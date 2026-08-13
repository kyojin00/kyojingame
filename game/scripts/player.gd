# 플레이어: 수동 타일 충돌 이동 + 방향별 걷기 애니메이션
extends Node2D

const SPEED := 150.0  # 아트 픽셀/초
const R := 6.0       # 발 밑 충돌 반경

var main: Node2D
var dir := "down"
var moving := false
var anim_time := 0.0
var step_timer := 0.0
var step_alt := false
var walked := 0.0  # 이동 체크용 누적 거리
var bumped := false  # 이동하려 했지만 완전히 막혔는가 (스토리 연출용)

@onready var sprite: Sprite2D = $Sprite

# ---- 탈 것 ----
#
# 캐릭터 도트에 「타는」 자세가 없다. 그래서 두 가지로 앉힌 것처럼 만든다:
#
#   1. 상체만 남기고 잘라(region_rect) 말 등 높이에 얹는다.
#      잘린 자리는 말 몸통이 가려서 다리가 몸통 뒤로 넘어간 것처럼 보인다.
#   2. 걷기 프레임을 쓰지 않는다. 안 그러면 말 위에서 걸어다닌다.
#      대신 말 걸음에 맞춰 몸이 오르내린다.
#
# 캐릭터 도트: 128x192, 내용은 12~191행, 0.5배로 그린다 (발이 원점).
# 그래서 텍스처 r행은 발밑 기준 (r - 188) * 0.5 만큼 위에 온다.
const HORSE_SCALE := 1.15
const RIDER_ROWS := 192.0      # 캐릭터 텍스처 세로
const RIDER_FOOT := 188.0      # 발이 놓이는 행 (scenes/player.tscn의 offset)

# 방향별 —
#   foot  말 발굽이 있는 텍스처 행 (여기를 땅에 맞춘다. 앞/뒤/옆이 다르다)
#   seat  안장 높이. 캐릭터를 자른 자리가 여기 온다 (발밑 기준 월드 y)
#   cut   캐릭터를 잘라 낼 텍스처 행. 작을수록 상체만 남는다
#
# 말은 늘 캐릭터보다 뒤에 그린다. 앞모습일 때 말을 앞에 그려 보았는데
# (이쪽을 보는 말이니 머리가 더 가깝다), 지금 말 그림은 머리가 위로 길어서
# 사람이 통째로 가려졌다. 제대로 하려면 머리를 낮춘 앞모습 도트가 필요하다.
const HORSE_POSE := {
	"down": {"foot": 79, "seat": -50.0, "cut": 120},
	"up": {"foot": 79, "seat": -54.0, "cut": 116},
	"side": {"foot": 77, "seat": -52.0, "cut": 118},
}

# 탈 것: 캐릭터 밑에 깔리는 말 그림 (탔을 때만 보인다)
var horse_sprite: Sprite2D

# ---- 도구 휘두르기 ----
#
# 캐릭터 도트에는 아직 「휘두르는」 프레임이 없다 (서기 + 걷기 4프레임뿐).
# 그래서 네 가지를 겹쳐 동작을 만든다:
#
#   1. 몸    허리를 축으로 **상체만** 감았다 내리친다 (다리는 붙박이)
#   2. 도구  손 높이에서 호를 그리고, 빠른 구간에 잔상을 남긴다
#   3. 무게  내리치는 쪽으로 몸이 몇 px 쏠렸다 돌아온다
#   4. 눌림  닿는 순간 몸이 살짝 주저앉는다
#
# 자연스러움은 그림보다 **완급**에서 나온다. 감아올리기는 길고 느리게
# (예비동작), 내리치기는 두세 프레임에 끝내고, 닿는 순간 잠깐 멈췄다가
# (히트스톱) 천천히 돌아온다. 그 완급은 `_swing_curve` 하나가 쥐고 있다.
#
# **내리치는 정점(+1)을 main.HIT_AT에 맞춰 둔다.** 예전에는 정점이 0.17초인데
# 판정은 0.15초에 나서, 도끼가 아직 내려오는 중에 나무가 맞았다.
#
# ---- 휘두르기 도트 ----
#
# 남자 캐릭터는 `assets/ref/dot_boy/make_sprites.py`가 방향당 네 장을 그린다
# (`new_boy_<방향>_swing_0..3` = 감기 시작 · 다 감음 · 내리침 · 되돌아옴).
# 여자 캐릭터는 아직 없어서 `_swing_frame`이 ""를 돌려주고, 그때는 아래
# 몸통 회전으로 대신한다. 도트를 뽑아 이름만 맞추면 그날부터 켜진다.
#
# 도트가 있으면 **몸을 가르지 않는다**. 그림이 이미 굽힌 자세라 거기에
# 상체 회전을 또 얹으면 두 번 굽는다.
const SWING_WAIST := 136        # 상·하체를 자르는 텍스처 행 (주먹 아래 · 반바지 한가운데)
const SWING_OVERLAP := 9        # 상체를 이만큼 더 아래까지 그린다 (자른 자국을 덮는다)
const SWING_LEAN := 0.34        # 상체가 감겼다 펴지는 최대 각(라디안)
const SWING_LEAN_DOT := 0.05    # 휘두르기 도트가 있을 때 (도트가 자세를 맡는다)
const SWING_SHIFT := 5.0        # 내리치는 쪽으로 몸이 쏠리는 거리(px)
const SWING_SQUASH := 0.06      # 닿는 순간 몸이 눌리는 정도
const SWING_HOLD := 0.10        # 히트스톱: 정점에서 머무는 구간 (진행도 0~1 기준)
const SWING_TRAIL := 6          # 도구 잔상으로 남기는 자취 수
const SWING_FRAMES := 4         # 방향당 휘두르기 도트 장수

