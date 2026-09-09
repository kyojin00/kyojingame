# 상호작용 — 무엇을 겨누고 있고, 키를 누르면 무슨 일이 벌어지는가.
#
# 키는 둘로 갈라져 있다.
#   F(`talk`)  — 말 걸기. 사람과 가축만 본다. 아무도 없으면 말 타기로 넘어간다.
#   E(`interact`) — 그 밖의 전부. 벌목·채광·채집·문·계산대·표지판...
# 예전에는 E 하나가 캐기와 말 걸기를 겸해서, 나무를 연타하다 옆 사람에게
# 말이 걸리곤 했다. 키를 가른 뒤로는 그 새는 길이 아예 없다.
#
# 겨눔은 두 갈래다. 마우스가 움직이면 그 칸, 아니면 바라보는 쪽 한 칸
# (`target_tile`). 클릭으로 고른 칸이 있으면 그것이 우선한다.
#
# `interact`는 가까운 것부터 훑는다 — 곤충 > 채집물 > 오브젝트 > 문 > 도구.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinActions
extends Node

var m: KyojinMain    # main.gd


func _door_kind_at(t: Vector2i) -> String:
	if GameData.house_lv >= 1 and t == m.door_tile(m.HOME_ANCHOR):
		return "home"
	if GameData.forest_quest in ["visit", "done"] \
			and t == m.door_tile(m.FOREST_HOUSE_ANCHOR):
		return "forest_house"
	if GameData.story12_phase in ["path", "gather", "done"] \
			and t == m.door_tile(m.ALCH_HOUSE_ANCHOR):
		return "alch_house"
	if GameData.move_house.x >= 0 and t == m.door_tile(GameData.move_house):
		return "move_house"
	for pid: String in GameData.village_built:
		if m.VILLAGE_PLOTS.has(pid) and t == m.door_tile(m.VILLAGE_PLOTS[pid].anchor):
			return pid
	return ""


func _enter_building(kind: String) -> void:
	m.riding.dismount_horse()   # 말을 타고 실내로 들어갈 수는 없다
	if kind == "home":
		m.interior.open()
		return
	if kind == "move_house":
		m.dialog.open("재민의 집",
			"새 주민 재민의 집이다. 문패에 나침반이 그려져 있다.\n(재민은 마을 어딘가를 쏘다니는 중이다)",
			[["닫기", null]])
		return
	if kind == "forest_house":
		# 숲속의 집 (스토리 5): 이장과 함께 온 날이면 문 앞 장면,
		# 연화가 마음을 연 날이면 처음으로 안에 들어간다
		if GameData.forest_quest == "go":
			m.story._start_forest_house_dialog()
		elif GameData.forest_trust == "invited":
			m.story._start_forest_trust_dialog()
		elif GameData.forest_trust == "done":
			m.dialog.open("숲속의 집",
				"문이 반쯤 열려 있다.\n안에서 약초 달이는 향과 솔이의 웃음소리가 난다.",
				[["닫기", null]])
		else:
			m.dialog.open("숲속의 집",
				"문은 굳게 닫혀 있다.\n창문 너머로 인기척만 조용히 오간다.",
				[["닫기", null]])
		return
	if kind == "alch_house":
		# 연금술사의 오두막 (스토리 12): 첫 만남 -> 재료 시험 -> 시연
		m.story._alch_house_door()
		return
	if m.shop_room.has_room(kind):
		# 주인이 아직 첫 인사를 안 했으면 이사 준비 중 — 문이 닫혀 있다
		var owner := str(m.VILLAGE_NPC.get(kind, ""))
		if owner != "" and owner != "fisher" and not GameData.npc_greeted.has(owner):
			m.hud.show_message("이사 준비로 분주한 모양이다.\n내일 주인이 직접 인사하러 온다고 했다.", 4.0)
			return
		# 공공 건물은 영업시간에만 문을 연다 (개인 주거지는 해당 없음)
		var why := GameData.shop_closed_why()
		if why != "":
			m.dialog.open(str(m.BUILDING_NAMES.get(kind, "건물")),
				m.shop_room.closed_text(why) + "\n\n" + GameData.shop_hours_line(),
				[["돌아선다", null]])
			return
		m.shop_room.open(kind)   # 가게마다 다른 방으로 들어간다
		return
	m.hud.show_message("%s다. 아직 안에서 할 수 있는 일은 없다." %
		m.BUILDING_NAMES.get(kind, "건물"))


