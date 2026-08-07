# 능력치 창 (U): 숙련도 6종 + 데리고 다니는 펫.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(285, 105)
	panel.custom_minimum_size = Vector2(390, 315)
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

	items_box = VBoxContainer.new()
	items_box.add_theme_constant_override("separation", 3)
	v.add_child(items_box)


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
	l.add_theme_color_override("font_color", color)
	items_box.add_child(l)


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	_line("하다 보면 는다 — 반복할수록 레벨이 오른다.", Color(0.62, 0.58, 0.75))
	for sid in GameData.SKILL_IDS:
		var lv := GameData.skill_lv(sid)
		var s: Dictionary = GameData.skills[sid]
		var prog := "MAX" if lv >= GameData.SKILL_MAX_LV else \
			"%d/%d" % [int(s.xp), int(GameData.skill_xp_needed(lv))]
		_line("%s Lv.%d (%s)" % [GameData.SKILLS[sid].name, lv, prog], Color("ffd75e"))
		_line("  %s" % GameData.SKILLS[sid].effect)

	_line("")
	if GameData.active_pet != "":
		var pdef: Dictionary = GameData.PETS[GameData.active_pet]
		_line("[펫] %s — %s" % [pdef.name, pdef.passive], Color(0.65, 0.85, 0.6))
	else:
		_line("[펫] 없음 — 목장 상회에서 입양할 수 있다", Color(0.62, 0.58, 0.75))
