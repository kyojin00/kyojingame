# 그리는 쪽 — 지형 위에 얹히는 것들과 화면 안내.
#
# main의 `_draw()`가 세계(땅·작물·타겟)를 그리고, 그 위에 얹히는 것은 전부
# 여기서 그린다: 건물 이름표·축제 천막·온실 유리·날씨·길잡이 화살표·조작 안내.
#
# **`draw_*`는 CanvasItem의 메서드다.** 이 모듈은 그냥 Node라 자기 것이 없어서
# 전부 `m.draw_*`로 부른다. 그리고 그 호출은 **main의 `_draw()`가 도는 동안에만**
# 유효하다 — 다른 때 부르면 아무 일도 일어나지 않는다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinRenderer
extends Node

var m: KyojinMain    # main.gd

# ---- 살아 있는 마을 (앰비언트) ----
#
# 정적인 화면과 살아 있는 화면의 차이는 **아무도 시키지 않은 움직임**이다:
# 구름 그림자가 땅 위를 지나가고, 나무에서 잎이 한두 장 떨어지고,
# 걸음마다 발밑에서 잔것이 인다. 셋 다 게임 규칙에는 손대지 않는다.
#
# 검증(KYOJIN_SHOT)에서는 끈다 — 무작위 픽셀이 어서션을 흔들면 안 된다.
# 앨범(KYOJIN_ALBUM)은 사람 눈으로 보는 사진이니 켠 채로 찍는다.
var _ambient_on := true
var _cloud_tex: Texture2D = null
var _amb_leaf_cd := 0.0
var _step_accum := 0.0
var _last_player_pos := Vector2.ZERO
const CLOUD_CELL := Vector2(560.0, 430.0)   # 구름 하나가 사는 칸
const CLOUD_WIND := Vector2(8.0, 3.2)       # 초당 흐르는 속도 (세계 px)


func _ready() -> void:
	_ambient_on = OS.get_environment("KYOJIN_SHOT") == "" \
		or OS.get_environment("KYOJIN_ALBUM") != ""
	# 구름 그림자 원판 — 가장자리로 갈수록 옅어지는 둥근 얼룩 한 장
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var d := Vector2(x - 48, y - 48).length() / 46.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_cloud_tex = ImageTexture.create_from_image(img)
	# 자연물 접지 그림자 원판 — 미리 눌러 놓은 타원. 남보라 (회색은 회색이 아니다)
	var sim := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 64:
			var d := Vector2((x - 32) / 30.0, (y - 12) / 11.0).length()
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			sim.set_pixel(x, y, Color(0.10, 0.08, 0.18, a * 0.52))
	_obj_shadow_tex = ImageTexture.create_from_image(sim)


# ---- 자연물의 접지 그림자 ----
#
# 나무·바위는 여태 그림자 없이 떠 있었다 — 밑동의 풀숲 몇 포기로는 땅을
# 못 딛는다. 세계보다 밑에 깔린 레이어(main.shadows)에 부드러운 타원을
# 한 장씩 그리면 화면의 모든 나무가 단번에 땅으로 내려앉는다.
# 노드에 자식을 끼우지 않는 이유: 온 코드가 「자식 0번 = 스프라이트」로
# 잡고 있어서, 그 사이에 그림자를 끼우면 전부 흔들린다.
var _obj_shadow_tex: Texture2D = null
const OBJ_SHADOW_KINDS := ["tree", "rock", "bigrock", "searock", "bent_tree"]

func _draw_object_shadows() -> void:
	if _obj_shadow_tex == null or m.player == null:
		return
	if m.interior.visible or m.cave.visible \
			or (m.shop_room != null and m.shop_room.visible):
		return
	var view := _view_rect().grow(96.0)
	for pos: Vector2i in m.obj_nodes:
		var od: Dictionary = m.objects.get(pos, {})
		var kind: String = str(od.get("kind", ""))
		if not kind in OBJ_SHADOW_KINDS:
			continue
		var node: Node2D = m.obj_nodes[pos]
		if not is_instance_valid(node) or not view.has_point(node.position):
			continue
		if node.get_child_count() == 0:
			continue
		var spr: Sprite2D = node.get_child(0)
		if spr.texture == null:
			continue
		# 폭은 그 그루의 화면 폭을 따른다 — 캐노피와 거의 같게, 바위는 조금 넓게
		# (바위는 밑동의 흙무더기가 그림자 안쪽을 가리므로 밖으로 비어져 나와야 보인다)
		var w: float = spr.texture.get_width() * spr.scale.x \
			* (0.95 if kind == "tree" or kind == "bent_tree" else 1.25)
		if kind == "tree" and int(od.get("hp", m.TREE_HP)) < m.TREE_HP:
			w *= 0.4                       # 잎을 잃은 나무는 그림자도 준다
		var sz := Vector2(w, w * 0.36)
		# 중심을 밑변보다 **아래로** — 위에서 내려다보는 화면에서는 캐노피가
		# 제 그림자의 위쪽을 다 가린다. 아래로 고여야 눈에 보인다
		m.shadows.draw_texture_rect(_obj_shadow_tex,
			Rect2(node.position + Vector2(m.TILE / 2.0 - sz.x / 2.0, -sz.y * 0.28), sz),
			false)


