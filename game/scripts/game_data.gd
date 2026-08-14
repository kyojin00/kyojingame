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
	"wheat": {"name": "밀", "seed_price": 30, "sell_price": 75, "grow_days": 3,
		"seasons": [SPRING, SUMMER, FALL, WINTER]},
	"potato": {"name": "감자", "seed_price": 30, "sell_price": 80, "grow_days": 2, "seasons": [SPRING]},
	"carrot": {"name": "당근", "seed_price": 40, "sell_price": 110, "grow_days": 3, "seasons": [SPRING]},
	"strawberry": {"name": "딸기", "seed_price": 60, "sell_price": 170, "grow_days": 4, "seasons": [SPRING]},
	"tomato": {"name": "토마토", "seed_price": 50, "sell_price": 130, "grow_days": 3, "seasons": [SUMMER]},
	# 옥수수 — 처음부터 파는 두 번째 씨앗 (그래서 봄에도 심을 수 있다)
	"corn": {"name": "옥수수", "seed_price": 40, "sell_price": 150, "grow_days": 4,
		"seasons": [SPRING, SUMMER, FALL]},
	"watermelon": {"name": "수박", "seed_price": 120, "sell_price": 380, "grow_days": 7, "seasons": [SUMMER]},
	"pumpkin": {"name": "호박", "seed_price": 100, "sell_price": 320, "grow_days": 7, "seasons": [FALL]},
	"eggplant": {"name": "가지", "seed_price": 45, "sell_price": 120, "grow_days": 3, "seasons": [FALL]},
	"cabbage": {"name": "배추", "seed_price": 70, "sell_price": 200, "grow_days": 5, "seasons": [FALL]},
	"winter_radish": {"name": "겨울무", "seed_price": 60, "sell_price": 180, "grow_days": 4, "seasons": [WINTER]},
	# 봄
	"spinach": {"name": "시금치", "seed_price": 35, "sell_price": 95, "grow_days": 2, "seasons": [SPRING]},
	"onion": {"name": "양파", "seed_price": 55, "sell_price": 150, "grow_days": 4, "seasons": [SPRING]},
	"pea": {"name": "완두", "seed_price": 45, "sell_price": 130, "grow_days": 3, "seasons": [SPRING, SUMMER]},
	# 여름
	"pepper": {"name": "고추", "seed_price": 65, "sell_price": 175, "grow_days": 4, "seasons": [SUMMER]},
	"melon": {"name": "참외", "seed_price": 110, "sell_price": 330, "grow_days": 6, "seasons": [SUMMER]},
	"garlic": {"name": "마늘", "seed_price": 50, "sell_price": 140, "grow_days": 3, "seasons": [SUMMER]},
	# 가을
	"sweet_potato": {"name": "고구마", "seed_price": 80, "sell_price": 230, "grow_days": 5, "seasons": [FALL]},
	"bean": {"name": "콩", "seed_price": 55, "sell_price": 155, "grow_days": 4, "seasons": [FALL]},
	"rice": {"name": "벼", "seed_price": 90, "sell_price": 260, "grow_days": 6, "seasons": [FALL]},
	# 겨울 — 추운 계절은 종류가 적은 대신 값이 좋다
	"leek": {"name": "대파", "seed_price": 55, "sell_price": 165, "grow_days": 3, "seasons": [WINTER]},
	"beet": {"name": "비트", "seed_price": 85, "sell_price": 250, "grow_days": 5, "seasons": [WINTER]},
	"snow_cabbage": {"name": "눈배추", "seed_price": 130, "sell_price": 400, "grow_days": 7, "seasons": [WINTER]},
	# 사계절 — 값은 싸지만 언제든 심을 수 있다
	"herb_leaf": {"name": "약초잎", "seed_price": 40, "sell_price": 105, "grow_days": 3, "seasons": [SPRING, SUMMER, FALL, WINTER]},
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

const SAVE_PATH := "user://kyojin_farm_save.json"

# ---- 개발/테스트용 치트 (출시 전에 DEV_MODE를 false로 되돌린다) ----
# 켜져 있으면 새 게임 시작 시 소지금과 기본 아이템을 잔뜩 들고 시작한다.
const DEV_MODE := true
const DEV_MONEY := 100000000
const DEV_STOCK := 10000        # 목재·석재·씨앗·아이템 개수
const START_MONEY := 500        # 출시용 시작 소지금

# ---- 키 설정 (사람마다 다르게 바꿀 수 있다) ----
const KEYBIND_PATH := "user://keybinds.json"
# [액션, 설명] — 이 목록이 설정 화면의 키 안내 겸 리바인딩 대상
const BINDABLE_ACTIONS := [
	["move_up", "위로 이동"],
	["move_down", "아래로 이동"],
	["move_left", "왼쪽으로 이동"],
	["move_right", "오른쪽으로 이동"],
	["use_tool", "도구 사용 / 낚시 / 공격"],
	["interact", "상호작용 (대화/입장/줍기)"],
	["mount", "말 타기 / 내리기"],
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
# 개발용 시작 자금 (출시 전 500으로 되돌릴 것!)
var money := DEV_MONEY if DEV_MODE else START_MONEY
var energy := ENERGY_MAX
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


func skill_xp_needed(lv: int) -> float:
	return 30.0 + 20.0 * lv * lv


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
	if leveled >= SKILL_MAX_LV:
		check_skill_water(id)   # 만렙 증표 — 생명의 물 한 병
	return leveled


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
	"heart_rug": {"name": "하트 러그", "price": 0, "w": 96, "h": 78, "solid": false},
}
const FURNITURE_IDS := ["table", "chair", "chest", "rug", "plant", "bookshelf", "lamp", "small_table"]
# 제작·선물로 들여놓는 세간 — 집 확장 때 기본 세간에 밀려 지워지면 안 된다
const CRAFT_FURN := ["plant", "trash_bin", "heart_rug"]
var furniture: Array = []  # [{id, x, y}]


