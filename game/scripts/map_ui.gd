# 지도 (M): 실제로 가 본 지역만 보여준다 (fog of war).
# 아직 가 보지 않은 곳은 **먹구름**이 덮고 있고, 탐사할수록 걷힌다.
# (예전에는 검은 단색이었다 — 「고장 난 화면」처럼 보여서 구름으로 바꿨다)
#
# 조작: 마우스 휠 = 확대/축소 (커서 기준) · 끌기 = 이동 · R = 처음 크기로
extends CanvasLayer

# 배율 1 = 맵 전체가 화면에 딱 들어오는 크기. 맵이 커져도 알아서 맞는다.
# 화면을 최대한 넓게 쓴다 — 위 이름패(34)와 아래 안내줄(22)만 비켜 둔다.
# (예전에는 920x496이라 좌우로 손가락 두 마디씩 빈 자리가 남았다)
const VIEW_W := 952.0
const VIEW_H := 512.0

# 먹구름 — 바탕 한 겹 + 뭉게뭉게 두 겹. 전부 불투명이라 밑은 보이지 않는다.
const FOG := Color(0.13, 0.14, 0.19)          # 구름 그늘 (바탕)
const CLOUD_MID := Color(0.21, 0.22, 0.28)    # 구름 덩어리
const CLOUD_TOP := Color(0.29, 0.30, 0.37)    # 구름의 밝은 쪽 (빛 받는 면)
const ZOOM_MIN := 0.7
const ZOOM_MAX := 6.5
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
	# 구운 지형 그림은 칸 하나가 픽셀 하나다 — 늘여 그릴 때 뭉개지면 안 된다
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw.connect(_draw_map)
	add_child(canvas)


func open() -> void:
	# 배율과 위치는 닫아도 그대로 둔다 (R로 처음 크기로 되돌린다)
	visible = true
	_drag = false
	_bake_age = 999.0        # 걸어다니는 동안 달라진 것을 반영해 새로 굽는다
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


# 이 지도가 보여 주는 땅. 튜토리얼 동안에는 그 작은 공간만, 마을에
# 도착한 뒤로는 실제 세계만이다 — 튜토리얼 공간은 세계 밖(y가 WORLD_H보다
# 아래)에 있으므로 여기서 통째로 빠진다. 지나온 길도, 처음 서 있던 자리도
# 지도에 남지 않는다.
# 한 장을 굽는 동안에만 2만 7천 번 불린다 — 매번 새 Rect2i를 만들면 그것만으로
# 몇 밀리초다. 튜토리얼에서 세계로 넘어갈 때만 달라지므로 그때만 다시 잰다.
var _wr := Rect2i()
var _wr_tut := true


func _world() -> Rect2i:
	if _wr.size.x == 0 or _wr_tut != GameData.tutorial_space:
		_wr_tut = GameData.tutorial_space
		_wr = main.world_rect()
	return _wr


# 배율 1 = 이 땅이 화면에 딱 들어오는 칸 크기
func _base_cell() -> float:
	var r := _world()
	return minf(VIEW_W / float(r.size.x), VIEW_H / float(r.size.y))


# 칸 (0,0)이 놓이는 화면 자리 — 보여 줄 땅의 한가운데가 화면 한가운데에 오게
func _origin_base(c: float) -> Vector2:
	var r := _world()
	return Vector2(480.0 - (float(r.position.x) + float(r.size.x) * 0.5) * c,
		272.0 - (float(r.position.y) + float(r.size.y) * 0.5) * c)


func _origin(c: float) -> Vector2:
	return _origin_base(c) + pan


# 보여 줄 땅이 화면에서 차지하는 네모 (구운 그림·테두리가 같이 쓴다)
func _world_screen_rect() -> Rect2:
	var r := _world()
	return Rect2(_ox + float(r.position.x) * _cell, _oy + float(r.position.y) * _cell,
		float(r.size.x) * _cell, float(r.size.y) * _cell)


# 커서 아래의 지점이 그대로 있도록 확대/축소한다
func _zoom_at(m: Vector2, factor: float) -> void:
	var c0 := _base_cell() * zoom
	var t := (m - _origin(c0)) / c0            # 커서가 가리키는 타일 좌표
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var c1 := _base_cell() * zoom
	pan = m - t * c1 - _origin_base(c1)
	_clamp_pan()


