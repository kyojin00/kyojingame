# 범용 대화/퀘스트 패널: 제목 + 본문 + 동적 버튼들
#
# ---- 공통 NPC 대화 시퀀스 시스템 ----
# 모든 NPC(주민/상점/우체부/스토리 이벤트)가 같은 시스템을 쓴다.
# NPC마다 데이터만 바꾼다: 화자 이름, 초상화, 대사 배열, 선택지, 이벤트.
#
#   dialog.open_seq("우체부 아저씨", portrait_tex, [
#       {"text": "아이고, 드디어 왔구먼."},
#       {"text": "이 도끼를 받아라.", "event": func(): main.give_axe()},
#       {"text": "잘 지내보게!", "choices": [["고마워요!", null]]},
#   ], func(): main.start_quest("chop_tree"))
#
# 엔트리 키: text(필수) / name·portrait(그 대사만 화자 교체) /
#            event(대사 도달 시 실행 — 스킵해도 반드시 실행됨) /
#            choices([[라벨, Callable|null], ...] — 마지막 대사 선택지)
# 스킵: ESC 또는 InputMap의 "dialog_skip" 액션(컨트롤러/모바일 확장용).
#       텍스트·연출만 건너뛰고 event/on_end는 전부 실행된다.
# 진행: 다음 버튼 클릭 또는 E/Space.
extends CanvasLayer

var title_label: Label
var body_label: Label
var buttons_box: HBoxContainer
var portrait: TextureRect
var skip_btn: Button

var _seq: Array = []
var _seq_idx := -1
var _seq_name := ""
var _seq_portrait: Texture2D = null
var _seq_on_end := Callable()
var _seq_has_choices := false


# 대화창은 화면 아래 가운데에 고정하고, 내용 높이만큼만 커진다.
# (예전에는 645x210으로 고정이라 짧은 대사에서도 빈 공간이 크게 남았다)
const PANEL_W := 520
const BOTTOM_MARGIN := 56          # 아래 핫바를 가리지 않는 높이
const FONT_TITLE := 17
const FONT_BODY := 17
const FONT_BTN := 15
const FONT_SKIP := 13
const SKIP_W := 76
const PORTRAIT := 64


func _ready() -> void:
	layer = 25
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	# 가로 가운데 정렬 + 아래쪽 고정. 내용이 길어지면 위로 자란다.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -PANEL_W / 2.0
	panel.offset_right = PANEL_W / 2.0
	panel.offset_top = -BOTTOM_MARGIN
	panel.offset_bottom = -BOTTOM_MARGIN
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	panel.add_child(h)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.visible = false
	h.add_child(portrait)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)

	# 제목 줄: 가운데 화자 이름 + 오른쪽 끝 건너뛰기 버튼.
	# 버튼이 이름을 밀어내지 않도록 왼쪽에 같은 폭의 빈 칸을 둔다.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)

	var lpad := Control.new()
	lpad.custom_minimum_size = Vector2(SKIP_W, 0)
	top.add_child(lpad)

	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color("ffd75e"))
	title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)

	# 대사가 여러 줄 남았을 때만 보인다 (ESC와 같은 동작)
	skip_btn = Button.new()
	skip_btn.text = "건너뛰기 >>"
	skip_btn.tooltip_text = "이 대화를 건너뛴다 (ESC)"
	skip_btn.add_theme_font_size_override("font_size", FONT_SKIP)
	skip_btn.add_theme_color_override("font_color", Color(0.72, 0.68, 0.82))
	skip_btn.custom_minimum_size = Vector2(SKIP_W, 0)
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_btn.visible = false
	skip_btn.pressed.connect(skip_seq)
	top.add_child(skip_btn)

	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", FONT_BODY)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 글자는 상자 한가운데에 놓는다 (가로·세로 모두)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.custom_minimum_size = Vector2(0, 44)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body_label)

	buttons_box = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 8)
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons_box)


