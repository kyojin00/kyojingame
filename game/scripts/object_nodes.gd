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
	_clear_tree_falls()   # 쓰러지던 나무는 obj_nodes 밖에 있다 — 따로 치운다
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
	if GameData.forest_quest in ["visit", "done"]:
		# 숲속의 집 (스토리 5) — 저장된 발자취 그대로 그림만 다시 세운다
		m.objects.erase(m.door_tile(m.FOREST_HOUSE_ANCHOR))
		m.worldgen._spawn_house_node(m.FOREST_HOUSE_ANCHOR)
	if GameData.move_house.x >= 0:
		# 무진의 집 (스토리 3) — 플레이어가 정한 자리에 다시 세운다
		m.objects.erase(m.door_tile(GameData.move_house))
		m.worldgen._spawn_house_node(GameData.move_house)
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
		"searock":
			texture = m.tex["rock"]  # 남쪽 바위 능선 — 캘 수 없는 바위 벽
		"housesite":
			# 집터·구역 해금 게시판 — 지붕 얹은 파란 현판 (의뢰 게시판과 다르다)
			texture = m.tex["board_unlock"]
			offset = Vector2(0, -texture.get_height())
		"plotsite":
			# 상점 터 게시판 — 구역 해금 게시판과 같은 모습
			texture = m.tex["board_unlock"]
			offset = Vector2(0, -texture.get_height())
		"homeplot":
			# 빈 집터 팻말 — 이주 편지를 수락하면 이 자리에 집이 선다
			texture = m.tex["board_unlock"]
			offset = Vector2(0, -texture.get_height())
		"chief_hut":
			# 이장의 거처 — 낡은 오두막에서 시작해, 마을이 크면 새 집이 된다
			texture = m.tex["chief_house"] if GameData.chief_house_lv >= 1 \
				else m.tex["chief_hut"]
			offset = Vector2(0, -texture.get_height())
		"board":
			# 의뢰 게시판 — 다리 둘 달린 큰 코르크 게시판
			texture = m.tex["board_quest"]
			offset = Vector2(0, -texture.get_height())
		"auction":
			# 경매 게시판 — 같은 판에 금빛을 입혀 의뢰 게시판과 구별한다
			# (색은 아래에서 스프라이트가 생긴 뒤에 입힌다)
			texture = m.tex["board_quest"]
			offset = Vector2(0, -texture.get_height())
		"sign":
			if pos == m.GREENHOUSE_SIGN:
				texture = m.tex["board_unlock"]  # 온실 터도 「구역 해금」 게시판
				offset = Vector2(0, -texture.get_height())
			else:
				texture = m.tex["sign"]
		"cave":
			texture = m.tex["cave"]
			offset = Vector2(0, -100)
		"onsen":
			texture = m.tex["onsen"]   # 마을 온천 (메인 스토리 15)
			offset = Vector2(0, -100)
		"fence":
			texture = m.tex["fence"]
		"sprinkler":
			texture = m.tex["sprinkler"]
		"forage_berry":
			texture = m.tex["forage_berry"]
		"forage_herb":
			texture = m.tex["forage_herb"]
		"forage_shell":
			texture = m.tex["forage_shell"]
		"forage_coral":
			texture = m.tex["forage_coral"]
		"forage_trash":
			texture = m.tex["forage_trash"]
		"forage_glass":
			texture = m.tex["forage_glass"]
		"forage_ring":
			texture = m.tex["forage_ring"]
		"forage_relic":
			texture = m.tex["forage_relic"]
		"stall":
			# 민지의 해변 노점 — 차양 지붕이 위로 솟아 있어 밑변을 칸에 맞춘다
			texture = m.tex["stall"]
			offset = Vector2(0, -texture.get_height())
		"trash_bin":
			# 바깥에 설치한 무인 판매함 (E로 연다)
			texture = m.tex["trash_bin"]
			offset = Vector2(0, -texture.get_height())
		"weed":
			# 서 있을 때는 풀숲, 주우면 묶음(weed)이 인벤토리에 들어간다
			texture = m.tex["weed_plant"]
		"old_book":
			# 풀숲에 반쯤 묻힌 오래된 책 — 메인 스토리 6의 시작점
			texture = m.tex["old_book"]
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
	elif kind == "searock":
		# 능선 바위도 크기를 조금씩 다르게 — 벽이 자로 잰 듯 보이지 않게
		sc *= 0.85 + m._hash01(pos.x * 7 + 2, pos.y * 3 + 8) * 0.3
	if texture != null:
		var spr: Sprite2D = node.get_child(0)
		if kind == "tree":
			spr.flip_h = m._hash01(pos.x * 3 + 5, pos.y * 11 + 7) > 0.5  # 좌우 변형
		spr.scale = Vector2(sc, sc)
		spr.offset.x = 16.0 / sc - texture.get_width() / 2.0
		if kind == "deco_fountain":
			spr.offset.x += 16.0 / sc  # 4칸짜리 분수의 정중앙에 세운다
		elif kind == "auction":
			spr.modulate = Color(1.15, 1.0, 0.62)  # 경매 게시판은 금빛
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


