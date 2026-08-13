# 집 내부: 문에서 E로 입장, 침대에서 잠자기, F로 꾸미기 모드, 아래 문으로 나가기.
#
# 방 배치는 집 단계를 따라간다. 처음 집(1단계)은 할아버지가 살던 좁은
# 오두막 — 낡은 침대·낡은 책상·먼지더미(조리대가 묻혀 있다)뿐이다.
# 확장(2단계)하면 방이 넓어지고 조합대·가구 꾸미기가 생긴다.
extends CanvasLayer

var ROOM := Rect2(120, 75, 720, 390)  # 방 전체 (벽 포함)
var FLOOR_TOP := 156.0                # 벽 아래부터 바닥
var BED := Rect2(156, 162, 69, 99)
var DESK := Rect2(597, 288, 105, 48)   # 제작대 — 오른쪽 아랫벽 쪽
var KITCHEN := Rect2(600, 117, 93, 39)  # 조리대 (윗벽에 붙박이)
# 연금술 조합대 (윗벽, 조리대 반대편). 확장 전에는 없다.
var ALCHEMY := Rect2(345, 117, 108, 39)
var EXIT_X := Vector2(408, 552)       # 아랫벽 문 구간
var WINDOWS: Array = [270.0, 690.0]   # 창문 x 자리
const GRID := 12.0                      # 꾸미기 배치 격자


# 집 단계에 맞춰 방 크기와 붙박이 자리를 정한다
func _layout() -> void:
	if GameData.house_lv >= 2:
		ROOM = Rect2(120, 75, 720, 390)
		FLOOR_TOP = 156.0
		BED = Rect2(156, 162, 69, 99)
		DESK = Rect2(597, 288, 105, 48)
		KITCHEN = Rect2(600, 117, 93, 39)
		ALCHEMY = Rect2(345, 117, 108, 39)
		EXIT_X = Vector2(408, 552)
		WINDOWS = [270.0, 690.0]
	else:
		# 좁은 오두막 — 큰 방의 6할쯤. 세간이라곤 침대·책상·먼지더미뿐
		ROOM = Rect2(255, 135, 450, 300)
		FLOOR_TOP = 216.0
		BED = Rect2(285, 231, 69, 99)
		DESK = Rect2(576, 348, 105, 48)
		KITCHEN = Rect2(576, 177, 93, 39)
		ALCHEMY = Rect2(-900, -900, 108, 39)   # 화면 밖 = 없음
		EXIT_X = Vector2(432, 528)
		WINDOWS = [345.0]

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

	# 집 안에서 바로 여는 창 버튼 — 연구노트(N) · 퀘스트(Q)
	var dock := HBoxContainer.new()
	dock.position = Vector2(24, 14)
	dock.add_theme_constant_override("separation", 8)
	add_child(dock)
	for pair in [["연구노트 (%s)" % GameData.key_label("open_note"),
			func() -> void: main.note_ui.toggle()],
			["퀘스트 (%s)" % GameData.key_label("open_quest"),
			func() -> void: main.quest_ui.toggle()]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 32)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.24, 0.18, 0.12, 0.95)
		bs.border_color = Color(0.62, 0.48, 0.28)
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(4)
		bs.set_content_margin_all(7)
		var bs2: StyleBoxFlat = bs.duplicate()
		bs2.border_color = Color(1, 0.84, 0.37)
		b.add_theme_stylebox_override("normal", bs)
		b.add_theme_stylebox_override("hover", bs2)
		b.add_theme_stylebox_override("pressed", bs2)
		b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
		b.pressed.connect(func() -> void:
			Sound.play_sfx("sfx_ui")
			(pair[1] as Callable).call())
		dock.add_child(b)


func open() -> void:
	visible = true
	_layout()
	ppos = Vector2((EXIT_X.x + EXIT_X.y) / 2.0, ROOM.end.y - 12)
	pdir = "up"
	deco_mode = false
	held = {}
	Sound.play_sfx("sfx_place")
	main.story.home_entered()   # 처음 들어온 순간 메인 스토리 1이 끝난다
	canvas.queue_redraw()


