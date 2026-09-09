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
	# (c) 파출소 — 내 순찰 지점 찍기, 그리고 박 순경이 나를 잡는 순간
	_patrol_tick()
	_arrest_tick(delta)


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
	GameData.rep_add(d)


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


# 채용이 되는가 — 빈 문자열이면 된다, 아니면 주인이 거절하는 말. 점원은 기관의 기본 직업이다
func can_hire(inst: String) -> String:
	return can_hire_job(str(_inst_def(inst).get("job", "")))


# 직업 하나의 채용 판정. 순서가 뜻이다: 손님·문 안 연 가게·자리·겸업·대기·호감·평판·전과·손·책
# (D6, 부록 §3). 기관직(kind office)은 헌법 §7.1 대로 rep ≥ 20 과 미말소 전과 0 을 더 본다 —
# 면사무소 창구는 story9 가 끝나야 열려 있다(npc_open 이 아니라 tax_open)
func can_hire_job(job_id: String) -> String:
	if Net.is_guest():
		return "손님은 안 쓰네."
	var job: Dictionary = GameData.JOBS.get(job_id, {})
	var inst := str(job.get("inst", ""))
	var idef := _inst_def(inst)
	if job.is_empty() or idef.is_empty():
		return "그런 자리는 없네."
	var head := str(idef.get("head", ""))
	var office := str(job.get("kind", "")) == "office"
	if (not GameData.tax_open()) if office else (not GameData.npc_open(head)):
		return "가게부터 열어야지."
	if GameData.seat_of(inst, str(job.get("rank", ""))) != "":
		return "자리가 안 비었네."
	var lines: Dictionary = job.get("hire", {})
	if str(GameData.me.get("job", "")) != "":
		return str(lines.get("refuse_busy", "일자리는 하나만 갖게."))
	# 그만둔 지 이레 안 — refuse_busy(「이미 다른 데서 일하잖아」)는 무직자에게 사실과 어긋난다
	var hist: Array = GameData.me.get("job_history", [])
	if not hist.is_empty() and GameData.day - int(hist[-1].get("to", 0)) < 7:
		return "그만둔 지 이레도 안 됐잖나."
	if GameData.aff(head) < 20:
		return str(lines.get("refuse_aff", "아직 자네를 잘 몰라서 말이야."))
	if office:
		var rep: Dictionary = GameData.me.get("reputation", {})
		if int(rep.get("kyojin", 0)) < int(job.get("req_rep", 20)):
			return str(lines.get("refuse_rep", "마을에 자네 얘기가 좀 더 좋게 돌아야 하네."))
		# 미말소 전과 — 마을 회의(court village)의 봉사 판결은 전과로 안 본다(직업 설계서)
		for rec in GameData.me.get("record", []):
			if rec is Dictionary and not bool(rec.get("expunged", false)) \
					and str(rec.get("court", "")) != "village":
				return str(lines.get("refuse_record", "전과가 있는 사람한테는 못 맡기네."))
	var skill := str(job.get("skill", ""))
	if skill != "" and GameData.skill_lv(skill) < int(job.get("skill_lv", 2)):
		return str(lines.get("refuse_skill", "손이 아직 서툴러. 좀 더 해 보고 오게."))
	# 순경은 대범함 문턱이 있다(헌법 §7.1 순경 boldness 35) — 성격을 아직 안 물었으면 0 으로 센다
	if int(job.get("boldness", 0)) > 0 and GameData.boldness() < int(job.get("boldness", 0)):
		return str(lines.get("refuse_bold", "밤길이 무섭지 않다고 했나. 자네 눈은 아직 아닐세."))
	if int(job.get("books", 0)) > _me_int("books_read"):
		return str(lines.get("refuse_skill", "책 세 권은 읽고 오게."))
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
	# 기관직(면사무소)은 광장이 아니라 창구에서 「일하고 싶습니다」다(헌법 §7.1) — 이장의 광장
	# 대화에는 끼우지 않는다. 회의·봉사·성격 질문이 이미 이장의 몫이다
	if inst != "" and str(_inst_def(inst).get("room", "")) == "hall":
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
	# 순경(S2b) — 열린 사건의 피해자·목격자에게 「사건 이야기」, 용의자에게 「검거한다」
	if nid != "chief" and not guest:
		_case_choices(nid, choices)


