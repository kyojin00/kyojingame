# 메인 월드: 맵, 경작, 도구, 자원, 시간, 낮/밤을 관리한다.
extends Node2D

const MAP_W := 60
const MAP_H := 40
const TILE := 16

const MIN_PER_SEC := 10.0 / 7.0  # 실제 7초 = 게임 10분
const ENERGY_COST := {
	"hoe": 2.0, "water": 1.0, "seed": 1.0, "hand": 1.0,
	"axe": 2.0, "pickaxe": 2.0, "fence": 1.0, "sprinkler": 1.0,
	"rod": 2.0,
}
const TREE_HP := 3
const ROCK_HP := 2
const WOOD_PER_TREE := 3
const STONE_PER_ROCK := 2

# grid[y][x] = {ground, watered, crop_id, crop_day, dead}
var grid: Array = []
# Vector2i -> {kind: "tree"|"rock"|"house"|"bin"|"fence"|"sprinkler", hp: int}
var objects: Dictionary = {}
var obj_nodes: Dictionary = {}  # Vector2i -> Node2D (설치/제거 가능한 오브젝트만)

var tex: Dictionary = {}
var world: Node2D
var player: Node2D
var hud: CanvasLayer
var shop: CanvasLayer
var summary: CanvasLayer
var night: CanvasModulate
var sleep_dialog: ConfirmationDialog
var water_frame := 0
var water_timer := 0.0
var tree_sprites: Array = []
var weather_time := 0.0
var animals: Array = []

# 낚시 상태: "" | "waiting"(입질 대기) | "bite"(입질!)
var fishing_state := ""
var fishing_timer := 0.0
var fishing_ui: CanvasLayer
var pending_fish: Array = []

# 개발/CI용: KYOJIN_SHOT=경로 로 실행하면 잠시 후 스크린샷을 저장하고 종료한다.
# KYOJIN_DAY=숫자, KYOJIN_WEATHER=0/1/2 로 시작 날짜/날씨를 강제할 수 있다.
var _shot_path := ""
var _shot_frames := 0
var _weather_override := -1

const TEXTURE_NAMES := [
	"player_down_0", "player_down_1", "player_up_0", "player_up_1",
	"player_side_0", "player_side_1",
	"crop_sprout", "crop_small", "crop_medium", "withered",
	"mature_potato", "mature_carrot", "mature_strawberry", "mature_pumpkin",
	"mature_tomato", "mature_corn", "mature_watermelon",
	"mature_eggplant", "mature_cabbage", "mature_winter_radish",
	"tree_spring", "tree_summer", "tree_fall", "tree_winter",
	"rock", "bin", "house", "fence", "sprinkler",
	"chicken_0", "chicken_1", "cow_0", "cow_1",
	"grass_spring_0", "grass_spring_1", "grass_spring_2",
	"grass_summer_0", "grass_summer_1", "grass_summer_2",
	"grass_fall_0", "grass_fall_1", "grass_fall_2",
	"grass_winter_0", "grass_winter_1", "grass_winter_2",
	"soil_dry", "soil_wet", "water_0", "water_1",
]

const START_TILE := Vector2i(30, 20)


func _ready() -> void:
	_load_textures()
	_build_map()

	night = CanvasModulate.new()
	add_child(night)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	player = preload("res://scenes/player.tscn").instantiate()
	player.main = self
	player.position = Vector2(START_TILE.x * TILE + 8, START_TILE.y * TILE + 8)
	world.add_child(player)
	_setup_camera()

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

	sleep_dialog = ConfirmationDialog.new()
	sleep_dialog.dialog_text = "잠자리에 들까요?\n다음 날 아침이 됩니다."
	sleep_dialog.ok_button_text = "잔다"
	sleep_dialog.cancel_button_text = "안 잔다"
	sleep_dialog.confirmed.connect(func() -> void: _next_day(false))
	add_child(sleep_dialog)

	_shot_path = OS.get_environment("KYOJIN_SHOT")
	if OS.get_environment("KYOJIN_DAY") != "":
		GameData.day = int(OS.get_environment("KYOJIN_DAY"))
	if OS.get_environment("KYOJIN_WEATHER") != "":
		_weather_override = int(OS.get_environment("KYOJIN_WEATHER"))

	var loaded := GameData.load_game()
	if loaded.size() > 0:
		_apply_save(loaded)
		hud.show_message("저장된 농장을 불러왔다!")
	else:
		hud.show_message("교진 팜에 온 것을 환영한다! 감자 씨앗 5개로 시작하자.")
	_spawn_objects()
	_apply_season_visuals()


