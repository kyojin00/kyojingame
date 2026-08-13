# 마을에서 여는 창들 — 상점·여관·연구소·도서관·축제·의뢰·선물,
# 그리고 온실·광산·집 짓기·마을 건물 짓기.
#
# 공통점: **대화창 하나로 시작해서, 버튼을 누르면 무슨 일이 벌어진다.**
# 세계 상태를 매 프레임 굴리는 쪽(main)과 성격이 달라서 따로 뺐다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinVillage
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
	m.objnode._remove_object(m.HOME_SITE)
	m.worldgen._fill_building(m.HOME_ANCHOR)
	Sound.play_sfx("sfx_place")
	m.dialog.set_body("우리집 완성!\n아직 안은 텅 비어 있다.\n침대(목재 %d)를 만들어야 잠을 잘 수 있다." %
		GameData.BED_WOOD)
	m.dialog.set_buttons([["좋아!", null]])
	m.hud.quest_toast("집 짓기")
	m.saveio.save_now()


# ---- 상점 터 (메인 스토리 2 첫 퀘스트: 재료를 모아 마을의 첫 상점을 짓는다) ----
func _open_shop_site_dialog() -> void:
	if GameData.village_built.has("general"):
		return
	if GameData.story2_phase == "":
		# 아직 이장의 부탁을 받기 전이다 (스토리 1 진행 중)
		m.dialog.open("상점 터", "낡은 게시판이 서 있다.\n「상점이 들어설 자리」라고 적혀 있다.",
			[["닫기", null]])
		return
	m.dialog.open("상점 터",
		"이장이 말한 상점 자리다.\n재료를 모아 마을의 첫 상점을 세우자.\n\n필요 재료: 목재 %d (보유 %d) · 돌 %d (보유 %d)" %
			[GameData.SHOP_BUILD_WOOD, GameData.wood,
			GameData.SHOP_BUILD_STONE, GameData.stone], [
		["상점 짓기", _build_shop],
		["닫기", null],
	])


func _build_shop() -> void:
	if GameData.village_built.has("general"):
		return
	if GameData.wood < GameData.SHOP_BUILD_WOOD \
			or GameData.stone < GameData.SHOP_BUILD_STONE:
		m.dialog.set_body("재료가 부족하다...\n(보유: 목재 %d/%d · 돌 %d/%d)\n나무를 베고 바위를 캐서 모으자." %
			[GameData.wood, GameData.SHOP_BUILD_WOOD,
			GameData.stone, GameData.SHOP_BUILD_STONE])
		return
	GameData.wood -= GameData.SHOP_BUILD_WOOD
	GameData.stone -= GameData.SHOP_BUILD_STONE
	GameData.village_built.append("general")
	m.objnode._remove_object(m.door_tile(m.VILLAGE_PLOTS["general"].anchor))
	m.worldgen._fill_building(m.VILLAGE_PLOTS["general"].anchor, "general")
	m.npcmgr._sync_village_npcs()   # 상점 주인 민지가 마을에 온다
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("상점 완성!")
	m.dialog.set_body("마을의 첫 상점이 세워졌다!\n민지가 씨앗과 생필품을 팔기 시작했다.")
	m.dialog.set_buttons([["좋아!", null]])
	if GameData.story2_phase == "shop":
		GameData.story2_phase = "fisher"
		m.hud.show_message("상점이 생겼다! ...그런데 낯선 낚시꾼이 마을에 온다는 소문이 돈다.", 6.0)
	m.queue_redraw()
	m.saveio.save_now()


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
	if pid == "general":
		m.objnode._remove_object(m.door_tile(plot.anchor))  # 상점 터 게시판 철거
		if GameData.story2_phase == "shop":
			GameData.story2_phase = "fisher"   # 이장 경로로 지어도 이야기는 이어진다
	m.worldgen._fill_building(plot.anchor, pid)
	m.npcmgr._sync_village_npcs()
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("%s 완공!" % plot.name)
	m.dialog.set_body("%s(이)가 세워졌네!\n마을이 조금씩 살아나는구먼." % plot.name)
	m.dialog.set_buttons([["좋군요!", null]])
	m.queue_redraw()
	m.saveio.save_now()