# 마우스가 움직일 때 main이 여기에 화면 좌표를 적어 둔다 (main._unhandled_input).
# 창 시스템에 매 프레임 묻지 않기 위해서다.
var mouse_screen := Vector2(-9999, -9999)


# 씨앗만 멀리서도 뿌릴 수 있다.
#
# 갈아 둔 밭에 심으려고 한 칸씩 밟고 다니면, 넓은 밭일수록 심는 시간보다
# 걸어다니는 시간이 길어진다. 씨앗은 던져 뿌리는 것이니 마우스로 가리킨
# 자리에 바로 들어가게 한다 — 그래도 「갈아 둔 내 밭」이라는 조건은 그대로다.
# (호미·물뿌리개·도끼처럼 몸을 쓰는 도구는 예전대로 바로 옆 한 칸뿐이다)
const SEED_REACH := 10


func reach_tiles() -> int:
	return SEED_REACH if GameData.tool == "seed" else 1


# 손이 닿는 자리인가. 한 칸일 때는 대각선까지 여덟 칸(예전 그대로),
# 멀리 뿌릴 때는 반지름 안쪽이면 된다 (네모로 재면 구석이 14칸까지 간다)
func in_reach(d: Vector2i) -> bool:
	var r := reach_tiles()
	if r <= 1:
		return absi(d.x) <= 1 and absi(d.y) <= 1
	return Vector2(d).length() <= float(r)


func _update_mouse_target() -> void:
	if m.player == null:
		m._mouse_target = Vector2i(-999, -999)
		return
	# 화면 -> 월드 변환만 매 프레임 한다 (이건 싸다)
	var mp: Vector2 = m.get_canvas_transform().affine_inverse() * mouse_screen
	var t := Vector2i(int(floor(mp.x / m.TILE)), int(floor(mp.y / m.TILE)))
	var d := t - m.player_tile()
	if d != Vector2i.ZERO and in_reach(d):
		m._mouse_target = t
	else:
		m._mouse_target = Vector2i(-999, -999)


func target_tile() -> Vector2i:
	if m._target_override.x != -999:
		return m._target_override  # 원격 플레이어 행동 처리 중
	if m._sel_target.x != -999:
		var d := m._sel_target - m.player_tile()
		if in_reach(d):
			return m._sel_target  # 좌클릭으로 고정한 선택
		m._sel_target = Vector2i(-999, -999)  # 멀어지면 선택 해제
	if m._mouse_target.x != -999:
		return m._mouse_target
	var dirs := {
		"down": Vector2i(0, 1), "up": Vector2i(0, -1),
		"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
	}
	return m.player_tile() + dirs[m.player.dir]


func _current_perp() -> Vector2i:
	if m._perp_override != Vector2i.ZERO:
		return m._perp_override
	return Vector2i(0, 1) if m.player.dir in ["left", "right"] else Vector2i(1, 0)


func can_use_tile(t: Vector2i) -> bool:
	# 마을/길은 공용, 나머지는 부지 소유 여부를 따른다
	return m._tile_accessible(t)


func _face_tile(t: Vector2i) -> void:
	var d := t - m.player_tile()
	if d == Vector2i.ZERO:
		return
	if absi(d.x) >= absi(d.y):
		m.player.dir = "right" if d.x > 0 else "left"
	else:
		m.player.dir = "down" if d.y > 0 else "up"