func _load_textures() -> void:
	for n in TEXTURE_NAMES:
		tex[n] = load("res://assets/sprites/%s.png" % n)


func _setup_camera() -> void:
	var cam: Camera2D = player.get_node("Camera")
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
			row.append({"ground": "grass", "watered": false, "crop_id": "", "crop_day": 0, "dead": false})
		grid.append(row)

	# 연못 2개
	for y in range(13, 18):
		for x in range(23, 28):
			grid[y][x].ground = "water"
	for y in range(28, 35):
		for x in range(45, 53):
			grid[y][x].ground = "water"

	# 집 (왼쪽 위 5x4 타일) + 출하 상자
	for y in range(1, 5):
		for x in range(2, 7):
			objects[Vector2i(x, y)] = {"kind": "house", "hp": 0}
	objects[Vector2i(9, 4)] = {"kind": "bin", "hp": 0}

	# 테두리 나무
	for x in MAP_W:
		if _hash01(x, 0) < 0.75 and not objects.has(Vector2i(x, 0)):
			objects[Vector2i(x, 0)] = {"kind": "tree", "hp": TREE_HP}
		if _hash01(x, MAP_H - 1) < 0.75:
			objects[Vector2i(x, MAP_H - 1)] = {"kind": "tree", "hp": TREE_HP}
	for y in MAP_H:
		if _hash01(0, y) < 0.75 and not objects.has(Vector2i(0, y)):
			objects[Vector2i(0, y)] = {"kind": "tree", "hp": TREE_HP}
		if _hash01(MAP_W - 1, y) < 0.75 and not objects.has(Vector2i(MAP_W - 1, y)):
			objects[Vector2i(MAP_W - 1, y)] = {"kind": "tree", "hp": TREE_HP}

	# 흩어진 나무/돌 (결정적 해시 배치)
	for y in range(1, MAP_H - 1):
		for x in range(1, MAP_W - 1):
			var pos := Vector2i(x, y)
			if objects.has(pos) or grid[y][x].ground != "grass":
				continue
			if x >= 1 and x <= 10 and y >= 0 and y <= 6:
				continue  # 집/출하상자 주변은 비워둔다
			if abs(x - START_TILE.x) <= 3 and abs(y - START_TILE.y) <= 3:
				continue  # 시작 지점 주변도 비워둔다
			var h := _hash01(x * 3 + 7, y * 5 + 11)
			if h < 0.045:
				objects[pos] = {"kind": "tree", "hp": TREE_HP}
			elif h < 0.075:
				objects[pos] = {"kind": "rock", "hp": ROCK_HP}


func _spawn_objects() -> void:
	for n in obj_nodes.values():
		n.queue_free()
	obj_nodes.clear()
	tree_sprites.clear()
	var house_done := false
	for pos: Vector2i in objects:
		var kind: String = objects[pos].kind
		if kind == "house":
			if house_done:
				continue
			house_done = true
			var hn := _make_object(tex["house"], Vector2(2 * TILE, 5 * TILE), Vector2(0, -64))
			obj_nodes[pos] = hn
			world.add_child(hn)
		else:
			_spawn_object_node(pos, kind)


func _spawn_object_node(pos: Vector2i, kind: String) -> void:
	var offset := Vector2(0, -16)
	var texture: Texture2D
	match kind:
		"tree":
			texture = tex["tree_" + GameData.season_key()]
			offset = Vector2(0, -18)
		"rock":
			texture = tex["rock"]
		"bin":
			texture = tex["bin"]
		"fence":
			texture = tex["fence"]
		"sprinkler":
			texture = tex["sprinkler"]
	var node := _make_object(texture, Vector2(pos.x * TILE, (pos.y + 1) * TILE), offset)
	obj_nodes[pos] = node
	if kind == "tree":
		tree_sprites.append(node.get_child(0))
	world.add_child(node)


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
	for s in tree_sprites:
		s.texture = tex["tree_" + GameData.season_key()]
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
	return true


func is_passable_px(p: Vector2) -> bool:
	return is_passable(Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE))))


