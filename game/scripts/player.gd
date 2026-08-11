# 플레이어: 수동 타일 충돌 이동 + 방향별 걷기 애니메이션
extends Node2D

const SPEED := 150.0  # 아트 픽셀/초
const R := 6.0       # 발 밑 충돌 반경

var main: Node2D
var dir := "down"
var moving := false
var anim_time := 0.0
var step_timer := 0.0
var step_alt := false
var walked := 0.0  # 이동 체크용 누적 거리
var bumped := false  # 이동하려 했지만 완전히 막혔는가 (스토리 연출용)

@onready var sprite: Sprite2D = $Sprite

# 탈 것: 캐릭터 밑에 깔리는 말 그림 (탔을 때만 보인다)
var horse_sprite: Sprite2D

# ---- 도구 휘두르기 ----
#
# 캐릭터 도트에는 「휘두르는」 프레임이 없다 (서기 + 걷기 4프레임뿐).
# 그래서 몸을 발끝을 축으로 젖혔다 내리치고, 손에 도구 아이콘을 띄워
# 호를 그리게 해서 동작을 만든다. 나중에 휘두르기 도트가 생기면
# _swing_visual만 갈아끼우면 된다.
const SWING_LEAN := 0.22        # 몸이 젖혀지는 최대 각(라디안)
const SWING_ARC := 1.9          # 도구가 그리는 호(라디안)
const TOOL_ICONS := {
	"axe": "icon_axe", "pickaxe": "icon_pickaxe",
	"hoe": "icon_hoe", "water": "icon_water",
}

var swing_t := 0.0              # 남은 시간
var swing_len := 0.0
var swing_face := Vector2.DOWN  # 내리치는 방향
var tool_sprite: Sprite2D


func _ready() -> void:
	horse_sprite = Sprite2D.new()
	horse_sprite.centered = false
	horse_sprite.scale = Vector2(0.8, 0.8)    # 사람보다 조금 크게
	horse_sprite.offset = Vector2(-48, -70)   # 96x80을 발밑에 맞춘다
	horse_sprite.visible = false
	add_child(horse_sprite)
	# 캐릭터보다 먼저 그린다 (자식 순서로 앞뒤를 정한다).
	# z_index를 -1로 두면 지형(z=0)보다 먼저 그려져 땅 밑에 깔린다.
	move_child(horse_sprite, 0)

	# 손에 들리는 도구 (휘두를 때만 보인다). 손잡이 끝을 축으로 돈다.
	tool_sprite = Sprite2D.new()
	tool_sprite.centered = false
	tool_sprite.offset = Vector2(-16, -30)
	tool_sprite.scale = Vector2(1.15, 1.15)   # 한눈에 보이게 조금 크게
	tool_sprite.visible = false
	add_child(tool_sprite)
	_update_sprite()


# 휘두르기 시작. face = 내리치는 방향, length = 동작 길이(초)
func start_swing(tool_id: String, face: Vector2, length: float) -> void:
	if not TOOL_ICONS.has(tool_id):
		return
	var icon: String = TOOL_ICONS[tool_id]
	if tool_id == "axe" and int(GameData.tool_level.get("axe", 1)) >= 2:
		icon = "icon_axe_stone"
	if not main.tex.has(icon):
		return
	tool_sprite.texture = main.tex[icon]
	swing_face = face if face != Vector2.ZERO else Vector2.DOWN
	swing_len = maxf(0.14, length)
	swing_t = swing_len


# 0(시작) ~ 1(끝)을 -1(뒤로 젖힘) ~ +1(앞으로 내리침)로 바꾼다.
# 감아올리기는 느리게, 내리치기는 빠르게 — 그래야 「친다」로 보인다.
func _swing_curve(p: float) -> float:
	if p < 0.32:
		return -p / 0.32
	if p < 0.5:
		return -1.0 + (p - 0.32) / 0.18 * 2.0
	return 1.0 - (p - 0.5) / 0.5


func _swing_visual() -> void:
	if swing_t <= 0.0:
		tool_sprite.visible = false
		sprite.rotation = 0.0
		return
	var p: float = 1.0 - swing_t / swing_len
	var c := _swing_curve(p)
	var sign_x := -1.0 if swing_face.x < -0.3 else 1.0
	# 몸: 발끝을 축으로 젖혔다 내리친다 (스프라이트 원점이 발이다)
	sprite.rotation = c * SWING_LEAN * sign_x
	# 도구: 손 높이에서 호를 그린다
	tool_sprite.visible = true
	tool_sprite.flip_h = sign_x < 0.0
	tool_sprite.rotation = (-1.1 + c * SWING_ARC) * sign_x
	tool_sprite.position = Vector2(sign_x * 9.0 + swing_face.x * 6.0,
		-30.0 + swing_face.y * 5.0 + c * 4.0)
	# 위를 향해 칠 때는 캐릭터 뒤로 (아래/옆이면 앞으로)
	move_child(tool_sprite, 0 if swing_face.y < -0.3 else get_child_count() - 1)


