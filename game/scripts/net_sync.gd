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
var _connect_ip := ""   # 접속 화면에 보여 줄 호스트 주소

# ---- 게스트 요청 검문 ----
#
# 게스트가 보내는 `_req_*`는 **고친 게임에서 오는 것일 수 있다.** 예전에는
# 그대로 반영해서, 조작한 클라이언트가 돈과 물건을 무한히 만들 수 있었다.
# 호스트가 문지기 노릇을 한다 — 너무 잦은 요청은 흘리고, 말이 안 되는 값은
# 버린다. (진짜 방어는 서버 권위 창고지만, 여기서 막을 수 있는 건 막는다)
const REQ_PER_SEC := 12.0        # peer 하나가 초당 보낼 수 있는 요청
const REQ_BURST := 30.0          # 잠깐 몰릴 때 허용치
const AUCTION_MONEY_CAP := 9_000_000   # 장터 한 번에 오갈 수 있는 돈
var _req_tokens := {}            # peer_id -> 남은 토큰
var _req_last := {}              # peer_id -> 마지막으로 채운 시각(초)


# 이 요청을 받아 줄까? (토큰 버킷 — 평소엔 넉넉하고 쏟아지면 막는다)
func _allow(cost := 1.0) -> bool:
	var pid := multiplayer.get_remote_sender_id()
	var now := Time.get_ticks_msec() / 1000.0
	var last: float = float(_req_last.get(pid, now))
	var have: float = float(_req_tokens.get(pid, REQ_BURST))
	have = minf(REQ_BURST, have + (now - last) * REQ_PER_SEC)
	_req_last[pid] = now
	if have < cost:
		_req_tokens[pid] = have
		return false
	_req_tokens[pid] = have - cost
	return true


# 게임이 아는 물건인가 (아무 이름이나 보내 창고를 늘리지 못하게)
func _known_goods(cat: String, id: String) -> bool:
	match cat:
		"seed", "produce":
			return GameData.CROPS.has(id)
		"tool":
			return GameData.ALL_TOOLS.has(id)
		_:
			return GameData.ITEMS.has(id) or id == "wood" or id == "stone"


# 요청한 게스트가 그 칸 가까이에 있는가 (맵 반대편을 건드리지 못하게).
# tiles는 몇 칸까지 봐 줄지 — 씨앗은 멀리서도 뿌리므로 그만큼 넓게 본다.
func _near_sender(t: Vector2i, tiles := 3.0) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H:
		return false
	var pid := multiplayer.get_remote_sender_id()
	if not m.remote_players.has(pid):
		return true      # 아직 자리를 못 받았으면 통과시킨다 (첫 프레임)
	var p: Vector2 = m.remote_players[pid].position
	var d := Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16) - p
	return d.length() < m.TILE * tiles


func _show_connecting() -> void:
	_connect_ip = Net.last_ip
	var layer := CanvasLayer.new()
	layer.layer = 55
	layer.name = "Connecting"
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	m._connect_label = Label.new()
	m._connect_label.text = "호스트를 찾는 중... (%s)\n\nESC: 취소하고 타이틀로" % _connect_ip
	m._connect_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	m._connect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m._connect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(m._connect_label)
	# 스냅샷을 끝내 못 받으면 타이틀로. 맵 전체를 조각으로 받아오므로
	# 넉넉히 기다린다 (조각이 오는 동안은 라벨에 진행률이 찍힌다).
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
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
	_req_tokens.erase(id)      # 검문 기록도 함께 치운다
	_req_last.erase(id)
	if Net.is_host():
		m.hud.show_message("일꾼이 농장을 떠났다.")


func _on_server_disconnected() -> void:
	Net.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# 호스트를 못 찾았다 (IP가 틀렸거나 방이 없거나 방화벽에 막혔다).
# 왜 안 됐는지 알려 주고 잠시 뒤 타이틀로 돌아간다.
func _on_connection_failed() -> void:
	if m._connect_label != null and is_instance_valid(m._connect_label):
		m._connect_label.text = "호스트에 닿지 못했다...\n" \
			+ "IP(%s)와 방화벽(7777 포트)을 확인하자.\n곧 타이틀로 돌아간다." % _connect_ip
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if Net.is_guest() and not m._net_ready:
			m._back_to_title())


func _make_snapshot_json() -> String:
	# 저장과 **똑같은 것**을 보낸다 (saveio.grid_cells / object_rows).
	# 예전에는 여기서 격자를 통째로 다시 훑었는데, 저장 형식이 「바뀐 칸만」으로
	# 바뀌었을 때 이쪽만 옛 방식으로 남으면 접속마다 오 메가바이트를 보낸다.
	var g := m.saveio.grid_cells()
	var objs := m.saveio.object_rows()
	var anims := []
	for a in m.animals:
		anims.append([a.type, a.position.x, a.position.y, 1 if a.fed else 0])
	return JSON.stringify(GameData.build_save(g, m.player.position, objs, anims,
		m.MAP_W, m.MAP_H))


