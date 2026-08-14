# 세계를 짓는 쪽 — 지형·길·마을 부지·자원 재생.
#
# 「한 번 깔고 나면 끝」인 일들을 모았다. 새 게임을 시작할 때 한 번, 그리고
# 하루가 지날 때 자원을 되살릴 때 부른다. 매 프레임 도는 것은 여기 없다.
#
# 규칙 하나: **길은 걸어 다닐 수 있는 곳에만 있어야 한다.** 건물 그림에
# 가려 지나갈 수 없게 된 칸은 길로 두지 않는다 (_trim_paths_under_building).
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinWorldGen
extends Node

var m: KyojinMain    # main.gd


# ---- 맵 ----

func _build_map() -> void:
	m.grid = []
	m.objects = {}
	for y in m.MAP_H:
		var row := []
		for x in m.MAP_W:
			# crop_day = 누적 성장 시간(게임 분), wet_min = 남은 젖음 시간(게임 분)
			row.append({"ground": "grass", "watered": false, "wet_min": 0.0,
				"crop_id": "", "crop_day": 0.0, "dead": false, "half_fed": false})
		m.grid.append(row)

	# 연못들 (숲/깊은 숲) — 시작 부지의 연못은 없앴다
	for y in range(28, 35):
		for x in range(45, 53):
			m.grid[y][x].ground = "water"
	# (호수는 마을 서쪽 낚시터가 됐다 — 마을을 가르던 강은 전부 없앴다)
	for y in range(48, 54):          # 깊은 숲 연못
		for x in range(70, 79):
			m.grid[y][x].ground = "water"

	_build_village()

	# 농장 -> 마을 이음새는 잔디 그대로 둔다 (흙길은 깔지 않는다 —
	# 바닥 타일은 앞으로 플레이어가 직접 깐다. m.ROAD 직사각형은
	# 자연물이 스폰되지 않는 통행로로 계속 쓰인다)

	# 동굴 (출하 상자는 없앴다 — 판매는 마을 잡화점에서 한다)
	m.objects[m.CAVE_POS] = {"kind": "cave", "hp": 0}
	m.objects[m.WORLDTREE_POS] = {"kind": "worldtree", "hp": 0}

	# 세계의 끝을 두르는 나무 (그림 폭에 맞춰 4칸 간격 — 서로 겹치지 않는다)
	for x in m.MAP_W:
		if x % 4 == 0 and not m.objects.has(Vector2i(x, 0)):
			m.objects[Vector2i(x, 0)] = {"kind": "tree", "hp": m.TREE_HP}
		if x % 4 == 0:
			m.objects[Vector2i(x, m.MAP_H - 1)] = {"kind": "tree", "hp": m.TREE_HP}
	for y in m.MAP_H:
		if y % 4 == 0 and not m.objects.has(Vector2i(0, y)):
			m.objects[Vector2i(0, y)] = {"kind": "tree", "hp": m.TREE_HP}
		if y % 4 == 0 and not m.objects.has(Vector2i(m.MAP_W - 1, y)):
			m.objects[Vector2i(m.MAP_W - 1, y)] = {"kind": "tree", "hp": m.TREE_HP}

	# 흩어진 나무/돌 (결정적 해시 배치, 남동쪽 깊은 숲은 더 빽빽하게)
	var deep_rect := Rect2i(45, 40, 45, 20)
	for y in range(1, m.MAP_H - 1):
		for x in range(1, m.MAP_W - 1):
			var pos := Vector2i(x, y)
			if m.objects.has(pos) or m.grid[y][x].ground != "grass":
				continue
			if x >= 1 and x <= 10 and y >= 0 and y <= 6:
				continue  # 축사 주변은 비워둔다
			if abs(x - m.START_TILE.x) <= 3 and abs(y - m.START_TILE.y) <= 3:
				continue  # 시작 지점 주변도 비워둔다
			if m.VILLAGE_REGION.has_point(pos) or m.ROAD.has_point(pos):
				continue  # 마을/길은 비워둔다
			var h := m._hash01(x * 3 + 7, y * 5 + 11)
			if deep_rect.has_point(pos):
				# 깊은 숲은 나무를 많이 두되, 그림이 겹치지 않는 선까지만 채운다
				if h < 0.30:
					if _nature_clear(pos, "tree"):
						m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP}
				elif h < 0.40:
					if _nature_clear(pos, "rock"):
						m.objects[pos] = {"kind": "rock", "hp": m.ROCK_HP}
			elif h < 0.06:
				if _nature_clear(pos, "tree"):
					m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP}
			elif h < 0.12:
				if _nature_clear(pos, "rock"):
					m.objects[pos] = {"kind": "rock", "hp": m.ROCK_HP}

	# 낚시터 둘레는 마지막에 비운다 — 나무/돌 그림이 부두와 강을 덮으면 안 된다.
	# (자연물 배치가 모두 끝난 뒤라야 확실히 비워진다)
	for p: Vector2i in m.objects.keys():
		if m.FISH_CLEAR.has_point(p):
			m.objects.erase(p)
	m.objects[m.FISH_SIGN] = {"kind": "sign", "hp": 0}
	# 온실 터 표지판 (농장 한켠) — 온실 자리는 자연물을 비워 둔다
	for gy in range(m.GREENHOUSE.position.y, m.GREENHOUSE.end.y):
		for gx in range(m.GREENHOUSE.position.x, m.GREENHOUSE.end.x):
			m.objects.erase(Vector2i(gx, gy))
	m.objects[m.GREENHOUSE_SIGN] = {"kind": "sign", "hp": 0}
	if GameData.has_horse and not GameData.riding:
		m.objects[GameData.horse_tile] = {"kind": "horse", "hp": 0}
	if GameData.greenhouse_built:
		for gy2 in range(m.GREENHOUSE.position.y, m.GREENHOUSE.end.y):
			for gx2 in range(m.GREENHOUSE.position.x, m.GREENHOUSE.end.x):
				m.grid[gy2][gx2].ground = "soil"
	# (낚시터의 가로등·벤치도 없앴다)

	_build_sea()