func _talk_to(npc: Node2D) -> void:
	# 스토리 대화가 먼저다 — 낚시꾼 첫 만남 / 호미 받기 / 숲속의 집
	# (편지는 우체부가 직접 전한다 — 이장에게 대신 전달하는 과정은 없다)
	if npc.id == "chief" and GameData.story2_phase == "farm_talk":
		m.story._start_farm_dialog()
		return
	if npc.id == "fisher" and GameData.fisher_quest == "meet":
		m.story._start_fisher_dialog()
		return
	if npc.id == "chief" and GameData.move_quest == "show":
		m.story._start_move_chief_dialog()
		return
	if npc.id == "explorer" and GameData.move_quest == "greet":
		m.story._start_move_greet_dialog()
		return
	if npc.id == "explorer" and GameData.forest_quest == "arrive":
		m.story._start_explorer_arrive_dialog()
		return
	if npc.id == "explorer" and GameData.forest_quest == "found":
		m.story._start_explorer_found_dialog()
		return
	if npc.id == "chief" and GameData.forest_quest == "ask":
		m.story._start_forest_ask_dialog()
		return
	if npc.id in ["forest_mom", "forest_girl"] and GameData.forest_quest == "visit":
		m.story._start_forest_house_dialog()
		return
	var def: Dictionary = GameData.NPCS[npc.id]
	# 봄 꽃놀이: 말을 건 사람을 하나씩 세어 둔다 (호감도 해금과 무관)
	if GameData.festival_open() and str(GameData.festival_today().id) == "flower" \
			and not GameData.fest_greeted.has(npc.id):
		GameData.fest_greeted.append(npc.id)
		m.renderer.spawn_particles(m.player_tile(), "sparkle")
		if GameData.fest_greeted.size() >= m.npcs.size():
			_finish_festival()
			return
	# 호감도 콘텐츠는 「숲속에서 발견한 집」(스토리 5)을 끝내야 열린다 —
	# 그전에는 하트·호감도·선물 없이 담백한 인사만 나눈다
	if not GameData.affinity_open:
		var plain_choices: Array = [["대화 끝", null]]
		if npc.id == "chief" and GameData.story_phase == "done":
			plain_choices.insert(0, ["마을 발전 이야기", _open_village_build_dialog])
		if npc.id == "chief" and GameData.festival_open():
			plain_choices.insert(0, ["축제 이야기", _open_festival_dialog])
		m.dialog.open_seq(str(def.name), _npc_portrait(npc.id), [
			{"text": GameData.npc_line(npc.id), "choices": plain_choices},
		])
		return
	if not npc.talked_today:
		npc.talked_today = true
		GameData.affinity[npc.id] = int(GameData.affinity[npc.id]) + 2
	# 계절·날씨·시간대·호감도·연애 단계에 맞는 대사를 고른다 (game_data.npc_line)
	var line: String = GameData.npc_line(npc.id)
	var aff := mini(int(GameData.affinity[npc.id]), 100)
	# 호감도가 오르면 비밀 이야기(할아버지의 과거)가 섞여 나온다
	if aff >= 100 and def.has("secret100") and randf() < 0.4:
		line = def.secret100
	elif aff >= 50 and def.has("secret50") and randf() < 0.4:
		line = def.secret50
	var hearts := int(aff / 10.0)
	var mark := ""
	if GameData.spouse == npc.id:
		mark = " [배우자]"
	elif GameData.dating == npc.id:
		mark = " [연인]"
	if GameData.is_birthday(npc.id):
		mark += " [오늘 생일!]"
	var title := "%s%s %s (%d/100)" % [def.name, mark, "♥".repeat(maxi(hearts, 0)), aff]
	if aff >= 50:
		line += "\n(친밀한 사이다! 특전 발동 중)"
	# 호감도 100: 할아버지의 기억 조각을 건네받는다 (1회)
	if aff >= 100 and not GameData.memory_given:
		GameData.memory_given = true
		line = def.get("secret100", line)
		m.toolwork.gain_legend("memory_piece")
		if Net.is_host():
			m.netsync._broadcast_stats()
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
	# 연화의 서브 퀘스트 — 「대화 끝」 바로 위에 실제 퀘스트 이름으로 뜬다
	var mom_q: Dictionary = {}
	if npc.id == "forest_mom":
		mom_q = _mom_quest_option()
		if not mom_q.is_empty():
			choices.insert(choices.size() - 1, [str(mom_q.label), mom_q.cb])
	m.dialog.open_seq(title, _npc_portrait(npc.id), [
		{"text": line, "choices": choices},
	])
	if not mom_q.is_empty():
		_attach_quest_bang(str(mom_q.label))


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
				m.objnode._remove_object(t)
			m.grid[y][x].ground = "soil"
	Sound.play_sfx("sfx_place")
	m.hud.quest_toast("온실 완공!")
	m.saveio.save_now()
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
	m.saveio.save_now()
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
	m.saveio.save_now()
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
		m.netsync._broadcast_stats()
	m.saveio.save_now()
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
		m.netsync._req_gift.rpc_id(1, npc_id, kind, item_id)  # 호스트가 차감/가산 후 전파

	# 꽃다발과 반지는 호감도가 아니라 사이를 바꾼다
	if item_id == "bouquet" or item_id == "wedding_ring":
		_romance_gift(npc_id, item_id, before)
		return

	var gain := GameData.gift_value(npc_id, item_id)
	GameData.affinity[npc_id] = clampi(before + gain, 0, 100)
	GameData.gifted_today.append(npc_id)
	Sound.play_sfx("sfx_heart")
	if Net.is_host():
		m.netsync._broadcast_stats()
	m.dialog.set_portrait(_npc_portrait(npc_id, gain > 8))
	var body := ""
	if gain < 0:
		body = "%s을(를) 선물했다... 별로 안 좋아하는 눈치다." % gift_name
	elif gain >= 30:
		body = "%s을(를) 선물했다! 정말 좋아한다!! ♥♥♥" % gift_name
	elif gain >= 18:
		body = "%s을(를) 선물했다! 좋아한다. ♥♥" % gift_name
	else:
		body = "%s을(를) 선물했다. 고맙다고 한다. ♥" % gift_name
	if GameData.is_birthday(npc_id):
		body = "오늘은 %s의 생일이다!\n" % str(GameData.NPCS[npc_id].name) + body + "  (생일 3배!)"
	var after := int(GameData.affinity[npc_id])
	if before < 50 and after >= 50:
		if npc_id == "merchant":
			body += "\n\n[특전 해금] 민지의 씨앗 10% 할인!"
		elif npc_id == "fisher":
			body += "\n\n[특전 해금] 철수의 낚시 비법! 판정 구간 확대!"
		else:
			body += "\n\n[친밀] 이제 속 이야기를 들려준다."
	if bool(GameData.NPCS[npc_id].get("romance", false)):
		if before < 60 and after >= 60:
			body += "\n\n(꽃다발을 건네면 마음을 물어볼 수 있을 것 같다.)"
		elif GameData.dating == npc_id and after >= 100 and GameData.spouse == "":
			body += "\n\n(청혼 반지를 건넬 수 있을 것 같다.)"
	m.dialog.set_body(body)


