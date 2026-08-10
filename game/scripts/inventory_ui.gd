# 인벤토리 (I): 도구 선택 + 보유 중인 씨앗/수확물/생산물/자원.
extends CanvasLayer

const TOOLS := ["hoe", "water", "seed", "axe", "pickaxe", "fence", "sprinkler", "rod"]
const TOOL_ICONS := {
	"hoe": "icon_hoe", "water": "icon_water", "seed": "icon_seed",
	"axe": "icon_axe", "pickaxe": "icon_pickaxe", "fence": "fence",
	"sprinkler": "sprinkler", "rod": "icon_rod",
}

const TOOL_DESC := {
	"hoe": "호미 — 잔디를 갈아 밭을 만든다",
	"water": "물뿌리개 — 작물에 물을 준다",
	"seed": "씨앗 주머니 — 밭에 씨앗을 심는다 (Tab: 종류 바꾸기)",
	"axe": "도끼 — 나무를 벤다 (동굴에서는 무기)",
	"pickaxe": "곡괭이 — 바위를 캔다",
	"fence": "울타리 — 목재 1개로 설치한다",
	"sprinkler": "스프링클러 — 아침마다 주변 4칸에 물을 준다",
	"rod": "낚싯대 — 물가에서 물고기를 낚는다",
}

var main: Node2D
var items_box: VBoxContainer
var tip_panel: PanelContainer
var tip_title: Label
var tip_body: Label
var _refresh_timer := 0.0
var _slot_normal: StyleBoxFlat
var _slot_selected: StyleBoxFlat
var _slot_moving: StyleBoxFlat
var _move_from := -1  # 우클릭으로 이동 중인 슬롯 (-1 = 없음)
var _hover_slots: Array = []  # 툴팁 판정용 [{b, tool, title, body}]
var _forced_tip := ""         # 검증 하네스에서 툴팁을 고정할 도구 id
# 탭: 한 번에 한 종류만 보여 준다 (아이템이 늘어나도 밀리지 않게)
const TABS := [
	["tool", "도구"], ["gear", "장비"], ["seed", "씨앗"], ["crop", "작물"],
	["res", "자원"], ["food", "요리"],
]
var _tab := "tool"


func _ready() -> void:
	layer = 22
	visible = false

	# 가죽 가방을 펼친 듯한 패널 (덮개 + 버클 + 재봉선)
	var panel := PanelContainer.new()
	panel.position = Vector2(203, 92)
	panel.custom_minimum_size = Vector2(555, 384)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.36, 0.2, 0.98)
	style.border_color = Color(0.29, 0.18, 0.09)
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var deco := Control.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func() -> void:
		var w := deco.size.x
		# 가방 덮개 (위로 접힌 뚜껑)
		var flap := PackedVector2Array([
			Vector2(w / 2 - 150, -12), Vector2(w / 2 + 150, -12),
			Vector2(w / 2 + 115, -40), Vector2(w / 2 - 115, -40)])
		deco.draw_colored_polygon(flap, Color(0.42, 0.27, 0.14))
		deco.draw_polyline(PackedVector2Array([
			Vector2(w / 2 - 150, -12), Vector2(w / 2 - 115, -40),
			Vector2(w / 2 + 115, -40), Vector2(w / 2 + 150, -12)]),
			Color(0.29, 0.18, 0.09), 3.0)
		# 버클
		deco.draw_rect(Rect2(w / 2 - 12, -30, 24, 16), Color(0.79, 0.57, 0.18))
		deco.draw_rect(Rect2(w / 2 - 12, -30, 24, 16), Color(0.47, 0.33, 0.1), false, 2.0)
		deco.draw_rect(Rect2(w / 2 - 2, -28, 4, 12), Color(0.47, 0.33, 0.1))
		# 재봉선 (안쪽 점선)
		var r := Rect2(Vector2(-4, -4), deco.size + Vector2(8, 8))
		var dash := 8.0
		for edge in [[r.position, Vector2(r.end.x, r.position.y)],
				[Vector2(r.position.x, r.end.y), r.end],
				[r.position, Vector2(r.position.x, r.end.y)],
				[Vector2(r.end.x, r.position.y), r.end]]:
			var a: Vector2 = edge[0]
			var b: Vector2 = edge[1]
			var n := int(a.distance_to(b) / dash)
			for i in n:
				if i % 2 == 0:
					deco.draw_line(a.lerp(b, float(i) / n),
						a.lerp(b, float(i + 0.7) / n), Color(0.85, 0.7, 0.45, 0.55), 2.0))
	panel.add_child(deco)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 가방 (I/ESC: 닫기 · U: 능력치) -"
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.65))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(525, 270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items_box)

	# 마우스를 따라다니는 아이템 툴팁 카드
	tip_panel = PanelContainer.new()
	tip_panel.visible = false
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.z_index = 10
	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.1, 0.08, 0.14, 0.98)
	tstyle.border_color = Color(1, 0.84, 0.37)
	tstyle.set_border_width_all(2)
	tstyle.set_corner_radius_all(4)
	tstyle.set_content_margin_all(8)
	tip_panel.add_theme_stylebox_override("panel", tstyle)
	var tv := VBoxContainer.new()
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_theme_constant_override("separation", 2)
	tip_panel.add_child(tv)
	tip_title = Label.new()
	tip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_title.add_theme_color_override("font_color", Color("ffd75e"))
	tv.add_child(tip_title)
	tip_body = Label.new()
	tip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_body.custom_minimum_size = Vector2(292, 0)
	tip_body.add_theme_color_override("font_color", Color(0.88, 0.85, 0.95))
	tv.add_child(tip_body)
	add_child(tip_panel)


