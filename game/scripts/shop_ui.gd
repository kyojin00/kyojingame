# 상점 UI: 씨앗 구매 / 작물 판매 (가게마다 허용된 탭만 보인다)
extends CanvasLayer

const TAB_BUTTONS := {
	"buy": "BuyBtn", "sell": "SellBtn", "animal": "AnimalBtn",
	"upgrade": "UpgradeBtn", "codex": "CodexBtn",
}

var main: Node2D
var tab := "buy"
var allowed: Array = TAB_BUTTONS.keys()
var shop_title := "상점"
var _head: Label
var _money: Label
var _money_icon: TextureRect

@onready var items_box: VBoxContainer = $Panel/V/Scroll/Items

# 가방 창과 같은 나무 결 톤으로 맞춘다
const WOOD_BG := Color(0.55, 0.36, 0.2, 0.98)
const WOOD_EDGE := Color(0.29, 0.18, 0.09)
const TAB_ON := Color(0.28, 0.19, 0.1)
const TAB_OFF := Color(0.42, 0.29, 0.16)
const ROW_BG := Color(0.35, 0.23, 0.12, 0.55)
const ROW_HL := Color(0.5, 0.34, 0.18, 0.85)


func _ready() -> void:
	_style_panel()
	$Panel/V/Tabs/BuyBtn.pressed.connect(_on_tab.bind("buy"))
	$Panel/V/Tabs/SellBtn.pressed.connect(_on_tab.bind("sell"))
	$Panel/V/Tabs/AnimalBtn.pressed.connect(_on_tab.bind("animal"))
	$Panel/V/Tabs/UpgradeBtn.pressed.connect(_on_tab.bind("upgrade"))
	$Panel/V/Tabs/CodexBtn.pressed.connect(_on_tab.bind("codex"))
	$Panel/V/Tabs/CloseBtn.pressed.connect(close)


# 창 전체를 가방 창과 같은 결로 다듬는다 (가운데 정렬 + 나무 패널 + 머리글)
func _style_panel() -> void:
	var panel: PanelContainer = $Panel
	panel.offset_left = 200.0
	panel.offset_top = 56.0
	panel.offset_right = 760.0
	panel.offset_bottom = 470.0
	var st := StyleBoxFlat.new()
	st.bg_color = WOOD_BG
	st.border_color = WOOD_EDGE
	st.set_border_width_all(4)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", st)

	var v: VBoxContainer = $Panel/V
	v.add_theme_constant_override("separation", 6)

	_head = Label.new()
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_theme_font_size_override("font_size", 20)
	_head.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	v.add_child(_head)
	v.move_child(_head, 0)

	# 소지금은 동전 아이콘 + 숫자 (글자 'G' 대신 그림으로 읽히게)
	var mbox := HBoxContainer.new()
	mbox.alignment = BoxContainer.ALIGNMENT_END
	mbox.add_theme_constant_override("separation", 4)
	v.add_child(mbox)
	v.move_child(mbox, 1)

	_money_icon = TextureRect.new()
	_money_icon.custom_minimum_size = Vector2(20, 20)
	_money_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_money_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_money_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mbox.add_child(_money_icon)

	_money = Label.new()
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money.add_theme_font_size_override("font_size", 16)
	_money.add_theme_color_override("font_color", Color(1, 0.93, 0.72))
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mbox.add_child(_money)

	$Panel/V/Scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_box.add_theme_constant_override("separation", 3)
	$Panel/V/Tabs.add_theme_constant_override("separation", 4)