# 하루 첫 대화의 첫마디 — 호칭이 NPC 의 입으로 나오는 자리 (헌법 §0.4).
# 빈 문자열이면 village_ui 가 별도 페이지를 만들지 않는다 (D1)
func talk_opener(nid: String, first_today: bool) -> String:
	if not first_today or not GameData.affinity_open or Net.is_guest():
		return ""
	# 네 주 밀린 세금 — 이장의 첫마디는 인사가 아니라 독촉이다(헌법 §2.3, 하루 한 번)
	if nid == "chief" and GameData.tax_dun_active():
		return "자네, 세금 얘기 좀 하세. 마을이 보고 있네. 면사무소로 오게."
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

# 「일자리 이야기」 — 기관의 기본 직업(점원)으로. 면사무소는 직업이 둘이라 open_job_talk_job 으로 간다
func open_job_talk(inst: String) -> void:
	open_job_talk_job(str(_inst_def(inst).get("job", "")))


# 내가 먼저 묻고(hire.ask) 주인이 답한다. 거절 사유는 can_hire_job 이 고른다.
# back 이 있으면 거절·보류 뒤 그 창으로 돌아간다(면사무소 창구)
func open_job_talk_job(job_id: String, back := Callable()) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var job: Dictionary = GameData.JOBS.get(job_id, {})
	var head := str(job.get("boss", ""))
	var lines: Dictionary = job.get("hire", {})
	var ask := str(lines.get("ask", ""))
	var pages: Array = []
	if ask != "":
		pages.append({"text": ask, "name": _my_name(), "portrait": null})
	var why := can_hire_job(job_id)
	var later: Variant = back if back.is_valid() else null
	if why != "":
		pages.append({"text": why, "choices": [["알겠습니다", later]]})
	else:
		pages.append({"text": str(lines.get("accept", "내일 아침 나오게.")), "choices": [
			["하겠습니다", hire_job.bind(job_id)],
			["생각해 보겠습니다", later],
		]})
	m.dialog.open_seq(_npc_name(head), _portrait(head), pages)


# 자리가 진실이다(헌법 §0.1) — seats 에 "player" 를 앉히는 것이 채용이고, me.job 은 그 그림자
func hire(inst: String) -> void:
	hire_job(str(_inst_def(inst).get("job", "")))


