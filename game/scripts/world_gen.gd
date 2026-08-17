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
			# tx/ty — 칸이 **제 좌표를 안다.** 하루가 넘어갈 때 밭 칸 목록만
			# 돌면서 온실 안인지 따위를 물어야 하는데, 목록에는 칸만 들어
			# 있어서 좌표를 되찾을 길이 없었다 (그래서 지도를 다시 훑었다)
			row.append({"ground": "grass", "watered": false, "wet_min": 0.0,
				"crop_id": "", "crop_day": 0.0, "dead": false, "half_fed": false,
				"tx": x, "ty": y})
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

	await m.mark_build("높낮이를 잡는 중…", 0.48)
	_build_levels()
	await m.mark_build("마을 터를 놓는 중…", 0.56)
	_build_village()

	# 농장 -> 마을 이음새는 잔디 그대로 둔다 (흙길은 깔지 않는다 —
	# 바닥 타일은 앞으로 플레이어가 직접 깐다. m.ROAD 직사각형은
	# 자연물이 스폰되지 않는 통행로로 계속 쓰인다)

	# 동굴 (출하 상자는 없앴다 — 판매는 마을 잡화점에서 한다).
	# 자리를 정할 때까지는 놓지 않는다 (main.CAVE_PLACED 참고)
	if m.CAVE_PLACED:
		m.objects[m.CAVE_POS] = {"kind": "cave", "hp": 0}
	m.objects[m.WORLDTREE_POS] = {"kind": "worldtree", "hp": 0}

	await m.mark_build("숲을 심는 중…", 0.64)
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
			if m.spawn_blocked(x, y):
				continue  # 그림·계단·길이 차지한 자리
			# 잔디가 아닌 바닥(길·마당·모래·자갈)에는 아무것도 안 둔다.
			#
			# **이 검사가 예전에는 지역 밖에서만 돌았다.** 지역(REGIONS) 안이면
			# 통째로 건너뛰어서, 깔아 놓은 길이든 돌계단이든 그 위에 나무가
			# 돋았다 — 촛대바위의 계단이 바로 지역 한복판이다
			if m.grid[y][x].ground != "grass":
				continue
			var reg := _region_at(pos)
			var h := m._hash01(x * 3 + 7, y * 5 + 11)
			var tree_p := 0.05
			var rock_p := 0.09          # 나무 확률 위에 이어 붙는 문턱값
			if not reg.is_empty():
				# 줄지어 심은 땅(과수원)은 격자 위에만 선다 — 그 사이는 훤히 비운다
				var g := int(reg.grid)
				if g > 0 and (x % g != 0 or y % g != 0):
					continue
				tree_p = float(reg.tree)
				rock_p = float(reg.rock)
			# ---- **덩어리로** 난다 ----
			#
			# 확률 하나로 온 세계에 뿌리면 어디를 가나 똑같이 성긴 숲이다 —
			# 걸어도 걸어도 같은 풍경이라 「저기는 뭐가 있나」가 안 생긴다.
			# 진짜 숲은 빽빽한 데와 훤한 데가 갈린다.
			#
			# 굵은 얼룩 둘을 곱한다: 스물여섯 칸짜리(수풀이 우거진 골)와
			# 열 칸짜리(그 안의 덤불). 평균은 1이고 0에서 2.5까지 벌어지므로,
			# 같은 밀도를 두고도 밀림과 빈터가 함께 나온다
			var clump: float = clampf(_vnoise(x, y, 26, 5) * 2.0
				* _vnoise(x, y, 10, 137) * 2.0, 0.0, 2.5)
			tree_p *= clump
			rock_p = tree_p + rock_p * clump
			if h < tree_p:
				if _nature_clear(pos, "tree"):
					m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP}
			elif h < rock_p:
				if _nature_clear(pos, "rock"):
					m.objects[pos] = {"kind": "rock", "hp": m.ROCK_HP}

	# 낚시터 둘레는 마지막에 비운다 — 나무/돌 그림이 부두와 강을 덮으면 안 된다.
	# (자연물 배치가 모두 끝난 뒤라야 확실히 비워진다)
	# **저절로 난 것만** 걷는다. 여기서 통째로 지웠더니 낚시터 네모의 동쪽
	# 끝(x=60)에 걸친 **여관 건물의 왼쪽 한 줄**까지 같이 날아갔다 —
	# 부지 아홉 곳 중 여관 한 곳만 건물이 안 서던 것이 이것이었다.
	for p: Vector2i in m.objects.keys():
		if m.FISH_CLEAR.has_point(p) and _is_wild(str(m.objects[p].kind)):
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

	# ---- 마지막 비질 ----
	#
	# 「여기는 비워라」를 자리마다 따로 적어 왔다 — 랜드마크는 clear 로,
	# 낚시터는 다 흩고 나서 지우기로, 계단은 is_ramp 로. 새 자리를 만들 때마다
	# 그 예외를 어딘가에 또 적어야 했고, 한 군데만 빠뜨리면 그림 위에 나무가
	# 섰다. 못박아 둔 판(no_spawn)을 **한 번에 훑어** 쓸어 낸다.
	#
	# 순서가 중요하다. 랜드마크·마을·바다까지 다 세운 **뒤**라야, 그 사이에
	# 새로 놓인 것도 같이 걸린다.
	sweep_blocked_nature()

	_build_sea()
	# 채집물은 첫날부터 들판에 흩어져 있다. 예전에는 세계를 지을 때
	# 한 포기도 두지 않아, 새 농장의 첫날은 산딸기 한 알 없는 빈 들판이었다.
	# (아직 화면도 주인공도 없는 시점이라 노드는 만들지 않는다)
	_respawn_forage(false)


# 그림·계단·길 위에 선 자연물을 쓸어 낸다.
#
# **세이브를 편 뒤에도 부른다.** 오브젝트는 통째로 저장되므로, 계단을 새로
# 놓기 전에 저장한 세계를 열면 그 자리에 옛 나무와 바위가 그대로 살아난다 —
# 새로 시작한 사람만 깨끗하고 이어서 하는 사람은 계단이 막혀 있게 된다.
# 저절로 난 것인가 (나무·돌·잡초·채집물). 사람이 놓은 것 — 표지판·석등·
# 건물·그림 — 은 「비우기」의 대상이 아니다.
#
# 이 구분이 없어서 랜드마크 둘레를 비우는 한 줄이 방금 세운 석등까지
# 지웠다. 「비운다」는 말이 두 가지를 뜻하고 있었던 것이다
func _is_wild(kind: String) -> bool:
	return kind == "tree" or kind == "rock" or kind == "weed" \
		or kind == "bigrock" or kind.begins_with("forage_")


