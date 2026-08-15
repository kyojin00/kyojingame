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
	title.text = "Little Root"
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
	# 생성창을 열면 이 넷을 잠시 치운다 (나무판이 제목을 반쯤 가리면 지저분하다)
	_menu_nodes = [title, subtitle, menu_bg, v]

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
var _menu_nodes: Array = []      # 생성창이 열려 있는 동안 치워 두는 타이틀 차림


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_new_game() -> void:
	settings_panel.visible = false
	mp_panel.visible = false
	if gender_panel == null:
		_build_gender_panel()
	_show_creator(not gender_panel.visible)


# 생성창을 열고 닫는다. 여는 동안 타이틀 차림(제목·부제·메뉴)은 치워 둔다
func _show_creator(on: bool) -> void:
	gender_panel.visible = on
	for n: Control in _menu_nodes:
		n.visible = not on


func _start_new(g: String) -> void:
	# (개발 스크린샷 등 옛 경로) 성별만으로 옛 기본 외형을 만든다
	GameData.gender = g
	GameData.appearance = {"hair": 3 if g == "f" else 0,
		"shirt": 1 if g == "f" else 0, "pants": 0, "shoes": 0,
		"skin": 0, "hair_col": 0}
	if FileAccess.file_exists(GameData.SAVE_PATH):
		DirAccess.remove_absolute(GameData.SAVE_PATH)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---- 캐릭터 생성창 (「새로 시작」) ----
#
# 나무판 하나 위에 왼쪽은 액자, 오른쪽은 고르는 자리다. 고르는 것은
# **전부 눈으로 본다** — 색은 색칠한 네모(스와치)를 직접 누르고,
# 성별은 글자 대신 ♂♀ 표식을, 머리 모양만 이름이 있어 화살표로 넘긴다.
# 무엇을 고르든 왼쪽 액자의 도트가 그 자리에서 갈아입는다.
#
# 이름과 농장 이름도 여기서 짓는다. 예전에는 숲에서 우체부 아저씨가
# 이름을 물었지만, 이제는 처음부터 알고 있는 사이로 시작한다.

var _appear := {"hair": 0, "shirt": 0, "pants": 0, "shoes": 0,
	"skin": 0, "hair_col": 0}
var _appear_gender := "m"
var _appear_preview: TextureRect = null
var _hair_label: Label = null
var _hair_row: HBoxContainer = null
var _name_edit: LineEdit = null
var _farm_edit: LineEdit = null
var _village_edit: LineEdit = null
var _gender_btns := {}
var _swatch_btns := {}          # 부위 -> [Button, ...]
var _blink_tex: Texture2D = null
var _idle_tex: Texture2D = null
var _blink_t := 0.0             # 눈을 깜빡이는 시늉 (액자가 살아 있게)

const WOOD_BG := Color(0.71, 0.51, 0.30)
const WOOD_DARK := Color(0.33, 0.20, 0.10)
const WOOD_MID := Color(0.55, 0.37, 0.20)
const WOOD_LIGHT := Color(0.86, 0.70, 0.46)
const INK := Color(0.24, 0.14, 0.06)
# [부위, 팻말, 색표] — 색은 각 벌의 「기본」 색을 그대로 스와치에 쓴다
const SWATCH_ROWS := [
	["hair_col", "머리색", "hair"],
	["skin", "피부", "skin"],
	["shirt", "상의", "shirt"],
	["pants", "바지", "pants"],
	["shoes", "신발", "shoes"],
]


func _swatch_colors(kind: String) -> Array:
	match kind:
		"hair":
			return GameData.APPEAR_HAIR_COL
		"skin":
			return GameData.APPEAR_SKIN
		"shirt":
			return GameData.APPEAR_SHIRT
		"pants":
			return GameData.APPEAR_PANTS
	return GameData.APPEAR_SHOES


func _wood_style(bg: Color, border: Color, w := 2, r := 4) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(w)
	st.set_corner_radius_all(r)
	st.set_content_margin_all(6)
	return st


func _wood_button(text: String, cb: Callable, w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 26)
	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.92))
	b.add_theme_stylebox_override("normal", _wood_style(WOOD_MID, WOOD_DARK))
	b.add_theme_stylebox_override("hover", _wood_style(WOOD_BG, WOOD_LIGHT))
	b.add_theme_stylebox_override("pressed", _wood_style(WOOD_DARK, WOOD_DARK))
	b.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		cb.call())
	return b


