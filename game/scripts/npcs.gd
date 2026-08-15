# NPC — 어디에 세울지와, 거기까지 어떻게 갈지.
#
# 마을 사람은 시간표(`GameData.NPC_SCHEDULE`)를 따라 자리를 옮긴다.
# `_tile_path`는 A*로 칸 단위 길을 낸다 — NPC와 스토리 연출이 함께 쓴다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinNpcs
extends Node

var m: KyojinMain    # main.gd


# 온천이 열리면 저녁마다 몸을 담그러 가는 사람들 (메인 스토리 15)
const ONSEN_GOERS := ["blacksmith", "chief", "merchant"]


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
	# 용식은 집터 부탁을 꺼낼 때까지 하루 종일 분수대 앞에 서 있다
	if npc_id == "fisher" and GameData.fisher_home in ["wait", "built"]:
		return "fountain"
	# 만수는 노점 시간이 되면 해변으로 내려간다 (하루 3번, 1시간씩)
	if npc_id == "merchant" and GameData.merchant_at_stall():
		return "stall"
	# 온천이 되살아나면 저녁에 몸을 담그러 가는 사람들이 생긴다 (스토리 15)
	if GameData.onsen_open and npc_id in ONSEN_GOERS:
		var oh := GameData.minutes / 60.0
		if oh >= 17.0 and oh < 19.5:
			return "onsen"
	# 마을회관이 서면 이장은 낮(9~17시)에 회관에서 업무를 본다 (집은 그대로)
	if npc_id == "chief" and GameData.village_built.has("hall"):
		var hh := GameData.minutes / 60.0
		if hh >= 9.0 and hh < 17.0:
			return "hallwork"
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
		"hallwork":
			t = m.door_tile(m.VILLAGE_PLOTS["hall"].anchor) + Vector2i(0, 1)
		"onsen":
			# 온천 앞 — 셋이 겹치지 않게 한 칸씩 벌려 선다
			var oi: int = maxi(0, ONSEN_GOERS.find(npc_id))
			t = m.ONSEN_POS + Vector2i(oi - 1, 2)
		"fountain":
			t = Vector2i(m.FOUNTAIN.position.x + 1, m.FOUNTAIN.end.y + 1)
		"plaza":
			t = m.NPC_PLAZA.get(npc_id, Vector2i(74, 13))
		"board":
			t = m.BOARD_POS + Vector2i(0, 1)
		"pier":
			# 낚시대회 때는 다섯이 한 칸에 겹치지 않게 호수 남쪽 물가에 선다
			var i: int = maxi(0, m.NPC_PIER_ORDER.find(npc_id))
			t = Vector2i(m.FISH_YARD_X0 + 2 + i * 2, m.DOCK_Y + 1)
		_:
			# 제 집을 얻은 사람은 「집」 시간대에 그 집으로 돌아간다 (용식의 집)
			if place == "home" and GameData.settler_homes.has(npc_id):
				var mh: Array = GameData.settler_homes[npc_id]
				t = m.door_tile(Vector2i(int(mh[0]), int(mh[1]))) + Vector2i(0, 1)
				if m.is_passable(t):
					return t
			# 자기 건물 문 앞 (집도 일터도 같은 건물이다)
			for pid: String in m.VILLAGE_NPC:
				if m.VILLAGE_NPC[pid] == npc_id and GameData.village_built.has(pid):
					t = m.door_tile(m.VILLAGE_PLOTS[pid].anchor) + Vector2i(0, 1)
					break
			# 이사 온 주민은 집터에 지은 자기 집이 곧 거처다
			if t.x == -999 and GameData.settler_homes.has(npc_id):
				var sh: Array = GameData.settler_homes[npc_id]
				t = m.door_tile(Vector2i(int(sh[0]), int(sh[1]))) + Vector2i(0, 1)
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
		if nid != "fisher" and not GameData.npc_greeted.has(nid):
			continue  # 이사 온 다음 날 첫 인사를 나눠야 마을에 자리 잡는다
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

	# 모험가 재민 — 이주 편지(스토리 3)로 이사 온다. 자기 집(플레이어가
	# 지어 준 자리) 앞에서 스폰되고, 마을을 자유롭게 쏘다닌다.
	if GameData.move_quest in ["greet", "done"] or GameData.forest_quest != "":
		var have_ex := false
		for n in m.npcs:
			if n.id == "explorer":
				have_ex = true
				break
		if not have_ex:
			var ex_spawn: Vector2i = m.EXPLORER_ARRIVE
			if GameData.move_house.x >= 0:
				ex_spawn = m.door_tile(GameData.move_house) + Vector2i(0, 1)
			_spawn_npc("explorer", ex_spawn)

	# 사서 서하 — 오래된 책을 보러 온 방문객 (스토리 6).
	# 도서관이 완성되고 정착 대화를 마쳐야 정식 주민이 된다 —
	# 그 전에는 건물 없이도 광장 근처에서 지내는 손님이다.
	if GameData.story6_phase in ["visit", "told", "build", "done"]:
		var have_lib := false
		for n in m.npcs:
			if n.id == "librarian":
				have_lib = true
				break
		if not have_lib:
			_spawn_npc("librarian", m.NPC_HOME["librarian"])

	# 목동 보라 — 초원을 보러 온 방문객 (스토리 8).
	# 목장 상회가 완성되고 정착 대화를 마쳐야 정식 주민이 된다.
	if GameData.story8_phase in ["visit", "ask", "build", "done"]:
		var have_ran := false
		for n in m.npcs:
			if n.id == "rancher":
				have_ran = true
				break
		if not have_ran:
			_spawn_npc("rancher", m.NPC_HOME["rancher"])

	# 이사 온 일반/특수 주민 — 집터에 지은 자기 집 곁에서 지낸다
	for nid: String in GameData.settlers:
		var have_s := false
		for n in m.npcs:
			if n.id == nid:
				have_s = true
				break
		if not have_s and GameData.settler_homes.has(nid):
			var h: Array = GameData.settler_homes[nid]
			_spawn_npc(nid,
				m.door_tile(Vector2i(int(h[0]), int(h[1]))) + Vector2i(0, 1))

	# 숲의 연금술사 묘연 — 숨은 길이 열린 뒤, 깊은 숲 오두막 곁에서 산다.
	# 마을에 입주하지 않는다 (스토리 12) — 볼일이 있으면 직접 찾아간다.
	if GameData.story12_phase in ["path", "gather", "done"]:
		var have_alch := false
		for n in m.npcs:
			if n.id == "alchemist":
				have_alch = true
				break
		if not have_alch:
			_spawn_npc("alchemist",
				m.door_tile(m.ALCH_HOUSE_ANCHOR) + Vector2i(0, 1))
			m.npcs[m.npcs.size() - 1].region = Rect2i(
				m.ALCH_HOUSE_ANCHOR.x - 3, m.ALCH_HOUSE_ANCHOR.y + 3, 12, 5)

	# 숲속의 모녀 — 연화는 집을 찾아간 뒤부터 집 앞 빈터에서 지낸다.
	# 솔이는 몸이 약해 문밖으로 나오지 못한다 — 연화가 마음을 열고
	# 안으로 들인 뒤(forest_trust == "done")에야 마당까지 나온다.
	var forest_ids: Array = []
	if GameData.forest_quest in ["go", "back", "done"]:
		forest_ids.append("forest_mom")
	if GameData.forest_trust == "done":
		forest_ids.append("forest_girl")
	if not forest_ids.is_empty():
		for fid: String in forest_ids:
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
