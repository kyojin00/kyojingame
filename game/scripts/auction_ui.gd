# 경매장 창 — 광장 경매 게시판에서 E.
#
# 모든 플레이어가 함께 보는 장터다. 내가 값을 매겨 올리면 다른 농장 사람이
# 사 가고, 대금은 여기서 받아 간다. 통신은 auction_api가 맡고 이 파일은
# **그림과 손놀림만** 맡는다 — 성공/실패는 신호로 돌아온다.
#
# 세 칸으로 나뉜다.
#   장터    남들이 올린 것 (사기)
#   등록    내 창고에서 골라 값을 매겨 올리기
#   내 물건 내가 올린 것 (거두기) + 팔린 대금 받기
extends CanvasLayer

var main: Node2D
var api: Node

var _tab := "market"          # market / sell / mine
var _rows: Array = []         # 서버에서 받은 목록
var _status := ""             # 아래 줄에 뜨는 안내
var _loading := false
var _box: VBoxContainer
var _tabs: HBoxContainer
var _status_label: Label
# 등록 고르기 — 무엇을 얼마에 몇 개
var _pick_cat := ""
var _pick_id := ""
var _pick_quality := 0
var _pick_qty := 1
var _pick_price := 0
# 금고 — 서버가 쥔 창고 (여기 있는 것만 장터에 올릴 수 있다)
var _vault := {}          # {gold, items[], left_value, left_gold}
var _vault_loaded := false
var _gold_amt := 1000     # 금고에 넣고 뺄 돈 — 직접 쳐 넣을 수 있다


func _ready() -> void:
	layer = 24
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(150, 60)
	panel.custom_minimum_size = Vector2(660, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.24, 0.98)
	style.border_color = Color(0.62, 0.52, 0.34)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 교진 장터 (E/ESC: 닫기) -"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("ffd75e"))
	v.add_child(title)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	v.add_child(_tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(636, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_box)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.76, 0.68))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status_label)

	api = preload("res://scripts/auction_api.gd").new()
	add_child(api)
	api.fetched.connect(_on_fetched)
	api.listed.connect(_on_listed)
	api.bought.connect(_on_bought)
	api.claimed.connect(_on_claimed)
	api.vault.connect(_on_vault)
	api.moved.connect(_on_moved)


func open() -> void:
	visible = true
	_tab = "market"
	_status = ""
	_refresh()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_loading = true
	_rebuild()
	if _tab == "vault" or _tab == "sell":
		api.vault_state()
		return
	api.fetch(_tab == "mine")


func _on_vault(state: Dictionary) -> void:
	_vault = state
	_vault_loaded = true
	_loading = false
	_rebuild()


func _on_moved(ok: bool, msg: String) -> void:
	_status = msg
	if ok:
		Sound.play_sfx("sfx_coin")
	api.vault_state()


# 금고에 든 개수 (장터에 올릴 때 이만큼까지 된다)
func _vault_qty(cat: String, id: String, quality: int) -> int:
	for it: Dictionary in _vault.get("items", []):
		if str(it.get("cat", "")) == cat and str(it.get("item_id", "")) == id \
				and int(it.get("quality", 0)) == quality:
			return int(it.get("qty", 0))
	return 0


# ---- 서버 응답 ----

func _on_fetched(rows: Array) -> void:
	_rows = rows
	_loading = false
	_rebuild()


func _on_listed(ok: bool, msg: String, fee: int) -> void:
	_status = msg
	if ok:
		Sound.play_sfx("sfx_coin")        # 수수료는 금고 돈에서 서버가 뗀다
		_pick_id = ""
		_tab = "mine"
		_refresh()
	else:
		_rebuild()   # 금고에서 빠지지 않았으니 돌려줄 것이 없다


