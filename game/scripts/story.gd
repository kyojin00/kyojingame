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
var _story_art: TextureRect = null
var _story_art_frame := 0
# 오프닝 페이지마다 얹는 움직이는 일러스트 (prologue_<이름>_0..3).
# 마지막 안내 페이지(목록 밖)는 농장 그림을 쓴다.
const INTRO_ART := ["grandpa", "grandpa", "grandpa", "box", "letter",
	"farm", "farm"]
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
					m.hud.quest_start_toast("숲 안으로 들어가보기")
					_spawn_postman()
				else:
					# 자막을 읽을 시간을 준 뒤 완료 처리 + 우체부 등장
					get_tree().create_timer(1.3).timeout.connect(func() -> void:
						m.hud.quest_start_toast("숲 안으로 들어가보기")
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
				m.hud.quest_start_toast("나무도끼를 장착해보기")
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
				m.hud.quest_start_toast("지도를 확인해보자")
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
		{"text": "「오, 이런 숲길에서 사람을 다 만나는구먼!\n자네도 교진 마을로 가는 길인가?」",
			"portrait": m.tex["npc_postman_portrait_happy"]},
		{"text": "「나는 이 근방 마을들을 도는 우체부라네.\n오늘은 꼭 전해야 할 편지가 한 통 있어서 말이지.」",
			"portrait": m.tex["npc_postman_portrait_normal"]},
		{"text": "「교진 마을 이장님 앞으로 온 편지인데...\n사연이 담긴 귀한 것이라, 해가 지기 전에는\n꼭 전해 드려야 하네.」"},
		{"text": "「그런데 보게나 — 마을로 드는 길은 이 숲\n하나뿐인데, 오래 사람이 안 다녔더니 나무가\n길을 통째로 삼켜 버렸지 뭔가.」"},
		{"text": "「이 늙은 몸으로 혼자 뚫고 가자니 영 엄두가\n안 나던 참이었네. 자네를 만난 게 천운이구먼!」",
			"portrait": m.tex["npc_postman_portrait_happy"]},
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
	m.hud.quest_start_toast("나무를 베어보자")
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
		m.hud.show_message("나무를 베어 숲길을 개척하며 나아가자!", 6.0))


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
		m.hud.show_message("열린 길을 따라 마을로 가보자.", 6.0))


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
	m.hud.quest_start_toast("마을로 가는 길을 열어보자")
	m.hud.reward_toast("나무 곡괭이 (정식 획득)", m.tex["icon_pickaxe"])
	_apply_story_camera()
	_apply_story_visibility()
	m.hud.show_message("우체부 아저씨와 함께 길을 따라 마을로 가자!", 6.0)
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
		m.hud.quest_start_toast("자신의 능력 확인해보기")


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
	# 처음 마을에 발 디딘 순간 — 엔딩 통계 리포트가 이 날짜·시각에서 시작한다
	if GameData.arrive_day == 0:
		GameData.arrive_day = GameData.day
		GameData.arrive_clock = GameData.clock_text()
	m.hud.quest_toast("마을 도착")
	m.hud.show_message("우체부 아저씨를 따라 이장님께 가자.", 6.0)
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
	# 정착 준비: 이장이 환영 선물로 호미와 씨앗 살 밑천을 건넨다.
	# 씨앗은 공짜로 주지 않는다 — 잡화점에서 직접 사는 게 농사의 시작이다.
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")
	GameData.money += 200
	m.hud.reward_toast("호미 × 1 · 씨앗 살 밑천 200G", m.tex["icon_hoe"])
	m.hud.show_message("호미는 가방(I)에서 슬롯에 넣어야 쓴다.\n씨앗은 잡화점 씨앗 선반에서 사자!", 5.0)


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
	m.hud.story_banner("메인 스토리 1 완결", "우체부 아저씨와의 첫 만남")
	m.hud.show_message("집을 둘러보고 밖으로 나가 보자.", 6.0)
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
		{"text": "「책상에서는 손수 가구를 만들 수 있네.\n물론 재료가 있어야만 만들 수 있지.」"},
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
	# 검은 알림 바 대신 말풍선 연출만 — 자세한 재료는 트래커/Q창이 보여 준다
	m.hud.story_banner("메인 스토리 2 시작", "마을을 깨우다")
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
		{"text": "「호미로 집 앞 풀밭을 갈아 밭을 만들고,\n씨앗을 사서 심어보게. 농사가 이 마을의 근본일세.」",
			"portrait": chief_happy},
		{"text": "「아, 참! 상인은 내일 해가 뜨면 오네.\n씨앗은 그때 상점에서 사면 되네.」"},
		{"text": "「오늘은 일단 마을을 둘러보고,\n바닷바람도 쐬며 해변을 걸어보게나.」",
			"portrait": chief_happy},
		{"text": "「자연을 만끽하며 푹 쉬고 내일을 준비하게.\n같이 넣어 둔 밑천이면 씨앗값은 충분할 걸세.」"},
	], _end_farm_intro)


func _end_farm_intro() -> void:
	GameData.story2_phase = "farm"
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")  # 대화를 스킵해도 지급 보장
	m.hud.quest_start_toast("밭을 일구자")
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
	m.hud.event_toast("낯선 낚시꾼이 마을에 왔다")
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
	m.hud.quest_start_toast("낚시꾼과 함께 바다로")
	m.hud.show_message("낚시꾼과 함께 남쪽 바위 능선으로 가자.", 6.0)
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
		m.hud.quest_start_toast("바닷길을 열자")
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
	m.hud.event_toast("바다 · 해변 해금!")
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

	# 양피지 편지 패널 (밝은 배경 + 진한 글씨).
	# 오프닝은 위에 일러스트가 얹혀 키가 크므로 화면 위쪽에 붙인다.
	var panel := PanelContainer.new()
	panel.position = Vector2(210, 26 if _story_mode == "intro" else 90)
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

	# 움직이는 프롤로그 일러스트 — 페이지에 그림이 있으면 위에 얹는다
	_story_art = TextureRect.new()
	_story_art.custom_minimum_size = Vector2(504, 216)
	_story_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_story_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_story_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_story_art.visible = false
	v.add_child(_story_art)
	var art_timer := Timer.new()
	art_timer.wait_time = 0.26
	art_timer.autostart = true
	art_timer.timeout.connect(func() -> void:
		_story_art_frame = (_story_art_frame + 1) % 4
		_update_story_art())
	story_layer.add_child(art_timer)

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


# 지금 페이지의 일러스트 이름 ("" = 그림 없음)
func _story_art_key() -> String:
	if _story_mode != "intro":
		return ""
	if _story_idx < INTRO_ART.size():
		return str(INTRO_ART[_story_idx])
	return "farm"   # 마지막 안내 페이지


func _update_story_art() -> void:
	if _story_art == null or not is_instance_valid(_story_art):
		return
	var key := _story_art_key()
	var tn := "prologue_%s_%d" % [key, _story_art_frame]
	if key == "" or not m.tex.has(tn):
		_story_art.visible = false
		return
	_story_art.visible = true
	_story_art.texture = m.tex[tn]


func _show_story_page() -> void:
	_update_story_art()
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


# (유니콘의 뿔 「최후의 연금술」 엔딩은 걷어냈다 — 엔딩은 ending_ui 하나다)


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
		m.hud.story_banner("메인 스토리 2 완결", "마을을 깨우다")
		m.saveio.save_now()
	var tut: Dictionary = GameData.tutorial
	if not tut.get("active", false) or tut.get(flag, true):
		return
	# 마을 생활 안내(스토리2 밖 목표)는 스토리 3이 열어 줘야 진행된다
	if flag not in GameData.STORY2_FLAGS and not GameData.guide_active:
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
		[["해보겠습니다", null]], m.tex.get("icon_letter"))


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
	m.hud.quest_start_toast("할아버지의 부탁 — %s" % q.name)
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
		m.hud.event_toast("숨겨진 레시피 발견: 산호빛 차")
		m.dialog.open_seq("산호 조각", null, [
			{"text": "파도 사이에서 붉게 빛나는 조각을 주웠다.\n"
				+ "물에 담그자 은은한 노을빛이 번진다."},
			{"text": "할아버지의 노트 귀퉁이에 이런 낙서가 있었지 —\n"
				+ "\"바다가 꽃을 피우면, 약초와 함께 달여 보거라.\""},
			{"text": "[숨겨진 레시피를 배웠다: 산호빛 차]\n집 조리대에 새 칸이 생겼다."},
		])
	elif fid == "forage_relic":
		m.hud.event_toast("숨겨진 이야기 발견: 물에 잠긴 마을")
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
		m.hud.story_banner("메인 스토리 5 시작", "숲속에서 발견한 집")
		m.hud.quest_start_toast("무진이 할 말이 있는 듯하다")


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
		m.hud.event_toast("새 주민: 모험가 무진")
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
		m.hud.quest_start_toast("숲속의 집에 대해 이장에게 물어보자")
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
		m.hud.quest_start_toast("숲 깊은 곳의 집을 찾아가 보자")
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
		m.hud.story_banner("메인 스토리 5 완결", "숲속에서 발견한 집")
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
		# 메인 스토리 3과 함께 「마을 생활 안내」가 열린다 —
		# 이때부터 안내 목표가 퀘스트 창(Q)에 나오고, 원하면 핀으로 고정한다
		GameData.guide_active = true
		_start_move_letter_dialog()
	# 집을 지은 다음 날 — 무진이 정말로 이사 오고, 직접 인사하러 온다
	# (이주 NPC 공통 규칙: 확정일 다음 날, 본인이 플레이어를 찾아온다)
	elif GameData.move_quest == "wait" and GameData.day > GameData.move_day:
		GameData.move_quest = "greet"
		GameData.arrivals.append({"id": "explorer", "day": GameData.move_day})
		m.hud.event_toast("무진이 이사 왔다!")
		m.hud.show_message("새로 지은 집 앞에 이삿짐이 보인다.\n무진이 곧 인사하러 올 것 같다.", 6.0)


func _start_move_letter_dialog() -> void:
	m.dialog.open_seq("이주 희망 편지", m.tex.get("icon_letter"), [
		{"text": "(문 앞에 낯선 편지가 한 통 놓여 있었다.)"},
		{"text": "『안녕하세요! 저는 무진이라고 해요.\n여기저기 떠돌며 모험하는 걸 좋아하는 소년이에요.』"},
		{"text": "『소문을 들었어요. 조용하던 교진 마을에\n다시 활기가 돌기 시작했다고요!』"},
		{"text": "『숲과 강, 바다까지 있는 마을이라니...\n꼭 한번 살아 보고 싶어요. 받아 주실래요?』"},
		{"text": "(마을로 이사 오고 싶다는 편지다.\n이장님께 보여드리고 상의해 보자.)"},
	], _end_move_letter)


func _end_move_letter() -> void:
	if GameData.move_quest == "letter":
		GameData.move_quest = "show"
		m.hud.story_banner("메인 스토리 3 시작", "새로운 주민의 이사")
		m.hud.quest_start_toast("마을 생활 안내가 열렸다! (Q에서 확인)")
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
		m.hud.quest_start_toast("빈 집터를 마련하고 편지를 수락하자")
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
	m.hud.event_toast("빈 집터 완성!")
	m.hud.show_message("빈 집터를 마련했다. 이주 희망 편지를 수락하면 여기에 집이 선다.", 5.0)
	m.queue_redraw()
	m.saveio.save_now()
	return true


# 가방의 이주 희망 편지를 다시 읽는다 — 여기서 수락한다
func open_move_letter() -> void:
	if GameData.move_quest == "show":
		m.dialog.open("이주 희망 편지",
			"『...꼭 한번 살아 보고 싶어요. 받아 주실래요? — 무진』\n\n(먼저 이장님께 보여드리고 상의해 보자.)",
			[["닫기", null]], m.tex.get("icon_letter"))
		return
	if GameData.move_quest != "build":
		m.dialog.open("이주 희망 편지", "이미 답장을 보낸 편지다.\n무진의 들뜬 글씨가 눈에 선하다.",
			[["닫기", null]], m.tex.get("icon_letter"))
		return
	m.dialog.open("이주 희망 편지",
		"『숲과 강, 바다까지 있는 마을이라니...\n꼭 한번 살아 보고 싶어요. 받아 주실래요? — 무진』",
		[["수락하기", _try_accept_move], ["나중에", null]], m.tex.get("icon_letter"))


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
	m.hud.event_toast("이사 수락 — 새 주민의 집 완공!")
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
	m.hud.story_banner("메인 스토리 4 시작", "오래된 마을의 경계")
	m.hud.quest_start_toast("낡은 표지판 — 이장에게 물어보자")
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
	m.hud.story_banner("메인 스토리 4 완결", "오래된 마을의 경계")
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
		m.hud.story_banner("메인 스토리 3 완결", "새로운 주민의 이사")
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


# 플레이어 곁의 「걸어서 설 수 있는」 칸 — 물·오브젝트·건물 위는 안 된다.
# (예전엔 플레이어 아래 170px에 그냥 텔레포트해서, 호숫가·분수 곁에서는
#  NPC가 물속에 서던 버그가 있었다)
func _walk_tile_near_player(dist: int) -> Vector2i:
	var pt := m.player_tile()
	var cands: Array[Vector2i] = []
	for d in range(dist, 0, -1):
		cands += [Vector2i(0, d), Vector2i(-1, d), Vector2i(1, d),
			Vector2i(-d, 0), Vector2i(d, 0), Vector2i(0, -d),
			Vector2i(-d, d), Vector2i(d, d)]
	for off: Vector2i in cands:
		if m.is_passable(pt + off):
			return pt + off
	return pt


