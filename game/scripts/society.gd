# 세계·사람을 만지는 사회 행동(채용·근무·봉급·소매치기·선반·목격·이장의 마을 회의·
# 봉사·성격 질문).
#
# 대화창·방·NPC 노드를 만지므로 GameData 가 아니라 main 컴포넌트다.
# 새 코드는 GameData.npc_def/npc_kind/aff/aff_add 만 쓴다 — 호칭·기억·대범함의
# 순수 계산(player_title·call_opener·bold_add·theft_p…)은 전부 game_data.gd 에
# 있고, 여기는 그 값을 읽어 **창을 열고 상태를 바꾸는 손**이다.
#
# 지키는 것(헌법 §0):
#   · 알림은 다음날 아침 결산 한 줄뿐 — 여기서는 토스트를 띄우지 않는다
#   · 돈은 창구 앞에서 E 를 누를 때만 오간다 (봉급도 「받으러 가는 행위」)
#   · 호칭은 NPC 의 입으로 나온다 (talk_opener → call_opener)
#   · 게스트는 모든 진입점 첫 줄에서 돌아가고, 선택지는 gray() 로만 보인다
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinSociety
extends Node

var m: KyojinMain    # main.gd

# 하네스가 주사위를 고정한다 — 0 이상이면 randf() 대신 이 값을 쓴다.
# 검사가 끝나면 하네스가 −1 로 되돌린다 (남겨 두면 실제 플레이의 도둑질이 굳는다)
var force_roll := -1.0
var force_report := -1.0
var _last_min := -1.0   # 지난 프레임의 GameData.minutes — 밤길 분을 차분으로 센다
var _tick := 0.0        # animals_now 갱신 간격

# 근무 반응 줄의 「화자: 대사」에서 화자가 NPC 이름과 다른 경우 — 이장만 직함으로 적혀 있다
const SPEAKER_ALIAS := {"이장": "chief"}

# 이장·회의·도둑질 대사(부록 §4 · pack.chief)는 GameData.SOCIETY_LINES 한 곳에만 둔다 —
# 같은 표를 두 파일에 베껴 두면 한쪽만 고쳐지는 날이 온다. 여기서는 읽기만 한다

# ---- 매 프레임 ----

func _process(delta: float) -> void:
	if m == null or m.shop_room == null or Net.is_guest():
		return
	# (a) 밤길 분 — 프레임 차분으로 센다. 30분 이상 건너뛴 것(온천·하네스 점프)은
	# 「밖에서 걸은 시간」이 아니라서 버린다 (D8). 시계가 새벽으로 되감기면 dm 이
	# 음수라 저절로 걸러진다
	var now: float = GameData.minutes
	var dm: float = now - _last_min
	_last_min = now
	if dm > 0.0 and dm < 30.0 and GameData.is_evening() and outdoors():
		if int(GameData.me.get("night_out_day", 0)) != GameData.day:
			GameData.me["night_out_min"] = 0.0
			GameData.me["night_out_day"] = GameData.day
		GameData.me["night_out_min"] = float(GameData.me.get("night_out_min", 0.0)) + dm
		GameData.bold_add(dm / 60.0, "night")
	# (b) 가축 수 — 자유직 「목장주」의 재료. 반 초에 한 번이면 충분하다
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		GameData.animals_now = m.animals.size()


# 마을 바깥 땅에 서 있는가 — 밤길 분은 여기서만 쌓인다
func outdoors() -> bool:
	return not m.interior.visible and not m.cave.visible \
		and not m.shop_room.visible and GameData.story_phase == "done"


# ---- 작은 손 ----

# 회색 선택지 규약 — 버튼을 나중에 회색으로 칠하는 게 아니라, 누르면 「왜 안 되는지」를
# 그 자리에서 말하는 선택지를 만든다 (D1). 라벨 앞의 「… 」가 회색의 표시다
func gray(label: String, why: String) -> Array:
	return ["… " + label, _say_gray.bind(why)]


func _say_gray(why: String) -> void:
	m.dialog.set_body(why)
	m.dialog.set_buttons([["대화 끝", null]])


func _npc_name(nid: String) -> String:
	return str(GameData.npc_def(nid).get("name", nid))


func _portrait(nid: String) -> Texture2D:
	return m.village._npc_portrait(nid)


# 내가 말하는 페이지의 이름표 — 이름을 안 지었으면 「나」
func _my_name() -> String:
	return GameData.player_name if GameData.player_name != "" else "나"


func _job() -> Dictionary:
	return GameData.JOBS.get(str(GameData.me.get("job", "")), {})


func _inst_def(inst: String) -> Dictionary:
	return GameData.INSTITUTIONS.get(inst, {})


# 그 기관의 점원 직업 표 (INSTITUTIONS.job → JOBS)
func _job_of(inst: String) -> Dictionary:
	return GameData.JOBS.get(str(_inst_def(inst).get("job", "")), {})


