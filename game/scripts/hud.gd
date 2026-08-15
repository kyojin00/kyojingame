# HUD (스타듀 스타일): 우측 상단 나무 패널(날짜/시계/돈/체력) + 퀘스트 트래커,
# 하단 중앙 핫바(빠른 사용 슬롯 9칸 — 1~9 숫자키, 가방에서 자유 배치).
extends CanvasLayer

const TOOL_ICONS := {
	"hoe": "icon_hoe", "water": "icon_water", "seed": "icon_seed",
	"axe": "icon_axe", "pickaxe": "icon_pickaxe", "fence": "fence",
	"sprinkler": "sprinkler", "rod": "icon_rod",
	"spear": "icon_spear", "sword": "icon_sword",
}


# 도구 아이콘 (강화 단계 반영: 도끼 2강 이상 = 돌도끼)
func tool_icon(t: String) -> Texture2D:
	if t == "axe" and int(GameData.tool_level.get("axe", 1)) >= 2:
		return main.tex["icon_axe_stone"]
	return main.tex[TOOL_ICONS[t]]
const TOOL_LABELS := {
	"hoe": "호미", "water": "물뿌리개",
	"axe": "도끼", "pickaxe": "곡괭이", "fence": "울타리",
	"sprinkler": "스프링클러", "rod": "낚싯대",
	"spear": "돌 창", "sword": "돌 검",
}
# 도구 -> 관련 숙련도
const TOOL_SKILL := {
	"hoe": "farm", "water": "farm", "seed": "farm",
	"axe": "forest", "pickaxe": "mine", "rod": "fish",
	"spear": "combat", "sword": "combat",
}
# 나무 프레임 팔레트
const WOOD_TEXT := Color(0.29, 0.16, 0.06)
# 작은 글씨용 갈무리9 (작은 크기에서 뭉개지지 않게)
const FONT_SMALL := preload("res://assets/fonts/Galmuri9.ttf")

var main: Node2D
var msg_timer := 0.0

var hotbar_panel: Panel
var slot_buttons: Array = []
var _slot_normal: StyleBoxFlat
var _slot_selected: StyleBoxFlat

@onready var day_label: Label = $ClockPanel/DayLabel
@onready var clock_label: Label = $ClockPanel/ClockLabel
@onready var money_label: Label = $ClockPanel/MoneyLabel
@onready var energy_bar: ProgressBar = $EnergyPanel/EnergyBar
@onready var msg_label: Label = $Message
@onready var objective_label: Label = $TrackerPanel/Objective
@onready var tool_name: Label = $ToolName


func _wood_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.91, 0.71, 0.42, 0.97)
	st.border_color = Color(0.43, 0.24, 0.11)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	return st


func _ready() -> void:
	$ClockPanel/CoinIcon.texture = main.tex["icon_coin"]
	$EnergyPanel/HeartIcon.texture = main.tex["icon_heart"]
	$ClockPanel.add_theme_stylebox_override("panel", _wood_style())
	$EnergyPanel.add_theme_stylebox_override("panel", _wood_style())
	_build_tracker_scroll()
	_build_minimap()
	_build_hotbar()
	_build_hunger()


# ---- 배고픔 게이지 (체력 막대 위) ----
#
# 글자는 한 자도 없다 — 밥그릇 그림 하나와 막대뿐이다.
# 배고픔이 열리기 전(스토리 3 전)에는 아예 보이지 않는다.
var hunger_panel: Panel
var hunger_bar: ProgressBar
var hunger_icon: TextureRect


func _build_hunger() -> void:
	hunger_panel = Panel.new()
	hunger_panel.add_theme_stylebox_override("panel", _wood_style())
	hunger_panel.position = Vector2(6, 466)
	hunger_panel.size = Vector2(194, 30)
	hunger_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hunger_panel.visible = false
	add_child(hunger_panel)

	hunger_icon = TextureRect.new()
	hunger_icon.position = Vector2(8, 5)
	hunger_icon.size = Vector2(20, 20)
	hunger_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hunger_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hunger_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cand in ["dish_bread", "dish_baked_potato", "icon_seed"]:
		if main.tex.has(cand):
			hunger_icon.texture = main.tex[cand]
			break
	hunger_panel.add_child(hunger_icon)

	hunger_bar = ProgressBar.new()
	hunger_bar.position = Vector2(32, 8)
	hunger_bar.size = Vector2(154, 13)
	hunger_bar.max_value = GameData.HUNGER_MAX
	hunger_bar.show_percentage = false
	hunger_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.28, 0.19, 0.11)
	bg.set_corner_radius_all(3)
	hunger_bar.add_theme_stylebox_override("background", bg)
	hunger_bar.add_theme_stylebox_override("fill", _hunger_fill(1.0))
	hunger_panel.add_child(hunger_bar)


# 배가 부를수록 노릇하고, 꺼질수록 붉어진다 (숫자 없이 색으로 읽는다)
func _hunger_fill(ratio: float) -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.72, 0.28) if ratio > 0.45 \
		else (Color(0.9, 0.5, 0.2) if ratio > 0.15 else Color(0.86, 0.28, 0.24))
	fill.set_corner_radius_all(3)
	return fill