# 남쪽 끝: 바위 능선 너머의 땅. 바다를 열기 전에는 울창한 숲처럼 보이고,
# 낚시꾼 퀘스트에서 길목(SEA_GATE) 바위를 캐는 순간 바다·해변이 드러난다.
# 로드 후에도 다시 불러 남쪽 지형을 결정적으로 맞춘다 (구세이브 보정).
func _build_sea() -> void:
	if GameData.sea_open:
		for y in range(m.SEA_Y0, m.MAP_H):
			for x in m.MAP_W:
				m.grid[y][x].ground = "water"
				m.objects.erase(Vector2i(x, y))
		for y in range(m.BEACH_Y0, m.SEA_Y0):
			for x in m.MAP_W:
				m.grid[y][x].ground = "sand"
				m.objects.erase(Vector2i(x, y))
	else:
		# 아직 바다를 모른다 — 능선 너머는 빽빽한 숲으로 가려 둔다
		for y in range(m.BEACH_Y0, m.MAP_H):
			for x in range(1, m.MAP_W - 1):
				var pos := Vector2i(x, y)
				if m.objects.has(pos) or m.grid[y][x].ground != "grass":
					continue
				if m._hash01(x * 11 + 1, y * 7 + 5) < 0.5 and _nature_clear(pos, "tree"):
					m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP}
	for x in m.MAP_W:
		var p := Vector2i(x, m.SEA_RIDGE_Y)
		m.objects.erase(p)
		if p in m.SEA_GATE:
			continue
		m.objects[p] = {"kind": "searock", "hp": 0}
	for p: Vector2i in m.SEA_GATE:
		if not GameData.sea_open and not m.objects.has(p):
			m.objects[p] = {"kind": "bigrock", "hp": m.BIGROCK_HP, "fixed": true}
	if GameData.sea_open:
		var have := false
		for pos in m.objects:
			if String(m.objects[pos].kind) in m.BEACH_FORAGE:
				have = true
				break
		if not have:
			_seed_beach_forage(false)   # 노드는 뒤이어 _spawn_objects가 만든다
		_place_stall(false)


