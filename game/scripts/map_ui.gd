# 지도 (M): 실제로 가 본 지역만 보여준다 (fog of war).
# 아직 가 보지 않은 곳은 **먹구름**이 덮고 있고, 탐사할수록 걷힌다.
# (예전에는 검은 단색이었다 — 「고장 난 화면」처럼 보여서 구름으로 바꿨다)
#
# 조작: 마우스 휠 = 확대/축소 (커서 기준) · 끌기 = 이동 · R = 처음 크기로
extends CanvasLayer

# 배율 1 = 맵 전체가 화면에 딱 들어오는 크기. 맵이 커져도 알아서 맞는다.
func _base_cell() -> float:
	return minf(920.0 / float(main.MAP_W), 496.0 / float(main.MAP_H))
# 먹구름 — 바탕 한 겹 + 뭉게뭉게 두 겹. 전부 불투명이라 밑은 보이지 않는다.
const FOG := Color(0.13, 0.14, 0.19)          # 구름 그늘 (바탕)
const CLOUD_MID := Color(0.21, 0.22, 0.28)    # 구름 덩어리
const CLOUD_TOP := Color(0.29, 0.30, 0.37)    # 구름의 밝은 쪽 (빛 받는 면)
const ZOOM_MIN := 0.7
const ZOOM_MAX := 5.0
const ZOOM_STEP := 1.2

var main: Node2D
var canvas: Control
var blink := 0.0

var zoom := 1.0
var pan := Vector2.ZERO       # 기본 위치에서 얼마나 밀었는지 (화면 픽셀)
var _drag := false
var _drag_from := Vector2.ZERO
var _hud_was := true          # 지도를 열기 전 HUD 표시 상태

# 이번 프레임의 그리기 기준 (셀 크기 / 원점) — 그릴 때 한 번 계산해 둔다
var _cell := 8.0
var _ox := 0.0
var _oy := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	# 두 Control 모두 마우스를 통과시켜야 한다.
	# 기본값(STOP)이면 GUI 단계에서 이벤트를 먹어 _unhandled_input이 아예 안 불리고,
	# 휠 확대와 끌기가 통째로 죽는다.
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.1, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_map)
	add_child(canvas)


func open() -> void:
	# 배율과 위치는 닫아도 그대로 둔다 (R로 처음 크기로 되돌린다)
	visible = true
	_drag = false
	# 지도를 보는 동안에는 HUD를 감춘다.
	# 미니맵·시계가 큰 지도 위에 겹쳐 보이는 것도 그렇지만, 무엇보다
	# 하단 핫바가 **버튼**이라 그 위에서 마우스를 놓으면 버튼이 이벤트를 먹는다.
	if main != null and main.hud != null:
		_hud_was = main.hud.visible
		main.hud.visible = false
	canvas.queue_redraw()


func close() -> void:
	visible = false
	_drag = false
	if main != null and main.hud != null:
		main.hud.visible = _hud_was


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# 배율 1 · 맵 전체가 화면에 들어오는 처음 상태
func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO


func _origin(c: float) -> Vector2:
	return Vector2((960.0 - main.MAP_W * c) / 2.0,
		(540.0 - main.MAP_H * c) / 2.0 + 2.0) + pan


# 커서 아래의 지점이 그대로 있도록 확대/축소한다
func _zoom_at(m: Vector2, factor: float) -> void:
	var c0 := _base_cell() * zoom
	var t := (m - _origin(c0)) / c0            # 커서가 가리키는 타일 좌표
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var c1 := _base_cell() * zoom
	pan = m - t * c1 - Vector2((960.0 - main.MAP_W * c1) / 2.0,
		(540.0 - main.MAP_H * c1) / 2.0 + 2.0)
	_clamp_pan()