func player_tile() -> Vector2i:
	return Vector2i(int(floor(player.position.x / TILE)), int(floor(player.position.y / TILE)))


func target_tile() -> Vector2i:
	var dirs := {
		"down": Vector2i(0, 1), "up": Vector2i(0, -1),
		"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
	}
	return player_tile() + dirs[player.dir]


func ui_open() -> bool:
	return shop.visible or summary.visible or sleep_dialog.visible or fishing_ui.visible


# ---- 도구/상호작용 ----

func set_tool(t: String) -> void:
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
	if GameData.energy < ENERGY_COST["rod"]:
		hud.show_message("너무 지쳤다... 자러 가야 할 것 같다.")
		return
	GameData.energy -= ENERGY_COST["rod"]
	fishing_state = "waiting"
	fishing_timer = randf_range(1.5, 4.0)


func _update_fishing(delta: float) -> void:
	if fishing_state == "waiting":
		fishing_timer -= delta
		if fishing_timer <= 0.0:
			fishing_state = "bite"
			fishing_timer = 0.9
	elif fishing_state == "bite":
		fishing_timer -= delta
		if fishing_timer <= 0.0:
			fishing_state = ""
			hud.show_message("물고기가 도망갔다...")


func _on_fishing_finished(success: bool) -> void:
	if success:
		var id: String = pending_fish[0]
		var def: Dictionary = GameData.ITEMS[id]
		GameData.items[id] += 1
		GameData.fish_caught[id] = int(GameData.fish_caught.get(id, 0)) + 1
		GameData.today_harvest += 1
		hud.show_message("%s를 낚았다! (%dG)" % [def.name, def.sell])
	else:
		hud.show_message("놓쳤다...")


func _affected_tiles(base: Vector2i) -> Array:
	# 업그레이드된 호미/물뿌리개는 전방 3칸(진행 방향의 좌우 포함)에 적용된다.
	var out := [base]
	if GameData.tool_level.get(GameData.tool, 1) >= 2:
		var perp := Vector2i(0, 1) if player.dir in ["left", "right"] else Vector2i(1, 0)
		out.append(base + perp)
		out.append(base - perp)
	return out


