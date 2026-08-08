# 동굴 탐험: 층별 생성 던전. 슬라임을 모두 잡으면 보상 상자 + 다음 층.
extends CanvasLayer

const GW := 26          # 동굴 그리드 (타일)
const GH := 13
const TS := 32.0        # 타일 픽셀
const OX := 64.0         # 화면 오프셋
const OY := 62.0

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


func open(wt: bool = false) -> void:
	if GameData.energy < 15.0:
		main.hud.show_message("체력이 너무 낮다... 회복하고 오자. (요리를 먹거나 잠시 기다리기)")
		return
	worldtree = wt
	floor_num = 1
	_gen_floor()
	visible = true
	Sound.play_sfx("sfx_place")
	if worldtree:
		main.hud.show_message("세계수 동굴... 공기가 다르다. 3층에 수호자가 있다!")
	else:
		main.hud.show_message("동굴 %d층. Space: 공격 · 슬라임을 모두 잡자!" % floor_num)


func close() -> void:
	visible = false
	Sound.play_sfx("sfx_place")


func _gen_floor() -> void:
	walls.clear()
	ores.clear()
	monsters.clear()
	chest_pos = Vector2i(-1, -1)
	stairs_pos = Vector2i(-1, -1)
	# 테두리 벽 + 랜덤 기둥
	for y in GH:
		for x in GW:
			if x == 0 or y == 0 or x == GW - 1 or y == GH - 1:
				walls[Vector2i(x, y)] = true
			elif randf() < 0.08 and Vector2i(x, y).distance_to(entry_pos) > 3.0:
				walls[Vector2i(x, y)] = true
	# 광석
	for i in 2 + floor_num / 2:
		var p := _free_tile(3.0)
		if p.x >= 0:
			ores[p] = true
	# 몬스터 (층이 깊어질수록 종류/수 증가, 세계수 동굴은 2배 강함)
	var hp_mult := 2 if worldtree else 1
	if worldtree and floor_num == 3:
		# 보스층: 숲의 수호자 + 호위
		_spawn_mob("treant", 40)
		_spawn_mob("ghost", 4)
		_spawn_mob("ghost", 4)
	else:
		for i in 2 + floor_num:
			_spawn_mob("slime", (1 + int(floor_num / 3.0)) * hp_mult)
		if floor_num >= 2 or worldtree:
			for i in 1 + int(floor_num / 2.0):
				_spawn_mob("bat", 1 * hp_mult)
		if floor_num >= 4 or (worldtree and floor_num >= 2):
			for i in maxi(1, int((floor_num - 2) / 2.0)):
				_spawn_mob("ghost", (2 + int(floor_num / 4.0)) * hp_mult)
	ppos = Vector2(OX + (entry_pos.x + 0.5) * TS, OY + (entry_pos.y + 0.5) * TS)
	pdir = "right"


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


func _free_tile(min_dist: float) -> Vector2i:
	for attempt in 40:
		var p := Vector2i(randi_range(1, GW - 2), randi_range(1, GH - 2))
		if not walls.has(p) and not ores.has(p) and p != entry_pos \
				and float(p.distance_to(entry_pos)) >= min_dist:
			return p
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

	# 이동 (이미 끼어 있으면 충돌 무시하고 빠져나올 수 있게)
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving:
		if absf(v.x) > absf(v.y):
			pdir = "right" if v.x > 0 else "left"
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
			GameData.energy -= dmg * GameData.pet_cave_def_mult()  # 부엉이 펫: 피해 감소
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
	# 도끼 강화 = 공격력 2배, 전투 숙련도 = +0.5/Lv
	var dmg: float = 1 + (int(GameData.tool_level.get("axe", 1)) - 1) + GameData.combat_bonus()
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
		main.gain_item("ore", ore_n)
		if gem_n > 0:
			main.gain_item("gem", gem_n)
		Sound.play_sfx("sfx_coin")
		var msg := "상자에서 광석 %d개" % ore_n
		if gem_n > 0:
			msg += ", 보석 %d개" % gem_n
		main.hud.show_message(msg + "를 얻었다!")
		# 깊은 층(5층+)의 상자에서는 별빛 광석이 나온다
		if floor_num >= 5:
			main.gain_legend("star_ore")
		chest_pos = Vector2i(-1, -1)
		var sp := _free_tile(0.0)
		stairs_pos = sp if sp.x >= 0 else Vector2i(GW / 2, GH / 2)
		return
	# 다음 층 계단
	if stairs_pos.x >= 0 and pt.distance_to(stairs_pos) < 1.8:
		floor_num += 1
		_gen_floor()
		Sound.play_sfx("sfx_place")
		main.hud.show_message("동굴 %d층으로 내려간다... 더 위험해졌다!" % floor_num)


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
			tex_name = GameData.player_tex("down_" + suffix) if suffix != "idle" \
				else GameData.player_idle_tex("down")
		"up":
			tex_name = GameData.player_tex("up_" + suffix) if suffix != "idle" \
				else GameData.player_idle_tex("up")
		_:
			tex_name = GameData.player_side_tex(suffix, anim_time)
			player_sprite.flip_h = pdir == "left"
	player_sprite.texture = main.tex[tex_name]
	player_sprite.position = ppos + Vector2(-16, -42)
	player_sprite.modulate = Color(1, 0.55, 0.55) if hurt_cd > 0.6 else Color(1, 1, 1)


func _draw_cave() -> void:
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

	# 상단 정보
	var cave_name := "세계수 동굴" if worldtree else "동굴"
	var info := "%s %d층 · 몬스터 %d마리 · 체력 %d" % [cave_name, floor_num, monsters.size(), int(GameData.energy)]
	if chest_pos.x >= 0:
		info += " · 상자를 열자(E)!"
	elif stairs_pos.x >= 0:
		info += " · 계단(E)으로 다음 층!"
	_cave_label(Vector2(480, 52), info)


func _cave_label(center: Vector2, text: String) -> void:
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var p := Vector2(center.x - w / 2.0, center.y)
	canvas.draw_string_outline(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3,
		Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color(0.95, 0.92, 0.85))
