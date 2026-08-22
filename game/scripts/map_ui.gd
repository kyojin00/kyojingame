# 지도 (M): 실제로 가 본 지역만 보여준다 (fog of war).
# 아직 가 보지 않은 곳과 아직 열리지 않은 땅은 **검정 무지**로 덮여 있고,
# 걸어서 탐사하고 이야기가 닿을 때마다 한 조각씩 드러난다.
#
# 조작: 마우스 휠 = 확대/축소 (커서 기준) · 끌기 = 이동 · R = 처음 크기로
extends CanvasLayer

# 배율 1 = 맵 전체가 화면에 딱 들어오는 크기. 맵이 커져도 알아서 맞는다.
# 화면을 최대한 넓게 쓴다 — 위 이름패(34)와 아래 안내줄(22)만 비켜 둔다.
# (예전에는 920x496이라 좌우로 손가락 두 마디씩 빈 자리가 남았다)
const VIEW_W := 952.0
const VIEW_H := 512.0

# 아직 열리지 않은 땅은 **검정 무지**다.
#
# 예전에는 뭉게뭉게한 먹구름을 얹었다. 그런데 배율을 바꾸면 동그라미가
# 커졌다 작아졌다 하며 겉돌아, 가려진 것이 아니라 「위에 뭘 얹어 놓은」
# 것처럼 보였다. 지금은 한 점 비치지 않는 검정 한 색이다 — 무엇이 있는지가
# 아니라 **여기는 아직 내 세계가 아니다**만 말한다.
const FOG := Color(0, 0, 0)
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
	_bake_dirty = true       # 열 때마다 한 장은 반드시 다시 굽는다
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
	# 바다는 늘 보인다.
	#
	# 물 위는 걸어서 탐사할 수가 없으니, 탐사 기록만 보면 남쪽 바다는
	# 영영 검은 구멍으로 남는다. 뭍에 서서도 바다는 보이는 법이라,
	# 능선 아래 물줄은 처음부터 물로 그린다.
	if y >= main.SEA_Y0 and y < main.WORLD_H:
		return true
	if not GameData.is_explored_tile(x, y):
		return false
	if _vis_idx.size() != main.MAP_W * main.MAP_H:
		_ensure_vis_index()      # 낡았는지는 그리기 진입점에서 한 번만 본다
	return _vis_idx[y * main.MAP_W + x] == 1


# 「탐사만 했다면 보이는 칸인가」를 미리 구해 둔다.
#
# 칸마다 묻던 것이 세 가지였다 — 잠긴 확장 구역인가(`is_tile_owned`가 구역
# 목록을 훑는다) · 공용 길인가 · 마을인가. 한 장 굽는 데 2만 7천 번이니
# 그것만으로 백 밀리초가 넘게 들었다. 답이 달라지는 때는 **확장 구역이
# 열릴 때뿐**이라, 그때만 다시 만든다.
var _vis_idx := PackedByteArray()
var _vis_key := ""


# 이 표가 낡았는지 가리는 열쇠 — 확장 구역이 열리거나 야생 지역이 열리면 다시 만든다
func _unlock_key() -> String:
	var open_regions := 0
	for reg: Dictionary in main.REGIONS:
		if GameData.region_unlocked(str(reg.id)):
			open_regions += 1
	return "%d/%d" % [GameData.zones_open.size(), open_regions]