var _movein_route: Array = []


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
		var start := _walk_tile_near_player(5)   # 물·장애물 없는 칸에서 등장
		if walker == null:
			m.npcmgr._spawn_npc(nid, start)
			walker = m.npcs[m.npcs.size() - 1]
		_movein_walker = walker
		m.story_cutscene = true
		walker.scripted = true
		walker.visible = true
		walker.position = Vector2(start.x * m.TILE + 16, start.y * m.TILE + 16)
		# 플레이어 바로 곁(통행 가능 칸)까지는 길찾기로 걸어온다 — 물을 건너지 않는다
		var goal := _walk_tile_near_player(1)
		_movein_route = m.npcmgr._tile_path(start, goal)
		m.hud.show_message("누군가 이쪽으로 걸어온다...", 4.0)
	elif not m.dialog.visible:
		if not _movein_route.is_empty():
			var wp: Vector2 = _movein_route[0]
			var to: Vector2 = wp - _movein_walker.position
			if to.length() < 6.0:
				_movein_walker.position = wp
				_movein_route.pop_front()
			else:
				_movein_walker.moving = true
				_movein_walker.dir = "up" if absf(to.y) >= absf(to.x) and to.y < 0.0 \
					else ("down" if absf(to.y) >= absf(to.x)
					else ("right" if to.x > 0.0 else "left"))
				_movein_walker.position += to.normalized() * 110.0 * delta
				_movein_walker.anim_time += delta
				_movein_walker._update_sprite()
			return
		# 길이 끝났다 — 플레이어가 그새 멀어졌으면 새 길을 잡고, 곁이면 인사
		var to2: Vector2 = m.player.position - _movein_walker.position
		if to2.length() > 80.0:
			var wt := Vector2i(int(floor(_movein_walker.position.x / m.TILE)),
				int(floor(_movein_walker.position.y / m.TILE)))
			_movein_route = m.npcmgr._tile_path(wt, _walk_tile_near_player(1))
			if _movein_route.is_empty():
				_start_movein_dialog(str(GameData.arrivals[0].id))   # 길이 없다 — 그 자리에서
			return
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
	_movein_route = []
	if _movein_walker != null:
		_movein_walker.scripted = false
	_movein_walker = null
	if not GameData.npc_greeted.has(nid):
		GameData.npc_greeted.append(nid)
	# 민지 도착 첫날 기억 — 잡화점 요리 레시피 선반은 다음 날부터 깔린다
	if nid == "merchant" and GameData.merchant_day == 0:
		GameData.merchant_day = GameData.day
	for i in GameData.arrivals.size():
		if str(GameData.arrivals[i].id) == nid:
			GameData.arrivals.remove_at(i)
			break
	m.npcmgr._sync_village_npcs()
	m.hud.event_toast("%s이(가) 마을에 자리 잡았다!" % GameData.NPCS[nid].name)
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
		# 화면 밖에서 걸어오는 느낌 — 물·장애물 없는 곁 칸에서 다가온다
		var st := _walk_tile_near_player(5)
		chief.position = Vector2(st.x * m.TILE + 16, st.y * m.TILE + 16)
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
	# 받은 레시피도 곧바로 배워지지 않는다 — 가방에서 「배우기」
	if "spear" not in GameData.recipes_unlocked \
			and not GameData.recipe_items.has("spear"):
		GameData.give_recipe("spear")
	m.hud.reward_toast("돌 창 레시피 (가방에서 배우자)", m.tex.get("recipe"))


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


# ---- 메인 스토리 6: 오래된 책과 사서 ----
#
# 스토리 5(숲속에서 발견한 집)를 끝내면 마을 풀숲에 오래된 책이 놓인다.
# 책 -> 이장(모름) -> 우체부에게 편지 부탁 -> 이틀 뒤 답장 -> 사서 방문 ->
# 책 확인(마을의 기록, 상태가 나빠 당장은 못 읽음) -> 도서관 필요성 ->
# 이장 상의 -> 도서관 건설 -> 사서 정착. 완결 후 책은 도서관에 보관된다.

var _book_post: Node2D = null       # 스토리 6의 우체부 (부탁받기/답장 전달)
var _book_post_spr: Sprite2D = null
var _book_post_route: Array = []
var _book_post_mode := ""           # "stand"(우체국 터에서 대기) / "walk"(답장 배달)
var _book_post_anim := 0.0


func _story6_update(delta: float) -> void:
	if Net.is_guest():
		return
	# 시작: 스토리 5를 끝내면 풀숲에 오래된 책이 놓인다
	if GameData.story6_phase == "" and GameData.forest_quest == "done":
		_place_old_book()
	elif GameData.story6_phase == "find" and not _old_book_exists():
		_place_old_book()   # 세이브 호환 — 책이 사라졌으면 다시 놓는다
	# 편지 부탁 단계: 우체부가 우체국 터 앞에서 기다린다
	if GameData.story6_phase == "ask_post" and _book_post == null:
		_spawn_book_post("stand",
			m.door_tile(m.VILLAGE_PLOTS["post"].anchor) + Vector2i(0, 1))
	# 답장: 이틀 뒤, 낮에 야외에서 한가할 때 우체부가 걸어온다
	if GameData.story6_phase == "wait" and _book_post == null \
			and GameData.day > GameData.story6_day + GameData.STORY6_REPLY_DAYS - 1:
		if m.ui_open() or m.dialog.visible or m.story_cutscene \
				or m.interior.visible or m.cave.visible or m.house_preview:
			return
		var hh := GameData.minutes / 60.0
		if hh < 6.0 or hh >= 19.0:
			return
		var start := _walk_tile_near_player(6)
		_spawn_book_post("walk", start)
		_book_post_route = m.npcmgr._tile_path(start, _walk_tile_near_player(1))
		m.hud.show_message("우체부 아저씨가 이쪽으로 걸어온다...", 4.0)
	# 답장을 든 우체부가 걸어온다
	if _book_post != null and _book_post_mode == "walk" and not m.dialog.visible:
		if not _book_post_route.is_empty():
			var wp: Vector2 = _book_post_route[0]
			var to: Vector2 = wp - _book_post.position
			if to.length() < 6.0:
				_book_post.position = wp
				_book_post_route.pop_front()
			else:
				_book_post.position += to.normalized() * 110.0 * delta
				_book_post_anim += delta
				var f := int(_book_post_anim * 6.0) % 2
				if absf(to.y) >= absf(to.x):
					_book_post_spr.texture = m.tex["npc_postman_%s_%d"
						% ["up" if to.y < 0.0 else "down", f]]
					_book_post_spr.flip_h = false
				else:
					_book_post_spr.texture = m.tex["npc_postman_side_%d" % f]
					_book_post_spr.flip_h = to.x < 0.0
			return
		if GameData.story6_phase == "wait":
			_start_book_reply_dialog()


# 광장 남동쪽 풀숲에서 빈 잔디칸을 찾아 책을 놓는다
func _place_old_book() -> void:
	var base := Vector2i(78, 22)
	for r in 7:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := base + Vector2i(dx, dy)
				if t.x < 1 or t.y < 1 or t.x >= m.MAP_W - 1 or t.y >= m.MAP_H - 1:
					continue
				if m.objects.has(t) or not m.is_passable(t):
					continue
				var c: Dictionary = m.grid[t.y][t.x]
				if c.ground != "grass" or c.crop_id != "":
					continue
				m.objects[t] = {"kind": "old_book", "hp": 0}
				m.objnode._spawn_object_node(t, "old_book")
				GameData.story6_phase = "find"
				m.saveio.save_now()
				return


func _old_book_exists() -> bool:
	for pos: Vector2i in m.objects:
		if str(m.objects[pos].kind) == "old_book":
			return true
	return false


func _spawn_book_post(mode: String, tile: Vector2i) -> void:
	_book_post = Node2D.new()
	_book_post.position = Vector2(tile.x * m.TILE + 16, tile.y * m.TILE + 16)
	_book_post_spr = Sprite2D.new()
	_book_post_spr.centered = false
	_book_post_spr.offset = Vector2(-64, -188)
	_book_post_spr.scale = Vector2(0.56, 0.56)
	_book_post_spr.texture = m.tex["npc_postman_down_0"]
	_book_post.add_child(_book_post_spr)
	m.world.add_child(_book_post)
	_book_post_mode = mode
	_book_post_route = []
	_book_post_anim = 0.0


func _despawn_book_post() -> void:
	if _book_post != null:
		_book_post.queue_free()
	_book_post = null
	_book_post_spr = null
	_book_post_mode = ""
	_book_post_route = []


# 퀘스트 1 — 풀숲의 오래된 책을 조사해 줍는다
func examine_old_book(t: Vector2i) -> void:
	if GameData.story6_phase != "find":
		m.dialog.open("오래된 책", "낡은 책이 풀숲에 반쯤 묻혀 있다.", [["닫기", null]])
		return
	m.objnode._remove_object(t)
	GameData.items["old_book"] = 1
	GameData.discover("old_book")
	GameData.story6_phase = "show_chief"
	Sound.play_sfx("sfx_catch")
	m.dialog.open_seq("오래된 책", m.tex.get("old_book"), [
		{"text": "(풀숲에 반쯤 묻힌 두꺼운 책을 조심스레 파냈다.)"},
		{"text": "(가죽 표지는 닳아 해졌고 종이는 누렇게 바랬다.\n알아볼 수 없는 옛 글씨가 빼곡하다.)"},
		{"text": "(혼자서는 도무지 모르겠다...\n이장님께 가져가 보자.)"},
	], _end_book_found)


func _end_book_found() -> void:
	m.hud.story_banner("메인 스토리 6 시작", "오래된 책과 사서")
	m.saveio.save_now()


# 퀘스트 2 — 이장도 읽지 못한다. 사서에게 편지를 보내기로
func _start_book_chief_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_normal"], [
		{"text": "「이건... 꽤나 오래된 물건이구먼.\n어디 보자...」"},
		{"text": "「안 되겠네. 글씨가 옛 서체라 나도 못 읽겠어.\n마을 어른들도 이런 건 본 적 없을 게야.」"},
		{"text": "「책이라면, 책을 잘 아는 사람에게\n보여주는 게 좋겠지.」"},
		{"text": "「우체부 양반에게 부탁해 보게. 책에 밝은\n사서 선생이 한 분 계시다 들었네 —\n편지를 보내 보는 걸세.」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
	], _end_book_chief)


func _end_book_chief() -> void:
	if GameData.story6_phase == "show_chief":
		GameData.story6_phase = "ask_post"
		m.hud.quest_start_toast("우체부 아저씨에게 편지를 부탁하자")
	m.saveio.save_now()


# 퀘스트 3 — 우체부에게 편지를 부탁한다 (우체국 터 앞)
func _start_book_post_dialog() -> void:
	if GameData.story6_phase != "ask_post":
		return
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
		{"text": "「오, 오랜만이구먼! 잘 지냈는가?\n...부탁이 있다고?」"},
		{"text": "(오래된 책 이야기를 전하고, 책을 잘 아는 사서에게\n편지를 보내 달라고 부탁했다.)",
			"portrait": m.tex["npc_postman_portrait_normal"]},
		{"text": "「책에 밝은 사서 선생이라... 알지, 알아.\n편지는 내가 책임지고 전함세!」",
			"portrait": m.tex["npc_postman_portrait_happy"]},
		{"text": "「답장이 오려면 며칠은 걸릴 게야.\n느긋하게 기다려 보게.」"},
	], _end_book_post)


func _end_book_post() -> void:
	if GameData.story6_phase == "ask_post":
		GameData.story6_phase = "wait"
		GameData.story6_day = GameData.day
		m.hud.quest_start_toast("사서의 답장을 기다리자")
	_despawn_book_post()
	m.saveio.save_now()


# 퀘스트 4 — 며칠 뒤, 우체부가 답장을 들고 찾아온다
func _start_book_reply_dialog() -> void:
	m.dialog.open_seq("우체부 아저씨", m.tex["npc_postman_portrait_happy"], [
		{"text": "「이보게! 답장일세, 답장!」"},
		{"text": "『보내 주신 이야기는 잘 읽었습니다.\n그런 책이 남아 있다니 놀랍네요.\n꼭 직접 보고 싶습니다. 곧 찾아뵐게요. — 사서 서하』",
			"portrait": m.tex.get("icon_letter")},
		{"text": "「곧 마을로 오신다더군. 부지런한 분이라\n아마 벌써 광장쯤에 와 계실지도 몰라!」"},
	], _end_book_reply)


func _end_book_reply() -> void:
	if GameData.story6_phase == "wait":
		GameData.story6_phase = "visit"
		m.hud.quest_start_toast("마을에 찾아온 사서를 만나보자")
	_despawn_book_post()
	m.npcmgr._sync_village_npcs()   # 사서가 광장 곁에 나타난다 (방문객)
	m.saveio.save_now()


# 퀘스트 5 — 사서가 책을 확인한다: 마을의 기록, 그리고 도서관의 필요성
func _start_librarian_book_dialog() -> void:
	m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_normal"], [
		{"text": "「안녕하세요. 편지를 받고 온 사서, 서하라고 해요.\n그... 오래된 책, 지금 갖고 계신가요?」"},
		{"text": "(오래된 책을 건넸다. 서하가 장갑을 끼고\n조심스레 책장을 넘긴다.)"},
		{"text": "「...놀라워요. 이건 이 마을에 관한\n아주 오래된 기록이에요.」",
			"portrait": m.tex["npc_librarian_portrait_happy"]},
		{"text": "「다만 상태가 많이 나빠서, 지금 당장 전부\n읽어 내는 건 무리예요. 시간을 들여\n복원해야 해요.」",
			"portrait": m.tex["npc_librarian_portrait_normal"]},
		{"text": "「그런데... 이상해요. 이런 기록이 나오는 마을에\n책과 기록을 보관할 곳이 하나도 없다니요.」"},
		{"text": "「작은 도서관이 있다면 이 책도, 앞으로 발견될\n기록들도 제대로 지킬 수 있을 텐데요.」",
			"portrait": m.tex["npc_librarian_portrait_happy"]},
		{"text": "(도서관 이야기를 이장님께 전해 보자.)"},
	], _end_librarian_book)


func _end_librarian_book() -> void:
	if GameData.story6_phase == "visit":
		GameData.story6_phase = "told"
		m.hud.quest_start_toast("사서의 이야기를 이장에게 전하자")
	m.saveio.save_now()


# 퀘스트 6 — 이장과 상의: 작은 도서관을 짓기로 한다
func _start_book_chief2_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_normal"], [
		{"text": "「도서관이라... 사서 선생이 그리 말씀하셨는가.」"},
		{"text": "「하긴, 마을이 예전보다 부쩍 컸지.\n앞으로 사람도 더 늘 게고... 책과 기록을\n둘 곳이 있어야겠구먼.」"},
		{"text": "「좋네! 마을에 작은 도서관을 짓기로 하지.\n자리는 비워 두겠네.」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
		{"text": "「재료가 모이면 나에게 「마을 발전 이야기」로\n오게. 목재 90에 석재 50 — 마을 사람들도\n거들 걸세!」"},
	], _end_book_chief2)