# 방향마다 손이 있는 자리와 휘두르는 폭이 다르다.
#   hand   손잡이 끝이 오는 자리 (발밑 기준 node 좌표. x는 sign_x로 뒤집힌다)
#   mid    호의 한가운데 각. 여기서 arc/2 만큼 위(감음)·아래(내리침)로 벌어진다.
#          0은 「위로 곧게 선 도구」다 (도구 그림이 손잡이 끝을 축으로 위를 본다)
#   arc    도구가 그리는 호 전체(라디안)
#   tilt   상체를 굽히는 정도 (뒷모습은 팔이 안 보여 조금 덜 굽힌다)
#   shift  무게가 쏠리는 방향
#   spin   도구가 도는 쪽. 앞·옆은 왼쪽에서 감아 오른쪽으로 내리치는데
#          **뒷모습만 반대**다 — 등을 보이고 몸을 비틀어 치는 그림이라
#          주먹이 오른쪽 위에서 왼쪽 아래로 간다 (도트를 재 보면 그렇다).
const SWING_POSE := {
	"down": {"hand": Vector2(10, -36), "mid": 0.85, "arc": 2.6, "tilt": 1.0,
		"shift": Vector2(1, 3), "spin": 1.0},
	"up": {"hand": Vector2(-9, -40), "mid": 0.80, "arc": 2.4, "tilt": 0.75,
		"shift": Vector2(1, -3), "spin": -1.0},
	"side": {"hand": Vector2(12, -38), "mid": 0.95, "arc": 2.9, "tilt": 1.0,
		"shift": Vector2(5, 1), "spin": 1.0},
}
# 휘두르기 도트가 있을 때, 위상마다 **주먹이 실제로 가 있는 자리**.
# 도구 손잡이 끝을 여기 얹는다. node 좌표 = 그림이 화면에 나온 크기 기준이라
# 도트 좌표의 절반이다 (스프라이트를 0.5배로 그린다).
#
#   도트에서 읽은 값 (발밑 가운데가 원점) -> 여기 적는 값
#   node.x = 도트.x / 2 ,  node.y = (도트.y + 2) / 2      (offset -64,-188 · 0.5배)
#
# 값은 `assets/ref/dot_boy/make_sprites.py`가 주먹을 그린 자리에서 계산해
# 실행 끝에 찍어 준다 — **그림을 다시 뽑으면 찍힌 값을 여기 그대로 옮긴다.**
# 안 맞으면 도구가 손에서 뜬다. 도트가 없는 방향은 SWING_POSE의 식을 쓴다.
const SWING_HAND_DOT := {
	# 감기 시작 · 다 감음(머리 옆) · 내리침 · 되돌아옴
	"side": [Vector2(-16.5, -55), Vector2(-16.5, -67), Vector2(19.5, -22), Vector2(16.5, -34)],
	"down": [Vector2(-19.5, -52), Vector2(-19.5, -70), Vector2(13.5, -34), Vector2(10.5, -37)],
	"up": [Vector2(19.5, -55), Vector2(19.5, -70), Vector2(-1.5, -88), Vector2(19.5, -61)],
}
const TOOL_ICONS := {
	"axe": "icon_axe", "pickaxe": "icon_pickaxe",
	"hoe": "icon_hoe", "water": "icon_water",
}
# 도구 그림마다 자루가 놓인 방향이 다르다. 곡괭이·호미·물뿌리개는 자루가
# **왼쪽 아래**에서 머리가 오른쪽 위로 가는데 **도끼만 반대**다
# (자루 오른쪽 아래 - 날 왼쪽 위). 그대로 쓰면 오른쪽을 보고 휘두를 때
# 날이 등 뒤를 향한다. 가방 아이콘은 그대로 두고 **휘두를 때만** 뒤집는다.
const TOOL_MIRROR := ["axe"]
# 도구를 **쥐는 자리** (아이콘 그림 안의 픽셀). 여기를 축으로 돌리고,
# 여기가 주먹에 온다. 32x32 칸의 한가운데 아래(16,30)로 두면 자루 끝이
# 모서리에 그려진 도구는 손에서 10px 넘게 떠 보인다 — 도끼는 자루가
# 오른쪽 아래, 곡괭이·호미는 왼쪽 아래에 있다.
const TOOL_GRIP := {
	"icon_axe": Vector2(25, 30), "icon_axe_stone": Vector2(26, 30),
	"icon_pickaxe": Vector2(3, 30), "icon_hoe": Vector2(4, 23),
	"icon_water": Vector2(13, 23),
}