# 표가 낡았는지 확인하고 필요하면 다시 만든다.
# **칸마다 부르면 안 된다** — 열쇠를 만드는 것만으로 지역 목록을 훑는다.
func _ensure_vis_index() -> void:
	if _vis_idx.size() == main.MAP_W * main.MAP_H and _vis_key == _unlock_key():
		return
	_vis_idx.resize(main.MAP_W * main.MAP_H)
	_vis_key = _unlock_key()
	for y in main.MAP_H:
		var base: int = y * main.MAP_W
		for x in main.MAP_W:
			var t := Vector2i(x, y)
			# 못 가는 땅은 지도에도 없다 — 잠긴 확장 구역이든,
			# 아직 이야기가 닿지 않은 야생 지역이든 똑같이 검정이다
			var open: bool = (GameData.is_tile_owned(x, y) or main.ROAD.has_point(t)
				or main.VILLAGE_REGION.has_point(t)) and main.region_open_at(t)
			_vis_idx[base + x] = 1 if open else 0


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
	# ---- 네 배로 넓히며 붙인 고장들 ----
	# 색이 없으면 지도에서 그냥 풀밭이라, 넓힌 땅이 통째로 「빈 데」로 보인다.
	# 고장마다 색이 있어야 지도를 펼친 순간 **세상이 갈라져 보인다**
	"falls": Color(0.34, 0.56, 0.62, 0.38),     # 물안개 낀 골짜기
	"birch": Color(0.62, 0.72, 0.5, 0.32),      # 훤한 자작나무
	"redrock": Color(0.66, 0.4, 0.28, 0.36),    # 붉은 자갈땅
	"reed": Color(0.68, 0.64, 0.4, 0.28),       # 마른 억새
	"starlake": Color(0.3, 0.46, 0.66, 0.34),   # 호수 낀 땅
	"flower": Color(0.72, 0.56, 0.66, 0.3),     # 꽃 핀 들
	"greatwood": Color(0.2, 0.42, 0.22, 0.42),  # 큰나무의 숲
	"boulder": Color(0.5, 0.48, 0.46, 0.34),    # 돌무지 비탈
	"farpine": Color(0.12, 0.26, 0.24, 0.46),   # 세계에서 제일 깊은 숲
	"mist": Color(0.34, 0.46, 0.48, 0.4),       # 안개 낀 늪
	"southfield": Color(0.56, 0.68, 0.4, 0.28), # 남녘 들
	"dune": Color(0.76, 0.7, 0.52, 0.32),       # 바다 앞 모래
	"bramble": Color(0.38, 0.44, 0.26, 0.36),   # 걷기 사나운 잡목
	"willow": Color(0.32, 0.5, 0.4, 0.34),      # 늪가 버들
	"ashen": Color(0.58, 0.56, 0.52, 0.32),     # 색 없는 땅
	"eastedge": Color(0.46, 0.5, 0.54, 0.34),   # 세계의 동쪽 끝
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
var _bake_dirty := true     # 지도를 열 때마다 켜진다 (그 사이 세상이 달라졌다)
var bake_us := 0            # 마지막으로 한 장 굽는 데 걸린 시간 (하네스가 본다)

# ---- 지도에 얹는 **작은 그림**의 자리 ----
#
# 참고 지도(스타듀)가 「그 게임의 지도」로 보이는 까닭은 나무가 나무 모양,
# 집이 집 모양으로 그려져 있어서다. 그런데 세계에는 나무가 만 그루가 넘어,
# 한 그루씩 그리면 한 프레임에 이만 번을 그리게 된다.
#
# 지도는 **census 가 아니라 삽화**다. 세 칸씩 묶어 그 안에 무엇이 있었는지만
# 남기고, 묶음 하나에 그림 하나를 얹는다. 숲의 **밀도**는 그대로 읽히면서
# 그리는 횟수는 아홉 분의 일이 된다. 굽는 김에 같이 만들어 둔다.
# 몇 칸을 한 그림으로 묶는가. 셋이면 한 장에 1만 1천us, 넷이면 9천5백 —
# 한도가 8천이라 다섯으로 묶는다. 세계를 통째로 펼친 배율에서도 도장이
# 삼천 개면 되고, 그래도 숲은 숲으로 읽힌다 (지도는 census 가 아니다)
const ICO_K := 5
const ICO_NONE := 0
const ICO_TREE := 1
const ICO_ROCK := 2
const ICO_FENCE := 3
const ICO_SIGN := 4
const ICO_CAVE := 5
var _ico := PackedByteArray()
var _ico_w := 0
var _ico_h := 0
var _houses: Array = []     # 건물 왼위 모서리 (한 채는 한 번만 그린다)
const STAMP_NAME := ["", "tree", "rock", "", "sign", "cave"]


