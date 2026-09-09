# 전역 게임 데이터 (오토로드 싱글톤)
# 작물 정의, 계절/날씨, 플레이어 자원, 시간, 저장/불러오기를 담당한다.
extends Node

# ---- 계절 ----
const SPRING := 0
const SUMMER := 1
const FALL := 2
const WINTER := 3
const SEASON_NAMES := ["봄", "여름", "가을", "겨울"]
const SEASON_KEYS := ["spring", "summer", "fall", "winter"]
const DAYS_PER_SEASON := 28

# ---- 날씨 ----
const WEATHER_SUN := 0
const WEATHER_RAIN := 1
const WEATHER_SNOW := 2
const WEATHER_FOG := 3
const WEATHER_STORM := 4
const WEATHER_STAR := 5

# ---- 작물 ----
# grow_days = 성장에 필요한 게임 시간(시). 초반 작물은 빨리, 비쌀수록 오래.
const CROPS := {
	# 밀 — 잡화점이 처음부터 파는 두 씨앗 중 하나. 사철 자라는 주식이다.
	"wheat": {"name": "밀", "seed_price": 20, "sell_price": 35, "grow_days": 3,
		"seasons": [SPRING, SUMMER, FALL, WINTER]},
	"potato": {"name": "감자", "seed_price": 20, "sell_price": 35, "grow_days": 2, "seasons": [SPRING]},
	"carrot": {"name": "당근", "seed_price": 30, "sell_price": 50, "grow_days": 3, "seasons": [SPRING]},
	"strawberry": {"name": "딸기", "seed_price": 40, "sell_price": 75, "grow_days": 4, "seasons": [SPRING]},
	"tomato": {"name": "토마토", "seed_price": 35, "sell_price": 60, "grow_days": 3, "seasons": [SUMMER]},
	# 옥수수 — 처음부터 파는 두 번째 씨앗 (그래서 봄에도 심을 수 있다)
	"corn": {"name": "옥수수", "seed_price": 40, "sell_price": 70, "grow_days": 4,
		"seasons": [SPRING, SUMMER, FALL]},
	"watermelon": {"name": "수박", "seed_price": 95, "sell_price": 170, "grow_days": 7, "seasons": [SUMMER]},
	"pumpkin": {"name": "호박", "seed_price": 80, "sell_price": 145, "grow_days": 7, "seasons": [FALL]},
	"eggplant": {"name": "가지", "seed_price": 30, "sell_price": 55, "grow_days": 3, "seasons": [FALL]},
	"cabbage": {"name": "배추", "seed_price": 50, "sell_price": 90, "grow_days": 5, "seasons": [FALL]},
	"winter_radish": {"name": "겨울무", "seed_price": 45, "sell_price": 80, "grow_days": 4, "seasons": [WINTER]},
	# 봄
	"spinach": {"name": "시금치", "seed_price": 25, "sell_price": 45, "grow_days": 2, "seasons": [SPRING]},
	"onion": {"name": "양파", "seed_price": 40, "sell_price": 70, "grow_days": 4, "seasons": [SPRING]},
	"pea": {"name": "완두", "seed_price": 35, "sell_price": 60, "grow_days": 3, "seasons": [SPRING, SUMMER]},
	# 여름
	"pepper": {"name": "고추", "seed_price": 45, "sell_price": 80, "grow_days": 4, "seasons": [SUMMER]},
	"melon": {"name": "참외", "seed_price": 80, "sell_price": 150, "grow_days": 6, "seasons": [SUMMER]},
	"garlic": {"name": "마늘", "seed_price": 35, "sell_price": 65, "grow_days": 3, "seasons": [SUMMER]},
	# 가을
	"sweet_potato": {"name": "고구마", "seed_price": 60, "sell_price": 105, "grow_days": 5, "seasons": [FALL]},
	"bean": {"name": "콩", "seed_price": 40, "sell_price": 70, "grow_days": 4, "seasons": [FALL]},
	"rice": {"name": "벼", "seed_price": 65, "sell_price": 115, "grow_days": 6, "seasons": [FALL]},
	# 겨울 — 추운 계절은 종류가 적은 대신 값이 좋다
	"leek": {"name": "대파", "seed_price": 40, "sell_price": 75, "grow_days": 3, "seasons": [WINTER]},
	"beet": {"name": "비트", "seed_price": 60, "sell_price": 110, "grow_days": 5, "seasons": [WINTER]},
	"snow_cabbage": {"name": "눈배추", "seed_price": 100, "sell_price": 180, "grow_days": 7, "seasons": [WINTER]},
	# 사계절 — 값은 싸지만 언제든 심을 수 있다
	"herb_leaf": {"name": "약초잎", "seed_price": 25, "sell_price": 45, "grow_days": 3, "seasons": [SPRING, SUMMER, FALL, WINTER]},
}
const CROP_IDS := [
	"wheat",
	"potato", "carrot", "strawberry", "spinach", "onion", "pea",
	"tomato", "corn", "watermelon", "pepper", "melon", "garlic",
	"pumpkin", "eggplant", "cabbage", "sweet_potato", "bean", "rice",
	"winter_radish", "leek", "beet", "snow_cabbage",
	"herb_leaf",
]

const ENERGY_MAX := 100.0  # 체력 (동굴 전투용. 밖에서는 천천히 자연 회복)
# 도구를 한 번 쓸 때 드는 기력 = 장비의 「기력 소모」 x 배율.
# 낮에는 가볍게, 밤에는 그대로 든다 (밤일이 힘들다)
const STAMINA_DAY_MULT := 0.25
const STAMINA_NIGHT_MULT := 1.0
const DAY_START := 6.0 * 60.0   # 오전 6시
const DAY_END := 26.0 * 60.0    # 새벽 2시 강제 취침

# ---- 공공 건물의 영업시간 ----
#
# 상점·도서관·대장간처럼 사람이 일하는 건물은 아침 9시에 문을 열고
# 저녁 6시에 닫는다. 낮 12시부터 1시까지는 점심시간이라 잠시 쉰다.
# (개인 주거지는 여기에 해당하지 않는다 — 집 문은 언제나 열린다)
const OPEN_HOUR := 9.0
const CLOSE_HOUR := 18.0
const LUNCH_FROM := 12.0
const LUNCH_TO := 13.0


func hour_now() -> float:
	return minutes / 60.0


func shop_lunch_now() -> bool:
	var h := hour_now()
	return h >= LUNCH_FROM and h < LUNCH_TO


func shop_open_now() -> bool:
	var h := hour_now()
	return h >= OPEN_HOUR and h < CLOSE_HOUR and not shop_lunch_now()


# 왜 닫혀 있는가 — "" 열림 / "early" 아직 / "lunch" 점심 / "late" 마감
func shop_closed_why() -> String:
	var h := hour_now()
	if h < OPEN_HOUR:
		return "early"
	if h >= CLOSE_HOUR:
		return "late"
	if shop_lunch_now():
		return "lunch"
	return ""


func shop_hours_line() -> String:
	return "영업 %d시~%d시 · 점심 %d시~%d시" % [int(OPEN_HOUR), int(CLOSE_HOUR),
		int(LUNCH_FROM), int(LUNCH_TO)]

# ---- 배고픔(포만감) ----
#
# 메인 스토리 3의 두 번째 퀘스트에서 열린다 (재민이 알려 준다).
# 시간이 흐르면 배가 꺼지고, 0이 되면 몸이 상한다 —
#   · 체력이 계속 깎이고
#   · 걸음이 눈에 띄게 느려진다
# 다만 **집 안은 안전지대**다. 지붕 밑에 있는 동안에는 굶주림으로
# 체력이 HUNGER_SAFE_FLOOR 아래로 내려가지 않는다 (자리를 비워 두어도
# 죽지 않는다). 밖에서 굶다가 체력이 바닥나면 그대로 쓰러진다.
const HUNGER_MAX := 100.0
const HUNGER_PER_MIN := 0.1       # 게임 1분마다 — 가득 차면 1000분(≈하루)
const HUNGER_STARVE_DPS := 1.5    # 굶을 때 초당 깎이는 체력
const HUNGER_SAFE_FLOOR := 30.0   # 집 안에서는 여기까지만
const HUNGER_SLOW_MULT := 0.35    # 굶으면 걸음이 이만큼으로
const HUNGER_WAKE_MIN := 40.0     # 자고 일어나면 최소 이만큼은 차 있다
const HUNGER_LOW := 25.0          # 이 아래면 배가 고프다는 신호

const SAVE_PATH := "user://kyojin_farm_save.json"

# ---- 개발/테스트용 치트 (출시 전에 DEV_MODE를 false로 되돌린다) ----
# 켜져 있으면 개발용 단축키(F3·F6~F10)와 스토리 건너뛰기가 열린다.
const DEV_MODE := true
# **지갑은 따로 잠근다.**
#
# 세금·봉급·예산이 이 위에 서기 시작하면, 시작 소지금 1억은 그 모든
# 숫자를 무의미하게 만든다 — 세율을 아무리 만져도 체감이 없으면 그건
# 경제가 아니라 그냥 적혀 있는 글자다. 그래서 시작 지갑만 떼어 껐다.
# 손으로 만져 볼 때는 F10(dev_fill_stock)이 돈까지 같이 채워 주고,
# 검증 하네스는 필요한 자리마다 money 를 직접 꽂는다.
const DEV_RICH := false
const DEV_MONEY := 100000000
const DEV_STOCK := 10000        # 목재·석재·씨앗·아이템 개수
const START_MONEY := 200        # 출시용 시작 소지금 — 씨앗 몇 줌이 전부다

# ---- 키 설정 (사람마다 다르게 바꿀 수 있다) ----
const KEYBIND_PATH := "user://keybinds.json"
# [액션, 설명] — 이 목록이 설정 화면의 키 안내 겸 리바인딩 대상
const BINDABLE_ACTIONS := [
	["move_up", "위로 이동"],
	["move_down", "아래로 이동"],
	["move_left", "왼쪽으로 이동"],
	["move_right", "오른쪽으로 이동"],
	["use_tool", "도구 사용 / 낚시 / 공격"],
	["talk", "대화 (사람·가축)"],
	["interact", "상호작용 (줍기/캐기/입장)"],
	["mount", "말 타기 / 내리기 (대화키와 같은 키)"],
	["cycle_seed", "씨앗 바꾸기"],
	["open_inventory", "가방 (도구/능력치)"],
	["open_map", "지도"],
	["open_quest", "퀘스트 창"],
	["open_note", "연구 노트"],
	["open_stats", "능력치 창"],
	["save_game", "저장"],
]


func key_label(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			if ev.physical_keycode != KEY_NONE:
				return OS.get_keycode_string(
					DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode))
			return OS.get_keycode_string(ev.keycode)
	return "?"


# 첫 번째 키보드 바인딩만 교체하고 나머지(화살표 같은 보조 키)는 유지한다.
# 다른 액션이 이미 그 키를 쓰고 있으면 두 액션의 키를 맞바꾼다.
func rebind_action(action: String, physical: int) -> void:
	var old := _primary_key(action)
	for pair in BINDABLE_ACTIONS:
		var other: String = pair[0]
		if other != action and _primary_key(other) == physical:
			_set_primary_key(other, old)
			break
	_set_primary_key(action, physical)
	save_keybinds()


func _primary_key(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return int(ev.physical_keycode)
	return 0


func _set_primary_key(action: String, physical: int) -> void:
	var kept := []
	var replaced := false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and not replaced:
			replaced = true
			continue
		kept.append(ev)
	InputMap.action_erase_events(action)
	var nev := InputEventKey.new()
	nev.physical_keycode = physical
	InputMap.action_add_event(action, nev)
	for k in kept:
		InputMap.action_add_event(action, k)


func save_keybinds() -> void:
	var out := {}
	for pair in BINDABLE_ACTIONS:
		out[pair[0]] = _primary_key(pair[0])
	var f := FileAccess.open(KEYBIND_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))


func load_keybinds() -> void:
	if not FileAccess.file_exists(KEYBIND_PATH):
		return
	var f := FileAccess.open(KEYBIND_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	for a in d:
		if InputMap.has_action(a) and int(d[a]) > 0:
			_set_primary_key(a, int(d[a]))


func reset_keybinds() -> void:
	InputMap.load_from_project_settings()
	if FileAccess.file_exists(KEYBIND_PATH):
		DirAccess.remove_absolute(KEYBIND_PATH)

# ---- 화면 설정 ----
const SETTINGS_PATH := "user://kyojin_display.json"
const WINDOW_MODES := ["960x540", "1440x810", "1920x1080", "fullscreen"]
var window_mode := "1440x810"
var _last_windowed := "1440x810"


func _ready() -> void:
	load_settings()
	apply_window_mode()
	load_keybinds()


func _input(event: InputEvent) -> void:
	# F11: 전체 화면 토글 (어디서든)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F11:
		if window_mode == "fullscreen":
			window_mode = _last_windowed
		else:
			_last_windowed = window_mode
			window_mode = "fullscreen"
		apply_window_mode()
		save_settings()


func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if window_mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var parts := window_mode.split("x")
	if parts.size() != 2:
		return
	var size := Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(DisplayServer.screen_get_position()
		+ (screen - size) / 2)


func cycle_window_mode() -> void:
	var i := WINDOW_MODES.find(window_mode)
	window_mode = WINDOW_MODES[(i + 1) % WINDOW_MODES.size()]
	if window_mode != "fullscreen":
		_last_windowed = window_mode
	apply_window_mode()
	save_settings()


func window_mode_label() -> String:
	return "전체 화면" if window_mode == "fullscreen" else "창 " + window_mode


# ---- 경매장 신원 ----
#
# 장터(바깥 서버)에는 로그인이 없다. 대신 이 컴퓨터가 처음 켤 때 무작위
# 문자열을 하나 만들어 설정 파일에 두고, 그것으로 「내 농장」을 가른다.
# 이 값이 있어야 내가 올린 글을 거두고 대금을 받을 수 있으므로 지우지 않는다.
var farm_id := ""


# 장터에서 「내 농장」을 가리키는 값. 로그인했으면 **서버가 발급한 계정 id**를
# 쓰고(그 편이 안전하다), 아니면 이 컴퓨터가 만든 farm_id로 버틴다.
func farm_key() -> String:
	# 오토로드를 이름으로 부르면 등록 순서에 걸려 파싱이 깨질 수 있어
	# 실행할 때 노드로 집는다 (없으면 예전 방식 그대로)
	var a := get_node_or_null("/root/Auth")
	if a != null and a.signed_in():
		return str(a.uid)
	return farm_id


func _ensure_farm_id() -> void:
	if farm_id != "":
		return
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 24:
		farm_id += chars[rng.randi() % chars.length()]
	save_settings()


# 장터에 보이는 내 이름 (이름을 안 지었으면 기본값)
func seller_name() -> String:
	var n := player_name.strip_edges()
	return n.substr(0, 24) if n != "" else "이름 없는 농부"


# 지도 이름패·엔딩 통계에 쓰는 농장 이름.
#
# 예전에는 생성창에서 따로 지었다. 마을 칸과 나란히 놓고 보면 **같은 것을
# 두 번** 묻는 꼴이라 칸을 없앴고, 이제 농장은 주인 이름을 따른다.
# (옛 세이브에 지어 둔 이름이 있으면 그건 그대로 쓴다)
func farm_title() -> String:
	var n := farm_name.strip_edges()
	return n.substr(0, 12) if n != "" else "%s의 농장" % seller_name()


# ---- 마을 이름 ----
#
# 대사·안내·간판에 박혀 있는 기본 이름은 「교진」이다. 생성창에서 다른
# 이름을 지으면, **화면에 나가는 글자를 내보내는 길목에서** 그 이름으로
# 바꿔 준다(`localize`). 수백 줄의 대사마다 %s를 심는 대신 이렇게 한 이유는
# 하나 — 한 군데라도 빠뜨리면 그 대사에서만 옛 이름이 튀어나오기 때문이다.
const HOME_VILLAGE := "교진"


func village_base() -> String:
	var n := village_name.strip_edges()
	return n.substr(0, 8) if n != "" else HOME_VILLAGE


func village_title() -> String:
	return "%s 마을" % village_base()


func localize(text: String) -> String:
	var n := village_base()
	if n == HOME_VILLAGE or text == "":
		return text
	return text.replace(HOME_VILLAGE, n)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"window": window_mode, "farm_id": farm_id}))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		_ensure_farm_id()
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		_ensure_farm_id()
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY:
		farm_id = str(d.get("farm_id", ""))
	_ensure_farm_id()
	if typeof(d) == TYPE_DICTIONARY and d.has("window"):
		window_mode = str(d.window)
		# 구버전 해상도 설정은 현재 기본값으로 교체
		if not WINDOW_MODES.has(window_mode):
			window_mode = "1440x810"
		if window_mode != "fullscreen":
			_last_windowed = window_mode

var day := 1
var minutes := DAY_START
var money := DEV_MONEY if (DEV_MODE and DEV_RICH) else START_MONEY
var energy := ENERGY_MAX
var hunger := HUNGER_MAX
var hunger_open := false     # 배고픔 해금 (스토리 3의 씨앗 퀘스트에서 열린다)
var tool := "hoe"
var seed_index := 0
var seeds := {}
var produce := {}
# 품질 등급: 수확 시 농사 숙련도에 따라 은/금 품질 (판매가 1.25/1.5배)
var produce_silver := {}
var produce_gold := {}
var wood := 0
var stone := 0
var tool_level := {"hoe": 1, "water": 1, "axe": 1, "pickaxe": 1}

# ---- 나 (사회) ----
#
# 직업·자리·대범함·전과·기억 — 이 마을이 나를 무엇이라 부르는지의 재료.
# 열쇠 목록과 뜻은 fresh_me()(「# ---- 사회 (S1) ----」 블록)에 있다.
#
# 읽을 때는 _apply_me 가 fresh_me() 위에 저장된 값만 덮는다 — 열쇠가 늘어도
# 옛 세이브가 깨지지 않고, 모르는 열쇠는 그대로 지나가며, JSON 이 float 로
# 돌려준 수는 int 로 되돌린다. 게스트는 남의 me 를 읽지 않는다(fresh 그대로).
var me := fresh_me()

# 설치물 비용
const FENCE_COST_WOOD := 1
const SPRINKLER_COST_WOOD := 2
const SPRINKLER_COST_STONE := 2

# ---- 장비 능력치 (대장간 시스템의 토대) ----
#
# 도구는 저마다 능력치를 가지고, 강화 단계(tool_level)마다 값이 오른다.
# 앞으로 대장간에서 새 장비를 만들면 이 표에 항목만 추가하면 되고,
# 게임 쪽은 tool_stats()가 돌려주는 값만 보므로 손댈 곳이 없다.
#
#   power   위력   — 나무/돌에 한 번에 주는 타격, 동굴에서의 공격력
#   reach   범위   — 한 번에 다루는 칸 수 (1=1칸 / 2=전방 3칸 / 3=3x3)
#   stamina 소모   — 한 번 쓸 때 드는 기력 (낮에는 아직 쓰지 않는다)
#   luck    행운   — 좋은 등급/희귀 산출 확률 보정 (%p)
const STAT_NAMES := {
	"power": "위력", "reach": "범위", "stamina": "기력 소모", "luck": "행운",
}
# 각 능력치가 실제로 무엇에 걸리는지 (능력치 창 안내용)
const STAT_HELP := [
	"위력 — 나무·돌 타격량, 동굴 공격력",
	"범위 — 한 번에 다루는 칸 수 (1칸 / 전방 3칸 / 3x3)",
	"기력 소모 — 도구를 쓸 때 드는 체력 (밤에는 그대로, 낮에는 1/4)",
	"행운 — 작물 등급, 목재·석재 추가 산출, 희귀 물고기 확률",
]
# base = Lv1 값 / grow = 강화 1단계마다 더해지는 값
const TOOL_STATS := {
	"hoe":     {"base": {"power": 1, "reach": 1, "stamina": 3, "luck": 0},
		"grow": {"reach": 1, "stamina": -0.5}},
	"water":   {"base": {"power": 1, "reach": 1, "stamina": 2, "luck": 0},
		"grow": {"reach": 1, "stamina": -0.5}},
	"axe":     {"base": {"power": 1, "reach": 1, "stamina": 4, "luck": 0},
		"grow": {"power": 2, "stamina": -0.5, "luck": 1}},
	"pickaxe": {"base": {"power": 1, "reach": 1, "stamina": 4, "luck": 0},
		"grow": {"power": 1, "stamina": -0.5, "luck": 1}},
	"rod":     {"base": {"power": 1, "reach": 1, "stamina": 2, "luck": 1},
		"grow": {}},
	# 초반 무기 — 창은 느리지만 한 방이 강하고, 검은 빠르게 두 번 벤다.
	# (전체 화력은 비슷하게 — 성향 따라 고르는 무기)
	"spear":   {"base": {"power": 4, "reach": 1, "stamina": 5, "luck": 0},
		"grow": {}},
	"sword":   {"base": {"power": 1.5, "reach": 1, "stamina": 3, "luck": 0},
		"grow": {}},
}


# 지금 단계에서의 장비 능력치. 표에 없는 도구는 기본값을 돌려준다.
func tool_stats(tool_id: String) -> Dictionary:
	var out := {"power": 1.0, "reach": 1.0, "stamina": 0.0, "luck": 0.0}
	if not TOOL_STATS.has(tool_id):
		return out
	var def: Dictionary = TOOL_STATS[tool_id]
	var steps: int = maxi(0, int(tool_level.get(tool_id, 1)) - 1)
	for k in out:
		out[k] = float(def.base.get(k, out[k])) + float(def.grow.get(k, 0.0)) * steps
	out.power = maxf(1.0, out.power)
	out.reach = maxf(1.0, out.reach)
	out.stamina = maxf(0.0, out.stamina)
	return out


# 능력치 숫자 표기: 정수는 그대로, 소수는 소수 첫째 자리까지
func fmt_stat(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else "%.1f" % v


func tool_stat(tool_id: String, stat: String) -> float:
	return float(tool_stats(tool_id).get(stat, 0.0))


# 슬롯에 장착한 장비들의 행운 합계 (등급/희귀 산출 보정)
func total_luck() -> float:
	var sum := 0.0
	for t in tool_slots:
		if t != "" and TOOL_STATS.has(t):
			sum += tool_stat(t, "luck")
	return sum + gear_stat("luck")


# ==== 대장간: 장비 제작 · 장착 ====
#
# 도구 강화(UPGRADES)와는 별개다. 도구는 「무엇을 하느냐」를 정하고,
# 장비는 「얼마나 잘 하느냐」를 정한다. 세 부위를 하나씩 장착한다.
#
# 능력치가 실제로 하는 일:
#   power   동굴 공격력 +          defense 동굴에서 받는 피해 -%
#   stamina 도구 기력 소모 -%      luck    품질·추가 수확·희귀 물고기
#   speed   이동 속도 +%
# 새 장비를 넣을 때는 GEAR에 한 줄만 더하면 된다.
const GEAR_SLOTS := ["weapon", "armor", "charm"]
const GEAR_SLOT_NAMES := {"weapon": "무기", "armor": "방어구", "charm": "장신구"}
const GEAR_STAT_NAMES := {
	"power": "위력", "defense": "방어", "stamina": "기력 절약",
	"luck": "행운", "speed": "이동 속도",
}
const GEAR := {
	# ---- 무기: 동굴 공격력 ----
	"gear_sword_wood": {"name": "나무 검", "slot": "weapon", "tier": 1,
		"stats": {"power": 2.0},
		"cost": {"money": 300, "wood": 20, "stone": 5},
		"desc": "무쇠 아저씨가 연습용으로 깎아 준 검."},
	"gear_sword_iron": {"name": "무쇠 검", "slot": "weapon", "tier": 2,
		"stats": {"power": 5.0},
		"cost": {"money": 1200, "ore": 10, "stone": 10},
		"desc": "제대로 벼려 낸 검. 동굴이 한결 수월해진다."},
	"gear_sword_star": {"name": "별빛 검", "slot": "weapon", "tier": 3,
		"stats": {"power": 10.0, "luck": 2.0},
		"cost": {"money": 4000, "star_shard": 3, "ore": 20},
		"desc": "별빛 광석을 녹여 만든 검. 어둠 속에서 옅게 빛난다."},
	# ---- 방어구: 받는 피해 ----
	"gear_vest_leather": {"name": "가죽 조끼", "slot": "armor", "tier": 1,
		"stats": {"defense": 10.0},
		"cost": {"money": 400, "wood": 15, "stone": 10},
		"desc": "가볍고 튼튼하다. 첫 동굴에 딱 맞다."},
	"gear_vest_iron": {"name": "무쇠 갑옷", "slot": "armor", "tier": 2,
		"stats": {"defense": 25.0, "speed": -3.0},
		"cost": {"money": 1500, "ore": 15, "stone": 20},
		"desc": "묵직한 만큼 확실하다. 조금 느려진다."},
	"gear_vest_star": {"name": "별빛 갑옷", "slot": "armor", "tier": 3,
		"stats": {"defense": 40.0},
		"cost": {"money": 5000, "star_shard": 2, "gem": 1, "ore": 25},
		"desc": "별빛을 짜 넣어 무겁지 않다."},
	# ---- 장신구: 생활 능력치 ----
	"gear_charm_clover": {"name": "네잎클로버", "slot": "charm", "tier": 1,
		"stats": {"luck": 3.0},
		"cost": {"money": 300, "wood": 10},
		"desc": "행운이 따른다. 좋은 품질이 더 자주 나온다."},
	"gear_charm_ember": {"name": "불씨 부적", "slot": "charm", "tier": 2,
		"stats": {"stamina": 20.0},
		"cost": {"money": 1000, "ore": 8, "stone": 10},
		"desc": "일이 덜 고되다. 도구 기력 소모가 준다."},
	"gear_charm_wind": {"name": "바람 부적", "slot": "charm", "tier": 3,
		"stats": {"speed": 12.0, "luck": 1.0},
		"cost": {"money": 2500, "gem": 1, "ore": 10},
		"desc": "발걸음이 가벼워진다."},
}
const GEAR_IDS := ["gear_sword_wood", "gear_sword_iron", "gear_sword_star",
	"gear_vest_leather", "gear_vest_iron", "gear_vest_star",
	"gear_charm_clover", "gear_charm_ember", "gear_charm_wind"]

var owned_gear: Array = []
var equipped := {"weapon": "", "armor": "", "charm": ""}

# ---- 세트 장비 시너지 (메이플식) ----
# 같은 테마의 장비를 여러 부위 장착하면 개수 구간마다 보너스가 얹힌다.
# 새 세트는 표에 한 줄이면 된다 — pieces에 든 장비 중 장착 수를 세고,
# bonus의 「그 개수 이하 구간」 보너스를 전부 더한다.
const GEAR_SETS := [
	{"id": "iron", "name": "무쇠 세트",
		"pieces": ["gear_sword_iron", "gear_vest_iron", "gear_charm_ember"],
		"bonus": {2: {"defense": 5.0}, 3: {"power": 2.0, "defense": 8.0}}},
	{"id": "star", "name": "별빛 세트",
		"pieces": ["gear_sword_star", "gear_vest_star", "gear_charm_wind"],
		"bonus": {2: {"luck": 2.0}, 3: {"power": 3.0, "luck": 3.0, "speed": 6.0}}},
]


# 이 세트에서 몇 부위를 차고 있나
func gear_set_count(gset: Dictionary) -> int:
	var n := 0
	for gid: String in gset.pieces:
		if gid in equipped.values():
			n += 1
	return n


# 장착 중인 장비의 능력치 합 (+ 세트 보너스)
func gear_stat(key: String) -> float:
	var sum := 0.0
	for slot: String in GEAR_SLOTS:
		var gid: String = str(equipped.get(slot, ""))
		if gid != "" and GEAR.has(gid):
			sum += float(GEAR[gid].stats.get(key, 0.0))
	for gset: Dictionary in GEAR_SETS:
		var n := gear_set_count(gset)
		for need in gset.bonus:
			if n >= int(need):
				sum += float((gset.bonus[need] as Dictionary).get(key, 0.0))
	return sum


# 지금 발동 중인 세트 효과 설명 (가방 장비 탭·능력치 창에서 보여준다)
func gear_set_text() -> String:
	var parts: Array[String] = []
	for gset: Dictionary in GEAR_SETS:
		var n := gear_set_count(gset)
		var best := 0
		for need in gset.bonus:
			if n >= int(need) and int(need) > best:
				best = int(need)
		if best > 0:
			var stat_bits: Array[String] = []
			for need in gset.bonus:
				if n >= int(need):
					for k: String in gset.bonus[need]:
						stat_bits.append("%s +%s" % [k, str(gset.bonus[need][k])])
			parts.append("%s %d부위 (%s)" % [gset.name, n, " · ".join(stat_bits)])
	return " / ".join(parts)


func gear_speed_mult() -> float:
	return clampf(1.0 + gear_stat("speed") / 100.0, 0.5, 2.0)


# 도구 기력 소모 배수 (기력 절약이 높을수록 적게 든다)
func gear_stamina_mult() -> float:
	return clampf(1.0 - gear_stat("stamina") / 100.0, 0.2, 1.0)


# 동굴에서 받는 피해 배수
func gear_defense_mult() -> float:
	return clampf(1.0 - gear_stat("defense") / 100.0, 0.2, 1.0)


func gear_stat_text(gid: String) -> String:
	if not GEAR.has(gid):
		return ""
	var parts: Array[String] = []
	var st: Dictionary = GEAR[gid].stats
	for k: String in ["power", "defense", "stamina", "luck", "speed"]:
		if not st.has(k):
			continue
		var v := float(st[k])
		var unit := "%" if k in ["defense", "stamina", "speed"] else ""
		parts.append("%s %s%s%s" % [GEAR_STAT_NAMES[k], "+" if v > 0.0 else "",
			fmt_stat(v), unit])
	return " · ".join(parts)


func gear_cost_text(gid: String) -> String:
	if not GEAR.has(gid):
		return ""
	var names := {"money": "G", "wood": "목재", "stone": "석재",
		"ore": "광석", "star_shard": "별빛 조각", "gem": "보석"}
	var parts: Array[String] = []
	for k: String in GEAR[gid].cost:
		var n: int = int(GEAR[gid].cost[k])
		parts.append("%dG" % n if k == "money" else "%s %d" % [names.get(k, k), n])
	return " · ".join(parts)


# 이 장비의 재료를 전부 겪어 봤는가 — 대장간은 「아는 재료」로만 벼려 준다.
# 처음 보는 물건이 진열대에 있으면 발견의 재미가 사라진다 (기본 컨셉 1).
# 목재·돌·돈은 늘 아는 것으로 친다. tier 1(나무 장비)은 언제나 열려 있다 —
# 첫 장비까지 잠그면 동굴 첫 걸음이 막힌다.
func gear_known(gid: String) -> bool:
	if int(GEAR[gid].get("tier", 1)) <= 1:
		return true
	for k: String in GEAR[gid].cost:
		if k in ["money", "wood", "stone"]:
			continue
		if not discovered.has(k):
			return false
	return true


func can_craft_gear(gid: String) -> bool:
	if not GEAR.has(gid) or owned_gear.has(gid) or not gear_known(gid):
		return false
	var cost: Dictionary = GEAR[gid].cost
	if money < int(cost.get("money", 0)):
		return false
	if wood < int(cost.get("wood", 0)) or stone < int(cost.get("stone", 0)):
		return false
	for k: String in ["ore", "star_shard", "gem"]:
		if int(items.get(k, 0)) < int(cost.get(k, 0)):
			return false
	return true


# 만들면 바로 장착한다 (같은 부위의 이전 장비는 그대로 가지고 있는다)
func craft_gear(gid: String) -> bool:
	if not can_craft_gear(gid):
		return false
	var cost: Dictionary = GEAR[gid].cost
	money -= int(cost.get("money", 0))
	today_spent += int(cost.get("money", 0))
	wood -= int(cost.get("wood", 0))
	stone -= int(cost.get("stone", 0))
	for k: String in ["ore", "star_shard", "gem"]:
		items[k] = int(items.get(k, 0)) - int(cost.get(k, 0))
	owned_gear.append(gid)
	equipped[str(GEAR[gid].slot)] = gid
	return true


func equip_gear(gid: String) -> void:
	if GEAR.has(gid) and owned_gear.has(gid):
		equipped[str(GEAR[gid].slot)] = gid


func unequip_slot(slot: String) -> void:
	if equipped.has(slot):
		equipped[slot] = ""


# 강화 한 단계로 어떤 능력치가 얼마나 오르는지 (상점 표시용)
func tool_stat_gain_text(tool_id: String) -> String:
	if not TOOL_STATS.has(tool_id):
		return ""
	var parts: Array[String] = []
	var grow: Dictionary = TOOL_STATS[tool_id].grow
	for k in grow:
		var v := float(grow[k])
		if is_zero_approx(v):
			continue
		parts.append("%s %s%s" % [STAT_NAMES.get(k, k),
			"+" if v > 0.0 else "", fmt_stat(v)])
	return " · ".join(parts)


# 업그레이드 정의: levels[현재레벨-1] = 다음 레벨 비용/효과
const UPGRADES := {
	"hoe": {"name": "호미", "levels": [
		{"money": 500, "wood": 10, "ore": 0, "desc": "전방 3칸 갈기"},
		{"money": 1500, "wood": 0, "ore": 8, "desc": "3x3 범위 갈기"},
	]},
	"water": {"name": "물뿌리개", "levels": [
		{"money": 500, "wood": 10, "ore": 0, "desc": "전방 3칸 물주기"},
		{"money": 1500, "wood": 0, "ore": 8, "desc": "3x3 범위 물주기"},
	]},
	"axe": {"name": "도끼", "levels": [
		{"money": 1200, "wood": 0, "ore": 6, "desc": "나무 1타 벌목 + 동굴 공격력 2배"},
	]},
	"pickaxe": {"name": "곡괭이", "levels": [
		{"money": 1200, "wood": 0, "ore": 6, "desc": "돌 1타 채굴 + 동굴 공격력 2배"},
	]},
}

# ---- 몬스터 도감 ----
const MOBS := {
	"slime": {"name": "슬라임", "desc": "동굴 어디에나 있는 말랑이. 느리지만 떼로 다닌다."},
	"bat": {"name": "박쥐", "desc": "2층부터 등장. 빠르게 덮쳐온다!"},
	"ghost": {"name": "유령", "desc": "4층부터 등장. 벽을 통과해 끈질기게 쫓아온다..."},
	"treant": {"name": "숲의 수호자", "desc": "세계수 동굴 최심부의 보스. 오래된 나무의 정령이다."},
}
var mob_kills := {}

# ---- 능력치 (숙련도): 하다 보면 는다 ----
const SKILLS := {
	"farm": {"name": "농사", "effect": "작물 성장 +4%/Lv"},
	"fish": {"name": "낚시", "effect": "입질 대기 -5%/Lv"},
	"forest": {"name": "벌목", "effect": "목재 추가 +6%/Lv"},
	"mine": {"name": "채광", "effect": "석재·광석 추가 +6%/Lv"},
	"combat": {"name": "전투", "effect": "동굴 공격력 +0.5/Lv"},
	"cook": {"name": "요리", "effect": "요리 회복량 +5%/Lv"},
	# 숲 채집과 해변 채집을 합친 하나의 「채집」 숙련이다
	"beach": {"name": "채집", "effect": "숲·해변 채집량 3Lv마다 +1 · 조개 리젠 +8%/Lv"},
	"ranch": {"name": "목장", "effect": "쓰다듬은 동물이 생산물을 더 줄 확률 +3%/Lv"},
}
const SKILL_IDS := ["farm", "fish", "forest", "mine", "combat", "cook", "beach", "ranch"]
const SKILL_MAX_LV := 10
var skills := {}


func _reset_skills() -> void:
	for id in SKILL_IDS:
		skills[id] = {"lv": 1, "xp": 0.0}


func skill_lv(id: String) -> int:
	return int(skills[id].lv)


# 레벨업은 아주 더디다 — 한 분야를 끝까지 갈고닦는 일이
# 며칠이 아니라 여러 계절에 걸친 일이 되도록 곡선을 네 배 가까이 세웠다.
func skill_xp_needed(lv: int) -> float:
	return 120.0 + 85.0 * lv * lv


# 경험치 추가. 레벨업하면 도달한 레벨을, 아니면 0을 반환
func add_skill_xp(id: String, amount: float) -> int:
	var s: Dictionary = skills[id]
	if int(s.lv) >= SKILL_MAX_LV:
		return 0
	s.xp = float(s.xp) + amount
	var leveled := 0
	while int(s.lv) < SKILL_MAX_LV and float(s.xp) >= skill_xp_needed(int(s.lv)):
		s.xp = float(s.xp) - skill_xp_needed(int(s.lv))
		s.lv = int(s.lv) + 1
		leveled = int(s.lv)
	if leveled > 0:
		# 그 자리에서 알리지 않는다 — 하루를 마치고 잠들 때 한꺼번에 전한다
		levelup_pending.append([id, leveled])
	if leveled >= SKILL_MAX_LV:
		check_skill_water(id)   # 만렙 증표 — 생명의 물 한 병
	return leveled


# 오늘 오른 능력치들 — [[분야 id, 레벨], ...]. 잠들 때 결산에 실린다
var levelup_pending: Array = []


# 잠자리 결산에 실을 한 줄 (없으면 "")
func levelup_report() -> String:
	if levelup_pending.is_empty():
		return ""
	var parts: Array = []
	for row: Array in levelup_pending:
		parts.append("%s Lv.%d" % [str(SKILLS[str(row[0])].name), int(row[1])])
	levelup_pending = []
	return "오늘 실력이 늘었다 — " + " · ".join(parts)


func farm_growth_mult() -> float:
	var m := 1.0 + 0.04 * (skill_lv("farm") - 1)
	if active_pet == "rabbit":
		m += 0.05
	return m


func fish_wait_mult() -> float:
	var m := maxf(0.55, 1.0 - 0.05 * (skill_lv("fish") - 1))
	if active_pet == "cat":
		m *= 0.85
	return m


# 벌목/채광 레벨에 따른 추가 획득 확률
func bonus_drop_chance(id: String) -> float:
	# 숙련도 + 장비 행운 (행운 1당 +3%p) + 오늘의 약효
	var base := 0.06 * (skill_lv(id) - 1) + total_luck() * 0.03
	return base + (0.15 if has_potion("luck") else 0.0)


func combat_bonus() -> float:
	return 0.5 * (skill_lv("combat") - 1) + (3.0 if has_potion("ember") else 0.0)


func cook_energy_mult() -> float:
	return 1.0 + 0.05 * (skill_lv("cook") - 1)


# ---- 집 꾸미기 가구 ----
# solid: 지나갈 수 없는 가구 (러그/액자는 통과 가능)
const FURNITURE := {
	"table": {"name": "식탁", "price": 250, "w": 90, "h": 63, "solid": true},
	"chair": {"name": "의자", "price": 80, "w": 21, "h": 24, "solid": true},
	"chest": {"name": "궤짝", "price": 150, "w": 45, "h": 39, "solid": true},
	"rug": {"name": "러그", "price": 120, "w": 132, "h": 60, "solid": false},
	"plant": {"name": "화분", "price": 100, "w": 24, "h": 30, "solid": true},
	"bookshelf": {"name": "책장", "price": 300, "w": 54, "h": 72, "solid": true},
	"lamp": {"name": "램프", "price": 150, "w": 18, "h": 39, "solid": true},
	"small_table": {"name": "탁자", "price": 140, "w": 42, "h": 36, "solid": true},
	# 사는 게 아니라 제작대에서 만들거나 선물로 받는 세간
	# (FURNITURE_IDS 밖 = 꾸미기 상점 미노출)
	"trash_bin": {"name": "쓰레기통", "price": 0, "w": 24, "h": 33, "solid": true},
	"storage_box": {"name": "수납 상자", "price": 0, "w": 33, "h": 27, "solid": true},
	"heart_rug": {"name": "하트 러그", "price": 0, "w": 96, "h": 78, "solid": false},
}
const FURNITURE_IDS := ["table", "chair", "chest", "rug", "plant", "bookshelf", "lamp", "small_table"]
# 제작·선물로 들여놓는 세간 — 집 확장 때 기본 세간에 밀려 지워지면 안 된다
const CRAFT_FURN := ["plant", "trash_bin", "heart_rug", "storage_box"]
var furniture: Array = []  # [{id, x, y}]


func default_furniture() -> Array:
	# 세간은 사람 크기에 맞춰 줄여 그린다 (interior_ui의 ZOOM). 자리 값은
	# 「줄이기 전」 왼쪽 위라, 예전 배치를 그대로 두면 식탁과 의자가 벌어진다.
	# 그래서 예전 배치를 통째로 같은 배율로 줄인 자리를 적어 둔다 —
	# 눈에 보이는 모양은 예전과 똑같고 크기만 작아진다.
	return [
		{"id": "rug", "x": 312.0, "y": 305.0},
		{"id": "table", "x": 346.0, "y": 258.0},
		{"id": "chair", "x": 346.0, "y": 284.0},
		{"id": "chair", "x": 415.0, "y": 284.0},
		{"id": "chest", "x": 455.0, "y": 234.0},
	]

# ---- 펫: 한 마리만 데리고 다니며 고유 패시브를 준다 ----
const PETS := {
	"dog": {"name": "강아지", "price": 2000, "passive": "이동 속도 +10%"},
	"cat": {"name": "고양이", "price": 2000, "passive": "낚시 입질 대기 -15%"},
	"owl": {"name": "부엉이", "price": 3500, "passive": "동굴 피해 -25%"},
	"rabbit": {"name": "토끼", "price": 3000, "passive": "작물 성장 +5%"},
}
const PET_IDS := ["dog", "cat", "owl", "rabbit"]
var owned_pets: Array = []
var active_pet := ""
var gender := "m"  # 플레이어 성별 (m/f) — 옛 세이브 호환용 (외형은 appearance가 쥔다)

# ---- 플레이어 외형 (타이틀 「새로 시작」에서 고른다) ----
# 머리는 스타일별로 도트 한 벌씩 있고(HAIR_PREFIX), 옷·바지·신발은
# 표준 팔레트(파랑 셔츠·갈색 바지·밤색 신발)로 뽑은 도트의 색을
# 실행 중에 갈아입힌다 (recolor_player_image). 게임 코드는 언제나
# 조립 결과인 pc_* 텍스처만 본다 (main.apply_appearance가 굽는다).
var appearance := {"hair": 0, "shirt": 0, "pants": 0, "shoes": 0,
	"skin": 0, "hair_col": 0}
const HAIR_PREFIX := ["new_boy", "hair_short", "hair_spiky", "player_f"]
const HAIR_NAMES := ["민머리", "짧은 머리", "삐죽 머리", "긴 머리"]
const SHIRT_NAMES := ["파랑", "분홍", "초록", "노랑"]
const PANTS_NAMES := ["갈색", "남색", "잿빛", "카키"]
const SHOES_NAMES := ["밤색", "검정", "빨강", "파랑"]
const SKIN_NAMES := ["살구", "흰 살결", "볕에 그은", "구릿빛", "갈색", "짙은 갈색"]
const HAIR_COL_NAMES := ["갈색", "검정", "짙은 갈색", "금발", "붉은 머리",
	"잿빛", "분홍", "하늘빛"]
# [기본, 그늘, 밝은 면] — 0번이 도트가 실제로 칠해진 표준 팔레트다
const APPEAR_SHIRT := [
	[[58, 88, 168], [38, 58, 120], [94, 126, 200]],
	[[214, 96, 116], [158, 60, 82], [232, 138, 152]],
	[[74, 138, 84], [48, 98, 60], [112, 176, 118]],
	[[206, 160, 60], [158, 114, 38], [232, 196, 102]],
]
const APPEAR_PANTS := [
	[[134, 88, 46], [98, 62, 32], [158, 108, 58]],
	[[64, 76, 116], [44, 54, 86], [88, 102, 144]],
	[[110, 110, 118], [80, 80, 88], [140, 140, 148]],
	[[126, 122, 72], [92, 88, 50], [154, 150, 96]],
]
const APPEAR_SHOES := [
	[[82, 53, 33], [56, 37, 25]],
	[[50, 48, 52], [32, 31, 35]],
	[[150, 58, 46], [106, 38, 30]],
	[[60, 76, 140], [40, 52, 102]],
]
# 피부 [기본, 밝은 면, 그늘, 볼, 입] — 도트에서 실제로 쓰이는 다섯 칸이다.
# (민머리는 정수리가 「밝은 면」, 머리 있는 쪽은 앞머리 밑이 「그늘」)
# 테두리(54,33,26)·눈(66,32,30)·눈썹(136,70,42)은 건드리지 않는다 —
# 피부를 아무리 어둡게 해도 얼굴선이 뭉개지지 않게.
const APPEAR_SKIN := [
	[[243, 159, 138], [250, 192, 170], [213, 116, 98], [235, 128, 114], [170, 84, 66]],
	[[252, 220, 203], [255, 240, 228], [232, 182, 166], [246, 196, 186], [205, 140, 126]],
	[[226, 166, 120], [240, 196, 156], [190, 126, 84], [220, 140, 104], [156, 92, 58]],
	[[198, 134, 92], [216, 166, 124], [158, 98, 62], [190, 112, 78], [128, 72, 44]],
	[[158, 102, 68], [182, 130, 94], [120, 72, 46], [150, 86, 58], [96, 54, 34]],
	[[116, 74, 50], [142, 98, 68], [84, 50, 32], [110, 62, 42], [68, 38, 24]],
]
# 머리카락 [기본, 밝은 면, 그늘] — 민머리(new_boy)에는 이 색이 아예 없어서
# 아무리 바꿔도 그림이 그대로다 (그래서 생성창에서 머리색 줄이 흐려진다)
const APPEAR_HAIR_COL := [
	[[118, 72, 40], [152, 100, 56], [86, 52, 30]],
	[[52, 46, 50], [78, 72, 78], [32, 28, 32]],
	[[84, 52, 32], [112, 74, 46], [58, 34, 20]],
	[[214, 170, 84], [240, 208, 132], [168, 124, 52]],
	[[190, 96, 48], [220, 134, 74], [142, 64, 30]],
	[[150, 148, 152], [186, 184, 188], [110, 108, 114]],
	[[214, 120, 160], [238, 160, 192], [164, 80, 118]],
	[[96, 140, 190], [132, 178, 220], [66, 100, 146]],
]


# 표준 팔레트로 뽑힌 플레이어 도트의 옷 색을 ap 선택에 맞춰 바꾼다.
# 색은 생성기(make_sprites.py PAL)와 정확히 같은 값이라 픽셀 단위로 맞는다.
func recolor_player_image(img: Image, ap: Dictionary) -> void:
	var mp := {}
	for tbl_sel in [[APPEAR_SHIRT, int(ap.shirt)], [APPEAR_PANTS, int(ap.pants)],
			[APPEAR_SHOES, int(ap.shoes)],
			[APPEAR_SKIN, int(ap.get("skin", 0))],
			[APPEAR_HAIR_COL, int(ap.get("hair_col", 0))]]:
		var tbl: Array = tbl_sel[0]
		var sel: int = clampi(int(tbl_sel[1]), 0, tbl.size() - 1)
		if sel == 0:
			continue
		for i in (tbl[0] as Array).size():
			var s: Array = tbl[0][i]
			var dst: Array = tbl[sel][i]
			mp[Color8(s[0], s[1], s[2]).to_rgba32()] = Color8(dst[0], dst[1], dst[2])
	if mp.is_empty():
		return
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var key := c.to_rgba32()
			if mp.has(key):
				img.set_pixel(x, y, mp[key])
# 메인 스토리 1 「우체부 아저씨와의 첫 만남」 진행 단계
# enter: 숲 안으로 들어가보기 / approach: 우체부 접근·대화 /
# equip: 나무도끼를 가방 슬롯에 장착 / chop: 나무를 베어보자 / done: 완료
var story_phase := "done"
# 벤 나무 자리의 재성장 대기열: [x, y, 남은 일수]
var tree_regrow: Array = []
# 유저 닉네임 · 농장 이름 · 마을 이름: 셋 다 타이틀의 캐릭터 생성창에서 정한다
var player_name := ""
var farm_name := ""
var village_name := ""

# 마을 건물은 **처음부터 다 서 있다**. 예전엔 재료를 모아 하나씩 지었는데(상점은
# 스토리 2, 나머지는 이장의 「마을 발전 이야기」) 그 짓기가 이야기의 흐름을 자꾸
# 끊었다 — 사람을 만나러 가는 길에 목재 서른을 세고 있었다. 이제 건물도 주인도
# 첫날부터 있고, 이야기는 「짓는다」가 아니라 「그 사람을 만난다」로 흐른다.
# (회관만은 문을 닫아 두었다가 주민이 모이면 개관식으로 연다 — 스토리 9)
# 건물 id는 main.gd의 VILLAGE_PLOTS 키. village_built 는 세이브 호환·개발 F7 때문에 남는다
const ALL_VILLAGE_PLOTS := ["post", "general", "lab", "smith", "ranch", "inn",
	"library", "fish", "hall"]
var village_built: Array = ALL_VILLAGE_PLOTS.duplicate()
# 첫날부터 마을에 있는 건물 주인들 — 첫 인사 없이도 가게가 열려 있다(npc_open)
const START_GREETED := ["merchant", "blacksmith", "postman", "librarian", "rancher",
	"fisher", "officer_park"]

# ---- 이장 거처 · 마을 성장 ----
#
# 이장은 처음부터 마을의 작고 낡은 오두막에서 산다 (제대로 된 집·회관 없음).
# 주민이 늘면(대략 4~6명 기준 — 아직 미확정, 전체 NPC 수가 정해지면 조정)
# 어느 날 아침 마을 사람들이 이장의 새 집을 지어 준다.
# 총 주민 수(플레이어 포함)가 10명을 넘어가면 마을회관이 해금된다 — 강제로
# 숫자를 맞추는 게 아니라, 게임을 진행하며 주민이 이사 올 때마다 조건을
# 재확인하는 트리거다. 완공되면 이장은 낮에 회관에서 업무를 보고,
# 집은 그대로 유지된다.
var chief_house_lv := 0            # 0=낡은 오두막 / 1=제대로 된 이장 집
const CHIEF_HOUSE_RESIDENTS := 5   # 새 집 기준 주민 수 (4~6 사이 — 추후 조정)
const HALL_RESIDENTS := 10         # 이 수를 「넘어가면」 마을회관 해금 (플레이어 포함)
var hall_noticed := false          # 해금 순간의 아침 안내를 한 번만 띄운다

# 잡화점 씨앗 선반에 진열되는 씨앗 — 처음에는 밀·옥수수 두 종뿐이고,
# 게임을 진행하면서 하나씩 늘어난다.
var shop_seeds: Array = ["wheat", "corn"]

# 메인 스토리 2에서 짓는 첫 상점의 재료 (main.VILLAGE_BUILD_COST.general과 같게)
const SHOP_BUILD_WOOD := 30
const SHOP_BUILD_STONE := 20

# 메인 스토리 2 진행 — 집 인사 후 이 순서로 이어진다:
#   shop: 재료를 모아 상점 짓기 / fisher: 낚시꾼 퀘스트(fisher_quest가 세부) /
#   farm_talk: 이장에게 가 호미 받기 / farm: 밭 갈기(STORY2_FLAGS) / done: 완료
var story2_phase := ""


func story2_objective_short() -> String:
	match story2_phase:
		"shop":
			# 옛 세이브에만 남는 단계(상점 짓기) — 로드가 fisher 로 옮기므로 보통은 안 온다
			return "분수 앞의 낚시꾼을 만나자."
		"farm_talk":
			return "이장과 대화하자."
		"farm":
			# **호미도 도끼와 같이 손을 잡아 준다.**
			#
			# 도끼는 빠른 슬롯에 넣을 때까지 기다려 주는 대목(equip)이
			# 따로 있는데, 호미는 「가방에서 슬롯에 넣어야 쓴다」는 말풍선
			# 한 줄이 전부였다. 안 넣고 지나가면 밭 앞에서 아무것도 안 된다 —
			# 같은 구조인데 한쪽만 손을 놓고 있었다
			if not tool_slots.has("hoe"):
				return "가방(I)에서 호미를 빠른 슬롯에 넣자."
			return "집 앞 풀밭을 갈아 밭을 만들자."
		"cook":
			# 첫 수확을 마친 뒤 — 만수가 밥 이야기를 꺼낸다.
			# 말을 걸고 나면 **그 뒤의 잔 단계를 그대로 이어서** 보여 준다.
			# (예전에는 이야기가 시작된 뒤에도 목표가 「만수와 대화하자」에
			#  멈춰 있어, 말을 걸어도 아무것도 안 된 것처럼 보였다)
			if kitchen_quest == "":
				return "잡화점 만수에게 말을 걸자."
			var step := kitchen_quest_objective_short()
			return step if step != "" else "만수에게 말을 걸자."
	return ""

# 낚시꾼 퀘스트 (메인 스토리 3): 전설의 황금잉어를 쫓는 낚시꾼과 함께
# 남쪽 바위 능선을 뚫어 바다·해변을 열고, 간이낚싯대(낚시)를 얻는다.
#   "": 아직 (첫 수확 뒤 시작) / meet: 광장의 낚시꾼에게 말 걸기 /
#   follow: 함께 능선으로 / open: 길목 바위 캐기 / done: 완료
var fisher_quest := ""
var fisher_choice := 0     # 황금잉어 선택지 (1: 꼭 잡겠다 / 2: 욕심 없다)
var sea_open := false      # 남쪽 바다·해변 개방 (능선 길목이 뚫렸다)
var sea_open_day := 0      # 바닷길이 열린 날 — 용식의 집터 부탁이 여기서 3일 뒤다

# ---- 서브 퀘스트: 용식의 집터 (낚시꾼) ----
#
# 바닷길을 연 지 **정확히 3일 뒤**, 용식이 광장 분수대 앞에 서 있다.
# 말을 걸면 바로 퀘스트가 시작되지 않고 「대화하기」 선택지가 먼저 뜬다 —
# 고르면 그제야 부탁을 꺼낸다. 이 마을이 마음에 들어 눌러앉고 싶으니
# 자기가 살 집을 한 채 지어 달라는 이야기다.
#   "": 아직 / wait: 분수대 앞에서 기다린다 (말 걸기) /
#   build: 집터를 놓고 집을 짓는다 / built: 집 완성 — 용식에게 알리기 /
#   done: 완료 (수납 상자 레시피)
var fisher_home := ""
# 새로 지은 집 앞 표지판 — 표지판 칸 -> 그 집의 앵커 [x, y].
# 「막 지은 이 건물이 누구 집인지」를 표지판을 눌러 정한다
var home_signs := {}
const FISHER_HOME_DAYS := 3        # 바닷길을 연 날로부터 며칠 뒤에 서 있는가


# 분수대 앞에 서 있을 조건 — 바닷길을 연 지 정확히 3일 뒤부터
func fisher_home_ready() -> bool:
	return fisher_quest == "done" and sea_open and sea_open_day > 0 \
		and day >= sea_open_day + FISHER_HOME_DAYS


func fisher_home_objective_short() -> String:
	match fisher_home:
		"wait":
			return "용식과 대화하자."
		"build":
			return "집을 짓고 표지판에서 정하자."
		"built":
			return "용식에게 알리자."
	return ""


# ---- 수납 상자 (용식의 부탁 보상) ----
#
# 목재 8개로 만드는 작은 상자. **집 안에** 놓으면 창고처럼 쓴다.
# 여러 개를 놓아도 안은 하나로 이어져 있다 (같은 창고를 나눠 쓴다) —
# 어느 상자를 열든 넣어 둔 것이 그대로 보이는 편이 헷갈리지 않는다.
var storage_stock := {}            # 아이템 id -> 개수
const STORAGE_SLOTS := 40          # 보관할 수 있는 아이템 「종류」 수


func storage_used() -> int:
	return storage_stock.size()


func storage_full() -> bool:
	return storage_used() >= STORAGE_SLOTS


# 가방 -> 상자. 넣은 개수를 돌려준다 (0이면 못 넣었다)
func storage_put(id: String, n: int) -> int:
	if n <= 0 or not ITEMS.has(id):
		return 0
	var have := int(items.get(id, 0))
	var move := mini(n, have)
	if move <= 0:
		return 0
	if not storage_stock.has(id) and storage_full():
		return 0
	items[id] = have - move
	storage_stock[id] = int(storage_stock.get(id, 0)) + move
	return move


# 상자 -> 가방
func storage_take(id: String, n: int) -> int:
	var have := int(storage_stock.get(id, 0))
	var move := mini(n, have)
	if move <= 0:
		return 0
	storage_stock[id] = have - move
	if int(storage_stock[id]) <= 0:
		storage_stock.erase(id)
	items[id] = int(items.get(id, 0)) + move
	return move


# 가방에서 상자에 넣을 수 있는 것 — 도구·장비처럼 개수가 없는 것은 뺀다
func storage_can_store(id: String) -> bool:
	return ITEMS.has(id) and int(items.get(id, 0)) > 0 \
		and id not in ["housing_kit", "settle_letter", "farewell_letter",
			"move_letter", "grandpa_seed"]

# 만수(잡화점)의 서브 퀘스트 「해변 노점」 — 바다가 열린 뒤부터 계산대
# 대화 선택지에 ❗로 뜬다. 재료를 모아다 주면 해변에 노점이 선다.
#   "": 아직 안 받음 / doing: 재료 모으는 중 / done: 노점 완성
var merchant_errand := ""
# 만수가 마을에 도착해 첫 인사를 나눈 날 (0 = 아직/구세이브).
# 도착 첫날은 잡화점에 요리 레시피 선반이 아직 없다 — 다음 날부터 진열
var merchant_day := 0
# 오늘 만수가 노점에 나와 있는 시각들 (분 단위 시작점). 하루 3번, 1시간씩 —
# 매일 아침 새로 뽑는다. 만수가 있어야 노점에서 「구매」할 수 있다 (판매는 상시).
var stall_hours: Array = []
const STALL_WOOD := 15         # 노점 재료: 목재
const STALL_SHELLS := 5        # 노점 재료: 조개 (장식 겸 진열대)
const STALL_VISITS := 3        # 하루 방문 횟수
const STALL_VISIT_MIN := 60    # 1회 방문 시간 (게임 분)
# 노점 한정 레시피 — 잡화점 선반에는 없는 낚시 요리들. id -> 가격
# 잡화점 생활용품 선반의 요리 레시피 (생선 요리 — 사서 「배우기」)
const SHOP_DISH_RECIPES := {
	"dish_grilled_fish": 200, "dish_fish_soup": 300, "dish_stew": 400,
	"dish_crab_soup": 500, "dish_sashimi": 600, "dish_golden_roast": 800,
}
const SHOP_DISH_IDS := ["dish_grilled_fish", "dish_fish_soup", "dish_stew",
	"dish_crab_soup", "dish_sashimi", "dish_golden_roast"]


# 잡화점 요리 레시피 진열 조건 — 그 요리에 드는 물고기를 한 번이라도
# 직접 낚아 봤어야 선반에 오른다 (만수가 "이 생선 요리법 필요하지?" 하는 셈).
# 물고기가 안 드는 요리라면 언제나 진열.
func shop_dish_on_shelf(did: String) -> bool:
	var needs: Dictionary = RECIPES.get(did, {}).get("needs", {})
	for mid: String in needs:
		if str(mid).begins_with("fish_") and int(fish_caught.get(mid, 0)) <= 0:
			return false
	return true


# 초반 음식 레시피 — 잡화점에서 단계적으로 풀린다. id -> 가격
# 산딸기잼 레시피는 **상점에서 팔지 않는다** — 퀘스트로만 얻는 첫 요리다
# (조리대를 찾는 안내의 선물 · 용식의 집터 부탁 보상)
const SHOP_FOOD_RECIPES := {
	"flour": 100, "dish_bread": 150, "dish_berry_toast": 250,
}
const SHOP_FOOD_IDS := ["flour", "dish_bread", "dish_berry_toast"]


# 초반 음식 레시피의 진열 조건 — 재료를 겪어 본 순서대로 하나씩 열린다.
#   밀가루        밀을 처음 수확했다 (수확이 곧 발견 기록)
#   빵            밀가루를 얻어 봤다
#   산딸기잼 토스트  밀가루나 산딸기잼 중 하나라도 만들어 봤다
func shop_food_on_sale(rid: String) -> bool:
	match rid:
		"flour":
			return discovered.has("wheat")
		"dish_bread":
			return discovered.has("flour")
		"dish_berry_toast":
			return int(recipes_cooked.get("flour", 0)) > 0 \
				or int(recipes_cooked.get("dish_berry_jam", 0)) > 0
	return false

const STALL_RECIPES := {
	"dish_smelt_fry": 800, "dish_eel_rice": 1500, "dish_salmon_steak": 1600,
}
const STALL_RECIPE_IDS := ["dish_smelt_fry", "dish_eel_rice", "dish_salmon_steak"]
const BAIT_PRICE := 8          # 미끼 한 개 값


# 오늘 만수가 노점에 나올 시각 세 개를 뽑는다 (9시~19시 사이, 서로 겹치지 않게)
func roll_stall_hours() -> void:
	stall_hours = []
	if merchant_errand != "done":
		return
	var tries := 0
	while stall_hours.size() < STALL_VISITS and tries < 200:
		tries += 1
		var start := randi_range(9 * 60, 18 * 60)
		var ok := true
		for s in stall_hours:
			if absi(start - int(s)) < STALL_VISIT_MIN:
				ok = false
				break
		if ok:
			stall_hours.append(start)
	stall_hours.sort()


func merchant_at_stall() -> bool:
	if merchant_errand != "done":
		return false
	for s in stall_hours:
		if minutes >= float(s) and minutes < float(s) + STALL_VISIT_MIN:
			return true
	return false


# ---- 메인 스토리 3: 새로운 주민의 이사 (편지 이주 + 집터 건설) ----
#
# 첫 수확 다음 날, 처음으로 「이주 희망 편지」가 도착한다. 보낸 사람은
# 호기심 많고 모험을 좋아하는 소년 재민. 이장과 상의해 받아주기로 하고,
# 이장은 앞으로의 이사 결정권을 플레이어에게 맡긴다. 집터 레시피(비싸다)를
# 사서 재료를 모아 집터를 만들고, 해금된 땅 중 원하는 풀밭에 집 자리를
# 직접 정하면 집이 지어진다. 다음 날 재민이 이사 와 첫인사를 나눈다.
# 이사가 끝나면 3장은 두 걸음 더 간다:
#   ② 재민이 배낭에서 씨앗을 꺼내 주며 **배고픔**을 알려 준다 (씨앗 심기)
#   ③ 이장이 우체국 이야기를 꺼낸다 — 우체국을 세우면 우체부 아저씨가
#      마을에 눌러앉는다 (3장의 마지막 퀘스트)
#   "": 아직 / letter: 편지 읽는 중 / show: 이장에게 보여주기 /
#   build: 집터 레시피 구매·제작·설치 / wait: 완공 — 내일 이사 온다 /
#   greet: 재민 도착 — 인사하러 가기 /
#   seed: 받은 씨앗을 밭에 심기 / seedrep: 재민에게 알리기 /
#   post: 이장에게 우체국 이야기 듣기 / postbuild: 우체국 짓기 /
#   postgreet: 우체부의 첫 인사 / done: 완료 (이주·집터 시스템 해금)
var move_quest := ""
const MOVE_SEEDS := 3        # 재민이 나눠 주는 씨앗 (이만큼 심으면 된다)
var move_seeds := 0          # 그중 심은 개수
var move_day := 0
var move_min := 0            # 집을 지은 시각 (분) — 여기서 조금 뒤에 이사 온다
const MOVE_WAIT_MIN := 120   # 두 시간쯤 지나면 짐을 들고 나타난다            # 단계 전환 기준 날 (편지 도착·이사 대기)
var move_house := Vector2i(-999, -999)   # 재민의 집 자리 (수락한 집터)
const HOUSING_KIT_PRICE := 2500          # 집터 레시피 값 — 일부러 비싸다
# 스프링클러는 퀘스트 보상이 아니라 잡화점 레시피가 됐다 —
# 농사 실력이 이만큼 붙어야 선반에 올라온다
const SPRINKLER_FARM_LV := 3
const SPRINKLER_RECIPE_PRICE := 500
# 미리 마련해 둔 빈 집터들 — [{x, y, used}]. **빈 집터가 있어야만**
# 이주 희망 편지를 수락할 수 있다 (수락하면 첫 빈 집터에 집이 지어진다)
var home_plots: Array = []
# 새터말(S3b) — 너른 초원 서쪽에 처음부터 있는 빈 집터 여덟(짓기 없음). 집 5×4 에 둘레 한 칸을
# 비운 7×6 격자. y 는 main.NORTH_PAD(12)를 더한 값이다(VILLAGE_ZONES 와 같은 이유). 장부에는
# 집이 선 자리만 {fixed:true, used:true} 로 적힌다 — 옛 마을 너머(스토리 4)가 열려야 자리로 센다
const MEADOW_PLOTS := [
	Vector2i(106, 62), Vector2i(114, 62), Vector2i(122, 62), Vector2i(130, 62),
	Vector2i(106, 70), Vector2i(114, 70), Vector2i(122, 70), Vector2i(130, 70),
]


# 이 앵커의 집터가 새터말인가
func plot_fixed_at(a: Vector2i) -> bool:
	return a in MEADOW_PLOTS


# 새터말의 자리가 찼나 — 장부에 used 로 적혀 있으면 집이 선 것
func meadow_plot_used(a: Vector2i) -> bool:
	for p: Dictionary in home_plots:
		if int(p.x) == a.x and int(p.y) == a.y and bool(p.get("used", false)):
			return true
	return false


# 새터말의 집터는 옛 마을 너머(스토리 4)가 열린 뒤에야 자리로 센다 — 재민의 이사(스토리 3)는
# 내가 마련한 집터로만 받는다. 내가 놓은 집터가 먼저, 새터말은 그다음
func first_empty_plot() -> Vector2i:
	for p: Dictionary in home_plots:
		if not bool(p.get("used", false)) and not bool(p.get("fixed", false)):
			return Vector2i(int(p.x), int(p.y))
	if story4_phase == "done":
		for a: Vector2i in MEADOW_PLOTS:
			if not meadow_plot_used(a):
				return a
	return Vector2i(-999, -999)


# 집이 서는 순간 장부에 적는다 — 내 집터는 used 로, 새터말은 새 줄로
func mark_plot_used(a: Vector2i) -> void:
	for p: Dictionary in home_plots:
		if int(p.x) == a.x and int(p.y) == a.y:
			p["used"] = true
			return
	if plot_fixed_at(a):
		home_plots.append({"x": a.x, "y": a.y, "used": true, "fixed": true})


func empty_plot_count() -> int:
	var n := 0
	if story4_phase == "done":
		for a: Vector2i in MEADOW_PLOTS:
			if not meadow_plot_used(a):
				n += 1
	for p: Dictionary in home_plots:
		if not bool(p.get("used", false)) and not bool(p.get("fixed", false)):
			n += 1
	return n


# ---- 제4장 서브 퀘스트: 새 이웃을 위한 빈 집터 셋 ----
#
# 옛 마을의 경계를 되찾자마자(스토리 4 완결) 이장이 덧붙이는 부탁이다.
# 땅이 넓어졌으니 이제 사람이 들어올 자리를 미리 마련해 두자는 이야기 —
# 빈 집터를 **PLOT3_GOAL개** 더 놓으면 이장에게 알리고 사례를 받는다.
#   "": 아직 / make: 집터를 놓는 중 / report: 다 놓았다 — 이장에게 /
#   done: 완료
var plot3_quest := ""
var plot3_made := 0               # 부탁을 받은 뒤로 새로 놓은 집터 수
const PLOT3_GOAL := 3
const PLOT3_MONEY := 900          # 이장이 마을 살림에서 떼어 주는 사례
const PLOT3_WOOD := 40            # 다음 집터에 보태라고 얹어 주는 목재
const PLOT3_STONE := 30


func plot3_objective_short() -> String:
	match plot3_quest:
		"make":
			return "빈 집터를 놓자 %d/%d" % [plot3_made, PLOT3_GOAL]
		"report":
			return "이장에게 알리자."
	return ""


# 빈 집터를 하나 놓을 때마다 story.try_place_home_plot이 불러 준다
func plot3_add() -> void:
	if plot3_quest != "make":
		return
	plot3_made += 1
	if plot3_made >= PLOT3_GOAL:
		plot3_quest = "report"


# ---- 우체국 — 편지 부치기와 보관함 ----
#
# 우체부가 자리를 잡으면(스토리 3 완결) 우체국이 두 가지 일을 맡는다.
#   · 부치기 — 마을 사람에게 편지 한 통. 값을 치르는 대신 마음이 오간다.
#     다음 날 아침 답장이 보관함에 도착하고 호감도가 조금 오른다.
#   · 보관함 — 가방에서 **수락한 편지**가 자동으로 여기로 옮겨져 남는다.
#     가방을 비워도 지난 편지는 우체국에 그대로 있다.
const MAIL_SEND_COST := 150       # 편지 한 통을 부치는 값
const MAIL_BOX_MAX := 40          # 보관함이 담아 두는 편지 수
const MAIL_REPLY_AFF := 3         # 답장이 오면 오르는 호감도
var mail_box: Array = []          # [{title, body, day}] — 오래된 것이 앞
var mail_out: Array = []          # 부치고 답장을 기다리는 편지 [{npc, day}]
var mail_sent_day := 0            # 하루 한 통 — 마지막으로 부친 날


# 보관함에 한 통 넣는다 (수락한 편지·도착한 답장 모두 이 문을 지난다)
func mail_store(title: String, body: String) -> void:
	mail_box.append({"title": title, "body": body, "day": day})
	while mail_box.size() > MAIL_BOX_MAX:
		mail_box.pop_front()


func mail_open() -> bool:
	return village_built.has("post")


func mail_sent_today() -> bool:
	return mail_sent_day == day and day > 0


# 아침에 도착한 답장들 — 보낸 사람 이름을 돌려준다 (day_cycle이 알린다)
func mail_new_day() -> Array:
	var came: Array = []
	for i in range(mail_out.size() - 1, -1, -1):
		var mo: Dictionary = mail_out[i]
		if day <= int(mo.get("day", 0)):
			continue
		var nid := str(mo.get("npc", ""))
		mail_out.remove_at(i)
		if not NPCS.has(nid):
			continue
		var nm := str(NPCS[nid].name)
		mail_store("%s의 답장" % nm, str(NPCS[nid].get("reply_letter",
			"『편지 잘 받았어요.\n덕분에 하루가 환했습니다. 또 써 주세요.』")))
		affinity[nid] = mini(int(affinity.get(nid, 0)) + MAIL_REPLY_AFF, 100)
		came.append(nm)
	return came
# 쓰레기통(무인 판매함) 판매 배율 — 24시간 아무 때나 파는 대신 제값의 80%
const TRASH_SELL_MULT := 0.8


func move_objective_short() -> String:
	match move_quest:
		"show":
			return "이장에게 편지를 보여주자."
		"build":
			if first_empty_plot().x >= 0:
				return "이주 편지를 읽고 수락하자."
			return "빈 집터를 마련하자."
		"wait":
			return "재민이 이사 오기를 기다리자."
		"greet":
			return "밖에서 재민을 기다리자."
		"seed":
			return "씨앗을 심자 %d/%d" % [move_seeds, MOVE_SEEDS]
		"seedrep":
			return "재민에게 알리자."
		"post":
			return "이장과 대화하자."
		"postbuild":
			return "우체국을 세우자."
		"postgreet":
			return "밖에서 우체부를 기다리자."
	return ""


# 밭에 씨앗을 한 알 심었다 (스토리 3의 두 번째 퀘스트를 진행하는 중이면 센다)
func move_seed_planted() -> void:
	if move_quest != "seed":
		return
	move_seeds += 1
	if move_seeds >= MOVE_SEEDS:
		move_quest = "seedrep"


# ---- 이주 NPC의 첫 인사 (공통 시스템) ----
#
# 건물이 완공되거나 이사가 확정된 「그날」에는 아직 영업도 일과도 없다.
# **다음 날** 아침, 그 NPC가 직접 플레이어를 찾아와 첫 인사를 나눈 뒤부터
# 정상적으로 장사(생활)를 시작한다. 앞으로 이주해 오는 모든 NPC 공통.
# (낚시꾼은 자기 퀘스트로 이미 인사를 나누는 특수 경로 — 여기 안 탄다)
var arrivals: Array = []      # [{"id": npc_id, "day": 확정된 날}] — 방문 대기열
var npc_greeted: Array = START_GREETED.duplicate()   # 첫 인사를 마친 NPC id — 이때부터 영업/일과. 건물 주인은 첫날부터

# ---- 자연물 리젠 ----
# 나무/돌/잡초를 캐서 없애면 그 자리가 아니라, 3~5일 뒤(자원마다 랜덤)
# 맵의 「빈자리 검사」를 통과한 랜덤 위치에서 새로 자란다.
# (world_gen._respawn_resources가 아침마다 처리 — 세이브에 그대로 남는다)
var respawn_queue: Array = []   # [{"kind", "removed": 제거일, "due": 리젠 예정일}]


func queue_respawn(kind: String) -> void:
	# 잡초는 금방 다시 돋는다 (1~2일) — 나무·돌은 3~5일 걸린다
	var days := randi_range(1, 2) if kind == "weed" else randi_range(3, 5)
	respawn_queue.append({"kind": kind, "removed": day, "due": day + days})


func npc_open(nid: String) -> bool:
	return nid in npc_greeted


# ---- 메인 스토리 4: 오래된 마을의 경계 ----
#
# 마을 동쪽 다리 건너, 낡은 표지판이 옛 마을의 경계를 알린다.
# 표지판을 확인하고(→"ask") 이장에게 물어보면 오래된 마을 지도를 보여
# 준다 — 지금 쓰는 땅은 옛 교진 마을의 일부일 뿐이다. 이야기 끝에 첫
# 구역이 열리고(→"done"), 남은 구역은 이장의 「마을 확장 이야기」에서
# 재료를 들여 하나씩 되살린다.
#
# 규칙: 해금 전 구역은 들어갈 수 없고(집터·설치물도 불가), 해금하면
# 보통 땅과 똑같이 쓴다.
var story4_phase := ""             # "" -> "ask"(이장에게 묻기) -> "done"
var zones_open: Array = []         # 열린 구역 id 목록
const VILLAGE_ZONES := {
	# y 는 main.gd 의 NORTH_PAD(12) 를 이미 더한 값이다. 여기서 KyojinMain 을
	# 참조하면 main -> GameData -> main 순환이 되어 파싱이 막힌다.
	"east_north": {"rect": Rect2i(100, 13, 68, 20), "name": "옛 마을 북동쪽 터"},
	"east_south": {"rect": Rect2i(100, 33, 68, 23), "name": "옛 마을 남동쪽 터"},
}
const ZONE_ORDER := ["east_north", "east_south"]
const ZONE_COST := {"east_north": [0, 0], "east_south": [60, 30]}  # [목재, 석재]


# 이 칸이 속한 (아직 잠긴/열린) 확장 구역 id — 구역 밖이면 ""
func zone_at(x: int, y: int) -> String:
	for zid: String in VILLAGE_ZONES:
		if (VILLAGE_ZONES[zid].rect as Rect2i).has_point(Vector2i(x, y)):
			return zid
	return ""


func story4_objective_short() -> String:
	if story4_phase == "ask":
		return "이장에게 표지판을 물어보자."
	return ""


# ---- 메인 스토리 6: 오래된 책과 사서 ----
#
# 스토리 5(숲속에서 발견한 집)를 끝내면 마을 어딘가 풀숲에 오래된 책이
# 놓인다. 책 -> 이장(모름) -> 우체부 편지 -> 며칠 뒤 사서 방문 ->
# 도서관 필요성 -> 이장 상의 -> 도서관 건설 -> 사서 정착 순서.
# 사서 서하는 도서관이 완성되고 정착 대화를 마쳐야 정식 주민이 된다.
var story6_phase := ""   # ""→find(책 놓임)→show_chief→ask_post→wait→visit→told→build→done
var story6_day := 0      # 편지를 부친 날 — 이틀 뒤 답장이 온다
const STORY6_REPLY_DAYS := 2
# 오래된 책 보관 여부 — 완결 후 도서관 서가로 옮겨진다 (판매·삭제 금지,
# 다음 메인 스토리에서 다시 꺼내 쓴다)
var old_book_stored := false


func story6_objective_short() -> String:
	match story6_phase:
		"show_chief":
			return "이장에게 책을 보여주자."
		"ask_post":
			return "우체부에게 편지를 부탁하자."
		"wait":
			return "사서의 답장을 기다리자."
		"visit":
			return "찾아온 사서를 만나자."
		"told":
			return "이장에게 사서 이야기를 전하자."
		"build":
			if village_built.has("library"):
				return "도서관이 완성됐다 — 사서에게 말을 걸자"
			return "도서관을 세우자."
	return ""


# ---- 메인 스토리 7: 식지 않는 화로 ----
#
# 스토리 6(오래된 책과 사서)을 끝내면, 대장장이 무쇠의 화로가 식어 간다.
# 무쇠의 고민 -> 서하가 복원 중인 오래된 책에서 옛 대장간 구절을 찾음 ->
# 동굴 깊은 곳의 광석·보석을 모아 화로를 되살린다.
# 완결하면 화로가 뜨거워져 도구 강화 골드 비용이 20% 싸진다.
#   "": 아직 / worry: 무쇠의 고민 듣기 / lore: 서하에게 물어보기 /
#   gather: 광석·보석 모아 무쇠에게 / done: 완료
var story7_phase := ""
const STORY7_ORE := 15    # 화로 재점화 재료: 광석
const STORY7_GEM := 2     # 화로 재점화 재료: 보석 (동굴 3층부터 나온다)
const FORGE_DISCOUNT := 0.8   # 완결 보상 — 강화 골드 비용 배수


# 화로가 되살아나면 도구 강화의 골드 비용이 싸진다 (재료는 그대로)
func forge_price(base: int) -> int:
	return int(base * FORGE_DISCOUNT) if story7_phase == "done" else base


func story7_objective_short() -> String:
	match story7_phase:
		"worry":
			return "무쇠와 대화하자."
		"lore":
			return "서하에게 물어보자."
		"gather":
			if int(items.get("ore", 0)) >= STORY7_ORE \
					and int(items.get("gem", 0)) >= STORY7_GEM:
				return "무쇠에게 가져다주자."
			return "광석과 보석을 모으자."
	return ""


# ---- 메인 스토리 8: 초원에서 온 목동 ----
#
# 스토리 7(식지 않는 화로)을 끝내면, 동물들과 초원을 찾아 떠도는 목동
# 보라가 마을을 찾아온다. 보라의 사정 -> 이장 상의 -> 목장 상회 건설
# (스토리 게이트) -> 보라 정착. 완결하면 목장 상회에서 동물·축사·말·펫을
# 들일 수 있다 — 동물 사육의 정식 개방이다.
#   "": 아직 / visit: 낯선 목동 만나기 / ask: 이장과 상의 /
#   build: 목장 상회 짓기(완공 후 보라에게) / done: 완료
var story8_phase := ""


func story8_objective_short() -> String:
	match story8_phase:
		"visit":
			return "목동을 만나자."
		"ask":
			return "이장과 상의하자."
		"build":
			if village_built.has("ranch"):
				return "보라와 대화하자."
			return "목장 상회를 세우자."
	return ""


# ---- 메인 스토리 9: 마을의 심장, 마을회관 ----
#
# 스토리 8(목동 정착)을 끝내면, 이장이 옛 교진 마을의 회관을 떠올리며
# 「주민을 초대해 마을을 키워 달라」고 부탁한다. 주민(플레이어 제외)이
# 10명이 되면 회관 건설이 열리고, 완공 후 접수대의 이장과 개관식을
# 하면 완결. 회관 기능은 한꺼번에 주어지지 않는다 — 마을이 클수록
# 하나씩 열린다 (개관: 명부·캘린더 / 12명: 창고 / 15명: 공동 프로젝트 /
# 20명: 마을 회의).
#   "": 아직 / ask: 이장의 부탁 듣기 / invite: 주민 초대하기 /
#   build: 회관 짓기(완공 후 개관식) / done: 완료
var story9_phase := ""
var residents_now := 1             # 지금 마을 주민 수 (플레이어 포함, main이 갱신)
const HALL_STORE_RES := 12         # 마을 창고 해금 (플레이어 포함 주민 수)
const HALL_PROJECT_RES := 15       # 공동 프로젝트 해금
const HALL_MEET_RES := 20          # 마을 회의 해금
const HALL_STOCK_MAX := 30         # 창고에 쌓이는 기부품 상한
const HALL_TRASH_G := 5            # 쓰레기 수거 미화 지원금 (개당)
const HALL_MEET_COOLDOWN := 7      # 마을 회의 간격 (일)

# 회관 창고 — 주민들이 아침마다 이따금 놓고 가는 물건 (id -> 수)
var hall_stock := {}
var hall_loot_day := 0             # 마지막으로 창고를 뒤적인 날 (하루 한 번)
var hall_trash_total := 0          # 지금까지 수거한 쓰레기 (마을 미화 기록)
var hall_projects: Array = []      # 완성한 공동 프로젝트 id
var hall_meet_day := 0             # 마지막 마을 회의 날
var hall_feat_noticed: Array = []  # 해금 안내를 띄운 기능 (한 번 열리면 닫히지 않는다)

# 공동 프로젝트 — 광장 둘레를 다 함께 가꾼다 (순서대로 하나씩)
#   tiles: 완성 시 세워지는 장식물 자리 (막힌 칸은 건너뛴다)
const HALL_PROJECTS := [
	{"id": "lamps", "name": "광장 가로등", "wood": 40, "stone": 20, "money": 2000,
		"desc": "광장 네 귀퉁이에 가로등을 세운다.\n밤 산책이 한결 든든해진다.",
		"tiles": [[71, 13], [83, 13], [71, 18], [83, 18]], "kind": "deco_lamp"},
	{"id": "benches", "name": "쉼터 벤치", "wood": 60, "stone": 0, "money": 3000,
		"desc": "광장 곁에 나무 벤치를 놓는다.\n주민들이 앉아 쉬며 수다를 떤다.",
		"tiles": [[73, 13], [81, 13]], "kind": "deco_bench"},
	{"id": "fountain", "name": "분수 새 단장", "wood": 0, "stone": 80, "money": 5000,
		"desc": "낡은 분수를 반짝반짝 손본다.\n마을의 자랑거리가 된다.",
		"tiles": [], "kind": ""},
]
# 아침 기부 풀 — 주민들이 창고에 놓고 가는 소박한 물건들 (보석은 귀하다)
const HALL_DONATE_POOL := ["forage_berry", "forage_herb", "forage_shell",
	"ore", "bait", "dish_bread", "gem"]


func story9_objective_short() -> String:
	match story9_phase:
		"ask":
			return "이장의 이야기를 듣자."
		"invite":
			return "주민을 초대하자 %d/%d" % [
				maxi(residents_now - 1, 0), HALL_RESIDENTS]
		"build":
			if village_built.has("hall"):
				return "접수대의 이장에게 가자."
			return "마을회관을 세우자."
	return ""


# 회관 기능의 점진 해금 — 주민이 늘 때마다 하나씩 열린다.
# 한 번 열린 기능은 주민이 줄어도 닫히지 않는다 (hall_feat_noticed).
func hall_feature_open(feat: String) -> bool:
	if story9_phase != "done":
		return false
	match feat:
		"store":
			return feat in hall_feat_noticed or residents_now >= HALL_STORE_RES
		"project":
			return feat in hall_feat_noticed or residents_now >= HALL_PROJECT_RES
		"meet":
			return feat in hall_feat_noticed or residents_now >= HALL_MEET_RES
	return true


# 다음에 열릴 기능 안내 한 줄 — 회관 공지판이 자연스럽게 예고한다
func hall_next_feature_text() -> String:
	if not hall_feature_open("store"):
		return "주민 %d명이면 마을 창고가 열린다. 지금 %d명" \
			% [HALL_STORE_RES, residents_now]
	if not hall_feature_open("project"):
		return "주민 %d명이면 공동 프로젝트가 열린다. 지금 %d명" \
			% [HALL_PROJECT_RES, residents_now]
	if not hall_feature_open("meet"):
		return "주민 %d명이면 마을 회의가 열린다. 지금 %d명" \
			% [HALL_MEET_RES, residents_now]
	return "마을의 모든 살림이 돌아가고 있다."


func hall_stock_total() -> int:
	var n := 0
	for iid in hall_stock:
		n += int(hall_stock[iid])
	return n


# 아침 기부 — 주민마다 낮은 확률로 창고에 물건을 놓고 간다.
# residents: 굴릴 주민 수 (플레이어 제외). 돌아오는 값은 쌓인 개수.
func hall_donate_morning(residents: int) -> int:
	if not hall_feature_open("store"):
		return 0
	var added := 0
	for _i in residents:
		if hall_stock_total() >= HALL_STOCK_MAX:
			break
		if randf() < 0.12:
			var iid := str(HALL_DONATE_POOL[randi() % HALL_DONATE_POOL.size()])
			if iid == "gem" and randf() > 0.2:
				iid = "forage_berry"   # 보석은 웬만해선 안 나온다
			hall_stock[iid] = int(hall_stock.get(iid, 0)) + 1
			added += 1
	return added


# 창고 뒤적이기 — 하루 한 번, 행운이 좋으면 보관품 하나를 얻는다.
# roll: 테스트용 강제 굴림(0~1). 음수면 랜덤. 돌아오는 값:
#   "" = 오늘 이미 뒤적였거나 창고가 비었다 / "miss" = 허탕 / 아이템 id = 획득
func hall_loot(roll := -1.0) -> String:
	if hall_loot_day == day or hall_stock.is_empty():
		return ""
	hall_loot_day = day
	var r := roll if roll >= 0.0 else randf()
	if r >= 0.35 + total_luck() * 0.03:   # 행운이 높을수록 손맛이 좋다
		return "miss"
	var ids: Array = hall_stock.keys()
	var iid := str(ids[randi() % ids.size()])
	hall_stock[iid] = int(hall_stock[iid]) - 1
	if int(hall_stock[iid]) <= 0:
		hall_stock.erase(iid)
	items[iid] = int(items.get(iid, 0)) + 1
	discover(iid)
	return iid


# 쓰레기 비우기 — 가방의 쓰레기를 회관 수거함에 몽땅 넣는다.
# 마을 미화 지원금(개당 5G)을 받는다. 돌아오는 값은 넣은 개수.
func hall_dump_trash() -> int:
	var n := int(items.get("forage_trash", 0))
	if n <= 0:
		return 0
	items["forage_trash"] = 0
	hall_trash_total += n
	money += HALL_TRASH_G * n
	return n


# ---- 메인 스토리 10: 동굴과 탐험 ----
#
# 스토리 9(마을회관)로 마을의 기반이 완성되면, 서하가 복원을 끝낸
# 오래된 책 마지막 장에서 할아버지의 「동굴 표본 조사」 기록을 찾아낸다.
# 연구 노트에 동굴 컬렉션 두 쪽이 열리고, 조사가 시작되면 동굴에
# 새 표본(수정·동굴 이끼·발광 버섯)이 모습을 드러낸다.
# 컬렉션을 다 채우면 **플레이에 실질적으로 도움이 되는 영구 보상**이
# 처음으로 강하게 체감되도록 설계했다 (아래 CAVE_COL_* 참고).
#   "": 아직 / note: 서하의 발견 듣기 / survey: 동굴 조사
#   (깊이 15층 + 표본 2종 발견 -> 서하에게 보고) / done: 완료
var story10_phase := ""
const STORY10_DEPTH := 15          # 조사 목표 깊이 (승강기 세 칸)
const CAVE_FINDS := ["crystal", "cave_moss", "glow_shroom"]   # 새 표본 3종
const STORY10_FINDS := 2           # 보고에 필요한 표본 종 수 (이끼방은 운이라 2종)


# 동굴 조사가 시작됐는가 — 새 표본은 이때부터 동굴에 나타난다
func story10_open() -> bool:
	return story10_phase in ["survey", "done"]


func cave_finds_found() -> int:
	var n := 0
	for id: String in CAVE_FINDS:
		if discovered.has(id):
			n += 1
	return n


# 조사 목표를 다 채웠는가 (서하에게 보고할 수 있는가)
func story10_survey_done() -> bool:
	return mine_deepest >= STORY10_DEPTH and cave_finds_found() >= STORY10_FINDS


func story10_objective_short() -> String:
	match story10_phase:
		"note":
			return "서하와 대화하자."
		"survey":
			if story10_survey_done():
				return "서하에게 알리자."
			return "동굴 조사 %d/%d층 · 표본 %d/%d" % [
				mini(mine_deepest, STORY10_DEPTH), STORY10_DEPTH,
				mini(cave_finds_found(), STORY10_FINDS), STORY10_FINDS]
	return ""


# ---- 메인 스토리 11: 할머니의 모자 ----
#
# 스토리 10 완결 + 마을 회의를 한 번 진행 + 연구 노트 20% —
# 조건이 차면 이장이 직접 플레이어를 찾아와 첫 유품 이야기를 꺼낸다.
# 주민들에게 단서를 모으고(그동안 농사·낚시·강화 등 자유 생활 그대로),
# 동굴 50층 광석을 캐다 「할머니의 모자」를 발견한다 (이야기 중에는
# 확정 드랍 — try_relic(0)의 굴림을 cave_ui가 확정으로 넘긴다).
# 모자를 얻으면 도서관에 「할머니의 기록」 첫 장이 열린다 — 기록은
# 유품 하나에 한 장씩, 한 번에 다 공개하지 않는다.
#   "": 아직 / visit: 이장이 찾아온다(연출) / clue: 단서 수집 /
#   deep: 동굴 50층 — 광석에서 모자 발견 / record: 도서관 기록 / done
var story11_phase := ""
var story11_clues: Array = []      # 단서를 들려준 주민 id
const STORY11_CLUE_NPCS := ["blacksmith", "librarian", "forest_mom"]
const STORY11_NOTE := 0.2          # 시작 조건 — 연구 노트 진행률
const STORY11_FLOOR := 50          # 모자가 잠든 깊이 (RELICS[0]의 힌트 층)
var grandma_read := 0              # 「할머니의 기록」 읽은 장 수 (점진 공개)

# 할머니의 기록 — 유품 하나를 찾을 때마다 한 장씩 열린다 (RELICS 순서.
# 가진 유품의 장만 보인다 — 한 번에 다 공개하지 않는다).
# 장이 갈수록 두 분의 이야기가 조금씩 짙어진다 (모자 < 팔찌 < ...)
const GRANDMA_RECORDS := [
	"『교진 마을 부녀회 명부』 — 빛바랜 명단 맨 앞에 할머니의 이름이 있다.\n\n"
	+ "「밭일 나갈 때도 늘 그 챙 넓은 모자를 쓰고 계셨지. 광부들 도시락을\n"
	+ "싸 들고 굴까지 내려가시던 분은 마을에 그분뿐이었어.」 — 옛 주민의 메모.\n\n"
	+ "할아버지의 글씨가 여백에 작게 남아 있다.\n「당신이 굴에 두고 온 모자, 내가 꼭 찾아다 주리다.」",
	"『바닷가의 약속』 — 물때가 적힌 낡은 조석표 사이에 편지 한 장.\n\n"
	+ "「그 사람은 바다를 참 좋아했다. 해 질 무렵이면 늘 서쪽 모래밭 끝\n"
	+ "바위께로 나를 끌고 갔지. 첫 수확을 판 돈으로 팔찌를 사 주던 날,\n"
	+ "파도가 유난히 잔잔했다.」 — 할아버지의 필체.\n\n"
	+ "뒷장에는 서툰 그림 — 바위에 기대앉은 두 사람과, 물결 위의 노을.\n"
	+ "「폭풍이 몰아치던 해, 바다는 많은 것을 가져갔다.\n"
	+ "...하지만 언젠가 돌려주리라 믿는다. 바다도 약속은 지키니까.」",
	"『두 사람의 시작』 — 빛바랜 혼인 기록과, 그 사이에 끼워진 사진 한 장.\n\n"
	+ "「그 사람은 마을 밖 옛 농지에서 일하던 처녀였다. 나는 밭 가는 법을\n"
	+ "가르쳐 달라는 핑계로 매일 그 밭을 찾아갔지. ...핑계인 걸\n"
	+ "그 사람도 알고 있었을 거다.」\n\n"
	+ "「혼인하던 해 봄, 나는 반지 하나를 겨우 마련했다. 그 사람은 그걸\n"
	+ "끼고도 밭일을 했고, 어느 날 흙 속에 잃어버렸다며 한참을 울었다.\n"
	+ "괜찮다고, 내가 언젠가 꼭 찾아 주겠다고 했었는데.」",
	"『동물과 함께한 나날』 — 낡은 사료 장부 뒤에 적힌 글.\n\n"
	+ "「그 사람은 짐승을 참 잘 다뤘다. 아픈 송아지가 있으면 밤을 새워\n"
	+ "곁을 지켰고, 목장 사람들은 그 사람을 『짐승들의 어머니』라 불렀지.」\n\n"
	+ "「목에 걸던 목걸이를 아이들이 자꾸 잡아당겨서, 일할 땐 늘 어딘가에\n"
	+ "벗어 두곤 했다. 그날도 그랬을 거다. ...그 사람이 떠난 뒤로,\n"
	+ "나는 그 헛간 근처를 지나가지 못했다.」",
	"『마지막 언덕』 — 여기서부터는 기록이 아니라 편지다.\n"
	+ "서하가 흩어진 종이들을 날짜 순으로 이어 붙여 두었다.\n\n"
	+ "「그 사람이 걷기 힘들어진 뒤로, 우리는 한 달에 한 번\n"
	+ "언덕에 올랐다. 한나절이 걸려도 꼭 가자고 했다.\n"
	+ "『우리 밭이 저기 있네』 — 늘 그렇게 손가락으로 짚었지.」\n\n"
	+ "「마지막으로 오른 날, 그 사람은 차고 있던 시계를 풀어\n"
	+ "내 손에 쥐여 주었다. 『먼저 가서 기다릴 테니, 늦게 와요.』\n"
	+ "...나는 그 시계를 언덕에 묻었다. 차마 볼 수가 없어서.」\n\n"
	+ "「이제 와 적어 둔다. 언젠가 이 노트를 이어받을 누군가가\n"
	+ "이 언덕을 찾아 준다면, 그때는 시계를 꺼내 주기를.\n"
	+ "멈춘 시계라도, 다시 누군가의 손목 위에서 돌기를.」",
]


# 시작 조건 — 마을 기반 완성(스토리 10) + 회의 경험 + 노트 20%
func story11_ready() -> bool:
	return story10_phase == "done" and hall_meet_day > 0 \
		and note_progress().ratio >= STORY11_NOTE


func story11_objective_short() -> String:
	match story11_phase:
		"visit":
			return "이장이 찾아오고 있다."
		"clue":
			return "모자 이야기를 듣자 %d/%d" % [
				story11_clues.size(), STORY11_CLUE_NPCS.size()]
		"deep":
			if int(items.get("relic_hat", 0)) > 0:
				return "할머니의 모자를 찾았다!"
			return "동굴 %d층까지 내려가자 · 지금 %d층" % [
				STORY11_FLOOR, mine_deepest]
		"record":
			return "도서관에서 「할머니의 기록」을 읽자"
	return ""


# ---- 메인 스토리 12: 숲의 연금술사 ----
#
# 스토리 11 뒤 곧장 이어지지 않는다 — 자유 생활을 하다 **연구 노트 40%
# + 서로 다른 주민 5명과 호감도 3단계(하트 3개, 30)**를 채우면, 노트에서
# 할아버지의 낯선 기록(끝내 혼자 풀지 못해 누군가의 도움을 받은 연구)이
# 발견된다. 서하의 옛 기록 -> 주민 소문 -> 깊은 숲의 숨은 길 ->
# 연금술사의 오두막. 연금술사 묘연은 마을에 입주하지 않고 숲속 집에서
# 계속 살며, 필요할 때 직접 찾아가야 한다. 재료 시험(여러 생활 콘텐츠)을
# 통과하면 시연을 보여 주고 — 그때부터 집 조합대의 연금술이 열린다.
# 연금술은 새 능력치 분야가 아니라 7대 분야를 보조하는 제작 시스템이다.
#   "": 아직 / note: 노트의 낯선 기록 확인(N) / ask: 서하에게 보여주기 /
#   gossip: 주민 소문 수집 / path: 숨은 길·오두막 발견 /
#   gather: 재료 시험 / done: 연금술 해금
var story12_phase := ""
var story12_heard: Array = []      # 소문을 들려준 주민 id
const STORY12_NOTE := 0.4          # 시작 조건 — 연구 노트 진행률
const STORY12_FRIENDS := 5         # 시작 조건 — 호감도 3단계 주민 수
const STORY12_AFF_LV := 30         # 호감도 3단계 = 하트 3개
const STORY12_RUMORS := 3          # 소문을 들어야 하는 주민 수
# 재료 시험 — 여러 생활 콘텐츠에서 하나씩 (동굴 수정·숲 약초·낚시 붕어.
# 종류·개수는 추후 별도 확정 예정 — 지금은 임시값)
const STORY12_MATS := {"crystal": 2, "forage_herb": 5, "fish_crucian": 3}


func story12_friends() -> int:
	var n := 0
	for nid in affinity:
		if int(affinity[nid]) >= STORY12_AFF_LV:
			n += 1
	return n


# 시작 조건 — 스토리 11 뒤 자유 생활을 충분히 거친 다음에야 열린다
func story12_ready() -> bool:
	return story11_phase == "done" and note_progress().ratio >= STORY12_NOTE \
		and story12_friends() >= STORY12_FRIENDS


func story12_mats_ok() -> bool:
	for mid in STORY12_MATS:
		if int(items.get(mid, 0)) < int(STORY12_MATS[mid]):
			return false
	return true


# 연금술(집 조합대)이 열렸는가 — 스토리 12를 끝내야 쓸 수 있다
func alchemy_open() -> bool:
	return story12_phase == "done"


func story12_mats_text() -> String:
	var parts: Array = []
	for mid in STORY12_MATS:
		parts.append("%s %d/%d" % [ITEMS[mid].name,
			mini(int(items.get(mid, 0)), int(STORY12_MATS[mid])),
			int(STORY12_MATS[mid])])
	return " · ".join(parts)


func story12_objective_short() -> String:
	match story12_phase:
		"note":
			return "연구 노트를 확인하자."
		"ask":
			return "서하에게 기록을 보여주자."
		"gossip":
			return "연금술사 이야기를 듣자 %d/%d" % [
				story12_heard.size(), STORY12_RUMORS]
		"path":
			return "깊은 숲의 숨은 길을 찾자."
		"gather":
			if story12_mats_ok():
				return "연금술사에게 가져다주자."
			return "재료를 모으자 " + story12_mats_text()
	return ""


# ---- 메인 스토리 13: 할머니의 팔찌 ----
#
# 두 번째 유품. 스토리 12 완결 뒤 곧장 이어지지 않는다 — 자유 생활을
# 며칠 보낸 다음(임시 조건, 세부 시작 조건은 추후 확정) 용식가 「요즘
# 그물에 물고기 대신 낡은 물건이 올라온다」는 이야기를 꺼낸다.
# 주민들에게 할머니와 바다 이야기를 모으면 두 분이 자주 찾던 해변
# 서쪽 끝 바위가 조사 지점으로 드러나고, 그 곁에서 낚시하면 스토리
# 중에만 생기는 특별한 입질로 「낡은 작은 상자」가 올라온다. 상자는
# 녹슬어 바로 못 연다 — 연금술사 묘연이 재료(임시값)를 받아 안전하게
# 열어 준다 (스토리 12에서 해금한 연금술의 자연스러운 재활용).
# 팔찌를 얻으면 도서관 「할머니의 기록」 2장(바닷가의 약속)이 열린다.
#   "": 아직 / rumor: 용식의 이상한 이야기 / clue: 주민 단서 수집 /
#   spot: 해변 바위·특별 낚시 / box: 낡은 상자 — 연금술사에게 /
#   open: 개봉 재료 준비 / record: 도서관 기록 / done
var story13_phase := ""
var story13_heard: Array = []      # 바다 이야기를 들려준 주민 id
var story12_done_day := 0          # 스토리 12를 끝낸 날 (자유 생활 보장)
const STORY13_REST_DAYS := 3       # 임시 — 스토리 12 뒤 이만큼 지나야 시작
const STORY13_TALES := 3           # 이야기를 들어야 하는 주민 수
# 상자 개봉 재료 — 녹을 녹이는 간단한 것들 (종류·개수는 추후 확정, 임시값)
const STORY13_MATS := {"glow_shroom": 2, "forage_glass": 3}


# 시작 조건 (임시) — 스토리 12 완결 + 자유 생활 며칠 + 바다가 열려 있고
# 팔찌를 아직 못 찾았을 때. 세부 조건은 추후 별도 확정 예정.
func story13_ready() -> bool:
	return story12_phase == "done" and sea_open \
		and day >= story12_done_day + STORY13_REST_DAYS \
		and int(items.get("relic_bracelet", 0)) == 0


func story13_mats_ok() -> bool:
	for mid in STORY13_MATS:
		if int(items.get(mid, 0)) < int(STORY13_MATS[mid]):
			return false
	return true


func story13_mats_text() -> String:
	var parts: Array = []
	for mid in STORY13_MATS:
		parts.append("%s %d/%d" % [ITEMS[mid].name,
			mini(int(items.get(mid, 0)), int(STORY13_MATS[mid])),
			int(STORY13_MATS[mid])])
	return " · ".join(parts)


func story13_objective_short() -> String:
	match story13_phase:
		"rumor":
			return "용식의 이야기를 듣자."
		"clue":
			return "바다 이야기를 듣자 %d/%d" % [
				story13_heard.size(), STORY13_TALES]
		"spot":
			return "해변 서쪽 바위 곁에서 낚시하자."
		"box":
			return "묘연에게 상자를 가져가자."
		"open":
			if story13_mats_ok():
				return "묘연에게 상자를 열어 달라 하자."
			return "재료를 모으자 " + story13_mats_text()
		"record":
			return "도서관에서 「할머니의 기록」을 읽자"
	return ""


# ---- 메인 스토리 14: 마을의 첫 축제 ----
#
# 스토리 13 뒤 자유 생활을 며칠 보내면, 이장이 마을회관에서 회의를 열어
# 「주민이 이만큼 늘었으니 우리 손으로 첫 축제를 열자」고 제안한다.
# 준비는 여섯 가지 중 **셋만 고르면 된다** — 지금까지 연 생활 콘텐츠
# (농사·요리·낚시·목장·벌목·제작)에서 하나씩 가져왔다. 주민들도 저마다
# 맡은 몫을 준비하니 혼자 차리는 축제가 아니다.
# 준비가 끝나면 이튿날 광장에서 축제가 열리고(전용 대사 + 투호 미니게임),
# 이장의 마무리 인사와 함께 회관의 「축제·행사 일정」이 정식 해금된다.
#   "": 아직 / meet: 회관 회의 / prep: 준비(3/6) /
#   fest: 축제 당일 — 광장 / done: 완료
var story14_phase := ""
var story13_done_day := 0          # 스토리 13을 끝낸 날 (자유 생활 보장)
var story14_tasks: Array = []      # 끝낸 준비 항목 id
var story14_greet: Array = []      # 준비 이야기를 들려준 주민
var story14_fest_day := 0          # 축제가 열리는 날
var story14_toss := false          # 투호 미니게임을 해 봤는가
const STORY14_REST_DAYS := 3       # 스토리 13 뒤 이만큼 지나야 시작 (임시)
const STORY14_PICK := 3            # 여섯 항목 중 몇 개만 하면 되는가

# 축제 준비 항목 — kind로 「무엇을 세는가」가 갈린다. 맡은 주민은 저마다
# 제 몫을 준비하고 있고, 플레이어는 그중 셋만 거들면 된다.
const FEST_TASKS := [
	{"id": "crop", "name": "잔치상 채소", "kind": "produce", "need": 10,
		"npc": "chief", "desc": "광장 상에 올릴 밭 것들 (아무 작물)"},
	{"id": "dish", "name": "나눔 음식", "kind": "dish", "need": 3,
		"npc": "merchant", "desc": "다 같이 나눠 먹을 요리 (아무 요리)"},
	{"id": "fish", "name": "구이용 물고기", "kind": "fish", "need": 3,
		"npc": "fisher", "desc": "숯불에 구울 생선 (아무 물고기)"},
	{"id": "ranch", "name": "목장 잔치상", "kind": "ranch", "need": 6,
		"npc": "rancher", "desc": "달걀과 우유"},
	{"id": "wood", "name": "모닥불 장작", "kind": "wood", "need": 30,
		"npc": "blacksmith", "desc": "광장 한복판에 지필 장작"},
	{"id": "flower", "name": "광장 꽃 장식", "kind": "flower", "need": 2,
		"npc": "librarian", "desc": "화분 (제작대에서 만든다)"},
]


# 준비 항목의 지금 보유량 — 종류를 가리지 않고 뭉쳐 센다
func fest_have(kind: String) -> int:
	var n := 0
	if kind == "produce":
		for cid in produce:
			n += int(produce[cid])
	elif kind == "dish":
		for rid: String in RECIPE_IDS:
			n += int(items.get(rid, 0))
	elif kind == "fish":
		for fid: String in FISH_IDS:
			n += int(items.get(fid, 0))
	elif kind == "ranch":
		n = int(items.get("egg", 0)) + int(items.get("milk", 0))
	elif kind == "wood":
		n = wood
	elif kind == "flower":
		n = int(items.get("flower_pot", 0))
	return n


func _fest_consume(kind: String, need: int) -> void:
	var left := need
	if kind == "produce":
		for cid in produce:
			if left <= 0:
				break
			var take: int = mini(left, int(produce[cid]))
			if take > 0:
				consume_produce(cid, take)
				left -= take
		return
	if kind == "wood":
		wood = maxi(0, wood - need)
		return
	var ids: Array = ["flower_pot"]
	if kind == "dish":
		ids = RECIPE_IDS
	elif kind == "fish":
		ids = FISH_IDS
	elif kind == "ranch":
		ids = ["egg", "milk"]
	for iid: String in ids:
		if left <= 0:
			break
		var t2: int = mini(left, int(items.get(iid, 0)))
		if t2 > 0:
			items[iid] = int(items[iid]) - t2
			left -= t2


# 준비 항목 내놓기 — 재료를 내면 그 몫이 끝난다
func fest_deliver(tid: String) -> bool:
	if tid in story14_tasks:
		return false
	for t: Dictionary in FEST_TASKS:
		if str(t.id) != tid:
			continue
		if fest_have(str(t.kind)) < int(t.need):
			return false
		_fest_consume(str(t.kind), int(t.need))
		story14_tasks.append(tid)
		return true
	return false


func fest_prep_done() -> bool:
	return story14_tasks.size() >= STORY14_PICK


# 시작 조건 (임시) — 스토리 13 완결 + 자유 생활 며칠 + 회관이 서 있을 것
func story14_ready() -> bool:
	return story13_phase == "done" and village_built.has("hall") \
		and day >= story13_done_day + STORY14_REST_DAYS


# 회관의 「축제·행사 일정」 — 첫 축제를 치러야 정식으로 열린다
func hall_calendar_open() -> bool:
	return story14_phase == "done"


func story14_objective_short() -> String:
	match story14_phase:
		"meet":
			return "회관에서 회의를 듣자."
		"prep":
			return "축제 준비 %d/%d" % [
				story14_tasks.size(), STORY14_PICK]
		"fest":
			if day < story14_fest_day:
				return "내일 광장에서 축제가 열린다."
			return "축제를 즐기고 이장과 대화하자."
	return ""


# ---- 메인 스토리 15: 마른 온천 ----
#
# 스토리 14 뒤 자유 생활을 며칠 보내면, 이장이 옛 온천 이야기를 꺼낸다.
# 서하의 옛 기록으로 온천수가 동굴 지하 수맥과 이어져 있었음을 알고,
# 무쇠에게 수맥을 뚫을 「착암 쐐기」를 벼려 받아 동굴 깊은 곳(20층+)에서
# 무너진 바위와 몬스터를 헤치며 수맥을 되살린다. 솟은 물은 묘연이
# 살펴 준 뒤에야 마을 온천으로 흐른다 — 복구하면 온천 시설이 열린다.
#   "": 아직 / tale: 이장의 옛 온천 이야기 / book: 도서관 기록 /
#   tool: 대장간 착암 쐐기 / dig: 동굴 수맥 뚫기 /
#   water: 묘연의 물 확인 / done: 온천 부활
var story15_phase := ""
var story14_done_day := 0
var story15_mobs := 0              # 수맥 둘레에서 처치한 몬스터
var story15_ore := 0               # 무너져 쌓인 바위·광석을 걷어낸 수
var onsen_open := false            # 온천 시설 해금
var onsen_day := 0                 # 마지막으로 입욕한 날 (하루 한 번)
const STORY15_REST_DAYS := 3
const STORY15_DEPTH := 20          # 수맥이 막힌 깊이
const STORY15_MOBS := 8            # 수맥 둘레를 지키던 것들
const STORY15_ORE := 12            # 무너져 쌓인 바위·광석
const STORY15_TOOL_ORE := 20       # 착암 쐐기 재료
const STORY15_TOOL_SHARD := 2
const ONSEN_HOURS := 2.0           # 입욕에 흐르는 시간


func story15_ready() -> bool:
	return story14_phase == "done" \
		and day >= story14_done_day + STORY15_REST_DAYS


func story15_dig_done() -> bool:
	return story15_mobs >= STORY15_MOBS and story15_ore >= STORY15_ORE


# 온천에 몸을 담근다 — 하루 한 번, 시간이 흐르고 체력이 가득 찬다
func onsen_bathe() -> bool:
	if not onsen_open or onsen_day == day:
		return false
	onsen_day = day
	energy = ENERGY_MAX
	minutes = minf(minutes + ONSEN_HOURS * 60.0, DAY_END - 60.0)
	return true


func story15_objective_short() -> String:
	match story15_phase:
		"tale":
			return "이장에게 온천을 물어보자."
		"book":
			return "도서관에서 기록을 찾자."
		"tool":
			if int(items.get("rock_wedge", 0)) > 0:
				return "쐐기를 들고 동굴로 가자."
			return "무쇠에게 쐐기를 부탁하자."
		"dig":
			if story15_dig_done():
				return "쐐기로 바위를 뚫자 · 동굴 %d층" % STORY15_DEPTH
			return "동굴 %d층 · 몬스터 %d/%d · 바위 %d/%d" % [
				STORY15_DEPTH, mini(story15_mobs, STORY15_MOBS), STORY15_MOBS,
				mini(story15_ore, STORY15_ORE), STORY15_ORE]
		"water":
			return "묘연에게 물을 보여주자."
	return ""


# ---- 메인 스토리 16: 할머니의 반지 ----
#
# 세 번째 유품. 스토리 15 뒤 자유 생활을 며칠 보내고 연구 노트가
# 어느 정도 차면, 도서관에서 두 분의 혼인 기록이 열린다 — 반지는
# 마을 밖 「옛 농지」에서 흙 속에 잃어버렸다. 전투가 아니라 **농사·
# 벌목·채집**으로 푸는 장이다: 우거진 옛 농지를 걷어내고(잡초·돌·나무),
# 땅을 다시 갈다 보면 흙 속에서 낡은 상자가 나온다.
#   "": 아직 / record: 도서관 혼인 기록 / clue: 주민 단서 /
#   clear: 옛 농지 정리 + 밭 갈기 / tale: 도서관 새 기록 / done
var story16_phase := ""
var story15_done_day := 0
var story16_heard: Array = []
var story16_clear := 0             # 걷어낸 잡초·돌·나무
var story16_till := 0              # 갈아엎은 밭
const STORY16_REST_DAYS := 3
const STORY16_NOTE := 0.6          # 도서관 혼인 기록이 열리는 노트 진행률
const STORY16_TALES := 3
const STORY16_CLEAR := 8           # 옛 농지에서 걷어낼 자연물
const STORY16_TILL := 6            # 다시 갈 밭 칸


func story16_ready() -> bool:
	return story15_phase == "done" and note_progress().ratio >= STORY16_NOTE \
		and day >= story15_done_day + STORY16_REST_DAYS


func story16_field_done() -> bool:
	return story16_clear >= STORY16_CLEAR and story16_till >= STORY16_TILL


func story16_objective_short() -> String:
	match story16_phase:
		"record":
			return "도서관에서 두 분의 오래된 기록을 읽자"
		"clue":
			return "농지 이야기를 듣자 %d/%d" % [
				story16_heard.size(), STORY16_TALES]
		"clear":
			if story16_field_done():
				return "옛 농지를 한 번 더 갈자."
			return "농지 정리 %d/%d · 밭 갈기 %d/%d" % [
				mini(story16_clear, STORY16_CLEAR), STORY16_CLEAR,
				mini(story16_till, STORY16_TILL), STORY16_TILL]
		"tale":
			return "도서관에서 「할머니의 기록」을 읽자"
	return ""


# ---- 메인 스토리 17: 할머니의 목걸이 ----
#
# 네 번째 유품. 보라가 낡은 마구간 창고를 치우다 할머니 이름이 적힌
# 천 조각을 찾아내며 시작한다. **목장·동물 돌보기·탐색**의 장이다:
# 방치된 옛 헛간 둘레를 치우고 동물들을 돌보다 보면, 낡은 사료통
# 아래에서 목걸이가 나온다.
#   "": 아직 / cloth: 보라의 천 조각 / clue: 주민 단서 /
#   barn: 옛 헛간 정리 + 동물 돌보기 / tale: 도서관 기록 / done
var story17_phase := ""
var story16_done_day := 0
var story17_heard: Array = []
var story17_done_day := 0          # 스토리 17을 끝낸 날 (다음 이야기의 자유 생활)
var story17_clear := 0             # 헛간 둘레에서 걷어낸 것
var story17_care := 0              # 동물을 돌본 횟수
const STORY17_REST_DAYS := 3
const STORY17_TALES := 3
const STORY17_CLEAR := 6
const STORY17_CARE := 5


func story17_ready() -> bool:
	return story16_phase == "done" \
		and day >= story16_done_day + STORY17_REST_DAYS


func story17_barn_done() -> bool:
	return story17_clear >= STORY17_CLEAR and story17_care >= STORY17_CARE


func story17_objective_short() -> String:
	match story17_phase:
		"cloth":
			return "보라와 대화하자."
		"clue":
			return "목장 이야기를 듣자 %d/%d" % [
				story17_heard.size(), STORY17_TALES]
		"barn":
			if story17_barn_done():
				return "낡은 사료통을 살펴보자."
			return "헛간 정리 %d/%d · 동물 돌보기 %d/%d" % [
				mini(story17_clear, STORY17_CLEAR), STORY17_CLEAR,
				mini(story17_care, STORY17_CARE), STORY17_CARE]
		"tale":
			return "도서관에서 「할머니의 기록」을 읽자"
	return ""


# ---- 메인 스토리 18: 할머니의 시계 ----
#
# 마지막 유품. 스토리 17 뒤 자유 생활 + 연구 노트가 후반까지 차면,
# 도서관에서 할아버지의 오래된 메모가 열린다 — 늘 차고 다니던 시계와
# 두 분이 자주 오르던 언덕. 단서를 좇아 마을 밖 옛 전망대에 오르면
# 흔적을 하나씩 살피며 두 분의 마지막 추억을 알게 되고, 마지막에
# 숨겨진 보관함에서 시계가 나온다. 유품 다섯이 모두 모이는 장이라
# 연출과 대화가 앞선 유품보다 길다.
#   "": 아직 / memo: 도서관의 오래된 메모 / clue: 사서·주민 단서 /
#   hill: 전망대 흔적 조사(세 곳) / box: 숨겨진 보관함 /
#   tale: 도서관 마지막 기록 / done
var story18_phase := ""
var story18_traces: Array = []     # 살펴본 흔적
const STORY18_REST_DAYS := 3
const STORY18_NOTE := 0.8          # 후반부까지 찬 연구 노트
const STORY18_TALES := 3

# 전망대의 흔적 세 곳 — 살필 때마다 두 분의 마지막이 조금씩 드러난다
const HILL_TRACES := [
	{"id": "bench", "name": "무너진 나무 의자",
		"text": "비바람에 삭은 의자 하나가 언덕 끝을 보고 놓여 있다.\n등받이에 두 사람이 나란히 기댔던 자국이 남았다.\n\n"
			+ "「걷기 힘들어진 뒤로, 그 사람은 여기까지 오는 데\n한나절이 걸렸다. 그래도 매번 오자고 했다.」"},
	{"id": "stone", "name": "글씨가 새겨진 돌",
		"text": "납작한 돌에 두 글자가 나란히 새겨져 있다.\n한쪽 글씨는 삐뚤빼뚤, 다른 쪽은 반듯하다.\n\n"
			+ "「그 사람이 먼저 새기고, 내 것은 내가 새겼다.\n손이 떨려 반듯하지 못했다고 한참을 웃었지.」"},
	{"id": "tree", "name": "굽은 나무",
		"text": "바람을 오래 맞아 마을 쪽으로 굽은 나무 한 그루.\n밑동에 낡은 끈이 감겨 있다.\n\n"
			+ "「여기서 보면 마을이 다 보인다. 그 사람은 늘\n『우리 밭이 저기 있네』 하고 손가락으로 짚었다.\n마지막 날에도 그랬다.」"},
]


func story18_ready() -> bool:
	return story17_phase == "done" and note_progress().ratio >= STORY18_NOTE \
		and day >= story17_done_day + STORY18_REST_DAYS


func story18_objective_short() -> String:
	match story18_phase:
		"memo":
			return "도서관에서 메모를 읽자."
		"clue":
			return "언덕 이야기를 듣자 %d/%d" % [
				story18_heard.size(), STORY18_TALES]
		"hill":
			return "전망대의 흔적을 살펴보자 %d/%d" % [
				story18_traces.size(), HILL_TRACES.size()]
		"box":
			return "숨겨진 보관함을 열어 보자."
		"tale":
			return "도서관에서 마지막 기록을 읽자"
	return ""


var story18_heard: Array = []
var story18_done_day := 0          # 시계를 찾은 날 — 스토리 19가 여기서 이어진다


# ---- 메인 스토리 19: 일곱 갈래의 삶 (생명의 물) ----
#
# 마지막 유품을 찾으면, 할아버지의 기록에서 「일곱 가지 분야를 끝까지
# 익힌 사람에게 남겨지는 것」이라는 구절이 드러난다. 채광·벌목·농사·
# 요리·전투·낚시·목장을 만렙까지 올릴 때마다 그 분야의 증표로 생명의
# 물이 한 병씩 주어지고(이미 만렙인 분야는 소급 지급), 일곱 병이 다
# 모이면 노트의 마지막 페이지가 열린다 — 스토리 20으로 이어진다.
#   "": 아직 / seek: 일곱 분야 만렙 도전(자유 생활) / page: 마지막 페이지 /
#   done: 마지막 장소의 단서를 얻음
var story19_phase := ""
var story19_shown: Array = []      # 전용 연출을 이미 본 분야 id


func story19_ready() -> bool:
	return story18_phase == "done"


func water_count() -> int:
	return water_life_found.size()


# 분야 이름 — 만렙 연출과 노트의 생명의 물 칸에 쓴다
const SKILL_WATER_NAME := {
	"mine": "채광", "forest": "벌목", "farm": "농사", "cook": "요리",
	"combat": "전투", "fish": "낚시", "ranch": "목장",
}
# 만렙 연출의 한 줄 — 그 분야를 끝까지 익혔다는 것이 어떤 의미인지
const SKILL_WATER_LINE := {
	"mine": "「굴의 어둠이 더는 무섭지 않다.\n어느 돌을 때려야 하는지, 손이 먼저 안다.」",
	"forest": "「나무가 어느 쪽으로 넘어갈지 보인다.\n베어 낸 자리마다 다시 심을 줄도 알게 됐다.」",
	"farm": "「흙을 쥐면 목이 마른지 아닌지 알 수 있다.\n할아버지가 늘 하시던 그 말이, 이제야.」",
	"cook": "「불의 세기를, 간을, 뜸 들이는 시간을 — 이제는\n누구에게 물어보지 않아도 된다.」",
	"combat": "「겁이 사라진 건 아니다. 다만 겁을 안고도\n한 발 더 나아갈 수 있게 됐을 뿐이다.」",
	"fish": "「물낯만 봐도 무엇이 있는지 알겠다.\n기다릴 줄 알게 된 것이, 아마 제일 큰 변화다.」",
	"ranch": "「짐승들이 먼저 다가온다.\n『짐승들의 어머니』라 불리던 분도 이랬을까.」",
}


func story19_objective_short() -> String:
	match story19_phase:
		"seek":
			return "생명의 물 %d/%d" % [
				water_count(), ENDING_SKILLS.size()]
		"page":
			return "노트의 마지막 페이지가 열렸다."
	return ""


# 노트의 마지막 페이지 — 생명의 물 일곱 병이 다 모이면 읽을 수 있다
func note_last_page_open() -> bool:
	return water_count() >= ENDING_SKILLS.size() and story19_phase != ""


# ---- 메인 스토리 20: 가장 오래된 자리 (최종 엔딩) ----
#
# 세 가지가 다 갖춰져야 시작한다 — 연구 노트 100% · 유품 다섯 · 생명의 물
# 일곱. 노트의 마지막 페이지가 가리키는 곳은 동굴 가장 깊은 곳,
# 마을이 서기 훨씬 전부터 그 아래에 잠겨 있던 오래된 돌문이다.
# 아무도 열지 못했고, 그래서 아무도 내려가 보지 않던 자리.
# 일곱 병을 홈에 부으면 문이 열리고, 그 안쪽이 할아버지의 마지막
# 연구 공간이다.
#   "": 아직 / tell: 사서·이장에게 보여주기 / gate: 동굴 입구로 /
#   inner: 문 안쪽 — 봉인된 것과의 마지막 / letter: 씨앗과 편지 /
#   plant: 다음 날 농장에 씨앗 심기 / done: 엔딩을 보았다 (자유 생활 계속)
var story20_phase := ""
var note_last_line := false        # 노트 마지막 장에 플레이어가 남긴 한 줄
var story20_told: Array = []       # 단서를 보여 준 사람 (서하·이장)
var gate_open := false             # 돌문이 열렸다 (로드 후에도 열린 채)
var seed_day := 0                  # 씨앗을 손에 넣은 날 — 다음 날 심는다
var seed_tile := Vector2i(-1, -1)  # 씨앗을 심은 칸 (엔딩 후 자라난다)
var seed_water := false            # 심은 뒤 물을 주었는가
const STORY20_TELL := ["librarian", "chief"]


# 오래된 돌문은 **세계에 놓인 오브젝트가 아니다.**
#
# 한때는 마을 북쪽에 세워 두었지만, 어느 자리에 두어도 상점 마당·길과
# 겹쳐 통행을 막는 일이 생겼다. 그래서 오브젝트를 통째로 없애고,
# 그 문을 **동굴 가장 깊은 곳**으로 옮겼다 — 스토리 20에서 동굴 입구에
# 서면 이야기가 이어지고, 일곱 병을 부으면 가장 깊은 곳이 열린다.
# (gate_open은 그대로 「그 문이 열렸는가」를 기억한다)


func story20_ready() -> bool:
	return story19_phase == "done" and relics_owned() >= RELICS.size() \
		and note_progress().ratio >= 1.0


func story20_objective_short() -> String:
	match story20_phase:
		"tell":
			return "마지막 페이지를 보여주자 %d/%d" % [
				story20_told.size(), STORY20_TELL.size()]
		"gate":
			if gate_open:
				return "가장 깊은 곳으로 내려가자."
			return "동굴 입구로 가자."
		"inner":
			return "가장 깊은 곳으로 나아가자."
		"letter":
			return "집으로 돌아가자."
		"plant":
			if seed_tile.x < 0:
				return "밭을 갈고 씨앗을 심자."
			if not seed_water:
				return "씨앗에 물을 주자."
			return "새싹이 돋았다."
	return ""


# ---- 우측 상단 퀘스트 추적창 ----
#
# 「지금 따라가는 퀘스트」 하나를 제목/현재 목표/한두 줄 설명으로 돌려준다.
# hud가 매 프레임 이걸 읽어 그리므로, 단계가 바뀌면 즉시 갱신된다.
# 메인 스토리 1의 서두 — Q창에서 이야기 위에 얹는다.
# (단계별 「story」 문장은 그 뒤에 이어 붙인다)
const STORY1_TALE := """낯선 숲의 아침이었다.
손에는 할아버지가 남긴 열쇠 하나,
주머니에는 아직 부치지 못한 편지 한 장.

길을 잃고 서 있던 너에게 우체부 아저씨가 말을 걸었다.
「같이 갈까? 나도 그 마을로 가는 길이거든.」

나란히 찍히던 두 사람의 발자국에서
이 이야기는 시작된다."""


# 지금 진행 중인 퀘스트 전부 — 미니창 고정(핀) 선택지가 된다.
# 앞쪽일수록 「자동」일 때 우선순위가 높다 (메인 스토리 먼저).
# 진행 중 퀘스트 카탈로그 — Q창(좌측 목록/우측 상세)과 미니 트래커가 함께 쓴다.
# 항목: id/title/obj/desc + cat("main"/"sub"/"guide"/"daily") + ep(메인 회차 라벨)
#       + npc(퀘스트를 준 인물 — 초상화 키의 가운데 토막) + reward(보상 안내문)
func quest_catalog() -> Array:
	var out: Array = []
	var o := story_objective_short()
	if o != "":
		var cur := story_current_quest()
		out.append({"id": "story1", "title": str(cur.get("name", "처음 온 마을")),
			"obj": o, "desc": STORY1_TALE + "\n\n" + str(cur.get("story", "")),
			"cat": "main", "ep": "메인 스토리 1", "npc": "postman",
			"reward": "새 도구와 나만의 집"})
	o = story2_objective_short()
	if o != "":
		out.append({"id": "story2", "title": "마을을 깨우다", "obj": o,
			"desc": "할아버지가 떠난 뒤, 교진 마을은 조용히 잠들었다.\n"
				+ "가게도 뱃길도 밭도 하나씩 문을 닫았고, 남은 사람들은\n"
				+ "서로의 안부만 물으며 긴 겨울을 났다.\n\n"
				+ "이장은 마디 굵은 두 손을 마주 잡고 이렇게 말한다.\n"
				+ "「자네가 온 뒤로 아침 공기가 달라졌어. ...정말일세.」\n\n"
				+ "누군가 다시 문을 열고, 누군가 다시 그물을 던지고,\n"
				+ "누군가 다시 흙을 갈면 — 마을은 그렇게 깨어난다.",
			"cat": "main", "ep": "메인 스토리 2", "npc": "chief",
			"reward": "상점·바다·밭 — 마을의 기틀"})
	o = fisher_objective_short()
	if o != "":
		out.append({"id": "fisher", "title": "낚시꾼과 바닷길", "obj": o,
			"desc": "어떤 사람은 평생 한 마리의 물고기를 쫓는다.\n\n"
				+ "황금빛 비늘 이야기를 품고 온 낚시꾼이\n"
				+ "남쪽 바위 능선 앞에 서서, 넘어가지 못한 바다를 본다.\n"
				+ "능선 너머에는 아무도 오래 보지 못한 파도가 있다.\n\n"
				+ "돌 하나를 걷어내는 일이지만, 그 하나로\n"
				+ "이 마을은 잃어버렸던 바다를 되찾는다.",
			"cat": "main", "ep": "메인 스토리 2", "npc": "fisher",
			"reward": "바다·해변 해금 + 간이낚싯대"})
	o = move_objective_short()
	if o != "":
		var mv_npc := "explorer"
		if move_quest in ["show", "post", "postbuild"]:
			mv_npc = "chief"
		elif move_quest == "postgreet":
			mv_npc = "postman"
		out.append({"id": "move", "title": "새로운 주민의 이사", "obj": o,
			"desc": "먼 길 위에서 쓴 편지 한 통이 문 앞에 놓였다.\n"
				+ "「저는 재민이에요. 이 마을에서 살고 싶어요.」\n\n"
				+ "지붕이 없으면 아무도 머무를 수 없는 법이다.\n"
				+ "누군가의 첫 집이 될 자리를 네 손으로 고르고,\n"
				+ "그 아이가 나눠 줄 씨앗을 흙에 묻고,\n"
				+ "편지가 오갈 우체국까지 세우고 나면 —\n\n"
				+ "이 마을은 비로소 「사람이 찾아오는 곳」이 된다.",
			"cat": "main", "ep": "메인 스토리 3", "npc": mv_npc,
			"reward": "이주 편지·집터 시스템 해금 + 우체국·우체부"})
	o = forest_objective_short()
	if o != "":
		var f_npc := "explorer"
		if forest_quest in ["ask", "back"]:
			f_npc = "chief"
		out.append({"id": "forest", "title": "숲속에서 발견한 집", "obj": o,
			"desc": "숲을 쏘다니던 재민이 숨을 몰아쉬며 달려왔다.\n"
				+ "「나무 사이에 집이 한 채 있었어. 정말이야!」\n\n"
				+ "삼십 년 이장을 지낸 사람도 처음 듣는 집.\n"
				+ "굴뚝에는 연기가 오르고, 마당에는 빨래가 널려 있다.\n"
				+ "누가, 왜, 마을을 등지고 살고 있는 걸까.\n\n"
				+ "이장과 재민을 앞세워 함께 가 보자.\n"
				+ "문을 두드리기 전까지는 아무도 알 수 없다.",
			"cat": "main", "ep": "메인 스토리 5", "npc": f_npc,
			"reward": "호감도 시스템 해금"})
	# 후속: 연화가 문을 여는 날 (스토리 5 이후 · 호감도로 연다)
	o = forest_trust_objective_short()
	if o != "":
		out.append({"id": "forest_trust", "title": "닫힌 문 앞에서", "obj": o,
			"desc": "그날 연화는 끝내 문을 열어 주지 않았다.\n"
				+ "당연한 일이다. 우리는 낯선 사람이었으니까.\n\n"
				+ "이장의 말대로 자주 얼굴을 비추고,\n"
				+ "말을 붙이고, 손이 필요할 때 거들었다.\n\n"
				+ "오늘 그 집 앞을 지나는데,\n"
				+ "연화가 먼저 이쪽을 보고 있었다.",
			"cat": "sub", "npc": "forest_mom",
			"reward": "집 안으로 — 솔이와의 첫 만남"})
	o = story4_objective_short()
	if o != "":
		out.append({"id": "story4", "title": "오래된 마을의 경계", "obj": o,
			"desc": "동쪽 다리 너머, 이끼에 덮인 낡은 표지판 하나.\n"
				+ "지워진 글씨를 손으로 훑으면 옛 마을 이름이 드러난다.\n\n"
				+ "지금보다 훨씬 넓었던, 사람들이 살던 자리.\n"
				+ "덤불에 잠긴 그 길을 다시 여는 일은\n"
				+ "떠난 이웃들에게 「돌아와도 된다」고 말하는 일과 같다.",
			"cat": "main", "ep": "메인 스토리 4", "npc": "chief",
			"reward": "마을 확장 해금"})
	o = story6_objective_short()
	if o != "":
		var s6map := {"show_chief": "chief", "ask_post": "postman",
			"wait": "postman", "visit": "librarian", "told": "chief",
			"build": "librarian"}
		var s6npc: String = str(s6map.get(story6_phase, "chief"))
		out.append({"id": "story6", "title": "오래된 책과 사서", "obj": o,
			"desc": "풀을 뽑다가 흙 속에서 두꺼운 책 한 권이 나왔다.\n"
				+ "표지는 삭았지만 글씨는 아직 살아 있다.\n\n"
				+ "이장도 끝까지 읽어 내지 못하는 오래된 문장들.\n"
				+ "이런 책은 읽어 줄 사람이 있어야 비로소 이야기가 된다.\n\n"
				+ "먼 도시로 편지 한 통을 부치는 것부터 시작하자.",
			"cat": "main", "ep": "메인 스토리 6", "npc": s6npc,
			"reward": "도서관 해금 + 사서 정착"})
	o = story7_objective_short()
	if o != "":
		var s7npc := "librarian" if story7_phase == "lore" else "blacksmith"
		out.append({"id": "story7", "title": "식지 않는 화로", "obj": o,
			"desc": "며칠째 대장간의 망치 소리가 뜸하다.\n"
				+ "「불이 예전만큼 오래 붙어 있질 않아.」\n\n"
				+ "옛 대장장이들은 불씨를 재우지 않는 법을 알았고,\n"
				+ "그 방법은 아무도 펼쳐 보지 않은 책 속에 잠들어 있다.\n\n"
				+ "다시 붉게 달아오를 화로를 위해,\n"
				+ "땅속에서 잠자던 것들을 몇 가지 꺼내 오자.",
			"cat": "main", "ep": "메인 스토리 7", "npc": s7npc,
			"reward": "도구 강화 골드 비용 20% 할인"})
	o = story8_objective_short()
	if o != "":
		var s8npc := "chief" if story8_phase == "ask" else "rancher"
		out.append({"id": "story8", "title": "초원에서 온 목동", "obj": o,
			"desc": "바람 냄새를 맡으며 걷는 사람이 마을에 들어왔다.\n"
				+ "뒤에는 소 한 마리와 닭 두 마리.\n\n"
				+ "「좋은 풀밭을 찾고 있어요. 여긴... 냄새가 좋네요.」\n\n"
				+ "평생 초원을 찾아 떠돌던 사람이\n"
				+ "여기서 걸음을 멈출 수 있도록,\n"
				+ "울타리와 지붕을 마련해 주자.",
			"cat": "main", "ep": "메인 스토리 8", "npc": s8npc,
			"reward": "목장 상회 해금 — 동물을 키울 수 있다"})
	o = story9_objective_short()
	if o != "":
		out.append({"id": "story9", "title": "마을의 심장, 마을회관", "obj": o,
			"desc": "이장은 종종 광장 한가운데를 오래 바라본다.\n"
				+ "예전엔 그 자리에 마을회관이 서 있었다고 한다.\n\n"
				+ "비 오는 날엔 처마 밑에 모여 떡을 나눠 먹고,\n"
				+ "겨울엔 난로 하나로 온 마을이 따뜻했다는 이야기.\n\n"
				+ "사람이 모이면 건물이 서고,\n"
				+ "건물이 서면 또 사람이 온다.",
			"cat": "main", "ep": "메인 스토리 9", "npc": "chief",
			"reward": "마을회관 — 명부·창고·프로젝트가 차례로 열린다"})
	o = story10_objective_short()
	if o != "":
		out.append({"id": "story10", "title": "동굴과 탐험", "obj": o,
			"desc": "오래된 책의 마지막 장에는 그림이 그려져 있었다.\n"
				+ "땅속 깊은 곳에서만 자란다는 이끼와 버섯,\n"
				+ "별빛을 머금었다는 돌 하나.\n\n"
				+ "할아버지는 그것들을 「아직 기록되지 않은 이웃」이라 불렀다.\n\n"
				+ "등불을 들고, 아무도 세어 보지 않은 층으로 내려가자.",
			"cat": "main", "ep": "메인 스토리 10", "npc": "librarian",
			"reward": "동굴 컬렉션 — 채우면 영구 채광·탐험 보상"})
	o = story11_objective_short()
	if o != "":
		var s11npc := "chief"
		if story11_phase == "record":
			s11npc = "librarian"
		out.append({"id": "story11", "title": "할머니의 모자", "obj": o,
			"desc": "할머니는 밭에 나갈 때 늘 밀짚모자를 썼다.\n"
				+ "챙이 넓어 그늘이 꼭 두 사람 몫이었다고 한다.\n\n"
				+ "그 모자가 어쩌다 굴속까지 갔는지는 아무도 모른다.\n"
				+ "다만 마을 사람들은 저마다 다른 조각을 기억한다.\n\n"
				+ "하나씩 이어 붙이면 길이 되는, 그런 이야기들을.",
			"cat": "main", "ep": "메인 스토리 11", "npc": s11npc,
			"reward": "할머니의 모자 + 도서관 「할머니의 기록」"})
	o = story12_objective_short()
	if o != "":
		var s12npc := ""
		if story12_phase == "ask":
			s12npc = "librarian"
		elif story12_phase == "gather":
			s12npc = "alchemist"
		out.append({"id": "story12", "title": "숲의 연금술사", "obj": o,
			"desc": "노트에는 늘 두 사람의 필체가 번갈아 나온다.\n"
				+ "하나는 할아버지, 다른 하나는 이름이 없다.\n\n"
				+ "숲 안쪽에 사는 사람이라는 소문만 떠돌 뿐,\n"
				+ "누구도 그 얼굴을 본 적이 없다고 한다.\n\n"
				+ "안개가 걷히는 날에만 드러난다는 오솔길 끝에서\n"
				+ "그 사람은 여태 무언가를 끓이고 있을지도 모른다.",
			"cat": "main", "ep": "메인 스토리 12", "npc": s12npc,
			"reward": "연금술 해금 — 집 조합대에서 물약을 만든다"})
	o = story13_objective_short()
	if o != "":
		var s13npc := ""
		match story13_phase:
			"rumor":
				s13npc = "fisher"
			"box", "open":
				s13npc = "alchemist"
			"record":
				s13npc = "librarian"
		out.append({"id": "story13", "title": "할머니의 팔찌", "obj": o,
			"desc": "바다는 무엇이든 오래 간직한다.\n\n"
				+ "파도에 밀려온 낡은 상자 하나를 두고\n"
				+ "마을 사람들이 저마다 옛이야기를 꺼내 놓는다.\n\n"
				+ "소금기에 굳어 열리지 않는 뚜껑 안에는\n"
				+ "할머니가 여름마다 차고 다녔다는 팔찌가 들어 있을까.",
			"cat": "main", "ep": "메인 스토리 13", "npc": s13npc,
			"reward": "할머니의 팔찌 + 「할머니의 기록」 2장"})
	o = story14_objective_short()
	if o != "":
		out.append({"id": "story14", "title": "마을의 첫 축제", "obj": o,
			"desc": "주민이 하나둘 늘면서 광장이 붐비기 시작했다.\n\n"
				+ "이장이 색 바랜 종이 한 장을 꺼내 놓는다.\n"
				+ "예전 축제의 차례가 적힌 목록이다.\n\n"
				+ "음식과 등불과 노래 — 하나씩 채워 넣으면\n"
				+ "이 마을에도 다시 축제의 밤이 온다.",
			"cat": "main", "ep": "메인 스토리 14", "npc": "chief",
			"reward": "마을회관 「축제·행사 일정」 해금"})
	o = story15_objective_short()
	if o != "":
		var s15npc := "chief"
		match story15_phase:
			"book":
				s15npc = "librarian"
			"tool":
				s15npc = "blacksmith"
			"water":
				s15npc = "alchemist"
		out.append({"id": "story15", "title": "마른 온천", "obj": o,
			"desc": "북쪽 바위 밑에는 김이 오르던 자리가 있었다.\n"
				+ "지금은 마른 돌 틈에 낙엽만 쌓여 있다.\n\n"
				+ "물길이 끊긴 건 땅속 어딘가가 막혔기 때문이라고 한다.\n\n"
				+ "뜨거운 물에 어깨를 담그던 저녁을 되찾으려면\n"
				+ "아주 깊은 곳까지 한 번 내려가 보아야 한다.",
			"cat": "main", "ep": "메인 스토리 15", "npc": s15npc,
			"reward": "온천 해금 — 몸을 담그면 체력이 가득 찬다"})
	o = story16_objective_short()
	if o != "":
		out.append({"id": "story16", "title": "할머니의 반지", "obj": o,
			"desc": "혼인하던 해 봄, 할머니는 반지를 잃어버렸다.\n"
				+ "밭일을 하다 흙 속에 떨어뜨렸다고 했다.\n\n"
				+ "할아버지는 그 밭을 평생 갈지 않았다.\n"
				+ "「언젠가 나올 거야」 하고 웃으면서.\n\n"
				+ "이제는 수풀에 덮인 그 땅을, 다시 일으켜 보자.",
			"cat": "main", "ep": "메인 스토리 16",
			"npc": "librarian" if story16_phase in ["record", "tale"] else "",
			"reward": "할머니의 반지 + 「할머니의 기록」 3장"})
	o = story17_objective_short()
	if o != "":
		out.append({"id": "story17", "title": "할머니의 목걸이", "obj": o,
			"desc": "짐승들은 할머니 곁에서만 순해졌다고 한다.\n"
				+ "아픈 송아지가 밤새 그 무릎을 베고 잤다는 이야기도.\n\n"
				+ "목에 걸고 다니던 나무 목걸이는\n"
				+ "헛간이 무너지던 날 이후로 아무도 보지 못했다.\n\n"
				+ "낡은 헛간을 조용히 치우는 일부터 시작하자.",
			"cat": "main", "ep": "메인 스토리 17",
			"npc": "librarian" if story17_phase == "tale" else "rancher",
			"reward": "할머니의 목걸이 + 「할머니의 기록」 4장"})
	o = story18_objective_short()
	if o != "":
		out.append({"id": "story18", "title": "할머니의 시계", "obj": o,
			"desc": "마을 북서쪽 언덕에는 무너져 가는 전망대가 있다.\n"
				+ "두 분이 마지막으로 함께 오른 자리다.\n\n"
				+ "해가 지는 쪽으로 나란히 앉아 있었다는 이야기,\n"
				+ "그리고 그날 이후 멈춰 버린 시계 하나.\n\n"
				+ "남은 온기를 더듬어, 마지막 유품을 찾아오자.",
			"cat": "main", "ep": "메인 스토리 18",
			"npc": "librarian" if story18_phase in ["memo", "tale"] else "",
			"reward": "할머니의 시계 — 유품 다섯이 모두 모인다"})
	o = story19_objective_short()
	if o != "":
		out.append({"id": "story19", "title": "일곱 갈래의 삶", "obj": o,
			"desc": "할아버지는 일곱 가지 일을 두루 익힌 사람이었다.\n"
				+ "흙과 물, 굴과 숲, 짐승과 손끝과 발걸음.\n\n"
				+ "하나를 끝까지 갈고닦을 때마다\n"
				+ "맑은 물 한 병이 조용히 남겨진다고 했다.\n\n"
				+ "일곱 병이 모이는 날, 노트의 마지막 장이 열린다.",
			"cat": "main", "ep": "메인 스토리 19", "npc": "",
			"reward": "생명의 물 7종 + 연구 노트 마지막 페이지"})
	o = story20_objective_short()
	if o != "":
		var s20npc := ""
		if story20_phase == "tell":
			s20npc = "librarian" if "librarian" not in story20_told else "chief"
		out.append({"id": "story20", "title": "가장 오래된 자리", "obj": o,
			"desc": "동굴 가장 깊은 곳에 마을보다 오래된 돌문이 잠겨 있다.\n"
				+ "할아버지가 마지막 몇 해를 보낸 자리라고 한다.\n\n"
				+ "일곱 병의 물과 다섯 개의 유품,\n"
				+ "그리고 끝까지 채운 노트를 들고 앞에 서면\n\n"
				+ "문은 그제야, 아주 천천히 열린다.",
			"cat": "main", "ep": "메인 스토리 20", "npc": s20npc,
			"reward": "할아버지가 남긴 씨앗 한 알과 마지막 편지"})
	# 메인 스토리 2의 마지막 마디 — 조리대에서 요리를 하자
	o = kitchen_quest_objective_short()
	if o != "":
		out.append({"id": "kitchen", "title": "조리대에서 요리를 하자", "obj": o,
			"desc": "첫 수확을 마치고 잡화점에 들렀더니\n"
				+ "만수가 대뜸 이렇게 물었다.\n"
				+ "「자네 요즘 밥은 제대로 챙겨 먹고 있나?」\n\n"
				+ "오래 비어 있던 집에는 먼지가 이불처럼 쌓인다.\n"
				+ "만수는 그 밑에 분명 살림살이가 묻혀 있을 거라 한다.\n\n"
				+ "먼지를 걷어내면 첫 끼를 지을 자리가 나온다.\n"
				+ "그렇게 지은 한 그릇을 들고 그에게 돌아가자.",
			"cat": "main", "ep": "메인 스토리 2", "npc": "merchant",
			"reward": "요리 해금 + 판매하는 법 · 메인 스토리 2 완결"})
	# 서브: 용식의 집터 — 바닷길을 연 지 3일 뒤 분수대 앞에서 시작된다
	o = fisher_home_objective_short()
	if o != "":
		out.append({"id": "fisher_home", "title": "용식의 부탁 — 살 집 한 채",
			"obj": o,
			"desc": "평생 배 위에서 잠들던 사람이 뭍을 오래 바라본다.\n\n"
				+ "「떠돌이한테 『여기가 네 집이다』 하고 말해 주는 게\n"
				+ "어떤 건지, 자네는 모를 걸세.」\n\n"
				+ "지붕과 문이 있는 자리를 한 채 지어 주면\n"
				+ "용식은 그때부터 이 마을 사람이 된다.",
			"cat": "sub", "npc": "fisher",
			"reward": "수납 상자 레시피 (목재 8)"})
	# 서브: 새 이웃을 위한 빈 집터 셋 — 옛 경계를 되찾은 뒤 이장의 부탁
	o = plot3_objective_short()
	if o != "":
		out.append({"id": "plot3", "title": "이장의 부탁 — 새 이웃의 자리",
			"obj": o,
			"desc": "덤불에 잠겼던 옛 마을 땅이 다시 열렸다.\n"
				+ "이장은 그 넓어진 땅을 오래 바라보다 이렇게 말한다.\n\n"
				+ "「사람은 부른다고 오는 게 아닐세.\n"
				+ "빈자리가 먼저 있어야, 그 자리를 보고 오는 게지.」\n\n"
				+ "아직 이름도 얼굴도 모르는 누군가를 위해\n"
				+ "지붕이 설 자리를 미리 세 곳 골라 두자.\n"
				+ "언젠가 그 문 앞에서 처음 인사를 나누게 될 것이다.",
			"cat": "sub", "npc": "chief",
			"reward": "이장의 사례 %dG + 목재 %d · 석재 %d"
				% [PLOT3_MONEY, PLOT3_WOOD, PLOT3_STONE]})
	# 서브: 상인의 노점 심부름
	if merchant_errand == "doing":
		var ready := wood >= STALL_WOOD \
			and int(items.get("forage_shell", 0)) >= STALL_SHELLS
		out.append({"id": "stall", "title": "상인의 부탁 — 해변 노점",
			"obj": "다 모았다 — 만수에게 가져다주자" if ready
				else "바닷바람 좋은 자리에 노점을 세울 나무와 조개를 모으자",
			"desc": "만수가 눈여겨봐 둔, 바닷바람 좋은 자리가 있다.\n\n"
				+ "나무 몇 짐과 조개껍데기 몇 줌이면\n"
				+ "작은 노점 하나쯤은 세울 수 있다고 한다.\n\n"
				+ "장사꾼의 꿈은 언제나 「목 좋은 자리」에서 시작된다.",
			"cat": "sub", "npc": "merchant",
			"reward": "해변 노점 개장 + 하트 모양 러그"})
	o = tutorial_objective_short()
	if o != "":
		var flag := tutorial_current_flag()
		if flag in STORY2_FLAGS:
			out.append({"id": "tutorial", "title": "마을을 깨우다", "obj": o,
				"desc": "이장이 건넨 호미는 손잡이가 반들반들했다.\n"
					+ "오래 쓰던 사람의 손자국이 그대로 남은 물건.\n\n"
					+ "흙을 갈고, 씨앗을 놓고, 물을 주고 기다리는 일 —\n"
					+ "이 마을의 하루는 언제나 거기서부터 시작된다.",
				"cat": "main", "ep": "메인 스토리 2", "npc": "chief",
				"reward": _tut_reward_text(flag)})
		elif flag == "cook":
			out.append({"id": "tutorial", "title": "조리대에서 요리를 하자", "obj": o,
				"desc": "거둔 것을 손질해 불에 올리는 저녁.\n"
					+ "혼자 사는 집에서 제일 먼저 익히게 되는 일이다.\n\n"
					+ "집 안 조리대 앞에 서기만 하면 된다.\n"
					+ "(먼지가 쌓여 있으면 빗자루로 쓸어 내자)",
				"cat": "guide", "npc": "chief",
				"reward": _tut_reward_text(flag)})
		else:
			out.append({"id": "tutorial", "title": "마을 생활 안내", "obj": o,
				"desc": "이장이 알려 주는 마을살이 요령. 안 해도 되지만,\n하면 살림이 수월해진다.",
				"cat": "guide", "npc": "chief",
				"reward": _tut_reward_text(flag)})
	# 오늘의 의뢰 (게시판에서 수락한 것)
	var ql := quest_line()
	if ql != "":
		out.append({"id": "errand", "title": "오늘의 의뢰", "obj": ql,
			"desc": "마을 광장 게시판의 납품 의뢰다.",
			"cat": "daily", "npc": "",
			"reward": "%dG" % int(quest.get("reward", 0))})
	var gl := grandpa_line()
	if gl != "":
		out.append({"id": "grandpa", "title": "할아버지의 부탁",
			"obj": gl.replace("목표: ", ""),
			"desc": "연구 노트에 남은 할아버지의 흔적을 따라가자.",
			"cat": "sub", "npc": "", "reward": "연구 노트의 빈 장이 채워진다"})
	return out


# 안내 목표의 보상 안내문 ("100G" / "목재 5" 식)
func _tut_reward_text(flag: String) -> String:
	var r: Dictionary = TUTORIAL_REWARDS.get(flag, {})
	var parts := []
	if r.has("money"):
		parts.append("%dG" % int(r.money))
	if r.has("wood"):
		parts.append("목재 %d" % int(r.wood))
	if r.has("stone"):
		parts.append("석재 %d" % int(r.stone))
	var unlocked: Array = TUTORIAL_UNLOCKS.get(flag, [])
	for tid in unlocked:
		parts.append("%s 해금" % TOOL_KOR.get(tid, tid))
	return " · ".join(parts)


# 미니창 고정 — ""=자동(맨 앞 퀘스트), 아니면 quest_catalog의 id.
# 고정한 퀘스트가 끝나면(목록에서 사라지면) 자동으로 되돌아간다.
var tracked_pick := ""


# **Q창과 우측 미니창이 보는 단 하나의 목록.**
#
# 예전에는 Q창이 quest_catalog()를 한 번 더 걸러서(메인 이야기는 하나만)
# 보여 주고, 미니창은 걸러지지 않은 목록의 맨 앞을 집었다. 그래서 둘이
# 서로 다른 퀘스트를 가리키는 일이 생겼다. 이제 거르는 자리는 여기
# 한 곳뿐이고, 두 창이 같은 목록을 읽는다.
func quest_list() -> Array:
	var cat := quest_catalog()
	# 목록에 남길 메인 이야기 하나를 먼저 정한다 — 보통은 맨 앞이지만,
	# 고정한 퀘스트가 메인이면 **그쪽이 언제나 이긴다.**
	var keep_main := ""
	for q: Dictionary in cat:
		if str(q.get("cat", "sub")) != "main":
			continue
		if keep_main == "":
			keep_main = str(q.id)
		if str(q.id) == tracked_pick:
			keep_main = tracked_pick
	var out: Array = []
	for q: Dictionary in cat:
		var e: Dictionary = q.duplicate()
		if not e.has("cat"):
			e["cat"] = "sub"
		if str(e.cat) == "main" and str(e.id) != keep_main:
			continue          # 진행 중인 메인 이야기는 언제나 하나
		out.append(e)
	return out


# 지금 따라가는 퀘스트 하나 — 고정한 것이 있으면 무조건 그것이다.
# 고정한 퀘스트가 목록에서 사라지면 자동으로 맨 앞으로 돌아간다.
func tracked_quest() -> Dictionary:
	var cat := quest_list()
	if cat.is_empty():
		tracked_pick = ""
		return {}
	if tracked_pick != "":
		for q: Dictionary in cat:
			if str(q.id) == tracked_pick:
				return q
		tracked_pick = ""     # 끝난 퀘스트를 계속 붙들고 있지 않는다
	return cat[0]


# 지금 말을 걸어야 하는 퀘스트 NPC 머리 위 표시.
#   "!" 아직 대화하지 않은 대상 / "?" 납품(보고)할 수 있는 대상
func quest_npc_marks() -> Dictionary:
	var marks := {}
	# 서브 퀘스트 표시는 맨 먼저 — 메인 이야기의 ❗가 있으면 그쪽이 이긴다
	if plot3_quest == "report":
		marks["chief"] = "?"
	if story2_phase == "farm_talk":
		marks["chief"] = "!"
	if fisher_quest == "meet":
		marks["fisher"] = "!"
	if move_quest == "show":
		marks["chief"] = "!"
	if move_quest == "seedrep":
		marks["explorer"] = "?"
	if move_quest == "post":
		marks["chief"] = "!"
	match forest_quest:
		"arrive", "found":
			marks["explorer"] = "!"
		"ask":
			marks["chief"] = "!"
		"back":
			marks["chief"] = "?"
	if forest_trust == "invited":
		marks["forest_mom"] = "!"
	if story4_phase == "ask":
		marks["chief"] = "!"
	match story6_phase:
		"show_chief", "told":
			marks["chief"] = "!"
		"visit":
			marks["librarian"] = "!"
		"build":
			if village_built.has("library"):
				marks["librarian"] = "!"
	match story7_phase:
		"worry":
			marks["blacksmith"] = "!"
		"lore":
			marks["librarian"] = "!"
		"gather":
			if int(items.get("ore", 0)) >= STORY7_ORE \
					and int(items.get("gem", 0)) >= STORY7_GEM:
				marks["blacksmith"] = "!"
	match story8_phase:
		"visit":
			marks["rancher"] = "!"
		"ask":
			marks["chief"] = "!"
		"build":
			if village_built.has("ranch"):
				marks["rancher"] = "!"
	match story9_phase:
		"ask":
			marks["chief"] = "!"
		"build":
			if village_built.has("hall"):
				marks["chief"] = "!"   # 회관 접수대에서 개관식을 하자
	match story10_phase:
		"note":
			marks["librarian"] = "!"
		"survey":
			if story10_survey_done():
				marks["librarian"] = "?"   # 조사 결과를 보고하자
	# 스토리 11 — 단서를 아직 안 들려준 주민에게 ❗
	if story11_phase == "clue":
		for cnid: String in STORY11_CLUE_NPCS:
			if cnid not in story11_clues:
				marks[cnid] = "!"
	# 스토리 12 — 서하에게 기록을 보여주자 / 재료가 다 모였으면 연금술사에게
	if story12_phase == "ask":
		marks["librarian"] = "!"
	elif story12_phase == "gather" and story12_mats_ok():
		marks["alchemist"] = "?"
	# 스토리 13 — 용식의 이상한 이야기 / 상자 개봉은 연금술사에게
	match story13_phase:
		"rumor":
			marks["fisher"] = "!"
		"box":
			marks["alchemist"] = "!"
		"open":
			if story13_mats_ok():
				marks["alchemist"] = "?"
	# 스토리 14 — 회의·축제는 이장이 이끈다
	if story14_phase == "meet":
		marks["chief"] = "!"
	elif story14_phase == "prep" and fest_prep_done():
		marks["chief"] = "?"
	elif story14_phase == "fest" and day >= story14_fest_day:
		marks["chief"] = "?"
	# 스토리 15 — 온천: 이장 → 서하 → 무쇠 → 동굴 → 묘연
	match story15_phase:
		"tale":
			marks["chief"] = "!"
		"book":
			marks["librarian"] = "!"
		"tool":
			if int(items.get("rock_wedge", 0)) == 0:
				marks["blacksmith"] = "!"
		"water":
			marks["alchemist"] = "?"
	# 스토리 16·17 — 유품 이야기의 시작과 끝은 도서관·목장에서
	if story16_phase in ["record", "tale"]:
		marks["librarian"] = "!"
	if story17_phase == "cloth":
		marks["rancher"] = "!"
	elif story17_phase == "tale":
		marks["librarian"] = "!"
	# 스토리 18 — 마지막 유품. 도서관에서 열리고 도서관에서 닫힌다
	if story18_phase in ["memo", "tale"]:
		marks["librarian"] = "!"
	elif story18_phase == "clue":
		marks["librarian"] = "?"
	# 첫 수확을 마쳤다 — 만수가 밥 이야기를 꺼내려 한다
	if story2_phase == "cook" and kitchen_quest == "":
		marks["merchant"] = "!"
	# 조리대를 찾았다 · 요리를 지었다 — 만수가 기다린다
	if kitchen_quest in ["found", "deliver"]:
		marks["merchant"] = "?"
	# 용식의 집터 — 분수대 앞에서 기다릴 때와 집이 다 됐을 때 말을 걸자
	if fisher_home == "wait":
		marks["fisher"] = "!"
	elif fisher_home == "built":
		marks["fisher"] = "?"
	if merchant_errand == "doing":
		# 노점 재료를 다 모았으면 만수에게 가져다주자
		if wood >= STALL_WOOD and int(items.get("forage_shell", 0)) >= STALL_SHELLS:
			marks["merchant"] = "?"
	if mom_quest_open() and mom_quest != "":
		marks["forest_mom"] = "?"
	# 마지막 페이지를 보여줄 사람 — 서하와 이장 (메인 스토리 20)
	if story20_phase == "tell":
		for tid: String in STORY20_TELL:
			if tid not in story20_told:
				marks[tid] = "!"
	# 떠나려는 주민 — 하고 싶은 말이 있다
	if settler_leaving != "":
		marks[settler_leaving] = "!"
	return marks


# ---- 메인 스토리 5: 숲속에서 발견한 집 ----
#
# 첫 수확(스토리 2 완료) 뒤, 모험을 좋아하는 재민이 마을로 이사 온다.
# 숲을 쏘다니던 재민이 깊은 숲의 수상한 집을 발견하고, 이장도 모르는
# 그 집에는 아픈 딸을 돌보는 모녀가 조용히 살고 있었다.
# 이 이야기를 끝내면 호감도 콘텐츠(하트·선물)가 해금된다.
#   "": 아직 / arrive: 재민 등장 — 말 걸기 / settle: 정착 (다음 날 아침까지) /
#   found: 숲속 집 발견담 — 재민에게 말 걸기 /
#   ask: 이장에게 보고 (재민과 함께) /
#   go: 이장·재민과 함께 숲속의 집으로 (두 사람이 따라온다) /
#   back: 돌아오는 길 — 이장의 조언 (여기서 호감도가 열린다) / done: 완료
var forest_quest := ""
var forest_day := 0          # 재민이 정착한 날 — 다음 날 아침 발견담이 뜬다
var affinity_open := false   # 호감도 콘텐츠(하트·선물) 해금 여부

# ---- 튜토리얼 공간과 세계 ----
#
# 게임을 켜면 세계 밖의 **일회성 숲길**에서 시작한다 (main.TUTORIAL_REGION).
# 마을에 들어서는 순간 그 공간은 닫히고, 그때부터가 진짜 세계다.
var tutorial_space := true


# ---- 마을을 중심으로 하나씩 열리는 땅 ----
#
# 처음 마을에 도착하면 마을과 큰길, 그리고 바로 곁의 농장뿐이다.
# 이야기가 나아갈 때마다 둘레의 땅이 하나씩 이어진다.
#   조건: "story2"(마을을 깨우다) / "sea"(바닷길) / "forest"(숲속의 집) /
#         "story8"(목장) / "story10"(동굴) / "story12"(연금술사) / "zone"(구역 해금)
# ---- 야생 지역은 전부 열려 있다 ----
#
# 한때는 마을을 중심으로 숲·초원·습지·솔숲·벼랑길을 이야기에 따라 하나씩
# 열었다. 그런데 걸어서 갈 수 있는 곳이 이야기 진도에 묶이자 **가고 싶은 데를
# 못 가는 게임**이 됐다 — 특히 바닷가 벼랑길은 자기 자신을 잠갔다(길을 여는
# 바위가 그 벼랑길 아래에 있었다). 지금은 **세계를 처음부터 다 걸을 수 있다.**
# 「아직 이르다」는 느낌은 지형과 몬스터와 이야기가 만들지, 보이지 않는 벽이
# 만들지 않는다.
#
# (메인 스토리 4의 마을 확장 구역은 별개다 — 그건 게시판에서 재료를 들여
#  직접 여는 마을의 몸통이라 그대로 둔다: `is_tile_owned`)
const REGION_UNLOCK := {}


func region_unlocked(_id: String) -> bool:
	return true


# ---- 숲속 집의 문이 열리는 날 (메인 스토리 5 이후) ----
#
# 스토리 5에서 연화는 끝내 집 안으로 들이지 않는다 — 낯선 사람을 경계하는
# 것은 당연한 일이고, 신뢰는 시간이 쌓아 주는 것이기 때문이다.
# 꾸준히 말을 걸고 도우며 **연화의 호감도가 FOREST_TRUST_AFF 이상**이
# 되면, 처음으로 문 안으로 들어오라는 말을 듣는다. 그날 솔이를 만난다.
#   "": 아직 / invited: 마음을 열었다 — 연화에게 말 걸기(❗) /
#   done: 집 안에서 솔이를 만났다 (이때부터 솔이가 집 앞에 나온다)
const FOREST_TRUST_AFF := 5
var forest_trust := ""


# 연화가 마음을 열 만큼 친해졌는가
func forest_trust_ready() -> bool:
	return forest_quest == "done" \
		and int(affinity.get("forest_mom", 0)) >= FOREST_TRUST_AFF


# ---- 숲속 엄마(연화)의 서브 퀘스트 시스템 ----
#
# 스토리 5(숲속에서 발견한 집)를 끝내야 받을 수 있다.
# 방향: 연화가 솔이에게 줄 요리·음식·재료를 부탁하는 심부름.
#
# 세부 퀘스트는 아직 정하지 않았다 — 정해지면 MOM_QUESTS에 한 줄씩 넣는다:
#   {"id": "porridge", "name": "솔이의 죽 재료",       # 선택지에 뜨는 실제 이름
#    "item": "potato", "qty": 3,                       # 필요한 것 (작물/아이템 id)
#    "money": 300, "affinity": 5,                      # 보상 (돈·연화 호감도)
#    "ask": "요즘 솔이가 죽이 먹고 싶다네요.",           # (선택) 부탁 대사 한 줄
#    "thanks": "이걸로 푹 끓여 줘야겠어요."}             # (선택) 감사 대사 한 줄
# 표가 비어 있으면 선택지가 아예 뜨지 않는다. 앞에서부터 순서대로 하나씩 열린다.
var MOM_QUESTS: Array = []
var mom_quest := ""                # 진행 중인 퀘스트 id ("" = 없음)
var mom_quests_done: Array = []    # 끝낸 퀘스트 id들

# ---- 밤 기절 조건부 서브 퀘스트 (이장의 걱정) ----
# 밤에 몬스터에게 당해 기절하면, 다음 날 아침 이장이 직접 찾아와
# 돌 창 레시피를 준다 (상점 구매가 아니라 이 서브퀘로만 얻는다).
#   "": 아직 / pending: 간밤에 기절했다 — 아침에 이장이 온다 /
#   visit: 이장이 걸어오는 중 / done: 완료 (돌 창 레시피 획득)
var spear_quest := ""


func mom_quest_open() -> bool:
	return forest_quest == "done"


# 지금 연화가 보여 줄 퀘스트 (진행 중이면 그것, 아니면 다음 것. 없으면 {})
func mom_next_quest() -> Dictionary:
	if not mom_quest_open():
		return {}
	for q: Dictionary in MOM_QUESTS:
		if mom_quest != "":
			if str(q.id) == mom_quest:
				return q
		elif str(q.id) not in mom_quests_done:
			return q
	return {}


func forest_objective_short() -> String:
	match forest_quest:
		"arrive":
			return "낯선 사람과 대화하자."
		"found":
			return "재민과 대화하자."
		"ask":
			return "이장에게 알리자."
		"go":
			return "숲속의 집으로 가자."
		"back":
			return "이장과 대화하자."
	return ""


# 후속 이야기 — 연화가 문을 열어 주는 날
func forest_trust_objective_short() -> String:
	if forest_trust == "invited":
		return "연화와 대화하자."
	return ""


# 해변 채집 능력치 — 조개가 다시 밀려오는 간격(게임 분)과 한 번에 줍는 양.
# 기본은 10~15분에 하나. 레벨이 오르면 리젠이 빨라지고, 3레벨마다 +1개.
func shell_respawn_minutes() -> float:
	return randf_range(10.0, 15.0) / (1.0 + 0.08 * (skill_lv("beach") - 1))


func beach_pick_count() -> int:
	return 1 + int((skill_lv("beach") - 1) / 3.0)   # 4 · 7 · 10레벨에 +1


# 산호 조각·고대 조각이 밀려올 확률 (각각). 기본 0.1% — 매우 희귀하다.
# 해변 채집 레벨이 오르면 조금씩 오른다 (10레벨에 0.37%).
func beach_rare_chance() -> float:
	return 0.001 + 0.0003 * (skill_lv("beach") - 1)


func fisher_objective_short() -> String:
	match fisher_quest:
		"meet":
			return "낚시꾼과 대화하자."
		"follow":
			return "함께 바위 능선으로 가자."
		"open":
			return "길목의 큰 바위를 캐자."
	return ""


# 집: 스토리 1 완료 후 마을 서쪽 집터에 직접 짓는다 (0=집터 / 1=집 / 2=확장)
var house_lv := 1     # 할아버지의 집은 처음부터 서 있다(짓기 없음)
var has_bed := true   # 할아버지가 쓰던 낡은 침대(bed_lv 0)가 남아 있다

# ---- 제작대 (책상) ----
#
# 집에 있는 작업대. 여기서 가구를 만들면 시간이 지나 완성되고,
# 완성된 가구는 낡은 것과 저절로 바뀐다 (동물의 숲 제작대 느낌).
# 업글하면 빨라지고 여러 개를 동시에 걸 수 있다.
const DESK_NAMES := ["낡은 책상", "튼튼한 작업대", "장인의 작업대"]
const DESK_TIME := [5.0, 4.0, 3.0]       # 하나 만드는 데 걸리는 시간(초)
const DESK_SLOTS := [1, 2, 3]            # 동시에 걸 수 있는 개수
# 제작대 자신은 자기로 못 만드니 「손보기」로 즉시 바꾼다 (여기만 예외)
const DESK_UPGRADES := [
	{"cost": {"wood": 20, "stone": 10, "nail": 2}},
	{"cost": {"wood": 40, "ore": 8, "hinge": 3}},
]
# 만들 수 있는 것 — kind "bed"는 완성되는 순간 침대가 바뀐다
const DESK_RECIPES := {
	"broom": {"name": "빗자루", "cost": {"weed": 1},
		"kind": "item", "give": "broom", "locked": true, "shop": "잡화점",
		"desc": "집 안의 먼지를 쓸어 낸다 (레시피는 잡화점에서)"},
	# 울타리 — 배우는 순간 도구가 열린다 (kind "tool"). 재료는 목재 한 개이고,
	# 세울 때마다 또 한 개씩 든다. 잡화점은 **가방에 목재가 있어야** 이 레시피를
	# 꺼내 놓는다 — 나무를 베어 본 사람에게만 쓸모가 있는 물건이기 때문이다.
	"fence": {"name": "울타리", "cost": {"wood": 1},
		"kind": "tool", "tool": "fence", "locked": true, "shop": "잡화점",
		"desc": "빈틈없이 둘러싸면 목초지가 된다 — 그 안 동물은 알아서 배부르다"},
	# kind "furniture": 완성되면 집에 세간으로 들어온다 (꾸미기 F로 옮긴다)
	"flower_pot": {"name": "화분", "cost": {"weed": 5},
		"kind": "furniture", "furn": "plant", "locked": true, "shop": "잡화점",
		"desc": "집을 꾸미는 화분 — 완성되면 방에 놓인다 (레시피는 잡화점에서)"},
	# 쓰레기통 — 24시간 무인 판매함. 만들어서 원하는 곳(집 안/바깥)에 설치한다.
	"trash_bin": {"name": "쓰레기통", "cost": {"wood": 5, "forage_ring": 2},
		"kind": "item", "give": "trash_bin", "locked": true, "shop": "잡화점",
		"desc": "넣은 물건을 제값의 80%에 파는 무인 판매함 — 가방에서 꺼내 설치한다"},
	# 수납 상자 — 집 안에 놓는 작은 창고 (용식의 집터 부탁 보상으로 열린다)
	"storage_box": {"name": "수납 상자", "cost": {"wood": 8},
		"kind": "item", "give": "storage_box", "locked": true, "shop": "용식의 부탁",
		"desc": "집 안에 놓고 창고처럼 쓰는 작은 상자 — 가방이 넘칠 때 넣어 둔다"},
	# 집터 — 새 주민의 집을 지을 자리 (메인 스토리 3에서 해금, 일부러 무겁다)
	# 집터 — 양은 많지만 **초반에 구할 수 있는 것만** 쓴다.
	# (예전에는 못 4개가 들어갔는데, 못은 대장간이 서야 살 수 있어서
	#  이사 이야기가 나오는 시점에는 아예 만들 수 없었다)
	"housing_kit": {"name": "집터", "cost": {"wood": 90, "stone": 70},
		"kind": "item", "give": "housing_kit", "locked": true, "shop": "잡화점",
		"desc": "새 주민이 살 집의 터 — 지을 풀밭을 바라보고 가방에서 쓴다"},
	# 초반 무기 — kind "tool": 완성되면 도구가 해금된다 (가방에서 슬롯에 장착)
	"spear": {"name": "돌 창", "cost": {"wood": 3, "stone": 2},
		"kind": "tool", "tool": "spear", "locked": true, "shop": "이장",
		"desc": "느리지만 한 방이 묵직한 창 — 밤 몬스터를 상대한다 (레시피는 이장에게)"},
	"sword": {"name": "돌 검", "cost": {"wood": 2, "stone": 3},
		"kind": "tool", "tool": "sword", "locked": true, "shop": "훗날의 부탁",
		"desc": "빠르게 두 번 베는 검 — 화력은 창과 비슷하다 (레시피는 어느 부탁의 보상)"},
	"bed_wood": {"name": "나무 침대", "cost": {"wood": 25, "nail": 2},
		"kind": "bed", "lv": 1, "desc": "아침 기력이 가득 찬다"},
	"bed_soft": {"name": "푹신한 침대", "cost": {"wood": 30, "cloth": 5, "milk": 3},
		"kind": "bed", "lv": 2, "desc": "쓰러진 다음 날도 덜 힘들다"},
}
const BED_NAMES := ["낡은 침대", "나무 침대", "푹신한 침대"]
var desk_lv := 0
var bed_lv := 0
# 집 청소 — 조리대는 먼지와 잡동사니에 묻혀 있다. 빗자루로 세 번 쓸면
# 나타나고, 그때부터 요리를 할 수 있다 (요리 해금).
const DUST_TOTAL := 3
var dust_swept := 0
var kitchen_found := false

# ---- 메인 스토리 2의 마지막 마디: 조리대에서 요리를 하자 ----
#
# 첫 수확을 마치면 만수가 「밥은 먹고 다니나」 하고 묻는다.
# 거기서 시작해 조리대를 찾아내고, 첫 요리를 지어 만수에게 가져가면
# 그가 파는 법과 먹는 법을 알려 준다 — 그것으로 2장이 끝난다.
#   "": 아직 / broom: 빗자루 레시피 사기 / make: 잡초 모아 빗자루 만들기 /
#   sweep: 집 안 먼지 쓸기 / found: 조리대 발견 — 만수에게 알리기 /
#   jam: 받은 재료로 산딸기잼 만들기 /
#   deliver: 지은 요리를 만수에게 가져가기 / done: 끝 (판매까지 배웠다)
var kitchen_quest := ""
var kitchen_branch := ""    # (옛 세이브 호환 — 지금은 갈래가 없다)
const JAM_ID := "dish_berry_jam"     # 첫 요리 — 산딸기잼
const JAM_BERRIES := 3               # 만수가 함께 주는 산딸기


# 이 이야기가 시작될 수 있는가 — 잡화점이 서 있고, 아직 조리대가 없다
# 낚시를 할 수 있는가 — 용식과 바닷길을 열고 낚싯대를 받아야 한다
func can_fish() -> bool:
	return is_tool_unlocked("rod")


# 이 이야기가 시작될 수 있는가 —
# **첫 수확을 마친 뒤**(story2_phase == "cook") 만수에게 말을 걸었을 때만.
# 예전에는 잡화점에서 나가려 하거나 레시피를 사려 할 때 등 세 갈래로
# 불쑥 시작됐다. 지금은 시작점이 하나뿐이다.
# 만수가 밥 이야기를 꺼낼 때인가.
#
# **조건은 둘뿐이다** — 첫 수확을 마쳤고(story2_phase == "cook"),
# 아직 이 이야기를 시작하지 않았다(kitchen_quest == ""). 예전에는
# 「상점이 서 있을 것」과 「조리대를 아직 못 찾았을 것」이 더 붙어 있었는데,
# 넷 중 하나만 어긋나도 **목표는 「만수와 대화하자」인데 말을 걸어도 아무
# 일이 없는** 막다른 길이 됐다. 조리대를 이미 찾았다면 그 마디만
# 건너뛰면 될 일이지, 이야기 전체가 멈출 이유가 없다.
func kitchen_quest_ready() -> bool:
	return kitchen_quest == "" and story2_phase == "cook"


# 요리 레시피를 정상적으로 사고팔 수 있는가 (튜토리얼을 마쳐야 열린다)
func cook_shop_open() -> bool:
	return kitchen_found and kitchen_quest in ["", "done"]


func kitchen_quest_objective_short() -> String:
	match kitchen_quest:
		"broom":
			return "빗자루 레시피를 사자."
		"make":
			if recipe_items.has("broom"):
				return "빗자루 레시피를 배우자."
			if int(items.get("weed", 0)) < 1:
				return "풀숲에서 잡초를 모으자."
			return "책상에서 빗자루를 만들자."
		"sweep":
			return "집 안 먼지를 쓸어 내자 %d/%d" % [
				dust_swept, DUST_TOTAL]
		"found":
			return "만수에게 알리자."
		"jam":
			return "조리대에서 요리를 하자."
		"deliver":
			return "요리를 만수에게 가져가자."
	return ""
var desk_queue: Array = []        # [{id, left(초)}]
var desk_done_pending: Array = [] # 방금 완성된 것 — hud가 꺼내 배너를 띄운다


func desk_time() -> float:
	return DESK_TIME[desk_lv]


func desk_slots() -> int:
	return DESK_SLOTS[desk_lv]


# 목재·돌은 자원 변수에, 나머지는 items에 있다
func mat_count(k: String) -> int:
	match k:
		"wood":
			return wood
		"stone":
			return stone
		_:
			return int(items.get(k, 0))


func mats_ok(cost: Dictionary) -> bool:
	for k: String in cost:
		if mat_count(k) < int(cost[k]):
			return false
	return true


func pay_mats(cost: Dictionary) -> bool:
	if not mats_ok(cost):
		return false
	for k: String in cost:
		match k:
			"wood":
				wood -= int(cost[k])
			"stone":
				stone -= int(cost[k])
			_:
				items[k] = int(items[k]) - int(cost[k])
	return true


# 제작을 건다. 자리가 없거나 재료가 모자라면 안 건다.
func desk_start(id: String) -> bool:
	if not DESK_RECIPES.has(id) or desk_queue.size() >= desk_slots():
		return false
	var def: Dictionary = DESK_RECIPES[id]
	# 레시피를 상점에서 사기 전에는 못 만든다 (기본 컨셉 1과 같은 결)
	if bool(def.get("locked", false)) and id not in recipes_unlocked:
		return false
	# 침대는 순서대로만 — 낡은 것에서 푹신한 것으로 건너뛸 수 없다
	if str(def.kind) == "bed" and int(def.lv) != bed_lv + 1:
		return false
	if not pay_mats(def.cost):
		return false
	desk_queue.append({"id": id, "left": desk_time()})
	return true


# 시간이 흐른다 — 매 프레임 _process가 부른다 (하네스는 크게 한 번 부른다)
func desk_tick(delta: float) -> void:
	if desk_queue.is_empty():
		return
	for job: Dictionary in desk_queue:
		job.left = float(job.left) - delta
	var still: Array = []
	for job: Dictionary in desk_queue:
		if float(job.left) > 0.0:
			still.append(job)
			continue
		var def: Dictionary = DESK_RECIPES[job.id]
		if str(def.kind) == "bed":
			bed_lv = maxi(bed_lv, int(def.lv))
			has_bed = true
		elif str(def.kind) == "item":
			var give := str(def.give)
			items[give] = int(items.get(give, 0)) + 1
			discover(give)
		elif str(def.kind) == "furniture":
			# 방 가운데쯤에 들여놓는다 — 겹치지 않게 조금씩 밀고, 꾸미기(F)로 옮긴다
			furniture.append({"id": str(def.furn),
				"x": 430.0 + float(furniture.size() % 4) * 40.0,
				"y": 255.0 + float(furniture.size() / 4 % 3) * 30.0})
		elif str(def.kind) == "tool":
			# 무기·도구 — 완성되는 순간 도구가 해금된다 (가방에서 슬롯에 장착)
			var tid := str(def.tool)
			if tid not in unlocked_tools:
				unlocked_tools.append(tid)
			discover(tid)
		discover(str(job.id))
		desk_done_pending.append(str(def.name))
		things_built += 1
	desk_queue = still


func _process(delta: float) -> void:
	desk_tick(delta)


# 손보기 — 제작대 자신을 다음 단계로 (즉시)
func desk_upgrade() -> bool:
	if desk_lv >= DESK_UPGRADES.size():
		return false
	if not pay_mats(DESK_UPGRADES[desk_lv].cost):
		return false
	desk_lv += 1
	return true


# ---- 배고픔 ----

# 시간이 흐른 만큼 배가 꺼진다 (게임 분 단위 — main._process가 부른다)
func hunger_tick(game_min: float) -> void:
	if not hunger_open:
		return
	hunger = clampf(hunger - game_min * HUNGER_PER_MIN, 0.0, HUNGER_MAX)


func starving() -> bool:
	return hunger_open and hunger <= 0.0


# 굶주림으로 깎이는 체력. 집 안(안전지대)에서는 바닥이 있다 —
# 지붕 밑에서 자리를 비워 두었다고 죽지는 않는다.
func starve_tick(delta: float, indoors: bool) -> void:
	if not starving():
		return
	var limit := HUNGER_SAFE_FLOOR if indoors else 0.0
	if energy <= limit:
		return          # 이미 바닥 — 굶주림으로는 더 깎이지 않는다
	energy = maxf(limit, energy - delta * HUNGER_STARVE_DPS)


# 굶으면 걸음이 눈에 띄게 무거워진다
func hunger_speed_mult() -> float:
	return HUNGER_SLOW_MULT if starving() else 1.0


# 먹은 만큼 배가 찬다 (요리의 회복량과 같은 값을 쓴다)
func feed(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, HUNGER_MAX)


# 아침에 기력이 얼마나 차는가 — 침대가 좋을수록 잘 잔다
func bed_wake_mult(passed_out: bool) -> float:
	if passed_out:
		return [0.4, 0.5, 0.75][bed_lv]
	return [0.7, 1.0, 1.0][bed_lv]
const HOUSE_BUILD_WOOD := 20
const HOUSE_UPGRADE_WOOD := 60
const HOUSE_UPGRADE_STONE := 40
const BED_WOOD := 10


# ---- 밤 시간대 (잠을 자야 하는 자연스러운 이유) ----

func is_evening() -> bool:
	return minutes >= 19.0 * 60.0  # 19시: NPC들이 집으로 돌아간다


func is_night() -> bool:
	return minutes >= 20.0 * 60.0  # 20시: 채집 효율 저하


func is_deep_night() -> bool:
	return minutes >= 21.0 * 60.0  # 21시: 위험한 밤 몬스터 등장

# ---- 지도 탐사 (fog of war) ----
# 실제로 가 본 지역만 지도에 표시된다. 청크(8타일) 단위로 기록.
# 지도 안개 — 걸어 본 만큼만 걷힌다.
#
# 처음 지도를 열면 온 세상이 먹구름이고, 발이 닿은 자리부터 조금씩
# 드러난다. 칸을 4로 잡고 둘레 한 겹까지만 밝히므로 한 번에 12x12칸,
# 168x90짜리 맵의 1%가 채 안 된다 — 탐험할 거리가 남는다.
# (예전에는 8칸 단위 3x3 = 24x24를 한꺼번에 밝혀, 몇 발짝에 지도가 다 열렸다)
const EXPLORE_CHUNK := 4
var explored := {}  # Vector2i(청크 좌표) -> true


func mark_explored_at(t: Vector2i) -> void:
	var c := Vector2i(t.x / EXPLORE_CHUNK, t.y / EXPLORE_CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			explored[c + Vector2i(dx, dy)] = true


func is_explored_tile(x: int, y: int) -> bool:
	return explored.has(Vector2i(x / EXPLORE_CHUNK, y / EXPLORE_CHUNK))


# 메인 스토리 1 퀘스트 순서 (기준 문서: game/docs/quests.md)
# {이름, 해야 하는 일, 스토리} — Q 상세 창과 목록 모두 여기서 가져온다
const STORY1_QUESTS := [
	{"name": "숲 안으로 들어가보기",
		"task": "숲 안으로 들어가 보자.",
		"story": "할아버지가 집으로 가는 길이 힘들 거라고 했던 이유를 이제야 알 것 같다. 그래도 집으로 가기 위해서는 이 숲을 지나가야 한다."},
	{"name": "우체부 아저씨와의 만남",
		"task": "우체부와 대화하자.",
		"story": "숲 속에서 우체부 아저씨가 다가와 말을 걸었다. 그도 마을로 가는 길이라고 한다."},
	{"name": "나무도끼를 장착해보기",
		"task": "나무도끼를 장착하자.",
		"story": "숲이 너무 험하고 나무가 많아 쉽게 들어갈 수 없던 중 우체부 아저씨를 만났다. 아저씨와 함께 마을까지 가기로 했고, 안전하게 지나가려면 나무를 베어 길을 만들어야 한다. 아저씨에게 받은 나무도끼로 숲을 지나갈 준비를 해보자."},
	{"name": "나무를 베어보자",
		"task": "길을 막은 나무를 베자.",
		"story": "도끼를 장착했다. 길을 막는 나무를 베어 마을로 가는 길을 만들자."},
	{"name": "숲길을 나아가자",
		"task": "숲길을 따라 나아가자.",
		"story": "첫 나무를 베어 길이 열리기 시작했다. 아저씨와 함께 숲길을 따라 앞으로 나아가자."},
	{"name": "지도를 확인해보자",
		"task": "지도를 열어 보자.",
		"story": "숲길이 여러 갈래로 갈라졌다. 어느 길로 가야 할까? 아저씨가 알려준 대로 지도에서 우리 위치와 가 본 곳을 확인해 보자."},
	{"name": "마을로 가는 길을 열어보자",
		"task": "곡괭이로 바위를 캐자.",
		"story": "마을로 향하던 중 커다란 바위가 길을 완전히 가로막고 있었다. 아저씨가 곡괭이로 캐는 모습을 보여주며 곡괭이를 건네주었다. 배운 대로 바위를 캐서 길을 열자."},
	{"name": "마을로 이동",
		"task": "우체부와 함께 마을로 가자.",
		"story": "바위를 치워 마침내 길이 열렸다. 아저씨와 함께 숲을 빠져나가 마을로 향하자."},
	{"name": "이장에게 편지 전달",
		"task": "이장에게 가 보자.",
		"story": "드디어 마을에 도착했다. 우체부 아저씨가 이장님께 직접 편지를 전하러 간다. 함께 따라가 보자."},
	{"name": "새 보금자리",
		"task": "집에 들어가 보자.",
		"story": "이장님이 할아버지가 지내던 집을 내어 주셨다. 오랫동안 비어 있었다는 마을 서쪽의 그 집... 들어가 보자."},
]
# 단계 -> 지금 진행 중인 퀘스트 번호. home_open: 편지는 전했고, 집에 들어가면
# 메인 스토리 1이 끝난다. greet(집 안, 표에 없음)는 전부 완료로 본다.
const STORY1_PHASE_IDX := {"enter": 0, "approach": 1, "equip": 2, "chop": 3,
	"path": 4, "map": 5, "rock": 6, "travel": 7, "deliver": 8, "home_open": 9}


func story_current_quest() -> Dictionary:
	if STORY1_PHASE_IDX.has(story_phase):
		return STORY1_QUESTS[STORY1_PHASE_IDX[story_phase]]
	return {}


func story_objective_short() -> String:
	match story_phase:
		"enter":
			return "숲 안으로 들어가 보자."
		"approach":
			return "우체부와 대화하자."
		"equip":
			return "나무도끼를 장착하자."
		"chop":
			return "길을 막은 나무를 베자."
		"path":
			if story_gates_left > 0:
				return "길목의 나무를 베자 %d곳 남음" % story_gates_left
			return "갈림길까지 가 보자."
		"map":
			return "지도를 열어 보자."
		"rock":
			match story_rock_state:
				0:
					return "마을로 가 보자."
				1:
					return "곡괭이로 바위를 캐자."
				_:
					return "우체부와 대화하자."
		"travel":
			return "우체부와 함께 마을로 가자."
		"deliver":
			return "이장에게 가 보자."
		"home_open":
			return "집에 들어가 보자."
		"greet":
			return "집을 둘러보고 나가 보자."
	return ""


func player_tex(part: String) -> String:
	# 플레이어 텍스처 이름 — 고른 외형으로 구워 둔 pc_* 를 본다
	# (main.apply_appearance가 머리 스타일 + 옷 색으로 만들어 둔다)
	return "pc_" + part


# 휘두르기 도트 이름의 앞부분 (key = "down"/"up"/"side").
# 모든 머리 스타일이 같은 골격이라 주먹 자리(player.gd SWING_HAND_DOT)도 공용이다.
func swing_tex_base(key: String) -> String:
	return "pc_%s_swing" % key


# 걷기 프레임 수와 속도. 다섯 칸에서 **여섯 칸**으로 늘렸다.
#
# 걸음은 두 발짝이 한 바퀴다. 한 바퀴 안에 다리를 모으는 「통과」가 두 번,
# 벌리는 「딛기」가 두 번 있어야 하는데, 다섯 칸으로는 담을 수가 없다 —
# 통과는 위상 0도와 180도인데 다섯 등분의 눈금 간격이 72도라 180도에
# 눈금이 없다. 그래서 두 발짝 중 하나만 몸이 통통 뜨는 절뚝걸음이었다.
# 여섯이면 눈금이 60도라 둘 다 눈금에 놓인다.
#
# 초당 칸 수도 8에서 12로 올렸다. 8fps × 여섯 칸이면 한 바퀴가 0.75초,
# 이동 속도 150px/s로는 한 발짝에 3.5칸(112px)을 간다 — 발이 미끄러진다.
# 12fps면 한 발짝이 1.2칸쯤이라 다리 길이에 가깝다.
const WALK_FRAMES := 6
const WALK_FPS := 12.0


func player_side_tex(is_moving: bool, _suffix: String, t: float) -> String:
	# 옆모습. 걷는 중엔 걷기 프레임, 멈추면 숨쉬기(스케일) 모션.
	# (_suffix는 안 쓴다 — 부르는 쪽이 넘기던 옛 박자 값이다. 걷기 칸은
	#  여기서 anim_time으로 직접 고른다.)
	if not is_moving:
		return "pc_side_idle"
	return "pc_side_walk_%d" % (int(t * WALK_FPS) % WALK_FRAMES)


func player_down_tex(is_moving: bool, _suffix: String, t: float) -> String:
	# 앞모습. 걷는 중엔 걷기 프레임, 멈추면 숨쉬기(스케일) 모션.
	if not is_moving:
		return "pc_down_idle"
	return "pc_down_walk_%d" % (int(t * WALK_FPS) % WALK_FRAMES)


func player_up_tex(is_moving: bool, _suffix: String, t: float) -> String:
	# 뒷모습. 걷는 중엔 걷기 프레임, 멈추면 숨쉬기(스케일) 모션.
	if not is_moving:
		return "pc_up_idle"
	return "pc_up_walk_%d" % (int(t * WALK_FPS) % WALK_FRAMES)


# 벌목 누적 횟수 (스토리 중 15그루째에 우체부가 능력치 창을 알려준다)
var trees_chopped := 0
var things_built := 0            # 제작대에서 완성한 수 — 자유직 「목수」(S3c)의 문턱
# U키 능력치 안내 단계: 0=대기 / 1=대사 완료(U 누르기 대기) / 2=창 열어봄 / 3=완료
var u_intro_state := 0
# 숲길을 막고 선 나무 중 아직 베지 않은 그루 수 (얼마나 더 파야 하는지 표시)
var story_gates_left := 0
# 퀘스트 5 「마을로 가는 길을 열어보자」 진행 단계:
# 0=바위 발견 전 / 1=곡괭이 받음(채광 중) / 2=바위 제거(곡괭이 돌려주기 대기) / 3=완료
var story_rock_state := 0


func player_idle_tex(dirn: String) -> String:
	# 대기: 단일 서기 프레임. 숨쉬기는 스프라이트 세로 스케일로 연출한다 (player.gd)
	return "pc_%s_idle" % dirn


# 이동 속도 보정 (펫 + 바람 물약)
func pet_speed_mult() -> float:
	var m := 1.1 if active_pet == "dog" else 1.0
	return m * (1.25 if has_potion("swift") else 1.0)


# 동굴에서 받는 피해 배율 (펫 + 수호 물약)
func pet_cave_def_mult() -> float:
	var m := 0.75 if active_pet == "owl" else 1.0
	return m * (0.6 if has_potion("guard") else 1.0)


# ---- 동물 ----
const ANIMALS := {
	"chicken": {"name": "닭", "price": 800, "product": "egg"},
	"cow": {"name": "소", "price": 1500, "product": "milk"},
}
const MAX_ANIMALS := 8          # 기본 동물 상한
const BARN_MAX_ANIMALS := 16    # 축사 건설 후
const BARN_COST_MONEY := 2500
const BARN_COST_WOOD := 20
var barn_built := false


func max_animals() -> int:
	return BARN_MAX_ANIMALS if barn_built else MAX_ANIMALS

# ---- 기타 판매 아이템 (동물 생산물, 물고기) ----
const ITEMS := {
	"egg": {"name": "달걀", "sell": 25},
	"milk": {"name": "우유", "sell": 55},
	"fish_crucian": {"name": "붕어", "sell": 20},
	"fish_minnow": {"name": "피라미", "sell": 15},
	"fish_loach": {"name": "미꾸라지", "sell": 25},
	"fish_bitterling": {"name": "납자루", "sell": 20},
	"fish_carp": {"name": "잉어", "sell": 25},
	"fish_sweetfish": {"name": "은어", "sell": 50},
	"fish_trout": {"name": "산천어", "sell": 65},
	"fish_mandarin": {"name": "쏘가리", "sell": 70},
	"fish_catfish": {"name": "메기", "sell": 40},
	"fish_eel": {"name": "뱀장어", "sell": 80},
	"fish_snakehead": {"name": "가물치", "sell": 90},
	"fish_crab": {"name": "참게", "sell": 60},
	"fish_salmon": {"name": "연어", "sell": 100},
	"fish_rainbow": {"name": "무지개송어", "sell": 85},
	"fish_smelt": {"name": "빙어", "sell": 30},
	"fish_icecarp": {"name": "얼음잉어", "sell": 70},
	"fish_lenok": {"name": "열목어", "sell": 110},
	"fish_mistfish": {"name": "안개무늬", "sell": 75},
	"fish_stormjack": {"name": "폭풍전갱이", "sell": 115},
	"fish_moonfish": {"name": "달빛어", "sell": 145},
	"fish_starcarp": {"name": "별잉어", "sell": 170},
	"fish_ghost": {"name": "유령물고기", "sell": 190},
	"fish_golden": {"name": "황금잉어", "sell": 135},
	"fish_king": {"name": "무지개 왕송어", "sell": 225},
	"fish_dragon": {"name": "이무기", "sell": 360},
	"ore": {"name": "광석", "sell": 20},
	"gem": {"name": "보석", "sell": 100},
	"star_shard": {"name": "별빛 조각", "sell": 135},
	# 동굴 표본 (메인 스토리 10) — 조사가 시작돼야 동굴에 모습을 드러낸다
	"crystal": {"name": "수정", "sell": 70},
	"cave_moss": {"name": "동굴 이끼", "sell": 20},
	"glow_shroom": {"name": "발광 버섯", "sell": 55},
	# 낡은 작은 상자 (메인 스토리 13) — 바다가 돌려준 것. 팔 수 없다
	"old_box": {"name": "낡은 작은 상자", "sell": 0},
	# 온천 복구 (메인 스토리 15) — 수맥을 뚫는 쐐기와 솟아난 물의 표본
	"rock_wedge": {"name": "착암 쐐기", "sell": 0},
	"spring_water": {"name": "샘물 표본", "sell": 0},
	"tax_receipt": {"name": "납세 영수증", "sell": 0},   # 팔 수 없다(sell 0 → 판매 목록 제외). 냈다는 증거
	"bouquet": {"name": "꽃다발", "sell": 0},
	# 부품 — 제작대에서 가구를 만들 때 쓴다. 못·천·밧줄은 잡화점, 경첩은 대장간
	"nail": {"name": "못", "sell": 5},
	"cloth": {"name": "천", "sell": 20},
	"rope": {"name": "밧줄", "sell": 10},
	"hinge": {"name": "경첩", "sell": 50},
	"wedding_ring": {"name": "청혼 반지", "sell": 0},
	"dish_baked_potato": {"name": "구운 감자", "sell": 30},
	"dish_soup": {"name": "야채 수프", "sell": 50},
	"dish_jam": {"name": "딸기잼", "sell": 70},
	"dish_cornbread": {"name": "옥수수빵", "sell": 60},
	# 초반 음식 사슬 — 산딸기잼 → 밀가루 → 빵 → 산딸기잼 토스트
	"dish_berry_jam": {"name": "산딸기잼", "sell": 25},
	"flour": {"name": "밀가루", "sell": 10},
	"dish_bread": {"name": "빵", "sell": 30},
	"dish_berry_toast": {"name": "산딸기잼 토스트", "sell": 70},
	"dish_grilled_fish": {"name": "생선구이", "sell": 40},
	"dish_stew": {"name": "매운탕", "sell": 90},
	"dish_pie": {"name": "호박파이", "sell": 125},
	"dish_salad": {"name": "치즈 샐러드", "sell": 75},
	"dish_punch": {"name": "수박화채", "sell": 110},
	"dish_eggplant": {"name": "가지볶음", "sell": 55},
	"dish_pickle": {"name": "무김치", "sell": 65},
	"dish_ratatouille": {"name": "야채볶음", "sell": 115},
	"dish_pumpkin_soup": {"name": "호박죽", "sell": 105},
	"dish_corn_salad": {"name": "옥수수 샐러드", "sell": 95},
	"dish_sweet_potato": {"name": "군고구마", "sell": 70},
	"dish_bean_rice": {"name": "콩밥", "sell": 90},
	"dish_rice_cake": {"name": "인절미", "sell": 130},
	"dish_melon_ice": {"name": "참외 빙수", "sell": 120},
	"dish_onion_soup": {"name": "양파 수프", "sell": 85},
	"dish_garlic_bread": {"name": "마늘빵", "sell": 70},
	"dish_spinach_saute": {"name": "시금치 볶음", "sell": 70},
	"dish_sashimi": {"name": "회", "sell": 135},
	"dish_eel_rice": {"name": "장어덮밥", "sell": 190},
	"dish_crab_soup": {"name": "게탕", "sell": 155},
	"dish_salmon_steak": {"name": "연어 스테이크", "sell": 205},
	"dish_smelt_fry": {"name": "빙어 튀김", "sell": 110},
	"dish_fish_soup": {"name": "생선 맑은국", "sell": 80},
	"dish_golden_roast": {"name": "황금잉어 구이", "sell": 315},
	"dish_moon_tea": {"name": "달빛차", "sell": 290},
	"dish_coral_tea": {"name": "산호빛 차", "sell": 250},
	"dish_feast": {"name": "한상차림", "sell": 495},
	# 컬렉션 보상으로 열리는 요리 레시피
	"butter": {"name": "버터", "sell": 80},
	"dish_fried_egg": {"name": "계란후라이", "sell": 40},
	"dish_egg_roll": {"name": "계란말이", "sell": 90},
	"dish_omurice": {"name": "오므라이스", "sell": 170},
	"dish_butter_corn": {"name": "버터옥수수", "sell": 115},
	# 채집물/곤충
	"forage_berry": {"name": "산딸기", "sell": 20},
	# 엔딩 유품·물약 — 팔 수 없다
	"water_life": {"name": "생명의 물", "sell": 0},
	"settle_letter": {"name": "이사 신청 편지", "sell": 0},
	"farewell_letter": {"name": "짧은 작별 편지", "sell": 0},
	"relic_hat": {"name": "할머니의 모자", "sell": 0},
	"relic_watch": {"name": "할머니의 시계", "sell": 0},
	"relic_bracelet": {"name": "할머니의 팔찌", "sell": 0},
	"relic_ring": {"name": "할머니의 반지", "sell": 0},
	"relic_necklace": {"name": "할머니의 목걸이", "sell": 0},
	"grandpa_seed": {"name": "할아버지의 씨앗", "sell": 0},
	"weed": {"name": "잡초", "sell": 5},
	"broom": {"name": "빗자루", "sell": 0},
	# 해변 채집물 — 바다를 열면 아침마다 모래밭에 밀려온다
	"forage_shell": {"name": "조개", "sell": 15},
	"forage_trash": {"name": "젖은 비닐봉지", "sell": 5},
	"forage_glass": {"name": "유리 조각", "sell": 15},
	"forage_ring": {"name": "금속 고리", "sell": 15},
	"forage_relic": {"name": "고대 조각", "sell": 215},
	"bait": {"name": "미끼", "sell": 5},
	"housing_kit": {"name": "집터", "sell": 0},
	"move_letter": {"name": "이주 희망 편지", "sell": 0},
	# 메인 스토리 6의 핵심 물건 — 팔 수 없고, 완결 후 도서관에 보관된다
	"old_book": {"name": "오래된 책", "sell": 0},
	"trash_bin": {"name": "쓰레기통", "sell": 0},
	"storage_box": {"name": "수납 상자", "sell": 0},
	# 초반 무기 (도구라 개수는 없지만, 도감·컬렉션 표시용 이름이 필요하다)
	"spear": {"name": "돌 창", "sell": 0},
	"sword": {"name": "돌 검", "sell": 0},
	"arrow": {"name": "화살", "sell": 5},
	"forage_coral": {"name": "산호 조각", "sell": 115},
	"forage_herb": {"name": "약초", "sell": 25},
	# 산자락 풀밭에 피는 노란 꽃 — 씨앗이 바람에 날린다
	"forage_dandelion": {"name": "민들레", "sell": 20},
	"bug_butterfly": {"name": "나비", "sell": 15},
	"bug_dragonfly": {"name": "잠자리", "sell": 20},
	"bug_firefly": {"name": "반딧불이", "sell": 40},
	# 전설 재료 (판매 불가, 최후의 연금술 재료)
	"gold_crop": {"name": "달빛 작물", "sell": 0, "legend": true},
	"world_branch": {"name": "세계수 가지", "sell": 0, "legend": true},
	"star_ore": {"name": "별빛 광석", "sell": 0, "legend": true},
	"ghost_essence": {"name": "유령의 정수", "sell": 0, "legend": true},
	"golden_egg": {"name": "황금 달걀", "sell": 0, "legend": true},
	"memory_piece": {"name": "할아버지의 기억 조각", "sell": 0, "legend": true},
	# 연금술 결과물 (조합대에서 만든다)
	"potion_energy": {"name": "원기 물약", "sell": 80},
	"potion_luck": {"name": "행운의 물", "sell": 100},
	"potion_swift": {"name": "바람 물약", "sell": 90},
	"potion_ember": {"name": "불꽃 물약", "sell": 110},
	"potion_grow": {"name": "성장 물약", "sell": 115},
	"potion_guard": {"name": "수호 물약", "sell": 115},
	"potion_moon": {"name": "달빛의 물", "sell": 180},
	"sludge": {"name": "탁한 앙금", "sell": 5},
}
const FISH_IDS := ["fish_crucian", "fish_minnow", "fish_loach", "fish_bitterling",
	"fish_carp", "fish_sweetfish", "fish_trout", "fish_mandarin", "fish_catfish",
	"fish_eel", "fish_snakehead", "fish_crab", "fish_salmon", "fish_rainbow",
	"fish_smelt", "fish_icecarp", "fish_lenok", "fish_mistfish", "fish_stormjack",
	"fish_moonfish", "fish_starcarp", "fish_ghost", "fish_golden", "fish_king", "fish_dragon"]
const ITEM_IDS := ["tax_receipt", "egg", "milk", "fish_crucian", "fish_minnow", "fish_loach",
	"fish_bitterling", "fish_carp", "fish_sweetfish", "fish_trout", "fish_mandarin",
	"fish_catfish", "fish_eel", "fish_snakehead", "fish_crab", "fish_salmon",
	"fish_rainbow", "fish_smelt", "fish_icecarp", "fish_lenok", "fish_mistfish",
	"fish_stormjack", "fish_moonfish", "fish_starcarp", "fish_ghost", "fish_golden",
	"fish_king", "fish_dragon",
	"ore", "gem", "star_shard", "crystal", "cave_moss", "glow_shroom",
	"old_box", "rock_wedge", "spring_water", "bouquet", "wedding_ring",
	"nail", "cloth", "rope", "hinge", "dish_baked_potato", "dish_soup", "dish_jam", "dish_cornbread",
	"dish_berry_jam", "flour", "dish_bread", "dish_berry_toast",
	"dish_grilled_fish", "dish_stew", "dish_pie", "dish_salad", "dish_punch", "dish_eggplant",
	"dish_pickle", "dish_ratatouille", "dish_pumpkin_soup", "dish_corn_salad",
	"dish_sweet_potato", "dish_bean_rice", "dish_rice_cake", "dish_melon_ice",
	"dish_onion_soup", "dish_garlic_bread", "dish_spinach_saute", "dish_sashimi",
	"dish_eel_rice", "dish_crab_soup", "dish_salmon_steak", "dish_smelt_fry",
	"dish_fish_soup", "dish_golden_roast", "dish_moon_tea", "dish_feast",
	"butter", "dish_fried_egg", "dish_egg_roll", "dish_omurice", "dish_butter_corn",
	"water_life", "relic_hat", "relic_watch",
	"relic_bracelet", "relic_ring", "relic_necklace", "grandpa_seed",
	"settle_letter", "farewell_letter",
	"forage_berry", "forage_herb", "forage_dandelion", "weed", "broom",
	"forage_shell", "forage_coral",
	"forage_trash", "forage_glass", "forage_ring", "forage_relic", "bait",
	"housing_kit", "move_letter", "old_book", "trash_bin", "storage_box",
	"arrow", "dish_coral_tea",
	"bug_butterfly", "bug_dragonfly", "bug_firefly",
	"gold_crop", "world_branch", "star_ore", "ghost_essence", "golden_egg", "memory_piece",
	"potion_energy", "potion_luck", "potion_swift", "potion_ember", "potion_grow",
	"potion_guard", "potion_moon", "sludge"]

# 채집물/곤충 도감 (팔아도 기록은 남는다)
# 초록 풀숲(잡초·약초 자리)을 뽑았을 때 실제로 나오는 것 —
# 기본은 잡초, 아주 드물게(1%) 약초가 섞여 나온다
func weed_drop_id() -> String:
	return "forage_herb" if randf() < 0.01 else "weed"


const FORAGE_IDS := ["forage_berry", "forage_herb", "forage_dandelion", "weed",
	"forage_shell", "forage_coral", "forage_trash", "forage_glass",
	"forage_ring", "forage_relic"]
	# 잡초는 화분 재료 · 조개/비닐봉지/유리/금속 고리는 해변(바다 해금 후)
	# 산호 조각·고대 조각은 해변의 매우 희귀한 채집물 (숨겨진 콘텐츠와 연결)
const BUG_IDS := ["bug_butterfly", "bug_dragonfly", "bug_firefly"]
# 곤충 출현 조건
const BUGS := {
	"bug_butterfly": {"seasons": [SPRING, SUMMER], "night": false},
	"bug_dragonfly": {"seasons": [SUMMER, FALL], "night": false},
	"bug_firefly": {"seasons": [SUMMER], "night": true},
}
var forage_caught := {}  # id -> 누적 획득 수

# ---- 발견 기록 ----
#
# 「무엇을 언제 처음 얻었는가」. 도감의 물음표를 여는 열쇠이고,
# 상점이 무엇을 진열할지도 여기서 갈린다 (겪지 않은 물건은 안 판다).
# 값은 처음 얻은 날(day). 1일에 얻은 것과 「아직 못 얻음」을 구별해야 해서
# 있는지 없는지(has)로 보고, 날짜는 보여 줄 때만 쓴다.
var discovered := {}


# 처음이면 true를 돌려준다 (연출을 띄울지 부르는 쪽이 정한다)
func discover(id: String) -> bool:
	if id == "" or discovered.has(id):
		return false
	discovered[id] = day
	_check_collections()
	_check_recipe_unlocks()
	return true


# ---- 컬렉션 ----
#
# 묶음을 다 모으면 보상이 열린다 (메이플 몬스터컬렉션식).
# 따로 지정해 주는 컬렉션만 이 표에 한 줄씩 등록한다.
#   형식: id/name/reward(레시피 id 또는 "")/ids
#   perk  "" 아니면 완성 시 영구 버프 — "speed"는 이동 속도 소폭 증가
#   gate  "" 아니면 이 이야기가 열려야 노트에 나타난다 ("story10" 등)
const COLLECTIONS := [
	{"id": "col_food_starter", "name": "초반 음식", "reward": "",
		"perk": "speed", "perk_text": "이동 속도 소폭 증가 (영구)",
		"ids": ["dish_berry_jam", "flour", "dish_bread", "dish_berry_toast"]},
	# 동굴 컬렉션 (메인 스토리 10) — 채우면 채광·탐험에 실질적인 영구 보상.
	# 단순 진행률이 아니라 「모으니 몸이 달라진다」를 처음 강하게 체감시킨다.
	{"id": "col_cave_mineral", "name": "동굴의 광물", "reward": "",
		"perk": "mining", "perk_text": "곡괭이 기력 소모 -25% · 동굴 광석 +1 (영구)",
		"gate": "story10",
		"ids": ["ore", "gem", "star_shard", "crystal"]},
	{"id": "col_cave_life", "name": "동굴의 생명", "reward": "",
		"perk": "cave_speed", "perk_text": "동굴 이동 속도 +10% (영구)",
		"gate": "story10",
		"ids": ["cave_moss", "glow_shroom", "slime", "bat", "ghost"]},
]

# 「초반 음식」 완성 보상 — 걸음이 영구히 조금 빨라진다
const FOOD_COL_SPEED := 1.05
# 동굴 컬렉션 완성 보상 — 채광·탐험이 몸에 밴다 (할아버지의 요령)
const CAVE_COL_STAMINA := 0.75    # 곡괭이 기력 소모 배수
const CAVE_COL_SPEED := 1.1       # 동굴 이동 속도 배수


func perk_speed_mult() -> float:
	return FOOD_COL_SPEED if "col_food_starter" in collections_done else 1.0


# 「동굴의 광물」 — 곡괭이질이 가벼워지고, 동굴 광석이 하나 더 나온다
func perk_pick_stamina_mult() -> float:
	return CAVE_COL_STAMINA if "col_cave_mineral" in collections_done else 1.0


func perk_cave_ore_bonus() -> int:
	return 1 if "col_cave_mineral" in collections_done else 0


# 「동굴의 생명」 — 동굴 지리가 눈에 익어 발걸음이 빨라진다
func perk_cave_speed_mult() -> float:
	return CAVE_COL_SPEED if "col_cave_life" in collections_done else 1.0


# 이야기로 잠긴 컬렉션은 노트에도 없고, 완성 판정도 하지 않는다
func collection_open(col: Dictionary) -> bool:
	if str(col.get("gate", "")) == "story10":
		return story10_open()
	return true
# ---- 레시피 아이템 ----
#
# 사거나 받은 레시피는 곧바로 배워지지 않는다 — 가방의 「제작·배치」
# 칸에 두루마리(아이템)로 들어오고, 클릭해 「배우기」를 눌러야 습득된다.
var recipe_items := {}   # recipe id -> 보유 개수


func give_recipe(rid: String) -> void:
	recipe_items[rid] = int(recipe_items.get(rid, 0)) + 1


func recipe_display_name(rid: String) -> String:
	if ITEMS.has(rid):
		return str(ITEMS[rid].name)
	if DESK_RECIPES.has(rid):
		return str(DESK_RECIPES[rid].name)
	if TOOL_KOR.has(rid):
		return str(TOOL_KOR[rid])
	return rid


# 두루마리를 읽어 레시피를 익힌다 — 이때부터 조리대/제작대에 칸이 생긴다
func learn_recipe(rid: String) -> bool:
	if int(recipe_items.get(rid, 0)) <= 0:
		return false
	recipe_items[rid] = int(recipe_items[rid]) - 1
	if int(recipe_items[rid]) <= 0:
		recipe_items.erase(rid)
	if rid not in recipes_unlocked:
		recipes_unlocked.append(rid)
	# 도구 레시피(스프링클러 등)는 배우는 순간 도구 자체가 열린다
	if rid in ALL_TOOLS and not unlocked_tools.has(rid):
		unlocked_tools.append(rid)
	return true


var recipes_unlocked: Array = []
var collections_done: Array = []
# 방금 열린 것 — hud가 꺼내 배너를 띄운다 (여기서는 UI를 못 부른다)
var collection_pending: Array = []
# 방금 떠오른 기본 요리 레시피 — hud가 꺼내 토스트를 띄운다
var recipe_pending: Array = []


# 이 묶음에서 몇 개를 모았나 (몬스터는 처치 기록을 본다)
func collection_have(col: Dictionary) -> int:
	var n := 0
	for id: String in col.ids:
		if discovered.has(id) or int(mob_kills.get(id, 0)) > 0:
			n += 1
	return n


func _check_collections() -> void:
	for col: Dictionary in COLLECTIONS:
		if col.id in collections_done or not collection_open(col):
			continue
		if collection_have(col) < (col.ids as Array).size():
			continue
		collections_done.append(col.id)
		# 보상이 없는 컬렉션(무기 도감 등)은 완성 배너만 띄운다
		if str(col.reward) != "" and not (col.reward in recipes_unlocked):
			recipes_unlocked.append(col.reward)
		collection_pending.append(col)


func date_text(d: int) -> String:
	return "%d년 %s %d일" % [(d - 1) / (DAYS_PER_SEASON * 4) + 1,
		SEASON_NAMES[season_of_day(d)], (d - 1) % DAYS_PER_SEASON + 1]


func discovered_on(id: String) -> String:
	if not discovered.has(id):
		return ""
	return date_text(int(discovered[id]))

# 최후의 연금술에 필요한 전설 재료 7종 (콘텐츠마다 하나씩)
# [아이템 id, 어느 콘텐츠에서, 힌트]
const LEGENDS := [
	["gold_crop", "농사", "달 밝은 날, 정성껏 키운 작물에서 아주 드물게..."],
	["fish_golden", "낚시", "물가의 전설. 용식도 두 번밖에 못 봤다는 황금잉어."],
	["world_branch", "탐험", "깊은 숲 '세계수 동굴' 3층의 수호자가 지키고 있다."],
	["star_ore", "채광", "동굴 깊은 곳(5층+)의 보상 상자에서 별처럼 빛나는 광석이."],
	["ghost_essence", "전투", "유령은 아주 드물게 정수를 남긴다."],
	["golden_egg", "목장", "사랑받은 닭은 아주 가끔 황금빛 알을 낳는다."],
	["memory_piece", "교류", "마을 사람과 마음이 통하면(호감도 100) 건네받게 될 것."],
]

# ---- 연금술 (조합대) ----
#
# 요리는 「정해진 레시피를 보고 만드는」 것이고, 연금술은 그 반대다.
# 재료마다 다섯 속성(빛/물/불/흙/생명)이 숨어 있고, 조합대에 **세 가지**를
# 올려 돌리면 속성 합계로 결과가 정해진다. 조건에 맞는 조합법이 있으면
# 물약이 나오면서 그 조합법을 **알아낸다**. 아니면 탁한 앙금만 남는다.
#
# 조합법을 손에 넣는 길은 두 가지다:
#   1) 직접 실험해서 맞히기
#   2) 나무·바위·몬스터에서 낡은 조합법이 드물게 나온다 (ALCHEMY_DROP)
#
# 새 물약을 넣을 때는 FORMULAS에 한 줄 + ITEMS에 한 줄이면 된다.
const ELEMENTS := ["light", "water", "fire", "earth", "life"]
const ELEMENT_NAMES := {
	"light": "빛", "water": "물", "fire": "불", "earth": "흙", "life": "생명",
}

# 조합대에 올릴 수 있는 재료와 그 속성 (없는 속성은 0)
# 작물은 CROPS의 id, 그 밖은 ITEMS의 id를 그대로 쓴다.
const REAGENTS := {
	# 작물
	"potato": {"earth": 2},
	"carrot": {"earth": 1, "life": 1},
	"strawberry": {"life": 2, "water": 1},
	"tomato": {"fire": 2, "life": 1},
	"wheat": {"earth": 1, "light": 1},
	"corn": {"light": 1, "earth": 1},
	"watermelon": {"water": 3},
	"pumpkin": {"earth": 2, "fire": 1},
	"eggplant": {"earth": 1, "water": 1},
	"cabbage": {"life": 2},
	"winter_radish": {"earth": 2, "water": 1},
	"spinach": {"life": 1, "water": 1},
	"onion": {"earth": 1, "fire": 1},
	"pea": {"life": 2, "earth": 1},
	"pepper": {"fire": 3},
	"melon": {"water": 2, "life": 1},
	"garlic": {"fire": 2, "earth": 1},
	"sweet_potato": {"earth": 3},
	"bean": {"life": 2, "earth": 1},
	"rice": {"life": 3, "water": 1},
	"leek": {"life": 1, "earth": 2},
	"beet": {"earth": 2, "fire": 1},
	"snow_cabbage": {"life": 3, "water": 2},
	"herb_leaf": {"life": 2, "light": 1},
	# 축산물 · 물고기
	"egg": {"life": 2},
	"milk": {"life": 1, "water": 1},
	"fish_crucian": {"water": 2},
	"fish_minnow": {"water": 1},
	"fish_loach": {"water": 2, "earth": 1},
	"fish_bitterling": {"water": 1, "life": 1},
	"fish_carp": {"water": 2, "life": 1},
	"fish_sweetfish": {"water": 2, "light": 1},
	"fish_trout": {"water": 2, "life": 2},
	"fish_mandarin": {"water": 2, "fire": 1},
	"fish_catfish": {"water": 3, "earth": 1},
	"fish_eel": {"water": 3, "life": 1},
	"fish_snakehead": {"water": 3, "earth": 2},
	"fish_crab": {"water": 1, "earth": 3},
	"fish_salmon": {"water": 3, "life": 2},
	"fish_rainbow": {"water": 2, "light": 2},
	"fish_smelt": {"water": 2, "earth": 1},
	"fish_icecarp": {"water": 3, "earth": 1},
	"fish_lenok": {"water": 3, "life": 1, "earth": 1},
	"fish_mistfish": {"water": 2, "light": 1, "earth": 1},
	"fish_stormjack": {"water": 3, "fire": 2},
	"fish_moonfish": {"water": 2, "light": 3},
	"fish_starcarp": {"water": 2, "light": 4},
	"fish_ghost": {"water": 2, "light": 2, "life": 2},
	"fish_king": {"water": 4, "light": 2, "life": 2},
	"fish_dragon": {"water": 4, "fire": 2, "light": 2},
	# 광물
	"ore": {"earth": 2, "fire": 2},
	"gem": {"light": 2, "fire": 1},
	"star_shard": {"light": 3},
	# 채집물 · 곤충
	"forage_berry": {"life": 1, "water": 1},
	"forage_herb": {"life": 2, "earth": 1},
	"forage_dandelion": {"life": 1, "light": 1},
	"forage_shell": {"water": 2},
	"forage_coral": {"water": 2, "life": 1},
	"bug_butterfly": {"light": 1, "life": 1},
	"bug_dragonfly": {"light": 1, "water": 1},
	"bug_firefly": {"light": 2, "life": 1},
}

# 조합대에 올리는 재료 수 (고정)
const ALCHEMY_SLOTS := 3

# 조합법. need = 속성 합계가 이 값 **이상**이어야 한다.
# 여러 조합법이 동시에 맞으면 **까다로운 쪽(need 합계가 큰 쪽)** 이 이긴다.
# effect: drink(마시기)로 나타나는 효과. today = 그날 밤까지 이어지는 약효.
const FORMULAS := {
	"potion_energy": {
		"name": "원기 물약", "need": {"life": 4},
		"effect": "체력을 크게 회복한다 (+60)",
		"note": "생명이 진하게 모이면 몸이 다시 움직인다.",
	},
	"potion_luck": {
		"name": "행운의 물", "need": {"light": 3, "life": 2}, "today": "luck",
		"effect": "오늘 하루 채집·채광 부산물이 더 나온다",
		"note": "빛과 생명을 섞으면 손끝에 운이 붙는다.",
	},
	"potion_swift": {
		"name": "바람 물약", "need": {"light": 2, "water": 3}, "today": "swift",
		"effect": "오늘 하루 이동 속도 +25%",
		"note": "물이 빛을 타고 흐르면 발이 가벼워진다.",
	},
	"potion_ember": {
		"name": "불꽃 물약", "need": {"fire": 4, "earth": 2}, "today": "ember",
		"effect": "오늘 하루 전투 공격력 +3",
		"note": "땅속의 불을 그러모으면 팔에 힘이 실린다.",
	},
	"potion_guard": {
		"name": "수호 물약", "need": {"earth": 5, "fire": 2}, "today": "guard",
		"effect": "오늘 하루 동굴에서 받는 피해 -40%",
		"note": "굳은 땅은 무엇도 뚫지 못한다.",
	},
	"potion_grow": {
		"name": "성장 물약", "need": {"life": 3, "water": 3, "earth": 2}, "today": "grow",
		"effect": "오늘 하루 작물이 20% 빨리 자란다",
		"note": "생명·물·흙. 밭에 필요한 것은 결국 이 셋뿐이다.",
	},
	"potion_moon": {
		"name": "달빛의 물", "need": {"light": 6, "water": 2}, "today": "luck",
		"effect": "밭 전체에 물을 주고, 오늘 하루 행운이 붙는다",
		"note": "달빛을 병에 담을 수 있다면. 별빛 조각이 필요할 것이다.",
	},
}
const FORMULA_IDS := ["potion_energy", "potion_luck", "potion_swift", "potion_ember",
	"potion_guard", "potion_grow", "potion_moon"]
const ALCHEMY_FAIL := "sludge"
const POTION_ENERGY_HEAL := 60.0

# 낡은 조합법이 나올 확률 (아직 모르는 것이 남아 있을 때만).
# 아주 드물게 나오는 것이라야 주웠을 때 기쁘다 — 초반 도구로는 거의 안 나오고,
# 잘 벼린 도구를 들어도 눈에 띄게 잦아지지는 않는다 (alchemy_drop_chance).
const ALCHEMY_DROP := {"tree": 0.004, "rock": 0.004, "bigrock": 0.015, "mob": 0.006}
# 어느 도구의 등급을 보는가 (몬스터는 도구와 무관하다)
const ALCHEMY_DROP_TOOL := {"tree": "axe", "rock": "pickaxe", "bigrock": "pickaxe"}


# 실제 확률 — 도구 등급 1단계면 0.6배, 최고 등급이라야 1.2배쯤.
# 좋은 도구를 든다고 「조합법 캐기」가 되어 버리지 않게 폭을 좁게 잡았다.
func alchemy_drop_chance(source: String) -> float:
	var base := float(ALCHEMY_DROP.get(source, 0.0))
	if not ALCHEMY_DROP_TOOL.has(source):
		return base
	var lv: int = int(tool_level.get(str(ALCHEMY_DROP_TOOL[source]), 1))
	return base * (0.4 + 0.2 * float(lv))

var alchemy_known: Array = []   # 알아낸 조합법 id
var alchemy_brews := {}         # 조합법 id -> 만든 횟수
var alchemy_fails := 0          # 실패해서 앙금만 남은 횟수
var potion_today := {}          # 오늘 걸린 약효 (key -> true, 자고 나면 사라진다)


func reagent_elements(id: String) -> Dictionary:
	return REAGENTS.get(id, {})


# 조합대에 올린 재료들의 속성 합계
func mix_elements(ids: Array) -> Dictionary:
	var sum := {}
	for e in ELEMENTS:
		sum[e] = 0
	for id: String in ids:
		var el: Dictionary = reagent_elements(id)
		for e: String in el:
			sum[e] = int(sum[e]) + int(el[e])
	return sum


func _need_total(id: String) -> int:
	var t := 0
	for e: String in FORMULAS[id].need:
		t += int(FORMULAS[id].need[e])
	return t


# 이 속성 합계로 만들어지는 조합법 ("" = 실패).
# 조건을 만족하는 것이 여럿이면 가장 까다로운 쪽이 나온다.
func match_formula(ids: Array) -> String:
	var sum := mix_elements(ids)
	var best := ""
	var best_total := -1
	for fid: String in FORMULA_IDS:
		var ok := true
		for e: String in FORMULAS[fid].need:
			if int(sum.get(e, 0)) < int(FORMULAS[fid].need[e]):
				ok = false
				break
		if not ok:
			continue
		var t := _need_total(fid)
		if t > best_total:
			best_total = t
			best = fid
	return best


func knows_formula(id: String) -> bool:
	return alchemy_known.has(id)


func learn_formula(id: String) -> bool:
	if not FORMULAS.has(id) or alchemy_known.has(id):
		return false
	alchemy_known.append(id)
	return true


func unknown_formulas() -> Array:
	var out: Array = []
	for fid: String in FORMULA_IDS:
		if not alchemy_known.has(fid):
			out.append(fid)
	return out


# 조합법에 필요한 속성을 사람이 읽는 글로
# 실패했을 때 무엇이 모자랐는지만 알려준다.
# 어떤 조합법에 가까웠는지는 말하지 않는다 — 알아내는 재미가 사라지므로,
# 「가장 적게 모자랐던 배합」의 부족분만 뽑아 준다.
func brew_hint(ids: Array) -> String:
	var sum := mix_elements(ids)
	var best := 999
	var best_parts: Array[String] = []
	for fid: String in FORMULA_IDS:
		var lack_total := 0
		var parts: Array[String] = []
		for e: String in FORMULAS[fid].need:
			var lack := int(FORMULAS[fid].need[e]) - int(sum.get(e, 0))
			if lack > 0:
				lack_total += lack
				parts.append("%s %d" % [ELEMENT_NAMES[e], lack])
		if lack_total > 0 and lack_total < best:
			best = lack_total
			best_parts = parts
	if best_parts.is_empty():
		return "속성은 넘쳤는데 어울리지 않았다."
	return "가장 가까웠던 배합에서 " + " · ".join(best_parts) + " 모자랐다."


func formula_need_text(id: String) -> String:
	var parts: Array[String] = []
	for e: String in FORMULAS[id].need:
		parts.append("%s %d+" % [ELEMENT_NAMES[e], int(FORMULAS[id].need[e])])
	return " · ".join(parts)


# ---- 약효 (오늘 하루) ----

func has_potion(key: String) -> bool:
	return bool(potion_today.get(key, false))


func potion_text() -> String:
	var parts: Array[String] = []
	for fid: String in FORMULA_IDS:
		var key: String = str(FORMULAS[fid].get("today", ""))
		if key != "" and has_potion(key):
			parts.append(str(FORMULAS[fid].name))
	return " · ".join(parts)


# ---- 광산 깊이 ----
#
# 예전에는 나가면 무조건 1층부터 다시였다. 이제 최고 도달 층을 기록해 두고,
# 5층마다의 「승강기 층」에서 다시 시작할 수 있다.
# (승강기가 없으면 깊은 층에서만 나오는 재료를 모으는 일이 사실상 불가능하다)
const MINE_ELEVATOR_STEP := 5
var mine_deepest := 1


# 지금 고를 수 있는 시작 층 목록 (1층 + 5의 배수 층)
func mine_floors() -> Array:
	var out: Array = [1]
	var f := MINE_ELEVATOR_STEP
	while f <= mine_deepest:
		out.append(f)
		f += MINE_ELEVATOR_STEP
	return out


func mine_reach(f: int) -> void:
	mine_deepest = maxi(mine_deepest, f)


# ---- 연구소: 씨앗 개량 ----
# 단계를 올릴수록 모든 작물이 조금씩 빨리 자라고 조금씩 비싸게 팔린다.
# (작물마다 따로 관리하면 표가 커지므로 마을 전체에 걸리는 한 줄짜리 강화로 둔다)
const BREED_MAX := 5
const BREED_COST := [1500, 3000, 5000, 8000, 12000]   # 단계별 연구비
const BREED_ORE := [0, 3, 6, 10, 15]                  # 단계별 광석
var breed_level := 0
var greenhouse_built := false

# ---- 탈 것 (말) ----
# 목장 상회에서 산다. 타면 빨라지고, 도구는 쓸 수 없다 (E로 내린다).
const HORSE_PRICE := 8000
const HORSE_SPEED_MULT := 2.3
var has_horse := false
var riding := false
var horse_tile := Vector2i(14, 24)   # 세워 둔 자리 (12 + NORTH_PAD 12)


# 작물 성장에 걸리는 시간 배율 (씨앗 개량 + 성장 물약. 작을수록 빨리 자란다)
func breed_grow_mult() -> float:
	var m := 1.0 - 0.12 * breed_level   # 한 단계마다 성장 12% 단축
	return m * (0.8 if has_potion("grow") else 1.0)


func breed_price_mult() -> float:
	return 1.0 + 0.08 * breed_level     # 한 단계마다 판매가 8% 상승


func breed_next_cost() -> Array:
	if breed_level >= BREED_MAX:
		return []
	return [BREED_COST[breed_level], BREED_ORE[breed_level]]


# ---- 요리: 재료(작물/아이템) -> 요리 아이템. energy = 먹었을 때 회복량 ----
const RECIPES := {
	# ---- 밭에서 나오는 것 ----
	"dish_baked_potato": {"needs": {"potato": 2}, "energy": 30},
	"dish_soup": {"needs": {"potato": 1, "carrot": 2}, "energy": 45},
	"dish_jam": {"needs": {"strawberry": 3}, "energy": 35},
	"dish_cornbread": {"needs": {"corn": 2}, "energy": 50},
	# ---- 초반 음식 사슬 (레시피는 잡화점에서 조건부로 판다) ----
	# 산딸기를 주워 봐야 잼이, 밀을 거둬 봐야 밀가루가 선반에 오른다.
	# 넷을 전부 만들면 도감 「초반 음식」 컬렉션이 차고 이동 속도가 오른다
	"dish_berry_jam": {"needs": {"forage_berry": 3}, "energy": 30, "locked": true},
	"flour": {"needs": {"wheat": 1}, "energy": 5, "locked": true},
	"dish_bread": {"needs": {"flour": 1}, "energy": 45, "locked": true},
	"dish_berry_toast": {"needs": {"dish_berry_jam": 1, "dish_bread": 1},
		"energy": 80, "locked": true},
	"dish_eggplant": {"needs": {"eggplant": 2}, "energy": 40},
	"dish_salad": {"needs": {"cabbage": 1, "milk": 1}, "energy": 55},
	"dish_punch": {"needs": {"watermelon": 1, "strawberry": 1}, "energy": 60},
	"dish_pie": {"needs": {"pumpkin": 1, "egg": 1}, "energy": 80},
	"dish_pickle": {"needs": {"winter_radish": 2, "carrot": 1}, "energy": 45},
	"dish_ratatouille": {"needs": {"eggplant": 1, "tomato": 1, "pepper": 1}, "energy": 90},
	"dish_pumpkin_soup": {"needs": {"pumpkin": 1, "milk": 1}, "energy": 75},
	"dish_corn_salad": {"needs": {"corn": 1, "cabbage": 1, "tomato": 1}, "energy": 70},
	"dish_sweet_potato": {"needs": {"sweet_potato": 2}, "energy": 55},
	"dish_bean_rice": {"needs": {"bean": 2, "rice": 1}, "energy": 65},
	"dish_rice_cake": {"needs": {"rice": 2, "bean": 1}, "energy": 85},
	"dish_melon_ice": {"needs": {"melon": 1, "milk": 1}, "energy": 80},
	"dish_onion_soup": {"needs": {"onion": 2, "milk": 1}, "energy": 60},
	"dish_garlic_bread": {"needs": {"garlic": 1, "corn": 1}, "energy": 50},
	"dish_spinach_saute": {"needs": {"spinach": 2, "garlic": 1}, "energy": 55},
	# ---- 물에서 나오는 것 ----
	# 생선 요리는 물고기를 잡았다고 저절로 떠오르지 않는다 —
	# 잡화점에서 레시피(SHOP_DISH_RECIPES)를 사서 배운다
	"dish_grilled_fish": {"needs": {"fish_crucian": 1}, "energy": 40, "locked": true},
	"dish_stew": {"needs": {"fish_catfish": 1, "tomato": 1}, "energy": 65, "locked": true},
	"dish_sashimi": {"needs": {"fish_trout": 1, "winter_radish": 1}, "energy": 85, "locked": true},
	# 장어덮밥·연어 스테이크·빙어 튀김은 해변 노점에서 레시피를 사야 배운다
	"dish_eel_rice": {"needs": {"fish_eel": 1, "rice": 1}, "energy": 110, "locked": true},
	"dish_crab_soup": {"needs": {"fish_crab": 1, "onion": 1}, "energy": 95, "locked": true},
	"dish_salmon_steak": {"needs": {"fish_salmon": 1, "garlic": 1}, "energy": 120, "locked": true},
	"dish_smelt_fry": {"needs": {"fish_smelt": 3}, "energy": 70, "locked": true},
	"dish_fish_soup": {"needs": {"fish_minnow": 2, "spinach": 1}, "energy": 60, "locked": true},
	# ---- 귀한 것 ----
	# 황금잉어 구이는 잡화점 선반(황금잉어를 낚아 본 뒤)에서 레시피를 판다
	"dish_golden_roast": {"needs": {"fish_golden": 1, "sweet_potato": 1}, "energy": 160, "locked": true},
	"dish_moon_tea": {"needs": {"fish_moonfish": 1, "forage_herb": 2}, "energy": 150, "locked": true},
	# 숨겨진 레시피 — 해변에서 산호 조각을 처음 주우면 떠오른다
	"dish_coral_tea": {"needs": {"forage_coral": 1, "forage_herb": 2}, "energy": 150, "locked": true},
	"dish_feast": {"needs": {"fish_king": 1, "pumpkin": 1, "rice": 2}, "energy": 220, "locked": true},
	# ---- 마음이 담긴 요리 (♥ 컬렉션 보상) ----
	"butter": {"needs": {"milk": 1}, "energy": 20, "locked": true},
	"dish_fried_egg": {"needs": {"egg": 1}, "energy": 25, "locked": true},
	"dish_egg_roll": {"needs": {"egg": 1, "milk": 1}, "energy": 45, "locked": true},
	"dish_omurice": {"needs": {"egg": 1, "rice": 2}, "energy": 90, "locked": true},
	"dish_butter_corn": {"needs": {"butter": 1, "corn": 1}, "energy": 60, "locked": true},
}

# ---- 요리별 배부름 (배고픔 회복량) ----
#
# 체력(energy)과 **따로 논다**. 달인의 차 한 잔은 몸에 기운이 돌지만
# 배는 안 부르고, 감자 한 알은 기운은 덜해도 속이 든든하다.
# 그래서 회복량을 요리마다 따로 적는다 — 무엇을 먹을지 고민하게 만드는
# 것이 이 표의 목적이다.
#
#   국·밥·덮밥  : 든든하다 (체력보다 배부름이 크다)
#   빵·구이·전  : 무난하다
#   잼·간식·튀김: 입은 즐겁지만 금방 꺼진다
#   차·음료·얼음: 기운은 나도 배는 안 찬다
#   재료(밀가루·버터): 그대로 먹을 것이 못 된다
const RECIPE_FILL := {
	# 밭에서 나오는 것
	"dish_baked_potato": 45, "dish_soup": 55, "dish_jam": 20,
	"dish_cornbread": 60, "dish_berry_jam": 18, "flour": 3,
	"dish_bread": 60, "dish_berry_toast": 75,
	"dish_eggplant": 45, "dish_salad": 40, "dish_punch": 20,
	"dish_pie": 85, "dish_pickle": 30, "dish_ratatouille": 95,
	"dish_pumpkin_soup": 85, "dish_corn_salad": 55, "dish_sweet_potato": 70,
	"dish_bean_rice": 100, "dish_rice_cake": 90, "dish_melon_ice": 25,
	"dish_onion_soup": 65, "dish_garlic_bread": 55, "dish_spinach_saute": 45,
	# 물에서 나오는 것
	"dish_grilled_fish": 45, "dish_stew": 80, "dish_sashimi": 55,
	"dish_eel_rice": 110, "dish_crab_soup": 90, "dish_salmon_steak": 100,
	"dish_smelt_fry": 50, "dish_fish_soup": 70,
	# 귀한 것
	"dish_golden_roast": 130, "dish_moon_tea": 35, "dish_coral_tea": 35,
	"dish_feast": 200,
	# 마음이 담긴 요리
	"butter": 8, "dish_fried_egg": 30, "dish_egg_roll": 50,
	"dish_omurice": 105, "dish_butter_corn": 65,
}
const RECIPE_FILL_DEFAULT := 0.8   # 표에 없으면 체력의 8할쯤 찬다


# 이 요리를 먹으면 배가 얼마나 부른가
func recipe_fill(id: String) -> float:
	if RECIPE_FILL.has(id):
		return float(RECIPE_FILL[id])
	if RECIPES.has(id):
		return float(RECIPES[id].energy) * RECIPE_FILL_DEFAULT
	return 0.0


# 「든든함」 한마디 — 숫자 대신 감으로 읽는다 (가방·요리 창에서 쓴다)
func fill_word(id: String) -> String:
	var f := recipe_fill(id)
	if f >= 100.0:
		return "아주 든든하다"
	if f >= 60.0:
		return "든든하다"
	if f >= 35.0:
		return "적당하다"
	if f >= 15.0:
		return "가볍다"
	return "요기가 안 된다"
const RECIPE_IDS := ["dish_baked_potato", "dish_soup", "dish_jam", "dish_cornbread",
	"dish_berry_jam", "flour", "dish_bread", "dish_berry_toast",
	"dish_eggplant", "dish_salad", "dish_punch", "dish_pie", "dish_pickle",
	"dish_ratatouille", "dish_pumpkin_soup", "dish_corn_salad", "dish_sweet_potato",
	"dish_bean_rice", "dish_rice_cake", "dish_melon_ice", "dish_onion_soup",
	"dish_garlic_bread", "dish_spinach_saute",
	"dish_grilled_fish", "dish_stew", "dish_sashimi", "dish_eel_rice", "dish_crab_soup",
	"dish_salmon_steak", "dish_smelt_fry", "dish_fish_soup",
	"dish_golden_roast", "dish_moon_tea", "dish_coral_tea", "dish_feast",
	"butter", "dish_fried_egg", "dish_egg_roll", "dish_omurice", "dish_butter_corn"]
var recipes_cooked := {}  # 도감: id -> 만든 횟수
# 최후의 연금술(유니콘의 뿔)을 완성했는가 — 엔딩 후에도 자유 플레이 계속
var ending_seen := false

# ---- 연구 노트 ----
# 할아버지가 남긴 노트. 발견할 때마다 빈 페이지가 채워진다.
var crops_harvested := {}   # crop id -> 수확 횟수 (첫 수확 = 작물 기록)
var minerals_found := {}    # "ore"/"gem" -> true (한 번이라도 획득)
var memory_given := false   # 기억 조각을 받았는가 (호감도 100 보상, 1회)

# 진행도 50%부터 하나씩 풀리는 할아버지의 숨겨진 메모
# [필요 진행도(0~1), 제목, 내용]
const NOTE_MEMOS := [
	[0.5, "숨겨진 메모 I", "…흙에서 시작해야 한다. 생명을 키워 본 손만이\n다음 장을 읽을 자격이 있다.\n\n나는 이 마을의 밭에서 그 씨앗을 보았다."],
	[0.6, "숨겨진 메모 II", "물속에도, 바위 속에도, 어둠 속에도 재료는 있다.\n하나하나는 평범해 보이지만, 모이면 이야기가 된다.\n\n일곱. 일곱이 필요하다."],
	[0.7, "숨겨진 메모 III", "사람들은 내 연구를 비웃었지.\n하지만 가장 중요한 재료는 시장에서 살 수 없는 것들이다.\n땀, 정성, 그리고 사람의 마음."],
	[0.8, "숨겨진 메모 IV", "이제 너도 눈치챘을 것이다.\n네가 매일 하던 모든 일이 — 농사도, 낚시도, 탐험도 —\n전부 나의 연구였다는 걸.\n\n일곱 재료가 모이면, 연구실 책상에서 나를 만나러 오렴."],
]


func note_progress() -> Dictionary:
	# 연구 노트 채움 상태: {filled, total, ratio}
	var filled := 0
	var total := 0
	for id in CROP_IDS:
		total += 1
		if int(crops_harvested.get(id, 0)) > 0:
			filled += 1
	for fid in FISH_IDS:
		total += 1
		if int(fish_caught.get(fid, 0)) > 0:
			filled += 1
	for mid in MOBS:
		total += 1
		if int(mob_kills.get(mid, 0)) > 0:
			filled += 1
	for rid in RECIPE_IDS:
		total += 1
		if int(recipes_cooked.get(rid, 0)) > 0:
			filled += 1
	for mineral in ["ore", "gem"]:
		total += 1
		if minerals_found.get(mineral, false):
			filled += 1
	for npc_id in NPCS:
		# 이사 오고 가는 일반/특수 주민은 노트 페이지에 넣지 않는다 —
		# 떠날 수 있는 사람으로 100%가 막히면 안 된다 (필수 주민만 센다)
		if str(NPC_KIND.get(npc_id, "core")) != "core":
			continue
		total += 2  # 호감도 50 / 100 이야기
		if int(affinity[npc_id]) >= 50:
			filled += 1
		if int(affinity[npc_id]) >= 100:
			filled += 1
	for fid in FORAGE_IDS + BUG_IDS:
		total += 1
		if int(forage_caught.get(fid, 0)) > 0:
			filled += 1
	for leg in LEGENDS:
		total += 1
		if int(items[leg[0]]) > 0:
			filled += 1
	return {"filled": filled, "total": total, "ratio": float(filled) / float(total)}


func legends_owned() -> int:
	var n := 0
	for leg in LEGENDS:
		if int(items[leg[0]]) > 0:
			n += 1
	return n


func can_final_alchemy() -> bool:
	return legends_owned() == LEGENDS.size() and not ending_seen


# ---- 진짜 엔딩: 꿈속의 배웅 ----
#
# 게임의 핵심 목표는 **할아버지의 연구 노트를 100% 채우는 것**이다.
# 해금 조건:
#   1) 연구 노트 100% (note_progress().ratio >= 1.0)
#   2) 「할머니의 유품」 5종 — 시계·모자·팔찌·반지·목걸이.
#      노트가 20% 차오를 때마다 유품 하나의 힌트가 순서대로 열리고,
#      힌트가 열린 유품만 그 장소에서 아주 드물게 발견된다 (RELICS)
#   3) 일곱 분야(채광/벌목/농사/요리/전투/낚시/목장) **만렙** —
#      만렙을 찍을 때마다 「생명의 물」 한 병 (총 7병, water_life_found)
#   4) 연화(숲속의 집)를 찾아가 항아리에 일곱 병을 붓고
#      「기억의 물약」을 받아, 마시고 침대에서 잠들면 — 꿈속 엔딩
# 엔딩(꿈)이 끝나면 dream_seen이 켜지고 자유 플레이로 이어진다.

# 생명의 물 — 일곱 분야를 만렙까지 갈고닦은 증표
const ENDING_SKILLS := ["mine", "forest", "farm", "cook", "combat", "fish", "ranch"]
var water_life_found := {}    # 만렙 분야 id -> true
var water_pending := 0        # 방금 받은 병 수 — hud가 꺼내 토스트를 띄운다
var dream_ready := false      # 기억의 물약을 마셨다 — 오늘 밤 꿈속 엔딩
var dream_seen := false       # 꿈속 엔딩을 봤다 (자유 플레이 계속)
# 통계 리포트용 기록
var arrive_day := 0           # 처음 마을에 발 디딘 날 (0 = 옛 세이브)
var arrive_clock := ""        # 그 시각 ("오후 2:15")
var playtime_sec := 0.0       # 실제 플레이 시간 (초)
var rocks_mined := 0          # 깬 바위 수

# 할머니의 유품 5종 — 순서 = 힌트 해금 순서 (노트 20%마다 하나씩).
# 힌트가 열린 유품만 그 자리에서 발견된다. 확률·수치는 추후 조정 (임시값)
# 유품은 이야기 순서대로 놓는다 — 노트 20%마다 힌트가 하나씩 열리고,
# 각 유품은 제 이야기(스토리 11·13·16·17·18)에서 확정으로 손에 들어온다.
const RELICS := [
	{"id": "relic_hat", "name": "할머니의 모자", "chance": 0.05,
		"hint": "동굴 50층 아래, 광석을 깨다 보면 낡은 모자가 나온다더라..."},
	{"id": "relic_bracelet", "name": "할머니의 팔찌", "chance": 1.0,
		"hint": "두 분이 자주 걷던 해변 어딘가... 바다가 간직하고 있다더라."},
	{"id": "relic_ring", "name": "할머니의 반지", "chance": 1.0,
		"hint": "마을 밖 옛 농지 — 흙을 갈아엎다 보면 무언가 나온다더라."},
	{"id": "relic_necklace", "name": "할머니의 목걸이", "chance": 1.0,
		"hint": "동물들이 오가던 옛 목장 언저리에 잠들어 있다더라."},
	{"id": "relic_watch", "name": "할머니의 시계", "chance": 1.0,
		"hint": "두 분이 마지막으로 함께 오르던 언덕 위, 그 자리에..."},
]
var relic_pending := ""       # 방금 발견한 유품 이름 — hud가 꺼내 토스트


# i번째 유품의 힌트가 열렸는가 — 노트 20%마다 하나씩 (0번=20% ... 4번=100%)
func relic_hint_open(i: int) -> bool:
	return note_progress().ratio >= 0.2 * float(i + 1) - 0.0001


func relics_owned() -> int:
	var n := 0
	for r: Dictionary in RELICS:
		if int(items[r.id]) > 0:
			n += 1
	return n


# 유품 발견 굴림 — 힌트가 열려 있고 아직 없을 때만.
# roll에 0.0을 주면 무조건 성공, force_hint는 검증 하네스 전용이다.
func try_relic(i: int, roll := -1.0, force_hint := false) -> bool:
	var def: Dictionary = RELICS[i]
	if int(items[def.id]) > 0:
		return false
	if not force_hint and not relic_hint_open(i):
		return false
	var r := randf() if roll < 0.0 else roll
	if r >= float(def.chance):
		return false
	items[def.id] = 1
	discover(str(def.id))
	relic_pending = str(def.name)
	return true


# 분야가 만렙에 닿으면 생명의 물 한 병 — 분야당 한 번뿐이다.
# 스토리 19(일곱 갈래의 삶)가 시작된 뒤에만 병이 생긴다. 그 전에 이미
# 만렙을 찍어 둔 분야는 스토리가 열릴 때 소급해서 한꺼번에 채워진다.
func check_skill_water(id: String) -> void:
	if story19_phase == "":
		return
	if id not in ENDING_SKILLS or water_life_found.has(id):
		return
	if skill_lv(id) < SKILL_MAX_LV:
		return
	water_life_found[id] = true
	items["water_life"] += 1
	discover("water_life")
	water_pending += 1


# 이미 만렙인 분야를 소급해서 채운다 — 채운 분야 id 목록을 돌려준다
func water_backfill() -> Array:
	var got: Array = []
	for id: String in ENDING_SKILLS:
		if water_life_found.has(id) or skill_lv(id) < SKILL_MAX_LV:
			continue
		water_life_found[id] = true
		items["water_life"] += 1
		discover("water_life")
		got.append(id)
	return got


# 마지막 이야기(스토리 20)의 세 가지 조건이 다 갖춰졌는가 —
# 연구 노트 100% · 유품 다섯 · 생명의 물 일곱
func ending_ready() -> bool:
	return water_life_found.size() >= ENDING_SKILLS.size() \
		and relics_owned() >= RELICS.size() \
		and note_progress().ratio >= 1.0


func playtime_text() -> String:
	var mins := int(playtime_sec / 60.0)
	return "%d시간 %d분" % [mins / 60, mins % 60]


# ---- 주민 분류 · 이사 시스템 (입주/이탈) ----
#
# 주민은 세 갈래다:
#   core    필수 주민 — 메인 스토리로 확정 입주 (이장·만수·무쇠·보라·
#           용식·서하·재민·연화·솔이). 절대 마을을 떠나지 않는다.
#   normal  일반 주민 — 빈 집터가 있으면 랜덤으로 「이사 신청 편지」를
#           보내 오는 생활형 캐릭터 (농부 순돌·미식가 다미·낚시광 강태)
#   special 특수 주민 — 조건을 채워야 해금 (연금술사 묘연 — 연구 노트 50%)
# 편지를 수락해야 입주하고, 호감도가 낮거나(LEAVE_AFF 미만) 오래
# 말을 걸지 않으면(NEGLECT_DAYS) 떠날 마음이 생긴다 — 대개는 직접
# 「이사 가고 싶다」고 말하지만(붙잡을 수 있다), 드물게는 말없이
# 편지 한 통만 남기고 떠난다. 호감도 SAFE_AFF 이상이면 절대 안 떠난다.
const NPC_KIND := {
	"chief": "core", "merchant": "core", "blacksmith": "core",
	"postman": "core",
	"rancher": "core", "fisher": "core", "librarian": "core",
	"explorer": "core", "forest_mom": "core", "forest_girl": "core",
	"farmer": "normal", "foodie": "normal", "angler": "normal",
	"miner": "normal", "florist": "normal", "carpenter": "normal",
	"herbalist": "normal", "painter": "normal", "musician": "normal",
	"weaver": "normal",
	"alchemist": "special",
	# 고장 사람 — 제 고장에 뿌리내린 사람들이라 이사도 이탈도 없다.
	# core 와 같은 취급이지만 「교진 마을 주민 수」에는 안 든다
	"miller": "core", "dyer": "core", "brook": "core",
	"sawyer": "core", "beekeep": "core", "teller": "core",
	# 파출소의 선임 순경(S2b) — 건물 주인이라 core
	"officer_park": "core",
}
# 일반 주민 후보 — 앞쪽일수록 먼저 편지를 보내기 쉽다 (랜덤이지만 풀 순서대로
# 소문이 도는 셈). 전부 정착하면 최대 주민 21명 (핵심 9 + 일반 10 +
# 특수 1 + 플레이어) — 마을 회의(20명)는 마을을 알뜰히 키워야 열린다.
const SETTLER_POOL := ["farmer", "foodie", "angler", "miner", "florist",
	"carpenter", "herbalist", "painter", "musician", "weaver"]
const ALCHEMIST_NOTE := 0.5        # 연금술사 해금 — 연구 노트 50%
const SETTLER_OFFER_CHANCE := 0.25 # 아침마다 편지가 올 확률
const LEAVE_AFF := 20              # 이 밑이면 떠날 마음이 생긴다
const SAFE_AFF := 40               # 이 위면 절대 떠나지 않는다
const NEGLECT_DAYS := 7            # 이만큼 말을 안 걸면 서운해한다
const LEAVE_CHANCE := 0.25         # 조건이 찼을 때 아침마다 떠날 확률
const SILENT_LEAVE := 0.2          # 그중 말없이 떠나는 비율
var settlers: Array = []           # 정착한 일반/특수 주민 id
var settler_homes := {}            # nid -> [x, y] (집 앵커)
var empty_houses: Array = []       # 떠난 주민이 남긴 빈 집 — 재입주 우선
var settler_offer := ""            # 읽지 않은 이사 신청 편지의 주인
var settler_offer_day := 0         # 마지막으로 편지를 굴린 날
var settler_arrive := ""           # 내일 아침 이사 올 주민
var settler_arrive_day := 0
var settler_leaving := ""          # 「이사 가고 싶다」 말하려는 주민 (❗)
var settler_leave_day := 0         # 마지막으로 이탈을 굴린 날
var npc_last_talk := {}            # nid -> 마지막으로 대화한 날
var last_farewell := ""            # 마지막으로 말없이 떠난 주민 이름 (편지용)


func settler_kind(nid: String) -> String:
	return str(NPC_KIND.get(nid, "core"))


# 다음 이사 신청 후보 — 일반 주민 풀에서 랜덤.
# 떠난 주민도 다시 올 수 있다 (마을은 계속 살아 움직인다).
# 연금술사 묘연은 마을에 입주하지 않는다 — 깊은 숲의 오두막에서
# 계속 살며, 스토리 12로 만난다 (특수 주민의 새 길).
func settler_candidates() -> Array:
	var out: Array = []
	for nid: String in SETTLER_POOL:
		if nid not in settlers and settler_arrive != nid:
			out.append(nid)
	return out


# ---- 주민 삼자 대화 — 모여서 떠드는 이야깃거리 ----
# %A = 말을 거는 쪽 / %B = 상대 / 선택지마다 호감도가 오르는 쪽이 다르다
const TRIO_TOPICS := [
	{"q": "「어어, 마침 잘 왔어! %B는 축구보다 야구가\n좋다는데, 넌 어떻게 생각해?」",
		"a1": "나도 야구가 좋아!", "w1": "b",
		"a2": "역시 공은 발로 차야지!", "w2": "a"},
	{"q": "「%B가 그러는데 바다는 노을 질 때가 최고래.\n난 아침 바다가 좋은데 — 넌?」",
		"a1": "노을 지는 바다지!", "w1": "b",
		"a2": "아침 바다가 최고야!", "w2": "a"},
	{"q": "「%B랑 내기했거든 — 밥에는 국이냐, 반찬이냐.\n%B는 국파야. 네 생각은?」",
		"a1": "당연히 국이지!", "w1": "b",
		"a2": "반찬이 본체지!", "w2": "a"},
	{"q": "「비 오는 날 말이야, %B는 집이 최고라는데\n난 빗속 산책도 좋거든. 넌 어때?」",
		"a1": "집에서 뒹굴뒹굴!", "w1": "b",
		"a2": "우산 쓰고 산책!", "w2": "a"},
	{"q": "「%B는 겨울이 제일 좋대. 눈 때문이라나.\n난 봄이 좋은데 — 너는?」",
		"a1": "겨울 눈이 낭만이지!", "w1": "b",
		"a2": "역시 꽃 피는 봄!", "w2": "a"},
	{"q": "「%B랑 얘기 중이었어 — 든든한 아침이냐,\n느긋한 늦잠이냐! 너라면?」",
		"a1": "아침밥은 못 참지!", "w1": "b",
		"a2": "늦잠이 보약이야!", "w2": "a"},
]


# 수확 품질 굴리기: 0=일반 1=은 2=금 (농사 숙련도가 높을수록 좋다)
func roll_quality(luck := 0.0) -> int:
	# luck 은 장비 능력치(행운)에서 오는 보정값 (%p)
	var lv := skill_lv("farm")
	if randf() < 0.02 + lv * 0.008 + luck * 0.01:
		return 2
	if randf() < 0.08 + lv * 0.02 + luck * 0.02:
		return 1
	return 0


func add_produce(id: String, quality: int) -> void:
	produce[id] += 1
	discover(id)
	if quality == 2:
		produce_gold[id] = int(produce_gold.get(id, 0)) + 1
	elif quality == 1:
		produce_silver[id] = int(produce_silver.get(id, 0)) + 1


# 수확물 소비(요리/의뢰): 일반부터 쓰고, 품질본은 판매용으로 남긴다
func consume_produce(id: String, n: int) -> void:
	produce[id] -= n
	var normal: int = int(produce[id]) - int(produce_silver.get(id, 0)) \
		- int(produce_gold.get(id, 0))
	while normal < 0 and int(produce_silver.get(id, 0)) > 0:
		produce_silver[id] = int(produce_silver[id]) - 1
		normal += 1
	while normal < 0 and int(produce_gold.get(id, 0)) > 0:
		produce_gold[id] = int(produce_gold[id]) - 1
		normal += 1


# 품질 배수 — 은은 1.25배, 금은 1.5배
const QUALITY_MULT := [1.0, 1.25, 1.5]


# **작물 한 개 값. 파는 곳도 값을 적어 두는 곳도 전부 이 함수를 지난다.**
#
# 예전엔 곳마다 따로 셌다. 그래서 세 가지가 어긋나 있었다:
#   ① 진열대는 「합쳐서 내림」, 실제 판매는 「개당 내림」 — 딸기 다섯에
#      450G 이라 적어 놓고 448G 을 줬다. 두 푼이지만 장부는 장부다
#   ② 연구소 개량(단계마다 +8%)은 여기서만 곱해졌다. 실제로 파는 쪽은
#      곱하지 않아서, **돈과 광석을 들여 올린 개량이 수입을 한 푼도
#      못 올리고 있었다**. 마을 안내판은 「판매가 +N%」라고 적혀 있는데
#   ③ 경매장의 「잡화점 기준값」은 은 2배·금 3배로 세고 있었다 —
#      잡화점이 실제로 쳐 주는 값(1.25/1.5배)과 다른 숫자였다
#
# 세금도 봉급도 예산도 전부 이 숫자 위에 선다. 값을 묻는 길은 하나뿐이다.
func crop_unit_price(id: String, quality := 0, mult := 1.0) -> int:
	if not CROPS.has(id):
		return 0
	return int(CROPS[id].sell_price * breed_price_mult()
		* float(QUALITY_MULT[clampi(quality, 0, 2)]) * mult)


# 보유 전량 판매 가치 (은 1.25배 / 금 1.5배)
#
# `produce` 는 총량이고 `produce_silver`/`produce_gold` 는 그 **부분집합**이다
# (add_produce 참고). 일반 = 총량 - 은 - 금.
func produce_sell_value(id: String, mult := 1.0) -> int:
	var silver := int(produce_silver.get(id, 0))
	var gold := int(produce_gold.get(id, 0))
	var normal: int = int(produce[id]) - silver - gold
	return normal * crop_unit_price(id, 0, mult) \
		+ silver * crop_unit_price(id, 1, mult) \
		+ gold * crop_unit_price(id, 2, mult)


# 재료 보유량 (작물이면 수확물, 아니면 아이템)
func ingredient_count(id: String) -> int:
	return int(produce[id]) if CROPS.has(id) else int(items[id])


# 잠긴 레시피인가 — 모든 요리는 배워야 만들 수 있다.
# 조리대는 빈 채로 시작하고, 인게임 플레이로만 하나씩 열린다:
#   기본 요리  재료를 전부 발견하면 저절로 떠오른다 (_check_recipe_unlocks)
#   locked 표시 퀘스트·컬렉션·상점(노점) 같은 정해진 길로만 열린다
func recipe_locked(id: String) -> bool:
	return id not in recipes_unlocked


# 재료를 새로 발견할 때마다 — 재료를 다 아는 기본 요리가 떠오른다.
# (locked 표시가 붙은 요리는 여기서 열리지 않는다)
func _check_recipe_unlocks() -> void:
	for rid: String in RECIPE_IDS:
		if bool(RECIPES[rid].get("locked", false)) or rid in recipes_unlocked:
			continue
		var know_all := true
		for k in RECIPES[rid].needs:
			if not discovered.has(k):
				know_all = false
				break
		if know_all:
			recipes_unlocked.append(rid)
			recipe_pending.append(rid)   # hud가 꺼내 토스트를 띄운다


func can_cook(id: String) -> bool:
	if recipe_locked(id):
		return false
	for k in RECIPES[id].needs:
		if ingredient_count(k) < int(RECIPES[id].needs[k]):
			return false
	return true


func cook(id: String) -> bool:
	if not can_cook(id):
		return false
	for k in RECIPES[id].needs:
		if CROPS.has(k):
			consume_produce(k, int(RECIPES[id].needs[k]))
		else:
			items[k] -= int(RECIPES[id].needs[k])
	items[id] += 1
	discover(id)
	recipes_cooked[id] = int(recipes_cooked.get(id, 0)) + 1
	return true

# 낚시: [아이템 id, 확률 가중치, 타이밍 존 폭(px)]
# [id, 나올 확률(무게), 판정 구간 너비, 성공 횟수, 커서 속도 배율]
# 귀한 물고기일수록 구간이 좁고 · 여러 번 맞혀야 하고 · 커서가 빠르다.
# 황금잉어는 세 번을 이어서 맞혀야 올라온다.
# ---- 물고기 ----
#
# 언제 무는지가 물고기마다 다르다. 그래야 「오늘은 뭐가 물까」가 생긴다.
#   seasons  빈 배열이면 사계절
#   time     "" 아무 때 / "morning" 6~11시 / "day" 11~18시 / "night" 18시~새벽
#   weather  빈 배열이면 날씨 무관
# 미니게임 쪽 값 —
#   zone  초록 구간의 폭(작을수록 어렵다) · stages 몇 번 맞춰야 하는가
#   speed 찌가 움직이는 빠르기 · w 같은 조건 안에서의 흔한 정도
const FISH := [
	# 계절 로스터는 완전히 갈린다 — 일반 물고기는 저마다 한 계절에만
	# 문다 (안개·폭풍·별밤 같은 날씨 어종과 전설급만 계절 무관).
	# 흔한 것들
	{"id": "fish_crucian", "w": 1.00, "zone": 96.0, "stages": 1, "speed": 1.00,
		"seasons": [SPRING], "time": "", "weather": [], "hint": "가볍게 톡 —"},
	{"id": "fish_minnow", "w": 0.90, "zone": 100.0, "stages": 1, "speed": 0.95,
		"seasons": [SUMMER], "time": "", "weather": [], "hint": "톡, 톡 —"},
	{"id": "fish_loach", "w": 0.70, "zone": 88.0, "stages": 1, "speed": 1.15,
		"seasons": [FALL], "time": "", "weather": [], "hint": "꿈틀거린다"},
	# 봄
	{"id": "fish_bitterling", "w": 0.65, "zone": 92.0, "stages": 1, "speed": 1.00,
		"seasons": [SPRING], "time": "", "weather": [], "hint": "가볍게 톡 —"},
	{"id": "fish_carp", "w": 0.55, "zone": 84.0, "stages": 2, "speed": 1.12,
		"seasons": [SUMMER], "time": "", "weather": [], "hint": "제법 당긴다!"},
	{"id": "fish_sweetfish", "w": 0.40, "zone": 70.0, "stages": 2, "speed": 1.30,
		"seasons": [SPRING], "time": "morning", "weather": [], "hint": "빠르다!"},
	{"id": "fish_trout", "w": 0.35, "zone": 66.0, "stages": 2, "speed": 1.35,
		"seasons": [WINTER], "time": "morning", "weather": [], "hint": "빠르다!"},
	# 여름
	{"id": "fish_mandarin", "w": 0.32, "zone": 58.0, "stages": 2, "speed": 1.45,
		"seasons": [SUMMER], "time": "day", "weather": [], "hint": "홱 채간다!"},
	{"id": "fish_catfish", "w": 0.45, "zone": 54.0, "stages": 2, "speed": 1.30,
		"seasons": [SUMMER], "time": "night", "weather": [], "hint": "묵직하다!!"},
	{"id": "fish_eel", "w": 0.30, "zone": 50.0, "stages": 3, "speed": 1.40,
		"seasons": [SUMMER], "time": "night", "weather": [WEATHER_RAIN], "hint": "미끄럽게 빠져나간다!!"},
	{"id": "fish_snakehead", "w": 0.25, "zone": 48.0, "stages": 3, "speed": 1.50,
		"seasons": [FALL], "time": "night", "weather": [], "hint": "낚싯대가 휜다!!!"},
	# 가을
	{"id": "fish_crab", "w": 0.45, "zone": 78.0, "stages": 1, "speed": 0.85,
		"seasons": [FALL], "time": "", "weather": [], "hint": "게걸음처럼 옆으로 —"},
	{"id": "fish_salmon", "w": 0.30, "zone": 52.0, "stages": 3, "speed": 1.50,
		"seasons": [FALL], "time": "morning", "weather": [], "hint": "거슬러 오른다!!"},
	{"id": "fish_rainbow", "w": 0.30, "zone": 56.0, "stages": 2, "speed": 1.40,
		"seasons": [SPRING], "time": "", "weather": [WEATHER_RAIN], "hint": "무지개빛이 스친다!"},
	# 겨울
	{"id": "fish_smelt", "w": 0.75, "zone": 90.0, "stages": 1, "speed": 1.05,
		"seasons": [WINTER], "time": "", "weather": [], "hint": "가볍게 톡 —"},
	{"id": "fish_icecarp", "w": 0.40, "zone": 68.0, "stages": 2, "speed": 1.25,
		"seasons": [WINTER], "time": "", "weather": [], "hint": "차갑게 당긴다"},
	{"id": "fish_lenok", "w": 0.25, "zone": 46.0, "stages": 3, "speed": 1.55,
		"seasons": [WINTER], "time": "", "weather": [WEATHER_SNOW], "hint": "낚싯대가 휜다!!!"},
	# 날씨가 만드는 것들
	{"id": "fish_mistfish", "w": 0.50, "zone": 60.0, "stages": 2, "speed": 1.35,
		"seasons": [], "time": "", "weather": [WEATHER_FOG], "hint": "안개 속에서 뭔가가 —"},
	{"id": "fish_stormjack", "w": 0.50, "zone": 44.0, "stages": 3, "speed": 1.60,
		"seasons": [], "time": "", "weather": [WEATHER_STORM], "hint": "물살을 가른다!!!"},
	{"id": "fish_moonfish", "w": 0.40, "zone": 42.0, "stages": 3, "speed": 1.60,
		"seasons": [], "time": "night", "weather": [WEATHER_STAR], "hint": "달빛이 흔들린다!!"},
	{"id": "fish_starcarp", "w": 0.30, "zone": 40.0, "stages": 3, "speed": 1.65,
		"seasons": [], "time": "", "weather": [WEATHER_STAR], "hint": "별이 물속에서 —!!!"},
	{"id": "fish_ghost", "w": 0.20, "zone": 36.0, "stages": 3, "speed": 1.70,
		"seasons": [], "time": "night", "weather": [WEATHER_FOG], "hint": "아무 무게도 느껴지지 않는다..."},
	# 어디서나 아주 드물게
	{"id": "fish_golden", "w": 0.07, "zone": 34.0, "stages": 3, "speed": 1.50,
		"seasons": [], "time": "", "weather": [], "hint": "낚싯대가 휜다!!!"},
	{"id": "fish_king", "w": 0.04, "zone": 30.0, "stages": 4, "speed": 1.75,
		"seasons": [], "time": "", "weather": [], "hint": "이건... 뭔가 다르다!!!"},
	{"id": "fish_dragon", "w": 0.03, "zone": 26.0, "stages": 4, "speed": 1.90,
		"seasons": [], "time": "night", "weather": [WEATHER_STORM], "hint": "물이 통째로 솟구친다!!!!"},
]


# 지금이 어느 때인가 — 물고기 조건에 쓴다.
func fish_time_key() -> String:
	var h := minutes / 60.0
	if h < 11.0:
		return "morning"
	if h < 18.0:
		return "day"
	return "night"


# 지금 물 수 있는 물고기만 추린다 (흔한 것 → 드문 것 순).
func fish_now() -> Array:
	var s := season()
	var w := weather_today()
	var t := fish_time_key()
	var out: Array = []
	for f: Dictionary in FISH:
		var seasons: Array = f.seasons
		if not seasons.is_empty() and s not in seasons:
			continue
		var weathers: Array = f.weather
		if not weathers.is_empty() and w not in weathers:
			continue
		if str(f.time) != "" and str(f.time) != t:
			continue
		out.append(f)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.w) > float(b.w))
	return out

var items := {}
var fish_caught := {}  # 도감용 누적 기록

# ---- 부지 ----
# 부지 구입 시스템은 삭제했다. 맵은 처음부터 전부 오갈 수 있고,
# 다음 마을은 이후 이야기(스토리)로 열린다.

func is_tile_owned(x: int, y: int) -> bool:
	# 메인 스토리 4의 확장 구역만 잠긴다 — 그 밖의 땅은 전부 오갈 수 있다
	var zid := zone_at(x, y)
	return zid == "" or zid in zones_open


# ---- NPC / 퀘스트 ----
# 호감도가 오르면 secret50/secret100 대사가 풀리며 할아버지의 과거가 드러난다
# ---- 마을 사람 ----
#
# 대사가 넉 줄뿐이면 세 번째 대화에서 이미 다 본 게 된다. 그래서 갈래를
# 나눴다 — 계절 · 날씨 · 시간대 · 호감도 · 연애 단계. `npc_line()`이
# 지금 맞는 갈래를 모아 그 안에서 하나를 뽑는다.
#
#   birthday  [계절, 날] — 그날 선물은 세 배로 오른다
#   gender    성별 (m/f) — 호감도·결혼 이벤트가 참고한다
#   romance   연애할 수 있는가 (마을 어른 둘은 아니다)
#   loves     아주 좋아함 +30 · likes 좋아함 +18 · hates 싫어함 -6
#             (표에 없는 것은 +8)
const NPCS := {
	"merchant": {"name": "만수", "birthday": [SPRING, 12], "gender": "f", "romance": true,
	"lines": [
		"어서 와! 오늘도 농사는 잘 되고 있어?",
		"제철 씨앗이 제일 잘 자라. 가게 안으로 들어와!",
		"거둔 작물은 우리 가게로 가져와. 내가 좋은 값에 사줄게.",
		"스프링클러를 세워 두면 그 둘레는 물주기가 아예 필요 없어.",
		"장부 정리가 제일 싫어. 숫자만 보면 졸려...",
	],
	"season": {
		SPRING: ["봄 씨앗이 들어왔어! 딸기가 인기야.",
			"봄이 되면 가게에 사람이 북적여서 좋아."],
		SUMMER: ["여름엔 수박이 제일 잘 팔려. 너도 심어 봐!",
			"더워... 가게 안이 그나마 시원해."],
		FALL: ["가을엔 다들 창고를 채우느라 바빠. 나도 그렇고.",
			"호박 값이 좋을 때야. 지금이 기회라고!"],
		WINTER: ["겨울엔 밭이 쉬니까 나도 좀 쉬어.",
			"난롯가에서 장부 보는 거, 이건 좀 좋아."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오는 날엔 손님이 없어. 너라도 와줘서 다행이야."],
		WEATHER_SNOW: ["눈 오는 날 가게 앞 쓸기가 제일 힘들어..."],
		WEATHER_STORM: ["폭풍이야! 가게 덧문 닫는 거 도와줄래?"],
		WEATHER_FOG: ["안개 낀 날은 간판이 안 보여서 손님이 길을 잃어."],
		WEATHER_STAR: ["오늘 별 봤어? 이런 밤엔 이상한 물건이 잘 팔려."],
	},
	"morning": ["아침 일찍부터 부지런하네! 나도 방금 문 열었어."],
	"night": ["이 시간까지 안 자고? 무리하지 마."],
	"aff30": ["요즘 네 얼굴 보는 게 하루 낙이야.",
		"너한테는 특별히 싸게 줄게. 비밀이야!"],
	"aff70": ["...가끔은 장사 얘기 말고 다른 얘기도 하고 싶어.",
		"네가 오는 시간쯤 되면 나도 모르게 문 쪽을 봐."],
	"dating": ["오늘 장사 접고 같이 걸을까?",
		"네 밭에서 난 거라면 뭐든 맛있어.",
		"가게 문에 「잠시 자리 비움」 걸어 둘게. 잠깐만 있다 가."],
	"married": ["다녀왔어? 밥은?",
		"오늘 장부에 네 이름을 세 번이나 썼어. 실수로.",
		"가게보다 집이 좋아진 건 네 탓이야."],
	"loves": ["strawberry", "dish_jam", "dish_rice_cake", "gem"],
	"likes": ["potato", "carrot", "melon", "dish_punch", "forage_berry"],
	"hates": ["sludge", "fish_loach"],
	"secret50": "너희 할아버지... 우리 가게 단골이었어. 늘 이상한 걸 찾으셨지.\n'달빛을 먹고 자란 작물'이라던가... 밭에서도 기적이 자란다고 하셨어.",
	"secret100": "떠나시기 전에 그러셨어. '내 연구는 이 마을 전부에 흩어져 있다'고.\n밭, 호수, 숲, 동굴... 그리고 사람들 속에도. 이제 그 말뜻을 알겠니?",
	},
	"fisher": {"name": "용식", "birthday": [SUMMER, 3], "gender": "m", "romance": true,
	"lines": [
		"입질이 오면 초록 구간에서 낚아채는 거야.",
		"황금잉어는 정말 귀하지... 나도 두 번밖에 못 봤어.",
		"비 오는 날엔 왠지 물고기가 더 잘 잡히는 기분이야.",
		"겨울엔 농사가 안 되니 낚시가 최고야.",
		"물고기는 시간을 알아. 아침 놈과 밤 놈이 따로 있어.",
	],
	"season": {
		SPRING: ["봄엔 은어가 올라와. 아침 일찍 나와야 해.",
			"물이 풀리는 소리, 저게 봄이 왔다는 신호야."],
		SUMMER: ["여름 밤엔 메기가 물어. 등불 하나 챙겨 가.",
			"장어는 비 오는 여름 밤에만 나와. 진짜야."],
		FALL: ["가을엔 연어가 거슬러 올라. 아침에 가 봐.",
			"참게 철이다. 국 끓이면 그렇게 시원할 수가 없어."],
		WINTER: ["얼음 위에서 빙어를 낚는 맛, 알아?",
			"열목어는 눈 오는 날에만 나와. 손 시려도 참을 만해."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오는 날이야말로 낚시하기 좋은 날이지."],
		WEATHER_SNOW: ["눈 오는 날 낚시? 나 같은 놈이나 하는 거지."],
		WEATHER_STORM: ["오늘은 물가에 가지 마. 물이 사람을 삼켜."],
		WEATHER_FOG: ["안개 낀 물가에선... 가끔 없는 게 물어."],
		WEATHER_STAR: ["별 뜬 밤 물속을 봐. 별이 하나 더 헤엄쳐."],
	},
	"morning": ["새벽 물이 제일 맑아. 좋은 시간에 나왔네."],
	"night": ["밤낚시 하러 왔어? 조용히 해, 놈들이 눈치채."],
	"aff30": ["내 자리 하나 비워 뒀어. 옆에 앉아.",
		"너랑 있으면 입질이 잘 오는 것 같단 말이지."],
	"aff70": ["...혼자 낚는 게 편했는데, 요즘은 아니야.",
		"오늘 잡은 거 반은 네 몫이야. 그냥 그러고 싶어서."],
	"dating": ["오늘은 물고기 말고 네 얼굴만 봤어.",
		"낚싯대 두 개 챙겨 왔어. 하나는 네 거."],
	"married": ["아침에 국 끓여 놨어. 식기 전에 먹어.",
		"오늘은 일찍 접고 왔어. 집에 오고 싶어서."],
	"loves": ["fish_golden", "dish_sashimi", "dish_grilled_fish", "fish_king"],
	"likes": ["fish_carp", "fish_catfish", "dish_stew", "forage_herb", "forage_shell"],
	"hates": ["sludge", "dish_jam"],
	"secret50": "네 할아버지랑 밤새 낚시하던 게 엊그제 같은데...\n그분은 물고기를 잡으면 놓아주면서 뭔가를 계속 적으셨어. 연구라고 하셨지.",
	"secret100": "할아버지가 마지막으로 남긴 말이 있어. '전설은 잡는 게 아니라\n기록하는 것'이라고. 이 기억 조각... 네가 가져야 할 것 같구나.",
	},
	"rancher": {"name": "보라", "birthday": [FALL, 20], "gender": "f", "romance": true,
	"lines": [
		"동물은 사랑을 먹고 자라. 매일 쓰다듬어 줘!",
		"닭이 낳은 달걀은 아침에 거둬야 신선해.",
		"우리 목장 상회에서 귀여운 펫도 분양하고 있어~",
		"축사가 있으면 비 오는 날에도 동물들이 편하지.",
		"소가 나를 보고 우는 소리, 그게 인사인 거 알아?",
	],
	"season": {
		SPRING: ["봄엔 새끼들이 태어나. 눈코 뜰 새가 없어!",
			"목초가 파래지면 우유 맛이 달라져. 진짜야."],
		SUMMER: ["더울 땐 동물들도 지쳐. 물을 자주 갈아 줘.",
			"여름 저녁에 목장 바람 쐬러 와. 시원해."],
		FALL: ["가을 털이 제일 좋아. 이때 깎아야 해.",
			"겨울나기 준비로 건초를 쌓는 철이야."],
		WINTER: ["눈 오면 다 안으로 들여야 해서 바빠.",
			"겨울엔 축사 안이 제일 따뜻해. 놀러 와."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오면 애들을 다 안에 들여야 해. 도와줄래?"],
		WEATHER_SNOW: ["눈 오는 날 축사는 김이 모락모락 나."],
		WEATHER_STORM: ["폭풍이야! 울타리 무너지지 않게 봐 둬야 해."],
		WEATHER_FOG: ["안개 끼면 애들이 길을 잃어. 종을 달아 놨어."],
		WEATHER_STAR: ["별 뜬 밤엔 닭들도 안 자고 하늘을 봐. 신기하지?"],
	},
	"morning": ["아침 젖 짜는 거 도와줄래? 손이 모자라!"],
	"night": ["이 시간엔 애들 다 자. 조용히 와."],
	"aff30": ["우리 애들이 너를 알아봐. 좋은 사람이란 뜻이야.",
		"네가 오는 날은 우유가 더 잘 나와. 우연 아니야."],
	"aff70": ["동물한테만 마음을 주고 살았는데... 요즘은 좀 달라.",
		"오늘은 일 얘기 말고 그냥 앉아 있자."],
	"dating": ["송아지 이름을 네 이름으로 지었어. 싫어?",
		"목장 노을 보러 갈래? 오늘 좋을 것 같아."],
	"married": ["오늘 짠 우유 제일 좋은 걸로 남겨 뒀어.",
		"집에 오니까 좋다. 그 말이 이런 거구나."],
	"loves": ["milk", "golden_egg", "dish_melon_ice", "dish_salad"],
	"likes": ["egg", "cabbage", "bean", "dish_pumpkin_soup"],
	"hates": ["sludge", "fish_snakehead"],
	"secret50": "너희 할아버지, 동물들이 유난히 따랐어.\n'동물이 주는 건 생산물이 아니라 마음'이라고 입버릇처럼 말씀하셨지.",
	"secret100": "언젠가 금빛으로 빛나는 달걀을 보여주신 적이 있어.\n'사랑받은 닭만이 낳을 수 있다'며... 나는 아직도 그게 꿈같아.",
	},
	"blacksmith": {"name": "무쇠", "birthday": [WINTER, 8], "gender": "m", "romance": false,
	"lines": [
		"광석을 가져오면 도구를 벼려주지. 대장간으로 와.",
		"동굴 깊은 곳 광석일수록 좋은 쇠가 된다.",
		"쇠는 정직해. 두드린 만큼만 단단해지지.",
		"요즘 젊은것들은 도끼 가는 법도 몰라... 자네는 다르군.",
		"불은 거짓말을 안 해. 뜨거우면 뜨겁다고 말하지.",
	],
	"season": {
		SPRING: ["봄엔 연장 손보러 오는 사람이 줄을 서지."],
		SUMMER: ["여름 화덕 앞은 지옥이야. 그래도 불은 꺼뜨릴 수 없지."],
		FALL: ["가을엔 겨울 연장을 미리 벼려 둬야 해."],
		WINTER: ["겨울엔 화덕 앞이 제일 좋은 자리지. 앉게."],
	},
	"weather": {
		WEATHER_RAIN: ["빗소리에 망치 소리가 묻히는군. 나쁘지 않아."],
		WEATHER_SNOW: ["눈 오는 날의 쇠는 더 잘 식어. 담금질하기 좋지."],
		WEATHER_STORM: ["번개 치는 날 벼린 쇠가 제일 좋다는 말이 있어."],
		WEATHER_FOG: ["안개 낀 날은 불빛이 멀리 안 가. 조심히 다니게."],
		WEATHER_STAR: ["별빛 조각... 저런 게 하늘에서 떨어진다니 믿기나?"],
	},
	"morning": ["일찍 왔군. 화덕이 아직 덜 달았네."],
	"night": ["이 시간에? 대장간 불은 벌써 껐네."],
	"aff30": ["자네 손을 보니 일하는 손이야. 마음에 들어.",
		"자네가 가져오는 광석은 늘 깨끗해. 고르는 눈이 있어."],
	"aff70": ["내 연장 중 하나를 자네한테 물려줄 생각을 하고 있네.",
		"손주가 있었으면 자네 같았을 텐데 말이야."],
	"loves": ["star_ore", "ore", "gem", "star_shard"],
	"likes": ["dish_baked_potato", "dish_stew", "sweet_potato"],
	"hates": ["sludge", "dish_punch"],
	"secret50": "자네 할아버지? 별난 양반이었지. 광석을 사 가면서\n'이건 녹이려는 게 아니라 별을 담으려는 거야'라고 하더군.",
	"secret100": "떠나기 전에 화로를 빌려 갔어. 뭘 만들었는지는 끝내 안 보여줬지만...\n그날 밤 대장간 굴뚝에서 무지개색 연기가 올라왔다네.",
	},
	"chief": {"name": "덕수", "birthday": [FALL, 5], "gender": "m", "romance": false,
	"lines": [
		"우리 마을에 젊은 사람이 오니 좋구먼.",
		"부지 문서는 내가 관리하고 있네. 표지판에서 사면 돼.",
		"광장 게시판에 마을 사람들 부탁이 올라온다네.",
		"자네 할아버지와는... 오랜 친구였지.",
		"마을이 커지는 걸 보는 게 늙은이의 낙이야.",
	],
	"season": {
		SPRING: ["봄 꽃놀이 준비는 잘 되어 가나? 광장에서 보세."],
		SUMMER: ["여름 낚시대회가 곧이야. 자네도 나가 보게."],
		FALL: ["가을엔 추수 감사 잔치가 있지. 기대하게."],
		WINTER: ["겨울 등불 축제는 내가 제일 좋아하는 날이야."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오는 날엔 늙은 무릎이 먼저 알아채."],
		WEATHER_SNOW: ["눈이 오면 마을이 조용해져서 좋아."],
		WEATHER_STORM: ["다들 집에 있으라고 일러뒀네. 자네도 조심하게."],
		WEATHER_FOG: ["안개 낀 날엔 옛날 일이 자꾸 떠올라."],
		WEATHER_STAR: ["이런 밤이면 자네 할아버지 생각이 나는군."],
	},
	"morning": ["부지런하구먼. 젊을 땐 나도 그랬지."],
	"night": ["늦었네. 젊다고 몸을 함부로 쓰면 안 돼."],
	"aff30": ["자네가 오고 나서 마을이 밝아졌어.",
		"이 마을을 자네에게 맡겨도 되겠다는 생각을 해."],
	"aff70": ["언젠가 이 마을을 자네가 이끌었으면 하네.",
		"내 친구의 손주가 이렇게 자랐구먼... 고맙네."],
	"loves": ["dish_feast", "dish_bean_rice", "memory_piece", "dish_rice_cake"],
	"likes": ["rice", "pumpkin", "dish_pie", "leek"],
	"hates": ["sludge"],
	"secret50": "자네 할아버지가 이 마을에 처음 왔을 때, 다들 미친 사람 취급했어.\n나만 빼고. 그 눈빛은... 미친 게 아니라 믿는 사람의 눈이었거든.",
	"secret100": "그 양반이 마지막으로 한 말을 전해주지. '덕수, 내 손주가 오면\n일곱 가지를 모을 걸세. 그때 이 마을은 기적을 보게 될 거야.'",
	},
	# ---- 우체국이 서면 마을에 눌러앉는 사람 (메인 스토리 3의 마지막) ----
	"postman": {"name": "우체부 아저씨", "birthday": [SUMMER, 3], "gender": "m",
	"romance": false,
	"lines": [
		"자네 편지 덕에 이 마을에 눌러앉게 됐지 뭔가.",
		"우체국이 생기니 이제 소문도 편지도 다 여기로 모여.",
		"먼 길 걷는 건 이제 그만... 이라고 말은 하는데, 몸이 근질근질해.",
		"이사 오고 싶다는 편지가 또 왔더군. 자네한테 갈 걸세.",
		"편지 한 통이 사람 하나를 데려오는 걸 여러 번 봤네.",
	],
	"morning": ["첫 배달은 해 뜨기 전에 나가야 제맛이지."],
	"night": ["이 시간에 오는 편지는 대개 급한 소식이야."],
	"aff30": ["숲에서 처음 만났을 때가 엊그제 같구먼.",
		"자네 앞으로 온 편지는 내가 제일 먼저 챙겨 두네."],
	"aff70": ["이 마을에 정 붙인 건 순전히 자네 탓일세.",
		"내 가방에서 제일 무거운 건 자네한테 갈 소식이야."],
	"loves": ["dish_bread", "dish_berry_toast", "dish_egg_roll"],
	"likes": ["dish_soup", "forage_berry", "milk"],
	"hates": ["sludge"],
	"secret50": "자네 할아버지 앞으로 온 편지는 늘 두꺼웠어.\n답장은 더 두꺼웠고. 어디로 부치는지는 끝내 안 알려주셨지.",
	"secret100": "마지막으로 부친 편지, 수취인이 비어 있었네.\n「언젠가 이 집에 올 사람에게」 — 그게 자네였구먼.",
	},
	# ---- 메인 스토리 5에서 합류하는 사람들 ----
	"explorer": {"name": "재민", "birthday": [FALL, 7], "gender": "m", "romance": false,
	"lines": [
		"이 마을, 걸어서 안 가 본 데가 없어. ...아마도?",
		"지도 밖이 제일 재밌는 법이야.",
		"동굴 가 봤어? 밑으로 내려갈수록 심장이 뛰지!",
		"가만히 있으면 몸이 근질근질해서 말이야.",
		"오늘은 어느 쪽으로 가 볼까... 같이 갈래?",
	],
	"morning": ["아침 공기 좋다! 이런 날은 멀리 가야지."],
	"night": ["별 보면서 걷는 것도 모험이라면 모험이지."],
	"aff30": ["너도 꽤 모험가 기질이 있단 말이지.",
		"다음에 좋은 데 찾으면 너한테 제일 먼저 알려줄게."],
	"aff70": ["혼자 다니는 게 좋았는데... 요즘은 둘이 다니는 게 더 좋아.",
		"내 지도에 네 이름으로 표시해 둔 곳이 있어. 언젠가 같이 가자."],
	"loves": ["dish_stew", "forage_relic", "fish_stormjack"],
	"likes": ["forage_berry", "forage_glass", "dish_baked_potato"],
	"hates": ["sludge"],
	},
	"forest_mom": {"name": "연화", "birthday": [SPRING, 20], "gender": "f", "romance": false,
	"lines": [
		"숲의 아침 공기는 약이 돼요. 그래서 여기 살아요.",
		"솔이가 요즘은 얼굴빛이 많이 좋아졌어요.",
		"조용한 게 좋아서... 마을엔 잘 안 내려가요.",
		"약초를 달여 두었는데, 향이 참 좋죠?",
	],
	"morning": ["이슬 마르기 전 숲이 제일 예뻐요."],
	"night": ["밤 숲은 차요. 감기 조심하세요."],
	"aff30": ["당신이 오는 날은 솔이가 문 앞을 서성여요.",
		"따뜻한 차 한 잔 하고 가요."],
	"aff70": ["사람이 그리웠나 봐요, 우리 둘 다.\n와 줘서 고마워요.",
		"이 숲에 온 게 잘한 일이었다고, 요즘 처음 생각해요."],
	"loves": ["forage_herb", "dish_moon_tea", "dish_coral_tea"],
	"likes": ["forage_berry", "dish_soup", "dish_onion_soup"],
	"hates": ["sludge", "forage_trash"],
	},
	"forest_girl": {"name": "솔이", "birthday": [SUMMER, 14], "gender": "f", "romance": false,
	"lines": [
		"기침이 많이 나아졌어요. 숲 공기 덕분이래요!",
		"창문으로 다람쥐가 보여요. 이름도 지어 줬어요.",
		"언젠가 마을 축제에 가 보고 싶어요.",
		"오늘은 엄마랑 산딸기잼을 만들었어요!",
	],
	"morning": ["아침엔 새소리 세기 놀이를 해요. 오늘은 일곱!"],
	"night": ["이 시간엔 자야 하는데... 쉿, 비밀이에요."],
	"aff30": ["오늘도 와 줬네요! 헤헤.",
		"나중에 내가 제일 좋아하는 나무 보여줄게요."],
	"aff70": ["있잖아요, 다 나으면요...\n제일 먼저 같이 바다에 가고 싶어요.",
		"엄마가 그러는데, 좋은 사람이 오면 병도 빨리 낫는대요."],
	"loves": ["dish_jam", "forage_berry", "dish_melon_ice"],
	"likes": ["forage_shell", "bug_butterfly", "dish_punch"],
	"hates": ["sludge", "potion_ember"],
	},
	# 사서 서하 — 메인 스토리 6에서 오래된 책을 보러 왔다가 정착한다
	"librarian": {"name": "서하", "birthday": [WINTER, 15], "romance": false,
	"lines": [
		"책장 넘기는 소리가 세상에서 제일 좋아요.",
		"기록은 거짓말을 하지 않아요. 사람이 잊을 뿐이죠.",
		"오래된 책은 함부로 펼치면 안 돼요. 종이가 바스러지거든요.",
		"읽고 싶은 책이 있으면 언제든 도서관으로 오세요.",
		"이 마을, 기록할 이야기가 많은 곳이에요.",
	],
	"season": {
		SPRING: ["봄볕에 책을 말리기 좋은 계절이에요.",
			"꽃가루가 책에 앉으면 얼룩이 져요. 조심조심."],
		SUMMER: ["습기가 책의 적이에요. 요즘은 매일 서가를 살펴요.",
			"여름엔 시원한 도서관이 최고죠?"],
		FALL: ["독서의 계절이라고들 하죠. 저는 사계절 다지만요.",
			"낙엽을 책갈피로 쓰면 근사해요."],
		WINTER: ["겨울밤엔 난로 곁에서 책 한 권. 그게 전부예요.",
			"눈 오는 소리를 들으며 책을 정리하고 있었어요."],
	},
	"weather": {
		WEATHER_RAIN: ["빗소리를 들으며 읽는 책이 제일 잘 읽혀요."],
		WEATHER_SNOW: ["눈이 오네요. 책 배달은 못 오겠어요."],
		WEATHER_STORM: ["폭풍이에요! 창문 틈으로 물이 새면 큰일인데..."],
		WEATHER_FOG: ["안개 낀 날엔 옛이야기가 잘 어울려요."],
		WEATHER_STAR: ["별이 쏟아지는 밤이에요. 천문 서적을 꺼내 볼까요."],
	},
	"morning": ["아침 공기 속에서 책 정리를 하면 하루가 개운해요."],
	"night": ["밤 독서는 좋지만... 눈 버려요. 일찍 쉬세요."],
	"aff30": ["당신이 오는 날은 책 정리가 빨리 끝나요. 이상하죠?",
		"좋아할 만한 책을 골라 뒀어요. 다음에 보여 드릴게요."],
	"aff70": ["오래된 책 복원이 끝나면... 제일 먼저 당신에게 읽어 줄게요.",
		"기록보다 오래 남는 건 사람의 마음인 것 같아요. 요즘 들어서요."],
	"loves": ["forage_relic", "dish_moon_tea", "bug_firefly"],
	"likes": ["forage_herb", "dish_garlic_bread", "flower_pot"],
	"hates": ["sludge", "forage_trash"],
	"secret50": "그 오래된 책 말이에요... 표지 안쪽에 글씨가 한 줄 숨어 있었어요.\n「기록은 남기는 자의 것」 — 당신 할아버지 필체와 닮았더라고요.",
	"secret100": "복원하다 알았어요. 그 책, 이 마을의 옛 기록이 맞아요.\n그리고 마지막 장은... 아직 쓰이지 않은 채 비어 있어요. 당신 몫인가 봐요.",
	},
	# ---- 일반 주민 (이사 신청 편지로 들어오는 생활형 캐릭터) ----
	"farmer": {"name": "순돌", "birthday": [SPRING, 22], "gender": "m", "romance": false,
	"lines": [
		"흙냄새가 좋아서 이 마을로 왔어. 자네 밭 구경해도 되나?",
		"작물은 주인 발소리를 듣고 자란다니까!",
		"올해는 뭘 심을 건가? 난 감자에 한 표.",
		"거름이야말로 농사의 반이지. 아무렴.",
		"해 뜨면 밭으로, 해 지면 집으로 — 이만한 삶이 없어.",
	],
	"loves": ["pumpkin", "dish_baked_potato", "gold_crop"],
	"likes": ["potato", "corn", "dish_soup"],
	"hates": ["sludge", "forage_trash"],
	},
	"foodie": {"name": "다미", "birthday": [SUMMER, 5], "gender": "f", "romance": false,
	"lines": [
		"이 마을 음식 소문 듣고 왔잖아~ 냄새부터 다르더라!",
		"오늘은 뭐 맛있는 거 만들었어? 냄새가 나는데?",
		"요리는 사랑이야. 진짜야. 먹어 보면 알아.",
		"만수네 가게 신상 레시피 봤어? 못 참지.",
		"맛있는 걸 먹을 때만큼은 세상이 다 예뻐 보여.",
	],
	"loves": ["dish_feast", "dish_berry_toast", "dish_golden_roast"],
	"likes": ["dish_bread", "dish_jam", "dish_punch"],
	"hates": ["sludge", "forage_trash"],
	},
	"angler": {"name": "강태", "birthday": [FALL, 9], "gender": "m", "romance": false, "greed": 1.2,
	"lines": [
		"물 좋다는 소문 듣고 낚싯대 하나 들고 왔지.",
		"어제 이만~한 놈을 놓쳤다니까? 진짜라니까?",
		"낚시는 기다림의 미학이야. 인생처럼.",
		"용식 씨랑은 라이벌이야. 본인은 모르지만.",
		"입질 없는 날엔 그냥 물멍만 해도 좋아.",
	],
	"loves": ["fish_golden", "dish_sashimi", "fish_king"],
	"likes": ["fish_crucian", "bait", "dish_grilled_fish"],
	"hates": ["sludge", "forage_trash"],
	},
	"miner": {"name": "바우", "birthday": [SPRING, 8], "gender": "m", "romance": false, "greed": 1.3,
	"lines": [
		"이 마을 굴, 돌이 살아 있다며? 곡괭이가 근질근질해.",
		"돌은 거짓말을 안 해. 두드린 만큼 내준다니까.",
		"동굴 깊은 데는 조심해. 반짝이는 건 다 이유가 있어.",
		"광석 냄새 맡는 데는 내 코가 제일이지. 킁킁.",
		"오늘도 한 짐 캐고 왔더니 어깨가 뻐근하구먼.",
	],
	"loves": ["gem", "forage_relic", "star_ore"],
	"likes": ["ore", "dish_baked_potato"],
	"hates": ["sludge", "forage_trash"],
	},
	"florist": {"name": "봄이", "birthday": [SPRING, 3], "gender": "f", "romance": false,
	"lines": [
		"이 마을은 바람에서 꽃냄새가 나요. 그래서 왔어요.",
		"창가에 화분 하나만 놓아도 집이 웃는답니다.",
		"나비가 앉는 꽃은 좋은 꽃이에요. 진짜예요.",
		"봄 꽃놀이 날엔 광장을 꽃으로 가득 채울 거예요!",
		"시든 꽃도 씨앗을 남겨요. 끝이 아니라는 거죠.",
	],
	"loves": ["flower_pot", "bug_butterfly"],
	"likes": ["forage_berry", "forage_herb"],
	"hates": ["sludge", "forage_trash"],
	},
	"carpenter": {"name": "덕구", "birthday": [SUMMER, 19], "gender": "m", "romance": false, "greed": 1.2,
	"lines": [
		"좋은 나무가 많은 마을이라 들었네. 대패질할 맛 나겠어.",
		"못 하나도 제자리에 박혀야 집이 백 년을 가지.",
		"삐걱대는 마루는 나한테 맡기게. 금방일세.",
		"나무는 베인 뒤에도 산다네 — 집이 되고, 의자가 되고.",
		"자네 집 문지방, 지나가다 보니 손 좀 봐야겠던데?",
	],
	"loves": ["dish_feast", "forage_relic"],
	"likes": ["nail", "hinge"],
	"hates": ["sludge", "forage_trash"],
	},
	"herbalist": {"name": "향이", "birthday": [SUMMER, 27], "gender": "f", "romance": false,
	"lines": [
		"산비탈 약초 냄새가 여기까지 나서 따라왔지 뭐예요.",
		"쓴맛 나는 풀일수록 몸에는 약이 된답니다.",
		"이슬 마르기 전에 캔 약초가 제일 좋아요.",
		"어디 결리는 데는 없어요? 안색이 좀...",
		"차 한 잔 우려 드릴까요? 마음이 가라앉아요.",
	],
	"loves": ["forage_herb", "dish_moon_tea"],
	"likes": ["forage_berry", "potion_energy"],
	"hates": ["sludge", "forage_trash"],
	},
	"painter": {"name": "청람", "birthday": [FALL, 21], "gender": "m", "romance": false, "greed": 1.2,
	"lines": [
		"이 마을의 노을빛... 물감으로는 도저히 못 만들겠더군요.",
		"바다 산호 색을 아세요? 세상에 그런 빨강은 또 없어요.",
		"오늘은 광장을 그렸어요. 사람 웃는 소리까지 담고 싶은데.",
		"그림은 눈으로 그리는 게 아니라 발로 그리는 거예요. 많이 걷죠.",
		"언젠가 이 마을 전부를 한 폭에 담을 겁니다.",
	],
	"loves": ["forage_coral", "gem"],
	"likes": ["forage_shell", "forage_glass"],
	"hates": ["sludge", "forage_trash"],
	},
	"musician": {"name": "한별", "birthday": [WINTER, 7], "gender": "f", "romance": false,
	"lines": [
		"파도 소리, 새소리, 망치 소리... 이 마을은 통째로 노래예요.",
		"달밤에 광장에서 한 곡 연주해도 될까요?",
		"반딧불이 나는 밤엔 느린 곡이 어울려요.",
		"축제 때는 제가 흥을 맡을게요. 기대해요!",
		"슬픈 날엔 노래가 약이에요. 언제든 불러 줘요.",
	],
	"loves": ["bug_firefly", "dish_punch"],
	"likes": ["forage_shell", "dish_bread"],
	"hates": ["sludge", "forage_trash"],
	},
	"weaver": {"name": "솜이", "birthday": [WINTER, 16], "gender": "f", "romance": false,
	"lines": [
		"베틀 놓을 조용한 방 한 칸이면 저는 충분해요.",
		"실 한 올 한 올이 모여 천이 되죠. 마을도 그래요.",
		"겨울이 오기 전에 다들 목도리 하나씩 떠 드릴게요.",
		"고운 천을 짜는 날엔 콧노래가 절로 나와요.",
		"당신 옷소매, 뜯어진 데 이리 줘 봐요. 금방 기워요.",
	],
	"loves": ["cloth", "dish_pie"],
	"likes": ["rope", "forage_berry"],
	"hates": ["sludge", "forage_trash"],
	},
	# ---- 특수 주민 (연구 노트 50%에서 해금 — 소문을 듣고 찾아온다) ----
	"alchemist": {"name": "묘연", "birthday": [WINTER, 24], "gender": "f", "romance": false,
	"lines": [
		"이 마을, 오래된 연구의 기운이 흐르고 있어요.",
		"당신의 노트... 그분의 연구를 잇고 있군요. 흥미로워요.",
		"재료 셋이 만나면 하나의 답이 나오죠. 연금술은 정직해요.",
		"달이 밝은 밤엔 좋은 물약이 나와요. 정말이에요.",
		"별의 가루, 유령의 숨결... 세상엔 아직 신비가 남아 있어요.",
	],
	"loves": ["potion_moon", "ghost_essence", "star_ore"],
	"likes": ["forage_herb", "gem", "potion_energy"],
	"hates": ["sludge", "forage_trash"],
	},

	# ---- 물소리 마을 (폭포골) ----
	#
	# 큰폭포 밑에 세 집이 모여 산다. 물레방아가 도는 소리가 하루 종일
	# 나서 마을 이름이 그렇게 붙었다. 물로 먹고사는 사람들이다.
	"miller": {"name": "수길", "birthday": [FALL, 9], "gender": "m", "romance": false,
	"lines": [
		"어이, 교진 마을에서 왔나? 여긴 물소리가 커서 말도 크게 해야 해!",
		"물방아는 사람이 안 밀어도 돌아. 물이 대신 일해 주는 거지.",
		"밀가루 묻은 손으로 악수해서 미안해. 여긴 늘 이래.",
		"폭포는 겨울에도 안 얼어. 저렇게 세게 떨어지는데 얼 새가 있나.",
		"우리 마을엔 우물이 없어. 필요가 없거든.",
	],
	"season": {
		SPRING: ["봄에 물이 제일 세. 방아가 너무 빨리 돌아서 붙잡아야 해."],
		SUMMER: ["여름엔 폭포 밑이 제일 시원해. 낮잠 자기 좋지."],
		FALL: ["가을이 방앗간 대목이야. 온 고장 곡식이 여기로 와."],
		WINTER: ["겨울엔 물보라가 얼어붙어서 바위가 유리처럼 돼."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오면 폭포가 두 배가 돼. 오늘은 가까이 가지 마."],
		WEATHER_STORM: ["폭풍 날엔 방아를 세워. 물이 너무 세면 축이 부러져."],
		WEATHER_FOG: ["안개 낀 날엔 폭포 소리만 나고 폭포가 안 보여. 그게 제일 무섭지."],
	},
	"morning": ["첫 방아는 해 뜰 때 돌려. 아침 물이 제일 힘차거든."],
	"night": ["이 시간에? 밤엔 물소리가 더 커. 잠이 안 올 거야."],
	"loves": ["wheat", "dish_rice_cake", "dish_bread"],
	"likes": ["potato", "corn", "dish_soup"],
	"hates": ["sludge", "forage_trash"],
	},
	"dyer": {"name": "윤슬", "birthday": [SPRING, 21], "gender": "f", "romance": false,
	"lines": [
		"이 폭포 물로 물을 들이면 색이 안 바래요. 왜인지는 나도 몰라요.",
		"쪽빛은 열두 번을 담가야 나와요. 한 번에 되는 색은 없어요.",
		"손이 파란 건 씻어도 안 지워져요. 이제는 그냥 두기로 했어요.",
		"물보라에 무지개가 설 때가 있어요. 그 색은 아직 못 냈어요.",
		"꽃도, 나뭇잎도, 흙도 다 색이 돼요. 안 되는 건 없어요.",
	],
	"season": {
		SPRING: ["봄꽃은 노란색이 제일 곱게 나와요."],
		SUMMER: ["여름엔 천이 금방 말라서 좋아요."],
		FALL: ["가을 잎으로 물들이면 그 잎 색이 그대로 나와요."],
		WINTER: ["겨울엔 물이 차서 손이 곱아요. 그래도 색은 겨울 게 제일 맑아요."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오는 날엔 천을 못 널어요. 오늘은 쉬는 날."],
		WEATHER_STAR: ["별 뜬 밤에 담근 천은... 기분 탓인지 색이 깊어요."],
	},
	"morning": ["아침 물이 제일 맑아요. 물들이기 좋은 시간이에요."],
	"night": ["밤엔 색이 제대로 안 보여서 일을 못 해요."],
	"loves": ["forage_dandelion", "bouquet", "cloth"],
	"likes": ["forage_berry", "forage_herb", "gem"],
	"hates": ["sludge", "forage_trash"],
	},
	"brook": {"name": "도담", "birthday": [SUMMER, 15], "gender": "m", "romance": false,
	"lines": [
		"나 폭포 뒤에 들어가 봤어! 아무한테도 말하면 안 돼.",
		"저 통나무, 내가 띄운 거야. 저기까지 흘러가는 데 사흘 걸렸어.",
		"물고기가 폭포를 거슬러 올라가는 거 봤어? 진짜야!",
		"할아버지가 물방아 만지지 말래. 근데 한 번만 타 보고 싶어.",
		"교진 마을은 여기서 얼마나 멀어? 나도 언젠가 가 볼 거야.",
	],
	"season": {
		SUMMER: ["여름엔 하루 종일 물속에 있어. 아무도 안 말려."],
		WINTER: ["겨울엔 물보라가 얼어서 바위가 반짝여. 그거 보러 가자!"],
	},
	"weather": {
		WEATHER_RAIN: ["비 오면 폭포가 우르르 소리를 내. 무섭기도 하고 좋기도 해."],
	},
	"morning": ["일찍 왔네! 나도 방금 나왔어."],
	"night": ["이 시간에 밖에 있으면 혼나. 나도 너도."],
	"loves": ["fish_sweetfish", "dish_grilled_fish", "forage_berry"],
	"likes": ["fish_crucian", "fish_bitterling", "egg"],
	"hates": ["sludge", "forage_trash"],
	},

	# ---- 나무그늘 마을 (큰나무 숲) ----
	#
	# 큰나무 그늘 안에 세 집. 나무를 베어 먹고사는 사람들인데,
	# 정작 큰나무만은 아무도 손대지 않는다.
	"sawyer": {"name": "동백", "birthday": [WINTER, 4], "gender": "m", "romance": false,
	"lines": [
		"큰나무? 저건 안 벤다. 우리 할아버지의 할아버지도 안 베셨어.",
		"나무는 겨울에 베야 해. 물이 안 올라와 있을 때라야 안 갈라지거든.",
		"이 숲에서 제일 오래된 건 저 나무고, 두 번째는 나야.",
		"톱은 밀 때가 아니라 당길 때 썰려. 힘으로 하는 게 아니야.",
		"나무 나이는 밑동을 보면 알아. 저 나무는 세어 볼 엄두도 안 나.",
	],
	"season": {
		SPRING: ["봄엔 안 벤다. 물이 올라와서 나무가 운다."],
		FALL: ["가을엔 장작을 쌓아 둬. 겨울이 길거든."],
		WINTER: ["겨울 나무가 제일 단단해. 지금이 일할 때야."],
	},
	"weather": {
		WEATHER_STORM: ["폭풍 날엔 숲에 안 들어가. 큰 가지가 떨어져."],
		WEATHER_SNOW: ["눈 덮인 숲은 조용해. 톱 소리만 나지."],
	},
	"morning": ["해 뜨자마자 나와야 하루가 길어."],
	"night": ["어두운 숲엔 들어가지 마. 길을 잃는 게 아니라 길이 없어져."],
	"loves": ["wood", "dish_soup", "dish_grilled_fish"],
	"likes": ["nail", "stone", "potato"],
	"hates": ["sludge", "forage_trash"],
	},
	"beekeep": {"name": "꿀비", "birthday": [SUMMER, 28], "gender": "f", "romance": false,
	"lines": [
		"큰나무 꽃이 필 때 뜬 꿀이 제일 좋아요. 일 년에 딱 며칠이에요.",
		"벌은 안 쏘아요. 무서워하지만 않으면.",
		"벌통에 귀를 대 보면 소리가 나요. 나무가 웅웅거리는 것 같아요.",
		"저 나무 하나에 벌이 몇 마린지 세어 본 적 있어요. 세다 말았지만요.",
		"꿀은 안 상해요. 백 년 지난 꿀도 꿀이에요.",
	],
	"season": {
		SPRING: ["봄엔 벌이 제일 바빠요. 나도 같이 바빠지죠."],
		SUMMER: ["여름 꿀은 진해요. 겨울 꿀은 맑고요."],
		FALL: ["가을엔 벌들 먹을 걸 남겨 둬야 해요. 다 뜨면 안 돼요."],
		WINTER: ["겨울엔 벌통을 싸매 줘요. 우리보다 벌이 먼저예요."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오면 벌이 안 나와요. 나도 안 나가고요."],
		WEATHER_FOG: ["안개 낀 날엔 벌이 길을 잃어요. 오늘은 벌통을 안 열어요."],
	},
	"morning": ["아침 이슬 걷히면 벌통을 열어요. 조금만 기다려요."],
	"night": ["밤엔 벌도 자요. 조용히 지나가 줘요."],
	"loves": ["dish_jam", "bouquet", "forage_berry"],
	"likes": ["strawberry", "melon", "forage_herb"],
	"hates": ["sludge", "forage_trash"],
	},
	"teller": {"name": "글샘", "birthday": [FALL, 30], "gender": "f", "romance": false,
	"lines": [
		"저 나무는 이 고장 이야기를 다 들었어요. 나는 그걸 받아 적을 뿐이고요.",
		"밤에 나무 밑에 앉아 있으면 잎이 무슨 말을 해요. 웃지 말아요.",
		"이야기는 사람이 짓는 게 아니에요. 있던 걸 찾아내는 거지.",
		"교진 마을 이야기도 들려줘요. 나는 여기서만 살아서요.",
		"오래 산 것 곁에 있으면 사람도 좀 길게 생각하게 돼요.",
	],
	"season": {
		SPRING: ["봄엔 잎이 새로 나요. 새 이야기가 시작되는 것 같죠."],
		FALL: ["가을엔 잎이 다 떨어져요. 이야기 하나가 끝나는 거예요."],
		WINTER: ["겨울 나무는 말이 없어요. 나도 그때는 듣기만 해요."],
	},
	"weather": {
		WEATHER_STAR: ["별 뜬 밤엔 잎 사이로 별이 보여요. 그 밤 이야기는 잘 써져요."],
		WEATHER_FOG: ["안개 낀 날엔 나무가 반쯤 사라져요. 그게 제일 예뻐요."],
	},
	"morning": ["아침에 쓴 글이 제일 정직해요."],
	"night": ["밤에는 이야기가 잘 와요. 오래 있다 가요."],
	"loves": ["old_book", "world_branch", "dish_tea"],
	"likes": ["forage_herb", "gem", "memory_piece"],
	"hates": ["sludge", "forage_trash"],
	},
	# ---- 파출소가 서면 부임하는 사람 (사회 S2b) ----
	# 읍에서 내려온 선임 순경. 말수 적고 하게체, 「규정」과 「밤길」로 말한다.
	# 야간 순찰(19~24시)을 도는 유일한 사람 — 밤은 유리하지만 안전하지 않다(헌법 §6.2)
	"officer_park": {"name": "박 순경", "birthday": [SPRING, 14], "gender": "m", "romance": false,
	"lines": [
		"규정은 사람을 묶으려고 있는 게 아닐세. 풀어 주려고 있는 거지.",
		"밤길은 내가 도네. 자네는 자게.",
		"이 마을은 문을 안 잠그더군. 그게 좋기도 하고, 걱정도 되고.",
		"읍에서 내려올 때 다들 한직이라 했지. 나는 이 자리가 좋네.",
		"잡는 게 일이 아닐세. 안 잡아도 되게 하는 게 일이지.",
	],
	"season": {
		SPRING: ["봄엔 낯선 얼굴이 늘어. 다 나쁜 사람은 아니지만 눈은 두어야지."],
		SUMMER: ["여름밤은 길어서 순찰도 길어지네."],
		FALL: ["추수철엔 창고 문단속을 이르고 다니지."],
		WINTER: ["눈 오는 밤은 발자국이 남아서 좋아. 내 일이 쉬워지거든."],
	},
	"weather": {
		WEATHER_RAIN: ["비 오는 밤엔 사고가 없네. 다들 집에 있으니까."],
		WEATHER_STORM: ["폭풍 치는 날은 문 두드리고 다니네. 다들 무사한지."],
		WEATHER_FOG: ["안개 낀 밤이 제일 싫어. 열 걸음 앞도 안 보여."],
	},
	"morning": ["밤새 조용했네. 그게 제일 좋은 보고지."],
	"night": ["이 시간에 밖이면 이유가 있어야 하네. 자네는 뭔가."],
	"aff30": ["자네가 밤에 돌아다녀도 나는 안 묻네. 믿으니까.",
		"순찰 돌다 자네 집 불 켜진 걸 보면 마음이 놓여."],
	"aff70": ["이 마을에서 내가 믿는 사람은 이장하고 자네뿐일세.",
		"언젠가 이 제복을 자네한테 넘길 날이 올지도 모르지."],
	"loves": ["dish_moon_tea", "dish_soup", "lamp"],
	"likes": ["dish_bread", "forage_berry", "egg"],
	"hates": ["sludge", "forage_trash"],
	"secret50": "읍에서 사람 하나를 못 잡았네. 잡았으면 살았을 사람이 하나 있었지.\n그 뒤로 밤에 잠을 못 자. 그래서 순찰을 도는 걸세.",
	"secret100": "자네 할아버지 이야기를 읍 서장한테 들었네. 옛날에 여기 순경이었다더군.\n이 제복은 그 양반이 입던 것과 같은 색일세.",
	},
}
var affinity := {"librarian": 0,
	"merchant": 0, "fisher": 0, "blacksmith": 0, "rancher": 0, "chief": 0,
	"postman": 0,
	"explorer": 0, "forest_mom": 0, "forest_girl": 0,
	"farmer": 0, "foodie": 0, "angler": 0, "miner": 0, "florist": 0,
	"carpenter": 0, "herbalist": 0, "painter": 0, "musician": 0,
	"weaver": 0, "alchemist": 0,
	# 고장의 작은 마을 사람들 — 교진 마을 밖에도 사람이 산다
	"miller": 0, "dyer": 0, "brook": 0,
	"sawyer": 0, "beekeep": 0, "teller": 0,
	# 사회(S2b) — 파출소가 서면 부임한다
	"officer_park": 0}
# 연애 — 꽃다발을 받아 주면 연인, 반지를 받아 주면 배우자. 각각 한 사람뿐이다.
const BOUQUET_PRICE := 800
const RING_PRICE := 12000
var dating := ""                # NPC id, 없으면 ""
var spouse := ""                # NPC id, 없으면 ""
var spouse_gift_day := 0        # 배우자가 마지막으로 아침 선물을 준 날
var gifted_today: Array[String] = []   # 오늘 선물한 상대 (하루 한 번)


# 오늘이 이 사람 생일인가
func is_birthday(npc_id: String) -> bool:
	var b: Array = NPCS[npc_id].get("birthday", [])
	return b.size() == 2 and int(b[0]) == season() and int(b[1]) == day_in_season()


# 며칠 뒤가 생일인가 (-1이면 이번 계절에 없다)
# "봄/여름"처럼 심을 수 있는 계절을 글로 (도감 설명용)
func season_list(crop_id: String) -> String:
	var names: Array[String] = []
	for sn in CROPS[crop_id].seasons:
		names.append(SEASON_NAMES[int(sn)])
	return "/".join(names)


func days_to_birthday(npc_id: String) -> int:
	var b: Array = NPCS[npc_id].get("birthday", [])
	if b.size() != 2 or int(b[0]) != season():
		return -1
	return int(b[1]) - day_in_season()


# 선물이 얼마나 오르는가. 표에 없으면 그냥 반갑다.
func gift_value(npc_id: String, item_id: String) -> int:
	var def: Dictionary = NPCS[npc_id]
	var base := 8
	if item_id in def.get("loves", []):
		base = 30
	elif item_id in def.get("likes", []):
		base = 18
	elif item_id in def.get("hates", []):
		base = -6
	if base > 0 and is_birthday(npc_id):
		base *= 3          # 생일에는 세 배
	return base


# NPC 성별 (m/f) — 호감도·결혼 이벤트가 참고한다
func npc_gender(npc_id: String) -> String:
	return str((NPCS.get(npc_id, {}) as Dictionary).get("gender", "m"))


# 지금 상황에 맞는 대사를 하나 고른다.
#
# 좁은 갈래(연애 > 호감도 > 생일 > 날씨 > 시간대 > 계절)일수록 먼저 보고,
# 거기 있는 것과 기본 대사를 **함께** 후보에 넣는다. 좁은 것만 쓰면
# 같은 계절 내내 같은 말을 하고, 기본만 쓰면 갈래를 나눈 뜻이 없어진다.
func npc_line(npc_id: String) -> String:
	var def: Dictionary = NPCS[npc_id]
	var pool: Array = []
	if spouse == npc_id:
		pool += def.get("married", [])
	elif dating == npc_id:
		pool += def.get("dating", [])
	var aff := int(affinity[npc_id])
	if aff >= 70:
		pool += def.get("aff70", [])
	if aff >= 30:
		pool += def.get("aff30", [])
	if is_birthday(npc_id):
		pool.append("오늘 내 생일인 거... 알고 있었어?")
	var w: Dictionary = def.get("weather", {})
	if w.has(weather_today()):
		pool += w[weather_today()]
	var h := minutes / 60.0
	if h < 9.0:
		pool += def.get("morning", [])
	elif h >= 19.0:
		pool += def.get("night", [])
	var sn: Dictionary = def.get("season", {})
	if sn.has(season()):
		pool += sn[season()]
	pool += def.lines
	# 호칭 토큰 — 새로 쓰는 대사는 어디서든 {title} {name} 을 쓸 수 있다(NPCS 리터럴 안엔 중괄호가 없다)
	return str(pool[randi() % pool.size()]).format({"title": player_title(npc_id).text, "name": player_name})
# {crop, qty, reward, accepted}
var quest := {}

# ---- 튜토리얼 / 도구 해금 ----
#
# 두 갈래로 나뉜다:
#   · 앞 네 개(till~harvest)는 **메인 스토리 2** — 이장에게 호미를 받고
#     밭을 일구는 본 줄기다.
#   · 나머지는 **마을 생활 안내** — 선택 서브퀘스트. 안 해도 메인은
#     진행되고, 도구도 안내에 묶여 잠기지 않는다.
# 순서: [플래그, 목표 문구]. 순서를 어겨도 막히지 않는 체크리스트 방식.
const STORY2_FLAGS := ["till", "plant", "water", "harvest"]
# 첫 살림을 배우는 줄기 — 스토리 3(마을 생활 안내)이 열리기 전에도
# 이 다섯은 차례로 이어진다. 수확에서 끊기지 않고 요리까지 간다.
const FARM_CHAIN_FLAGS := ["till", "plant", "water", "harvest", "cook"]
const TUTORIAL_ORDER := [
	["till", "호미를 슬롯에 장착해 풀밭을 갈자"],
	["plant", "밭에 씨앗을 심자"],
	["water", "물뿌리개로 물을 주자"],
	["harvest", "다 자란 작물을 거두자 — 도구 없이 바로 딸 수 있다"],
	["cook", "집 안 조리대에서 요리를 해 보자"],
	["board", "의뢰 게시판에서 오늘의 의뢰를 살펴보자"],
	["moved", "방향키/WASD로 움직여보자"],
	["map", "지도(M)를 열어 집과 마을 위치를 확인하자"],
	["quest", "퀘스트 창(Q)을 열어 할 일을 확인하자"],
	["note", "할아버지의 연구 노트(N)를 펼쳐보자"],
	["chop", "도끼로 나무를 베어 목재를 모으자"],
	["slept", "침대에서 자고 다음 날을 맞자"],
	["mine", "곡괭이로 돌을 캐서 석재를 모으자"],
	["fish", "낚시터에서 물고기를 낚자"],
	["shop", "마을 잡화점에 들어가 씨앗을 사 보자"],
]
# 목표 달성 시 해금되는 도구 — 메인 줄기(밭 갈기)에만 묶는다.
# 도끼·곡괭이는 스토리 1에서 이미 받았고, 나머지는 첫 수확에 열린다.
# 스프링클러는 여기서 빠졌다 — 농사 Lv3부터 잡화점에서 레시피를 판다.
# (마을 생활 안내는 선택이므로 도구를 잠그지 않는다)
const TUTORIAL_UNLOCKS := {
	"till": ["seed"],
	"plant": ["water"],
	# 낚싯대는 여기서 주지 않는다 — 용식과 바닷길을 연 뒤에야 손에 들어온다
	# 울타리는 여기서 빠졌다 — **목재를 손에 넣으면** 잡화점이 레시피를 들여놓는다
	# (나무 한 그루 베어 본 적 없는 사람에게 울타리부터 쥐여 줄 이유가 없다)
	"harvest": ["axe", "pickaxe"],
}
# 수확은 도구 없이 되므로 「바구니(hand)」 도구는 없앴다
# 돌 창·돌 검은 제작대에서 만들어 해금하는 무기다 (레시피: 이장/추후 서브퀘)
const ALL_TOOLS := ["hoe", "water", "seed", "axe", "pickaxe", "fence", "sprinkler",
	"rod", "spear", "sword"]

# 튜토리얼 목표 달성 보상 (도구 해금과 별개)
const TUTORIAL_REWARDS := {
	"moved": {"money": 25},
	"map": {"money": 25},
	"quest": {"money": 25},
	"note": {"money": 25},   # 씨앗을 그냥 주지 않는다 — 상점에서 사는 게 시작이다
	"till": {"money": 15},
	"plant": {"money": 25},
	"water": {"money": 50},
	"harvest": {"money": 50},
	"board": {"money": 50},
	"chop": {"wood": 5},
	"slept": {"money": 75},
	"mine": {"stone": 5},
	"fish": {},          # 낚시는 돈을 주지 않는다 — 물고기는 팔아서 값을 받는다
	"shop": {"money": 150},
}

# 도구 슬롯(빠른 사용 슬롯) 9칸: 1~9 숫자키로 선택 — 가방에서 자유 배치
const TOOL_SLOT_COUNT := 9


static func default_tool_slots() -> Array:
	var slots: Array = ALL_TOOLS.duplicate()
	slots.resize(TOOL_SLOT_COUNT)   # 도구가 슬롯보다 많으면 뒤(무기)는 직접 장착한다
	for i in slots.size():
		if slots[i] == null:
			slots[i] = ""
	return slots


var tool_slots: Array = default_tool_slots()
# 슬롯은 자유 배치이므로 고정 번호를 붙이지 않는다 (가방에서 장착 후 숫자키 선택)
const TOOL_KOR := {
	"hoe": "호미", "water": "물뿌리개", "seed": "씨앗",
	"axe": "도끼", "pickaxe": "곡괭이", "fence": "울타리",
	"sprinkler": "스프링클러", "rod": "낚싯대",
	"spear": "돌 창", "sword": "돌 검",
}
var tutorial := {"active": false}
# 마을 생활 안내 시작 여부 — 메인 스토리 3(이주 편지)이 시작될 때 함께 열린다.
# 그 전에는 안내 목표가 퀘스트 창에도, 트래커에도 나오지 않는다.
var guide_active := false
var unlocked_tools: Array = ALL_TOOLS.duplicate()


func is_tool_unlocked(id: String) -> bool:
	return unlocked_tools.has(id)


func unlock_all_tools() -> void:
	unlocked_tools = ALL_TOOLS.duplicate()


# ---- 개발/테스트용: 가방을 통째로 채운다 (DEV_MODE에서 F10) ----
# 장터·요리·조합처럼 「물건이 많아야 볼 수 있는 것」을 손으로 모으지 않고
# 바로 확인하려고 쓴다. 도구도 전부 열고 품질별 수확물까지 채운다.
func dev_fill_stock(n: int = DEV_STOCK) -> void:
	money = maxi(money, DEV_MONEY)
	wood = n
	stone = n
	for id: String in CROP_IDS:
		seeds[id] = n
		produce[id] = n
		produce_silver[id] = int(n / 3.0)   # 은빛·금빛도 섞어 둔다 (품질별 확인용)
		produce_gold[id] = int(n / 3.0)
	for id: String in ITEM_IDS:
		items[id] = n
	unlock_all_tools()
	# 도감(discover)은 일부러 건드리지 않는다 — 컬렉션 보상과 영구 버프가
	# 한꺼번에 터져서 정작 보려던 것을 덮어 버린다.


# ---- 사회 (S1) ----
#
# 「불리는 사람」 — 내가 무엇으로 불리는가는 내가 고르지 않는다. 자리(seats)·실적·기억
# (memories)·평판이 정하고, 마을 사람의 입(call_opener)으로 나온다(헌법 §0.4). 여기에는
# 표(기관·직업·호칭 대사)와 상태(me·세계 키)와 순수 함수만 둔다 — 대화창·방·NPC 노드를
# 만지는 행동(채용·근무·소매치기·회의)은 society.gd 의 몫이다.
#
# 알림은 다음날 아침 결산 한 줄(society_note), 돈은 창구 앞 E 로만 — 즉시 토스트는 없다.

# ---- 사회: 표 ----

# 기관 6 — room·head 는 shop_room.ROOMS 의 키·keeper 와 1:1. ranks 는 [아래, 위]이고
# 플레이어는 아래 자리(player_max)까지만 오른다 — 맨 윗자리는 손글 NPC 고정(헌법 §0.2).
# skill/books/job 은 JOBS 와 같은 값(채용 조건, D6).
const INSTITUTIONS := {
	"general": {
		"name": "잡화점",
		"region": "kyojin",
		"room": "general",
		"head": "merchant",
		"ranks": ["clerk", "owner"],
		"player_max": "clerk",
		"skill": "farm",
		"books": 0,
		"job": "general_clerk",
		"slice": 1,
	},
	"smith": {
		"name": "대장간",
		"region": "kyojin",
		"room": "smith",
		"head": "blacksmith",
		"ranks": ["apprentice", "owner"],
		"player_max": "apprentice",
		"skill": "mine",
		"books": 0,
		"job": "blacksmith_apprentice",
		"slice": 1,
	},
	"ranch": {
		"name": "목장 상회",
		"region": "kyojin",
		"room": "ranch",
		"head": "rancher",
		"ranks": ["hand", "owner"],
		"player_max": "hand",
		"skill": "ranch",
		"books": 0,
		"job": "ranch_hand",
		"slice": 1,
	},
	"fish": {
		"name": "수산시장",
		"region": "kyojin",
		"room": "fish",
		"head": "fisher",
		"ranks": ["deckhand", "owner"],
		"player_max": "deckhand",
		"skill": "fish",
		"books": 0,
		"job": "deckhand",
		"slice": 1,
	},
	"library": {
		"name": "도서관",
		"region": "kyojin",
		"room": "library",
		"head": "librarian",
		"ranks": ["aide", "head"],
		"player_max": "aide",
		"skill": "",
		"books": 3,
		"job": "library_aide",
		"slice": 1,
	},
	"post": {
		"name": "우체국",
		"region": "kyojin",
		"room": "post",
		"head": "postman",
		"ranks": ["carrier", "head"],
		"player_max": "carrier",
		"skill": "",
		"books": 0,
		"job": "mail_carrier",
		"slice": 1,
	},
	# 면사무소(S2) — 회관 창구. 이장이 면장을 겸한다(읍이 열리기 전까지).
	# 아래 자리가 둘(서기·감시원)이라 ranks 가 셋이다 — seat_rows 는 마지막 랭크만 주인으로 시드한다.
	# job 은 「일자리 이야기」의 기본값이고, jobs 가 이 창구에서 들어갈 수 있는 직업 전부다
	# 파출소(S2b) — 여관 부지(inn)를 재명명했다. 선임 박 순경이 주인, 순경 한 자리
	"police_box": {
		"name": "파출소",
		"region": "kyojin",
		"room": "inn",
		"head": "officer_park",
		"ranks": ["constable", "senior"],
		"player_max": "constable",
		"skill": "combat",
		"books": 0,
		"job": "constable",
		"slice": 2,
	},
	"township": {
		"name": "면사무소",
		"region": "kyojin",
		"room": "hall",
		"head": "chief",
		"ranks": ["clerk", "ranger", "head"],
		"player_max": "ranger",
		"skill": "",
		"books": 0,
		"job": "township_clerk",
		"jobs": ["township_clerk", "forest_ranger"],
		"slice": 2,
	},
	# 마을 자치회(S3c) — 부녀회장·청년회장·서당 훈장. 명예직(무보수), 회관 창구에서 이장이 추천한다.
	# 위에는 언제나 이장(head) — 자리 셋이라 ranks 가 넷이다
	"assoc": {
		"name": "마을 자치회",
		"region": "kyojin",
		"room": "hall",
		"head": "chief",
		"ranks": ["women_head", "youth_head", "tutor", "head"],
		"player_max": "tutor",
		"skill": "",
		"books": 0,
		"job": "youth_head",
		"jobs": ["women_head", "youth_head", "village_tutor"],
		"slice": 3,
	},
	# 고장 점원 넷(S3c) — 방(room)이 없다: 「일자리 이야기」도 「근무」도 그 사람 앞 대화다.
	# 고장 사람은 첫 인사 목록에 없어도 늘 제자리에 있으므로 can_hire_job 이 따로 연다
	"mill": {
		"name": "물레방앗간",
		"region": "brookside",
		"room": "",
		"head": "miller",
		"ranks": ["hand", "owner"],
		"player_max": "hand",
		"skill": "farm",
		"books": 0,
		"job": "miller_hand",
		"slice": 3,
	},
	"dyeworks": {
		"name": "물들이터",
		"region": "brookside",
		"room": "",
		"head": "dyer",
		"ranks": ["hand", "owner"],
		"player_max": "hand",
		"skill": "beach",
		"books": 0,
		"job": "dyer_hand",
		"slice": 3,
	},
	"sawmill": {
		"name": "톱질터",
		"region": "treeshade",
		"room": "",
		"head": "sawyer",
		"ranks": ["hand", "owner"],
		"player_max": "hand",
		"skill": "forest",
		"books": 0,
		"job": "sawyer_hand",
		"slice": 3,
	},
	"loom": {
		"name": "솜이네 베틀",
		"region": "kyojin",
		"room": "",
		"head": "weaver",
		"ranks": ["hand", "owner"],
		"player_max": "hand",
		"skill": "farm",
		"books": 0,
		"job": "weaver_hand",
		"slice": 3,
	},
}

# 직업 14 — 점원 6(kind "clerk") + 자유직 8(kind "free").
#   calls       호칭 text 3단(player_title 이 쓴다) — stranger(근속 < known_at) / known({ho}) / master(호감 70)
#   boss_calls  주인의 첫마디(call_opener 가 nid == boss 일 때 NPC_CALLS 보다 먼저 본다)
#   hire        채용·사직·해고 대사(society.open_job_talk/resign 이 쓴다)
#   loop        근무 미니루프 — [{customer, setup, choices:[[라벨, "화자: 반응", 주인 aff ±1|0]×3]}×4],
#               오늘 손님은 loop[(day + INSTITUTIONS.keys().find(inst)) % 4]. 정답은 없다(perf·봉급 동일),
#               주인과의 사이만 조금 오르내린다(헌법 §7.3 「직장 정치」).
#   wage_lines  봉급 창구 대사 pay / nothing(적립 0) / not_yet(봉급날 전)
#   sees        그 직업만 보는 것 — what 은 stats_ui 툴팁, line 은 master 첫 근무날 한 번
#   자유직은 문턱·호칭이 FREE_TITLES 에 있다(표가 진실 — 조립하지 않는다).
const JOBS := {
	"general_clerk": {
		"name": "잡화점 점원",
		"kind": "clerk",
		"inst": "general",
		"rank": "clerk",
		"boss": "merchant",
		"wage": 80,
		"known_at": 14,
		"skill": "farm",
		"books": 0,
		"slice": 1,
		"calls": {
			"stranger": "만수네 새 사람",
			"known": "점원 {ho}",
			"master": "우리 점원",
		},
		"boss_calls": {
			"stranger": [
				"어, {name}! 새 사람은 계산대 서기 전에 손부터 씻고. 알았지?",
				"새 사람 왔네. 오늘도 문 열기 전에 온 거야? 기특하네.",
			],
			"known": [
				"어, {title} 왔네! 오늘 계산대는 너한테 맡기고 노점 다녀올게.",
				"{title}, 어제 손님이 너 칭찬하더라. 나보다 낫대. 흥.",
			],
			"master": [
				"우리 점원 왔다! 장부 숫자 보다 졸고 있었는데 이제 살았어.",
				"우리 점원 없으면 이 가게 못 굴러. 진짜야, 이건 비밀 아니야.",
			],
		},
		"hire": {
			"ask": "만수, 일자리 이야기 좀 하자. 여기 계산대에 나도 서 보고 싶어.",
			"refuse_aff": "계산대는 아무한테나 안 맡겨. 우리 좀 더 친해지고 얘기하자.",
			"refuse_skill": "씨앗 파는 손은 밭을 알아야 해. 농사가 좀 더 손에 익으면 다시 와.",
			"refuse_busy": "이미 다른 데서 일하잖아. 한 몸으로 두 자리는 못 서. 안 돼.",
			"accept": "좋아, 내일 아침 나와. 아홉 시 문 열기 전에! 늦으면 국물도 없어.",
			"first_day": "첫날이네. 손님 오면 웃고, 값은 표대로. 깎는 건 내 일이야.",
			"resign_ask": "만수, 나 이제 가게 일은 그만두려고. 그동안 고마웠어.",
			"resign_reply": "...그래. 계산대 자리는 비워 둘게. 손님으로는 꼭 와. 알았지?",
			"fired": "이레를 안 나왔어. 나 혼자 문 열고 닫았고. 이제 안 나와도 돼.",
		},
		"loop": [
			{
				"customer": "farmer",
				"setup": "순돌이 또 감자 씨앗을 찾는다. 선반엔 마지막 두 봉지뿐이다.",
				"choices": [
					[
						"두 봉 다 값대로 판다",
						"만수: 다 나갔어? 내일 올 사람 몫이... 뭐, 판 건 판 거지.",
						0,
					],
					[
						"한 봉만 팔고 한 봉은 남긴다",
						"순돌: 한 봉? 밭 절반은 뭘로 채우라고... 다음엔 넉넉히 들이게.",
						-1,
					],
					[
						"감자는 한 봉, 옆의 옥수수 씨앗을 권한다",
						"순돌: 옥수수라... 자네 밭 구경한 값으로 한 봉 사 보지, 아무렴.",
						1,
					],
				],
			},
			{
				"customer": "foodie",
				"setup": "다미가 신상 레시피 두루마리 앞에서 돈주머니를 세 번째 센다.",
				"choices": [
					[
						"값대로 받는다",
						"다미: ...다음 주에 올게. 그때까지 안 팔면 안 돼? 응?",
						0,
					],
					[
						"조금 깎아 준다",
						"만수: 또 깎았어? 레시피는 깎아 파는 물건이 아니라고.",
						-1,
					],
					[
						"만들면 만수한테 한 입 가져오라고 한다",
						"다미: 그럼 진짜 사야겠네! 만수 몫은 제일 예쁘게 구울게.",
						1,
					],
				],
			},
			{
				"customer": "angler",
				"setup": "강태가 미끼를 통째로 달라 한다. 용식 씨보다 먼저 쓸 거라며.",
				"choices": [
					[
						"달라는 대로 통째로 판다",
						"강태: 고맙네! 오늘은 용식 씨 코를 납작하게 해 주지, 진짜로.",
						0,
					],
					[
						"반만 팔고 나머지는 용식 몫으로 남긴다",
						"만수: 용식이 몫 남겨 뒀어? 단골 챙기는 거, 그게 장사야.",
						1,
					],
					[
						"어제 놓친 고기 얘기를 끝까지 들어 준다",
						"만수: 손님 하나 붙잡고 한 시간? 뒤에 줄 선 거 안 보여?",
						-1,
					],
				],
			},
			{
				"customer": "forest_mom",
				"setup": "연화가 처음 가게에 내려왔다. 솔이 줄 것을 찾는데 말이 없다.",
				"choices": [
					["제철 씨앗을 이것저것 늘어놓고 설명한다", "연화: ...고마워요. 다음에 다시 올게요.", -1],
					[
						"말을 걸지 않고 고를 때까지 기다린다",
						"연화: ...이 딸기 씨앗으로 할게요. 솔이가 좋아할 것 같아서.",
						1,
					],
					[
						"약초잎 씨앗을 권한다",
						"연화: 약초는 숲에 많아요. ...마음은 고마워요.",
						0,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "자, 이번 주 몫. 세어 봐. 나 숫자 약한 거 알지?",
			"nothing": "받을 거? 근무한 날이 없는데 뭘 줘. 내일부터 나와.",
			"not_yet": "봉급날은 아직이야. 장부에 그렇게 적혀 있어... 아마.",
		},
		"sees": {
			"what": "만수의 재고 메모 — 선반에서 곧 떨어질 씨앗·레시피와 남은 봉지 수",
			"line": "이거 내 재고 메모야. 뭐가 곧 떨어질지 너도 알아 둬. 우리 점원이니까.",
		},
		"absent_warn": "사흘이나 안 나왔어. 무슨 일 있는 건 아니지? ...내일은 와.",
	},
	"blacksmith_apprentice": {
		"name": "대장간 도제",
		"kind": "clerk",
		"inst": "smith",
		"rank": "apprentice",
		"boss": "blacksmith",
		"wage": 80,
		"known_at": 14,
		"skill": "mine",
		"books": 0,
		"slice": 1,
		"calls": {
			"stranger": "대장간 {ho}",
			"known": "무쇠네 도제",
			"master": "우리 젊은 대장",
		},
		"boss_calls": {
			"stranger": [
				"어이, 대장간 {ho}. 풀무부터 밟게. 불이 아직 덜 달았어.",
				"대장간 {ho} 왔나. 오늘은 보기만 하게. 손은 나중이야.",
			],
			"known": [
				"우리 도제 왔군. 오늘은 자네가 먼저 불을 봐. 난 좀 앉지.",
				"도제, 어제 벼린 거 식었나 보게. 손 말고 눈으로.",
			],
			"master": [
				"우리 젊은 대장 왔나. 화덕은 이제 자네한테 맡겨도 되겠어.",
				"젊은 대장, 오늘 망치 소리는 자네가 내게. 내 귀는 좀 쉬지.",
			],
		},
		"hire": {
			"ask": "어르신, 여기서 일 좀 배우고 싶습니다. 풀무라도 밟을게요.",
			"refuse_aff": "자네 손을 아직 못 봤네. 광석이나 몇 번 더 가져와 보게.",
			"refuse_skill": "채광이 아직 서툴러. 광석도 못 캐는 손에 망치는 못 줘.",
			"refuse_busy": "딴 집 일을 하면서? 불은 한눈파는 손부터 데네. 하나만 하게.",
			"accept": "…좋아. 내일 아홉 시에 나오게. 풀무는 불 달기 전에 밟는 거야.",
			"first_day": "왔군. 오늘은 두드리지 말고 보게. 쇠가 언제 붉어지는지부터.",
			"resign_ask": "어르신, 저 이제 그만두려고요. 그동안 고마웠습니다.",
			"resign_reply": "…그래. 배운 건 손에 남아. 가게. 화덕은 또 나 혼자 보지 뭐.",
			"fired": "이레째군. 불은 하루만 비워도 죽어. 자네 자린 이제 없네.",
		},
		"loop": [
			{
				"customer": "miner",
				"setup": "바우가 이 나간 곡괭이를 등 뒤에 감추고 온다. 무쇠 영감한텐 비밀로 해 달란다.",
				"choices": [
					[
						"아무 말 없이 숫돌에 갈아서 돌려보낸다",
						"무쇠: 숫돌이 젖어 있군. 누가 왔다 갔나. …됐네, 말 안 해도 알아.",
						-1,
					],
					[
						"숫돌을 내주고 이 안 나가게 가는 법을 보여 준다",
						"무쇠: 숫돌 자국이 둘이야. 가는 법을 가르쳤나. …잘했어.",
						1,
					],
					[
						"광장에 가서 무쇠 어른을 모셔 온다",
						"무쇠: 이 나간 곡괭이가 죄인가. 바우, 앉게. 다음엔 그냥 오게.",
						0,
					],
				],
			},
			{
				"customer": "carpenter",
				"setup": "덕구가 굽은 못 한 줌을 계산대에 쏟는다. 이걸로 집을 지으라고 판 거냐고.",
				"choices": [
					[
						"말없이 새 못으로 바꿔 준다",
						"무쇠: 왜 굽었는지는 물었나? 안 물었으면 다음 못도 굽어.",
						0,
					],
					[
						"못 탓이 아니라 망치질 탓이라고 받아친다",
						"덕구: 못 탓이 아니면 내 팔 탓인가. 이 집 못은 다신 안 사네.",
						-1,
					],
					[
						"못을 하나씩 살펴보고 담금질이 덜 됐다고 말한다",
						"무쇠: 내 손이 틀린 걸 자네가 봤군. 쇠는 정직해. 다시 벼리지.",
						1,
					],
				],
			},
			{
				"customer": "explorer",
				"setup": "재민이 동굴 4층 얘기를 하며 무쇠 검을 달란다. 돈은 나중에 주겠다고.",
				"choices": [
					[
						"외상으로 내준다",
						"무쇠: 외상? 화덕은 외상을 몰라. 그 검 도로 걸어 두게. 값은 내 앞에서 받지.",
						-1,
					],
					[
						"값을 그대로 읽어 준다 — 1,200G에 광석 열, 석재 열",
						"재민: 천이백에 광석 열… 지도 귀퉁이에 적어 둘게. 다음에 올게!",
						0,
					],
					[
						"돈은 됐고 4층 광석을 캐 오면 그걸로 벼려 주겠다고 한다",
						"무쇠: 깊은 데 광석으로 값을 친다? 내 방식이군. 누가 가르쳤나.",
						1,
					],
				],
			},
			{
				"customer": "farmer",
				"setup": "순돌이 호미가 말을 안 듣는다며 새로 벼려 달란다. 날을 보니 그냥 무뎌졌을 뿐이다.",
				"choices": [
					[
						"달라는 대로 새로 벼리는 값을 부른다",
						"무쇠: 무딘 날을 벼린다고 값을 받았나. 화덕은 그런 걸 다 알아.",
						-1,
					],
					[
						"숫돌에 갈아 주고 값은 안 받는다",
						"무쇠: 벼릴 것도 없는 걸 벼리지 않았군. 그게 쇠 볼 줄 아는 눈이야.",
						1,
					],
					[
						"무쇠 어른이 오실 때까지 기다리라고 한다",
						"순돌: 두 시간을? 밭이 날 기다리는데… 내일 다시 오지 뭐.",
						0,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "받게. 두드린 만큼이야. 쇠도 사람도 그건 같아.",
			"nothing": "줄 게 없네. 화덕 앞에 서지도 않은 손에 뭘 쥐여 주나.",
			"not_yet": "아직 이레가 안 됐어. 쇠도 때 되기 전엔 안 꺼내네.",
		},
		"sees": {
			"what": "화덕 옆 널빤지에 숯으로 적힌 순서표 — 다음에 누구의 무슨 연장이 불에 오르는지 보인다.",
			"line": "손주한테나 보여 줄 거였는데… 저 널빤지, 이제 자네도 읽게. 다음 차례가 다 적혔어.",
		},
		"absent_warn": "사흘째 안 보이는군. 불은 사흘이면 식어. 사람도 그래.",
	},
	"ranch_hand": {
		"name": "목장 일꾼",
		"kind": "clerk",
		"inst": "ranch",
		"rank": "hand",
		"boss": "rancher",
		"wage": 80,
		"known_at": 14,
		"skill": "ranch",
		"books": 0,
		"slice": 1,
		"calls": {
			"stranger": "새 일꾼",
			"known": "보라네 일꾼",
			"master": "우리 목장 일꾼",
		},
		"boss_calls": {
			"stranger": [
				"어, 새 일꾼. 애들 이름 아직 못 외웠지? 오늘 안에 외워.",
				"새로 온 {ho}, 닭장 문은 두 번 돌려야 잠겨. 어제 열려 있었어.",
			],
			"known": [
				"{name}, 왔어? 애들이 아까부터 문 쪽만 보더라.",
				"{name}, 이제 진짜 일꾼 다 됐네. 소가 네 발소리를 알아.",
			],
			"master": [
				"우리 목장 일꾼 왔다. 애들아, 오늘도 잘 부탁해.",
				"우리 일꾼 없으면 이제 나 혼자 젖도 못 짜. 진짜야.",
			],
		},
		"hire": {
			"ask": "보라, 나 여기서 일해 보고 싶어. 일꾼 자리 아직 비었어?",
			"refuse_aff": "애들은 낯선 손을 알아봐. 우리부터 좀 더 친해지고 얘기하자.",
			"refuse_skill": "목장 손이 아직 서툴러. 네 닭부터 매일 쓰다듬고 다시 와.",
			"refuse_busy": "다른 데서 일하잖아? 애들은 반쪽 마음으론 못 키워. 거기 끝나면 와.",
			"accept": "좋아! 내일 아홉 시에 나와. 아침 젖은 내가 짜 둘게, 애들 인사부터 해.",
			"first_day": "첫날이지? 애들한테 인사부터. 이름 부르면 돌아봐, 진짜야.",
			"resign_ask": "보라, 일꾼 일은 여기까지 하려고. 애들한테는 내가 말할게.",
			"resign_reply": "...애들이 서운해하겠다. 가끔 들러. 문은 안 잠가 둘게.",
			"fired": "일주일이야. 애들은 매일 기다렸는데 넌 안 왔어. 그만하자.",
		},
		"loop": [
			{
				"customer": "postman",
				"setup": "우체부 아저씨가 빈 병을 들고 왔다. 「우유 한 병 있나? 오늘은 길이 멀구먼.」",
				"choices": [
					[
						"아침에 짠 걸로 골라 드린다",
						"보라: 아침 것 알아보는 거 봐. 애들 마음까지 판 거야.",
						1,
					],
					[
						"계란말이 좋아하시니 달걀도 권한다",
						"우체부: 계란말이? 그거 좋지. 두 알 더 주게. 보라가 웃는다.",
						0,
					],
					[
						"어제 남은 우유를 싸게 드린다",
						"보라: 어제 거를 왜 줘? 애들이 애써 낸 건데 아무렇게나 팔지 마.",
						-1,
					],
				],
			},
			{
				"customer": "forest_girl",
				"setup": "솔이가 엄마 손을 잡고 왔다. 「병아리… 만져 봐도 돼요? 도망갈까요?」",
				"choices": [
					[
						"솔이 손을 잡고 천천히 같이 다가간다",
						"보라: 천천히, 그거야. 애들은 급한 손을 제일 무서워해.",
						1,
					],
					[
						"병아리를 안아다 솔이 품에 넣어 준다",
						"보라: 번쩍 안으면 애가 놀라잖아. 솔이 손이 먼저 가야지.",
						-1,
					],
					[
						"모이를 쥐여 주고 기다리게 한다",
						"병아리가 모이만 먹고 갔다. 보라: 다음엔 더 가까이 올 거야.",
						0,
					],
				],
			},
			{
				"customer": "merchant",
				"setup": "만수가 수레를 끌고 왔다. 「우유 열 병! 선반이 텅 비었어. 좀 싸게 안 돼?」",
				"choices": [
					[
						"오늘 나온 여섯 병만 제값에 준다",
						"보라: 있는 만큼만. 애들한테 더 짜 내라곤 못 하지.",
						1,
					],
					[
						"내일 것까지 약속하고 열 병에 값을 깎는다",
						"보라: 내일 거까지 약속했어? 소한테는 물어봤고?",
						-1,
					],
					[
						"제값에 있는 만큼, 대신 달걀 한 판을 덤으로",
						"만수: 덤이면 됐어! 보라: 뭐… 닭들이 많이 낳긴 했어.",
						0,
					],
				],
			},
			{
				"customer": "chief",
				"setup": "이장이 왔다. 「추수 잔치에 쓸 닭 한 마리, 값이 얼마나 되나.」",
				"choices": [
					[
						"잔치상은 달걀과 우유로 차리자고 권한다",
						"보라: 달걀 한 판이면 잔치상 충분해. 애들은 못 보내.",
						1,
					],
					[
						"제일 살찐 놈으로 골라 드린다",
						"보라: ...살찐 놈? 걔 이름 복실이야. 오늘은 그만 나가 있어.",
						-1,
					],
					[
						"값만 알려 드리고 보라한테 직접 물어보시라 한다",
						"이장: 그러지. 보라: 흠, 나한테 넘겼네. 뭐, 틀린 건 아니야.",
						0,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "자, 이번 주 품삯. 애들이 낸 거 반, 네 손이 낸 거 반이야.",
			"nothing": "이번 주는 줄 게 없는데? 나온 날이 없잖아. 애들도 몰라보겠다.",
			"not_yet": "봉급날 아직이야. 이레 채우면 줄게. 애들처럼 매일 오면 금방이야.",
		},
		"sees": {
			"what": "보라의 가축 장부 — 누가 언제 닭·소를 사 갔는지, 지금 몇 마리 있는지 보인다.",
			"line": "이거 우리 애들 시집간 장부야. 누가 언제 데려갔는지 다 적어. 너도 이제 봐도 돼.",
		},
		"absent_warn": "사흘째야. 애들이 문 쪽만 보더라. 무슨 일 있으면 말이라도 해.",
	},
	"deckhand": {
		"name": "수산시장 선원",
		"kind": "clerk",
		"inst": "fish",
		"rank": "deckhand",
		"boss": "fisher",
		"wage": 80,
		"known_at": 14,
		"skill": "fish",
		"books": 0,
		"slice": 1,
		"calls": {
			"stranger": "새 뱃사람",
			"known": "뱃사람 {ho}",
			"master": "우리 선원",
		},
		"boss_calls": {
			"stranger": [
				"새로 온 {ho}, 궤짝은 저쪽이고 그물은 이쪽이야. 손부터 씻고.",
				"새로 온 {ho}, 오늘은 세 마리만이라도 걷어 봐. 그거면 돼.",
			],
			"known": [
				"뱃사람 {ho}, 물이 올랐어. 오늘 그물은 무겁겠다.",
				"뱃사람 {ho}, 비 온다. 궤짝 덮개부터 씌워.",
			],
			"master": [
				"우리 선원 왔어? 물부터 봐. 오늘은 그물이 알아서 찰 거야.",
				"우리 선원, 저녁엔 접고 가. 궤짝은 내가 마저 볼게.",
			],
		},
		"hire": {
			"ask": "그물 걷는 손, 하나 더 필요하지 않아요? 저 써 주세요.",
			"refuse_aff": "남의 그물을 맡기는 건... 얼굴 몇 번 더 보고. 아직은 아니야.",
			"refuse_skill": "낚시 손이 아직 서툴러. 입질 좀 더 받아 보고 와. 그물은 그다음.",
			"refuse_busy": "딴 데 자리 있다며. 물때는 사람 사정 안 봐 줘. 거기 접고 와.",
			"accept": "좋아. 내일 아침에 나와. 궤짝은 아홉 시부터 채우는 거야.",
			"first_day": "첫날이지. 그물은 내가 던졌으니 넌 걷기만 해. 초록 구간, 알지?",
			"resign_ask": "저... 그물 일은 오늘까지만 할게요. 낚싯대는 계속 들 거예요.",
			"resign_reply": "...그래. 물은 어디 안 가. 낚싯대는 계속 들고 다녀.",
			"fired": "이레째 궤짝이 비었어. 그물은 내가 걷지. 이제 넌 손님이야.",
		},
		"loop": [
			{
				"customer": "angler",
				"setup": "강태가 궤짝을 기웃대며 「어제 놓친 놈이 이만~했는데, 여기 있나?」 한다.",
				"choices": [
					[
						"「놓친 놈이 훨씬 컸을 거예요」 하고 맞장구친다",
						"강태는 신나서 떠들다 빈손으로 간다. 용식 「기분은 팔고 생선은 안 팔았네.」",
						0,
					],
					[
						"궤짝에서 제일 큰 놈을 꺼내 「이것보단 작았죠?」 한다",
						"강태가 발끈해서 사 간다. 용식 「팔긴 팔았어. 내일 강태 얼굴은 네가 봐.」",
						-1,
					],
					[
						"「낚은 건 낚은 거고 궤짝 건 그물 거예요. 자랑은 못 돼요」",
						"강태가 웃으며 미끼만 산다. 용식 「그물 건 그물 거. 그걸 아는 손이면 됐어.」",
						1,
					],
				],
			},
			{
				"customer": "foodie",
				"setup": "다미가 코를 킁킁대며 「제일 싱싱한 걸로 회 뜰 거야. 어떤 게 좋아?」 한다.",
				"choices": [
					[
						"값 제일 비싼 놈을 「이게 제일이에요」 하고 내민다",
						"다미가 값을 치른다. 용식 「비싼 놈이 싱싱한 놈은 아니야. 그건 새벽 거잖아.」",
						-1,
					],
					[
						"방금 걷은 작은 놈을 「값은 싸도 이게 제일 싱싱해요」 한다",
						"다미 「냄새부터 다르다!」 용식 「싼 놈을 권하네. 근데 맞는 말이야.」",
						1,
					],
					[
						"「회는 주인장 손이죠」 하고 용식을 부른다",
						"용식이 회를 뜬다. 「그 정도는 네가 고르라고 둔 건데.」",
						0,
					],
				],
			},
			{
				"customer": "chief",
				"setup": "이장이 지팡이를 짚고 들어와 「마을 잔치 상에 올릴 생선을 맞춰 두게」 한다.",
				"choices": [
					[
						"「황금잉어로 올릴게요」 하고 큰소리친다",
						"이장은 껄껄 웃는다. 용식 「두 번밖에 못 본 놈을 잔치에? 물에다 약속하지 마.」",
						-1,
					],
					[
						"「몇 분이나 오세요? 머릿수를 알아야 그물을 몇 번 걷죠」",
						"이장 「용식이가 사람 하나는 잘 봤구먼.」 용식 「...묻는 순서가 맞아.」",
						1,
					],
					[
						"「주인장이 직접 받으셔야죠」 하고 용식을 부른다",
						"용식이 나와 받는다. 「이장 어른이면 내가 나가야지. 다음엔 네가 받아.」",
						0,
					],
				],
			},
			{
				"customer": "forest_mom",
				"setup": "연화가 모처럼 마을에 내려와 「솔이 국거리로, 순한 놈 하나만요」 한다.",
				"choices": [
					[
						"궤짝에서 제일 크고 살진 놈을 골라 준다",
						"연화 「이렇게 큰 걸요...?」 용식 「아이 국거리에 큰 놈? 가시만 많아.」",
						-1,
					],
					[
						"가시 적은 작은 놈을 골라 「국엔 이게 순해요」 하고 값을 받는다",
						"연화 「솔이가 좋아하겠어요.」 용식 「맞아, 국은 그놈이야. 값도 딱 그만큼.」",
						1,
					],
					[
						"「값은 됐어요, 솔이 주세요」 하고 그냥 건넨다",
						"연화가 몇 번이나 고개를 숙인다. 용식 「마음은 알겠어. 다음엔 나한테 먼저 말해.」",
						0,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "받아. 걷은 날만 셌어. 물도 거짓말 안 하고, 나도 안 해.",
			"nothing": "줄 게 없어. 그물을 안 걷은 날엔 궤짝도 비어 있잖아.",
			"not_yet": "아직이야. 이레 채우고 와. 품삯도 물때처럼 날이 있어.",
		},
		"sees": {
			"what": "용식의 물때표 — 내일 무는 어종과 아침/낮/밤, 안 잡아 본 놈까지 계절·날씨대로",
			"line": "...이건 아무한테도 안 보여 준 거야. 내일 무는 놈들. 우리 선원이니까 봐.",
		},
		"absent_warn": "사흘째 궤짝이 비었어. 물은 기다려 주지 않아. 내일은 나와.",
	},
	"library_aide": {
		"name": "도서관 사서보",
		"kind": "clerk",
		"inst": "library",
		"rank": "aide",
		"boss": "librarian",
		"wage": 80,
		"known_at": 14,
		"skill": "",
		"books": 3,
		"slice": 1,
		"calls": {
			"stranger": "새로 온 사람",
			"known": "도서관 {ho}",
			"master": "우리 사서보",
		},
		"boss_calls": {
			"stranger": [
				"왔네요. 반납함부터 봐 줄래요? 어젯밤 것까지 쌓였어요.",
				"오늘은 서가 셋째 줄이에요. 먼지가 제일 먼저 앉는 데죠.",
			],
			"known": [
				"{title}, 왔네요. 어제 나간 책 둘이 아직 안 돌아왔어요.",
				"{title}. 오늘 장부 첫 줄은 당신이 써요. 저는 서가 볼게요.",
			],
			"master": [
				"{title} 왔네요. 오늘 장부는 제가 먼저 펴 뒀어요.",
				"{title}, 열쇠는 늘 그 자리예요. 서가는 오늘 당신 몫이에요.",
			],
		},
		"hire": {
			"ask": "사서보 자리, 비어 있죠? 여기서 일하고 싶어요.",
			"refuse_aff": "…아직 당신을 잘 몰라요. 장부는 아는 사람한테만 맡겨요.",
			"refuse_skill": "여기 책, 세 권은 읽고 오세요. 서가를 모르면 못 맡겨요.",
			"refuse_busy": "다른 데서 일하고 있잖아요. 장부는 반쪽 마음으론 못 봐요.",
			"accept": "…좋아요. 내일 아침 아홉 시, 반납함부터 같이 봐요.",
			"first_day": "첫날이에요. 장부는 이렇게 펴요. 글씨는 작게, 날짜는 꼭.",
			"resign_ask": "그만두려고요. 장부는 오늘까지만 볼게요.",
			"resign_reply": "…알았어요. 마지막 줄은 당신 글씨로 남겨 둘게요.",
			"fired": "이레째예요. 장부는 다시 제가 펴요. 열쇠는 두고 가요.",
		},
		"loop": [
			{
				"customer": "merchant",
				"setup": "만수가 계산대에 기대 묻는다. 「다미가 뭐 빌려 갔어? 장부 좀.」",
				"choices": [
					[
						"잼 책이라고 슬쩍 귀띔한다",
						"서하: …대출 기록은 빌린 사람 거예요. 장부, 오늘은 제가 볼게요.",
						-1,
					],
					[
						"장부는 못 보여 주고, 잼 책을 한 권 더 찾아 준다",
						"만수: 어, 이런 게 또 있었어? 됐다, 내가 직접 볼래.",
						1,
					],
					[
						"누가 뭘 빌렸는지 모르는 척한다",
						"만수: 사서보가 그것도 몰라? 치, 됐어. 내가 찾지 뭐.",
						0,
					],
				],
			},
			{
				"customer": "alchemist",
				"setup": "묘연이 복원 중인 오래된 책을 가리킨다. 「집에서 보고 싶은데요.」",
				"choices": [
					[
						"연구에 쓰신다니 빌려 드린다",
						"서하: 그 책은 문밖에 못 나가요. …오늘은 제가 찾아올게요.",
						-1,
					],
					[
						"열람석에서만 보시라 하고 장갑을 내준다",
						"묘연: 장갑까지… 꼼꼼하네요. 좋아요, 여기서 볼게요.",
						1,
					],
					[
						"관장이 돌아올 때까지 기다리시라고 한다",
						"묘연: 두 시간이나요? …흠, 다음에 다시 올게요.",
						0,
					],
				],
			},
			{
				"customer": "farmer",
				"setup": "순돌이 감자 책을 내민다. 흙 묻은 손자국째로, 다음 권을 찾는다.",
				"choices": [
					[
						"얼룩은 못 본 척 받고 다음 권을 내준다",
						"서하: …흙자국이요. 다음엔 한마디 해 줘요. 책이 아파요.",
						-1,
					],
					[
						"얼룩을 보여 주고 손 씻을 물을 내준 뒤 다음 권을 준다",
						"순돌: 허, 미안하네. 밭에서 바로 오느라. 씻고 보지.",
						1,
					],
					[
						"얼룩값을 물리고 다음 권은 안 된다고 한다",
						"순돌: 책 하나에 야박하구먼. 알았네, 다음엔 씻고 오지.",
						0,
					],
				],
			},
			{
				"customer": "musician",
				"setup": "한별이 악기를 안고 들어온다. 「여기서 느린 곡 하나만 해도 돼요?」",
				"choices": [
					[
						"조용한 곡이라면 괜찮다고 한다",
						"서하: …책장 넘기는 소리가 안 들렸어요. 여긴 그게 전부인데요.",
						-1,
					],
					[
						"안에선 안 되니 도서관 앞 계단에서 하자고 한다",
						"한별: 계단에서 한 곡! 좋아요. 창문 열어 두면 안에도 들리겠죠?",
						1,
					],
					[
						"읽는 사람 없을 때 딱 한 곡만 하라고 한다",
						"서하: …끝부분만 들었네요. 좋은 곡이지만 다음엔 밖에서요.",
						0,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "이번 주 몫이에요. 봉투는 얇지만… 장부는 두꺼워졌어요.",
			"nothing": "받을 게 없어요. 근무한 날이 장부에 한 줄도 없거든요.",
			"not_yet": "봉급일은 아직이에요. 날짜는 장부가 세고 있어요.",
		},
		"sees": {
			"what": "대출 장부 — 누가 어떤 책을 언제 빌려 갔고, 반납 기한이 언제인지",
			"line": "이건 당신한테만 보여 줘요. 누가 뭘 읽는지… 광장에선 말하지 말고요.",
		},
		"absent_warn": "사흘째 안 왔어요. 반납함이 넘쳐요. …내일은 와요.",
	},
	# ---- 순경(S2b) — 파출소 창구에서 들어간다. 근무는 대화가 아니라 **걷기**다: 순찰 지점 셋을
	# 발로 찍고 돌아와 보고한다. 19시 뒤에 보고하면 야간 순찰 +30. 사건이 열려 있으면 「출동」
	"constable": {
		"name": "순경",
		"kind": "office",
		"inst": "police_box",
		"rank": "constable",
		"boss": "officer_park",
		"wage": 120,
		"night_bonus": 30,
		"known_at": 14,
		"skill": "combat",
		"skill_lv": 2,
		"boldness": 35,
		"books": 0,
		"req_rep": 20,
		"slice": 2,
		"calls": {
			"stranger": "신참 순경",
			"known": "순경 양반",
			"master": "우리 순경",
		},
		"boss_calls": {
			"stranger": [
				"왔나. 제복은 입는 게 아니라 지키는 걸세. 오늘도 세 군데일세.",
				"신참, 순찰은 빨리 도는 게 아니야. 보면서 도는 거지.",
			],
			"known": [
				"순경 양반 왔구먼. 어젯밤은 조용했네. 자네 덕도 있지.",
				"순경 양반, 게시판 앞은 자네가 맡게. 나는 어귀를 돌지.",
			],
			"master": [
				"우리 순경 왔네. 이제 밤길은 자네한테 맡겨도 되겠어.",
				"우리 순경, 자네가 있어서 나도 잠을 좀 자네.",
			],
		},
		"hire": {
			"ask": "순경님, 파출소에서 일하고 싶습니다. 밤길이 무섭지 않습니다.",
			"refuse_aff": "제복은 아는 사람한테 주는 걸세. 자넬 좀 더 봐야겠어.",
			"refuse_skill": "지네 한 마리는 혼자 잡아야 하네. 창부터 손에 익히고 오게.",
			"refuse_rep": "마을이 자넬 믿어야 제복이 서네. 아직은 아닐세.",
			"refuse_record": "전과가 있는 사람한테 제복은 못 주네. 규정일세.",
			"refuse_bold": "밤길이 무섭지 않다고 했나. 자네 눈은 아직 그렇게 말하지 않네.",
			"refuse_busy": "자넨 벌써 딴 데 이름이 올라 있잖나. 제복은 겸직이 안 되네.",
			"accept": "그래. 내일 아침 아홉 시에 파출소로 오게. 제복은 맞춰 두지.",
			"first_day": "첫날일세. 순찰은 세 군데 — 광장 남쪽, 게시판 앞, 서쪽 어귀. 보고 오게.",
			"resign_ask": "순경님, 제복을 벗겠습니다. 그동안 감사했습니다.",
			"resign_reply": "그리하게. 제복은 두고 가게. 밤길은 다시 내가 돌지.",
			"fired": "이레일세. 순찰을 비워 둔 채로는 못 두네. 제복을 거두겠네.",
		},
		"patrol": {
			"start": ["오늘도 세 군데일세. 광장 남쪽, 게시판 앞, 서쪽 어귀. 다녀오게.",
				"순찰은 보는 일일세. 누가 어디 서 있었는지 기억해 두게.",
				"어귀 쪽은 낯선 얼굴이 오는 길이야. 거기부터 보고 오게."],
			"report": ["수고했네. 조용한 보고가 제일 좋은 보고지. 몫은 적어 뒀네.",
				"돌고 왔구먼. 오늘 몫은 장부에 올렸네.",
				"그래, 그 정도면 됐네. 내일도 같은 길일세."],
			"night": "밤길을 돌았구먼. 밤 몫은 서른 더 얹네. 제복이 그만한 값을 하는 걸세.",
		},
		"loop": [],
		"wage_lines": {
			"pay": "이번 주 몫일세. 제복 값은 도에서 나오네. 받게.",
			"nothing": "순찰 보고가 없구먼. 봉급은 돈 날에만 적히는 걸세.",
			"not_yet": "봉급날은 아직일세. 이레마다라고 했잖나.",
		},
		"sees": {
			"what": "순찰 일지 — 누가 어느 집 근처를 서성였는지, 사건이 어디까지 갔는지",
			"line": "우리 순경한테는 이걸 보여 주지. 순찰 일지야. 남이 보면 곤란한 이름이 있네.",
		},
		"absent_warn": "사흘째 제복이 걸려만 있네. 밤길을 나 혼자 돌았어. 내일은 오게.",
	},
	# ---- 기관직(S2) — 면사무소 창구에서 들어간다. 봉급도 그 창구에서 받는다(헌법 §2.5).
	# req: rep(kyojin) ≥ 20 · 미말소 전과 0 · 직업별 숙련. 채용 대사·거절 사유는 이장이 말한다
	"township_clerk": {
		"name": "면 서기",
		"kind": "office",
		"inst": "township",
		"rank": "clerk",
		"boss": "chief",
		"wage": 100,
		"known_at": 14,
		"skill": "",
		"books": 0,
		"req_rep": 20,
		"slice": 2,
		"calls": {
			"stranger": "면사무소 새 사람",
			"known": "서기 양반",
			"master": "우리 서기",
		},
		"boss_calls": {
			"stranger": [
				"왔구먼. 장부는 펜보다 무겁네. 오늘도 한 장씩 넘기세.",
				"새 사람, 도장은 힘으로 찍는 게 아닐세. 자리에 앉게.",
			],
			"known": [
				"서기 양반 왔는가. 오늘 민원은 셋일세. 차부터 한잔 하게.",
				"서기 양반, 어제 그 장부 자네가 맞춰 놓은 거 봤네. 잘했어.",
			],
			"master": [
				"우리 서기 왔구먼. 늙은이는 이제 도장만 찍으면 되겠어.",
				"우리 서기, 자네 없으면 이 면사무소는 문 닫아야 하네.",
			],
		},
		"hire": {
			"ask": "이장님, 면사무소에서 일하고 싶습니다. 장부라면 자신 있어요.",
			"refuse_aff": "면사무소 일은 마을 사람 일일세. 자넬 좀 더 알고 나서 보세.",
			"refuse_skill": "장부는 배우면 되네. 그보다 사람 됨됨이가 먼저야. 좀 더 두고 보세.",
			"refuse_rep": "마을에 자네 얘기가 좀 더 좋게 돌아야 하네. 그때 다시 오게.",
			"refuse_record": "전과가 있는 사람한테 공무를 맡길 수는 없네. 미안하이.",
			"refuse_busy": "자넨 벌써 딴 데 이름이 올라 있잖나. 공무는 한 몸으로 하는 걸세.",
			"accept": "그래. 내일 아침 아홉 시에 회관으로 오게. 도장은 내가 찍어 두지.",
			"first_day": "첫날일세. 민원은 사람 얘기야. 장부보다 얼굴을 먼저 보게.",
			"resign_ask": "이장님, 면사무소 일은 여기까지 하겠습니다. 감사했습니다.",
			"resign_reply": "그리하게. 자네가 맞춘 장부는 오래 갈 걸세. 수고했네.",
			"fired": "이레일세. 창구를 비워 둔 채로는 못 두네. 자리는 거두겠네.",
		},
		"loop": [
			{
				"customer": "farmer",
				"setup": "순돌이 밭 경계 문제로 왔다. 「덕구네 울타리가 한 뼘 넘어왔네.」",
				"choices": [
					[
						"측량 장부를 펴고 경계를 그대로 읽어 준다",
						"이장: 장부대로 했구먼. 그게 서기 일일세. 순돌이도 수긍했지.",
						1,
					],
					[
						"한 뼘쯤은 서로 봐 주라고 달랜다",
						"순돌: 한 뼘이 열 뼘 되는 걸세, 아무렴. 그래도 알았네.",
						0,
					],
					[
						"덕구를 불러 다음에 다시 오라고 한다",
						"이장: 미루면 두 사람 다 다시 와야 하네. 오늘 끝냈어야지.",
						-1,
					],
				],
			},
			{
				"customer": "merchant",
				"setup": "만수가 장부를 들고 왔다. 「재산세 그거, 가게 창고까지 세는 거야?」",
				"choices": [
					[
						"창고는 집이 아니라고 규정을 읽어 준다",
						"만수: 그럼 됐어! 역시 물어보길 잘했네. 다음에 씨앗 하나 줄게.",
						1,
					],
					[
						"모르겠으니 이장에게 물어보라고 한다",
						"이장: 그건 자네가 답할 수 있는 거였네. 규정집 다시 읽게.",
						-1,
					],
					[
						"세는 게 맞다고 대충 답한다",
						"만수: 진짜? …그럼 창고 좀 줄여야겠네. 확실한 거지?",
						0,
					],
				],
			},
			{
				"customer": "florist",
				"setup": "봄이가 도장을 받으러 왔다. 「꽃밭 옆에 작은 화분 가게를 내고 싶어요.」",
				"choices": [
					[
						"허가 절차를 순서대로 적어 준다",
						"봄이: 이렇게 적어 주니 하나도 안 무섭네요. 고마워요!",
						1,
					],
					[
						"도장부터 찍어 준다",
						"이장: 서류 없이 도장부터 찍으면 나중에 서기가 곤란해지네.",
						-1,
					],
					[
						"지금은 상점 허가가 안 열렸다고 알려 준다",
						"봄이: 그렇군요… 그럼 열리면 제일 먼저 올게요.",
						0,
					],
				],
			},
			{
				"customer": "postman",
				"setup": "덕구가 이사 서류를 들고 왔다. 「고장 사람 하나가 교진으로 오고 싶다네.」",
				"choices": [
					[
						"빈 집터가 있는지 장부로 확인해 준다",
						"이장: 집터부터 보는 게 맞네. 자네 장부가 마을을 지키는 걸세.",
						1,
					],
					[
						"사람이 늘면 좋다고 바로 받는다",
						"덕구: 반가운 마음은 알겠네만 집이 없으면 어디서 자나.",
						0,
					],
					[
						"이장 결재를 받아 오라고 돌려보낸다",
						"이장: 그건 서기 선에서 볼 수 있는 일이었네. 나까지 올 것 없어.",
						-1,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "이번 주 몫일세. 도 교부금이라 마을 장부에선 안 나가네. 받게.",
			"nothing": "근무한 날이 없구먼. 봉급은 나온 날에만 적히는 걸세.",
			"not_yet": "봉급날은 아직일세. 장부에 이레마다라고 적혀 있잖나.",
		},
		"sees": {
			"what": "예산 장부 — 마을 예산의 실수치와 다음 사업까지 남은 돈",
			"line": "우리 서기니까 보여 주는 걸세. 이게 마을 예산 장부야. 남한텐 말 말게.",
		},
		"absent_warn": "사흘째 창구가 비었네. 민원 온 사람들이 그냥 돌아갔어. 내일은 오게.",
	},
	"forest_ranger": {
		"name": "산림감시원",
		"kind": "office",
		"inst": "township",
		"rank": "ranger",
		"boss": "chief",
		"wage": 110,
		"known_at": 14,
		"skill": "forest",
		"skill_lv": 4,
		"books": 0,
		"req_rep": 20,
		"slice": 2,
		"calls": {
			"stranger": "견습 감시원",
			"known": "감시원 양반",
			"master": "우리 감시원",
		},
		"boss_calls": {
			"stranger": [
				"왔구먼. 견습이라도 숲은 자네를 벌써 아네. 오늘도 돌고 오게.",
				"새 감시원, 숲 지도는 접지 말고 펴서 들게. 접으면 길을 잃어.",
			],
			"known": [
				"감시원 양반 왔는가. 어제 솔숲에서 연기 봤다는 말이 있었네.",
				"감시원 양반, 동백이가 자네 얘기를 하더군. 깐깐하다고. 칭찬일세.",
			],
			"master": [
				"우리 감시원 왔구먼. 자네가 돌고 온 숲은 조용하네.",
				"우리 감시원, 늙은이는 이제 숲 걱정은 안 하네. 자네가 있으니.",
			],
		},
		"hire": {
			"ask": "이장님, 숲을 지키는 일을 하고 싶습니다. 도끼질은 할 만큼 했어요.",
			"refuse_aff": "숲을 맡기려면 사람을 알아야 하네. 자넨 아직 낯설어.",
			"refuse_skill": "도끼질이 아직 서툴러. 나무를 알아야 숲을 세지. 더 베고 오게.",
			"refuse_rep": "숲을 맡기려면 마을이 자넬 믿어야 하네. 아직은 아닐세.",
			"refuse_record": "전과가 있는 사람한테 숲을 맡길 수는 없네. 미안하이.",
			"refuse_busy": "자넨 벌써 딴 데 이름이 올라 있잖나. 숲은 한 몸으로 지키는 걸세.",
			"accept": "그래. 내일 아침 아홉 시에 회관으로 오게. 숲 지도는 내가 주지.",
			"first_day": "첫날일세. 숲은 베는 사람이 아니라 세는 사람이 지키는 걸세.",
			"resign_ask": "이장님, 숲 지키는 일은 여기까지 하겠습니다. 감사했습니다.",
			"resign_reply": "그리하게. 자네가 센 나무는 그대로 서 있을 걸세. 수고했네.",
			"fired": "이레일세. 숲을 비워 둔 채로는 못 두네. 지도는 돌려주게.",
		},
		"loop": [
			{
				"customer": "sawyer",
				"setup": "동백이 그루터기 셋을 두고 왔다. 「내가 벤 거요. 이장 허가는 받았소.」",
				"choices": [
					[
						"허가 장부와 맞춰 보고 정상으로 적는다",
						"이장: 장부와 맞춰 봤구먼. 동백이는 허가 없이 안 베네. 잘했어.",
						1,
					],
					[
						"허가증을 보여 달라고 한다",
						"동백: 허가증? 이장 말이 허가지. 젊은 사람이 깐깐하구먼.",
						0,
					],
					[
						"묻지 않고 그냥 넘어간다",
						"이장: 장부에 안 적으면 다음 사람이 그걸 무허가로 보네. 적게.",
						-1,
					],
				],
			},
			{
				"customer": "herbalist",
				"setup": "유하가 약초 밭 경계를 묻는다. 「깊은 숲 안쪽은 캐도 되는 건가요?」",
				"choices": [
					[
						"큰나무 둘레 다섯 걸음은 남기라고 일러 준다",
						"유하: 다섯 걸음이요. 적어 둘게요. 숲도 쉬어야 하니까요.",
						1,
					],
					[
						"어디든 캐도 된다고 한다",
						"이장: 큰나무 둘레는 비워 두는 게 마을 규칙일세. 다시 일러 주게.",
						-1,
					],
					[
						"이장에게 물어보라고 한다",
						"유하: 그럼 다음에요. 오늘은 그냥 돌아갈게요.",
						0,
					],
				],
			},
			{
				"customer": "explorer",
				"setup": "재민이 뛰어왔다. 「솔숲에서 연기 봤어! 애들이 불장난하는 거 같아!」",
				"choices": [
					[
						"곧장 솔숲으로 가서 불씨를 밟아 끈다",
						"이장: 불은 늦으면 숲 하나가 없어지네. 바로 간 게 맞았어.",
						1,
					],
					[
						"재민에게 물 한 통 들고 같이 가자고 한다",
						"재민: 좋아, 나도 갈래! 근데 물통 무겁다…",
						0,
					],
					[
						"애들 장난이니 두고 본다",
						"이장: 불장난을 두고 본 감시원은 없네. 다음엔 바로 가게.",
						-1,
					],
				],
			},
			{
				"customer": "carpenter",
				"setup": "덕구가 목재를 부탁한다. 「지붕 고칠 나무가 모자라. 큰나무 하나면 되는데.」",
				"choices": [
					[
						"큰나무는 안 되고 벌목장 나무를 안내한다",
						"이장: 큰나무는 마을 것도 내 것도 아닐세. 잘 막았어.",
						1,
					],
					[
						"딱 하나만 허가해 준다",
						"이장: 큰나무는 한 그루도 안 되네. 감시원이 그걸 몰라서야.",
						-1,
					],
					[
						"이장 허가를 받아 오라고 한다",
						"덕구: 허가라… 알겠네. 이장님한테 가 보지.",
						0,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "이번 주 몫일세. 숲 세는 값은 도에서 나오네. 받게.",
			"nothing": "순찰 나간 날이 없구먼. 봉급은 나간 날에만 적히는 걸세.",
			"not_yet": "봉급날은 아직일세. 이레마다라고 말했잖나.",
		},
		"sees": {
			"what": "숲의 장부 — 어느 그루터기가 허가받은 것이고 어디가 무허가인지",
			"line": "우리 감시원한테는 이걸 주지. 허가 장부야. 그루터기마다 이름이 있네.",
		},
		"absent_warn": "사흘째 숲을 안 돌았네. 그루터기가 셋 늘었어. 내일은 나가게.",
	},
	"mail_carrier": {
		"name": "우체국 배달원",
		"kind": "clerk",
		"inst": "post",
		"rank": "carrier",
		"boss": "postman",
		"wage": 80,
		"known_at": 14,
		"skill": "",
		"books": 0,
		"slice": 1,
		"calls": {
			"stranger": "가방 멘 젊은이",
			"known": "배달원 양반",
			"master": "우리 배달원",
		},
		"boss_calls": {
			"stranger": [
				"어, 심부름꾼 왔나. 가방 끈부터 조이게. 편지는 떨어뜨리면 끝일세.",
				"비 오는 날은 봉투를 품에 넣고 걷게. 젖은 글씨는 못 읽어.",
			],
			"known": [
				"배달원 양반 왔구먼. 도장은 내가 찍을 테니 자넨 걷기만 하게.",
				"오늘 가방은 가볍네, 배달원 양반. 가벼운 날이 좋은 날이야.",
			],
			"master": [
				"우리 배달원 왔네. 문 열기 전에 발소리로 알아.",
				"우리 배달원, 저녁이면 내가 문 앞에 서 있네. 늙은이 버릇일세.",
			],
		},
		"hire": {
			"ask": "아저씨, 가방 하나 더 안 필요하세요? 걷는 건 제가 할게요.",
			"refuse_aff": "남의 편지를 맡기려면 사람을 알아야 하네. 자넨 아직 낯설어.",
			"refuse_skill": "물소리 마을까지 하루에 다녀올 다리가 아직 아닐세. 더 걷고 오게.",
			"refuse_busy": "자넨 벌써 딴 데 이름이 올라 있잖나. 가방은 한 어깨에 하나야.",
			"accept": "좋네. 내일 아침 나오게. 자네 몫 가방 하나 비워 두지.",
			"first_day": "자, 첫 가방일세. 무거운 건 종이가 아니라 남의 말이야. 그리 들게.",
			"resign_ask": "아저씨, 가방 내려놓으려고요. 그동안 고마웠습니다.",
			"resign_reply": "그리하게. 다리는 쉬어도 되네. 자네 앞으로 온 건 계속 챙겨 두지.",
			"fired": "이레일세. 못 간 편지는 내가 다 걸었네. 가방은 내려놓게.",
		},
		"loop": [
			{
				"customer": "florist",
				"setup": "봄이가 봉투를 품에 안고 온다. 「덕구 아저씨한테요. 손 말고 편지로요.」",
				"choices": [
					[
						"덕구 아저씨 지금 광장에 계세요. 제가 바로 손에 쥐여 드릴게요.",
						"고맙긴 한데, 봄이가 우표를 산 건 얼굴 안 보고 주고 싶어서야.",
						0,
					],
					[
						"우표값 150G예요. 봉투째 제 가방에 넣어서 갖다 드릴게요.",
						"그래. 봉투에 든 채로 가야 편지지. 자네 걸음이 우표값일세.",
						1,
					],
					[
						"덕구 아저씨한테요? 뭐라고 쓰셨는데요?",
						"봄이가 봉투를 도로 품에 넣는다. 「…그냥 다음에 올게요.」",
						-1,
					],
				],
			},
			{
				"customer": "explorer",
				"setup": "재민이 봉투를 내민다. 「북쪽 고개 너머 아무 집. 주소는 이게 다야!」",
				"choices": [
					[
						"주소 없이는 못 부쳐요. 제대로 적어서 다시 오세요.",
						"틀린 말은 아닌데, 편지 한 통 돌려보내면 사람 하나 돌려보내는 걸세.",
						0,
					],
					[
						"받는 분 이름만 적어 주세요. 고개 너머는 아저씨가 아실 거예요.",
						"고개 너머 집은 셋뿐이야. 이름만 있으면 내가 찾네. 잘 물었어.",
						1,
					],
					[
						"제가 같이 가서 찾아 드릴게요. 지도 밖은 재밌잖아요.",
						"가방 놓고 어딜 가나. 배달원이 모험가 따라가면 우체국이 비네.",
						-1,
					],
				],
			},
			{
				"customer": "herbalist",
				"setup": "향이가 문을 열자마자 묻는다. 「묘연 씨 답장 왔죠? 안에 뭐라고… 급해서요.」",
				"choices": [
					[
						"봉투는 못 열어요. 대신 지금 바로 들고 가서 드릴게요.",
						"그래, 아픈 사람 편지가 먼저야. 다녀오게, 도장은 내가 찍지.",
						1,
					],
					[
						"급하시다니까… 제가 살짝만 봐 드릴까요?",
						"그 손 거기서 멈추게. 봉투 안은 받는 사람 것일세.",
						-1,
					],
					[
						"순서대로 돌아요. 향이 씨 집은 오후예요. 그때 꼭 갑니다.",
						"틀린 말은 아니야. 그런데 아픈 사람한테 순서는 없네.",
						0,
					],
				],
			},
			{
				"customer": "merchant",
				"setup": "만수가 씨앗 주문서를 흔든다. 「우표값 150은 너무해. 단골 할인 없어?」",
				"choices": [
					[
						"우표값은 우체국 거라 저도 못 깎아요.",
						"맞는 말이야. 근데 만수는 매번 저러니 웃어나 주게.",
						0,
					],
					[
						"깎는 건 안 되고요, 답장 오면 가게로 제일 먼저 갖다 드릴게요.",
						"그게 배달원 할인일세. 우표는 못 깎아도 걸음은 보태지.",
						1,
					],
					[
						"제가 반 낼게요. 단골이시니까.",
						"자네 일급에서 남의 우표값 내면 걸은 값이 뭐가 남나. 그러지 말게.",
						-1,
					],
				],
			},
		],
		"wage_lines": {
			"pay": "자, 이레치일세. 걸은 만큼이야. 세어 보게, 난 셈이 느려.",
			"nothing": "받을 게 없네. 가방 안 멘 날은 봉투도 비는 법이야.",
			"not_yet": "아직일세. 이레가 차야 봉투를 여네. 오늘은 걷는 날이야.",
		},
		"sees": {
			"what": "가방 속 봉투 안 — 누가 누구에게 무엇을 썼는지 한 줄(mail_box body)",
			"line": "자네 가방일세. 안이 비쳐도 안 읽을 사람한테만 주는 거야.",
		},
		"absent_warn": "사흘째 가방이 그 자리 그대로야. 다리가 아픈 겐가, 마음이 아픈 겐가.",
	},
	"farmer": {
		"name": "농부",
		"kind": "free",
		"inst": "",
		"stat": "crops_harvested",
		"slice": 1,
	},
	"fisher": {
		"name": "어부",
		"kind": "free",
		"inst": "",
		"stat": "fish_caught",
		"slice": 1,
	},
	"logger": {
		"name": "벌목꾼",
		"kind": "free",
		"inst": "",
		"stat": "trees_chopped",
		"slice": 1,
	},
	"miner": {
		"name": "광부",
		"kind": "free",
		"inst": "",
		"stat": "rocks_mined",
		"slice": 1,
	},
	"cook": {
		"name": "요리사",
		"kind": "free",
		"inst": "",
		"stat": "recipes_cooked",
		"slice": 1,
	},
	"rancher": {
		"name": "목장주",
		"kind": "free",
		"inst": "",
		"stat": "animals",
		"slice": 1,
	},
	"herbalist": {
		"name": "약초꾼",
		"kind": "free",
		"inst": "",
		"stat": "forage_caught",
		"slice": 1,
	},
	"cave_hunter": {
		"name": "동굴꾼",
		"kind": "free",
		"inst": "",
		"stat": "mob_kills",
		"slice": 1,
	},
	# ---- 명예직 셋(S3c) — 무보수. 돈이 아니라 부름과 「보이는 것」이 몫이다 ----
	"women_head": {
		"name": "부녀회장",
		"kind": "honor",
		"inst": "assoc",
		"rank": "women_head",
		"boss": "chief",
		"wage": 0,
		"known_at": 14,
		"skill": "",
		"books": 0,
		"req_rep": 60,
		"req_aff": 50,
		"slice": 3,
		"calls": {
			"stranger": "부녀회 새 사람",
			"known": "부녀회장 양반",
			"master": "우리 부녀회장",
		},
		"boss_calls": {
			"stranger": [
				"왔나. 부녀회는 말보다 발일세. 누구 집에 무슨 일 있는지 먼저 알게.",
				"새 회장, 오늘은 누구네를 돌 텐가. 명부는 창구에 있네.",
			],
			"known": [
				"부녀회장 양반, 솜이네가 요즘 조용하더군. 한번 들러 보게.",
				"부녀회장 양반 덕에 마을이 덜 외롭네. 고맙네.",
			],
			"master": [
				"우리 부녀회장 왔구먼. 자네 없으면 누가 사람을 챙기겠나.",
				"우리 부녀회장, 오늘도 한 집 돌고 오게. 내가 차 끓여 두지.",
			],
		},
		"hire": {
			"ask": "이장님, 부녀회장 자리를 맡고 싶습니다. 사람 챙기는 일이라면.",
			"refuse_aff": "자네를 아직 잘 모르네. 나하고 좀 더 지내고 말하세.",
			"refuse_rep": "부녀회장은 마을이 먼저 미는 자리일세. 아직 그 말이 안 도네.",
			"refuse_record": "전과가 있는 사람한테 남의 집 문을 두드리게 할 순 없네.",
			"refuse_busy": "일자리가 있는 사람은 못 맡네. 부녀회는 온 하루가 남의 일이야.",
			"refuse_skill": "손이 아직 서툴러. 좀 더 해 보고 오게.",
			"accept": "그래, 자네가 맡게. 봉급은 없네. 대신 마을이 자넬 부를 걸세.",
			"first_day": "첫날일세. 창구에 살림 명부를 뒀네. 오래 못 본 집부터 돌게.",
			"resign_ask": "이장님, 부녀회장 자리를 내려놓겠습니다.",
			"resign_reply": "그러게. 자네가 돈 집들은 기억할 걸세. 고마웠네.",
			"fired": "이레를 안 보였어. 사람 챙기는 자리를 비워 둘 순 없네. 내려놓게.",
		},
		"loop": [
			{
				"customer": "florist",
				"setup": "해솔이 회관 문 앞에서 서성인다. 「부녀회에서… 저희 집도 봐 주나요?」",
				"choices": [
					["오늘 저녁에 들르겠다고 한다", "해솔: 정말요? 꽃차 끓여 둘게요. 아무도 안 온 지 오래라.", 1],
					["무슨 일인지 먼저 묻는다", "해솔: 별일은 아니에요. 그냥… 사람이 그리웠어요.", 0],
					["명부에 이름만 적는다", "해솔: 아, 네. 바쁘시죠. 그럼 다음에…", -1],
				],
			},
			{
				"customer": "weaver",
				"setup": "솜이가 베 한 필을 들고 왔다. 「누구 집에 필요한 데 없을까요?」",
				"choices": [
					["연화네에 보내자고 한다", "솜이: 솔이 옷 지으면 되겠네요. 잘 됐다. 고마워요.", 1],
					["회관 창고에 두자고 한다", "솜이: 창고요… 네. 누구든 쓰면 좋죠.", 0],
					["값을 쳐 주겠다고 한다", "솜이: 팔려고 가져온 게 아닌데요. 조금 서운하네요.", -1],
				],
			},
		],
	},
	"youth_head": {
		"name": "청년회장",
		"kind": "honor",
		"inst": "assoc",
		"rank": "youth_head",
		"boss": "chief",
		"wage": 0,
		"known_at": 14,
		"skill": "forest",
		"skill_lv": 3,
		"boldness": 35,
		"books": 0,
		"req_rep": 60,
		"req_aff": 50,
		"slice": 3,
		"calls": {
			"stranger": "청년회 새 사람",
			"known": "회장 양반",
			"master": "우리 회장님",
		},
		"boss_calls": {
			"stranger": [
				"왔나. 청년회장은 밤에 마을을 도는 자리일세. 등불은 없네.",
				"새 회장, 어젯밤은 조용했나. 자네 발소리만 났으면 된 걸세.",
			],
			"known": [
				"회장 양반, 어젯밤 잡화점 뒷문은 봤나. 만수가 걱정하더군.",
				"회장 양반 덕에 밤이 덜 무섭다고들 하네.",
			],
			"master": [
				"우리 회장님 왔구먼. 자네가 도는 밤엔 나도 잠을 자네.",
				"우리 회장님, 오늘 밤도 부탁하네. 마을이 자네를 믿네.",
			],
		},
		"hire": {
			"ask": "이장님, 청년회장을 맡고 싶습니다. 밤길이 무섭지 않습니다.",
			"refuse_aff": "자네를 아직 잘 모르네. 나하고 좀 더 지내고 말하세.",
			"refuse_rep": "청년회장은 마을이 먼저 미는 자리일세. 아직 그 말이 안 도네.",
			"refuse_record": "전과가 있는 사람한테 밤 마을을 맡길 순 없네.",
			"refuse_busy": "일자리가 있는 사람은 못 맡네. 밤을 도는 사람은 낮에 쉬어야 해.",
			"refuse_skill": "나무를 베어 본 손이라야 울력을 시키네. 도끼부터 익히게.",
			"refuse_bold": "밤이 무섭지 않다고 했나. 자네 눈은 아직 그렇게 말하지 않네.",
			"accept": "그래, 자네가 맡게. 봉급은 없네. 밤 아홉 시부터 세 군데를 돌게.",
			"first_day": "첫밤일세. 분수, 잡화점 앞, 우체국 앞. 아침에 나한테 보고하게.",
			"resign_ask": "이장님, 청년회장 자리를 내려놓겠습니다.",
			"resign_reply": "그러게. 밤은 다시 박 순경 혼자 돌겠구먼. 고마웠네.",
			"fired": "이레째 밤을 안 돌았어. 청년회장 자리를 비워 둘 순 없네. 내려놓게.",
		},
		"watch": {
			"report": [
				"수고했네. 어젯밤 마을이 조용했던 건 자네 발소리 덕일세.",
				"세 군데 다 돌았구먼. 이런 밤이 쌓여서 마을이 되는 걸세.",
			],
		},
		"loop": [],
	},
	"village_tutor": {
		"name": "서당 훈장",
		"kind": "honor",
		"inst": "assoc",
		"rank": "tutor",
		"boss": "chief",
		"wage": 0,
		"known_at": 14,
		"skill": "",
		"books": 6,
		"req_rep": 40,
		"req_aff": 30,
		"slice": 3,
		"calls": {
			"stranger": "서당 새 사람",
			"known": "훈장 {ho}",
			"master": "우리 훈장님",
		},
		"boss_calls": {
			"stranger": [
				"왔나. 서당은 회관 구석 책상 하나일세. 아이들은 자네가 모으게.",
				"새 훈장, 글은 천천히 가르치게. 급하면 아이들이 도망가네.",
			],
			"known": [
				"훈장 왔구먼. 솔이가 제 이름을 쓰더군. 자네가 가르쳤나.",
				"훈장, 오늘도 한 사람 앉히게. 글 아는 사람이 느는 게 마을일세.",
			],
			"master": [
				"우리 훈장님 왔네. 자네 덕에 이 마을에 글소리가 나네.",
				"우리 훈장님, 나도 한 자 배워 볼까 하네. 늦었나.",
			],
		},
		"hire": {
			"ask": "이장님, 회관에 서당을 열고 싶습니다. 책은 좀 읽었습니다.",
			"refuse_aff": "자네를 아직 잘 모르네. 나하고 좀 더 지내고 말하세.",
			"refuse_rep": "훈장은 마을이 믿는 사람이라야 하네. 아직은 아닐세.",
			"refuse_record": "전과가 있는 사람한테 아이들을 맡길 순 없네.",
			"refuse_busy": "일자리가 있는 사람은 못 맡네. 서당은 낮을 통째로 먹네.",
			"refuse_skill": "책을 여섯 권은 읽고 오게. 서하한테 가면 되네.",
			"accept": "그래, 열게. 봉급은 없네. 대신 아이들이 자넬 훈장이라 부를 걸세.",
			"first_day": "첫날일세. 오늘은 한 사람만 앉히게. 이름 쓰는 것부터.",
			"resign_ask": "이장님, 서당을 닫겠습니다.",
			"resign_reply": "그러게. 배운 글은 안 지워지네. 고마웠네.",
			"fired": "이레째 서당이 비었어. 아이들이 기다리다 갔네. 내려놓게.",
		},
		"loop": [
			{
				"customer": "forest_girl",
				"setup": "솔이가 붓을 거꾸로 쥐고 앉았다. 「훈장님, 제 이름부터요!」",
				"choices": [
					["손을 잡고 한 획씩 같이 쓴다", "솔이: 됐다! 이게 나예요. 엄마한테 보여 줄래요.", 1],
					["먼저 붓 쥐는 법부터 고친다", "솔이: 이렇게요? 어렵다… 그래도 해 볼게요.", 0],
					["오늘은 보고만 있으라고 한다", "솔이: 보기만요? 저도 쓰고 싶은데… 알겠어요.", -1],
				],
			},
			{
				"customer": "farmer",
				"setup": "순돌이 머쓱하게 들어온다. 「어른도 되나. 장부를 내 손으로 적고 싶어서.」",
				"choices": [
					["숫자부터 가르친다", "순돌: 열, 스물… 이제 감자 자루를 셀 수 있겠네. 고맙네.", 1],
					["자기 이름부터 쓰게 한다", "순돌: 이름이라… 좋네. 내 이름을 내가 쓰는 게 처음일세.", 0],
					["아이들 시간이라 내일 오라 한다", "순돌: 그런가. 그럼… 내일 오지. 미안하이.", -1],
				],
			},
		],
	},
	# ---- 고장 점원 넷(S3c) — 방 없는 일터. 일급 80, 미니루프는 그 사람 앞 대화 ----
	"miller_hand": {
		"name": "방앗간 일꾼",
		"kind": "clerk",
		"inst": "mill",
		"rank": "hand",
		"boss": "miller",
		"wage": 80,
		"known_at": 14,
		"skill": "farm",
		"books": 0,
		"slice": 3,
		"calls": {
			"stranger": "방앗간 새 사람",
			"known": "방앗간 {ho}",
			"master": "우리 방앗간 사람",
		},
		"boss_calls": {
			"stranger": [
				"왔나. 물레는 쉬지 않네. 자네도 쉬지 말게.",
				"새 사람, 밀은 마른 것부터 넣게. 젖으면 맷돌이 미끄러지네.",
			],
			"known": [
				"방앗간 사람 왔구먼. 오늘 물이 세니 두 자루는 더 빻겠네.",
				"자네 손이 맷돌에 익었어. 소리만 들어도 알겠네.",
			],
			"master": [
				"우리 방앗간 사람 왔네. 이제 자네가 물레 소리를 아는구먼.",
				"우리 방앗간 사람 없으면 나 혼자 밤새 빻아야 하네.",
			],
		},
		"hire": {
			"ask": "수길 어른, 방앗간에서 일하고 싶습니다. 밀은 좀 압니다.",
			"refuse_aff": "자네를 아직 잘 모르네. 물소리나 몇 번 더 듣고 오게.",
			"refuse_skill": "밭을 모르는 손은 밀도 모르네. 농사가 좀 익거든 오게.",
			"refuse_busy": "딴 데 이름이 올라 있잖나. 맷돌은 두 손이 다 필요하네.",
			"accept": "그래. 내일 아침 아홉 시에 물레 앞으로 오게. 늦으면 물이 먼저 가네.",
			"first_day": "첫날일세. 자루를 받고, 빻고, 이름을 적게. 순서는 그것뿐이야.",
			"resign_ask": "수길 어른, 방앗간 일은 그만두겠습니다.",
			"resign_reply": "그러게. 물레는 자네 없이도 돌지만, 소리는 좀 달라지겠지.",
			"fired": "이레를 안 왔어. 물레는 기다려 주지 않네. 이제 안 와도 되네.",
		},
		"loop": [
			{
				"customer": "brook",
				"setup": "도담이 젖은 밀 자루를 메고 왔다. 「비를 맞았는데… 되나요?」",
				"choices": [
					["말려서 내일 빻자고 한다", "수길: 옳지. 젖은 밀은 맷돌을 먹네. 자네가 나보다 낫구먼.", 1],
					["그냥 빻아 준다", "수길: 맷돌 소리가 다르잖나. 다음엔 말려 오라 하게.", -1],
					["반만 빻고 반은 말린다", "도담: 반이라도 오늘 빵을 굽겠네요. 고마워요.", 0],
				],
			},
			{
				"customer": "dyer",
				"setup": "윤슬이 빈 자루를 들고 왔다. 「가루 한 되만요. 물감 풀에 쓰려고요.」",
				"choices": [
					["값을 받고 한 되를 준다", "윤슬: 네, 값은 여기요. 물감이 잘 서겠어요.", 0],
					["이웃이라 그냥 준다", "수길: 인심은 좋네만 장부는 내가 맞추네. 다음엔 받게.", -1],
					["가루 대신 겨를 권한다", "윤슬: 겨요? 아, 풀에는 겨가 더 낫겠네요. 고마워요.", 1],
				],
			},
		],
	},
	"dyer_hand": {
		"name": "물들이터 일꾼",
		"kind": "clerk",
		"inst": "dyeworks",
		"rank": "hand",
		"boss": "dyer",
		"wage": 80,
		"known_at": 14,
		"skill": "beach",
		"books": 0,
		"slice": 3,
		"calls": {
			"stranger": "물들이터 새 사람",
			"known": "물감 {ho}",
			"master": "우리 물감쟁이",
		},
		"boss_calls": {
			"stranger": [
				"오셨어요. 손이 파래질 거예요. 그게 이 일이에요.",
				"새 사람, 오늘은 쪽물이에요. 천은 세 번 담갔다 꺼내요.",
			],
			"known": [
				"물감 사람 왔네요. 어제 그 천, 색이 곱게 섰어요.",
				"손이 아직 파랗네요. 물들이터 사람 티가 나요.",
			],
			"master": [
				"우리 물감쟁이 왔다. 이제 색은 눈으로 봐도 알죠?",
				"우리 물감쟁이 없으면 붉은 물은 저 혼자 못 내요.",
			],
		},
		"hire": {
			"ask": "윤슬 씨, 물들이터에서 일하고 싶어요. 풀 캐는 건 익숙해요.",
			"refuse_aff": "아직 서로 잘 모르잖아요. 물소리나 더 듣고 와요.",
			"refuse_skill": "물감은 풀에서 나요. 채집이 손에 익거든 다시 와요.",
			"refuse_busy": "다른 데서 일하고 있잖아요. 물감은 손이 두 개 다 필요해요.",
			"accept": "좋아요. 내일 아홉 시에 개울가로 와요. 소매는 걷고요.",
			"first_day": "첫날이에요. 오늘은 물만 끓여요. 색은 내일부터.",
			"resign_ask": "윤슬 씨, 물들이터 일은 그만둘게요.",
			"resign_reply": "그래요. 손에 든 물은 한 달은 가요. 그동안은 우리 사람이에요.",
			"fired": "이레를 안 왔어요. 물은 식으면 못 써요. 이제 안 와도 돼요.",
		},
		"loop": [
			{
				"customer": "brook",
				"setup": "도담이 하얀 천을 들고 왔다. 「물고기 색으로 물들여 줄 수 있어요?」",
				"choices": [
					["쪽물 위에 노랑을 한 번 얹는다", "윤슬: 어머, 은어 색이네요. 그 생각을 어떻게 했어요?", 1],
					["쪽물만 곱게 낸다", "도담: 파랗긴 한데… 물고기는 아니네요. 그래도 고마워요.", 0],
					["그런 색은 없다고 한다", "윤슬: 없긴요. 물감은 섞으라고 있는 거예요.", -1],
				],
			},
			{
				"customer": "beekeep",
				"setup": "꿀비가 밀랍 한 덩이를 내민다. 「이걸로 무늬를 낼 수 있대서요.」",
				"choices": [
					["밀랍으로 무늬를 막고 물들인다", "꿀비: 벌집 무늬다! 우리 벌들이 좋아하겠어요.", 1],
					["밀랍은 값으로 치고 그냥 물들인다", "꿀비: 아… 무늬는요? 다음에 해 주실래요?", -1],
					["윤슬 씨에게 물어보고 한다", "윤슬: 잘 물었어요. 밀랍은 뜨거우면 녹아요. 같이 해요.", 0],
				],
			},
		],
	},
	"sawyer_hand": {
		"name": "톱질터 일꾼",
		"kind": "clerk",
		"inst": "sawmill",
		"rank": "hand",
		"boss": "sawyer",
		"wage": 80,
		"known_at": 14,
		"skill": "forest",
		"skill_lv": 2,
		"books": 0,
		"slice": 3,
		"calls": {
			"stranger": "톱질터 새 사람",
			"known": "톱질꾼 {ho}",
			"master": "우리 톱질꾼",
		},
		"boss_calls": {
			"stranger": [
				"왔군. 톱은 밀 때 힘주는 게 아니야. 당길 때야.",
				"새 사람, 큰나무는 쳐다보지도 마. 여기 규칙이야.",
			],
			"known": [
				"톱질꾼 왔네. 어제 켠 판이 곧더군. 손이 붙었어.",
				"톱질꾼, 오늘은 소나무야. 진이 많으니 톱날 자주 닦아.",
			],
			"master": [
				"우리 톱질꾼 왔어. 이제 톱 소리만 들어도 자네인 줄 알아.",
				"우리 톱질꾼 없으면 나 혼자 켜다 허리 나가.",
			],
		},
		"hire": {
			"ask": "동백 어른, 톱질터에서 일하고 싶습니다. 나무는 좀 베어 봤습니다.",
			"refuse_aff": "누군지도 모르는 사람한테 톱을 맡기나. 더 보고 말하지.",
			"refuse_skill": "도끼도 안 익은 손이 톱을 잡아. 나무부터 더 베고 와.",
			"refuse_busy": "딴 데 이름이 올라 있잖아. 톱은 두 팔이 다 필요해.",
			"accept": "그래. 내일 아침 아홉 시. 장갑은 내가 주지.",
			"first_day": "첫날이야. 오늘은 톱날만 갈아. 켜는 건 내일부터.",
			"resign_ask": "동백 어른, 톱질터 일은 그만두겠습니다.",
			"resign_reply": "그래. 톱은 두고 가. 손에 밴 소리는 가져가고.",
			"fired": "이레를 안 왔어. 톱은 녹슬어. 이제 안 와도 돼.",
		},
		"loop": [
			{
				"customer": "teller",
				"setup": "글샘이 널빤지 하나를 부탁한다. 「이야기 판을 세우려고요. 얇게요.」",
				"choices": [
					["결 따라 얇게 켠다", "글샘: 가볍다! 이 판 위에 오늘 밤 이야기를 걸게요.", 1],
					["튼튼하게 두껍게 켠다", "글샘: 무겁네요… 그래도 오래는 가겠어요.", 0],
					["널빤지는 안 판다고 한다", "동백: 이웃 부탁을 그렇게 자르나. 내가 켜 줄게.", -1],
				],
			},
			{
				"customer": "beekeep",
				"setup": "꿀비가 벌통 판을 재러 왔다. 「벌들이 좁다고 웅웅대요.」",
				"choices": [
					["치수를 재서 같은 판을 넷 켠다", "꿀비: 딱 맞아요. 벌들이 오늘 밤은 조용하겠네요.", 1],
					["남은 판을 그냥 준다", "꿀비: 크기가 다르면 바람이 들어요… 다시 잴게요.", -1],
					["동백 어른에게 넘긴다", "동백: 벌통은 내가 켜지. 자네는 옆에서 봐 둬.", 0],
				],
			},
		],
	},
	"weaver_hand": {
		"name": "베틀 일꾼",
		"kind": "clerk",
		"inst": "loom",
		"rank": "hand",
		"boss": "weaver",
		"wage": 80,
		"known_at": 14,
		"skill": "farm",
		"books": 0,
		"slice": 3,
		"calls": {
			"stranger": "베틀 새 사람",
			"known": "베틀 {ho}",
			"master": "우리 베틀 사람",
		},
		"boss_calls": {
			"stranger": [
				"오셨어요. 베틀은 소리로 배워요. 오늘은 듣기만 해요.",
				"새 사람, 북은 던지는 게 아니라 건네는 거예요.",
			],
			"known": [
				"베틀 사람 왔네요. 어제 짠 데가 고르더라고요.",
				"베틀 사람, 오늘은 무명이에요. 실이 잘 끊기니 천천히.",
			],
			"master": [
				"우리 베틀 사람 왔다. 이제 북 소리가 둘이 나요.",
				"우리 베틀 사람 없으면 이 필은 겨울까지 못 끝내요.",
			],
		},
		"hire": {
			"ask": "솜이 씨, 베틀 일을 배우고 싶어요. 밭일 하던 손이라 느리진 않아요.",
			"refuse_aff": "아직 서로 잘 모르잖아요. 좀 더 이야기하고 나서요.",
			"refuse_skill": "실은 밭에서 와요. 농사가 좀 더 익거든 다시 와요.",
			"refuse_busy": "다른 데서 일하고 있잖아요. 베틀은 하루를 다 먹어요.",
			"accept": "좋아요. 내일 아홉 시에 우리 집으로 와요. 북은 제가 드릴게요.",
			"first_day": "첫날이에요. 오늘은 실만 걸어요. 짜는 건 내일부터.",
			"resign_ask": "솜이 씨, 베틀 일은 그만둘게요.",
			"resign_reply": "그래요. 짜던 필은 제가 마저 할게요. 고마웠어요.",
			"fired": "이레를 안 왔어요. 실이 다 늘어졌어요. 이제 안 와도 돼요.",
		},
		"loop": [
			{
				"customer": "forest_mom",
				"setup": "연화가 솔이 치수를 적어 왔다. 「겨울 옷감을 한 필만요.」",
				"choices": [
					["두툼한 무명으로 짠다", "연화: 따뜻하겠네요. 솔이가 올겨울은 안 떨겠어요.", 1],
					["얇은 삼베로 짠다", "연화: 삼베는… 여름 것 아닌가요? 겨울인데.", -1],
					["솜이 씨에게 고르게 한다", "솜이: 무명이죠. 잘 물었어요. 같이 걸어요.", 0],
				],
			},
			{
				"customer": "florist",
				"setup": "해솔이 꽃물 든 실타래를 가져왔다. 「이걸로 띠 하나 짤 수 있을까요?」",
				"choices": [
					["꽃무늬를 넣어 띠를 짠다", "해솔: 어머, 꽃이 피었네요. 축제 때 두를게요.", 1],
					["민무늬로 짠다", "해솔: 예쁘긴 한데… 꽃물 든 실이 아깝네요.", 0],
					["띠는 안 짠다고 한다", "솜이: 띠는 반나절이면 돼요. 이웃 부탁은 받아요.", -1],
				],
			},
		],
	},
	# 자유직 목수(S3c) — 제작대에서 완성한 것이 마흔이면 불린다
	"carpenter": {
		"name": "목수",
		"kind": "free",
		"inst": "",
		"stat": "things_built",
		"slice": 3,
	},
}

# 자유직 문턱 8 — stat 값(사전이면 합)이 need 를 넘으면 불린다. 여럿이면 value/need 비율 최대(D16).
# "animals" 만 통계가 아니라 런타임 animals_now(가축 수)다.
const FREE_TITLES := {
	"farmer": {
		"name": "농부",
		"stat": "crops_harvested",
		"need": 100,
		"known_m": "농부 총각",
		"known_f": "농부 처자",
		"master": "우리 마을 농부 양반",
	},
	"fisher": {
		"name": "어부",
		"stat": "fish_caught",
		"need": 50,
		"known_m": "어부 총각",
		"known_f": "어부 처자",
		"master": "우리 마을 어부 양반",
	},
	"logger": {
		"name": "벌목꾼",
		"stat": "trees_chopped",
		"need": 150,
		"known_m": "나무꾼 총각",
		"known_f": "나무꾼 처자",
		"master": "우리 마을 나무꾼",
	},
	"miner": {
		"name": "광부",
		"stat": "rocks_mined",
		"need": 150,
		"known_m": "광부 총각",
		"known_f": "광부 처자",
		"master": "우리 마을 광부 양반",
	},
	"cook": {
		"name": "요리사",
		"stat": "recipes_cooked",
		"need": 60,
		"known_m": "요리사 총각",
		"known_f": "요리사 처자",
		"master": "우리 마을 요리사",
	},
	"rancher": {
		"name": "목장주",
		"stat": "animals",
		"need": 6,
		"known_m": "목장주 총각",
		"known_f": "목장주 처자",
		"master": "우리 마을 목장주",
	},
	"herbalist": {
		"name": "약초꾼",
		"stat": "forage_caught",
		"need": 80,
		"known_m": "약초꾼 총각",
		"known_f": "약초꾼 처자",
		"master": "우리 마을 약초꾼",
	},
	"cave_hunter": {
		"name": "동굴꾼",
		"stat": "mob_kills",
		"need": 100,
		"known_m": "동굴꾼 총각",
		"known_f": "동굴꾼 처자",
		"master": "우리 마을 동굴꾼",
	},
	"carpenter": {
		"name": "목수",
		"stat": "things_built",
		"need": 40,
		"known_m": "목수 총각",
		"known_f": "목수 처자",
		"master": "우리 마을 목수",
	},
}

# 호칭 cls 별 공용 첫마디 — NPC_CALLS 에 그 cls 가 없을 때. stranger 는 셋으로 갈린다:
# 직업이 있으면 stranger_job, 없으면 day < 28 stranger_new / 그 뒤 stranger_old.
# wary(평판 −20 아래)·bold_high(대범함 75 이상)는 접두가 아니라 줄 자체다(부록 §2).
const CALL_FALLBACK := {
	"murderer": [
		"…가까이 오지 마세요. 할 말 없어요.",
		"사람을 죽인 손으로… 인사는 됐어요. 지나가요.",
		"살인자하고 한 마을에 산다는 게 아직도 안 믿겨요.",
	],
	"seen": [
		"…그쪽하고는 할 말 없어요.",
		"그날 내가 뭘 봤는지, 그 사람이 더 잘 알 텐데요.",
		"볼일 있으면 빨리 끝내요. 오래 붙잡지 말고요.",
	],
	"heard": [
		"아… 소문의 그 사람이죠? 얘기는 들었어요.",
		"그쪽 얘기가 요즘 마을에 좀 돌아요. 조심히 다녀요.",
		"…소문이 소문으로 끝나길 바라요. 그게 다예요.",
	],
	"jailed": [
		"그 일 있던 사람… 맞죠? 얼굴이 좀 상했네요.",
		"다시 보네요. 이제는 조용히 지내요.",
		"그 일은 그 일이고… 오늘 처음 봤으니 인사는 할게요.",
	],
	"office": [
		"어, {title} 오셨습니까. 오늘 처음 뵙네요.",
		"{title}, 일 나가시는 길이에요? 수고 많으세요.",
		"바쁘실 텐데 {title}도 여기까지 다 오셨네요.",
	],
	"ex": [
		"{title} 아니세요? 이제 그 일은 안 하신다면서요.",
		"{title}도 이제 한가하신 얼굴이네요. 좀 낯설어요.",
		"{title}, 그 자리 비우신 뒤로는 어떠세요? 잠은 잘 주무세요?",
	],
	"free_master": [
		"{title} 오셨네요. 오늘도 손이 바쁘시죠?",
		"{title}, 얼굴만 봐도 마음이 놓여요. 나만 그런 거 아니에요.",
		"{title} 안 보이면 마을이 허전해요. 잘 오셨어요.",
	],
	"free_known": [
		"어, {title} 왔네요. 오늘은 벌써 한 바퀴 돌았어요?",
		"{title}, 요즘 손이 쉴 새가 없던데요. 몸도 챙겨요.",
		"{title} 얘기는 마을에서 다들 해요. 부지런하다고.",
	],
	"name": [
		"{name}, 오늘 처음 보네요. 잘 지냈어요?",
		"어, {name}! 마침 생각하고 있었는데.",
		"{name} 왔네요. 얼굴 보니 하루가 좀 풀리네요.",
	],
	"stranger_new": [
		"새로 온 {ho} 맞지? 마을 길은 좀 익었나.",
		"{ho}, 온 지 며칠 됐다지? 인사가 늦었네. 잘 지내 보세.",
		"이 시간에 밖에 있네, 새로 온 {ho}. 여긴 해 지면 금방 캄캄해.",
	],
	"stranger_old": [
		"젊은이, 오늘도 바쁜가. 얼굴은 알겠는데 이름이 안 떠오르네.",
		"젊은이, 밭은 잘 되나? 아직 통성명도 못 했네.",
		"그 집 젊은이지? 지나가는 건 몇 번 봤어.",
	],
	"wary": ["…자네가 왜 여기 있나.", "…볼일만 보고 가지.", "…무슨 낯으로 또 왔나."],
	"bold_high": [
		"…눈빛이 예전 같지 않네.",
		"요즘 밤에 밖에서 봤다는 사람이 많던데. 잠은 자고 다니나.",
		"애들이 요즘 {ho} 보면 길을 비키더라. 알고는 있나.",
	],
	"stranger_job": ["{title} 왔구먼. 일은 할 만한가.", "어, {title}. 아침부터 부지런하네.", "{title} 맞지? 요즘 자주 보이네."],
}

# 27명 × {name, free_known, seen} — NPCS 리터럴은 손대지 않고 여기 따로 둔다.
# seen 줄 대부분은 {title} 이 없다 — 「그 사람」을 입에 올리지 않는 말투가 설계다.
# 없는 cls 는 CALL_FALLBACK 로 떨어진다.
const NPC_CALLS := {
	"merchant": {
		"name": [
			"{name}! 딱 맞춰 왔네. 방금 새 물건 풀었어.",
			"{name}, 잘 왔어. 장부 보다 졸 뻔했잖아.",
			"어, {name}. 이 시간에 웬일이야? 문 닫기 전에 잘 왔어.",
		],
		"free_known": [
			"어서 와, {title}! 오늘은 뭐 사러 왔어, 팔러 왔어?",
			"{title}, 아침부터 일하고 온 얼굴이네. 앉았다 가.",
			"손님들이 {title} 얘기를 하더라. 내 단골이라고 자랑했어.",
		],
		"seen": [
			"...그 사람이네. 진열대에서 좀 떨어져서 서.",
			"그쪽 손, 내가 똑똑히 봤어. 두 번은 없어.",
			"살 거 있으면 골라. 없으면 그냥 가.",
		],
	},
	"fisher": {
		"name": [
			"{name}, 왔어. 조용히 앉아. 지금 입질 오는 중이야.",
			"{name}, 오늘 물빛 봤어? 이런 날은 큰 놈이 나와.",
			"어, {name}. 이 밤에? ...등불은 좀 낮춰.",
		],
		"free_known": [
			"{title}, 여긴 웬일이야. 오늘 일은 다 끝냈어?",
			"{title}, 잠깐 앉았다 가. 일한 사람한텐 물소리가 약이야.",
			"사람들이 {title} 얘기를 하던데. 나야 뭐, 낚시나 하지.",
		],
		"seen": [
			"...왔어. 거기 서. 더 가까이는 말고.",
			"그날 그쪽 손, 내가 봤어. 나도, 물도 잊지 않아.",
			"오늘은 입질 없어. 그냥 가.",
		],
	},
	"rancher": {
		"name": [
			"{name}! 소들이 아까부터 문 쪽만 보더라. 왔구나.",
			"{name}, 저녁 바람 좋지? 같이 울타리나 한 바퀴 돌자.",
			"비 오는데 {name}까지 젖었네. 축사 들어와, 따뜻해.",
		],
		"free_known": [
			"{title}, 우리 애들도 알아. 일하는 사람은 냄새부터 달라.",
			"{title}, 손 봐. 그렇게 될 때까지 얼마나 일한 거야.",
			"동네에서 {title} 소리 들었어. 우리 애들한테도 그렇게 말해 뒀어.",
		],
		"seen": [
			"...애들이 먼저 알아봤어. 봐, 다 뒤로 물러섰잖아.",
			"애들 앞에서 그랬어. 애들은 그런 손 안 잊어. 나도.",
			"울타리 밖에서 얘기해. 이쪽으로 넘어오지 말고.",
		],
	},
	"blacksmith": {
		"name": [
			"{name}, 왔군. 잠깐 불 좀 봐 주게, 금방 오겠네.",
			"{name}인가. 망치 소리에 발소리가 묻혔군.",
			"{name}, 오늘은 광석 없나? 없으면 그냥 앉게.",
		],
		"free_known": [
			"{title}, 연장은 안 무뎌졌나? 무뎌지면 가져오게.",
			"{title} 손이 다 됐군. 쇠는 그런 손을 알아봐.",
			"{title}, 비 오는 날은 쉬나? 화덕 앞 자리 비었네.",
		],
		"seen": [
			"...그쪽 손, 그런 데 쓰라고 있는 손이 아닐 텐데.",
			"볼일 없으면 가게. 화덕 앞은 좁아.",
			"광석이면 두고 가게. 얘기는 됐어.",
		],
	},
	"chief": {
		"name": [
			"{name}, 잘 잤나. 광장 게시판은 봤고?",
			"오, {name}. 마침 자네 얘기를 하던 참일세.",
			"{name}, 자네 할아버지도 이맘때면 이 앞을 지났지.",
		],
		"free_known": [
			"{title}, 요즘 일은 잘 되나? 마을에 자네 얘기가 돌더구먼.",
			"{title}, 왔구먼. 게시판에 부탁 하나 올려뒀네.",
			"{title}, 다음 잔치엔 자네 것도 한 상 올려 보게.",
		],
		"seen": [
			"...봤네. 이 마을에서 그런 짓을 볼 줄은 몰랐구먼.",
			"할 말이 있으면 회관에서 듣지. 여기선 말고.",
			"할아버지 얘기는 오늘 안 하겠네. 가 보게.",
		],
	},
	"postman": {
		"name": [
			"{name}, 마침 잘 왔네. 첫 배달 나가는 길에 얼굴 보니 좋구먼.",
			"{name}, 오늘 배달은 끝났으니 좀 앉아 얘기하세.",
			"{name}, 비 오는데 어딜 가나? 편지는 젖어도 소식은 안 젖지.",
		],
		"free_known": [
			"{title}, 자네 소문이 편지보다 빨리 돌더구먼.",
			"{title}, 해 뜨기 전부터 나왔나? 나랑 비슷하구먼.",
			"{title} 얘기를 편지에 썼더니 이사 오겠다는 답이 왔네.",
		],
		"seen": [
			"...봤네. 그런 손엔 편지도 못 맡기겠구먼.",
			"그쪽 앞으로 온 건 없네. 가 보게.",
			"배달 중일세. 길 좀 비켜 주게.",
		],
	},
	"librarian": {
		"name": [
			"{name}, 왔군요. 오늘은 서가 정리가 금방 끝나겠어요.",
			"{name}, 밤늦게까지 읽었죠? 눈이 빨개요. 오늘은 일찍 쉬어요.",
			"{name}, 빗소리 들려요? 오늘은 책이 잘 읽히는 날이에요.",
		],
		"free_known": [
			"{title}, 아침부터 부지런하네요. 그래서 다들 그리 부르나 봐요.",
			"이 마을 기록에 {title} 이야기가 한 줄 늘었어요. 좋은 쪽으로요.",
			"일 마치고 온 거죠, {title}? 책은 손 닦고 만져 주세요.",
		],
		"seen": [
			"...그쪽이군요. 본 건 적어 뒀어요. 기록은 안 잊으니까요.",
			"...읽을 책이 있으면 저쪽에요. 저는 정리할 게 있어서요.",
			"그 사람이 왔네요. ...오늘은 문을 일찍 닫을 거예요.",
		],
	},
	"explorer": {
		"name": [
			"{name}! 마침 잘 왔어. 오늘은 어느 쪽으로 가 볼까?",
			"야, {name}. 별 뜬 거 봤어? 이런 밤엔 걷기만 해도 모험이야.",
			"{name}, 비 오면 동굴이 딱이야. 밑에선 젖을 일이 없거든!",
		],
		"free_known": [
			"{title}! 다들 그렇게 부르길래 나도 불러 봤어. 어때, 괜찮지?",
			"{title}, 매일 같은 일 어떻게 해? 난 하루만 해도 근질근질할 텐데.",
			"{title}, 내 지도에 네 일터도 표시해 뒀어. 잘 찾아가라고!",
		],
		"seen": [
			"...봤어. 그날. 지도 밖은 재밌어도 그런 건 아니야.",
			"그쪽이랑은 같이 안 가. 혼자가 편해.",
			"오늘은 반대쪽으로 갈래. ...그 사람이 있으니까.",
		],
	},
	"forest_mom": {
		"name": [
			"{name}, 이슬 마르기 전에 왔네요. 솔이가 문 앞에서 기다려요.",
			"{name}, 이 시간에 숲길은 차요. 차 한 잔 하고 내려가요.",
			"비 오는 날인데도 왔네요, {name}. 약초 향이 오늘따라 짙어요.",
		],
		"free_known": [
			"{title}, 마을에선 그리 부른다면서요. 여기까지 소문이 왔어요.",
			"{title}, 일 마친 손이네요. 약초 달인 물에 담그면 좀 풀려요.",
			"{title}, 아침부터 숲길을요? 부지런한 사람이 오면 솔이도 일찍 일어나요.",
		],
		"seen": [
			"...그쪽. 왜 그랬어요. 여긴 조용히 살려고 온 곳이에요.",
			"솔이는 오늘 안 나와요. 돌아가 주세요.",
			"문은 닫아 둘게요. 그 사람이 있는 동안은요.",
		],
	},
	"forest_girl": {
		"name": [
			"{name}! 산딸기잼 냄새 나죠? 헤헤, 오늘은 제가 저었어요.",
			"{name}, 있잖아요. 오늘 아침엔 새소리 아홉까지 셌어요!",
			"{name}, 비 오는 날은 창가에서 기다렸어요. 올 줄 알았죠. 헤헤.",
		],
		"free_known": [
			"{title}! 아침에 창문으로 나가는 거 봤어요. 손 흔들었는데.",
			"비 오는데도 일하고 왔어요? {title}도 감기 조심해요, 저처럼 되면 안 돼요.",
			"{title}, 다 나으면 하루만 일하는 거 구경 가도 돼요? 딱 하루만요.",
		],
		"seen": [
			"봤어요. 창문으로 다 봤어요. 그런 거 하면 안 되는 거잖아요.",
			"…엄마가 그쪽이랑은 말하지 말랬어요.",
			"다람쥐가 숨었어요. 그쪽이 오면 늘 그래요.",
		],
	},
	"farmer": {
		"name": [
			"{name}, 아침 이슬 밟고 나왔구먼. 그래야 작물이 자네 발소리를 알지.",
			"비 오는 날은 쉬는 게 농사야, {name}. 거름이나 뒤집어 두게.",
			"{name}, 해 떨어졌는데 아직 안 들어갔나? 밭은 내일도 거기 있네.",
		],
		"free_known": [
			"{title}, 그렇게 불리려면 손에 굳은살부터 박여야지. 자네 손 좀 보세.",
			"해 뜨면 나가고 해 지면 들어오고 — {title}도 이제 그 맛을 알겠구먼.",
			"{title}, 비 오는 날은 쉬게. 땅도 사람도 숨 돌릴 때가 있어야지.",
		],
		"seen": [
			"봤네. 남의 것에 손대는 건 농사꾼이 제일 싫어하는 짓이야.",
			"그쪽하고는 할 말 없네. 밭이나 보러 가야겠어.",
			"우리 밭 근처엔 오지 말게. 그것만 부탁하지.",
		],
	},
	"foodie": {
		"name": [
			"{name}! 딱 맞춰 왔네~ 방금 만수네서 신상 빵 사 왔거든. 반 줄까?",
			"비 오는 날엔 국물이지~ {name}, 너 집에 냄비는 있지?",
			"{name}, 저녁 아직이지? 맛있는 거 먹을 때 세상이 다 예뻐 보인댔잖아~",
		],
		"free_known": [
			"{title}! 오~ 그렇게 불리니까 딱이다. 근데 밥은 먹고 다녀?",
			"{title}, 일 끝나고 뭐 먹어? 그게 제일 궁금해. 진짜야.",
			"만수네 신상 나왔대! {title}, 같이 가자. 이건 못 참지.",
		],
		"seen": [
			"봤어. 그건 아니지. 아무리 배고파도 그건 아니야.",
			"…오늘은 나눠 먹을 기분 아니야. 그쪽이랑은.",
			"…됐어. 그쪽 얘긴 안 할래. 밥이나 먹으러 갈래.",
		],
	},
	"angler": {
		"name": [
			"{name}, 오늘 물 좋다. 낚싯대 하나 더 있는데 옆에 앉을래?",
			"어, {name}! 어제 놓친 놈 얘기 들어 볼래? 이만~했다니까, 진짜야.",
			"비 오는데 {name} 왔네. 이런 날 고기가 더 문다니까. 물멍이나 하자.",
		],
		"free_known": [
			"{title}, 손이 벌써 일꾼 손이네. 그래도 가끔은 물가 와서 쉬어.",
			"요즘 마을에 {title} 얘기 제법 돌더라. 용식 씨보다 먼저 유명해지겠어.",
			"{title}, 기다릴 줄 아는 사람은 뭘 해도 돼. 낚시나 일이나 같지.",
		],
		"seen": [
			"…봤어. 그쪽이 남의 걸 슬쩍하는 거. 두 번은 말 안 해.",
			"물가는 넓어. 그쪽은 저쪽 끝에서 해.",
			"…입질 얘기는 다음에. 오늘은 말고.",
		],
	},
	"miner": {
		"name": [
			"{name}, 잘 왔어. 오늘 캔 거 좀 봐. 이 결이 예사롭지 않다니까.",
			"비 오는 날엔 굴이 울어. {name}, 오늘은 깊이 들어가지 마.",
			"킁킁, {name} 온 줄 알았지. 내 코가 광석만 맡는 게 아니라니까.",
		],
		"free_known": [
			"{title}, 손바닥 좀 보자. …됐어, 굳은살이 대신 말해 주는구먼.",
			"{title}, 두드린 만큼 나오지? 돌이든 땅이든 물이든 거짓말은 안 해.",
			"{title}도 어깨가 뻐근하겠구먼. 몸으로 버는 사람끼리는 알지.",
		],
		"seen": [
			"…돌은 거짓말을 안 하는데, 사람은 하는구먼. 그쪽 얘기야.",
			"할 말 없구먼. 곡괭이나 손질해야겠어.",
			"굴은 깊고 어두워. 그쪽은 내 뒤에 서지 마.",
		],
	},
	"florist": {
		"name": [
			"{name}, 안녕하세요! 오늘 아침 창가 화분이 처음 피었어요.",
			"{name}, 비 오는 날은 꽃이 제일 예뻐요. 잠깐만 같이 봐요.",
			"{name} 어깨에 나비 앉았었어요. 좋은 사람이란 뜻이에요, 진짜예요.",
		],
		"free_known": [
			"{title}, 일하고 오셨죠? 옷에서 좋은 냄새가 나요. 일한 냄새요.",
			"{title}, 마을 사람들이 다 그렇게 불러요. 이름이 하나 더 생긴 거예요!",
			"{title}, 너무 애쓰지 마세요. 꽃도 하루는 쉬어야 피어요.",
		],
		"seen": [
			"…봤어요, 그날. 나비도 그쪽엔 안 앉더라고요.",
			"화분은 만지지 마세요. 부탁이에요.",
			"…시든 꽃도 씨앗은 남겨요. 그건 그 사람 몫이에요.",
		],
	},
	"carpenter": {
		"name": [
			"{name}, 아침부터 부지런하구먼. 대패질 소리 시끄러우면 말하게.",
			"{name}, 비 오는 날은 나무가 운다네. 문짝 뻑뻑하면 들르게.",
			"해 떨어지네, {name}. 톱밥 털고 나도 이제 들어가야겠어.",
		],
		"free_known": [
			"{title}, 아침부터 손이 바쁘구먼. 굳은살 박인 손이 제일 믿을 만하지.",
			"{title}, 그 일도 못 박듯 제자리에 해야 오래 가네. 집이나 사람이나.",
			"{title}, 이 비엔 쉬게. 연장도 쉬어야 날이 서는 법일세.",
		],
		"seen": [
			"그쪽 손은 그렇게 쓰는 손이었나. 못 하나 박을 손인 줄 알았네.",
			"……볼일 없으면 가게. 나무 재는 중일세.",
			"……망치 소리 시끄러우면 다른 길로 가게. 그편이 서로 편하네.",
		],
	},
	"herbalist": {
		"name": [
			"{name}, 이슬 마르기 전에 나왔네요. 약초 캐기 딱 좋은 아침이에요.",
			"{name}, 비 맞고 다니면 몸 식어요. 생강차 한 잔 우려 드릴게요.",
			"{name}, 오늘 안색이 좋네요. 잘 자는 게 제일가는 약이랍니다.",
		],
		"free_known": [
			"{title}, 아침부터 일이에요? 이슬 밟은 신발 보니 알겠네요.",
			"{title}, 다들 그렇게 부르더라고요. 부지런한 사람한테 붙는 이름이죠.",
			"{title}, 안색이 좀 탔네요. 저녁엔 차 한 잔 우려 드릴까요?",
		],
		"seen": [
			"쓴 풀은 약이 되지만, 그쪽이 한 일은 약이 안 돼요.",
			"……차는 안 드릴게요. 볼일 보고 가세요.",
			"……바구니 끈을 쥐게 되네요, 그쪽이 오면.",
		],
	},
	"painter": {
		"name": [
			"{name}, 오늘 아침 빛은 노랗네요. 그 얼굴도 덩달아 밝고요.",
			"{name}! 노을 보러 왔어요? 이 빨강은 오늘만 있는 겁니다.",
			"비 오면 색이 다 가라앉아요, {name}. 그래도 회색은 회색대로 그려야죠.",
		],
		"free_known": [
			"{title}, 일하는 뒷모습 한 장 그려도 됩니까? 좋은 선이 나와요.",
			"{title}, 해 질 녘 돌아오는 걸 봤어요. 하루 다 쓴 사람 색이더군요.",
			"{title}, 이 비에도 나왔어요? 젖은 어깨도 그림이 되긴 합니다만.",
		],
		"seen": [
			"그쪽 손은 붓 잡는 손이 아니더군요. 남의 주머니로 가던데요.",
			"……그림에 그 사람은 안 넣을 겁니다. 그뿐이에요.",
			"캔버스 앞은 비켜 주시죠. 빛이 가립니다.",
		],
	},
	"musician": {
		"name": [
			"{name}! 좋은 아침이에요. 오늘 첫 곡은 뭘로 할까요?",
			"{name}, 광장에서 연습 중이에요. 듣고 싶은 곡 있으면 말해요.",
			"빗소리가 반주 같죠, {name}? 오늘은 느린 곡으로 갈게요.",
		],
		"free_known": [
			"{title}, 일하는 소리에도 박자가 있더라고요. 좋은 리듬이었어요.",
			"{title} 얘기, 마을에서 자주 들려요. 노래로 만들어 볼까요?",
			"해 질 녘엔 {title}도 쉬어야죠. 한 곡 불러 드릴까요?",
		],
		"seen": [
			"...봤어요. 그날 그쪽 손이 어디로 갔는지.",
			"미안하지만 오늘은 그쪽 앞에서 연주 안 해요.",
			"지나가세요. 곡이 끊겨요.",
		],
	},
	"weaver": {
		"name": [
			"{name}, 소매 또 뜯어졌네요. 이따 이리 줘 봐요.",
			"{name} 목도리는 무슨 색으로 뜰까요? 겨울 오기 전에요.",
			"비 오면 실이 눅눅해요. {name}, 안에서 차 한잔 해요.",
		],
		"free_known": [
			"{title}, 일하다 옷 해지면 가져와요. 금방 기워요.",
			"{title}, 어깨가 굳었네요. 베틀 앞에 앉은 제 어깨 같아요.",
			"마을이 천이라면 {title}도 한 올이죠. 이제 빠지면 티 나요.",
		],
		"seen": ["...봤어요. 남의 것에 손대는 거.", "그쪽 소매는 안 기워요. 됐어요.", "베틀이 바빠요. 그만 가 봐요."],
	},
	"alchemist": {
		"name": [
			"{name}, 오늘 달이 좋아요. 밤에 솥을 걸 생각이에요.",
			"{name}... 약초 냄새가 나네요. 들에 다녀왔군요.",
			"비 오는 날 여기까지요? {name}, 재료는 도망 안 가는데.",
		],
		"free_known": [
			"{title}... 마을이 붙여 준 이름이군요. 그분한테도 있었어요.",
			"{title} 손, 많이 거칠어졌네요. 재료를 아는 손이에요.",
			"소문이 숲까지 와요. {title} 얘기, 바람이 물어다 주더군요.",
		],
		"seen": [
			"...봤어요. 연금술은 정직한데, 그쪽은 아니었네요.",
			"솥이 바빠요. 오늘은 돌아가요.",
			"오두막 문은 열려 있어요. 그쪽한텐 아니지만.",
		],
	},
	"miller": {
		"name": [
			"어이, {name}! 물소리 뚫고 잘 왔어. 손은 밀가루니까 악수는 나중에.",
			"{name} 왔나. 방아 소리 크지? 곁에 와서 크게 말해.",
			"{name}, 먼 길 왔으니 앉아. 폭포 물은 그냥 떠 마셔도 돼.",
		],
		"free_known": [
			"어이, {title}! 교진 소문이 물소리 넘어 여기까지 오더군.",
			"{title} 왔나. 그런 손이면 방아 축 붙잡는 것도 금방 배우겠어.",
			"{title}, 여기까지 오느라 목 탔지? 방앗간 그늘에서 좀 쉬어.",
		],
		"seen": [
			"…그 사람이군. 오늘은 물소리가 커서 말이 안 들려.",
			"남의 것에 손대는 손이랑은 악수 안 해.",
			"방아 근처엔 오지 마. 여긴 전부 남의 곡식이야.",
		],
	},
	"dyer": {
		"name": [
			"{name} 씨 왔네요. 손이 파래서 놀라지 마요, 오늘도 쪽빛이에요.",
			"{name} 씨, 마침 잘 왔어요. 이 색이 잘 나왔는지 좀 봐 줘요.",
			"{name} 씨 목소리는 폭포 소리 속에서도 알아듣겠어요.",
		],
		"free_known": [
			"{title} 오셨네요. 그 옷, 이 물로 한번 물들여 보고 싶어요.",
			"{title}, 교진서 여기까지 왔어요? 천 널어 놓고 얘기해요.",
			"{title} 손은 아직 깨끗하네요. 여기 오래 있으면 파래져요.",
		],
		"seen": [
			"…그쪽이군요. 오늘은 천 널 게 많아서요.",
			"밀가루 묻은 손이 그쪽 손보단 깨끗해. 악수는 됐어.",
			"천 마르는 동안엔 말 안 해요. 그냥 지나가세요.",
		],
	},
	"brook": {
		"name": [
			"{name}! 왔구나! 나 오늘 통나무 또 띄웠어, 보러 가자!",
			"{name}, 있잖아, 나 비밀 하나 더 생겼어. 아무한테도 말하면 안 돼.",
			"{name}도 교진서 여기까지 걸어왔어? 나도 언젠가 반대로 가 볼래.",
		],
		"free_known": [
			"{title}! 교진 사람이지? 교진 얘기 해 줘, 얼마나 커?",
			"{title}, 나 폭포 뒤에 들어간 거 교진 사람들한테 말하면 안 돼!",
			"{title}도 물고기가 폭포 올라가는 거 봤어? 나만 본 거 아니지?",
		],
		"seen": [
			"…폭포 뒤 비밀, 그 사람한텐 절대 안 알려 줄 거야.",
			"남의 거 가져가는 거 나 봤어. 진짜야.",
			"…나 지금 물속에 들어갈 거야. 따라오지 마.",
		],
	},
	"sawyer": {
		"name": [
			"{name}, 왔나. 톱 좀 잡아 봐. 밀지 말고 당겨.",
			"{name}, 자네군. 발소리로 알았어. 숲에선 다 들려.",
			"{name}, 장작 좀 같이 쌓지. 겨울은 혼자 나는 게 아니야.",
		],
		"free_known": [
			"{title}, 손 좀 보여 봐. 굳은살 박힌 자리를 보면 일이 보여.",
			"{title}, 자네 일은 언제가 제철인가. 나무는 겨울이야.",
			"{title}, 장작은 넉넉한가. 일하는 사람이 겨울에 떨면 안 돼.",
		],
		"seen": [
			"봤어. 큰나무도 안 베는 숲이야. 남의 건 말할 것도 없지.",
			"장작은 저기 있어. 세어 놨으니까.",
			"…할 말 없어. 나무나 보고 가.",
		],
	},
	"beekeep": {
		"name": [
			"{name} 씨, 벌들이 이제 안 쏘죠? 얼굴을 외운 거예요.",
			"{name} 씨, 벌통 소리 들어 볼래요? 오늘은 유난히 웅웅거려요.",
			"{name} 씨네 밭에 벌이 다녀왔나 봐요. 꿀에서 꽃 맛이 달라졌어요.",
		],
		"free_known": [
			"{title}, 일하는 사람 냄새는 벌이 먼저 알아요. 안 쏠 거예요.",
			"{title}, 일 마치고 오는 길이에요? 꿀물 한 잔 하고 가요.",
			"{title}, 비 오는 날엔 쉬어요. 벌도 안 나가는 날이니까요.",
		],
		"seen": [
			"벌은 안 훔쳐요. 꽃이 주는 것만 받죠. …그쪽은요.",
			"오늘은 벌통 안 열어요. 그쪽 있을 땐요.",
			"……벌 놀라요. 조용히 지나가 줘요.",
		],
	},
	"teller": {
		"name": [
			"{name} 씨, 어젯밤 잎이 {name} 씨 얘길 했어요. 웃지 말아요.",
			"{name} 씨, 교진 얘기 이어서 해 줘요. 지난번 거기까지 적었어요.",
			"{name} 씨, 오늘은 옆에 앉아 있어도 돼요. 잎이 허락했어요.",
		],
		"free_known": [
			"{title}, 이야기에 새 사람이 하나 늘었어요. 제목은 아직이에요.",
			"{title}, 잎들이 궁금해해요. 매일 무슨 일을 하고 오는지.",
			"{title}, 오래 한 일은 이야기가 돼요. 벌써 그런 얼굴이에요.",
		],
		"seen": [
			"그 손으로 집어 간 건 이야기가 안 돼요. 그냥 도둑질이에요.",
			"그쪽은 저기 앉아요. 나는 여기 있을게요.",
			"……오늘은 잎이 말이 없네요. 그만 가 봐요.",
		],
	},
}

# 이장의 성격 질문·마을 회의·도둑질 서술문(society.gd 가 쓴다).
#   bold_question  lead 한 줄 + choices [{text, base, reply}] — base 가 boldness_base 가 된다
#   meeting        open 은 {victim} 을 npc_def(target).name 으로 치환, options[key pay/deny/confess]
#   theft          선택지 라벨·회색 사유·성공/실패 서술문 3줄(posmod(day, 3))·목격자 한마디
const SOCIETY_LINES := {
	# 순회 재판(S2c) — 판사는 하오체, 검사는 합쇼체. 숫자는 % 로 채운다
	"court": {
		"open": "교진 순회 재판을 연다. 피고는 앞으로 나오게.",
		"charge": "피고는 %s네 빈집에 몰래 들어갔습니다. 본 사람이 %d명입니다.",
		"charge_skips": "재판을 %d번 거른 피고입니다. 가중을 구합니다.",
		"ask": "피고, 할 말이 있는가.",
		"admit_choice": "인정한다",
		"deny_choice": "부인한다",
		"plea_choice": "사정을 말한다",
		"admit": "인정했으니 참작한다.",
		"deny_weak": "본 사람이 주인뿐이다. 그것만으로는 못 묻는다. 무죄.",
		"deny_strong": "본 사람이 %d명입니다. 부인은 거짓 진술입니다.",
		"plea_ok": "마을이 자네를 나쁘게 말하지 않더군. 참작한다.",
		"plea_no": "사정은 누구에게나 있다. 참작할 게 못 된다.",
		"record": "전과가 있는 피고다. 가중한다.",
		"verdict_fine": "벌금 %dG. 고지서로 간다. 이레 안에 면사무소에 내게.",
		"verdict_service": "벌금 %dG 에 봉사 %s. 이장에게 빗자루를 받게.",
		"verdict_jail": "구류 이레. 박 순경이 데려간다.",
		"acquit": "무죄. 피고는 돌아가도 좋다.",
		"leave": "법정을 나선다",
		"follow": "박 순경을 따라간다",
		"docket_open": "오늘 재판은 순경이 넘긴 사건 %d건이다.",
		"docket_line": "%s — %s네 도둑. 벌금 %dG.",
		"docket_none": "오늘은 넘어온 사건이 없다. 마을이 조용했군.",
		"docket_close": "이것으로 오늘 재판을 닫는다.",
		"expunge_ok": "말소했네. 장부에서 지웠어. 마을도 곧 잊을 걸세.",
	},
	# 남의 집 문 앞(빈집 잠입) — 헌법 §6.1 「NPC_SCHEDULE 이 곧 범행 계획」
	"house": {
		"sign": "문패에 %s의 이름이 있다.",
		"knock_choice": "문을 두드린다",
		"sneak_choice": "몰래 들어간다",
		"knock_home": "안에서 %s가 문을 열었다. 「무슨 일인가?」",
		"knock_empty": "문을 두드렸다. 아무도 없다.",
		"gray_home": "안에 사람이 있다.",
		"gray_bold": "남의 집 문고리에 손이 안 간다.",
		"gray_court": "재판이 걸려 있다. 지금은 아니다.",
		"ok": "문이 열렸다. 궤짝에서 %s 하나를 챙겨 나왔다.",
		"fail": "문을 따는데 등 뒤에서 발소리가 났다. 주인이다.",
		"owner_fail": "…내 집에서 뭐 하는 건가. 이장한테 갈 걸세.",
	},
	"bold_question": {
		"lead": "자네 할아버지는 낯선 사람 앞에서도 통 기죽는 법이 없었지. 자네는 어떤가?",
		"choices": [
			{
				"text": "낯을 좀 가려요",
				"base": 10,
				"reply": "그것도 괜찮네. 조심스러운 사람이 오래 가는 법이지.",
			},
			{
				"text": "보통이죠",
				"base": 25,
				"reply": "허허, 보통이 제일 어려운 걸세. 그래, 그렇게 살게.",
			},
			{
				"text": "겁은 별로 없어요",
				"base": 40,
				"reply": "허, 그 말투가 할아버지 그대로구먼. 겁 없는 건 좋네만 몸은 아끼게.",
			},
		],
	},
	"meeting": {
		"summon_note": "아침부터 이장이 집 앞에 서 있었다. 회관에서 보자고 했다.",
		"open": "어제 일은 당한 사람한테서 들었네. 나는 자네 입으로 듣고 싶구먼.",
		"options": [
			{
				"key": "pay",
				"text": "두 배로 물어 주겠다",
				"chief": "돈으로 되는 일이면 다행이지. 가서 얼굴 보고 직접 건네게.",
				"outcome": "물건값의 두 배를 물어 주기로 했다. 사과는 내 입으로 해야 한다.",
			},
			{
				"key": "deny",
				"text": "나는 모르는 일이다",
				"chief": "...그런가. 나는 자네 말을 믿겠네. 마을이 믿을지는 모르겠네만.",
				"outcome": "모르는 일이라고 잡아뗐다. 이장은 더 묻지 않았다. 소문은 남았다.",
			},
			{
				"key": "confess",
				"text": "내가 그랬다",
				"chief": "말해 줘서 고맙네. 회관 마당 사흘, 빗자루를 들게. 그걸로 끝일세.",
				"outcome": "내가 그랬다고 말했다. 사흘 동안 회관을 쓸기로 했다.",
			},
		],
		"service_day": "어제 회관을 쓸었다. 이장이 말없이 물 한 잔을 두고 갔다.",
		"service_done": "사흘째 빗자루를 놓았다. 이장이 「이제 됐네」 하고 어깨를 두드렸다.",
		"forgiven": "그 사람이 한참 나를 보다가 고개를 끄덕였다. 사과는 받겠다고, 한 번뿐이라고 했다.",
		"victim_after": [
			"그 사람이 다시 내 이름을 불렀다. 주머니에 손이 가는 버릇만 남았다.",
			"일은 잘 되냐고 먼저 물어 왔다. 지난 일은 서로 입에 올리지 않았다.",
			"길에서 마주쳤다. 인사는 받아 줬지만 등 뒤에는 서지 말라고 했다.",
		],
	},
	"theft": {
		"pickpocket_choice": "주머니를 노린다",
		"pickpocket_gray": "손이 안 나간다",
		"pickpocket_ok": [
			"스치듯 지나쳤다. 손끝에 동전이 걸렸고, 상대는 돌아보지 않았다.",
			"말을 붙이는 척하며 손을 넣었다 뺐다. 심장이 아직 뛴다.",
			"사람들 틈에 섞여 한 번에 끝냈다. 가벼워진 건 저쪽 주머니뿐이다.",
		],
		"pickpocket_fail": [
			"손목이 잡혔다. 상대가 소리를 질렀고, 주위 사람들이 이쪽을 봤다.",
			"손끝이 닿기도 전에 상대가 홱 돌아섰다. 눈이 마주쳤고, 변명이 안 나왔다.",
			"동전이 손에서 미끄러져 땅에 흩어졌다. 그 소리에 다들 이쪽을 돌아봤다.",
		],
		"shelf_choice": "선반에서 슬쩍한다",
		"shelf_gray_day": "주인이 보고 있다. 손이 안 나간다",
		"shelf_gray_night": "빈 가게인데도 손이 안 나간다",
		"shelf_ok": [
			"주인이 고개를 돌린 사이 물건 하나가 품에 들어왔다.",
			"선반 안쪽 것을 골랐다. 빈자리가 티 나지 않는다.",
			"어둠 속에서 손에 잡히는 대로 챙겼다. 발소리를 죽였다.",
		],
		"shelf_fail": [
			"거기! 그거 내려놔요, 지금 당장!",
			"값은 계산대에서 치르는 거예요. ...품속 말고.",
			"문 닫은 가게에 누구요? 그 손에 든 게 뭐요!",
		],
		"witness": ["...봤어요. 나, 방금 다 봤어요.", "어어, 저기... 저 사람 지금...!", "허. 눈이 있는데 못 본 척은 못 하지."],
		"victim_next_day": [
			"...그쪽이군요. 볼일 없으면 그냥 지나가요.",
			"가까이 오지 마요. 내 주머니는 내가 챙길 테니.",
			"남의 것에 손대고도 얼굴은 들고 다니네요. 이장님께 말해 뒀어요.",
		],
	},
}

# 아침 결산 줄 — society_new_day 의 note 문구는 전부 여기서(title_changed 만 {title} 치환).
const SOCIETY_NOTES := {
	"title_changed": "사람들이 요즘 나를 이렇게 부른다 — {title}.",
	"wage_paid": "봉급날이다. 아직 내 주머니에 든 돈은 아니다 — 가서 받아야 한다.",
	"wage_lost": "받으러 가지 않은 봉급이 그냥 사라졌다.",
	"absent_warn": "사흘째 일터에 나가지 않았다. 나흘만 더 비우면 자리는 없어진다.",
	"fired": "너무 오래 자리를 비웠다. 오늘부터 나갈 일터가 없다.",
	"hired": "일자리를 얻었다. 아홉 시까지 일터로 가면 된다.",
	"service_day": "오늘은 봉사하는 날이다. 이장이 시킨 일을 해야 한다.",
	"service_done": "봉사가 끝났다. 이장이 이 일은 여기서 접자고 했다.",
	"bold_up": "요즘 겁이 없어졌다. 전에는 못 하던 것에 손이 간다.",
	"bold_down": "요즘 다시 조심스러워졌다. 조용히 살다 보니 그렇다.",
	"meeting_summon": "이장이 아침부터 집 앞에 와 있다. 할 말이 있다고 한다.",
	"rumor": "마을에 내 이야기가 돈다. 누가 먼저 말했는지는 모른다.",
	"forgiven": "어제 일은 갚았다. 그 사람이 다시 예전처럼 불렀다.",
	"rep_wary": "요즘 사람들이 나를 보면 먼저 눈을 피한다.",
	# ---- 세금·예산(S2a) ----
	"tax_bill": "납세 고지서가 왔다 — %dG. 이레 안에 면사무소로 가야 한다.",
	"tax_free": "이번 계절 세금은 없다. 지난 계절 수입이 적었다.",
	"tax_dun": "독촉장이 왔다. 밀린 세금에 이자가 붙기 시작했다.",
	"tax_chief": "이장이 세금 이야기로 찾아온다고 한다. 마을에 말이 돌겠지.",
	"tax_freeze": "체납으로 봉급이 멈췄다. 자리는 아직 남아 있다.",
	"tax_seized": "밀린 세금을 대신 가져갔다 — %s.",
	"gov_start": "마을 예산으로 「%s」 공사가 시작됐다.",
	"gov_done": "「%s」이 다 됐다. %s",
	# ---- 파출소(S2b) ----
	"crime_night": "어젯밤 %s네에 도둑이 들었다고 한다. 박 순경이 아침부터 돌고 있다.",
	"case_caught": "박 순경이 %s를 잡았다 — %s네 도둑이었다.",
	"case_expired": "%s네 도둑은 끝내 잡히지 않았다. 마을이 그 얘기를 그만뒀다.",
	"case_mine": "내가 %s를 잡았다 — %s네 도둑. 마을이 봤다.",
	"wanted": "박 순경이 나를 찾고 있다. 회의에서 부인한 그 일 때문이다.",
	"fined": "벌금을 물었다 — %dG. 그 일은 그것으로 끝났다.",
	"surrendered": "파출소에 자수했다. 벌금은 절반이었다. 마을이 그걸 기억할 것이다.",
	# ---- 순회 재판(S2c) ----
	"charged": "박 순경이 아침에 왔다. %s네 일로 기소됐다. 재판은 %s, 회관이다.",
	"court_today": "오늘 순회 재판이다. 윤 판사가 회관에 와 있다. 피고석에 서야 한다.",
	"court_skipped": "어제 재판에 나가지 않았다. 다음 재판일에 가중된다.",
	"court_visit": "오늘 순회 재판이 열린다. 회관에 윤 판사가 와 있다.",
	"convicted": "유죄였다. 마을이 그 판결을 들었다.",
	"acquitted": "무죄였다. 그래도 본 사람은 본 것이다.",
	"jail_out": "이레 만에 파출소를 나왔다. 마을이 그 일을 기억할 것이다.",
	# ---- 자기 상점(S3a) ----
	"shop_sold": "어제 좌판에서 %d개가 팔렸다 — %dG. 좌판 금고에 있다.",
	"shop_none": "어제 좌판에는 손님이 없었다. 값이 비싼가, 물건이 낯선가.",
	"shop_frozen": "밀린 세금으로 좌판이 영업정지다. 세금부터 내자.",
	# ---- 자치회(S3c) ----
	"watch_done": "어젯밤 마을을 세 군데 돌았다. 회관에서 이장에게 보고하면 근무다.",
	"watch_missed": "어젯밤 야경을 돌지 않았다. 마을이 캄캄한 채로 잤다.",
}

# 마음 카드 — [[문턱, 이름, 설명]] · stats_ui 가 이름을 글줄로, 설명을 툴팁으로 쓴다.
const BOLD_STAGES := [
	[0, "조심스러운", ""],
	[20, "손이 굳지 않는", ""],
	[35, "거리낌 없는", ""],
	[55, "무서운 것이 없는", ""],
	[75, "돌아올 수 없는", ""],
]

# ---- 사회: 그 밖의 상수 ----

# 저녁에도 밖에 남는 사람들과 들어가는 시각(분). 박 순경은 야간 순찰이라 자정까지(헌법 §6.2 —
# 밤은 유리하지만 안전하지 않다). society_place 가 저녁 자리를 준다
const NIGHT_OWLS := {"explorer": 22 * 60, "musician": 22 * 60, "angler": 22 * 60,
	"officer_park": 24 * 60}
const NIGHT_OWL_UNTIL := 22.0 * 60.0                      # 옛 이름 — 셋의 기본값
const BOLD_CAP := {"cave": 5.0, "night": 4.0}             # 하루에 오를 수 있는 대범함 — 동굴 처치 / 밤길
const KOR_DAYS := ["하루", "이틀", "사흘", "나흘", "닷새", "엿새", "이레", "여드레", "아흐레", "열흘"]
const CLERK_WAGE := 80        # 근무 한 번에 적립되는 몫(D4)
const WAGE_CAP := 1680        # 주인은 세 주치(80 × 7 × 3)까지만 맡아 둔다 — 봉급날 아침에 넘치는 만큼 사라진다
const ABSENT_WARN := 3        # 사흘 결근 — 아침 결산 경고
const ABSENT_FIRE := 7        # 이레 결근 — 해고(평판 −8)
const MEMORY_MAX := 60        # memories 상한(오래된 것부터)
const WORK_LOG_MAX := 12      # work_log 상한 — 「오늘/어제」만 보면 되므로 짧다
const SEEN_DAYS := [28, 56, 84]   # heat 1/2/3+ 기억이 살아 있는 날수(헌법 §4.2 seen)
const GATE := {"pickpocket": 20, "shelf_night": 35, "shelf_day": 45, "burglary": 35}   # boldness() 문턱(헌법 §5.2)
const SERVICE_LAST_HOUR := 17.0   # 봉사는 17시 전에만 — 시계를 되감지 않으려고(D14)

# ---- 세금·예산(S2a, 헌법 §2) ----
#
# 세금은 「내러 가는 행위」다 — 자동 차감은 압류 하나뿐이다. 정부는 면사무소 창구가
# 열린 계절(story9 done)부터 있다. 그 전엔 세율 0: 정부가 없으면 세금도 없다.
const TAX_FREE_INCOME := 2000      # 지난 계절 수입이 이 아래면 소득세 0
const TAX_INCOME_RATE := 0.10      # 넘으면 전액의 10%(봉급 포함 — 공무원이 세금 안 내면 누가 내나)
const TAX_PROPERTY_HOUSE := 100    # 재산세: 집 단계당
const TAX_PROPERTY_ANIMAL := 20    #          가축 한 마리당
const TAX_DUE_DAYS := 7            # 계절 1~7일 납부
const ARREARS_RATE := 0.05         # 체납 주당 단리
const ARREARS_CAP := 0.50          # 가산 상한
const ARREARS_DUN_WEEK := 2        # 독촉장
const ARREARS_CHIEF_WEEK := 4      # 이장이 먼저 말을 건다 · rep −5
const ARREARS_FREEZE_WEEK := 6     # 봉급 정지(자리는 남는다)
const ARREARS_SEIZE_WEEK := 8      # 압류: 회관 창고 → 가축 → 소지금 · rep −15
const TAX_BILLS_MAX := 6           # 고지서 보관 수
# ---- 파출소·범죄(S2b, 헌법 §6) ----
const CASE_MAX := 20               # 사건 상한
const CASE_TTL := 30               # 시효(일) — 지나면 조용히 닫힌다
const NPC_CRIME_PERIOD := 7        # 교진 NPC 범죄 주기(일) — 후보가 없으면 사건이 안 생긴다
const NPC_CATCH_DAYS := 3          # 신고 며칠 뒤 순경 검거 굴림
const NPC_CATCH_P := 0.5           # 그 확률(야간 순찰이 있는 마을)
const NPC_FINE := 200              # NPC 벌금 — 예산으로
const FINE_MIN := 200              # 즉결 벌금 하한 · 물건값 ×3
const FINE_MULT := 3
const ARREST_TILES := 1.5          # 순경이 이 거리 안에 2초 → 체포
const ARREST_SECONDS := 2.0
const NEED_EVIDENCE := 2           # 검거에 필요한 흔적 수(피해자·목격자)
# ---- 순회 재판(S2c, 헌법 §6.4~6.6) ----
# 계절 7·21일 회관에 윤 판사·한 검사가 온다. heat 2 이상(빈집)은 이장의 회의가 아니라 기소다 —
# 플레이어가 서는 자리는 피고석이다. 즉결(순경)은 heat 1 까지, 그 위는 판사만 형을 정한다
const COURT_DAYS := [7, 21]
const CRIME_HEAT := {"pickpocket": 1, "shelf": 1, "burglary": 2}
const BURGLARY_P := 0.30           # 빈집 문을 따는 기본 확률 — theft_p 가 손버릇·밤·목격자를 얹는다
const JAIL_DAYS := 7               # 구류 — 파출소에서 이레(하루 넘김 일곱 번, 밭은 마른다)
const EXPUNGE_COST := 500          # 전과 말소 인지세(헌법 §2.1)
const EXPUNGE_DAYS := 28           # 형이 끝나고 이만큼 조용히 지내야 말소를 청구할 수 있다
# ---- 자기 상점(S3a, 헌법 §7.4) ----
# 면사무소 「상점 허가」 500G + 그 종류의 숙련 Lv3 + 평판 0 이상 + 일자리 없음. 자리는 집 마당
# 좌판(shop_stand) 하나 — 건물도 실내도 없다(짓기 없음). 손님은 아침 결산이 보낸다: 하루 4~7명,
# 값이 쌀수록·아끼는 물건일수록·좌판 종류에 맞을수록 산다. 판 돈은 좌판 금고(till)에 쌓이고
# E 로 받는다(돈은 창구에서만). 매출세는 지난 28일 매출의 5%(고지서 한 줄)
const SHOP_PERMIT_COST := 500
const SHOP_SKILL_LV := 3
const SHOP_STOCK_KINDS := 8                 # 좌판에 올릴 수 있는 물건 가짓수
const SHOP_LEDGER_DAYS := 28
const SALES_TAX_RATE := 0.05
const SHOP_CUSTOMERS := [4, 7]              # 하루 손님(교진)
const SHOP_PRICE_TIERS := {"cheap": 0.8, "fair": 1.0, "dear": 1.5}
const SHOP_TIER_NAMES := {"cheap": "싸게", "fair": "제값", "dear": "비싸게"}
const SHOP_KINDS := {
	"farm": {"name": "농산물전", "skill": "farm", "desc": "밭에서 난 것"},
	"fish": {"name": "어물전", "skill": "fish", "desc": "낚은 것"},
	"forest": {"name": "산나물전", "skill": "forest", "desc": "산에서 캔 것"},
	"mine": {"name": "광석상", "skill": "mine", "desc": "굴에서 캔 것"},
	"cook": {"name": "밥집", "skill": "cook", "desc": "만든 음식"},
	"beach": {"name": "갯것전", "skill": "beach", "desc": "바닷가에서 주운 것"},
	"ranch": {"name": "축산물전", "skill": "ranch", "desc": "가축이 낸 것"},
	"combat": {"name": "무기 노점", "skill": "combat", "desc": "동굴에서 얻은 것"},
}
# 재판정의 두 사람 — 읍에서 오는 순회 손글이라 NPCS 에 없다(주민도 명부도 생일도 아니다).
# npc_def 가 여기로 떨어지므로 이름·초상은 같은 길로 나온다. 스프라이트는 SOCIETY_NPC_IDS 가 싣는다
const COURT_NPCS := {
	"judge_yoon": {"name": "윤 판사", "gender": "f"},
	"prosecutor_han": {"name": "한 검사", "gender": "m"},
}
const GOV_GRANT := 2000                     # 계절 교부금(고정) — 교진 예산은 절대 마이너스가 안 된다
const GOV_LEVY_PER_RESIDENT := 30           # NPC 장부세: (주민 − 1) × 30
const GOV_OPS := {"inn": 300, "lab": 300}   # 운영비 — 부지(파출소 inn · 진료소 lab)가 서 있을 때만
# 공공사업 — 예산이 비용에 닿으면 이장이 다음 사업을 건다(착공 즉시 차감), 다음 계절 첫날 완공.
# 둘 다 눈에 보이는 결과다 — 「내가 낸 세금이 등불이 되고 길이 된다」. 순경·의사 자리는 S2b 가 뒤에 잇는다
const GOV_PROJECTS := [
	{"id": "lights", "name": "밤길 등불", "cost": 500,
		"desc": "마을 길목마다 등불을 건다. 밤이 덜 어둡다.",
		"done": "밤이 조금 덜 어둡다."},
	{"id": "paving", "name": "마을 길 포장", "cost": 5000,
		"desc": "마을 안 자갈길을 고르게 다진다. 길 위에서는 걸음이 빠르다.",
		"done": "자갈길 위에서는 걸음이 한결 가볍다."},
]

# ---- 사회: 상태 ----

# 세계 키 — 호스트 권위, build_save 한 줄로 게스트에 자동 전파된다(헌법 §9.1).
var society_v := 1        # 사회 하위 시스템의 세이브 판 — 옛 세이브엔 없어 0, 그러면 전부 기본값
var seats := {}           # {inst: {rank: [npc id / "player" / ""]}} — 「자리가 진실이다」(헌법 §0.1)
var npc_wallet := {}      # {nid: int} 소매치기가 건드린 지갑만 — 없는 사람은 wallet_of 가 계절 시드로 정한다
# 정부(S2a) — 사업비 저금통. 인건비 계정은 없다(공무원 봉급은 도 교부금, 어떤 장부에도 안 적힌다)
var gov_budget := {"kyojin": 2000}   # {region: int}
var gov_done: Array = []             # 완공한 공공사업 id
var gov_building := ""               # 착공해 다음 계절 첫날 완공되는 사업 id ("" = 없음)
var gov_tax_season := 0              # 이번 계절 플레이어가 낸 세금(장부 한 줄의 재료)
var gov_log: Array = []              # 계절 장부 [{season, grant, levy, tax, ops, project}] ≤ 8 — 서기의 「예산 장부」
var tax_seize_due := 0               # 오늘 아침 압류할 액수(society.after_new_day 가 집행하고 0 으로)
# 파출소(S2b) — NPC 사건. 헌법 §6.7: 확률이 아니라 결정적 주기, 플레이어 없이도 닫힌다
var cases: Array = []                # [{id, crime, day, suspect, victim, witness, evidence, stage, closed_by, deadline}]
var case_seq := 0
var npc_greed_adj := {}              # {nid: float} 유죄마다 −0.1 (하한 0.5)

# 런타임 — 저장하지 않는다.
var animals_now := 0                              # 가축 수 — society._process 가 0.5초마다 채운다(목장주 호칭 재료)
var _society_notes: Array = []                    # 아침 결산에 덧붙일 줄들 — society_note() 가 한 번에 비운다
var _title_mark := ""                             # 이장 기준 호칭 cls 의 기준선 — 바뀐 아침에만 한 줄(D9)
var _bold_today := {"cave": 0.0, "night": 0.0}    # 오늘 오른 대범함 — BOLD_CAP 의 하루 상한을 센다
var shop_force_p := -1.0                          # 하네스가 좌판 손님의 구매 확률을 고정한다(0 이상이면)

# me 안 목록 원소의 모양 — _apply_me 가 이 위에 같은 이름만 덮고 int 칸을 int() 로 되돌린다(D21).
# JSON 은 속까지 모든 수를 float 로 읽으므로, 원소를 만드는 쪽이 아니라 읽는 쪽이 모양을 안다.
const ME_MEMORY := {"day": 0, "kind": "pickpocket", "heat": 1, "region": "kyojin", "witnesses": [],
	"forgiven": false, "target": "", "value": 0, "reported_day": 0, "settled": "", "settled_day": 0}
const ME_RECORD := {"day": 0, "crime": "", "court": "village", "verdict": "service", "sentence": 3,
	"served": 0, "served_day": 0, "expunged": false}
const ME_WORK := {"day": 0, "kind": "work", "inst": "", "pick": 0}
const ME_JOB_HIST := {"inst": "", "rank": "", "job": "", "from": 0, "to": 0, "reason": "quit"}
const ME_LEDGER := {"day": 0, "sold": 0, "gold": 0}   # 좌판 하루 장부(S3a)


# 새 인물의 사회적 신원 — 아무것도 아닌 사람으로 시작한다(헌법 §9.2 + S1 신규 키 셋).
#
# wage_day·work_log·night_out_min 은 헌법 §9.2 에 없던 키다: 봉급날은 적립과 따로 굴러야
# 하고(D4), 「오늘/어제 근무·독서」는 날짜 스탬프 목록이 필요하며, 밤길 분은 rest_mult 의
# 재료다(D8). rep_wary_seen 은 「사람들이 눈을 피한다」 줄을 한 번만 내려고(부록 §5).
# boldness_base −1 은 「아직 안 물어봤다」 — 이장이 묻기 전엔 대범함이 전혀 움직이지 않는다.
func fresh_me() -> Dictionary:
	return {
		# 직업
		"job": "", "rank": "", "job_since_day": 0, "job_history": [],
		"perf": 0, "absent_days": 0, "service_days": 0, "books_read": 0,
		"wage_pending": 0, "wage_day": 0, "work_log": [],
		# 돈·세금 — S1 은 season_earned 둘만 굴린다
		"season_earned": 0, "season_earned_prev": 0, "tax_paid_season": -1,
		"arrears": {"amount": 0, "weeks": 0}, "tax_bills": [],
		# 평판·전과·기억
		"reputation": {"kyojin": 0, "town": 0}, "record": [], "memories": [], "rumor_day": 0,
		"rep_wary_seen": false,
		# 대범함
		"boldness_base": -1, "boldness_state": 0.0, "bold_days_up": 0, "bold_days_quiet": 0,
		# 범죄·구속
		"theft_xp": 0.0, "night_out_min": 0.0, "stolen": {}, "wanted": {}, "night_out_day": 0,
		"jail_days_left": 0, "sentence": {}, "home_region": "kyojin",
		# 순회 재판(S2c) — 걸린 기소 하나(재판일까지 자택 대기), 출소한 날(호칭 jailed 이레)
		"charged": {}, "jail_out_day": -99,
		# 순경(S2b) — 오늘 순찰의 진행과 검거 실적, 사건마다 물어본 사람
		"patrol_day": 0, "patrol_idx": 0, "arrests": 0, "case_asked": {},
		# 자치회(S3c) — 부녀회장이 오늘 찾아간 집
		"visit_day": 0,
		# 자기 상점(S3)
		"shop_own": {}, "shop_stock": {}, "shop_ledger": [],
	}


# 세이브의 me 를 fresh_me() 위에 덮는다 — 모르는 키는 버리고, 수는 fresh 의 타입으로
# 캐스팅하고(JSON 은 int 도 float 로 읽는다), 그 밖은 typeof 가 같을 때만 받는다.
# src 가 Dictionary 가 아니면("me": null 같은 손댄 세이브) 새 그릇을 돌려준다.
func _apply_me(src: Variant) -> Dictionary:
	var out := fresh_me()
	if not (src is Dictionary):
		return out
	for k in out.keys():
		if not src.has(k):
			continue
		var v: Variant = src[k]
		var base: Variant = out[k]
		if (base is int or base is float) and (v is int or v is float):
			out[k] = int(v) if base is int else float(v)
		elif typeof(v) == typeof(base):
			out[k] = v
	# 중첩 정규화 — 최상위만 int 로 되돌리면 memories[i].heat 같은 속의 수가 float 로 남아
	# 첨자·비교에서 어긋난다. 원소마다 §3.1 모양 위에 다시 얹는다.
	var rep: Variant = out.reputation
	if not (rep is Dictionary):
		rep = {}
	out.reputation = {"kyojin": int(rep.get("kyojin", 0)), "town": int(rep.get("town", 0))}
	# arrears 도 같은 이유로 — 세금(S2)이 `amount % n` 이나 첨자로 쓰는 날 float 가 걸린다
	var ar: Variant = out.arrears
	if not (ar is Dictionary):
		ar = {}
	out.arrears = {"amount": int(ar.get("amount", 0)), "weeks": int(ar.get("weeks", 0))}
	out.memories = _apply_rows(out.memories, ME_MEMORY)
	out.record = _apply_rows(out.record, ME_RECORD)
	out.work_log = _apply_rows(out.work_log, ME_WORK)
	out.job_history = _apply_rows(out.job_history, ME_JOB_HIST)
	var st := {}
	for id in out.stolen.keys():
		st[id] = int(out.stolen[id])
	out.stolen = st
	# 좌판(S3a) — 재고의 수·값, 금고, 장부 줄까지 int 로
	var stock := {}
	for id in out.shop_stock.keys():
		var row: Variant = out.shop_stock[id]
		if row is Dictionary:
			stock[id] = {"qty": int(row.get("qty", 0)), "price": int(row.get("price", 0))}
	out.shop_stock = stock
	if not out.shop_own.is_empty():
		out.shop_own = {"kind": str(out.shop_own.get("kind", "")), "since": int(out.shop_own.get("since", 0)),
			"till": int(out.shop_own.get("till", 0)), "x": int(out.shop_own.get("x", -1)),
			"y": int(out.shop_own.get("y", -1))}
	out.shop_ledger = _apply_rows(out.shop_ledger, ME_LEDGER)
	return out


# 목록 원소 정규화 — shape 의 기본값 위에 같은 이름만 덮고, int 칸은 int() 로. Dictionary 가 아닌 원소는 버린다.
func _apply_rows(rows: Array, shape: Dictionary) -> Array:
	var res: Array = []
	for r in rows:
		if not (r is Dictionary):
			continue
		var e: Dictionary = shape.duplicate(true)
		for k in shape.keys():
			if not r.has(k):
				continue
			var v: Variant = r[k]
			var base: Variant = shape[k]
			if base is int and (v is int or v is float):
				e[k] = int(v)
			elif typeof(v) == typeof(base):
				e[k] = v
		res.append(e)
	return res


# 기관의 자리 줄 — 없으면 {아래: [""], 위: [주인]} 로 시드하고, 있어도 두 랭크 키를 돌며
# 빠진 키(또는 빈 배열·배열 아님)를 같은 기본값으로 채운다. 랭크 이름을 바꾼 세이브에서
# seat_of 가 KeyError 로 매일 아침 하루 넘김을 죽이지 않게(D21).
func seat_rows(inst: String) -> Dictionary:
	var d: Dictionary = INSTITUTIONS.get(inst, {})
	var ranks: Array = d.get("ranks", [])
	if ranks.size() < 2:
		return {}
	var rows: Variant = seats.get(inst)
	if not (rows is Dictionary):
		rows = {}
		seats[inst] = rows
	# 마지막 랭크가 주인(고정), 그 아래는 전부 공석으로 시드한다 — 면사무소(S2)처럼
	# 아래 자리가 둘인 기관도 같은 규칙이다
	for i in ranks.size():
		var r := str(ranks[i])
		var cur: Variant = rows.get(r)
		if not (cur is Array) or cur.is_empty():
			rows[r] = [str(d.get("head", ""))] if i == ranks.size() - 1 else [""]
	# 랭크 밖의 키나 Array 아닌 값은 버린다 — society_new_day ② 의 `"player" in rows[r]` 와
	# seat_clear_player 가 손댄 세이브의 수 하나에 걸려 매일 아침 ③~⑫ 를 통째로 건너뛰지 않게.
	# 정상 경로는 두 랭크 키 아래 Array 만 쓰므로 여기서 지워지는 건 남이 손댄 것뿐이다
	for k in rows.keys():
		if not (str(k) in ranks) or not (rows[k] is Array):
			rows.erase(k)
	return rows


# 그 자리의 첫 칸에 앉은 사람 — npc id / "player" / ""(공석)
func seat_of(inst: String, rank: String) -> String:
	var rows := seat_rows(inst)
	var arr: Array = rows.get(rank, [""])
	return str(arr[0]) if not arr.is_empty() else ""


# 플레이어가 앉은 자리를 전부 비운다 — 사직·해고가 같은 줄을 쓴다.
func seat_clear_player() -> void:
	for inst in INSTITUTIONS:
		var rows := seat_rows(inst)
		for r in rows:
			if not (rows[r] is Array):
				continue
			var arr: Array = rows[r]
			for i in arr.size():
				if str(arr[i]) == "player":
					arr[i] = ""


# NPC 지갑 — 소매치기가 건드리기 전엔 계절마다 정해지는 시드값(20~120). 저장된 값은 int 로 읽는다.
func wallet_of(nid: String) -> int:
	if npc_wallet.has(nid):
		return int(npc_wallet[nid])
	return 20 + posmod(hash(nid + "|" + str(season())), 101)


# ---- 사회: 순수 함수 ----
#
# 새 코드는 아래 넷으로만 NPC 표·호감도에 닿는다 — NPCS[ / NPC_KIND[ / affinity[ 직접 접근이
# 120곳이라 표를 가르는 날 고칠 곳을 더 늘리지 않으려고.

func npc_def(id: String) -> Dictionary:
	if NPCS.has(id):
		return NPCS[id]
	return COURT_NPCS.get(id, {})   # 순회 판사·검사 — 주민이 아니라 NPCS 밖에 산다(S2c)


func npc_kind(id: String) -> String:
	return str(NPC_KIND.get(id, "core"))


func aff(id: String) -> int:
	return int(affinity.get(id, 0))


# 호감도 쓰기는 전부 여기로 — 모르는 id 는 조용히 지나가고 0..100 을 넘지 않는다.
# 교진 평판 — 모든 오르내림은 이 한 줄을 지난다(society.gd 의 _rep_add 도 여기로 온다)
func rep_add(d: int) -> void:
	var rep: Variant = me.get("reputation", {})
	if not (rep is Dictionary):
		rep = {"kyojin": 0, "town": 0}
	rep["kyojin"] = int(rep.get("kyojin", 0)) + d
	me["reputation"] = rep


func aff_add(id: String, d: int) -> void:
	if not affinity.has(id):
		return
	affinity[id] = clampi(aff(id) + d, 0, 100)


# 「총각/처자」 — 성별은 플레이어 gender 로만 가른다.
func honor() -> String:
	return "처자" if gender == "f" else "총각"


# 자유직 통계값 — "animals" 는 런타임 가축 수, 사전(도감)이면 값의 합, 수면 그 값.
func free_stat_value(stat: String) -> int:
	if stat == "animals":
		return animals_now
	var v: Variant = get(stat)
	if v is Dictionary:
		var total := 0
		for k in v.keys():
			total += int(v[k])
		return total
	if v is int or v is float:
		return int(v)
	return 0


# 문턱을 넘은 자유직 중 value/need 비율이 가장 큰 것 — 없으면 ""(D16).
func free_title_of() -> String:
	var best := ""
	var best_ratio := 0.0
	for id in FREE_TITLES:
		var need := int(FREE_TITLES[id].need)
		if need <= 0:
			continue
		var value := free_stat_value(str(FREE_TITLES[id].stat))
		if value < need:
			continue
		var ratio := float(value) / float(need)
		if ratio > best_ratio:
			best_ratio = ratio
			best = id
	return best


func job_inst() -> String:
	return str(JOBS.get(str(me.get("job", "")), {}).get("inst", ""))


func job_days() -> int:
	return day - int(me.get("job_since_day", 0))


func worked_on(d: int) -> bool:
	return _logged_on(d, "work")


func read_on(d: int) -> bool:
	return _logged_on(d, "read")


func _logged_on(d: int, kind: String) -> bool:
	for w in me.get("work_log", []):
		if w is Dictionary and int(w.get("day", 0)) == d and str(w.get("kind", "")) == kind:
			return true
	return false


# 「사흘째」「이레치」 — 열흘까지는 우리말, 그 위는 「n일」
func days_kor(n: int) -> String:
	if n >= 1 and n <= KOR_DAYS.size():
		return KOR_DAYS[n - 1]
	return "%d일" % n


# 기억이 아직 살아 있나 — 용서받지 않았고, heat 별 날수(28/56/84)를 안 넘겼다.
func mem_alive(mem: Dictionary) -> bool:
	if bool(mem.get("forgiven", false)):
		return false
	var heat := mini(int(mem.get("heat", 1)), 3)
	return day - int(mem.get("day", 0)) <= int(SEEN_DAYS[maxi(heat, 1) - 1])


# 호칭 체인(헌법 §4.2) — 위에서 첫 참. {cls, text, wary} 를 돌려준다.
# me 는 전부 .get 으로 읽는다 — S0 그릇·하네스가 심은 임의 값에서도 오류 없이 stranger 로 떨어지게.
func player_title(nid: String) -> Dictionary:
	var rep: Variant = me.get("reputation", {})
	var wary: bool = rep is Dictionary and int(rep.get("kyojin", 0)) < -20
	var cls := ""
	var text := ""
	var job := str(me.get("job", ""))
	var a := aff(nid)
	# 1 살인자 — 말소되지 않은 murder 기록
	for rec in me.get("record", []):
		if rec is Dictionary and str(rec.get("crime", "")) == "murder" and not bool(rec.get("expunged", false)):
			cls = "murderer"
			text = "살인자"
			break
	# 2 본 사람 / 3 들은 사람 — 살아 있는 기억만. 들은 것은 heat 2 이상이 하루 지난 뒤
	if cls == "":
		var heard := false
		for mem in me.get("memories", []):
			if not (mem is Dictionary) or not mem_alive(mem):
				continue
			var wit: Variant = mem.get("witnesses", [])
			if wit is Array and nid in wit:
				cls = "seen"
				text = "그 사람"
				break
			if int(mem.get("heat", 1)) >= 2 and int(mem.get("day", 0)) < day:
				heard = true
		if cls == "" and heard:
			cls = "heard"
			text = "소문의 그 사람"
	# 4 그 일 있던 사람 — 구속 중이거나 출소 이레 안
	if cls == "" and (int(me.get("jail_days_left", 0)) > 0 or day - int(me.get("jail_out_day", -99)) <= 7):
		cls = "jailed"
		text = "그 일 있던 사람"
	# 5 직함 — 근속이 known_at(14일)을 넘어야 직함으로 불린다(D5). 호감 70이면 「우리 점원」
	if cls == "" and job != "" and JOBS.has(job) and job_days() >= int(JOBS[job].get("known_at", 14)):
		var calls: Dictionary = JOBS[job].get("calls", {})
		cls = "office"
		text = str(calls.get("master", "") if a >= 70 else calls.get("known", "")).format({"ho": honor()})
	# 6 전직 — 그만둔 지 이레 안이거나, 호감 70인 사람은 계속 「전 …」
	if cls == "":
		var hist: Array = me.get("job_history", [])
		if not hist.is_empty() and hist[-1] is Dictionary:
			var last: Dictionary = hist[-1]
			if day - int(last.get("to", 0)) <= 7 or a >= 70:
				cls = "ex"
				text = "전 " + str(JOBS.get(str(last.get("job", "")), {}).get("name", "일꾼"))
	# 7·8 자유직 — 실적 문턱을 넘으면 불린다. 호감 70이면 「우리 마을 …」. 표가 진실(부록 §1)
	if cls == "":
		var ft := free_title_of()
		if ft != "":
			var f: Dictionary = FREE_TITLES[ft]
			if a >= 70:
				cls = "free_master"
				text = str(f.master)
			else:
				cls = "free_known"
				text = str(f.known_f if gender == "f" else f.known_m)
	# 9 이름 — 호감 30
	if cls == "" and a >= 30:
		cls = "name"
		text = player_name if player_name != "" else "친구"
	# 10 낯선 사람 — 직업이 있으면 수습 호칭(「만수네 새 사람」, D5), 없으면 날수로
	if cls == "":
		cls = "stranger"
		if JOBS.has(job):
			text = str(JOBS[job].get("calls", {}).get("stranger", "")).format({"ho": honor()})
		else:
			text = "새로 온 사람" if day < 28 else "젊은이"
	return {"cls": cls, "text": text, "wary": wary}


# 하루 첫 대화의 첫마디 — 호칭이 NPC 의 입으로 나오는 자리(헌법 §0.4).
# 풀 고르기는 부록 §2 순서: wary(줄 자체) > bold_high > 주인의 boss_calls > NPC_CALLS > 공용.
# 하루 안에서 결정적이다 — 같은 날 같은 cls·같은 nid 면 같은 줄(하네스 TITLE_OK 가 이 성질에 기댄다).
func call_opener(nid: String) -> String:
	var t := player_title(nid)
	var cls := str(t.cls)
	var job := str(me.get("job", ""))
	var pool: Array = []
	if bool(t.wary):
		pool = CALL_FALLBACK.wary
	elif boldness() >= 75 and not (cls in ["murderer", "seen", "heard"]):
		pool = CALL_FALLBACK.bold_high
	elif cls in ["office", "stranger"] and job != "" and JOBS.has(job) and nid == str(JOBS[job].get("boss", "")):
		var bc: Dictionary = JOBS[job].get("boss_calls", {})
		var key := "master" if aff(nid) >= 70 else ("known" if cls == "office" else "stranger")
		pool = bc.get(key, [])
	elif (NPC_CALLS.get(nid, {}) as Dictionary).has(cls):
		pool = NPC_CALLS[nid][cls]
	elif cls == "stranger":
		if job != "":
			pool = CALL_FALLBACK.stranger_job
		else:
			pool = CALL_FALLBACK.stranger_new if day < 28 else CALL_FALLBACK.stranger_old
	else:
		pool = CALL_FALLBACK.get(cls, [])
	if pool.is_empty():
		pool = CALL_FALLBACK.stranger_old
	var line := str(pool[posmod(day * 31 + nid.hash(), pool.size())])
	return line.format({"title": t.text, "name": player_name if player_name != "" else "친구", "ho": honor()})


# 판정값 — 성격(base) 위에 그날의 흔들림(state). base −1(아직 안 물어봄)은 0 으로 센다.
func boldness() -> int:
	return maxi(int(me.get("boldness_base", -1)), 0) + int(me.get("boldness_state", 0.0))


# 마음 카드의 단계 이름 — 숫자는 보여 주지 않는다(헌법 §5.1). base −1 이면 "".
func bold_stage() -> String:
	if int(me.get("boldness_base", -1)) < 0:
		return ""
	var b := boldness()
	var stage := ""
	for st in BOLD_STAGES:
		if b >= int(st[0]):
			stage = str(st[1])
	return stage


# 대범함 흔들림 — base 가 −1 인 동안은 아무것도 안 한다(이장이 묻기 전엔 성격이 없다).
# cap_key("cave"/"night")가 있으면 오늘 오른 몫이 BOLD_CAP 을 넘지 않게 자른다.
func bold_add(delta: float, cap_key := "") -> void:
	if int(me.get("boldness_base", -1)) < 0:
		return
	if cap_key != "":
		delta = minf(delta, float(BOLD_CAP.get(cap_key, 0.0)) - float(_bold_today.get(cap_key, 0.0)))
		if delta <= 0.0:
			return
		_bold_today[cap_key] = float(_bold_today.get(cap_key, 0.0)) + delta
	me.boldness_state = clampf(float(me.get("boldness_state", 0.0)) + delta, -20.0, 40.0)


# 손버릇 레벨 — SKILL_IDS 에 넣지 않고 곡선(skill_xp_needed)만 빌린다: 205 → Lv2.
func theft_lv() -> int:
	var xp := float(me.get("theft_xp", 0.0))
	var lv := 1
	while lv < 10 and xp >= skill_xp_needed(lv):
		xp -= skill_xp_needed(lv)
		lv += 1
	return lv


# 도둑질 성공률 — 손버릇 Lv 마다 +4%, 밤 ×1.3, 목격자 한 명마다 ×0.85. 2%~60%.
func theft_p(base: float, night: bool, witnesses: int) -> float:
	var p := base * (1.0 + 0.04 * (theft_lv() - 1)) * (1.3 if night else 1.0) * pow(0.85, witnesses)
	return clampf(p, 0.02, 0.60)


# 밤 사람 — 저녁에도 22시까지는 밖에 남는다(npc.gd 의 귀가 조건이 이걸 뺀다).
func night_owl(id: String) -> bool:
	return NIGHT_OWLS.has(id) and minutes < float(NIGHT_OWLS[id])


# 신고된 기억이 아직 회의를 거치지 않았나 — 신고 다음날부터 이장이 찾아온다.
func council_pending() -> bool:
	for mem in me.get("memories", []):
		if not (mem is Dictionary):
			continue
		var rd := int(mem.get("reported_day", 0))
		if rd > 0 and rd < day and str(mem.get("settled", "")) == "":
			return true
	return false


# 아직 채우지 못한 봉사 판결 — 없으면 {}
func service_pending() -> Dictionary:
	for rec in me.get("record", []):
		if rec is Dictionary and int(rec.get("served", 0)) < int(rec.get("sentence", 0)):
			return rec
	return {}


# 사회가 NPC 에게 주는 자리 — npcs.gd 의 사회 분기가 부른다. 축제 > 사회(plan §7)는 여기
# 시간 조건으로 지킨다: 회의는 축제 없는 날 09~17시만, 밤 사람은 저녁 뒤만(축제는 18시 종료).
# ---- 세금·예산 (S2a) ----

# 정부가 있는가 — 면사무소 창구(회관, story9 done)가 열린 뒤부터. 그 전엔 세금도 예산도 없다
func tax_open() -> bool:
	return story9_phase == "done"


# 절대 계절 번호(0부터) — 고지서·납부 기록이 「어느 계절 것」인지 셀 때
func season_no(d := day) -> int:
	return (d - 1) / DAYS_PER_SEASON


# 아직 안 낸 고지서들 — 오래된 것이 앞
func unpaid_bills() -> Array:
	var out: Array = []
	for b in me.get("tax_bills", []):
		if b is Dictionary and int(b.get("paid", 0)) < int(b.get("total", 0)):
			out.append(b)
	return out


# 고지서 하나의 체납 주 — 납부 기한 다음날부터 이레마다 한 주. 기한 안이면 0
func bill_weeks(b: Dictionary) -> int:
	var over: int = day - int(b.get("due_day", 0))
	return 0 if over <= 0 else (over - 1) / 7 + 1


# 고지서 하나를 오늘 내면 얼마인가 — 원금 + 주당 5% 단리, 상한 50%
func bill_due(b: Dictionary) -> int:
	var total := int(b.get("total", 0))
	var extra := minf(ARREARS_RATE * float(bill_weeks(b)), ARREARS_CAP)
	return total + int(float(total) * extra)


# 밀린 세금 전부 — 오늘 창구에서 낼 액수
func tax_due_total() -> int:
	var n := 0
	for b in unpaid_bills():
		n += bill_due(b)
	return n


# 기한이 지난 고지서만 — 압류는 「밀린」 것만 걷는다(그날 아침 막 나온 고지서는 아직 밀린 게 아니다)
func overdue_bills() -> Array:
	var out: Array = []
	for b in unpaid_bills():
		if bill_weeks(b) >= 1:
			out.append(b)
	return out


# 가장 오래 밀린 주 수 — 독촉·이장·봉급 정지·압류의 사다리는 이 수를 본다
func arrears_weeks() -> int:
	var w := 0
	for b in unpaid_bills():
		w = maxi(w, bill_weeks(b))
	return w


# 체납으로 봉급이 멈췄나(여섯 주째, 자리는 남는다)
func wage_frozen() -> bool:
	return arrears_weeks() >= ARREARS_FREEZE_WEEK


# 이장이 세금 얘기로 먼저 말을 거는가(네 주째)
func tax_dun_active() -> bool:
	return arrears_weeks() >= ARREARS_CHIEF_WEEK


# 계절 첫날 고지서 — 소득세(지난 계절 수입 2,000 초과분 10%) + 재산세(집 단계 100 · 가축 20).
# 0원이어도 편지는 온다(「이번 계절 세금은 없다」) — 정부가 있다는 것을 계절마다 한 번 느낀다
func issue_tax_bill() -> Dictionary:
	var earned := int(me.get("season_earned_prev", 0))
	var income := int(float(earned) * TAX_INCOME_RATE) if earned > TAX_FREE_INCOME else 0
	var property := house_lv * TAX_PROPERTY_HOUSE + animals_now * TAX_PROPERTY_ANIMAL
	# 매출세(S3a) — 좌판 28일 매출의 5%. 좌판이 없으면 0
	var sales_sum := shop_ledger_sum(SHOP_LEDGER_DAYS)
	var sales := int(float(sales_sum) * SALES_TAX_RATE)
	var total := income + property + sales
	var b := {"season": season_no(), "day": day, "income": income, "property": property,
		"sales": sales, "total": total, "paid": 0, "due_day": day + TAX_DUE_DAYS - 1}
	var bills: Array = me.get("tax_bills", [])
	bills.append(b)
	while bills.size() > TAX_BILLS_MAX:
		bills.pop_front()
	me["tax_bills"] = bills
	var body := "『%s %d년 %s 납세 고지서』\n\n" % [village_name if village_name != "" else "교진",
		(day - 1) / (DAYS_PER_SEASON * 4) + 1, season_name()]
	if total <= 0:
		body += "지난 계절 수입 %dG — 면세 기준(%dG) 아래라\n이번 계절 세금은 없습니다.\n\n— 교진 면사무소" \
			% [earned, TAX_FREE_INCOME]
	else:
		body += "소득세 %dG (지난 계절 수입 %dG)\n재산세 %dG (집 %d단계 · 가축 %d마리)\n" \
			% [income, earned, property, house_lv, animals_now]
		if sales > 0:
			body += "매출세 %dG (좌판 28일 매출 %dG)\n" % [sales, sales_sum]
		body += "합계 %dG\n\n" % total
		body += "납부 기한: 이 계절 %d일까지, 면사무소 창구.\n기한을 넘기면 주마다 5%%가 붙습니다.\n\n— 교진 면사무소" \
			% TAX_DUE_DAYS
	mail_store("납세 고지서", body)
	return b


# 창구에서 낸다 — 밀린 것 전부, 가산 포함. 돌아오는 값은 낸 액수(0 이면 낼 것이 없다)
func pay_tax() -> int:
	var due := tax_due_total()
	if due <= 0 or money < due:
		return 0
	money -= due
	today_spent += due
	for b in unpaid_bills():
		b["paid"] = int(b.get("total", 0))
	me["tax_paid_season"] = season_no()
	me["arrears"] = {"amount": 0, "weeks": 0}
	gov_budget["kyojin"] = int(gov_budget.get("kyojin", 0)) + due
	gov_tax_season += due
	items["tax_receipt"] = int(items.get("tax_receipt", 0)) + 1
	aff_add("chief", 2)
	rep_add(2)
	return due


# 체납 사다리 — 매일 아침. 문턱을 「넘는 순간」에만 한 번씩 일어난다(me.arrears.weeks 가 지난 값)
func _tax_step_daily() -> void:
	var bills := unpaid_bills()
	var ar: Dictionary = me.get("arrears", {"amount": 0, "weeks": 0})
	if bills.is_empty():
		me["arrears"] = {"amount": 0, "weeks": 0}
		return
	var was := int(ar.get("weeks", 0))
	var now_w := arrears_weeks()
	me["arrears"] = {"amount": tax_due_total(), "weeks": now_w}
	if now_w == was:
		return
	if was < ARREARS_DUN_WEEK and now_w >= ARREARS_DUN_WEEK:
		mail_store("독촉장", "『독촉장』\n\n밀린 세금이 %dG 입니다.\n주마다 5%%가 더 붙습니다. 면사무소로 오십시오.\n\n— 교진 면사무소"
			% tax_due_total())
		_note(str(SOCIETY_NOTES.tax_dun))
	if was < ARREARS_CHIEF_WEEK and now_w >= ARREARS_CHIEF_WEEK:
		rep_add(-5)
		_note(str(SOCIETY_NOTES.tax_chief))
	if was < ARREARS_FREEZE_WEEK and now_w >= ARREARS_FREEZE_WEEK and str(me.get("job", "")) != "":
		_note(str(SOCIETY_NOTES.tax_freeze))
	if was < ARREARS_SEIZE_WEEK and now_w >= ARREARS_SEIZE_WEEK:
		# 압류 — 유일한 자동 차감. 무엇을 가져갈지는 세계(가축)를 만질 수 있는 society 가
		# 같은 아침에 집행한다(after_new_day). 여기서는 액수만 적어 둔다 — 기한 지난 것만
		var due := 0
		for b in overdue_bills():
			due += bill_due(b)
		tax_seize_due = due


# 압류 집행의 마무리 — society.after_new_day 가 창고·가축·소지금에서 걷은 뒤 부른다.
# 밀린 고지서는 전부 낸 것으로 치고(강제로), 평판이 크게 깎인다
func tax_seized(taken: String) -> void:
	for b in overdue_bills():
		b["paid"] = int(b.get("total", 0))
	me["arrears"] = {"amount": tax_due_total(), "weeks": arrears_weeks()}
	tax_seize_due = 0
	rep_add(-15)
	_note(str(SOCIETY_NOTES.tax_seized) % taken)


# 회관 창고에서 값어치만큼 걷는다 — 돌아오는 값은 [걷은 값어치, "이름 x개 · …"]
func seize_from_store(due: int) -> Array:
	var got := 0
	var parts: Array = []
	for iid in hall_stock.keys():
		if got >= due:
			break
		var n := int(hall_stock[iid])
		var v := maxi(1, item_value(str(iid)))
		var take := mini(n, int(ceil(float(due - got) / float(v))))
		if take <= 0:
			continue
		hall_stock[iid] = n - take
		if int(hall_stock[iid]) <= 0:
			hall_stock.erase(iid)
		got += take * v
		parts.append("%s %d개" % [str(ITEMS.get(iid, {}).get("name", iid)), take])
	return [got, " · ".join(PackedStringArray(parts))]


# 다음에 걸 공공사업 — 완공·착공한 것 다음 순서. 없으면 {}
func gov_next_project() -> Dictionary:
	for p in GOV_PROJECTS:
		var pid := str(p.id)
		if pid in gov_done or pid == gov_building:
			continue
		return p
	return {}


func gov_project(pid: String) -> Dictionary:
	for p in GOV_PROJECTS:
		if str(p.id) == pid:
			return p
	return {}


# 운영비 — 서 있는 건물만 낸다(S2a 에는 아직 없다)
func gov_ops_cost() -> int:
	var n := 0
	for b in GOV_OPS:
		if village_built.has(b):
			n += int(GOV_OPS[b])
	return n


# 계절 첫날의 예산 — 교부금 + 장부세 − 운영비, 그 뒤 공사 완공·착공.
# 이장이 건다: 예산이 비용에 닿으면 다음 사업을 그 자리에서 착공(차감), 다음 계절 첫날 완공
func gov_season() -> void:
	var grant := GOV_GRANT
	var levy := maxi(0, residents_now - 1) * GOV_LEVY_PER_RESIDENT
	var ops := gov_ops_cost()
	gov_budget["kyojin"] = int(gov_budget.get("kyojin", 0)) + grant + levy - ops
	var row := {"season": season_no(), "grant": grant, "levy": levy, "tax": gov_tax_season,
		"ops": ops, "project": ""}
	gov_tax_season = 0
	if gov_building != "":
		var done := gov_project(gov_building)
		gov_done.append(gov_building)
		gov_building = ""
		_note(str(SOCIETY_NOTES.gov_done) % [str(done.get("name", "")), str(done.get("done", ""))])
	var nxt := gov_next_project()
	if not nxt.is_empty() and int(gov_budget.get("kyojin", 0)) >= int(nxt.cost):
		gov_budget["kyojin"] = int(gov_budget.get("kyojin", 0)) - int(nxt.cost)
		gov_building = str(nxt.id)
		row["project"] = gov_building
		_note(str(SOCIETY_NOTES.gov_start) % str(nxt.name))
	gov_log.append(row)
	while gov_log.size() > 8:
		gov_log.pop_front()


# 공공사업의 효과 — 길 포장이 되면 자갈길 위에서 걸음이 빠르다(player.gd 가 읽는다)
func path_speed_mult() -> float:
	return 1.2 if "paving" in gov_done else 1.0


# 밤의 가장 어두운 색 — 등불이 걸리면 조금 덜 어둡다(day_cycle._update_night 가 읽는다)
func night_dark_color() -> Color:
	return Color(0.24, 0.23, 0.35) if "lights" in gov_done else Color(0.16, 0.15, 0.26)


# ---- 파출소·사건 (S2b) ----

# 파출소가 서고 박 순경이 부임했나 — 그때부터 사건이 생기고, 닫히고, 나를 쫓는다
func police_open() -> bool:
	return village_built.has("inn") and npc_greeted.has("officer_park")


# 정착민의 탐욕 — NPCS.greed(없으면 1.0)에서 유죄마다 −0.1(하한 0.5)
func npc_greed(nid: String) -> float:
	return maxf(0.5, float(npc_def(nid).get("greed", 1.0)) + float(npc_greed_adj.get(nid, 0.0)))


func wanted_active() -> bool:
	var w: Variant = me.get("wanted", {})
	return w is Dictionary and not w.is_empty()


func open_cases() -> Array:
	var out: Array = []
	for c in cases:
		if c is Dictionary and str(c.get("stage", "")) == "open":
			out.append(c)
	return out


func case_by_id(cid: int) -> Dictionary:
	for c in cases:
		if c is Dictionary and int(c.get("id", -1)) == cid:
			return c
	return {}


# 결정적 굴림 — 날짜·번호로 정해지는 0..1 (플레이어 없이도, 다시 불러와도 같은 결과)
func _case_roll(cid: int, salt: int) -> float:
	return float(posmod(hash("%d|%d|%d" % [day, cid, salt]), 1000)) / 1000.0


# NPC 범죄 — 이레마다 한 건, 후보가 있을 때만(헌법 §6.7: 평화로운 마을은 결과다).
# 범인: 정착민 중 greed ≥ 1.2 · 호감도 < 40 · 열린 사건의 용의자가 아닌 사람.
# 피해자: 마을에 자리 잡은 다른 사람. 목격자: 또 다른 사람(순경의 두 번째 흔적)
func _npc_crime_tick() -> void:
	if not police_open() or day % NPC_CRIME_PERIOD != 0 or open_cases().size() >= 3:
		return
	var suspects: Array = []
	for nid in settlers:
		var sid := str(nid)
		if npc_greed(sid) < 1.2 or aff(sid) >= 40 or not npc_greeted.has(sid):
			continue
		var busy := false
		for c in open_cases():
			if str(c.get("suspect", "")) == sid:
				busy = true
		if not busy:
			suspects.append(sid)
	if suspects.is_empty():
		return
	var pool: Array = []
	for nid in npc_greeted:
		var vid := str(nid)
		if vid != "officer_park" and vid not in suspects and NPCS.has(vid):
			pool.append(vid)
	if pool.size() < 2:
		return
	var suspect := str(suspects[posmod(day / NPC_CRIME_PERIOD, suspects.size())])
	var victim := str(pool[posmod(day * 7 + case_seq, pool.size())])
	var witness := str(pool[posmod(day * 13 + case_seq + 1, pool.size())])
	if witness == victim:
		witness = str(pool[posmod(day * 13 + case_seq + 2, pool.size())])
	case_seq += 1
	cases.append({"id": case_seq, "crime": "burglary", "day": day, "suspect": suspect,
		"victim": victim, "witness": witness, "evidence": 0, "stage": "open",
		"closed_by": "", "deadline": day + CASE_TTL})
	while cases.size() > CASE_MAX:
		cases.pop_front()
	_note(str(SOCIETY_NOTES.crime_night) % str(npc_def(victim).get("name", victim)))


# 열린 사건이 저절로 닫히는 길 — 신고 사흘 뒤부터 사흘마다 순경이 굴리고, 시효에 닫힌다
func _case_close_tick() -> void:
	for c in open_cases():
		var cid := int(c.get("id", 0))
		var age: int = day - int(c.get("day", 0))
		var victim := str(npc_def(str(c.get("victim", ""))).get("name", ""))
		if day >= int(c.get("deadline", 0)):
			c["stage"] = "closed"
			c["closed_by"] = "expired"
			_note(str(SOCIETY_NOTES.case_expired) % victim)
			continue
		if age >= NPC_CATCH_DAYS and age % NPC_CATCH_DAYS == 0 and police_open():
			if _case_roll(cid, age) < NPC_CATCH_P:
				_case_convict(c, "officer")


# 유죄 — 사건을 닫고, 범인의 탐욕이 조금 줄고, 벌금이 예산으로 간다
func _case_convict(c: Dictionary, by: String) -> void:
	var sid := str(c.get("suspect", ""))
	c["stage"] = "closed"
	c["closed_by"] = by
	npc_greed_adj[sid] = float(npc_greed_adj.get(sid, 0.0)) - 0.1
	var w := wallet_of(sid)
	var fine: int = mini(w, NPC_FINE)
	npc_wallet[sid] = w - fine
	gov_budget["kyojin"] = int(gov_budget.get("kyojin", 0)) + fine
	var sname := str(npc_def(sid).get("name", sid))
	var vname := str(npc_def(str(c.get("victim", ""))).get("name", ""))
	_note(str(SOCIETY_NOTES.case_mine if by == "player" else SOCIETY_NOTES.case_caught) % [sname, vname])


# ---- 순회 재판 (S2c) ----

# 오늘이 재판일인가 — 정부(창구)와 파출소가 있어야 판사가 온다
func is_court_day(d := day) -> bool:
	return tax_open() and police_open() and ((d - 1) % DAYS_PER_SEASON + 1) in COURT_DAYS


# d 다음 첫 재판일(d 자신은 빼고) — 오늘 기소되면 next_court_day(day − 1) 이 오늘일 수 있다
func next_court_day(d: int) -> int:
	var x := d + 1
	while not (((x - 1) % DAYS_PER_SEASON + 1) in COURT_DAYS):
		x += 1
	return x


# 「이 계절 21일」 「다음 계절 7일」 — 결산 한 줄에 쓰는 날짜
func court_day_label(d: int) -> String:
	var when := "이 계절" if season_no(d) == season_no() else "다음 계절"
	return "%s %d일" % [when, (d - 1) % DAYS_PER_SEASON + 1]


func charged_active() -> bool:
	var c: Variant = me.get("charged", {})
	return c is Dictionary and not c.is_empty()


# 말소되지 않은 법원 전과 — 마을 회의의 봉사(court village)는 전과가 아니다
func record_unexpunged() -> bool:
	for rec in me.get("record", []):
		if rec is Dictionary and not bool(rec.get("expunged", false)) \
				and str(rec.get("court", "")) != "village":
			return true
	return false


# 전과 말소를 청구할 수 있나 — "" 면 된다, 아니면 창구가 말할 이유
func can_expunge() -> String:
	if not record_unexpunged():
		return "말소할 전과가 없다."
	if charged_active() or int(me.get("jail_days_left", 0)) > 0:
		return "재판이 걸려 있는 동안은 안 되네."
	var last := 0
	for rec in me.get("record", []):
		if not (rec is Dictionary) or bool(rec.get("expunged", false)) or str(rec.get("court", "")) == "village":
			continue
		if int(rec.get("served", 0)) < int(rec.get("sentence", 0)):
			return "형을 다 채운 뒤에 오게."
		last = maxi(last, maxi(int(rec.get("day", 0)), int(rec.get("served_day", 0))))
	if day - last < EXPUNGE_DAYS:
		return "형이 끝나고 %d일은 조용히 지내야 하네. %d일 남았네." % [EXPUNGE_DAYS, EXPUNGE_DAYS - (day - last)]
	return ""


# 법원 전과를 전부 말소한다 — 돌려주는 값은 지운 수. 기록은 남되 임용 심사가 0 으로 센다
func expunge_records() -> int:
	var n := 0
	for rec in me.get("record", []):
		if rec is Dictionary and not bool(rec.get("expunged", false)) and str(rec.get("court", "")) != "village":
			rec["expunged"] = true
			n += 1
	return n


# 구류가 시작되는 순간의 장부 — 남은 날수를 적고, 안 낸 고지서 기한을 그만큼 미룬다(복역 중
# 체납 정지). 하루를 실제로 넘기는 일은 society.serve_jail 이 한다(세계를 든 쪽)
func jail_begin(days: int) -> void:
	me["jail_days_left"] = days
	for b in unpaid_bills():
		b["due_day"] = int(b.get("due_day", 0)) + days


# 재판일에 판사가 읽는 NPC 사건 — 지난 두 주 안에 순경(또는 순경인 나)이 닫은 것
func court_docket() -> Array:
	var out: Array = []
	for c in cases:
		if c is Dictionary and str(c.get("stage", "")) == "closed" \
				and str(c.get("closed_by", "")) in ["officer", "player"] and day - int(c.get("day", 0)) <= 14:
			out.append(c)
	return out


# 아침의 재판 자리(society_new_day 가 부른다) — ① 구류 하루 ② 어제 신고된 heat 2 는 기소
# ③ 재판일 알림·거른 재판 가중 ④ 기소가 없는 재판일엔 방청 안내
func _court_tick() -> void:
	if int(me.get("jail_days_left", 0)) > 0:
		me.jail_days_left = int(me.jail_days_left) - 1
		if int(me.jail_days_left) == 0:
			me.jail_out_day = day
			_note(str(SOCIETY_NOTES.jail_out))
	if not police_open():
		return
	if not charged_active():
		for mem in me.memories:
			if int(mem.get("heat", 1)) < 2 or str(mem.get("settled", "")) != "":
				continue
			var rd := int(mem.get("reported_day", 0))
			if rd <= 0 or rd >= day:
				continue
			mem["settled"] = "charged"
			mem["settled_day"] = day
			var wit: Array = mem.get("witnesses", [])
			var target := str(mem.get("target", ""))
			var others := wit.size() - (1 if target in wit else 0)
			var cd := next_court_day(day - 1)
			me.charged = {"day": int(mem.get("day", 0)), "kind": str(mem.get("kind", "")), "target": target,
				"value": int(mem.get("value", 0)), "others": others, "seen": wit.size(), "heat": int(mem.get("heat", 2)),
				"court_day": cd, "skips": 0, "since": day}
			_note(str(SOCIETY_NOTES.charged) % [str(npc_def(target).get("name", target)), court_day_label(cd)])
			break
	if charged_active():
		var ch: Dictionary = me.charged
		var cd := int(ch.get("court_day", 0))
		if day == cd and int(ch.get("since", 0)) != day:
			_note(str(SOCIETY_NOTES.court_today))
		elif day > cd:
			ch.skips = int(ch.get("skips", 0)) + 1
			ch.court_day = next_court_day(day - 1)
			_note(str(SOCIETY_NOTES.court_skipped))
	elif is_court_day() and not court_docket().is_empty():
		_note(str(SOCIETY_NOTES.court_visit))


# ---- 자기 상점 (S3a) ----

func shop_open() -> bool:
	var so: Variant = me.get("shop_own", {})
	return so is Dictionary and not so.is_empty()


# 물건이 어느 좌판 종류의 것인가 — 맞지 않는 좌판에서는 반만 팔린다(농산물전의 생선)
func goods_kind(id: String) -> String:
	if CROPS.has(id):
		return "farm"
	if id.begins_with("fish_"):
		return "fish"
	if id.begins_with("dish_") or id == "flour":
		return "cook"
	if id in ["forage_berry", "forage_herb", "forage_dandelion", "weed", "herb_leaf"]:
		return "forest"
	if id in ["forage_shell", "forage_coral", "forage_glass", "forage_relic", "bait"]:
		return "beach"
	if id in ["ore", "gem", "star_shard", "crystal", "star_ore"]:
		return "mine"
	if id in ["egg", "milk", "golden_egg"]:
		return "ranch"
	if id in ["slime", "bat", "ghost", "treant", "arrow", "ghost_essence"]:
		return "combat"
	return ""


func goods_name(id: String) -> String:
	if CROPS.has(id):
		return str(CROPS[id].name)
	return str(ITEMS.get(id, {}).get("name", id))


# 허가를 받을 수 있나 — "" 면 된다. 종류별 숙련은 open_shop_permit 이 따로 잰다
func shop_permit_why() -> String:
	if not tax_open():
		return "면사무소가 열려야 하네."
	if shop_open():
		return "좌판은 하나뿐일세."
	if str(me.get("job", "")) != "":
		return "일자리가 있는 사람은 안 되네. 하나만 하게."
	if int(me.get("reputation", {}).get("kyojin", 0)) < 0:
		return "마을에 자네 얘기가 좋지 않네. 그 전엔 허가 못 하네."
	if money < SHOP_PERMIT_COST:
		return "인지세 %dG 이 있어야 하네." % SHOP_PERMIT_COST
	return ""


func shop_ledger_sum(days: int) -> int:
	var n := 0
	for row in me.get("shop_ledger", []):
		if row is Dictionary and day - int(row.get("day", 0)) <= days:
			n += int(row.get("gold", 0))
	return n


# 오늘 손님 수 — 날짜로 정해진다. 평판 40 이면 ×1.2
func shop_customers(d: int) -> int:
	var n: int = int(SHOP_CUSTOMERS[0]) + posmod(hash("shop|%d" % d), int(SHOP_CUSTOMERS[1]) - int(SHOP_CUSTOMERS[0]) + 1)
	if int(me.get("reputation", {}).get("kyojin", 0)) >= 40:
		n = int(float(n) * 1.2 + 0.5)
	return n


# 값의 비율로 정하는 구매 확률 — 0.8 이하 0.7 / 1.0 에 0.5 / 1.5 이상 0.2, 사이는 직선
func shop_buy_p(ratio: float) -> float:
	if ratio <= 0.8:
		return 0.7
	if ratio <= 1.0:
		return 0.7 - (ratio - 0.8) / 0.2 * 0.2
	if ratio >= 1.5:
		return 0.2
	return 0.5 - (ratio - 1.0) / 0.5 * 0.3


# 아침 정산(society_new_day) — 어제 좌판. 손님마다 물건 하나를 고르고 값·취향·종류로 산다.
# 판 돈은 금고(till)로, 장부는 28일. 밀린 세금 6주면 영업정지(팔지 않는다)
func _shop_settle() -> void:
	if not shop_open():
		return
	var stock: Dictionary = me.get("shop_stock", {})
	var ids: Array = []
	for id in stock.keys():
		if int(stock[id].get("qty", 0)) > 0:
			ids.append(id)
	if ids.is_empty():
		return
	if wage_frozen():
		_note(str(SOCIETY_NOTES.shop_frozen))
		return
	var kind := str(me.shop_own.get("kind", ""))
	var pool: Array = []
	for nid in npc_greeted:
		if NPCS.has(str(nid)):
			pool.append(str(nid))
	if pool.is_empty():
		return
	var yday := day - 1
	var sold := 0
	var gold := 0
	for i in shop_customers(yday):
		if ids.is_empty():
			break
		var nid := str(pool[posmod(hash("cust|%d|%d" % [yday, i]), pool.size())])
		var id := str(ids[posmod(hash("goods|%d|%d" % [yday, i]), ids.size())])
		var row: Dictionary = stock[id]
		var base := maxi(1, item_value(id))
		var p := shop_buy_p(float(row.get("price", base)) / float(base))
		var d := npc_def(nid)
		if id in Array(d.get("loves", [])) or id in Array(d.get("likes", [])):
			p *= 1.5
		if goods_kind(id) != kind:
			p *= 0.5
		p = clampf(p, 0.05, 0.9)
		if shop_force_p >= 0.0:
			p = shop_force_p
		var roll := float(posmod(hash("buy|%d|%d" % [yday, i]), 1000)) / 1000.0
		if roll < p:
			row["qty"] = int(row.get("qty", 0)) - 1
			sold += 1
			gold += int(row.get("price", base))
			if int(row["qty"]) <= 0:
				ids.erase(id)
	for id in stock.keys():
		if int(stock[id].get("qty", 0)) <= 0:
			stock.erase(id)
	var ledger: Array = me.get("shop_ledger", [])
	ledger.append({"day": yday, "sold": sold, "gold": gold})
	while ledger.size() > SHOP_LEDGER_DAYS:
		ledger.pop_front()
	me["shop_ledger"] = ledger
	if sold > 0:
		me.shop_own["till"] = int(me.shop_own.get("till", 0)) + gold
		_note(str(SOCIETY_NOTES.shop_sold) % [sold, gold])
	else:
		_note(str(SOCIETY_NOTES.shop_none))


func society_place(id: String) -> String:
	if id == "chief" and (council_pending() or tax_dun_active()) and festival_today().is_empty() \
			and hour_now() >= 9.0 and hour_now() < SERVICE_LAST_HOUR:
		return "meeting"   # 마을 회의도, 네 주 밀린 세금 얘기도 같은 자리에서 기다린다
	if id == "officer_park":
		# 수배 중이면 나를 쫓는다(6~24시, 축제 아닌 날). 아니면 저녁엔 야간 순찰
		if wanted_active() and festival_today().is_empty() and hour_now() >= 6.0:
			return "chase"
		if is_evening():
			return "patrol"
		return ""
	if night_owl(id) and is_evening():
		match id:
			"musician":
				return "plaza"
			"angler":
				return "pier"
		return ""
	return ""


# 잠자리 회복 배율 — 「어제」는 day − 1(day_cycle 이 day += 1 한 뒤에 부른다).
# 어젯밤 밖에서 8시간 넘게 → 0.60, 4시간 넘게 → 0.75. 어제 근무했으면 ×0.90.
func rest_mult() -> float:
	var mult := 1.0
	if int(me.get("night_out_day", 0)) == day - 1:
		var mins := float(me.get("night_out_min", 0.0))
		if mins >= 480.0:
			mult = 0.60
		elif mins >= 240.0:
			mult = 0.75
	if worked_on(day - 1):
		mult *= 0.90
	return mult


func _note(line: String) -> void:
	if line != "":
		_society_notes.append(line)


# 하루가 넘어갈 때 사회가 도는 자리 (day_cycle 이 부른다). ko = 기력 소진으로 기절했나(D15 —
# 26시 강제 취침은 아니다). 순서 ①~⑫ 는 계약서 §4 그대로이고, note 는 SOCIETY_NOTES 에서만.
func society_new_day(stats: Array, ko := false) -> void:
	# ① 게스트는 사회가 없다 — me 를 읽지도 않는다
	if Net.is_guest():
		return
	# ② 그릇부터 갖추고, 「자리가 진실」로 직업을 정합한다
	me = _apply_me(me)
	_society_notes = []
	if not JOBS.has(str(me.get("job", ""))):
		me.job = ""
		me.rank = ""
	var seat_job := ""
	var seat_rank := ""
	for inst in INSTITUTIONS:
		var rows := seat_rows(inst)   # 빠진 랭크 키를 채우므로 여기서 KeyError 는 없다
		for r in rows:
			if rows[r] is Array and "player" in rows[r]:
				seat_job = str(INSTITUTIONS[inst].job)
				seat_rank = str(r)
	if seat_job != "" and str(me.job) != seat_job:
		me.job = seat_job
		me.rank = seat_rank
	elif seat_job == "" and str(me.job) != "":
		me.job = ""
		me.rank = ""
	# ③ 계절 첫날 — 지난 계절 수입을 넘기고 지갑을 새로 시드한다
	if day_in_season() == 1:
		me.season_earned_prev = int(me.season_earned)
		me.season_earned = 0
		npc_wallet = {}
		# 정부(S2a) — 창구가 열린 뒤부터. 예산이 먼저 돌고(지난 계절 세금이 장부에 오른다),
		# 그다음 새 고지서가 온다. 복역 중에는 고지서가 없다(「나라가 먹여 주는 동안은 세금 없다」)
		if tax_open():
			gov_season()
			if int(me.get("jail_days_left", 0)) <= 0:
				var bill := issue_tax_bill()
				if int(bill.total) > 0:
					_note(str(SOCIETY_NOTES.tax_bill) % int(bill.total))
				else:
					_note(str(SOCIETY_NOTES.tax_free))
	# 체납 사다리 — 매일 아침, 넘는 문턱에서만 한 번씩. 구류 중엔 멈춘다(「나라가 먹여 주는 동안은
	# 세금 없다」 — serve_jail 이 고지서 기한도 그만큼 미룬다)
	if tax_open() and int(me.get("jail_days_left", 0)) <= 0:
		_tax_step_daily()
	# 좌판(S3a) — 어제 손님. 돈은 금고에 남는다(받으러 가야 수입이다)
	_shop_settle()
	# ④ 어제 번 돈
	if stats.size() > 1:
		me.season_earned += int(stats[1])
	# ⑤ 직업 — 출근 판정. 첫 출근일 아침엔 「일자리를 얻었다」 한 줄
	var job := str(me.job)
	if job != "" and int(me.job_since_day) == day:
		_note(str(SOCIETY_NOTES.hired))
	if job != "" and day > int(me.job_since_day):
		if worked_on(day - 1):
			me.absent_days = 0
		else:
			me.absent_days = int(me.absent_days) + 1
		if int(me.absent_days) == ABSENT_WARN:
			_note(str(SOCIETY_NOTES.absent_warn))
		elif int(me.absent_days) >= ABSENT_FIRE:
			# 해고 — 자리를 비우고 이력에 남긴다. 마을에 말이 돈다(평판 −8)
			seat_clear_player()
			me.job_history.append({"inst": job_inst(), "rank": str(me.rank), "job": job,
				"from": int(me.job_since_day), "to": day, "reason": "fired"})
			me.job = ""
			me.rank = ""
			me.perf = 0
			me.wage_pending = 0
			me.absent_days = 0
			var rep: Dictionary = me.reputation
			rep.kyojin = int(rep.get("kyojin", 0)) - 8
			_note(str(SOCIETY_NOTES.fired))
			job = ""
	# ⑥ 봉급날 — 주인은 세 주치까지만 맡아 둔다. 돈은 창구 앞 E 로만(헌법 §0.3).
	# 봉급날은 받았든 안 받았든 이레마다 돌아온다. wage_day 는 수령(collect_wage)에서만
	# 앞으로 갔으므로, 봉급날 창구를 안 들르면 그날에 멈춘 채 `day == wage_day` 가 두 번
	# 다시 참이 되지 않아 상한도 「봉급날이다」 줄도 첫 한 번뿐이었다(D4 가 죽은 길).
	# 여기서 오늘까지 이레씩 굴려 둔다 — wage_ready(day >= wage_day)·counter_menu 는 그대로 참
	if job != "":
		var wd := int(me.wage_day)
		while wd + 7 <= day:
			wd += 7
		me.wage_day = wd
		if day == wd:
			if int(me.wage_pending) > WAGE_CAP:
				me.wage_pending = WAGE_CAP
				_note(str(SOCIETY_NOTES.wage_lost))
			if int(me.wage_pending) > 0:
				_note(str(SOCIETY_NOTES.wage_paid))
	# ⑦ 대범함 — base < 0 이면 통째로 건너뛴다(성격을 아직 안 물었다).
	# 순서 고정(D15·검증 반영 2차 11): (가) 감쇠 → (나) ko −5 → (다) 흔들림 → (라) 일일 상한 리셋.
	# 뜻: 밤사이 가라앉은 뒤에 기절이 얹힌다. 셈:
	#   state 0 · ko        → (가) 0 → (나) −5.0
	#   이어서 ko 없음      → (가) −2.0
	#   state +1(소매치기 실패) → 다음날 (가) 0.0 → 자백 bold_add(−5) → −5.0
	# 순서를 다시 바꾸면 이 셈과 하네스 REST_OK·PICKPOCKET_OK 기대를 함께 고친다.
	if int(me.boldness_base) >= 0:
		# (가) state 를 0 쪽으로 3 — 넘지 않게
		var st := float(me.boldness_state)
		st = move_toward(st, 0.0, 3.0)
		me.boldness_state = st
		# (나) 기력 소진 기절 −5
		if ko:
			bold_add(-5.0)
		# (다) 흔들림 — 배짱 좋은 날이 닷새면 base +1(상한 60), 조용한 날이 열흘이면 base −1(하한 5)
		st = float(me.boldness_state)
		if st >= 20.0:
			me.bold_days_up = int(me.bold_days_up) + 1
			if int(me.bold_days_up) >= 5:
				me.boldness_base = mini(60, int(me.boldness_base) + 1)
				me.bold_days_up = 0
				_note(str(SOCIETY_NOTES.bold_up))
		else:
			me.bold_days_up = 0
		if st <= 0.0:
			me.bold_days_quiet = int(me.bold_days_quiet) + 1
			if int(me.bold_days_quiet) >= 10:
				me.boldness_base = maxi(5, int(me.boldness_base) - 1)
				me.bold_days_quiet = 0
				_note(str(SOCIETY_NOTES.bold_down))
		else:
			me.bold_days_quiet = 0
		# (라) 오늘 오른 몫 리셋
		_bold_today = {"cave": 0.0, "night": 0.0}
	# ⑧ 밤길 분 — rest_mult 가 day_cycle 에서 이미 소비했다
	me.night_out_min = 0.0
	# 파출소(S2b) — NPC 사건이 생기고 닫힌다. 수배 중이면 아침마다 한 줄
	_npc_crime_tick()
	_case_close_tick()
	if wanted_active():
		_note(str(SOCIETY_NOTES.wanted))
	# 순회 재판(S2c) — 구류 하루, 기소, 재판일
	_court_tick()
	# 자치회(S3c) — 청년회장의 어젯밤: 세 군데를 다 돌았으면 보고를, 안 돌았으면 빠진 밤을 적는다
	if str(me.job) == "youth_head" and day > int(me.job_since_day):
		if int(me.patrol_day) == day - 1 and int(me.patrol_idx) >= 3:
			_note(str(SOCIETY_NOTES.watch_done))
		elif int(me.job_since_day) < day - 1:
			_note(str(SOCIETY_NOTES.watch_missed))
	# ⑨ 이장이 찾아온다 — 어제 신고된 일
	if council_pending():
		_note(str(SOCIETY_NOTES.meeting_summon))
	# 회의의 다음날 — 어제 고른 답의 결과 한 줄(부록 §4 「다음날 아침 note = option.outcome」).
	# 자백은 이 줄이 「이장에게 가야 한다」를 알리는 유일한 통로다(헌법 §0 — 결산 한 줄) —
	# 없으면 자백 다음날 결산이 침묵했다. 같은 날 여러 건을 매듭지어도 같은 줄은 한 번만
	var confessed_yesterday := false
	var outcomes: Array = []
	for mem in me.memories:
		if int(mem.get("settled_day", 0)) != day - 1:
			continue
		var key := str(mem.get("settled", ""))
		if key == "confessed":
			confessed_yesterday = true
		var line := _meeting_outcome(key)
		if line != "" and not (line in outcomes):
			outcomes.append(line)
	for ol in outcomes:
		_note(str(ol))
	# ⑩ 봉사 — 남아 있는 아침마다(첫 봉사 전에도 — 미루면 미룰수록 알려야 한다), 어제 다
	# 채웠으면 「끝났다」. 자백 다음날은 위의 outcome 줄이 이미 사흘을 말했으니 겹치지 않는다
	var pend := service_pending()
	if not pend.is_empty() and not confessed_yesterday:
		_note(str(SOCIETY_NOTES.service_day))
	for rec in me.record:
		if int(rec.get("served", 0)) >= int(rec.get("sentence", 0)) and int(rec.get("served_day", 0)) == day - 1:
			_note(str(SOCIETY_NOTES.service_done))
	# 부인했으면 소문, 배상했으면 용서(부록 §5) — outcome 줄에 이어 붙는다
	if int(me.rumor_day) == day - 1:
		_note(str(SOCIETY_NOTES.rumor))
	for mem in me.memories:
		if str(mem.get("settled", "")) == "paid" and int(mem.get("settled_day", 0)) == day - 1:
			_note(str(SOCIETY_NOTES.forgiven))
			break
	# ⑪ 호칭 구간 — 이장 기준으로만(도배 방지). 기준선은 society_loaded() 가 심는다(D9).
	# 호칭은 호감도 해금 뒤에만 들리므로(talk_opener 가 그 전엔 "") 알림도 그때부터 —
	# 해금 전에 벌목 150 그루로 「벌목꾼」이 됐다고 알리면 아무도 그렇게 안 부르는 호칭을
	# 알리는 셈이다(헌법 §0.4). 기준선은 매일 갱신해 해금 첫 아침에 몰아서 알리지 않는다
	var c := str(player_title("chief").cls)
	if affinity_open and _title_mark != "" and c != _title_mark:
		_note(str(SOCIETY_NOTES.title_changed).format({"title": player_title("chief").text}))
	_title_mark = c
	# 평판이 처음 −20 아래로 내려간 아침 — 한 번만
	if int(me.reputation.kyojin) < -20 and not bool(me.rep_wary_seen):
		me.rep_wary_seen = true
		_note(str(SOCIETY_NOTES.rep_wary))
	# ⑫ 상한 — work_log 는 가장 오래된 근무·독서부터 지우되 「보이는 것」을 봤다는 표시
	# (kind "sees")는 남긴다. 지우면 society.work_start 가 그 페이지를 또 보여 준다
	while me.memories.size() > MEMORY_MAX:
		me.memories.pop_front()
	while me.work_log.size() > WORK_LOG_MAX:
		var cut := -1
		for i in me.work_log.size():
			if str(me.work_log[i].get("kind", "")) != "sees":
				cut = i
				break
		if cut < 0:
			break
		me.work_log.remove_at(cut)


# 회의에서 고른 답(memories.settled: paid/denied/confessed)의 다음날 아침 줄 — 표는
# SOCIETY_LINES.meeting.options 의 key(pay/deny/confess)로 적혀 있어 여기서 잇는다
func _meeting_outcome(settled: String) -> String:
	var key := str({"paid": "pay", "denied": "deny", "confessed": "confess"}.get(settled, ""))
	if key == "":
		return ""
	for o in SOCIETY_LINES.meeting.options:
		if o is Dictionary and str(o.get("key", "")) == key:
			return str(o.get("outcome", ""))
	return ""


# 아침 결산에 덧붙일 사회 줄 — 한 번 읽으면 비운다(하네스는 루프 밖에서 정확히 한 번 읽는다).
func society_note() -> String:
	var s := "\n".join(PackedStringArray(_society_notes))
	_society_notes = []
	return s


# 로드·새 게임·하네스 복원 뒤에 부른다 — 호칭 기준선은 호감도까지 다 읽은 뒤에 잡는다.
# 그 전에 잡으면 첫 아침마다 거짓 알림(D9): _title_mark 가 stranger(로드 전 affinity 0)나
# free_known(옛 게임의 trees_chopped 가 남은 채)으로 박혀 ⑪ 이 없는 변화를 알린다.
func society_loaded() -> void:
	_title_mark = str(player_title("chief").cls)
	_society_notes = []
	_bold_today = {"cave": 0.0, "night": 0.0}


func fresh_tutorial() -> Dictionary:
	var t := {"active": true}
	for pair in TUTORIAL_ORDER:
		t[pair[0]] = false
	return t


# 우측 트래커용 짧은 목표 문구
# %s 는 실제로 설정된 키로 바뀐다 (키 재설정을 따라간다)
# 안내 목표 — 짧게 한 줄. 괄호도, 조작키 안내도 넣지 않는다
# (키는 설정 창과 손에 든 도구가 알려 준다).
const TUTORIAL_SHORT := {
	"moved": "마을을 걸어 보자.",
	"map": "지도를 열어 보자.",
	"quest": "퀘스트 창을 열어 보자.",
	"note": "연구 노트를 펴 보자.",
	"till": "호미로 밭을 갈자.",
	"plant": "씨앗을 심자.",
	"water": "밭에 물을 주자.",
	"harvest": "다 자란 작물을 거두자.",
	"cook": "조리대에서 요리하자.",
	"slept": "침대에서 자자.",
	"board": "의뢰 게시판을 읽어 보자.",
	"chop": "나무를 베자.",
	"mine": "돌을 캐자.",
	"fish": "물가에서 낚시하자.",
	"shop": "잡화점에 들러 보자.",
}


# (조작키를 목표문에 끼워 넣던 표는 없앴다 — 괄호 표기를 전부 걷어냈다)


func tutorial_objective_short() -> String:
	var flag := tutorial_current_flag()
	if flag == "":
		return ""
	return String(TUTORIAL_SHORT.get(flag, ""))


func tutorial_objective() -> String:
	if not tutorial.get("active", false):
		return ""
	for pair in TUTORIAL_ORDER:
		if not tutorial.get(pair[0], false):
			return "다음 목표: " + pair[1]
	return ""


# 밭 갈기 줄기(호미→씨앗→물→수확→요리)는 **이장에게 호미를 받은 뒤**에만
# 안내로 뜬다. 호미는 상점이 서고 용식과 바닷길을 연 다음에 받으므로
# (story2_phase: shop → fisher → farm_talk → farm), 앞선 퀘스트와
# 나란히 떠서 헷갈리는 일이 없다.
func farm_chain_open() -> bool:
	return story2_phase in ["farm", "cook", "done"]


func tutorial_current_flag() -> String:
	if not tutorial.get("active", false):
		return ""
	for pair in TUTORIAL_ORDER:
		# 밭 갈기 줄기는 호미를 받은 뒤부터
		if pair[0] in FARM_CHAIN_FLAGS and not farm_chain_open():
			continue
		# 마을 생활 안내(첫 살림 줄기 밖 목표)는 스토리 3이 열어 줘야 나온다
		if pair[0] not in FARM_CHAIN_FLAGS and not guide_active:
			continue
		if not tutorial.get(pair[0], false):
			return pair[0]
	return ""


# ---- 할아버지의 부탁 ----
#
# 기본 안내(튜토리얼)가 끝나면 이어지는 본 게임의 길잡이.
# 할아버지가 노트에 남긴 부탁을 하나씩 들어주며 빈 장을 채워 간다.
# 새 부탁을 넣을 때는 이 표에 한 줄만 더하면 된다.
#   count: 지금까지 얼마나 했는지 세는 방법 (아래 grandpa_count 참고)
const GRANDPA_QUESTS := [
	{"id": "crops", "count": "crop_kinds", "goal": 3,
		"name": "밭에서 시작한다",
		"desc": "작물 3종류를 수확해 노트에 기록하자",
		"letter": "\"농사는 땅과 나누는 대화란다.\n무엇을 심어도 좋으니, 서로 다른 작물 셋을\n네 손으로 거둬 노트에 적어 두렴.\"",
		"reward": {"money": 230, "seeds": {"tomato": 3}}},
	{"id": "fish", "count": "fish_kinds", "goal": 3,
		"name": "강가의 기록",
		"desc": "물고기 3종류를 낚아 노트에 기록하자",
		"letter": "\"물속에도 답이 있다.\n마을 남쪽 낚시터에서 서로 다른 물고기 셋을\n낚아 보렴. 기다림도 연구의 일부란다.\"",
		"reward": {"money": 360}},
	{"id": "forage", "count": "forage_kinds", "goal": 3,
		"name": "숲의 기록",
		"desc": "채집물·곤충 3종류를 모아 노트에 기록하자",
		"letter": "\"숲은 아무것도 팔지 않지만 모든 것을 준단다.\n열매든 풀이든 벌레든, 서로 다른 셋을 찾아\n노트에 붙여 두렴.\"",
		"reward": {"money": 450, "stone": 10}},
	{"id": "mine", "count": "mob_kills", "goal": 10,
		"name": "땅속의 기록",
		"desc": "동굴에서 몬스터를 10마리 물리치자",
		"letter": "\"동굴 깊은 곳의 것들은 사납지만,\n그 몸에서 나오는 것 또한 재료다.\n조심하되 물러서지는 말거라.\"",
		"reward": {"money": 680, "wood": 20}},
	{"id": "cook", "count": "recipe_kinds", "goal": 3,
		"name": "조리대의 기록",
		"desc": "요리를 3종류 만들어 보자",
		"letter": "\"불과 물과 시간을 다루는 일 —\n요리야말로 가장 오래된 연금술이란다.\n세 가지를 만들어 먹어 보렴.\"",
		"reward": {"money": 900}},
	{"id": "friend", "count": "best_affinity", "goal": 50,
		"name": "사람의 기록",
		"desc": "마을 사람과 친해지자 (호감도 50)",
		"letter": "\"내가 끝내 못 채운 장이 사람이었다.\n마을 사람 하나와 진하게 친해져 보렴.\n선물도 좋고, 매일 인사도 좋다.\"",
		"reward": {"money": 1130}},
	{"id": "note", "count": "note_percent", "goal": 50,
		"name": "절반의 노트",
		"desc": "연구 노트를 절반(50%)까지 채우자",
		"letter": "\"여기까지 왔다면 이제 알 게다.\n노트의 절반을 채우면, 남은 장이 무엇을 원하는지\n스스로 보이기 시작할 거야.\"",
		"reward": {"money": 1350}},
]

var grandpa_step := 0        # 지금 받은 부탁 번호 (GRANDPA_QUESTS의 인덱스)
var grandpa_seen := false    # 첫 부탁 편지를 읽었는가


# 부탁마다 「지금까지 얼마나 했는지」를 센다
func grandpa_count(kind: String) -> int:
	match kind:
		"crop_kinds":
			return crops_harvested.size()
		"fish_kinds":
			return fish_caught.size()
		"forage_kinds":
			return forage_caught.size()
		"mob_kills":
			var n := 0
			for k in mob_kills:
				n += int(mob_kills[k])
			return n
		"recipe_kinds":
			return recipes_cooked.size()
		"best_affinity":
			var best := 0
			for k in affinity:
				best = maxi(best, int(affinity[k]))
			return best
		"note_percent":
			var p: Dictionary = note_progress()
			if int(p.total) <= 0:
				return 0
			return int(round(float(p.filled) * 100.0 / float(p.total)))
	return 0


func grandpa_all_done() -> bool:
	return grandpa_step >= GRANDPA_QUESTS.size()


# 완료한 퀘스트의 기록 — 퀘스트 창(Q)은 완료 항목을 숨기고, 이 목록은
# 나중에 도서관 콘텐츠(지난 이야기 돌아보기)에서 보여줄 밑재료다.
func completed_quests() -> Array:
	var out: Array = []
	var s1_idx: int = STORY1_QUESTS.size() if story_phase == "done" \
		else int(STORY1_PHASE_IDX.get(story_phase, 0))
	for i in mini(s1_idx, STORY1_QUESTS.size()):
		out.append(str(STORY1_QUESTS[i].name))
	if village_built.has("general"):
		out.append("마을의 첫 상점을 세웠다")
	if fisher_quest == "done":
		out.append("바닷길을 열었다 (낚시꾼과 바위 능선)")
	if fisher_home == "done":
		out.append("용식의 부탁 — 살 집 한 채")
	if kitchen_quest == "done":
		out.append("조리대에서 요리를 하자 — 첫 끼를 지어 나눴다")
	if story2_phase == "done":
		out.append("메인 스토리 2 — 마을을 깨우다")
	if move_quest == "done":
		out.append("메인 스토리 3 — 새로운 주민의 이사")
	if story4_phase == "done":
		out.append("메인 스토리 4 — 오래된 마을의 경계")
	if forest_quest == "done":
		out.append("메인 스토리 5 — 숲속에서 발견한 집")
	if story6_phase == "done":
		out.append("메인 스토리 6 — 오래된 책과 사서")
	if story7_phase == "done":
		out.append("메인 스토리 7 — 식지 않는 화로")
	if story8_phase == "done":
		out.append("메인 스토리 8 — 초원에서 온 목동")
	if story9_phase == "done":
		out.append("메인 스토리 9 — 마을의 심장, 마을회관")
	if story10_phase == "done":
		out.append("메인 스토리 10 — 동굴과 탐험")
	if story11_phase == "done":
		out.append("메인 스토리 11 — 할머니의 모자")
	if story12_phase == "done":
		out.append("메인 스토리 12 — 숲의 연금술사")
	if story13_phase == "done":
		out.append("메인 스토리 13 — 할머니의 팔찌")
	if story14_phase == "done":
		out.append("메인 스토리 14 — 마을의 첫 축제")
	if story15_phase == "done":
		out.append("메인 스토리 15 — 마른 온천")
	if story16_phase == "done":
		out.append("메인 스토리 16 — 할머니의 반지")
	if story17_phase == "done":
		out.append("메인 스토리 17 — 할머니의 목걸이")
	if story18_phase == "done":
		out.append("메인 스토리 18 — 할머니의 시계")
	if story19_phase == "done":
		out.append("메인 스토리 19 — 일곱 갈래의 삶")
	if story20_phase == "done":
		out.append("메인 스토리 20 — 가장 오래된 자리")
	for pair in TUTORIAL_ORDER:
		if tutorial.get(pair[0], false):
			out.append(str(pair[1]))
	for i in mini(grandpa_step, GRANDPA_QUESTS.size()):
		out.append(str(GRANDPA_QUESTS[i].name))
	return out


func grandpa_current() -> Dictionary:
	if tutorial.get("active", false) or grandpa_all_done():
		return {}
	return GRANDPA_QUESTS[grandpa_step]


# 지금 부탁을 다 했는가 (진행도가 목표에 닿았는가)
func grandpa_ready() -> bool:
	var q := grandpa_current()
	if q.is_empty():
		return false
	return grandpa_count(str(q.count)) >= int(q.goal)


func grandpa_line() -> String:
	var q := grandpa_current()
	if q.is_empty():
		return ""
	var now: int = mini(grandpa_count(str(q.count)), int(q.goal))
	return "할아버지의 부탁: %s (%d/%d)" % [q.name, now, int(q.goal)]


func merchant_discount() -> bool:
	return int(affinity["merchant"]) >= 50


func seed_price(id: String) -> int:
	var p: int = CROPS[id].seed_price
	if merchant_discount():
		p = int(ceil(p * 0.9))
	return p


# ---- 오늘의 의뢰 ----
#
# 예전에는 「제철 작물 N개 납품」 한 종류뿐이었다. 물고기·광물·채집물·요리·물약이
# 다 있는데 하나도 쓰이지 않았다. 이제 종류를 표로 두고, 게시판에서
# **세 가지 중 하나를 골라** 받는다.
#
# 새 의뢰 종류를 넣을 때는 이 표에 한 줄 + quest_pool에 분기 하나면 된다.
const QUEST_KINDS := [
	{"id": "crop", "label": "작물", "qmin": 3, "qmax": 7, "pay": 1.5},
	{"id": "fish", "label": "물고기", "qmin": 2, "qmax": 4, "pay": 2.0},
	{"id": "forage", "label": "채집물", "qmin": 3, "qmax": 6, "pay": 2.4},
	{"id": "mineral", "label": "광물", "qmin": 3, "qmax": 8, "pay": 1.8},
	{"id": "dish", "label": "요리", "qmin": 1, "qmax": 2, "pay": 2.2},
	{"id": "potion", "label": "물약", "qmin": 1, "qmax": 2, "pay": 2.2},
]
const QUEST_OFFER_COUNT := 3

var quest_offers: Array = []   # 오늘 게시판에 붙은 의뢰들 (하나만 고를 수 있다)


# 작물 id든 아이템 id든 이름을 준다
func item_display_name(id: String) -> String:
	if CROPS.has(id):
		return str(CROPS[id].name)
	if ITEMS.has(id):
		return str(ITEMS[id].name)
	return id


# 도감·의뢰 보상이 보는 **표에 적힌 값**. 연구소 개량은 여기 안 탄다 —
# 마을 안내판이 약속한 것은 「판매가 +N%」이지, 이웃이 부탁하며 얹어 주는
# 삯까지 오른다는 말이 아니다. 파는 값은 crop_unit_price 가 따로 센다.
func item_value(id: String) -> int:
	if CROPS.has(id):
		return int(CROPS[id].sell_price)
	return int(ITEMS.get(id, {}).get("sell", 50))


# 의뢰 납품 등으로 가진 것을 덜어낸다 (작물은 품질 낮은 것부터)
func consume_ingredient(id: String, n: int) -> void:
	if CROPS.has(id):
		consume_produce(id, n)
	else:
		items[id] = maxi(0, int(items[id]) - n)


# 이 종류로 낼 수 있는 후보들 (지금 상태에서 말이 되는 것만)
func quest_pool(kind: String) -> Array:
	var out: Array = []
	match kind:
		"crop":
			# 지금 구할 수 있는 씨앗(상점 판매 중이거나 이미 갖고 있는 것)만
			for id: String in CROP_IDS:
				if season() not in CROPS[id].seasons:
					continue
				if id in shop_seeds or int(seeds.get(id, 0)) > 0 \
						or int(produce.get(id, 0)) > 0:
					out.append(id)
		"fish":
			# 낚싯대가 없으면 물고기 의뢰 자체가 나오지 않는다
			if not is_tool_unlocked("rod"):
				return []
			# 전설급은 의뢰로 내지 않는다 — 못 잡아서 표가 막힌다
			var legendary := ["fish_golden", "fish_king", "fish_dragon",
				"fish_ghost", "fish_starcarp", "fish_moonfish"]
			for f: Dictionary in FISH:
				var fid := str(f.id)
				if fid in legendary:
					continue
				# 이번 계절에 물지 않거나 특정 날씨에만 무는 놈도 뺀다 —
				# 지금 당장 잡을 수 있는 물고기로만 의뢰가 붙는다
				if not (f.weather as Array).is_empty():
					continue
				if not (f.seasons as Array).is_empty() \
						and season() not in f.seasons:
					continue
				out.append(fid)
		"forage":
			out = FORAGE_IDS + BUG_IDS
			# 산호 조각·고대 조각은 0.1%짜리 희귀 채집물 — 의뢰로 내면 표가 막힌다
			out.erase("forage_coral")
			out.erase("forage_relic")
			out.erase("forage_herb")   # 약초도 1% 희귀 드랍이 됐다 — 의뢰 금지
			if not sea_open:
				# 아직 바다를 모른다 — 해변 채집물은 의뢰로 내지 않는다
				for bid: String in ["forage_shell", "forage_trash",
						"forage_glass", "forage_ring"]:
					out.erase(bid)
		"mineral":
			# 곡괭이가 없으면 광물 의뢰가 나오지 않고, 보석은 동굴을
			# 3층까지 내려가 본 뒤에야 의뢰에 붙는다
			if not is_tool_unlocked("pickaxe"):
				return []
			out = ["ore"]
			if mine_deepest >= 3:
				out.append("gem")
		"dish":
			# 한 번이라도 만들어 본 요리만 의뢰로 나온다
			for rid: String in RECIPE_IDS:
				if int(recipes_cooked.get(rid, 0)) > 0:
					out.append(rid)
		"potion":
			# 조합법을 알아낸 물약만
			for fid: String in alchemy_known:
				out.append(fid)
	return out


func make_daily_quest() -> void:
	quest_offers = []
	var kinds: Array = []
	for k in QUEST_KINDS:
		if not quest_pool(str(k.id)).is_empty():
			kinds.append(k)
	if kinds.is_empty():
		quest = {}
		return
	# 날짜 해시로 결정적 — 같은 날은 언제나 같은 의뢰가 붙는다
	var used := {}
	for i in QUEST_OFFER_COUNT:
		var h := fposmod(sin(float(day) * 73.7 + float(i) * 41.3 + 17.3) * 43758.5453, 1.0)
		var k: Dictionary = kinds[int(h * 1000.0) % kinds.size()]
		var pool: Array = quest_pool(str(k.id))
		var item: String = str(pool[int(h * 997.0) % pool.size()])
		if used.has(item):
			continue                       # 같은 물건이 두 번 붙지 않게
		used[item] = true
		var span: int = int(k.qmax) - int(k.qmin) + 1
		var qty: int = int(k.qmin) + int(h * 89.0) % span
		quest_offers.append({
			"item": item,
			"kind": str(k.id),
			"label": str(k.label),
			"qty": qty,
			"reward": maxi(50, int(item_value(item) * qty * float(k.pay))),
		})
	quest = {}


func accept_offer(i: int) -> void:
	if i < 0 or i >= quest_offers.size():
		return
	quest = quest_offers[i].duplicate()
	quest["accepted"] = true
	quest_offers = []


# 진행 중인 의뢰 한 줄 요약 ("" = 없음)
func quest_line() -> String:
	if quest.is_empty() or not bool(quest.get("accepted", false)):
		return ""
	var id: String = str(quest.item)
	return "%s %d/%d" % [item_display_name(id),
		mini(ingredient_count(id), int(quest.qty)), int(quest.qty)]


func pick_fish() -> Dictionary:
	# 지금 조건에 맞는 것 중에서 고른다 (fish_now가 흔한 것부터 정렬해 준다).
	var pool := fish_now()
	if pool.is_empty():
		return FISH[0]          # 조건이 다 어긋나는 일은 없지만, 붕어로 떨어뜨린다
	var total := 0.0
	for f: Dictionary in pool:
		total += float(f.w)
	# 행운이 높을수록 뽑기 값을 뒤(희귀)로 밀어 준다
	var r: float = pow(randf(), 1.0 / (1.0 + total_luck() * 0.08)) * total
	var acc := 0.0
	for f: Dictionary in pool:
		acc += float(f.w)
		if r <= acc:
			return f
	return pool[pool.size() - 1]

# 일별 통계 (결산 화면용, 매일 아침 리셋)
var today_harvest := 0
var today_earned := 0
var today_spent := 0


func _init() -> void:
	for id in CROP_IDS:
		seeds[id] = 0
		produce[id] = 0
	for id in ITEM_IDS:
		items[id] = 0
	# 시작 가방은 완전히 비어 있다 — 씨앗 하나까지 전부 인게임에서 얻는다
	_reset_skills()
	furniture = []   # 처음 집엔 세간이 없다 — 집을 확장하면 기본 가구가 생긴다


func reset_daily() -> void:
	today_harvest = 0
	today_earned = 0
	today_spent = 0
	potion_today = {}   # 약효는 그날 밤까지만 간다


# 새 게임 시작 시 전체 초기화 (오토로드는 씬 전환에도 유지되므로 필수)
func reset_all() -> void:
	day = 1
	minutes = DAY_START
	money = DEV_MONEY if (DEV_MODE and DEV_RICH) else START_MONEY
	energy = ENERGY_MAX
	hunger = HUNGER_MAX
	hunger_open = false
	tool = "hoe"
	seed_index = 0
	wood = 0
	stone = 0
	tool_level = {"hoe": 1, "water": 1, "axe": 1, "pickaxe": 1}
	quest = {}
	quest_offers = []
	fish_caught = {}
	mob_kills = {}
	recipes_cooked = {}
	ending_seen = false
	water_life_found = {}
	water_pending = 0
	relic_pending = ""
	dream_ready = false
	dream_seen = false
	settlers = []
	settler_homes = {}
	empty_houses = []
	settler_offer = ""
	settler_offer_day = 0
	settler_arrive = ""
	settler_arrive_day = 0
	settler_leaving = ""
	settler_leave_day = 0
	npc_last_talk = {}
	last_farewell = ""
	arrive_day = 0
	arrive_clock = ""
	playtime_sec = 0.0
	rocks_mined = 0
	crops_harvested = {}
	minerals_found = {}
	memory_given = false
	forage_caught = {}
	produce_silver = {}
	produce_gold = {}
	barn_built = false
	alchemy_known = []
	alchemy_brews = {}
	alchemy_fails = 0
	potion_today = {}
	owned_pets = []
	active_pet = ""
	for id in CROP_IDS:
		seeds[id] = 0
		produce[id] = 0
	for id in ITEM_IDS:
		items[id] = 0
	for k in affinity:
		affinity[k] = 0
	dating = ""
	spouse = ""
	spouse_gift_day = 0
	gifted_today.clear()
	discovered.clear()
	recipes_unlocked.clear()
	collections_done.clear()
	collection_pending.clear()
	desk_lv = 0
	bed_lv = 0
	desk_queue.clear()
	desk_done_pending.clear()
	dust_swept = 0
	kitchen_found = false
	kitchen_quest = ""
	kitchen_branch = ""
	fisher_quest = ""
	fisher_home = ""
	home_signs = {}
	sea_open_day = 0
	storage_stock = {}
	fisher_choice = 0
	sea_open = false
	merchant_errand = ""
	merchant_day = 0
	stall_hours = []
	forest_quest = ""
	forest_trust = ""
	tutorial_space = true
	forest_day = 0
	affinity_open = false
	move_quest = ""
	move_seeds = 0
	move_day = 0
	move_house = Vector2i(-999, -999)
	home_plots = []
	plot3_quest = ""
	plot3_made = 0
	mail_box = []
	mail_out = []
	mail_sent_day = 0
	mom_quest = ""
	mom_quests_done = []
	spear_quest = ""
	story4_phase = ""
	story6_phase = ""
	story6_day = 0
	old_book_stored = false
	story7_phase = ""
	story8_phase = ""
	story9_phase = ""
	story10_phase = ""
	story11_phase = ""
	story11_clues = []
	grandma_read = 0
	story12_phase = ""
	story12_heard = []
	story13_phase = ""
	story13_heard = []
	story12_done_day = 0
	story14_phase = ""
	story13_done_day = 0
	story14_tasks = []
	story14_greet = []
	story14_fest_day = 0
	story14_toss = false
	story15_phase = ""
	story14_done_day = 0
	story15_mobs = 0
	story15_ore = 0
	onsen_open = false
	onsen_day = 0
	story16_phase = ""
	story15_done_day = 0
	story16_heard = []
	story16_clear = 0
	story16_till = 0
	story17_phase = ""
	story16_done_day = 0
	story17_heard = []
	story17_clear = 0
	story17_care = 0
	story17_done_day = 0
	story18_phase = ""
	story18_heard = []
	story18_traces = []
	story18_done_day = 0
	story19_phase = ""
	story19_shown = []
	story20_phase = ""
	story20_told = []
	note_last_line = false
	gate_open = false
	seed_day = 0
	seed_tile = Vector2i(-1, -1)
	seed_water = false
	residents_now = 1
	hall_stock = {}
	hall_loot_day = 0
	hall_trash_total = 0
	hall_projects = []
	hall_meet_day = 0
	hall_feat_noticed = []
	zones_open = []
	arrivals = []
	npc_greeted = START_GREETED.duplicate()
	me = fresh_me()
	society_v = 1   # 사회 세계 키(S1) — 자리·지갑도 새로
	seats = {}
	gov_budget = {"kyojin": 2000}
	gov_done = []
	gov_building = ""
	gov_tax_season = 0
	gov_log = []
	tax_seize_due = 0
	cases = []
	case_seq = 0
	npc_greed_adj = {}
	npc_wallet = {}
	recipe_items = {}
	tracked_pick = ""
	respawn_queue = []
	chief_house_lv = 0
	hall_noticed = false
	shop_seeds = ["wheat", "corn"]
	recipe_pending = []
	story2_phase = ""
	village_built = ALL_VILLAGE_PLOTS.duplicate()
	if DEV_MODE and OS.get_environment("KYOJIN_SHOT") != "":
		# 검증 하네스 전용: 기본 아이템을 잔뜩 들고 시작한다.
		# 보통 새 게임은 (DEV_MODE라도) 가방이 완전히 비어 있다 —
		# 재료는 전부 게임을 진행하며 직접 얻는다.
		wood = DEV_STOCK
		stone = DEV_STOCK
		for id in CROP_IDS:
			seeds[id] = DEV_STOCK
			produce[id] = DEV_STOCK
		for id in ITEM_IDS:
			items[id] = DEV_STOCK
	_reset_skills()
	furniture = []   # 처음 집엔 세간이 없다 — 집을 확장하면 기본 가구가 생긴다
	tutorial = fresh_tutorial()
	grandpa_step = 0
	grandpa_seen = false
	breed_level = 0
	greenhouse_built = false
	has_horse = false
	riding = false
	horse_tile = Vector2i(14, 24)
	mine_deepest = 1
	fest_history = []
	reset_festival_state()
	owned_gear = []
	equipped = {"weapon": "", "armor": "", "charm": ""}
	# 시작 시 도구/씨앗은 아무것도 주지 않는다 — 스토리·퀘스트로 획득하는 구조
	unlocked_tools = []
	tree_regrow = []
	# 마을은 무건물로 시작한다 — village_built는 위(스토리 절)에서 이미 []다.
	# (여기서 ALL을 다시 채우던 옛 줄이 남아 초기 마을에 건물이 다 서 있었다)
	house_lv = 1
	has_bed = true
	explored = {}
	trees_chopped = 0
	things_built = 0
	u_intro_state = 0
	story_rock_state = 0
	story_gates_left = 0
	tool_slots = default_tool_slots()
	reset_daily()
	# 가축 수는 society._process 의 폴링이 반 초 뒤에야 채우는 런타임 값이라, 가축 많은 게임을
	# 하다가 새 게임을 시작하면 옛 수가 남아 기준선이 「목장주」로 박힌다 — 여기서 먼저 0 으로
	animals_now = 0
	# 호칭 기준선은 호감도까지 다 읽은 뒤에 잡는다 — 그 전에 잡으면 첫 아침마다 거짓 알림(D9).
	# 위의 trees_chopped 같은 자유직 통계가 0 이 된 다음이어야 해서 맨 끝이다.
	society_loaded()


# ---- 계절/날씨 ----

# ==== 계절 축제 ====
#
# 계절마다 한 번, 정해진 날에 마을이 축제를 연다. 계절이 바뀌어도 할 일이
# 그대로이던 문제를 메우는 장치다. 그날은 마을 사람들이 모두 한 곳에 모인다.
#
#   day    그 계절의 며칠째인가 (1~28)
#   place  모이는 곳 ("plaza" / "pier") — NPC 일과가 이날은 여기로 덮인다
#   goal   무엇을 하면 되는가 (참가 방식은 축제마다 다르다)
# 새 축제를 넣을 때는 이 표에 한 줄만 더하면 된다.
# 계절 축제는 **두 해째부터** 열린다 (첫 한 해는 조용히 지나간다)
const FEST_FIRST_YEAR := 2
const FEST_START := 9.0 * 60.0    # 9시 시작
const FEST_END := 18.0 * 60.0     # 18시 종료
const FESTIVALS := {
	SPRING: {"id": "flower", "name": "봄 꽃놀이", "day": 14, "place": "plaza",
		"goal": "마을 사람 모두와 인사하기",
		"desc": "광장에 봄꽃을 늘어놓고 다 같이 모이는 날.\n"
			+ "마을 사람 모두에게 말을 걸어 인사하자.",
		"reward": {"money": 540}},
	SUMMER: {"id": "fishing", "name": "여름 낚시대회", "day": 14, "place": "pier",
		"goal": "낚시터에서 물고기 5마리 낚기",
		"desc": "낚시터에서 열리는 마을 대회.\n"
			+ "해가 지기 전까지 물고기를 많이 낚는 사람이 이긴다.",
		"reward": {"money": 680}},
	FALL: {"id": "harvest", "name": "가을 수확제", "day": 14, "place": "plaza",
		"goal": "가장 좋은 작물 하나 출품하기",
		"desc": "한 해 농사를 겨루는 날.\n"
			+ "가장 자신 있는 작물 하나를 광장에 출품하자.",
		"reward": {"money": 450}},
	WINTER: {"id": "star", "name": "겨울 별빛제", "day": 14, "place": "plaza",
		"goal": "요리 하나 나눠 주기",
		"desc": "가장 긴 밤을 함께 넘기는 날.\n"
			+ "직접 만든 요리를 하나 가져와 나누자.",
		"reward": {"money": 590}},
}

# 오늘의 축제 진행 상태 (날이 바뀌면 초기화된다)
var fest_state_day := -1     # 이 상태가 어느 날짜의 것인가
var fest_greeted: Array = [] # 봄: 인사한 주민
var fest_fish := 0           # 여름: 대회 중 낚은 수
var fest_done := false       # 오늘 축제를 끝냈는가
var fest_history: Array = [] # 지금까지 참가한 축제 id


# 며칠째가 몇 년째인가 (1년 = 사계절)
func year_of_day(d: int) -> int:
	return (d - 1) / (DAYS_PER_SEASON * 4) + 1


# 계절 축제가 열리는 해인가.
#
# **첫 한 해(사계절 한 바퀴)에는 축제가 하나도 열리지 않는다.**
# 마을이 아직 축제를 치를 만큼 여물지 않았다는 설정이자, 첫 해를
# 살림 꾸리기에만 집중하게 하려는 장치다. 두 해째 봄부터 정상으로 돌아온다.
func fest_year_ok(d: int = -1) -> bool:
	return year_of_day(day if d < 0 else d) >= FEST_FIRST_YEAR


func festival_of_day(d: int) -> Dictionary:
	if not fest_year_ok(d):
		return {}          # 첫 해에는 어떤 축제도 열리지 않는다
	var f: Dictionary = FESTIVALS.get(season_of_day(d), {})
	if f.is_empty() or (d - 1) % DAYS_PER_SEASON + 1 != int(f.day):
		return {}
	return f


func festival_today() -> Dictionary:
	return festival_of_day(day)


# 지금 축제가 열려 있는가 (그날 + 시간대 안 + 아직 안 끝냄)
func festival_open() -> bool:
	if festival_today().is_empty() or fest_done:
		return false
	return minutes >= FEST_START and minutes < FEST_END


func reset_festival_state() -> void:
	fest_state_day = day
	fest_greeted = []
	fest_fish = 0
	fest_done = false


# 오늘 축제의 진행도 [지금, 목표]. 목표가 없는 축제는 [0, 0]
func festival_progress() -> Array:
	var f := festival_today()
	if f.is_empty():
		return [0, 0]
	match str(f.id):
		"flower":
			return [fest_greeted.size(), NPCS.size()]
		"fishing":
			return [fest_fish, 5]
	return [0, 0]


func festival_line() -> String:
	var f := festival_today()
	if f.is_empty():
		return ""
	if fest_done:
		return "%s — 잘 즐겼다!" % f.name
	if minutes < FEST_START:
		return "오늘은 %s! (9시 시작)" % f.name
	if minutes >= FEST_END:
		return "%s — 오늘은 끝났다" % f.name
	var p := festival_progress()
	if int(p[1]) > 0:
		return "%s: %s (%d/%d)" % [f.name, f.goal, mini(int(p[0]), int(p[1])), int(p[1])]
	return "%s: %s" % [f.name, f.goal]


func season_of_day(d: int) -> int:
	return int(floor((d - 1) / float(DAYS_PER_SEASON))) % 4


func season() -> int:
	return season_of_day(day)


func season_name() -> String:
	return SEASON_NAMES[season()]


func season_key() -> String:
	return SEASON_KEYS[season()]


func day_in_season() -> int:
	return (day - 1) % DAYS_PER_SEASON + 1


# 날씨 표. 새 날씨를 넣을 때는 여기에 한 줄이면 된다.
#   seasons = 나오는 계절 · weight = 뽑힐 무게 (맑음 대비)
#   wet     = 밭이 하루 종일 젖어 있는가 (물주기를 안 해도 된다)
#   harsh   = 궂은 날씨 (축사가 있으면 동물이 알아서 배부르다)
#
# 날씨가 그날 **무엇을 할지**를 바꾸는 것이 요점이다:
#   안개 = 채집 · 폭풍 = 목재(대신 밭이 상한다) · 별밤 = 빛 속성 재료
const WEATHERS := {
	WEATHER_SUN: {"name": "맑음", "icon": "☀", "weight": 100,
		"seasons": [SPRING, SUMMER, FALL, WINTER], "wet": false, "harsh": false,
		"note": ""},
	WEATHER_RAIN: {"name": "비", "icon": "☔", "weight": 26,
		"seasons": [SPRING, SUMMER, FALL], "wet": true, "harsh": true,
		"note": "오늘은 비가 온다. 물주기는 쉬자!"},
	WEATHER_SNOW: {"name": "눈", "icon": "☃", "weight": 40,
		"seasons": [WINTER], "wet": false, "harsh": true,
		"note": "함박눈이 내린다."},
	WEATHER_FOG: {"name": "안개", "icon": "≋", "weight": 16,
		"seasons": [SPRING, FALL, WINTER], "wet": false, "harsh": false,
		"note": "짙은 안개. 멀리는 안 보여도 발밑의 것들이 잘 보인다 — 채집하기 좋은 날."},
	WEATHER_STORM: {"name": "폭풍", "icon": "⚡", "weight": 11,
		"seasons": [SUMMER, FALL], "wet": true, "harsh": true,
		"note": "밤새 폭풍이 몰아쳤다. 밭이 상했지만 부러진 가지가 잔뜩 떨어져 있다."},
	WEATHER_STAR: {"name": "별밤", "icon": "✦", "weight": 13,
		"seasons": [SPRING, SUMMER, FALL, WINTER], "wet": false, "harsh": false,
		"note": "별이 유난히 밝다. 빛을 품은 것들이 나오는 밤이다."},
}
const WEATHER_IDS := [WEATHER_SUN, WEATHER_RAIN, WEATHER_SNOW,
	WEATHER_FOG, WEATHER_STORM, WEATHER_STAR]


func weather_of_day(d: int) -> int:
	# 날짜 기반 결정적 해시 → 저장할 필요 없이 항상 같은 날씨
	var h := fposmod(sin(float(d) * 127.1 + 311.7) * 43758.5453, 1.0)
	var s := season_of_day(d)
	var total := 0.0
	for w: int in WEATHER_IDS:
		if s in WEATHERS[w].seasons:
			total += float(WEATHERS[w].weight)
	var r := h * total
	for w: int in WEATHER_IDS:
		if s not in WEATHERS[w].seasons:
			continue
		r -= float(WEATHERS[w].weight)
		if r <= 0.0:
			return w
	return WEATHER_SUN


func weather_today() -> int:
	return weather_of_day(day)


func weather_def(w: int) -> Dictionary:
	return WEATHERS.get(w, WEATHERS[WEATHER_SUN])


func weather_icon(w: int) -> String:
	return str(weather_def(w).icon)


func weather_name(w: int) -> String:
	return str(weather_def(w).name)


# 밭이 하루 종일 젖어 있는 날인가 (비 · 폭풍)
func weather_wet(w: int) -> bool:
	return bool(weather_def(w).wet)


# 궂은 날인가 (축사가 동물을 알아서 먹이는 날 — 비 · 눈 · 폭풍)
func weather_harsh(w: int) -> bool:
	return bool(weather_def(w).harsh)


# ---- 씨앗 ----

func owned_seed_ids() -> Array:
	var out := []
	for id in CROP_IDS:
		if seeds[id] > 0:
			out.append(id)
	return out


func current_seed_id() -> String:
	var owned := owned_seed_ids()
	if owned.is_empty():
		return ""
	seed_index = seed_index % owned.size()
	return owned[seed_index]


# 가진 씨앗 총 수 — 0이면 가방의 씨앗 주머니 항목 자체를 숨긴다
func seed_total() -> int:
	var n := 0
	for id: String in CROP_IDS:
		n += int(seeds[id])
	return n


func cycle_seed() -> void:
	var owned := owned_seed_ids()
	if owned.is_empty():
		seed_index = 0
	else:
		seed_index = (seed_index + 1) % owned.size()


func clock_text() -> String:
	var m := int(minutes)
	var h := int(m / 60.0) % 24
	var ampm := "오전" if h < 12 else "오후"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	# 1분 단위로 표시해 시간이 흐르는 게 체감되게 한다
	return "%s %d:%02d" % [ampm, h12, m % 60]


# ---- 저장 ----

# grid_data 는 **사람이 바꾼 칸만** 담긴 성긴 목록이다 (KyojinSaveIO.grid_cells).
# grid_w/grid_h 는 그 목록이 만들어진 세계의 크기 — 세계가 넓어지면 좌표가
# 어긋나므로, 불러올 때 이 둘이 다르면 밭 상태는 버린다.
func build_save(grid_data: Array, player_pos: Vector2, objects_data: Array = [],
		animals_data: Array = [], grid_w: int = 0, grid_h: int = 0) -> Dictionary:
	return {
		"day": day,
		"minutes": minutes,
		"money": money,
		"energy": energy,
		"hunger": hunger, "hunger_open": hunger_open,
		"seeds": seeds,
		"produce": produce,
		"items": items,
		"fish_caught": fish_caught,
		"mob_kills": mob_kills,
		"affinity": affinity,
		"dating": dating, "spouse": spouse, "spouse_gift_day": spouse_gift_day,
		"discovered": discovered,
		"recipes_unlocked": recipes_unlocked, "collections_done": collections_done,
		"quest": quest,
		"quest_offers": quest_offers,
		"tutorial": tutorial,
		"guide_active": guide_active,
		"alchemy_known": alchemy_known,
		"alchemy_brews": alchemy_brews,
		"alchemy_fails": alchemy_fails,
		"potion_today": potion_today,
		"breed_level": breed_level,
		"greenhouse_built": greenhouse_built,
		"has_horse": has_horse,
		"horse_tile": [horse_tile.x, horse_tile.y],
		"mine_deepest": mine_deepest,
		"fest_history": fest_history,
		"owned_gear": owned_gear,
		"equipped": equipped,
		"grandpa_step": grandpa_step,
		"grandpa_seen": grandpa_seen,
		"unlocked_tools": unlocked_tools,
		"wood": wood,
		"stone": stone,
		"tool_level": tool_level,
		"tool_slots": tool_slots,
		"tree_regrow": tree_regrow,
		"player_name": player_name,
		"farm_name": farm_name,
		"village_name": village_name,
		"village_built": village_built,
		"house_lv": house_lv,
		"has_bed": has_bed,
		"desk_lv": desk_lv, "bed_lv": bed_lv, "desk_queue": desk_queue,
		"dust_swept": dust_swept, "kitchen_found": kitchen_found,
		"kitchen_quest": kitchen_quest, "kitchen_branch": kitchen_branch,
		"fisher_quest": fisher_quest, "fisher_choice": fisher_choice,
		"fisher_home": fisher_home, "sea_open_day": sea_open_day,
		"home_signs": home_signs,
		"storage_stock": storage_stock,
		"sea_open": sea_open, "story2_phase": story2_phase,
		"merchant_errand": merchant_errand, "merchant_day": merchant_day,
		"stall_hours": stall_hours,
		"forest_quest": forest_quest, "forest_day": forest_day,
		"forest_trust": forest_trust, "tutorial_space": tutorial_space,
		"affinity_open": affinity_open,
		"move_quest": move_quest, "move_day": move_day, "move_min": move_min,
		"move_seeds": move_seeds,
		"move_house": [move_house.x, move_house.y],
		"home_plots": home_plots,
		"plot3_quest": plot3_quest, "plot3_made": plot3_made,
		"mail_box": mail_box, "mail_out": mail_out,
		"mail_sent_day": mail_sent_day,
		"mom_quest": mom_quest, "mom_quests_done": mom_quests_done,
		"spear_quest": spear_quest, "chief_house_lv": chief_house_lv,
		"hall_noticed": hall_noticed, "shop_seeds": shop_seeds,
		"story4_phase": story4_phase, "zones_open": zones_open,
		"story6_phase": story6_phase, "story6_day": story6_day,
		"old_book_stored": old_book_stored,
		"story7_phase": story7_phase, "story8_phase": story8_phase,
		"story9_phase": story9_phase, "story10_phase": story10_phase,
		"story11_phase": story11_phase, "story11_clues": story11_clues,
		"grandma_read": grandma_read,
		"story12_phase": story12_phase, "story12_heard": story12_heard,
		"story13_phase": story13_phase, "story13_heard": story13_heard,
		"story12_done_day": story12_done_day,
		"story14_phase": story14_phase, "story13_done_day": story13_done_day,
		"story14_tasks": story14_tasks, "story14_greet": story14_greet,
		"story14_fest_day": story14_fest_day, "story14_toss": story14_toss,
		"story15_phase": story15_phase, "story14_done_day": story14_done_day,
		"story15_mobs": story15_mobs, "story15_ore": story15_ore,
		"onsen_open": onsen_open, "onsen_day": onsen_day,
		"story16_phase": story16_phase, "story15_done_day": story15_done_day,
		"story16_heard": story16_heard, "story16_clear": story16_clear,
		"story16_till": story16_till,
		"story17_phase": story17_phase, "story16_done_day": story16_done_day,
		"story17_heard": story17_heard, "story17_clear": story17_clear,
		"story17_care": story17_care, "story17_done_day": story17_done_day,
		"story18_phase": story18_phase, "story18_heard": story18_heard,
		"story18_traces": story18_traces, "story18_done_day": story18_done_day,
		"story19_phase": story19_phase, "story19_shown": story19_shown,
		"story20_phase": story20_phase, "story20_told": story20_told,
		"note_last_line": note_last_line, "gate_open": gate_open,
		"seed_day": seed_day, "seed_water": seed_water,
		"seed_tile": [seed_tile.x, seed_tile.y],
		"hall_stock": hall_stock,
		"hall_loot_day": hall_loot_day, "hall_trash_total": hall_trash_total,
		"hall_projects": hall_projects, "hall_meet_day": hall_meet_day,
		"hall_feat_noticed": hall_feat_noticed,
		"arrivals": arrivals, "npc_greeted": npc_greeted,
		"me": me,
		# 사회 세계 키(S1) — 호스트 권위, 이 한 줄로 게스트에도 전파된다
		"society_v": society_v,
		"seats": seats,
		"npc_wallet": npc_wallet,
		# 정부(S2a)
		"gov_budget": gov_budget, "gov_done": gov_done, "gov_building": gov_building,
		"gov_tax_season": gov_tax_season, "gov_log": gov_log,
		"cases": cases, "case_seq": case_seq, "npc_greed_adj": npc_greed_adj,
		"recipe_items": recipe_items, "tracked_pick": tracked_pick, "respawn_queue": respawn_queue,
		"explored": explored.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"trees_chopped": trees_chopped, "things_built": things_built,
		"u_intro": u_intro_state,
		"rock_state": story_rock_state,
		"gates_left": story_gates_left,
		"skills": skills,
		"furniture": furniture,
		"recipes_cooked": recipes_cooked,
		"ending_seen": ending_seen,
		"water_life_found": water_life_found, "dream_ready": dream_ready,
		"dream_seen": dream_seen, "arrive_day": arrive_day,
		"arrive_clock": arrive_clock, "playtime_sec": playtime_sec,
		"rocks_mined": rocks_mined,
		"settlers": settlers, "settler_homes": settler_homes,
		"empty_houses": empty_houses, "settler_offer": settler_offer,
		"settler_offer_day": settler_offer_day,
		"settler_arrive": settler_arrive,
		"settler_arrive_day": settler_arrive_day,
		"settler_leaving": settler_leaving,
		"settler_leave_day": settler_leave_day,
		"npc_last_talk": npc_last_talk, "last_farewell": last_farewell,
		"crops_harvested": crops_harvested,
		"minerals_found": minerals_found,
		"memory_given": memory_given,
		"forage_caught": forage_caught,
		"produce_silver": produce_silver,
		"produce_gold": produce_gold,
		"barn_built": barn_built,
		"owned_pets": owned_pets,
		"active_pet": active_pet,
		"gender": gender,
		"appearance": appearance,
		"main_story": story_phase,
		"tile": 32,
		"player": [player_pos.x, player_pos.y],
		"grid_cells": grid_data,
		"grid_w": grid_w, "grid_h": grid_h,
		"objects": objects_data,
		"animals": animals_data,
	}


func save_game(grid_data: Array, player_pos: Vector2, objects_data: Array = [],
		animals_data: Array = [], grid_w: int = 0, grid_h: int = 0) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(build_save(grid_data, player_pos,
			objects_data, animals_data, grid_w, grid_h)))


# ---- 멀티플레이 동기화용 (그리드 제외 공유 상태) ----

func build_stats() -> Dictionary:
	return {
		"money": money, "wood": wood, "stone": stone,
		"seeds": seeds, "produce": produce, "items": items,
		"fish_caught": fish_caught, "mob_kills": mob_kills, "affinity": affinity,
		"quest": quest, "tool_level": tool_level,
		"unlocked_tools": unlocked_tools,   # 장터에서 도구가 오가면 이것도 맞춰야 한다
		"skills": skills, "furniture": furniture,
		"recipes_cooked": recipes_cooked, "ending_seen": ending_seen,
		"crops_harvested": crops_harvested, "minerals_found": minerals_found,
		"memory_given": memory_given, "forage_caught": forage_caught,
		"produce_silver": produce_silver, "produce_gold": produce_gold,
		"barn_built": barn_built,
		"owned_pets": owned_pets, "active_pet": active_pet,
		"discovered": discovered, "recipes_unlocked": recipes_unlocked,
		"collections_done": collections_done,
	}


func apply_stats(d: Dictionary) -> void:
	money = int(d.get("money", money))
	wood = int(d.get("wood", wood))
	stone = int(d.get("stone", stone))
	for k in d.get("seeds", {}):
		seeds[k] = int(d.seeds[k])
	for k in d.get("produce", {}):
		produce[k] = int(d.produce[k])
	for k in d.get("items", {}):
		items[k] = int(d.items[k])
	for k in d.get("fish_caught", {}):
		fish_caught[k] = int(d.fish_caught[k])
	for k in d.get("mob_kills", {}):
		mob_kills[k] = int(d.mob_kills[k])
	for k in d.get("affinity", {}):
		affinity[k] = int(d.affinity[k])
	discovered = d.get("discovered", {})
	recipes_unlocked = d.get("recipes_unlocked", [])
	collections_done = d.get("collections_done", [])
	_check_collections()   # 예전 세이브: 이미 채운 묶음이 있으면 지금 열어 준다
	dating = str(d.get("dating", ""))
	spouse = str(d.get("spouse", ""))
	spouse_gift_day = int(d.get("spouse_gift_day", 0))
	for k in d.get("tool_level", {}):
		tool_level[k] = int(d.tool_level[k])
	if d.has("unlocked_tools"):
		unlocked_tools = []
		for t in d.unlocked_tools:
			unlocked_tools.append(str(t))
	apply_skills_data(d.get("skills", {}))
	if d.has("furniture"):
		apply_furniture_data(d.furniture)
	for k in d.get("recipes_cooked", {}):
		recipes_cooked[k] = int(d.recipes_cooked[k])
	owned_pets = d.get("owned_pets", owned_pets)
	active_pet = str(d.get("active_pet", active_pet))
	ending_seen = bool(d.get("ending_seen", ending_seen))
	for k in d.get("crops_harvested", {}):
		crops_harvested[k] = int(d.crops_harvested[k])
	for k in d.get("minerals_found", {}):
		minerals_found[k] = bool(d.minerals_found[k])
	memory_given = bool(d.get("memory_given", memory_given))
	for k in d.get("forage_caught", {}):
		forage_caught[k] = int(d.forage_caught[k])
	for k in d.get("produce_silver", {}):
		produce_silver[k] = int(d.produce_silver[k])
	for k in d.get("produce_gold", {}):
		produce_gold[k] = int(d.produce_gold[k])
	barn_built = bool(d.get("barn_built", barn_built))
	var q: Variant = d.get("quest", {})
	if typeof(q) == TYPE_DICTIONARY:
		if q.is_empty():
			quest = {}
		else:
			# 의뢰는 **crop 이 아니라 item** 이다 (make_daily_quest 참고 —
			# 작물만이 아니라 물고기·광물·요리도 붙는다). q.crop 을 읽고
			# 있었으므로 호스트가 의뢰를 받아 둔 상태에서 손님이 들어오면
			# 그 자리에서 죽었다. kind·label 도 같이 넘긴다 — 안 그러면
			# quest_line()·village_ui 가 읽을 것이 없다
			quest = {
				"item": str(q.get("item", "")), "kind": str(q.get("kind", "")),
				"label": str(q.get("label", "")), "qty": int(q.get("qty", 0)),
				"reward": int(q.get("reward", 0)),
				"accepted": bool(q.get("accepted", false)),
			}


# JSON에서 읽은 스킬/가구 데이터를 타입을 맞춰 적용 (저장 로드·멀티 동기화 공용)
func apply_skills_data(data: Dictionary) -> void:
	for k in data:
		if skills.has(k):
			skills[k] = {"lv": int(data[k].lv), "xp": float(data[k].xp)}


func apply_furniture_data(data: Array) -> void:
	furniture = []
	for f in data:
		if FURNITURE.has(f.get("id", "")):
			furniture.append({"id": f.id, "x": float(f.x), "y": float(f.y)})


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
