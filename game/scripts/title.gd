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
	# 배경: 참고 도트 풍경화 한 장 (960x540 그대로 화면을 채운다)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 글자가 하늘 위에 얹히므로 위쪽을 살짝 어둡게 깐다.
	# 단색 판을 얹으면 경계가 자로 그은 듯 보이므로 아래로 갈수록 옅어지게 한다.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.05, 0.11, 0.44))
	grad.set_color(1, Color(0.03, 0.05, 0.11, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 8
	gtex.height = 64
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	var veil := TextureRect.new()
	veil.texture = gtex
	veil.position = Vector2(0, 0)
	veil.size = Vector2(960, 230)
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	# 타이틀
	var title := Label.new()
	title.text = "교 진 팜"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("ffe08a"))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(285, 48)
	title.size = Vector2(390, 66)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "- 도트 농장 시뮬레이션 -"
	subtitle.add_theme_color_override("font_color", Color(0.94, 0.96, 0.9))
	subtitle.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	subtitle.add_theme_constant_override("outline_size", 4)
	subtitle.position = Vector2(300, 126)
	subtitle.size = Vector2(360, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	# 메뉴 버튼 (풍경 위라 뒤에 어두운 판을 깐다)
	var menu_bg := PanelContainer.new()
	menu_bg.position = Vector2(363, 190)
	menu_bg.custom_minimum_size = Vector2(234, 180)
	menu_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mstyle := StyleBoxFlat.new()
	mstyle.bg_color = Color(0.06, 0.08, 0.12, 0.58)
	mstyle.border_color = Color(0.72, 0.62, 0.38, 0.7)
	mstyle.set_border_width_all(2)
	mstyle.set_corner_radius_all(4)
	mstyle.set_content_margin_all(10)
	menu_bg.add_theme_stylebox_override("panel", mstyle)
	add_child(menu_bg)

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
	Sound.play_track("bgm_title")

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


var gender_panel: PanelContainer = null


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_new_game() -> void:
	settings_panel.visible = false
	mp_panel.visible = false
	if gender_panel == null:
		_build_gender_panel()
	gender_panel.visible = not gender_panel.visible


func _start_new(g: String) -> void:
	# (개발 스크린샷 등 옛 경로) 성별만으로 옛 기본 외형을 만든다
	GameData.gender = g
	GameData.appearance = {"hair": 3 if g == "f" else 0,
		"shirt": 1 if g == "f" else 0, "pants": 0, "shoes": 0}
	if FileAccess.file_exists(GameData.SAVE_PATH):
		DirAccess.remove_absolute(GameData.SAVE_PATH)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---- 외형 만들기 (새로 시작) ----
# 성별(호감도·결혼 이벤트용) + 머리/상의/바지/신발 템플릿 4종씩.
# 미리보기는 표준 팔레트 도트를 골라 둔 색으로 바로 갈아입혀 보여 준다.

var _appear := {"hair": 0, "shirt": 0, "pants": 0, "shoes": 0}
var _appear_gender := "m"
var _appear_preview: TextureRect = null
var _appear_labels := {}
const APPEAR_ROWS := [["gender", "성별"], ["hair", "머리"],
	["shirt", "상의"], ["pants", "바지"], ["shoes", "신발"]]


func _appear_names(part: String) -> Array:
	match part:
		"gender":
			return ["남자", "여자"]
		"hair":
			return GameData.HAIR_NAMES
		"shirt":
			return GameData.SHIRT_NAMES
		"pants":
			return GameData.PANTS_NAMES
	return GameData.SHOES_NAMES


func _build_gender_panel() -> void:
	gender_panel = PanelContainer.new()
	gender_panel.visible = false
	gender_panel.position = Vector2(280, 140)
	gender_panel.custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.97)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	gender_panel.add_theme_stylebox_override("panel", style)
	add_child(gender_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	gender_panel.add_child(v)
	var title := Label.new()
	title.text = "우리 캐릭터 만들기"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("ffd75e"))
	v.add_child(title)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)

	_appear_preview = TextureRect.new()
	_appear_preview.custom_minimum_size = Vector2(128, 192)
	_appear_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_appear_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_appear_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(_appear_preview)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rows)
	for pair in APPEAR_ROWS:
		var part: String = pair[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l := Label.new()
		name_l.text = pair[1]
		name_l.custom_minimum_size = Vector2(44, 0)
		row.add_child(name_l)
		row.add_child(_mk_button("◀", func() -> void: _appear_cycle(part, -1)))
		var val := Label.new()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
		_appear_labels[part] = val
		row.add_child(val)
		row.add_child(_mk_button("▶", func() -> void: _appear_cycle(part, 1)))
		rows.add_child(row)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bottom)
	bottom.add_child(_mk_button("이걸로 시작!", _start_selected))
	bottom.add_child(_mk_button("닫기", func() -> void: gender_panel.visible = false))
	_appear_refresh()