# buttons: [[라벨, Callable], ...] — 콜백이 null이면 닫기 동작
func open(title_text: String, body_text: String, buttons: Array,
		portrait_tex: Texture2D = null) -> void:
	title_label.text = title_text
	body_label.text = body_text
	# 일반 안내창에는 건너뛸 대사가 없다 — 시퀀스가 다시 켜 준다
	skip_btn.visible = false
	portrait.texture = portrait_tex
	portrait.visible = portrait_tex != null
	for c in buttons_box.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", FONT_BTN)
		btn.focus_mode = Control.FOCUS_NONE
		if b[1] != null:
			btn.pressed.connect(b[1])
		else:
			btn.pressed.connect(close)
		buttons_box.add_child(btn)
	visible = true


func set_body(text: String) -> void:
	body_label.text = text


# 본문은 그대로 두고 버튼만 갈아 끼운다
# (건설·제작이 끝난 뒤 「짓기」 버튼을 치워 두 번 눌리지 않게 한다)
func set_buttons(buttons: Array) -> void:
	for c in buttons_box.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", FONT_BTN)
		btn.focus_mode = Control.FOCUS_NONE
		if b[1] != null:
			btn.pressed.connect(b[1])
		else:
			btn.pressed.connect(close)
		buttons_box.add_child(btn)


func set_portrait(tex: Texture2D) -> void:
	portrait.texture = tex
	portrait.visible = tex != null


func close() -> void:
	visible = false
	_seq = []
	_seq_idx = -1
	_seq_on_end = Callable()


# ---- 시퀀스 대화 ----

func open_seq(speaker: String, portrait_tex: Texture2D, entries: Array,
		on_end := Callable()) -> void:
	_seq = entries
	_seq_idx = -1
	_seq_name = speaker
	_seq_portrait = portrait_tex
	_seq_on_end = on_end
	_advance_seq()


func in_seq() -> bool:
	return visible and _seq_idx >= 0


func _advance_seq() -> void:
	_seq_idx += 1
	if _seq_idx >= _seq.size():
		_end_seq()
		return
	var e: Dictionary = _seq[_seq_idx]
	# 이 대사에 걸린 게임 이벤트 (아이템 지급/퀘스트 시작 등)는 도달 즉시 실행
	if e.get("event") is Callable:
		(e.event as Callable).call()
	var btns: Array
	_seq_has_choices = e.has("choices")
	if _seq_has_choices:
		btns = e.choices
	elif _seq_idx < _seq.size() - 1:
		btns = [["다음 >", _advance_seq]]
	else:
		btns = [["대화 끝", _end_seq]]
	open(str(e.get("name", _seq_name)), str(e.text), btns,
		e.get("portrait", _seq_portrait))
	skip_btn.visible = _can_skip()


# 건너뛰기는 "남은 대사를 접는" 기능이다. 그래서
#  - 마지막 대사(더 접을 게 없다)에는 보이지 않고
#  - 남은 대사에 선택지가 있으면 그 선택을 건너뛸 수 없으므로 숨긴다
func _can_skip() -> bool:
	if _seq_idx < 0 or _seq_idx >= _seq.size() - 1:
		return false
	for i in range(_seq_idx + 1, _seq.size()):
		var e: Dictionary = _seq[i]
		if e.has("choices"):
			return false
	return true


func skip_seq() -> void:
	# 스킵 = 남은 텍스트/연출만 건너뛴다. 남은 대사의 이벤트는 순서대로 즉시 실행.
	if _seq_idx < 0:
		close()
		return
	for i in range(_seq_idx + 1, _seq.size()):
		var e: Dictionary = _seq[i]
		if e.get("event") is Callable:
			(e.event as Callable).call()
	_end_seq()


func _end_seq() -> void:
	var cb := _seq_on_end
	close()
	if cb.is_valid():
		cb.call()


func _is_skip_pressed(event: InputEvent) -> bool:
	# 확장 가능: 프로젝트 InputMap에 "dialog_skip" 액션을 추가하면
	# 컨트롤러/모바일 버튼도 스킵 키로 쓸 수 있다.
	if InputMap.has_action("dialog_skip") and event.is_action_pressed("dialog_skip"):
		return true
	return event.is_action_pressed("ui_cancel")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _seq_idx < 0:
		return
	if _is_skip_pressed(event):
		skip_seq()
		get_viewport().set_input_as_handled()
	elif not _seq_has_choices \
			and (event.is_action_pressed("interact") or event.is_action_pressed("use_tool")):
		_advance_seq()
		get_viewport().set_input_as_handled()