func _clear_wild(x: int, y: int) -> void:
	var p := Vector2i(x, y)
	if m.objects.has(p) and _is_wild(String(m.objects[p].kind)):
		m.objects.erase(p)


func sweep_blocked_nature() -> void:
	var swept := 0
	for p2: Vector2i in m.objects.keys():
		if not m.spawn_blocked(p2.x, p2.y):
			continue
		if not _is_wild(String(m.objects[p2].kind)):
			continue          # 사람이 놓은 것(표지판·석등·그림)은 그대로 둔다
		if m.obj_nodes.has(p2):
			m.objnode._remove_object(p2)
		else:
			m.objects.erase(p2)
		swept += 1
	if swept > 0:
		print("[자연물] 그림·계단·길 위에 있던 %d개를 치웠다" % swept)


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
	m.no_spawn = PackedByteArray()
	m.no_spawn.resize(m.MAP_W * m.MAP_H)
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
	# 폭은 **네 칸**. 두 칸이면, 벼랑면이 두 칸 높이가 된 지금은 계단이
	# 벽 사이에 낀 틈처럼 보인다 — 실제로 「계단이 묻혔다」고 보였다
	_cut_ramp(33, 5 + m.NORTH_PAD, 4)
	_cut_ramp(51, 63 + m.NORTH_PAD, 4)
	_cut_ramp(60, 63 + m.NORTH_PAD, 4)
	_cut_ramp(190, 52 + m.NORTH_PAD, 4)
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
	var stairs: Array = []          # [x, yb, 폭] — 석등을 세울 자리
	for lm2: Dictionary in m.LANDMARKS:
		var t2: Dictionary = lm2.get("terrain", {})
		var tw: int = int(t2.get("width", 2))
		var lit: bool = bool(t2.get("lamps", false))
		for r: Array in t2.get("ramps", []):
			var yb := _cut_ramp(int(r[0]), int(r[1]), tw)
			if lit and yb >= 0:
				stairs.append([int(r[0]), yb, tw])
	# ---- 벼랑면 위에는 아무것도 안 난다 ----
	#
	# 벼랑면은 「위 칸이 더 높다」는 표시로 **아랫 칸에** 그리는 그림이다.
	# 그 칸의 바닥은 여전히 잔디라, 나무도 바위도 거기 돋았다 — 바위벽
	# 한복판에 바위가 박히고 나무가 벽에서 자랐다.
	# 이제 벽이 **두 칸**이라 더 크게 눈에 띈다. 통행은 이미 막아 두었으니
	# (main.gd `_cliff_foot`) 심기는 것만 막으면 된다.
	# 벼랑면뿐 아니라 **켜가 바뀌는 자리 둘레 전체**를 비운다.
	#
	# 나무 한 그루의 그림은 두 칸 반이고 밑변이 칸에 맞는다. 마루(위쪽 땅의
	# 가장자리)에 서면 잎이 벼랑면을 통째로 덮고, 발치에 서면 밑동이 벽에
	# 파묻힌다 — 어느 쪽이든 「경계에 걸친」 꼴이다. 경계는 지형이 말하는
	# 자리라, 거기만은 훤히 비워 두는 편이 낫다
	for y in range(1, m.MAP_H - 1):
		for x in range(1, m.MAP_W - 1):
			var lv0 := _lv(x, y)
			var edge := false
			for o: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0),
					Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1),
					Vector2i(-1, 1), Vector2i(1, 1)]:
				if _lv(x + o.x, y + o.y) != lv0:
					edge = true
					break
			if not edge:
				continue
			_no_spawn_rect(x, y, x, y, 1)
			# 벼랑면은 아래로 두 칸을 덮는다 — 그 밑까지 비운다
			if _lv(x, y - 1) > lv0:
				_no_spawn_rect(x, y + 1, x, y + 2, 1)

	# 층계참을 잇는 길 — 오르막을 낸 뒤라야 그 발치까지 이어 붙는다
	for lm3: Dictionary in m.LANDMARKS:
		var tr: Dictionary = lm3.get("terrain", {})
		for chain: Array in tr.get("paths", []):
			_lay_path(chain, int(tr.get("width", 2)))
	# ---- 석등 — **계단마다 한 쌍씩만** ----
	#
	# 길을 따라 대여섯 칸마다 죽 세웠더니 층계참이 등으로 뒤덮였다. 참고
	# 사진의 등은 **계단을 따라** 서 있지 온 산에 서 있는 게 아니다.
	# 계단 넷에 여덟이면 「여기가 오르는 자리다」는 충분히 말한다.
	#
	# 길을 다 깐 **뒤에** 세운다 — _lay_path 가 지나는 자리의 물건을 쓸어
	# 내므로, 먼저 세우면 방금 세운 등을 제가 지운다
	for st: Array in stairs:
		var sx := int(st[0])
		# 계단 **한 칸 위**(윗단 쪽)에 세운다.
		#
		# 벼랑 마루 줄(yb)에 세우려 했더니 여덟 자리 중 다섯이 빠졌다 —
		# 대지 가장자리가 흔들려 있어서, 계단에서 두어 칸만 옆으로 가도
		# 그 줄은 이미 벼랑 아래였다. 한 줄 위는 윗단이 통으로 이어져 있다.
		#
		# 아래쪽(yb+2)에는 세우지 않는다. 그림이 위로 두 칸 넘게 뻗으므로
		# 계단 남쪽에 서면 제 몸으로 계단을 덮는다
		var sy := maxi(1, int(st[1]) - 1)
		var sw := int(st[2])
		# 양옆으로 **한 자리씩 밀어 가며** 설 데를 찾는다. 대지 가장자리가
		# 흔들려 있어서 「계단에서 두 칸 옆」이 벼랑 밖일 때가 있다 —
		# 한 자리만 보고 말면 계단 넷 중 둘은 등이 없이 남는다
		for dir: int in [-1, 1]:
			for step in 3:
				var lx: int = sx - 2 - step if dir < 0 else sx + sw + 1 + step
				if lx < 1 or lx >= m.MAP_W - 1 or m.objects.has(Vector2i(lx, sy)):
					continue
				# 벼랑 밖이면 등이 허공에 뜨고, 계단 위면 길을 막는다
				if _lv(lx, sy) != _lv(sx, sy) or (m.terrain_level[sy][lx] & 8) != 0:
					continue
				if m.grid[sy][lx].ground == "water" or _lamp_hides_stairs(lx, sy):
					continue
				m.objects[Vector2i(lx, sy)] = {"kind": "deco_stonelamp", "hp": 0}
				_no_spawn_rect(lx, sy, lx, sy, 1)
				break
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