# 길이 열리는 순간 능선 너머가 드러난다 — 숲을 걷어내고 바다와 모래사장을 깐다
func _reveal_sea() -> void:
	GameData.sea_open = true
	for y in range(m.BEACH_Y0, m.MAP_H):
		for x in m.MAP_W:
			var pos := Vector2i(x, y)
			m.objnode._remove_object(pos)
			m.grid[y][x].ground = "water" if y >= m.SEA_Y0 else "sand"
	_seed_beach_forage()
	_place_stall()
	m.queue_redraw()


# 바다를 연 직후/불러온 직후 해변에 조개를 몇 개 깔아 둔다
func _seed_beach_forage(with_node := true) -> void:
	for i in 4:
		_try_spawn_shell(with_node)


func _try_spawn_shell(with_node := true) -> bool:
	var pos := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(m.BEACH_Y0, m.SEA_Y0 - 1))
	if m.objects.has(pos) or m.grid[pos.y][pos.x].ground != "sand":
		return false
	# 기본은 조개(흔함)·비닐봉지·유리 조각·금속 고리.
	# 산호 조각·고대 조각은 각각 기본 0.1%의 매우 희귀한 채집물 —
	# 해변 채집 레벨이 오르면 확률이 조금씩 오른다 (beach_rare_chance).
	var kind := "forage_shell"
	var rare := GameData.beach_rare_chance()
	var roll := randf()
	if roll < rare:
		kind = "forage_coral"
	elif roll < rare * 2.0:
		kind = "forage_relic"
	else:
		var r2 := randf()
		if r2 < 0.15:
			kind = "forage_trash"
		elif r2 < 0.30:
			kind = "forage_glass"
		elif r2 < 0.45:
			kind = "forage_ring"
	if with_node:
		m.objnode._place_object(pos, kind, 0)
	else:
		m.objects[pos] = {"kind": kind, "hp": 0}
	return true


# 민지의 해변 노점 — 서브 퀘스트를 끝냈으면 늘 이 자리에 서 있다.
# 바다를 다시 까는 코드(_build_sea/_reveal_sea)가 해변을 통째로 밀기 때문에
# 그때마다 여기서 도로 세워 준다 (세이브 로드 후에도 이 경로로 복원된다).
func _place_stall(with_node := true) -> void:
	if GameData.merchant_errand != "done":
		return
	var cur := str(m.objects.get(m.STALL_TILE, {}).get("kind", ""))
	if cur == "stall":
		return
	if cur != "":
		m.objnode._remove_object(m.STALL_TILE)   # 자리에 밀려온 조개 따위는 치운다
	if with_node:
		m.objnode._place_object(m.STALL_TILE, "stall", 0)
	else:
		m.objects[m.STALL_TILE] = {"kind": "stall", "hp": 0}


