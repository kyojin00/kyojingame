# 동굴 탐험: 층별 생성 던전. 슬라임을 모두 잡으면 보상 상자 + 다음 층.
extends CanvasLayer

const GW := 26          # 동굴 그리드 (타일)
const GH := 13
const TS := 16.0        # 타일 픽셀
const OX := 32.0        # 화면 오프셋
const OY := 48.0

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
	add_child(player_sprite)


func open() -> void:
	if GameData.energy < 15.0:
		main.hud.show_message("너무 지쳤다... 동굴은 위험하다.")
		return
	floor_num = 1
	_gen_floor()
	visible = true
	Sound.play_sfx("sfx_place")
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
	# 몬스터 (층이 깊어질수록 종류/수 증가)
	for i in 2 + floor_num:
		_spawn_mob("slime", 1 + int(floor_num / 3.0))
	if floor_num >= 2:
		for i in 1 + int(floor_num / 2.0):
			_spawn_mob("bat", 1)
	if floor_num >= 4:
		for i in int((floor_num - 2) / 2.0):
			_spawn_mob("ghost", 2 + int(floor_num / 4.0))
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
	for off in [Vector2(-5, -3), Vector2(5, -3), Vector2(-5, 4), Vector2(5, 4)]:
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

	# 이동
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving:
		if absf(v.x) > absf(v.y):
			pdir = "right" if v.x > 0 else "left"
		else:
			pdir = "down" if v.y > 0 else "up"
		var np := ppos + v * 85.0 * delta
		if not _blocked_at(Vector2(np.x, ppos.y)):
			ppos.x = np.x
		if not _blocked_at(Vector2(ppos.x, np.y)):
			ppos.y = np.y
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
					if to_player.length() < 70.0:
						m.vel = to_player.normalized() * (26.0 + floor_num * 4.0)
					else:
						m.vel = Vector2.RIGHT.rotated(randf() * TAU) * 20.0
			"bat":
				if m.think <= 0.0:
					# 주기적으로 플레이어를 향해 돌진
					m.think = randf_range(1.2, 2.0)
					if to_player.length() < 120.0:
						m.vel = to_player.normalized() * (70.0 + floor_num * 8.0)
					else:
						m.vel = Vector2.RIGHT.rotated(randf() * TAU) * 34.0
				m.vel = m.vel.move_toward(Vector2.ZERO, 30.0 * delta)  # 돌진 후 감속
			"ghost":
				# 벽을 통과하며 끈질기게 추적
				m.vel = to_player.normalized() * (22.0 + floor_num * 3.0)
		var np: Vector2 = m.pos + m.vel * delta
		if m.type == "ghost":
			m.pos.x = clampf(np.x, OX + TS, OX + (GW - 1) * TS)
			m.pos.y = clampf(np.y, OY + TS, OY + (GH - 1) * TS)
		elif _blocked_at(np):
			m.vel = -m.vel
		else:
			m.pos = np
		# 접촉 피해 (종류별)
		if hurt_cd <= 0.0 and (m.pos - ppos).length() < 12.0:
			hurt_cd = 0.9
			var dmg: float = {"slime": 8.0, "bat": 6.0, "ghost": 12.0}[m.type]
			GameData.energy -= dmg
			Sound.play_sfx("sfx_miss")
			ppos += (ppos - m.pos).normalized() * 10.0
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


func _attack() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = 0.35
	swing_t = 0.15
	Sound.play_sfx("sfx_chop", 0.2)
	var reach := ppos + _dir_vec() * 14.0
	var dmg := 1 + (int(GameData.tool_level.get("axe", 1)) - 1)  # 도끼 강화 = 공격력 2배
	# 몬스터 타격
	for m in monsters:
		if (m.pos - reach).length() < 14.0 or (m.pos - ppos).length() < 12.0:
			m.hp -= dmg
			if m.type != "ghost":
				m.vel = (m.pos - ppos).normalized() * 60.0
			if m.hp <= 0:
				monsters.erase(m)
				Sound.play_sfx("sfx_pick", 0.2)
				main.record_kill(m.type)
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
				if monsters.is_empty():
					_floor_clear()
			return
	# 광석 채굴
	var rt := Vector2i(int((reach.x - OX) / TS), int((reach.y - OY) / TS))
	if ores.has(rt):
		ores.erase(rt)
		Sound.play_sfx("sfx_pick", 0.1)
		main.gain_item("ore", 1)
		main.hud.show_message("광석 획득!")


