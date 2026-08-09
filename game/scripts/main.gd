# 메인 월드: 맵, 경작, 도구, 자원, 시간, 낮/밤을 관리한다.
extends Node2D

const MAP_W := 90
const MAP_H := 60
const TILE := 32

const MIN_PER_SEC := 10.0 / 7.0  # 실제 7초 = 게임 10분
const TREE_HP := 3
const ROCK_HP := 2
const WOOD_PER_TREE := 3
const STONE_PER_ROCK := 2

# 물 지속 시간 (게임 분): 손 물주기 6시간, 비/스프링클러는 하루 종일
const WET_MANUAL := 360.0
const WET_ALL_DAY := 1200.0


# 작물 성숙에 필요한 누적 성장 시간 (게임 분) — grow_days를 '시간'으로 해석
func _grow_total(def: Dictionary) -> float:
	return float(def.grow_days) * 60.0


# 절반까지 자란 작물은 물을 한 번 더 받아야 계속 자란다 (성장 체크포인트)
const GROW_CHECKPOINT := 0.5


# 이 칸의 작물이 체크포인트에서 물을 기다리며 멈춰 있는가
func _crop_thirsty(cell: Dictionary) -> bool:
	if cell.crop_id == "" or cell.dead or bool(cell.get("half_fed", false)):
		return false
	return float(cell.crop_day) >= _grow_total(GameData.CROPS[cell.crop_id]) * GROW_CHECKPOINT


func _wet(cell: Dictionary, minutes: float) -> void:
	cell.wet_min = maxf(float(cell.wet_min), minutes)
	cell.watered = true
	# 절반까지 자란 뒤에 받은 물만 체크포인트를 통과시킨다
	# (심을 때 내린 비로 미리 통과되지 않도록 성장률을 직접 본다)
	if _crop_thirsty(cell):
		cell.half_fed = true

# grid[y][x] = {ground, watered, crop_id, crop_day, dead}
var grid: Array = []
# Vector2i -> {kind: "tree"|"rock"|"house"|"bin"|"fence"|"sprinkler", hp: int}
var objects: Dictionary = {}
var obj_nodes: Dictionary = {}  # Vector2i -> Node2D (설치/제거 가능한 오브젝트만)

var tex: Dictionary = {}
var world: Node2D
var overlay: Node2D  # 건물보다 앞에 그리는 안내 텍스트/화살표/날씨 레이어
var player: Node2D
var hud: CanvasLayer
var shop: CanvasLayer
var summary: CanvasLayer
var night: CanvasModulate
var sleep_dialog: ConfirmationDialog
var water_frame := 0
var water_timer := 0.0
var _growth_timer := 0.0
var tree_sprites: Array = []
var weather_time := 0.0
var animals: Array = []

# 낚시 상태: "" | "waiting"(입질 대기) | "bite"(입질!)
var fishing_state := ""
var fishing_timer := 0.0
var fishing_ui: CanvasLayer
var pending_fish: Array = []
var dialog: CanvasLayer
var map_ui: CanvasLayer
var inventory_ui: CanvasLayer
var interior: CanvasLayer
var cooking_ui: CanvasLayer
var quest_ui: CanvasLayer
var note_ui: CanvasLayer
var stats_ui: CanvasLayer
var cave: CanvasLayer
var pet: Node2D
var fade_rect: ColorRect

# ---- 멀티플레이 상태 ----
var remote_players := {}  # peer_id -> remote_player 노드
var _pos_sync_timer := 0.0
var _time_sync_timer := 0.0
var _net_ready := false   # 게스트: 스냅샷 수신 완료 여부
var _connect_label: Label
const PLAYER_TINTS := [
	Color(1, 1, 1), Color(1, 0.85, 0.85), Color(0.85, 1, 0.9), Color(0.88, 0.9, 1),
]
var day_transitioning := false
var particles: Array = []

# 개발/CI용: KYOJIN_SHOT=경로 로 실행하면 잠시 후 스크린샷을 저장하고 종료한다.
# KYOJIN_DAY=숫자, KYOJIN_WEATHER=0/1/2 로 시작 날짜/날씨를 강제할 수 있다.
var _shot_path := ""
var _shot_frames := 0
var _weather_override := -1

const TEXTURE_NAMES := [
	"player_f_down_0", "player_f_down_1", "player_f_up_0", "player_f_up_1",
	"player_f_side_0", "player_f_side_1",
	"player_f_down_idle", "player_f_up_idle", "player_f_side_idle",
	"new_boy_down_idle", "new_boy_side_idle", "new_boy_up_idle",
	"new_boy_down_walk_0", "new_boy_down_walk_1",
	"new_boy_down_walk_2", "new_boy_down_walk_3",
	"new_boy_side_walk_0", "new_boy_side_walk_1",
	"new_boy_side_walk_2", "new_boy_side_walk_3",
	"new_boy_up_walk_0", "new_boy_up_walk_1",
	"new_boy_up_walk_2", "new_boy_up_walk_3",
	"crop_sprout", "crop_small", "crop_medium", "withered",
	"mature_potato", "mature_carrot", "mature_strawberry", "mature_pumpkin",
	"mature_tomato", "mature_corn", "mature_watermelon",
	"mature_eggplant", "mature_cabbage", "mature_winter_radish",
	"tree_spring", "tree_summer", "tree_fall", "tree_winter",
	"tree_bare", "tree_half", "tree_apple",
	"tree_01", "tree_06", "tree_09", "tree_13", "tree_15",
	"rock", "bin", "house", "fence", "sprinkler", "board", "sign",
	"deco_fountain", "deco_lamp", "deco_bench",
	"cave", "slime_0", "slime_1", "bat_0", "bat_1", "ghost_0", "ghost_1",
	"ore_node", "chest", "stairs",
	"chicken_0", "chicken_1", "cow_0", "cow_1",
	"pet_dog_0", "pet_dog_1", "pet_cat_0", "pet_cat_1",
	"pet_owl_0", "pet_owl_1", "pet_rabbit_0", "pet_rabbit_1",
	"npc_postman_down_0", "npc_postman_down_1", "npc_postman_up_0",
	"npc_postman_up_1", "npc_postman_side_0", "npc_postman_side_1",
	"npc_postman_portrait_normal", "npc_postman_portrait_happy",
	"npc_merchant_down_0", "npc_merchant_down_1", "npc_merchant_up_0",
	"npc_merchant_up_1", "npc_merchant_side_0", "npc_merchant_side_1",
	"npc_fisher_down_0", "npc_fisher_down_1", "npc_fisher_up_0",
	"npc_fisher_up_1", "npc_fisher_side_0", "npc_fisher_side_1",
	"npc_merchant_portrait_normal", "npc_merchant_portrait_happy",
	"npc_fisher_portrait_normal", "npc_fisher_portrait_happy",
	"npc_blacksmith_down_0", "npc_blacksmith_down_1", "npc_blacksmith_up_0",
	"npc_blacksmith_up_1", "npc_blacksmith_side_0", "npc_blacksmith_side_1",
	"npc_blacksmith_portrait_normal", "npc_blacksmith_portrait_happy",
	"npc_rancher_down_0", "npc_rancher_down_1", "npc_rancher_up_0",
	"npc_rancher_up_1", "npc_rancher_side_0", "npc_rancher_side_1",
	"npc_rancher_portrait_normal", "npc_rancher_portrait_happy",
	"mob_centipede_0", "mob_centipede_1",
	"npc_chief_down_0", "npc_chief_down_1", "npc_chief_up_0",
	"npc_chief_up_1", "npc_chief_side_0", "npc_chief_side_1",
	"npc_chief_portrait_normal", "npc_chief_portrait_happy",
	"forage_berry", "forage_herb", "bug_butterfly_0", "bug_butterfly_1",
	"bug_dragonfly_0", "bug_dragonfly_1", "bug_firefly_0", "bug_firefly_1",
	"treant_0", "treant_1", "barn", "icon_coin", "icon_heart",
	"icon_hoe", "icon_water", "icon_seed", "icon_basket", "icon_axe", "icon_axe_stone",
	"icon_pickaxe", "icon_rod", "icon_wood", "icon_stone",
	"grass_spring_0", "grass_spring_1", "grass_spring_2",
	"grass_summer_0", "grass_summer_1", "grass_summer_2",
	"grass_fall_0", "grass_fall_1", "grass_fall_2",
	"grass_winter_0", "grass_winter_1", "grass_winter_2",
	"soil_dry", "soil_wet", "water_0", "water_1", "path",
]

const START_TILE := Vector2i(14, 10)
const CAVE_POS := Vector2i(50, 1)
const WORLDTREE_POS := Vector2i(68, 50)  # 세계수 동굴 (깊은 숲)
const BARN_POS := Vector2i(10, 3)        # 축사 (구입 시 농장에 건설)
# ---- 교진 마을 ----
# 마을에는 처음에 건물이 하나도 없다.
# 넓은 중앙 광장과 사방으로 뻗은 길, 그리고 나중에 건물이 들어설 빈 부지뿐이다.
# 건물은 진행에 따라 하나씩 세워지며, 그때마다 마을의 모습이 달라진다.
const VILLAGE_REGION := Rect2i(60, 0, 30, 30)
const ROAD := Rect2i(30, 8, 30, 2)         # 농장/숲 -> 마을 공용 길
const MAIN_STREET_Y := 8                   # 마을 입구를 가로지르는 큰길 (2칸)
const PLAZA := Rect2i(68, 12, 14, 10)      # 중앙 광장 (아주 넓은 평지)
const FOUNTAIN := Rect2i(73, 15, 4, 4)     # 광장 중앙 분수
const FOUNTAIN_DECO := Vector2i(74, 17)    # 분수 조형물 (분수 한가운데)
const VILLAGE_RIVER_Y := 27                # 마을 남쪽 외곽을 흐르는 강 (2칸)
const DOCK_Y := 26                         # 강가 낚시터(부두)
const BOARD_POS := Vector2i(77, 12)        # 광장 게시판 (오늘의 의뢰)
const PLAZA_LAMPS := [Vector2i(69, 13), Vector2i(80, 13),
	Vector2i(69, 20), Vector2i(80, 20)]
const PLAZA_BENCHES := [Vector2i(71, 16), Vector2i(71, 18),
	Vector2i(78, 16), Vector2i(78, 18)]

# 우리집: 스토리 1 완료 후 마을 서쪽 집터(E)에서 목재로 직접 짓는다
const HOME_ANCHOR := Vector2i(61, 4)
const HOME_SITE := Vector2i(63, 6)  # 집터 표지판 위치

# 건물 부지(좌상단 앵커, 5x4). 처음에는 아무것도 없는 빈 공간이며
# 표지판도 건물 이름도 표시하지 않는다. 건설된 뒤에만 실제 건물이 나타난다.
const VILLAGE_PLOTS := {
	"post":    {"anchor": Vector2i(68, 4),  "name": "우체국"},
	"general": {"anchor": Vector2i(77, 4),  "name": "잡화점"},
	"smith":   {"anchor": Vector2i(61, 11), "name": "대장간"},
	"lab":     {"anchor": Vector2i(82, 11), "name": "연구소"},
	"inn":     {"anchor": Vector2i(61, 18), "name": "여관"},
	"library": {"anchor": Vector2i(82, 18), "name": "도서관"},
	"ranch":   {"anchor": Vector2i(67, 22), "name": "목장 상회"},
	"fish":    {"anchor": Vector2i(77, 22), "name": "수산시장"},
}
# 마을 발전 순서: 이장에게 이야기하면 이 순서대로 하나씩 지을 수 있다.
# (여관·연구소·도서관 부지는 자리만 잡아두고 이후 이야기에서 열린다)
const VILLAGE_BUILD_ORDER := ["post", "general", "smith", "ranch", "fish"]
const VILLAGE_BUILD_COST := {   # [목재, 석재]
	"post": [30, 10], "general": [50, 20], "smith": [60, 50],
	"ranch": [80, 40], "fish": [100, 60],
}
# 건물이 생기면 그 건물의 주인이 마을에 자리를 잡는다 (이장은 처음부터 있다)
const VILLAGE_NPC := {"general": "merchant", "smith": "blacksmith",
	"ranch": "rancher", "fish": "fisher"}
const BUILDING_NAMES := {
	"home": "집", "post": "우체국", "general": "잡화점", "smith": "대장간",
	"lab": "연구소", "inn": "여관", "library": "도서관",
	"ranch": "목장 상회", "fish": "수산시장",
}
# 폰트 규칙: 큰 글씨(14px+)=갈무리11, 작은 글씨(13px 이하·소형 오버레이)=갈무리9
# 카메라 줌: 1보다 작을수록 더 넓게(작게) 보인다. 화면에 보이는 범위 = 960/줌 x 540/줌
const CAMERA_ZOOM := 0.8                   # 1200 x 675 월드 픽셀 = 37.5 x 21 타일
const UI_FONT := preload("res://assets/fonts/Galmuri11.ttf")
const UI_FONT_SMALL := preload("res://assets/fonts/Galmuri9.ttf")

var npcs: Array = []


func _ready() -> void:
	_load_textures()
	_build_map()

	night = CanvasModulate.new()
	add_child(night)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	overlay = Node2D.new()
	overlay.name = "Overlay"
	overlay.z_index = 100
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	player = preload("res://scenes/player.tscn").instantiate()
	player.main = self
	player.position = Vector2(START_TILE.x * TILE + 16, START_TILE.y * TILE + 16)
	world.add_child(player)
	_setup_camera()

	pet = preload("res://scripts/pet.gd").new()
	pet.main = self
	pet.position = player.position + Vector2(14, 4)
	world.add_child(pet)

	hud = preload("res://scenes/hud.tscn").instantiate()
	hud.main = self
	add_child(hud)

	shop = preload("res://scenes/shop.tscn").instantiate()
	shop.main = self
	add_child(shop)

	summary = preload("res://scenes/summary.tscn").instantiate()
	add_child(summary)

	fishing_ui = preload("res://scripts/fishing_ui.gd").new()
	fishing_ui.finished.connect(_on_fishing_finished)
	add_child(fishing_ui)

	dialog = preload("res://scripts/dialog_ui.gd").new()
	add_child(dialog)

	map_ui = preload("res://scripts/map_ui.gd").new()
	map_ui.main = self
	add_child(map_ui)

	inventory_ui = preload("res://scripts/inventory_ui.gd").new()
	inventory_ui.main = self
	add_child(inventory_ui)

	interior = preload("res://scripts/interior_ui.gd").new()
	interior.main = self
	add_child(interior)

	cooking_ui = preload("res://scripts/cooking_ui.gd").new()
	cooking_ui.main = self
	add_child(cooking_ui)

	quest_ui = preload("res://scripts/quest_ui.gd").new()
	quest_ui.main = self
	add_child(quest_ui)

	note_ui = preload("res://scripts/note_ui.gd").new()
	note_ui.main = self
	add_child(note_ui)

	stats_ui = preload("res://scripts/stats_ui.gd").new()
	stats_ui.main = self
	add_child(stats_ui)

	cave = preload("res://scripts/cave_ui.gd").new()
	cave.main = self
	add_child(cave)

	# 마을 사람들: 이장만 처음부터 광장에 있고,
	# 나머지는 자기 건물이 지어진 뒤에 마을에 자리를 잡는다
	_spawn_npc("chief", Vector2i(71, 20))

	sleep_dialog = ConfirmationDialog.new()
	sleep_dialog.dialog_text = "잠자리에 들까요?\n다음 날 아침이 됩니다."
	sleep_dialog.ok_button_text = "잔다"
	sleep_dialog.cancel_button_text = "안 잔다"
	sleep_dialog.confirmed.connect(func() -> void:
		Sound.play_sfx("sfx_sleep")
		_fade_next_day(false))
	add_child(sleep_dialog)

	_shot_path = OS.get_environment("KYOJIN_SHOT")
	if OS.get_environment("KYOJIN_DAY") != "":
		GameData.day = int(OS.get_environment("KYOJIN_DAY"))
	if OS.get_environment("KYOJIN_WEATHER") != "":
		_weather_override = int(OS.get_environment("KYOJIN_WEATHER"))

	if Net.active():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if Net.is_guest():
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		# 게스트: 로컬 저장 대신 호스트 스냅샷을 기다린다
		GameData.reset_all()
		GameData.tutorial = {"active": false}
		GameData.story_phase = "done"
		GameData.unlock_all_tools()
		player.position = Vector2((START_TILE.x + multiplayer.get_unique_id() % 3 + 1) * TILE + 16,
			START_TILE.y * TILE + 16)
		_show_connecting()
		# 연결이 완료된 뒤에 스냅샷을 요청한다 (그 전 RPC는 유실됨)
		multiplayer.connected_to_server.connect(func() -> void: _req_snapshot.rpc_id(1))
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_req_snapshot.rpc_id(1)
		_spawn_objects()
		_apply_season_visuals()
		_setup_fade(false)
		return

	var loaded := GameData.load_game()
	if loaded.size() > 0:
		_apply_save(loaded)
		_apply_story_camera.call_deferred()
		# 스토리 도중 저장했다면 우체부 아저씨가 계속 동행한다
		if GameData.story_phase == "approach":
			_spawn_postman()  # 아직 대화 전 -> 다시 걸어와 말을 건다
		elif GameData.story_phase in ["equip", "chop", "path", "map", "rock", "travel"]:
			_spawn_postman()
			story_cutscene = false
			_postman_state = "follow"
			_postman.position = player.position + Vector2(-42, 6)
		hud.show_message("저장된 농장을 불러왔다!")
	else:
		GameData.reset_all()
		var story_shot := _shot_path != "" and OS.get_environment("KYOJIN_STORY") != ""
		if (_shot_path == "" and OS.get_environment("KYOJIN_MP") == "") or story_shot:
			# 메인 스토리 1: 울창한 숲 동남쪽 구석에서 시작한다
			GameData.story_phase = "enter"
			# 스토리로 배우는 조작: 빠른 슬롯은 비운 채 시작한다
			# (도끼를 받아 가방(I)에서 직접 장착해야 사용할 수 있다)
			GameData.tool_slots = []
			for i in GameData.TOOL_SLOT_COUNT:
				GameData.tool_slots.append("")
			GameData.tool = "hand"
			player.position = Vector2(STORY_SPAWN.x * TILE + 16, STORY_SPAWN.y * TILE + 16)
			_plant_story_forest()
			_apply_story_camera.call_deferred()
			hud.show_message("우거진 숲... 이 숲을 지나야 마을이 나온다.", 5.0)
			if not story_shot:
				_show_intro.call_deferred()
		else:
			player.position = Vector2(4 * TILE + 16, 5 * TILE + 16)
		if _shot_path != "" and not story_shot:
			GameData.unlock_all_tools()  # 검증 시퀀스는 모든 도구 사용
			GameData.seeds["potato"] = 5  # 씨앗 심기 캡처용
			GameData.house_lv = 2         # 집/부엌/침대 캡처용
			GameData.has_bed = true
			for cy in range(0, MAP_H / GameData.EXPLORE_CHUNK + 1):
				for cx in range(0, MAP_W / GameData.EXPLORE_CHUNK + 1):
					GameData.explored[Vector2i(cx, cy)] = true  # 지도 캡처용 전체 탐사
			for y in range(HOME_ANCHOR.y, HOME_ANCHOR.y + 4):
				for x in range(HOME_ANCHOR.x, HOME_ANCHOR.x + 5):
					objects[Vector2i(x, y)] = {"kind": "house", "hp": 0}
			objects.erase(HOME_SITE)
	_sync_village_npcs()
	_spawn_objects()
	_apply_season_visuals()
	if GameData.quest.is_empty():
		GameData.make_daily_quest()

	_setup_fade(loaded.size() > 0 or _shot_path != "")
	# 신규 게임은 _show_intro가 스토리 동안 화면을 가렸다가 직접 페이드한다


func _setup_fade(animate_in: bool) -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1 if animate_in else 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	if animate_in:
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 0.0, 0.5)


func _load_textures() -> void:
	for n in TEXTURE_NAMES:
		tex[n] = load("res://assets/sprites/%s.png" % n)


func _setup_camera() -> void:
	var cam: Camera2D = player.get_node("Camera")
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * TILE
	cam.limit_bottom = MAP_H * TILE


# ---- 맵 ----

func _build_map() -> void:
	grid = []
	objects = {}
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			# crop_day = 누적 성장 시간(게임 분), wet_min = 남은 젖음 시간(게임 분)
			row.append({"ground": "grass", "watered": false, "wet_min": 0.0,
				"crop_id": "", "crop_day": 0.0, "dead": false, "half_fed": false})
		grid.append(row)

	# 연못들 (숲/깊은 숲) — 시작 부지의 연못은 없앴다
	for y in range(28, 35):
		for x in range(45, 53):
			grid[y][x].ground = "water"
	for y in range(34, 36):          # 강변 부지의 강
		for x in range(60, 90):
			grid[y][x].ground = "water"
	for y in range(48, 54):          # 깊은 숲 연못
		for x in range(70, 79):
			grid[y][x].ground = "water"

	_build_village()

	# 농장 -> 마을 공용 길
	for y in range(ROAD.position.y, ROAD.end.y):
		for x in range(ROAD.position.x, ROAD.end.x):
			grid[y][x].ground = "path"

	# 출하 상자(농장) + 동굴
	objects[Vector2i(9, 4)] = {"kind": "bin", "hp": 0}
	objects[CAVE_POS] = {"kind": "cave", "hp": 0}
	objects[WORLDTREE_POS] = {"kind": "worldtree", "hp": 0}

	# 세계의 끝을 두르는 나무 (그림 폭에 맞춰 4칸 간격 — 서로 겹치지 않는다)
	for x in MAP_W:
		if x % 4 == 0 and not objects.has(Vector2i(x, 0)):
			objects[Vector2i(x, 0)] = {"kind": "tree", "hp": TREE_HP}
		if x % 4 == 0:
			objects[Vector2i(x, MAP_H - 1)] = {"kind": "tree", "hp": TREE_HP}
	for y in MAP_H:
		if y % 4 == 0 and not objects.has(Vector2i(0, y)):
			objects[Vector2i(0, y)] = {"kind": "tree", "hp": TREE_HP}
		if y % 4 == 0 and not objects.has(Vector2i(MAP_W - 1, y)):
			objects[Vector2i(MAP_W - 1, y)] = {"kind": "tree", "hp": TREE_HP}

	# 흩어진 나무/돌 (결정적 해시 배치, 남동쪽 깊은 숲은 더 빽빽하게)
	var deep_rect := Rect2i(45, 40, 45, 20)
	for y in range(1, MAP_H - 1):
		for x in range(1, MAP_W - 1):
			var pos := Vector2i(x, y)
			if objects.has(pos) or grid[y][x].ground != "grass":
				continue
			if x >= 1 and x <= 10 and y >= 0 and y <= 6:
				continue  # 집/출하상자 주변은 비워둔다
			if abs(x - START_TILE.x) <= 3 and abs(y - START_TILE.y) <= 3:
				continue  # 시작 지점 주변도 비워둔다
			if VILLAGE_REGION.has_point(pos) or ROAD.has_point(pos):
				continue  # 마을/길은 비워둔다
			var h := _hash01(x * 3 + 7, y * 5 + 11)
			if deep_rect.has_point(pos):
				# 깊은 숲은 나무를 많이 두되, 그림이 겹치지 않는 선까지만 채운다
				if h < 0.30:
					if _nature_clear(pos, "tree"):
						objects[pos] = {"kind": "tree", "hp": TREE_HP}
				elif h < 0.40:
					if _nature_clear(pos, "rock"):
						objects[pos] = {"kind": "rock", "hp": ROCK_HP}
			elif h < 0.06:
				if _nature_clear(pos, "tree"):
					objects[pos] = {"kind": "tree", "hp": TREE_HP}
			elif h < 0.12:
				if _nature_clear(pos, "rock"):
					objects[pos] = {"kind": "rock", "hp": ROCK_HP}


