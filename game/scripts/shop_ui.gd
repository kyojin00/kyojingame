# 상점 UI: 씨앗 구매 / 작물 판매
extends CanvasLayer

var main: Node2D
var tab := "buy"

@onready var items_box: VBoxContainer = $Panel/V/Scroll/Items


func _ready() -> void:
	$Panel/V/Tabs/BuyBtn.pressed.connect(_on_tab.bind("buy"))
	$Panel/V/Tabs/SellBtn.pressed.connect(_on_tab.bind("sell"))
	$Panel/V/Tabs/AnimalBtn.pressed.connect(_on_tab.bind("animal"))
	$Panel/V/Tabs/UpgradeBtn.pressed.connect(_on_tab.bind("upgrade"))
	$Panel/V/Tabs/CodexBtn.pressed.connect(_on_tab.bind("codex"))
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
			var price := GameData.seed_price(id)
			var b := _mk_button("%dG 구매" % price, _on_buy.bind(id))
			b.disabled = GameData.money < price
			row.add_child(b)
			items_box.add_child(row)
		if GameData.merchant_discount():
			var note := Label.new()
			note.text = "민지와 친해져서 씨앗 10% 할인 중! ♥"
			items_box.add_child(note)
	elif tab == "sell":
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
		for id in GameData.ITEM_IDS:
			var count: int = GameData.items[id]
			if count <= 0:
				continue
			any = true
			var def: Dictionary = GameData.ITEMS[id]
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s x%d (개당 %dG)" % [def.name, count, def.sell]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(_mk_button("%dG에 전부 판매" % (def.sell * count), _on_sell_item.bind(id)))
			items_box.add_child(row)
		if not any:
			var empty := Label.new()
			empty.text = "팔 수 있는 것이 없다. 수확물/생산물이 여기에 표시된다."
			items_box.add_child(empty)
	elif tab == "animal":
		for id in GameData.ANIMALS:
			var def: Dictionary = GameData.ANIMALS[id]
			var count := 0
			for a in main.animals:
				if a.type == id:
					count += 1
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s x%d - %s 생산" % [def.name, count, GameData.ITEMS[def.product].name]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var b := _mk_button("%dG 입양" % def.price, _on_buy_animal.bind(id))
			b.disabled = GameData.money < def.price or main.animals.size() >= GameData.MAX_ANIMALS
			row.add_child(b)
			items_box.add_child(row)
		var hint := Label.new()
		hint.text = "\n동물은 농장을 돌아다닌다. 가까이 가서 E로 쓰다듬어주면\n다음 날 아침 생산물을 준다. (최대 %d마리)" % GameData.MAX_ANIMALS
		items_box.add_child(hint)
	elif tab == "codex":
		var title := Label.new()
		title.text = "- 물고기 도감 -"
		items_box.add_child(title)
		for f in GameData.FISH:
			var id: String = f[0]
			var caught := int(GameData.fish_caught.get(id, 0))
			var l := Label.new()
			if caught > 0:
				l.text = "%s - %d마리 낚음 (%dG)" % [GameData.ITEMS[id].name, caught, GameData.ITEMS[id].sell]
			else:
				l.text = "??? - 아직 낚지 못했다"
			items_box.add_child(l)
		var hint := Label.new()
		hint.text = "\n낚싯대(9)를 들고 물가에서 Space! 입질(!)이 오면 다시 Space!"
		items_box.add_child(hint)
	else:
		for id in GameData.UPGRADES:
			var up: Dictionary = GameData.UPGRADES[id]
			var level: int = GameData.tool_level[id]
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s Lv%d - %s" % [up.name, level, up.desc]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			if level >= 2:
				var done := Label.new()
				done.text = "최대 레벨"
				row.add_child(done)
			else:
				var b := _mk_button("%dG+목재%d" % [up.money, up.wood], _on_upgrade.bind(id))
				b.disabled = GameData.money < up.money or GameData.wood < up.wood
				row.add_child(b)
			items_box.add_child(row)
		var hint := Label.new()
		hint.text = "\n울타리: 목재 %d / 스프링클러: 목재 %d+석재 %d\n(나무는 도끼로, 돌은 곡괭이로 캔다)" % [
			GameData.FENCE_COST_WOOD, GameData.SPRINKLER_COST_WOOD, GameData.SPRINKLER_COST_STONE]
		items_box.add_child(hint)


func _on_buy(id: String) -> void:
	var price := GameData.seed_price(id)
	if GameData.money < price:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= price
	GameData.seeds[id] += 1
	GameData.today_spent += price
	_rebuild()


func _on_sell(id: String) -> void:
	var def: Dictionary = GameData.CROPS[id]
	var amount: int = def.sell_price * GameData.produce[id]
	Sound.play_sfx("sfx_coin")
	GameData.money += amount
	GameData.today_earned += amount
	GameData.produce[id] = 0
	_rebuild()


func _on_sell_item(id: String) -> void:
	var def: Dictionary = GameData.ITEMS[id]
	var amount: int = def.sell * GameData.items[id]
	Sound.play_sfx("sfx_coin")
	GameData.money += amount
	GameData.today_earned += amount
	GameData.items[id] = 0
	_rebuild()


func _on_buy_animal(id: String) -> void:
	var def: Dictionary = GameData.ANIMALS[id]
	if GameData.money < def.price or main.animals.size() >= GameData.MAX_ANIMALS:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= def.price
	GameData.today_spent += def.price
	main.spawn_animal(id)
	_rebuild()


func _on_upgrade(id: String) -> void:
	var up: Dictionary = GameData.UPGRADES[id]
	if GameData.tool_level[id] >= 2 or GameData.money < up.money or GameData.wood < up.wood:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= up.money
	GameData.wood -= up.wood
	GameData.tool_level[id] = 2
	_rebuild()