func default_furniture() -> Array:
	return [
		{"id": "rug", "x": 294.0, "y": 309.0},
		{"id": "table", "x": 339.0, "y": 228.0},
		{"id": "chair", "x": 312.0, "y": 243.0},
		{"id": "chair", "x": 435.0, "y": 243.0},
		{"id": "chest", "x": 516.0, "y": 165.0},
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
var appearance := {"hair": 0, "shirt": 0, "pants": 0, "shoes": 0}
const HAIR_PREFIX := ["new_boy", "hair_short", "hair_spiky", "player_f"]
const HAIR_NAMES := ["민머리", "짧은 머리", "삐죽 머리", "긴 머리"]
const SHIRT_NAMES := ["파랑", "분홍", "초록", "노랑"]
const PANTS_NAMES := ["갈색", "남색", "잿빛", "카키"]
const SHOES_NAMES := ["밤색", "검정", "빨강", "파랑"]
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


# 표준 팔레트로 뽑힌 플레이어 도트의 옷 색을 ap 선택에 맞춰 바꾼다.
# 색은 생성기(make_sprites.py PAL)와 정확히 같은 값이라 픽셀 단위로 맞는다.
func recolor_player_image(img: Image, ap: Dictionary) -> void:
	var mp := {}
	for tbl_sel in [[APPEAR_SHIRT, int(ap.shirt)], [APPEAR_PANTS, int(ap.pants)],
			[APPEAR_SHOES, int(ap.shoes)]]:
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
# 유저 닉네임: 스토리 1에서 우체부 아저씨가 물어봐 입력받는다
var player_name := ""

# 마을 발전: 처음 마을에는 건물이 하나도 없다 (플레이어의 집만 스토리로 열린다).
# 상점은 메인 스토리 2에서 직접 짓고, 나머지는 이장의 「마을 발전 이야기」로
# 재료를 모아 하나씩 세운다. (건물 id는 main.gd의 VILLAGE_PLOTS 키)
const ALL_VILLAGE_PLOTS := ["post", "general", "lab", "smith", "ranch", "inn",
	"library", "fish", "hall"]
var village_built: Array = []

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
			return "재료를 모아 상점을 짓자 (목재 %d·돌 %d) — 상점 터 게시판에서 E" \
				% [SHOP_BUILD_WOOD, SHOP_BUILD_STONE]
		"farm_talk":
			return "이장에게 가 보자 (E)"
	return ""

# 낚시꾼 퀘스트 (메인 스토리 3): 전설의 황금잉어를 쫓는 낚시꾼과 함께
# 남쪽 바위 능선을 뚫어 바다·해변을 열고, 간이낚싯대(낚시)를 얻는다.
#   "": 아직 (첫 수확 뒤 시작) / meet: 광장의 낚시꾼에게 말 걸기 /
#   follow: 함께 능선으로 / open: 길목 바위 캐기 / done: 완료
var fisher_quest := ""
var fisher_choice := 0     # 황금잉어 선택지 (1: 꼭 잡겠다 / 2: 욕심 없다)
var sea_open := false      # 남쪽 바다·해변 개방 (능선 길목이 뚫렸다)

# 민지(잡화점)의 서브 퀘스트 「해변 노점」 — 바다가 열린 뒤부터 계산대
# 대화 선택지에 ❗로 뜬다. 재료를 모아다 주면 해변에 노점이 선다.
#   "": 아직 안 받음 / doing: 재료 모으는 중 / done: 노점 완성
var merchant_errand := ""
# 민지가 마을에 도착해 첫 인사를 나눈 날 (0 = 아직/구세이브).
# 도착 첫날은 잡화점에 요리 레시피 선반이 아직 없다 — 다음 날부터 진열
var merchant_day := 0
# 오늘 민지가 노점에 나와 있는 시각들 (분 단위 시작점). 하루 3번, 1시간씩 —
# 매일 아침 새로 뽑는다. 민지가 있어야 노점에서 「구매」할 수 있다 (판매는 상시).
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
# 직접 낚아 봤어야 선반에 오른다 (민지가 "이 생선 요리법 필요하지?" 하는 셈).
# 물고기가 안 드는 요리라면 언제나 진열.
func shop_dish_on_shelf(did: String) -> bool:
	var needs: Dictionary = RECIPES.get(did, {}).get("needs", {})
	for mid: String in needs:
		if str(mid).begins_with("fish_") and int(fish_caught.get(mid, 0)) <= 0:
			return false
	return true


# 초반 음식 레시피 — 잡화점에서 단계적으로 풀린다. id -> 가격
const SHOP_FOOD_RECIPES := {
	"dish_berry_jam": 150, "flour": 100, "dish_bread": 150,
	"dish_berry_toast": 250,
}
const SHOP_FOOD_IDS := ["dish_berry_jam", "flour", "dish_bread",
	"dish_berry_toast"]


# 초반 음식 레시피의 진열 조건 — 재료를 겪어 본 순서대로 하나씩 열린다.
#   산딸기잼      산딸기를 주워 본 적이 있다
#   밀가루        밀을 처음 수확했다 (수확이 곧 발견 기록)
#   빵            밀가루를 얻어 봤다
#   산딸기잼 토스트  밀가루나 산딸기잼 중 하나라도 만들어 봤다
func shop_food_on_sale(rid: String) -> bool:
	match rid:
		"dish_berry_jam":
			return discovered.has("forage_berry")
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


# 오늘 민지가 노점에 나올 시각 세 개를 뽑는다 (9시~19시 사이, 서로 겹치지 않게)
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
# 호기심 많고 모험을 좋아하는 소년 무진. 이장과 상의해 받아주기로 하고,
# 이장은 앞으로의 이사 결정권을 플레이어에게 맡긴다. 집터 레시피(비싸다)를
# 사서 재료를 모아 집터를 만들고, 해금된 땅 중 원하는 풀밭에 집 자리를
# 직접 정하면 집이 지어진다. 다음 날 무진이 이사 와 첫인사를 나눈다.
#   "": 아직 / letter: 편지 읽는 중 / show: 이장에게 보여주기 /
#   build: 집터 레시피 구매·제작·설치 / wait: 완공 — 내일 이사 온다 /
#   greet: 무진 도착 — 인사하러 가기 / done: 완료 (이주·집터 시스템 해금)
var move_quest := ""
var move_day := 0            # 단계 전환 기준 날 (편지 도착·이사 대기)
var move_house := Vector2i(-999, -999)   # 무진의 집 자리 (수락한 집터)
const HOUSING_KIT_PRICE := 5000          # 집터 레시피 값 — 일부러 비싸다
# 스프링클러는 퀘스트 보상이 아니라 잡화점 레시피가 됐다 —
# 농사 실력이 이만큼 붙어야 선반에 올라온다
const SPRINKLER_FARM_LV := 3
const SPRINKLER_RECIPE_PRICE := 500
# 미리 마련해 둔 빈 집터들 — [{x, y, used}]. **빈 집터가 있어야만**
# 이주 희망 편지를 수락할 수 있다 (수락하면 첫 빈 집터에 집이 지어진다)
var home_plots: Array = []


func first_empty_plot() -> Vector2i:
	for p: Dictionary in home_plots:
		if not bool(p.get("used", false)):
			return Vector2i(int(p.x), int(p.y))
	return Vector2i(-999, -999)
# 쓰레기통(무인 판매함) 판매 배율 — 24시간 아무 때나 파는 대신 제값의 80%
const TRASH_SELL_MULT := 0.8


func move_objective_short() -> String:
	match move_quest:
		"show":
			return "이주 희망 편지를 이장에게 보여주자 (E)"
		"build":
			if first_empty_plot().x >= 0:
				return "빈 집터가 생겼다 — 이주 편지(가방)를 읽고 수락하자"
			return "빈 집터를 마련하자 (집터 레시피는 잡화점)"
		"wait":
			return "집이 완성됐다 — 내일 무진이 이사 온다"
		"greet":
			return "무진이 인사하러 오고 있다 — 야외에서 기다리자"
	return ""


# ---- 이주 NPC의 첫 인사 (공통 시스템) ----
#
# 건물이 완공되거나 이사가 확정된 「그날」에는 아직 영업도 일과도 없다.
# **다음 날** 아침, 그 NPC가 직접 플레이어를 찾아와 첫 인사를 나눈 뒤부터
# 정상적으로 장사(생활)를 시작한다. 앞으로 이주해 오는 모든 NPC 공통.
# (낚시꾼은 자기 퀘스트로 이미 인사를 나누는 특수 경로 — 여기 안 탄다)
var arrivals: Array = []      # [{"id": npc_id, "day": 확정된 날}] — 방문 대기열
var npc_greeted: Array = []   # 첫 인사를 마친 NPC id — 이때부터 영업/일과

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
	"east_north": {"rect": Rect2i(100, 1, 68, 20), "name": "옛 마을 북동쪽 터"},
	"east_south": {"rect": Rect2i(100, 21, 68, 23), "name": "옛 마을 남동쪽 터"},
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
		return "낡은 표지판에 대해 이장에게 물어보자 (E)"
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
			return "오래된 책을 이장에게 보여주자 (E)"
		"ask_post":
			return "우체부 아저씨를 찾아가 편지를 부탁하자"
		"wait":
			return "사서의 답장을 기다리자 (며칠 걸린다)"
		"visit":
			return "마을에 찾아온 사서를 만나보자"
		"told":
			return "사서의 이야기를 이장에게 전하자 (E)"
		"build":
			if village_built.has("library"):
				return "도서관이 완성됐다 — 사서에게 말을 걸자"
			return "도서관을 짓자 — 이장 「마을 발전 이야기」 (목재 90·석재 50)"
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
			return "대장장이 무쇠의 이야기를 들어보자 (E)"
		"lore":
			return "도서관의 서하에게 옛 대장간 이야기를 물어보자"
		"gather":
			if int(items.get("ore", 0)) >= STORY7_ORE \
					and int(items.get("gem", 0)) >= STORY7_GEM:
				return "무쇠에게 재료를 가져다주자 (E)"
			return "재료 모으기 — 광석 %d·보석 %d (보유 %d·%d)" % [
				STORY7_ORE, STORY7_GEM,
				int(items.get("ore", 0)), int(items.get("gem", 0))]
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
			return "마을에 온 낯선 목동을 만나보자"
		"ask":
			return "목장 이야기를 이장과 상의하자 (E)"
		"build":
			if village_built.has("ranch"):
				return "목장 상회가 완성됐다 — 보라에게 말을 걸자"
			return "목장 상회를 짓자 — 이장 「마을 발전 이야기」 (목재 80·석재 40)"
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
			return "이장의 이야기를 들어보자 (E)"
		"invite":
			return "주민 초대하기 — %d/%d명 (이사 편지·빈 집터)" % [
				maxi(residents_now - 1, 0), HALL_RESIDENTS]
		"build":
			if village_built.has("hall"):
				return "마을회관이 완성됐다 — 접수대의 이장에게 (E)"
			return "마을회관을 짓자 — 이장 「마을 발전 이야기」 (목재 120·석재 80)"
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
		return "주민이 %d명이 되면 마을 창고가 열린다. (지금 %d명)" \
			% [HALL_STORE_RES, residents_now]
	if not hall_feature_open("project"):
		return "주민이 %d명이 되면 공동 프로젝트가 열린다. (지금 %d명)" \
			% [HALL_PROJECT_RES, residents_now]
	if not hall_feature_open("meet"):
		return "주민이 %d명이 되면 마을 회의가 열린다. (지금 %d명)" \
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


# ---- 우측 상단 퀘스트 추적창 ----
#
# 「지금 따라가는 퀘스트」 하나를 제목/현재 목표/한두 줄 설명으로 돌려준다.
# hud가 매 프레임 이걸 읽어 그리므로, 단계가 바뀌면 즉시 갱신된다.
func _quest_brief(s: String) -> String:
	var t := s.split("\n")[0]
	if t.length() > 36:
		t = t.substr(0, 35) + "…"
	return t


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
			"obj": o, "desc": _quest_brief(str(cur.get("story", ""))),
			"cat": "main", "ep": "메인 스토리 1", "npc": "postman",
			"reward": "새 도구와 나만의 집"})
	o = story2_objective_short()
	if o != "":
		out.append({"id": "story2", "title": "마을을 깨우다", "obj": o,
			"desc": "이장의 부탁 — 마을에 다시 활기를 불어넣자.",
			"cat": "main", "ep": "메인 스토리 2", "npc": "chief",
			"reward": "상점·바다·밭 — 마을의 기틀"})
	o = fisher_objective_short()
	if o != "":
		out.append({"id": "fisher", "title": "낚시꾼과 바닷길", "obj": o,
			"desc": "낯선 낚시꾼이 황금잉어 소문을 듣고 왔다.",
			"cat": "main", "ep": "메인 스토리 2", "npc": "fisher",
			"reward": "바다·해변 해금 + 간이낚싯대"})
	o = move_objective_short()
	if o != "":
		out.append({"id": "move", "title": "새로운 주민의 이사", "obj": o,
			"desc": "무진이 마을에 살고 싶다는 편지를 보내왔다.",
			"cat": "main", "ep": "메인 스토리 3", "npc": "explorer",
			"reward": "이주 편지·집터 시스템 해금"})
	o = forest_objective_short()
	if o != "":
		out.append({"id": "forest", "title": "숲속에서 발견한 집", "obj": o,
			"desc": "무진이 숲 깊은 곳에서 수상한 집을 봤다고 한다.",
			"cat": "main", "ep": "메인 스토리 5", "npc": "explorer",
			"reward": "숲속 모녀와의 만남"})
	o = story4_objective_short()
	if o != "":
		out.append({"id": "story4", "title": "오래된 마을의 경계", "obj": o,
			"desc": "동쪽 다리 너머에 낡은 표지판이 서 있었다.",
			"cat": "main", "ep": "메인 스토리 4", "npc": "chief",
			"reward": "마을 확장 해금"})
	o = story6_objective_short()
	if o != "":
		var s6map := {"show_chief": "chief", "ask_post": "postman",
			"wait": "postman", "visit": "librarian", "told": "chief",
			"build": "librarian"}
		var s6npc: String = str(s6map.get(story6_phase, "chief"))
		out.append({"id": "story6", "title": "오래된 책과 사서", "obj": o,
			"desc": "풀숲에서 파낸 오래된 책 — 마을의 기록일지도 모른다.",
			"cat": "main", "ep": "메인 스토리 6", "npc": s6npc,
			"reward": "도서관 해금 + 사서 정착"})
	o = story7_objective_short()
	if o != "":
		var s7npc := "librarian" if story7_phase == "lore" else "blacksmith"
		out.append({"id": "story7", "title": "식지 않는 화로", "obj": o,
			"desc": "무쇠의 화로가 식어 간다 — 옛 대장간의 비밀을 찾자.",
			"cat": "main", "ep": "메인 스토리 7", "npc": s7npc,
			"reward": "도구 강화 골드 비용 20% 할인"})
	o = story8_objective_short()
	if o != "":
		var s8npc := "chief" if story8_phase == "ask" else "rancher"
		out.append({"id": "story8", "title": "초원에서 온 목동", "obj": o,
			"desc": "동물들과 초원을 찾아 떠도는 목동이 마을에 왔다.",
			"cat": "main", "ep": "메인 스토리 8", "npc": s8npc,
			"reward": "목장 상회 해금 — 동물을 키울 수 있다"})
	o = story9_objective_short()
	if o != "":
		out.append({"id": "story9", "title": "마을의 심장, 마을회관", "obj": o,
			"desc": "이장의 꿈 — 주민을 모아 마을회관을 되살리자.",
			"cat": "main", "ep": "메인 스토리 9", "npc": "chief",
			"reward": "마을회관 — 명부·창고·프로젝트가 차례로 열린다"})
	# 서브: 상인의 노점 심부름
	if merchant_errand == "doing":
		var ready := wood >= STALL_WOOD \
			and int(items.get("forage_shell", 0)) >= STALL_SHELLS
		out.append({"id": "stall", "title": "상인의 부탁 — 해변 노점",
			"obj": "민지에게 재료를 가져다주기" if ready
				else "재료 모으기 — 목재 %d·조개 %d" % [STALL_WOOD, STALL_SHELLS],
			"desc": "민지가 해변에서 장사할 노점을 내고 싶어 한다.",
			"cat": "sub", "npc": "merchant",
			"reward": "해변 노점 개장 + 하트 모양 러그"})
	o = tutorial_objective_short()
	if o != "":
		var flag := tutorial_current_flag()
		if flag in STORY2_FLAGS:
			out.append({"id": "tutorial", "title": "마을을 깨우다", "obj": o,
				"desc": "이장에게 받은 호미와 씨앗으로 밭을 일구자.",
				"cat": "main", "ep": "메인 스토리 2", "npc": "chief",
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


func tracked_quest() -> Dictionary:
	var cat := quest_catalog()
	if cat.is_empty():
		return {}
	if tracked_pick != "":
		for q: Dictionary in cat:
			if str(q.id) == tracked_pick:
				return q
	return cat[0]


# 지금 말을 걸어야 하는 퀘스트 NPC 머리 위 표시.
#   "!" 아직 대화하지 않은 대상 / "?" 납품(보고)할 수 있는 대상
func quest_npc_marks() -> Dictionary:
	var marks := {}
	if story2_phase == "farm_talk":
		marks["chief"] = "!"
	if fisher_quest == "meet":
		marks["fisher"] = "!"
	if move_quest == "show":
		marks["chief"] = "!"
	match forest_quest:
		"arrive", "found":
			marks["explorer"] = "!"
		"ask":
			marks["chief"] = "!"
		"visit":
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
	if merchant_errand == "doing":
		# 노점 재료를 다 모았으면 민지에게 가져다주자
		if wood >= STALL_WOOD and int(items.get("forage_shell", 0)) >= STALL_SHELLS:
			marks["merchant"] = "?"
	if mom_quest_open() and mom_quest != "":
		marks["forest_mom"] = "?"
	# 엔딩 준비 완료 — 연화가 항아리를 꺼낼 차례다
	if ending_ready():
		marks["forest_mom"] = "!"
	# 떠나려는 주민 — 하고 싶은 말이 있다
	if settler_leaving != "":
		marks[settler_leaving] = "!"
	return marks


# ---- 메인 스토리 5: 숲속에서 발견한 집 ----
#
# 첫 수확(스토리 2 완료) 뒤, 모험을 좋아하는 무진이 마을로 이사 온다.
# 숲을 쏘다니던 무진이 깊은 숲의 수상한 집을 발견하고, 이장도 모르는
# 그 집에는 아픈 딸을 돌보는 모녀가 조용히 살고 있었다.
# 이 이야기를 끝내면 호감도 콘텐츠(하트·선물)가 해금된다.
#   "": 아직 / arrive: 무진 등장 — 말 걸기 / settle: 정착 (다음 날 아침까지) /
#   found: 숲속 집 발견담 — 무진에게 말 걸기 / ask: 이장에게 물어보기 /
#   visit: 숲 깊은 곳의 집 방문 (문 앞 E) / done: 완료
var forest_quest := ""
var forest_day := 0          # 무진이 정착한 날 — 다음 날 아침 발견담이 뜬다
var affinity_open := false   # 호감도 콘텐츠(하트·선물) 해금 여부


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
			return "마을 광장에 낯선 사람이 왔다 — 말을 걸어 보자 (E)"
		"found":
			return "무진이 할 말이 있는 듯하다 — 말을 걸어 보자 (E)"
		"ask":
			return "숲속의 집에 대해 이장에게 물어보자 (E)"
		"visit":
			return "숲 깊은 곳의 집을 찾아가 보자 (문 앞에서 E)"
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
			return "마을 광장의 낚시꾼에게 말을 걸어 보자 (E)"
		"follow":
			return "낚시꾼과 함께 바위 능선으로 가자"
		"open":
			return "곡괭이로 길목의 커다란 바위를 캐서 바닷길을 열자"
	return ""


# 집: 스토리 1 완료 후 마을 서쪽 집터에 직접 짓는다 (0=집터 / 1=집 / 2=확장)
var house_lv := 0
var has_bed := false  # 침대는 직접 제작해야 잠을 잘 수 있다

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
	# kind "furniture": 완성되면 집에 세간으로 들어온다 (꾸미기 F로 옮긴다)
	"flower_pot": {"name": "화분", "cost": {"weed": 5},
		"kind": "furniture", "furn": "plant", "locked": true, "shop": "잡화점",
		"desc": "집을 꾸미는 화분 — 완성되면 방에 놓인다 (레시피는 잡화점에서)"},
	# 쓰레기통 — 24시간 무인 판매함. 만들어서 원하는 곳(집 안/바깥)에 설치한다.
	"trash_bin": {"name": "쓰레기통", "cost": {"wood": 5, "forage_ring": 2},
		"kind": "item", "give": "trash_bin", "locked": true, "shop": "잡화점",
		"desc": "넣은 물건을 제값의 80%에 파는 무인 판매함 — 가방에서 꺼내 설치한다"},
	# 집터 — 새 주민의 집을 지을 자리 (메인 스토리 3에서 해금, 일부러 무겁다)
	"housing_kit": {"name": "집터", "cost": {"wood": 60, "stone": 40, "nail": 4},
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
const EXPLORE_CHUNK := 8
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
		"task": "숲 안으로 들어가 보자",
		"story": "할아버지가 집으로 가는 길이 힘들 거라고 했던 이유를 이제야 알 것 같다. 그래도 집으로 가기 위해서는 이 숲을 지나가야 한다."},
	{"name": "우체부 아저씨와의 만남",
		"task": "다가오는 우체부 아저씨에게 말을 걸어 보자 (E)",
		"story": "숲 속에서 우체부 아저씨가 다가와 말을 걸었다. 그도 마을로 가는 길이라고 한다."},
	{"name": "나무도끼를 장착해보기",
		"task": "받은 나무도끼를 가방(I)의 슬롯에 장착해 보자",
		"story": "숲이 너무 험하고 나무가 많아 쉽게 들어갈 수 없던 중 우체부 아저씨를 만났다. 아저씨와 함께 마을까지 가기로 했고, 안전하게 지나가려면 나무를 베어 길을 만들어야 한다. 아저씨에게 받은 나무도끼로 숲을 지나갈 준비를 해보자."},
	{"name": "나무를 베어보자",
		"task": "도끼를 선택(숫자키)하고 나무를 클릭한 뒤 E 키로 베어보자",
		"story": "도끼를 장착했다. 길을 막는 나무를 베어 마을로 가는 길을 만들자."},
	{"name": "숲길을 나아가자",
		"task": "나무를 베며 숲길을 따라 나아가자",
		"story": "첫 나무를 베어 길이 열리기 시작했다. 아저씨와 함께 숲길을 따라 앞으로 나아가자."},
	{"name": "지도를 확인해보자",
		"task": "M 키를 눌러 지도를 열어 보자",
		"story": "숲길이 여러 갈래로 갈라졌다. 어느 길로 가야 할까? 아저씨가 알려준 대로 지도에서 우리 위치와 가 본 곳을 확인해 보자."},
	{"name": "마을로 가는 길을 열어보자",
		"task": "우체부 아저씨에게 받은 곡괭이를 장착하고, 길을 막은 커다란 바위를 캐보자",
		"story": "마을로 향하던 중 커다란 바위가 길을 완전히 가로막고 있었다. 아저씨가 곡괭이로 캐는 모습을 보여주며 곡괭이를 건네주었다. 배운 대로 바위를 캐서 길을 열자."},
	{"name": "마을로 이동",
		"task": "우체부 아저씨와 함께 길을 따라 마을로 가자",
		"story": "바위를 치워 마침내 길이 열렸다. 아저씨와 함께 숲을 빠져나가 마을로 향하자."},
	{"name": "이장에게 편지 전달",
		"task": "우체부 아저씨를 따라 이장님께 가자",
		"story": "드디어 마을에 도착했다. 우체부 아저씨가 이장님께 직접 편지를 전하러 간다. 함께 따라가 보자."},
	{"name": "새 보금자리",
		"task": "이장님이 내어 준 집에 들어가 보자 (문 앞 E)",
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
			return "우거진 숲 안으로 들어가 보자"
		"approach":
			return "우체부 아저씨에게 말 걸기 (E)"
		"equip":
			return "나무도끼를 가방(I) 슬롯에 장착해 보자"
		"chop":
			return "흙길을 막고 선 나무를 베어보자"
		"path":
			if story_gates_left > 0:
				return "길을 막은 나무를 베며 나아가자 (남은 길목 %d곳)" % story_gates_left
			return "열린 숲길을 따라 갈림길까지 가자"
		"map":
			return "M 키를 눌러 지도를 열어 보자"
		"rock":
			match story_rock_state:
				0:
					return "열린 길을 따라 마을로 가보자"
				1:
					return "곡괭이를 장착하고 바위를 클릭한 뒤 E로 캐보자"
				_:
					return "우체부 아저씨에게 말을 걸어보자"
		"travel":
			return "우체부 아저씨와 함께 길을 따라 마을로 가자"
		"deliver":
			return "우체부 아저씨를 따라 이장님께 가자"
		"home_open":
			return "이장님이 내어 준 집에 들어가 보자"
		"greet":
			return "집을 둘러보고 밖으로 나가 보자 (아랫문)"
	return ""


func player_tex(part: String) -> String:
	# 플레이어 텍스처 이름 — 고른 외형으로 구워 둔 pc_* 를 본다
	# (main.apply_appearance가 머리 스타일 + 옷 색으로 만들어 둔다)
	return "pc_" + part


# 휘두르기 도트 이름의 앞부분 (key = "down"/"up"/"side").
# 모든 머리 스타일이 같은 골격이라 주먹 자리(player.gd SWING_HAND_DOT)도 공용이다.
func swing_tex_base(key: String) -> String:
	return "pc_%s_swing" % key


func player_side_tex(is_moving: bool, _suffix: String, t: float) -> String:
	# 옆모습. 걷는 중엔 5프레임 걷기(8fps), 멈추면 숨쉬기(스케일) 모션.
	# (4박자 로직의 "서기" 박자가 걷기에 끼어들지 않게 moving을 직접 본다)
	if not is_moving:
		return "pc_side_idle"
	return "pc_side_walk_%d" % (int(t * 8.0) % 5)


func player_down_tex(is_moving: bool, _suffix: String, t: float) -> String:
	# 앞모습. 걷는 중엔 5프레임 걷기(8fps), 멈추면 숨쉬기(스케일) 모션.
	if not is_moving:
		return "pc_down_idle"
	return "pc_down_walk_%d" % (int(t * 8.0) % 5)


func player_up_tex(is_moving: bool, _suffix: String, t: float) -> String:
	# 뒷모습. 걷는 중엔 5프레임 걷기(8fps), 멈추면 숨쉬기(스케일) 모션.
	if not is_moving:
		return "pc_up_idle"
	return "pc_up_walk_%d" % (int(t * 8.0) % 5)


# 벌목 누적 횟수 (스토리 중 15그루째에 우체부가 능력치 창을 알려준다)
var trees_chopped := 0
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
const BARN_COST_MONEY := 5000
const BARN_COST_WOOD := 20
var barn_built := false


func max_animals() -> int:
	return BARN_MAX_ANIMALS if barn_built else MAX_ANIMALS

# ---- 기타 판매 아이템 (동물 생산물, 물고기) ----
const ITEMS := {
	"egg": {"name": "달걀", "sell": 60},
	"milk": {"name": "우유", "sell": 120},
	"fish_crucian": {"name": "붕어", "sell": 40},
	"fish_minnow": {"name": "피라미", "sell": 30},
	"fish_loach": {"name": "미꾸라지", "sell": 55},
	"fish_bitterling": {"name": "납자루", "sell": 45},
	"fish_carp": {"name": "잉어", "sell": 60},
	"fish_sweetfish": {"name": "은어", "sell": 110},
	"fish_trout": {"name": "산천어", "sell": 140},
	"fish_mandarin": {"name": "쏘가리", "sell": 160},
	"fish_catfish": {"name": "메기", "sell": 90},
	"fish_eel": {"name": "뱀장어", "sell": 180},
	"fish_snakehead": {"name": "가물치", "sell": 200},
	"fish_crab": {"name": "참게", "sell": 130},
	"fish_salmon": {"name": "연어", "sell": 220},
	"fish_rainbow": {"name": "무지개송어", "sell": 190},
	"fish_smelt": {"name": "빙어", "sell": 70},
	"fish_icecarp": {"name": "얼음잉어", "sell": 150},
	"fish_lenok": {"name": "열목어", "sell": 240},
	"fish_mistfish": {"name": "안개무늬", "sell": 170},
	"fish_stormjack": {"name": "폭풍전갱이", "sell": 260},
	"fish_moonfish": {"name": "달빛어", "sell": 320},
	"fish_starcarp": {"name": "별잉어", "sell": 380},
	"fish_ghost": {"name": "유령물고기", "sell": 420},
	"fish_golden": {"name": "황금잉어", "sell": 300},
	"fish_king": {"name": "무지개 왕송어", "sell": 500},
	"fish_dragon": {"name": "이무기", "sell": 800},
	"ore": {"name": "광석", "sell": 50},
	"gem": {"name": "보석", "sell": 220},
	"star_shard": {"name": "별빛 조각", "sell": 300},
	"bouquet": {"name": "꽃다발", "sell": 0},
	# 부품 — 제작대에서 가구를 만들 때 쓴다. 못·천·밧줄은 잡화점, 경첩은 대장간
	"nail": {"name": "못", "sell": 15},
	"cloth": {"name": "천", "sell": 45},
	"rope": {"name": "밧줄", "sell": 25},
	"hinge": {"name": "경첩", "sell": 110},
	"wedding_ring": {"name": "청혼 반지", "sell": 0},
	"dish_baked_potato": {"name": "구운 감자", "sell": 70},
	"dish_soup": {"name": "야채 수프", "sell": 110},
	"dish_jam": {"name": "딸기잼", "sell": 150},
	"dish_cornbread": {"name": "옥수수빵", "sell": 130},
	# 초반 음식 사슬 — 산딸기잼 → 밀가루 → 빵 → 산딸기잼 토스트
	"dish_berry_jam": {"name": "산딸기잼", "sell": 60},
	"flour": {"name": "밀가루", "sell": 25},
	"dish_bread": {"name": "빵", "sell": 70},
	"dish_berry_toast": {"name": "산딸기잼 토스트", "sell": 150},
	"dish_grilled_fish": {"name": "생선구이", "sell": 90},
	"dish_stew": {"name": "매운탕", "sell": 200},
	"dish_pie": {"name": "호박파이", "sell": 280},
	"dish_salad": {"name": "치즈 샐러드", "sell": 170},
	"dish_punch": {"name": "수박화채", "sell": 240},
	"dish_eggplant": {"name": "가지볶음", "sell": 120},
	"dish_pickle": {"name": "무김치", "sell": 140},
	"dish_ratatouille": {"name": "야채볶음", "sell": 260},
	"dish_pumpkin_soup": {"name": "호박죽", "sell": 230},
	"dish_corn_salad": {"name": "옥수수 샐러드", "sell": 210},
	"dish_sweet_potato": {"name": "군고구마", "sell": 160},
	"dish_bean_rice": {"name": "콩밥", "sell": 200},
	"dish_rice_cake": {"name": "인절미", "sell": 290},
	"dish_melon_ice": {"name": "참외 빙수", "sell": 270},
	"dish_onion_soup": {"name": "양파 수프", "sell": 190},
	"dish_garlic_bread": {"name": "마늘빵", "sell": 150},
	"dish_spinach_saute": {"name": "시금치 볶음", "sell": 155},
	"dish_sashimi": {"name": "회", "sell": 300},
	"dish_eel_rice": {"name": "장어덮밥", "sell": 420},
	"dish_crab_soup": {"name": "게탕", "sell": 340},
	"dish_salmon_steak": {"name": "연어 스테이크", "sell": 460},
	"dish_smelt_fry": {"name": "빙어 튀김", "sell": 240},
	"dish_fish_soup": {"name": "생선 맑은국", "sell": 180},
	"dish_golden_roast": {"name": "황금잉어 구이", "sell": 700},
	"dish_moon_tea": {"name": "달빛차", "sell": 640},
	"dish_coral_tea": {"name": "산호빛 차", "sell": 560},
	"dish_feast": {"name": "한상차림", "sell": 1100},
	# 컬렉션 보상으로 열리는 요리 레시피
	"butter": {"name": "버터", "sell": 180},
	"dish_fried_egg": {"name": "계란후라이", "sell": 90},
	"dish_egg_roll": {"name": "계란말이", "sell": 200},
	"dish_omurice": {"name": "오므라이스", "sell": 380},
	"dish_butter_corn": {"name": "버터옥수수", "sell": 260},
	# 채집물/곤충
	"forage_berry": {"name": "산딸기", "sell": 40},
	# 엔딩 유품·물약 — 팔 수 없다
	"water_life": {"name": "생명의 물", "sell": 0},
	"potion_dream": {"name": "기억의 물약", "sell": 0},
	"settle_letter": {"name": "이사 신청 편지", "sell": 0},
	"farewell_letter": {"name": "짧은 작별 편지", "sell": 0},
	"relic_hat": {"name": "할머니의 모자", "sell": 0},
	"relic_watch": {"name": "할머니의 시계", "sell": 0},
	"relic_bracelet": {"name": "할머니의 팔찌", "sell": 0},
	"relic_ring": {"name": "할머니의 반지", "sell": 0},
	"relic_necklace": {"name": "할머니의 목걸이", "sell": 0},
	"weed": {"name": "잡초", "sell": 5},
	"broom": {"name": "빗자루", "sell": 0},
	# 해변 채집물 — 바다를 열면 아침마다 모래밭에 밀려온다
	"forage_shell": {"name": "조개", "sell": 35},
	"forage_trash": {"name": "젖은 비닐봉지", "sell": 12},
	"forage_glass": {"name": "유리 조각", "sell": 34},
	"forage_ring": {"name": "금속 고리", "sell": 28},
	"forage_relic": {"name": "고대 조각", "sell": 480},
	"bait": {"name": "미끼", "sell": 2},
	"housing_kit": {"name": "집터", "sell": 0},
	"move_letter": {"name": "이주 희망 편지", "sell": 0},
	# 메인 스토리 6의 핵심 물건 — 팔 수 없고, 완결 후 도서관에 보관된다
	"old_book": {"name": "오래된 책", "sell": 0},
	"trash_bin": {"name": "쓰레기통", "sell": 0},
	# 초반 무기 (도구라 개수는 없지만, 도감·컬렉션 표시용 이름이 필요하다)
	"spear": {"name": "돌 창", "sell": 0},
	"sword": {"name": "돌 검", "sell": 0},
	"arrow": {"name": "화살", "sell": 15},
	"forage_coral": {"name": "산호 조각", "sell": 260},
	"forage_herb": {"name": "약초", "sell": 60},
	"bug_butterfly": {"name": "나비", "sell": 30},
	"bug_dragonfly": {"name": "잠자리", "sell": 50},
	"bug_firefly": {"name": "반딧불이", "sell": 90},
	# 전설 재료 (판매 불가, 최후의 연금술 재료)
	"gold_crop": {"name": "달빛 작물", "sell": 0, "legend": true},
	"world_branch": {"name": "세계수 가지", "sell": 0, "legend": true},
	"star_ore": {"name": "별빛 광석", "sell": 0, "legend": true},
	"ghost_essence": {"name": "유령의 정수", "sell": 0, "legend": true},
	"golden_egg": {"name": "황금 달걀", "sell": 0, "legend": true},
	"memory_piece": {"name": "할아버지의 기억 조각", "sell": 0, "legend": true},
	# 연금술 결과물 (조합대에서 만든다)
	"potion_energy": {"name": "원기 물약", "sell": 180},
	"potion_luck": {"name": "행운의 물", "sell": 220},
	"potion_swift": {"name": "바람 물약", "sell": 200},
	"potion_ember": {"name": "불꽃 물약", "sell": 240},
	"potion_grow": {"name": "성장 물약", "sell": 260},
	"potion_guard": {"name": "수호 물약", "sell": 260},
	"potion_moon": {"name": "달빛의 물", "sell": 400},
	"sludge": {"name": "탁한 앙금", "sell": 5},
}
const FISH_IDS := ["fish_crucian", "fish_minnow", "fish_loach", "fish_bitterling",
	"fish_carp", "fish_sweetfish", "fish_trout", "fish_mandarin", "fish_catfish",
	"fish_eel", "fish_snakehead", "fish_crab", "fish_salmon", "fish_rainbow",
	"fish_smelt", "fish_icecarp", "fish_lenok", "fish_mistfish", "fish_stormjack",
	"fish_moonfish", "fish_starcarp", "fish_ghost", "fish_golden", "fish_king", "fish_dragon"]
const ITEM_IDS := ["egg", "milk", "fish_crucian", "fish_minnow", "fish_loach",
	"fish_bitterling", "fish_carp", "fish_sweetfish", "fish_trout", "fish_mandarin",
	"fish_catfish", "fish_eel", "fish_snakehead", "fish_crab", "fish_salmon",
	"fish_rainbow", "fish_smelt", "fish_icecarp", "fish_lenok", "fish_mistfish",
	"fish_stormjack", "fish_moonfish", "fish_starcarp", "fish_ghost", "fish_golden",
	"fish_king", "fish_dragon",
	"ore", "gem", "star_shard", "bouquet", "wedding_ring",
	"nail", "cloth", "rope", "hinge", "dish_baked_potato", "dish_soup", "dish_jam", "dish_cornbread",
	"dish_berry_jam", "flour", "dish_bread", "dish_berry_toast",
	"dish_grilled_fish", "dish_stew", "dish_pie", "dish_salad", "dish_punch", "dish_eggplant",
	"dish_pickle", "dish_ratatouille", "dish_pumpkin_soup", "dish_corn_salad",
	"dish_sweet_potato", "dish_bean_rice", "dish_rice_cake", "dish_melon_ice",
	"dish_onion_soup", "dish_garlic_bread", "dish_spinach_saute", "dish_sashimi",
	"dish_eel_rice", "dish_crab_soup", "dish_salmon_steak", "dish_smelt_fry",
	"dish_fish_soup", "dish_golden_roast", "dish_moon_tea", "dish_feast",
	"butter", "dish_fried_egg", "dish_egg_roll", "dish_omurice", "dish_butter_corn",
	"water_life", "potion_dream", "relic_hat", "relic_watch",
	"relic_bracelet", "relic_ring", "relic_necklace",
	"settle_letter", "farewell_letter",
	"forage_berry", "forage_herb", "weed", "broom", "forage_shell", "forage_coral",
	"forage_trash", "forage_glass", "forage_ring", "forage_relic", "bait",
	"housing_kit", "move_letter", "old_book", "trash_bin", "arrow", "dish_coral_tea",
	"bug_butterfly", "bug_dragonfly", "bug_firefly",
	"gold_crop", "world_branch", "star_ore", "ghost_essence", "golden_egg", "memory_piece",
	"potion_energy", "potion_luck", "potion_swift", "potion_ember", "potion_grow",
	"potion_guard", "potion_moon", "sludge"]

# 채집물/곤충 도감 (팔아도 기록은 남는다)
# 초록 풀숲(잡초·약초 자리)을 뽑았을 때 실제로 나오는 것 —
# 기본은 잡초, 아주 드물게(1%) 약초가 섞여 나온다
func weed_drop_id() -> String:
	return "forage_herb" if randf() < 0.01 else "weed"


const FORAGE_IDS := ["forage_berry", "forage_herb", "weed",
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
const COLLECTIONS := [
	{"id": "col_food_starter", "name": "초반 음식", "reward": "",
		"perk": "speed", "perk_text": "이동 속도 소폭 증가 (영구)",
		"ids": ["dish_berry_jam", "flour", "dish_bread", "dish_berry_toast"]},
]

# 「초반 음식」 완성 보상 — 걸음이 영구히 조금 빨라진다
const FOOD_COL_SPEED := 1.05


func perk_speed_mult() -> float:
	return FOOD_COL_SPEED if "col_food_starter" in collections_done else 1.0
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
		if col.id in collections_done:
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
	["fish_golden", "낚시", "물가의 전설. 철수도 두 번밖에 못 봤다는 황금잉어."],
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

# 낡은 조합법이 나올 확률 (아직 모르는 것이 남아 있을 때만)
const ALCHEMY_DROP := {"tree": 0.03, "rock": 0.03, "bigrock": 0.12, "mob": 0.06}

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
var horse_tile := Vector2i(14, 12)   # 세워 둔 자리


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
const RELICS := [
	{"id": "relic_hat", "name": "할머니의 모자", "chance": 0.05,
		"hint": "동굴 50층 아래, 광석을 깨다 보면 낡은 모자가 나온다더라..."},
	{"id": "relic_watch", "name": "할머니의 시계", "chance": 0.015,
		"hint": "바다 물고기를 낚다 보면 낚싯줄에 시계가 걸려 온다더라..."},
	{"id": "relic_bracelet", "name": "할머니의 팔찌", "chance": 0.015,
		"hint": "해변의 모래를 뒤지다 보면 팔찌가 반짝인다더라..."},
	{"id": "relic_ring", "name": "할머니의 반지", "chance": 0.04,
		"hint": "금빛으로 여문 작물 속에 반지가 숨어 있다더라..."},
	{"id": "relic_necklace", "name": "할머니의 목걸이", "chance": 0.25,
		"hint": "동굴의 가장 크고 오래된 나무 괴물이 목걸이를 지킨다더라..."},
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


# 분야가 만렙에 닿으면 생명의 물 한 병 — 분야당 한 번뿐이다
func check_skill_water(id: String) -> void:
	if id not in ENDING_SKILLS or water_life_found.has(id):
		return
	if skill_lv(id) < SKILL_MAX_LV:
		return
	water_life_found[id] = true
	items["water_life"] += 1
	discover("water_life")
	water_pending += 1


# 꿈속 엔딩으로 갈 준비가 됐는가 — 연화가 항아리를 꺼내 주는 조건
func ending_ready() -> bool:
	return water_life_found.size() >= ENDING_SKILLS.size() \
		and relics_owned() >= RELICS.size() \
		and note_progress().ratio >= 1.0 and not dream_seen \
		and int(items["potion_dream"]) == 0 and not dream_ready


func playtime_text() -> String:
	var mins := int(playtime_sec / 60.0)
	return "%d시간 %d분" % [mins / 60, mins % 60]


# ---- 주민 분류 · 이사 시스템 (입주/이탈) ----
#
# 주민은 세 갈래다:
#   core    필수 주민 — 메인 스토리로 확정 입주 (이장·민지·무쇠·보라·
#           철수·서하·무진·연화·솔이). 절대 마을을 떠나지 않는다.
#   normal  일반 주민 — 빈 집터가 있으면 랜덤으로 「이사 신청 편지」를
#           보내 오는 생활형 캐릭터 (농부 순돌·미식가 다미·낚시광 강태)
#   special 특수 주민 — 조건을 채워야 해금 (연금술사 묘연 — 연구 노트 50%)
# 편지를 수락해야 입주하고, 호감도가 낮거나(LEAVE_AFF 미만) 오래
# 말을 걸지 않으면(NEGLECT_DAYS) 떠날 마음이 생긴다 — 대개는 직접
# 「이사 가고 싶다」고 말하지만(붙잡을 수 있다), 드물게는 말없이
# 편지 한 통만 남기고 떠난다. 호감도 SAFE_AFF 이상이면 절대 안 떠난다.
const NPC_KIND := {
	"chief": "core", "merchant": "core", "blacksmith": "core",
	"rancher": "core", "fisher": "core", "librarian": "core",
	"explorer": "core", "forest_mom": "core", "forest_girl": "core",
	"farmer": "normal", "foodie": "normal", "angler": "normal",
	"miner": "normal", "florist": "normal", "carpenter": "normal",
	"herbalist": "normal", "painter": "normal", "musician": "normal",
	"weaver": "normal",
	"alchemist": "special",
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


# 다음 이사 신청 후보 — 특수 주민(조건 충족)이 먼저, 그다음 일반 랜덤.
# 떠난 주민도 다시 올 수 있다 (마을은 계속 살아 움직인다)
func settler_candidates() -> Array:
	var out: Array = []
	if note_progress().ratio >= ALCHEMIST_NOTE and "alchemist" not in settlers \
			and settler_arrive != "alchemist":
		out.append("alchemist")
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
		try_relic(3)   # 금빛 작물 속의 「할머니의 반지」 (힌트가 열린 뒤부터)
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


# 보유 전량 판매 가치 (은 1.25배 / 금 1.5배)
func produce_sell_value(id: String) -> int:
	# 연구소 개량 단계만큼 값이 오른다
	var price: int = int(CROPS[id].sell_price * breed_price_mult())
	var silver := int(produce_silver.get(id, 0))
	var gold := int(produce_gold.get(id, 0))
	var normal: int = int(produce[id]) - silver - gold
	return int(normal * price + silver * price * 1.25 + gold * price * 1.5)


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
	"merchant": {"name": "민지", "birthday": [SPRING, 12], "gender": "f", "romance": true,
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
	"fisher": {"name": "철수", "birthday": [SUMMER, 3], "gender": "m", "romance": true,
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
	# ---- 메인 스토리 5에서 합류하는 사람들 ----
	"explorer": {"name": "무진", "birthday": [FALL, 7], "gender": "m", "romance": false,
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
		"민지네 가게 신상 레시피 봤어? 못 참지.",
		"맛있는 걸 먹을 때만큼은 세상이 다 예뻐 보여.",
	],
	"loves": ["dish_feast", "dish_berry_toast", "dish_golden_roast"],
	"likes": ["dish_bread", "dish_jam", "dish_punch"],
	"hates": ["sludge", "forage_trash"],
	},
	"angler": {"name": "강태", "birthday": [FALL, 9], "gender": "m", "romance": false,
	"lines": [
		"물 좋다는 소문 듣고 낚싯대 하나 들고 왔지.",
		"어제 이만~한 놈을 놓쳤다니까? 진짜라니까?",
		"낚시는 기다림의 미학이야. 인생처럼.",
		"철수 씨랑은 라이벌이야. 본인은 모르지만.",
		"입질 없는 날엔 그냥 물멍만 해도 좋아.",
	],
	"loves": ["fish_golden", "dish_sashimi", "fish_king"],
	"likes": ["fish_crucian", "bait", "dish_grilled_fish"],
	"hates": ["sludge", "forage_trash"],
	},
	"miner": {"name": "바우", "birthday": [SPRING, 8], "gender": "m", "romance": false,
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
	"carpenter": {"name": "덕구", "birthday": [SUMMER, 19], "gender": "m", "romance": false,
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
	"painter": {"name": "청람", "birthday": [FALL, 21], "gender": "m", "romance": false,
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

}
var affinity := {"librarian": 0,
	"merchant": 0, "fisher": 0, "blacksmith": 0, "rancher": 0, "chief": 0,
	"explorer": 0, "forest_mom": 0, "forest_girl": 0,
	"farmer": 0, "foodie": 0, "angler": 0, "miner": 0, "florist": 0,
	"carpenter": 0, "herbalist": 0, "painter": 0, "musician": 0,
	"weaver": 0, "alchemist": 0}
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
	return str(pool[randi() % pool.size()])
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
const TUTORIAL_ORDER := [
	["till", "호미를 슬롯에 장착해 풀밭을 갈자"],
	["plant", "밭에 씨앗을 심자"],
	["water", "물뿌리개로 물을 주자"],
	["harvest", "다 자란 작물에 E — 도구 없이 바로 딸 수 있다"],
	["board", "의뢰 게시판(E)에서 오늘의 의뢰를 살펴보자"],
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
	"harvest": ["axe", "pickaxe", "fence", "rod"],
}
# 수확은 도구 없이 되므로 「바구니(hand)」 도구는 없앴다
# 돌 창·돌 검은 제작대에서 만들어 해금하는 무기다 (레시피: 이장/추후 서브퀘)
const ALL_TOOLS := ["hoe", "water", "seed", "axe", "pickaxe", "fence", "sprinkler",
	"rod", "spear", "sword"]

# 튜토리얼 목표 달성 보상 (도구 해금과 별개)
const TUTORIAL_REWARDS := {
	"moved": {"money": 50},
	"map": {"money": 50},
	"quest": {"money": 50},
	"note": {"money": 50},   # 씨앗을 그냥 주지 않는다 — 상점에서 사는 게 시작이다
	"till": {"money": 30},
	"plant": {"money": 50},
	"water": {"money": 100},
	"harvest": {"money": 100},
	"board": {"money": 100},
	"chop": {"wood": 5},
	"slept": {"money": 150},
	"mine": {"stone": 5},
	"fish": {"money": 200},
	"shop": {"money": 300},
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


func fresh_tutorial() -> Dictionary:
	var t := {"active": true}
	for pair in TUTORIAL_ORDER:
		t[pair[0]] = false
	return t


# 우측 트래커용 짧은 목표 문구
# %s 는 실제로 설정된 키로 바뀐다 (키 재설정을 따라간다)
const TUTORIAL_SHORT := {
	"moved": "움직여보기 (WASD)", "map": "지도 열기 (%s)", "quest": "퀘스트 창 (%s)",
	"note": "연구 노트 (%s)", "till": "밭 갈기 (1)", "plant": "씨앗 심기 (3)",
	"water": "물 주기 (2)", "harvest": "다 자란 작물에 E",
	"slept": "침대에서 자기", "board": "의뢰 게시판 보기",
	"chop": "나무 베기 (5)", "mine": "돌 캐기 (6)",
	"fish": "낚시터에서 낚시 (9)", "shop": "잡화점 가보기",
}


const TUTORIAL_SHORT_KEY := {"map": "open_map", "quest": "open_quest", "note": "open_note"}


func tutorial_objective_short() -> String:
	var flag := tutorial_current_flag()
	if flag == "":
		return ""
	var txt := String(TUTORIAL_SHORT.get(flag, ""))
	if TUTORIAL_SHORT_KEY.has(flag):
		txt = txt % key_label(TUTORIAL_SHORT_KEY[flag])
	return txt


func tutorial_objective() -> String:
	if not tutorial.get("active", false):
		return ""
	for pair in TUTORIAL_ORDER:
		if not tutorial.get(pair[0], false):
			return "다음 목표: " + pair[1]
	return ""


func tutorial_current_flag() -> String:
	if not tutorial.get("active", false):
		return ""
	for pair in TUTORIAL_ORDER:
		# 마을 생활 안내(스토리2 밖 목표)는 스토리 3이 열어 줘야 나온다
		if pair[0] not in STORY2_FLAGS and not guide_active:
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
		"reward": {"money": 500, "seeds": {"tomato": 3}}},
	{"id": "fish", "count": "fish_kinds", "goal": 3,
		"name": "강가의 기록",
		"desc": "물고기 3종류를 낚아 노트에 기록하자",
		"letter": "\"물속에도 답이 있다.\n마을 남쪽 낚시터에서 서로 다른 물고기 셋을\n낚아 보렴. 기다림도 연구의 일부란다.\"",
		"reward": {"money": 800}},
	{"id": "forage", "count": "forage_kinds", "goal": 3,
		"name": "숲의 기록",
		"desc": "채집물·곤충 3종류를 모아 노트에 기록하자",
		"letter": "\"숲은 아무것도 팔지 않지만 모든 것을 준단다.\n열매든 풀이든 벌레든, 서로 다른 셋을 찾아\n노트에 붙여 두렴.\"",
		"reward": {"money": 1000, "stone": 10}},
	{"id": "mine", "count": "mob_kills", "goal": 10,
		"name": "땅속의 기록",
		"desc": "동굴에서 몬스터를 10마리 물리치자",
		"letter": "\"동굴 깊은 곳의 것들은 사납지만,\n그 몸에서 나오는 것 또한 재료다.\n조심하되 물러서지는 말거라.\"",
		"reward": {"money": 1500, "wood": 20}},
	{"id": "cook", "count": "recipe_kinds", "goal": 3,
		"name": "부엌의 기록",
		"desc": "요리를 3종류 만들어 보자",
		"letter": "\"불과 물과 시간을 다루는 일 —\n요리야말로 가장 오래된 연금술이란다.\n세 가지를 만들어 먹어 보렴.\"",
		"reward": {"money": 2000}},
	{"id": "friend", "count": "best_affinity", "goal": 50,
		"name": "사람의 기록",
		"desc": "마을 사람과 친해지자 (호감도 50)",
		"letter": "\"내가 끝내 못 채운 장이 사람이었다.\n마을 사람 하나와 진하게 친해져 보렴.\n선물도 좋고, 매일 인사도 좋다.\"",
		"reward": {"money": 2500}},
	{"id": "note", "count": "note_percent", "goal": 50,
		"name": "절반의 노트",
		"desc": "연구 노트를 절반(50%)까지 채우자",
		"letter": "\"여기까지 왔다면 이제 알 게다.\n노트의 절반을 채우면, 남은 장이 무엇을 원하는지\n스스로 보이기 시작할 거야.\"",
		"reward": {"money": 3000}},
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
	money = DEV_MONEY if DEV_MODE else START_MONEY
	energy = ENERGY_MAX
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
	fisher_quest = ""
	fisher_choice = 0
	sea_open = false
	merchant_errand = ""
	merchant_day = 0
	stall_hours = []
	forest_quest = ""
	forest_day = 0
	affinity_open = false
	move_quest = ""
	move_day = 0
	move_house = Vector2i(-999, -999)
	home_plots = []
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
	residents_now = 1
	hall_stock = {}
	hall_loot_day = 0
	hall_trash_total = 0
	hall_projects = []
	hall_meet_day = 0
	hall_feat_noticed = []
	zones_open = []
	arrivals = []
	npc_greeted = []
	recipe_items = {}
	tracked_pick = ""
	respawn_queue = []
	chief_house_lv = 0
	hall_noticed = false
	shop_seeds = ["wheat", "corn"]
	recipe_pending = []
	story2_phase = ""
	village_built = []
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
	horse_tile = Vector2i(14, 12)
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
	house_lv = 0
	has_bed = false
	explored = {}
	trees_chopped = 0
	u_intro_state = 0
	story_rock_state = 0
	story_gates_left = 0
	tool_slots = default_tool_slots()
	reset_daily()


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
const FEST_START := 9.0 * 60.0    # 9시 시작
const FEST_END := 18.0 * 60.0     # 18시 종료
const FESTIVALS := {
	SPRING: {"id": "flower", "name": "봄 꽃놀이", "day": 14, "place": "plaza",
		"goal": "마을 사람 모두와 인사하기",
		"desc": "광장에 봄꽃을 늘어놓고 다 같이 모이는 날.\n"
			+ "마을 사람 모두에게 말을 걸어 인사하자.",
		"reward": {"money": 1200}},
	SUMMER: {"id": "fishing", "name": "여름 낚시대회", "day": 14, "place": "pier",
		"goal": "낚시터에서 물고기 5마리 낚기",
		"desc": "낚시터에서 열리는 마을 대회.\n"
			+ "해가 지기 전까지 물고기를 많이 낚는 사람이 이긴다.",
		"reward": {"money": 1500}},
	FALL: {"id": "harvest", "name": "가을 수확제", "day": 14, "place": "plaza",
		"goal": "가장 좋은 작물 하나 출품하기",
		"desc": "한 해 농사를 겨루는 날.\n"
			+ "가장 자신 있는 작물 하나를 광장에 출품하자.",
		"reward": {"money": 1000}},
	WINTER: {"id": "star", "name": "겨울 별빛제", "day": 14, "place": "plaza",
		"goal": "요리 하나 나눠 주기",
		"desc": "가장 긴 밤을 함께 넘기는 날.\n"
			+ "직접 만든 요리를 하나 가져와 나누자.",
		"reward": {"money": 1300}},
}

# 오늘의 축제 진행 상태 (날이 바뀌면 초기화된다)
var fest_state_day := -1     # 이 상태가 어느 날짜의 것인가
var fest_greeted: Array = [] # 봄: 인사한 주민
var fest_fish := 0           # 여름: 대회 중 낚은 수
var fest_done := false       # 오늘 축제를 끝냈는가
var fest_history: Array = [] # 지금까지 참가한 축제 id


func festival_of_day(d: int) -> Dictionary:
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

func build_save(grid_data: Array, player_pos: Vector2, objects_data: Array = [],
		animals_data: Array = []) -> Dictionary:
	return {
		"day": day,
		"minutes": minutes,
		"money": money,
		"energy": energy,
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
		"village_built": village_built,
		"house_lv": house_lv,
		"has_bed": has_bed,
		"desk_lv": desk_lv, "bed_lv": bed_lv, "desk_queue": desk_queue,
		"dust_swept": dust_swept, "kitchen_found": kitchen_found,
		"fisher_quest": fisher_quest, "fisher_choice": fisher_choice,
		"sea_open": sea_open, "story2_phase": story2_phase,
		"merchant_errand": merchant_errand, "merchant_day": merchant_day,
		"stall_hours": stall_hours,
		"forest_quest": forest_quest, "forest_day": forest_day,
		"affinity_open": affinity_open,
		"move_quest": move_quest, "move_day": move_day,
		"move_house": [move_house.x, move_house.y],
		"home_plots": home_plots,
		"mom_quest": mom_quest, "mom_quests_done": mom_quests_done,
		"spear_quest": spear_quest, "chief_house_lv": chief_house_lv,
		"hall_noticed": hall_noticed, "shop_seeds": shop_seeds,
		"story4_phase": story4_phase, "zones_open": zones_open,
		"story6_phase": story6_phase, "story6_day": story6_day,
		"old_book_stored": old_book_stored,
		"story7_phase": story7_phase, "story8_phase": story8_phase,
		"story9_phase": story9_phase, "hall_stock": hall_stock,
		"hall_loot_day": hall_loot_day, "hall_trash_total": hall_trash_total,
		"hall_projects": hall_projects, "hall_meet_day": hall_meet_day,
		"hall_feat_noticed": hall_feat_noticed,
		"arrivals": arrivals, "npc_greeted": npc_greeted,
		"recipe_items": recipe_items, "tracked_pick": tracked_pick, "respawn_queue": respawn_queue,
		"explored": explored.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"trees_chopped": trees_chopped,
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
		"grid": grid_data,
		"objects": objects_data,
		"animals": animals_data,
	}


func save_game(grid_data: Array, player_pos: Vector2, objects_data: Array = [],
		animals_data: Array = []) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(build_save(grid_data, player_pos, objects_data, animals_data)))


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
			quest = {
				"crop": q.crop, "qty": int(q.qty),
				"reward": int(q.reward), "accepted": bool(q.accepted),
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