var _was_riding := false        # 그림자 크기를 다시 그릴 때만 쓴다
var swing_t := 0.0              # 남은 시간
var swing_len := 0.0
var swing_face := Vector2.DOWN  # 내리치는 방향
var tool_sprite: Sprite2D
var upper_sprite: Sprite2D      # 휘두를 때만 보인다 (상체 — 허리 위)
var _base_offset := Vector2.ZERO # scenes/player.tscn이 정한 스프라이트 자리
var _split := false             # 지금 상·하체를 갈라 그리는 중인가
var _trail: Array = []          # 도구 끝이 지나간 자취 (node 좌표)
var _tool_mirror := false       # 지금 든 도구 그림을 좌우로 뒤집어야 하는가
var _tool_grip := Vector2(16, 30)  # 지금 든 도구를 쥐는 자리 (아이콘 안 픽셀)


func _ready() -> void:
	horse_sprite = Sprite2D.new()
	horse_sprite.centered = false
	horse_sprite.scale = Vector2(HORSE_SCALE, HORSE_SCALE)
	horse_sprite.visible = false
	add_child(horse_sprite)
	# 캐릭터보다 먼저 그린다 (자식 순서로 앞뒤를 정한다).
	# z_index를 -1로 두면 지형(z=0)보다 먼저 그려져 땅 밑에 깔린다.
	move_child(horse_sprite, 0)

	# 상체 (허리 위). 휘두를 때만 보이고, 그동안 sprite는 다리만 그린다.
	_base_offset = sprite.offset
	upper_sprite = Sprite2D.new()
	upper_sprite.centered = false
	upper_sprite.visible = false
	add_child(upper_sprite)
	move_child(upper_sprite, sprite.get_index() + 1)   # 다리 위에 겹친다

	# 손에 들리는 도구 (휘두를 때만 보인다). 쥐는 자리를 축으로 돈다
	# (offset은 도구·좌우뒤집기에 따라 _swing_visual이 다시 잡는다).
	tool_sprite = Sprite2D.new()
	tool_sprite.centered = false
	tool_sprite.offset = Vector2(-16, -30)
	tool_sprite.scale = Vector2(1.15, 1.15)   # 한눈에 보이게 조금 크게
	tool_sprite.visible = false
	add_child(tool_sprite)
	_update_sprite()


