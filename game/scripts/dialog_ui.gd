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

var _seq: Array = []
var _seq_idx := -1
var _seq_name := ""
var _seq_portrait: Texture2D = null
var _seq_on_end := Callable()
var _seq_has_choices := false


func _ready() -> void:
	layer = 25
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(158, 285)
	panel.custom_minimum_size = Vector2(645, 210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.22, 0.96)
	style.border_color = Color(0.42, 0.36, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.visible = false
	h.add_child(portrait)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)

	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color("ffd75e"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 초상화(64px)+여백을 빼고 화면 안에 들어오는 고정 폭
	body_label.custom_minimum_size = Vector2(465, 90)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body_label)

	buttons_box = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 8)
	buttons_box.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(buttons_box)


# buttons: [[라벨, Callable], ...] — 콜백이 null이면 닫기 동작
func open(title_text: String, body_text: String, buttons: Array,
		portrait_tex: Texture2D = null) -> void:
	title_label.text = title_text
	body_label.text = body_text
	portrait.texture = portrait_tex
	portrait.visible = portrait_tex != null
	for c in buttons_box.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		if b[1] != null:
			btn.pressed.connect(b[1])
		else:
			btn.pressed.connect(close)
		buttons_box.add_child(btn)
	visible = true


func set_body(text: String) -> void:
	body_label.text = text


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