func _refresh_hunger() -> void:
	if hunger_panel == null:
		return
	hunger_panel.visible = GameData.hunger_open
	if not GameData.hunger_open:
		return
	var ratio := GameData.hunger / GameData.HUNGER_MAX
	hunger_bar.value = GameData.hunger
	hunger_bar.add_theme_stylebox_override("fill", _hunger_fill(ratio))
	# 굶으면 밥그릇이 깜빡인다 — 말 대신 그림이 재촉한다
	var t := float(Time.get_ticks_msec()) / 1000.0
	hunger_icon.modulate = Color(1, 1, 1) if ratio > 0.0 \
		else Color(1, 0.6, 0.6, 0.55 + 0.45 * sin(t * 6.0))


# ---- 미니맵 (좌측 상단) ----
#
# M키 지도는 맵 전체를 보여주고, 이쪽은 **내 주변만** 항상 띄워 둔다.
# 90x60을 다 담으면 타일이 2px도 안 돼 알아볼 수 없기 때문이다.
# 안개(가 본 곳만 보이기) 규칙은 M키 지도와 똑같이 map_ui에 맡긴다.
const MM_TX := 31          # 가로로 보이는 타일 수 (플레이어가 한가운데)
const MM_TY := 21
const MM_CELL := 5.0
const MM_FOG := Color(0.13, 0.14, 0.19)        # 먹구름 그늘 (M 지도와 같은 팔레트)
const MM_CLOUD_MID := Color(0.21, 0.22, 0.28)
const MM_CLOUD_TOP := Color(0.29, 0.30, 0.37)

var minimap_panel: Panel
var minimap: Control


func _build_minimap() -> void:
	minimap_panel = Panel.new()
	minimap_panel.add_theme_stylebox_override("panel", _wood_style())
	minimap_panel.position = Vector2(6, 5)
	minimap_panel.size = Vector2(MM_TX * MM_CELL + 8, MM_TY * MM_CELL + 8)
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(minimap_panel)

	minimap = Control.new()
	minimap.position = Vector2(4, 4)
	minimap.size = Vector2(MM_TX * MM_CELL, MM_TY * MM_CELL)
	minimap.clip_contents = true
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	minimap_panel.add_child(minimap)


func _minimap_color(x: int, y: int) -> Color:
	var cell: Dictionary = main.grid[y][x]
	if cell.ground == "water":
		return Color(0.26, 0.45, 0.68)
	if cell.ground == "path":
		return Color(0.72, 0.62, 0.44)
	if cell.ground == "soil":
		return Color(0.42, 0.31, 0.19)
	match GameData.season():
		GameData.WINTER:
			return Color(0.82, 0.85, 0.9)
		GameData.FALL:
			return Color(0.62, 0.5, 0.3)
	return Color(0.32, 0.52, 0.27)


# 미니맵의 먹구름 — 큰 지도와 같은 규칙(칸 좌표로 정해지는 덩어리)
func _draw_mm_clouds(x0: int, y0: int) -> void:
	for ty in MM_TY:
		for tx in MM_TX:
			var x: int = x0 + tx
			var y: int = y0 + ty
			var out: bool = x < 0 or y < 0 or x >= main.MAP_W or y >= main.MAP_H
			if not out and main.map_ui._visible_tile(x, y):
				continue
			if tx % 2 != 0 or ty % 2 != 0:
				continue
			var rx: float = float(main.map_ui._cloud_rand(x, y, 1))
			var ry: float = float(main.map_ui._cloud_rand(x, y, 2))
			var rs: float = float(main.map_ui._cloud_rand(x, y, 3))
			var c := Vector2((tx + 1.0 + (rx - 0.5)) * MM_CELL,
				(ty + 1.0 + (ry - 0.5)) * MM_CELL)
			var r1: float = MM_CELL * (1.5 + rs * 0.7)
			minimap.draw_circle(c, r1, MM_FOG.lerp(MM_CLOUD_MID, 0.45 + rs * 0.55))
			if rs > 0.35:
				minimap.draw_circle(c - Vector2(0.0, MM_CELL * 0.5),
					r1 * 0.4, MM_CLOUD_MID.lerp(MM_CLOUD_TOP, 0.5))


func _draw_minimap() -> void:
	var pt: Vector2i = main.player_tile()
	var x0: int = pt.x - MM_TX / 2
	var y0: int = pt.y - MM_TY / 2
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), MM_FOG)
	# 아직 가 보지 않은 곳은 먹구름이 덮는다 (M 지도와 같은 그림)
	_draw_mm_clouds(x0, y0)

	for ty in MM_TY:
		for tx in MM_TX:
			var x: int = x0 + tx
			var y: int = y0 + ty
			if x < 0 or y < 0 or x >= main.MAP_W or y >= main.MAP_H:
				continue  # 맵 밖은 구름 그대로
			if not main.map_ui._visible_tile(x, y):
				continue
			var r := Rect2(tx * MM_CELL, ty * MM_CELL, MM_CELL, MM_CELL)
			minimap.draw_rect(r, _minimap_color(x, y))
			var obj: Variant = main.objects.get(Vector2i(x, y))
			if obj != null:
				minimap.draw_rect(r, MM_OBJ_COLORS.get(obj.kind, Color(0.5, 0.4, 0.3)))

	# 사람·동물은 점 하나로 (플레이어는 한가운데 흰 점)
	for n in main.npcs:
		if n.visible:
			_mm_dot(n.position, x0, y0, Color(0.97, 0.55, 0.75))
	for a in main.animals:
		_mm_dot(a.position, x0, y0, Color(0.97, 0.97, 0.92))
	var c := Vector2((MM_TX / 2) * MM_CELL, (MM_TY / 2) * MM_CELL)
	minimap.draw_rect(Rect2(c - Vector2(1, 1), Vector2(MM_CELL + 2, MM_CELL + 2)),
		Color(0.1, 0.08, 0.06))
	minimap.draw_rect(Rect2(c, Vector2(MM_CELL, MM_CELL)), Color(1, 1, 1))


