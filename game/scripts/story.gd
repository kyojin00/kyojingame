# 메인 스토리 연출 — 오프닝부터 마을 도착까지.
#
# 게임 규칙이 아니라 **각본**이다. 우체부와 함께 걷고, 나무를 베고, 바위를
# 깨고, 편지를 전하는 동안의 카메라·대화·등장인물 움직임을 여기서 다룬다.
#
# 진행 상태는 GameData.story_step 하나로 정해진다. `_story_update`가 매 프레임
# 그 단계를 보고 무엇을 할지 고른다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
extends Node

var m: KyojinMain    # main.gd
var _postman: Node2D = null
var _postman_spr: Sprite2D = null
var _postman_state := ""                   # approach / wait / talk / follow / leave
var _postman_anim := 0.0
var _postman_wait_t := 0.0
var _postman_path: Array = []      # 퇴장 경로 (지나갈 칸의 중심 좌표)
var _postman_fade := 1.0
var _story_t := 0.0
var _story_snapped := false
var _story_map_opened := false
var _rock_intro_started := false
var _story_idx := 0
var _story_pages: Array = []
var _story_mode := "intro"  # "intro": 오프닝 / "ending": 엔딩
var story_layer: CanvasLayer
var _story_title: Label
var _story_body: Label
var _story_buttons: HBoxContainer
var _grandpa_timer := 0.0


func _apply_story_camera() -> void:
	# 숲 구간(마을 이동 전)에는 카메라를 숲 안에 가둔다.
	# 숲이 화면보다 넓으므로 주인공을 따라 옆으로 스크롤된다.
	# 마을로 이동하는 travel 단계부터는 전체 맵 카메라로 풀린다.
	var cam: Camera2D = m.player.get_node("Camera")
	cam.zoom = Vector2(m.CAMERA_ZOOM, m.CAMERA_ZOOM)
	if GameData.story_phase in ["enter", "approach", "equip", "chop", "path", "map", "rock"]:
		cam.limit_left = 0
		cam.limit_top = m.TILE
		cam.limit_right = m.STORY_FOREST_W * m.TILE
		cam.limit_bottom = 23 * m.TILE
		cam.position_smoothing_enabled = true
	else:
		m._free_camera_limits(cam)
		cam.position_smoothing_enabled = true


func _apply_story_visibility() -> void:
	# 숲 구간(마을 이동 전)엔 집/건물류가 어느 방향에서도 보이지 않는다.
	# 마을로 이동하는 travel 단계부터는 마을이 보여야 하므로 표시한다.
	var show := GameData.story_phase not in ["enter", "approach", "equip", "chop", "path", "map", "rock"]
	for pos: Vector2i in m.obj_nodes:
		# 부지 앵커로 만든 집 노드는 objects에 없다 -> house로 간주
		var kind: String = m.objects[pos].kind if m.objects.has(pos) else "house"
		if kind in ["house", "housesite", "board", "sign", "barn", "barn_block",
				"art_block", "cave"]:
			m.obj_nodes[pos].visible = show


func _plant_story_forest() -> void:
	# ① 4줄 폭의 흙길을 낸다 (본길 + 갈림길의 북/남 갈래 + 마을 큰길 연결로)
	#    길을 내면서 그 자리에 미리 생성된 나무·돌은 치운다 (길이 막히면 안 된다)
	for y in range(m.STORY_ROAD_Y0, m.STORY_ROAD_Y1 + 1):
		for x in range(m.STORY_ROAD_X0, m.STORY_ROAD_X1 + 1):
			_carve_road(Vector2i(x, y))
	for y in range(10, m.STORY_ROAD_Y0):              # 북쪽 갈래 (막다른 길)
		for x in range(m.STORY_FORK.x - 1, m.STORY_FORK.x + 3):
			_carve_road(Vector2i(x, y))
	for y in range(m.STORY_ROAD_Y1 + 1, 22):          # 남쪽 갈래 (막다른 길)
		for x in range(m.STORY_FORK.x - 1, m.STORY_FORK.x + 3):
			_carve_road(Vector2i(x, y))
	for y in range(9, m.STORY_ROAD_Y0):               # 마을 큰길로 오르는 연결로
		for x in range(m.STORY_LINK_X, m.STORY_LINK_X + 4):
			_carve_road(Vector2i(x, y))
	for y in [8, 9]:                                # 숲을 빠져나와 마을 큰길로 이어지는 길
		for x in range(m.STORY_LINK_X, 60):
			_carve_road(Vector2i(x, y))

	# ② 길 양옆은 울타리로 막는다 — 길을 벗어날 수 없다 (숲으로는 못 들어간다)
	for x in range(m.STORY_ROAD_X0, m.STORY_ROAD_X1 + 2):
		var at_fork: bool = x >= m.STORY_FORK.x - 1 and x <= m.STORY_FORK.x + 2
		var at_link: bool = x >= m.STORY_LINK_X and x <= m.STORY_LINK_X + 3
		if not at_fork and not at_link:
			_story_fence(Vector2i(x, m.STORY_ROAD_Y0 - 1))   # 위쪽 (갈래·연결로는 열어 둔다)
		if not at_fork:
			_story_fence(Vector2i(x, m.STORY_ROAD_Y1 + 1))   # 아래쪽
	for y in range(9, m.STORY_ROAD_Y0):               # 북쪽 갈래 양옆 + 막다른 끝
		_story_fence(Vector2i(m.STORY_FORK.x - 2, y))
		_story_fence(Vector2i(m.STORY_FORK.x + 3, y))
	for x in range(m.STORY_FORK.x - 2, m.STORY_FORK.x + 4):
		_story_fence(Vector2i(x, 9))
	for y in range(m.STORY_ROAD_Y1 + 1, 22):          # 남쪽 갈래 양옆 + 막다른 끝
		_story_fence(Vector2i(m.STORY_FORK.x - 2, y))
		_story_fence(Vector2i(m.STORY_FORK.x + 3, y))
	for x in range(m.STORY_FORK.x - 2, m.STORY_FORK.x + 4):
		_story_fence(Vector2i(x, 22))
	for y in range(9, m.STORY_ROAD_Y0):               # 연결로 양옆
		_story_fence(Vector2i(m.STORY_LINK_X - 1, y))
		_story_fence(Vector2i(m.STORY_LINK_X + 4, y))
	for y in range(m.STORY_ROAD_Y0, m.STORY_ROAD_Y1 + 1):   # 본길 양 끝
		_story_fence(Vector2i(m.STORY_ROAD_X1 + 1, y))
		_story_fence(Vector2i(m.STORY_ROAD_X0 - 1, y))

	# ③ 길을 가로막고 선 나무 — 베어야만 지나갈 수 있다.
	#    길목에서는 길이 두 줄로 좁아지므로 나무 두 그루면 막힌다.
	for gx: int in m.STORY_GATE_XS:
		_story_narrow(gx, "tree", m.TREE_HP)

	# ④ 퀘스트 5: 커다란 바위 두 개가 좁아진 길을 막는다
	_story_narrow(m.STORY_ROCK.x, "bigrock", m.BIGROCK_HP)

	# ⑤ 길 바깥의 숲: 서로 겹치지 않게 간격을 지켜 세운다 (울타리 너머 풍경)
	for y in range(1, 23):
		for x in range(3, m.STORY_FOREST_W):
			var pos := Vector2i(x, y)
			if m.grid[y][x].ground != "grass" or m.objects.has(pos):
				continue
			var h := m._hash01(x, y)
			if h < 0.55:
				if m._nature_clear(pos, "tree"):
					var tr := {"kind": "tree", "hp": m.TREE_HP}
					if m._hash01(x * 17 + 2, y * 23 + 5) < 0.12:
						tr["apple"] = true  # 일부 나무에만 사과 3개가 열린다
					m.objects[pos] = tr
			elif h > 0.93:
				if m._nature_clear(pos, "rock"):
					m.objects[pos] = {"kind": "rock", "hp": m.ROCK_HP}
			elif h > 0.86:
				if m._nature_clear(pos, "forage_berry"):
					m.objects[pos] = {"kind": "forage_herb" if h < 0.895 else "forage_berry",
						"hp": 0}
	_refresh_story_gates()


