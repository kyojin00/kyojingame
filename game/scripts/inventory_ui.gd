# 인벤토리 (I): 도구 선택 + 보유 중인 씨앗/수확물/생산물/자원.
extends CanvasLayer

const TOOLS := ["hoe", "water", "seed", "axe", "pickaxe", "fence", "sprinkler", "rod",
	"spear", "sword"]
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
	"fence": "울타리 — 목재 1개. 빈틈없이 둘러싸면 목초지가 된다\n(그 안 동물은 알아서 배부르고 생산물도 더 준다)",
	"sprinkler": "스프링클러 — 설치해 두면 주변 4칸에 계속 물을 준다",
	"rod": "낚싯대 — 물가에서 물고기를 낚는다",
}

var main: Node2D
var items_box: VBoxContainer
var tip_panel: PanelContainer
var tip_title: Label
var tip_body: Label
var tip_count: Label
var _refresh_timer := 0.0
var _slot_normal: StyleBoxFlat
var _slot_selected: StyleBoxFlat
var _slot_moving: StyleBoxFlat
var _move_from := -1  # 우클릭으로 이동 중인 슬롯 (-1 = 없음)
var _hover_slots: Array = []  # 툴팁 판정용 [{b, tool, title, body}]
var _forced_tip := ""         # 검증 하네스에서 툴팁을 고정할 도구 id
# 탭: 한 번에 한 종류만 보여 준다 (아이템이 늘어나도 밀리지 않게)
const TABS := [
	["tool", "도구"], ["gear", "장비"], ["crop", "씨앗·작물"],
	["res", "재료"], ["food", "요리"], ["place", "제작·배치"],
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
	tip_count = Label.new()          # 보유 수량 — 작게, 흐리게
	tip_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_count.add_theme_font_size_override("font_size", 12)
	tip_count.add_theme_color_override("font_color", Color(0.68, 0.65, 0.75))
	tv.add_child(tip_count)
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
	# 씨앗 주머니 — 어떤 씨앗을 몇 개 갖고 있는지 종류별로 정확히 보여 준다
	if t == "seed":
		var held: Array = []
		for id: String in GameData.CROP_IDS:
			if int(GameData.seeds[id]) > 0:
				held.append("%s 씨앗 x%d" % [GameData.CROPS[id].name,
					int(GameData.seeds[id])])
		if not held.is_empty():
			body += "\n\n" + " · ".join(held)
	return {"title": title, "body": body}


func _show_tip(title: String, body: String, count := "") -> void:
	tip_title.text = title
	tip_body.text = body
	tip_body.visible = body != ""
	tip_count.text = count
	tip_count.visible = count != ""
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
			_show_tip(str(h.title), str(h.body), str(h.get("count", "")))
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
			# 씨앗이 하나도 없으면 씨앗 주머니 항목 자체를 보여 주지 않는다
			if t == "seed" and GameData.seed_total() == 0:
				continue
			any = true
			items_box.add_child(_mk_tool_row(t))
		if not any:
			_line("아직 가진 도구가 없다.", Color(0.35, 0.22, 0.1))
		return

	if _tab == "gear":
		_build_gear_tab()
		return

	# 아이템 탭: 네모 슬롯 격자 — 같은 아이템은 한 칸에 모이고, 칸에 아이콘·수량
	_line("마우스를 올리면 설명이 보인다" +
		(" · 요리는 클릭해서 바로 먹는다" if _tab == "food" else ""), Color(0.35, 0.22, 0.1))
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	var rows := 0
	for e in _item_entries():
		if str(e.get("tab", "res")) != _tab:
			continue
		rows += 1
		grid.add_child(_mk_item_slot(e))
	items_box.add_child(grid)
	if rows == 0:
		_line("여기에 담긴 것이 없다.", Color(0.35, 0.22, 0.1))


# 장비 탭: 아바타(부위 슬롯) + 합계 능력치 + 가진 장비 (눌러서 장착/해제)
func _build_gear_tab() -> void:
	# ---- 메이플식 장비 창: 왼쪽에 사람 실루엣 + 부위별 슬롯 ----
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(0, 210)
	items_box.add_child(panel)
	var av := TextureRect.new()
	av.texture = main.tex.get(GameData.player_down_tex(false, "idle", 0.0))
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.modulate = Color(0.34, 0.32, 0.38)      # 실루엣 느낌
	av.position = Vector2(96, 6)
	av.size = Vector2(120, 196)
	panel.add_child(av)
	# 부위 슬롯 — 왼줄(모자/무기/장갑) · 오른줄(상의/하의/신발) · 아래(장신구)
	# 무기·상의(방어구)·장신구만 실제 장비 칸이고 나머지는 아직 준비 중이다
	var defs := [
		["모자", "", Vector2(30, 6)],
		["무기", "weapon", Vector2(30, 76)],
		["장갑", "", Vector2(30, 146)],
		["상의", "armor", Vector2(238, 6)],
		["하의", "", Vector2(238, 76)],
		["신발", "", Vector2(238, 146)],
		["장신구", "charm", Vector2(134, 158)],
	]
	for sd: Array in defs:
		panel.add_child(_mk_gear_slot(str(sd[0]), str(sd[1]), sd[2]))
	# 세트 시너지 — 같은 테마를 여러 부위 차면 보너스가 얹힌다
	var set_txt := GameData.gear_set_text()
	if set_txt != "":
		_line("세트 효과: " + set_txt, Color(0.65, 0.5, 0.2))

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


# 아바타 옆 부위 슬롯 한 칸 — 실제 장비 칸은 장착물이 보이고 눌러서 해제,
# 아직 준비 안 된 부위는 어둡게 잠겨 있다
func _mk_gear_slot(label: String, slot_id: String, pos: Vector2) -> Control:
	var wrap := Control.new()
	wrap.position = pos
	wrap.custom_minimum_size = Vector2(66, 64)
	var b := Button.new()
	b.custom_minimum_size = Vector2(50, 50)
	b.position = Vector2(8, 0)
	b.focus_mode = Control.FOCUS_NONE
	var gid := str(GameData.equipped.get(slot_id, "")) if slot_id != "" else ""
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.32, 0.22, 0.12) if slot_id != "" else Color(0.24, 0.18, 0.12)
	st.border_color = Color(1, 0.84, 0.37) if gid != "" \
		else (Color(0.55, 0.42, 0.25) if slot_id != "" else Color(0.32, 0.26, 0.18))
	st.set_border_width_all(2)
	st.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	if gid != "":
		b.icon = main.tex.get(gid)
		b.expand_icon = true
		b.tooltip_text = "%s — 눌러서 해제\n%s" % [GameData.GEAR[gid].name,
			GameData.gear_stat_text(gid)]
		b.pressed.connect(func() -> void:
			GameData.unequip_slot(slot_id)
			Sound.play_sfx("sfx_ui")
			_rebuild())
	elif slot_id != "":
		b.tooltip_text = "%s 칸 — 아래 [가진 장비]에서 장착" % label
	else:
		b.tooltip_text = "%s 칸 — 아직 준비 중" % label
		b.disabled = true
	wrap.add_child(b)
	var l := Label.new()
	l.text = label
	l.position = Vector2(0, 48)
	l.custom_minimum_size = Vector2(66, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color",
		Color(0.85, 0.78, 0.66) if slot_id != "" else Color(0.55, 0.5, 0.42))
	wrap.add_child(l)
	return wrap


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
	elif t == "seed":
		# 뭉뚱그리지 않는다 — 지금 골라 든 씨앗의 정확한 이름과 개수
		var sid := GameData.current_seed_id()
		if sid != "":
			right = "%s 씨앗 x%d" % [GameData.CROPS[sid].name,
				int(GameData.seeds[sid])]
	var lv: int = int(GameData.tool_level.get(t, 1))
	var nm: String = GameData.TOOL_KOR.get(t, t)
	if GameData.TOOL_STATS.has(t):
		nm += "  Lv.%d" % lv
	var b := _mk_row(main.hud.tool_icon(t), nm, right)
	var tip := _tool_tip(t)
	_hover_slots.append({"b": b, "tool": t, "title": tip.title, "body": tip.body})
	b.pressed.connect(func() -> void:
		main.toolwork.set_tool(t)
		_rebuild())
	# 더블 클릭: 비어 있는 가장 앞 번호 슬롯에 자동 장착
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.double_click \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			_auto_equip(t))
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


