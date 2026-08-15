# 동굴 탐험: 층별 생성 던전. 슬라임을 모두 잡으면 보상 상자 + 다음 층.
extends CanvasLayer

# 동굴은 **한 화면에 다 들어오지 않는다.** 층이 깊어질수록 넓어지고,
# 화면은 주인공을 따라 움직인다 (ZOOM 배로 확대해 그린다).
#
# 좌표계는 예전 그대로 「타일 x TS 픽셀」이다 (OX/OY = 0).
# 이동 속도·판정 거리 같은 값을 건드리지 않으려고 논리 좌표는 그대로 두고,
# **그리기만** 확대·이동한다 (_draw_cave의 draw_set_transform).
const TS := 32.0         # 타일 (논리 픽셀)
const OX := 0.0
const OY := 0.0
const ZOOM := 0.56       # 화면에 그릴 때의 배율 — 바깥 카메라(CAMERA_ZOOM)와 똑같이
const VIEW := Vector2(960.0, 540.0)

# 줌을 낮출 때마다 한 화면에 보이는 칸이 늘어난다 —
# 「탐험」이 남으려면 층이 그만큼 넓어야 해서 기본 크기도 같이 키운다
# (한 화면 53.6 x 30.1칸 · 층은 그 1.8배 이상)
const CAVE_W_BASE := 100  # 1층 크기
const CAVE_H_BASE := 58
const CAVE_GROW := 2      # 한 층 내려갈 때마다 (가로/세로)
const CAVE_W_MAX := 140
const CAVE_H_MAX := 96

var GW := CAVE_W_BASE
var GH := CAVE_H_BASE
var cam := Vector2.ZERO
var seen := {}           # 미니맵에 드러난 칸

# 휘두르기 도트·도구 자리·자세 값은 바깥 세상과 **똑같은 것**을 쓴다.
# 여기서 따로 잡으면 동굴에서만 어깨가 어긋난다.
const PlayerArt := preload("res://scripts/player.gd")

var main: Node2D
var canvas: Control
var player_sprite: Sprite2D
var tool_sprite: Sprite2D    # 휘두르는 동안만 보인다

var floor_num := 1
var walls := {}         # Vector2i -> true
var ores := {}          # Vector2i -> true
var shrooms := {}       # Vector2i -> true — 발광 버섯 (스토리 10 조사 후, 3층+)
var monsters: Array = []
var chest_pos := Vector2i(-1, -1)
var stairs_pos := Vector2i(-1, -1)
var entry_pos := Vector2i(1, 11)

var ppos := Vector2.ZERO
var pdir := "right"
var moving := false
var anim_time := 0.0
var attack_cd := 0.0
var hurt_cd := 0.0
# 휘두르기 — 바깥 세상과 같은 도트를 쓴다 (감기 -> 내리침 -> 되돌아옴).
# swing_t는 남은 시간, swing_len은 이번 동작의 전체 길이,
# swing_dir은 **시작할 때의 방향** (도중에 방향을 틀어도 그림이 안 튄다).
var swing_t := 0.0
var swing_len := 0.0
var swing_dir := "right"
var swing_fx := 0.0      # 히트박스 번쩍임 — 그림보다 짧게 스친다
# ---- 피격 연출 ----
# 맞는 순간: 하얀 번쩍 한 프레임 -> 붉은 기 + 눈 질끈, 히트스톱, 화면 흔들림,
# 미끄러지는 넉백. 남은 무적시간에는 점멸해서 언제 다시 맞는지 보여 준다.
var hurt_flash := 0.0            # 하얀 번쩍 남은 시간
var hitstop := 0.0               # 세상이 한숨 멎는 시간
var shake_t := 0.0               # 화면 흔들림 남은 시간
var shake_off := Vector2.ZERO    # 이번 프레임의 흔들림 (화면 px)
var kb_vel := Vector2.ZERO       # 피격 넉백 속도 — 순간이동 대신 미끄러진다
var dmg_pops: Array = []         # 피해 숫자 팝업 {pos, t, txt}


func _ready() -> void:
	layer = 15
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.045, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_cave)
	add_child(canvas)
	player_sprite = Sprite2D.new()
	player_sprite.centered = false
	player_sprite.scale = Vector2(0.5, 0.5)
	add_child(player_sprite)
	# 손에 든 도구. 쥐는 자리를 축으로 돌리니 가운데 맞춤을 끈다
	tool_sprite = Sprite2D.new()
	tool_sprite.centered = false
	tool_sprite.visible = false
	add_child(tool_sprite)


var worldtree := false  # 세계수 동굴 모드 (강화 몬스터 + 3층 보스)
var lastroom := false   # 돌문 안쪽 — 할아버지의 마지막 연구 공간 (메인 스토리 20)


# 돌문 안쪽으로 들어간다 — 한 방뿐이고, 봉인된 것이 기다린다
func open_last() -> void:
	worldtree = false
	lastroom = true
	floor_num = 1
	_gen_floor()
	hurt_cd = 0.0
	hurt_flash = 0.0
	hitstop = 0.0
	shake_t = 0.0
	shake_off = Vector2.ZERO
	kb_vel = Vector2.ZERO
	dmg_pops.clear()
	visible = true
	Sound.play_sfx("sfx_place")
	main.hud.show_message("계단 끝은 넓은 돌방이었다.\n벽마다 할아버지의 글씨 — 그리고 안쪽에서 무언가 움직인다.", 6.0)


