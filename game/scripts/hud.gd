# HUD (스타듀 스타일): 우측 상단 나무 패널(날짜/시계/돈/체력) + 퀘스트 트래커,
# 하단 중앙 핫바(도구 슬롯 12칸 — 마지막 3칸은 원하는 도구를 넣는 빈 칸).
extends CanvasLayer

const TOOL_ICONS := {
	"hoe": "icon_hoe", "water": "icon_water", "seed": "icon_seed", "hand": "icon_basket",
	"axe": "icon_axe", "pickaxe": "icon_pickaxe", "fence": "fence",
	"sprinkler": "sprinkler", "rod": "icon_rod",
}
const TOOL_LABELS := {
	"hoe": "호미", "water": "물뿌리개", "hand": "수확",
	"axe": "도끼", "pickaxe": "곡괭이", "fence": "울타리 (목재1)",
	"sprinkler": "스프링클러 (목재2·석재2)", "rod": "낚싯대",
}
# 나무 프레임 팔레트
const WOOD_TEXT := Color(0.29, 0.16, 0.06)

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
	$TrackerPanel.add_theme_stylebox_override("panel", _wood_style())
	$EnergyPanel.add_theme_stylebox_override("panel", _wood_style())
	_build_hotbar()


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
				pv.texture = main.tex[TOOL_ICONS[t]]
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
		b.icon = main.tex[TOOL_ICONS[t]] if unlocked else null
		b.add_theme_stylebox_override("normal",
			_slot_selected if (t != "" and GameData.tool == t) else _slot_normal)
		b.add_theme_stylebox_override("hover", _slot_selected)
		b.add_theme_stylebox_override("pressed", _slot_selected)


func refresh() -> void:
	day_label.text = "%s %d일 %s" % [GameData.season_name(), GameData.day_in_season(),
		GameData.weather_icon(main.weather_now())]
	clock_label.text = GameData.clock_text()
	money_label.text = "%dG" % GameData.money
	energy_bar.value = GameData.energy

	# 우측 퀘스트 트래커 (짧은 문구)
	var track := []
	var obj := GameData.tutorial_objective_short()
	if obj != "":
		track.append("목표: " + obj)
	var q: Dictionary = GameData.quest
	if not q.is_empty() and bool(q.accepted):
		track.append("의뢰: %s %d/%d" % [GameData.CROPS[q.crop].name,
			mini(int(GameData.produce[q.crop]), int(q.qty)), int(q.qty)])
	var prog: Dictionary = GameData.note_progress()
	track.append("노트 %d%% (N)" % int(prog.ratio * 100.0))
	track.append("J: 퀘스트 창")
	objective_label.text = "\n".join(track)

	_refresh_hotbar()

	if GameData.tool == "seed":
		var id := GameData.current_seed_id()
		if id == "":
			tool_name.text = "씨앗 없음 - 상점(%s)에서 사자" % GameData.key_label("open_shop")
		else:
			tool_name.text = "%s 씨앗 x%d (%s: 바꾸기)" % [GameData.CROPS[id].name,
				GameData.seeds[id], GameData.key_label("cycle_seed")]
	else:
		tool_name.text = TOOL_LABELS[GameData.tool]


func show_message(text: String) -> void:
	if main != null and main._remote_acting:
		return  # 다른 플레이어의 행동 메시지는 표시하지 않는다
	msg_label.text = text
	msg_label.visible = true
	$MessageBg.visible = true
	msg_timer = 2.5


func _process(delta: float) -> void:
	if msg_label.visible:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.visible = false
			$MessageBg.visible = false
