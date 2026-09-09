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
	m.hud.event_toast("집 짓기")
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
	# 만수는 오늘 밤 이삿짐을 옮기고, **내일** 직접 인사하러 온다.
	# 인사를 나눠야 상점 문이 열린다 (이주 NPC 공통 규칙)
	if not GameData.npc_greeted.has("merchant"):
		GameData.arrivals.append({"id": "merchant", "day": GameData.day})
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("상점 완성!")
	m.dialog.set_body("마을의 첫 상점이 세워졌다!\n주인 만수는 내일 이사 와서 인사하러 온다고 한다.")
	m.dialog.set_buttons([["좋아!", null]])
	if GameData.story2_phase == "shop":
		GameData.story2_phase = "fisher"
		m.hud.show_message("상점이 생겼다!\n...그런데 낚싯대를 멘 사람이 마을로 오고 있다는 소문이 돈다.", 6.0)
	m.queue_redraw()
	m.saveio.save_now()


func _next_village_build() -> String:
	for pid in m.VILLAGE_BUILD_ORDER:
		if GameData.village_built.has(pid):
			continue
		# 마을회관은 메인 스토리 9 — 이장의 부탁(주민 초대)을 받고
		# 주민 10명을 모아야 지을 수 있다 (마을 성장의 정점)
		if pid == "hall" and GameData.story9_phase != "build":
			continue
		# 우체국은 메인 스토리 3의 마지막 퀘스트 — 이장의 이야기를 들어야 한다
		if pid == "post" and GameData.move_quest != "postbuild":
			continue
		# 도서관은 메인 스토리 6에서 사서와 이야기를 마쳐야 지을 수 있다
		if pid == "library" and GameData.story6_phase != "build":
			continue
		# 목장 상회는 메인 스토리 8에서 목동·이장과 이야기를 마쳐야 지을 수 있다
		if pid == "ranch" and GameData.story8_phase != "build":
			continue
		# 파출소는 회관이 열린 뒤 — 정부가 있어야 법도 있다(사회 S2b)
		if pid == "inn" and GameData.story9_phase != "done":
			continue
		return pid
	return ""


# 마을 확장(메인 스토리 4 이후) — 버려진 옛 마을 구역을 순서대로 되살린다.
# 해금 전 구역은 들어갈 수도, 집터·설치물을 놓을 수도 없다.
func _open_zone_dialog() -> void:
	var next_zid := ""
	for zid: String in GameData.ZONE_ORDER:
		if zid not in GameData.zones_open:
			next_zid = zid
			break
	if next_zid == "":
		m.dialog.open("마을 확장",
			"「버려졌던 구역은 이제 다 되살렸네.\n옛 교진 마을이 전부 돌아온 걸세 — 고맙네!」",
			[["뿌듯하네요", null]])
		return
	var zname := str(GameData.VILLAGE_ZONES[next_zid].name)
	var cost: Array = GameData.ZONE_COST[next_zid]
	m.dialog.open("마을 확장 — %s" % zname,
		"「다음은 %s 차례일세.\n수풀을 걷고 길을 트려면 재료가 필요하네.」\n\n필요: 목재 %d · 석재 %d (보유 %d·%d)" %
			[zname, int(cost[0]), int(cost[1]), GameData.wood, GameData.stone],
		[["되살리기", _unlock_zone.bind(next_zid)], ["다음에", null]])


func _unlock_zone(zid: String) -> void:
	m.dialog.close()
	var cost: Array = GameData.ZONE_COST[zid]
	if GameData.wood < int(cost[0]) or GameData.stone < int(cost[1]):
		m.hud.show_message("재료가 모자라다 — 목재 %d · 석재 %d가 필요하다." %
			[int(cost[0]), int(cost[1])])
		return
	GameData.wood -= int(cost[0])
	GameData.stone -= int(cost[1])
	GameData.zones_open.append(zid)
	m.dirty_walk()   # 부지가 열렸다 — 걸을 수 있는 땅이 바뀐다
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("마을 확장!")
	m.hud.show_message("%s를 되살렸다! 마을이 넓어졌다. (지도 M)" %
		str(GameData.VILLAGE_ZONES[zid].name), 6.0)
	m.queue_redraw()
	m.saveio.save_now()


func _open_village_build_dialog() -> void:
	var pid := _next_village_build()
	if pid == "":
		if not GameData.village_built.has("hall"):
			m.dialog.open("마을 발전",
				"지금 지을 수 있는 건물은 다 세웠네.\n\n남은 건 마을회관뿐인데... 회관은 마을 사람이\n"
				+ "%d명은 넘어야 의미가 있지. (지금 %d명)\n주민이 더 늘면 다시 이야기함세." %
					[GameData.HALL_RESIDENTS, m.village_residents()],
				[["알겠습니다", null]])
			return
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
	# 주인이 있는 건물은 바로 영업하지 않는다 — 다음 날 주인이 직접
	# 찾아와 첫 인사를 나눈 뒤부터 문을 연다 (이주 NPC 공통 규칙)
	var owner := str(m.VILLAGE_NPC.get(pid, ""))
	var greet_note := ""
	if pid == "library":
		# 사서는 이미 마을에 와 있다 (스토리 6 방문객) — 이사 대기열 없이
		# 도서관 앞의 서하에게 직접 말을 걸면 정착 이야기가 이어진다
		greet_note = "\n사서 선생이 벌써 도서관 앞을 서성이는구먼 — 말을 걸어 보게."
	elif pid == "ranch":
		# 목동도 이미 마을에 와 있다 (스토리 8 방문객) — 보라에게 말을 걸면
		# 정착 이야기가 이어진다
		greet_note = "\n목동 아가씨가 벌써 상회 앞에서 들떠 있구먼 — 말을 걸어 보게."
	elif pid == "post":
		# 우체부 아저씨가 돌아온다 — 스토리 3의 마지막 장면.
		# 다른 건물과 달리 「오늘 안에」 온다 (기다리던 재회니까)
		if GameData.move_quest == "postbuild":
			GameData.move_quest = "postgreet"
		if not GameData.npc_greeted.has("postman"):
			GameData.arrivals.append({"id": "postman", "day": GameData.day - 1})
		greet_note = "\n우체부 그 친구를 불렀네. 곧 인사하러 올 걸세."
	elif pid == "hall":
		# 마을회관 — 개관식은 접수대에서 이장과 (메인 스토리 9의 끝맺음)
		greet_note = "\n내일부터 낮에는 내가 회관을 지키겠네.\n접수대로 와 주게 — 개관식을 해야지!"
	elif owner != "" and owner != "fisher" and not GameData.npc_greeted.has(owner):
		GameData.arrivals.append({"id": owner, "day": GameData.day})
		greet_note = "\n내일쯤 주인이 자네한테 인사하러 올 걸세."
	m.npcmgr._sync_village_npcs()
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("%s 완공!" % plot.name)
	m.dialog.set_body("%s(이)가 세워졌네!\n마을이 조금씩 살아나는구먼.%s" % [plot.name, greet_note])
	m.dialog.set_buttons([["좋군요!", null]])
	m.queue_redraw()
	m.saveio.save_now()


