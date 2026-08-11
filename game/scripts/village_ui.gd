# 마을에서 여는 창들 — 상점·여관·연구소·도서관·축제·의뢰·선물,
# 그리고 온실·광산·집 짓기·마을 건물 짓기.
#
# 공통점: **대화창 하나로 시작해서, 버튼을 누르면 무슨 일이 벌어진다.**
# 세계 상태를 매 프레임 굴리는 쪽(main)과 성격이 달라서 따로 뺐다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
extends Node

var m: KyojinMain    # main.gd
var _gift_layer: CanvasLayer = null


func _open_build_dialog() -> void:
	m.dialog.open("집터",
		"할아버지가 남긴 집터다.\n재료를 모아 직접 집을 지어야 한다.\n\n필요 재료: 목재 %d (보유 %d)" %
			[GameData.HOUSE_BUILD_WOOD, GameData.wood], [
		["집 짓기", _build_house],
		["닫기", null],
	])


func _build_house() -> void:
	if GameData.house_lv > 0:
		return  # 이미 지은 집 — 두 번 지어지지 않는다
	if GameData.wood < GameData.HOUSE_BUILD_WOOD:
		m.dialog.set_body("목재가 부족하다... (%d/%d)\n도끼로 나무를 베어 목재를 모으자." %
			[GameData.wood, GameData.HOUSE_BUILD_WOOD])
		return
	GameData.wood -= GameData.HOUSE_BUILD_WOOD
	GameData.house_lv = 1
	m.tutorial_notify("home")
	m._remove_object(m.HOME_SITE)
	m.worldgen._fill_building(m.HOME_ANCHOR)
	Sound.play_sfx("sfx_place")
	m.dialog.set_body("우리집 완성!\n아직 안은 텅 비어 있다.\n침대(목재 %d)를 만들어야 잠을 잘 수 있다." %
		GameData.BED_WOOD)
	m.dialog.set_buttons([["좋아!", null]])
	m.hud.quest_toast("집 짓기")
	m.save_now()


func _next_village_build() -> String:
	for pid in m.VILLAGE_BUILD_ORDER:
		if not GameData.village_built.has(pid):
			return pid
	return ""


func _open_village_build_dialog() -> void:
	var pid := _next_village_build()
	if pid == "":
		m.dialog.open("마을 발전",
			"지금 지을 수 있는 건물은 다 세웠네.\n마을이 제법 그럴듯해졌구먼!",
			[["좋군요!", null]])
		return
	var plot: Dictionary = m.VILLAGE_PLOTS[pid]
	var cost: Array = m.VILLAGE_BUILD_COST[pid]
	m.dialog.open("마을 발전 — %s" % plot.name,
		"%s(을)를 지을 자리는 이미 비워 두었네.\n재료만 모아 오면 마을 사람들과 함께 세우겠네.\n\n필요 재료: 목재 %d (보유 %d) · 석재 %d (보유 %d)" %
			[plot.name, cost[0], GameData.wood, cost[1], GameData.stone], [
		["%s 짓기" % plot.name, _build_village_building.bind(pid)],
		["나중에", null],
	])


func _build_village_building(pid: String) -> void:
	var plot: Dictionary = m.VILLAGE_PLOTS[pid]
	var cost: Array = m.VILLAGE_BUILD_COST[pid]
	if GameData.village_built.has(pid):
		return  # 이미 세운 건물 — 버튼을 또 눌러도 재료가 사라지지 않는다
	if GameData.wood < int(cost[0]) or GameData.stone < int(cost[1]):
		m.dialog.set_body("재료가 아직 부족하네...\n\n목재 %d/%d · 석재 %d/%d" %
			[GameData.wood, cost[0], GameData.stone, cost[1]])
		return
	GameData.wood -= int(cost[0])
	GameData.stone -= int(cost[1])
	GameData.village_built.append(pid)
	m.worldgen._fill_building(plot.anchor, pid)
	m._sync_village_npcs()
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("%s 완공!" % plot.name)
	m.dialog.set_body("%s(이)가 세워졌네!\n마을이 조금씩 살아나는구먼." % plot.name)
	m.dialog.set_buttons([["좋군요!", null]])
	m.queue_redraw()
	m.save_now()


