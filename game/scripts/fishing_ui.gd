# 낚시 미니게임: 움직이는 커서를 초록 구간에서 멈추면 성공.
extends CanvasLayer

signal finished(success: bool)

const BAR_W := 300.0
const CURSOR_SPEED := 360.0

var zone_x := 0.0
var zone_w := 60.0
var t := 0.0
var bar: Control


func _ready() -> void:
	layer = 25
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(315, 225)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var label := Label.new()
	label.text = "초록 구간에서 Space!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(label)

	bar = Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 36)
	bar.draw.connect(_draw_bar)
	v.add_child(bar)


func start(zone_width: float) -> void:
	zone_w = zone_width
	zone_x = randf_range(4.0, BAR_W - zone_w - 4.0)
	t = randf() * 10.0
	visible = true


func _process(delta: float) -> void:
	if visible:
		t += delta
		bar.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("use_tool"):
		get_viewport().set_input_as_handled()
		var c := _cursor_x()
		visible = false
		finished.emit(c >= zone_x and c <= zone_x + zone_w)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		visible = false
		finished.emit(false)


func _cursor_x() -> float:
	return pingpong(t * CURSOR_SPEED, BAR_W)


func _draw_bar() -> void:
	bar.draw_rect(Rect2(0, 0, BAR_W, 36), Color(0.09, 0.07, 0.13))
	bar.draw_rect(Rect2(zone_x, 3, zone_w, 30), Color(0.32, 0.72, 0.36))
	bar.draw_rect(Rect2(_cursor_x() - 1.5, 0, 3, 36), Color(1, 1, 1))