const MM_OBJ_COLORS := {
	"tree": Color(0.09, 0.24, 0.1), "worldtree": Color(0.35, 0.7, 0.45),
	"rock": Color(0.55, 0.55, 0.6), "bigrock": Color(0.45, 0.45, 0.5),
	"house": Color(0.62, 0.28, 0.2), "art_block": Color(0.62, 0.28, 0.2),
	"barn": Color(0.66, 0.42, 0.24), "barn_block": Color(0.66, 0.42, 0.24),
	"board": Color(0.95, 0.8, 0.35),
	"cave": Color(0.2, 0.16, 0.2), "sign": Color(0.9, 0.76, 0.4),
	"forage_berry": Color(0.85, 0.3, 0.4), "forage_herb": Color(0.5, 0.8, 0.4),
	"deco_fountain": Color(0.4, 0.66, 0.85),
}


func _mm_dot(pos: Vector2, x0: int, y0: int, col: Color) -> void:
	var p := Vector2((pos.x / 32.0 - x0) * MM_CELL, (pos.y / 32.0 - y0) * MM_CELL)
	if p.x < 0 or p.y < 0 or p.x > minimap.size.x or p.y > minimap.size.y:
		return
	minimap.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(4, 4)), col)


# ---- 퀘스트 트래커: 픽셀아트 두루마리 ----

var quest_title_label: Label = null   # 퀘스트 제목 (진한 브라운)
var goal_label: Label = null          # 📍 현재 목표 (강조색 — 제일 눈에 띈다)


func _build_tracker_scroll() -> void:
	var panel: Panel = $TrackerPanel
	var empty := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", empty)
	# 클릭하면 퀘스트 상세 창(Q)이 열린다
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = "클릭하면 퀘스트 상세가 열린다"
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			Sound.play_sfx("sfx_ui")
			main.quest_ui.toggle())
	# 두루마리 안은 딱 두 줄 — 퀘스트 이름(1줄) / 지금 할 행동(최대 2줄).
	# 설명·재료·진행 상황은 전부 Q 상세 창의 몫이다 (클릭하면 열린다).
	# 모든 글자는 말줄임(…)과 줄 수 제한으로 두루마리 밖으로 못 나간다.
	panel.offset_bottom = 128.0           # 작고 귀여운 메모 크기 (226x70)
	quest_title_label = Label.new()
	quest_title_label.position = Vector2(16, 10)
	quest_title_label.size = Vector2(192, 14)
	quest_title_label.add_theme_font_size_override("font_size", 11)
	quest_title_label.add_theme_color_override("font_color", Color(0.32, 0.2, 0.08))
	quest_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(quest_title_label)
	goal_label = Label.new()
	goal_label.position = Vector2(16, 26)
	goal_label.size = Vector2(192, 38)
	goal_label.add_theme_font_size_override("font_size", 10)
	goal_label.add_theme_color_override("font_color", Color(0.78, 0.42, 0.02))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 글씨를 줄인 만큼 세 줄까지 들어간다 — 목표가 짧아 대개 한 줄이다
	goal_label.max_lines_visible = 3
	goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(goal_label)
	# 「Q 상세보기」 안내 줄은 없앴다 — 트래커 클릭·툴팁이 그 역할을 한다
	objective_label.visible = false
	var deco := Control.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.show_behind_parent = true
	deco.draw.connect(func() -> void:
		var w := deco.size.x
		var h := deco.size.y
		var paper := Color(0.93, 0.85, 0.66)
		var paper_dk := Color(0.85, 0.75, 0.55)
		var edge := Color(0.55, 0.4, 0.2)
		var roll := Color(0.82, 0.71, 0.5)
		var roll_dk := Color(0.62, 0.49, 0.3)
		# 종이 몸통
		deco.draw_rect(Rect2(6, 8, w - 12, h - 16), paper)
		deco.draw_rect(Rect2(6, 8, 3, h - 16), paper_dk)       # 왼쪽 음영
		deco.draw_rect(Rect2(w - 9, 8, 3, h - 16), paper_dk)   # 오른쪽 음영
		deco.draw_rect(Rect2(6, 8, w - 12, h - 16), edge, false, 1.0)
		# 위/아래 말린 축 (양쪽 끝이 살짝 튀어나온 원통)
		for ry in [0.0, h - 10.0]:
			deco.draw_rect(Rect2(2, ry + 2, w - 4, 6), roll)
			deco.draw_rect(Rect2(2, ry + 2, w - 4, 2), Color(0.9, 0.8, 0.6))  # 하이라이트
			deco.draw_rect(Rect2(2, ry + 6, w - 4, 2), roll_dk)               # 그림자
			deco.draw_rect(Rect2(2, ry + 2, w - 4, 6), edge, false, 1.0)
			# 말린 끝 (좌우 마감 캡)
			deco.draw_rect(Rect2(0, ry + 1, 4, 8), roll_dk)
			deco.draw_rect(Rect2(0, ry + 1, 4, 8), edge, false, 1.0)
			deco.draw_rect(Rect2(w - 4, ry + 1, 4, 8), roll_dk)
			deco.draw_rect(Rect2(w - 4, ry + 1, 4, 8), edge, false, 1.0))
	panel.add_child(deco)


# ---- 퀘스트 완료/보상 토스트 ----

var _toast_queue: Array = []
var _toast: Panel = null
var _toast_t := 0.0