# 화면이 보고 있는 세계 사각형
func _view_rect() -> Rect2:
	var inv: Transform2D = m.overlay.get_canvas_transform().affine_inverse()
	var vp: Vector2 = m.get_viewport().get_visible_rect().size
	var o: Vector2 = inv * Vector2.ZERO
	return Rect2(o, (inv * vp) - o)


# 구름 그림자 — 칸마다 구름이 하나 살거나 안 살고, 바람에 실려 흐른다.
# 자리는 해시로 굳혀 두므로 같은 구름이 늘 같은 꼴로 온다
func _draw_clouds() -> void:
	if not _ambient_on or _cloud_tex == null:
		return
	if m.interior.visible or m.cave.visible \
			or (m.shop_room != null and m.shop_room.visible):
		return
	var view := _view_rect().grow(340.0)
	var off: Vector2 = CLOUD_WIND * m.weather_time
	var c0x := floori((view.position.x + off.x) / CLOUD_CELL.x) - 1
	var c1x := floori((view.end.x + off.x) / CLOUD_CELL.x) + 1
	var c0y := floori((view.position.y + off.y) / CLOUD_CELL.y) - 1
	var c1y := floori((view.end.y + off.y) / CLOUD_CELL.y) + 1
	for cy in range(c0y, c1y + 1):
		for cx in range(c0x, c1x + 1):
			var r0 := m._hash01(cx * 7 + 3, cy * 11 + 5)
			if r0 < 0.42:
				continue                       # 빈 하늘도 많다
			var pos := Vector2(
				(cx + m._hash01(cx, cy)) * CLOUD_CELL.x,
				(cy + m._hash01(cy * 3 + 1, cx * 5 + 2)) * CLOUD_CELL.y) - off
			var sc := 2.0 + m._hash01(cx * 13 + 1, cy * 17 + 4) * 1.6
			var size := Vector2(96.0 * sc * 1.7, 96.0 * sc)
			var a := 0.065 + 0.05 * m._hash01(cx * 5 + 2, cy * 3 + 7)
			# 그늘은 남보라로 기운다 — 회색 그늘은 때가 된다
			m.overlay.draw_texture_rect(_cloud_tex,
				Rect2(pos - size * 0.5, size), false,
				Color(0.10, 0.10, 0.22, a))
			# 같은 구름의 작은 짝 — 덩어리가 둘이어야 구름 꼴이 난다
			var pos2 := pos + Vector2(size.x * 0.34, size.y * 0.18)
			m.overlay.draw_texture_rect(_cloud_tex,
				Rect2(pos2 - size * 0.30, size * 0.6), false,
				Color(0.10, 0.10, 0.22, a * 0.8))


# ---- 밤 등불 빛무리 ----
#
# 밤(CanvasModulate)이 짙어질수록 가로등·창가에 따뜻한 빛무리가 살아난다.
# 등불 자리는 프레임마다 온 objects를 뒤지면 비싸니 몇 초에 한 번 모은다
var _lamp_cache: Array = []
var _anvil_cache: Array = []
var _lamp_cache_cd := 0.0
var _glint_cd := 0.0
var _spark_cd := 0.0
# 새 — 풀밭에 앉아 모이를 쪼다가, 다가가면 날아오른다
var _birds: Array = []
var _bird_cd := 4.0

func _draw_glows() -> void:
	if m.night == null or m.player == null:
		return
	if m.interior.visible or m.cave.visible \
			or (m.shop_room != null and m.shop_room.visible):
		return
	# 어둠의 깊이 — 밤 색이 어두울수록 빛무리가 짙어진다
	var dark := 1.0 - m.night.color.v
	if dark < 0.18 or _cloud_tex == null:
		return
	var a := clampf((dark - 0.18) / 0.5, 0.0, 1.0)
	var view := _view_rect().grow(160.0)
	for lp: Vector2 in _lamp_cache:
		if not view.has_point(lp):
			continue
		var size := Vector2(210, 210)
		m.glow.draw_texture_rect(_cloud_tex, Rect2(lp - size * 0.5, size), false,
			Color(1.0, 0.72, 0.32, 0.22 * a))
		m.glow.draw_texture_rect(_cloud_tex, Rect2(lp - size * 0.25, size * 0.5), false,
			Color(1.0, 0.85, 0.5, 0.18 * a))


func _refresh_lamp_cache() -> void:
	_lamp_cache.clear()
	_anvil_cache.clear()
	for pos: Vector2i in m.objects:
		var k := String(m.objects[pos].kind)
		if k == "deco_lamp":
			# 불알은 기둥 위에 있다 — 칸 가운데보다 위
			_lamp_cache.append(Vector2(pos.x * m.TILE + 16, pos.y * m.TILE - 14))
		elif k == "deco_forge":
			_lamp_cache.append(Vector2(pos.x * m.TILE + 16, pos.y * m.TILE + 20))
		elif k == "deco_anvil":
			_anvil_cache.append(Vector2(pos.x * m.TILE + 16, pos.y * m.TILE + 2))


