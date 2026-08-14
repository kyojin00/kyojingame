# 퀘스트 창 (Q): 픽셀아트 두루마리 — 메이플식 좌우 이분할.
# 왼쪽 = 진행 중인 퀘스트 목록(메인/서브/마을 생활 안내/오늘의 의뢰),
# 오른쪽 = 고른 퀘스트의 상세(준 사람 일러스트 · 명칭 · 목표 · 설명 · 보상).
# 수락한 퀘스트는 전부 GameData.quest_catalog()에서 나오므로 하나도 빠지지 않는다.
extends CanvasLayer

# 양피지 위 글자 색
const COL_TEXT := Color(0.32, 0.2, 0.08)
const COL_HEAD := Color(0.27, 0.45, 0.16)
const COL_DONE := Color(0.45, 0.55, 0.38)
const COL_NOW := Color(0.72, 0.45, 0.06)
const COL_DIM := Color(0.55, 0.48, 0.38)
const COL_SUB := Color(0.5, 0.42, 0.3)

# 분류 순서와 이름표 — 「새로운 주민의 이사」는 cat="main"(메인 스토리 3)
const CAT_ORDER := ["main", "sub", "guide", "daily", "info"]
const CAT_NAMES := {
	"main": "메인 스토리", "sub": "서브 퀘스트",
	"guide": "마을 생활 안내", "daily": "오늘의 의뢰", "info": "마을 소식",
}
const CAT_COLORS := {
	"main": Color(0.62, 0.32, 0.05), "sub": Color(0.27, 0.45, 0.16),
	"guide": Color(0.2, 0.42, 0.5), "daily": Color(0.5, 0.35, 0.55),
	"info": Color(0.55, 0.48, 0.38),
}

var main: Node2D
var list_box: VBoxContainer      # 왼쪽 목록
var detail_box: VBoxContainer    # 오른쪽 상세
var _refresh_timer := 0.0
var _sel := ""                   # 선택한 항목 id ("" = 자동)


func _ready() -> void:
	layer = 22
	visible = false

	# 픽셀아트 두루마리: 양피지 몸통 + 위아래 말린 축.
	var panel := PanelContainer.new()
	panel.position = Vector2(130, 20)
	panel.custom_minimum_size = Vector2(700, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.85, 0.66)
	style.border_color = Color(0.55, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_content_margin_all(26)
	style.content_margin_top = 30.0
	style.content_margin_bottom = 30.0
	panel.add_theme_stylebox_override("panel", style)
	# 말린 축은 패널 자체에 그린다 (자식은 content margin 안쪽으로 밀리므로)
	panel.draw.connect(func() -> void:
		var w := panel.size.x
		var h := panel.size.y
		var edge := Color(0.55, 0.4, 0.2)
		var roll := Color(0.82, 0.71, 0.5)
		var roll_dk := Color(0.62, 0.49, 0.3)
		# 좌우 가장자리 음영 (말려 있던 자국)
		panel.draw_rect(Rect2(3, 16, 6, h - 32), Color(0.85, 0.75, 0.55))
		panel.draw_rect(Rect2(w - 9, 16, 6, h - 32), Color(0.85, 0.75, 0.55))
		# 좌/우 칸 사이 세로 접힘 줄
		panel.draw_rect(Rect2(238, 52, 2, h - 76), Color(0.78, 0.66, 0.46))
		# 위/아래 말린 축
		for ry in [0.0, h - 16.0]:
			panel.draw_rect(Rect2(5, ry + 4, w - 10, 9), roll)
			panel.draw_rect(Rect2(5, ry + 4, w - 10, 3), Color(0.9, 0.8, 0.6))
			panel.draw_rect(Rect2(5, ry + 10, w - 10, 3), roll_dk)
			panel.draw_rect(Rect2(5, ry + 4, w - 10, 9), edge, false, 1.0)
			# 양쪽으로 살짝 튀어나온 말린 끝
			panel.draw_rect(Rect2(0, ry + 3, 7, 11), roll_dk)
			panel.draw_rect(Rect2(0, ry + 3, 7, 11), edge, false, 1.0)
			panel.draw_rect(Rect2(w - 7, ry + 3, 7, 11), roll_dk)
			panel.draw_rect(Rect2(w - 7, ry + 3, 7, 11), edge, false, 1.0))
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 퀘스트 (%s/ESC: 닫기) -" % GameData.key_label("open_quest")
	title.add_theme_color_override("font_color", Color(0.5, 0.3, 0.08))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)

	# 왼쪽: 진행 중 퀘스트 목록
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(200, 400)
	lscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(lscroll)
	list_box = VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(196, 0)
	list_box.add_theme_constant_override("separation", 3)
	lscroll.add_child(list_box)

	# 오른쪽: 고른 퀘스트 상세
	var rscroll := ScrollContainer.new()
	rscroll.custom_minimum_size = Vector2(420, 400)
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(rscroll)
	detail_box = VBoxContainer.new()
	detail_box.custom_minimum_size = Vector2(416, 0)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 4)
	rscroll.add_child(detail_box)


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_rebuild()