# 교진 마을: 건물은 하나도 짓지 않는다.
# 넓은 중앙 광장 + 사방으로 뻗은 길 + 나중에 건물이 들어설 빈 부지만 만든다.
func _build_village() -> void:
	# 마을을 가로지르는 큰길 (서쪽 입구 -> 동쪽)
	for y in range(MAIN_STREET_Y, MAIN_STREET_Y + 2):
		for x in range(60, 87):
			grid[y][x].ground = "path"
	# 중앙 광장 (아주 넓은 평지)
	for y in range(PLAZA.position.y, PLAZA.end.y):
		for x in range(PLAZA.position.x, PLAZA.end.x):
			grid[y][x].ground = "path"
	# 광장에서 사방으로 퍼져나가는 길
	for x in [74, 75]:
		for y in range(1, PLAZA.position.y):         # 북쪽 길
			grid[y][x].ground = "path"
		for y in range(PLAZA.end.y, DOCK_Y + 1):     # 남쪽 길 (강가까지)
			grid[y][x].ground = "path"
	for y in [16, 17]:
		for x in range(61, PLAZA.position.x):        # 서쪽 길
			grid[y][x].ground = "path"
		for x in range(PLAZA.end.x, 87):             # 동쪽 길
			grid[y][x].ground = "path"
	# 광장 한가운데 분수
	for y in range(FOUNTAIN.position.y, FOUNTAIN.end.y):
		for x in range(FOUNTAIN.position.x, FOUNTAIN.end.x):
			grid[y][x].ground = "water"

	# 마을 바깥쪽을 따라 흐르는 강 (광장을 가로막지 않는다)
	for y in range(VILLAGE_RIVER_Y, VILLAGE_RIVER_Y + 2):
		for x in range(46, 89):
			grid[y][x].ground = "water"
	for x in [87, 88]:
		for y in range(1, VILLAGE_RIVER_Y):
			grid[y][x].ground = "water"
	# 마을 남쪽 끝 낚시터: 강가 마당 + 강 위로 뻗은 부두 (시설은 없다)
	for x in range(72, 78):
		grid[DOCK_Y][x].ground = "path"
	for x in range(73, 77):
		grid[VILLAGE_RIVER_Y][x].ground = "path"
	# 강 건너 남쪽 부지로 이어지는 작은 다리
	for x in [63, 64]:
		for y in range(VILLAGE_RIVER_Y, VILLAGE_RIVER_Y + 2):
			grid[y][x].ground = "path"

	# 집터(스토리 1 완료 후 직접 짓는다) + 광장 게시판 + 최소한의 장식
	objects[HOME_SITE] = {"kind": "housesite", "hp": 0}
	objects[BOARD_POS] = {"kind": "board", "hp": 0}
	objects[FOUNTAIN_DECO] = {"kind": "deco_fountain", "hp": 0}
	for p: Vector2i in PLAZA_LAMPS:
		objects[p] = {"kind": "deco_lamp", "hp": 0}
	for p: Vector2i in PLAZA_BENCHES:
		objects[p] = {"kind": "deco_bench", "hp": 0}
	# 마을 외곽에만 나무를 둔다 (생활 공간 안에는 나무/돌을 두지 않는다)
	for x in range(60, 89):
		for y in [1, 29]:
			var rim := Vector2i(x, y)
			if grid[y][x].ground == "grass" and not objects.has(rim) \
					and _hash01(x * 5 + 3, y * 7 + 2) < 0.9 and _nature_clear(rim, "tree"):
				objects[rim] = {"kind": "tree", "hp": TREE_HP}


# 자연물은 타일보다 훨씬 크게 그려진다. 그림이 서로 겹치지 않도록,
# 두 오브젝트가 요구하는 간격 중 더 큰 값을 적용해 배치 가능 여부를 판단한다.
func _nature_clear(pos: Vector2i, kind: String, override_dist := -1) -> bool:
	var need_self: int = override_dist if override_dist >= 0 \
		else int(NATURE_CLEAR.get(kind, 1))
	for dy in range(-NATURE_CLEAR_MAX, NATURE_CLEAR_MAX + 1):
		for dx in range(-NATURE_CLEAR_MAX, NATURE_CLEAR_MAX + 1):
			var p := pos + Vector2i(dx, dy)
			if p == pos or not objects.has(p):
				continue
			var k: String = objects[p].kind
			if not NATURE_CLEAR.has(k):
				continue
			if override_dist < 0 and (kind == "tree" or k == "tree"):
				# 나무는 "옆으로 나란히" 놓일 때만 지저분하게 겹친다.
				# 앞뒤로 겹치는 건 앞 나무가 뒤를 가려 주므로 깊은 숲처럼 보인다.
				if absi(dx) <= TREE_DX and absi(dy) <= TREE_DY:
					return false
				continue
			var need: int = need_self if override_dist >= 0 \
				else maxi(need_self, int(NATURE_CLEAR[k]))
			if maxi(absi(dx), absi(dy)) <= need:
				return false
	return true


# 빽빽한 숲에서는 앞쪽(아래) 나무가 주인공을 가린다.
# 가리는 나무만 잠깐 비치게 해서 자기 위치를 항상 볼 수 있게 한다.
var _faded_trees: Array = []


func _update_tree_fade() -> void:
	for spr in _faded_trees:
		if is_instance_valid(spr):
			spr.modulate.a = 1.0
	_faded_trees.clear()
	if player == null or interior.visible or cave.visible:
		return
	var t := player_tile()
	for dy in range(0, 4):
		for dx in range(-2, 3):
			var p := t + Vector2i(dx, dy)
			if not obj_nodes.has(p) or not objects.has(p):
				continue
			if objects[p].kind != "tree":
				continue
			var node: Node2D = obj_nodes[p]
			if node.position.y <= player.position.y:
				continue  # 뒤쪽 나무는 주인공을 가리지 않는다
			var spr: Sprite2D = node.get_child(0)
			spr.modulate.a = 0.45
			_faded_trees.append(spr)


func _spawn_npc(npc_id: String, tile: Vector2i) -> void:
	var n: Node2D = preload("res://scripts/npc.gd").new()
	n.main = self
	n.id = npc_id
	n.region = VILLAGE_REGION
	n.position = Vector2(tile.x * TILE + 16, tile.y * TILE + 16)
	npcs.append(n)
	world.add_child(n)


func _sync_village_npcs() -> void:
	# 건물이 생기면 그 건물의 주인이 마을에 나타난다 (없는 건물의 주인은 아직 없다)
	for pid: String in VILLAGE_NPC:
		if not GameData.village_built.has(pid):
			continue
		var nid: String = VILLAGE_NPC[pid]
		var found := false
		for n in npcs:
			if n.id == nid:
				found = true
				break
		if found:
			continue
		var a: Vector2i = VILLAGE_PLOTS[pid].anchor
		_spawn_npc(nid, Vector2i(a.x + 2, a.y + 4))  # 자기 건물 문 앞


func _spawn_objects() -> void:
	for n in obj_nodes.values():
		n.queue_free()
	obj_nodes.clear()
	tree_sprites.clear()
	for pid: String in GameData.village_built:
		if VILLAGE_PLOTS.has(pid):
			_spawn_house_node(VILLAGE_PLOTS[pid].anchor)  # 지은 뒤에만 존재
	if GameData.house_lv >= 1:
		_spawn_house_node(HOME_ANCHOR)  # 지은 뒤에만 존재
	for pos: Vector2i in objects:
		if objects[pos].kind != "house":
			_spawn_object_node(pos, objects[pos].kind)
	_apply_story_visibility()


func _spawn_house_node(anchor: Vector2i) -> void:
	var hn := _make_object(tex["house"],
		Vector2(anchor.x * TILE, (anchor.y + 4) * TILE), Vector2(0, -256))
	var hspr: Sprite2D = hn.get_child(0)
	hspr.scale = Vector2(0.8, 0.8)  # 문이 캐릭터와 1:1이 되는 크기
	hspr.offset.x = 80.0 / 0.8 - 160.0
	obj_nodes[anchor] = hn
	world.add_child(hn)


# 종류별 시각 배율. 텍스처가 2배 해상도(EPX)라서 실제 곱은 여기의 절반이 적용된다.
const OBJECT_SCALES := {
	# 주인공(약 3타일 키)에 맞춘 크기. 그림이 타일보다 크므로 배치 간격도 띄운다.
	"tree": 3.0, "rock": 1.9, "bigrock": 4.0, "cave": 2.2, "worldtree": 2.6,
	"barn": 1.8, "forage_berry": 1.5, "forage_herb": 1.5,
	"deco_fountain": 1.4, "deco_lamp": 1.15, "deco_bench": 1.15,
}
# 자연물 배치 간격(타일). 실제 그려지는 폭에서 뽑았다.
#
# 나무는 "옆으로 나란히" 있을 때만 그림이 지저분하게 겹친다.
# 앞뒤(위아래)로 겹치는 것은 y정렬로 앞 나무가 뒤 나무를 가려 주므로
# 오히려 깊은 숲처럼 보인다. 그래서 가로 간격만 넓게 잡고 세로는 촘촘히 둔다.
const TREE_DX := 4   # 가로로 4칸 이내이면서
const TREE_DY := 2   # 세로로 2칸 이내면 겹쳐 보인다 -> 금지
const NATURE_CLEAR := {
	"tree": 4, "bigrock": 3, "rock": 2, "forage_berry": 2, "forage_herb": 2,
}
const NATURE_CLEAR_MAX := 4
const OBJECT_TEX_DENSITY := 2.0  # 농장 오브젝트 텍스처 밀도 (월드 크기 유지용)

# 오브젝트가 실제로 막는 크기(픽셀). 기준 칸(32px) 밖으로 얼마나 더 넓히는지다.
# 그림이 타일보다 훨씬 크기 때문에, 칸 하나만 막으면 캐릭터가 나무 밑동/바위 속으로
# 파고들어 겹쳐 보인다. 그래서 그림 크기에 맞춰 밑동 판정을 넓힌다.
# 다만 한 칸짜리 통로는 계속 지나갈 수 있어야 하므로(플레이어 몸 폭 12px),
# 한 변에 6px(양쪽 12px, 남는 폭 20px)을 넘지 않게 잡는다.
const OBJECT_PAD := {
	"tree": Vector2(6, 6), "bigrock": Vector2(6, 6), "rock": Vector2(5, 4),
	"cave": Vector2(6, 4), "worldtree": Vector2(6, 4), "barn": Vector2(4, 3),
	"forage_berry": Vector2(3, 2), "forage_herb": Vector2(3, 2),
	"deco_fountain": Vector2(5, 4), "deco_lamp": Vector2(3, 3), "deco_bench": Vector2(4, 3),
	"bin": Vector2(3, 2), "board": Vector2(3, 2), "sign": Vector2(3, 2),
}


func _spawn_object_node(pos: Vector2i, kind: String) -> void:
	var offset := Vector2(0, -64)
	var texture: Texture2D
	match kind:
		"tree":
			texture = tex["tree_01"]  # 실제 상태별 텍스처는 _refresh_tree_sprite가 결정
			offset = Vector2(0, -100)
		"rock":
			texture = tex["rock"]
		"bigrock":
			texture = tex["rock"]  # 같은 바위 그림을 크게 그린다 (퀘스트 5)
		"bin":
			texture = tex["bin"]
		"housesite":
			texture = tex["sign"]  # 집터 표지판
		"board":
			texture = tex["board"]
		"sign":
			texture = tex["sign"]
		"cave":
			texture = tex["cave"]
			offset = Vector2(0, -100)
		"fence":
			texture = tex["fence"]
		"sprinkler":
			texture = tex["sprinkler"]
		"forage_berry":
			texture = tex["forage_berry"]
		"forage_herb":
			texture = tex["forage_herb"]
		"worldtree":
			texture = tex["cave"]
			offset = Vector2(0, -100)
		"barn":
			texture = tex["barn"]
			offset = Vector2(0, -88)
		"barn_block":
			pass  # 축사 오른쪽 칸 (통행 차단용, 그림 없음)
		"deco_fountain":
			texture = tex["deco_fountain"]  # 광장 분수 조형물 (분수 한가운데)
			offset = Vector2(0, -160)
		"deco_lamp":
			texture = tex["deco_lamp"]
			offset = Vector2(0, -128)
		"deco_bench":
			texture = tex["deco_bench"]
	var node := _make_object(texture, Vector2(pos.x * TILE, (pos.y + 1) * TILE), offset)
	# 큰 캐릭터에 맞춰 자연물은 타일보다 크게 그린다 (충돌 칸은 1칸 유지)
	var sc: float = OBJECT_SCALES.get(kind, 1.0) / OBJECT_TEX_DENSITY
	if kind == "tree":
		# 크기 편차는 5칸 간격 안에서 겹치지 않는 범위까지만 (숲에서는 덩어리감을 준다)
		sc *= 0.82 + _hash01(pos.x * 7 + 3, pos.y * 13 + 1) * 0.26
	elif kind == "rock":
		# 큰 돌과 작은 돌이 섞이도록
		sc *= 0.65 + _hash01(pos.x * 5 + 1, pos.y * 9 + 4) * 0.6
	if texture != null:
		var spr: Sprite2D = node.get_child(0)
		if kind == "tree":
			spr.flip_h = _hash01(pos.x * 3 + 5, pos.y * 11 + 7) > 0.5  # 좌우 변형
		spr.scale = Vector2(sc, sc)
		spr.offset.x = 16.0 / sc - texture.get_width() / 2.0
		if kind == "deco_fountain":
			spr.offset.x += 16.0 / sc  # 4칸짜리 분수의 정중앙에 세운다
	obj_nodes[pos] = node
	if kind == "tree":
		tree_sprites.append(node.get_child(0))
	world.add_child(node)


# 나무 상태별 이미지 규칙 (고정 매핑):
# 어린 나무=tree_15 / 다 자란 나무=tree_01 / 1회 벌목=tree_06 / 2회 벌목=tree_09
func _refresh_tree_sprite(pos: Vector2i) -> void:
	if not obj_nodes.has(pos) or not objects.has(pos):
		return
	if objects[pos].kind != "tree":
		return
	var spr: Sprite2D = obj_nodes[pos].get_child(0)
	var hp := int(objects[pos].hp)
	if hp >= TREE_HP:
		if bool(objects[pos].get("young", false)):
			spr.texture = tex["tree_15"]  # 아직 덜 자란 어린 나무
		elif objects[pos].get("apple", false):
			spr.texture = tex["tree_13"]  # 일부 나무에만 사과 3개
		else:
			spr.texture = tex["tree_01"]  # 완전히 자란 기본 나무
	elif hp == 2:
		spr.texture = tex["tree_06"]
	else:
		spr.texture = tex["tree_09"]


func _remove_object(pos: Vector2i) -> void:
	objects.erase(pos)
	if obj_nodes.has(pos):
		var node: Node2D = obj_nodes[pos]
		var sprite := node.get_child(0)
		tree_sprites.erase(sprite)
		node.queue_free()
		obj_nodes.erase(pos)


func _place_object(pos: Vector2i, kind: String, hp: int) -> void:
	objects[pos] = {"kind": kind, "hp": hp}
	_spawn_object_node(pos, kind)


func _make_object(texture: Texture2D, base_pos: Vector2, offset: Vector2) -> Node2D:
	# y 정렬 기준점(밑변)에 노드를 두고, 스프라이트는 위로 올려 그린다.
	var node := Node2D.new()
	node.position = base_pos
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.offset = offset
	node.add_child(s)
	return node


func _apply_season_visuals() -> void:
	for pos: Vector2i in obj_nodes:
		if objects.has(pos) and objects[pos].kind == "tree":
			_refresh_tree_sprite(pos)  # 손상 단계(잎 없음/반파)를 유지한 채 계절 반영
	Sound.play_bgm(GameData.season_key())
	queue_redraw()


func weather_now() -> int:
	if _weather_override >= 0:
		return _weather_override
	return GameData.weather_today()


func _hash01(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h) / 4294967295.0


# ---- 통행/타겟 ----

func is_passable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return false
	if grid[t.y][t.x].ground == "water":
		return false
	if objects.has(t):
		return false
	if not _tile_accessible(t):
		return false  # 해금하지 않은 부지는 들어갈 수 없다
	return true


func _tile_accessible(t: Vector2i) -> bool:
	return VILLAGE_REGION.has_point(t) or ROAD.has_point(t) \
		or GameData.is_tile_owned(t.x, t.y)


func is_passable_px(p: Vector2) -> bool:
	var t := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	if not is_passable(t):
		return false
	# 옆 칸 오브젝트라도 그림(밑동) 안쪽이면 들어갈 수 없다 — 캐릭터가 겹쳐 보이지 않게
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n := t + Vector2i(dx, dy)
			if not objects.has(n):
				continue
			var pad: Vector2 = OBJECT_PAD.get(objects[n].kind, Vector2.ZERO)
			if pad == Vector2.ZERO:
				continue
			var r := Rect2(n.x * TILE - pad.x, n.y * TILE - pad.y,
				TILE + pad.x * 2.0, TILE + pad.y * 2.0)
			if r.has_point(p):
				return false
	return true


func is_passable_px_loose(p: Vector2) -> bool:
	# 끼임 탈출용: 설치물/나무 충돌은 무시하되
	# 물·맵 밖·미구매 부지는 어떤 경우에도 통과할 수 없다
	var t := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return false
	if grid[t.y][t.x].ground == "water":
		return false
	return _tile_accessible(t)


func player_tile() -> Vector2i:
	return Vector2i(int(floor(player.position.x / TILE)), int(floor(player.position.y / TILE)))


# 마우스가 플레이어 주변 8칸 위에 있으면 그 칸이 타겟 (대각선 선택 가능)
var _mouse_target := Vector2i(-999, -999)
# 좌클릭으로 고정한 선택 대상 (E키/더블클릭 상호작용의 기준)
var _sel_target := Vector2i(-999, -999)


func _update_mouse_target() -> void:
	if player == null:
		_mouse_target = Vector2i(-999, -999)
		return
	var mp := get_global_mouse_position()
	var t := Vector2i(int(floor(mp.x / TILE)), int(floor(mp.y / TILE)))
	var d := t - player_tile()
	if d != Vector2i.ZERO and absi(d.x) <= 1 and absi(d.y) <= 1:
		_mouse_target = t
	else:
		_mouse_target = Vector2i(-999, -999)


func target_tile() -> Vector2i:
	if _target_override.x != -999:
		return _target_override  # 원격 플레이어 행동 처리 중
	if _sel_target.x != -999:
		var d := _sel_target - player_tile()
		if absi(d.x) <= 1 and absi(d.y) <= 1:
			return _sel_target  # 좌클릭으로 고정한 선택
		_sel_target = Vector2i(-999, -999)  # 멀어지면 선택 해제
	if _mouse_target.x != -999:
		return _mouse_target
	var dirs := {
		"down": Vector2i(0, 1), "up": Vector2i(0, -1),
		"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
	}
	return player_tile() + dirs[player.dir]


func _current_perp() -> Vector2i:
	if _perp_override != Vector2i.ZERO:
		return _perp_override
	return Vector2i(0, 1) if player.dir in ["left", "right"] else Vector2i(1, 0)


func can_use_tile(t: Vector2i) -> bool:
	# 마을/길은 공용, 나머지는 부지 소유 여부를 따른다
	return _tile_accessible(t)


func ui_open() -> bool:
	return story_cutscene or shop.visible or summary.visible or sleep_dialog.visible \
		or fishing_ui.visible or dialog.visible or map_ui.visible \
		or inventory_ui.visible or interior.visible or cave.visible \
		or cooking_ui.visible or quest_ui.visible or note_ui.visible \
		or stats_ui.visible or _name_layer != null or _gift_layer != null \
		or (story_layer != null and story_layer.visible)


func interior_only_open() -> bool:
	# 집/동굴 안에 있을 때는 시간이 흐른다 (다른 창이 겹치면 정지)
	return (interior.visible or cave.visible) and not (shop.visible
		or summary.visible or sleep_dialog.visible or dialog.visible
		or map_ui.visible or inventory_ui.visible)


func request_sleep() -> void:
	if not GameData.has_bed:
		hud.show_message("잘 침대가 없다. 침대 자리에서 침대를 만들자 (목재 %d)." %
			GameData.BED_WOOD)
		return
	if Net.is_guest():
		hud.show_message("하루는 호스트가 잠자리에 들어야 넘어간다.")
	else:
		sleep_dialog.popup_centered()


# ---- 도구/상호작용 ----

func set_tool(t: String) -> void:
	if not GameData.is_tool_unlocked(t):
		hud.show_message("아직 열리지 않은 도구다. 목표를 달성하면 해금된다!")
		return
	if not GameData.tool_slots.has(t):
		# 획득 -> 가방(I)에서 슬롯 장착 -> 숫자키 선택 -> 사용 순서를 지킨다
		hud.show_message("가방(I)에서 빠른 슬롯에 장착해야 쓸 수 있다!")
		return
	if t != "rod":
		cancel_fishing()
	GameData.tool = t


# ---- 낚시 ----

func cancel_fishing() -> void:
	fishing_state = ""


func _start_fishing() -> void:
	var t := target_tile()
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H \
			or grid[t.y][t.x].ground != "water":
		hud.show_message("물가를 보고 낚싯대를 던지자.")
		return
	if not can_use_tile(t):
		hud.show_message("아직 구입하지 않은 부지의 물이다. 표지판(E)에서 구입하자!")
		return
	fishing_state = "waiting"
	fishing_timer = randf_range(1.5, 4.0) * GameData.fish_wait_mult()
	Sound.play_sfx("sfx_cast")


func _update_fishing(delta: float) -> void:
	if fishing_state == "waiting":
		fishing_timer -= delta
		if fishing_timer <= 0.0:
			fishing_state = "bite"
			fishing_timer = 0.9
			Sound.play_sfx("sfx_bite")
	elif fishing_state == "bite":
		fishing_timer -= delta
		if fishing_timer <= 0.0:
			fishing_state = ""
			hud.show_message("물고기가 도망갔다...")


# 축사 건설: 농장 고정 위치에 세워진다 (동물 16마리 + 굳은 날씨 자동 배부름)
func build_barn() -> void:
	if GameData.barn_built:
		return
	GameData.barn_built = true
	GameData.money -= GameData.BARN_COST_MONEY
	GameData.wood -= GameData.BARN_COST_WOOD
	_place_object(BARN_POS, "barn", 0)
	objects[BARN_POS + Vector2i(1, 0)] = {"kind": "barn_block", "hp": 0}
	Sound.play_sfx("sfx_place")
	hud.show_message("축사 완공! 동물을 %d마리까지 키울 수 있다." % GameData.BARN_MAX_ANIMALS)
	if Net.is_host():
		_broadcast_stats()


# 전설 재료 획득 (판매 불가, 최후의 연금술 재료 — 연구 노트에 기록)
func gain_legend(id: String) -> void:
	if int(GameData.items[id]) > 0:
		return  # 각 전설 재료는 하나면 충분하다
	gain_item(id, 1)
	Sound.play_sfx("sfx_catch")
	hud.show_message("[전설 재료] %s 획득! 연구 노트(N)에 기록됐다." % GameData.ITEMS[id].name)


# 숙련도 경험치를 주고, 레벨업하면 하단에 알린다
var float_texts: Array = []  # 경험치 획득 플로팅 텍스트 [{text, pos, t}]


func gain_skill(id: String, amount: float) -> void:
	if GameData.is_night():
		amount = maxf(1.0, amount * 0.5)  # 밤에는 채집/작업 효율이 떨어진다
	float_texts.append({"text": "+%d %s" % [int(amount), GameData.SKILLS[id].name],
		"pos": player.position + Vector2(0, -100), "t": 0.0})
	var lv := GameData.add_skill_xp(id, amount)
	if lv > 0:
		Sound.play_sfx("sfx_catch")
		hud.show_message("[능력치] %s Lv.%d 달성! (%s)" %
			[GameData.SKILLS[id].name, lv, GameData.SKILLS[id].effect])
	if lv > 0 and Net.is_host():
		_broadcast_stats()


