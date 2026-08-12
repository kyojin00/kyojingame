# 세계에 서 있는 것들 — 나무·바위·울타리·건물 그림의 **노드**를 다룬다.
#
# `main.objects`가 「어느 칸에 무엇이 있는가」라는 사실이라면, 여기는 그것을
# 화면에 세우고 치우는 쪽이다. 두 가지가 늘 짝을 이뤄야 한다 —
# `objects`에서 지웠는데 노드를 안 치우면 유령이 남는다.
#
# 앞을 가리는 것은 반투명하게 비친다 (`_covers_player` · `_update_object_fade`).
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinObjects
extends Node

var m: KyojinMain    # main.gd


func _update_tree_fade() -> void:
	for spr in m._faded_trees:
		if is_instance_valid(spr):
			spr.modulate.a = 1.0
	m._faded_trees.clear()
	if m.player == null or m.interior.visible or m.cave.visible:
		return
	var t := m.player_tile()
	for dy in range(0, 4):
		for dx in range(-2, 3):
			var p := t + Vector2i(dx, dy)
			if not m.obj_nodes.has(p) or not m.objects.has(p):
				continue
			if m.objects[p].kind != "tree":
				continue
			var node: Node2D = m.obj_nodes[p]
			if node.position.y <= m.player.position.y:
				continue  # 뒤쪽 나무는 주인공을 가리지 않는다
			var spr: Sprite2D = node.get_child(0)
			spr.modulate.a = 0.45
			m._faded_trees.append(spr)


func _spawn_objects() -> void:
	for n in m.obj_nodes.values():
		n.queue_free()
	m.obj_nodes.clear()
	m.tree_sprites.clear()
	# 지은 뒤에만 존재한다. 문 칸은 비워 둔다 (구버전 저장도 여기서 열린다)
	for pid: String in GameData.village_built:
		if m.VILLAGE_PLOTS.has(pid):
			m.objects.erase(m.door_tile(m.VILLAGE_PLOTS[pid].anchor))
			m.worldgen._spawn_house_node(m.VILLAGE_PLOTS[pid].anchor, pid)
			m.worldgen._trim_paths_under_building(m.VILLAGE_PLOTS[pid].anchor)
	if GameData.house_lv >= 1:
		m.objects.erase(m.door_tile(m.HOME_ANCHOR))
		m.worldgen._spawn_house_node(m.HOME_ANCHOR)
		m.worldgen._trim_paths_under_building(m.HOME_ANCHOR)
	for pos: Vector2i in m.objects:
		if m.objects[pos].kind != "house":
			_spawn_object_node(pos, m.objects[pos].kind)
	m.farming._recount_pasture()   # 불러온 세이브의 울타리도 목초지로 인정한다
	m.story._apply_story_visibility()


func _spawn_object_node(pos: Vector2i, kind: String) -> void:
	var offset := Vector2(0, -64)
	var texture: Texture2D
	match kind:
		"tree":
			texture = m.tex["tree_01"]  # 실제 상태별 텍스처는 _refresh_tree_sprite가 결정
			offset = Vector2(0, -100)
		"rock":
			texture = m.tex["rock"]
		"bigrock":
			texture = m.tex["rock"]  # 같은 바위 그림을 크게 그린다 (퀘스트 5)
		"housesite":
			texture = m.tex["sign"]  # 집터 표지판
		"board":
			texture = m.tex["board"]
		"sign":
			texture = m.tex["sign"]
		"cave":
			texture = m.tex["cave"]
			offset = Vector2(0, -100)
		"fence":
			texture = m.tex["fence"]
		"sprinkler":
			texture = m.tex["sprinkler"]
		"forage_berry":
			texture = m.tex["forage_berry"]
		"forage_herb":
			texture = m.tex["forage_herb"]
		"weed":
			# 서 있을 때는 풀숲, 주우면 묶음(weed)이 인벤토리에 들어간다
			texture = m.tex["weed_plant"]
		"worldtree":
			texture = m.tex["cave"]
			offset = Vector2(0, -100)
		"barn":
			texture = m.tex["barn"]
			offset = Vector2(0, -texture.get_height())   # 밑변을 문 칸 아래에 맞춘다
		"barn_block":
			pass  # 축사 오른쪽 칸 (통행 차단용, 그림 없음)
		"art_block":
			pass  # 건물 그림이 덮는 칸 (통행 차단용, 그림 없음)
		"deco_fountain":
			texture = m.tex["deco_fountain"]  # 광장 분수 조형물 (분수 한가운데)
			offset = Vector2(0, -160)
		"deco_lamp":
			texture = m.tex["deco_lamp"]
			offset = Vector2(0, -128)
		"deco_bench":
			texture = m.tex["deco_bench"]
		"horse":
			texture = m.tex["horse_side_0"]   # 세워 둔 말
			offset = Vector2(0, -80)
	var node := _make_object(texture, Vector2(pos.x * m.TILE, (pos.y + 1) * m.TILE), offset)
	# 큰 캐릭터에 맞춰 자연물은 타일보다 크게 그린다 (충돌 칸은 1칸 유지)
	var sc: float = m.OBJECT_SCALES.get(kind, 1.0) / m.OBJECT_TEX_DENSITY
	if kind == "tree":
		# 크기 편차는 5칸 간격 안에서 겹치지 않는 범위까지만 (숲에서는 덩어리감을 준다)
		sc *= 0.82 + m._hash01(pos.x * 7 + 3, pos.y * 13 + 1) * 0.26
	elif kind == "rock":
		# 큰 돌과 작은 돌이 섞이도록
		sc *= 0.65 + m._hash01(pos.x * 5 + 1, pos.y * 9 + 4) * 0.6
	if texture != null:
		var spr: Sprite2D = node.get_child(0)
		if kind == "tree":
			spr.flip_h = m._hash01(pos.x * 3 + 5, pos.y * 11 + 7) > 0.5  # 좌우 변형
		spr.scale = Vector2(sc, sc)
		spr.offset.x = 16.0 / sc - texture.get_width() / 2.0
		if kind == "deco_fountain":
			spr.offset.x += 16.0 / sc  # 4칸짜리 분수의 정중앙에 세운다
	m.obj_nodes[pos] = node
	if kind == "tree":
		m.tree_sprites.append(node.get_child(0))
	m.world.add_child(node)


