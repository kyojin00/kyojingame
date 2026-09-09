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
	if not GameData.affinity.has(nid):
		return m.tex.get("npc_%s_portrait_normal" % nid)   # 순회 판사·검사(S2c) — 주민이 아니라 호감도가 없다
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


func _rep_add(d: int, region := "kyojin") -> void:
	GameData.rep_add(d, region)


# 지금 서 있는 땅 — 읍 안이면 "town", 아니면 "kyojin"(고장도 교진의 법이다)
func region_here() -> String:
	return "town" if m.TOWN_RECT.grow(4).has_point(m.player_tile()) else "kyojin"


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
	# 읍은 본 사람이 곧 신고다(0.8, 헌법 §6.2) — 생성 NPC 는 제 snitch 만큼 더·덜
	var base := 0.8 if region_here() == "town" else 0.4
	var snitch := GameData.gen_trait(wid, "snitch") if GameData.gen_npcs.has(wid) else 1.0
	return r < base * snitch * maxf(0.25, 1.0 - float(GameData.aff(wid)) / 200.0)


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
	var office := str(job.get("kind", "")) in ["office", "honor"]   # 명예직(S3c)도 창구·평판·전과를 본다
	# 고장 사람(S3c)은 첫 인사 목록에 없어도 늘 제자리에 있다 — 그 일터는 언제나 열려 있다
	var head_here: bool = GameData.npc_open(head) or head in m.HAMLET_NPC_IDS
	if (not GameData.tax_open()) if office else (not head_here):
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
	if GameData.aff(head) < int(job.get("req_aff", 20)):
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
	# 방 없는 일터(고장 점원 S3c) — 계산대가 없으니 근무·봉급·사직이 그 사람 앞 대화에 선다
	var my_inst := GameData.job_inst()
	if not guest and my_inst != "" and owner_inst(nid) == my_inst \
			and str(_inst_def(my_inst).get("room", "")) == "":
		_talk_work_choices(choices)
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
		# 대면 범죄(S5a) — 문턱 아래면 줄 자체가 없다(부재, 헌법 §5.2). 손이 안 가는 사람은 회색
		var vl: Dictionary = GameData.SOCIETY_LINES.violence
		var bold := GameData.boldness()
		if bold >= int(GameData.GATE.get("violence", 55)):
			var acts: Array = [[str(vl.rob_choice), rob.bind(nid)], [str(vl.assault_choice), assault.bind(nid)]]
			if bold >= int(GameData.GATE.get("murder", 75)):
				acts.append([str(vl.murder_choice), murder.bind(nid)])
			for act: Array in acts:
				if guest:
					choices.insert(choices.size() - 1, gray(str(act[0]), "손님은 이 마을 일에 끼지 않는다."))
				elif not GameData.victim_ok(nid):
					choices.insert(choices.size() - 1, gray(str(act[0]), str(vl.no_target)))
				else:
					choices.insert(choices.size() - 1, act)
	# 순경(S2b) — 열린 사건의 피해자·목격자에게 「사건 이야기」, 용의자에게 「검거한다」
	if nid != "chief" and not guest:
		_case_choices(nid, choices)
	# 장물아비(S4c) — 훔친 것이 가방에 있으면 반값에 넘긴다. 그가 아니면 아무 데도 못 판다
	if nid == "fence_gu" and not guest:
		var fl: Dictionary = GameData.SOCIETY_LINES.fence
		if stolen_value() > 0:
			choices.insert(choices.size() - 1, [str(fl.choice), sell_stolen])
		else:
			choices.insert(choices.size() - 1, gray(str(fl.choice), str(fl.gray)))


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
	# 읍 사건(S4d) — 검사·판사의 책상에 진짜 서류가 있으면 손글 미니루프보다 그것이 먼저다
	var real: Dictionary = GameData.town_case_for(job_id_now())
	if not real.is_empty():
		_work_real_case(real)
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
		_me_add("wage_pending", GameData.job_wage())   # 승진한 자리면 그 자리의 봉급(S4h)
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
		reported: bool, heat := 1) -> void:
	var mems: Array = GameData.me.get("memories", [])
	mems.append({
		"day": GameData.day, "kind": kind, "heat": heat, "region": region_here(),
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
		if str(mem.get("region", "")) == "town":
			continue   # 읍 일은 경찰서로 간다(S4f)
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
	# 벌금 고지서(S2c 재판)는 세금과 같은 창구·같은 사다리다 — 이름만 달리 부른다
	var has_fine := false
	for fb in GameData.unpaid_bills():
		if str(fb.get("kind", "")) == "fine":
			has_fine = true
	var what := "세금·벌금" if has_fine else "세금"
	var body := ""
	if due > 0:
		var w := GameData.arrears_weeks()
		if w == 0:
			# 아직 기한 안 — 밀린 게 아니라 「이번 계절 것」이다
			var last: Dictionary = GameData.unpaid_bills()[-1]
			body += "이번 계절 %s %dG — 기한은 이 계절 %d일까지\n" \
				% [what, due, (int(last.get("due_day", GameData.day)) - 1) % GameData.DAYS_PER_SEASON + 1]
		else:
			body += "밀린 %s %dG — 체납 %d주째, 이자가 붙었다\n" % [what, due, w]
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
			btns.append(["%s 내기 — %dG" % [what, due], _pay_tax])
		else:
			btns.append(gray("%s 내기 — %dG" % [what, due], "그만한 돈이 없다. 모아서 오자."))
	btns.append(["예산 장부", _open_ledger])
	# 상점 허가(S3a) — 인지세 500. 좌판은 하나, 일자리와 겸하지 않는다
	if not GameData.shop_open():
		var why_s := GameData.shop_permit_why()
		var lbl_s := "상점 허가 — %dG" % GameData.SHOP_PERMIT_COST
		btns.append(gray(lbl_s, why_s) if why_s != "" else [lbl_s, open_shop_permit])
	# 전과 말소(S2c) — 인지세. 형이 끝나고 스무여드레 조용히 지낸 뒤에만, 이유는 창구가 말한다
	if GameData.record_unexpunged():
		var why_x := GameData.can_expunge()
		var lbl_x := "전과 말소 — %dG" % GameData.EXPUNGE_COST
		if why_x != "":
			btns.append(gray(lbl_x, why_x))
		elif GameData.money < GameData.EXPUNGE_COST:
			btns.append(gray(lbl_x, "그만한 돈이 없다. 인지세일세."))
		else:
			btns.append([lbl_x, expunge])
	var employed := GameData.job_inst() in ["township", "assoc"]
	if employed:
		var my_job := str(GameData.me.get("job", ""))
		if my_job == "youth_head":
			# 청년회장(S3c) — 근무는 어젯밤의 야경이고, 아침의 보고가 그것을 인정한다
			if GameData.worked_on(GameData.day):
				btns.append(gray("야경 보고", "오늘 보고는 끝났다."))
			elif watch_done_yesterday():
				btns.append(["야경 보고", watch_report])
			else:
				btns.append(gray("야경 보고", "어젯밤 세 군데를 다 돌지 않았다."))
			btns.append(["야경 명부", _watch_roster])
		elif can_work("hall") == "":
			btns.append(["근무", work_start.bind("hall")])
		if my_job == "women_head":
			btns.append(["살림 명부", _women_roster])
		if int(_job().get("wage", 0)) > 0:
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
	# 기관직(면사무소) 뒤에 명예직(자치회, S3c) — 무보수라 일급 대신 「명예직」이라 적는다
	for inst_j: String in ["township", "assoc"]:
		for jid in _inst_def(inst_j).get("jobs", []):
			var job: Dictionary = GameData.JOBS.get(str(jid), {})
			if job.is_empty():
				continue
			var taken := GameData.seat_of(inst_j, str(job.get("rank", ""))) != ""
			var label := ("%s — 명예직, 무보수" % str(job.get("name", jid))) if int(job.get("wage", 0)) <= 0 \
				else "%s — 일급 %dG" % [str(job.get("name", jid)), int(job.get("wage", 0))]
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
# 청년회장의 야경(S3c) — 광장 분수 · 잡화점 앞 · 우체국 앞. 21시부터, 등불 없이
const WATCH_NAMES := ["광장 분수", "잡화점 앞", "우체국 앞"]
const WATCH_HOUR := 21.0
var _patrol_pts: Array = []
var _watch_pts: Array = []
var _arrest_t := 0.0


func patrol_points() -> Array:
	if _patrol_pts.is_empty():
		for sp: Vector2i in PATROL_SPOTS:
			var t: Vector2i = m.nearest_open_tile(sp)
			_patrol_pts.append(t if t.x >= 0 else sp)
	return _patrol_pts


func watch_points() -> Array:
	if _watch_pts.is_empty():
		var spots: Array = [
			Vector2i(m.FOUNTAIN.position.x + 1, m.FOUNTAIN.end.y + 1),
			m.door_tile(m.VILLAGE_PLOTS["general"].anchor) + Vector2i(0, 1),
			m.door_tile(m.VILLAGE_PLOTS["post"].anchor) + Vector2i(0, 1),
		]
		for sp: Vector2i in spots:
			var t: Vector2i = m.nearest_open_tile(sp)
			_watch_pts.append(t if t.x >= 0 else sp)
	return _watch_pts


func _is_constable() -> bool:
	return str(GameData.me.get("job", "")) == "constable"


func _is_youth() -> bool:
	return str(GameData.me.get("job", "")) == "youth_head"


# 지금 직업이 발로 찍는 지점들 — 순경은 낮 순찰, 청년회장은 밤 야경. 아니면 빈 배열
func _spots() -> Array:
	if _is_constable():
		return patrol_points()
	if _is_youth():
		return watch_points()
	return []


func _spot_names() -> Array:
	return WATCH_NAMES if _is_youth() else PATROL_NAMES


# 오늘 순찰(야경)이 진행 중인가(시작했고 아직 세 곳을 다 못 찍었다)
func patrol_active() -> bool:
	return not _spots().is_empty() and _me_int("patrol_day") == GameData.day and _me_int("patrol_idx") < 3


func patrol_done_today() -> bool:
	return _me_int("patrol_day") == GameData.day and _me_int("patrol_idx") >= 3


# 청년회장의 어젯밤 — 세 군데를 다 돌았나(아침 보고의 조건)
func watch_done_yesterday() -> bool:
	return _me_int("patrol_day") == GameData.day - 1 and _me_int("patrol_idx") >= 3


func _patrol_tick() -> void:
	# 야경은 저절로 시작된다 — 21시가 되면 청년회장의 발밑에 첫 핀이 선다(이장은 자고 있다)
	if _is_youth() and GameData.hour_now() >= WATCH_HOUR and _me_int("patrol_day") != GameData.day \
			and GameData.day >= _me_int("job_since_day") and not m.ui_open():
		GameData.me["patrol_day"] = GameData.day
		GameData.me["patrol_idx"] = 0
		_guide_patrol(0)
	if not patrol_active() or m.ui_open():
		return
	var pts := _spots()
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
			if _is_youth():
				GameData.bold_add(3.0, "night")   # 등불 없는 마을을 돈 밤 — 대범함(하루 상한 안에서)


func _guide_patrol(idx: int) -> void:
	var t: Vector2i = _spots()[idx]
	m.hud.set_guide(Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16),
		"%s %s" % ["야경" if _is_youth() else "순찰", _spot_names()[idx]])


func _officer_node() -> Node2D:
	for n in m.npcs:
		if str(n.id) == "officer_park":
			return n
	return null


# 지금 나를 쫓는 순경들 — 박 순경(교진 수배, 또는 heat 3 의 읍 수배)과 읍 순경 셋(읍 수배)
func _cops_after_me() -> Array:
	var out: Array = []
	if not GameData.wanted_active():
		return out
	for n in m.npcs:
		if n.visible and not n.scripted and GameData.society_place(str(n.id)) == "chase":
			out.append(n)
	return out


# 순경이 내 곁에 2초 — 체포. 실내·가게 안·연출 중에는 잡지 않는다(문 앞에서 기다린다)
func _arrest_tick(delta: float) -> void:
	if not GameData.wanted_active() or m.ui_open():
		_arrest_t = 0.0
		return
	var near: Node2D = null
	for cop in _cops_after_me():
		if (cop.position - m.player.position).length() <= GameData.ARREST_TILES * float(m.TILE):
			near = cop
			break
	if near == null:
		_arrest_t = 0.0
		return
	_arrest_t += delta
	if _arrest_t >= GameData.ARREST_SECONDS:
		_arrest_t = 0.0
		if GameData.town_wanted_active():
			arrest_town(str(near.id), false)
		else:
			arrest(false)


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
	var wage := GameData.job_wage() + (int(job.get("night_bonus", 0)) if night else 0)
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


# ---- 빈집 잠입·순회 재판·구류·전과 말소 (S2c) ----
#
# 남의 집 문 앞에서 시작해 피고석에서 끝나는 길. 즉결(순경)은 heat 1 까지고, 빈집(heat 2)은
# 이장의 회의가 아니라 기소다 — 다음 재판일(계절 7·21일)까지 자택 대기, 회관에서 윤 판사가
# 형을 정한다. 형은 셋뿐: 벌금 고지서 / 벌금 + 봉사 이레 / 구류 이레(serve_jail 이 하루를
# 일곱 번 넘긴다 — 밭은 마른다). 돈은 여기서도 창구로만 간다: 벌금은 면사무소 고지서다.

func _lines(key: String) -> Dictionary:
	return GameData.SOCIETY_LINES.get(key, {})


# 정착민의 집 문 앞 — 두드리거나, 몰래 들어가거나. 주인이 안에 있으면(저녁·집 시간) 손이 안 간다
func house_door(nid: String) -> void:
	m.dialog.close()
	var hl := _lines("house")
	var name := _npc_name(nid)
	if Net.is_guest():
		m.dialog.open("%s의 집" % name, str(hl.sign) % name, [["돌아선다", null]])
		return
	var owner_home: bool = GameData.is_evening() or m.npcmgr.npc_place_now(nid) == "home"
	var sneak := str(hl.sneak_choice)
	var sneak_btn: Array
	if _me_int("boldness_base", -1) == -1 or GameData.boldness() < int(GameData.GATE.get("burglary", 35)):
		sneak_btn = gray(sneak, str(hl.gray_bold))
	elif owner_home:
		sneak_btn = gray(sneak, str(hl.gray_home))
	elif GameData.charged_active() or GameData.wanted_active():
		sneak_btn = gray(sneak, str(hl.gray_court))
	else:
		sneak_btn = [sneak, burglary.bind(nid)]
	m.dialog.open("%s의 집" % name, str(hl.sign) % name,
		[[str(hl.knock_choice), _knock.bind(nid, owner_home)], sneak_btn, ["돌아선다", null]])


func _knock(nid: String, owner_home: bool) -> void:
	m.dialog.close()
	var hl := _lines("house")
	if owner_home:
		m.dialog.open("", str(hl.knock_home) % _npc_name(nid), [["돌아선다", null]])
	else:
		m.dialog.open("", str(hl.knock_empty), [["돌아선다", null]])


# 궤짝의 물건 — 주인이 아끼는 것(loves·likes) 중 하나, 날짜로 정해진다
func _house_loot(nid: String) -> String:
	var d := GameData.npc_def(nid)
	var pool: Array = []
	for iid in Array(d.get("loves", [])) + Array(d.get("likes", [])):
		if GameData.ITEMS.has(str(iid)):
			pool.append(str(iid))
	if pool.is_empty():
		return "wood"
	return str(pool[posmod(GameData.day, pool.size())])


# 빈집 잠입 — theft_p(0.30, 밤, 목격자). 성공: 물건 하나·손버릇 +10·대범함 +3, 본 사람이 있으면
# 기억(heat 2). 실패: 주인이 돌아왔다 — 주인이 곧 목격자, 신고는 확정(다음날 기소)
func burglary(nid: String, roll := -1.0) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var hl := _lines("house")
	var witnesses := _witnesses(nid)
	var p: float = GameData.theft_p(GameData.BURGLARY_P, GameData.is_evening(), witnesses.size())
	var pages: Array = []
	if _roll(roll) < p:
		var iid := _house_loot(nid)
		GameData.items[iid] = int(GameData.items.get(iid, 0)) + 1
		var stolen: Dictionary = GameData.me.get("stolen", {})
		stolen[iid] = int(stolen.get(iid, 0)) + 1
		GameData.me["stolen"] = stolen
		GameData.me["theft_xp"] = float(GameData.me.get("theft_xp", 0.0)) + 10.0
		GameData.bold_add(3.0)
		if not witnesses.is_empty():
			var reported := false
			for wid: String in witnesses:
				if _tells(wid):
					reported = true
			_remember("burglary", nid, witnesses, maxi(GameData.item_value(iid), 20), reported, 2)
		pages.append({"text": str(hl.ok) % str(GameData.ITEMS[iid].get("name", iid))})
	else:
		GameData.me["theft_xp"] = float(GameData.me.get("theft_xp", 0.0)) + 3.0
		GameData.bold_add(1.0)
		GameData.aff_add(nid, -15)
		_remember("burglary", nid, [nid] + witnesses, 20, true, 2)
		pages.append({"text": str(hl.fail)})
		pages.append({"text": str(hl.owner_fail), "name": _npc_name(nid), "portrait": _portrait(nid)})
	if not witnesses.is_empty():
		var wid := str(witnesses[0])
		pages.append({"text": str(GameData.SOCIETY_LINES.theft.witness[posmod(GameData.day, 3)]),
			"name": _npc_name(wid), "portrait": _portrait(wid)})
	pages[-1]["choices"] = [["자리를 뜬다", null]]
	m.dialog.open_seq("", null, pages)
	m.saveio.save_now()


# 피고석 — 재판일에 회관에서. 판사가 열고, 검사가 읽고, 내가 답한다
func open_trial() -> void:
	if Net.is_guest() or not GameData.charged_active() or not GameData.is_court_day() \
			or str(GameData.me.charged.get("court", "")) == "town":
		return
	_trial_open()


# 법정의 문장 — 읍 법원(court_town)에 있는 키는 그것을, 없으면 순회 재판의 것을
func _cl(key: String) -> String:
	var ch: Dictionary = GameData.me.get("charged", {})
	if str(ch.get("court", "")) == "town":
		var ct := _lines("court_town")
		if ct.has(key):
			return str(ct[key])
	return str(_lines("court").get(key, ""))


func _bench() -> String:
	return "judge_suh" if str(GameData.me.get("charged", {}).get("court", "")) == "town" else "judge_yoon"


func _bar() -> String:
	return "pros_min" if str(GameData.me.get("charged", {}).get("court", "")) == "town" else "prosecutor_han"


func _trial_open() -> void:
	m.dialog.close()
	var cl := _lines("court")
	var ch: Dictionary = GameData.me.charged
	var pros := _npc_name(_bar())
	var kind := str(ch.get("kind", "burglary"))
	var charge: String = str(Dictionary(cl.get("charge_kind", {})).get(kind, cl.charge))
	var pages: Array = [
		{"text": _cl("open")},
		{"text": charge % [_npc_name(str(ch.get("target", ""))), int(ch.get("seen", 1))],
			"name": pros, "portrait": _portrait(_bar())},
	]
	if int(ch.get("skips", 0)) > 0:
		pages.append({"text": str(cl.charge_skips) % int(ch.get("skips", 0)),
			"name": pros, "portrait": _portrait(_bar())})
	if bool(ch.get("bribe", false)):
		pages.append({"text": str(cl.charge_bribe), "name": pros, "portrait": _portrait(_bar())})
	if bool(ch.get("surrender", false)):
		pages.append({"text": str(cl.charge_surrender), "name": pros, "portrait": _portrait(_bar())})
	pages.append({"text": str(cl.ask), "choices": [
		[str(cl.admit_choice), trial_pick.bind("admit")],
		[str(cl.deny_choice), trial_pick.bind("deny")],
		[str(cl.plea_choice), trial_pick.bind("plea")],
	]})
	m.dialog.open_seq(_npc_name(_bench()), _portrait(_bench()), pages)


# 판결 — 단계 = heat + 거른 재판 + 전과 − (평판 40) − (인정) − (사정, 평판 20) + (부인, 본 사람 있음).
# 1 벌금 / 2 벌금 + 봉사 이레 / 3 구류 이레. 부인했는데 본 사람이 주인뿐이면 무죄(증거 부족)
func trial_pick(kind: String) -> void:
	if Net.is_guest() or not GameData.charged_active():
		return
	m.dialog.close()
	var cl := _lines("court")
	var ch: Dictionary = GameData.me.charged
	var pros := _npc_name(_bar())
	var town := str(ch.get("court", "")) == "town"
	var region := "town" if town else "kyojin"
	var rep := int(GameData.me.reputation.get(region, 0))
	# 단계 = heat + 거른 재판 + 뇌물 − 자수(형 절반) + 전과 − 평판 40 …
	var tier: int = int(ch.get("heat", 2)) + int(ch.get("skips", 0)) \
		+ (1 if bool(ch.get("bribe", false)) else 0) - (1 if bool(ch.get("surrender", false)) else 0)
	var pages: Array = []
	if GameData.record_unexpunged():
		tier += 1
		pages.append({"text": str(cl.record)})
	if rep >= 40:
		tier -= 1
	var acquit := false
	match kind:
		"admit":
			tier -= 1
			pages.append({"text": str(cl.admit)})
		"deny":
			if int(ch.get("others", 0)) == 0:
				acquit = true
				pages.append({"text": str(cl.deny_weak)})
			else:
				tier += 1
				pages.append({"text": str(cl.deny_strong) % int(ch.get("seen", 1)),
					"name": pros, "portrait": _portrait(_bar())})
		"plea":
			if rep >= 20:
				tier -= 1
				pages.append({"text": str(cl.plea_ok)})
			else:
				pages.append({"text": str(cl.plea_no)})
		_:
			return
	if str(ch.get("kind", "")) == "murder" and not acquit:
		tier = maxi(tier, 5)   # 살인(S5a) — 인정·사정·평판으로도 징역 아래로 내려가지 않는다
		pages.append({"text": str(cl.murder_no_mercy)})
	# 그 일의 기억 — 판결이 매듭이다
	var mem: Dictionary = {}
	for cand: Dictionary in GameData.me.get("memories", []):
		if int(cand.get("day", -1)) == int(ch.get("day", -2)) \
				and str(cand.get("target", "")) == str(ch.get("target", "")):
			mem = cand
	var jail := false
	var prison := false
	if acquit:
		if not mem.is_empty():
			mem["settled"] = "acquitted"
		pages.append({"text": str(cl.acquit)})
	else:
		tier = clampi(tier, 1, 5)
		var value: int = maxi(int(ch.get("value", 0)), 20)
		var fine := 0
		var rec := {"day": GameData.day, "crime": str(ch.get("kind", "burglary")), "court": region if town else "circuit",
			"verdict": "fine", "sentence": 0, "served": 0, "served_day": 0, "expunged": false}
		match tier:
			1:
				fine = maxi(GameData.FINE_MIN, value * GameData.FINE_MULT)
				pages.append({"text": _cl("verdict_fine") % fine})
			2:
				fine = maxi(GameData.FINE_MIN * 2, value * 5)
				rec.verdict = "service"
				rec.sentence = 7
				pages.append({"text": _cl("verdict_service") % [fine, GameData.days_kor(7)]})
			3, 4:
				jail = true
				rec.verdict = "jail"
				rec.sentence = GameData.JAIL_DAYS
				rec.served = GameData.JAIL_DAYS
				rec.served_day = GameData.day + GameData.JAIL_DAYS
				pages.append({"text": _cl("verdict_jail")})
			_:
				# 징역(S4g) — 잿빛 벌판의 교도소. 84일을 세지 않고 건너뛴다
				prison = true
				rec.verdict = "prison"
				rec.sentence = GameData.PRISON_DAYS
				rec.served = GameData.PRISON_DAYS
				rec.served_day = GameData.day + GameData.PRISON_DAYS
				pages.append({"text": _cl("verdict_prison")})
		if fine > 0:
			_fine_bill(fine, region)
		var recs: Array = GameData.me.get("record", [])
		recs.append(rec)
		GameData.me["record"] = recs
		if not mem.is_empty():
			mem["settled"] = "convicted"
			mem["forgiven"] = true
		_rep_add(-15, region)
		GameData.bold_add(-5.0)
	# 읍 법원(S4f)이면 사건 장부도 닫는다 — 판사·검사의 책상에서 사라진다
	if town:
		for c in GameData.cases:
			if c is Dictionary and int(c.get("id", -1)) == int(ch.get("case_id", -2)):
				c["stage"] = "closed"
				c["closed_by"] = "acquitted" if acquit else "court"
		if not acquit:
			GameData.note_later(str(GameData.SOCIETY_NOTES.town_convicted))
	# 법정의 문장·판사는 기소를 비우기 전에 읽는다 — 비운 뒤엔 순회 재판의 것으로 돌아간다
	var follow := _cl("follow")
	var bench := _bench()
	GameData.me["charged"] = {}
	if prison:
		pages[-1]["choices"] = [[follow, prison_begin.bind(region)]]
	elif jail:
		pages[-1]["choices"] = [[follow, serve_jail.bind(GameData.JAIL_DAYS, region)]]
	else:
		pages[-1]["choices"] = [[str(cl.leave), null]]
	m.dialog.open_seq(_npc_name(bench), _portrait(bench), pages)
	m.saveio.save_now()


# 벌금은 고지서다 — 돈은 창구 앞 E 로만(헌법 §0.3). 세금과 같은 목록·같은 체납 사다리
func _fine_bill(fine: int, region := "kyojin") -> void:
	var bills: Array = GameData.me.get("tax_bills", [])
	bills.append({"season": GameData.season_no(), "day": GameData.day, "income": 0, "property": 0,
		"total": fine, "paid": 0, "due_day": GameData.day + GameData.TAX_DUE_DAYS - 1, "kind": "fine",
		"region": region})
	while bills.size() > GameData.TAX_BILLS_MAX:
		bills.pop_front()
	GameData.me["tax_bills"] = bills


# 구류 — 하루 넘김을 days 번. 밭은 마르고, 결근은 쌓이고(이레면 자리를 잃는다), 고지서 기한은
# 그만큼 미뤄진다(복역 중 체납 정지). 이레 뒤 파출소 문 앞에서 깬다. 마지막 아침 결산이 남는다
func serve_jail(days: int, region := "kyojin", kind := "jail") -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	if m.shop_room.visible:
		m.shop_room.close()
	GameData.jail_begin(days, kind)
	for i in days:
		m.daycycle._next_day(false)
	if region == "town":
		var tt: Vector2i = m.door_tile(m.TOWN_PLOTS["police"].anchor) + Vector2i(0, 1)
		m.player.position = Vector2(tt.x * m.TILE + 16, tt.y * m.TILE + 16)
	elif GameData.village_built.has("inn"):
		var t: Vector2i = m.door_tile(m.VILLAGE_PLOTS["inn"].anchor) + Vector2i(0, 1)
		m.player.position = Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16)
	m.saveio.save_now()


