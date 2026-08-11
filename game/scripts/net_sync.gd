# 함께하기 — 세계를 두 사람이 같이 굴리기 위한 배관.
#
# 규칙은 하나다. **호스트가 정답을 가진다.** 게스트는 무엇을 하고 싶은지
# `_req_*`로 호스트에 요청하고, 호스트가 실제로 적용한 뒤 결과를 뿌린다
# (`_net_area`·`_net_stats`·`_net_time`). 게스트가 제 화면만 고치는 일은 없다.
#
# **이 파일은 main의 자식 노드다.** @rpc는 노드 경로로 상대를 찾아가므로,
# 양쪽 peer에서 경로가 같아야 한다 — main이 _ready 맨 앞에서 늘 같은
# 이름(NetSync)으로 붙이기 때문에 성립한다. 이름을 바꾸면 통신이 죽는다.
#
# 검증: dev_harness.gd의 `_mp_tick` (KYOJIN_MP=host / guest).
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinNetSync
extends Node

var m: KyojinMain    # main.gd


func _show_connecting() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 55
	layer.name = "Connecting"
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	m._connect_label = Label.new()
	m._connect_label.text = "호스트에 접속하는 중..."
	m._connect_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	m._connect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m._connect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(m._connect_label)
	# 12초 안에 스냅샷을 못 받으면 타이틀로
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		if not m._net_ready and Net.is_guest():
			m._back_to_title())


func _hide_connecting() -> void:
	var layer := get_node_or_null("Connecting")
	if layer != null:
		layer.queue_free()


func _on_peer_connected(_id: int) -> void:
	if Net.is_host():
		m.hud.show_message("새 일꾼이 농장에 도착했다!")


func _on_peer_disconnected(id: int) -> void:
	if m.remote_players.has(id):
		m.remote_players[id].queue_free()
		m.remote_players.erase(id)
	if Net.is_host():
		m.hud.show_message("일꾼이 농장을 떠났다.")


func _on_server_disconnected() -> void:
	Net.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _make_snapshot_json() -> String:
	var g := []
	for y in m.MAP_H:
		var row := []
		for x in m.MAP_W:
			var c: Dictionary = m.grid[y][x]
			row.append([c.ground, int(c.wet_min), c.crop_id, int(c.crop_day),
				1 if c.dead else 0, 1 if c.get("half_fed", false) else 0])
		g.append(row)
	var objs := []
	for pos: Vector2i in m.objects:
		objs.append([pos.x, pos.y, m.objects[pos].kind, m.objects[pos].hp,
			1 if m.objects[pos].get("apple", false) else 0,
			1 if m.objects[pos].get("young", false) else 0,
			int(m.objects[pos].get("grow", 0)),
			1 if m.objects[pos].get("fixed", false) else 0])
	var anims := []
	for a in m.animals:
		anims.append([a.type, a.position.x, a.position.y, 1 if a.fed else 0])
	return JSON.stringify(GameData.build_save(g, m.player.position, objs, anims))


@rpc("any_peer", "reliable")
func _req_snapshot() -> void:
	if not Net.is_host():
		return
	_recv_snapshot.rpc_id(multiplayer.get_remote_sender_id(), _make_snapshot_json())


