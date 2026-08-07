# 타이틀 화면: 이어하기 / 새로 시작 / 설정 / 종료
extends Control

var settings_panel: PanelContainer
var mp_panel: PanelContainer
var keys_panel: PanelContainer
var ip_edit: LineEdit
var mp_status: Label
var _shot_frames := 0
# 키 리바인딩: 값이 비어있지 않으면 다음 키 입력을 이 액션에 배정한다
var _waiting_action := ""
var _key_buttons := {}


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
		["tree_spring", Vector2(75, 375), 2.5], ["tree_spring", Vector2(810, 360), 2.5],
		["house", Vector2(60, 60), 1.6], ["mature_pumpkin", Vector2(210, 459), 2.0],
		["mature_strawberry", Vector2(300, 465), 2.0], ["chicken_0", Vector2(585, 468), 2.0],
		["cow_0", Vector2(690, 459), 2.0],
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
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	title.add_theme_constant_override("outline_size", 3)
	title.position = Vector2(285, 72)
	title.size = Vector2(390, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "- 도트 농장 시뮬레이션 -"
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	subtitle.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	subtitle.add_theme_constant_override("outline_size", 2)
	subtitle.position = Vector2(300, 148)
	subtitle.size = Vector2(360, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	# 메뉴 버튼
	var v := VBoxContainer.new()
	v.position = Vector2(375, 200)
	v.custom_minimum_size = Vector2(210, 0)
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var has_save := FileAccess.file_exists(GameData.SAVE_PATH)
	var continue_btn := _mk_button("이어하기", _on_continue)
	continue_btn.disabled = not has_save
	v.add_child(continue_btn)
	v.add_child(_mk_button("새로 시작", _on_new_game))
	v.add_child(_mk_button("함께하기", _on_multiplayer))
	v.add_child(_mk_button("설정", _on_settings))
	v.add_child(_mk_button("종료", func() -> void: get_tree().quit()))

	_build_settings_panel()
	_build_keys_panel()
	_build_mp_panel()
	Net.reset()
	Sound.play_bgm("spring")

	# 개발/CI용: KYOJIN_MP=host|guest 로 자동 접속
	var mp := OS.get_environment("KYOJIN_MP")
	if mp == "host":
		Net.host_game()
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
	elif mp == "guest":
		Net.join_game("127.0.0.1")
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


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
	mp_panel.visible = false
	settings_panel.visible = not settings_panel.visible


func _on_multiplayer() -> void:
	settings_panel.visible = false
	mp_panel.visible = not mp_panel.visible


func _build_mp_panel() -> void:
	mp_panel = PanelContainer.new()
	mp_panel.visible = false
	mp_panel.position = Vector2(285, 135)
	mp_panel.custom_minimum_size = Vector2(390, 225)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.97)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	mp_panel.add_theme_stylebox_override("panel", style)
	add_child(mp_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mp_panel.add_child(v)

	var title := Label.new()
	title.text = "함께하기 (같은 네트워크)"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	v.add_child(title)

	v.add_child(_mk_button("방 만들기 (호스트)", _on_host))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "호스트 IP"
	ip_edit.custom_minimum_size = Vector2(210, 0)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ip_edit)
	row.add_child(_mk_button("참가", _on_join))

	mp_status = Label.new()
	mp_status.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	mp_status.text = "호스트의 농장(저장)을 함께 가꾼다.\n호스트: 방 만들기 / 친구: IP 입력 후 참가"
	v.add_child(mp_status)

	v.add_child(_mk_button("닫기", func() -> void: mp_panel.visible = false))


func _on_host() -> void:
	if Net.host_game() != OK:
		mp_status.text = "방 만들기 실패... 포트(7777)를 확인하자."
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_join() -> void:
	if Net.join_game(ip_edit.text.strip_edges()) != OK:
		mp_status.text = "접속 시작 실패... IP를 확인하자."
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.position = Vector2(300, 90)
	settings_panel.custom_minimum_size = Vector2(360, 225)
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

	# 화면 크기: 누를 때마다 창 960/1440/1920 → 전체 화면 순환 (F11: 전체 화면 토글)
	var win_btn := Button.new()
	win_btn.text = "화면: " + GameData.window_mode_label()
	win_btn.focus_mode = Control.FOCUS_NONE
	win_btn.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		GameData.cycle_window_mode()
		win_btn.text = "화면: " + GameData.window_mode_label())
	v.add_child(win_btn)

	var win_hint := Label.new()
	win_hint.text = "F11: 전체 화면 토글"
	# 에디터 임베드 실행 중에는 창 크기/전체 화면 변경이 막힌다
	if OS.has_feature("editor"):
		win_hint.text += "\n(에디터에서는 게임 패널 우상단 메뉴의\n'창 띄우기'를 켜야 화면 변경이 적용됨)"
	win_hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	v.add_child(win_hint)

	v.add_child(_mk_button("키 설정", func() -> void:
		settings_panel.visible = false
		_refresh_key_buttons()
		keys_panel.visible = true))

	var close_btn := _mk_button("닫기", func() -> void: settings_panel.visible = false)
	v.add_child(close_btn)


func _build_keys_panel() -> void:
	keys_panel = PanelContainer.new()
	keys_panel.visible = false
	keys_panel.position = Vector2(255, 30)
	keys_panel.custom_minimum_size = Vector2(450, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.97)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	keys_panel.add_theme_stylebox_override("panel", style)
	add_child(keys_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	keys_panel.add_child(v)

	var title := Label.new()
	title.text = "키 설정 (버튼 누르고 새 키 입력)"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 357)
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
			_refresh_key_buttons())
		_key_buttons[action] = b
		row.add_child(b)
		list.add_child(row)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bottom)
	bottom.add_child(_mk_button("기본값 복원", func() -> void:
		GameData.reset_keybinds()
		_waiting_action = ""
		_refresh_key_buttons()))
	bottom.add_child(_mk_button("닫기", func() -> void:
		_waiting_action = ""
		keys_panel.visible = false))


func _refresh_key_buttons() -> void:
	for action in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = "[키 입력...]" if _waiting_action == action else GameData.key_label(action)


func _input(event: InputEvent) -> void:
	# 리바인딩 대기 중이면 다음 키 입력을 가로챈다 (ESC: 취소)
	if _waiting_action == "" or not keys_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			GameData.rebind_action(_waiting_action, int(event.physical_keycode))
			Sound.play_sfx("sfx_place")
		_waiting_action = ""
		_refresh_key_buttons()
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
	if OS.get_environment("KYOJIN_SHOT") == "" or OS.get_environment("KYOJIN_MP") != "":
		return
	_shot_frames += 1
	if _shot_frames == 30:
		var img := get_viewport().get_texture().get_image()
		img.save_png(OS.get_environment("KYOJIN_SHOT") + "_title.png")
	elif _shot_frames == 32:
		_refresh_key_buttons()
		keys_panel.visible = true
	elif _shot_frames == 36:
		var img := get_viewport().get_texture().get_image()
		img.save_png(OS.get_environment("KYOJIN_SHOT") + "_keys.png")
	elif _shot_frames == 38:
		keys_panel.visible = false
	elif _shot_frames == 40:
		_on_new_game()