# 지도를 화면 안에 붙들어 둔다.
#
# 예전에는 「지도 크기의 절반」까지 밀 수 있었다. 그래서 기본 배율에서도
# 지도가 화면 한쪽으로 확 밀려 나가 절반이 빈 공간이 됐다 — 끌기가 고장 난 것처럼 보인다.
# 지금은 지도가 화면보다 크면 **가장자리가 화면 안으로 들어오지 않게**(구석까지 볼 수 있다),
# 화면보다 작으면 **화면 밖으로 나가지 않게** 묶는다. 두 경우가 같은 식이 된다.
func _clamp_pan() -> void:
	var c := _base_cell() * zoom
	var lim_x: float = absf(float(main.MAP_W) * c - 960.0) / 2.0
	var lim_y: float = absf(float(main.MAP_H) * c - 540.0) / 2.0
	pan.x = clampf(pan.x, -lim_x, lim_x)
	pan.y = clampf(pan.y, -lim_y, lim_y)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			_drag_from = mb.position
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		pan += mm.relative
		_drag_from = mm.position
		_clamp_pan()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_R:
		reset_view()
		get_viewport().set_input_as_handled()


# 끌기를 끝내는 일은 세 겹으로 막아 둔다.
# 「눌림 해제」를 _unhandled_input에만 맡기면, 마우스를 먹는 Control 위에서
# 버튼을 놓았을 때 그 이벤트가 영영 오지 않아 지도가 계속 마우스를 따라다녔다.
#
# ① _input — GUI보다 **먼저** 오므로 핫바 버튼 위에서 놓아도 놓치지 않는다.
#    (여기서는 이벤트를 소비하지 않는다. 다른 UI 조작을 방해하면 안 된다)
func _input(event: InputEvent) -> void:
	if not visible or not _drag:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag = false


# ② 매 프레임 실제 버튼 상태 확인 — 창 밖에서 놓아 이벤트가 아예 없는 경우
func _stop_drag_if_released() -> void:
	if _drag and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag = false


# ③ 창이 포커스를 잃으면 (Alt+Tab 등) 끌기를 놓는다
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_drag = false


func _process(delta: float) -> void:
	if visible:
		blink += delta
		_stop_drag_if_released()
		canvas.queue_redraw()


# 이 타일을 지도에 보여줘도 되는가:
# 실제로 가 본 청크 + (내 부지이거나 공용 길/마을)만 표시한다.
# 미해금 부지는 탐사 여부와 관계없이 가린다.
func _visible_tile(x: int, y: int) -> bool:
	if not GameData.is_explored_tile(x, y):
		return false
	if GameData.is_tile_owned(x, y):
		return true
	return main.ROAD.has_point(Vector2i(x, y)) \
		or main.VILLAGE_REGION.has_point(Vector2i(x, y))


# 이 칸의 바닥 색. 같은 지형이라도 칸마다 밝기를 조금 흔들어 결을 낸다 —
# 한 색으로 칠하면 초록 장판이 된다.
func _ground_color(x: int, y: int, season: int) -> Color:
	var g: String = main.grid[y][x].ground
	var base: Color
	match g:
		"water":
			base = Color(0.22, 0.42, 0.66)
		"sand":
			base = Color(0.85, 0.77, 0.55)
		"dock":
			base = Color(0.55, 0.38, 0.22)
		"path":
			base = Color(0.72, 0.62, 0.44)
		"soil":
			# 물을 준 밭은 짙다 — 지도만 봐도 어디에 물을 안 줬는지 보인다
			base = Color(0.3, 0.21, 0.13) if main.grid[y][x].watered \
				else Color(0.45, 0.33, 0.2)
		_:
			match season:
				GameData.WINTER:
					base = Color(0.82, 0.85, 0.9)
				GameData.FALL:
					base = Color(0.62, 0.5, 0.3)
				_:
					base = Color(0.3, 0.5, 0.26)
	# 야생 지역은 그 땅의 결을 얹는다 (풀빛이 조금씩 다르다)
	var tint := _region_tint(x, y)
	if tint.a > 0.0:
		base = base.lerp(Color(tint.r, tint.g, tint.b), tint.a)
	var n: float = main._hash01(x * 13 + 5, y * 29 + 7) - 0.5
	return Color(clampf(base.r + n * 0.09, 0.0, 1.0),
		clampf(base.g + n * 0.09, 0.0, 1.0),
		clampf(base.b + n * 0.09, 0.0, 1.0))