# ---- 목록 만들기 ----------------------------------------------------------


# 카탈로그 + 정보 항목(아직 수락 안 한 의뢰, 계절 축제)을 한 줄로 편다
func _entries() -> Array:
	var out: Array = []
	# 메인 스토리는 「지금 진행 중인 하나」만 보여 준다 — 완료했거나
	# 아직 닿지 않은 회차는 목록에서 숨긴다 (서브퀘는 전부 그대로)
	var main_shown := false
	for q: Dictionary in GameData.quest_catalog():
		var e := q.duplicate()
		if not e.has("cat"):
			e["cat"] = "sub"
		if str(e.cat) == "main":
			if main_shown:
				continue
			main_shown = true
		out.append(e)
	# 마을 소식은 마을에 도착한 뒤에야 열린다 (숲길 진행 중에는 숨김)
	if GameData.story_phase != "done":
		return out
	# 게시판에 붙어 있는(아직 수락 전) 의뢰 — 정보로 보여 준다
	if GameData.quest_line() == "" and not GameData.quest_offers.is_empty():
		out.append({"id": "info_offers", "cat": "info", "title": "게시판의 의뢰",
			"obj": "의뢰 게시판(E)에서 하나를 골라 수락하자", "npc": "",
			"desc": "오늘 게시판에 의뢰 %d건이 붙어 있다. 하나만 고를 수 있다."
				% GameData.quest_offers.size(), "reward": ""})
	# 계절 축제 안내
	out.append({"id": "info_fest", "cat": "info", "title": "계절 축제",
		"obj": "", "npc": "chief", "desc": "", "reward": ""})
	return out


func _line(box: VBoxContainer, text: String, color := COL_TEXT,
		size := 0) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	box.add_child(l)


func _rebuild() -> void:
	for c in list_box.get_children():
		c.queue_free()
	for c in detail_box.get_children():
		c.queue_free()

	var entries := _entries()
	# 선택이 비었거나(처음) 고른 퀘스트가 끝나서 사라졌으면 맨 앞으로
	var ids := entries.map(func(e: Dictionary) -> String: return str(e.id))
	if _sel == "" or _sel not in ids:
		_sel = str(GameData.tracked_pick) if GameData.tracked_pick in ids \
			else (str(entries[0].id) if not entries.is_empty() else "")

	# 왼쪽 목록 — 분류별로 묶는다
	for cat: String in CAT_ORDER:
		var group: Array = entries.filter(
			func(e: Dictionary) -> bool: return str(e.cat) == cat)
		if group.is_empty():
			continue
		var head := Label.new()
		head.text = "[%s]" % CAT_NAMES[cat]
		head.add_theme_font_size_override("font_size", 13)
		head.add_theme_color_override("font_color", CAT_COLORS[cat])
		list_box.add_child(head)
		for e: Dictionary in group:
			list_box.add_child(_mk_list_btn(e))

	if entries.is_empty():
		_line(list_box, "진행 중인 퀘스트가 없다.", COL_DIM)
		return

	# 오른쪽 상세
	for e: Dictionary in entries:
		if str(e.id) == _sel:
			_build_detail(e)
			break


