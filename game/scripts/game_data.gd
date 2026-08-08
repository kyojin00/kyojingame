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
		# 구버전 해상도 설정은 현재 기본값으로 교체
		if not WINDOW_MODES.has(window_mode):
			window_mode = "1440x810"
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
	"table": {"name": "식탁", "price": 250, "w": 90, "h": 63, "solid": true},
	"chair": {"name": "의자", "price": 80, "w": 21, "h": 24, "solid": true},
	"chest": {"name": "궤짝", "price": 150, "w": 45, "h": 39, "solid": true},
	"rug": {"name": "러그", "price": 120, "w": 132, "h": 60, "solid": false},
	"plant": {"name": "화분", "price": 100, "w": 24, "h": 30, "solid": true},
	"bookshelf": {"name": "책장", "price": 300, "w": 54, "h": 72, "solid": true},
	"lamp": {"name": "램프", "price": 150, "w": 18, "h": 39, "solid": true},
	"small_table": {"name": "탁자", "price": 140, "w": 42, "h": 36, "solid": true},
}
const FURNITURE_IDS := ["table", "chair", "chest", "rug", "plant", "bookshelf", "lamp", "small_table"]
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
var gender := "m"  # 플레이어 성별 (m/f) — 새 게임에서 선택
# 메인 스토리 1 「우체부 아저씨와의 첫 만남」 진행 단계
# enter: 숲 안으로 들어가보기 / approach: 우체부 접근·대화 /
# equip: 나무도끼를 가방 슬롯에 장착 / chop: 나무를 베어보자 / done: 완료
var story_phase := "done"


func story_objective_short() -> String:
	match story_phase:
		"enter":
			return "우거진 숲 안으로 들어가 보자"
		"approach":
			return "우체부 아저씨의 이야기를 듣자"
		"equip":
			return "나무도끼를 가방(I) 슬롯에 장착해 보자"
		"chop":
			return "나무도끼로 나무를 베어보자"
	return ""


func player_tex(part: String) -> String:
	# 성별에 맞는 플레이어 텍스처 이름
	return ("player_f_" if gender == "f" else "player_") + part


func player_side_tex(is_moving: bool, suffix: String, t: float) -> String:
	# 옆모습. 남자: 걷는 중엔 20프레임 걷기만(8fps), 멈추면 숨쉬기 모션.
	# (4박자 로직의 "서기" 박자가 걷기에 끼어들지 않게 moving을 직접 본다)
	if gender == "m":
		if not is_moving:
			return player_idle_tex("side")
		return "player_side_walk_%d" % (int(t * 6.0) % 4)
	if suffix == "idle":
		return player_tex("side_idle")
	return player_tex("side_" + suffix)


func player_down_tex(is_moving: bool, suffix: String, t: float) -> String:
	# 앞모습. 남자: 걷는 중엔 4프레임 걷기(6fps), 멈추면 정지 프레임.
	if gender == "m":
		if not is_moving:
			return player_idle_tex("down")
		return "player_down_walk_%d" % (int(t * 6.0) % 4)
	if suffix == "idle":
		return player_tex("down_idle")
	return player_tex("down_" + suffix)


func player_up_tex(is_moving: bool, suffix: String, t: float) -> String:
	# 뒷모습. 남자: 걷는 중엔 4프레임 걷기(6fps), 멈추면 정지 프레임.
	if gender == "m":
		if not is_moving:
			return player_idle_tex("up")
		return "player_up_walk_%d" % (int(t * 6.0) % 4)
	if suffix == "idle":
		return player_tex("up_idle")
	return player_tex("up_" + suffix)


func player_idle_tex(dirn: String) -> String:
	# 대기 모션: 남자 옆/앞모습은 4프레임 숨쉬기 애니메이션 (0.4초/프레임)
	if gender == "m" and dirn in ["side", "down"]:
		return "player_%s_idle_%d" % [dirn, int(Time.get_ticks_msec() / 400.0) % 4]
	return player_tex(dirn + "_idle")



