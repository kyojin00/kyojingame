# 퀘스트 창 (Q): 픽셀아트 두루마리 — 메인 스토리 + 오늘의 의뢰 + 장기 목표.
extends CanvasLayer

# 양피지 위 글자 색
const COL_TEXT := Color(0.32, 0.2, 0.08)
const COL_HEAD := Color(0.27, 0.45, 0.16)
const COL_DONE := Color(0.45, 0.55, 0.38)
const COL_NOW := Color(0.72, 0.45, 0.06)
const COL_DIM := Color(0.55, 0.48, 0.38)
const COL_SUB := Color(0.5, 0.42, 0.3)

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	# 픽셀아트 두루마리: 양피지 몸통 + 위아래 말린 축.
	# 모든 텍스트는 이 두루마리 안(여백 안쪽)에만 표시된다.
	var panel := PanelContainer.new()
	panel.position = Vector2(240, 26)
	panel.custom_minimum_size = Vector2(480, 488)
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

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(428, 396)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_box.custom_minimum_size = Vector2(424, 0)
	scroll.add_child(items_box)


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


func _line(text: String, color := COL_TEXT) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	items_box.add_child(l)


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	var ph: String = GameData.story_phase

	# ① 현재 퀘스트 이름(크게) ② 해야 하는 일 ③ 스토리
	var cur := GameData.story_current_quest()
	if not cur.is_empty():
		var big := Label.new()
		big.text = str(cur.name)
		big.add_theme_font_size_override("font_size", 24)
		big.add_theme_color_override("font_color", Color(0.42, 0.24, 0.06))
		big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		items_box.add_child(big)
		_line("해야 할 일: " + str(cur.task), COL_NOW)
		_line("")
		_line(str(cur.story), COL_SUB)
		_line("")
		_line("--------------------------------", Color(0.75, 0.63, 0.42))

	# 메인 스토리 1 전체 퀘스트 목록 (완료 후에도 기록으로 남는다)
	_line("[메인 스토리 1 — 우체부 아저씨와의 첫 만남]", COL_HEAD)
	var cur_idx: int = GameData.STORY1_QUESTS.size() if ph == "done" \
		else int(GameData.STORY1_PHASE_IDX.get(ph, GameData.STORY1_QUESTS.size()))
	for i in GameData.STORY1_QUESTS.size():
		var qd: Dictionary = GameData.STORY1_QUESTS[i]
		if ph == "done" or i < cur_idx:
			_line("  V %s (완료)" % qd.name, COL_DONE)
		elif i == cur_idx:
			_line("  > %s — %s" % [qd.name, qd.task], COL_NOW)
		else:
			_line("  - ???", COL_DIM)
			break  # 다음 퀘스트는 미리 보여주지 않는다
	_line("")

	# 스토리 진행 중에는 스토리에만 집중한다
	if ph != "done":
		return

	# 메인 스토리 2 — 상점 짓기 -> 낚시꾼과 바다 -> 밭 일구기 (이 순서)
	_line("[메인 스토리 2 — 마을을 깨우다]", COL_HEAD)
	var s2: String = GameData.story2_phase
	var shop_txt := "재료를 모아 상점을 짓자 (목재 %d·돌 %d)" \
		% [GameData.SHOP_BUILD_WOOD, GameData.SHOP_BUILD_STONE]
	if GameData.village_built.has("general"):
		_line("  V " + shop_txt, COL_DONE)
	elif s2 == "shop":
		_line("  > " + shop_txt, COL_NOW)
	else:
		_line("  - ???", COL_DIM)
	var fq: String = GameData.fisher_quest
	if fq == "":
		_line("  - ??? (상점이 서면 이어진다)", COL_DIM)
	else:
		var order := ["meet", "follow", "open", "done"]
		var steps := ["낯선 낚시꾼에게 말을 걸어 보자",
			"낚시꾼과 함께 남쪽 바위 능선으로 가자",
			"길목의 커다란 바위를 캐서 바닷길을 열자",
			"바다·해변 해금 + 간이낚싯대 (낚시 해금)"]
		var idx := order.find(fq)
		for i in steps.size():
			if i < idx or fq == "done":
				_line("  V " + steps[i], COL_DONE)
			elif i == idx:
				_line("  > " + steps[i], COL_NOW)
			else:
				_line("  - " + steps[i], COL_DIM)
	if s2 == "farm_talk":
		_line("  > 이장에게 가 보자 — 마을의 선물이 기다린다", COL_NOW)
	elif s2 in ["farm", "done"]:
		_line("  V 이장에게 호미와 씨앗을 받았다", COL_DONE)
		_tut_section(true)   # 밭 갈기 -> 씨앗 -> 물 -> 첫 수확
	else:
		_line("  - ??? (바닷길이 열리면 이어진다)", COL_DIM)
	_line("")

	# 마을 생활 안내 (선택 서브퀘스트)
	if GameData.tutorial.get("active", false):
		_line("[마을 생활 안내]  선택 — 안 해도 이야기는 진행된다", COL_HEAD)
		_tut_section(false)
		_line("")

	# 계절 축제 (계절마다 하루)
	_line("[계절 축제]", COL_HEAD)
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
			_line("  다음 축제: %s — %d일 뒤" % [next_name, next_in], COL_SUB)
	else:
		_line("  오늘은 %s! (9시~18시, %s)" % [ft.name,
			"낚시터" if str(ft.place) == "pier" else "마을 광장"], COL_NOW)
		_line("    %s" % ft.goal, COL_SUB)
		if GameData.fest_done:
			_line("    참가 완료!", COL_DONE)
		else:
			_line("    이장에게 「축제 이야기」로 진행한다.", COL_SUB)
	for sid in [GameData.SPRING, GameData.SUMMER, GameData.FALL, GameData.WINTER]:
		var f3: Dictionary = GameData.FESTIVALS[sid]
		var seen: bool = GameData.fest_history.has(str(f3.id))
		_line("  %s %s %d일 — %s" % ["V" if seen else "-",
			GameData.SEASON_NAMES[sid], int(f3.day), f3.name],
			COL_DONE if seen else COL_DIM)
	_line("")

	# 오늘의 의뢰 (마을 광장 게시판)
	_line("[오늘의 의뢰]", COL_HEAD)
	var q: Dictionary = GameData.quest
	if not q.is_empty():
		var iname: String = GameData.item_display_name(str(q.item))
		var have := GameData.ingredient_count(str(q.item))
		var status := "달성! 게시판(마을 광장)에서 납품하자." \
			if have >= int(q.qty) else "진행 중"
		_line("  [%s] %s %d개 납품 - 보상 %dG" % [q.get("label", "납품"), iname,
			int(q.qty), int(q.reward)])
		_line("    보유 %d/%d · %s" % [mini(have, int(q.qty)), int(q.qty), status],
			COL_NOW if have >= int(q.qty) else COL_SUB)
	elif GameData.quest_offers.is_empty():
		_line("  오늘 의뢰는 없다. 내일 게시판을 확인하자.")
	else:
		_line("  게시판에 세 건이 붙어 있다. 하나만 고를 수 있다.", COL_SUB)
		for o: Dictionary in GameData.quest_offers:
			_line("  · [%s] %s %d개 - %dG" % [o.label,
				GameData.item_display_name(str(o.item)), int(o.qty), int(o.reward)])
		_line("    마을 광장 게시판(E)에서 골라 수락하자.", COL_SUB)

	# 할아버지의 부탁 — 기본 안내가 끝난 뒤 이어지는 본 게임의 길잡이.
	# 다음 부탁은 미리 보여주지 않는다 (받았을 때 편지로 읽는다).
	_line("")
	_line("[할아버지의 부탁]", COL_HEAD)
	if GameData.tutorial.get("active", false):
		_line("  마을 생활 안내를 마치면 노트에서 떠오른다.", COL_DIM)
	else:
		var step: int = GameData.grandpa_step
		for i in GameData.GRANDPA_QUESTS.size():
			var gq: Dictionary = GameData.GRANDPA_QUESTS[i]
			if i < step:
				_line("  V %s (완료)" % gq.name, COL_DONE)
			elif i == step:
				var now: int = mini(GameData.grandpa_count(str(gq.count)), int(gq.goal))
				_line("  > %s — %s" % [gq.name, gq.desc], COL_NOW)
				_line("    %d/%d" % [now, int(gq.goal)], COL_SUB)
			else:
				_line("  - ???", COL_DIM)
				break

	# 마지막 부탁: 최후의 연금술 (진짜 목표는 여기까지 와야 밝혀진다)
	var prog: Dictionary = GameData.note_progress()
	_line("")
	if GameData.ending_seen:
		_line("  할아버지의 꿈을 완성했다.", COL_NOW)
		_line("    교진 마을의 나날은 계속된다.", COL_SUB)
	elif GameData.grandpa_all_done():
		_line("  [마지막 부탁] 일곱 전설의 재료를 모아 최후의 연금술을", COL_NOW)
		_line("    기록 %d/%d (%d%%) — 연구 노트(%s)를 보자" % [int(prog.filled),
			int(prog.total), int(prog.ratio * 100.0),
			GameData.key_label("open_note")], COL_SUB)
	else:
		_line("  연구 노트(%s)를 채워 할아버지의 흔적을 따라가자" %
			GameData.key_label("open_note"))
		_line("    기록 %d/%d (%d%%)" % [int(prog.filled), int(prog.total),
			int(prog.ratio * 100.0)], COL_SUB)



# 튜토리얼 목록의 반쪽을 그린다 — story2=true면 메인 스토리 2(밭 갈기),
# false면 선택 서브퀘스트(마을 생활 안내)
func _tut_section(story2: bool) -> void:
	var current_found := false
	for pair in GameData.TUTORIAL_ORDER:
		if (pair[0] in GameData.STORY2_FLAGS) != story2:
			continue
		if GameData.tutorial.get(pair[0], false):
			_line("  V " + pair[1], COL_DONE)
		elif not current_found:
			current_found = true
			_line("  > " + pair[1], COL_NOW)
		else:
			_line("  - " + pair[1], COL_DIM)