func _on_bought(ok: bool, msg: String, row: Dictionary) -> void:
	_status = msg
	if ok:
		Sound.play_sfx("sfx_coin")
		# 산 물건도, 거둔 물건도 **금고로** 들어간다 (돈도 금고에서 오간다).
		# 게임 창고로 가져오려면 「금고」 칸에서 꺼내면 된다.
		_refresh()
	else:
		_rebuild()


func _on_claimed(count: int, gold: int) -> void:
	if count <= 0:
		_status = "받아 갈 대금이 없다."
	else:
		GameData.money += gold
		Sound.play_sfx("sfx_coin")
		_status = "%d건 대금 %dG를 받았다!" % [count, gold]
		_sync("", "", 0, 0, gold)
	_refresh()


# ---- 창고 넣고 빼기 ----

# 함께하기: 지갑·창고가 공용이라 장터에서 오간 것을 세계에도 알린다
func _sync(cat: String, id: String, qty: int, quality: int, money_delta: int) -> void:
	if main == null:
		return
	if Net.active():
		main.doing.net_auction(cat, id, qty, quality, money_delta)
	# 장터에 넘긴 물건과 받은 대금은 **곧바로** 저장한다. 안 그러면 등록해 놓고
	# 게임을 끄면 물건이 창고에도 남고 장터에도 남는다 (복제).
	main.saveio.save_now()


func _take_out(cat: String, id: String, qty: int, quality: int) -> bool:
	if cat == "tool":
		if not GameData.is_tool_unlocked(id):
			return false
		GameData.unlocked_tools.erase(id)          # 손에서 떠난다
		var slot := GameData.tool_slots.find(id)   # 빠른 슬롯에서도 뺀다
		if slot >= 0:
			GameData.tool_slots[slot] = ""
		if GameData.tool == id:
			GameData.tool = ""
		_sync(cat, id, -qty, quality, 0)
		return true
	match cat:
		"seed":
			if int(GameData.seeds.get(id, 0)) < qty:
				return false
			GameData.seeds[id] = int(GameData.seeds[id]) - qty
		"produce":
			var have: int = int(GameData.produce.get(id, 0))
			var pool := have
			match quality:
				1:
					pool = int(GameData.produce_silver.get(id, 0))
				2:
					pool = int(GameData.produce_gold.get(id, 0))
				_:
					pool = have - int(GameData.produce_silver.get(id, 0)) \
						- int(GameData.produce_gold.get(id, 0))
			if pool < qty:
				return false
			GameData.produce[id] = have - qty
			if quality == 1:
				GameData.produce_silver[id] = int(GameData.produce_silver[id]) - qty
			elif quality == 2:
				GameData.produce_gold[id] = int(GameData.produce_gold[id]) - qty
		_:
			if id == "wood":
				if GameData.wood < qty:
					return false
				GameData.wood -= qty
			elif id == "stone":
				if GameData.stone < qty:
					return false
				GameData.stone -= qty
			else:
				if int(GameData.items.get(id, 0)) < qty:
					return false
				GameData.items[id] = int(GameData.items[id]) - qty
	_sync(cat, id, -qty, quality, 0)
	return true


func _give_back(cat: String, id: String, qty: int, quality: int) -> void:
	if id == "" or qty <= 0:
		return
	if cat == "tool":
		if not GameData.unlocked_tools.has(id):
			GameData.unlocked_tools.append(id)
		# 등급은 더 좋은 쪽으로 (내 것이 이미 더 좋으면 그대로)
		if GameData.tool_level.has(id):
			GameData.tool_level[id] = maxi(int(GameData.tool_level[id]), maxi(1, quality))
		return
	match cat:
		"seed":
			GameData.seeds[id] = int(GameData.seeds.get(id, 0)) + qty
		"produce":
			GameData.produce[id] = int(GameData.produce.get(id, 0)) + qty
			if quality == 1:
				GameData.produce_silver[id] = int(GameData.produce_silver.get(id, 0)) + qty
			elif quality == 2:
				GameData.produce_gold[id] = int(GameData.produce_gold.get(id, 0)) + qty
		_:
			if id == "wood":
				GameData.wood += qty
			elif id == "stone":
				GameData.stone += qty
			else:
				GameData.items[id] = int(GameData.items.get(id, 0)) + qty


