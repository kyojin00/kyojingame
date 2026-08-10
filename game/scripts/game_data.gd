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


# 장착 중인 장비의 능력치 합
func gear_stat(key: String) -> float:
	var sum := 0.0
	for slot: String in GEAR_SLOTS:
		var gid: String = str(equipped.get(slot, ""))
		if gid != "" and GEAR.has(gid):
			sum += float(GEAR[gid].stats.get(key, 0.0))
	return sum


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


func can_craft_gear(gid: String) -> bool:
	if not GEAR.has(gid) or owned_gear.has(gid):
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
	# 숙련도 + 장비 행운 (행운 1당 +3%p)
	return 0.06 * (skill_lv(id) - 1) + total_luck() * 0.03


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
# 벤 나무 자리의 재성장 대기열: [x, y, 남은 일수]
var tree_regrow: Array = []
# 유저 닉네임: 스토리 1에서 우체부 아저씨가 물어봐 입력받는다
var player_name := ""

# 마을 발전: 처음 마을에는 건물이 하나도 없다.
# 이장에게 이야기해 재료를 모으면 빈 부지에 건물이 하나씩 세워진다.
# (건물 id는 main.gd의 VILLAGE_PLOTS 키)
# 마을은 처음부터 다 세워져 있다. (건물 목록은 main.VILLAGE_PLOTS와 같아야 한다)
const ALL_VILLAGE_PLOTS := ["post", "general", "lab", "smith", "ranch", "inn",
	"library", "fish"]
var village_built: Array = ALL_VILLAGE_PLOTS.duplicate()

# 집: 스토리 1 완료 후 마을 서쪽 집터에 직접 짓는다 (0=집터 / 1=집 / 2=확장)
var house_lv := 0
var has_bed := false  # 침대는 직접 제작해야 잠을 잘 수 있다
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
		"task": "나무를 베며 숲길을 따라 나아가자 (화살표 방향)",
		"story": "첫 나무를 베어 길이 열리기 시작했다. 아저씨와 함께 숲길을 따라 앞으로 나아가자."},
	{"name": "지도를 확인해보자",
		"task": "M 키를 눌러 지도를 열어 보자",
		"story": "숲길이 여러 갈래로 갈라졌다. 어느 길로 가야 할까? 아저씨가 알려준 대로 지도에서 우리 위치와 가 본 곳을 확인해 보자."},
	{"name": "마을로 가는 길을 열어보자",
		"task": "우체부 아저씨에게 받은 곡괭이를 장착하고, 길을 막은 커다란 바위를 캐보자",
		"story": "마을로 향하던 중 커다란 바위가 길을 완전히 가로막고 있었다. 아저씨가 곡괭이로 캐는 모습을 보여주며 곡괭이를 건네주었다. 배운 대로 바위를 캐서 길을 열자."},
	{"name": "마을로 이동",
		"task": "우체부 아저씨와 함께 마을 방향으로 가자 (화살표 방향)",
		"story": "바위를 치워 마침내 길이 열렸다. 아저씨와 함께 숲을 빠져나가 마을로 향하자."},
	{"name": "이장에게 편지 전달",
		"task": "마을 이장을 찾아가자",
		"story": "드디어 마을이 보인다. 우체부 아저씨가 이장님께 편지를 전하면 긴 여정이 끝난다."},
]
const STORY1_PHASE_IDX := {"enter": 0, "approach": 1, "equip": 2, "chop": 3,
	"path": 4, "map": 5, "rock": 6, "travel": 7}


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
					return "길을 따라 마을 방향으로 가보자 (화살표 방향)"
				1:
					return "곡괭이를 장착하고 바위를 클릭한 뒤 E로 캐보자"
				_:
					return "우체부 아저씨에게 말을 걸어보자"
		"travel":
			return "우체부 아저씨와 함께 마을로 가자 (화살표 방향)"
	return ""


func player_tex(part: String) -> String:
	# 여자 캐릭터 텍스처 이름 (남자는 new_boy_* 를 그대로 쓴다)
	return "player_f_" + part


func player_side_tex(is_moving: bool, suffix: String, t: float) -> String:
	# 옆모습. 남자: 걷는 중엔 4프레임 걷기(8fps), 멈추면 숨쉬기(스케일) 모션.
	# (4박자 로직의 "서기" 박자가 걷기에 끼어들지 않게 moving을 직접 본다)
	if gender == "m":
		if not is_moving:
			return "new_boy_side_idle"
		return "new_boy_side_walk_%d" % (int(t * 8.0) % 4)
	if suffix == "idle":
		return player_tex("side_idle")
	return player_tex("side_" + suffix)


func player_down_tex(is_moving: bool, suffix: String, t: float) -> String:
	# 앞모습. 남자: 걷는 중엔 4프레임 걷기(8fps), 멈추면 숨쉬기(스케일) 모션.
	if gender == "m":
		if not is_moving:
			return "new_boy_down_idle"
		return "new_boy_down_walk_%d" % (int(t * 8.0) % 4)
	if suffix == "idle":
		return player_tex("down_idle")
	return player_tex("down_" + suffix)


func player_up_tex(is_moving: bool, suffix: String, t: float) -> String:
	# 뒷모습. 남자: 걷는 중엔 4프레임 걷기(8fps), 멈추면 숨쉬기(스케일) 모션.
	if gender == "m":
		if not is_moving:
			return "new_boy_up_idle"
		return "new_boy_up_walk_%d" % (int(t * 8.0) % 4)
	if suffix == "idle":
		return player_tex("up_idle")
	return player_tex("up_" + suffix)


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
	if gender == "m":
		return "new_boy_%s_idle" % dirn
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
	"star_shard": {"name": "별빛 조각", "sell": 300},
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
	"ore", "gem", "star_shard", "dish_baked_potato", "dish_soup", "dish_jam", "dish_cornbread",
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


