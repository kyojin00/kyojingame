# 집 내부: 문에서 E로 입장, 침대에서 잠자기, F로 꾸미기 모드, 아래 문으로 나가기.
extends CanvasLayer

const ROOM := Rect2(120, 75, 720, 390)  # 방 전체 (벽 포함)
const FLOOR_TOP := 156.0                # 벽 아래부터 바닥
const BED := Rect2(156, 162, 69, 99)
const KITCHEN := Rect2(600, 117, 93, 39)  # 조리대 (윗벽에 붙박이)
const EXIT_X := Vector2(408, 552)       # 아랫벽 문 구간
const GRID := 12.0                      # 꾸미기 배치 격자

var main: Node2D
var canvas: Control
var player_sprite: Sprite2D
var ppos := Vector2(480, 444)
var pdir := "up"
var moving := false
var anim_time := 0.0

# 꾸미기 모드
var deco_mode := false
var cursor := Vector2(480, 300)
var held: Dictionary = {}       # 들고 있는 가구 {id, x, y} (+ orig_x/orig_y = 원위치)
var _cursor_cd := 0.0


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


func open() -> void:
	visible = true
	ppos = Vector2(480, 444)
	pdir = "up"
	deco_mode = false
	held = {}
	Sound.play_sfx("sfx_place")
	canvas.queue_redraw()


func close() -> void:
	if deco_mode:
		_exit_deco()
	visible = false
	Sound.play_sfx("sfx_place")


func _process(delta: float) -> void:
	if not visible or main.dialog.visible or main.sleep_dialog.visible \
			or main.summary.visible or main.cooking_ui.visible:
		moving = false
		_update_sprite()
		return
	if deco_mode:
		_process_deco(delta)
		canvas.queue_redraw()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving:
		if absf(v.x) > absf(v.y):
			pdir = "right" if v.x > 0 else "left"
		else:
			pdir = "down" if v.y > 0 else "up"
		var np := ppos + v * 150.0 * delta
		np.x = clampf(np.x, ROOM.position.x + 18, ROOM.end.x - 18)
		np.y = clampf(np.y, FLOOR_TOP + 9, ROOM.end.y - 6)
		if not _blocked(np):
			ppos = np
		anim_time += delta
		# 아랫문으로 나가기
		if ppos.y >= ROOM.end.y - 9 and ppos.x > EXIT_X.x and ppos.x < EXIT_X.y and v.y > 0:
			close()
	_update_sprite()
	canvas.queue_redraw()


func _process_deco(delta: float) -> void:
	moving = false
	_update_sprite()
	_cursor_cd -= delta
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v != Vector2.ZERO and _cursor_cd <= 0.0:
		_cursor_cd = 0.06
		cursor += Vector2(signf(v.x), signf(v.y)) * GRID
		cursor.x = clampf(cursor.x, ROOM.position.x, ROOM.end.x - GRID)
		cursor.y = clampf(cursor.y, ROOM.position.y + 8, ROOM.end.y - GRID)
		if not held.is_empty():
			held.x = cursor.x
			held.y = cursor.y


func _furn_rect(f: Dictionary) -> Rect2:
	var def: Dictionary = GameData.FURNITURE[f.id]
	return Rect2(float(f.x), float(f.y), float(def.w), float(def.h))


func _blocked(p: Vector2) -> bool:
	var feet := Rect2(p.x - 8, p.y - 6, 16, 8)
	if feet.intersects(BED):
		return true
	for f in GameData.furniture:
		if GameData.FURNITURE[f.id].solid and feet.intersects(_furn_rect(f)):
			return true
	return false


# 가구를 이 자리에 놓아도 되는가 (방 안 + 침대/솔리드 가구와 겹치지 않게)
func _can_place(f: Dictionary) -> bool:
	var r := _furn_rect(f)
	if r.position.x < ROOM.position.x + 4 or r.end.x > ROOM.end.x - 4:
		return false
	if r.position.y < ROOM.position.y + 12 or r.end.y > ROOM.end.y - 4:
		return false
	# 아랫문 막기 금지
	if r.end.y > ROOM.end.y - 14 and r.end.x > EXIT_X.x and r.position.x < EXIT_X.y:
		return false
	var solid: bool = GameData.FURNITURE[f.id].solid
	if solid and r.intersects(BED.grow(2)):
		return false
	if solid:
		for other in GameData.furniture:
			if other != f and GameData.FURNITURE[other.id].solid \
					and r.intersects(_furn_rect(other)):
				return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialog.visible or main.sleep_dialog.visible \
			or main.cooking_ui.visible:
		return
	if deco_mode:
		_deco_input(event)
		return
	if event.is_action_pressed("interact"):
		if (ppos - KITCHEN.get_center()).length() < 69.0:
			main.cooking_ui.open()
			get_viewport().set_input_as_handled()
		elif (ppos - BED.get_center()).length() < 82.0:
			main.request_sleep()
		else:
			main.hud.show_message("침대 E: 잠자기 · 조리대 E: 요리 · F: 꾸미기")
	elif event is InputEventKey and event.pressed and not event.echo \
			and _key_of(event) == KEY_F:
		deco_mode = true
		cursor = (ppos / GRID).floor() * GRID
		Sound.play_sfx("sfx_ui")
	elif event.is_action_pressed("ui_cancel"):
		close()


