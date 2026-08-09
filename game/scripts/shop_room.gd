# 상점 실내: 가게마다 다른 방.
#
# 문으로 들어오면 이 방이 열리고, 안에서 걸어 다니다가
# 계산대 앞에서 E를 누르면 그 가게의 거래 창(shop_ui)이 열린다.
# 아래쪽 문으로 나가면 마을로 돌아간다.
#
# 방마다 다른 것: 벽/바닥 색, 계산대 색, 소품, 주인 NPC, 열리는 거래 탭.
# 새 가게를 추가할 때는 ROOMS에 한 줄만 넣으면 된다.
extends CanvasLayer

const ROOM := Rect2(120, 75, 720, 384)   # 방 전체 (벽 포함)
const FLOOR_TOP := 156.0                 # 벽 아래부터 바닥
const COUNTER := Rect2(276, 186, 408, 54)
const EXIT_X := Vector2(432, 528)        # 아랫벽 문 구간

const ROOMS := {
	"general": {
		"name": "잡화점", "keeper": "merchant",
		"wall": Color(0.46, 0.33, 0.22), "floor": Color(0.68, 0.52, 0.34),
		"counter": Color(0.55, 0.38, 0.22), "deco": "shelf",
		"tab": "buy", "tabs": ["buy", "sell"],
		"hint": "씨앗을 사고 작물을 판다.",
	},
	"smith": {
		"name": "대장간", "keeper": "blacksmith",
		"wall": Color(0.3, 0.26, 0.27), "floor": Color(0.4, 0.36, 0.36),
		"counter": Color(0.32, 0.28, 0.26), "deco": "forge",
		"tab": "upgrade", "tabs": ["upgrade"],
		"hint": "도구를 강화한다.",
	},
	"ranch": {
		"name": "목장 상회", "keeper": "rancher",
		"wall": Color(0.44, 0.36, 0.22), "floor": Color(0.62, 0.52, 0.3),
		"counter": Color(0.5, 0.38, 0.22), "deco": "hay",
		"tab": "animal", "tabs": ["animal"],
		"hint": "동물과 펫을 들인다.",
	},
	"fish": {
		"name": "수산시장", "keeper": "fisher",
		"wall": Color(0.24, 0.36, 0.44), "floor": Color(0.42, 0.55, 0.6),
		"counter": Color(0.28, 0.4, 0.46), "deco": "crate",
		"tab": "codex", "tabs": ["codex"],
		"hint": "물고기 도감을 본다.",
	},
	"post": {
		"name": "우체국", "keeper": "postman",
		"wall": Color(0.36, 0.33, 0.46), "floor": Color(0.55, 0.5, 0.62),
		"counter": Color(0.4, 0.34, 0.5), "deco": "mail",
		"tab": "", "tabs": [],
		"hint": "우체부 아저씨가 편지를 정리하고 있다.",
	},
}

var main: Node2D
var canvas: Control
var player_sprite: Sprite2D
var room_id := ""
var ppos := Vector2(480, 420)
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
	player_sprite.scale = Vector2(0.5, 0.5)
	add_child(player_sprite)


func has_room(id: String) -> bool:
	return ROOMS.has(id)


func open(id: String) -> void:
	if not ROOMS.has(id):
		return
	room_id = id
	visible = true
	ppos = Vector2(480, 420)
	pdir = "up"
	moving = false
	Sound.play_sfx("sfx_place")
	main.hud.show_message("%s — 계산대 앞에서 E" % ROOMS[id].name, 3.0)
	canvas.queue_redraw()


func close() -> void:
	visible = false
	room_id = ""
	Sound.play_sfx("sfx_place")


func _def() -> Dictionary:
	return ROOMS.get(room_id, ROOMS.general)


func _process(delta: float) -> void:
	if not visible or main.dialog.visible or main.shop.visible:
		moving = false
		_update_sprite()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving:
		if v.x != 0.0:
			pdir = "right" if v.x > 0 else "left"
		else:
			pdir = "down" if v.y > 0 else "up"
		var np := ppos + v * 150.0 * delta
		np.x = clampf(np.x, ROOM.position.x + 18, ROOM.end.x - 18)
		np.y = clampf(np.y, FLOOR_TOP + 9, ROOM.end.y - 6)
		if not Rect2(np.x - 8, np.y - 6, 16, 8).intersects(COUNTER):
			ppos = np
		anim_time += delta
		# 아랫문으로 나가기
		if ppos.y >= ROOM.end.y - 9 and ppos.x > EXIT_X.x and ppos.x < EXIT_X.y and v.y > 0:
			close()
	_update_sprite()
	canvas.queue_redraw()


func _at_counter() -> bool:
	return absf(ppos.y - COUNTER.end.y) < 46.0 \
		and ppos.x > COUNTER.position.x - 20.0 and ppos.x < COUNTER.end.x + 20.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialog.visible or main.shop.visible:
		return
	if event.is_action_pressed("interact"):
		if _at_counter():
			var d := _def()
			if str(d.tab) == "":
				main.hud.show_message(str(d.hint), 4.0)
			else:
				main.shop.open(str(d.tab), d.tabs)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _update_sprite() -> void:
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
	player_sprite.flip_h = false
	match pdir:
		"down":
			tex_name = GameData.player_down_tex(moving, suffix, anim_time)
		"up":
			tex_name = GameData.player_up_tex(moving, suffix, anim_time)
		_:
			tex_name = GameData.player_side_tex(moving, suffix, anim_time)
			player_sprite.flip_h = pdir == "left"
	player_sprite.texture = main.tex[tex_name]
	player_sprite.position = ppos + Vector2(-16, -47)


