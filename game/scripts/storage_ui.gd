# 수납 상자 창 — 집 안에 놓은 상자 곁에서 E.
#
# 왼쪽이 가방, 오른쪽이 상자다. 줄을 누르면 하나씩 옮기고, 「전부」를
# 누르면 그 칸을 통째로 옮긴다. 상자를 여러 개 놓아도 안은 하나로
# 이어져 있다 (GameData.storage_stock) — 어느 상자를 열든 같은 살림이다.
#
# 넣고 빼는 규칙 자체는 GameData.storage_put/take가 쥐고 있다.
# 여기는 그것을 보여 주고 눌러 주는 창일 뿐이다.
extends CanvasLayer

var main: Node2D
var _bag: VBoxContainer
var _box: VBoxContainer
var _title: Label


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(190, 90)
	panel.custom_minimum_size = Vector2(580, 350)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.18, 0.12, 0.98)
	style.border_color = Color(0.62, 0.48, 0.28)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
	v.add_child(_title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	v.add_child(cols)
	_bag = _make_column(cols, "가방")
	_box = _make_column(cols, "상자")


func _make_column(parent: HBoxContainer, head: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 3)
	parent.add_child(wrap)
	var l := Label.new()
	l.text = head
	l.add_theme_color_override("font_color", Color(0.8, 0.72, 0.55))
	wrap.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(272, 280)
	wrap.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	return box


func open() -> void:
	visible = true
	_rebuild()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	_title.text = "- 수납 상자 (%d/%d칸 · E/ESC: 닫기) -" % [
		GameData.storage_used(), GameData.STORAGE_SLOTS]
	for c in _bag.get_children():
		c.queue_free()
	for c in _box.get_children():
		c.queue_free()

	# 가방 -> 상자
	var bag_any := false
	for id: String in GameData.ITEM_IDS:
		if not GameData.storage_can_store(id):
			continue
		bag_any = true
		_row(_bag, id, int(GameData.items[id]), true)
	if not bag_any:
		_note(_bag, "넣을 것이 없다.")

	# 상자 -> 가방
	if GameData.storage_stock.is_empty():
		_note(_box, "상자가 비어 있다.")
		return
	for id: String in GameData.storage_stock:
		_row(_box, id, int(GameData.storage_stock[id]), false)


func _note(parent: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.62, 0.56, 0.46))
	parent.add_child(l)


# 한 줄: [이름 x개] [1] [전부]
func _row(parent: VBoxContainer, id: String, n: int, to_box: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var l := Label.new()
	l.text = "%s x%d" % [GameData.ITEMS[id].name, n]
	l.custom_minimum_size = Vector2(170, 0)
	l.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	row.add_child(l)
	for pair: Array in [["1", 1], ["전부", n]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(44, 22)
		b.pressed.connect(_move.bind(id, int(pair[1]), to_box))
		row.add_child(b)


func _move(id: String, n: int, to_box: bool) -> void:
	var moved := GameData.storage_put(id, n) if to_box else GameData.storage_take(id, n)
	if moved <= 0:
		if to_box and GameData.storage_full():
			main.hud.show_message("상자가 꽉 찼다 — 다른 것을 먼저 꺼내자.")
		return
	Sound.play_sfx("sfx_place", 0.1)
	main.saveio.save_now()
	_rebuild()