func _end_book_chief2() -> void:
	if GameData.story6_phase == "told":
		GameData.story6_phase = "build"
		m.hud.quest_start_toast("도서관 건설을 준비하자")
	m.saveio.save_now()


# 퀘스트 7 — 도서관 완성: 사서가 마을에 정착한다 (스토리 6 완결)
func _start_library_done_dialog() -> void:
	m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_happy"], [
		{"text": "「도서관... 정말로 지어 주셨네요.\n나무 냄새가 참 좋아요.」"},
		{"text": "「처음엔 책 한 권만 보고 돌아갈 생각이었어요.\n그런데 이 서가를 보니... 마음이 바뀌었어요.」",
			"portrait": m.tex["npc_librarian_portrait_normal"]},
		{"text": "「여기서 책과 기록을 관리하며 살고 싶어요.\n이 마을의 사서로요. ...받아 주실 거죠?」",
			"portrait": m.tex["npc_librarian_portrait_happy"]},
		{"text": "「오래된 책은 도서관에 소중히 보관할게요.\n복원이 끝나는 대로, 제일 먼저 함께 읽어요.」"},
	], _end_library_done)


func _end_library_done() -> void:
	if GameData.story6_phase != "build" or not GameData.village_built.has("library"):
		return
	GameData.story6_phase = "done"
	if not GameData.npc_greeted.has("librarian"):
		GameData.npc_greeted.append("librarian")   # 정식 주민으로 정착
	# 오래된 책은 도서관 서가로 — 판매·삭제 없이 다음 이야기까지 보관된다
	# (키를 지우면 가방 목록이 빈 키를 밟는다 — 개수만 0으로)
	GameData.items["old_book"] = 0
	GameData.old_book_stored = true
	m.hud.story_banner("메인 스토리 6 완결", "오래된 책과 사서")
	m.hud.show_message("사서 서하가 마을에 정착했다!\n도서관에서 오래된 책과 마을의 기록을 볼 수 있다.", 7.0)
	m.saveio.save_now()


# ---- 메인 스토리 7: 식지 않는 화로 ----
#
# 스토리 6을 끝내면 대장장이 무쇠의 화로가 식어 간다. 서하가 복원 중인
# 오래된 책에서 옛 교진 대장간의 비법을 찾아내고, 동굴 깊은 곳의
# 광석·보석으로 화로를 되살린다. 완결하면 강화 골드 비용이 싸진다.

func _story7_update(_delta: float) -> void:
	if Net.is_guest():
		return
	# 시작: 스토리 6 완결 + 무쇠가 마을에 자리 잡은 뒤
	if GameData.story7_phase == "" and GameData.story6_phase == "done" \
			and GameData.village_built.has("smith") \
			and GameData.npc_greeted.has("blacksmith"):
		GameData.story7_phase = "worry"
		m.hud.quest_start_toast("대장장이 무쇠의 이야기를 들어보자")
		m.saveio.save_now()


# 퀘스트 1 — 무쇠의 고민: 화로의 불이 예전 같지 않다
func _start_forge_worry_dialog() -> void:
	m.dialog.open_seq("무쇠", m.tex["npc_blacksmith_portrait_normal"], [
		{"text": "「...왔는가. 마침 잘 왔네.」"},
		{"text": "「요즘 화로가 이상해. 불이 예전만큼\n오르질 않아. 아무리 풀무질을 해도 말이지.」"},
		{"text": "「이대로면 쇠를 벼리는 값이 자꾸 오를 걸세.\n좋은 쇠는 좋은 불에서 나오는 법이거든.」"},
		{"text": "「할아버지 세대에게 듣기로, 옛 교진 마을의\n대장간 불은 백 년을 꺼지지 않았다더군.」"},
		{"text": "「그 비법이 어딘가 남아 있지 않겠나...\n혹시 도서관의 그 오래된 책 말일세.」"},
		{"text": "「사서 선생이 복원 중이라 들었네.\n옛 대장간 이야기가 있는지 물어봐 주게.」"},
	], _end_forge_worry)


func _end_forge_worry() -> void:
	if GameData.story7_phase == "worry":
		GameData.story7_phase = "lore"
		m.hud.story_banner("메인 스토리 7 시작", "식지 않는 화로")
		m.hud.quest_start_toast("도서관의 서하에게 물어보자")
	m.saveio.save_now()


# 퀘스트 2 — 서하가 복원 중인 책에서 옛 대장간 구절을 찾아낸다
func _start_forge_lore_dialog() -> void:
	m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_normal"], [
		{"text": "「옛 대장간이요? 잠깐만요...\n마침 복원이 끝난 장이 있어요.」"},
		{"text": "(서하가 오래된 책을 조심스레 펼친다.\n숯과 불꽃 그림이 그려진 장이다.)"},
		{"text": "「여기예요 — 『화로가 식거든 깊은 굴의 돌을\n녹여라. 별처럼 반짝이는 돌이 불씨를 지킨다』.」",
			"portrait": m.tex["npc_librarian_portrait_happy"]},
		{"text": "「깊은 굴의 돌이라면... 동굴의 광석,\n그리고 반짝이는 돌은 보석이겠네요.」"},
		{"text": "「광석 %d개와 보석 %d개 — 이만큼이면 화로를\n다시 살릴 수 있대요. 보석은 동굴 깊은 층에서\n나온다고 들었어요.」" % [GameData.STORY7_ORE, GameData.STORY7_GEM],
			"portrait": m.tex["npc_librarian_portrait_normal"]},
		{"text": "「무쇠 씨에게 이 이야기를 전해 주세요.\n책이 마을을 돕네요 — 기뻐요.」",
			"portrait": m.tex["npc_librarian_portrait_happy"]},
	], _end_forge_lore)


func _end_forge_lore() -> void:
	if GameData.story7_phase == "lore":
		GameData.story7_phase = "gather"
		m.hud.quest_start_toast("광석 %d·보석 %d를 모아 무쇠에게 가져가자"
			% [GameData.STORY7_ORE, GameData.STORY7_GEM])
	m.saveio.save_now()


# 퀘스트 3 — 재료를 모아 화로를 되살린다 (스토리 7 완결)
func _start_forge_fire_dialog() -> void:
	var ore := int(GameData.items.get("ore", 0))
	var gem := int(GameData.items.get("gem", 0))
	if ore < GameData.STORY7_ORE or gem < GameData.STORY7_GEM:
		m.dialog.open_seq("무쇠", m.tex["npc_blacksmith_portrait_normal"], [
			{"text": "「재료는 좀 모였는가? 광석 %d개와 보석 %d개 —\n지금은 광석 %d·보석 %d로군.」" %
				[GameData.STORY7_ORE, GameData.STORY7_GEM, ore, gem]},
			{"text": "「보석은 동굴 깊은 층에서 나온다네.\n서두를 것 없네 — 안전이 먼저야.」"},
		])
		return
	m.dialog.open_seq("무쇠", m.tex["npc_blacksmith_portrait_normal"], [
		{"text": "「오오... 가져왔군! 이만하면 충분하네.」"},
		{"text": "(무쇠가 광석과 보석을 화로에 넣고\n힘차게 풀무질을 시작했다.)"},
		{"text": "(불꽃이 파랗게, 이윽고 하얗게 —\n화로가 눈부시게 타오른다!)"},
		{"text": "「하하! 이 불이야, 이 불!\n옛 어른들이 지키던 바로 그 불일세!」",
			"portrait": m.tex["npc_blacksmith_portrait_happy"]},
		{"text": "「고맙네. 화로가 살아났으니 벼리는 품이\n한결 덜 들 걸세 — 강화 값을 깎아 주지!」",
			"portrait": m.tex["npc_blacksmith_portrait_happy"]},
	], _end_forge_fire)


func _end_forge_fire() -> void:
	if GameData.story7_phase != "gather":
		return
	if int(GameData.items.get("ore", 0)) < GameData.STORY7_ORE \
			or int(GameData.items.get("gem", 0)) < GameData.STORY7_GEM:
		return
	GameData.items["ore"] -= GameData.STORY7_ORE
	GameData.items["gem"] -= GameData.STORY7_GEM
	GameData.story7_phase = "done"
	m.hud.story_banner("메인 스토리 7 완결", "식지 않는 화로")
	m.hud.show_message("화로가 되살아났다! 대장간의 도구 강화 골드 비용이 20% 싸진다.", 7.0)
	m.saveio.save_now()


# ---- 메인 스토리 8: 초원에서 온 목동 ----
#
# 스토리 7을 끝내면 동물들과 초원을 찾아 떠도는 목동 보라가 마을에 온다.
# 보라의 사정 -> 이장 상의 -> 목장 상회 건설(스토리 게이트) -> 정착.
# 완결하면 목장 상회에서 동물·축사·말·펫을 들일 수 있다.

func _story8_update(_delta: float) -> void:
	if Net.is_guest():
		return
	# 시작: 스토리 7 완결 — 다음 날부터가 아니라 곧장, 소문처럼 찾아온다
	if GameData.story8_phase == "" and GameData.story7_phase == "done":
		GameData.story8_phase = "visit"
		m.npcmgr._sync_village_npcs()   # 보라가 광장 곁에 나타난다 (방문객)
		m.hud.quest_start_toast("마을에 온 낯선 목동을 만나보자")
		m.saveio.save_now()


# 퀘스트 1 — 떠도는 목동 보라: 초원이 마음에 들지만 상회가 없다
func _start_rancher_visit_dialog() -> void:
	m.dialog.open_seq("보라", m.tex["npc_rancher_portrait_normal"], [
		{"text": "「아, 안녕! 나는 보라 — 동물들이랑\n좋은 초원을 찾아 떠돌아다니는 목동이야.」"},
		{"text": "「대장간 화로가 되살아난 마을이 있다길래\n구경 왔는데... 여기 초원, 정말 좋다!」",
			"portrait": m.tex["npc_rancher_portrait_happy"]},
		{"text": "「부드러운 풀에 맑은 물... 우리 애들이\n살기엔 더할 나위 없는 곳이야.」"},
		{"text": "「그런데 동물을 맡기고 먹이를 대 줄\n목장 상회가 없네. 그게 없으면 동물은\n키우기 어렵거든.」",
			"portrait": m.tex["npc_rancher_portrait_normal"]},
		{"text": "「이장님께 한번 여쭤봐 줄래? 상회 자리만\n생기면, 나 여기 정착하고 싶어!」",
			"portrait": m.tex["npc_rancher_portrait_happy"]},
	], _end_rancher_visit)


func _end_rancher_visit() -> void:
	if GameData.story8_phase == "visit":
		GameData.story8_phase = "ask"
		m.hud.story_banner("메인 스토리 8 시작", "초원에서 온 목동")
		m.hud.quest_start_toast("목장 이야기를 이장과 상의하자")
	m.saveio.save_now()


# 퀘스트 2 — 이장과 상의: 목장 상회를 짓기로 한다
func _start_ranch_chief_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_normal"], [
		{"text": "「목동이 왔다고? 허어, 마을에 동물이라...\n옛날엔 집집마다 닭 울음이 들렸는데 말일세.」"},
		{"text": "「초원이야 넉넉하지. 목동이 자리만 잡으면\n마을이 또 한 번 살아나겠구먼.」"},
		{"text": "「좋네! 목장 상회 자리는 비워 두겠네.\n서쪽 길가 — 대장간 아랫자리일세.」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
		{"text": "「재료가 모이면 「마을 발전 이야기」로 오게.\n목재 80에 석재 40 — 다 같이 세워 봄세!」"},
	], _end_ranch_chief)


func _end_ranch_chief() -> void:
	if GameData.story8_phase == "ask":
		GameData.story8_phase = "build"
		m.hud.quest_start_toast("목장 상회 건설을 준비하자")
	m.saveio.save_now()


# 퀘스트 3 — 목장 상회 완성: 보라가 정착한다 (스토리 8 완결)
func _start_ranch_done_dialog() -> void:
	m.dialog.open_seq("보라", m.tex["npc_rancher_portrait_happy"], [
		{"text": "「우와아... 진짜 지어 줬네!\n지붕도 튼튼하고, 마당도 널찍하고!」"},
		{"text": "「정했어. 나, 이 마을의 목동 할래!\n우리 애들도 다 데려올 거야.」"},
		{"text": "「상회에서 닭이랑 소도 분양하고, 축사도\n지어 줄게. 말이랑 귀여운 펫도 있어!」",
			"portrait": m.tex["npc_rancher_portrait_normal"]},
		{"text": "「동물은 사랑을 먹고 자라 — 매일 쓰다듬어\n주는 거 잊지 마! 앞으로 잘 부탁해~」",
			"portrait": m.tex["npc_rancher_portrait_happy"]},
	], _end_ranch_done)


func _end_ranch_done() -> void:
	if GameData.story8_phase != "build" or not GameData.village_built.has("ranch"):
		return
	GameData.story8_phase = "done"
	if not GameData.npc_greeted.has("rancher"):
		GameData.npc_greeted.append("rancher")   # 정식 주민으로 정착
	m.hud.story_banner("메인 스토리 8 완결", "초원에서 온 목동")
	m.hud.show_message("목동 보라가 마을에 정착했다!\n목장 상회에서 동물·축사·말·펫을 들일 수 있다.", 7.0)
	m.saveio.save_now()


# ---- 메인 스토리 9: 마을의 심장, 마을회관 ----
#
# 스토리 8을 끝내면 이장이 옛 교진 마을의 회관을 떠올리며 「주민을
# 초대해 달라」고 부탁한다. 주민(플레이어 제외) 10명 -> 회관 건설 해금 ->
# 완공 후 접수대의 이장과 개관식 -> 완결. 회관 기능(명부·캘린더·창고·
# 프로젝트·회의)은 마을이 클수록 하나씩 열린다 — 한꺼번에 주지 않는다.

func _story9_update(_delta: float) -> void:
	if Net.is_guest():
		return
	# 회관 해금·기능 게이트가 함께 쓰는 「지금 주민 수」 거울
	GameData.residents_now = m.village_residents()
	# 시작: 스토리 8 완결 — 커진 마을을 보며 이장이 옛 회관을 떠올린다
	if GameData.story9_phase == "" and GameData.story8_phase == "done":
		GameData.story9_phase = "ask"
		m.hud.quest_start_toast("이장이 마을의 앞날을 이야기하고 싶어 한다")
		m.saveio.save_now()
	# 주민 10명(플레이어 제외)이 모이면 회관 건설이 열린다
	if GameData.story9_phase == "invite" \
			and m.village_residents() > GameData.HALL_RESIDENTS:
		GameData.story9_phase = "build"
		m.hud.event_toast("마을회관 해금!")
		m.hud.quest_start_toast("마을회관을 짓자 — 이장 「마을 발전 이야기」")
		m.saveio.save_now()


