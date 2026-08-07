# HUD: 상단 정보 바 + 자원 표시 + 도트 아이콘 핫바 + 메시지 토스트
extends CanvasLayer

# 핫바 순서 (숫자키 1~9와 일치)
const TOOLS := ["hoe", "water", "seed", "hand", "axe", "pickaxe", "fence", "sprinkler", "rod"]
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

var main: Node2D
var msg_timer := 0.0
var wood_label: Label
var stone_label: Label

@onready var day_label: Label = $Top/DayLabel
@onready var clock_label: Label = $Top/ClockLabel
@onready var money_label: Label = $Top/MoneyLabel
@onready var energy_bar: ProgressBar = $Top/EnergyBar
@onready var msg_label: Label = $Message
@onready var objective_label: Label = $Objective
@onready var tool_name: Label = $ToolName
@onready var resources: HBoxContainer = $Resources


func _ready() -> void:
	wood_label = _mk_resource("icon_wood")
	stone_label = _mk_resource("icon_stone")


func _mk_resource(icon: String) -> Label:
	var rect := TextureRect.new()
	rect.texture = main.tex[icon]
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	resources.add_child(rect)
	var l := Label.new()
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.12))
	l.add_theme_constant_override("outline_size", 3)
	resources.add_child(l)
	return l


func refresh() -> void:
	day_label.text = "%s %d일 %s" % [GameData.season_name(), GameData.day_in_season(),
		GameData.weather_icon(main.weather_now())]
	clock_label.text = GameData.clock_text()
	money_label.text = "%dG" % GameData.money
	energy_bar.value = GameData.energy
	wood_label.text = str(GameData.wood)
	stone_label.text = str(GameData.stone)
	objective_label.text = GameData.tutorial_objective()

	if GameData.tool == "seed":
		var id := GameData.current_seed_id()
		if id == "":
			tool_name.text = "씨앗 없음 - 상점(%s)에서 사자" % GameData.key_label("open_shop")
		else:
			tool_name.text = "%s 씨앗 x%d (%s: 바꾸기)" % [GameData.CROPS[id].name,
				GameData.seeds[id], GameData.key_label("cycle_seed")]
	else:
		tool_name.text = "%s · %s: 가방 · %s: 퀘스트" % [TOOL_LABELS[GameData.tool],
			GameData.key_label("open_inventory"), GameData.key_label("open_quest")]


func show_message(text: String) -> void:
	if main != null and main._remote_acting:
		return  # 다른 플레이어의 행동 메시지는 표시하지 않는다
	msg_label.text = text
	msg_label.visible = true
	msg_timer = 2.5


func _process(delta: float) -> void:
	if msg_label.visible:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.visible = false
