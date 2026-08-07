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
const CROPS := {
	"potato": {"name": "감자", "seed_price": 30, "sell_price": 80, "grow_days": 4, "seasons": [SPRING]},
	"carrot": {"name": "당근", "seed_price": 40, "sell_price": 110, "grow_days": 5, "seasons": [SPRING]},
	"strawberry": {"name": "딸기", "seed_price": 60, "sell_price": 170, "grow_days": 6, "seasons": [SPRING]},
	"tomato": {"name": "토마토", "seed_price": 50, "sell_price": 130, "grow_days": 5, "seasons": [SUMMER]},
	"corn": {"name": "옥수수", "seed_price": 75, "sell_price": 150, "grow_days": 6, "seasons": [SUMMER, FALL]},
	"watermelon": {"name": "수박", "seed_price": 120, "sell_price": 380, "grow_days": 9, "seasons": [SUMMER]},
	"pumpkin": {"name": "호박", "seed_price": 100, "sell_price": 320, "grow_days": 9, "seasons": [FALL]},
	"eggplant": {"name": "가지", "seed_price": 45, "sell_price": 120, "grow_days": 5, "seasons": [FALL]},
	"cabbage": {"name": "배추", "seed_price": 70, "sell_price": 200, "grow_days": 7, "seasons": [FALL]},
	"winter_radish": {"name": "겨울무", "seed_price": 60, "sell_price": 180, "grow_days": 6, "seasons": [WINTER]},
}
const CROP_IDS := [
	"potato", "carrot", "strawberry",
	"tomato", "corn", "watermelon",
	"pumpkin", "eggplant", "cabbage",
	"winter_radish",
]

const ENERGY_MAX := 100.0
const DAY_START := 6.0 * 60.0   # 오전 6시
const DAY_END := 26.0 * 60.0    # 새벽 2시 강제 취침

const SAVE_PATH := "user://kyojin_farm_save.json"

var day := 1
var minutes := DAY_START
var money := 500
var energy := ENERGY_MAX
var tool := "hoe"
var seed_index := 0
var seeds := {}
var produce := {}
var wood := 0
var stone := 0
var tool_level := {"hoe": 1, "water": 1}

# 설치물 비용
const FENCE_COST_WOOD := 1
const SPRINKLER_COST_WOOD := 2
const SPRINKLER_COST_STONE := 2

# 업그레이드 정의
const UPGRADES := {
	"hoe": {"name": "호미", "money": 500, "wood": 10, "desc": "전방 3칸 갈기"},
	"water": {"name": "물뿌리개", "money": 500, "wood": 10, "desc": "전방 3칸 물주기"},
}

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
}
const ITEM_IDS := ["egg", "milk", "fish_crucian", "fish_carp", "fish_catfish", "fish_golden"]

# 낚시: [아이템 id, 확률 가중치, 타이밍 존 폭(px)]
const FISH := [
	["fish_crucian", 0.45, 62.0],
	["fish_carp", 0.30, 46.0],
	["fish_catfish", 0.18, 32.0],
	["fish_golden", 0.07, 18.0],
]

var items := {}
var fish_caught := {}  # 도감용 누적 기록

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


func reset_daily() -> void:
	today_harvest = 0
	today_earned = 0
	today_spent = 0


# 새 게임 시작 시 전체 초기화 (오토로드는 씬 전환에도 유지되므로 필수)
func reset_all() -> void:
	day = 1
	minutes = DAY_START
	money = 500
	energy = ENERGY_MAX
	tool = "hoe"
	seed_index = 0
	wood = 0
	stone = 0
	tool_level = {"hoe": 1, "water": 1}
	quest = {}
	fish_caught = {}
	for id in CROP_IDS:
		seeds[id] = 0
		produce[id] = 0
	for id in ITEM_IDS:
		items[id] = 0
	for k in affinity:
		affinity[k] = 0
	seeds["potato"] = 5
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
	var mm := int((m % 60) / 10.0) * 10
	return "%s %d:%02d" % [ampm, h12, mm]


# ---- 저장 ----

func save_game(grid_data: Array, player_pos: Vector2, objects_data: Array = [],
		animals_data: Array = []) -> void:
	var data := {
		"day": day,
		"minutes": minutes,
		"money": money,
		"energy": energy,
		"seeds": seeds,
		"produce": produce,
		"items": items,
		"fish_caught": fish_caught,
		"affinity": affinity,
		"quest": quest,
		"wood": wood,
		"stone": stone,
		"tool_level": tool_level,
		"player": [player_pos.x, player_pos.y],
		"grid": grid_data,
		"objects": objects_data,
		"animals": animals_data,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


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
