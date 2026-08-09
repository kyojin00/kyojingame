# 능력치 창 (U): 숙련도 6종 + 데리고 다니는 펫.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var scroll: ScrollContainer
var _refresh_timer := 0.0


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
	items_box.add_theme_constant_override("separation", 3)
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


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	_line("하다 보면 는다 — 반복할수록 레벨이 오른다.", Color(0.62, 0.58, 0.75))
	for sid in GameData.SKILL_IDS:
		var lv := GameData.skill_lv(sid)
		var s: Dictionary = GameData.skills[sid]
		var prog := "MAX" if lv >= GameData.SKILL_MAX_LV else \
			"%d/%d" % [int(s.xp), int(GameData.skill_xp_needed(lv))]
		_line("%s Lv.%d  (%s)" % [GameData.SKILLS[sid].name, lv, prog], Color("ffd75e"))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(350, 10)
		bar.show_percentage = false
		if lv >= GameData.SKILL_MAX_LV:
			bar.max_value = 1.0
			bar.value = 1.0
		else:
			bar.max_value = GameData.skill_xp_needed(lv)
			bar.value = float(s.xp)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.08, 0.15)
		bg.border_color = Color(0.32, 0.27, 0.43)
		bg.set_border_width_all(1)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.48, 0.83, 0.35) if lv < GameData.SKILL_MAX_LV \
			else Color(1.0, 0.84, 0.37)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		items_box.add_child(bar)
		_line("  %s" % GameData.SKILLS[sid].effect)

	# 장비 능력치 (대장간에서 강화하면 여기 숫자가 오른다)
	_line("")
	_line("[장비] 강화할수록 능력치가 오른다 — 대장간에서", Color(0.62, 0.58, 0.75))
	for tid in GameData.TOOL_STATS:
		if not is_tool_unlocked_safe(tid):
			continue
		var st: Dictionary = GameData.tool_stats(tid)
		var lv: int = int(GameData.tool_level.get(tid, 1))
		var parts: Array[String] = []
		for k in ["power", "reach", "stamina", "luck"]:
			parts.append("%s %s" % [GameData.STAT_NAMES[k], GameData.fmt_stat(st[k])])
		_line("%s Lv.%d — %s" % [GameData.TOOL_KOR.get(tid, tid), lv, " · ".join(parts)],
			Color("ffd75e"))
	_line("  행운 합계 %s (장착 중인 장비)" % GameData.fmt_stat(GameData.total_luck()))
	for h in GameData.STAT_HELP:
		_line("  %s" % h, Color(0.62, 0.58, 0.75))

	_line("")
	if GameData.active_pet != "":
		var pdef: Dictionary = GameData.PETS[GameData.active_pet]
		_line("[펫] %s — %s" % [pdef.name, pdef.passive], Color(0.65, 0.85, 0.6))
	else:
		_line("[펫] 없음 — 목장 상회에서 입양할 수 있다", Color(0.62, 0.58, 0.75))