@rpc("authority", "reliable")
func _recv_snapshot(json: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if typeof(d) != TYPE_DICTIONARY:
		return
	# 스냅샷의 플레이어 위치는 호스트 것이므로 내 위치는 유지한다
	var my_pos := m.player.position
	for a in m.animals:
		a.queue_free()
	m.animals.clear()
	m.saveio._apply_save(d)
	m.player.position = my_pos
	GameData.tutorial = {"active": false}
	GameData.unlock_all_tools()
	m.objnode._spawn_objects()
	m.objnode._apply_season_visuals()
	m._net_ready = true
	_hide_connecting()
	m.hud.show_message("농장에 도착했다! 함께 일해보자.")
	m.queue_redraw()


@rpc("any_peer", "unreliable_ordered")
func _sync_pos(x: float, y: float, dir: String, moving: bool) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not m.remote_players.has(pid):
		var rp: Node2D = preload("res://scripts/remote_player.gd").new()
		rp.main = m
		rp.tint = m.PLAYER_TINTS[(pid % 3) + 1]
		rp.position = Vector2(x, y)
		m.remote_players[pid] = rp
		m.world.add_child(rp)
	m.remote_players[pid].set_state(Vector2(x, y), dir, moving)


func _net_process(delta: float) -> void:
	if not Net.active():
		return
	if Net.is_guest() and not m._net_ready:
		# 스냅샷 재요청 (유실 대비)
		m._snapshot_retry -= delta
		if m._snapshot_retry <= 0.0 and multiplayer.multiplayer_peer != null \
				and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			m._snapshot_retry = 2.0
			_req_snapshot.rpc_id(1)
	m._pos_sync_timer -= delta
	if m._pos_sync_timer <= 0.0:
		m._pos_sync_timer = 1.0 / 15.0
		_sync_pos.rpc(m.player.position.x, m.player.position.y, m.player.dir, m.player.moving)
	if Net.is_host():
		m._time_sync_timer -= delta
		if m._time_sync_timer <= 0.0:
			m._time_sync_timer = 3.0
			_net_time.rpc(GameData.day, GameData.minutes, GameData.energy)


@rpc("authority", "unreliable_ordered")
func _net_time(day: int, minutes: float, _host_energy: float) -> void:
	GameData.day = day
	GameData.minutes = minutes


func _broadcast_area(center: Vector2i) -> void:
	if not Net.is_host():
		return
	var cells := []
	var objs := []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var pos := center + Vector2i(dx, dy)
			if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.MAP_H:
				continue
			var c: Dictionary = m.grid[pos.y][pos.x]
			cells.append([pos.x, pos.y, c.ground, int(c.wet_min), c.crop_id,
				int(c.crop_day), 1 if c.dead else 0, 1 if c.get("half_fed", false) else 0])
			if m.objects.has(pos):
				var o: Dictionary = m.objects[pos]
				objs.append([pos.x, pos.y, o.kind, o.hp])
	_net_area.rpc(center.x, center.y, cells, objs)


@rpc("authority", "reliable")
func _net_area(cx: int, cy: int, cells: Array, objs: Array) -> void:
	for entry in cells:
		var c: Dictionary = m.grid[entry[1]][entry[0]]
		c.ground = entry[2]
		c.wet_min = float(entry[3])
		c.watered = float(entry[3]) > 0.0
		c.crop_id = entry[4]
		c.crop_day = float(entry[5])
		c.dead = int(entry[6]) == 1
		c.half_fed = entry.size() > 7 and int(entry[7]) == 1
	# 영역 내 오브젝트: 목록에 없는 건 제거, 있는 건 갱신/추가
	var present := {}
	for o in objs:
		present[Vector2i(int(o[0]), int(o[1]))] = o
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var pos := Vector2i(cx + dx, cy + dy)
			if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.MAP_H:
				continue
			if m.objects.has(pos) and not present.has(pos):
				if m.objects[pos].kind != "house":
					m.objnode._remove_object(pos)
			elif present.has(pos):
				var o: Array = present[pos]
				if o[2] == "house":
					continue
				if m.objects.has(pos):
					m.objects[pos].hp = int(o[3])
				else:
					m.objnode._place_object(pos, o[2], int(o[3]))
	m.queue_redraw()
	m.farming.rebuild()

func _broadcast_stats() -> void:
	if Net.is_host():
		_net_stats.rpc(JSON.stringify(GameData.build_stats()))


@rpc("authority", "reliable")
func _net_stats(json: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if typeof(d) == TYPE_DICTIONARY:
		GameData.apply_stats(d)


@rpc("any_peer", "reliable")
func _req_tool(tx: int, ty: int, tool: String, seed_id: String, px: int, py: int) -> void:
	if not Net.is_host():
		return
	var saved_tool: String = GameData.tool
	var saved_energy: float = GameData.energy
	m._target_override = Vector2i(tx, ty)
	m._perp_override = Vector2i(px, py)
	m._forced_seed = seed_id
	m._remote_acting = true
	GameData.tool = tool
	m.toolwork.use_tool()
	GameData.tool = saved_tool
	GameData.energy = saved_energy  # 게스트 기력은 게스트 로컬 관리
	m._remote_acting = false
	m._target_override = Vector2i(-999, -999)
	m._perp_override = Vector2i.ZERO
	m._forced_seed = ""
	_broadcast_area(Vector2i(tx, ty))
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_shop(op: String, id: String) -> void:
	if not Net.is_host():
		return
	match op:
		"buy_seed":
			m.shop._on_buy(id)
		"sell_crop":
			m.shop._on_sell(id)
		"sell_item":
			m.shop._on_sell_item(id)
		"buy_animal":
			m.shop._on_buy_animal(id)
		"buy_pet":
			m.shop._on_buy_pet(id)
		"select_pet":
			m.shop._on_select_pet(id)
		"upgrade":
			m.shop._on_upgrade(id)
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_feed(index: int) -> void:
	if not Net.is_host():
		return
	if index >= 0 and index < m.animals.size():
		m.animals[index].fed = true


@rpc("any_peer", "reliable")
func _req_kill(mob: String) -> void:
	if not Net.is_host():
		return
	if GameData.MOBS.has(mob):
		GameData.mob_kills[mob] = int(GameData.mob_kills.get(mob, 0)) + 1
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_gain(id: String, count: int) -> void:
	if not Net.is_host():
		return
	if GameData.items.has(id) and count > 0 and count <= 50:
		GameData.items[id] += count
		if id.begins_with("fish_"):
			GameData.fish_caught[id] = int(GameData.fish_caught.get(id, 0)) + count
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_cook(id: String) -> void:
	if not Net.is_host():
		return
	if GameData.RECIPES.has(id) and GameData.cook(id):
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_eat(id: String) -> void:
	if not Net.is_host():
		return
	if GameData.RECIPES.has(id) and int(GameData.items[id]) > 0:
		GameData.items[id] -= 1
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_furniture(furn_json: String, money_delta: int) -> void:
	if not Net.is_host():
		return
	var arr: Variant = JSON.parse_string(furn_json)
	if typeof(arr) != TYPE_ARRAY or absi(money_delta) > 1000:
		return
	GameData.apply_furniture_data(arr)
	GameData.money += money_delta
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_gift(npc_id: String, kind: String, item_id: String) -> void:
	if not Net.is_host():
		return
	# 게스트가 직접 고른 품목을 차감한다
	if kind == "produce" and int(GameData.produce.get(item_id, 0)) > 0:
		GameData.produce[item_id] -= 1
	elif kind == "item" and int(GameData.items.get(item_id, 0)) > 0:
		GameData.items[item_id] -= 1
	else:
		return
	GameData.affinity[npc_id] = int(GameData.affinity[npc_id]) + 10
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_quest(op: String) -> void:
	if not Net.is_host():
		return
	if op == "accept" and not GameData.quest.is_empty():
		GameData.quest.accepted = true
	elif op == "turnin" and not GameData.quest.is_empty():
		var q: Dictionary = GameData.quest
		var iid: String = str(q.item)
		if GameData.ingredient_count(iid) >= int(q.qty):
			GameData.consume_ingredient(iid, int(q.qty))
			GameData.money += int(q.reward)
			GameData.affinity["merchant"] = int(GameData.affinity["merchant"]) + 5
			GameData.quest = {}
	_broadcast_stats()


@rpc("authority", "reliable")
func _net_new_day(json: String, title_text: String, body: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if typeof(d) != TYPE_DICTIONARY:
		return
	var my_pos := m.player.position
	for a in m.animals:
		a.queue_free()
	m.animals.clear()
	m.saveio._apply_save(d)
	m.player.position = my_pos
	GameData.tutorial = {"active": false}
	GameData.unlock_all_tools()
	GameData.energy = GameData.ENERGY_MAX
	m.objnode._spawn_objects()
	m.objnode._apply_season_visuals()
	m.summary.open(title_text, body)
	m.queue_redraw()
