# 낚시 미니게임: 움직이는 커서를 초록 구간에서 멈춘다.
#
# 예전에는 한 번 맞히면 끝이라, 붕어든 황금잉어든 손맛이 같았다.
# 지금은 물고기마다 **맞혀야 하는 횟수 · 구간 너비 · 커서 속도**가 다르고,
# 한 번은 놓쳐도 만회할 수 있다 (두 번 놓치면 도망간다).
extends CanvasLayer

signal finished(success: bool)

const BAR_W := 300.0
const CURSOR_SPEED := 360.0
const MAX_MISS := 1          # 허용되는 실수 (이 이상이면 도망)
const ZONE_SHRINK := 0.82    # 단계가 오를수록 구간이 좁아진다
const SPEED_UP := 1.15       # 그리고 커서가 빨라진다

var zone_x := 0.0
var zone_w := 60.0
var t := 0.0
var bar: Control
var title: Label
var sub: Label

var stages_total := 1
var stage := 0
var misses := 0
var speed := CURSOR_SPEED
var hint := ""


func _ready() -> void:
	layer = 25
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(315, 210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("ffd75e"))
	v.add_child(title)

	bar = Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 36)
	bar.draw.connect(_draw_bar)
	v.add_child(bar)

	sub = Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.72, 0.68, 0.85))
	v.add_child(sub)


# fish = GameData.FISH의 한 줄. zone_width는 호감도 보정이 들어간 값이다.
func start(zone_width: float, stages: int = 1, speed_mult: float = 1.0,
		fish_hint: String = "") -> void:
	zone_w = zone_width
	stages_total = maxi(1, stages)
	stage = 0
	misses = 0
	speed = CURSOR_SPEED * speed_mult
	hint = fish_hint
	_next_stage(false)
	visible = true


func _next_stage(shrink: bool) -> void:
	if shrink:
		zone_w = maxf(18.0, zone_w * ZONE_SHRINK)
		speed *= SPEED_UP
	zone_x = randf_range(4.0, maxf(5.0, BAR_W - zone_w - 4.0))
	t = randf() * 10.0
	_refresh_text()


func _refresh_text() -> void:
	var pips := ""
	for i in stages_total:
		pips += "●" if i < stage else "○"
	title.text = "%s  %s" % [hint, pips] if hint != "" else pips
	var left := MAX_MISS - misses
	sub.text = "초록 구간에서 %s!   (기회 %d번 남음)" % [
		GameData.key_label("use_tool"), left + 1]


func _process(delta: float) -> void:
	if visible:
		t += delta
		bar.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("use_tool"):
		get_viewport().set_input_as_handled()
		_try_hook()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		visible = false
		finished.emit(false)


func _try_hook() -> void:
	var c := _cursor_x()
	if c >= zone_x and c <= zone_x + zone_w:
		stage += 1
		if stage >= stages_total:
			visible = false
			finished.emit(true)
			return
		Sound.play_sfx("sfx_bite")
		_next_stage(true)          # 아직 남았다 — 더 좁고 더 빠르게
	else:
		misses += 1
		if misses > MAX_MISS:
			visible = false
			finished.emit(false)
			return
		Sound.play_sfx("sfx_miss")
		_next_stage(false)         # 한 번은 봐준다


func _cursor_x() -> float:
	return pingpong(t * speed, BAR_W)


func _draw_bar() -> void:
	bar.draw_rect(Rect2(0, 0, BAR_W, 36), Color(0.09, 0.07, 0.13))
	bar.draw_rect(Rect2(zone_x, 3, zone_w, 30), Color(0.32, 0.72, 0.36))
	# 구간 한가운데 (딱 맞히면 기분이 좋으라고)
	bar.draw_rect(Rect2(zone_x + zone_w / 2.0 - 0.5, 3, 1, 30), Color(0.5, 0.9, 0.55))
	bar.draw_rect(Rect2(_cursor_x() - 1.5, 0, 3, 36), Color(1, 1, 1))