# 처음 하는 유저도 충분히 읽을 수 있는 표시 시간
const TOAST_TIME := 4.5


func quest_toast(title: String) -> void:
	_toast_queue.append({"head": "✔ 퀘스트 완료!", "body": title, "icon": null,
		"head_col": Color(0.35, 0.72, 0.3)})
	Sound.play_sfx("sfx_catch")


# 퀘스트가 아닌 사건 알림 — 완공·해금·발견처럼 축하할 일.
# 「퀘스트 완료!」 머리말을 아무 데나 붙이던 버릇을 여기로 분리했다.
func event_toast(title: String) -> void:
	_toast_queue.append({"head": "✨ 알림", "body": title, "icon": null,
		"head_col": Color(0.55, 0.45, 0.72)})
	Sound.play_sfx("sfx_catch")


# 퀘스트 시작 — 딱딱한 검은 알림 대신, 통통 튀며 내려오는 말풍선으로
func quest_start_toast(title: String) -> void:
	_toast_queue.append({"head": "📜 새로운 퀘스트!", "body": title, "icon": null,
		"head_col": Color(0.85, 0.5, 0.12), "bounce": true})
	Sound.play_sfx("sfx_ui")


# ---- 메인 스토리 완결 연출 (전체 화면) ----
#
# 상단 구석에 스치던 작은 토스트 대신, 화면을 잠깐 어둡게 하고
# 한가운데에 큼직하게 「메인 스토리 N 완결」을 띄운다. 클릭하면 닫힌다.
var _sb_layer: CanvasLayer = null
var _sb_dim: ColorRect
var _sb_box: Control
var _sb_head: Label
var _sb_title: Label
var _sb_sub: Label
var _sb_time := 0.0
var _sb_dur := 4.6


func story_banner(head: String, title: String) -> void:
	if _sb_layer == null:
		_make_story_banner()
	_sb_head.text = "✦  %s  ✦" % head
	_sb_title.text = title
	_sb_time = 0.0
	# 검증 하네스에서는 짧게 스치고 지나간다 (다음 스텝 입력을 막지 않게)
	_sb_dur = 0.8 if OS.get_environment("KYOJIN_SHOT") != "" else 4.6
	_sb_layer.visible = true
	Sound.play_sfx("sfx_catch")


func _make_story_banner() -> void:
	_sb_layer = CanvasLayer.new()
	_sb_layer.layer = 40
	_sb_layer.visible = false
	add_child(_sb_layer)

	_sb_dim = ColorRect.new()
	_sb_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sb_dim.color = Color(0, 0, 0, 0.55)
	_sb_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_sb_dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_sb_time = maxf(_sb_time, _sb_dur - 0.35))
	_sb_layer.add_child(_sb_dim)

	_sb_box = Control.new()
	_sb_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb_box.pivot_offset = Vector2(480, 250)
	_sb_layer.add_child(_sb_box)

	# 위아래 가는 금줄 — 두루마리를 펼친 듯한 띠
	for y in [196.0, 316.0]:
		var rule := ColorRect.new()
		rule.position = Vector2(270, y)
		rule.size = Vector2(420, 2)
		rule.color = Color(1.0, 0.84, 0.37, 0.8)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sb_box.add_child(rule)

	_sb_head = Label.new()
	_sb_head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sb_head.offset_top = 210
	_sb_head.offset_bottom = 240
	_sb_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sb_head.add_theme_font_override("font", FONT_SMALL)
	_sb_head.add_theme_font_size_override("font_size", 20)
	_sb_head.add_theme_color_override("font_color", Color(1.0, 0.84, 0.37))
	_sb_head.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	_sb_head.add_theme_constant_override("outline_size", 5)
	_sb_box.add_child(_sb_head)

	_sb_title = Label.new()
	_sb_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sb_title.offset_top = 244
	_sb_title.offset_bottom = 296
	_sb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sb_title.add_theme_font_override("font", FONT_SMALL)
	_sb_title.add_theme_font_size_override("font_size", 34)
	_sb_title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_sb_title.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	_sb_title.add_theme_constant_override("outline_size", 6)
	_sb_box.add_child(_sb_title)

	_sb_sub = Label.new()
	_sb_sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sb_sub.offset_top = 330
	_sb_sub.offset_bottom = 350
	_sb_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sb_sub.text = "이야기는 계속된다  ...클릭"
	_sb_sub.add_theme_font_override("font", FONT_SMALL)
	_sb_sub.add_theme_font_size_override("font_size", 12)
	_sb_sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 0.85))
	_sb_sub.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	_sb_sub.add_theme_constant_override("outline_size", 3)
	_sb_box.add_child(_sb_sub)


func _update_story_banner(delta: float) -> void:
	if _sb_layer == null or not _sb_layer.visible:
		return
	_sb_time += delta
	var a := clampf(_sb_time / 0.35, 0.0, 1.0)               # 스르륵 나타나고
	if _sb_time > _sb_dur - 0.5:
		a = minf(a, clampf((_sb_dur - _sb_time) / 0.5, 0.0, 1.0))  # 스르륵 사라진다
	_sb_dim.color.a = 0.55 * a
	_sb_box.modulate.a = a
	var pop := 1.0 + 0.06 * (1.0 - minf(_sb_time / 0.35, 1.0))    # 살짝 커졌다 앉는다
	_sb_box.scale = Vector2(pop, pop)
	if _sb_time >= _sb_dur:
		_sb_layer.visible = false