# 도구 툴팁: 설명 + 지금 단계의 세부 능력치
# (능력치가 없는 것 — 씨앗·바구니·울타리·스프링클러 — 은 설명만 나온다)
func _tool_tip(t: String) -> Dictionary:
	var parts := str(TOOL_DESC.get(t, t)).split(" — ")
	var title: String = parts[0]
	var body: String = parts[1] if parts.size() > 1 else ""
	if GameData.TOOL_STATS.has(t):
		var lv: int = int(GameData.tool_level.get(t, 1))
		var st: Dictionary = GameData.tool_stats(t)
		title += "  Lv.%d" % lv
		body += "\n\n%s %s  ·  %s %s\n%s %s  ·  %s %s" % [
			GameData.STAT_NAMES.power, GameData.fmt_stat(st.power),
			GameData.STAT_NAMES.reach, GameData.fmt_stat(st.reach),
			GameData.STAT_NAMES.stamina, GameData.fmt_stat(st.stamina),
			GameData.STAT_NAMES.luck, GameData.fmt_stat(st.luck)]
		var gain := GameData.tool_stat_gain_text(t)
		if gain != "" and GameData.UPGRADES.has(t) \
				and lv - 1 < int(GameData.UPGRADES[t].levels.size()):
			body += "\n강화 시  %s" % gain
	return {"title": title, "body": body}


func _show_tip(title: String, body: String) -> void:
	tip_title.text = title
	tip_body.text = body
	tip_body.visible = body != ""
	tip_panel.reset_size()
	tip_panel.visible = true


func _hide_tip() -> void:
	tip_panel.visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func close() -> void:
	visible = false
	_move_from = -1
	_forced_tip = ""


# 검증 하네스용: 능력치가 있는 도구의 툴팁을 띄워 둔다
# (헤드리스에서는 마우스를 옮겨도 커서 위치가 갱신되지 않는다)
# 검증 하네스용: 탭을 바꿔 캡처한다
func show_tab(id: String) -> void:
	_forced_tip = ""
	_hide_tip()
	_tab = id
	_rebuild()


func hover_stat_tool() -> void:
	_tab = "tool"
	_rebuild()
	for h in _hover_slots:
		if GameData.TOOL_STATS.has(str(h.get("tool", ""))):
			_forced_tip = str(h.tool)
			return


func _process(delta: float) -> void:
	if not visible:
		return
	_update_hover_tip()
	if tip_panel.visible and _forced_tip == "":
		var mp := get_viewport().get_mouse_position()
		tip_panel.position = Vector2(
			minf(mp.x + 14.0, 960.0 - tip_panel.size.x - 8.0),
			minf(mp.y + 16.0, 540.0 - tip_panel.size.y - 8.0))
	elif tip_panel.visible:
		tip_panel.position = Vector2(600, 150)
	_refresh_timer -= delta
	if _refresh_timer <= 0.0 and not get_viewport().gui_is_dragging():
		_refresh_timer = 0.5
		_rebuild()