# 길을 낸다: 흙바닥으로 바꾸고, 그 자리에 있던 오브젝트는 치운다
func _carve_road(pos: Vector2i) -> void:
	if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.MAP_H:
		return
	m.grid[pos.y][pos.x].ground = "path"
	m.objects.erase(pos)


# 스토리용 울타리: 길을 벗어나지 못하게 막는다 (도끼로 걷어낼 수 없다)
func _story_fence(pos: Vector2i) -> void:
	if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.MAP_H:
		return
	m.objects[pos] = {"kind": "fence", "hp": 0, "fixed": true}


# 아직 뚫지 못한 길목(나무 줄) 수를 센다 — 한 칸만 베어도 그 줄은 열린 것으로 본다
# 그 자리에서 길을 두 줄로 좁히고, 남은 두 줄을 막을 것으로 채운다.
# (길이 네 줄이면 네 개를 다 캐야 하는데 초반부터 그건 지루하다)
func _story_narrow(gx: int, kind: String, hp: int) -> void:
	for y in range(m.STORY_ROAD_Y0, m.STORY_ROAD_Y1 + 1):
		var p := Vector2i(gx, y)
		if m.STORY_GATE_ROWS.has(y):
			m.objects[p] = {"kind": kind, "hp": hp}
		else:
			_story_fence(p)


func _refresh_story_gates() -> void:
	var left := 0
	for gx: int in m.STORY_GATE_XS:
		var blocked := true
		for y in range(m.STORY_ROAD_Y0, m.STORY_ROAD_Y1 + 1):
			if not m.objects.has(Vector2i(gx, y)):
				blocked = false
				break
		if blocked:
			left += 1
	GameData.story_gates_left = left


