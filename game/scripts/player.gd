# 플레이어: 수동 타일 충돌 이동 + 방향별 걷기 애니메이션
extends Node2D

const SPEED := 75.0  # 아트 픽셀/초
const R := 3.0       # 발 밑 충돌 반경

var main: Node2D
var dir := "down"
var moving := false
var anim_time := 0.0
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-6, -15)  # 발 밑 기준
	add_child(sprite)
	_update_sprite()


func _process(delta: float) -> void:
	if main == null or main.ui_open():
		moving = false
		_update_sprite()
		return

	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0

	moving = v != Vector2.ZERO
	if moving:
		if absf(v.x) > absf(v.y):
			dir = "right" if v.x > 0 else "left"
		elif v.y != 0:
			dir = "down" if v.y > 0 else "up"
		v = v.normalized() * SPEED * delta
		if not _blocked(position + Vector2(v.x, 0)):
			position.x += v.x
		if not _blocked(position + Vector2(0, v.y)):
			position.y += v.y
		anim_time += delta
	_update_sprite()


func _blocked(p: Vector2) -> bool:
	for off in [Vector2(-R, -R), Vector2(R, -R), Vector2(-R, R), Vector2(R, R)]:
		if not main.is_passable_px(p + off):
			return true
	return false


func _update_sprite() -> void:
	var frame := (int(anim_time * 6.0) % 2) if moving else 0
	var tex_name := ""
	sprite.flip_h = false
	match dir:
		"down":
			tex_name = "player_down_%d" % frame
		"up":
			tex_name = "player_up_%d" % frame
		_:
			tex_name = "player_side_%d" % frame
			sprite.flip_h = dir == "left"
	sprite.texture = main.tex[tex_name]