# 방청 — 기소가 없는 재판일, 판사가 순경이 넘긴 사건을 읽는다(마을이 법을 본다)
func open_docket() -> void:
	m.dialog.close()
	var cl := _lines("court")
	var pages: Array = [{"text": str(cl.open)}]
	var docket := GameData.court_docket()
	if docket.is_empty():
		pages.append({"text": str(cl.docket_none)})
	else:
		pages.append({"text": str(cl.docket_open) % docket.size()})
		for c in docket:
			pages.append({"text": str(cl.docket_line) % [_npc_name(str(c.get("suspect", ""))),
				_npc_name(str(c.get("victim", ""))), GameData.NPC_FINE]})
	pages.append({"text": str(cl.docket_close), "choices": [[str(cl.leave), null]]})
	m.dialog.open_seq(_npc_name("judge_yoon"), _portrait("judge_yoon"), pages)


# 전과 말소 — 면사무소 창구, 인지세 500(예산으로). 임용 심사가 다시 0 으로 센다. 평판 +10
func expunge() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var why := GameData.can_expunge()
	if why == "" and GameData.money < GameData.EXPUNGE_COST:
		why = "인지세 %dG 이 있어야 하네." % GameData.EXPUNGE_COST
	if why != "":
		m.dialog.open(_npc_name("chief"), why, [["알겠습니다", open_township]], _portrait("chief"))
		return
	GameData.money -= GameData.EXPUNGE_COST
	GameData.today_spent += GameData.EXPUNGE_COST
	GameData.gov_budget["kyojin"] = int(GameData.gov_budget.get("kyojin", 0)) + GameData.EXPUNGE_COST
	GameData.expunge_records()
	_rep_add(10)
	m.dialog.open(_npc_name("chief"), str(_lines("court").expunge_ok), [["대화 끝", null]], _portrait("chief"))
	m.saveio.save_now()


