# 인벤토리 (I): 도구 선택 + 보유 중인 씨앗/수확물/생산물/자원.
extends CanvasLayer

const TOOLS := ["hoe", "water", "seed", "hand", "axe", "pickaxe", "fence", "sprinkler", "rod"]
const TOOL_ICONS := {
	"hoe": "icon_hoe", "water": "icon_water", "seed": "icon_seed", "hand": "icon_basket",
	"axe": "icon_axe", "pickaxe": "icon_pickaxe", "fence": "fence",
	"sprinkler": "sprinkler", "rod": "icon_rod",
}

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0
var _slot_normal: StyleBoxFlat
var _slot_selected: StyleBoxFlat
var _slot_moving: StyleBoxFlat
var _move_from := -1  # 우클릭으로 이동 중인 슬롯 (-1 = 없음)


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(203, 83)
	panel.custom_minimum_size = Vector2(555, 345)
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
	title.text = "- 인벤토리 (I/ESC: 닫기 · U: 능력치) -"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(525, 270)
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
	_move_from = -1


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

	if _slot_normal == null:
		_slot_normal = StyleBoxFlat.new()
		_slot_normal.bg_color = Color(0.11, 0.09, 0.16, 0.85)
		_slot_normal.border_color = Color(0.32, 0.27, 0.43)
		_slot_normal.set_border_width_all(1)
		_slot_normal.set_corner_radius_all(3)
		_slot_selected = _slot_normal.duplicate()
		_slot_selected.bg_color = Color(0.24, 0.2, 0.32, 0.95)
		_slot_selected.border_color = Color(1, 0.84, 0.37)
		_slot_selected.set_border_width_all(2)
		_slot_moving = _slot_normal.duplicate()
		_slot_moving.bg_color = Color(0.3, 0.22, 0.14, 0.95)
		_slot_moving.border_color = Color(0.45, 0.9, 0.5)
		_slot_moving.set_border_width_all(2)

	# 도구 슬롯: 드래그로 원하는 칸에 배치 (좌클릭: 선택)
	_line("[도구]  드래그: 위치 이동 · 좌클릭: 선택", Color(0.65, 0.85, 0.6))
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 4)
	for i in GameData.tool_slots.size():
		tool_row.add_child(_mk_tool_slot(i))
	items_box.add_child(tool_row)

	_line("소지금 %dG" % GameData.money, Color("ffd75e"))

	# 아이템 그리드 (12 x 4): 얻은 것들이 자동으로 채워진다
	var entries := _item_entries()
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in 48:
		grid.add_child(_mk_item_slot(entries[i] if i < entries.size() else {}))
	items_box.add_child(grid)


func _mk_tool_slot(slot_i: int) -> Button:
	var t: String = GameData.tool_slots[slot_i]
	var unlocked: bool = t != "" and GameData.is_tool_unlocked(t)
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.icon = main.tex[TOOL_ICONS[t]] if unlocked else null
	b.add_theme_stylebox_override("normal",
		_slot_selected if (t != "" and GameData.tool == t) else _slot_normal)
	b.add_theme_stylebox_override("hover", _slot_normal)
	b.add_theme_stylebox_override("pressed", _slot_selected)
	b.pressed.connect(func() -> void:
		if unlocked:
			main.set_tool(t)
			_rebuild())
	b.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var tt: String = GameData.tool_slots[slot_i]
			if tt == "" or not GameData.is_tool_unlocked(tt):
				return null
			var pv := TextureRect.new()
			pv.texture = main.tex[TOOL_ICONS[tt]]
			pv.custom_minimum_size = Vector2(36, 36)
			pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pv.stretch_mode = TextureRect.STRETCH_SCALE
			b.set_drag_preview(pv)
			return {"kind": "tool_slot", "from": slot_i},
		func(_pos: Vector2, data: Variant) -> bool:
			return typeof(data) == TYPE_DICTIONARY and data.get("kind") == "tool_slot",
		func(_pos: Vector2, data: Variant) -> void:
			_swap_slots(int(data.from), slot_i))
	return b


func _swap_slots(from_i: int, to_i: int) -> void:
	if from_i == to_i:
		return
	var tmp: String = GameData.tool_slots[from_i]
	GameData.tool_slots[from_i] = GameData.tool_slots[to_i]
	GameData.tool_slots[to_i] = tmp
	Sound.play_sfx("sfx_place")
	_rebuild()


func _mk_item_slot(e: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_stylebox_override("normal", _slot_normal)
	b.add_theme_stylebox_override("hover", _slot_selected)
	b.add_theme_stylebox_override("pressed", _slot_normal)
	if e.is_empty():
		return b
	b.tooltip_text = str(e.tip)
	if e.has("icon") and main.tex.has(e.icon):
		b.icon = main.tex[e.icon]
	else:
		var tag := Label.new()
		tag.text = str(e.label)
		tag.position = Vector2(11, 4)
		tag.add_theme_color_override("font_color", e.get("color", Color(0.9, 0.88, 0.95)))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
	var cnt := Label.new()
	cnt.text = str(e.count)
	cnt.add_theme_font_size_override("font_size", 16)
	cnt.position = Vector2(18, 20)
	cnt.size = Vector2(20, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	cnt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	cnt.add_theme_constant_override("outline_size", 3)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cnt)
	return b


func _item_entries() -> Array:
	var out: Array = []
	if GameData.wood > 0:
		out.append({"icon": "icon_wood", "count": GameData.wood,
			"tip": "목재 x%d" % GameData.wood})
	if GameData.stone > 0:
		out.append({"icon": "icon_stone", "count": GameData.stone,
			"tip": "석재 x%d" % GameData.stone})
	for id in GameData.CROP_IDS:
		if GameData.seeds[id] > 0:
			out.append({"icon": "icon_seed", "count": GameData.seeds[id],
				"tip": "%s 씨앗 x%d" % [GameData.CROPS[id].name, GameData.seeds[id]]})
	for id in GameData.CROP_IDS:
		var n := int(GameData.produce[id])
		if n > 0:
			out.append({"icon": "mature_" + id, "count": n,
				"tip": "%s x%d (개당 %dG)" % [GameData.CROPS[id].name, n,
					GameData.CROPS[id].sell_price]})
		var ns := int(GameData.produce_silver.get(id, 0))
		if ns > 0:
			out.append({"icon": "mature_" + id, "count": ns,
				"tip": "%s (은품질) x%d" % [GameData.CROPS[id].name, ns]})
		var ng := int(GameData.produce_gold.get(id, 0))
		if ng > 0:
			out.append({"icon": "mature_" + id, "count": ng,
				"tip": "%s (금품질) x%d" % [GameData.CROPS[id].name, ng]})
	for id in GameData.ITEM_IDS:
		var n2 := int(GameData.items[id])
		if n2 <= 0:
			continue
		var def: Dictionary = GameData.ITEMS[id]
		var e := {"count": n2, "tip": "%s x%d" % [def.name, n2],
			"label": str(def.name).left(1)}
		for cand in [id, id + "_0", "forage_" + id]:
			if main.tex.has(cand):
				e["icon"] = cand
				break
		if id.begins_with("fish_"):
			e["color"] = Color(0.5, 0.75, 1.0)
		elif id.begins_with("dish_"):
			e["color"] = Color(1.0, 0.75, 0.4)
		elif bool(def.get("legend", false)):
			e["color"] = Color(1.0, 0.85, 0.4)
		else:
			e["color"] = Color(0.85, 0.82, 0.95)
		out.append(e)
	return out