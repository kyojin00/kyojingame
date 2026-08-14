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


func save_now() -> void:
	if Net.is_guest():
		return  # 저장은 호스트만
	var g := []
	for y in m.MAP_H:
		var row := []
		for x in m.MAP_W:
			var c: Dictionary = m.grid[y][x]
			row.append([c.ground, int(c.wet_min), c.crop_id, int(c.crop_day),
				1 if c.dead else 0, 1 if c.get("half_fed", false) else 0])
		g.append(row)
	var objs := []
	for pos: Vector2i in m.objects:
		objs.append([pos.x, pos.y, m.objects[pos].kind, m.objects[pos].hp,
			1 if m.objects[pos].get("apple", false) else 0,
			1 if m.objects[pos].get("young", false) else 0,
			int(m.objects[pos].get("grow", 0)),
			1 if m.objects[pos].get("fixed", false) else 0])
	var anims := []
	for a in m.animals:
		anims.append([a.type, a.position.x, a.position.y, 1 if a.fed else 0])
	GameData.save_game(g, m.player.position, objs, anims)


func _apply_save(d: Dictionary) -> void:
	GameData.day = int(d.day)
	GameData.minutes = float(d.minutes)
	GameData.money = int(d.money)
	GameData.energy = float(d.energy)
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
	}
	GameData.story_phase = str(d.get("main_story", "done"))
	GameData.tree_regrow = d.get("tree_regrow", [])
	GameData.player_name = str(d.get("player_name", ""))
	GameData.village_built = d.get("village_built", [])
	GameData.house_lv = int(d.get("house_lv", 0))
	GameData.has_bed = bool(d.get("has_bed", false))
	GameData.desk_lv = int(d.get("desk_lv", 0))
	# 침대 등급이 생기기 전 세이브: 만들어 둔 침대는 나무 침대(100%)로 쳐 준다
	GameData.bed_lv = int(d.get("bed_lv", 1 if GameData.has_bed else 0))
	GameData.dust_swept = int(d.get("dust_swept", 0))
	GameData.fisher_quest = str(d.get("fisher_quest", ""))
	GameData.fisher_choice = int(d.get("fisher_choice", 0))
	GameData.sea_open = bool(d.get("sea_open", false))
	GameData.merchant_errand = str(d.get("merchant_errand", ""))
	GameData.merchant_day = int(d.get("merchant_day", 0))
	GameData.stall_hours = (d.get("stall_hours", []) as Array)
	GameData.forest_quest = str(d.get("forest_quest", ""))
	GameData.forest_day = int(d.get("forest_day", 0))
	GameData.move_quest = str(d.get("move_quest", ""))
	GameData.move_day = int(d.get("move_day", 0))
	var mh: Array = d.get("move_house", [])
	GameData.move_house = Vector2i(int(mh[0]), int(mh[1])) if mh.size() == 2 \
		else Vector2i(-999, -999)
	GameData.home_plots = (d.get("home_plots", []) as Array)
	# 이사 편지(스토리 3)가 생기기 전 세이브: 무진이 이미 마을에 있으면
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
	GameData.mom_quest = str(d.get("mom_quest", ""))
	GameData.mom_quests_done = (d.get("mom_quests_done", []) as Array)
	GameData.spear_quest = str(d.get("spear_quest", ""))
	if GameData.spear_quest == "visit":
		GameData.spear_quest = "pending"   # 걸어오다 저장했으면 다시 걸어온다
	GameData.chief_house_lv = int(d.get("chief_house_lv", 0))
	GameData.story4_phase = str(d.get("story4_phase", ""))
	GameData.zones_open = d.get("zones_open", [])
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
	# 주인들은 인사를 마친 것으로 친다 (무진도 이사가 끝났으면 마찬가지)
	if not d.has("npc_greeted"):
		for pid: String in GameData.village_built:
			var owner := str(m.VILLAGE_NPC.get(pid, ""))
			if owner != "" and owner not in GameData.npc_greeted:
				GameData.npc_greeted.append(owner)
		if GameData.move_quest == "done" \
				and "explorer" not in GameData.npc_greeted:
			GameData.npc_greeted.append("explorer")
	# 인사만 남기고 저장한 세이브: 무진이 다시 찾아오도록 대기열에 태운다
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
	# 발견한 것으로 친다 — 쓰던 부엌이 갑자기 먼지에 묻히면 안 된다
	GameData.kitchen_found = bool(d.get("kitchen_found",
		int(d.get("house_lv", 0)) >= 2 or not d.get("recipes_cooked", {}).is_empty()))
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

	# 맵 크기가 다른 옛 저장이면 밭 상태는 버리고 진행 상황만 복원한다
	var g: Array = d.grid
	if g.size() != m.MAP_H or (g.size() > 0 and g[0].size() != m.MAP_W):
		m.player.position = Vector2(m.START_TILE.x * m.TILE + 16, m.START_TILE.y * m.TILE + 16)
		return
	for y in m.MAP_H:
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
	for y in m.MAP_H:
		for x in m.MAP_W:
			var cell: Dictionary = m.grid[y][x]
			if cell.ground in ["path", "dock"]:
				cell.ground = "grass"
	if d.has("objects"):
		m.objects.clear()
		for o in d.objects:
			if str(o[2]) in ["deco_lamp", "deco_bench"]:
				continue   # 가로등·벤치는 없앴다 — 옛 세이브에서 걷어 낸다
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
			m.objects[Vector2i(int(o[0]), int(o[1]))] = od
		# 경매 게시판이 생기기 전 세이브 — 광장에 세워 준다
		if not m.objects.has(m.AUCTION_POS):
			m.objects[m.AUCTION_POS] = {"kind": "auction", "hp": 0}
		m.worldgen._migrate_farm_layout()
	# 남쪽 능선·바다·해변은 세이브 값이 아니라 sea_open을 보고 여기서 다시
	# 깐다 (맵 생성은 로드 전에 끝나 있고, 물 타일은 위에서 건너뛰므로)
	m.worldgen._build_sea()
	# 확장 구역이 생기기 전 세이브에서 플레이어가 이제-잠긴 땅에 서 있으면
	# 광장으로 옮겨 준다 (잠긴 구역은 들어갈 수 없다)
	var pt := m.player_tile()
	if not GameData.is_tile_owned(pt.x, pt.y):
		m.player.position = Vector2(78 * m.TILE + 16, 20 * m.TILE + 16)
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