func open(wt: bool = false, start_floor: int = 1) -> void:
	lastroom = false
	if GameData.energy < 15.0:
		main.hud.show_message("체력이 너무 낮다... 회복하고 오자. (요리를 먹거나 잠시 기다리기)")
		return
	worldtree = wt
	# 승강기로 내려간 층에서 시작한다 (세계수 동굴은 언제나 1층부터)
	floor_num = 1 if wt else maxi(1, start_floor)
	GameData.mine_reach(floor_num)
	_gen_floor()
	# 지난 방문의 피격 연출이 남아 있지 않게
	hurt_cd = 0.0
	hurt_flash = 0.0
	hitstop = 0.0
	shake_t = 0.0
	shake_off = Vector2.ZERO
	kb_vel = Vector2.ZERO
	dmg_pops.clear()
	visible = true
	Sound.play_sfx("sfx_place")
	if worldtree:
		main.hud.show_message("세계수 동굴... 공기가 다르다. 3층에 수호자가 있다!")
	else:
		main.hud.show_message("동굴 %d층 — %s\nSpace: 공격 · 몬스터를 모두 잡자!"
			% [floor_num, floor_title()], 4.0)
		if special != "":
			main.hud.event_toast(str(SPECIALS[special].name))


func close() -> void:
	visible = false
	lastroom = false
	Sound.play_sfx("sfx_place")


# 층 유형 — 예전에는 모든 층이 「테두리 + 8% 기둥」으로 똑같이 생겨서,
# 1층이든 30층이든 눈에 보이는 것이 같았다.
const LAYOUTS := ["open", "pillars", "maze", "cavern"]
const LAYOUT_NAMES := {
	"open": "너른 굴", "pillars": "돌기둥 숲", "maze": "좁은 갱도", "cavern": "동공",
}
# 드물게 층 전체가 특별해진다
const SPECIALS := {
	"vein": {"name": "광맥방", "hint": "벽마다 광석이 박혀 있다!"},
	"grove": {"name": "이끼방", "hint": "축축한 이끼 사이로 약초가 자란다."},
	"treasure": {"name": "보물방", "hint": "상자가 먼저 보인다. 조심해서 열자."},
}
const SPECIAL_CHANCE := 0.26

var layout := "open"
var special := ""
var reachable := {}      # 입구에서 걸어 닿는 칸 (여기에만 무언가를 놓는다)


func floor_title() -> String:
	var t: String = str(LAYOUT_NAMES.get(layout, ""))
	if special != "":
		t += " · " + str(SPECIALS[special].name)
	return t


func _wall_at(x: int, y: int) -> void:
	walls[Vector2i(x, y)] = true


# 입구에서 실제로 걸어 닿는 칸만 남긴다.
# (미로/동공은 벽 배치에 따라 섬이 생길 수 있다 — 거기에 계단을 놓으면 갇힌다)
func _mark_reachable() -> void:
	reachable.clear()
	var queue: Array[Vector2i] = [entry_pos]
	reachable[entry_pos] = true
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 1 or n.y < 1 or n.x >= GW - 1 or n.y >= GH - 1:
				continue
			if reachable.has(n) or walls.has(n):
				continue
			reachable[n] = true
			queue.append(n)


func _gen_floor() -> void:
	walls.clear()
	ores.clear()
	shrooms.clear()
	monsters.clear()
	seen.clear()
	chest_pos = Vector2i(-1, -1)
	stairs_pos = Vector2i(-1, -1)
	# 층이 깊어질수록 넓어진다
	GW = mini(CAVE_W_MAX, CAVE_W_BASE + (floor_num - 1) * CAVE_GROW)
	GH = mini(CAVE_H_MAX, CAVE_H_BASE + (floor_num - 1) * CAVE_GROW)
	entry_pos = Vector2i(2, GH - 3)

	# 층마다 모양을 바꾼다 (세계수 동굴은 언제나 너른 굴)
	layout = "open" if (worldtree or lastroom) else LAYOUTS[randi() % LAYOUTS.size()]
	special = ""
	if not worldtree and floor_num > 1 and randf() < SPECIAL_CHANCE:
		var keys: Array = SPECIALS.keys()
		special = str(keys[randi() % keys.size()])

	# 테두리
	for y in GH:
		for x in GW:
			if x == 0 or y == 0 or x == GW - 1 or y == GH - 1:
				_wall_at(x, y)
	# 유형별 속 채우기
	match layout:
		"pillars":
			# 규칙적인 돌기둥 (사이는 언제나 지나갈 수 있다)
			for y in range(2, GH - 2, 3):
				for x in range(2, GW - 2, 3):
					if randf() < 0.85:
						_wall_at(x + (randi() % 2), y)
		"maze":
			# 격자 미로: 짝수 칸을 기둥으로 두면 통로가 반드시 이어진다
			for y in range(2, GH - 2, 2):
				for x in range(2, GW - 2, 2):
					_wall_at(x, y)
					var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(0, 1), Vector2i(0, -1)][randi() % 4]
					if randf() < 0.6:
						_wall_at(x + d.x, y + d.y)
		"cavern":
			# 큼직한 바위 덩어리 몇 개
			for i in randi_range(3, 5):
				var cx := randi_range(3, GW - 5)
				var cy := randi_range(2, GH - 4)
				for dy in randi_range(2, 3):
					for dx in randi_range(2, 4):
						_wall_at(cx + dx, cy + dy)
		_:
			for y in range(1, GH - 1):
				for x in range(1, GW - 1):
					if randf() < 0.08 and Vector2i(x, y).distance_to(entry_pos) > 3.0:
						_wall_at(x, y)
	# 입구 둘레는 언제나 비워 둔다
	for dy in range(-1, 2):
		for dx in range(-1, 3):
			walls.erase(entry_pos + Vector2i(dx, dy))
	_mark_reachable()

	# 광석 (광맥방은 세 배)
	var ore_n := 2 + floor_num / 2
	if special == "vein":
		ore_n *= 3
	for i in ore_n:
		var p := _free_tile(3.0)
		if p.x >= 0:
			ores[p] = true

	# 발광 버섯 (스토리 10 「동굴과 탐험」) — 조사가 시작된 뒤, 3층부터
	# 어두운 굴 바닥에 돋아난다. E로 딴다 (연구 노트 동굴 컬렉션 표본)
	if GameData.story10_open() and not worldtree and not lastroom and floor_num >= 3:
		for i in randi_range(1, 2):
			var sp := _free_tile(6.0)
			if sp.x >= 0:
				shrooms[sp] = true

	# 보물방은 상자가 처음부터 놓여 있다
	if special == "treasure":
		var cp := _free_tile(4.0)
		if cp.x >= 0:
			chest_pos = cp

	# 몬스터 (층이 깊어질수록 종류/수 증가, 세계수 동굴은 2배 강함)
	var hp_mult := 2 if worldtree else 1
	if lastroom:
		# 봉인되어 있던 것 — 할아버지가 끝내 피해 다니던 존재와 그 그림자들
		_spawn_mob("ghost", 70)
		_spawn_mob("ghost", 10)
		_spawn_mob("ghost", 10)
		_spawn_mob("treant", 24)
	elif worldtree and floor_num == 3:
		# 보스층: 숲의 수호자 + 호위
		_spawn_mob("treant", 40)
		_spawn_mob("ghost", 4)
		_spawn_mob("ghost", 4)
	else:
		# 이끼방은 조용하다 (대신 얻는 것도 다르다)
		var mob_scale := 0.5 if special == "grove" else 1.0
		for i in int((2 + floor_num) * mob_scale):
			_spawn_mob("slime", (1 + int(floor_num / 3.0)) * hp_mult)
		if floor_num >= 2 or worldtree:
			for i in int((1 + int(floor_num / 2.0)) * mob_scale):
				_spawn_mob("bat", 1 * hp_mult)
		if floor_num >= 4 or (worldtree and floor_num >= 2):
			for i in maxi(1, int((floor_num - 2) / 2.0 * mob_scale)):
				_spawn_mob("ghost", (2 + int(floor_num / 4.0)) * hp_mult)
		# 다섯 층마다 미니보스 — 승강기 층이 「도달했다」는 느낌이 나게
		if not worldtree and floor_num % 5 == 0:
			_spawn_mob("treant", 12 + floor_num * 2)

	# 계단은 처음부터 어딘가에 있다 — 넓어진 동굴에서 몬스터를 한 마리씩
	# 찾아다니지 않고도 내려갈 수 있어야 「탐험」이 된다.
	# (상자는 여전히 전멸 보상이다)
	var st := _free_tile(minf(GW, GH) * 0.55)
	stairs_pos = Vector2i(-1, -1) if lastroom \
		else (st if st.x >= 0 else Vector2i(GW - 3, 2))
	ppos = Vector2(OX + (entry_pos.x + 0.5) * TS, OY + (entry_pos.y + 0.5) * TS)
	pdir = "right"
	# 층을 내려오는 순간까지 휘두르던 동작은 여기서 끊는다
	swing_t = 0.0
	swing_fx = 0.0
	tool_sprite.visible = false
	cam = ppos
	_mark_seen()