func hire_job(job_id: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var job: Dictionary = GameData.JOBS.get(job_id, {})
	if job.is_empty():
		return
	var inst := str(job.get("inst", ""))
	var rank := str(job.get("rank", ""))
	var rows: Dictionary = GameData.seat_rows(inst)
	if not rows.has(rank) or not (rows[rank] is Array) or rows[rank].is_empty():
		return
	rows[rank][0] = "player"
	GameData.me["job"] = job_id
	GameData.me["rank"] = rank
	GameData.me["job_since_day"] = GameData.day + 1      # 내일 아침부터
	GameData.me["wage_day"] = GameData.day + 8           # 첫 봉급날 = 첫 근무 이레 뒤
	GameData.me["perf"] = 0
	GameData.me["absent_days"] = 0
	GameData.me["wage_pending"] = 0
	var head := str(job.get("boss", ""))
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
	var rank := str(job.get("rank", ""))
	var rows: Dictionary = GameData.seat_rows(inst)
	if rows.has(rank) and rows[rank] is Array and rows[rank].size() > 0 \
			and str(rows[rank][0]) == "player":
		rows[rank][0] = ""
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

# 지금 이 방에서 근무할 수 있는가 — 빈 문자열이면 된다. room_id 를 안 주면 지금 들어가 있는 가게
func can_work(room_id := "") -> String:
	if Net.is_guest():
		return "손님은 일하지 않는다."
	if str(GameData.me.get("job", "")) == "":
		return "맡은 일이 없다."
	var here := room_id if room_id != "" else str(m.shop_room.room_id)
	if str(_inst_def(GameData.job_inst()).get("room", "")) != here:
		return "여긴 내 일터가 아니다."
	if GameData.day < _me_int("job_since_day"):
		return "내일부터다."
	var h := GameData.hour_now()
	var close_h: float = 24.0 if int(_job().get("night_bonus", 0)) > 0 else GameData.CLOSE_HOUR
	if h < GameData.OPEN_HOUR or h >= close_h:
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
		if GameData.wage_frozen():
			btns.append(gray("봉급 받기", "밀린 세금부터 내게. 그 전엔 봉급이 없네."))
		elif _me_int("wage_pending") <= 0:
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
func work_start(room_id := "") -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var job := _job()
	var head := str(job.get("boss", ""))
	var why := can_work(room_id)
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
	# 일급은 직업표대로(점원 80 · 서기 100 · 감시원 110). 여섯 주 밀린 세금이면 봉급이
	# 멈춘다 — 근무는 인정되고(결근이 아니다) 몫만 적히지 않는다(헌법 §2.3 직위해제)
	if not GameData.wage_frozen():
		_me_add("wage_pending", int(job.get("wage", GameData.CLERK_WAGE)))
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
	if not wage_ready() or GameData.wage_frozen():
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
			# 파출소가 있고 본 사람이 있으면 부인은 끝이 아니다 — 이장이 파출소로 넘긴다(헌법 §6.3).
			# 흔적(목격 1.0)이 좀도둑의 기소 문턱(1.0)에 닿으므로 박 순경이 나를 쫓기 시작한다
			var wit: Variant = mem.get("witnesses", [])
			if GameData.police_open() and wit is Array and not wit.is_empty():
				GameData.me["wanted"] = {"day": int(mem.get("day", 0)), "kind": str(mem.get("kind", "")),
					"target": str(mem.get("target", "")), "value": int(mem.get("value", 0)),
					"fine": maxi(GameData.FINE_MIN, int(mem.get("value", 0)) * GameData.FINE_MULT),
					"since": GameData.day}
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


# ---- 면사무소 창구 (회관 · S2a) ----
#
# 세금은 「내러 가는 행위」다(헌법 §2.2) — 고지서는 편지로 오고, 돈은 여기 창구에서 E 로만
# 나간다. 이장이 면장을 겸한다(읍이 열리기 전까지). 기관직(서기·감시원)의 채용·근무·봉급도
# 이 창구다 — 점원이 주인 계산대에서 하는 일을 공무원은 면사무소에서 한다.

func open_township() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var due := GameData.tax_due_total()
	var body := ""
	if due > 0:
		var w := GameData.arrears_weeks()
		if w == 0:
			# 아직 기한 안 — 밀린 게 아니라 「이번 계절 것」이다
			var last: Dictionary = GameData.unpaid_bills()[-1]
			body += "이번 계절 세금 %dG — 기한은 이 계절 %d일까지\n" \
				% [due, (int(last.get("due_day", GameData.day)) - 1) % GameData.DAYS_PER_SEASON + 1]
		else:
			body += "밀린 세금 %dG — 체납 %d주째, 이자가 붙었다\n" % [due, w]
	elif int(GameData.me.get("tax_paid_season", -1)) == GameData.season_no():
		body += "이번 계절 세금은 냈다. 영수증이 있다.\n"
	else:
		body += "낼 세금이 없다.\n"
	var nxt := GameData.gov_next_project()
	if GameData.gov_building != "":
		body += "「%s」 공사 중 — 다음 계절 첫날 다 된다." \
			% str(GameData.gov_project(GameData.gov_building).get("name", ""))
	elif not nxt.is_empty():
		body += "다음 사업: 「%s」 — %s" % [str(nxt.name), str(nxt.desc).split("\n")[0]]
		if _is_clerk_here():
			body += "\n마을 예산 %dG / 필요 %dG" % [int(GameData.gov_budget.get("kyojin", 0)), int(nxt.cost)]
		else:
			body += "\n예산이 모이는 중이다."
	else:
		body += "계획한 사업은 다 끝났다. 예산은 다음 계획을 기다린다."
	var btns: Array = []
	if due > 0:
		if GameData.money >= due:
			btns.append(["세금 내기 — %dG" % due, _pay_tax])
		else:
			btns.append(gray("세금 내기 — %dG" % due, "그만한 돈이 없다. 모아서 오자."))
	btns.append(["예산 장부", _open_ledger])
	var employed := GameData.job_inst() == "township"
	if employed:
		if can_work("hall") == "":
			btns.append(["근무", work_start.bind("hall")])
		var wl := _wage_lines(_job())
		if GameData.wage_frozen():
			btns.append(gray("봉급 받기", "밀린 세금부터 내게. 그 전엔 봉급이 없네."))
		elif _me_int("wage_pending") <= 0:
			btns.append(gray("봉급 받기", str(wl.get("nothing", "받을 게 없다."))))
		elif GameData.day < _me_int("wage_day"):
			btns.append(gray("봉급 받기", str(wl.get("not_yet", "봉급날은 아직이다."))))
		else:
			btns.append(["봉급 받기 — %dG" % _me_int("wage_pending"), collect_wage])
		btns.append(["그만두겠습니다", resign])
	elif str(GameData.me.get("job", "")) == "":
		btns.append(["일하고 싶습니다", _open_township_jobs])
	btns.append(["돌아가기", m.village._open_hall_dialog])
	m.dialog.open("면사무소 창구", body, btns, _portrait("chief"))


func _is_clerk_here() -> bool:
	return str(GameData.me.get("job", "")) == "township_clerk"


func _pay_tax() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var paid := GameData.pay_tax()
	if paid <= 0:
		open_township()
		return
	Sound.play_sfx("sfx_coin")
	m.dialog.open(_npc_name("chief"),
		"고맙네. 이 돈이 등불이 되고 길이 되는 걸세. 영수증은 챙겨 두게.",
		[["돌아가기", open_township], ["대화 끝", null]], _portrait("chief"))
	m.saveio.save_now()


# 예산 장부 — 실수치는 면 서기만 본다(그 직업이 보는 것). 남한테는 사업 이름만
func _open_ledger() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	if not _is_clerk_here():
		m.dialog.open(_npc_name("chief"),
			"장부는 서기가 보는 걸세. 자네한텐 다음 사업 이름만 말해 주지.",
			[["돌아가기", open_township]], _portrait("chief"))
		return
	var body := "마을 예산: %dG\n" % int(GameData.gov_budget.get("kyojin", 0))
	var nxt := GameData.gov_next_project()
	if GameData.gov_building != "":
		body += "공사 중: 「%s」\n" % str(GameData.gov_project(GameData.gov_building).get("name", ""))
	if not nxt.is_empty():
		body += "다음 사업: 「%s」 %dG — 남은 돈 %dG\n" % [str(nxt.name), int(nxt.cost),
			maxi(0, int(nxt.cost) - int(GameData.gov_budget.get("kyojin", 0)))]
	if not GameData.gov_done.is_empty():
		var names: Array = []
		for pid in GameData.gov_done:
			names.append(str(GameData.gov_project(str(pid)).get("name", pid)))
		body += "다 된 것: %s\n" % " · ".join(PackedStringArray(names))
	var logs: Array = GameData.gov_log
	if not logs.is_empty():
		body += "\n계절 장부"
		for i in range(maxi(0, logs.size() - 4), logs.size()):
			var r: Dictionary = logs[i]
			body += "\n· 교부금 +%d · 장부세 +%d · 세금 +%d · 운영비 −%d" \
				% [int(r.get("grant", 0)), int(r.get("levy", 0)), int(r.get("tax", 0)), int(r.get("ops", 0))]
			if str(r.get("project", "")) != "":
				body += " · 「%s」 착공" % str(GameData.gov_project(str(r.project)).get("name", ""))
	m.dialog.open("예산 장부", body, [["돌아가기", open_township]])


# 「일하고 싶습니다」 — 면사무소의 두 자리 중 하나를 고른다. 거절 사유는 이장이 말한다
func _open_township_jobs() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var btns: Array = []
	for jid in _inst_def("township").get("jobs", []):
		var job: Dictionary = GameData.JOBS.get(str(jid), {})
		if job.is_empty():
			continue
		var taken := GameData.seat_of("township", str(job.get("rank", ""))) != ""
		var label := "%s — 일급 %dG" % [str(job.get("name", jid)), int(job.get("wage", 0))]
		if taken:
			btns.append(gray(label, "그 자리는 비어 있지 않네."))
		else:
			btns.append([label, open_job_talk_job.bind(str(jid), open_township)])
	btns.append(["돌아가기", open_township])
	m.dialog.open(_npc_name("chief"), "어느 일을 하고 싶은가.", btns, _portrait("chief"))


# ---- 압류 집행 (하루 넘김 직후, day_cycle 이 부른다) ----
#
# 여덟 주 밀린 세금은 마을이 대신 가져간다 — 유일한 자동 차감(헌법 §2.3).
# 회관 창고 → 가축 → 소지금 순서. GameData 는 가축 노드를 못 만지므로 세계를 든 여기서 집행한다
func after_new_day() -> void:
	if Net.is_guest() or GameData.tax_seize_due <= 0:
		return
	var due: int = GameData.tax_seize_due
	var got := 0
	var parts: Array = []
	var st: Array = GameData.seize_from_store(due)
	got += int(st[0])
	if str(st[1]) != "":
		parts.append(str(st[1]))
	var taken_animals := {}
	while got < due and not m.animals.is_empty():
		var a: Node2D = m.animals[-1]
		var kind := str(a.type)
		m.animals.erase(a)
		a.queue_free()
		got += int(GameData.ANIMALS.get(kind, {}).get("price", 500))
		taken_animals[kind] = int(taken_animals.get(kind, 0)) + 1
	GameData.animals_now = m.animals.size()
	for kind in taken_animals:
		parts.append("%s %d마리" % [str(GameData.ANIMALS.get(kind, {}).get("name", kind)), int(taken_animals[kind])])
	if got < due:
		var take: int = mini(GameData.money, due - got)
		if take > 0:
			GameData.money -= take
			got += take
			parts.append("소지금 %dG" % take)
	GameData.tax_seized(" · ".join(PackedStringArray(parts)) if not parts.is_empty() else "가져갈 것이 없었다")


# ---- 파출소 (S2b) ----
#
# 순경의 근무는 대화가 아니라 **걷기**다 — 세 지점을 발로 찍고 돌아와 보고한다.
# 박 순경은 저녁에 같은 길을 돌고(밤 목격자), 수배 중인 나를 쫓는다. 체포는 즉결 —
# 벌금(물건값 ×3, 하한 200)이거나 사흘 봉사. 자수하면 절반. 벌금은 마을 예산으로 간다.

# 광장 남쪽 · 게시판 앞 · 서쪽 어귀 (NORTH_PAD 를 더한 실제 칸). 막힌 칸이면 가장 가까운 빈 칸
const PATROL_SPOTS := [Vector2i(78, 37), Vector2i(82, 27), Vector2i(62, 33)]
const PATROL_NAMES := ["광장 남쪽", "게시판 앞", "서쪽 어귀"]
var _patrol_pts: Array = []
var _arrest_t := 0.0


func patrol_points() -> Array:
	if _patrol_pts.is_empty():
		for sp: Vector2i in PATROL_SPOTS:
			var t: Vector2i = m.nearest_open_tile(sp)
			_patrol_pts.append(t if t.x >= 0 else sp)
	return _patrol_pts


func _is_constable() -> bool:
	return str(GameData.me.get("job", "")) == "constable"


# 오늘 순찰이 진행 중인가(시작했고 아직 세 곳을 다 못 찍었다)
func patrol_active() -> bool:
	return _is_constable() and _me_int("patrol_day") == GameData.day and _me_int("patrol_idx") < 3


func patrol_done_today() -> bool:
	return _me_int("patrol_day") == GameData.day and _me_int("patrol_idx") >= 3


func _patrol_tick() -> void:
	if not patrol_active() or m.ui_open():
		return
	var pts := patrol_points()
	var idx := _me_int("patrol_idx")
	var goal: Vector2i = pts[idx]
	var pt: Vector2i = m.player_tile()
	if absi(pt.x - goal.x) <= 1 and absi(pt.y - goal.y) <= 1:
		idx += 1
		GameData.me["patrol_idx"] = idx
		if idx < 3:
			_guide_patrol(idx)
		else:
			m.hud.clear_guide()


func _guide_patrol(idx: int) -> void:
	var t: Vector2i = patrol_points()[idx]
	m.hud.set_guide(Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16), "순찰 %s" % PATROL_NAMES[idx])


