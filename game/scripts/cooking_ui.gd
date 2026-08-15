# 주방 (집 안 조리대 E) — 큰 격자에 요리 일러스트를 늘어놓는다.
#
# 구조는 두 겹이다:
#   ① RecipeGrid  — 격자 셀(일러스트)만. 잠긴 레시피는 아예 안 보이고,
#                    배운 뒤 아직 안 만들어 본 요리는 회색으로 나온다.
#   ② RecipeDetail — 셀을 누르면 뜨는 상세 창. 재료 수급 현황과
#                    [만들기] 버튼이 여기에만 있다 (격자에서 바로 못 만든다).
#
# 상태 규칙 (요리 id 하나당):
#   recipe_locked(id)            -> 격자에 노출하지 않는다
#   미제작 (recipes_cooked에 없음) -> 회색(그레이스케일 셰이더) 일러스트
#   제작 1회 이상                 -> 원래 색 일러스트
extends CanvasLayer

const COLS := 7                 # 격자 열 수 (셀 64px — 눈에 확 들어오는 크기)
const CELL := 64.0

# 미제작 요리를 회색으로 — 색조만 어둡히는 게 아니라 진짜 무채색으로 만든다
const GRAY_SHADER := "
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g) * 0.8, c.a * 0.9);
}"

var main: Node2D
var grid: GridContainer
var head_label: Label
var _refresh_timer := 0.0
var _gray_mat: ShaderMaterial

# 상세 창 (RecipeDetail)
var detail: PanelContainer
var _detail_id := ""            # 지금 상세 창이 보여 주는 요리 ("" = 닫힘)
var _detail_box: VBoxContainer


func _ready() -> void:
	layer = 22
	visible = false

	var sh := Shader.new()
	sh.code = GRAY_SHADER
	_gray_mat = ShaderMaterial.new()
	_gray_mat.shader = sh

	# ---- 격자 패널 ----
	var panel := PanelContainer.new()
	panel.position = Vector2(200, 62)
	panel.custom_minimum_size = Vector2(560, 416)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 주방 (E/ESC: 닫기) -"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	head_label = Label.new()
	head_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.6))
	head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(536, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	# ---- 상세 창 (셀을 누르면 격자 위에 뜬다) ----
	detail = PanelContainer.new()
	detail.visible = false
	detail.position = Vector2(300, 96)
	detail.custom_minimum_size = Vector2(360, 0)
	var dstyle := StyleBoxFlat.new()
	dstyle.bg_color = Color(0.12, 0.1, 0.17, 0.99)
	dstyle.border_color = Color(1, 0.84, 0.37)
	dstyle.set_border_width_all(2)
	dstyle.set_corner_radius_all(5)
	dstyle.set_content_margin_all(12)
	detail.add_theme_stylebox_override("panel", dstyle)
	add_child(detail)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 6)
	detail.add_child(_detail_box)


func open() -> void:
	visible = true
	_detail_id = ""
	detail.visible = false
	Sound.play_sfx("sfx_ui")
	_rebuild()


func close() -> void:
	visible = false
	detail.visible = false
	_detail_id = ""


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		if _detail_id != "":
			_close_detail()      # 상세 창부터 닫는다 — 한 번 더 누르면 주방 닫기
		else:
			close()
		get_viewport().set_input_as_handled()


# ---- RecipeGrid ----


func _rebuild() -> void:
	for c in grid.get_children():
		c.queue_free()

	# 노출 판정: 잠긴 레시피는 셀 자체가 없다. 만들 수 있는 것을 앞으로.
	var ready_ids: Array[String] = []
	var rest_ids: Array[String] = []
	var locked_n := 0
	var made_n := 0
	for id: String in GameData.RECIPE_IDS:
		if GameData.recipe_locked(id):
			locked_n += 1
			continue
		if int(GameData.recipes_cooked.get(id, 0)) > 0:
			made_n += 1
		if GameData.can_cook(id):
			ready_ids.append(id)
		else:
			rest_ids.append(id)

	head_label.text = "숙련 Lv.%d · 회복 +%d%% · 만들어 본 요리 %d/%d" % [
		GameData.skill_lv("cook"),
		int(round((GameData.cook_energy_mult() - 1.0) * 100.0)),
		made_n, ready_ids.size() + rest_ids.size()]
	if locked_n > 0:
		head_label.text += " · 숨은 레시피 %d" % locked_n

	for id: String in ready_ids + rest_ids:
		grid.add_child(_mk_cell(id))

	# 아직 아무 레시피도 모르면 — 조리대는 비어 있다
	if ready_ids.is_empty() and rest_ids.is_empty():
		var empty := Label.new()
		empty.text = "아는 레시피가 없다.\n재료를 모으고 발견하다 보면 요리가 떠오른다."
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.55, 0.45, 0.35))
		grid.add_child(empty)

	if _detail_id != "":
		_rebuild_detail()        # 열려 있는 상세 창도 수급 현황을 따라간다


