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

# ---- 작물 ----
# grow_days = 성장에 필요한 게임 시간(시). 초반 작물은 빨리, 비쌀수록 오래.
const CROPS := {
	"potato": {"name": "감자", "seed_price": 30, "sell_price": 80, "grow_days": 2, "seasons": [SPRING]},
	"carrot": {"name": "당근", "seed_price": 40, "sell_price": 110, "grow_days": 3, "seasons": [SPRING]},
	"strawberry": {"name": "딸기", "seed_price": 60, "sell_price": 170, "grow_days": 4, "seasons": [SPRING]},
	"tomato": {"name": "토마토", "seed_price": 50, "sell_price": 130, "grow_days": 3, "seasons": [SUMMER]},
	"corn": {"name": "옥수수", "seed_price": 75, "sell_price": 150, "grow_days": 4, "seasons": [SUMMER, FALL]},
	"watermelon": {"name": "수박", "seed_price": 120, "sell_price": 380, "grow_days": 7, "seasons": [SUMMER]},
	"pumpkin": {"name": "호박", "seed_price": 100, "sell_price": 320, "grow_days": 7, "seasons": [FALL]},
	"eggplant": {"name": "가지", "seed_price": 45, "sell_price": 120, "grow_days": 3, "seasons": [FALL]},
	"cabbage": {"name": "배추", "seed_price": 70, "sell_price": 200, "grow_days": 5, "seasons": [FALL]},
	"winter_radish": {"name": "겨울무", "seed_price": 60, "sell_price": 180, "grow_days": 4, "seasons": [WINTER]},
}
const CROP_IDS := [
	"potato", "carrot", "strawberry",
	"tomato", "corn", "watermelon",
	"pumpkin", "eggplant", "cabbage",
	"winter_radish",
]

const ENERGY_MAX := 100.0  # 체력 (동굴 전투용. 밖에서는 천천히 자연 회복)
const DAY_START := 6.0 * 60.0   # 오전 6시
const DAY_END := 26.0 * 60.0    # 새벽 2시 강제 취침

const SAVE_PATH := "user://kyojin_farm_save.json"

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
	["open_shop", "상점 (상점 근처에서)"],
	["cycle_seed", "씨앗 바꾸기"],
	["open_inventory", "가방 (도구/능력치)"],
	["open_map", "지도"],
	["open_quest", "퀘스트 창"],
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
var window_mode := "960x540"
var _last_windowed := "960x540"


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


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"window": window_mode}))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY and d.has("window"):
		window_mode = str(d.window)
		# 구버전(3:2) 해상도 설정은 16:9 기본값으로 교체
		if not WINDOW_MODES.has(window_mode):
			window_mode = "960x540"
		if window_mode != "fullscreen":
			_last_windowed = window_mode

var day := 1
var minutes := DAY_START
# 개발용 시작 자금 (출시 전 500으로 되돌릴 것!)
var money := 100000000
var energy := ENERGY_MAX
var tool := "hoe"
var seed_index := 0
var seeds := {}
var produce := {}
var wood := 0
var stone := 0
var tool_level := {"hoe": 1, "water": 1, "axe": 1, "pickaxe": 1}

# 설치물 비용
const FENCE_COST_WOOD := 1
const SPRINKLER_COST_WOOD := 2
const SPRINKLER_COST_STONE := 2

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
}
const SKILL_IDS := ["farm", "fish", "forest", "mine", "combat", "cook"]
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
	return 0.06 * (skill_lv(id) - 1)


func combat_bonus() -> float:
	return 0.5 * (skill_lv("combat") - 1)


func cook_energy_mult() -> float:
	return 1.0 + 0.05 * (skill_lv("cook") - 1)


# ---- 집 꾸미기 가구 ----
# solid: 지나갈 수 없는 가구 (러그/액자는 통과 가능)
const FURNITURE := {
	"table": {"name": "식탁", "price": 250, "w": 60, "h": 42, "solid": true},
	"chair": {"name": "의자", "price": 80, "w": 14, "h": 16, "solid": true},
	"chest": {"name": "궤짝", "price": 150, "w": 30, "h": 26, "solid": true},
	"rug": {"name": "러그", "price": 120, "w": 88, "h": 40, "solid": false},
	"plant": {"name": "화분", "price": 100, "w": 16, "h": 20, "solid": true},
	"bookshelf": {"name": "책장", "price": 300, "w": 36, "h": 48, "solid": true},
	"lamp": {"name": "램프", "price": 150, "w": 12, "h": 26, "solid": true},
	"small_table": {"name": "탁자", "price": 140, "w": 28, "h": 24, "solid": true},
}
const FURNITURE_IDS := ["table", "chair", "chest", "rug", "plant", "bookshelf", "lamp", "small_table"]
var furniture: Array = []  # [{id, x, y}]


