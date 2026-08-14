# 연구 노트 (N): 할아버지가 남긴 노트. 발견할 때마다 빈 페이지가 채워지고,
# 절반 이상 채워지면 숨겨진 메모가 하나씩 해금된다. (게임의 핵심 시스템)
#
# 두 장으로 나뉜다 —
#   도감: 모으는 것들. 네모칸 격자. 못 얻은 것은 어두운 칸에 물음표,
#         칸에 마우스를 올리면 설명과 「처음 얻은 날」이 뜬다.
#   이야기: 연금술 조합법 · 주민 · 숨겨진 메모. 읽는 것이라 줄글 그대로.
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var scroll: ScrollContainer
var _refresh_timer := 0.0
var tab := "collect"          # "collect" | "story"
var _tab_buttons := {}
var _tip: PanelContainer
var _tip_label: Label


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(210, 78)
	panel.custom_minimum_size = Vector2(540, 375)
	var style := StyleBoxFlat.new()
	# 노트 느낌의 밝은 양피지 배경
	style.bg_color = Color(0.93, 0.88, 0.74, 0.98)
	style.border_color = Color(0.55, 0.42, 0.26)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 할아버지의 연구 노트 (%s/ESC: 닫기) -" % GameData.key_label("open_note")
	title.add_theme_color_override("font_color", Color(0.5, 0.32, 0.12))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	for t: Array in [["collect", "도감"], ["story", "이야기"]]:
		var b := Button.new()
		b.text = str(t[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(90, 24)
		b.pressed.connect(_show_tab.bind(str(t[0])))
		tabs.add_child(b)
		_tab_buttons[t[0]] = b

	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(510, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_box.add_theme_constant_override("separation", 2)
	scroll.add_child(items_box)

	# 칸에 마우스를 올리면 뜨는 설명 (다른 무엇보다 위에)
	_tip = PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.16, 0.13, 0.09, 0.97)
	ts.border_color = Color(0.62, 0.48, 0.28)
	ts.set_border_width_all(2)
	ts.set_content_margin_all(7)
	_tip.add_theme_stylebox_override("panel", ts)
	_tip.visible = false
	_tip.z_index = 50
	add_child(_tip)
	_tip_label = Label.new()
	_tip_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74))
	_tip_label.custom_minimum_size = Vector2(0, 0)
	_tip.add_child(_tip_label)


func _show_tab(t: String) -> void:
	tab = t
	_rebuild()


func _tab_style() -> void:
	for k in _tab_buttons:
		_tab_buttons[k].disabled = (k == tab)


# ---- 격자 ----
#
# 갈래마다 아이콘 한 줄짜리 표. 얻은 것은 아이콘, 못 얻은 것은 어두운
# 칸에 물음표. 마우스를 올리면 설명 + 처음 얻은 날.
const CELL := 40
const COLS := 11


func _grid(entries: Array) -> void:
	# entries: [{icon, name, found, count_text, desc, date}]
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	items_box.add_child(grid)
	for e: Dictionary in entries:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(CELL, CELL)
		var st := StyleBoxFlat.new()
		var found: bool = e.found
		st.bg_color = Color(0.85, 0.79, 0.62) if found else Color(0.32, 0.29, 0.24)
		st.border_color = Color(0.6, 0.47, 0.28) if found else Color(0.42, 0.38, 0.32)
		st.set_border_width_all(2)
		st.set_corner_radius_all(4)
		cell.add_theme_stylebox_override("panel", st)
		if found and main.tex.has(str(e.icon)) and main.tex[str(e.icon)] != null:
			var icon := TextureRect.new()
			icon.texture = main.tex[str(e.icon)]
			# 원본이 커도 칸 안에 맞춰 줄어든다 (잡초 그림이 칸을 뚫고
			# 크게 보이던 버그 — expand_mode 기본값이 원본 크기를 강제했다)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 4
			icon.offset_top = 4
			icon.offset_right = -4
			icon.offset_bottom = -4
			cell.add_child(icon)
		else:
			var q := Label.new()
			q.text = "?"
			q.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
			q.set_anchors_preset(Control.PRESET_FULL_RECT)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.add_child(q)
		cell.mouse_entered.connect(_cell_tip.bind(cell, e))
		cell.mouse_exited.connect(func() -> void: _tip.visible = false)
		grid.add_child(cell)