func _hire_line(inst: String, key: String) -> String:
	return str(_job_of(inst).get("hire", {}).get(key, ""))


# 봉급 대사 — 부록 §1 은 wage_lines 인데 pack 원본 키는 wage 다(숫자 wage 와 겹친다).
# game_data 갈래가 어느 이름을 골랐든 읽히게 둘 다 본다
func _wage_lines(job: Dictionary) -> Dictionary:
	var w: Variant = job.get("wage_lines", job.get("wage", {}))
	return w if w is Dictionary else {}


func _rep_add(d: int) -> void:
	var rep: Dictionary = GameData.me.get("reputation", {})
	rep["kyojin"] = int(rep.get("kyojin", 0)) + d
	GameData.me["reputation"] = rep


func _me_int(key: String, d := 0) -> int:
	return int(GameData.me.get(key, d))


func _me_add(key: String, d: int) -> void:
	GameData.me[key] = _me_int(key) + d


# 주사위 — 인자 > 하네스 강제값 > 난수
func _roll(roll: float) -> float:
	if roll >= 0.0:
		return roll
	if force_roll >= 0.0:
		return force_roll
	return randf()


# 목격자 한 사람이 이장에게 가는가 — 나를 좋아할수록 덜 간다 (하한 25%)
func _tells(wid: String) -> bool:
	var r: float = force_report if force_report >= 0.0 else randf()
	return r < 0.4 * maxf(0.25, 1.0 - float(GameData.aff(wid)) / 200.0)


# 근무 일지 — 상한을 넘으면 가장 오래된 근무·독서를 지운다. 「보이는 것」을 봤다는
# 표시(kind "sees")는 지우지 않는다 — 지우면 다음 근무에 또 보여 주게 된다
func _log_work(kind: String, inst: String, pick: int) -> void:
	var log: Array = GameData.me.get("work_log", [])
	log.append({"day": GameData.day, "kind": kind, "inst": inst, "pick": pick})
	while log.size() > GameData.WORK_LOG_MAX:
		var cut := -1
		for i in log.size():
			if str(log[i].get("kind", "")) != "sees":
				cut = i
				break
		if cut < 0:
			break
		log.remove_at(cut)
	GameData.me["work_log"] = log


# 그 직업의 「보이는 것」 페이지를 이미 봤나 — 직업마다 한 페이지다(부록 §3 · 팩의 sees 6줄).
# inst 를 안 보면 잡화점에서 한 번 본 뒤 대장간 도제가 돼도 널빤지 페이지가 영영 안 뜬다
func _sees_shown(inst: String) -> bool:
	for w in GameData.me.get("work_log", []):
		if str(w.get("kind", "")) == "sees" and str(w.get("inst", "")) == inst:
			return true
	return false


# ---- 주인과 자리 ----

# 이 사람이 어느 기관의 우두머리인가 ("" = 아니다)
func owner_inst(nid: String) -> String:
	for inst: String in GameData.INSTITUTIONS:
		if str(GameData.INSTITUTIONS[inst].get("head", "")) == nid:
			return inst
	return ""


# 채용이 되는가 — 빈 문자열이면 된다, 아니면 주인이 거절하는 말.
# 순서가 뜻이다: 손님·문 안 연 가게·자리·겸업·대기·호감·손·책 (D6, 부록 §3)
func can_hire(inst: String) -> String:
	if Net.is_guest():
		return "손님은 안 쓰네."
	var idef := _inst_def(inst)
	if idef.is_empty():
		return "그런 자리는 없네."
	var head := str(idef.get("head", ""))
	var ranks: Array = idef.get("ranks", ["", ""])
	if not GameData.npc_open(head):
		return "가게부터 열어야지."
	if GameData.seat_of(inst, str(ranks[0])) != "":
		return "자리가 안 비었네."
	if str(GameData.me.get("job", "")) != "":
		return _hire_line(inst, "refuse_busy")
	# 그만둔 지 이레 안 — refuse_busy(「이미 다른 데서 일하잖아」)는 무직자에게 사실과
	# 어긋나므로 계약서 문구로 말한다(부록 §3 을 그에 맞게 고쳤다)
	var hist: Array = GameData.me.get("job_history", [])
	if not hist.is_empty() and GameData.day - int(hist[-1].get("to", 0)) < 7:
		return "그만둔 지 이레도 안 됐잖나."
	if GameData.aff(head) < 20:
		return _hire_line(inst, "refuse_aff")
	var skill := str(idef.get("skill", ""))
	if skill != "" and GameData.skill_lv(skill) < 2:
		return _hire_line(inst, "refuse_skill")
	if int(idef.get("books", 0)) > _me_int("books_read"):
		return _hire_line(inst, "refuse_skill")
	return ""


# ---- 광장 대화에 끼어드는 선택지 (village_ui._talk_to 가 부른다) ----