# 실제 키보드는 keycode, 테스트 하네스는 physical_keycode만 채워서 보낸다
func _key_of(event: InputEventKey) -> int:
	return event.keycode if event.keycode != KEY_NONE else event.physical_keycode


func _deco_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
		if held.is_empty():
			_pick_up()
		else:
			_place_held()
	elif event is InputEventKey and event.pressed and not event.echo:
		match _key_of(event):
			KEY_F, KEY_ESCAPE:
				_exit_deco()
			KEY_X:
				_sell_held()
			_:
				var idx: int = _key_of(event) - KEY_1
				if idx >= 0 and idx < GameData.FURNITURE_IDS.size():
					_buy_furniture(GameData.FURNITURE_IDS[idx])


func _pick_up() -> void:
	# 커서 아래 가구 집기 (나중에 그려진 = 위에 보이는 것부터)
	for i in range(GameData.furniture.size() - 1, -1, -1):
		var f: Dictionary = GameData.furniture[i]
		if _furn_rect(f).has_point(cursor + Vector2(GRID / 2, GRID / 2)):
			held = f
			held["orig_x"] = float(f.x)
			held["orig_y"] = float(f.y)
			held.x = cursor.x
			held.y = cursor.y
			Sound.play_sfx("sfx_ui")
			return
	main.hud.show_message("빈 곳이다. 숫자키로 가구를 사거나 가구 위에서 집자.")


func _place_held() -> void:
	if _can_place(held):
		held.erase("orig_x")
		held.erase("orig_y")
		var delta := 0
		if held.has("new_cost"):
			delta = -int(held.new_cost)
			held.erase("new_cost")
		held = {}
		Sound.play_sfx("sfx_place")
		main.sync_furniture(delta)
	else:
		main.hud.show_message("여기에는 놓을 수 없다.")


func _buy_furniture(id: String) -> void:
	if not held.is_empty():
		main.hud.show_message("들고 있는 가구를 먼저 놓자. (E: 놓기 / X: 판매)")
		return
	var def: Dictionary = GameData.FURNITURE[id]
	if GameData.money < int(def.price):
		main.hud.show_message("돈이 부족하다. (%dG 필요)" % int(def.price))
		return
	GameData.money -= int(def.price)
	held = {"id": id, "x": cursor.x, "y": cursor.y, "new_cost": int(def.price)}
	GameData.furniture.append(held)
	Sound.play_sfx("sfx_buy")
	main.hud.show_message("%s 구입! 자리를 골라 E로 놓자." % def.name)


func _sell_held() -> void:
	if held.is_empty():
		return
	var def: Dictionary = GameData.FURNITURE[held.id]
	GameData.furniture.erase(held)
	var delta := 0
	if held.has("new_cost"):
		GameData.money += int(held.new_cost)  # 방금 산 것은 전액 환불
		main.hud.show_message("%s 구입 취소." % def.name)
	else:
		var refund := int(def.price) / 2
		GameData.money += refund
		delta = refund
		main.hud.show_message("%s 판매 (+%dG)" % [def.name, refund])
	held = {}
	Sound.play_sfx("sfx_sell")
	main.sync_furniture(delta)


func _exit_deco() -> void:
	if not held.is_empty():
		# 들고 있던 가구 정리: 원위치로 되돌리거나, 새로 산 것은 환불
		if held.has("new_cost"):
			GameData.furniture.erase(held)
			GameData.money += int(held.new_cost)
		else:
			held.x = float(held.orig_x)
			held.y = float(held.orig_y)
			held.erase("orig_x")
			held.erase("orig_y")
		held = {}
	deco_mode = false
	Sound.play_sfx("sfx_ui")
	main.sync_furniture(0)


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
	player_sprite.flip_h = false
	match pdir:
		"down":
			tex_name = GameData.player_tex("down_" + suffix) if suffix != "idle" \
				else GameData.player_idle_tex("down")
		"up":
			tex_name = GameData.player_tex("up_" + suffix) if suffix != "idle" \
				else GameData.player_idle_tex("up")
		_:
			tex_name = GameData.player_side_tex(suffix, anim_time)
			player_sprite.flip_h = pdir == "left"
	player_sprite.texture = main.tex[tex_name]
	player_sprite.position = ppos + Vector2(-16, -47)
	player_sprite.modulate.a = 0.4 if deco_mode else 1.0