func breed_grow_mult() -> float:
	return 1.0 - 0.12 * breed_level     # 한 단계마다 성장 12% 단축


func breed_price_mult() -> float:
	return 1.0 + 0.08 * breed_level     # 한 단계마다 판매가 8% 상승


func breed_next_cost() -> Array:
	if breed_level >= BREED_MAX:
		return []
	return [BREED_COST[breed_level], BREED_ORE[breed_level]]


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
# 부지 구입 시스템은 삭제했다. 맵은 처음부터 전부 오갈 수 있고,
# 다음 마을은 이후 이야기(스토리)로 열린다.

func is_tile_owned(_x: int, _y: int) -> bool:
	return true


# ---- NPC / 퀘스트 ----
# 호감도가 오르면 secret50/secret100 대사가 풀리며 할아버지의 과거가 드러난다
const NPCS := {
	"merchant": {"name": "민지", "lines": [
		"어서 와! 오늘도 농사는 잘 되고 있어?",
		"제철 씨앗이 제일 잘 자라. 상점(B)에 들러!",
		"거둔 작물은 우리 가게로 가져와. 내가 좋은 값에 사줄게.",
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
	["quest", "퀘스트 창(Q)을 열어 할 일을 확인하자"],
	["note", "할아버지의 연구 노트(N)를 펼쳐보자"],
	["till", "호미를 슬롯에 장착해 풀밭을 갈자"],
	["plant", "밭에 씨앗을 심자"],
	["water", "물뿌리개로 물을 주자"],
	["harvest", "다 자란 작물에 E — 도구 없이 바로 딸 수 있다"],
	["chop", "도끼로 나무를 베어 목재를 모으자"],
	["home", "목재를 모았으니 집터(마을 서쪽)에 집을 짓자"],
	["bed", "집 안에서 침대를 만들자"],
	["slept", "침대에서 자고 다음 날을 맞자"],
	["mine", "곡괭이로 돌을 캐서 석재를 모으자"],
	["build", "울타리나 스프링클러를 설치해보자"],
	["fish", "마을 남쪽 낚시터(부두)에서 물고기를 낚자"],
	["shop", "마을 잡화점에 들어가 씨앗을 사 보자"],
]
# 목표 달성 시 해금되는 도구
# 목표를 달성하면 다음 단계에서 쓸 도구가 열린다 (순서와 어긋나지 않게)
const TUTORIAL_UNLOCKS := {
	"till": ["seed"],
	"plant": ["water"],
	"harvest": ["axe"],
	"slept": ["pickaxe"],
	"mine": ["fence", "sprinkler"],
	"build": ["rod"],
}
# 수확은 도구 없이 되므로 「바구니(hand)」 도구는 없앴다
const ALL_TOOLS := ["hoe", "water", "seed", "axe", "pickaxe", "fence", "sprinkler", "rod"]

# 튜토리얼 목표 달성 보상 (도구 해금과 별개)
const TUTORIAL_REWARDS := {
	"moved": {"money": 50},
	"map": {"money": 50},
	"quest": {"money": 50},
	"note": {"seeds": {"potato": 2}},
	"till": {"money": 30},
	"plant": {"money": 50},
	"water": {"money": 100},
	"harvest": {"money": 100},
	"chop": {"wood": 5},
	"home": {"money": 200},
	"bed": {"seeds": {"carrot": 2}},
	"slept": {"money": 150},
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
	"hoe": "호미", "water": "물뿌리개", "seed": "씨앗",
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
# %s 는 실제로 설정된 키로 바뀐다 (키 재설정을 따라간다)
const TUTORIAL_SHORT := {
	"moved": "움직여보기 (WASD)", "map": "지도 열기 (%s)", "quest": "퀘스트 창 (%s)",
	"note": "연구 노트 (%s)", "till": "밭 갈기 (1)", "plant": "씨앗 심기 (3)",
	"water": "물 주기 (2)", "harvest": "다 자란 작물에 E",
	"home": "집 짓기 (집터 E)", "bed": "침대 만들기", "slept": "침대에서 자기",
	"chop": "나무 베기 (5)", "mine": "돌 캐기 (6)", "build": "설치하기 (7/8)",
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
	# 장비 행운이 높을수록 흔한 물고기 쪽 확률을 덜어 뒤쪽(희귀)으로 넘긴다
	var r := randf() * (1.0 + total_luck() * 0.06)
	var acc := 0.0
	for f in FISH:
		acc += f[1]
		if r <= acc:
			return f
	return FISH[FISH.size() - 1]

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
	money = DEV_MONEY if DEV_MODE else START_MONEY
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
	if DEV_MODE:
		# 테스트용: 기본 아이템을 잔뜩 들고 시작한다
		wood = DEV_STOCK
		stone = DEV_STOCK
		for id in CROP_IDS:
			seeds[id] = DEV_STOCK
			produce[id] = DEV_STOCK
		for id in ITEM_IDS:
			items[id] = DEV_STOCK
	_reset_skills()
	furniture = default_furniture()
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
	# 마을은 처음부터 다 세워져 있다 (건물을 하나씩 짓는 단계는 없앴다)
	village_built = ALL_VILLAGE_PLOTS.duplicate()
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
		"explored": explored.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"trees_chopped": trees_chopped,
		"u_intro": u_intro_state,
		"rock_state": story_rock_state,
		"gates_left": story_gates_left,
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
