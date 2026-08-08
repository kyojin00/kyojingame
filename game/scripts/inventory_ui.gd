# 인벤토리 (I): 도구 선택 + 보유 중인 씨앗/수확물/생산물/자원.
extends CanvasLayer

const TOOLS := ["hoe", "water", "seed", "hand", "axe", "pickaxe", "fence", "sprinkler", "rod"]
const TOOL_ICONS := {
	"hoe": "icon_hoe", "water": "icon_water", "seed": "icon_seed", "hand": "icon_basket",
	"axe": "icon_axe", "pickaxe": "icon_pickaxe", "fence": "fence",
	"sprinkler": "sprinkler", "rod": "icon_rod",
}

const TOOL_DESC := {
	"hoe": "호미 — 잔디를 갈아 밭을 만든다",
	"water": "물뿌리개 — 작물에 물을 준다",
	"seed": "씨앗 주머니 — 밭에 씨앗을 심는다 (Tab: 종류 바꾸기)",
	"hand": "바구니 — 다 자란 작물을 수확한다",
	"axe": "도끼 — 나무를 벤다 (동굴에서는 무기)",
	"pickaxe": "곡괭이 — 바위를 캔다",
	"fence": "울타리 — 목재 1개로 설치한다",
	"sprinkler": "스프링클러 — 아침마다 주변 4칸에 물을 준다",
	"rod": "낚싯대 — 물가에서 물고기를 낚는다",
}

var main: Node2D
var items_box: VBoxContainer
var info_label: Label
var _refresh_timer := 0.0
var _slot_normal: StyleBoxFlat
var _slot_selected: StyleBoxFlat
var _slot_moving: StyleBoxFlat
var _move_from := -1  # 우클릭으로 이동 중인 슬롯 (-1 = 없음)


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(203, 83)
	panel.custom_minimum_size = Vector2(555, 345)
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
	title.text = "- 인벤토리 (I/ESC: 닫기 · U: 능력치) -"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(525, 235)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items_box)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(525, 46)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(info_label)
	_show_info("")


func _show_info(text: String) -> void:
	if text == "":
		info_label.text = "슬롯에 마우스를 올리면 상세 정보가 나온다"
		info_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.68))
	else:
		info_label.text = text
		info_label.add_theme_color_override("font_color", Color(1, 0.93, 0.75))


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func close() -> void:
	visible = false
	_move_from = -1


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
		_slot_moving = _slot_normal.duplicate()
		_slot_moving.bg_color = Color(0.3, 0.22, 0.14, 0.95)
		_slot_moving.border_color = Color(0.45, 0.9, 0.5)
		_slot_moving.set_border_width_all(2)

	# 도구 슬롯: 드래그로 원하는 칸에 배치 (좌클릭: 선택 / 우클릭: 칸 비우기)
	_line("[도구 슬롯]  드래그: 배치 · 좌클릭: 선택 · 우클릭: 빼기", Color(0.65, 0.85, 0.6))
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 4)
	for i in GameData.tool_slots.size():
		tool_row.add_child(_mk_tool_slot(i))
	items_box.add_child(tool_row)

	# 보유 도구: 여기서 드래그해서 슬롯에 넣는다
	_line("[보유 도구]  드래그해서 위 슬롯이나 하단바에 넣기", Color(0.65, 0.85, 0.6))
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 4)
	for t in TOOLS:
		if GameData.is_tool_unlocked(t):
			pick_row.add_child(_mk_pick_slot(t))
	items_box.add_child(pick_row)

	_line("소지금 %dG" % GameData.money, Color("ffd75e"))

	# 아이템 그리드 (12 x 4): 얻은 것들이 자동으로 채워진다
	var entries := _item_entries()
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in 48:
		grid.add_child(_mk_item_slot(entries[i] if i < entries.size() else {}))
	items_box.add_child(grid)


