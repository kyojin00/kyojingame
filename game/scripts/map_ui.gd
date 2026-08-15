# 지도 (M): 실제로 가 본 지역만 보여준다 (fog of war).
# 미탐사/미해금 지역은 검은색으로 가려지고, 탐사할수록 하나씩 공개된다.
#
# 조작: 마우스 휠 = 확대/축소 (커서 기준) · 끌기 = 이동 · R = 처음 크기로
extends CanvasLayer

# 배율 1 = 맵 전체가 화면에 딱 들어오는 크기. 맵이 커져도 알아서 맞는다.
func _base_cell() -> float:
	return minf(920.0 / float(main.MAP_W), 496.0 / float(main.MAP_H))
const FOG := Color(0.02, 0.02, 0.035)
const ZOOM_MIN := 0.7
const ZOOM_MAX := 5.0
const ZOOM_STEP := 1.2

var main: Node2D
var canvas: Control
var blink := 0.0

var zoom := 1.0
var pan := Vector2.ZERO       # 기본 위치에서 얼마나 밀었는지 (화면 픽셀)
var _drag := false
var _drag_from := Vector2.ZERO
var _hud_was := true          # 지도를 열기 전 HUD 표시 상태

# 이번 프레임의 그리기 기준 (셀 크기 / 원점) — 그릴 때 한 번 계산해 둔다
var _cell := 8.0
var _ox := 0.0
var _oy := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	# 두 Control 모두 마우스를 통과시켜야 한다.
	# 기본값(STOP)이면 GUI 단계에서 이벤트를 먹어 _unhandled_input이 아예 안 불리고,
	# 휠 확대와 끌기가 통째로 죽는다.
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.1, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_map)
	add_child(canvas)


func open() -> void:
	# 배율과 위치는 닫아도 그대로 둔다 (R로 처음 크기로 되돌린다)
	visible = true
	_drag = false
	# 지도를 보는 동안에는 HUD를 감춘다.
	# 미니맵·시계가 큰 지도 위에 겹쳐 보이는 것도 그렇지만, 무엇보다
	# 하단 핫바가 **버튼**이라 그 위에서 마우스를 놓으면 버튼이 이벤트를 먹는다.
	if main != null and main.hud != null:
		_hud_was = main.hud.visible
		main.hud.visible = false
	canvas.queue_redraw()


func close() -> void:
	visible = false
	_drag = false
	if main != null and main.hud != null:
		main.hud.visible = _hud_was


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# 배율 1 · 맵 전체가 화면에 들어오는 처음 상태
func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO


func _origin(c: float) -> Vector2:
	return Vector2((960.0 - main.MAP_W * c) / 2.0,
		(540.0 - main.MAP_H * c) / 2.0 + 2.0) + pan


# 커서 아래의 지점이 그대로 있도록 확대/축소한다
func _zoom_at(m: Vector2, factor: float) -> void:
	var c0 := _base_cell() * zoom
	var t := (m - _origin(c0)) / c0            # 커서가 가리키는 타일 좌표
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var c1 := _base_cell() * zoom
	pan = m - t * c1 - Vector2((960.0 - main.MAP_W * c1) / 2.0,
		(540.0 - main.MAP_H * c1) / 2.0 + 2.0)
	_clamp_pan()


# 지도를 화면 안에 붙들어 둔다.
#
# 예전에는 「지도 크기의 절반」까지 밀 수 있었다. 그래서 기본 배율에서도
# 지도가 화면 한쪽으로 확 밀려 나가 절반이 빈 공간이 됐다 — 끌기가 고장 난 것처럼 보인다.
# 지금은 지도가 화면보다 크면 **가장자리가 화면 안으로 들어오지 않게**(구석까지 볼 수 있다),
# 화면보다 작으면 **화면 밖으로 나가지 않게** 묶는다. 두 경우가 같은 식이 된다.
func _clamp_pan() -> void:
	var c := _base_cell() * zoom
	var lim_x: float = absf(float(main.MAP_W) * c - 960.0) / 2.0
	var lim_y: float = absf(float(main.MAP_H) * c - 540.0) / 2.0
	pan.x = clampf(pan.x, -lim_x, lim_x)
	pan.y = clampf(pan.y, -lim_y, lim_y)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			_drag_from = mb.position
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		pan += mm.relative
		_drag_from = mm.position
		_clamp_pan()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_R:
		reset_view()
		get_viewport().set_input_as_handled()