# ---- 이름·아이콘 ----

# 도구 그림 이름은 규칙이 아니라 표다 (가방 창과 같은 값)
const TOOL_ICONS := {
	"hoe": "icon_hoe", "water": "icon_water", "seed": "icon_seed",
	"axe": "icon_axe", "pickaxe": "icon_pickaxe", "fence": "fence",
	"sprinkler": "sprinkler", "rod": "icon_rod",
	"spear": "icon_spear", "sword": "icon_sword",
}
const TOOL_NAMES := {
	"hoe": "호미", "water": "물뿌리개", "seed": "씨앗 주머니", "axe": "도끼",
	"pickaxe": "곡괭이", "fence": "울타리", "sprinkler": "스프링클러",
	"rod": "낚싯대", "spear": "작살", "sword": "검",
}


func _label_of(cat: String, id: String, quality: int) -> String:
	var nm := id
	match cat:
		"tool":
			nm = str(TOOL_NAMES.get(id, id))
			if quality > 1:
				nm += " +%d" % (quality - 1)
		"seed":
			if GameData.CROPS.has(id):
				nm = "%s 씨앗" % str(GameData.CROPS[id].name)
		"produce":
			if GameData.CROPS.has(id):
				nm = str(GameData.CROPS[id].name)
			var q: String = ["", "은빛 ", "금빛 "][clampi(quality, 0, 2)]
			nm = q + nm
		_:
			if id == "wood":
				nm = "목재"
			elif id == "stone":
				nm = "석재"
			elif GameData.ITEMS.has(id):
				nm = str(GameData.ITEMS[id].name)
	return nm


func _icon_of(cat: String, id: String) -> String:
	match cat:
		"seed":
			return "icon_seed"
		"produce":
			return "mature_" + id
	if cat == "tool":
		return str(TOOL_ICONS.get(id, "icon_" + id))
	if id == "wood":
		return "icon_wood"
	if id == "stone":
		return "icon_stone"
	return id


# ---- 그리기 ----

func _mk_tab(key: String, text: String) -> void:
	var b := Button.new()
	b.text = ("▶ " if _tab == key else "") + text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = _tab == key
	b.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		_tab = key
		_status = ""
		_pick_id = ""
		_refresh())
	_tabs.add_child(b)


func _line(text: String, color := Color(0.88, 0.84, 0.76)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)
	return l


