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

var _deco: Control = null          # 스티치·나뭇잎·진행 화살표를 그리는 겹
var _name_plate: PanelContainer = null
var _deco_t := 0.0

var _seq: Array = []
var _seq_idx := -1
var _seq_name := ""
var _seq_portrait: Texture2D = null
var _seq_on_end := Callable()
var _seq_has_choices := false


# 대화창은 화면 아래 가운데에 고정하고, 내용 높이만큼만 커진다.
# (예전에는 645x210으로 고정이라 짧은 대사에서도 빈 공간이 크게 남았다)
#
# 따뜻한 우드톤 팔레트 — 밝은 크림 속지 + 진한 브라운 테두리 +
# 나무 명패식 이름 탭. 퀘스트 추적창도 같은 톤을 쓴다.
const PANEL_W := 470               # 화면을 덜 가리게 조금 줄였다
const BOTTOM_MARGIN := 56          # 아래 핫바를 가리지 않는 높이
const FONT_TITLE := 16
const FONT_BODY := 14
const FONT_BTN := 15
const FONT_SKIP := 13
const SKIP_W := 76
const PORTRAIT := 58
const COL_CREAM := Color(0.97, 0.93, 0.83, 0.97)   # 속지 (밝은 크림)
const COL_WOOD := Color(0.62, 0.44, 0.26)          # 명패·장식 (우드 브라운)
const COL_WOOD_DK := Color(0.45, 0.3, 0.16)        # 테두리 (진한 브라운)
const COL_INK := Color(0.32, 0.2, 0.1)             # 본문 글자 (잉크 브라운)
const COL_LEAF := Color(0.45, 0.62, 0.32)          # 나뭇잎 장식


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
	style.bg_color = COL_CREAM
	style.border_color = COL_WOOD_DK
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)          # 모서리를 살짝 둥글게
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	# 아기자기한 디테일 — 네 귀퉁이 스티치 점 + 왼쪽 위 나뭇잎 한 장 +
	# 대화가 이어질 때 오른쪽 아래에서 콩콩 뛰는 진행 화살표(▼)
	_deco = Control.new()
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	panel.add_child(_deco)

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

	# 이름은 작은 나무 명패 탭에 얹는다 (왼쪽 정렬)
	_name_plate = PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = COL_WOOD
	pstyle.border_color = COL_WOOD_DK
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 10.0
	pstyle.content_margin_right = 10.0
	pstyle.content_margin_top = 1.0
	pstyle.content_margin_bottom = 1.0
	_name_plate.add_theme_stylebox_override("panel", pstyle)
	_name_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(_name_plate)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color(0.99, 0.95, 0.86))
	title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_name_plate.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	# 대사가 여러 줄 남았을 때만 보인다 (ESC와 같은 동작)
	skip_btn = Button.new()
	skip_btn.text = "건너뛰기 >>"
	skip_btn.tooltip_text = "이 대화를 건너뛴다 (ESC)"
	skip_btn.add_theme_font_size_override("font_size", FONT_SKIP)
	skip_btn.add_theme_color_override("font_color", COL_WOOD)
	skip_btn.custom_minimum_size = Vector2(SKIP_W, 0)
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_btn.visible = false
	skip_btn.pressed.connect(skip_seq)
	top.add_child(skip_btn)

	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", FONT_BODY)
	body_label.add_theme_color_override("font_color", COL_INK)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 글자는 상자 한가운데에 놓는다 (가로·세로 모두).
	# 세로 최소 높이를 줄여 대사에 필요한 만큼만 차지한다
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.custom_minimum_size = Vector2(0, 34)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body_label)

	buttons_box = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 8)
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons_box)


# 선택지 버튼도 같은 우드톤 — 크림 바탕에 진한 브라운 테두리
func _style_btn(btn: Button) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.9, 0.82, 0.66)
	st.border_color = COL_WOOD_DK
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.content_margin_left = 10.0
	st.content_margin_right = 10.0
	st.content_margin_top = 3.0
	st.content_margin_bottom = 3.0
	btn.add_theme_stylebox_override("normal", st)
	var hv: StyleBoxFlat = st.duplicate()
	hv.bg_color = Color(0.96, 0.9, 0.75)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_color_override("font_color", COL_INK)
	btn.add_theme_color_override("font_hover_color", COL_INK)
	btn.add_theme_color_override("font_pressed_color", COL_INK)


func _process(delta: float) -> void:
	if not visible:
		return
	_deco_t += delta
	if _deco != null:
		_deco.queue_redraw()   # 진행 화살표가 콩콩 뛰도록


