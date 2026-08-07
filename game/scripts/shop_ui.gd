# 상점 UI: 씨앗 구매 / 작물 판매 (가게마다 허용된 탭만 보인다)
extends CanvasLayer

const TAB_BUTTONS := {
	"buy": "BuyBtn", "sell": "SellBtn", "animal": "AnimalBtn",
	"upgrade": "UpgradeBtn", "codex": "CodexBtn",
}

var main: Node2D
var tab := "buy"
var allowed: Array = TAB_BUTTONS.keys()

@onready var items_box: VBoxContainer = $Panel/V/Scroll/Items


func _ready() -> void:
	$Panel/V/Tabs/BuyBtn.pressed.connect(_on_tab.bind("buy"))
	$Panel/V/Tabs/SellBtn.pressed.connect(_on_tab.bind("sell"))
	$Panel/V/Tabs/AnimalBtn.pressed.connect(_on_tab.bind("animal"))
	$Panel/V/Tabs/UpgradeBtn.pressed.connect(_on_tab.bind("upgrade"))
	$Panel/V/Tabs/CodexBtn.pressed.connect(_on_tab.bind("codex"))
	$Panel/V/Tabs/CloseBtn.pressed.connect(close)


func _on_tab(t: String) -> void:
	if not allowed.has(t):
		return
	tab = t
	_rebuild()


