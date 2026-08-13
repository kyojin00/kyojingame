# 메인 스토리 연출 — 오프닝부터 마을 도착까지.
#
# 게임 규칙이 아니라 **각본**이다. 우체부와 함께 걷고, 나무를 베고, 바위를
# 깨고, 편지를 전하는 동안의 카메라·대화·등장인물 움직임을 여기서 다룬다.
#
# 진행 상태는 GameData.story_step 하나로 정해진다. `_story_update`가 매 프레임
# 그 단계를 보고 무엇을 할지 고른다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinStory
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
	elif GameData.story_phase == "travel":
		# 가리개 숲의 좁은 길을 지나는 동안 — 마을 전경은 아직 보여 주지 않는다.
		# 마을 어귀(작별 인사)에서 제한이 풀리며 시야가 극적으로 넓어진다.
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = 60 * m.TILE
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
	for y in range(9, m.STORY_ROAD_Y0):               # 연결로 양옆 — 우거진 나무 벽
		_story_tree_wall(Vector2i(m.STORY_LINK_X - 1, y))
		_story_tree_wall(Vector2i(m.STORY_LINK_X + 4, y))
	for y in range(m.STORY_ROAD_Y0, m.STORY_ROAD_Y1 + 1):   # 본길 양 끝
		_story_fence(Vector2i(m.STORY_ROAD_X1 + 1, y))
		_story_fence(Vector2i(m.STORY_ROAD_X0 - 1, y))

	# ⑥ 마을 초입 가리개 숲: 큰길(y8~10) 양옆을 벨 수 없는 나무로 빽빽하게
	#    채워, 이 좁은 길을 다 지나기 전에는 마을 전경이 보이지 않는다.
	#    마을로 드는 길은 이 큰길 하나뿐이다.
	for x in range(40, 60):
		_story_tree_wall(Vector2i(x, 7))
		_story_tree_wall(Vector2i(x, 11))
	for y in range(1, 15):
		for x in range(40, 60):
			var pos6 := Vector2i(x, y)
			if m.grid[y][x].ground != "grass" or m.objects.has(pos6):
				continue
			if m._hash01(x * 13 + 3, y * 17 + 9) < 0.85 and m.worldgen._nature_clear(pos6, "tree"):
				m.objects[pos6] = {"kind": "tree", "hp": m.TREE_HP, "fixed": true}

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
				if m.worldgen._nature_clear(pos, "tree"):
					var tr := {"kind": "tree", "hp": m.TREE_HP}
					if m._hash01(x * 17 + 2, y * 23 + 5) < 0.12:
						tr["apple"] = true  # 일부 나무에만 사과 3개가 열린다
					m.objects[pos] = tr
			elif h > 0.93:
				if m.worldgen._nature_clear(pos, "rock"):
					m.objects[pos] = {"kind": "rock", "hp": m.ROCK_HP}
			elif h > 0.86:
				if m.worldgen._nature_clear(pos, "forage_berry"):
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


# 가리개 숲의 나무 벽: 벨 수 없는 나무 한 그루 (풀밭에만 세운다)
func _story_tree_wall(pos: Vector2i) -> void:
	if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.MAP_H:
		return
	if m.grid[pos.y][pos.x].ground != "grass":
		return
	m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP, "fixed": true}


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
			and _postman_state != "deliver" and not _chief_greet:
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
			# 마을 어귀에 다다르면 우체부가 함께 이장에게 가자고 한다
			if _postman_state == "follow" and not m.dialog.visible \
					and m.player_tile().x >= 58:
				m.story_cutscene = true
				_postman_state = "talk"
				_start_arrival_dialog()
		"deliver":
			_update_postman(delta, false)   # 우체부가 떠나는 연출은 계속 돌린다
		"home_open":
			_update_postman(delta, false)   # 우체부가 떠나는 연출은 계속 돌린다
		"greet":
			_update_postman(delta, false)
			_update_home_greet(delta)       # 이장이 문 앞으로 걸어온다


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
			# 이장에게 직접 걸어가 편지를 전달한다 (플레이어는 따라간다)
			var chief := _story_chief()
			if chief == null:
				if not m.dialog.visible:
					_postman_state = "talk"
					_start_delivery_dialog()
				return
			var to2: Vector2 = chief.position + Vector2(-40, 0) - _postman.position
			if to2.length() > 8.0:
				_postman.position += to2.normalized() * 90.0 * delta
				_postman_spr.texture = m.tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				_postman_spr.flip_h = to2.x < 0
			elif not m.dialog.visible:
				# 플레이어가 다른 대화 중이면 그 대화가 끝날 때까지 기다린다
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
				m.renderer.spawn_particles(m.STORY_ROCK, "stone"))


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
	m.saveio.save_now()


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


# 마을 어귀: 우체부는 떠나지 않는다 — 함께 이장에게 편지를 전하러 간다
func _start_arrival_dialog() -> void:
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
		{"text": "「다 왔군! 여기가 교진 마을일세.」"},
		{"text": "「그럼 이장님께 편지를 전해 드려야지.\n광장 근처에 계실 걸세 — 같이 가세나!」"},
	], _end_arrival)


func _end_arrival() -> void:
	m.story_cutscene = false
	GameData.story_phase = "deliver"
	_apply_story_camera()
	_apply_story_visibility()
	m.hud.quest_toast("마을 도착")
	m.hud.show_message("우체부 아저씨를 따라 이장님께 가자. (화살표 방향)", 6.0)
	if _postman != null:
		_postman_state = "deliver"   # 이장에게 곧장 걸어간다
	m.saveio.save_now()


# 우체부가 이장에게 **직접** 편지를 전한다 — 플레이어는 곁에서 지켜본다.
# (예전에는 우체부가 떠나고 플레이어가 대신 전달했는데, 그 과정은 없앴다)
func _start_delivery_dialog() -> void:
	var chief_normal: Texture2D = m.tex["npc_chief_portrait_normal"]
	var chief_happy: Texture2D = m.tex["npc_chief_portrait_happy"]
	var post_normal: Texture2D = m.tex["npc_postman_portrait_normal"]
	var post_happy: Texture2D = m.tex["npc_postman_portrait_happy"]
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.story_cutscene = true
	m.dialog.open_seq("우체부 아저씨", post_happy, [
		{"text": "「이장님! 편지 배달 왔습니다.」"},
		{"text": "「오, 우체부 양반! 먼 길 오느라 고생했네.」",
			"name": "이장 덕수", "portrait": chief_happy},
		{"text": "(우체부 아저씨가 이장님께 편지를 건넸다.)",
			"name": "", "portrait": null},
		{"text": "「요즘 마을은 좀 어떻습니까? 오는 길에 보니\n광장이 영 한산하던데요.」",
			"name": "우체부 아저씨", "portrait": post_normal},
		{"text": "「보다시피 조용하네... 젊은 사람들이 하나둘 떠나서\n남은 건 빈터뿐이라네.」",
			"name": "이장 덕수", "portrait": chief_normal},
		{"text": "「그래도 마을로 드는 숲길이 훤히 뚫려 있던데요!\n여기 이 친구가 열었지 뭡니까.」",
			"name": "우체부 아저씨", "portrait": post_happy},
		{"text": "「호오... 편지에도 자네 얘기가 적혀 있구먼.\n%s(이)라고 했나. 교진 마을에 온 것을 환영하네!」" % nm,
			"name": "이장 덕수", "portrait": chief_happy},
		{"text": "「자네 할아버지가 지내던 집이 마을 서쪽에 그대로 있네.\n오래 비워 둬서 낡았네만... 오늘부터 자네 집일세.」",
			"name": "이장 덕수", "portrait": chief_happy, "event": _story_open_home},
		{"text": "「그럼 나는 다음 배달을 가야겠구먼.」",
			"name": "우체부 아저씨", "portrait": post_normal},
		{"text": "「자네와의 숲길, 즐거웠네. 잘 지내게, %s!」" % nm,
			"name": "우체부 아저씨", "portrait": post_happy},
	], _end_delivery)