func _appear_cycle(part: String, dir: int) -> void:
	if part == "gender":
		_appear_gender = "f" if _appear_gender == "m" else "m"
	else:
		_appear[part] = wrapi(int(_appear[part]) + dir, 0, _appear_names(part).size())
	_appear_refresh()


func _appear_refresh() -> void:
	for part in _appear_labels:
		var idx: int = 0 if part != "gender" else (0 if _appear_gender == "m" else 1)
		if part != "gender":
			idx = int(_appear[part])
		_appear_labels[part].text = str(_appear_names(part)[idx])
	# 미리보기: 고른 머리의 정면 서기 한 장을 고른 색으로 갈아입힌다
	var t: Texture2D = load("res://assets/sprites/%s_down_idle.png"
		% GameData.HAIR_PREFIX[int(_appear.hair)])
	var img: Image = t.get_image()
	GameData.recolor_player_image(img, _appear)
	_appear_preview.texture = ImageTexture.create_from_image(img)


func _start_selected() -> void:
	GameData.gender = _appear_gender
	GameData.appearance = _appear.duplicate()
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
	title.text = "함께하기 — 방 코드로 만나기"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	v.add_child(title)

	v.add_child(_mk_button("방 만들기 (코드가 나온다)", _on_host))

	# 방 코드 여섯 글자 — 친구가 이걸 치면 내 농장으로 들어온다
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "방 코드 6글자"
	ip_edit.max_length = 6
	ip_edit.custom_minimum_size = Vector2(210, 0)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			ip_edit.text = up
			ip_edit.caret_column = up.length())
	row.add_child(ip_edit)
	row.add_child(_mk_button("참가", _on_join))

	mp_status = Label.new()
	mp_status.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	mp_status.text = "호스트의 농장(저장)을 함께 가꾼다.\n호스트가 방을 만들어 나온 코드를 친구에게 알려 주자."
	v.add_child(mp_status)

	v.add_child(_mk_button("닫기", func() -> void: mp_panel.visible = false))


# 방 만들기 — ENet 서버를 먼저 세우고, 장터 서버에서 코드를 받아 온다.
# 코드를 보여 준 뒤 「시작하기」를 누르면 농장으로 들어간다.
func _on_host() -> void:
	if Net.host_game() != OK:
		mp_status.text = "방 만들기 실패... 포트(7777)를 확인하자."
		return
	mp_status.text = "방을 여는 중..."
	Net.rooms.opened.connect(_on_room_opened, CONNECT_ONE_SHOT)
	Net.rooms.open_room(GameData.seller_name(), Net.DEFAULT_PORT)


func _on_room_opened(ok: bool, code: String, msg: String) -> void:
	if not ok:
		# 코드를 못 받아도 같은 네트워크라면 IP로 놀 수 있다 — 그대로 들어간다
		mp_status.text = "%s\n코드 없이 방은 열렸다 (같은 공유기라면 접속된다)." % msg
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/main.tscn"))
		return
	mp_status.text = "방 코드: %s\n친구에게 알려 주자. 잠시 뒤 농장으로 들어간다." % code
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn"))


# 참가 — 코드로 주소를 물어보고, 받은 주소로 붙는다
func _on_join() -> void:
	var code := ip_edit.text.strip_edges().to_upper()
	if code.length() < 4:
		mp_status.text = "방 코드 6글자를 넣자."
		return
	mp_status.text = "방을 찾는 중..."
	Net.rooms.found.connect(_on_room_found, CONNECT_ONE_SHOT)
	Net.rooms.find_room(code)


func _on_room_found(ok: bool, ip: String, port: int, msg: String) -> void:
	if not ok:
		mp_status.text = msg
		return
	if Net.join_game(ip, port) != OK:
		mp_status.text = "접속 시작 실패... 잠시 뒤 다시 해보자."
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
	elif _shot_frames == 44:
		var img3 := get_viewport().get_texture().get_image()
		img3.save_png(OS.get_environment("KYOJIN_SHOT") + "_gender.png")
	elif _shot_frames == 46:
		_start_new("f")