# ---- 자기 상점 · 좌판 (S3a) ----
#
# 면사무소에서 허가를 받으면 집 마당에 좌판이 선다(짓기 없음 — 그날 바로). 물건을 올리고
# 값을 매기면 아침 결산이 손님을 보낸다(GameData._shop_settle). 판 돈은 금고에 쌓이고
# 좌판 앞 E 로 받는다 — 돈은 창구에서만. 폐업하면 물건은 가방으로, 좌판은 사라진다.

const STAND_PAGE := 6
const STAND_YARD := Vector2i(6, 3)   # 집 앵커에서 — 집 오른쪽 앞마당


func open_shop_permit() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var why := GameData.shop_permit_why()
	if why != "":
		m.dialog.open(_npc_name("chief"), why, [["알겠습니다", open_township]], _portrait("chief"))
		return
	var btns: Array = []
	for kid in GameData.SHOP_KINDS:
		var kd: Dictionary = GameData.SHOP_KINDS[kid]
		var lbl := "%s — %s" % [str(kd.name), str(kd.desc)]
		var need := int(GameData.SHOP_SKILL_LV)
		if GameData.skill_lv(str(kd.skill)) < need:
			btns.append(gray(lbl, "%s 숙련이 %d은 돼야 하네. 지금 %d일세." \
				% [str(GameData.SKILLS.get(str(kd.skill), {}).get("name", kd.skill)), need, GameData.skill_lv(str(kd.skill))]))
		else:
			btns.append([lbl, _permit.bind(kid)])
	btns.append(["돌아가기", open_township])
	m.dialog.open(_npc_name("chief"), "무슨 좌판을 낼 텐가. 인지세는 %dG일세." % GameData.SHOP_PERMIT_COST,
		btns, _portrait("chief"))