# 교진 마을: 건물은 하나도 짓지 않는다.
# 넓은 중앙 광장 + 사방으로 뻗은 길 + 나중에 건물이 들어설 빈 부지만 만든다.
func _build_village() -> void:
	# 흙길은 더 이상 깔지 않는다 — 마을 바닥은 잔디이고, 길·광장 바닥은
	# 앞으로 플레이어가 직접 타일을 깔아 꾸미는 구조로 간다.
	# 광장 한가운데 분수
	for y in range(m.FOUNTAIN.position.y, m.FOUNTAIN.end.y):
		for x in range(m.FOUNTAIN.position.x, m.FOUNTAIN.end.x):
			m.grid[y][x].ground = "water"

	# (마을을 가르던 강과 다리는 전부 없앴다 — 물을 걷어낸 자리는
	#  잔디로 이어지고, 낚시터는 서쪽 호수로 옮겼다)

	# 마을 건물은 처음부터 다 서 있다 — 칸과 마당을 여기서 만든다
	for pid: String in GameData.village_built:
		if m.VILLAGE_PLOTS.has(pid):
			_place_building_tiles(m.VILLAGE_PLOTS[pid].anchor)

	# 집터(스토리 1 완료 후 직접 짓는다) + 광장 게시판 + 최소한의 장식
	m.objects[m.HOME_SITE] = {"kind": "housesite", "hp": 0}
	# 이장의 거처 — 처음부터 있는 작고 낡은 오두막 (마을의 유일한 지붕)
	m.objects[m.CHIEF_HUT] = {"kind": "chief_hut", "hp": 0}
	# 상점 터 게시판 — 메인 스토리 2의 첫 퀘스트 (재료를 모아 여기서 짓는다)
	if not GameData.village_built.has("general"):
		m.objects[m.door_tile(m.VILLAGE_PLOTS["general"].anchor)] = {"kind": "plotsite", "hp": 0}
	m.objects[m.BOARD_POS] = {"kind": "board", "hp": 0}
	# 경매 게시판 — 다른 농장 사람들과 사고파는 장터로 이어진다
	m.objects[m.AUCTION_POS] = {"kind": "auction", "hp": 0}
	m.objects[m.FOUNTAIN_DECO] = {"kind": "deco_fountain", "hp": 0}
	# 동쪽 다리 건너 — 옛 마을의 경계를 알리는 낡은 표지판 (메인 스토리 4)
	m.objects[m.OLD_SIGN] = {"kind": "sign", "hp": 0}
	# (광장의 가로등·벤치는 없앴다 — 밤이 되면 마을도 캄캄하다)
	# 마을 외곽에만 나무를 둔다 (생활 공간 안에는 나무/돌을 두지 않는다)
	for x in range(60, 99):
		for y in [1, 43]:
			var rim := Vector2i(x, y)
			if m.grid[y][x].ground == "grass" and not m.objects.has(rim) \
					and m._hash01(x * 5 + 3, y * 7 + 2) < 0.9 and _nature_clear(rim, "tree"):
				m.objects[rim] = {"kind": "tree", "hp": m.TREE_HP}


# 건물 한 채의 마당: 그림 둘레 한 칸을 잔디로 고르고 울타리를 두른다.
# 문 앞 한 줄만 터 두고, 거기서 가장 가까운 길까지 흙길을 잇는다.
func _build_yard(anchor: Vector2i) -> void:
	var yard := Rect2i(anchor.x - m.YARD_PAD, anchor.y - m.YARD_PAD,
		5 + m.YARD_PAD * 2, 4 + m.YARD_PAD * 2)
	# 마당 안은 잔디 (길이 건물 밑으로 지나가지 않게)
	for y in range(yard.position.y, yard.end.y):
		for x in range(yard.position.x, yard.end.x):
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			m.grid[y][x].ground = "grass"
	# (건물을 감싸던 마당 울타리는 없앴다 — 마당은 잔디로 트여 있다.
	#  문 앞 흙길도 더 이상 내지 않는다 — 바닥 타일은 플레이어 몫이다)


# 자연물은 타일보다 훨씬 크게 그려진다. 그림이 서로 겹치지 않도록,
# 두 오브젝트가 요구하는 간격 중 더 큰 값을 적용해 배치 가능 여부를 판단한다.
func _nature_clear(pos: Vector2i, kind: String, override_dist := -1) -> bool:
	var need_self: int = override_dist if override_dist >= 0 \
		else int(m.NATURE_CLEAR.get(kind, 1))
	for dy in range(-m.NATURE_CLEAR_MAX, m.NATURE_CLEAR_MAX + 1):
		for dx in range(-m.NATURE_CLEAR_MAX, m.NATURE_CLEAR_MAX + 1):
			var p := pos + Vector2i(dx, dy)
			if p == pos or not m.objects.has(p):
				continue
			var k: String = m.objects[p].kind
			if not m.NATURE_CLEAR.has(k):
				continue
			if override_dist < 0 and (kind == "tree" or k == "tree"):
				# 나무는 "옆으로 나란히" 놓일 때만 지저분하게 겹친다.
				# 앞뒤로 겹치는 건 앞 나무가 뒤를 가려 주므로 깊은 숲처럼 보인다.
				if absi(dx) <= m.TREE_DX and absi(dy) <= m.TREE_DY:
					return false
				continue
			var need: int = need_self if override_dist >= 0 \
				else maxi(need_self, int(m.NATURE_CLEAR[k]))
			if maxi(absi(dx), absi(dy)) <= need:
				return false
	return true


