# 농사 — 자라기·물기·스프링클러, 그리고 울타리 목초지와 가축.
#
# 물기는 「젖었다/말랐다」가 아니라 **남은 분(minute)** 으로 센다. 그래야
# 스프링클러가 계속 대 주는 것과 비 온 날이 자연스럽게 섞인다.
#
# 목초지는 울타리로 **완전히 둘러싸인** 칸만 인정한다 (`_recount_pasture`).
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinFarming
extends Node

var m: KyojinMain    # main.gd


func _grow_total(def: Dictionary) -> float:
	# 연구소에서 개량한 씨앗은 더 빨리 자란다 (최소 40%까지)
	return float(def.grow_days) * 60.0 * GameData.breed_grow_mult()


func _crop_thirsty(cell: Dictionary) -> bool:
	if cell.crop_id == "" or cell.dead or bool(cell.get("half_fed", false)):
		return false
	return float(cell.crop_day) >= _grow_total(GameData.CROPS[cell.crop_id]) * m.GROW_CHECKPOINT


func _wet(cell: Dictionary, minutes: float) -> void:
	touch(cell)
	cell.wet_min = maxf(float(cell.wet_min), minutes)
	cell.watered = true
	# 절반까지 자란 뒤에 받은 물만 체크포인트를 통과시킨다
	# (심을 때 내린 비로 미리 통과되지 않도록 성장률을 직접 본다)
	if _crop_thirsty(cell):
		cell.half_fed = true


func spawn_animal(type: String, pos: Vector2 = Vector2.ZERO, fed: bool = false) -> void:
	var a: Node2D = preload("res://scripts/animal.gd").new()
	a.main = m
	a.type = type
	a.fed = fed
	if pos == Vector2.ZERO:
		var t := _find_free_tile_near(Vector2i(10, 7 + m.NORTH_PAD))
		pos = Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16)
	a.position = pos
	m.animals.append(a)
	m.world.add_child(a)