# 귀퉁이 스티치 점 4개 + 명패 옆 나뭇잎 + 진행 화살표.
# 장식은 글자 영역 밖(테두리 근처)에만 둔다 — 가독성이 먼저다.
func _draw_deco() -> void:
	var sz: Vector2 = _deco.size
	var dot := COL_WOOD
	for c: Vector2 in [Vector2(5, 5), Vector2(sz.x - 8, 5),
			Vector2(5, sz.y - 8), Vector2(sz.x - 8, sz.y - 8)]:
		_deco.draw_rect(Rect2(c, Vector2(3, 3)), dot)
	# 왼쪽 위 작은 나뭇잎 (픽셀 두 장)
	_deco.draw_rect(Rect2(12, 4, 4, 3), COL_LEAF)
	_deco.draw_rect(Rect2(15, 2, 3, 3), COL_LEAF.lightened(0.2))
	# 대화가 더 남았으면 오른쪽 아래에서 ▼가 콩콩 뛴다
	if in_seq() and not _seq_has_choices:
		var bob := absf(sin(_deco_t * 4.0)) * 3.0
		var p := Vector2(sz.x - 18, sz.y - 12 + bob - 3.0)
		_deco.draw_colored_polygon(PackedVector2Array([
			p, p + Vector2(8, 0), p + Vector2(4, 5)]), COL_WOOD_DK)


# buttons: [[라벨, Callable], ...] — 콜백이 null이면 닫기 동작
func open(title_text: String, body_text: String, buttons: Array,
		portrait_tex: Texture2D = null) -> void:
	title_label.text = title_text
	_name_plate.visible = title_text != ""   # 이름 없는 안내창엔 명패도 없다
	body_label.text = clean_text(body_text)
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
		_style_btn(btn)
		if b[1] != null:
			btn.pressed.connect(b[1])
		else:
			btn.pressed.connect(close)
		buttons_box.add_child(btn)
	visible = true


func set_body(text: String) -> void:
	body_label.text = clean_text(text)


# ---- 대사 다듬기 ----
#
# 창에 나가는 글에서 **눈에 띄어선 안 되는 것**을 걷어낸다.
#   · 강조 기호(**) 같은 편집용 표시 — 게임 안에서는 아무 뜻이 없다
#   · 이어진 공백
# NPC가 입으로 하는 말(「」로 묶인 대사)에서는 괄호로 적어 둔 지문까지
# 떼어낸다 — 말풍선 안에 「...」와 (지문)이 섞이면 읽는 사람이 헷갈린다.
func clean_text(text: String) -> String:
	var out := text.replace("", "")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()


func _is_spoken(text: String) -> bool:
	return text.contains("「") or text.contains("」")


# ---- 사람이 하는 말에는 문장 부호가 넷뿐이다 ----
#
# 마침표 · 쉼표 · 물음표 · 느낌표. 그 밖의 것(따옴표 「」『』, 줄표 —,
# 가운뎃점 ·, 말줄임표 …, ★♥ 같은 그림 기호)은 전부 걷어낸다.
# 누가 하는 말인지는 창의 이름패가 알려 주므로 따옴표도 필요 없다.
# (괄호로 적은 지문은 앞서 _strip_parens가 이미 떼어냈다)
const KEEP_PUNCT := ".,?!"


func _only_basic_punct(text: String) -> String:
	var out := ""
	for ch in text.replace("…", "...").replace("...", "..."):
		if ch == "\n" or ch == " ":
			out += ch
			continue
		if KEEP_PUNCT.contains(ch):
			out += ch
			continue
		var c := ch.unicode_at(0)
		# 한글 · 숫자 · 알파벳만 남긴다
		if (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x1100 and c <= 0x11FF) \
				or (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) \
				or (c >= 0x61 and c <= 0x7A):
			out += ch
		else:
			out += " "     # 지운 자리에 낱말이 붙지 않게 한 칸 남긴다
	return out


# 괄호로 묶인 부분을 통째로 걷어낸다 (중첩은 없다고 본다)
func _strip_parens(text: String) -> String:
	var out := ""
	var depth := 0
	for ch in text:
		if ch == "(" or ch == "（":
			depth += 1
			continue
		if ch == ")" or ch == "）":
			depth = maxi(depth - 1, 0)
			continue
		if depth == 0:
			out += ch
	return out


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
		_style_btn(btn)
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
	_seq = _paginate_seq(entries)
	_seq_idx = -1
	_seq_name = speaker
	_seq_portrait = portrait_tex
	_seq_on_end = on_end
	_advance_seq()


