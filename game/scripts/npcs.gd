# NPC — 어디에 세울지와, 거기까지 어떻게 갈지.
#
# 마을 사람은 시간표(`GameData.NPC_SCHEDULE`)를 따라 자리를 옮긴다.
# `_tile_path`는 A*로 칸 단위 길을 낸다 — NPC와 스토리 연출이 함께 쓴다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinNpcs
extends Node

var m: KyojinMain    # main.gd


func _spawn_npc(npc_id: String, tile: Vector2i) -> void:
	var n: Node2D = preload("res://scripts/npc.gd").new()
	n.main = m
	n.id = npc_id
	n.region = m.VILLAGE_REGION
	n.position = Vector2(tile.x * m.TILE + 16, tile.y * m.TILE + 16)
	m.npcs.append(n)
	m.world.add_child(n)


func npc_place_now(npc_id: String) -> String:
	# 축제날에는 일과를 접고 다 같이 축제 자리로 모인다
	var fest: Dictionary = GameData.festival_today()
	if not fest.is_empty() and GameData.minutes >= GameData.FEST_START \
			and GameData.minutes < GameData.FEST_END:
		return str(fest.place)
	# 민지는 노점 시간이 되면 해변으로 내려간다 (하루 3번, 1시간씩)
	if npc_id == "merchant" and GameData.merchant_at_stall():
		return "stall"
	var plan: Array = m.NPC_SCHEDULE.get(npc_id, [])
	if plan.is_empty():
		return ""
	var hour := GameData.minutes / 60.0
	var place: String = plan[0][1]
	for entry: Array in plan:
		if hour >= float(entry[0]):
			place = entry[1]
	return place


func npc_place_tile(npc_id: String, place: String) -> Vector2i:
	var t := Vector2i(-999, -999)
	match place:
		"stall":
			t = m.STALL_TILE + Vector2i(0, 1)   # 노점 앞 모래밭
		"plaza":
			t = m.NPC_PLAZA.get(npc_id, Vector2i(74, 13))
		"board":
			t = m.BOARD_POS + Vector2i(0, 1)
		"pier":
			# 낚시대회 때는 다섯이 한 칸에 겹치지 않게 강가 마당에 나란히 선다
			var i: int = maxi(0, m.NPC_PIER_ORDER.find(npc_id))
			t = Vector2i(m.FISH_YARD_X0 + 2 + i * 3, m.DOCK_Y - 1)
		_:
			# 자기 건물 문 앞 (집도 일터도 같은 건물이다)
			for pid: String in m.VILLAGE_NPC:
				if m.VILLAGE_NPC[pid] == npc_id and GameData.village_built.has(pid):
					t = m.door_tile(m.VILLAGE_PLOTS[pid].anchor) + Vector2i(0, 1)
					break
			if t.x == -999:
				t = m.NPC_HOME.get(npc_id, Vector2i(72, 20))
	if m.is_passable(t):
		return t
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0)]:
		if m.is_passable(t + d):
			return t + d
	return t


func _sync_village_npcs() -> void:
	# 건물이 생기면 그 건물의 주인이 마을에 나타난다 (없는 건물의 주인은 아직 없다)
	for pid: String in m.VILLAGE_NPC:
		if not GameData.village_built.has(pid):
			continue
		var nid: String = m.VILLAGE_NPC[pid]
		if nid == "fisher" and GameData.fisher_quest == "":
			continue  # 낚시꾼은 황금잉어 소문을 듣고 뒤늦게 온다 (상점 완공 뒤 퀘스트)
		var found := false
		for n in m.npcs:
			if n.id == nid:
				found = true
				break
		if found:
			continue
		var a: Vector2i = m.VILLAGE_PLOTS[pid].anchor
		_spawn_npc(nid, Vector2i(a.x + 2, a.y + 4))  # 자기 건물 문 앞

	# 낚시꾼은 자기 건물(수산시장)이 없어도 퀘스트로 마을에 온다
	if GameData.fisher_quest != "":
		var have_fisher := false
		for n in m.npcs:
			if n.id == "fisher":
				have_fisher = true
				break
		if not have_fisher:
			_spawn_npc("fisher", m.FISHER_ARRIVE)

	# 모험가 무진 — 스토리 5로 이사 온다 (건물 없이 광장 언저리에서 지낸다)
	if GameData.forest_quest != "":
		var have_ex := false
		for n in m.npcs:
			if n.id == "explorer":
				have_ex = true
				break
		if not have_ex:
			_spawn_npc("explorer", m.EXPLORER_ARRIVE)

	# 숲속의 모녀 — 집을 찾아간 뒤부터 집 앞 빈터에서 지낸다
	if GameData.forest_quest in ["visit", "done"]:
		for fid: String in ["forest_mom", "forest_girl"]:
			var have_f := false
			for n in m.npcs:
				if n.id == fid:
					have_f = true
					break
			if have_f:
				continue
			_spawn_npc(fid, m.NPC_HOME[fid])
			# 마을이 아니라 숲속 집 둘레만 서성인다
			m.npcs[m.npcs.size() - 1].region = Rect2i(
				m.FOREST_HOUSE_ANCHOR.x - 3, m.FOREST_HOUSE_ANCHOR.y + 3, 12, 5)


func _tile_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return []
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var found := false
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			found = true
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if prev.has(n) or not m.is_passable(n):
				continue
			prev[n] = cur
			queue.append(n)
	if not found:
		return []
	var path: Array = []
	var at := goal
	while at != start:
		path.push_front(Vector2(at.x * m.TILE + 16, at.y * m.TILE + 16))
		at = prev[at]
	return path
