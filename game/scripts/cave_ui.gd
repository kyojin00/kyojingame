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
const ZOOM := 1.5        # 화면에 그릴 때의 배율 — 타일 한 칸이 48px로 보인다
const VIEW := Vector2(960.0, 540.0)

const CAVE_W_BASE := 42  # 1층 크기
const CAVE_H_BASE := 28
const CAVE_GROW := 2     # 한 층 내려갈 때마다 (가로/세로)
const CAVE_W_MAX := 76
const CAVE_H_MAX := 52

var GW := CAVE_W_BASE
var GH := CAVE_H_BASE
var cam := Vector2.ZERO
var seen := {}           # 미니맵에 드러난 칸

var main: Node2D
var canvas: Control
var player_sprite: Sprite2D

var floor_num := 1
var walls := {}         # Vector2i -> true
var ores := {}          # Vector2i -> true
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
var swing_t := 0.0


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


var worldtree := false  # 세계수 동굴 모드 (강화 몬스터 + 3층 보스)


func open(wt: bool = false, start_floor: int = 1) -> void:
	if GameData.energy < 15.0:
		main.hud.show_message("체력이 너무 낮다... 회복하고 오자. (요리를 먹거나 잠시 기다리기)")
		return
	worldtree = wt
	# 승강기로 내려간 층에서 시작한다 (세계수 동굴은 언제나 1층부터)
	floor_num = 1 if wt else maxi(1, start_floor)
	GameData.mine_reach(floor_num)
	_gen_floor()
	visible = true
	Sound.play_sfx("sfx_place")
	if worldtree:
		main.hud.show_message("세계수 동굴... 공기가 다르다. 3층에 수호자가 있다!")
	else:
		main.hud.show_message("동굴 %d층 — %s\nSpace: 공격 · 몬스터를 모두 잡자!"
			% [floor_num, floor_title()], 4.0)
		if special != "":
			main.hud.quest_toast(str(SPECIALS[special].name))


func close() -> void:
	visible = false
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
	monsters.clear()
	seen.clear()
	chest_pos = Vector2i(-1, -1)
	stairs_pos = Vector2i(-1, -1)
	# 층이 깊어질수록 넓어진다
	GW = mini(CAVE_W_MAX, CAVE_W_BASE + (floor_num - 1) * CAVE_GROW)
	GH = mini(CAVE_H_MAX, CAVE_H_BASE + (floor_num - 1) * CAVE_GROW)
	entry_pos = Vector2i(2, GH - 3)

	# 층마다 모양을 바꾼다 (세계수 동굴은 언제나 너른 굴)
	layout = "open" if worldtree else LAYOUTS[randi() % LAYOUTS.size()]
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

	# 보물방은 상자가 처음부터 놓여 있다
	if special == "treasure":
		var cp := _free_tile(4.0)
		if cp.x >= 0:
			chest_pos = cp

	# 몬스터 (층이 깊어질수록 종류/수 증가, 세계수 동굴은 2배 강함)
	var hp_mult := 2 if worldtree else 1
	if worldtree and floor_num == 3:
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
	stairs_pos = st if st.x >= 0 else Vector2i(GW - 3, 2)
	ppos = Vector2(OX + (entry_pos.x + 0.5) * TS, OY + (entry_pos.y + 0.5) * TS)
	pdir = "right"
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
		if reachable.has(p) and not ores.has(p) and p != chest_pos and p != entry_pos \
				and float(p.distance_to(entry_pos)) >= min_dist:
			return p
	# 멀리 떨어진 자리를 못 찾았으면 거리 조건을 풀고 아무 데나
	for p2: Vector2i in reachable:
		if not ores.has(p2) and p2 != entry_pos and p2 != chest_pos:
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
	if not visible or main.dialog.visible or main.summary.visible:
		return
	attack_cd -= delta
	hurt_cd -= delta
	swing_t -= delta
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
		var np := ppos + v * 170.0 * delta
		var stuck := _blocked_at(ppos)
		if stuck or not _blocked_at(Vector2(np.x, ppos.y)):
			ppos.x = clampf(np.x, OX + 8, OX + GW * TS - 8)
		if stuck or not _blocked_at(Vector2(ppos.x, np.y)):
			ppos.y = clampf(np.y, OY + 8, OY + GH * TS - 8)
		anim_time += delta

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
			var dmg: float = {"slime": 8.0, "bat": 6.0, "ghost": 12.0, "treant": 20.0}[m.type]
			# 부엉이 펫 + 방어구가 받는 피해를 줄인다
			GameData.energy -= dmg * GameData.pet_cave_def_mult() * GameData.gear_defense_mult()
			Sound.play_sfx("sfx_miss")
			# 넉백은 막히지 않은 곳으로만 (벽/바위 끼임 방지)
			var kb: Vector2 = ppos + (ppos - m.pos).normalized() * 20.0
			if not _blocked_at(kb):
				ppos = kb
			if GameData.energy <= 0.0:
				GameData.energy = 10.0
				close()
				main.hud.show_message("동굴에서 쫓겨났다... 기력이 바닥났다!")
				return

	_update_sprite()
	canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialog.visible or main.summary.visible:
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
	attack_cd = 0.35
	swing_t = 0.15
	Sound.play_sfx("sfx_chop", 0.2)
	var reach := ppos + _dir_vec() * 28.0
	# 공격력 = 도끼의 「위력」 + 전투 숙련도 + 장착한 무기
	var dmg: float = GameData.tool_stat("axe", "power") + GameData.combat_bonus() \
		+ GameData.gear_stat("power")
	# 몬스터 타격
	for m in monsters:
		if (m.pos - reach).length() < 28.0 or (m.pos - ppos).length() < 24.0:
			m.hp -= dmg
			if m.type != "ghost":
				m.vel = (m.pos - ppos).normalized() * 120.0
			if m.hp <= 0:
				monsters.erase(m)
				Sound.play_sfx("sfx_pick", 0.2)
				main.record_kill(m.type)
				main.gain_skill("combat", {"slime": 6.0, "bat": 8.0, "ghost": 12.0, "treant": 40.0}[m.type])
				match m.type:
					"slime":
						if randf() < 0.35:
							main.gain_item("ore", 1)
							main.hud.show_message("슬라임이 광석을 떨어뜨렸다!")
					"bat":
						if randf() < 0.2:
							main.gain_item("ore", 1)
							main.hud.show_message("박쥐가 광석을 떨어뜨렸다!")
					"ghost":
						main.gain_item("ore", 1)
						if randf() < 0.15:
							main.gain_item("gem", 1)
							main.hud.show_message("유령이 보석을 떨어뜨렸다!")
						if randf() < 0.1:
							main.gain_legend("ghost_essence")
					"treant":
						main.gain_item("gem", 3)
						main.gain_legend("world_branch")
						main.hud.show_message("숲의 수호자를 쓰러뜨렸다! 세계수 가지를 얻었다!")
				if monsters.is_empty():
					_floor_clear()
			return
	# 광석 채굴
	var rt := Vector2i(int((reach.x - OX) / TS), int((reach.y - OY) / TS))
	if ores.has(rt):
		ores.erase(rt)
		Sound.play_sfx("sfx_pick", 0.1)
		var n := 2 if randf() < GameData.bonus_drop_chance("mine") else 1
		main.gain_item("ore", n)
		main.hud.show_message("광석 %d개 획득!" % n if n > 1 else "광석 획득!")
		main.gain_skill("mine", 8.0)