func reward_toast(item_name: String, icon: Texture2D) -> void:
	_toast_queue.append({"head": "보상 획득!", "body": item_name, "icon": icon,
		"head_col": Color(0.85, 0.6, 0.15)})
	Sound.play_sfx("sfx_catch")


var _toast_bounce := false


func _show_next_toast() -> void:
	var d: Dictionary = _toast_queue.pop_front()
	_toast = Panel.new()
	# 둥근 크림색 말풍선 — 딱딱한 나무판 대신 아기자기하게
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.99, 0.95, 0.83, 0.98)
	st.border_color = Color(0.62, 0.4, 0.18)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.shadow_color = Color(0.15, 0.09, 0.03, 0.25)
	st.shadow_size = 4
	st.shadow_offset = Vector2(0, 3)
	_toast.add_theme_stylebox_override("panel", st)
	var has_icon: bool = d.icon != null
	var tw := 250
	_toast.position = Vector2((960 - tw) / 2.0, -54)
	_toast.size = Vector2(tw, 46)
	_toast.pivot_offset = Vector2(tw / 2.0, 23.0)
	_toast_bounce = bool(d.get("bounce", false))
	var head := Label.new()
	head.text = str(d.head)
	head.position = Vector2(44 if has_icon else 14, 5)
	head.size = Vector2(tw - 52, 16)
	head.add_theme_font_override("font", FONT_SMALL)
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", d.head_col)
	_toast.add_child(head)
	var body := Label.new()
	body.text = str(d.body)
	body.position = Vector2(44 if has_icon else 14, 22)
	body.size = Vector2(tw - 52, 18)
	body.add_theme_font_override("font", FONT_SMALL)
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", WOOD_TEXT)
	_toast.add_child(body)
	if has_icon:
		var ic := TextureRect.new()
		ic.texture = d.icon
		ic.position = Vector2(10, 9)
		ic.size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		_toast.add_child(ic)
	add_child(_toast)
	_toast_t = 0.0


func _update_toast(delta: float) -> void:
	if _toast == null:
		if not _toast_queue.is_empty():
			_show_next_toast()
		return
	_toast_t += delta
	# 톡 떨어져서 한 번 튕기고 자리 잡는다 -> 유지 -> 페이드 아웃
	var slide := clampf(_toast_t / 0.25, 0.0, 1.0)
	var y := -54.0 + (58.0 + 54.0) * (1.0 - (1.0 - slide) * (1.0 - slide))
	if _toast_t > 0.25 and _toast_t < 0.85:
		# 감쇠하는 바운스 — 말풍선이 통통 튀는 느낌
		var bt := _toast_t - 0.25
		y += -absf(sin(bt * 10.5)) * 9.0 * maxf(0.0, 1.0 - bt / 0.6)
	_toast.position.y = y
	# 시작 알림(bounce)은 살짝 커졌다 앉으며 갸웃갸웃한다
	if _toast_bounce and _toast_t < 1.0:
		var pop := 1.0 + 0.14 * maxf(0.0, 1.0 - _toast_t / 0.3) \
			* sin(_toast_t * 16.0 + 1.2)
		_toast.scale = Vector2(pop, pop)
		_toast.rotation_degrees = sin(_toast_t * 9.0) * 2.2 \
			* maxf(0.0, 1.0 - _toast_t / 1.0)
	else:
		_toast.scale = Vector2.ONE
		_toast.rotation_degrees = 0.0
	var fade := clampf((TOAST_TIME - _toast_t) / 0.4, 0.0, 1.0)
	_toast.modulate.a = fade
	if _toast_t >= TOAST_TIME:
		_toast.queue_free()
		_toast = null


# ---- 하단 핫바 ----

func _build_hotbar() -> void:
	_slot_normal = StyleBoxFlat.new()
	_slot_normal.bg_color = Color(0.96, 0.82, 0.55)
	_slot_normal.border_color = Color(0.43, 0.24, 0.11)
	_slot_normal.set_border_width_all(1)
	_slot_normal.set_corner_radius_all(3)
	_slot_selected = _slot_normal.duplicate()
	_slot_selected.bg_color = Color(1.0, 0.9, 0.62)
	_slot_selected.border_color = Color(0.85, 0.25, 0.2)
	_slot_selected.set_border_width_all(2)

	var slot_count: int = GameData.tool_slots.size()
	var slot_w := 32
	var sep := 2
	var pad := 6
	var width := slot_count * slot_w + (slot_count - 1) * sep + pad * 2
	hotbar_panel = Panel.new()
	hotbar_panel.add_theme_stylebox_override("panel", _wood_style())
	hotbar_panel.position = Vector2((960 - width) / 2.0, 490.0)
	hotbar_panel.size = Vector2(width, 44)
	add_child(hotbar_panel)

	for i in slot_count:
		var b := Button.new()
		b.custom_minimum_size = Vector2(slot_w, 32)
		b.position = Vector2(pad + i * (slot_w + sep), 6)
		b.focus_mode = Control.FOCUS_NONE
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true  # 텍스처 해상도와 무관하게 버튼 크기에 맞춤
		var slot_i := i
		b.pressed.connect(func() -> void:
			var t: String = GameData.tool_slots[slot_i]
			if t != "" and GameData.is_tool_unlocked(t):
				main.toolwork.set_tool(t))
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed \
					and ev.button_index == MOUSE_BUTTON_RIGHT \
					and GameData.tool_slots[slot_i] != "":
				GameData.tool_slots[slot_i] = ""
				Sound.play_sfx("sfx_ui")
				_refresh_hotbar())
		b.set_drag_forwarding(
			func(_pos: Vector2) -> Variant:
				var t: String = GameData.tool_slots[slot_i]
				if t == "" or not GameData.is_tool_unlocked(t):
					return null
				var pv := TextureRect.new()
				pv.texture = tool_icon(t)
				pv.custom_minimum_size = Vector2(30, 30)
				pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pv.stretch_mode = TextureRect.STRETCH_SCALE
				b.set_drag_preview(pv)
				return {"kind": "tool_slot", "from": slot_i},
			func(_pos: Vector2, data: Variant) -> bool:
				return typeof(data) == TYPE_DICTIONARY \
					and data.get("kind") in ["tool_slot", "tool_pick"],
			func(_pos: Vector2, data: Variant) -> void:
				if data.get("kind") == "tool_pick":
					var t2: String = str(data.tool)
					for i2 in GameData.tool_slots.size():
						if i2 != slot_i and GameData.tool_slots[i2] == t2:
							GameData.tool_slots[i2] = ""
					GameData.tool_slots[slot_i] = t2
					Sound.play_sfx("sfx_place")
					_refresh_hotbar()
					return
				var from_i := int(data.from)
				if from_i != slot_i:
					var tmp: String = GameData.tool_slots[from_i]
					GameData.tool_slots[from_i] = GameData.tool_slots[slot_i]
					GameData.tool_slots[slot_i] = tmp
					Sound.play_sfx("sfx_place")
					_refresh_hotbar())
		hotbar_panel.add_child(b)
		slot_buttons.append(b)


