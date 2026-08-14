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
const COUNTER := Rect2(276, 252, 408, 54)  # 주인이 뒤에 설 자리를 벽 아래에 남긴다
const EXIT_X := Vector2(432, 528)        # 아랫벽 문 구간

# 잡화점(마트)만의 배치: 물건은 한가운데 네 선반에서 산다.
# 계산대는 오른쪽으로 밀려나고, 민지에게는 「판매」만 한다.
# [카테고리, 표시 이름, 선반 왼쪽 x]
const SHELVES := [
	["seed", "씨앗", 168.0],
	["life", "생활용품", 300.0],
	["tool", "도구", 432.0],
	["misc", "기타", 564.0],
]
const SHELF_Y := 208.0                   # 선반 윗변
const SHELF_W := 104.0
const SHELF_H := 58.0
const GENERAL_COUNTER := Rect2(688, 336, 124, 50)

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
		"tab": "upgrade", "tabs": ["upgrade", "craft"],
		"hint": "도구를 강화하고 장비를 만든다.",
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
	# ---- 거래 창 대신 제 나름의 기능을 가진 방들 ----
	"inn": {
		"name": "여관", "keeper": "chief",
		"wall": Color(0.44, 0.3, 0.3), "floor": Color(0.6, 0.44, 0.38),
		"counter": Color(0.48, 0.32, 0.28), "deco": "beds",
		"tab": "", "tabs": [], "action": "rest",
		"hint": "한숨 돌리고 간다 (100G, 체력 회복)",
	},
	"lab": {
		"name": "연구소", "keeper": "merchant",
		"wall": Color(0.28, 0.34, 0.4), "floor": Color(0.46, 0.54, 0.58),
		"counter": Color(0.3, 0.4, 0.46), "deco": "lab",
		"tab": "", "tabs": [], "action": "breed",
		"hint": "씨앗을 개량한다 (작물이 더 빨리·비싸게)",
	},
	"library": {
		"name": "도서관", "keeper": "librarian",
		"wall": Color(0.4, 0.34, 0.24), "floor": Color(0.58, 0.5, 0.36),
		"counter": Color(0.44, 0.34, 0.22), "deco": "books",
		"tab": "", "tabs": [], "action": "read",
		"hint": "할아버지의 연구를 뒤쫓는다 (다음 전설 재료 힌트)",
	},
	"hall": {
		"name": "마을회관", "keeper": "chief",
		"wall": Color(0.42, 0.35, 0.26), "floor": Color(0.62, 0.54, 0.42),
		"counter": Color(0.46, 0.36, 0.26), "deco": "town",
		"tab": "", "tabs": [], "action": "hall",
		"hint": "주민 명부와 마을 살림을 본다",
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
	if id == "general":
		main.hud.show_message("선반 앞에서 E: 구매 · 계산대(민지)에서 E: 판매", 4.0)
	else:
		main.hud.show_message("%s — 계산대 앞에서 E" % ROOMS[id].name, 3.0)
	canvas.queue_redraw()


func close() -> void:
	visible = false
	room_id = ""
	Sound.play_sfx("sfx_place")


func _def() -> Dictionary:
	return ROOMS.get(room_id, ROOMS.general)


# 잡화점은 계산대가 오른쪽 아래로 밀려나 있다 (가운데는 선반 차지)
func _counter() -> Rect2:
	return GENERAL_COUNTER if room_id == "general" else COUNTER


func _shelf_rect(i: int) -> Rect2:
	return Rect2(float(SHELVES[i][2]), SHELF_Y, SHELF_W, SHELF_H)


# 플레이어가 어느 선반 앞에 서 있는가 (-1 = 없음)
func _shelf_near() -> int:
	if room_id != "general":
		return -1
	for i in SHELVES.size():
		var r := _shelf_rect(i)
		if ppos.y > r.end.y - 6.0 and ppos.y < r.end.y + 52.0 \
				and ppos.x > r.position.x - 14.0 and ppos.x < r.end.x + 14.0:
			return i
	return -1


func _process(delta: float) -> void:
	if not visible or main.dialog.visible or main.shop.visible \
			or main.inventory_ui.visible:
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
		var feet := Rect2(np.x - 8, np.y - 6, 16, 8)
		var blocked := feet.intersects(_counter())
		if room_id == "general":
			for i in SHELVES.size():
				if feet.intersects(_shelf_rect(i)):
					blocked = true
					break
		if not blocked:
			ppos = np
		anim_time += delta
		# 아랫문으로 나가기
		if ppos.y >= ROOM.end.y - 9 and ppos.x > EXIT_X.x and ppos.x < EXIT_X.y and v.y > 0:
			close()
	_update_sprite()
	canvas.queue_redraw()


func _at_counter() -> bool:
	var c := _counter()
	if absf(ppos.y - c.end.y) < 46.0 \
			and ppos.x > c.position.x - 20.0 and ppos.x < c.end.x + 20.0:
		return true
	# 주인(계산대 뒤에 서 있는 사람) 곁이어도 말이 걸린다 —
	# 계산대 띠에서 살짝 벗어나 서면 E가 조용히 씹히던 버그 수정
	var keeper := Vector2(c.get_center().x, c.position.y)
	return (ppos - keeper).length() < 110.0


# 계산대/주인/선반과의 상호작용 한 줄 — E와 마우스 클릭이 같이 쓴다
func _try_interact() -> bool:
	var si := _shelf_near()
	if si >= 0:
		# 선반에서 산다 — 그 카테고리의 물건만 진열된다
		main.shop.open("buy", ["buy"],
			"잡화점 — %s" % str(SHELVES[si][1]), str(SHELVES[si][0]))
		return true
	if _at_counter():
		var d := _def()
		if str(d.get("action", "")) != "":
			main.room_action(str(d.action))   # 여관·연구소·도서관
		elif room_id == "general":
			# 민지에게 말을 걸면 인사말 + 선택지 메뉴 (판매/대화/퀘스트)
			main.village.open_merchant_counter()
		elif str(d.tab) == "":
			main.hud.show_message(str(d.hint), 4.0)
		else:
			main.shop.open(str(d.tab), d.tabs, str(d.name))
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or main.dialog.visible or main.shop.visible \
			or main.inventory_ui.visible:
		return
	if event.is_action_pressed("interact"):
		if not _try_interact():
			main.hud.show_message("선반 앞에서 E: 구매 · 계산대(주인)에게 다가가 E: 대화", 3.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# 주인이나 계산대·선반을 클릭해도 말이 걸린다
		var mp: Vector2 = event.position
		var c := _counter()
		var keeper_r := Rect2(c.get_center().x - 40, c.position.y - 108, 80, 110)
		if keeper_r.has_point(mp) or c.grow(24).has_point(mp):
			if (ppos - Vector2(c.get_center().x, c.end.y)).length() < 190.0:
				_try_interact()
			else:
				main.hud.show_message("좀 더 가까이 가서 말을 걸자.", 3.0)
			get_viewport().set_input_as_handled()
		else:
			for i in SHELVES.size():
				if _shelf_rect(i).grow(14).has_point(mp):
					if _shelf_near() == i:
						_try_interact()
					else:
						main.hud.show_message("선반 앞으로 다가가서 E!", 3.0)
					get_viewport().set_input_as_handled()
					break
	elif event.is_action_pressed("ui_cancel"):
		# ESC로 가게 밖으로 튕겨 나가지 않게 — 게임 메뉴만 띄운다.
		# 밖으로 나가는 길은 아랫문뿐이다.
		Sound.play_sfx("sfx_ui")
		main.dialog.open("게임 메뉴", "타이틀 화면으로 돌아갈까?\n(진행 상황은 자동 저장된다)", [
			["저장 후 타이틀로", main._back_to_title],
			["계속하기", null],
		])
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
	# 원본은 128x192에 발바닥이 y=190. 0.5배로 그리니 발이 ppos에 오도록 맞춘다
	# (예전 값은 몸통을 ppos에 두어 발이 방 밖으로 삐져나왔다)
	player_sprite.position = ppos + Vector2(-32, -95)


func _draw_room() -> void:
	var d := _def()
	var wall: Color = d.wall
	var f: Font = main.UI_FONT

	# ---- 벽 ----
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, FLOOR_TOP - ROOM.position.y)),
		wall)
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, 10)), wall.darkened(0.4))
	# 벽 아래 굽도리 — 벽과 바닥의 경계를 또렷하게
	canvas.draw_rect(Rect2(ROOM.position.x, FLOOR_TOP - 12, ROOM.size.x, 12),
		wall.darkened(0.22))
	canvas.draw_rect(Rect2(ROOM.position.x, FLOOR_TOP - 12, ROOM.size.x, 3),
		wall.lightened(0.18))

	# 창문 두 개 (좌우 대칭)
	for wx in [ROOM.position.x + 74.0, ROOM.end.x - 194.0]:
		var wr := Rect2(wx, 96, 120, 40)
		canvas.draw_rect(wr.grow(4), wall.darkened(0.45))
		canvas.draw_rect(wr, Color(0.55, 0.72, 0.85))
		canvas.draw_rect(Rect2(wr.position, Vector2(wr.size.x, 12)), Color(0.68, 0.82, 0.92))
		canvas.draw_rect(Rect2(wr.get_center().x - 2, wr.position.y, 4, wr.size.y),
			wall.darkened(0.4))
		canvas.draw_rect(Rect2(wr.position.x, wr.get_center().y - 2, wr.size.x, 4),
			wall.darkened(0.4))

	# 가운데 간판 (주인은 그 아래 계산대 뒤에 선다)
	# 잡화점(마트)은 간판을 뗐다 — 선반 팻말이 그 역할을 한다
	if room_id != "general":
		var sign_rect := Rect2(360, 88, 240, 48)
		canvas.draw_rect(sign_rect.grow(3), Color(0.16, 0.11, 0.07))
		canvas.draw_rect(sign_rect, wall.darkened(0.42))
		canvas.draw_rect(sign_rect.grow(-5), wall.lightened(0.22))
		var tw: float = f.get_string_size(str(d.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		canvas.draw_string(f, Vector2(sign_rect.get_center().x - tw / 2.0, 122),
			str(d.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.6))

	# ---- 바닥 ----
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
	# 벽 그림자 (바닥 위쪽을 살짝 어둡게 — 실내 느낌)
	canvas.draw_rect(Rect2(ROOM.position.x, FLOOR_TOP, ROOM.size.x, 14),
		Color(0, 0, 0, 0.16))

	var C := _counter()
	# 계산대 앞 깔개 — 손님이 서는 자리를 알려 준다
	var rug := Rect2(348, 320, 264, 96) if room_id != "general" \
		else Rect2(C.position.x - 16, C.end.y + 10, C.size.x + 32, 52)
	canvas.draw_rect(rug, Color(0.62, 0.26, 0.24, 0.55))
	canvas.draw_rect(rug.grow(-8), Color(0.75, 0.38, 0.32, 0.5))
	canvas.draw_rect(rug, Color(0.35, 0.16, 0.14, 0.5), false, 2.0)

	_draw_deco(str(d.deco), wall)
	if room_id == "general":
		_draw_shelves()

	# ---- 계산대 ----
	canvas.draw_rect(Rect2(C.position.x, C.end.y, C.size.x, 10),
		Color(0, 0, 0, 0.22))                                   # 바닥 그림자
	canvas.draw_rect(C.grow(2), Color(0.2, 0.14, 0.1))
	canvas.draw_rect(C, d.counter)
	canvas.draw_rect(Rect2(C.position, Vector2(C.size.x, 9)),
		Color(d.counter).lightened(0.32))                       # 상판 하이라이트
	for i in 6:                                                 # 앞면 판자 이음매
		var seam_x := C.position.x + 24 + i * 64
		if seam_x < C.end.x - 6:
			canvas.draw_rect(Rect2(seam_x, C.position.y + 12,
				2, C.size.y - 14), Color(d.counter).darkened(0.28))

	# ---- 주인 (계산대 뒤) ----
	var kt := "npc_%s_down_0" % str(d.keeper)
	if main.tex.has(kt):
		canvas.draw_rect(Rect2(C.get_center().x - 26, C.position.y - 8, 52, 10),
			Color(0, 0, 0, 0.2))                                # 발밑 그림자
		canvas.draw_texture_rect(main.tex[kt],
			Rect2(C.get_center().x - 32, C.position.y - 100, 64, 96), false)

	# ---- 아랫문 (문틀 + 매트) ----
	var dw: float = EXIT_X.y - EXIT_X.x
	canvas.draw_rect(Rect2(EXIT_X.x - 6, ROOM.end.y - 16, dw + 12, 16),
		Color(0.24, 0.16, 0.1))
	canvas.draw_rect(Rect2(EXIT_X.x, ROOM.end.y - 12, dw, 12), Color(0.45, 0.31, 0.18))
	canvas.draw_rect(Rect2(EXIT_X.x + 12, ROOM.end.y - 34, dw - 24, 20),
		Color(0.38, 0.3, 0.24, 0.75))                           # 현관 매트
	var ew: float = f.get_string_size("나가기 ▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	canvas.draw_string(f, Vector2((EXIT_X.x + EXIT_X.y) / 2.0 - ew / 2.0, ROOM.end.y + 20),
		"나가기 ▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.8, 0.74))

	var si := _shelf_near()
	if si >= 0:
		var sht := "E: [%s] 선반 — 물건 보기" % str(SHELVES[si][1])
		var shw: float = f.get_string_size(sht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		canvas.draw_string(f, Vector2(480 - shw / 2.0, SHELF_Y + SHELF_H + 66),
			sht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.6))
	elif _at_counter():
		var ht := "E: %s" % ("판매 — 민지에게 판다" if room_id == "general" else str(d.hint))
		var hw: float = f.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		canvas.draw_string(f, Vector2(480 - hw / 2.0, C.end.y + 40),
			ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.6))


# 잡화점 한가운데 네 선반 — 카테고리마다 다른 물건이 얹혀 있고,
# 아래에 팻말이 붙어 있다. 선반 앞에서 E를 누르면 그 칸의 진열대가 열린다.
func _draw_shelves() -> void:
	var f: Font = main.UI_FONT
	for i in SHELVES.size():
		var r := _shelf_rect(i)
		var cat: String = SHELVES[i][0]
		# 바닥 그림자 + 나무 몸통
		canvas.draw_rect(Rect2(r.position.x + 2, r.end.y, r.size.x - 4, 8),
			Color(0, 0, 0, 0.2))
		canvas.draw_rect(r.grow(2), Color(0.24, 0.16, 0.1))
		canvas.draw_rect(r, Color(0.55, 0.4, 0.24))
		canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), Color(0.68, 0.52, 0.32))
		canvas.draw_rect(Rect2(r.position.x, r.position.y + 30, r.size.x, 5),
			Color(0.4, 0.29, 0.17))
		# 얹힌 물건 — 카테고리마다 다르게
		match cat:
			"seed":
				for j in 3:
					var sx := r.position.x + 12 + j * 30.0
					canvas.draw_rect(Rect2(sx, r.position.y + 12, 18, 14), Color(0.82, 0.68, 0.4))
					canvas.draw_rect(Rect2(sx + 5, r.position.y + 8, 8, 5), Color(0.4, 0.7, 0.35))
			"life":
				canvas.draw_rect(Rect2(r.position.x + 12, r.position.y + 9, 6, 18), Color(0.6, 0.44, 0.24))
				canvas.draw_rect(Rect2(r.position.x + 9, r.position.y + 22, 12, 6), Color(0.85, 0.75, 0.5))
				canvas.draw_rect(Rect2(r.position.x + 40, r.position.y + 12, 16, 14), Color(0.7, 0.82, 0.9))
				canvas.draw_rect(Rect2(r.position.x + 70, r.position.y + 10, 14, 16), Color(0.85, 0.6, 0.5))
			"tool":
				canvas.draw_rect(Rect2(r.position.x + 12, r.position.y + 16, 22, 10), Color(0.55, 0.55, 0.6))
				canvas.draw_rect(Rect2(r.position.x + 46, r.position.y + 10, 8, 16), Color(0.72, 0.72, 0.78))
				canvas.draw_rect(Rect2(r.position.x + 68, r.position.y + 12, 20, 12), Color(0.75, 0.65, 0.45))
			_:
				canvas.draw_rect(Rect2(r.position.x + 14, r.position.y + 10, 12, 16), Color(0.9, 0.55, 0.6))
				canvas.draw_rect(Rect2(r.position.x + 44, r.position.y + 14, 18, 12), Color(0.6, 0.7, 0.85))
		# 팻말 (카테고리 이름)
		var label: String = "[%s]" % SHELVES[i][1]
		var lw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var plate := Rect2(r.get_center().x - lw / 2.0 - 6, r.end.y + 10, lw + 12, 22)
		canvas.draw_rect(plate, Color(0.28, 0.19, 0.11))
		canvas.draw_rect(plate.grow(-2), Color(0.8, 0.68, 0.45))
		canvas.draw_string(f, Vector2(plate.position.x + 6, plate.end.y - 6),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.25, 0.15, 0.06))


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
			for i in 2:
				var cx := 152.0 + i * 60.0
				canvas.draw_rect(Rect2(cx, 320, 52, 44), Color(0.55, 0.42, 0.28))
				canvas.draw_rect(Rect2(cx + 4, 312, 44, 12), Color(0.7, 0.85, 0.95))
			canvas.draw_rect(Rect2(716, 320, 92, 48), Color(0.55, 0.42, 0.28))
		"mail":
			for i in 4:
				for j in 3:
					canvas.draw_rect(Rect2(150 + i * 26, 176 + j * 26, 22, 22),
						wall.darkened(0.25))
			canvas.draw_rect(Rect2(716, 250, 90, 60), Color(0.45, 0.36, 0.55))
			canvas.draw_rect(Rect2(726, 240, 70, 14), Color(0.9, 0.88, 0.84))
		"beds":
			# 여관: 침대 두 개 + 협탁
			for i in 2:
				var by := 176.0 + i * 84.0
				canvas.draw_rect(Rect2(148, by, 104, 62), Color(0.5, 0.36, 0.26))
				canvas.draw_rect(Rect2(148, by, 104, 20), Color(0.92, 0.9, 0.86))
				canvas.draw_rect(Rect2(148, by + 20, 104, 42), Color(0.72, 0.32, 0.3))
				canvas.draw_rect(Rect2(258, by + 26, 26, 26), Color(0.42, 0.3, 0.22))
			canvas.draw_rect(Rect2(716, 320, 92, 48), Color(0.5, 0.36, 0.26))
		"lab":
			# 연구소: 실험대 + 플라스크 + 씨앗 선반
			canvas.draw_rect(Rect2(148, 300, 132, 56), Color(0.34, 0.4, 0.44))
			for i in 3:
				var fx := 158.0 + i * 42.0
				canvas.draw_rect(Rect2(fx + 8, 272, 10, 14), Color(0.8, 0.9, 0.95))
				canvas.draw_rect(Rect2(fx, 286, 26, 16), Color(0.5, 0.86, 0.6))
			canvas.draw_rect(Rect2(716, 300, 92, 12), Color(0.34, 0.4, 0.44))
			canvas.draw_rect(Rect2(716, 340, 92, 12), Color(0.34, 0.4, 0.44))
			for i in 3:
				canvas.draw_rect(Rect2(722 + i * 28, 284, 20, 16), Color(0.7, 0.6, 0.35))
		"town":
			# 마을회관: 마을 게시판 + 교진 마을 깃발 + 서류장
			canvas.draw_rect(Rect2(148, 176, 124, 74), Color(0.3, 0.21, 0.13))   # 게시판 틀
			canvas.draw_rect(Rect2(154, 182, 112, 62), Color(0.78, 0.68, 0.48))
			for i in 3:
				canvas.draw_rect(Rect2(161 + i * 36, 190, 28, 20),
					Color(0.95, 0.92, 0.84))                                     # 붙은 공지들
				canvas.draw_rect(Rect2(161 + i * 36, 216, 28, 20),
					Color(0.9, 0.86, 0.76))
			canvas.draw_rect(Rect2(788, 176, 8, 96), Color(0.45, 0.32, 0.18))    # 깃대
			canvas.draw_rect(Rect2(724, 182, 64, 36), Color(0.72, 0.3, 0.28))    # 마을 깃발
			canvas.draw_rect(Rect2(724, 194, 64, 5), Color(0.9, 0.82, 0.55))
			for i in 2:                                                          # 서류장
				canvas.draw_rect(Rect2(700 + i * 54, 300, 46, 58), Color(0.42, 0.31, 0.2))
				for j in 3:
					canvas.draw_rect(Rect2(704 + i * 54, 306 + j * 18, 38, 12),
						Color(0.58, 0.46, 0.3))
		"books":
			# 도서관: 책장 두 벌 (책등 색을 섞는다)
			var spine := [Color(0.7, 0.3, 0.28), Color(0.32, 0.44, 0.62),
				Color(0.4, 0.56, 0.36), Color(0.66, 0.54, 0.28)]
			for side in [148.0, 700.0]:
				for r in 3:
					var sy := 262.0 + r * 40.0
					canvas.draw_rect(Rect2(side, sy + 26, 116, 8), wall.darkened(0.35))
					for i in 9:
						canvas.draw_rect(Rect2(side + 4 + i * 12, sy, 9, 26),
							spine[(i + r) % spine.size()])