# 이장이 할아버지의 집을 내어 준다 — 낡은 침대와 책상이 남아 있다
func _story_open_home() -> void:
	if GameData.house_lv >= 1:
		return
	GameData.house_lv = 1
	GameData.has_bed = true    # 할아버지가 쓰던 낡은 침대
	GameData.bed_lv = 0
	m.objnode._remove_object(m.HOME_SITE)
	m.worldgen._fill_building(m.HOME_ANCHOR)
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("할아버지의 집을 물려받았다")


func _story_give_hoe() -> void:
	# 정착 준비: 이장이 환영 선물로 호미와 씨앗을 건넨다 (밭갈기 목표의 시작)
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")
	GameData.seeds["potato"] += 3
	m.hud.reward_toast("호미 × 1 · 감자 씨앗 × 3", m.tex["icon_hoe"])
	m.hud.show_message("호미는 가방(I)에서 슬롯에 넣어야 쓸 수 있다.", 5.0)


func _end_delivery() -> void:
	m.story_cutscene = false
	GameData.story_phase = "home_open"
	_story_open_home()   # 대화를 스킵해도 집은 열린다
	_apply_story_camera()
	_apply_story_visibility()
	m.hud.quest_toast("편지 전달 완료")
	m.hud.show_message("마을 서쪽, 이장님이 내어 준 집에 들어가 보자. (문 앞에서 E)", 6.0)
	# 인사를 마친 우체부는 마을 북쪽 길을 따라 떠난다
	if _postman != null:
		_postman_path = m.npcmgr._tile_path(
			Vector2i(int(_postman.position.x / m.TILE), int(_postman.position.y / m.TILE)),
			Vector2i(m.VILLAGE_EXIT_X, 1))
		_postman_fade = 1.0
		_postman_state = "leave"
	m.saveio.save_now()


# ---- 메인 스토리 1 끝 / 2 시작 ----
#
# 집에 처음 들어가면 스토리 1이 끝난다 (interior.open이 부른다).
# 집에서 나오면 이장이 문 앞으로 걸어와 말을 걸고, 그 대화가 스토리 2
# (밭 일구기)의 시작이다.
var _chief_greet := false     # 이장이 걸어오는 연출 중


func home_entered() -> void:
	if GameData.story_phase != "home_open":
		return
	GameData.story_phase = "greet"
	m.hud.quest_toast("새 보금자리")
	m.hud.show_message("메인 스토리 1 완료! 집을 둘러보고 밖으로 나가 보자.", 6.0)
	m.saveio.save_now()


func start_home_greet() -> void:
	if GameData.story_phase != "greet":
		return
	var chief: Variant = _story_chief()
	if chief == null:
		_start_story2_dialog()
		return
	m.story_cutscene = true
	chief.scripted = true      # 일과·배회를 멈추고 연출이 직접 움직인다
	chief.visible = true
	# 문 앞 큰길 쪽에서 걸어온다
	chief.position = m.player.position + Vector2(-24.0, 150.0)
	_chief_greet = true


func _update_home_greet(delta: float) -> void:
	if not _chief_greet:
		return
	var chief: Variant = _story_chief()
	if chief == null:
		_chief_greet = false
		_start_story2_dialog()
		return
	var to: Vector2 = m.player.position + Vector2(0.0, 30.0) - chief.position
	if to.length() > 8.0:
		chief.position += to.normalized() * minf(to.length() * 2.5, 130.0) * delta
		chief.moving = true
		chief.anim_time += delta
		if absf(to.x) > absf(to.y):
			chief.dir = "right" if to.x > 0 else "left"
		else:
			chief.dir = "down" if to.y > 0 else "up"
		chief._update_sprite()
	else:
		chief.moving = false
		chief.dir = "up"          # 플레이어를 올려다본다
		chief._update_sprite()
		_chief_greet = false
		_start_story2_dialog()


func _start_story2_dialog() -> void:
	m.story_cutscene = true
	var chief_normal: Texture2D = m.tex["npc_chief_portrait_normal"]
	var chief_happy: Texture2D = m.tex["npc_chief_portrait_happy"]
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.dialog.open_seq("이장 덕수", chief_normal, [
		{"text": "「%s! 집은 좀 둘러봤는가?」" % nm, "portrait": chief_happy},
		{"text": "「할아버지가 쓰시던 침대와 책상이 그대로 남아 있을 걸세.」"},
		{"text": "「침대는 낡았어도 쓸 만하네. 밤에는 꼭 침대에서 자게 — 어두워지면 들판에 지네가 나온다네.」"},
		{"text": "「책상은 제작대일세. 재료만 있으면 가구도 손수 만들 수 있지.」"},
		{"text": "「그나저나... 보다시피 마을이 텅 비었네. 젊은 사람들이 다 떠났거든.」"},
		{"text": "「자네가 와 준 김에 부탁 하나 함세. 우선 **상점**부터 세워 보지 않겠나?」",
			"portrait": chief_happy},
		{"text": "「목재 %d에 돌 %d... 나무를 베고 바위를 캐면 모일 걸세.」"
			% [GameData.SHOP_BUILD_WOOD, GameData.SHOP_BUILD_STONE]},
		{"text": "「재료가 모이면 광장 북쪽 상점 터의 게시판에서 짓게. 상점이 서면 민지가 와서 씨앗이며 생필품을 팔 거야.」"},
	], _end_home_greet)


func _end_home_greet() -> void:
	m.story_cutscene = false
	_chief_greet = false
	GameData.story_phase = "done"
	GameData.story2_phase = "shop"
	var chief: Variant = _story_chief()
	if chief != null:
		chief.scripted = false
	m.hud.quest_toast("메인 스토리 2 — 상점을 짓자")
	m.hud.show_message("메인 스토리 2 시작! 목재 %d·돌 %d을 모아 상점 터 게시판(광장 북쪽)에서 상점을 짓자."
		% [GameData.SHOP_BUILD_WOOD, GameData.SHOP_BUILD_STONE], 7.0)
	m.saveio.save_now()


# 상점이 서고 바닷길까지 열리면, 이장이 호미를 주며 밭 갈기를 권한다
func _start_farm_dialog() -> void:
	var chief_normal: Texture2D = m.tex["npc_chief_portrait_normal"]
	var chief_happy: Texture2D = m.tex["npc_chief_portrait_happy"]
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.dialog.open_seq("이장 덕수", chief_normal, [
		{"text": "「%s! 상점도 서고, 바닷길도 열리고... 자네 덕에 마을이 살아나는구먼!」" % nm,
			"portrait": chief_happy},
		{"text": "「이제 자네도 여기 뿌리를 내릴 차례지. 이건 우리 마을의 선물일세.」",
			"event": _story_give_hoe},
		{"text": "「호미로 집 앞 풀밭을 갈아 밭을 만들어 보게. 농사가 이 마을의 근본일세.」",
			"portrait": chief_happy},
		{"text": "「씨앗이 모자라면 상점에서 사면 되네. 급할 것 없으니 천천히 하게나.」"},
	], _end_farm_intro)


func _end_farm_intro() -> void:
	GameData.story2_phase = "farm"
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")  # 대화를 스킵해도 지급 보장
	m.hud.quest_toast("밭을 일구자")
	m.hud.show_message("호미로 밭을 갈아 농사를 시작하자! (밭 갈기 → 씨앗 → 물 → 수확)", 6.0)
	m.saveio.save_now()


