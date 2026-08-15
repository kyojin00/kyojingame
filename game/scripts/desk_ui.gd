# 제작대 창 — 집 안 책상에서 E.
#
# 여기서 가구를 「걸어 두면」 시간이 지나 완성되고, 완성된 가구는 낡은
# 것과 저절로 바뀐다. 큐는 GameData.desk_tick이 돌리므로 창을 닫고
# 딴 일을 해도 만들어진다. 손보기(제작대 업글)만 즉시다 —
# 자기 자신은 자기로 못 만든다.
#
# 화면은 **글자보다 그림**이다. 무엇을 만드는지도, 무엇이 드는지도
# 아이콘으로 먼저 읽히고, 이름·설명은 고른 뒤 아래 상세 칸에서만
# 길게 말한다. 만들 것이 늘어나면서 한 줄로는 안 보이므로 위쪽
# 탭(전체·도구·가구·생활)으로 갈래를 나눈다.
extends CanvasLayer

# 탭 — key는 _cat_of()가 돌려주는 갈래, tex는 탭 그림
const TABS := [
	{"key": "all", "name": "전체", "tex": "desk"},
	{"key": "tool", "name": "도구", "tex": "icon_sword"},
	{"key": "furniture", "name": "가구", "tex": "bed_wood"},
	{"key": "life", "name": "생활", "tex": "broom"},
]
# 재료 그림이 아이템 이름과 다른 것들
const MAT_ALIAS := {"wood": "icon_wood", "stone": "icon_stone"}

var main: Node2D
var _root: VBoxContainer
var _refresh := 0.0
var _sel := ""            # 격자에서 고른 레시피 (상세·만들기 칸이 아래 뜬다)
var _tab := "all"         # 지금 보고 있는 갈래


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(186, 62)
	panel.custom_minimum_size = Vector2(588, 392)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.18, 0.12, 0.98)
	style.border_color = Color(0.62, 0.48, 0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 6)
	panel.add_child(_root)


func open() -> void:
	visible = true
	_rebuild()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25          # 진행 막대가 눈에 띄게 줄어드는 정도면 충분하다
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


# ---- 갈래 나누기 ----------------------------------------------------

# 레시피가 어느 탭에 들어가는가 — 표의 kind를 사람이 보는 갈래로 옮긴다
func cat_of(id: String) -> String:
	if not GameData.DESK_RECIPES.has(id):
		return "life"
	var kind := str(GameData.DESK_RECIPES[id].get("kind", "item"))
	if kind == "tool":
		return "tool"
	if kind == "furniture" or kind == "bed":
		return "furniture"
	return "life"


# 지금 격자에 놓일 레시피들 — 배운 것만 보인다 (모르는 건 아예 없다)
func tab_ids(key: String) -> Array:
	var out: Array = []
	for id: String in GameData.DESK_RECIPES:
		var def: Dictionary = GameData.DESK_RECIPES[id]
		if bool(def.get("locked", false)) and id not in GameData.recipes_unlocked:
			continue
		if key != "all" and cat_of(id) != key:
			continue
		out.append(id)
	return out


func set_tab(key: String) -> void:
	_tab = key
	if _sel != "" and _sel not in tab_ids(_tab):
		_sel = ""
	if visible:
		_rebuild()


# ---- 그림 찾기 ------------------------------------------------------

# 레시피의 얼굴 그림 — 아이템/가구/도구 순으로 찾는다
func _recipe_tex(id: String) -> Texture2D:
	var def: Dictionary = GameData.DESK_RECIPES[id]
	for cand in [id, "icon_" + id, str(def.get("give", "")),
			str(def.get("furn", "")), str(def.get("tool", "")),
			"icon_" + str(def.get("tool", "")),
			"bed_old" if str(def.get("kind", "")) == "bed" else "", "recipe"]:
		if str(cand) != "" and main.tex.has(cand):
			return main.tex[cand]
	return null


func _mat_tex(k: String) -> Texture2D:
	for cand in [str(MAT_ALIAS.get(k, k)), k, "icon_" + k, "forage_" + k]:
		if str(cand) != "" and main.tex.has(cand):
			return main.tex[cand]
	return null


func _mat_name(k: String) -> String:
	if GameData.ITEMS.has(k):
		return str(GameData.ITEMS[k].name)
	return "목재" if k == "wood" else ("석재" if k == "stone" else k)


# ---- 조각 만들기 ----------------------------------------------------