# 지금 다시 구워야 하는가.
#
# 「혼자 할 때는 한 번만」을 `_bake_age`로 눌러 뒀더니, 혼자 하는 동안에는
# `_tex`가 있는 한 **영영 다시 굽지 않았다.** 튜토리얼 숲길에서 한 번 구운
# 62x38짜리 그림이 마을에 와서도 그대로 남아, 세계 크기(224x120)의 자리에
# 늘여 그려졌다 — 지형은 한가운데 뭉쳐 있고 내 위치만 엉뚱한 데 찍히던
# 그 화면이다. 이제 **열 때마다 한 번**은 반드시 다시 굽고, 그림 크기가
# 보여 줄 땅과 다르면 무조건 다시 굽는다.
func _need_bake() -> bool:
	if _tex == null or _bake_dirty:
		return true
	var r := _world()
	if _tex.get_size() != Vector2(r.size.x, r.size.y):
		return true
	if not (Net.is_host() or Net.is_guest()):
		return false        # 혼자 볼 때는 열어 둔 동안 그 그림 그대로
	return _bake_age > BAKE_EVERY


func _bake() -> void:
	var bt0 := Time.get_ticks_usec()
	_bake_age = 0.0
	_bake_dirty = false
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
	# 바탕 초록을 한 단 올린다. 삽화 지도는 **밝다** — 어두운 초록 위에
	# 어두운 나무 도장을 찍으면 숲이 얼룩으로 뭉개진다
	var gbase := Color(0.38, 0.60, 0.31)
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
	_ico_w = (w + ICO_K - 1) / ICO_K
	_ico_h = (h + ICO_K - 1) / ICO_K
	_ico.resize(_ico_w * _ico_h)
	_ico.fill(ICO_NONE)
	_houses.clear()
	for pos: Vector2i in main.objects:
		if not r.has_point(pos):
			continue
		if _vis_idx[pos.y * main.MAP_W + pos.x] != 1 \
				or not GameData.is_explored_tile(pos.x, pos.y):
			continue
		var k2: String = str(main.objects[pos].kind)
		var c2: Color = OBJ_COL.get(k2, OBJ_DEFAULT)
		var j := ((pos.y - oy) * w + (pos.x - ox)) * 3
		buf[j] = int(c2.r * 255.0)
		buf[j + 1] = int(c2.g * 255.0)
		buf[j + 2] = int(c2.b * 255.0)
		# 얹을 그림의 자리 — 세 칸 묶음마다 하나
		var code := ICO_NONE
		match k2:
			"tree": code = ICO_TREE
			"rock", "bigrock", "searock": code = ICO_ROCK
			"fence": code = ICO_FENCE
			"board", "sign", "auction", "plotsite", "homeplot": code = ICO_SIGN
			"cave": code = ICO_CAVE
			"house", "chief_hut", "barn":
				# 한 채는 5x4칸이다. **왼위 모서리에서만** 한 번 담는다 —
				# 칸마다 담으면 마을이 지붕 스무 장 겹친 덩어리가 된다
				if k2 == "house":
					if not (_is_house(pos.x - 1, pos.y) or _is_house(pos.x, pos.y - 1)):
						_houses.append(pos)
				else:
					_houses.append(pos - Vector2i(2, 3))
		if code == ICO_NONE:
			continue
		var bi: int = ((pos.y - oy) / ICO_K) * _ico_w + (pos.x - ox) / ICO_K
		# 나무가 다른 것을 이긴다 — 숲은 숲으로 읽혀야 한다
		if _ico[bi] == ICO_NONE or code == ICO_TREE:
			_ico[bi] = code
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
	"house": Color(0.72, 0.62, 0.5), "art_block": Color(0.66, 0.6, 0.5),
	"chief_hut": Color(0.72, 0.62, 0.5), "barn": Color(0.72, 0.62, 0.5),
	"board": Color(0.95, 0.8, 0.35), "sign": Color(0.95, 0.8, 0.35),
	"auction": Color(0.95, 0.8, 0.35), "plotsite": Color(0.9, 0.75, 0.4),
	"homeplot": Color(0.9, 0.75, 0.4), "fence": Color(0.6, 0.45, 0.28),
}