# 끌기를 끝내는 일은 세 겹으로 막아 둔다.
# 「눌림 해제」를 _unhandled_input에만 맡기면, 마우스를 먹는 Control 위에서
# 버튼을 놓았을 때 그 이벤트가 영영 오지 않아 지도가 계속 마우스를 따라다녔다.
#
# ① _input — GUI보다 **먼저** 오므로 핫바 버튼 위에서 놓아도 놓치지 않는다.
#    (여기서는 이벤트를 소비하지 않는다. 다른 UI 조작을 방해하면 안 된다)
func _input(event: InputEvent) -> void:
	if not visible or not _drag:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag = false


# ② 매 프레임 실제 버튼 상태 확인 — 창 밖에서 놓아 이벤트가 아예 없는 경우
func _stop_drag_if_released() -> void:
	if _drag and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag = false


# ③ 창이 포커스를 잃으면 (Alt+Tab 등) 끌기를 놓는다
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_drag = false


func _process(delta: float) -> void:
	if visible:
		blink += delta
		_stop_drag_if_released()
		canvas.queue_redraw()


# 이 타일을 지도에 보여줘도 되는가:
# 실제로 가 본 청크 + (내 부지이거나 공용 길/마을)만 표시한다.
# 미해금 부지는 탐사 여부와 관계없이 가린다.
func _visible_tile(x: int, y: int) -> bool:
	if not GameData.is_explored_tile(x, y):
		return false
	if GameData.is_tile_owned(x, y):
		return true
	return main.ROAD.has_point(Vector2i(x, y)) \
		or main.VILLAGE_REGION.has_point(Vector2i(x, y))


