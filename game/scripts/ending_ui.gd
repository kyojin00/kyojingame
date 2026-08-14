# 꿈속 엔딩 시퀀스 — 기억의 물약을 마시고 잠들면 시작된다.
#
# 흐름: 꿈속(할아버지·할머니의 인사) → 플레이 통계 리포트(한 줄씩
# 떠오르는 회상) → 마을 사람들의 배웅(전 NPC + 떠난 우체부까지) →
# 마지막 카드 → 꿈에서 깨어나 다음 날 아침(자유 플레이).
#
# 화면은 전부 이 레이어 하나가 그린다 — 클릭(또는 E/Space)으로 넘긴다.
extends CanvasLayer

var main: Node2D
var phase := ""            # "" / town / stats / note / credits / outro
var _bg: ColorRect
var _root: Control
var _timer := 0.0
var _idx := 0              # 지금 몇 번째 줄/카드인가
var _lines: Array = []     # dream 대사 / stats 줄 목록
var _cards: Array = []     # credits 카드 목록
var _auto := false         # 샷 모드 — 자동으로 빠르게 넘어간다

const COL_TEXT := Color(0.93, 0.9, 0.84)
const COL_DIM := Color(0.62, 0.58, 0.52)
const COL_GOLD := Color(1.0, 0.84, 0.37)


func _ready() -> void:
	layer = 44
	visible = false


# ---- 시작 ----

func begin() -> void:
	if visible:
		return
	_auto = OS.get_environment("KYOJIN_SHOT") != ""
	main.story_cutscene = true
	main.hud.visible = false
	main.dialog.close()
	visible = true
	_make_root()
	_start_town()
	Sound.stop_bgm()


func _make_root() -> void:
	for c in get_children():
		c.queue_free()
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.05, 1.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed \
			and ev.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo \
			and ev.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
		_advance()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	# 통계 줄은 시간이 지나면 저절로 하나씩 떠오른다 (클릭하면 빨리)
	var pace := 0.25 if _auto else 1.1
	if phase == "stats" and _idx < _lines.size() and _timer > pace:
		_reveal_next_stat()
	if _auto and _timer > (0.35 if phase != "stats" else 3.0):
		_advance()


# ---- 새싹이 돋은 아침, 달라진 마을 ----

func _start_town() -> void:
	phase = "town"
	_idx = 0
	_timer = 0.0
	var nm := GameData.player_name
	var call_name := ("%s의 밭" % nm) if nm != "" else "그 사람의 밭"
	_lines = [
		["", "(새싹 하나가 아침 볕을 받고 서 있다.\n어제까지 아무것도 없던 자리에.)"],
		["", "(밭에서 마을 쪽을 올려다본다.\n처음 이 땅에 발을 디디던 날이 떠오른다.)"],
		["", "(그때 마을에는 이장의 낡은 오두막 하나뿐이었다.)"],
		["", "(지금은 상점의 차양이 펄럭이고,\n도서관 창가에 불이 켜져 있다.)"],
		["", "(대장간 화로에서 연기가 오르고,\n목장 울타리 너머로 짐승들이 울음을 낸다.)"],
		["", "(회관 앞에서는 벌써 다음 축제 이야기가 오간다.\n온천에서는 누군가 어깨를 두드리고 있다.)"],
		["", "(숲속 오두막의 굴뚝에서도 가느다란 연기.\n연금술사도 오늘은 불을 지폈나 보다.)"],
		["", "(그리고 %s.\n여기서부터 전부 시작됐다.)" % call_name],
		["", "(할아버지의 연구는 여기서 끝났다.\n...하지만 이곳에서의 삶은 아직 끝나지 않았다.)"],
	]
	_show_town_line()


func _show_town_line() -> void:
	for c in _root.get_children():
		c.queue_free()
	# 프롤로그의 할아버지 그림이 꿈의 빛무리 위에 떠오른다
	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.95, 0.8, 0.06)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(glow)
	var pic := TextureRect.new()
	pic.texture = main.tex.get("prologue_farm_0", main.tex.get("prologue_grandpa_0"))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(504, 216)
	pic.position = Vector2(228, 90)
	pic.size = Vector2(504, 216)
	pic.modulate = Color(1, 1, 1, 0.85)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pic)
	var entry: Array = _lines[_idx]
	if str(entry[0]) != "":
		var who := Label.new()
		who.text = "— %s —" % str(entry[0])
		who.position = Vector2(0, 340)
		who.size = Vector2(960, 30)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.add_theme_font_size_override("font_size", 18)
		who.add_theme_color_override("font_color", COL_GOLD)
		who.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(who)
	var lab := Label.new()
	lab.text = str(entry[1])
	lab.position = Vector2(0, 375)
	lab.size = Vector2(960, 110)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", COL_TEXT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lab)
	_hint("클릭해서 계속")