# 격자 셀: 요리 일러스트 + 보유 수 + 재료 되면 초록 테두리
func _mk_cell(id: String) -> Button:
	var made := int(GameData.recipes_cooked.get(id, 0)) > 0
	var can := GameData.can_cook(id)

	var b := Button.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = str(GameData.ITEMS[id].name)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.09, 0.16, 0.9)
	st.border_color = Color(0.45, 0.85, 0.5) if can else Color(0.32, 0.27, 0.43)
	st.set_border_width_all(2 if can else 1)
	st.set_corner_radius_all(4)
	var st2: StyleBoxFlat = st.duplicate()
	st2.border_color = Color(1, 0.84, 0.37)
	st2.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st2)
	b.add_theme_stylebox_override("pressed", st2)

	var ic := TextureRect.new()
	ic.texture = main.tex.get(id)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 7
	ic.offset_top = 7
	ic.offset_right = -7
	ic.offset_bottom = -7
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not made:
		ic.material = _gray_mat   # 아직 안 만들어 봤다 — 회색 실루엣
	b.add_child(ic)

	var owned := int(GameData.items[id])
	if owned > 0:
		var num := Label.new()
		num.text = str(owned)
		num.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		num.offset_left = -30
		num.offset_top = -18
		num.offset_right = -4
		num.offset_bottom = -2
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.add_theme_font_override("font", preload("res://assets/fonts/Galmuri9.ttf"))
		num.add_theme_font_size_override("font_size", 10)
		num.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		num.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.14))
		num.add_theme_constant_override("outline_size", 3)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)

	b.pressed.connect(_open_detail.bind(id))
	return b


# ---- RecipeDetail ----


func _open_detail(id: String) -> void:
	_detail_id = id
	Sound.play_sfx("sfx_ui")
	_rebuild_detail()
	detail.visible = true


func _close_detail() -> void:
	_detail_id = ""
	detail.visible = false


func _rebuild_detail() -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	var id := _detail_id
	if id == "":
		return
	var def: Dictionary = GameData.ITEMS[id]
	var rec: Dictionary = GameData.RECIPES[id]
	var made := int(GameData.recipes_cooked.get(id, 0))

	# 머리: 일러스트 + 이름 + 요약
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var ic := TextureRect.new()
	ic.texture = main.tex.get(id)
	ic.custom_minimum_size = Vector2(52, 52)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if made == 0:
		ic.material = _gray_mat
	head.add_child(ic)
	var hv := VBoxContainer.new()
	var nm := Label.new()
	nm.text = str(def.name) + ("" if made > 0 else "  (아직 안 만들어 봤다)")
	nm.add_theme_color_override("font_color", Color("ffd75e"))
	hv.add_child(nm)
	var sub := Label.new()
	# 체력 회복과 「배부름」은 따로다 — 무엇을 지을지 여기서 고른다
	var fill_txt := (" · 배부름 %s" % GameData.fill_word(id)) \
		if GameData.hunger_open else ""
	sub.text = "회복 +%d%s · 판매 %dG · 보유 %d · 만든 횟수 %d" % [
		int(rec.energy), fill_txt, int(def.sell), int(GameData.items[id]), made]
	sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	hv.add_child(sub)
	head.add_child(hv)
	_detail_box.add_child(head)

	# 재료 수급: 모자란 줄은 붉게
	var rl := Label.new()
	rl.text = "[재료]"
	rl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.6))
	_detail_box.add_child(rl)
	for k in rec.needs:
		var need := int(rec.needs[k])
		var have := GameData.ingredient_count(str(k))
		var nm2: String = GameData.CROPS[k].name if GameData.CROPS.has(k) \
			else GameData.ITEMS[k].name
		var line := Label.new()
		line.text = "  %s x%d  (보유 %d)" % [nm2, need, have]
		line.add_theme_color_override("font_color",
			Color(0.85, 0.92, 0.85) if have >= need else Color(0.9, 0.5, 0.45))
		_detail_box.add_child(line)

	# 버튼 줄: [만들기]가 주인공 — 여기서만 실제 조리가 시작된다
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	var cook := Button.new()
	cook.text = "만들기"
	cook.focus_mode = Control.FOCUS_NONE
	cook.custom_minimum_size = Vector2(120, 34)
	cook.disabled = not GameData.can_cook(id)
	cook.pressed.connect(func() -> void:
		main.doing.do_cook(id)
		_rebuild())
	btns.add_child(cook)
	if int(GameData.items[id]) > 0:
		var eat := Button.new()
		eat.text = "먹기"
		eat.focus_mode = Control.FOCUS_NONE
		eat.pressed.connect(func() -> void:
			main.doing.do_eat(id)
			_rebuild())
		btns.add_child(eat)
	var back := Button.new()
	back.text = "닫기"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close_detail)
	btns.add_child(back)
	_detail_box.add_child(btns)
	if cook.disabled:
		var why := Label.new()
		why.text = "재료가 모자라다."
		why.add_theme_color_override("font_color", Color(0.6, 0.55, 0.65))
		_detail_box.add_child(why)
	detail.reset_size()