# 야생 지역마다 옅게 다른 풀빛 (a = 섞는 정도). 이름표가 없어도
# 「여기부터 다른 땅」이 눈에 들어와야 한다.
const REGION_TINT := {
	"deep": Color(0.13, 0.34, 0.18, 0.42),      # 짙은 숲
	"orchard": Color(0.45, 0.6, 0.26, 0.32),    # 밝은 과수원
	"quarry": Color(0.62, 0.56, 0.44, 0.3),     # 메마른 자갈
	"meadow": Color(0.53, 0.68, 0.34, 0.3),     # 볕 드는 초원
	"wetland": Color(0.26, 0.44, 0.42, 0.36),   # 물 먹은 땅
	"pinewood": Color(0.16, 0.3, 0.26, 0.44),   # 서늘한 솔숲
	"bluff": Color(0.55, 0.52, 0.42, 0.3),      # 바람 든 벼랑
}


# 칸마다 지역을 매번 찾으면 (지역 수 x 보이는 칸 수)만큼 헛일을 한다 —
# 배율 1에서는 온 맵이 다 보이므로 한 프레임에 십수만 번이다.
# 그래서 「칸 -> 지역 번호」를 한 번 만들어 두고 쓴다 (0 = 지역 밖).
var _reg_idx := PackedByteArray()
var _reg_cols: Array[Color] = []


func _build_region_index() -> void:
	_reg_idx.resize(main.MAP_W * main.MAP_H)
	_reg_idx.fill(0)
	_reg_cols = [Color(0, 0, 0, 0.0)]
	for reg: Dictionary in main.REGIONS:
		_reg_cols.append(REGION_TINT.get(str(reg.id), Color(0, 0, 0, 0.0)))
		var n := _reg_cols.size() - 1
		var r: Rect2i = reg.rect
		for y in range(maxi(0, r.position.y), mini(main.MAP_H, r.end.y)):
			for x in range(maxi(0, r.position.x), mini(main.MAP_W, r.end.x)):
				_reg_idx[y * main.MAP_W + x] = n


func _region_tint(x: int, y: int) -> Color:
	return _reg_cols[_reg_idx[y * main.MAP_W + x]]