func _floor_clear() -> void:
	var p := _free_tile(0.0)
	chest_pos = p if p.x >= 0 else Vector2i(GW / 2, GH / 2)
	Sound.play_sfx("sfx_catch")
	main.hud.show_message("%d층 클리어! 보상 상자가 나타났다!" % floor_num)


func _interact() -> void:
	var pt := Vector2i(int((ppos.x - OX) / TS), int((ppos.y - OY) / TS))
	# 입구 사다리: 나가기 (ESC로도 언제든 가능)
	if pt.distance_to(entry_pos) < 2.0:
		close()
		return
	# 보상 상자
	if chest_pos.x >= 0 and pt.distance_to(chest_pos) < 1.8:
		var ore_n := 2 + floor_num
		var gem_n := maxi(0, floor_num - 2)
		if special == "vein":
			ore_n *= 2
		elif special == "treasure":
			gem_n += 2 + floor_num / 3
		main.gain_item("ore", ore_n)
		if gem_n > 0:
			main.gain_item("gem", gem_n)
		Sound.play_sfx("sfx_coin")
		var msg := "상자에서 광석 %d개" % ore_n
		if gem_n > 0:
			msg += ", 보석 %d개" % gem_n
		# 이끼방에서는 약초가 함께 나온다 (연금술 생명 재료)
		if special == "grove":
			var herb := 3 + floor_num / 2
			main.gain_item("forage_herb", herb)
			GameData.forage_caught["forage_herb"] = \
				int(GameData.forage_caught.get("forage_herb", 0)) + herb
			msg += ", 약초 %d개" % herb
		main.hud.show_message(msg + "를 얻었다!")
		# 깊은 층(5층+)의 상자: 전설 「별빛 광석」은 한 번만,
		# 대장간 재료인 「별빛 조각」은 층이 깊을수록 여러 개 나온다
		if floor_num >= 5:
			main.gain_legend("star_ore")
			var shards: int = 1 + int((floor_num - 5) / 3.0)
			main.gain_item("star_shard", shards)
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
			main.hud.quest_toast(str(SPECIALS[special].name))
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
	player_sprite.texture = main.tex[tex_name]
	# 원본 128x192에 발바닥이 y=190. 0.5배로 그리니 발이 ppos에 오도록 맞춘다
	player_sprite.scale = Vector2(0.5, 0.5) * ZOOM
	player_sprite.position = _to_screen(ppos) + Vector2(-32, -95) * ZOOM
	player_sprite.modulate = Color(1, 0.55, 0.55) if hurt_cd > 0.6 else Color(1, 1, 1)


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
	return (p - cam) * ZOOM + VIEW / 2.0


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
	# 여기서부터 그리는 것은 모두 카메라 기준 + ZOOM 배
	canvas.draw_set_transform(VIEW / 2.0 - cam * ZOOM, 0.0, Vector2(ZOOM, ZOOM))
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

	# 공격 스윙
	if swing_t > 0.0:
		var reach := ppos + _dir_vec() * 28.0
		canvas.draw_rect(Rect2(reach.x - 12, reach.y - 12, 24, 24), Color(1, 0.9, 0.5, 0.5))

	# ---- 여기부터는 화면 고정 (카메라를 따라가지 않는다) ----
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_minimap()

	# 상단 정보
	var cave_name := "세계수 동굴" if worldtree else "동굴"
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