# 색칠한 네모 한 칸. 고른 칸은 테두리가 밝은 나무색으로 굵어진다
func _mk_swatch(col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 24)
	b.set_meta("col", col)
	b.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		cb.call())
	return b


func _paint_swatch(b: Button, on: bool) -> void:
	var col: Color = b.get_meta("col")
	var st := _wood_style(col, WOOD_LIGHT if on else WOOD_DARK, 3 if on else 1, 3)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("hover",
		_wood_style(col.lightened(0.12), WOOD_LIGHT, 3, 3))


func _mk_field(place: String, maxlen: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = place
	e.max_length = maxlen
	e.custom_minimum_size = Vector2(150, 28)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(0.45, 0.32, 0.2, 0.8))
	e.add_theme_color_override("caret_color", INK)
	e.add_theme_stylebox_override("normal", _wood_style(Color(0.94, 0.85, 0.68), WOOD_DARK))
	e.add_theme_stylebox_override("focus", _wood_style(Color(1, 0.94, 0.78), WOOD_LIGHT))
	return e


func _mk_tag(text: String, w := 54) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(w, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", INK)
	return l


func _build_gender_panel() -> void:
	gender_panel = PanelContainer.new()
	gender_panel.visible = false
	gender_panel.position = Vector2(148, 58)
	gender_panel.custom_minimum_size = Vector2(664, 0)
	var style := _wood_style(WOOD_BG, WOOD_DARK, 4, 8)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	gender_panel.add_theme_stylebox_override("panel", style)
	add_child(gender_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	gender_panel.add_child(v)

	# 머리말 — 나무판에 박은 명패
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _wood_style(WOOD_MID, WOOD_DARK, 2, 5))
	v.add_child(plate)
	var title := Label.new()
	title.text = "새 농부 만들기"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("ffe6a6"))
	title.add_theme_color_override("font_outline_color", WOOD_DARK)
	title.add_theme_constant_override("outline_size", 4)
	plate.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)

	# ---- 왼쪽: 액자 ----
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",
		_wood_style(Color(0.33, 0.42, 0.30), WOOD_DARK, 3, 5))
	left.add_child(frame)
	_appear_preview = TextureRect.new()
	_appear_preview.custom_minimum_size = Vector2(176, 236)
	_appear_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_appear_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_appear_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_appear_preview)

	# 성별 — 글자 대신 표식 둘
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 6)
	grow.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(grow)
	for pair: Array in [["m", "♂"], ["f", "♀"]]:
		var g: String = pair[0]
		var b := _wood_button(pair[1], func() -> void:
			_appear_gender = g
			# 성별을 바꾸면 어울리는 기본 머리로 한 번 맞춰 준다
			_appear.hair = 3 if g == "f" else 1
			_appear_refresh(), 78)
		b.add_theme_font_size_override("font_size", 26)
		_gender_btns[g] = b
		grow.add_child(b)

	# ---- 오른쪽: 고르는 자리 ----
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 7)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(_mk_tag("이름"))
	_name_edit = _mk_field("마을에서 불릴 이름", 8)
	name_row.add_child(_name_edit)
	right.add_child(name_row)

	var farm_row := HBoxContainer.new()
	farm_row.add_theme_constant_override("separation", 8)
	farm_row.add_child(_mk_tag("농장"))
	_farm_edit = _mk_field("우리 농장 이름", 12)
	farm_row.add_child(_farm_edit)
	right.add_child(farm_row)

	# 마을 이름 — 비워 두면 「교진」. 대사·간판·지도에 전부 이 이름이 쓰인다
	var vil_row := HBoxContainer.new()
	vil_row.add_theme_constant_override("separation", 8)
	vil_row.add_child(_mk_tag("마을"))
	_village_edit = _mk_field("정착할 마을 이름 (기본: 교진)", 8)
	vil_row.add_child(_village_edit)
	right.add_child(vil_row)

	# 머리 모양 — 이름이 있는 것이라 화살표로 넘긴다
	_hair_row = HBoxContainer.new()
	_hair_row.add_theme_constant_override("separation", 6)
	_hair_row.add_child(_mk_tag("머리"))
	_hair_row.add_child(_wood_button("◀", func() -> void: _hair_cycle(-1), 30))
	_hair_label = Label.new()
	_hair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hair_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hair_label.add_theme_color_override("font_color", INK)
	_hair_row.add_child(_hair_label)
	_hair_row.add_child(_wood_button("▶", func() -> void: _hair_cycle(1), 30))
	right.add_child(_hair_row)

	# 색 고르기 — 부위마다 색칠한 네모를 늘어놓는다
	for row_def: Array in SWATCH_ROWS:
		var part: String = row_def[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.add_child(_mk_tag(str(row_def[1])))
		var btns: Array = []
		var tbl: Array = _swatch_colors(str(row_def[2]))
		for i in tbl.size():
			var idx := i
			var rgb: Array = tbl[i][0]
			var b := _mk_swatch(Color8(rgb[0], rgb[1], rgb[2]), func() -> void:
				_appear[part] = idx
				_appear_refresh())
			btns.append(b)
			row.add_child(b)
		_swatch_btns[part] = btns
		right.add_child(row)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bottom)
	bottom.add_child(_wood_button("이 사람으로 시작!", _start_selected, 190))
	bottom.add_child(_wood_button("돌아가기",
		func() -> void: _show_creator(false), 110))
	_appear_refresh()


