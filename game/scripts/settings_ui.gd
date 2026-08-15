# 설정 창 — 인게임에서 ESC 메뉴로 연다.
#
# 예전에는 타이틀 화면에만 설정이 있어서, 소리 하나 줄이려 해도 농장을
# 나갔다 들어와야 했다. 여기 있는 것은 타이틀의 설정 패널과 같은 것들이다:
# 소리 세 가지 · 화면 크기 · 키 설정.
#
# 값은 누르는 즉시 Sound/GameData가 파일에 적어 둔다 (따로 「적용」이 없다).
extends CanvasLayer

var main: Node2D

var _panel: PanelContainer
var _win_btn: Button
var _key_buttons := {}       # 액션 -> Button
var _waiting_action := ""    # 지금 새 키를 기다리는 액션


func _ready() -> void:
	layer = 30
	visible = false

	# 뒤를 어둡게 — 창이 떠 있다는 걸 눈으로 알려 준다
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.position = Vector2(255, 24)
	_panel.custom_minimum_size = Vector2(450, 492)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.98)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)

	var title := Label.new()
	title.text = "- 설정 (ESC: 닫기) -"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("ffd75e"))
	v.add_child(title)

	v.add_child(_mk_slider("마스터", Sound.master_volume,
		func(val: float) -> void: Sound.master_volume = val))
	v.add_child(_mk_slider("배경음악", Sound.bgm_volume,
		func(val: float) -> void: Sound.bgm_volume = val))
	v.add_child(_mk_slider("효과음", Sound.sfx_volume,
		func(val: float) -> void: Sound.sfx_volume = val))

	# 화면 크기: 누를 때마다 창 960/1440/1920 -> 전체 화면 순환
	_win_btn = _mk_button("화면: " + GameData.window_mode_label(), func() -> void:
		Sound.play_sfx("sfx_ui")
		GameData.cycle_window_mode()
		_win_btn.text = "화면: " + GameData.window_mode_label())
	v.add_child(_win_btn)

	var win_hint := Label.new()
	win_hint.text = "F11: 전체 화면 토글"
	if OS.has_feature("editor"):
		win_hint.text += "  (에디터에서는 '창 띄우기'를 켜야 적용됨)"
	win_hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	v.add_child(win_hint)

	var keys_title := Label.new()
	keys_title.text = "키 설정 (누르고 새 키를 입력 · ESC: 취소)"
	keys_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
	v.add_child(keys_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 246)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	for pair in GameData.BINDABLE_ACTIONS:
		var action: String = pair[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := Label.new()
		l.text = pair[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(108, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			Sound.play_sfx("sfx_ui")
			_waiting_action = action
			_refresh_keys())
		_key_buttons[action] = b
		row.add_child(b)
		list.add_child(row)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bottom)
	bottom.add_child(_mk_button("기본값 복원", func() -> void:
		Sound.play_sfx("sfx_ui")
		GameData.reset_keybinds()
		_waiting_action = ""
		_refresh_keys()))
	bottom.add_child(_mk_button("닫기", func() -> void: close()))


func open() -> void:
	_waiting_action = ""
	_win_btn.text = "화면: " + GameData.window_mode_label()
	_refresh_keys()
	visible = true


func close() -> void:
	if not visible:
		return
	_waiting_action = ""
	visible = false
	Sound.play_sfx("sfx_ui")


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = "[키 입력...]" if _waiting_action == action else GameData.key_label(action)


# 새 키를 기다리는 동안만 키를 가로챈다.
# `_input`이라 게임보다 먼저 본다 — 안 그러면 W를 누르는 순간 캐릭터가 걷는다.
func _input(event: InputEvent) -> void:
	if not visible or _waiting_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			GameData.rebind_action(_waiting_action, int(event.physical_keycode))
			Sound.play_sfx("sfx_place")
		_waiting_action = ""
		_refresh_keys()
		get_viewport().set_input_as_handled()


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
	s.custom_minimum_size = Vector2(240, 16)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(val: float) -> void:
		setter.call(val)
		Sound.apply_settings()
		Sound.save_settings())
	row.add_child(s)
	return row


func _mk_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b
