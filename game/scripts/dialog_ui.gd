# 범용 대화/퀘스트 패널: 제목 + 본문 + 동적 버튼들
extends CanvasLayer

var title_label: Label
var body_label: Label
var buttons_box: HBoxContainer


func _ready() -> void:
	layer = 25
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(60, 90)
	panel.custom_minimum_size = Vector2(360, 140)
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

	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color("ffd75e"))
	v.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(340, 60)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body_label)

	buttons_box = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 8)
	buttons_box.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(buttons_box)


# buttons: [[라벨, Callable], ...] — 콜백이 null이면 닫기 동작
func open(title_text: String, body_text: String, buttons: Array) -> void:
	title_label.text = title_text
	body_label.text = body_text
	for c in buttons_box.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		if b[1] != null:
			btn.pressed.connect(b[1])
		else:
			btn.pressed.connect(close)
		buttons_box.add_child(btn)
	visible = true


func set_body(text: String) -> void:
	body_label.text = text


func close() -> void:
	visible = false