func _officer_node() -> Node2D:
	for n in m.npcs:
		if str(n.id) == "officer_park":
			return n
	return null


# 박 순경이 내 곁에 2초 — 체포. 실내·가게 안·연출 중에는 잡지 않는다(문 앞에서 기다린다)
func _arrest_tick(delta: float) -> void:
	if not GameData.wanted_active() or m.ui_open() or not GameData.police_open():
		_arrest_t = 0.0
		return
	var cop := _officer_node()
	if cop == null or not cop.visible:
		_arrest_t = 0.0
		return
	var d: float = (cop.position - m.player.position).length()
	if d <= GameData.ARREST_TILES * float(m.TILE):
		_arrest_t += delta
		if _arrest_t >= GameData.ARREST_SECONDS:
			_arrest_t = 0.0
			arrest(false)
	else:
		_arrest_t = 0.0


# 체포(surrender=false) 또는 자수(true) — 즉결: 벌금이거나 사흘 봉사
func arrest(surrender: bool) -> void:
	if Net.is_guest() or not GameData.wanted_active():
		return
	m.dialog.close()
	var w: Dictionary = GameData.me.get("wanted", {})
	var fine := int(w.get("fine", GameData.FINE_MIN))
	if surrender:
		fine = maxi(1, fine / 2)
	var target := _npc_name(str(w.get("target", "")))
	var text := ("자수하러 왔나. 잘했네. 벌금은 절반으로 하지 — %dG. 아니면 사흘 봉사일세." % fine) if surrender \
		else ("%s 일, 마을이 봤네. 벌금 %dG 이거나 사흘 봉사일세. 고르게." % [target, fine])
	var pay_btn: Array = gray("벌금 %dG 을 낸다" % fine, "그만한 돈이 없다.")
	if GameData.money >= fine:
		pay_btn = ["벌금 %dG 을 낸다" % fine, _arrest_pick.bind("fine", fine, surrender)]
	m.dialog.open_seq(_npc_name("officer_park"), _portrait("officer_park"), [
		{"text": text, "choices": [pay_btn, ["사흘 봉사를 한다", _arrest_pick.bind("service", fine, surrender)]]},
	])


