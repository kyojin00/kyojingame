# 범용 대화/퀘스트 패널: 제목 + 본문 + 동적 버튼들
extends CanvasLayer

var title_label: Label
var body_label: Label
var buttons_box: HBoxContainer
var portrait: TextureRect


func _ready() -> void:
	layer = 25
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(105, 190)
	panel.custom_minimum_size = Vector2(430, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.visible = false
	h.add_child(portrait)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)

	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color("ffd75e"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 초상화(64px)+여백을 빼고 화면 안에 들어오는 고정 폭
	body_label.custom_minimum_size = Vector2(310, 60)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body_label)

	buttons_box = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 8)
	buttons_box.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(buttons_box)


# buttons: [[라벨, Callable], ...] — 콜백이 null이면 닫기 동작
func open(title_text: String, body_text: String, buttons: Array,
		portrait_tex: Texture2D = null) -> void:
	title_label.text = title_text
	body_label.text = body_text
	portrait.texture = portrait_tex
	portrait.visible = portrait_tex != null
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


func set_portrait(tex: Texture2D) -> void:
	portrait.texture = tex
	portrait.visible = tex != null


func close() -> void:
	visible = false
