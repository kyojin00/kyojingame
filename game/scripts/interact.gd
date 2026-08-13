# 상호작용 — 무엇을 겨누고 있고, E를 누르면 무슨 일이 벌어지는가.
#
# 겨눔은 두 갈래다. 마우스가 움직이면 그 칸, 아니면 바라보는 쪽 한 칸
# (`target_tile`). 클릭으로 고른 칸이 있으면 그것이 우선한다.
#
# `interact`는 가까운 것부터 훑는다 — 문 > NPC > 가축 > 곤충 > 오브젝트.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinActions
extends Node

var m: KyojinMain    # main.gd


func _door_kind_at(t: Vector2i) -> String:
	if GameData.house_lv >= 1 and t == m.door_tile(m.HOME_ANCHOR):
		return "home"
	if GameData.forest_quest in ["visit", "done"] \
			and t == m.door_tile(m.FOREST_HOUSE_ANCHOR):
		return "forest_house"
	if GameData.move_house.x >= 0 and t == m.door_tile(GameData.move_house):
		return "move_house"
	for pid: String in GameData.village_built:
		if m.VILLAGE_PLOTS.has(pid) and t == m.door_tile(m.VILLAGE_PLOTS[pid].anchor):
			return pid
	return ""


func _enter_building(kind: String) -> void:
	m.riding.dismount_horse()   # 말을 타고 실내로 들어갈 수는 없다
	if kind == "home":
		m.interior.open()
		return
	if kind == "move_house":
		m.dialog.open("무진의 집",
			"새 주민 무진의 집이다. 문패에 나침반이 그려져 있다.\n(무진은 마을 어딘가를 쏘다니는 중이다)",
			[["닫기", null]])
		return
	if kind == "forest_house":
		# 숲속의 집 (스토리 5): 첫 방문이면 모녀와의 만남, 이후에는 짧은 인사
		if GameData.forest_quest == "visit":
			m.story._start_forest_house_dialog()
		else:
			m.dialog.open("숲속의 집",
				"문틈으로 약초 달이는 향이 은은하게 흘러나온다.\n연화와 솔이는 집 근처를 산책하는 모양이다.",
				[["닫기", null]])
		return
	if m.shop_room.has_room(kind):
		m.shop_room.open(kind)   # 가게마다 다른 방으로 들어간다
		return
	m.hud.show_message("%s다. 아직 안에서 할 수 있는 일은 없다." %
		m.BUILDING_NAMES.get(kind, "건물"))


# 마우스가 움직일 때 main이 여기에 화면 좌표를 적어 둔다 (main._unhandled_input).
# 창 시스템에 매 프레임 묻지 않기 위해서다.
var mouse_screen := Vector2(-9999, -9999)


func _update_mouse_target() -> void:
	if m.player == null:
		m._mouse_target = Vector2i(-999, -999)
		return
	# 화면 -> 월드 변환만 매 프레임 한다 (이건 싸다)
	var mp: Vector2 = m.get_canvas_transform().affine_inverse() * mouse_screen
	var t := Vector2i(int(floor(mp.x / m.TILE)), int(floor(mp.y / m.TILE)))
	var d := t - m.player_tile()
	if d != Vector2i.ZERO and absi(d.x) <= 1 and absi(d.y) <= 1:
		m._mouse_target = t
	else:
		m._mouse_target = Vector2i(-999, -999)


func target_tile() -> Vector2i:
	if m._target_override.x != -999:
		return m._target_override  # 원격 플레이어 행동 처리 중
	if m._sel_target.x != -999:
		var d := m._sel_target - m.player_tile()
		if absi(d.x) <= 1 and absi(d.y) <= 1:
			return m._sel_target  # 좌클릭으로 고정한 선택
		m._sel_target = Vector2i(-999, -999)  # 멀어지면 선택 해제
	if m._mouse_target.x != -999:
		return m._mouse_target
	var dirs := {
		"down": Vector2i(0, 1), "up": Vector2i(0, -1),
		"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
	}
	return m.player_tile() + dirs[m.player.dir]


func _current_perp() -> Vector2i:
	if m._perp_override != Vector2i.ZERO:
		return m._perp_override
	return Vector2i(0, 1) if m.player.dir in ["left", "right"] else Vector2i(1, 0)


func can_use_tile(t: Vector2i) -> bool:
	# 마을/길은 공용, 나머지는 부지 소유 여부를 따른다
	return m._tile_accessible(t)


func _face_tile(t: Vector2i) -> void:
	var d := t - m.player_tile()
	if d == Vector2i.ZERO:
		return
	if absi(d.x) >= absi(d.y):
		m.player.dir = "right" if d.x > 0 else "left"
	else:
		m.player.dir = "down" if d.y > 0 else "up"