func close() -> void:
	if deco_mode:
		_exit_deco()
	visible = false
	Sound.play_sfx("sfx_place")
	# 스토리: 첫 집 구경을 마치고 나오면 이장이 문 앞으로 걸어온다
	if GameData.story_phase == "greet":
		main.story.start_home_greet.call_deferred()


func _process(delta: float) -> void:
	if not visible or main.dialog.visible or main.sleep_dialog.visible \
			or main.summary.visible or main.cooking_ui.visible or main.desk_ui.visible \
			or main.inventory_ui.visible or main.quest_ui.visible or main.note_ui.visible:
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
		if v.x != 0.0:
			pdir = "right" if v.x > 0 else "left"  # 대각선 포함 옆모습
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
	if GameData.house_lv >= 2:   # 가구는 확장한 집에만 있다
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
			or main.cooking_ui.visible or main.alchemy_ui.visible \
			or main.desk_ui.visible:
		return
	if deco_mode:
		_deco_input(event)
		return
	if event.is_action_pressed("interact"):
		if (ppos - ALCHEMY.get_center()).length() < 75.0:
			main.alchemy_ui.open()
			get_viewport().set_input_as_handled()
		elif (ppos - KITCHEN.get_center()).length() < 69.0:
			# 조리대는 먼지와 잡동사니에 묻혀 있다 — 빗자루로 쓸어야 나타난다
			if GameData.kitchen_found:
				main.cooking_ui.open()
			elif int(GameData.items.get("broom", 0)) > 0:
				_sweep_kitchen()
			else:
				main.hud.show_message(
					"먼지와 잡동사니에 뭔가 묻혀 있다... 빗자루가 있으면 치울 수 있을 텐데. (잡화점에 레시피)", 4.0)
			get_viewport().set_input_as_handled()
		elif (ppos - DESK.get_center()).length() < 78.0:
			main.desk_ui.open()
			get_viewport().set_input_as_handled()
		elif _near_trash_bin():
			# 집 안 쓰레기통 — 24시간 무인 판매 (제값의 80%)
			main.shop.open("sell", ["sell"], "쓰레기통 — 무인 판매", "",
				GameData.TRASH_SELL_MULT)
			get_viewport().set_input_as_handled()
		elif (ppos - BED.get_center()).length() < 82.0:
			if GameData.has_bed:
				main.daycycle.request_sleep()
			else:
				# 침대는 직접 만들어야 한다
				main.dialog.open("침대 제작",
					"침대가 있어야 잠을 잘 수 있다.\n\n필요 재료: 목재 %d (보유 %d)" %
						[GameData.BED_WOOD, GameData.wood], [
					["침대 만들기", _craft_bed],
					["닫기", null],
				])
		else:
			main.hud.show_message("침대 E: 잠자기 · 책상 E: 제작 · 조리대 E: 요리 · 조합대 E: 연금술 · F: 꾸미기")
	elif event is InputEventKey and event.pressed and not event.echo \
			and _key_of(event) == KEY_F:
		if GameData.house_lv < 2:
			main.dialog.open("집 확장",
				"집을 확장하면 가구로 꾸밀 수 있다.\n\n필요 재료: 목재 %d · 석재 %d\n(보유: 목재 %d · 석재 %d)" %
					[GameData.HOUSE_UPGRADE_WOOD, GameData.HOUSE_UPGRADE_STONE,
					GameData.wood, GameData.stone], [
				["확장하기", _upgrade_house],
				["닫기", null],
			])
			return
		deco_mode = true
		cursor = (ppos / GRID).floor() * GRID
		Sound.play_sfx("sfx_ui")
	elif event.is_action_pressed("ui_cancel"):
		close()


func _craft_bed() -> void:
	if GameData.has_bed:
		return  # 이미 만든 침대
	if GameData.wood < GameData.BED_WOOD:
		main.dialog.set_body("목재가 부족하다... (%d/%d)\n도끼로 나무를 베어 목재를 모으자." %
			[GameData.wood, GameData.BED_WOOD])
		return
	GameData.wood -= GameData.BED_WOOD
	GameData.has_bed = true
	main.tutorial_notify("bed")
	Sound.play_sfx("sfx_place")
	main.dialog.set_body("낡은 침대나마 완성!\n이제 밤이 되면 잘 수 있다.\n책상(제작대)에서 더 좋은 침대를 만들 수 있다.")
	main.dialog.set_buttons([["좋아!", null]])
	main.hud.quest_toast("침대 만들기")
	main.saveio.save_now()