# ---- 낚시꾼 퀘스트 (메인 스토리 3): 바다 · 해변 · 낚시 해금 ----
#
# 첫 수확을 마치면(마을 생활이 자리 잡으면) 전설의 황금잉어를 쫓는
# 낚시꾼이 마을 광장에 나타난다. 함께 남쪽 바위 능선으로 내려가
# 길목의 바위를 캐면 바다와 해변이 열리고, 보답으로 간이낚싯대를
# 받아 낚시가 해금된다. 황금잉어 선택지는 대사만 가른다.
var _fisher_gate_talked := false


func _fisher_node() -> Variant:
	for n in m.npcs:
		if n.id == "fisher":
			return n
	return null


func _sea_gate_center() -> Vector2:
	return Vector2(m.SEA_GATE[0].x * m.TILE + 32.0, m.SEA_GATE[0].y * m.TILE - 16.0)


func _fisher_update(delta: float) -> void:
	if Net.is_guest():
		return
	match GameData.fisher_quest:
		"":
			# 상점이 서면(메인 스토리 2의 다음 마디) 낚시꾼이 온다
			if GameData.story_phase == "done" and not m.ui_open() \
					and GameData.story2_phase == "fisher":
				_fisher_arrive()
		"open":
			# 길을 연 채로 저장했다가 불러온 경우: 보상 대화를 다시 잇는다
			if GameData.sea_open and not m.ui_open():
				_start_fisher_reward_dialog()
		"follow":
			if m.ui_open():
				return
			var fisher: Variant = _fisher_node()
			if fisher == null:
				return
			# 주인공을 따라 걷는다 (우체부 동행과 같은 느낌)
			var to: Vector2 = m.player.position + Vector2(44.0, -4.0) - fisher.position
			if to.length() > 16.0:
				fisher.position += to.normalized() * minf(to.length() * 2.2, 150.0) * delta
				fisher.moving = true
				fisher.anim_time += delta
				if absf(to.x) > absf(to.y):
					fisher.dir = "right" if to.x > 0 else "left"
				else:
					fisher.dir = "down" if to.y > 0 else "up"
				fisher._update_sprite()
			else:
				fisher.moving = false
				fisher._update_sprite()
			# 능선 길목에 다다르면 바위 앞 대화
			if not _fisher_gate_talked \
					and m.player.position.distance_to(_sea_gate_center()) < 150.0:
				_fisher_gate_talked = true
				_start_fisher_gate_dialog()


# 퀘스트 도중 저장한 게임을 불러오면 낚시꾼을 제자리에 되돌린다
func _restore_fisher() -> void:
	var fisher: Variant = _fisher_node()
	if fisher == null:
		return
	fisher.scripted = true
	match GameData.fisher_quest:
		"meet":
			fisher.position = Vector2(m.FISHER_ARRIVE.x * m.TILE + 16,
				m.FISHER_ARRIVE.y * m.TILE + 16)
		"follow":
			fisher.position = m.player.position + Vector2(44.0, -4.0)
		"open":
			fisher.position = Vector2((m.SEA_GATE[0].x - 2) * m.TILE + 16,
				(m.SEA_GATE[0].y - 1) * m.TILE + 16)


func _fisher_arrive() -> void:
	GameData.fisher_quest = "meet"
	m.npcmgr._sync_village_npcs()   # 낚시꾼은 이 퀘스트로 처음 마을에 온다
	var fisher: Variant = _fisher_node()
	if fisher != null:
		fisher.scripted = true
		fisher.visible = true
		fisher.position = Vector2(m.FISHER_ARRIVE.x * m.TILE + 16,
			m.FISHER_ARRIVE.y * m.TILE + 16)
	m.hud.quest_toast("낯선 낚시꾼이 마을에 왔다")
	m.hud.show_message("항구 차림의 낯선 사람이 마을 광장에 서 있다. 말을 걸어 보자. (E)", 6.0)
	m.saveio.save_now()


func _start_fisher_dialog() -> void:
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.dialog.open_seq("낚시꾼 철수", m.tex["npc_fisher_portrait_normal"], [
		{"text": "「오, 처음 보는 얼굴이군! 나는 낚시꾼 철수라고 하네.」",
			"portrait": m.tex["npc_fisher_portrait_happy"]},
		{"text": "「이 마을 물줄기에 **전설의 황금잉어**가 산다는 소문을 듣고 왔지.」"},
		{"text": "「그놈을 낚을 때까지 이 마을에 눌러앉을 작정이야.」"},
		{"text": "「그런데 말이지... 큰 놈은 바다를 오간다네. 남쪽 능선 너머가 바다인데, 바위가 길을 막고 있더군.」"},
		{"text": "「%s, 자네도 황금잉어에 관심이 있나?」" % nm,
			"choices": [
				["당연하다. 꼭 잡고 말 거다.", _fisher_choose.bind(1)],
				["잘 모르겠다. 아직까진 욕심이 없다.", _fisher_choose.bind(2)],
			]},
	])


func _fisher_choose(pick: int) -> void:
	GameData.fisher_choice = pick
	var first := "「하하, 좋은 눈빛이야! 그럼 우리는 경쟁자로군. 정정당당하게 겨뤄 보세!」" \
		if pick == 1 else "「욕심이 없는 것도 낚시꾼의 덕목이지. 물은 조용한 사람을 좋아하거든.」"
	m.dialog.open_seq("낚시꾼 철수", m.tex["npc_fisher_portrait_happy"], [
		{"text": first},
		{"text": "「마침 잘됐군. 같이 남쪽으로 내려가 주지 않겠나?」",
			"portrait": m.tex["npc_fisher_portrait_normal"]},
		{"text": "「듣자 하니 자네, 곡괭이 솜씨가 보통이 아니라던데.」"},
	], _end_fisher_meet)


func _end_fisher_meet() -> void:
	GameData.fisher_quest = "follow"
	_fisher_gate_talked = false
	m.hud.quest_toast("낚시꾼과 함께 바다로")
	m.hud.show_message("낚시꾼과 함께 남쪽 바위 능선으로 가자. (화살표 방향)", 6.0)
	m.saveio.save_now()


func _start_fisher_gate_dialog() -> void:
	m.dialog.open_seq("낚시꾼 철수", m.tex["npc_fisher_portrait_normal"], [
		{"text": "「여기군! 능선 너머에서 파도 소리가 들려.」"},
		{"text": "「길목의 저 커다란 바위 두 개... 자네 곡괭이라면 캐낼 수 있겠지?」"},
		{"text": "「부탁하네. 길이 열리면 보답은 톡톡히 하지!」",
			"portrait": m.tex["npc_fisher_portrait_happy"]},
	], func() -> void:
		GameData.fisher_quest = "open"
		var fisher: Variant = _fisher_node()
		if fisher != null:   # 낚시꾼은 길목 옆에서 기다린다
			fisher.position = Vector2((m.SEA_GATE[0].x - 2) * m.TILE + 16,
				(m.SEA_GATE[0].y - 1) * m.TILE + 16)
			fisher.moving = false
			fisher.dir = "right"
			fisher._update_sprite()
		m.hud.quest_toast("바닷길을 열자")
		m.hud.show_message("곡괭이로 길목의 커다란 바위를 캐자!", 5.0)
		m.saveio.save_now())


# 길목의 바위가 부서질 때마다 불린다 (tool_use) — 둘 다 캐면 보상 대화
func _sea_gate_mined() -> void:
	if GameData.fisher_quest != "open":
		return
	for p: Vector2i in m.SEA_GATE:
		if m.objects.has(p):
			m.hud.show_message("하나 더! 남은 바위를 캐자.")
			return
	# 길이 열리는 순간 능선 너머의 숲이 걷히고 바다가 드러난다
	m.worldgen._reveal_sea()
	_start_fisher_reward_dialog()