func _story_update(delta: float) -> void:
	if GameData.story_phase == "done" or Net.is_guest():
		# 스토리가 끝나도 우체부가 남아 있으면 떠나는 연출은 계속 돌린다
		# (예전에는 여기서 바로 빠져나가 편지를 전한 자리에 그대로 서 있었다)
		if not Net.is_guest() and _postman != null:
			_update_postman(delta, false)
		return
	_story_t += delta
	var story_shot := m._shot_path != "" and OS.get_environment("KYOJIN_STORY") != ""
	# 안전장치: 어떤 이유로든 연출이 끊겨 조작이 잠긴 채 남으면 풀어 준다.
	# (편지 전달 중에는 원래 잠겨 있어야 한다)
	if m.story_cutscene and not m.dialog.visible and m._name_layer == null \
			and _postman_state != "deliver":
		m._cutscene_idle += delta
		if m._cutscene_idle > 1.5:
			m._cutscene_idle = 0.0
			m.story_cutscene = false
	else:
		m._cutscene_idle = 0.0
	match GameData.story_phase:
		"enter":
			# (검증용) t를 지나는 첫 프레임에만 1회 발동
			if story_shot and _story_t >= 0.4 and _story_t - delta < 0.4:
				m.quest_ui.toggle()  # 상세 퀘스트 창 캡처
			if story_shot and _story_t >= 0.55 and _story_t - delta < 0.55:
				_snap_story("story_quest")
				m.quest_ui.close()
			if story_shot and absf(_story_t - 0.7) < delta:
				_snap_story("story_forest")
			# 숲으로 걷다가 나무에 정면으로 막히는 순간 퀘스트 1 완료
			var hit_tree := false
			if m.player.moving and m.player.bumped:
				var dirs := {"down": Vector2i(0, 1), "up": Vector2i(0, -1),
					"left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
				var ahead: Variant = m.objects.get(m.player_tile() + dirs[m.player.dir])
				hit_tree = ahead != null and ahead.kind == "tree"
			if hit_tree or (story_shot and _story_t > 0.8):
				if story_shot:   # 실제 플레이처럼 첫 나무 줄 앞까지 걸어와 있게 한다
					m.player.position = Vector2(
						(m.STORY_GATE_XS[0] - 1) * m.TILE + 16, m.STORY_LANE_Y * m.TILE + 16)
				GameData.story_phase = "approach"
				m.hud.show_message("더 이상 갈 수 없는 길인 것 같다.", 4.0)
				if story_shot:
					m.hud.quest_toast("숲 안으로 들어가보기")
					_spawn_postman()
				else:
					# 자막을 읽을 시간을 준 뒤 완료 처리 + 우체부 등장
					get_tree().create_timer(1.3).timeout.connect(func() -> void:
						m.hud.quest_toast("숲 안으로 들어가보기")
						_spawn_postman())
		"approach":
			_update_postman(delta, story_shot)
			if story_shot and _postman_state == "wait":
				# 실제 플레이와 같은 경로: 느낌표를 보고 걸어가서 E로 말을 건다
				_postman_wait_t += delta
				if _postman_wait_t >= 0.5 and _postman_wait_t - delta < 0.5:
					_snap_story("story_bang")     # 머리 위 느낌표 확인
				elif _postman_wait_t > 0.6:
					if (m.player.position - _postman.position).length() > m.POSTMAN_TALK_DIST - 8.0:
						m.player.position = m.player.position.move_toward(
							_postman.position, 220.0 * delta)
					else:
						m.harness._send_key(KEY_E)
		"equip":
			_update_postman(delta, story_shot)
			# 받은 나무도끼를 가방에서 빠른 슬롯에 넣으면 퀘스트 2 완료
			if GameData.tool_slots.has("axe"):
				GameData.story_phase = "chop"
				m.hud.quest_toast("나무도끼를 장착해보기")
				m.hud.show_message("숫자키로 도끼를 선택하고, 나무를 클릭한 뒤 E로 베어보자!", 6.0)
		"chop":
			_update_postman(delta, story_shot)
		"path":
			_update_postman(delta, story_shot)
			# 갈림길 중앙에 도착하면 지도 안내 대화 시작
			if not m.dialog.visible and m.player.position.distance_to(
					Vector2(m.STORY_FORK.x * m.TILE + 16, m.STORY_FORK.y * m.TILE + 16)) < 44.0:
				_start_fork_dialog()
		"map":
			_update_postman(delta, story_shot)
			# 지도 UI가 실제로 열린 것을 확인해야 퀘스트 완료
			if m.map_ui.visible and not _story_map_opened:
				_story_map_opened = true
			elif _story_map_opened and not m.map_ui.visible and not m.dialog.visible:
				m.hud.quest_toast("지도를 확인해보자")
				GameData.story_phase = "rock"  # 대화는 토스트 뒤에 이어진다
				get_tree().create_timer(1.4).timeout.connect(_after_map_dialog)
		"rock":
			_update_postman(delta, story_shot)
			# 안전장치: 곡괭이 대화가 도중에 끊겼으면 조작이 잠긴 채로 두지 않는다
			if _rock_intro_started and GameData.story_rock_state == 0 \
					and not m.dialog.visible:
				_end_rock_intro()
			# 길을 막은 커다란 바위를 발견하면 우체부 아저씨가 곡괭이를 보여준다
			if GameData.story_rock_state == 0 and not m.dialog.visible and not m.ui_open() \
					and m.objects.has(m.STORY_ROCK) and m.player.position.distance_to(
						Vector2(m.STORY_ROCK.x * m.TILE + 16, m.STORY_ROCK.y * m.TILE + 16)) < 110.0:
				_start_rock_dialog()
		"travel":
			_update_postman(delta, story_shot)
			# 마을 이장 근처에 도착하면 편지 전달 컷신
			if _postman_state == "follow":
				var chief := _story_chief()
				if chief != null and m.player.position.distance_to(chief.position) < 150.0:
					m.story_cutscene = true
					_postman_state = "deliver"


func _spawn_postman() -> void:
	_postman = Node2D.new()
	_postman.position = Vector2(m.STORY_ROAD_X0 * m.TILE + 16, m.STORY_LANE_Y * m.TILE + 16)
	_postman_spr = Sprite2D.new()
	_postman_spr.centered = false
	# 플레이어와 같은 밀도의 도트. 어른이라 주인공보다 조금 크게 그린다.
	_postman_spr.offset = Vector2(-64, -188)
	_postman_spr.scale = Vector2(0.56, 0.56)
	_postman_spr.texture = m.tex["npc_postman_side_0"]
	_postman.add_child(_postman_spr)
	m.world.add_child(_postman)
	_postman_state = "approach"
	# 걸어오는 동안 조작을 잠그지 않는다 — 직접 다가가 E로 말을 건다
	if m._shot_path != "" and OS.get_environment("KYOJIN_STORY") != "":
		get_tree().create_timer(0.2).timeout.connect(
			func() -> void: _snap_story("story_postman"))


func _update_postman(delta: float, story_shot: bool) -> void:
	if _postman == null:
		return
	_postman_anim += delta
	match _postman_state:
		"approach":
			# 멀리서 뚜벅뚜벅 걸어온다. 검증 시퀀스만 붙자마자 대화를 시작하고,
			# 실제 플레이에서는 옆에 서서 기다린다 (플레이어가 E로 말을 건다)
			var to_player := m.player.position - _postman.position
			if to_player.length() > m.POSTMAN_STOP_DIST:
				var far := to_player.length() > 320.0   # 멀어지면 서둘러 따라온다
				var spd := 90.0 if story_shot else (110.0 if far else 45.0)
				_postman.position += to_player.normalized() * spd * delta
				_postman_spr.texture = m.tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				_postman_spr.flip_h = to_player.x < 0
			else:
				_postman_state = "wait"
				_postman_spr.texture = m.tex["npc_postman_side_0"]
				_postman_spr.flip_h = to_player.x < 0
				if not story_shot:
					m.hud.show_message(
						"누군가 말을 걸고 싶어 한다. 가까이 가서 E를 눌러보자.", 6.0)
		"wait":
			# 느낌표를 띄운 채 서서 기다린다 (많이 멀어지면 다시 따라간다)
			var to_wait := m.player.position - _postman.position
			if to_wait.length() > m.POSTMAN_REFOLLOW_DIST:
				_postman_state = "approach"
			else:
				_postman_spr.texture = m.tex["npc_postman_side_0"]
				if absf(to_wait.x) > 4.0:
					_postman_spr.flip_h = to_wait.x < 0
		"follow":
			# 마을까지 동행: 주인공 옆에서 함께 걷고, 개척하는 동안 기다린다
			var to := m.player.position + Vector2(-42, 6) - _postman.position
			if to.length() > 14.0:
				var spd := minf(to.length() * 2.5, 160.0)
				_postman.position += to.normalized() * spd * delta
				_postman_spr.texture = m.tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				if absf(to.x) > 4.0:
					_postman_spr.flip_h = to.x < 0
			else:
				_postman_spr.texture = m.tex["npc_postman_side_0"]
		"mine_demo":
			# 퀘스트 5: 대사가 나오는 동안 커다란 바위 옆으로 걸어가 시연 위치에 선다
			var demo_pos := Vector2(m.STORY_ROCK.x * m.TILE - 20, m.STORY_ROCK.y * m.TILE + 22)
			var to_rock := demo_pos - _postman.position
			if to_rock.length() > 6.0:
				_postman.position += to_rock.normalized() * minf(to_rock.length() * 3.0, 110.0) * delta
				_postman_spr.texture = m.tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				if absf(to_rock.x) > 4.0:
					_postman_spr.flip_h = to_rock.x < 0
			else:
				_postman_spr.texture = m.tex["npc_postman_side_0"]
				_postman_spr.flip_h = false  # 바위(오른쪽)를 바라본다
		"deliver":
			# 이장에게 걸어가 편지를 전달한다
			var chief := _story_chief()
			if chief == null:
				_postman_state = "talk"
				_start_delivery_dialog()
				return
			var to2: Vector2 = chief.position + Vector2(-40, 0) - _postman.position
			if to2.length() > 8.0:
				_postman.position += to2.normalized() * 90.0 * delta
				_postman_spr.texture = m.tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				_postman_spr.flip_h = to2.x < 0
			else:
				_postman_state = "talk"
				_postman_spr.texture = m.tex["npc_postman_side_0"]
				_postman_spr.flip_h = false
				_start_delivery_dialog()
		"leave":
			# 편지를 전하고 나면 마을 북쪽 길을 따라 걸어 나간다.
			# 길찾기로 낸 경로를 밟으므로 분수·벤치·건물을 뚫고 지나가지 않는다.
			if _postman_path.is_empty():
				# 길 끝에 닿았다 — 그 자리에서 서서히 사라진다
				_postman_fade = maxf(0.0, _postman_fade - delta * 2.5)
				_postman_spr.modulate.a = _postman_fade
				_postman_spr.texture = m.tex["npc_postman_up_%d" % (int(_postman_anim * 5.0) % 2)]
				if _postman_fade <= 0.0:
					_postman.queue_free()
					_postman = null
				return
			var step: Vector2 = _postman_path[0]
			var to4 := step - _postman.position
			if to4.length() <= 4.0:
				_postman.position = step
				_postman_path.remove_at(0)
				return
			_postman.position += to4.normalized() * 70.0 * delta
			if absf(to4.x) > absf(to4.y):
				_postman_spr.texture = m.tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				_postman_spr.flip_h = to4.x < 0
			else:
				_postman_spr.texture = m.tex["npc_postman_%s_%d"
					% ["up" if to4.y < 0.0 else "down", int(_postman_anim * 5.0) % 2]]
				_postman_spr.flip_h = false


func _start_postman_dialog() -> void:
	# 1부: 인사 -> 이름 질문. 이름 입력 후 2부로 이어진다.
	if m._shot_path != "" and OS.get_environment("KYOJIN_STORY") != "":
		get_tree().create_timer(0.25).timeout.connect(
			func() -> void: _snap_story("story_dialog"))
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
		{"text": "「자네도 마을로 가는 길인가?」"},
		{"text": "「나도 마을에 가야 하는데 말이야.」"},
		{"text": "「이장님께 전할 편지가 있거든.」"},
		{"text": "「그런데 이 숲을 지나야 하거든.」"},
		{"text": "「나무가 너무 빽빽해서 혼자서는 영 쉽지가 않구먼.」"},
		{"text": "「그러고 보니, 자네 이름이 어떻게 되나?」"},
	], _show_name_input)