# 물건 한 줄 — 아이콘 + 이름/개수 + 값 + 단추
func _mk_row(cat: String, id: String, quality: int, qty: int, sub: String,
		btn_text: String, cb: Callable, btn_on := true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tn := _icon_of(cat, id)
	if main != null and main.tex.has(tn):
		icon.texture = main.tex[tn]
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new()
	t.text = "%s x%d" % [_label_of(cat, id, quality), qty]
	t.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	col.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_color_override("font_color", Color(0.74, 0.7, 0.64))
	col.add_child(s)
	row.add_child(col)
	if btn_text != "":
		var b := Button.new()
		b.text = btn_text
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not btn_on
		b.pressed.connect(func() -> void:
			Sound.play_sfx("sfx_ui")
			cb.call())
		row.add_child(b)
	_box.add_child(row)


func _rebuild() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for c in _box.get_children():
		c.queue_free()
	_mk_tab("market", "장터 둘러보기")
	_mk_tab("vault", "금고")
	_mk_tab("sell", "올리기")
	_mk_tab("mine", "내 등록")
	_status_label.text = _status if _status != "" else \
		"내 이름: %s · 소지금 %dG · 금고 %dG (장터는 금고 돈으로 산다)" \
		% [GameData.seller_name(), GameData.money, int(_vault.get("gold", 0))]
	match _tab:
		"vault":
			_build_vault()
		"sell":
			_build_sell()
		"mine":
			_build_mine()
		_:
			_build_market()


# 장터 — 남들이 올린 것
func _build_market() -> void:
	if _loading:
		_line("장터를 둘러보는 중...")
		return
	if _rows.is_empty():
		_line("아직 올라온 물건이 없다. 첫 손님이 되어 보자!")
		return
	for r: Dictionary in _rows:
		var price := int(r.get("price", 0))
		# 장터 목록에는 남의 열쇠가 실리지 않는다 — 내 글인지는 서버가 판단해
		# 「내가 올린 물건은 살 수 없다」로 걸러 준다
		var sub := "%dG · %s" % [price, str(r.get("seller_name", "?"))]
		_mk_row(str(r.get("cat", "item")), str(r.get("item_id", "")),
			int(r.get("quality", 0)), int(r.get("qty", 1)), sub,
			"사기", func() -> void: api.buy(int(r.get("id", 0))))


# 내 물건 — 올려 둔 것 거두기 + 대금 받기
func _build_mine() -> void:
	_line("팔리면 대금이 곧바로 금고에 들어간다. (「금고」 칸에서 꺼내자)",
		Color(0.7, 0.68, 0.62))
	if _loading:
		_line("내 물건을 살펴보는 중...")
		return
	var any := false
	for r: Dictionary in _rows:
		var st := str(r.get("status", ""))
		if st == "cancelled":
			continue
		any = true
		var sold := st == "sold"
		var sub := "%dG · " % int(r.get("price", 0))
		if sold:
			sub += "%s에게 팔림 · 대금은 금고에" % str(r.get("buyer_name", "누군가"))
		else:
			sub += "팔리는 중"
		_mk_row(str(r.get("cat", "item")), str(r.get("item_id", "")),
			int(r.get("quality", 0)), int(r.get("qty", 1)), sub,
			"" if sold else "거두기",
			func() -> void: api.cancel(int(r.get("id", 0))))
	if not any:
		_line("올려 둔 물건이 없다.")


# 등록 — 창고에서 고르고 값을 매긴다
# 금고 — 게임 창고에서 넣고, 금고에서 빼고, 돈도 오간다
func _build_vault() -> void:
	if _loading and not _vault_loaded:
		_line("금고를 여는 중...")
		return
	var gold := int(_vault.get("gold", 0))
	_line("금고 돈 %dG · 오늘 더 넣을 수 있는 값 %dG · 돈 %dG"
		% [gold, int(_vault.get("left_value", 0)), int(_vault.get("left_gold", 0))],
		Color(0.95, 0.8, 0.5))
	_line("장터는 금고 안에서만 돈다 — 올릴 물건과 수수료·물건값을 여기 넣어 두자.",
		Color(0.7, 0.68, 0.62))

	# 돈 넣고 빼기 — 얼마를 넣고 뺄지 **직접 쳐 넣는다**
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 6)
	var gl := Label.new()
	gl.text = "돈"
	gl.custom_minimum_size = Vector2(40, 0)
	grow.add_child(gl)
	grow.add_child(_num_edit(_gold_amt, 110,
		func(n: int) -> void: _gold_amt = n))
	var bin := Button.new()
	bin.text = "넣기"
	bin.focus_mode = Control.FOCUS_NONE
	bin.pressed.connect(func() -> void:
		var amt := _gold_amt
		if amt <= 0:
			_status = "넣을 돈을 적자."
			_rebuild()
			return
		if GameData.money < amt:
			_status = "가진 돈이 모자란다. (%dG 있다)" % GameData.money
			_rebuild()
			return
		if amt > int(_vault.get("left_gold", 0)):
			_status = "오늘 더 넣을 수 있는 돈은 %dG까지다." % int(_vault.get("left_gold", 0))
			_rebuild()
			return
		Sound.play_sfx("sfx_ui")
		GameData.money -= amt
		_sync("", "", 0, 0, -amt)
		api.vault_deposit("", "", 0, 0, amt))
	grow.add_child(bin)
	var bout := Button.new()
	bout.text = "빼기"
	bout.focus_mode = Control.FOCUS_NONE
	bout.pressed.connect(func() -> void:
		var amt := _gold_amt
		if amt <= 0:
			_status = "뺄 돈을 적자."
			_rebuild()
			return
		if gold < amt:
			_status = "금고에 든 돈이 모자란다. (%dG 있다)" % gold
			_rebuild()
			return
		Sound.play_sfx("sfx_ui")
		GameData.money += amt
		_sync("", "", 0, 0, amt)
		api.vault_withdraw("", "", 0, 0, amt))
	grow.add_child(bout)
	# 자주 쓰는 값은 눌러서 채운다
	for amt3 in [1000, 10000, 100000]:
		var bp := Button.new()
		bp.text = str(amt3)
		bp.focus_mode = Control.FOCUS_NONE
		bp.pressed.connect(func() -> void:
			Sound.play_sfx("sfx_ui")
			_gold_amt = amt3
			_rebuild())
		grow.add_child(bp)
	_box.add_child(grow)

	# 금고에 든 물건 — 눌러서 하나씩 뺀다
	_line("금고 속 (누르면 하나 꺼낸다)", Color(0.9, 0.86, 0.7))
	var vg := GridContainer.new()
	vg.columns = 9
	vg.add_theme_constant_override("h_separation", 5)
	vg.add_theme_constant_override("v_separation", 5)
	var anyv := false
	for it: Dictionary in _vault.get("items", []):
		var n := int(it.get("qty", 0))
		if n <= 0:
			continue
		anyv = true
		var cat := str(it.get("cat", "item"))
		var id := str(it.get("item_id", ""))
		var q := int(it.get("quality", 0))
		vg.add_child(_mk_vault_cell(cat, id, q, n, false))
	_box.add_child(vg)
	if not anyv:
		_line("금고가 비어 있다.", Color(0.7, 0.66, 0.6))

	# 게임 창고 — 눌러서 하나씩 넣는다
	_line("내 창고 (누르면 금고에 하나 넣는다)", Color(0.9, 0.86, 0.7))
	var ig := GridContainer.new()
	ig.columns = 9
	ig.add_theme_constant_override("h_separation", 5)
	ig.add_theme_constant_override("v_separation", 5)
	var anyi := false
	for e in _stock_entries():
		anyi = true
		ig.add_child(_mk_vault_cell(str(e.cat), str(e.id), int(e.q), int(e.n), true))
	_box.add_child(ig)
	if not anyi:
		_line("창고에 넣을 것이 없다.", Color(0.7, 0.66, 0.6))