func _on_fishing_finished(success: bool) -> void:
	if success:
		var id: String = pending_fish[0]
		var def: Dictionary = GameData.ITEMS[id]
		GameData.items[id] += 1
		GameData.fish_caught[id] = int(GameData.fish_caught.get(id, 0)) + 1
		GameData.today_harvest += 1
		Sound.play_sfx("sfx_catch")
		spawn_particles(player_tile(), "sparkle")
		hud.show_message("%s를 낚았다! (%dG)" % [def.name, def.sell])
		tutorial_notify("fish")
		gain_skill("fish", 10.0)
		if Net.is_guest():
			# 로컬 반영분은 호스트 통계 브로드캐스트로 덮어써 수렴한다
			GameData.items[id] -= 1
			GameData.fish_caught[id] = int(GameData.fish_caught[id]) - 1
			_req_gain.rpc_id(1, id, 1)
		elif Net.is_host():
			_broadcast_stats()
	else:
		Sound.play_sfx("sfx_miss")
		hud.show_message("놓쳤다...")


func _affected_tiles(base: Vector2i) -> Array:
	# 장비 능력치의 「범위」를 그대로 쓴다 (1=1칸 / 2=전방 3칸 / 3=3x3)
	var lvl := int(GameData.tool_stat(GameData.tool, "reach"))
	if lvl >= 3:
		var out := []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				out.append(base + Vector2i(dx, dy))
		return out
	if lvl >= 2:
		var perp := _current_perp()
		return [base, base + perp, base - perp]
	return [base]


func use_tool() -> void:
	# 도구는 슬롯에 장착하고 직접 선택해 손에 든 상태여야만 쓸 수 있다 (맨손 수확 제외)
	if not _remote_acting and GameData.tool != "hand" \
			and not GameData.tool_slots.has(GameData.tool):
		hud.show_message("가방(I)에서 도구를 슬롯에 장착하고 숫자키로 선택하자!")
		return
	# 밤 채집 패널티: 어두워서 몸이 무겁고(기력 소모) 손이 무디다 (숙련도 절반)
	if not _remote_acting and GameData.is_night() and GameData.tool != "hand":
		# 밤에는 장비의 「기력 소모」만큼 힘이 더 든다
		GameData.energy = maxf(0.0,
			GameData.energy - maxf(1.0, GameData.tool_stat(GameData.tool, "stamina")))
		if randf() < 0.15:
			hud.show_message("어두워서 일이 손에 잡히지 않는다... 슬슬 돌아가서 쉬자.")
	var t := target_tile()
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return
	var cell: Dictionary = grid[t.y][t.x]
	var obj: Variant = objects.get(t)
	var seed_now := GameData.current_seed_id()

	match GameData.tool:
		"hoe":
			if cell.crop_id != "" and cell.dead:
				# 시든 작물 정리
				cell.crop_id = ""
				cell.crop_day = 0
				cell.dead = false
				cell.half_fed = false
				Sound.play_sfx("sfx_hoe", 0.1)
				hud.show_message("시든 작물을 정리했다.")
			elif obj != null:
				hud.show_message("여기는 갈 수 없다.")
				return
			elif cell.ground == "soil" and cell.crop_id == "":
				cell.ground = "grass"
				cell.watered = false
				cell.wet_min = 0.0
				Sound.play_sfx("sfx_hoe", 0.1)
			else:
				var worked := false
				for pos: Vector2i in _affected_tiles(t):
					if pos.x < 0 or pos.y < 0 or pos.x >= MAP_W or pos.y >= MAP_H:
						continue
					var c: Dictionary = grid[pos.y][pos.x]
					if objects.has(pos) or c.ground != "grass":
						continue
					c.ground = "soil"
					if weather_now() == GameData.WEATHER_RAIN:
						_wet(c, WET_ALL_DAY)
					spawn_particles(pos, "dirt")
					worked = true
				if worked:
					Sound.play_sfx("sfx_hoe", 0.1)
					tutorial_notify("till")
		"water":
			var worked := false
			var revived := false
			for pos: Vector2i in _affected_tiles(t):
				if pos.x < 0 or pos.y < 0 or pos.x >= MAP_W or pos.y >= MAP_H:
					continue
				var c: Dictionary = grid[pos.y][pos.x]
				var was_thirsty := _crop_thirsty(c)
				if c.ground == "soil" and not objects.has(pos) \
						and (float(c.wet_min) < WET_MANUAL - 1.0 or was_thirsty):
					_wet(c, WET_MANUAL)
					spawn_particles(pos, "water")
					worked = true
					revived = revived or was_thirsty
			if worked:
				Sound.play_sfx("sfx_water", 0.1)
				tutorial_notify("water")
				if revived:
					hud.show_message("물을 머금은 작물이 다시 자라기 시작했다!", 4.0)
			elif grid[t.y][t.x].ground != "soil":
				hud.show_message("물을 줄 곳이 아니다.")
		"seed":
			var id := _forced_seed if _forced_seed != "" else GameData.current_seed_id()
			if id == "":
				hud.show_message("씨앗이 없다. 상점(B)에서 사자.")
				return
			if cell.ground != "soil" or obj != null:
				hud.show_message("먼저 호미로 밭을 갈자.")
				return
			if cell.crop_id != "":
				hud.show_message("이미 작물이 자라고 있다.")
				return
			var def: Dictionary = GameData.CROPS[id]
			if GameData.season() not in def.seasons:
				hud.show_message("%s은(는) 지금 계절에 자라지 않는다." % def.name)
				return
			GameData.seeds[id] -= 1
			cell.crop_id = id
			cell.crop_day = 0.0
			cell.dead = false
			cell.half_fed = false
			if weather_now() == GameData.WEATHER_RAIN:
				_wet(cell, WET_ALL_DAY)
			Sound.play_sfx("sfx_seed", 0.1)
			spawn_particles(t, "seed")
			tutorial_notify("plant")
			gain_skill("farm", 2.0)
		"hand":
			if cell.crop_id != "":
				if cell.dead:
					hud.show_message("시들어버렸다... 호미로 정리하자.")
					return
				var def: Dictionary = GameData.CROPS[cell.crop_id]
				if float(cell.crop_day) >= _grow_total(def):
					var quality := GameData.roll_quality(GameData.total_luck())
					GameData.add_produce(cell.crop_id, quality)
					GameData.today_harvest += 1
					match quality:
						2:
							hud.show_message("금빛 %s 수확! (판매가 %dG)" %
								[def.name, int(def.sell_price * 1.5)])
						1:
							hud.show_message("은빛 %s 수확! (판매가 %dG)" %
								[def.name, int(def.sell_price * 1.25)])
						_:
							hud.show_message("%s 수확! (판매가 %dG)" % [def.name, def.sell_price])
					cell.crop_id = ""
					cell.crop_day = 0.0
					cell.half_fed = false
					Sound.play_sfx("sfx_harvest")
					spawn_particles(t, "sparkle")
					tutorial_notify("harvest")
					gain_skill("farm", 8.0)
					if int(GameData.crops_harvested.get(cell.crop_id, 0)) == 0:
						hud.show_message("연구 노트에 '%s' 기록이 추가됐다! (N)" % def.name)
					GameData.crops_harvested[cell.crop_id] = \
						int(GameData.crops_harvested.get(cell.crop_id, 0)) + 1
					if randf() < 0.02:
						gain_legend("gold_crop")
				else:
					hud.show_message("아직 다 자라지 않았다.")
		"axe":
			if obj == null:
				hud.show_message("벨 것이 없다.")
				return
			if obj.kind == "tree":
				if bool(obj.get("young", false)):
					hud.show_message("아직 어린 나무다. 다 자라면 벨 수 있다.")
					return
				obj.hp -= int(GameData.tool_stat("axe", "power"))
				Sound.play_sfx("sfx_chop", 0.15)
				spawn_particles(t, "wood")
				_refresh_tree_sprite(t)
				if obj.hp <= 0:
					_remove_object(t)
					# 숲길을 막고 있던 나무는 다시 자라지 않는다 (길이 도로 막히면 안 된다)
					var story_gate: bool = GameData.story_phase != "done" \
						and STORY_GATE_XS.has(t.x) \
						and t.y >= STORY_ROAD_Y0 and t.y <= STORY_ROAD_Y1
					if not story_gate:
						GameData.tree_regrow.append([t.x, t.y, 1])  # 다음 날 어린 나무
					var wood_got := WOOD_PER_TREE
					if randf() < GameData.bonus_drop_chance("forest"):
						wood_got += 1
					GameData.wood += wood_got
					GameData.trees_chopped += 1
					hud.show_message("나무를 베었다! 목재 +%d" % wood_got)
					# 길목을 뚫었다면 진행도를 갱신한다
					if story_gate:
						var before_gates := int(GameData.story_gates_left)
						_refresh_story_gates()
						if GameData.story_gates_left < before_gates:
							if GameData.story_gates_left > 0:
								hud.show_message("길이 뚫렸다! (남은 길목 %d곳)"
									% GameData.story_gates_left, 4.0)
							else:
								hud.show_message("숲길이 끝까지 열렸다!", 4.0)
					_story_tree_chopped()
					tutorial_notify("chop")
					gain_skill("forest", 3.0)
					# 15그루째: 우체부 아저씨가 능력치 창(U)을 알려준다
					if GameData.u_intro_state == 0 and GameData.trees_chopped >= 15 \
							and _postman != null and _postman_state == "follow":
						GameData.u_intro_state = 1
						get_tree().create_timer(1.0).timeout.connect(_start_u_intro_dialog)
					if randf() < 0.02:
						gain_legend("world_branch")
				elif obj.hp == 2:
					hud.show_message("나무를 베었다! (1/%d)" % TREE_HP)
				else:
					hud.show_message("나무가 쓰러지기 직전이다! (2/%d)" % TREE_HP)
			elif obj.kind == "fence":
				if bool(obj.get("fixed", false)):
					hud.show_message("단단히 박힌 울타리다. 길을 따라 가야 한다.")
					return
				_remove_object(t)
				GameData.wood += GameData.FENCE_COST_WOOD
				Sound.play_sfx("sfx_place")
				hud.show_message("울타리를 회수했다.")
			else:
				hud.show_message("도끼로 벨 수 없다.")
		"pickaxe":
			if obj == null:
				hud.show_message("캘 것이 없다.")
				return
			if obj.kind == "rock":
				obj.hp -= int(GameData.tool_stat("pickaxe", "power"))
				Sound.play_sfx("sfx_pick", 0.15)
				spawn_particles(t, "stone")
				if obj.hp <= 0:
					_remove_object(t)
					var stone_got := STONE_PER_ROCK
					if randf() < GameData.bonus_drop_chance("mine"):
						stone_got += 1
					GameData.stone += stone_got
					hud.show_message("돌을 캤다! 석재 +%d" % stone_got)
					tutorial_notify("mine")
					gain_skill("mine", 6.0)
				else:
					hud.show_message("돌을 내리쳤다. (%d/%d)" % [ROCK_HP - obj.hp, ROCK_HP])
			elif obj.kind == "bigrock":
				# 퀘스트 5: 길을 막은 커다란 바위 (여러 번 캐야 부서진다)
				obj.hp -= 1
				Sound.play_sfx("sfx_pick", 0.15)
				spawn_particles(t, "stone")
				if obj.hp <= 0:
					_remove_object(t)
					GameData.stone += BIGROCK_STONE
					hud.show_message("커다란 바위를 캐냈다! 돌 +%d" % BIGROCK_STONE)
					gain_skill("mine", 4.0)
					_story_rock_mined()
				else:
					hud.show_message("커다란 바위를 내리쳤다. (%d/%d)" %
						[BIGROCK_HP - obj.hp, BIGROCK_HP])
			elif obj.kind == "sprinkler":
				_remove_object(t)
				GameData.wood += GameData.SPRINKLER_COST_WOOD
				GameData.stone += GameData.SPRINKLER_COST_STONE
				Sound.play_sfx("sfx_place")
				hud.show_message("스프링클러를 회수했다.")
			else:
				hud.show_message("곡괭이로 캘 수 없다.")
		"fence":
			if obj != null or cell.ground == "water" or cell.crop_id != "" \
					or _tile_overlaps_player(t):
				hud.show_message("여기에는 설치할 수 없다.")
				return
			if GameData.wood < GameData.FENCE_COST_WOOD:
				hud.show_message("목재가 부족하다. (목재 %d 필요)" % GameData.FENCE_COST_WOOD)
				return
			GameData.wood -= GameData.FENCE_COST_WOOD
			_place_object(t, "fence", 0)
			Sound.play_sfx("sfx_place")
			tutorial_notify("build")
		"sprinkler":
			if obj != null or cell.ground == "water" or cell.crop_id != "" \
					or _tile_overlaps_player(t):
				hud.show_message("여기에는 설치할 수 없다.")
				return
			if GameData.wood < GameData.SPRINKLER_COST_WOOD or GameData.stone < GameData.SPRINKLER_COST_STONE:
				hud.show_message("재료 부족: 목재 %d + 석재 %d 필요" %
					[GameData.SPRINKLER_COST_WOOD, GameData.SPRINKLER_COST_STONE])
				return
			GameData.wood -= GameData.SPRINKLER_COST_WOOD
			GameData.stone -= GameData.SPRINKLER_COST_STONE
			_place_object(t, "sprinkler", 0)
			Sound.play_sfx("sfx_place")
			hud.show_message("스프링클러 설치! 매일 아침 주변 4칸에 물을 준다.")
			tutorial_notify("build")
		"rod":
			match fishing_state:
				"":
					_start_fishing()
				"waiting":
					fishing_state = ""
					hud.show_message("아직 입질이 없다...")
				"bite":
					fishing_state = ""
					pending_fish = GameData.pick_fish()
					# 철수 호감도 50+ 특전: 판정 구간 25% 확대
					var zone: float = pending_fish[2]
					if int(GameData.affinity["fisher"]) >= 50:
						zone *= 1.25
					fishing_ui.start(zone)
	# 멀티: 내 행동을 다른 플레이어에게 반영 (낚싯대는 로컬 진행)
	if not _remote_acting:
		if Net.is_guest() and GameData.tool != "rod":
			_req_tool.rpc_id(1, t.x, t.y, GameData.tool, seed_now,
				_current_perp().x, _current_perp().y)
		elif Net.is_host():
			_broadcast_area(t)
			_broadcast_stats()
	queue_redraw()


func interact() -> void:
	# 맞는 도구를 들고 나무/돌을 조준 중이면 채집이 최우선
	# (근처에 NPC가 있어도 대화가 끼어들지 않는다)
	var aim: Variant = objects.get(target_tile())
	if aim != null and not bool(aim.get("young", false)) \
			and ((aim.kind == "tree" and GameData.tool == "axe")
			or (aim.kind in ["rock", "bigrock"] and GameData.tool == "pickaxe")):
		use_tool()
		return
	# 나무·돌·채집물을 조준하고 있으면 대화보다 채집이 우선이다
	# (옆에 사람이 서 있어도 E가 대화로 새지 않는다)
	const AIM_KINDS := ["tree", "rock", "bigrock", "forage_berry", "forage_herb"]
	var aiming_object: bool = aim != null and AIM_KINDS.has(aim.kind)
	# 우체부 아저씨에게 말 걸기 (첫 만남 / 동행 중 보조 대화)
	if not aiming_object and _postman != null and _postman_state == "wait" \
			and (player.position - _postman.position).length() < POSTMAN_TALK_DIST:
		_postman_state = "talk"
		_start_postman_dialog()
		return
	if not aiming_object and _postman != null and _postman_state == "follow" \
			and (player.position - _postman.position).length() < 48.0:
		_talk_to_postman()
		return
	# 가까운 NPC와 대화
	var npc := nearby_npc()
	if npc != null and not aiming_object:
		_talk_to(npc)
		return
	# 가까운 동물 쓰다듬기(=먹이 주기)
	var animal := nearby_animal()
	if animal != null:
		var def: Dictionary = GameData.ANIMALS[animal.type]
		if animal.fed:
			hud.show_message("%s는 이미 만족스러워 보인다." % def.name)
		else:
			animal.fed = true
			Sound.play_sfx("sfx_heart")
			if Net.is_guest():
				_req_feed.rpc_id(1, animals.find(animal))
			hud.show_message("%s를 쓰다듬었다! ♥ 내일 아침 %s을 준다." %
				[def.name, GameData.ITEMS[def.product].name])
		return
	# 곤충 잡기
	var bug := nearby_bug()
	if bug != null:
		var bid: String = bug.bug_id
		GameData.items[bid] += 1
		GameData.forage_caught[bid] = int(GameData.forage_caught.get(bid, 0)) + 1
		Sound.play_sfx("sfx_catch")
		spawn_particles(player_tile(), "sparkle")
		hud.show_message("%s를 잡았다! 연구 노트에 기록됐다." % GameData.ITEMS[bid].name)
		bug.respawn()
		if Net.is_host():
			_broadcast_stats()
		return
	for t in [target_tile(), player_tile()]:
		var obj: Variant = objects.get(t)
		if obj == null:
			continue
		if String(obj.kind).begins_with("forage_"):
			var fid: String = obj.kind
			_remove_object(t)
			GameData.items[fid] += 1
			GameData.forage_caught[fid] = int(GameData.forage_caught.get(fid, 0)) + 1
			Sound.play_sfx("sfx_harvest")
			spawn_particles(t, "sparkle")
			hud.show_message("%s 채집! 연구 노트에 기록됐다." % GameData.ITEMS[fid].name)
			gain_skill("forest", 3.0)
			if Net.is_host():
				_broadcast_area(t)
				_broadcast_stats()
			elif Net.is_guest():
				_req_gain.rpc_id(1, fid, 1)
			return
		if obj.kind == "worldtree":
			cave.open(true)
			return
		if obj.kind == "housesite":
			_open_build_dialog()
			return
		if obj.kind == "bin":
			shop.open("sell", ["sell"])
			return
		if obj.kind == "board":
			_open_quest_board()
			return
		if obj.kind == "cave":
			cave.open()
			return
		if obj.kind == "house":
			match _building_kind_at(t):
				"home":
					interior.open()  # 우리집 입장
				"general":
					shop.open("buy", ["buy", "sell"])
				"ranch":
					shop.open("animal", ["animal"])
				"smith":
					shop.open("upgrade", ["upgrade"])
				"fish":
					shop.open("codex", ["codex"])
				"post":
					hud.show_message("우체국이다. 우체부 아저씨가 편지를 정리하고 있다.")
				_:
					var bk2 := _building_kind_at(t)
					hud.show_message("%s다. 아직 안에서 할 수 있는 일은 없다." %
						BUILDING_NAMES.get(bk2, "건물"))
			return
	# 자연물: E키가 기본 상호작용 (나무=도끼 벌목, 돌=곡괭이 채광)
	var tobj: Variant = objects.get(target_tile())
	if tobj != null and tobj.kind == "tree":
		if bool(tobj.get("young", false)):
			hud.show_message("아직 어린 나무다. 다 자라면 벨 수 있다.")
		elif GameData.tool == "axe":
			use_tool()
		else:
			hud.show_message("도끼가 필요하다. 숫자키로 도끼를 선택하자!")
		return
	if tobj != null and tobj.kind in ["rock", "bigrock"]:
		if GameData.tool == "pickaxe":
			use_tool()
		else:
			hud.show_message("곡괭이가 필요하다. 숫자키로 곡괭이를 선택하자!")
		return
	# 그 밖에는 손에 든 것을 그대로 쓴다 — 호미로 밭 갈기, 씨앗 심기, 물 주기,
	# 수확, 낚시까지 전부 E 하나로 된다 (좌클릭과 같은 동작).
	# 맨손이고 앞에 작물도 없으면 아무 일도 하지 않는다
	# (걸어다니며 E를 눌러도 메시지가 뜨지 않게)
	var tt := target_tile()
	var crop_ahead: bool = tt.x >= 0 and tt.y >= 0 and tt.x < MAP_W and tt.y < MAP_H \
		and grid[tt.y][tt.x].crop_id != ""
	if GameData.tool != "hand" or GameData.current_seed_id() != "" or crop_ahead:
		use_tool()


# 설치 타일이 플레이어(원격 포함) 발밑과 겹치면 끼이므로 설치를 막는다
func _tile_overlaps_player(t: Vector2i) -> bool:
	var rect := Rect2(t.x * TILE - 2, t.y * TILE - 2, TILE + 4, TILE + 4)
	if rect.has_point(player.position):
		return true
	for pid in remote_players:
		if rect.has_point(remote_players[pid].position):
			return true
	return false


func nearby_npc() -> Node2D:
	for n in npcs:
		if not n.visible:
			continue  # 집에 들어간 NPC와는 만날 수 없다
		if (n.position - player.position).length() < 48.0:
			return n
	return null


func nearby_animal() -> Node2D:
	for a in animals:
		if (a.position - player.position).length() < 44.0:
			return a
	return null


func _building_kind_at(t: Vector2i) -> String:
	if GameData.house_lv >= 1 and t.x >= HOME_ANCHOR.x and t.x < HOME_ANCHOR.x + 5 \
			and t.y >= HOME_ANCHOR.y and t.y < HOME_ANCHOR.y + 4:
		return "home"
	# 마을 건물은 실제로 지어진 것만 존재한다
	for pid: String in GameData.village_built:
		if not VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = VILLAGE_PLOTS[pid].anchor
		if t.x >= a.x and t.x < a.x + 5 and t.y >= a.y and t.y < a.y + 4:
			return pid
	return ""


# ---- 오프닝 스토리 / 튜토리얼 ----

# ---- 메인 스토리 1 「우체부 아저씨와의 첫 만남」 ----
const STORY_SPAWN := Vector2i(18, 16)       # 화면 왼쪽에서 시작 (집은 화면 밖)
const STORY_LANE_Y := 16                   # 우체부가 왼쪽에서 걸어오는 길
const STORY_FORK := Vector2i(34, 16)       # 숲길이 갈라지는 갈림길 (지도 퀘스트)
const STORY_ROCK := Vector2i(40, 16)       # 마을 가는 길을 막는 커다란 바위 (퀘스트 5)
# 스토리 숲의 가로 폭. 화면(37.5칸)보다 넉넉히 넓어야 카메라가 주인공을 따라
# 옆으로 움직인다. 숲길(x 4~33) 동쪽은 들어갈 수 없는 배경 숲이다.
const STORY_FOREST_W := 58
# 숲길은 4줄 폭의 흙길. 양옆은 울타리로 막혀 있어 길을 벗어날 수 없다.
const STORY_ROAD_Y0 := 15
const STORY_ROAD_Y1 := 18                  # 15·16·17·18 = 4줄
const STORY_ROAD_X0 := 18
const STORY_ROAD_X1 := 47
const STORY_LINK_X := 44                   # 마을 큰길로 오르는 4줄 연결로 (30~33)
# 길을 가로막고 선 나무 줄 (4줄 전체를 막는다) — 베어야만 지나갈 수 있다.
# 첫 번째는 퀘스트 1의 「더 이상 갈 수 없는 길」이자 퀘스트 3의 벌목 대상.
const STORY_GATE_XS := [25, 30, 36, 42]
const BIGROCK_HP := 4                      # 커다란 바위는 여러 번 캐야 부서진다
const BIGROCK_STONE := 4                   # 커다란 바위에서 나오는 돌
var story_cutscene := false                # 컷신 중 조작 잠금
var _postman: Node2D = null
var _postman_spr: Sprite2D = null
var _postman_state := ""                   # approach / wait / talk / follow / leave
const POSTMAN_STOP_DIST := 168.0           # 걸어와서 멈춰 서는 거리 (5칸쯤 앞)
const POSTMAN_TALK_DIST := 60.0            # E로 말을 걸 수 있는 거리
const POSTMAN_REFOLLOW_DIST := 420.0       # 이만큼 멀어지면 다시 따라온다
const VILLAGE_EXIT_X := 74                 # 우체부가 빠져나가는 마을 북쪽 길
var _postman_anim := 0.0
var _postman_wait_t := 0.0
var _postman_path: Array = []      # 퇴장 경로 (지나갈 칸의 중심 좌표)
var _postman_fade := 1.0
var _story_t := 0.0


func _apply_story_camera() -> void:
	# 숲 구간(마을 이동 전)에는 카메라를 숲 안에 가둔다.
	# 숲이 화면보다 넓으므로 주인공을 따라 옆으로 스크롤된다.
	# 마을로 이동하는 travel 단계부터는 전체 맵 카메라로 풀린다.
	var cam: Camera2D = player.get_node("Camera")
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	if GameData.story_phase in ["enter", "approach", "equip", "chop", "path", "map", "rock"]:
		cam.limit_left = 0
		cam.limit_top = TILE
		cam.limit_right = STORY_FOREST_W * TILE
		cam.limit_bottom = 23 * TILE
		cam.position_smoothing_enabled = true
	else:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = MAP_W * TILE
		cam.limit_bottom = MAP_H * TILE
		cam.position_smoothing_enabled = true