func _talk_to(npc: Node2D) -> void:
	var def: Dictionary = GameData.NPCS[npc.id]
	if not npc.talked_today:
		npc.talked_today = true
		GameData.affinity[npc.id] = int(GameData.affinity[npc.id]) + 2
	# 봄 꽃놀이: 말을 건 사람을 하나씩 세어 둔다
	if GameData.festival_open() and str(GameData.festival_today().id) == "flower" \
			and not GameData.fest_greeted.has(npc.id):
		GameData.fest_greeted.append(npc.id)
		m.renderer.spawn_particles(m.player_tile(), "sparkle")
		if GameData.fest_greeted.size() >= GameData.NPCS.size():
			_finish_festival()
			return
	var lines: Array = def.lines
	var line: String = lines[randi() % lines.size()]
	var aff := mini(int(GameData.affinity[npc.id]), 100)
	# 호감도가 오르면 비밀 이야기(할아버지의 과거)가 섞여 나온다
	if aff >= 100 and def.has("secret100") and randf() < 0.4:
		line = def.secret100
	elif aff >= 50 and def.has("secret50") and randf() < 0.4:
		line = def.secret50
	var hearts := int(aff / 10.0)
	var title := "%s %s (%d/100)" % [def.name, "♥".repeat(maxi(hearts, 0)), aff]
	if aff >= 50:
		line += "\n(친밀한 사이다! 특전 발동 중)"
	# 호감도 100: 할아버지의 기억 조각을 건네받는다 (1회)
	if aff >= 100 and not GameData.memory_given:
		GameData.memory_given = true
		line = def.get("secret100", line)
		m.gain_legend("memory_piece")
		if Net.is_host():
			m._broadcast_stats()
	var choices := [
		["선물하기", _open_gift_picker.bind(npc.id)],
		["대화 끝", null],
	]
	# 이장은 마을 발전(빈 부지에 건물 세우기)을 맡고 있다
	if npc.id == "chief" and GameData.story_phase == "done":
		choices.insert(0, ["마을 발전 이야기", _open_village_build_dialog])
	# 축제날에는 이장이 진행을 맡는다
	if npc.id == "chief" and GameData.festival_open():
		choices.insert(0, ["축제 이야기", _open_festival_dialog])
	m.dialog.open_seq(title, _npc_portrait(npc.id), [
		{"text": line, "choices": choices},
	])


func in_greenhouse(t: Vector2i) -> bool:
	return GameData.greenhouse_built and m.GREENHOUSE.has_point(t)


func _open_greenhouse_dialog() -> void:
	if GameData.greenhouse_built:
		m.dialog.open("온실", "유리 너머로 늘 봄이다.\n\n이 안에서는 계절을 타지 않는다 —\n"
			+ "아무 씨앗이나 심을 수 있고,\n계절이 바뀌어도 시들지 않는다.",
			[["좋다", null]])
		return
	var ok: bool = GameData.wood >= m.GREENHOUSE_COST_WOOD \
		and GameData.stone >= m.GREENHOUSE_COST_STONE \
		and GameData.money >= m.GREENHOUSE_COST_MONEY
	var body := "여기에 온실을 세울 수 있다.\n\n온실 안에서는 계절을 타지 않는다.\n"
	body += "겨울에도 원하는 작물을 키울 수 있다.\n\n"
	body += "필요: 목재 %d/%d · 석재 %d/%d · %dG/%dG" % [
		GameData.wood, m.GREENHOUSE_COST_WOOD, GameData.stone, m.GREENHOUSE_COST_STONE,
		GameData.money, m.GREENHOUSE_COST_MONEY]
	m.dialog.open("온실 터", body,
		[["짓기", _build_greenhouse], ["나중에", null]] if ok else [["다음에", null]])