# 건물이 차지하는 칸과 마당만 만든다 (그림 노드는 _spawn_objects가 세운다).
# 맵을 만드는 단계에서는 아직 world 노드가 없으므로 이쪽만 부른다.
func _place_building_tiles(anchor: Vector2i) -> void:
	for y in range(anchor.y, anchor.y + 4):
		for x in range(anchor.x, anchor.x + 5):
			m.objects[Vector2i(x, y)] = {"kind": "house", "hp": 0}
	m.objects.erase(m.door_tile(anchor))
	_trim_paths_under_building(anchor)
	_build_yard(anchor)


func _fill_building(anchor: Vector2i, kind: String = "") -> void:
	_place_building_tiles(anchor)
	_spawn_house_node(anchor, kind)


# 숲 깊은 곳의 집 (메인 스토리 5) — 이장에게 물어본 순간 세상에 놓인다.
# 빽빽한 스토리 숲(fixed 나무)을 걷어 내고 오솔길을 깐 뒤 집을 세운다.
func _spawn_forest_house() -> void:
	var a: Vector2i = m.FOREST_HOUSE_ANCHOR
	if str(m.objects.get(a, {}).get("kind", "")) == "house":
		return
	# 집터 빈터
	for y in range(a.y - 2, a.y + 6):
		for x in range(a.x - 3, a.x + 9):
			m.objnode._remove_object(Vector2i(x, y))
	# 숲길(y18) 남쪽에서 문 앞까지 내려오는 좁은 오솔길
	for y in range(m.STORY_ROAD_Y1 + 1, a.y + 5):
		for x in [m.FOREST_TRAIL_X, m.FOREST_TRAIL_X + 1]:
			m.objnode._remove_object(Vector2i(x, y))
			if m.grid[y][x].ground == "grass":
				m.grid[y][x].ground = "path"
	_fill_building(a)
	m.objects.erase(m.door_tile(a))
	m.queue_redraw()


# 연금술사의 오두막 (메인 스토리 12) — 소문을 다 모은 순간 세상에 놓인다.
# 깊은 숲 덤불을 걷어 내고 숨은 오솔길을 낸 뒤 오두막을 세운다.
# (플레이어가 세운 집·집터는 건드리지 않는다)
func _spawn_alch_house() -> void:
	var a: Vector2i = m.ALCH_HOUSE_ANCHOR
	if str(m.objects.get(a, {}).get("kind", "")) == "house":
		return
	for y in range(a.y - 2, a.y + 6):
		for x in range(a.x - 3, a.x + 9):
			var p := Vector2i(x, y)
			if m.objects.has(p) \
					and str(m.objects[p].get("kind", "")) in ["homeplot", "house"]:
				continue
			m.objnode._remove_object(p)
	# 문 앞에서 남쪽으로 빠지는 좁은 숨은 길 — 덤불에 가려 있던 오솔길
	var door := m.door_tile(a)
	for y2 in range(a.y + 4, mini(a.y + 11, m.MAP_H - 1)):
		for x2 in [door.x, door.x + 1]:
			m.objnode._remove_object(Vector2i(x2, y2))
			if m.grid[y2][x2].ground == "grass":
				m.grid[y2][x2].ground = "path"
	_fill_building(a)
	m.objects.erase(m.door_tile(a))
	m.queue_redraw()


# 마을 온천 (메인 스토리 15) — 수맥을 되살리면 바위 탕에 물이 찬다.
# 오브젝트 하나로 서고, 둘레 한 칸은 드나들 수 있게 비워 둔다.
func _spawn_onsen() -> void:
	var t: Vector2i = m.ONSEN_POS
	if str(m.objects.get(t, {}).get("kind", "")) == "onsen":
		return
	for y in range(t.y - 1, t.y + 2):
		for x in range(t.x - 1, t.x + 2):
			m.objnode._remove_object(Vector2i(x, y))
	m.objnode._place_object(t, "onsen", 0)
	m.queue_redraw()


