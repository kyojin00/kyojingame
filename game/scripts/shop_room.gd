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
# 계산대는 오른쪽으로 밀려나고, 만수에게는 「판매」만 한다.
# [카테고리, 표시 이름, 선반 왼쪽 x]
const SHELVES := [
	["seed", "씨앗", 168.0],
	["life", "생활용품", 300.0],
	["recipe", "레시피", 432.0],
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
		"tab": "", "tabs": [], "action": "mail",
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
	_visit_spent = GameData.today_spent   # 이번 방문의 구매 여부 기준점
	_kicked = false
	# 안내는 **방 안에 적는다.** 예전에는 머리 위 말풍선으로 띄웠는데,
	# 가게 안에서는 주인공이 화면에 없어 말풍선이 한가운데 붙박이처럼
	# 떠 있었다 (「사라지지 않는 말풍선」 버그의 정체)
	main.hud.hide_bubble()
	var ek := GameData.key_label("interact")
	notice = "선반 앞에서 %s: 구매 · 계산대에서 %s: 판매" % [ek, ek] if id == "general" \
		else "%s — 계산대 앞에서 %s" % [ROOMS[id].name, ek]
	notice_t = 4.5
	canvas.queue_redraw()


# ---- 영업시간 ----
#
# 문 닫을 시각(저녁 6시)이 되면 주인이 손님을 내보낸다.
# 가게 안에서 시간을 흘려보내도 반드시 밖으로 나가게 된다.
var _kicked := false
var notice := ""
var notice_t := 0.0


func closed_text(why: String) -> String:
	match why:
		"early":
			return "아직 문을 열지 않았다.\n안에서 준비하는 기척만 들린다."
		"lunch":
			return "「점심 먹으러 갔습니다」\n문에 작은 팻말이 걸려 있다."
		"late":
			return "오늘 영업은 끝났다.\n창문의 불도 꺼져 있다."
	return ""


func _closing_tick(delta: float) -> void:
	if notice_t > 0.0:
		notice_t -= delta
		if notice_t <= 0.0:
			notice = ""
			canvas.queue_redraw()
	if not visible or _kicked or room_id == "":
		return
	if GameData.hour_now() < GameData.CLOSE_HOUR:
		return
	_kicked = true
	_closing_kick()


# 「이제 문 닫을 시간이니까 내일 다시 와~」 — 말하고 밖으로 내보낸다
func _closing_kick() -> void:
	var keeper := str(_def().get("keeper", ""))
	var kname := "주인"
	var portrait: Texture2D = null
	if GameData.NPCS.has(keeper):
		kname = str(GameData.NPCS[keeper].name)
		portrait = main.tex.get("npc_%s_portrait_happy" % keeper)
	main.dialog.open_seq(kname, portrait, [
		{"text": "「아이고, 벌써 여섯 시네.」"},
		{"text": "「이제 문 닫을 시간이니까 내일 다시 와~」"},
	], _leave_after_close)


func _leave_after_close() -> void:
	close()
	# 문밖으로 한 발 밀려난다 (문턱에 붙어 서서 다시 들어가지 않게)
	if main.player != null:
		main.player.position.y += float(main.TILE)
	main.hud.event_toast("문을 닫았다 — 내일 다시 오자")


# 이번 방문에 실제로 무언가를 샀는가 (분기 B와 C를 가른다).
# 판매는 세지 않는다 — today_spent는 구매에서만 오른다.
var _visit_spent := 0
var bought_this_visit: bool:
	get: return GameData.today_spent > _visit_spent


# 문턱을 밟았다 — 언제든 그냥 나갈 수 있다.
# (예전에는 조리대 이야기가 여기서 불쑥 시작돼 손님을 붙잡았다.
#  지금 그 이야기는 계산대에서 만수와 말을 걸 때만 시작된다)
func try_leave() -> bool:
	close()
	return true


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
	_closing_tick(delta)          # 문 닫을 시각이면 손님을 내보낸다
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
		# 아랫문으로 나가기.
		# 【분기 B·C】 잡화점을 나서려는 순간, 아직 조리대를 못 찾았다면
		# 만수가 밥 이야기를 꺼내며 붙잡는다 (뭘 샀는지에 따라 첫마디가 다르다)
		if ppos.y >= ROOM.end.y - 9 and ppos.x > EXIT_X.x and ppos.x < EXIT_X.y and v.y > 0:
			try_leave()
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
			# 만수에게 말을 걸면 인사말 + 선택지 메뉴 (판매/대화/퀘스트)
			main.village.open_merchant_counter()
		elif str(d.tab) == "":
			main.hud.show_message(str(d.hint), 4.0)
		else:
			main.shop.open(str(d.tab), d.tabs, str(d.name))
		return true
	return false


# 가게 안 안내 — 물건은 상호작용키(E), 사람은 대화키(F)
func _room_hint() -> String:
	return "선반 앞에서 %s: 구매 · 계산대(주인)에게 다가가 %s: 대화" % [
		GameData.key_label("interact"), GameData.key_label("talk")]


func _unhandled_input(event: InputEvent) -> void:
	# 겹쳐 뜬 창(가방·퀘스트·상점...)이 있으면 그 창이 먼저다 —
	# 여기서 ESC를 가로채면 가방을 닫으려다 게임 메뉴가 뜬다
	if not visible or main.room_overlay_open():
		return
	# 가게 안에서는 대화키(F)도 같은 일을 한다 — 주인에게 말을 걸러 온 손님이
	# 계산대 앞에서 F를 눌렀는데 아무 일도 없으면 안 된다
	if event.is_action_pressed("interact") or event.is_action_pressed("talk"):
		if not _try_interact():
			main.hud.show_message(_room_hint(), 3.0)
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
						main.hud.show_message("선반 앞으로 다가가서 %s!"
							% GameData.key_label("interact"), 3.0)
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

	# ---- 벽 — 가로로 켠 널. 방마다 제 색은 유지하고 결만 같게 ----
	#
	# 한 색으로 칠한 벽은 상자 안이다 (집 안과 같은 규칙). 널 한 단마다
	# 낯빛이 조금씩 다르고, 단 사이에 골이 지고, 골 밑이 빛을 받는다
	var ly := ROOM.position.y
	var lrow := 0
	while ly < FLOOR_TOP - 12:
		var lh := minf(14.0, FLOOR_TOP - 12 - ly)
		var lt: float = (main._hash01(lrow * 7 + 3, 23) - 0.5) * 0.14
		var lc: Color = wall.lightened(lt) if lt >= 0.0 else wall.darkened(-lt)
		canvas.draw_rect(Rect2(ROOM.position.x, ly, ROOM.size.x, lh), lc)
		canvas.draw_rect(Rect2(ROOM.position.x, ly + lh - 2, ROOM.size.x, 2),
			wall.darkened(0.36))                             # 단 사이 골
		canvas.draw_rect(Rect2(ROOM.position.x, ly, ROOM.size.x, 1),
			wall.lightened(0.14))                            # 골 밑 윗변 빛
		var kx: float = ROOM.position.x + 10.0 \
			+ main._hash01(lrow * 3 + 1, 29) * (ROOM.size.x - 20.0)
		canvas.draw_rect(Rect2(kx, ly + 4, 3, 3), wall.darkened(0.4))   # 옹이
		ly += lh
		lrow += 1
	canvas.draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, 8)), wall.darkened(0.42))
	# 벽 아래 굽도리 — 벽과 바닥의 경계를 또렷하게
	canvas.draw_rect(Rect2(ROOM.position.x, FLOOR_TOP - 12, ROOM.size.x, 12),
		wall.darkened(0.22))
	canvas.draw_rect(Rect2(ROOM.position.x, FLOOR_TOP - 12, ROOM.size.x, 3),
		wall.lightened(0.18))

	# 창문 두 개 (좌우 대칭) — 틀 윗변에 빛, 밑에 창턱
	for wx in [ROOM.position.x + 74.0, ROOM.end.x - 194.0]:
		var wr := Rect2(wx, 96, 120, 40)
		canvas.draw_rect(wr.grow(4), wall.darkened(0.45))
		canvas.draw_rect(Rect2(wr.position.x - 4, wr.position.y - 4, wr.size.x + 8, 2),
			wall.lightened(0.16))                            # 틀 윗변 빛
		canvas.draw_rect(wr, Color(0.55, 0.72, 0.85))
		canvas.draw_rect(Rect2(wr.position, Vector2(wr.size.x, 12)), Color(0.68, 0.82, 0.92))
		canvas.draw_rect(Rect2(wr.get_center().x - 2, wr.position.y, 4, wr.size.y),
			wall.darkened(0.4))
		canvas.draw_rect(Rect2(wr.position.x, wr.get_center().y - 2, wr.size.x, 4),
			wall.darkened(0.4))
		canvas.draw_rect(Rect2(wr.position.x - 8, wr.end.y + 4, wr.size.x + 16, 5),
			wall.darkened(0.28))                             # 창턱
		canvas.draw_rect(Rect2(wr.position.x - 8, wr.end.y + 4, wr.size.x + 16, 1),
			wall.lightened(0.2))

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

	# ---- 바닥 — 널판. 체커보드는 게임판이지 방바닥이 아니다 ----
	var floor_c: Color = d.floor
	var y := FLOOR_TOP
	var row := 0
	while y < ROOM.end.y:
		var h := minf(14.0, ROOM.end.y - y)
		var seam := ROOM.position.x + (24.0 if row % 2 == 0 else 56.0)
		var px := ROOM.position.x
		var si := 0
		while px < ROOM.end.x:
			var nx := minf(seam + si * 64.0, ROOM.end.x)
			var ft: float = (main._hash01(row * 5 + 1, si * 7 + 2) - 0.5) * 0.12
			var fc: Color = floor_c.lightened(ft) if ft >= 0.0 else floor_c.darkened(-ft)
			canvas.draw_rect(Rect2(px, y, nx - px, h), fc)
			px = nx
			si += 1
		var s2 := seam
		while s2 < ROOM.end.x:
			canvas.draw_rect(Rect2(s2, y, 1, h), floor_c.darkened(0.26))   # 이음매
			canvas.draw_rect(Rect2(s2 - 2, y + 2, 1, 1), floor_c.darkened(0.42))  # 못
			s2 += 64.0
		canvas.draw_rect(Rect2(ROOM.position.x, y + h - 1, ROOM.size.x, 1),
			floor_c.darkened(0.15))                          # 널 사이 가는 골
		y += h
		row += 1
	# 벽이 바닥에 드리운 그늘 — 두 겹으로 부드럽게
	canvas.draw_rect(Rect2(ROOM.position.x, FLOOR_TOP, ROOM.size.x, 8),
		Color(0.08, 0.06, 0.1, 0.26))
	canvas.draw_rect(Rect2(ROOM.position.x, FLOOR_TOP + 8, ROOM.size.x, 5),
		Color(0.08, 0.06, 0.1, 0.12))

	var C := _counter()
	# 계산대 앞 깔개 — 손님이 서는 자리를 알려 준다
	var rug := Rect2(348, 320, 264, 96) if room_id != "general" \
		else Rect2(C.position.x - 16, C.end.y + 10, C.size.x + 32, 52)
	# 민무늬 사각형은 색종이다 — 테두리 띠, 직조 결, 네 귀 매듭
	canvas.draw_rect(rug, Color(0.55, 0.23, 0.21, 0.9))
	canvas.draw_rect(rug.grow(-6), Color(0.68, 0.33, 0.28, 0.9))
	var ry := rug.position.y + 12.0
	while ry < rug.end.y - 9.0:
		canvas.draw_rect(Rect2(rug.position.x + 10, ry, rug.size.x - 20, 1),
			Color(0.55, 0.23, 0.21, 0.6))
		ry += 9.0
	canvas.draw_rect(rug, Color(0.33, 0.14, 0.13, 0.8), false, 2.0)
	for c4: Vector2 in [rug.position + Vector2(4, 4),
			Vector2(rug.end.x - 8, rug.position.y + 4),
			Vector2(rug.position.x + 4, rug.end.y - 8), rug.end - Vector2(8, 8)]:
		canvas.draw_rect(Rect2(c4, Vector2(4, 4)), Color(0.85, 0.66, 0.42))

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

	# 방에 들어선 직후의 안내 한 줄 (말풍선 대신 방 위쪽에 적는다)
	if notice != "":
		var nw: float = f.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var nr := Rect2(480.0 - nw / 2.0 - 12.0, 54.0, nw + 24.0, 26.0)
		canvas.draw_rect(nr, Color(0.16, 0.12, 0.09, 0.88))
		canvas.draw_rect(nr, Color(0.62, 0.5, 0.32), false, 2.0)
		canvas.draw_string(f, Vector2(480.0 - nw / 2.0, 73.0), notice,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.6))

	# 영업시간 팻말 — 지금 몇 시고, 언제까지 여는지
	var hline := "%s · 지금 %d시" % [GameData.shop_hours_line(),
		int(GameData.hour_now())]
	var hlw: float = f.get_string_size(hline, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	canvas.draw_string(f, Vector2(944.0 - hlw, 30.0), hline,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.78, 0.72, 0.6))

	var si := _shelf_near()
	if si >= 0:
		var sht := "[%s] 선반 — 물건 보기" % str(SHELVES[si][1])
		var shw: float = f.get_string_size(sht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		canvas.draw_string(f, Vector2(480 - shw / 2.0, SHELF_Y + SHELF_H + 66),
			sht, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.6))
	elif _at_counter():
		var ht := "%s" % ("판매 — 만수에게 판다" if room_id == "general" else str(d.hint))
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
		# 얹힌 물건 — 색 네모가 아니라 **물건**. 도트 자(2px)를 타고,
		# 윤곽선을 두르고, 윗변이 빛을 받는다 — 세계의 살림과 같은 손
		var o := r.position
		match cat:
			"seed":
				for j in 3:
					var sx := 6.0 + j * 15.0
					# 씨앗 자루 — 묶인 목, 볼록한 몸, 삐져나온 싹
					KyojinMain.dot_panel(canvas, o, sx, 7, 8, 7, Color(0.78, 0.62, 0.36))
					KyojinMain.dot_rect(canvas, o, sx, 7, 8, 1, Color(0.88, 0.74, 0.48))
					KyojinMain.dot_rect(canvas, o, sx + 2, 5, 4, 2, Color(0.62, 0.48, 0.28))
					KyojinMain.dot_rect(canvas, o, sx + 2, 6, 4, 1, Color(0.45, 0.34, 0.2))
					KyojinMain.dot_rect(canvas, o, sx + 3, 3, 1, 2, Color(0.36, 0.6, 0.3))
					KyojinMain.dot_rect(canvas, o, sx + 4, 2, 2, 2, Color(0.48, 0.74, 0.38))
			"life":
				# 빗자루(눕힌) · 파란 물병 · 붉은 단지
				KyojinMain.dot_panel(canvas, o, 5, 5, 2, 10, Color(0.6, 0.44, 0.24))
				KyojinMain.dot_panel(canvas, o, 4, 12, 4, 3, Color(0.85, 0.74, 0.44))
				KyojinMain.dot_rect(canvas, o, 4, 12, 4, 1, Color(0.93, 0.84, 0.56))
				KyojinMain.dot_panel(canvas, o, 21, 8, 6, 7, Color(0.42, 0.62, 0.78))
				KyojinMain.dot_rect(canvas, o, 23, 5, 2, 3, Color(0.42, 0.62, 0.78))
				KyojinMain.dot_rect(canvas, o, 22, 9, 1, 3, Color(0.72, 0.86, 0.94))
				KyojinMain.dot_panel(canvas, o, 36, 7, 7, 8, Color(0.72, 0.42, 0.34))
				KyojinMain.dot_rect(canvas, o, 37, 7, 5, 1, Color(0.84, 0.56, 0.44))
				KyojinMain.dot_rect(canvas, o, 37, 5, 5, 2, Color(0.5, 0.3, 0.24))
			"tool":
				# 눕힌 망치 · 세운 낫 · 못 상자
				KyojinMain.dot_panel(canvas, o, 5, 10, 10, 2, Color(0.55, 0.4, 0.24))
				KyojinMain.dot_panel(canvas, o, 12, 7, 4, 5, Color(0.6, 0.6, 0.68))
				KyojinMain.dot_rect(canvas, o, 12, 7, 4, 1, Color(0.78, 0.78, 0.84))
				KyojinMain.dot_panel(canvas, o, 24, 4, 2, 11, Color(0.55, 0.4, 0.24))
				KyojinMain.dot_rect(canvas, o, 26, 4, 4, 2, Color(0.7, 0.7, 0.76))
				KyojinMain.dot_rect(canvas, o, 29, 6, 2, 2, Color(0.7, 0.7, 0.76))
				KyojinMain.dot_panel(canvas, o, 36, 9, 8, 6, Color(0.62, 0.46, 0.28))
				KyojinMain.dot_rect(canvas, o, 36, 9, 8, 1, Color(0.74, 0.58, 0.36))
				for nj in 3:
					KyojinMain.dot_rect(canvas, o, 37.0 + nj * 2.5, 10, 1, 1, Color(0.72, 0.72, 0.78))
			_:
				# 세워 꽂힌 책 두 권 + 묶인 두루마리
				KyojinMain.dot_panel(canvas, o, 7, 5, 4, 10, Color(0.68, 0.34, 0.3))
				KyojinMain.dot_rect(canvas, o, 8, 7, 2, 1, Color(0.85, 0.7, 0.45))
				KyojinMain.dot_panel(canvas, o, 12, 6, 4, 9, Color(0.36, 0.5, 0.66))
				KyojinMain.dot_rect(canvas, o, 13, 8, 2, 1, Color(0.85, 0.7, 0.45))
				KyojinMain.dot_panel(canvas, o, 28, 9, 10, 5, Color(0.88, 0.82, 0.68))
				KyojinMain.dot_rect(canvas, o, 28, 9, 10, 1, Color(0.95, 0.91, 0.8))
				KyojinMain.dot_rect(canvas, o, 32, 9, 2, 5, Color(0.62, 0.32, 0.28))
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