# 꽃다발 -> 연인, 청혼 반지 -> 배우자. 각각 한 사람뿐이고 되돌릴 수 없다.
func _romance_gift(npc_id: String, item_id: String, aff: int) -> void:
	var def: Dictionary = GameData.NPCS[npc_id]
	var name := str(def.name)
	m.dialog.set_portrait(_npc_portrait(npc_id, true))
	if not bool(def.get("romance", false)):
		GameData.items[item_id] += 1        # 돌려받는다
		m.dialog.set_body("%s은(는) 웃으며 돌려주었다.\n\"마음은 고맙네. 나한테 쓸 건 아니지.\"" % name)
		return
	if item_id == "bouquet":
		if GameData.spouse != "":
			GameData.items[item_id] += 1
			m.dialog.set_body("이미 함께하는 사람이 있다.")
			return
		if aff < 60:
			GameData.items[item_id] += 1
			m.dialog.set_body("%s은(는) 꽃다발을 보고 당황했다.\n\"...아직은, 조금 이른 것 같아.\"\n(호감도 60 이상이어야 한다. 지금 %d)" % [name, aff])
			return
		if GameData.dating != "" and GameData.dating != npc_id:
			GameData.items[item_id] += 1
			m.dialog.set_body("%s은(는) 고개를 저었다.\n\"...너, 다른 사람이 있잖아.\"" % name)
			return
		GameData.dating = npc_id
		GameData.affinity[npc_id] = mini(aff + 10, 100)
		Sound.play_sfx("sfx_heart")
		m.dialog.set_body("%s에게 꽃다발을 건넸다.\n\n\"...받을게. 오래 기다렸어.\"\n\n[연인이 되었다]" % name)
	else:
		if GameData.spouse != "":
			GameData.items[item_id] += 1
			m.dialog.set_body("이미 함께하는 사람이 있다.")
			return
		if GameData.dating != npc_id:
			GameData.items[item_id] += 1
			m.dialog.set_body("%s은(는) 반지를 보고 얼어붙었다.\n\"...우리, 아직 그런 사이는 아니잖아.\"\n(먼저 꽃다발로 연인이 되어야 한다.)" % name)
			return
		if aff < 100:
			GameData.items[item_id] += 1
			m.dialog.set_body("%s은(는) 반지를 보고 망설였다.\n\"조금만... 조금만 더 알고 싶어.\"\n(호감도 100이어야 한다. 지금 %d)" % [name, aff])
			return
		GameData.spouse = npc_id
		Sound.play_sfx("sfx_heart")
		m.dialog.set_body("%s에게 반지를 건넸다.\n\n\"...응. 같이 살자.\"\n\n[결혼했다! 이제 아침마다 같이 눈을 뜬다]" % name)
	if Net.is_host():
		m.netsync._broadcast_stats()


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
		m.netsync._req_quest.rpc_id(1, "accept")
	elif Net.is_host():
		m.netsync._broadcast_stats()
	m.saveio.save_now()
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
	m.saveio.save_now()
	if Net.is_guest():
		m.netsync._req_quest.rpc_id(1, "turnin")
	elif Net.is_host():
		m.netsync._broadcast_stats()


