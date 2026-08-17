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
	m.landmark_sprites.clear()
	# 지은 뒤에만 존재한다. 문 칸은 비워 둔다 (구버전 저장도 여기서 열린다)
	for pid: String in GameData.village_built:
		if m.VILLAGE_PLOTS.has(pid):
			m.objects.erase(m.door_tile(m.VILLAGE_PLOTS[pid].anchor))
			m.worldgen._spawn_house_node(m.VILLAGE_PLOTS[pid].anchor, pid)
			m.worldgen._trim_paths_under_building(m.VILLAGE_PLOTS[pid].anchor)
	# 고장 마을의 집 — 세계를 지을 때는 칸만 놓였다 (그때는 m.world 가
	# 없다). 그림은 여기서 세운다. 짓는 게 아니라 처음부터 있는 집이라
	# 조건 없이 전부 세운다
	for hid: String in m.HAMLETS:
		for entry: Array in (m.HAMLETS[hid] as Dictionary).houses:
			var ha: Vector2i = entry[0]
			m.objects.erase(m.door_tile(ha))
			m.worldgen._spawn_house_node(ha, String(entry[1]))
	if GameData.house_lv >= 1:
		m.objects.erase(m.door_tile(m.HOME_ANCHOR))
		m.worldgen._spawn_house_node(m.HOME_ANCHOR)
		m.worldgen._trim_paths_under_building(m.HOME_ANCHOR)
	if GameData.forest_quest in ["visit", "done"]:
		# 숲속의 집 (스토리 5) — 저장된 발자취 그대로 그림만 다시 세운다
		m.objects.erase(m.door_tile(m.FOREST_HOUSE_ANCHOR))
		m.worldgen._spawn_house_node(m.FOREST_HOUSE_ANCHOR)
	if GameData.move_house.x >= 0:
		# 재민의 집 (스토리 3) — 플레이어가 정한 자리에 다시 세운다
		m.objects.erase(m.door_tile(GameData.move_house))
		m.worldgen._spawn_house_node(GameData.move_house)
	# 나머지는 **가까운 것만** 세운다 (아래 _stream_nodes).
	# 세계가 네 배가 되면서 나무·돌이 만 개를 넘었는데, world 는 y정렬을
	# 쓰므로 자식이 만 개면 **매 프레임 만 개를 정렬한다** — 걸을 때마다
	# 화면이 끊긴 게 이것이었다. 화면 둘레만 세우고 나머지는 안 만든다.
	_stream_center = Vector2i(-9999, -9999)
	_stream_prev = Rect2i()
	_spawn_queue.clear()
	_stream_nodes()
	_drain_spawn_queue(true)   # 세계를 처음 펼 때는 한 번에 (여긴 이미 멈춰 있다)
	m.farming._recount_pasture()   # 불러온 세이브의 울타리도 목초지로 인정한다
	m.farming.rebuild_sprinklers() # 세계가 통째로 바뀌었으니 목록도 다시
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
		"home_sign":
			# 새로 지은 집 앞 문패 — 누구 집인지 여기서 정한다
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
		"old_barn":
			texture = m.tex["barn"]    # 방치된 옛 헛간 (메인 스토리 17)
			offset = Vector2(0, -160)
		"old_lookout":
			texture = m.tex["old_lookout"]   # 옛 전망대 (메인 스토리 18)
			offset = Vector2(0, -100)
		"old_bench":
			texture = m.tex["old_bench"]     # 무너진 나무 의자
		"carved_stone":
			texture = m.tex["carved_stone"]  # 글씨가 새겨진 돌
		"seed_sprout":
			texture = m.tex["crop_sprout"]   # 할아버지의 씨앗에서 돋은 새싹
		"bent_tree":
			texture = m.tex["tree_bare"]     # 마을 쪽으로 굽은 나무
			offset = Vector2(0, -100)
		"fence":
			texture = m.tex["fence"]
		"sprinkler":
			texture = m.tex["sprinkler"]
		"forage_berry":
			texture = m.tex["forage_berry"]
		"forage_herb":
			texture = m.tex["forage_herb"]
		"forage_dandelion":
			texture = m.tex["forage_dandelion"]
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
			# 만수의 해변 노점 — 차양 지붕이 위로 솟아 있어 밑변을 칸에 맞춘다
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
		"landmark_greattree", "landmark_falls", "deco_cairn":
			# 고장의 랜드마크 — 화면 열두 칸이 넘는 큰 그림. 밑변을 칸에
			# 맞추고, 배율은 아래에서 0.5로 못 박는다 (건물과 같은 도트 밀도).
			# 여러 장이라 첫 장으로 세우고, _tick_landmarks 가 돌린다
			texture = m.tex[kind + "_0"]
			offset = Vector2(0, -texture.get_height())
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
		"deco_wheel":
			# 물방앗간 곁의 물레방아 — 돈다 (_tick_landmarks)
			texture = m.tex["deco_wheel_0"]
			offset = Vector2(0, -texture.get_height())
		"deco_stonelamp":
			# 돌계단을 따라 늘어선 석등 — 하나로 볼 것이 아니라 **줄지어**
			# 섰을 때 길의 방향과 길이를 말한다
			texture = m.tex["deco_stonelamp_0"]
			offset = Vector2(0, -texture.get_height())
		"horse":
			texture = m.tex["horse_side_0"]   # 세워 둔 말
			offset = Vector2(0, -80)
		# ---- 가게 마당에 내놓는 것들 ----
		#
		# 그림은 진작에 있었는데 이 match 에 없어서 **투명하게** 놓였다
		# (texture 가 null 인 채로 노드만 선다). 전부 32x32 한 칸짜리라
		# 밑변을 칸에 맞추고(-height), 배율은 OBJECT_SCALES 가 잡는다.
		"flower_pot", "chest", "storage_box", "ore_node", "rock_wedge", \
		"bait", "crystal", "rope", "broom":
			texture = m.tex[kind]
			offset = Vector2(0, -texture.get_height())
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
	elif kind == "chief_hut":
		# 이장의 거처는 낡은 오두막·새 집 둘 다 **우리 도트 밀도**로 그렸다.
		# 그림 한 도트가 4px이라 0.5배로 얹어야 화면에서 2px이 되고, 그래야
		# 사람·다른 집과 도트 크기가 맞는다.
		# (예전엔 오두막만 옛 1px 밀도라 이 보정에서 빼 뒀었다. 그때 오두막은
		#  화면 72x62px — 주인공 64x96px보다 낮아, 이장이 제 집보다 컸다.)
		sc = 0.5
	elif kind.begins_with("landmark_") or kind == "deco_wheel" \
			or kind == "deco_stonelamp" or kind == "deco_cairn":
		sc = 0.5   # 원본 4px = 도트 한 칸 (make_landmarks.js)
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
		var od: Dictionary = m.objects.get(pos, {})
		var lie: float = float(od.get("fallen", 0.0))
		if lie != 0.0:
			_lay_tree_down(node.get_child(0), lie)   # 누운 채로 길을 막은 나무
		# ---- 벨 수 있는 나무와 못 베는 나무 ----
		#
		# 둘이 똑같이 생겨서, 빽빽한 숲에서는 어느 것이 벽이고 어느 것이
		# 목재인지 도끼를 대 봐야 알 수 있었다 (「나무가 너무 우거져
		# 벨 엄두가 나지 않는다」). **못 베는 것은 한 톤 어둡게** 깐다 —
		# 깊은 숲은 뒤로 물러나고 벨 수 있는 나무만 앞으로 나온다.
		if bool(od.get("fixed", false)):
			(node.get_child(0) as Sprite2D).modulate = DEEP_WOOD
	elif m.LANDMARK_FRAMES.has(kind):
		m.landmark_sprites.append([node.get_child(0), kind])
	m.world.add_child(node)