# 허가 — 인지세는 예산으로, 좌판은 마당에 바로 선다
func _permit(kind: String) -> void:
	if Net.is_guest() or GameData.shop_permit_why() != "" or not GameData.SHOP_KINDS.has(kind):
		return
	m.dialog.close()
	var t: Vector2i = m.nearest_open_tile(m.HOME_ANCHOR + STAND_YARD)
	if t.x < 0:
		m.dialog.open(_npc_name("chief"), "마당에 좌판 놓을 자리가 없네.", [["알겠습니다", null]], _portrait("chief"))
		return
	GameData.money -= GameData.SHOP_PERMIT_COST
	GameData.today_spent += GameData.SHOP_PERMIT_COST
	GameData.gov_budget["kyojin"] = int(GameData.gov_budget.get("kyojin", 0)) + GameData.SHOP_PERMIT_COST
	GameData.me["shop_own"] = {"kind": kind, "since": GameData.day, "till": 0, "x": t.x, "y": t.y}
	GameData.me["shop_stock"] = {}
	m.objnode._place_object(t, "shop_stand", 0)
	m.queue_redraw()
	m.dialog.open(_npc_name("chief"), "허가했네. 마당에 좌판을 세워 두게. 손님은 마을이 보내지.",
		[["대화 끝", null]], _portrait("chief"))
	m.saveio.save_now()


func _stand_tile() -> Vector2i:
	var so: Dictionary = GameData.me.get("shop_own", {})
	return Vector2i(int(so.get("x", -1)), int(so.get("y", -1)))


# 좌판 앞 E
func open_stand() -> void:
	m.dialog.close()
	if not GameData.shop_open():
		m.dialog.open("좌판", "주인 없는 좌판이다.", [["닫기", null]])
		return
	var so: Dictionary = GameData.me.shop_own
	var kd: Dictionary = GameData.SHOP_KINDS.get(str(so.get("kind", "")), {})
	var stock: Dictionary = GameData.me.get("shop_stock", {})
	var body := "%s의 %s.\n" % [_my_name(), str(kd.get("name", "좌판"))]
	if stock.is_empty():
		body += "좌판이 비어 있다."
	else:
		body += "진열:"
		for id in stock:
			body += " %s ×%d(%dG) ·" % [GameData.goods_name(str(id)), int(stock[id].qty), int(stock[id].price)]
		body = body.trim_suffix(" ·")
	var till := int(so.get("till", 0))
	if till > 0:
		body += "\n금고에 %dG 이 있다." % till
	if Net.is_guest():
		m.dialog.open("좌판", body, [["닫기", null]])
		return
	var btns: Array = []
	if till > 0:
		btns.append(["돈 받기 — %dG" % till, _stand_collect])
	btns.append(["물건 올리기", _stand_put.bind(0)])
	if not stock.is_empty():
		btns.append(["물건 내리기", _stand_take.bind(0)])
	btns.append(["장부", _stand_ledger])
	btns.append(["폐업", _stand_close_ask])
	btns.append(["닫기", null])
	m.dialog.open("좌판", body, btns)


func _stand_collect() -> void:
	if Net.is_guest() or not GameData.shop_open():
		return
	var till := int(GameData.me.shop_own.get("till", 0))
	if till <= 0:
		return
	GameData.money += till
	GameData.today_earned += till
	GameData.me.shop_own["till"] = 0
	Sound.play_sfx("sfx_coin")
	m.saveio.save_now()
	open_stand()


# 올릴 수 있는 것 — 가진 작물(수확물)과 값 있는 물건
func _stand_goods() -> Array:
	var out: Array = []
	for id in GameData.produce:
		if int(GameData.produce[id]) > 0 and GameData.CROPS.has(id):
			out.append(str(id))
	for id in GameData.items:
		if int(GameData.items[id]) > 0 and int(GameData.ITEMS.get(id, {}).get("sell", 0)) > 0:
			out.append(str(id))
	return out


func _stand_put(page: int) -> void:
	m.dialog.close()
	var goods := _stand_goods()
	var stock: Dictionary = GameData.me.get("shop_stock", {})
	if goods.is_empty():
		m.dialog.open("좌판", "올릴 물건이 없다.", [["돌아가기", open_stand]])
		return
	var pages := maxi(1, int(ceil(goods.size() / float(STAND_PAGE))))
	page = clampi(page, 0, pages - 1)
	var btns: Array = []
	for i in range(page * STAND_PAGE, mini((page + 1) * STAND_PAGE, goods.size())):
		var id := str(goods[i])
		var have: int = int(GameData.produce[id]) if GameData.CROPS.has(id) else int(GameData.items[id])
		var lbl := "%s ×%d — 제값 %dG" % [GameData.goods_name(id), have, GameData.item_value(id)]
		if stock.size() >= GameData.SHOP_STOCK_KINDS and not stock.has(id):
			btns.append(gray(lbl, "좌판이 좁다. 가짓수는 %d까지다." % GameData.SHOP_STOCK_KINDS))
		else:
			btns.append([lbl, _stand_put_pick.bind(id)])
	if page + 1 < pages:
		btns.append(["다음 장", _stand_put.bind(page + 1)])
	if page > 0:
		btns.append(["앞 장", _stand_put.bind(page - 1)])
	btns.append(["돌아가기", open_stand])
	m.dialog.open("물건 올리기 (%d/%d장)" % [page + 1, pages], "무엇을 올릴까.", btns)


func _stand_put_pick(id: String) -> void:
	m.dialog.close()
	var have: int = int(GameData.produce.get(id, 0)) if GameData.CROPS.has(id) else int(GameData.items.get(id, 0))
	if have <= 0:
		_stand_put(0)
		return
	var base := GameData.item_value(id)
	var btns: Array = []
	for qty in [5, have]:
		if qty > have or (qty == have and have == 5 and btns.size() > 0):
			continue
		for tier in ["cheap", "fair", "dear"]:
			var price := maxi(1, int(float(base) * float(GameData.SHOP_PRICE_TIERS[tier])))
			btns.append(["%s %d개 · %s %dG" % [GameData.goods_name(id), mini(qty, have),
				str(GameData.SHOP_TIER_NAMES[tier]), price], _stand_put_do.bind(id, mini(qty, have), tier)])
	btns.append(["돌아가기", _stand_put.bind(0)])
	m.dialog.open("물건 올리기", "%s — 제값 %dG. 몇 개를 얼마에 올릴까." % [GameData.goods_name(id), base], btns)