# 물칸이 뭍과 닿아 있는가 (해안선을 그릴지 정한다)
func _shore(x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nx := x + d.x
		var ny := y + d.y
		if nx < 0 or ny < 0 or nx >= main.MAP_W or ny >= main.MAP_H:
			continue
		if main.grid[ny][nx].ground != "water":
			return true
	return false


func _draw_map() -> void:
	_taken.clear()
	if _reg_idx.size() != main.MAP_W * main.MAP_H:
		_build_region_index()
	_cell = _base_cell() * zoom
	var o := _origin(_cell)
	_ox = o.x
	_oy = o.y

	# 확대하면 대부분이 화면 밖이므로, 보이는 칸만 그린다
	var x0: int = maxi(0, int(floor(-_ox / _cell)))
	var x1: int = mini(main.MAP_W, int(ceil((960.0 - _ox) / _cell)) + 1)
	var y0: int = maxi(0, int(floor(-_oy / _cell)))
	var y1: int = mini(main.MAP_H, int(ceil((540.0 - _oy) / _cell)) + 1)

	# ---- 지형 ----
	#
	# 한 칸을 한 색으로 칠하면 초록 장판이 된다. 같은 잔디라도 칸마다
	# 밝기를 조금씩 흔들어 「그려 놓은 지도」처럼 결이 생기게 한다.
	# (흔드는 값은 칸 좌표 해시라 볼 때마다 달라지지 않는다)
	var fogged: Array = []
	var season := GameData.season()
	for y in range(y0, y1):
		for x in range(x0, x1):
			var r := Rect2(_ox + x * _cell, _oy + y * _cell, _cell + 0.5, _cell + 0.5)
			if not _visible_tile(x, y):
				canvas.draw_rect(r, FOG)
				fogged.append(Vector2i(x, y))
				continue
			canvas.draw_rect(r, _ground_color(x, y, season))
			# 물가: 뭍과 닿는 쪽에 옅은 띠를 둘러 해안선을 낸다.
			# 이 선 하나로 호수와 바다가 「퍼진 파란 얼룩」에서 벗어난다.
			if main.grid[y][x].ground == "water" and _shore(x, y):
				canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, maxf(1.0, _cell * 0.3))),
					Color(0.58, 0.78, 0.88, 0.55))

	# ---- 지형지물 ----
	#
	# 네모 한 칸으로 찍으면 나무도 바위도 건물도 그냥 「점」이다.
	# 작아도 생김새를 흉내 내면 한눈에 무엇인지 읽힌다 —
	# 나무는 밑동 위에 얹힌 둥근 잎, 바위는 위가 밝은 덩어리,
	# 건물은 몸통 위에 얹힌 지붕.
	var cs := _cell
	for pos: Vector2i in main.objects:
		if pos.x < x0 or pos.x >= x1 or pos.y < y0 or pos.y >= y1:
			continue
		if not _visible_tile(pos.x, pos.y):
			continue
		var kind: String = main.objects[pos].kind
		var at := Vector2(_ox + pos.x * cs, _oy + pos.y * cs)
		match kind:
			"tree":
				# 잎 두 겹 — 아래는 짙게, 위쪽 절반은 볕이 든 것처럼 밝게
				canvas.draw_rect(Rect2(at.x, at.y + cs * 0.15, cs + 0.5, cs * 0.85),
					Color(0.13, 0.31, 0.13))
				canvas.draw_rect(Rect2(at.x + cs * 0.15, at.y + cs * 0.1,
					cs * 0.6, cs * 0.45), Color(0.24, 0.47, 0.2))
			"rock", "bigrock":
				var big: float = 1.0 if kind == "bigrock" else 0.82
				canvas.draw_rect(Rect2(at.x + cs * (1.0 - big) * 0.5,
					at.y + cs * (1.0 - big) * 0.5, cs * big, cs * big),
					Color(0.46, 0.46, 0.52))
				canvas.draw_rect(Rect2(at.x + cs * 0.2, at.y + cs * 0.15,
					cs * 0.45, cs * 0.3), Color(0.68, 0.68, 0.74))
			"house", "art_block":
				canvas.draw_rect(Rect2(at, Vector2(cs + 0.5, cs + 0.5)),
					Color(0.76, 0.68, 0.56))                     # 벽
				canvas.draw_rect(Rect2(at.x, at.y, cs + 0.5, maxf(1.0, cs * 0.45)),
					Color(0.66, 0.27, 0.21))                     # 지붕
			"board", "sign", "auction", "plotsite", "homeplot":
				canvas.draw_rect(Rect2(at.x + cs * 0.2, at.y + cs * 0.2,
					cs * 0.6, cs * 0.6), Color(0.95, 0.8, 0.35))
			"searock":
				canvas.draw_rect(Rect2(at, Vector2(cs + 0.5, cs + 0.5)),
					Color(0.38, 0.38, 0.44))
			"fence":
				canvas.draw_rect(Rect2(at.x, at.y + cs * 0.3, cs + 0.5,
					maxf(1.0, cs * 0.4)), Color(0.6, 0.45, 0.28))
			_:
				canvas.draw_rect(Rect2(at.x + cs * 0.15, at.y + cs * 0.15,
					cs * 0.7, cs * 0.7), Color(0.5, 0.4, 0.3))

	# 동물/NPC (보이는 지역만)
	var dot: float = maxf(3.0, _cell * 0.5)
	for a in main.animals:
		if _visible_tile(int(a.position.x / 32.0), int(a.position.y / 32.0)):
			_dot(a.position, dot, Color(0.95, 0.95, 0.9))
	for n in main.npcs:
		if n.visible and _visible_tile(int(n.position.x / 32.0), int(n.position.y / 32.0)):
			_dot(n.position, dot, Color(0.95, 0.55, 0.75))

	# 시설 라벨 (그 위치를 발견했을 때만)
	_place_label(73, 28, "우리집")
	_place_label(18, 14, "농장")
	if GameData.barn_built:
		_place_label(main.BARN_POS.x, main.BARN_POS.y, "축사")
	if GameData.greenhouse_built:
		_place_label(main.GREENHOUSE.position.x + 4,
			main.GREENHOUSE.position.y + 3, "온실")
	# 세워 둔 말 (타고 있는 동안에는 내 위치와 같으므로 표시하지 않는다)
	if GameData.has_horse and not GameData.riding:
		var h: Vector2i = GameData.horse_tile
		canvas.draw_rect(Rect2(_ox + h.x * _cell - 2, _oy + h.y * _cell - 2,
			_cell + 4, _cell + 4), Color(0.62, 0.42, 0.24))
		# 글씨는 아래쪽에 — 위에 두면 「농장」·「축사」 라벨과 겹쳐 읽을 수 없다
		_label(Vector2(_ox + h.x * _cell, _oy + h.y * _cell + _cell + 20), "말")
	_place_label(74, 13, "중앙 광장")
	_place_label(46, 31, "호수 낚시터")
	_place_label(50, 1, "동굴")
	# 야생 지역 이름 — 가 본 곳만. 그 땅 한가운데에 옅은 테두리와 함께 적는다.
	# 이름이 붙어야 「빈 잔디밭」이 아니라 「가 볼 데」로 보인다.
	for reg: Dictionary in main.REGIONS:
		var rr: Rect2i = reg.rect
		var mid := rr.position + rr.size / 2
		if not _visible_tile(mid.x, mid.y):
			continue
		canvas.draw_rect(Rect2(_ox + rr.position.x * _cell, _oy + rr.position.y * _cell,
			rr.size.x * _cell, rr.size.y * _cell), Color(0.85, 0.9, 0.7, 0.16), false, 1.0)
		_label(Vector2(_ox + mid.x * _cell - 34.0, _oy + mid.y * _cell), str(reg.name))
	# 지어진 마을 건물만 이름을 보여준다 (빈 부지는 표시하지 않는다)
	for pid: String in GameData.village_built:
		if not main.VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = main.VILLAGE_PLOTS[pid].anchor
		_place_label(a.x, a.y, str(main.VILLAGE_PLOTS[pid].name))

	# 옛 마을 확장 구역 (메인 스토리 4) — 표지판을 본 뒤부터 지도에 나타난다.
	# 잠긴 구역은 빗금 테두리 + 이름, 열린 구역은 이름만 남긴다.
	if GameData.story4_phase != "":
		for zid: String in GameData.ZONE_ORDER:
			var zr: Rect2i = GameData.VILLAGE_ZONES[zid].rect
			var pr := Rect2(_ox + zr.position.x * _cell, _oy + zr.position.y * _cell,
				zr.size.x * _cell, zr.size.y * _cell)
			var locked: bool = zid not in GameData.zones_open
			if locked:
				canvas.draw_rect(pr, Color(0.5, 0.15, 0.12, 0.28))
			canvas.draw_rect(pr, Color(0.9, 0.55, 0.3, 0.8) if locked
				else Color(0.55, 0.8, 0.45, 0.6), false, 2.0)
			_label(Vector2(pr.get_center().x - 40.0, pr.get_center().y),
				str(GameData.VILLAGE_ZONES[zid].name) + (" (잠김)" if locked else ""))

	# 먹구름 뭉치 — 가려진 칸 위로 둥근 덩어리를 얹어 「구름에 덮인」 모양을 낸다
	_draw_clouds(fogged)

	# 퀘스트 길라잡이 — **딱 하나**만 찍는다 (미니창에 고정한 그 퀘스트)
	for g: Dictionary in _quest_guides():
		_draw_guide(g)

	# 내 위치: 눈에 잘 띄는 마커 (고리 + 깜빡이는 점 + 라벨)
	var pp := Vector2(_ox + main.player.position.x / 32.0 * _cell,
		_oy + main.player.position.y / 32.0 * _cell)
	var pulse := 4.0 + sin(blink * 5.0) * 1.5
	canvas.draw_arc(pp + Vector2(0.5, 0.5), pulse + 3.0, 0, TAU, 20, Color(1, 0.85, 0.3, 0.9), 2.0)
	canvas.draw_rect(Rect2(pp.x - 3, pp.y - 3, 7, 7), Color(1, 1, 1))
	canvas.draw_rect(Rect2(pp.x - 2, pp.y - 2, 5, 5), Color(0.95, 0.3, 0.25))
	_label(Vector2(pp.x, pp.y - 10), "내 위치", 22, true)

	# 세계의 테두리 — 지도가 어디서 끝나는지 눈에 보이게 두른다.
	# (테두리가 없으면 먹구름과 배경이 이어져 「여기가 끝인지」 알 수 없다)
	var edge := Rect2(_ox, _oy, main.MAP_W * _cell, main.MAP_H * _cell)
	canvas.draw_rect(edge.grow(3.0), Color(0.32, 0.26, 0.18), false, 3.0)
	canvas.draw_rect(edge.grow(1.0), Color(0.58, 0.48, 0.32), false, 1.0)

	# 이름패 — 지도 맨 위, 이 땅의 이름
	var plate := "교진 마을 · %s의 농장" % GameData.seller_name()
	var pw: float = main.UI_FONT.get_string_size(plate, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var pr2 := Rect2(480.0 - pw / 2.0 - 14.0, 4.0, pw + 28.0, 30.0)
	canvas.draw_rect(pr2, Color(0.16, 0.12, 0.09, 0.92))
	canvas.draw_rect(pr2, Color(0.62, 0.5, 0.32), false, 2.0)
	canvas.draw_string(main.UI_FONT, Vector2(480.0 - pw / 2.0, 27.0), plate,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.86, 0.5))

	# 안내
	var guide := "휠: 확대·축소 · 끌기: 이동 · R: 처음 크기 · M/ESC: 닫기 (배율 %.1fx)" % zoom
	var w: float = main.UI_FONT.get_string_size(guide, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	canvas.draw_string(main.UI_FONT, Vector2(480 - w / 2.0, 526), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.68, 0.8))


