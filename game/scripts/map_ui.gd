# 지도 (M): 농장 전체를 축소해 보여주고 주요 시설과 내 위치를 표시한다.
extends CanvasLayer

const CELL := 8.0  # 타일당 픽셀 (90x60 맵, 화면 960x540)

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


func _draw_map() -> void:
	var ox: float = (960.0 - main.MAP_W * CELL) / 2.0
	var oy: float = (540.0 - main.MAP_H * CELL) / 2.0 + 2.0

	# 지형
	for y in main.MAP_H:
		for x in main.MAP_W:
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

	# 오브젝트
	for pos: Vector2i in main.objects:
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

	# 동물/NPC
	for a in main.animals:
		canvas.draw_rect(Rect2(ox + a.position.x / 32.0 * CELL - 1, oy + a.position.y / 32.0 * CELL - 1, 3, 3),
			Color(0.95, 0.95, 0.9))
	for n in main.npcs:
		canvas.draw_rect(Rect2(ox + n.position.x / 32.0 * CELL - 1, oy + n.position.y / 32.0 * CELL - 1, 3, 3),
			Color(0.95, 0.55, 0.75))

	# 내 위치 (깜빡임)
	if fmod(blink, 0.8) < 0.5:
		var pp := Vector2(ox + main.player.position.x / 32.0 * CELL, oy + main.player.position.y / 32.0 * CELL)
		canvas.draw_rect(Rect2(pp.x - 2, pp.y - 2, 5, 5), Color(1, 1, 1))
		canvas.draw_rect(Rect2(pp.x - 1, pp.y - 1, 3, 3), Color(0.95, 0.3, 0.25))

	# 미구매 부지 표시
	for pid in GameData.PARCELS:
		if GameData.owned_parcels.has(pid):
			continue
		var r: Array = GameData.PARCELS[pid].rect
		var rect := Rect2(ox + r[0] * CELL, oy + r[1] * CELL, r[2] * CELL, r[3] * CELL)
		canvas.draw_rect(rect, Color(0.05, 0.03, 0.1, 0.45))
		canvas.draw_rect(rect, Color(1, 0.85, 0.4, 0.8), false, 1.0)
		_label(rect.get_center() + Vector2(0, -6), GameData.PARCELS[pid].name)
		_label(rect.get_center() + Vector2(0, 10), "%dG" % GameData.PARCELS[pid].price)

	# 라벨
	_label(Vector2(ox + 4.0 * CELL, oy + 1.0 * CELL - 2), "우리집")
	_label(Vector2(ox + 74.0 * CELL, oy + 1.0 * CELL - 2), "마을")
	_label(Vector2(ox + 73.0 * CELL, oy + 15.0 * CELL - 4), "광장")
	_label(Vector2(ox + 25.0 * CELL, oy + 13.0 * CELL - 2), "연못")
	_label(Vector2(ox + 50.0 * CELL, oy + 1.0 * CELL - 2), "동굴")
	_label(Vector2(ox + main.player.position.x / 32.0 * CELL, oy + main.player.position.y / 32.0 * CELL - 8), "내 위치")

	# 안내
	var guide := "M 또는 ESC: 닫기"
	var w: float = main.UI_FONT.get_string_size(guide, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	canvas.draw_string(main.UI_FONT, Vector2(480 - w / 2.0, 526), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.68, 0.8))


func _label(pos: Vector2, text: String) -> void:
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var p := Vector2(pos.x - w / 2.0, pos.y)
	canvas.draw_string_outline(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3,
		Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.92, 0.7))