# ---- 누워 있는 나무 ----
#
# 길 위로 넘어온 나무는 **그림만** 누워 있다. 판정은 선 나무와 똑같다 —
# 도끼로 베고, 목재가 나오고, 길이 열린다. 새 그림을 그리지 않고 서 있는
# 나무를 밑동째 눕혀 쓴다 (`_fell_tree`가 쓰러뜨리는 각과 같은 각이다).
#
# 누운 쪽은 **넘어온 쪽**을 따른다 (dir: -1 서쪽 / +1 동쪽). 길 양옆에서
# 한 그루씩 넘어오는데 남은 몸통이 둘 다 같은 쪽으로 누워 있으면 방금 본
# 것과 어긋난다.
func _lay_tree_down(spr: Sprite2D, dir: float) -> void:
	if spr.texture == null:
		return
	var pivot := Vector2(m.TILE / 2.0,
		(spr.offset.y + spr.texture.get_height()) * spr.scale.y)
	var a := FALL_ANGLE * (1.0 if dir > 0.0 else -1.0)
	spr.rotation = a
	spr.position = pivot - pivot.rotated(a)


func _refresh_tree_sprite(pos: Vector2i) -> void:
	if not m.obj_nodes.has(pos) or not m.objects.has(pos):
		return
	if m.objects[pos].kind != "tree":
		return
	var spr: Sprite2D = m.obj_nodes[pos].get_child(0)
	var lie: float = float(m.objects[pos].get("fallen", 0.0))
	if lie != 0.0:
		_lay_tree_down(spr, lie)   # 도끼질로 그림이 바뀌어도 계속 누워 있다
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
	# 묵은 땅을 걷어내는 일 — 옛 농지(스토리 16)·옛 헛간(스토리 17)에서만 센다
	var gone := str(m.objects.get(pos, {}).get("kind", ""))
	if gone in ["weed", "rock", "tree"]:
		m.story.story16_field_work("clear", pos)
		m.story.story17_barn_work("clear", pos)
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
# 벨 수 없는 나무(fixed)에 입히는 빛깔 — 그늘진 깊은 숲.
# 채도를 조금 죽이고 어둡게만 한다. 색을 바꾸면 다른 종류의 나무로 보인다.
const DEEP_WOOD := Color(0.66, 0.74, 0.68)

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