func _start_fisher_reward_dialog() -> void:
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	var brag := "「황금잉어는 강에도 바다에도 나온다더군. 먼저 낚는 쪽이 임자야!」" \
		if GameData.fisher_choice == 1 \
		else "「서두를 것 없네. 바다는 어디 안 가니까, 천천히 즐기게.」"
	m.dialog.open_seq("낚시꾼 철수", m.tex["npc_fisher_portrait_happy"], [
		{"text": "「열렸다! 이 바람, 이 냄새... 바다야!」"},
		{"text": "「고맙네, %s. 자네 덕에 길이 열렸어.」" % nm},
		{"text": "「약속한 보답일세 — 내가 손수 깎은 **간이낚싯대**야.」",
			"event": _story_give_rod},
		{"text": "「물가 어디서든 던져 보게. 입질(!)이 오면 다시 E일세.」",
			"portrait": m.tex["npc_fisher_portrait_normal"]},
		{"text": brag, "portrait": m.tex["npc_fisher_portrait_happy"]},
		{"text": "「참, 해변 모래밭에는 조개가 밀려온다네. 물때마다 주워 가게.」"},
	], _end_fisher_quest)


func _story_give_rod() -> void:
	if not GameData.is_tool_unlocked("rod"):
		GameData.unlocked_tools.append("rod")
	m.hud.reward_toast("간이낚싯대 × 1", m.tex["icon_rod"])
	m.hud.show_message("낚싯대는 가방(I)에서 슬롯에 장착해 물가에서 쓴다.", 5.0)


func _end_fisher_quest() -> void:
	GameData.fisher_quest = "done"
	if not GameData.sea_open:
		m.worldgen._reveal_sea()   # 대화를 스킵해도 바다는 열린다
	if not GameData.is_tool_unlocked("rod"):
		GameData.unlocked_tools.append("rod")  # 대화를 스킵해도 지급 보장
	if GameData.story2_phase == "fisher":
		GameData.story2_phase = "farm_talk"    # 다음: 이장이 호미를 준다
	var fisher: Variant = _fisher_node()
	if fisher != null:
		fisher.scripted = false   # 이제부터는 마을 일과(부두)대로 산다
	m.hud.quest_toast("바다 · 해변 해금!")
	m.hud.show_message("남쪽 바다가 열렸다! 물가 어디서든 낚시할 수 있다. 이장님이 자네를 찾는다더군. (E)", 7.0)
	m.saveio.save_now()


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
	m.saveio.save_now()
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
	GameData.story2_phase = "done"
	_story_open_home()   # 이장이 내어 주는 집도 바로 받는다
	# 이야기를 건너뛰면 마을과 바다도 다 열린 채 시작한다 (샌드박스)
	GameData.village_built = GameData.ALL_VILLAGE_PLOTS.duplicate()
	for pid: String in GameData.village_built:
		if m.VILLAGE_PLOTS.has(pid):
			m.worldgen._fill_building(m.VILLAGE_PLOTS[pid].anchor, pid)
	m.objnode._remove_object(m.door_tile(m.VILLAGE_PLOTS["general"].anchor))
	m.worldgen._reveal_sea()
	m.npcmgr._sync_village_npcs()
	GameData.fisher_quest = "done"
	GameData.seeds["potato"] += 3
	_apply_story_camera()
	if _postman != null:
		_postman.queue_free()
		_postman = null
	m.story_cutscene = false
	_end_intro()


func tutorial_notify(flag: String) -> void:
	# 첫 수확 = 메인 스토리 2의 마지막 목표 (안내 체크리스트와는 무관하다)
	if flag == "harvest" and GameData.story2_phase == "farm":
		GameData.story2_phase = "done"
		GameData.move_day = GameData.day   # 다음 날 아침, 이주 희망 편지가 온다
		m.hud.quest_toast("메인 스토리 2 완료!")
		m.saveio.save_now()
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
		m.netsync._broadcast_stats()

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
		m.netsync._broadcast_stats()
	m.saveio.save_now()

	# 다음 부탁 편지를 바로 이어서 보여 준다
	if GameData.grandpa_all_done():
		m.dialog.open("할아버지의 마지막 부탁",
			"노트의 빈 장이 스스로 넘어가며,\n마지막 한 장에 이렇게 적혀 있었다.\n\n"
			+ "\"여기까지 와 주어 고맙구나.\n남은 것은 하나 — 세상에 없는 재료를 만드는 일.\n"
			+ "일곱 가지 전설의 재료를 모으거라.\n노트(N)가 길을 알려 줄 게다.\"",
			[["반드시 찾아낼게요", null]], m.tex.get("icon_note"))
	else:
		_open_grandpa_letter()


# ---- 해변의 숨겨진 콘텐츠 ----
#
# 산호 조각·고대 조각은 0.1%짜리 매우 희귀한 해변 채집물.
# 처음 줍는 순간, 그 조각에 얽힌 숨겨진 이야기가 흘러나오고
# 산호 조각은 숨겨진 레시피(산호빛 차)까지 열어 준다.
func hidden_beach_find(fid: String) -> void:
	if fid == "forage_coral":
		if "dish_coral_tea" not in GameData.recipes_unlocked:
			GameData.recipes_unlocked.append("dish_coral_tea")
		m.hud.quest_toast("숨겨진 레시피 발견: 산호빛 차")
		m.dialog.open_seq("산호 조각", null, [
			{"text": "파도 사이에서 붉게 빛나는 조각을 주웠다.\n"
				+ "물에 담그자 은은한 노을빛이 번진다."},
			{"text": "할아버지의 노트 귀퉁이에 이런 낙서가 있었지 —\n"
				+ "\"바다가 꽃을 피우면, 약초와 함께 달여 보거라.\""},
			{"text": "[숨겨진 레시피를 배웠다: 산호빛 차]\n집 조리대에 새 칸이 생겼다."},
		])
	elif fid == "forage_relic":
		m.hud.quest_toast("숨겨진 이야기 발견: 물에 잠긴 마을")
		m.dialog.open_seq("고대 조각", null, [
			{"text": "모래 깊숙이 박힌 낡은 돌조각.\n"
				+ "닳아 버린 표면에 알 수 없는 무늬가 새겨져 있다."},
			{"text": "…무늬를 손끝으로 따라가자, 머릿속에\n"
				+ "본 적 없는 풍경이 스친다. 물속에 가라앉은 지붕들,\n"
				+ "그 사이를 헤엄치는 커다란 황금빛 그림자."},
			{"text": "이 바다 밑에는, 아주 오래전 가라앉은\n"
				+ "마을이 잠들어 있는지도 모른다."},
			{"text": "[숨겨진 이야기가 연구 노트(N)에 기록됐다:\n「물에 잠긴 마을」]"},
		])
	m.saveio.save_now()


# ---- 메인 스토리 5: 숲속에서 발견한 집 ----
#
# 첫 수확(스토리 2 완료) 뒤 모험가 무진이 마을로 이사 온다.
# 숲을 쏘다니던 무진이 깊은 숲의 수상한 집을 발견하고, 이장도 모르는
# 그 집에는 아픈 딸(솔이)을 돌보는 어머니(연화)가 조용히 살고 있었다.
# 이야기를 끝내면 호감도 콘텐츠(하트·선물)가 해금된다.

func _forest_update(_delta: float) -> void:
	if Net.is_guest():
		return
	# 무진의 이야기는 이사(메인 스토리 3)가 끝난 다음 날부터 이어진다 —
	# _end_move_greet가 forest_quest를 "settle"로 넘겨 준다.
	# 정착한 다음 날 아침, 숲을 쏘다니던 무진이 뭔가를 발견했다.
	if GameData.forest_quest == "settle" and GameData.day > GameData.forest_day:
		GameData.forest_quest = "found"
		m.hud.quest_toast("무진이 할 말이 있는 듯하다")


