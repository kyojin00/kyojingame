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
	# 격자는 튜토리얼 공간(세계 밖에 붙인 띠)까지 담는다 — 다만 **세계를 짓는
	# 일은 WORLD_H 위쪽에서만** 한다. 그 아래 띠는 story가 손수 깐다.
	for y in m.MAP_H:
		var row := []
		for x in m.MAP_W:
			# crop_day = 누적 성장 시간(게임 분), wet_min = 남은 젖음 시간(게임 분)
			row.append({"ground": "grass", "watered": false, "wet_min": 0.0,
				"crop_id": "", "crop_day": 0.0, "dead": false, "half_fed": false})
		m.grid.append(row)

	# 연못들 (숲/깊은 숲) — 시작 부지의 연못은 없앴다
	# 낚시터 호수 — 부두를 놓으려고 넓혔다 (4.5x3.5 -> 6.5x4.2).
	# 옛 크기에서는 T자 부두 하나가 연못을 거의 다 덮어, 낚시터가 아니라
	# 물웅덩이에 널을 깐 꼴이 됐다. 부두 양옆으로 물이 남아야 낚는 자리다.
	_carve_pond(49, 31 + m.NORTH_PAD, 6.5, 4.2)
	_build_dock()
	# (호수는 마을 서쪽 낚시터가 됐다 — 마을을 가르던 강은 전부 없앴다)
	_carve_pond(74, 51 + m.NORTH_PAD, 5.0, 3.0)    # 깊은 숲 연못
	# 숲을 가로지르는 개울 — 웅덩이만 있으면 물이 고인 땅으로 보인다.
	# 흐르는 물이 하나는 있어야 지형에 방향이 생긴다
	_carve_river(30, 24, 44, 46, 2.2)

	_build_levels()
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
			m.objects[Vector2i(x, m.WORLD_H - 1)] = {"kind": "tree", "hp": m.TREE_HP}
	for y in m.WORLD_H:
		if y % 4 == 0 and not m.objects.has(Vector2i(0, y)):
			m.objects[Vector2i(0, y)] = {"kind": "tree", "hp": m.TREE_HP}
		if y % 4 == 0 and not m.objects.has(Vector2i(m.MAP_W - 1, y)):
			m.objects[Vector2i(m.MAP_W - 1, y)] = {"kind": "tree", "hp": m.TREE_HP}

	# 지역 바닥 먼저 (자갈밭·물웅덩이). 자연물은 그 위에 얹는다
	_build_region_map()
	_paint_regions()

	# 흩어진 나무/돌 (결정적 해시 배치 — 지역마다 밀도가 다르다)
	for y in range(1, m.WORLD_H - 1):
		for x in range(1, m.MAP_W - 1):
			var pos := Vector2i(x, y)
			if m.objects.has(pos) or m.grid[y][x].ground == "water":
				continue
			if m.is_ramp(x, y):
				continue  # 오르막은 비워둔다 — 나무 한 그루가 길을 막는다
			if x >= 1 and x <= 10 and y >= 0 and y <= 6:
				continue  # 축사 주변은 비워둔다
			if abs(x - m.START_TILE.x) <= 3 and abs(y - m.START_TILE.y) <= 3:
				continue  # 시작 지점 주변도 비워둔다
			if m.VILLAGE_REGION.has_point(pos) or m.ROAD.has_point(pos):
				continue  # 마을/길은 비워둔다
			var reg := _region_at(pos)
			var h := m._hash01(x * 3 + 7, y * 5 + 11)
			var tree_p := 0.06
			var rock_p := 0.12          # 나무 확률 위에 이어 붙는 문턱값
			if not reg.is_empty():
				# 줄지어 심은 땅(과수원)은 격자 위에만 선다 — 그 사이는 훤히 비운다
				var g := int(reg.grid)
				if g > 0 and (x % g != 0 or y % g != 0):
					continue
				tree_p = float(reg.tree)
				rock_p = tree_p + float(reg.rock)
			elif m.grid[y][x].ground != "grass":
				continue                # 지역 밖의 흙·모래 위에는 아무것도 안 둔다
			if h < tree_p:
				if _nature_clear(pos, "tree"):
					m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP}
			elif h < rock_p:
				if _nature_clear(pos, "rock"):
					m.objects[pos] = {"kind": "rock", "hp": m.ROCK_HP}

	# 낚시터 둘레는 마지막에 비운다 — 나무/돌 그림이 부두와 강을 덮으면 안 된다.
	# (자연물 배치가 모두 끝난 뒤라야 확실히 비워진다)
	for p: Vector2i in m.objects.keys():
		if m.FISH_CLEAR.has_point(p):
			m.objects.erase(p)
	m.objects[m.FISH_SIGN] = {"kind": "sign", "hp": 0}
	# 고장의 랜드마크 — 나무·돌을 다 흩고 **난 뒤에** 세운다. 먼저 세우면
	# 그 위로 나무가 돋아 그림을 반쯤 가린다 (낚시터를 마지막에 비우는 것과
	# 같은 이유다)
	_build_landmarks()
	_build_hamlets()
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
	# 채집물은 첫날부터 들판에 흩어져 있다. 예전에는 세계를 지을 때
	# 한 포기도 두지 않아, 새 농장의 첫날은 산딸기 한 알 없는 빈 들판이었다.
	# (아직 화면도 주인공도 없는 시점이라 노드는 만들지 않는다)
	_respawn_forage(false)


# 이 칸이 어느 야생 지역인가 (없으면 빈 사전).
#
# 예전에는 부를 때마다 지역 표를 처음부터 훑었다. 지역이 일곱이고 세계가
# 224x132일 때는 20만 번이라 티가 안 났는데, 지역 스물에 448x264가 되면서
# **240만 번**이 됐다 — 새 게임을 시작할 때 몇 초씩 멈췄다.
#
# 그래서 한 번만 훑어 칸마다 지역 번호를 적어 둔다. 118킬로바이트짜리
# 표 하나면 그다음부터는 한 번에 찾는다.
var _region_map: Array[PackedByteArray] = []

func _build_region_map() -> void:
	# 한 줄씩 **다 채워서** 넣는다. PackedByteArray 는 값 타입이라
	# `_region_map[y][x] = v` 처럼 두 겹으로 넣는 건 기대대로 안 될 수 있다
	_region_map = []
	for y in m.WORLD_H:
		var row := PackedByteArray()
		row.resize(m.MAP_W)
		for i in m.REGIONS.size():
			var r: Rect2i = m.REGIONS[i].rect
			if y < r.position.y or y >= r.end.y:
				continue
			for x in range(maxi(0, r.position.x), mini(m.MAP_W, r.end.x)):
				if row[x] == 0:        # 먼저 적힌 지역이 이긴다 (0 = 지역 밖)
					row[x] = i + 1
		_region_map.append(row)
	# 지역이 255를 넘으면 번호가 한 바이트에 안 들어간다 (지금은 스물 남짓)
	assert(m.REGIONS.size() < 255, "REGIONS가 255개를 넘었다 — 표를 넓혀야 한다")