func pet_speed_mult() -> float:
	return 1.1 if active_pet == "dog" else 1.0


func pet_cave_def_mult() -> float:
	return 0.75 if active_pet == "owl" else 1.0


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
	# 채집물/곤충
	"forage_berry": {"name": "산딸기", "sell": 40},
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
}
const ITEM_IDS := ["egg", "milk", "fish_crucian", "fish_carp", "fish_catfish", "fish_golden",
	"ore", "gem", "dish_baked_potato", "dish_soup", "dish_jam", "dish_cornbread",
	"dish_grilled_fish", "dish_stew", "dish_pie", "dish_salad", "dish_punch", "dish_eggplant",
	"forage_berry", "forage_herb", "bug_butterfly", "bug_dragonfly", "bug_firefly",
	"gold_crop", "world_branch", "star_ore", "ghost_essence", "golden_egg", "memory_piece"]

# 채집물/곤충 도감 (팔아도 기록은 남는다)
const FORAGE_IDS := ["forage_berry", "forage_herb"]
const BUG_IDS := ["bug_butterfly", "bug_dragonfly", "bug_firefly"]
# 곤충 출현 조건
const BUGS := {
	"bug_butterfly": {"seasons": [SPRING, SUMMER], "night": false},
	"bug_dragonfly": {"seasons": [SUMMER, FALL], "night": false},
	"bug_firefly": {"seasons": [SUMMER], "night": true},
}
var forage_caught := {}  # id -> 누적 획득 수

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
	for f in FISH:
		total += 1
		if int(fish_caught.get(f[0], 0)) > 0:
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


# 수확 품질 굴리기: 0=일반 1=은 2=금 (농사 숙련도가 높을수록 좋다)
func roll_quality() -> int:
	var lv := skill_lv("farm")
	if randf() < 0.02 + lv * 0.008:
		return 2
	if randf() < 0.08 + lv * 0.02:
		return 1
	return 0


func add_produce(id: String, quality: int) -> void:
	produce[id] += 1
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
	var price: int = CROPS[id].sell_price
	var silver := int(produce_silver.get(id, 0))
	var gold := int(produce_gold.get(id, 0))
	var normal: int = int(produce[id]) - silver - gold
	return int(normal * price + silver * price * 1.25 + gold * price * 1.5)


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
			consume_produce(k, int(RECIPES[id].needs[k]))
		else:
			items[k] -= int(RECIPES[id].needs[k])
	items[id] += 1
	recipes_cooked[id] = int(recipes_cooked.get(id, 0)) + 1
	return true