# 광장의 무진에게 말을 걸면 — 이사 인사 (모험을 좋아하는 성격)
func _start_explorer_arrive_dialog() -> void:
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.dialog.open_seq("무진", m.tex["npc_explorer_portrait_happy"], [
		{"text": "「어! 안녕? 나는 무진.\n오늘부로 이 마을 주민이 된 사람!」"},
		{"text": "「한곳에 오래 못 붙어 있는 성격인데 말이야,\n이 동네는 숲도 강도 바다도 있다며?」",
			"portrait": m.tex["npc_explorer_portrait_normal"]},
		{"text": "「당분간 여기 살면서 구석구석 모험해 볼 참이야.\n%s(이)라고? 잘 부탁해!」" % nm,
			"portrait": m.tex["npc_explorer_portrait_happy"]},
	], _end_explorer_arrive)


func _end_explorer_arrive() -> void:
	if GameData.forest_quest == "arrive":
		GameData.forest_quest = "settle"
		GameData.forest_day = GameData.day
		m.hud.quest_toast("새 주민: 모험가 무진")
		m.hud.show_message("무진이 마을에 정착했다. 내일은 또 어딜 쏘다닐까?", 5.0)
	m.saveio.save_now()


# 다음 날 — 무진이 숲 깊은 곳에서 수상한 집을 봤다며 조사를 부탁한다
func _start_explorer_found_dialog() -> void:
	m.dialog.open_seq("무진", m.tex["npc_explorer_portrait_normal"], [
		{"text": "「야, 마침 잘 왔어!\n어제 서쪽 숲을 온종일 헤집고 다녔거든?」"},
		{"text": "「그런데 숲 '깊은 곳'에 말이야...\n집이 한 채 덩그러니 있는 거야.」"},
		{"text": "「저 우거진 숲속에 누가 산다고?\n아무리 생각해도 이상하단 말이지.」"},
		{"text": "「같이 좀 알아봐 줘. 이장님이라면 뭔가 아실지도?\n나는... 그, 왠지 으스스해서 말이야.」",
			"portrait": m.tex["npc_explorer_portrait_happy"]},
	], _end_explorer_found)


func _end_explorer_found() -> void:
	if GameData.forest_quest == "found":
		GameData.forest_quest = "ask"
		m.hud.quest_toast("숲속의 집에 대해 이장에게 물어보자")
	m.saveio.save_now()


# 이장에게 물어본다 — 이장도 모르는 집
func _start_forest_ask_dialog() -> void:
	m.dialog.open_seq("이장 덕수", m.tex["npc_chief_portrait_normal"], [
		{"text": "「숲 깊은 곳에... 집이 있다고?」"},
		{"text": "「내가 이 마을 이장을 삼십 년 했네만,\n그런 집이 있단 얘기는 처음 듣는구먼.」"},
		{"text": "「빈집일 리는 없고... 영 마음에 걸리는군.\n미안하네만, 자네가 직접 가서 살펴봐 주겠나?」"},
	], _end_forest_ask)


func _end_forest_ask() -> void:
	if GameData.forest_quest == "ask":
		GameData.forest_quest = "visit"
		m.worldgen._spawn_forest_house()
		m.npcmgr._sync_village_npcs()   # 모녀가 집 앞에 있다
		m.hud.quest_toast("숲 깊은 곳의 집을 찾아가 보자")
		m.hud.show_message("숲길(서쪽) 남쪽으로 난 오솔길을 따라 내려가 보자.", 6.0)
	m.saveio.save_now()


# 숲속 집의 모녀 — 문을 두드리면(또는 연화·솔이에게 말을 걸면) 사정을 듣는다
func _start_forest_house_dialog() -> void:
	var mom_n: Texture2D = m.tex["npc_forest_mom_portrait_normal"]
	var mom_h: Texture2D = m.tex["npc_forest_mom_portrait_happy"]
	var girl_h: Texture2D = m.tex["npc_forest_girl_portrait_happy"]
	m.story_cutscene = true
	m.dialog.open_seq("숲속의 집", null, [
		{"text": "(문을 두드리자, 한참 만에 조심스럽게 문이 열렸다.)"},
		{"text": "「...누구세요? 이 깊은 숲까지 어떻게...」",
			"name": "연화", "portrait": mom_n},
		{"text": "「엄마, 손님이에요? 우와, 진짜 손님이다!」",
			"name": "솔이", "portrait": girl_h},
		{"text": "「어머, 놀라게 해서 죄송해요. 저는 연화라고 해요.\n여기서 딸 솔이와 둘이 살고 있어요.」",
			"name": "연화", "portrait": mom_n},
		{"text": "「마을에는 거의 내려가지 않아서...\n이장님께서도 저희를 모르셨을 거예요.」",
			"name": "연화"},
		{"text": "「우리 솔이가... 몸이 약해요. 의원 말이,\n공기 좋고 조용한 곳에서 지내야 한다더군요.」",
			"name": "연화"},
		{"text": "「그래서 이 숲에 자리를 잡았어요.\n숲 공기 덕분인지 요즘은 많이 좋아졌답니다.」",
			"name": "연화", "portrait": mom_h},
		{"text": "「저 이제 기침도 거의 안 해요!\n나중에 마을 축제에도 가 보고 싶어요.」",
			"name": "솔이", "portrait": girl_h},
		{"text": "「숨기려던 건 아니에요. 그저 조용히 지내고 싶었을 뿐...\n괜찮으시다면, 가끔 놀러 오세요.」",
			"name": "연화", "portrait": mom_h},
	], _end_forest_quest)


func _end_forest_quest() -> void:
	m.story_cutscene = false
	if GameData.forest_quest != "done":
		GameData.forest_quest = "done"
		GameData.affinity_open = true
		m.hud.quest_toast("메인 스토리 완료: 숲속에서 발견한 집")
		m.hud.show_message("호감도 해금! 퀘스트 너머, 사람들의 이야기가 열렸다.\n주민에게 말을 걸어 마음을 나누고 선물도 건네 보자.", 7.0)
	m.saveio.save_now()


# ---- 메인 스토리 3: 새로운 주민의 이사 ----
#
# 첫 수확 다음 날, 처음으로 「이주 희망 편지」가 도착한다 (편지 이주 시스템의
# 소개). 이장과 상의해 소년 무진을 받아주기로 하고, 이장은 앞으로의 이사
# 결정권을 플레이어에게 맡긴다. 집터(비싼 레시피 + 많은 재료)를 만들어
# 해금된 땅의 풀밭에 집 자리를 직접 정하면 집이 서고, 다음 날 무진이
# 이사 와 첫인사를 나눈다. 완료하면 이주 편지·집터 시스템이 해금된다.

func _move_update(_delta: float) -> void:
	if Net.is_guest():
		return
	# 첫 수확 다음 날 아침 — 이주 희망 편지가 도착한다
	if GameData.move_quest == "" and GameData.story_phase == "done" \
			and GameData.story2_phase == "done" and GameData.day > GameData.move_day \
			and not m.ui_open() and not m.dialog.visible and not m.story_cutscene:
		GameData.move_quest = "letter"
		# 편지는 가방에 남는다 — 나중에 다시 꺼내 읽고 수락할 수 있다
		GameData.items["move_letter"] = int(GameData.items.get("move_letter", 0)) + 1
		_start_move_letter_dialog()
	# 집을 지은 다음 날 — 무진이 정말로 이사 오고, 직접 인사하러 온다
	# (이주 NPC 공통 규칙: 확정일 다음 날, 본인이 플레이어를 찾아온다)
	elif GameData.move_quest == "wait" and GameData.day > GameData.move_day:
		GameData.move_quest = "greet"
		GameData.arrivals.append({"id": "explorer", "day": GameData.move_day})
		m.hud.quest_toast("무진이 이사 왔다!")
		m.hud.show_message("새로 지은 집 앞에 이삿짐이 보인다.\n무진이 곧 인사하러 올 것 같다.", 6.0)