func _apply_story_visibility() -> void:
	# 숲 구간(마을 이동 전)엔 집/건물류가 어느 방향에서도 보이지 않는다.
	# 마을로 이동하는 travel 단계부터는 마을이 보여야 하므로 표시한다.
	var show := GameData.story_phase not in ["enter", "approach", "equip", "chop", "path", "map", "rock"]
	for pos: Vector2i in obj_nodes:
		# 부지 앵커로 만든 집 노드는 objects에 없다 -> house로 간주
		var kind: String = objects[pos].kind if objects.has(pos) else "house"
		if kind in ["house", "housesite", "bin", "board", "sign", "barn", "barn_block", "cave"]:
			obj_nodes[pos].visible = show


func _plant_story_forest() -> void:
	# ① 4줄 폭의 흙길을 낸다 (본길 + 갈림길의 북/남 갈래 + 마을 큰길 연결로)
	#    길을 내면서 그 자리에 미리 생성된 나무·돌은 치운다 (길이 막히면 안 된다)
	for y in range(STORY_ROAD_Y0, STORY_ROAD_Y1 + 1):
		for x in range(STORY_ROAD_X0, STORY_ROAD_X1 + 1):
			_carve_road(Vector2i(x, y))
	for y in range(10, STORY_ROAD_Y0):              # 북쪽 갈래 (막다른 길)
		for x in range(STORY_FORK.x - 1, STORY_FORK.x + 3):
			_carve_road(Vector2i(x, y))
	for y in range(STORY_ROAD_Y1 + 1, 22):          # 남쪽 갈래 (막다른 길)
		for x in range(STORY_FORK.x - 1, STORY_FORK.x + 3):
			_carve_road(Vector2i(x, y))
	for y in range(9, STORY_ROAD_Y0):               # 마을 큰길로 오르는 연결로
		for x in range(STORY_LINK_X, STORY_LINK_X + 4):
			_carve_road(Vector2i(x, y))
	for y in [8, 9]:                                # 숲을 빠져나와 마을 큰길로 이어지는 길
		for x in range(STORY_LINK_X, 60):
			_carve_road(Vector2i(x, y))

	# ② 길 양옆은 울타리로 막는다 — 길을 벗어날 수 없다 (숲으로는 못 들어간다)
	for x in range(STORY_ROAD_X0, STORY_ROAD_X1 + 2):
		var at_fork: bool = x >= STORY_FORK.x - 1 and x <= STORY_FORK.x + 2
		var at_link: bool = x >= STORY_LINK_X and x <= STORY_LINK_X + 3
		if not at_fork and not at_link:
			_story_fence(Vector2i(x, STORY_ROAD_Y0 - 1))   # 위쪽 (갈래·연결로는 열어 둔다)
		if not at_fork:
			_story_fence(Vector2i(x, STORY_ROAD_Y1 + 1))   # 아래쪽
	for y in range(9, STORY_ROAD_Y0):               # 북쪽 갈래 양옆 + 막다른 끝
		_story_fence(Vector2i(STORY_FORK.x - 2, y))
		_story_fence(Vector2i(STORY_FORK.x + 3, y))
	for x in range(STORY_FORK.x - 2, STORY_FORK.x + 4):
		_story_fence(Vector2i(x, 9))
	for y in range(STORY_ROAD_Y1 + 1, 22):          # 남쪽 갈래 양옆 + 막다른 끝
		_story_fence(Vector2i(STORY_FORK.x - 2, y))
		_story_fence(Vector2i(STORY_FORK.x + 3, y))
	for x in range(STORY_FORK.x - 2, STORY_FORK.x + 4):
		_story_fence(Vector2i(x, 22))
	for y in range(9, STORY_ROAD_Y0):               # 연결로 양옆
		_story_fence(Vector2i(STORY_LINK_X - 1, y))
		_story_fence(Vector2i(STORY_LINK_X + 4, y))
	for y in range(STORY_ROAD_Y0, STORY_ROAD_Y1 + 1):   # 본길 양 끝
		_story_fence(Vector2i(STORY_ROAD_X1 + 1, y))
		_story_fence(Vector2i(STORY_ROAD_X0 - 1, y))

	# ③ 길을 가로막고 선 나무 줄 — 베어야만 지나갈 수 있다
	for gx: int in STORY_GATE_XS:
		for y in range(STORY_ROAD_Y0, STORY_ROAD_Y1 + 1):
			objects[Vector2i(gx, y)] = {"kind": "tree", "hp": TREE_HP}

	# ④ 퀘스트 5: 커다란 바위가 길 4줄을 통째로 가로막는다
	for y in range(STORY_ROAD_Y0, STORY_ROAD_Y1 + 1):
		objects[Vector2i(STORY_ROCK.x, y)] = {"kind": "bigrock", "hp": BIGROCK_HP}

	# ⑤ 길 바깥의 숲: 서로 겹치지 않게 간격을 지켜 세운다 (울타리 너머 풍경)
	for y in range(1, 23):
		for x in range(3, STORY_FOREST_W):
			var pos := Vector2i(x, y)
			if grid[y][x].ground != "grass" or objects.has(pos):
				continue
			var h := _hash01(x, y)
			if h < 0.55:
				if _nature_clear(pos, "tree"):
					var tr := {"kind": "tree", "hp": TREE_HP}
					if _hash01(x * 17 + 2, y * 23 + 5) < 0.12:
						tr["apple"] = true  # 일부 나무에만 사과 3개가 열린다
					objects[pos] = tr
			elif h > 0.93:
				if _nature_clear(pos, "rock"):
					objects[pos] = {"kind": "rock", "hp": ROCK_HP}
			elif h > 0.86:
				if _nature_clear(pos, "forage_berry"):
					objects[pos] = {"kind": "forage_herb" if h < 0.895 else "forage_berry",
						"hp": 0}
	_refresh_story_gates()


# 길을 낸다: 흙바닥으로 바꾸고, 그 자리에 있던 오브젝트는 치운다
func _carve_road(pos: Vector2i) -> void:
	if pos.x < 0 or pos.y < 0 or pos.x >= MAP_W or pos.y >= MAP_H:
		return
	grid[pos.y][pos.x].ground = "path"
	objects.erase(pos)


# 스토리용 울타리: 길을 벗어나지 못하게 막는다 (도끼로 걷어낼 수 없다)
func _story_fence(pos: Vector2i) -> void:
	if pos.x < 0 or pos.y < 0 or pos.x >= MAP_W or pos.y >= MAP_H:
		return
	objects[pos] = {"kind": "fence", "hp": 0, "fixed": true}


# 아직 뚫지 못한 길목(나무 줄) 수를 센다 — 한 칸만 베어도 그 줄은 열린 것으로 본다
func _refresh_story_gates() -> void:
	var left := 0
	for gx: int in STORY_GATE_XS:
		var blocked := true
		for y in range(STORY_ROAD_Y0, STORY_ROAD_Y1 + 1):
			if not objects.has(Vector2i(gx, y)):
				blocked = false
				break
		if blocked:
			left += 1
	GameData.story_gates_left = left


func _story_update(delta: float) -> void:
	if GameData.story_phase == "done" or Net.is_guest():
		# 스토리가 끝나도 우체부가 남아 있으면 떠나는 연출은 계속 돌린다
		# (예전에는 여기서 바로 빠져나가 편지를 전한 자리에 그대로 서 있었다)
		if not Net.is_guest() and _postman != null:
			_update_postman(delta, false)
		return
	_story_t += delta
	var story_shot := _shot_path != "" and OS.get_environment("KYOJIN_STORY") != ""
	# 안전장치: 어떤 이유로든 연출이 끊겨 조작이 잠긴 채 남으면 풀어 준다.
	# (편지 전달 중에는 원래 잠겨 있어야 한다)
	if story_cutscene and not dialog.visible and _name_layer == null \
			and _postman_state != "deliver":
		_cutscene_idle += delta
		if _cutscene_idle > 1.5:
			_cutscene_idle = 0.0
			story_cutscene = false
	else:
		_cutscene_idle = 0.0
	match GameData.story_phase:
		"enter":
			# (검증용) t를 지나는 첫 프레임에만 1회 발동
			if story_shot and _story_t >= 0.4 and _story_t - delta < 0.4:
				quest_ui.toggle()  # 상세 퀘스트 창 캡처
			if story_shot and _story_t >= 0.55 and _story_t - delta < 0.55:
				_snap_story("story_quest")
				quest_ui.close()
			if story_shot and absf(_story_t - 0.7) < delta:
				_snap_story("story_forest")
			# 숲으로 걷다가 나무에 정면으로 막히는 순간 퀘스트 1 완료
			var hit_tree := false
			if player.moving and player.bumped:
				var dirs := {"down": Vector2i(0, 1), "up": Vector2i(0, -1),
					"left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
				var ahead: Variant = objects.get(player_tile() + dirs[player.dir])
				hit_tree = ahead != null and ahead.kind == "tree"
			if hit_tree or (story_shot and _story_t > 0.8):
				if story_shot:   # 실제 플레이처럼 첫 나무 줄 앞까지 걸어와 있게 한다
					player.position = Vector2(
						(STORY_GATE_XS[0] - 1) * TILE + 16, STORY_LANE_Y * TILE + 16)
				GameData.story_phase = "approach"
				hud.show_message("더 이상 갈 수 없는 길인 것 같다.", 4.0)
				if story_shot:
					hud.quest_toast("숲 안으로 들어가보기")
					_spawn_postman()
				else:
					# 자막을 읽을 시간을 준 뒤 완료 처리 + 우체부 등장
					get_tree().create_timer(1.3).timeout.connect(func() -> void:
						hud.quest_toast("숲 안으로 들어가보기")
						_spawn_postman())
		"approach":
			_update_postman(delta, story_shot)
			if story_shot and _postman_state == "wait":
				# 실제 플레이와 같은 경로: 느낌표를 보고 걸어가서 E로 말을 건다
				_postman_wait_t += delta
				if _postman_wait_t >= 0.5 and _postman_wait_t - delta < 0.5:
					_snap_story("story_bang")     # 머리 위 느낌표 확인
				elif _postman_wait_t > 0.6:
					if (player.position - _postman.position).length() > POSTMAN_TALK_DIST - 8.0:
						player.position = player.position.move_toward(
							_postman.position, 220.0 * delta)
					else:
						_send_key(KEY_E)
		"equip":
			_update_postman(delta, story_shot)
			# 받은 나무도끼를 가방에서 빠른 슬롯에 넣으면 퀘스트 2 완료
			if GameData.tool_slots.has("axe"):
				GameData.story_phase = "chop"
				hud.quest_toast("나무도끼를 장착해보기")
				hud.show_message("숫자키로 도끼를 선택하고, 나무를 클릭한 뒤 E로 베어보자!", 6.0)
		"chop":
			_update_postman(delta, story_shot)
		"path":
			_update_postman(delta, story_shot)
			# 갈림길 중앙에 도착하면 지도 안내 대화 시작
			if not dialog.visible and player.position.distance_to(
					Vector2(STORY_FORK.x * TILE + 16, STORY_FORK.y * TILE + 16)) < 44.0:
				_start_fork_dialog()
		"map":
			_update_postman(delta, story_shot)
			# 지도 UI가 실제로 열린 것을 확인해야 퀘스트 완료
			if map_ui.visible and not _story_map_opened:
				_story_map_opened = true
			elif _story_map_opened and not map_ui.visible and not dialog.visible:
				hud.quest_toast("지도를 확인해보자")
				GameData.story_phase = "rock"  # 대화는 토스트 뒤에 이어진다
				get_tree().create_timer(1.4).timeout.connect(_after_map_dialog)
		"rock":
			_update_postman(delta, story_shot)
			# 안전장치: 곡괭이 대화가 도중에 끊겼으면 조작이 잠긴 채로 두지 않는다
			if _rock_intro_started and GameData.story_rock_state == 0 \
					and not dialog.visible:
				_end_rock_intro()
			# 길을 막은 커다란 바위를 발견하면 우체부 아저씨가 곡괭이를 보여준다
			if GameData.story_rock_state == 0 and not dialog.visible and not ui_open() \
					and objects.has(STORY_ROCK) and player.position.distance_to(
						Vector2(STORY_ROCK.x * TILE + 16, STORY_ROCK.y * TILE + 16)) < 110.0:
				_start_rock_dialog()
		"travel":
			_update_postman(delta, story_shot)
			# 마을 이장 근처에 도착하면 편지 전달 컷신
			if _postman_state == "follow":
				var chief := _story_chief()
				if chief != null and player.position.distance_to(chief.position) < 150.0:
					story_cutscene = true
					_postman_state = "deliver"


func _spawn_postman() -> void:
	_postman = Node2D.new()
	_postman.position = Vector2(STORY_ROAD_X0 * TILE + 16, STORY_LANE_Y * TILE + 16)
	_postman_spr = Sprite2D.new()
	_postman_spr.centered = false
	# 플레이어와 같은 밀도의 도트. 어른이라 주인공보다 조금 크게 그린다.
	_postman_spr.offset = Vector2(-64, -188)
	_postman_spr.scale = Vector2(0.56, 0.56)
	_postman_spr.texture = tex["npc_postman_side_0"]
	_postman.add_child(_postman_spr)
	world.add_child(_postman)
	_postman_state = "approach"
	# 걸어오는 동안 조작을 잠그지 않는다 — 직접 다가가 E로 말을 건다
	if _shot_path != "" and OS.get_environment("KYOJIN_STORY") != "":
		get_tree().create_timer(0.2).timeout.connect(
			func() -> void: _snap_story("story_postman"))


func _update_postman(delta: float, story_shot: bool) -> void:
	if _postman == null:
		return
	_postman_anim += delta
	match _postman_state:
		"approach":
			# 멀리서 뚜벅뚜벅 걸어온다. 검증 시퀀스만 붙자마자 대화를 시작하고,
			# 실제 플레이에서는 옆에 서서 기다린다 (플레이어가 E로 말을 건다)
			var to_player := player.position - _postman.position
			if to_player.length() > POSTMAN_STOP_DIST:
				var far := to_player.length() > 320.0   # 멀어지면 서둘러 따라온다
				var spd := 90.0 if story_shot else (110.0 if far else 45.0)
				_postman.position += to_player.normalized() * spd * delta
				_postman_spr.texture = tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				_postman_spr.flip_h = to_player.x < 0
			else:
				_postman_state = "wait"
				_postman_spr.texture = tex["npc_postman_side_0"]
				_postman_spr.flip_h = to_player.x < 0
				if not story_shot:
					hud.show_message(
						"누군가 말을 걸고 싶어 한다. 가까이 가서 E를 눌러보자.", 6.0)
		"wait":
			# 느낌표를 띄운 채 서서 기다린다 (많이 멀어지면 다시 따라간다)
			var to_wait := player.position - _postman.position
			if to_wait.length() > POSTMAN_REFOLLOW_DIST:
				_postman_state = "approach"
			else:
				_postman_spr.texture = tex["npc_postman_side_0"]
				if absf(to_wait.x) > 4.0:
					_postman_spr.flip_h = to_wait.x < 0
		"follow":
			# 마을까지 동행: 주인공 옆에서 함께 걷고, 개척하는 동안 기다린다
			var to := player.position + Vector2(-42, 6) - _postman.position
			if to.length() > 14.0:
				var spd := minf(to.length() * 2.5, 160.0)
				_postman.position += to.normalized() * spd * delta
				_postman_spr.texture = tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				if absf(to.x) > 4.0:
					_postman_spr.flip_h = to.x < 0
			else:
				_postman_spr.texture = tex["npc_postman_side_0"]
		"mine_demo":
			# 퀘스트 5: 대사가 나오는 동안 커다란 바위 옆으로 걸어가 시연 위치에 선다
			var demo_pos := Vector2(STORY_ROCK.x * TILE - 20, STORY_ROCK.y * TILE + 22)
			var to_rock := demo_pos - _postman.position
			if to_rock.length() > 6.0:
				_postman.position += to_rock.normalized() * minf(to_rock.length() * 3.0, 110.0) * delta
				_postman_spr.texture = tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				if absf(to_rock.x) > 4.0:
					_postman_spr.flip_h = to_rock.x < 0
			else:
				_postman_spr.texture = tex["npc_postman_side_0"]
				_postman_spr.flip_h = false  # 바위(오른쪽)를 바라본다
		"deliver":
			# 이장에게 걸어가 편지를 전달한다
			var chief := _story_chief()
			if chief == null:
				_postman_state = "talk"
				_start_delivery_dialog()
				return
			var to2: Vector2 = chief.position + Vector2(-40, 0) - _postman.position
			if to2.length() > 8.0:
				_postman.position += to2.normalized() * 90.0 * delta
				_postman_spr.texture = tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				_postman_spr.flip_h = to2.x < 0
			else:
				_postman_state = "talk"
				_postman_spr.texture = tex["npc_postman_side_0"]
				_postman_spr.flip_h = false
				_start_delivery_dialog()
		"leave":
			# 편지를 전하고 나면 마을 북쪽 길을 따라 걸어 나간다.
			# 길찾기로 낸 경로를 밟으므로 분수·벤치·건물을 뚫고 지나가지 않는다.
			if _postman_path.is_empty():
				# 길 끝에 닿았다 — 그 자리에서 서서히 사라진다
				_postman_fade = maxf(0.0, _postman_fade - delta * 2.5)
				_postman_spr.modulate.a = _postman_fade
				_postman_spr.texture = tex["npc_postman_up_%d" % (int(_postman_anim * 5.0) % 2)]
				if _postman_fade <= 0.0:
					_postman.queue_free()
					_postman = null
				return
			var step: Vector2 = _postman_path[0]
			var to4 := step - _postman.position
			if to4.length() <= 4.0:
				_postman.position = step
				_postman_path.remove_at(0)
				return
			_postman.position += to4.normalized() * 70.0 * delta
			if absf(to4.x) > absf(to4.y):
				_postman_spr.texture = tex["npc_postman_side_%d" % (int(_postman_anim * 5.0) % 2)]
				_postman_spr.flip_h = to4.x < 0
			else:
				_postman_spr.texture = tex["npc_postman_%s_%d"
					% ["up" if to4.y < 0.0 else "down", int(_postman_anim * 5.0) % 2]]
				_postman_spr.flip_h = false


func _start_postman_dialog() -> void:
	# 1부: 인사 -> 이름 질문. 이름 입력 후 2부로 이어진다.
	if _shot_path != "" and OS.get_environment("KYOJIN_STORY") != "":
		get_tree().create_timer(0.25).timeout.connect(
			func() -> void: _snap_story("story_dialog"))
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
		{"text": "「자네도 마을로 가는 길인가?」"},
		{"text": "「나도 마을에 가야 하는데 말이야.」"},
		{"text": "「이장님께 전할 편지가 있거든.」"},
		{"text": "「그런데 이 숲을 지나야 하거든.」"},
		{"text": "「나무가 너무 빽빽해서 혼자서는 영 쉽지가 않구먼.」"},
		{"text": "「그러고 보니, 자네 이름이 어떻게 되나?」"},
	], _show_name_input)


var _name_layer: CanvasLayer = null


func _show_name_input() -> void:
	# 이름 입력: 여기서 정한 닉네임을 게임 전체에서 사용한다
	_name_layer = CanvasLayer.new()
	_name_layer.layer = 30
	var panel := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.91, 0.71, 0.42, 0.98)
	st.border_color = Color(0.43, 0.24, 0.11)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", st)
	panel.position = Vector2(330, 200)
	panel.size = Vector2(300, 120)
	_name_layer.add_child(panel)
	var lab := Label.new()
	lab.text = "이름을 알려주자"
	lab.position = Vector2(0, 10)
	lab.size = Vector2(300, 20)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color(0.29, 0.16, 0.06))
	panel.add_child(lab)
	var edit := LineEdit.new()
	edit.position = Vector2(50, 40)
	edit.size = Vector2(200, 30)
	edit.max_length = 8
	edit.placeholder_text = "이름 입력 (최대 8자)"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(edit)
	var btn := Button.new()
	btn.text = "확인"
	btn.position = Vector2(110, 80)
	btn.size = Vector2(80, 28)
	btn.focus_mode = Control.FOCUS_NONE
	panel.add_child(btn)
	var confirm := func() -> void:
		var nm := edit.text.strip_edges()
		if nm == "":
			nm = "친구"
		GameData.player_name = nm
		_name_layer.queue_free()
		_name_layer = null
		Sound.play_sfx("sfx_ui")
		_start_postman_dialog2()
	btn.pressed.connect(confirm)
	edit.text_submitted.connect(func(_t: String) -> void: confirm.call())
	add_child(_name_layer)
	edit.grab_focus.call_deferred()


func _start_postman_dialog2() -> void:
	# 2부: 닉네임으로 부르며 동행 제안 -> 숲을 바라보며 상황 설명 -> 도끼 전달 -> 퀘스트 안내
	var nm := GameData.player_name
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
		{"text": "「%s(이)라... 좋은 이름이구먼.」" % nm,
			"portrait": tex["npc_postman_portrait_happy"]},
		{"text": "「그렇다면 같이 가는 게 어떻겠나?」"},
		{"text": "「자네가 길을 만들고, 나는 옆에서 도와주지.」"},
		{"text": "(우체부 아저씨가 우거진 숲을 잠시 바라본다...)"},
		{"text": "「이 숲은 나무가 너무 많아서 그냥 지나가기는 힘들겠구먼.」"},
		{"text": "「안전하게 지나가려면 길을 조금 만들어야 할 것 같네.」"},
		{"text": "「%s, 이 나무도끼를 한번 사용해보게.」" % nm, "event": _story_give_axe},
		{"text": "「가방을 열어 도끼를 슬롯에 넣어두게.」"},
		{"text": "「숫자키를 누르면 슬롯에 넣어둔 도구를 빠르게 꺼낼 수 있다네.」"},
		{"text": "「지금 자네가 해야 할 일은 오른쪽 위에 간단하게 적혀 있을 걸세.」"},
		{"text": "「자세한 내용을 보고 싶다면 Q 키를 눌러보게.」"},
	], _end_postman_dialog)


func _story_give_axe() -> void:
	if not GameData.is_tool_unlocked("axe"):
		GameData.unlocked_tools.append("axe")
	hud.reward_toast("나무도끼 × 1", tex["icon_axe"])
	hud.show_message("나무도끼는 슬롯에 장착하기 전에는 쓸 수 없다.", 5.0)


func _end_postman_dialog() -> void:
	story_cutscene = false
	GameData.story_phase = "equip"
	hud.show_message("새 퀘스트: 받은 나무도끼를 가방의 슬롯에 장착해 보자 (I: 가방)", 6.0)
	if _postman != null:
		_postman_state = "follow"  # 우체부는 떠나지 않고 마을까지 동행한다


var _cutscene_idle := 0.0
var _story_snapped := false
var _story_map_opened := false
var _last_explore_tile := Vector2i(-999, -999)


func _story_tree_chopped() -> void:
	if GameData.story_phase != "chop":
		return
	# 벌목 퀘스트 완료 (보상: 목재) -> 완료 연출 후 우체부 아저씨의 다음 대화로 자동 연결.
	# 아직 마을로 가지 않는다 — 숲길을 개척하며 갈림길까지 함께 이동한다.
	GameData.story_phase = "path"
	hud.quest_toast("나무를 베어보자")
	hud.reward_toast("목재 × %d" % WOOD_PER_TREE, tex["icon_wood"])
	get_tree().create_timer(1.6).timeout.connect(_start_travel_dialog)