func _cell_tip(cell: Panel, e: Dictionary) -> void:
	var text := ""
	if e.found:
		text = str(e.name)
		if str(e.get("count_text", "")) != "":
			text += "\n" + str(e.count_text)
		if str(e.get("desc", "")) != "":
			text += "\n" + str(e.desc)
		if str(e.get("date", "")) != "":
			text += "\n처음 얻은 날: " + str(e.date)
	else:
		text = "???\n" + str(e.get("hint", "아직 만나지 못했다"))
	_tip_label.text = text
	_tip.visible = true
	# 칸 오른쪽 아래. 화면 밖으로 나가면 왼쪽으로 뒤집는다
	var pos := cell.get_screen_position() + Vector2(CELL + 4, 0)
	_tip.reset_size()
	if pos.x + 240 > 960:
		pos.x = cell.get_screen_position().x - _tip.size.x - 4
	_tip.position = pos


func toggle() -> void:
	visible = not visible
	if visible:
		# 스토리 12 — 노트를 펼치는 순간, 끼워져 있던 낯선 기록이 읽힌다
		main.story.story12_note_read()
		_rebuild()


func close() -> void:
	visible = false


# 도감은 여는 순간에만 다시 그린다 — 예전처럼 0.5초마다 격자를 부수고
# 다시 지으면, 마우스를 올려 둔 칸이 사라지면서 툴팁이 금방 꺼졌다.