func _refresh_tree_sprite(pos: Vector2i) -> void:
	if not m.obj_nodes.has(pos) or not m.objects.has(pos):
		return
	if m.objects[pos].kind != "tree":
		return
	var spr: Sprite2D = m.obj_nodes[pos].get_child(0)
	var hp := int(m.objects[pos].hp)
	if hp >= m.TREE_HP:
		if bool(m.objects[pos].get("young", false)):
			spr.texture = m.tex["tree_15"]  # 아직 덜 자란 어린 나무
		elif m.objects[pos].get("apple", false):
			spr.texture = m.tex["tree_13"]  # 일부 나무에만 사과 3개
		else:
			spr.texture = m.tex["tree_01"]  # 완전히 자란 기본 나무
	elif hp == 2:
		spr.texture = m.tex["tree_06"]
	else:
		spr.texture = m.tex["tree_09"]


func _remove_object(pos: Vector2i, pop: bool = false) -> void:
	m.objects.erase(pos)
	if m.obj_nodes.has(pos):
		var node: Node2D = m.obj_nodes[pos]
		var sprite := node.get_child(0)
		m.tree_sprites.erase(sprite)
		m.obj_nodes.erase(pos)
		if pop and is_instance_valid(sprite):
			# 바로 지우지 않고 팍 튀었다가 사라진다 (그림만 남는 것이라 판정과 무관)
			# 노드에 매어 둔다 — 다른 이유로 노드가 먼저 사라져도
			# 트윈이 유령 객체에 값을 쓰지 않는다
			var tw := create_tween().bind_node(node).set_parallel(true)
			tw.tween_property(sprite, "scale", sprite.scale * 1.25, 0.08)
			tw.chain().tween_property(sprite, "scale", Vector2.ZERO, 0.14)
			tw.chain().tween_callback(node.queue_free)
		else:
			node.queue_free()


func _place_object(pos: Vector2i, kind: String, hp: int) -> void:
	m.objects[pos] = {"kind": kind, "hp": hp}
	_spawn_object_node(pos, kind)


func _make_object(texture: Texture2D, base_pos: Vector2, offset: Vector2) -> Node2D:
	# y 정렬 기준점(밑변)에 노드를 두고, 스프라이트는 위로 올려 그린다.
	var node := Node2D.new()
	node.position = base_pos
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.offset = offset
	node.add_child(s)
	return node


func _apply_season_visuals() -> void:
	for pos: Vector2i in m.obj_nodes:
		if m.objects.has(pos) and m.objects[pos].kind == "tree":
			_refresh_tree_sprite(pos)  # 손상 단계(잎 없음/반파)를 유지한 채 계절 반영
	# 배경음은 main._bgm_tick이 상황을 보고 고른다 (계절만으로는 못 정한다)
	m.queue_redraw()


func _covers_player(t: Vector2i, node: Node2D) -> bool:
	if node.position.y <= m.player.position.y:
		return false          # y정렬상 플레이어 뒤 — 가릴 수 없다
	var spr: Sprite2D = node.get_child(0)
	if spr == null or spr.texture == null:
		return false
	var top_left: Vector2 = node.position + spr.offset * spr.scale
	var art := Rect2(top_left, spr.texture.get_size() * spr.scale)
	# 플레이어 몸통 (발끝 위쪽)
	return art.intersects(Rect2(m.player.position + Vector2(-9, -74), Vector2(18, 70)))


func _update_object_fade(delta: float) -> void:
	var pt := m.player_tile()
	var want := {}
	# 플레이어보다 아래쪽(앞에 그려지는) 오브젝트만 본다
	for dy in range(-1, 5):
		for dx in range(-3, 4):
			var t: Vector2i = pt + Vector2i(dx, dy)
			if not m.obj_nodes.has(t):
				continue
			var kind: String = str(m.objects.get(t, {}).get("kind", ""))
			if not m.FADE_KINDS.has(kind):
				continue
			if _covers_player(t, m.obj_nodes[t]):
				want[t] = true
				if not m._fade_a.has(t):
					m._fade_a[t] = 1.0
	for t: Vector2i in m._fade_a.keys():
		if not m.obj_nodes.has(t):
			m._fade_a.erase(t)
			continue
		var target: float = m.FADE_ALPHA if want.has(t) else 1.0
		var a: float = move_toward(float(m._fade_a[t]), target, delta * m.FADE_SPEED)
		m._fade_a[t] = a
		var spr2: Sprite2D = m.obj_nodes[t].get_child(0)
		if spr2 != null:
			spr2.modulate.a = a
		if is_equal_approx(a, 1.0) and not want.has(t):
			m._fade_a.erase(t)