# 머리 모양만 화살표로 넘긴다 (색과 달리 한눈에 늘어놓을 수 없어서)
func _hair_cycle(dir: int) -> void:
	_appear.hair = wrapi(int(_appear.hair) + dir, 0, GameData.HAIR_NAMES.size())
	_appear_refresh()


func _appear_refresh() -> void:
	_hair_label.text = str(GameData.HAIR_NAMES[int(_appear.hair)])
	for g: String in _gender_btns:
		var on: bool = g == _appear_gender
		var b: Button = _gender_btns[g]
		b.add_theme_stylebox_override("normal",
			_wood_style(WOOD_BG if on else WOOD_MID,
				WOOD_LIGHT if on else WOOD_DARK, 3 if on else 2))
	for part: String in _swatch_btns:
		var sel: int = int(_appear[part])
		var btns: Array = _swatch_btns[part]
		for i in btns.size():
			var sw: Button = btns[i]
			_paint_swatch(sw, i == sel)
	# 민머리에는 머리카락 픽셀이 아예 없다 — 머리색 줄을 흐리게 해서
	# 「지금은 눌러도 안 바뀐다」를 색으로 알려 준다
	if _swatch_btns.has("hair_col"):
		var lit: bool = int(_appear.hair) != 0
		var hair_sw: Array = _swatch_btns["hair_col"]
		for b2: Button in hair_sw:
			b2.modulate = Color(1, 1, 1, 1.0 if lit else 0.4)
	# 액자: 고른 머리의 정면 도트를 그 자리에서 갈아입힌다 (평소 + 눈 감은 것)
	_idle_tex = _dress("%s_down_idle" % GameData.HAIR_PREFIX[int(_appear.hair)])
	_blink_tex = _dress("%s_down_blink" % GameData.HAIR_PREFIX[int(_appear.hair)])
	_appear_preview.texture = _idle_tex


func _dress(sprite: String) -> Texture2D:
	var path := "res://assets/sprites/%s.png" % sprite
	if not ResourceLoader.exists(path):
		return null
	var img: Image = (load(path) as Texture2D).get_image()
	GameData.recolor_player_image(img, _appear)
	return ImageTexture.create_from_image(img)


func _start_selected() -> void:
	GameData.gender = _appear_gender
	GameData.appearance = _appear.duplicate()
	GameData.player_name = _name_edit.text.strip_edges()
	GameData.farm_name = _farm_edit.text.strip_edges()
	GameData.village_name = _village_edit.text.strip_edges()
	if GameData.player_name == "":
		GameData.player_name = "친구"
	if FileAccess.file_exists(GameData.SAVE_PATH):
		DirAccess.remove_absolute(GameData.SAVE_PATH)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# 검증용 — 고른 색이 정말 액자 속 도트에 칠해졌는지 픽셀로 센다.
