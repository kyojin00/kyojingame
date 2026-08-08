# 지도 (M): 실제로 가 본 지역만 보여준다 (fog of war).
# 미탐사/미해금 지역은 검은색으로 가려지고, 탐사할수록 하나씩 공개된다.
extends CanvasLayer

const CELL := 8.0  # 타일당 픽셀 (90x60 맵, 화면 960x540)
const FOG := Color(0.02, 0.02, 0.035)

var main: Node2D
var canvas: Control
var blink := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.1, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_map)
	add_child(canvas)


func open() -> void:
	visible = true
	canvas.queue_redraw()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


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
	var ox: float = (960.0 - main.MAP_W * CELL) / 2.0
	var oy: float = (540.0 - main.MAP_H * CELL) / 2.0 + 2.0

	# 지형 (미탐사/미해금은 검은색)
	for y in main.MAP_H:
		for x in main.MAP_W:
			if not _visible_tile(x, y):
				canvas.draw_rect(Rect2(ox + x * CELL, oy + y * CELL, CELL, CELL), FOG)
				continue
			var cell: Dictionary = main.grid[y][x]
			var c: Color
			if cell.ground == "water":
				c = Color(0.26, 0.45, 0.68)
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
			canvas.draw_rect(Rect2(ox + x * CELL, oy + y * CELL, CELL, CELL), c)

	# 오브젝트 (보이는 지역만)
	for pos: Vector2i in main.objects:
		if not _visible_tile(pos.x, pos.y):
			continue
		var kind: String = main.objects[pos].kind
		var c: Color
		match kind:
			"tree":
				c = Color(0.15, 0.35, 0.14)
			"rock":
				c = Color(0.55, 0.55, 0.6)
			"house":
				c = Color(0.62, 0.28, 0.2)
			"bin":
				c = Color(0.85, 0.6, 0.25)
			"board":
				c = Color(0.95, 0.8, 0.35)
			_:
				c = Color(0.5, 0.4, 0.3)
		canvas.draw_rect(Rect2(ox + pos.x * CELL, oy + pos.y * CELL, CELL, CELL), c)

	# 동물/NPC (보이는 지역만)
	for a in main.animals:
		if _visible_tile(int(a.position.x / 32.0), int(a.position.y / 32.0)):
			canvas.draw_rect(Rect2(ox + a.position.x / 32.0 * CELL - 1,
				oy + a.position.y / 32.0 * CELL - 1, 3, 3), Color(0.95, 0.95, 0.9))
	for n in main.npcs:
		if n.visible and _visible_tile(int(n.position.x / 32.0), int(n.position.y / 32.0)):
			canvas.draw_rect(Rect2(ox + n.position.x / 32.0 * CELL - 1,
				oy + n.position.y / 32.0 * CELL - 1, 3, 3), Color(0.95, 0.55, 0.75))

	# 시설 라벨 (그 위치를 발견했을 때만)
	_place_label(63, 3, "우리집", ox, oy)
	_place_label(74, 13, "중앙 광장", ox, oy)
	_place_label(74, 26, "낚시터", ox, oy)
	_place_label(40, 27, "호수", ox, oy)
	_place_label(50, 1, "동굴", ox, oy)
	# 지어진 마을 건물만 이름을 보여준다 (빈 부지는 표시하지 않는다)
	for pid: String in GameData.village_built:
		if not main.VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = main.VILLAGE_PLOTS[pid].anchor
		_place_label(a.x, a.y, str(main.VILLAGE_PLOTS[pid].name), ox, oy)

	# 내 위치: 눈에 잘 띄는 마커 (고리 + 깜빡이는 점 + 라벨)
	var pp := Vector2(ox + main.player.position.x / 32.0 * CELL,
		oy + main.player.position.y / 32.0 * CELL)
	var pulse := 4.0 + sin(blink * 5.0) * 1.5
	canvas.draw_arc(pp + Vector2(0.5, 0.5), pulse + 3.0, 0, TAU, 20, Color(1, 0.85, 0.3, 0.9), 2.0)
	canvas.draw_rect(Rect2(pp.x - 3, pp.y - 3, 7, 7), Color(1, 1, 1))
	canvas.draw_rect(Rect2(pp.x - 2, pp.y - 2, 5, 5), Color(0.95, 0.3, 0.25))
	_label(Vector2(pp.x, pp.y - 10), "내 위치")

	# 안내
	var guide := "M 또는 ESC: 닫기 · 가 본 곳만 표시된다"
	var w: float = main.UI_FONT.get_string_size(guide, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	canvas.draw_string(main.UI_FONT, Vector2(480 - w / 2.0, 526), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.68, 0.8))


func _place_label(tx: int, ty: int, text: String, ox: float, oy: float) -> void:
	if _visible_tile(tx, ty):
		_label(Vector2(ox + tx * CELL, oy + ty * CELL - 2), text)


func _label(pos: Vector2, text: String) -> void:
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var p := Vector2(pos.x - w / 2.0, pos.y)
	canvas.draw_string_outline(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3,
		Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.92, 0.7))