# 앰비언트 한 틱 — main._process가 매 프레임 부른다
func _update_ambient(delta: float) -> void:
	_lamp_cache_cd -= delta
	if _lamp_cache_cd <= 0.0:
		_lamp_cache_cd = 4.0
		_refresh_lamp_cache()
	if not _ambient_on or m.player == null:
		return
	if m.interior.visible or m.cave.visible \
			or (m.shop_room != null and m.shop_room.visible):
		return
	# ① 나무에서 잎이 진다 — 화면 안 무작위 칸을 찔러 나무를 찾는다
	_amb_leaf_cd -= delta
	if _amb_leaf_cd <= 0.0:
		_amb_leaf_cd = randf_range(0.55, 1.2)
		if GameData.season_key() != "winter":
			var view := _view_rect()
			var tx0 := maxi(0, int(view.position.x / m.TILE))
			var ty0 := maxi(0, int(view.position.y / m.TILE))
			var tx1 := mini(m.MAP_W - 1, int(view.end.x / m.TILE))
			var ty1 := mini(m.WORLD_H - 1, int(view.end.y / m.TILE))
			for attempt in 14:
				var pos := Vector2i(randi_range(tx0, tx1), randi_range(ty0, ty1))
				var obj: Variant = m.objects.get(pos)
				if obj == null or String(obj.kind) != "tree":
					continue
				var leaf := "leaf_fall" if GameData.season_key() == "fall" else "leaf"
				spawn_burst(Vector2(pos.x * m.TILE + 16, pos.y * m.TILE - 30),
					leaf, 0.25, 16.0)
				break
	# ② 발걸음 — 일정 거리마다 바닥에 맞는 잔것이 인다
	var dmove := m.player.position.distance_to(_last_player_pos)
	_last_player_pos = m.player.position
	if dmove > 0.05 and dmove < 60.0:
		_step_accum += dmove
	if _step_accum >= 30.0:
		_step_accum = 0.0
		var t := m.player_tile()
		if t.y >= 0 and t.y < m.WORLD_H and t.x >= 0 and t.x < m.MAP_W:
			var gk: String = m.grid[t.y][t.x].ground
			var pk := ""
			if gk == "grass" or gk == "":
				pk = "step_grass"
			elif gk in ["yard", "soil", "path", "sand"]:
				pk = "step_dust"
			if pk != "":
				spawn_burst(m.player.position + Vector2(0, 4), pk, 1.0, 4.0)
	# ③ 물가 반짝임 — 화면 안 물 칸에서 해가 부서진다
	_glint_cd -= delta
	if _glint_cd <= 0.0:
		_glint_cd = randf_range(0.25, 0.6)
		var view := _view_rect()
		var tx0 := maxi(0, int(view.position.x / m.TILE))
		var ty0 := maxi(0, int(view.position.y / m.TILE))
		var tx1 := mini(m.MAP_W - 1, int(view.end.x / m.TILE))
		var ty1 := mini(m.WORLD_H - 1, int(view.end.y / m.TILE))
		for attempt in 10:
			var wx := randi_range(tx0, tx1)
			var wy := randi_range(ty0, ty1)
			if m.grid[wy][wx].ground != "water":
				continue
			spawn_burst(Vector2(wx * m.TILE + randf_range(4, 28),
				wy * m.TILE + randf_range(4, 28)), "glint", 1.0, 2.0)
			break
	# ④ 망치질 불티 — 모루 곁에 사람이 있으면 이따금 튄다
	_spark_cd -= delta
	if _spark_cd <= 0.0:
		_spark_cd = randf_range(1.6, 3.2)
		for ap: Vector2 in _anvil_cache:
			if not _view_rect().grow(60.0).has_point(ap):
				continue
			var someone := m.player.position.distance_to(ap) < 110.0
			if not someone:
				for mn in m.npcs:
					if mn.visible and mn.position.distance_to(ap) < 110.0:
						someone = true
						break
			if someone:
				spawn_burst(ap + Vector2(0, -14), "spark", 1.0, 3.0)
			break
	# ⑤ 새 — 풀밭에 두어 마리 내려앉고, 다가가면 날아오른다
	_update_birds(delta)


# ---- 새 ----
#
# 파티클로는 안 된다 — 새는 **반응**해야 산다. 앉아서 콕콕 쪼다가
# 사람이 다가오면 푸드덕 날아오르는 것, 그 한 박자가 생동감의 전부다.
func _update_birds(delta: float) -> void:
	_bird_cd -= delta
	var view := _view_rect()
	if _bird_cd <= 0.0 and _birds.size() < 3:
		_bird_cd = randf_range(5.0, 9.0)
		# 화면 가장자리 쪽 풀밭에 내려앉는다 (한복판이면 바로 쫓겨난다)
		var tx0 := maxi(0, int(view.position.x / m.TILE))
		var ty0 := maxi(0, int(view.position.y / m.TILE))
		var tx1 := mini(m.MAP_W - 1, int(view.end.x / m.TILE))
		var ty1 := mini(m.WORLD_H - 1, int(view.end.y / m.TILE))
		for attempt in 12:
			var bx := randi_range(tx0, tx1)
			var by := randi_range(ty0, ty1)
			var g0: String = m.grid[by][bx].ground
			if (g0 != "grass" and g0 != "") or m.objects.has(Vector2i(bx, by)):
				continue
			var bp := Vector2(bx * m.TILE + 16, by * m.TILE + 16)
			if m.player.position.distance_to(bp) < 140.0:
				continue
			_birds.append({"p": bp, "v": Vector2.ZERO, "state": "ground",
				"t": randf_range(4.0, 9.0), "phase": randf() * TAU,
				"tint": randf() < 0.5})
			break
	var alive: Array = []
	for b in _birds:
		b.t -= delta
		b.phase += delta * (14.0 if b.state == "fly" else 3.0)
		if b.state == "ground":
			# 가끔 한 발짝 총총
			if randf() < delta * 0.8:
				b.p += Vector2(randf_range(-6, 6), randf_range(-3, 3))
			# 사람이 다가오면 날아오른다
			if m.player.position.distance_to(b.p) < 74.0 or b.t <= 0.0:
				b.state = "fly"
				b.t = 2.6
				b.v = Vector2(randf_range(-40, 40), -randf_range(90, 130))
		else:
			b.p += b.v * delta
			b.v.x *= 1.0 + delta * 0.4
		if b.state == "fly" and b.t <= 0.0:
			continue
		alive.append(b)
	_birds = alive