# 대사 한 페이지는 세 줄까지다 — 창이 지나치게 커지지 않으면서도,
# **한 문장이 두 화면에 걸쳐 끊기는 일이 없도록** 넉넉히 잡은 값이다.
# \n으로 나눈 줄뿐 아니라 자동 줄바꿈으로 생기는 줄까지 픽셀 폭으로
# 계산해서, 한 줄이 아무리 길어도 화면 밖으로 넘치지 않는다.
# 이벤트는 첫 조각에서, 선택지·이름 같은 나머지 성질은 마지막 조각에 남는다.
const WRAP_W := 330.0   # 본문이 실제로 쓰는 폭 (패널 - 초상화 - 여백)
const PAGE_LINES := 3   # 한 페이지에 담는 줄 수


func _wrap_at(text: String, width: float) -> PackedStringArray:
	var f: Font = body_label.get_theme_font("font")
	var out: PackedStringArray = []
	for raw in text.split("\n"):
		var line := ""
		for ch in raw:
			if line != "" and f.get_string_size(line + ch,
					HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY).x > width:
				out.append(line)
				line = ch
			else:
				line += ch
		out.append(line)
	return out


func _wrap_lines(text: String) -> PackedStringArray:
	return _wrap_at(text, WRAP_W)


# 두 줄로 나뉠 때 **양쪽 길이를 고르게** 맞춘다.
# 그냥 폭에 맞춰 자르면 둘째 줄에 한두 글자만 덜렁 남아 읽기 어렵다 —
# 줄 수가 늘지 않는 선까지 폭을 좁혀서 자르면 자연스럽게 반씩 나뉜다.
func _wrap_balanced(text: String) -> PackedStringArray:
	var lines := _wrap_at(text, WRAP_W)
	if lines.size() <= 1:
		return lines
	var lo := 60.0
	var hi := WRAP_W
	while hi - lo > 4.0:
		var mid := (lo + hi) * 0.5
		if _wrap_at(text, mid).size() <= lines.size():
			hi = mid
		else:
			lo = mid
	return _wrap_at(text, hi)


# 한 문장 단위로 자른다 (문장 부호 뒤에서 끊는다).
# 손으로 넣은 줄바꿈은 무시하고 다시 짠다 — 글자 크기가 달라져도
# 「한 문장은 한 화면에」가 지켜지게 하기 위해서다.
func _split_sentences(text: String) -> PackedStringArray:
	var flat := text.replace("\n", " ").strip_edges()
	while flat.contains("  "):
		flat = flat.replace("  ", " ")
	var out: PackedStringArray = []
	var cur := ""
	for i in flat.length():
		var ch := flat[i]
		cur += ch
		if ch in [".", "!", "?", "…"]:
			# 마침표 뒤에 닫는 따옴표가 붙으면 거기까지가 한 문장이다
			while i + 1 < flat.length() and flat[i + 1] in ["」", "』", "\"", "'", ")"]:
				i += 1
				cur += flat[i]
			out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out


# 대사 한 덩이를 화면 두 줄짜리 페이지들로 나눈다.
# **문장이 페이지를 가로질러 끊기지 않는다** — 짧은 문장은 두 문장까지
# 한 페이지에 모으고, 두 줄을 넘는 긴 문장만 어쩔 수 없이 나눈다.
func _paginate_seq(entries: Array) -> Array:
	var paged: Array = []
	for e_v in entries:
		var e: Dictionary = e_v
		var body := clean_text(str(e.get("text", "")))
		# NPC가 하는 말에서는 괄호 지문을 떼어낸다 (지문만 있는 페이지는 그대로)
		if _is_spoken(body):
			var spoken := clean_text(_only_basic_punct(_strip_parens(body)))
			if spoken != "":
				body = spoken
		var pages: Array[String] = []
		var buf: PackedStringArray = []
		for sent: String in _split_sentences(body):
			var lines := _wrap_balanced(sent)
			if lines.size() > PAGE_LINES:
				# 세 줄로도 안 담기는 아주 긴 문장만 어쩔 수 없이 나눈다
				if not buf.is_empty():
					pages.append("\n".join(buf))
					buf = []
				var i := 0
				while i < lines.size():
					pages.append("\n".join(lines.slice(i,
						mini(i + PAGE_LINES, lines.size()))))
					i += PAGE_LINES
				continue
			if buf.size() + lines.size() > PAGE_LINES:
				pages.append("\n".join(buf))
				buf = []
			buf += lines
		if not buf.is_empty():
			pages.append("\n".join(buf))
		if pages.is_empty():
			pages.append(body)
		for pi in pages.size():
			var pg := {"text": pages[pi]}
			if e.has("portrait"):
				pg["portrait"] = e.portrait
			if e.has("name"):
				pg["name"] = e.name
			if pi == 0 and e.has("event"):
				pg["event"] = e.event
			if pi == pages.size() - 1 and e.has("choices"):
				pg["choices"] = e.choices
			paged.append(pg)
	return paged


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