func _blocking_object_tile() -> Vector2i:
	if m.player == null:
		return Vector2i(-999, -999)
	var dirs := {"down": Vector2(0, 1), "up": Vector2(0, -1),
		"left": Vector2(-1, 0), "right": Vector2(1, 0)}
	var probe: Vector2 = m.player.position + (dirs[m.player.dir] as Vector2) * 14.0
	var pt := m.player_tile()
	var best := Vector2i(-999, -999)
	var best_d := 1e9
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var n: Vector2i = pt + Vector2i(dx, dy)
			if not m.objects.has(n) or not m.AIM_KINDS.has(m.objects[n].kind):
				continue
			var pad: Vector2 = m.OBJECT_PAD.get(m.objects[n].kind, Vector2.ZERO)
			var r := Rect2(n.x * m.TILE - pad.x, n.y * m.TILE - pad.y,
				m.TILE + pad.x * 2.0, m.TILE + pad.y * 2.0)
			if not r.has_point(probe):
				continue
			var d: float = (Vector2(n.x * m.TILE + 16, n.y * m.TILE + 16) - m.player.position).length()
			if d < best_d:
				best_d = d
				best = n
	return best


# 대화키(F) — 앞에 있는 사람/가축에게 말을 건다.
#
# 말을 걸 상대를 찾아 실제로 무언가 했으면 true. 아무도 없으면 false를
# 돌려주고, 그때는 main이 같은 키를 말 타기로 넘긴다.
func talk() -> bool:
	if GameData.riding:
		return false          # 말 위에서는 F가 「내리기」다
	# 스토리 6: 우체국 터 앞에서 기다리는 우체부에게 편지를 부탁한다
	if m.story._book_post != null and m.story._book_post_mode == "stand" \
			and (m.player.position - m.story._book_post.position).length() < m.POSTMAN_TALK_DIST:
		m.story._start_book_post_dialog()
		return true
	# 우체부 아저씨에게 말 걸기 (첫 만남 / 동행 중 보조 대화)
	if m.story._postman != null and m.story._postman_state == "wait" \
			and (m.player.position - m.story._postman.position).length() < m.POSTMAN_TALK_DIST:
		m.story._postman_state = "talk"
		m.story._start_postman_dialog()
		return true
	if m.story._postman != null and m.story._postman_state == "follow" \
			and (m.player.position - m.story._postman.position).length() < m.POSTMAN_TALK_DIST:
		m.story._talk_to_postman()
		return true
	# 가까운 NPC와 대화
	var npc := nearby_npc()
	if npc != null:
		m.village._talk_to(npc)
		return true
	# 가까운 동물 쓰다듬기(=먹이 주기)
	var animal := nearby_animal()
	if animal != null:
		var def: Dictionary = GameData.ANIMALS[animal.type]
		if animal.fed:
			m.hud.show_message("%s는 이미 만족스러워 보인다." % def.name)
		else:
			animal.fed = true
			Sound.play_sfx("sfx_heart")
			m.toolwork.gain_skill("ranch", 6.0)   # 동물을 돌본 손길이 쌓인다
			m.story.story17_barn_work("care")     # 옛 헛간 이야기 (스토리 17)
			if Net.is_guest():
				m.netsync._req_feed.rpc_id(1, m.animals.find(animal))
			m.hud.show_message("%s를 쓰다듬었다! ♥ 내일 아침 %s을 준다." %
				[def.name, GameData.ITEMS[def.product].name])
		return true
	return false


