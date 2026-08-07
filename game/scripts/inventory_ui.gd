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
	panel.position = Vector2(135, 55)
	panel.custom_minimum_size = Vector2(370, 230)
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
	scroll.custom_minimum_size = Vector2(350, 180)
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

	# 도구 슬롯 (좌클릭: 선택 / 우클릭: 슬롯 이동 시작 → 다른 슬롯 좌클릭으로 교환)
	_line("[도구]  우클릭: 원하는 숫자 슬롯으로 이동", Color(0.65, 0.85, 0.6))
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 4)
	for i in GameData.tool_slots.size():
		var t: String = GameData.tool_slots[i]
		var unlocked: bool = t != "" and GameData.is_tool_unlocked(t)
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.focus_mode = Control.FOCUS_NONE
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon = main.tex[TOOL_ICONS[t]] if unlocked else null
		if _move_from == i:
			b.add_theme_stylebox_override("normal", _slot_moving)
		else:
			b.add_theme_stylebox_override("normal",
				_slot_selected if (t != "" and GameData.tool == t) else _slot_normal)
		b.add_theme_stylebox_override("hover", _slot_normal)
		b.add_theme_stylebox_override("pressed", _slot_selected)
		var slot_i := i
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_RIGHT:
					# 이동 모드 시작/취소
					_move_from = -1 if _move_from == slot_i else slot_i
					Sound.play_sfx("sfx_ui")
					_rebuild()
				elif ev.button_index == MOUSE_BUTTON_LEFT:
					if _move_from >= 0 and _move_from != slot_i:
						var tmp: String = GameData.tool_slots[_move_from]
						GameData.tool_slots[_move_from] = GameData.tool_slots[slot_i]
						GameData.tool_slots[slot_i] = tmp
						_move_from = -1
						Sound.play_sfx("sfx_place")
						_rebuild()
					elif _move_from < 0 and unlocked:
						main.set_tool(GameData.tool_slots[slot_i])
						_rebuild())
		var num := Label.new()
		num.text = str(i + 1)
		num.position = Vector2(2, -4)
		num.add_theme_color_override("font_color", Color(0.62, 0.58, 0.75))
		num.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
		num.add_theme_constant_override("outline_size", 2)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)
		tool_row.add_child(b)
	items_box.add_child(tool_row)

	_line("소지금 %dG   목재 %d   석재 %d" % [GameData.money, GameData.wood, GameData.stone],
		Color("ffd75e"))

	var any_seed := false
	for id in GameData.CROP_IDS:
		if GameData.seeds[id] > 0:
			if not any_seed:
				_line("[씨앗]", Color(0.65, 0.85, 0.6))
				any_seed = true
			_line("  %s 씨앗 x%d" % [GameData.CROPS[id].name, GameData.seeds[id]])

	var any_crop := false
	for id in GameData.CROP_IDS:
		if GameData.produce[id] > 0:
			if not any_crop:
				_line("[수확물]", Color(0.65, 0.85, 0.6))
				any_crop = true
			_line("  %s x%d (개당 %dG)" % [GameData.CROPS[id].name, GameData.produce[id],
				GameData.CROPS[id].sell_price])

	var any_item := false
	for id in GameData.ITEM_IDS:
		if GameData.items[id] > 0:
			if not any_item:
				_line("[생산물/물고기]", Color(0.65, 0.85, 0.6))
				any_item = true
			_line("  %s x%d (개당 %dG)" % [GameData.ITEMS[id].name, GameData.items[id],
				GameData.ITEMS[id].sell])

	if not (any_seed or any_crop or any_item):
		_line("아직 가진 것이 별로 없다. 농사를 시작해보자!")