# ---- 퀘스트 길라잡이 ----
#
# 「어디로 가야 하지?」를 글로 설명하는 대신 지도에 찍어 준다.
#
# **마커는 언제나 한 개다.** 미니창에 고정한 퀘스트(고정하지 않았다면
# 미니창에 뜬 그 퀘스트) 하나만 짚는다 — 여러 개가 동시에 뜨면
# 어디가 어딘지 모르게 되기 때문이다.
#   ① 이야기 단계마다 정해 둔 장소가 있으면 그 자리 (아래 표)
#   ② 없으면 그 퀘스트의 담당 NPC가 서 있는 자리
func _quest_guides() -> Array:
	var q: Dictionary = GameData.tracked_quest()
	if q.is_empty():
		return []
	var out: Array = []
	var title := str(q.get("title", "목표"))
	var spot := _quest_spot(str(q.get("id", "")))
	if spot.x >= 0:
		out.append({"tile": spot, "text": title})
		return out
	# 담당하는 사람이 있으면 그 사람이 곧 목적지다
	var nid := str(q.get("npc", ""))
	if nid != "":
		for n in main.npcs:
			if n.id == nid and n.visible:
				out.append({"tile": Vector2i(int(n.position.x / main.TILE),
					int(n.position.y / main.TILE)), "text": title})
				break
	return out