# 지도를 화면 안에 붙들어 둔다.
#
# 예전에는 「지도 크기의 절반」까지 밀 수 있었다. 그래서 기본 배율에서도
# 지도가 화면 한쪽으로 확 밀려 나가 절반이 빈 공간이 됐다 — 끌기가 고장 난 것처럼 보인다.
# 지금은 지도가 화면보다 크면 **가장자리가 화면 안으로 들어오지 않게**(구석까지 볼 수 있다),
# 화면보다 작으면 **화면 밖으로 나가지 않게** 묶는다. 두 경우가 같은 식이 된다.
func _clamp_pan() -> void:
	var c := _base_cell() * zoom
	var r := _world()
	var lim_x: float = absf(float(r.size.x) * c - 960.0) / 2.0
	var lim_y: float = absf(float(r.size.y) * c - 540.0) / 2.0
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
		_bake_age += delta
		_stop_drag_if_released()
		canvas.queue_redraw()


# 이 타일을 지도에 보여줘도 되는가:
# 실제로 가 본 청크 + (내 부지이거나 공용 길/마을)만 표시한다.
# 미해금 부지는 탐사 여부와 관계없이 가린다.
func _visible_tile(x: int, y: int) -> bool:
	# 보여 줄 땅 밖 — 튜토리얼 공간이든 세계든, 지금 지도가 아닌 곳은 없는 셈이다
	if not _world().has_point(Vector2i(x, y)):
		return false
	return _seen_tile(x, y)


# 「보여 줄 땅 안」이 이미 보장된 자리용 (구울 때는 그 사각만 훑으므로
# 칸마다 사각을 다시 볼 이유가 없다 — 2만 7천 번이 그냥 없어진다)
func _seen_tile(x: int, y: int) -> bool:
	if not GameData.is_explored_tile(x, y):
		return false
	_ensure_vis_index()
	return _vis_idx[y * main.MAP_W + x] == 1


# 「탐사만 했다면 보이는 칸인가」를 미리 구해 둔다.
#
# 칸마다 묻던 것이 세 가지였다 — 잠긴 확장 구역인가(`is_tile_owned`가 구역
# 목록을 훑는다) · 공용 길인가 · 마을인가. 한 장 굽는 데 2만 7천 번이니
# 그것만으로 백 밀리초가 넘게 들었다. 답이 달라지는 때는 **확장 구역이
# 열릴 때뿐**이라, 그때만 다시 만든다.
var _vis_idx := PackedByteArray()
var _vis_zones := -1


func _ensure_vis_index() -> void:
	if _vis_idx.size() == main.MAP_W * main.MAP_H \
			and _vis_zones == GameData.zones_open.size():
		return
	_vis_idx.resize(main.MAP_W * main.MAP_H)
	_vis_zones = GameData.zones_open.size()
	for y in main.MAP_H:
		var base: int = y * main.MAP_W
		for x in main.MAP_W:
			var t := Vector2i(x, y)
			_vis_idx[base + x] = 1 if (GameData.is_tile_owned(x, y) \
				or main.ROAD.has_point(t) or main.VILLAGE_REGION.has_point(t)) else 0


# 이 칸의 바닥 색. 같은 지형이라도 칸마다 밝기를 조금 흔들어 결을 낸다 —
# 한 색으로 칠하면 초록 장판이 된다.
#
# 칸 정보(cell)와 흔들 값(n)은 부르는 쪽이 넘긴다. 한 장에 2만 7천 번
# 불리는 자리라, 여기서 격자를 다시 찾고 해시를 다시 돌리면 그것만으로
# 수십 밀리초다 (`_bake`가 줄마다 격자 줄을 쥐고, 흔들 값은 미리 굽는다).
func _ground_color(cell: Dictionary, x: int, y: int, season: int, n: float) -> Color:
	var g: String = cell.ground
	var base: Color
	match g:
		"water":
			# 뭍과 닿는 물칸은 밝게 — 이 한 줄이 호수와 바다에 해안선을 낸다.
			# (없으면 「퍼진 파란 얼룩」으로 보인다)
			base = Color(0.44, 0.63, 0.78) if _shore(x, y) else Color(0.22, 0.42, 0.66)
		"sand":
			base = Color(0.85, 0.77, 0.55)
		"dock":
			base = Color(0.55, 0.38, 0.22)
		"path":
			base = Color(0.72, 0.62, 0.44)
		"soil":
			# 물을 준 밭은 짙다 — 지도만 봐도 어디에 물을 안 줬는지 보인다
			base = Color(0.3, 0.21, 0.13) if cell.watered else Color(0.45, 0.33, 0.2)
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
	return Color(clampf(base.r + n * 0.09, 0.0, 1.0),
		clampf(base.g + n * 0.09, 0.0, 1.0),
		clampf(base.b + n * 0.09, 0.0, 1.0))