# 이벤트 대신 매 프레임 마우스 위치로 판정한다
# (리빌드로 버튼이 교체돼도 툴팁이 끊기지 않는다)
func _update_hover_tip() -> void:
	if _forced_tip != "":
		var ft := _tool_tip(_forced_tip)
		_show_tip(ft.title, ft.body)
		return
	if get_viewport().gui_is_dragging():
		_hide_tip()
		return
	var mp := get_viewport().get_mouse_position()
	for h in _hover_slots:
		var b: Button = h.b
		if is_instance_valid(b) and b.get_global_rect().has_point(mp):
			_show_tip(str(h.title), str(h.body))
			return
	_hide_tip()


func _line(text: String, color := Color(0.9, 0.88, 0.95)) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	items_box.add_child(l)


func _rebuild() -> void:
	_hover_slots.clear()
	for c in items_box.get_children():
		c.queue_free()

	if _slot_normal == null:
		_slot_normal = StyleBoxFlat.new()
		_slot_normal.bg_color = Color(0.11, 0.09, 0.16, 0.85)
		_slot_normal.border_color = Color(0.32, 0.27, 0.43)
		_slot_normal.set_border_width_all(1)
		_slot_normal.set_corner_radius_all(3)
		_slot_selected = _slot_normal.duplicate()
		_slot_selected.bg_color = Color(0.24, 0.2, 0.32, 0.95)
		_slot_selected.border_color = Color(1, 0.84, 0.37)
		_slot_selected.set_border_width_all(2)
		_slot_moving = _slot_normal.duplicate()
		_slot_moving.bg_color = Color(0.3, 0.22, 0.14, 0.95)
		_slot_moving.border_color = Color(0.45, 0.9, 0.5)
		_slot_moving.set_border_width_all(2)

	# 빠른 사용 슬롯 1~9: 드래그로 배치, 숫자키로 선택 (우클릭: 칸 비우기)
	_line("[빠른 사용 슬롯 1~9]  드래그: 배치 · 숫자키/좌클릭: 선택 · 우클릭: 빼기",
		Color(0.65, 0.85, 0.6))
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 4)
	for i in GameData.tool_slots.size():
		tool_row.add_child(_mk_tool_slot(i))
	items_box.add_child(tool_row)

	_line("소지금 %dG" % GameData.money, Color("ffd75e"))

	# 탭 줄
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	for pair in TABS:
		tabs.add_child(_mk_tab_button(str(pair[0]), str(pair[1])))
	items_box.add_child(tabs)

	var sep := ColorRect.new()
	sep.color = Color(0.29, 0.18, 0.09)
	sep.custom_minimum_size = Vector2(0, 2)
	items_box.add_child(sep)

	# 탭 내용
	if _tab == "tool":
		_line("드래그해서 위 슬롯이나 하단바에 넣기", Color(0.35, 0.22, 0.1))
		var any := false
		for t in TOOLS:
			if not GameData.is_tool_unlocked(t):
				continue
			any = true
			items_box.add_child(_mk_tool_row(t))
		if not any:
			_line("아직 가진 도구가 없다.", Color(0.35, 0.22, 0.1))
		return

	if _tab == "gear":
		_build_gear_tab()
		return

	var rows := 0
	for e in _item_entries():
		if str(e.get("tab", "res")) != _tab:
			continue
		rows += 1
		items_box.add_child(_mk_item_row(e))
	if rows == 0:
		_line("여기에 담긴 것이 없다.", Color(0.35, 0.22, 0.1))


