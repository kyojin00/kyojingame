# 곤충: 들판을 팔랑팔랑 날아다닌다. 가까이 가서 E로 잡으면 연구 노트에 기록.
extends Node2D

var main: Node2D
var bug_id := "bug_butterfly"
var night_only := false
var anim := 0.0
var _target := Vector2.ZERO
var _think := 0.0
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = true
	add_child(sprite)
	_target = position


func respawn() -> void:
	position = Vector2(randi_range(2, main.MAP_W - 2) * main.TILE,
		randi_range(2, main.MAP_H - 2) * main.TILE)
	_target = position


func _process(delta: float) -> void:
	# 반딧불이는 저녁(19시~)에만 나타난다
	var night: bool = GameData.minutes >= 19.0 * 60.0
	visible = night if night_only else true
	if not visible:
		return
	anim += delta
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(1.0, 2.5)
		_target = position + Vector2(randf_range(-80, 80), randf_range(-60, 60))
		_target.x = clampf(_target.x, main.TILE, (main.MAP_W - 1) * float(main.TILE))
		_target.y = clampf(_target.y, main.TILE, (main.MAP_H - 1) * float(main.TILE))
	position = position.move_toward(_target, 44.0 * delta)
	position.y += sin(anim * 5.0) * 0.15
	sprite.texture = main.tex["%s_%d" % [bug_id, int(anim * 6.0) % 2]]