func interact() -> void:
	# 말을 타고 있으면 E도 「내리기」로 친다 (기본은 F)
	if GameData.riding:
		m.riding.dismount_horse()
		return
	# 맞는 도구를 들고 나무/돌을 조준 중이면 채집이 최우선
	# (근처에 NPC가 있어도 대화가 끼어들지 않는다)
	var aim: Variant = m.objects.get(target_tile())
	if aim == null:
		# 앞 칸은 비었는데 걸음이 막힌다면, 막고 있는 그 오브젝트를 대상으로 삼는다
		var bt := _blocking_object_tile()
		if bt.x != -999:
			m._sel_target = bt
			aim = m.objects.get(bt)
	var forced := Vector2i(-999, -999)
	if aim == null:
		# 도구에 맞는 대상이 가까이 있으면 그쪽을 본다 (그림이 커서 정면이 어긋날 때).
		# 찾은 칸은 _target_override로 그대로 넘긴다 — target_tile()의 한 칸 제한에
		# 걸려 도구가 엉뚱한 빈 칸을 때리지 않게 한다.
		var nt: Vector2i = m.toolwork._tool_target_nearby()
		if nt.x != -999:
			forced = nt
			m._sel_target = nt
			_face_tile(nt)
			aim = m.objects.get(nt)
	if aim != null and not bool(aim.get("young", false)) \
			and ((aim.kind == "tree" and GameData.tool == "axe")
			or (aim.kind in ["rock", "bigrock"] and GameData.tool == "pickaxe")):
		m._work_lock = m.WORK_LOCK_TIME  # 캐는 중 — 잠시 E는 무조건 도구다
		var prev := m._target_override
		if forced.x != -999:
			m._target_override = forced
		m.toolwork.use_tool()
		m._target_override = prev
		return
	# 캐던 나무/돌이 마지막 한 방에 부서져도, 이어 누른 E가 엉뚱한 데로 새지 않는다
	if m._work_lock > 0.0:
		m.toolwork.use_tool()
		return
	# 곤충 잡기
	var bug := nearby_bug()
	if bug != null:
		var bid: String = bug.bug_id
		GameData.items[bid] += 1
		GameData.forage_caught[bid] = int(GameData.forage_caught.get(bid, 0)) + 1
		var bug_first: bool = not GameData.discovered.has(bid)
		GameData.discover(bid)
		Sound.play_sfx("sfx_catch")
		m.renderer.spawn_particles(m.player_tile(), "sparkle")
		# 「연구 노트에 기록」 안내는 처음 잡았을 때 한 번만
		m.hud.show_message("%s를 잡았다!%s" % [GameData.ITEMS[bid].name,
			" 연구 노트에 기록됐다." if bug_first else ""])
		bug.respawn()
		if Net.is_host():
			m.netsync._broadcast_stats()
		return
	for t in [target_tile(), m.player_tile()]:
		var obj: Variant = m.objects.get(t)
		if obj == null:
			continue
		if String(obj.kind).begins_with("forage_") or String(obj.kind) == "weed":
			var fid: String = obj.kind
			m.objnode._remove_object(t)
			if fid == "weed":
				GameData.queue_respawn("weed")   # 3~5일 뒤 다른 빈자리에서
			if fid in ["weed", "forage_herb"]:
				# 초록 풀숲은 기본이 잡초 — 약초는 1%짜리 행운이다
				fid = GameData.weed_drop_id()
			# 숲이든 해변이든 줍는 일은 「채집」 숙련 하나로 합산된다 —
			# 레벨이 오르면 어디서 줍든 한 번에 더 줍는다 (3Lv마다 +1)
			var got := GameData.beach_pick_count()
			m.toolwork.gain_skill("beach",
				6.0 if fid in m.BEACH_FORAGE else 3.0)
			var first_find: bool = not GameData.discovered.has(fid)
			GameData.items[fid] += got
			GameData.forage_caught[fid] = int(GameData.forage_caught.get(fid, 0)) + got
			GameData.discover(fid)
			# (팔찌는 모래밭 랜덤 드랍이 아니라 스토리 13의 낡은 상자에서 —
			#  두 분의 바위 곁, 특별한 입질로 얻는다)
			# 산호 조각·고대 조각: 처음 주우면 숨겨진 이야기/레시피가 열린다
			if first_find and fid in ["forage_coral", "forage_relic"]:
				m.story.hidden_beach_find(fid)
			Sound.play_sfx("sfx_harvest")
			m.renderer.spawn_particles(t, "sparkle")
			# 「연구 노트에 기록」 안내는 처음 얻었을 때 한 번만
			m.hud.show_message("%s%s 채집!%s"
				% [GameData.ITEMS[fid].name, " x%d" % got if got > 1 else "",
				" 연구 노트에 기록됐다." if first_find else ""])
			if Net.is_host():
				m.netsync._broadcast_area(t)
				m.netsync._broadcast_stats()
			elif Net.is_guest():
				m.netsync._req_gain.rpc_id(1, fid, got)
			return
		if obj.kind == "searock":
			m.hud.show_message("울퉁불퉁한 바위 능선이다. 이 너머가 바다인 모양이다.")
			return
		if obj.kind == "worldtree":
			m.cave.open(true)
			return
		if obj.kind == "housesite":
			m.village._open_build_dialog()
			return
		if obj.kind == "plotsite":
			# 옛 세이브에만 남은 상점 터 팻말 — 상점은 이제 처음부터 서 있다
			m.dialog.open("상점 터", "낡은 게시판이 서 있다. 상점은 광장 북쪽에 있다.", [["닫기", null]])
			return
		if obj.kind == "stall":
			m.village.open_stall()
			return
		if obj.kind == "trash_bin":
			m.village.open_trash_bin(t)
			return
		if obj.kind == "chief_hut":
			if GameData.chief_house_lv >= 1:
				m.dialog.open("이장의 집",
					"마을 사람들이 힘을 모아 지어 드린 이장님의 새 집이다.\n"
					+ ("낮에는 마을회관에서 업무를 보신다." if GameData.village_built.has("hall")
						else "창가에 화분이 가지런하다."),
					[["닫기", null]])
			else:
				m.dialog.open("이장의 오두막",
					"이장님이 사는 작고 낡은 오두막이다.\n"
					+ "마을이 살아나면 제대로 된 집을 지어 드리고 싶다...",
					[["닫기", null]])
			return
		if obj.kind == "home_sign":
			m.story.home_sign_dialog(t)   # 이 집을 누구 집으로 할까
			return
		if obj.kind == "homeplot":
			# 빈 집터 팻말 — 회수하면 집터가 가방으로 돌아온다
			var plot_btns: Array = []
			var plot_body := "새 주민을 위해 마련해 둔 빈 집터다.\n이주 희망 편지를 수락하면 여기에 집이 지어진다."
			if GameData.fisher_home == "build":
				# 용식의 부탁 — 여기에 집을 한 채 올린다 (주인은 표지판에서 정한다)
				plot_body = "새 주민을 위해 마련해 둔 빈 집터다.\n여기에 집을 한 채 지을까?"
				plot_btns.append(["집을 짓는다",
					m.story.build_fisher_home.bind(t)])
			plot_btns.append(["회수하기", m.story._pickup_home_plot.bind(t)])
			plot_btns.append(["닫기", null])
			m.dialog.open("빈 집터", plot_body, plot_btns)
			return
		if obj.kind == "board":
			m.village._open_quest_board()
			return
		if obj.kind == "auction":
			m.auction_ui.open()
			return
		if obj.kind == "sign" and t == m.OLD_SIGN:
			m.story.examine_old_sign()
			return
		if obj.kind == "old_book":
			m.story.examine_old_book(t)   # 메인 스토리 6 — 오래된 책 발견
			return
		if obj.kind == "sign" and t == m.GREENHOUSE_SIGN:
			m.village._open_greenhouse_dialog()
			return
		if obj.kind == "sign" and t == m.BRACELET_ROCK:
			m.story.examine_bracelet_rock()   # 메인 스토리 13 — 두 사람의 바위
			return
		if obj.kind == "sign" and t == m.FISH_SIGN:
			m.dialog.open("낚시터", "교진 마을 낚시터.\n\n강가에 서서 물을 보고 낚싯대를 던지면 된다.\n"
				+ "입질(!)이 오면 다시 E!\n\n붕어 · 잉어 · 메기... 그리고 아주 드물게\n황금잉어가 올라온다고 한다.",
				[["알겠다", null]])
			return
		if obj.kind == "horse":
			m.riding._mount_horse(t)   # 말 칸에서 E를 눌러도 탄다 (F가 기본)
			return
		if obj.kind == "cave":
			# 스토리 20 — 가장 깊은 곳의 돌문 이야기가 먼저다
			if GameData.story20_phase == "gate":
				m.story.gate_examine()
				return
			m.village._open_mine_dialog()
			return
		if obj.kind == "onsen":
			m.story.onsen_enter()   # 마을 온천 (메인 스토리 15) — 하루 한 번
			return
		if obj.kind == "old_barn":
			m.story.old_barn_examine()   # 옛 헛간 (메인 스토리 17)
			return
		if obj.kind == "seed_sprout":
			m.dialog.open("작은 새싹",
				"어디서도 본 적 없는 빛깔의 새싹이다.\n무엇이 될지는 아직 아무도 모른다.",
				[["가만히 바라본다", null]])
			return
		if obj.kind == "old_lookout":
			m.story.hill_lookout_examine()   # 옛 전망대 (메인 스토리 18)
			return
		if obj.kind in ["old_bench", "carved_stone", "bent_tree"]:
			# 전망대 언덕의 흔적 세 곳 — 살피면 두 분의 마지막이 드러난다
			for tid: String in m.HILL_TRACE_TILES:
				if m.HILL_TRACE_TILES[tid] == t:
					m.story.hill_trace(tid)
					break
			return
		if obj.kind == "house":
			_enter_building(_building_kind_at(t))
			return
	# 자연물: E키가 기본 상호작용 (나무=도끼 벌목, 돌=곡괭이 채광)
	var tobj: Variant = m.objects.get(target_tile())
	if tobj != null and tobj.kind == "tree":
		if bool(tobj.get("young", false)):
			m.hud.show_message("아직 어린 나무다. 다 자라면 벨 수 있다.")
		elif GameData.tool == "axe":
			m.toolwork.use_tool()
		else:
			m.hud.show_message("도끼가 필요하다. 숫자키로 도끼를 선택하자!")
		return
	if tobj != null and tobj.kind in ["rock", "bigrock"]:
		if GameData.tool == "pickaxe":
			m.toolwork.use_tool()
		else:
			m.hud.show_message("곡괭이가 필요하다. 숫자키로 곡괭이를 선택하자!")
		return
	# 그 밖에는 손에 든 것을 그대로 쓴다 — 호미로 밭 갈기, 씨앗 심기, 물 주기,
	# 수확, 낚시까지 전부 E 하나로 된다 (좌클릭과 같은 동작).
	# 앞에 아무것도 없으면 조용히 지나간다 (걸어다니며 E를 눌러도 메시지 없음)
	var tt := target_tile()
	var in_map: bool = tt.x >= 0 and tt.y >= 0 and tt.x < m.MAP_W and tt.y < m.MAP_H
	# 물가 — 낚싯대가 없으면 던질 것이 없다 (용식과 바닷길을 열어야 받는다)
	if in_map and str(m.grid[tt.y][tt.x].ground) == "water" \
			and not GameData.can_fish():
		m.hud.show_message("낚시대가 없다...")
		return
	var crop_ahead: bool = in_map and m.grid[tt.y][tt.x].crop_id != ""
	if crop_ahead or GameData.tool_slots.has(GameData.tool):
		m.toolwork.use_tool()