func _start_travel_dialog() -> void:
	# 벌목 퀘스트 완료 직후 자동으로 이어지는 대화 (첫 벌목 직후 1회)
	# 다른 연출이 진행 중이면 그 대화를 덮어쓰지 않고 기다린다
	if dialog.visible or ui_open():
		get_tree().create_timer(1.0).timeout.connect(_start_travel_dialog)
		return
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_happy"], [
		{"text": "「오, 제법이구먼! 좋은 목재도 얻었고 말이야.」"},
		{"text": "「도구를 사용해야만 나무를 벨 수 있다는 걸 기억하게.」"},
		{"text": "「이렇게 나무를 베어 길을 만들면서 가면 되겠네.」"},
		{"text": "「%s, 이 숲길을 따라 가보세. 막힌 나무는 자네가 부탁하네.」" % nm},
	], func() -> void:
		hud.show_message("화살표를 따라 숲길을 개척하며 나아가자!", 6.0))


func _start_fork_dialog() -> void:
	# 갈림길 도착: 우체부 아저씨가 길을 둘러본 뒤 지도를 알려준다 (퀘스트: 지도 확인)
	story_cutscene = true
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
		{"text": "(우체부 아저씨가 갈라진 길을 둘러본다...)"},
		{"text": "「길이 여러 갈래로 나뉘었구먼.」"},
		{"text": "「이럴 때는 지도를 확인하는 게 좋다네.」"},
		{"text": "「M 키를 누르면 지도를 볼 수 있어.」"},
		{"text": "「지도에서는 자네가 지금 어디에 있는지와, 지금까지 가본 곳들을 확인할 수 있다네.」"},
	], func() -> void:
		story_cutscene = false
		GameData.story_phase = "map"
		hud.show_message("새 퀘스트: M 키를 눌러 지도를 열어 보자", 6.0))


func _after_map_dialog() -> void:
	# 지도를 확인한 뒤: 마을 방향을 함께 확인하고 이동 재개 (아직 숲길 — 카메라 잠금 유지)
	if GameData.story_phase != "rock" or _rock_intro_started:
		return  # 이미 다음 연출(바위)로 넘어갔다면 건너뛴다
	if dialog.visible or ui_open():
		get_tree().create_timer(1.0).timeout.connect(_after_map_dialog)
		return
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_happy"], [
		{"text": "「이제 우리가 어디쯤 있는지 알겠나?」"},
		{"text": "「마을은 이쪽 방향일세. 계속 가보세.」"},
	], func() -> void:
		hud.show_message("길을 따라 마을 방향으로 가보자 (화살표 방향)", 6.0))


# ---- 퀘스트 5 「마을로 가는 길을 열어보자」 (커다란 바위 / 곡괭이) ----

var _rock_intro_started := false


func _start_rock_dialog() -> void:
	# 커다란 바위 발견: 우체부 아저씨가 곡괭이 채광을 보여준 뒤 곡괭이를 건네준다
	story_cutscene = true
	_rock_intro_started = true
	_postman_state = "mine_demo"  # 대사가 진행되는 동안 바위 옆으로 걸어간다
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
		{"text": "「이런, 하필 여기서 길이 막혀버렸구먼.」"},
		{"text": "「이 정도로 큰 돌은 그냥 지나갈 수가 없겠어.」"},
		{"text": "(우체부 아저씨가 가방에서 낡은 나무 곡괭이를 꺼낸다...)"},
		{"text": "「잠깐만 기다리게.」"},
		{"text": "「이 곡괭이라면 저 돌을 치울 수 있을 걸세.」"},
		{"text": "(우체부 아저씨가 곡괭이로 바위를 몇 번 캐 보인다...)", "event": _rock_demo},
		{"text": "「자, 한번 자네가 직접 해보게.」", "event": _story_give_pickaxe},
		{"text": "「바위도 나무와 마찬가지로 대상에 가까이 가서 E 키를 누르면 캘 수 있다네.」"},
	], _end_rock_intro)


# 곡괭이 전달 마무리 — 대화가 도중에 끊겨도 여기로 복구된다
func _end_rock_intro() -> void:
	if GameData.story_rock_state != 0:
		return
	story_cutscene = false
	GameData.story_rock_state = 1
	if not GameData.is_tool_unlocked("pickaxe"):
		GameData.unlocked_tools.append("pickaxe")  # 대화를 스킵해도 지급 보장
	if _postman != null:
		_postman_state = "follow"
	hud.show_message("곡괭이를 가방(I) 슬롯에 장착하고, 바위를 클릭한 뒤 E로 캐보자!", 6.0)


func _rock_demo() -> void:
	# 채광 시연: 바위에 곡괭이질 3번 (효과음 + 돌조각, 바위는 줄지 않는다)
	for i in 3:
		get_tree().create_timer(0.35 + 0.5 * i).timeout.connect(func() -> void:
			if objects.has(STORY_ROCK):
				Sound.play_sfx("sfx_pick", 0.15)
				spawn_particles(STORY_ROCK, "stone"))


func _story_give_pickaxe() -> void:
	if not GameData.is_tool_unlocked("pickaxe"):
		GameData.unlocked_tools.append("pickaxe")
	hud.reward_toast("낡은 나무 곡괭이 × 1", tex["icon_pickaxe"])
	hud.show_message("곡괭이는 슬롯에 장착하기 전에는 쓸 수 없다.", 5.0)


func _story_rock_mined() -> void:
	# 커다란 바위를 모두 캐면: 돌 획득 -> 우체부 아저씨의 칭찬 -> 곡괭이 돌려주기 목표
	if GameData.story_phase != "rock" or GameData.story_rock_state != 1:
		return
	GameData.story_rock_state = 2
	hud.reward_toast("돌 × %d" % BIGROCK_STONE, tex["icon_stone"])
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if dialog.visible or ui_open():
			return  # 창이 열려 있으면 말을 걸 때 같은 안내가 나온다
		dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_happy"], [
			{"text": "「잘했네. 이제 길이 열렸구먼.」"},
		], func() -> void:
			hud.show_message("우체부 아저씨에게 곡괭이를 돌려주자 (E: 대화)", 6.0)))


func _start_pickaxe_return_dialog() -> void:
	# 곡괭이를 돌려주려 하면 정식으로 건네준다 -> 퀘스트 5 완료, 마을로 출발
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	story_cutscene = true
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
		{"text": "(곡괭이를 우체부 아저씨에게 돌려주려 했다...)"},
		{"text": "「아, 그건 자네가 가지게.」",
			"portrait": tex["npc_postman_portrait_happy"]},
		{"text": "「앞으로도 이런 돌을 만날 일이 있을 테니 잘 써보게.」"},
		{"text": "「그럼 %s, 이제 마을로 가 보세나!」" % nm},
	], _end_rock_quest)


func _end_rock_quest() -> void:
	# 퀘스트 5 완료: 곡괭이 정식 획득. 이후 튜토리얼 없이 마을로 향한다.
	story_cutscene = false
	GameData.story_rock_state = 3
	GameData.story_phase = "travel"
	hud.quest_toast("마을로 가는 길을 열어보자")
	hud.reward_toast("나무 곡괭이 (정식 획득)", tex["icon_pickaxe"])
	_apply_story_camera()
	_apply_story_visibility()
	hud.show_message("우체부 아저씨와 함께 마을로 가자! (화살표 방향)", 6.0)
	save_now()


# ---- 밤 몬스터: 지네 (21시 이후 야외에서 등장, 아침에 사라진다) ----
# 밤늦게까지 밖에서 채집하는 것이 위험해지도록 만드는 요소.

var night_mobs: Array = []  # [{node, spr, anim}]
var _mob_hit_cd := 0.0
var _mob_spawn_cd := 0.0


func _update_night_mobs(delta: float) -> void:
	_mob_hit_cd = maxf(0.0, _mob_hit_cd - delta)
	var outdoors := not interior.visible and not cave.visible \
		and GameData.story_phase == "done" and not Net.is_guest()
	if not GameData.is_deep_night() or not outdoors:
		if not night_mobs.is_empty():
			for m in night_mobs:
				m.node.queue_free()
			night_mobs.clear()
		return
	# 최대 2마리, 플레이어에서 조금 떨어진 곳에서 스멀스멀 나타난다
	_mob_spawn_cd -= delta
	if night_mobs.size() < 2 and _mob_spawn_cd <= 0.0:
		_mob_spawn_cd = 6.0
		var ang := randf() * TAU
		var node := Node2D.new()
		node.position = player.position + Vector2.from_angle(ang) * 380.0
		var spr := Sprite2D.new()
		spr.texture = tex["mob_centipede_0"]
		spr.scale = Vector2(1.4, 1.4)
		node.add_child(spr)
		world.add_child(node)
		night_mobs.append({"node": node, "spr": spr, "anim": 0.0})
		hud.show_message("어둠 속에서 무언가 기어오는 소리가 들린다...", 4.0)
	for m in night_mobs:
		m.anim += delta
		var to: Vector2 = player.position - m.node.position
		if to.length() > 8.0:
			m.node.position += to.normalized() * 55.0 * delta
		m.spr.texture = tex["mob_centipede_%d" % (int(m.anim * 8.0) % 2)]
		m.spr.flip_h = to.x > 0.0  # 머리가 진행 방향을 향한다
		# 접촉 피해
		if to.length() < 22.0 and _mob_hit_cd <= 0.0 and not ui_open():
			_mob_hit_cd = 1.2
			GameData.energy = maxf(0.0, GameData.energy - 10.0)
			Sound.play_sfx("sfx_chop", 0.2)
			spawn_particles(player_tile(), "stone")
			hud.show_message("지네에게 물렸다! 밤의 숲은 위험하다...", 3.0)
			player.position += (player.position - m.node.position).normalized() * 36.0
			if GameData.energy <= 0.0 and not day_transitioning:
				hud.show_message("정신을 잃고 쓰러졌다...")
				_fade_next_day(true)


# ---- 집 건설 (스토리 1 완료 후 집터에서 직접 짓는다) ----

func _open_build_dialog() -> void:
	dialog.open("집터",
		"할아버지가 남긴 집터다.\n재료를 모아 직접 집을 지어야 한다.\n\n필요 재료: 목재 %d (보유 %d)" %
			[GameData.HOUSE_BUILD_WOOD, GameData.wood], [
		["집 짓기", _build_house],
		["닫기", null],
	])


func _build_house() -> void:
	if GameData.wood < GameData.HOUSE_BUILD_WOOD:
		dialog.set_body("목재가 부족하다... (%d/%d)\n도끼로 나무를 베어 목재를 모으자." %
			[GameData.wood, GameData.HOUSE_BUILD_WOOD])
		return
	GameData.wood -= GameData.HOUSE_BUILD_WOOD
	GameData.house_lv = 1
	_remove_object(HOME_SITE)
	for y in range(HOME_ANCHOR.y, HOME_ANCHOR.y + 4):
		for x in range(HOME_ANCHOR.x, HOME_ANCHOR.x + 5):
			objects[Vector2i(x, y)] = {"kind": "house", "hp": 0}
	_spawn_house_node(HOME_ANCHOR)
	Sound.play_sfx("sfx_place")
	dialog.set_body("우리집 완성!\n아직 안은 텅 비어 있다.\n침대(목재 %d)를 만들어야 잠을 잘 수 있다." %
		GameData.BED_WOOD)
	hud.quest_toast("집 짓기")
	save_now()


# ---- 마을 발전 (빈 부지에 건물을 하나씩 세운다) ----
# 처음 마을에는 건물이 하나도 없다. 이장에게 이야기하면 정해진 순서대로
# 재료를 모아 건물을 짓고, 그때마다 마을의 모습과 기능이 늘어난다.

func _next_village_build() -> String:
	for pid in VILLAGE_BUILD_ORDER:
		if not GameData.village_built.has(pid):
			return pid
	return ""


func _open_village_build_dialog() -> void:
	var pid := _next_village_build()
	if pid == "":
		dialog.open("마을 발전",
			"지금 지을 수 있는 건물은 다 세웠네.\n마을이 제법 그럴듯해졌구먼!")
		return
	var plot: Dictionary = VILLAGE_PLOTS[pid]
	var cost: Array = VILLAGE_BUILD_COST[pid]
	dialog.open("마을 발전 — %s" % plot.name,
		"%s(을)를 지을 자리는 이미 비워 두었네.\n재료만 모아 오면 마을 사람들과 함께 세우겠네.\n\n필요 재료: 목재 %d (보유 %d) · 석재 %d (보유 %d)" %
			[plot.name, cost[0], GameData.wood, cost[1], GameData.stone], [
		["%s 짓기" % plot.name, _build_village_building.bind(pid)],
		["나중에", null],
	])


func _build_village_building(pid: String) -> void:
	var plot: Dictionary = VILLAGE_PLOTS[pid]
	var cost: Array = VILLAGE_BUILD_COST[pid]
	if GameData.wood < int(cost[0]) or GameData.stone < int(cost[1]):
		dialog.set_body("재료가 아직 부족하네...\n\n목재 %d/%d · 석재 %d/%d" %
			[GameData.wood, cost[0], GameData.stone, cost[1]])
		return
	GameData.wood -= int(cost[0])
	GameData.stone -= int(cost[1])
	GameData.village_built.append(pid)
	var a: Vector2i = plot.anchor
	for y in range(a.y, a.y + 4):
		for x in range(a.x, a.x + 5):
			objects[Vector2i(x, y)] = {"kind": "house", "hp": 0}
	_spawn_house_node(a)
	_sync_village_npcs()
	Sound.play_sfx("sfx_place")
	hud.quest_toast("%s 완공!" % plot.name)
	dialog.set_body("%s(이)가 세워졌네!\n마을이 조금씩 살아나는구먼." % plot.name)
	queue_redraw()
	save_now()


# 동행 중 우체부에게 말을 걸면 지금 단계에 맞는 짧은 안내를 해 준다.
# 도끼 사용법 설명은 아직 장착 전(equip 단계)에만 나온다 — 이후엔 반복하지 않는다.
func _talk_to_postman() -> void:
	match GameData.story_phase:
		"equip":
			dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
				{"text": "「그건 나무를 베기 위한 도구라네.」"},
				{"text": "「숲을 지나가려면 그 도끼로 나무를 베어 길을 만들어야 할 걸세.」"},
				{"text": "「가방을 열어 도끼를 슬롯에 넣어두게.」"},
				{"text": "「숫자키를 누르면 슬롯에 넣어둔 도구를 빠르게 꺼낼 수 있다네.」"},
			], Callable())
		"chop":
			dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
				{"text": "「도끼를 챙겼구먼. 앞의 나무를 골라 베어보게.」"},
			], Callable())
		"path":
			dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
				{"text": "「이 숲길을 따라 가보세. 막힌 나무는 자네가 부탁하네.」"},
			], Callable())
		"map":
			dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
				{"text": "「M 키를 누르면 지도를 볼 수 있다네.」"},
			], Callable())
		"rock":
			match GameData.story_rock_state:
				1:
					dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
						{"text": "「곡괭이도 도끼처럼 가방(I)에서 슬롯에 넣고 숫자키로 꺼내야 쓸 수 있다네.」"},
						{"text": "「준비되면 바위를 클릭한 뒤 E 키로 캐보게.」"},
					], Callable())
				2:
					_start_pickaxe_return_dialog()
				_:
					dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
						{"text": "「길을 따라 계속 가보세.」"},
					], Callable())
		_:
			dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_happy"], [
				{"text": "「마을은 동쪽일세. 같이 가세나.」"},
			], Callable())


func _start_u_intro_dialog() -> void:
	if dialog.visible or ui_open():
		# 다른 창이 열려 있으면 잠시 뒤에 다시 시도
		get_tree().create_timer(2.0).timeout.connect(_start_u_intro_dialog)
		return
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_normal"], [
		{"text": "「계속 같은 일을 하다 보면 자연스럽게 실력이 늘기도 한다네.」"},
		{"text": "「자신의 능력이 얼마나 늘었는지는 U를 눌러 확인해보게.」"},
	], func() -> void:
		hud.show_message("U 키를 눌러 능력치 창을 확인해 보자", 6.0))


func _update_u_intro() -> void:
	# U 안내: 창을 실제로 열어본 뒤 닫으면 완료 처리하고 스토리로 복귀
	if GameData.u_intro_state == 1 and stats_ui.visible:
		GameData.u_intro_state = 2
	elif GameData.u_intro_state == 2 and not stats_ui.visible:
		GameData.u_intro_state = 3
		hud.quest_toast("자신의 능력 확인해보기")


# 지나갈 수 있는 칸만 밟는 최단 경로 (BFS). 반환값은 칸 중심의 월드 좌표 배열.
# 길이 아예 없으면 빈 배열을 돌려준다.
func _tile_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return []
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var found := false
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			found = true
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if prev.has(n) or not is_passable(n):
				continue
			prev[n] = cur
			queue.append(n)
	if not found:
		return []
	var path: Array = []
	var at := goal
	while at != start:
		path.push_front(Vector2(at.x * TILE + 16, at.y * TILE + 16))
		at = prev[at]
	return path


func _story_chief() -> Node2D:
	for n in npcs:
		if n.id == "chief":
			return n
	return null


func _start_delivery_dialog() -> void:
	var chief_normal: Texture2D = tex["npc_chief_portrait_normal"]
	var chief_happy: Texture2D = tex["npc_chief_portrait_happy"]
	var nm := GameData.player_name if GameData.player_name != "" else "친구"
	dialog.open_seq("우체부 아저씨", tex["npc_postman_portrait_happy"], [
		{"text": "「이장님! 편지를 가지고 왔습니다.」"},
		{"text": "「오, 우체부 양반. 그 험한 숲길을 뚫고 왔는가!」",
			"name": "이장 덕수", "portrait": chief_normal},
		{"text": "「여기 %s(이)가 길을 열어 준 덕분입니다.」" % nm},
		{"text": "「%s(이)라고 했나. 교진 마을에 온 것을 환영하네!」" % nm,
			"name": "이장 덕수", "portrait": chief_happy},
		{"text": "「마을 서쪽 큰길가에 빈 집터가 하나 있네. 자네가 쓰게.」",
			"name": "이장 덕수", "portrait": chief_happy},
		{"text": "「그리고 이건 새로 온 사람에게 주는 우리 마을의 선물일세.」",
			"name": "이장 덕수", "portrait": chief_normal, "event": _story_give_hoe},
		{"text": "「호미로 땅을 갈아 밭을 만들면, 이 마을에서 살아갈 수 있을 걸세.」",
			"name": "이장 덕수", "portrait": chief_happy},
	], _end_delivery)


func _story_give_hoe() -> void:
	# 정착 준비: 이장이 환영 선물로 호미를 건넨다 (밭갈기 목표의 시작)
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")
	hud.reward_toast("호미 × 1", tex["icon_hoe"])
	hud.show_message("호미는 가방(I)에서 슬롯에 넣어야 쓸 수 있다.", 5.0)


func _end_delivery() -> void:
	story_cutscene = false
	GameData.story_phase = "done"
	_apply_story_camera()
	_apply_story_visibility()
	hud.quest_toast("이장에게 편지 전달")
	if not GameData.is_tool_unlocked("hoe"):
		GameData.unlocked_tools.append("hoe")  # 대화를 스킵해도 지급 보장
	hud.show_message("메인 스토리 1 완료! 호미로 밭을 갈고, 집터(E)에 집을 지어 정착하자.", 6.0)
	if _postman != null:
		_postman_path = _tile_path(
			Vector2i(int(_postman.position.x / TILE), int(_postman.position.y / TILE)),
			Vector2i(VILLAGE_EXIT_X, 1))
		_postman_fade = 1.0
		_postman_state = "leave"
	save_now()


func _snap_story(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path + name + ".png")


const STORY_PAGES := [
	["탐험가 할아버지", "나의 할아버지는 유명한 탐험가이자\n연금술 연구자였다.\n\n평생 신비한 생명체와 전설 속 재료를 찾아\n세계 곳곳을 누비셨다."],
	["비웃음", "사람들은 할아버지의 연구를\n'허황된 꿈'이라며 비웃었다.\n\n하지만 할아버지는 단 한 번도\n포기하지 않으셨다."],
	["이별", "수많은 연구 노트와 기록을 남기고도,\n할아버지는 끝내 마지막 연구를\n완성하지 못한 채 세상을 떠나셨다.\n\n무엇을 만들려 하셨는지는\n아무도 알지 못한다."],
	["나무 상자", "장례식이 끝난 뒤,\n부모님이 낡은 나무 상자를 건네주셨다.\n\n안에는 대부분 비어 있는 연구 노트 한 권과\n손으로 눌러쓴 편지 한 통."],
	["할아버지의 편지", "\"이 편지를 읽고 있다면, 나는 이미 떠났겠구나.\n내가 마지막까지 조사하던 곳은 '교진 마을'이다.\n그곳에 내가 평생 찾던 답이 있을지도 모른다.\n\n...내가 이루지 못한 꿈을,\n네가 이어주었으면 좋겠다.\""],
	["교진 마을로", "할아버지가 무엇을 찾고 계셨는지,\n나는 아직 아무것도 모른다.\n\n하지만 상자 속 빈 노트가\n왠지 나를 부르는 것 같았다.\n\n나는 짐을 싸서 교진 마을로 향했다."],
	["물려받은 농장", "마을 어귀, 할아버지가 머물던 작은 농장.\n오래 방치되어 잡초가 무성하고\n시설은 낡아 있었다.\n\n당분간은... 여기서 살아가 보자.\n농사도 짓고, 이웃도 사귀면서."],
]

# 진 엔딩: 전설 재료 7종을 모아 최후의 연금술로 '유니콘의 뿔'을 완성한다.
# (최종 목표는 게임 내에서 이 순간까지 절대 공개되지 않는다)
const ENDING_PAGES := [
	["마지막 연금술", "연구실 책상 위에 일곱 재료를 늘어놓았다.\n\n달빛 작물, 황금잉어, 세계수 가지,\n별빛 광석, 유령의 정수, 황금 달걀,\n그리고... 할아버지의 기억 조각."],
	["완성되는 노트", "재료를 노트의 마지막 장에 겹쳐 놓자,\n빈 페이지에 글씨가 스며들 듯 떠올랐다.\n\n할아버지가 평생 찾아 헤매던 것.\n그것은 자연 어디에도 없는 재료 —\n일곱 개의 정성이 모여야만 태어나는 것."],
	["유니콘의 뿔", "빛이 잦아들자, 책상 위에는\n나선형으로 빛나는 뿔 하나가 놓여 있었다.\n\n세상에 단 하나뿐인, 유니콘의 뿔.\n\n사람들이 비웃던 할아버지의 연구는\n허황된 꿈이 아니었다."],
	["이어진 꿈", "'내가 이루지 못한 꿈을\n네가 이어주었으면 좋겠다.'\n\n...할아버지, 보이시나요.\n농사를 짓고, 물고기를 잡고,\n사람들과 웃고 지내던 그 모든 날들이\n전부 할아버지의 연구였어요.\n\n그리고 오늘, 그 꿈이 완성됐어요."],
]

var _story_idx := 0
var _story_pages: Array = []
var _story_mode := "intro"  # "intro": 오프닝 / "ending": 엔딩
var story_layer: CanvasLayer
var _story_title: Label
var _story_body: Label
var _story_buttons: HBoxContainer


func _show_intro() -> void:
	hud.visible = false
	fade_rect.color.a = 0.0  # 농장이 보이는 채로 편지지 연출
	_story_mode = "intro"
	_story_pages = STORY_PAGES
	_build_story_ui()
	_story_idx = 0
	_show_story_page()


func _build_story_ui() -> void:
	story_layer = CanvasLayer.new()
	story_layer.layer = 60
	add_child(story_layer)

	# 양피지 편지 패널 (밝은 배경 + 진한 글씨)
	var panel := PanelContainer.new()
	panel.position = Vector2(210, 90)
	panel.custom_minimum_size = Vector2(540, 315)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.88, 0.74)
	style.border_color = Color(0.55, 0.42, 0.26)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	story_layer.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	_story_title = Label.new()
	_story_title.add_theme_color_override("font_color", Color(0.5, 0.32, 0.12))
	_story_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_story_title)

	_story_body = Label.new()
	_story_body.add_theme_color_override("font_color", Color(0.24, 0.17, 0.09))
	_story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_story_body)

	_story_buttons = HBoxContainer.new()
	_story_buttons.add_theme_constant_override("separation", 10)
	_story_buttons.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_story_buttons)