# 빗자루질 — 세 번 쓸면 먼지 밑에서 낡은 조리대가 나온다 (요리 해금)
func _sweep_kitchen() -> void:
	GameData.dust_swept += 1
	Sound.play_sfx("sfx_hoe")
	canvas.queue_redraw()
	if GameData.dust_swept < GameData.DUST_TOTAL:
		main.hud.show_message("빗자루로 먼지를 쓸어 냈다... (%d/%d)"
			% [GameData.dust_swept, GameData.DUST_TOTAL])
		return
	GameData.kitchen_found = true
	main.dialog.open("낡은 조리대 발견!",
		"먼지 밑에서 할아버지가 쓰시던 낡은 조리대가 나왔다!\n"
		+ "화구도 냄비도 그대로다... 닦으면 쓸 수 있겠다.\n\n[요리 해금] 조리대 앞에서 E", [
		["좋아!", null],
	])
	main.hud.quest_toast("낡은 조리대 발견")
	main.saveio.save_now()


func _upgrade_house() -> void:
	if GameData.house_lv >= 2:
		return  # 이미 확장한 집
	if GameData.wood < GameData.HOUSE_UPGRADE_WOOD \
			or GameData.stone < GameData.HOUSE_UPGRADE_STONE:
		main.dialog.set_body("재료가 부족하다...\n(보유: 목재 %d/%d · 석재 %d/%d)" %
			[GameData.wood, GameData.HOUSE_UPGRADE_WOOD,
			GameData.stone, GameData.HOUSE_UPGRADE_STONE])
		return
	GameData.wood -= GameData.HOUSE_UPGRADE_WOOD
	GameData.stone -= GameData.HOUSE_UPGRADE_STONE
	GameData.house_lv = 2
	# 확장 기념 기본 세간 — 오두막에서 만들어 둔 세간(화분·쓰레기통)은 그대로 둔다
	if GameData.furniture.all(func(f: Dictionary) -> bool:
			return str(f.get("id", "")) in GameData.CRAFT_FURN):
		GameData.furniture = GameData.default_furniture() + GameData.furniture
	_layout()
	canvas.queue_redraw()
	Sound.play_sfx("sfx_place")
	main.dialog.set_body("집 확장 완료!\n방이 넓어지고, 연금술 조합대와 가구 꾸미기(F)가 생겼다.")
	main.dialog.set_buttons([["좋아!", null]])
	main.hud.quest_toast("집 확장")
	main.saveio.save_now()


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
		main.doing.sync_furniture(delta)
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
	main.doing.sync_furniture(delta)


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
	main.doing.sync_furniture(0)


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
			tex_name = GameData.player_down_tex(moving, suffix, anim_time)
		"up":
			tex_name = GameData.player_up_tex(moving, suffix, anim_time)
		_:
			tex_name = GameData.player_side_tex(moving, suffix, anim_time)
			player_sprite.flip_h = pdir == "left"
	player_sprite.texture = main.tex[tex_name]
	# 원본 128x192에 발바닥이 y=190. 0.5배로 그리니 발이 ppos에 오도록 맞춘다
	# (예전 값은 몸통을 ppos에 두어 발이 방 밖으로 삐져나왔다)
	player_sprite.position = ppos + Vector2(-32, -95)
	player_sprite.modulate.a = 0.4 if deco_mode else 1.0