# ---- 주민 삼자 대화 — 수다 떠는 둘 사이에 끼어든다 ----
var _trio_day := -1
var _trio_pairs: Array = []


# 곁(3칸)에서 함께 서 있는 다른 주민 — 삼자 대화의 상대.
# 상대도 플레이어 곁에 있어야 한다 (수다 떠는 무리에 「걸어 들어간」 상황)
func _chat_buddy(npc: Node2D) -> Variant:
	for n in m.npcs:
		if n == npc or not n.visible:
			continue
		if n.position.distance_to(npc.position) < 96.0 \
				and n.position.distance_to(m.player.position) < 120.0:
			return n
	return null


func _start_trio_dialog(a: Node2D, b: Node2D) -> void:
	var an := str(GameData.NPCS[a.id].name)
	var bn := str(GameData.NPCS[b.id].name)
	GameData.npc_last_talk[b.id] = GameData.day
	var topic: Dictionary = GameData.TRIO_TOPICS[randi() % GameData.TRIO_TOPICS.size()]
	var q: String = str(topic.q).replace("%B", bn)
	m.dialog.open_seq(an, _npc_portrait(a.id), [
		{"text": "(%s와(과) %s이(가) 한창 수다를 떨고 있다.)" % [an, bn]},
		{"text": q, "choices": [
			[str(topic.a1), _trio_pick.bind(
				b.id if str(topic.w1) == "b" else a.id)],
			[str(topic.a2), _trio_pick.bind(
				b.id if str(topic.w2) == "b" else a.id)],
			["웃으며 듣기만 한다", null],
		]},
	])


func _trio_pick(win_id: String) -> void:
	m.dialog.close()
	GameData.affinity[win_id] = int(GameData.affinity[win_id]) + 6
	Sound.play_sfx("sfx_heart")
	m.hud.show_message("%s이(가) 신나서 맞장구쳤다! (호감도 +6)"
		% GameData.NPCS[win_id].name, 4.0)
	m.saveio.save_now()