func _stand_put_do(id: String, qty: int, tier: String) -> void:
	if Net.is_guest() or not GameData.shop_open() or qty <= 0:
		return
	m.dialog.close()
	var have: int = int(GameData.produce.get(id, 0)) if GameData.CROPS.has(id) else int(GameData.items.get(id, 0))
	qty = mini(qty, have)
	if qty <= 0:
		return
	var stock: Dictionary = GameData.me.get("shop_stock", {})
	if stock.size() >= GameData.SHOP_STOCK_KINDS and not stock.has(id):
		return
	if GameData.CROPS.has(id):
		GameData.consume_produce(id, qty)
	else:
		GameData.items[id] = int(GameData.items[id]) - qty
	var price := maxi(1, int(float(GameData.item_value(id)) * float(GameData.SHOP_PRICE_TIERS.get(tier, 1.0))))
	var row: Dictionary = stock.get(id, {"qty": 0, "price": price})
	row["qty"] = int(row.get("qty", 0)) + qty
	row["price"] = price   # 새로 매긴 값이 전체에 붙는다
	stock[id] = row
	GameData.me["shop_stock"] = stock
	Sound.play_sfx("sfx_place")
	m.saveio.save_now()
	open_stand()


func _stand_take(page: int) -> void:
	m.dialog.close()
	var stock: Dictionary = GameData.me.get("shop_stock", {})
	var ids: Array = stock.keys()
	if ids.is_empty():
		open_stand()
		return
	var pages := maxi(1, int(ceil(ids.size() / float(STAND_PAGE))))
	page = clampi(page, 0, pages - 1)
	var btns: Array = []
	for i in range(page * STAND_PAGE, mini((page + 1) * STAND_PAGE, ids.size())):
		var id := str(ids[i])
		btns.append(["%s ×%d 내리기" % [GameData.goods_name(id), int(stock[id].qty)], _stand_take_do.bind(id)])
	if page + 1 < pages:
		btns.append(["다음 장", _stand_take.bind(page + 1)])
	if page > 0:
		btns.append(["앞 장", _stand_take.bind(page - 1)])
	btns.append(["돌아가기", open_stand])
	m.dialog.open("물건 내리기", "무엇을 거둘까.", btns)


