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


func open() -> void:
	visible = true
	_tab = "market"
	_status = ""
	_refresh()


# 가방에서 우클릭으로 바로 들어오는 입구 — 고른 물건의 값 매기기 창을 편다
# (게시판까지 걸어가지 않아도 창고에 있는 것을 그 자리에서 내놓을 수 있다)
func open_sell(cat: String, id: String, quality: int) -> void:
	visible = true
	_tab = "sell"
	_rows = []
	_loading = false
	var have := _have_of(cat, id, quality)
	if have <= 0:
		_status = "창고에 없다."
		_pick_id = ""
		_rebuild()
		return
	var base := 1
	match cat:
		"seed":
			base = int(GameData.CROPS[id].seed_price) if GameData.CROPS.has(id) else 1
		"produce":
			var mult: int = [1, 2, 3][clampi(quality, 0, 2)]   # 은·금은 더 쳐 준다
			base = int(GameData.CROPS[id].sell_price) * mult \
				if GameData.CROPS.has(id) else 1
		_:
			base = int(GameData.ITEMS[id].get("sell", 1)) if GameData.ITEMS.has(id) else 1
	_pick(cat, id, quality, have, base)


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
	if _tab == "sell":
		_loading = false
		_rebuild()
		return
	api.fetch(_tab == "mine")


# ---- 서버 응답 ----

func _on_fetched(rows: Array) -> void:
	_rows = rows
	_loading = false
	_rebuild()


func _on_listed(ok: bool, msg: String) -> void:
	_status = msg
	if ok:
		Sound.play_sfx("sfx_coin")
		_pick_id = ""
		_tab = "mine"
		_refresh()
	else:
		# 실패했으면 맡겨 둔 물건을 돌려준다 (등록할 때 미리 뺐다)
		_give_back(_pick_cat, _pick_id, _pick_qty, _pick_quality)
		_sync(_pick_cat, _pick_id, _pick_qty, _pick_quality, 0)
		_rebuild()


func _on_bought(ok: bool, msg: String, row: Dictionary) -> void:
	_status = msg
	if ok:
		Sound.play_sfx("sfx_coin")
		# 산 것도, 거둔 것도 결국 내 창고로 들어온다.
		# (산 것은 여기서 값을 치른다 — 거둔 것은 냈던 물건이 돌아오는 것)
		var paid := int(row.get("price", 0)) if str(row.get("status", "")) == "sold" else 0
		GameData.money -= paid
		_give_back(str(row.get("cat", "")), str(row.get("item_id", "")),
			int(row.get("qty", 0)), int(row.get("quality", 0)))
		_sync(str(row.get("cat", "")), str(row.get("item_id", "")),
			int(row.get("qty", 0)), int(row.get("quality", 0)), -paid)
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
	if main != null and Net.active():
		main.doing.net_auction(cat, id, qty, quality, money_delta)


func _take_out(cat: String, id: String, qty: int, quality: int) -> bool:
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
			if int(GameData.items.get(id, 0)) < qty:
				return false
			GameData.items[id] = int(GameData.items[id]) - qty
	_sync(cat, id, -qty, quality, 0)
	return true


func _give_back(cat: String, id: String, qty: int, quality: int) -> void:
	if id == "" or qty <= 0:
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
			GameData.items[id] = int(GameData.items.get(id, 0)) + qty


# ---- 이름·아이콘 ----

func _label_of(cat: String, id: String, quality: int) -> String:
	var nm := id
	match cat:
		"seed":
			if GameData.CROPS.has(id):
				nm = "%s 씨앗" % str(GameData.CROPS[id].name)
		"produce":
			if GameData.CROPS.has(id):
				nm = str(GameData.CROPS[id].name)
			var q: String = ["", "은빛 ", "금빛 "][clampi(quality, 0, 2)]
			nm = q + nm
		_:
			if GameData.ITEMS.has(id):
				nm = str(GameData.ITEMS[id].name)
	return nm


