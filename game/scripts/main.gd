# 메인 월드: 맵, 경작, 도구, 시간, 낮/밤을 관리한다.
extends Node2D

const MAP_W := 30
const MAP_H := 20
const TILE := 16

const MIN_PER_SEC := 10.0 / 7.0  # 실제 7초 = 게임 10분
const ENERGY_COST := {"hoe": 2.0, "water": 1.0, "seed": 1.0, "hand": 1.0}

# grid[y][x] = {ground: "grass"|"soil"|"water", watered: bool, crop_id: String, crop_day: int}
var grid: Array = []
# Vector2i -> "tree" | "rock" | "house" | "bin"
var objects: Dictionary = {}

var tex: Dictionary = {}
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
	"rock", "bin", "house",
	"grass_spring_0", "grass_spring_1", "grass_spring_2",
	"grass_summer_0", "grass_summer_1", "grass_summer_2",
	"grass_fall_0", "grass_fall_1", "grass_fall_2",
	"grass_winter_0", "grass_winter_1", "grass_winter_2",
	"soil_dry", "soil_wet", "water_0", "water_1",
]


func _ready() -> void:
	_load_textures()
	_build_map()

	night = CanvasModulate.new()
	add_child(night)

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	_spawn_objects(world)

	player = preload("res://scenes/player.tscn").instantiate()
	player.main = self
	player.position = Vector2(10 * TILE + 8, 9 * TILE + 8)
	world.add_child(player)

	hud = preload("res://scenes/hud.tscn").instantiate()
	hud.main = self
	add_child(hud)

	shop = preload("res://scenes/shop.tscn").instantiate()
	shop.main = self
	add_child(shop)

	summary = preload("res://scenes/summary.tscn").instantiate()
	add_child(summary)

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
	_apply_season_visuals()


func _load_textures() -> void:
	for n in TEXTURE_NAMES:
		tex[n] = load("res://assets/sprites/%s.png" % n)


# ---- 맵 ----

func _build_map() -> void:
	grid = []
	objects = {}
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			row.append({"ground": "grass", "watered": false, "crop_id": "", "crop_day": 0, "dead": false})
		grid.append(row)

	# 연못 (오른쪽 아래)
	for y in range(13, 18):
		for x in range(23, 28):
			grid[y][x].ground = "water"

	# 집 (왼쪽 위 5x4 타일)
	for y in range(1, 5):
		for x in range(2, 7):
			objects[Vector2i(x, y)] = "house"

	# 출하 상자
	objects[Vector2i(9, 4)] = "bin"

	# 테두리 나무
	for x in MAP_W:
		if _hash01(x, 0) < 0.75 and not objects.has(Vector2i(x, 0)):
			objects[Vector2i(x, 0)] = "tree"
		if _hash01(x, MAP_H - 1) < 0.75:
			objects[Vector2i(x, MAP_H - 1)] = "tree"
	for y in MAP_H:
		if _hash01(0, y) < 0.75 and not objects.has(Vector2i(0, y)):
			objects[Vector2i(0, y)] = "tree"
		if _hash01(MAP_W - 1, y) < 0.75 and not objects.has(Vector2i(MAP_W - 1, y)):
			objects[Vector2i(MAP_W - 1, y)] = "tree"

	# 흩어진 나무/돌
	var decor := [
		[12, 2, "tree"], [18, 3, "tree"], [24, 2, "tree"], [21, 7, "tree"],
		[3, 12, "tree"], [5, 16, "tree"], [16, 16, "rock"], [8, 8, "rock"],
		[19, 12, "rock"], [26, 8, "rock"], [13, 6, "rock"],
	]
	for d in decor:
		var pos := Vector2i(d[0], d[1])
		if not objects.has(pos) and grid[d[1]][d[0]].ground == "grass":
			objects[pos] = d[2]


func _spawn_objects(world: Node2D) -> void:
	var house_done := false
	for pos: Vector2i in objects:
		var kind: String = objects[pos]
		if kind == "house":
			if house_done:
				continue
			house_done = true
			world.add_child(_make_object(tex["house"], Vector2(2 * TILE, 5 * TILE), Vector2(0, -64)))
		elif kind == "tree":
			var t := _make_object(tex["tree_spring"], Vector2(pos.x * TILE, (pos.y + 1) * TILE), Vector2(0, -18))
			tree_sprites.append(t.get_child(0))
			world.add_child(t)
		elif kind == "rock":
			world.add_child(_make_object(tex["rock"], Vector2(pos.x * TILE, (pos.y + 1) * TILE), Vector2(0, -16)))
		elif kind == "bin":
			world.add_child(_make_object(tex["bin"], Vector2(pos.x * TILE, (pos.y + 1) * TILE), Vector2(0, -16)))


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
	return shop.visible or summary.visible or sleep_dialog.visible


# ---- 도구/상호작용 ----

func set_tool(t: String) -> void:
	GameData.tool = t


