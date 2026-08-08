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
	var cur_idx: int = 8 if ph == "done" \
		else int(GameData.STORY1_PHASE_IDX.get(ph, 8))
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

	# 생활 안내 (스토리 완료 후, 필요한 순간마다 하나씩)
	if GameData.tutorial.get("active", false):
		_line("[마을 생활 안내]", COL_HEAD)
		var current_found := false
		for pair in GameData.TUTORIAL_ORDER:
			if GameData.tutorial.get(pair[0], false):
				_line("  V " + pair[1], COL_DONE)
			elif not current_found:
				current_found = true
				_line("  > " + pair[1], COL_NOW)
			else:
				_line("  - " + pair[1], COL_DIM)
		_line("")

	# 오늘의 의뢰 (마을 광장 게시판)
	_line("[오늘의 의뢰]", COL_HEAD)
	var q: Dictionary = GameData.quest
	if q.is_empty():
		_line("  오늘 의뢰는 없다. 내일 게시판을 확인하자.")
	else:
		var crop_name: String = GameData.CROPS[q.crop].name
		if bool(q.accepted):
			var have := int(GameData.produce[q.crop])
			var status := "달성! 게시판(마을 광장)에서 납품하자." \
				if have >= int(q.qty) else "진행 중"
			_line("  %s %d개 납품 - 보상 %dG" % [crop_name, int(q.qty), int(q.reward)])
			_line("    보유 %d/%d · %s" % [mini(have, int(q.qty)), int(q.qty), status],
				COL_NOW if have >= int(q.qty) else COL_SUB)
		else:
			_line("  [미수락] %s %d개 납품 - 보상 %dG" % [crop_name, int(q.qty), int(q.reward)])
			_line("    마을 광장 게시판(E)에서 수락하자.", COL_SUB)

	# 할아버지의 부탁 (진짜 목표는 끝까지 밝히지 않는다)
	_line("")
	_line("[할아버지의 부탁]", COL_HEAD)
	var prog: Dictionary = GameData.note_progress()
	if GameData.ending_seen:
		_line("  할아버지의 꿈을 완성했다.", COL_NOW)
		_line("    교진 마을의 나날은 계속된다.", COL_SUB)
	else:
		_line("  연구 노트(%s)를 채워 할아버지의 흔적을 따라가자" %
			GameData.key_label("open_note"))
		_line("    기록 %d/%d (%d%%)" % [int(prog.filled), int(prog.total),
			int(prog.ratio * 100.0)], COL_SUB)
		if prog.ratio >= 0.5:
			_line("    노트에 숨겨진 메모가 나타나기 시작했다...", COL_NOW)

	# 마을 탐사 (부지)
	_line("")
	_line("[마을 탐사]", COL_HEAD)
	var total := 0
	var owned := 0
	var next_pid := ""
	for pid in GameData.PARCELS:
		total += 1
		if GameData.owned_parcels.has(pid):
			owned += 1
		elif next_pid == "":
			next_pid = pid
	if next_pid == "":
		_line("  할아버지가 조사하던 곳을 전부 되찾았다. (%d/%d)" % [owned, total], COL_NOW)
	else:
		var pdef: Dictionary = GameData.PARCELS[next_pid]
		_line("  할아버지의 탐사 흔적을 따라 부지를 되찾자 (%d/%d)" % [owned, total])
		_line("    다음: %s (%dG) · 지도(%s)에서 확인" %
			[pdef.name, int(pdef.price), GameData.key_label("open_map")], COL_SUB)
