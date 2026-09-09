# 능력치 창 (U): 그룹별 카드(숙련도/장비/착용 장비/약효/마음/펫)로 정돈했다.
# 글줄을 잔뜩 늘어놓는 대신 아이콘 + 짧은 숫자, 자세한 효과는 툴팁으로.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var scroll: ScrollContainer
var _refresh_timer := 0.0

# 숙련도별 아이콘 (main.tex 키 — 없으면 글자로 대신한다)
const SKILL_ICONS := {
	"farm": "icon_hoe", "fish": "icon_rod", "forest": "icon_axe",
	"mine": "icon_pickaxe", "combat": "icon_sword", "cook": "recipe",
	"beach": "forage_shell", "ranch": "egg",
}


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(285, 58)
	panel.custom_minimum_size = Vector2(390, 424)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 능력치 (%s/ESC: 닫기) -" % GameData.key_label("open_stats")
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_box.add_theme_constant_override("separation", 6)
	scroll.add_child(items_box)


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func close() -> void:
	visible = false


# 검증 하네스에서 아래쪽(장비 능력치)까지 확인하기 위해 쓴다
func scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_rebuild()


func _line(text: String, color := Color(0.9, 0.88, 0.95)) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	items_box.add_child(l)


func is_tool_unlocked_safe(tid: String) -> bool:
	return GameData.unlocked_tools.has(tid)


# ---- 카드/행 도우미 --------------------------------------------------------


# 둥근 카드 한 장 — 제목 줄 + 내용 VBox를 돌려준다
func _card(title: String, tip := "") -> VBoxContainer:
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.21, 0.18, 0.28)
	st.border_color = Color(0.36, 0.31, 0.48)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	st.content_margin_top = 6.0
	pc.add_theme_stylebox_override("panel", st)
	items_box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	pc.add_child(v)
	var head := Label.new()
	head.text = title
	head.add_theme_color_override("font_color", Color("ffd75e"))
	head.add_theme_font_size_override("font_size", 14)
	if tip != "":
		head.tooltip_text = tip
		head.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(head)
	return v