func _line(text: String, color := Color(0.24, 0.17, 0.09)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	items_box.add_child(l)


func _head(text: String) -> void:
	_line(text, Color(0.5, 0.32, 0.12))


const DIM := Color(0.55, 0.48, 0.4)
const GOLD := Color(0.62, 0.42, 0.05)


func _rebuild() -> void:
	_tab_style()
	for c in items_box.get_children():
		c.queue_free()
	_tip.visible = false

	var prog: Dictionary = GameData.note_progress()
	var pct := int(prog.ratio * 100.0)
	_head("기록된 페이지: %d / %d (%d%%)" % [int(prog.filled), int(prog.total), pct])
	if tab == "collect":
		_rebuild_collect()
	else:
		_rebuild_story()


# ---- 도감 (격자) ----
func _rebuild_collect() -> void:
	_line("새로운 것을 발견하면 빈 페이지가 채워진다. 칸에 마우스를 올려 보자.", DIM)

	# 할아버지의 마지막 부탁 — 게임의 핵심 목표와 엔딩 재료의 진행 상황.
	# 노트가 20% 차오를 때마다 할머니의 유품 힌트가 하나씩 열린다
	_line("")
	_head("[할아버지의 마지막 부탁]")
	_line("  이 노트를 100% 채우는 것 — 그것이 할아버지의 연구의 끝이다.", DIM)
	_line("  생명의 물 %d/%d — 일곱 분야(채광·벌목·농사·요리·전투·낚시·목장)를" %
		[GameData.water_life_found.size(), GameData.ENDING_SKILLS.size()], DIM)
	_line("  만렙까지 갈고닦으면 한 병씩 손에 들어온다.", DIM)
	for i in GameData.RELICS.size():
		var rdef: Dictionary = GameData.RELICS[i]
		if int(GameData.items[rdef.id]) > 0:
			_line("  ★ %s — 찾았다!" % str(rdef.name), GOLD)
		elif GameData.relic_hint_open(i):
			_line("  %s — 『%s』" % [str(rdef.name), str(rdef.hint)], DIM)
		else:
			_line("  ???  — 노트 %d%%에서 힌트가 열린다" % int(20 * (i + 1)), DIM)

	# 컬렉션 — 묶음을 다 모으면 레시피가 열린다
	# 낯선 기록 (스토리 12) — 노트 40%에서 발견되는 할아버지의 고백
	if GameData.story12_phase != "":
		_line("")
		_head("[낯선 기록]")
		_line("  「이 재료만은 끝내 내 힘으로 풀지 못했다.", DIM)
		_line("   그 사람의 손을 빌렸다. ...고마운 일이다.」", DIM)
		if GameData.story12_phase == "done":
			_line("  ★ 깊은 숲의 연금술사 묘연 — 그 사람을 찾았다!", GOLD)
		else:
			_line("  누구의 이야기일까... (%s)" %
				GameData.story12_objective_short(), DIM)

	_line("")
	_head("[컬렉션]")
	for col: Dictionary in GameData.COLLECTIONS:
		if not GameData.collection_open(col):
			continue   # 이야기로 잠긴 묶음 — 스토리 10 조사가 시작되면 나타난다
		var have := GameData.collection_have(col)
		var total := (col.ids as Array).size()
		var done: bool = str(col.id) in GameData.collections_done
		# 보상 표기 — 레시피 보상이면 「~ 레시피」, 영구 버프면 그 설명
		var rname := "" if str(col.reward) == "" \
			else "%s 레시피" % str(GameData.ITEMS[col.reward].name)
		if rname == "" and str(col.get("perk_text", "")) != "":
			rname = str(col.perk_text)
		if done:
			_line("  ★ %s %d/%d%s" % [col.name, have, total,
				(" — %s!" % rname) if rname != "" else " — 완성!"], GOLD)
		else:
			var reward_hint := "???" if have < total - 1 \
				else (rname if rname != "" else "완성 기념")
			_line("  %s %d/%d — 보상: %s" % [col.name, have, total, reward_hint], DIM)

	# 기본 재료 — 목재·석재·못. 세기는 어디서나 쓰이는데 도감에는 칸이
	# 없어서 「나무·돌이 안 보인다」는 구멍이 있었다.
	_line("")
	var mats: Array = [
		{"id": "wood", "icon": "icon_wood", "name": "목재",
			"found": GameData.wood > 0 or GameData.trees_chopped > 0
				or GameData.discovered.has("wood"),
			"desc": "나무를 베면 얻는다 — 건축·제작의 근본"},
		{"id": "stone", "icon": "icon_stone", "name": "석재",
			"found": GameData.stone > 0 or GameData.discovered.has("stone"),
			"desc": "바위를 캐면 얻는다 — 건축·설치물 재료"},
		{"id": "nail", "icon": "nail", "name": "못",
			"found": int(GameData.items.get("nail", 0)) > 0
				or GameData.discovered.has("nail"),
			"desc": "대장간에서 판다 — 집터·가구 재료"},
	]
	var mat_got := 0
	var mat_rows: Array = []
	for mt: Dictionary in mats:
		if bool(mt.found):
			mat_got += 1
		mat_rows.append({"icon": mt.icon, "name": mt.name, "found": mt.found,
			"desc": mt.desc, "date": GameData.discovered_on(str(mt.id)),
			"hint": "마을 곳곳에서 얻을 수 있다"})
	_head("[기본 재료]  %d / %d" % [mat_got, mats.size()])
	_grid(mat_rows)

	# 도구 — 언제나 같은 순서(ALL_TOOLS)로 깔끔하게 늘어선다
	_line("")
	var tool_got := 0
	var tool_rows: Array = []
	for t: String in GameData.ALL_TOOLS:
		var unlocked: bool = GameData.is_tool_unlocked(t)
		if unlocked:
			tool_got += 1
		var lv := int(GameData.tool_level.get(t, 1))
		tool_rows.append({"icon": main.hud.TOOL_ICONS.get(t, ""),
			"name": GameData.TOOL_KOR.get(t, t), "found": unlocked,
			"desc": "강화 Lv.%d — 대장간에서 올린다" % lv, "date": "",
			"hint": "이야기를 진행하면 손에 들어온다"})
	_head("[도구]  %d / %d" % [tool_got, GameData.ALL_TOOLS.size()])
	_grid(tool_rows)

	_line("")
	_head("[작물]  %s" % _count(GameData.CROP_IDS, GameData.crops_harvested))
	var rows: Array = []
	for id in GameData.CROP_IDS:
		var n := int(GameData.crops_harvested.get(id, 0))
		rows.append({"icon": "mature_" + id, "name": GameData.CROPS[id].name,
			"found": n > 0,
			"desc": "%s 씨앗 %dG" % [GameData.season_list(id), GameData.CROPS[id].seed_price],
			"date": GameData.discovered_on(id), "hint": "밭에 심어 거둬 보자"})
	_grid(rows)

	_line("")
	_head("[물고기]  %s" % _count(GameData.FISH_IDS, GameData.fish_caught))
	rows = []
	for fid in GameData.FISH_IDS:
		var caught := int(GameData.fish_caught.get(fid, 0))
		rows.append({"icon": fid, "name": GameData.ITEMS[fid].name,
			"found": caught > 0, "count_text": "%dG" % GameData.ITEMS[fid].sell,
			"desc": _fish_desc(fid),
			"date": GameData.discovered_on(fid), "hint": _fish_desc(fid)})
	_grid(rows)

	_line("")
	_head("[요리]  %s" % _count(GameData.RECIPE_IDS, GameData.recipes_cooked))
	rows = []
	for rid in GameData.RECIPE_IDS:
		var made := int(GameData.recipes_cooked.get(rid, 0))
		rows.append({"icon": rid, "name": GameData.ITEMS[rid].name,
			"found": made > 0,
			"desc": "회복 %d · %dG" % [int(GameData.RECIPES[rid].energy), GameData.ITEMS[rid].sell],
			"date": GameData.discovered_on(rid), "hint": "조리대에서 실험해 보자"})
	_grid(rows)

	_line("")
	var got_m := 0
	for mid in ["ore", "gem", "star_shard"]:
		if GameData.minerals_found.get(mid, false) or GameData.discovered.has(mid):
			got_m += 1
	_head("[광물]  %d / 3" % got_m)
	rows = []
	for mid in ["ore", "gem", "star_shard"]:
		var found: bool = GameData.minerals_found.get(mid, false) or GameData.discovered.has(mid)
		rows.append({"icon": mid, "name": GameData.ITEMS[mid].name,
			"found": found, "count_text": "%dG" % GameData.ITEMS[mid].sell,
			"desc": "동굴에서 캔다", "date": GameData.discovered_on(mid),
			"hint": "동굴 어딘가에"})
	_grid(rows)

	_line("")
	_head("[채집 · 곤충]  %s" % _count(GameData.FORAGE_IDS + GameData.BUG_IDS, GameData.forage_caught))
	rows = []
	for fid2 in GameData.FORAGE_IDS + GameData.BUG_IDS:
		var got := int(GameData.forage_caught.get(fid2, 0))
		rows.append({"icon": fid2, "name": GameData.ITEMS[fid2].name,
			"found": got > 0,
			"desc": "들과 숲에서", "date": GameData.discovered_on(fid2),
			"hint": "들판과 계절을 살펴보자"})
	_grid(rows)

	_line("")
	_head("[몬스터]  %s" % _count(GameData.MOBS.keys(), GameData.mob_kills))
	rows = []
	for mid2 in GameData.MOBS:
		var kills := int(GameData.mob_kills.get(mid2, 0))
		rows.append({"icon": mid2 + "_0", "name": GameData.MOBS[mid2].name,
			"found": kills > 0,
			"desc": GameData.MOBS[mid2].desc, "date": "",
			"hint": "동굴에서 만나보자"})
	_grid(rows)

	_line("")
	var known_f := 0
	for fo in GameData.FORMULA_IDS:
		if int(GameData.alchemy_brews.get(fo, 0)) > 0 or GameData.discovered.has(fo):
			known_f += 1
	_head("[물약]  %d / %d" % [known_f, GameData.FORMULA_IDS.size()])
	rows = []
	for fo2 in GameData.FORMULA_IDS:
		var def: Dictionary = GameData.FORMULAS[fo2]
		# 조합법을 「아는 것」과 「빚어 본 것」은 다르다 — 도감에는
		# 실제로 한 병이라도 얻어 봐야 등록된다
		rows.append({"icon": fo2, "name": def.name,
			"found": int(GameData.alchemy_brews.get(fo2, 0)) > 0
				or GameData.discovered.has(fo2),
			"desc": str(def.effect), "date": GameData.discovered_on(fo2),
			"hint": "재료 셋을 조합대에 올려 보자"})
	_grid(rows)
	_line("")


func _count(ids: Array, tally: Dictionary) -> String:
	var got := 0
	for id in ids:
		if int(tally.get(id, 0)) > 0:
			got += 1
	return "%d / %d" % [got, ids.size()]


# 물고기가 언제 무는지 — 표에서 만들어 준다 (도감 힌트)
func _fish_desc(fid: String) -> String:
	for f: Dictionary in GameData.FISH:
		if str(f.id) != fid:
			continue
		var bits: Array[String] = []
		var seasons: Array = f.seasons
		if not seasons.is_empty():
			var names: Array[String] = []
			for sn in seasons:
				names.append(GameData.SEASON_NAMES[int(sn)])
			bits.append("/".join(names))
		match str(f.time):
			"morning": bits.append("아침")
			"day": bits.append("낮")
			"night": bits.append("밤")
		var weathers: Array = f.weather
		for w in weathers:
			bits.append(str(GameData.WEATHERS[int(w)].name) + " 날")
		if bits.is_empty():
			return "어디서나 문다"
		return " · ".join(bits) + "에 문다"
	return ""


# ---- 이야기 (줄글) ----
func _rebuild_story() -> void:
	# 연금술 (조합대에서 알아낸 것)
	_line("")
	_head("[연금술 조합법]")
	for fid in GameData.FORMULA_IDS:
		var def: Dictionary = GameData.FORMULAS[fid]
		if GameData.knows_formula(fid):
			var made := int(GameData.alchemy_brews.get(fid, 0))
			_line("  %s — %s" % [def.name, GameData.formula_need_text(fid)])
			_line("   \"%s\"" % def.note, Color(0.35, 0.27, 0.16))
			_line("   %s (지금까지 %d병)" % [def.effect, made], DIM)
		else:
			_line("  ??? — 재료 셋을 조합대에 올려 실험해 보자", DIM)
	if GameData.alchemy_fails > 0:
		_line("  (실패해서 앙금만 남은 적: %d번)" % GameData.alchemy_fails, DIM)

	# 주민 이야기
	_line("")
	_head("[주민 이야기]")
	for npc_id in GameData.NPCS:
		var def2: Dictionary = GameData.NPCS[npc_id]
		var aff := int(GameData.affinity[npc_id])
		# 생일과 취향 — 취향은 좀 친해져야 알게 된다
		var head_bits: Array[String] = []
		var b: Array = def2.get("birthday", [])
		if b.size() == 2:
			head_bits.append("생일 %s %d일" % [GameData.SEASON_NAMES[int(b[0])], int(b[1])])
		if GameData.spouse == npc_id:
			head_bits.append("배우자")
		elif GameData.dating == npc_id:
			head_bits.append("연인")
		if not head_bits.is_empty():
			_line("  %s — %s" % [def2.name, " · ".join(head_bits)], GOLD)
		if aff >= 30:
			var loves: Array = def2.get("loves", [])
			var names: Array[String] = []
			for lid: String in loves:
				names.append(_item_name(lid))
			_line("   아주 좋아하는 것: %s" % ", ".join(names), DIM)
		else:
			_line("   좋아하는 것은 아직 모른다 (호감도 30부터)", DIM)
		if aff >= 50:
			_line("  %s의 기억:" % def2.name)
			_line("   \"%s\"" % String(def2.secret50).replace("\n", " "), Color(0.35, 0.27, 0.16))
		else:
			_line("  %s — 더 친해지면 이야기해 줄 것 같다 (%d/50)" % [def2.name, aff], DIM)
		if aff >= 100:
			_line("   \"%s\"" % String(def2.secret100).replace("\n", " "), Color(0.35, 0.27, 0.16))
		elif aff >= 50:
			_line("   ...아직 못다 한 이야기가 있는 듯하다 (%d/100)" % aff, DIM)

	# 할아버지의 숨겨진 메모 (진행도 해금)
	var prog: Dictionary = GameData.note_progress()
	_line("")
	_head("[할아버지의 숨겨진 메모]")
	for memo in GameData.NOTE_MEMOS:
		if prog.ratio >= float(memo[0]):
			_line("  · %s" % memo[1], GOLD)
		else:
			_line("  · (%d%%를 채우면 열린다)" % int(float(memo[0]) * 100.0), DIM)

	# 바다가 남긴 이야기 — 해변의 매우 희귀한 조각을 주우면 열린다
	if GameData.sea_open:
		_line("")
		_head("[바다가 남긴 이야기]")
		if GameData.discovered.has("forage_relic"):
			_line("  · 물에 잠긴 마을", GOLD)
			_line("     고대 조각의 무늬가 보여 준 풍경 — 바다 밑에는 아주 오래전", Color(0.35, 0.27, 0.16))
			_line("     가라앉은 마을이 잠들어 있고, 그 사이를 황금빛 그림자가 헤엄친다.", Color(0.35, 0.27, 0.16))
			_line("     ...철수가 쫓는 황금잉어와 무슨 관계가 있을까?", Color(0.35, 0.27, 0.16))
		else:
			_line("  · (해변에 아주 드물게 밀려오는 옛 조각이 이야기를 안다)", DIM)
		if GameData.discovered.has("forage_coral"):
			_line("  · 바다가 피운 꽃 — 산호 조각으로 「산호빛 차」를 달일 수 있다", GOLD)
	_line("")


func _item_name(id: String) -> String:
	if GameData.CROPS.has(id):
		return str(GameData.CROPS[id].name)
	if GameData.ITEMS.has(id):
		return str(GameData.ITEMS[id].name)
	return id