# (스와치만 눌리고 그림은 그대로면 아무 소용이 없다)
func _creator_report() -> String:
	if _idle_tex == null:
		return "false 미리보기없음"
	var img: Image = _idle_tex.get_image()
	var want := {
		"hair": Color8(GameData.APPEAR_HAIR_COL[int(_appear.hair_col)][0][0],
			GameData.APPEAR_HAIR_COL[int(_appear.hair_col)][0][1],
			GameData.APPEAR_HAIR_COL[int(_appear.hair_col)][0][2]).to_rgba32(),
		"skin": Color8(GameData.APPEAR_SKIN[int(_appear.skin)][0][0],
			GameData.APPEAR_SKIN[int(_appear.skin)][0][1],
			GameData.APPEAR_SKIN[int(_appear.skin)][0][2]).to_rgba32(),
	}
	var src := {
		"hair": Color8(GameData.APPEAR_HAIR_COL[0][0][0],
			GameData.APPEAR_HAIR_COL[0][0][1],
			GameData.APPEAR_HAIR_COL[0][0][2]).to_rgba32(),
		"skin": Color8(GameData.APPEAR_SKIN[0][0][0], GameData.APPEAR_SKIN[0][0][1],
			GameData.APPEAR_SKIN[0][0][2]).to_rgba32(),
	}
	var hair_n := 0
	var skin_n := 0
	var stale := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var k := c.to_rgba32()
			if k == want.hair:
				hair_n += 1
			elif k == want.skin:
				skin_n += 1
			elif k == src.hair or k == src.skin:
				stale += 1
	var sw_hair: Array = _swatch_btns["hair_col"]
	var sw_skin: Array = _swatch_btns["skin"]
	var sw_shirt: Array = _swatch_btns["shirt"]
	var rows_ok: bool = sw_hair.size() == GameData.APPEAR_HAIR_COL.size() \
		and sw_skin.size() == GameData.APPEAR_SKIN.size() \
		and sw_shirt.size() == GameData.APPEAR_SHIRT.size()
	var typed: bool = _name_edit.text != "" and _farm_edit.text != "" \
		and _village_edit.text != ""
	var ok: bool = hair_n > 0 and skin_n > 0 and stale == 0 and rows_ok and typed
	return "%s 머리색=%d 피부=%d 옛색남음=%d 스와치=%s 이름·농장칸=%s" \
		% [ok, hair_n, skin_n, stale, rows_ok, typed]


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


# 코드가 나오면 **기다린다.** 저절로 넘어가면 코드를 못 보고 지나친다
# (농장에 들어간 뒤에도 화면 오른쪽 위에 계속 떠 있긴 하다)
func _on_room_opened(ok: bool, code: String, msg: String) -> void:
	if not ok:
		# 코드를 못 받아도 같은 네트워크라면 주소로 놀 수 있다
		mp_status.text = "%s\n코드 없이 방은 열렸다 (같은 공유기라면 접속된다)." % msg
		_show_start_button("농장으로 들어가기")
		return
	_room_code = code
	mp_status.text = "방 코드   %s\n친구에게 알려 주자. (농장 안에서도 오른쪽 위에 계속 보인다)" % code
	_show_start_button("복사하고 시작하기")


var _room_code := ""
var _start_row: HBoxContainer = null


func _show_start_button(text: String) -> void:
	if _start_row != null and is_instance_valid(_start_row):
		_start_row.queue_free()
	_start_row = HBoxContainer.new()
	_start_row.add_theme_constant_override("separation", 8)
	_start_row.alignment = BoxContainer.ALIGNMENT_CENTER
	(mp_panel.get_child(0) as VBoxContainer).add_child(_start_row)
	_start_row.add_child(_mk_button(text, func() -> void:
		if _room_code != "":
			DisplayServer.clipboard_set(_room_code)   # 붙여넣어 알려 주기 편하게
		get_tree().change_scene_to_file("res://scenes/main.tscn")))


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


func _process(delta: float) -> void:
	# 액자 속 농부가 이따금 눈을 깜빡인다 (가만히 있어도 살아 있어 보이게)
	if gender_panel != null and gender_panel.visible and _idle_tex != null:
		_blink_t += delta
		if _blink_t >= 3.4:
			_blink_t = 0.0
		var shut: bool = _blink_t > 3.25 and _blink_tex != null
		_appear_preview.texture = _blink_tex if shut else _idle_tex
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
	elif _shot_frames == 42:
		# 화면에 남길 한 장은 실제로 골라 본 모습으로 (빈 칸만 찍으면 소용없다)
		_name_edit.text = "교진"
		_farm_edit.text = "햇살 농장"
		_village_edit.text = "교진"
		_appear_gender = "f"
		_appear = {"hair": 3, "shirt": 1, "pants": 1, "shoes": 2,
			"skin": 2, "hair_col": 3}
		_appear_refresh()
		print("CREATOR_OK=", _creator_report())
	elif _shot_frames == 44:
		var img3 := get_viewport().get_texture().get_image()
		img3.save_png(OS.get_environment("KYOJIN_SHOT") + "_gender.png")
	elif _shot_frames == 46:
		_start_new("f")