func _trim_paths_under_building(anchor: Vector2i) -> void:
	var door := m.door_tile(anchor)
	for y in range(anchor.y - 2, anchor.y + 4):
		for x in range(anchor.x - 1, anchor.x + 6):
			var pos := Vector2i(x, y)
			if pos == door or x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			if m.objects.has(pos) and m.BUILDING_KINDS.has(m.objects[pos].kind):
				m.grid[y][x].ground = "grass"


# kind: VILLAGE_PLOTS의 열쇠("post"/"smith"...). 빈 값이면 살림집.
func _spawn_house_node(anchor: Vector2i, kind: String = "") -> void:
	if m.obj_nodes.has(anchor):
		m.obj_nodes[anchor].queue_free()   # 다시 세워도 낡은 그림이 겹치지 않게
	var tname := "house_" + kind
	if kind == "" or not m.tex.has(tname):
		tname = "house"
	# 그림은 512x410이고 0.5배로 그려 화면에서는 256 x 205(8 x 6.4칸)를 덮는다.
	# 다른 오브젝트와 같은 2:1 축소라 점이 흔들리지 않는다.
	var hn: Node2D = m.objnode._make_object(m.tex[tname],
		Vector2(anchor.x * m.TILE, (anchor.y + 4) * m.TILE), Vector2(0, -410))
	var hspr: Sprite2D = hn.get_child(0)
	hspr.scale = Vector2(0.5, 0.5)
	hspr.offset.x = -96.0
	m.obj_nodes[anchor] = hn
	m.world.add_child(hn)
	# 집 그림은 5x4칸보다 크게 그려진다 (양옆 1칸, 위 2칸 더 덮는다).
	# 그 칸도 막아 두지 않으면 벽 안쪽으로 걸어 들어가진다.
	_block_under_art(Rect2i(anchor.x - 1, anchor.y - 2, 7, 6),
		Rect2i(anchor.x, anchor.y, 5, 4))


# 그림이 덮는 칸(area) 중 건물 본체(core)가 아닌 칸을 보이지 않는 벽으로 막는다.
# 이미 다른 것이 놓인 칸은 건드리지 않는다.
func _block_under_art(area: Rect2i, core: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var pos := Vector2i(x, y)
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			if core.has_point(pos) or m.objects.has(pos):
				continue
			m.objects[pos] = {"kind": "art_block", "hp": 0, "fixed": true}


# 축사 그림이 덮는 칸을 막는다 (그림 안으로 걸어 들어가지 않게).
# 그림 크기가 바뀌면 BARN_ART만 고치면 된다.
func _block_barn_art() -> void:
	_block_under_art(Rect2i(m.BARN_POS + m.BARN_ART.position, m.BARN_ART.size),
		Rect2i(m.BARN_POS, Vector2i.ONE))


# 나무 성장: 어린 나무(tree_15)는 며칠 지나면 다 자란 나무(tree_01)가 되고,
# 벤 자리에는 다음 날 어린 나무가 돋아 다시 자란다.
func _advance_tree_growth() -> void:
	for pos: Vector2i in m.objects:
		var o: Dictionary = m.objects[pos]
		if o.kind == "tree" and bool(o.get("young", false)):
			o["grow"] = int(o.get("grow", 2)) - 1
			if int(o.grow) <= 0:
				o.erase("young")
				o.erase("grow")
			m.objnode._refresh_tree_sprite(pos)
	var keep := []
	for e in GameData.tree_regrow:
		var pos := Vector2i(int(e[0]), int(e[1]))
		var days := int(e[2]) - 1
		if days > 0:
			keep.append([pos.x, pos.y, days])
			continue
		# 자리가 비어 있고 밭/작물이 아니면 어린 나무가 돋는다 (차 있으면 소멸)
		if not m.objects.has(pos) and m.grid[pos.y][pos.x].ground == "grass" \
				and m.grid[pos.y][pos.x].crop_id == "":
			m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP, "young": true, "grow": 2}
			m.objnode._spawn_object_node(pos, "tree")
			m.objnode._refresh_tree_sprite(pos)
	GameData.tree_regrow = keep