# 칸마다의 밝기 흔들림 — 지형이 아니라 **자리**가 정하는 값이라 한 번만 굽는다
var _noise := PackedByteArray()


func _ensure_noise() -> void:
	if _noise.size() == main.MAP_W * main.MAP_H:
		return
	_noise.resize(main.MAP_W * main.MAP_H)
	for y in main.MAP_H:
		var b: int = y * main.MAP_W
		for x in main.MAP_W:
			_noise[b + x] = int(main._hash01(x * 13 + 5, y * 29 + 7) * 255.0)


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
var _reg_plain := PackedByteArray()   # 지역 번호별로 1 = 덧칠할 풀빛이 없다


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
	_reg_plain.resize(_reg_cols.size())
	for i in _reg_cols.size():
		_reg_plain[i] = 1 if _reg_cols[i].a == 0.0 else 0


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


# ---- 구운 지형 그림 ----
#
# 칸 하나가 픽셀 하나다. 지도를 보는 동안 지형은 거의 바뀌지 않으니
# 매 프레임 2만 7천 칸을 다시 칠할 이유가 없다 — 한 번 구워 두고
# 통째로 늘여 그린다.
#
# **혼자 할 때는 열 때 딱 한 번만 굽는다.** 지도를 보는 동안에는 밭에 물을
# 줄 수도, 나무를 벨 수도 없으니 다시 구울 일이 없다. 예전에는 0.5초마다
# 다시 구워, 끌고 있는 도중에 2만 7천 칸을 다시 칠하느라 한 프레임이
# 통째로 튀었다. 함께하는 농장에서는 상대가 세상을 바꾸므로 그대로 둔다.
const BAKE_EVERY := 0.5
var _tex: ImageTexture = null
var _bake_age := 999.0
var bake_us := 0            # 마지막으로 한 장 굽는 데 걸린 시간 (하네스가 본다)


# 지금 다시 구워야 하는가
func _need_bake() -> bool:
	if _tex == null:
		return true
	if not (Net.is_host() or Net.is_guest()):
		return false        # 혼자 볼 때는 열 때 구운 그림 그대로
	return _bake_age > BAKE_EVERY