func _region_at(pos: Vector2i) -> Dictionary:
	if pos.x < 0 or pos.y < 0 or pos.x >= m.MAP_W or pos.y >= m.WORLD_H:
		return {}
	if _region_map.is_empty():
		_build_region_map()
	var i := _region_map[pos.y][pos.x]
	return {} if i == 0 else m.REGIONS[i - 1]


# 지역 바닥을 깐다 — 채석장 자갈, 습지 물웅덩이.
# 마을·길·낚시터처럼 이미 쓰임이 정해진 칸은 건드리지 않는다.
func _paint_regions() -> void:
	for reg: Dictionary in m.REGIONS:
		var r: Rect2i = reg.rect
		var g := str(reg.ground)
		var pond := float(reg.pond)
		if pond > 0.0:
			_carve_region_ponds(r, pond)
		if g == "":
			continue
		for y in range(maxi(1, r.position.y), mini(m.WORLD_H - 1, r.end.y)):
			for x in range(maxi(1, r.position.x), mini(m.MAP_W - 1, r.end.x)):
				var pos := Vector2i(x, y)
				if m.VILLAGE_REGION.has_point(pos) or m.ROAD.has_point(pos):
					continue
				if m.grid[y][x].ground != "grass":
					continue
				# 물은 **크게 몇 개**여야 물이다. 예전에는 칸마다 확률로 찍어서
				# 작은 웅덩이가 온 들판에 흩뿌려졌다 — 물이 아니라 파란 얼룩이었다.
				# 이제 지역마다 큰 웅덩이 몇 개를 파낸다 (아래 _carve_region_ponds)
				if g != "":
					# 가장자리로 갈수록 듬성듬성 — 네모 반듯하게 깔면
					# 「자로 그어 놓은 땅」처럼 보인다
					if m._hash01(x * 9 + 3, y * 7 + 1) < _edge_fade(pos, r):
						m.grid[y][x].ground = g


# 지역에 큰 웅덩이를 몇 개 판다.
#
# 물은 **크게 몇 개**여야 물로 보인다. 칸마다 확률로 찍으면 아무리 잘 그린
# 타일을 깔아도 파란 얼룩이 흩뿌려질 뿐이다 — 물가도, 깊이도, 여울도
# 세 칸짜리 웅덩이에서는 보이지 않는다.
#
# 개수는 지역 넓이에 맞춘다 (600칸에 하나쯤). 자리와 크기는 해시로 정해
# 다시 시작해도 같은 지형이 나오게 한다.
func _carve_region_ponds(r: Rect2i, pond: float) -> void:
	var n := int(round(float(r.size.x * r.size.y) / 600.0 * (pond / 0.25)))
	n = clampi(n, 1, 5)
	for i in n:
		var hx := m._hash01(r.position.x * 13 + i * 7 + 1, r.position.y * 17 + i * 5 + 3)
		var hy := m._hash01(r.position.y * 11 + i * 3 + 5, r.position.x * 19 + i * 9 + 7)
		var hs := m._hash01(i * 23 + r.position.x, i * 29 + r.position.y)
		# 가장자리에서 넉넉히 안쪽에 — 지역 밖으로 물이 새면 지형이 어긋난다
		var cx := r.position.x + 6 + int(hx * float(maxi(1, r.size.x - 12)))
		var cy := r.position.y + 5 + int(hy * float(maxi(1, r.size.y - 10)))
		if m.VILLAGE_REGION.has_point(Vector2i(cx, cy)) or m.ROAD.has_point(Vector2i(cx, cy)):
			continue
		_carve_pond(cx, cy, 5.0 + hs * 4.0, 3.5 + hs * 2.5)


# 지역 가장자리에서 0, 세 칸쯤 안으로 들어오면 1에 가까워지는 값.
# 바닥을 깔지 말지를 이 값으로 흔들어 경계를 너덜너덜하게 만든다.
func _edge_fade(pos: Vector2i, r: Rect2i) -> float:
	var d: int = mini(mini(pos.x - r.position.x, r.end.x - 1 - pos.x),
		mini(pos.y - r.position.y, r.end.y - 1 - pos.y))
	return clampf(float(d) / 3.0, 0.0, 1.0) * 0.9 + 0.05