# 핫바는 **바뀌었을 때만** 다시 그린다.
# 매 프레임 12칸에 스타일박스를 새로 씌우면 그때마다 Control이 다시 배치된다 —
# 이것만으로 프레임당 0.7ms를 먹고 있었다.
var _hotbar_sig := ""

func _refresh_hotbar() -> void:
	var sig := GameData.tool + "|" + "|".join(GameData.tool_slots)
	for t2: String in GameData.tool_slots:
		sig += "1" if (t2 != "" and GameData.is_tool_unlocked(t2)) else "0"
	if sig == _hotbar_sig:
		return
	_hotbar_sig = sig
	for i in slot_buttons.size():
		var b: Button = slot_buttons[i]
		var t: String = GameData.tool_slots[i] if i < GameData.tool_slots.size() else ""
		var unlocked: bool = t != "" and GameData.is_tool_unlocked(t)
		b.icon = tool_icon(t) if unlocked else null
		b.add_theme_stylebox_override("normal",
			_slot_selected if (t != "" and GameData.tool == t) else _slot_normal)
		b.add_theme_stylebox_override("hover", _slot_selected)
		b.add_theme_stylebox_override("pressed", _slot_selected)


# 같은 글을 다시 넣지 않는다. Label.text에 대입하면 글자 배치를 새로 계산하는데,
# 한글은 그 비용이 특히 크다. 매 프레임 여섯 줄을 다시 계산하고 있었다.
func _put(l: Label, s2: String) -> void:
	if l.text != s2:
		l.text = s2


# HUD는 **초당 열 번**만 다시 짠다.
# 글자를 바꾸지 않아도 「무슨 글을 넣을지」 만드는 데만 프레임당 0.12ms가 든다
# (목표·의뢰·축제 줄을 매번 새로 이어 붙인다). 시계는 게임 분 단위라
# 0.1초 늦어도 눈에 안 보인다. 체력 막대만 매 프레임 따라간다.
var _refresh_t := 0.0

func refresh(force := false) -> void:
	energy_bar.value = GameData.energy
	_refresh_hunger()
	_refresh_t -= get_process_delta_time()
	if _refresh_t > 0.0 and not force:
		return
	_refresh_t = 0.1

	# 컴팩트 날씨/날짜/시간: "☀ 맑음" / "봄 1일 · 오전 8:30"
	var w: int = main.weather_now()
	_put(day_label, "%s %s" % [GameData.weather_icon(w), GameData.weather_name(w)])
	_put(clock_label, "%s %d일 · %s" % [GameData.season_name(),
		GameData.day_in_season(), GameData.clock_text()])
	_put(money_label, "%dG" % GameData.money)


	# 미니 퀘스트창: 「지금 어떤 퀘스트를, 지금 뭘 하면 되는지」 두 가지만.
	# 설명·재료·진행 상황·보상은 전부 Q 상세 창에서 본다.
	# tracked_quest()가 스토리 단계를 따라가므로 단계가 바뀌면 즉시 갱신된다
	var tq := GameData.tracked_quest()
	var t_title := str(tq.get("title", ""))
	var t_goal := str(tq.get("obj", ""))
	if t_goal == "":
		# 메인 퀘스트가 없을 때만 축제·오늘의 의뢰가 자리를 잇는다
		var fl := GameData.festival_line()
		var qline: String = GameData.quest_line()
		if fl != "":
			t_title = "계절 축제"
			t_goal = fl
		elif qline != "":
			t_title = "오늘의 의뢰"
			t_goal = qline
	# Q창(상세)이 열려 있는 동안에는 미니 트래커·핫바가 그 위로 비치지 않게
	var qopen: bool = main != null and main.quest_ui != null \
		and main.quest_ui.visible
	$TrackerPanel.visible = t_goal != "" and not qopen
	hotbar_panel.visible = not qopen
	if qopen and _bub != null and _bub.visible:
		_bub.visible = false           # 안내 말풍선도 Q창 위로 비치지 않게
	_put(quest_title_label, t_title)
	_put(goal_label, ("📍 " + t_goal) if t_goal != "" else "")
	_watch_goal(str(tq.get("obj", "")))

	_refresh_hotbar()

	if GameData.tool == "seed":
		var id := GameData.current_seed_id()
		if id == "":
			_put(tool_name, "씨앗 없음 - 마을 잡화점에서 사자")
		else:
			_put(tool_name, "%s 씨앗 x%d (%s: 바꾸기)" % [GameData.CROPS[id].name,
				GameData.seeds[id], GameData.key_label("cycle_seed")])
	else:
		var label: String = TOOL_LABELS[GameData.tool]
		var sk: String = TOOL_SKILL.get(GameData.tool, "")
		if sk != "":
			label += "  ·  %s Lv.%d" % [GameData.SKILLS[sk].name, GameData.skill_lv(sk)]
		_put(tool_name, label)