func _hint(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.position = Vector2(0, 505)
	h.size = Vector2(950, 24)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", COL_DIM)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(h)


# ---- 플레이 통계 리포트 (한 줄씩 떠오르는 회상) ----

func _start_stats() -> void:
	phase = "stats"
	_idx = 0
	_timer = 0.0
	_lines = _build_stat_lines()
	for c in _root.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "✦  우리의 나날들  ✦"
	title.position = Vector2(0, 42)
	title.size = Vector2(960, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title)
	var box := VBoxContainer.new()
	box.name = "StatBox"
	box.position = Vector2(180, 100)
	box.size = Vector2(600, 400)
	box.add_theme_constant_override("separation", 7)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_hint("클릭: 다음 줄 · 다 보이면 한 번 더 클릭")


func _build_stat_lines() -> Array:
	var g := GameData
	var fish_n := 0
	for k in g.fish_caught:
		fish_n += int(g.fish_caught[k])
	var kills := 0
	for k in g.mob_kills:
		kills += int(g.mob_kills[k])
	var cook_n := 0
	for k in g.recipes_cooked:
		cook_n += int(g.recipes_cooked[k])
	var pick_n := 0
	for k in g.forage_caught:
		pick_n += int(g.forage_caught[k])
	var harvest_n := 0
	for k in g.crops_harvested:
		harvest_n += int(g.crops_harvested[k])
	var aff_total := 0
	var best_npc := ""
	var best_aff := -1
	for nid in g.NPCS:
		var a := int(g.affinity[nid])
		aff_total += a
		if a > best_aff:
			best_aff = a
			best_npc = str(g.NPCS[nid].name)
	var prog: Dictionary = g.note_progress()
	var arrive := g.date_text(g.arrive_day) if g.arrive_day > 0 else "1년 봄 1일"
	var out: Array = [
		["처음 우리 마을에 온 날", "%s%s — 우체부 아저씨를 따라, 처음 마을에 발을 디뎠다"
			% [arrive, (" " + g.arrive_clock) if g.arrive_clock != "" else ""]],
		["함께한 날", "%d일 — 오늘까지, 하루도 같은 날이 없었다" % g.day],
		["플레이 시간", "%s — 화면 너머의 진짜 시간" % g.playtime_text()],
		["도끼를 휘두른 날들", "나무 %d그루 — 그만큼의 장작과 땀" % g.trees_chopped],
		["곡괭이가 울린 소리", "바위 %d개 — 돌가루 사이에서 빛나던 것들" % g.rocks_mined],
		["밭에서 거둔 것", "수확 %d번 — 씨앗은 한 번도 배신하지 않았다" % harvest_n],
		["물가에서 보낸 시간", "물고기 %d마리 — 찌가 흔들릴 때마다 두근거렸다" % fish_n],
		["부엌의 온기", "요리 %d번 — 냄새만으로 배부르던 저녁" % cook_n],
		["숲과 해변의 선물", "채집 %d번 — 몸을 숙여야 보이는 것들" % pick_n],
		["어둠과 맞선 밤", "몬스터 %d마리 — 무섭지만 물러서지 않았다" % kills],
		["사람들과의 마음", "호감도 총 %d · 가장 아끼는 사이: %s" % [aff_total, best_npc]],
		["할아버지의 연구 노트", "%d/%d 페이지 (%d%%) — 빈 노트가 가득 찼다"
			% [int(prog.filled), int(prog.total), int(prog.ratio * 100.0)]],
	]
	return out


func _reveal_next_stat() -> void:
	_timer = 0.0
	var box: VBoxContainer = _root.get_node_or_null("StatBox")
	if box == null or _idx >= _lines.size():
		return
	var entry: Array = _lines[_idx]
	_idx += 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var head := Label.new()
	head.text = str(entry[0])
	head.custom_minimum_size = Vector2(190, 0)
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", COL_GOLD)
	row.add_child(head)
	var body := Label.new()
	body.text = str(entry[1])
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(body)
	row.modulate.a = 0.0
	box.add_child(row)
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.45)
	Sound.play_sfx("sfx_ui")