func _show_name_input() -> void:
	# 이름 입력: 여기서 정한 닉네임을 게임 전체에서 사용한다
	m._name_layer = CanvasLayer.new()
	m._name_layer.layer = 30
	var panel := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.91, 0.71, 0.42, 0.98)
	st.border_color = Color(0.43, 0.24, 0.11)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", st)
	panel.position = Vector2(330, 200)
	panel.size = Vector2(300, 120)
	m._name_layer.add_child(panel)
	var lab := Label.new()
	lab.text = "이름을 알려주자"
	lab.position = Vector2(0, 10)
	lab.size = Vector2(300, 20)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color(0.29, 0.16, 0.06))
	panel.add_child(lab)
	var edit := LineEdit.new()
	edit.position = Vector2(50, 40)
	edit.size = Vector2(200, 30)
	edit.max_length = 8
	edit.placeholder_text = "이름 입력 (최대 8자)"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(edit)
	var btn := Button.new()
	btn.text = "확인"
	btn.position = Vector2(110, 80)
	btn.size = Vector2(80, 28)
	btn.focus_mode = Control.FOCUS_NONE
	panel.add_child(btn)
	var confirm := func() -> void:
		var nm := edit.text.strip_edges()
		if nm == "":
			nm = "친구"
		GameData.player_name = nm
		m._name_layer.queue_free()
		m._name_layer = null
		Sound.play_sfx("sfx_ui")
		_start_postman_dialog2()
	btn.pressed.connect(confirm)
	edit.text_submitted.connect(func(_t: String) -> void: confirm.call())
	add_child(m._name_layer)
	edit.grab_focus.call_deferred()


func _start_postman_dialog2() -> void:
	# 2부: 닉네임으로 부르며 동행 제안 -> 숲을 바라보며 상황 설명 -> 도끼 전달 -> 퀘스트 안내
	var nm := GameData.player_name
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
		{"text": "「%s(이)라... 좋은 이름이구먼.」" % nm,
			"portrait": m.tex["npc_postman_portrait_happy"]},
		{"text": "「그렇다면 같이 가는 게 어떻겠나?」"},
		{"text": "「자네가 길을 만들고, 나는 옆에서 도와주지.」"},
		{"text": "(우체부 아저씨가 우거진 숲을 잠시 바라본다...)"},
		{"text": "「이 숲은 나무가 너무 많아서 그냥 지나가기는 힘들겠구먼.」"},
		{"text": "「안전하게 지나가려면 길을 조금 만들어야 할 것 같네.」"},
		{"text": "「%s, 이 나무도끼를 한번 사용해보게.」" % nm, "event": _story_give_axe},
		{"text": "「가방을 열어 도끼를 슬롯에 넣어두게.」"},
		{"text": "「숫자키를 누르면 슬롯에 넣어둔 도구를 빠르게 꺼낼 수 있다네.」"},
		{"text": "「지금 자네가 해야 할 일은 오른쪽 위에 간단하게 적혀 있을 걸세.」"},
		{"text": "「자세한 내용을 보고 싶다면 Q 키를 눌러보게.」"},
	], _end_postman_dialog)