func _mk_list_btn(e: Dictionary) -> Button:
	var on := str(e.id) == _sel
	var pinned := GameData.tracked_pick == str(e.id)
	var b := Button.new()
	b.text = ("📌 " if pinned else "") + str(e.title)
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(192, 24)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.85, 0.72, 0.45) if on else Color(0.9, 0.83, 0.64)
	st.border_color = Color(0.72, 0.45, 0.06) if on else Color(0.72, 0.61, 0.42)
	st.set_border_width_all(2 if on else 1)
	st.set_corner_radius_all(5)
	st.content_margin_left = 8.0
	st.content_margin_right = 6.0
	st.content_margin_top = 3.0
	st.content_margin_bottom = 3.0
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.pressed.connect(func() -> void:
		_sel = str(e.id)
		Sound.play_sfx("sfx_ui")
		_rebuild())
	return b


# ---- 오른쪽 상세 ----------------------------------------------------------


func _build_detail(e: Dictionary) -> void:
	var cat := str(e.get("cat", "sub"))

	# 위: 준 사람 일러스트 + (분류 · 제목)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	detail_box.add_child(top)

	var pt := _portrait(str(e.get("npc", "")))
	if pt != null:
		var tr := TextureRect.new()
		tr.texture = pt
		tr.custom_minimum_size = Vector2(84, 84)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(tr)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 2)
	top.add_child(tv)

	# 분류 칩 — 메인 스토리는 회차까지 적는다 (예: 메인 스토리 3)
	var chip := Label.new()
	chip.text = "「%s」" % str(e.get("ep", CAT_NAMES.get(cat, "퀘스트")))
	chip.add_theme_font_size_override("font_size", 13)
	chip.add_theme_color_override("font_color", CAT_COLORS.get(cat, COL_SUB))
	tv.add_child(chip)

	var big := Label.new()
	big.text = str(e.title)
	big.add_theme_font_size_override("font_size", 23)
	big.add_theme_color_override("font_color", Color(0.42, 0.24, 0.06))
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(big)

	if str(e.get("npc", "")) != "":
		var giver := Label.new()
		giver.text = "— %s" % _npc_name(str(e.npc))
		giver.add_theme_font_size_override("font_size", 12)
		giver.add_theme_color_override("font_color", COL_SUB)
		tv.add_child(giver)

	_line(detail_box, "--------------------------------------------",
		Color(0.75, 0.63, 0.42))

	# 정보 항목은 자기 본문을 그린다
	if str(e.id) == "info_fest":
		_build_fest_detail()
		return
	if str(e.id) == "info_offers":
		_line(detail_box, str(e.desc), COL_SUB)
		_line(detail_box, "")
		for o: Dictionary in GameData.quest_offers:
			_line(detail_box, "· [%s] %s %d개 — %dG" % [o.label,
				GameData.item_display_name(str(o.item)), int(o.qty),
				int(o.reward)], COL_TEXT)
		_line(detail_box, "")
		_line(detail_box, str(e.obj), COL_NOW)
		return

	# 목표
	_line(detail_box, "📍 목표", COL_HEAD, 14)
	_line(detail_box, "  " + str(e.obj), COL_NOW)
	_extra_progress(str(e.id))
	_line(detail_box, "")

	# 설명
	if str(e.get("desc", "")) != "":
		_line(detail_box, "이야기", COL_HEAD, 14)
		_line(detail_box, "  " + str(e.desc), COL_SUB)
		_line(detail_box, "")

	# 보상
	if str(e.get("reward", "")) != "":
		_line(detail_box, "보상", COL_HEAD, 14)
		_line(detail_box, "  " + str(e.reward), COL_TEXT)
		_line(detail_box, "")

	# 미니창 고정 (핀) — 서브퀘 위주로 놀고 싶을 때
	var pinned := GameData.tracked_pick == str(e.id)
	var pin := Button.new()
	pin.text = "📌 미니창 고정 해제 (자동으로)" if pinned \
		else "📌 이 퀘스트를 미니창에 고정"
	pin.focus_mode = Control.FOCUS_NONE
	pin.add_theme_font_size_override("font_size", 13)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.85, 0.72, 0.45) if pinned else Color(0.88, 0.8, 0.62)
	st.border_color = Color(0.72, 0.45, 0.06)
	st.set_border_width_all(2)
	st.set_corner_radius_all(5)
	st.content_margin_left = 10.0
	st.content_margin_right = 10.0
	st.content_margin_top = 3.0
	st.content_margin_bottom = 3.0
	pin.add_theme_stylebox_override("normal", st)
	pin.add_theme_stylebox_override("hover", st)
	pin.add_theme_stylebox_override("pressed", st)
	pin.add_theme_color_override("font_color", COL_TEXT)
	pin.add_theme_color_override("font_hover_color", COL_TEXT)
	pin.pressed.connect(func() -> void:
		GameData.tracked_pick = "" if pinned else str(e.id)
		Sound.play_sfx("sfx_ui")
		_rebuild())
	detail_box.add_child(pin)