func _tile_overlaps_player(t: Vector2i) -> bool:
	var rect := Rect2(t.x * m.TILE - 2, t.y * m.TILE - 2, m.TILE + 4, m.TILE + 4)
	if rect.has_point(m.player.position):
		return true
	for pid in m.remote_players:
		if rect.has_point(m.remote_players[pid].position):
			return true
	return false


# 말을 걸 수 있는 거리 (칸 = 32px).
#
# 예전에는 48px — 한 칸 반이라 **바로 옆에 딱 붙어야만** 말이 걸렸다.
# 캐기와 말 걸기가 E 하나였을 때는 그래야 도끼질이 대화로 새지 않았지만,
# 대화키를 F로 가른 지금은 좁을 이유가 없다. 세 칸까지 늘리고,
# 바라보는 쪽을 재는 각도도 넉넉하게 열었다.
const TALK_DIST := 96.0     # 세 칸
const TALK_ANY := 40.0      # 이 안쪽이면 어느 쪽을 보고 있든 걸린다
const TALK_DOT := 0.1       # 그 밖에서는 「대충 그쪽을 보고 있으면」 된다
const PET_DIST := 76.0      # 가축 쓰다듬기


func nearby_npc() -> Node2D:
	# 말은 **바라보는 쪽**에 있는 사람부터 걸린다.
	# 여럿이 걸리면 가장 가까운 사람이다.
	var f: Vector2 = m.FACE_VECS[m.player.dir]
	var best: Node2D = null
	var best_d := 1e9
	for n in m.npcs:
		if not n.visible:
			continue  # 집에 들어간 NPC와는 만날 수 없다
		var v: Vector2 = n.position - m.player.position
		var d := v.length()
		if d >= TALK_DIST:
			continue
		if d > TALK_ANY and v.normalized().dot(f) < TALK_DOT:
			continue
		if d < best_d:
			best_d = d
			best = n
	return best