func _story_give_axe() -> void:
	if not GameData.is_tool_unlocked("axe"):
		GameData.unlocked_tools.append("axe")
	m.hud.reward_toast("나무도끼 × 1", m.tex["icon_axe"])
	m.hud.show_message("나무도끼는 슬롯에 장착하기 전에는 쓸 수 없다.", 5.0)


func _end_postman_dialog() -> void:
	m.story_cutscene = false
	GameData.story_phase = "equip"
	m.hud.show_message("새 퀘스트: 받은 나무도끼를 가방의 슬롯에 장착해 보자 (I: 가방)", 6.0)
	if _postman != null:
		_postman_state = "follow"  # 우체부는 떠나지 않고 마을까지 동행한다


func _story_tree_chopped() -> void:
	if GameData.story_phase != "chop":
		return
	# 벌목 퀘스트 완료 (보상: 목재) -> 완료 연출 후 우체부 아저씨의 다음 대화로 자동 연결.
	# 아직 마을로 가지 않는다 — 숲길을 개척하며 갈림길까지 함께 이동한다.
	GameData.story_phase = "path"
	m.hud.quest_toast("나무를 베어보자")
	m.hud.reward_toast("목재 × %d" % m.WOOD_PER_TREE, m.tex["icon_wood"])
	get_tree().create_timer(1.6).timeout.connect(_start_travel_dialog)


func _start_travel_dialog() -> void:
	# 벌목 퀘스트 완료 직후 자동으로 이어지는 대화 (첫 벌목 직후 1회)
	# 다른 연출이 진행 중이면 그 대화를 덮어쓰지 않고 기다린다
	if m.dialog.visible or m.ui_open():
		get_tree().create_timer(1.0).timeout.connect(_start_travel_dialog)
		return
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
		{"text": "「오, 제법이구먼! 좋은 목재도 얻었고 말이야.」"},
		{"text": "「도구를 사용해야만 나무를 벨 수 있다는 걸 기억하게.」"},
		{"text": "「이렇게 나무를 베어 길을 만들면서 가면 되겠네.」"},
		{"text": "「%s, 이 숲길을 따라 가보세. 막힌 나무는 자네가 부탁하네.」" % nm},
	], func() -> void:
		m.hud.show_message("화살표를 따라 숲길을 개척하며 나아가자!", 6.0))


func _start_fork_dialog() -> void:
	# 갈림길 도착: 우체부 아저씨가 길을 둘러본 뒤 지도를 알려준다 (퀘스트: 지도 확인)
	m.story_cutscene = true
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
		{"text": "(우체부 아저씨가 갈라진 길을 둘러본다...)"},
		{"text": "「길이 여러 갈래로 나뉘었구먼.」"},
		{"text": "「이럴 때는 지도를 확인하는 게 좋다네.」"},
		{"text": "「M 키를 누르면 지도를 볼 수 있어.」"},
		{"text": "「지도에서는 자네가 지금 어디에 있는지와, 지금까지 가본 곳들을 확인할 수 있다네.」"},
	], func() -> void:
		m.story_cutscene = false
		GameData.story_phase = "map"
		m.hud.show_message("새 퀘스트: M 키를 눌러 지도를 열어 보자", 6.0))


func _after_map_dialog() -> void:
	# 지도를 확인한 뒤: 마을 방향을 함께 확인하고 이동 재개 (아직 숲길 — 카메라 잠금 유지)
	if GameData.story_phase != "rock" or _rock_intro_started:
		return  # 이미 다음 연출(바위)로 넘어갔다면 건너뛴다
	if m.dialog.visible or m.ui_open():
		get_tree().create_timer(1.0).timeout.connect(_after_map_dialog)
		return
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
		{"text": "「이제 우리가 어디쯤 있는지 알겠나?」"},
		{"text": "「마을은 이쪽 방향일세. 계속 가보세.」"},
	], func() -> void:
		m.hud.show_message("길을 따라 마을 방향으로 가보자 (화살표 방향)", 6.0))


func _start_rock_dialog() -> void:
	# 커다란 바위 발견: 우체부 아저씨가 곡괭이 채광을 보여준 뒤 곡괭이를 건네준다
	m.story_cutscene = true
	_rock_intro_started = true
	_postman_state = "mine_demo"  # 대사가 진행되는 동안 바위 옆으로 걸어간다
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
		{"text": "「이런, 하필 여기서 길이 막혀버렸구먼.」"},
		{"text": "「이 정도로 큰 돌은 그냥 지나갈 수가 없겠어.」"},
		{"text": "(우체부 아저씨가 가방에서 낡은 나무 곡괭이를 꺼낸다...)"},
		{"text": "「잠깐만 기다리게.」"},
		{"text": "「이 곡괭이라면 저 돌을 치울 수 있을 걸세.」"},
		{"text": "(우체부 아저씨가 곡괭이로 바위를 몇 번 캐 보인다...)", "event": _rock_demo},
		{"text": "「자, 한번 자네가 직접 해보게.」", "event": _story_give_pickaxe},
		{"text": "「바위도 나무와 마찬가지로 대상에 가까이 가서 E 키를 누르면 캘 수 있다네.」"},
	], _end_rock_intro)


# 곡괭이 전달 마무리 — 대화가 도중에 끊겨도 여기로 복구된다
func _end_rock_intro() -> void:
	if GameData.story_rock_state != 0:
		return
	m.story_cutscene = false
	GameData.story_rock_state = 1
	if not GameData.is_tool_unlocked("pickaxe"):
		GameData.unlocked_tools.append("pickaxe")  # 대화를 스킵해도 지급 보장
	if _postman != null:
		_postman_state = "follow"
	m.hud.show_message("곡괭이를 가방(I) 슬롯에 장착하고, 바위를 클릭한 뒤 E로 캐보자!", 6.0)


func _rock_demo() -> void:
	# 채광 시연: 바위에 곡괭이질 3번 (효과음 + 돌조각, 바위는 줄지 않는다)
	for i in 3:
		get_tree().create_timer(0.35 + 0.5 * i).timeout.connect(func() -> void:
			if m.objects.has(m.STORY_ROCK):
				Sound.play_sfx("sfx_pick", 0.15)
				m.spawn_particles(m.STORY_ROCK, "stone"))