func _tab_style(on: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = TAB_ON if on else TAB_OFF
	st.border_color = Color(1, 0.84, 0.37) if on else WOOD_EDGE
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(4)
	return st


func _style_tabs() -> void:
	for key: String in TAB_BUTTONS:
		var b: Button = get_node("Panel/V/Tabs/" + TAB_BUTTONS[key])
		var on := key == tab
		b.custom_minimum_size = Vector2(76, 28)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("normal", _tab_style(on))
		b.add_theme_stylebox_override("hover", _tab_style(on))
		b.add_theme_stylebox_override("pressed", _tab_style(true))
		b.add_theme_color_override("font_color",
			Color(1, 0.9, 0.6) if on else Color(0.9, 0.85, 0.78))
	var cb: Button = $Panel/V/Tabs/CloseBtn
	cb.custom_minimum_size = Vector2(32, 28)
	cb.add_theme_stylebox_override("normal", _tab_style(false))
	cb.add_theme_stylebox_override("hover", _tab_style(true))


# 값은 글자 대신 아이콘으로 읽힌다: 골드는 동전, 목재는 통나무, 광석은 광석.
# costs = [["coin", 250], ["wood", 5], ["ore", 3]] 처럼 넘긴다.
const COST_ICONS := {"coin": "icon_coin", "wood": "icon_wood",
	"stone": "icon_stone", "ore": "ore"}


func _cost_box(costs: Array, enough := true) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_END
	for c in costs:
		var kind: String = c[0]
		var amount: int = int(c[1])
		if amount <= 0:
			continue
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(18, 18)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if main != null and main.tex.has(COST_ICONS[kind]):
			ic.texture = main.tex[COST_ICONS[kind]]
		box.add_child(ic)
		var l := Label.new()
		l.text = str(amount)
		l.add_theme_font_size_override("font_size", 15)
		# 못 사면 붉게 — 무엇이 모자란지 한눈에 보인다
		l.add_theme_color_override("font_color",
			Color(1, 0.88, 0.5) if enough else Color(0.95, 0.5, 0.45))
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(l)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(6, 0)
		box.add_child(pad)
	return box


# 목록 한 줄: 아이콘 + 이름/설명 + (값 아이콘) + 오른쪽 버튼
func _mk_row(icon_name: String, title_text: String, sub_text: String,
		btn: Button = null, costs: Array = []) -> PanelContainer:
	var wrap := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = ROW_BG
	st.set_corner_radius_all(3)
	st.set_content_margin_all(5)
	wrap.add_theme_stylebox_override("panel", st)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	wrap.add_child(h)

	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if main != null and icon_name != "" and main.tex.has(icon_name):
		ic.texture = main.tex[icon_name]
	h.add_child(ic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	h.add_child(col)

	var t := Label.new()
	t.text = title_text
	t.clip_text = true
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color(0.98, 0.95, 0.9))
	col.add_child(t)
	if sub_text != "":
		var sl := Label.new()
		sl.text = sub_text
		sl.clip_text = true
		sl.add_theme_font_size_override("font_size", 13)
		sl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.66))
		col.add_child(sl)

	if not costs.is_empty():
		h.add_child(_cost_box(costs, btn == null or not btn.disabled))

	if btn != null:
		btn.custom_minimum_size = Vector2(84 if not costs.is_empty() else 120, 30)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_stylebox_override("normal", _tab_style(false))
		btn.add_theme_stylebox_override("hover", _tab_style(true))
		btn.add_theme_stylebox_override("pressed", _tab_style(true))
		h.add_child(btn)
	return wrap


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.34, 0.22, 0.1))
	items_box.add_child(l)


func _on_tab(t: String) -> void:
	if not allowed.has(t):
		return
	tab = t
	_rebuild()