# 금고 칸 하나 — into=true 면 창고에서 금고로, false 면 금고에서 창고로
func _mk_vault_cell(cat: String, id: String, q: int, n: int, into: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(54, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = "%s x%d\n%s" % [_label_of(cat, id, q), n,
		"누르면 금고에 하나 넣는다" if into else "누르면 창고로 하나 꺼낸다"]
	var tn := _icon_of(cat, id)
	if main != null and main.tex.has(tn):
		b.icon = main.tex[tn]
	else:
		b.text = _label_of(cat, id, q).left(2)
	var num := Label.new()
	num.text = str(n)
	num.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	num.offset_left = -38
	num.offset_top = -15
	num.offset_right = -3
	num.offset_bottom = -1
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	num.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.14))
	num.add_theme_constant_override("outline_size", 3)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(num)
	b.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		if into:
			if not _take_out(cat, id, 1, q):
				_status = "창고에 없다."
				_rebuild()
				return
			api.vault_deposit(cat, id, 1, q, 0)
		else:
			_give_back(cat, id, 1, q)
			_sync(cat, id, 1, q, 0)
			api.vault_withdraw(cat, id, 1, q, 0))
	return b


# 금고에 든 것만 올릴 수 있다 (서버가 쥔 창고 — 게임의 말을 안 믿는다)
func _build_sell() -> void:
	if _pick_id != "":
		_build_price_picker()
		return
	if _loading and not _vault_loaded:
		_line("금고를 여는 중...")
		return
	_line("금고에 든 것만 장터에 올릴 수 있다. (「금고」 칸에서 넣고 오자)",
		Color(0.95, 0.8, 0.5))
	_line("규칙: 동시에 10개까지 · 하루 20건 · 30초에 한 번 · 수수료 5%(금고 돈에서)\n"
		+ "값은 잡화점 기준의 0.5배 ~ 10배 안에서만 매길 수 있다.",
		Color(0.7, 0.68, 0.62))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	var any := false
	for it: Dictionary in _vault.get("items", []):
		var n := int(it.get("qty", 0))
		if n <= 0:
			continue
		any = true
		var cat := str(it.get("cat", "item"))
		var id := str(it.get("item_id", ""))
		var q := int(it.get("quality", 0))
		grid.add_child(_mk_stock_cell({"cat": cat, "id": id, "q": q, "n": n,
			"base": _base_of(cat, id, q)}))
	_box.add_child(grid)
	if not any:
		_line("금고가 비어 있다. 「금고」 칸에서 물건을 넣자.")