# 퀘스트 1 — 이장의 부탁: 주민을 초대해 마을을 키워 달라
func _start_hall_ask_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_normal"], [
		{"text": "「어서 오게. 요즘 마을을 보고 있자면...\n꼭 옛날로 돌아간 것 같구먼.」"},
		{"text": "「옛 교진 마을엔 마을회관이 있었다네.\n주민 명부며 마을 살림이며, 다 거기서\n돌아갔지. 마을의 심장이었어.」"},
		{"text": "「하지만 회관은 사람이 모여야 뜻이 있는 법 —\n텅 빈 마을에 세워 봐야 헛간일 뿐일세.」"},
		{"text": "「자네가 주민을 초대해 주게. 빈 집터를 두면\n이사 오고 싶다는 편지가 올 걸세.\n나까지 합쳐 %d명이면 충분하네.」" % GameData.HALL_RESIDENTS,
			"portrait": m.tex["npc_chief_portrait_happy"]},
		{"text": "「사람이 모이면 회관 터는 광장 남쪽에\n비워 두겠네. 마을의 심장이 다시 뛰는 걸\n꼭 보고 싶구먼.」"},
	], _end_hall_ask)


func _end_hall_ask() -> void:
	if GameData.story9_phase == "ask":
		GameData.story9_phase = "invite"
		m.hud.story_banner("메인 스토리 9 시작", "마을의 심장, 마을회관")
		m.hud.quest_start_toast("주민을 초대하자 — 목표 %d명 (지금 %d명)" %
			[GameData.HALL_RESIDENTS, maxi(GameData.residents_now - 1, 0)])
	m.saveio.save_now()


# 퀘스트 2 — 개관식: 완공된 회관 접수대에서 이장과 (스토리 9 완결)
func _start_hall_open_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_happy"], [
		{"text": "「왔는가! 보게, 이 튼튼한 서까래며 넓은\n마루며... 옛 회관보다 낫구먼!」"},
		{"text": "「자네가 초대한 이웃들 덕에 마을이 이렇게\n북적이게 됐네. 다 자네 덕일세.」"},
		{"text": "(이장이 접수대에 두툼한 장부를 펼쳐 놓았다.\n첫 장에 주민들의 이름이 적혀 있다.)"},
		{"text": "「여기서 주민 명부와 마을 소식을 볼 수 있네.\n낮에는 내가 지키고 있겠네.」",
			"portrait": m.tex["npc_chief_portrait_normal"]},
		{"text": "「그리고 말일세 — 마을이 더 크면 회관이\n할 수 있는 일도 늘어난다네. 창고며 공동\n프로젝트며... 천천히, 차근차근 함세.」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
	], _end_hall_open)


func _end_hall_open() -> void:
	if GameData.story9_phase != "build" or not GameData.village_built.has("hall"):
		return
	GameData.story9_phase = "done"
	m.hud.story_banner("메인 스토리 9 완결", "마을의 심장, 마을회관")
	m.hud.show_message("마을회관이 문을 열었다! 접수대에서 주민 명부와\n마을 소식을 볼 수 있다 — 마을이 클수록 할 일이 늘어난다.", 8.0)
	m.saveio.save_now()


# ---- 메인 스토리 10: 동굴과 탐험 ----
#
# 마을의 기반이 완성되면(스토리 9), 서하가 복원을 끝낸 오래된 책의
# 마지막 장에서 할아버지의 「동굴 표본 조사」 기록을 찾아낸다.
# 조사(깊이 15층 + 새 표본 2종)를 마치고 보고하면 완결.
# 연구 노트의 동굴 컬렉션을 다 채우면 영구 채광·탐험 보상이 몸에 밴다.

func _story10_update(_delta: float) -> void:
	if Net.is_guest():
		return
	# 시작: 스토리 9 완결 — 서하가 복원 막바지의 발견을 들고 찾아온다
	if GameData.story10_phase == "" and GameData.story9_phase == "done":
		GameData.story10_phase = "note"
		m.hud.quest_start_toast("도서관의 서하가 찾고 있다")
		m.saveio.save_now()


# 퀘스트 1 — 서하의 발견: 오래된 책 마지막 장, 할아버지의 동굴 조사
func _start_cave_note_dialog() -> void:
	m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_happy"], [
		{"text": "「왔군요! 드디어... 오래된 책의 복원이\n마지막 장까지 닿았어요.」"},
		{"text": "(서하가 조심스레 책장을 넘긴다. 광석과 버섯,\n이끼가 빼곡히 그려진 장이 나타났다.)"},
		{"text": "「할아버님의 동굴 표본 조사예요. 『깊은 굴은\n살아 있다 — 빛나는 돌과 자라는 것들을\n기록하라』... 그런데 여기, 빈 칸들이 있어요.」",
			"portrait": m.tex["npc_librarian_portrait_normal"]},
		{"text": "「할아버님도 다 못 채우신 거예요. 당신의\n연구 노트에 이 장을 옮겨 둘게요 —\n동굴 표본 두 묶음이에요.」"},
		{"text": "「우선 %d층까지 내려가서, 책에 그려진\n새 표본을 두 종류만 찾아와 주세요.\n조사가 시작되면 동굴도 달라 보일 거예요.」" % GameData.STORY10_DEPTH,
			"portrait": m.tex["npc_librarian_portrait_happy"]},
		{"text": "「그리고... 묶음을 끝까지 채우면, 할아버님의\n요령이 몸에 밴대요. 책에 그렇게 적혀 있어요.\n『다 아는 자의 곡괭이는 가볍다』 — 라고요.」"},
	], _end_cave_note)


func _end_cave_note() -> void:
	if GameData.story10_phase == "note":
		GameData.story10_phase = "survey"
		m.hud.story_banner("메인 스토리 10 시작", "동굴과 탐험")
		m.hud.quest_start_toast("동굴 조사 — %d층 도달 + 새 표본 %d종 발견" %
			[GameData.STORY10_DEPTH, GameData.STORY10_FINDS])
		m.hud.show_message("연구 노트(N)에 동굴 컬렉션 두 쪽이 열렸다!\n다 채우면 채광·탐험에 영구 보상이 붙는다.", 7.0)
	m.saveio.save_now()


# 퀘스트 2 — 조사 보고: 목표를 채우고 서하에게 (스토리 10 완결)
func _start_cave_report_dialog() -> void:
	if not GameData.story10_survey_done():
		m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_normal"], [
			{"text": "「조사는 어때요? 깊이 %d층, 그리고 책에\n그려진 새 표본 %d종 — 지금은 %d층에\n표본 %d종이네요.」" % [
				GameData.STORY10_DEPTH, GameData.STORY10_FINDS,
				mini(GameData.mine_deepest, GameData.STORY10_DEPTH),
				GameData.cave_finds_found()]},
			{"text": "「수정은 깊은 층 광맥에, 발광 버섯은 어두운\n굴 바닥에, 이끼는 축축한 이끼방에...\n서두르지 말고요. 안전이 먼저예요.」"},
		])
		return
	m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_happy"], [
		{"text": "「이 표본... 정말 찾아냈군요! 책의 그림과\n똑같아요. 할아버님이 보셨다면 정말\n기뻐하셨을 거예요.」"},
		{"text": "(서하가 표본을 찬찬히 살펴 그리고는,\n연구 노트의 빈 칸에 조심스레 옮겨 적었다.)"},
		{"text": "「이제 이 조사는 당신 거예요. 동굴 컬렉션의\n남은 칸도 언젠가 다 채워질 거예요 —\n묶음이 완성되는 날, 몸으로 느끼실 거예요.」",
			"portrait": m.tex["npc_librarian_portrait_normal"]},
		{"text": "「『다 아는 자의 곡괭이는 가볍다』...\n할아버님의 말씀, 꼭 확인해 보세요.」",
			"portrait": m.tex["npc_librarian_portrait_happy"]},
	], _end_cave_report)


func _end_cave_report() -> void:
	if GameData.story10_phase != "survey" or not GameData.story10_survey_done():
		return
	GameData.story10_phase = "done"
	m.hud.story_banner("메인 스토리 10 완결", "동굴과 탐험")
	m.hud.show_message("할아버지의 동굴 조사를 이어받았다!\n연구 노트(N)의 동굴 컬렉션을 채우면 영구 보상이 열린다.", 7.0)
	m.saveio.save_now()


# ---- 메인 스토리 11: 할머니의 모자 ----
#
# 스토리 10 완결 + 마을 회의 경험 + 노트 20%가 차면, 이장이 직접
# 플레이어를 찾아와 걸어온다 (「이장의 걱정」과 같은 연출).
# 주민 단서 -> 동굴 50층 광석에서 모자(확정) -> 도서관 「할머니의 기록」.

func _story11_update(delta: float) -> void:
	if Net.is_guest():
		return
	# 시작: 조건이 차면 이장이 하던 일을 멈추고 이쪽으로 걸어온다
	if GameData.story11_phase == "" and GameData.story11_ready():
		if m.ui_open() or m.dialog.visible or m.story_cutscene \
				or m.interior.visible or m.cave.visible or m.house_preview:
			return
		var chief: Variant = _story_chief()
		if chief == null or not chief.visible:
			return
		GameData.story11_phase = "visit"
		m.story_cutscene = true
		chief.scripted = true
		var st := _walk_tile_near_player(5)
		chief.position = Vector2(st.x * m.TILE + 16, st.y * m.TILE + 16)
		m.hud.show_message("이장님이 무언가 결심한 얼굴로 걸어온다...", 4.0)
		return
	# 걸어오는 중 — 곁에 닿으면 이야기를 꺼낸다.
	# (걸어오다 저장하고 껐다 켜도 여기서 연출을 다시 잡는다)
	if GameData.story11_phase == "visit" and not m.dialog.visible:
		var chief2: Variant = _story_chief()
		if chief2 == null:
			_start_hat_visit_dialog()
			return
		m.story_cutscene = true
		chief2.scripted = true
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
			_start_hat_visit_dialog()
		return
	# 동굴 50층에서 모자를 찾았다 — 도서관의 기록으로 이어진다
	if GameData.story11_phase in ["clue", "deep"] \
			and int(GameData.items.get("relic_hat", 0)) > 0:
		GameData.story11_phase = "record"
		m.hud.quest_start_toast("도서관에서 「할머니의 기록」을 읽어 보자")
		m.saveio.save_now()


func _start_hat_visit_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_normal"], [
		{"text": "「...자네, 잠깐 시간 좀 내주겠나.\n오늘은 마을 일이 아니라... 옛날얘기일세.」"},
		{"text": "「자네 연구 노트가 제법 두툼해졌다고\n들었네. 그럼 이제 말해도 되겠지.」"},
		{"text": "「자네 할머님 말일세. 그분에겐 아끼던\n유품이 다섯 있었네 — 하나같이 어디에\n있는지 아무도 모르지만.」"},
		{"text": "「그중 첫째가 챙 넓은 모자였네. 밭에서도,\n굴에서도 늘 쓰고 계셨지... 그러다 어느 날\n굴 깊은 곳에 두고 오셨다네.」"},
		{"text": "「나이 든 사람들은 아직 그 모자를 기억하네.\n무쇠, 사서 선생, 그리고 숲의 연화 —\n먼저 이야기를 들어 보게.」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
		{"text": "「서두를 것 없네. 밭 갈고 고기 잡던 대로\n지내면서, 준비가 되면 굴로 내려가게.\n...할머님이 기다리셨을 걸세.」"},
	], _end_hat_visit)


func _end_hat_visit() -> void:
	m.story_cutscene = false
	var chief: Variant = _story_chief()
	if chief != null:
		chief.scripted = false
	if GameData.story11_phase == "visit":
		GameData.story11_phase = "clue"
		GameData.story11_clues = []
		m.hud.story_banner("메인 스토리 11 시작", "할머니의 모자")
		m.hud.quest_start_toast("주민들에게 할머니의 모자 이야기를 듣자 (0/%d)"
			% GameData.STORY11_CLUE_NPCS.size())
	m.saveio.save_now()


# 단서 — 세 사람이 저마다 기억하는 할머니의 모자
const HAT_CLUES := {
	"blacksmith": [
		{"text": "「할머님 모자? ...기억하네. 광부들 도시락을\n싸 들고 굴까지 내려오시던 분이었지.」"},
		{"text": "「우리 아버지가 그러셨네 — 그 모자는 아주\n깊은 곳, 승강기도 안 닿던 막장에서\n사라졌다고. 쉰 층은 됐을 거라더군.」"},
		{"text": "「내려갈 거면 장비부터 벼리고 가게.\n쉰 층은... 장난이 아닐세.」"},
	],
	"librarian": [
		{"text": "「할머님 이야기요? 부녀회 명부에서 성함을\n봤어요. 기록엔 이렇게 남아 있어요 —\n『챙 넓은 모자의 그분』.」"},
		{"text": "「광산 일지에 이런 구절도 있어요.\n『깊은 막장의 광맥은 물건을 삼킨다.\n삼킨 것은 돌과 한 몸이 된다』...」"},
		{"text": "「모자가 아직 그곳에 있다면 — 광석 틈에\n섞여 있을 거예요. 캐다 보면, 분명.」"},
	],
	"forest_mom": [
		{"text": "「할머님의 모자... 그래, 어머니께 들은 적이\n있어. 볕이 강한 날엔 그 모자 그늘에\n마을 아이들이 다 들어갔다고.」"},
		{"text": "「할아버님은 평생 그 모자를 찾으려\n동굴을 헤매셨대. ...끝내 못 찾으셨지만.」"},
		{"text": "「네가 찾아 준다면 — 두 분 모두에게\n그보다 큰 선물은 없을 거야.」"},
	],
}


func _start_hat_clue_dialog(nid: String) -> void:
	var nm := str(GameData.NPCS[nid].name)
	m.dialog.open_seq(nm, m.tex.get("npc_%s_portrait_normal" % nid),
		HAT_CLUES[nid].duplicate(), _end_hat_clue.bind(nid))