# 네모 아이템 슬롯: 아이콘 + 수량 숫자. 마우스를 올리면 이름/설명/보유 수가 보인다.
func _mk_item_slot(e: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(46, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st: StyleBoxFlat = _slot_normal.duplicate()
	st.set_content_margin_all(5)
	var st2: StyleBoxFlat = st.duplicate()
	st2.border_color = Color(1, 0.84, 0.37)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st2)
	b.add_theme_stylebox_override("pressed", st2)
	if e.has("icon") and main.tex.has(e.icon):
		b.icon = main.tex[e.icon]
	else:
		# 아직 그림이 없는 아이템은 이름 첫 글자로 대신한다
		b.text = str(e.name).left(1)
		b.add_theme_color_override("font_color", e.get("color", Color(0.96, 0.93, 0.88)))

	var num := Label.new()      # 보유 수량 — 오른쪽 아래 작은 숫자
	num.text = str(int(e.count))
	num.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	num.offset_left = -36
	num.offset_top = -15
	num.offset_right = -2
	num.offset_bottom = -1
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.add_theme_font_override("font", preload("res://assets/fonts/Galmuri9.ttf"))
	num.add_theme_font_size_override("font_size", 10)
	num.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	num.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.14))
	num.add_theme_constant_override("outline_size", 3)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(num)

	var body := str(e.get("desc", ""))
	_hover_slots.append({"b": b, "title": str(e.name), "body": body,
		"count": "보유 중: %d개" % int(e.count)})

	# 요리는 슬롯을 눌러 그 자리에서 바로 먹는다
	var eat_id := str(e.get("eat", ""))
	if eat_id != "":
		b.pressed.connect(func() -> void:
			main.doing.do_eat(eat_id)
			_rebuild())
	# 집터는 슬롯을 눌러 바라보는 자리에 설치한다 (스토리 3)
	if bool(e.get("place", false)):
		b.pressed.connect(func() -> void:
			visible = false
			main.story.request_place_house())
	# 수납 상자 — 집 안에서만 놓을 수 있다
	if bool(e.get("storage", false)):
		b.pressed.connect(func() -> void:
			visible = false
			main.village.use_storage_box())
	# 쓰레기통도 슬롯을 눌러 설치한다 (집 안=세간 · 바깥=바라보는 칸)
	if bool(e.get("bin", false)):
		b.pressed.connect(func() -> void:
			visible = false
			main.village.use_trash_bin())
	# 이주 희망 편지 — 다시 읽고 수락한다
	if bool(e.get("letter", false)):
		b.pressed.connect(func() -> void:
			visible = false
			main.story.open_move_letter())
	# 이사 신청 편지 — 읽고 수락/거절한다
	if bool(e.get("settle", false)):
		b.pressed.connect(func() -> void:
			visible = false
			main.story.open_settle_letter())
	# 작별 편지 — 떠난 주민의 마지막 인사
	if bool(e.get("farewell", false)):
		b.pressed.connect(func() -> void:
			visible = false
			main.story.open_farewell_letter())
	# 씨앗 — 누르면 그 씨앗을 골라 들고, 드래그하면 씨앗 주머니를 슬롯에 건다
	var seed_id := str(e.get("seed_pick", ""))
	if seed_id != "":
		b.pressed.connect(func() -> void:
			_pick_seed(seed_id))
		b.set_drag_forwarding(
			func(_pos: Vector2) -> Variant:
				GameData.seed_index = maxi(0, GameData.owned_seed_ids().find(seed_id))
				var pv := TextureRect.new()
				pv.texture = b.icon
				pv.custom_minimum_size = Vector2(36, 36)
				pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pv.stretch_mode = TextureRect.STRETCH_SCALE
				b.set_drag_preview(pv)
				return {"kind": "tool_pick", "tool": "seed"},
			func(_pos: Vector2, _data: Variant) -> bool: return false,
			func(_pos: Vector2, _data: Variant) -> void: pass)
	# 레시피 두루마리 — 「배우기」를 눌러야 진짜로 익힌다
	var learn_id := str(e.get("learn", ""))
	if learn_id != "":
		b.pressed.connect(func() -> void:
			main.dialog.open("%s 레시피" % GameData.recipe_display_name(learn_id),
				"두루마리를 펼쳐 읽는다.\n이 레시피를 배울까?", [
				["배우기", func() -> void:
					m_learn(learn_id)],
				["나중에", null],
			]))
	return b


