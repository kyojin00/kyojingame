# 다른 플레이어의 아바타: 수신한 위치/방향으로 부드럽게 따라간다.
extends Node2D

var main: Node2D
var tint := Color(1, 1, 1)
var target_pos := Vector2.ZERO
var dir := "down"
var moving := false
var anim_time := 0.0
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-64, -188)
	sprite.scale = Vector2(0.5, 0.5)
	sprite.modulate = tint
	add_child(sprite)
	target_pos = position
	_update_sprite()


func _draw() -> void:
	draw_rect(Rect2(-4, -2, 8, 3), Color(0, 0, 0, 0.22))


func set_state(pos: Vector2, new_dir: String, new_moving: bool) -> void:
	target_pos = pos
	dir = new_dir
	moving = new_moving


func _process(delta: float) -> void:
	var d := target_pos - position
	if d.length() > 64.0:
		position = target_pos  # 순간이동 (스냅샷 직후 등)
	else:
		position = position.lerp(target_pos, minf(delta * 12.0, 1.0))
	if moving:
		anim_time += delta
	_update_sprite()


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
			tex_name = GameData.player_tex("down_" + suffix) if suffix != "idle" \
				else GameData.player_idle_tex("down")
		"up":
			tex_name = GameData.player_tex("up_" + suffix) if suffix != "idle" \
				else GameData.player_idle_tex("up")
		_:
			tex_name = GameData.player_side_tex(moving, suffix, anim_time)
			sprite.flip_h = dir == "left"
	sprite.texture = main.tex[tex_name]
