# 주방 (집 안 조리대 E): 재료로 요리를 만들고, 먹어서 에너지를 회복한다.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(50, 16)
	panel.custom_minimum_size = Vector2(380, 238)
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
	title.text = "- 주방 (E/ESC: 닫기) -"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 190)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_box.add_theme_constant_override("separation", 4)
	scroll.add_child(items_box)


func open() -> void:
	visible = true
	Sound.play_sfx("sfx_ui")
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _needs_text(id: String) -> String:
	var parts := []
	for k in GameData.RECIPES[id].needs:
		var n: int = int(GameData.RECIPES[id].needs[k])
		var nm: String = GameData.CROPS[k].name if GameData.CROPS.has(k) else GameData.ITEMS[k].name
		parts.append("%s x%d (%d)" % [nm, n, GameData.ingredient_count(k)])
	return ", ".join(parts)


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	var head := Label.new()
	head.text = "요리 숙련 Lv.%d · 회복 +%d%%" % [GameData.skill_lv("cook"),
		int(round((GameData.cook_energy_mult() - 1.0) * 100.0))]
	head.add_theme_color_override("font_color", Color(0.65, 0.85, 0.6))
	items_box.add_child(head)

	for id in GameData.RECIPE_IDS:
		var def: Dictionary = GameData.ITEMS[id]
		var rec: Dictionary = GameData.RECIPES[id]
		var made := int(GameData.recipes_cooked.get(id, 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var cook_btn := Button.new()
		cook_btn.text = "만들기"
		cook_btn.focus_mode = Control.FOCUS_NONE
		cook_btn.disabled = not GameData.can_cook(id)
		cook_btn.pressed.connect(func() -> void:
			main.do_cook(id)
			_rebuild())
		row.add_child(cook_btn)

		var eat_btn := Button.new()
		eat_btn.text = "먹기"
		eat_btn.focus_mode = Control.FOCUS_NONE
		eat_btn.disabled = int(GameData.items[id]) <= 0
		eat_btn.pressed.connect(func() -> void:
			main.do_eat(id)
			_rebuild())
		row.add_child(eat_btn)

		var info := Label.new()
		info.text = "%s x%d · 회복%d · %dG" % [def.name, int(GameData.items[id]),
			int(rec.energy), int(def.sell)]
		info.add_theme_color_override("font_color",
			Color(0.92, 0.9, 0.95) if made > 0 else Color(0.6, 0.57, 0.7))
		row.add_child(info)
		items_box.add_child(row)

		var needs := Label.new()
		needs.text = "    재료: " + _needs_text(id)
		needs.add_theme_color_override("font_color", Color(0.62, 0.58, 0.75))
		items_box.add_child(needs)