func _story_give_pickaxe() -> void:
	if not GameData.is_tool_unlocked("pickaxe"):
		GameData.unlocked_tools.append("pickaxe")
	m.hud.reward_toast("낡은 나무 곡괭이 × 1", m.tex["icon_pickaxe"])
	m.hud.show_message("곡괭이는 슬롯에 장착하기 전에는 쓸 수 없다.", 5.0)


func _story_rock_mined() -> void:
	# 커다란 바위를 모두 캐면: 돌 획득 -> 우체부 아저씨의 칭찬 -> 곡괭이 돌려주기 목표
	if GameData.story_phase != "rock" or GameData.story_rock_state != 1:
		return
	GameData.story_rock_state = 2
	m.hud.reward_toast("돌 × %d" % m.BIGROCK_STONE, m.tex["icon_stone"])
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if m.dialog.visible or m.ui_open():
			return  # 창이 열려 있으면 말을 걸 때 같은 안내가 나온다
		m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
			{"text": "「잘했네. 이제 길이 열렸구먼.」"},
		], func() -> void:
			m.hud.show_message("우체부 아저씨에게 곡괭이를 돌려주자 (E: 대화)", 6.0)))


func _start_pickaxe_return_dialog() -> void:
	# 곡괭이를 돌려주려 하면 정식으로 건네준다 -> 퀘스트 5 완료, 마을로 출발
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.story_cutscene = true
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
		{"text": "(곡괭이를 우체부 아저씨에게 돌려주려 했다...)"},
		{"text": "「아, 그건 자네가 가지게.」",
			"portrait": m.tex["npc_postman_portrait_happy"]},
		{"text": "「앞으로도 이런 돌을 만날 일이 있을 테니 잘 써보게.」"},
		{"text": "「그럼 %s, 이제 마을로 가 보세나!」" % nm},
	], _end_rock_quest)


func _end_rock_quest() -> void:
	# 퀘스트 5 완료: 곡괭이 정식 획득. 이후 튜토리얼 없이 마을로 향한다.
	m.story_cutscene = false
	GameData.story_rock_state = 3
	GameData.story_phase = "travel"
	m.hud.quest_toast("마을로 가는 길을 열어보자")
	m.hud.reward_toast("나무 곡괭이 (정식 획득)", m.tex["icon_pickaxe"])
	_apply_story_camera()
	_apply_story_visibility()
	m.hud.show_message("우체부 아저씨와 함께 마을로 가자! (화살표 방향)", 6.0)
	m.save_now()


# 동행 중 우체부에게 말을 걸면 지금 단계에 맞는 짧은 안내를 해 준다.
# 도끼 사용법 설명은 아직 장착 전(equip 단계)에만 나온다 — 이후엔 반복하지 않는다.
func _talk_to_postman() -> void:
	match GameData.story_phase:
		"equip":
			m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
				{"text": "「그건 나무를 베기 위한 도구라네.」"},
				{"text": "「숲을 지나가려면 그 도끼로 나무를 베어 길을 만들어야 할 걸세.」"},
				{"text": "「가방을 열어 도끼를 슬롯에 넣어두게.」"},
				{"text": "「숫자키를 누르면 슬롯에 넣어둔 도구를 빠르게 꺼낼 수 있다네.」"},
			], Callable())
		"chop":
			m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
				{"text": "「도끼를 챙겼구먼. 앞의 나무를 골라 베어보게.」"},
			], Callable())
		"path":
			m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
				{"text": "「이 숲길을 따라 가보세. 막힌 나무는 자네가 부탁하네.」"},
			], Callable())
		"map":
			m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
				{"text": "「M 키를 누르면 지도를 볼 수 있다네.」"},
			], Callable())
		"rock":
			match GameData.story_rock_state:
				1:
					m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
						{"text": "「곡괭이도 도끼처럼 가방(I)에서 슬롯에 넣고 숫자키로 꺼내야 쓸 수 있다네.」"},
						{"text": "「준비되면 바위를 클릭한 뒤 E 키로 캐보게.」"},
					], Callable())
				2:
					_start_pickaxe_return_dialog()
				_:
					m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
						{"text": "「길을 따라 계속 가보세.」"},
					], Callable())
		_:
			m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
				{"text": "「마을은 동쪽일세. 같이 가세나.」"},
			], Callable())


func _start_u_intro_dialog() -> void:
	if m.dialog.visible or m.ui_open():
		# 다른 창이 열려 있으면 잠시 뒤에 다시 시도
		get_tree().create_timer(2.0).timeout.connect(_start_u_intro_dialog)
		return
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_normal"], [
		{"text": "「계속 같은 일을 하다 보면 자연스럽게 실력이 늘기도 한다네.」"},
		{"text": "「자신의 능력이 얼마나 늘었는지는 U를 눌러 확인해보게.」"},
	], func() -> void:
		m.hud.show_message("U 키를 눌러 능력치 창을 확인해 보자", 6.0))


func _update_u_intro() -> void:
	# U 안내: 창을 실제로 열어본 뒤 닫으면 완료 처리하고 스토리로 복귀
	if GameData.u_intro_state == 1 and m.stats_ui.visible:
		GameData.u_intro_state = 2
	elif GameData.u_intro_state == 2 and not m.stats_ui.visible:
		GameData.u_intro_state = 3
		m.hud.quest_toast("자신의 능력 확인해보기")


func _story_chief() -> Node2D:
	for n in m.npcs:
		if n.id == "chief":
			return n
	return null


func _start_delivery_dialog() -> void:
	var chief_normal: Texture2D = m.tex["npc_chief_portrait_normal"]
	var chief_happy: Texture2D = m.tex["npc_chief_portrait_happy"]
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
		{"text": "「이장님! 편지를 가지고 왔습니다.」"},
		{"text": "「오, 우체부 양반. 그 험한 숲길을 뚫고 왔는가!」",
			"name": "이장 덕수", "portrait": chief_normal},
		{"text": "「여기 %s(이)가 길을 열어 준 덕분입니다.」" % nm},
		{"text": "「%s(이)라고 했나. 교진 마을에 온 것을 환영하네!」" % nm,
			"name": "이장 덕수", "portrait": chief_happy},
		{"text": "「마을 서쪽 큰길가에 빈 집터가 하나 있네. 자네가 쓰게.」",
			"name": "이장 덕수", "portrait": chief_happy},
		{"text": "「그리고 이건 새로 온 사람에게 주는 우리 마을의 선물일세.」",
			"name": "이장 덕수", "portrait": chief_normal, "event": _story_give_hoe},
		{"text": "「호미로 땅을 갈아 밭을 만들면, 이 마을에서 살아갈 수 있을 걸세.」",
			"name": "이장 덕수", "portrait": chief_happy},
	], _end_delivery)


