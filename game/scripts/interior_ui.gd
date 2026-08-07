# 집 내부 (초안): 문에서 E로 입장, 침대에서 잠자기, 아래 문으로 나가기.
extends CanvasLayer

const ROOM := Rect2(90, 56, 300, 204)   # 방 전체 (벽 포함)
const FLOOR_TOP := 104.0                # 벽 아래부터 바닥
const BED := Rect2(104, 108, 46, 66)
const TABLE := Rect2(226, 152, 60, 42)
const CHEST := Rect2(344, 110, 30, 26)
const EXIT_X := Vector2(216, 264)       # 아랫벽 문 구간

var main: Node2D
var canvas: Control
var player_sprite: Sprite2D
var ppos := Vector2(240, 236)
var pdir := "up"
var moving := false
var anim_time := 0.0


func _ready() -> void:
	layer = 15
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_room)
	add_child(canvas)

	player_sprite = Sprite2D.new()
	player_sprite.centered = false
	add_child(player_sprite)


func open() -> void:
	visible = true
	ppos = Vector2(240, 236)
	pdir = "up"
	Sound.play_sfx("sfx_place")
	canvas.queue_redraw()


func close() -> void:
	visible = false
	Sound.play_sfx("sfx_place")


func _process(delta: float) -> void:
	if not visible or main.dialog.visible or main.sleep_dialog.visible \
			or main.summary.visible:
		moving = false
		_update_sprite()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving:
		if absf(v.x) > absf(v.y):
			pdir = "right" if v.x > 0 else "left"
		else:
			pdir = "down" if v.y > 0 else "up"
		var np := ppos + v * 90.0 * delta
		np.x = clampf(np.x, ROOM.position.x + 12, ROOM.end.x - 12)
		np.y = clampf(np.y, FLOOR_TOP + 6, ROOM.end.y - 4)
		if not _blocked(np):
			ppos = np
		anim_time += delta
		# 아랫문으로 나가기
		if ppos.y >= ROOM.end.y - 6 and ppos.x > EXIT_X.x and ppos.x < EXIT_X.y and v.y > 0:
			close()
	_update_sprite()
	canvas.queue_redraw()


func _blocked(p: Vector2) -> bool:
	var feet := Rect2(p.x - 5, p.y - 4, 10, 5)
	return feet.intersects(BED) or feet.intersects(TABLE) or feet.intersects(CHEST)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialog.visible or main.sleep_dialog.visible:
		return
	if event.is_action_pressed("interact"):
		if (ppos - BED.get_center()).length() < 55.0:
			main.request_sleep()
		else:
			main.hud.show_message("침대 옆에서 E: 잠자기 · 아래 문으로 나가기")
	elif event.is_action_pressed("ui_cancel"):
		close()


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
	player_sprite.position = ppos + Vector2(-8, -23)


func _draw_room() -> void:
	# 벽
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, FLOOR_TOP - ROOM.position.y)),
		Color(0.42, 0.29, 0.19))
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, 8)), Color(0.3, 0.2, 0.13))
	# 창문 2개 (밖의 하늘)
	for wx in [140.0, 300.0]:
		canvas.draw_rect(Rect2(wx, 66, 40, 26), Color(0.25, 0.17, 0.11))
		canvas.draw_rect(Rect2(wx + 2, 68, 36, 22),
			Color(0.55, 0.75, 0.95) if GameData.minutes < 18 * 60 else Color(0.13, 0.12, 0.3))
		canvas.draw_rect(Rect2(wx + 19, 68, 2, 22), Color(0.25, 0.17, 0.11))

	# 바닥 (나무 판자)
	var y := FLOOR_TOP
	var row := 0
	while y < ROOM.end.y:
		var h := minf(14.0, ROOM.end.y - y)
		canvas.draw_rect(Rect2(ROOM.position.x, y, ROOM.size.x, h),
			Color(0.63, 0.45, 0.28) if row % 2 == 0 else Color(0.58, 0.41, 0.25))
		var seam := ROOM.position.x + (16 if row % 2 == 0 else 40)
		while seam < ROOM.end.x:
			canvas.draw_rect(Rect2(seam, y, 1, h), Color(0.5, 0.35, 0.21))
			seam += 48
		y += h
		row += 1

	# 러그
	canvas.draw_rect(Rect2(196, 206, 88, 40), Color(0.45, 0.6, 0.42))
	canvas.draw_rect(Rect2(200, 210, 80, 32), Color(0.52, 0.68, 0.48))

	# 침대
	canvas.draw_rect(BED.grow(2), Color(0.35, 0.23, 0.14))
	canvas.draw_rect(BED, Color(0.75, 0.3, 0.28))
	canvas.draw_rect(Rect2(BED.position.x + 3, BED.position.y + 3, BED.size.x - 6, 16),
		Color(0.92, 0.9, 0.85))
	canvas.draw_rect(Rect2(BED.position.x, BED.position.y + 24, BED.size.x, 4),
		Color(0.6, 0.22, 0.2))

	# 테이블 + 의자
	canvas.draw_rect(TABLE, Color(0.52, 0.36, 0.22))
	canvas.draw_rect(Rect2(TABLE.position + Vector2(4, 4), TABLE.size - Vector2(8, 8)),
		Color(0.6, 0.43, 0.26))
	canvas.draw_rect(Rect2(TABLE.position.x - 18, TABLE.position.y + 10, 14, 16), Color(0.45, 0.3, 0.18))
	canvas.draw_rect(Rect2(TABLE.end.x + 4, TABLE.position.y + 10, 14, 16), Color(0.45, 0.3, 0.18))

	# 궤짝
	canvas.draw_rect(CHEST, Color(0.5, 0.33, 0.18))
	canvas.draw_rect(Rect2(CHEST.position.x, CHEST.position.y + 10, CHEST.size.x, 3), Color(0.85, 0.7, 0.3))

	# 아랫문 (매트)
	canvas.draw_rect(Rect2(EXIT_X.x, ROOM.end.y - 8, EXIT_X.y - EXIT_X.x, 8), Color(0.35, 0.25, 0.15))
	canvas.draw_rect(Rect2(EXIT_X.x + 6, ROOM.end.y - 6, EXIT_X.y - EXIT_X.x - 12, 4), Color(0.7, 0.6, 0.4))

	# 그림자 + 안내
	canvas.draw_rect(Rect2(ppos.x - 4, ppos.y - 2, 8, 3), Color(0, 0, 0, 0.22))
	var guide := "침대 E: 잠자기 · 아래 문: 나가기"
	var w: float = main.UI_FONT.get_string_size(guide, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	canvas.draw_string_outline(main.UI_FONT, Vector2(240 - w / 2.0, 48), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, Vector2(240 - w / 2.0, 48), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.92, 0.85))