func _talk_to(npc: Node2D) -> void:
	# 마을 도착 이벤트 순서 고정: 우체부 -> 이장 -> 자유 행동.
	# 우체부의 필수 대화(편지 전달)가 끝나기 전에는 이장과 이야기할 수
	# 없다 — story_phase가 이벤트 플래그다 ("deliver"를 지나야 완료).
	if npc.id == "chief" and GameData.story_phase in ["travel", "deliver"]:
		m.hud.show_message("우선 우체부 아저씨와 이야기해보자.")
		return
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
	# 스토리 3-② 씨앗 한 줌 / 3-③ 우체국
	if npc.id == "explorer" and GameData.move_quest == "seedrep":
		m.story._start_move_seedrep_dialog()
		return
	if npc.id == "chief" and GameData.move_quest == "post":
		m.story._start_move_post_dialog()
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
	# 돌아오는 길 — 이장의 조언 (여기서 호감도가 열린다)
	if npc.id == "chief" and GameData.forest_quest == "back":
		m.story._start_forest_back_dialog()
		return
	if npc.id == "chief" and GameData.story4_phase == "ask":
		m.story._start_story4_dialog()   # 낡은 표지판 이야기 (메인 스토리 4)
		return
	# 메인 스토리 6 — 오래된 책과 사서
	if npc.id == "chief" and GameData.story6_phase == "show_chief":
		m.story._start_book_chief_dialog()
		return
	if npc.id == "chief" and GameData.story6_phase == "told":
		m.story._start_book_chief2_dialog()
		return
	if npc.id == "librarian" and GameData.story6_phase == "visit":
		m.story._start_librarian_book_dialog()
		return
	if npc.id == "librarian" and GameData.story6_phase == "build" \
			and GameData.village_built.has("library"):
		m.story._start_library_done_dialog()
		return
	# 메인 스토리 7 — 식지 않는 화로
	if npc.id == "blacksmith" and GameData.story7_phase == "worry":
		m.story._start_forge_worry_dialog()
		return
	if npc.id == "librarian" and GameData.story7_phase == "lore":
		m.story._start_forge_lore_dialog()
		return
	if npc.id == "blacksmith" and GameData.story7_phase == "gather":
		m.story._start_forge_fire_dialog()
		return
	# 메인 스토리 8 — 초원에서 온 목동
	if npc.id == "rancher" and GameData.story8_phase == "visit":
		m.story._start_rancher_visit_dialog()
		return
	if npc.id == "chief" and GameData.story8_phase == "ask":
		m.story._start_ranch_chief_dialog()
		return
	if npc.id == "rancher" and GameData.story8_phase == "build" \
			and GameData.village_built.has("ranch"):
		m.story._start_ranch_done_dialog()
		return
	# 메인 스토리 9 — 마을의 심장, 마을회관
	if npc.id == "chief" and GameData.story9_phase == "ask":
		m.story._start_hall_ask_dialog()
		return
	# 메인 스토리 10 — 동굴과 탐험
	if npc.id == "librarian" and GameData.story10_phase == "note":
		m.story._start_cave_note_dialog()
		return
	if npc.id == "librarian" and GameData.story10_phase == "survey":
		m.story._start_cave_report_dialog()
		return
	# 메인 스토리 11 — 할머니의 모자 (이장이 걸어오기 전에 먼저 말 걸어도)
	if npc.id == "chief" and GameData.story11_phase == "visit":
		m.story._start_hat_visit_dialog()
		return
	if GameData.story11_phase == "clue" and npc.id in GameData.STORY11_CLUE_NPCS \
			and npc.id not in GameData.story11_clues:
		m.story._start_hat_clue_dialog(npc.id)
		return
	# 메인 스토리 12 — 숲의 연금술사
	if npc.id == "librarian" and GameData.story12_phase == "ask":
		m.story._start_alch_ask_dialog()
		return
	if GameData.story12_phase == "gossip" and npc.id != "alchemist" \
			and npc.id not in GameData.story12_heard:
		m.story.story12_hear(npc.id)
		return
	if npc.id == "alchemist" and GameData.story12_phase in ["path", "gather"]:
		m.story._alch_house_door()
		return
	# 메인 스토리 13 — 할머니의 팔찌
	if npc.id == "fisher" and GameData.story13_phase == "rumor":
		m.story._start_sea_rumor_dialog()
		return
	if GameData.story13_phase == "clue" \
			and npc.id not in ["fisher", "alchemist"] \
			and npc.id not in GameData.story13_heard:
		m.story.story13_hear(npc.id)
		return
	if npc.id == "alchemist" and GameData.story13_phase in ["box", "open"]:
		m.story._alch_house_door()
		return
	# 메인 스토리 14 — 마을의 첫 축제
	if npc.id == "chief" and GameData.story14_phase == "meet":
		m.story._start_fest_meet_dialog()
		return
	if npc.id == "chief" and GameData.story14_phase == "prep" \
			and GameData.fest_prep_done():
		m.story._start_fest_ready_dialog()
		return
	if npc.id == "chief" and GameData.story14_phase == "fest" \
			and GameData.day >= GameData.story14_fest_day:
		m.story.open_fest_day_dialog()
		return
	if GameData.story14_phase == "fest" and m.story.story14_fest_greet(npc.id):
		return   # 축제 당일 — 다들 들떠 있다
	if GameData.story14_phase == "prep" and m.story.story14_prep_greet(npc.id):
		return   # 준비 기간 — 저마다 맡은 몫을 이야기한다 (한 번씩)
	# 메인 스토리 15 — 마른 온천
	if npc.id == "chief" and GameData.story15_phase == "tale":
		m.story._start_onsen_tale_dialog()
		return
	if npc.id == "librarian" and GameData.story15_phase == "book":
		m.story._start_onsen_book_dialog()
		return
	if npc.id == "blacksmith" and GameData.story15_phase == "tool" \
			and int(GameData.items.get("rock_wedge", 0)) == 0:
		m.story._start_onsen_tool_dialog()
		return
	if npc.id == "alchemist" and GameData.story15_phase == "water":
		m.story._start_onsen_water_dialog()
		return
	# 메인 스토리 16 — 할머니의 반지 (옛 농지)
	if npc.id == "librarian" and GameData.story16_phase == "record":
		m.story._start_ring_record_dialog()
		return
	if GameData.story16_phase == "clue" and npc.id not in GameData.story16_heard:
		m.story.story16_hear(npc.id)
		return
	# 메인 스토리 17 — 할머니의 목걸이 (옛 헛간)
	if npc.id == "rancher" and GameData.story17_phase == "cloth":
		m.story._start_barn_cloth_dialog()
		return
	if GameData.story17_phase == "clue" and npc.id not in GameData.story17_heard:
		m.story.story17_hear(npc.id)
		return
	# 메인 스토리 18 — 할머니의 시계 (옛 전망대)
	if npc.id == "librarian" and GameData.story18_phase == "memo":
		m.story._start_watch_memo_dialog()
		return
	if GameData.story18_phase == "clue" and npc.id not in GameData.story18_heard:
		m.story.story18_hear(npc.id)
		return
	# 유품을 찾아 온 날 — 도서관에서 새 기록이 열린다 (스토리 16·17·18)
	if npc.id == "librarian" and GameData.story16_phase == "tale":
		m.story.open_grandma_records()
		return
	if npc.id == "librarian" and GameData.story17_phase == "tale":
		m.story.open_grandma_records()
		return
	if npc.id == "librarian" and GameData.story18_phase == "tale":
		m.story.open_grandma_records()
		return
	# 온천에 몸을 담그러 온 주민 — 물가에선 이야기가 길어진다 (스토리 15)
	if GameData.onsen_open and m.npcmgr.npc_place_now(npc.id) == "onsen":
		m.story.onsen_npc_line(npc.id)
		return
	if npc.id == "forest_mom" and GameData.forest_quest == "go":
		m.story._start_forest_house_dialog()
		return
	# 스토리 5 이후 — 연화가 마음을 열고 처음으로 안으로 들인다
	if npc.id == "forest_mom" and GameData.forest_trust == "invited":
		m.story._start_forest_trust_dialog()
		return
	# 조리대 이야기 — 첫 수확 뒤 만수를 만나면 밥 이야기부터
	if npc.id == "merchant" and GameData.kitchen_quest_ready():
		m.story.start_kitchen_quest()
		return
	# 조리대를 찾은 뒤 만수를 만나면 축하와 선물
	if npc.id == "merchant" and GameData.kitchen_quest == "found":
		m.story.kitchen_gift_dialog()
		return
	# 지은 요리를 들고 만수를 만나면 — 칭찬과 판매 안내로 2장이 끝난다
	if npc.id == "merchant" and GameData.kitchen_quest == "deliver":
		m.story.kitchen_deliver_dialog()
		return
	# 서브 퀘스트 — 용식의 집터 (분수대 앞: 선택지 / 집 완공 뒤: 보고)
	if npc.id == "fisher" and GameData.fisher_home == "wait":
		m.story.fisher_home_greet()
		return
	if npc.id == "fisher" and GameData.fisher_home == "built":
		m.story.fisher_home_report()
		return
	# 메인 스토리 20 — 노트의 마지막 페이지를 서하와 이장에게 보여준다
	if GameData.story20_phase == "tell" and npc.id in GameData.STORY20_TELL \
			and npc.id not in GameData.story20_told:
		m.story.story20_show_page(npc.id)
		return
	# 대화 기록 — 오래 말을 안 걸면 이사 온 주민이 서운해한다
	GameData.npc_last_talk[npc.id] = GameData.day
	# 떠나려는 주민 — 「이사를 가고 싶다」 (붙잡을 수 있다)
	if npc.id == GameData.settler_leaving:
		m.story.start_leaving_dialog(npc.id)
		return
	# 곁에서 수다 떨던 주민들 사이에 끼면 삼자 대화가 된다 (짝마다 하루 한 번)
	if GameData.affinity_open and not m.story_cutscene:
		var buddy: Variant = _chat_buddy(npc)
		if buddy != null:
			if _trio_day != GameData.day:
				_trio_day = GameData.day
				_trio_pairs = []
			var pk: String = npc.id + "|" + buddy.id
			var pk2: String = buddy.id + "|" + npc.id
			if not _trio_pairs.has(pk) and not _trio_pairs.has(pk2):
				_trio_pairs.append(pk)
				_start_trio_dialog(npc, buddy)
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
		if npc.id == "chief" and GameData.story4_phase == "done":
			plain_choices.insert(0, ["마을 확장 이야기", _open_zone_dialog])
		if npc.id == "chief" and GameData.plot3_quest in ["make", "report"]:
			plain_choices.insert(0, ["집터 이야기", m.story.open_plot3_dialog])
		if npc.id == "chief" and GameData.festival_open():
			plain_choices.insert(0, ["축제 이야기", _open_festival_dialog])
		m.dialog.open_seq(str(def.name), _npc_portrait(npc.id), [
			{"text": GameData.npc_line(npc.id), "choices": plain_choices},
		])
		return
	# 하루 첫 대화인가 — 호칭 첫마디(society.talk_opener)는 그날 첫 만남에만 나온다 (D1)
	var first_today: bool = not npc.talked_today
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
	# 마을 확장(스토리 4 이후) — 버려진 구역을 재료를 들여 되살린다
	if npc.id == "chief" and GameData.story4_phase == "done":
		choices.insert(0, ["마을 확장 이야기", _open_zone_dialog])
	# 제4장 서브 — 새 이웃이 들어설 빈 집터 셋
	if npc.id == "chief" and GameData.plot3_quest in ["make", "report"]:
		choices.insert(0, ["집터 이야기", m.story.open_plot3_dialog])
	# 축제날에는 이장이 진행을 맡는다
	if npc.id == "chief" and GameData.festival_open():
		choices.insert(0, ["축제 이야기", _open_festival_dialog])
	# 사회(S1) — 일자리 이야기·이장의 질문·마을 회의·봉사·소매치기는 society 가 끼운다.
	# 게스트에게는 회색(gray) 으로만 보이고, 호감도 콘텐츠가 열리기 전에는 아무것도 안 낀다
	m.society.add_talk_choices(npc.id, choices)
	# 연화의 서브 퀘스트 — 「대화 끝」 바로 위에 실제 퀘스트 이름으로 뜬다
	var mom_q: Dictionary = {}
	if npc.id == "forest_mom":
		mom_q = _mom_quest_option()
		if not mom_q.is_empty():
			choices.insert(choices.size() - 1, [str(mom_q.label), mom_q.cb])
	# 호칭은 NPC 의 입으로 나온다(헌법 §0.4) — 하루 첫 대화면 첫마디를 **별도 페이지**로
	# line 앞에 둔다. line 에 접두로 붙이지 않는 이유: 위의 secret50/100·memory_given 이
	# line 을 통째로 덮어 호칭이 사라지고, 길어진 line 이 PAGE_LINES 로 갈라지면 선택지가
	# 뒷장으로 밀린다. 별도 페이지는 line 의 페이지 수를 오늘과 똑같이 둔다 (D1).
	# 빈 문자열이면(둘째 대화·호감도 잠김·게스트) 페이지를 만들지 않는다
	var opener: String = m.society.talk_opener(npc.id, first_today)
	var seq: Array = []
	if opener != "":
		seq.append({"text": opener})
	# 연화의 「!」는 선택지 페이지의 버튼이 지어진 뒤에야 붙일 수 있다 — 첫 페이지가
	# 호칭이면 즉시 부착이 빗나가므로, line 엔트리의 event 로 넘겨 society 가 한 프레임 미룬다
	seq.append({"text": line, "choices": choices,
		"event": m.society.on_choices_page.bind(str(mom_q.get("label", "")))})
	m.dialog.open_seq(title, _npc_portrait(npc.id), seq)


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
			m.farming.touch(m.grid[y][x])   # 갈아 놓은 흙도 「밭」이다
	m.dirty_all()   # 온실 한 채가 통째로 흙이 됐다 — 그려 둔 것을 버린다
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("온실 완공!")
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
		"hall":
			# 완공 직후에는 개관식부터 — 그다음부터 회관 살림이 열린다
			if GameData.story9_phase == "build":
				m.story._start_hall_open_dialog()
			else:
				_open_hall_dialog()
		"mail":
			_open_post_dialog()
		"police":
			m.society.open_police()   # 파출소 창구(사회 S2b) — 자수·출동·순찰·봉급