func _arrest_pick(kind: String, fine: int, surrender: bool) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var w: Dictionary = GameData.me.get("wanted", {})
	# 그 일의 기억을 찾아 매듭짓는다 — 본 사람들이 다시 이름을 부른다(forgiven)
	var mem: Dictionary = {}
	for cand: Dictionary in GameData.me.get("memories", []):
		if int(cand.get("day", -1)) == int(w.get("day", -2)) and str(cand.get("target", "")) == str(w.get("target", "")):
			mem = cand
	var line := ""
	if kind == "fine":
		if GameData.money < fine:
			return
		GameData.money -= fine
		GameData.today_spent += fine
		GameData.gov_budget["kyojin"] = int(GameData.gov_budget.get("kyojin", 0)) + fine
		if not mem.is_empty():
			mem["settled"] = "fined"
			mem["forgiven"] = true
		line = "받았네. 이 돈은 마을 예산으로 가네. 다음엔 없는 걸세."
	else:
		if not mem.is_empty():
			mem["settled"] = "confessed"
		var rec: Array = GameData.me.get("record", [])
		rec.append({"day": GameData.day, "crime": str(w.get("kind", "")), "court": "village",
			"verdict": "service", "sentence": 3, "served": 0, "served_day": 0, "expunged": false})
		GameData.me["record"] = rec
		line = "사흘일세. 이장한테 가서 빗자루를 받게. 그걸로 끝일세."
	_rep_add(-2 if surrender else -5)
	GameData.me["wanted"] = {}
	m.dialog.open(_npc_name("officer_park"), line, [["대화 끝", null]], _portrait("officer_park"))
	m.saveio.save_now()