# ---- 안내 말풍선 ----
#
# 화면 아래 검은 띠 대신, **주인공 머리 위에 뜨는 작은 말풍선**이다.
# 글자는 미리 폭에 맞춰 잘라 두고, 풍선을 그 크기에 맞춰 키운다 —
# 그래서 어떤 문장이 와도 풍선 밖으로 삐져나오지 않는다.
const BUB_FONT := 11
const BUB_W := 250.0        # 말풍선 안쪽 글 폭 (넘으면 줄바꿈)
const BUB_LINE := 15.0
const BUB_PAD := Vector2(10.0, 7.0)
var _bub: Panel = null
var _bub_label: Label = null
var _bub_tail: Control = null


func _make_bubble() -> void:
	if _bub != null:
		return
	_bub = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.99, 0.96, 0.86, 0.97)
	st.border_color = Color(0.45, 0.31, 0.16)
	st.set_border_width_all(2)
	st.set_corner_radius_all(9)
	st.shadow_color = Color(0.12, 0.08, 0.03, 0.28)
	st.shadow_size = 3
	st.shadow_offset = Vector2(0, 2)
	_bub.add_theme_stylebox_override("panel", st)
	_bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bub.visible = false
	add_child(_bub)
	# 아래로 뾰족한 꼬리 — 누가 하는 말인지 가리킨다
	_bub_tail = Control.new()
	_bub_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bub_tail.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 9)])
		_bub_tail.draw_colored_polygon(pts, Color(0.99, 0.96, 0.86, 0.97))
		_bub_tail.draw_line(Vector2(-7, 0), Vector2(0, 9), Color(0.45, 0.31, 0.16), 2.0)
		_bub_tail.draw_line(Vector2(7, 0), Vector2(0, 9), Color(0.45, 0.31, 0.16), 2.0))
	_bub.add_child(_bub_tail)
	_bub_label = Label.new()
	_bub_label.add_theme_font_override("font", FONT_SMALL)
	_bub_label.add_theme_font_size_override("font_size", BUB_FONT)
	_bub_label.add_theme_color_override("font_color", Color(0.22, 0.15, 0.07))
	_bub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bub.add_child(_bub_label)


# 폭에 맞춰 미리 줄을 나눈다 (풍선 크기를 정확히 잡기 위해)
func _bub_wrap(text: String) -> Array:
	var lines: Array = []
	var w := 0.0
	for raw in text.split("\n"):
		var line := ""
		for ch in raw:
			var cw := FONT_SMALL.get_string_size(line + ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, BUB_FONT).x
			if line != "" and cw > BUB_W:
				lines.append(line)
				w = maxf(w, FONT_SMALL.get_string_size(line,
					HORIZONTAL_ALIGNMENT_LEFT, -1, BUB_FONT).x)
				line = ch
			else:
				line += ch
		lines.append(line)
		w = maxf(w, FONT_SMALL.get_string_size(line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, BUB_FONT).x)
	return [lines, w]


# 주인공 머리 위로 붙인다. 실내·동굴처럼 바깥 좌표가 없는 곳에서는
# 화면 가운데 아래(핫바 위)에 띄운다 — 어디서든 가려지지 않게 화면 안으로 민다.
func _place_bubble() -> void:
	if _bub == null:
		return
	var anchor := Vector2(480.0, 330.0)
	var outside: bool = main != null and main.player != null \
		and not main.interior.visible and not main.cave.visible \
		and not (main.shop_room != null and main.shop_room.visible)
	if outside:
		anchor = main.get_canvas_transform() * main.player.position
		anchor.y -= 46.0        # 머리 위
	var p := Vector2(anchor.x - _bub.size.x * 0.5, anchor.y - _bub.size.y - 9.0)
	p.x = clampf(p.x, 6.0, 960.0 - _bub.size.x - 6.0)
	p.y = clampf(p.y, 34.0, 540.0 - _bub.size.y - 60.0)
	_bub.position = p
	# 화면 밖으로 밀렸으면 꼬리도 주인공 쪽을 가리키게 옮긴다
	_bub_tail.position = Vector2(
		clampf(anchor.x - p.x, 12.0, _bub.size.x - 12.0), _bub.size.y - 1.0)


# 말풍선을 즉시 걷는다 (창이 열리거나 장면이 바뀔 때)
func hide_bubble() -> void:
	msg_timer = 0.0
	if _bub != null:
		_bub.visible = false