# ---- 우체국 (메인 스토리 3에서 세운다) ----
#
# 계산대의 우체부가 두 가지 일을 맡는다.
#   · 편지 부치기 — 마을 사람 한 명에게. 값을 치르고, 다음 날 아침
#     답장이 보관함에 도착하며 호감도가 조금 오른다. 하루 한 통.
#   · 편지 보관함 — 가방에서 **수락한 편지**가 저절로 여기로 옮겨진다.
#     가방을 비워도 지난 편지는 우체국에 그대로 남는다.

const MAIL_PAGE := 6


func _open_post_dialog() -> void:
	var box: int = GameData.mail_box.size()
	var body := "우체부 아저씨가 도장을 쥔 채 고개를 든다.\n\n"
	body += "보관함에 편지 %d통이 쌓여 있다." % box
	if not GameData.mail_out.is_empty():
		body += "\n답장을 기다리는 편지 %d통 — 내일 아침에 닿는다." \
			% GameData.mail_out.size()
	var btns: Array = [
		["편지 보관함", _open_mail_box.bind(0)],
		["편지 부치기 — %dG" % GameData.MAIL_SEND_COST, _open_mail_send.bind(0)],
		["그만두기", null],
	]
	m.dialog.open("우체국", body, btns, m.tex.get("icon_letter"))


# 보관함 — 최근 편지가 위로 온다
func _open_mail_box(page: int) -> void:
	var mails: Array = GameData.mail_box
	if mails.is_empty():
		m.dialog.open("편지 보관함",
			"아직 보관된 편지가 없다.\n\n받은 편지를 수락하면 이곳에 차곡차곡 쌓인다.",
			[["돌아가기", _open_post_dialog]], m.tex.get("icon_letter"))
		return
	var pages := maxi(1, int(ceil(mails.size() / float(MAIL_PAGE))))
	page = clampi(page, 0, pages - 1)
	var btns: Array = []
	for i in range(page * MAIL_PAGE, mini((page + 1) * MAIL_PAGE, mails.size())):
		var idx: int = mails.size() - 1 - i          # 최근 것부터
		var mail: Dictionary = mails[idx]
		btns.append([str(mail.get("title", "편지")), _read_mail.bind(idx, page)])
	if page + 1 < pages:
		btns.append(["다음 장", _open_mail_box.bind(page + 1)])
	if page > 0:
		btns.append(["앞 장", _open_mail_box.bind(page - 1)])
	btns.append(["돌아가기", _open_post_dialog])
	m.dialog.open("편지 보관함",
		"편지 %d통 (%d/%d장)\n\n읽고 싶은 편지를 고르자." % [mails.size(), page + 1, pages],
		btns, m.tex.get("icon_letter"))


func _read_mail(idx: int, page: int) -> void:
	if idx < 0 or idx >= GameData.mail_box.size():
		_open_mail_box(page)
		return
	var mail: Dictionary = GameData.mail_box[idx]
	var day := int(mail.get("day", 0))
	var head := "— %d일차에 받은 편지 —\n\n" % day if day > 0 else ""
	m.dialog.open(str(mail.get("title", "편지")),
		head + str(mail.get("body", "")),
		[["편지를 접는다", _open_mail_box.bind(page)]], m.tex.get("icon_letter"))


# 부치기 — 마을 사람 한 명을 고른다
func _open_mail_send(page: int) -> void:
	if GameData.mail_sent_today():
		m.dialog.open("우체국",
			"오늘 부칠 편지는 이미 보냈다.\n우편 마차는 하루에 한 번만 떠난다.",
			[["돌아가기", _open_post_dialog]], m.tex.get("icon_letter"))
		return
	var ids: Array = []
	for n in m.npcs:
		if GameData.NPCS.has(n.id):
			ids.append(str(n.id))
	if ids.is_empty():
		m.dialog.open("우체국", "아직 편지를 보낼 사람이 없다.",
			[["돌아가기", _open_post_dialog]], m.tex.get("icon_letter"))
		return
	var pages := maxi(1, int(ceil(ids.size() / float(MAIL_PAGE))))
	page = clampi(page, 0, pages - 1)
	var poor: bool = GameData.money < GameData.MAIL_SEND_COST
	var btns: Array = []
	for i in range(page * MAIL_PAGE, mini((page + 1) * MAIL_PAGE, ids.size())):
		var nid: String = str(ids[i])
		btns.append([str(GameData.NPCS[nid].name), _send_mail.bind(nid)])
	if page + 1 < pages:
		btns.append(["다음 장", _open_mail_send.bind(page + 1)])
	if page > 0:
		btns.append(["앞 장", _open_mail_send.bind(page - 1)])
	btns.append(["돌아가기", _open_post_dialog])
	var body := "누구에게 부칠까? 값은 %dG다.\n소지금 %dG\n\n답장은 내일 아침 보관함에 닿는다." \
		% [GameData.MAIL_SEND_COST, GameData.money]
	if poor:
		body = "우표값이 모자란다. 한 통에 %dG다.\n소지금 %dG" \
			% [GameData.MAIL_SEND_COST, GameData.money]
		btns = [["돌아가기", _open_post_dialog]]
	m.dialog.open("편지 부치기", body, btns, m.tex.get("icon_letter"))