# 아이콘 + 글줄 한 행 (아이콘이 없으면 글자만)
func _row(box: VBoxContainer, icon: String, text: String,
		color := Color(0.9, 0.88, 0.95), tip := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	if tip != "":
		h.tooltip_text = tip
		h.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(h)
	if icon != "" and main != null and main.tex.has(icon):
		var tr := TextureRect.new()
		tr.texture = main.tex[icon]
		tr.custom_minimum_size = Vector2(18, 18)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tr)
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)
	return h


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	# ① 숙련도 — 아이콘 + 레벨 + 게이지. 효과는 행 툴팁으로
	var sk := _card("숙련도", "하다 보면 는다 — 반복할수록 레벨이 오른다")
	for sid in GameData.SKILL_IDS:
		var lv := GameData.skill_lv(sid)
		var s: Dictionary = GameData.skills[sid]
		var maxed := lv >= GameData.SKILL_MAX_LV
		var row := _row(sk, SKILL_ICONS.get(sid, ""),
			"%s Lv.%d" % [GameData.SKILLS[sid].name, lv],
			Color("ffd75e") if maxed else Color(0.92, 0.9, 0.96),
			"%s\n경험치 %s" % [GameData.SKILLS[sid].effect,
				"MAX" if maxed else "%d/%d" % [int(s.xp),
					int(GameData.skill_xp_needed(lv))]])
		# 이름 칸을 고정 폭으로 — 게이지가 한 줄에 나란히 선다
		(row.get_child(row.get_child_count() - 1) as Label) \
			.custom_minimum_size = Vector2(128, 0)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(170, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = 1.0 if maxed else GameData.skill_xp_needed(lv)
		bar.value = 1.0 if maxed else float(s.xp)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.08, 0.15)
		bg.border_color = Color(0.32, 0.27, 0.43)
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1.0, 0.84, 0.37) if maxed else Color(0.48, 0.83, 0.35)
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		bar.tooltip_text = "MAX" if maxed \
			else "%d/%d" % [int(s.xp), int(GameData.skill_xp_needed(lv))]
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(bar)

	# ② 도구 강화 — 대장간에서 올린 수치. 자세한 항목은 툴팁으로
	var tools := _card("도구 강화 — 대장간에서",
		"\n".join(GameData.STAT_HELP))
	for tid in GameData.TOOL_STATS:
		if not is_tool_unlocked_safe(tid):
			continue
		var st: Dictionary = GameData.tool_stats(tid)
		var lv2: int = int(GameData.tool_level.get(tid, 1))
		var parts: Array[String] = []
		for k in ["power", "reach", "stamina", "luck"]:
			parts.append("%s %s" % [GameData.STAT_NAMES[k], GameData.fmt_stat(st[k])])
		_row(tools, main.hud.TOOL_ICONS.get(tid, "") if main != null else "",
			"%s Lv.%d" % [GameData.TOOL_KOR.get(tid, tid), lv2],
			Color(0.92, 0.9, 0.96), " · ".join(parts))
	_row(tools, "icon_coin", "행운 합계 %s (도구+장비)"
		% GameData.fmt_stat(GameData.total_luck()), Color(0.75, 0.72, 0.85),
		"행운은 품질·추가 수확에 붙는다")

	# ③ 착용 장비 — 대장간 제작, 가방(I) 장비 탭에서 교체
	var gear := _card("착용 장비 — 가방(I) 장비 탭에서 교체",
		"위력=동굴 공격력 · 방어=받는 피해 · 기력 절약=도구 소모\n행운=품질·추가 수확 · 이동 속도=걷는 속도")
	for slot: String in GameData.GEAR_SLOTS:
		var gid: String = str(GameData.equipped.get(slot, ""))
		var nm: String = GameData.GEAR[gid].name if gid != "" else "비어 있음"
		var st2: String = GameData.gear_stat_text(gid) if gid != "" else ""
		_row(gear, gid if gid != "" else "",
			"%s — %s" % [GameData.GEAR_SLOT_NAMES[slot], nm],
			Color(0.92, 0.9, 0.96) if gid != "" else Color(0.6, 0.56, 0.7), st2)
	var set_txt: String = GameData.gear_set_text()
	if set_txt != "":
		_row(gear, "", "세트 효과: %s" % set_txt, Color(0.65, 0.85, 0.6))

	# ④ 오늘의 약효
	var buff: String = GameData.potion_text()
	var pot := _card("오늘의 약효")
	if buff != "":
		_row(pot, "potion_luck", buff, Color(0.7, 0.9, 0.75))
		for fid: String in GameData.FORMULA_IDS:
			var key: String = str(GameData.FORMULAS[fid].get("today", ""))
			if key != "" and GameData.has_potion(key):
				_row(pot, fid, str(GameData.FORMULAS[fid].effect),
					Color(0.75, 0.72, 0.85))
	else:
		_row(pot, "", "없음 — 집 조합대에서 물약을 만들어 마셔 보자",
			Color(0.6, 0.56, 0.7))

	# ⑤ 마음 — 대범함은 숫자 없이 단계 이름만 보여 준다(헌법 §5.1). 설명은 툴팁으로.
	# 이장이 아직 묻지 않았으면(base −1) 단계가 없다 — 어디서 알게 되는지만 일러 준다
	var mind := _card("마음")
	var stage: String = GameData.bold_stage()
	if stage == "":
		_row(mind, "", "아직 모른다 — 이장과 이야기해 보자", Color(0.6, 0.56, 0.7))
	else:
		var blurb := ""
		for st in GameData.BOLD_STAGES:
			if str(st[1]) == stage:
				blurb = str(st[2])
		_row(mind, "", stage, Color(0.92, 0.9, 0.96), blurb)
	# 직업 한 줄 — JOBS 에 없는 job 은 없는 것으로 보고 건너뛴다(D22). me 는 전부 .get 으로.
	# 채용된 날은 아직 근무 전(job_since_day 가 내일)이라 「내일부터」로 적는다
	var jd: Dictionary = GameData.JOBS.get(str(GameData.me.get("job", "")), {})
	if not jd.is_empty():
		var jdays: int = GameData.job_days()
		var since: String = "내일부터" if jdays < 0 else "%s째" % GameData.days_kor(jdays + 1)
		var sees: Dictionary = jd.get("sees", {})
		_row(mind, "", "요즘 하는 일: %s · %s" % [str(jd.get("name", "")), since],
			Color(0.65, 0.85, 0.6), str(sees.get("what", "")))

	# ⑥ 펫
	var pet := _card("펫")
	if GameData.active_pet != "":
		var pdef: Dictionary = GameData.PETS[GameData.active_pet]
		_row(pet, "", "%s — %s" % [pdef.name, pdef.passive], Color(0.65, 0.85, 0.6))
	else:
		_row(pet, "", "없음 — 목장 상회에서 입양할 수 있다", Color(0.6, 0.56, 0.7))