# 장비 탭: 지금 낀 것 + 합계 능력치 + 가진 장비 (눌러서 장착/해제)
func _build_gear_tab() -> void:
	_line("[장착 중]", Color(0.65, 0.85, 0.6))
	for slot: String in GameData.GEAR_SLOTS:
		var gid: String = str(GameData.equipped.get(slot, ""))
		var slot_name: String = GameData.GEAR_SLOT_NAMES[slot]
		if gid == "":
			items_box.add_child(_mk_row(null, "%s — 없음" % slot_name, "",
				Color(0.72, 0.66, 0.6)))
			continue
		var row := _mk_row(main.tex.get(gid), "%s · %s" % [slot_name, GameData.GEAR[gid].name],
			"해제")
		row.pressed.connect(func() -> void:
			GameData.unequip_slot(slot)
			Sound.play_sfx("sfx_ui")
			_rebuild())
		items_box.add_child(row)

	# 합계 — 이 숫자가 실제로 게임에 적용된다
	var totals: Array[String] = []
	for k: String in ["power", "defense", "stamina", "luck", "speed"]:
		var v := GameData.gear_stat(k)
		if v == 0.0:
			continue
		var unit := "%" if k in ["defense", "stamina", "speed"] else ""
		totals.append("%s +%s%s" % [GameData.GEAR_STAT_NAMES[k], GameData.fmt_stat(v), unit])
	_line("합계: " + (" · ".join(totals) if not totals.is_empty() else "없음"),
		Color(0.35, 0.22, 0.1))

	_line("[가진 장비]  눌러서 장착", Color(0.65, 0.85, 0.6))
	var any := false
	for gid: String in GameData.GEAR_IDS:
		if not GameData.owned_gear.has(gid):
			continue
		any = true
		var g: Dictionary = GameData.GEAR[gid]
		var worn: bool = str(GameData.equipped.get(str(g.slot), "")) == gid
		var row2 := _mk_row(main.tex.get(gid), str(g.name),
			GameData.gear_stat_text(gid),
			Color(1, 0.88, 0.55) if worn else Color(0.96, 0.93, 0.88))
		if not worn:
			row2.pressed.connect(func() -> void:
				GameData.equip_gear(gid)
				Sound.play_sfx("sfx_ui")
				_rebuild())
		items_box.add_child(row2)
	if not any:
		_line("아직 장비가 없다. 대장간(제작 탭)에서 만들 수 있다.", Color(0.35, 0.22, 0.1))


func _mk_tab_button(id: String, label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(90, 26)
	b.add_theme_font_size_override("font_size", 15)
	var on := id == _tab
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.28, 0.19, 0.1) if on else Color(0.42, 0.29, 0.16)
	st.border_color = Color(1, 0.84, 0.37) if on else Color(0.29, 0.18, 0.09)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_color_override("font_color",
		Color(1, 0.9, 0.6) if on else Color(0.9, 0.85, 0.78))
	b.pressed.connect(func() -> void:
		_tab = id
		Sound.play_sfx("sfx_ui")
		_rebuild())
	return b


# 한 줄짜리 목록 칸 (아이콘 + 이름 + 오른쪽 값)
func _mk_row(icon: Texture2D, name_text: String, right_text: String,
		name_color := Color(0.96, 0.93, 0.88)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.35, 0.23, 0.12, 0.55)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(4)
	var st2 := st.duplicate()
	st2.bg_color = Color(0.5, 0.34, 0.18, 0.85)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st2)
	b.add_theme_stylebox_override("pressed", st2)

	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	h.offset_left = 6
	h.offset_right = -6
	b.add_child(h)

	if icon != null:
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = icon
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	else:
		# 아직 그림이 없는 아이템은 이름 첫 글자로 대신한다
		var ph := Label.new()
		ph.custom_minimum_size = Vector2(28, 28)
		ph.text = name_text.left(1)
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.add_theme_color_override("font_color", name_color)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ph)

	var nl := Label.new()
	nl.text = name_text
	nl.clip_text = true          # 이름이 길어도 창을 밀지 않는다
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 16)
	nl.add_theme_color_override("font_color", name_color)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nl)

	var rl := Label.new()
	rl.text = right_text
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rl.add_theme_font_size_override("font_size", 16)
	rl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rl)
	return b


func _mk_tool_row(t: String) -> Button:
	var st: Dictionary = GameData.tool_stats(t)
	var right := ""
	if GameData.TOOL_STATS.has(t):
		right = "위력 %s · 범위 %s" % [
			GameData.fmt_stat(st.power), GameData.fmt_stat(st.reach)]
	var lv: int = int(GameData.tool_level.get(t, 1))
	var nm: String = GameData.TOOL_KOR.get(t, t)
	if GameData.TOOL_STATS.has(t):
		nm += "  Lv.%d" % lv
	var b := _mk_row(main.hud.tool_icon(t), nm, right)
	var tip := _tool_tip(t)
	_hover_slots.append({"b": b, "tool": t, "title": tip.title, "body": tip.body})
	b.pressed.connect(func() -> void:
		main.set_tool(t)
		_rebuild())
	b.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var pv := TextureRect.new()
			pv.texture = main.hud.tool_icon(t)
			pv.custom_minimum_size = Vector2(36, 36)
			pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pv.stretch_mode = TextureRect.STRETCH_SCALE
			b.set_drag_preview(pv)
			return {"kind": "tool_pick", "tool": t},
		func(_pos: Vector2, _data: Variant) -> bool: return false,
		func(_pos: Vector2, _data: Variant) -> void: pass)
	return b