func nearby_animal() -> Node2D:
	for a in m.animals:
		if (a.position - m.player.position).length() < PET_DIST:
			return a
	return null


func _building_kind_at(t: Vector2i) -> String:
	if GameData.house_lv >= 1 and t.x >= m.HOME_ANCHOR.x and t.x < m.HOME_ANCHOR.x + 5 \
			and t.y >= m.HOME_ANCHOR.y and t.y < m.HOME_ANCHOR.y + 4:
		return "home"
	# 마을 건물은 실제로 지어진 것만 존재한다
	for pid: String in GameData.village_built:
		if not m.VILLAGE_PLOTS.has(pid):
			continue
		var a: Vector2i = m.VILLAGE_PLOTS[pid].anchor
		if t.x >= a.x and t.x < a.x + 5 and t.y >= a.y and t.y < a.y + 4:
			return pid
	return ""


func nearby_bug() -> Node2D:
	for bnode in m.bugs:
		if bnode.visible and (bnode.position - m.player.position).length() < 40.0:
			return bnode
	return null


func _click_at(pos: Vector2, dbl: bool) -> void:
	# 좌클릭 1회: 대상 선택 / 더블클릭: 선택 + 즉시 상호작용 (E·F키와 동일)
	var t := Vector2i(int(floor(pos.x / m.TILE)), int(floor(pos.y / m.TILE)))
	var d := t - m.player_tile()
	if not in_reach(d):
		m._sel_target = Vector2i(-999, -999)  # 먼 곳 클릭 = 선택 해제
		return
	if d != Vector2i.ZERO:
		# 스프라이트 방향은 우세한 축 기준 (대각선이면 좌우 우선)
		if d.x != 0:
			m.player.dir = "right" if d.x > 0 else "left"
		else:
			m.player.dir = "down" if d.y > 0 else "up"
	m._sel_target = t
	m.queue_redraw()
	if dbl:
		# 마우스만으로 즉시 상호작용: 사람·가축이면 말 걸기(F), 물건이면 E,
		# 빈 칸이면 손에 든 도구
		if m.objects.has(t) or nearby_bug() != null:
			interact()
		elif talk():
			return
		else:
			m.toolwork.use_tool()