# ---- 파출소 창구 ----

func open_police() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	if not GameData.npc_greeted.has("officer_park"):
		m.dialog.open("파출소", "아직 아무도 없다. 부임하는 사람이 오면 문을 열 것이다.", [["나간다", null]])
		return
	if GameData.wanted_active():
		arrest(true)   # 수배 중에 제 발로 왔다 — 자수
		return
	var body := "박 순경이 순찰 일지를 넘기고 있다.\n"
	var opens := GameData.open_cases()
	if opens.is_empty():
		body += "요즘 마을은 조용하다."
	else:
		body += "열린 사건 %d건." % opens.size()
	var btns: Array = []
	var employed := GameData.job_inst() == "police_box"
	if employed:
		if patrol_done_today():
			btns.append(["순찰 보고", patrol_report])
		elif patrol_active():
			btns.append(gray("순찰 보고", "아직 %s을 안 찍었다." % PATROL_NAMES[_me_int("patrol_idx")]))
		elif can_work("inn") == "":
			btns.append(["근무 — 순찰", patrol_start])
		for c in opens:
			var cid := int(c.get("id", 0))
			btns.append(["출동 — %s네 도둑 (흔적 %d/%d)" % [_npc_name(str(c.get("victim", ""))),
				int(c.get("evidence", 0)), GameData.NEED_EVIDENCE], _open_case.bind(cid)])
		var wl := _wage_lines(_job())
		if GameData.wage_frozen():
			btns.append(gray("봉급 받기", "밀린 세금부터 내게. 그 전엔 봉급이 없네."))
		elif _me_int("wage_pending") <= 0:
			btns.append(gray("봉급 받기", str(wl.get("nothing", "받을 게 없다."))))
		elif GameData.day < _me_int("wage_day"):
			btns.append(gray("봉급 받기", str(wl.get("not_yet", "봉급날은 아직이다."))))
		else:
			btns.append(["봉급 받기 — %dG" % _me_int("wage_pending"), collect_wage])
		btns.append(["그만두겠습니다", resign])
	elif str(GameData.me.get("job", "")) == "":
		btns.append(["일하고 싶습니다", open_job_talk_job.bind("constable", open_police)])
	btns.append(["나간다", null])
	m.dialog.open(_npc_name("officer_park"), body, btns, _portrait("officer_park"))