func _floor_clear() -> void:
	var p := _free_tile(0.0)
	chest_pos = p if p.x >= 0 else Vector2i(GW / 2, GH / 2)
	Sound.play_sfx("sfx_catch")
	main.hud.show_message("%d층 클리어! 보상 상자가 나타났다!" % floor_num)


func _interact() -> void:
	var pt := Vector2i(int((ppos.x - OX) / TS), int((ppos.y - OY) / TS))
	# 입구 사다리: 나가기
	if pt.distance_to(entry_pos) < 1.5:
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
	var frame := (int(anim_time * 6.0) % 2) if moving else 0
	var tex_name := ""
	player_sprite.flip_h = false
	match pdir:
		"down":
			tex_name = "player_down_%d" % frame
		"up":
			tex_name = "player_up_%d" % frame
		_:
			tex_name = "player_side_%d" % frame
			player_sprite.flip_h = pdir == "left"
	player_sprite.texture = main.tex[tex_name]
	player_sprite.position = ppos + Vector2(-8, -21)
	player_sprite.modulate = Color(1, 0.55, 0.55) if hurt_cd > 0.6 else Color(1, 1, 1)


func _draw_cave() -> void:
	# 바닥
	canvas.draw_rect(Rect2(OX, OY, GW * TS, GH * TS), Color(0.22, 0.19, 0.24))
	for y in GH:
		for x in GW:
			if (x + y * 3) % 7 == 0:
				canvas.draw_rect(Rect2(OX + x * TS + 6, OY + y * TS + 8, 2, 2),
					Color(0.17, 0.15, 0.19))
	# 벽/광석/상자/계단/입구
	for pos: Vector2i in walls:
		canvas.draw_texture(main.tex["rock"], Vector2(OX + pos.x * TS, OY + pos.y * TS))
	for pos: Vector2i in ores:
		canvas.draw_texture(main.tex["ore_node"], Vector2(OX + pos.x * TS, OY + pos.y * TS))
	if chest_pos.x >= 0:
		canvas.draw_texture(main.tex["chest"], Vector2(OX + chest_pos.x * TS, OY + chest_pos.y * TS))
	if stairs_pos.x >= 0:
		canvas.draw_texture(main.tex["stairs"], Vector2(OX + stairs_pos.x * TS, OY + stairs_pos.y * TS))
	canvas.draw_texture(main.tex["stairs"], Vector2(OX + entry_pos.x * TS, OY + entry_pos.y * TS))
	_cave_label(Vector2(OX + (entry_pos.x + 0.5) * TS, OY + entry_pos.y * TS - 4), "E: 나가기")

	# 몬스터
	for m in monsters:
		var frame := int(m.anim * (7.0 if m.type == "bat" else 4.0)) % 2
		var mod := Color(1, 1, 1, 0.7) if m.type == "ghost" else Color(1, 1, 1)
		canvas.draw_texture(main.tex["%s_%d" % [m.type, frame]], m.pos + Vector2(-8, -10), mod)

	# 공격 스윙
	if swing_t > 0.0:
		var reach := ppos + _dir_vec() * 14.0
		canvas.draw_rect(Rect2(reach.x - 6, reach.y - 6, 12, 12), Color(1, 0.9, 0.5, 0.5))

	# 상단 정보
	var info := "동굴 %d층 · 슬라임 %d마리 · 기력 %d" % [floor_num, monsters.size(), int(GameData.energy)]
	if chest_pos.x >= 0:
		info += " · 상자를 열자(E)!"
	elif stairs_pos.x >= 0:
		info += " · 계단(E)으로 다음 층!"
	_cave_label(Vector2(240, 32), info)


func _cave_label(center: Vector2, text: String) -> void:
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var p := Vector2(center.x - w / 2.0, center.y)
	canvas.draw_string_outline(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4,
		Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.95, 0.92, 0.85))