# 잡화점 기준값 (값을 매길 때 길잡이로 보여 준다)
func _base_of(cat: String, id: String, quality: int) -> int:
	match cat:
		"seed":
			return int(GameData.CROPS[id].seed_price) if GameData.CROPS.has(id) else 1
		"produce":
			var mult: int = [1, 2, 3][clampi(quality, 0, 2)]
			return int(GameData.CROPS[id].sell_price) * mult \
				if GameData.CROPS.has(id) else 1
		"tool":
			return 300 * maxi(1, quality)
		_:
			if id == "wood" or id == "stone":
				return 10
			return maxi(1, int(GameData.ITEMS[id].get("sell", 1))) \
				if GameData.ITEMS.has(id) else 1


# 창고에 있는 것들 — [종류, id, 품질, 개수, 잡화점 기준값]
func _stock_entries() -> Array:
	var out: Array = []
	for id: String in GameData.CROP_IDS:            # 수확물 (품질별로 따로)
		var total: int = int(GameData.produce.get(id, 0))
		if total <= 0:
			continue
		var silver: int = int(GameData.produce_silver.get(id, 0))
		var gold: int = int(GameData.produce_gold.get(id, 0))
		for q in 3:
			var n: int = [total - silver - gold, silver, gold][q]
			if n <= 0:
				continue
			var mult: int = [1, 2, 3][q]      # 은빛·금빛은 잡화점에서도 더 쳐 준다
			out.append({"cat": "produce", "id": id, "q": q, "n": n,
				"base": int(GameData.CROPS[id].sell_price) * mult})
	for id: String in GameData.CROP_IDS:            # 씨앗
		var ns: int = int(GameData.seeds.get(id, 0))
		if ns > 0:
			out.append({"cat": "seed", "id": id, "q": 0, "n": ns,
				"base": int(GameData.CROPS[id].seed_price)})
	# 목재·석재는 items가 아니라 따로 세는 자원이라 여기서 챙긴다
	if GameData.wood > 0:
		out.append({"cat": "item", "id": "wood", "q": 0, "n": GameData.wood, "base": 10})
	if GameData.stone > 0:
		out.append({"cat": "item", "id": "stone", "q": 0, "n": GameData.stone, "base": 10})
	for id: String in GameData.ITEM_IDS:            # 물건 — 전설 재료까지 전부
		var n2: int = int(GameData.items.get(id, 0))
		if n2 <= 0:
			continue
		var def: Dictionary = GameData.ITEMS.get(id, {})
		out.append({"cat": "item", "id": id, "q": 0, "n": n2,
			"base": maxi(1, int(def.get("sell", 0)))})
	# 도구 — 하나뿐인 물건이라 올리면 내 손에서 떠난다 (등급을 함께 올린다)
	for id: String in GameData.ALL_TOOLS:
		if not GameData.is_tool_unlocked(id):
			continue
		var lv: int = int(GameData.tool_level.get(id, 1))
		out.append({"cat": "tool", "id": id, "q": lv, "n": 1,
			"base": 300 * lv})
	return out