# 휘두르기 시작. face = 내리치는 방향, length = 동작 길이(초)
func start_swing(tool_id: String, face: Vector2, length: float) -> void:
	if not TOOL_ICONS.has(tool_id):
		return
	var icon: String = TOOL_ICONS[tool_id]
	if tool_id == "axe" and int(GameData.tool_level.get("axe", 1)) >= 2:
		icon = "icon_axe_stone"
	if not main.tex.has(icon):
		return
	tool_sprite.texture = main.tex[icon]
	_tool_grip = TOOL_GRIP.get(icon, Vector2(16, 30))
	_tool_mirror = TOOL_MIRROR.has(tool_id)
	swing_face = face if face != Vector2.ZERO else Vector2.DOWN
	swing_len = maxf(0.14, length)
	swing_t = swing_len
	_trail.clear()


# 내리치는 정점이 오는 진행도. main의 두 상수에서 그대로 끌어온다 —
# 여기가 어긋나면 도끼가 아직 내려오는 중에 나무가 맞는다.
func _hit_p() -> float:
	if main == null:
		return 0.44
	return clampf(main.HIT_AT / maxf(0.01, main.SWING_TIME), 0.15, 0.8)


# 0(시작) ~ 1(끝)을 -1(다 감음) ~ +1(다 내리침)로 바꾼다.
#
#   감아올리기  길고 느리게 끝난다 (예비동작 — 여기가 있어야 「친다」로 보인다)
#   내리치기    두세 프레임에 확 (가속)
#   히트스톱    정점에서 잠깐 박힌 채로 멈춘다
#   되돌아오기  천천히 제자리로
func _swing_curve(p: float) -> float:
	var hit := _hit_p()
	var wind := hit * 0.62
	if p < wind:
		return -sin(p / wind * PI * 0.5)          # 뒤로 넘어가며 느려진다
	if p < hit:
		var q: float = (p - wind) / maxf(0.01, hit - wind)
		return -1.0 + 2.0 * q * q                 # 내리치기 (가속)
	if p < hit + SWING_HOLD:
		return 1.0                                # 히트스톱
	var r: float = (p - hit - SWING_HOLD) / maxf(0.02, 1.0 - hit - SWING_HOLD)
	return 1.0 - r * r * (3.0 - 2.0 * r)          # 부드럽게 제자리로


# 지금 휘두르기 위상 (-1 ~ +1). 안 휘두르면 0.
func swing_c() -> float:
	if swing_t <= 0.0 or swing_len <= 0.0:
		return 0.0
	return _swing_curve(1.0 - swing_t / swing_len)


# 지금 위상에 맞는 휘두르기 도트 이름. 아직 도트가 없으면 "" —
# 그러면 아래에서 몸통 회전으로 대신한다.
func _swing_frame(key: String) -> String:
	if main == null or swing_t <= 0.0:
		return ""
	var base := GameData.swing_tex_base(key)
	if base == "":
		return ""
	# **네 장이 다 있어야 켠다.** 한 장만 넣으면 그 위상에서만 도트가 되고
	# 나머지 위상은 서기 자세로 튀어, 휘두르다 말고 깜빡인다.
	# (손으로 한 장씩 그려 넣을 때 실제로 겪는다)
	for i in SWING_FRAMES:
		if not main.tex.has("%s_%d" % [base, i]):
			return ""
	return "%s_%d" % [base, swing_phase()]


# 지금 위상 (0=감기 시작 / 1=다 감음 / 2=내리침 / 3=되돌아옴).
#
# 시간(진행도)으로 가른다. `swing_c`로 가르면 감을 때와 되돌아올 때가 같은
# 값을 지나서 한 위상이 두 번 나온다 — 팔이 갔다가 되짚어 오는 것처럼 보인다.
#
# 내리치는 그림(2)은 **판정 순간부터 남은 시간의 절반 넘게** 붙들어 둔다.
# 히트스톱(0.03초)만큼만 보이면 두 프레임 만에 지나가서, 정작 제일 중요한
# 「맞은 자세」가 눈에 안 남는다.
func swing_phase() -> int:
	if swing_len <= 0.0:
		return 0
	var p: float = 1.0 - swing_t / swing_len
	var hit := _hit_p()
	if p < hit * 0.34:
		return 0
	if p < hit:
		return 1
	return 2 if p < hit + (1.0 - hit) * 0.55 else 3


# 휘두르는 동안 쓰는 방향 딱지 ("down"/"up"/"side")
func _swing_key() -> String:
	if absf(swing_face.x) >= 0.4:
		return "side"
	return "up" if swing_face.y < 0.0 else "down"