# 실시간 진행 수치 — 재료/납품 개수는 가방과 연동해 0.5초마다 갱신된다
func _extra_progress(id: String) -> void:
	if id == "stall":
		var w_have := mini(GameData.wood, GameData.STALL_WOOD)
		var s_have := mini(int(GameData.items.get("forage_shell", 0)),
			GameData.STALL_SHELLS)
		var w_ok := w_have >= GameData.STALL_WOOD
		var s_ok := s_have >= GameData.STALL_SHELLS
		_line(detail_box, "    목재  %d / %d%s" % [w_have, GameData.STALL_WOOD,
			"  ✓" if w_ok else ""], COL_DONE if w_ok else COL_SUB)
		_line(detail_box, "    조개  %d / %d%s" % [s_have, GameData.STALL_SHELLS,
			"  ✓" if s_ok else ""], COL_DONE if s_ok else COL_SUB)
	elif id == "errand" and not GameData.quest.is_empty():
		var q: Dictionary = GameData.quest
		var have := GameData.ingredient_count(str(q.item))
		var ok := have >= int(q.qty)
		_line(detail_box, "    보유 %d / %d%s" % [mini(have, int(q.qty)),
			int(q.qty), "  ✓ 게시판에서 납품하자!" if ok else ""],
			COL_DONE if ok else COL_SUB)


# 계절 축제 상세 (옛 Q창의 축제 절을 그대로 옮겨 왔다)
func _build_fest_detail() -> void:
	var ft: Dictionary = GameData.festival_today()
	if ft.is_empty():
		var next_name := ""
		var next_in := 0
		for i in range(1, GameData.DAYS_PER_SEASON * 4 + 1):
			var f2: Dictionary = GameData.festival_of_day(GameData.day + i)
			if not f2.is_empty():
				next_name = str(f2.name)
				next_in = i
				break
		if next_name != "":
			_line(detail_box, "다음 축제: %s — %d일 뒤" % [next_name, next_in],
				COL_SUB)
	else:
		_line(detail_box, "오늘은 %s! (9시~18시, %s)" % [ft.name,
			"낚시터" if str(ft.place) == "pier" else "마을 광장"], COL_NOW)
		_line(detail_box, "  %s" % ft.goal, COL_SUB)
		if GameData.fest_done:
			_line(detail_box, "  참가 완료!", COL_DONE)
		else:
			_line(detail_box, "  이장에게 「축제 이야기」로 진행한다.", COL_SUB)
	_line(detail_box, "")
	for sid in [GameData.SPRING, GameData.SUMMER, GameData.FALL, GameData.WINTER]:
		var f3: Dictionary = GameData.FESTIVALS[sid]
		var seen: bool = GameData.fest_history.has(str(f3.id))
		_line(detail_box, "%s %s %d일 — %s" % ["V" if seen else "-",
			GameData.SEASON_NAMES[sid], int(f3.day), f3.name],
			COL_DONE if seen else COL_DIM)


# ---- 도우미 ----------------------------------------------------------------


func _portrait(npc: String) -> Texture2D:
	if npc == "" or main == null:
		return null
	for cand in ["npc_%s_portrait_normal" % npc, "npc_%s_portrait_happy" % npc]:
		if main.tex.has(cand):
			return main.tex[cand]
	return null


func _npc_name(npc: String) -> String:
	return {"postman": "우체부 아저씨", "chief": "이장님", "fisher": "낚시꾼",
		"explorer": "무진", "merchant": "민지"}.get(npc, npc)