# 자연물 금지 칸을 못박는다 (여백을 함께 준다 — 그림은 밑동보다 넓다)
# 부드러운 값잡음 (칸 크기 cell). 굵은 얼룩을 만들 때 쓴다.
#
# m._hash01(x / 9, y / 9) 처럼 나눗셈으로 뭉치면 아홉 칸짜리 **네모**가
# 그대로 보인다 — 숲이 바둑판이 된다. 격자점 넷을 부드럽게 이어야 얼룩이
# 얼룩으로 보인다
func _vnoise(x: int, y: int, cell: int, seed: int) -> float:
	var gx := float(x) / float(cell)
	var gy := float(y) / float(cell)
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var u := gx - x0
	var v := gy - y0
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := m._hash01(x0 + seed, y0 + seed)
	var b := m._hash01(x0 + 1 + seed, y0 + seed)
	var c := m._hash01(x0 + seed, y0 + 1 + seed)
	var d := m._hash01(x0 + 1 + seed, y0 + 1 + seed)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func _no_spawn_rect(x0: int, y0: int, x1: int, y1: int, pad := 0) -> void:
	for y in range(maxi(0, y0 - pad), mini(m.MAP_H, y1 + pad + 1)):
		var b := y * m.MAP_W
		for x in range(maxi(0, x0 - pad), mini(m.MAP_W, x1 + pad + 1)):
			m.no_spawn[b + x] = 1


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
			# 흔들림을 **크게 몇 번**으로. 잔 흔들림(a*8)이 크면 가장자리가
			# 두세 칸씩 들쭉날쭉해지는데, 벼랑면이 한 칸일 때는 그게 「거친
			# 벼랑」이었지만 두 칸이 되고 나서는 **회색 덩어리가 뚝뚝 끊겨**
			# 놓인 것처럼 보인다. 벽은 이어져야 벽이다
			var w := 0.90 + m._hash01(int(round(a * 3.0)), seed) * 0.15 \
				+ m._hash01(int(round(a * 7.0)), seed + 1) * 0.06
			var d := pow((x - cx) / (rx * w), 2.0) + pow((y - cy) / (ry * w), 2.0)
			if d <= 1.0 and _lv(x, y) > 0:
				_set_lv(x, y, to)
	# 뾰족하게 튀어나온 칸을 다듬는다. 흔들어 놓은 가장자리는 한두 칸짜리
	# 돌기를 남기는데, 그건 벼랑이 아니라 그리다 만 자국으로 보인다
	var x0: int = maxi(1, cx - int(rx) - 3)
	var x1: int = mini(m.MAP_W - 1, cx + int(rx) + 4)
	var y0: int = maxi(1, cy - int(ry) - 3)
	var y1: int = mini(m.MAP_H - 1, cy + int(ry) + 4)
	for _pass in 4:
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


# 층계참을 잇는 길 — 이음점을 따라 **두 칸 폭**으로 다져 놓는다.
#
# 계단만 놓아 두면 층계참이 허허벌판이라 다음 계단이 어디인지 안 보인다.
# 사람이 다니면 풀이 죽고 흙이 드러난다 — 그 자국이 곧 안내다.
#
# 가로/세로로만 꺾는다. 비스듬한 길은 칸 단위 세계에서 톱니로 나오고,
# 무엇보다 **오르막이 세로로만 나므로** 길도 같은 결이라야 이어 붙는다.
func _lay_path(chain: Array, w := 2) -> void:
	for i in range(chain.size() - 1):
		var a: Array = chain[i]
		var b: Array = chain[i + 1]
		var x0: int = mini(int(a[0]), int(b[0]))
		var x1: int = maxi(int(a[0]), int(b[0]))
		var y0: int = mini(int(a[1]), int(b[1]))
		var y1: int = maxi(int(a[1]), int(b[1]))
		for y in range(y0, y1 + w):
			for x in range(x0, x1 + w):
				if x < 1 or y < 1 or x >= m.MAP_W - 1 or y >= m.MAP_H - 1:
					continue
				# 계단(오르막) 위에는 안 깐다 — 거기는 이미 돌계단이다.
				# 잔디가 아닌 데도 안 건드린다 (물 위로 길이 지나가면 안 된다)
				# **밟혀 다져진 흙(yard)** 으로 낸다.
				#
				# 처음엔 흙길(path)로 깔았는데 촛대바위 둘레는 채석장 지역이라
				# 바닥이 이미 흙길이었다 — 길을 깔았는데 아무것도 안 달라졌고,
				# 어디로 가야 다음 계단인지 여전히 안 보였다. 마당 흙은 자갈과
				# 색이 갈리고, 오르막(_cut_ramp)이 쓰는 바닥과도 같은 것이라
				# 계단 발치에서 자연스럽게 이어 붙는다.
				var gr: String = m.grid[y][x].ground
				if (m.terrain_level[y][x] & 8) == 0 and (gr == "grass" or gr == "path"):
					m.grid[y][x].ground = "yard"
				m.objects.erase(Vector2i(x, y))
				# 길 양옆 두 칸까지 비운다 — 나무 그림이 두 칸 반이라 바로
				# 옆에 서면 길을 통째로 덮는다
				_no_spawn_rect(x, y, x, y, 2)


# ---- 석등 — 길을 따라 **줄지어** 선다 ----
#
# 계단만 놓으면 「지형이 낮아졌다 높아졌다」로 보인다. 참고 사진에서 그 길을
# 길로 만드는 건 계단이 아니라 **양옆에 늘어선 등**이다. 같은 것이 일정한
# 간격으로 되풀이되면서 길의 방향과 길이를 한눈에 말해 준다 — 우리 집들이
# 처마 밑에 같은 창을 늘어놓아 「벽」을 말하는 것과 같은 일이다.
#
# 그래서 계단 끝에 한 쌍만 세우면 안 된다. 처음엔 그렇게 했는데, 대지
# 가장자리가 흔들려 있어 여덟 자리 중 넷이 벼랑 밖이라 빠지고, 남은 것도
# 길을 까는 손이 도로 지웠다 — 다섯 개가 흩어져 서 있으면 그건 줄이 아니다.
#
# 길은 가로/세로로만 꺾으므로, 등은 **길의 결과 직각으로** 한 칸 옆에 선다.
# 이 자리에 등을 세우면 **계단이 가려지는가.**
#
# 그림은 밑변을 칸에 맞추고 **위로** 뻗는다 (석등은 두 칸이 조금 넘는다).
# 그래서 계단 **남쪽**에 선 등은 제 몸으로 계단을 덮는다 — 「계단보다 앞에
# 있거나 계단을 가리는 경우」가 이것이다. 옆으로도 그림 폭만큼은 떨어져야
# 계단 어깨를 안 문다.
func _lamp_hides_stairs(lx: int, ly: int) -> bool:
	for dy in range(0, 4):                 # 제 자리와 **위쪽 세 칸**
		for dx in range(-1, 2):
			var x := lx + dx
			var y := ly - dy
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			if (m.terrain_level[y][x] & 8) != 0:
				return true
	# 큰 그림 곁에도 서지 않는다. 돌무지 바로 뒤에 세우면 그 그림에 가려
	# 보이지도 않고, 삐져나오면 그것대로 지저분하다.
	#
	# **놓인 물건이 아니라 표를 본다.** 석등은 지형을 지을 때 세우고
	# 랜드마크는 한참 뒤에 세우므로, 이 시점에 m.objects 를 뒤져 봐야
	# 거기엔 아직 아무것도 없다 (그래서 돌무지 바로 뒤에 하나가 섰다)
	for lm: Dictionary in m.LANDMARKS:
		if String(lm.kind) == "":
			continue
		var at: Vector2i = lm.tile
		var art: Vector2i = lm.get("art", Vector2i(3, 3))
		if absi(lx - at.x) <= art.x / 2 + 2 \
				and ly <= at.y + 2 and ly >= at.y - art.y - 1:
			return true
	return false



