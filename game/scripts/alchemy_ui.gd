# 연금술 조합대 (집 안 조합대 E)
#
# 왼쪽: 가진 재료 목록. 재료마다 다섯 속성(빛/물/불/흙/생명)이 점으로 보인다.
#       클릭하면 위쪽 세 칸에 올라간다.
# 위쪽: 올린 재료 세 개 + 속성 합계 + [조합하기]
# 오른쪽: 알아낸 조합법. [만들기](재료 자동)와 [마시기].
#
# 속성을 숨기지 않는 것이 요점이다 — 찍기가 아니라 **풀이**가 되어야 한다.
extends CanvasLayer

const EL_COLORS := {
	"light": Color(1.0, 0.86, 0.42),
	"water": Color(0.42, 0.7, 0.95),
	"fire": Color(0.95, 0.5, 0.32),
	"earth": Color(0.72, 0.56, 0.36),
	"life": Color(0.5, 0.85, 0.5),
}

var main: Node2D
var slot_box: HBoxContainer
var sum_label: Label
var brew_btn: Button
var reagent_box: VBoxContainer
var formula_box: VBoxContainer

var picked: Array = []          # 올려 둔 재료 id (최대 ALCHEMY_SLOTS)
var result_panel: PanelContainer
var result_head: Label
var result_body: Label
var last: Dictionary = {}       # 마지막 조합 결과 (main.do_brew가 돌려준 것)


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(32, 24)
	panel.custom_minimum_size = Vector2(896, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.19, 0.97)
	style.border_color = Color(0.48, 0.4, 0.66)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	# ---- 머리줄: 제목 + 속성 범례 ----
	# 색 점이 무슨 속성인지 모르면 재료 목록이 그냥 알록달록한 점이 된다.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var title := Label.new()
	title.text = "연금술 조합대"
	title.add_theme_color_override("font_color", Color("ffd75e"))
	head.add_child(title)
	for e: String in GameData.ELEMENTS:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		var sw := ColorRect.new()
		sw.color = EL_COLORS[e]
		sw.custom_minimum_size = Vector2(9, 9)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(sw)
		var nm2 := Label.new()
		nm2.text = str(GameData.ELEMENT_NAMES[e])
		nm2.add_theme_color_override("font_color", EL_COLORS[e])
		chip.add_child(nm2)
		head.add_child(chip)
	var closer := Label.new()
	closer.text = "  (E/ESC: 닫기)"
	closer.add_theme_color_override("font_color", Color(0.58, 0.55, 0.7))
	closer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	closer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(closer)

	# ---- 결과 배너 (조합한 뒤에만 보인다) ----
	result_panel = PanelContainer.new()
	result_panel.visible = false
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.10, 0.16, 0.12, 0.95)
	rstyle.border_color = Color(0.4, 0.8, 0.5)
	rstyle.set_border_width_all(2)
	rstyle.set_corner_radius_all(3)
	rstyle.set_content_margin_all(7)
	result_panel.add_theme_stylebox_override("panel", rstyle)
	v.add_child(result_panel)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	result_panel.add_child(rv)
	result_head = Label.new()
	result_head.add_theme_font_size_override("font_size", 15)
	rv.add_child(result_head)
	result_body = Label.new()
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.custom_minimum_size = Vector2(846, 0)
	result_body.add_theme_color_override("font_color", Color(0.86, 0.86, 0.9))
	rv.add_child(result_body)

	# ---- 조합대: 올린 재료 세 칸 + 합계 + 버튼 ----
	var bench := PanelContainer.new()
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.18, 0.15, 0.26, 0.9)
	bstyle.border_color = Color(0.40, 0.34, 0.56)
	bstyle.set_border_width_all(1)
	bstyle.set_corner_radius_all(3)
	bstyle.set_content_margin_all(7)
	bench.add_theme_stylebox_override("panel", bstyle)
	v.add_child(bench)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 5)
	bench.add_child(bv)

	slot_box = HBoxContainer.new()
	slot_box.add_theme_constant_override("separation", 6)
	bv.add_child(slot_box)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	bv.add_child(row2)
	brew_btn = _mk_button("조합하기", _on_brew)
	brew_btn.custom_minimum_size = Vector2(110, 0)
	row2.add_child(brew_btn)
	row2.add_child(_mk_button("비우기", func() -> void:
		picked.clear()
		_rebuild()))
	sum_label = Label.new()
	sum_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sum_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.92))
	row2.add_child(sum_label)

	# ---- 아래: 재료 목록 | 조합법 ----
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	reagent_box = _mk_column(cols, "[ 재료 ]  (올리기 -> 세 칸을 채우고 조합)", 356)
	formula_box = _mk_column(cols, "[ 알아낸 조합법 ]", 500)


