# 세이브 — 세계를 담고, 다시 편다.
#
# 담는 규칙은 GameData.build_save에 있고, 여기는 **세계 쪽**(격자·오브젝트·
# 가축·플레이어 위치)을 담고 펴는 일만 한다. 함께하기의 스냅샷도 같은 길을
# 쓴다 — 그래서 저장 형식이 바뀌면 통신도 같이 따라온다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinSaveIO
extends Node

var m: KyojinMain    # main.gd


# ---- 자동 저장 ----
#
# 15분(실제 시간)마다 알아서 담는다. 원래는 잠들 때와 F5뿐이라, 하루를
# 길게 놀다 껐다 켜면 그 하루가 통째로 날아갔다.
#
# 시계를 **여기** 둔다 — 저장을 맡은 쪽이 시계도 가져야, 잠들거나 F5로
# 저장했을 때 15분이 저절로 다시 시작된다 (main에 두면 저장할 때마다
# 그쪽 시계를 따로 만져 줘야 하고, 한 군데만 빠뜨려도 방금 담고 또 담는다).
const AUTO_EVERY := 900.0        # 15분
# 못 담고 미룰 때 다시 보는 간격. 이야기 한 장면이 끝나기를 기다리는
# 것이라 짧게 잡는다 (다음 15분까지 기다리면 그 사이가 통째로 빈다).
const AUTO_RETRY := 5.0
var _auto_t := 0.0


func autosave_tick(delta: float) -> void:
	if Net.is_guest():
		return                   # 저장은 호스트만 (게스트는 시계도 안 돈다)
	_auto_t += delta
	if _auto_t < AUTO_EVERY:
		return
	# 이야기 연출 중에는 미룬다. 그 한복판을 담으면 불러올 때 연출이
	# 반쯤 진행된 자리에서 시작한다 — 담을 수야 있지만 굳이 그 순간일 이유가 없다.
	if m.story_cutscene or m.ending.visible:
		_auto_t = AUTO_EVERY - AUTO_RETRY
		return
	save_now()                   # 여기서 _auto_t가 0으로 돌아간다
	m.hud.show_message("자동 저장했다.")


func save_now() -> void:
	_auto_t = 0.0                # 어떤 이유로 담았든 15분을 다시 센다
	if Net.is_guest():
		return  # 저장은 호스트만
	var g := grid_cells()
	var objs := object_rows()
	var anims := []
	for a in m.animals:
		anims.append([a.type, a.position.x, a.position.y, 1 if a.fed else 0])
	GameData.save_game(g, m.player.position, objs, anims, m.MAP_W, m.MAP_H)


# 격자는 **사람이 바꾼 칸만** 담는다.
#
# 예전에는 온 격자를 통째로 적었다. 224x146일 때는 3만 칸이라 견뎠는데,
# 세계가 네 배로 넓어지며 13만 6천 칸이 됐다 — 저장 한 번에 오 메가바이트를
# 쓰고, 밭 스무 칸 갈아 놓고 그 짓을 한다. 함께하기는 이걸 통째로 **전송**까지
# 했다 — 접속 한 번에 5메가바이트다.
#
# 나머지 칸은 적을 이유가 없다. 세계를 짓는 일은 처음부터 끝까지
# **해시로만** 정해지므로(무작위가 한 군데도 없다), 다시 지으면 잔디도
# 자갈도 모래도 물도 한 칸까지 똑같이 나온다. 사람이 손댄 것 — 갈아 놓은
# 흙, 심은 작물, 물 준 자리 — 만이 다시 못 만드는 것이다.
#
# (자갈을 잔디로 되돌린 자리는 담지 못한다. 하지만 그건 예전 형식도
#  마찬가지였다 — 불러올 때 _paint_regions 가 자갈을 도로 깔았다)
# (담을 칸을 **찾는 일**도 지도를 안 훑는다. 예전에는 여기서 13만 6천 칸을
#  하나씩 걸렀는데, 남는 것은 언제나 **밭 칸**뿐이었다 — 젖었거나 · 심겼거나 ·
#  갈아 놓은 흙. 그건 농사 쪽이 이미 목록으로 들고 있다. 저장은 잠들 때마다
#  일어나므로 그 훑기가 그대로 하루 넘김의 멈춤이 됐다)
func grid_cells() -> Array:
	var g := []
	for c: Dictionary in m.farming.farm_cells():
		g.append([int(c.tx), int(c.ty), c.ground, float(c.wet_min), c.crop_id,
			float(c.crop_day), 1 if c.dead else 0,
			1 if c.get("half_fed", false) else 0])
	return g


# 세계에 놓인 것들 (나무·돌·울타리·설치물)
func object_rows() -> Array:
	var objs := []
	for pos: Vector2i in m.objects:
		objs.append([pos.x, pos.y, m.objects[pos].kind, m.objects[pos].hp,
			1 if m.objects[pos].get("apple", false) else 0,
			1 if m.objects[pos].get("young", false) else 0,
			int(m.objects[pos].get("grow", 0)),
			1 if m.objects[pos].get("fixed", false) else 0,
			# 8: 누워 있는 나무 — **누운 쪽**까지 담는다 (0 안 누움 / 1 서쪽 /
			#    2 동쪽) · 9: 광석이 박힌 바위.
			# 옛 세이브에는 이 자리가 없다 — 읽는 쪽이 길이를 본다
			(2 if float(m.objects[pos].get("fallen", 0.0)) > 0.0
				else (1 if m.objects[pos].get("fallen", false) else 0)),
			1 if m.objects[pos].get("ore", false) else 0])
	return objs