# 오르막 — 벼랑을 끊고 내려오는 자리.
#
# **두 칸 폭**으로 낸다. 한 칸이면 양옆 바위벽이 서로 맞물려 길이 막힌다.
# 그리고 그 두 칸의 경계를 한 줄에 맞춘다 — 어긋나면 오르막이 비뚤어진다
func _cut_ramp(x: int, near_y: int, w := 2) -> int:
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
		return -1
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
			m.objects.erase(Vector2i(cx, ry))
		# 계단 **양옆 두 칸**까지 비운다. 나무 한 그루의 그림은 두 칸 반이라,
		# 바로 옆에 서 있으면 잎이 계단을 통째로 덮는다 — 올라가는 길이
		# 보이지 않으면 올라갈 수 있다는 것도 모른다
		_no_spawn_rect(cx, yb - 2, cx, yb + 3, 3)
	return yb


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
# 그림 한 장이 **몇 칸을 덮는가.**
#
# 손으로 적어 둔 clear 값으로만 비우고 있었는데, 그림을 키우면 그 값을 같이
# 고쳐야 한다는 걸 아무도 안 알려 준다 — 촛대바위를 7.75칸에서 9.5칸으로
# 키운 순간 양옆 한 칸씩이 비워지지 않았다.
#
# 그래서 표(LANDMARKS.art)에 **칸 수를 적어 둔다.** 텍스처에서 재 오는 게
# 더 깔끔해 보이지만, .import 가 없으면 load()가 null 을 주고 그러면 둘레를
# 통째로 안 비우게 된다 — 그림이 안 보이는 것도 모자라 그 위에 나무까지
# 돋는다. 세계를 짓는 일이 PNG 하나에 매달리면 안 된다.
#
# 대신 그림이 있을 때는 **맞는지 견준다.** 도트 규칙이 「원본 4px = 화면
# 2px = 한 칸의 1/16」이라 칸 = 픽셀/64 다. 어긋나면 여기서 걸린다.
func _art_tiles(lm: Dictionary) -> Vector2i:
	var kind := String(lm.kind)
	var art: Vector2i = lm.get("art", Vector2i.ZERO)
	if kind == "":
		return Vector2i.ZERO
	var t: Texture2D = m.tex.get(kind + "_0", m.tex.get(kind))
	if t != null:
		var real := Vector2i(int(ceil(t.get_width() / 64.0)),
			int(ceil(t.get_height() / 64.0)))
		if real != art:
			push_error("[랜드마크] %s 그림이 %s칸인데 표에는 %s칸으로 적혀 있다 — "
				% [kind, real, art] + "LANDMARKS.art 를 고쳐라")
			return real
	elif art == Vector2i.ZERO:
		push_error("[랜드마크] %s — 그림도 없고 art 도 안 적혀 있다" % kind)
	return art


