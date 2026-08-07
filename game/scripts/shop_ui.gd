# 상점 UI: 씨앗 구매 / 작물 판매
extends CanvasLayer

var main: Node2D
var tab := "buy"

@onready var items_box: VBoxContainer = $Panel/V/Scroll/Items


func _ready() -> void:
	$Panel/V/Tabs/BuyBtn.pressed.connect(_on_tab.bind("buy"))
	$Panel/V/Tabs/SellBtn.pressed.connect(_on_tab.bind("sell"))
	$Panel/V/Tabs/CloseBtn.pressed.connect(close)


func _on_tab(t: String) -> void:
	tab = t
	_rebuild()


func open(t: String) -> void:
	tab = t
	visible = true
	_rebuild()


func close() -> void:
	visible = false


func _mk_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	if tab == "buy":
		for id in GameData.CROP_IDS:
			var def: Dictionary = GameData.CROPS[id]
			if GameData.season() not in def.seasons:
				continue  # 제철 씨앗만 판매
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
	GameData.today_spent += def.seed_price
	_rebuild()


func _on_sell(id: String) -> void:
	var def: Dictionary = GameData.CROPS[id]
	var amount: int = def.sell_price * GameData.produce[id]
	GameData.money += amount
	GameData.today_earned += amount
	GameData.produce[id] = 0
	_rebuild()