func _draw_room() -> void:
	# 벽
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, FLOOR_TOP - ROOM.position.y)),
		Color(0.42, 0.29, 0.19))
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, 8)), Color(0.3, 0.2, 0.13))
	# 창문 (밖의 하늘) — 좁은 집은 하나뿐이다
	var wy := ROOM.position.y + 24.0
	for wx: float in WINDOWS:
		canvas.draw_rect(Rect2(wx, wy, 60, 39), Color(0.25, 0.17, 0.11))
		canvas.draw_rect(Rect2(wx + 3, wy + 3, 54, 33),
			Color(0.55, 0.75, 0.95) if GameData.minutes < 18 * 60 else Color(0.13, 0.12, 0.3))
		canvas.draw_rect(Rect2(wx + 28, wy + 3, 3, 33), Color(0.25, 0.17, 0.11))

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

	# 제작대 — 유저가 그린 책상 도트(desk.png). 밑변을 DESK 칸 바닥선에 맞춘다
	var desk_tex: Texture2D = main.tex["desk"]
	var desk_h := DESK.size.x * desk_tex.get_height() / float(desk_tex.get_width())
	var desk_y := DESK.end.y - desk_h
	canvas.draw_texture_rect(desk_tex,
		Rect2(DESK.position.x, desk_y, DESK.size.x, desk_h), false)
	# 위에 놓인 것들: 망치는 늘, 톱은 1단계부터, 등불은 2단계부터
	canvas.draw_rect(Rect2(DESK.position.x + 22, desk_y + 6, 6, 14), Color(0.35, 0.35, 0.4))
	canvas.draw_rect(Rect2(DESK.position.x + 18, desk_y + 4, 14, 6), Color(0.5, 0.5, 0.56))
	if GameData.desk_lv >= 1:
		canvas.draw_rect(Rect2(DESK.position.x + 48, desk_y + 12, 26, 4), Color(0.72, 0.72, 0.78))
		canvas.draw_rect(Rect2(DESK.position.x + 44, desk_y + 10, 6, 10), Color(0.45, 0.3, 0.18))
	if GameData.desk_lv >= 2:
		canvas.draw_rect(Rect2(DESK.end.x - 30, desk_y + 4, 10, 16), Color(0.9, 0.75, 0.4))
	# 만드는 중이면 위에 진행 막대가 뜬다
	if not GameData.desk_queue.is_empty():
		var j: Dictionary = GameData.desk_queue[0]
		var frac := 1.0 - float(j.left) / GameData.desk_time()
		canvas.draw_rect(Rect2(DESK.position.x, DESK.position.y - 10, DESK.size.x, 6),
			Color(0.2, 0.16, 0.1))
		canvas.draw_rect(Rect2(DESK.position.x, DESK.position.y - 10, DESK.size.x * clampf(frac, 0.0, 1.0), 6),
			Color(0.55, 0.85, 0.45))

	# 연금술 조합대 — 확장한 집에만 있다
	if GameData.house_lv >= 2:
		_draw_alchemy()

	_draw_kitchen()
	_draw_bed()

	# 배치된 가구 (확장한 집에만 — 러그 같은 비충돌 가구 먼저, 그 위에 솔리드)
	if GameData.house_lv >= 2:
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

	# 밤에는 집 안도 대체로 어둡다 — 바깥과 같은 시각 곡선으로 어두워진다
	var night_a := clampf((GameData.minutes - 18.0 * 60.0) / (6.0 * 60.0), 0.0, 1.0)
	if night_a > 0.0:
		canvas.draw_rect(Rect2(ROOM.position.x, ROOM.position.y - 60,
			ROOM.size.x, ROOM.size.y + 60), Color(0.04, 0.04, 0.09, night_a * 0.62))

	if deco_mode:
		_draw_deco_ui()
	else:
		var guide := "E: 잠자기/요리/연금술 · F: 꾸미기 · 아랫문: 나가기"
		if not GameData.has_bed:
			guide = "침대 자리 E: 침대 만들기 · 아랫문: 나가기"
		elif GameData.house_lv < 2:
			guide = "침대 E: 잠자기 · 책상 E: 제작 · F: 집 확장 · 아랫문: 나가기"
		_draw_center_text(guide, 72)


