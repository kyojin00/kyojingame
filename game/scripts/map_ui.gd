# 지도 (M): 실제로 가 본 지역만 보여준다 (fog of war).
# 미탐사/미해금 지역은 검은색으로 가려지고, 탐사할수록 하나씩 공개된다.
#
# 조작: 마우스 휠 = 확대/축소 (커서 기준) · 끌기 = 이동 · R = 처음 크기로
extends CanvasLayer

const CELL := 8.0  # 배율 1일 때 타일당 픽셀 (90x60 맵, 화면 960x540)
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

# 이번 프레임의 그리기 기준 (셀 크기 / 원점) — 그릴 때 한 번 계산해 둔다
var _cell := CELL
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
	visible = true
	reset_view()
	canvas.queue_redraw()


func close() -> void:
	visible = false
	_drag = false


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
	var c0 := CELL * zoom
	var t := (m - _origin(c0)) / c0            # 커서가 가리키는 타일 좌표
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var c1 := CELL * zoom
	pan = m - t * c1 - Vector2((960.0 - main.MAP_W * c1) / 2.0,
		(540.0 - main.MAP_H * c1) / 2.0 + 2.0)
	_clamp_pan()


# 지도가 화면 밖으로 완전히 사라지지 않게 한다
func _clamp_pan() -> void:
	var c := CELL * zoom
	var half_w: float = int(main.MAP_W) * c / 2.0
	var half_h: float = int(main.MAP_H) * c / 2.0
	pan.x = clampf(pan.x, -half_w, half_w)
	pan.y = clampf(pan.y, -half_h, half_h)


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
		pan += (event as InputEventMouseMotion).relative
		_clamp_pan()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_R:
		reset_view()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		blink += delta
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
	_cell = CELL * zoom
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
			"bin":
				c = Color(0.85, 0.6, 0.25)
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
	_place_label(63, 3, "우리집")
	_place_label(74, 13, "중앙 광장")
	_place_label(74, 30, "낚시터")
	_place_label(40, 27, "호수")
	_place_label(50, 1, "동굴")
	# 지어진 마을 건물만 이름을 보여준다 (빈 부지는 표시하지 않는다)
	for pid: String in GameData.village_built:
		if not main.VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = main.VILLAGE_PLOTS[pid].anchor
		_place_label(a.x, a.y, str(main.VILLAGE_PLOTS[pid].name))

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