# 휘두르기가 끝났다 — 갈라 놓은 몸을 도로 붙인다
func _swing_off() -> void:
	tool_sprite.visible = false
	sprite.rotation = 0.0
	if _split:
		_split = false
		upper_sprite.visible = false
		sprite.offset = _base_offset
	# 말에 올라탄 채로 끝났다면 region·자리는 _ride_visual의 것이다 — 건드리지 않는다
	if not GameData.riding:
		sprite.region_enabled = false
		sprite.position = Vector2.ZERO
	if not _trail.is_empty():
		_trail.clear()
		queue_redraw()


func _swing_visual() -> void:
	if swing_t <= 0.0:
		_swing_off()
		return
	var p: float = 1.0 - swing_t / swing_len
	var c := _swing_curve(p)
	var key := _swing_key()
	var pose: Dictionary = SWING_POSE[key]
	var sign_x := -1.0 if swing_face.x < -0.3 else 1.0
	# 도트가 이미 자세를 가지고 있으면 몸은 살짝만 거든다
	var dot := _swing_frame(key)
	var lean: float = (SWING_LEAN_DOT if dot != "" else SWING_LEAN) * float(pose.tilt)

	# 눌림: 감을 때 늘어났다가 닿는 순간 주저앉는다
	var sq := 1.0 - SWING_SQUASH * maxf(0.0, c) + 0.03 * maxf(0.0, -c)
	var body := Vector2(0.5, 0.5 * sq)
	# 무게: 내리치는 쪽으로 쏠렸다 돌아온다 (감을 때는 반대로 = 예비동작)
	var shift: Vector2 = Vector2(float(pose.shift.x) * sign_x, float(pose.shift.y)) \
		* (c * SWING_SHIFT / 5.0)

	# 몸: 허리를 축으로 상체만 감았다 내리친다. 다리는 그 자리에서 버틴다.
	# 말 위에서는 가르지 않는다 — 안장에 앉히느라 이미 몸을 잘라 놨다.
	# **도트가 있으면 아예 안 가른다** — 그림이 이미 굽힌 자세라 또 굽히면
	# 허리가 두 번 접히고, 자른 자리가 그림의 팔을 가로지른다.
	var can_split: bool = dot == "" and not GameData.riding and sprite.texture != null
	if can_split:
		var tw: float = sprite.texture.get_width()
		var th: float = sprite.texture.get_height()
		if not _split:
			_split = true
			upper_sprite.visible = true
		upper_sprite.texture = sprite.texture
		upper_sprite.flip_h = sprite.flip_h
		upper_sprite.scale = body
		upper_sprite.region_enabled = true
		# 상체는 허리보다 조금 더 아래까지 그린다 — 안 그러면 굽힐 때 허리에
		# 자른 자국(계단)이 보인다. 겹친 만큼 다리를 덮어 준다.
		upper_sprite.region_rect = Rect2(0.0, 0.0, tw,
			minf(th, SWING_WAIST + SWING_OVERLAP))
		upper_sprite.offset = _base_offset
		sprite.scale = body
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0.0, SWING_WAIST, tw, th - SWING_WAIST)
		sprite.offset = _base_offset + Vector2(0.0, SWING_WAIST)
		sprite.rotation = 0.0
		# 허리 — 자른 자리의 한가운데. 여기를 축으로 돌린다.
		var pivot := Vector2(0.0, (SWING_WAIST + _base_offset.y) * body.y)
		var a := c * lean * sign_x
		upper_sprite.rotation = a
		upper_sprite.position = pivot - pivot.rotated(a) + shift
		sprite.position = shift
	else:
		if _split:
			_split = false
			upper_sprite.visible = false
			sprite.offset = _base_offset
			if not GameData.riding:
				sprite.region_enabled = false
		sprite.rotation = c * lean * 0.55 * sign_x   # 통째로 젖힌다 (예전 방식)
		if not GameData.riding:
			sprite.position = shift   # 말 위에서는 _ride_visual이 자리를 쥔다

	# 도구: 손 높이에서 호를 그린다
	var hand: Vector2 = pose.hand
	var spin: float = sign_x * float(pose.spin)
	tool_sprite.visible = true
	tool_sprite.flip_h = (spin < 0.0) != _tool_mirror
	# 쥐는 자리를 node 원점(=주먹)에 맞춘다. 좌우로 뒤집으면 그림 안의 x도
	# 뒤집히므로 offset을 그만큼 반대로 잡아야 축이 자루 끝에 그대로 있는다.
	if tool_sprite.texture != null:
		var tw := float(tool_sprite.texture.get_width())
		tool_sprite.offset = Vector2(
			-(tw - 1.0 - _tool_grip.x) if tool_sprite.flip_h else -_tool_grip.x,
			-_tool_grip.y)
	# 감을 때는 어깨 뒤로 세우고(c=-1), 내리칠 때는 발치까지 넘긴다(c=+1)
	tool_sprite.rotation = (float(pose.mid) + c * float(pose.arc) * 0.5) * spin
	if dot != "" and SWING_HAND_DOT.has(key):
		# 도트가 자세를 쥐고 있다 — 도구는 그 프레임의 주먹 자리에 얹는다
		hand = SWING_HAND_DOT[key][swing_phase()]
		tool_sprite.position = Vector2(hand.x * sign_x, hand.y) + shift
	else:
		tool_sprite.position = Vector2(hand.x * sign_x + c * 7.0 * sign_x,
			hand.y + c * 9.0) + shift
	# 감아올리는 동안은 도구가 몸 **뒤로** 간다 (어깨 너머로 넘긴 것이니까).
	# 내리치기 시작하면 앞으로 나온다. 뒤를 보고 칠 때는 내내 뒤다.
	var behind: bool = key == "up" or c < 0.0
	move_child(tool_sprite, 0 if behind else get_child_count() - 1)

	# 잔상: 도구 끝이 지나간 자리를 몇 개 남긴다 (빠른 구간에서만 눈에 띈다)
	var tip: Vector2 = tool_sprite.position \
		+ Vector2(0.0, -34.0).rotated(tool_sprite.rotation)
	_trail.push_front(tip)
	while _trail.size() > SWING_TRAIL:
		_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	# 발밑 그림자. 말을 타면 말 몸통만큼 넓어진다
	if GameData.riding:
		draw_rect(Rect2(-26, -4, 52, 9), Color(0, 0, 0, 0.22))
	else:
		draw_rect(Rect2(-10, -3, 20, 6), Color(0, 0, 0, 0.22))
	# 도구 잔상 — 날 끝이 지나간 자취를 옅게 이어 그린다.
	# 빠른 구간에서만 자취가 벌어지므로, 내리치는 순간에만 눈에 띈다.
	if _trail.size() >= 2:
		for i in range(_trail.size() - 1):
			var k: float = 1.0 - float(i) / float(_trail.size() - 1)
			draw_line(_trail[i], _trail[i + 1], Color(1, 1, 1, 0.30 * k * k),
				maxf(1.0, 3.0 * k))