# ---- 마을 사람들의 배웅 ----

# 호감도 50 이상이면 추억을 언급하는 개별 인사가 나온다
const MEMORY_LINES := {
	"chief": "「처음 편지를 들고 온 날이 엊그제 같은데...\n자네 덕에 교진 마을이 다시 살아났네. 정말 즐거웠어.」",
	"merchant": "「첫 손님이 너였던 거, 기억해?\n계산대 너머로 웃던 날들 — 정말 즐거웠어!」",
	"blacksmith": "「화로를 다시 살려 준 그 날을 잊지 않아.\n네 도구엔 내 자부심이 들어 있다. 정말 즐거웠네.」",
	"rancher": "「우리 애들이 너를 얼마나 따랐는데!\n초원에서 같이 뒹굴던 거, 정말 즐거웠어~」",
	"fisher": "「황금잉어 소문 쫓다가 너를 만난 게\n내 인생 최고의 월척이었지. 정말 즐거웠다!」",
	"librarian": "「오래된 책을 처음 보여 주던 날...\n서가를 함께 채운 시간들, 정말 즐거웠어요.」",
	"explorer": "「너랑 같이면 숲길도 지도 밖도 무섭지 않았어.\n최고의 모험이었다 — 정말 즐거웠어!」",
	"forest_mom": "「숲속 우리 집을 찾아 준 날부터,\n솔이도 나도 외롭지 않았어. 정말 즐거웠단다.」",
	"forest_girl": "「언니(오빠)가 와 주는 날이 제일 좋았어!\n...정말 즐거웠어. 또 놀러 와야 해?」",
}
const GENERIC_LINES := {
	"chief": "「자네가 온 뒤로 마을에 웃음이 늘었네.」",
	"merchant": "「가게에 자주 들러 줘서 고마웠어!」",
	"blacksmith": "「쇠는 정직하지. 자네 손도 그랬네.」",
	"rancher": "「동물들이 너를 참 좋아했어~」",
	"fisher": "「물가에서 또 보자고!」",
	"librarian": "「책 먼지 냄새가 나면 놀러 오세요.」",
	"explorer": "「다음 모험도 같이 가는 거다?」",
	"forest_mom": "「숲은 언제나 조용히 널 반길 거야.」",
	"forest_girl": "「또 놀러 와야 해!」",
}


func _start_credits() -> void:
	phase = "credits"
	_idx = 0
	_timer = 0.0
	_cards = []
	# 이장 → 정착한 주민들 → 숲속 모녀 → 떠났던 우체부 → 다 함께
	var order: Array = ["chief"]
	for nid: String in ["merchant", "blacksmith", "fisher", "librarian",
			"rancher", "explorer", "forest_mom", "forest_girl"]:
		if GameData.npc_greeted.has(nid) or _npc_in_town(nid):
			order.append(nid)
	for nid: String in order:
		var aff := int(GameData.affinity[nid])
		var line: String = str(MEMORY_LINES.get(nid, "")) if aff >= 50 \
			else str(GENERIC_LINES.get(nid, "「고마웠어!」"))
		_cards.append({"name": str(GameData.NPCS[nid].name),
			"tex": "npc_%s_portrait_%s" % [nid, "happy" if aff >= 50 else "normal"],
			"line": line})
	# 떠났던 사람도 배웅하러 돌아온다 — 우체부 아저씨
	_cards.append({"name": "우체부 아저씨", "tex": "npc_postman_portrait_happy",
		"line": "「숲길을 같이 걷던 첫날을 기억하나?\n자네 편지라면 어디든 배달함세 — 정말 즐거웠네!」"})
	# 마지막: 모두 함께
	_cards.append({"name": "교진 마을 사람들", "tex": "",
		"line": "「우린 언제나 여기에 있으니까,\n놀고 싶을 때마다 언제든 찾아와!」"})
	_show_card()


func _npc_in_town(nid: String) -> bool:
	for n in main.npcs:
		if n.id == nid:
			return true
	return false


