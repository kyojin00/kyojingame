# 일별 결산 화면: 아침에 어제의 수확/수입/지출을 보여준다.
extends CanvasLayer

@onready var title_label: Label = $Panel/V/Title
@onready var body_label: Label = $Panel/V/Body


func _ready() -> void:
	$Panel/V/OkBtn.pressed.connect(func() -> void:
		Sound.play_sfx("sfx_ui")
		close())


func open(title_text: String, body_text: String) -> void:
	title_label.text = title_text
	body_label.text = body_text
	visible = true


func close() -> void:
	visible = false