func patrol_start() -> void:
	if Net.is_guest() or not _is_constable():
		return
	m.dialog.close()
	var why := can_work("inn")
	if why != "":
		m.dialog.open(_npc_name("officer_park"), why, [["알겠습니다", null]], _portrait("officer_park"))
		return
	GameData.me["patrol_day"] = GameData.day
	GameData.me["patrol_idx"] = 0
	_guide_patrol(0)
	var job := _job()
	var pages: Array = []
	if GameData.day == _me_int("job_since_day"):
		pages.append({"text": str(job.get("hire", {}).get("first_day", ""))})
	var starts: Array = job.get("patrol", {}).get("start", ["다녀오게."])
	pages.append({"text": str(starts[posmod(GameData.day, starts.size())])})
	m.dialog.open_seq(_npc_name("officer_park"), _portrait("officer_park"), pages)


# 세 곳을 다 찍고 돌아왔다 — 근무 인정. 19시 뒤면 밤 몫이 붙는다
func patrol_report() -> void:
	if Net.is_guest() or not _is_constable() or not patrol_done_today() \
			or GameData.worked_on(GameData.day):
		return
	m.dialog.close()
	var job := _job()
	var night: bool = GameData.hour_now() >= 19.0
	var wage := int(job.get("wage", GameData.CLERK_WAGE)) + (int(job.get("night_bonus", 0)) if night else 0)
	_me_add("perf", 1)
	if not GameData.wage_frozen():
		_me_add("wage_pending", wage)
	_log_work("work", "police_box", 1 if night else 0)
	if _me_int("perf") % 5 == 0:
		_rep_add(1)
	var lines: Array = job.get("patrol", {}).get("report", ["수고했네."])
	var text := str(job.get("patrol", {}).get("night", "")) if night else str(lines[posmod(GameData.day, lines.size())])
	m.dialog.open(_npc_name("officer_park"), text, [["대화 끝", null]], _portrait("officer_park"))
	m.saveio.save_now()