# 스냅샷은 **맵 전체**라 커서(168x90칸이면 300KB를 넘는다) 한 번에 못 보낸다.
# 한 번에 밀어 넣으면 통째로 유실되고, 게스트는 12초를 기다리다 타이틀로
# 튕긴다 — 맵을 넓힌 뒤 접속이 안 되던 원인이 이것이다. 조각으로 끊어
# 보내고 게스트가 다시 이어 붙인다.
const SNAP_CHUNK := 24000        # 조각 하나의 글자 수

var _snap_buf := ""              # 게스트: 받아 쌓는 중인 스냅샷


@rpc("any_peer", "reliable")
func _req_snapshot() -> void:
	# 맵 전체를 보내는 무거운 요청이라 값을 비싸게 매긴다 (도배 방지)
	if not Net.is_host() or not _allow(10.0):
		return
	var who := multiplayer.get_remote_sender_id()
	var json := _make_snapshot_json()
	var total: int = int(ceil(float(json.length()) / SNAP_CHUNK))
	for i in total:
		_recv_snapshot_part.rpc_id(who, json.substr(i * SNAP_CHUNK, SNAP_CHUNK),
			i, total)


# 조각 하나 도착. 첫 조각에서 버퍼를 비우고, 마지막 조각에서 펼친다.
# (요청이 두 번 나가 조각이 겹쳐 와도 첫 조각이 버퍼를 지우므로 안전하다)
@rpc("authority", "reliable")
func _recv_snapshot_part(part: String, idx: int, total: int) -> void:
	if idx == 0:
		_snap_buf = ""
	_snap_buf += part
	if idx < total - 1:
		if m._connect_label != null:
			m._connect_label.text = "농장을 받아오는 중... %d%%" \
				% int(float(idx + 1) / total * 100.0)
		return
	var json := _snap_buf
	_snap_buf = ""
	_recv_snapshot(json)


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


# 위치 갱신은 초당 15번 오는 것이 정상이라 검문에서 뺀다 (막으면 걸음이 끊긴다).
# 세계를 바꾸지 않고 남의 그림 자리만 옮기므로, 조작해도 손해가 없다.
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


# 접속 화면에 지금 어디까지 왔는지 적는다. 「접속하는 중...」에서 멈춰
# 있을 때 연결이 안 붙은 것인지, 붙었는데 농장을 못 받는 것인지 구별된다.
# (조각을 받기 시작하면 _recv_snapshot_part가 진행률로 덮어쓴다)
func _update_connect_label() -> void:
	if m._connect_label == null or not is_instance_valid(m._connect_label) \
			or not Net.is_guest() or m._net_ready or _snap_buf != "":
		return
	var peer := multiplayer.multiplayer_peer
	var esc := "\n\nESC: 취소하고 타이틀로"
	if peer == null:
		m._connect_label.text = "연결이 끊어졌다..." + esc
		return
	match peer.get_connection_status():
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			m._connect_label.text = "호스트를 찾지 못했다...\n" \
				+ "IP(%s)와 방화벽(7777 포트)을 확인하자." % _connect_ip + esc
		MultiplayerPeer.CONNECTION_CONNECTING:
			m._connect_label.text = "호스트를 찾는 중... (%s)" % _connect_ip + esc
		_:
			m._connect_label.text = "연결됐다! 농장을 넘겨받는 중..." + esc


func _net_process(delta: float) -> void:
	_update_connect_label()
	# **붙어 있을 때만** 내보낸다. 모드만 보고 쏘면 게스트가 방을 찾는 동안,
	# 또는 연결이 끊긴 뒤에 "not connected" 오류가 매 프레임 쌓인다.
	if not Net.connected():
		return
	if Net.is_guest() and not m._net_ready:
		# 스냅샷 재요청 (유실 대비)
		m._snapshot_retry -= delta
		if m._snapshot_retry <= 0.0:
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
		if c.ground != entry[2]:
			m.dirty_tile(int(entry[0]), int(entry[1]))
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