func _send_mail(nid: String) -> void:
	if GameData.money < GameData.MAIL_SEND_COST or GameData.mail_sent_today():
		_open_post_dialog()
		return
	if not GameData.NPCS.has(nid):
		_open_post_dialog()
		return
	GameData.money -= GameData.MAIL_SEND_COST
	GameData.today_spent += GameData.MAIL_SEND_COST
	GameData.mail_sent_day = GameData.day
	GameData.mail_out.append({"npc": nid, "day": GameData.day})
	var nm: String = str(GameData.NPCS[nid].name)
	GameData.mail_store("%s에게 보낸 편지" % nm,
		"『잘 지내고 있나요.\n요즘 우리 마을은 아침 공기가 참 좋습니다.\n"
			+ "언제 한번 천천히 이야기 나눠요.』\n\n(우체부 아저씨가 도장을 꾹 눌러 주었다)")
	Sound.play_sfx("sfx_coin")
	m.hud.event_toast("%s에게 편지를 부쳤다!" % nm)
	m.saveio.save_now()
	_open_post_dialog()


# ---- 마을회관 (메인 스토리 9) ----
#
# 접수대의 이장에게서 마을 살림을 본다. 기능은 마을 크기에 따라
# 점진적으로 열린다 — 개관: 주민 명부·마을 소식 / 12명: 마을 창고 /
# 15명: 공동 프로젝트 / 20명: 마을 회의. 잠긴 기능은 공지가 예고한다.

func _open_hall_dialog() -> void:
	if GameData.story9_phase != "done":
		m.dialog.open("마을회관", "아직 문을 열지 않았다.", [["닫기", null]])
		return
	var body := "이장이 두툼한 장부를 넘기고 있다.\n\n주민 %d명 (플레이어 포함)\n%s" \
		% [m.village_residents(), GameData.hall_next_feature_text()]
	var btns: Array = [["주민 명부 보기", _open_hall_roster.bind(0)],
		["축제·행사 일정" if GameData.hall_calendar_open() else "마을 공지",
			_open_hall_notice_dialog]]
	# 첫 축제 준비 중에는 접수대가 준비물 접수처가 된다 (메인 스토리 14)
	if GameData.story14_phase == "prep":
		btns.insert(0, ["★ 축제 준비물 내놓기", _open_fest_prep_dialog])
	if GameData.hall_feature_open("store"):
		btns.append(["마을 창고", _open_hall_store_dialog])
	if GameData.hall_feature_open("project"):
		btns.append(["공동 프로젝트", _open_hall_project_dialog])
	if GameData.hall_feature_open("meet"):
		btns.append(["마을 회의", _open_hall_meeting_dialog])
	# 면사무소 창구(S2a) — 세금·예산·기관직. 회관이 열린 날부터 정부가 있다(헌법 §2.2).
	# 게스트는 조용히 죽는 단추가 아니라 회색 안내가 뜬다(D19 규약)
	if GameData.hall_feature_open("office"):
		btns.append(m.society.gray("면사무소 창구", "손님은 이 마을 일에 끼지 않는다.")
			if Net.is_guest() else ["면사무소 창구", m.society.open_township])
	btns.append(["나가기", null])
	m.dialog.open("마을회관", body, btns)


# 주민 명부 — 온 마을 사람의 이름·분류·호감도를 장부처럼 넘겨 본다
const HALL_PAGE := 7
const HALL_KIND_KOR := {"core": "토박이", "normal": "이웃", "special": "귀한 손님"}


func _open_hall_roster(page: int) -> void:
	var rows: Array = []
	for kind in ["core", "normal", "special"]:   # 토박이 먼저, 장부 순서대로
		for n in m.npcs:
			if GameData.settler_kind(n.id) != kind or not GameData.NPCS.has(n.id):
				continue
			var def: Dictionary = GameData.NPCS[n.id]
			var aff := mini(int(GameData.affinity.get(n.id, 0)), 100)
			var mark := ""
			if GameData.spouse == n.id:
				mark = " [배우자]"
			elif GameData.dating == n.id:
				mark = " [연인]"
			rows.append("· %s%s — ♥%d (%s)" % [def.name, mark, aff,
				HALL_KIND_KOR.get(kind, kind)])
	var pages := maxi(1, int(ceil(rows.size() / float(HALL_PAGE))))
	page = clampi(page, 0, pages - 1)
	var body := "주민 %d명이 장부에 적혀 있다. (%d/%d장)\n\n" \
		% [rows.size(), page + 1, pages]
	for i in range(page * HALL_PAGE, mini((page + 1) * HALL_PAGE, rows.size())):
		body += str(rows[i]) + "\n"
	var btns: Array = []
	if page + 1 < pages:
		btns.append(["다음 장", _open_hall_roster.bind(page + 1)])
	if page > 0:
		btns.append(["앞 장", _open_hall_roster.bind(page - 1)])
	btns.append(["장부를 덮는다", _open_hall_dialog])
	m.dialog.open("주민 명부", body, btns)


# 마을 소식·캘린더 — 축제 일정과 마을의 지금, 그리고 다음 목표의 예고
func _open_hall_notice_dialog() -> void:
	var body := "— %s %d일, 주민 %d명 —\n\n" \
		% [GameData.season_name(), GameData.day_in_season(), m.village_residents()]
	# 축제·행사 일정은 마을이 첫 축제를 치러야 정식으로 걸린다 (메인 스토리 14)
	if not GameData.fest_year_ok():
		# 첫 한 해는 축제를 열지 않는다 — 일정 대신 그 사정을 적어 둔다
		body += "[축제·행사 일정]\n· 올해는 축제가 없다. 마을을 추스르는 해다.\n"
	elif GameData.hall_calendar_open():
		body += "[축제·행사 일정]\n"
		for s in [GameData.SPRING, GameData.SUMMER, GameData.FALL, GameData.WINTER]:
			var f: Dictionary = GameData.FESTIVALS[s]
			var mark := " ★오늘!" if not GameData.festival_today().is_empty() \
				and GameData.season() == s \
				and GameData.day_in_season() == int(f.day) else ""
			body += "· %s %d일 — %s%s\n" % [GameData.SEASON_NAMES[s], int(f.day),
				str(f.name), mark]
	else:
		body += "[축제·행사 일정]\n· 아직 마을이 함께 치른 축제가 없다.\n"
	body += "\n[마을 공지]\n"
	if not GameData.empty_houses.is_empty():
		body += "· 빈 집 %d채 — 새 이웃을 기다린다.\n" % GameData.empty_houses.size()
	if GameData.hall_trash_total > 0:
		body += "· 지금까지 수거한 쓰레기 %d개 — 마을이 깨끗하다!\n" \
			% GameData.hall_trash_total
	if not GameData.hall_projects.is_empty():
		body += "· 완성한 공동 프로젝트 %d건.\n" % GameData.hall_projects.size()
	body += "· %s" % GameData.hall_next_feature_text()
	m.dialog.open("마을 소식·캘린더", body, [["돌아가기", _open_hall_dialog]])