func _build_greenhouse() -> void:
	if GameData.greenhouse_built:
		return
	if GameData.wood < m.GREENHOUSE_COST_WOOD or GameData.stone < m.GREENHOUSE_COST_STONE \
			or GameData.money < m.GREENHOUSE_COST_MONEY:
		return
	GameData.wood -= m.GREENHOUSE_COST_WOOD
	GameData.stone -= m.GREENHOUSE_COST_STONE
	GameData.money -= m.GREENHOUSE_COST_MONEY
	GameData.greenhouse_built = true
	# 온실 안은 처음부터 갈아 둔 밭으로 만든다 (자연물은 치운다)
	for y in range(m.GREENHOUSE.position.y, m.GREENHOUSE.end.y):
		for x in range(m.GREENHOUSE.position.x, m.GREENHOUSE.end.x):
			var t := Vector2i(x, y)
			if m.objects.has(t) and m.objects[t].kind != "sign":
				m._remove_object(t)
			m.grid[y][x].ground = "soil"
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("온실 완공!")
	m.save_now()
	m.queue_redraw()
	m.dialog.open("온실", "온실이 완성됐다!\n\n이 안에서는 계절을 타지 않는다.\n"
		+ "겨울에도 원하는 작물을 키울 수 있다.", [["고맙습니다", null]])


func _open_mine_dialog() -> void:
	var floors: Array = GameData.mine_floors()
	if floors.size() <= 1:
		m.cave.open(false, 1)
		return
	var btns: Array = []
	for f: int in floors:
		btns.append(["%d층" % f, _enter_mine.bind(f)])
	btns.append(["그만두기", null])
	m.dialog.open("동굴 승강기",
		"가장 깊이 내려가 본 곳: %d층

어디서 시작할까?
(5층마다 승강기가 있다)"
		% GameData.mine_deepest, btns)


func _enter_mine(f: int) -> void:
	m.dialog.close()
	m.cave.open(false, f)


func room_action(kind: String) -> void:
	match kind:
		"rest":
			_open_inn_dialog()
		"breed":
			_open_lab_dialog()
		"read":
			_open_library_dialog()


func _open_inn_dialog() -> void:
	var can: bool = GameData.money >= m.INN_REST_COST
	var body := "따뜻한 방과 국 한 그릇.\n\n%d골드에 %d시간 쉬어 가면\n체력이 가득 찬다." \
		% [m.INN_REST_COST, int(m.INN_REST_HOURS)]
	if not can:
		body += "\n\n(소지금이 모자란다)"
	m.dialog.open("여관", body,
		[["쉬어 간다", _do_rest]] if can else [["다음에", null]])


func _do_rest() -> void:
	if GameData.money < m.INN_REST_COST:
		return
	GameData.money -= m.INN_REST_COST
	GameData.today_spent += m.INN_REST_COST
	GameData.energy = GameData.ENERGY_MAX
	# 쉬는 만큼 시간이 흐른다 (밤을 넘기지는 않는다)
	GameData.minutes = minf(GameData.minutes + m.INN_REST_HOURS * 60.0,
		GameData.DAY_END - 60.0)
	Sound.play_sfx("sfx_sleep")
	m.save_now()
	m.dialog.open("여관", "푹 쉬었다!\n체력이 가득 찼다.", [["고맙습니다", null]])


func _open_lab_dialog() -> void:
	var lv: int = GameData.breed_level
	var body := "지금 개량 단계: %d / %d\n성장 %d%% 단축 · 판매가 %d%% 상승" % [lv,
		GameData.BREED_MAX, int(round((1.0 - GameData.breed_grow_mult()) * 100.0)),
		int(round((GameData.breed_price_mult() - 1.0) * 100.0))]
	var cost := GameData.breed_next_cost()
	if cost.is_empty():
		m.dialog.open("연구소", body + "\n\n더 개량할 것이 없다. 최고 단계다!",
			[["훌륭하군요", null]])
		return
	body += "\n\n다음 단계: %dG · 광석 %d" % [int(cost[0]), int(cost[1])]
	var ok: bool = GameData.money >= int(cost[0]) \
		and int(GameData.items.get("ore", 0)) >= int(cost[1])
	if not ok:
		body += "\n(재료가 모자란다)"
	m.dialog.open("연구소 — 씨앗 개량", body,
		[["개량하기", _do_breed], ["나중에", null]] if ok else [["다음에", null]])