# 이야기 단계별 목적지 — 사람이 아니라 「장소」로 가야 하는 것들
func _quest_spot(qid: String) -> Vector2i:
	match qid:
		"story2":
			# 첫 상점을 세울 자리 — 「어디에 짓지?」를 지도가 대신 말한다
			if GameData.story2_phase == "shop":
				return _plot_center("general")
		"move":
			if GameData.move_quest == "postbuild":
				return _plot_center("post")
		"story10", "story11":
			if GameData.story11_phase == "deep" or GameData.story10_phase == "dig":
				return main.CAVE_POS
		"story13":
			if GameData.story13_phase in ["rock", "fish"]:
				return main.BRACELET_ROCK
		"story15":
			if GameData.story15_phase == "dig":
				return main.CAVE_POS
			if GameData.story15_phase == "water":
				return main.ONSEN_POS
		"story16":
			if GameData.story16_phase == "clear":
				return main.OLD_FARM.position + Vector2i(5, 3)
		"story17":
			if GameData.story17_phase == "barn":
				return main.OLD_BARN
		"story18":
			if GameData.story18_phase in ["hill", "box"]:
				return main.HILL_POS
		"story20":
			if GameData.story20_phase in ["gate", "inner"]:
				return main.CAVE_POS
			if GameData.story20_phase == "plant":
				return main.HOME_ANCHOR + Vector2i(2, 5)
		"fisher_home":
			if GameData.fisher_home in ["wait", "built"]:
				return Vector2i(main.FOUNTAIN.position.x + 1, main.FOUNTAIN.end.y + 1)
		"kitchen":
			if GameData.kitchen_quest in ["sweep", "jam"]:
				return main.HOME_ANCHOR + Vector2i(2, 3)
			if GameData.kitchen_quest in ["broom", "make"] \
					and GameData.village_built.has("general"):
				return main.VILLAGE_PLOTS["general"].anchor + Vector2i(2, 3)
		"tutorial":
			if GameData.tutorial_current_flag() == "cook":
				return main.HOME_ANCHOR + Vector2i(2, 3)
	return Vector2i(-1, -1)