# 축제 준비물 접수 (메인 스토리 14) — 여섯 가지 중 셋만 고르면 된다.
# 나머지는 주민들이 저마다 맡았다 — 어느 걸 거들지는 플레이어가 고른다.
func _open_fest_prep_dialog() -> void:
	var body := "접수대에 준비물 장부가 펼쳐져 있다.\n%d/%d 완료 — 여섯 가지 중 셋만 거들면 된다.\n" \
		% [GameData.story14_tasks.size(), GameData.STORY14_PICK]
	var btns: Array = []
	for t: Dictionary in GameData.FEST_TASKS:
		var tid := str(t.id)
		var who: String = str(GameData.NPCS[str(t.npc)].name)
		var have: int = GameData.fest_have(str(t.kind))
		if tid in GameData.story14_tasks:
			body += "\n★ %s — 완료! (%s와 함께)" % [str(t.name), who]
			continue
		body += "\n· %s %d/%d — %s (%s 담당)" % [str(t.name),
			mini(have, int(t.need)), int(t.need), str(t.desc), who]
		if have >= int(t.need) and not GameData.fest_prep_done():
			btns.append(["%s 내놓기" % str(t.name), _fest_deliver.bind(tid)])
	if GameData.fest_prep_done():
		body += "\n\n준비는 이만하면 됐다 — 이장에게 알리자!"
	btns.append(["돌아가기", _open_hall_dialog])
	m.dialog.open("축제 준비물", body, btns)


func _fest_deliver(tid: String) -> void:
	if not GameData.fest_deliver(tid):
		return
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("축제 준비 %d/%d!"
		% [GameData.story14_tasks.size(), GameData.STORY14_PICK])
	m.saveio.save_now()
	_open_fest_prep_dialog()


# 마을 창고 — 주민 기부품 보관 + 쓰레기 수거함 + 하루 한 번 운 루팅
func _open_hall_store_dialog() -> void:
	var body := "주민들이 나눠 쓰는 살림 창고.\n이따금 누군가 물건을 놓고 간다.\n\n"
	if GameData.hall_stock.is_empty():
		body += "지금은 텅 비어 있다."
	else:
		body += "보관품:"
		for iid in GameData.hall_stock:
			body += " %s x%d ·" % [GameData.ITEMS[iid].name,
				int(GameData.hall_stock[iid])]
		body = body.trim_suffix(" ·")
	var btns: Array = []
	if GameData.hall_loot_day != GameData.day and not GameData.hall_stock.is_empty():
		btns.append(["창고를 뒤적인다 (하루 한 번)", _hall_loot_pick])
	var trash := int(GameData.items.get("forage_trash", 0))
	if trash > 0:
		btns.append(["쓰레기 %d개 비우기 (+%dG)" % [trash,
			trash * GameData.HALL_TRASH_G], _hall_dump])
	btns.append(["돌아가기", _open_hall_dialog])
	m.dialog.open("마을 창고", body, btns)


func _hall_loot_pick() -> void:
	var got := GameData.hall_loot()
	Sound.play_sfx("sfx_place")
	if got == "miss":
		m.dialog.open("마을 창고", "구석구석 뒤적여 봤지만...\n오늘은 쓸 만한 게 손에 잡히지 않았다.",
			[["아쉽다", _open_hall_dialog]])
	elif got != "":
		m.dialog.open("마을 창고", "먼지 쌓인 구석에서 %s을(를) 찾았다!\n(가방에 넣었다)"
			% GameData.ITEMS[got].name, [["웬 떡이냐", _open_hall_dialog]])
	else:
		_open_hall_store_dialog()
	m.saveio.save_now()


func _hall_dump() -> void:
	var n := GameData.hall_dump_trash()
	if n > 0:
		Sound.play_sfx("sfx_catch")
		m.hud.event_toast("마을 미화 +%dG!" % (n * GameData.HALL_TRASH_G))
		m.saveio.save_now()
	_open_hall_store_dialog()


# 공동 프로젝트 — 재료를 모아 광장을 함께 가꾼다 (순서대로 하나씩)
func _open_hall_project_dialog() -> void:
	var next: Dictionary = {}
	for p: Dictionary in GameData.HALL_PROJECTS:
		if str(p.id) not in GameData.hall_projects:
			next = p
			break
	if next.is_empty():
		m.dialog.open("공동 프로젝트",
			"계획한 프로젝트는 모두 끝났다.\n광장이 몰라보게 근사해졌다!",
			[["뿌듯하다", _open_hall_dialog]])
		return
	var body := "다음 프로젝트 — 「%s」\n%s\n\n필요: " % [str(next.name), str(next.desc)]
	var parts: Array = []
	if int(next.wood) > 0:
		parts.append("목재 %d (보유 %d)" % [int(next.wood), GameData.wood])
	if int(next.stone) > 0:
		parts.append("석재 %d (보유 %d)" % [int(next.stone), GameData.stone])
	if int(next.money) > 0:
		parts.append("%dG (보유 %d)" % [int(next.money), GameData.money])
	body += " · ".join(parts)
	var ok: bool = GameData.wood >= int(next.wood) \
		and GameData.stone >= int(next.stone) and GameData.money >= int(next.money)
	var btns: Array = [["돌아가기", _open_hall_dialog]]
	if ok:
		btns.insert(0, ["재료를 내놓는다", _do_hall_project.bind(str(next.id))])
	m.dialog.open("공동 프로젝트", body if ok else body + "\n(재료가 모자란다)", btns)


func _do_hall_project(pid: String) -> void:
	var p: Dictionary = {}
	for cand: Dictionary in GameData.HALL_PROJECTS:
		if str(cand.id) == pid:
			p = cand
			break
	if p.is_empty() or pid in GameData.hall_projects \
			or GameData.wood < int(p.wood) or GameData.stone < int(p.stone) \
			or GameData.money < int(p.money):
		return
	GameData.wood -= int(p.wood)
	GameData.stone -= int(p.stone)
	GameData.money -= int(p.money)
	GameData.today_spent += int(p.money)
	GameData.hall_projects.append(pid)
	_place_hall_project_deco(p)
	# 마을이 좋아지면 다들 기뻐한다 — 온 주민의 마음이 조금씩 따뜻해진다
	for n in m.npcs:
		if GameData.affinity.has(n.id):
			GameData.affinity[n.id] = int(GameData.affinity[n.id]) + 3
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("「%s」 완성!" % str(p.name))
	m.hud.show_message("마을 사람들과 함께 「%s」을(를) 끝냈다!\n다들 무척 기뻐한다. (온 주민 호감도 +3)"
		% str(p.name), 6.0)
	m.queue_redraw()
	m.saveio.save_now()
	if m.dialog.visible:
		_open_hall_project_dialog()


# 완성한 프로젝트의 장식물을 광장에 세운다 (막힌 칸은 건너뛴다).
# 옛 세이브 로더가 가로등·벤치를 걷어내므로, 로드 후에도 여기로 되살린다.
func _place_hall_project_deco(p: Dictionary) -> void:
	if str(p.kind) == "":
		return
	for t: Array in p.tiles:
		var tile := Vector2i(int(t[0]), int(t[1]))
		if not m.objects.has(tile) and m.is_passable(tile):
			m.objnode._place_object(tile, str(p.kind), 0)