func _end_hat_clue(nid: String) -> void:
	if GameData.story11_phase != "clue" or nid in GameData.story11_clues:
		return
	GameData.story11_clues.append(nid)
	var n := GameData.story11_clues.size()
	var total := GameData.STORY11_CLUE_NPCS.size()
	if n >= total:
		GameData.story11_phase = "deep"
		m.hud.quest_start_toast("동굴 %d층으로 — 광석 틈에 모자가 잠들어 있다"
			% GameData.STORY11_FLOOR)
	else:
		m.hud.event_toast("단서 %d/%d" % [n, total])
	m.saveio.save_now()


# 도서관 「할머니의 기록」 — 가진 유품의 장만 보인다 (점진 공개).
# 유품이 늘수록 두 분의 이야기가 조금씩 짙어진다.
func open_grandma_records() -> void:
	var owned := GameData.relics_owned()
	if owned <= 0:
		return
	var body := "서하가 명부·일지·편지를 모아\n할머니의 발자취를 정리해 두었다.\n\n"
	for i in GameData.RELICS.size():
		if int(GameData.items.get(str(GameData.RELICS[i].id), 0)) > 0:
			body += str(GameData.GRANDMA_RECORDS[i]) + "\n\n"
	if owned < GameData.RELICS.size():
		body += "(남은 기록 %d장 — 다음 유품을 찾으면 열린다)" \
			% (GameData.RELICS.size() - owned)
	GameData.grandma_read = maxi(GameData.grandma_read, owned)
	m.dialog.open("할머니의 기록 (%d/%d)" % [owned, GameData.RELICS.size()],
		body, [["소중히 읽었다", _end_grandma_record]])


func _end_grandma_record() -> void:
	# 기록 읽기가 이야기의 끝맺음이 되는 장 — 스토리 11(모자)·13(팔찌)
	if GameData.story11_phase == "record":
		GameData.story11_phase = "done"
		m.hud.story_banner("메인 스토리 11 완결", "할머니의 모자")
		m.hud.show_message("첫 번째 유품을 찾았다. 할머니의 기록은 유품을\n찾을 때마다 한 장씩 열린다 — 이야기는 계속된다.", 7.0)
		m.saveio.save_now()
		return
	if GameData.story13_phase == "record":
		GameData.story13_phase = "done"
		GameData.story13_done_day = GameData.day   # 다음 이야기 전, 자유 생활
		m.hud.story_banner("메인 스토리 13 완결", "할머니의 팔찌")
		m.hud.show_message("두 번째 유품을 찾았다. 바다도 약속은 지킨다 —\n남은 유품들이 어딘가에서 기다리고 있다.", 7.0)
		m.saveio.save_now()


# ---- 메인 스토리 12: 숲의 연금술사 ----
#
# 노트 40% + 호감도 3단계 주민 5명 -> 노트의 낯선 기록(누군가의 도움) ->
# 서하의 옛 기록 -> 주민 소문 -> 깊은 숲의 숨은 길 -> 연금술사의 오두막 ->
# 재료 시험(여러 생활 콘텐츠) -> 시연 -> 연금술 해금. 묘연은 마을에
# 입주하지 않고 오두막에 산다 — 할아버지를 「일부만」 아는 사람이다.

func _story12_update(_delta: float) -> void:
	if Net.is_guest():
		return
	# 시작: 자유 생활을 하다 조건이 차면, 노트에 낯선 기록이 눈에 띈다
	if GameData.story12_phase == "" and GameData.story12_ready():
		GameData.story12_phase = "note"
		m.hud.quest_start_toast("연구 노트(N)에 못 보던 기록이 끼워져 있다")
		m.saveio.save_now()


# 노트(N)를 펼치면 낯선 기록을 읽는다 — note_ui가 부른다
func story12_note_read() -> void:
	if GameData.story12_phase != "note":
		return
	GameData.story12_phase = "ask"
	m.hud.story_banner("메인 스토리 12 시작", "숲의 연금술사")
	m.hud.quest_start_toast("이 기록... 도서관의 서하에게 보여주자")
	m.saveio.save_now()


# 퀘스트 1 — 서하의 옛 기록: 재료를 연구하던 사람이 있었다
func _start_alch_ask_dialog() -> void:
	m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_normal"], [
		{"text": "「할아버님 노트에 이런 장이...?\n『이 재료만은 끝내 내 힘으로 풀지 못했다.\n그 사람의 손을 빌렸다』...」"},
		{"text": "「이름은 어디에도 없네요. 잠깐만요 —\n비슷한 이야기를 어디서 봤어요.」"},
		{"text": "(서하가 서가 깊은 곳에서 곰팡내 나는\n장부 하나를 꺼내 왔다.)"},
		{"text": "「여기요. 옛날 마을 근처에 온갖 재료를\n연구하던 사람이 살았대요. 마을 사람이\n아니라... 어디 사는지는 안 남아 있어요.」",
			"portrait": m.tex["npc_librarian_portrait_happy"]},
		{"text": "「나이 드신 분들 중에 이야기를 들어 본\n사람이 있을지도 몰라요. 주민들에게\n물어보는 게 좋겠어요.」"},
	], _end_alch_ask)


func _end_alch_ask() -> void:
	if GameData.story12_phase == "ask":
		GameData.story12_phase = "gossip"
		GameData.story12_heard = []
		m.hud.quest_start_toast("주민들에게 연금술사 이야기를 듣자 (0/%d)"
			% GameData.STORY12_RUMORS)
	m.saveio.save_now()


# 주민 소문 — 몇 명에게만 들으면 충분하다 (순서대로 이야기가 짙어진다)
const ALCH_RUMORS := [
	"「재료 연구하던 사람? 아아... 어른들이 말하던\n그 약장수 양반? 마을엔 안 살아.\n숲 어딘가라고만 들었는데.」",
	"「밤에 깊은 숲 쪽에서 보랏빛 연기가 피어오르는 걸\n봤다는 사람이 있어. 연못 있는 쪽 말이야.\n도깨비불이라고들 했지만... 글쎄.」",
	"「깊은 숲 연못 근처에 혼자 사는 사람이 있대.\n덤불에 가려진 좁은 길이 있다던데,\n무서워서 아무도 안 가 봤지.」",
]


func story12_hear(nid: String) -> void:
	if GameData.story12_phase != "gossip" or nid in GameData.story12_heard \
			or nid == "alchemist":
		return
	var idx := mini(GameData.story12_heard.size(), ALCH_RUMORS.size() - 1)
	GameData.story12_heard.append(nid)
	var nm := str(GameData.NPCS[nid].name)
	m.dialog.open_seq(nm, m.tex.get("npc_%s_portrait_normal" % nid), [
		{"text": str(ALCH_RUMORS[idx])},
	], _end_alch_rumor)


func _end_alch_rumor() -> void:
	if GameData.story12_phase != "gossip":
		return
	var n := GameData.story12_heard.size()
	if n >= GameData.STORY12_RUMORS:
		GameData.story12_phase = "path"
		# 소문이 가리키는 곳 — 깊은 숲의 덤불이 걷히고 숨은 길이 드러난다
		m.worldgen._spawn_alch_house()
		m.npcmgr._sync_village_npcs()
		m.hud.event_toast("숨은 길 발견!")
		m.hud.quest_start_toast("깊은 숲 연못 근처 — 숨은 길을 따라가 보자")
	else:
		m.hud.event_toast("소문 %d/%d" % [n, GameData.STORY12_RUMORS])
	m.saveio.save_now()


# 오두막 문 앞 E — 단계에 따라 다른 이야기가 이어진다
func _alch_house_door() -> void:
	match GameData.story12_phase:
		"path":
			_start_alch_meet_dialog()
			return
		"gather":
			_start_alch_gather_dialog()
			return
	# 스토리 13 — 낡은 상자 개봉은 연금술사의 몫이다
	match GameData.story13_phase:
		"box":
			_start_box_help_dialog()
			return
		"open":
			_start_box_open_dialog()
			return
	m.dialog.open("연금술사의 오두막",
		"문틈으로 알싸한 약초 냄새와 함께\n보글보글 무언가 끓는 소리가 새어 나온다.\n(묘연은 오두막 곁을 서성이고 있다)",
		[["닫기", null]])


# 퀘스트 2 — 첫 만남: 낯선 이를 시험하는 연금술사
func _start_alch_meet_dialog() -> void:
	m.dialog.open_seq("???", m.tex["npc_alchemist_portrait_normal"], [
		{"text": "(덤불 너머, 굴뚝에서 보랏빛 연기가 오르는\n작은 오두막이 있었다. 문을 두드리자...)"},
		{"text": "「...여기까지 찾아온 사람은 오랜만이네요.\n난 묘연 — 보다시피, 재료를 다루는 사람이에요.」"},
		{"text": "「그 노트... 그리운 필체네요. 그래요,\n그분의 연구를 몇 번 도운 적이 있어요.\n전부는 아니고... 아주 일부만.」"},
		{"text": "「하지만 처음 본 사람에게 연금술을 보여 줄\n수는 없어요. 재료를 다룰 줄 아는 사람인지\n먼저 확인해야겠어요.」"},
		{"text": "「굴의 %s, 들의 %s, 물의 %s —\n가져와 보세요. 세 가지 삶을 다 아는\n사람이라면 어렵지 않을 거예요.」" % [
			GameData.ITEMS["crystal"].name, GameData.ITEMS["forage_herb"].name,
			GameData.ITEMS["fish_crucian"].name],
			"portrait": m.tex["npc_alchemist_portrait_happy"]},
	], _end_alch_meet)


func _end_alch_meet() -> void:
	if GameData.story12_phase == "path":
		GameData.story12_phase = "gather"
		m.hud.quest_start_toast("재료 시험 — " + GameData.story12_mats_text())
	m.saveio.save_now()


# 퀘스트 3 — 재료 시험과 첫 시연 (스토리 12 완결, 연금술 해금)
func _start_alch_gather_dialog() -> void:
	if not GameData.story12_mats_ok():
		m.dialog.open_seq("묘연", m.tex["npc_alchemist_portrait_normal"], [
			{"text": "「재료는 어때요? — %s.」" % GameData.story12_mats_text()},
			{"text": "「수정은 깊은 굴 광맥에, 약초는 들과 숲에,\n붕어는 낚시터에... 서두르지 않아도 돼요.\n재료는 도망가지 않으니까.」"},
		])
		return
	m.dialog.open_seq("묘연", m.tex["npc_alchemist_portrait_happy"], [
		{"text": "「...전부 가져왔네요. 굴과 들과 물을\n다 아는 사람. 좋아요, 합격이에요.」"},
		{"text": "(묘연이 재료를 받아 절구에 빻고, 끓는\n솥에 하나씩 넣었다. 솥이 은빛으로 —\n이윽고 별처럼 반짝였다!)"},
		{"text": "「이게 연금술이에요. 재료의 목소리를 듣고,\n서로 만나게 해 주는 일.」"},
		{"text": "「그분도 그랬어요. 밭을 갈고 고기를 잡으면서,\n풀지 못한 물음이 생기면 여길 찾아왔죠.\n...당신도 그러면 돼요.」",
			"portrait": m.tex["npc_alchemist_portrait_normal"]},
		{"text": "「집에 있는 그분의 조합대, 이제 쓸 수 있을\n거예요. 조합법은 세상 곳곳에 흩어져 있어요 —\n나무에, 바위에, 몬스터의 주머니에.」",
			"portrait": m.tex["npc_alchemist_portrait_happy"]},
	], _end_alch_demo)


func _end_alch_demo() -> void:
	if GameData.story12_phase != "gather" or not GameData.story12_mats_ok():
		return
	for mid in GameData.STORY12_MATS:
		GameData.items[mid] = int(GameData.items[mid]) - int(GameData.STORY12_MATS[mid])
	GameData.story12_phase = "done"
	GameData.story12_done_day = GameData.day   # 다음 이야기 전, 자유 생활 보장
	m.hud.story_banner("메인 스토리 12 완결", "숲의 연금술사")
	m.hud.show_message("연금술이 열렸다! 집 안의 조합대(E)에서 물약을\n만들 수 있다 — 조합법은 나무·바위·몬스터에게서 배운다.", 8.0)
	m.saveio.save_now()


# ---- 메인 스토리 13: 할머니의 팔찌 ----
#
# 스토리 12 뒤 자유 생활을 며칠 보내면(임시 조건 — 세부 시작 조건은
# 추후 확정), 철수의 그물에 낡은 물건이 올라온다는 이야기로 시작한다.
# 주민 단서 -> 해변 서쪽 끝 바위 -> 특별한 입질 -> 낡은 상자 ->
# 연금술사의 개봉 -> 두 번째 유품 「할머니의 팔찌」 -> 도서관 기록 2장.

func _story13_update(_delta: float) -> void:
	if Net.is_guest():
		return
	if GameData.story13_phase == "" and GameData.story13_ready():
		GameData.story13_phase = "rumor"
		m.hud.quest_start_toast("낚시꾼 철수가 요즘 바다가 이상하다고 한다")
		m.saveio.save_now()
	# 조사 지점(두 분의 바위)이 세상에 놓여 있는지 살핀다 — 로드 직후 포함
	if GameData.story13_phase in ["spot", "box", "open", "record", "done"] \
			and GameData.sea_open:
		story13_place_rock()


# 해변 서쪽 끝, 두 분이 앉던 바위 — 조사 지점 표식 (뒀다 지우지 않는다)
func story13_place_rock() -> void:
	var t: Vector2i = m.BRACELET_ROCK
	if str(m.objects.get(t, {}).get("kind", "")) == "sign":
		return
	m.objnode._remove_object(t)
	m.objnode._place_object(t, "sign", 0)


# 퀘스트 1 — 철수의 이상한 이야기: 그물에 올라오는 낡은 물건들
func _start_sea_rumor_dialog() -> void:
	m.dialog.open_seq("철수", m.tex["npc_fisher_portrait_normal"], [
		{"text": "「어이, 마침 잘 왔네. 요즘 바다가 좀 이상해.」"},
		{"text": "「물고기 대신에 말이야 — 오래된 금속 조각이며\n낡은 물건들이 자꾸 그물에 걸려 올라와.\n어제는 녹슨 숟가락이 나왔다니까?」"},
		{"text": "「옛날 어른들 말로는, 큰 폭풍이 온 해에\n해안가 물건들이 죄다 바다로 쓸려 갔다더군.\n그게 이제야 하나씩 돌아오는 건가...」"},
		{"text": "「...가만, 자네 할머님 유품을 찾고 있다 했지?\n혹시 모르지. 바다가 그중 하나쯤\n간직하고 있을지도.」",
			"portrait": m.tex["npc_fisher_portrait_happy"]},
		{"text": "「할머님이 바다랑 인연이 있으셨는지,\n마을 사람들한테 한번 물어보게.」"},
	], _end_sea_rumor)