# 남쪽 끝: 바위 능선 너머의 땅. 바다를 열기 전에는 울창한 숲처럼 보이고,
# 낚시꾼 퀘스트에서 길목(SEA_GATE) 바위를 캐는 순간 바다·해변이 드러난다.
# 로드 후에도 다시 불러 남쪽 지형을 결정적으로 맞춘다 (구세이브 보정).
func _build_sea() -> void:
	# 바다와 모래사장은 **언제나 이 자리에 있다**. 예전에는 바닷길을 열기 전까지
	# 숲으로 덮어 두었다가 길목 바위를 캐는 순간 물로 바꿨는데, 그러다 보니
	# 「돌을 캤더니 숲이 바다가 되는」 광경이 그대로 보였다. 이제 지형은
	# 고정이고, 능선의 큰 바위가 길을 막고 있을 뿐이다.
	# 바다는 **화면에 보일 수 있는 끝까지** 물이다.
	#
	# 예전에는 세계의 높이(WORLD_H)까지만 물을 깔았다. 그런데 격자는 그
	# 아래로도 튜토리얼 공간까지 이어져 있어서, 모래사장에 서면 파란 띠가
	# 끊기고 **그 밑에 풀밭이 도로 보였다** — 바다 건너에 초원이 있는 꼴이다.
	# 이제 격자 끝(MAP_H)까지 **한 칸도 빼놓지 않고** 물로 채운다.
	# 세계 밖의 튜토리얼 숲길도 예외가 아니다 — 그 공간이 살아 있는 동안에는
	# `story._plant_story_forest`가 제 바닥을 다시 깔고, 마을로 넘어가며
	# 닫힌 뒤에는 바다만 남는다. (예외를 두었더니 모래사장에서 파란 바다 밑에
	#  초록 땅덩이가 떠 보였다 — 카메라가 열다섯 줄 아래까지 비춘다)
	# 해안선은 **자로 그은 선이 아니다.**
	#
	# 예전에는 SEA_Y0 아래를 통째로 물, 그 위 띠를 통째로 모래로 깔았다.
	# 바다가 화면을 가로지르는 파란 사각형이었다. 실제 해안은 굽이친다 —
	# 곶이 튀어나오고 만이 파고든다.
	#
	# 두 파장으로 흔든다. 하나만 쓰면 규칙적인 물결이 되고, 셋 이상이면
	# 해안이 너덜너덜해져 「닳은 종이」가 된다.
	for x in m.MAP_W:
		var t := float(x) / float(m.MAP_W)
		var wave := sin(t * PI * 3.1) * 2.6 + sin(t * PI * 7.3) * 1.3
		var sea_y := m.SEA_Y0 + int(round(wave))
		# 모래사장 폭도 자리마다 다르다. 어디는 넓은 백사장, 어디는 좁은 갯바위
		var beach_w := (m.SEA_Y0 - m.BEACH_Y0) + int(round(sin(t * PI * 4.7) * 1.8))
		var beach_y: int = maxi(m.BEACH_Y0 - 2, sea_y - beach_w)
		for y in range(sea_y, m.MAP_H):
			if y < 0 or y >= m.MAP_H:
				continue
			m.grid[y][x].ground = "water"
			m.objects.erase(Vector2i(x, y))
		for y in range(beach_y, sea_y):
			if y < 0 or y >= m.MAP_H:
				continue
			m.grid[y][x].ground = "sand"
			m.objects.erase(Vector2i(x, y))
	# 능선 바위는 **벼랑 마루를 따라** 놓는다. 곧은 줄에 늘어놓으면 굽이치는
	# 벼랑과 어긋나 바위가 허공에 뜬다
	for x in m.MAP_W:
		var p := Vector2i(x, _ridge_y(x))
		m.objects.erase(p)
		if p in m.SEA_GATE:
			continue
		m.objects[p] = {"kind": "searock", "hp": 0}
	for p: Vector2i in m.SEA_GATE:
		if GameData.sea_open:
			m.objects.erase(p)      # 한 번 연 길은 무엇으로도 다시 막히지 않는다
		elif not m.objects.has(p):
			m.objects[p] = {"kind": "bigrock", "hp": m.BIGROCK_HP, "fixed": true}
	# 튜토리얼 공간이 아직 살아 있으면 방금 덮어쓴 그 바닥을 도로 깔아 준다
	if GameData.tutorial_space and m.story != null:
		m.story._plant_story_forest()
	if GameData.sea_open:
		var have := false
		for pos in m.objects:
			if String(m.objects[pos].kind) in m.BEACH_FORAGE:
				have = true
				break
		if not have:
			_seed_beach_forage(false)   # 노드는 뒤이어 _spawn_objects가 만든다
		_place_stall(false)
	# 바다가 통째로 깔렸다 — 물의 깊이를 다시 잰다 (물가에서 멀수록 짙다)
	m.rebuild_water_levels()


# ---- 땅의 높이 ----
#
# 벼랑은 따로 놓는 물건이 아니라 **높이가 다른 두 땅이 만나는 자리**다.
# 칸마다 켜(0~7)만 정해 두면 바위면도 마루도 통행 막힘도 거기서 나온다.
#
#   켜 1   세계의 바닥. 남쪽 능선 위쪽은 전부 여기다
#   켜 0   능선 아래 — 모래사장과 바다. 능선이 그대로 벼랑이 된다
#   켜 2   대지(臺地) 몇 군데. 깊은 숲의 언덕과 채석장의 단구
func _build_levels() -> void:
	m.terrain_level = []
	for y in m.MAP_H:
		var row := PackedByteArray()
		row.resize(m.MAP_W)
		for x in m.MAP_W:
			# 능선 위는 한 켜 높다. 그 아래(모래사장·바다)는 0
			row[x] = 1 if y <= _ridge_y(x) else 0
		m.terrain_level.append(row)
	# 마을 북쪽 언덕 — **큰길에서 올려다보이는** 자리다. 벼랑면은 남쪽을
	# 보고 서므로 길(y 8~10)보다 위에 있어야 얼굴이 보인다. 다만 벼랑 밑
	# 한 줄은 지나갈 수 없으니 길과는 두 줄쯤 떼어 놓는다
	_raise_blob(37, 1 + m.NORTH_PAD, 11.0, 4.6, 2, 71)
	# 깊은 숲의 언덕 — 연못(74,51)과 겹치지 않게 서쪽으로 앉힌다
	_raise_blob(56, 58 + m.NORTH_PAD, 9.0, 5.0, 2, 41)
	# 동쪽 채석장의 단구 — 돌을 캐 낸 자리라 층이 진다
	_raise_blob(196, 46 + m.NORTH_PAD, 13.0, 6.0, 2, 57)
	# 오르막 — 벼랑을 끊고 내려오는 자리. 없으면 올라갈 수가 없다.
	# **남쪽 자락**에 낸다 — 바위면이 보이는 쪽이라야 길로 읽힌다
	_cut_ramp(33, 5 + m.NORTH_PAD)
	_cut_ramp(51, 63 + m.NORTH_PAD)
	_cut_ramp(60, 63 + m.NORTH_PAD)
	_cut_ramp(190, 52 + m.NORTH_PAD)
	# ---- 고장 랜드마크의 단차 ----
	#
	# 그림만 세우면 아무리 잘 그려도 평지에 붙인 판때기다. 폭포는
	# **벼랑에서** 떨어져야 폭포고, 바위 기둥은 **대지 위에** 서야 높다.
	# 그림이 그 벼랑의 한 자리를 맡으면, 좌우로 벼랑이 이어져 나가면서
	# 그림과 세계가 한 몸이 된다.
	#
	# 켜를 다 올린 **뒤에** 오르막을 낸다 — 먼저 내면 나중 켜가 덮어 버려
	# 올라갈 수 없는 섬이 된다.
	for lm: Dictionary in m.LANDMARKS:
		for b: Array in (lm.get("terrain", {}) as Dictionary).get("blobs", []):
			_raise_blob(int(b[0]), int(b[1]), float(b[2]), float(b[3]),
				int(b[4]), int(b[5]))
	for lm2: Dictionary in m.LANDMARKS:
		for r: Array in (lm2.get("terrain", {}) as Dictionary).get("ramps", []):
			_cut_ramp(int(r[0]), int(r[1]))
	# 바다로 내려가는 길목 — 큰 바위를 캐면 이 오르막으로 내려간다
	_cut_ramp(m.SEA_GATE[0].x, m.SEA_RIDGE_Y, m.SEA_GATE.size())