func _draw() -> void:
	# 발밑 그림자
	draw_rect(Rect2(-10, -3, 20, 6), Color(0, 0, 0, 0.22))


func _process(delta: float) -> void:
	if main == null or main.ui_open():
		moving = false
		swing_t = maxf(0.0, swing_t - delta)
		_update_sprite()
		return

	swing_t = maxf(0.0, swing_t - delta)
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving and main.fishing_state != "":
		main.fishing.cancel_fishing()  # 움직이면 낚시 중단
	if moving:
		if v.x != 0.0:
			# 대각선 포함: 좌우 성분이 있으면 옆모습 걷기
			dir = "right" if v.x > 0 else "left"
		elif v.y != 0:
			dir = "down" if v.y > 0 else "up"
		# 강아지 펫 + 장신구 + 탈 것이 이동 속도를 올린다
		var mult := GameData.pet_speed_mult() * GameData.gear_speed_mult()
		if GameData.riding:
			mult *= GameData.HORSE_SPEED_MULT
		v = v * SPEED * mult * delta
		var before := position
		# 이미 끼어 있으면(설치물 등) 충돌을 무시하고 빠져나올 수 있게 한다
		var stuck := _blocked(position)
		if not _blocked(position + Vector2(v.x, 0)) \
				or (stuck and _loose_ok(position + Vector2(v.x, 0))):
			position.x += v.x
		if not _blocked(position + Vector2(0, v.y)) \
				or (stuck and _loose_ok(position + Vector2(0, v.y))):
			position.y += v.y
		bumped = (position - before).length() < 0.01
		anim_time += delta
		walked += SPEED * delta
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.33
			step_alt = not step_alt
			Sound.play_sfx("sfx_step1" if step_alt else "sfx_step0", 0.2)
	else:
		step_timer = 0.15
		bumped = false
	_update_sprite()


# 끼임 탈출용 검사: 물/맵 밖/미구매 부지로는 절대 빠져나갈 수 없다
func _loose_ok(p: Vector2) -> bool:
	for off in [Vector2(-R, -R), Vector2(R, -R), Vector2(-R, R), Vector2(R, R)]:
		if not main.is_passable_px_loose(p + off):
			return false
	return true


func _blocked(p: Vector2) -> bool:
	for off in [Vector2(-R, -R), Vector2(R, -R), Vector2(-R, R), Vector2(R, R)]:
		if not main.is_passable_px(p + off):
			return true
	return false


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
	sprite.flip_h = false
	match dir:
		"down":
			tex_name = GameData.player_down_tex(moving, suffix, anim_time)
		"up":
			tex_name = GameData.player_up_tex(moving, suffix, anim_time)
		_:
			tex_name = GameData.player_side_tex(moving, suffix, anim_time)
			sprite.flip_h = dir == "left"
	sprite.texture = main.tex[tex_name]
	# 서 있을 때 숨쉬기: 프레임 대신 세로 스케일을 살짝 키웠다 줄인다
	# (스프라이트 offset이 발 기준이라 발은 그대로, 머리만 오르내린다)
	if not moving:
		var b := 1.0 + 0.018 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		sprite.scale = Vector2(0.5, 0.5 * b)
	else:
		sprite.scale = Vector2(0.5, 0.5)

	# 탈 것: 말을 발밑에 깔고 캐릭터를 안장 높이로 올린다
	horse_sprite.visible = GameData.riding
	if GameData.riding:
		var hf := 1 if (moving and int(anim_time * 9.0) % 2 == 1) else 0
		var hname := "horse_down_%d" % hf
		horse_sprite.flip_h = false
		match dir:
			"up":
				hname = "horse_up_%d" % hf
			"left", "right":
				hname = "horse_side_%d" % hf
				horse_sprite.flip_h = dir == "left"
		horse_sprite.texture = main.tex[hname]
		sprite.position.y = -34.0     # 안장 위
	else:
		sprite.position.y = 0.0
	_swing_visual()