func _stand_take_do(id: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	_stand_return(id)
	m.saveio.save_now()
	open_stand()


# 좌판의 물건 하나를 가방으로 — 작물은 보통 품질로 돌아온다(올릴 때 낮은 품질부터 나갔다)
func _stand_return(id: String) -> void:
	var stock: Dictionary = GameData.me.get("shop_stock", {})
	if not stock.has(id):
		return
	var qty := int(stock[id].get("qty", 0))
	if GameData.CROPS.has(id):
		GameData.produce[id] = int(GameData.produce.get(id, 0)) + qty
	else:
		GameData.items[id] = int(GameData.items.get(id, 0)) + qty
	stock.erase(id)
	GameData.me["shop_stock"] = stock


func _stand_ledger() -> void:
	m.dialog.close()
	var ledger: Array = GameData.me.get("shop_ledger", [])
	var body := ""
	if ledger.is_empty():
		body = "아직 장부에 적힌 날이 없다."
	else:
		var start := maxi(0, ledger.size() - 7)
		for i in range(start, ledger.size()):
			var row: Dictionary = ledger[i]
			body += "%d일째 — %d개, %dG\n" % [int(row.day), int(row.sold), int(row.gold)]
	var sum28 := GameData.shop_ledger_sum(GameData.SHOP_LEDGER_DAYS)
	body += "\n28일 매출 %dG — 다음 고지서의 매출세 %dG" % [sum28, int(float(sum28) * GameData.SALES_TAX_RATE)]
	m.dialog.open("좌판 장부", body, [["돌아가기", open_stand]])


func _stand_close_ask() -> void:
	m.dialog.close()
	m.dialog.open("폐업", "좌판을 거둘까. 물건은 가방으로 돌아오고, 허가는 사라진다.",
		[["거둔다", _stand_close], ["아니다", open_stand]])


func _stand_close() -> void:
	if Net.is_guest() or not GameData.shop_open():
		return
	m.dialog.close()
	var stock: Dictionary = GameData.me.get("shop_stock", {})
	for id in stock.keys():
		_stand_return(str(id))
	var till := int(GameData.me.shop_own.get("till", 0))
	if till > 0:
		GameData.money += till
		GameData.today_earned += till
	var t := _stand_tile()
	if t.x >= 0 and str(m.objects.get(t, {}).get("kind", "")) == "shop_stand":
		m.objnode._remove_object(t)
	GameData.me["shop_own"] = {}
	GameData.me["shop_stock"] = {}
	m.queue_redraw()
	m.dialog.open("", "좌판을 거뒀다. 마당이 조용하다.", [["대화 끝", null]])
	m.saveio.save_now()


# ---- 자치회 · 고장 점원 (S3c) ----
#
# 명예직은 봉급이 없다 — 몫은 부름(호칭)과 「보이는 것」이다. 청년회장은 밤에 세 군데를 돌고
# 아침에 이장에게 보고하며 어젯밤 밖에 있던 사람을 안다. 부녀회장은 오래 못 본 집을 알고
# 찾아간다(이탈을 막는 손). 훈장은 회관 책상에서 글을 가르친다(근무 미니루프).
# 고장 점원은 방이 없어 그 사람 앞 대화가 계산대다.

# 아침 보고 — 어젯밤 야경이 곧 근무. 실적·평판만 오르고 봉급은 없다
func watch_report() -> void:
	if Net.is_guest() or not _is_youth() or not watch_done_yesterday() \
			or GameData.worked_on(GameData.day):
		return
	m.dialog.close()
	var job := _job()
	_me_add("perf", 1)
	_log_work("work", "assoc", 1)
	if _me_int("perf") % 5 == 0:
		_rep_add(1)
	var lines: Array = job.get("watch", {}).get("report", ["수고했네."])
	m.dialog.open(_npc_name("chief"), str(lines[posmod(GameData.day, lines.size())]),
		[["대화 끝", open_township]], _portrait("chief"))
	m.saveio.save_now()


# 야경 명부 — 밤에 밖에 있는 사람들. 마을에서 밤을 아는 사람은 청년회장뿐이다(sees)
func _watch_roster() -> void:
	m.dialog.close()
	var body := "어젯밤 밖에 있던 사람.\n"
	var rows: Array = []
	for nid in GameData.NIGHT_OWLS:
		var sid := str(nid)
		if sid == "officer_park":
			rows.append("· 박 순경 — 자정까지 순찰")
		elif GameData.npc_greeted.has(sid) and GameData.NPCS.has(sid):
			rows.append("· %s — %d시까지 밖에" % [_npc_name(sid), int(GameData.NIGHT_OWLS[sid]) / 60])
	if int(GameData.me.get("night_out_day", 0)) == GameData.day - 1:
		rows.append("· 나 — 밤길 %d분" % int(GameData.me.get("night_out_min", 0.0)))
	body += "\n".join(PackedStringArray(rows)) if not rows.is_empty() else "아무도 없었다."
	m.dialog.open("야경 명부", body, [["돌아가기", open_township]])


# 오래 말을 못 붙인 정착민 — 이레 넘게 대화가 없으면 떠날 마음이 생긴다(LEAVE). 부녀회장이 본다
func _neglected() -> Array:
	var out: Array = []
	for nid in GameData.settlers:
		var sid := str(nid)
		if not GameData.NPCS.has(sid):
			continue
		if GameData.day - int(GameData.npc_last_talk.get(sid, 0)) >= GameData.NEGLECT_DAYS:
			out.append(sid)
	return out


func _women_roster() -> void:
	m.dialog.close()
	var lonely := _neglected()
	var body := "오래 못 본 집.\n"
	if lonely.is_empty():
		body += "요즘은 다들 얼굴을 봤다."
	else:
		for sid: String in lonely:
			body += "· %s — %s째 말이 없다\n" % [_npc_name(sid),
				GameData.days_kor(mini(10, GameData.day - int(GameData.npc_last_talk.get(sid, 0))))]
	var btns: Array = []
	if not lonely.is_empty():
		var first := str(lonely[0])
		if _me_int("visit_day") == GameData.day:
			btns.append(gray("찾아간다 — %s" % _npc_name(first), "오늘은 한 집 돌았다."))
		else:
			btns.append(["찾아간다 — %s" % _npc_name(first), _women_visit.bind(first)])
	btns.append(["돌아가기", open_township])
	m.dialog.open("살림 명부", body, btns)


# 찾아간다 — 하루 한 집. 그 집의 「마지막 대화」가 오늘이 되고 호감이 조금 오른다(이탈이 멈춘다)
func _women_visit(nid: String) -> void:
	if Net.is_guest() or str(GameData.me.get("job", "")) != "women_head" \
			or _me_int("visit_day") == GameData.day:
		return
	m.dialog.close()
	GameData.npc_last_talk[nid] = GameData.day
	GameData.aff_add(nid, 3)
	GameData.me["visit_day"] = GameData.day
	m.dialog.open(_npc_name(nid), "…와 줬네요. 아무도 안 오는 줄 알았어요. 차 한잔 하고 가요.",
		[["대화 끝", null]], _portrait(nid))
	m.saveio.save_now()


# 방 없는 일터의 대화 선택지 — 계산대(counter_menu)와 같은 세 줄
func _talk_work_choices(choices: Array) -> void:
	var job := _job()
	var why := can_work("")
	if why == "":
		choices.insert(choices.size() - 1, ["근무", work_start.bind("")])
	else:
		choices.insert(choices.size() - 1, gray("근무", why))
	if int(job.get("wage", 0)) > 0:
		var wl := _wage_lines(job)
		if GameData.wage_frozen():
			choices.insert(choices.size() - 1, gray("봉급 받기", "밀린 세금부터 내게. 그 전엔 봉급이 없네."))
		elif _me_int("wage_pending") <= 0:
			choices.insert(choices.size() - 1, gray("봉급 받기", str(wl.get("nothing", "받을 게 없다."))))
		elif GameData.day < _me_int("wage_day"):
			choices.insert(choices.size() - 1, gray("봉급 받기", str(wl.get("not_yet", "봉급날은 아직이다."))))
		else:
			choices.insert(choices.size() - 1, ["봉급 받기 — %dG" % _me_int("wage_pending"), collect_wage])
	choices.insert(choices.size() - 1, ["그만두겠습니다", resign])


# ---- 장물아비 (S4c) ----

# 가방에 남아 있는 장물의 값 — me.stolen 은 훔친 수, 가진 수와 작은 쪽만 장물이다
func stolen_value() -> int:
	var total := 0
	var stolen: Dictionary = GameData.me.get("stolen", {})
	for id in stolen:
		var n: int = mini(int(stolen[id]), int(GameData.items.get(id, 0)))
		if n > 0:
			total += n * int(float(GameData.item_value(str(id))) * GameData.FENCE_RATE)
	return total


func sell_stolen() -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var fl: Dictionary = GameData.SOCIETY_LINES.fence
	var got := stolen_value()
	if got <= 0:
		m.dialog.open(_npc_name("fence_gu"), str(fl.none), [["대화 끝", null]], _portrait("fence_gu"))
		return
	var stolen: Dictionary = GameData.me.get("stolen", {})
	for id in stolen.keys():
		var n: int = mini(int(stolen[id]), int(GameData.items.get(id, 0)))
		if n > 0:
			GameData.items[id] = int(GameData.items[id]) - n
	GameData.me["stolen"] = {}
	GameData.money += got
	GameData.today_earned += got
	GameData.bold_add(1.0)
	m.dialog.open(_npc_name("fence_gu"), str(fl.ok) % got, [["대화 끝", null]], _portrait("fence_gu"))
	m.saveio.save_now()


# ---- 읍 사건 위의 검사·판사 (S4d) ----
#
# 손글 미니루프는 연습이고, 이것이 진짜다: 읍 순경이 잡아 넘긴 사건이 검사의 책상에, 검사가
# 기소한 사건이 판사의 책상에 오른다. 사흘 안에 손대지 않으면 부장이 대신 처리한다(GameData._town_case_tick)

func job_id_now() -> String:
	return str(GameData.me.get("job", ""))


func _work_real_case(c: Dictionary) -> void:
	var job := _job()
	var head := str(job.get("boss", ""))
	var cid := int(c.get("id", 0))
	var sname := GameData.npc_name(str(c.get("suspect", "")))
	var vname := GameData.npc_name(str(c.get("victim", "")))
	var ev := int(c.get("evidence", 0))
	var pages: Array = []
	if job_id_now() == "prosecutor":
		pages.append({"text": "%s네 점포 사건. 피의자 %s. 흔적 %d — 문턱은 %d." % [vname, sname, ev, GameData.NEED_EVIDENCE],
			"choices": [
				["기소한다", case_pick.bind(cid, "indict")],
				["불기소한다", case_pick.bind(cid, "drop")],
				["보완수사를 지시한다", case_pick.bind(cid, "probe")],
			]})
	else:
		pages.append({"text": "피고 %s. %s네 점포에 들었다. 흔적 %d." % [sname, vname, ev],
			"choices": [
				["무죄", case_pick.bind(cid, "acquit")],
				["경감 — 벌금 절반", case_pick.bind(cid, "lenient")],
				["법정형 — 벌금", case_pick.bind(cid, "full")],
			]})
	m.dialog.open_seq(_npc_name(head), _portrait(head), pages)


# 근무 한 번의 몫 — 실적·일급·근무 기록·평판(work_pick 과 같은 셈)
func _work_credit(inst: String, pick: int) -> void:
	_me_add("perf", 1)
	if not GameData.wage_frozen():
		_me_add("wage_pending", GameData.job_wage())
	_log_work("work", inst, pick)
	if _me_int("perf") % 5 == 0:
		_rep_add(1)


func case_pick(cid: int, kind: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	var c := GameData.case_by_id(cid)
	if c.is_empty() or str(c.get("region", "")) != "town":
		return
	var job := _job()
	var head := str(job.get("boss", ""))
	var sid := str(c.get("suspect", ""))
	var ev := int(c.get("evidence", 0))
	var line := ""
	match kind:
		"indict":
			GameData.town_case_indict(c, "player", true)
			line = "기소했네. 판사가 볼 걸세." if ev >= GameData.NEED_EVIDENCE else "흔적이 모자란 기소일세. 판사가 돌려보낼지도 모르네."
			GameData.aff_add(head, 1 if ev >= GameData.NEED_EVIDENCE else -1)
		"drop":
			GameData.town_case_indict(c, "player", false)
			GameData.aff_add(sid, 5)
			line = "덮은 건 아니겠지. 흔적을 다시 보게." if ev >= GameData.NEED_EVIDENCE else "그래. 문턱에 못 미치면 안 하는 걸세."
			GameData.aff_add(head, -1 if ev >= GameData.NEED_EVIDENCE else 1)
		"probe":
			c["evidence"] = ev + 1
			line = "보완수사일세. 순경이 하루 더 돌겠네."
		"acquit":
			GameData.town_case_verdict(c, "player", "acquit")
			GameData.aff_add(sid, 10)
			line = "무죄라. 흔적이 둘인데." if ev >= GameData.NEED_EVIDENCE else "그래. 흔적 하나로는 못 가두네."
			GameData.aff_add(head, -1 if ev >= GameData.NEED_EVIDENCE else 1)
		"lenient":
			GameData.town_case_verdict(c, "player", "lenient")
			GameData.aff_add(sid, 3)
			line = "경감일세. 반은 갚고 반은 마음으로 갚겠지."
		"full":
			GameData.town_case_verdict(c, "player", "full")
			GameData.aff_add(sid, -5)
			line = "법정형일세. 무겁지만 맞네." if ev >= GameData.NEED_EVIDENCE else "흔적 하나에 법정형인가. 무겁네."
			GameData.aff_add(head, 1 if ev >= GameData.NEED_EVIDENCE else -1)
		_:
			return
	_work_credit(str(job.get("inst", "")), 0)
	m.dialog.open(_npc_name(head), line, [["대화 끝", null]], _portrait(head))
	m.saveio.save_now()


# ---- 읍 살림 (S4e) — 군청 장부 · 신협 기채 ----
#
# 읍 예산은 군수가 건다. 나는 군청 서기로 신협에서 빚을 낼 수 있고, 그 빚이 긴축을 부른다 —
# 「망한 읍의 서장」은 내가 만든 결과로만 있다. 장부는 누구나 본다(군청 게시)

func open_town_ledger() -> void:
	m.dialog.close()
	var budget := int(GameData.gov_budget.get("town", 0))
	var debt := int(GameData.gov_debt.get("town", 0))
	var body := "읍 예산 %dG · 빚 %dG · 인구 %d명\n" % [budget, debt, GameData.town_population()]
	var lv := GameData.town_austerity()
	if lv > 0:
		body += "긴축 %d단계 — %s\n" % [lv, ["", "사업 중단", "밤 순찰 축소", "순경 감원·이주 중지"][lv]]
	if GameData.town_building != "":
		body += "공사 중: 「%s」\n" % str(GameData.town_project(GameData.town_building).get("name", ""))
	var nxt := GameData.town_next_project()
	if not nxt.is_empty():
		body += "다음 사업: 「%s」 %dG\n" % [str(nxt.name), int(nxt.cost)]
	if not GameData.town_done.is_empty():
		var names: Array = []
		for pid in GameData.town_done:
			names.append(str(GameData.town_project(str(pid)).get("name", pid)))
		body += "다 된 것: %s\n" % " · ".join(PackedStringArray(names))
	var logs: Array = GameData.town_log
	if not logs.is_empty():
		body += "\n계절 장부"
		for i in range(maxi(0, logs.size() - 3), logs.size()):
			var r: Dictionary = logs[i]
			body += "\n· 교부금 +%d · 장부세 +%d · 운영비 −%d" % [int(r.get("grant", 0)), int(r.get("levy", 0)), int(r.get("ops", 0))]
			if int(r.get("interest", 0)) > 0:
				body += " · 이자 %d · 상환 %d" % [int(r.get("interest", 0)), int(r.get("repay", 0))]
			if str(r.get("project", "")) != "":
				body += " · 「%s」 착공" % str(GameData.town_project(str(r.project)).get("name", ""))
	m.dialog.open("읍 장부", body, [["나간다", null]])


func _is_county_clerk() -> bool:
	return str(GameData.me.get("job", "")) == "county_clerk"


func town_bank_menu() -> void:
	m.dialog.close()
	var debt := int(GameData.gov_debt.get("town", 0))
	var body := "읍 빚 %dG. 계절 이자 %d%%, 흑자의 반으로 갚는다." % [debt, int(GameData.TOWN_INTEREST * 100.0)]
	var btns: Array = []
	var lbl := "읍 기채 — %dG" % GameData.TOWN_LOAN
	if Net.is_guest():
		btns.append(gray(lbl, "손님은 이 마을 일에 끼지 않는다."))
	elif not _is_county_clerk():
		btns.append(gray(lbl, "기채는 군청 서기가 청하는 걸세."))
	else:
		btns.append([lbl, town_borrow])
	if debt > 0:
		var pay: int = mini(debt, int(GameData.gov_budget.get("town", 0)))
		if _is_county_clerk() and pay > 0:
			btns.append(["읍 빚 갚기 — %dG" % pay, town_repay.bind(pay)])
		else:
			btns.append(gray("읍 빚 갚기", "군청 서기가 예산으로 갚는 걸세."))
	btns.append(["대화 끝", null])
	m.dialog.open(_npc_name("manager_baek"), body, btns, _portrait("manager_baek"))


func town_borrow() -> void:
	if Net.is_guest() or not _is_county_clerk():
		return
	m.dialog.close()
	GameData.town_borrow()
	m.dialog.open(_npc_name("manager_baek"), "빌려 주지. %dG 은 읍 예산으로 갔네. 이자는 계절마다일세." % GameData.TOWN_LOAN,
		[["대화 끝", null]], _portrait("manager_baek"))
	m.saveio.save_now()


func town_repay(amount: int) -> void:
	if Net.is_guest() or not _is_county_clerk():
		return
	m.dialog.close()
	var paid := GameData.town_repay(amount)
	m.dialog.open(_npc_name("manager_baek"), "받았네. %dG 이 줄었어. 장부는 거짓말을 안 하네." % paid,
		[["대화 끝", null]], _portrait("manager_baek"))
	m.saveio.save_now()


# ---- 읍 순경·유치·뇌물 (S4f, 헌법 §6.3) ----
#
# 읍의 신고는 회의가 아니라 곧장 경찰서다. 아침에 수배가 걸리면 순경 셋이 여섯 시부터 정류장·관청
# 거리·장터에서 협공한다(읍 밖으로는 안 나온다 — 정류장을 막는 게 그들의 일이다). 곁에 2초면 체포:
# 순순히 가면 유치 사흘 → 검찰 → 읍 법원, 돈을 내밀면(대범함 40, 500G) 순경의 snitch 만큼 굴린다.
# 실패한 뇌물은 같은 사건에 얹혀 가중된다. 자수는 경찰서 창구에서 — 형이 한 단계 가볍다.

func _pl(key: String) -> String:
	return str(_lines("police_town").get(key, ""))


func arrest_town(cop: String, surrender: bool) -> void:
	if Net.is_guest() or not GameData.town_wanted_active():
		return
	m.dialog.close()
	var w: Dictionary = GameData.me.wanted
	if surrender:
		m.dialog.open(_npc_name("chief_ha"), _pl("surrender"),
			[[_pl("surrender_choice"), town_detain.bind(true)]], _portrait("chief_ha"))
		return
	var text := _pl("caught").format({"victim": _npc_name(str(w.get("target", "")))})
	var choices: Array = [[_pl("follow_choice"), town_detain.bind(false)]]
	# 뇌물 — 문턱 아래면 선택지 자체가 없다(헌법 §5.2 「선택지 없음」)
	if _me_int("boldness_base", -1) >= 0 and GameData.boldness() >= int(GameData.GATE.get("bribe", 40)):
		if GameData.money >= GameData.BRIBE_COST:
			choices.append([_pl("bribe_choice") % GameData.BRIBE_COST, bribe.bind(cop)])
		else:
			choices.append(gray(_pl("bribe_choice") % GameData.BRIBE_COST, "그만한 돈이 없다."))
	m.dialog.open(_npc_name(cop), text, choices, _portrait(cop))


# 뇌물 — 성공 0.3 × (2 − snitch) / 1.5. 성공: 수배 끝, 기억은 「덮였다」. 실패: 돈은 압수(읍 예산),
# 같은 사건에 뇌물이 얹히고(heat +2) 유치로 간다
func bribe(cop: String, roll := -1.0) -> void:
	if Net.is_guest() or not GameData.town_wanted_active() or GameData.money < GameData.BRIBE_COST:
		return
	m.dialog.close()
	GameData.money -= GameData.BRIBE_COST
	GameData.today_spent += GameData.BRIBE_COST
	var w: Dictionary = GameData.me.wanted
	var p: float = GameData.BRIBE_P * (2.0 - GameData.gen_trait(cop, "snitch")) / 1.5
	if _roll(roll) < p:
		GameData._settle_mem(int(w.get("day", 0)), str(w.get("target", "")), "bribed")
		GameData.me["wanted"] = {}
		GameData.bold_add(3.0)
		GameData.aff_add(cop, 5)
		m.dialog.open(_npc_name(cop), _pl("bribe_ok"), [["자리를 뜬다", null]], _portrait(cop))
		m.saveio.save_now()
		return
	GameData.gov_budget["town"] = int(GameData.gov_budget.get("town", 0)) + GameData.BRIBE_COST
	w["bribe"] = true
	w["heat"] = int(w.get("heat", 1)) + 2
	_remember("bribe", cop, [cop], GameData.BRIBE_COST, true, 2)
	GameData.me.memories[-1]["settled"] = "charged"
	GameData.bold_add(-3.0)
	m.dialog.open(_npc_name(cop), _pl("bribe_fail"),
		[[_pl("follow_choice"), town_detain.bind(false)]], _portrait(cop))


# 유치 사흘 — 하루 넘김 셋(밭은 마른다), 경찰서 문 앞에서 깬다. 서류는 사건 장부로: 검찰이 다음날 본다
func town_detain(surrender: bool) -> void:
	if Net.is_guest() or not GameData.town_wanted_active():
		return
	_detain_book(surrender)
	serve_jail(GameData.TOWN_DETAIN_DAYS, "town", "detain")
	m.dialog.open("경찰서", _pl("detained"), [["나선다", null]])


# 유치의 장부 몫 — 수배를 사건으로 옮긴다(하루 넘김은 serve_jail 의 몫이라 하네스는 이것만 부른다)
func _detain_book(surrender: bool) -> void:
	var w: Dictionary = GameData.me.wanted
	GameData._settle_mem(int(w.get("day", 0)), str(w.get("target", "")), "charged")
	GameData.case_seq += 1
	GameData.cases.append({"id": GameData.case_seq, "crime": str(w.get("kind", "")), "day": int(w.get("day", 0)),
		"suspect": "player", "victim": str(w.get("target", "")), "witness": "", "evidence": int(w.get("seen", 1)) + 1,
		"stage": "charged", "closed_by": "", "deadline": GameData.day + GameData.CASE_TTL, "region": "town",
		"heat": int(w.get("heat", 1)), "charged_day": GameData.day + GameData.TOWN_DETAIN_DAYS - 1, "indicted_day": 0,
		"surrender": surrender, "bribe": bool(w.get("bribe", false)), "skips": 0,
		"seen": int(w.get("seen", 1)), "others": int(w.get("others", 0)), "value": int(w.get("value", 0))})
	while GameData.cases.size() > GameData.CASE_MAX:
		GameData.cases.pop_front()
	GameData.me["wanted"] = {}
	_rep_add(-2 if surrender else -5, "town")


# 경찰서 창구 — 수배 중이면 자수, 내 사건이 있으면 그 자리, 아니면 서장의 한마디
func police_town_counter() -> bool:
	if Net.is_guest():
		return false
	if GameData.town_wanted_active():
		arrest_town("chief_ha", true)
		return true
	var c := GameData.town_my_case()
	if c.is_empty():
		return false
	var key := "desk_indicted" if str(c.get("stage", "")) == "indicted" else "desk_charged"
	m.dialog.open(_npc_name("chief_ha"), _pl(key), [["대화 끝", null]], _portrait("chief_ha"))
	return true


# 법원 창구 — 기소된 내가 서면 재판이 열린다(재판일을 기다리지 않는다: 읍 법원은 날마다 앉아 있다)
func court_town_counter() -> bool:
	if Net.is_guest():
		return false
	var c := GameData.town_my_case()
	if c.is_empty():
		return false
	if str(c.get("stage", "")) != "indicted":
		m.dialog.open(_npc_name("judge_suh"), _pl("court_wait"), [["대화 끝", null]], _portrait("judge_suh"))
		return true
	m.dialog.close()
	open_town_trial(c)
	return true


func open_town_trial(c: Dictionary) -> void:
	GameData.me["charged"] = {"day": int(c.get("day", 0)), "kind": str(c.get("crime", "")),
		"target": str(c.get("victim", "")), "value": int(c.get("value", 0)), "others": int(c.get("others", 0)),
		"seen": int(c.get("seen", 1)), "heat": int(c.get("heat", 1)), "court_day": GameData.day,
		"skips": int(c.get("skips", 0)), "since": GameData.day, "court": "town", "case_id": int(c.get("id", 0)),
		"surrender": bool(c.get("surrender", false)), "bribe": bool(c.get("bribe", false))}
	_trial_open()


# ---- 교도소 (S4g, 헌법 §6.6) ----
#
# 징역은 잿빛 벌판의 교도소 실내에서 시작해 실내에서 끝난다. 하루 넘김을 84번 돌리지 않는다 —
# 날짜를 한 번에 옮기고 밭만 마르게(젖음 0, 지나온 계절의 제철 아닌 작물은 시듦) 한 뒤 사회의
# 아침을 한 번 돈다. 자리는 구속되는 날 비고(전직), 나올 땐 대범함 +5 · 호칭 「그 일 있던 사람」 이레.

func _pr(key: String) -> String:
	return str(_lines("prison").get(key, ""))


# 구속 — 판결의 「순경을 따라간다」. 자리부터 비우고 교도소 안으로 옮긴다
func prison_begin(region: String) -> void:
	if Net.is_guest():
		return
	m.dialog.close()
	if m.shop_room.visible:
		m.shop_room.close()
	GameData.me["sentence"] = {"days": GameData.PRISON_DAYS, "region": region, "since": GameData.day}
	var lost := _seat_release("jailed")
	var t: Vector2i = m.door_tile(m.TOWN_PLOTS["prison"].anchor) + Vector2i(0, 1)
	m.player.position = Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16)
	m.shop_room.open("prison")
	m.saveio.save_now()
	open_prison(lost)


# 자리를 잃는다(구속) — 좌석·직업·이력. 돌려주는 값은 잃은 직함(없으면 "")
func _seat_release(reason: String) -> String:
	var job := _job()
	if job.is_empty():
		return ""
	var title := str(job.get("name", GameData.me.get("job", "")))
	GameData.seat_clear_player()
	var hist: Array = GameData.me.get("job_history", [])
	hist.append({"inst": str(job.get("inst", "")), "rank": str(GameData.me.get("rank", "")),
		"job": str(GameData.me.get("job", "")), "from": _me_int("job_since_day"), "to": GameData.day, "reason": reason})
	GameData.me["job_history"] = hist
	GameData.me["job"] = ""
	GameData.me["rank"] = ""
	GameData.me["wage_pending"] = 0
	return title


# 교도소 창구 — 형이 있으면 복역, 없으면 안에서만 열리는 문
func open_prison(lost := "") -> void:
	m.dialog.close()
	var sen: Dictionary = GameData.me.get("sentence", {})
	if Net.is_guest() or sen.is_empty():
		m.dialog.open("교도소", _pr("closed"), [["나간다", null]])
		return
	var pages: Array = [{"text": _pr("in") % GameData.days_kor(int(sen.get("days", GameData.PRISON_DAYS)))}]
	if lost != "":
		pages.append({"text": _pr("seat_lost") % lost})
	pages[-1]["choices"] = [[_pr("serve_choice"), serve_sentence]]
	m.dialog.open_seq("교도소", null, pages)


# 복역 — 건너뛰기 경로. 밭은 마르고 제철 아닌 작물은 시들며, 사회의 아침이 한 번 돈다
func serve_sentence() -> void:
	if Net.is_guest():
		return
	var sen: Dictionary = GameData.me.get("sentence", {})
	if sen.is_empty():
		return
	m.dialog.close()
	var days := int(sen.get("days", GameData.PRISON_DAYS))
	var day0 := GameData.day
	GameData.prison_skip(days)
	# 밭 — 젖음은 마르고, 지나온 계절마다 제철 아닌 작물은 시든다(farm_cells 만 돈다)
	var seasons: Array = []
	for d in range(day0 + 1, GameData.day + 1):
		var sn := GameData.season_of_day(d)
		if sn not in seasons:
			seasons.append(sn)
	for cell: Dictionary in m.farming.farm_cells():
		cell.watered = false
		cell.wet_min = 0.0
		var cid := str(cell.get("crop_id", ""))
		if cid == "" or bool(cell.get("dead", false)) or not GameData.CROPS.has(cid):
			continue
		if m.village.in_greenhouse(Vector2i(int(cell.tx), int(cell.ty))):
			continue
		for sn in seasons:
			if sn not in GameData.CROPS[cid].seasons:
				cell.dead = true
				break
	GameData.society_new_day([0, 0, 0])
	GameData.note_later(str(GameData.SOCIETY_NOTES.prison_out))
	if m.shop_room.visible:
		m.shop_room.close()
	var t: Vector2i = m.door_tile(m.TOWN_PLOTS["prison"].anchor) + Vector2i(0, 1)
	m.player.position = Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16)
	m.dialog.open("교도소", _pr("out"), [[_pr("out_choice"), null]])
	m.saveio.save_now()