func use_tool() -> void:
	var t := target_tile()
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return
	var cell: Dictionary = grid[t.y][t.x]
	var obj: Variant = objects.get(t)
	var cost: float = ENERGY_COST[GameData.tool]

	if GameData.energy < cost:
		hud.show_message("너무 지쳤다... 자러 가야 할 것 같다.")
		return

	match GameData.tool:
		"hoe":
			if cell.crop_id != "" and cell.dead:
				# 시든 작물 정리
				cell.crop_id = ""
				cell.crop_day = 0
				cell.dead = false
				GameData.energy -= cost
				hud.show_message("시든 작물을 정리했다.")
			elif obj != null:
				hud.show_message("여기는 갈 수 없다.")
				return
			elif cell.ground == "soil" and cell.crop_id == "":
				cell.ground = "grass"
				cell.watered = false
				GameData.energy -= cost
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
						c.watered = true
					worked = true
				if worked:
					GameData.energy -= cost
		"water":
			var worked := false
			for pos: Vector2i in _affected_tiles(t):
				if pos.x < 0 or pos.y < 0 or pos.x >= MAP_W or pos.y >= MAP_H:
					continue
				var c: Dictionary = grid[pos.y][pos.x]
				if c.ground == "soil" and not c.watered and not objects.has(pos):
					c.watered = true
					worked = true
			if worked:
				GameData.energy -= cost
			elif grid[t.y][t.x].ground != "soil":
				hud.show_message("물을 줄 곳이 아니다.")
		"seed":
			var id := GameData.current_seed_id()
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
			cell.crop_day = 0
			cell.dead = false
			if weather_now() == GameData.WEATHER_RAIN:
				cell.watered = true
			GameData.energy -= cost
		"hand":
			if cell.crop_id != "":
				if cell.dead:
					hud.show_message("시들어버렸다... 호미로 정리하자.")
					return
				var def: Dictionary = GameData.CROPS[cell.crop_id]
				if cell.crop_day >= def.grow_days:
					GameData.produce[cell.crop_id] += 1
					GameData.today_harvest += 1
					hud.show_message("%s 수확! (판매가 %dG)" % [def.name, def.sell_price])
					cell.crop_id = ""
					cell.crop_day = 0
					GameData.energy -= cost
				else:
					hud.show_message("아직 다 자라지 않았다.")
		"axe":
			if obj == null:
				hud.show_message("벨 것이 없다.")
				return
			if obj.kind == "tree":
				obj.hp -= 1
				GameData.energy -= cost
				if obj.hp <= 0:
					_remove_object(t)
					GameData.wood += WOOD_PER_TREE
					hud.show_message("나무를 베었다! 목재 +%d" % WOOD_PER_TREE)
				else:
					hud.show_message("나무를 찍었다. (%d/%d)" % [TREE_HP - obj.hp, TREE_HP])
			elif obj.kind == "fence":
				_remove_object(t)
				GameData.wood += GameData.FENCE_COST_WOOD
				GameData.energy -= cost
				hud.show_message("울타리를 회수했다.")
			else:
				hud.show_message("도끼로 벨 수 없다.")
		"pickaxe":
			if obj == null:
				hud.show_message("캘 것이 없다.")
				return
			if obj.kind == "rock":
				obj.hp -= 1
				GameData.energy -= cost
				if obj.hp <= 0:
					_remove_object(t)
					GameData.stone += STONE_PER_ROCK
					hud.show_message("돌을 캤다! 석재 +%d" % STONE_PER_ROCK)
				else:
					hud.show_message("돌을 내리쳤다. (%d/%d)" % [ROCK_HP - obj.hp, ROCK_HP])
			elif obj.kind == "sprinkler":
				_remove_object(t)
				GameData.wood += GameData.SPRINKLER_COST_WOOD
				GameData.stone += GameData.SPRINKLER_COST_STONE
				GameData.energy -= cost
				hud.show_message("스프링클러를 회수했다.")
			else:
				hud.show_message("곡괭이로 캘 수 없다.")
		"fence":
			if obj != null or cell.ground == "water" or cell.crop_id != "" or t == player_tile():
				hud.show_message("여기에는 설치할 수 없다.")
				return
			if GameData.wood < GameData.FENCE_COST_WOOD:
				hud.show_message("목재가 부족하다. (목재 %d 필요)" % GameData.FENCE_COST_WOOD)
				return
			GameData.wood -= GameData.FENCE_COST_WOOD
			_place_object(t, "fence", 0)
			GameData.energy -= cost
		"sprinkler":
			if obj != null or cell.ground == "water" or cell.crop_id != "" or t == player_tile():
				hud.show_message("여기에는 설치할 수 없다.")
				return
			if GameData.wood < GameData.SPRINKLER_COST_WOOD or GameData.stone < GameData.SPRINKLER_COST_STONE:
				hud.show_message("재료 부족: 목재 %d + 석재 %d 필요" %
					[GameData.SPRINKLER_COST_WOOD, GameData.SPRINKLER_COST_STONE])
				return
			GameData.wood -= GameData.SPRINKLER_COST_WOOD
			GameData.stone -= GameData.SPRINKLER_COST_STONE
			_place_object(t, "sprinkler", 0)
			GameData.energy -= cost
			hud.show_message("스프링클러 설치! 매일 아침 주변 4칸에 물을 준다.")
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
					fishing_ui.start(pending_fish[2])
	queue_redraw()


func interact() -> void:
	# 가까운 동물 쓰다듬기(=먹이 주기)
	for a in animals:
		if (a.position - player.position).length() < 22.0:
			var def: Dictionary = GameData.ANIMALS[a.type]
			if a.fed:
				hud.show_message("%s는 이미 만족스러워 보인다." % def.name)
			else:
				a.fed = true
				hud.show_message("%s를 쓰다듬었다! ♥ 내일 아침 %s을 준다." %
					[def.name, GameData.ITEMS[def.product].name])
			return
	for t in [target_tile(), player_tile()]:
		var obj: Variant = objects.get(t)
		if obj == null:
			continue
		if obj.kind == "bin":
			shop.open("sell")
			return
		if obj.kind == "house":
			sleep_dialog.popup_centered()
			return
	hud.show_message("집 문 앞에서 E: 취침 · 출하 상자 앞에서 E: 판매")


# ---- 동물 ----