func use_tool() -> void:
	var t := target_tile()
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return
	var cell: Dictionary = grid[t.y][t.x]
	var has_obj := objects.has(t)
	var cost: float = ENERGY_COST[GameData.tool]

	if GameData.energy < cost:
		hud.show_message("너무 지쳤다... 자러 가야 할 것 같다.")
		return

	match GameData.tool:
		"hoe":
			if has_obj:
				hud.show_message("여기는 갈 수 없다.")
				return
			if cell.crop_id != "" and cell.dead:
				# 시든 작물 정리
				cell.crop_id = ""
				cell.crop_day = 0
				cell.dead = false
				GameData.energy -= cost
				hud.show_message("시든 작물을 정리했다.")
			elif cell.ground == "grass":
				cell.ground = "soil"
				if weather_now() == GameData.WEATHER_RAIN:
					cell.watered = true
				GameData.energy -= cost
			elif cell.ground == "soil" and cell.crop_id == "":
				cell.ground = "grass"
				cell.watered = false
				GameData.energy -= cost
		"water":
			if cell.ground == "soil":
				if not cell.watered:
					cell.watered = true
					GameData.energy -= cost
			else:
				hud.show_message("물을 줄 곳이 아니다.")
		"seed":
			var id := GameData.current_seed_id()
			if id == "":
				hud.show_message("씨앗이 없다. 상점(B)에서 사자.")
				return
			if cell.ground != "soil":
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
	queue_redraw()


func interact() -> void:
	for t in [target_tile(), player_tile()]:
		if objects.get(t, "") == "bin":
			shop.open("sell")
			return
		if objects.get(t, "") == "house":
			sleep_dialog.popup_centered()
			return
	hud.show_message("집 문 앞에서 E: 취침 · 출하 상자 앞에서 E: 판매")


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

	save_now()

	var note := ""
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
		"어제 수확: %d개\n판매 수입: +%dG\n씨앗 지출: -%dG\n소지금: %dG\n%s"
		% [stats[0], stats[1], stats[2], GameData.money, note])
	queue_redraw()


# ---- 저장 ----

func save_now() -> void:
	var g := []
	for y in MAP_H:
		var row := []
		for x in MAP_W:
			var c: Dictionary = grid[y][x]
			row.append([c.ground, 1 if c.watered else 0, c.crop_id, c.crop_day, 1 if c.dead else 0])
		g.append(row)
	GameData.save_game(g, player.position)


func _apply_save(d: Dictionary) -> void:
	GameData.day = int(d.day)
	GameData.minutes = float(d.minutes)
	GameData.money = int(d.money)
	GameData.energy = float(d.energy)
	for k in d.seeds:
		GameData.seeds[k] = int(d.seeds[k])
	for k in d.produce:
		GameData.produce[k] = int(d.produce[k])
	player.position = Vector2(float(d.player[0]), float(d.player[1]))
	for y in MAP_H:
		for x in MAP_W:
			var s: Array = d.grid[y][x]
			var cell: Dictionary = grid[y][x]
			# 물 타일은 맵 생성 결과를 유지하고 경작 상태만 복원
			if cell.ground != "water" and s[0] != "water":
				cell.ground = s[0]
			cell.watered = int(s[1]) == 1
			cell.crop_id = s[2]
			cell.crop_day = int(s[3])
			cell.dead = s.size() > 4 and int(s[4]) == 1


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
	weather_time += delta
	_update_night()
	hud.refresh()
	queue_redraw()
	if _shot_path != "":
		_debug_tick()


# 스크린샷 검증 시퀀스: 키/마우스 이벤트를 실제 InputMap 경로로 흘려보내
# 밭갈기->클릭 경작->물주기->파종->상점->결산까지 자동 재생한다.
func _debug_tick() -> void:
	_shot_frames += 1
	match _shot_frames:
		10: _send_key(KEY_1)
		14: _send_key(KEY_SPACE)                       # 아래 타일 밭 갈기
		18: _send_click(Vector2(11 * TILE + 8, 9 * TILE + 8))  # 오른쪽 타일 클릭 경작
		22: _send_key(KEY_2)
		26: _send_key(KEY_SPACE)                       # 물 주기
		30: _send_key(KEY_3)
		34: _send_key(KEY_SPACE)                       # 씨앗 심기
		40: _save_shot("_game.png")
		44: _send_key(KEY_B)                           # 상점 열기
		54: _save_shot("_shop.png")
		58:
			shop.close()
			_next_day(false)                           # 결산 화면
		66:
			_save_shot("_summary.png")
			get_tree().quit()


func _send_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
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

	_draw_weather()


func _draw_weather() -> void:
	var w := weather_now()
	if w == GameData.WEATHER_RAIN:
		for i in 90:
			var sx := _hash01(i, 1) * 500.0 - 10.0
			var sy := fposmod(_hash01(i, 2) * 330.0 + weather_time * 280.0, 330.0) - 5.0
			draw_line(Vector2(sx - 2, sy - 7), Vector2(sx, sy), Color(0.72, 0.82, 1.0, 0.5), 1.0)
	elif w == GameData.WEATHER_SNOW:
		for i in 60:
			var sx := fposmod(_hash01(i, 1) * 480.0 + sin(weather_time * 1.5 + i) * 12.0, 480.0)
			var sy := fposmod(_hash01(i, 2) * 330.0 + weather_time * 35.0, 330.0) - 5.0
			draw_rect(Rect2(Vector2(sx, sy), Vector2(1, 1)), Color(1, 1, 1, 0.85))