func _show_story_page() -> void:
	for c in _story_buttons.get_children():
		c.queue_free()

	# 페이지 번호 (왼쪽) + 버튼 (오른쪽). 오프닝은 마지막에 환영 페이지가 하나 더 있다
	var total := _story_pages.size() + (1 if _story_mode == "intro" else 0)
	var pnum := Label.new()
	pnum.text = "%d / %d" % [_story_idx + 1, total]
	pnum.add_theme_color_override("font_color", Color(0.62, 0.5, 0.34))
	_story_buttons.add_child(pnum)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_buttons.add_child(spacer)

	if _story_idx > 0:
		_story_add_button("< 이전", _prev_story_page)
	if _story_idx < _story_pages.size():
		var page: Array = _story_pages[_story_idx]
		_story_title.text = page[0]
		_story_body.text = page[1]
		if _story_mode != "intro" and _story_idx == _story_pages.size() - 1:
			_story_add_button("농장 생활 계속하기", _close_story)
		else:
			_story_add_button("다음 >", _next_story_page)
			_story_add_button("건너뛰기 >>", func() -> void:
				Sound.play_sfx("sfx_ui")
				_story_idx = _story_pages.size() - (0 if _story_mode == "intro" else 1)
				_show_story_page())
	else:
		_story_title.text = "교진 마을로 가는 길"
		_story_body.text = "가진 것은 할아버지의 낡은 연구 노트(N) 하나.\n\n마을로 가려면 저 우거진 숲을\n지나야 한다고 한다.\n\n화면 위 '목표'를 따라 천천히 나아가자!"
		_story_add_button("시작하기", _end_intro)


func _prev_story_page() -> void:
	Sound.play_sfx("sfx_ui")
	_story_idx -= 1
	_show_story_page()


# 부지/엔딩 스토리 닫기 (오프닝과 달리 튜토리얼로 이어지지 않는다)
func _close_story() -> void:
	Sound.play_sfx("sfx_ui")
	if story_layer != null:
		story_layer.queue_free()
		story_layer = null
	hud.visible = true


# 최후의 연금술 (연구 노트에서 재료 7종을 모두 모으면 실행 가능)
func show_ending() -> void:
	GameData.ending_seen = true
	save_now()
	hud.visible = false
	_story_mode = "ending"
	var kills := 0
	for k in GameData.mob_kills:
		kills += int(GameData.mob_kills[k])
	var fish_n := 0
	for k in GameData.fish_caught:
		fish_n += int(GameData.fish_caught[k])
	var prog: Dictionary = GameData.note_progress()
	_story_pages = ENDING_PAGES.duplicate()
	_story_pages.append(["연구의 기록",
		"함께한 날: %d일째\n연구 노트: %d/%d 페이지\n낚은 물고기: %d마리 · 처치한 몬스터: %d\n만든 요리: %d종류\n\n...그리고 교진 마을의 나날은 계속된다." %
		[GameData.day, int(prog.filled), int(prog.total), fish_n, kills,
		GameData.recipes_cooked.size()]])
	_build_story_ui()
	_story_idx = 0
	_show_story_page()


func _story_add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_story_buttons.add_child(b)


func _next_story_page() -> void:
	Sound.play_sfx("sfx_ui")
	_story_idx += 1
	_show_story_page()


func _end_intro() -> void:
	if story_layer != null:
		story_layer.queue_free()
		story_layer = null
	hud.visible = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.6)
	# 숲 앞에서 잠시 멈춰 할아버지의 말을 떠올리는 연출 (퀘스트 1은 그 후에 시작)
	if GameData.story_phase == "enter":
		tw.tween_callback(_start_forest_monologue)


func _start_forest_monologue() -> void:
	story_cutscene = true
	dialog.open_seq("나", null, [
		{"text": "(눈앞에 우거진 숲이 펼쳐져 있다...)"},
		{"text": "(문득, 할아버지가 하셨던 말이 떠오른다.)"},
		{"text": "『집으로 가는 길이 조금 힘들 거다.』"},
		{"text": "(그때는 무슨 뜻인지 몰랐는데...)"},
		{"text": "(...이제야 알 것 같다.)"},
		{"text": "(그래도 집으로 가려면, 이 숲을 지나가는 수밖에 없다.)"},
	], _end_forest_monologue)


func _end_forest_monologue() -> void:
	story_cutscene = false
	hud.show_message("퀘스트 시작: 숲 안으로 들어가 보자", 6.0)


func _skip_tutorial() -> void:
	GameData.tutorial = {"active": false}
	GameData.unlock_all_tools()
	GameData.story_phase = "done"
	_apply_story_camera()
	if _postman != null:
		_postman.queue_free()
		_postman = null
	story_cutscene = false
	_end_intro()


func tutorial_notify(flag: String) -> void:
	var tut: Dictionary = GameData.tutorial
	if not tut.get("active", false) or tut.get(flag, true):
		return
	tut[flag] = true
	Sound.play_sfx("sfx_catch")

	# 목표 달성 보상 (돈/자원/씨앗)
	var msg := "목표 달성!"
	var reward: Dictionary = GameData.TUTORIAL_REWARDS.get(flag, {})
	var parts := []
	if reward.has("money"):
		GameData.money += int(reward.money)
		parts.append("%dG" % int(reward.money))
	if reward.has("wood"):
		GameData.wood += int(reward.wood)
		parts.append("목재 %d" % int(reward.wood))
	if reward.has("stone"):
		GameData.stone += int(reward.stone)
		parts.append("석재 %d" % int(reward.stone))
	if reward.has("seeds"):
		for sid in reward.seeds:
			GameData.seeds[sid] += int(reward.seeds[sid])
			parts.append("%s 씨앗 x%d" % [GameData.CROPS[sid].name, int(reward.seeds[sid])])
	if not parts.is_empty():
		msg += " 보상: " + ", ".join(parts)
		hud.reward_toast(", ".join(parts), tex["icon_coin"])
	if Net.is_host():
		_broadcast_stats()

	# 새 도구 해금
	var unlocked: Array = GameData.TUTORIAL_UNLOCKS.get(flag, [])
	if not unlocked.is_empty():
		var names := []
		for id in unlocked:
			if not GameData.unlocked_tools.has(id):
				GameData.unlocked_tools.append(id)
			names.append(GameData.TOOL_KOR[id])
		msg += " 새 도구 해금: " + ", ".join(names)
	hud.show_message(msg)

	for pair in GameData.TUTORIAL_ORDER:
		if not tut.get(pair[0], false):
			return
	tut["active"] = false
	dialog.open("기본 안내 완료!",
		"이제 진짜 농장 생활 시작이다!\n\n[기본 키]\nB: 상점 (씨앗/판매/동물/강화/도감 탭)\nE: 상호작용 (대화/취침/판매/쓰다듬기)\nTab: 씨앗 바꾸기 / F5: 저장 / Esc: 메뉴\n\n동쪽 마을의 주민, 의뢰 게시판도 잊지 말자.\n계절이 바뀌기 전에 수확을 끝낼 것!",
		[["좋아!", null]])


# ---- NPC 대화 / 선물 / 퀘스트 ----

func _talk_to(npc: Node2D) -> void:
	var def: Dictionary = GameData.NPCS[npc.id]
	if not npc.talked_today:
		npc.talked_today = true
		GameData.affinity[npc.id] = int(GameData.affinity[npc.id]) + 2
	var lines: Array = def.lines
	var line: String = lines[randi() % lines.size()]
	var aff := mini(int(GameData.affinity[npc.id]), 100)
	# 호감도가 오르면 비밀 이야기(할아버지의 과거)가 섞여 나온다
	if aff >= 100 and def.has("secret100") and randf() < 0.4:
		line = def.secret100
	elif aff >= 50 and def.has("secret50") and randf() < 0.4:
		line = def.secret50
	var hearts := int(aff / 10.0)
	var title := "%s %s (%d/100)" % [def.name, "♥".repeat(maxi(hearts, 0)), aff]
	if aff >= 50:
		line += "\n(친밀한 사이다! 특전 발동 중)"
	# 호감도 100: 할아버지의 기억 조각을 건네받는다 (1회)
	if aff >= 100 and not GameData.memory_given:
		GameData.memory_given = true
		line = def.get("secret100", line)
		gain_legend("memory_piece")
		if Net.is_host():
			_broadcast_stats()
	var choices := [
		["선물하기", _open_gift_picker.bind(npc.id)],
		["대화 끝", null],
	]
	# 이장은 마을 발전(빈 부지에 건물 세우기)을 맡고 있다
	if npc.id == "chief" and GameData.story_phase == "done":
		choices.insert(0, ["마을 발전 이야기", _open_village_build_dialog])
	dialog.open_seq(title, _npc_portrait(npc.id), [
		{"text": line, "choices": choices},
	])


func _npc_portrait(npc_id: String, happy := false) -> Texture2D:
	# 호감도 50+ 또는 선물 직후엔 웃는 얼굴
	var expr := "happy" if (happy or int(GameData.affinity[npc_id]) >= 50) else "normal"
	return tex["npc_%s_portrait_%s" % [npc_id, expr]]


var _gift_layer: CanvasLayer = null


# 선물은 플레이어가 직접 고른다 — 가진 수확물/생산물 목록에서 선택
func _open_gift_picker(npc_id: String) -> void:
	var entries: Array = []
	for id: String in GameData.CROP_IDS:
		if int(GameData.produce.get(id, 0)) > 0:
			entries.append(["produce", id, str(GameData.CROPS[id].name),
				int(GameData.produce[id])])
	for id: String in GameData.ITEM_IDS:
		if int(GameData.items.get(id, 0)) > 0:
			entries.append(["item", id, str(GameData.ITEMS[id].name),
				int(GameData.items[id])])
	if entries.is_empty():
		dialog.set_body("선물할 것이 없다... 수확물이나 생산물이 필요하다.")
		return
	_close_gift_picker()
	_gift_layer = CanvasLayer.new()
	_gift_layer.layer = 30
	var panel := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.91, 0.71, 0.42, 0.98)
	st.border_color = Color(0.43, 0.24, 0.11)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", st)
	panel.position = Vector2(300, 110)
	panel.size = Vector2(360, 320)
	_gift_layer.add_child(panel)
	var lab := Label.new()
	lab.text = "무엇을 선물할까?"
	lab.position = Vector2(0, 8)
	lab.size = Vector2(360, 24)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color(0.29, 0.16, 0.06))
	panel.add_child(lab)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 38)
	scroll.size = Vector2(332, 234)
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(322, 0)
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for e: Array in entries:
		var btn := Button.new()
		btn.text = "%s  x%d" % [e[2], e[3]]
		btn.custom_minimum_size = Vector2(322, 30)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_give_gift.bind(npc_id, str(e[0]), str(e[1])))
		list.add_child(btn)
	var cancel := Button.new()
	cancel.text = "그만두기"
	cancel.position = Vector2(130, 280)
	cancel.size = Vector2(100, 28)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_close_gift_picker)
	panel.add_child(cancel)
	add_child(_gift_layer)


func _close_gift_picker() -> void:
	if _gift_layer != null:
		_gift_layer.queue_free()
		_gift_layer = null


func _give_gift(npc_id: String, kind: String, item_id: String) -> void:
	# 고른 선물을 건넨다
	var gift_name := ""
	if kind == "produce" and int(GameData.produce.get(item_id, 0)) > 0:
		GameData.produce[item_id] -= 1
		gift_name = str(GameData.CROPS[item_id].name)
	elif kind == "item" and int(GameData.items.get(item_id, 0)) > 0:
		GameData.items[item_id] -= 1
		gift_name = str(GameData.ITEMS[item_id].name)
	_close_gift_picker()
	if gift_name == "":
		dialog.set_body("그건 이제 가지고 있지 않다...")
		return
	var before := int(GameData.affinity[npc_id])
	if Net.is_guest():
		_req_gift.rpc_id(1, npc_id, kind, item_id)  # 호스트가 차감/가산 후 전파
	GameData.affinity[npc_id] = before + 10
	Sound.play_sfx("sfx_heart")
	if Net.is_host():
		_broadcast_stats()
	dialog.set_portrait(_npc_portrait(npc_id, true))
	var body := "%s을(를) 선물했다! 정말 좋아한다. ♥" % gift_name
	if before < 50 and before + 10 >= 50:
		if npc_id == "merchant":
			body += "\n\n[특전 해금] 민지의 씨앗 10% 할인!"
		else:
			body += "\n\n[특전 해금] 철수의 낚시 비법! 판정 구간 확대!"
	dialog.set_body(body)


func _open_quest_board() -> void:
	var q: Dictionary = GameData.quest
	if q.is_empty():
		dialog.open("의뢰 게시판", "오늘은 새 의뢰가 없다.", [["닫기", null]])
		return
	var crop: Dictionary = GameData.CROPS[q.crop]
	var text := "[납품 의뢰]\n%s %d개를 모아 오면 %dG를 드립니다." % [crop.name, q.qty, q.reward]
	if not q.accepted:
		dialog.open("의뢰 게시판", text, [
			["수락", _accept_quest],
			["닫기", null],
		])
	elif GameData.produce[q.crop] >= q.qty:
		dialog.open("의뢰 게시판", text + "\n(보유: %d개 - 납품 가능!)" % GameData.produce[q.crop], [
			["납품하기", _turn_in_quest],
			["닫기", null],
		])
	else:
		dialog.open("의뢰 게시판", text + "\n(진행중: %d/%d개)" % [GameData.produce[q.crop], q.qty],
			[["닫기", null]])


func _accept_quest() -> void:
	GameData.quest.accepted = true
	if Net.is_guest():
		_req_quest.rpc_id(1, "accept")
	elif Net.is_host():
		_broadcast_stats()
	dialog.set_body("의뢰를 수락했다! 작물을 모아서 다시 오자.")


func _turn_in_quest() -> void:
	var q: Dictionary = GameData.quest
	GameData.consume_produce(q.crop, int(q.qty))
	GameData.money += q.reward
	GameData.today_earned += int(q.reward)
	GameData.affinity["merchant"] = int(GameData.affinity["merchant"]) + 5
	Sound.play_sfx("sfx_coin")
	hud.reward_toast("%dG" % int(q.reward), tex["icon_coin"])
	dialog.set_body("납품 완료! %dG를 받았다. 내일 새 의뢰가 올라온다." % q.reward)
	GameData.quest = {}
	if Net.is_guest():
		_req_quest.rpc_id(1, "turnin")
	elif Net.is_host():
		_broadcast_stats()


# ---- 동물 ----

func spawn_animal(type: String, pos: Vector2 = Vector2.ZERO, fed: bool = false) -> void:
	var a: Node2D = preload("res://scripts/animal.gd").new()
	a.main = self
	a.type = type
	a.fed = fed
	if pos == Vector2.ZERO:
		var t := _find_free_tile_near(Vector2i(10, 7))
		pos = Vector2(t.x * TILE + 16, t.y * TILE + 16)
	a.position = pos
	animals.append(a)
	world.add_child(a)


func _find_free_tile_near(center: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := center + Vector2i(dx, dy)
				if is_passable(t):
					return t
	return START_TILE


# ---- 하루 진행 ----

func _fade_next_day(passed_out: bool) -> void:
	if day_transitioning:
		return
	day_transitioning = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.4)
	tw.tween_callback(_next_day.bind(passed_out))
	tw.tween_property(fade_rect, "color:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: day_transitioning = false)


# 나무 성장: 어린 나무(tree_15)는 며칠 지나면 다 자란 나무(tree_01)가 되고,
# 벤 자리에는 다음 날 어린 나무가 돋아 다시 자란다.
func _advance_tree_growth() -> void:
	for pos: Vector2i in objects:
		var o: Dictionary = objects[pos]
		if o.kind == "tree" and bool(o.get("young", false)):
			o["grow"] = int(o.get("grow", 2)) - 1
			if int(o.grow) <= 0:
				o.erase("young")
				o.erase("grow")
			_refresh_tree_sprite(pos)
	var keep := []
	for e in GameData.tree_regrow:
		var pos := Vector2i(int(e[0]), int(e[1]))
		var days := int(e[2]) - 1
		if days > 0:
			keep.append([pos.x, pos.y, days])
			continue
		# 자리가 비어 있고 밭/작물이 아니면 어린 나무가 돋는다 (차 있으면 소멸)
		if not objects.has(pos) and grid[pos.y][pos.x].ground == "grass" \
				and grid[pos.y][pos.x].crop_id == "":
			objects[pos] = {"kind": "tree", "hp": TREE_HP, "young": true, "grow": 2}
			_spawn_object_node(pos, "tree")
			_refresh_tree_sprite(pos)
	GameData.tree_regrow = keep


func _next_day(passed_out: bool) -> void:
	# 밤사이 밭은 마른다 (성장은 실시간 _growth_tick에서)
	for y in MAP_H:
		for x in MAP_W:
			var cell: Dictionary = grid[y][x]
			cell.watered = false
			cell.wet_min = 0.0

	if cave.visible:
		cave.visible = false  # 새벽이 되면 동굴에서 나온다
	var stats := [GameData.today_harvest, GameData.today_earned, GameData.today_spent]
	var prev_season := GameData.season()
	GameData.day += 1
	GameData.minutes = GameData.DAY_START
	GameData.energy = GameData.ENERGY_MAX * 0.5 if passed_out else GameData.ENERGY_MAX
	GameData.reset_daily()
	_advance_tree_growth()

	# 계절이 바뀌면 제철 아닌 작물은 시든다
	var season_changed := GameData.season() != prev_season
	var wilted := 0
	if season_changed:
		for y in MAP_H:
			for x in MAP_W:
				var cell: Dictionary = grid[y][x]
				if cell.crop_id != "" and not cell.dead \
						and GameData.season() not in GameData.CROPS[cell.crop_id].seasons:
					cell.dead = true
					wilted += 1
		_apply_season_visuals()

	# 비 오는 날은 밭이 하루 종일 젖어 있다
	if weather_now() == GameData.WEATHER_RAIN:
		for y in MAP_H:
			for x in MAP_W:
				if grid[y][x].ground == "soil":
					_wet(grid[y][x], WET_ALL_DAY)

	# 스프링클러는 주변 4칸을 하루 종일 적신다
	for pos: Vector2i in objects:
		if objects[pos].kind != "sprinkler":
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = pos + d
			if n.x >= 0 and n.y >= 0 and n.x < MAP_W and n.y < MAP_H \
					and grid[n.y][n.x].ground == "soil":
				_wet(grid[n.y][n.x], WET_ALL_DAY)

	# 축사가 있으면 굳은 날씨에도 동물들이 알아서 배부르다
	if GameData.barn_built and weather_now() != GameData.WEATHER_SUN:
		for a2 in animals:
			a2.fed = true

	# 동물 생산물 수거
	var collected := {}
	for a in animals:
		if a.fed:
			var product: String = GameData.ANIMALS[a.type].product
			GameData.items[product] += 1
			collected[product] = int(collected.get(product, 0)) + 1
			if a.type == "chicken" and randf() < 0.03 and int(GameData.items["golden_egg"]) == 0:
				GameData.items["golden_egg"] += 1
				collected["golden_egg"] = 1
		a.fed = false

	# 나무/돌이 조금씩 다시 자란다
	_respawn_resources()
	_respawn_forage()
	_spawn_bugs()

	tutorial_notify("slept")

	# NPC 일일 상태 리셋 + 새 의뢰
	for n in npcs:
		n.talked_today = false
	if GameData.quest.is_empty() or not GameData.quest.get("accepted", false):
		GameData.make_daily_quest()

	save_now()

	var note := ""
	for product in collected:
		note += "\n%s %d개를 얻었다!" % [GameData.ITEMS[product].name, collected[product]]
	if season_changed:
		note += "\n%s이 시작됐다!" % GameData.season_name()
	if wilted > 0:
		note += "\n작물 %d개가 시들어버렸다..." % wilted
	match weather_now():
		GameData.WEATHER_RAIN:
			note += "\n오늘은 비가 온다. 물주기는 쉬자! ☔"
		GameData.WEATHER_SNOW:
			note += "\n함박눈이 내린다. ☃"
	if passed_out:
		note += "\n쓰러져서 기력이 절반만 회복됐다..."

	var s_title := "- %s %d일 아침 -" % [GameData.season_name(), GameData.day_in_season()]
	var s_body := "어제 수확: %d개\n판매 수입: +%dG\n지출: -%dG\n소지금: %dG\n%s" \
		% [stats[0], stats[1], stats[2], GameData.money, note]
	summary.open(s_title, s_body)
	if Net.is_host():
		_net_new_day.rpc(_make_snapshot_json(), s_title, s_body)
	queue_redraw()


func _respawn_resources() -> void:
	for attempt in 6:
		var kind := "tree" if randf() < 0.5 else "rock"
		var chance := 0.4 if kind == "tree" else 0.3
		if randf() > chance:
			continue
		var pos := Vector2i(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2))
		var cell: Dictionary = grid[pos.y][pos.x]
		if objects.has(pos) or cell.ground != "grass" or cell.crop_id != "":
			continue
		if VILLAGE_REGION.has_point(pos) or ROAD.has_point(pos):
			continue  # 마을/길에는 리스폰하지 않는다
		if (pos - player_tile()).length() < 4.0:
			continue
		_place_object(pos, kind, TREE_HP if kind == "tree" else ROCK_HP)
		break


# 아침마다 열매/약초가 풀밭에 돋아난다 (최대 12개 유지)
func _respawn_forage() -> void:
	var count := 0
	for pos in objects:
		if String(objects[pos].kind).begins_with("forage_"):
			count += 1
	for attempt in 8:
		if count >= 12:
			break
		var pos := Vector2i(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2))
		var cell: Dictionary = grid[pos.y][pos.x]
		if objects.has(pos) or cell.ground != "grass" or cell.crop_id != "":
			continue
		if VILLAGE_REGION.has_point(pos) or ROAD.has_point(pos):
			continue
		var kind := "forage_berry" if randf() < 0.6 else "forage_herb"
		_place_object(pos, kind, 0)
		count += 1


# 곤충: 계절/시간대에 맞는 곤충들이 들판을 날아다닌다
var bugs: Array = []


func _spawn_bugs() -> void:
	for bnode in bugs:
		bnode.queue_free()
	bugs.clear()
	for bid in GameData.BUGS:
		var cond: Dictionary = GameData.BUGS[bid]
		if GameData.season() not in cond.seasons:
			continue
		for i in 3:
			var bnode: Node2D = preload("res://scripts/bug.gd").new()
			bnode.main = self
			bnode.bug_id = bid
			bnode.night_only = bool(cond.night)
			bnode.position = Vector2(randi_range(2, MAP_W - 2) * TILE,
				randi_range(2, MAP_H - 2) * TILE)
			bugs.append(bnode)
			world.add_child(bnode)


func nearby_bug() -> Node2D:
	for bnode in bugs:
		if bnode.visible and (bnode.position - player.position).length() < 40.0:
			return bnode
	return null


# ---- 저장 ----

func save_now() -> void:
	if Net.is_guest():
		return  # 저장은 호스트만
	var g := []
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			var c: Dictionary = grid[y][x]
			row.append([c.ground, int(c.wet_min), c.crop_id, int(c.crop_day),
				1 if c.dead else 0, 1 if c.get("half_fed", false) else 0])
		g.append(row)
	var objs := []
	for pos: Vector2i in objects:
		objs.append([pos.x, pos.y, objects[pos].kind, objects[pos].hp,
			1 if objects[pos].get("apple", false) else 0,
			1 if objects[pos].get("young", false) else 0,
			int(objects[pos].get("grow", 0)),
			1 if objects[pos].get("fixed", false) else 0])
	var anims := []
	for a in animals:
		anims.append([a.type, a.position.x, a.position.y, 1 if a.fed else 0])
	GameData.save_game(g, player.position, objs, anims)


