# 상점 UI: 씨앗 구매 / 작물 판매
extends CanvasLayer

var main: Node2D
var panel: PanelContainer
var items_box: VBoxContainer
var tab := "buy"


func _ready() -> void:
	layer = 20
	visible = false

	panel = PanelContainer.new()
	panel.position = Vector2(20, 28)
	panel.custom_minimum_size = Vector2(440, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	panel.add_child(v)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)

	tabs.add_child(_mk_button("씨앗 구매", func() -> void:
		tab = "buy"
		_rebuild()))
	tabs.add_child(_mk_button("작물 판매", func() -> void:
		tab = "sell"
		_rebuild()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	tabs.add_child(_mk_button("닫기(ESC)", close))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(432, 216)
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items_box)


func _mk_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


func open(t: String) -> void:
	tab = t
	visible = true
	_rebuild()


func close() -> void:
	visible = false


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	if tab == "buy":
		for id in GameData.CROP_IDS:
			var def: Dictionary = GameData.CROPS[id]
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s 씨앗(보유%d) 성장%d일" % [def.name, GameData.seeds[id], def.grow_days]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var b := _mk_button("%dG 구매" % def.seed_price, _on_buy.bind(id))
			b.disabled = GameData.money < def.seed_price
			row.add_child(b)
			items_box.add_child(row)
	else:
		var any := false
		for id in GameData.CROP_IDS:
			var count: int = GameData.produce[id]
			if count <= 0:
				continue
			any = true
			var def: Dictionary = GameData.CROPS[id]
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s x%d (개당 %dG)" % [def.name, count, def.sell_price]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(_mk_button("%dG에 전부 판매" % (def.sell_price * count), _on_sell.bind(id)))
			items_box.add_child(row)
		if not any:
			var empty := Label.new()
			empty.text = "팔 수 있는 작물이 없다. 수확하면 여기에 표시된다."
			items_box.add_child(empty)


func _on_buy(id: String) -> void:
	var def: Dictionary = GameData.CROPS[id]
	if GameData.money < def.seed_price:
		return
	GameData.money -= def.seed_price
	GameData.seeds[id] += 1
	_rebuild()


func _on_sell(id: String) -> void:
	var def: Dictionary = GameData.CROPS[id]
	GameData.money += def.sell_price * GameData.produce[id]
	GameData.produce[id] = 0
	_rebuild()