func _build_landmarks() -> void:
	for lm: Dictionary in m.LANDMARKS:
		var at: Vector2i = lm.tile
		var clear: int = int(lm.clear)
		# ① 둘레 비우기 — 그림은 밑변이 기준이라 **위로** 훨씬 높이 뻗는다.
		#    그래서 위쪽을 넉넉히, 아래쪽은 조금만 비운다
		for y in range(at.y - clear * 2, at.y + 3):
			for x in range(at.x - clear, at.x + clear + 1):
				_clear_wild(x, y)
		# ①-2 그림이 **실제로 덮는 자리**는 텍스처에서 재서 못박는다.
		#     clear 는 「둘레를 트이게」 하는 값이고, 이쪽은 「그림 위에
		#     나무가 돋지 않게」 하는 값이다 — 둘은 다른 일이다
		var art := _art_tiles(lm)
		if art != Vector2i.ZERO:
			_no_spawn_rect(at.x - art.x / 2, at.y - art.y + 1,
				at.x + art.x / 2, at.y + 1, 1)
			for y in range(maxi(0, at.y - art.y), mini(m.MAP_H, at.y + 3)):
				for x in range(maxi(0, at.x - art.x / 2 - 1),
						mini(m.MAP_W, at.x + art.x / 2 + 2)):
					_clear_wild(x, y)
		# ② 물
		for lake: Array in lm.lakes:
			_carve_pond(int(lake[0]), int(lake[1]), float(lake[2]), float(lake[3]))
		# 반드시 물이어야 하는 칸 — 못의 흔들린 가장자리가 여기를 비우면
		# 폭포가 벼랑에서 끊겨 보인다. 못을 판 **뒤에** 못박는다
		for sp: Rect2i in lm.get("spill", []):
			for sy in range(sp.position.y, sp.end.y):
				for sx in range(sp.position.x, sp.end.x):
					if sx < 1 or sy < 1 or sx >= m.MAP_W - 1 or sy >= m.WORLD_H - 1:
						continue
					m.grid[sy][sx].ground = "water"
					m.objects.erase(Vector2i(sx, sy))
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

		# 집 — **칸과 마당만** 여기서 만든다.
		#
		# 그림 노드는 못 세운다. 세계를 짓는 이 시점에는 아직 m.world 가
		# 없어서 _fill_building 을 부르면 add_child 가 null 에서 터진다.
		# 마을 가게(_build_village)가 _place_building_tiles 만 부르는 것과
		# 같은 이유다 — 그림은 뒤이어 _spawn_objects 가 세운다.
		for entry2: Array in h.houses:
			_place_building_tiles(entry2[0])

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
				# 바퀴 **아랫도리가 잠기는** 자리에 판다. 밑에만 파 두었더니
				# 바퀴가 물 위에 얹혀 헛도는 꼴이었다 — 물이 바퀴를 돌리려면
				# 바퀴가 물속에 들어가 있어야 한다.
				# 이미 무언가 놓인 칸(방앗간 그림)은 건드리지 않는다 —
				# 지웠다가는 집이 통째로 사라진다
				for wy in range(p.y - 2, p.y + 3):
					for wx in range(p.x - 3, p.x + 4):
						if m.objects.has(Vector2i(wx, wy)):
							continue
						if wx < 0 or wy < 0 or wx >= m.MAP_W or wy >= m.WORLD_H:
							continue
						m.grid[wy][wx].ground = "water"
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
	# ---- 길부터 깐다 ----
	#
	# 부지와 부지 사이로 3줄짜리 흙길이 지난다 (main.VILLAGE_ROADS).
	# **부지보다 먼저** 깔아야 한다: `_lay_yard` 는 잔디만 마당 흙으로 바꾸므로,
	# 길이 먼저 깔려 있으면 마당이 길을 덮지 않는다.
	#
	# 「마을 바닥은 잔디」라는 약속은 **부지 안**의 이야기다. 부지 사이까지
	# 잔디로 두면 집들이 잔디밭에 그냥 얹혀 있는 모형 줄로 보인다 —
	# 사람이 다녀 풀이 죽은 길이 있어야 마을이 된다.
	# 바닥은 **다져진 흙**("yard")이다. 자갈("path")로 깔아 봤더니 마을
	# 한복판에 회색 포장도로가 격자로 뻗어 도시가 됐다 — 여기는 사람이
	# 밟고 다녀 풀이 죽은 시골길이다. 마당과 같은 흙이라 마을이 한 덩어리로
	# 읽히고, 잔디와 닿는 자리는 그리기가 알아서 번지게 이어 준다.
	var lanes: Array = m.VILLAGE_ROADS.duplicate()
	lanes.append(m.ROAD)          # 농장에서 드는 큰길도 같은 길이다
	for lane: Rect2i in lanes:
		_paint_village_lane(lane)
	# 광장 한가운데 분수
	# 분수만은 네모로 둔다 — 사람이 만든 것이라 자로 잰 게 맞다
	for y in range(m.FOUNTAIN.position.y, m.FOUNTAIN.end.y):
		for x in range(m.FOUNTAIN.position.x, m.FOUNTAIN.end.x):
			m.grid[y][x].ground = "water"

	# (마을을 가르던 강과 다리는 전부 없앴다 — 물을 걷어낸 자리는
	#  잔디로 이어지고, 낚시터는 서쪽 호수로 옮겼다)

	# 마을 건물은 **처음부터 다 서 있다.** `village_built` 은 「문을 연 가게」
	# 라는 뜻만 남는다 — 건물은 있고 안이 비어 있다가, 이장이 사람을 들이면
	# 그때 장사가 시작된다.
	for pid: String in m.VILLAGE_PLOTS:
		_place_building_tiles(m.VILLAGE_PLOTS[pid].anchor)


	# **할아버지의 낡은 집** — 빈 터가 아니라 집이 서 있다.
	#
	# 예전에는 여기에 「집터」 표지판 하나를 꽂아 두고 목재를 모아 새로
	# 지었다. 그런데 이야기는 처음부터 「자네 할아버지가 지내던 집이 마을
	# 서쪽에 그대로 있네」라고 말한다 — 빈 터를 보여 주면 그 말이 거짓이 된다.
	# 집은 처음부터 서 있고, 오래 비워 둬서 낡았을 뿐이다. 플레이어가 할 일은
	# 짓는 것이 아니라 **보수**다 (village_ui._open_build_dialog).
	_place_building_tiles(m.HOME_ANCHOR)
	# 이장의 거처 — 처음부터 있는 집 (마을의 유일한 지붕)
	m.objects[m.CHIEF_HUT] = {"kind": "chief_hut", "hp": 0}
	# 그림이 덮는 칸을 막는다. 안 막으면 512x552 짜리 집 안으로 걸어
	# 들어가진다 (예전 오두막은 한 칸짜리라 이럴 일이 없었다).
	# 문 칸만 남겨 둔다 — 거기서 이장을 부른다.
	_block_under_art(m.CHIEF_ART, Rect2i(m.CHIEF_HUT.x, m.CHIEF_HUT.y, 1, 1))
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
	_plant_village_greenery()


# 부지와 부지 **사이**를 숲으로 채운다.
#
# 마을 구역 안에는 자연물을 한 포기도 두지 않았다. 부지가 다닥다닥 붙어
# 있던 시절에는 그게 맞았는데, 한 부지를 한 구역으로 벌려 놓고 나니
# 사이가 통째로 맨 잔디밭이 됐다 — 「이 집 다음 이 집」, 주택 단지다.
#
# 사진 속 마을은 집이 **제 환경을 두르고** 있다. 나무와 덤불 사이에 한 채가
# 서 있고, 다음 집까지는 숲 사이를 걸어간다. 그 사이를 여기서 심는다.
#
# 건드리지 않는 것: 길·광장·부지 울타리 안·문 앞 통로·잔디가 아닌 바닥.
# 길이 사방으로 뚫려 있으므로 나무가 부지를 가둘 일은 없다.
func _plant_village_greenery() -> void:
	var r: Rect2i = m.VILLAGE_REGION
	for y in range(maxi(1, r.position.y), mini(m.WORLD_H - 1, r.end.y)):
		for x in range(maxi(1, r.position.x), mini(m.MAP_W - 1, r.end.x)):
			var pos := Vector2i(x, y)
			if m.grid[y][x].ground != "grass":
				continue          # 흙길·자갈 마당·물은 그대로
			if m.objects.has(pos) or m.spawn_blocked(x, y):
				continue
			if m.PLAZA.has_point(pos) or m.ROAD.has_point(pos) or _on_village_road(pos):
				continue
			if _in_any_plot_ring(pos) or _is_plot_gateway(pos):
				continue
			# 길가 한 줄은 비워 둔다 — 나무 그림이 길을 덮으면 답답하다
			if _next_to_village_road(pos):
				continue
			var h := m._hash01(x * 3 + 11, y * 5 + 7)
			# 덩어리로 난다 (world_gen 의 흩뿌리기와 같은 결)
			var clump: float = clampf(_vnoise(x, y, 14, 23) * 2.2, 0.0, 2.2)
			if h < 0.26 * clump:
				if _nature_clear(pos, "tree"):
					m.objects[pos] = {"kind": "tree", "hp": m.TREE_HP}
			elif h < 0.26 * clump + 0.03:
				if _nature_clear(pos, "rock"):
					m.objects[pos] = {"kind": "rock", "hp": m.ROCK_HP}
			elif h < 0.42:
				# 풀숲 — 걸어 다니는 데 걸리지 않는 잔것.
				# **채집물(forage_*)은 심지 않는다.** 그건 하루 상한이 있는
				# 물건이라, 마을을 채운 만큼 들판이 텅 빈다 (LIVELY_OK 채집)
				m.objects[pos] = {"kind": "weed", "hp": 0}


