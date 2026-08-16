# 세계를 짓는 동안 보여 주는 화면.
#
# 「새로 시작」을 누르면 장면이 바뀌고 main._ready() 가 지도 사만 칸을 짓는다.
# 그동안 화면은 **마지막에 그린 그림 그대로 멈춰 있다** — 창이 응답을 안 하는
# 것처럼 보여서, 껐다 켜는 사람이 생긴다.
#
# 두 가지를 한다.
#   ① 장면을 바꾸기 **전에** 이 화면을 띄우고 한 프레임 그리게 한다.
#      그래야 멈춰 있는 동안 보이는 그림이 「짓는 중」이다
#   ② 짓는 도중 단계마다 breathe() 를 await 하면 **진짜 프레임이 한동안 돈다.**
#      그동안 트리는 멈춰 있고(paused) 세계는 감춰져 있어(main.visible=false),
#      절반만 지어진 세계가 보이거나 남의 _process 가 끼어들 일이 없다
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

# ---- 막대는 **차오른다** ----
#
# 단계마다 값을 그대로 꽂았더니 0 -> 100 이 한 번에 튀었다. 눈에는
# 「채워지는 것」이 아니라 「갑자기 다 됐다」로 보인다.
#
# 그래서 목표(_target)와 **보이는 값**(_ratio)을 따로 둔다. 보이는 값은
# 정해진 속도로만 목표를 쫓아간다. 세계를 짓는 동안에는 프레임이 안 도니까
# step() 안에서 몇 장을 직접 그려 그 사이를 메우고, 다 지은 뒤에는
# _process 가 100까지 마저 채운다.
#
# 짓는 도중에는 BUILD_CAP 위로 안 올라간다 — 아직 할 일이 남았는데 막대가
# 꽉 차 있으면 그때부터는 멈춘 것으로 보인다.
const CLIMB := 0.62               # 초당 차오르는 양
const BUILD_CAP := 0.75           # 짓는 동안 보여 줄 수 있는 최대치
const WARMUP := 0.40              # 장면을 바꾸기 전에 미리 채워 두는 몫

var _c: Control
var _msg := "마을을 짓는 중…"
var _ratio := 0.0                 # 지금 화면에 보이는 값
var _target := 0.0                # 다다르려는 값
var _t := 0.0
var _hold := -1.0                 # 100% 를 채운 뒤 기다리는 시간 (음수면 아직)
var _held := 0.0
var _done := false                # 다 지었다 — 이제 100까지 채운다


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


# 어디서든 한 줄로: KyojinLoadingHelper 없이 쓰라고 static 으로 둔다.
# 값만 바꾼다 (그림은 다음 프레임에 따라온다)
static func mark(tree: SceneTree, text: String, ratio: float) -> void:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	if n != null:
		n.step(text, ratio)


# 값을 바꾸고 **막대가 거기까지 차오를 때까지 프레임을 흘려 보낸다.**
# 세계를 짓는 도중에 부르는 것은 이쪽이다 (await 로 부를 것).
# 로딩판이 이미 걷혔으면 아무 일도 없이 그 자리에서 돌아온다.
static func breathe(tree: SceneTree, text: String, ratio: float) -> void:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	if n == null:
		return
	await n.hold(text, ratio)


# 목표만 정한다 — 채우는 건 _process 가 **실제 프레임에서** 한다.
# 장면을 바꾸기 전(=아직 프레임이 도는 동안)에 미리 채워 두는 데 쓴다
static func climb(tree: SceneTree, text: String, ratio: float) -> void:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	if n != null:
		n.aim(text, ratio)


# 목표에 다다랐나 (타이틀이 이걸 보고 장면을 바꾼다)
static func reached(tree: SceneTree) -> bool:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	return n == null or n.is_at_target()