# ---- 지도를 「그림」으로 ----
#
# 지도가 칸마다 색을 찍은 **도표**였다. 참고로 받은 지도(스타듀)가 한눈에
# 읽히는 까닭은 정보가 많아서가 아니라, 세상에 있는 것이 **작은 그림**으로
# 그려져 있어서다 — 나무는 나무 모양, 집은 지붕과 문이 있는 집 모양.
#
# 세 가지를 지킨다.
#   ① 윤곽선   그림마다 검은 테를 두른다. 테가 없으면 바탕에 스민다
#   ② 두 톤    잎도 벽도 밝은 면과 그늘 두 단. 한 색은 색종이다
#   ③ 한 채는 한 번  집은 5x4칸인데 칸마다 그리면 지붕 스무 장이 겹친다
const INK := Color(0.10, 0.09, 0.12)
# 지붕색 — 마을이 한 가지 색이면 집이 아니라 무늬가 된다. 자리로 고른다
const ROOFS := [Color(0.78, 0.29, 0.22), Color(0.62, 0.34, 0.24),
	Color(0.36, 0.44, 0.56), Color(0.44, 0.52, 0.34), Color(0.70, 0.46, 0.22)]


func _is_house(x: int, y: int) -> bool:
	return str(main.objects.get(Vector2i(x, y), {}).get("kind", "")) in \
		["house", "art_block"]


# 나무 한 그루 — 밑동 위에 잎 두 겹. 그루마다 크기와 자리를 조금씩 흔든다
func _mini_tree(at: Vector2, cs: float, pos: Vector2i) -> void:
	var jx: float = (main._hash01(pos.x * 7 + 1, pos.y * 11 + 3) - 0.5) * cs * 0.34
	var jy: float = (main._hash01(pos.x * 13 + 5, pos.y * 17 + 2) - 0.5) * cs * 0.22
	var r: float = cs * (0.44 + main._hash01(pos.x * 5 + 9, pos.y * 3 + 7) * 0.16)
	var c := Vector2(at.x + cs * 0.5 + jx, at.y + cs * 0.44 + jy)
	# **멀리서는 싸게 그린다.** 한 그루에 여섯 번씩 부르면 화면에 삼천 그루가
	# 뜨는 배율에서 한 프레임이 무너진다 — 작아서 어차피 안 보일 것은 안 그린다
	if cs < 8.0:
		canvas.draw_circle(c, r, INK)
		canvas.draw_circle(c - Vector2(r * 0.16, r * 0.2), r * 0.78,
			Color(0.24, 0.47, 0.21))
		return
	# 밑동 — 잎보다 먼저. 잎이 밑동의 어깨를 덮어야 한 그루가 된다
	canvas.draw_rect(Rect2(c.x - cs * 0.13, c.y, cs * 0.26, cs * 0.62), INK)
	canvas.draw_rect(Rect2(c.x - cs * 0.09, c.y, cs * 0.18, cs * 0.56),
		Color(0.36, 0.24, 0.15))
	canvas.draw_circle(c, r, INK)
	canvas.draw_circle(c, r - maxf(1.0, cs * 0.09), Color(0.16, 0.36, 0.17))
	canvas.draw_circle(c - Vector2(r * 0.22, r * 0.26), r * 0.62,
		Color(0.28, 0.53, 0.24))
	canvas.draw_circle(c - Vector2(r * 0.34, r * 0.38), r * 0.28,
		Color(0.40, 0.66, 0.31))


# ---- 멀리서 볼 때 쓰는 **그림 도장** ----
#
# 세 칸 묶음마다 draw_circle 로 나무를 그렸더니 한 장에 2만 4천us 가 나왔다
# (한도 8천). 원은 그릴 때마다 다각형으로 잘게 쪼개지는데, 화면에 도장이
# 팔천 개면 그 쪼개기가 팔천 번이다.
#
# 그림은 어차피 다 똑같다 — **한 번 구워 두고 도장처럼 찍는다.**
# 텍스처 사각형 하나는 꼭짓점 넷이라, 같은 텍스처끼리 묶여 나간다.
var _stamp := {}