# 낚시: [아이템 id, 확률 가중치, 타이밍 존 폭(px)]
const FISH := [
	["fish_crucian", 0.45, 93.0],
	["fish_carp", 0.30, 69.0],
	["fish_catfish", 0.18, 48.0],
	["fish_golden", 0.07, 27.0],
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
# 호감도가 오르면 secret50/secret100 대사가 풀리며 할아버지의 과거가 드러난다
const NPCS := {
	"merchant": {"name": "민지", "lines": [
		"어서 와! 오늘도 농사는 잘 되고 있어?",
		"제철 씨앗이 제일 잘 자라. 상점(B)에 들러!",
		"출하 상자에 넣은 작물은 내가 좋은 값에 팔아줄게.",
		"스프링클러를 만들면 아침 물주기가 편해져.",
	],
	"secret50": "너희 할아버지... 우리 가게 단골이었어. 늘 이상한 걸 찾으셨지.\n'달빛을 먹고 자란 작물'이라던가... 밭에서도 기적이 자란다고 하셨어.",
	"secret100": "떠나시기 전에 그러셨어. '내 연구는 이 마을 전부에 흩어져 있다'고.\n밭, 호수, 숲, 동굴... 그리고 사람들 속에도. 이제 그 말뜻을 알겠니?",
	},
	"fisher": {"name": "철수", "lines": [
		"입질이 오면 초록 구간에서 낚아채는 거야.",
		"황금잉어는 정말 귀하지... 나도 두 번밖에 못 봤어.",
		"비 오는 날엔 왠지 물고기가 더 잘 잡히는 기분이야.",
		"겨울엔 농사가 안 되니 낚시가 최고야.",
	],
	"secret50": "네 할아버지랑 밤새 낚시하던 게 엊그제 같은데...\n그분은 물고기를 잡으면 놓아주면서 뭔가를 계속 적으셨어. 연구라고 하셨지.",
	"secret100": "할아버지가 마지막으로 남긴 말이 있어. '전설은 잡는 게 아니라\n기록하는 것'이라고. 이 기억 조각... 네가 가져야 할 것 같구나.",
	},
	"blacksmith": {"name": "무쇠", "lines": [
		"광석을 가져오면 도구를 벼려주지. 대장간으로 와.",
		"동굴 깊은 곳 광석일수록 좋은 쇠가 된다.",
		"쇠는 정직해. 두드린 만큼만 단단해지지.",
		"요즘 젊은것들은 도끼 가는 법도 몰라... 자네는 다르군.",
	],
	"secret50": "자네 할아버지? 별난 양반이었지. 광석을 사 가면서\n'이건 녹이려는 게 아니라 별을 담으려는 거야'라고 하더군.",
	"secret100": "떠나기 전에 화로를 빌려 갔어. 뭘 만들었는지는 끝내 안 보여줬지만...\n그날 밤 대장간 굴뚝에서 무지개색 연기가 올라왔다네.",
	},
	"rancher": {"name": "보라", "lines": [
		"동물은 사랑을 먹고 자라. 매일 쓰다듬어 줘!",
		"닭이 낳은 달걀은 아침에 거둬야 신선해.",
		"우리 목장 상회에서 귀여운 펫도 분양하고 있어~",
		"축사가 있으면 비 오는 날에도 동물들이 편하지.",
	],
	"secret50": "너희 할아버지, 동물들이 유난히 따랐어.\n'동물이 주는 건 생산물이 아니라 마음'이라고 입버릇처럼 말씀하셨지.",
	"secret100": "언젠가 금빛으로 빛나는 달걀을 보여주신 적이 있어.\n'사랑받은 닭만이 낳을 수 있다'며... 나는 아직도 그게 꿈같아.",
	},
	"chief": {"name": "덕수", "lines": [
		"우리 마을에 젊은 사람이 오니 좋구먼.",
		"부지 문서는 내가 관리하고 있네. 표지판에서 사면 돼.",
		"광장 게시판에 마을 사람들 부탁이 올라온다네.",
		"자네 할아버지와는... 오랜 친구였지.",
	],
	"secret50": "자네 할아버지가 이 마을에 처음 왔을 때, 다들 미친 사람 취급했어.\n나만 빼고. 그 눈빛은... 미친 게 아니라 믿는 사람의 눈이었거든.",
	"secret100": "그 양반이 마지막으로 한 말을 전해주지. '덕수, 내 손주가 오면\n일곱 가지를 모을 걸세. 그때 이 마을은 기적을 보게 될 거야.'",
	},
}
var affinity := {"merchant": 0, "fisher": 0, "blacksmith": 0, "rancher": 0, "chief": 0}
# {crop, qty, reward, accepted}
var quest := {}

# ---- 튜토리얼 / 도구 해금 ----
# 순서: [플래그, 목표 문구]. 순서를 어겨도 막히지 않는 체크리스트 방식.
const TUTORIAL_ORDER := [
	["moved", "방향키/WASD로 움직여보자"],
	["map", "지도(M)를 열어 집과 마을 위치를 확인하자"],
	["quest", "퀘스트 창(J)을 열어 할 일을 확인하자"],
	["note", "할아버지의 연구 노트(N)를 펼쳐보자"],
	["till", "호미를 슬롯에 장착해 풀밭을 갈자"],
	["plant", "밭에 씨앗을 심자"],
	["water", "물뿌리개로 물을 주자"],
	["slept", "집(북서쪽)에 들어가 침대에서 잠자기"],
	["harvest", "다 자란 작물을 수확하자 - 매일 물주기!"],
	["chop", "도끼로 나무를 베어 목재를 모으자"],
	["mine", "곡괭이로 돌을 캐서 석재를 모으자"],
	["build", "울타리나 스프링클러를 설치해보자"],
	["fish", "낚싯대로 물가에서 물고기를 낚자"],
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

# 튜토리얼 목표 달성 보상 (도구 해금과 별개)
const TUTORIAL_REWARDS := {
	"moved": {"money": 50},
	"map": {"money": 50},
	"quest": {"money": 50},
	"note": {"seeds": {"potato": 2}},
	"till": {"money": 30},
	"plant": {"money": 50},
	"water": {"money": 100},
	"slept": {"seeds": {"carrot": 2}},
	"harvest": {"money": 100},
	"chop": {"wood": 5},
	"mine": {"stone": 5},
	"build": {"money": 150},
	"fish": {"money": 200},
	"shop": {"money": 300},
}

# 도구 슬롯(빠른 사용 슬롯) 9칸: 1~9 숫자키로 선택 — 가방에서 자유 배치
const TOOL_SLOT_COUNT := 9


static func default_tool_slots() -> Array:
	var slots: Array = ALL_TOOLS.duplicate()
	while slots.size() < TOOL_SLOT_COUNT:
		slots.append("")
	return slots


var tool_slots: Array = default_tool_slots()
# 슬롯은 자유 배치이므로 고정 번호를 붙이지 않는다 (가방에서 장착 후 숫자키 선택)
const TOOL_KOR := {
	"hoe": "호미", "water": "물뿌리개", "seed": "씨앗", "hand": "수확",
	"axe": "도끼", "pickaxe": "곡괭이", "fence": "울타리",
	"sprinkler": "스프링클러", "rod": "낚싯대",
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


# 우측 트래커용 짧은 목표 문구
const TUTORIAL_SHORT := {
	"moved": "움직여보기 (WASD)", "map": "지도 열기 (M)", "quest": "퀘스트 창 (J)",
	"note": "연구 노트 (N)", "till": "밭 갈기 (1)", "plant": "씨앗 심기 (3)",
	"water": "물 주기 (2)", "slept": "침대에서 자기", "harvest": "수확하기 (4)",
	"chop": "나무 베기 (5)", "mine": "돌 캐기 (6)", "build": "설치하기 (7/8)",
	"fish": "낚시하기 (9)", "shop": "잡화점 가보기",
}


func tutorial_objective_short() -> String:
	var flag := tutorial_current_flag()
	return String(TUTORIAL_SHORT.get(flag, "")) if flag != "" else ""


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
	crops_harvested = {}
	minerals_found = {}
	memory_given = false
	forage_caught = {}
	produce_silver = {}
	produce_gold = {}
	barn_built = false
	owned_pets = []
	active_pet = ""
	for id in CROP_IDS:
		seeds[id] = 0
		produce[id] = 0
	for id in ITEM_IDS:
		items[id] = 0
	for k in affinity:
		affinity[k] = 0
	_reset_skills()
	furniture = default_furniture()
	tutorial = fresh_tutorial()
	# 시작 시 도구/씨앗은 아무것도 주지 않는다 — 스토리·퀘스트로 획득하는 구조
	unlocked_tools = []
	tool_slots = default_tool_slots()
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
		"tool_slots": tool_slots,
		"skills": skills,
		"furniture": furniture,
		"recipes_cooked": recipes_cooked,
		"ending_seen": ending_seen,
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
		"owned_parcels": owned_parcels,
		"skills": skills, "furniture": furniture,
		"recipes_cooked": recipes_cooked, "ending_seen": ending_seen,
		"crops_harvested": crops_harvested, "minerals_found": minerals_found,
		"memory_given": memory_given, "forage_caught": forage_caught,
		"produce_silver": produce_silver, "produce_gold": produce_gold,
		"barn_built": barn_built,
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