func _draw_room() -> void:
	# 벽
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, FLOOR_TOP - ROOM.position.y)),
		Color(0.42, 0.29, 0.19))
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, 8)), Color(0.3, 0.2, 0.13))
	# 창문 2개 (밖의 하늘)
	for wx in [270.0, 690.0]:
		canvas.draw_rect(Rect2(wx, 99, 60, 39), Color(0.25, 0.17, 0.11))
		canvas.draw_rect(Rect2(wx + 3, 102, 54, 33),
			Color(0.55, 0.75, 0.95) if GameData.minutes < 18 * 60 else Color(0.13, 0.12, 0.3))
		canvas.draw_rect(Rect2(wx + 28, 102, 3, 33), Color(0.25, 0.17, 0.11))

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

	# 주방 조리대 (고정)
	canvas.draw_rect(KITCHEN, Color(0.52, 0.36, 0.22))
	canvas.draw_rect(Rect2(KITCHEN.position, Vector2(KITCHEN.size.x, 6)), Color(0.72, 0.7, 0.68))
	# 화구 + 냄비
	canvas.draw_rect(Rect2(KITCHEN.position.x + 8, KITCHEN.position.y + 1, 14, 4),
		Color(0.2, 0.18, 0.2))
	canvas.draw_rect(Rect2(KITCHEN.position.x + 10, KITCHEN.position.y - 6, 10, 7),
		Color(0.35, 0.35, 0.4))
	canvas.draw_rect(Rect2(KITCHEN.position.x + 8, KITCHEN.position.y - 7, 14, 2),
		Color(0.45, 0.45, 0.5))
	# 도마 + 접시
	canvas.draw_rect(Rect2(KITCHEN.position.x + 34, KITCHEN.position.y + 1, 16, 4),
		Color(0.78, 0.62, 0.4))
	canvas.draw_rect(Rect2(KITCHEN.end.x - 10, KITCHEN.position.y + 1, 6, 4),
		Color(0.9, 0.9, 0.92))

	# 침대 (고정 가구)
	canvas.draw_rect(BED.grow(2), Color(0.35, 0.23, 0.14))
	canvas.draw_rect(BED, Color(0.75, 0.3, 0.28))
	canvas.draw_rect(Rect2(BED.position.x + 3, BED.position.y + 3, BED.size.x - 6, 16),
		Color(0.92, 0.9, 0.85))
	canvas.draw_rect(Rect2(BED.position.x, BED.position.y + 24, BED.size.x, 4),
		Color(0.6, 0.22, 0.2))

	# 배치된 가구 (러그 같은 비충돌 가구 먼저 → 그 위에 솔리드)
	for f in GameData.furniture:
		if not GameData.FURNITURE[f.id].solid:
			_draw_furniture(f)
	for f in GameData.furniture:
		if GameData.FURNITURE[f.id].solid:
			_draw_furniture(f)

	# 아랫문 (매트)
	canvas.draw_rect(Rect2(EXIT_X.x, ROOM.end.y - 8, EXIT_X.y - EXIT_X.x, 8), Color(0.35, 0.25, 0.15))
	canvas.draw_rect(Rect2(EXIT_X.x + 6, ROOM.end.y - 6, EXIT_X.y - EXIT_X.x - 12, 4), Color(0.7, 0.6, 0.4))

	# 그림자 + 안내
	canvas.draw_rect(Rect2(ppos.x - 4, ppos.y - 2, 8, 3), Color(0, 0, 0, 0.22))
	if deco_mode:
		_draw_deco_ui()
	else:
		var guide := "E: 잠자기/요리 · F: 꾸미기 · 아랫문: 나가기"
		_draw_center_text(guide, 72)


func _draw_center_text(text: String, ty: float) -> void:
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	canvas.draw_string_outline(main.UI_FONT, Vector2(480 - w / 2.0, ty), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3, Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, Vector2(480 - w / 2.0, ty), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.92, 0.85))