# 자연물 상한 — 리젠이 맵을 가득 채우지 않게 종류별로 막는다
const NATURE_CAP := {"tree": 260, "rock": 120, "weed": 70}
# 자연물이 절대 나면 안 되는 곳 — 스토리 숲길(길목이 도로 막히면 안 된다)
const NO_SPAWN_RECTS: Array[Rect2i] = [Rect2i(3, 12, 45, 9)]


# 이 칸에 자연물이 나도 되는가 — 나무/돌/잡초가 전부 같은 검사를 쓴다.
# 건물·문 앞·통행로·농작물·설치물·다른 자연물·물가를 전부 피한다.
func _respawn_ok(pos: Vector2i, kind: String) -> bool:
	if pos.x < 1 or pos.y < 1 or pos.x >= m.MAP_W - 1 or pos.y >= m.MAP_H - 1:
		return false
	var cell: Dictionary = m.grid[pos.y][pos.x]
	if m.objects.has(pos) or cell.ground != "grass" or str(cell.crop_id) != "":
		return false
	if m.VILLAGE_REGION.has_point(pos) or m.ROAD.has_point(pos) \
			or m.FISH_CLEAR.has_point(pos) or m.GREENHOUSE.has_point(pos):
		return false  # 마을·큰길·낚시터 어귀·온실 터에는 나지 않는다
	for r: Rect2i in NO_SPAWN_RECTS:
		if r.has_point(pos):
			return false
	# 마을 밖 집(무진의 집·숲속의 집·연금술사의 오두막) 문 앞도 비워 둔다
	for anchor: Vector2i in [GameData.move_house, m.FOREST_HOUSE_ANCHOR,
			m.ALCH_HOUSE_ANCHOR]:
		if anchor.x >= 0 and (pos - m.door_tile(anchor)).length() < 3.0:
			return false
	if (pos - m.player_tile()).length() < 4.0:
		return false
	if not _nature_clear(pos, kind if kind != "weed" else "rock"):
		return false  # 이웃 자연물과의 간격 — 통로가 통째로 막히지 않는다
	return true


func _nature_count(kind: String) -> int:
	var n := 0
	for pos in m.objects:
		if String(m.objects[pos].kind) == kind:
			n += 1
	return n


# 아침 리젠 — 캐서 없앤 나무/돌/잡초가 3~5일 뒤(respawn_queue),
# 맵의 「빈자리 검사」를 통과한 랜덤 위치에서 새로 자란다.
# 잡초는 그와 별개로 시간이 지나면 저절로도 돋는다 (상한 안에서).
func _respawn_resources() -> void:
	var keep: Array = []
	for e in GameData.respawn_queue:
		if int(e.due) > GameData.day:
			keep.append(e)
			continue
		var kind := str(e.kind)
		if _nature_count(kind) >= int(NATURE_CAP.get(kind, 999)):
			continue   # 이미 빽빽하다 — 이 리젠은 조용히 사라진다
		var placed := false
		for attempt in 30:
			var pos := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.MAP_H - 2))
			if not _respawn_ok(pos, kind):
				continue   # 못 놓는 자리면 강제하지 않고 다른 자리를 다시 찾는다
			m.objnode._place_object(pos, kind,
				m.TREE_HP if kind == "tree" else (m.ROCK_HP if kind == "rock" else 0))
			placed = true
			break
		if not placed:
			e["due"] = GameData.day + 1   # 오늘은 자리가 없다 — 내일 다시
			keep.append(e)
	GameData.respawn_queue = keep
	# 잡초 자연 발생 — 아침마다 서너 포기씩 무성하게 돋는다 (같은 검사로)
	var weed_sprouts := 0
	for attempt in 18:
		if weed_sprouts >= 3 or _nature_count("weed") >= int(NATURE_CAP["weed"]):
			break
		var pos2 := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.MAP_H - 2))
		if _respawn_ok(pos2, "weed"):
			m.objnode._place_object(pos2, "weed", 0)
			weed_sprouts += 1