# allowed_tabs: 이 가게에서 쓸 수 있는 탭 (비우면 t 하나만)
func open(t: String, allowed_tabs: Array = [], title := "") -> void:
	tab = t
	shop_title = title if title != "" else "상점"
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
	_style_tabs()
	if _head != null:
		_head.text = "- %s -" % shop_title
		_money.text = "%d" % GameData.money
		if main != null and main.tex.has("icon_coin"):
			_money_icon.texture = main.tex["icon_coin"]

	if tab == "buy":
		for id in GameData.CROP_IDS:
			var def: Dictionary = GameData.CROPS[id]
			if GameData.season() not in def.seasons:
				continue  # 제철 씨앗만 판매
			var price := GameData.seed_price(id)
			var b := _mk_button("구매", _on_buy.bind(id))
			b.disabled = GameData.money < price
			items_box.add_child(_mk_row("icon_seed", "%s 씨앗" % def.name,
				"보유 %d개 · 수확까지 %d시간" % [GameData.seeds[id], def.grow_days], b,
				[["coin", price]]))
		if GameData.merchant_discount():
			_note("민지와 친해져서 씨앗 10% 할인 중! ♥")
	elif tab == "sell":
		var any := false
		for id in GameData.CROP_IDS:
			var count: int = GameData.produce[id]
			if count <= 0:
				continue
			any = true
			var def: Dictionary = GameData.CROPS[id]
			var silver := int(GameData.produce_silver.get(id, 0))
			var gold := int(GameData.produce_gold.get(id, 0))
			var qtxt := "일반 %d" % (count - silver - gold)
			if silver > 0:
				qtxt += " · 은 %d" % silver
			if gold > 0:
				qtxt += " · 금 %d" % gold
			items_box.add_child(_mk_row("mature_" + id, "%s x%d" % [def.name, count], qtxt,
				_mk_button("전부 판매", _on_sell.bind(id)),
				[["coin", GameData.produce_sell_value(id)]]))
		for id in GameData.ITEM_IDS:
			var count: int = GameData.items[id]
			if count <= 0 or GameData.ITEMS[id].get("legend", false):
				continue  # 전설 재료는 팔 수 없다
			any = true
			var def: Dictionary = GameData.ITEMS[id]
			items_box.add_child(_mk_row(id, "%s x%d" % [def.name, count],
				"개당 %dG" % def.sell,
				_mk_button("전부 판매", _on_sell_item.bind(id)),
				[["coin", def.sell * count]]))
		if not any:
			_note("팔 수 있는 것이 없다. 수확물·생산물이 여기에 표시된다.")
	elif tab == "animal":
		for id in GameData.ANIMALS:
			var def: Dictionary = GameData.ANIMALS[id]
			var count := 0
			for a in main.animals:
				if a.type == id:
					count += 1
			var b := _mk_button("입양", _on_buy_animal.bind(id))
			b.disabled = GameData.money < def.price or main.animals.size() >= GameData.max_animals()
			items_box.add_child(_mk_row("%s_0" % id, "%s x%d" % [def.name, count],
				"%s 생산" % GameData.ITEMS[def.product].name, b, [["coin", def.price]]))
		_note("동물은 E로 쓰다듬으면 다음 날 아침 생산물을 준다. (최대 %d마리)"
			% GameData.max_animals())

		# 축사 건설
		if GameData.barn_built:
			items_box.add_child(_mk_row("barn", "축사 완공!",
				"동물 %d마리 · 굳은 날 자동 배부름" % GameData.BARN_MAX_ANIMALS))
		else:
			var bb := _mk_button("건설", func() -> void:
					main.build_barn()
					_rebuild())
			bb.disabled = GameData.money < GameData.BARN_COST_MONEY \
				or GameData.wood < GameData.BARN_COST_WOOD
			items_box.add_child(_mk_row("barn", "축사 건설",
				"동물 %d마리 · 비 오는 날 자동 배부름" % GameData.BARN_MAX_ANIMALS, bb,
				[["coin", GameData.BARN_COST_MONEY], ["wood", GameData.BARN_COST_WOOD]]))

		_note("— 펫 입양 (한 마리만 데리고 다닌다) —")
		for pid in GameData.PET_IDS:
			var pdef: Dictionary = GameData.PETS[pid]
			var pb: Button
			var pcost: Array = []
			if not GameData.owned_pets.has(pid):
				pb = _mk_button("입양", _on_buy_pet.bind(pid))
				pb.disabled = GameData.money < int(pdef.price)
				pcost = [["coin", int(pdef.price)]]
			elif GameData.active_pet == pid:
				pb = _mk_button("쉬게 하기", _on_select_pet.bind(""))
			else:
				pb = _mk_button("데려가기", _on_select_pet.bind(pid))
			items_box.add_child(_mk_row("pet_%s_0" % pid, str(pdef.name),
				str(pdef.passive), pb, pcost))
	elif tab == "codex":
		_note("— 물고기 도감 —")
		for f in GameData.FISH:
			var id: String = f[0]
			var caught := int(GameData.fish_caught.get(id, 0))
			if caught > 0:
				items_box.add_child(_mk_row(id, str(GameData.ITEMS[id].name),
					"%d마리 낚음 · %dG" % [caught, GameData.ITEMS[id].sell]))
			else:
				items_box.add_child(_mk_row("", "???", "아직 낚지 못했다"))
		_note("— 몬스터 도감 —")
		for mid in GameData.MOBS:
			var kills := int(GameData.mob_kills.get(mid, 0))
			if kills > 0:
				items_box.add_child(_mk_row("%s_0" % mid, str(GameData.MOBS[mid].name),
					"%d마리 처치 · %s" % [kills, GameData.MOBS[mid].desc]))
			else:
				items_box.add_child(_mk_row("", "???", "동굴에서 만나보자"))
		_note("— 요리 도감 —")
		for rid in GameData.RECIPE_IDS:
			var made := int(GameData.recipes_cooked.get(rid, 0))
			if made > 0:
				items_box.add_child(_mk_row(rid, str(GameData.ITEMS[rid].name),
					"%d번 요리 · %dG" % [made, GameData.ITEMS[rid].sell]))
			else:
				items_box.add_child(_mk_row("", "???", "집 조리대에서 만들어보자"))
		_note("낚싯대를 들고 물가에서 E! 입질(!)이 오면 다시 E!\n"
			+ "철수와 친해지면(호감도 50+) 판정 구간이 넓어진다.")
	else:
		for id in GameData.UPGRADES:
			var up: Dictionary = GameData.UPGRADES[id]
			var levels: Array = up.levels
			var level: int = GameData.tool_level.get(id, 1)
			var st: Dictionary = GameData.tool_stats(id)
			var stat_line := "위력 %s · 범위 %s · 기력 %s · 행운 %s" % [
				GameData.fmt_stat(st.power), GameData.fmt_stat(st.reach),
				GameData.fmt_stat(st.stamina), GameData.fmt_stat(st.luck)]
			var icon: String = "icon_" + ("water" if id == "water" else id)
			if level - 1 >= levels.size():
				items_box.add_child(_mk_row(icon, "%s Lv.%d (최대)" % [up.name, level],
					stat_line))
				continue
			var next: Dictionary = levels[level - 1]
			var b := _mk_button("강화", _on_upgrade.bind(id))
			b.disabled = GameData.money < next.money or GameData.wood < next.wood \
				or GameData.items["ore"] < next.ore
			var gain := GameData.tool_stat_gain_text(id)
			var sub := "%s → %s" % [stat_line, next.desc]
			if gain != "":
				sub = "%s   (%s)" % [next.desc, gain]
			items_box.add_child(_mk_row(icon,
				"%s Lv.%d → %d" % [up.name, level, level + 1], sub, b,
				[["coin", int(next.money)], ["wood", int(next.wood)],
				["ore", int(next.ore)]]))
		_note("광석은 동굴(마을 북쪽)에서! 울타리: 목재 %d · 스프링클러: 목재 %d+석재 %d" % [
			GameData.FENCE_COST_WOOD, GameData.SPRINKLER_COST_WOOD,
			GameData.SPRINKLER_COST_STONE])


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
	var amount: int = GameData.produce_sell_value(id)  # 은/금 품질은 더 비싸게
	Sound.play_sfx("sfx_coin")
	GameData.money += amount
	GameData.today_earned += amount
	GameData.produce[id] = 0
	GameData.produce_silver[id] = 0
	GameData.produce_gold[id] = 0
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