# allowed_tabs: 이 가게에서 쓸 수 있는 탭 (비우면 t 하나만)
func open(t: String, allowed_tabs: Array = []) -> void:
	tab = t
	allowed = allowed_tabs if not allowed_tabs.is_empty() else [t]
	for key in TAB_BUTTONS:
		get_node("Panel/V/Tabs/" + TAB_BUTTONS[key]).visible = allowed.has(key)
	visible = true
	if main != null:
		main.tutorial_notify("shop")
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
			l.text = "%s 씨앗(보유%d) 성장 %d시간" % [def.name, GameData.seeds[id], def.grow_days]
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
			if count <= 0 or GameData.ITEMS[id].get("legend", false):
				continue  # 전설 재료는 팔 수 없다
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

		var pet_title := Label.new()
		pet_title.text = "\n- 펫 입양 (한 마리만 데리고 다닌다) -"
		items_box.add_child(pet_title)
		for pid in GameData.PET_IDS:
			var pdef: Dictionary = GameData.PETS[pid]
			var prow := HBoxContainer.new()
			var pl := Label.new()
			pl.text = "%s - %s" % [pdef.name, pdef.passive]
			pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			prow.add_child(pl)
			if not GameData.owned_pets.has(pid):
				var pb := _mk_button("%dG 입양" % pdef.price, _on_buy_pet.bind(pid))
				pb.disabled = GameData.money < int(pdef.price)
				prow.add_child(pb)
			elif GameData.active_pet == pid:
				prow.add_child(_mk_button("쉬게 하기", _on_select_pet.bind("")))
			else:
				prow.add_child(_mk_button("데려가기", _on_select_pet.bind(pid)))
			items_box.add_child(prow)
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
		var mob_title := Label.new()
		mob_title.text = "\n- 몬스터 도감 -"
		items_box.add_child(mob_title)
		for mid in GameData.MOBS:
			var kills := int(GameData.mob_kills.get(mid, 0))
			var ml := Label.new()
			if kills > 0:
				ml.text = "%s - %d마리 처치. %s" % [GameData.MOBS[mid].name, kills, GameData.MOBS[mid].desc]
				ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			else:
				ml.text = "??? - 동굴에서 만나보자"
			items_box.add_child(ml)
		var cook_title := Label.new()
		cook_title.text = "\n- 요리 도감 -"
		items_box.add_child(cook_title)
		for rid in GameData.RECIPE_IDS:
			var made := int(GameData.recipes_cooked.get(rid, 0))
			var cl := Label.new()
			if made > 0:
				cl.text = "%s - %d번 요리 (%dG)" % [GameData.ITEMS[rid].name, made,
					GameData.ITEMS[rid].sell]
			else:
				cl.text = "??? - 집 조리대에서 만들어보자"
			items_box.add_child(cl)
		var hint := Label.new()
		hint.text = "\n낚싯대(9)를 들고 물가에서 Space! 입질(!)이 오면 다시 Space!\n철수와 친해지면(호감도 50+) 판정 구간이 넓어진다."
		items_box.add_child(hint)
	else:
		for id in GameData.UPGRADES:
			var up: Dictionary = GameData.UPGRADES[id]
			var levels: Array = up.levels
			var level: int = GameData.tool_level.get(id, 1)
			var row := HBoxContainer.new()
			var l := Label.new()
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			if level - 1 >= levels.size():
				l.text = "%s Lv%d (최대)" % [up.name, level]
			else:
				var next: Dictionary = levels[level - 1]
				l.text = "%s Lv%d→%d: %s" % [up.name, level, level + 1, next.desc]
				var cost_text := "%dG" % next.money
				if int(next.wood) > 0:
					cost_text += "+목재%d" % next.wood
				if int(next.ore) > 0:
					cost_text += "+광석%d" % next.ore
				var b := _mk_button(cost_text, _on_upgrade.bind(id))
				b.disabled = GameData.money < next.money or GameData.wood < next.wood \
					or GameData.items["ore"] < next.ore
				row.add_child(b)
			items_box.add_child(row)
		var hint := Label.new()
		hint.text = "\n광석은 동굴(마을 북쪽)에서! 울타리: 목재 %d /\n스프링클러: 목재 %d+석재 %d" % [
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
	if main != null and not main._remote_acting:
		main.net_shop("buy_seed", id)
	_rebuild()


func _on_sell(id: String) -> void:
	var def: Dictionary = GameData.CROPS[id]
	var amount: int = def.sell_price * GameData.produce[id]
	Sound.play_sfx("sfx_coin")
	GameData.money += amount
	GameData.today_earned += amount
	GameData.produce[id] = 0
	if main != null and not main._remote_acting:
		main.net_shop("sell_crop", id)
	_rebuild()


func _on_sell_item(id: String) -> void:
	var def: Dictionary = GameData.ITEMS[id]
	var amount: int = def.sell * GameData.items[id]
	Sound.play_sfx("sfx_coin")
	GameData.money += amount
	GameData.today_earned += amount
	GameData.items[id] = 0
	if main != null and not main._remote_acting:
		main.net_shop("sell_item", id)
	_rebuild()


func _on_buy_animal(id: String) -> void:
	var def: Dictionary = GameData.ANIMALS[id]
	if GameData.money < def.price or main.animals.size() >= GameData.MAX_ANIMALS:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= def.price
	GameData.today_spent += def.price
	main.spawn_animal(id)
	if main != null and not main._remote_acting:
		main.net_shop("buy_animal", id)
	_rebuild()


func _on_buy_pet(id: String) -> void:
	var def: Dictionary = GameData.PETS[id]
	if GameData.money < int(def.price) or GameData.owned_pets.has(id):
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= int(def.price)
	GameData.today_spent += int(def.price)
	GameData.owned_pets.append(id)
	GameData.active_pet = id
	if main != null and not main._remote_acting:
		main.net_shop("buy_pet", id)
	_rebuild()


func _on_select_pet(id: String) -> void:
	GameData.active_pet = id
	Sound.play_sfx("sfx_ui")
	if main != null and not main._remote_acting:
		main.net_shop("select_pet", id)
	_rebuild()


func _on_upgrade(id: String) -> void:
	var levels: Array = GameData.UPGRADES[id].levels
	var level: int = GameData.tool_level.get(id, 1)
	if level - 1 >= levels.size():
		return
	var next: Dictionary = levels[level - 1]
	if GameData.money < next.money or GameData.wood < next.wood \
			or GameData.items["ore"] < next.ore:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= next.money
	GameData.wood -= int(next.wood)
	GameData.items["ore"] -= int(next.ore)
	GameData.tool_level[id] = level + 1
	if main != null and not main._remote_acting:
		main.net_shop("upgrade", id)
	_rebuild()