func _apply_save(d: Dictionary) -> void:
	GameData.day = int(d.day)
	GameData.minutes = float(d.minutes)
	GameData.money = int(d.money)
	GameData.energy = float(d.energy)
	GameData.gender = str(d.get("gender", "m"))
	GameData.story_phase = str(d.get("main_story", "done"))
	GameData.tree_regrow = d.get("tree_regrow", [])
	GameData.player_name = str(d.get("player_name", ""))
	GameData.village_built = d.get("village_built", [])
	GameData.house_lv = int(d.get("house_lv", 0))
	GameData.has_bed = bool(d.get("has_bed", false))
	GameData.explored = {}
	for c in d.get("explored", []):
		GameData.explored[Vector2i(int(c[0]), int(c[1]))] = true
	GameData.trees_chopped = int(d.get("trees_chopped", 0))
	GameData.u_intro_state = int(d.get("u_intro", 0))
	GameData.story_rock_state = int(d.get("rock_state", 0))
	GameData.story_gates_left = int(d.get("gates_left", 0))
	GameData.wood = int(d.get("wood", 0))
	GameData.stone = int(d.get("stone", 0))
	for k in d.get("tool_level", {}):
		GameData.tool_level[k] = int(d.tool_level[k])
	var slots: Variant = d.get("tool_slots", null)
	if typeof(slots) == TYPE_ARRAY and slots.size() >= 9:
		GameData.tool_slots = []
		for t in slots:
			GameData.tool_slots.append(str(t))
		while GameData.tool_slots.size() < GameData.TOOL_SLOT_COUNT:
			GameData.tool_slots.append("")  # 칸 수가 늘어난 구버전 저장 호환
		if GameData.tool_slots.size() > GameData.TOOL_SLOT_COUNT:
			GameData.tool_slots.resize(GameData.TOOL_SLOT_COUNT)  # 12칸 -> 9칸 호환
	for k in d.seeds:
		GameData.seeds[k] = int(d.seeds[k])
	for k in d.produce:
		GameData.produce[k] = int(d.produce[k])
	for k in d.get("items", {}):
		GameData.items[k] = int(d.items[k])
	for k in d.get("fish_caught", {}):
		GameData.fish_caught[k] = int(d.fish_caught[k])
	for k in d.get("affinity", {}):
		GameData.affinity[k] = int(d.affinity[k])
	if d.has("quest") and typeof(d.quest) == TYPE_DICTIONARY and not d.quest.is_empty():
		GameData.quest = {
			"crop": d.quest.crop, "qty": int(d.quest.qty),
			"reward": int(d.quest.reward), "accepted": bool(d.quest.accepted),
		}
	# 구버전 저장에는 튜토리얼 정보가 없다 → 완료로 간주
	GameData.tutorial = d.get("tutorial", {"active": false})
	GameData.unlocked_tools = d.get("unlocked_tools", GameData.ALL_TOOLS.duplicate())
	for k in d.get("mob_kills", {}):
		GameData.mob_kills[k] = int(d.mob_kills[k])
	GameData.apply_skills_data(d.get("skills", {}))
	if d.has("furniture"):
		GameData.apply_furniture_data(d.furniture)
		if int(d.get("tile", 16)) != TILE:
			for furn in GameData.furniture:  # 구버전 집 좌표(640기준) → 960기준
				furn.x = float(furn.x) * 1.5
				furn.y = float(furn.y) * 1.5
	for k in d.get("recipes_cooked", {}):
		GameData.recipes_cooked[k] = int(d.recipes_cooked[k])
	GameData.owned_pets = d.get("owned_pets", [])
	GameData.active_pet = str(d.get("active_pet", ""))
	for k in d.get("forage_caught", {}):
		GameData.forage_caught[k] = int(d.forage_caught[k])
	for k in d.get("produce_silver", {}):
		GameData.produce_silver[k] = int(d.produce_silver[k])
	for k in d.get("produce_gold", {}):
		GameData.produce_gold[k] = int(d.produce_gold[k])
	GameData.barn_built = bool(d.get("barn_built", false))
	if GameData.barn_built and not objects.has(BARN_POS):
		objects[BARN_POS] = {"kind": "barn", "hp": 0}
		objects[BARN_POS + Vector2i(1, 0)] = {"kind": "barn_block", "hp": 0}
	var anim_scale := float(TILE) / float(d.get("tile", 16))
	for a in d.get("animals", []):
		spawn_animal(a[0], Vector2(float(a[1]), float(a[2])) * anim_scale, int(a[3]) == 1)
	# 구버전(16px 타일) 저장 좌표 환산
	var pos_scale := float(TILE) / float(d.get("tile", 16))
	player.position = Vector2(float(d.player[0]), float(d.player[1])) * pos_scale

	# 맵 크기가 다른 옛 저장이면 밭 상태는 버리고 진행 상황만 복원한다
	var g: Array = d.grid
	if g.size() != MAP_H or (g.size() > 0 and g[0].size() != MAP_W):
		player.position = Vector2(START_TILE.x * TILE + 16, START_TILE.y * TILE + 16)
		return
	for y in MAP_H:
		for x in MAP_W:
			var s: Array = g[y][x]
			var cell: Dictionary = grid[y][x]
			# 물 타일은 맵 생성 결과를 유지하고 경작 상태만 복원
			if cell.ground != "water" and s[0] != "water":
				cell.ground = s[0]
			# 구버전 호환: 0/1 플래그였으면 젖음 6시간으로 간주
			var wet := float(s[1])
			if wet == 1.0:
				wet = WET_MANUAL
			cell.wet_min = wet
			cell.watered = wet > 0.0
			cell.crop_id = s[2]
			# 구버전 호환: 일 단위(0~9)였으면 시간 단위(분)로 환산
			var growth := float(s[3])
			if growth > 0.0 and growth < 15.0:
				growth *= 60.0
			cell.crop_day = growth
			cell.dead = s.size() > 4 and int(s[4]) == 1
			cell.half_fed = s.size() > 5 and int(s[5]) == 1
	if d.has("objects"):
		objects.clear()
		for o in d.objects:
			var od := {"kind": o[2], "hp": int(o[3])}
			if o.size() > 4 and int(o[4]) == 1:
				od["apple"] = true
			if o.size() > 6 and int(o[5]) == 1:
				od["young"] = true
				od["grow"] = int(o[6])
			if o.size() > 7 and int(o[7]) == 1:
				od["fixed"] = true  # 스토리 울타리 (걷어낼 수 없다)
			objects[Vector2i(int(o[0]), int(o[1]))] = od


# ---- 루프 ----

func _process(delta: float) -> void:
	_story_update(delta)
	for ft in float_texts:
		ft.t += delta
	float_texts = float_texts.filter(func(ft: Dictionary) -> bool: return ft.t < 1.3)
	if not ui_open() or interior_only_open():
		if not Net.is_guest():
			# 시간은 호스트/솔로만 진행 (게스트는 동기화 수신)
			GameData.minutes += delta * MIN_PER_SEC
			if GameData.minutes >= GameData.DAY_END and not day_transitioning:
				_fade_next_day(true)
		water_timer += delta
		if water_timer > 0.8:
			water_timer = 0.0
			water_frame = 1 - water_frame
		_growth_timer += delta
		if _growth_timer >= 0.7:
			_growth_tick(_growth_timer * MIN_PER_SEC)
			_growth_timer = 0.0
		_update_mouse_target()
		_update_fishing(delta)
		if player_tile() != _last_explore_tile:
			_last_explore_tile = player_tile()
			GameData.mark_explored_at(_last_explore_tile)
		if player.walked > 40.0:
			tutorial_notify("moved")
	weather_time += delta
	# 체력은 동굴 밖에서 천천히 회복된다 (요리를 먹으면 즉시 회복)
	if not cave.visible:
		GameData.energy = minf(GameData.ENERGY_MAX, GameData.energy + delta * 2.0)
	_update_particles(delta)
	_update_night_mobs(delta)
	_update_tree_fade()
	_update_u_intro()
	_net_process(delta)
	_update_night()
	hud.refresh()
	queue_redraw()
	overlay.queue_redraw()
	if _shot_path != "":
		_debug_tick()


# 젖은 밭 위 작물은 실시간으로 자라고, 물기는 서서히 마른다
func _growth_tick(game_minutes: float) -> void:
	var changed := false
	for y in MAP_H:
		for x in MAP_W:
			var cell: Dictionary = grid[y][x]
			if float(cell.wet_min) <= 0.0:
				continue
			cell.wet_min = float(cell.wet_min) - game_minutes
			if float(cell.wet_min) <= 0.0:
				cell.wet_min = 0.0
				cell.watered = false
				changed = true
			if cell.crop_id != "" and not cell.dead and not _crop_thirsty(cell):
				var before_stage := _crop_texture(cell)
				cell.crop_day = float(cell.crop_day) + game_minutes * GameData.farm_growth_mult()
				# 절반을 막 넘겼다면 여기서 멈춘다 — 물을 한 번 더 줘야 한다
				if _crop_thirsty(cell):
					changed = true
				if _crop_texture(cell) != before_stage:
					changed = true
	if changed:
		queue_redraw()


# (자동 도구 선택은 제거됨 — 도구는 반드시 슬롯에 장착하고 숫자키/클릭으로
#  직접 선택해야 하며, 대상에 접근하는 것만으로는 아무 일도 일어나지 않는다)


func _update_night() -> void:
	var start := 18.0 * 60.0
	var a := clampf((GameData.minutes - start) / (6.0 * 60.0), 0.0, 1.0)
	var c := Color(1, 1, 1).lerp(Color(0.5, 0.48, 0.72), a)
	if weather_now() == GameData.WEATHER_RAIN:
		c *= Color(0.78, 0.8, 0.88)  # 비 오는 날은 어둑하게
	night.color = c


func _unhandled_input(event: InputEvent) -> void:
	if Net.is_guest() and not _net_ready:
		return  # 접속 완료 전에는 조작 금지
	if _name_layer != null:
		return  # 이름 입력 중에는 다른 조작을 받지 않는다
	if story_cutscene and _postman_state == "approach" and _postman != null \
			and event.is_action_pressed("ui_cancel"):
		# 걸어오는 연출 스킵: 우체부가 바로 도착해 말을 건다
		_postman.position = player.position + Vector2(-44, 0)
		_postman_state = "talk"
		_start_postman_dialog()
		get_viewport().set_input_as_handled()
		return
	if story_layer != null:
		# 스토리 연출 중 ESC = 스킵. 텍스트만 건너뛰고 후속 이벤트는 그대로 진행된다.
		if event.is_action_pressed("ui_cancel"):
			Sound.play_sfx("sfx_ui")
			if _story_mode == "intro":
				# 마지막 선택 페이지(시작하기/튜토리얼 건너뛰기)로 점프
				_story_idx = _story_pages.size()
				_show_story_page()
			else:
				_close_story()  # 부지/엔딩: 정상 종료 루틴 (HUD 복구 등)
			get_viewport().set_input_as_handled()
		return
	if ui_open():
		if event.is_action_pressed("ui_cancel"):
			shop.close()
			summary.close()
			map_ui.close()
			inventory_ui.close()
			quest_ui.close()
			note_ui.close()
			stats_ui.close()
			# 오프닝 스토리 중(화면이 어두울 때)에는 ESC로 대화창을 닫지 않는다
			if fade_rect == null or fade_rect.color.a < 0.5:
				dialog.close()
		elif event.is_action_pressed("open_map") and map_ui.visible:
			map_ui.close()
		elif event.is_action_pressed("open_inventory") and inventory_ui.visible:
			inventory_ui.close()
		elif event.is_action_pressed("open_quest") and quest_ui.visible:
			quest_ui.close()
		elif event.is_action_pressed("open_note") and note_ui.visible:
			note_ui.close()
		elif event.is_action_pressed("open_stats") and stats_ui.visible:
			stats_ui.close()
		return
	if event.is_action_pressed("open_map"):
		Sound.play_sfx("sfx_ui")
		map_ui.open()
		tutorial_notify("map")
		return
	if event.is_action_pressed("open_inventory"):
		Sound.play_sfx("sfx_ui")
		inventory_ui.toggle()
		return
	if event.is_action_pressed("open_quest"):
		Sound.play_sfx("sfx_ui")
		quest_ui.toggle()
		tutorial_notify("quest")
		return
	if event.is_action_pressed("open_note"):
		Sound.play_sfx("sfx_ui")
		note_ui.toggle()
		tutorial_notify("note")
		return
	if event.is_action_pressed("open_stats"):
		Sound.play_sfx("sfx_ui")
		stats_ui.toggle()
		return
	if event.is_action_pressed("ui_cancel"):
		# 게임 메뉴: 저장 후 타이틀로
		Sound.play_sfx("sfx_ui")
		dialog.open("게임 메뉴", "타이틀 화면으로 돌아갈까?\n(진행 상황은 자동 저장된다)", [
			["저장 후 타이틀로", _back_to_title],
			["계속하기", null],
		])
		return
	for slot_i in 9:
		if event.is_action_pressed("tool_%d" % (slot_i + 1)):
			if slot_i < GameData.tool_slots.size() and GameData.tool_slots[slot_i] != "":
				set_tool(GameData.tool_slots[slot_i])
			return
	if event.is_action_pressed("cycle_seed"):
		GameData.cycle_seed()
		set_tool("seed")
	elif event.is_action_pressed("use_tool"):
		use_tool()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("open_shop"):
		match _near_shop():
			"general":
				shop.open("buy", ["buy", "sell"])
			"bin":
				shop.open("sell", ["sell"])
			"ranch":
				shop.open("animal", ["animal"])
			"smith":
				shop.open("upgrade", ["upgrade"])
			"fish":
				shop.open("codex", ["codex"])
			_:
				hud.show_message("상점은 마을에! 상점 건물이나 출하 상자 근처에서 열 수 있다.")
	elif event.is_action_pressed("save_game"):
		save_now()
		hud.show_message("저장했다!")
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_click_at(get_canvas_transform().affine_inverse() * event.position,
			event.double_click)


func _back_to_title() -> void:
	save_now()
	Sound.stop_bgm()
	Net.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# 상점 건물/출하 상자 근처인가 (B키 사용 조건)
# 근처 가게 종류 반환 ("" = 없음). B키가 그 가게에 맞는 탭만 연다
func _near_shop() -> String:
	var p := player_tile()
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := p + Vector2i(dx, dy)
			var bk := _building_kind_at(t)
			if bk in ["general", "ranch", "smith", "fish"]:
				return bk
			var obj: Variant = objects.get(t)
			if obj != null and obj.kind == "bin":
				return "bin"
	return ""


func _click_at(pos: Vector2, dbl: bool) -> void:
	# 좌클릭 1회: 대상 선택 / 더블클릭: 선택 + 즉시 상호작용 (E키와 동일)
	var t := Vector2i(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))
	var d := t - player_tile()
	if absi(d.x) > 1 or absi(d.y) > 1:
		_sel_target = Vector2i(-999, -999)  # 먼 곳 클릭 = 선택 해제
		return
	if d != Vector2i.ZERO:
		# 스프라이트 방향은 우세한 축 기준 (대각선이면 좌우 우선)
		if d.x != 0:
			player.dir = "right" if d.x > 0 else "left"
		else:
			player.dir = "down" if d.y > 0 else "up"
	_sel_target = t
	queue_redraw()
	if dbl:
		# 마우스만으로 즉시 상호작용: 대상이 있으면 E와 동일, 빈 칸이면 도구 사용
		if objects.has(t) or nearby_npc() != null or nearby_animal() != null \
				or nearby_bug() != null:
			interact()
		else:
			use_tool()


# ---- 파티클 ----

const PARTICLE_DEFS := {
	"water": [Color(0.45, 0.65, 1.0), 8, -18.0, 40.0],
	"sparkle": [Color(1.0, 0.85, 0.3), 10, -45.0, 25.0],
	"wood": [Color(0.55, 0.38, 0.2), 7, -35.0, 70.0],
	"stone": [Color(0.62, 0.62, 0.68), 7, -35.0, 70.0],
	"seed": [Color(0.4, 0.75, 0.35), 6, -28.0, 50.0],
	"dirt": [Color(0.52, 0.4, 0.26), 6, -25.0, 60.0],
}


func spawn_particles(t: Vector2i, kind: String) -> void:
	var d: Array = PARTICLE_DEFS[kind]
	var center := Vector2(t.x * TILE + 16, t.y * TILE + 16)
	for i in d[1]:
		particles.append({
			"p": center + Vector2(randf_range(-5, 5), randf_range(-4, 2)),
			"v": Vector2(randf_range(-14, 14), d[2] + randf_range(-8, 8)),
			"c": d[0],
			"life": randf_range(0.3, 0.55),
			"g": d[3],
		})


func _update_particles(delta: float) -> void:
	if particles.is_empty():
		return
	var alive := []
	for pt in particles:
		pt.life -= delta
		if pt.life <= 0.0:
			continue
		pt.v.y += pt.g * delta
		pt.p += pt.v * delta
		alive.append(pt)
	particles = alive


# ---- 렌더링 ----

func _crop_texture(cell: Dictionary) -> Texture2D:
	if cell.dead:
		return tex["withered"]
	var def: Dictionary = GameData.CROPS[cell.crop_id]
	var t := float(cell.crop_day) / _grow_total(def)
	if t >= 1.0:
		return tex["mature_" + cell.crop_id]
	if t < 0.34:
		return tex["crop_sprout"]
	if t < 0.67:
		return tex["crop_small"]
	return tex["crop_medium"]


func _draw() -> void:
	# 카메라에 보이는 타일만 그린다 (90x60 맵 컬링)
	var vis: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var x0 := maxi(0, int(vis.position.x / TILE) - 1)
	var y0 := maxi(0, int(vis.position.y / TILE) - 1)
	var x1 := mini(MAP_W, int(vis.end.x / TILE) + 2)
	var y1 := mini(MAP_H, int(vis.end.y / TILE) + 2)

	var grass_prefix := "grass_" + GameData.season_key() + "_"
	for y in range(y0, y1):
		for x in range(x0, x1):
			var cell: Dictionary = grid[y][x]
			var t: Texture2D
			if cell.ground == "water":
				t = tex["water_%d" % water_frame]
			elif cell.ground == "soil":
				t = tex["soil_wet"] if cell.watered else tex["soil_dry"]
			elif cell.ground == "path":
				t = tex["path"]
			else:
				t = tex[grass_prefix + str(int(_hash01(x, y) * 3.0) % 3)]
			# 텍스처 해상도와 무관하게 타일 칸에 맞춰 그린다 (64px 아트 → 1080p에서 1:1)
			var tile_rect := Rect2(Vector2(x * TILE, y * TILE), Vector2(TILE, TILE))
			draw_texture_rect(t, tile_rect, false)
			if cell.crop_id != "":
				draw_texture_rect(_crop_texture(cell), tile_rect, false)

	# 타겟 타일 하이라이트 (호버: 흰 실선 / 좌클릭 선택: 금색 강조)
	if player != null:
		var tt := target_tile()
		if tt.x >= 0 and tt.y >= 0 and tt.x < MAP_W and tt.y < MAP_H:
			if tt == _sel_target:
				draw_rect(Rect2(Vector2(tt.x * TILE + 1, tt.y * TILE + 1),
					Vector2(TILE - 2, TILE - 2)), Color(1, 0.85, 0.3, 0.9), false, 2.0)
			else:
				draw_rect(Rect2(Vector2(tt.x * TILE, tt.y * TILE), Vector2(TILE, TILE)),
					Color(1, 1, 1, 0.6), false, 1.0)



# 건물/오브젝트 위에 그려야 하는 것들 (안내 텍스트·화살표·파티클·날씨)
func _draw_overlay() -> void:
	_draw_nav_arrow()

	# 낚시 인디케이터 (대기: 점점점 / 입질: 노란 느낌표)
	if player != null:
		if fishing_state == "waiting":
			var base := player.position + Vector2(-8, -96)
			var dots := int(weather_time * 2.0) % 3 + 1
			for i in dots:
				overlay.draw_rect(Rect2(base + Vector2(i * 5, 0), Vector2(2, 2)),
					Color(1, 1, 1, 0.8))
		elif fishing_state == "bite":
			var base := player.position + Vector2(-2, -108)
			overlay.draw_rect(Rect2(base, Vector2(3, 7)), Color(1, 0.85, 0.2))
			overlay.draw_rect(Rect2(base + Vector2(0, 9), Vector2(3, 3)), Color(1, 0.85, 0.2))

	# 말을 걸어 달라는 표시: 머리 위에서 통통 튀는 느낌표
	if _postman != null and _postman_state == "wait" and not ui_open():
		_draw_bang(_postman.position + Vector2(0, -136))

	for pt in particles:
		overlay.draw_rect(Rect2(pt.p, Vector2(1, 1)), pt.c)

	# 경험치 획득 플로팅 텍스트
	for ft in float_texts:
		var a: float = clampf(1.4 - ft.t, 0.0, 1.0)
		var p: Vector2 = ft.pos + Vector2(0, -ft.t * 26.0)
		var tw: float = UI_FONT_SMALL.get_string_size(ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		overlay.draw_string_outline(UI_FONT_SMALL, p + Vector2(-tw / 2.0, 0), ft.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 3, Color(0.05, 0.04, 0.08, a))
		overlay.draw_string(UI_FONT_SMALL, p + Vector2(-tw / 2.0, 0), ft.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.65, 0.95, 0.5, a))

	_draw_context_hint()
	_draw_weather()


# 머리 위 느낌표 (도트 그대로 — 굵은 막대 + 점)
func _draw_bang(pos: Vector2) -> void:
	var bob := absf(sin(weather_time * 4.0)) * 6.0
	var p := pos + Vector2(0, -bob)
	var body := Rect2(p + Vector2(-3, 0), Vector2(6, 20))
	var dot := Rect2(p + Vector2(-3, 24), Vector2(6, 7))
	for r: Rect2 in [body, dot]:
		overlay.draw_rect(r.grow(2.0), Color(0.12, 0.08, 0.05, 0.92))  # 외곽선
		overlay.draw_rect(r, Color(1.0, 0.86, 0.25))


# 타겟 타일/주변 상황에 맞는 안내 문구를 월드에 띄운다
func _context_hint() -> Array:
	# 반환: [문구, 기준 위치(월드)] 또는 []
	if player == null or ui_open():
		return []
	var above_player := player.position + Vector2(0, -100)
	if fishing_state == "bite":
		return ["지금이다!", above_player]
	if fishing_state == "waiting":
		return []
	# 첫 만남: 걸어와서 기다리는 우체부 아저씨 머리 위에 안내를 띄운다
	if _postman != null and _postman_state == "wait" \
			and (player.position - _postman.position).length() < POSTMAN_TALK_DIST:
		return ["E: 말 걸기", _postman.position + Vector2(0, -112)]
	if nearby_npc() != null:
		return ["E: 대화", above_player]
	if nearby_animal() != null:
		return ["E: 쓰다듬기", above_player]
	var t := target_tile()
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return []
	var above_tile := Vector2(t.x * TILE + 16, t.y * TILE - 12)
	var obj: Variant = objects.get(t)
	if obj != null:
		match obj.kind:
			"bin":
				return ["E: 판매", above_tile]
			"board":
				return ["E: 의뢰 게시판", above_tile]
			"cave":
				return ["E: 동굴 탐험", above_tile]
			"worldtree":
				return ["E: 세계수 동굴 (위험!)", above_tile]
			"forage_berry", "forage_herb":
				return ["E: 채집", above_tile]
			"housesite":
				return ["E: 집 짓기 (목재 %d)" % GameData.HOUSE_BUILD_WOOD, above_tile]
			"tree":
				if bool(obj.get("young", false)):
					return ["어린 나무 (자라는 중)", above_tile]
				return ["E: 벌목 (도끼)", above_tile]
			"rock", "bigrock":
				return ["E: 채광 (곡괭이)", above_tile]
			"house":
				var bk := _building_kind_at(t)
				if bk == "home":
					return ["E: 집에 들어가기", above_tile]
				if bk in ["general", "ranch", "smith", "fish"]:
					return ["E: " + BUILDING_NAMES[bk], above_tile]
		return []
	var cell: Dictionary = grid[t.y][t.x]
	if cell.crop_id != "":
		if cell.dead:
			return ["시듦 - 호미로 정리", above_tile]
		var def: Dictionary = GameData.CROPS[cell.crop_id]
		var pct := float(cell.crop_day) / _grow_total(def)
		if pct >= 1.0:
			return ["수확!", above_tile]
		var text := "성장 %d%%" % int(pct * 100.0)
		if _crop_thirsty(cell):
			text += " · 물을 한 번 더!"
		elif not cell.watered:
			text += " · 물주기!"
		return [text, above_tile]
	if cell.ground == "water" and GameData.tool == "rod":
		return ["Space: 낚시", above_tile]
	return []