# ---- 잡화점 계산대: 민지와의 대화 메뉴 ----
#
# 계산대에서 E를 눌러도 판매 창이 바로 열리지 않는다.
# 먼저 인사말이 나오고, 선택지로 갈라진다:
#   판매하기 / 대화하기 / (서브 퀘스트 — 있을 때만, ❗ 통통) / 대화 그만두기
# 퀘스트 선택지는 언제나 「대화 그만두기」 바로 위에 선다.
#
# 첫 서브 퀘스트 「해변에 노점 차리기」는 바다가 열린 뒤부터 받을 수 있다.
# 재료(목재·조개)를 모아다 주면 해변에 민지의 노점이 선다.

const MERCHANT_QUEST_NAME := "해변에 노점 차리기"

# 「대화하기」에서 일상 대사 대신 반반 확률로 나오는 가게 팁
const MERCHANT_TIPS := [
	"씨앗은 가운데 선반에서 골라 가면 돼.\n팻말 보고 찾으면 빨라!",
	"나랑 친해지면(하트 50) 물건값을\n깎아 준다는 소문이 있어. 소문이야, 소문.",
	"작물은 나한테 팔면 바로 현금!\n그래도 요리로 만들면 더 비싸게 쳐줘.",
	"게시판 의뢰도 잊지 말고 확인해.\n쏠쏠한 부수입이 되거든.",
]


func open_merchant_counter() -> void:
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	var btns: Array = [
		["판매하기", _merchant_sell],
		["대화하기", _merchant_chat],
	]
	var q := _merchant_quest_option()
	if not q.is_empty():
		btns.append([str(q.label), q.cb])   # 「대화 그만두기」 바로 위
	btns.append(["대화 그만두기", null])
	m.dialog.open("잡화점 민지", "어어, %s! 무슨 일이야?" % nm,
		btns, _npc_portrait("merchant"))
	if not q.is_empty():
		_attach_quest_bang(str(q.label))


func _merchant_sell() -> void:
	m.dialog.close()
	m.shop.open("sell", ["sell"], "잡화점 — 판매")


func _merchant_chat() -> void:
	var line := str(MERCHANT_TIPS[randi() % MERCHANT_TIPS.size()]) \
		if randf() < 0.5 else GameData.npc_line("merchant")
	# 대사가 끝나면 다시 선택지 메뉴로 돌아온다
	m.dialog.open_seq("잡화점 민지", _npc_portrait("merchant"), [
		{"text": line},
	], open_merchant_counter)


