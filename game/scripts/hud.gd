# HUD (스타듀 스타일): 우측 상단 나무 패널(날짜/시계/돈/체력) + 퀘스트 트래커,
# 하단 중앙 핫바(빠른 사용 슬롯 9칸 — 1~9 숫자키, 가방에서 자유 배치).
extends CanvasLayer

const TOOL_ICONS := {
	"hoe": "icon_hoe", "water": "icon_water", "seed": "icon_seed",
	"axe": "icon_axe", "pickaxe": "icon_pickaxe", "fence": "fence",
	"sprinkler": "sprinkler", "rod": "icon_rod",
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
}
# 도구 -> 관련 숙련도
const TOOL_SKILL := {
	"hoe": "farm", "water": "farm", "seed": "farm",
	"axe": "forest", "pickaxe": "mine", "rod": "fish",
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

func _build_tracker_scroll() -> void:
	var panel: Panel = $TrackerPanel
	var empty := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", empty)
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
				main.set_tool(t))
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


func _refresh_hotbar() -> void:
	for i in slot_buttons.size():
		var b: Button = slot_buttons[i]
		var t: String = GameData.tool_slots[i] if i < GameData.tool_slots.size() else ""
		var unlocked: bool = t != "" and GameData.is_tool_unlocked(t)
		b.icon = tool_icon(t) if unlocked else null
		b.add_theme_stylebox_override("normal",
			_slot_selected if (t != "" and GameData.tool == t) else _slot_normal)
		b.add_theme_stylebox_override("hover", _slot_selected)
		b.add_theme_stylebox_override("pressed", _slot_selected)


func refresh() -> void:
	# 컴팩트 날씨/날짜/시간: "☀ 맑음" / "봄 1일 · 오전 8:30"
	var w: int = main.weather_now()
	day_label.text = "%s %s" % [GameData.weather_icon(w), GameData.weather_name(w)]
	clock_label.text = "%s %d일 · %s" % [GameData.season_name(),
		GameData.day_in_season(), GameData.clock_text()]
	money_label.text = "%dG" % GameData.money
	energy_bar.value = GameData.energy

	# 두루마리 퀘스트 트래커 (최소 문구)
	var track := []
	var story_obj := GameData.story_objective_short()
	var obj := GameData.tutorial_objective_short()
	if story_obj != "":
		track.append("목표: " + story_obj)
	elif obj != "":
		track.append("목표: " + obj)
	else:
		# 기본 안내가 끝나면 할아버지의 부탁이 그 자리를 잇는다
		var gl := GameData.grandpa_line()
		if gl != "":
			track.append(gl)
	# 축제날은 그날 할 일을 맨 위로 올린다
	var fl := GameData.festival_line()
	if fl != "":
		track.push_front("★ " + fl)
	if GameData.u_intro_state == 1:
		track.append("목표: U 키로 능력치를 확인해 보자")
	var q: Dictionary = GameData.quest
	if not q.is_empty() and bool(q.accepted):
		track.append("의뢰: %s %d/%d" % [GameData.CROPS[q.crop].name,
			mini(int(GameData.produce[q.crop]), int(q.qty)), int(q.qty)])
	track.append("%s: 퀘스트 창" % GameData.key_label("open_quest"))
	objective_label.text = "\n".join(track)

	_refresh_hotbar()

	if GameData.tool == "seed":
		var id := GameData.current_seed_id()
		if id == "":
			tool_name.text = "씨앗 없음 - 마을 잡화점에서 사자"
		else:
			tool_name.text = "%s 씨앗 x%d (%s: 바꾸기)" % [GameData.CROPS[id].name,
				GameData.seeds[id], GameData.key_label("cycle_seed")]
	else:
		tool_name.text = TOOL_LABELS[GameData.tool]
		var sk: String = TOOL_SKILL.get(GameData.tool, "")
		if sk != "":
			tool_name.text += "  ·  %s Lv.%d" % [GameData.SKILLS[sk].name,
				GameData.skill_lv(sk)]


func show_message(text: String, dur := 2.5) -> void:
	if main != null and main._remote_acting:
		return  # 다른 플레이어의 행동 메시지는 표시하지 않는다
	msg_label.text = text
	msg_label.visible = true
	$MessageBg.visible = true
	msg_timer = dur


func _process(delta: float) -> void:
	_update_toast(delta)
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