func _blocking_object_tile() -> Vector2i:
	if m.player == null:
		return Vector2i(-999, -999)
	var dirs := {"down": Vector2(0, 1), "up": Vector2(0, -1),
		"left": Vector2(-1, 0), "right": Vector2(1, 0)}
	var probe: Vector2 = m.player.position + (dirs[m.player.dir] as Vector2) * 14.0
	var pt := m.player_tile()
	var best := Vector2i(-999, -999)
	var best_d := 1e9
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var n: Vector2i = pt + Vector2i(dx, dy)
			if not m.objects.has(n) or not m.AIM_KINDS.has(m.objects[n].kind):
				continue
			var pad: Vector2 = m.OBJECT_PAD.get(m.objects[n].kind, Vector2.ZERO)
			var r := Rect2(n.x * m.TILE - pad.x, n.y * m.TILE - pad.y,
				m.TILE + pad.x * 2.0, m.TILE + pad.y * 2.0)
			if not r.has_point(probe):
				continue
			var d: float = (Vector2(n.x * m.TILE + 16, n.y * m.TILE + 16) - m.player.position).length()
			if d < best_d:
				best_d = d
				best = n
	return best


func interact() -> void:
	# 말을 타고 있으면 E도 「내리기」로 친다 (기본은 F)
	if GameData.riding:
		m.riding.dismount_horse()
		return
	# 맞는 도구를 들고 나무/돌을 조준 중이면 채집이 최우선
	# (근처에 NPC가 있어도 대화가 끼어들지 않는다)
	var aim: Variant = m.objects.get(target_tile())
	if aim == null:
		# 앞 칸은 비었는데 걸음이 막힌다면, 막고 있는 그 오브젝트를 대상으로 삼는다
		var bt := _blocking_object_tile()
		if bt.x != -999:
			m._sel_target = bt
			aim = m.objects.get(bt)
	var forced := Vector2i(-999, -999)
	if aim == null:
		# 도구에 맞는 대상이 가까이 있으면 그쪽을 본다 (그림이 커서 정면이 어긋날 때).
		# 찾은 칸은 _target_override로 그대로 넘긴다 — target_tile()의 한 칸 제한에
		# 걸려 도구가 엉뚱한 빈 칸을 때리지 않게 한다.
		var nt: Vector2i = m.toolwork._tool_target_nearby()
		if nt.x != -999:
			forced = nt
			m._sel_target = nt
			_face_tile(nt)
			aim = m.objects.get(nt)
	if aim != null and not bool(aim.get("young", false)) \
			and ((aim.kind == "tree" and GameData.tool == "axe")
			or (aim.kind in ["rock", "bigrock"] and GameData.tool == "pickaxe")):
		m._work_lock = m.WORK_LOCK_TIME  # 캐는 중 — 잠시 E는 무조건 도구다
		var prev := m._target_override
		if forced.x != -999:
			m._target_override = forced
		m.toolwork.use_tool()
		m._target_override = prev
		return
	# 캐던 나무/돌이 마지막 한 방에 부서져도, 이어 누른 E가 대화로 새지 않는다
	# (E는 캐기와 말 걸기를 겸하므로 연타 도중 말이 걸리면 곤란하다)
	if m._work_lock > 0.0:
		m.toolwork.use_tool()
		return
	# 나무·돌·채집물을 조준하고 있으면 대화보다 채집이 우선이다
	# (옆에 사람이 서 있어도 E가 대화로 새지 않는다)
	var aiming_object: bool = aim != null and m.AIM_KINDS.has(aim.kind)
	# 우체부 아저씨에게 말 걸기 (첫 만남 / 동행 중 보조 대화)
	if not aiming_object and m.story._postman != null and m.story._postman_state == "wait" \
			and (m.player.position - m.story._postman.position).length() < m.POSTMAN_TALK_DIST:
		m.story._postman_state = "talk"
		m.story._start_postman_dialog()
		return
	if not aiming_object and m.story._postman != null and m.story._postman_state == "follow" \
			and (m.player.position - m.story._postman.position).length() < 48.0:
		m.story._talk_to_postman()
		return
	# 가까운 NPC와 대화
	var npc := nearby_npc()
	if npc != null and not aiming_object:
		m.village._talk_to(npc)
		return
	# 가까운 동물 쓰다듬기(=먹이 주기)
	var animal := nearby_animal()
	if animal != null:
		var def: Dictionary = GameData.ANIMALS[animal.type]
		if animal.fed:
			m.hud.show_message("%s는 이미 만족스러워 보인다." % def.name)
		else:
			animal.fed = true
			Sound.play_sfx("sfx_heart")
			if Net.is_guest():
				m.netsync._req_feed.rpc_id(1, m.animals.find(animal))
			m.hud.show_message("%s를 쓰다듬었다! ♥ 내일 아침 %s을 준다." %
				[def.name, GameData.ITEMS[def.product].name])
		return
	# 곤충 잡기
	var bug := nearby_bug()
	if bug != null:
		var bid: String = bug.bug_id
		GameData.items[bid] += 1
		GameData.forage_caught[bid] = int(GameData.forage_caught.get(bid, 0)) + 1
		GameData.discover(bid)
		Sound.play_sfx("sfx_catch")
		m.renderer.spawn_particles(m.player_tile(), "sparkle")
		m.hud.show_message("%s를 잡았다! 연구 노트에 기록됐다." % GameData.ITEMS[bid].name)
		bug.respawn()
		if Net.is_host():
			m.netsync._broadcast_stats()
		return
	for t in [target_tile(), m.player_tile()]:
		var obj: Variant = m.objects.get(t)
		if obj == null:
			continue
		if String(obj.kind).begins_with("forage_") or String(obj.kind) == "weed":
			var fid: String = obj.kind
			m.objnode._remove_object(t)
			var got := 1
			if fid in m.BEACH_FORAGE:
				got = GameData.beach_pick_count()   # 해변 채집 레벨: 한 번에 더 줍는다
				m.toolwork.gain_skill("beach", 6.0)
			else:
				m.toolwork.gain_skill("forest", 3.0)
			var first_find: bool = not GameData.discovered.has(fid)
			GameData.items[fid] += got
			GameData.forage_caught[fid] = int(GameData.forage_caught.get(fid, 0)) + got
			GameData.discover(fid)
			# 산호 조각·고대 조각: 처음 주우면 숨겨진 이야기/레시피가 열린다
			if first_find and fid in ["forage_coral", "forage_relic"]:
				m.story.hidden_beach_find(fid)
			Sound.play_sfx("sfx_harvest")
			m.renderer.spawn_particles(t, "sparkle")
			m.hud.show_message("%s%s 채집! 연구 노트에 기록됐다."
				% [GameData.ITEMS[fid].name, " x%d" % got if got > 1 else ""])
			if Net.is_host():
				m.netsync._broadcast_area(t)
				m.netsync._broadcast_stats()
			elif Net.is_guest():
				m.netsync._req_gain.rpc_id(1, fid, got)
			return
		if obj.kind == "searock":
			m.hud.show_message("울퉁불퉁한 바위 능선이다. 이 너머가 바다인 모양이다.")
			return
		if obj.kind == "worldtree":
			m.cave.open(true)
			return
		if obj.kind == "housesite":
			m.village._open_build_dialog()
			return
		if obj.kind == "plotsite":
			m.village._open_shop_site_dialog()
			return
		if obj.kind == "stall":
			m.village.open_stall()
			return
		if obj.kind == "trash_bin":
			m.village.open_trash_bin(t)
			return
		if obj.kind == "chief_hut":
			if GameData.chief_house_lv >= 1:
				m.dialog.open("이장의 집",
					"마을 사람들이 힘을 모아 지어 드린 이장님의 새 집이다.\n"
					+ ("낮에는 마을회관에서 업무를 보신다." if GameData.village_built.has("hall")
						else "창가에 화분이 가지런하다."),
					[["닫기", null]])
			else:
				m.dialog.open("이장의 오두막",
					"이장님이 사는 작고 낡은 오두막이다.\n"
					+ "마을이 살아나면 제대로 된 집을 지어 드리고 싶다...",
					[["닫기", null]])
			return
		if obj.kind == "homeplot":
			# 빈 집터 팻말 — 회수하면 집터가 가방으로 돌아온다
			m.dialog.open("빈 집터",
				"새 주민을 위해 마련해 둔 빈 집터다.\n이주 희망 편지를 수락하면 여기에 집이 지어진다.",
				[["회수하기", m.story._pickup_home_plot.bind(t)], ["닫기", null]])
			return
		if obj.kind == "board":
			m.village._open_quest_board()
			return
		if obj.kind == "sign" and t == m.GREENHOUSE_SIGN:
			m.village._open_greenhouse_dialog()
			return
		if obj.kind == "sign" and t == m.FISH_SIGN:
			m.dialog.open("낚시터", "교진 마을 낚시터.\n\n부두 끝에 서서 강을 보고 낚싯대(E)를 던지면 된다.\n"
				+ "입질(!)이 오면 다시 E!\n\n붕어 · 잉어 · 메기... 그리고 아주 드물게\n황금잉어가 올라온다고 한다.",
				[["알겠다", null]])
			return
		if obj.kind == "horse":
			m.riding._mount_horse(t)   # 말 칸에서 E를 눌러도 탄다 (F가 기본)
			return
		if obj.kind == "cave":
			m.village._open_mine_dialog()
			return
		if obj.kind == "house":
			_enter_building(_building_kind_at(t))
			return
	# 자연물: E키가 기본 상호작용 (나무=도끼 벌목, 돌=곡괭이 채광)
	var tobj: Variant = m.objects.get(target_tile())
	if tobj != null and tobj.kind == "tree":
		if bool(tobj.get("young", false)):
			m.hud.show_message("아직 어린 나무다. 다 자라면 벨 수 있다.")
		elif GameData.tool == "axe":
			m.toolwork.use_tool()
		else:
			m.hud.show_message("도끼가 필요하다. 숫자키로 도끼를 선택하자!")
		return
	if tobj != null and tobj.kind in ["rock", "bigrock"]:
		if GameData.tool == "pickaxe":
			m.toolwork.use_tool()
		else:
			m.hud.show_message("곡괭이가 필요하다. 숫자키로 곡괭이를 선택하자!")
		return
	# 그 밖에는 손에 든 것을 그대로 쓴다 — 호미로 밭 갈기, 씨앗 심기, 물 주기,
	# 수확, 낚시까지 전부 E 하나로 된다 (좌클릭과 같은 동작).
	# 앞에 아무것도 없으면 조용히 지나간다 (걸어다니며 E를 눌러도 메시지 없음)
	var tt := target_tile()
	var crop_ahead: bool = tt.x >= 0 and tt.y >= 0 and tt.x < m.MAP_W and tt.y < m.MAP_H \
		and m.grid[tt.y][tt.x].crop_id != ""
	if crop_ahead or GameData.tool_slots.has(GameData.tool):
		m.toolwork.use_tool()


