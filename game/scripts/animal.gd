# 동물: 농장을 자유롭게 돌아다니고, 쓰다듬어주면 다음 날 아침 생산물을 준다.
extends Node2D

var main: Node2D
var type := "chicken"
var fed := false
var sprite: Sprite2D
var anim_time := 0.0
var moving := false
var target: Vector2
var wait := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-16, -28)
	sprite.scale = Vector2(1.35, 1.35)  # 큰 캐릭터에 맞춘 비율
	add_child(sprite)
	target = position
	wait = randf_range(0.5, 2.0)
	_update_sprite()


func _draw() -> void:
	# 발밑 그림자 (쓰다듬어준 날은 하트 표시)
	KyojinMain.draw_ground_shadow(self, 6.0, 2.0)
	if fed:
		draw_rect(Rect2(-2, -18, 2, 2), Color(0.95, 0.35, 0.45))
		draw_rect(Rect2(1, -18, 2, 2), Color(0.95, 0.35, 0.45))
		draw_rect(Rect2(-1, -16, 3, 2), Color(0.95, 0.35, 0.45))
		draw_rect(Rect2(0, -14, 1, 1), Color(0.95, 0.35, 0.45))


func _process(delta: float) -> void:
	if main.ui_open():
		return
	anim_time += delta
	if moving:
		var d := target - position
		if d.length() < 1.5:
			moving = false
			wait = randf_range(1.0, 3.5)
		else:
			var speed := 44.0 if type == "chicken" else 30.0
			var step := d.normalized() * speed * delta
			if absf(step.x) > 0.01:
				sprite.flip_h = step.x > 0  # 기본 그림은 왼쪽 보기
			position += step
	else:
		wait -= delta
		if wait <= 0.0:
			_pick_target()
	_update_sprite()
	queue_redraw()


func _pick_target() -> void:
	var t := Vector2i(int(floor(position.x / 16.0)), int(floor(position.y / 16.0)))
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var n: Vector2i = t + d
		if main.is_passable(n):
			target = Vector2(n.x * 16 + 8, n.y * 16 + 8)
			moving = true
			return
	wait = 1.0


func _update_sprite() -> void:
	var frame := (int(anim_time * 4.0) % 2) if moving else 0
	sprite.texture = main.tex["%s_%d" % [type, frame]]