func _end_sea_rumor() -> void:
	if GameData.story13_phase == "rumor":
		GameData.story13_phase = "clue"
		GameData.story13_heard = []
		m.hud.story_banner("메인 스토리 13 시작", "할머니의 팔찌")
		m.hud.quest_start_toast("주민들에게 할머니와 바다 이야기를 듣자 (0/%d)"
			% GameData.STORY13_TALES)
	m.saveio.save_now()


# 주민들의 바다 이야기 — 몇 명에게만 들으면 충분하다 (갈수록 짙어진다)
const SEA_TALES := [
	"「자네 할머님? 바다를 참 좋아하셨지.\n물때만 맞으면 모래밭을 맨발로 걸으셨어.\n할아버님이 늘 뒤를 따라다니셨고.」",
	"「두 분이 늘 가시던 자리가 있었어.\n해 질 무렵이면 나란히 앉아 계셨는데...\n서쪽이었나, 그랬을 거야.」",
	"「기억나! 해변 서쪽 끝의 그 바위!\n두 분이 늘 거기 앉아 노을을 보셨어.\n그 앞바다에 뭔가 있다면... 거기일 거야.」",
]


func story13_hear(nid: String) -> void:
	if GameData.story13_phase != "clue" or nid in GameData.story13_heard \
			or nid in ["fisher", "alchemist"]:
		return
	var idx := mini(GameData.story13_heard.size(), SEA_TALES.size() - 1)
	GameData.story13_heard.append(nid)
	var nm := str(GameData.NPCS[nid].name)
	m.dialog.open_seq(nm, m.tex.get("npc_%s_portrait_normal" % nid), [
		{"text": str(SEA_TALES[idx])},
	], _end_sea_tale)


func _end_sea_tale() -> void:
	if GameData.story13_phase != "clue":
		return
	var n := GameData.story13_heard.size()
	if n >= GameData.STORY13_TALES:
		GameData.story13_phase = "spot"
		story13_place_rock()
		m.hud.event_toast("조사 지점 발견!")
		m.hud.quest_start_toast("해변 서쪽 끝 바위 곁 — 그 자리에서 낚시를 해 보자")
	else:
		m.hud.event_toast("이야기 %d/%d" % [n, GameData.STORY13_TALES])
	m.saveio.save_now()


# 두 분의 바위 (E) — 조사 지점의 표식
func examine_bracelet_rock() -> void:
	if GameData.story13_phase == "spot":
		m.dialog.open("두 사람의 바위",
			"파도에 닳은 바위에 작게 새겨진 글씨 —\n서로 기대선 두 글자의 이니셜.\n\n"
			+ "두 분이 나란히 앉아 노을을 보던 자리다.\n이 앞바다에... 낚싯대를 던져 보자.",
			[["낚싯대를 꺼낸다", null]])
	else:
		m.dialog.open("두 사람의 바위",
			"서로 기대선 두 글자의 이니셜이 새겨진 바위.\n두 분이 나란히 앉아 노을을 보던 자리다.\n\n오늘도 파도가 잔잔하다.",
			[["잠시 바다를 본다", null]])


# 특별한 입질 — 스토리 진행 중, 바위 곁에서 낚아 올린 것 (fishing이 부른다)
func story13_special_bite() -> bool:
	if GameData.story13_phase != "spot":
		return false
	if m.player_tile().distance_to(Vector2i(m.BRACELET_ROCK)) > 6.0:
		return false
	GameData.story13_phase = "box"
	GameData.items["old_box"] = 1
	GameData.discover("old_box")
	Sound.play_sfx("sfx_catch")
	m.renderer.spawn_particles(m.player_tile(), "sparkle")
	m.hud.show_message("묵직한 입질...! 물고기가 아니다 —\n바닷물에 오래 잠겨 있던 낡은 작은 상자다!", 6.0)
	m.hud.quest_start_toast("낡은 상자 — 녹슬어 열 수 없다. 연금술사에게 가져가자")
	m.saveio.save_now()
	return true


# 퀘스트 2 — 상자 개봉: 연금술사의 손을 빌린다 (오두막 문·묘연에게 E)
func _start_box_help_dialog() -> void:
	m.dialog.open_seq("묘연", m.tex["npc_alchemist_portrait_normal"], [
		{"text": "「어서 와요. ...어머, 그 상자.\n바닷물을 오래 먹었네요. 이리 줘 봐요.」"},
		{"text": "(묘연이 상자를 이리저리 돌려 보았다.\n경첩은 녹으로 굳었고, 자물쇠는 소금이\n하얗게 껴 있다.)"},
		{"text": "「억지로 비틀면 안의 것까지 상해요.\n녹을 녹이는 약을 만들어서, 천천히\n열어야 해요.」"},
		{"text": "「%s — 이만큼만 구해다 줘요.\n빛이 소금을 풀고, 유리가 녹을 걷어 내죠.\n연금술은 이럴 때 쓰는 거예요.」" % GameData.story13_mats_text(),
			"portrait": m.tex["npc_alchemist_portrait_happy"]},
	], _end_box_help)


func _end_box_help() -> void:
	if GameData.story13_phase == "box":
		GameData.story13_phase = "open"
		m.hud.quest_start_toast("개봉 재료 — " + GameData.story13_mats_text())
	m.saveio.save_now()


# 퀘스트 3 — 개봉: 두 번째 유품 「할머니의 팔찌」
func _start_box_open_dialog() -> void:
	if not GameData.story13_mats_ok():
		m.dialog.open_seq("묘연", m.tex["npc_alchemist_portrait_normal"], [
			{"text": "「재료는 어때요? — %s.」" % GameData.story13_mats_text()},
			{"text": "「발광 버섯은 동굴 바닥에, 유리 조각은\n해변 모래밭에... 상자는 도망 안 가요.\n찬찬히 모아 와요.」"},
		])
		return
	m.dialog.open_seq("묘연", m.tex["npc_alchemist_portrait_happy"], [
		{"text": "「좋아요, 다 모였네요. 자, 시작할게요.」"},
		{"text": "(묘연이 재료를 끓여 은은히 빛나는 약을\n만들더니, 상자의 경첩과 자물쇠에\n한 방울씩 조심스레 떨어뜨렸다.)"},
		{"text": "(녹과 소금이 스르르 풀리고... 딸깍.\n상자가 조용히 열렸다.)"},
		{"text": "「...팔찌네요. 바닷물에 그리 오래 잠겼는데,\n하나도 녹슬지 않았어요. 아껴 준 물건은\n쉽게 상하지 않는 법이죠.」",
			"portrait": m.tex["npc_alchemist_portrait_normal"]},
		{"text": "「그분 노트에 적어 둬요. 그리고...\n도서관의 사서 씨도 분명 반가워할 거예요.」",
			"portrait": m.tex["npc_alchemist_portrait_happy"]},
	], _end_box_open)


# ---- 메인 스토리 14: 마을의 첫 축제 ----
#
# 스토리 13 뒤 자유 생활을 며칠 보내면 이장이 회관에서 회의를 연다.
# 준비는 여섯 중 셋만 — 주민들도 저마다 제 몫을 맡는다.
# 이튿날 광장에서 축제(전용 대사 + 투호) -> 이장의 마무리 -> 캘린더 해금.

func _story14_update(_delta: float) -> void:
	if Net.is_guest():
		return
	if GameData.story14_phase == "" and GameData.story14_ready():
		GameData.story14_phase = "meet"
		m.hud.quest_start_toast("이장이 마을회관에서 회의를 연다고 한다")
		m.saveio.save_now()


# 퀘스트 1 — 회관 회의: 첫 공식 축제를 열자
func _start_fest_meet_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_happy"], [
		{"text": "「다들 모였는가! 오늘 회의는 좋은 이야길세.」"},
		{"text": "「자네가 온 뒤로 주민이 이만큼 늘었네.\n빈집만 늘어가던 마을이 말이야...」"},
		{"text": "「그래서 말인데 — 우리 손으로 축제를\n열어 보세! 옛날엔 계절마다 모이는 날이\n있었지만, 마을이 여는 첫 공식 축제일세.」"},
		{"text": "「준비할 건 많네만, 다들 하나씩 맡기로 했네.\n나는 밭 것을, 민지는 음식을, 철수는 생선을,\n보라는 목장 것을, 무쇠는 장작을...」",
			"portrait": m.tex["npc_chief_portrait_normal"]},
		{"text": "「자네는 그중 %d가지만 거들어 주게.\n어느 걸 맡을지는 자네가 고르고 —\n회관 접수대에 내놓으면 되네.」" % GameData.STORY14_PICK,
			"portrait": m.tex["npc_chief_portrait_happy"]},
	], _end_fest_meet)


func _end_fest_meet() -> void:
	if GameData.story14_phase == "meet":
		GameData.story14_phase = "prep"
		GameData.story14_tasks = []
		GameData.story14_greet = []
		m.hud.story_banner("메인 스토리 14 시작", "마을의 첫 축제")
		m.hud.quest_start_toast("축제 준비 — 여섯 가지 중 %d가지만 고르자"
			% GameData.STORY14_PICK)
	m.saveio.save_now()


# 준비 기간의 주민 대사 — 다들 제 몫을 챙기고 있다 (한 사람당 한 번)
const PREP_LINES := {
	"chief": "「내 몫은 밭 것일세. 무를 뽑아 두었지.\n자네는 자네가 고른 것만 챙기게!」",
	"merchant": "「나는 음식 담당! 가게 문 일찍 닫고\n하루 종일 부칠 거야. 기대해도 좋아~」",
	"blacksmith": "「장작은 내가 팬다. 팔 힘이야 남아돌지.\n모닥불은 크게 지펴야 제맛이거든.」",
	"fisher": "「생선은 내가 맡았어! 새벽에 나가서\n제일 좋은 놈으로 골라 올 거야.」",
	"rancher": "「달걀이랑 우유는 우리 애들이 책임져!\n애들도 축제라니까 신났나 봐~」",
	"librarian": "「저는 광장 장식을 맡았어요.\n화분을 어디에 둘지 도면까지 그렸답니다.」",
	"explorer": "「축제라니! 내가 숲에서 재밌는 얘깃거리\n하나 물어 오지. 밤에 들려줄게.」",
	"forest_mom": "「솔이가 축제 이야기에 잠을 못 자더라.\n우리도 그날은 마을로 내려갈게.」",
	"forest_girl": "「엄마가 축제 가도 된댔어요!\n저 광장 처음 가 봐요...!」",
}
const PREP_LINE_DEFAULT := "「축제 준비 도와줄까? 나도 뭐라도 하고 싶은데!\n마을에 이런 날이 다 오네.」"


func story14_prep_greet(nid: String) -> bool:
	if GameData.story14_phase != "prep" or nid in GameData.story14_greet:
		return false
	GameData.story14_greet.append(nid)
	m.dialog.open_seq(str(GameData.NPCS[nid].name),
		m.tex.get("npc_%s_portrait_happy" % nid,
			m.tex.get("npc_%s_portrait_normal" % nid)),
		[{"text": str(PREP_LINES.get(nid, PREP_LINE_DEFAULT))}])
	return true


# 준비를 마치고 이장에게 — 축제는 이튿날 광장에서
func _start_fest_ready_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_happy"], [
		{"text": "「오오, 이만하면 넉넉하네! 자네 덕에\n상이 그득하겠구먼.」"},
		{"text": "「다른 사람들 몫도 다 들어왔네.\n광장에 자리도 다 잡아 두었고 말이야.」"},
		{"text": "「그럼 — 내일 아침, 광장에서 보세!\n마을의 첫 축제일세!」"},
	], _end_fest_ready)


func _end_fest_ready() -> void:
	if GameData.story14_phase != "prep" or not GameData.fest_prep_done():
		return
	GameData.story14_phase = "fest"
	GameData.story14_fest_day = GameData.day + 1
	GameData.story14_toss = false
	m.hud.event_toast("내일은 마을 축제!")
	m.hud.quest_start_toast("내일 아침, 광장에서 첫 축제가 열린다")
	m.saveio.save_now()


# 축제 당일 — 주민들의 축제 전용 대사
const FEST_LINES := {
	"chief": "「하하! 이 사람들 좀 보게 —\n마을이 이렇게 북적인 게 대체 몇 해 만인가!」",
	"merchant": "「자, 부침개 갓 부쳤어요~ 오늘은 공짜!\n축제니까 특별히!」",
	"blacksmith": "「모닥불 잘 타지? 내가 팬 장작일세.\n...불빛이 좋구먼. 참 좋아.」",
	"fisher": "「생선 구이 하나 들고 가! 내가 새벽에\n직접 낚은 거라니까?」",
	"rancher": "「우리 애들도 데려왔어! 저기 봐,\n닭이 아이들이랑 놀고 있잖아~」",
	"librarian": "「화분 배치, 예쁘죠? ...오늘은 책 대신\n사람들을 구경하고 있어요.」",
	"explorer": "「축제 좋다! 여기저기 떠돌아다녔지만\n이런 밤은 오랜만이야.」",
	"forest_mom": "「솔이가 저렇게 웃는 건 참 오랜만이야.\n...데려오길 잘했어. 고마워.」",
	"forest_girl": "「저기요! 저기 불꽃 봤어요?\n오늘 하루가 제일 재밌어요!」",
}
const FEST_LINE_DEFAULT := "「이런 날이 오다니! 이 마을로 오길 잘했어.\n내년에도 꼭 열자, 응?」"


func story14_fest_greet(nid: String) -> bool:
	if GameData.story14_phase != "fest" or GameData.day < GameData.story14_fest_day:
		return false
	m.dialog.open_seq(str(GameData.NPCS[nid].name),
		m.tex.get("npc_%s_portrait_happy" % nid,
			m.tex.get("npc_%s_portrait_normal" % nid)),
		[{"text": str(FEST_LINES.get(nid, FEST_LINE_DEFAULT))}])
	return true


# 축제 진행 — 이장에게 말을 걸면 놀거리와 마무리를 고른다
func open_fest_day_dialog() -> void:
	var btns: Array = [
		["투호 던지기 (미니게임)", _fest_toss],
		["축제를 마무리한다", _start_fest_end_dialog],
		["더 둘러본다", null],
	]
	m.dialog.open("마을 축제",
		"광장 한복판에 모닥불이 타오르고,\n상에는 마을 사람들이 낸 음식이 그득하다.\n\n"
		+ "「즐기고 있는가? 놀거리도 있다네!」", btns)