func _draw_alchemy() -> void:
	canvas.draw_rect(ALCHEMY, Color(0.34, 0.28, 0.42))
	canvas.draw_rect(Rect2(ALCHEMY.position, Vector2(ALCHEMY.size.x, 6)),
		Color(0.5, 0.44, 0.62))
	# 증류기(가운데) + 양옆 플라스크 세 병
	canvas.draw_rect(Rect2(ALCHEMY.position.x + 46, ALCHEMY.position.y - 16, 16, 17),
		Color(0.72, 0.76, 0.8))
	canvas.draw_rect(Rect2(ALCHEMY.position.x + 49, ALCHEMY.position.y - 8, 10, 8),
		Color(0.55, 0.35, 0.7))
	canvas.draw_rect(Rect2(ALCHEMY.position.x + 51, ALCHEMY.position.y - 22, 6, 6),
		Color(0.62, 0.66, 0.72))
	var vials := [Color(0.9, 0.4, 0.38), Color(0.4, 0.75, 0.5), Color(0.45, 0.65, 0.95)]
	for i in 3:
		var vx: float = ALCHEMY.position.x + 10.0 + i * 14.0
		canvas.draw_rect(Rect2(vx, ALCHEMY.position.y - 11, 7, 12), Color(0.78, 0.82, 0.86))
		canvas.draw_rect(Rect2(vx, ALCHEMY.position.y - 5, 7, 6), vials[i])
	# 펼쳐 둔 노트
	canvas.draw_rect(Rect2(ALCHEMY.end.x - 26, ALCHEMY.position.y + 1, 20, 5),
		Color(0.9, 0.86, 0.72))
	canvas.draw_rect(Rect2(ALCHEMY.end.x - 17, ALCHEMY.position.y + 1, 1, 5),
		Color(0.6, 0.5, 0.36))


# 주방 조리대 (고정). 발견 전에는 먼지와 잡동사니 더미로 덮여 있다 —
# 빗자루로 쓸 때마다(dust_swept) 한 겹씩 걷힌다.
func _draw_kitchen() -> void:
	if not GameData.kitchen_found:
		var left := GameData.DUST_TOTAL - GameData.dust_swept
		# 바탕: 뭔가 있긴 한 실루엣
		canvas.draw_rect(KITCHEN, Color(0.4, 0.33, 0.26))
		# 잡동사니 (남은 만큼): 상자·항아리·천 덮개
		if left >= 3:
			canvas.draw_rect(Rect2(KITCHEN.position.x + 6, KITCHEN.position.y - 10,
				26, 28), Color(0.5, 0.4, 0.28))
			canvas.draw_rect(Rect2(KITCHEN.position.x + 10, KITCHEN.position.y - 6,
				18, 3), Color(0.38, 0.3, 0.2))
		if left >= 2:
			canvas.draw_rect(Rect2(KITCHEN.position.x + 40, KITCHEN.position.y - 4,
				22, 22), Color(0.62, 0.58, 0.5))
			canvas.draw_rect(Rect2(KITCHEN.position.x + 44, KITCHEN.position.y - 8,
				14, 6), Color(0.55, 0.5, 0.42))
		if left >= 1:
			canvas.draw_rect(Rect2(KITCHEN.end.x - 26, KITCHEN.position.y + 2,
				20, 16), Color(0.58, 0.52, 0.44))
		# 먼지 얼룩
		for i in range(maxi(left * 2, 1)):
			canvas.draw_rect(Rect2(KITCHEN.position.x + 4 + i * 17,
				KITCHEN.end.y - 6 + (i % 2) * 3, 12, 4), Color(0.55, 0.5, 0.44, 0.5))
	elif main.tex.has("kitchen_counter"):
		# 발견한 낡은 조리대 — 올려 준 손그림 (벽 소품까지 한 장이다).
		# 밑변을 조리대 칸 바닥에 맞추고, 벽 높이에 맞춰 비율대로 줄인다.
		var t: Texture2D = main.tex["kitchen_counter"]
		var h := (KITCHEN.end.y + 8.0) - (ROOM.position.y + 10.0)
		var w := h * float(t.get_width()) / float(t.get_height())
		canvas.draw_texture_rect(t, Rect2(
			KITCHEN.get_center().x - w / 2.0, KITCHEN.end.y + 8.0 - h, w, h), false)
	else:
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


