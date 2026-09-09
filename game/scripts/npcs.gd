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


func _spawn_npc(npc_id: String, tile: Vector2i, region := Rect2i()) -> void:
	var n: Node2D = preload("res://scripts/npc.gd").new()
	n.main = m
	n.id = npc_id
	# 어슬렁거릴 범위. 고장 사람은 제 마을 둘레를 돈다 —
	# 교진 마을 구역을 주면 지도 반대편까지 걸어가려 든다
	n.region = region if region.size.x > 0 else m.VILLAGE_REGION
	n.position = Vector2(tile.x * m.TILE + 16, tile.y * m.TILE + 16)
	m.npcs.append(n)
	m.world.add_child(n)


func npc_place_now(npc_id: String) -> String:
	# 사회가 자리를 정한 사람이 먼저다 — 이장의 마을 회의(meeting)와 밤 사람(plaza·pier).
	# 축제 블록보다 위에 있지만 「축제 > 사회」는 society_place 안의 시간 조건이 지킨다:
	# 회의는 축제 없는 날 9~17시만, 밤 사람은 축제가 끝난 저녁(is_evening) 이후만
	var soc := GameData.society_place(npc_id)
	if soc != "":
		return soc
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


# 고장 마을 사람이 갈 자리. 교진 마을의 광장·게시판·부두는 여기 없다 —
# 하루가 제 고장 안에서 돈다.
func _hamlet_tile(npc_id: String, place: String) -> Vector2i:
	var h: Dictionary = m.HAMLETS[m.HAMLET_OF[npc_id]]
	if place == "square":
		return h.square
	if place == "falls":
		# 도담은 폭포 밑에서 논다 (그림 밑동은 못 밟으니 두 칸 옆)
		for lm: Dictionary in m.LANDMARKS:
			if lm.id == "falls":
				return Vector2i(lm.tile.x + 8, lm.tile.y + 1)
	if place == "tree":
		# 글샘은 큰나무 밑에 앉아 이야기를 받아 적는다
		for lm2: Dictionary in m.LANDMARKS:
			if lm2.id == "greattree":
				return Vector2i(lm2.tile.x - 7, lm2.tile.y + 1)
	# home · work — 둘 다 제 집이다 (여기 사람들은 집이 일터다)
	for entry: Array in h.houses:
		if String(entry[2]) == npc_id:
			return m.door_tile(entry[0]) + Vector2i(0, 1)
	return h.square


func npc_place_tile(npc_id: String, place: String) -> Vector2i:
	var t := Vector2i(-999, -999)
	if m.HAMLET_OF.has(npc_id):
		t = _hamlet_tile(npc_id, place)
		if m.is_passable(t):
			return t
		for d0: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0),
				Vector2i(-1, 0), Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0)]:
			if m.is_passable(t + d0):
				return t + d0
		return t
	match place:
		"stall":
			t = m.STALL_TILE + Vector2i(0, 1)   # 노점 앞 모래밭
		"hallwork":
			t = m.door_tile(m.VILLAGE_PLOTS["hall"].anchor) + Vector2i(0, 1)
		"patrol":
			# 박 순경의 순찰 — 시각마다 세 지점(광장 남쪽·게시판 앞·서쪽 어귀)을 돈다
			var pts: Array = m.society.patrol_points()
			t = pts[int(GameData.hour_now()) % pts.size()]
		"chase":
			# 수배 중인 나를 쫓는다 — 목적지가 곧 내 발밑이다(npc.gd 가 route 마다 다시 잡는다)
			t = m.player_tile()
		"meeting":
			# 이장의 마을 회의 — 회관이 있으면 회관 문 앞, 없으면 이장 집 문 앞 (D14)
			if GameData.village_built.has("hall"):
				t = m.door_tile(m.VILLAGE_PLOTS["hall"].anchor) + Vector2i(0, 1)
			else:
				t = m.CHIEF_HUT + Vector2i(0, 1)
		"onsen":
			# 온천 앞 — 셋이 겹치지 않게 한 칸씩 벌려 선다
			var oi: int = maxi(0, ONSEN_GOERS.find(npc_id))
			t = m.ONSEN_POS + Vector2i(oi - 1, 2)
		"fountain":
			t = Vector2i(m.FOUNTAIN.position.x + 1, m.FOUNTAIN.end.y + 1)
		"plaza":
			t = m.NPC_PLAZA.get(npc_id, Vector2i(74, 13 + m.NORTH_PAD))
		"board":
			t = m.BOARD_POS + Vector2i(0, 1)
		"pier":
			# 낚시꾼은 **부두 위에** 선다 — 낚시터의 주인이니 제일 좋은 자리다.
			# 나머지는 낚시대회 때 한 칸에 겹치지 않게 남쪽 물가에 늘어선다.
			if npc_id == "fisher" or npc_id == "angler":
				t = m.DOCK_STAND
				if npc_id == "angler":
					t += Vector2i(2, 0)
			else:
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
				t = m.NPC_HOME.get(npc_id, Vector2i(72, 20 + m.NORTH_PAD))
	if m.is_passable(t):
		return t
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0)]:
		if m.is_passable(t + d):
			return t + d
	return t


