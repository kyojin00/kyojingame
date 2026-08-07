# 연구 노트 (N): 할아버지가 남긴 노트. 발견할 때마다 빈 페이지가 채워지고,
# 절반 이상 채워지면 숨겨진 메모가 하나씩 해금된다. (게임의 핵심 시스템)
extends CanvasLayer

var main: Node2D
var items_box: VBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 22
	visible = false

	var panel := PanelContainer.new()
	panel.position = Vector2(140, 52)
	panel.custom_minimum_size = Vector2(360, 250)
	var style := StyleBoxFlat.new()
	# 노트 느낌의 밝은 양피지 배경
	style.bg_color = Color(0.93, 0.88, 0.74, 0.98)
	style.border_color = Color(0.55, 0.42, 0.26)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var title := Label.new()
	title.text = "- 할아버지의 연구 노트 (%s/ESC: 닫기) -" % GameData.key_label("open_note")
	title.add_theme_color_override("font_color", Color(0.5, 0.32, 0.12))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 204)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	items_box = VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_box.add_theme_constant_override("separation", 2)
	scroll.add_child(items_box)


func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_rebuild()


func _line(text: String, color := Color(0.24, 0.17, 0.09)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	items_box.add_child(l)


func _head(text: String) -> void:
	_line(text, Color(0.5, 0.32, 0.12))


const DIM := Color(0.55, 0.48, 0.4)
const GOLD := Color(0.62, 0.42, 0.05)


func _rebuild() -> void:
	for c in items_box.get_children():
		c.queue_free()

	var prog: Dictionary = GameData.note_progress()
	var pct := int(prog.ratio * 100.0)
	_head("기록된 페이지: %d / %d (%d%%)" % [int(prog.filled), int(prog.total), pct])
	_line("새로운 것을 발견하면 빈 페이지가 채워진다.", DIM)

	# 작물 기록
	_line("")
	_head("[작물 기록]")
	for id in GameData.CROP_IDS:
		var n := int(GameData.crops_harvested.get(id, 0))
		if n > 0:
			_line("  %s — 수확 %d회" % [GameData.CROPS[id].name, n])
		else:
			_line("  ??? — 아직 수확하지 못했다", DIM)

	# 물고기 생태
	_line("")
	_head("[물고기 생태]")
	for f in GameData.FISH:
		var caught := int(GameData.fish_caught.get(f[0], 0))
		if caught > 0:
			_line("  %s — %d마리 관찰" % [GameData.ITEMS[f[0]].name, caught])
		else:
			_line("  ??? — 물가에서 만나지 못했다", DIM)

	# 광물 연구
	_line("")
	_head("[광물 연구]")
	for mid in ["ore", "gem"]:
		if GameData.minerals_found.get(mid, false):
			_line("  %s — 동굴에서 발견" % GameData.ITEMS[mid].name)
		else:
			_line("  ??? — 동굴 어딘가에", DIM)

	# 몬스터 관찰
	_line("")
	_head("[몬스터 관찰]")
	for mid in GameData.MOBS:
		var kills := int(GameData.mob_kills.get(mid, 0))
		if kills > 0:
			_line("  %s — %s" % [GameData.MOBS[mid].name, GameData.MOBS[mid].desc])
		else:
			_line("  ??? — 동굴에서 만나보자", DIM)

	# 요리 기록
	_line("")
	_head("[요리 기록]")
	for rid in GameData.RECIPE_IDS:
		var made := int(GameData.recipes_cooked.get(rid, 0))
		if made > 0:
			_line("  %s — %d번 만들었다" % [GameData.ITEMS[rid].name, made])
		else:
			_line("  ??? — 조리대에서 실험해 보자", DIM)

	# 주민 이야기
	_line("")
	_head("[주민 이야기]")
	for npc_id in GameData.NPCS:
		var def: Dictionary = GameData.NPCS[npc_id]
		var aff := int(GameData.affinity[npc_id])
		if aff >= 50:
			_line("  %s의 기억:" % def.name)
			_line("   \"%s\"" % String(def.secret50).replace("\n", " "), Color(0.35, 0.27, 0.16))
		else:
			_line("  %s — 더 친해지면 이야기해 줄 것 같다 (%d/50)" % [def.name, aff], DIM)
		if aff >= 100:
			_line("   \"%s\"" % String(def.secret100).replace("\n", " "), Color(0.35, 0.27, 0.16))
		elif aff >= 50:
			_line("   ...아직 못다 한 이야기가 있는 듯하다 (%d/100)" % aff, DIM)

	# 할아버지의 숨겨진 메모 (진행도 해금)
	_line("")
	_head("[할아버지의 숨겨진 메모]")
	for memo in GameData.NOTE_MEMOS:
		if prog.ratio >= float(memo[0]):
			_line("  · %s" % memo[1], GOLD)
			_line("    %s" % String(memo[2]).replace("\n", " "))
		else:
			_line("  · ??? (기록 %d%% 필요)" % int(float(memo[0]) * 100.0), DIM)

	# 전설의 재료 (메모 II부터 존재가 드러난다)
	if prog.ratio >= 0.6 or GameData.legends_owned() > 0:
		_line("")
		_head("[일곱 개의 전설 재료]")
		for leg in GameData.LEGENDS:
			if int(GameData.items[leg[0]]) > 0:
				_line("  V %s (%s)" % [GameData.ITEMS[leg[0]].name, leg[1]], GOLD)
			elif prog.ratio >= 0.7:
				_line("  - ??? (%s) 힌트: %s" % [leg[1], leg[2]], DIM)
			else:
				_line("  - ??? (%s)" % leg[1], DIM)

	# 마지막 연금술 (메모 IV 해금 후)
	if prog.ratio >= 0.8 and not GameData.ending_seen:
		_line("")
		_head("[마지막 연금술]")
		_line("  일곱 재료: %d / %d" % [GameData.legends_owned(), GameData.LEGENDS.size()])
		var b := Button.new()
		b.text = "연구실 책상에서 마지막 연금술을 시작한다"
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not GameData.can_final_alchemy()
		b.pressed.connect(func() -> void:
			close()
			main.show_ending())
		items_box.add_child(b)
	elif GameData.ending_seen:
		_line("")
		_head("[유니콘의 뿔]")
		_line("  세상에 단 하나뿐인 뿔이 연구실에서 빛나고 있다.", GOLD)
		_line("  할아버지의 꿈은 완성되었다. 이야기는 계속된다.", DIM)