func spawn_animal(type: String, pos: Vector2 = Vector2.ZERO, fed: bool = false) -> void:
	var a: Node2D = preload("res://scripts/animal.gd").new()
	a.main = self
	a.type = type
	a.fed = fed
	if pos == Vector2.ZERO:
		var t := _find_free_tile_near(Vector2i(10, 7))
		pos = Vector2(t.x * TILE + 8, t.y * TILE + 8)
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

func _next_day(passed_out: bool) -> void:
	# 물 준 작물 성장
	for y in MAP_H:
		for x in MAP_W:
			var cell: Dictionary = grid[y][x]
			if cell.crop_id != "" and not cell.dead and cell.watered:
				cell.crop_day += 1
			cell.watered = false

	var stats := [GameData.today_harvest, GameData.today_earned, GameData.today_spent]
	var prev_season := GameData.season()
	GameData.day += 1
	GameData.minutes = GameData.DAY_START
	GameData.energy = GameData.ENERGY_MAX * 0.5 if passed_out else GameData.ENERGY_MAX
	GameData.reset_daily()

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

	# 비 오는 날은 밭이 저절로 젖는다
	if weather_now() == GameData.WEATHER_RAIN:
		for y in MAP_H:
			for x in MAP_W:
				if grid[y][x].ground == "soil":
					grid[y][x].watered = true

	# 스프링클러는 주변 4칸에 물을 준다
	for pos: Vector2i in objects:
		if objects[pos].kind != "sprinkler":
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = pos + d
			if n.x >= 0 and n.y >= 0 and n.x < MAP_W and n.y < MAP_H \
					and grid[n.y][n.x].ground == "soil":
				grid[n.y][n.x].watered = true

	# 동물 생산물 수거
	var collected := {}
	for a in animals:
		if a.fed:
			var product: String = GameData.ANIMALS[a.type].product
			GameData.items[product] += 1
			collected[product] = int(collected.get(product, 0)) + 1
		a.fed = false

	# 나무/돌이 조금씩 다시 자란다
	_respawn_resources()

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

	summary.open("- %s %d일 아침 -" % [GameData.season_name(), GameData.day_in_season()],
		"어제 수확: %d개\n판매 수입: +%dG\n지출: -%dG\n소지금: %dG\n%s"
		% [stats[0], stats[1], stats[2], GameData.money, note])
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
		if (pos - player_tile()).length() < 4.0:
			continue
		_place_object(pos, kind, TREE_HP if kind == "tree" else ROCK_HP)
		break


# ---- 저장 ----

func save_now() -> void:
	var g := []
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			var c: Dictionary = grid[y][x]
			row.append([c.ground, 1 if c.watered else 0, c.crop_id, c.crop_day, 1 if c.dead else 0])
		g.append(row)
	var objs := []
	for pos: Vector2i in objects:
		objs.append([pos.x, pos.y, objects[pos].kind, objects[pos].hp])
	var anims := []
	for a in animals:
		anims.append([a.type, a.position.x, a.position.y, 1 if a.fed else 0])
	GameData.save_game(g, player.position, objs, anims)


func _apply_save(d: Dictionary) -> void:
	GameData.day = int(d.day)
	GameData.minutes = float(d.minutes)
	GameData.money = int(d.money)
	GameData.energy = float(d.energy)
	GameData.wood = int(d.get("wood", 0))
	GameData.stone = int(d.get("stone", 0))
	for k in d.get("tool_level", {}):
		GameData.tool_level[k] = int(d.tool_level[k])
	for k in d.seeds:
		GameData.seeds[k] = int(d.seeds[k])
	for k in d.produce:
		GameData.produce[k] = int(d.produce[k])
	for k in d.get("items", {}):
		GameData.items[k] = int(d.items[k])
	for k in d.get("fish_caught", {}):
		GameData.fish_caught[k] = int(d.fish_caught[k])
	for a in d.get("animals", []):
		spawn_animal(a[0], Vector2(float(a[1]), float(a[2])), int(a[3]) == 1)
	player.position = Vector2(float(d.player[0]), float(d.player[1]))

	# 맵 크기가 다른 옛 저장이면 밭 상태는 버리고 진행 상황만 복원한다
	var g: Array = d.grid
	if g.size() != MAP_H or (g.size() > 0 and g[0].size() != MAP_W):
		player.position = Vector2(START_TILE.x * TILE + 8, START_TILE.y * TILE + 8)
		return
	for y in MAP_H:
		for x in MAP_W:
			var s: Array = g[y][x]
			var cell: Dictionary = grid[y][x]
			# 물 타일은 맵 생성 결과를 유지하고 경작 상태만 복원
			if cell.ground != "water" and s[0] != "water":
				cell.ground = s[0]
			cell.watered = int(s[1]) == 1
			cell.crop_id = s[2]
			cell.crop_day = int(s[3])
			cell.dead = s.size() > 4 and int(s[4]) == 1
	if d.has("objects"):
		objects.clear()
		for o in d.objects:
			objects[Vector2i(int(o[0]), int(o[1]))] = {"kind": o[2], "hp": int(o[3])}