# 고장 마을 사람들 — 조건 없이 처음부터 제 마을에 산다.
# 교진 마을 사람처럼 「이사 오는」 게 아니라 원래 거기 살던 사람들이다.
# 멀어서 걸어가야 만난다 — 그 거리가 곧 해금이다.
func _sync_hamlet_npcs() -> void:
	for hid: String in m.HAMLETS:
		var h: Dictionary = m.HAMLETS[hid]
		# 어슬렁거릴 범위 = 집들과 한복판을 다 감싸는 네모 + 두 칸 여유
		var box := Rect2i(h.square, Vector2i.ZERO)
		for entry: Array in h.houses:
			box = box.expand(entry[0]).expand(entry[0] + Vector2i(5, 4))
		box = box.grow(3)
		for entry2: Array in h.houses:
			var nid: String = entry2[2]
			var found := false
			for n in m.npcs:
				if n.id == nid:
					found = true
					break
			if found:
				continue
			_spawn_npc(nid, m.door_tile(entry2[0]) + Vector2i(0, 1), box)


func _sync_village_npcs() -> void:
	_sync_hamlet_npcs()
	# 건물이 생기면 그 건물의 주인이 마을에 나타난다 (없는 건물의 주인은 아직 없다)
	for pid: String in m.VILLAGE_NPC:
		if not GameData.village_built.has(pid):
			continue
		var nid: String = m.VILLAGE_NPC[pid]
		if not GameData.npc_greeted.has(nid):
			continue  # 첫 인사를 나눠야 마을에 자리 잡는다 (건물 주인은 첫날부터 인사한 셈)
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


# 펼칠 칸 수의 상한. 넘으면 「못 간다」로 친다.
#
# 펼칠 칸의 상한은 **거리에 맞춘다.**
#
# 스무 칸 앞을 못 찾겠으면 팔천 칸을 더 펼쳐도 못 찾는다. 반대로 마을에서
# 농장까지 가는 길은 숲을 헤치느라 수천 칸을 펼치기도 한다. 한 값으로
# 묶으면 가까운 데서 낭비하거나 먼 데서 길을 못 찾거나 둘 중 하나다.
#
# 상한에 걸린다는 것은 「길이 멀다」가 아니라 **닿을 수 없다**는 뜻이다 —
# 갈 수 있는 땅과 끊긴 웅덩이 안. 거기서 세계를 다 훑어도 답은 똑같다.
const PATH_BUDGET_MIN := 3000
const PATH_BUDGET_MAX := 12000
const BIG_G := 1 << 30
var _path_opened := 0        # 마지막으로 펼친 칸 수 (검증·F3용)
# 길찾기 프레임 예산(S4a 성능 ②) — 한 프레임에 둘까지. 셋째부터는 다음 프레임에 —
# 부른 쪽(npc._update_schedule)이 짧게 기다렸다 다시 온다. 아흔 명이 같은 시각에
# 길을 찾아도 한 프레임이 튀지 않는다(최악 24,000 pop ≈ 30~50ms 가 한 프레임에 겹치지 않게)
const PATH_PER_FRAME := 2
var _path_frame := -1
var _path_calls := 0


func path_slot() -> bool:
	var f: int = Engine.get_process_frames()
	if f != _path_frame:
		_path_frame = f
		_path_calls = 0
	if _path_calls >= PATH_PER_FRAME:
		return false
	_path_calls += 1
	return true