func _stamp_of(name: String) -> ImageTexture:
	if _stamp.has(name):
		return _stamp[name]
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n * 0.5, n * 0.44)
	var put := func(p: Vector2, r: float, col: Color) -> void:
		for y in range(maxi(0, int(p.y - r) - 1), mini(n, int(p.y + r) + 2)):
			for x in range(maxi(0, int(p.x - r) - 1), mini(n, int(p.x + r) + 2)):
				if Vector2(x + 0.5, y + 0.5).distance_to(p) <= r:
					img.set_pixel(x, y, col)
	match name:
		"tree":
			# 밑동 — 잎보다 먼저. 잎이 어깨를 덮어야 한 그루가 된다
			for y in range(int(c.y), n - 2):
				for x in range(int(c.x) - 2, int(c.x) + 2):
					img.set_pixel(x, y, INK)
			for y in range(int(c.y), n - 3):
				for x in range(int(c.x) - 1, int(c.x) + 1):
					img.set_pixel(x, y, Color(0.36, 0.24, 0.15))
			put.call(c, n * 0.42, INK)
			put.call(c, n * 0.36, Color(0.16, 0.36, 0.17))
			put.call(c - Vector2(n * 0.08, n * 0.09), n * 0.24, Color(0.28, 0.53, 0.24))
			put.call(c - Vector2(n * 0.13, n * 0.14), n * 0.11, Color(0.40, 0.66, 0.31))
		"rock":
			put.call(c, n * 0.40, INK)
			put.call(c, n * 0.34, Color(0.46, 0.46, 0.52))
			put.call(c - Vector2(n * 0.09, n * 0.10), n * 0.16, Color(0.68, 0.68, 0.74))
		"sign":
			for y in range(4, 15):
				for x in range(5, 19):
					img.set_pixel(x, y, INK if (y < 6 or y > 12 or x < 7 or x > 16)
						else Color(0.95, 0.8, 0.35))
			for y in range(15, n - 2):
				for x in range(11, 13):
					img.set_pixel(x, y, Color(0.42, 0.28, 0.16))
		"cave":
			put.call(c, n * 0.44, INK)
			put.call(c, n * 0.38, Color(0.40, 0.38, 0.42))
			put.call(c + Vector2(0, n * 0.10), n * 0.20, Color(0.08, 0.07, 0.10))
	var t := ImageTexture.create_from_image(img)
	_stamp[name] = t
	return t


# 바위 · 표지판 · 동굴 — 나무·집과 같은 규칙(테 + 두 톤)으로
func _mini_rock(at: Vector2, cs: float) -> void:
	var rc := Vector2(at.x + cs * 0.5, at.y + cs * 0.55)
	canvas.draw_circle(rc, cs * 0.46, INK)
	canvas.draw_circle(rc, cs * 0.46 - maxf(1.0, cs * 0.08), Color(0.46, 0.46, 0.52))
	canvas.draw_circle(rc - Vector2(cs * 0.11, cs * 0.13), cs * 0.24,
		Color(0.68, 0.68, 0.74))


func _mini_sign(at: Vector2, cs: float) -> void:
	var sp := Vector2(at.x + cs * 0.5, at.y + cs * 0.35)
	canvas.draw_rect(Rect2(sp.x - cs * 0.34, sp.y - cs * 0.3,
		cs * 0.68, cs * 0.6), INK)
	canvas.draw_rect(Rect2(sp.x - cs * 0.24, sp.y - cs * 0.2,
		cs * 0.48, cs * 0.4), Color(0.95, 0.8, 0.35))
	canvas.draw_rect(Rect2(sp.x - cs * 0.08, sp.y + cs * 0.3,
		maxf(1.0, cs * 0.16), cs * 0.5), Color(0.42, 0.28, 0.16))


func _mini_cave(at: Vector2, cs: float) -> void:
	var cc := Vector2(at.x + cs * 0.5, at.y + cs * 0.5)
	canvas.draw_circle(cc, cs * 0.6, INK)
	canvas.draw_circle(cc, cs * 0.6 - maxf(1.0, cs * 0.1), Color(0.4, 0.38, 0.42))
	canvas.draw_circle(cc + Vector2(0, cs * 0.14), cs * 0.3, Color(0.08, 0.07, 0.1))