# 출동 — 사건의 흔적은 사람에게서 나온다: 피해자에게 묻고, 목격자에게 묻고, 용의자를 잡는다
func _open_case(cid: int) -> void:
	m.dialog.close()
	var c := GameData.case_by_id(cid)
	if c.is_empty():
		return
	var asked: Array = GameData.me.get("case_asked", {}).get(str(cid), [])
	var body := "%s네에 도둑이 들었다.\n" % _npc_name(str(c.get("victim", "")))
	body += "흔적 %d/%d — " % [int(c.get("evidence", 0)), GameData.NEED_EVIDENCE]
	if asked.is_empty():
		body += "먼저 %s에게 가서 물어보자." % _npc_name(str(c.get("victim", "")))
	elif int(c.get("evidence", 0)) < GameData.NEED_EVIDENCE:
		body += "누가 봤는지 마을 사람들에게 더 물어보자."
	else:
		body += "%s가 범인이다. 가서 검거하자." % _npc_name(str(c.get("suspect", "")))
	m.dialog.open(_npc_name("officer_park"), body, [["알겠습니다", open_police]], _portrait("officer_park"))


func _case_choices(nid: String, choices: Array) -> void:
	if not _is_constable():
		return
	for c in GameData.open_cases():
		var cid := int(c.get("id", 0))
		var asked: Array = GameData.me.get("case_asked", {}).get(str(cid), [])
		var vname := _npc_name(str(c.get("victim", "")))
		if (nid == str(c.get("victim", "")) or nid == str(c.get("witness", ""))) and nid not in asked:
			choices.insert(choices.size() - 1, ["사건 이야기 — %s네 도둑" % vname, case_ask.bind(cid, nid)])
		elif nid == str(c.get("suspect", "")) and int(c.get("evidence", 0)) >= 1:
			choices.insert(choices.size() - 1, ["검거한다 — %s네 도둑" % vname, case_arrest.bind(cid, nid)])


func case_ask(cid: int, nid: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var c := GameData.case_by_id(cid)
	if c.is_empty() or str(c.get("stage", "")) != "open":
		return
	var asked_all: Dictionary = GameData.me.get("case_asked", {})
	var asked: Array = asked_all.get(str(cid), [])
	if nid in asked:
		return
	asked.append(nid)
	asked_all[str(cid)] = asked
	GameData.me["case_asked"] = asked_all
	c["evidence"] = int(c.get("evidence", 0)) + 1
	var line := ""
	if nid == str(c.get("victim", "")):
		line = "밤에 문소리가 났어요. 창고에서 뭔가 없어졌고요. 누군지는 못 봤어요."
	else:
		line = "그날 밤 %s가 그 집 근처에서 서성이는 걸 봤어요. 이상하다 했죠." % _npc_name(str(c.get("suspect", "")))
	m.dialog.open(_npc_name(nid), line, [["대화 끝", null]], _portrait(nid))
	m.saveio.save_now()


# 검거 — 흔적이 둘이면 성공(실적·평판 +2), 하나면 무고(평판 −5·그 사람 호감도 −10)
func case_arrest(cid: int, nid: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var c := GameData.case_by_id(cid)
	if c.is_empty() or str(c.get("stage", "")) != "open" or nid != str(c.get("suspect", "")):
		return
	if int(c.get("evidence", 0)) >= GameData.NEED_EVIDENCE:
		GameData._case_convict(c, "player")
		_me_add("arrests", 1)
		_rep_add(2)
		GameData.aff_add(nid, -20)
		m.dialog.open(_npc_name(nid), "…알았소. 같이 가지. 손은 안 대도 되네.", [["파출소로 데려간다", null]], _portrait(nid))
	else:
		_rep_add(-5)
		GameData.aff_add(nid, -10)
		m.dialog.open(_npc_name(nid), "나를? 무슨 근거로! 마을 사람들이 다 보고 있네.", [["…물러선다", null]], _portrait(nid))
	m.saveio.save_now()
