# 상점 UI: 씨앗 구매 / 작물 판매 (가게마다 허용된 탭만 보인다)
extends CanvasLayer

const TAB_BUTTONS := {
	"buy": "BuyBtn", "sell": "SellBtn", "animal": "AnimalBtn",
	"upgrade": "UpgradeBtn", "craft": "CraftBtn", "codex": "CodexBtn",
}

var main: Node2D
var tab := "buy"
var allowed: Array = TAB_BUTTONS.keys()
var shop_title := "상점"
# 선반 구매: 잡화점 선반에서 열면 그 카테고리만 보인다
#   "" = 전부 / seed 씨앗 / life 생활용품 / tool 도구·부품 / misc 기타
var buy_cat := ""
var sell_mult := 1.0       # 판매 배율 (쓰레기통 무인 판매 = 0.8)
var last_sell_cells := 0   # 검증용 — 판매 격자에 깔린 칸 수
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
	$Panel/V/Tabs/CraftBtn.pressed.connect(_on_tab.bind("craft"))
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
	"stone": "icon_stone", "ore": "ore", "star_shard": "star_shard", "gem": "gem"}


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


# 판매 격자 한 칸: 일러스트 + 작은 수량. 정보는 호버 툴팁으로만 보여 준다.
func _mk_sell_cell(icon_name: String, title: String, count: int,
		unit: int, total: int, sub: String, on_sell: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(50, 50)
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.09, 0.16, 0.85)
	st.border_color = Color(0.32, 0.27, 0.43)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	var st2: StyleBoxFlat = st.duplicate()
	st2.border_color = Color(1, 0.84, 0.37)
	st2.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st2)
	b.add_theme_stylebox_override("pressed", st2)
	b.tooltip_text = "%s x%d\n개당 %dG · 전부 %dG%s\n(클릭: 전부 판매)" \
		% [title, count, unit, total, ("\n" + sub) if sub != "" else ""]
	if main != null and main.tex.has(icon_name):
		var ic := TextureRect.new()
		ic.texture = main.tex[icon_name]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 5
		ic.offset_top = 5
		ic.offset_right = -5
		ic.offset_bottom = -5
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
	var num := Label.new()
	num.text = str(count)
	num.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	num.offset_left = -34
	num.offset_top = -16
	num.offset_right = -3
	num.offset_bottom = -1
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.add_theme_font_size_override("font_size", 11)
	num.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	num.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.14))
	num.add_theme_constant_override("outline_size", 3)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(num)
	b.pressed.connect(on_sell)
	return b


func _on_tab(t: String) -> void:
	if not allowed.has(t):
		return
	tab = t
	_rebuild()