# ---- 쓰러진 채로 **남는** 나무 ----
#
# `_fell_tree`는 벤 나무다 — 넘어가고, 잠깐 누웠다가, 스르르 사라진다.
# 이쪽은 길가에 서 있던 나무가 **길 위로 넘어와 그대로 눕는** 것이다
# (메인 스토리 1의 첫 나무). 넘어가는 그림은 같고, 착지한 자리에 누운
# 몸통이 남는다.
#
# 통행은 **부르는 즉시** 막힌다 (objects에 이미 놓고 부른다). 그림만
# 늦게 온다 — 넘어가는 동안은 쓰러지는 나무가 그 자리를 덮고 있다.
func _topple_onto(pos: Vector2i, dir: float, rest: Array) -> void:
	if not m.obj_nodes.has(pos):
		for p: Vector2i in rest:
			_spawn_object_node(p, "tree")
		m.objects.erase(pos)
		return
	_fell_tree(pos, dir)
	if m._tree_falls.is_empty():
		for p: Vector2i in rest:
			_spawn_object_node(p, "tree")
		return
	var f: Dictionary = m._tree_falls[-1]
	f["rest"] = rest
	f["wait"] = 0.0        # 도끼질이 아니다 — 그 자리에서 바로 기운다
	var stv: Variant = f.stump
	if is_instance_valid(stv):
		# 밑동만 남기는 건 「벤 나무」의 그림이다. 이건 뿌리째 넘어간 것이다
		(stv as Sprite2D).queue_free()
		f["stump"] = null


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
			if f.has("rest"):
				# 길 위로 넘어와 **그대로 눕는다** — 누운 몸통을 그 자리에
				# 세우고 쓰러지던 그림은 물린다 (둘 다 누운 나무라 이어져 보인다)
				for p: Vector2i in f.rest:
					if m.objects.has(p) and not m.obj_nodes.has(p):
						_spawn_object_node(p, str(m.objects[p].kind))
				m._tree_falls.erase(f)
				node.queue_free()
				continue
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
	if kind == "sprinkler":
		m.farming.add_sprinkler(pos)   # 물 주는 목록에 넣는다 (매번 다 뒤지지 않게)


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