func _mk_tool_slot(slot_i: int) -> Button:
	var t: String = GameData.tool_slots[slot_i]
	var unlocked: bool = t != "" and GameData.is_tool_unlocked(t)
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.icon = main.tex[TOOL_ICONS[t]] if unlocked else null
	b.add_theme_stylebox_override("normal",
		_slot_selected if (t != "" and GameData.tool == t) else _slot_normal)
	b.add_theme_stylebox_override("hover", _slot_normal)
	b.add_theme_stylebox_override("pressed", _slot_selected)
	b.pressed.connect(func() -> void:
		if unlocked:
			main.set_tool(t)
			_rebuild())
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_RIGHT \
				and GameData.tool_slots[slot_i] != "":
			GameData.tool_slots[slot_i] = ""
			Sound.play_sfx("sfx_ui")
			_rebuild())
	if unlocked:
		b.mouse_entered.connect(func() -> void:
			_show_info(TOOL_DESC.get(t, t)))
		b.mouse_exited.connect(func() -> void: _show_info(""))
	b.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var tt: String = GameData.tool_slots[slot_i]
			if tt == "" or not GameData.is_tool_unlocked(tt):
				return null
			var pv := TextureRect.new()
			pv.texture = main.tex[TOOL_ICONS[tt]]
			pv.custom_minimum_size = Vector2(36, 36)
			pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pv.stretch_mode = TextureRect.STRETCH_SCALE
			b.set_drag_preview(pv)
			return {"kind": "tool_slot", "from": slot_i},
		func(_pos: Vector2, data: Variant) -> bool:
			return typeof(data) == TYPE_DICTIONARY \
				and data.get("kind") in ["tool_slot", "tool_pick"],
		func(_pos: Vector2, data: Variant) -> void:
			if data.get("kind") == "tool_pick":
				_place_tool(str(data.tool), slot_i)
			else:
				_swap_slots(int(data.from), slot_i))
	return b


func _mk_pick_slot(t: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.icon = main.tex[TOOL_ICONS[t]]
	b.add_theme_stylebox_override("normal", _slot_normal)
	b.add_theme_stylebox_override("hover", _slot_selected)
	b.add_theme_stylebox_override("pressed", _slot_normal)
	b.mouse_entered.connect(func() -> void: _show_info(TOOL_DESC.get(t, t)))
	b.mouse_exited.connect(func() -> void: _show_info(""))
	b.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var pv := TextureRect.new()
			pv.texture = main.tex[TOOL_ICONS[t]]
			pv.custom_minimum_size = Vector2(36, 36)
			pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pv.stretch_mode = TextureRect.STRETCH_SCALE
			b.set_drag_preview(pv)
			return {"kind": "tool_pick", "tool": t},
		func(_pos: Vector2, _data: Variant) -> bool: return false,
		func(_pos: Vector2, _data: Variant) -> void: pass)
	return b


func _place_tool(t: String, slot_i: int) -> void:
	# 같은 도구가 다른 칸에 있으면 그 칸을 비운다 (중복 방지)
	for i in GameData.tool_slots.size():
		if i != slot_i and GameData.tool_slots[i] == t:
			GameData.tool_slots[i] = ""
	GameData.tool_slots[slot_i] = t
	Sound.play_sfx("sfx_place")
	_rebuild()


func _swap_slots(from_i: int, to_i: int) -> void:
	if from_i == to_i:
		return
	var tmp: String = GameData.tool_slots[from_i]
	GameData.tool_slots[from_i] = GameData.tool_slots[to_i]
	GameData.tool_slots[to_i] = tmp
	Sound.play_sfx("sfx_place")
	_rebuild()


