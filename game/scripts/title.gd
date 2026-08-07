# 타이틀 화면: 이어하기 / 새로 시작 / 설정 / 종료
extends Control

var settings_panel: PanelContainer
var _shot_frames := 0


func _ready() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.23, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 배경 장식: 도트 스프라이트 몇 개
	var deco := Node2D.new()
	deco.position = Vector2(0, 0)
	add_child(deco)
	var deco_items := [
		["tree_spring", Vector2(30, 210), 2.5], ["tree_spring", Vector2(410, 190), 2.5],
		["house", Vector2(24, 26), 1.4], ["mature_pumpkin", Vector2(100, 268), 2.0],
		["mature_strawberry", Vector2(150, 272), 2.0], ["chicken_0", Vector2(300, 274), 2.0],
		["cow_0", Vector2(350, 268), 2.0],
	]
	for item in deco_items:
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/%s.png" % item[0])
		s.centered = false
		s.position = item[1]
		s.scale = Vector2(item[2], item[2])
		s.modulate = Color(1, 1, 1, 0.85)
		deco.add_child(s)

	# 타이틀
	var title := Label.new()
	title.text = "교 진 팜"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(110, 56)
	title.size = Vector2(260, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "- 도트 농장 시뮬레이션 -"
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	subtitle.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	subtitle.add_theme_constant_override("outline_size", 3)
	subtitle.position = Vector2(120, 100)
	subtitle.size = Vector2(240, 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	# 메뉴 버튼
	var v := VBoxContainer.new()
	v.position = Vector2(170, 140)
	v.custom_minimum_size = Vector2(140, 0)
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var has_save := FileAccess.file_exists(GameData.SAVE_PATH)
	var continue_btn := _mk_button("이어하기", _on_continue)
	continue_btn.disabled = not has_save
	v.add_child(continue_btn)
	v.add_child(_mk_button("새로 시작", _on_new_game))
	v.add_child(_mk_button("설정", _on_settings))
	v.add_child(_mk_button("종료", func() -> void: get_tree().quit()))

	_build_settings_panel()
	Sound.play_bgm("spring")


func _mk_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		cb.call())
	return b


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_new_game() -> void:
	if FileAccess.file_exists(GameData.SAVE_PATH):
		DirAccess.remove_absolute(GameData.SAVE_PATH)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_settings() -> void:
	settings_panel.visible = not settings_panel.visible


func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.position = Vector2(120, 90)
	settings_panel.custom_minimum_size = Vector2(240, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.97)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	settings_panel.add_theme_stylebox_override("panel", style)
	add_child(settings_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	settings_panel.add_child(v)

	v.add_child(_mk_slider("마스터", Sound.master_volume,
		func(val: float) -> void: Sound.master_volume = val))
	v.add_child(_mk_slider("배경음악", Sound.bgm_volume,
		func(val: float) -> void: Sound.bgm_volume = val))
	v.add_child(_mk_slider("효과음", Sound.sfx_volume,
		func(val: float) -> void: Sound.sfx_volume = val))

	var fs := CheckBox.new()
	fs.text = "전체화면"
	fs.focus_mode = Control.FOCUS_NONE
	fs.button_pressed = Sound.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		Sound.fullscreen = on
		Sound.apply_settings()
		Sound.save_settings())
	v.add_child(fs)

	var close_btn := _mk_button("닫기", func() -> void: settings_panel.visible = false)
	v.add_child(close_btn)


func _mk_slider(label_text: String, value: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = value
	s.custom_minimum_size = Vector2(120, 16)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(val: float) -> void:
		setter.call(val)
		Sound.apply_settings()
		Sound.save_settings())
	row.add_child(s)
	return row


func _process(_delta: float) -> void:
	# 개발/CI용 스크린샷
	if OS.get_environment("KYOJIN_SHOT") == "":
		return
	_shot_frames += 1
	if _shot_frames == 30:
		var img := get_viewport().get_texture().get_image()
		img.save_png(OS.get_environment("KYOJIN_SHOT") + "_title.png")
	elif _shot_frames == 40:
		_on_new_game()