const PATH_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)]


func _h(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# 칸 단위 길찾기 — **A***.
#
# 예전에는 너비 우선이었다. 「갈 수 있는 칸이면 무조건 다 펼친다」는 뜻이다.
# 224x132 시절에는 그래도 됐다. 448x304 가 되면서, **닿을 수 없는 목적지**
# 하나가 세계 전체(8만 칸)를 훑는 일이 됐다 — 한 프레임이 0.1~0.5초로 튀고,
# 실패하면 2초 뒤에 또 훑는다. 「최악이 튀고 바로 돌아와」가 이것이었다.
#
# A*는 목적지 쪽으로 먼저 펼친다. 맨해튼 거리는 네 방향 격자에서 실제 거리를
# 넘지 않으므로(admissible·consistent) **길 자체는 너비 우선과 똑같이 짧게**
# 나온다 — 값만 줄고 그림은 안 바뀐다. 그리고 펼칠 칸에 상한을 둔다.
func _tile_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return []
	# 목적지 칸 자체를 못 밟으면 훑을 것도 없다. 예전에도 답은 「없다」였는데,
	# 그 답을 내려고 세계를 다 펼쳤다 — 건물에 막힌 목적지 하나가 그랬다
	if not m.is_passable(goal):
		return []
	var t0 := Time.get_ticks_usec() if m.perf_show else 0
	var budget := clampi(_h(start, goal) * 150, PATH_BUDGET_MIN, PATH_BUDGET_MAX)
	var prev := {start: start}
	var gsc := {start: 0}
	var blocked := {}          # 못 가는 칸 — 이웃 넷이 저마다 물어보지 않게
	# 작은 이진 힙 — [f, 넣은 차례, 칸, g]. 차례는 f가 같을 때 순서를 굳혀
	# 같은 자리에서 부를 때마다 길이 달라지지 않게 한다
	var heap: Array = [[_h(start, goal), 0, start, 0]]
	var seq := 0
	var opened := 0
	var found := false
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var cur: Vector2i = top[2]
		# 묵은 표 — 이 칸에 더 싼 길이 이미 났다.
		# (꺼내는 차례는 f 순이지 g 순이 아니라서, 넣을 때 굳혀 두면
		#  두어 칸 돌아가는 길이 나온다. 실제로 87칸이 89칸으로 나왔다)
		if int(top[3]) > int(gsc.get(cur, BIG_G)):
			continue
		if cur == goal:
			found = true
			break
		opened += 1
		if opened > budget:
			break
		var ng: int = int(top[3]) + 1
		for d: Vector2i in PATH_DIRS:
			var n: Vector2i = cur + d
			if ng >= int(gsc.get(n, BIG_G)) or blocked.has(n):
				continue
			if not m.is_passable(n):
				blocked[n] = true
				continue
			gsc[n] = ng
			prev[n] = cur
			seq += 1
			heap.append([ng + _h(n, goal), seq, n, ng])
			_heap_up(heap, heap.size() - 1)
	if m.perf_show:
		m._pm("길찾기", t0)
	_path_opened = opened
	if not found:
		return []
	var path: Array = []
	var at := goal
	while at != start:
		path.push_front(Vector2(at.x * m.TILE + 16, at.y * m.TILE + 16))
		at = prev[at]
	return path


func _heap_less(a: Array, b: Array) -> bool:
	if int(a[0]) != int(b[0]):
		return int(a[0]) < int(b[0])
	return int(a[1]) < int(b[1])


func _heap_up(h: Array, i: int) -> void:
	while i > 0:
		var par: int = (i - 1) >> 1
		if not _heap_less(h[i], h[par]):
			return
		var t: Array = h[i]
		h[i] = h[par]
		h[par] = t
		i = par


func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.is_empty():
		return top
	h[0] = last
	var i := 0
	var n := h.size()
	while true:
		var l := i * 2 + 1
		var sm := i
		if l < n and _heap_less(h[l], h[sm]):
			sm = l
		if l + 1 < n and _heap_less(h[l + 1], h[sm]):
			sm = l + 1
		if sm == i:
			return top
		var t: Array = h[i]
		h[i] = h[sm]
		h[sm] = t
		i = sm
	return top