# 능선이 지나는 줄. **자로 그은 선이 아니다** — 굽이친다.
# 다만 길목(SEA_GATE) 언저리는 반듯하게 둔다: 큰 바위가 놓인 자리와
# 오르막이 어긋나면 바닷길이 엉뚱한 데로 난다
func _ridge_y(x: int) -> int:
	if absi(x - m.SEA_GATE[0].x) <= 4:
		return m.SEA_RIDGE_Y
	var t := float(x) / float(m.MAP_W)
	var w := sin(t * PI * 5.3) * 1.3 + sin(t * PI * 11.9) * 0.9
	return m.SEA_RIDGE_Y - clampi(int(round(w + 1.6)), 0, 3)


func _lv(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
		return 0
	return m.terrain_level[y][x] & 7


func _set_lv(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
		return
	m.terrain_level[y][x] = (m.terrain_level[y][x] & 8) | (v & 7)


func _set_ramp(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
		return
	m.terrain_level[y][x] = m.terrain_level[y][x] | 8


# 대지 하나 — 연못과 같은 방식으로 가장자리를 흔든다. 타원 그대로 두면
# 땅이 아니라 접시가 된다
func _raise_blob(cx: int, cy: int, rx: float, ry: float, to: int, seed: int) -> void:
	for y in range(maxi(0, cy - int(ry) - 3), mini(m.MAP_H, cy + int(ry) + 4)):
		for x in range(maxi(0, cx - int(rx) - 3), mini(m.MAP_W, cx + int(rx) + 4)):
			var a := atan2(float(y - cy), float(x - cx))
			var w := 0.86 + m._hash01(int(round(a * 4.0)), seed) * 0.16 \
				+ m._hash01(int(round(a * 8.0)), seed + 1) * 0.14
			var d := pow((x - cx) / (rx * w), 2.0) + pow((y - cy) / (ry * w), 2.0)
			if d <= 1.0 and _lv(x, y) > 0:
				_set_lv(x, y, to)
	# 뾰족하게 튀어나온 칸을 다듬는다. 흔들어 놓은 가장자리는 한두 칸짜리
	# 돌기를 남기는데, 그건 벼랑이 아니라 그리다 만 자국으로 보인다
	var x0: int = maxi(1, cx - int(rx) - 3)
	var x1: int = mini(m.MAP_W - 1, cx + int(rx) + 4)
	var y0: int = maxi(1, cy - int(ry) - 3)
	var y1: int = mini(m.MAP_H - 1, cy + int(ry) + 4)
	for _pass in 2:
		var fix: Array = []
		for y in range(y0, y1):
			for x in range(x0, x1):
				if _lv(x, y) == 0:
					continue          # 물 아래(바다)는 건드리지 않는다
				var n := 0
				for o: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
						Vector2i(-1, 0), Vector2i(1, 0)]:
					if _lv(x + o.x, y + o.y) == to:
						n += 1
				if _lv(x, y) == to and n <= 1:
					fix.append([x, y, to - 1])
				elif _lv(x, y) != to and n >= 3:
					fix.append([x, y, to])
		for f: Array in fix:
			_set_lv(f[0], f[1], f[2])


# 오르막 — 벼랑을 끊고 내려오는 자리.
#
# **두 칸 폭**으로 낸다. 한 칸이면 양옆 바위벽이 서로 맞물려 길이 막힌다.
# 그리고 그 두 칸의 경계를 한 줄에 맞춘다 — 어긋나면 오르막이 비뚤어진다
func _cut_ramp(x: int, near_y: int, w := 2) -> void:
	# 어느 벼랑인지는 **줄로 짚어 준다.** 위에서부터 훑으면 대지의 북쪽
	# 자락이 먼저 걸리는데, 거기는 바위면이 아예 안 보이는 쪽이다
	var yb := -1
	for d in 7:
		for y: int in [near_y + d, near_y - d]:
			if y < 1 or y >= m.MAP_H - 2:
				continue
			if _lv(x, y) > _lv(x, y + 1):
				yb = y
				break
		if yb >= 0:
			break
	if yb < 0:
		return
	var hi := _lv(x, yb)
	var lo := _lv(x, yb + 1)
	for i in w:
		var cx: int = x + i
		for y in range(maxi(0, yb - 2), mini(m.MAP_H, yb + 4)):
			_set_lv(cx, y, hi if y <= yb else lo)
		_set_ramp(cx, yb)
		_set_ramp(cx, yb + 1)
		# 오르내리며 밟혀 풀이 죽은 자리 — 길이 난 것처럼 보인다
		for ry in [yb, yb + 1]:
			if m.grid[ry][cx].ground == "grass":
				m.grid[ry][cx].ground = "yard"


# 길이 열리는 순간 능선 너머가 드러난다 — 숲을 걷어내고 바다와 모래사장을 깐다
func _reveal_sea() -> void:
	if not GameData.sea_open:
		# 바닷길이 열린 날 — 용식의 집터 부탁이 여기서 정확히 3일 뒤에 뜬다
		GameData.sea_open_day = GameData.day
	GameData.sea_open = true
	# 지형은 그대로다 (처음부터 바다였다). 길목을 막고 있던 바위만 걷어낸다
	for p: Vector2i in m.SEA_GATE:
		m.objnode._remove_object(p)
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


# 만수의 해변 노점 — 서브 퀘스트를 끝냈으면 늘 이 자리에 서 있다.
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
# 웅덩이를 **파낸다.** 사각형으로 칠하면 물이 아니라 수영장이다.
#
# 타원으로 자르되 반지름을 칸마다 흔든다 — 가장자리가 들쭉날쭉해야
# 물이 땅을 파고든 것처럼 보인다. 흔드는 폭은 반지름의 1/4쯤이면 충분하다.
# (더 흔들면 웅덩이가 아니라 얼룩이 된다)
# 낚시터의 나무 부두 — 물 위에 판자를 깐다.
#
# 호수를 판 **뒤에** 깐다. 순서가 바뀌면 연못 파기가 널을 다시 물로 지운다.
# 목이 뭍에 닿는 자리는 물이 아니어도 그냥 깐다 — 부두는 물가에서 시작해야
# 걸어 올라설 수 있다.
func _build_dock() -> void:
	for r: Rect2i in [m.DOCK_STEM, m.DOCK_HEAD]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
					continue
				m.grid[y][x].ground = "dock"
				m.objects.erase(Vector2i(x, y))   # 물풀·바위가 널 위에 남지 않게


# ---- 고장의 랜드마크 ----
#
# 고장마다 하나씩 서 있는 「엄청 큰 것」을 세운다 (m.LANDMARKS).
#
# 하는 일은 셋뿐이다:
#   ① 둘레를 **비운다** — 화면 열두 칸짜리 그림 앞에 나무가 서면
#      그림이 반쯤 가려져 무엇인지도 모르게 된다
#   ② 필요하면 **물을 판다** — 폭포 밑의 못, 별빛 호수
#   ③ 그림을 세우고 **밑동만** 막는다 — 뒤로 돌아가 걸을 수 있어야
#      「지나가는 길에 서 있는 것」이 된다 (벽이 아니라)
func _build_landmarks() -> void:
	for lm: Dictionary in m.LANDMARKS:
		var at: Vector2i = lm.tile
		var clear: int = int(lm.clear)
		# ① 둘레 비우기 — 그림은 밑변이 기준이라 **위로** 훨씬 높이 뻗는다.
		#    그래서 위쪽을 넉넉히, 아래쪽은 조금만 비운다
		for y in range(at.y - clear * 2, at.y + 3):
			for x in range(at.x - clear, at.x + clear + 1):
				m.objects.erase(Vector2i(x, y))
		# ② 물
		var lake: Array = lm.lake
		if not lake.is_empty():
			_carve_pond(int(lake[0]), int(lake[1]), float(lake[2]), float(lake[3]))
		var riv: Array = lm.river
		if not riv.is_empty():
			_carve_river(int(riv[0]), int(riv[1]), int(riv[2]), int(riv[3]), float(riv[4]))
		if String(lm.kind) == "":
			continue
		# ③ 그림과 밑동
		var blk: Rect2i = lm.block
		for by in range(blk.position.y, blk.end.y):
			for bx in range(blk.position.x, blk.end.x):
				var p := Vector2i(at.x + bx, at.y + by)
				if p == at or p.x < 0 or p.y < 0 or p.x >= m.MAP_W or p.y >= m.WORLD_H:
					continue
				m.objects[p] = {"kind": "art_block", "hp": 0}
		m.objects[at] = {"kind": String(lm.kind), "hp": 0}


# ---- 고장의 작은 마을 ----
#
# 랜드마크만 세워 놓으니 「크고 멋있는데 아무도 안 사는 곳」이 됐다.
# 큰 것 곁에는 그것 때문에 사는 사람이 있어야 한다.
#
# 교진 마을과 달리 **짓는 게 아니다.** 처음부터 서 있고, 걸어가서
# 발견하는 것이다. 그래서 여기서 통째로 세운다.
func _build_hamlets() -> void:
	for hid: String in m.HAMLETS:
		var h: Dictionary = m.HAMLETS[hid]
		# 마을 자리를 먼저 비운다 — 집 그림 위로 나무가 서면 안 된다.
		# 집 하나가 그림으로 덮는 칸은 7x6(앵커 기준 -1,-2 에서 시작)이고,
		# 그 둘레 마당까지 비워야 「집이 숲에 파묻힌」 꼴이 안 난다
		for entry: Array in h.houses:
			var a: Vector2i = entry[0]
			for y in range(a.y - 4, a.y + 6):
				for x in range(a.x - 3, a.x + 8):
					m.objects.erase(Vector2i(x, y))
		# 마을 한복판과 표지판 둘레도 비운다
		for c: Vector2i in [h.square, h.sign]:
			for y in range(c.y - 2, c.y + 3):
				for x in range(c.x - 2, c.x + 3):
					m.objects.erase(Vector2i(x, y))

		# 집 — 마당(다져진 흙)을 깔고 그림을 세운다
		for entry2: Array in h.houses:
			var a2: Vector2i = entry2[0]
			_lay_yard(a2)
			_fill_building(a2, String(entry2[1]))

		# 마을 한복판 — 다져진 흙 마당. 여기서 사람들이 만난다
		for y2 in range(h.square.y - 2, h.square.y + 3):
			for x2 in range(h.square.x - 3, h.square.x + 4):
				if x2 < 0 or y2 < 0 or x2 >= m.MAP_W or y2 >= m.WORLD_H:
					continue
				if str(m.grid[y2][x2].ground) == "grass":
					m.grid[y2][x2].ground = "yard"
				m.objects.erase(Vector2i(x2, y2))
		m.objects[h.sign] = {"kind": "sign", "hp": 0}

		# 그 마을에만 있는 것 (물레방아처럼)
		for pr: Array in h.props:
			var p: Vector2i = pr[0]
			# 물레방아 밑에는 물이 있어야 한다 — 마른 땅에서 도는 방아는 없다
			if String(pr[1]) == "deco_wheel":
				for wy in range(p.y + 1, p.y + 3):
					for wx in range(p.x - 1, p.x + 3):
						if wx < 0 or wy < 0 or wx >= m.MAP_W or wy >= m.WORLD_H:
							continue
						m.grid[wy][wx].ground = "water"
						m.objects.erase(Vector2i(wx, wy))
			m.objects[p] = {"kind": String(pr[1]), "hp": 0}


func _carve_pond(cx: int, cy: int, rx: float, ry: float) -> void:
	var mx := int(ceil(rx)) + 2
	var my := int(ceil(ry)) + 2
	for y in range(cy - my, cy + my + 1):
		for x in range(cx - mx, cx + mx + 1):
			if x < 1 or y < 1 or x >= m.MAP_W - 1 or y >= m.WORLD_H - 1:
				continue
			var dx := (float(x) - float(cx)) / rx
			var dy := (float(y) - float(cy)) / ry
			# 두 파장으로 반지름을 흔든다 — 한 겹만 쓰면 규칙적인 물결이 남는다
			var wob := 0.86 + m._hash01(x * 5 + 3, y * 7 + 1) * 0.16 \
				+ m._hash01(x / 2 * 11 + 5, y / 2 * 13 + 7) * 0.14
			if dx * dx + dy * dy <= wob * wob:
				m.grid[y][x].ground = "water"
				m.objects.erase(Vector2i(x, y))


# 강을 판다 — 굽이치는 띠.
#
# 웅덩이가 타원이라면 강은 **길이 있는 물**이다. 시작점에서 끝점까지
# 조금씩 흔들리며 나아가되, 폭도 함께 흔든다. 폭이 일정하면 강이 아니라
# 수로가 된다.
func _carve_river(x0: int, y0: int, x1: int, y1: int, w: float) -> void:
	var steps := int(max(abs(x1 - x0), abs(y1 - y0)))
	if steps <= 0:
		return
	for i in steps + 1:
		var t := float(i) / float(steps)
		# 두 파장으로 굽이친다 — 한 겹만 쓰면 규칙적인 물결이 된다
		var bend := sin(t * PI * 2.4) * 4.0 + sin(t * PI * 5.7) * 1.8
		var cx := int(round(lerpf(float(x0), float(x1), t) + bend))
		var cy := int(round(lerpf(float(y0), float(y1), t) - bend * 0.35))
		var rad := w * (0.78 + m._hash01(cx * 7 + 1, cy * 11 + 3) * 0.5)
		var ri := int(ceil(rad))
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var px := cx + dx
				var py := cy + dy
				if px < 1 or py < 1 or px >= m.MAP_W - 1 or py >= m.WORLD_H - 1:
					continue
				if m.VILLAGE_REGION.has_point(Vector2i(px, py)) \
					or m.ROAD.has_point(Vector2i(px, py)):
					continue
				if float(dx * dx + dy * dy) > rad * rad:
					continue
				m.grid[py][px].ground = "water"
				m.objects.erase(Vector2i(px, py))


func _build_village() -> void:
	# 흙길은 더 이상 깔지 않는다 — 마을 바닥은 잔디이고, 길·광장 바닥은
	# 앞으로 플레이어가 직접 타일을 깔아 꾸미는 구조로 간다.
	# 광장 한가운데 분수
	# 분수만은 네모로 둔다 — 사람이 만든 것이라 자로 잰 게 맞다
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
	# 이장의 거처 — 처음부터 있는 집 (마을의 유일한 지붕)
	m.objects[m.CHIEF_HUT] = {"kind": "chief_hut", "hp": 0}
	# 그림이 덮는 칸을 막는다. 안 막으면 512x552 짜리 집 안으로 걸어
	# 들어가진다 (예전 오두막은 한 칸짜리라 이럴 일이 없었다).
	# 문 칸만 남겨 둔다 — 거기서 이장을 부른다.
	_block_under_art(m.CHIEF_ART, Rect2i(m.CHIEF_HUT.x, m.CHIEF_HUT.y, 1, 1))
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
	# 마을 외곽에만 나무를 둔다 (생활 공간 안에는 나무/돌을 두지 않는다).
	# 줄 번호는 **마을 구역에서 잰다** — 예전에는 1과 43을 그대로 적어
	# 두었는데, 세계를 북쪽으로 열두 줄 내리면서 이 두 줄만 제자리에
	# 남아 지도 맨 위에 뜬금없는 나무 띠가 생겼다
	for x in range(m.VILLAGE_REGION.position.x + 4, m.VILLAGE_REGION.end.x - 1):
		for y in [m.VILLAGE_REGION.position.y + 1, m.VILLAGE_REGION.end.y - 1]:
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
# 집 둘레의 부지 — 다져진 흙 마당과 문 앞 오솔길.
#
# 집이 잔디 위에 그냥 얹혀 있으면 「놓아 둔 모형」으로 보인다. 사람이 사는
# 집 둘레에는 풀이 못 자란 자리가 생기고, 문 앞에서 큰길까지 길이 난다.
# 이 둘이 집을 땅에 앉힌다.
func _lay_yard(anchor: Vector2i) -> void:
	for y in range(anchor.y - 1, anchor.y + 6):
		for x in range(anchor.x - 2, anchor.x + 7):
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			var cell: Dictionary = m.grid[y][x]
			if cell.ground != "grass":
				continue                      # 길·물·밭·모래는 건드리지 않는다
			# 가장자리는 **자로 잰 듯하면 안 된다.** 바깥 한 겹을 확률로 빼서
			# 들쭉날쭉하게 만든다 (모서리일수록 많이 빠진다)
			var edge := 0
			if x == anchor.x - 2 or x == anchor.x + 6:
				edge += 1
			if y == anchor.y - 1 or y == anchor.y + 5:
				edge += 1
			if edge > 0 and m._hash01(x * 7 + 3, y * 11 + 5) < 0.4 * float(edge):
				continue
			cell.ground = "yard"
	# 문 앞에서 큰길까지 — 마당만 있고 길이 없으면 부지가 섬처럼 뜬다.
	# 아래로 먼저 찾고, 없으면 위로. 큰길에 닿는 쪽만 깐다
	var d: Vector2i = m.door_tile(anchor)
	for dir in [1, -1]:
		var run: Array[Vector2i] = []
		for k in range(1, 9):
			var t := Vector2i(d.x, d.y + dir * k)
			if t.y < 0 or t.y >= m.MAP_H:
				break
			var g: String = m.grid[t.y][t.x].ground
			if g == "path":
				for q: Vector2i in run:
					m.grid[q.y][q.x].ground = "path"
				return
			if g != "grass" and g != "yard":
				break
			run.append(t)


func _place_building_tiles(anchor: Vector2i) -> void:
	_lay_yard(anchor)
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
	for y2 in range(a.y + 4, mini(a.y + 11, m.WORLD_H - 1)):
		for x2 in [door.x, door.x + 1]:
			m.objnode._remove_object(Vector2i(x2, y2))
			if m.grid[y2][x2].ground == "grass":
				m.grid[y2][x2].ground = "path"
	_fill_building(a)
	m.objects.erase(m.door_tile(a))
	m.queue_redraw()


# 옛 농지 (메인 스토리 16) — 오래 묵어 잡초·돌·나무가 우거진 채 드러난다.
# 플레이어가 이미 쓰고 있던 칸(작물·설치물)은 건드리지 않는다.
func seed_old_farm() -> void:
	var r: Rect2i = m.OLD_FARM
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			if m.objects.has(p) or str(m.grid[y][x].crop_id) != "":
				continue
			if m.grid[y][x].ground != "grass":
				continue
			var h := m._hash01(x * 13 + 3, y * 17 + 9)
			if h < 0.34:
				m.objects[p] = {"kind": "weed", "hp": 0}
			elif h < 0.5:
				m.objects[p] = {"kind": "rock", "hp": m.ROCK_HP}
			elif h < 0.6 and _nature_clear(p, "tree"):
				m.objects[p] = {"kind": "tree", "hp": m.TREE_HP}
	m.objnode._spawn_objects()
	m.queue_redraw()


# 옛 헛간 (메인 스토리 17) — 목장 남쪽에 방치된 헛간. 둘레엔 잡동사니가
# 쌓여 있다 (치울 거리 = 잡초·돌)
func spawn_old_barn() -> void:
	if str(m.objects.get(m.OLD_BARN, {}).get("kind", "")) == "old_barn":
		return
	var r: Rect2i = m.OLD_BARN_AREA
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			if m.objects.has(p) or m.grid[y][x].ground != "grass":
				continue
			var h := m._hash01(x * 7 + 5, y * 11 + 2)
			if h < 0.3:
				m.objects[p] = {"kind": "weed", "hp": 0}
			elif h < 0.42:
				m.objects[p] = {"kind": "rock", "hp": m.ROCK_HP}
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			m.objects.erase(m.OLD_BARN + Vector2i(dx, dy))
	m.objects[m.OLD_BARN] = {"kind": "old_barn", "hp": 0}
	m.objnode._spawn_objects()
	m.queue_redraw()


# 옛 세이브에 남아 있는 「오래된 돌문」을 걷어낸다.
#
# 돌문은 한때 마을 북쪽에 서 있는 오브젝트였지만, 상점 마당과 겹쳐
# 길을 막는 일이 잦아 **세계에서 완전히 없앴다**. 스토리 20의 그 문은
# 이제 동굴 가장 깊은 곳에 있고, 동굴 입구에서 이야기가 이어진다.
# 예전 세이브를 불러오면 이 함수가 남은 돌문을 지운다.
func purge_old_gate() -> void:
	for t: Vector2i in m.objects.keys():
		if str(m.objects[t].get("kind", "")) == "old_gate":
			m.objnode._remove_object(t)
			m.objects.erase(t)


# 할아버지의 씨앗에서 돋은 새싹 (메인 스토리 20) — 엔딩 뒤에도 남는다
func spawn_seed_sprout() -> void:
	var t: Vector2i = GameData.seed_tile
	if t.x < 0 or m.objects.has(t):
		return
	m.objects[t] = {"kind": "seed_sprout", "hp": 0}
	m.objnode._spawn_object_node(t, "seed_sprout")
	m.queue_redraw()


# 옛 전망대 (메인 스토리 18) — 단서를 다 모으면 언덕 위에 드러난다.
# 전망대 하나와 흔적 세 곳(무너진 의자·새겨진 돌·굽은 나무)이 서고,
# 둘레는 걸어 다닐 수 있게 비운다.
func spawn_hill() -> void:
	if str(m.objects.get(m.HILL_POS, {}).get("kind", "")) == "old_lookout":
		return
	var r: Rect2i = m.HILL_AREA
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			m.objnode._remove_object(Vector2i(x, y))
	m.objects[m.HILL_POS] = {"kind": "old_lookout", "hp": 0}
	m.objects[m.HILL_TRACE_TILES["bench"]] = {"kind": "old_bench", "hp": 0}
	m.objects[m.HILL_TRACE_TILES["stone"]] = {"kind": "carved_stone", "hp": 0}
	m.objects[m.HILL_TRACE_TILES["tree"]] = {"kind": "bent_tree", "hp": 0}
	m.objnode._spawn_objects()
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
	# 그림은 512 폭에 0.5배로 그려 화면에서는 256(8칸)을 덮는다.
	# 다른 오브젝트와 같은 2:1 축소라 점이 흔들리지 않는다.
	#
	# 세로 오프셋은 **그림 높이에서 가져온다.** 410으로 박아 뒀더니 지붕을
	# 뒤로 더 눕히려고 그림을 키운 순간 집이 땅에 파묻혔다 — 밑변을 문 앞에
	# 맞추는 값이라 그림이 자라면 같이 자라야 한다.
	var htex: Texture2D = m.tex[tname]
	var hn: Node2D = m.objnode._make_object(htex,
		Vector2(anchor.x * m.TILE, (anchor.y + 4) * m.TILE),
		Vector2(0, -float(htex.get_height())))
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
# 잡초는 화분·빗자루의 재료라 흔해야 한다 — 70포기로는 온 들판을 뒤져야 했다
const NATURE_CAP := {"tree": 260, "rock": 120, "weed": 220}
# 자연물이 절대 나면 안 되는 곳 — 스토리 숲길(길목이 도로 막히면 안 된다)
# 자연물이 다시 나면 안 되는 자리 — 농장 앞마당, 옛 전망대 언덕(m.HILL_AREA)
# 세계가 북쪽으로 밀린 만큼 여기도 민다 (밭 언저리 · 언덕 자리).
# m.NORTH_PAD 로는 못 쓴다 — 멤버 초기화는 m 이 꽂히기 전에 돌아간다.
const NO_SPAWN_RECTS: Array[Rect2i] = [
	Rect2i(3, 12 + KyojinMain.NORTH_PAD, 45, 9),
	Rect2i(26, 1 + KyojinMain.NORTH_PAD, 11, 6)]


# 이 칸에 자연물이 나도 되는가 — 나무/돌/잡초가 전부 같은 검사를 쓴다.
# 건물·문 앞·통행로·농작물·설치물·다른 자연물·물가를 전부 피한다.
func _respawn_ok(pos: Vector2i, kind: String, clear_dist := -1) -> bool:
	if pos.x < 1 or pos.y < 1 or pos.x >= m.MAP_W - 1 or pos.y >= m.WORLD_H - 1:
		return false
	var cell: Dictionary = m.grid[pos.y][pos.x]
	if m.objects.has(pos) or cell.ground != "grass" or str(cell.crop_id) != "":
		return false
	if m.VILLAGE_REGION.has_point(pos) or m.ROAD.has_point(pos) \
			or m.FISH_CLEAR.has_point(pos) or m.GREENHOUSE.has_point(pos):
		return false  # 마을·큰길·낚시터 어귀·온실 터에는 나지 않는다
	if pos in m.SEA_GATE or pos.y == m.SEA_RIDGE_Y:
		return false  # 바다로 내려가는 길목은 어떤 것도 막지 않는다
	for r: Rect2i in NO_SPAWN_RECTS:
		if r.has_point(pos):
			return false
	# 랜드마크 앞도 비워 둔다 — 화면 열두 칸짜리 그림 앞에 산딸기 한 포기가
	# 돋아도 그림이 가려진다. 그림은 밑변이 기준이라 **위로** 높이 뻗으므로
	# 위쪽을 넉넉히 잡는다 (_build_landmarks 와 같은 규칙)
	for lm: Dictionary in m.LANDMARKS:
		var lc: int = int(lm.clear)
		if lc <= 0:
			continue
		var lt: Vector2i = lm.tile
		if absi(pos.x - lt.x) <= lc and pos.y <= lt.y + 2 and pos.y >= lt.y - lc * 2:
			return false
	# 마을 밖 집(재민의 집·숲속의 집·연금술사의 오두막) 문 앞도 비워 둔다
	for anchor: Vector2i in [GameData.move_house, m.FOREST_HOUSE_ANCHOR,
			m.ALCH_HOUSE_ANCHOR]:
		if anchor.x >= 0 and (pos - m.door_tile(anchor)).length() < 3.0:
			return false
	# 눈앞에서 불쑥 돋지 않게 (세계를 처음 지을 때는 아직 주인공이 없다)
	if m.player != null and (pos - m.player_tile()).length() < 4.0:
		return false
	if not _nature_clear(pos, kind if kind != "weed" else "rock", clear_dist):
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
			var pos := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.WORLD_H - 2))
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
	# 잡초 자연 발생 — 아침마다 한 움큼씩 무성하게 돋는다 (같은 검사로).
	# 비 오는 날은 그 두 배로 돋는다 — 젖은 땅이 풀을 부른다.
	var wet: bool = m.weather_now() in [GameData.WEATHER_RAIN, GameData.WEATHER_STORM]
	var weed_want := 18 if wet else 9
	var weed_sprouts := 0
	for attempt in weed_want * 6:
		if weed_sprouts >= weed_want or _nature_count("weed") >= int(NATURE_CAP["weed"]):
			break
		var pos2 := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.WORLD_H - 2))
		if _respawn_ok(pos2, "weed"):
			m.objnode._place_object(pos2, "weed", 0)
			weed_sprouts += 1