func _mk_item_row(e: Dictionary) -> Button:
	var icon: Texture2D = null
	if e.has("icon") and main.tex.has(e.icon):
		icon = main.tex[e.icon]
	var right := "x%d" % int(e.count)
	if int(e.get("sell", 0)) > 0:
		right = "x%d   %dG" % [int(e.count), int(e.sell)]
	var b := _mk_row(icon, str(e.name), right, e.get("color", Color(0.96, 0.93, 0.88)))
	_hover_slots.append({"b": b, "title": str(e.tip), "body": str(e.get("desc", ""))})
	return b


func _mk_tool_slot(slot_i: int) -> Button:
	var t: String = GameData.tool_slots[slot_i]
	var unlocked: bool = t != "" and GameData.is_tool_unlocked(t)
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.icon = main.hud.tool_icon(t) if unlocked else null
	b.add_theme_stylebox_override("normal",
		_slot_selected if (t != "" and GameData.tool == t) else _slot_normal)
	b.add_theme_stylebox_override("hover", _slot_normal)
	b.add_theme_stylebox_override("pressed", _slot_selected)
	var num := Label.new()  # 슬롯 번호 = 숫자키
	num.text = str(slot_i + 1)
	num.position = Vector2(3, 0)
	num.add_theme_font_override("font", preload("res://assets/fonts/Galmuri9.ttf"))
	num.add_theme_font_size_override("font_size", 10)
	num.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85, 0.75))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(num)
	b.pressed.connect(func() -> void:
		if unlocked:
			main.set_tool(t)
			_rebuild())
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_RIGHT \
				and GameData.tool_slots[slot_i] != "":
			GameData.tool_slots[slot_i] = ""
			Sound.play_sfx("sfx_ui")
			_rebuild())
	if unlocked:
		var tip := _tool_tip(t)
		_hover_slots.append({"b": b, "tool": t, "title": tip.title, "body": tip.body})
	b.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var tt: String = GameData.tool_slots[slot_i]
			if tt == "" or not GameData.is_tool_unlocked(tt):
				return null
			var pv := TextureRect.new()
			pv.texture = main.hud.tool_icon(tt)
			pv.custom_minimum_size = Vector2(36, 36)
			pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pv.stretch_mode = TextureRect.STRETCH_SCALE
			b.set_drag_preview(pv)
			return {"kind": "tool_slot", "from": slot_i},
		func(_pos: Vector2, data: Variant) -> bool:
			return typeof(data) == TYPE_DICTIONARY \
				and data.get("kind") in ["tool_slot", "tool_pick"],
		func(_pos: Vector2, data: Variant) -> void:
			if data.get("kind") == "tool_pick":
				_place_tool(str(data.tool), slot_i)
			else:
				_swap_slots(int(data.from), slot_i))
	return b


func _place_tool(t: String, slot_i: int) -> void:
	# 같은 도구가 다른 칸에 있으면 그 칸을 비운다 (중복 방지)
	for i in GameData.tool_slots.size():
		if i != slot_i and GameData.tool_slots[i] == t:
			GameData.tool_slots[i] = ""
	GameData.tool_slots[slot_i] = t
	Sound.play_sfx("sfx_place")
	_rebuild()


func _swap_slots(from_i: int, to_i: int) -> void:
	if from_i == to_i:
		return
	var tmp: String = GameData.tool_slots[from_i]
	GameData.tool_slots[from_i] = GameData.tool_slots[to_i]
	GameData.tool_slots[to_i] = tmp
	Sound.play_sfx("sfx_place")
	_rebuild()