# 투호 — 세 번 던져 맞힌 수만큼 상금 (행운이 높으면 잘 들어간다)
func _fest_toss() -> void:
	var hit := 0
	for i in 3:
		if randf() < 0.5 + GameData.total_luck() * 0.02:
			hit += 1
	var prize := hit * 300
	GameData.money += prize
	Sound.play_sfx("sfx_coin" if hit > 0 else "sfx_miss")
	var body := "화살 셋을 항아리에 던졌다 — %d개 명중!\n\n" % hit
	if hit >= 3:
		body += "「세 발 다 넣다니! 오늘의 주인공일세!」\n상금 %dG를 받았다." % prize
	elif hit > 0:
		body += "「좋아, 좋아! 제법이구먼.」\n상금 %dG를 받았다." % prize
	else:
		body += "「하하, 다음엔 더 잘 되겠지!\n자, 부침개나 한 장 들게.」"
	if not GameData.story14_toss:
		GameData.story14_toss = true
		for n in m.npcs:
			if GameData.affinity.has(n.id):
				GameData.affinity[n.id] = int(GameData.affinity[n.id]) + 2
		body += "\n\n(다 같이 웃고 떠들었다 — 온 주민 호감도 +2)"
	m.dialog.open("투호 던지기", body, [["즐거웠다", open_fest_day_dialog]])
	m.saveio.save_now()


# 축제 마무리 — 처음 왔을 때와 견주는 이장의 인사 (스토리 14 완결)
func _start_fest_end_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_happy"], [
		{"text": "「...자네, 처음 이 마을에 왔던 날 기억하나?」"},
		{"text": "「집도 상점도 없고, 나 하나 남아\n빈 집만 지키고 있었지. 솔직히 말하면 —\n이 마을은 끝났다고 생각했다네.」",
			"portrait": m.tex["npc_chief_portrait_normal"]},
		{"text": "(모닥불 너머로 웃음소리가 번진다.\n상점 주인도, 대장장이도, 아이들도,\n숲에서 내려온 모녀까지 모두 여기 있다.)"},
		{"text": "「그런데 지금 이 소리 좀 듣게.\n...고맙네. 정말로.」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
		{"text": "「앞으로는 회관에서 축제와 행사 일정을\n제대로 챙기겠네. 다음 계절 축제도\n마을이 함께 준비하는 걸세!」"},
	], _end_fest_day)


func _end_fest_day() -> void:
	if GameData.story14_phase != "fest":
		return
	GameData.story14_phase = "done"
	GameData.story14_done_day = GameData.day
	m.hud.story_banner("메인 스토리 14 완결", "마을의 첫 축제")
	m.hud.show_message("마을의 첫 축제가 끝났다!\n마을회관에서 「축제·행사 일정」을 볼 수 있게 됐다.", 7.0)
	m.saveio.save_now()


# ---- 메인 스토리 15: 마른 온천 ----
#
# 이장의 옛 온천 이야기 -> 서하의 기록(동굴 지하 수맥) -> 무쇠의 착암
# 쐐기 -> 동굴 20층 아래에서 몬스터·무너진 바위를 치우고 수맥을 뚫기 ->
# 묘연의 물 확인 -> 마을 온천 부활 (하루 한 번 입욕 = 체력 회복).

func _story15_update(_delta: float) -> void:
	if Net.is_guest():
		return
	if GameData.story15_phase == "" and GameData.story15_ready():
		GameData.story15_phase = "tale"
		m.hud.quest_start_toast("이장이 옛날 이야기를 하나 들려주고 싶어 한다")
		m.saveio.save_now()
	# 온천이 되살아나 있으면 세상에 놓아 둔다 (로드 직후 포함)
	if GameData.onsen_open:
		m.worldgen._spawn_onsen()


# 퀘스트 1 — 이장: 물이 끊긴 옛 온천
func _start_onsen_tale_dialog() -> void:
	m.dialog.open_seq("이장", m.tex["npc_chief_portrait_normal"], [
		{"text": "「축제 때 하도 옛날 얘기가 나와서 말인데 —\n자네, 우리 마을에 온천이 있었던 건 아나?」"},
		{"text": "「마을 북쪽 바위 밑에서 김이 폴폴 나는\n작은 탕이었네. 밭일 끝나고 다들 거기\n몸을 담갔지. 자네 할아버지도 단골이었고.」"},
		{"text": "「그런데 어느 해부터 물이 뚝 끊겼어.\n바위만 덩그러니 남고... 이유는 아무도 몰라.」"},
		{"text": "「사서 선생이라면 옛 기록에서 뭔가\n찾아낼지도 모르겠구먼. 한번 물어봐 주겠나?」",
			"portrait": m.tex["npc_chief_portrait_happy"]},
	], _end_onsen_tale)


func _end_onsen_tale() -> void:
	if GameData.story15_phase == "tale":
		GameData.story15_phase = "book"
		m.hud.story_banner("메인 스토리 15 시작", "마른 온천")
		m.hud.quest_start_toast("도서관에서 온천 기록을 찾아보자")
	m.saveio.save_now()


# 퀘스트 2 — 서하: 온천수는 동굴 지하 수맥과 이어져 있었다
func _start_onsen_book_dialog() -> void:
	m.dialog.open_seq("서하", m.tex["npc_librarian_portrait_normal"], [
		{"text": "「온천이요? ...아, 있어요! 옛 마을 지질도.\n여기 물길이 그려져 있네요.」"},
		{"text": "(빛바랜 도면에 마을 북쪽 바위에서\n땅속으로 뻗어 내려가는 실선이 있다.\n선은 동굴 깊은 곳까지 이어진다.)"},
		{"text": "「온천수는 동굴 지하 수맥에서 올라오던\n거예요. 기록엔 『%d길 아래 물길이 무너져\n막혔다』고 적혀 있고요.」" % GameData.STORY15_DEPTH,
			"portrait": m.tex["npc_librarian_portrait_happy"]},
		{"text": "「바위가 무너져 길을 막은 거라면...\n사람 손으로 뚫을 수 있을지도 몰라요.\n무쇠 씨에게 연장을 부탁해 보세요.」"},
	], _end_onsen_book)


func _end_onsen_book() -> void:
	if GameData.story15_phase == "book":
		GameData.story15_phase = "tool"
		m.hud.quest_start_toast("무쇠에게 수맥을 뚫을 연장을 부탁하자")
	m.saveio.save_now()


# 퀘스트 3 — 무쇠: 착암 쐐기를 벼린다
func _start_onsen_tool_dialog() -> void:
	var ore := int(GameData.items.get("ore", 0))
	var shard := int(GameData.items.get("star_shard", 0))
	if ore < GameData.STORY15_TOOL_ORE or shard < GameData.STORY15_TOOL_SHARD:
		m.dialog.open_seq("무쇠", m.tex["npc_blacksmith_portrait_normal"], [
			{"text": "「수맥을 막은 바위를 뚫겠다고?\n그럼 보통 곡괭이로는 안 되지.」"},
			{"text": "「착암 쐐기를 벼려 주겠네 —\n광석 %d개와 별빛 조각 %d개를 가져오게.\n(지금 광석 %d·조각 %d)」" % [
				GameData.STORY15_TOOL_ORE, GameData.STORY15_TOOL_SHARD, ore, shard]},
		])
		return
	m.dialog.open_seq("무쇠", m.tex["npc_blacksmith_portrait_normal"], [
		{"text": "「좋아, 재료는 넉넉하군. 잠깐 기다리게.」"},
		{"text": "(화로가 하얗게 타오르고, 무쇠가\n쇠를 접고 또 접어 뾰족한 쐐기를 벼렸다.)"},
		{"text": "「자, 착암 쐐기일세. 바위 결을 찾아\n한 번에 때리게 — 힘으로 하는 게 아니야.」",
			"portrait": m.tex["npc_blacksmith_portrait_happy"]},
		{"text": "「깊은 굴은 위험하네. 무너진 자리엔\n으레 험한 것들이 꼬이는 법이니\n무기부터 챙기게.」"},
	], _end_onsen_tool)


func _end_onsen_tool() -> void:
	if GameData.story15_phase != "tool" \
			or int(GameData.items.get("ore", 0)) < GameData.STORY15_TOOL_ORE \
			or int(GameData.items.get("star_shard", 0)) < GameData.STORY15_TOOL_SHARD:
		return
	GameData.items["ore"] = int(GameData.items["ore"]) - GameData.STORY15_TOOL_ORE
	GameData.items["star_shard"] = int(GameData.items["star_shard"]) \
		- GameData.STORY15_TOOL_SHARD
	GameData.items["rock_wedge"] = 1
	GameData.discover("rock_wedge")
	GameData.story15_phase = "dig"
	GameData.story15_mobs = 0
	GameData.story15_ore = 0
	m.hud.reward_toast("착암 쐐기", m.tex.get("rock_wedge"))
	m.hud.quest_start_toast("동굴 %d층 아래 — 수맥을 막은 자리를 치우자"
		% GameData.STORY15_DEPTH)
	m.saveio.save_now()


# 동굴에서 수맥 둘레를 치운다 (cave_ui가 처치·채굴 때마다 부른다)
func story15_dig_progress(kind: String, floor_num: int) -> void:
	if GameData.story15_phase != "dig" or floor_num < GameData.STORY15_DEPTH:
		return
	if kind == "mob":
		GameData.story15_mobs += 1
	else:
		GameData.story15_ore += 1
	if not GameData.story15_dig_done():
		return
	# 다 치웠다 — 쐐기를 박아 넣으면 물이 솟는다
	GameData.story15_phase = "water"
	GameData.items["rock_wedge"] = 0
	GameData.items["spring_water"] = 1
	GameData.discover("spring_water")
	Sound.play_sfx("sfx_catch")
	m.hud.event_toast("수맥이 뚫렸다!")
	m.hud.show_message("무너진 바위를 다 걷어내고 쐐기를 박아 넣자 —\n쩍, 하고 금이 가며 따뜻한 물이 솟아올랐다!\n표본을 한 병 담았다. 묘연에게 보여주자.", 8.0)
	m.saveio.save_now()


# 퀘스트 4 — 묘연: 물의 상태를 살핀다 (스토리 15 완결)
func _start_onsen_water_dialog() -> void:
	m.dialog.open_seq("묘연", m.tex["npc_alchemist_portrait_normal"], [
		{"text": "「물이 다시 솟았다고요? 어디 봐요.」"},
		{"text": "(묘연이 표본을 등불에 비추고,\n손끝으로 찍어 맛을 보았다.)"},
		{"text": "「...좋은 물이에요. 땅속 깊은 데서\n돌을 오래 지나온 물. 몸을 담그면\n피로가 풀릴 거예요.」",
			"portrait": m.tex["npc_alchemist_portrait_happy"]},
		{"text": "「막힌 데를 뚫었으니 마을 쪽 탕에도\n곧 물이 찰 거예요. ...옛날에 그분도\n거기서 자주 쉬셨다던데.」"},
	], _end_onsen_water)


func _end_onsen_water() -> void:
	if GameData.story15_phase != "water":
		return
	GameData.items["spring_water"] = 0
	GameData.story15_phase = "done"
	GameData.onsen_open = true
	m.worldgen._spawn_onsen()
	m.npcmgr._sync_village_npcs()
	m.hud.story_banner("메인 스토리 15 완결", "마른 온천")
	m.hud.show_message("마을 북쪽 온천에 다시 물이 찼다!\n하루 한 번 몸을 담그면 체력이 가득 찬다. (E)", 8.0)
	m.queue_redraw()
	m.saveio.save_now()


# 온천 (E) — 하루 한 번 입욕
func onsen_enter() -> void:
	if GameData.onsen_day == GameData.day:
		m.dialog.open("마을 온천",
			"오늘은 이미 실컷 담갔다.\n김이 오르는 물결을 바라보기만 해도 개운하다.",
			[["내일 또 오자", null]])
		return
	m.dialog.open("마을 온천",
		"바위 틈에서 더운 물이 콸콸 솟는다.\n김 너머로 마을 지붕들이 어른거린다.\n\n몸을 담그면 %d시간이 흐르고 체력이 가득 찬다."
			% int(GameData.ONSEN_HOURS),
		[["몸을 담근다", _do_onsen], ["나중에", null]])


# 온천에 몸을 담그러 온 주민의 이야기 — 마을이 달라졌다는 실감
const ONSEN_LINES := {
	"blacksmith": ["「크으... 이 맛이지. 화로 앞에서 굳은 어깨가\n싹 풀린다니까.」",
		"「자네 아니었으면 이 물은 영영 안 나왔을 걸세.\n덕분에 늙은 뼈가 호강하는구먼.」"],
	"chief": ["「하아... 젊었을 적엔 매일 여기서 살다시피 했지.\n다시 담글 줄은 몰랐네.」",
		"「물이 도니 마을에 온기가 도는 것 같구먼.\n자네 할아버지도 여기 단골이었네.」"],
	"merchant": ["「장사 끝나고 오는 게 요즘 낙이야~\n어깨 결림이 싹 가셔!」",
		"「이참에 온천 앞에 노점을 하나 더 낼까?\n...농담이야, 농담!」"],
}
const ONSEN_LINE_DEFAULT := "「온천 좋다~ 이런 게 있었는지도 몰랐어.\n마을에 하나쯤 있으니 참 좋네.」"


func onsen_npc_line(nid: String) -> void:
	var lines: Array = ONSEN_LINES.get(nid, [ONSEN_LINE_DEFAULT])
	m.dialog.open_seq(str(GameData.NPCS[nid].name),
		m.tex.get("npc_%s_portrait_happy" % nid,
			m.tex.get("npc_%s_portrait_normal" % nid)),
		[{"text": str(lines[randi() % lines.size()])}])


func _do_onsen() -> void:
	if not GameData.onsen_bathe():
		return
	Sound.play_sfx("sfx_sleep")
	m.saveio.save_now()
	m.dialog.open("마을 온천",
		"뜨끈한 물에 어깨까지 담갔다.\n뭉친 데가 스르르 풀린다...\n\n체력이 가득 찼다!",
		[["개운하다", null]])