# 게스트가 장터에서 사고팔았다 — 공용 지갑·창고에 반영하고 다시 뿌린다
@rpc("any_peer", "reliable")
func _req_auction(cat: String, id: String, qty: int, quality: int,
		money_delta: int) -> void:
	if not Net.is_host() or not _allow():
		return
	# 값이 말이 되는지부터 본다 — 예전에는 그대로 반영해서 조작한 게스트가
	# 돈을 무한히 만들 수 있었다
	if absi(qty) > 999 or absi(money_delta) > AUCTION_MONEY_CAP:
		return
	if id != "" and not _known_goods(cat, id):
		return
	GameData.money = maxi(0, GameData.money + money_delta)
	if id != "" and qty != 0:
		if cat == "tool":
			# 도구는 하나뿐 — 들어오면 해금하고 등급을 올리고, 나가면 잠근다
			if qty > 0:
				if not GameData.unlocked_tools.has(id):
					GameData.unlocked_tools.append(id)
				if GameData.tool_level.has(id):
					GameData.tool_level[id] = maxi(int(GameData.tool_level[id]),
						maxi(1, quality))
			else:
				GameData.unlocked_tools.erase(id)
			_broadcast_stats()
			return
		match cat:
			"seed":
				GameData.seeds[id] = maxi(0, int(GameData.seeds.get(id, 0)) + qty)
			"produce":
				GameData.produce[id] = maxi(0, int(GameData.produce.get(id, 0)) + qty)
				if quality == 1:
					GameData.produce_silver[id] = maxi(0,
						int(GameData.produce_silver.get(id, 0)) + qty)
				elif quality == 2:
					GameData.produce_gold[id] = maxi(0,
						int(GameData.produce_gold.get(id, 0)) + qty)
			_:
				if id == "wood":
					GameData.wood = maxi(0, GameData.wood + qty)
				elif id == "stone":
					GameData.stone = maxi(0, GameData.stone + qty)
				else:
					GameData.items[id] = maxi(0, int(GameData.items.get(id, 0)) + qty)
	_broadcast_stats()


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
	if not Net.is_host() or not _allow(1.0):
		return
	if not _known_goods("tool", tool) and tool != "":
		return
	# 씨앗은 손이 닿는 거리가 넓다 (interact.SEED_REACH) — 그만큼 봐 준다
	if not _near_sender(Vector2i(tx, ty), 11.0 if tool == "seed" else 3.0):
		return      # 맵 반대편 칸을 건드리려는 요청
	var saved_tool: String = GameData.tool
	var saved_energy: float = GameData.energy
	m._target_override = Vector2i(tx, ty)
	m._perp_override = Vector2i(px, py)
	m.forced_seed = seed_id
	m.remote_acting = true
	GameData.tool = tool
	m.toolwork.use_tool()
	GameData.tool = saved_tool
	GameData.energy = saved_energy  # 게스트 기력은 게스트 로컬 관리
	m.remote_acting = false
	m._target_override = Vector2i(-999, -999)
	m._perp_override = Vector2i.ZERO
	m.forced_seed = ""
	_broadcast_area(Vector2i(tx, ty))
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_shop(op: String, id: String, qty := -1) -> void:
	if not Net.is_host() or not _allow(1.0):
		return
	match op:
		"buy_seed":
			m.shop._on_buy(id)
		"sell_crop":
			m.shop._on_sell(id, qty)
		"sell_item":
			m.shop._on_sell_item(id, qty)
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
	if not Net.is_host() or not _allow(1.0):
		return
	if index >= 0 and index < m.animals.size():
		m.animals[index].fed = true


@rpc("any_peer", "reliable")
func _req_kill(mob: String) -> void:
	if not Net.is_host() or not _allow(1.0):
		return
	if GameData.MOBS.has(mob):
		GameData.mob_kills[mob] = int(GameData.mob_kills.get(mob, 0)) + 1
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_gain(id: String, count: int) -> void:
	if not Net.is_host() or not _allow(1.0):
		return
	if GameData.items.has(id) and count > 0 and count <= 50:
		GameData.items[id] += count
		GameData.discover(id)
		if id.begins_with("fish_"):
			GameData.fish_caught[id] = int(GameData.fish_caught.get(id, 0)) + count
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_cook(id: String) -> void:
	if not Net.is_host() or not _allow(1.0):
		return
	if GameData.RECIPES.has(id) and GameData.cook(id):
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_eat(id: String) -> void:
	if not Net.is_host() or not _allow(1.0):
		return
	if GameData.RECIPES.has(id) and int(GameData.items[id]) > 0:
		GameData.items[id] -= 1
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_furniture(furn_json: String, money_delta: int) -> void:
	if not Net.is_host() or not _allow(1.0):
		return
	var arr: Variant = JSON.parse_string(furn_json)
	if typeof(arr) != TYPE_ARRAY or absi(money_delta) > 1000:
		return
	GameData.apply_furniture_data(arr)
	GameData.money += money_delta
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_gift(npc_id: String, kind: String, item_id: String) -> void:
	if not Net.is_host() or not _allow(1.0):
		return
	if not GameData.NPCS.has(npc_id):
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
	if not Net.is_host() or not _allow(1.0):
		return
	if op not in ["accept", "turnin"]:
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


# 새 날도 맵 전체를 보내므로 스냅샷과 똑같이 조각내 보낸다 (day_cycle이 부른다).
func send_new_day(json: String, title_text: String, body: String) -> void:
	var total: int = int(ceil(float(json.length()) / SNAP_CHUNK))
	for i in total:
		_recv_new_day_part.rpc(json.substr(i * SNAP_CHUNK, SNAP_CHUNK), i, total,
			title_text, body)


var _day_buf := ""


@rpc("authority", "reliable")
func _recv_new_day_part(part: String, idx: int, total: int,
		title_text: String, body: String) -> void:
	if idx == 0:
		_day_buf = ""
	_day_buf += part
	if idx < total - 1:
		return
	var json := _day_buf
	_day_buf = ""
	_net_new_day(json, title_text, body)


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