func _apply_save(d: Dictionary) -> void:
	GameData.day = int(d.day)
	GameData.minutes = float(d.minutes)
	GameData.money = int(d.money)
	GameData.energy = float(d.energy)
	GameData.hunger = float(d.get("hunger", GameData.HUNGER_MAX))
	GameData.hunger_open = bool(d.get("hunger_open", false))
	GameData.gender = str(d.get("gender", "m"))
	# 외형 — 외형 시스템 이전의 세이브는 성별에서 옛 기본 모습을 만든다
	# (남자 = 민머리·파란 셔츠, 여자 = 긴 머리·분홍 셔츠)
	var was_f := GameData.gender == "f"
	var ap: Dictionary = d.get("appearance", {})
	GameData.appearance = {
		"hair": int(ap.get("hair", 3 if was_f else 0)),
		"shirt": int(ap.get("shirt", 1 if was_f else 0)),
		"pants": int(ap.get("pants", 0)),
		"shoes": int(ap.get("shoes", 0)),
		"skin": int(ap.get("skin", 0)),
		"hair_col": int(ap.get("hair_col", 0)),
	}
	GameData.story_phase = str(d.get("main_story", "done"))
	GameData.tree_regrow = d.get("tree_regrow", [])
	GameData.player_name = str(d.get("player_name", ""))
	GameData.farm_name = str(d.get("farm_name", ""))
	GameData.village_name = str(d.get("village_name", ""))
	GameData.village_built = d.get("village_built", [])
	GameData.house_lv = int(d.get("house_lv", 0))
	GameData.has_bed = bool(d.get("has_bed", false))
	GameData.desk_lv = int(d.get("desk_lv", 0))
	# 침대 등급이 생기기 전 세이브: 만들어 둔 침대는 나무 침대(100%)로 쳐 준다
	GameData.bed_lv = int(d.get("bed_lv", 1 if GameData.has_bed else 0))
	GameData.dust_swept = int(d.get("dust_swept", 0))
	GameData.fisher_quest = str(d.get("fisher_quest", ""))
	GameData.fisher_choice = int(d.get("fisher_choice", 0))
	# 용식의 집터 부탁 (서브) + 수납 상자 안의 살림
	GameData.fisher_home = str(d.get("fisher_home", ""))
	GameData.home_signs = Dictionary(d.get("home_signs", {}))
	GameData.sea_open_day = int(d.get("sea_open_day", 0))
	GameData.storage_stock = Dictionary(d.get("storage_stock", {}))
	if GameData.sea_open and GameData.sea_open_day <= 0:
		# 이 이야기가 생기기 전의 세이브 — 오늘을 기준으로 3일 뒤에 나온다
		GameData.sea_open_day = GameData.day
	GameData.sea_open = bool(d.get("sea_open", false))
	GameData.merchant_errand = str(d.get("merchant_errand", ""))
	GameData.merchant_day = int(d.get("merchant_day", 0))
	GameData.stall_hours = (d.get("stall_hours", []) as Array)
	GameData.forest_quest = str(d.get("forest_quest", ""))
	GameData.forest_day = int(d.get("forest_day", 0))
	GameData.forest_trust = str(d.get("forest_trust", ""))
	# 옛 세이브에는 이 값이 없다 — 마을에 이미 도착했으면 튜토리얼 공간은 닫힌 것
	GameData.tutorial_space = bool(d.get("tutorial_space",
		GameData.story_phase in ["enter", "approach", "equip", "chop",
			"path", "map", "rock", "travel"]))
	# 옛 세이브: 「visit」 단계는 이제 없다 — 동행부터 다시 걷는다
	if GameData.forest_quest == "visit":
		GameData.forest_quest = "go"
	GameData.move_quest = str(d.get("move_quest", ""))
	GameData.move_seeds = int(d.get("move_seeds", 0))
	GameData.move_day = int(d.get("move_day", 0))
	GameData.move_min = int(d.get("move_min", 0))
	var mh: Array = d.get("move_house", [])
	GameData.move_house = Vector2i(int(mh[0]), int(mh[1])) if mh.size() == 2 \
		else Vector2i(-999, -999)
	GameData.home_plots = (d.get("home_plots", []) as Array)
	# 이사 편지(스토리 3)가 생기기 전 세이브: 재민이 이미 마을에 있으면
	# (숲속의 집 이야기가 시작됐으면) 이사는 끝난 것으로 친다
	if GameData.move_quest == "" and GameData.forest_quest != "":
		GameData.move_quest = "done"
	# 편지를 읽던 중 저장했으면 다음 날 아침 다시 온다
	if GameData.move_quest == "letter":
		GameData.move_quest = ""
		GameData.move_day = GameData.day - 1
	# 집터 선행 조건이 생기기 전 세이브: 진행 중이면 편지를 가방에 챙겨 준다
	if GameData.move_quest in ["show", "build"] \
			and int(GameData.items.get("move_letter", 0)) <= 0:
		GameData.items["move_letter"] = 1
	GameData.plot3_quest = str(d.get("plot3_quest", ""))
	GameData.plot3_made = int(d.get("plot3_made", 0))
	GameData.mail_box = (d.get("mail_box", []) as Array)
	GameData.mail_out = (d.get("mail_out", []) as Array)
	GameData.mail_sent_day = int(d.get("mail_sent_day", 0))
	GameData.mom_quest = str(d.get("mom_quest", ""))
	GameData.mom_quests_done = (d.get("mom_quests_done", []) as Array)
	GameData.spear_quest = str(d.get("spear_quest", ""))
	if GameData.spear_quest == "visit":
		GameData.spear_quest = "pending"   # 걸어오다 저장했으면 다시 걸어온다
	GameData.chief_house_lv = int(d.get("chief_house_lv", 0))
	GameData.story4_phase = str(d.get("story4_phase", ""))
	GameData.zones_open = d.get("zones_open", [])
	m.dirty_walk()   # 세이브의 해금 상태로 걸을 수 있는 땅을 다시 잰다
	GameData.story6_phase = str(d.get("story6_phase", ""))
	GameData.story6_day = int(d.get("story6_day", 0))
	GameData.old_book_stored = bool(d.get("old_book_stored", false))
	GameData.story7_phase = str(d.get("story7_phase", ""))
	GameData.story8_phase = str(d.get("story8_phase", ""))
	# 생명의 물 — 이제 「분야 만렙」의 증표다. 옛 세이브의 활동 출처
	# 키(tree/rock 등)는 버리고, 이미 만렙인 분야는 로드 때 소급해 준다
	GameData.water_life_found = {}
	for wk in d.get("water_life_found", {}):
		if str(wk) in GameData.ENDING_SKILLS:
			GameData.water_life_found[str(wk)] = true
	GameData.dream_ready = bool(d.get("dream_ready", false))
	GameData.dream_seen = bool(d.get("dream_seen", false))
	GameData.arrive_day = int(d.get("arrive_day", 0))
	GameData.arrive_clock = str(d.get("arrive_clock", ""))
	GameData.playtime_sec = float(d.get("playtime_sec", 0.0))
	GameData.rocks_mined = int(d.get("rocks_mined", 0))
	GameData.settlers = d.get("settlers", [])
	GameData.settler_homes = d.get("settler_homes", {})
	GameData.empty_houses = d.get("empty_houses", [])
	GameData.settler_offer = str(d.get("settler_offer", ""))
	GameData.settler_offer_day = int(d.get("settler_offer_day", 0))
	GameData.settler_arrive = str(d.get("settler_arrive", ""))
	GameData.settler_arrive_day = int(d.get("settler_arrive_day", 0))
	GameData.settler_leaving = str(d.get("settler_leaving", ""))
	GameData.settler_leave_day = int(d.get("settler_leave_day", 0))
	GameData.npc_last_talk = d.get("npc_last_talk", {})
	GameData.last_farewell = str(d.get("last_farewell", ""))
	# 구세이브 호환 — 목장 상회가 이야기(스토리 8) 도입 전에 이미 서
	# 있었다면, 그 세이브에서는 8장을 완료로 친다 (방문객 연출이 이미
	# 정착한 보라와 겹치지 않게)
	if GameData.story8_phase == "" and d.get("village_built", []).has("ranch"):
		GameData.story8_phase = "done"
	GameData.arrivals = d.get("arrivals", [])
	GameData.npc_greeted = d.get("npc_greeted", [])
	GameData.recipe_items = d.get("recipe_items", {})
	# 발견 기록과 배운 레시피 — 저장에는 실려 있었는데 읽는 쪽이 없어서
	# 재로드 때 백필로만 어림잡던 구멍을 메웠다 (처음 얻은 날, 배운
	# 레시피가 이제 그대로 살아난다)
	for k in d.get("discovered", {}):
		GameData.discovered[k] = int(d.discovered[k])
	for rid in d.get("recipes_unlocked", []):
		if str(rid) not in GameData.recipes_unlocked:
			GameData.recipes_unlocked.append(str(rid))
	GameData.tracked_pick = str(d.get("tracked_pick", ""))
	GameData.respawn_queue = d.get("respawn_queue", [])
	# 첫 인사 시스템이 생기기 전 세이브: 이미 지어져 영업하던 건물의
	# 주인들은 인사를 마친 것으로 친다 (재민도 이사가 끝났으면 마찬가지)
	if not d.has("npc_greeted"):
		for pid: String in GameData.village_built:
			var owner := str(m.VILLAGE_NPC.get(pid, ""))
			if owner != "" and owner not in GameData.npc_greeted:
				GameData.npc_greeted.append(owner)
		if GameData.move_quest == "done" \
				and "explorer" not in GameData.npc_greeted:
			GameData.npc_greeted.append("explorer")
	# 인사만 남기고 저장한 세이브: 재민이 다시 찾아오도록 대기열에 태운다
	if GameData.move_quest == "greet":
		var has_ex := false
		for a2 in GameData.arrivals:
			if str(a2.id) == "explorer":
				has_ex = true
		if not has_ex:
			GameData.arrivals.append({"id": "explorer", "day": GameData.day - 1})
	# 숲속의 집 이야기가 생기기 전 세이브: 이미 선물을 주고받던 사이면
	# (호감도가 쌓여 있으면) 호감도 콘텐츠는 열린 채로 이어 준다
	var had_aff := false
	for ak in d.get("affinity", {}):
		if int(d.affinity[ak]) >= 10:
			had_aff = true
	GameData.affinity_open = bool(d.get("affinity_open", had_aff))
	# 노점은 다 지었는데 오늘 방문 시각이 없다 (옛 세이브/자정 전 저장) — 새로 뽑는다
	if GameData.merchant_errand == "done" and GameData.stall_hours.is_empty():
		GameData.roll_stall_hours()
	# 스토리 2 재배열 전 세이브: 낚시꾼을 끝냈으면 완료로, 아니면 낚시꾼
	# 대기로 이어 준다 (옛 세이브는 마을이 이미 다 서 있다)
	GameData.story2_phase = str(d.get("story2_phase",
		"done" if str(d.get("fisher_quest", "")) == "done" else "fisher"))
	# 무건물 시작 버그(reset_all 잔재가 ALL을 다시 채우던 시절) 세이브 교정:
	# 스토리가 거기까지 안 갔으면 건물이 서 있을 수 없다
	if GameData.story_phase != "done" or GameData.story2_phase == "":
		GameData.village_built = []
	elif GameData.story2_phase == "shop":
		GameData.village_built.erase("general")   # 상점은 퀘스트로 지어야 한다
	# 조리대 발견이 생기기 전 세이브: 이미 요리하던 집(확장됨/요리 기록)은
	# 발견한 것으로 친다 — 쓰던 조리대가 갑자기 먼지에 묻히면 안 된다
	GameData.kitchen_found = bool(d.get("kitchen_found",
		int(d.get("house_lv", 0)) >= 2 or not d.get("recipes_cooked", {}).is_empty()))
	# 「먼지 속의 조리대」 — 이 이야기가 생기기 전 세이브에서 이미 조리대를
	# 찾아 놨다면 튜토리얼은 끝난 것으로 친다 (레시피를 못 사면 곤란하다)
	GameData.kitchen_quest = str(d.get("kitchen_quest",
		"done" if GameData.kitchen_found else ""))
	GameData.kitchen_branch = str(d.get("kitchen_branch", ""))
	# 예전에는 첫 수확만으로 2장이 끝났다 — 그때 조리대를 못 찾았다면
	# 마지막 마디(만수와의 밥 이야기)를 마저 걷게 되돌려 준다
	if GameData.story2_phase == "done" and not GameData.kitchen_found \
			and GameData.kitchen_quest == "":
		GameData.story2_phase = "cook"
	GameData.desk_queue = []
	for job in d.get("desk_queue", []):
		if GameData.DESK_RECIPES.has(str(job.get("id", ""))):
			GameData.desk_queue.append({"id": str(job.id), "left": float(job.get("left", 1.0))})
	GameData.explored = {}
	for c in d.get("explored", []):
		GameData.explored[Vector2i(int(c[0]), int(c[1]))] = true
	GameData.trees_chopped = int(d.get("trees_chopped", 0))
	GameData.u_intro_state = int(d.get("u_intro", 0))
	GameData.story_rock_state = int(d.get("rock_state", 0))
	GameData.story_gates_left = int(d.get("gates_left", 0))
	GameData.wood = int(d.get("wood", 0))
	GameData.stone = int(d.get("stone", 0))
	for k in d.get("tool_level", {}):
		GameData.tool_level[k] = int(d.tool_level[k])
	var slots: Variant = d.get("tool_slots", null)
	if typeof(slots) == TYPE_ARRAY and slots.size() >= 9:
		GameData.tool_slots = []
		for t in slots:
			GameData.tool_slots.append(str(t))
		while GameData.tool_slots.size() < GameData.TOOL_SLOT_COUNT:
			GameData.tool_slots.append("")  # 칸 수가 늘어난 구버전 저장 호환
		if GameData.tool_slots.size() > GameData.TOOL_SLOT_COUNT:
			GameData.tool_slots.resize(GameData.TOOL_SLOT_COUNT)  # 12칸 -> 9칸 호환
	for k in d.seeds:
		GameData.seeds[k] = int(d.seeds[k])
	for k in d.produce:
		GameData.produce[k] = int(d.produce[k])
	for k in d.get("items", {}):
		GameData.items[k] = int(d.items[k])
	for k in d.get("fish_caught", {}):
		GameData.fish_caught[k] = int(d.fish_caught[k])
	for k in d.get("affinity", {}):
		GameData.affinity[k] = int(d.affinity[k])
	if d.has("quest") and typeof(d.quest) == TYPE_DICTIONARY and not d.quest.is_empty():
		# 옛 저장은 「crop」이었다 (작물 납품 한 종류뿐이던 시절)
		GameData.quest = {
			"item": str(d.quest.get("item", d.quest.get("crop", ""))),
			"kind": str(d.quest.get("kind", "crop")),
			"label": str(d.quest.get("label", "작물")),
			"qty": int(d.quest.qty),
			"reward": int(d.quest.reward), "accepted": bool(d.quest.accepted),
		}
		if str(GameData.quest.item) == "":
			GameData.quest = {}
	GameData.quest_offers = d.get("quest_offers", [])
	# 구버전 저장에는 튜토리얼 정보가 없다 → 완료로 간주
	GameData.tutorial = d.get("tutorial", {"active": false})
	# 마을 생활 안내 분리(스토리 3과 함께 시작) 이전 세이브:
	# 안내 목표를 전부 초기화하고, 스토리 3을 이미 시작했으면 안내도 연다
	GameData.guide_active = bool(d.get("guide_active",
		str(d.get("move_quest", "")) != ""))
	if not d.has("guide_active"):
		for pair in GameData.TUTORIAL_ORDER:
			if pair[0] not in GameData.STORY2_FLAGS:
				GameData.tutorial[pair[0]] = false
		if GameData.tutorial.get("active", true) == false:
			GameData.tutorial["active"] = true   # 리셋한 안내를 다시 진행할 수 있게
	# 예전 세이브 고치기: 「조리대에서 요리를 하자」가 체크될 길이 없던 시절의
	# 세이브는 2장을 끝내고도 그 목표가 남아 있다. 만수에게 요리를 가져다줬으면
	# 요리는 이미 지어 본 것이니 여기서 닫아 준다.
	if str(d.get("kitchen_quest", "")) == "done" \
			and GameData.tutorial.get("active", false):
		GameData.tutorial["cook"] = true
	GameData.grandpa_step = int(d.get("grandpa_step", 0))
	GameData.grandpa_seen = bool(d.get("grandpa_seen", false))
	GameData.alchemy_known = d.get("alchemy_known", [])
	for k in d.get("alchemy_brews", {}):
		GameData.alchemy_brews[k] = int(d.alchemy_brews[k])
	GameData.alchemy_fails = int(d.get("alchemy_fails", 0))
	for k in d.get("potion_today", {}):
		GameData.potion_today[k] = bool(d.potion_today[k])
	GameData.breed_level = int(d.get("breed_level", 0))
	GameData.greenhouse_built = bool(d.get("greenhouse_built", false))
	GameData.has_horse = bool(d.get("has_horse", false))
	GameData.riding = false                      # 불러오면 언제나 내린 채로 시작
	var ht: Array = d.get("horse_tile", [14, 12])
	GameData.horse_tile = Vector2i(int(ht[0]), int(ht[1]))
	GameData.mine_deepest = maxi(1, int(d.get("mine_deepest", 1)))
	GameData.fest_history = d.get("fest_history", []).duplicate()
	GameData.owned_gear = d.get("owned_gear", []).duplicate()
	for slot: String in GameData.GEAR_SLOTS:
		var gid: String = str(d.get("equipped", {}).get(slot, ""))
		# 없는 장비를 끼고 있는 저장은 무시한다 (표에서 빠진 장비 등)
		GameData.equipped[slot] = gid if GameData.owned_gear.has(gid) else ""
	GameData.unlocked_tools = d.get("unlocked_tools", GameData.ALL_TOOLS.duplicate())
	# 스프링클러가 퀘스트 보상에서 잡화점 레시피(농사 Lv3)로 바뀌었다 —
	# 레시피 없이 열려 있던 구세이브의 스프링클러는 회수한다 (설치물은 유지)
	if GameData.unlocked_tools.has("sprinkler") \
			and "sprinkler" not in GameData.recipes_unlocked:
		GameData.unlocked_tools.erase("sprinkler")
	for k in d.get("mob_kills", {}):
		GameData.mob_kills[k] = int(d.mob_kills[k])
	GameData.apply_skills_data(d.get("skills", {}))
	# 이미 만렙에 닿아 있던 분야는 생명의 물을 소급해 받는다
	for sid: String in GameData.ENDING_SKILLS:
		GameData.check_skill_water(sid)
	if d.has("furniture"):
		GameData.apply_furniture_data(d.furniture)
		if int(d.get("tile", 16)) != m.TILE:
			for furn in GameData.furniture:  # 구버전 집 좌표(640기준) → 960기준
				furn.x = float(furn.x) * 1.5
				furn.y = float(furn.y) * 1.5
	for k in d.get("recipes_cooked", {}):
		GameData.recipes_cooked[k] = int(d.recipes_cooked[k])
	# 노점 한정 레시피가 생기기 전 세이브: 이미 만들어 본 요리는 아는 것으로 친다
	for rid: String in GameData.STALL_RECIPE_IDS:
		if int(GameData.recipes_cooked.get(rid, 0)) > 0 \
				and rid not in GameData.recipes_unlocked:
			GameData.recipes_unlocked.append(rid)
	GameData.owned_pets = d.get("owned_pets", [])
	GameData.active_pet = str(d.get("active_pet", ""))
	for k in d.get("forage_caught", {}):
		GameData.forage_caught[k] = int(d.forage_caught[k])
	_backfill_discovered()
	GameData.hall_noticed = bool(d.get("hall_noticed", false))
	# 메인 스토리 9 (마을회관) — 회관이 이미 서 있는 구세이브는 완결로 본다
	GameData.story9_phase = str(d.get("story9_phase", ""))
	if GameData.story9_phase == "" and GameData.village_built.has("hall"):
		GameData.story9_phase = "done"
	GameData.hall_stock = d.get("hall_stock", {})
	GameData.hall_loot_day = int(d.get("hall_loot_day", 0))
	GameData.hall_trash_total = int(d.get("hall_trash_total", 0))
	GameData.hall_projects = Array(d.get("hall_projects", []))
	GameData.hall_meet_day = int(d.get("hall_meet_day", 0))
	GameData.hall_feat_noticed = Array(d.get("hall_feat_noticed", []))
	GameData.story10_phase = str(d.get("story10_phase", ""))
	GameData.story11_phase = str(d.get("story11_phase", ""))
	GameData.story11_clues = Array(d.get("story11_clues", []))
	GameData.grandma_read = int(d.get("grandma_read", 0))
	# 씨앗 진열이 생기기 전 세이브: 기본 두 종(밀·옥수수)으로 시작한다
	GameData.shop_seeds = d.get("shop_seeds", ["wheat", "corn"])
	# 조리대가 빈 채로 시작하는 개편 전 세이브: 이미 만들어 본 요리와,
	# 재료를 전부 발견해 둔 기본 요리는 아는 것으로 쳐 준다
	for rid: String in GameData.RECIPE_IDS:
		if int(GameData.recipes_cooked.get(rid, 0)) > 0 \
				and rid not in GameData.recipes_unlocked:
			GameData.recipes_unlocked.append(rid)
	GameData._check_recipe_unlocks()
	GameData.recipe_pending.clear()   # 로드 직후엔 토스트를 쏟아내지 않는다
	for k in d.get("produce_silver", {}):
		GameData.produce_silver[k] = int(d.produce_silver[k])
	for k in d.get("produce_gold", {}):
		GameData.produce_gold[k] = int(d.produce_gold[k])
	GameData.barn_built = bool(d.get("barn_built", false))
	if GameData.barn_built and not m.objects.has(m.BARN_POS):
		m.objects[m.BARN_POS] = {"kind": "barn", "hp": 0}
		m.worldgen._block_barn_art()
	var anim_scale := float(m.TILE) / float(d.get("tile", 16))
	for a in d.get("animals", []):
		m.farming.spawn_animal(a[0], Vector2(float(a[1]), float(a[2])) * anim_scale, int(a[3]) == 1)
	# 구버전(16px 타일) 저장 좌표 환산
	var pos_scale := float(m.TILE) / float(d.get("tile", 16))
	m.player.position = Vector2(float(d.player[0]), float(d.player[1])) * pos_scale

	# ---- 밭 상태 ----
	#
	# 새 형식은 **사람이 바꾼 칸만** 담는다. 세계가 448x264 로 넓어지면서
	# 격자가 13만 6천 칸이 됐다 — 통째로 적으면 저장 한 번에 오 메가바이트고,
	# 밭 스무 칸 갈아 놓고 그 짓을 한다. 나머지 칸은 세계를 다시 지으면
	# 똑같이 나오므로 적을 이유가 없다 (save_now 참고).
	if d.has("grid_cells"):
		if int(d.get("grid_w", 0)) != m.MAP_W or int(d.get("grid_h", 0)) != m.MAP_H:
			# 세계 크기가 달라진 옛 저장 — 밭도 오브젝트도 자리가 어긋난다
			m.player.position = Vector2(m.START_TILE.x * m.TILE + 16,
				m.START_TILE.y * m.TILE + 16)
			return
		for s: Array in d.grid_cells:
			var cx := int(s[0])
			var cy := int(s[1])
			if cx < 0 or cy < 0 or cx >= m.MAP_W or cy >= m.MAP_H:
				continue
			var c2: Dictionary = m.grid[cy][cx]
			# 물 칸은 지형이 정한다 — 밭 상태만 얹는다
			if c2.ground != "water" and str(s[2]) != "water":
				c2.ground = s[2]
			c2.wet_min = float(s[3])
			c2.watered = float(s[3]) > 0.0
			c2.crop_id = s[4]
			c2.crop_day = float(s[5])
			c2.dead = int(s[6]) == 1
			c2.half_fed = int(s[7]) == 1
	else:
		# ---- 옛 형식: 격자를 통째로 적던 시절 ----
		# 맵 크기가 다른 옛 저장이면 밭 상태는 버리고 진행 상황만 복원한다.
		# 다만 **튜토리얼 공간이 격자 아래에 붙기 전(세계 높이만큼만 저장하던)**
		# 것은 세계 부분이 한 칸도 안 어긋났다 — 그만큼만 읽어 밭을 살린다.
		var g: Array = d.get("grid", [])
		var rows: int = m.MAP_H
		if g.size() == m.WORLD_H and g.size() > 0 and g[0].size() == m.MAP_W:
			rows = m.WORLD_H
		elif g.size() != m.MAP_H or (g.size() > 0 and g[0].size() != m.MAP_W):
			m.player.position = Vector2(m.START_TILE.x * m.TILE + 16,
				m.START_TILE.y * m.TILE + 16)
			return
		for y in rows:
			for x in m.MAP_W:
				var s: Array = g[y][x]
				var cell: Dictionary = m.grid[y][x]
				# 물 타일은 맵 생성 결과를 유지하고 경작 상태만 복원
				if cell.ground != "water" and s[0] != "water":
					cell.ground = s[0]
				# 구버전 호환: 0/1 플래그였으면 젖음 6시간으로 간주
				var wet := float(s[1])
				if wet == 1.0:
					wet = m.WET_MANUAL
				cell.wet_min = wet
				cell.watered = wet > 0.0
				cell.crop_id = s[2]
				# 구버전 호환: 일 단위(0~9)였으면 시간 단위(분)로 환산
				var growth := float(s[3])
				if growth > 0.0 and growth < 15.0:
					growth *= 60.0
				cell.crop_day = growth
				cell.dead = s.size() > 4 and int(s[4]) == 1
				cell.half_fed = s.size() > 5 and int(s[5]) == 1
		# 흙길·부두·다리가 전부 없어졌다 — 옛 세이브의 길/데크는 잔디로.
		# (옛 강 물칸은 위의 물 규칙 덕에 새 지형(잔디)을 그대로 따른다)
		# 세계에만 적용한다 — 튜토리얼 공간의 숲길은 이야기가 깐 진짜 길이다.
		for y2 in m.WORLD_H:
			for x2 in m.MAP_W:
				var c3: Dictionary = m.grid[y2][x2]
				if c3.ground in ["path", "dock"]:
					c3.ground = "grass"
		# 위에서 자갈 바닥까지 같이 걷혔다 — 지역 바닥(채석장 자갈·습지 웅덩이)은
		# 지형이 정하는 것이지 저장에 딸린 게 아니니 여기서 다시 깐다
		m.worldgen._paint_regions()
	if d.has("objects"):
		m.objects.clear()
		for o in d.objects:
			if str(o[2]) in ["deco_lamp", "deco_bench", "old_gate"]:
				continue   # 가로등·벤치·돌문은 없앴다 — 옛 세이브에서 걷어 낸다
			if str(o[2]) == "fence" and o.size() > 7 and int(o[7]) == 1 \
					and int(o[0]) >= 54:
				continue   # 건물 마당을 감싸던 고정 울타리도 없앴다
				# (숲길의 스토리 울타리는 x<54라 그대로 남는다)
			var od := {"kind": o[2], "hp": int(o[3])}
			if o.size() > 4 and int(o[4]) == 1:
				od["apple"] = true
			if o.size() > 6 and int(o[5]) == 1:
				od["young"] = true
				od["grow"] = int(o[6])
			if o.size() > 7 and int(o[7]) == 1:
				od["fixed"] = true  # 스토리 울타리 (걷어낼 수 없다)
			if o.size() > 8 and int(o[8]) != 0:
				# 길 위에 누운 나무 (그림만 누워 있다). 1 서쪽 · 2 동쪽
				od["fallen"] = 1.0 if int(o[8]) == 2 else -1.0
			if o.size() > 9 and int(o[9]) == 1:
				od["ore"] = true     # 광석이 박힌 바위
			m.objects[Vector2i(int(o[0]), int(o[1]))] = od
		# 경매 게시판이 생기기 전 세이브 — 광장에 세워 준다
		if not m.objects.has(m.AUCTION_POS):
			m.objects[m.AUCTION_POS] = {"kind": "auction", "hp": 0}
		m.worldgen._migrate_farm_layout()
	# 회관 공동 프로젝트의 가로등·벤치는 위에서 걷혔다 — 완성 기록대로 되살린다
	m.village.restore_hall_project_deco()
	# ---- 메인 스토리 12 (숲의 연금술사) ----
	GameData.story12_phase = str(d.get("story12_phase", ""))
	GameData.story12_heard = Array(d.get("story12_heard", []))
	# 개편 전 구세이브: 마을에 입주해 있던 묘연은 깊은 숲 오두막으로
	# 거처를 옮긴다 — 이미 만난 사이니 연금술도 열린 채로 이어진다
	if "alchemist" in GameData.settlers:
		GameData.settlers.erase("alchemist")
		if GameData.settler_homes.has("alchemist"):
			GameData.empty_houses.append(GameData.settler_homes["alchemist"])
			GameData.settler_homes.erase("alchemist")
		if GameData.story12_phase == "":
			GameData.story12_phase = "done"
	if GameData.settler_offer == "alchemist":
		GameData.settler_offer = ""
		GameData.items["settle_letter"] = 0
	if GameData.settler_arrive == "alchemist":
		GameData.settler_arrive = ""
	# 연금술을 이미 써 본(조합법을 아는) 구세이브는 열린 것으로 본다
	if GameData.story12_phase == "" and not d.has("story12_phase") \
			and not GameData.alchemy_known.is_empty():
		GameData.story12_phase = "done"
	# 숨은 길·오두막 복원 (완성 기록이 있으면 다시 세운다)
	if GameData.story12_phase in ["path", "gather", "done"]:
		m.worldgen._spawn_alch_house()
	# ---- 메인 스토리 13 (할머니의 팔찌) ----
	GameData.story13_phase = str(d.get("story13_phase", ""))
	GameData.story13_heard = Array(d.get("story13_heard", []))
	GameData.story12_done_day = int(d.get("story12_done_day", 0))
	# ---- 메인 스토리 14 (마을의 첫 축제) · 15 (마른 온천) ----
	GameData.story14_phase = str(d.get("story14_phase", ""))
	GameData.story13_done_day = int(d.get("story13_done_day", 0))
	GameData.story14_tasks = Array(d.get("story14_tasks", []))
	GameData.story14_greet = Array(d.get("story14_greet", []))
	GameData.story14_fest_day = int(d.get("story14_fest_day", 0))
	GameData.story14_toss = bool(d.get("story14_toss", false))
	GameData.story15_phase = str(d.get("story15_phase", ""))
	GameData.story14_done_day = int(d.get("story14_done_day", 0))
	GameData.story15_mobs = int(d.get("story15_mobs", 0))
	GameData.story15_ore = int(d.get("story15_ore", 0))
	GameData.onsen_open = bool(d.get("onsen_open", false))
	GameData.onsen_day = int(d.get("onsen_day", 0))
	if GameData.onsen_open:
		m.worldgen._spawn_onsen()   # 되살린 온천은 로드 후에도 그 자리에
	# ---- 메인 스토리 16 (할머니의 반지) · 17 (할머니의 목걸이) ----
	GameData.story16_phase = str(d.get("story16_phase", ""))
	GameData.story15_done_day = int(d.get("story15_done_day", 0))
	GameData.story16_heard = Array(d.get("story16_heard", []))
	GameData.story16_clear = int(d.get("story16_clear", 0))
	GameData.story16_till = int(d.get("story16_till", 0))
	GameData.story17_phase = str(d.get("story17_phase", ""))
	GameData.story16_done_day = int(d.get("story16_done_day", 0))
	GameData.story17_heard = Array(d.get("story17_heard", []))
	GameData.story17_clear = int(d.get("story17_clear", 0))
	GameData.story17_care = int(d.get("story17_care", 0))
	GameData.story17_done_day = int(d.get("story17_done_day", 0))
	if GameData.story17_phase != "":
		m.worldgen.spawn_old_barn()   # 드러난 옛 헛간은 그 자리에 남는다
	# ---- 메인 스토리 18 (할머니의 시계) · 19 (일곱 갈래의 삶) ----
	GameData.story18_phase = str(d.get("story18_phase", ""))
	GameData.story18_heard = Array(d.get("story18_heard", []))
	GameData.story18_traces = Array(d.get("story18_traces", []))
	GameData.story18_done_day = int(d.get("story18_done_day", 0))
	GameData.story19_phase = str(d.get("story19_phase", ""))
	GameData.story19_shown = Array(d.get("story19_shown", []))
	if GameData.story18_phase in ["hill", "box", "tale", "done"]:
		m.worldgen.spawn_hill()   # 한 번 오른 언덕은 그대로 남는다
	# ---- 메인 스토리 20 (가장 오래된 자리) ----
	GameData.story20_phase = str(d.get("story20_phase", ""))
	GameData.story20_told = Array(d.get("story20_told", []))
	GameData.note_last_line = bool(d.get("note_last_line", false))
	GameData.gate_open = bool(d.get("gate_open", false))
	GameData.seed_day = int(d.get("seed_day", 0))
	GameData.seed_water = bool(d.get("seed_water", false))
	var st20: Array = Array(d.get("seed_tile", [-1, -1]))
	GameData.seed_tile = Vector2i(int(st20[0]), int(st20[1])) if st20.size() == 2 \
		else Vector2i(-1, -1)
	m.worldgen.purge_old_gate()      # 옛 세이브의 돌문 오브젝트를 걷어낸다
	if GameData.seed_tile.x >= 0 and GameData.seed_water:
		m.worldgen.spawn_seed_sprout()   # 돋아난 새싹은 엔딩 뒤에도 남는다
	# 옛 세이브 보정 — 스토리 19가 열리기 전에 받아 둔 생명의 물이 있으면
	# 이야기를 이미 시작한 것으로 본다 (병이 사라지지 않게)
	if GameData.story19_phase == "" and not GameData.water_life_found.is_empty():
		GameData.story19_phase = "seek"
		for wid: String in GameData.water_life_found:
			if wid not in GameData.story19_shown:
				GameData.story19_shown.append(wid)
	# 남쪽 능선·바다·해변은 세이브 값이 아니라 sea_open을 보고 여기서 다시
	# 깐다 (맵 생성은 로드 전에 끝나 있고, 물 타일은 위에서 건너뛰므로)
	m.worldgen._build_sea()
	# 확장 구역이 생기기 전 세이브에서 플레이어가 이제-잠긴 땅에 서 있으면
	# 광장으로 옮겨 준다 (잠긴 구역은 들어갈 수 없다)
	var pt := m.player_tile()
	if not GameData.is_tile_owned(pt.x, pt.y):
		m.player.position = Vector2(78 * m.TILE + 16, 20 * m.TILE + 16)
	# 이어서 하는 사람도 새 계단을 오를 수 있어야 한다.
	#
	# 오브젝트는 통째로 저장된다 — 계단과 층계참 길을 놓기 **전에** 저장한
	# 세계를 열면 그 자리에 옛 나무와 바위가 그대로 되살아난다. 새로 시작한
	# 사람만 깨끗하고 이어서 하는 사람은 길이 막혀 있게 된다.
	m.worldgen.sweep_blocked_nature()
	# 격자가 통째로 바뀌었다 — 「돌아가는 칸」 목록을 다시 만든다
	m.farming.rebuild()


# 발견 기록은 나중에 붙은 것이라, 예전 세이브에는 없다. 이미 겪은 흔적
# (잡은 물고기 · 수확 · 만든 요리 · 들고 있는 것)을 보고 메워 준다.
# 날짜를 알 수 없으니 1일로 적는다 — 「언제인지 모르지만 겪었다」.
func _backfill_discovered() -> void:
	var seen: Array = []
	seen += GameData.fish_caught.keys()
	seen += GameData.crops_harvested.keys()
	seen += GameData.recipes_cooked.keys()
	seen += GameData.forage_caught.keys()
	for id: String in GameData.ITEM_IDS:
		if int(GameData.items.get(id, 0)) > 0:
			seen.append(id)
	for id: String in GameData.CROP_IDS:
		if int(GameData.produce.get(id, 0)) > 0:
			seen.append(id)
	for id in seen:
		if not GameData.discovered.has(id):
			GameData.discovered[id] = 1