func _process(delta: float) -> void:
	if main == null or main.ui_open():
		moving = false
		swing_t = maxf(0.0, swing_t - delta)
		_update_sprite()
		return

	swing_t = maxf(0.0, swing_t - delta)
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = v != Vector2.ZERO
	if moving and main.fishing_state != "":
		main.fishing.cancel_fishing()  # 움직이면 낚시 중단
	if moving:
		if v.x != 0.0:
			# 대각선 포함: 좌우 성분이 있으면 옆모습 걷기
			dir = "right" if v.x > 0 else "left"
		elif v.y != 0:
			dir = "down" if v.y > 0 else "up"
		# 강아지 펫 + 장신구 + 탈 것이 이동 속도를 올린다
		var mult := GameData.pet_speed_mult() * GameData.gear_speed_mult()
		if GameData.riding:
			mult *= GameData.HORSE_SPEED_MULT
		v = v * SPEED * mult * delta
		var before := position
		# 이미 끼어 있으면(설치물 등) 충돌을 무시하고 빠져나올 수 있게 한다
		var stuck := _blocked(position)
		if not _blocked(position + Vector2(v.x, 0)) \
				or (stuck and _loose_ok(position + Vector2(v.x, 0))):
			position.x += v.x
		if not _blocked(position + Vector2(0, v.y)) \
				or (stuck and _loose_ok(position + Vector2(0, v.y))):
			position.y += v.y
		bumped = (position - before).length() < 0.01
		anim_time += delta
		walked += SPEED * delta
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.33
			step_alt = not step_alt
			Sound.play_sfx("sfx_step1" if step_alt else "sfx_step0", 0.2)
	else:
		step_timer = 0.15
		bumped = false
	_update_sprite()