func _do_breed() -> void:
	var cost := GameData.breed_next_cost()
	if cost.is_empty() or GameData.money < int(cost[0]) \
			or int(GameData.items.get("ore", 0)) < int(cost[1]):
		return
	GameData.money -= int(cost[0])
	GameData.today_spent += int(cost[0])
	GameData.items["ore"] = int(GameData.items["ore"]) - int(cost[1])
	GameData.breed_level += 1
	Sound.play_sfx("sfx_catch")
	m.save_now()
	m.hud.quest_toast("씨앗 개량 %d단계!" % GameData.breed_level)
	_open_lab_dialog()


func _open_library_dialog() -> void:
	var left: Array = []
	for leg: Array in GameData.LEGENDS:
		if int(GameData.items.get(str(leg[0]), 0)) <= 0:
			left.append(leg)
	if left.is_empty():
		m.dialog.open("도서관", "일곱 재료를 모두 모았다.\n\n남은 것은 최후의 연금술뿐 —\n"
			+ "연구 노트(N)를 펼쳐 보자.", [["가보겠습니다", null]])
		return
	var pick: Array = left[GameData.day % left.size()]
	m.dialog.open("도서관", "먼지 쌓인 책 사이에서\n할아버지의 메모를 찾았다.\n\n"
		+ "「%s」 — %s\n\n· %s에서 찾을 수 있다." % [GameData.ITEMS[pick[0]].name,
		pick[2], pick[1]], [["기억해 두자", null]])


func _open_festival_dialog() -> void:
	var f: Dictionary = GameData.festival_today()
	if f.is_empty():
		return
	var p := GameData.festival_progress()
	var body: String = "%s\n\n· %s" % [f.desc, f.goal]
	var btns: Array = [["알겠습니다", null]]
	match str(f.id):
		"flower", "fishing":
			body += "\n  지금 %d / %d" % [mini(int(p[0]), int(p[1])), int(p[1])]
			if int(p[0]) >= int(p[1]):
				btns = [["결과 보고하기", _finish_festival]]
		"harvest":
			var best := _best_produce()
			if best == "":
				body += "\n\n(수확한 작물이 없다. 하나 거둬 오자!)"
			else:
				body += "\n\n출품할 작물: %s" % GameData.CROPS[best].name
				btns = [["출품하기", _submit_harvest], ["나중에", null]]
		"star":
			var dish := _first_dish()
			if dish == "":
				body += "\n\n(가진 요리가 없다. 집 조리대에서 만들어 오자!)"
			else:
				body += "\n\n나눠 줄 요리: %s" % GameData.ITEMS[dish].name
				btns = [["나눠 주기", _submit_dish], ["나중에", null]]
	m.dialog.open("%s — 이장 덕수" % f.name, body, btns, _npc_portrait("chief", true))


func _best_produce() -> String:
	for kind: String in ["produce_gold", "produce_silver", "produce"]:
		var d: Dictionary = GameData.get(kind)
		for cid: String in GameData.CROP_IDS:
			if int(d.get(cid, 0)) > 0:
				return cid
	return ""


func _first_dish() -> String:
	for rid: String in GameData.RECIPE_IDS:
		if int(GameData.items.get(rid, 0)) > 0:
			return rid
	return ""


func _submit_harvest() -> void:
	var cid := _best_produce()
	if cid == "":
		return
	# 품질이 높을수록 상금이 오른다
	var bonus := 1.0
	var grade := "일반"
	if int(GameData.produce_gold.get(cid, 0)) > 0:
		GameData.produce_gold[cid] = int(GameData.produce_gold[cid]) - 1
		bonus = 2.0
		grade = "금빛"
	elif int(GameData.produce_silver.get(cid, 0)) > 0:
		GameData.produce_silver[cid] = int(GameData.produce_silver[cid]) - 1
		bonus = 1.5
		grade = "은빛"
	GameData.produce[cid] = maxi(0, int(GameData.produce[cid]) - 1)
	_finish_festival(bonus, "%s %s로 출품했다!" % [grade, GameData.CROPS[cid].name])


