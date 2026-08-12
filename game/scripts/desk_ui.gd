# 제작대 창 — 집 안 책상에서 E.
#
# 여기서 가구를 「걸어 두면」 시간이 지나 완성되고, 완성된 가구는 낡은
# 것과 저절로 바뀐다. 큐는 GameData.desk_tick이 돌리므로 창을 닫고
# 딴 일을 해도 만들어진다. 손보기(제작대 업글)만 즉시다 —
# 자기 자신은 자기로 못 만든다.
extends CanvasLayer

var main: Node2D
var _box: VBoxContainer
var _refresh := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(250, 100)
	panel.custom_minimum_size = Vector2(460, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.18, 0.12, 0.98)
	style.border_color = Color(0.62, 0.48, 0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(436, 306)
	panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 5)
	scroll.add_child(_box)


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


func _line(text: String, color := Color(0.9, 0.85, 0.75)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)


func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	var lv := GameData.desk_lv

	_line("- %s (E/ESC: 닫기) -" % GameData.DESK_NAMES[lv], Color(0.95, 0.8, 0.5))
	_line("하나 만드는 데 %.1f초 · 동시에 %d개" % [GameData.desk_time(), GameData.desk_slots()],
		Color(0.75, 0.68, 0.58))

	# ---- 지금 만드는 중 ----
	if not GameData.desk_queue.is_empty():
		_line("")
		_line("[만드는 중]", Color(0.95, 0.8, 0.5))
		for job: Dictionary in GameData.desk_queue:
			var def: Dictionary = GameData.DESK_RECIPES[job.id]
			var total := GameData.desk_time()
			var done := 1.0 - float(job.left) / total
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var nm := Label.new()
			nm.text = str(def.name)
			nm.custom_minimum_size = Vector2(120, 0)
			nm.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
			row.add_child(nm)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(200, 16)
			bar.value = done * 100.0
			bar.show_percentage = false
			row.add_child(bar)
			var left := Label.new()
			left.text = "%.1f초" % maxf(0.0, float(job.left))
			left.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58))
			row.add_child(left)
			_box.add_child(row)

	# ---- 만들 수 있는 것 ----
	_line("")
	_line("[가구 만들기]  — 완성되면 낡은 것과 바뀐다", Color(0.95, 0.8, 0.5))
	for id: String in GameData.DESK_RECIPES:
		var def: Dictionary = GameData.DESK_RECIPES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var b := Button.new()
		b.text = "만들기"
		b.focus_mode = Control.FOCUS_NONE
		var why := _cant_reason(id)
		b.disabled = why != ""
		b.pressed.connect(func() -> void:
			if GameData.desk_start(id):
				Sound.play_sfx("sfx_place")
				main.saveio.save_now()
			_rebuild())
		row.add_child(b)
		var nm2 := Label.new()
		var owned := "  (지금: %s)" % GameData.BED_NAMES[GameData.bed_lv] \
			if str(def.kind) == "bed" else ""
		nm2.text = "%s — %s%s" % [def.name, _cost_text(def.cost), owned]
		nm2.add_theme_color_override("font_color",
			Color(0.9, 0.85, 0.75) if why == "" else Color(0.6, 0.55, 0.48))
		row.add_child(nm2)
		_box.add_child(row)
		if why != "":
			_line("     %s" % why, Color(0.6, 0.55, 0.48))
		else:
			_line("     %s" % def.desc, Color(0.68, 0.62, 0.52))

	# ---- 손보기 (제작대 업글, 즉시) ----
	_line("")
	if lv < GameData.DESK_UPGRADES.size():
		var up: Dictionary = GameData.DESK_UPGRADES[lv]
		_line("[손보기]  %s -> %s" % [GameData.DESK_NAMES[lv], GameData.DESK_NAMES[lv + 1]],
			Color(0.95, 0.8, 0.5))
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		var ub := Button.new()
		ub.text = "손보기"
		ub.focus_mode = Control.FOCUS_NONE
		ub.disabled = not GameData.mats_ok(up.cost)
		ub.pressed.connect(func() -> void:
			if GameData.desk_upgrade():
				Sound.play_sfx("sfx_place")
				main.hud.quest_toast("%s 완성" % GameData.DESK_NAMES[GameData.desk_lv])
				main.saveio.save_now()
			_rebuild())
		row2.add_child(ub)
		var ut := Label.new()
		ut.text = "%s  -> %.1f초 · %d칸" % [_cost_text(up.cost),
			GameData.DESK_TIME[lv + 1], GameData.DESK_SLOTS[lv + 1]]
		ut.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
		row2.add_child(ut)
		_box.add_child(row2)
	else:
		_line("[손보기]  더 손볼 데가 없다 — 장인의 솜씨다.", Color(0.68, 0.62, 0.52))


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k: String in cost:
		var nm := str(GameData.ITEMS[k].name) if GameData.ITEMS.has(k) \
			else ("목재" if k == "wood" else "돌")
		parts.append("%s %d(%d)" % [nm, int(cost[k]), GameData.mat_count(k)])
	return " · ".join(parts)


# 왜 못 만드는가 — 버튼을 끄기만 하면 이유를 모른다
func _cant_reason(id: String) -> String:
	var def: Dictionary = GameData.DESK_RECIPES[id]
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