# 새 그리기 — 몸통 한 점, 날개 두 점. 날 때는 날개가 퍼덕인다
func _draw_birds() -> void:
	for b in _birds:
		var body := Color(0.32, 0.3, 0.38) if b.tint else Color(0.55, 0.42, 0.3)
		var wing := Color(0.2, 0.19, 0.26) if b.tint else Color(0.4, 0.3, 0.2)
		var p: Vector2 = b.p
		if b.state == "ground":
			var peck := 1.0 if fmod(b.phase, 2.4) < 0.4 else 0.0
			m.overlay.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(5, 3)), body)
			m.overlay.draw_rect(Rect2(p + Vector2(2, -4 + peck * 2.0), Vector2(2, 2)), body)
			m.overlay.draw_rect(Rect2(p + Vector2(-1, -4), Vector2(3, 2)), wing)
		else:
			var flap := sin(b.phase) * 3.0
			m.overlay.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(4, 2)), body)
			m.overlay.draw_rect(Rect2(p + Vector2(-4, -2 - flap), Vector2(3, 2)), wing)
			m.overlay.draw_rect(Rect2(p + Vector2(3, -2 - flap), Vector2(3, 2)), wing)


func _draw_building_signs() -> void:
	var f: Font = m.UI_FONT_SMALL
	for pid: String in GameData.village_built:
		if not m.VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = m.VILLAGE_PLOTS[pid].anchor
		_draw_name_plate(f, str(m.VILLAGE_PLOTS[pid].name),
			Vector2((a.x + 2) * m.TILE + 16, a.y * m.TILE - 6))
	# 손보기 전에도 집은 서 있다 — 다만 아직 「우리집」이라 부르기엔 이르다
	_draw_name_plate(f, "우리집" if GameData.house_lv >= 1 else "할아버지의 낡은 집",
		Vector2((m.HOME_ANCHOR.x + 2) * m.TILE + 16, m.HOME_ANCHOR.y * m.TILE - 6))


func _draw_name_plate(f: Font, text: String, at: Vector2) -> void:
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var box := Rect2(at.x - w / 2.0 - 5, at.y - 13, w + 10, 17)
	m.overlay.draw_rect(box.grow(1), Color(0.24, 0.15, 0.08, 0.95))
	m.overlay.draw_rect(box, Color(0.86, 0.7, 0.44, 0.96))
	m.overlay.draw_rect(Rect2(box.position, Vector2(box.size.x, 3)),
		Color(0.95, 0.82, 0.58, 0.96))
	m.overlay.draw_string(f, Vector2(at.x - w / 2.0, at.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.18, 0.07))


func _draw_festival() -> void:
	var f: Dictionary = GameData.festival_today()
	if f.is_empty() or GameData.minutes >= GameData.FEST_END:
		return
	var cols: Array = m.FEST_COLORS.get(str(f.id), m.FEST_COLORS.flower)
	# 깃발 줄을 거는 구간 (모이는 자리 위)
	var x0: int = m.FISH_YARD_X0 if str(f.place) == "pier" else m.PLAZA.position.x
	var x1: int = m.FISH_YARD_X1 if str(f.place) == "pier" else m.PLAZA.end.x - 1
	# 낚시대회 깃발줄은 **물가 남쪽 잔디** 위에 건다. DOCK_Y-2 였는데,
	# 호수를 넓히면서 그 줄이 물 한복판이 됐다 — 줄이 수면에 잠겼다.
	var y: int = m.DOCK_Y + 1 if str(f.place) == "pier" else m.PLAZA.position.y
	var top := float(y) * m.TILE
	for i in range(x0, x1):
		var px := float(i) * m.TILE
		# 줄은 살짝 늘어지게 (사인 곡선)
		var sag := sin(float(i - x0) / 3.0) * 4.0 + 6.0
		m.overlay.draw_line(Vector2(px, top + sag), Vector2(px + m.TILE, top + sag + 1.0),
			Color(0.35, 0.26, 0.18), 2.0)
		var c: Color = cols[(i - x0) % cols.size()]
		var a := Vector2(px + 8, top + sag + 2)
		m.overlay.draw_colored_polygon(PackedVector2Array([
			a, a + Vector2(14, 0), a + Vector2(7, 16)]), c)