func _submit_dish() -> void:
	var rid := _first_dish()
	if rid == "":
		return
	GameData.items[rid] = int(GameData.items[rid]) - 1
	# 요리를 나누면 모두와 조금씩 가까워진다
	for nid: String in GameData.affinity:
		GameData.affinity[nid] = mini(int(GameData.affinity[nid]) + 3, 100)
	_finish_festival(1.0, "%s를 나눠 먹었다! 모두와 조금 가까워졌다." % GameData.ITEMS[rid].name)


func _finish_festival(bonus := 1.0, extra := "") -> void:
	var f: Dictionary = GameData.festival_today()
	if f.is_empty() or GameData.fest_done:
		return
	GameData.fest_done = true
	if not GameData.fest_history.has(str(f.id)):
		GameData.fest_history.append(str(f.id))
	var money := int(int(f.reward.get("money", 0)) * bonus)
	GameData.money += money
	GameData.today_earned += money
	# 봄 꽃놀이는 인사를 나눈 만큼 모두와 가까워진다
	if str(f.id) == "flower":
		for nid: String in GameData.affinity:
			GameData.affinity[nid] = mini(int(GameData.affinity[nid]) + 5, 100)
	Sound.play_sfx("sfx_catch")
	m.hud.quest_toast(str(f.name))
	m.hud.reward_toast("%dG" % money, m.tex["icon_coin"])
	if Net.is_host():
		m._broadcast_stats()
	m.save_now()
	m.dialog.open(str(f.name), "%s%s\n\n상금 %dG를 받았다.\n\n내년에도 또 만나자!"
		% [extra, "\n" if extra != "" else "", money], [["좋았어!", null]],
		_npc_portrait("chief", true))


func _npc_portrait(npc_id: String, happy := false) -> Texture2D:
	# 호감도 50+ 또는 선물 직후엔 웃는 얼굴
	var expr := "happy" if (happy or int(GameData.affinity[npc_id]) >= 50) else "normal"
	return m.tex["npc_%s_portrait_%s" % [npc_id, expr]]


func _open_gift_picker(npc_id: String) -> void:
	var entries: Array = []
	for id: String in GameData.CROP_IDS:
		if int(GameData.produce.get(id, 0)) > 0:
			entries.append(["produce", id, str(GameData.CROPS[id].name),
				int(GameData.produce[id])])
	for id: String in GameData.ITEM_IDS:
		if int(GameData.items.get(id, 0)) > 0:
			entries.append(["item", id, str(GameData.ITEMS[id].name),
				int(GameData.items[id])])
	if entries.is_empty():
		m.dialog.set_body("선물할 것이 없다... 수확물이나 생산물이 필요하다.")
		return
	_close_gift_picker()
	_gift_layer = CanvasLayer.new()
	_gift_layer.layer = 30
	var panel := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.91, 0.71, 0.42, 0.98)
	st.border_color = Color(0.43, 0.24, 0.11)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", st)
	panel.position = Vector2(300, 110)
	panel.size = Vector2(360, 320)
	_gift_layer.add_child(panel)
	var lab := Label.new()
	lab.text = "무엇을 선물할까?"
	lab.position = Vector2(0, 8)
	lab.size = Vector2(360, 24)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color(0.29, 0.16, 0.06))
	panel.add_child(lab)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 38)
	scroll.size = Vector2(332, 234)
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(322, 0)
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for e: Array in entries:
		var btn := Button.new()
		btn.text = "%s  x%d" % [e[2], e[3]]
		btn.custom_minimum_size = Vector2(322, 30)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_give_gift.bind(npc_id, str(e[0]), str(e[1])))
		list.add_child(btn)
	var cancel := Button.new()
	cancel.text = "그만두기"
	cancel.position = Vector2(130, 280)
	cancel.size = Vector2(100, 28)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_close_gift_picker)
	panel.add_child(cancel)
	add_child(_gift_layer)


func _close_gift_picker() -> void:
	if _gift_layer != null:
		_gift_layer.queue_free()
		_gift_layer = null