func _story_give_hoe() -> void:
	# 정착 준비: 이장이 환영 선물로 호미를 건넨다 (밭갈기 목표의 시작)
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")
	m.hud.reward_toast("호미 × 1", m.tex["icon_hoe"])
	m.hud.show_message("호미는 가방(I)에서 슬롯에 넣어야 쓸 수 있다.", 5.0)


func _end_delivery() -> void:
	m.story_cutscene = false
	GameData.story_phase = "done"
	_apply_story_camera()
	_apply_story_visibility()
	m.hud.quest_toast("이장에게 편지 전달")
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")  # 대화를 스킵해도 지급 보장
	m.hud.show_message("메인 스토리 1 완료! 호미로 밭을 갈고, 집터(E)에 집을 지어 정착하자.", 6.0)
	if _postman != null:
		_postman_path = m._tile_path(
			Vector2i(int(_postman.position.x / m.TILE), int(_postman.position.y / m.TILE)),
			Vector2i(m.VILLAGE_EXIT_X, 1))
		_postman_fade = 1.0
		_postman_state = "leave"
	m.save_now()


func _snap_story(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(m._shot_path + name + ".png")


func _show_intro() -> void:
	m.hud.visible = false
	m.fade_rect.color.a = 0.0  # 농장이 보이는 채로 편지지 연출
	_story_mode = "intro"
	_story_pages = m.STORY_PAGES
	_build_story_ui()
	_story_idx = 0
	_show_story_page()


func _build_story_ui() -> void:
	story_layer = CanvasLayer.new()
	story_layer.layer = 60
	add_child(story_layer)

	# 양피지 편지 패널 (밝은 배경 + 진한 글씨)
	var panel := PanelContainer.new()
	panel.position = Vector2(210, 90)
	panel.custom_minimum_size = Vector2(540, 315)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.88, 0.74)
	style.border_color = Color(0.55, 0.42, 0.26)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	story_layer.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	_story_title = Label.new()
	_story_title.add_theme_color_override("font_color", Color(0.5, 0.32, 0.12))
	_story_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_story_title)

	_story_body = Label.new()
	_story_body.add_theme_color_override("font_color", Color(0.24, 0.17, 0.09))
	_story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_story_body)

	_story_buttons = HBoxContainer.new()
	_story_buttons.add_theme_constant_override("separation", 10)
	_story_buttons.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_story_buttons)


func _show_story_page() -> void:
	for c in _story_buttons.get_children():
		c.queue_free()

	# 페이지 번호 (왼쪽) + 버튼 (오른쪽). 오프닝은 마지막에 환영 페이지가 하나 더 있다
	var total := _story_pages.size() + (1 if _story_mode == "intro" else 0)
	var pnum := Label.new()
	pnum.text = "%d / %d" % [_story_idx + 1, total]
	pnum.add_theme_color_override("font_color", Color(0.62, 0.5, 0.34))
	_story_buttons.add_child(pnum)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_buttons.add_child(spacer)

	if _story_idx > 0:
		_story_add_button("< 이전", _prev_story_page)
	if _story_idx < _story_pages.size():
		var page: Array = _story_pages[_story_idx]
		_story_title.text = page[0]
		_story_body.text = page[1]
		if _story_mode != "intro" and _story_idx == _story_pages.size() - 1:
			_story_add_button("농장 생활 계속하기", _close_story)
		else:
			_story_add_button("다음 >", _next_story_page)
			_story_add_button("건너뛰기 >>", func() -> void:
				Sound.play_sfx("sfx_ui")
				_story_idx = _story_pages.size() - (0 if _story_mode == "intro" else 1)
				_show_story_page())
	else:
		_story_title.text = "교진 마을로 가는 길"
		_story_body.text = "가진 것은 할아버지의 낡은 연구 노트(N) 하나.\n\n마을로 가려면 저 우거진 숲을\n지나야 한다고 한다.\n\n화면 위 '목표'를 따라 천천히 나아가자!"
		_story_add_button("시작하기", _end_intro)


func _prev_story_page() -> void:
	Sound.play_sfx("sfx_ui")
	_story_idx -= 1
	_show_story_page()


# 부지/엔딩 스토리 닫기 (오프닝과 달리 튜토리얼로 이어지지 않는다)
func _close_story() -> void:
	Sound.play_sfx("sfx_ui")
	if story_layer != null:
		story_layer.queue_free()
		story_layer = null
	m.hud.visible = true


# 최후의 연금술 (연구 노트에서 재료 7종을 모두 모으면 실행 가능)
func show_ending() -> void:
	GameData.ending_seen = true
	m.save_now()
	m.hud.visible = false
	_story_mode = "ending"
	var kills := 0
	for k in GameData.mob_kills:
		kills += int(GameData.mob_kills[k])
	var fish_n := 0
	for k in GameData.fish_caught:
		fish_n += int(GameData.fish_caught[k])
	var prog: Dictionary = GameData.note_progress()
	_story_pages = m.ENDING_PAGES.duplicate()
	_story_pages.append(["연구의 기록",
		"함께한 날: %d일째\n연구 노트: %d/%d 페이지\n낚은 물고기: %d마리 · 처치한 몬스터: %d\n만든 요리: %d종류\n\n...그리고 교진 마을의 나날은 계속된다." %
		[GameData.day, int(prog.filled), int(prog.total), fish_n, kills,
		GameData.recipes_cooked.size()]])
	_build_story_ui()
	_story_idx = 0
	_show_story_page()


func _story_add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_story_buttons.add_child(b)


func _next_story_page() -> void:
	Sound.play_sfx("sfx_ui")
	_story_idx += 1
	_show_story_page()


func _end_intro() -> void:
	if story_layer != null:
		story_layer.queue_free()
		story_layer = null
	m.hud.visible = true
	var tw := create_tween()
	tw.tween_property(m.fade_rect, "color:a", 0.0, 0.6)
	# 숲 앞에서 잠시 멈춰 할아버지의 말을 떠올리는 연출 (퀘스트 1은 그 후에 시작)
	if GameData.story_phase == "enter":
		tw.tween_callback(_start_forest_monologue)