# 지금 보여 줄 퀘스트 선택지. 없으면 빈 사전.
# 라벨은 고정 문구("퀘스트 받기")가 아니라 실제 퀘스트 이름을 쓴다.
# 노점 퀘스트는 바다가 열린 뒤부터 — 그전에는 선택지 자체가 없다.
func _merchant_quest_option() -> Dictionary:
	if not GameData.sea_open:
		return {}
	match GameData.merchant_errand:
		"":
			return {"label": MERCHANT_QUEST_NAME, "cb": _merchant_errand_start}
		"doing":
			return {"label": MERCHANT_QUEST_NAME, "cb": _merchant_errand_turnin}
	return {}


func _merchant_errand_start() -> void:
	GameData.merchant_errand = "doing"
	m.saveio.save_now()
	m.dialog.open_seq("잡화점 민지", _npc_portrait("merchant"), [
		{"text": "바다가 열렸다며? 실은 나, 해변에\n작은 노점을 내는 게 꿈이었어."},
		{"text": "낚시용품이랑 바다 요리 레시피를 팔고,\n해변에서 주운 것들도 사 주는 가게!"},
		{"text": "목재 %d개랑 조개 %d개만 구해다 줄래?\n진열대랑 장식으로 쓰게." \
			% [GameData.STALL_WOOD, GameData.STALL_SHELLS]},
	], func() -> void:
		m.hud.quest_toast("서브 퀘스트: %s" % MERCHANT_QUEST_NAME)
		open_merchant_counter())


func _merchant_errand_turnin() -> void:
	var have_w: int = GameData.wood
	var have_s := int(GameData.items.get("forage_shell", 0))
	if have_w < GameData.STALL_WOOD or have_s < GameData.STALL_SHELLS:
		m.dialog.open_seq("잡화점 민지", _npc_portrait("merchant"), [
			{"text": "재료는 좀 모였어?\n(목재 %d/%d · 조개 %d/%d)" \
				% [have_w, GameData.STALL_WOOD, have_s, GameData.STALL_SHELLS]},
		], open_merchant_counter)
		return
	GameData.wood -= GameData.STALL_WOOD
	GameData.items["forage_shell"] = have_s - GameData.STALL_SHELLS
	GameData.affinity["merchant"] = int(GameData.affinity["merchant"]) + 8
	GameData.merchant_errand = "done"
	GameData.roll_stall_hours()
	m.worldgen._place_stall()
	Sound.play_sfx("sfx_place")
	m.queue_redraw()
	m.saveio.save_now()   # 재료를 받은 순간 저장 — 대화 중에 꺼져도 노점은 서 있다
	if Net.is_host():
		m.netsync._broadcast_stats()
	# 마무리 흐름: 노점 완성 → 하트 러그 지급 → 집 꾸미기 권유 →
	# 상점 인테리어 레시피 안내 → (대화가 다 끝난 뒤) 퀘스트 완료 표시
	m.dialog.open_seq("잡화점 민지", _npc_portrait("merchant", true), [
		{"text": "고마워! 바로 해변에 노점을 차렸어.\n능선 아래 모래밭에 있으니 놀러 와."},
		{"text": "나는 하루에 세 번, 한 시간씩 나가 있을 거야.\n내가 있을 때만 물건을 살 수 있어.\n(물건을 파는 건 언제든 — 무인 판매!)"},
		{"text": "그리고 이건 도와준 보답!\n\n[하트 모양 러그를 받았다]", "event": _give_heart_rug},
		{"text": "집 안에서 꾸미기(F)를 눌러서 깔아 봐.\n집 꾸미는 재미, 은근히 쏠쏠하다?"},
		{"text": "우리 가게에서도 가끔 집을 꾸밀 수 있는\n예쁜 아이템을 만드는 레시피를 팔고 있으니까,\n자주 와서 구경해~"},
	], _end_stall_quest)


# 보상: 하트 모양 러그 — 집 세간으로 바로 들어온다 (꾸미기 F로 옮긴다)
func _give_heart_rug() -> void:
	GameData.furniture.append({"id": "heart_rug", "x": 366.0, "y": 285.0})
	Sound.play_sfx("sfx_heart")
	m.hud.reward_toast("하트 모양 러그", m.tex.get("icon_heart"))


func _end_stall_quest() -> void:
	m.hud.quest_toast("서브 퀘스트 완료: %s" % MERCHANT_QUEST_NAME)
	m.saveio.save_now()
	open_merchant_counter()