# ---- 대면 범죄 (S5a, 헌법 §5.2·§6.1) ----
#
# 강도·주먹다짐·살인은 굴림이 없다 — 마주 서 있으면 언제나 성립한다. 문제는 뒤다: 피해자의 진술이
# 곧 목격이라(facing_others) 강도·폭행은 다음날 반드시 기소되고, 살인은 본 사람이 있으면 100%,
# 없으면 아무 데도 없던 일이 된다(완전범죄). 손이 가는 사람은 정착민과 읍의 생성 NPC 뿐.

func _vl(key: String) -> String:
	return str(_lines("violence").get(key, ""))


func _facing_ok(nid: String, gate: String) -> bool:
	return not Net.is_guest() and _me_int("boldness_base", -1) != -1 \
		and GameData.boldness() >= int(GameData.GATE.get(gate, 55)) and GameData.victim_ok(nid)


func _witness_page(witnesses: Array, line: String) -> Dictionary:
	var wid := str(witnesses[0])
	return {"text": line, "name": _npc_name(wid), "portrait": _portrait(wid)}


# 강도 — 소지금 전부. 즉시 평판 −10, 호감 −40, 대범함 +4. 피해자가 본 사람이라 신고는 확정
func rob(nid: String) -> void:
	if not _facing_ok(nid, "violence"):
		return
	m.dialog.close()
	var witnesses := _witnesses(nid)
	var take: int = GameData.wallet_of(nid)
	GameData.npc_wallet[nid] = 0
	GameData.money += take
	GameData.today_earned += take
	GameData.bold_add(4.0)
	GameData.aff_add(nid, -40)
	_rep_add(-GameData.ROBBERY_REP, region_here())
	_remember("robbery", nid, [nid] + witnesses, maxi(take, 50), true, 3)
	var pages: Array = [{"text": (_vl("rob_ok") % take) if take > 0 else _vl("rob_empty")},
		{"text": _vl("rob_victim"), "name": _npc_name(nid), "portrait": _portrait(nid)}]
	if not witnesses.is_empty():
		pages.append(_witness_page(witnesses, str(GameData.SOCIETY_LINES.theft.witness[posmod(GameData.day, 3)])))
	pages[-1]["choices"] = [[_vl("leave"), null]]
	m.dialog.open_seq("", null, pages)
	m.saveio.save_now()