func _find_free_tile_near(center: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := center + Vector2i(dx, dy)
				if m.is_passable(t):
					return t
	return m.START_TILE


func _blocks_pasture(t: Vector2i) -> bool:
	return m.objects.has(t) or m.grid[t.y][t.x].ground == "water"


func _recount_pasture() -> void:
	m.pasture.clear()
	# ---- 울타리 둘레만 본다 ----
	#
	# 예전에는 지도 **전체**에서 흘려보냈다. 224x132 일 때는 3만 칸이라
	# 견뎠는데, 448x264 가 되면서 13만 6천 칸이 됐다 — 하루가 넘어갈 때마다
	# (그리고 울타리를 놓을 때마다) 그걸 두 번씩 훑는다. 배속을 올리면
	# 하루가 몇 초마다 넘어가니 그게 1초짜리 멈춤으로 계속 걸렸다.
	#
	# 목초지는 **울타리로 둘러싼 곳**이다. 울타리가 하나도 없으면 볼 것도
	# 없고, 있어도 그 울타리들을 감싸는 네모 바깥은 절대 갇힐 수 없다.
	var fx0 := m.MAP_W
	var fy0 := m.MAP_H
	var fx1 := -1
	var fy1 := -1
	for pos: Vector2i in m.objects:
		if str(m.objects[pos].kind) != "fence":
			continue
		fx0 = mini(fx0, pos.x); fy0 = mini(fy0, pos.y)
		fx1 = maxi(fx1, pos.x); fy1 = maxi(fy1, pos.y)
	if fx1 < 0:
		return                      # 울타리가 없으면 목초지도 없다
	# 울타리 네모에서 두 칸 넉넉히 — 그 테두리에서 물을 흘려보낸다
	var bx0: int = maxi(0, fx0 - 2)
	var by0: int = maxi(0, fy0 - 2)
	var bx1: int = mini(m.MAP_W - 1, fx1 + 2)
	var by1: int = mini(m.MAP_H - 1, fy1 + 2)
	# ① 네모 테두리에서 흘려보내 「바깥」을 표시한다
	var outside := {}
	var queue: Array[Vector2i] = []
	for x in range(bx0, bx1 + 1):
		for y in [by0, by1]:
			var t := Vector2i(x, y)
			if not _blocks_pasture(t) and not outside.has(t):
				outside[t] = true
				queue.append(t)
	for y2 in range(by0, by1 + 1):
		for x2 in [bx0, bx1]:
			var t2 := Vector2i(x2, y2)
			if not _blocks_pasture(t2) and not outside.has(t2):
				outside[t2] = true
				queue.append(t2)
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < bx0 or n.y < by0 or n.x > bx1 or n.y > by1:
				continue
			if outside.has(n) or _blocks_pasture(n):
				continue
			outside[n] = true
			queue.append(n)
	# ② 바깥에 닿지 못한 빈 칸 = 갇힌 칸. 덩어리별로 크기를 재서 너무 넓으면 뺀다
	var seen := {}
	for y3 in range(by0, by1 + 1):
		for x3 in range(bx0, bx1 + 1):
			var t3 := Vector2i(x3, y3)
			if seen.has(t3) or outside.has(t3) or _blocks_pasture(t3):
				continue
			var blob: Array[Vector2i] = [t3]
			seen[t3] = true
			var h2 := 0
			while h2 < blob.size():
				var c2: Vector2i = blob[h2]
				h2 += 1
				for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n2: Vector2i = c2 + d2
					if n2.x < bx0 or n2.y < by0 or n2.x > bx1 or n2.y > by1:
						continue
					if seen.has(n2) or _blocks_pasture(n2):
						continue
					seen[n2] = true
					blob.append(n2)
			if blob.size() <= m.PASTURE_MAX:
				for c3: Vector2i in blob:
					m.pasture[c3] = true


func in_pasture(t: Vector2i) -> bool:
	return m.pasture.has(t)


func _sprinkle(pos: Vector2i) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = pos + d
		if n.x < 0 or n.y < 0 or n.x >= m.MAP_W or n.y >= m.MAP_H:
			continue
		if m.grid[n.y][n.x].ground == "soil":
			_wet(m.grid[n.y][n.x], m.WET_ALL_DAY)


# ---- 스프링클러도 「있는 것만」 돈다 ----
#
# 0.7초마다 **세계의 모든 물건**(m.objects)을 훑어 스프링클러를 찾고 있었다.
# 224x132 일 때는 이천 개라 티가 안 났는데, 448x264 가 되면서 나무·돌만
# 만 개를 넘었다 — 0.7초마다 만 번을 뒤지니 그 주기로 화면이 걸렸다.
# 바로 밑 _ticking 이 같은 이유로 이미 한 번 고쳐진 자리인데, 물건 쪽만
# 남아 있었다.
#
# 놓을 때 목록에 넣고(add_sprinkler), 걷어낸 것은 도는 김에 빠진다.
var _sprinklers: Array[Vector2i] = []


func add_sprinkler(pos: Vector2i) -> void:
	if not _sprinklers.has(pos):
		_sprinklers.append(pos)


# 세이브를 펴거나 하루가 넘어갈 때 통째로 다시 만든다 — 어딘가에서
# add_sprinkler 를 빠뜨려도 하루 안에 저절로 맞춰진다
func rebuild_sprinklers() -> void:
	_sprinklers.clear()
	for pos: Vector2i in m.objects:
		if m.objects[pos].kind == "sprinkler":
			_sprinklers.append(pos)


func _sprinkler_tick() -> void:
	var gone := false
	for pos: Vector2i in _sprinklers:
		if str((m.objects.get(pos, {}) as Dictionary).get("kind", "")) != "sprinkler":
			gone = true
			continue
		_sprinkle(pos)
	if gone:
		var keep: Array[Vector2i] = []
		for pos2: Vector2i in _sprinklers:
			if str((m.objects.get(pos2, {}) as Dictionary).get("kind", "")) == "sprinkler":
				keep.append(pos2)
		_sprinklers = keep


# ---- 「지금 돌아가고 있는 칸」만 돈다 ----
#
# 자라거나 마르는 중인 칸은 늘 몇십 개뿐인데, 예전에는 0.7초마다 지도 전체
# 10,800칸을 훑었다. 그게 4ms짜리 끊김이 되어 0.7초마다 한 번씩 걸렸다.
#
# 젖거나 심긴 순간에 이 목록에 들어오고(`touch`), 마르고 작물도 없으면 빠진다.
# 칸 Dictionary를 그대로 담는다 — 성장 계산에 좌표가 필요 없기 때문이다.
# 세이브를 펴거나 하루가 넘어갈 때는 통째로 다시 만든다 (`rebuild`) —
# 어딘가에서 touch를 빠뜨려도 하루 안에 저절로 맞춰진다.
var _ticking: Array[Dictionary] = []


func touch(cell: Dictionary) -> void:
	if cell.get("ticking", false):
		return
	cell["ticking"] = true
	_ticking.append(cell)


# 이 칸을 「밭」으로 볼 것인가 — 젖었거나 · 심겼거나 · 갈아 놓은 흙.
# 하루가 넘어갈 때 마르게 하고 시들게 하는 일도 전부 이 조건이다.
func _is_farm_cell(c: Dictionary) -> bool:
	return float(c.wet_min) > 0.0 or str(c.crop_id) != "" or str(c.ground) == "soil"


# 지금 「밭」인 칸들. 하루가 넘어갈 때 여기만 돌면 된다 —
# 지도 전체(13만 6천 칸)를 훑을 이유가 없다
func farm_cells() -> Array[Dictionary]:
	return _ticking


# 하루가 넘어갈 때 — **목록만 걸러 낸다.** 지도는 안 훑는다.
# (rebuild 는 세이브를 펴거나 세계를 다시 지을 때만 부른다)
func refresh() -> void:
	var keep: Array[Dictionary] = []
	for c: Dictionary in _ticking:
		if _is_farm_cell(c):
			keep.append(c)
		else:
			c["ticking"] = false
	_ticking = keep


# 지도를 통째로 훑어 목록을 다시 만든다 — **여는 순간에만.**
# 하루가 넘어갈 때마다 부르면 13만 6천 칸을 매일 훑는다 (예전에 그랬고,
# 배속을 올리면 그게 1초짜리 멈춤이 되어 계속 걸렸다)
func rebuild() -> void:
	rebuild_sprinklers()
	_ticking.clear()
	for y in m.MAP_H:
		var row: Array = m.grid[y]
		for x in m.MAP_W:
			var c: Dictionary = row[x]
			c["ticking"] = false
			if _is_farm_cell(c):
				touch(c)


func _growth_tick(game_minutes: float) -> void:
	_sprinkler_tick()
	var changed := false
	var keep: Array[Dictionary] = []
	for cell in _ticking:
		if float(cell.wet_min) > 0.0:
			cell.wet_min = float(cell.wet_min) - game_minutes
			if float(cell.wet_min) <= 0.0:
				cell.wet_min = 0.0
				cell.watered = false
				changed = true
			if cell.crop_id != "" and not cell.dead and not _crop_thirsty(cell):
				var before_stage: Texture2D = m.renderer._crop_texture(cell)
				cell.crop_day = float(cell.crop_day) + game_minutes * GameData.farm_growth_mult()
				# 절반을 막 넘겼다면 여기서 멈춘다 — 물을 한 번 더 줘야 한다
				if _crop_thirsty(cell):
					changed = true
				if m.renderer._crop_texture(cell) != before_stage:
					changed = true
		# 마르고 · 작물도 없고 · 갈아 놓은 흙도 아니면 더 볼 일이 없다
		if _is_farm_cell(cell):
			keep.append(cell)
		else:
			cell["ticking"] = false
	_ticking = keep
	if changed:
		m.queue_redraw()