func _bake() -> void:
	var bt0 := Time.get_ticks_usec()
	_bake_age = 0.0
	# 굽는 것은 **보여 줄 땅뿐이다.** 세계 밖의 튜토리얼 띠는 아예 들어가지 않는다.
	var r := _world()
	var ox: int = r.position.x
	var oy: int = r.position.y
	var w: int = r.size.x
	var h: int = r.size.y
	_ensure_vis_index()
	_ensure_noise()
	if _reg_idx.size() != main.MAP_W * main.MAP_H:
		_build_region_index()
	var buf := PackedByteArray()
	buf.resize(w * h * 3)
	var season := GameData.season()
	# 안 가 본 곳은 어차피 한 색이다 — 통째로 깔아 두고 보이는 칸만 덧칠한다
	var fr := int(FOG.r * 255.0)
	var fg := int(FOG.g * 255.0)
	var fb := int(FOG.b * 255.0)
	# 계절 잔디 바탕 (아래 빠른 갈래가 쓴다)
	var gbase := Color(0.3, 0.5, 0.26)
	if season == GameData.WINTER:
		gbase = Color(0.82, 0.85, 0.9)
	elif season == GameData.FALL:
		gbase = Color(0.62, 0.5, 0.3)
	var gr := int(gbase.r * 255.0)
	var gg := int(gbase.g * 255.0)
	var gb := int(gbase.b * 255.0)
	var ck: int = GameData.EXPLORE_CHUNK
	var i := 0
	# 탐사 여부는 **청크 단위**다 (4x4). 칸마다 묻지 않고 줄마다 한 번씩 모아 둔다
	var cx0: int = ox / ck
	var chunk_ok := PackedByteArray()
	chunk_ok.resize((ox + w) / ck - cx0 + 2)
	var last_cy := -999
	for y in h:
		var wy: int = oy + y
		var cy: int = wy / ck
		if cy != last_cy:
			last_cy = cy
			for cxi in chunk_ok.size():
				chunk_ok[cxi] = 1 if GameData.explored.has(
					Vector2i(cx0 + cxi, cy)) else 0
		var base: int = wy * main.MAP_W
		var grow: Array = main.grid[wy]
		for x in w:
			var wx: int = ox + x
			if chunk_ok[wx / ck - cx0] != 1 or _vis_idx[base + wx] != 1:
				buf[i] = fr
				buf[i + 1] = fg
				buf[i + 2] = fb
				i += 3
				continue
			var cell: Dictionary = grow[wx]
			var nn: int = int(_noise[base + wx]) - 128
			# 지역빛 없는 맨 잔디가 지도의 대부분이다 — 그 칸은 함수를 부르지 않고
			# 계절 바탕에 흔들림만 더한다 (2만 7천 번의 함수 호출이 몇 백 번이 된다)
			if cell.ground == "grass" and _reg_plain[_reg_idx[base + wx]] == 1:
				buf[i] = clampi(gr + nn * 23 / 255, 0, 255)
				buf[i + 1] = clampi(gg + nn * 23 / 255, 0, 255)
				buf[i + 2] = clampi(gb + nn * 23 / 255, 0, 255)
			else:
				var c: Color = _ground_color(cell, wx, wy, season,
					float(nn) / 255.0)
				buf[i] = int(c.r * 255.0)
				buf[i + 1] = int(c.g * 255.0)
				buf[i + 2] = int(c.b * 255.0)
			i += 3
	# 지형지물은 그 칸 색을 덮어쓴다 (가까이 가면 위에 생김새를 얹는다)
	for pos: Vector2i in main.objects:
		if not r.has_point(pos):
			continue
		if not _visible_tile(pos.x, pos.y):
			continue
		var c2: Color = OBJ_COL.get(str(main.objects[pos].kind), OBJ_DEFAULT)
		var j := ((pos.y - oy) * w + (pos.x - ox)) * 3
		buf[j] = int(c2.r * 255.0)
		buf[j + 1] = int(c2.g * 255.0)
		buf[j + 2] = int(c2.b * 255.0)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, buf)
	# 튜토리얼에서 세계로 넘어가면 그림의 크기가 통째로 달라진다 — 그때는 새로 만든다
	if _tex == null or _tex.get_width() != w or _tex.get_height() != h:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	bake_us = Time.get_ticks_usec() - bt0


# 멀리서 볼 때 지형지물이 찍히는 색 (칸 하나 = 점 하나)
const OBJ_DEFAULT := Color(0.5, 0.4, 0.3)
const OBJ_COL := {
	"tree": Color(0.15, 0.35, 0.14), "rock": Color(0.5, 0.5, 0.56),
	"bigrock": Color(0.44, 0.44, 0.5), "searock": Color(0.38, 0.38, 0.44),
	"house": Color(0.66, 0.3, 0.23), "art_block": Color(0.66, 0.3, 0.23),
	"board": Color(0.95, 0.8, 0.35), "sign": Color(0.95, 0.8, 0.35),
	"auction": Color(0.95, 0.8, 0.35), "plotsite": Color(0.9, 0.75, 0.4),
	"homeplot": Color(0.9, 0.75, 0.4), "fence": Color(0.6, 0.45, 0.28),
}


# 마지막으로 한 장 그리는 데 걸린 시간(us). 하네스가 이 값으로
# 「지도를 끌 때 프레임이 떨어지지 않는가」를 지킨다.
var draw_us := 0