func _icon_of(cat: String, id: String) -> String:
	match cat:
		"seed":
			return "icon_seed"
		"produce":
			return "mature_" + id
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
	_mk_tab("sell", "내 창고에서 올리기")
	_mk_tab("mine", "내 등록·대금")
	_status_label.text = _status if _status != "" else \
		"내 이름: %s · 소지금 %dG" % [GameData.seller_name(), GameData.money]
	match _tab:
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
		var mine: bool = str(r.get("seller_id", "")) == GameData.farm_id
		var sub := "%dG · %s" % [price, str(r.get("seller_name", "?"))]
		if mine:
			sub += " (나)"
		_mk_row(str(r.get("cat", "item")), str(r.get("item_id", "")),
			int(r.get("quality", 0)), int(r.get("qty", 1)), sub,
			"사기", func() -> void: api.buy(int(r.get("id", 0))),
			not mine and GameData.money >= price)


# 내 물건 — 올려 둔 것 거두기 + 대금 받기
func _build_mine() -> void:
	var claim := Button.new()
	claim.text = "팔린 대금 받기"
	claim.focus_mode = Control.FOCUS_NONE
	claim.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		api.claim())
	_box.add_child(claim)
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
			sub += "%s에게 팔림" % str(r.get("buyer_name", "누군가"))
			sub += " · 대금 받음" if bool(r.get("claimed", false)) else " · 대금 대기"
		else:
			sub += "팔리는 중"
		_mk_row(str(r.get("cat", "item")), str(r.get("item_id", "")),
			int(r.get("quality", 0)), int(r.get("qty", 1)), sub,
			"" if sold else "거두기",
			func() -> void: api.cancel(int(r.get("id", 0))))
	if not any:
		_line("올려 둔 물건이 없다.")


# 등록 — 창고에서 고르고 값을 매긴다
# 내 창고 한눈에 — 가방처럼 아이콘 격자로 늘어놓고, 누르면 값 매기기로 간다
func _build_sell() -> void:
	if _pick_id != "":
		_build_price_picker()
		return
	_line("내 창고 — 올릴 것을 누르자. (칸 아래 숫자가 가진 개수)",
		Color(0.95, 0.8, 0.5))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	var any := false
	for e in _stock_entries():
		any = true
		grid.add_child(_mk_stock_cell(e))
	_box.add_child(grid)
	if not any:
		_line("올릴 만한 것이 창고에 없다.")


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
	for id: String in GameData.ITEM_IDS:            # 물건 (전설 재료는 뺀다)
		var n2: int = int(GameData.items.get(id, 0))
		var def: Dictionary = GameData.ITEMS.get(id, {})
		if n2 <= 0 or int(def.get("sell", 0)) <= 0 or def.get("legend", false):
			continue
		out.append({"cat": "item", "id": id, "q": 0, "n": n2,
			"base": int(def.sell)})
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


func _build_price_picker() -> void:
	var have := _have_of(_pick_cat, _pick_id, _pick_quality)
	_line("%s — 몇 개를 얼마에 올릴까? (가진 것 %d개)"
		% [_label_of(_pick_cat, _pick_id, _pick_quality), have],
		Color(0.95, 0.8, 0.5))
	_line("(값은 묶음 전체의 값이다. 팔리면 「내 물건」에서 대금을 받는다)")

	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 6)
	var ql := Label.new()
	ql.text = "개수 %d / %d" % [_pick_qty, have]
	ql.custom_minimum_size = Vector2(150, 0)
	qrow.add_child(ql)
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
	pl.text = "값 %dG" % _pick_price
	pl.custom_minimum_size = Vector2(150, 0)
	prow.add_child(pl)
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
	return int(GameData.items.get(id, 0))


# 올리기 — 물건은 **먼저** 창고에서 뺀다. 서버가 거절하면 돌려준다.
# (안 빼면 올려 둔 것을 집에서 또 팔아 두 번 챙길 수 있다)
func _do_list() -> void:
	Sound.play_sfx("sfx_ui")
	if not _take_out(_pick_cat, _pick_id, _pick_qty, _pick_quality):
		_status = "창고에 그만큼 없다."
		_rebuild()
		return
	_status = "장터에 올리는 중..."
	_rebuild()
	api.list_item(_pick_cat, _pick_id, _pick_qty, _pick_quality, _pick_price)
