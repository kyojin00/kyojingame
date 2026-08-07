# NPC: 마을 구역 안을 돌아다니고, E로 대화/선물을 받는다.
extends Node2D

var main: Node2D
var id := "merchant"
var region := Rect2i(46, 2, 13, 15)  # 배회 구역 (타일 단위)
var talked_today := false
var sprite: Sprite2D
var dir := "down"
var anim_time := 0.0
var moving := false
var target: Vector2
var wait := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-6, -15)
	add_child(sprite)
	target = position
	wait = randf_range(0.5, 2.0)
	_update_sprite()


func _process(delta: float) -> void:
	if main.ui_open():
		return
	anim_time += delta
	if moving:
		var d := target - position
		if d.length() < 1.5:
			moving = false
			wait = randf_range(1.5, 4.0)
		else:
			var step := d.normalized() * 20.0 * delta
			if absf(step.x) > absf(step.y):
				dir = "right" if step.x > 0 else "left"
			else:
				dir = "down" if step.y > 0 else "up"
			position += step
	else:
		wait -= delta
		if wait <= 0.0:
			_pick_target()
	_update_sprite()


func _pick_target() -> void:
	var t := Vector2i(int(floor(position.x / 16.0)), int(floor(position.y / 16.0)))
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var n: Vector2i = t + d
		if region.has_point(n) and main.is_passable(n):
			target = Vector2(n.x * 16 + 8, n.y * 16 + 8)
			moving = true
			return
	wait = 1.0


func _update_sprite() -> void:
	var frame := (int(anim_time * 5.0) % 2) if moving else 0
	var key := ""
	sprite.flip_h = false
	match dir:
		"down":
			key = "down_%d" % frame
		"up":
			key = "up_%d" % frame
		_:
			key = "side_%d" % frame
			sprite.flip_h = dir == "left"
	sprite.texture = main.tex["npc_%s_%s" % [id, key]]