func show_message(text: String, dur := 2.5) -> void:
	if main != null and main.remote_acting:
		return  # 다른 플레이어의 행동 메시지는 표시하지 않는다
	_make_bubble()
	var wrapped: Array = _bub_wrap(text)
	var lines: Array = wrapped[0]
	var w: float = minf(float(wrapped[1]), BUB_W)
	_bub_label.text = "\n".join(lines)
	_bub.size = Vector2(w + BUB_PAD.x * 2.0,
		float(lines.size()) * BUB_LINE + BUB_PAD.y * 2.0)
	_bub_label.position = BUB_PAD
	_bub_label.size = Vector2(w, float(lines.size()) * BUB_LINE)
	_bub_tail.position = Vector2(_bub.size.x * 0.5, _bub.size.y - 1.0)
	_bub_tail.queue_redraw()
	_bub.visible = true
	_place_bubble()
	msg_timer = dur


# ---- 새 목표 알림 ----
# 목표가 바뀌는 순간 알려 준다. 보상/완료 토스트와 같은 자리에 겹쳐
# 뜨지 않도록, 별도 배너 대신 **같은 토스트 대기열**에 태운다 —
# 화면 위에는 언제나 알림이 하나만 보인다.
var _goal_seen := "<init>"


func _watch_goal(goal: String) -> void:
	if goal == _goal_seen:
		return
	var first := _goal_seen == "<init>"
	_goal_seen = goal
	if first or goal == "":
		return   # 게임을 막 켰을 때·목표가 사라질 때는 조용히
	for t in _toast_queue:
		if str(t.get("body", "")) == goal:
			return   # 같은 목표가 이미 대기 중이면 또 쌓지 않는다
	_toast_queue.append({"head": "새로운 목표", "body": goal, "icon": null,
		"head_col": Color(0.78, 0.42, 0.02)})
	Sound.play_sfx("sfx_ui")


func _process(delta: float) -> void:
	_update_toast(delta)
	_update_story_banner(delta)
	# 제작대에서 방금 완성된 것 (game_data는 UI를 못 부른다)
	while not GameData.desk_done_pending.is_empty():
		var made: String = GameData.desk_done_pending.pop_front()
		_toast_queue.append({"head": "🔨 완성!", "body": "%s — 낡은 것과 바꿨다" % made,
			"icon": null, "head_col": Color(0.85, 0.6, 0.15)})
		Sound.play_sfx("sfx_place")
	# 컬렉션이 방금 찼으면 배너로 알린다 (game_data는 UI를 못 부른다)
	while not GameData.collection_pending.is_empty():
		var col: Dictionary = GameData.collection_pending.pop_front()
		# 보상 없는 컬렉션(무기 도감 등)은 완성 배너만
		var body := "묶음을 전부 모았다!"
		if str(col.reward) != "":
			body = "%s 레시피가 열렸다!" % GameData.ITEMS[col.reward].name
		elif str(col.get("perk", "")) == "speed":
			body = "이동 속도가 영구히 조금 빨라졌다!"
		_toast_queue.append({"head": "★ 도감 완성 — %s!" % col.name,
			"body": body,
			"icon": (main.tex.get(col.reward) if str(col.reward) != "" else null) \
				if main != null else null,
			"head_col": Color(0.85, 0.6, 0.15)})
		Sound.play_sfx("sfx_catch")
	# 만렙 증표 「생명의 물」 — 일곱 분야를 끝까지 갈고닦으면 한 병씩
	while GameData.water_pending > 0:
		GameData.water_pending -= 1
		_toast_queue.append({"head": "✨ 생명의 물을 얻었다!",
			"body": "한 분야를 끝까지 갈고닦은 증표다 %d/%d" %
				[int(GameData.items["water_life"]),
				GameData.ENDING_SKILLS.size()],
			"icon": main.tex.get("water_life") if main != null else null,
			"head_col": Color(0.4, 0.65, 0.9)})
		Sound.play_sfx("sfx_catch")
	# 방금 발견한 「할머니의 유품」 — 노트 힌트를 따라 찾아낸 희귀 수집품
	if GameData.relic_pending != "":
		_toast_queue.append({"head": "💍 %s 발견!" % GameData.relic_pending,
			"body": "할머니의 유품이다... 소중히 간직하자 %d/%d" %
				[GameData.relics_owned(), GameData.RELICS.size()],
			"icon": null, "head_col": Color(0.85, 0.55, 0.75)})
		GameData.relic_pending = ""
		Sound.play_sfx("sfx_catch")
	# 재료를 다 발견해서 방금 떠오른 기본 요리 레시피
	while not GameData.recipe_pending.is_empty():
		var rid: String = GameData.recipe_pending.pop_front()
		_toast_queue.append({"head": "요리 레시피가 떠올랐다!",
			"body": "%s — 집 조리대에서 만들 수 있다" % GameData.ITEMS[rid].name,
			"icon": main.tex.get(rid) if main != null else null,
			"head_col": Color(0.85, 0.6, 0.15)})
		Sound.play_sfx("sfx_catch")
	if minimap_panel != null and main != null:
		# 실내(집·동굴·가게 방)에서는 바깥 지도를 띄우지 않는다
		minimap_panel.visible = not (main.interior.visible or main.cave.visible
			or (main.shop_room != null and main.shop_room.visible))
		if minimap_panel.visible:
			minimap.queue_redraw()
	if _bub != null and _bub.visible:
		# 가게 방·집 안·동굴·전체 창이 열리면 말풍선은 갈 곳이 없다 —
		# 그대로 두면 화면 한가운데 붙박이처럼 남는다 (예전 버그)
		if main != null and (main.shop_room.visible or main.interior.visible
				or main.cave.visible or main.ui_open()):
			hide_bubble()
		else:
			_place_bubble()
			msg_timer -= delta
			if msg_timer <= 0.0:
				_bub.visible = false