func _remove_object(pos: Vector2i, pop: bool = false, delay: float = 0.0) -> void:
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
			var tw := create_tween().bind_node(node)
			# 도구로 부순 것은 날이 닿는 순간(main.HIT_AT)까지 기다렸다 튄다
			if delay > 0.0:
				tw.tween_interval(delay)
			tw.tween_property(sprite, "scale", sprite.scale * 1.25, 0.08)
			tw.tween_property(sprite, "scale", Vector2.ZERO, 0.14)
			tw.tween_callback(node.queue_free)
		else:
			node.queue_free()


# ---- 나무가 쓰러진다 ----
#
# 마지막 도끼질에 그림이 그냥 팍 사라지면 「베었다」는 느낌이 안 난다.
# 밑동을 축으로 삼아 세 박자로 넘긴다:
#
#   1. 반동   도끼가 파고든 쪽으로 잠깐 되젖힌다 (뿌리가 버티는 순간)
#   2. 넘어감 반대쪽으로 점점 빨라지며 쓰러진다 (중력처럼 p²)
#   3. 착지   우듬지가 닿는 자리에서 흙먼지·잎이 일고 화면이 흔들린다
#
# 그 뒤 누운 몸통은 스르르 사라지고 **그루터기**만 조금 더 남는다.
#
# 판정은 `_fell_tree`를 부르는 그 자리에서 이미 끝나 있다 (objects에서 지운다).
# 여기 있는 것은 전부 그림뿐이라, 도중에 날이 바뀌거나 세이브를 불러와도
# 노드만 치우면 그만이다 (`_clear_tree_falls`).
const FALL_WIND := 0.12         # 반동 시간
const FALL_WIND_ANGLE := 0.11   # 되젖히는 각(라디안)
const FALL_DOWN := 0.46         # 넘어가는 시간
const FALL_ANGLE := 1.47        # 다 누웠을 때 각 (약 84도)
const FALL_BOUNCE := 0.075      # 땅에 닿고 한 번 튕기는 정도
const FALL_LIE := 0.55          # 누운 채 머무는 시간
const FALL_GONE := 0.35         # 스르르 사라지는 시간
const STUMP_STAY := 1.5         # 그루터기가 남아 있는 시간 (착지 뒤)
const STUMP_CUT := 0.81         # 나무 그림의 이 비율 아래쪽을 그루터기로 쓴다
                                # (96px 도트에서 77행 — 잎이 끝나고 밑동만 남는 줄)


# 이 칸의 나무를 쓰러뜨린다. dir: +1이면 오른쪽, -1이면 왼쪽으로 넘어간다.
# 그림이 실제로 움직이기 시작하는 것은 도끼날이 닿는 순간(main.HIT_AT)부터다.
func _fell_tree(pos: Vector2i, dir: float) -> void:
	m.objects.erase(pos)
	if not m.obj_nodes.has(pos):
		return
	var node: Node2D = m.obj_nodes[pos]
	m.obj_nodes.erase(pos)
	m._fade_a.erase(pos)
	var sv: Variant = node.get_child(0)
	m.tree_sprites.erase(sv)
	if not is_instance_valid(sv):
		node.queue_free()
		return
	var spr: Sprite2D = sv
	if spr.texture == null:
		node.queue_free()
		return
	# 앞을 가려서 비쳐 보이던 중이었다면 다시 진하게 (쓰러지는 건 잘 보여야 한다)
	m._faded_trees.erase(spr)
	spr.modulate.a = 1.0
	# 앞선 도끼질의 흔들림이 남아 있으면 쓰러지는 내내 같이 떨린다 — 여기서 끊는다
	m.toolwork._end_shake(node)
	var stump := _make_stump(spr)
	node.add_child(stump)
	m._tree_falls.append({
		"node": node, "spr": spr, "stump": stump,
		"dir": (1.0 if dir >= 0.0 else -1.0),
		# 밑동 — 그림의 밑변 한가운데다. 여기를 축으로 돈다.
		"pivot": Vector2(m.TILE / 2.0,
			(spr.offset.y + spr.texture.get_height()) * spr.scale.y),
		"t": 0.0, "wait": m.HIT_AT, "landed": false,
	})