func _draw_map() -> void:
	var t0 := Time.get_ticks_usec()
	_taken.clear()
	if _reg_idx.size() != main.MAP_W * main.MAP_H:
		_build_region_index()
	_cell = _base_cell() * zoom
	var o := _origin(_cell)
	_ox = o.x
	_oy = o.y

	# 확대하면 대부분이 화면 밖이므로, 보이는 칸만 그린다 (보여 줄 땅 안에서)
	var wr := _world()
	var x0: int = maxi(wr.position.x, int(floor(-_ox / _cell)))
	var x1: int = mini(wr.end.x, int(ceil((960.0 - _ox) / _cell)) + 1)
	var y0: int = maxi(wr.position.y, int(floor(-_oy / _cell)))
	var y1: int = mini(wr.end.y, int(ceil((540.0 - _oy) / _cell)) + 1)

	# ---- 지형 ----
	#
	# 칸마다 draw_rect를 부르면 배율 1에서 한 프레임에 2만 7천 번이다.
	# 지형은 걸어다니는 동안에나 바뀌지 **지도를 보는 동안에는 거의 그대로**라,
	# 칸 하나를 픽셀 하나로 구운 그림(_bake)을 한 번에 늘여 그린다.
	# 드로우콜이 2만 7천 번에서 **한 번**이 된다 — 끌어도 안 버벅인다.
	if _need_bake():
		_bake()
	canvas.draw_texture_rect(_tex, _world_screen_rect(), false)

	# ---- 지형지물 ----
	#
	# 구운 그림에는 칸 하나가 점 하나로만 들어가 있다. 가까이 들여다볼 때는
	# 생김새를 얹어 준다 — 나무는 잎 두 겹, 바위는 위가 밝은 덩어리,
	# 건물은 몸통 위에 얹힌 지붕. 멀리서 볼 때(칸이 7px 미만)는 어차피
	# 점만 하니 굽힌 색으로 충분하다.
	var cs := _cell
	if cs >= 7.0:
		for pos: Vector2i in main.objects:
			if pos.x < x0 or pos.x >= x1 or pos.y < y0 or pos.y >= y1:
				continue
			if not _visible_tile(pos.x, pos.y):
				continue
			var kind: String = main.objects[pos].kind
			var at := Vector2(_ox + pos.x * cs, _oy + pos.y * cs)
			match kind:
				"tree":
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
						Color(0.76, 0.68, 0.56))
					canvas.draw_rect(Rect2(at.x, at.y, cs + 0.5, maxf(1.0, cs * 0.45)),
						Color(0.66, 0.27, 0.21))
				"board", "sign", "auction", "plotsite", "homeplot":
					canvas.draw_rect(Rect2(at.x + cs * 0.2, at.y + cs * 0.2,
						cs * 0.6, cs * 0.6), Color(0.95, 0.8, 0.35))
				"fence":
					canvas.draw_rect(Rect2(at.x, at.y + cs * 0.3, cs + 0.5,
						maxf(1.0, cs * 0.4)), Color(0.6, 0.45, 0.28))

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
	_draw_clouds(x0, y0, x1, y1)

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
	var edge := _world_screen_rect()
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

	_draw_trim()

	# 안내
	var guide := "휠: 확대·축소 · 끌기: 이동 · R: 처음 크기 · M/ESC: 닫기 (배율 %.1fx)" % zoom
	var w: float = main.UI_FONT.get_string_size(guide, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	canvas.draw_string(main.UI_FONT, Vector2(480 - w / 2.0, 530), guide,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.68, 0.8))
	draw_us = Time.get_ticks_usec() - t0


# ---- 지도의 장식 ----
#
# 종이 지도처럼 보이게 하는 작은 것들 — 네 귀퉁이의 나뭇잎, 왼쪽 아래의
# 나침반 장미, 오른쪽 아래의 작은 범례. 지형 위가 아니라 **화면 가장자리**에
# 그려서 지도를 가리지 않는다.
const COL_LEAF := Color(0.45, 0.62, 0.32)
const COL_INK := Color(0.86, 0.78, 0.58)