# 씨앗 슬롯 클릭 → 그 씨앗을 고르고 씨앗 주머니를 든다 (바로 파종 가능)
func _pick_seed(sid: String) -> void:
	var idx: int = GameData.owned_seed_ids().find(sid)
	if idx < 0:
		return
	GameData.seed_index = idx
	# 씨앗 주머니가 빠른 슬롯에 없으면 빈 칸에 자동 장착부터
	if GameData.is_tool_unlocked("seed") and not GameData.tool_slots.has("seed"):
		for i in GameData.tool_slots.size():
			if GameData.tool_slots[i] == "":
				GameData.tool_slots[i] = "seed"
				Sound.play_sfx("sfx_place")
				break
	main.toolwork.set_tool("seed")
	if GameData.tool == "seed":
		Sound.play_sfx("sfx_ui")
		main.hud.show_message("%s 씨앗을 들었다 — 호미로 간 밭에서 클릭/E로 심는다."
			% GameData.CROPS[sid].name)
	_rebuild()


func m_learn(rid: String) -> void:
	main.dialog.close()
	if GameData.learn_recipe(rid):
		Sound.play_sfx("sfx_catch")
		main.hud.show_message("%s 레시피를 배웠다! 조리대/제작대에 칸이 생겼다."
			% GameData.recipe_display_name(rid))
	_rebuild()


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
			main.toolwork.set_tool(t)
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