func _show_card() -> void:
	for c in _root.get_children():
		c.queue_free()
	var card: Dictionary = _cards[_idx]
	if str(card.tex) != "" and main.tex.has(str(card.tex)):
		var pic := TextureRect.new()
		pic.texture = main.tex[str(card.tex)]
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(400, 120)
		pic.size = Vector2(160, 160)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(pic)
	var who := Label.new()
	who.text = str(card.name)
	who.position = Vector2(0, 300)
	who.size = Vector2(960, 34)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_size_override("font_size", 22)
	who.add_theme_color_override("font_color", COL_GOLD)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(who)
	var lab := Label.new()
	lab.text = str(card.line)
	lab.position = Vector2(0, 345)
	lab.size = Vector2(960, 110)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 19)
	lab.add_theme_color_override("font_color", COL_TEXT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lab)
	var prog := Label.new()
	prog.text = "%d / %d" % [_idx + 1, _cards.size()]
	prog.position = Vector2(0, 505)
	prog.size = Vector2(950, 24)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog.add_theme_font_size_override("font_size", 13)
	prog.add_theme_color_override("font_color", COL_DIM)
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(prog)


# ---- 마지막 카드와 기상 ----

func _start_outro() -> void:
	phase = "outro"
	_timer = 0.0
	for c in _root.get_children():
		c.queue_free()
	var t1 := Label.new()
	t1.text = "— 교진 팜 —"
	t1.position = Vector2(0, 200)
	t1.size = Vector2(960, 44)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_font_size_override("font_size", 30)
	t1.add_theme_color_override("font_color", COL_GOLD)
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(t1)
	var t2 := Label.new()
	t2.text = "함께해 주어 고맙습니다.\n그리고 — 교진 마을의 나날은 계속됩니다.\n(밭의 새싹은 앞으로도 자랍니다)"
	t2.position = Vector2(0, 265)
	t2.size = Vector2(960, 70)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 17)
	t2.add_theme_color_override("font_color", COL_TEXT)
	t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(t2)
	var b := Button.new()
	b.text = "마을로 돌아간다"
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(400, 380)
	b.size = Vector2(160, 42)
	b.pressed.connect(wake)
	_root.add_child(b)


# ---- 연구 노트의 마지막 줄 — 플레이어가 남기는 기록 ----

func _start_note() -> void:
	phase = "note"
	_timer = 0.0
	for c in _root.get_children():
		c.queue_free()
	var t1 := Label.new()
	t1.text = "할아버지의 연구 노트  ―  100%"
	t1.position = Vector2(0, 150)
	t1.size = Vector2(960, 40)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_font_size_override("font_size", 24)
	t1.add_theme_color_override("font_color", COL_GOLD)
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(t1)
	var t2 := Label.new()
	t2.text = "마지막 장에는, 이 노트를 이어받은 사람의 글씨로\n한 줄이 새로 적혀 있다."
	t2.position = Vector2(0, 205)
	t2.size = Vector2(960, 60)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 15)
	t2.add_theme_color_override("font_color", COL_DIM)
	t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(t2)
	var t3 := Label.new()
	t3.text = "「할아버지의 연구는 끝났지만,\n이곳에서의 삶은 아직 끝나지 않았다.」"
	t3.position = Vector2(0, 285)
	t3.size = Vector2(960, 80)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t3.add_theme_font_size_override("font_size", 20)
	t3.add_theme_color_override("font_color", COL_TEXT)
	t3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(t3)
	_hint("클릭: 계속")


# ---- 진행 ----

func _advance() -> void:
	match phase:
		"town":
			_idx += 1
			_timer = 0.0
			if _idx >= _lines.size():
				_start_stats()
			else:
				_show_town_line()
		"stats":
			if _idx < _lines.size():
				_reveal_next_stat()   # 클릭하면 다음 줄이 바로 떠오른다
			else:
				_start_note()
		"note":
			_start_credits()
		"credits":
			_idx += 1
			_timer = 0.0
			if _idx >= _cards.size():
				_start_outro()
			else:
				_show_card()
		"outro":
			if _auto:
				wake()


# 엔딩이 끝난다 — 세이브는 그대로, 하던 자리에서 자유 생활이 이어진다
# (advance_day는 남겨 두지만 이제 날짜를 넘기지 않는다 — 후일담이 계속된다)
func wake(_advance_day := true) -> void:
	if not visible:
		return
	phase = ""
	visible = false
	for c in get_children():
		c.queue_free()
	GameData.dream_ready = false
	GameData.dream_seen = true
	main.story_cutscene = false
	main.hud.visible = true
	main.hud.story_banner("메인 스토리 20 완결", "가장 오래된 자리")
	main.hud.show_message("교진 마을의 나날은 계속된다.\n새싹은 내일도, 그다음 날도 자랄 것이다.", 8.0)
	main.saveio.save_now()