func _draw_greenhouse() -> void:
	if not GameData.greenhouse_built:
		return
	var r := Rect2(m.GREENHOUSE.position.x * m.TILE, m.GREENHOUSE.position.y * m.TILE,
		m.GREENHOUSE.size.x * m.TILE, m.GREENHOUSE.size.y * m.TILE)
	m.overlay.draw_rect(r, Color(0.72, 0.9, 0.95, 0.22))              # 유리
	# 지붕 띠 (위쪽을 조금 더 밝게 — 유리집처럼 보이게)
	m.overlay.draw_rect(Rect2(r.position, Vector2(r.size.x, m.TILE * 0.7)),
		Color(0.85, 0.95, 1.0, 0.3))
	m.overlay.draw_rect(r, Color(0.9, 0.96, 1.0, 0.75), false, 4.0)   # 테두리
	for i in range(1, m.GREENHOUSE.size.x):                          # 세로 뼈대
		var x := r.position.x + i * m.TILE
		m.overlay.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y),
			Color(0.85, 0.93, 0.96, 0.28), 1.0)
	for i in range(1, m.GREENHOUSE.size.y):                          # 가로 뼈대
		var y := r.position.y + i * m.TILE
		m.overlay.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y),
			Color(0.85, 0.93, 0.96, 0.28), 1.0)
	# 유리에 비치는 빛 한 줄
	m.overlay.draw_line(r.position + Vector2(8, 8),
		r.position + Vector2(r.size.x * 0.45, r.size.y * 0.45),
		Color(1, 1, 1, 0.22), 4.0)


func spawn_particles(t: Vector2i, kind: String) -> void:
	spawn_burst(Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16), kind)


# 칸이 아니라 **월드 좌표** 아무 데서나 터뜨린다. 나무 우듬지처럼 칸 한가운데가
# 아닌 곳에서 잎이 떨어져야 할 때 쓴다.
#   mult   개수 배수 (0.5면 절반만)
#   spread 처음 흩어져 있는 반경
func spawn_burst(center: Vector2, kind: String, mult: float = 1.0,
		spread: float = 5.0) -> void:
	var d: Dictionary = m.PARTICLE_DEFS[kind]
	var drift: float = float(d.get("drift", 14.0))
	var life: float = float(d.get("life", 1.0))
	var size: float = float(d.get("size", 1.0))
	var sway: float = float(d.get("sway", 0.0))
	for i in int(ceilf(float(d.n) * mult)):
		m.particles.append({
			"p": center + Vector2(randf_range(-spread, spread),
				randf_range(-spread * 0.8, spread * 0.4)),
			"v": Vector2(randf_range(-drift, drift), float(d.up) + randf_range(-8, 8)),
			"c": d.c,
			"life": randf_range(0.3, 0.55) * life,
			"g": float(d.g),
			"size": size,
			"sway": sway,
			"phase": randf_range(0.0, TAU),
		})


func _update_particles(delta: float) -> void:
	if m.particles.is_empty():
		return
	var alive := []
	for pt in m.particles:
		pt.life -= delta
		if pt.life <= 0.0:
			continue
		pt.v.y += pt.g * delta
		# 나뭇잎은 떨어지면서 좌우로 팔랑거린다
		if float(pt.sway) > 0.0:
			pt.p.x += sin(float(pt.phase) + float(pt.life) * 9.0) * float(pt.sway) * delta
		pt.p += pt.v * delta
		alive.append(pt)
	m.particles = alive


func _crop_texture(cell: Dictionary) -> Texture2D:
	if cell.dead:
		return m.tex["withered"]
	var def: Dictionary = GameData.CROPS[cell.crop_id]
	var t := float(cell.crop_day) / m.farming._grow_total(def)
	if t >= 1.0:
		return m.tex["mature_" + cell.crop_id]
	if t < 0.34:
		return m.tex["crop_sprout"]
	if t < 0.67:
		return m.tex["crop_small"]
	return m.tex["crop_medium"]


func _draw_overlay() -> void:
	_draw_clouds()   # 구름 그림자가 제일 밑 — 안내 표시를 어둡게 하면 안 된다
	# 길라잡이 화살표는 없앴다 — 퀘스트 목표 문구와 길 자체로 안내한다
	_draw_festival()
	_draw_greenhouse()
	_draw_building_signs()
	_draw_house_preview()

	# 낚시 인디케이터 (대기: 점점점 / 입질: 노란 느낌표)
	if m.player != null:
		if m.fishing_state == "waiting":
			var base := m.player.position + Vector2(-8, -96)
			var dots := int(m.weather_time * 2.0) % 3 + 1
			for i in dots:
				m.overlay.draw_rect(Rect2(base + Vector2(i * 5, 0), Vector2(2, 2)),
					Color(1, 1, 1, 0.8))
		elif m.fishing_state == "bite":
			var base := m.player.position + Vector2(-2, -108)
			m.overlay.draw_rect(Rect2(base, Vector2(3, 7)), Color(1, 0.85, 0.2))
			m.overlay.draw_rect(Rect2(base + Vector2(0, 9), Vector2(3, 3)), Color(1, 0.85, 0.2))

	# 말을 걸어 달라는 표시: 머리 위에서 통통 튀는 느낌표
	if m.story._postman != null and m.story._postman_state == "wait" and not m.ui_open():
		_draw_bang(m.story._postman.position + Vector2(0, -136))
	# 퀘스트 대상 NPC 표시 — ! 말을 걸어야 할 사람 / ? 납품(보고)할 사람
	# (대상은 GameData.quest_npc_marks()가 스토리 단계를 보고 정한다)
	if not m.ui_open():
		var marks: Dictionary = GameData.quest_npc_marks()
		for mn in m.npcs:
			if mn.visible and marks.has(mn.id):
				if str(marks[mn.id]) == "!":
					_draw_bang(mn.position + Vector2(0, -124))
				else:
					_draw_question(mn.position + Vector2(0, -124))

	_draw_birds()
	for pt in m.particles:
		var s: float = float(pt.size)
		m.overlay.draw_rect(Rect2(pt.p, Vector2(s, s)), pt.c)

	# 경험치 획득 플로팅 텍스트
	for ft in m.float_texts:
		var a: float = clampf(1.4 - ft.t, 0.0, 1.0)
		var p: Vector2 = ft.pos + Vector2(0, -ft.t * 26.0)
		var tw: float = m.UI_FONT_SMALL.get_string_size(ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		m.overlay.draw_string_outline(m.UI_FONT_SMALL, p + Vector2(-tw / 2.0, 0), ft.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 3, Color(0.05, 0.04, 0.08, a))
		m.overlay.draw_string(m.UI_FONT_SMALL, p + Vector2(-tw / 2.0, 0), ft.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.65, 0.95, 0.5, a))

	_draw_context_hint()
	_draw_weather()