func _spawn_mob(type: String, hp: int) -> void:
	var p := _free_tile(5.0)
	if p.x < 0:
		return
	monsters.append({
		"type": type,
		"pos": Vector2(OX + (p.x + 0.5) * TS, OY + (p.y + 0.5) * TS),
		"vel": Vector2.ZERO, "think": 0.0, "hp": hp,
		"anim": randf() * 10.0,
	})


# 입구에서 걸어 닿는 빈 칸을 고른다.
# 닿지 않는 칸에 계단이나 상자를 놓으면 층을 못 넘어간다.
func _free_tile(min_dist: float) -> Vector2i:
	for attempt in 60:
		var p := Vector2i(randi_range(1, GW - 2), randi_range(1, GH - 2))
		if reachable.has(p) and not ores.has(p) and not shrooms.has(p) \
				and p != chest_pos and p != entry_pos \
				and float(p.distance_to(entry_pos)) >= min_dist:
			return p
	# 멀리 떨어진 자리를 못 찾았으면 거리 조건을 풀고 아무 데나
	for p2: Vector2i in reachable:
		if not ores.has(p2) and not shrooms.has(p2) \
				and p2 != entry_pos and p2 != chest_pos:
			return p2
	return Vector2i(-1, -1)


func _blocked_at(p: Vector2) -> bool:
	for off in [Vector2(-10, -6), Vector2(10, -6), Vector2(-10, 8), Vector2(10, 8)]:
		var t := Vector2i(int((p.x + off.x - OX) / TS), int((p.y + off.y - OY) / TS))
		if t.x < 0 or t.y < 0 or t.x >= GW or t.y >= GH or walls.has(t) or ores.has(t):
			return true
		if t == chest_pos or t == stairs_pos:
			if t == stairs_pos:
				continue
			return true
	return false