# ---- 랜드마크를 돌린다 ----
#
# 폭포가 안 흐르면 그건 폭포 그림이지 폭포가 아니다. 세계에 넷뿐이라
# 매 프레임 도는 것보다 훨씬 싸다 — 초당 일곱 번, 그림 넷만 갈아 끼운다.
func _tick_landmarks() -> void:
	for e: Array in m.landmark_sprites:
		var spr: Sprite2D = e[0]
		if not is_instance_valid(spr):
			continue
		var kind: String = e[1]
		var n: int = int(m.LANDMARK_FRAMES[kind])
		spr.texture = m.tex["%s_%d" % [kind, m.lm_frame % n]]


# ---- 가까운 것만 세운다 ----
#
# 세계를 네 배로 넓히니 나무·돌이 만 개를 넘었다. world 는 y정렬(뒤에
# 있는 것이 먼저 그려지게)을 쓰는데, 자식이 만 개면 **매 프레임 만 개를
# 정렬한다.** 걸을 때마다 화면이 끊긴 게 이것이었다.
#
# 화면에 보이지도 않는 지도 반대편 나무까지 노드로 들고 있을 이유가 없다.
# 주인공 둘레 한 화면 반만 세우고, 걸어 나가면 뒤엣것은 치운다.
#
# **건물·랜드마크는 안 치운다.** 몇 개 안 되는데다, 멀리서 보이는 것이
# 그 몫이라 화면 밖이라고 없애면 다가갈 때 불쑥 나타난다.
const STREAM_W := 34      # 좌우 (화면 반폭 15칸 + 여유)
const STREAM_H := 26      # 위아래
const KEEP_ALWAYS := ["house", "chief_hut", "barn", "barn_block", "art_block",
	"cave", "worldtree", "onsen", "stall", "board", "auction", "sign",
	"housesite", "plotsite", "home_sign", "homeplot", "old_lookout", "old_barn",
	"landmark_greattree", "landmark_falls", "deco_cairn", "deco_wheel",
	"deco_fountain", "horse", "old_book", "seed_sprout", "carved_stone",
	"old_bench", "bent_tree"]

var _stream_center := Vector2i(-9999, -9999)
var _stream_prev := Rect2i()      # 지난번 창 (새로 들어온 띠만 훑으려고)

# ---- 세우는 일을 **여러 프레임에 나눠** 한다 ----
#
# world 는 y정렬을 쓴다. y정렬 노드에 자식을 붙이면 그 자리에서 형제들이
# 다시 정렬된다 — 자식이 천 개면 한 번 붙일 때마다 천 개를 정렬한다.
# 빽빽한 숲에서는 한 칸 걸을 때마다 예닐곱 그루가 새로 들어오니, 그
# 순간에만 정렬이 예닐곱 번 겹쳐 화면이 딱딱 걸렸다.
#
# 「폭포 가기 전까지는 끊기고 폭포를 보면 안 끊긴다」가 이것이었다 —
# 폭포 둘레는 물이라 새로 세울 게 없다.
#
# 한 프레임에 몇 개씩만 세운다. 화면 밖 한 칸 너머에서 들어오는 것이라
# 몇 프레임 늦어도 눈에 안 띈다.
const SPAWN_PER_FRAME := 5
var _spawn_queue: Array[Vector2i] = []


func _drain_spawn_queue(burst := false) -> void:
	var n := 0
	while not _spawn_queue.is_empty() and (burst or n < SPAWN_PER_FRAME):
		var pos: Vector2i = _spawn_queue.pop_back()
		if m.obj_nodes.has(pos) or not m.objects.has(pos):
			continue
		var kind: String = str(m.objects[pos].kind)
		if kind == "house":
			continue
		_spawn_object_node(pos, kind)
		if kind == "tree":
			_refresh_tree_sprite(pos)   # 계절·손상 단계를 바로 반영한다
		n += 1