func _draw_bang(pos: Vector2) -> void:
	var bob := absf(sin(m.weather_time * 4.0)) * 6.0
	var p := pos + Vector2(0, -bob)
	var body := Rect2(p + Vector2(-3, 0), Vector2(6, 20))
	var dot := Rect2(p + Vector2(-3, 24), Vector2(6, 7))
	for r: Rect2 in [body, dot]:
		m.overlay.draw_rect(r.grow(2.0), Color(0.12, 0.08, 0.05, 0.92))  # 외곽선
		m.overlay.draw_rect(r, Color(1.0, 0.86, 0.25))


# 납품/보고가 가능한 NPC 머리 위 물음표 — 느낌표와 같은 픽셀 결
func _draw_question(pos: Vector2) -> void:
	var bob := absf(sin(m.weather_time * 4.0)) * 6.0
	var p := pos + Vector2(0, -bob)
	var segs: Array = [
		Rect2(p + Vector2(-8, 0), Vector2(14, 5)),    # 윗머리
		Rect2(p + Vector2(2, 4), Vector2(5, 7)),      # 오른쪽 내림
		Rect2(p + Vector2(-3, 10), Vector2(8, 5)),    # 가운데 꺾임
		Rect2(p + Vector2(-3, 14), Vector2(5, 5)),    # 목
		Rect2(p + Vector2(-3, 24), Vector2(6, 7)),    # 점
	]
	for r: Rect2 in segs:
		m.overlay.draw_rect(r.grow(2.0), Color(0.12, 0.08, 0.05, 0.92))
	for r: Rect2 in segs:
		m.overlay.draw_rect(r, Color(0.55, 0.95, 0.45))


# 머리 위 안내가 뜨는 높이 (월드 픽셀). 예전 값(100)은 주인공 정수리에
# 딱 붙어 있어서 도트 그림과 글자가 서로 먹었다 — 한 뼘 띄운다.
const HINT_LIFT := 124.0


func _context_hint() -> Array:
	# 반환: [문구, 기준 위치(월드)] 또는 []
	if m.player == null or m.ui_open():
		return []
	# 머리 위 안내는 **말풍선 위로** 비켜선다.
	#
	# 둘 다 「주인공 머리 위」에 붙어 있어서 말을 하는 순간 글자가 겹쳐
	# 둘 다 못 읽었다. 말풍선이 떠 있으면 그 키만큼 더 올라간다.
	var lift: float = HINT_LIFT + (m.hud.bubble_lift() if m.hud != null else 0.0)
	var above_player := m.player.position + Vector2(0, -lift)
	if m.fishing_state == "bite":
		return ["지금이다!", above_player]
	if m.fishing_state == "waiting":
		return []
	# 첫 만남: 걸어와서 기다리는 우체부 아저씨 머리 위에 안내를 띄운다
	if m.story._postman != null and m.story._postman_state == "wait" \
			and (m.player.position - m.story._postman.position).length() < m.POSTMAN_TALK_DIST:
		return ["%s: 말 걸기" % GameData.key_label("talk"),
			m.story._postman.position + Vector2(0, -(HINT_LIFT + 12.0))]
	# 대화는 대화키(F) 하나로 통일 — 어떤 키인지 머리 위에 같이 적어 준다
	if m.actions.nearby_npc() != null:
		return ["%s: 대화" % GameData.key_label("talk"), above_player]
	if m.actions.nearby_animal() != null:
		return ["%s: 쓰다듬기" % GameData.key_label("talk"), above_player]
	var t: Vector2i = m.actions.target_tile()
	if not m.objects.has(t):
		# 앞 칸은 비었는데 걸음을 막고 있는 오브젝트가 있으면 그것을 가리킨다
		var bt: Vector2i = m.actions._blocking_object_tile()
		if bt.x != -999:
			t = bt
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.MAP_H:
		return []
	var above_tile := Vector2(t.x * m.TILE + 16, t.y * m.TILE - 24)
	var obj: Variant = m.objects.get(t)
	if obj != null:
		match obj.kind:
			"board":
				return ["의뢰 게시판", above_tile]
			"horse":
				return ["%s: 말 타기" % GameData.key_label("mount"), above_tile]
			"sign":
				if t == m.STORY_TRAIL_SIGN:
					return ["낡은 표지판", above_tile]
				if t == m.FISH_SIGN:
					return ["낚시터 안내", above_tile]
				if t == m.GREENHOUSE_SIGN:
					return ["온실 짓기" if not GameData.greenhouse_built
						else "온실", above_tile]
			"cave":
				return ["동굴 탐험", above_tile]
			"worldtree":
				return ["세계수 동굴 — 위험!", above_tile]
			"landmark_greattree", "landmark_falls", "deco_cairn":
				for lm: Dictionary in m.LANDMARKS:
					if lm.kind == obj.kind:
						return [String(lm.name), above_tile]
				return []
			"forage_berry", "forage_herb":
				return ["채집", above_tile]
			"old_book":
				return ["낡은 책을 살펴본다", above_tile]
			"housesite":
				return ["집 짓기 — 목재 %d" % GameData.HOUSE_BUILD_WOOD, above_tile]
			"tree":
				if bool(obj.get("young", false)):
					return ["어린 나무 — 자라는 중", above_tile]
				return ["벌목", above_tile]
			"rock", "bigrock":
				return ["채광", above_tile]
			"house":
				var bk: String = m.actions._building_kind_at(t)
				if bk == "home":
					return ["집에 들어가기", above_tile]
				if bk == "home_ruin":
					return ["집 보수 — 목재 %d" % GameData.HOUSE_BUILD_WOOD, above_tile]
				if bk in ["general", "ranch", "smith", "fish"]:
					return [m.BUILDING_NAMES[bk], above_tile]
				# 서 있기는 하되 아직 사람이 들지 않은 가게
				var ep: String = m.plot_body_at(t)
				if ep != "":
					return ["빈 %s" % str(m.VILLAGE_PLOTS[ep].name), above_tile]
		return []
	var cell: Dictionary = m.grid[t.y][t.x]
	if cell.crop_id != "":
		if cell.dead:
			return ["시듦 — 호미로 정리", above_tile]
		var def: Dictionary = GameData.CROPS[cell.crop_id]
		var pct := float(cell.crop_day) / m.farming._grow_total(def)
		if pct >= 1.0:
			return ["수확!", above_tile]
		var text := "성장 %d%%" % int(pct * 100.0)
		if m.farming._crop_thirsty(cell):
			text += " · 물을 한 번 더!"
		elif not cell.watered:
			text += " · 물주기!"
		return [text, above_tile]
	if cell.ground == "water" and GameData.tool == "rod":
		return ["낚시", above_tile]
	return []


