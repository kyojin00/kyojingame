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
	_update_sprite()


func _draw() -> void:
	# 발밑 그림자
	draw_rect(Rect2(-10, -3, 20, 6), Color(0, 0, 0, 0.22))


func _process(delta: float) -> void:
	if main == null or main.ui_open():
		moving = false
		_update_sprite()
		return

	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving and main.fishing_state != "":
		main.cancel_fishing()  # 움직이면 낚시 중단
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