# 마을 길에 붙은 칸인가 (길 양옆 한 줄은 비워 둔다)
func _next_to_village_road(t: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _on_village_road(t + d) or m.ROAD.has_point(t + d):
			return true
	return false


# 이 칸이 어느 부지의 울타리 테두리 안(문턱 한 줄 포함)인가
func _in_any_plot_ring(t: Vector2i) -> bool:
	for pid: String in m.VILLAGE_PLOTS:
		var a: Vector2i = m.VILLAGE_PLOTS[pid].anchor
		if Rect2i(a.x - m.YARD_PAD - 1, a.y - m.YARD_PAD - 1,
				5 + m.YARD_PAD * 2 + 2, 4 + m.YARD_PAD * 2 + 2).has_point(t):
			return true
	return false


# 건물 한 채의 마당: 그림 둘레 한 칸을 잔디로 고르고 울타리를 두른다.
# 문 앞 한 줄만 터 두고, 거기서 가장 가까운 길까지 흙길을 잇는다.
func _build_yard(anchor: Vector2i) -> void:
	# 마당 바닥을 잔디로 **되돌리지 않는다.** 예전에는 여기서 마당 네모를
	# 통째로 잔디로 칠해, `_lay_yard` 가 깔아 놓은 흙마당이 바깥 한 겹만
	# 남았다 — 집이 잔디밭에 얹힌 모형처럼 보이던 것이 이것이다.
	# 사람이 사는 집 둘레에는 풀이 못 자란 땅이 생긴다.
	#
	# **물만은 메운다.** 잔디로 칠하던 그 고리가 겸사겸사 하던 일이 있었다 —
	# 개울이 지나는 자리에 집을 앉히면 물을 땅으로 바꿔 주었다. 그 한 줄을
	# 빼자 숲속의 집 문 앞이 개울이 되어 문이 잠겼다.
	var yard := Rect2i(anchor.x - m.YARD_PAD, anchor.y - m.YARD_PAD,
		5 + m.YARD_PAD * 2, 4 + m.YARD_PAD * 2)
	for y in range(yard.position.y, yard.end.y):
		for x in range(yard.position.x, yard.end.x):
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			if m.grid[y][x].ground == "water":
				m.grid[y][x].ground = "yard"
	# 문 앞 흙길은 내지 않는다 — **마을 바닥은 잔디**이고 포장은 플레이어
	# 몫이라는 약속이 있다 (마을 어귀도 그래서 흙길 대신 나무로 목을 만들었다).
	# 「여기는 뭐 하는 곳」은 바닥이 아니라 **내놓은 물건과 경계**로 말한다.
	var pid: String = m.plot_at_anchor(anchor)
	if pid == "":
		return          # 농장 집 · 고장 집 · 숲속 집은 꾸미지 않는다
	decorate_plot(anchor, pid)


# 마당의 소품과 경계 — **여러 번 불러도 같은 모습**이다 (이미 놓인 칸은
# 건너뛴다). 건물을 놓을 때와 세계를 펼 때 양쪽에서 부른다:
# 짓는 순간에만 두었더니, 이미 지어 놓은 세이브는 자고 일어나 세계를
# 다시 지을 때까지 마당이 텅 비어 있었다.
func decorate_plot(anchor: Vector2i, pid: String) -> void:
	_plot_bounds(anchor)
	_plot_props(anchor, pid)


# 부지의 경계 — 마당 한 칸 바깥을 울타리로 두르고 **문 앞만 터 둔다.**
#
# 가게들이 잔디 위에 나란히 놓여 있으면 어디까지가 그 가게의 자리인지
# 알 수가 없다. 낮은 울타리 한 겹이면 「여기부터 저기까지가 대장간」이 된다.
#
# 이미 무언가 서 있는 칸, 잔디가 아닌 칸, 큰길과 광장은 건드리지 않는다 —
# 부지들이 서로 가깝고 이장 집 그림과도 닿아 있어서, 그냥 두르면 남의
# 자리에 말뚝을 박는다.
func _plot_bounds(anchor: Vector2i) -> void:
	var ring := Rect2i(anchor.x - m.YARD_PAD - 1, anchor.y - m.YARD_PAD - 1,
		5 + m.YARD_PAD * 2 + 2, 4 + m.YARD_PAD * 2 + 2)
	var gate_y: int = ring.end.y - 1              # 아래 변 = 문이 난 쪽
	var side_x: int = _plot_side_gate_x(anchor)   # 옆문 = 마을 한복판 쪽
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var edge: bool = x == ring.position.x or x == ring.end.x - 1 \
				or y == ring.position.y or y == gate_y
			if not edge:
				continue
			# 드나드는 목 — 문 앞 세 칸은 비운다
			if y == gate_y and absi(x - (anchor.x + 2)) <= 1:
				continue
			# 옆문 세 칸
			if x == side_x and y >= anchor.y + 1 and y <= anchor.y + 3:
				continue
			var t := Vector2i(x, y)
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			if m.objects.has(t):
				continue
			# 잔디와 **마당 흙**에만 박는다. `_lay_yard` 가 부지 둘레를 이미
			# 흙마당으로 깔아 두므로 잔디만 보면 말뚝이 한 개도 안 선다.
			# 문 앞에서 큰길로 난 길("path")은 건드리지 않는다 — 드나드는 길이다
			if m.grid[y][x].ground not in ["grass", "yard"]:
				continue
			if m.ROAD.has_point(t) or m.PLAZA.has_point(t) or _on_village_road(t):
				continue
			if _is_plot_gateway(t):
				continue
			m.objects[t] = {"kind": "fence", "hp": 0}


# **어느 부지든** 문 앞 목에 걸리는 칸인가.
#
# 부지는 한 곳씩 지어지는데 서로 가깝다. 제 울타리만 보고 두르면, 나중에
# 지은 집의 경계가 **앞서 지은 집의 출입구를 덮는다** — 대장간 문 앞을
# 목장 상회의 울타리가 막아 광장에서 대장간까지 길이 끊겼다.
# 어느 부지의 목이든 세 칸 폭 · 두 줄 깊이로 비워 둔다.
func _is_plot_gateway(t: Vector2i) -> bool:
	for pid: String in m.VILLAGE_PLOTS:
		var a: Vector2i = m.VILLAGE_PLOTS[pid].anchor
		var gate_y: int = a.y + 4 + m.YARD_PAD          # 울타리 아래 변
		if absi(t.x - (a.x + 2)) <= 1 and (t.y >= a.y + 4 and t.y <= gate_y + 1):
			return true
		var sx: int = _plot_side_gate_x(a)
		if absi(t.x - sx) <= 1 and t.y >= a.y + 1 and t.y <= a.y + 3:
			return true
	return false


# 길 한 줄을 **굽이치게** 깐다.
#
# 자로 그은 네모로 깔면 마을이 격자 도시가 된다 — 시골길은 지형을 피해
# 휘고, 밟히는 폭도 들쭉날쭉하다. 줄기(lane)는 그대로 두고 칸마다 두어 칸씩
# 좌우로 흔들면서, 가장자리 한 겹은 확률로 빼서 톱니를 남긴다.
#
# 바닥은 자갈("path")이다. 흙마당과 같은 흙으로 깔았더니 마당과 길이
# 한 덩어리로 뭉개져 어디까지가 마당인지 안 보였다.
func _paint_village_lane(lane: Rect2i) -> void:
	var vertical: bool = lane.size.y > lane.size.x
	var along0: int = lane.position.y if vertical else lane.position.x
	var along1: int = lane.end.y if vertical else lane.end.x
	var across0: int = lane.position.x if vertical else lane.position.y
	var width: int = lane.size.x if vertical else lane.size.y
	for a in range(along0, along1):
		# 굽이는 **한 칸 남짓**이면 된다. 두세 칸씩 흔들었더니 3줄짜리 길이
		# 화면에서 열 칸 폭의 자갈 얼룩이 됐다 — 길이 아니라 자갈밭이었다.
		# 서른 칸 주기 하나로 완만하게 휜다.
		var wob := int(round(sin(float(a) * 0.19) * 1.4))
		for k in range(0, width + 1):
			var c: int = across0 + wob + k
			var x: int = c if vertical else a
			var y: int = a if vertical else c
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			if m.grid[y][x].ground != "grass":
				continue
			# **부지 안은 건드리지 않는다.** 길이 울타리 자리를 자갈로 덮으면
			# 말뚝이 한 개도 안 선다 (_plot_bounds 는 잔디·마당에만 박는다)
			if _in_any_plot_ring(Vector2i(x, y)):
				continue
			# 마지막 한 겹은 확률로 뺀다 (가장자리가 자로 잰 듯하지 않게)
			if k >= width and m._hash01(x * 7 + 1, y * 5 + 3) < 0.6:
				continue
			m.grid[y][x].ground = "path"


# 이 칸이 마을 길 위인가.
#
# 길이 굽이치므로 네모 안에 드는지로는 못 잰다 — 줄기 네모를 두 칸 부풀린
# 것을 「길목」으로 보고, 울타리·소품·나무를 그 안에 두지 않는다.
func _on_village_road(t: Vector2i) -> bool:
	for lane: Rect2i in m.VILLAGE_ROADS:
		if lane.grow(2).has_point(t):
			return true
	return false


# 부지의 **옆문**이 난 줄 — 마을 한복판을 바라보는 쪽이다.
#
# 앞문(남쪽) 하나로는 모자란다. 서쪽 줄의 세 부지(대장간·목장 상회·여관)는
# 여덟 칸 간격으로 놓여 있고 울타리 테두리가 여덟 줄이라, 테두리끼리 **틈
# 없이 맞닿는다** — 세 마당이 남쪽으로만 뚫린 하나의 관이 되고, 그 관은
# 가운데 선 건물이 스스로 막는다. 광장에서 대장간까지 걸어갈 길이 없었다.
# (여태 이게 안 드러난 것은 낚시터를 비우는 네모가 여관의 서쪽 울타리를
#  통째로 지워 우연히 구멍을 내 주고 있었기 때문이다)
func _plot_side_gate_x(anchor: Vector2i) -> int:
	var ring_l: int = anchor.x - m.YARD_PAD - 1
	var ring_r: int = anchor.x + 4 + m.YARD_PAD + 1
	return ring_r if anchor.x + 2 < m.PLAZA.get_center().x else ring_l


# 그 가게다운 마당을 편다 (main.PLOT_DECOR) — 바닥을 먼저 깔고 살림을 놓는다.
# 자리가 이미 차 있으면 그 하나만 건너뛴다 — 나머지는 그대로 놓는다.
func _plot_props(anchor: Vector2i, pid: String) -> void:
	var spec: Dictionary = m.PLOT_DECOR.get(pid, {})
	# ① 바닥 — 자갈 마당이든 다진 흙이든, 소품보다 먼저 깐다
	for f: Array in spec.get("floor", []):
		var r: Rect2i = f[0] as Rect2i
		for y in range(anchor.y + r.position.y, anchor.y + r.end.y):
			for x in range(anchor.x + r.position.x, anchor.x + r.end.x):
				if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
					continue
				var t0 := Vector2i(x, y)
				if m.ROAD.has_point(t0) or m.PLAZA.has_point(t0) or _on_village_road(t0):
					continue
				if m.grid[y][x].ground not in ["grass", "yard"]:
					continue      # 물·모래·이미 깐 바닥은 건드리지 않는다
				m.grid[y][x].ground = str(f[1])
	# ② 살림
	for entry: Array in spec.get("props", []):
		var t: Vector2i = anchor + (entry[0] as Vector2i)
		if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H:
			continue
		if m.objects.has(t) \
				or m.grid[t.y][t.x].ground not in ["grass", "yard", "path", "sand"]:
			continue
		if m.ROAD.has_point(t) or m.PLAZA.has_point(t) or _on_village_road(t):
			continue
		if _is_plot_gateway(t):
			continue      # 드나드는 목은 무엇으로도 막지 않는다
		m.objects[t] = {"kind": str(entry[1]), "hp": 0}


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
	# 울타리 테두리 **안쪽을 다 채운다.** 자리를 넓히면(YARD_PAD) 마당도
	# 같이 넓어져야 한다 — 예전에는 아홉 칸으로 박아 두어서, 부지를 키우면
	# 넓어진 자리만 잔디로 남아 울타리 안에 풀밭이 생겼다
	for y in range(anchor.y - m.YARD_PAD, anchor.y + 4 + m.YARD_PAD):
		for x in range(anchor.x - m.YARD_PAD, anchor.x + 5 + m.YARD_PAD):
			if x < 0 or y < 0 or x >= m.MAP_W or y >= m.MAP_H:
				continue
			var cell: Dictionary = m.grid[y][x]
			if cell.ground != "grass":
				continue                      # 길·물·밭·모래는 건드리지 않는다
			# 가장자리는 **자로 잰 듯하면 안 된다.** 바깥 한 겹을 확률로 빼서
			# 들쭉날쭉하게 만든다 (모서리일수록 많이 빠진다)
			var edge := 0
			if x == anchor.x - m.YARD_PAD or x == anchor.x + 4 + m.YARD_PAD:
				edge += 1
			if y == anchor.y - m.YARD_PAD or y == anchor.y + 3 + m.YARD_PAD:
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


# 집 앞 **나무 데크**. 건물이 바닥에 그냥 붙어 있으면 종이를 오려 붙인
# 것처럼 납작하다 — 문 앞에 널을 한 겹 깔면 집이 한 단 올라선다.
#
# 널은 건물 폭만큼(문 앞 다섯 칸) 두 줄. 드나드는 통로 위이므로 지나갈 수
# 있어야 하고(바닥일 뿐 오브젝트가 아니다), 길·광장은 건드리지 않는다.
func _lay_porch(anchor: Vector2i) -> void:
	for dy in range(4, 6):
		for dx in range(0, 5):
			var t := anchor + Vector2i(dx, dy)
			if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H:
				continue
			if m.PLAZA.has_point(t) or m.ROAD.has_point(t) or _on_village_road(t):
				continue
			if m.grid[t.y][t.x].ground in ["grass", "yard", "path"]:
				m.grid[t.y][t.x].ground = "dock"


func _place_building_tiles(anchor: Vector2i) -> void:
	_lay_yard(anchor)
	_lay_porch(anchor)
	for y in range(anchor.y, anchor.y + 4):
		for x in range(anchor.x, anchor.x + 5):
			m.objects[Vector2i(x, y)] = {"kind": "house", "hp": 0}
	m.objects.erase(m.door_tile(anchor))
	_trim_paths_under_building(anchor)
	_build_yard(anchor)


# 칸을 놓고 그림까지 세운다 — **세계가 다 지어진 뒤에만** 부를 수 있다.
#
# 세계를 짓는 중(_build_map)에는 m.world 가 아직 없어서, 여기서 세우려
# 들면 add_child 가 null 에서 터진다. 그때는 _place_building_tiles 만
# 부르고 그림은 _spawn_objects 에 맡긴다 (마을 가게·고장 마을이 그렇게 한다).
# 오류 문구가 「null 에 add_child」뿐이라 어디서 잘못 불렀는지 안 보였다.
func _fill_building(anchor: Vector2i, kind: String = "") -> void:
	assert(m.world != null,
		"_fill_building 은 세계가 다 지어진 뒤에만 부른다 — 짓는 중이면 _place_building_tiles")
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
	# 여기에 「숲길 남쪽에서 문 앞까지 내려오는 오솔길」을 내는 줄이 있었다.
	# 그 숲길은 **세계 안(y15~18)에 있던 시절**의 튜토리얼 길이다 —
	# 세계 밖으로 옮겨 간 뒤로는 시작 줄이 끝 줄보다 커서, 이 반복문은
	# 한 번도 돌지 않았다 (길은 오래전부터 없었다). 죽은 줄을 걷어낸다.
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
	if m.spawn_blocked(pos.x, pos.y):
		return false   # 그림·돌계단·층계참 길이 차지한 자리
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


# 종류별로 **한 번에** 센다.
#
# 예전에는 `_nature_count(kind)` 하나가 물건 전부(6천 개)를 훑었고, 그걸
# 잡초 돋는 반복문 **안에서** 불렀다 — 비 오는 날은 108번. 6천 × 108 =
# 육십오만 번이다. 하루가 넘어갈 때 반 초가 여기서 갔다.
# 한 번 세어 놓고, 놓을 때마다 하나씩 올리면 된다.
func _nature_counts() -> Dictionary:
	var n := {}
	for pos in m.objects:
		var k := String(m.objects[pos].kind)
		n[k] = int(n.get(k, 0)) + 1
	return n


# 아침 리젠 — 캐서 없앤 나무/돌/잡초가 3~5일 뒤(respawn_queue),
# 맵의 「빈자리 검사」를 통과한 랜덤 위치에서 새로 자란다.
# 잡초는 그와 별개로 시간이 지나면 저절로도 돋는다 (상한 안에서).
func _respawn_resources() -> void:
	var cnt := _nature_counts()
	var keep: Array = []
	for e in GameData.respawn_queue:
		if int(e.due) > GameData.day:
			keep.append(e)
			continue
		var kind := str(e.kind)
		if int(cnt.get(kind, 0)) >= int(NATURE_CAP.get(kind, 999)):
			continue   # 이미 빽빽하다 — 이 리젠은 조용히 사라진다
		var placed := false
		for attempt in 30:
			var pos := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.WORLD_H - 2))
			if not _respawn_ok(pos, kind):
				continue   # 못 놓는 자리면 강제하지 않고 다른 자리를 다시 찾는다
			m.objnode._place_object(pos, kind,
				m.TREE_HP if kind == "tree" else (m.ROCK_HP if kind == "rock" else 0))
			cnt[kind] = int(cnt.get(kind, 0)) + 1
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
	var weed_n := int(cnt.get("weed", 0))
	var weed_cap := int(NATURE_CAP["weed"])
	for attempt in weed_want * 6:
		if weed_sprouts >= weed_want or weed_n >= weed_cap:
			break
		var pos2 := Vector2i(randi_range(1, m.MAP_W - 2), randi_range(1, m.WORLD_H - 2))
		if _respawn_ok(pos2, "weed"):
			m.objnode._place_object(pos2, "weed", 0)
			weed_sprouts += 1
			weed_n += 1


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
	# 마을 안에서는 **길·광장·부지 마당**을 피한다. 마을 사이가 숲이 되면서
	# 채집물도 마을에 돋게 됐는데, 아침마다 흙길 한복판과 대장간 자갈 마당에
	# 산딸기가 돋았다 — 사람이 쓸고 다니는 자리다
	if m.VILLAGE_REGION.has_point(pos):
		if m.PLAZA.has_point(pos) or m.ROAD.has_point(pos) or _on_village_road(pos):
			return false
		if _in_any_plot_ring(pos) or _is_plot_gateway(pos):
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


# ---- 마을 어귀의 목은 걷어냈다 ----
#
# 여기에 x53~63 을 나무로 두껍게 채워 **목**을 만드는 함수가 있었다.
# 도착 자리(story.WORLD_ENTRY)가 마을 문턱(58, 21)이던 시절, 숲길을 걸어
# 나와 그 자리에서 눈을 뜨면 사방이 트인 벌판이라 「마을에 들어선다」가
# 아니라 그냥 나타나는 것이었다 — 양옆을 숲으로 막은 이유가 그것이다.
#
# 도착 자리가 **세계 서쪽 끝**으로 옮겨 가면서 그 이유가 통째로 사라졌다.
# 이제는 거기서 눈을 뜨지 않고 농장을 지나 걸어서 마을에 든다. 감쌀 것이
# 없어진 나무 벽만 마을 서쪽 한복판에 덩어리로 남아, 지나갈 때마다
# 「여기 왜 숲이 있지」가 됐다.