func _item_entries() -> Array:
	# 각 항목: tab(어느 탭에 들어가는지) · name · count · sell · icon · tip · desc
	var out: Array = []
	if GameData.wood > 0:
		out.append({"tab": "res", "icon": "icon_wood", "name": "목재",
			"count": GameData.wood, "tip": "목재 x%d" % GameData.wood,
			"desc": "나무를 베면 얻는다. 울타리·스프링클러·축사 재료"})
	if GameData.stone > 0:
		out.append({"tab": "res", "icon": "icon_stone", "name": "석재",
			"count": GameData.stone, "tip": "석재 x%d" % GameData.stone,
			"desc": "바위를 캐면 얻는다. 스프링클러·축사 재료"})
	for id in GameData.CROP_IDS:
		if GameData.seeds[id] > 0:
			out.append({"tab": "seed", "icon": "icon_seed",
				"name": "%s 씨앗" % GameData.CROPS[id].name, "count": GameData.seeds[id],
				"tip": "%s 씨앗 x%d" % [GameData.CROPS[id].name, GameData.seeds[id]],
				"desc": "밭(호미로 간 땅)에 심자. 수확까지 %d일"
					% int(GameData.CROPS[id].grow_days)})
	for id in GameData.CROP_IDS:
		var def: Dictionary = GameData.CROPS[id]
		var n := int(GameData.produce[id])
		if n > 0:
			out.append({"tab": "crop", "icon": "mature_" + id, "name": str(def.name),
				"count": n, "sell": int(def.sell_price),
				"tip": "%s x%d (개당 %dG)" % [def.name, n, def.sell_price],
				"desc": "마을 잡화점(판매 탭)에 팔 수 있다"})
		var ns := int(GameData.produce_silver.get(id, 0))
		if ns > 0:
			out.append({"tab": "crop", "icon": "mature_" + id,
				"name": "%s (은)" % def.name, "count": ns,
				"sell": int(def.sell_price * 1.25), "color": Color(0.85, 0.88, 0.95),
				"tip": "%s (은품질) x%d" % [def.name, ns],
				"desc": "은품질 — 일반보다 비싸게 팔린다 (1.25배)"})
		var ng := int(GameData.produce_gold.get(id, 0))
		if ng > 0:
			out.append({"tab": "crop", "icon": "mature_" + id,
				"name": "%s (금)" % def.name, "count": ng,
				"sell": int(def.sell_price * 1.5), "color": Color(1.0, 0.88, 0.45),
				"tip": "%s (금품질) x%d" % [def.name, ng],
				"desc": "금품질 — 최고 품질! 가장 비싸게 팔린다 (1.5배)"})
	for id in GameData.ITEM_IDS:
		var n2 := int(GameData.items[id])
		if n2 <= 0:
			continue
		var idef: Dictionary = GameData.ITEMS[id]
		var e := {"tab": "res", "name": str(idef.name), "count": n2,
			"sell": int(idef.get("sell", 0)),
			"tip": "%s x%d" % [idef.name, n2]}
		for cand in [id, id + "_0", "forage_" + id]:
			if main.tex.has(cand):
				e["icon"] = cand
				break
		if bool(idef.get("legend", false)):
			e["color"] = Color(1.0, 0.85, 0.4)
			e["sell"] = 0
			e["desc"] = "전설의 재료 — 연구 노트의 마지막 연금술에 쓰인다 (판매 불가)"
		elif id.begins_with("fish_"):
			e["tab"] = "food"
			e["color"] = Color(0.5, 0.75, 1.0)
			e["desc"] = "낚시로 잡은 물고기"
		elif id.begins_with("dish_"):
			e["tab"] = "food"
			e["color"] = Color(1.0, 0.75, 0.4)
			e["desc"] = "요리 — 먹으면 체력을 회복한다"
		elif id.begins_with("potion_"):
			e["tab"] = "food"
			e["color"] = Color(0.75, 0.7, 1.0)
			e["desc"] = "연금술 물약 — 집 조합대에서 마신다 (%s)" \
				% str(GameData.FORMULAS[id].effect)
		elif id == "sludge":
			e["color"] = Color(0.6, 0.56, 0.5)
			e["desc"] = "조합에 실패해 남은 앙금. 팔면 푼돈은 된다"
		elif id in ["ore", "gem", "star_ore", "ghost_essence"]:
			e["color"] = Color(0.8, 0.8, 0.9)
			e["desc"] = "동굴에서 얻었다"
		elif id in ["egg", "milk"]:
			e["color"] = Color(0.95, 0.9, 0.8)
			e["desc"] = "축사 동물이 준 선물"
		else:
			e["color"] = Color(0.85, 0.82, 0.95)
			e["desc"] = "채집·수집품"
		out.append(e)
	return out