# 집 한 채 — 벽 위에 박공 지붕, 문 하나 창 하나. 테를 두른다
func _mini_house(p: Vector2, w: float, h: float, pos: Vector2i) -> void:
	var roof: Color = ROOFS[int(main._hash01(pos.x * 3 + 2, pos.y * 5 + 1) * 5.0) % 5]
	var wall := Color(0.88, 0.82, 0.68)
	var bx: float = p.x + w * 0.14
	var bw: float = w * 0.72
	var by: float = p.y + h * 0.44
	var bh: float = h * 0.56
	canvas.draw_rect(Rect2(bx - 1.0, by - 1.0, bw + 2.0, bh + 2.0), INK)
	canvas.draw_rect(Rect2(bx, by, bw, bh), wall)
	canvas.draw_rect(Rect2(bx, by + bh * 0.62, bw, bh * 0.38),
		wall.darkened(0.16))
	# 지붕 — 처마가 벽보다 넓게 나온다. 그래야 얹힌 것으로 보인다
	var apex := Vector2(p.x + w * 0.5, p.y + h * 0.04)
	var le := Vector2(p.x + w * 0.03, by + h * 0.04)
	var re := Vector2(p.x + w * 0.97, by + h * 0.04)
	canvas.draw_colored_polygon(PackedVector2Array([
		apex + Vector2(0, -2), le + Vector2(-2, 2), re + Vector2(2, 2)]), INK)
	canvas.draw_colored_polygon(PackedVector2Array([apex, le, re]), roof)
	canvas.draw_colored_polygon(PackedVector2Array([
		apex, le, Vector2(p.x + w * 0.5, by + h * 0.04)]), roof.lightened(0.14))
	# 문과 창
	var dw: float = maxf(1.0, w * 0.13)
	canvas.draw_rect(Rect2(p.x + w * 0.5 - dw * 0.5, by + bh - bh * 0.52,
		dw, bh * 0.52), Color(0.34, 0.22, 0.14))
	if w >= 26.0:
		var ww: float = w * 0.1
		canvas.draw_rect(Rect2(bx + bw * 0.16, by + bh * 0.24, ww, ww),
			Color(0.55, 0.74, 0.82))
		canvas.draw_rect(Rect2(bx + bw * 0.84 - ww, by + bh * 0.24, ww, ww),
			Color(0.55, 0.74, 0.82))


# 마지막으로 한 장 그리는 데 걸린 시간(us). 하네스가 이 값으로
# 「지도를 끌 때 프레임이 떨어지지 않는가」를 지킨다.
var draw_us := 0