func _draw_deco_ui() -> void:
	# 커서 (들고 있으면 배치 가능 여부 색으로 표시)
	if held.is_empty():
		canvas.draw_rect(Rect2(cursor, Vector2(GRID, GRID)), Color(1, 1, 0.4, 0.9), false, 1.0)
	else:
		var r := _furn_rect(held)
		canvas.draw_rect(r, Color(0.4, 1, 0.5, 0.35) if _can_place(held)
			else Color(1, 0.35, 0.3, 0.35))
		canvas.draw_rect(r, Color(1, 1, 1, 0.8), false, 1.0)

	_draw_center_text("꾸미기 모드 - E: 집기/놓기 · X: 판매 · F: 완료", 72)

	# 가구 카탈로그 (숫자키 구입)
	var px := 8.0
	var py := 60.0
	canvas.draw_rect(Rect2(px - 4, py - 14, 84, GameData.FURNITURE_IDS.size() * 18.0 + 20),
		Color(0.05, 0.04, 0.08, 0.75))
	canvas.draw_string(main.UI_FONT, Vector2(px, py), "[가구 구입]",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.84, 0.37))
	for i in GameData.FURNITURE_IDS.size():
		var id: String = GameData.FURNITURE_IDS[i]
		var def: Dictionary = GameData.FURNITURE[id]
		py += 18.0
		canvas.draw_string(main.UI_FONT, Vector2(px, py),
			"%d %s %dG" % [i + 1, def.name, int(def.price)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.92, 0.9, 0.95))


func _draw_furniture(f: Dictionary) -> void:
	var p := Vector2(float(f.x), float(f.y))
	var def: Dictionary = GameData.FURNITURE[f.id]
	var w := float(def.w)
	var h := float(def.h)
	match String(f.id):
		"rug":
			canvas.draw_rect(Rect2(p, Vector2(w, h)), Color(0.45, 0.6, 0.42))
			canvas.draw_rect(Rect2(p + Vector2(4, 4), Vector2(w - 8, h - 8)), Color(0.52, 0.68, 0.48))
		"table":
			canvas.draw_rect(Rect2(p, Vector2(w, h)), Color(0.52, 0.36, 0.22))
			canvas.draw_rect(Rect2(p + Vector2(4, 4), Vector2(w - 8, h - 8)), Color(0.6, 0.43, 0.26))
		"chair":
			canvas.draw_rect(Rect2(p, Vector2(w, h)), Color(0.45, 0.3, 0.18))
			canvas.draw_rect(Rect2(p + Vector2(2, 2), Vector2(w - 4, 5)), Color(0.55, 0.38, 0.22))
		"chest":
			canvas.draw_rect(Rect2(p, Vector2(w, h)), Color(0.5, 0.33, 0.18))
			canvas.draw_rect(Rect2(p.x, p.y + 10, w, 3), Color(0.85, 0.7, 0.3))
		"plant":
			canvas.draw_rect(Rect2(p.x + 4, p.y + h - 8, w - 8, 8), Color(0.65, 0.4, 0.25))
			canvas.draw_rect(Rect2(p.x + 2, p.y + 2, w - 4, h - 10), Color(0.3, 0.6, 0.3))
			canvas.draw_rect(Rect2(p.x + 5, p.y, w - 10, 6), Color(0.38, 0.7, 0.35))
		"bookshelf":
			canvas.draw_rect(Rect2(p, Vector2(w, h)), Color(0.45, 0.3, 0.18))
			for shelf in 3:
				var sy := p.y + 6 + shelf * 14.0
				canvas.draw_rect(Rect2(p.x + 3, sy, w - 6, 9), Color(0.3, 0.2, 0.12))
				for b in 4:
					canvas.draw_rect(Rect2(p.x + 4 + b * 7.0, sy + 1, 5, 8),
						[Color(0.7, 0.35, 0.3), Color(0.35, 0.5, 0.7),
						Color(0.5, 0.65, 0.4), Color(0.8, 0.7, 0.4)][b])
		"lamp":
			canvas.draw_rect(Rect2(p.x + 4, p.y + 8, 4, h - 10), Color(0.4, 0.3, 0.2))
			canvas.draw_rect(Rect2(p.x + 2, p.y + h - 2, 8, 2), Color(0.35, 0.25, 0.16))
			canvas.draw_rect(Rect2(p.x, p.y, w, 9), Color(1, 0.85, 0.5))
			canvas.draw_rect(Rect2(p.x + 2, p.y + 2, w - 4, 5), Color(1, 0.95, 0.75))
		"small_table":
			canvas.draw_rect(Rect2(p, Vector2(w, h - 6)), Color(0.55, 0.38, 0.24))
			canvas.draw_rect(Rect2(p.x + 3, p.y + h - 6, 4, 6), Color(0.42, 0.28, 0.17))
			canvas.draw_rect(Rect2(p.x + w - 7, p.y + h - 6, 4, 6), Color(0.42, 0.28, 0.17))