func _process(delta: float) -> void:
	# 겹쳐 뜬 창(가방·퀘스트·연구노트...)이 있으면 그 창이 먼저다
	if not visible or main.room_overlay_open():
		return
	# 히트스톱 — 맞는 순간 아주 잠깐 모두 멈춘다 (타격이 몸에 박힌다)
	if hitstop > 0.0:
		hitstop -= delta
		canvas.queue_redraw()
		return
	attack_cd -= delta
	hurt_cd -= delta
	swing_t = maxf(0.0, swing_t - delta)
	swing_fx = maxf(0.0, swing_fx - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	shake_t = maxf(0.0, shake_t - delta)
	shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
		* 3.0 * ZOOM * (shake_t / 0.18) if shake_t > 0.0 else Vector2.ZERO
	_update_cam(delta)
	_mark_seen()

	# 이동 (이미 끼어 있으면 충돌 무시하고 빠져나올 수 있게)
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving:
		if v.x != 0.0:
			pdir = "right" if v.x > 0 else "left"  # 대각선 포함 옆모습
		else:
			pdir = "down" if v.y > 0 else "up"
		# 컬렉션 「동굴의 생명」 완성 — 동굴 지리가 익어 발걸음이 빨라진다
		var np := ppos + v * 170.0 * GameData.perk_cave_speed_mult() * delta
		var stuck := _blocked_at(ppos)
		if stuck or not _blocked_at(Vector2(np.x, ppos.y)):
			ppos.x = clampf(np.x, OX + 8, OX + GW * TS - 8)
		if stuck or not _blocked_at(Vector2(ppos.x, np.y)):
			ppos.y = clampf(np.y, OY + 8, OY + GH * TS - 8)
		anim_time += delta

	# 피격 넉백 — 몇 프레임에 걸쳐 밀려나며 잦아든다 (순간이동보다 자연스럽다)
	if kb_vel != Vector2.ZERO:
		var kp := ppos + kb_vel * delta
		if not _blocked_at(kp):
			ppos.x = clampf(kp.x, OX + 8, OX + GW * TS - 8)
			ppos.y = clampf(kp.y, OY + 8, OY + GH * TS - 8)
		kb_vel = kb_vel.move_toward(Vector2.ZERO, 1100.0 * delta)

	# 몬스터
	for m in monsters:
		m.anim += delta
		m.think -= delta
		var to_player: Vector2 = ppos - m.pos
		match m.type:
			"slime":
				if m.think <= 0.0:
					m.think = randf_range(0.6, 1.6)
					if to_player.length() < 140.0:
						m.vel = to_player.normalized() * (52.0 + floor_num * 8.0)
					else:
						m.vel = Vector2.RIGHT.rotated(randf() * TAU) * 40.0
			"bat":
				if m.think <= 0.0:
					# 주기적으로 플레이어를 향해 돌진
					m.think = randf_range(1.2, 2.0)
					if to_player.length() < 240.0:
						m.vel = to_player.normalized() * (140.0 + floor_num * 16.0)
					else:
						m.vel = Vector2.RIGHT.rotated(randf() * TAU) * 68.0
				m.vel = m.vel.move_toward(Vector2.ZERO, 60.0 * delta)  # 돌진 후 감속
			"ghost":
				# 벽을 통과하며 끈질기게 추적
				m.vel = to_player.normalized() * (44.0 + floor_num * 6.0)
			"treant":
				# 느리게 다가오다 주기적으로 돌진한다
				if m.think <= 0.0:
					m.think = randf_range(2.0, 3.0)
					m.vel = to_player.normalized() * 190.0
				else:
					m.vel = m.vel.move_toward(to_player.normalized() * 36.0, 120.0 * delta)
		var np: Vector2 = m.pos + m.vel * delta
		if m.type == "ghost":
			m.pos.x = clampf(np.x, OX + TS, OX + (GW - 1) * TS)
			m.pos.y = clampf(np.y, OY + TS, OY + (GH - 1) * TS)
		elif _blocked_at(np):
			m.vel = -m.vel
		else:
			m.pos = np
		# 접촉 피해 (종류별)
		if hurt_cd <= 0.0 and (m.pos - ppos).length() < 24.0:
			hurt_cd = 0.9
			hurt_flash = 0.09      # 하얀 번쩍 한 프레임
			hitstop = 0.05
			shake_t = 0.18
			var dmg: float = {"slime": 8.0, "bat": 6.0, "ghost": 12.0, "treant": 20.0}[m.type]
			# 부엉이 펫 + 방어구가 받는 피해를 줄인다
			var taken: float = dmg * GameData.pet_cave_def_mult() * GameData.gear_defense_mult()
			GameData.energy -= taken
			Sound.play_sfx("sfx_miss")
			# 넉백은 미끄러짐으로 — _blocked_at이 프레임마다 확인하므로 벽에 안 낀다
			kb_vel = (ppos - m.pos).normalized() * 240.0
			dmg_pops.append({"pos": ppos + Vector2(0.0, -46.0), "t": 0.8,
				"txt": "-%d" % maxi(1, int(round(taken)))})
			if GameData.energy <= 0.0:
				GameData.energy = 10.0
				close()
				main.hud.show_message("동굴에서 쫓겨났다... 기력이 바닥났다!")
				return

	# 피해 숫자 — 떠오르며 사라진다
	for pp in dmg_pops:
		pp.t -= delta
		pp.pos.y -= 26.0 * delta
	dmg_pops = dmg_pops.filter(func(pp: Dictionary) -> bool: return pp.t > 0.0)

	_update_sprite()
	canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# 겹쳐 뜬 창(가방·퀘스트·연구노트...)이 있으면 그 창이 먼저다
	if not visible or main.room_overlay_open():
		return
	if event.is_action_pressed("use_tool"):
		_attack()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	# 이벤트를 소비하지 않으면 같은 E가 main으로 넘어가 동굴이 새로 열린다
	get_viewport().set_input_as_handled()


func _attack() -> void:
	if attack_cd > 0.0:
		return
	# 무기 리듬: 돌 창 = 느리게 한 방 강하게 · 돌 검 = 빠르게 두 번 ·
	# 그 밖(맨손)은 도끼 힘으로 기본 박자
	var wpn: String = GameData.tool if GameData.tool in ["spear", "sword"] else ""
	attack_cd = 1.1 if wpn == "spear" else (0.8 if wpn == "sword" else 0.35)
	_start_swing()
	Sound.play_sfx("sfx_chop", 0.2)
	_attack_hit(wpn, true)
	if wpn == "sword":
		# 둘째 타 — 순수 무기 위력만 (보너스가 두 번 실리지 않게)
		get_tree().create_timer(0.16).timeout.connect(func() -> void:
			if visible:
				_start_swing()
				_attack_hit(wpn, false))


# 휘두르기 시작 — 바깥 세상과 같은 길이·같은 도트를 쓴다
func _start_swing() -> void:
	swing_len = main.SWING_TIME
	swing_t = swing_len
	swing_dir = pdir
	swing_fx = 0.15


func _attack_hit(wpn: String, first: bool) -> void:
	var reach := ppos + _dir_vec() * 28.0
	# 공격력 = 무기(없으면 도끼)의 「위력」 + 전투 숙련도 + 장착한 장비
	var dmg: float = GameData.tool_stat("axe" if wpn == "" else wpn, "power")
	if first:
		dmg += GameData.combat_bonus() + GameData.gear_stat("power")
	# 몬스터 타격
	for m in monsters:
		if (m.pos - reach).length() < 28.0 or (m.pos - ppos).length() < 24.0:
			m.hp -= dmg
			if m.type != "ghost":
				m.vel = (m.pos - ppos).normalized() * 120.0
			if m.hp <= 0:
				monsters.erase(m)
				Sound.play_sfx("sfx_pick", 0.2)
				main.doing.record_kill(m.type)
				# 막힌 수맥을 지키던 것들 (메인 스토리 15)
				main.story.story15_dig_progress("mob", floor_num)
				main.toolwork.gain_skill("combat", {"slime": 6.0, "bat": 8.0, "ghost": 12.0, "treant": 40.0}[m.type])
				match m.type:
					"slime":
						if randf() < 0.35:
							main.doing.gain_item("ore", 1)
							main.hud.show_message("슬라임이 광석을 떨어뜨렸다!")
					"bat":
						if randf() < 0.2:
							main.doing.gain_item("ore", 1)
							main.hud.show_message("박쥐가 광석을 떨어뜨렸다!")
						elif randf() < 0.15:
							main.doing.gain_item("arrow", 1)
							main.hud.show_message("박쥐가 화살을 떨어뜨렸다!")
					"ghost":
						main.doing.gain_item("ore", 1)
						if randf() < 0.15:
							main.doing.gain_item("gem", 1)
							main.hud.show_message("유령이 보석을 떨어뜨렸다!")
						if randf() < 0.1:
							main.toolwork.gain_legend("ghost_essence")
					"treant":
						main.doing.gain_item("gem", 3)
						main.toolwork.gain_legend("world_branch")
						main.hud.show_message("숲의 수호자를 쓰러뜨렸다! 세계수 가지를 얻었다!")
				if monsters.is_empty():
					_floor_clear()
			return
	# 광석 채굴 (첫 타에서만 — 연격 둘째 타가 광석까지 캐면 두 배가 된다)
	if not first:
		return
	var rt := Vector2i(int((reach.x - OX) / TS), int((reach.y - OY) / TS))
	if ores.has(rt):
		ores.erase(rt)
		Sound.play_sfx("sfx_pick", 0.1)
		# 컬렉션 「동굴의 광물」 완성 — 광석이 늘 하나 더 나온다
		var n := (2 if randf() < GameData.bonus_drop_chance("mine") else 1) \
			+ GameData.perk_cave_ore_bonus()
		main.doing.gain_item("ore", n)
		main.hud.show_message("광석 %d개 획득!" % n if n > 1 else "광석 획득!")
		main.toolwork.gain_skill("mine", 8.0)
		# 수맥을 막고 무너져 쌓인 바위 (메인 스토리 15)
		main.story.story15_dig_progress("ore", floor_num)
		# 동굴 조사(스토리 10) — 깊은 층 광맥에는 수정이 섞여 있다
		if GameData.story10_open() and floor_num >= 5 and randf() < 0.12:
			main.doing.gain_item("crystal", 1)
			main.hud.show_message("광맥 틈에서 수정을 캤다!")
		if floor_num >= 50:
			# 깊은 층 광석 속의 「할머니의 모자」 — 스토리 11 「깊은 굴」
			# 단계에서는 확정으로 나온다 (단서를 다 모은 뒤의 발견 연출)
			GameData.try_relic(0,
				0.0 if GameData.story11_phase == "deep" else -1.0)


func _floor_clear() -> void:
	var p := _free_tile(0.0)
	chest_pos = p if p.x >= 0 else Vector2i(GW / 2, GH / 2)
	Sound.play_sfx("sfx_catch")
	if lastroom:
		main.hud.show_message("...조용해졌다.\n방 안쪽에 낮은 나무 보관함이 하나 남아 있다.", 6.0)
		return
	main.hud.show_message("%d층 클리어! 보상 상자가 나타났다!" % floor_num)


func _interact() -> void:
	var pt := Vector2i(int((ppos.x - OX) / TS), int((ppos.y - OY) / TS))
	# 입구 사다리: 나가기 (ESC로도 언제든 가능)
	if pt.distance_to(entry_pos) < 2.0:
		close()
		return
	# 발광 버섯 따기 (스토리 10 표본)
	for sp: Vector2i in shrooms:
		if pt.distance_to(sp) < 1.8:
			shrooms.erase(sp)
			Sound.play_sfx("sfx_pick", 0.1)
			var sn := 2 if randf() < 0.3 else 1
			main.doing.gain_item("glow_shroom", sn)
			main.hud.show_message("은은히 빛나는 발광 버섯을 땄다!"
				+ (" (x%d)" % sn if sn > 1 else ""))
			return
	# 보상 상자
	if chest_pos.x >= 0 and pt.distance_to(chest_pos) < 1.8:
		if lastroom:
			# 할아버지의 보관함 — 금도 보석도 아닌 것이 들어 있다
			chest_pos = Vector2i(-1, -1)
			main.story.final_chest()
			return
		var ore_n := 2 + floor_num
		var gem_n := maxi(0, floor_num - 2)
		if special == "vein":
			ore_n *= 2
		elif special == "treasure":
			gem_n += 2 + floor_num / 3
		main.doing.gain_item("ore", ore_n)
		if gem_n > 0:
			main.doing.gain_item("gem", gem_n)
		Sound.play_sfx("sfx_coin")
		var msg := "상자에서 광석 %d개" % ore_n
		if gem_n > 0:
			msg += ", 보석 %d개" % gem_n
		# 이끼방에서는 약초가 함께 나온다 (연금술 생명 재료)
		if special == "grove":
			var herb := 3 + floor_num / 2
			main.doing.gain_item("forage_herb", herb)
			GameData.forage_caught["forage_herb"] = \
				int(GameData.forage_caught.get("forage_herb", 0)) + herb
			msg += ", 약초 %d개" % herb
		# 동굴 조사(스토리 10) — 이끼방 상자엔 동굴 이끼가 붙어 있다
		if GameData.story10_open():
			if special == "grove":
				var moss := 2 + floor_num / 5
				main.doing.gain_item("cave_moss", moss)
				msg += ", 동굴 이끼 %d개" % moss
			elif randf() < 0.2:
				main.doing.gain_item("cave_moss", 1)
				msg += ", 동굴 이끼 1개"
		main.hud.show_message(msg + "를 얻었다!")
		# 깊은 층(5층+)의 상자: 전설 「별빛 광석」은 한 번만,
		# 대장간 재료인 「별빛 조각」은 층이 깊을수록 여러 개 나온다
		if floor_num >= 5:
			main.toolwork.gain_legend("star_ore")
			var shards: int = 1 + int((floor_num - 5) / 3.0)
			main.doing.gain_item("star_shard", shards)
			main.hud.show_message("별빛 조각 %d개! 대장간에서 쓸 수 있다." % shards, 4.0)
		chest_pos = Vector2i(-1, -1)
		return
	# 다음 층 계단
	if stairs_pos.x >= 0 and pt.distance_to(stairs_pos) < 1.8:
		floor_num += 1
		if not worldtree:
			GameData.mine_reach(floor_num)
		_gen_floor()
		Sound.play_sfx("sfx_place")
		var msg2 := "동굴 %d층 — %s" % [floor_num, floor_title()]
		if special != "":
			msg2 += "\n" + str(SPECIALS[special].hint)
			main.hud.event_toast(str(SPECIALS[special].name))
		if not worldtree and floor_num % 5 == 0:
			msg2 += "\n무언가 커다란 것이 버티고 있다..."
		if not worldtree and floor_num % GameData.MINE_ELEVATOR_STEP == 0:
			msg2 += "\n승강기 층! 다음부터 여기서 시작할 수 있다."
		main.hud.show_message(msg2, 4.5)


func _dir_vec() -> Vector2:
	match pdir:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
	return Vector2.RIGHT


func _update_sprite() -> void:
	# 4박자 걷기: 발걸음A -> 서기(통과) -> 발걸음B -> 서기(통과)
	var suffix := "idle"
	if moving:
		match int(anim_time * 8.0) % 4:
			0:
				suffix = "0"
			2:
				suffix = "1"
			_:
				suffix = "idle"
	var tex_name := ""
	player_sprite.flip_h = false
	match pdir:
		"down":
			tex_name = GameData.player_down_tex(moving, suffix, anim_time)
		"up":
			tex_name = GameData.player_up_tex(moving, suffix, anim_time)
		_:
			tex_name = GameData.player_side_tex(moving, suffix, anim_time)
			player_sprite.flip_h = pdir == "left"
	# 맞은 직후엔 눈을 질끈 감는다 (깜빡임 그림 재활용 — 뒷모습은 눈이 없다)
	if hurt_cd > 0.55 and pdir != "up":
		tex_name = "pc_%s_blink" % ("side" if (pdir == "left" or pdir == "right") else "down")
	# 휘두르는 중이면 그 도트가 걷기·서기·깜빡임을 다 덮는다.
	# **바깥 세상과 같은 그림**이라 동굴에서만 자세가 달라 보이지 않는다.
	var sw_key := ""
	var sw_phase := 0
	if swing_t > 0.0 and swing_len > 0.0:
		var key: String = "side" if (swing_dir == "left" or swing_dir == "right") \
			else swing_dir
		sw_phase = _swing_phase()
		var sw_name := "%s_%d" % [GameData.swing_tex_base(key), sw_phase]
		if main.tex.has(sw_name):
			sw_key = key
			tex_name = sw_name
			player_sprite.flip_h = swing_dir == "left"
	_place_tool(sw_key, sw_phase)
	player_sprite.texture = main.tex[tex_name]
	# 원본 128x192에 발바닥이 y=190. 0.5배로 그리니 발이 ppos에 오도록 맞춘다
	player_sprite.scale = Vector2(0.5, 0.5) * ZOOM
	player_sprite.position = _to_screen(ppos) + Vector2(-32, -95) * ZOOM
	if hurt_flash > 0.0:
		player_sprite.modulate = Color(2.6, 2.6, 2.6)   # 맞는 순간 하얀 번쩍
	elif hurt_cd > 0.55:
		player_sprite.modulate = Color(1, 0.5, 0.5)     # 아픈 붉은 기
	elif hurt_cd > 0.0:
		# 남은 무적시간 동안 점멸 — 언제부터 다시 맞는지 눈에 보인다
		player_sprite.modulate = Color(1, 1, 1, 0.4 if fmod(hurt_cd, 0.14) < 0.07 else 1.0)
	else:
		player_sprite.modulate = Color(1, 1, 1)
	# 손에 든 것도 같이 번쩍이고 같이 점멸한다 (도구만 멀쩡하면 따로 논다)
	tool_sprite.modulate = player_sprite.modulate


# 지금 위상 (0=감기 시작 / 1=다 감음 / 2=휘두름 / 3=내리침 / 4=되돌아옴).
# player.gd의 swing_phase와 같은 식이다 — 한쪽만 고치면 동굴에서 박자가 어긋난다.
func _swing_phase() -> int:
	if swing_len <= 0.0:
		return 0
	var p: float = 1.0 - swing_t / swing_len
	var hit: float = clampf(main.HIT_AT / maxf(0.01, main.SWING_TIME), 0.15, 0.8)
	if p < hit * 0.34:
		return 0
	if p < hit * 0.74:
		return 1
	if p < hit:
		return 2
	return 3 if p < hit + (1.0 - hit) * 0.55 else 4


# 휘두르기 진행도 -1(다 감음) ~ +1(다 내리침). player.gd의 _swing_curve와 같다.
func _swing_c() -> float:
	if swing_t <= 0.0 or swing_len <= 0.0:
		return 0.0
	var p: float = 1.0 - swing_t / swing_len
	var hit: float = clampf(main.HIT_AT / maxf(0.01, main.SWING_TIME), 0.15, 0.8)
	var wind: float = hit * 0.62
	if p < wind:
		return -sin(p / wind * PI * 0.5)
	if p < hit:
		var q: float = (p - wind) / maxf(0.01, hit - wind)
		return -1.0 + 2.0 * q * q
	if p < hit + PlayerArt.SWING_HOLD:
		return 1.0
	var r: float = (p - hit - PlayerArt.SWING_HOLD) \
		/ maxf(0.02, 1.0 - hit - PlayerArt.SWING_HOLD)
	return 1.0 - r * r * (3.0 - 2.0 * r)


# 손에 든 도구를 주먹 자리에 얹는다. key가 비면 감춘다.
# 자리 값(SWING_HAND_DOT)은 발밑이 원점인 **0.5배 그림 기준**이라
# 여기서는 ZOOM만 더 곱하면 바깥 세상과 같은 자리에 온다.
func _place_tool(key: String, phase: int) -> void:
	var icon := ""
	if key != "" and PlayerArt.SWING_HAND_DOT.has(key):
		icon = str(PlayerArt.TOOL_ICONS.get(GameData.tool, ""))
		if GameData.tool == "axe" and int(GameData.tool_level.get("axe", 1)) >= 2:
			icon = "icon_axe_stone"
	if icon == "" or not main.tex.has(icon):
		tool_sprite.visible = false
		return
	var tex: Texture2D = main.tex[icon]
	var grip: Vector2 = PlayerArt.TOOL_GRIP.get(icon, Vector2(16, 30))
	var pose: Dictionary = PlayerArt.SWING_POSE[key]
	var sign_x := -1.0 if swing_dir == "left" else 1.0
	var spin: float = sign_x * float(pose.spin)
	var c := _swing_c()
	tool_sprite.texture = tex
	tool_sprite.visible = true
	tool_sprite.scale = Vector2(1.15, 1.15) * ZOOM
	tool_sprite.flip_h = (spin < 0.0) != PlayerArt.TOOL_MIRROR.has(GameData.tool)
	var tw := float(tex.get_width())
	tool_sprite.offset = Vector2(
		-(tw - 1.0 - grip.x) if tool_sprite.flip_h else -grip.x, -grip.y)
	tool_sprite.rotation = (float(pose.mid) + c * float(pose.arc) * 0.5) * spin
	var hand: Vector2 = PlayerArt.SWING_HAND_DOT[key][clampi(phase, 0, 4)]
	tool_sprite.position = _to_screen(ppos) + Vector2(hand.x * sign_x, hand.y) * ZOOM
	# 감아올릴 때는 몸 뒤, 내리치기 시작하면 앞. 뒤를 보고 칠 때는 내내 뒤다.
	if key == "up" or c < 0.0:
		move_child(tool_sprite, player_sprite.get_index())
	else:
		move_child(tool_sprite, get_child_count() - 1)


# 주인공 둘레를 미니맵에 드러낸다 (한 화면에 안 들어오니 길잡이가 필요하다)
func _mark_seen() -> void:
	var pt := Vector2i(int(ppos.x / TS), int(ppos.y / TS))
	for dy in range(-5, 6):
		for dx in range(-7, 8):
			var t := pt + Vector2i(dx, dy)
			if t.x >= 0 and t.y >= 0 and t.x < GW and t.y < GH:
				seen[t] = true


# 화면은 주인공을 따라간다. 동굴이 화면보다 작은 쪽(좁은 층)은 가운데 맞춘다.
func _update_cam(delta: float) -> void:
	var half := VIEW / (2.0 * ZOOM)
	var target := ppos
	var w: float = GW * TS
	var h: float = GH * TS
	if w > half.x * 2.0:
		target.x = clampf(target.x, half.x, w - half.x)
	else:
		target.x = w / 2.0
	if h > half.y * 2.0:
		target.y = clampf(target.y, half.y, h - half.y)
	else:
		target.y = h / 2.0
	cam = cam.lerp(target, clampf(delta * 9.0, 0.0, 1.0))


func _to_screen(p: Vector2) -> Vector2:
	return (p - cam) * ZOOM + VIEW / 2.0 + shake_off


# 미니맵 (오른쪽 아래) — 가 본 곳만 보여 준다.
# 오른쪽 위는 바깥 HUD(시계·의뢰 두루마리)가 덮으므로 피한다.
func _draw_minimap() -> void:
	var cell := 3.0
	var w: float = GW * cell
	var h: float = GH * cell
	var ox: float = VIEW.x - w - 14.0
	var oy: float = VIEW.y - h - 14.0
	# 판 + 테두리 (아직 안 가 본 곳은 옅은 회색으로 남겨 둬서 「지도」로 읽히게)
	canvas.draw_rect(Rect2(ox - 4, oy - 4, w + 8, h + 8), Color(0.08, 0.07, 0.12, 0.92))
	canvas.draw_rect(Rect2(ox - 4, oy - 4, w + 8, h + 8), Color(0.45, 0.4, 0.55, 0.9),
		false, 1.0)
	canvas.draw_rect(Rect2(ox, oy, w, h), Color(0.13, 0.12, 0.17, 0.95))
	for t: Vector2i in seen:
		var c := Color(0.42, 0.38, 0.45) if walls.has(t) else Color(0.2, 0.26, 0.22)
		canvas.draw_rect(Rect2(ox + t.x * cell, oy + t.y * cell, cell, cell), c)
	for t2: Vector2i in ores:
		if seen.has(t2):
			canvas.draw_rect(Rect2(ox + t2.x * cell, oy + t2.y * cell, cell, cell),
				Color(0.85, 0.72, 0.35))
	for t3: Vector2i in shrooms:
		if seen.has(t3):
			canvas.draw_rect(Rect2(ox + t3.x * cell, oy + t3.y * cell, cell, cell),
				Color(0.4, 0.95, 0.85))
	if stairs_pos.x >= 0 and seen.has(stairs_pos):
		canvas.draw_rect(Rect2(ox + stairs_pos.x * cell - 1, oy + stairs_pos.y * cell - 1,
			cell + 2, cell + 2), Color(0.5, 0.9, 1.0))
	if chest_pos.x >= 0 and seen.has(chest_pos):
		canvas.draw_rect(Rect2(ox + chest_pos.x * cell - 1, oy + chest_pos.y * cell - 1,
			cell + 2, cell + 2), Color(1.0, 0.85, 0.35))
	canvas.draw_rect(Rect2(ox + entry_pos.x * cell - 1, oy + entry_pos.y * cell - 1,
		cell + 2, cell + 2), Color(0.6, 0.8, 0.6))
	var pt := Vector2(ox + ppos.x / TS * cell, oy + ppos.y / TS * cell)
	canvas.draw_rect(Rect2(pt.x - 2, pt.y - 2, 5, 5), Color(1, 1, 1))
	canvas.draw_rect(Rect2(pt.x - 1, pt.y - 1, 3, 3), Color(0.95, 0.3, 0.25))


func _draw_cave() -> void:
	# 여기서부터 그리는 것은 모두 카메라 기준 + ZOOM 배 (+ 피격 흔들림)
	canvas.draw_set_transform(VIEW / 2.0 - cam * ZOOM + shake_off, 0.0, Vector2(ZOOM, ZOOM))
	# 바닥
	canvas.draw_rect(Rect2(OX, OY, GW * TS, GH * TS),
		Color(0.16, 0.24, 0.18) if worldtree else Color(0.22, 0.19, 0.24))
	for y in GH:
		for x in GW:
			if (x + y * 3) % 7 == 0:
				canvas.draw_rect(Rect2(OX + x * TS + 6, OY + y * TS + 8, 2, 2),
					Color(0.17, 0.15, 0.19))
	# 벽/광석/상자/계단/입구
	for pos: Vector2i in walls:
		canvas.draw_texture_rect(main.tex["rock"],
			Rect2(Vector2(OX + pos.x * TS, OY + pos.y * TS), Vector2(TS, TS)), false)
	for pos: Vector2i in ores:
		canvas.draw_texture_rect(main.tex["ore_node"],
			Rect2(Vector2(OX + pos.x * TS, OY + pos.y * TS), Vector2(TS, TS)), false)
	for pos: Vector2i in shrooms:
		# 발광 버섯 — 둘레에 은은한 빛무리를 깔아 어둠 속에서도 눈에 띈다
		canvas.draw_circle(Vector2(OX + (pos.x + 0.5) * TS, OY + (pos.y + 0.5) * TS),
			TS * 0.8, Color(0.4, 0.95, 0.85, 0.13))
		canvas.draw_texture_rect(main.tex["glow_shroom"],
			Rect2(Vector2(OX + pos.x * TS, OY + pos.y * TS), Vector2(TS, TS)), false)
	if chest_pos.x >= 0:
		canvas.draw_texture_rect(main.tex["chest"],
			Rect2(Vector2(OX + chest_pos.x * TS, OY + chest_pos.y * TS), Vector2(TS, TS)), false)
	if stairs_pos.x >= 0:
		canvas.draw_texture_rect(main.tex["stairs"],
			Rect2(Vector2(OX + stairs_pos.x * TS, OY + stairs_pos.y * TS), Vector2(TS, TS)), false)
	canvas.draw_texture_rect(main.tex["stairs"],
		Rect2(Vector2(OX + entry_pos.x * TS, OY + entry_pos.y * TS), Vector2(TS, TS)), false)
	_cave_label(Vector2(OX + (entry_pos.x + 0.5) * TS, OY + entry_pos.y * TS - 4), "E: 나가기")

	# 몬스터
	for m in monsters:
		var frame := int(m.anim * (7.0 if m.type == "bat" else 4.0)) % 2
		var mod := Color(1, 1, 1, 0.7) if m.type == "ghost" else Color(1, 1, 1)
		var moff := Vector2(-24, -32) if m.type == "treant" else Vector2(-16, -20)
		canvas.draw_texture(main.tex["%s_%d" % [m.type, frame]], m.pos + moff, mod)

	# 공격 스윙 — 어디까지 닿는지 한 번 스친다 (그림보다 짧다)
	if swing_fx > 0.0:
		var reach := ppos + _dir_vec() * 28.0
		canvas.draw_rect(Rect2(reach.x - 12, reach.y - 12, 24, 24), Color(1, 0.9, 0.5, 0.5))

	# 피해 숫자 — 맞은 자리에서 떠올라 옅어지며 사라진다
	for pp in dmg_pops:
		var a: float = clampf(float(pp.t) / 0.35, 0.0, 1.0)
		var pos: Vector2 = pp.pos + Vector2(-14.0, 0.0)
		canvas.draw_string_outline(main.UI_FONT, pos, str(pp.txt),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 3, Color(0.1, 0.03, 0.03, a))
		canvas.draw_string(main.UI_FONT, pos, str(pp.txt),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.36, 0.3, a))

	# ---- 여기부터는 화면 고정 (카메라를 따라가지 않는다) ----
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_minimap()

	# 상단 정보
	var cave_name := "할아버지의 마지막 방" if lastroom \
		else ("세계수 동굴" if worldtree else "동굴")
	var info := "%s %d층 · 몬스터 %d마리 · 체력 %d" % [cave_name, floor_num, monsters.size(), int(GameData.energy)]
	if chest_pos.x >= 0:
		info += " · 상자를 열자(E)!"
	elif stairs_pos.x >= 0:
		info += " · 계단을 찾아 내려가자(E)"
	_cave_label(Vector2(480, 30), info)
	_cave_label(Vector2(480, 54), "%s · %d x %d칸" % [floor_title(), GW, GH])


func _cave_label(center: Vector2, text: String) -> void:
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var p := Vector2(center.x - w / 2.0, center.y)
	canvas.draw_string_outline(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3,
		Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color(0.95, 0.92, 0.85))