func _draw_map() -> void:
	var t0 := Time.get_ticks_usec()
	_taken.clear()
	if _reg_idx.size() != main.MAP_W * main.MAP_H:
		_build_region_index()
	_ensure_vis_index()          # 한 장 그리기 전에 한 번 — 칸마다 보지 않는다
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
	# ---- 얹는 그림 ----
	#
	# 가까이 볼 때는 물건 하나하나에 생김새를 얹고, 멀리서 볼 때는 **세 칸
	# 묶음**(_ico)에 하나씩 얹는다. 지도는 census 가 아니라 삽화라, 숲의
	# 밀도만 읽히면 나무 만 그루를 다 그릴 이유가 없다.
	var wr2 := _world()
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
					_mini_tree(at, cs, pos)
				"rock", "bigrock":
					_mini_rock(at, cs * (1.15 if kind == "bigrock" else 0.9))
				"board", "sign", "auction", "plotsite", "homeplot":
					_mini_sign(at, cs)
				"fence":
					canvas.draw_rect(Rect2(at.x, at.y + cs * 0.34, cs + 0.5,
						maxf(1.0, cs * 0.3)), Color(0.45, 0.32, 0.19))
					canvas.draw_rect(Rect2(at.x, at.y + cs * 0.38, cs + 0.5,
						maxf(1.0, cs * 0.18)), Color(0.66, 0.5, 0.31))
				"cave":
					_mini_cave(at, cs)
	elif _ico_w > 0:
		var k := float(ICO_K)
		var bx0: int = maxi(0, (x0 - wr2.position.x) / ICO_K)
		var bx1: int = mini(_ico_w, (x1 - wr2.position.x) / ICO_K + 1)
		var by0: int = maxi(0, (y0 - wr2.position.y) / ICO_K)
		var by1: int = mini(_ico_h, (y1 - wr2.position.y) / ICO_K + 1)
		var ics: float = cs * k
		# **더 줄여야 할 때가 있다.** 배율을 끝까지 줄이면 묶음이 육천 개가
		# 넘는다. 그때는 한 칸씩 건너뛰고 도장을 그만큼 키운다 — 덮는 넓이가
		# 같으니 숲의 밀도는 그대로고, 그리는 횟수만 사분의 일이 된다
		var stride := 1
		if (bx1 - bx0) * (by1 - by0) > 3400:
			stride = 2
		ics *= stride
		for by in range(by0, by1, stride):
			var row: int = by * _ico_w
			for bx in range(bx0, bx1, stride):
				var code: int = _ico[row + bx]
				if code == ICO_NONE:
					continue
				var tp := Vector2i(wr2.position.x + bx * ICO_K,
					wr2.position.y + by * ICO_K)
				var at2 := Vector2(_ox + tp.x * cs, _oy + tp.y * cs)
				# **바위는 안 찍는다.** 세계에 흩어진 돌이 나무보다 많아서,
				# 도장을 찍었더니 지도가 통째로 **회색 자갈밭**이 됐다 —
				# 마을도 숲도 그 밑에 묻혔다. 돌은 굽힌 바탕색으로 족하고,
				# 생김새는 가까이 들여다볼 때(칸 7px 이상)만 얹는다
				if code == ICO_ROCK:
					continue
				if code == ICO_FENCE:
					canvas.draw_rect(Rect2(at2.x, at2.y + ics * 0.36,
						ics, maxf(1.0, ics * 0.22)), Color(0.5, 0.36, 0.21))
					continue
				var st: ImageTexture = _stamp_of(STAMP_NAME[code])
				# 도장마다 조금씩 크기와 자리를 흔든다 — 자로 잰 듯 찍으면
				# 숲이 아니라 바둑판이다
				var jj: float = main._hash01(tp.x * 7 + 1, tp.y * 11 + 3)
				var sz: float = ics * (0.98 + jj * 0.3)
				# 낯빛도 그루마다 조금씩 — 통짜 초록은 잔디밭이지 숲이 아니다
				var tint := Color(1, 1, 1)
				if code == ICO_TREE:
					var v: float = main._hash01(tp.x * 19 + 4, tp.y * 23 + 8)
					tint = Color(0.90 + v * 0.24, 0.92 + v * 0.2, 0.86 + v * 0.24)
				canvas.draw_texture_rect(st, Rect2(
					at2.x + (ics - sz) * 0.5 + (jj - 0.5) * ics * 0.22,
					at2.y + (ics - sz) * 0.5 + (main._hash01(tp.x * 13 + 5,
						tp.y * 17 + 2) - 0.5) * ics * 0.16,
					sz, sz), false, tint)
	# 집은 **배율과 상관없이** 그린다. 마을이 열 채뿐이라 값이 싸고,
	# 지붕 열 장이 보여야 지도가 「우리 마을」이 된다
	for a2: Vector2i in _houses:
		if a2.x < x0 - 6 or a2.x >= x1 + 6 or a2.y < y0 - 6 or a2.y >= y1 + 6:
			continue
		_mini_house(Vector2(_ox + a2.x * cs, _oy + a2.y * cs),
			maxf(14.0, cs * 5.0), maxf(12.0, cs * 4.0), a2)

	# 동물/NPC (보이는 지역만)
	var dot: float = maxf(3.0, _cell * 0.5)
	for a in main.animals:
		if _visible_tile(int(a.position.x / 32.0), int(a.position.y / 32.0)):
			_dot(a.position, dot, Color(0.95, 0.95, 0.9))
	for n in main.npcs:
		if n.visible and _visible_tile(int(n.position.x / 32.0), int(n.position.y / 32.0)):
			_dot(n.position, dot, Color(0.95, 0.55, 0.75))

	# 시설 라벨 (그 위치를 발견했을 때만).
	#
	# 자리는 **상수에서 뽑는다.** 예전에는 숫자를 그대로 적어 두었는데,
	# 세계를 북쪽으로 열두 줄 내렸을 때 이 라벨들만 제자리에 남아
	# 「동굴」이 세계 맨 윗줄에, 「중앙 광장」이 이장집 위에 찍혔다.
	_place_label(main.HOME_SITE.x - 2, main.HOME_SITE.y - 2, "우리집")
	_place_label(main.START_TILE.x + 4, main.START_TILE.y + 4, "농장")
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
	_place_label(main.PLAZA.get_center().x - 3, main.PLAZA.get_center().y - 3, "중앙 광장")
	_place_label(main.FISH_SPOT.get_center().x - 3,
		main.FISH_SPOT.get_center().y - 1, "호수 낚시터")
	if main.CAVE_PLACED:
		_place_label(main.CAVE_POS.x, main.CAVE_POS.y, "동굴")
	# 고장의 랜드마크 — 가 본 곳이면 **금빛 마름모**로 찍는다.
	#
	# 지역 이름표는 지역 한가운데에 붙지만, 랜드마크는 정확히 그 자리를
	# 알려 줘야 한다. 세계가 네 배가 된 뒤로는 「그 고장 어딘가」로는
	# 못 찾는다 — 열두 칸짜리 그림도 448칸 안에서는 점 하나다.
	for lm: Dictionary in main.LANDMARKS:
		var lt: Vector2i = lm.tile
		if not _visible_tile(lt.x, lt.y):
			continue
		var lp := Vector2(_ox + lt.x * _cell + _cell * 0.5, _oy + lt.y * _cell)
		var d: float = maxf(5.0, _cell * 1.6)
		canvas.draw_colored_polygon(PackedVector2Array([
			lp + Vector2(0, -d), lp + Vector2(d, 0),
			lp + Vector2(0, d), lp + Vector2(-d, 0)]), Color(0.16, 0.12, 0.06))
		canvas.draw_colored_polygon(PackedVector2Array([
			lp + Vector2(0, -d + 2), lp + Vector2(d - 2, 0),
			lp + Vector2(0, d - 2), lp + Vector2(-d + 2, 0)]), Color(1.0, 0.84, 0.36))
		_label(lp + Vector2(0, -d - 4.0), str(lm.name), 22, true)
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

	# 아직 열리지 않은 칸은 구운 그림에서 이미 검정으로 칠해져 있다 —
	# 위에 따로 얹을 것이 없다 (예전의 구름 덩어리는 없앴다)

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
	var plate := map_plate()
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