# choices 는 [..., ["대화 끝", null]] 꼴 — 「대화 끝」 바로 위(size−1)나 맨 앞(0)에 끼운다.
# 호감도 콘텐츠가 열리기 전에는 아무것도 끼우지 않는다 (§9 「affinity_open 이후에만」)
func add_talk_choices(nid: String, choices: Array) -> void:
	if not GameData.affinity_open:
		return
	var guest := Net.is_guest()
	var theft: Dictionary = GameData.SOCIETY_LINES.theft
	# ① 주인 — 일자리 이야기. 내가 이미 그 자리에 앉아 있으면 끼우지 않는다 — 내 주인에게
	# 「나도 서 보고 싶어」 하고 「자리가 안 비었네」를 듣는 꼴이 된다. 사직은 계산대(counter_menu)에 있다
	var inst := owner_inst(nid)
	if inst != "" and GameData.job_inst() == inst:
		inst = ""
	if inst != "":
		if guest:
			choices.insert(choices.size() - 1,
				gray("일자리 이야기", "손님은 이 마을 일에 끼지 않는다."))
		else:
			choices.insert(choices.size() - 1, ["일자리 이야기", open_job_talk.bind(inst)])
	# ② 이장 — 성격 질문 · 마을 회의 · 봉사
	if nid == "chief":
		if _me_int("boldness_base", -1) == -1 and GameData.story_phase == "done":
			if guest:
				choices.insert(0, gray("자네는 어떤 사람인가", "손님은 이 마을 일에 끼지 않는다."))
			else:
				choices.insert(0, ["자네는 어떤 사람인가", ask_boldness])
		if GameData.council_pending():
			if guest:
				choices.insert(0, gray("어제 일 — 이장의 마을 회의", "손님은 이 마을 일에 끼지 않는다."))
			else:
				choices.insert(0, ["어제 일 — 이장의 마을 회의", open_council])
		var rec: Dictionary = GameData.service_pending()
		if not rec.is_empty() and int(rec.get("served_day", 0)) != GameData.day:
			if guest:
				choices.insert(0, gray("오늘 봉사", "손님은 이 마을 일에 끼지 않는다."))
			elif GameData.hour_now() >= GameData.SERVICE_LAST_HOUR:
				choices.insert(0, gray("오늘 봉사", "오늘은 늦었다. 내일 아침에 오게."))
			else:
				choices.insert(0, ["오늘 봉사", serve_day])
	# ③ 그 밖의 사람 — 소매치기. 성격을 아직 모르면(base −1) 줄 자체가 없다 (D7)
	elif _me_int("boldness_base", -1) != -1:
		var label := str(theft.get("pickpocket_choice", "소매치기"))
		if GameData.boldness() >= int(GameData.GATE.get("pickpocket", 20)) and not guest:
			choices.insert(choices.size() - 1, [label, pickpocket.bind(nid)])
		else:
			choices.insert(choices.size() - 1,
				gray(label, str(theft.get("pickpocket_gray", "손이 안 나간다"))))


# 하루 첫 대화의 첫마디 — 호칭이 NPC 의 입으로 나오는 자리 (헌법 §0.4).
# 빈 문자열이면 village_ui 가 별도 페이지를 만들지 않는다 (D1)
func talk_opener(nid: String, first_today: bool) -> String:
	if not first_today or not GameData.affinity_open or Net.is_guest():
		return ""
	# 사흘째 결근한 날, 주인의 첫마디는 인사가 아니라 걱정이다 (부록 §3 — 하루 한 번)
	var job := _job()
	if not job.is_empty() and str(job.get("boss", "")) == nid \
			and _me_int("absent_days") == GameData.ABSENT_WARN:
		return str(job.get("absent_warn", ""))
	# 해고된 그날, 옛 주인의 첫마디는 해고 한마디다(hire.fired — absent_warn 과 같은 규약:
	# 그날 하루의 첫 대화 한 번. 부록은 이 줄의 자리를 정하지 않았다)
	var hist: Array = GameData.me.get("job_history", [])
	if not hist.is_empty() and hist[-1] is Dictionary:
		var last: Dictionary = hist[-1]
		if str(last.get("reason", "")) == "fired" and int(last.get("to", 0)) == GameData.day:
			var old_job: Dictionary = GameData.JOBS.get(str(last.get("job", "")), {})
			if str(old_job.get("boss", "")) == nid:
				var fired := str(old_job.get("hire", {}).get("fired", ""))
				if fired != "":
					return fired
	return GameData.call_opener(nid)


# 선택지 페이지에 닿았을 때 — 연화의 「!」는 버튼이 만들어진 뒤에야 붙일 수 있어
# 한 프레임 미룬다 (_advance_seq 는 event 를 먼저 부르고 그 다음 open() 으로 버튼을 짓는다)
func on_choices_page(mom_label: String) -> void:
	if mom_label != "":
		m.village._attach_quest_bang.call_deferred(mom_label)


# ---- 이장의 성격 질문 (헌법 §5.1) ----

