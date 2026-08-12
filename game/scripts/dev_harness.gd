# 개발용 검증 하네스 — 게임 로직이 아니다.
#
# KYOJIN_SHOT이 켜졌을 때만 붙는다. 정해진 프레임마다 게임을 조작하고,
# 결과를 print로 뱉고, 스크린샷을 남긴다. 여기서 나오는 `*_OK=...` 줄이
# 곧 이 게임의 회귀 테스트다.
#
#   KYOJIN_SHOT=<디렉터리>/ godot --path game        -> 51장 + 어서션
#   KYOJIN_SHOT=<디렉터리>/ KYOJIN_STORY=1 godot ...  -> 스토리 9장
#
# **단계 번호는 match의 갈래다. 번호가 겹치면 뒤에 온 갈래는 죽은 코드가 된다.**
# 새 단계를 넣기 전에 반드시 확인할 것:
#
#   grep -n "^\t\t[0-9]\+:" scripts/dev_harness.gd \
#     | sed 's/:\t\t/ /' | awk '{print $2}' | tr -d ':' | sort -n | uniq -d
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinHarness
extends Node

var m: KyojinMain    # main.gd
var _shot_frames := 0


# ---- 검증 시퀀스 ----
# 키/마우스 이벤트를 실제 InputMap 경로로 흘려보내
# 밭갈기->클릭 경작->물주기->파종->자원->설치->상점->결산까지 자동 재생한다.
#
# ※ 단계 번호는 match의 값이다. **절대 겹치면 안 된다** —
#    같은 번호를 두 번 쓰면 뒤에 쓴 쪽이 통째로 죽은 코드가 되고,
#    검사가 조용히 사라진다 (실제로 세 번 당했다).
#    새 단계를 넣기 전에: grep -n "^\t\t[0-9]\+:" 로 빈 번호를 확인할 것.