# 창고 한 칸 — 아이콘 + 개수. 누르면 그 물건의 값 매기기로 넘어간다
func _mk_stock_cell(e: Dictionary) -> Button:
	var cat := str(e.cat)
	var id := str(e.id)
	var q := int(e.q)
	var n := int(e.n)
	var base := int(e.base)
	var b := Button.new()
	b.custom_minimum_size = Vector2(58, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = "%s x%d\n잡화점 기준 %dG" % [_label_of(cat, id, q), n, base]
	var tn := _icon_of(cat, id)
	if main != null and main.tex.has(tn):
		b.icon = main.tex[tn]
	else:
		b.text = _label_of(cat, id, q).left(2)
	# 품질은 테두리 색으로 — 은빛은 하얗게, 금빛은 노랗게
	if q > 0:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.14, 0.12, 0.2, 0.9)
		st.border_color = Color(0.85, 0.88, 0.95) if q == 1 else Color(1.0, 0.86, 0.4)
		st.set_border_width_all(2)
		st.set_corner_radius_all(3)
		st.set_content_margin_all(5)
		b.add_theme_stylebox_override("normal", st)
	var num := Label.new()
	num.text = str(n)
	num.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	num.offset_left = -40
	num.offset_top = -16
	num.offset_right = -3
	num.offset_bottom = -1
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	num.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.14))
	num.add_theme_constant_override("outline_size", 3)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(num)
	b.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		_pick(cat, id, q, n, base))
	return b


func _pick(cat: String, id: String, quality: int, have: int, base: int) -> void:
	_pick_cat = cat
	_pick_id = id
	_pick_quality = quality
	_pick_qty = 1
	_pick_price = maxi(1, base)
	_status = "%d개까지 올릴 수 있다." % have
	_rebuild()


