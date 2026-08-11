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
	GameData.story_phase = str(d.get("main_story", "done"))
	GameData.tree_regrow = d.get("tree_regrow", [])
	GameData.player_name = str(d.get("player_name", ""))
	GameData.village_built = d.get("village_built", [])
	GameData.house_lv = int(d.get("house_lv", 0))
	GameData.has_bed = bool(d.get("has_bed", false))
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
	for k in d.get("mob_kills", {}):
		GameData.mob_kills[k] = int(d.mob_kills[k])
	GameData.apply_skills_data(d.get("skills", {}))
	if d.has("furniture"):
		GameData.apply_furniture_data(d.furniture)
		if int(d.get("tile", 16)) != m.TILE:
			for furn in GameData.furniture:  # 구버전 집 좌표(640기준) → 960기준
				furn.x = float(furn.x) * 1.5
				furn.y = float(furn.y) * 1.5
	for k in d.get("recipes_cooked", {}):
		GameData.recipes_cooked[k] = int(d.recipes_cooked[k])
	GameData.owned_pets = d.get("owned_pets", [])
	GameData.active_pet = str(d.get("active_pet", ""))
	for k in d.get("forage_caught", {}):
		GameData.forage_caught[k] = int(d.forage_caught[k])
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
	if d.has("objects"):
		m.objects.clear()
		for o in d.objects:
			var od := {"kind": o[2], "hp": int(o[3])}
			if o.size() > 4 and int(o[4]) == 1:
				od["apple"] = true
			if o.size() > 6 and int(o[5]) == 1:
				od["young"] = true
				od["grow"] = int(o[6])
			if o.size() > 7 and int(o[7]) == 1:
				od["fixed"] = true  # 스토리 울타리 (걷어낼 수 없다)
			m.objects[Vector2i(int(o[0]), int(o[1]))] = od
		m.worldgen._migrate_farm_layout()
