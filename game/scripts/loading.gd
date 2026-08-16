# 세계를 짓는 동안 보여 주는 화면.
#
# 「새로 시작」을 누르면 장면이 바뀌고 main._ready() 가 지도 사만 칸을 짓는다.
# 그동안 화면은 **마지막에 그린 그림 그대로 멈춰 있다** — 창이 응답을 안 하는
# 것처럼 보여서, 껐다 켜는 사람이 생긴다.
#
# 두 가지를 한다.
#   ① 장면을 바꾸기 **전에** 이 화면을 띄우고 한 프레임 그리게 한다.
#      그래야 멈춰 있는 동안 보이는 그림이 「짓는 중」이다
#   ② 짓는 도중 단계마다 step() 을 부르면 RenderingServer.force_draw() 로
#      그 자리에서 다시 그린다. 장면 트리를 재우지 않으므로(await 가 아니다)
#      절반만 지어진 세계에 다른 노드가 끼어들 일이 없다
#
# 이 노드는 **장면 밖(root)** 에 붙는다. 장면이 통째로 갈릴 때 같이 지워지면
# 정작 필요한 순간에 사라지기 때문이다.
extends CanvasLayer

const NODE_NAME := "KyojinLoading"
const FONT := preload("res://assets/fonts/Galmuri9.ttf")

const COL_BACK := Color(0.16, 0.12, 0.09)          # 밤빛 배경
const COL_CREAM := Color(0.97, 0.93, 0.83)
const COL_WOOD := Color(0.62, 0.44, 0.26)
const COL_WOOD_DK := Color(0.45, 0.3, 0.16)
const COL_INK := Color(0.32, 0.2, 0.1)
const COL_LEAF := Color(0.45, 0.62, 0.32)
const COL_LEAF_DK := Color(0.30, 0.44, 0.21)

const BOX_W := 440.0
const BOX_H := 150.0

var _c: Control
var _msg := "마을을 짓는 중…"
var _ratio := 0.0
var _t := 0.0


# 이미 떠 있으면 그것을 쓰고, 없으면 만들어 붙인다
static func open(tree: SceneTree) -> Node:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	if n == null:
		n = (load("res://scripts/loading.gd") as GDScript).new()
		n.name = NODE_NAME
		tree.root.add_child(n)
	n.visible = true
	return n


static func close(tree: SceneTree) -> void:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	if n != null:
		n.queue_free()


# 어디서든 한 줄로: KyojinLoadingHelper 없이 쓰라고 static 으로 둔다
static func mark(tree: SceneTree, text: String, ratio: float) -> void:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	if n != null:
		n.step(text, ratio)


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 버튼이 눌리지 않게
	_c.draw.connect(_draw_screen)
	add_child(_c)


func step(text: String, ratio: float) -> void:
	if text != "":
		_msg = text
	_ratio = clampf(ratio, 0.0, 1.0)
	_t += 0.35                       # 멈춰 있는 동안에도 새싹이 자라 보이게
	if _c != null:
		_c.queue_redraw()
	# **그 자리에서 다시 그린다.** await 를 쓰면 장면 트리가 한 바퀴 돌아,
	# 아직 절반만 지어진 세계에서 남의 _process 가 먼저 깨어난다
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()


func _process(delta: float) -> void:
	_t += delta
	if _c != null:
		_c.queue_redraw()


func _draw_screen() -> void:
	var sz: Vector2 = _c.size
	_c.draw_rect(Rect2(Vector2.ZERO, sz), COL_BACK)
	# 배경에 옅은 밭이랑 — 빈 검정 화면보다 훨씬 덜 불안하다
	for i in range(0, int(sz.y / 26.0) + 1):
		var y := float(i) * 26.0 + fmod(_t * 6.0, 26.0)
		_c.draw_rect(Rect2(0, y, sz.x, 2), Color(1, 1, 1, 0.020))

	var box := Rect2(sz.x * 0.5 - BOX_W * 0.5, sz.y * 0.5 - BOX_H * 0.5, BOX_W, BOX_H)
	_c.draw_rect(box.grow(4.0), COL_WOOD_DK)
	_c.draw_rect(box.grow(1.0), COL_WOOD)
	_c.draw_rect(box, COL_CREAM)
	# 귀퉁이 스티치 — 대화창과 같은 톤으로 묶는다
	for c: Vector2 in [Vector2(5, 5), Vector2(BOX_W - 8, 5),
			Vector2(5, BOX_H - 8), Vector2(BOX_W - 8, BOX_H - 8)]:
		_c.draw_rect(Rect2(box.position + c, Vector2(3, 3)), COL_WOOD)

	# ---- 자라는 새싹 ----
	#
	# 도는 고리 하나만 두면 「멈췄나」 싶을 때 판단할 근거가 없다.
	# 진행에 맞춰 **한 뼘씩 자라는** 것이 있어야 나아가고 있음이 읽힌다
	var gx := box.position.x + 40.0
	var gy := box.position.y + BOX_H - 42.0
	var grow := 8.0 + _ratio * 26.0
	_c.draw_rect(Rect2(gx - 6, gy + 2, 12, 3), COL_WOOD_DK)          # 흙
	_c.draw_rect(Rect2(gx - 1, gy - grow, 2, grow), COL_LEAF_DK)     # 줄기
	var leaves := int(_ratio * 3.0) + 1
	for i in leaves:
		var ly := gy - grow + 4.0 + float(i) * 8.0
		var side := 1.0 if i % 2 == 0 else -1.0
		var sway := sin(_t * 2.2 + float(i)) * 1.5
		_c.draw_rect(Rect2(gx + (1.0 * side if side > 0 else -7.0),
			ly + sway, 6, 4), COL_LEAF)
		_c.draw_rect(Rect2(gx + (1.0 * side if side > 0 else -5.0),
			ly + sway - 1.0, 4, 2), COL_LEAF.lightened(0.18))

	# ---- 글 ----
	var tx := box.position.x + 78.0
	_c.draw_string(FONT, Vector2(tx, box.position.y + 42.0),
		"마을을 짓는 중", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, COL_INK)
	# 점 셋이 하나씩 켜진다 — 이게 「살아 있음」을 말한다
	var dots := int(fmod(_t * 2.6, 4.0))
	var dw: float = FONT.get_string_size("마을을 짓는 중", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 19).x
	for i in 3:
		if i < dots:
			_c.draw_rect(Rect2(tx + dw + 4.0 + float(i) * 7.0,
				box.position.y + 36.0, 4, 4), COL_INK)
	_c.draw_string(FONT, Vector2(tx, box.position.y + 68.0),
		_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_WOOD_DK)

	# ---- 진행 막대 ---- (도트에 맞춰 칸으로 채운다)
	var bar := Rect2(tx, box.position.y + BOX_H - 46.0, BOX_W - 118.0, 12.0)
	_c.draw_rect(bar.grow(2.0), COL_WOOD_DK)
	_c.draw_rect(bar, Color(0.87, 0.81, 0.70))
	var cells := int(bar.size.x / 8.0)
	var lit := int(round(float(cells) * _ratio))
	for i in lit:
		_c.draw_rect(Rect2(bar.position.x + float(i) * 8.0 + 1.0,
			bar.position.y + 1.0, 6.0, bar.size.y - 2.0), COL_LEAF)
	_c.draw_string(FONT, Vector2(bar.position.x + bar.size.x + 10.0,
		bar.position.y + 11.0), "%d%%" % int(_ratio * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_WOOD_DK)