func _start_move_letter_dialog() -> void:
	m.dialog.open_seq("이주 희망 편지", null, [
		{"text": "(문 앞에 낯선 편지가 한 통 놓여 있었다.)"},
		{"text": "『안녕하세요! 저는 무진이라고 해요.\n여기저기 떠돌며 모험하는 걸 좋아하는 소년이에요.』"},
		{"text": "『소문을 들었어요. 조용하던 교진 마을에\n다시 활기가 돌기 시작했다고요!』"},
		{"text": "『숲과 강, 바다까지 있는 마을이라니...\n꼭 한번 살아 보고 싶어요. 받아 주실래요?』"},
		{"text": "(마을로 이사 오고 싶다는 편지다.\n이장님께 보여드리고 상의해 보자.)"},
	], _end_move_letter)


func _end_move_letter() -> void:
	if GameData.move_quest == "letter":
		GameData.move_quest = "show"
		m.hud.quest_toast("메인 스토리: 새로운 주민의 이사")
	m.saveio.save_now()


# 이장과 상의 — 이번 이사를 받아주기로 하고, 앞으로의 결정권을 넘겨받는다
func _start_move_chief_dialog() -> void:
	var chief_normal: Texture2D = m.tex["npc_chief_portrait_normal"]
	var chief_happy: Texture2D = m.tex["npc_chief_portrait_happy"]
	m.dialog.open_seq("이장 덕수", chief_normal, [
		{"text": "「이주 희망 편지라... 어디 보세.」"},
		{"text": "「모험을 좋아하는 소년이구먼. 좋네!\n젊은 사람이 온다면야 마을이야 환영이지.」",
			"portrait": chief_happy},
		{"text": "「그리고 말인데... 앞으로 이런 편지는\n굳이 나한테 가져올 필요 없네.」",
			"portrait": chief_normal},
		{"text": "「자네 덕에 상점도 생기고, 마을에 조금씩\n활기가 돌고 있잖나. 새 주민을 받을지는\n이제 자네가 정하게.」"},
		{"text": "「단, 명심할 게 하나 있네 — 사람을 초대하려면\n**먼저 그 사람이 살 빈 집터**를 마련해 둬야 하네.」"},
		{"text": "「빈 집터가 없으면 편지를 수락할 수 없어.\n앞으로 오는 편지도 전부 마찬가질세.」"},
		{"text": "「집터 자리는 자네가 직접 골라 주게.\n아직 열리지 않은 땅만 아니면 어디든 좋네.」"},
		{"text": "「집터는 민지네 잡화점에서 레시피를 판다네.\n값도 재료도 꽤 들지만... 마을 일이니 부탁함세.」",
			"portrait": chief_happy},
		{"text": "「집터를 마련했으면 **편지를 다시 읽고**\n수락해 주게. 앞으로도 우리 마을을 잘 부탁하네.」",
			"portrait": chief_happy},
	], _end_move_chief)


func _end_move_chief() -> void:
	if GameData.move_quest == "show":
		GameData.move_quest = "build"
		m.hud.quest_toast("빈 집터를 마련하고 편지를 수락하자")
		m.hud.show_message("잡화점에서 집터 레시피 구매 → 제작대에서 제작 → 풀밭에 설치.\n빈 집터가 생기면 가방의 편지를 다시 읽고 수락할 수 있다.", 7.0)
	m.saveio.save_now()


# 가방에서 집터를 클릭하면 — 바라보는 풀밭에 **빈 집터**를 마련해 둔다.
# 집은 아직 서지 않는다. 이주 편지를 수락하는 순간, 빈 집터에 집이 지어진다.
# 가방에서 집터를 클릭하면 — 「동물의 숲」식 자리 고르기가 시작된다.
# 마우스를 따라 집이 차지할 범위가 초록(가능)/빨강(불가)으로 비쳐 보이고,
# 좌클릭으로 설치, 우클릭/ESC로 취소한다. (renderer._draw_house_preview)
func request_place_house() -> void:
	if int(GameData.items.get("housing_kit", 0)) <= 0:
		m.hud.show_message("집터가 없다 — 잡화점 레시피를 사서 제작대에서 만들자.")
		return
	m.house_preview = true
	m.hud.show_message("집터 자리 고르기 — 초록이면 놓을 수 있다.\n좌클릭: 설치 · 우클릭/ESC: 취소", 6.0)
	m.overlay.queue_redraw()


# 지금 마우스가 가리키는 칸이 집터의 현관이 된다 (거리 제한 없음)
func preview_door() -> Vector2i:
	var mp: Vector2 = m.get_canvas_transform().affine_inverse() * m.actions.mouse_screen
	return Vector2i(int(floor(mp.x / m.TILE)), int(floor(mp.y / m.TILE)))


func confirm_house_preview(door := Vector2i(-999, -999)) -> void:
	if door.x == -999:
		door = preview_door()
	if not _can_place_house(door - Vector2i(2, 3)):
		m.hud.show_message("여기는 집터를 놓을 수 없다 — 빨간 칸이 없는 넓은 풀밭을 고르자.", 4.0)
		return
	m.house_preview = false
	try_place_home_plot(door)


# door 칸이 현관이 되도록 빈 집터를 놓는다. 성공하면 true.
func try_place_home_plot(door: Vector2i) -> bool:
	if int(GameData.items.get("housing_kit", 0)) <= 0:
		return false
	var a := door - Vector2i(2, 3)
	if not _can_place_house(a):
		return false
	GameData.items["housing_kit"] = int(GameData.items["housing_kit"]) - 1
	GameData.home_plots.append({"x": a.x, "y": a.y, "used": false})
	m.objnode._place_object(door, "homeplot", 0)   # 현관 자리에 집터 팻말
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("빈 집터 완성!")
	m.hud.show_message("빈 집터를 마련했다. 이주 희망 편지를 수락하면 여기에 집이 선다.", 5.0)
	m.queue_redraw()
	m.saveio.save_now()
	return true


# 가방의 이주 희망 편지를 다시 읽는다 — 여기서 수락한다
func open_move_letter() -> void:
	if GameData.move_quest == "show":
		m.dialog.open("이주 희망 편지",
			"『...꼭 한번 살아 보고 싶어요. 받아 주실래요? — 무진』\n\n(먼저 이장님께 보여드리고 상의해 보자.)",
			[["닫기", null]])
		return
	if GameData.move_quest != "build":
		m.dialog.open("이주 희망 편지", "이미 답장을 보낸 편지다.\n무진의 들뜬 글씨가 눈에 선하다.",
			[["닫기", null]])
		return
	m.dialog.open("이주 희망 편지",
		"『숲과 강, 바다까지 있는 마을이라니...\n꼭 한번 살아 보고 싶어요. 받아 주실래요? — 무진』",
		[["수락하기", _try_accept_move], ["나중에", null]])


# 수락 — **빈 집터가 있어야만** 된다. 없으면 편지는 그대로 남는다.
func _try_accept_move() -> void:
	var plot: Vector2i = GameData.first_empty_plot()
	if plot.x < 0:
		m.dialog.close()
		m.hud.show_message("집터가 없어서 초대할 수 없다. 집터를 우선 만들자!", 5.0)
		return
	m.dialog.close()
	# 준비해 둔 빈 집터에 집을 짓고 이사를 진행한다
	for p: Dictionary in GameData.home_plots:
		if int(p.x) == plot.x and int(p.y) == plot.y:
			p.used = true
			break
	GameData.items["move_letter"] = maxi(0, int(GameData.items.get("move_letter", 0)) - 1)
	GameData.move_house = plot
	m.objnode._remove_object(m.door_tile(plot))   # 집터 팻말 철거
	for y in range(plot.y - 1, plot.y + 5):       # 그새 자란 것들 정리
		for x in range(plot.x - 1, plot.x + 6):
			if m.objects.has(Vector2i(x, y)):
				m.objnode._remove_object(Vector2i(x, y))
	m.worldgen._fill_building(plot)
	m.objects.erase(m.door_tile(plot))
	GameData.move_quest = "wait"
	GameData.move_day = GameData.day
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("이사 수락 — 새 주민의 집 완공!")
	m.hud.show_message("준비해 둔 집터에 집이 지어졌다. 내일이면 무진이 이사 온다!", 5.0)
	m.queue_redraw()
	m.saveio.save_now()