func _give_gift(npc_id: String, kind: String, item_id: String) -> void:
	# 고른 선물을 건넨다
	var gift_name := ""
	if kind == "produce" and int(GameData.produce.get(item_id, 0)) > 0:
		GameData.produce[item_id] -= 1
		gift_name = str(GameData.CROPS[item_id].name)
	elif kind == "item" and int(GameData.items.get(item_id, 0)) > 0:
		GameData.items[item_id] -= 1
		gift_name = str(GameData.ITEMS[item_id].name)
	_close_gift_picker()
	if gift_name == "":
		m.dialog.set_body("그건 이제 가지고 있지 않다...")
		return
	var before := int(GameData.affinity[npc_id])
	if Net.is_guest():
		m._req_gift.rpc_id(1, npc_id, kind, item_id)  # 호스트가 차감/가산 후 전파
	GameData.affinity[npc_id] = before + 10
	Sound.play_sfx("sfx_heart")
	if Net.is_host():
		m._broadcast_stats()
	m.dialog.set_portrait(_npc_portrait(npc_id, true))
	var body := "%s을(를) 선물했다! 정말 좋아한다. ♥" % gift_name
	if before < 50 and before + 10 >= 50:
		if npc_id == "merchant":
			body += "\n\n[특전 해금] 민지의 씨앗 10% 할인!"
		else:
			body += "\n\n[특전 해금] 철수의 낚시 비법! 판정 구간 확대!"
	m.dialog.set_body(body)


func _open_quest_board() -> void:
	var q: Dictionary = GameData.quest
	if q.is_empty():
		if GameData.quest_offers.is_empty():
			m.dialog.open("의뢰 게시판", "오늘은 새 의뢰가 없다.", [["닫기", null]])
			return
		var text := "[오늘의 의뢰] 하나만 고를 수 있습니다.\n"
		var btns: Array = []
		for i in GameData.quest_offers.size():
			var o: Dictionary = GameData.quest_offers[i]
			var have: int = GameData.ingredient_count(str(o.item))
			text += "\n%d. [%s] %s %d개  —  %dG  (보유 %d)" % [i + 1, o.label,
				GameData.item_display_name(str(o.item)), int(o.qty), int(o.reward), have]
			btns.append(["%d번" % (i + 1), _accept_quest.bind(i)])
		btns.append(["닫기", null])
		m.dialog.open("의뢰 게시판", text, btns)
		return
	var iid: String = str(q.item)
	var have2: int = GameData.ingredient_count(iid)
	var text2 := "[납품 의뢰]\n%s %d개를 모아 오면 %dG를 드립니다." % [
		GameData.item_display_name(iid), int(q.qty), int(q.reward)]
	if have2 >= int(q.qty):
		m.dialog.open("의뢰 게시판", text2 + "\n(보유 %d개 — 납품 가능!)" % have2, [
			["납품하기", _turn_in_quest],
			["닫기", null],
		])
	else:
		m.dialog.open("의뢰 게시판", text2 + "\n(진행중: %d/%d개)" % [have2, int(q.qty)],
			[["닫기", null]])


func _accept_quest(i: int) -> void:
	GameData.accept_offer(i)
	if Net.is_guest():
		m._req_quest.rpc_id(1, "accept")
	elif Net.is_host():
		m._broadcast_stats()
	m.save_now()
	m.dialog.set_body("의뢰를 수락했다!\n%s %d개를 모아서 다시 오자." % [
		GameData.item_display_name(str(GameData.quest.item)), int(GameData.quest.qty)])


func _turn_in_quest() -> void:
	var q: Dictionary = GameData.quest
	var iid: String = str(q.item)
	if GameData.ingredient_count(iid) < int(q.qty):
		return
	GameData.consume_ingredient(iid, int(q.qty))
	GameData.money += int(q.reward)
	GameData.today_earned += int(q.reward)
	GameData.affinity["merchant"] = int(GameData.affinity["merchant"]) + 5
	Sound.play_sfx("sfx_coin")
	m.hud.reward_toast("%dG" % int(q.reward), m.tex["icon_coin"])
	m.dialog.set_body("납품 완료! %dG를 받았다. 내일 새 의뢰가 올라온다." % int(q.reward))
	GameData.quest = {}
	m.save_now()
	if Net.is_guest():
		m._req_quest.rpc_id(1, "turnin")
	elif Net.is_host():
		m._broadcast_stats()