# ---- 먹구름 (미탐사 지역) ----
#
# 검은 단색은 「아직 안 가 봤다」가 아니라 「화면이 깨졌다」처럼 보인다.
# 그래서 가려진 칸 위에 둥근 구름 덩어리를 얹는다. 자리는 칸 좌표로
# 정해지므로 다시 열어도 같은 모양이고(깜빡이지 않는다), 아주 느리게
# 흘러가 살아 있는 하늘처럼 보인다. **전부 불투명이라 밑은 안 비친다.**
func _cloud_rand(x: int, y: int, salt: int) -> float:
	var h := float(sin(float(x) * 12.9898 + float(y) * 78.233 + float(salt) * 37.719) * 43758.5453)
	return h - floor(h)


func _draw_clouds(fogged: Array) -> void:
	var drift := blink * 0.12          # 아주 느린 흐름
	for t: Vector2i in fogged:
		# 두 칸마다 한 덩어리 — 큼직하게 겹쳐 놓아야 「구름」으로 보인다
		# (칸마다 하나씩 찍으면 크기가 고르게 나와 물방울무늬가 된다)
		if t.x % 2 != 0 or t.y % 2 != 0:
			continue
		var rx := _cloud_rand(t.x, t.y, 1)
		var ry := _cloud_rand(t.x, t.y, 2)
		var rs := _cloud_rand(t.x, t.y, 3)
		var c := Vector2(_ox + (float(t.x) + 1.0 + (rx - 0.5) * 1.1) * _cell,
			_oy + (float(t.y) + 1.0 + (ry - 0.5) * 1.1) * _cell)
		var wob := sin(drift + float(t.x) * 0.7 + float(t.y) * 0.4) * _cell * 0.25
		# 덩어리마다 밝기가 조금씩 달라 층이 진 하늘처럼 보인다
		var body := FOG.lerp(CLOUD_MID, 0.45 + rs * 0.55)
		var r1 := _cell * (1.5 + rs * 0.75)
		canvas.draw_circle(c + Vector2(wob, 0.0), r1, body)
		# 빛을 받는 윗면 — 살짝 위로 올려 그린다
		if rs > 0.35:
			canvas.draw_circle(c + Vector2(wob * 0.6, -_cell * (0.5 + rx * 0.3)),
				r1 * (0.34 + rx * 0.22), CLOUD_MID.lerp(CLOUD_TOP, 0.4 + ry * 0.6))