func _draw_map() -> void:
	_cell = _base_cell() * zoom
	var o := _origin(_cell)
	_ox = o.x
	_oy = o.y

	# 확대하면 대부분이 화면 밖이므로, 보이는 칸만 그린다
	var x0: int = maxi(0, int(floor(-_ox / _cell)))
	var x1: int = mini(main.MAP_W, int(ceil((960.0 - _ox) / _cell)) + 1)
	var y0: int = maxi(0, int(floor(-_oy / _cell)))
	var y1: int = mini(main.MAP_H, int(ceil((540.0 - _oy) / _cell)) + 1)

	# 지형 (미탐사/미해금은 검은색)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var r := Rect2(_ox + x * _cell, _oy + y * _cell, _cell + 0.5, _cell + 0.5)
			if not _visible_tile(x, y):
				canvas.draw_rect(r, FOG)
				continue
			var cell: Dictionary = main.grid[y][x]
			var c: Color
			if cell.ground == "water":
				c = Color(0.26, 0.45, 0.68)
			elif cell.ground == "sand":
				c = Color(0.85, 0.77, 0.55)
			elif cell.ground == "dock":
				c = Color(0.55, 0.38, 0.22)
			elif cell.ground == "path":
				c = Color(0.72, 0.62, 0.44)
			elif cell.ground == "soil":
				c = Color(0.42, 0.31, 0.19)
			else:
				match GameData.season():
					GameData.WINTER:
						c = Color(0.82, 0.85, 0.9)
					GameData.FALL:
						c = Color(0.62, 0.5, 0.3)
					_:
						c = Color(0.32, 0.52, 0.27)
			canvas.draw_rect(r, c)

	# 오브젝트 (보이는 지역만)
	for pos: Vector2i in main.objects:
		if pos.x < x0 or pos.x >= x1 or pos.y < y0 or pos.y >= y1:
			continue
		if not _visible_tile(pos.x, pos.y):
			continue
		var kind: String = main.objects[pos].kind
		var c: Color
		match kind:
			"tree":
				c = Color(0.15, 0.35, 0.14)
			"rock", "bigrock":
				c = Color(0.55, 0.55, 0.6)
			"house", "art_block":
				c = Color(0.62, 0.28, 0.2)
			"board", "sign":
				c = Color(0.95, 0.8, 0.35)
			_:
				c = Color(0.5, 0.4, 0.3)
		canvas.draw_rect(Rect2(_ox + pos.x * _cell, _oy + pos.y * _cell,
			_cell + 0.5, _cell + 0.5), c)

	# 동물/NPC (보이는 지역만)
	var dot: float = maxf(3.0, _cell * 0.5)
	for a in main.animals:
		if _visible_tile(int(a.position.x / 32.0), int(a.position.y / 32.0)):
			_dot(a.position, dot, Color(0.95, 0.95, 0.9))
	for n in main.npcs:
		if n.visible and _visible_tile(int(n.position.x / 32.0), int(n.position.y / 32.0)):
			_dot(n.position, dot, Color(0.95, 0.55, 0.75))

	# 시설 라벨 (그 위치를 발견했을 때만)
	_place_label(73, 28, "우리집")
	_place_label(18, 14, "농장")
	if GameData.barn_built:
		_place_label(main.BARN_POS.x, main.BARN_POS.y, "축사")
	if GameData.greenhouse_built:
		_place_label(main.GREENHOUSE.position.x + 4,
			main.GREENHOUSE.position.y + 3, "온실")
	# 세워 둔 말 (타고 있는 동안에는 내 위치와 같으므로 표시하지 않는다)
	if GameData.has_horse and not GameData.riding:
		var h: Vector2i = GameData.horse_tile
		canvas.draw_rect(Rect2(_ox + h.x * _cell - 2, _oy + h.y * _cell - 2,
			_cell + 4, _cell + 4), Color(0.62, 0.42, 0.24))
		# 글씨는 아래쪽에 — 위에 두면 「농장」·「축사」 라벨과 겹쳐 읽을 수 없다
		_label(Vector2(_ox + h.x * _cell, _oy + h.y * _cell + _cell + 20), "말")
	_place_label(74, 13, "중앙 광장")
	_place_label(46, 31, "호수 낚시터")
	_place_label(50, 1, "동굴")
	# 지어진 마을 건물만 이름을 보여준다 (빈 부지는 표시하지 않는다)
	for pid: String in GameData.village_built:
		if not main.VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = main.VILLAGE_PLOTS[pid].anchor
		_place_label(a.x, a.y, str(main.VILLAGE_PLOTS[pid].name))

	# 옛 마을 확장 구역 (메인 스토리 4) — 표지판을 본 뒤부터 지도에 나타난다.
	# 잠긴 구역은 빗금 테두리 + 이름, 열린 구역은 이름만 남긴다.
	if GameData.story4_phase != "":
		for zid: String in GameData.ZONE_ORDER:
			var zr: Rect2i = GameData.VILLAGE_ZONES[zid].rect
			var pr := Rect2(_ox + zr.position.x * _cell, _oy + zr.position.y * _cell,
				zr.size.x * _cell, zr.size.y * _cell)
			var locked: bool = zid not in GameData.zones_open
			if locked:
				canvas.draw_rect(pr, Color(0.5, 0.15, 0.12, 0.28))
			canvas.draw_rect(pr, Color(0.9, 0.55, 0.3, 0.8) if locked
				else Color(0.55, 0.8, 0.45, 0.6), false, 2.0)
			_label(Vector2(pr.get_center().x - 40.0, pr.get_center().y),
				str(GameData.VILLAGE_ZONES[zid].name) + (" (잠김)" if locked else ""))

	# 건설 후보지 — 지금 세울 수 있는 건물 터를 먼저 찍는다 (퀘스트 마커 아래)
	for g: Dictionary in build_spots():
		_draw_guide(g)
	# 퀘스트 길라잡이 — 지금 따라가는 목표가 어디인지 하트로 찍어 준다
	for g: Dictionary in _quest_guides():
		_draw_guide(g)

	# 내 위치: 눈에 잘 띄는 마커 (고리 + 깜빡이는 점 + 라벨)
	var pp := Vector2(_ox + main.player.position.x / 32.0 * _cell,
		_oy + main.player.position.y / 32.0 * _cell)
	var pulse := 4.0 + sin(blink * 5.0) * 1.5
	canvas.draw_arc(pp + Vector2(0.5, 0.5), pulse + 3.0, 0, TAU, 20, Color(1, 0.85, 0.3, 0.9), 2.0)
	canvas.draw_rect(Rect2(pp.x - 3, pp.y - 3, 7, 7), Color(1, 1, 1))
	canvas.draw_rect(Rect2(pp.x - 2, pp.y - 2, 5, 5), Color(0.95, 0.3, 0.25))
	_label(Vector2(pp.x, pp.y - 10), "내 위치")

	# 안내
	var guide := "휠: 확대·축소 · 끌기: 이동 · R: 처음 크기 · M/ESC: 닫기 (배율 %.1fx)" % zoom
	var w: float = main.UI_FONT.get_string_size(guide, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	canvas.draw_string(main.UI_FONT, Vector2(480 - w / 2.0, 526), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.68, 0.8))