# allowed_tabs: 이 가게에서 쓸 수 있는 탭 (비우면 t 하나만)
# cat: 선반에서 열었을 때의 구매 카테고리 ("" = 전부)
# mult: 판매 배율 — 쓰레기통(무인 판매함)은 0.8로 연다
func open(t: String, allowed_tabs: Array = [], title := "", cat := "",
		mult := 1.0) -> void:
	tab = t
	buy_cat = cat
	sell_mult = mult
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
	# 구매 탭 이름은 열린 분류를 따른다 — 생활용품 선반을 열었는데
	# 탭이 「씨앗」으로 적혀 있던 버그를 고쳤다.
	$Panel/V/Tabs/BuyBtn.text = {"seed": "씨앗", "life": "생활용품",
		"tool": "도구", "misc": "기타", "stall": "노점"}.get(buy_cat, "구매")
	if _head != null:
		_head.text = "- %s -" % shop_title
		_money.text = "%d" % GameData.money
		if main != null and main.tex.has("icon_coin"):
			_money_icon.texture = main.tex["icon_coin"]

	if tab == "buy":
		if buy_cat == "stall":
			# 해변 노점: 낚시용품 + 잡화점 선반에는 없는 레시피
			_note("— 낚시용품 —")
			var bt := _mk_button("구매", _on_buy_bait)
			bt.disabled = GameData.money < GameData.BAIT_PRICE
			items_box.add_child(_mk_row("bait", "미끼",
				"보유 %d개 · 낚싯대를 던질 때 하나씩 쓴다 — 입질이 훨씬 빨라진다"
				% int(GameData.items.get("bait", 0)), bt, [["coin", GameData.BAIT_PRICE]]))
			_note("— 노점 한정 레시피 (집 조리대에서 만든다) —")
			for rid: String in GameData.STALL_RECIPE_IDS:
				var rname := str(GameData.ITEMS[rid].name)
				if not GameData.recipe_locked(rid):
					items_box.add_child(_mk_row(rid, "%s 레시피 (배움)" % rname,
						"재료를 모아 집 조리대에서 만들자"))
					continue
				var rprice := int(GameData.STALL_RECIPES[rid])
				var rb2 := _mk_button("구매", _on_buy_dish_recipe.bind(rid, rprice))
				rb2.disabled = GameData.money < rprice
				items_box.add_child(_mk_row(rid, "%s 레시피" % rname,
					"체력 +%d · 팔면 %dG" % [int(GameData.RECIPES[rid].energy),
						int(GameData.ITEMS[rid].sell)], rb2, [["coin", rprice]]))
			_note("민지가 노점에 있을 때만 살 수 있다. 판매는 언제든!")
		if buy_cat in ["", "seed"]:
			# 진열되는 씨앗은 shop_seeds에 있는 것뿐 — 처음에는 밀·옥수수 둘이고,
			# 게임을 진행하면서 하나씩 들어온다. 그중에서도 제철만 내놓는다.
			for id in GameData.CROP_IDS:
				if id not in GameData.shop_seeds:
					continue
				var def: Dictionary = GameData.CROPS[id]
				if GameData.season() not in def.seasons:
					continue  # 제철 씨앗만 판매
				var price := GameData.seed_price(id)
				var b := _mk_button("구매", _on_buy.bind(id))
				b.disabled = GameData.money < price
				items_box.add_child(_mk_row("icon_seed", "%s 씨앗" % def.name,
					"보유 %d개 · 수확까지 %d시간" % [GameData.seeds[id], def.grow_days], b,
					[["coin", price]]))
			_note("새 씨앗은 마을이 자라면 하나씩 들어온다.")
			if GameData.merchant_discount():
				_note("민지와 친해져서 씨앗 10% 할인 중! ♥")
		if buy_cat in ["", "tool"]:
			# 부품 — 제작대(집 책상)에서 가구를 만들 때 쓴다
			_note("— 도구 부품 (제작대 재료) —")
			for pid: String in ["nail", "cloth", "rope"]:
				var pdef: Dictionary = GameData.ITEMS[pid]
				var pprice := int(pdef.sell) * 2
				var pb2 := _mk_button("구매", _on_buy_part.bind(pid, pprice))
				pb2.disabled = GameData.money < pprice
				items_box.add_child(_mk_row(pid, str(pdef.name),
					"보유 %d개" % GameData.items[pid], pb2, [["coin", pprice]]))
		if buy_cat in ["", "life"]:
			# 레시피 — 사면 집 책상(제작대)에서 만들 수 있게 된다
			_note("— 생활용품 레시피 —")
			if "broom" in GameData.recipes_unlocked:
				items_box.add_child(_mk_row("broom", "빗자루 레시피 (배움)",
					"집 책상에서 만든다 — 잡초 1"))
			else:
				var rcp := _mk_button("구매", _on_buy_recipe.bind("broom", 300))
				rcp.disabled = GameData.money < 300
				items_box.add_child(_mk_row("broom", "빗자루 레시피",
					"집 안의 먼지를 쓸어 낸다 · 재료: 잡초 1", rcp, [["coin", 300]]))
			if "flower_pot" in GameData.recipes_unlocked:
				items_box.add_child(_mk_row("flower_pot", "화분 레시피 (배움)",
					"집 책상에서 만든다 — 잡초 5"))
			else:
				var pcp := _mk_button("구매", _on_buy_recipe.bind("flower_pot", 200))
				pcp.disabled = GameData.money < 200
				items_box.add_child(_mk_row("flower_pot", "화분 레시피",
					"집을 꾸미는 화분 · 재료: 잡초 5", pcp, [["coin", 200]]))
			# 쓰레기통 — 24시간 무인 판매함 (제값의 80%). 원하는 곳에 설치한다.
			if "trash_bin" in GameData.recipes_unlocked:
				items_box.add_child(_mk_row("trash_bin", "쓰레기통 레시피 (배움)",
					"집 책상에서 만든다 — 목재 5 · 금속 고리 2 (고리는 해변에서)"))
			else:
				var tcp := _mk_button("구매", _on_buy_recipe.bind("trash_bin", 400))
				tcp.disabled = GameData.money < 400
				items_box.add_child(_mk_row("trash_bin", "쓰레기통 레시피",
					"24시간 무인 판매함 (제값의 80%) · 재료: 목재 5 · 금속 고리 2",
					tcp, [["coin", 400]]))
			# 집터 — 새 주민의 집을 짓는 큰 공사 (스토리 3에서 이장이 알려준다)
			if GameData.move_quest in ["build", "wait", "greet", "done"]:
				if "housing_kit" in GameData.recipes_unlocked:
					items_box.add_child(_mk_row("housing_kit", "집터 레시피 (배움)",
						"집 책상에서 만든다 — 목재 60 · 석재 40 · 못 4"))
				else:
					var hcp := _mk_button("구매",
						_on_buy_recipe.bind("housing_kit", GameData.HOUSING_KIT_PRICE))
					hcp.disabled = GameData.money < GameData.HOUSING_KIT_PRICE
					items_box.add_child(_mk_row("housing_kit", "집터 레시피",
						"빈 집터를 마련한다 (이주 수락의 선행 조건) · 재료: 목재 60 · 석재 40 · 못 4",
						hcp, [["coin", GameData.HOUSING_KIT_PRICE]]))
		if buy_cat in ["", "misc"]:
			# 마음을 전하는 것들
			_note("— 마음을 전하는 것 —")
			var fb := _mk_button("구매", _on_buy_gift.bind("bouquet", GameData.BOUQUET_PRICE))
			fb.disabled = GameData.money < GameData.BOUQUET_PRICE
			items_box.add_child(_mk_row("bouquet", "꽃다발",
				"보유 %d개 · 마음이 있는 사람에게 (호감도 60 이상)" % GameData.items["bouquet"],
				fb, [["coin", GameData.BOUQUET_PRICE]]))
			if buy_cat == "misc":
				_note("새 물건이 들어오면 이 선반에 놓인다.")
	elif tab == "sell":
		# 판매: 가방과 같은 격자 — 일러스트만 보이고, 마우스를 올리면
		# 이름·판매 가격이 툴팁으로 뜬다. 클릭하면 그 묶음을 전부 판다.
		last_sell_cells = 0
		if sell_mult < 1.0:
			_note("무인 판매함 — 24시간 아무 때나, 대신 제값의 %d%%로 팔린다."
				% int(sell_mult * 100.0))
		_note("가방과 같은 격자다. 마우스를 올리면 이름·가격 · 클릭: 전부 판매")
		var grid := GridContainer.new()
		grid.columns = 9
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for id in GameData.CROP_IDS:
			var count: int = GameData.produce[id]
			if count <= 0:
				continue
			var def: Dictionary = GameData.CROPS[id]
			var silver := int(GameData.produce_silver.get(id, 0))
			var gold := int(GameData.produce_gold.get(id, 0))
			var qtxt := "일반 %d" % (count - silver - gold)
			if silver > 0:
				qtxt += " · 은 %d" % silver
			if gold > 0:
				qtxt += " · 금 %d" % gold
			grid.add_child(_mk_sell_cell("mature_" + id, str(def.name), count,
				int(def.sell_price * sell_mult),
				int(GameData.produce_sell_value(id) * sell_mult),
				qtxt, _on_sell.bind(id)))
			last_sell_cells += 1
		for id in GameData.ITEM_IDS:
			var count: int = GameData.items[id]
			if count <= 0 or GameData.ITEMS[id].get("legend", false):
				continue  # 전설 재료는 팔 수 없다
			var def: Dictionary = GameData.ITEMS[id]
			if int(def.sell) <= 0:
				continue  # 값이 없는 것(빗자루·꽃다발 등)은 팔지 않는다
			grid.add_child(_mk_sell_cell(id, str(def.name), count,
				int(def.sell * sell_mult), int(def.sell * sell_mult) * count,
				"", _on_sell_item.bind(id)))
			last_sell_cells += 1
		items_box.add_child(grid)
		if last_sell_cells == 0:
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

		# 탈 것 — 넓어진 세상을 빠르게 다닌다
		_note("— 탈 것 —")
		if GameData.has_horse:
			items_box.add_child(_mk_row("horse_side_0", "말",
				"이동 속도 %d%% · 농장에 세워 두었다 (E로 탄다)"
				% int(GameData.HORSE_SPEED_MULT * 100.0)))
		else:
			var hb := _mk_button("사기", _on_buy_horse)
			hb.disabled = GameData.money < GameData.HORSE_PRICE
			items_box.add_child(_mk_row("horse_side_0", "말",
				"타면 훨씬 빨리 다닌다 (탄 동안에는 도구를 쓸 수 없다)", hb,
				[["coin", GameData.HORSE_PRICE]]))

		# 축사 건설
		if GameData.barn_built:
			items_box.add_child(_mk_row("barn", "축사 완공!",
				"동물 %d마리 · 굳은 날 자동 배부름" % GameData.BARN_MAX_ANIMALS))
		else:
			var bb := _mk_button("건설", func() -> void:
					main.toolwork.build_barn()
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
		for id: String in GameData.FISH_IDS:
			var caught := int(GameData.fish_caught.get(id, 0))
			if caught > 0:
				var when := GameData.discovered_on(id)
				items_box.add_child(_mk_row(id, str(GameData.ITEMS[id].name),
					"%d마리 낚음 · %dG%s" % [caught, GameData.ITEMS[id].sell,
						("" if when == "" else " · 처음: " + when)]))
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
	elif tab == "craft":
		# 청혼 반지 — 대장간에서만 벼릴 수 있다
		_note("— 특별 주문 —")
		var rb := _mk_button("주문", _on_buy_gift.bind("wedding_ring", GameData.RING_PRICE))
		rb.disabled = GameData.money < GameData.RING_PRICE
		items_box.add_child(_mk_row("wedding_ring", "청혼 반지",
			"보유 %d개 · 연인에게 (호감도 100)" % GameData.items["wedding_ring"],
			rb, [["coin", GameData.RING_PRICE]]))
		# 부품 — 경첩은 대장간에서만 (제작대 손보기 재료)
		var hdef: Dictionary = GameData.ITEMS["hinge"]
		var hprice := int(hdef.sell) * 2
		var hb2 := _mk_button("구매", _on_buy_part.bind("hinge", hprice))
		hb2.disabled = GameData.money < hprice
		items_box.add_child(_mk_row("hinge", str(hdef.name),
			"보유 %d개 · 제작대 손보기에 쓴다" % GameData.items["hinge"], hb2,
			[["coin", hprice]]))
		# 대장간 제작: 부위별로 묶어 보여 준다
		for slot: String in GameData.GEAR_SLOTS:
			var eq: String = str(GameData.equipped.get(slot, ""))
			_note("— %s (%s) —" % [GameData.GEAR_SLOT_NAMES[slot],
				GameData.GEAR[eq].name if eq != "" else "없음"])
			for gid: String in GameData.GEAR_IDS:
				var g: Dictionary = GameData.GEAR[gid]
				if str(g.slot) != slot:
					continue
				# 재료를 겪어 보기 전에는 무쇠가 그림만 보여 준다 (기본 컨셉 1)
				if not GameData.gear_known(gid):
					items_box.add_child(_mk_row("", "???",
						"「가져와 본 적 없는 재료는 벼릴 수 없네.」 — 새 재료를 구해 오자"))
					continue
				var sub: String = "%s · %s" % [GameData.gear_stat_text(gid), g.desc]
				if GameData.owned_gear.has(gid):
					if eq == gid:
						items_box.add_child(_mk_row(gid, "%s (장착 중)" % g.name, sub,
							_mk_button("해제", _on_unequip.bind(slot))))
					else:
						items_box.add_child(_mk_row(gid, g.name, sub,
							_mk_button("장착", _on_equip.bind(gid))))
					continue
				var cb := _mk_button("제작", _on_craft.bind(gid))
				cb.disabled = not GameData.can_craft_gear(gid)
				items_box.add_child(_mk_row(gid, g.name, sub, cb, _gear_cost(gid)))
		_note("장비는 만들면 바로 장착된다. 가방(I)의 「장비」 탭에서도 바꿀 수 있다.")
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


func _gear_cost(gid: String) -> Array:
	var cost: Dictionary = GameData.GEAR[gid].cost
	var out: Array = []
	for k: String in ["money", "wood", "stone", "ore", "star_shard", "gem"]:
		if cost.has(k):
			out.append(["coin" if k == "money" else k, int(cost[k])])
	return out


func _on_craft(gid: String) -> void:
	if not GameData.craft_gear(gid):
		return
	Sound.play_sfx("sfx_place")
	if main != null:
		main.hud.show_message("%s 완성! 바로 장착했다." % GameData.GEAR[gid].name)
	_rebuild()


func _on_equip(gid: String) -> void:
	GameData.equip_gear(gid)
	Sound.play_sfx("sfx_ui")
	_rebuild()


func _on_unequip(slot: String) -> void:
	GameData.unequip_slot(slot)
	Sound.play_sfx("sfx_ui")
	_rebuild()


func _on_buy(id: String) -> void:
	var price := GameData.seed_price(id)
	if GameData.money < price:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= price
	GameData.seeds[id] += 1
	GameData.today_spent += price
	if main != null and not main._remote_acting:
		main.doing.net_shop("buy_seed", id)
	_rebuild()


func _on_sell(id: String) -> void:
	# 은/금 품질은 더 비싸게 · 쓰레기통(무인 판매함)은 제값의 80%
	var amount: int = int(GameData.produce_sell_value(id) * sell_mult)
	Sound.play_sfx("sfx_coin")
	GameData.money += amount
	GameData.today_earned += amount
	GameData.produce[id] = 0
	GameData.produce_silver[id] = 0
	GameData.produce_gold[id] = 0
	if main != null and not main._remote_acting:
		main.doing.net_shop("sell_crop", id)
	_rebuild()


func _on_sell_item(id: String) -> void:
	var def: Dictionary = GameData.ITEMS[id]
	var amount: int = int(def.sell * sell_mult) * int(GameData.items[id])
	Sound.play_sfx("sfx_coin")
	GameData.money += amount
	GameData.today_earned += amount
	GameData.items[id] = 0
	if main != null and not main._remote_acting:
		main.doing.net_shop("sell_item", id)
	_rebuild()


func _on_buy_animal(id: String) -> void:
	var def: Dictionary = GameData.ANIMALS[id]
	if GameData.money < def.price or main.animals.size() >= GameData.MAX_ANIMALS:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= def.price
	GameData.today_spent += def.price
	main.farming.spawn_animal(id)
	# 가게는 마을에 있지만 동물은 농장으로 간다 — 어디로 갔는지 알려 준다
	main.hud.show_message("%s를 들였다! **농장(맵 서쪽)** 에서 기다린다. (지도 M)"
		% def.name, 5.0)
	if main != null and not main._remote_acting:
		main.doing.net_shop("buy_animal", id)
	_rebuild()


# 꽃다발·반지는 개수만 늘려 주면 된다 (쓰는 곳은 선물하기 쪽이다)
func _on_buy_gift(item_id: String, price: int) -> void:
	if GameData.money < price:
		return
	GameData.money -= price
	GameData.today_spent += price
	GameData.items[item_id] += 1
	Sound.play_sfx("sfx_coin")
	_rebuild()


# 부품 구매 — 겪은 것으로 기록된다 (제작대 목록이 이걸 본다)
func _on_buy_part(item_id: String, price: int) -> void:
	if GameData.money < price:
		return
	GameData.money -= price
	GameData.today_spent += price
	GameData.items[item_id] += 1
	GameData.discover(item_id)
	Sound.play_sfx("sfx_coin")
	_rebuild()


# 노점 낚시용품: 미끼 하나 (던질 때 자동으로 쓴다)
func _on_buy_bait() -> void:
	if GameData.money < GameData.BAIT_PRICE:
		return
	GameData.money -= GameData.BAIT_PRICE
	GameData.today_spent += GameData.BAIT_PRICE
	GameData.items["bait"] = int(GameData.items.get("bait", 0)) + 1
	GameData.discover("bait")
	Sound.play_sfx("sfx_coin")
	_rebuild()


# 노점 한정 요리 레시피 — 사면 집 조리대의 잠긴 칸이 열린다
func _on_buy_dish_recipe(id: String, price: int) -> void:
	if GameData.money < price or not GameData.recipe_locked(id):
		return
	GameData.money -= price
	GameData.today_spent += price
	GameData.recipes_unlocked.append(id)
	Sound.play_sfx("sfx_coin")
	main.hud.quest_toast("%s 레시피를 배웠다" % GameData.ITEMS[id].name)
	_rebuild()


# 레시피 구매 — 집 책상의 잠긴 칸이 열린다
func _on_buy_recipe(id: String, price: int) -> void:
	if GameData.money < price or id in GameData.recipes_unlocked:
		return
	GameData.money -= price
	GameData.today_spent += price
	GameData.recipes_unlocked.append(id)
	Sound.play_sfx("sfx_coin")
	main.hud.quest_toast("%s 레시피를 배웠다" % GameData.DESK_RECIPES[id].name)
	_rebuild()


func _on_buy_horse() -> void:
	if GameData.has_horse or GameData.money < GameData.HORSE_PRICE:
		return
	Sound.play_sfx("sfx_coin")
	GameData.money -= GameData.HORSE_PRICE
	GameData.today_spent += GameData.HORSE_PRICE
	GameData.has_horse = true
	if main != null:
		main.riding.place_horse()
		main.hud.show_message(
			"말을 샀다! **농장(맵 서쪽) 축사 앞** 에 세워 두었다.\n"
			+ "가까이 가서 **F** 를 누르면 탄다. (지도 M에 「말」로 표시된다)", 6.0)
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
		main.doing.net_shop("buy_pet", id)
	_rebuild()


func _on_select_pet(id: String) -> void:
	GameData.active_pet = id
	Sound.play_sfx("sfx_ui")
	if main != null and not main._remote_acting:
		main.doing.net_shop("select_pet", id)
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
		main.doing.net_shop("upgrade", id)
	_rebuild()