func _stream_nodes() -> void:
	if m.player == null:
		return
	var pt := m.player_tile()
	if pt == _stream_center:
		return
	var prev := _stream_prev
	_stream_center = pt
	var keep := Rect2i(pt.x - STREAM_W, pt.y - STREAM_H,
		STREAM_W * 2 + 1, STREAM_H * 2 + 1)
	# **튜토리얼 숲은 통째로 세운다.**
	#
	# 이 창은 「카메라는 늘 주인공을 한가운데 둔다」를 전제로 잡혀 있다.
	# 세계에서는 맞는 말이지만, 튜토리얼 숲은 화면 하나만 한 공간이라
	# 카메라 제한에 걸려 붙박여 있다 — 주인공이 서쪽 어귀에 서 있어도
	# 화면에는 동쪽 끝까지 다 보인다. 주인공 둘레(좌우 34칸)만 세우면
	# 화면 오른쪽 숲이 통째로 안 그려지고 흙길만 뜬 맨땅이 남는다.
	# 한 장뿐인 공간이니 그 한 장을 다 세운다.
	if GameData.tutorial_space:
		keep = m.TUTORIAL_REGION
	_stream_prev = keep
	# 한 칸도 안 겹치게 멀리 뛰었으면(순간이동·불러오기) 통째로 다시 센다
	if not prev.intersects(keep):
		prev = Rect2i()
	# ① 나간 것 치우기 — 세워 둔 것만 훑으므로 몇백 개다
	for pos: Vector2i in m.obj_nodes.keys():
		if keep.has_point(pos):
			continue
		var kind: String = str(m.objects.get(pos, {}).get("kind", "house"))
		if kind in KEEP_ALWAYS:
			continue
		var node: Node2D = m.obj_nodes[pos]
		if node.get_child_count() > 0:
			m.tree_sprites.erase(node.get_child(0))
			m._faded_trees.erase(node.get_child(0))
		m._fade_a.erase(pos)
		node.queue_free()
		m.obj_nodes.erase(pos)
	# ② 들어온 것 세우기 — **새로 들어온 띠만** 훑는다.
	#
	# 창 전체(69x53 = 3657칸)를 매번 훑으면 한 칸 걸을 때마다 사천 번을
	# 뒤진다. 걸으면 초에 서너 칸이니 그것만으로 화면이 걸린다.
	# 한 칸 움직였을 때 새로 들어오는 것은 **세로 한 줄과 가로 한 줄**뿐이다.
	var bands: Array[Rect2i] = []
	if prev.size.x == 0:
		bands.append(keep)                       # 처음 한 번은 통째로
	else:
		var dx: int = keep.position.x - prev.position.x
		var dy: int = keep.position.y - prev.position.y
		if dx > 0:
			bands.append(Rect2i(prev.end.x, keep.position.y, dx, keep.size.y))
		elif dx < 0:
			bands.append(Rect2i(keep.position.x, keep.position.y, -dx, keep.size.y))
		if dy > 0:
			bands.append(Rect2i(keep.position.x, prev.end.y, keep.size.x, dy))
		elif dy < 0:
			bands.append(Rect2i(keep.position.x, keep.position.y, keep.size.x, -dy))
	for band: Rect2i in bands:
		for y in range(band.position.y, band.end.y):
			if y < 0 or y >= m.MAP_H:
				continue
			for x in range(band.position.x, band.end.x):
				if x < 0 or x >= m.MAP_W:
					continue
				var pos := Vector2i(x, y)
				if m.obj_nodes.has(pos) or not m.objects.has(pos):
					continue
				var kind2: String = str(m.objects[pos].kind)
				if kind2 == "house":
					continue          # 건물 그림은 앵커에서 따로 세운다
				_spawn_queue.append(pos)
