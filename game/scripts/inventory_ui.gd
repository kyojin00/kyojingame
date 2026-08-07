# 인벤토리 (I): 보유 중인 씨앗/수확물/생산물/자원을 한눈에 본다.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(80, 30)
	panel.custom_minimum_size = Vector2(320, 250)
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
	scroll.custom_minimum_size = Vector2(300, 200)
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