func _mk_column(parent: HBoxContainer, head: String, w: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	parent.add_child(col)
	var l := Label.new()
	l.text = head
	l.add_theme_color_override("font_color", Color(0.66, 0.6, 0.85))
	col.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(w, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 가로 스크롤을 끄면 안쪽 글자가 이 폭에 맞춰 줄바꿈된다 (칸 밖으로 새지 않는다)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(w - 14, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)
	return box


func _mk_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func open() -> void:
	visible = true
	picked.clear()
	last.clear()
	Sound.play_sfx("sfx_ui")
	_rebuild()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


# 속성을 색 점으로 (숫자만큼 찍는다)
func _element_pips(el: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for e: String in GameData.ELEMENTS:
		var n := int(el.get(e, 0))
		for i in n:
			var r := ColorRect.new()
			r.color = EL_COLORS[e]
			r.custom_minimum_size = Vector2(9, 9)
			# 이걸 안 걸면 줄 높이만큼 세로로 늘어나 색 막대가 된다
			r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.tooltip_text = str(GameData.ELEMENT_NAMES[e])
			h.add_child(r)
	return h


func _name_of(id: String) -> String:
	if GameData.CROPS.has(id):
		return str(GameData.CROPS[id].name)
	return str(GameData.ITEMS[id].name)


# 이 재료를 몇 개나 더 올릴 수 있는가 (이미 올린 것은 빼고 센다)
func _left(id: String) -> int:
	var used := 0
	for p: String in picked:
		if p == id:
			used += 1
	return GameData.ingredient_count(id) - used


func _pick(id: String) -> void:
	if picked.size() >= GameData.ALCHEMY_SLOTS or _left(id) <= 0:
		return
	picked.append(id)
	Sound.play_sfx("sfx_place")
	_rebuild()


func _on_brew() -> void:
	if picked.size() != GameData.ALCHEMY_SLOTS:
		return
	last = main.do_brew(picked.duplicate())
	picked.clear()
	_rebuild()


# 무엇이 나왔는지 창 안에서 바로 보이게 한다.
# (예전에는 화면 아래 안내문으로만 스쳐 지나가서, 성공했는지도 몰랐다)
func _refresh_result() -> void:
	if last.is_empty():
		result_panel.visible = false
		return
	result_panel.visible = true
	var ok: bool = bool(last.get("ok", false))
	var style: StyleBoxFlat = result_panel.get_theme_stylebox("panel")
	style.bg_color = Color(0.10, 0.17, 0.12, 0.95) if ok else Color(0.19, 0.11, 0.11, 0.95)
	style.border_color = Color(0.42, 0.82, 0.52) if ok else Color(0.82, 0.44, 0.42)
	var names: Array[String] = []
	for id: String in last.get("ids", []):
		names.append(_name_of(id))
	if ok:
		result_head.text = "✔  %s 완성!%s" % [last.get("name", ""),
			"   ★ 새 조합법" if last.get("first", false) else ""]
		result_head.add_theme_color_override("font_color", Color(0.62, 0.94, 0.68))
		result_body.text = "%s  →  %s\n%s" % [" + ".join(names),
			last.get("name", ""), last.get("effect", "")]
	else:
		result_head.text = "✘  실패 — 탁한 앙금만 남았다"
		result_head.add_theme_color_override("font_color", Color(0.96, 0.62, 0.58))
		result_body.text = "%s  →  탁한 앙금\n%s" % [" + ".join(names), last.get("hint", "")]


# 아는 조합법을 재료 자동 선택으로 만든다.
# 필요 속성을 넘기는 조합을 가진 재료 안에서 찾아본다 (없으면 버튼이 꺼진다).
func _auto_pick(fid: String) -> Array:
	var have: Array = []
	for id: String in GameData.REAGENTS:
		for i in mini(GameData.ingredient_count(id), GameData.ALCHEMY_SLOTS):
			have.append(id)
	var n := have.size()
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				var trio := [have[a], have[b], have[c]]
				if GameData.match_formula(trio) == fid:
					return trio
	return []


func _make(fid: String) -> void:
	var trio := _auto_pick(fid)
	if trio.is_empty():
		main.hud.show_message("재료가 모자란다. (%s)" % GameData.formula_need_text(fid))
		return
	last = main.do_brew(trio)
	picked.clear()
	_rebuild()


func _rebuild() -> void:
	_refresh_result()
	for c in slot_box.get_children():
		c.queue_free()
	for c in reagent_box.get_children():
		c.queue_free()
	for c in formula_box.get_children():
		c.queue_free()

	# ---- 올린 재료 칸 (이름 + 그 재료가 넣는 속성) ----
	for i in GameData.ALCHEMY_SLOTS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.custom_minimum_size = Vector2(176, 0)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(176, 0)
		if i < picked.size():
			var id: String = picked[i]
			b.text = "%s  ✕" % _name_of(id)
			b.tooltip_text = "누르면 내린다"
			b.pressed.connect(func() -> void:
				picked.remove_at(i)
				_rebuild())
			cell.add_child(b)
			var pips := _element_pips(GameData.reagent_elements(id))
			pips.alignment = BoxContainer.ALIGNMENT_CENTER
			cell.add_child(pips)
		else:
			b.text = "%d번 칸 (비어 있음)" % (i + 1)
			b.disabled = true
			cell.add_child(b)
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 9)
			cell.add_child(sp)
		slot_box.add_child(cell)

	var sum: Dictionary = GameData.mix_elements(picked)
	var parts: Array[String] = []
	for e: String in GameData.ELEMENTS:
		if int(sum[e]) > 0:
			parts.append("%s %d" % [GameData.ELEMENT_NAMES[e], int(sum[e])])
	sum_label.text = "합계  " + (" · ".join(parts) if not parts.is_empty() else "-")
	brew_btn.disabled = picked.size() != GameData.ALCHEMY_SLOTS
	if brew_btn.disabled:
		sum_label.text += "     (재료 %d/%d)" % [picked.size(), GameData.ALCHEMY_SLOTS]

	# ---- 재료 목록 (가진 것만) ----
	var any := false
	var order: Array = []
	for id: String in GameData.REAGENTS:
		if GameData.ingredient_count(id) > 0:
			order.append(id)
	# 더 올릴 수 있는 재료를 위로 (칸이 다 차면 전부 아래로 내려간다)
	var keys: Array = GameData.REAGENTS.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		var la: bool = _left(a) > 0
		var lb: bool = _left(b) > 0
		if la != lb:
			return la
		return keys.find(a) < keys.find(b))
	for id: String in order:
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var add := _mk_button("올리기", _pick.bind(id))
		add.disabled = picked.size() >= GameData.ALCHEMY_SLOTS or _left(id) <= 0
		row.add_child(add)
		var nm := Label.new()
		nm.text = "%s x%d" % [_name_of(id), _left(id)]
		nm.custom_minimum_size = Vector2(140, 0)
		nm.add_theme_color_override("font_color", Color(0.9, 0.88, 0.95))
		row.add_child(nm)
		row.add_child(_element_pips(GameData.reagent_elements(id)))
		reagent_box.add_child(row)
	if not any:
		var e := Label.new()
		e.text = "  올릴 재료가 없다. 작물·물고기·광물·채집물을 모아 오자."
		e.add_theme_color_override("font_color", Color(0.6, 0.57, 0.7))
		reagent_box.add_child(e)

	# ---- 조합법 ----
	var buff: String = GameData.potion_text()
	if buff != "":
		var bl := Label.new()
		bl.text = "오늘의 약효: " + buff
		bl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
		formula_box.add_child(bl)

	for fid: String in GameData.FORMULA_IDS:
		if not GameData.knows_formula(fid):
			continue
		var def: Dictionary = GameData.FORMULAS[fid]
		var can := not _auto_pick(fid).is_empty()
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 5)
		var mk := _mk_button("만들기", _make.bind(fid))
		mk.disabled = not can
		row2.add_child(mk)
		var drink := _mk_button("마시기", func() -> void:
			main.do_drink(fid)
			_rebuild())
		drink.disabled = int(GameData.items[fid]) <= 0
		row2.add_child(drink)
		var l2 := Label.new()
		l2.text = "%s  x%d" % [def.name, int(GameData.items[fid])]
		l2.add_theme_color_override("font_color",
			Color(0.98, 0.94, 0.72) if can else Color(0.64, 0.62, 0.7))
		row2.add_child(l2)
		# 지금 만들 수 있는지를 한 글자로 — 목록이 길어져도 눈에 들어온다
		var chip := Label.new()
		chip.text = "  ● 가능" if can else "  ○ 부족"
		chip.add_theme_color_override("font_color",
			Color(0.5, 0.88, 0.6) if can else Color(0.55, 0.52, 0.62))
		row2.add_child(chip)
		formula_box.add_child(row2)
		var d2 := Label.new()
		d2.text = "    %s · %s" % [GameData.formula_need_text(fid), def.effect]
		d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d2.add_theme_color_override("font_color", Color(0.62, 0.58, 0.75))
		formula_box.add_child(d2)

	# 마지막 연금술 — 일곱 재료가 다 모이면 여기서 끝을 낸다
	# (예전에는 연구 노트 안에 버튼이 있었다. 연금술은 조합대에서 한다)
	if GameData.legends_owned() > 0 and not GameData.ending_seen:
		var fl := Label.new()
		fl.text = "\n[마지막 연금술] 일곱 재료 %d / %d" % [GameData.legends_owned(),
			GameData.LEGENDS.size()]
		fl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		formula_box.add_child(fl)
		var fb := _mk_button("마지막 연금술을 시작한다", func() -> void:
			close()
			main.show_ending())
		fb.disabled = not GameData.can_final_alchemy()
		formula_box.add_child(fb)
	elif GameData.ending_seen:
		var fl2 := Label.new()
		fl2.text = "\n[유니콘의 뿔] 조합대 위에서 조용히 빛나고 있다."
		fl2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		formula_box.add_child(fl2)

	var left: int = GameData.unknown_formulas().size()
	var tail := Label.new()
	if left > 0:
		tail.text = "\n  아직 모르는 조합법이 %d가지 남았다.\n  재료 셋을 직접 올려 실험하거나,\n  나무·바위·몬스터에서 낡은 조합법을 주울 수 있다." % left
	else:
		tail.text = "\n  조합법을 모두 알아냈다. 할아버지의 노트가 다 채워졌다."
	tail.add_theme_color_override("font_color", Color(0.6, 0.57, 0.7))
	formula_box.add_child(tail)