# ---- 퀘스트 길라잡이 ----
#
# 「어디로 가야 하지?」를 글로 설명하는 대신 지도에 찍어 준다.
# 지금 따라가는 퀘스트(트래커에 뜬 것) 하나만 짚는다 — 화면이 마커로
# 뒤덮이면 오히려 어디가 어딘지 모르게 되므로.
#   ① 그 퀘스트의 담당 NPC가 마을에 나와 있으면 그 사람 자리
#   ② 아니면 이야기 단계마다 정해 둔 장소 (아래 표)
func _quest_guides() -> Array:
	var q: Dictionary = GameData.tracked_quest()
	if q.is_empty():
		return []
	var out: Array = []
	var title := str(q.get("title", "목표"))
	var spot := _quest_spot(str(q.get("id", "")))
	if spot.x >= 0:
		out.append({"tile": spot, "text": title})
		return out
	# 담당하는 사람이 있으면 그 사람이 곧 목적지다
	var nid := str(q.get("npc", ""))
	if nid != "":
		for n in main.npcs:
			if n.id == nid and n.visible:
				out.append({"tile": Vector2i(int(n.position.x / main.TILE),
					int(n.position.y / main.TILE)), "text": title})
				break
	return out


# 이야기 단계별 목적지 — 사람이 아니라 「장소」로 가야 하는 것들
func _quest_spot(qid: String) -> Vector2i:
	match qid:
		"story10", "story11":
			if GameData.story11_phase == "deep" or GameData.story10_phase == "dig":
				return main.CAVE_POS
		"story13":
			if GameData.story13_phase in ["rock", "fish"]:
				return main.BRACELET_ROCK
		"story15":
			if GameData.story15_phase == "dig":
				return main.CAVE_POS
			if GameData.story15_phase == "water":
				return main.ONSEN_POS
		"story16":
			if GameData.story16_phase == "clear":
				return main.OLD_FARM.position + Vector2i(5, 3)
		"story17":
			if GameData.story17_phase == "barn":
				return main.OLD_BARN
		"story18":
			if GameData.story18_phase in ["hill", "box"]:
				return main.HILL_POS
		"story20":
			if GameData.story20_phase in ["gate", "inner"]:
				return main.GATE_POS
			if GameData.story20_phase == "plant":
				return main.HOME_ANCHOR + Vector2i(2, 5)
		"fisher_home":
			if GameData.fisher_home in ["wait", "built"]:
				return Vector2i(main.FOUNTAIN.position.x + 1, main.FOUNTAIN.end.y + 1)
		"kitchen":
			if GameData.kitchen_quest in ["sweep", "jam"]:
				return main.HOME_ANCHOR + Vector2i(2, 3)
			if GameData.kitchen_quest in ["broom", "make"] \
					and GameData.village_built.has("general"):
				return main.VILLAGE_PLOTS["general"].anchor + Vector2i(2, 3)
		"tutorial":
			if GameData.tutorial_current_flag() == "cook":
				return main.HOME_ANCHOR + Vector2i(2, 3)
	return Vector2i(-1, -1)