# ---- 해변 노점 ----
#
# 구매(미끼·노점 한정 레시피)는 민지가 나와 있는 시간에만,
# 판매는 민지가 없어도 언제든 할 수 있다.
func open_stall() -> void:
	if GameData.merchant_at_stall():
		m.shop.open("buy", ["buy", "sell"], "해변 노점", "stall")
	else:
		m.hud.show_message("민지가 자리에 없다 — 판매만 할 수 있다.\n"
			+ "(민지는 하루 세 번, 한 시간씩 노점에 나온다)", 4.0)
		m.shop.open("sell", ["sell"], "해변 노점 (무인 판매)")


# 퀘스트 선택지 버튼에 노란 느낌표를 단다.
# 도트 게임답게 위아래로 통통 튀는 애니메이션을 건다.
func _attach_quest_bang(label: String) -> void:
	for c in m.dialog.buttons_box.get_children():
		if not (c is Button) or (c as Button).text != label:
			continue
		var btn := c as Button
		btn.text = "     " + label                     # 느낌표 앉을 자리
		var bang := Label.new()
		bang.text = "!"
		bang.add_theme_font_size_override("font_size", 18)
		bang.add_theme_color_override("font_color", Color("ffd75e"))
		bang.add_theme_color_override("font_outline_color", Color(0.36, 0.2, 0.02))
		bang.add_theme_constant_override("outline_size", 4)
		bang.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bang.position = Vector2(9, 5)
		btn.add_child(bang)
		var tw := bang.create_tween().set_loops()
		tw.tween_property(bang, "position:y", 1.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bang, "position:y", 5.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.3)
		return


# ---- 쓰레기통: 24시간 무인 판매함 ----
#
# 제작대에서 만든 쓰레기통(아이템)을 가방에서 꺼내 원하는 곳에 설치한다.
# 집 안이면 세간으로, 바깥이면 바라보는 칸에 놓인다.
# E로 열어 아무 때나 팔 수 있는 대신 제값의 80%만 받는다 —
# 밤에 몬스터를 뚫고 노점까지 가기 어려울 때를 위한 판매 수단이다.

func use_trash_bin() -> void:
	if int(GameData.items.get("trash_bin", 0)) <= 0:
		return
	# 집 안: 세간으로 들여놓는다 (꾸미기 F로 옮긴다)
	if m.interior.visible:
		if GameData.house_lv < 2:
			# 오두막에는 세간을 놓을 자리가 없다 (가구는 확장한 집부터)
			m.hud.show_message("오두막은 너무 좁다 — 집을 확장하면 안에도 놓을 수 있다.\n지금은 바깥에 설치하자.", 5.0)
			return
		GameData.items["trash_bin"] = int(GameData.items["trash_bin"]) - 1
		GameData.furniture.append({"id": "trash_bin",
			"x": 430.0 + float(GameData.furniture.size() % 4) * 40.0,
			"y": 255.0 + float(GameData.furniture.size() / 4 % 3) * 30.0})
		Sound.play_sfx("sfx_place")
		m.hud.quest_toast("쓰레기통을 들여놓았다")
		m.hud.show_message("가까이에서 E: 무인 판매 (제값의 80%) · 꾸미기(F)로 옮길 수 있다", 5.0)
		m.interior.canvas.queue_redraw()
		m.saveio.save_now()
		return
	# 바깥: 바라보는 칸에 설치한다
	var t: Vector2i = m.actions.target_tile()
	if t.x < 1 or t.y < 1 or t.x >= m.MAP_W - 1 or t.y >= m.MAP_H - 1 \
			or m.objects.has(t) or m.grid[t.y][t.x].ground in ["water", "dock"] \
			or m.grid[t.y][t.x].crop_id != "" or m.actions._tile_overlaps_player(t):
		m.hud.show_message("여기에는 놓을 수 없다 — 비어 있는 땅을 바라보고 쓰자.")
		return
	GameData.items["trash_bin"] = int(GameData.items["trash_bin"]) - 1
	m.objnode._place_object(t, "trash_bin", 0)
	Sound.play_sfx("sfx_place")
	m.hud.show_message("쓰레기통 설치! E로 열면 24시간 팔 수 있다 (제값의 80%).", 5.0)
	m.queue_redraw()
	m.saveio.save_now()