func _draw_trim() -> void:
	# 네 귀퉁이 — 작은 나뭇잎 두 장씩
	for c: Vector2 in [Vector2(14, 44), Vector2(946, 44),
			Vector2(14, 500), Vector2(946, 500)]:
		var s: float = -1.0 if c.x > 480.0 else 1.0
		canvas.draw_rect(Rect2(c.x, c.y, 5.0 * s, 3.0), COL_LEAF)
		canvas.draw_rect(Rect2(c.x + 4.0 * s, c.y - 3.0, 4.0 * s, 3.0),
			COL_LEAF.lightened(0.25))

	# 나침반 장미 — 십자 네 갈래 + 북쪽 눈금
	var cc := Vector2(52.0, 460.0)
	canvas.draw_arc(cc, 21.0, 0, TAU, 28, Color(0.62, 0.5, 0.32, 0.85), 2.0)
	canvas.draw_arc(cc, 15.0, 0, TAU, 24, Color(0.62, 0.5, 0.32, 0.5), 1.0)
	for d: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		canvas.draw_line(cc + d * 5.0, cc + d * 19.0, COL_INK, 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([
		cc + Vector2(0, -24), cc + Vector2(-5, -8), cc + Vector2(5, -8)]),
		Color(0.92, 0.5, 0.32))
	canvas.draw_string(main.UI_FONT, cc + Vector2(-5, -26), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.86, 0.5))

	# 범례 — 무엇이 무엇인지 그림으로
	var lx := 800.0
	var ly := 442.0
	var lr := Rect2(lx - 12.0, ly - 20.0, 152.0, 74.0)
	canvas.draw_rect(lr, Color(0.16, 0.12, 0.09, 0.82))
	canvas.draw_rect(lr, Color(0.62, 0.5, 0.32, 0.8), false, 1.0)
	# 내 위치
	canvas.draw_rect(Rect2(lx, ly - 5, 7, 7), Color(1, 1, 1))
	canvas.draw_rect(Rect2(lx + 1, ly - 4, 5, 5), Color(0.95, 0.3, 0.25))
	canvas.draw_string(main.UI_FONT, Vector2(lx + 16, ly + 3), "내 위치",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_INK)
	# 목표 (하트)
	_heart(Vector2(lx + 3, ly + 20), 5.0, Color(0.95, 0.35, 0.45))
	canvas.draw_string(main.UI_FONT, Vector2(lx + 16, ly + 25), "지금 목표",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_INK)
	# 구름 (미탐사)
	canvas.draw_circle(Vector2(lx + 2, ly + 40), 5.0, CLOUD_MID)
	canvas.draw_circle(Vector2(lx + 7, ly + 38), 4.0, CLOUD_TOP)
	canvas.draw_string(main.UI_FONT, Vector2(lx + 16, ly + 46), "아직 안 가 본 곳",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_INK)


# 작은 하트 하나 (범례·길라잡이가 같이 쓴다)
func _heart(c: Vector2, r: float, col: Color) -> void:
	canvas.draw_circle(c + Vector2(-r * 0.5, -r * 0.35), r * 0.62, col)
	canvas.draw_circle(c + Vector2(r * 0.5, -r * 0.35), r * 0.62, col)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 1.05, -r * 0.2), c + Vector2(r * 1.05, -r * 0.2),
		c + Vector2(0, r * 1.15)]), col)


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


# 구름 덩어리는 **화면 넓이에 맞춰 성글게** 찍는다.
#
# 예전에는 가려진 칸 두 개마다 하나씩이라, 배율 1에서 원을 6700개나
# 그렸다 (원 하나가 폴리곤 하나다). 지도를 끌면 그대로 뚝뚝 끊겼다.
# 지금은 화면에 들어오는 칸 수를 보고 간격을 벌린다 — 멀리서 보면
# 큼직한 구름 덩어리, 가까이 가면 잘게 나뉜 구름. 개수는 늘 400개 안쪽이다.
func _draw_clouds(x0: int, y0: int, x1: int, y1: int) -> void:
	var span := maxi(1, (x1 - x0) * (y1 - y0))
	var step := 2
	while span / (step * step) > 400:
		step *= 2
	var scale := float(step) * 0.75          # 성글수록 덩어리도 커진다
	var drift := blink * 0.12                # 아주 느린 흐름
	for ty in range(y0 - (y0 % step), y1, step):
		for tx in range(x0 - (x0 % step), x1, step):
			if tx < 0 or ty < 0 or _visible_tile(tx, ty):
				continue
			var rx := _cloud_rand(tx, ty, 1)
			var ry := _cloud_rand(tx, ty, 2)
			var rs := _cloud_rand(tx, ty, 3)
			var c := Vector2(
				_ox + (float(tx) + float(step) * 0.5 + (rx - 0.5) * 1.1 * step) * _cell,
				_oy + (float(ty) + float(step) * 0.5 + (ry - 0.5) * 1.1 * step) * _cell)
			var wob := sin(drift + float(tx) * 0.7 + float(ty) * 0.4) * _cell * 0.25
			# 덩어리마다 밝기가 조금씩 달라 층이 진 하늘처럼 보인다
			var body := FOG.lerp(CLOUD_MID, 0.45 + rs * 0.55)
			var r1 := _cell * (1.5 + rs * 0.75) * scale
			canvas.draw_circle(c + Vector2(wob, 0.0), r1, body)
			# 빛을 받는 윗면 — 살짝 위로 올려 그린다
			if rs > 0.35:
				canvas.draw_circle(c + Vector2(wob * 0.6, -_cell * (0.5 + rx * 0.3) * scale),
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