# 집이 설 자리: 해금된 땅의 넓게 트인 풀밭 (물·모래·나무·건물·작물 금지).
# 아직 열리지 않은 지역은 숲(fixed 나무)이나 모래·물이라 여기서 걸러진다.
# 집터 한 칸의 조건 — 프리뷰가 초록/빨강을 칠할 때도 이 판정을 그대로 쓴다
func _house_tile_ok(x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= m.MAP_W - 1 or y >= m.MAP_H - 1:
		return false
	if not GameData.is_tile_owned(x, y):
		return false  # 아직 해금하지 않은 마을 구역에는 집터를 못 놓는다
	var cell: Dictionary = m.grid[y][x]
	if cell.ground != "grass" or str(cell.get("crop_id", "")) != "":
		return false
	return not m.objects.has(Vector2i(x, y))


func _can_place_house(a: Vector2i) -> bool:
	for y in range(a.y - 1, a.y + 5):
		for x in range(a.x - 1, a.x + 6):
			if not _house_tile_ok(x, y):
				return false
	return true


# ---- 메인 스토리 4: 오래된 마을의 경계 ----
#
# 동쪽 다리 건너 낡은 표지판(E) -> 이장에게 물어보기 -> 오래된 마을
# 지도 -> 첫 구역 해금 + 마을 확장 시스템 정식 해금.
# 남은 구역은 이장의 「마을 확장 이야기」(village_ui)에서 되살린다.
func examine_old_sign() -> void:
	match GameData.story4_phase:
		"":
			m.dialog.open_seq("낡은 표지판", null, [
				{"text": "비바람에 삭아 반쯤 기운 나무 표지판이다.\n지워진 글씨를 겨우 읽어 본다.\n\n『교○ 마을 — 동쪽 경계』"},
				{"text": "표지판 너머는 수풀이 우거져 들어갈 수 없다.\n마을의 경계...? 오래전에 세운 것 같은데.\n\n이장님이라면 뭔가 알고 있을지도 모른다."},
			], _begin_story4)
		"ask":
			m.dialog.open("낡은 표지판",
				"『교○ 마을 — 동쪽 경계』\n\n이장님에게 이 표지판에 대해 물어보자.",
				[["닫기", null]])
		_:
			m.dialog.open("낡은 표지판",
				"『교○ 마을 — 동쪽 경계』\n\n옛 마을의 경계 표지판이다. 버려졌던 땅이\n이제 다시 마을로 돌아오고 있다.",
				[["닫기", null]])


func _begin_story4() -> void:
	GameData.story4_phase = "ask"
	m.hud.quest_toast("새 목표: 이장에게 물어보자")
	m.saveio.save_now()


func _start_story4_dialog() -> void:
	var chief_normal: Texture2D = m.tex["npc_chief_portrait_normal"]
	var chief_happy: Texture2D = m.tex["npc_chief_portrait_happy"]
	m.dialog.open_seq("이장 덕수", chief_normal, [
		{"text": "「동쪽 다리 건너 낡은 표지판 말인가?\n허허... 그걸 다 찾아냈구먼.」"},
		{"text": "「그건 예전에 쓰던 **마을의 경계 표지판**일세.\n잠깐 기다려 보게 — 보여줄 게 있네.」"},
		{"text": "(이장님이 장롱 깊숙한 곳에서 누렇게 바랜\n두루마리를 꺼내 조심스럽게 펼친다)\n\n— 오래된 교진 마을의 지도다."},
		{"text": "「보게나. 지금 우리가 쓰는 땅은 옛 교진 마을의\n일부일 뿐이야. 동쪽 강 너머까지, 예전엔 전부\n마을이었다네.」"},
		{"text": "「사람이 하나둘 떠나면서 바깥 구역부터 차례로\n버려졌지. 지금은 수풀만 무성하네만...」"},
		{"text": "「자네가 온 뒤로 마을이 다시 살아나고 있잖나.\n버려진 구역, 자네가 하나씩 되살려 보게!」",
			"portrait": chief_happy},
		{"text": "「우선 다리 건너 북동쪽 터부터 다시 쓰세.\n나머지 구역도 준비가 되면 나한테 말을 걸게 —\n「마을 확장 이야기」로 하나씩 열어 주겠네.」",
			"portrait": chief_happy},
	], _end_story4)


func _end_story4() -> void:
	if GameData.story4_phase != "ask":
		return
	GameData.story4_phase = "done"
	if not GameData.zones_open.has("east_north"):
		GameData.zones_open.append("east_north")
	m.hud.quest_toast("마을 확장 해금!")
	m.hud.show_message("옛 마을 북동쪽 터가 열렸다! 동쪽 다리 너머로 마을이 넓어졌다.\n"
		+ "남은 구역은 이장님의 「마을 확장 이야기」에서 되살릴 수 있다. (지도 M)", 7.0)
	m.queue_redraw()
	m.saveio.save_now()


# 이사 온 무진과의 첫인사
func _start_move_greet_dialog() -> void:
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	m.dialog.open_seq("무진", m.tex["npc_explorer_portrait_happy"], [
		{"text": "「아! 혹시 네가 %s?\n편지 받아 줘서 정말 고마워!」" % nm},
		{"text": "「나는 무진. 오늘부터 이 마을 주민이야.\n집도 네가 직접 골라 준 자리라며? 마음에 쏙 들어!」"},
		{"text": "「나는 한곳에 가만히 못 있는 성격이라...\n내일부터 마을 구석구석 모험하고 다닐 거야.」",
			"portrait": m.tex["npc_explorer_portrait_normal"]},
		{"text": "「좋은 거 찾으면 제일 먼저 알려줄게.\n또 보자, 잘 부탁해!」",
			"portrait": m.tex["npc_explorer_portrait_happy"]},
	], _end_move_greet)


func _end_move_greet() -> void:
	if GameData.move_quest in ["greet", "wait"]:
		GameData.move_quest = "done"
		m.hud.quest_toast("메인 스토리 완료: 새로운 주민의 이사")
		m.hud.show_message("이주 편지·집터 시스템 해금!\n앞으로 이주 희망 편지는 이장 허락 없이 네가 직접 결정한다.", 7.0)
		# 정착 다음 날, 무진의 숲 모험이 시작된다 (숲속에서 발견한 집으로 이어진다)
		GameData.forest_quest = "settle"
		GameData.forest_day = GameData.day
	_end_movein("explorer")   # 첫 인사 마무리 (공통 시스템과 같은 결)


# ---- 이주 NPC의 첫 인사 (공통 시스템) ----
#
# 건물 완공/이사 확정 「다음 날」, 그 NPC가 직접 플레이어를 찾아와
# 첫 인사를 나눈다. 인사를 마쳐야(npc_greeted) 영업과 일과가 시작된다.
# 걸어오는 연출은 「이장의 걱정」(_spear_update)과 같은 결이다.
var _movein_walker: Node2D = null


func _movein_npc_node(nid: String) -> Node2D:
	for n in m.npcs:
		if n.id == nid:
			return n
	return null


func _movein_update(delta: float) -> void:
	if Net.is_guest() or GameData.arrivals.is_empty():
		return
	if _movein_walker == null:
		# 확정일 다음 날부터, 플레이어가 야외에 한가할 때 찾아온다
		var a: Dictionary = GameData.arrivals[0]
		if GameData.day <= int(a.day):
			return
		if m.ui_open() or m.dialog.visible or m.story_cutscene \
				or m.interior.visible or m.cave.visible or m.house_preview:
			return
		var hh := GameData.minutes / 60.0
		if hh < 6.0 or hh >= 19.0:
			return   # 밤에는 찾아오지 않는다
		var nid := str(a.id)
		var walker := _movein_npc_node(nid)
		if walker == null:
			var pt := m.player_tile()
			m.npcmgr._spawn_npc(nid, Vector2i(pt.x - 1, pt.y + 5))
			walker = m.npcs[m.npcs.size() - 1]
		_movein_walker = walker
		m.story_cutscene = true
		walker.scripted = true
		walker.position = m.player.position + Vector2(-30.0, 170.0)
		m.hud.show_message("누군가 이쪽으로 걸어온다...", 4.0)
	elif not m.dialog.visible:
		var to: Vector2 = m.player.position + Vector2(0.0, 40.0) - _movein_walker.position
		if to.length() > 10.0:
			_movein_walker.moving = true
			_movein_walker.dir = "up" if absf(to.y) >= absf(to.x) and to.y < 0.0 \
				else ("down" if absf(to.y) >= absf(to.x)
				else ("right" if to.x > 0.0 else "left"))
			_movein_walker.position += to.normalized() * 110.0 * delta
			_movein_walker.anim_time += delta
			_movein_walker._update_sprite()
		else:
			_movein_walker.moving = false
			_movein_walker._update_sprite()
			_start_movein_dialog(str(GameData.arrivals[0].id))


func _start_movein_dialog(nid: String) -> void:
	# 무진(스토리 3)은 자기만의 첫인사가 있다 — 끝나면 같은 마무리를 탄다
	if nid == "explorer" and GameData.move_quest == "greet":
		_start_move_greet_dialog()
		return
	var def: Dictionary = GameData.NPCS[nid]
	var bname := "가게"
	for pid: String in m.VILLAGE_NPC:
		if str(m.VILLAGE_NPC[pid]) == nid:
			bname = str(m.VILLAGE_PLOTS[pid].name)
			break
	var entries: Array = []
	if nid == "merchant":
		entries = [
			{"text": "「안녕! 네가 이 마을을 살리고 있다는\n그 사람이지? 나는 민지야.」"},
			{"text": "「어제 세워 준 잡화점, 정말 고마워!\n밤새 진열을 끝냈어. 오늘부터 영업 시작이야.」",
				"portrait": m.tex["npc_merchant_portrait_happy"]},
			{"text": "「씨앗이든 뭐든 필요하면 들러!\n좋은 물건 잔뜩 갖다 놨으니까. 잘 부탁해~」",
				"portrait": m.tex["npc_merchant_portrait_happy"]},
		]
	else:
		entries = [
			{"text": "「안녕하세요! 오늘부터 %s를 맡게 된\n%s라고 해요.」" % [bname, def.name]},
			{"text": "「어제는 이사 준비로 정신이 없어서...\n인사가 늦었네요. 오늘부터 문을 엽니다!」"},
			{"text": "「앞으로 잘 부탁드려요. 언제든 놀러 오세요!」"},
		]
	m.dialog.open_seq(str(def.name), m.tex["npc_%s_portrait_normal" % nid],
		entries, _end_movein.bind(nid))


func _end_movein(nid: String) -> void:
	m.story_cutscene = false
	if _movein_walker != null:
		_movein_walker.scripted = false
	_movein_walker = null
	if not GameData.npc_greeted.has(nid):
		GameData.npc_greeted.append(nid)
	for i in GameData.arrivals.size():
		if str(GameData.arrivals[i].id) == nid:
			GameData.arrivals.remove_at(i)
			break
	m.npcmgr._sync_village_npcs()
	m.hud.quest_toast("%s이(가) 마을에 자리 잡았다!" % GameData.NPCS[nid].name)
	m.saveio.save_now()


# ---- 밤 기절 조건부 서브 퀘스트: 이장의 걱정 ----
#
# 밤에 몬스터(지네)에게 당해 기절하면 spear_quest가 "pending"이 되고,
# 다음 날 아침 이장이 플레이어에게 직접 걸어와 돌 창 레시피를 준다.
# (상점에서 살 수 없다 — 이 서브퀘로만 얻는 레시피)

func _spear_update(delta: float) -> void:
	if Net.is_guest():
		return
	if GameData.spear_quest == "pending":
		if GameData.story_phase != "done" or m.ui_open() or m.dialog.visible \
				or m.story_cutscene or m.interior.visible or m.cave.visible:
			return
		var chief: Variant = _story_chief()
		if chief == null or not chief.visible:
			return
		GameData.spear_quest = "visit"
		m.story_cutscene = true
		chief.scripted = true
		# 화면 밖에서 걸어오는 느낌 — 플레이어 남쪽에서 다가온다
		chief.position = m.player.position + Vector2(-30.0, 170.0)
		m.hud.show_message("이장님이 급히 걸어온다...", 4.0)
	elif GameData.spear_quest == "visit" and not m.dialog.visible:
		var chief2: Variant = _story_chief()
		if chief2 == null:
			_start_spear_dialog()   # 이장이 없으면 (있을 수 없는 상황) 바로 대화
			return
		var to: Vector2 = m.player.position + Vector2(0.0, 40.0) - chief2.position
		if to.length() > 10.0:
			chief2.moving = true
			chief2.dir = "up" if absf(to.y) >= absf(to.x) and to.y < 0.0 \
				else ("down" if absf(to.y) >= absf(to.x)
				else ("right" if to.x > 0.0 else "left"))
			chief2.position += to.normalized() * 110.0 * delta
			chief2.anim_time += delta
			chief2._update_sprite()
		else:
			chief2.moving = false
			chief2._update_sprite()
			_start_spear_dialog()


func _start_spear_dialog() -> void:
	m.dialog.open_seq("이장 덕수", m.tex["npc_chief_portrait_normal"], [
		{"text": "「이보게! 몸은 좀 괜찮은가?」"},
		{"text": "「간밤에 그 몹쓸 벌레들한테 당해 쓰러졌다고\n들었네. 얼마나 놀랐는지...」"},
		{"text": "「밤의 들판은 위험하다네.\n맨몸으로 다녀서는 안 돼.」"},
		{"text": "「옜네 — 내가 젊을 적 쓰던\n돌 창 만드는 법일세.」", "event": _grant_spear_recipe},
		{"text": "「목재 3개와 돌 2개면 집 제작대에서 만들 수 있네.\n느리지만 한 방이 묵직하지. 밤엔 꼭 챙겨 다니게!」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
	], _end_spear_visit)


func _grant_spear_recipe() -> void:
	if "spear" not in GameData.recipes_unlocked:
		GameData.recipes_unlocked.append("spear")
	m.hud.reward_toast("돌 창 레시피", m.tex.get("icon_spear"))


func _end_spear_visit() -> void:
	m.story_cutscene = false
	var chief: Variant = _story_chief()
	if chief != null:
		chief.scripted = false
	if GameData.spear_quest != "done":
		GameData.spear_quest = "done"
		m.hud.quest_toast("서브 퀘스트 완료: 이장의 걱정")
	m.saveio.save_now()


# 빈 집터 팻말 회수 — 집터가 가방으로 돌아온다 (아직 안 쓴 집터만)
func _pickup_home_plot(door: Vector2i) -> void:
	m.dialog.close()
	var a := door - Vector2i(2, 3)
	for p: Dictionary in GameData.home_plots.duplicate():
		if int(p.x) == a.x and int(p.y) == a.y and not bool(p.get("used", false)):
			GameData.home_plots.erase(p)
			m.objnode._remove_object(door)
			GameData.items["housing_kit"] = int(GameData.items.get("housing_kit", 0)) + 1
			m.hud.show_message("빈 집터를 거둬 가방에 챙겼다.")
			m.queue_redraw()
			m.saveio.save_now()
			return