func _tile_overlaps_player(t: Vector2i) -> bool:
	var rect := Rect2(t.x * m.TILE - 2, t.y * m.TILE - 2, m.TILE + 4, m.TILE + 4)
	if rect.has_point(m.player.position):
		return true
	for pid in m.remote_players:
		if rect.has_point(m.remote_players[pid].position):
			return true
	return false


func nearby_npc() -> Node2D:
	# 말은 **바라보는 쪽**에 있는 사람에게만 걸린다.
	# 옆이나 뒤에 서 있는 사람 때문에 E가 대화로 새면 캐기가 끊긴다.
	var f: Vector2 = m.FACE_VECS[m.player.dir]
	var best: Node2D = null
	var best_d := 1e9
	for n in m.npcs:
		if not n.visible:
			continue  # 집에 들어간 NPC와는 만날 수 없다
		var v: Vector2 = n.position - m.player.position
		var d := v.length()
		if d >= 48.0:
			continue
		if d > 14.0 and v.normalized().dot(f) < 0.35:
			continue
		if d < best_d:
			best_d = d
			best = n
	return best


func nearby_animal() -> Node2D:
	for a in m.animals:
		if (a.position - m.player.position).length() < 44.0:
			return a
	return null


func _building_kind_at(t: Vector2i) -> String:
	if GameData.house_lv >= 1 and t.x >= m.HOME_ANCHOR.x and t.x < m.HOME_ANCHOR.x + 5 \
			and t.y >= m.HOME_ANCHOR.y and t.y < m.HOME_ANCHOR.y + 4:
		return "home"
	# 마을 건물은 실제로 지어진 것만 존재한다
	for pid: String in GameData.village_built:
		if not m.VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = m.VILLAGE_PLOTS[pid].anchor
		if t.x >= a.x and t.x < a.x + 5 and t.y >= a.y and t.y < a.y + 4:
			return pid
	return ""