func default_furniture() -> Array:
	return [
		{"id": "rug", "x": 196.0, "y": 206.0},
		{"id": "table", "x": 226.0, "y": 152.0},
		{"id": "chair", "x": 208.0, "y": 162.0},
		{"id": "chair", "x": 290.0, "y": 162.0},
		{"id": "chest", "x": 344.0, "y": 110.0},
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


func pet_speed_mult() -> float:
	return 1.1 if active_pet == "dog" else 1.0


func pet_cave_def_mult() -> float:
	return 0.75 if active_pet == "owl" else 1.0


# ---- 동물 ----
const ANIMALS := {
	"chicken": {"name": "닭", "price": 800, "product": "egg"},
	"cow": {"name": "소", "price": 1500, "product": "milk"},
}
const MAX_ANIMALS := 8

# ---- 기타 판매 아이템 (동물 생산물, 물고기) ----
const ITEMS := {
	"egg": {"name": "달걀", "sell": 60},
	"milk": {"name": "우유", "sell": 120},
	"fish_crucian": {"name": "붕어", "sell": 40},
	"fish_carp": {"name": "잉어", "sell": 60},
	"fish_catfish": {"name": "메기", "sell": 90},
	"fish_golden": {"name": "황금잉어", "sell": 300},
	"ore": {"name": "광석", "sell": 50},
	"gem": {"name": "보석", "sell": 220},
	"dish_baked_potato": {"name": "구운 감자", "sell": 70},
	"dish_soup": {"name": "야채 수프", "sell": 110},
	"dish_jam": {"name": "딸기잼", "sell": 150},
	"dish_cornbread": {"name": "옥수수빵", "sell": 130},
	"dish_grilled_fish": {"name": "생선구이", "sell": 90},
	"dish_stew": {"name": "매운탕", "sell": 200},
	"dish_pie": {"name": "호박파이", "sell": 280},
	"dish_salad": {"name": "치즈 샐러드", "sell": 170},
	"dish_punch": {"name": "수박화채", "sell": 240},
	"dish_eggplant": {"name": "가지볶음", "sell": 120},
}
const ITEM_IDS := ["egg", "milk", "fish_crucian", "fish_carp", "fish_catfish", "fish_golden",
	"ore", "gem", "dish_baked_potato", "dish_soup", "dish_jam", "dish_cornbread",
	"dish_grilled_fish", "dish_stew", "dish_pie", "dish_salad", "dish_punch", "dish_eggplant"]

# ---- 요리: 재료(작물/아이템) -> 요리 아이템. energy = 먹었을 때 회복량 ----
const RECIPES := {
	"dish_baked_potato": {"needs": {"potato": 2}, "energy": 30},
	"dish_soup": {"needs": {"potato": 1, "carrot": 2}, "energy": 45},
	"dish_jam": {"needs": {"strawberry": 3}, "energy": 35},
	"dish_cornbread": {"needs": {"corn": 2}, "energy": 50},
	"dish_grilled_fish": {"needs": {"fish_crucian": 1}, "energy": 40},
	"dish_stew": {"needs": {"fish_catfish": 1, "tomato": 1}, "energy": 65},
	"dish_pie": {"needs": {"pumpkin": 1, "egg": 1}, "energy": 80},
	"dish_salad": {"needs": {"cabbage": 1, "milk": 1}, "energy": 55},
	"dish_punch": {"needs": {"watermelon": 1, "strawberry": 1}, "energy": 60},
	"dish_eggplant": {"needs": {"eggplant": 2}, "energy": 40},
}
const RECIPE_IDS := ["dish_baked_potato", "dish_soup", "dish_jam", "dish_cornbread",
	"dish_grilled_fish", "dish_stew", "dish_pie", "dish_salad", "dish_punch", "dish_eggplant"]
var recipes_cooked := {}  # 도감: id -> 만든 횟수
# 최종 목표(모든 부지 회수 = 할아버지의 농장 부활) 달성 후 엔딩을 봤는가
var ending_seen := false


# 재료 보유량 (작물이면 수확물, 아니면 아이템)
func ingredient_count(id: String) -> int:
	return int(produce[id]) if CROPS.has(id) else int(items[id])


func can_cook(id: String) -> bool:
	for k in RECIPES[id].needs:
		if ingredient_count(k) < int(RECIPES[id].needs[k]):
			return false
	return true


func cook(id: String) -> bool:
	if not can_cook(id):
		return false
	for k in RECIPES[id].needs:
		if CROPS.has(k):
			produce[k] -= int(RECIPES[id].needs[k])
		else:
			items[k] -= int(RECIPES[id].needs[k])
	items[id] += 1
	recipes_cooked[id] = int(recipes_cooked.get(id, 0)) + 1
	return true

# 낚시: [아이템 id, 확률 가중치, 타이밍 존 폭(px)]
const FISH := [
	["fish_crucian", 0.45, 62.0],
	["fish_carp", 0.30, 46.0],
	["fish_catfish", 0.18, 32.0],
	["fish_golden", 0.07, 18.0],
]

var items := {}
var fish_caught := {}  # 도감용 누적 기록

# ---- 부지 ----
# 시작 부지(home) 외에는 표지판에서 구입해야 사용할 수 있다 (이동은 자유)
const PARCELS := {
	"east": {"name": "동쪽 들판", "rect": [30, 0, 30, 20], "price": 3000},
	"south": {"name": "남쪽 들판", "rect": [0, 20, 30, 20], "price": 8000},
	"forest": {"name": "숲과 호수", "rect": [30, 20, 30, 20], "price": 15000},
	"river": {"name": "강변 부지", "rect": [60, 30, 30, 10], "price": 20000},
	"plains": {"name": "황금 평야", "rect": [0, 40, 45, 20], "price": 30000},
	"deepforest": {"name": "깊은 숲", "rect": [45, 40, 45, 20], "price": 50000},
}
var owned_parcels: Array = ["home"]


func parcel_at(x: int, y: int) -> String:
	for id in PARCELS:
		var r: Array = PARCELS[id].rect
		if x >= r[0] and x < r[0] + r[2] and y >= r[1] and y < r[1] + r[3]:
			return id
	return "home"


func is_tile_owned(x: int, y: int) -> bool:
	var p := parcel_at(x, y)
	return p == "home" or owned_parcels.has(p)


# ---- NPC / 퀘스트 ----
const NPCS := {
	"merchant": {"name": "민지", "lines": [
		"어서 와! 오늘도 농사는 잘 되고 있어?",
		"제철 씨앗이 제일 잘 자라. 상점(B)에 들러!",
		"출하 상자에 넣은 작물은 내가 좋은 값에 팔아줄게.",
		"스프링클러를 만들면 아침 물주기가 편해져.",
	]},
	"fisher": {"name": "철수", "lines": [
		"입질이 오면 초록 구간에서 낚아채는 거야.",
		"황금잉어는 정말 귀하지... 나도 두 번밖에 못 봤어.",
		"비 오는 날엔 왠지 물고기가 더 잘 잡히는 기분이야.",
		"겨울엔 농사가 안 되니 낚시가 최고야.",
	]},
}
var affinity := {"merchant": 0, "fisher": 0}
# {crop, qty, reward, accepted}
var quest := {}

# ---- 튜토리얼 / 도구 해금 ----
# 순서: [플래그, 목표 문구]. 순서를 어겨도 막히지 않는 체크리스트 방식.
const TUTORIAL_ORDER := [
	["moved", "방향키/WASD로 움직여보자"],
	["map", "지도(M)를 열어 집과 마을 위치를 확인하자"],
	["quest", "퀘스트 창(J)을 열어 할 일을 확인하자"],
	["till", "호미(1)로 풀밭을 갈자"],
	["plant", "밭에 씨앗(3)을 심자"],
	["water", "물뿌리개(2)로 물을 주자"],
	["slept", "집(북서쪽)에 들어가 침대에서 잠자기"],
	["harvest", "다 자란 작물을 수확(4)하자 - 매일 물주기!"],
	["chop", "도끼(5)로 나무를 베어 목재를 모으자"],
	["mine", "곡괭이(6)로 돌을 캐서 석재를 모으자"],
	["build", "울타리(7)나 스프링클러(8)를 설치해보자"],
	["fish", "낚싯대(9)로 물가에서 물고기를 낚자"],
	["shop", "마을 잡화점에 들어가 보자(E) - 도감도 구경!"],
]
# 목표 달성 시 해금되는 도구
const TUTORIAL_UNLOCKS := {
	"till": ["seed"],
	"plant": ["water"],
	"slept": ["hand"],
	"harvest": ["axe", "pickaxe"],
	"mine": ["fence", "sprinkler"],
	"build": ["rod"],
}
const ALL_TOOLS := ["hoe", "water", "seed", "hand", "axe", "pickaxe", "fence", "sprinkler", "rod"]
const TOOL_KOR := {
	"hoe": "호미(1)", "water": "물뿌리개(2)", "seed": "씨앗(3)", "hand": "수확(4)",
	"axe": "도끼(5)", "pickaxe": "곡괭이(6)", "fence": "울타리(7)",
	"sprinkler": "스프링클러(8)", "rod": "낚싯대(9)",
}
var tutorial := {"active": false}
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
		if not tutorial.get(pair[0], false):
			return pair[0]
	return ""


func merchant_discount() -> bool:
	return int(affinity["merchant"]) >= 50


func seed_price(id: String) -> int:
	var p: int = CROPS[id].seed_price
	if merchant_discount():
		p = int(ceil(p * 0.9))
	return p


func make_daily_quest() -> void:
	# 오늘 계절 작물 중 하나 납품 퀘스트 (날짜 해시로 결정적)
	var pool := []
	for id in CROP_IDS:
		if season() in CROPS[id].seasons:
			pool.append(id)
	if pool.is_empty():
		quest = {}
		return
	var h := fposmod(sin(float(day) * 73.7 + 17.3) * 43758.5453, 1.0)
	var crop: String = pool[int(h * pool.size()) % pool.size()]
	var qty := 3 + int(h * 97.0) % 4
	quest = {
		"crop": crop,
		"qty": qty,
		"reward": int(CROPS[crop].sell_price * qty * 1.5),
		"accepted": false,
	}


func pick_fish() -> Array:
	var r := randf()
	var acc := 0.0
	for f in FISH:
		acc += f[1]
		if r <= acc:
			return f
	return FISH[0]

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
	seeds["potato"] = 5
	_reset_skills()
	furniture = default_furniture()


func reset_daily() -> void:
	today_harvest = 0
	today_earned = 0
	today_spent = 0


# 새 게임 시작 시 전체 초기화 (오토로드는 씬 전환에도 유지되므로 필수)
func reset_all() -> void:
	day = 1
	minutes = DAY_START
	money = 100000000  # 개발용 (출시 전 500으로!)
	energy = ENERGY_MAX
	tool = "hoe"
	seed_index = 0
	wood = 0
	stone = 0
	tool_level = {"hoe": 1, "water": 1, "axe": 1, "pickaxe": 1}
	quest = {}
	fish_caught = {}
	mob_kills = {}
	recipes_cooked = {}
	ending_seen = false
	owned_pets = []
	active_pet = ""
	for id in CROP_IDS:
		seeds[id] = 0
		produce[id] = 0
	for id in ITEM_IDS:
		items[id] = 0
	for k in affinity:
		affinity[k] = 0
	seeds["potato"] = 5
	_reset_skills()
	furniture = default_furniture()
	tutorial = fresh_tutorial()
	unlocked_tools = ["hoe"]  # 튜토리얼을 깨며 하나씩 해금
	owned_parcels = ["home"]
	reset_daily()


# ---- 계절/날씨 ----

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


func weather_of_day(d: int) -> int:
	# 날짜 기반 결정적 해시 → 저장할 필요 없이 항상 같은 날씨
	var h := fposmod(sin(float(d) * 127.1 + 311.7) * 43758.5453, 1.0)
	if season_of_day(d) == WINTER:
		return WEATHER_SNOW if h < 0.35 else WEATHER_SUN
	return WEATHER_RAIN if h < 0.25 else WEATHER_SUN


func weather_today() -> int:
	return weather_of_day(day)


func weather_icon(w: int) -> String:
	if w == WEATHER_RAIN:
		return "☔"
	if w == WEATHER_SNOW:
		return "☃"
	return "☀"


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
		"quest": quest,
		"tutorial": tutorial,
		"unlocked_tools": unlocked_tools,
		"owned_parcels": owned_parcels,
		"wood": wood,
		"stone": stone,
		"tool_level": tool_level,
		"skills": skills,
		"furniture": furniture,
		"recipes_cooked": recipes_cooked,
		"ending_seen": ending_seen,
		"owned_pets": owned_pets,
		"active_pet": active_pet,
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
		"owned_parcels": owned_parcels,
		"skills": skills, "furniture": furniture,
		"recipes_cooked": recipes_cooked, "ending_seen": ending_seen,
		"owned_pets": owned_pets, "active_pet": active_pet,
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
	for k in d.get("tool_level", {}):
		tool_level[k] = int(d.tool_level[k])
	owned_parcels = d.get("owned_parcels", owned_parcels)
	apply_skills_data(d.get("skills", {}))
	if d.has("furniture"):
		apply_furniture_data(d.furniture)
	for k in d.get("recipes_cooked", {}):
		recipes_cooked[k] = int(d.recipes_cooked[k])
	owned_pets = d.get("owned_pets", owned_pets)
	active_pet = str(d.get("active_pet", active_pet))
	ending_seen = bool(d.get("ending_seen", ending_seen))
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
