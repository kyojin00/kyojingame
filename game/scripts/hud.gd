# HUD: 상단 정보 바 + 하단 도구 바 + 메시지 토스트
extends CanvasLayer

const TOOLS := [["hoe", "1 호미"], ["water", "2 물뿌리개"], ["seed", "3 씨앗"], ["hand", "4 수확"]]

var main: Node2D
var day_label: Label
var clock_label: Label
var money_label: Label
var energy_bar: ProgressBar
var tool_labels := {}
var msg_label: Label
var msg_timer := 0.0


func _ready() -> void:
	layer = 10

	var top := HBoxContainer.new()
	top.position = Vector2(4, 2)
	top.add_theme_constant_override("separation", 10)
	add_child(top)

	day_label = _mk_label(top)
	clock_label = _mk_label(top)
	money_label = _mk_label(top)
	money_label.add_theme_color_override("font_color", Color("ffd75e"))

	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(60, 12)
	energy_bar.show_percentage = false
	energy_bar.max_value = GameData.ENERGY_MAX
	energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.07, 0.12, 0.85)
	bg.border_color = Color(0.29, 0.25, 0.39)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.48, 0.83, 0.35)
	energy_bar.add_theme_stylebox_override("background", bg)
	energy_bar.add_theme_stylebox_override("fill", fill)
	top.add_child(energy_bar)

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(4, 320 - 20)
	bottom.add_theme_constant_override("separation", 12)
	add_child(bottom)
	for t in TOOLS:
		tool_labels[t[0]] = _mk_label(bottom)

	msg_label = Label.new()
	msg_label.position = Vector2(0, 26)
	msg_label.size = Vector2(480, 20)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.visible = false
	_style_label(msg_label)
	add_child(msg_label)


func _mk_label(parent: Control) -> Label:
	var l := Label.new()
	_style_label(l)
	parent.add_child(l)
	return l


func _style_label(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.12))
	l.add_theme_constant_override("outline_size", 3)


func refresh() -> void:
	day_label.text = "%d일차(봄)" % GameData.day
	clock_label.text = GameData.clock_text()
	money_label.text = "%dG" % GameData.money
	energy_bar.value = GameData.energy

	for key in tool_labels:
		var l: Label = tool_labels[key]
		if key == "seed":
			var id := GameData.current_seed_id()
			l.text = "3 %s씨앗 x%d" % [GameData.CROPS[id].name, GameData.seeds[id]]
		else:
			for t in TOOLS:
				if t[0] == key:
					l.text = t[1]
		var selected: bool = GameData.tool == key
		l.add_theme_color_override("font_color",
			Color("ffd75e") if selected else Color(0.85, 0.83, 0.92))


func show_message(text: String) -> void:
	msg_label.text = text
	msg_label.visible = true
	msg_timer = 2.5


func _process(delta: float) -> void:
	if msg_label.visible:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.visible = false