# 현재 목표에 목적지가 있으면 플레이어 주위에 방향 화살표를 띄운다
func nav_target() -> Variant:
	if GameData.story_phase == "approach" and _postman != null:
		return _postman.position          # 첫 만남: 우체부에게 가는 길 안내
	if GameData.story_phase == "path":
		# 갈림길까지 숲길 안내
		return Vector2(STORY_FORK.x * TILE + 16, STORY_FORK.y * TILE + 16)
	if GameData.story_phase == "rock":
		# 커다란 바위까지 안내, 바위를 캔 뒤에는 우체부 아저씨에게
		if GameData.story_rock_state >= 2 and _postman != null:
			return _postman.position
		return Vector2(STORY_ROCK.x * TILE + 16, STORY_ROCK.y * TILE + 16)
	if GameData.story_phase == "travel":
		# 마을 이장에게 가는 길 안내
		var chief := _story_chief()
		if chief != null:
			return chief.position
	if GameData.story_phase != "done":
		return null  # 숲 구간에서는 화살표를 띄우지 않는다
	match GameData.tutorial_current_flag():
		"slept":
			# 우리집(마을 서쪽) 문 앞 — 아직 안 지었으면 집터로 안내한다
			return Vector2(HOME_ANCHOR.x * TILE + 2 * TILE + 16,
				(HOME_ANCHOR.y + 4) * TILE + 16)
		"shop":
			if not GameData.village_built.has("general"):
				return null  # 잡화점은 마을 발전으로 지어야 생긴다
			var ga: Vector2i = VILLAGE_PLOTS["general"].anchor
			return Vector2((ga.x + 2) * TILE + 16, (ga.y + 4) * TILE + 16)
		"fish":
			return Vector2(40 * TILE + 16, 27 * TILE + 16)   # 호수 (숲과 호수 부지)
		"chop":
			return _nearest_object_pos("tree")
		"mine":
			return _nearest_object_pos("rock")
	return null


func _nearest_object_pos(kind: String) -> Variant:
	var best: Variant = null
	var best_d := INF
	for pos: Vector2i in objects:
		if objects[pos].kind != kind:
			continue
		var p := Vector2(pos.x * TILE + 16, pos.y * TILE + 16)
		var d := p.distance_to(player.position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _draw_nav_arrow() -> void:
	if player == null or ui_open():
		return
	var target: Variant = nav_target()
	if target == null:
		return
	var to: Vector2 = target - player.position
	if to.length() < 40.0:
		return  # 목적지 근처에서는 숨긴다
	var dirv := to.normalized()
	var bob := sin(weather_time * 6.0) * 2.0
	var base := player.position + Vector2(0, -80) + dirv * (24.0 + bob)
	var tip := base + dirv * 7.0
	var left := base + dirv.rotated(2.6) * 4.0
	var right := base + dirv.rotated(-2.6) * 4.0
	overlay.draw_colored_polygon(PackedVector2Array([tip, left, right]),
		Color(1, 0.85, 0.3, 0.95))


func _draw_context_hint() -> void:
	var hint := _context_hint()
	if hint.is_empty():
		return
	var text: String = hint[0]
	var base: Vector2 = hint[1]
	var w := UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var pos := Vector2(base.x - w / 2.0, base.y)
	overlay.draw_string_outline(UI_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3,
		Color(0.08, 0.06, 0.12, 0.9))
	overlay.draw_string(UI_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 0.9))


func _draw_weather() -> void:
	var w := weather_now()
	var full_w := MAP_W * TILE + 20.0
	var full_h := MAP_H * TILE + 10.0
	if w == GameData.WEATHER_RAIN:
		for i in 360:
			var sx := _hash01(i, 1) * full_w - 10.0
			var sy := fposmod(_hash01(i, 2) * full_h + weather_time * 280.0, full_h) - 5.0
			overlay.draw_line(Vector2(sx - 2, sy - 7), Vector2(sx, sy),
				Color(0.72, 0.82, 1.0, 0.5), 1.0)
	elif w == GameData.WEATHER_SNOW:
		for i in 240:
			var sx := fposmod(_hash01(i, 1) * full_w + sin(weather_time * 1.5 + i) * 12.0, full_w)
			var sy := fposmod(_hash01(i, 2) * full_h + weather_time * 35.0, full_h) - 5.0
			overlay.draw_rect(Rect2(Vector2(sx, sy), Vector2(1, 1)), Color(1, 1, 1, 0.85))


# ---- 검증 시퀀스 ----
# 키/마우스 이벤트를 실제 InputMap 경로로 흘려보내
# 밭갈기->클릭 경작->물주기->파종->자원->설치->상점->결산까지 자동 재생한다.

func _debug_tick() -> void:
	if Net.is_guest() and not _net_ready:
		return  # 접속 완료 후부터 시퀀스 시작
	_shot_frames += 1
	if OS.get_environment("KYOJIN_STORY") != "":
		# 스토리 화면만 캡처하고 종료 (프레임 수가 아니라 스토리 진행 시간 기준 —
		# 헤드리스 환경은 프레임 속도가 들쭉날쭉하다)
		if not _story_snapped and _story_t >= 3.2:
			_story_snapped = true
			_save_shot("_story.png")
		elif _story_snapped and _story_t >= 3.8:
			get_tree().quit()
		return
	match _shot_frames:
		10: _send_key(KEY_1)
		14: _send_key(KEY_E)                           # 아래 타일 밭 갈기 (E로도 된다)
		18: _send_click(Vector2((START_TILE.x + 1) * TILE + 16, START_TILE.y * TILE + 16))
		22: _send_key(KEY_2)
		26: _send_key(KEY_SPACE)                       # 물 주기
		30: _send_key(KEY_3)
		34: _send_key(KEY_E)                           # 씨앗 심기 (E로도 된다)
		36:
			GameData.wood = 5                          # 설치 테스트용 자원 지급
			GameData.stone = 5
		38: _send_key_press(KEY_A)
		42: _send_key_release(KEY_A)                   # 왼쪽 보기
		46: _send_key(KEY_7)
		50: _send_key(KEY_SPACE)                       # 울타리 설치
		54: _send_key_press(KEY_S)
		56: _send_key_release(KEY_S)                   # 아래 보기
		60: _send_key(KEY_8)
		64: _send_key(KEY_SPACE)                       # 스프링클러 설치
		66: _send_key(KEY_3)                           # 씨앗 도구로 컨텍스트 힌트 확인
		70: _save_shot("_game.png")
		71: map_ui.open()                              # 지도 확인
		73: _save_shot("_map.png")
		74:
			map_ui.close()
			player.position = Vector2(76 * TILE + 16, 12 * TILE + 16)
			player.dir = "right"                       # 마을 광장 게시판 앞으로
			for n in npcs:                             # 게시판 캡처를 위해 NPC를 비켜둔다
				n.position = Vector2(62 * TILE + 16, 25 * TILE + 16)
				n.target = n.position
		78: _send_key(KEY_E)
		84: _save_shot("_quest.png")
		86: dialog.close()
		87:
			player.position = Vector2(74 * TILE + 16, 20 * TILE + 16)
			player.dir = "up"                          # 중앙 광장(건물 없는 초기 마을)
		89: _save_shot("_village.png")
		90:
			player.position = npcs[0].position + Vector2(12, 0)
		94: _send_key(KEY_E)                           # NPC 대화
		100: _save_shot("_npc.png")
		101:
			GameData.produce["potato"] = 3             # 선물 고르기 확인
			GameData.items["egg"] = 2
			_open_gift_picker("chief")
		103: _save_shot("_gift.png")
		104:
			_close_gift_picker()
			dialog.close()
			GameData.money = 200000
		122: interior.open()                           # 집 내부 확인
		128: _save_shot("_house.png")
		129: _send_key(KEY_F)                          # 꾸미기 모드
		133: _save_shot("_deco.png")
		134: _send_key(KEY_F)                          # 꾸미기 종료
		136: interior.ppos = Vector2(645, 174)         # 조리대 앞으로
		138: _send_key(KEY_E)                          # 주방 열기
		142: _save_shot("_cook.png")
		144:
			cooking_ui.close()
			interior.close()
			inventory_ui.toggle()                      # 인벤토리(도구/능력치) 확인
			GameData.tool_level["axe"] = 2
		146: inventory_ui.hover_stat_tool()             # 장비 능력치 툴팁 확인
		148: _save_shot("_inv.png")
		150:
			inventory_ui.close()
			GameData.owned_pets = ["dog"]              # 펫 확인
			GameData.active_pet = "dog"
			pet.position = player.position + Vector2(14, 4)
		156: _save_shot("_pet.png")
		158: cave.open()                               # 동굴 확인
		160: _send_key(KEY_SPACE)                      # 공격 모션
		162: _save_shot("_cave.png")
		164: cave.close()
		166: quest_ui.toggle()                         # 퀘스트 창(Q) 확인
		170: _save_shot("_questwin.png")
		172:
			quest_ui.close()
			GameData.crops_harvested = {"potato": 3, "carrot": 1}
			GameData.affinity["merchant"] = 60
			note_ui.toggle()                           # 연구 노트(N) 확인
		176: _save_shot("_note.png")
		177:
			note_ui.close()
			GameData.tool_level["axe"] = 2             # 장비 능력치 확인
			GameData.tool_level["hoe"] = 3
			stats_ui.toggle()
		179: stats_ui.scroll_to_bottom()               # 장비 능력치까지 확인
		181: _save_shot("_stats.png")
		182: stats_ui.close()
		183:
			GameData.wood = 999                        # 마을 발전(건설) 확인
			GameData.stone = 999
			_build_village_building("post")
			_build_village_building("general")
			dialog.close()
			player.position = Vector2(74 * TILE + 16, 11 * TILE + 16)
			player.dir = "up"
		182: _save_shot("_village2.png")
		184:
			GameData.gender = "m"                      # 남자 캐릭터 뒷모습 걷기 확인
			_send_key_press(KEY_W)
		188: _save_shot("_boy_back.png")
		189:
			_send_key_release(KEY_W)
			_send_key_press(KEY_S)                     # 앞모습 걷기 확인
		193: _save_shot("_boy_front.png")
		194:
			_send_key_release(KEY_S)
			_send_key_press(KEY_D)                     # 옆모습 걷기 확인
		198: _save_shot("_boy_side.png")
		199: _send_key_release(KEY_D)
		201: get_tree().quit()


# ==== 멀티플레이 ====

func _show_connecting() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 55
	layer.name = "Connecting"
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	_connect_label = Label.new()
	_connect_label.text = "호스트에 접속하는 중..."
	_connect_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_connect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_connect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(_connect_label)
	# 12초 안에 스냅샷을 못 받으면 타이틀로
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		if not _net_ready and Net.is_guest():
			_back_to_title())


func _hide_connecting() -> void:
	var layer := get_node_or_null("Connecting")
	if layer != null:
		layer.queue_free()


func _on_peer_connected(_id: int) -> void:
	if Net.is_host():
		hud.show_message("새 일꾼이 농장에 도착했다!")


func _on_peer_disconnected(id: int) -> void:
	if remote_players.has(id):
		remote_players[id].queue_free()
		remote_players.erase(id)
	if Net.is_host():
		hud.show_message("일꾼이 농장을 떠났다.")


func _on_server_disconnected() -> void:
	Net.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _make_snapshot_json() -> String:
	var g := []
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			var c: Dictionary = grid[y][x]
			row.append([c.ground, int(c.wet_min), c.crop_id, int(c.crop_day),
				1 if c.dead else 0, 1 if c.get("half_fed", false) else 0])
		g.append(row)
	var objs := []
	for pos: Vector2i in objects:
		objs.append([pos.x, pos.y, objects[pos].kind, objects[pos].hp,
			1 if objects[pos].get("apple", false) else 0,
			1 if objects[pos].get("young", false) else 0,
			int(objects[pos].get("grow", 0)),
			1 if objects[pos].get("fixed", false) else 0])
	var anims := []
	for a in animals:
		anims.append([a.type, a.position.x, a.position.y, 1 if a.fed else 0])
	return JSON.stringify(GameData.build_save(g, player.position, objs, anims))


@rpc("any_peer", "reliable")
func _req_snapshot() -> void:
	if not Net.is_host():
		return
	_recv_snapshot.rpc_id(multiplayer.get_remote_sender_id(), _make_snapshot_json())


@rpc("authority", "reliable")
func _recv_snapshot(json: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if typeof(d) != TYPE_DICTIONARY:
		return
	# 스냅샷의 플레이어 위치는 호스트 것이므로 내 위치는 유지한다
	var my_pos := player.position
	for a in animals:
		a.queue_free()
	animals.clear()
	_apply_save(d)
	player.position = my_pos
	GameData.tutorial = {"active": false}
	GameData.unlock_all_tools()
	_spawn_objects()
	_apply_season_visuals()
	_net_ready = true
	_hide_connecting()
	hud.show_message("농장에 도착했다! 함께 일해보자.")
	queue_redraw()


# 위치 동기화 (15Hz, 비신뢰)
@rpc("any_peer", "unreliable_ordered")
func _sync_pos(x: float, y: float, dir: String, moving: bool) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not remote_players.has(pid):
		var rp: Node2D = preload("res://scripts/remote_player.gd").new()
		rp.main = self
		rp.tint = PLAYER_TINTS[(pid % 3) + 1]
		rp.position = Vector2(x, y)
		remote_players[pid] = rp
		world.add_child(rp)
	remote_players[pid].set_state(Vector2(x, y), dir, moving)


var _snapshot_retry := 0.0


func _net_process(delta: float) -> void:
	if not Net.active():
		return
	if Net.is_guest() and not _net_ready:
		# 스냅샷 재요청 (유실 대비)
		_snapshot_retry -= delta
		if _snapshot_retry <= 0.0 and multiplayer.multiplayer_peer != null \
				and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_snapshot_retry = 2.0
			_req_snapshot.rpc_id(1)
	_pos_sync_timer -= delta
	if _pos_sync_timer <= 0.0:
		_pos_sync_timer = 1.0 / 15.0
		_sync_pos.rpc(player.position.x, player.position.y, player.dir, player.moving)
	if Net.is_host():
		_time_sync_timer -= delta
		if _time_sync_timer <= 0.0:
			_time_sync_timer = 3.0
			_net_time.rpc(GameData.day, GameData.minutes, GameData.energy)


@rpc("authority", "unreliable_ordered")
func _net_time(day: int, minutes: float, _host_energy: float) -> void:
	GameData.day = day
	GameData.minutes = minutes


# 도구 사용 결과 영역 동기화 (호스트 -> 전체)
func _broadcast_area(center: Vector2i) -> void:
	if not Net.is_host():
		return
	var cells := []
	var objs := []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var pos := center + Vector2i(dx, dy)
			if pos.x < 0 or pos.y < 0 or pos.x >= MAP_W or pos.y >= MAP_H:
				continue
			var c: Dictionary = grid[pos.y][pos.x]
			cells.append([pos.x, pos.y, c.ground, int(c.wet_min), c.crop_id,
				int(c.crop_day), 1 if c.dead else 0, 1 if c.get("half_fed", false) else 0])
			if objects.has(pos):
				var o: Dictionary = objects[pos]
				objs.append([pos.x, pos.y, o.kind, o.hp])
	_net_area.rpc(center.x, center.y, cells, objs)


@rpc("authority", "reliable")
func _net_area(cx: int, cy: int, cells: Array, objs: Array) -> void:
	for entry in cells:
		var c: Dictionary = grid[entry[1]][entry[0]]
		c.ground = entry[2]
		c.wet_min = float(entry[3])
		c.watered = float(entry[3]) > 0.0
		c.crop_id = entry[4]
		c.crop_day = float(entry[5])
		c.dead = int(entry[6]) == 1
		c.half_fed = entry.size() > 7 and int(entry[7]) == 1
	# 영역 내 오브젝트: 목록에 없는 건 제거, 있는 건 갱신/추가
	var present := {}
	for o in objs:
		present[Vector2i(int(o[0]), int(o[1]))] = o
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var pos := Vector2i(cx + dx, cy + dy)
			if pos.x < 0 or pos.y < 0 or pos.x >= MAP_W or pos.y >= MAP_H:
				continue
			if objects.has(pos) and not present.has(pos):
				if objects[pos].kind != "house":
					_remove_object(pos)
			elif present.has(pos):
				var o: Array = present[pos]
				if o[2] == "house":
					continue
				if objects.has(pos):
					objects[pos].hp = int(o[3])
				else:
					_place_object(pos, o[2], int(o[3]))
	queue_redraw()


func _broadcast_stats() -> void:
	if Net.is_host():
		_net_stats.rpc(JSON.stringify(GameData.build_stats()))


@rpc("authority", "reliable")
func _net_stats(json: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if typeof(d) == TYPE_DICTIONARY:
		GameData.apply_stats(d)


# 게스트 행동 요청: 호스트가 같은 로직을 실행하고 결과를 전파한다
var _target_override := Vector2i(-999, -999)
var _perp_override := Vector2i.ZERO
var _forced_seed := ""
var _remote_acting := false


@rpc("any_peer", "reliable")
func _req_tool(tx: int, ty: int, tool: String, seed_id: String, px: int, py: int) -> void:
	if not Net.is_host():
		return
	var saved_tool: String = GameData.tool
	var saved_energy: float = GameData.energy
	_target_override = Vector2i(tx, ty)
	_perp_override = Vector2i(px, py)
	_forced_seed = seed_id
	_remote_acting = true
	GameData.tool = tool
	use_tool()
	GameData.tool = saved_tool
	GameData.energy = saved_energy  # 게스트 기력은 게스트 로컬 관리
	_remote_acting = false
	_target_override = Vector2i(-999, -999)
	_perp_override = Vector2i.ZERO
	_forced_seed = ""
	_broadcast_area(Vector2i(tx, ty))
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_shop(op: String, id: String) -> void:
	if not Net.is_host():
		return
	match op:
		"buy_seed":
			shop._on_buy(id)
		"sell_crop":
			shop._on_sell(id)
		"sell_item":
			shop._on_sell_item(id)
		"buy_animal":
			shop._on_buy_animal(id)
		"buy_pet":
			shop._on_buy_pet(id)
		"select_pet":
			shop._on_select_pet(id)
		"upgrade":
			shop._on_upgrade(id)
	_broadcast_stats()


# 게스트가 상점 조작 후 호출 (호스트면 즉시 전파)
func net_shop(op: String, id: String) -> void:
	if Net.is_host():
		_broadcast_stats()
	elif Net.is_guest():
		_req_shop.rpc_id(1, op, id)


@rpc("any_peer", "reliable")
func _req_feed(index: int) -> void:
	if not Net.is_host():
		return
	if index >= 0 and index < animals.size():
		animals[index].fed = true


# 몬스터 처치 기록 (도감용)
func record_kill(mob: String) -> void:
	GameData.mob_kills[mob] = int(GameData.mob_kills.get(mob, 0)) + 1
	if Net.is_guest():
		_req_kill.rpc_id(1, mob)
	elif Net.is_host():
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_kill(mob: String) -> void:
	if not Net.is_host():
		return
	if GameData.MOBS.has(mob):
		GameData.mob_kills[mob] = int(GameData.mob_kills.get(mob, 0)) + 1
		_broadcast_stats()


# 아이템 획득 (동굴 보상/낚시 등) — 멀티에서는 호스트가 확정한다
func gain_item(id: String, count: int) -> void:
	if id in ["ore", "gem"]:
		GameData.minerals_found[id] = true
	if Net.is_guest():
		GameData.items[id] += count  # 낙관적 반영, 통계 브로드캐스트로 수렴
		_req_gain.rpc_id(1, id, count)
		return
	GameData.items[id] += count
	if Net.is_host():
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_gain(id: String, count: int) -> void:
	if not Net.is_host():
		return
	if GameData.items.has(id) and count > 0 and count <= 50:
		GameData.items[id] += count
		if id.begins_with("fish_"):
			GameData.fish_caught[id] = int(GameData.fish_caught.get(id, 0)) + count
		_broadcast_stats()


# 요리/먹기 — 멀티에서는 호스트가 재고를 확정한다 (에너지는 각자)
func do_cook(id: String) -> void:
	if not GameData.cook(id):
		hud.show_message("재료가 부족하다.")
		return
	Sound.play_sfx("sfx_buy")
	hud.show_message("'%s' 완성!" % GameData.ITEMS[id].name)
	gain_skill("cook", 8.0)
	if Net.is_guest():
		_req_cook.rpc_id(1, id)
	elif Net.is_host():
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_cook(id: String) -> void:
	if not Net.is_host():
		return
	if GameData.RECIPES.has(id) and GameData.cook(id):
		_broadcast_stats()


func do_eat(id: String) -> void:
	if int(GameData.items[id]) <= 0:
		return
	GameData.items[id] -= 1
	var e: float = float(GameData.RECIPES[id].energy) * GameData.cook_energy_mult()
	GameData.energy = minf(GameData.ENERGY_MAX, GameData.energy + e)
	Sound.play_sfx("sfx_harvest")
	hud.show_message("%s를 먹었다! 체력 +%d" % [GameData.ITEMS[id].name, int(e)])
	if Net.is_guest():
		_req_eat.rpc_id(1, id)
	elif Net.is_host():
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_eat(id: String) -> void:
	if not Net.is_host():
		return
	if GameData.RECIPES.has(id) and int(GameData.items[id]) > 0:
		GameData.items[id] -= 1
		_broadcast_stats()


# 집 꾸미기 변경 동기화: 가구 배치 목록 + 돈 변화(구입/판매)를 호스트가 확정한다
func sync_furniture(money_delta: int) -> void:
	if Net.is_guest():
		_req_furniture.rpc_id(1, JSON.stringify(GameData.furniture), money_delta)
	elif Net.is_host():
		_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_furniture(furn_json: String, money_delta: int) -> void:
	if not Net.is_host():
		return
	var arr: Variant = JSON.parse_string(furn_json)
	if typeof(arr) != TYPE_ARRAY or absi(money_delta) > 1000:
		return
	GameData.apply_furniture_data(arr)
	GameData.money += money_delta
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_gift(npc_id: String, kind: String, item_id: String) -> void:
	if not Net.is_host():
		return
	# 게스트가 직접 고른 품목을 차감한다
	if kind == "produce" and int(GameData.produce.get(item_id, 0)) > 0:
		GameData.produce[item_id] -= 1
	elif kind == "item" and int(GameData.items.get(item_id, 0)) > 0:
		GameData.items[item_id] -= 1
	else:
		return
	GameData.affinity[npc_id] = int(GameData.affinity[npc_id]) + 10
	_broadcast_stats()


@rpc("any_peer", "reliable")
func _req_quest(op: String) -> void:
	if not Net.is_host():
		return
	if op == "accept" and not GameData.quest.is_empty():
		GameData.quest.accepted = true
	elif op == "turnin" and not GameData.quest.is_empty():
		var q: Dictionary = GameData.quest
		if GameData.produce[q.crop] >= q.qty:
			GameData.produce[q.crop] -= q.qty
			GameData.money += q.reward
			GameData.affinity["merchant"] = int(GameData.affinity["merchant"]) + 5
			GameData.quest = {}
	_broadcast_stats()


@rpc("authority", "reliable")
func _net_new_day(json: String, title_text: String, body: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if typeof(d) != TYPE_DICTIONARY:
		return
	var my_pos := player.position
	for a in animals:
		a.queue_free()
	animals.clear()
	_apply_save(d)
	player.position = my_pos
	GameData.tutorial = {"active": false}
	GameData.unlock_all_tools()
	GameData.energy = GameData.ENERGY_MAX
	_spawn_objects()
	_apply_season_visuals()
	summary.open(title_text, body)
	queue_redraw()


# ==== 검증 시퀀스 ====

func _send_key(code: Key) -> void:
	_send_key_press(code)


func _send_key_press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _send_key_release(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = false
	Input.parse_input_event(ev)


func _send_click(world_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	# parse_input_event 는 OS 창 좌표 기준이므로 스트레치 변환까지 적용한다.
	ev.position = get_viewport().get_screen_transform() * (get_canvas_transform() * world_pos)
	Input.parse_input_event(ev)


func _save_shot(suffix: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path + suffix)