func _draw_room() -> void:
	var d := _def()
	var wall: Color = d.wall
	# 벽
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, FLOOR_TOP - ROOM.position.y)),
		wall)
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, 8)), wall.darkened(0.35))
	# 간판
	var sign_rect := Rect2(ROOM.position.x + 24, 92, 230, 44)   # 주인과 겹치지 않게 왼쪽 벽
	canvas.draw_rect(sign_rect, wall.darkened(0.45))
	canvas.draw_rect(sign_rect.grow(-4), wall.lightened(0.25))
	var f: Font = main.UI_FONT
	var tw: float = f.get_string_size(str(d.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	canvas.draw_string(f, Vector2(sign_rect.get_center().x - tw / 2.0, 124),
		str(d.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.6))

	# 바닥 (타일)
	var floor_c: Color = d.floor
	var y := FLOOR_TOP
	var row := 0
	while y < ROOM.end.y:
		var h := minf(16.0, ROOM.end.y - y)
		var x := ROOM.position.x
		var col := 0
		while x < ROOM.end.x:
			var w := minf(24.0, ROOM.end.x - x)
			canvas.draw_rect(Rect2(x, y, w, h),
				floor_c if (row + col) % 2 == 0 else floor_c.darkened(0.08))
			x += w
			col += 1
		y += h
		row += 1

	_draw_deco(str(d.deco), wall)

	# 계산대
	canvas.draw_rect(COUNTER.grow(2), Color(0.2, 0.14, 0.1))
	canvas.draw_rect(COUNTER, d.counter)
	canvas.draw_rect(Rect2(COUNTER.position, Vector2(COUNTER.size.x, 8)),
		Color(d.counter).lightened(0.3))

	# 주인 (계산대 뒤)
	var kt := "npc_%s_down_0" % str(d.keeper)
	if main.tex.has(kt):
		canvas.draw_texture_rect(main.tex[kt],
			Rect2(COUNTER.get_center().x - 32, COUNTER.position.y - 96, 64, 96), false)

	# 아랫문
	canvas.draw_rect(Rect2(EXIT_X.x, ROOM.end.y - 10, EXIT_X.y - EXIT_X.x, 10),
		Color(0.35, 0.24, 0.14))
	var ew: float = f.get_string_size("나가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	canvas.draw_string(f, Vector2((EXIT_X.x + EXIT_X.y) / 2.0 - ew / 2.0, ROOM.end.y + 18),
		"나가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.75, 0.7))

	if _at_counter():
		var ht := "E: %s" % str(d.hint)
		var hw: float = f.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		canvas.draw_string(f, Vector2(480 - hw / 2.0, COUNTER.end.y + 40),
			ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.6))


# 가게마다 다른 소품
func _draw_deco(kind: String, wall: Color) -> void:
	match kind:
		"shelf":
			for i in 3:
				var sy := 168.0 + i * 30.0
				canvas.draw_rect(Rect2(150, sy, 100, 8), wall.darkened(0.3))
				for j in 4:
					canvas.draw_rect(Rect2(156 + j * 24, sy - 16, 16, 16),
						Color(0.75, 0.6, 0.35).lightened(j * 0.08))
			for i in 3:
				var sy2 := 168.0 + i * 30.0
				canvas.draw_rect(Rect2(710, sy2, 100, 8), wall.darkened(0.3))
		"forge":
			canvas.draw_rect(Rect2(160, 200, 110, 70), Color(0.24, 0.2, 0.2))   # 화로
			canvas.draw_rect(Rect2(178, 216, 74, 38), Color(0.95, 0.55, 0.15))
			canvas.draw_rect(Rect2(190, 228, 50, 20), Color(1, 0.85, 0.4))
			canvas.draw_rect(Rect2(716, 236, 84, 34), Color(0.3, 0.3, 0.34))    # 모루
			canvas.draw_rect(Rect2(740, 270, 36, 30), Color(0.24, 0.24, 0.28))
		"hay":
			for i in 2:
				canvas.draw_rect(Rect2(156 + i * 16, 210 + i * 44, 90, 46),
					Color(0.85, 0.72, 0.3))
				canvas.draw_rect(Rect2(156 + i * 16, 210 + i * 44, 90, 6),
					Color(0.7, 0.58, 0.22))
			canvas.draw_rect(Rect2(716, 220, 92, 80), Color(0.5, 0.36, 0.2))    # 여물통
		"crate":
			for i in 3:
				var cx := 150.0 + i * 60.0
				canvas.draw_rect(Rect2(cx, 300, 54, 44), Color(0.55, 0.42, 0.28))
				canvas.draw_rect(Rect2(cx + 4, 292, 46, 12), Color(0.7, 0.85, 0.95))
			canvas.draw_rect(Rect2(716, 296, 92, 48), Color(0.55, 0.42, 0.28))
		"mail":
			for i in 4:
				for j in 3:
					canvas.draw_rect(Rect2(150 + i * 26, 176 + j * 26, 22, 22),
						wall.darkened(0.25))
			canvas.draw_rect(Rect2(716, 250, 90, 60), Color(0.45, 0.36, 0.55))
			canvas.draw_rect(Rect2(726, 240, 70, 14), Color(0.9, 0.88, 0.84))