func _quiet(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _pic(tex: Texture2D, w: int, h: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(w, h)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_quiet(t)
	return t


func _tiny(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	_quiet(l)
	return l


func _line(text: String, color := Color(0.9, 0.85, 0.75)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	_root.add_child(l)


# 재료 줄 — 「그림 + 개수」만. 모자란 재료는 붉게 물든다
func _mat_row(cost: Dictionary, size: int, font: int, show_have: bool) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	_quiet(hb)
	for k: String in cost:
		var need := int(cost[k])
		var have := GameData.mat_count(k)
		var ok := have >= need
		var one := HBoxContainer.new()
		one.add_theme_constant_override("separation", 1)
		_quiet(one)
		var t := _mat_tex(k)
		if t != null:
			var p := _pic(t, size, size)
			p.modulate = Color(1, 1, 1) if ok else Color(1.0, 0.55, 0.5)
			one.add_child(p)
		else:
			one.add_child(_tiny(_mat_name(k).left(1), font, Color(0.8, 0.75, 0.65)))
		var txt := ("%d/%d" % [have, need]) if show_have else str(need)
		one.add_child(_tiny(txt, font,
			Color(0.88, 0.95, 0.82) if ok else Color(1.0, 0.55, 0.5)))
		hb.add_child(one)
	return hb


# ---- 화면 ------------------------------------------------------------

func _rebuild() -> void:
	for c in _root.get_children():
		c.queue_free()
	var lv := GameData.desk_lv

	# 머리 — 제작대 그림 + 이름, 오른쪽에 걸리는 시간·칸 수
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	if main.tex.has("desk"):
		head.add_child(_pic(main.tex["desk"], 34, 34))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	_quiet(hv)
	hv.add_child(_tiny(str(GameData.DESK_NAMES[lv]), 14, Color(0.97, 0.85, 0.55)))
	hv.add_child(_tiny("⏱ %.1f초   ▤ %d칸" % [GameData.desk_time(), GameData.desk_slots()],
		10, Color(0.72, 0.66, 0.56)))
	head.add_child(hv)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiet(sp)
	head.add_child(sp)
	head.add_child(_tiny("E / ESC", 10, Color(0.6, 0.55, 0.48)))
	_root.add_child(head)

	# 탭 — 그림 단추 네 개
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_root.add_child(tabs)
	for t: Dictionary in TABS:
		tabs.add_child(_mk_tab(t))

	# 만드는 중 — 그림 아래 진행 막대
	if not GameData.desk_queue.is_empty():
		var jobs := HBoxContainer.new()
		jobs.add_theme_constant_override("separation", 6)
		jobs.add_child(_tiny("⏳", 15, Color(0.95, 0.8, 0.5)))
		for job: Dictionary in GameData.desk_queue:
			jobs.add_child(_mk_job(job))
		_root.add_child(jobs)

	# 격자 — 그림을 눌러 고른다
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(566, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(grid)
	var shown := tab_ids(_tab)
	for id: String in shown:
		grid.add_child(_mk_cell(id))
	if shown.is_empty():
		_line("     이 갈래에 아는 레시피가 없다 — 상점·이야기에서 배워 온다",
			Color(0.6, 0.55, 0.48))

	# 고른 것의 상세 — 큰 그림 + 이름 + 설명 + 만들기
	if _sel != "" and _sel in shown:
		_root.add_child(_mk_detail(_sel))

	# 손보기 (제작대 업글, 즉시)
	_root.add_child(_mk_upgrade(lv))


func _mk_tab(t: Dictionary) -> Button:
	var key := str(t.key)
	var on := _tab == key
	var b := Button.new()
	b.custom_minimum_size = Vector2(90, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = str(t.name)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.42, 0.32, 0.18) if on else Color(0.28, 0.21, 0.14)
	st.border_color = Color(0.95, 0.82, 0.42) if on else Color(0.45, 0.36, 0.26)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	for s: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, st)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	_quiet(row)
	var tex: Texture2D = main.tex.get(str(t.tex))
	if tex != null:
		var p := _pic(tex, 24, 24)
		p.modulate = Color(1, 1, 1) if on else Color(0.72, 0.68, 0.62)
		row.add_child(p)
	row.add_child(_tiny(str(t.name), 11,
		Color(1.0, 0.93, 0.7) if on else Color(0.72, 0.67, 0.58)))
	b.add_child(row)
	b.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		set_tab(key))
	return b


func _mk_job(job: Dictionary) -> Control:
	var id := str(job.id)
	var def: Dictionary = GameData.DESK_RECIPES[id]
	var total := GameData.desk_time()
	var done := 1.0 - float(job.left) / maxf(0.01, total)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(44, 0)
	v.add_theme_constant_override("separation", 1)
	v.tooltip_text = "%s — %.1f초 남음" % [def.name, maxf(0.0, float(job.left))]
	var tex := _recipe_tex(id)
	if tex != null:
		v.add_child(_pic(tex, 40, 34))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(40, 7)
	bar.value = done * 100.0
	bar.show_percentage = false
	_quiet(bar)
	v.add_child(bar)
	return v


# 격자 한 칸 — 큰 그림 + 작은 이름 + 재료 그림줄
func _mk_cell(id: String) -> Button:
	var def: Dictionary = GameData.DESK_RECIPES[id]
	var why := _cant_reason(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(88, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s — %s" % [def.name, _cost_text(def.cost)]
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.33, 0.25, 0.16) if _sel == id else Color(0.3, 0.23, 0.15)
	st.border_color = Color(0.95, 0.85, 0.4) if _sel == id \
		else (Color(0.45, 0.75, 0.4) if why == "" else Color(0.45, 0.36, 0.26))
	st.set_border_width_all(3 if _sel == id else 2)
	st.set_corner_radius_all(4)
	for s: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, st)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 4
	v.offset_top = 4
	v.offset_right = -4
	v.offset_bottom = -4
	v.add_theme_constant_override("separation", 1)
	_quiet(v)
	var tex := _recipe_tex(id)
	if tex != null:
		var p := _pic(tex, 0, 46)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.modulate = Color(1, 1, 1) if why == "" else Color(0.55, 0.55, 0.55)
		v.add_child(p)
	var nm := _tiny(str(def.name), 10,
		Color(0.95, 0.9, 0.8) if why == "" else Color(0.66, 0.62, 0.55))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(nm)
	var mats := _mat_row(def.cost, 14, 9, false)
	mats.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(mats)
	b.add_child(v)

	b.pressed.connect(func() -> void:
		_sel = id
		Sound.play_sfx("sfx_ui")
		_rebuild())
	return b


# 고른 것 — 큰 그림 옆에 이름·재료·설명, 오른쪽 끝에 만들기
func _mk_detail(id: String) -> PanelContainer:
	var def: Dictionary = GameData.DESK_RECIPES[id]
	var why := _cant_reason(id)
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.18, 0.13, 0.09, 0.95)
	st.border_color = Color(0.5, 0.4, 0.24)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(6)
	pc.add_theme_stylebox_override("panel", st)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	pc.add_child(row)
	var tex := _recipe_tex(id)
	if tex != null:
		row.add_child(_pic(tex, 52, 52))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	_quiet(v)
	var owned := "   (지금: %s)" % GameData.BED_NAMES[GameData.bed_lv] \
		if str(def.kind) == "bed" else ""
	v.add_child(_tiny("%s%s" % [def.name, owned], 13, Color(0.97, 0.92, 0.8)))
	v.add_child(_mat_row(def.cost, 17, 11, true))
	var note := _tiny(why if why != "" else str(def.desc), 10,
		Color(1.0, 0.6, 0.55) if why != "" else Color(0.7, 0.65, 0.55))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(330, 0)
	v.add_child(note)
	row.add_child(v)

	var mk := Button.new()
	mk.text = " 만들기"
	mk.icon = tex
	mk.custom_minimum_size = Vector2(96, 44)
	mk.expand_icon = true
	mk.focus_mode = Control.FOCUS_NONE
	mk.disabled = why != ""
	mk.pressed.connect(func() -> void:
		if GameData.desk_start(id):
			Sound.play_sfx("sfx_place")
			main.saveio.save_now()
		_rebuild())
	row.add_child(mk)
	return pc


func _mk_upgrade(lv: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if lv >= GameData.DESK_UPGRADES.size():
		row.add_child(_tiny("🔨 더 손볼 데가 없다 — 장인의 솜씨다.", 11,
			Color(0.68, 0.62, 0.52)))
		return row
	var up: Dictionary = GameData.DESK_UPGRADES[lv]
	var ub := Button.new()
	ub.text = " 손보기"
	var dtex: Texture2D = main.tex.get("desk")
	ub.icon = dtex
	ub.expand_icon = true
	ub.custom_minimum_size = Vector2(92, 34)
	ub.focus_mode = Control.FOCUS_NONE
	ub.disabled = not GameData.mats_ok(up.cost)
	ub.tooltip_text = "%s -> %s" % [GameData.DESK_NAMES[lv], GameData.DESK_NAMES[lv + 1]]
	ub.pressed.connect(func() -> void:
		if GameData.desk_upgrade():
			Sound.play_sfx("sfx_place")
			main.hud.event_toast("%s 완성" % GameData.DESK_NAMES[GameData.desk_lv])
			main.saveio.save_now()
		_rebuild())
	row.add_child(ub)
	row.add_child(_mat_row(up.cost, 17, 11, true))
	row.add_child(_tiny("→ ⏱ %.1f초  ▤ %d칸" % [GameData.DESK_TIME[lv + 1],
		GameData.DESK_SLOTS[lv + 1]], 11, Color(0.85, 0.8, 0.7)))
	return row


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k: String in cost:
		parts.append("%s %d(%d)" % [_mat_name(k), int(cost[k]), GameData.mat_count(k)])
	return " · ".join(parts)


# 왜 못 만드는가 — 버튼을 끄기만 하면 이유를 모른다
func _cant_reason(id: String) -> String:
	var def: Dictionary = GameData.DESK_RECIPES[id]
	if bool(def.get("locked", false)) and id not in GameData.recipes_unlocked:
		return "레시피를 몰라서 못 만든다 — %s에서 배울 수 있다" % str(def.get("shop", "잡화점"))
	if str(def.kind) == "bed":
		if GameData.bed_lv >= int(def.lv):
			return "이미 이만한 침대가 있다"
		if int(def.lv) != GameData.bed_lv + 1:
			return "먼저 %s부터 만들자" % GameData.BED_NAMES[int(def.lv) - 1]
	if GameData.desk_queue.size() >= GameData.desk_slots():
		return "자리가 없다 — 만드는 중인 것이 끝나야 한다"
	if not GameData.mats_ok(def.cost):
		return "재료가 모자라다"
	return ""