# 0(서 있음) ~ FALL_ANGLE(다 누움). 부호는 부르는 쪽에서 곱한다.
func _fall_angle(t: float) -> float:
	if t < FALL_WIND:
		return -FALL_WIND_ANGLE * sin(t / FALL_WIND * PI)
	var p: float = (t - FALL_WIND) / FALL_DOWN
	if p < 1.0:
		return FALL_ANGLE * p * p    # 뿌리가 버티다 한순간에 무너진다
	# 땅에 닿은 뒤 한 번 튕겼다가 잦아든다
	var u: float = t - FALL_WIND - FALL_DOWN
	return FALL_ANGLE - FALL_BOUNCE * exp(-u * 9.0) * absf(sin(u * 22.0))


func _update_tree_fall(delta: float) -> void:
	if m._tree_falls.is_empty():
		return
	for f in m._tree_falls.duplicate():
		var nv: Variant = f.node
		if not is_instance_valid(nv):
			m._tree_falls.erase(f)
			continue
		var node: Node2D = nv
		if f.wait > 0.0:
			f.wait -= delta    # 도끼날이 닿을 때까지는 아직 서 있다
			continue
		f.t += delta
		var spr: Sprite2D = f.spr
		var a: float = _fall_angle(f.t) * float(f.dir)
		var pivot: Vector2 = f.pivot
		spr.rotation = a
		spr.position = pivot - pivot.rotated(a)   # 밑동을 제자리에 붙들어 둔다
		if not f.landed and f.t >= FALL_WIND + FALL_DOWN:
			f.landed = true
			_tree_landed(node, spr, f)
		if not f.landed:
			continue
		var lie: float = f.t - FALL_WIND - FALL_DOWN
		if lie > FALL_LIE:
			spr.modulate.a = clampf(1.0 - (lie - FALL_LIE) / FALL_GONE, 0.0, 1.0)
		var stv: Variant = f.stump
		if is_instance_valid(stv) and lie > STUMP_STAY:
			(stv as Sprite2D).modulate.a = clampf(
				1.0 - (lie - STUMP_STAY) / FALL_GONE, 0.0, 1.0)
		if lie > STUMP_STAY + FALL_GONE:
			m._tree_falls.erase(f)
			node.queue_free()


# 쿵. 우듬지가 떨어진 자리에서 흙먼지와 잎이 인다.
func _tree_landed(node: Node2D, spr: Sprite2D, f: Dictionary) -> void:
	var pivot: Vector2 = f.pivot
	var crown := Vector2(pivot.x, spr.offset.y * spr.scale.y)   # 서 있을 때의 꼭대기
	var at: Vector2 = node.position + pivot \
		+ (crown - pivot).rotated(FALL_ANGLE * float(f.dir))
	m.renderer.spawn_burst(at, "dust", 1.0, 16.0)
	m.renderer.spawn_burst(at, "leaf", 1.2, 18.0)
	Sound.play_sfx("sfx_chop", 0.05, 0.55)   # 낮게 깔면 「쿵」으로 들린다
	m._cam_shake = 0.22
	m._cam_shake_amp = 3.4


# 그루터기 — 새 그림을 만들지 않고 나무 그림의 **아랫동아리만** 잘라 쓴다.
# 나무 도트는 아래쪽이 밑동과 풀숲이라, 잘라 놓으면 그대로 그루터기로 읽힌다.
func _make_stump(spr: Sprite2D) -> Sprite2D:
	var size: Vector2 = spr.texture.get_size()
	var cut: float = floorf(size.y * STUMP_CUT)
	var s := Sprite2D.new()
	s.texture = spr.texture
	s.centered = false
	s.flip_h = spr.flip_h
	s.scale = spr.scale
	s.region_enabled = true
	s.region_rect = Rect2(0.0, cut, size.x, size.y - cut)
	s.offset = spr.offset + Vector2(0.0, cut)   # 잘라 낸 만큼 아래로 내려 붙인다
	return s


func _clear_tree_falls() -> void:
	for f in m._tree_falls:
		var nv: Variant = f.node
		if is_instance_valid(nv):
			(nv as Node2D).queue_free()
	m._tree_falls.clear()


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