# ---- 루프 ----

func _process(delta: float) -> void:
	if not ui_open():
		GameData.minutes += delta * MIN_PER_SEC
		if GameData.minutes >= GameData.DAY_END:
			_next_day(true)
		water_timer += delta
		if water_timer > 0.8:
			water_timer = 0.0
			water_frame = 1 - water_frame
		_update_fishing(delta)
	weather_time += delta
	_update_night()
	hud.refresh()
	queue_redraw()
	if _shot_path != "":
		_debug_tick()


func _update_night() -> void:
	var start := 18.0 * 60.0
	var a := clampf((GameData.minutes - start) / (6.0 * 60.0), 0.0, 1.0)
	var c := Color(1, 1, 1).lerp(Color(0.5, 0.48, 0.72), a)
	if weather_now() == GameData.WEATHER_RAIN:
		c *= Color(0.78, 0.8, 0.88)  # 비 오는 날은 어둑하게
	night.color = c


func _unhandled_input(event: InputEvent) -> void:
	if ui_open():
		if event.is_action_pressed("ui_cancel"):
			shop.close()
			summary.close()
		return
	if event.is_action_pressed("tool_1"):
		set_tool("hoe")
	elif event.is_action_pressed("tool_2"):
		set_tool("water")
	elif event.is_action_pressed("tool_3"):
		set_tool("seed")
	elif event.is_action_pressed("tool_4"):
		set_tool("hand")
	elif event.is_action_pressed("tool_5"):
		set_tool("axe")
	elif event.is_action_pressed("tool_6"):
		set_tool("pickaxe")
	elif event.is_action_pressed("tool_7"):
		set_tool("fence")
	elif event.is_action_pressed("tool_8"):
		set_tool("sprinkler")
	elif event.is_action_pressed("tool_9"):
		set_tool("rod")
	elif event.is_action_pressed("cycle_seed"):
		GameData.cycle_seed()
		set_tool("seed")
	elif event.is_action_pressed("use_tool"):
		use_tool()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("open_shop"):
		shop.open("buy")
	elif event.is_action_pressed("save_game"):
		save_now()
		hud.show_message("저장했다!")
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_click_at(get_canvas_transform().affine_inverse() * event.position)


func _click_at(pos: Vector2) -> void:
	# 플레이어 인접(또는 발밑) 타일 클릭 시 그 방향을 보고 도구를 쓴다.
	var t := Vector2i(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))
	var d := t - player_tile()
	if absi(d.x) + absi(d.y) == 1:
		if d.x == 1:
			player.dir = "right"
		elif d.x == -1:
			player.dir = "left"
		elif d.y == 1:
			player.dir = "down"
		else:
			player.dir = "up"
		use_tool()
	elif d == Vector2i.ZERO:
		use_tool()


# ---- 렌더링 ----

func _crop_texture(cell: Dictionary) -> Texture2D:
	if cell.dead:
		return tex["withered"]
	var def: Dictionary = GameData.CROPS[cell.crop_id]
	if cell.crop_day >= def.grow_days:
		return tex["mature_" + cell.crop_id]
	var t := float(cell.crop_day) / float(def.grow_days)
	if t < 0.34:
		return tex["crop_sprout"]
	if t < 0.67:
		return tex["crop_small"]
	return tex["crop_medium"]