# 끼임 탈출용 검사: 물/맵 밖/미구매 부지로는 절대 빠져나갈 수 없다
func _loose_ok(p: Vector2) -> bool:
	for off in [Vector2(-R, -R), Vector2(R, -R), Vector2(-R, R), Vector2(R, R)]:
		if not main.is_passable_px_loose(p + off):
			return false
	return true


func _blocked(p: Vector2) -> bool:
	for off in [Vector2(-R, -R), Vector2(R, -R), Vector2(-R, R), Vector2(R, R)]:
		if not main.is_passable_px(p + off):
			return true
	return false


func _update_sprite() -> void:
	# 말 위에서는 걷기 프레임을 쓰지 않는다 — 말 위를 걸어다니는 것처럼 보인다
	var riding: bool = GameData.riding
	# 휘두르는 동안은 걷기 프레임을 쓰지 않는다 — 발을 붙이고 서야 힘이 실린다
	var swinging: bool = swing_t > 0.0
	var walking: bool = moving and not riding and not swinging
	if riding != _was_riding:
		_was_riding = riding
		queue_redraw()          # 발밑 그림자 크기가 바뀐다
	# 4박자 걷기: 발걸음A -> 서기(통과) -> 발걸음B -> 서기(통과)
	var suffix := "idle"
	if walking:
		match int(anim_time * 8.0) % 4:
			0:
				suffix = "0"
			2:
				suffix = "1"
			_:
				suffix = "idle"
	var tex_name := ""
	sprite.flip_h = false
	match dir:
		"down":
			tex_name = GameData.player_down_tex(walking, suffix, anim_time)
		"up":
			tex_name = GameData.player_up_tex(walking, suffix, anim_time)
		_:
			tex_name = GameData.player_side_tex(walking, suffix, anim_time)
			sprite.flip_h = dir == "left"
	# 휘두르기 도트가 있으면 그것으로 갈아끼운다. 없으면 서기 프레임 그대로 두고
	# _swing_visual이 몸을 굽혀 대신한다 (도트가 생기면 여기부터 켜진다).
	if swinging:
		var swing_name := _swing_frame(_swing_key())
		if swing_name != "":
			tex_name = swing_name
			sprite.flip_h = swing_face.x < -0.3
	sprite.texture = main.tex[tex_name]
	# 서 있을 때 숨쉬기: 프레임 대신 세로 스케일을 살짝 키웠다 줄인다
	# (스프라이트 offset이 발 기준이라 발은 그대로, 머리만 오르내린다)
	if not moving and not riding:
		var b := 1.0 + 0.018 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		sprite.scale = Vector2(0.5, 0.5 * b)
	else:
		sprite.scale = Vector2(0.5, 0.5)

	horse_sprite.visible = riding
	if riding:
		_ride_visual()
	elif sprite.region_enabled and not _split:
		sprite.region_enabled = false
		sprite.position.y = 0.0
	_swing_visual()


# 말에 앉힌다 — 상체만 남겨 안장 높이에 얹고, 말 걸음에 맞춰 흔든다.
func _ride_visual() -> void:
	var key := "side" if (dir == "left" or dir == "right") else dir
	var pose: Dictionary = HORSE_POSE[key]
	var hf := 1 if (moving and int(anim_time * 9.0) % 2 == 1) else 0
	horse_sprite.texture = main.tex["horse_%s_%d" % [key, hf]]
	horse_sprite.flip_h = dir == "left"
	horse_sprite.scale = Vector2(HORSE_SCALE, HORSE_SCALE)
	# 발굽이 있는 행을 땅에 맞춘다 (앞/뒤/옆이 서로 다르다)
	horse_sprite.offset = Vector2(-48.0, -float(pose.foot))
	move_child(horse_sprite, 0)   # 늘 캐릭터 뒤 (위 주석 참고)

	# 상체만 남긴다. 잘린 자리는 말 몸통이 가려 준다.
	var cut: int = pose.cut
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, sprite.texture.get_width(), cut)
	# 달릴 때 몸이 한 걸음마다 한 번 뜬다 (말 걸음 9Hz와 같은 박자)
	var bob := 0.0
	if moving:
		bob = -2.2 * absf(sin(anim_time * PI * 9.0))
	sprite.position.y = float(pose.seat) - (float(cut) - RIDER_FOOT) * 0.5 + bob