# 더블 클릭 자동 장착: 이미 걸려 있으면 그 칸을 알려 주고,
# 아니면 비어 있는 가장 앞 번호 슬롯에 넣는다
func _auto_equip(t: String) -> void:
	for i in GameData.tool_slots.size():
		if GameData.tool_slots[i] == t:
			main.toolwork.set_tool(t)
			main.hud.show_message("%s은(는) 이미 %d번 슬롯에 있다." % [GameData.TOOL_KOR.get(t, t), i + 1])
			_rebuild()
			return
	for i in GameData.tool_slots.size():
		if GameData.tool_slots[i] == "":
			GameData.tool_slots[i] = t
			Sound.play_sfx("sfx_place")
			main.hud.show_message("%s을(를) %d번 슬롯에 장착했다. (숫자키 %d)" %
				[GameData.TOOL_KOR.get(t, t), i + 1, i + 1])
			_rebuild()
			return
	main.hud.show_message("빈 슬롯이 없다. 우클릭으로 칸을 비우거나 드래그로 바꾸자.")


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
		out.append({"tab": "res", "icon": "icon_wood", "name": "목재", "count": GameData.wood, "tip": "목재 x%d" % GameData.wood,
			"desc": "나무를 베면 얻는다. 울타리·스프링클러·축사 재료"})
	if GameData.stone > 0:
		out.append({"tab": "res", "icon": "icon_stone", "name": "석재", "count": GameData.stone, "tip": "석재 x%d" % GameData.stone,
			"desc": "바위를 캐면 얻는다. 스프링클러·축사 재료"})
	for id in GameData.CROP_IDS:
		if GameData.seeds[id] > 0:
			out.append({"tab": "crop", "icon": "icon_seed", "seed_pick": id,
				"name": "%s 씨앗" % GameData.CROPS[id].name, "count": GameData.seeds[id],
				"tip": "%s 씨앗 x%d" % [GameData.CROPS[id].name, GameData.seeds[id]],
				"desc": "밭(호미로 간 땅)에 심자. 수확까지 %d일\n클릭: 이 씨앗 들기 · 드래그: 빠른 슬롯 장착"
					% int(GameData.CROPS[id].grow_days)})
	for id in GameData.CROP_IDS:
		var def: Dictionary = GameData.CROPS[id]
		var n := int(GameData.produce[id])
		if n > 0:
			out.append({"tab": "crop", "icon": "mature_" + id, "name": str(def.name),
				"count": n, "sell": int(def.sell_price),
				"tip": "%s x%d" % [def.name, n],
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
			# 물고기는 요리 재료다 — 요리 칸이 아니라 재료 칸에 정렬
			e["color"] = Color(0.5, 0.75, 1.0)
			e["desc"] = "낚시로 잡은 물고기"
			if main.note_ui != null:      # 도감과 같은 문구 — 언제 무는지
				e["desc"] = "낚시로 잡았다 — %s" % main.note_ui._fish_desc(id)
		elif id.begins_with("dish_"):
			e["tab"] = "food"
			e["color"] = Color(1.0, 0.75, 0.4)
			e["desc"] = "요리 — 먹으면 체력 +%d" % int(GameData.RECIPES[id].energy)
			e["eat"] = id
		elif id == "water_life":
			e["color"] = Color(0.55, 0.8, 1.0)
			e["desc"] = "한 분야를 만렙까지 갈고닦은 증표 — 맑게 빛나는 물이다 (%d/%d)" \
				% [n2, GameData.ENDING_SKILLS.size()]
		elif id.begins_with("relic_"):
			e["color"] = Color(0.95, 0.75, 0.85)
			e["desc"] = "할머니의 유품 — 세월이 묻어 있지만 소중히 닦여 있다\n(%d/%d · 연구 노트(N)에 힌트가 있다)" \
				% [GameData.relics_owned(), GameData.RELICS.size()]
		elif id == "grandpa_seed":
			e["color"] = Color(0.72, 0.92, 0.7)
			e["desc"] = "할아버지가 평생의 연구 끝에 남긴 씨앗 한 알.\n내일 아침, 밭에 심어 주자"
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
			e["desc"] = "축사 동물이 준 선물. 요리 재료로도 쓴다"
		elif id == "flour":
			e["color"] = Color(0.96, 0.94, 0.88)
			e["desc"] = "밀을 곱게 빻은 가루 — 빵 재료 (조리대)"
		elif id == "weed":
			e["desc"] = "숲에서 채집할 수 있는 풀. 빗자루 재료 (제작대)"
		elif id == "forage_shell":
			e["desc"] = "해변 모래밭에 밀려온 조개. 시간이 지나면 또 밀려온다"
		elif id == "forage_coral":
			e["desc"] = "파도가 실어 온 산호 가지 — 해변에서 드물게 보인다"
		elif id == "forage_trash":
			e["desc"] = "파도에 밀려온 젖은 비닐봉지. 해변 노점에서 팔면 치워 준다"
		elif id == "forage_glass":
			e["desc"] = "모래에 반쯤 묻혀 있던 유리 조각 — 파도에 매끈하게 닳았다"
		elif id == "forage_ring":
			e["desc"] = "파도에 밀려온 녹슨 금속 고리"
		elif id == "forage_relic":
			e["desc"] = "알 수 없는 무늬가 새겨진 옛 돌조각 — 아주 드물게 밀려온다"
		elif id == "bait":
			e["desc"] = "낚시 미끼 — 낚싯대를 던질 때 하나씩 쓴다. 입질이 훨씬 빨라진다"
		elif id == "housing_kit":
			e["tab"] = "place"   # 제작·배치 탭 — 재료 칸과 섞이지 않는다
			e["desc"] = "빈 집터를 마련한다 — 클릭하면 자리 고르기가 시작된다.\n(초록=가능 · 좌클릭 설치) 빈 집터가 있어야 이주 편지를 수락할 수 있다"
			e["place"] = true
		elif id == "move_letter":
			e["tab"] = "place"
			e["icon"] = "icon_letter"
			e["desc"] = "마을로 이사 오고 싶다는 편지 — 클릭해서 다시 읽고 수락한다"
			e["letter"] = true
		elif id == "settle_letter":
			e["tab"] = "place"
			e["icon"] = "icon_letter"
			e["desc"] = "새 이웃이 보낸 이사 신청 편지 — 클릭해서 읽고 수락/거절한다"
			e["settle"] = true
		elif id == "farewell_letter":
			e["tab"] = "place"
			e["icon"] = "icon_letter"
			e["desc"] = "떠난 주민이 남긴 짧은 편지 — 클릭해서 읽는다"
			e["farewell"] = true
		elif id == "storage_box":
			e["tab"] = "place"
			e["desc"] = "집 안에 놓는 작은 창고 — 집 안에서 클릭해 설치한다"
			e["storage"] = true
		elif id == "trash_bin":
			e["tab"] = "place"
			e["desc"] = "24시간 무인 판매함 (제값의 80%) — 놓을 곳을 바라보고 클릭"
			e["bin"] = true
		elif id == "arrow":
			e["desc"] = "몬스터가 떨어뜨린 화살 — 도감 「풋내기 모험가의 무기」 수집품"
		elif id == "crystal":
			e["desc"] = "깊은 층 광맥에 섞여 있던 수정 — 컬렉션 「동굴의 광물」 표본"
		elif id == "cave_moss":
			e["desc"] = "축축한 이끼방에서 떼어 온 이끼 — 컬렉션 「동굴의 생명」 표본"
		elif id == "glow_shroom":
			e["desc"] = "어둠 속에서 은은히 빛나는 버섯 — 컬렉션 「동굴의 생명」 표본"
		elif id == "rock_wedge":
			e["desc"] = "무쇠가 벼려 준 착암 쐐기 — 무너진 바위를 결대로 쪼갠다.\n동굴 깊은 곳의 막힌 수맥을 뚫는 데 쓴다"
		elif id == "spring_water":
			e["desc"] = "되살아난 수맥에서 담은 따뜻한 물 한 병 — 묘연에게 보여주자"
		elif id == "old_box":
			e["desc"] = "바닷물에 오래 잠겨 있던 낡은 작은 상자 — 녹슬어 열 수 없다.\n억지로 열면 안의 것까지 상한다... 연금술사라면 방법을 알 텐데"
		elif id == "broom":
			e["desc"] = "집 안의 먼지를 쓸어 낸다 — 집 조리대 자리에서 E"
		elif id in ["nail", "cloth", "rope", "hinge"]:
			e["desc"] = "가구 부품 — 집 제작대에서 쓴다"
		elif id in ["bouquet", "wedding_ring"]:
			e["desc"] = "마음을 전하는 물건 — 아끼는 주민에게 건네자"
		else:
			e["color"] = Color(0.85, 0.82, 0.95)
			e["desc"] = "채집·수집품"
		out.append(e)

	# 레시피 두루마리 — 사거나 받은 레시피. 클릭해 「배우기」를 눌러야
	# 조리대/제작대에 칸이 생긴다 (제작·배치 탭)
	for rid: String in GameData.recipe_items:
		var rn := GameData.recipe_display_name(rid)
		out.append({"tab": "place", "icon": "recipe",
			"name": "%s 레시피" % rn, "count": int(GameData.recipe_items[rid]),
			"tip": "%s 레시피 x%d" % [rn, int(GameData.recipe_items[rid])],
			"desc": "클릭해서 배우면 조리대/제작대에서 만들 수 있다",
			"learn": rid})
	return out