# 지도 맨 위 이름패.
#
# 튜토리얼 동안에는 **마을 이름을 쓰지 않는다** — 주인공은 아직 교진 마을을
# 본 적도 들은 적도 없다. 지나가는 숲길일 뿐이다.
func map_plate() -> String:
	if GameData.tutorial_space:
		return "마을로 가는 숲길"
	return "%s · %s" % [GameData.village_title(), GameData.farm_title()]


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
	# 검정 (아직 열리지 않은 땅)
	canvas.draw_rect(Rect2(lx - 2, ly + 34, 12, 10), FOG)
	canvas.draw_rect(Rect2(lx - 2, ly + 34, 12, 10), Color(0.4, 0.36, 0.3), false, 1.0)
	canvas.draw_string(main.UI_FONT, Vector2(lx + 16, ly + 46), "아직 못 가는 곳",
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
			# 밭을 만들 자리 — 「어디를 갈지?」를 지도가 대신 말한다
			# (「첫 상점을 세울 자리」는 없앴다 — 가게는 처음부터 다 열려 있다)
			if GameData.story2_phase == "farm" and GameData.tool_slots.has("hoe"):
				return main.HOME_ANCHOR + Vector2i(2, 5)
		"move":
			if GameData.move_quest == "postbuild":
				return _plot_center("post")
		"story10", "story11":
			if GameData.story11_phase == "deep" or GameData.story10_phase == "dig":
				return main.CAVE_POS if main.CAVE_PLACED else Vector2i(-999, -999)
		"story13":
			if GameData.story13_phase in ["rock", "fish"]:
				return main.BRACELET_ROCK
		"story15":
			if GameData.story15_phase == "dig":
				return main.CAVE_POS if main.CAVE_PLACED else Vector2i(-999, -999)
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
				return main.CAVE_POS if main.CAVE_PLACED else Vector2i(-999, -999)
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
				return main.door_tile(main.VILLAGE_PLOTS["general"].anchor)
		"tutorial":
			if GameData.tutorial_current_flag() == "cook":
				return main.HOME_ANCHOR + Vector2i(2, 3)
	return Vector2i(-1, -1)


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