func nearby_bug() -> Node2D:
	for bnode in m.bugs:
		if bnode.visible and (bnode.position - m.player.position).length() < 40.0:
			return bnode
	return null


func _click_at(pos: Vector2, dbl: bool) -> void:
	# 좌클릭 1회: 대상 선택 / 더블클릭: 선택 + 즉시 상호작용 (E키와 동일)
	var t := Vector2i(int(floor(pos.x / m.TILE)), int(floor(pos.y / m.TILE)))
	var d := t - m.player_tile()
	if absi(d.x) > 1 or absi(d.y) > 1:
		m._sel_target = Vector2i(-999, -999)  # 먼 곳 클릭 = 선택 해제
		return
	if d != Vector2i.ZERO:
		# 스프라이트 방향은 우세한 축 기준 (대각선이면 좌우 우선)
		if d.x != 0:
			m.player.dir = "right" if d.x > 0 else "left"
		else:
			m.player.dir = "down" if d.y > 0 else "up"
	m._sel_target = t
	m.queue_redraw()
	if dbl:
		# 마우스만으로 즉시 상호작용: 대상이 있으면 E와 동일, 빈 칸이면 도구 사용
		if m.objects.has(t) or nearby_npc() != null or nearby_animal() != null \
				or nearby_bug() != null:
			interact()
		else:
			m.toolwork.use_tool()
