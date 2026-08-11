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
		var t := _find_free_tile_near(Vector2i(10, 7))
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
	# ① 가장자리에서 흘려보내 「바깥」을 표시한다
	var outside := {}
	var queue: Array[Vector2i] = []
	for x in m.MAP_W:
		for y in [0, m.MAP_H - 1]:
			var t := Vector2i(x, y)
			if not _blocks_pasture(t) and not outside.has(t):
				outside[t] = true
				queue.append(t)
	for y2 in m.MAP_H:
		for x2 in [0, m.MAP_W - 1]:
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
			if n.x < 0 or n.y < 0 or n.x >= m.MAP_W or n.y >= m.MAP_H:
				continue
			if outside.has(n) or _blocks_pasture(n):
				continue
			outside[n] = true
			queue.append(n)
	# ② 바깥에 닿지 못한 빈 칸 = 갇힌 칸. 덩어리별로 크기를 재서 너무 넓으면 뺀다
	var seen := {}
	for y3 in m.MAP_H:
		for x3 in m.MAP_W:
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
					if n2.x < 0 or n2.y < 0 or n2.x >= m.MAP_W or n2.y >= m.MAP_H:
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


func _sprinkler_tick() -> void:
	for pos: Vector2i in m.objects:
		if m.objects[pos].kind == "sprinkler":
			_sprinkle(pos)


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


func rebuild() -> void:
	_ticking.clear()
	for y in m.MAP_H:
		var row: Array = m.grid[y]
		for x in m.MAP_W:
			var c: Dictionary = row[x]
			c["ticking"] = false
			if float(c.wet_min) > 0.0 or str(c.crop_id) != "":
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
		# 마르고 작물도 없으면 더 볼 일이 없다
		if float(cell.wet_min) > 0.0 or str(cell.crop_id) != "":
			keep.append(cell)
		else:
			cell["ticking"] = false
	_ticking = keep
	if changed:
		m.queue_redraw()