# 건물 터의 한가운데 — 이야기가 「세우자」고 할 때 이 자리를 찍는다
func _plot_center(pid: String) -> Vector2i:
	var a: Vector2i = main.VILLAGE_PLOTS[pid].anchor
	return a + Vector2i(2, 2)      # 건물 그림(5x4) 한가운데


# 하트(퀘스트) 또는 집(건설 터) + 두근거리는 고리 — 멀리서도 눈에 띄게
func _draw_guide(g: Dictionary) -> void:
	var t: Vector2i = g.tile
	var c := Vector2(_ox + (float(t.x) + 0.5) * _cell, _oy + (float(t.y) + 0.5) * _cell)
	if c.x < -40.0 or c.x > 1000.0 or c.y < -40.0 or c.y > 560.0:
		return
	var beat := 1.0 + sin(blink * 4.0) * 0.12
	var tint := Color(1.0, 0.42, 0.55)
	var ring := Color(1.0, 0.55, 0.66)
	# 퍼지는 고리 두 겹
	canvas.draw_arc(c, 13.0 * beat, 0, TAU, 24, Color(ring, 0.85), 2.5)
	canvas.draw_arc(c, 19.0 * beat, 0, TAU, 24, Color(ring, 0.35), 2.0)
	# 하트 (두 개의 둥근 봉우리 + 아래로 모이는 삼각형)
	var s := 5.5 * beat
	canvas.draw_circle(c + Vector2(-s * 0.5, -s * 0.35), s * 0.62, tint)
	canvas.draw_circle(c + Vector2(s * 0.5, -s * 0.35), s * 0.62, tint)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 1.05, -s * 0.15), c + Vector2(s * 1.05, -s * 0.15),
		c + Vector2(0.0, s * 1.15)]), tint)
	# 이름만, 작게 (설명은 Q창의 몫이다)
	_label(Vector2(c.x, c.y + 20.0), str(g.text), 15)


func _dot(world_pos: Vector2, size: float, col: Color) -> void:
	canvas.draw_rect(Rect2(_ox + world_pos.x / 32.0 * _cell - size / 2.0,
		_oy + world_pos.y / 32.0 * _cell - size / 2.0, size, size), col)


func _place_label(tx: int, ty: int, text: String) -> void:
	if _visible_tile(tx, ty):
		_label(Vector2(_ox + tx * _cell, _oy + ty * _cell - 2), text)


# 이번 프레임에 이미 글씨가 놓인 자리들. 겹치는 이름표는 건너뛴다 —
# 마을처럼 건물이 붙어 선 곳에서는 이름 예닐곱 개가 한자리에 겹쳐
# 「동쪽제국잡화점연구소」 같은 글자 뭉치가 됐다.
var _taken: Array = []


# force=true면 겹쳐도 반드시 그린다 (내 위치·퀘스트 길라잡이처럼
# 「지금 봐야 하는 것」은 다른 이름표에 밀리면 안 된다)
func _label(pos: Vector2, text: String, size := 22, force := false) -> void:
	# 화면 밖 라벨은 그리지 않는다 (확대했을 때 글자가 가장자리에 몰리지 않게)
	if pos.x < -60.0 or pos.x > 1020.0 or pos.y < 0.0 or pos.y > 520.0:
		return
	var w: float = main.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(pos.x - w / 2.0, pos.y)
	# 글자가 놓이는 자리 (기준선 위로 글자 높이만큼)
	var box := Rect2(p.x - 3.0, p.y - size + 2.0, w + 6.0, size + 4.0)
	if not force:
		for t: Rect2 in _taken:
			if t.intersects(box):
				return
	_taken.append(box)
	# 바탕판 — 풀밭 위에 글씨만 얹으면 배경과 섞여 읽기 어렵다
	canvas.draw_rect(box, Color(0.06, 0.05, 0.1, 0.55))
	canvas.draw_string_outline(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3,
		Color(0.05, 0.04, 0.08))
	canvas.draw_string(main.UI_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(1, 0.92, 0.7))
