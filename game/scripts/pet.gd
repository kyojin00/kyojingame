# 펫: 활성 펫이 농장에서 플레이어를 졸졸 따라다닌다. (패시브 효과는 GameData가 적용)
extends Node2D

var main: Node2D
var sprite: Sprite2D
var anim := 0.0
var _flip := false


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-16, -28)
	add_child(sprite)


func _draw() -> void:
	# 발밑 그림자 — 펫도 땅을 딛는다 (여태 없어서 붕 떠 보였다)
	KyojinMain.draw_ground_shadow(self, 5.0, 1.7)


func _process(delta: float) -> void:
	if GameData.active_pet == "" or main.player == null:
		visible = false
		return
	visible = true
	anim += delta
	# 플레이어 뒤를 따라다닌다
	var target: Vector2 = main.player.position + Vector2(28, 8)
	var d := position.distance_to(target)
	if d > 40.0:
		var dir := (target - position).normalized()
		position += dir * minf(190.0, d * 2.5) * delta
		if absf(dir.x) > 0.2:
			_flip = dir.x > 0.0
	var frame := int(anim * 4.0) % 2 if d > 40.0 else 0
	sprite.texture = main.tex["pet_%s_%d" % [GameData.active_pet, frame]]
	sprite.flip_h = _flip