func restore_hall_project_deco() -> void:
	for p: Dictionary in GameData.HALL_PROJECTS:
		if str(p.id) in GameData.hall_projects:
			_place_hall_project_deco(p)


# 마을 회의 — 주민 20명의 큰 마을만 여는 자리 (7일에 한 번)
func _open_hall_meeting_dialog() -> void:
	var left: int = GameData.HALL_MEET_COOLDOWN \
		- (GameData.day - GameData.hall_meet_day)
	if GameData.hall_meet_day > 0 and left > 0:
		m.dialog.open("마을 회의",
			"회의는 얼마 전에 끝났다.\n다음 회의까지 %d일 남았다." % left,
			[["돌아가기", _open_hall_dialog]])
		return
	m.dialog.open("마을 회의",
		"주민들이 회관 마루에 둘러앉았다.\n안건을 올리면 다 같이 투표한다.\n(회의는 %d일에 한 번 열 수 있다)"
			% GameData.HALL_MEET_COOLDOWN, [
		["안건: 마을 대청소의 날", _meet_vote.bind("clean")],
		["안건: 간식 나눔 (800G)", _meet_vote.bind("snack")],
		["안건: 주민 퇴출", _open_expel_picker],
		["돌아가기", _open_hall_dialog],
	])


# 투표 — 마음이 가까운 주민일수록 내 안건에 손을 들어 준다
func _meet_vote(agenda: String) -> void:
	if agenda == "snack" and GameData.money < 800:
		m.dialog.open("마을 회의", "간식을 살 돈이 모자라다... (800G)",
			[["돌아가기", _open_hall_meeting_dialog]])
		return
	var yes := 0
	var no := 0
	for n in m.npcs:
		if randf() < 0.35 + float(int(GameData.affinity.get(n.id, 0))) / 200.0:
			yes += 1
		else:
			no += 1
	GameData.hall_meet_day = GameData.day
	var passed: bool = yes > no
	if passed:
		_meet_apply(agenda)
	var verdict := "가결!" if passed else "부결..."
	m.dialog.open("마을 회의 — 투표 결과",
		"찬성 %d · 반대 %d — %s\n%s" % [yes, no, verdict,
			_meet_result_text(agenda, passed)],
		[["회의를 마친다", null]])
	m.saveio.save_now()


func _meet_result_text(agenda: String, passed: bool) -> String:
	if not passed:
		return "다음 회의 때 다시 올려 보자.\n(평소 이웃들과 가깝게 지내면 표가 는다)"
	match agenda:
		"clean":
			return "다 같이 해변과 들의 쓰레기를 말끔히 치웠다!\n(온 주민 호감도 +2)"
		"snack":
			return "광장에 간식 잔치가 벌어졌다!\n(온 주민 호감도 +4)"
	return ""


func _meet_apply(agenda: String) -> void:
	match agenda:
		"clean":
			# 온 마을의 쓰레기를 걷어 낸다 (해변 채집 쓰레기)
			for t: Vector2i in m.objects.keys():
				if str(m.objects[t].get("kind", "")) == "forage_trash":
					m.objnode._remove_object(t)
			for n in m.npcs:
				if GameData.affinity.has(n.id):
					GameData.affinity[n.id] = int(GameData.affinity[n.id]) + 2
			m.queue_redraw()
		"snack":
			GameData.money -= 800
			GameData.today_spent += 800
			for n in m.npcs:
				if GameData.affinity.has(n.id):
					GameData.affinity[n.id] = int(GameData.affinity[n.id]) + 4
	Sound.play_sfx("sfx_catch")


# 주민 퇴출 — 이사 온 주민(일반·특수)만 안건에 올릴 수 있다
func _open_expel_picker() -> void:
	if GameData.settlers.is_empty():
		m.dialog.open("마을 회의",
			"퇴출 안건에 올릴 수 있는 건 이사 온 주민뿐인데,\n지금은 해당하는 사람이 없다.",
			[["돌아가기", _open_hall_meeting_dialog]])
		return
	var btns: Array = []
	for nid: String in GameData.settlers:
		btns.append(["%s (♥%d)" % [GameData.NPCS[nid].name,
			int(GameData.affinity.get(nid, 0))], _meet_expel_vote.bind(nid)])
	btns.append(["그만두기", _open_hall_meeting_dialog])
	m.dialog.open("주민 퇴출 안건", "무거운 안건이다...\n누구를 올릴까?", btns)


# 퇴출 투표 — 마을의 미움을 산 주민일수록 찬성이 쏟아진다
func _meet_expel_vote(nid: String) -> void:
	var target_aff := int(GameData.affinity.get(nid, 0))
	var yes := 0
	var no := 0
	for n in m.npcs:
		if n.id == nid:
			continue
		if randf() < clampf(0.85 - target_aff * 0.006, 0.1, 0.9):
			yes += 1
		else:
			no += 1
	GameData.hall_meet_day = GameData.day
	var nm := str(GameData.NPCS[nid].name)
	if yes > no:
		m.story._settler_depart(nid, false)
		m.dialog.open("마을 회의 — 투표 결과",
			"찬성 %d · 반대 %d — 가결.\n%s이(가) 무거운 얼굴로 짐을 쌌다...\n빈 집은 새 이웃을 기다린다." % [yes, no, nm],
			[["회의를 마친다", null]])
	else:
		m.dialog.open("마을 회의 — 투표 결과",
			"찬성 %d · 반대 %d — 부결.\n%s은(는) 마을에 남는다. 다들 뒤가 좀 머쓱해졌다." % [yes, no, nm],
			[["회의를 마친다", null]])
	m.saveio.save_now()


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
	m.hud.event_toast("씨앗 개량 %d단계!" % GameData.breed_level)
	_open_lab_dialog()


func _open_library_dialog() -> void:
	# 도서관 서가 — 오래된 책(스토리 6) · 마을의 기록 · 할아버지의 메모
	# · 할머니의 기록 (유품을 찾을 때마다 한 장씩, 스토리 11)
	var btns: Array = []
	if GameData.old_book_stored:
		btns.append(["오래된 책 보기", _open_old_book_dialog])
	btns.append(["마을의 기록 보기", _open_records_dialog])
	btns.append(["할아버지의 메모 찾기", _open_grandpa_memo_dialog])
	if GameData.relics_owned() > 0:
		btns.append(["할머니의 기록 읽기", m.story.open_grandma_records])
	# 「책 읽기 — 하루 한 권」(S1, 헌법 §7.1 books_read 가 사서보 채용의 열쇠) —
	# 게스트는 조용히 죽는 버튼이 아니라 회색 안내가 뜬다 (D19)
	btns.append(m.society.gray("책 읽기 — 하루 한 권", "손님은 이 마을 일에 끼지 않는다.")
		if Net.is_guest() else ["책 읽기 — 하루 한 권", m.society.read_book])
	btns.append(["나가기", null])
	m.dialog.open("도서관",
		"나무 냄새가 나는 아담한 서가.\n서하가 책과 마을의 기록을 정리해 두었다.", btns)


