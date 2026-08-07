# 퀘스트 창 (J): 튜토리얼 진행 + 오늘의 의뢰 + 영토 확장 목표.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(70, 16)
	panel.custom_minimum_size = Vector2(340, 238)
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
	scroll.custom_minimum_size = Vector2(320, 190)
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

	# 영토 확장
	_line("")
	_line("[영토 확장]", Color(0.65, 0.85, 0.6))
	var next_pid := ""
	for pid in GameData.PARCELS:
		if not GameData.owned_parcels.has(pid):
			next_pid = pid
			break
	if next_pid == "":
		_line("  모든 부지를 손에 넣었다! 이 땅의 주인은 나다.")
	else:
		var def: Dictionary = GameData.PARCELS[next_pid]
		_line("  다음 부지: %s (%dG)" % [def.name, int(def.price)])
		_line("    지도(%s)에서 위치 확인 · 표지판에서 구입" % GameData.key_label("open_map"),
			Color(0.75, 0.72, 0.85))