# 침대 (직접 만들어야 생긴다 — 만들기 전에는 빈 자리 표시)
func _draw_bed() -> void:
	if GameData.has_bed and GameData.bed_lv == 0 and main.tex.has("bed_old"):
		# 할아버지가 쓰던 낡은 침대 — 올려 준 손그림 (비율 유지, 칸 중심에)
		var t: Texture2D = main.tex["bed_old"]
		var r := BED.grow(10)
		var s := minf(r.size.x / t.get_width(), r.size.y / t.get_height())
		var sz := Vector2(t.get_width(), t.get_height()) * s
		canvas.draw_texture_rect(t, Rect2(r.get_center() - sz / 2.0, sz), false)
	elif GameData.has_bed:
		canvas.draw_rect(BED.grow(2), Color(0.35, 0.23, 0.14))
		canvas.draw_rect(BED, Color(0.75, 0.3, 0.28))
		canvas.draw_rect(Rect2(BED.position.x + 3, BED.position.y + 3, BED.size.x - 6, 16),
			Color(0.92, 0.9, 0.85))
		canvas.draw_rect(Rect2(BED.position.x, BED.position.y + 24, BED.size.x, 4),
			Color(0.6, 0.22, 0.2))
	else:
		canvas.draw_rect(BED, Color(0.5, 0.42, 0.3, 0.35))
		canvas.draw_rect(BED, Color(0.45, 0.35, 0.22, 0.8), false, 2.0)


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
		"heart_rug":
			# 노점 퀘스트 보상 — 연분홍 러그에 큰 하트
			canvas.draw_rect(Rect2(p, Vector2(w, h)), Color(0.93, 0.78, 0.8))
			canvas.draw_rect(Rect2(p + Vector2(4, 4), Vector2(w - 8, h - 8)), Color(0.97, 0.86, 0.87))
			var hc := Color(0.89, 0.42, 0.5)
			var cx := p.x + w / 2.0
			var cy := p.y + h / 2.0
			canvas.draw_rect(Rect2(cx - 18, cy - 12, 15, 12), hc)   # 왼쪽 봉우리
			canvas.draw_rect(Rect2(cx + 3, cy - 12, 15, 12), hc)    # 오른쪽 봉우리
			canvas.draw_rect(Rect2(cx - 21, cy - 6, 42, 10), hc)    # 몸통
			canvas.draw_rect(Rect2(cx - 15, cy + 4, 30, 7), hc)
			canvas.draw_rect(Rect2(cx - 8, cy + 11, 16, 5), hc)
			canvas.draw_rect(Rect2(cx - 3, cy + 16, 6, 3), hc)      # 뾰족한 끝
			canvas.draw_rect(Rect2(cx - 14, cy - 9, 6, 5), Color(0.98, 0.68, 0.74))
		"trash_bin":
			# 제작대에서 만드는 쓰레기통 — 통(회청색) + 금속 고리 두 줄 + 뚜껑
			canvas.draw_rect(Rect2(p.x + 2, p.y + 6, w - 4, h - 6), Color(0.44, 0.5, 0.54))
			canvas.draw_rect(Rect2(p.x + 4, p.y + 8, 4, h - 10), Color(0.58, 0.64, 0.68))
			canvas.draw_rect(Rect2(p.x + 1, p.y + 11, w - 2, 3), Color(0.3, 0.34, 0.38))
			canvas.draw_rect(Rect2(p.x + 1, p.y + h - 9, w - 2, 3), Color(0.3, 0.34, 0.38))
			canvas.draw_rect(Rect2(p.x, p.y + 3, w, 5), Color(0.36, 0.42, 0.46))
			canvas.draw_rect(Rect2(p.x + w / 2.0 - 4, p.y, 8, 4), Color(0.3, 0.34, 0.38))


# 세간으로 들여놓은 쓰레기통 곁에 서 있는가 (E: 무인 판매)
func _near_trash_bin() -> bool:
	for f in GameData.furniture:
		if str(f.get("id", "")) != "trash_bin":
			continue
		if (ppos - Vector2(float(f.x) + 12.0, float(f.y) + 16.0)).length() < 60.0:
			return true
	return false