# 지금 세울 수 있는 건물 터 — 「어디에 지어야 하지?」를 지도가 대신 말한다.
#
# 첫 상점(잡화점)이 대표다. 이야기가 상점을 지으라고 할 때, 그 터가
# 지도 어디쯤인지 몰라 마을을 헤매는 일이 없도록 집 모양 마커를 찍는다.
# 이미 세운 터는 찍지 않는다.
func build_spots() -> Array:
	var out: Array = []
	if GameData.story_phase != "done":
		return out           # 마을에 닿기 전에는 아무것도 안 찍는다
	# ① 첫 상점 — 이야기가 짓자고 하는 동안 계속 반짝인다
	if not GameData.village_built.has("general"):
		out.append({"tile": _plot_center("general"), "kind": "build",
			"text": "여기에 첫 상점을"})
	# ② 그다음 지을 수 있게 열린 건물 터 (이장과 이야기해 열린 것만)
	var nxt: String = main.village._next_village_build()
	if nxt != "" and nxt != "general":
		out.append({"tile": _plot_center(nxt), "kind": "build",
			"text": "%s를 세울 자리" % str(main.VILLAGE_PLOTS[nxt].name)})
	return out


func _plot_center(pid: String) -> Vector2i:
	var a: Vector2i = main.VILLAGE_PLOTS[pid].anchor
	return a + Vector2i(2, 2)      # 건물 그림(5x4) 한가운데


# 하트(퀘스트) 또는 집(건설 터) + 두근거리는 고리 — 멀리서도 눈에 띄게
func _draw_guide(g: Dictionary) -> void:
	var t: Vector2i = g.tile
	var c := Vector2(_ox + (float(t.x) + 0.5) * _cell, _oy + (float(t.y) + 0.5) * _cell)
	if c.x < -40.0 or c.x > 1000.0 or c.y < -40.0 or c.y > 560.0:
		return
	var beat := 1.0 + sin(blink * 4.0) * 0.12
	var build := str(g.get("kind", "quest")) == "build"
	var tint := Color(1.0, 0.78, 0.35) if build else Color(1.0, 0.42, 0.55)
	var ring := Color(1.0, 0.85, 0.5) if build else Color(1.0, 0.55, 0.66)
	# 퍼지는 고리 두 겹
	canvas.draw_arc(c, 13.0 * beat, 0, TAU, 24, Color(ring, 0.85), 2.5)
	canvas.draw_arc(c, 19.0 * beat, 0, TAU, 24, Color(ring, 0.35), 2.0)
	var s := 5.0 * beat
	if build:
		# 집 — 네모 몸통 + 삼각 지붕 (여기에 「짓는다」는 뜻)
		canvas.draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.1,
			s * 1.6, s * 1.2), tint)
		canvas.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-s * 1.15, -s * 0.1), c + Vector2(s * 1.15, -s * 0.1),
			c + Vector2(0.0, -s * 1.25)]), tint)
	else:
		# 하트 (두 개의 둥근 봉우리 + 아래로 모이는 삼각형)
		canvas.draw_circle(c + Vector2(-s * 0.5, -s * 0.35), s * 0.62, tint)
		canvas.draw_circle(c + Vector2(s * 0.5, -s * 0.35), s * 0.62, tint)
		canvas.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-s * 1.05, -s * 0.15), c + Vector2(s * 1.05, -s * 0.15),
			c + Vector2(0.0, s * 1.15)]), tint)
	_label(Vector2(c.x, c.y + 24.0), ("◈ " if build else "◆ ") + str(g.text))


func _dot(world_pos: Vector2, size: float, col: Color) -> void:
	canvas.draw_rect(Rect2(_ox + world_pos.x / 32.0 * _cell - size / 2.0,
		_oy + world_pos.y / 32.0 * _cell - size / 2.0, size, size), col)


func _place_label(tx: int, ty: int, text: String) -> void:
	if _visible_tile(tx, ty):
		_label(Vector2(_ox + tx * _cell, _oy + ty * _cell - 2), text)


func _label(pos: Vector2, text: String) -> void:
	# 화면 밖 라벨은 그리지 않는다 (확대했을 때 글자가 가장자리에 몰리지 않게)
	if pos.x < -60.0 or pos.x > 1020.0 or pos.y < 0.0 or pos.y > 520.0:
		return
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var p := Vector2(pos.x - w / 2.0, pos.y)
	canvas.draw_string_outline(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3,
		Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.92, 0.7))
