# 퀘스트 창 (J): 튜토리얼 진행 + 오늘의 의뢰 + 영토 확장 목표.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(495, 24)
	panel.custom_minimum_size = Vector2(450, 495)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 퀘스트 (%s/ESC: 닫기) -" % GameData.key_label("open_quest")
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 426)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _line(text: String, color := Color(0.9, 0.88, 0.95)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	items_box.add_child(l)


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	# 메인 스토리 1
	if GameData.story_phase != "done" or GameData.tutorial.get("active", false):
		_line("[메인 스토리 1 — 우체부 아저씨와의 첫 만남]", Color(0.65, 0.85, 0.6))
		var ph: String = GameData.story_phase
		var done_col := Color(0.5, 0.62, 0.5)
		var now_col := Color("ffd75e")
		var q1_done := ph != "enter"
		var q2_done := ph in ["chop", "done"]
		var q3_done := ph == "done"
		_line("  V 숲 안으로 들어가보기 (완료)" if q1_done
			else "  > 숲 안으로 들어가보기 — 우거진 숲 안으로 들어가 보자",
			done_col if q1_done else now_col)
		if ph == "approach":
			_line("  > 우체부 아저씨의 이야기를 듣자", now_col)
		if ph in ["equip", "chop", "done"]:
			_line("  V 나무도끼를 장착해보기 (완료)" if q2_done
				else "  > 나무도끼를 장착해보기 — 받은 나무도끼를 가방(I)의 슬롯에 장착해 보자",
				done_col if q2_done else now_col)
		if ph in ["chop", "done"]:
			_line("  V 나무를 베어보자 (완료)" if q3_done
				else "  > 나무를 베어보자 — 나무도끼를 사용해 나무를 베어보자",
				done_col if q3_done else now_col)
		if ph != "done":
			_line("  - ???", Color(0.5, 0.48, 0.6))
		_line("")

	# 튜토리얼 진행 상황
	_line("[튜토리얼]", Color(0.65, 0.85, 0.6))
	if not GameData.tutorial.get("active", false):
		_line("  완료! 자유롭게 농장을 가꾸자.", Color(0.6, 0.75, 0.6))
	else:
		var current_found := false
		for pair in GameData.TUTORIAL_ORDER:
			if GameData.tutorial.get(pair[0], false):
				_line("  V " + pair[1], Color(0.5, 0.62, 0.5))
			elif not current_found:
				current_found = true
				_line("  > " + pair[1], Color("ffd75e"))
			else:
				_line("  - " + pair[1], Color(0.5, 0.48, 0.6))

	# 오늘의 의뢰 (마을 광장 게시판)
	_line("")
	_line("[오늘의 의뢰]", Color(0.65, 0.85, 0.6))
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
				Color("ffd75e") if have >= int(q.qty) else Color(0.75, 0.72, 0.85))
		else:
			_line("  [미수락] %s %d개 납품 - 보상 %dG" % [crop_name, int(q.qty), int(q.reward)])
			_line("    마을 광장 게시판(E)에서 수락하자.", Color(0.75, 0.72, 0.85))

	# 할아버지의 부탁 (진짜 목표는 끝까지 밝히지 않는다)
	_line("")
	_line("[할아버지의 부탁]", Color(0.65, 0.85, 0.6))
	var prog: Dictionary = GameData.note_progress()
	if GameData.ending_seen:
		_line("  할아버지의 꿈을 완성했다.", Color("ffd75e"))
		_line("    교진 마을의 나날은 계속된다.", Color(0.75, 0.72, 0.85))
	else:
		_line("  연구 노트(%s)를 채워 할아버지의 흔적을 따라가자" %
			GameData.key_label("open_note"))
		_line("    기록 %d/%d (%d%%)" % [int(prog.filled), int(prog.total),
			int(prog.ratio * 100.0)], Color(0.75, 0.72, 0.85))
		if prog.ratio >= 0.5:
			_line("    노트에 숨겨진 메모가 나타나기 시작했다...", Color("ffd75e"))

	# 마을 탐사 (부지)
	_line("")
	_line("[마을 탐사]", Color(0.65, 0.85, 0.6))
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
		_line("  할아버지가 조사하던 곳을 전부 되찾았다. (%d/%d)" % [owned, total],
			Color("ffd75e"))
	else:
		var pdef: Dictionary = GameData.PARCELS[next_pid]
		_line("  할아버지의 탐사 흔적을 따라 부지를 되찾자 (%d/%d)" % [owned, total])
		_line("    다음: %s (%dG) · 지도(%s)에서 확인" %
			[pdef.name, int(pdef.price), GameData.key_label("open_map")],
			Color(0.75, 0.72, 0.85))