func ask_boldness() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var q: Dictionary = GameData.SOCIETY_LINES.bold_question
	var btns: Array = []
	for c in q.choices:
		btns.append([str(c.text), pick_bold.bind(int(c.base))])
	m.dialog.open_seq(_npc_name("chief"), _portrait("chief"), [
		{"text": str(q.lead), "choices": btns},
	])


func pick_bold(v: int) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	GameData.me["boldness_base"] = v
	GameData.me["boldness_state"] = 0.0
	var reply := "그런가. 사람은 살아온 대로 되는 법이지."
	for c in GameData.SOCIETY_LINES.bold_question.choices:
		if int(c.base) == v:
			reply = str(c.reply)
	m.dialog.open(_npc_name("chief"), reply, [["대화 끝", null]], _portrait("chief"))
	m.saveio.save_now()


# ---- 채용·사직 ----

# 「일자리 이야기」 — 내가 먼저 묻고(hire.ask) 주인이 답한다. 거절 사유는 can_hire 가 고른다
func open_job_talk(inst: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var head := str(_inst_def(inst).get("head", ""))
	var ask := _hire_line(inst, "ask")
	var pages: Array = []
	if ask != "":
		pages.append({"text": ask, "name": _my_name(), "portrait": null})
	var why := can_hire(inst)
	if why != "":
		pages.append({"text": why, "choices": [["알겠습니다", null]]})
	else:
		pages.append({"text": _hire_line(inst, "accept"), "choices": [
			["하겠습니다", hire.bind(inst)],
			["생각해 보겠습니다", null],
		]})
	m.dialog.open_seq(_npc_name(head), _portrait(head), pages)


# 자리가 진실이다(헌법 §0.1) — seats 에 "player" 를 앉히는 것이 채용이고, me.job 은 그 그림자
func hire(inst: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var idef := _inst_def(inst)
	var ranks: Array = idef.get("ranks", ["", ""])
	var rows: Dictionary = GameData.seat_rows(inst)
	rows[str(ranks[0])][0] = "player"
	GameData.me["job"] = str(idef.get("job", ""))
	GameData.me["rank"] = str(ranks[0])
	GameData.me["job_since_day"] = GameData.day + 1      # 내일 아침부터
	GameData.me["wage_day"] = GameData.day + 8           # 첫 봉급날 = 첫 근무 이레 뒤
	GameData.me["perf"] = 0
	GameData.me["absent_days"] = 0
	GameData.me["wage_pending"] = 0
	var head := str(idef.get("head", ""))
	m.dialog.open(_npc_name(head), "그래. 늦지 말게.", [["대화 끝", null]], _portrait(head))
	m.saveio.save_now()


# 「그만두겠습니다」 — 밀린 봉급은 이 자리에서 받는다(창구 앞 E, §0.3). 평판은 안 깎인다
func resign() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var job := _job()
	if job.is_empty():
		return
	var inst := str(job.get("inst", ""))
	var head := str(job.get("boss", ""))
	var paid := _me_int("wage_pending")
	if paid > 0:
		GameData.money += paid
		GameData.today_earned += paid
		GameData.me["wage_pending"] = 0
	var ranks: Array = _inst_def(inst).get("ranks", ["", ""])
	var rows: Dictionary = GameData.seat_rows(inst)
	if rows.has(str(ranks[0])) and rows[str(ranks[0])].size() > 0 \
			and str(rows[str(ranks[0])][0]) == "player":
		rows[str(ranks[0])][0] = ""
	var hist: Array = GameData.me.get("job_history", [])
	hist.append({"inst": inst, "rank": str(GameData.me.get("rank", "")),
		"job": str(GameData.me.get("job", "")),
		"from": _me_int("job_since_day"), "to": GameData.day, "reason": "quit"})
	GameData.me["job_history"] = hist
	GameData.me["job"] = ""
	GameData.me["rank"] = ""
	var pages: Array = []
	var ask := str(job.get("hire", {}).get("resign_ask", ""))
	if ask != "":
		pages.append({"text": ask, "name": _my_name(), "portrait": null})
	pages.append({"text": str(job.get("hire", {}).get("resign_reply", "그래, 수고했네."))})
	if paid > 0:
		pages.append({"text": "밀린 몫은 지금 주지."})
	if head != "":
		m.dialog.open_seq(_npc_name(head), _portrait(head), pages)
	m.saveio.save_now()


# ---- 근무·봉급 (방 안 계산대) ----

# 지금 이 방에서 근무할 수 있는가 — 빈 문자열이면 된다
func can_work() -> String:
	if Net.is_guest():
		return "손님은 일하지 않는다."
	if str(GameData.me.get("job", "")) == "":
		return "맡은 일이 없다."
	if GameData.job_inst() != m.shop_room.room_id:
		return "여긴 내 일터가 아니다."
	if GameData.day < _me_int("job_since_day"):
		return "내일부터다."
	var h := GameData.hour_now()
	if h < GameData.OPEN_HOUR or h >= GameData.CLOSE_HOUR:
		return "일하는 시간이 아니다."
	if GameData.worked_on(GameData.day):
		return "오늘 근무는 끝났다."
	return ""


func wage_ready() -> bool:
	return str(GameData.me.get("job", "")) != "" and _me_int("wage_pending") > 0 \
		and GameData.day >= _me_int("wage_day")


# 계산대 E 를 가로챈다 — 이 방에 고용됐거나 채용될 수 있을 때만. 그 밖에는 false 를
# 돌려 기존 계산대 흐름(shop_room.counter_default)이 한 줄도 안 바뀐다 (D2).
# 첫 버튼은 언제나 「가게 일」 — 일자리 때문에 물건을 못 사는 일은 없어야 한다
func counter_menu(room_id: String) -> bool:
	if Net.is_guest():
		return false
	if m.story_cutscene:
		return false
	# 잡화점은 스토리 2(조리대) 이야기가 먼저다
	if room_id == "general" and (GameData.kitchen_quest_ready()
			or GameData.kitchen_quest in ["found", "deliver"]):
		return false
	if not GameData.INSTITUTIONS.has(room_id):
		return false
	var employed := GameData.job_inst() == room_id
	var eligible := can_hire(room_id) == ""
	if not employed and not eligible:
		return false
	var head := str(_inst_def(room_id).get("head", ""))
	var btns: Array = [["가게 일", _counter_default]]
	if employed:
		if can_work() == "":
			btns.append(["근무", work_start])
		var wl := _wage_lines(_job())
		if _me_int("wage_pending") <= 0:
			btns.append(gray("봉급 받기", str(wl.get("nothing", "받을 게 없다."))))
		elif GameData.day < _me_int("wage_day"):
			btns.append(gray("봉급 받기", str(wl.get("not_yet", "봉급날은 아직이다."))))
		else:
			btns.append(["봉급 받기 — %dG" % _me_int("wage_pending"), collect_wage])
		btns.append(["그만두겠습니다", resign])
	if eligible:
		btns.append(["일자리 이야기", open_job_talk.bind(room_id)])
	btns.append(["그만두기", null])
	m.dialog.open(_npc_name(head), "어, 왔나. 무슨 일이야?", btns, _portrait(head))
	return true


func _counter_default() -> void:
	m.dialog.close()
	m.shop_room.counter_default()


# 오늘의 손님 — 직업의 loop 를 날짜와 기관 순번으로 돌린다(하루 안에서는 고정)
func _encounter() -> Dictionary:
	var job := _job()
	var loop: Array = job.get("loop", [])
	if loop.is_empty():
		return {}
	var order: int = GameData.INSTITUTIONS.keys().find(str(job.get("inst", "")))
	var enc: Dictionary = loop[posmod(GameData.day + maxi(order, 0), loop.size())]
	return enc


# 「근무」 — 손님 한 사람을 맞는 미니루프 하나. 시계도 돈도 여기서는 안 움직인다;
# 몫은 wage_pending 에 적립되고 봉급날 주인 앞에서 받는다 (D4)
func work_start() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var job := _job()
	var head := str(job.get("boss", ""))
	var why := can_work()
	if why != "":
		m.dialog.open(_npc_name(head), why, [["알겠습니다", null]], _portrait(head))
		return
	var enc := _encounter()
	if enc.is_empty():
		return
	var pages: Array = []
	# 첫 근무날의 첫마디
	if GameData.day == _me_int("job_since_day"):
		pages.append({"text": str(job.get("hire", {}).get("first_day", "")),
			"name": _npc_name(head), "portrait": _portrait(head)})
	# 주인이 나를 「우리 점원」이라 부르게 된 날, 그 직업만 보는 것을 한 번 보여 준다
	if GameData.aff(head) >= 70 and not _sees_shown(str(job.get("inst", ""))):
		var sees: Dictionary = job.get("sees", {})
		if str(sees.get("line", "")) != "":
			pages.append({"text": str(sees.line),
				"name": _npc_name(head), "portrait": _portrait(head)})
			_log_work("sees", str(job.get("inst", "")), 0)
	var customer := str(enc.get("customer", head))
	var btns: Array = []
	var picks: Array = enc.get("choices", [])
	for i in picks.size():
		btns.append([str(picks[i][0]), work_pick.bind(i)])
	pages.append({"text": str(enc.get("setup", "")), "choices": btns})
	m.dialog.open_seq(_npc_name(customer), _portrait(customer), pages)


# 반응 줄은 「화자: 대사」 꼴 — 화자 이름으로 초상을 고르고 대사만 보여 준다.
# 화자를 못 알아보면(서술문 등) 주인 초상에 줄 전체를 그대로 둔다
func _split_speaker(line: String, boss: String, customer: String) -> Array:
	var cut := line.find(": ")
	if cut > 0 and cut <= 8 and not line.left(cut).contains(" "):
		var who := line.left(cut)
		var said := line.substr(cut + 2).strip_edges()
		var nid := str(SPEAKER_ALIAS.get(who, ""))
		if nid == "":
			for cand: String in [boss, customer] + GameData.NPC_CALLS.keys():
				var nm := _npc_name(cand)
				if nm == who or nm.begins_with(who) or who.begins_with(nm):
					nid = cand
					break
		if nid != "":
			return [nid, said]
	return [boss, line]


func work_pick(i: int) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var job := _job()
	var inst := str(job.get("inst", ""))
	var head := str(job.get("boss", ""))
	var enc := _encounter()
	var picks: Array = enc.get("choices", [])
	if picks.is_empty():
		return
	i = clampi(i, 0, picks.size() - 1)
	var pick: Array = picks[i]
	var customer := str(enc.get("customer", head))
	_me_add("perf", 1)
	_me_add("wage_pending", GameData.CLERK_WAGE)
	_log_work("work", inst, i)
	GameData.aff_add(customer, 1)
	# 정답은 없다 — 다만 주인과의 사이는 조금 오르내린다 (§7.3 「직장 정치」)
	GameData.aff_add(head, int(pick[2]) if pick.size() > 2 else 0)
	# 근무일 평판 +0.2 — 다섯 번마다 +1 로 정수를 지킨다 (D10)
	if _me_int("perf") % 5 == 0:
		_rep_add(1)
	var sp := _split_speaker(str(pick[1]), head, customer)
	var who := str(sp[0])
	m.dialog.open(_npc_name(who), str(sp[1]), [["대화 끝", null]], _portrait(who))
	m.saveio.save_now()


# 「봉급 받기」 — 주인 앞에서만 돈이 손에 들어온다. 다음 봉급날은 이레씩 미룬다
func collect_wage() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	if not wage_ready():
		return
	var job := _job()
	var head := str(job.get("boss", ""))
	var amt := _me_int("wage_pending")
	GameData.money += amt
	GameData.today_earned += amt
	GameData.me["wage_pending"] = 0
	var wd := _me_int("wage_day")
	while wd <= GameData.day:
		wd += 7
	GameData.me["wage_day"] = wd
	m.dialog.open(_npc_name(head), str(_wage_lines(job).get("pay", "이번 주 몫이야. 수고했네.")),
		[["대화 끝", null]], _portrait(head))
	m.saveio.save_now()


# 도서관 「책 읽기 — 하루 한 권」 (헌법 §7.1 books_read). 버튼은 D19 대로 게스트에게
# 회색이지만, 몸통에서도 한 번 더 막는다
func read_book() -> void:
	if Net.is_guest():
		return
	if GameData.read_on(GameData.day):
		m.dialog.open("도서관", "오늘은 이미 읽었다.", [["나가기", null]])
		return
	_me_add("books_read", 1)
	_log_work("read", "library", 0)
	m.dialog.open(_npc_name("librarian"), "오늘은 이 책이에요.",
		[["나가기", null]], _portrait("librarian"))
	m.saveio.save_now()


# ---- 잡화점 선반 (좀도둑) ----

# 선반 E 를 가로챈다 — 대범함이 낮 좀도둑 문턱(45)에 닿은 사람에게만 「슬쩍한다」가
# 보인다(계약서 §5·D13). 그 아래에서는 false 를 돌려 기존 구매 흐름이 그대로다 —
# 선반은 씨앗·레시피를 사는 가장 잦은 길이라, 사려는 사람에게 클릭 하나를 더 시키지
# 않으려고(「보통이죠」25 로 시작한 사람이 선반마다 「물건 보기」를 한 번 더 누르던 것).
# shelf_gray_day 는 shoplift 몸통의 guard 가 말한다
func shelf_menu(si: int) -> bool:
	if Net.is_guest():
		return false
	if _me_int("boldness_base", -1) == -1 \
			or GameData.boldness() < int(GameData.GATE.get("shelf_day", 45)):
		return false
	var theft: Dictionary = GameData.SOCIETY_LINES.theft
	var label := str(theft.get("shelf_choice", "슬쩍한다"))
	var steal: Array
	if si == 0:
		steal = [label, shoplift.bind(si)]
	else:
		steal = gray(label, "손댈 것이 없다.")   # 씨앗 선반만 손이 닿는다 (D13)
	m.dialog.open("선반", "무엇을 할까.", [
		["물건 보기", _shelf_buy.bind(si)],
		steal,
		["그만둔다", null],
	])
	return true


func _shelf_buy(si: int) -> void:
	m.dialog.close()
	var shelf: Array = m.shop_room.SHELVES[si]
	m.shop.open("buy", ["buy"], "잡화점 — %s" % str(shelf[1]), str(shelf[0]))


# 씨앗 한 봉지를 슬쩍한다. 만수가 노점에 가 있으면 본 사람이 없어 기억도 안 남는다 (D23)
func shoplift(si: int, roll := -1.0) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var theft: Dictionary = GameData.SOCIETY_LINES.theft
	if GameData.boldness() < int(GameData.GATE.get("shelf_day", 45)):
		m.dialog.open("선반", str(theft.get("shelf_gray_day", "손이 안 나간다")), [["그만둔다", null]])
		return
	if si != 0 or GameData.shop_seeds.is_empty():
		m.dialog.open("선반", "손댈 것이 없다.", [["그만둔다", null]])
		return
	var id := str(GameData.shop_seeds[posmod(GameData.day + si, GameData.shop_seeds.size())])
	var w := 0 if GameData.merchant_at_stall() else 1
	var p: float = GameData.theft_p(0.35, false, w)
	var value: int = GameData.seed_price(id)
	if _roll(roll) < p:
		GameData.seeds[id] = int(GameData.seeds.get(id, 0)) + 1
		var stolen: Dictionary = GameData.me.get("stolen", {})
		stolen[id] = int(stolen.get(id, 0)) + 1
		GameData.me["stolen"] = stolen
		GameData.me["theft_xp"] = float(GameData.me.get("theft_xp", 0.0)) + 6.0
		GameData.bold_add(2.0)
		if w == 1:
			_remember("shoplift", "merchant", ["merchant"], value, _tells("merchant"))
		m.dialog.open("", str(theft.shelf_ok[posmod(GameData.day, 3)]), [["자리를 뜬다", null]])
	else:
		GameData.me["theft_xp"] = float(GameData.me.get("theft_xp", 0.0)) + 2.0
		GameData.bold_add(1.0)
		GameData.aff_add("merchant", -10)
		_remember("shoplift", "merchant", ["merchant"], value, true)
		m.dialog.open(_npc_name("merchant"), str(theft.shelf_fail[posmod(GameData.day, 3)]),
			[["나간다", _shelf_kick]], _portrait("merchant"))
	m.saveio.save_now()


# 들킨 손님은 가게 밖으로 — 문 앞 한 칸 아래에 세운다
func _shelf_kick() -> void:
	m.dialog.close()
	m.shop_room.close()
	m.player.position.y += m.TILE


# ---- 소매치기 ----

# 근처에서 보고 있는 사람들 — 가까운 순, 여덟까지. 연출 중인 사람은 세지 않는다
func _witnesses(nid: String) -> Array:
	var near: Array = []
	for n in m.npcs:
		if not n.visible or n.scripted or n.id == nid:
			continue
		var d: float = (n.position - m.player.position).length()
		if d <= 6.0 * m.TILE:
			near.append([d, str(n.id)])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array = []
	for pair in near:
		out.append(pair[1])
		if out.size() >= 8:
			break
	return out


func pickpocket(nid: String, roll := -1.0) -> void:
	if Net.is_guest():
		return
	var theft: Dictionary = GameData.SOCIETY_LINES.theft
	if _me_int("boldness_base", -1) == -1 \
			or GameData.boldness() < int(GameData.GATE.get("pickpocket", 20)):
		m.dialog.close()
		m.dialog.open("", str(theft.get("pickpocket_gray", "손이 안 나간다")), [["대화 끝", null]])
		return
	m.dialog.close()
	var witnesses := _witnesses(nid)
	var p: float = GameData.theft_p(0.25, GameData.is_evening(), witnesses.size())
	var pages: Array = []
	if _roll(roll) < p:
		var w: int = GameData.wallet_of(nid)
		var take: int = mini(w, 10 + 3 * GameData.theft_lv())
		GameData.npc_wallet[nid] = w - take
		GameData.money += take
		GameData.today_earned += take
		GameData.me["theft_xp"] = float(GameData.me.get("theft_xp", 0.0)) + 6.0
		GameData.bold_add(2.0)
		# 본 사람이 있을 때만 기억이 남는다 — 혼자였다면 어디에도 없던 일 (D23)
		if not witnesses.is_empty():
			var reported := false
			for wid: String in witnesses:
				if _tells(wid):
					reported = true
			_remember("pickpocket", nid, witnesses, maxi(take, 20), reported)
		pages.append({"text": str(theft.pickpocket_ok[posmod(GameData.day, 3)])})
	else:
		GameData.me["theft_xp"] = float(GameData.me.get("theft_xp", 0.0)) + 2.0
		GameData.bold_add(1.0)
		GameData.aff_add(nid, -10)
		_remember("pickpocket", nid, [nid] + witnesses, 20, true)
		pages.append({"text": str(theft.pickpocket_fail[posmod(GameData.day, 3)])})
	# 목격자가 있으면 그 사람의 한마디가 한 페이지 더
	if not witnesses.is_empty():
		var wid := str(witnesses[0])
		pages.append({"text": str(theft.witness[posmod(GameData.day, 3)]),
			"name": _npc_name(wid), "portrait": _portrait(wid)})
	pages[-1]["choices"] = [["자리를 뜬다", null]]
	m.dialog.open_seq("", null, pages)
	m.saveio.save_now()


# 기억 한 줄 — 「누가 봤는가」만 적는다. 저장은 부른 쪽이 한 번에 한다
func _remember(kind: String, target: String, witnesses: Array, value: int,
		reported: bool) -> void:
	var mems: Array = GameData.me.get("memories", [])
	mems.append({
		"day": GameData.day, "kind": kind, "heat": 1, "region": "kyojin",
		"witnesses": witnesses.duplicate(), "forgiven": false, "target": target,
		"value": value, "reported_day": GameData.day if reported else 0, "settled": "",
	})
	while mems.size() > GameData.MEMORY_MAX:
		mems.pop_front()
	GameData.me["memories"] = mems


# ---- 이장의 마을 회의·봉사 (헌법 §4.6 「낯익음의 자비」) ----

# 신고됐는데 아직 매듭짓지 않은 기억 중 가장 오래된 것
func _pending_mem() -> Dictionary:
	for mem: Dictionary in GameData.me.get("memories", []):
		if int(mem.get("reported_day", 0)) > 0 and str(mem.get("settled", "")) == "":
			return mem
	return {}


func _option(key: String) -> Dictionary:
	for o: Dictionary in GameData.SOCIETY_LINES.meeting.options:
		if str(o.key) == key:
			return o
	return {}


func open_council() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var mem := _pending_mem()
	if mem.is_empty():
		return
	var pay := int(mem.get("value", 0)) * 2
	var victim := _npc_name(str(mem.get("target", "")))
	var pay_label := "%s — %dG" % [str(_option("pay").get("text", "")), pay]
	var pay_btn: Array = gray(pay_label, "그만한 돈이 없다.")
	if GameData.money >= pay:
		pay_btn = [pay_label, council_pick.bind("paid")]
	var btns: Array = [
		pay_btn,
		[str(_option("deny").get("text", "")), council_pick.bind("denied")],
		[str(_option("confess").get("text", "")), council_pick.bind("confessed")],
	]
	m.dialog.open_seq(_npc_name("chief"), _portrait("chief"), [
		{"text": str(GameData.SOCIETY_LINES.meeting["open"]).format({"victim": victim}), "choices": btns},
	])


func council_pick(kind: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var mem := _pending_mem()
	if mem.is_empty():
		return
	var opt: Dictionary
	match kind:
		"paid":
			var pay := int(mem.get("value", 0)) * 2
			if GameData.money < pay:
				return
			GameData.money -= pay
			mem["forgiven"] = true
			mem["settled"] = "paid"
			mem["settled_day"] = GameData.day   # 다음날 아침 outcome·「어제 일은 갚았다」 줄의 재료
			_rep_add(-3)
			GameData.aff_add(str(mem.get("target", "")), 2)
			opt = _option("pay")
		"denied":
			mem["settled"] = "denied"
			mem["settled_day"] = GameData.day
			_rep_add(-5)
			GameData.me["rumor_day"] = GameData.day
			opt = _option("deny")
		"confessed":
			mem["settled"] = "confessed"
			mem["settled_day"] = GameData.day
			var rec: Array = GameData.me.get("record", [])
			rec.append({"day": GameData.day, "crime": str(mem.get("kind", "")),
				"court": "village", "verdict": "service", "sentence": 3,
				"served": 0, "served_day": 0, "expunged": false})
			GameData.me["record"] = rec
			GameData.bold_add(-5.0)
			opt = _option("confess")
		_:
			return
	m.dialog.open(_npc_name("chief"), str(opt.get("chief", "")),
		[["대화 끝", null]], _portrait("chief"))
	m.saveio.save_now()


# 「오늘 봉사」 — 하루 한 번, 기력 −20 · 시계 +60분(17시를 넘겨 되감지는 않는다, D14)
func serve_day() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var rec: Dictionary = GameData.service_pending()
	if rec.is_empty() or int(rec.get("served_day", 0)) == GameData.day:
		return
	rec["served"] = int(rec.get("served", 0)) + 1
	rec["served_day"] = GameData.day
	_me_add("service_days", 1)
	GameData.energy = maxf(0.0, GameData.energy - 20.0)
	GameData.minutes = maxf(GameData.minutes,
		minf(GameData.minutes + 60.0, GameData.SERVICE_LAST_HOUR * 60.0))
	var served := int(rec.get("served", 0))
	if served >= int(rec.get("sentence", 3)):
		for mem: Dictionary in GameData.me.get("memories", []):
			if str(mem.get("settled", "")) == "confessed":
				mem["forgiven"] = true
		_rep_add(3)
		m.dialog.open("", str(GameData.SOCIETY_LINES.meeting.forgiven), [["대화 끝", null]])
	else:
		m.dialog.open(_npc_name("chief"), "고맙네. %s째구먼." % GameData.days_kor(served),
			[["대화 끝", null]], _portrait("chief"))
	m.saveio.save_now()