func _nearest_object_pos(kind: String) -> Variant:
	var best: Variant = null
	var best_d := INF
	for pos: Vector2i in m.objects:
		if m.objects[pos].kind != kind:
			continue
		var p := Vector2(pos.x * m.TILE + 16, pos.y * m.TILE + 16)
		var d := p.distance_to(m.player.position)
		if d < best_d:
			best_d = d
			best = p
	return best


# 집터 자리 고르기 (동물의 숲식) — 마우스가 가리키는 곳에 집이 차지할
# 범위를 칸마다 초록(가능)/빨강(불가)으로 비춰 보여준다.
# 굵은 테두리는 집 몸체(5x4), 노란 칸은 현관이 될 자리다.
func _draw_house_preview() -> void:
	if not m.house_preview:
		return
	var door: Vector2i = m.story.preview_door()
	var a := door - Vector2i(2, 3)
	for y in range(a.y - 1, a.y + 5):
		for x in range(a.x - 1, a.x + 6):
			var col := Color(0.3, 0.9, 0.4, 0.28) if m.story._house_tile_ok(x, y) \
				else Color(0.95, 0.3, 0.25, 0.4)
			m.overlay.draw_rect(Rect2(x * m.TILE + 1, y * m.TILE + 1,
				m.TILE - 2, m.TILE - 2), col)
	# 집 몸체(5x4) 테두리 + 현관 칸
	var ok := m.story._can_place_house(a)
	m.overlay.draw_rect(Rect2(a.x * m.TILE, a.y * m.TILE, 5 * m.TILE, 4 * m.TILE),
		Color(1, 1, 1, 0.9) if ok else Color(1, 0.5, 0.4, 0.9), false, 2.0)
	m.overlay.draw_rect(Rect2(door.x * m.TILE + 4, door.y * m.TILE + 4,
		m.TILE - 8, m.TILE - 8), Color(1, 0.85, 0.3, 0.65))
	var tip := "좌클릭: 집터 설치 · 우클릭/ESC: 취소" if ok \
		else "빨간 칸이 있으면 놓을 수 없다"
	var f: Font = m.UI_FONT
	var tw: float = f.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var tp := Vector2(a.x * m.TILE + 2.5 * m.TILE - tw / 2.0, (a.y - 2) * m.TILE)
	m.overlay.draw_string_outline(f, tp, tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3,
		Color(0.1, 0.08, 0.05))
	m.overlay.draw_string(f, tp, tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(1, 0.95, 0.8))


func _draw_context_hint() -> void:
	var hint := _context_hint()
	if hint.is_empty():
		return
	var text: String = hint[0]
	var base: Vector2 = hint[1]
	var w := m.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var pos := Vector2(base.x - w / 2.0, base.y)
	m.overlay.draw_string_outline(m.UI_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3,
		Color(0.08, 0.06, 0.12, 0.9))
	m.overlay.draw_string(m.UI_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 0.9))


