# HUD: 상단 정보 바 + 하단 도구 바 + 메시지 토스트
extends CanvasLayer

const TOOL_NAMES := {"hoe": "1 호미", "water": "2 물뿌리개", "hand": "4 수확"}

var main: Node2D
var msg_timer := 0.0

@onready var day_label: Label = $Top/DayLabel
@onready var clock_label: Label = $Top/ClockLabel
@onready var money_label: Label = $Top/MoneyLabel
@onready var energy_bar: ProgressBar = $Top/EnergyBar
@onready var msg_label: Label = $Message
@onready var tool_labels := {
	"hoe": $Bottom/ToolHoe,
	"water": $Bottom/ToolWater,
	"seed": $Bottom/ToolSeed,
	"hand": $Bottom/ToolHand,
}


func refresh() -> void:
	day_label.text = "%s %d일 %s" % [GameData.season_name(), GameData.day_in_season(),
		GameData.weather_icon(main.weather_now())]
	clock_label.text = GameData.clock_text()
	money_label.text = "%dG" % GameData.money
	energy_bar.value = GameData.energy

	for key in tool_labels:
		var l: Label = tool_labels[key]
		if key == "seed":
			var id := GameData.current_seed_id()
			if id == "":
				l.text = "3 씨앗 없음"
			else:
				l.text = "3 %s씨앗 x%d" % [GameData.CROPS[id].name, GameData.seeds[id]]
		else:
			l.text = TOOL_NAMES[key]
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