# 스토리 6에서 발견한 오래된 책 — 도서관에 보관 중 (다음 이야기의 열쇠)
func _open_old_book_dialog() -> void:
	m.dialog.open("오래된 책",
		"유리 상자 안에 오래된 책이 소중히 놓여 있다.\n\n"
		+ "서하: 「이 마을의 옛 기록이에요. 종이가 삭아서\n"
		+ "조금씩밖에 복원을 못 하고 있어요.\n"
		+ "다 읽게 되는 날... 꼭 함께 읽어요.」", [["기대되네요", null]])


# 완료한 이야기·안내를 마을의 기록으로 돌아본다
func _open_records_dialog() -> void:
	var done: Array = GameData.completed_quests()
	if done.is_empty():
		m.dialog.open("마을의 기록", "아직 기록된 이야기가 없다.\n마을의 나날이 이 책장을 채워 갈 것이다.",
			[["닫기", null]])
		return
	var body := "서하가 정리한 마을의 발자취 —\n\n"
	var n := 0
	for name: String in done:
		body += "· %s\n" % name
		n += 1
		if n >= 12:
			body += "...그리고 %d가지 더." % (done.size() - n)
			break
	m.dialog.open("마을의 기록", body, [["뿌듯하다", null]])


func _open_grandpa_memo_dialog() -> void:
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
	m.hud.event_toast(str(f.name))
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
			body += "\n\n[특전 해금] 만수의 씨앗 10% 할인!"
		elif npc_id == "fisher":
			body += "\n\n[특전 해금] 용식의 낚시 비법! 판정 구간 확대!"
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
	# 마을 생활 안내 1번 — 의뢰 게시판을 처음 열어 보면 달성
	m.tutorial_notify("board")
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


# ---- 잡화점 계산대: 만수와의 대화 메뉴 ----
#
# 계산대에서 E를 눌러도 판매 창이 바로 열리지 않는다.
# 먼저 인사말이 나오고, 선택지로 갈라진다:
#   판매하기 / 대화하기 / (서브 퀘스트 — 있을 때만, ❗ 통통) / 대화 그만두기
# 퀘스트 선택지는 언제나 「대화 그만두기」 바로 위에 선다.
#
# 첫 서브 퀘스트 「해변에 노점 차리기」는 바다가 열린 뒤부터 받을 수 있다.
# 재료(목재·조개)를 모아다 주면 해변에 만수의 노점이 선다.

const MERCHANT_QUEST_NAME := "해변에 노점 차리기"

# 「대화하기」에서 일상 대사 대신 반반 확률로 나오는 가게 팁
const MERCHANT_TIPS := [
	"씨앗은 가운데 선반에서 골라 가면 돼.\n팻말 보고 찾으면 빨라!",
	"나랑 친해지면(하트 50) 물건값을\n깎아 준다는 소문이 있어. 소문이야, 소문.",
	"작물은 나한테 팔면 바로 현금!\n그래도 요리로 만들면 더 비싸게 쳐줘.",
	"게시판 의뢰도 잊지 말고 확인해.\n쏠쏠한 부수입이 되거든.",
]


func open_merchant_counter() -> void:
	# 첫 수확을 마치고 찾아왔다 — 만수가 밥 이야기를 꺼낸다 (2장의 마지막 마디)
	if GameData.kitchen_quest_ready():
		m.story.start_kitchen_quest()
		return
	# 조리대를 찾아온 날 — 인사보다 이 이야기가 먼저다
	if GameData.kitchen_quest == "found":
		m.story.kitchen_gift_dialog()
		return
	# 지은 요리를 들고 왔다 — 칭찬과 판매 안내, 그리고 2장의 끝
	if GameData.kitchen_quest == "deliver":
		m.story.kitchen_deliver_dialog()
		return
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	var btns: Array = [
		["판매하기", _merchant_sell],
		["대화하기", _merchant_chat],
	]
	var q := _merchant_quest_option()
	if not q.is_empty():
		btns.append([str(q.label), q.cb])   # 「대화 그만두기」 바로 위
	btns.append(["대화 그만두기", null])
	m.dialog.open("잡화점 만수", "어어, %s! 무슨 일이야?" % nm,
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
	m.dialog.open_seq("잡화점 만수", _npc_portrait("merchant"), [
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
	m.dialog.open_seq("잡화점 만수", _npc_portrait("merchant"), [
		{"text": "바다가 열렸다며? 실은 나, 해변에\n작은 노점을 내는 게 꿈이었어."},
		{"text": "낚시용품이랑 바다 요리 레시피를 팔고,\n해변에서 주운 것들도 사 주는 가게!"},
		{"text": "목재 %d개랑 조개 %d개만 구해다 줄래?\n진열대랑 장식으로 쓰게." \
			% [GameData.STALL_WOOD, GameData.STALL_SHELLS]},
	], func() -> void:
		m.hud.quest_start_toast("서브 퀘스트: %s" % MERCHANT_QUEST_NAME)
		open_merchant_counter())


func _merchant_errand_turnin() -> void:
	var have_w: int = GameData.wood
	var have_s := int(GameData.items.get("forage_shell", 0))
	if have_w < GameData.STALL_WOOD or have_s < GameData.STALL_SHELLS:
		m.dialog.open_seq("잡화점 만수", _npc_portrait("merchant"), [
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
	m.dialog.open_seq("잡화점 만수", _npc_portrait("merchant", true), [
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
# 구매(미끼·노점 한정 레시피)는 만수가 나와 있는 시간에만,
# 판매는 만수가 없어도 언제든 할 수 있다.
func open_stall() -> void:
	if GameData.merchant_at_stall():
		m.shop.open("buy", ["buy", "sell"], "해변 노점", "stall")
	else:
		m.hud.show_message("만수가 자리에 없다 — 판매만 할 수 있다.\n"
			+ "(만수는 하루 세 번, 한 시간씩 노점에 나온다)", 4.0)
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

# 수납 상자 설치 — 집 안 세간으로만 들어간다 (창고는 하나로 이어져 있다)
func use_storage_box() -> void:
	if int(GameData.items.get("storage_box", 0)) <= 0:
		return
	if not m.interior.visible:
		m.hud.show_message("수납 상자는 집 안에 놓는 물건이다.\n집에 들어가서 놓자.", 4.0)
		return
	if GameData.house_lv < 2:
		m.hud.show_message("오두막은 너무 좁다 — 집을 확장하면 놓을 자리가 생긴다.", 5.0)
		return
	GameData.items["storage_box"] = int(GameData.items["storage_box"]) - 1
	GameData.furniture.append({"id": "storage_box",
		"x": 400.0 + float(GameData.furniture.size() % 4) * 44.0,
		"y": 300.0 + float(GameData.furniture.size() / 4 % 3) * 32.0})
	Sound.play_sfx("sfx_place")
	m.hud.event_toast("수납 상자를 놓았다")
	m.hud.show_message("가까이에서 E: 물건 넣고 빼기 · 꾸미기(F)로 옮길 수 있다", 5.0)
	m.interior.canvas.queue_redraw()
	m.saveio.save_now()


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
		m.hud.event_toast("쓰레기통을 들여놓았다")
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
	m.hud.show_message("쓰레기통 설치! 열어서 24시간 팔 수 있다 — 제값의 80%.", 5.0)
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
		m.hud.quest_start_toast("연화의 부탁: %s" % str(q.name))
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