func _start_forest_monologue() -> void:
	m.story_cutscene = true
	m.dialog.open_seq("나", null, [
		{"text": "(눈앞에 우거진 숲이 펼쳐져 있다...)"},
		{"text": "(문득, 할아버지가 하셨던 말이 떠오른다.)"},
		{"text": "『집으로 가는 길이 조금 힘들 거다.』"},
		{"text": "(그때는 무슨 뜻인지 몰랐는데...)"},
		{"text": "(...이제야 알 것 같다.)"},
		{"text": "(그래도 집으로 가려면, 이 숲을 지나가는 수밖에 없다.)"},
	], _end_forest_monologue)


func _end_forest_monologue() -> void:
	m.story_cutscene = false
	m.hud.show_message("퀘스트 시작: 숲 안으로 들어가 보자", 6.0)


func _skip_tutorial() -> void:
	GameData.tutorial = {"active": false}
	GameData.unlock_all_tools()
	GameData.story_phase = "done"
	_apply_story_camera()
	if _postman != null:
		_postman.queue_free()
		_postman = null
	m.story_cutscene = false
	_end_intro()


func tutorial_notify(flag: String) -> void:
	var tut: Dictionary = GameData.tutorial
	if not tut.get("active", false) or tut.get(flag, true):
		return
	tut[flag] = true
	Sound.play_sfx("sfx_catch")

	# 목표 달성 보상 (돈/자원/씨앗)
	var msg := "목표 달성!"
	var reward: Dictionary = GameData.TUTORIAL_REWARDS.get(flag, {})
	var parts := []
	if reward.has("money"):
		GameData.money += int(reward.money)
		parts.append("%dG" % int(reward.money))
	if reward.has("wood"):
		GameData.wood += int(reward.wood)
		parts.append("목재 %d" % int(reward.wood))
	if reward.has("stone"):
		GameData.stone += int(reward.stone)
		parts.append("석재 %d" % int(reward.stone))
	if reward.has("seeds"):
		for sid in reward.seeds:
			GameData.seeds[sid] += int(reward.seeds[sid])
			parts.append("%s 씨앗 x%d" % [GameData.CROPS[sid].name, int(reward.seeds[sid])])
	if not parts.is_empty():
		msg += " 보상: " + ", ".join(parts)
		m.hud.reward_toast(", ".join(parts), m.tex["icon_coin"])
	if Net.is_host():
		m._broadcast_stats()

	# 새 도구 해금
	var unlocked: Array = GameData.TUTORIAL_UNLOCKS.get(flag, [])
	if not unlocked.is_empty():
		var names := []
		for id in unlocked:
			if not GameData.unlocked_tools.has(id):
				GameData.unlocked_tools.append(id)
			names.append(GameData.TOOL_KOR[id])
		msg += " 새 도구 해금: " + ", ".join(names)
	m.hud.show_message(msg)

	for pair in GameData.TUTORIAL_ORDER:
		if not tut.get(pair[0], false):
			return
	tut["active"] = false
	m.dialog.open("기본 안내 완료!",
		"이제 진짜 농장 생활 시작이다!\n\n[기본 키]\nE: 상호작용 (대화/가게 들어가기/취침/쓰다듬기)\nF: 말 타기 / Tab: 씨앗 바꾸기 / F5: 저장 / Esc: 메뉴\n\n집 안 **조합대(E)** 에서는 연금술을 할 수 있다.\n사고 파는 일은 마을 가게 **안** 계산대에서 E.\n주민, 의뢰 게시판도 잊지 말자.\n계절이 바뀌기 전에 수확을 끝낼 것!",
		[["좋아!", _open_grandpa_letter]])


func _open_grandpa_letter() -> void:
	m.dialog.close()
	var q: Dictionary = GameData.grandpa_current()
	if q.is_empty():
		return
	GameData.grandpa_seen = true
	Sound.play_sfx("sfx_ui")
	m.dialog.open("할아버지의 부탁 — %s" % q.name,
		"%s\n\n· %s" % [q.letter, q.desc],
		[["해보겠습니다", null]], m.tex.get("icon_note"))


func _grandpa_update(delta: float) -> void:
	if GameData.tutorial.get("active", false) or m.ui_open():
		return
	if not GameData.grandpa_seen and not GameData.grandpa_all_done():
		_grandpa_timer = 0.0
		_open_grandpa_letter()
		return
	_grandpa_timer += delta
	if _grandpa_timer < 0.5:
		return
	_grandpa_timer = 0.0
	if not GameData.grandpa_ready():
		return
	_finish_grandpa()


func _finish_grandpa() -> void:
	var q: Dictionary = GameData.grandpa_current()
	if q.is_empty():
		return
	GameData.grandpa_step += 1
	Sound.play_sfx("sfx_catch")
	var parts := []
	var reward: Dictionary = q.get("reward", {})
	if reward.has("money"):
		GameData.money += int(reward.money)
		parts.append("%dG" % int(reward.money))
	if reward.has("wood"):
		GameData.wood += int(reward.wood)
		parts.append("목재 %d" % int(reward.wood))
	if reward.has("stone"):
		GameData.stone += int(reward.stone)
		parts.append("석재 %d" % int(reward.stone))
	if reward.has("seeds"):
		for sid in reward.seeds:
			GameData.seeds[sid] += int(reward.seeds[sid])
			parts.append("%s 씨앗 x%d" % [GameData.CROPS[sid].name, int(reward.seeds[sid])])
	if not parts.is_empty():
		m.hud.reward_toast(", ".join(parts), m.tex["icon_coin"])
	m.hud.quest_toast("할아버지의 부탁 — %s" % q.name)
	if Net.is_host():
		m._broadcast_stats()
	m.save_now()

	# 다음 부탁 편지를 바로 이어서 보여 준다
	if GameData.grandpa_all_done():
		m.dialog.open("할아버지의 마지막 부탁",
			"노트의 빈 장이 스스로 넘어가며,\n마지막 한 장에 이렇게 적혀 있었다.\n\n"
			+ "\"여기까지 와 주어 고맙구나.\n남은 것은 하나 — 세상에 없는 재료를 만드는 일.\n"
			+ "일곱 가지 전설의 재료를 모으거라.\n노트(N)가 길을 알려 줄 게다.\"",
			[["반드시 찾아낼게요", null]], m.tex.get("icon_note"))
	else:
		_open_grandpa_letter()