func _draw_weather() -> void:
	var w := m.weather_now()
	var full_w := m.MAP_W * m.TILE + 20.0
	var full_h := m.MAP_H * m.TILE + 10.0
	if w == GameData.WEATHER_RAIN:
		for i in 360:
			var sx := m._hash01(i, 1) * full_w - 10.0
			var sy := fposmod(m._hash01(i, 2) * full_h + m.weather_time * 280.0, full_h) - 5.0
			m.overlay.draw_line(Vector2(sx - 2, sy - 7), Vector2(sx, sy),
				Color(0.72, 0.82, 1.0, 0.5), 1.0)
		_draw_rain_splashes(34)
	elif w == GameData.WEATHER_SNOW:
		for i in 240:
			var sx := fposmod(m._hash01(i, 1) * full_w + sin(m.weather_time * 1.5 + i) * 12.0, full_w)
			var sy := fposmod(m._hash01(i, 2) * full_h + m.weather_time * 35.0, full_h) - 5.0
			m.overlay.draw_rect(Rect2(Vector2(sx, sy), Vector2(1, 1)), Color(1, 1, 1, 0.85))
	elif w == GameData.WEATHER_STORM:
		# 굵고 비스듬한 빗줄기 + 이따금 번쩍
		for i in 620:
			var sx := m._hash01(i, 1) * full_w - 10.0
			var sy := fposmod(m._hash01(i, 2) * full_h + m.weather_time * 520.0, full_h) - 5.0
			m.overlay.draw_line(Vector2(sx - 9, sy - 20), Vector2(sx, sy),
				Color(0.78, 0.85, 1.0, 0.85), 2.0)
		var flash := fposmod(m.weather_time, 5.2)
		if flash < 0.18:
			m.overlay.draw_rect(_camera_rect(), Color(1, 1, 1, 0.45 * (1.0 - flash / 0.18)))
		_draw_rain_splashes(58)
	elif w == GameData.WEATHER_FOG:
		# 가장자리로 갈수록 짙어지는 안개 (가까운 곳만 또렷하다)
		var view2 := _camera_rect()
		m.overlay.draw_rect(view2, Color(0.87, 0.89, 0.93, 0.34))
		var band: float = view2.size.y * 0.1
		for i in 5:
			var inset: float = band * float(i)
			var r := Rect2(view2.position + Vector2(inset * 1.7, inset),
				view2.size - Vector2(inset * 3.4, inset * 2.0))
			if r.size.x <= band or r.size.y <= band:
				break
			m.overlay.draw_rect(r, Color(0.9, 0.92, 0.95, 0.13), false, band)
		# 흘러가는 안개 띠
		for i in 16:
			var by := view2.position.y + fposmod(m._hash01(i, 3) * view2.size.y
				+ m.weather_time * 7.0, view2.size.y)
			var bh: float = 12.0 + m._hash01(i, 4) * 30.0
			m.overlay.draw_rect(Rect2(view2.position.x, by, view2.size.x, bh),
				Color(0.95, 0.96, 0.98, 0.16))
	elif w == GameData.WEATHER_STAR and GameData.minutes >= 17.0 * 60.0:
		# 별밤: 해가 지면 하늘빛 알갱이가 반짝인다
		var view3 := _camera_rect()
		for i in 210:
			var px2 := view3.position.x + m._hash01(i, 5) * view3.size.x
			var py2 := view3.position.y + m._hash01(i, 6) * view3.size.y
			var tw: float = 0.35 + 0.65 * absf(sin(m.weather_time * 1.8 + float(i) * 1.7))
			m.overlay.draw_rect(Rect2(px2, py2, 3, 3), Color(1, 0.99, 0.88, tw))
			if m._hash01(i, 7) > 0.86:   # 몇 개는 십자로 크게 반짝인다
				m.overlay.draw_rect(Rect2(px2 - 3, py2 + 1, 9, 1), Color(1, 1, 0.92, tw * 0.8))
				m.overlay.draw_rect(Rect2(px2 + 1, py2 - 3, 1, 9), Color(1, 1, 0.92, tw * 0.8))


func _camera_rect() -> Rect2:
	var half := Vector2(960.0, 540.0) / (2.0 * m.CAMERA_ZOOM)
	return Rect2(m.player.position - half, half * 2.0)


# 빗방울이 닿는 자리 — 바닥에 잠깐 퍼지는 잔물결 고리.
# 하늘에서 내리는 줄만 있고 바닥이 조용하면 비가 「화면 앞 유리」에
# 내리는 것처럼 보인다. 닿는 자리가 있어야 비가 세계 안에 내린다.
# 상태 없이 시간·해시로만 계산한다 — 고리마다 제 주기를 돌고 끝나면
# 다른 자리에서 다시 시작한다
func _draw_rain_splashes(count: int) -> void:
	var view := _camera_rect()
	for i in count:
		var ph: float = m.weather_time * 2.4 + m._hash01(i, 8) * 7.0
		var cyc := int(ph)
		var t := ph - float(cyc)
		var px: float = view.position.x + m._hash01(i * 3 + cyc, 9) * view.size.x
		var py: float = view.position.y + m._hash01(cyc * 7 + i, 10) * view.size.y
		var r: float = 1.5 + t * 4.5
		var a: float = (1.0 - t) * 0.38
		m.overlay.draw_set_transform(Vector2(px, py), 0.0, Vector2(1.0, 0.45))
		m.overlay.draw_arc(Vector2.ZERO, r, 0.0, TAU, 10,
			Color(0.85, 0.92, 1.0, a), 1.0)
	m.overlay.draw_set_transform(Vector2.ZERO)