func _draw() -> void:
	var grass_prefix := "grass_" + GameData.season_key() + "_"
	for y in MAP_H:
		for x in MAP_W:
			var cell: Dictionary = grid[y][x]
			var t: Texture2D
			if cell.ground == "water":
				t = tex["water_%d" % water_frame]
			elif cell.ground == "soil":
				t = tex["soil_wet"] if cell.watered else tex["soil_dry"]
			else:
				t = tex[grass_prefix + str(int(_hash01(x, y) * 3.0) % 3)]
			draw_texture(t, Vector2(x * TILE, y * TILE))
			if cell.crop_id != "":
				draw_texture(_crop_texture(cell), Vector2(x * TILE, y * TILE))

	# 타겟 타일 하이라이트
	if player != null:
		var tt := target_tile()
		if tt.x >= 0 and tt.y >= 0 and tt.x < MAP_W and tt.y < MAP_H:
			draw_rect(Rect2(Vector2(tt.x * TILE, tt.y * TILE), Vector2(TILE, TILE)),
				Color(1, 1, 1, 0.6), false, 1.0)

	# 낚시 인디케이터 (대기: 점점점 / 입질: 노란 느낌표)
	if fishing_state == "waiting":
		var base := player.position + Vector2(-6, -38)
		var dots := int(weather_time * 2.0) % 3 + 1
		for i in dots:
			draw_rect(Rect2(base + Vector2(i * 5, 0), Vector2(2, 2)), Color(1, 1, 1, 0.8))
	elif fishing_state == "bite":
		var base := player.position + Vector2(-1, -46)
		draw_rect(Rect2(base, Vector2(3, 7)), Color(1, 0.85, 0.2))
		draw_rect(Rect2(base + Vector2(0, 9), Vector2(3, 3)), Color(1, 0.85, 0.2))

	_draw_weather()


func _draw_weather() -> void:
	var w := weather_now()
	var full_w := MAP_W * TILE + 20.0
	var full_h := MAP_H * TILE + 10.0
	if w == GameData.WEATHER_RAIN:
		for i in 360:
			var sx := _hash01(i, 1) * full_w - 10.0
			var sy := fposmod(_hash01(i, 2) * full_h + weather_time * 280.0, full_h) - 5.0
			draw_line(Vector2(sx - 2, sy - 7), Vector2(sx, sy), Color(0.72, 0.82, 1.0, 0.5), 1.0)
	elif w == GameData.WEATHER_SNOW:
		for i in 240:
			var sx := fposmod(_hash01(i, 1) * full_w + sin(weather_time * 1.5 + i) * 12.0, full_w)
			var sy := fposmod(_hash01(i, 2) * full_h + weather_time * 35.0, full_h) - 5.0
			draw_rect(Rect2(Vector2(sx, sy), Vector2(1, 1)), Color(1, 1, 1, 0.85))


# ---- 검증 시퀀스 ----
# 키/마우스 이벤트를 실제 InputMap 경로로 흘려보내
# 밭갈기->클릭 경작->물주기->파종->자원->설치->상점->결산까지 자동 재생한다.

func _debug_tick() -> void:
	_shot_frames += 1
	match _shot_frames:
		10: _send_key(KEY_1)
		14: _send_key(KEY_SPACE)                       # 아래 타일 밭 갈기
		18: _send_click(Vector2((START_TILE.x + 1) * TILE + 8, START_TILE.y * TILE + 8))
		22: _send_key(KEY_2)
		26: _send_key(KEY_SPACE)                       # 물 주기
		30: _send_key(KEY_3)
		34: _send_key(KEY_SPACE)                       # 씨앗 심기
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
		70: _save_shot("_game.png")
		74: _send_key(KEY_B)                           # 상점 열기
		76:
			GameData.money = 3000
			shop._on_tab("animal")                     # 동물 탭에서 닭+소 입양
		78: shop._on_buy_animal("chicken")
		80: shop._on_buy_animal("cow")
		84: _save_shot("_shop.png")
		88: shop.close()
		92:
			player.position = Vector2(25 * TILE + 8, 12 * TILE + 8)
			player.dir = "down"                        # 연못가로 이동
		96: _send_key(KEY_9)
		100: _send_key(KEY_SPACE)                      # 캐스팅
		102: fishing_timer = 0.2                       # 입질 시간 단축
		112: _send_key(KEY_SPACE)                      # 입질! -> 미니게임
		118: _save_shot("_fishing.png")
		122: _send_key(KEY_SPACE)                      # 타이밍 판정
		130:
			for a in animals:
				a.fed = true                           # 아침 생산 테스트
			_next_day(false)
		138:
			_save_shot("_summary.png")
			get_tree().quit()


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