# 지금 날씨가 받쳐 주는 채집물 상한
func forage_cap_now() -> int:
	var w := m.weather_now()
	if w == GameData.WEATHER_RAIN or w == GameData.WEATHER_STORM:
		return m.FORAGE_CAP_RAIN
	if w == GameData.WEATHER_FOG:
		return m.FORAGE_CAP_FOG
	return m.FORAGE_CAP


func forage_count() -> int:
	var n := 0
	for pos in m.objects:
		if String(m.objects[pos].kind).begins_with("forage_"):
			n += 1
	return n


# 채집물이 돋을 자리 하나. **절반은 사람이 다니는 데 가까이** 뽑는다 —
# 세계 전체에 고루 뿌리면 정작 지나다니는 길에서는 아무것도 못 본다.
func _forage_spot() -> Vector2i:
	if randf() < 0.55:
		# 세계를 처음 지을 때는 아직 주인공이 없다 — 그때는 농장 자리를 기준으로
		var c: Vector2i = m.player_tile() if m.player != null else m.START_TILE
		return Vector2i(clampi(c.x + randi_range(-26, 26), 1, m.MAP_W - 2),
			clampi(c.y + randi_range(-20, 20), 1, m.WORLD_H - 2))
	return Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.WORLD_H - 2))


# 이 자리에 채집물이 돋아도 되는가.
#
# 나무·돌과 **같은 검사**를 쓴다 (`_respawn_ok`) — 낚시터 어귀·온실 터·
# 문 앞·바닷길 길목처럼 비워 둬야 하는 자리를 한 군데서 관리한다.
# 예전에는 여기만 따로 「마을과 큰길만 피한다」였는데, 상한을 올리자마자
# 낚시터로 내려가는 길이 산딸기로 막혔다.
func _forage_ok(pos: Vector2i) -> bool:
	# 간격은 **한 칸**이면 된다. 풀 한 포기와 열매 한 알은 나무·바위처럼
	# 길을 막지 않는다 — 나무 간격(네 칸)을 그대로 쓰면 온 들판이 「자리 없음」이 된다.
	if not _respawn_ok(pos, "weed", 1):
		return false
	# 아직 이야기가 닿지 않은 땅에는 돋지 않는다 — 가지도 못하는 곳에
	# 상한을 채워 버리면 정작 다닐 수 있는 들판이 텅 빈다
	return m.region_open_at(pos) and GameData.is_tile_owned(pos.x, pos.y)