# 숫자를 직접 쳐 넣는 칸. 치는 대로 바로 값이 잡히고,
# 엔터를 치면 화면을 다시 그려 안내 문구까지 맞춰 준다.
# (숫자가 아닌 글자는 지운다 — 값에 엉뚱한 게 섞이면 안 된다)
func _num_edit(value: int, width: float, on_change: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = str(value)
	e.custom_minimum_size = Vector2(width, 0)
	e.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	e.max_length = 9
	e.tooltip_text = "숫자를 직접 칠 수 있다"
	e.text_changed.connect(func(s: String) -> void:
		var digits := ""
		for ch in s:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != s:
			e.text = digits
			e.caret_column = digits.length()
		var n := 0
		if digits != "":
			n = int(digits)
		on_change.call(n))
	e.text_submitted.connect(func(_s: String) -> void:
		Sound.play_sfx("sfx_ui")
		_rebuild())
	return e


func _build_price_picker() -> void:
	var have := _vault_qty(_pick_cat, _pick_id, _pick_quality)   # 금고에 든 만큼
	_line("%s — 몇 개를 얼마에 올릴까? (가진 것 %d개)"
		% [_label_of(_pick_cat, _pick_id, _pick_quality), have],
		Color(0.95, 0.8, 0.5))
	_line("(값은 묶음 전체의 값이다. 팔리면 대금이 금고로 들어온다)\n"
		+ "올릴 때 값의 5%를 금고 돈에서 수수료로 뗀다 — 거둬도 돌아오지 않는다.")

	if _pick_cat == "tool":
		_line("도구는 하나뿐이라 올리면 내 손에서 떠난다. 팔리기 전엔 거둘 수 있다.",
			Color(0.95, 0.72, 0.5))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 6)
	var ql := Label.new()
	ql.text = "개수 (%d까지)" % have
	ql.custom_minimum_size = Vector2(110, 0)
	qrow.add_child(ql)
	qrow.add_child(_num_edit(_pick_qty, 80,
		func(n: int) -> void: _pick_qty = clampi(n, 0, maxi(1, have))))
	for step in [-10, -1, 1, 10]:
		var b := Button.new()
		b.text = ("%+d" % step)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			Sound.play_sfx("sfx_ui")
			_pick_qty = clampi(_pick_qty + step, 1, maxi(1, have))
			_rebuild())
		qrow.add_child(b)
	_box.add_child(qrow)

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	var pl := Label.new()
	pl.text = "값 (G)"
	pl.custom_minimum_size = Vector2(110, 0)
	prow.add_child(pl)
	prow.add_child(_num_edit(_pick_price, 120,
		func(n: int) -> void: _pick_price = clampi(n, 0, 99999999)))
	for step in [-1000, -100, -10, 10, 100, 1000]:
		var b2 := Button.new()
		b2.text = ("%+d" % step)
		b2.focus_mode = Control.FOCUS_NONE
		b2.pressed.connect(func() -> void:
			Sound.play_sfx("sfx_ui")
			_pick_price = clampi(_pick_price + step, 1, 99999999)
			_rebuild())
		prow.add_child(b2)
	_box.add_child(prow)
	# 매길 수 있는 값의 폭 — 잡화점 기준의 0.5배 ~ 10배
	var base_all: int = maxi(1, _base_of(_pick_cat, _pick_id, _pick_quality)) * maxi(1, _pick_qty)
	_line("%d개 기준 %dG ~ %dG 안에서 매길 수 있다. (지금 %dG · 수수료 %dG)"
		% [maxi(1, _pick_qty), maxi(1, int(base_all * 0.5)), base_all * 10,
			_pick_price, int(_pick_price * 0.05)],
		Color(0.7, 0.68, 0.62))

	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	var ok := Button.new()
	ok.text = "장터에 올리기"
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_do_list)
	brow.add_child(ok)
	var back := Button.new()
	back.text = "그만두기"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		_pick_id = ""
		_status = ""
		_rebuild())
	brow.add_child(back)
	_box.add_child(brow)


func _have_of(cat: String, id: String, quality: int) -> int:
	if cat == "tool":
		return 1 if GameData.is_tool_unlocked(id) else 0
	match cat:
		"seed":
			return int(GameData.seeds.get(id, 0))
		"produce":
			match quality:
				1:
					return int(GameData.produce_silver.get(id, 0))
				2:
					return int(GameData.produce_gold.get(id, 0))
				_:
					return int(GameData.produce.get(id, 0)) \
						- int(GameData.produce_silver.get(id, 0)) \
						- int(GameData.produce_gold.get(id, 0))
	if id == "wood":
		return GameData.wood
	if id == "stone":
		return GameData.stone
	return int(GameData.items.get(id, 0))


# 올리기 — 물건은 **금고에서** 빠진다 (서버가 판단한다). 게임 창고는 건드리지 않는다
func _do_list() -> void:
	# 직접 쳐 넣은 값이라 비었거나 0일 수 있다 — 여기서 걸러 준다
	if _pick_qty < 1:
		_status = "몇 개를 올릴지 적자."
		_rebuild()
		return
	if _pick_price < 1:
		_status = "값을 적자. (1G부터)"
		_rebuild()
		return
	Sound.play_sfx("sfx_ui")
	_status = "장터에 올리는 중..."
	_rebuild()
	api.list_item(_pick_cat, _pick_id, _pick_qty, _pick_quality, _pick_price)