# 바깥에 설치한 쓰레기통에서 E
func open_trash_bin(t: Vector2i) -> void:
	m.dialog.open("쓰레기통", "24시간 무인 판매함이다.\n여기 넣은 물건은 제값의 %d%%로 팔린다."
		% int(GameData.TRASH_SELL_MULT * 100.0), [
		["판매하기", _trash_sell],
		["회수하기", _trash_pickup.bind(t)],
		["닫기", null],
	])


func _trash_sell() -> void:
	m.dialog.close()
	m.shop.open("sell", ["sell"], "쓰레기통 — 무인 판매", "", GameData.TRASH_SELL_MULT)


func _trash_pickup(t: Vector2i) -> void:
	m.dialog.close()
	if str(m.objects.get(t, {}).get("kind", "")) != "trash_bin":
		return
	m.objnode._remove_object(t)
	GameData.items["trash_bin"] = int(GameData.items.get("trash_bin", 0)) + 1
	Sound.play_sfx("sfx_place")
	m.hud.show_message("쓰레기통을 도로 챙겼다.")
	m.queue_redraw()
	m.saveio.save_now()


# ---- 숲속 엄마(연화)의 서브 퀘스트 ----
#
# 스토리 5를 끝내야 열린다. 솔이에게 줄 요리·음식·재료를 부탁하는 심부름 —
# 세부 내용은 GameData.MOM_QUESTS 표가 정한다 (표가 비어 있으면 선택지 없음).
# 표에 줄만 추가하면 받기 -> 모으기 -> 전달 -> 보상까지 여기 코드가 다 굴린다.

func _mom_quest_option() -> Dictionary:
	var q: Dictionary = GameData.mom_next_quest()
	if q.is_empty():
		return {}
	if GameData.mom_quest == "":
		return {"label": str(q.name), "cb": _mom_quest_start.bind(str(q.id))}
	return {"label": str(q.name), "cb": _mom_quest_turnin.bind(str(q.id))}


func _mom_quest_start(qid: String) -> void:
	var q: Dictionary = GameData.mom_next_quest()
	if q.is_empty() or str(q.id) != qid or GameData.mom_quest != "":
		return
	GameData.mom_quest = qid
	var entries: Array = [{"text": "저... 부탁 하나 드려도 될까요?"}]
	if str(q.get("ask", "")) != "":
		entries.append({"text": str(q.ask)})
	entries.append({"text": "우리 솔이에게 줄 %s %d개가 필요해요.\n구해다 주시면 꼭 사례할게요." \
		% [GameData.item_display_name(str(q.item)), int(q.qty)]})
	m.dialog.open_seq("연화", _npc_portrait("forest_mom"), entries, func() -> void:
		m.hud.quest_toast("연화의 부탁: %s" % str(q.name))
		m.saveio.save_now())


func _mom_quest_turnin(qid: String) -> void:
	var q: Dictionary = GameData.mom_next_quest()
	if q.is_empty() or str(q.id) != qid:
		return
	var need := int(q.qty)
	var have: int = GameData.ingredient_count(str(q.item))
	if have < need:
		m.dialog.open_seq("연화", _npc_portrait("forest_mom"), [
			{"text": "%s은(는) 좀 모였나요?\n(진행중: %d/%d)" \
				% [GameData.item_display_name(str(q.item)), have, need]},
		])
		return
	GameData.consume_ingredient(str(q.item), need)
	if int(q.get("money", 0)) > 0:
		GameData.money += int(q.money)
		GameData.today_earned += int(q.money)
		m.hud.reward_toast("%dG" % int(q.money), m.tex["icon_coin"])
	if int(q.get("affinity", 0)) > 0:
		GameData.affinity["forest_mom"] = int(GameData.affinity["forest_mom"]) \
			+ int(q.affinity)
	GameData.mom_quests_done.append(qid)
	GameData.mom_quest = ""
	Sound.play_sfx("sfx_heart")
	m.hud.quest_toast("연화의 부탁 완료: %s" % str(q.name))
	if Net.is_host():
		m.netsync._broadcast_stats()
	m.saveio.save_now()
	var thanks: Array = [{"text": "정말 고마워요!\n솔이가 얼마나 기뻐할지 몰라요."}]
	if str(q.get("thanks", "")) != "":
		thanks.append({"text": str(q.thanks),
			"portrait": _npc_portrait("forest_mom", true)})
	m.dialog.open_seq("연화", _npc_portrait("forest_mom", true), thanks)