# 채집물 한 포기를 놓는다 (자리 검사는 부르는 쪽이 이미 했다)
func _place_forage(pos: Vector2i, with_node := true) -> void:
	# 산딸기 절반 · 약초 셋 중 하나 · 잡초 나머지 (화분 재료라 흔하게).
	# 다만 **북쪽 산자락**(MOUNTAIN_Y 위)에서는 민들레가 절반쯤 돋는다 —
	# 산에서만 볼 수 있는 노란 꽃이다.
	var roll := randf()
	var kind := "forage_berry" if roll < 0.5 \
		else ("forage_herb" if roll < 0.8 else "weed")
	if pos.y <= m.MOUNTAIN_Y:
		kind = "forage_dandelion" if roll < 0.5 \
			else ("forage_herb" if roll < 0.7 else "weed")
	if with_node:
		m.objnode._place_object(pos, kind, 0)
	else:
		m.objects[pos] = {"kind": kind, "hp": 0}   # 노드는 뒤이어 _spawn_objects가 만든다


# 아침마다 열매/약초가 풀밭에 돋아난다 — 상한까지 한 번에 채운다.
# (예전에는 하루 여덟 번만 자리를 찔러 봐서, 상한을 올려도 며칠이 걸렸다)
func _respawn_forage(with_node := true) -> void:
	var cap := forage_cap_now()
	var count := forage_count()
	# 나무·돌이 빽빽한 세계에서는 열 번에 한 번쯤만 자리가 난다 —
	# 시도를 넉넉히 잡아야 아침마다 상한을 실제로 채운다
	var tries: int = maxi(200, (cap - count) * 25)
	for attempt in tries:
		if count >= cap:
			break
		var pos := _forage_spot()
		if not _forage_ok(pos):
			continue
		_place_forage(pos, with_node)
		count += 1


