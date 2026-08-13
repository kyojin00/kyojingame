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
	"axe": "도끼", "pickaxe": "곡괭이", "fence": "울타리 (목재1)",
	"sprinkler": "스프링클러 (목재2·석재2)", "rod": "낚싯대",
	"spear": "돌 창 (느리고 강하게)", "sword": "돌 검 (빠르게 두 번)",
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


# ---- 미니맵 (좌측 상단) ----
#
# M키 지도는 맵 전체를 보여주고, 이쪽은 **내 주변만** 항상 띄워 둔다.
# 90x60을 다 담으면 타일이 2px도 안 돼 알아볼 수 없기 때문이다.
# 안개(가 본 곳만 보이기) 규칙은 M키 지도와 똑같이 map_ui에 맡긴다.
const MM_TX := 31          # 가로로 보이는 타일 수 (플레이어가 한가운데)
const MM_TY := 21
const MM_CELL := 5.0
const MM_FOG := Color(0.05, 0.05, 0.08)

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


func _draw_minimap() -> void:
	var pt: Vector2i = main.player_tile()
	var x0: int = pt.x - MM_TX / 2
	var y0: int = pt.y - MM_TY / 2
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), MM_FOG)

	for ty in MM_TY:
		for tx in MM_TX:
			var x: int = x0 + tx
			var y: int = y0 + ty
			if x < 0 or y < 0 or x >= main.MAP_W or y >= main.MAP_H:
				continue  # 맵 밖은 안개색 그대로
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
	panel.tooltip_text = "클릭: 퀘스트 상세 (%s)" % GameData.key_label("open_quest")
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			Sound.play_sfx("sfx_ui")
			main.quest_ui.toggle())
	# 두루마리 안은 딱 세 줄 — 퀘스트 이름(1줄) / 지금 할 행동(최대 2줄) /
	# 「Q 상세보기」. 설명·재료·진행 상황은 전부 Q 상세 창의 몫이다.
	# 모든 글자는 말줄임(…)과 줄 수 제한으로 두루마리 밖으로 못 나간다.
	panel.offset_bottom = 142.0           # 작고 귀여운 메모 크기 (226x84)
	quest_title_label = Label.new()
	quest_title_label.position = Vector2(16, 10)
	quest_title_label.size = Vector2(192, 15)
	quest_title_label.add_theme_font_size_override("font_size", 12)
	quest_title_label.add_theme_color_override("font_color", Color(0.32, 0.2, 0.08))
	quest_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(quest_title_label)
	goal_label = Label.new()
	goal_label.position = Vector2(16, 27)
	goal_label.size = Vector2(192, 32)
	goal_label.add_theme_font_size_override("font_size", 12)
	goal_label.add_theme_color_override("font_color", Color(0.78, 0.42, 0.02))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.max_lines_visible = 2
	goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(goal_label)
	# 기존 objective_label은 「Q 상세보기」 한 줄짜리 안내로만 쓴다
	objective_label.position = Vector2(16, 60)
	objective_label.size = Vector2(192, 13)
	objective_label.add_theme_font_size_override("font_size", 10)
	objective_label.add_theme_color_override("font_color", Color(0.55, 0.45, 0.3))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func reward_toast(item_name: String, icon: Texture2D) -> void:
	_toast_queue.append({"head": "보상 획득!", "body": item_name, "icon": icon,
		"head_col": Color(0.85, 0.6, 0.15)})
	Sound.play_sfx("sfx_catch")


func _show_next_toast() -> void:
	var d: Dictionary = _toast_queue.pop_front()
	_toast = Panel.new()
	_toast.add_theme_stylebox_override("panel", _wood_style())
	var has_icon: bool = d.icon != null
	var tw := 250
	_toast.position = Vector2((960 - tw) / 2.0, -50)
	_toast.size = Vector2(tw, 44)
	var head := Label.new()
	head.text = str(d.head)
	head.position = Vector2(44 if has_icon else 12, 4)
	head.size = Vector2(tw - 50, 16)
	head.add_theme_font_override("font", FONT_SMALL)
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", d.head_col)
	_toast.add_child(head)
	var body := Label.new()
	body.text = str(d.body)
	body.position = Vector2(44 if has_icon else 12, 21)
	body.size = Vector2(tw - 50, 18)
	body.add_theme_font_override("font", FONT_SMALL)
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", WOOD_TEXT)
	_toast.add_child(body)
	if has_icon:
		var ic := TextureRect.new()
		ic.texture = d.icon
		ic.position = Vector2(8, 8)
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
	# 슬라이드 인 (0~0.25초) -> 유지 -> 페이드 아웃 (마지막 0.4초)
	var slide := clampf(_toast_t / 0.25, 0.0, 1.0)
	_toast.position.y = -50.0 + (58.0 + 50.0) * (1.0 - (1.0 - slide) * (1.0 - slide))
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
	$TrackerPanel.visible = t_goal != ""
	_put(quest_title_label, t_title)
	_put(goal_label, ("📍 " + t_goal) if t_goal != "" else "")
	_watch_goal(str(tq.get("obj", "")))
	_put(objective_label, "%s 상세보기" % GameData.key_label("open_quest"))

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


func show_message(text: String, dur := 2.5) -> void:
	if main != null and main._remote_acting:
		return  # 다른 플레이어의 행동 메시지는 표시하지 않는다
	msg_label.text = text
	msg_label.visible = true
	$MessageBg.visible = true
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
		_toast_queue.append({"head": "★ 도감 완성 — %s!" % col.name,
			"body": body,
			"icon": (main.tex.get(col.reward) if str(col.reward) != "" else null) \
				if main != null else null,
			"head_col": Color(0.85, 0.6, 0.15)})
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
	if msg_label.visible:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.visible = false
			$MessageBg.visible = false