func _debug_tick() -> void:
	if OS.get_environment("KYOJIN_MP") != "":
		_mp_tick()
		return
	if Net.is_guest() and not m._net_ready:
		return  # 접속 완료 후부터 시퀀스 시작
	_shot_frames += 1
	if OS.get_environment("KYOJIN_STORY") != "":
		# 스토리 화면만 캡처하고 종료 (프레임 수가 아니라 스토리 진행 시간 기준 —
		# 헤드리스 환경은 프레임 속도가 들쭉날쭉하다)
		if not m.story._story_snapped and m.story._story_t >= 3.2:
			m.story._story_snapped = true
			_save_shot("_story.png")
			# 마을 진입로: 큰길(y8~10) 위아래가 벨 수 없는 나무로 막혀 있고,
			# 마을로 드는 길은 그 길 하나뿐이어야 한다
			print("ENTRANCE_OK=", not m.is_passable(Vector2i(52, 7))
				and not m.is_passable(Vector2i(52, 11))
				and m.is_passable(Vector2i(52, 9))
				and bool(m.objects.get(Vector2i(52, 7), {}).get("fixed", false)),
				" 위막힘=", not m.is_passable(Vector2i(52, 7)),
				" 아래막힘=", not m.is_passable(Vector2i(52, 11)),
				" 길열림=", m.is_passable(Vector2i(52, 9)))
		elif m.story._story_snapped and m.story._story_t >= 3.8:
			get_tree().quit()
		return
	match _shot_frames:
		10: _send_key(KEY_1)
		14: _send_key(KEY_E)                           # 아래 타일 밭 갈기 (E로도 된다)
		18: _send_click(Vector2((m.START_TILE.x + 1) * m.TILE + 16, m.START_TILE.y * m.TILE + 16))
		22: _send_key(KEY_2)
		26: _send_key(KEY_SPACE)                       # 물 주기
		30: _send_key(KEY_3)
		34: _send_key(KEY_E)                           # 씨앗 심기 (E로도 된다)
		36:
			GameData.wood = 5                          # 설치 테스트용 자원 지급
			GameData.stone = 5
		38: _send_key_press(KEY_A)
		42: _send_key_release(KEY_A)                   # 왼쪽 보기
		46: _send_key(KEY_7)
		50: _send_key(KEY_SPACE)                       # 울타리 설치
		54: _send_key_press(KEY_S)
		56: _send_key_release(KEY_S)                   # 아래 보기
		60: _send_key(KEY_8)
		64: _send_key(KEY_SPACE)                       # 스프링클러 설치
		66: _send_key(KEY_3)                           # 씨앗 도구로 컨텍스트 힌트 확인
		70: _save_shot("_game.png")
		71: m.map_ui.open()                              # 지도 확인
		73: _save_shot("_map.png")
		74:
			m.map_ui.close()
			m.player.position = Vector2(76 * m.TILE + 16, 12 * m.TILE + 16)
			m.player.dir = "right"                       # 마을 광장 게시판 앞으로
			for n in m.npcs:                             # 게시판 캡처를 위해 NPC를 비켜둔다
				n.position = Vector2(62 * m.TILE + 16, 25 * m.TILE + 16)
				n.target = n.position
		78: _send_key(KEY_E)
		84: _save_shot("_quest.png")
		86: m.dialog.close()
		87:
			m.player.position = Vector2(74 * m.TILE + 16, 20 * m.TILE + 16)
			m.player.dir = "up"                          # 중앙 광장(건물 없는 초기 마을)
		89: _save_shot("_village.png")
		90:
			m.player.position = m.npcs[0].position + Vector2(12, 0)
		94: _send_key(KEY_E)                           # NPC 대화
		100: _save_shot("_npc.png")
		101:
			GameData.produce["potato"] = 3             # 선물 고르기 확인
			GameData.items["egg"] = 2
			m.village._open_gift_picker("chief")
		103: _save_shot("_gift.png")
		104:
			m.village._close_gift_picker()
			m.dialog.close()
			GameData.money = 200000
		122: m.interior.open()                           # 집 내부 확인
		128: _save_shot("_house.png")
		129: _send_key(KEY_F)                          # 꾸미기 모드
		133: _save_shot("_deco.png")
		134: _send_key(KEY_F)                          # 꾸미기 종료
		136:
			m.interior.ppos = Vector2(645, 174)         # 조리대 앞으로
			GameData.kitchen_found = true               # 주방 격자 캡처용 (청소는 382가 검사)
			GameData.recipes_cooked["dish_soup"] = 1    # 컬러/회색 셀이 섞여 보이게
		137: _save_shot("_kitchen.png")                # 조리대 그림 확인
		138: _send_key(KEY_E)                          # 주방 열기
		142: _save_shot("_cook.png")
		144:
			m.cooking_ui.close()
			m.interior.close()
			m.inventory_ui.toggle()                      # 인벤토리(도구/능력치) 확인
			GameData.tool_level["axe"] = 2
		146: m.inventory_ui.hover_stat_tool()             # 장비 능력치 툴팁 확인
		148: _save_shot("_inv.png")
		149: m.inventory_ui.show_tab("res")               # 자원 탭 확인
		151: _save_shot("_inv2.png")
		152:
			m.inventory_ui.close()
			GameData.owned_pets = ["dog"]              # 펫 확인
			GameData.active_pet = "dog"
			m.pet.position = m.player.position + Vector2(14, 4)
		156: _save_shot("_pet.png")
		158: m.cave.open()                               # 동굴 확인
		160: _send_key(KEY_SPACE)                      # 공격 모션
		162: _save_shot("_cave.png")
		164: m.cave.close()
		166: m.quest_ui.toggle()                         # 퀘스트 창(Q) 확인
		170: _save_shot("_questwin.png")
		172:
			m.quest_ui.close()
			GameData.crops_harvested = {"potato": 3, "carrot": 1}
			GameData.affinity["merchant"] = 60
			# 도감 격자가 「얻은 것/못 얻은 것」을 갈라 그리는지 보이게 몇 개 심는다
			GameData.discover("potato")
			GameData.discover("carrot")
			GameData.discover("fish_crucian")
			GameData.fish_caught["fish_crucian"] = 2
			m.note_ui.toggle()                           # 연구 노트(N) 확인
		176: _save_shot("_note.png")
		177:
			m.note_ui.close()
			GameData.tool_level["axe"] = 2             # 장비 능력치 확인
			GameData.tool_level["hoe"] = 3
			m.stats_ui.toggle()
		179: m.stats_ui.scroll_to_bottom()               # 장비 능력치까지 확인
		181: _save_shot("_stats.png")
		183:
			m.stats_ui.close()
			GameData.wood = 999                        # 마을 발전(건설) 확인
			GameData.stone = 999
			m.village._build_village_building("post")
			m.village._build_village_building("general")
			m.village._build_village_building("smith")
			m.dialog.close()
			m.player.position = Vector2(74 * m.TILE + 16, 11 * m.TILE + 16)
			m.player.dir = "up"
		186: _save_shot("_village2.png")
		187: m.shop_room.open("general")                 # 가게 방 (잡화점)
		190: _save_shot("_shoproom.png")
		191: m.shop.open("buy", ["buy", "sell"], "잡화점")
		193: _save_shot("_shop.png")
		194: m.shop.close()
		195:
			m.shop_room.close()
			m.shop_room.open("smith")                    # 가게 방 (대장간)
		197: _save_shot("_shoproom2.png")
		198:
			m.shop_room.close()
			GameData.gender = "m"                      # 남자 캐릭터 뒷모습 걷기 확인
			_send_key_press(KEY_W)
		202: _save_shot("_boy_back.png")
		203:
			_send_key_release(KEY_W)
			_send_key_press(KEY_S)                     # 앞모습 걷기 확인
		204: _save_shot("_boy_front.png")
		205:
			_send_key_release(KEY_S)
			_send_key_press(KEY_D)                     # 옆모습 걷기 확인
		209: _save_shot("_boy_side.png")
		210:
			_send_key_release(KEY_D)
			m.player.position = Vector2(88 * m.TILE + 16, 2 * m.TILE + 16)  # 맵 끝 배경 확인
		213: _save_shot("_edge.png")                    # 맵 밖 배경 + 가운데 정렬
		214:
			# 낚시터 (마을 남쪽 강가 부두)
			m.player.position = Vector2(74 * m.TILE + 16, m.DOCK_Y * m.TILE + 16)
			m.player.dir = "down"
			m.toolwork.set_tool("rod")
		217: _save_shot("_pier.png")
		218:
			# 회귀 검사: 비가 와서 이미 젖은 밭에서도 「50% 물주기」가 되어야 한다
			var wt: Vector2i = m.player_tile() + Vector2i(0, 1)
			var wc: Dictionary = m.grid[wt.y][wt.x]
			m.objects.erase(wt)
			wc.ground = "soil"
			wc.crop_id = "potato"
			wc.crop_day = m.farming._grow_total(GameData.CROPS["potato"]) * 0.7
			wc.dead = false
			m.farming._wet(wc, m.WET_ALL_DAY)      # 비로 이미 젖은 상태
			wc.half_fed = false        # 아직 체크포인트 물은 안 줬다
			m.toolwork.set_tool("water")
			m._sel_target = wt
			m.player.dir = "down"
			m.actions.interact()
			print("WATER_CHECKPOINT_OK=", wc.half_fed)
			m._sel_target = Vector2i(-999, -999)

			# 회귀 검사: 커다란 바위 사이의 한 칸 틈은 계속 지나갈 수 있어야 한다
			# (퀘스트 5에서 바위 하나를 캐면 그 자리로 빠져나간다)
			var gap := Vector2i(20, 40)
			m.objects[gap + Vector2i(0, -1)] = {"kind": "bigrock", "hp": m.BIGROCK_HP}
			m.objects[gap + Vector2i(0, 1)] = {"kind": "bigrock", "hp": m.BIGROCK_HP}
			print("BIGROCK_GAP_OK=", m.is_passable_px(
				Vector2(gap.x * m.TILE + 16, gap.y * m.TILE + 16)))
			# 회귀 검사: 바위 옆에 서서 다른 쪽을 보고 있어도 E로 캘 수 있어야 한다
			m.player.position = Vector2(gap.x * m.TILE + 16, gap.y * m.TILE + 16)
			m.player.dir = "left"
			m.toolwork.set_tool("pickaxe")
			print("ROCK_SIDE_TARGET_OK=", m.toolwork._tool_target_nearby().x != -999)
			m.objects.erase(gap + Vector2i(0, -1))
			m.objects.erase(gap + Vector2i(0, 1))
		220:
			# 할아버지의 부탁: 기본 안내가 끝나면 첫 편지가 뜬다
			GameData.tutorial = {"active": false}
			GameData.grandpa_step = 0
			GameData.grandpa_seen = false
			m.dialog.close()
		222: _save_shot("_grandpa.png")
		223:
			# 조건을 채우면 다음 부탁으로 넘어간다
			GameData.crops_harvested = {"potato": 1, "carrot": 1, "strawberry": 1}
			m.dialog.close()
		# 진행도 확인은 0.5초 간격으로 도니 프레임을 넉넉히 준다
		260: print("GRANDPA_STEP=", GameData.grandpa_step)
		261:
			# NPC 하루 일과: 시각별로 갈 곳이 바뀌는지 확인
			var sched := []
			for h in [7, 10, 13, 17]:
				GameData.minutes = h * 60.0
				sched.append("%d시=%s" % [h, m.npcmgr.npc_place_now("merchant")])
			print("NPC_SCHEDULE=", ", ".join(sched))
			GameData.minutes = 13.0 * 60.0       # 낮: 다들 광장으로 모인다
			m.dialog.close()
			m.player.position = Vector2(74 * m.TILE + 16, 17 * m.TILE + 16)
		300:
			# 대장간 장비: 제작 -> 자동 장착 -> 능력치 적용까지 확인
			GameData.money = 100000
			GameData.wood = 500
			GameData.stone = 500
			GameData.items["ore"] = 100
			GameData.discover("ore")   # 겪어 본 재료만 벼려 준다 (SHOP_GATE)
			var made: bool = GameData.craft_gear("gear_sword_iron")
			GameData.craft_gear("gear_vest_leather")
			GameData.craft_gear("gear_charm_ember")
			print("GEAR_CRAFT_OK=", made, " power=", GameData.gear_stat("power"),
				" def_mult=", GameData.gear_defense_mult(),
				" stam_mult=", GameData.gear_stamina_mult())
			m.shop.open("upgrade", ["upgrade", "craft"], "대장간")
			m.shop._on_tab("craft")
		303: _save_shot("_craft.png")
		304:
			m.shop.close()
			m.inventory_ui.toggle()
			m.inventory_ui.show_tab("gear")
		307: _save_shot("_gear.png")
		308: m.inventory_ui.close()
		310:
			# 계절 축제: 봄 꽃놀이 날로 옮겨 장식·모임·진행을 확인
			GameData.day = 14
			GameData.minutes = 11.0 * 60.0
			GameData.reset_festival_state()
			var ft: Dictionary = GameData.festival_today()
			print("FESTIVAL_TODAY=", ft.get("name", "없음"),
				" open=", GameData.festival_open(),
				" npc_place=", m.npcmgr.npc_place_now("merchant"))
			m.player.position = Vector2(74 * m.TILE + 16, 14 * m.TILE + 16)
			m.objnode._apply_season_visuals()
		313: _save_shot("_festival.png")
		314:
			# 인사를 다 채우면 축제가 끝나고 상금이 나온다
			for nid: String in GameData.NPCS:
				if not GameData.fest_greeted.has(nid):
					GameData.fest_greeted.append(nid)
			m.village._finish_festival()
			print("FESTIVAL_DONE=", GameData.fest_done,
				" history=", ", ".join(GameData.fest_history))
		316: _save_shot("_festival2.png")
		317: m.dialog.close()
		318:
			# 여관·연구소·도서관: 새 방 세 곳
			m.shop_room.open("lab")
			m.room_action("breed")
		320: _save_shot("_lab.png")
		321:
			GameData.money = 100000
			GameData.items["ore"] = 100
			m.village._do_breed()
			m.dialog.close()
			m.shop_room.close()
			m.shop_room.open("library")
			m.room_action("read")
			print("BREED_LEVEL=", GameData.breed_level,
				" grow=", GameData.breed_grow_mult(),
				" price=", GameData.breed_price_mult())
		323: _save_shot("_library.png")
		324:
			m.dialog.close()
			m.shop_room.close()
			m.shop_room.open("inn")
			GameData.energy = 20.0
			m.room_action("rest")
		326: _save_shot("_inn.png")
		327:
			m.village._do_rest()
			print("INN_REST_OK=", GameData.energy >= GameData.ENERGY_MAX)
			m.dialog.close()
			m.shop_room.close()
		328:
			# 광산 승강기: 깊이 기록 -> 시작 층 고르기
			GameData.mine_deepest = 12
			print("MINE_FLOORS=", GameData.mine_floors())
			# 온실: 짓고 나면 겨울에도 심을 수 있어야 한다
			GameData.wood = 999
			GameData.stone = 999
			GameData.money = 99999
			m.village._build_greenhouse()
			m.dialog.close()
			GameData.day = GameData.DAYS_PER_SEASON * 3 + 1   # 겨울
			m.objnode._apply_season_visuals()
			m.player.position = Vector2((m.GREENHOUSE.position.x + 4) * m.TILE + 16,
				(m.GREENHOUSE.end.y + 1) * m.TILE + 16)
			print("GREENHOUSE_OK=", GameData.greenhouse_built,
				" winter_plantable=", m.village.in_greenhouse(m.GREENHOUSE.position))
		331: _save_shot("_greenhouse.png")
		332:
			# 지도 휠·끌기: 이벤트가 실제로 map_ui까지 닿는지 확인한다.
			# (Control의 mouse_filter가 STOP이면 _unhandled_input이 아예 안 불린다)
			# 세워 둔 말이 지도에 표시되는지도 함께 본다
			GameData.has_horse = true
			GameData.riding = false
			GameData.horse_tile = m.HORSE_HOME
			m.map_ui.open()
			_push_mouse_button(MOUSE_BUTTON_WHEEL_UP, Vector2(480, 270), true)
		333:
			var zoomed: bool = m.map_ui.zoom > 1.0
			_push_mouse_button(MOUSE_BUTTON_LEFT, Vector2(400, 270), true)
			var mm := InputEventMouseMotion.new()
			mm.position = Vector2(440, 290)
			mm.relative = Vector2(40, 20)
			get_viewport().push_input(mm)
			_push_mouse_button(MOUSE_BUTTON_LEFT, Vector2(440, 290), false)
			print("MAP_ZOOM_OK=", zoomed, " MAP_DRAG_OK=", m.map_ui.pan != Vector2.ZERO)
			# 회귀 검사: 끌던 손을 **HUD 핫바 위에서** 놓아도 끌기가 끝나야 한다.
			# 핫바는 진짜 Button이라 GUI 단계에서 「놓기」를 먹어 버린다 —
			# 그러면 지도가 손을 뗀 뒤에도 마우스를 계속 따라다녔다.
			# HUD를 일부러 다시 켜서 그때 상황을 그대로 재현한다.
			m.hud.visible = true
			m.map_ui._drag = true
			_push_mouse_button(MOUSE_BUTTON_LEFT, Vector2(480, 512), false)
			var stuck: bool = m.map_ui._drag
			var pan_before: Vector2 = m.map_ui.pan
			var mm2 := InputEventMouseMotion.new()
			mm2.position = Vector2(520, 330)
			mm2.relative = Vector2(80, 40)
			get_viewport().push_input(mm2)
			print("MAP_DRAG_RELEASE_OK=", not stuck and m.map_ui.pan == pan_before)
			m.hud.visible = false
			# 회귀 검사: 아무리 세게 끌어도 지도가 화면 밖으로 밀려나면 안 된다.
			# (예전 규칙은 지도 크기의 절반까지 허용해서, 기본 배율에서도
			#  지도가 한쪽으로 확 밀려 나가 절반이 빈 화면이 됐다)
			m.map_ui._drag = true
			for i in 6:
				var big := InputEventMouseMotion.new()
				big.position = Vector2(900, 500)
				big.relative = Vector2(900, 500)
				get_viewport().push_input(big)
			m.map_ui._drag = false
			var pc: float = m.map_ui._base_cell() * m.map_ui.zoom
			var org: Vector2 = m.map_ui._origin(pc)
			var mrect := Rect2(org, Vector2(m.MAP_W * pc, m.MAP_H * pc))
			print("MAP_PAN_LIMIT_OK=", mrect.has_point(Vector2(480, 270)),
				" pan=", m.map_ui.pan.round(), " map=", mrect.size.round())
			m.map_ui.reset_view()
		335: _save_shot("_mapdrag.png")
		336: m.map_ui.close()
		337:
			# 상인 대화 메뉴: 계산대 E -> 인사말 + [판매/대화/퀘스트❗/그만두기].
			# 퀘스트 선택지는 실제 퀘스트 이름으로, 「그만두기」 바로 위에 선다.
			GameData.merchant_errand = ""
			GameData.sea_open = true           # 노점 퀘스트는 바다가 열려야 보인다
			m.village.open_merchant_counter()
			var labels: Array = []
			var bang_ok := false
			for c in m.dialog.buttons_box.get_children():
				if c.is_queued_for_deletion() or not (c is Button):
					continue
				labels.append((c as Button).text.strip_edges())
				for cc in c.get_children():
					if cc is Label and (cc as Label).text == "!":
						bang_ok = true
			var menu_ok: bool = m.dialog.visible and labels.size() == 4 \
				and labels[0] == "판매하기" and labels[1] == "대화하기" \
				and labels[2] == m.village.MERCHANT_QUEST_NAME \
				and labels[3] == "대화 그만두기"
			# 바다가 닫혀 있으면 퀘스트 선택지가 아예 안 보인다
			GameData.sea_open = false
			m.village.open_merchant_counter()
			var closed_n := 0
			for c2 in m.dialog.buttons_box.get_children():
				if not c2.is_queued_for_deletion() and c2 is Button:
					closed_n += 1
			GameData.sea_open = true
			print("MERCHANT_TALK_OK=", menu_ok and bang_ok and closed_n == 3,
				" 메뉴=", menu_ok, " 느낌표=", bang_ok, " 바다전=", closed_n, "개(3)")
			# 퀘스트 수락 -> 재료 전달 -> 노점 설치 + 방문 시각 3개
			m.village._merchant_errand_start()
			var doing: bool = GameData.merchant_errand == "doing"
			GameData.wood += GameData.STALL_WOOD
			GameData.items["forage_shell"] = int(GameData.items.get("forage_shell", 0)) \
				+ GameData.STALL_SHELLS
			var shell_before := int(GameData.items["forage_shell"])
			m.village._merchant_errand_turnin()
			var built: bool = GameData.merchant_errand == "done" \
				and str(m.objects.get(m.STALL_TILE, {}).get("kind", "")) == "stall" \
				and int(GameData.items["forage_shell"]) \
					== shell_before - GameData.STALL_SHELLS
			var sched_ok: bool = GameData.stall_hours.size() == GameData.STALL_VISITS
			for i in GameData.stall_hours.size():
				var s := int(GameData.stall_hours[i])
				if s < 9 * 60 or s > 18 * 60:
					sched_ok = false
				if i > 0 and s - int(GameData.stall_hours[i - 1]) < GameData.STALL_VISIT_MIN:
					sched_ok = false
			m.dialog.close()
			print("STALL_QUEST_OK=", doing and built and sched_ok,
				" 수락=", doing, " 설치=", built, " 시각표=", sched_ok,
				" ", GameData.stall_hours)
		339:
			# 노점 이용: 민지가 있을 때만 구매(미끼·한정 레시피), 판매는 상시
			var keep_min: float = GameData.minutes
			GameData.minutes = float(GameData.stall_hours[0]) + 5.0
			var here: bool = GameData.merchant_at_stall()
			m.village.open_stall()
			var open_full: bool = m.shop.visible and m.shop.allowed == ["buy", "sell"] \
				and m.shop.tab == "buy"
			var money0: int = GameData.money
			var bait0 := int(GameData.items.get("bait", 0))
			m.shop._on_buy_bait()
			var bait_ok: bool = int(GameData.items["bait"]) == bait0 + 1 \
				and GameData.money == money0 - GameData.BAIT_PRICE
			var locked0: bool = GameData.recipe_locked("dish_smelt_fry")
			m.shop._on_buy_dish_recipe("dish_smelt_fry", GameData.STALL_RECIPES["dish_smelt_fry"])
			var recipe_ok: bool = locked0 and not GameData.recipe_locked("dish_smelt_fry")
			m.shop.close()
			GameData.minutes = 8.0 * 60.0        # 이른 아침 — 민지가 없다
			var away: bool = not GameData.merchant_at_stall()
			m.village.open_stall()
			var sell_only: bool = m.shop.visible and m.shop.allowed == ["sell"]
			m.shop.close()
			GameData.minutes = keep_min
			# 해변 채집물 확장: 쓰레기/유리 그림·아이템 등록 확인
			var kinds_ok: bool = m.tex.get("forage_trash") != null \
				and m.tex.get("forage_glass") != null and m.tex.get("stall") != null \
				and m.tex.get("bait") != null and GameData.ITEMS.has("forage_trash") \
				and GameData.ITEMS.has("forage_glass")
			print("STALL_SHOP_OK=", here and open_full and bait_ok and recipe_ok
				and away and sell_only and kinds_ok,
				" 방문중=", here, " 구매판매=", open_full, " 미끼=", bait_ok,
				" 레시피=", recipe_ok, " 부재=", away, " 판매만=", sell_only,
				" 등록=", kinds_ok)
		338:
			# 퀘스트 5 재현: 바위벽 앞까지 실제 이동 판정으로 붙은 뒤 E
			var rx := 30
			var ry := 40
			# 주변을 비운다 — 흩어진 돌이 먼저 잡히면 무엇을 쟀는지 알 수 없다
			for cy in range(ry - 4, ry + 5):
				for cx in range(rx - 4, rx + 5):
					m.objects.erase(Vector2i(cx, cy))
			for yy in range(ry - 2, ry + 3):
				var rp := Vector2i(rx, yy)
				m.objects[rp] = {"kind": "bigrock", "hp": m.BIGROCK_HP}
				m.objnode._spawn_object_node(rp, "bigrock")
			m._sel_target = Vector2i(-999, -999)
			m._mouse_target = Vector2i(-999, -999)
			m.toolwork.set_tool("pickaxe")
			var py: float = ry * m.TILE + 16.0
			var px: float = (rx - 3) * m.TILE + 16.0
			while m.is_passable_px(Vector2(px + 1.0, py)):
				px += 1.0                       # 막힐 때까지 오른쪽으로 (실제 이동과 같은 판정)
			m.player.position = Vector2(px, py)
			m.player.dir = "right"
			var before: int = int(m.objects[Vector2i(rx, ry)].hp)
			m.actions.interact()
			var after: int = int(m.objects.get(Vector2i(rx, ry), {"hp": -1}).hp)
			print("ROCK_WALL: player_tile=", m.player_tile(), " rock_x=", rx,
				" target=", m.actions.target_tile(), " hp ", before, "->", after,
				" MINED_OK=", after != before)
			# 더 나쁜 상황: 두 칸 떨어져 반대쪽을 보고 있어도 캘 수 있어야 한다
			m._work_lock = 0.0
			m._sel_target = Vector2i(-999, -999)
			m.player.position = Vector2((rx - 2) * m.TILE + 16, py)
			m.player.dir = "left"
			var b2: int = int(m.objects[Vector2i(rx, ry)].hp)
			m.actions.interact()
			var a2: int = int(m.objects.get(Vector2i(rx, ry), {"hp": -1}).hp)
			print("ROCK_FAR: player_tile=", m.player_tile(), " (두 칸 떨어져 반대쪽 보기) hp ",
				b2, "->", a2, " MINED_OK=", a2 != b2)
		340:
			var where := []
			for n in m.npcs:
				where.append("%s:%s" % [n.id, n.place])
			print("NPC_PLACES=", ", ".join(where))
			_save_shot("_npcday.png")
		341:
			# 더블 클릭 자동 장착: 빈 앞 번호 슬롯부터 차고, 겹치지 않는다
			var keep_slots: Array = GameData.tool_slots.duplicate()
			GameData.tool_slots = []
			for i in GameData.TOOL_SLOT_COUNT:
				GameData.tool_slots.append("")
			m.inventory_ui._auto_equip("axe")
			m.inventory_ui._auto_equip("hoe")
			m.inventory_ui._auto_equip("axe")    # 중복 — 새 칸을 먹으면 안 된다
			print("QUICKSLOT_OK=", GameData.tool_slots[0] == "axe"
				and GameData.tool_slots[1] == "hoe" and GameData.tool_slots[2] == "",
				" 슬롯=", GameData.tool_slots.slice(0, 3))
			GameData.tool_slots = keep_slots
			# 마트: 선반 4개(카테고리 구매) + 판매는 가방 격자 + 툴팁
			m.shop_room.open("general")
			var shelves_ok: bool = m.shop_room.SHELVES.size() == 4 \
				and m.shop_room._shelf_near() == -1
			m.shop.open("buy", ["buy"], "잡화점 — 씨앗", "seed")
			var cat_ok: bool = m.shop.visible and m.shop.buy_cat == "seed"
			m.shop.close()
			m.shop.open("sell", ["sell"], "잡화점 — 판매")
			var grid_ok: bool = m.shop.last_sell_cells > 0
			m.shop.close()
			m.shop_room.close()
			print("MART_OK=", shelves_ok and cat_ok and grid_ok,
				" 선반=", shelves_ok, " 카테고리=", cat_ok,
				" 판매격자칸=", m.shop.last_sell_cells)
		342:
			# 처음 집(좁은 오두막) 캡처 — 낡은 침대·책상·먼지더미뿐이어야 한다
			GameData.house_lv = 1
			GameData.kitchen_found = false
			GameData.dust_swept = 0
			m.interior.open()
		343:
			_save_shot("_home_small.png")
			m.interior.close()
			GameData.house_lv = 2         # 이후 단계는 확장한 집 기준
			GameData.kitchen_found = true
			m.interior._layout()
		344:
			# 탈 것: 사기 -> 타기 -> 속도 -> 내리기
			GameData.money = 99999
			GameData.has_horse = false
			GameData.riding = false
			GameData.horse_tile = m.player_tile() + Vector2i(1, 0)
			m.shop.main = m
			m.shop._on_buy_horse()
			var parked: bool = m.objects.has(GameData.horse_tile)
			m.riding._mount_horse(GameData.horse_tile)
			print("HORSE: parked=", parked, " riding=", GameData.riding)
			# 앉은 자세는 방향마다 따로 맞춰야 해서 셋 다 찍는다.
			# 화면은 한 프레임 늦게 찍히므로 「자세 -> 다음 단계에서 촬영」으로 민다.
			_ride_pose("down")
		345:
			print("HORSE_DRAW: vis=", m.player.horse_sprite.visible,
				" tex=", m.player.horse_sprite.texture != null,
				" 말offset=", m.player.horse_sprite.offset,
				" 배율=", m.player.horse_sprite.scale,
				" 사람y=", m.player.sprite.position.y,
				" 자른행=", m.player.sprite.region_rect.size.y)
			print("HORSE_SEAT_OK=", m.player.sprite.region_enabled
				and m.player.sprite.texture == m.tex[
					GameData.player_down_tex(false, "idle", 0.0)])
			_save_shot("_horse.png")
			_ride_pose("right")
		346:
			_save_shot("_horse_side.png")
			_ride_pose("up")
		347:
			_save_shot("_horse_up.png")
		348:
			m.riding.dismount_horse()
			m.player._update_sprite()   # 자른 상체를 되돌리는 건 그릴 때다
			print("HORSE_DISMOUNT_OK=", not GameData.riding
				and m.objects.has(GameData.horse_tile)
				and not m.player.sprite.region_enabled)
		349:
			# 우리집 자리: 마을 건물 마당과 한 칸도 겹치면 안 된다
			var home_yard := Rect2i(m.HOME_ANCHOR - Vector2i(m.YARD_PAD, m.YARD_PAD),
				Vector2i(5 + m.YARD_PAD * 2, 4 + m.YARD_PAD * 2))
			var clash := ""
			for pid: String in m.VILLAGE_PLOTS:
				var a: Vector2i = m.VILLAGE_PLOTS[pid].anchor
				var yard := Rect2i(a - Vector2i(m.YARD_PAD, m.YARD_PAD),
					Vector2i(5 + m.YARD_PAD * 2, 4 + m.YARD_PAD * 2))
				if home_yard.intersects(yard):
					clash += pid + " "
			print("HOME_CLEAR_OK=", clash == "", " clash=", clash,
				" plaza_overlap=", home_yard.intersects(m.PLAZA))
			# 지어 놓고 바깥 모습도 남긴다 (이름표 확인)
			GameData.house_lv = maxi(GameData.house_lv, 1)
			m.objnode._remove_object(m.HOME_SITE)
			m.worldgen._fill_building(m.HOME_ANCHOR)
			m.worldgen._spawn_house_node(m.HOME_ANCHOR)
			GameData.day = 1                 # 봄으로 되돌려 눈 없이 찍는다
			m.objnode._apply_season_visuals()
			m.player.position = Vector2((m.HOME_ANCHOR.x + 2) * m.TILE + 16,
				(m.HOME_ANCHOR.y + 4) * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
		351: _save_shot("_home.png")
		352:
			# 축사: 그림 크기 · 주변 정리 · 말 세우기
			GameData.money = 99999
			GameData.wood = 999
			GameData.barn_built = false
			GameData.has_horse = false
			GameData.riding = false
			m.toolwork.build_barn()
			m.riding.place_horse()
			GameData.has_horse = true
			# 그림이 덮는 칸이 모두 막혀 있는가 (안으로 걸어 들어가면 안 된다)
			var art_ok := true
			for ay in range(m.BARN_POS.y + m.BARN_ART.position.y,
					m.BARN_POS.y + m.BARN_ART.end.y):
				for ax in range(m.BARN_POS.x + m.BARN_ART.position.x,
						m.BARN_POS.x + m.BARN_ART.end.x):
					if not m.objects.has(Vector2i(ax, ay)):
						art_ok = false
			var no_bin := true
			for q: Vector2i in m.objects:
				if m.objects[q].kind == "bin":
					no_bin = false
			print("BARN_ART_OK=", art_ok, " size=", m.BARN_ART.size,
				" NO_BIN_OK=", no_bin)
			print("HORSE_PARK=", GameData.horse_tile, " at_farm=",
				GameData.horse_tile.distance_to(Vector2(m.HORSE_HOME)) <= 2.0)
			m.player.position = Vector2((m.BARN_POS.x + 3) * m.TILE + 16,
				(m.BARN_POS.y + 4) * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
		354: _save_shot("_barn.png")
		356:
			# 옛 세이브 정리: 예전 자리의 출하 상자·축사가 남지 않아야 한다
			var stale := [Vector2i(9, 4), Vector2i(10, 3), Vector2i(11, 3),
				Vector2i(9, 2), Vector2i(12, 3)]
			m.objects[stale[0]] = {"kind": "bin", "hp": 0}
			m.objects[stale[1]] = {"kind": "barn", "hp": 0}
			m.objects[stale[2]] = {"kind": "barn_block", "hp": 0}
			m.objects[stale[3]] = {"kind": "art_block", "hp": 0}
			m.objects[stale[4]] = {"kind": "art_block", "hp": 0}
			m.player.position = Vector2(m.BARN_POS.x * m.TILE + 16, m.BARN_POS.y * m.TILE + 16)
			m.worldgen._migrate_farm_layout()
			# 옛 자리의 상자/축사는 사라지고, 새 축사 그림 칸은 art_block이어야 한다
			var art := Rect2i(m.BARN_POS + m.BARN_ART.position, m.BARN_ART.size)
			var left := []
			for q: Vector2i in m.objects:
				var k: String = m.objects[q].kind
				if k == "bin":
					left.append("bin%s" % q)
				elif (k == "barn" or k == "barn_block") and q != m.BARN_POS:
					left.append("%s%s" % [k, q])
				elif k == "art_block" and Rect2i(9, 2, 4, 2).has_point(q) \
						and not art.has_point(q):
					left.append("art%s" % q)
			print("MIGRATE_OK=", left.is_empty()
					and m.objects.get(m.BARN_POS, {}).get("kind", "") == "barn",
				" leftovers=", left, " player_free=", m.is_passable(m.player_tile()))
		355:
			# 날씨 표: 계절마다 뽑히는 날씨가 실제로 다 나오는가
			var seen_w := {}
			for d in range(1, GameData.DAYS_PER_SEASON * 4 + 1):
				seen_w[GameData.weather_of_day(d)] = true
			var missing := []
			for wid: int in GameData.WEATHER_IDS:
				if not seen_w.has(wid):
					missing.append(GameData.weather_name(wid))
			print("WEATHER_ALL_OK=", missing.is_empty(), " 못 나온 날씨=", missing,
				" 1년치 종류=", seen_w.size())
			# 폭풍/비는 밭이 젖는 날, 안개/별밤은 아니다
			print("WEATHER_WET_OK=", GameData.weather_wet(GameData.WEATHER_STORM)
					and GameData.weather_wet(GameData.WEATHER_RAIN)
					and not GameData.weather_wet(GameData.WEATHER_FOG)
					and not GameData.weather_wet(GameData.WEATHER_STAR),
				" harsh(안개)=", GameData.weather_harsh(GameData.WEATHER_FOG))
		370:
			# 캐기 모션: 휘두르기 -> (0.15초 뒤) 파편 + 대상 흔들림
			m.player.position = Vector2(29 * m.TILE + 16, 40 * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m.player.dir = "right"
			var mt := Vector2i(30, 40)
			m.objects[mt] = {"kind": "bigrock", "hp": m.BIGROCK_HP}
			if not m.obj_nodes.has(mt):
				m.objnode._spawn_object_node(mt, "bigrock")
			m._pending_hits.clear()
			m._obj_shakes.clear()
			m.toolwork.set_tool("pickaxe")
			m.toolwork.swing_at(mt, "stone", true)
			var swung: bool = m.player.swing_t > 0.0 and m.player.tool_sprite.texture != null
			var queued: int = m._pending_hits.size()
			# 맞는 순간까지 시간을 흘려 본다
			for i in 20:
				m.toolwork._update_hit_fx(0.01)
			print("SWING_OK=", swung, " 예약된 타격=", queued,
				" 터진 뒤 남은 예약=", m._pending_hits.size(),
				" 흔들리는 오브젝트=", m._obj_shakes.size(),
				" 화면흔들림=", m._cam_shake > 0.0)
			# ---- 화면용 ----
			# 앞선 검사에서 세워 둔 커다란 바위 벽이 캐릭터를 덮으므로
			# 깨끗한 자리로 옮겨 작은 돌 하나만 놓고 찍는다.
			m.objnode._remove_object(mt)
			var demo := Vector2i(24, 20)
			for cy in range(demo.y - 3, demo.y + 4):
				for cx in range(demo.x - 3, demo.x + 4):
					m.objnode._remove_object(Vector2i(cx, cy))
			var rt2 := demo + Vector2i(1, 0)
			m.objects[rt2] = {"kind": "rock", "hp": m.ROCK_HP}
			m.objnode._spawn_object_node(rt2, "rock")
			m.player.position = Vector2(demo.x * m.TILE + 16, demo.y * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m.player.dir = "right"
			m.toolwork.swing_at(rt2, "stone")
			# 헤드리스는 프레임이 들쭉날쭉해서 짧은 동작이 그냥 지나간다.
			# 길게 잡고 「내리친 직후」 위상에 고정해 둔다.
			m.player.start_swing("pickaxe", Vector2.RIGHT, 4.0)
			m.player.swing_t = 4.0 * 0.45

		380:
			# 충돌 범위를 넓혔으니 길이 막히지 않았는지 확인한다.
			# 농장 시작 자리에서 마을 광장까지 실제로 걸어갈 수 있어야 한다.
			var seen_w := {m.START_TILE: true}
			var q: Array[Vector2i] = [m.START_TILE]
			var head2 := 0
			while head2 < q.size():
				var cur: Vector2i = q[head2]
				head2 += 1
				for d5 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n5: Vector2i = cur + d5
					if seen_w.has(n5) or not m.is_passable(n5):
						continue
					seen_w[n5] = true
					q.append(n5)
			var plaza := Vector2i(m.PLAZA.position.x + 3, m.PLAZA.position.y + 3)
			var pier := Vector2i(m.NS_LANE_X + 1, m.DOCK_Y - 1)
			print("WORLD_PATH_OK=", seen_w.has(plaza) and seen_w.has(pier),
				" 광장=", seen_w.has(plaza), " 낚시터=", seen_w.has(pier),
				" 걸어갈 수 있는 칸=", seen_w.size())
			# 나무·돌 여백을 넓혀도 한 칸 통로는 살아 있어야 한다
			print("PAD_INFO=", m.OBJECT_PAD["tree"], m.OBJECT_PAD["rock"])
			# 스토리 길목: 두 곳 · 각 두 그루(개), 막는 줄은 길 안에서 이어져 있어야
			# 한다 (떨어져 있으면 사이로 그냥 지나가 버린다)
			print("STORY_GATE_OK=", m.STORY_GATE_XS.size() == 2
					and m.STORY_GATE_ROWS.size() == 2
					and int(m.STORY_GATE_ROWS[1]) == int(m.STORY_GATE_ROWS[0]) + 1
					and int(m.STORY_GATE_ROWS[0]) >= m.STORY_ROAD_Y0
					and int(m.STORY_GATE_ROWS[1]) <= m.STORY_ROAD_Y1,
				" 길목=", m.STORY_GATE_XS.size(), "곳 · 막는 줄=", m.STORY_GATE_ROWS)
		384:
			# 나무 뒤에 서면 나무가 비쳐 보여야 한다 (플레이어가 안 가려지게)
			var ft := Vector2i(24, 22)
			for cy in range(ft.y - 2, ft.y + 3):
				for cx in range(ft.x - 2, ft.x + 3):
					m.objnode._remove_object(Vector2i(cx, cy))
			m.objects[ft] = {"kind": "tree", "hp": m.TREE_HP}
			m.objnode._spawn_object_node(ft, "tree")
			# 나무 그림이 덮는 자리(바로 위 칸)에 선다
			m.player.position = Vector2(ft.x * m.TILE + 16, (ft.y - 1) * m.TILE + 24)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m._fade_a.clear()
			var covered: bool = m.objnode._covers_player(ft, m.obj_nodes[ft])
			for i in 30:
				m.objnode._update_object_fade(0.02)
			var alpha: float = m.obj_nodes[ft].get_child(0).modulate.a
			print("FADE_OK=", covered and alpha < 0.5,
				" 가리는가=", covered, " 알파=", "%.2f" % alpha)
		386: _save_shot("_fade.png")
		373:
			print("SWING_DRAW: 도구 보임=", m.player.tool_sprite.visible,
				" 그림=", m.player.tool_sprite.texture != null,
				" 위치=", m.player.tool_sprite.position.round(),
				" 몸 기울기=", "%.2f" % m.player.sprite.rotation)
			_save_shot("_swing.png")
		367:
			# 낚시: 귀한 물고기는 여러 번 맞혀야 하고, 두 번 놓치면 도망간다
			var hooked := [0]
			m.pending_fish = GameData.FISH[0]   # 판정 성공 시 main이 실제로 처리한다
			var fin := func(ok: bool) -> void: hooked[0] = 1 if ok else -1
			m.fishing_ui.finished.connect(fin)
			var ev_hook := InputEventAction.new()
			ev_hook.action = "use_tool"
			ev_hook.pressed = true
			# ① 3단계 물고기(황금잉어) — 구간을 화면 전체로 열어 세 번 다 맞힌다
			m.fishing_ui.start(30.0, 3, 1.5, "테스트")
			var mid_ok := true
			for i in 3:
				m.fishing_ui.zone_x = 0.0
				m.fishing_ui.zone_w = m.fishing_ui.BAR_W
				if i < 2 and not m.fishing_ui.visible:
					mid_ok = false          # 아직 끝나면 안 된다
				m.fishing_ui._input(ev_hook)
			print("FISH_STAGES_OK=", hooked[0] == 1 and mid_ok,
				" 단계=", m.fishing_ui.stages_total)
			# ② 두 번 놓치면 도망 (한 번은 봐준다)
			hooked[0] = 0
			m.fishing_ui.start(30.0, 2, 1.0, "테스트")
			m.fishing_ui.zone_x = -999.0
			m.fishing_ui.zone_w = 1.0
			m.fishing_ui._input(ev_hook)
			var alive_after_1: bool = m.fishing_ui.visible and hooked[0] == 0
			m.fishing_ui.zone_x = -999.0
			m.fishing_ui.zone_w = 1.0
			m.fishing_ui._input(ev_hook)
			print("FISH_MISS_OK=", alive_after_1 and hooked[0] == -1,
				" (한 번 놓쳐도 계속=", alive_after_1, ")")
			m.fishing_ui.finished.disconnect(fin)
			# 화면용: 황금잉어 판정을 한 번 맞힌 상태로 띄워 둔다
			m.fishing_ui.start(34.0, 3, 1.5, "낚싯대가 휜다!!!")
			m.fishing_ui.zone_x = 0.0
			m.fishing_ui.zone_w = m.fishing_ui.BAR_W
			m.fishing_ui._input(ev_hook)
		368:
			_save_shot("_fishing.png")
			m.fishing_ui.visible = false
			m.pending_fish = {}
		364:
			# 동굴 층: 유형이 실제로 섞여 나오고, 계단/상자가 늘 걸어 닿는 곳에 있는가
			m.cave.main = m
			m.cave.worldtree = false
			var seen_layout := {}
			var seen_special := {}
			var unreachable_n := 0
			for f in range(1, 41):
				m.cave.floor_num = f
				m.cave._gen_floor()
				seen_layout[m.cave.layout] = true
				if m.cave.special != "":
					seen_special[m.cave.special] = true
				# 계단 자리를 실제로 뽑아 보고 걸어 닿는지 확인한다
				var sp2: Vector2i = m.cave._free_tile(0.0)
				if sp2.x < 0 or not m.cave.reachable.has(sp2):
					unreachable_n += 1
			print("CAVE_LAYOUT_OK=", seen_layout.size() >= 3,
				" 유형=", seen_layout.keys(), " 희귀방=", seen_special.keys())
			print("CAVE_REACHABLE_OK=", unreachable_n == 0,
				" 못 닿는 층=", unreachable_n, "/40")
			# 5층마다 미니보스가 서 있는가
			m.cave.floor_num = 10
			m.cave._gen_floor()
			var boss := 0
			for mob in m.cave.monsters:
				if str(mob.type) == "treant":
					boss += 1
			print("CAVE_MINIBOSS_OK=", boss >= 1, " 10층 보스=", boss)
			# 한 화면(ZOOM 배)보다 넓어야 「탐험」이 된다
			var view_w: float = 960.0 / m.cave.ZOOM / m.cave.TS
			var view_h: float = 540.0 / m.cave.ZOOM / m.cave.TS
			m.cave.floor_num = 1
			m.cave._gen_floor()
			var w1: int = m.cave.GW
			var h1: int = m.cave.GH
			m.cave.floor_num = 12
			m.cave._gen_floor()
			print("CAVE_SIZE_OK=", float(w1) > view_w * 1.8 and float(h1) > view_h * 1.8,
				" 1층=", w1, "x", h1, " 12층=", m.cave.GW, "x", m.cave.GH,
				" 한 화면=", "%.0f x %.0f" % [view_w, view_h])
			# 계단이 처음부터 있어야 몬스터를 다 잡지 않고도 내려갈 수 있다
			print("CAVE_STAIRS_OK=", m.cave.stairs_pos.x >= 0
					and m.cave.reachable.has(m.cave.stairs_pos),
				" 계단=", m.cave.stairs_pos, " 입구=", m.cave.entry_pos)
		361:
			# 의뢰: 종류가 여러 가지로 붙고, 골라서 수락 -> 납품까지 되는가
			GameData.quest = {}
			GameData.recipes_cooked["dish_soup"] = 1     # 요리 의뢰 후보를 연다
			GameData.learn_formula("potion_energy")      # 물약 의뢰 후보를 연다
			var kinds_seen := {}
			for d4 in range(1, GameData.DAYS_PER_SEASON * 4 + 1):
				GameData.day = d4
				GameData.make_daily_quest()
				for o: Dictionary in GameData.quest_offers:
					kinds_seen[str(o.kind)] = true
			GameData.day = 1
			GameData.make_daily_quest()
			print("QUEST_KINDS_OK=", kinds_seen.size() >= 5,
				" 1년치 종류=", kinds_seen.keys(),
				" 오늘 붙은 건수=", GameData.quest_offers.size())
			# 골라 수락 -> 물건을 채우고 -> 납품
			var off: Dictionary = GameData.quest_offers[0]
			var qitem: String = str(off.item)
			var qneed: int = int(off.qty)
			GameData.accept_offer(0)
			if GameData.CROPS.has(qitem):
				GameData.produce[qitem] = qneed
			else:
				GameData.items[qitem] = qneed
			var money0: int = GameData.money
			var left0: int = GameData.ingredient_count(qitem)
			m.village._turn_in_quest()
			print("QUEST_TURNIN_OK=", GameData.quest.is_empty()
					and GameData.money == money0 + int(off.reward)
					and GameData.ingredient_count(qitem) == left0 - qneed,
				" 품목=", GameData.item_display_name(qitem), " x", qneed,
				" 보상=", int(off.reward))
			m.dialog.close()
		359:
			# 목초지: 울타리로 네모나게 둘러싸면 그 안이 갇힌 칸이 되어야 한다
			var p0 := Vector2i(16, 16)
			for yy in range(p0.y - 1, p0.y + 4):
				for xx in range(p0.x - 1, p0.x + 4):
					m.objects.erase(Vector2i(xx, yy))
			m.farming._recount_pasture()
			var before_pen: int = m.pasture.size()
			for i in 5:
				m.objects[Vector2i(p0.x - 1 + i, p0.y - 1)] = {"kind": "fence", "hp": 0}
				m.objects[Vector2i(p0.x - 1 + i, p0.y + 3)] = {"kind": "fence", "hp": 0}
				m.objects[Vector2i(p0.x - 1, p0.y - 1 + i)] = {"kind": "fence", "hp": 0}
				m.objects[Vector2i(p0.x + 3, p0.y - 1 + i)] = {"kind": "fence", "hp": 0}
			m.farming._recount_pasture()
			var closed: int = m.pasture.size()
			var inside: bool = m.farming.in_pasture(p0 + Vector2i(1, 1))
			# 문을 하나 내면 (울타리 한 칸 걷어내면) 목초지가 풀려야 한다
			m.objects.erase(Vector2i(p0.x + 1, p0.y - 1))
			m.farming._recount_pasture()
			print("PASTURE_OK=", inside and closed > before_pen,
				" 닫았을 때=", closed - before_pen, "칸  문 내면=",
				m.pasture.size() - before_pen, "칸  OPEN_OK=", not m.farming.in_pasture(p0 + Vector2i(1, 1)))
		357:
			# 스프링클러: 설치하면 바로, 그리고 계속 물을 준다
			var sp := Vector2i(20, 20)
			for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				m.objects.erase(sp + d2)
				m.grid[sp.y + d2.y][sp.x + d2.x].ground = "soil"
				m.grid[sp.y + d2.y][sp.x + d2.x].wet_min = 0.0
				m.grid[sp.y + d2.y][sp.x + d2.x].watered = false
			m.objects.erase(sp)
			m.objnode._place_object(sp, "sprinkler", 0)
			m.farming._sprinkle(sp)
			var wet_now: bool = m.grid[sp.y][sp.x + 1].watered
			# 하루가 지나 마른 뒤에도, 낮에 새로 간 밭까지 다시 적셔야 한다
			for d3 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				m.grid[sp.y + d3.y][sp.x + d3.x].wet_min = 0.0
				m.grid[sp.y + d3.y][sp.x + d3.x].watered = false
			m.farming._sprinkler_tick()
			print("SPRINKLER_NOW_OK=", wet_now,
				" SPRINKLER_KEEPS_OK=", m.grid[sp.y][sp.x + 1].watered)
		358:
			# 연금술: 실험 -> 발견 -> 약효 -> 조합법 드랍
			GameData.alchemy_known = []
			GameData.alchemy_brews = {}
			GameData.potion_today = {}
			for rid: String in GameData.REAGENTS:
				if GameData.CROPS.has(rid):
					GameData.produce[rid] = 20
				else:
					GameData.items[rid] = 20
			for fid: String in GameData.FORMULA_IDS:
				GameData.items[fid] = 0
			# 모든 조합법이 실제로 만들 수 있는 조합을 가지고 있는가
			# (표만 고치고 재료를 안 넣으면 영영 못 만드는 조합법이 생긴다)
			m.alchemy_ui.main = m
			var unreachable := []
			for fid: String in GameData.FORMULA_IDS:
				if m.alchemy_ui._auto_pick(fid).is_empty():
					unreachable.append(fid)
			print("ALCHEMY_REACHABLE_OK=", unreachable.is_empty(),
				" unreachable=", unreachable)
			# 실패 조합: 물만 잔뜩 넣으면 아무것도 안 나와야 한다
			var dud := GameData.match_formula(["potato", "potato", "potato"])
			# 발견: 원기 물약 (생명 4 이상)
			var trio := ["egg", "egg", "cabbage"]
			var got := GameData.match_formula(trio)
			m.doing.do_brew(trio)
			print("ALCHEMY_BREW: dud=\"", dud, "\" got=", got,
				" learned=", GameData.knows_formula("potion_energy"),
				" bottles=", int(GameData.items["potion_energy"]))
		360:
			m.dialog.close()
			# 약효: 바람 물약을 마시면 이동 속도 배율이 오른다
			var spd0: float = GameData.pet_speed_mult()
			GameData.learn_formula("potion_swift")
			GameData.items["potion_swift"] = 1
			m.doing.do_drink("potion_swift")
			print("POTION_BUFF: speed ", spd0, " -> ", GameData.pet_speed_mult(),
				" luck=", GameData.bonus_drop_chance("mine"))
			GameData.reset_daily()
			print("POTION_CLEAR_OK=", not GameData.has_potion("swift"))
			# 조합법 드랍: 확률을 1로 올려 실제로 습득되는지 본다
			GameData.alchemy_known = ["potion_energy"]
			var before_n: int = GameData.alchemy_known.size()
			for i in 40:
				m.doing._maybe_drop_recipe("bigrock")
			print("RECIPE_DROP_OK=", GameData.alchemy_known.size() > before_n,
				" known=", GameData.alchemy_known.size(), "/", GameData.FORMULA_IDS.size())
			for fid2: String in GameData.FORMULA_IDS:
				GameData.learn_formula(fid2)
				GameData.items[fid2] = 2
			# 마지막 연금술 버튼이 조합대에 살아 있는지 (연구 노트에서 옮겼다)
			for leg in GameData.LEGENDS:
				GameData.items[leg[0]] = 1
			print("FINAL_ALCHEMY_OK=", GameData.can_final_alchemy(),
				" legends=", GameData.legends_owned(), "/", GameData.LEGENDS.size())
			m.interior.open()
			m.alchemy_ui.open()
			# 조합 결과가 창 안에 뜨는가. 우유 셋은 생명3·물3이라 어느 조합법도
			# 문턱을 못 넘고, 달걀 셋은 생명6이라 원기 물약이 된다.
			GameData.items["milk"] = 3
			GameData.items["egg"] = 3
			var r_fail: Dictionary = m.doing.do_brew(["milk", "milk", "milk"])
			var r_ok: Dictionary = m.doing.do_brew(["egg", "egg", "egg"])
			print("BREW_RESULT_OK=", r_fail.get("ok", true) == false
					and bool(r_ok.get("ok", false)),
				" 실패안내=\"", r_fail.get("hint", ""), "\"",
				" 성공=\"", r_ok.get("name", ""), "\"")
			m.alchemy_ui.last = r_ok
			m.alchemy_ui._rebuild()
			print("BREW_BANNER_OK=", m.alchemy_ui.result_panel.visible,
				" 문구=\"", m.alchemy_ui.result_head.text, "\"")
		362: _save_shot("_alchemy.png")
		363:
			m.alchemy_ui.close()
			m.interior.close()
			m.note_ui.toggle()
			m.note_ui.scroll.scroll_vertical = 1120   # 연금술 페이지까지 내린다
		365: _save_shot("_note2.png")
		366: m.note_ui.close()
		369:
			# 새 날씨 세 가지를 눈으로 확인한다 (안개 · 폭풍 · 별밤)
			m.note_ui.close()
			m.dialog.close()
			GameData.day = 1
			m.objnode._apply_season_visuals()
			m.player.position = Vector2(16 * m.TILE + 16, 12 * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			GameData.minutes = 14.0 * 60.0
			m._weather_override = GameData.WEATHER_FOG
		371: _save_shot("_weather_fog.png")
		372: m._weather_override = GameData.WEATHER_STORM
		374: _save_shot("_weather_storm.png")
		375:
			m._weather_override = GameData.WEATHER_STAR
			GameData.minutes = 22.0 * 60.0   # 별은 밤에 뜬다
		377: _save_shot("_weather_star.png")
		379:
			GameData.quest = {}
			GameData.make_daily_quest()
			m._weather_override = -1
			m.village._open_quest_board()
		381: _save_shot("_board.png")
		387:
			# ---- 성능 재기 ----
			# 소프트웨어 렌더러라 FPS는 뜻이 없다. **개수**를 본다 —
			# 드로우콜과 노드 수는 실기에서도 그대로다.
			m.interior.close()
			m.cave.close()
			m.player.position = Vector2(m.START_TILE.x * m.TILE + 16,
				m.START_TILE.y * m.TILE + 16)
		389:
			var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			var t0 := Time.get_ticks_usec()
			for i in 20:
				m._process(0.016)
			var proc_us := (Time.get_ticks_usec() - t0) / 20.0
			print("PERF: 드로우콜=", int(calls), " 노드=", int(nodes),
				" world자식=", m.world.get_child_count(),
				" 오브젝트=", m.objects.size(),
				" _process=", "%.0f" % proc_us, "us")
			# 한 프레임 드로우콜이 이 선을 넘으면 무언가 잘못된 것이다.
			# (화면에 보이는 칸이 38 x 22쯤이므로 타일만으로 900을 넘지 않아야 한다)
			# 어디에 시간이 드는지 쪼개 본다
			var parts := {
				"story": func() -> void: m.story._story_update(0.016),
				"fade": func() -> void: m.objnode._update_object_fade(0.016),
				"treefade": func() -> void: m.objnode._update_tree_fade(),
				"mouse": func() -> void: m.actions._update_mouse_target(),
				"particles": func() -> void: m.renderer._update_particles(0.016),
				"nightmobs": func() -> void: m.daycycle._update_night_mobs(0.016),
				"hud": func() -> void: m.hud.refresh(true),
				"growth": func() -> void: m.farming._growth_tick(1.0),
				"hitfx": func() -> void: m.toolwork._update_hit_fx(0.016),
			}
			var line := ""
			for k: String in parts:
				var t1 := Time.get_ticks_usec()
				for i2 in 20:
					parts[k].call()
				line += "%s=%.0f " % [k, (Time.get_ticks_usec() - t1) / 20.0]
			print("PERF_BREAKDOWN: ", line)
			print("PERF_DRAWCALLS_OK=", calls < 2500, " 콜=", int(calls))
			print("PERF_PROCESS_OK=", proc_us < 8000.0, " us=", "%.0f" % proc_us)
		388:
			# 배경음: 상황마다 다른 곡이 나오는가 + 열 곡이 다 실렸는가
			var loaded := 0
			for bn: String in Sound.BGM_NAMES:
				if Sound.streams.has(bn) and Sound.streams[bn] != null:
					loaded += 1
			var save_pos := m.player.position
			var save_min := GameData.minutes
			m.player.position = Vector2(74 * m.TILE + 16, 20 * m.TILE + 16)   # 광장
			GameData.minutes = 12.0 * 60.0
			var in_village := m._want_bgm()
			m.player.position = Vector2(m.START_TILE.x * m.TILE + 16, m.START_TILE.y * m.TILE + 16)
			var at_farm := m._want_bgm()
			GameData.minutes = 21.0 * 60.0
			var at_night := m._want_bgm()
			GameData.minutes = save_min
			m.cave.visible = true
			var in_cave := m._want_bgm()
			m.cave.visible = false
			m.player.position = save_pos
			var picks := [in_village, at_farm, at_night, in_cave]
			print("BGM_OK=", loaded == Sound.BGM_NAMES.size()
				and in_village == "bgm_main" and in_cave == "bgm_cave"
				and at_night == "bgm_night" and at_farm == "bgm_main"
				and picks.size() == 4,
				" 실린곡=", loaded, "/", Sound.BGM_NAMES.size(), " 고른것=", picks)
		390:
			# 선물 취향 · 생일 · 연애 단계
			GameData.dating = ""
			GameData.spouse = ""
			GameData.affinity["merchant"] = 0
			var loved := GameData.gift_value("merchant", "strawberry")     # loves
			var liked := GameData.gift_value("merchant", "potato")         # likes
			var plain := GameData.gift_value("merchant", "ore")            # 표에 없음
			var hated := GameData.gift_value("merchant", "sludge")         # hates
			print("GIFT_TASTE_OK=", loved > liked and liked > plain and hated < 0,
				" 아주좋아함=", loved, " 좋아함=", liked, " 보통=", plain, " 싫어함=", hated)

			# 꽃다발은 호감도 60부터, 반지는 연인 + 100부터. 순서를 건너뛸 수 없어야 한다.
			# _give_gift가 먼저 하나 빼고 부르므로 여기서도 0으로 두고 부른다
			GameData.items["bouquet"] = 0
			GameData.items["wedding_ring"] = 0
			m.village._romance_gift("merchant", "bouquet", 20)
			var too_early: bool = GameData.dating == "" and int(GameData.items["bouquet"]) == 1
			GameData.items["bouquet"] = 0
			m.village._romance_gift("merchant", "wedding_ring", 100)
			var ring_first: bool = GameData.spouse == "" and int(GameData.items["wedding_ring"]) == 1
			GameData.items["wedding_ring"] = 0
			m.village._romance_gift("merchant", "bouquet", 70)
			var now_dating := GameData.dating == "merchant"
			m.village._romance_gift("merchant", "wedding_ring", 100)
			var now_married := GameData.spouse == "merchant"
			# 연애 대상이 아닌 사람에게는 되돌려 준다
			GameData.spouse = ""
			GameData.dating = ""
			GameData.items["bouquet"] = 0
			m.village._romance_gift("chief", "bouquet", 100)
			var refused: bool = GameData.dating == "" and int(GameData.items["bouquet"]) == 1
			print("ROMANCE_OK=", too_early and ring_first and now_dating
				and now_married and refused,
				" 이른꽃다발거절=", too_early, " 반지먼저거절=", ring_first,
				" 연인=", now_dating, " 결혼=", now_married, " 어른거절=", refused)

			# 대사가 갈래대로 늘었는가 (넉 줄 돌려막기로 되돌아가면 잡힌다)
			var line_total := 0
			for nid: String in GameData.NPCS:
				var d: Dictionary = GameData.NPCS[nid]
				line_total += (d.lines as Array).size()
				for k in ["season", "weather"]:
					for kk in d.get(k, {}):
						line_total += (d[k][kk] as Array).size()
				for k2 in ["morning", "night", "aff30", "aff70", "dating", "married"]:
					line_total += (d.get(k2, []) as Array).size()
			print("NPC_LINES_OK=", line_total >= 100, " 대사줄=", line_total,
				" 사람=", GameData.NPCS.size())
			GameData.dating = ""
			GameData.spouse = ""
		383:
			# 제작대: 재료 지불 -> 시간 -> 완성되면 침대가 바뀐다
			GameData.desk_lv = 0
			GameData.bed_lv = 0
			GameData.desk_queue.clear()
			GameData.wood = 500
			GameData.stone = 500
			GameData.items["nail"] = 10
			GameData.items["cloth"] = 10
			GameData.items["hinge"] = 10
			GameData.items["ore"] = 100
			GameData.items["milk"] = 10
			var slow := GameData.desk_time() == 5.0 and GameData.desk_slots() == 1
			var skip_soft := not GameData.desk_start("bed_soft")   # 순서 건너뛰기 금지
			var q1 := GameData.desk_start("bed_wood")
			var full := not GameData.desk_start("bed_wood")        # 1칸이라 둘째는 거절
			GameData.desk_tick(6.0)
			var made_bed := GameData.bed_lv == 1 and GameData.desk_queue.is_empty()
			var up1 := GameData.desk_upgrade()
			var faster := GameData.desk_time() == 4.0 and GameData.desk_slots() == 2
			var q2 := GameData.desk_start("bed_soft")
			GameData.desk_tick(4.0)
			var made_soft := GameData.bed_lv == 2
			print("DESK_OK=", slow and skip_soft and q1 and full and made_bed
				and up1 and faster and q2 and made_soft,
				" 느림=", slow, " 건너뛰기거절=", skip_soft, " 걸림=", q1,
				" 칸참=", full, " 나무침대=", made_bed, " 손보기=", up1,
				" 빨라짐=", faster, " 푹신침대=", made_soft)
			print("BED_WAKE_OK=", is_equal_approx(GameData.bed_wake_mult(false), 1.0)
				and is_equal_approx(GameData.bed_wake_mult(true), 0.75),
				" 아침=", GameData.bed_wake_mult(false),
				" 쓰러짐=", GameData.bed_wake_mult(true))
			GameData.desk_done_pending.clear()
		382:
			# 빗자루 -> 청소 -> 조리대 발견 -> 요리 해금
			GameData.kitchen_found = false
			GameData.dust_swept = 0
			GameData.recipes_unlocked.erase("broom")
			GameData.items["broom"] = 0
			GameData.items["weed"] = 10
			GameData.wood = 100
			var locked_first := not GameData.desk_start("broom")   # 레시피를 모른다
			GameData.recipes_unlocked.append("broom")
			var q_ok := GameData.desk_start("broom")
			GameData.desk_tick(10.0)
			var got_broom := int(GameData.items["broom"]) == 1
			m.interior._sweep_kitchen()
			m.interior._sweep_kitchen()
			var not_yet := not GameData.kitchen_found
			m.interior._sweep_kitchen()
			var found := GameData.kitchen_found
			m.dialog.close()
			print("CLEAN_OK=", locked_first and q_ok and got_broom and not_yet and found,
				" 레시피잠김=", locked_first, " 제작=", got_broom,
				" 두번으로는안됨=", not_yet, " 세번에발견=", found)
			GameData.desk_done_pending.clear()
		385:
			# 발견 기록 + 컬렉션 보상
			GameData.discovered.clear()
			GameData.collections_done.clear()
			GameData.recipes_unlocked.clear()
			GameData.collection_pending.clear()
			var was_locked := GameData.recipe_locked("dish_fried_egg")
			# 봄의 밭 여섯을 채우면 계란후라이 레시피가 열려야 한다
			for cid2: String in ["potato", "carrot", "strawberry", "spinach", "onion"]:
				GameData.discover(cid2)
			var before_full := not GameData.recipe_locked("dish_fried_egg")
			GameData.discover("pea")
			var unlocked := not GameData.recipe_locked("dish_fried_egg")
			var pending := GameData.collection_pending.size() == 1
			var dated := GameData.discovered_on("pea") != ""
			var again := not GameData.discover("pea")   # 두 번째는 기록하지 않는다
			print("COLLECT_OK=", was_locked and not before_full and unlocked
				and pending and dated and again,
				" 잠겨있었다=", was_locked, " 5개로는안열림=", not before_full,
				" 6개로열림=", unlocked, " 배너대기=", pending,
				" 날짜=", GameData.discovered_on("pea"), " 중복차단=", again)
			# 상점 해금: 재료를 겪기 전에는 대장간이 안 벼려 준다
			GameData.owned_gear.erase("gear_sword_iron")
			var gate_before := GameData.gear_known("gear_sword_iron")   # ore 미발견
			var wood_open := GameData.gear_known("gear_sword_wood")     # tier1은 늘 열림
			GameData.discover("ore")
			var gate_after := GameData.gear_known("gear_sword_iron")
			print("SHOP_GATE_OK=", not gate_before and wood_open and gate_after,
				" 광석전=", gate_before, " 나무장비=", wood_open, " 광석후=", gate_after)
			GameData.collection_pending.clear()
		391:
			# 표에 한 줄 넣고 아이콘이나 아이템 정의를 빠뜨리면 조용히 사라진다.
			# (그림이 없으면 칸이 그냥 비고, 어서션이 없으면 한참 뒤에야 안다)
			var missing: Array[String] = []
			for fid: String in GameData.FISH_IDS:
				if not GameData.ITEMS.has(fid):
					missing.append("ITEMS:" + fid)
				if not m.tex.has(fid) or m.tex[fid] == null:
					missing.append("그림:" + fid)
			for rid: String in GameData.RECIPE_IDS:
				if not GameData.ITEMS.has(rid):
					missing.append("ITEMS:" + rid)
				if not m.tex.has(rid) or m.tex[rid] == null:
					missing.append("그림:" + rid)
				for need: String in GameData.RECIPES[rid].needs:
					if not (GameData.CROPS.has(need) or GameData.ITEMS.has(need)):
						missing.append("재료:%s<-%s" % [rid, need])
			for cid: String in GameData.CROP_IDS:
				if not m.tex.has("mature_" + cid) or m.tex["mature_" + cid] == null:
					missing.append("그림:mature_" + cid)
			print("CONTENT_OK=", missing.is_empty(),
				" 물고기=", GameData.FISH_IDS.size(),
				" 요리=", GameData.RECIPE_IDS.size(),
				" 작물=", GameData.CROP_IDS.size(), " 빠진것=", missing)
			# 계절마다 낚을 것과 심을 것이 실제로 있는가 (한 계절이 비면 그 달이 죽는다)
			var per_season: Array[String] = []
			var thin := false
			for s in range(4):
				var crops := 0
				for cid: String in GameData.CROP_IDS:
					if s in GameData.CROPS[cid].seasons:
						crops += 1
				var fishes := 0
				for f: Dictionary in GameData.FISH:
					var ss: Array = f.seasons
					if ss.is_empty() or s in ss:
						fishes += 1
				per_season.append("%s 작물%d 물고기%d" % [GameData.SEASON_NAMES[s], crops, fishes])
				if crops < 5 or fishes < 6:
					thin = true
			print("SEASON_CONTENT_OK=", not thin, " ", per_season)
		376:
			# 낚시꾼 퀘스트(메인 스토리 3): 등장 -> 황금잉어 선택지 ->
			# 길목 바위 -> 바다/해변 해금 + 간이낚싯대(낚시 해금) + 조개
			GameData.fisher_quest = ""
			GameData.sea_open = false
			GameData.unlocked_tools.erase("rod")
			GameData.story2_phase = "fisher"       # 상점이 서면 낚시꾼이 온다
			var hidden: bool = m.grid[m.MAP_H - 2][30].ground != "water"
			m.story._fisher_update(0.016)
			var met: bool = GameData.fisher_quest == "meet" \
				and m.story._fisher_node() != null
			m.story._start_fisher_dialog()
			var choice_shown := m.dialog.visible
			m.dialog.close()
			m.story._fisher_choose(2)              # 선택지 — 대사만 갈린다
			var picked: bool = GameData.fisher_choice == 2 and m.dialog.visible
			m.dialog.close()
			m.story._end_fisher_meet()
			var follow: bool = GameData.fisher_quest == "follow" \
				and GameData.fisher_objective_short() != ""
			GameData.fisher_quest = "open"         # 게이트 앞 대화가 끝난 상태
			for p: Vector2i in m.SEA_GATE:         # 길목 바위 둘을 캐낸 셈 친다
				m.objnode._remove_object(p)
			m.story._sea_gate_mined()              # -> 보상(간이낚싯대) 대화
			var reward := m.dialog.visible
			m.dialog.close()
			m.story._end_fisher_quest()
			var sea: bool = GameData.sea_open and GameData.fisher_quest == "done" \
				and GameData.is_tool_unlocked("rod") \
				and GameData.story2_phase == "farm_talk"
			var ridge: bool = str(m.objects.get(Vector2i(30, m.SEA_RIDGE_Y),
				{}).get("kind", "")) == "searock"
			var sand: bool = m.grid[m.BEACH_Y0][30].ground == "sand"
			var water: bool = m.grid[m.MAP_H - 2][30].ground == "water"
			var shells := 0
			for pos in m.objects:
				if String(m.objects[pos].kind) in m.BEACH_FORAGE:
					shells += 1
			var shell_ok: bool = GameData.ITEMS.has("forage_shell") \
				and m.tex.has("forage_shell") and m.tex.has("forage_coral") and shells > 0
			print("SEA_OK=", met and choice_shown and picked and follow and reward
				and sea and ridge and sand and water and shell_ok and hidden,
				" 등장=", met, " 선택지=", choice_shown, " 선택반영=", picked,
				" 동행=", follow, " 보상대화=", reward, " 바다해금=", sea,
				" 열기전숨김=", hidden, " 능선=", ridge, " 모래=", sand,
				" 바닷물=", water, " 조개=", shells)
			GameData.story2_phase = "done"
			# 해변 채집 능력치: 레벨이 오르면 리젠이 빨라지고 한 번에 더 줍는다.
			# 그리고 줍지 않은 조개가 상한을 넘겨 쌓이지 않아야 한다.
			GameData.skills["beach"] = {"lv": 1, "xp": 0.0}
			var base_n := GameData.beach_pick_count()
			var t1 := 0.0
			for i in 40:
				t1 += GameData.shell_respawn_minutes()
			GameData.skills["beach"] = {"lv": 10, "xp": 0.0}
			var lv_n := GameData.beach_pick_count()
			var t2 := 0.0
			for i in 40:
				t2 += GameData.shell_respawn_minutes()
			for i in 40:                       # 리젠을 거듭하면 상한까지만 쌓인다
				m.worldgen._tick_beach()
			var after := 0
			for pos2 in m.objects:
				if String(m.objects[pos2].kind) in m.BEACH_FORAGE:
					after += 1
			print("BEACH_OK=", base_n == 1 and lv_n > base_n and t2 < t1 * 0.7
				and after <= m.SHELL_CAP,
				" 기본줍기=", base_n, " 10렙줍기=", lv_n,
				" 평균리젠(분) 1렙=", "%.1f" % (t1 / 40.0), " 10렙=", "%.1f" % (t2 / 40.0),
				" 상한=", after, "/", m.SHELL_CAP)
			GameData.skills["beach"] = {"lv": 1, "xp": 0.0}
		378:
			# 스토리 1->2: 작별 -> 편지 전달 -> 집 해금 -> 입장(1막 끝) ->
			# 이장 인사(상점 퀘) -> 상점 건설 -> 호미 -> 밭 -> 첫 수확(2막 끝)
			var keep_house := GameData.house_lv
			var keep_bed := GameData.has_bed
			var keep_bedlv := GameData.bed_lv
			GameData.story_phase = "travel"
			GameData.story2_phase = ""
			GameData.house_lv = 0
			GameData.has_bed = false
			m.story._end_farewell()
			var farewell := GameData.story_phase == "deliver" \
				and GameData.story_objective_short() != ""
			m.story._start_delivery_dialog()   # 이장에게 E — 편지 전달
			var deliver_talk := m.dialog.visible
			m.dialog.close()
			m.story._end_delivery()
			var opened := GameData.house_lv == 1 and GameData.has_bed \
				and GameData.story_phase == "home_open"
			m.interior.open()
			var s1_done := GameData.story_phase == "greet"
			var small: bool = m.interior.ROOM.size.x < 500.0   # 처음 집은 좁은 오두막
			m.interior.close()
			m.story.start_home_greet()
			m.story._chief_greet = false     # 걸어오는 연출은 생략하고 도착한 셈 친다
			m.story._start_story2_dialog()
			var talk := m.dialog.visible
			m.dialog.close()
			m.story._end_home_greet()
			var shop_q: bool = GameData.story2_phase == "shop" \
				and GameData.story2_objective_short() != ""
			# 상점 건설 (재료를 채우고 상점 터 게시판 흐름으로)
			GameData.village_built.erase("general")
			GameData.wood = 100
			GameData.stone = 100
			m.village._open_shop_site_dialog()
			m.village._build_shop()
			m.dialog.close()
			var shop_built: bool = GameData.village_built.has("general") \
				and GameData.story2_phase == "fisher"
			# 바닷길이 열린 뒤(SEA_OK에서 검사) 이장이 호미를 준다
			GameData.story2_phase = "farm_talk"
			GameData.unlocked_tools.erase("hoe")
			m.story._start_farm_dialog()
			var farm_talk := m.dialog.visible
			m.dialog.close()
			m.story._end_farm_intro()
			var farm: bool = GameData.story2_phase == "farm" \
				and GameData.is_tool_unlocked("hoe")
			GameData.tutorial["harvest"] = false
			m.tutorial_notify("harvest")       # 첫 수확 = 2막 끝
			var s2_done: bool = GameData.story2_phase == "done"
			# 튜토리얼 분리: 밭 갈기 4개가 맨 앞, 집 짓기/침대 목표는 사라졌어야 한다
			var order_ok := true
			for i in 4:
				order_ok = order_ok \
					and str(GameData.TUTORIAL_ORDER[i][0]) == str(GameData.STORY2_FLAGS[i])
			for pair in GameData.TUTORIAL_ORDER:
				if str(pair[0]) in ["home", "bed"]:
					order_ok = false
			print("STORY2_OK=", farewell and deliver_talk and opened and s1_done and small
				and talk and shop_q and shop_built and farm_talk and farm and s2_done
				and order_ok,
				" 작별=", farewell, " 편지=", deliver_talk, " 집해금=", opened,
				" 입장으로1막끝=", s1_done, " 오두막=", small, " 이장대화=", talk,
				" 상점퀘=", shop_q, " 상점완성=", shop_built, " 호미대화=", farm_talk,
				" 밭시작=", farm, " 수확으로2막끝=", s2_done, " 안내분리=", order_ok)
			GameData.house_lv = keep_house
			GameData.has_bed = keep_bed
			GameData.bed_lv = keep_bedlv
			GameData.story2_phase = "done"
			m.interior._layout()
		392: get_tree().quit()


# ==== 검증 시퀀스 ====

func _send_key(code: Key) -> void:
	_send_key_press(code)


# 마우스 버튼을 뷰포트에 그대로 밀어 넣는다 (GUI 단계까지 거치는 진짜 경로)
func _push_mouse_button(button: MouseButton, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = pos
	ev.pressed = pressed
	get_viewport().push_input(ev)


func _send_key_press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _send_key_release(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = false
	Input.parse_input_event(ev)


func _send_click(world_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	# parse_input_event 는 OS 창 좌표 기준이므로 스트레치 변환까지 적용한다.
	# 캔버스 변환은 main(Node2D)의 것이다 — 하네스는 그냥 Node라 자기 것이 없다
	ev.position = get_viewport().get_screen_transform() * (m.get_canvas_transform() * world_pos)
	Input.parse_input_event(ev)


func _save_shot(suffix: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(m._shot_path + suffix)


# 말 탄 자세를 한 방향으로 고정한다 (걷는 도중 한 컷).
# 하네스는 키를 누르지 않으므로 moving을 직접 세운다.
func _ride_pose(face: String) -> void:
	m.player.dir = face
	m.player.moving = true
	m.player.anim_time = 0.21
	m.player._update_sprite()


# ---- 함께하기 검증 ----
#
# 통신은 헤드리스 한 판으로는 확인할 수가 없다. 호스트와 게스트를 따로
# 띄워서 서로 붙는지, 세계가 넘어오는지, 게스트가 민 변경이 호스트에
# 반영되는지를 본다.
#
#   KYOJIN_SHOT=/tmp/x/ KYOJIN_MP=host  godot --path game &
#   KYOJIN_SHOT=/tmp/x/ KYOJIN_MP=guest godot --path game
#
# 게스트가 MP_*_OK= 줄을 뱉고, 양쪽 다 스스로 끝낸다.
const MP_TILE := Vector2i(20, 20)   # 게스트가 갈아 볼 칸 (농장 빈 자리)

func _mp_tick() -> void:
	_shot_frames += 1
	var guest := Net.is_guest()
	if not guest:
		# 호스트: 게스트가 끝낼 시간을 주고 스스로 나간다
		if _shot_frames == 1:
			m.grid[MP_TILE.y][MP_TILE.x].ground = "grass"
		if _shot_frames == 900:
			get_tree().quit()
		return
	match _shot_frames:
		1:
			print("MP_START: 게스트 시작")
		240:
			# 스냅샷을 받아 세계가 넘어왔는가
			print("MP_CONNECT_OK=", m._net_ready,
				" 접속=", multiplayer.multiplayer_peer != null,
				" 오브젝트=", m.objects.size() > 0)
			print("MP_SNAPSHOT_OK=", m.objects.size() > 0 and m.grid.size() == m.MAP_H)
		250:
			# 게스트가 민 변경이 호스트를 거쳐 되돌아오는가
			m.player.position = Vector2(MP_TILE.x * m.TILE + 16, (MP_TILE.y + 1) * m.TILE + 16)
			GameData.tool = "hoe"
			m.netsync._req_tool.rpc_id(1, MP_TILE.x, MP_TILE.y, "hoe", "",
				int(m.player.position.x), int(m.player.position.y))
		330:
			var g: Dictionary = m.grid[MP_TILE.y][MP_TILE.x]
			print("MP_TOOL_OK=", g.ground == "soil", " 땅=", g.ground)
		340:
			_save_shot("_mp_guest.png")
		360:
			get_tree().quit()