# 비가 오는 동안에는 하루 내내 조금씩 더 돋는다 (main이 게임 시간
# RAIN_FORAGE_MINUTES마다 부른다). 비를 맞으며 걷다 보면 방금 지나온
# 풀밭에도 새로 돋아 있는 — 「비 오는 날은 나가서 줍는 날」이 된다.
func _tick_rain_forage() -> void:
	var cap := forage_cap_now()
	var count := forage_count()
	var grown := 0
	for attempt in 200:
		if count >= cap or grown >= 6:
			break
		var pos := _forage_spot()
		if not _forage_ok(pos):
			continue
		_place_forage(pos)
		count += 1
		grown += 1


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
				randi_range(2, m.WORLD_H - 2) * m.TILE)
			m.bugs.append(bnode)
			m.world.add_child(bnode)


# 옛 저장 정리: 축사를 크게 다시 그리면서 자리를 옮겼고,
# 농장의 출하 상자는 아예 없앴다 (판매는 마을 잡화점에서 한다).
# 오브젝트는 통째로 저장되므로, 불러올 때 한 번 자리를 맞춰 준다.
func _migrate_farm_layout() -> void:
	const OLD_BARN := Vector2i(10, 3)   # 헛간 안 실내 좌표 — 세계 좌표가 아니다
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