func _end_box_open() -> void:
	if GameData.story13_phase != "open" or not GameData.story13_mats_ok():
		return
	for mid in GameData.STORY13_MATS:
		GameData.items[mid] = int(GameData.items[mid]) - int(GameData.STORY13_MATS[mid])
	GameData.items["old_box"] = 0
	GameData.try_relic(1, 0.0, true)   # 「할머니의 팔찌」 — 노트·수집 현황 반영
	GameData.story13_phase = "record"
	m.hud.quest_start_toast("도서관에서 「할머니의 기록」을 읽어 보자")
	m.saveio.save_now()


# ---- 엔딩: 연화의 항아리 ----
#
# 연구 노트 100% + 생명의 물 여섯 병을 모아 연화를 찾아가면,
# 항아리에 물을 붓고 「기억의 물약」을 만들어 준다. 마시고 잠들면
# 꿈속 엔딩 시퀀스(ending_ui)로 이어진다.

func _start_elixir_dialog() -> void:
	m.dialog.open_seq("연화", m.tex["npc_forest_mom_portrait_normal"], [
		{"text": "「그 병들... 그리고 그 유품들.\n...맙소사. 정말 다 모았구나.」"},
		{"text": "「일곱 갈래 삶을 끝까지 갈고닦은 물과,\n할머님의 다섯 유품 —」"},
		{"text": "「할아버지께서 말씀하셨어. 이것들이 다시\n한자리에 모이면, 꿈속에서 보고 싶은 사람을\n만날 수 있다고.」"},
		{"text": "(연화가 낡은 항아리를 꺼내\n생명의 물을 한 병씩 천천히 부었다.)"},
		{"text": "(항아리 속에서 은은한 빛이 피어오른다...)"},
		{"text": "「자 — 「기억의 물약」이야.\n오늘 밤, 마시고 푹 자렴.」",
			"portrait": m.tex["npc_forest_mom_portrait_happy"]},
		{"text": "「좋은 꿈 꾸길. ...분명, 만나고 싶던 분들이\n기다리고 계실 거야.」"},
	], _end_elixir)


# ---- 주민 이사 시스템 — 일반/특수 주민의 입주와 이탈 ----
#
# 스토리 3(무진의 이사)을 겪은 뒤부터, 빈 집터(또는 떠난 주민이 남긴
# 빈 집)가 있으면 아침마다 낮은 확률로 「이사 신청 편지」가 온다.
# 가방에서 읽고 수락해야 입주한다. 연금술사 묘연(특수)은 연구 노트
# 50%를 넘기면 소문을 듣고 확정적으로 편지를 보낸다.
# 정착한 주민은 호감도가 낮거나 오래 말을 안 걸면 떠날 마음이 생긴다.

const SETTLE_LETTERS := {
	"farmer": "『안녕하십니까! 흙 좋기로 소문난 교진 마을에\n밭 한 뙈기 일구고 싶은 농부, 순돌이라고 합니다.\n받아 주신다면 부지런히 살겠습니다!』",
	"foodie": "『안녕하세요~ 교진 마을 음식이 그렇게 맛있다면서요?\n먹는 게 인생의 낙인 다미라고 해요.\n저도 그 마을에서 살아 보고 싶어요!』",
	"angler": "『물 좋고 고기 잘 문다는 소문을 들었습니다.\n낚싯대 하나 메고 떠도는 강태라고 합니다.\n마을 물가 한켠을 내어 주시겠습니까?』",
	"alchemist": "『당신의 연구 이야기가 바람을 타고 들려왔어요.\n그분의 노트를 잇는 사람이 있다니...\n연금술사 묘연, 그 마을에서 연구를 함께하고 싶어요.』",
	"miner": "『굴이 깊고 돌이 좋다는 소문을 들었소.\n곡괭이 하나로 잔뼈가 굵은 광부 바우요.\n방 한 칸 내주면 돌 캐는 소리로 보답하리다!』",
	"florist": "『바람에 실려 온 꽃냄새를 따라왔어요.\n꽃을 가꾸는 봄이라고 해요.\n마을 골목마다 꽃을 피워 드리고 싶어요!』",
	"carpenter": "『나무 좋은 마을이라 들었네. 목수 덕구일세.\n삐걱대는 문짝이든 기울어진 서까래든\n내 대패가 지나가면 반듯해진다네. 받아 주겠나?』",
	"herbalist": "『산비탈 약초 냄새가 여기까지 나더군요.\n약초를 다루는 향이라고 합니다.\n아픈 이웃에게 차 한 잔 우려 드리며 살고 싶어요.』",
	"painter": "『그 마을 노을이 그렇게 곱다면서요.\n떠돌이 화가 청람이라 합니다.\n그 빛을 화폭에 담게 자리 하나 내주시겠습니까?』",
	"musician": "『파도 소리가 노래 같은 마을이라 들었어요.\n악사 한별이에요. 축제엔 흥을, 슬픈 날엔\n위로를 — 노래로 보답할게요!』",
	"weaver": "『베틀 놓을 조용한 방 한 칸이면 됩니다.\n길쌈꾼 솜이라고 해요. 겨울이 오기 전에\n마을 분들 목도리를 떠 드리고 싶어요.』",
}


func _settler_update(_delta: float) -> void:
	if Net.is_guest() or GameData.move_quest != "done":
		return
	# ① 이사 도착 — 수락한 다음 날 아침, 새 주민이 자리를 잡는다
	if GameData.settler_arrive != "" and GameData.day > GameData.settler_arrive_day:
		var nid := GameData.settler_arrive
		GameData.settler_arrive = ""
		if nid not in GameData.settlers:
			GameData.settlers.append(nid)
		if not GameData.npc_greeted.has(nid):
			GameData.npc_greeted.append(nid)
		GameData.npc_last_talk[nid] = GameData.day
		m.npcmgr._sync_village_npcs()
		m.hud.event_toast("%s이(가) 마을에 이사 왔다!" % GameData.NPCS[nid].name)
		m.saveio.save_now()
	# ② 이사 신청 편지 — 하루 한 번만 굴린다 (들어올 자리가 있어야)
	if GameData.settler_offer == "" and GameData.settler_arrive == "" \
			and int(GameData.items["settle_letter"]) == 0 \
			and GameData.settler_offer_day != GameData.day:
		GameData.settler_offer_day = GameData.day
		var cands: Array = GameData.settler_candidates()
		var has_spot: bool = GameData.first_empty_plot().x >= 0 \
			or not GameData.empty_houses.is_empty()
		if not cands.is_empty() and has_spot:
			# 특수 주민(연금술사)은 조건이 차면 소문을 듣고 반드시 온다
			var special: bool = str(cands[0]) == "alchemist"
			if special or randf() < GameData.SETTLER_OFFER_CHANCE:
				GameData.settler_offer = str(cands[0]) if special \
					else str(cands[randi() % cands.size()])
				GameData.items["settle_letter"] = 1
				m.hud.quest_start_toast("이사 신청 편지가 왔다 — 가방(I)에서 읽어 보자")
				m.saveio.save_now()
	# ③ 이탈 — 아침마다 정착 주민들의 마음을 살핀다
	if GameData.settler_leave_day != GameData.day:
		GameData.settler_leave_day = GameData.day
		for nid2: String in GameData.settlers.duplicate():
			if GameData.settler_leaving == nid2:
				continue
			var aff := int(GameData.affinity[nid2])
			if aff >= GameData.SAFE_AFF:
				continue   # 마음이 깊으면 떠날 생각을 하지 않는다
			var neglected: bool = GameData.day \
				- int(GameData.npc_last_talk.get(nid2, GameData.day)) \
				> GameData.NEGLECT_DAYS
			if aff >= GameData.LEAVE_AFF and not neglected:
				continue
			if randf() >= GameData.LEAVE_CHANCE:
				continue
			if randf() < GameData.SILENT_LEAVE:
				_settler_depart(nid2, true)   # 드물게 — 말없이 편지만 남기고
			else:
				GameData.settler_leaving = nid2   # 직접 말하러 온다 (❗)
				m.saveio.save_now()


# 이사 신청 편지 읽기 (가방에서 클릭)
func open_settle_letter() -> void:
	var nid := GameData.settler_offer
	if nid == "" or int(GameData.items["settle_letter"]) <= 0:
		GameData.items["settle_letter"] = 0
		return
	var body: String = str(SETTLE_LETTERS.get(nid, "『마을에서 살고 싶습니다.』"))
	m.dialog.open("이사 신청 편지 — %s" % GameData.NPCS[nid].name, body, [
		["이사를 수락한다", _settle_accept],
		["정중히 거절한다", _settle_decline],
		["나중에 정한다", null],
	])


func _settle_accept() -> void:
	var nid := GameData.settler_offer
	if nid == "":
		m.dialog.close()
		return
	# 자리: 떠난 주민이 남긴 빈 집이 먼저, 없으면 빈 집터에 새로 짓는다
	var anchor := Vector2i(-999, -999)
	if not GameData.empty_houses.is_empty():
		var h: Array = GameData.empty_houses.pop_front()
		anchor = Vector2i(int(h[0]), int(h[1]))
	else:
		var plot: Vector2i = GameData.first_empty_plot()
		if plot.x < 0:
			m.dialog.close()
			m.hud.show_message("빈 집터가 없다 — 집터를 마련하면 초대할 수 있다.", 5.0)
			return
		for p: Dictionary in GameData.home_plots:
			if int(p.x) == plot.x and int(p.y) == plot.y:
				p.used = true
				break
		anchor = plot
		m.objnode._remove_object(m.door_tile(plot))
		for y in range(plot.y - 1, plot.y + 5):
			for x in range(plot.x - 1, plot.x + 6):
				if m.objects.has(Vector2i(x, y)):
					m.objnode._remove_object(Vector2i(x, y))
		m.worldgen._fill_building(plot)
		m.objects.erase(m.door_tile(plot))
	m.dialog.close()
	GameData.items["settle_letter"] = 0
	GameData.settler_offer = ""
	GameData.settler_homes[nid] = [anchor.x, anchor.y]
	GameData.settler_arrive = nid
	GameData.settler_arrive_day = GameData.day
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("이사 수락 — 내일 %s이(가) 온다!" % GameData.NPCS[nid].name)
	m.queue_redraw()
	m.saveio.save_now()


func _settle_decline() -> void:
	m.dialog.close()
	GameData.items["settle_letter"] = 0
	GameData.settler_offer = ""
	m.hud.show_message("정중히 거절하는 답장을 보냈다. 인연이 닿으면 또 편지가 올 것이다.", 5.0)
	m.saveio.save_now()


# 「이사를 가고 싶다」 — 떠나려는 주민의 속마음 (붙잡을 수 있다)
func start_leaving_dialog(nid: String) -> void:
	var nm := str(GameData.NPCS[nid].name)
	m.dialog.open_seq(nm, m.tex.get("npc_%s_portrait_normal" % nid), [
		{"text": "「...저기, 할 말이 있어.」"},
		{"text": "「요즘 마을 생활이 영 겉도는 것 같아서...\n나, 이사를 가 볼까 해.」"},
		{"text": "「넌... 어떻게 생각해?」", "choices": [
			["가지 마! 내가 더 잘할게", _leave_persuade.bind(nid)],
			["...네 뜻이 그렇다면", _leave_letgo.bind(nid)],
		]},
	])


func _leave_persuade(nid: String) -> void:
	m.dialog.close()
	GameData.settler_leaving = ""
	GameData.affinity[nid] = int(GameData.affinity[nid]) + 15
	GameData.npc_last_talk[nid] = GameData.day
	Sound.play_sfx("sfx_heart")
	m.hud.show_message("%s이(가) 조금 놀란 얼굴로... 이내 배시시 웃었다. (호감도 +15)\n앞으로 자주 들여다보자 — 마음이 식으면 또 떠나고 싶어진다."
		% GameData.NPCS[nid].name, 6.0)
	m.saveio.save_now()


func _leave_letgo(nid: String) -> void:
	m.dialog.close()
	GameData.settler_leaving = ""
	_settler_depart(nid, false)


# 주민이 마을을 떠난다 — 집은 빈 채로 남아 다음 주민을 기다린다
func _settler_depart(nid: String, silent: bool) -> void:
	GameData.settlers.erase(nid)
	if GameData.settler_leaving == nid:
		GameData.settler_leaving = ""
	if GameData.settler_homes.has(nid):
		GameData.empty_houses.append(GameData.settler_homes[nid])
		GameData.settler_homes.erase(nid)
	for n in m.npcs.duplicate():
		if n.id == nid:
			m.npcs.erase(n)
			n.queue_free()
	var nm := str(GameData.NPCS[nid].name)
	if silent:
		GameData.items["farewell_letter"] = \
			int(GameData.items["farewell_letter"]) + 1
		GameData.last_farewell = nm
		m.hud.show_message("%s이(가) 말없이 마을을 떠났다...\n문 앞에 짧은 편지 한 통만 남아 있었다. (가방 I)" % nm, 7.0)
	else:
		m.hud.show_message("%s이(가) 마을을 떠났다.\n빈 집은 남아 있다 — 언젠가 새 이웃이 올 것이다." % nm, 6.0)
	m.saveio.save_now()


# 말없이 떠난 주민의 작별 편지 (가방에서 클릭)
func open_farewell_letter() -> void:
	if int(GameData.items["farewell_letter"]) <= 0:
		return
	GameData.items["farewell_letter"] = \
		int(GameData.items["farewell_letter"]) - 1
	var nm := str(GameData.last_farewell)
	m.dialog.open("짧은 작별 편지",
		"『미안, 인사도 없이 떠나서.\n그동안 고마웠어. 몸 건강히 지내. — %s』\n\n(다음 이웃에게는 더 자주 말을 걸어 주자...)" % nm,
		[["편지를 접는다", null]])


func _end_elixir() -> void:
	if int(GameData.items["water_life"]) < GameData.ENDING_SKILLS.size() \
			or GameData.relics_owned() < GameData.RELICS.size() \
			or int(GameData.items["potion_dream"]) > 0 \
			or GameData.dream_ready or GameData.dream_seen:
		return
	GameData.items["water_life"] = 0   # 일곱 병 모두 항아리로 (유품은 간직한다)
	GameData.items["potion_dream"] = 1
	GameData.discover("potion_dream")
	m.hud.event_toast("기억의 물약을 얻었다!")
	m.hud.show_message("가방(I)에서 기억의 물약을 마시고, 침대에서 잠들자.", 6.0)
	m.saveio.save_now()