func _mk_item_slot(e: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_stylebox_override("normal", _slot_normal)
	b.add_theme_stylebox_override("hover", _slot_selected)
	b.add_theme_stylebox_override("pressed", _slot_normal)
	if e.is_empty():
		b.mouse_entered.connect(func() -> void: _show_info(""))
		return b
	b.tooltip_text = str(e.tip)
	b.mouse_entered.connect(func() -> void: _show_info(str(e.get("info", e.tip))))
	b.mouse_exited.connect(func() -> void: _show_info(""))
	if e.has("icon") and main.tex.has(e.icon):
		b.icon = main.tex[e.icon]
	else:
		var tag := Label.new()
		tag.text = str(e.label)
		tag.position = Vector2(11, 4)
		tag.add_theme_color_override("font_color", e.get("color", Color(0.9, 0.88, 0.95)))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
	var cnt := Label.new()
	cnt.text = str(e.count)
	cnt.add_theme_font_size_override("font_size", 16)
	cnt.position = Vector2(18, 20)
	cnt.size = Vector2(20, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	cnt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	cnt.add_theme_constant_override("outline_size", 3)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cnt)
	return b


func _item_entries() -> Array:
	var out: Array = []
	if GameData.wood > 0:
		out.append({"icon": "icon_wood", "count": GameData.wood,
			"tip": "목재 x%d" % GameData.wood,
			"info": "목재 x%d — 나무를 베면 얻는다. 울타리·스프링클러·축사 재료" % GameData.wood})
	if GameData.stone > 0:
		out.append({"icon": "icon_stone", "count": GameData.stone,
			"tip": "석재 x%d" % GameData.stone,
			"info": "석재 x%d — 바위를 캐면 얻는다. 스프링클러·축사 재료" % GameData.stone})
	for id in GameData.CROP_IDS:
		if GameData.seeds[id] > 0:
			out.append({"icon": "icon_seed", "count": GameData.seeds[id],
				"tip": "%s 씨앗 x%d" % [GameData.CROPS[id].name, GameData.seeds[id]],
				"info": "%s 씨앗 x%d — 밭(호미로 간 땅)에 심자. 수확까지 %d일" %
					[GameData.CROPS[id].name, GameData.seeds[id], int(GameData.CROPS[id].grow_days)]})
	for id in GameData.CROP_IDS:
		var n := int(GameData.produce[id])
		if n > 0:
			out.append({"icon": "mature_" + id, "count": n,
				"tip": "%s x%d (개당 %dG)" % [GameData.CROPS[id].name, n,
					GameData.CROPS[id].sell_price],
				"info": "%s x%d — 판매가 %dG. 출하 상자에 넣으면 다음 날 아침 정산된다" %
					[GameData.CROPS[id].name, n, GameData.CROPS[id].sell_price]})
		var ns := int(GameData.produce_silver.get(id, 0))
		if ns > 0:
			out.append({"icon": "mature_" + id, "count": ns,
				"tip": "%s (은품질) x%d" % [GameData.CROPS[id].name, ns],
				"info": "%s (은품질) x%d — 일반보다 비싸게 팔린다" % [GameData.CROPS[id].name, ns]})
		var ng := int(GameData.produce_gold.get(id, 0))
		if ng > 0:
			out.append({"icon": "mature_" + id, "count": ng,
				"tip": "%s (금품질) x%d" % [GameData.CROPS[id].name, ng],
				"info": "%s (금품질) x%d — 최고 품질! 가장 비싸게 팔린다" % [GameData.CROPS[id].name, ng]})
	for id in GameData.ITEM_IDS:
		var n2 := int(GameData.items[id])
		if n2 <= 0:
			continue
		var def: Dictionary = GameData.ITEMS[id]
		var e := {"count": n2, "tip": "%s x%d" % [def.name, n2],
			"label": str(def.name).left(1)}
		for cand in [id, id + "_0", "forage_" + id]:
			if main.tex.has(cand):
				e["icon"] = cand
				break
		var extra := ""
		if bool(def.get("legend", false)):
			e["color"] = Color(1.0, 0.85, 0.4)
			extra = "전설의 재료 — 연구 노트의 마지막 연금술에 쓰인다 (판매 불가)"
		elif id.begins_with("fish_"):
			e["color"] = Color(0.5, 0.75, 1.0)
			extra = "낚시로 잡은 물고기 · 판매가 %dG" % int(def.sell)
		elif id.begins_with("dish_"):
			e["color"] = Color(1.0, 0.75, 0.4)
			extra = "요리 — 먹으면 체력을 회복한다 · 판매가 %dG" % int(def.sell)
		elif id in ["ore", "gem", "star_ore", "ghost_essence"]:
			e["color"] = Color(0.8, 0.8, 0.9)
			extra = "동굴에서 얻었다 · 판매가 %dG" % int(def.sell)
		elif id in ["egg", "milk"]:
			e["color"] = Color(0.95, 0.9, 0.8)
			extra = "축사 동물이 준 선물 · 판매가 %dG" % int(def.sell)
		else:
			e["color"] = Color(0.85, 0.82, 0.95)
			extra = "판매가 %dG" % int(def.sell) if int(def.sell) > 0 else ""
		e["info"] = "%s x%d — %s" % [def.name, n2, extra] if extra != "" \
			else "%s x%d" % [def.name, n2]
		out.append(e)
	return out