# 주먹다짐 — 이길 확률 0.45 + 전투 Lv × 0.06. 이기면 상대가 이틀 눕고(대범함 +3), 지면 기력 −40
func assault(nid: String, roll := -1.0) -> void:
	if not _facing_ok(nid, "violence"):
		return
	m.dialog.close()
	var witnesses := _witnesses(nid)
	var p: float = clampf(GameData.FIGHT_P_BASE + GameData.FIGHT_P_LV * float(GameData.skills.get("combat", {}).get("lv", 0)), 0.2, 0.9)
	var pages: Array = []
	if _roll(roll) < p:
		GameData.npc_down[nid] = GameData.day + GameData.ASSAULT_DOWN_DAYS
		GameData.bold_add(3.0)
		GameData.aff_add(nid, -40)
		GameData.note_later(str(GameData.SOCIETY_NOTES.assault_down) % _npc_name(nid))
		pages.append({"text": _vl("assault_win")})
	else:
		GameData.energy = maxf(0.0, GameData.energy - 40.0)
		GameData.bold_add(1.0)
		GameData.aff_add(nid, -20)
		pages.append({"text": _vl("assault_lose")})
	_remember("assault", nid, [nid] + witnesses, 50, true, 2)
	pages.append({"text": _vl("assault_victim"), "name": _npc_name(nid), "portrait": _portrait(nid)})
	if not witnesses.is_empty():
		pages.append(_witness_page(witnesses, str(GameData.SOCIETY_LINES.theft.witness[posmod(GameData.day, 3)])))
	pages[-1]["choices"] = [[_vl("leave"), null]]
	m.dialog.open_seq("", null, pages)
	m.saveio.save_now()


# 살인 — 사람이 사라진다. 정착민은 집이 비고(편지는 없다), 생성 NPC 는 돌아오지 않는다.
# 본 사람이 있으면 마을이 안다(정착민 호감 −30, 평판 −20, heat 5 신고). 없으면 아무 데도 없던 일
func murder(nid: String) -> void:
	if not _facing_ok(nid, "murder"):
		return
	m.dialog.close()
	var witnesses := _witnesses(nid)
	var name := _npc_name(nid)
	GameData.dead.append(nid)
	if GameData.gen_npcs.has(nid):
		GameData.gen_npcs[nid]["here"] = false
		GameData.gen_npcs[nid]["away_until"] = 0
		GameData._gen_seats_sync()
	else:
		GameData.settlers.erase(nid)
		if GameData.settler_leaving == nid:
			GameData.settler_leaving = ""
		if GameData.settler_homes.has(nid):
			GameData.empty_houses.append(GameData.settler_homes[nid])
			GameData.settler_homes.erase(nid)
	if GameData.spouse == nid:
		GameData.spouse = ""
	if GameData.dating == nid:
		GameData.dating = ""
	for n in m.npcs.duplicate():
		if str(n.id) == nid:
			m.npcs.erase(n)
			n.queue_free()
	GameData.bold_add(5.0)
	var seen := not witnesses.is_empty()
	_remember("murder", nid, witnesses, 100, seen, 5)
	var pages: Array = [{"text": _vl("murder_done")}]
	if seen:
		_rep_add(-GameData.MURDER_REP, region_here())
		for sid in GameData.settlers:
			GameData.aff_add(str(sid), -GameData.MURDER_AFF_HIT)
		GameData.note_later(str(GameData.SOCIETY_NOTES.murder_known) % name)
		pages.append(_witness_page(witnesses, _vl("murder_witness")))
	else:
		GameData.note_later(str(GameData.SOCIETY_NOTES.murder_quiet) % name)
	pages[-1]["choices"] = [[_vl("leave"), null]]
	m.dialog.open_seq("", null, pages)
	m.saveio.save_now()

