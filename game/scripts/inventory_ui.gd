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


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(55, 30)
	panel.custom_minimum_size = Vector2(370, 250)
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
	title.text = "- 인벤토리 (I/ESC: 닫기) -"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 200)
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

	# 도구 선택 (클릭 또는 숫자키 1~9)
	_line("[도구]", Color(0.65, 0.85, 0.6))
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 4)
	for i in TOOLS.size():
		var t: String = TOOLS[i]
		var unlocked: bool = GameData.is_tool_unlocked(t)
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.focus_mode = Control.FOCUS_NONE
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon = main.tex[TOOL_ICONS[t]] if unlocked else null
		b.disabled = not unlocked
		b.add_theme_stylebox_override("normal",
			_slot_selected if GameData.tool == t else _slot_normal)
		b.add_theme_stylebox_override("hover", _slot_normal)
		b.add_theme_stylebox_override("pressed", _slot_selected)
		b.pressed.connect(func() -> void:
			main.set_tool(t)
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

	# 능력치: 하다 보면 는다
	_line("[능력치]", Color(0.65, 0.85, 0.6))
	for sid in GameData.SKILL_IDS:
		var lv := GameData.skill_lv(sid)
		var s: Dictionary = GameData.skills[sid]
		var prog := "MAX" if lv >= GameData.SKILL_MAX_LV else \
			"%d/%d" % [int(s.xp), int(GameData.skill_xp_needed(lv))]
		_line("  %s Lv.%d (%s) - %s" %
			[GameData.SKILLS[sid].name, lv, prog, GameData.SKILLS[sid].effect])

	if GameData.active_pet != "":
		var pdef: Dictionary = GameData.PETS[GameData.active_pet]
		_line("[펫] %s - %s" % [pdef.name, pdef.passive], Color(0.65, 0.85, 0.6))

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