# 아침마다 열매/약초가 풀밭에 돋아난다 (최대 12개 유지)
func _respawn_forage() -> void:
	# 안개 낀 날은 발밑이 잘 보인다 — 채집물이 훨씬 많이 돋는다
	var fog: bool = m.weather_now() == GameData.WEATHER_FOG
	var cap := m.FORAGE_CAP_FOG if fog else m.FORAGE_CAP
	var tries := 20 if fog else 8
	var count := 0
	for pos in m.objects:
		if String(m.objects[pos].kind).begins_with("forage_"):
			count += 1
	for attempt in tries:
		if count >= cap:
			break
		var pos := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.MAP_H - 2))
		var cell: Dictionary = m.grid[pos.y][pos.x]
		if m.objects.has(pos) or cell.ground != "grass" or cell.crop_id != "":
			continue
		if m.VILLAGE_REGION.has_point(pos) or m.ROAD.has_point(pos):
			continue
		# 산딸기 절반 · 약초 셋 중 하나 · 잡초 나머지 (화분 재료라 흔하게)
		var roll := randf()
		var kind := "forage_berry" if roll < 0.5 \
			else ("forage_herb" if roll < 0.8 else "weed")
		m.objnode._place_object(pos, kind, 0)
		count += 1


# 조개 리젠 한 번 (main이 게임 시간 10~15분마다 부른다 — 해변 채집 레벨을
# 올리면 빨라진다). 줍지 않고 두면 상한에서 멈추고 더 쌓이지 않는다.
func _tick_beach() -> void:
	var shells := 0
	for pos in m.objects:
		if String(m.objects[pos].kind) in m.BEACH_FORAGE:
			shells += 1
	if shells >= m.SHELL_CAP:
		return
	for attempt in 10:
		if _try_spawn_shell():
			return


func _spawn_bugs() -> void:
	for bnode in m.bugs:
		bnode.queue_free()
	m.bugs.clear()
	# 별밤에는 「빛을 품은 것」이 계절을 가리지 않고 잔뜩 나온다 (연금술 빛 재료)
	var starry: bool = m.weather_now() == GameData.WEATHER_STAR
	for bid in GameData.BUGS:
		var cond: Dictionary = GameData.BUGS[bid]
		var light_bug: bool = bid == "bug_firefly"
		if GameData.season() not in cond.seasons and not (starry and light_bug):
			continue
		for i in (m.STAR_FIREFLY_COUNT if (starry and light_bug) else 3):
			var bnode: Node2D = preload("res://scripts/bug.gd").new()
			bnode.main = m
			bnode.bug_id = bid
			bnode.night_only = bool(cond.night)
			bnode.position = Vector2(randi_range(2, m.MAP_W - 2) * m.TILE,
				randi_range(2, m.MAP_H - 2) * m.TILE)
			m.bugs.append(bnode)
			m.world.add_child(bnode)


# 옛 저장 정리: 축사를 크게 다시 그리면서 자리를 옮겼고,
# 농장의 출하 상자는 아예 없앴다 (판매는 마을 잡화점에서 한다).
# 오브젝트는 통째로 저장되므로, 불러올 때 한 번 자리를 맞춰 준다.
func _migrate_farm_layout() -> void:
	const OLD_BARN := Vector2i(10, 3)
	const OLD_BARN_ART := Rect2i(9, 2, 4, 2)
	for p: Vector2i in m.objects.keys():
		var kind: String = m.objects[p].kind
		if kind == "bin" or kind == "barn" or kind == "barn_block":
			m.objects.erase(p)
		elif kind == "art_block" and OLD_BARN_ART.has_point(p) and p != OLD_BARN:
			m.objects.erase(p)
	if GameData.barn_built:
		m.objects[m.BARN_POS] = {"kind": "barn", "hp": 0}
		_block_barn_art()
		# 새 축사 그림 자리에 서 있던 세이브라면 밖으로 꺼내 준다 (갇히지 않게)
		if not m.is_passable(m.player_tile()):
			var out: Vector2i = m.riding._free_spot_near(m.BARN_POS + Vector2i(0, 2))
			m.player.position = Vector2(out.x * m.TILE + 16, out.y * m.TILE + 16)