# 다 지었다 — 막대를 100까지 채우고, 다 찬 뒤 hold 초를 기다렸다가 걷는다.
# 기다리는 동안은 트리를 세운다: 화면은 아직 로딩판인데 뒤에서 사람이
# 걸어다니면 그건 로딩이 아니다
static func finish(tree: SceneTree, hold := 2.0) -> void:
	var n: Node = tree.root.get_node_or_null(NODE_NAME)
	if n == null:
		return
	n.done(hold)


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 버튼이 눌리지 않게
	_c.draw.connect(_draw_screen)
	add_child(_c)


func aim(text: String, ratio: float) -> void:
	if text != "":
		_msg = text
	_target = clampf(ratio, 0.0, 1.0)


func is_at_target() -> bool:
	return _ratio >= _target - 0.005


# 값만 바꾸고 그림은 다음 프레임에 맡긴다 (breathe 가 그 프레임을 벌어 준다)
func step(text: String, ratio: float) -> void:
	_msg = text if text != "" else _msg
	_target = clampf(ratio, 0.0, BUILD_CAP)
	if _c != null:
		_c.queue_redraw()


# ---- 막대가 **천천히 차오르는** 자리 ----
#
# 세계를 짓는 동안에는 프레임이 안 돈다. 오래도록 `RenderingServer.force_draw()`
# 로 그 자리에서 그려 보려 했는데, **그게 화면에 올라오지 않는 환경이 있다** —
# 값은 0.40 -> 0.75 로 멀쩡히 오르는데 사람 눈에는 39%에 굳어 있다가 다 지은
# 뒤에 튀는 것으로 보였다 (창이 「응답 없음」으로 굳어 마지막 화면만 남는다).
#
# 그래서 **진짜 프레임을 기다린다.** 목표에 다다를 때까지 process_frame 을
# 흘려 보내면, 막대는 _process 가 늘 하던 대로 CLIMB 속도로 차오른다.
# 그동안 트리는 멈춰 있고(main 이 paused 를 걸어 둔다) 세계는 감춰져 있어,
# 절반만 지어진 세계가 보이거나 남의 _process 가 끼어들 일은 없다.
#
# guard 는 만일의 무한 대기를 막는 빗장이다 — 프레임이 안 돌면 그냥 나간다.
func hold(text: String, ratio: float) -> void:
	step(text, ratio)
	if DisplayServer.get_name() == "headless":
		_ratio = maxf(_ratio, _target)
		return
	var guard := 0
	while _ratio < _target - 0.005 and guard < 180:
		guard += 1
		await get_tree().process_frame


# 세계를 다 지었다. 남은 만큼을 _process 가 채운다
func done(hold: float) -> void:
	_done = true
	_target = 1.0
	_hold = hold
	_msg = "마을이 다 지어졌다"
	get_tree().paused = true          # 뒤에서 게임이 먼저 굴러가지 않게


func _process(delta: float) -> void:
	_t += delta
	if _done:
		_ratio = move_toward(_ratio, 1.0, CLIMB * delta)
		if _ratio >= 1.0:
			_held += delta
			if _held >= _hold:
				get_tree().paused = false
				queue_free()
				return
	else:
		_ratio = move_toward(_ratio, _target, CLIMB * delta)
	if _c != null:
		_c.queue_redraw()


func _exit_tree() -> void:
	# 어떤 길로 지워지든 멈춰 둔 트리는 반드시 되돌린다
	var tr := get_tree()
	if tr != null:
		tr.paused = false


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
	var head_text := "마을이 다 지어졌다" if _ratio >= 1.0 else "마을을 짓는 중"
	_c.draw_string(FONT, Vector2(tx, box.position.y + 42.0),
		head_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, COL_INK)
	# 점 셋이 하나씩 켜진다 — 이게 「살아 있음」을 말한다
	var dots := int(fmod(_t * 2.6, 4.0))
	var dw: float = FONT.get_string_size(head_text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 19).x
	for i in 3:
		if i < dots and _ratio < 1.0:
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
