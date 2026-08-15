# 개발용 검증 하네스 — 게임 로직이 아니다.
#
# KYOJIN_SHOT이 켜졌을 때만 붙는다. 정해진 프레임마다 게임을 조작하고,
# 결과를 print로 뱉고, 스크린샷을 남긴다. 여기서 나오는 `*_OK=...` 줄이
# 곧 이 게임의 회귀 테스트다.
#
#   KYOJIN_SHOT=<디렉터리>/ godot --path game        -> 54장 + 어서션
#   KYOJIN_SHOT=<디렉터리>/ KYOJIN_STORY=1 godot ...  -> 스토리 9장
#
# **단계 번호는 match의 갈래다. 번호가 겹치면 뒤에 온 갈래는 죽은 코드가 된다.**
# 새 단계를 넣기 전에 반드시 확인할 것 (340·360은 _mp_tick과 겹치는 것이라 정상):
#
#   grep -oP "^\t\t\K[0-9]+(?=:)" scripts/dev_harness.gd | sort -n | uniq -d
#
# **화면을 찍는 단계는 389보다 앞 번호를 쓸 것.** 389의 성능 측정이
# `m._process`를 스무 번 돌려 _shot_frames를 그만큼 미는데, 그 사이에는
# 프레임이 그려지지 않아 390~409는 같은 화면만 찍는다.
#
# main의 것은 `m.`으로 부른다 (m = main.gd).
class_name KyojinHarness
extends Node

var m: KyojinMain    # main.gd
var _shot_frames := 0
var _saved_pos := Vector2.ZERO   # 화면용으로 잠깐 옮겨 둔 플레이어 자리
var _desk_keep: Array = []       # 제작대 화면을 찍는 동안 맡아 두는 레시피 목록
var _fog_keep: Dictionary = {}   # 먹구름 화면을 찍는 동안 맡아 두는 탐사 기록


# ---- 검증 시퀀스 ----
# 키/마우스 이벤트를 실제 InputMap 경로로 흘려보내
# 밭갈기->클릭 경작->물주기->파종->자원->설치->상점->결산까지 자동 재생한다.
#
# ※ 단계 번호는 match의 값이다. **절대 겹치면 안 된다** —
#    같은 번호를 두 번 쓰면 뒤에 쓴 쪽이 통째로 죽은 코드가 되고,
#    검사가 조용히 사라진다 (실제로 세 번 당했다).
#    새 단계를 넣기 전에: grep -n "^\t\t[0-9]\+:" 로 빈 번호를 확인할 것.

# 지도 끌기 성능 재기 (393~405단계)
var _bench_us := 0
var _bench_n := 0
var _bench_t0 := 0


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
			# 새 게임 초기 마을: 건물 0채 + NPC는 이장뿐이어야 한다
			var houses := 0
			for hp in m.objects:
				if String(m.objects[hp].kind) == "house":
					houses += 1
			var nids: Array = []
			for n2 in m.npcs:
				nids.append(n2.id)
			var hut0: bool = str(m.objects.get(m.CHIEF_HUT, {}).get("kind", "")) \
				== "chief_hut" and GameData.chief_house_lv == 0
			# 새 게임에는 낡은 표지판이 서 있고, 동쪽 확장 구역은 잠겨 있다
			var zone0: bool = str(m.objects.get(m.OLD_SIGN, {}).get("kind", "")) == "sign" \
				and GameData.story4_phase == "" \
				and not GameData.is_tile_owned(105, 10) and not m.is_passable(Vector2i(105, 10))
			print("VILLAGE_INIT_OK=", GameData.village_built.is_empty()
				and houses == 0 and nids == ["chief"] and hut0 and zone0,
				" 건물=", GameData.village_built, " 지붕칸=", houses, " NPC=", nids,
				" 이장오두막=", hut0, " 동쪽구역잠김=", zone0)
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
		# 방향이 바뀌는 데 한 프레임이 필요하다. 바로 찍으면 앞모습 대신
		# 직전 뒷모습이 걸린다 (실제로 그랬다)
		206: _save_shot("_boy_front.png")
		205:
			_send_key_release(KEY_S)
			_send_key_press(KEY_D)                     # 옆모습 걷기 확인
		209: _save_shot("_boy_side.png")
		210:
			_send_key_release(KEY_D)
			m.player.position = Vector2(88 * m.TILE + 16, 2 * m.TILE + 16)  # 맵 끝 배경 확인
		213: _save_shot("_edge.png")                    # 맵 밖 배경 + 가운데 정렬
		214:
			# 낚시터 (마을 서쪽 호수 남쪽 물가)
			m.player.position = Vector2(49 * m.TILE + 16, m.DOCK_Y * m.TILE + 16)
			m.player.dir = "up"
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
			# 계절 축제: 봄 꽃놀이 날로 옮겨 장식·모임·진행을 확인.
			# **첫 해에는 축제가 열리지 않는다** — 그것부터 확인하고,
			# 두 해째 같은 날로 넘어가 실제 축제를 본다.
			GameData.day = 14
			GameData.minutes = 11.0 * 60.0
			GameData.reset_festival_state()
			var year1_quiet: bool = GameData.festival_today().is_empty() \
				and not GameData.festival_open() and not GameData.fest_year_ok()
			GameData.day = GameData.DAYS_PER_SEASON * 4 + 14   # 두 해째 봄 14일
			GameData.reset_festival_state()
			var ft: Dictionary = GameData.festival_today()
			print("FEST_YEAR1_OK=", year1_quiet,
				" 첫해조용=", year1_quiet, " 두해째=", ft.get("name", "없음"))
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
			# 마무리 대화를 끝까지 넘긴다 -> 보상(하트 러그)이 세간으로 들어오고
			# 대화가 다 끝난 뒤에야 퀘스트 완료 표시가 뜬다
			var talking: bool = m.dialog.visible
			m.dialog.skip_seq()
			var rug_ok := false
			for fi2 in GameData.furniture:
				if str(fi2.id) == "heart_rug":
					rug_ok = true
			rug_ok = rug_ok and talking and GameData.FURNITURE.has("heart_rug")
			m.dialog.close()
			print("STALL_QUEST_OK=", doing and built and sched_ok and rug_ok,
				" 수락=", doing, " 설치=", built, " 시각표=", sched_ok,
				" 하트러그=", rug_ok, " ", GameData.stall_hours)
		339:
			# 노점 이용: 만수가 있을 때만 구매(미끼·한정 레시피), 판매는 상시
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
			# 사도 바로 배워지지 않는다 — 두루마리로 들어오고, 배워야 열린다
			var scroll_ok: bool = GameData.recipe_items.has("dish_smelt_fry") \
				and GameData.recipe_locked("dish_smelt_fry")
			GameData.learn_recipe("dish_smelt_fry")
			var recipe_ok: bool = locked0 and scroll_ok \
				and not GameData.recipe_locked("dish_smelt_fry") \
				and not GameData.recipe_items.has("dish_smelt_fry")
			m.shop.close()
			GameData.minutes = 8.0 * 60.0        # 이른 아침 — 만수가 없다
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
			# ---- 화분(잡화점)·쓰레기통(노점) 레시피: 구매 -> 제작대 -> 집 세간 ----
			m.shop._on_buy_recipe("flower_pot", 200)
			m.shop._on_buy_recipe("trash_bin", 400)
			var scroll2: bool = GameData.recipe_items.has("flower_pot") \
				and GameData.recipe_items.has("trash_bin")
			GameData.learn_recipe("flower_pot")
			GameData.learn_recipe("trash_bin")
			var learned: bool = scroll2 and "flower_pot" in GameData.recipes_unlocked \
				and "trash_bin" in GameData.recipes_unlocked
			var furn0: int = GameData.furniture.size()
			var pot_started: bool = GameData.desk_start("flower_pot")
			GameData.desk_tick(999.0)
			var ring_before := int(GameData.items["forage_ring"])
			var bin_item0 := int(GameData.items.get("trash_bin", 0))
			var bin_started: bool = GameData.desk_start("trash_bin")
			GameData.desk_tick(999.0)
			var made_ids: Array = []
			for fi in GameData.furniture:
				made_ids.append(str(fi.id))
			# 화분은 세간으로, 쓰레기통은 아이템(설치형 무인 판매함)으로 나온다
			var furn_ok: bool = GameData.furniture.size() == furn0 + 1 \
				and "plant" in made_ids and GameData.FURNITURE.has("trash_bin") \
				and int(GameData.items["trash_bin"]) == bin_item0 + 1 \
				and int(GameData.items["forage_ring"]) == ring_before - 2
			print("RECIPE2_OK=", learned and pot_started and bin_started and furn_ok,
				" 배움=", learned, " 화분제작=", pot_started, " 쓰레기통제작=", bin_started,
				" 산출=", furn_ok, " ", made_ids)
			# ---- 희귀 채집물: 기본 0.1% + 해변 채집 레벨로 조금씩 상승 ----
			var keep_beach: Variant = GameData.skills.get("beach")
			GameData.skills["beach"] = {"lv": 1, "xp": 0.0}
			var rare1: float = GameData.beach_rare_chance()
			GameData.skills["beach"] = {"lv": 10, "xp": 0.0}
			var rare10: float = GameData.beach_rare_chance()
			GameData.skills["beach"] = keep_beach
			var rare_ok: bool = absf(rare1 - 0.001) < 0.00001 and rare10 > rare1 \
				and rare10 < 0.01
			# ---- 숨겨진 콘텐츠: 산호 조각 -> 레시피 / 고대 조각 -> 이야기 ----
			GameData.discovered.erase("forage_coral")
			GameData.discovered.erase("forage_relic")
			GameData.recipes_unlocked.erase("dish_coral_tea")
			var tea_locked_before: bool = GameData.recipe_locked("dish_coral_tea")
			m.story.hidden_beach_find("forage_coral")
			var coral_ok: bool = tea_locked_before \
				and not GameData.recipe_locked("dish_coral_tea") and m.dialog.visible
			m.dialog.close()
			m.story.hidden_beach_find("forage_relic")
			var relic_ok: bool = m.dialog.visible
			m.dialog.close()
			GameData.discover("forage_relic")   # 노트 「물에 잠긴 마을」 해금 상태로
			print("HIDDEN_OK=", rare_ok and coral_ok and relic_ok,
				" 확률(1렙)=", rare1, " (10렙)=", rare10,
				" 산호레시피=", coral_ok, " 고대이야기=", relic_ok)
		263:
			# 메인 스토리 4 「오래된 마을의 경계」: 낡은 표지판(E) ->
			# 이장에게 묻기 -> 오래된 지도 -> 첫 구역 해금 ->
			# 남은 구역은 이장의 「마을 확장 이야기」로 되살린다
			m.dialog.close()
			GameData.story4_phase = ""
			GameData.zones_open = []
			var zin := Vector2i(105, 10)          # east_north 안쪽 칸
			m.objects.erase(zin)
			m.grid[zin.y][zin.x].ground = "grass"
			var sign_ok: bool = str(m.objects.get(m.OLD_SIGN, {}).get("kind", "")) == "sign"
			var locked_ok: bool = not GameData.is_tile_owned(zin.x, zin.y) \
				and not m.is_passable(zin)
			# 잠긴 구역에는 집터를 못 놓는다
			GameData.items["housing_kit"] = int(GameData.items.get("housing_kit", 0)) + 1
			var plot_deny: bool = not m.story.try_place_home_plot(Vector2i(107, 10))
			# 표지판 확인 -> 이장에게 묻는 목표
			m.story.examine_old_sign()
			var sign_seq: bool = m.dialog.visible
			m.dialog.close()
			m.story._begin_story4()
			var ask_ok: bool = GameData.story4_phase == "ask" \
				and GameData.story4_objective_short() != ""
			# 이장 대화(오래된 마을 지도) -> 첫 구역 해금
			m.story._start_story4_dialog()
			var chief_seq: bool = m.dialog.visible
			m.dialog.close()
			m.story._end_story4()
			var open1: bool = GameData.story4_phase == "done" \
				and GameData.zones_open.has("east_north") \
				and GameData.is_tile_owned(zin.x, zin.y) and m.is_passable(zin)
			# 둘째 구역은 아직 잠김 -> 「마을 확장 이야기」에서 재료로 해금
			var lock2: bool = not GameData.is_tile_owned(105, 30)
			var wood0: int = GameData.wood
			GameData.wood = maxi(GameData.wood, 200)
			GameData.stone = maxi(GameData.stone, 200)
			var wood1: int = GameData.wood
			m.village._unlock_zone("east_south")
			var open2: bool = GameData.zones_open.has("east_south") \
				and GameData.is_tile_owned(105, 30) \
				and GameData.wood == wood1 - int(GameData.ZONE_COST["east_south"][0])
			# 해금한 구역엔 집터를 놓을 수 있다 (자리를 고르고 놓아 본다)
			for py in range(6, 12):
				for px2 in range(103, 112):
					m.objects.erase(Vector2i(px2, py))
					m.grid[py][px2].ground = "grass"
			var plot_after: bool = m.story.try_place_home_plot(Vector2i(107, 10))
			m.objnode._remove_object(Vector2i(107, 10))   # 정리 (집터 회수)
			if plot_after:
				GameData.home_plots.pop_back()
			GameData.wood = wood0
			m.dialog.close()
			print("STORY4_OK=", sign_ok and locked_ok and plot_deny and sign_seq
				and ask_ok and chief_seq and open1 and lock2 and open2 and plot_after,
				" 표지판=", sign_ok, " 잠김=", locked_ok, " 집터거부=", plot_deny,
				" 표지판대화=", sign_seq, " 묻기=", ask_ok, " 지도대화=", chief_seq,
				" 첫구역=", open1, " 둘째잠김=", lock2, " 둘째해금=", open2,
				" 집터허용=", plot_after)
		264:
			# 이장 거처·마을 성장: 오두막 -> (주민 증가) 새 집 ->
			# (주민 10명) 마을회관 해금·건설 -> 이장 낮 근무
			var hut_ok: bool = str(m.objects.get(m.CHIEF_HUT, {}).get("kind", "")) \
				== "chief_hut" and GameData.chief_house_lv == 0
			var res0: int = m.village_residents()
			var res_ok: bool = res0 == m.npcs.size() + 1
			# 새 집 업그레이드 (아침 훅과 같은 조건·코드)
			var can_up: bool = GameData.chief_house_lv == 0 \
				and res0 >= GameData.CHIEF_HOUSE_RESIDENTS
			GameData.chief_house_lv = 1
			m.objnode._remove_object(m.CHIEF_HUT)
			m.objnode._place_object(m.CHIEF_HUT, "chief_hut", 0)
			var up_ok: bool = can_up and GameData.chief_house_lv == 1 \
				and str(m.objects.get(m.CHIEF_HUT, {}).get("kind", "")) == "chief_hut"
			# 마을회관: 스토리 9(주민 초대)를 밟지 않으면 목록에서 빠진다
			GameData.village_built.erase("hall")
			var keep_s9: String = GameData.story9_phase
			GameData.story9_phase = ""
			var gate_before: bool = m.village._next_village_build() != "hall"
			var dummies: Array = []                 # 임시 주민을 10명 초과까지 채운다
			while m.village_residents() <= GameData.HALL_RESIDENTS:
				m.npcmgr._spawn_npc("forest_girl", Vector2i(74, 22))
				dummies.append(m.npcs[m.npcs.size() - 1])
			GameData.story9_phase = "build"         # 스토리 9의 건설 단계
			var gate_after: bool = m.village_residents() > GameData.HALL_RESIDENTS \
				and m.village._next_village_build() == "hall"
			GameData.wood += 120
			GameData.stone += 80
			m.village._build_village_building("hall")
			GameData.story9_phase = keep_s9
			var hall_ok: bool = GameData.village_built.has("hall") \
				and str(m.objects.get(m.VILLAGE_PLOTS["hall"].anchor,
					{}).get("kind", "")) == "house"
			# 이장 낮 근무 (9~17시 회관) — 집은 그대로다
			var keep_min2: float = GameData.minutes
			GameData.minutes = 12.0 * 60.0
			var work: bool = m.npcmgr.npc_place_now("chief") == "hallwork"
			GameData.minutes = 7.0 * 60.0
			var off_work: bool = m.npcmgr.npc_place_now("chief") != "hallwork"
			GameData.minutes = keep_min2
			for dummy: Node2D in dummies:           # 임시 주민 정리
				m.npcs.erase(dummy)
				dummy.queue_free()
			print("CHIEFGROW_OK=", hut_ok and res_ok and up_ok and gate_before
				and gate_after and hall_ok and work and off_work,
				" 오두막=", hut_ok, " 주민수=", res_ok, "(", res0, "명)",
				" 새집=", up_ok, " 회관잠금=", gate_before, " 회관해금=", gate_after,
				" 회관건설=", hall_ok, " 낮근무=", work, " 아침집=", off_work)
		265:
			# 이주 NPC 공통 「완공 다음 날, 직접 찾아와 첫 인사」 +
			# 집터 자리 고르기 프리뷰 (동물의 숲식 범위 표시)
			m.dialog.close()
			# ① 첫 인사 전에는 잡화점 문이 닫혀 있고 주인도 없다
			GameData.npc_greeted.erase("merchant")
			for nm in m.npcs.duplicate():
				if nm.id == "merchant":
					m.npcs.erase(nm)
					nm.queue_free()
			m.npcmgr._sync_village_npcs()
			var no_spawn := true
			for nm2 in m.npcs:
				if nm2.id == "merchant":
					no_spawn = false
			m.actions._enter_building("general")
			var door_locked: bool = not m.shop_room.visible
			# ② 완공 다음 날 — 만수가 직접 걸어와 인사한다
			GameData.arrivals = [{"id": "merchant", "day": GameData.day - 1}]
			m.story._movein_update(0.016)
			var came: bool = m.story_cutscene and m.story._movein_walker != null \
				and m.is_passable(Vector2i(
					int(m.story._movein_walker.position.x / m.TILE),
					int(m.story._movein_walker.position.y / m.TILE)))   # 물속 스폰 금지
			m.story._movein_route = []               # 걸어온 셈 치고
			m.story._movein_walker.position = m.player.position + Vector2(0.0, 40.0)
			m.story._movein_update(0.016)
			var hello: bool = m.dialog.visible
			m.dialog.close()
			m.story._end_movein("merchant")
			var settled: bool = GameData.npc_greeted.has("merchant") \
				and GameData.arrivals.is_empty() and not m.story_cutscene
			m.actions._enter_building("general")
			var door_open: bool = m.shop_room.visible
			m.shop_room.close()
			# ③ 집터 프리뷰 — 가방 클릭으로 켜지고, 칸 판정대로 놓인다
			GameData.items["housing_kit"] = int(GameData.items.get("housing_kit", 0)) + 1
			m.story.request_place_house()
			var prev_on: bool = m.house_preview
			var bad_tile: bool = not m.story._house_tile_ok(
				m.FOUNTAIN.position.x, m.FOUNTAIN.position.y)   # 분수(물)는 빨강
			var hdoor2 := Vector2i(20, 55)
			for hy2 in range(49, 60):
				for hx2 in range(14, 27):
					m.objnode._remove_object(Vector2i(hx2, hy2))
					m.grid[hy2][hx2].ground = "grass"
					m.grid[hy2][hx2].crop_id = ""
			var good_tile: bool = m.story._house_tile_ok(hdoor2.x, hdoor2.y)
			m.story.confirm_house_preview(hdoor2)
			var placed2: bool = not m.house_preview \
				and str(m.objects.get(hdoor2, {}).get("kind", "")) == "homeplot"
			m.story._pickup_home_plot(hdoor2)     # 정리 — 집터를 도로 거둔다
			GameData.items["housing_kit"] = int(GameData.items["housing_kit"]) - 1
			m.dialog.close()
			print("ARRIVE_OK=", no_spawn and door_locked and came and hello
				and settled and door_open and prev_on and bad_tile and good_tile
				and placed2,
				" 미등장=", no_spawn, " 문닫힘=", door_locked, " 방문=", came,
				" 인사=", hello, " 정착=", settled, " 문열림=", door_open,
				" 프리뷰=", prev_on, " 빨강=", bad_tile, " 초록=", good_tile,
				" 설치=", placed2)
		262:
			# 밤 기절 서브퀘(이장의 걱정) + 초반 무기(돌 창·돌 검) + 화살 +
			# 컬렉션 「풋내기 모험가의 무기」
			m.dialog.close()
			GameData.spear_quest = ""
			GameData.recipes_unlocked.erase("spear")
			GameData.recipes_unlocked.erase("sword")
			GameData.recipe_items.erase("spear")
			# ① 밤에 지네에게 당해 기절한 셈 — 다음 날 아침 이장이 걸어온다
			GameData.spear_quest = "pending"
			m.story._spear_update(0.016)
			var visiting: bool = GameData.spear_quest == "visit"
			for i in 60:
				m.story._spear_update(0.1)
			var spear_talk: bool = m.dialog.visible
			m.dialog.skip_seq()                    # 대사 접기 -> 두루마리 지급 + 완료
			var spear_scroll: bool = GameData.recipe_items.has("spear")
			GameData.learn_recipe("spear")         # 가방에서 「배우기」
			var spear_done: bool = GameData.spear_quest == "done" \
				and spear_scroll and "spear" in GameData.recipes_unlocked
			m.dialog.close()
			print("SPEARQ_OK=", visiting and spear_talk and spear_done,
				" 이장방문=", visiting, " 대화=", spear_talk,
				" 레시피+완료=", spear_done)
			# ② 제작 -> 도구 해금 -> 장착 -> 몬스터 타격
			GameData.wood += 20
			GameData.stone += 20
			var sp_started: bool = GameData.desk_start("spear")
			GameData.desk_tick(999.0)
			GameData.recipes_unlocked.append("sword")   # (훗날 서브퀘 보상 대행)
			var sw_started: bool = GameData.desk_start("sword")
			GameData.desk_tick(999.0)
			var both_unlocked: bool = GameData.is_tool_unlocked("spear") \
				and GameData.is_tool_unlocked("sword")
			# 가짜 밤 몬스터를 코앞에 세우고 창으로 한 방
			var mnode := Node2D.new()
			m.world.add_child(mnode)
			mnode.position = m.player.position + m.FACE_VECS[m.player.dir] * 40.0
			m.night_mobs.append({"node": mnode, "spr": null, "anim": 0.0, "hp": 4.0})
			var keep_tool: String = GameData.tool
			m.toolwork.set_tool("spear")
			m.toolwork._weapon_cd = 0.0
			m.toolwork.use_tool()
			var spear_kill: bool = m.night_mobs.is_empty() \
				and m.toolwork._weapon_cd > 1.0    # 느린 박자 (강타)
			# 검: 빠른 박자 — 첫 타는 약하다 (둘째 타는 타이머로 이어진다)
			var mnode2 := Node2D.new()
			m.world.add_child(mnode2)
			mnode2.position = m.player.position + m.FACE_VECS[m.player.dir] * 40.0
			var mob2 := {"node": mnode2, "spr": null, "anim": 0.0, "hp": 10.0}
			m.night_mobs.append(mob2)
			var keep_slot: String = GameData.tool_slots[0]
			GameData.tool_slots[0] = "sword"
			m.toolwork.set_tool("sword")
			m.toolwork._weapon_cd = 0.0
			m.toolwork.use_tool()
			var sword_hit: bool = float(mob2.hp) < 10.0 and float(mob2.hp) > 0.0 \
				and m.toolwork._weapon_cd < 1.0    # 창보다 빠른 박자
			m.night_mobs.clear()
			mnode2.queue_free()
			GameData.tool_slots[0] = keep_slot
			m.toolwork.set_tool(keep_tool)
			print("WEAPON_OK=", sp_started and sw_started and both_unlocked
				and spear_kill and sword_hit,
				" 제작=", sp_started and sw_started, " 해금=", both_unlocked,
				" 창강타=", spear_kill, " 검연타=", sword_hit)
			# ③ 무기 컬렉션은 걷어냈다 — 따로 지정한 컬렉션(초반 음식)만 남고,
			# 무기는 발견 기록만 쌓인다
			m.doing.gain_item("arrow", 1)
			GameData.discover("arrow")
			GameData._check_collections()
			var weapon_col := false
			for wcol: Dictionary in GameData.COLLECTIONS:
				if (wcol.ids as Array).has("spear") or (wcol.ids as Array).has("arrow"):
					weapon_col = true
			print("WEAPONCOL_OK=", not weapon_col
				and GameData.discovered.has("spear") and GameData.discovered.has("sword"),
				" 무기표없음=", not weapon_col,
				" 발견기록=", GameData.discovered.has("spear"))
		353:
			# 쓰레기통 = 24시간 무인 판매함 — 설치(바깥/집 안)·80% 판매·회수
			GameData.items["trash_bin"] = int(GameData.items.get("trash_bin", 0)) + 2
			var keep_pos: Vector2 = m.player.position
			var keep_dir: String = m.player.dir
			m.player.position = Vector2(24 * m.TILE + 16, 56 * m.TILE + 16)
			m.player.dir = "down"
			m._sel_target = Vector2i(-999, -999)
			m._mouse_target = Vector2i(-999, -999)
			var bin_t := Vector2i(24, 57)
			m.objnode._remove_object(bin_t)
			var bins0 := int(GameData.items["trash_bin"])
			m.village.use_trash_bin()
			var placed_out: bool = str(m.objects.get(bin_t, {}).get("kind", "")) == "trash_bin" \
				and int(GameData.items["trash_bin"]) == bins0 - 1
			m.village.open_trash_bin(bin_t)
			var bin_menu: bool = m.dialog.visible
			m.village._trash_sell()
			var sell80: bool = m.shop.visible and absf(m.shop.sell_mult - 0.8) < 0.001
			GameData.items["forage_glass"] = 10       # 무인 판매는 제값의 80%
			var money_t: int = GameData.money
			var glass_g: int = GameData.item_value("forage_glass")
			m.shop._on_sell_item("forage_glass")
			var paid: bool = GameData.money == money_t + int(glass_g * 0.8) * 10 \
				and int(GameData.items["forage_glass"]) == 0
			m.shop.close()
			m.shop.open("sell", ["sell"], "잡화점 — 판매")
			var normal100: bool = absf(m.shop.sell_mult - 1.0) < 0.001
			m.shop.close()
			var bins1 := int(GameData.items["trash_bin"])
			m.village._trash_pickup(bin_t)
			var picked_up: bool = not m.objects.has(bin_t) \
				and int(GameData.items["trash_bin"]) == bins1 + 1
			# 집 안(확장된 집): 세간으로 들여놓는다
			m.interior.open()
			var furn_b: int = GameData.furniture.size()
			m.village.use_trash_bin()
			var in_house: bool = GameData.furniture.size() == furn_b + 1 \
				and str(GameData.furniture[furn_b].id) == "trash_bin"
			m.interior.close()
			m.player.position = keep_pos
			m.player.dir = keep_dir
			print("TRASHBIN_OK=", placed_out and bin_menu and sell80 and paid
				and normal100 and picked_up and in_house,
				" 설치=", placed_out, " 메뉴=", bin_menu, " 판매80=", sell80,
				" 정산=", paid, " 정상가=", normal100, " 회수=", picked_up,
				" 집안설치=", in_house)
		350:
			# 메인 스토리 3 「새로운 주민의 이사」 -> 5 「숲속에서 발견한 집」 전체 체인:
			# 이주 편지 -> 이장 상의(결정권 이양) -> 집터 레시피·제작 -> 집 자리
			# 직접 선정 -> 다음 날 재민 이사·첫인사 -> (다음 날) 숲속 집 발견담
			# -> 이장도 모름 -> 모녀 만남 -> 호감도 해금
			GameData.move_quest = ""
			GameData.forest_quest = ""
			GameData.affinity_open = false
			# 샌드박스는 마을 건물을 다 세워 두었다 — 우체국만 도로 헐고
			# 이야기로 다시 짓는다 (3장의 마지막 퀘스트)
			var k_built3: Array = GameData.village_built.duplicate()
			GameData.village_built.erase("post")
			GameData.move_house = Vector2i(-999, -999)
			GameData.move_day = GameData.day - 1
			for n0 in m.npcs.duplicate():          # 샌드박스가 미리 깔아 둔 재민 제거
				if n0.id == "explorer":
					m.npcs.erase(n0)
					n0.queue_free()
			m.story._move_update(0.016)
			var letter_ok: bool = m.dialog.visible and GameData.move_quest == "letter"
			m.dialog.close()
			m.story._end_move_letter()
			var show_q: bool = GameData.move_quest == "show" \
				and GameData.move_objective_short() != ""
			var chief_npc: Node2D = null
			for n3 in m.npcs:
				if n3.id == "chief":
					chief_npc = n3
			# 해금 전에는 하트·선물 없이 담백한 대화만... 인데 지금은 이장이
			# 스토리 대화(이주 상의)를 먼저 꺼낸다 — 훅이 잘 걸리는지 본다
			m.village._talk_to(chief_npc)
			var chief_talk: bool = m.dialog.visible
			m.dialog.close()
			m.story._end_move_chief()
			var build_q: bool = GameData.move_quest == "build"
			# 집터 레시피 구매(비싸다) + 제작(재료가 많이 든다)
			var money_b: int = GameData.money
			m.shop._on_buy_recipe("housing_kit", GameData.HOUSING_KIT_PRICE)
			GameData.learn_recipe("housing_kit")   # 가방 두루마리에서 배운다
			var recipe_ok2: bool = "housing_kit" in GameData.recipes_unlocked \
				and GameData.money == money_b - GameData.HOUSING_KIT_PRICE
			GameData.wood += 60
			GameData.stone += 40
			GameData.items["nail"] = int(GameData.items.get("nail", 0)) + 4
			var kit0 := int(GameData.items.get("housing_kit", 0))
			var kit_started: bool = GameData.desk_start("housing_kit")
			GameData.desk_tick(999.0)
			var kit_ok: bool = kit_started \
				and int(GameData.items["housing_kit"]) == kit0 + 1
			# 집터가 없으면 수락이 막히고 편지는 그대로 남는다
			var letters0 := int(GameData.items.get("move_letter", 0))
			GameData.home_plots = []
			m.story._try_accept_move()
			var no_plot_block: bool = GameData.move_quest == "build" \
				and int(GameData.items["move_letter"]) == letters0
			# 물가에는 못 놓는다 / 트인 풀밭에는 빈 집터가 놓인다
			var bad_ok: bool = not m.story.try_place_home_plot(Vector2i(2, m.SEA_Y0))
			var hdoor := Vector2i(20, 55)
			for hy in range(49, 60):
				for hx in range(14, 27):
					m.objnode._remove_object(Vector2i(hx, hy))
					m.grid[hy][hx].ground = "grass"
					m.grid[hy][hx].crop_id = ""
			var placed: bool = m.story.try_place_home_plot(hdoor)
			var plot_ok: bool = placed \
				and GameData.first_empty_plot() == hdoor - Vector2i(2, 3) \
				and str(m.objects.get(hdoor, {}).get("kind", "")) == "homeplot" \
				and int(GameData.items["housing_kit"]) == kit0
			# 빈 집터가 생겼으니 편지를 다시 수락한다 -> 집이 지어진다
			m.story._try_accept_move()
			var house2_ok: bool = GameData.move_quest == "wait" \
				and str(m.objects.get(hdoor - Vector2i(2, 3), {}).get("kind", "")) == "house" \
				and GameData.first_empty_plot().x < 0 \
				and int(GameData.items["move_letter"]) == letters0 - 1
			GameData.day += 1                      # 다음 날 — 재민이 이사 온다
			m.story._move_update(0.016)
			# 공통 규칙: 재민이 직접 찾아온다 (도착 연출 시작 -> 걸어오는 중)
			m.story._movein_update(0.016)
			var have_ex := false
			for nx in m.npcs:
				if nx.id == "explorer":
					have_ex = true
			var greet_q: bool = GameData.move_quest == "greet" and have_ex \
				and m.story_cutscene
			m.story._start_move_greet_dialog()
			var greet_talk: bool = m.dialog.visible
			m.dialog.skip_seq()                    # 첫인사 끝 -> 씨앗 퀘스트로
			var seed_q: bool = GameData.move_quest == "seed"
			m.dialog.close()

			# ── 3-② 「씨앗 한 줌」 — 씨앗을 받고 배고픔이 열린다
			var seed0 := GameData.seed_total()
			m.story._start_move_seed_dialog()
			m.dialog.skip_seq()
			m.dialog.close()
			var hunger_on: bool = GameData.hunger_open \
				and GameData.seed_total() == seed0 + GameData.MOVE_SEEDS \
				and GameData.move_objective_short().contains("0/%d" % GameData.MOVE_SEEDS)
			for si in GameData.MOVE_SEEDS:
				GameData.move_seed_planted()
			var seed_done: bool = GameData.move_quest == "seedrep" \
				and GameData.quest_npc_marks().get("explorer", "") == "?"
			m.story._start_move_seedrep_dialog()
			m.dialog.skip_seq()
			m.dialog.close()
			var post_q: bool = GameData.move_quest == "post" \
				and GameData.quest_npc_marks().get("chief", "") == "!"

			# ── 3-③ 「마을에 우체국을」 — 3장의 마지막 퀘스트
			var post_gated: bool = m.village._next_village_build() != "post"
			m.story._start_move_post_dialog()
			m.dialog.skip_seq()
			m.dialog.close()
			var post_open: bool = GameData.move_quest == "postbuild" \
				and m.village._next_village_build() == "post"
			var pcost: Array = m.VILLAGE_BUILD_COST["post"]
			GameData.wood += int(pcost[0])
			GameData.stone += int(pcost[1])
			m.village._build_village_building("post")
			m.dialog.close()
			var built_post: bool = GameData.village_built.has("post") \
				and GameData.move_quest == "postgreet" \
				and str(m.objects.get(m.VILLAGE_PLOTS["post"].anchor, {})
					.get("kind", "")) == "house"
			var post_arrival := false
			for a2: Dictionary in GameData.arrivals:
				if str(a2.id) == "postman":
					post_arrival = true
			m.story._start_postman_settle_dialog()
			var post_talk: bool = m.dialog.visible
			m.dialog.skip_seq()                    # 재회 인사 끝 -> 3장 완결
			var move_done: bool = GameData.move_quest == "done" \
				and GameData.forest_quest == "settle" \
				and GameData.npc_greeted.has("postman")
			m.dialog.close()
			print("MOVE_OK=", letter_ok and show_q and chief_talk and build_q
				and recipe_ok2 and kit_ok and no_plot_block and bad_ok and plot_ok
				and house2_ok and greet_q and greet_talk and seed_q and hunger_on
				and seed_done and post_q and post_gated and post_open
				and built_post and post_arrival and post_talk and move_done,
				" 편지=", letter_ok, " 이장상의=", show_q and chief_talk,
				" 결정권=", build_q, " 레시피=", recipe_ok2, " 제작=", kit_ok,
				" 집터없이수락거부=", no_plot_block, " 물가거부=", bad_ok,
				" 빈집터=", plot_ok, " 수락후집완공=", house2_ok, " 이사=", greet_q,
				" 첫인사=", greet_talk and seed_q, " 씨앗·배고픔=", hunger_on,
				" 씨앗심기=", seed_done, " 이장호출=", post_q,
				" 우체국잠김=", post_gated, " 우체국해금=", post_open,
				" 우체국완공=", built_post, " 우체부방문=", post_arrival,
				" 우체부정착=", post_talk and move_done)
			GameData.village_built = k_built3
			GameData.day += 1                      # 하룻밤 자고 나면 발견담이 뜬다
			m.story._forest_update(0.016)
			var found_q: bool = GameData.forest_quest == "found" \
				and GameData.forest_objective_short() != ""
			m.story._start_explorer_found_dialog()
			m.dialog.close()
			m.story._end_explorer_found()
			var ask_q: bool = GameData.forest_quest == "ask" \
				and GameData.quest_npc_marks().get("chief", "") == "!"
			m.story._start_forest_ask_dialog()
			m.dialog.skip_seq()                    # 「나도 같이 가겠네」 -> 동행 시작
			m.dialog.close()
			# 셋이 함께 간다 — 이장·재민이 뒤를 따르고, 집은 그때 세워진다
			var house_ok: bool = GameData.forest_quest == "go" \
				and str(m.objects.get(m.FOREST_HOUSE_ANCHOR, {}).get("kind", "")) == "house" \
				and m.is_passable(m.door_tile(m.FOREST_HOUSE_ANCHOR))
			var mom_ok := false
			var girl_ok := true                    # 솔이는 아직 나오지 않는다
			for n5 in m.npcs:
				if n5.id == "forest_mom":
					mom_ok = true
				elif n5.id == "forest_girl":
					girl_ok = false
			# 두 사람이 플레이어를 뒤따라 걷는다
			var _keep_pos5 := m.player.position
			var chief5: Variant = m.story._npc_by_id("chief")
			var exp5: Variant = m.story._npc_by_id("explorer")
			var party_ok := chief5 != null and exp5 != null
			if party_ok:
				chief5.position = m.player.position + Vector2(600.0, 0.0)
				var far0: float = chief5.position.distance_to(m.player.position)
				for _pi in 40:
					m.story._forest_party_update(0.05)
				party_ok = chief5.position.distance_to(m.player.position) < far0 \
					and chief5.scripted
			# 문 앞에 서면 저절로 문을 두드린다
			m.player.position = Vector2(
				m.door_tile(m.FOREST_HOUSE_ANCHOR).x * m.TILE + 16,
				m.door_tile(m.FOREST_HOUSE_ANCHOR).y * m.TILE + 16)
			m.story._forest_party_update(0.016)
			var meet: bool = m.dialog.visible
			var meet_txt := ""
			for e5: Dictionary in m.dialog._seq:
				meet_txt += str(e5.get("text", "")) + " "
			# 딸은 모습을 보이지 않고, 집 안으로도 들이지 않는다
			var no_girl: bool = not meet_txt.contains("솔이") \
				and meet_txt.contains("이장") and meet_txt.contains("돌아가")
			m.dialog.skip_seq()
			m.dialog.close()
			var back_q: bool = GameData.forest_quest == "back" \
				and not GameData.affinity_open \
				and GameData.quest_npc_marks().get("chief", "") == "?"
			# 돌아오는 길 — 이장의 조언에서 호감도가 열린다
			m.story._start_forest_back_dialog()
			m.dialog.skip_seq()
			var done_ok: bool = GameData.forest_quest == "done" \
				and GameData.affinity_open and m.dialog.visible
			m.dialog.close()
			m.player.position = _keep_pos5
			# ---- 스토리 5 이후: 호감도 5에서 연화가 문을 연다 ----
			var k_aff5 := int(GameData.affinity.get("forest_mom", 0))
			GameData.forest_trust = ""
			GameData.affinity["forest_mom"] = GameData.FOREST_TRUST_AFF - 1
			m.story._forest_trust_update(0.016)
			var trust_gate: bool = GameData.forest_trust == ""
			GameData.affinity["forest_mom"] = GameData.FOREST_TRUST_AFF
			m.story._forest_trust_update(0.016)
			var trust_open: bool = GameData.forest_trust == "invited" \
				and GameData.quest_npc_marks().get("forest_mom", "") == "!" \
				and GameData.forest_trust_objective_short() != ""
			m.story._start_forest_trust_dialog()
			var trust_txt := ""
			for e6: Dictionary in m.dialog._seq:
				trust_txt += str(e6.get("text", "")) + " "
			m.dialog.skip_seq()
			m.dialog.close()
			var girl_meet := false
			for n6 in m.npcs:
				if n6.id == "forest_girl":
					girl_meet = true
			var trust_done: bool = GameData.forest_trust == "done" \
				and trust_txt.contains("솔이") and girl_meet
			GameData.affinity["forest_mom"] = k_aff5
			GameData.day -= 2
			print("FOREST_OK=", found_q and ask_q and house_ok and mom_ok
				and girl_ok and party_ok and meet and no_girl and back_q
				and done_ok and trust_gate and trust_open and trust_done,
				" 발견담=", found_q, " 이장보고=", ask_q,
				" 숲속의집=", house_ok, " 연화=", mom_ok, " 솔이숨김=", girl_ok,
				" 동행=", party_ok, " 문앞장면=", meet, " 딸안나옴=", no_girl,
				" 돌아오는길=", back_q, " 완료+호감도해금=", done_ok,
				" 호감도게이트=", trust_gate, " 초대=", trust_open,
				" 솔이첫만남=", trust_done)
			# ---- 연화의 서브 퀘스트 시스템 (표 주도 — 임시 퀘스트로 흐름만 검증) ----
			GameData.MOM_QUESTS = [{"id": "_test", "name": "솔이의 감자죽 재료",
				"item": "weed", "qty": 3, "money": 120, "affinity": 4}]
			# 스토리 5 완료 전에는 잠긴다
			var keep_fq: String = GameData.forest_quest
			GameData.forest_quest = "visit"
			var locked_before: bool = GameData.mom_next_quest().is_empty()
			GameData.forest_quest = keep_fq            # "done"으로 복귀
			var offered: bool = not GameData.mom_next_quest().is_empty() \
				and not m.village._mom_quest_option().is_empty()
			m.village._mom_quest_start("_test")
			var accepted: bool = GameData.mom_quest == "_test" and m.dialog.visible
			m.dialog.close()
			GameData.items["weed"] = 1                 # 모자라면 진행 중 안내만
			m.village._mom_quest_turnin("_test")
			var still: bool = GameData.mom_quest == "_test"
			m.dialog.close()
			GameData.items["weed"] = 3
			var money_m: int = GameData.money
			var aff_m := int(GameData.affinity["forest_mom"])
			m.village._mom_quest_turnin("_test")
			var served: bool = GameData.mom_quest == "" \
				and "_test" in GameData.mom_quests_done \
				and GameData.money == money_m + 120 \
				and int(GameData.affinity["forest_mom"]) == aff_m + 4 \
				and int(GameData.items["weed"]) == 0
			var no_more: bool = GameData.mom_next_quest().is_empty()   # 표를 다 비웠다
			m.dialog.close()
			GameData.MOM_QUESTS = []                   # 임시 표 정리
			GameData.mom_quests_done.erase("_test")
			print("MOMQUEST_OK=", locked_before and offered and accepted and still
				and served and no_more,
				" 해금전잠금=", locked_before, " 제안=", offered, " 수락=", accepted,
				" 진행중=", still, " 납품보상=", served, " 표소진=", no_more)
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
		240:
			# 휘두르기 네 위상을 한 장씩 찍는다. 도구가 **주먹에 붙어** 따라가는지,
			# 도트가 위상마다 제대로 바뀌는지는 수치로는 안 보이고 그림을 봐야 한다.
			# (주먹 자리는 player.gd의 SWING_HAND_DOT에 손으로 적어 넣은 값이라
			#  그림을 다시 뽑으면 여기서 어긋난 게 드러난다)
			m.player.position = Vector2(29 * m.TILE + 16, 40 * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m.toolwork.set_tool("axe")
			_swing_pose(0)
		# 위상마다 **두 프레임** 붙들었다가 찍는다. 한 프레임만 세우면
		# 그림이 그려지기 전에 다음 위상으로 넘어가 한 칸씩 밀려 찍힌다
		# (플레이어의 _process와 이 tick 중 어느 쪽이 먼저인지에 달렸다).
		241: _swing_pose(0)
		242:
			_save_shot("_swing_p0.png")
			_swing_pose(1)
		243: _swing_pose(1)
		244:
			_save_shot("_swing_p1.png")
			_swing_pose(2)
		245: _swing_pose(2)
		246:
			_save_shot("_swing_p2.png")
			_swing_pose(3)
		247: _swing_pose(3)
		248:
			_save_shot("_swing_p3.png")
			_swing_pose(4)
		249: _swing_pose(4)
		250:
			_save_shot("_swing_p4.png")
			m.player.swing_t = 0.0
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
			var pier := Vector2i(49, m.DOCK_Y + 1)   # 호수 남쪽 물가
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
				" 상체 기울기=", "%.2f" % m.player.upper_sprite.rotation)
			# 완급: 내리치는 정점이 판정 순간(HIT_AT)에 **정확히** 와야 한다.
			# 어긋나면 도끼가 아직 내려오는 중인데 나무가 맞는다 (예전이 그랬다).
			var hp2: float = m.HIT_AT / m.SWING_TIME
			var sw_start: float = m.player._swing_curve(0.0)
			var sw_wind: float = m.player._swing_curve(hp2 * 0.62)
			var sw_hit: float = m.player._swing_curve(hp2)
			var sw_end: float = m.player._swing_curve(1.0)
			print("SWING_TIMING_OK=", is_equal_approx(sw_hit, 1.0)
					and is_equal_approx(sw_wind, -1.0)
					and absf(sw_start) < 0.01 and absf(sw_end) < 0.01,
				" 시작=", "%.2f" % sw_start, " 다감음=", "%.2f" % sw_wind,
				" 타격=", "%.2f" % sw_hit, " 끝=", "%.2f" % sw_end)
			# 자세는 둘 중 **하나로만** 만든다.
			#   도트가 있으면 그림이 자세를 쥐고 몸은 안 가른다
			#   도트가 없으면 상·하체를 갈라 상체만 돌린다 (다리는 각 0)
			# 둘 다 하면 허리가 두 번 접히고, 자른 자리가 그림의 팔을 가로지른다.
			var dot: String = m.player._swing_frame(m.player._swing_key())
			var split_ok: bool = (m.player.upper_sprite.visible
				and m.player.sprite.region_enabled
				and absf(m.player.upper_sprite.rotation) > 0.05
				and is_equal_approx(m.player.sprite.rotation, 0.0))
			print("SWING_SPLIT_OK=", split_ok != (dot != ""),
				" 도트=", dot, " 갈라그림=", split_ok,
				" 상체각=", "%.2f" % m.player.upper_sprite.rotation)
			# 위상은 진행도를 따라 0->1->2->3->4로 **한 번씩만** 지나야 한다.
			# swing_c로 가르면 감을 때와 되돌아올 때가 같은 값을 지나서
			# 한 위상이 두 번 나온다 (팔이 갔다가 되짚어 오는 것처럼 보인다).
			var seq: Array = []
			var keep_t: float = m.player.swing_t
			for k in 40:
				m.player.swing_t = m.player.swing_len * (1.0 - float(k) / 39.0)
				var ph: int = m.player.swing_phase()
				if seq.is_empty() or seq[-1] != ph:
					seq.append(ph)
			m.player.swing_t = keep_t
			print("SWING_PHASE_OK=", seq == [0, 1, 2, 3, 4], " 위상=", seq)
			_save_shot("_swing.png")
		266:
			# #122: 메인 스토리 7 「식지 않는 화로」·8 「초원에서 온 목동」 흐름
			var k_s6 := GameData.story6_phase
			var k_s7 := GameData.story7_phase
			var k_s8 := GameData.story8_phase
			var k_built78: Array = GameData.village_built.duplicate()
			var k_greet78: Array = GameData.npc_greeted.duplicate()
			var k_ore78 := int(GameData.items["ore"])
			var k_gem78 := int(GameData.items["gem"])
			var had_rancher := false
			for n8 in m.npcs:
				if n8.id == "rancher":
					had_rancher = true
			m.dialog.close()
			# 스토리 7 — 시작 조건: 스토리 6 완결 + 대장간 + 무쇠 정착
			GameData.story6_phase = "done"
			GameData.story7_phase = ""
			GameData.story8_phase = ""
			if not GameData.village_built.has("smith"):
				GameData.village_built.append("smith")
			if not GameData.npc_greeted.has("blacksmith"):
				GameData.npc_greeted.append("blacksmith")
			m.story._story7_update(0.1)
			var s7_start: bool = GameData.story7_phase == "worry"
			m.story._end_forge_worry()
			var s7_lore: bool = GameData.story7_phase == "lore"
			m.story._end_forge_lore()
			var s7_gather: bool = GameData.story7_phase == "gather"
			# 재료가 모자라면 화로는 켜지지 않는다
			GameData.items["ore"] = 0
			GameData.items["gem"] = 0
			m.story._end_forge_fire()
			var s7_block: bool = GameData.story7_phase == "gather"
			GameData.items["ore"] = GameData.STORY7_ORE
			GameData.items["gem"] = GameData.STORY7_GEM
			m.story._end_forge_fire()
			var s7_done: bool = GameData.story7_phase == "done" \
				and int(GameData.items["ore"]) == 0 \
				and int(GameData.items["gem"]) == 0
			var s7_disc: bool = GameData.forge_price(100) == 80
			# 스토리 8 — 목동 방문 → 이장 상의 → 목장 게이트 → 완공 → 정착
			m.story._story8_update(0.1)
			var s8_start: bool = GameData.story8_phase == "visit"
			var visitor := false
			for n9 in m.npcs:
				if n9.id == "rancher":
					visitor = true
			m.story._end_rancher_visit()
			var s8_ask: bool = GameData.story8_phase == "ask"
			GameData.village_built = ["post", "general", "smith", "library"]
			var gated8: bool = m.village._next_village_build() != "ranch"
			m.story._end_ranch_chief()
			var s8_build: bool = GameData.story8_phase == "build" \
				and m.village._next_village_build() == "ranch"
			GameData.npc_greeted.erase("rancher")
			GameData.village_built.append("ranch")
			m.story._end_ranch_done()
			var s8_done: bool = GameData.story8_phase == "done" \
				and GameData.npc_greeted.has("rancher")
			# 뒷정리 — 화면·상태를 시험 전으로 되돌린다
			m.dialog.close()
			m.hud._toast_queue.clear()
			if m.hud._sb_layer != null:
				m.hud._sb_layer.visible = false
			GameData.story6_phase = k_s6
			GameData.story7_phase = k_s7
			GameData.story8_phase = k_s8
			GameData.village_built = k_built78
			GameData.npc_greeted = k_greet78
			GameData.items["ore"] = k_ore78
			GameData.items["gem"] = k_gem78
			if not had_rancher:
				for n10 in m.npcs.duplicate():
					if n10.id == "rancher":
						m.npcs.erase(n10)
						n10.queue_free()
			print("STORY78_OK=", s7_start and s7_lore and s7_gather and s7_block
				and s7_done and s7_disc and s8_start and visitor and s8_ask
				and gated8 and s8_build and s8_done,
				" 화로시작=", s7_start, " 책구절=", s7_lore, " 수집=", s7_gather,
				" 부족차단=", s7_block, " 재점화=", s7_done, " 할인=", s7_disc,
				" 목동방문=", s8_start and visitor, " 이장상의=", s8_ask,
				" 목장게이트=", gated8, " 건설해금=", s8_build, " 정착=", s8_done)
		267:
			# #123/#124: 꿈속 엔딩 — 7분야 만렙 증표·유품 5종·항아리·물약·꿈
			var keep_found: Dictionary = GameData.water_life_found.duplicate()
			var keep_wl := int(GameData.items["water_life"])
			var keep_ds := GameData.dream_seen
			var keep_skl: Dictionary = {}
			for sid0: String in GameData.ENDING_SKILLS:
				keep_skl[sid0] = (GameData.skills[sid0] as Dictionary).duplicate()
			var keep_rel: Dictionary = {}
			for rd0: Dictionary in GameData.RELICS:
				keep_rel[rd0.id] = int(GameData.items[rd0.id])
				GameData.items[rd0.id] = 0
			m.dialog.close()
			# ① 생명의 물 — 분야 만렙을 찍는 순간 한 병 (분야당 한 번뿐).
			#    병은 스토리 19가 열린 뒤에만 생긴다
			var keep_s19 := GameData.story19_phase
			GameData.story19_phase = "seek"
			GameData.water_life_found = {}
			GameData.items["water_life"] = 0
			GameData.dream_seen = false
			GameData.skills["mine"] = {"lv": GameData.SKILL_MAX_LV - 1, "xp": 0.0}
			GameData.add_skill_xp("mine", 999999.0)   # 진짜 레벨업 경로로 만렙
			var first: bool = GameData.water_life_found.has("mine") \
				and int(GameData.items["water_life"]) == 1
			GameData.check_skill_water("mine")   # 같은 분야는 두 번 안 준다
			var dup: bool = int(GameData.items["water_life"]) == 1
			for sid1: String in GameData.ENDING_SKILLS:
				GameData.skills[sid1] = {"lv": GameData.SKILL_MAX_LV, "xp": 0.0}
				GameData.check_skill_water(sid1)
			GameData.water_pending = 0
			var six: bool = int(GameData.items["water_life"]) == 7 \
				and GameData.water_life_found.size() == 7
			# ①-2 할머니의 유품 — 하나씩만, 마지막 힌트는 노트 100%에서 열린다
			var r_first: bool = GameData.try_relic(0, 0.0, true)
			var r_dup: bool = not GameData.try_relic(0, 0.0, true)
			var r_hint: bool = not GameData.relic_hint_open(4) \
				or GameData.note_progress().ratio >= 1.0
			for ri in [1, 2, 3, 4]:
				GameData.try_relic(ri, 0.0, true)
			GameData.relic_pending = ""
			var relics5: bool = GameData.relics_owned() == 5
			# ② 노트가 100%가 아니면 마지막 이야기의 조건이 차지 않는다
			var gate_note: bool = not GameData.ending_ready() \
				and GameData.note_progress().ratio < 1.0
			# ③ 엔딩 시퀀스: 달라진 마을 -> 통계 -> 노트 마지막 줄 ->
			#    마을 사람들 -> 마무리. 끝나도 날짜는 넘어가지 않는다
			var keep_ds2 := GameData.dream_seen
			GameData.dream_seen = false
			m.ending.begin()
			var town_on: bool = m.ending.visible and m.ending.phase == "town"
			var town_line := false
			for dl: Array in m.ending._lines:
				if str(dl[1]).contains("삶은 아직 끝나지 않았다"):
					town_line = true
			for i2 in m.ending._lines.size():
				m.ending._advance()
			var stats_on: bool = m.ending.phase == "stats"
			var stat_n0: int = m.ending._lines.size()
			while m.ending._idx < m.ending._lines.size():
				m.ending._reveal_next_stat()
			m.ending._advance()
			var note_on: bool = m.ending.phase == "note"
			m.ending._advance()
			var credits_on: bool = m.ending.phase == "credits"
			var has_postman := false
			var has_all_line := false
			for card: Dictionary in m.ending._cards:
				if str(card.name) == "우체부 아저씨":
					has_postman = true
				if str(card.line).contains("우린 언제나 여기에 있으니까"):
					has_all_line = true
			while m.ending.phase == "credits":
				m.ending._advance()
			var outro_on: bool = m.ending.phase == "outro"
			var day_before := GameData.day
			m.ending.wake()
			var woke: bool = not m.ending.visible and GameData.dream_seen \
				and m.hud.visible and GameData.day == day_before
			GameData.dream_seen = keep_ds2
			m.hud._toast_queue.clear()
			GameData.story19_phase = keep_s19
			GameData.water_life_found = keep_found
			GameData.items["water_life"] = keep_wl
			GameData.dream_seen = keep_ds
			for sid2: String in keep_skl:
				GameData.skills[sid2] = keep_skl[sid2]
			for rid2: String in keep_rel:
				GameData.items[rid2] = int(keep_rel[rid2])
			print("ENDING_OK=", first and dup and six and r_first and r_dup
				and r_hint and relics5 and gate_note and town_on and town_line
				and stats_on and stat_n0 >= 10 and note_on and credits_on
				and has_postman and has_all_line and outro_on and woke,
				" 만렙첫병=", first, " 중복차단=", dup, " 일곱병=", six,
				" 유품=", r_first and r_dup and relics5, " 힌트게이트=", r_hint,
				" 노트게이트=", gate_note, " 달라진마을=", town_on and town_line,
				" 통계=", stats_on, "(", stat_n0, "줄) 마지막기록=", note_on,
				" 크레딧=", credits_on and has_postman and has_all_line,
				" 계속플레이=", outro_on and woke)
		268:
			# #125: 주민 분류·이사(입주/이탈)·삼자 대화·유니콘 뿔 제거
			var k_settlers: Array = GameData.settlers.duplicate()
			var k_homes: Dictionary = GameData.settler_homes.duplicate()
			var k_empty: Array = GameData.empty_houses.duplicate()
			var k_offer := GameData.settler_offer
			var k_arrive := GameData.settler_arrive
			var k_leaving := GameData.settler_leaving
			var k_move := GameData.move_quest
			var k_sl := int(GameData.items["settle_letter"])
			var k_fl := int(GameData.items["farewell_letter"])
			var k_aff_f := int(GameData.affinity["farmer"])
			var k_aff_d := int(GameData.affinity["foodie"])
			m.dialog.close()
			# ① 분류 — 필수/일반/특수
			var kinds: bool = GameData.settler_kind("chief") == "core" \
				and GameData.settler_kind("farmer") == "normal" \
				and GameData.settler_kind("alchemist") == "special"
			# 연금술사는 노트 50% 전에는 후보에도 안 오른다
			var no_alch: bool = GameData.note_progress().ratio >= 0.5 \
				or "alchemist" not in GameData.settler_candidates()
			# ② 입주 — 편지 수락 -> 빈 집 배정 -> 다음 날 아침 도착
			GameData.move_quest = "done"
			GameData.settlers = []
			GameData.settler_homes = {}
			GameData.empty_houses = [[60, 40]]
			GameData.settler_offer = "farmer"
			GameData.items["settle_letter"] = 1
			GameData.settler_arrive = ""
			GameData.settler_leaving = ""
			m.story._settle_accept()
			var accepted: bool = GameData.settler_arrive == "farmer" \
				and GameData.settler_homes.has("farmer") \
				and int(GameData.items["settle_letter"]) == 0 \
				and GameData.empty_houses.is_empty()
			GameData.settler_arrive_day = GameData.day - 1
			m.story._settler_update(0.1)
			var arrived: bool = "farmer" in GameData.settlers
			var spawned := false
			for na in m.npcs:
				if na.id == "farmer":
					spawned = true
			# ③ 삼자 대화 — 곁의 두 주민 사이에 끼면 질문+선택지, 호감도 상승
			var fnode: Variant = null
			for nb in m.npcs:
				if nb.id == "farmer":
					fnode = nb
			m.npcmgr._spawn_npc("foodie", Vector2i(int(fnode.position.x / m.TILE) + 1,
				int(fnode.position.y / m.TILE)))
			var dnode: Node2D = m.npcs[m.npcs.size() - 1]
			dnode.position = fnode.position + Vector2(48, 0)
			m.player.position = fnode.position + Vector2(0, 40)
			var buddy: Variant = m.village._chat_buddy(fnode)
			var trio_near: bool = buddy != null
			m.village._start_trio_dialog(fnode, buddy)
			var trio_open: bool = m.dialog.visible
			m.dialog.close()
			m.village._trio_pick("foodie")
			var trio_aff: bool = int(GameData.affinity["foodie"]) == k_aff_d + 6
			# ④ 이탈 — 「이사 가고 싶다」 대화에서 붙잡으면 남는다
			GameData.settler_leaving = "farmer"
			m.story.start_leaving_dialog("farmer")
			var leave_open: bool = m.dialog.visible
			m.dialog.close()
			var aff_before := int(GameData.affinity["farmer"])
			m.story._leave_persuade("farmer")
			var persuaded: bool = GameData.settler_leaving == "" \
				and int(GameData.affinity["farmer"]) == aff_before + 15
			# 말없이 떠나면 빈 집과 작별 편지가 남는다
			m.story._settler_depart("farmer", true)
			var gone: bool = "farmer" not in GameData.settlers \
				and not GameData.empty_houses.is_empty() \
				and int(GameData.items["farewell_letter"]) == k_fl + 1 \
				and GameData.last_farewell == "순돌"
			m.story.open_farewell_letter()
			var fw_read: bool = m.dialog.visible \
				and int(GameData.items["farewell_letter"]) == k_fl
			m.dialog.close()
			# ⑤ 유니콘 뿔 리소스 제거 — 최후의 연금술 진입점이 사라졌다
			var no_horn: bool = not m.has_method("show_ending") \
				and not m.story.has_method("show_ending")
			# 뒷정리
			for nc in m.npcs.duplicate():
				if nc.id in ["farmer", "foodie"]:
					m.npcs.erase(nc)
					nc.queue_free()
			m.hud._toast_queue.clear()
			GameData.settlers = k_settlers
			GameData.settler_homes = k_homes
			GameData.empty_houses = k_empty
			GameData.settler_offer = k_offer
			GameData.settler_arrive = k_arrive
			GameData.settler_leaving = k_leaving
			GameData.move_quest = k_move
			GameData.items["settle_letter"] = k_sl
			GameData.items["farewell_letter"] = k_fl
			GameData.affinity["farmer"] = k_aff_f
			GameData.affinity["foodie"] = k_aff_d
			print("SETTLER_OK=", kinds and no_alch and accepted and arrived
				and spawned and trio_near and trio_open and trio_aff
				and leave_open and persuaded and gone and fw_read and no_horn,
				" 분류=", kinds, " 특수잠금=", no_alch, " 수락=", accepted,
				" 도착=", arrived and spawned, " 삼자대화=", trio_near
				and trio_open and trio_aff, " 붙잡기=", leave_open and persuaded,
				" 말없이떠남=", gone and fw_read, " 유니콘뿔제거=", no_horn)
		269:
			# #126: 메인 스토리 9 「마을회관」 — 이장 부탁 -> 주민 초대 ->
			# 회관 건설 -> 개관식 -> 점진 해금(명부/창고 12명/프로젝트 15명/
			# 회의 20명) + 창고 루팅·쓰레기 수거·기부·프로젝트·회의 효과
			m.dialog.close()
			var k9_aff: Dictionary = GameData.affinity.duplicate()
			GameData.village_built.erase("hall")
			GameData.story9_phase = ""
			GameData.story8_phase = "done"
			m.story._story9_update(0.016)
			var s9_ask: bool = GameData.story9_phase == "ask" \
				and GameData.quest_npc_marks().get("chief", "") == "!"
			m.story._start_hall_ask_dialog()
			m.dialog.skip_seq()
			var s9_invite: bool = GameData.story9_phase == "invite" \
				and GameData.story9_objective_short() != "" \
				and m.village._next_village_build() != "hall"
			# 주민이 10명(플레이어 제외)을 넘어가면 건설 단계가 절로 열린다
			var s9_dummies: Array = []
			while m.village_residents() <= GameData.HALL_RESIDENTS:
				m.npcmgr._spawn_npc("forest_girl", Vector2i(74, 22))
				s9_dummies.append(m.npcs[m.npcs.size() - 1])
			m.story._story9_update(0.016)
			var s9_build: bool = GameData.story9_phase == "build" \
				and m.village._next_village_build() == "hall"
			GameData.wood += 120
			GameData.stone += 80
			m.village._build_village_building("hall")
			m.dialog.close()
			# 개관식 — 회관 접수대(room_action)에서 이장과 이야기해야 끝난다
			m.village.room_action("hall")
			var s9_rite: bool = m.dialog.visible and GameData.story9_phase == "build"
			m.dialog.skip_seq()
			var s9_done: bool = GameData.story9_phase == "done"
			m.dialog.close()
			# 점진 해금 — 지금 주민 11명: 명부는 열리고 창고(12명)부터는 잠김
			var s9_lock: bool = not GameData.hall_feature_open("store") \
				and not GameData.hall_feature_open("project") \
				and not GameData.hall_feature_open("meet") \
				and GameData.hall_next_feature_text() != ""
			while m.village_residents() < GameData.HALL_STORE_RES:
				m.npcmgr._spawn_npc("forest_girl", Vector2i(74, 22))
				s9_dummies.append(m.npcs[m.npcs.size() - 1])
			m.story._story9_update(0.016)
			var s9_store_open: bool = GameData.hall_feature_open("store") \
				and not GameData.hall_feature_open("project")
			while m.village_residents() < GameData.HALL_MEET_RES:
				m.npcmgr._spawn_npc("forest_girl", Vector2i(74, 22))
				s9_dummies.append(m.npcs[m.npcs.size() - 1])
			m.story._story9_update(0.016)
			var s9_meet_open: bool = GameData.hall_feature_open("project") \
				and GameData.hall_feature_open("meet")
			# 창고 — 하루 한 번 운 루팅 (허탕/획득), 쓰레기 수거 지원금
			GameData.hall_stock = {"forage_berry": 2}
			GameData.hall_loot_day = 0
			var s9_b0 := int(GameData.items["forage_berry"])
			var s9_miss: bool = GameData.hall_loot(0.99) == "miss"
			var s9_once: bool = GameData.hall_loot(0.0) == ""   # 오늘은 끝
			GameData.hall_loot_day = 0
			var s9_hit: bool = GameData.hall_loot(0.0) == "forage_berry" \
				and int(GameData.items["forage_berry"]) == s9_b0 + 1 \
				and int(GameData.hall_stock.get("forage_berry", 0)) == 1
			GameData.items["forage_trash"] = int(GameData.items["forage_trash"]) + 3
			var s9_m0: int = GameData.money
			var s9_t0 := int(GameData.items["forage_trash"])
			var s9_trash: bool = GameData.hall_dump_trash() == s9_t0 \
				and GameData.money == s9_m0 + GameData.HALL_TRASH_G * s9_t0 \
				and int(GameData.items["forage_trash"]) == 0
			# 아침 기부 — 주민이 물건을 놓고 간다 (200번 굴리면 사실상 확정)
			var s9_st0 := GameData.hall_stock_total()
			var s9_donate: bool = GameData.hall_donate_morning(200) > 0 \
				and GameData.hall_stock_total() > s9_st0
			# 공동 프로젝트 — 재료를 내면 완성 기록 + 온 주민 호감도 +3
			GameData.wood += 40
			GameData.stone += 20
			GameData.money += 2000
			var s9_aff0 := int(GameData.affinity["chief"])
			m.village._do_hall_project("lamps")
			var s9_proj: bool = GameData.hall_projects.has("lamps") \
				and int(GameData.affinity["chief"]) == s9_aff0 + 3
			# 마을 회의 — 간식 나눔 가결 효과 (온 주민 호감도 +4)
			GameData.money += 800
			var s9_aff1 := int(GameData.affinity["chief"])
			m.village._meet_apply("snack")
			var s9_meet: bool = int(GameData.affinity["chief"]) == s9_aff1 + 4
			# 새 일반 주민 7명 — 풀 10명·프로필·호감도·도트 8장씩
			var s9_pool: bool = GameData.SETTLER_POOL.size() == 10
			var s9_tex := true
			for sp: String in ["miner", "florist", "carpenter", "herbalist",
					"painter", "musician", "weaver"]:
				if m.tex.get("npc_%s_down_0" % sp) == null \
						or m.tex.get("npc_%s_portrait_normal" % sp) == null \
						or not GameData.NPCS.has(sp) \
						or not GameData.affinity.has(sp) \
						or GameData.settler_kind(sp) != "normal":
					s9_tex = false
			# 뒷정리 — 임시 주민·광장 장식·호감도 되돌리기
			for p9: Dictionary in GameData.HALL_PROJECTS:
				for t9: Array in p9.tiles:
					var tt9 := Vector2i(int(t9[0]), int(t9[1]))
					if str(m.objects.get(tt9, {}).get("kind", "")) == str(p9.kind):
						m.objnode._remove_object(tt9)
			for dmy9: Node2D in s9_dummies:
				m.npcs.erase(dmy9)
				dmy9.queue_free()
			m.story._story9_update(0.016)
			GameData.affinity = k9_aff
			m.hud._toast_queue.clear()
			print("STORY9_OK=", s9_ask and s9_invite and s9_build and s9_rite
				and s9_done and s9_lock and s9_store_open and s9_meet_open
				and s9_miss and s9_once and s9_hit and s9_trash and s9_donate
				and s9_proj and s9_meet and s9_pool and s9_tex,
				" 부탁=", s9_ask, " 초대=", s9_invite, " 해금=", s9_build,
				" 개관식=", s9_rite and s9_done, " 점진잠금=", s9_lock,
				" 창고12=", s9_store_open, " 회의20=", s9_meet_open,
				" 루팅=", s9_miss and s9_once and s9_hit, " 수거=", s9_trash,
				" 기부=", s9_donate, " 프로젝트=", s9_proj, " 회의효과=", s9_meet,
				" 새주민7=", s9_pool and s9_tex)
		275:
			# #127: 메인 스토리 10 「동굴과 탐험」 — 서하의 발견 -> 동굴 조사
			# (15층 + 새 표본 2종) -> 보고 완결 + 컬렉션 게이트/영구 보상
			m.dialog.close()
			GameData.story10_phase = ""
			GameData.story9_phase = "done"
			var s10_cmin: Dictionary = {}
			var s10_clife: Dictionary = {}
			for c10: Dictionary in GameData.COLLECTIONS:
				if str(c10.id) == "col_cave_mineral":
					s10_cmin = c10
				elif str(c10.id) == "col_cave_life":
					s10_clife = c10
			# 시작 전: 새 표본 잠김 + 동굴 컬렉션이 노트에 없다
			var s10_gate: bool = not GameData.story10_open() \
				and not GameData.collection_open(s10_cmin) \
				and not GameData.collection_open(s10_clife)
			m.story._story10_update(0.016)
			var s10_note: bool = GameData.story10_phase == "note" \
				and GameData.quest_npc_marks().get("librarian", "") == "!"
			m.story._start_cave_note_dialog()
			m.dialog.skip_seq()
			var s10_survey: bool = GameData.story10_phase == "survey" \
				and GameData.story10_open() and GameData.collection_open(s10_cmin) \
				and GameData.story10_objective_short() != "" \
				and not GameData.story10_survey_done()
			# 발광 버섯 — 조사가 시작되면 3층부터 돋아난다 (층마다 1~2개)
			var s10_keep_wt: bool = m.cave.worldtree
			m.cave.worldtree = false
			m.cave.floor_num = 3
			m.cave._gen_floor()
			var s10_shroom: bool = m.cave.shrooms.size() >= 1
			# 목표 달성: 15층 도달 + 표본 2종 발견 -> 서하에게 ? 표식
			GameData.mine_reach(GameData.STORY10_DEPTH)
			m.doing.gain_item("crystal", 1)
			m.doing.gain_item("glow_shroom", 1)
			var s10_cond: bool = GameData.story10_survey_done() \
				and GameData.quest_npc_marks().get("librarian", "") == "?"
			m.story._start_cave_report_dialog()
			m.dialog.skip_seq()
			var s10_done: bool = GameData.story10_phase == "done"
			m.dialog.close()
			# 컬렉션을 채우면 영구 보상 — 곡괭이 기력 -25% · 동굴 광석 +1 ·
			# 동굴 이동 속도 +10% (기획: 컬렉션 보상의 첫 강한 체감)
			m.doing.gain_item("ore", 1)
			m.doing.gain_item("gem", 1)
			m.doing.gain_item("star_shard", 1)
			m.doing.gain_item("cave_moss", 1)
			GameData.mob_kills["slime"] = maxi(1, int(GameData.mob_kills.get("slime", 0)))
			GameData.mob_kills["bat"] = maxi(1, int(GameData.mob_kills.get("bat", 0)))
			GameData.mob_kills["ghost"] = maxi(1, int(GameData.mob_kills.get("ghost", 0)))
			GameData._check_collections()
			var s10_cols: bool = "col_cave_mineral" in GameData.collections_done \
				and "col_cave_life" in GameData.collections_done
			var s10_perk: bool = absf(GameData.perk_pick_stamina_mult()
					- GameData.CAVE_COL_STAMINA) < 0.001 \
				and GameData.perk_cave_ore_bonus() == 1 \
				and absf(GameData.perk_cave_speed_mult()
					- GameData.CAVE_COL_SPEED) < 0.001
			# 표본 3종 — 아이템 표·아이콘이 다 갖춰졌는가
			var s10_items := true
			for cid: String in GameData.CAVE_FINDS:
				if m.tex.get(cid) == null or not GameData.ITEMS.has(cid):
					s10_items = false
			# 뒷정리
			m.cave.worldtree = s10_keep_wt
			m.cave.shrooms.clear()
			GameData.collection_pending.clear()
			m.hud._toast_queue.clear()
			print("STORY10_OK=", s10_gate and s10_note and s10_survey and s10_shroom
				and s10_cond and s10_done and s10_cols and s10_perk and s10_items,
				" 게이트=", s10_gate, " 발견=", s10_note, " 조사=", s10_survey,
				" 버섯=", s10_shroom, " 목표=", s10_cond, " 완결=", s10_done,
				" 컬렉션=", s10_cols, " 영구보상=", s10_perk, " 표본3종=", s10_items)
		276:
			# #128: 메인 스토리 11 「할머니의 모자」 — 회의+노트 20% 조건 ->
			# 이장이 직접 찾아옴 -> 단서 3인 -> 동굴 50층 확정 드랍 ->
			# 도서관 「할머니의 기록」 1장 (점진 공개)
			m.dialog.close()
			GameData.story10_phase = "done"
			GameData.story11_phase = ""
			GameData.story11_clues = []
			GameData.items["relic_hat"] = 0
			var k11_aff: Dictionary = GameData.affinity.duplicate()
			var k11_crops: Dictionary = GameData.crops_harvested.duplicate()
			# 노트 20%를 확실히 넘겨 둔다 (핵심 주민 호감도 + 수확 기록)
			for aid: String in GameData.NPCS:
				if GameData.settler_kind(aid) == "core":
					GameData.affinity[aid] = 100
			for cid2: String in GameData.CROP_IDS:
				GameData.crops_harvested[cid2] = \
					maxi(1, int(GameData.crops_harvested.get(cid2, 0)))
			GameData.minerals_found["ore"] = true
			GameData.minerals_found["gem"] = true
			# ① 마을 회의를 아직 안 했으면 이야기가 시작되지 않는다
			var k11_meet: int = GameData.hall_meet_day
			GameData.hall_meet_day = 0
			m.story._story11_update(0.016)
			var s11_wait: bool = GameData.story11_phase == "" \
				and not GameData.story11_ready()
			# ② 조건 완비 -> 이장이 걸어오는 연출 -> 대화 -> 단서 수집
			GameData.hall_meet_day = maxi(1, k11_meet)
			var s11_ready: bool = GameData.story11_ready()
			m.story._story11_update(0.016)
			var s11_visit: bool = GameData.story11_phase == "visit" \
				and m.story_cutscene
			m.story._start_hat_visit_dialog()   # 걷기는 생략 — 바로 대화
			m.dialog.skip_seq()
			var s11_clue0: bool = GameData.story11_phase == "clue" \
				and not m.story_cutscene \
				and GameData.quest_npc_marks().get("blacksmith", "") == "!"
			# ③ 단서 세 사람 — 다 들으면 「깊은 굴」 단계
			m.story._start_hat_clue_dialog("blacksmith")
			m.dialog.skip_seq()
			m.story._start_hat_clue_dialog("librarian")
			m.dialog.skip_seq()
			var s11_mid: bool = GameData.story11_phase == "clue" \
				and GameData.story11_clues.size() == 2
			m.story._start_hat_clue_dialog("forest_mom")
			m.dialog.skip_seq()
			var s11_deep: bool = GameData.story11_phase == "deep" \
				and GameData.story11_objective_short() != ""
			# ④ 50층 광석 채굴 — 이야기 중에는 굴림이 확정으로 넘어간다
			#    (cave_ui가 story11_phase=="deep"이면 roll 0.0을 넘긴다)
			var roll11 := 0.0 if GameData.story11_phase == "deep" else -1.0
			var s11_drop: bool = GameData.try_relic(0, roll11) \
				and int(GameData.items["relic_hat"]) == 1
			m.story._story11_update(0.016)
			var s11_rec: bool = GameData.story11_phase == "record"
			# ⑤ 도서관 서가에 「할머니의 기록」이 생겼다 — 첫 장만 열린다
			m.village._open_library_dialog()
			var s11_lib: bool = m.dialog.visible
			m.dialog.close()
			m.story.open_grandma_records()
			var s11_read: bool = m.dialog.visible and GameData.grandma_read >= 1
			m.dialog.close()
			m.story._end_grandma_record()
			var s11_done: bool = GameData.story11_phase == "done" \
				and GameData.completed_quests().has("메인 스토리 11 — 할머니의 모자")
			# 뒷정리
			GameData.affinity = k11_aff
			GameData.crops_harvested = k11_crops
			GameData.relic_pending = ""
			m.hud._toast_queue.clear()
			print("STORY11_OK=", s11_wait and s11_ready and s11_visit and s11_clue0
				and s11_mid and s11_deep and s11_drop and s11_rec and s11_lib
				and s11_read and s11_done,
				" 회의게이트=", s11_wait, " 조건=", s11_ready, " 방문=", s11_visit,
				" 단서시작=", s11_clue0, " 단서2=", s11_mid, " 깊은굴=", s11_deep,
				" 모자확정=", s11_drop, " 기록단계=", s11_rec,
				" 서가=", s11_lib, " 첫장=", s11_read, " 완결=", s11_done)
		277:
			# #129: 메인 스토리 12 「숲의 연금술사」 — 노트 40%+호감 3단계
			# 5명 -> 노트의 낯선 기록 -> 서하 -> 주민 소문 -> 숨은 길·오두막 ->
			# 재료 시험(동굴·채집·낚시) -> 시연 -> 연금술 해금
			m.dialog.close()
			GameData.story11_phase = "done"
			GameData.story12_phase = ""
			GameData.story12_heard = []
			var k12_aff: Dictionary = GameData.affinity.duplicate()
			var k12_crops: Dictionary = GameData.crops_harvested.duplicate()
			# ① 조건 게이트 — 호감도 3단계 주민 5명이 안 되면 시작되지 않는다
			for a12: String in GameData.affinity:
				GameData.affinity[a12] = 0
			m.story._story12_update(0.016)
			var s12_wait: bool = GameData.story12_phase == "" \
				and not GameData.story12_ready()
			# 노트 40%와 친구 5명을 채운다 (핵심 주민 호감도 + 수확 기록)
			for a13: String in GameData.NPCS:
				if GameData.settler_kind(a13) == "core":
					GameData.affinity[a13] = 100
			for c12: String in GameData.CROP_IDS:
				GameData.crops_harvested[c12] = \
					maxi(1, int(GameData.crops_harvested.get(c12, 0)))
			GameData.minerals_found["ore"] = true
			GameData.minerals_found["gem"] = true
			var s12_ready: bool = GameData.story12_ready() \
				and GameData.story12_friends() >= GameData.STORY12_FRIENDS
			m.story._story12_update(0.016)
			var s12_note: bool = GameData.story12_phase == "note" \
				and not GameData.alchemy_open()
			# ② 노트를 펼치면 낯선 기록이 읽힌다 -> 서하 ❗
			m.story.story12_note_read()
			var s12_ask: bool = GameData.story12_phase == "ask" \
				and GameData.quest_npc_marks().get("librarian", "") == "!"
			m.story._start_alch_ask_dialog()
			m.dialog.skip_seq()
			var s12_gossip: bool = GameData.story12_phase == "gossip"
			# ③ 주민 소문 셋(같은 사람 중복 없음) -> 숨은 길 + 오두막
			m.story.story12_hear("chief")
			m.dialog.skip_seq()
			m.story.story12_hear("chief")
			m.dialog.close()
			var s12_once: bool = GameData.story12_heard.size() == 1
			m.story.story12_hear("merchant")
			m.dialog.skip_seq()
			m.story.story12_hear("blacksmith")
			m.dialog.skip_seq()
			var s12_path: bool = GameData.story12_phase == "path" \
				and str(m.objects.get(m.ALCH_HOUSE_ANCHOR,
					{}).get("kind", "")) == "house"
			m.npcmgr._sync_village_npcs()
			var s12_npc := false
			for n12 in m.npcs:
				if n12.id == "alchemist":
					s12_npc = true
			# 묘연은 이제 이사 후보에 오르지 않는다 — 숲에 산다
			var s12_nocand: bool = "alchemist" not in GameData.settler_candidates()
			# ④ 오두막 첫 만남 -> 재료 시험 (모자라면 시연은 없다)
			m.story._alch_house_door()
			m.dialog.skip_seq()
			var s12_gather: bool = GameData.story12_phase == "gather"
			GameData.items["crystal"] = 0
			m.story._alch_house_door()
			var s12_block: bool = m.dialog.visible \
				and GameData.story12_phase == "gather" \
				and not GameData.alchemy_open()
			m.dialog.close()
			# ⑤ 동굴·채집·낚시 재료를 다 모으면 시연 -> 연금술 해금 (완결)
			GameData.items["crystal"] = int(GameData.STORY12_MATS["crystal"])
			GameData.items["forage_herb"] = maxi(int(GameData.items["forage_herb"]),
				int(GameData.STORY12_MATS["forage_herb"]))
			GameData.items["fish_crucian"] = maxi(int(GameData.items["fish_crucian"]),
				int(GameData.STORY12_MATS["fish_crucian"]))
			var s12_mark: bool = GameData.quest_npc_marks().get("alchemist", "") == "?"
			m.story._alch_house_door()
			m.dialog.skip_seq()
			var s12_done: bool = GameData.story12_phase == "done" \
				and GameData.alchemy_open() \
				and int(GameData.items["crystal"]) == 0 \
				and GameData.completed_quests().has("메인 스토리 12 — 숲의 연금술사")
			# 뒷정리
			GameData.affinity = k12_aff
			GameData.crops_harvested = k12_crops
			m.hud._toast_queue.clear()
			print("STORY12_OK=", s12_wait and s12_ready and s12_note and s12_ask
				and s12_gossip and s12_once and s12_path and s12_npc and s12_nocand
				and s12_gather and s12_block and s12_mark and s12_done,
				" 조건게이트=", s12_wait, " 조건=", s12_ready, " 낯선기록=", s12_note,
				" 사서=", s12_ask and s12_gossip, " 소문중복=", s12_once,
				" 숨은길=", s12_path, " 묘연숲=", s12_npc and s12_nocand,
				" 첫만남=", s12_gather, " 재료차단=", s12_block,
				" 재료표식=", s12_mark, " 해금완결=", s12_done)
		278:
			# #130: 메인 스토리 13 「할머니의 팔찌」 — 자유 생활 보장(임시 조건)
			# -> 용식의 바다 소문 -> 주민 이야기 3 -> 두 사람의 바위 ->
			# 특별한 입질(낡은 상자) -> 연금술사 개봉 -> 팔찌 + 기록 2장
			m.dialog.close()
			GameData.story12_phase = "done"
			GameData.story13_phase = ""
			GameData.story13_heard = []
			GameData.items["relic_bracelet"] = 0
			GameData.items["old_box"] = 0
			GameData.sea_open = true
			# ① 스토리 12 직후에는 시작되지 않는다 — 자유 생활 며칠 뒤에야
			GameData.story12_done_day = GameData.day
			m.story._story13_update(0.016)
			var s13_wait: bool = GameData.story13_phase == "" \
				and not GameData.story13_ready()
			GameData.story12_done_day = GameData.day - GameData.STORY13_REST_DAYS
			m.story._story13_update(0.016)
			var s13_rumor: bool = GameData.story13_phase == "rumor" \
				and GameData.quest_npc_marks().get("fisher", "") == "!"
			m.story._start_sea_rumor_dialog()
			m.dialog.skip_seq()
			var s13_clue: bool = GameData.story13_phase == "clue"
			# ② 주민 이야기 셋 — 용식·묘연은 안 세고, 같은 사람도 안 센다
			m.story.story13_hear("fisher")
			m.dialog.close()
			var s13_nofish: bool = GameData.story13_heard.is_empty()
			m.story.story13_hear("chief")
			m.dialog.skip_seq()
			m.story.story13_hear("chief")
			m.dialog.close()
			var s13_once: bool = GameData.story13_heard.size() == 1
			m.story.story13_hear("merchant")
			m.dialog.skip_seq()
			m.story.story13_hear("librarian")
			m.dialog.skip_seq()
			var s13_spot: bool = GameData.story13_phase == "spot" \
				and str(m.objects.get(m.BRACELET_ROCK,
					{}).get("kind", "")) == "sign" \
				and GameData.story13_objective_short() != ""
			# ③ 특별한 입질 — 바위에서 멀면 평범한 낚시, 곁이면 낡은 상자
			var keep13_pos: Vector2 = m.player.position
			m.player.position = Vector2(60 * m.TILE, 30 * m.TILE)
			var s13_far: bool = not m.story.story13_special_bite()
			m.player.position = Vector2(m.BRACELET_ROCK.x * m.TILE + 16,
				(m.BRACELET_ROCK.y - 1) * m.TILE + 16)
			var s13_bite: bool = m.story.story13_special_bite() \
				and GameData.story13_phase == "box" \
				and int(GameData.items["old_box"]) == 1
			m.player.position = keep13_pos
			# ④ 연금술사 — 상담 -> 재료 준비 -> 개봉 (재료가 모자라면 안 열린다)
			m.story._alch_house_door()
			m.dialog.skip_seq()
			var s13_ask: bool = GameData.story13_phase == "open"
			GameData.items["glow_shroom"] = 0
			m.story._alch_house_door()
			var s13_block: bool = m.dialog.visible \
				and GameData.story13_phase == "open" \
				and int(GameData.items["relic_bracelet"]) == 0
			m.dialog.close()
			GameData.items["glow_shroom"] = int(GameData.STORY13_MATS["glow_shroom"])
			GameData.items["forage_glass"] = maxi(
				int(GameData.items["forage_glass"]),
				int(GameData.STORY13_MATS["forage_glass"]))
			var s13_mark: bool = GameData.quest_npc_marks().get("alchemist", "") == "?"
			m.story._alch_house_door()
			m.dialog.skip_seq()
			var s13_relic: bool = GameData.story13_phase == "record" \
				and int(GameData.items["relic_bracelet"]) == 1 \
				and int(GameData.items["old_box"]) == 0 \
				and GameData.relics_owned() >= 2
			# ⑤ 도서관 — 팔찌 장(2장)이 함께 열리고, 읽으면 완결
			m.story.open_grandma_records()
			var s13_lib: bool = m.dialog.visible
			m.dialog.close()
			m.story._end_grandma_record()
			var s13_done: bool = GameData.story13_phase == "done" \
				and GameData.completed_quests().has("메인 스토리 13 — 할머니의 팔찌")
			GameData.relic_pending = ""
			m.hud._toast_queue.clear()
			print("STORY13_OK=", s13_wait and s13_rumor and s13_clue and s13_nofish
				and s13_once and s13_spot and s13_far and s13_bite and s13_ask
				and s13_block and s13_mark and s13_relic and s13_lib and s13_done,
				" 자유생활=", s13_wait, " 소문=", s13_rumor and s13_clue,
				" 낚시꾼제외=", s13_nofish, " 중복없음=", s13_once,
				" 바위=", s13_spot, " 원거리차단=", s13_far, " 특별입질=", s13_bite,
				" 상담=", s13_ask, " 재료차단=", s13_block, " 재료표식=", s13_mark,
				" 팔찌=", s13_relic, " 기록완결=", s13_lib and s13_done)
		279:
			# #131: 메인 스토리 14 「마을의 첫 축제」 — 자유 생활 -> 회관 회의
			# -> 준비(여섯 중 셋 선택) -> 이튿날 광장 축제(전용 대사·투호)
			# -> 이장의 마무리 -> 회관 「축제·행사 일정」 해금
			m.dialog.close()
			GameData.story13_phase = "done"
			GameData.story14_phase = ""
			GameData.story14_tasks = []
			GameData.story14_greet = []
			if not GameData.village_built.has("hall"):
				GameData.village_built.append("hall")
			var k14_aff: Dictionary = GameData.affinity.duplicate()
			var k14_wood: int = GameData.wood
			# ① 스토리 13 직후에는 시작되지 않는다 (자유 생활 보장)
			GameData.story13_done_day = GameData.day
			m.story._story14_update(0.016)
			var s14_wait: bool = GameData.story14_phase == "" \
				and not GameData.story14_ready() \
				and not GameData.hall_calendar_open()
			GameData.story13_done_day = GameData.day - GameData.STORY14_REST_DAYS
			m.story._story14_update(0.016)
			var s14_meet: bool = GameData.story14_phase == "meet" \
				and GameData.quest_npc_marks().get("chief", "") == "!"
			m.story._start_fest_meet_dialog()
			m.dialog.skip_seq()
			var s14_prep: bool = GameData.story14_phase == "prep" \
				and GameData.story14_objective_short() != ""
			# ② 준비 — 재료가 모자라면 못 내고, 셋만 내면 끝난다
			GameData.wood = 0
			var s14_short: bool = not GameData.fest_deliver("wood")
			GameData.wood = 200
			var s14_w1: bool = GameData.fest_deliver("wood") \
				and GameData.wood == 200 - 30
			var s14_dup: bool = not GameData.fest_deliver("wood")
			GameData.items["egg"] = int(GameData.items["egg"]) + 6
			GameData.items["flower_pot"] = int(GameData.items.get("flower_pot", 0)) + 2
			var s14_w2: bool = GameData.fest_deliver("ranch") \
				and GameData.fest_deliver("flower")
			var s14_ready: bool = GameData.fest_prep_done() \
				and GameData.quest_npc_marks().get("chief", "") == "?"
			# ③ 주민들도 저마다 준비 중이다 (한 사람당 한 번)
			var s14_greet: bool = m.story.story14_prep_greet("blacksmith")
			m.dialog.close()
			var s14_greet2: bool = not m.story.story14_prep_greet("blacksmith")
			# ④ 이장에게 알리면 이튿날 축제 — 그날이 와야 열린다
			m.story._start_fest_ready_dialog()
			m.dialog.skip_seq()
			var s14_fest: bool = GameData.story14_phase == "fest" \
				and GameData.story14_fest_day == GameData.day + 1 \
				and not m.story.story14_fest_greet("chief")
			GameData.day += 1
			var s14_open: bool = m.story.story14_fest_greet("merchant")
			m.dialog.close()
			# ⑤ 투호 미니게임 — 상금 + 첫 참가 때 온 주민 호감도
			var money14: int = GameData.money
			var aff14: int = int(GameData.affinity["chief"])
			m.story._fest_toss()
			var s14_toss: bool = GameData.story14_toss \
				and GameData.money >= money14 \
				and int(GameData.affinity["chief"]) == aff14 + 2
			m.dialog.close()
			# ⑥ 마무리 — 캘린더 해금
			m.story._start_fest_end_dialog()
			m.dialog.skip_seq()
			var s14_done: bool = GameData.story14_phase == "done" \
				and GameData.hall_calendar_open() \
				and GameData.story14_done_day == GameData.day \
				and GameData.completed_quests().has("메인 스토리 14 — 마을의 첫 축제")
			GameData.day -= 1
			GameData.wood = k14_wood
			GameData.affinity = k14_aff
			GameData.money = money14
			m.hud._toast_queue.clear()
			print("STORY14_OK=", s14_wait and s14_meet and s14_prep and s14_short
				and s14_w1 and s14_dup and s14_w2 and s14_ready and s14_greet
				and s14_greet2 and s14_fest and s14_open and s14_toss and s14_done,
				" 자유생활=", s14_wait, " 회의=", s14_meet, " 준비시작=", s14_prep,
				" 재료부족차단=", s14_short, " 내놓기=", s14_w1, " 중복차단=", s14_dup,
				" 셋완료=", s14_w2 and s14_ready, " 주민준비대사=", s14_greet
				and s14_greet2, " 이튿날=", s14_fest and s14_open,
				" 투호=", s14_toss, " 완결·캘린더=", s14_done)
		280:
			# #132: 메인 스토리 15 「마른 온천」 — 이장 이야기 -> 도서관 기록
			# -> 무쇠의 착암 쐐기 -> 동굴 20층+ 수맥(전투·채광) -> 묘연의
			# 물 확인 -> 온천 부활(하루 한 번 입욕) + 주민 온천 나들이
			m.dialog.close()
			GameData.story14_phase = "done"
			GameData.story15_phase = ""
			GameData.onsen_open = false
			GameData.items["rock_wedge"] = 0
			GameData.items["spring_water"] = 0
			m.objnode._remove_object(m.ONSEN_POS)
			# ① 스토리 14 직후에는 시작되지 않는다
			GameData.story14_done_day = GameData.day
			m.story._story15_update(0.016)
			var s15_wait: bool = GameData.story15_phase == "" \
				and not GameData.story15_ready()
			GameData.story14_done_day = GameData.day - GameData.STORY15_REST_DAYS
			m.story._story15_update(0.016)
			var s15_tale: bool = GameData.story15_phase == "tale" \
				and GameData.quest_npc_marks().get("chief", "") == "!"
			m.story._start_onsen_tale_dialog()
			m.dialog.skip_seq()
			m.story._start_onsen_book_dialog()
			m.dialog.skip_seq()
			var s15_tool: bool = GameData.story15_phase == "tool"
			# ② 착암 쐐기 — 재료가 모자라면 안 벼려 준다
			var k15_ore: int = int(GameData.items["ore"])
			var k15_shard: int = int(GameData.items["star_shard"])
			GameData.items["ore"] = 0
			m.story._start_onsen_tool_dialog()
			m.dialog.skip_seq()
			var s15_short: bool = GameData.story15_phase == "tool" \
				and int(GameData.items["rock_wedge"]) == 0
			GameData.items["ore"] = GameData.STORY15_TOOL_ORE
			GameData.items["star_shard"] = GameData.STORY15_TOOL_SHARD
			m.story._start_onsen_tool_dialog()
			m.dialog.skip_seq()
			var s15_wedge: bool = GameData.story15_phase == "dig" \
				and int(GameData.items["rock_wedge"]) == 1 \
				and int(GameData.items["ore"]) == 0
			# ③ 수맥 — 얕은 층은 세지 않는다. 깊은 층에서 다 치우면 물이 솟는다
			m.story.story15_dig_progress("mob", 5)
			var s15_shallow: bool = GameData.story15_mobs == 0
			for i in GameData.STORY15_MOBS:
				m.story.story15_dig_progress("mob", GameData.STORY15_DEPTH)
			for i in GameData.STORY15_ORE - 1:
				m.story.story15_dig_progress("ore", GameData.STORY15_DEPTH)
			var s15_mid: bool = GameData.story15_phase == "dig" \
				and not GameData.story15_dig_done()
			m.story.story15_dig_progress("ore", GameData.STORY15_DEPTH + 3)
			var s15_burst: bool = GameData.story15_phase == "water" \
				and int(GameData.items["spring_water"]) == 1 \
				and int(GameData.items["rock_wedge"]) == 0
			# ④ 묘연의 확인 -> 온천 부활
			m.story._start_onsen_water_dialog()
			m.dialog.skip_seq()
			var s15_done: bool = GameData.story15_phase == "done" \
				and GameData.onsen_open \
				and str(m.objects.get(m.ONSEN_POS, {}).get("kind", "")) == "onsen" \
				and GameData.completed_quests().has("메인 스토리 15 — 마른 온천")
			# ⑤ 입욕 — 하루 한 번, 체력이 가득 찬다
			GameData.onsen_day = 0
			GameData.energy = 20.0
			var min15: float = GameData.minutes
			var s15_bath: bool = GameData.onsen_bathe() \
				and GameData.energy >= GameData.ENERGY_MAX \
				and GameData.minutes > min15
			var s15_once: bool = not GameData.onsen_bathe()
			# ⑥ 저녁이면 주민이 온천에 몸을 담그러 온다
			var keep_min15: float = GameData.minutes
			GameData.minutes = 18.0 * 60.0
			var s15_goer: bool = m.npcmgr.npc_place_now("blacksmith") == "onsen" \
				and m.npcmgr.npc_place_tile("blacksmith", "onsen").x > 0
			GameData.minutes = 12.0 * 60.0
			var s15_day: bool = m.npcmgr.npc_place_now("blacksmith") != "onsen"
			GameData.minutes = keep_min15
			GameData.items["ore"] = k15_ore
			GameData.items["star_shard"] = k15_shard
			m.hud._toast_queue.clear()
			print("STORY15_OK=", s15_wait and s15_tale and s15_tool and s15_short
				and s15_wedge and s15_shallow and s15_mid and s15_burst
				and s15_done and s15_bath and s15_once and s15_goer and s15_day,
				" 자유생활=", s15_wait, " 이야기=", s15_tale, " 기록=", s15_tool,
				" 재료부족=", s15_short, " 쐐기=", s15_wedge,
				" 얕은층제외=", s15_shallow, " 진행중=", s15_mid,
				" 수맥돌파=", s15_burst, " 온천부활=", s15_done,
				" 입욕=", s15_bath and s15_once, " 주민나들이=", s15_goer and s15_day)
		281:
			# #133: 메인 스토리 16 「할머니의 반지」 — 도서관 혼인 기록 ->
			# 주민 단서 -> 옛 농지 정리·밭 갈기(농사·벌목·채집) -> 흙 속의
			# 상자에서 세 번째 유품 -> 도서관 3장
			m.dialog.close()
			GameData.story15_phase = "done"
			GameData.story16_phase = ""
			GameData.story16_heard = []
			GameData.items["relic_ring"] = 0
			m.story._ring_found = false
			var k16_crops: Dictionary = GameData.crops_harvested.duplicate()
			var k16_fish: Dictionary = GameData.fish_caught.duplicate()
			var k16_aff: Dictionary = GameData.affinity.duplicate()
			for a16: String in GameData.NPCS:
				if GameData.settler_kind(a16) == "core":
					GameData.affinity[a16] = 100
			for c16: String in GameData.CROP_IDS:
				GameData.crops_harvested[c16] = \
					maxi(1, int(GameData.crops_harvested.get(c16, 0)))
			for f16: String in GameData.FISH_IDS:
				GameData.fish_caught[f16] = \
					maxi(1, int(GameData.fish_caught.get(f16, 0)))
			GameData.minerals_found["ore"] = true
			GameData.minerals_found["gem"] = true
			# ① 스토리 15 직후에는 시작되지 않는다
			GameData.story15_done_day = GameData.day
			m.story._story16_update(0.016)
			var s16_wait: bool = GameData.story16_phase == ""
			GameData.story15_done_day = GameData.day - GameData.STORY16_REST_DAYS
			m.story._story16_update(0.016)
			var s16_rec: bool = GameData.story16_phase == "record" \
				and GameData.quest_npc_marks().get("librarian", "") == "!"
			m.story._start_ring_record_dialog()
			m.dialog.skip_seq()
			var s16_clue: bool = GameData.story16_phase == "clue"
			# ② 주민 단서 셋 -> 옛 농지가 우거진 채 드러난다
			m.story.story16_hear("chief")
			m.dialog.skip_seq()
			m.story.story16_hear("chief")
			m.dialog.close()
			var s16_once: bool = GameData.story16_heard.size() == 1
			m.story.story16_hear("merchant")
			m.dialog.skip_seq()
			m.story.story16_hear("blacksmith")
			m.dialog.skip_seq()
			var farm_objs := 0
			for fy in range(m.OLD_FARM.position.y, m.OLD_FARM.end.y):
				for fx in range(m.OLD_FARM.position.x, m.OLD_FARM.end.x):
					if m.objects.has(Vector2i(fx, fy)):
						farm_objs += 1
			var s16_field: bool = GameData.story16_phase == "clear" and farm_objs > 0
			# ③ 밭 밖에서 한 일은 세지 않는다
			m.story.story16_field_work("clear", Vector2i(60, 60))
			var s16_out: bool = GameData.story16_clear == 0
			# 정리와 밭 갈기 — 둘 다 채워야 상자가 나온다
			var ft16: Vector2i = m.OLD_FARM.position + Vector2i(1, 1)
			for i in GameData.STORY16_CLEAR:
				m.story.story16_field_work("clear", ft16)
			for i in GameData.STORY16_TILL - 1:
				m.story.story16_field_work("till", ft16)
			var s16_mid: bool = not GameData.story16_field_done() \
				and not m.story.story16_dig_box(ft16)
			m.story.story16_field_work("till", ft16)
			var s16_ready: bool = GameData.story16_field_done()
			# ④ 한 번 더 갈면 흙 속의 상자 -> 반지
			var s16_box: bool = m.story.story16_dig_box(ft16) \
				and GameData.story16_phase == "tale" \
				and int(GameData.items["relic_ring"]) == 1 \
				and GameData.relics_owned() >= 1
			m.dialog.close()
			# ⑤ 도서관 3장 -> 완결
			m.story.open_grandma_records()
			var s16_lib: bool = m.dialog.visible and GameData.grandma_read >= 1
			m.dialog.close()
			m.story._end_grandma_record()
			var s16_done: bool = GameData.story16_phase == "done" \
				and GameData.completed_quests().has("메인 스토리 16 — 할머니의 반지")
			GameData.crops_harvested = k16_crops
			GameData.fish_caught = k16_fish   # 뒤 스텝(상점 진열)을 오염시키지 않게
			GameData.affinity = k16_aff
			GameData.relic_pending = ""
			m.hud._toast_queue.clear()
			print("STORY16_OK=", s16_wait and s16_rec and s16_clue and s16_once
				and s16_field and s16_out and s16_mid and s16_ready and s16_box
				and s16_lib and s16_done,
				" 자유생활=", s16_wait, " 혼인기록=", s16_rec, " 단서=", s16_clue,
				" 중복없음=", s16_once, " 옛농지=", s16_field,
				" 구역밖제외=", s16_out, " 진행중=", s16_mid, " 정리완료=", s16_ready,
				" 상자·반지=", s16_box, " 기록·완결=", s16_lib and s16_done)
		282:
			# #134: 메인 스토리 17 「할머니의 목걸이」 — 보라의 천 조각 ->
			# 주민 단서 -> 옛 헛간 정리 + 동물 돌보기 -> 사료통 아래 목걸이
			m.dialog.close()
			GameData.story16_phase = "done"
			GameData.story17_phase = ""
			GameData.story17_heard = []
			GameData.items["relic_necklace"] = 0
			m.objnode._remove_object(m.OLD_BARN)
			# ① 스토리 16 직후에는 시작되지 않는다
			GameData.story16_done_day = GameData.day
			m.story._story17_update(0.016)
			var s17_wait: bool = GameData.story17_phase == ""
			GameData.story16_done_day = GameData.day - GameData.STORY17_REST_DAYS
			m.story._story17_update(0.016)
			var s17_cloth: bool = GameData.story17_phase == "cloth" \
				and GameData.quest_npc_marks().get("rancher", "") == "!"
			m.story._start_barn_cloth_dialog()
			m.dialog.skip_seq()
			var s17_clue: bool = GameData.story17_phase == "clue"
			# ② 주민 단서 셋 -> 옛 헛간이 드러난다
			m.story.story17_hear("chief")
			m.dialog.skip_seq()
			m.story.story17_hear("merchant")
			m.dialog.skip_seq()
			m.story.story17_hear("blacksmith")
			m.dialog.skip_seq()
			var s17_barn: bool = GameData.story17_phase == "barn" \
				and str(m.objects.get(m.OLD_BARN, {}).get("kind", "")) == "old_barn"
			# ③ 헛간 둘레 정리 + 동물 돌보기 — 둘 다 채워야 사료통이 열린다
			m.story.story17_barn_work("clear", Vector2i(60, 60))
			var s17_out: bool = GameData.story17_clear == 0
			var bt17: Vector2i = m.OLD_BARN + Vector2i(2, 2)
			for i in GameData.STORY17_CLEAR:
				m.story.story17_barn_work("clear", bt17)
			m.story.old_barn_examine()
			var s17_block: bool = m.dialog.visible \
				and GameData.story17_phase == "barn" \
				and int(GameData.items["relic_necklace"]) == 0
			m.dialog.close()
			for i in GameData.STORY17_CARE:
				m.story.story17_barn_work("care")
			var s17_ready: bool = GameData.story17_barn_done()
			# ④ 사료통 아래에서 목걸이
			m.story.old_barn_examine()
			var s17_find: bool = GameData.story17_phase == "tale" \
				and int(GameData.items["relic_necklace"]) == 1
			m.dialog.close()
			# ⑤ 도서관 4장 -> 완결
			m.story.open_grandma_records()
			var s17_lib: bool = m.dialog.visible
			m.dialog.close()
			m.story._end_grandma_record()
			var s17_done: bool = GameData.story17_phase == "done" \
				and GameData.story17_done_day == GameData.day \
				and GameData.completed_quests().has("메인 스토리 17 — 할머니의 목걸이")
			# ⑥ 유품 순서 — 모자·팔찌·반지·목걸이·시계
			var s17_order: bool = str(GameData.RELICS[2].id) == "relic_ring" \
				and str(GameData.RELICS[3].id) == "relic_necklace" \
				and str(GameData.RELICS[4].id) == "relic_watch" \
				and GameData.GRANDMA_RECORDS.size() == GameData.RELICS.size()
			GameData.relic_pending = ""
			m.hud._toast_queue.clear()
			print("STORY17_OK=", s17_wait and s17_cloth and s17_clue and s17_barn
				and s17_out and s17_block and s17_ready and s17_find and s17_lib
				and s17_done and s17_order,
				" 자유생활=", s17_wait, " 천조각=", s17_cloth, " 단서=", s17_clue,
				" 옛헛간=", s17_barn, " 구역밖제외=", s17_out,
				" 미완차단=", s17_block, " 정리·돌보기=", s17_ready,
				" 목걸이=", s17_find, " 기록·완결=", s17_lib and s17_done,
				" 유품순서=", s17_order)
		283:
			# #135: 메인 스토리 18 「할머니의 시계」 — 도서관 메모 -> 주민 단서
			# -> 옛 전망대의 흔적 셋 -> 발판 밑 보관함 -> 마지막 기록·완결
			m.dialog.close()
			GameData.story17_phase = "done"
			GameData.story18_phase = ""
			GameData.story18_heard = []
			GameData.story18_traces = []
			GameData.items["relic_watch"] = 0
			for hp: Vector2i in [m.HILL_POS, m.HILL_TRACE_TILES["bench"],
					m.HILL_TRACE_TILES["stone"], m.HILL_TRACE_TILES["tree"]]:
				m.objnode._remove_object(hp)
			# 노트를 후반부(80%)까지 채운다 — 스텝이 끝나면 되돌린다
			var k18_crops: Dictionary = GameData.crops_harvested.duplicate()
			var k18_fish: Dictionary = GameData.fish_caught.duplicate()
			var k18_mobs: Dictionary = GameData.mob_kills.duplicate()
			var k18_cook: Dictionary = GameData.recipes_cooked.duplicate()
			var k18_aff: Dictionary = GameData.affinity.duplicate()
			for c18: String in GameData.CROP_IDS:
				GameData.crops_harvested[c18] = maxi(1, int(GameData.crops_harvested.get(c18, 0)))
			for f18: String in GameData.FISH_IDS:
				GameData.fish_caught[f18] = maxi(1, int(GameData.fish_caught.get(f18, 0)))
			for mb18: String in GameData.MOBS:
				GameData.mob_kills[mb18] = maxi(1, int(GameData.mob_kills.get(mb18, 0)))
			for rc18: String in GameData.RECIPE_IDS:
				GameData.recipes_cooked[rc18] = maxi(1, int(GameData.recipes_cooked.get(rc18, 0)))
			for a18: String in GameData.NPCS:
				GameData.affinity[a18] = 100
			GameData.minerals_found["ore"] = true
			GameData.minerals_found["gem"] = true
			var s18_note: bool = GameData.note_progress().ratio >= GameData.STORY18_NOTE
			# ① 스토리 17 직후에는 시작되지 않는다 (자유 생활)
			GameData.story17_done_day = GameData.day
			m.story._story18_update(0.016)
			var s18_wait: bool = GameData.story18_phase == ""
			GameData.story17_done_day = GameData.day - GameData.STORY18_REST_DAYS
			m.story._story18_update(0.016)
			var s18_memo: bool = GameData.story18_phase == "memo" \
				and GameData.quest_npc_marks().get("librarian", "") == "!"
			m.story._start_watch_memo_dialog()
			m.dialog.skip_seq()
			var s18_clue: bool = GameData.story18_phase == "clue"
			# ② 주민 단서 셋 (같은 사람은 한 번만) -> 옛 전망대가 드러난다
			m.story.story18_hear("chief")
			m.dialog.skip_seq()
			m.story.story18_hear("chief")
			m.dialog.close()
			var s18_once: bool = GameData.story18_heard.size() == 1
			m.story.story18_hear("blacksmith")
			m.dialog.skip_seq()
			m.story.story18_hear("librarian")
			m.dialog.skip_seq()
			var s18_hill: bool = GameData.story18_phase == "hill" \
				and str(m.objects.get(m.HILL_POS, {}).get("kind", "")) == "old_lookout" \
				and str(m.objects.get(m.HILL_TRACE_TILES["stone"], {}).get(
					"kind", "")) == "carved_stone"
			# ③ 흔적을 다 살피기 전에는 보관함이 열리지 않는다
			m.story.hill_lookout_examine()
			var s18_block: bool = m.dialog.visible \
				and GameData.story18_phase == "hill" \
				and int(GameData.items["relic_watch"]) == 0
			m.dialog.close()
			m.story.hill_trace("bench")
			m.story._end_hill_trace()
			m.story.hill_trace("bench")   # 같은 흔적은 두 번 세지 않는다
			m.dialog.close()
			var s18_tr_once: bool = GameData.story18_traces.size() == 1
			m.story.hill_trace("stone")
			m.story._end_hill_trace()
			m.story.hill_trace("tree")
			m.story._end_hill_trace()
			var s18_box: bool = GameData.story18_phase == "box"
			# ④ 발판 밑 보관함 -> 시계 (유품 다섯 완성)
			m.story.hill_lookout_examine()
			var s18_find: bool = GameData.story18_phase == "tale" \
				and int(GameData.items["relic_watch"]) == 1
			m.dialog.skip_seq()
			# ⑤ 도서관 5장 -> 서하와의 마지막 대화 -> 완결 (스토리 19 복선)
			m.story.open_grandma_records()
			var s18_lib: bool = m.dialog.visible
			m.dialog.close()
			m.story._end_grandma_record()
			var s18_last: bool = m.dialog.visible \
				and GameData.story18_phase == "tale"
			m.dialog.skip_seq()
			var s18_done: bool = GameData.story18_phase == "done" \
				and GameData.story18_done_day == GameData.day \
				and GameData.completed_quests().has("메인 스토리 18 — 할머니의 시계")
			var s18_rec5: bool = str(GameData.GRANDMA_RECORDS[4]).contains(
				"먼저 가서 기다릴 테니")
			GameData.crops_harvested = k18_crops
			GameData.fish_caught = k18_fish
			GameData.mob_kills = k18_mobs
			GameData.recipes_cooked = k18_cook
			GameData.affinity = k18_aff
			GameData.relic_pending = ""
			m.hud._toast_queue.clear()
			print("STORY18_OK=", s18_note and s18_wait and s18_memo and s18_clue
				and s18_once and s18_hill and s18_block and s18_tr_once
				and s18_box and s18_find and s18_lib and s18_last and s18_done
				and s18_rec5,
				" 노트80=", s18_note, " 자유생활=", s18_wait, " 메모=", s18_memo,
				" 단서=", s18_clue, " 중복없음=", s18_once, " 전망대=", s18_hill,
				" 미조사차단=", s18_block, " 흔적중복=", s18_tr_once,
				" 흔적완료=", s18_box, " 시계=", s18_find,
				" 기록·마지막대화=", s18_lib and s18_last, " 완결=", s18_done,
				" 5장본문=", s18_rec5)
		284:
			# #136: 메인 스토리 19 「일곱 갈래의 삶」 — 만렙마다 생명의 물 한 병,
			# 이미 만렙인 분야는 소급 지급, 일곱 병이면 노트 마지막 페이지
			m.dialog.close()
			var k19_skl: Dictionary = {}
			for sid19: String in GameData.ENDING_SKILLS:
				k19_skl[sid19] = (GameData.skills[sid19] as Dictionary).duplicate()
			var k19_found: Dictionary = GameData.water_life_found.duplicate()
			var k19_wl := int(GameData.items["water_life"])
			GameData.water_life_found = {}
			GameData.items["water_life"] = 0
			GameData.story19_shown = []
			GameData.story19_phase = ""
			GameData.story18_phase = "done"
			# ① 스토리 19가 열리기 전에는 만렙을 찍어도 병이 생기지 않는다
			GameData.skills["mine"] = {"lv": GameData.SKILL_MAX_LV - 1, "xp": 0.0}
			GameData.add_skill_xp("mine", 999999.0)
			var s19_gate: bool = GameData.water_count() == 0
			# ② 스토리가 열리면 이미 만렙인 분야는 소급해서 채워진다
			GameData.skills["fish"] = {"lv": GameData.SKILL_MAX_LV, "xp": 0.0}
			m.story._story19_update(0.016)
			var s19_back: bool = GameData.story19_phase == "seek" \
				and GameData.water_count() == 2 \
				and int(GameData.items["water_life"]) == 2
			# ③ 분야마다 짧은 전용 연출이 한 번씩 (같은 분야는 다시 안 나온다)
			m.story._story19_update(0.016)
			var s19_scene: bool = m.dialog.visible \
				and GameData.story19_shown.size() == 1
			m.dialog.skip_seq()
			m.story._story19_update(0.016)
			m.dialog.skip_seq()
			m.story._story19_update(0.016)
			var s19_scene_once: bool = GameData.story19_shown.size() == 2 \
				and not m.dialog.visible
			# ④ 순서는 강제하지 않는다 — 아무 분야나 만렙이면 한 병
			GameData.skills["cook"] = {"lv": GameData.SKILL_MAX_LV - 1, "xp": 0.0}
			GameData.add_skill_xp("cook", 999999.0)
			var s19_any: bool = GameData.water_count() == 3 \
				and GameData.water_life_found.has("cook")
			var s19_lock: bool = not GameData.note_last_page_open()
			# ⑤ 일곱 병 -> 노트의 마지막 페이지가 열린다
			for sid20: String in GameData.ENDING_SKILLS:
				GameData.skills[sid20] = {"lv": GameData.SKILL_MAX_LV, "xp": 0.0}
				GameData.check_skill_water(sid20)
			for i in 12:
				if GameData.story19_phase != "seek":
					break
				m.story._story19_update(0.016)
				m.dialog.skip_seq()
				m.dialog.close()
			var s19_page: bool = GameData.story19_phase == "page" \
				and GameData.water_count() == GameData.ENDING_SKILLS.size() \
				and GameData.note_last_page_open()
			# ⑥ 마지막 페이지를 읽으면 마지막 장소의 단서 -> 스토리 20으로
			m.story.open_last_page()
			var s19_read: bool = m.dialog.visible
			m.dialog.skip_seq()
			var s19_done: bool = GameData.story19_phase == "done" \
				and GameData.completed_quests().has("메인 스토리 19 — 일곱 갈래의 삶")
			for sid21: String in k19_skl:
				GameData.skills[sid21] = k19_skl[sid21]
			GameData.water_life_found = k19_found
			GameData.items["water_life"] = k19_wl
			GameData.water_pending = 0
			m.hud._toast_queue.clear()
			print("STORY19_OK=", s19_gate and s19_back and s19_scene
				and s19_scene_once and s19_any and s19_lock and s19_page
				and s19_read and s19_done,
				" 시작전차단=", s19_gate, " 소급지급=", s19_back,
				" 전용연출=", s19_scene, " 연출중복없음=", s19_scene_once,
				" 순서자유=", s19_any, " 페이지잠김=", s19_lock,
				" 일곱병·해금=", s19_page, " 마지막페이지=", s19_read,
				" 완결=", s19_done)
		285:
			# #137: 메인 스토리 20 「가장 오래된 자리」 — 세 조건 -> 서하·이장
			# -> 돌문에 생명의 물 일곱 -> 봉인된 것 -> 씨앗과 편지 -> 심기
			m.dialog.close()
			m.cave.close()
			var k20_skl: Dictionary = {}
			for sd20: String in GameData.ENDING_SKILLS:
				k20_skl[sd20] = (GameData.skills[sd20] as Dictionary).duplicate()
			var k20_found: Dictionary = GameData.water_life_found.duplicate()
			var k20_wl := int(GameData.items["water_life"])
			var k20_rel: Dictionary = {}
			for rd20: Dictionary in GameData.RELICS:
				k20_rel[rd20.id] = int(GameData.items[rd20.id])
			var k20_crops: Dictionary = GameData.crops_harvested.duplicate()
			var k20_fish: Dictionary = GameData.fish_caught.duplicate()
			var k20_mobs: Dictionary = GameData.mob_kills.duplicate()
			var k20_cook: Dictionary = GameData.recipes_cooked.duplicate()
			var k20_aff: Dictionary = GameData.affinity.duplicate()
			var k20_ds := GameData.dream_seen
			GameData.story19_phase = "done"
			GameData.story20_phase = ""
			GameData.story20_told = []
			GameData.gate_open = false
			GameData.seed_tile = Vector2i(-1, -1)
			GameData.seed_water = false
			GameData.items["grandpa_seed"] = 0
			# ① 세 조건이 다 차야 시작된다 — 유품만 있고 노트가 덜 차면 안 된다
			for rid20: Dictionary in GameData.RELICS:
				GameData.items[rid20.id] = 1
			GameData.water_life_found = {}
			for sd21: String in GameData.ENDING_SKILLS:
				GameData.water_life_found[sd21] = true
			GameData.items["water_life"] = GameData.ENDING_SKILLS.size()
			m.story._story20_update(0.016)
			var s20_gate3: bool = GameData.story20_phase == "" \
				and not GameData.ending_ready()
			for c20: String in GameData.CROP_IDS:
				GameData.crops_harvested[c20] = maxi(1, int(GameData.crops_harvested.get(c20, 0)))
			for f20: String in GameData.FISH_IDS:
				GameData.fish_caught[f20] = maxi(1, int(GameData.fish_caught.get(f20, 0)))
			for mb20: String in GameData.MOBS:
				GameData.mob_kills[mb20] = maxi(1, int(GameData.mob_kills.get(mb20, 0)))
			for rc20: String in GameData.RECIPE_IDS:
				GameData.recipes_cooked[rc20] = maxi(1, int(GameData.recipes_cooked.get(rc20, 0)))
			for a20: String in GameData.NPCS:
				GameData.affinity[a20] = 100
			GameData.minerals_found["ore"] = true
			GameData.minerals_found["gem"] = true
			var k20_for: Dictionary = GameData.forage_caught.duplicate()
			for fg20: String in GameData.FORAGE_IDS + GameData.BUG_IDS:
				GameData.forage_caught[fg20] = maxi(1, int(GameData.forage_caught.get(fg20, 0)))
			var k20_leg: Dictionary = {}
			for lg20: Array in GameData.LEGENDS:
				k20_leg[lg20[0]] = int(GameData.items[lg20[0]])
				GameData.items[lg20[0]] = maxi(1, int(GameData.items[lg20[0]]))
			var s20_note100: bool = GameData.note_progress().ratio >= 1.0
			m.story._story20_update(0.016)
			var s20_start: bool = GameData.story20_phase == "tell" \
				and GameData.quest_npc_marks().get("librarian", "") == "!"
			# ② 서하와 이장에게 마지막 페이지를 보여준다
			m.story.story20_show_page("librarian")
			m.dialog.skip_seq()
			m.story.story20_show_page("librarian")
			m.dialog.close()
			var s20_once: bool = GameData.story20_told.size() == 1 \
				and GameData.story20_phase == "tell"
			m.story.story20_show_page("chief")
			m.dialog.skip_seq()
			var s20_told: bool = GameData.story20_phase == "gate"
			# ③ 돌문은 세계에 놓인 오브젝트가 아니다 — 동굴 입구에서 이어진다
			var s20_stone := true
			for gt: Vector2i in m.objects:
				if str(m.objects[gt].get("kind", "")) == "old_gate":
					s20_stone = false
			GameData.items["water_life"] = 3
			m.story.gate_examine()
			var s20_lack: bool = m.dialog.visible and not GameData.gate_open
			m.dialog.close()
			GameData.items["water_life"] = GameData.ENDING_SKILLS.size()
			m.story._pour_water()
			var s20_open: bool = GameData.gate_open \
				and int(GameData.items["water_life"]) == 0
			m.dialog.skip_seq()
			m.dialog.close()
			# ④ 돌문 안쪽 — 한 방뿐이고 계단이 없다, 보스가 버티고 있다
			m.story._enter_gate()
			var s20_room: bool = m.cave.visible and m.cave.lastroom \
				and m.cave.stairs_pos.x < 0 and m.cave.monsters.size() >= 3 \
				and GameData.story20_phase == "inner"
			var s20_boss := false
			for mb: Dictionary in m.cave.monsters:
				if int(mb.hp) >= 60:
					s20_boss = true
			m.cave.monsters.clear()
			m.cave._floor_clear()
			var s20_chest: bool = m.cave.chest_pos.x >= 0
			# ⑤ 보관함 — 금도 보석도 아닌 씨앗 한 알과 마지막 편지
			m.story.final_chest()
			var s20_seed: bool = GameData.story20_phase == "letter" \
				and int(GameData.items["grandpa_seed"]) == 1 \
				and GameData.seed_day == GameData.day
			var letter_ok := false
			for pg: Dictionary in m.dialog._seq:
				if str(pg.get("text", "")).contains("가장 중요한 것을 이어받았"):
					letter_ok = true
			m.dialog.skip_seq()
			m.dialog.close()
			# ⑥ 다음 날 아침 — 갈고 심고 물을 주면 새싹이 돋는다
			m.story._story20_update(0.016)
			var s20_same: bool = GameData.story20_phase == "letter"
			GameData.day += 1
			m.story._story20_update(0.016)
			var s20_plantday: bool = GameData.story20_phase == "plant"
			var pt20 := Vector2i(m.HOME_ANCHOR.x + 2, m.HOME_ANCHOR.y + 6)
			m.objnode._remove_object(pt20)
			m.grid[pt20.y][pt20.x].ground = "soil"
			var s20_plant: bool = m.story.story20_plant(pt20) \
				and GameData.seed_tile == pt20 \
				and int(GameData.items["grandpa_seed"]) == 0
			m.dialog.close()
			var s20_replant: bool = not m.story.story20_plant(pt20)
			m.story.story20_water(pt20)
			var s20_sprout: bool = GameData.seed_water \
				and str(m.objects.get(pt20, {}).get("kind", "")) == "seed_sprout"
			m.dialog.skip_seq()
			var s20_done: bool = GameData.story20_phase == "done" \
				and GameData.note_last_line and m.ending.visible \
				and GameData.completed_quests().has("메인 스토리 20 — 가장 오래된 자리")
			# ⑦ 엔딩이 끝나도 세이브는 그대로 — 자유 생활이 이어진다
			while m.ending.phase != "outro":
				if m.ending.phase == "stats":
					while m.ending._idx < m.ending._lines.size():
						m.ending._reveal_next_stat()
				m.ending._advance()
			var d20 := GameData.day
			m.ending.wake()
			var s20_free: bool = not m.ending.visible and GameData.day == d20 \
				and m.hud.visible and not m.story_cutscene
			# 뒷정리 — 뒤 스텝을 오염시키지 않는다
			m.objnode._remove_object(pt20)
			m.grid[pt20.y][pt20.x].ground = "grass"
			GameData.seed_tile = Vector2i(-1, -1)
			GameData.seed_water = false
			GameData.story20_phase = ""
			GameData.story20_told = []
			GameData.gate_open = false
			GameData.note_last_line = false
			GameData.story19_phase = ""
			GameData.day -= 1
			GameData.dream_seen = k20_ds
			for sd22: String in k20_skl:
				GameData.skills[sd22] = k20_skl[sd22]
			GameData.water_life_found = k20_found
			GameData.items["water_life"] = k20_wl
			for rid21: String in k20_rel:
				GameData.items[rid21] = int(k20_rel[rid21])
			GameData.crops_harvested = k20_crops
			GameData.fish_caught = k20_fish
			GameData.mob_kills = k20_mobs
			GameData.recipes_cooked = k20_cook
			GameData.affinity = k20_aff
			GameData.forage_caught = k20_for
			for lg21: String in k20_leg:
				GameData.items[lg21] = int(k20_leg[lg21])
			m.hud._toast_queue.clear()
			print("STORY20_OK=", s20_gate3 and s20_note100 and s20_start
				and s20_once and s20_told and s20_stone and s20_lack
				and s20_open and s20_room and s20_boss and s20_chest
				and s20_seed and letter_ok and s20_same and s20_plantday
				and s20_plant and s20_replant and s20_sprout and s20_done
				and s20_free,
				" 조건3종=", s20_gate3 and s20_note100, " 시작=", s20_start,
				" 중복없음=", s20_once, " 두사람=", s20_told,
				" 돌문오브젝트없음=", s20_stone, " 병부족차단=", s20_lack,
				" 일곱병개방=", s20_open, " 마지막방=", s20_room,
				" 최종보스=", s20_boss, " 보관함=", s20_chest,
				" 씨앗·편지=", s20_seed and letter_ok,
				" 다음날심기=", s20_same and s20_plantday and s20_plant,
				" 중복심기차단=", s20_replant, " 새싹=", s20_sprout,
				" 마지막기록·엔딩=", s20_done, " 계속플레이=", s20_free)
		286:
			# #138: 서브 퀘스트 「용식의 집터」 + 수납 상자.
			# 바닷길을 연 지 정확히 3일 뒤 -> 분수대 앞 -> [대화하기] 선택지 ->
			# 집터에 집 짓기 -> 다시 말 걸기 -> 수납 상자 레시피
			m.dialog.close()
			# ① 이름 — 상점 상인 만수 · 낚시꾼 용식
			var name_ok: bool = str(GameData.NPCS["merchant"].name) == "만수" \
				and str(GameData.NPCS["fisher"].name) == "용식"
			# ② 바닷길을 연 지 3일 — 그전에는 나오지 않는다
			GameData.fisher_quest = "done"
			GameData.sea_open = true
			GameData.fisher_home = ""
			GameData.settler_homes.erase("fisher")
			GameData.recipes_unlocked.erase("storage_box")
			var k_day := GameData.day
			GameData.day = 30                      # 날짜 계산이 음수로 가지 않게
			GameData.sea_open_day = GameData.day   # 바닷길을 연 바로 그날
			m.story._fisher_home_update(0.016)
			var wait_early: bool = GameData.fisher_home == ""
			GameData.sea_open_day = GameData.day - GameData.FISHER_HOME_DAYS + 1
			m.story._fisher_home_update(0.016)     # 이틀 뒤 — 아직 안 나온다
			var wait_early2: bool = GameData.fisher_home == ""
			GameData.sea_open_day = GameData.day - GameData.FISHER_HOME_DAYS
			m.story._fisher_home_update(0.016)     # 정확히 사흘 뒤
			var wait_ok: bool = GameData.fisher_home == "wait" \
				and GameData.quest_npc_marks().get("fisher", "") == "!"
			# ③ 분수대 앞에 서 있다
			var place_ok: bool = m.npcmgr.npc_place_now("fisher") == "fountain"
			var ft := m.npcmgr.npc_place_tile("fisher", "fountain")
			var tile_ok: bool = absi(ft.x - (m.FOUNTAIN.position.x + 1)) <= 2 \
				and ft.y >= m.FOUNTAIN.end.y and ft.y <= m.FOUNTAIN.end.y + 2
			# ④ 말을 걸면 바로 시작되지 않고 「대화하기」 선택지가 먼저 뜬다
			m.story.fisher_home_greet()
			var flabels: Array = []
			for c in m.dialog.buttons_box.get_children():
				if c.is_queued_for_deletion() or not (c is Button):
					continue   # 지워지길 기다리는 지난 선택지는 세지 않는다
				flabels.append((c as Button).text.strip_edges())
			var greet_ok: bool = m.dialog.visible and flabels.size() == 2 \
				and flabels[0] == "대화하기" and GameData.fisher_home == "wait"
			# ⑤ 「대화하기」를 골라야 부탁이 시작된다
			m.story._start_fisher_home_dialog()
			m.dialog.skip_seq()
			var ask_ok: bool = GameData.fisher_home == "build" \
				and GameData.quest_catalog().any(func(q: Dictionary) -> bool:
					return str(q.id) == "fisher_home")
			# ⑥ 마을 아무 곳에나 집터 -> 그 위에 집을 짓는다
			var fdoor := Vector2i(88, 30)
			for fy in range(24, 36):
				for fx in range(82, 95):
					m.objnode._remove_object(Vector2i(fx, fy))
					m.grid[fy][fx].ground = "grass"
					m.grid[fy][fx].crop_id = ""
			GameData.items["housing_kit"] = int(GameData.items.get("housing_kit", 0)) + 1
			var fplaced: bool = m.story.try_place_home_plot(fdoor)
			var fanchor := fdoor - Vector2i(2, 3)
			m.story.build_fisher_home(fdoor)
			# 지은 직후에는 아직 「빈 집」이다 — 문 옆 표지판에서 주인을 정한다
			var sign_ft := Vector2i(-999, -999)
			for foff: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(-1, 1), Vector2i(1, 1)]:
				if str(m.objects.get(fdoor + foff, {}).get("kind", "")) == "home_sign":
					sign_ft = fdoor + foff
					break
			var empty_home: bool = GameData.fisher_home == "build" \
				and sign_ft.x != -999 and not GameData.settler_homes.has("fisher")
			m.story._pick_fisher_home(sign_ft)
			var built_ok: bool = fplaced and empty_home \
				and GameData.fisher_home == "built" \
				and str(m.objects.get(fanchor, {}).get("kind", "")) == "house" \
				and GameData.settler_homes.has("fisher") \
				and GameData.quest_npc_marks().get("fisher", "") == "?"
			# ⑦ 다시 말을 걸면 완료 대사 + 수납 상자 레시피
			m.story.fisher_home_report()
			var report_ok: bool = m.dialog.visible
			m.dialog.skip_seq()
			var done_ok: bool = GameData.fisher_home == "done" \
				and "storage_box" in GameData.recipes_unlocked \
				and not GameData.recipe_locked("storage_box") \
				and GameData.completed_quests().has("용식의 부탁 — 살 집 한 채")
			var cost_ok: bool = int(GameData.DESK_RECIPES["storage_box"].cost.wood) == 8
			# ⑧ 수납 상자 — 넣기·꺼내기·칸 제한
			GameData.storage_stock = {}
			GameData.items["ore"] = 10
			var put_n := GameData.storage_put("ore", 4)
			var put_ok: bool = put_n == 4 and int(GameData.storage_stock["ore"]) == 4 \
				and int(GameData.items["ore"]) == 6
			var take_n := GameData.storage_take("ore", 3)
			var take_ok: bool = take_n == 3 and int(GameData.storage_stock["ore"]) == 1 \
				and int(GameData.items["ore"]) == 9
			GameData.storage_take("ore", 99)
			var empty_ok: bool = not GameData.storage_stock.has("ore")
			# 도구·편지처럼 넣으면 안 되는 것은 목록에 오르지 않는다
			GameData.items["housing_kit"] = 1
			var block_ok: bool = not GameData.storage_can_store("housing_kit")
			# 칸이 꽉 차면 새 종류는 더 못 넣는다 (이미 있는 종류는 계속 쌓인다)
			GameData.storage_stock = {}
			for si in GameData.STORAGE_SLOTS:
				GameData.storage_stock["slot_%d" % si] = 1
			GameData.items["gem"] = 5
			var full_ok: bool = GameData.storage_full() \
				and GameData.storage_put("gem", 1) == 0
			GameData.storage_stock = {}
			# 뒷정리 — 뒤 스텝을 오염시키지 않는다
			m.objnode._remove_object(fanchor)
			for fy2 in range(24, 36):
				for fx2 in range(82, 95):
					m.objnode._remove_object(Vector2i(fx2, fy2))
			for i in range(GameData.home_plots.size() - 1, -1, -1):
				var hp: Dictionary = GameData.home_plots[i]
				if int(hp.x) == fanchor.x and int(hp.y) == fanchor.y:
					GameData.home_plots.remove_at(i)
			GameData.settler_homes.erase("fisher")
			GameData.home_signs.erase(str(sign_ft))
			GameData.fisher_home = ""
			GameData.sea_open_day = 0
			GameData.day = k_day
			GameData.items["housing_kit"] = 0
			GameData.items["ore"] = 0
			GameData.items["gem"] = 0
			m.objnode._spawn_objects()
			m.hud._toast_queue.clear()
			print("SUBFISH_OK=", name_ok and wait_early and wait_early2 and wait_ok
				and place_ok and tile_ok and greet_ok and ask_ok and fplaced
				and built_ok and report_ok and done_ok and cost_ok and put_ok
				and take_ok and empty_ok and block_ok and full_ok,
				" 이름=", name_ok, " 3일전차단=", wait_early and wait_early2,
				" 3일뒤등장=", wait_ok, " 분수대앞=", place_ok and tile_ok,
				" 대화하기선택지=", greet_ok, " 부탁시작=", ask_ok,
				" 집터·건설=", fplaced and built_ok, " 완료보고=", report_ok and done_ok,
				" 레시피목재8=", cost_ok, " 넣기=", put_ok, " 꺼내기=", take_ok and empty_ok,
				" 제외품목=", block_ok, " 칸제한=", full_ok)
		287:
			# #139: 손본 여섯 가지 —
			# 농사 줄기(수확 뒤 요리로 이어짐) · 안내 말풍선 · 붙박이 충돌 ·
			# 찾아오는 사람의 방향 · 조합법 확률 · 대사 페이지(322에서 따로)
			m.dialog.close()
			var k_tut: Dictionary = GameData.tutorial.duplicate()
			var k_s2 := GameData.story2_phase
			var k_guide := GameData.guide_active
			GameData.tutorial = GameData.fresh_tutorial()
			GameData.story2_phase = "farm"
			GameData.guide_active = false
			# ① 밭 갈기 -> 씨앗 -> 물 -> 수확 -> 요리. 어느 걸음에서도 안 끊긴다
			var chain: Array = []
			var chain_ok := true
			for step_flag: String in ["till", "plant", "water", "harvest", "cook"]:
				var here := GameData.tutorial_current_flag()
				if here != step_flag or GameData.tutorial_objective_short() == "":
					chain_ok = false
				# 퀘스트 목록에도 반드시 한 줄로 올라와 있어야 한다
				var listed := false
				for q: Dictionary in GameData.quest_catalog():
					if str(q.id) == "tutorial":
						listed = true
				if not listed:
					chain_ok = false
				chain.append(here)
				m.story.tutorial_notify(step_flag)
				m.dialog.close()
			GameData.tutorial = k_tut
			GameData.story2_phase = k_s2
			GameData.guide_active = k_guide
			# ② 안내는 검은 띠가 아니라 주인공 머리 위 말풍선이다.
			#    글자가 풍선 밖으로 삐져나오지 않는지도 함께 본다
			m.hud.show_message("긴 안내도 말풍선 안에 다 들어가야 한다. 이렇게 길어도 마찬가지다.", 3.0)
			var bub: Panel = m.hud._bub
			var lbl: Label = m.hud._bub_label
			var bubble_ok: bool = bub != null and bub.visible \
				and lbl.size.x + 2.0 <= bub.size.x and lbl.size.y + 2.0 <= bub.size.y \
				and bub.position.x >= 0.0 and bub.position.y >= 0.0 \
				and bub.position.x + bub.size.x <= 960.0
			var no_black_bar: bool = not m.hud.msg_label.visible
			# ③ 집 안 붙박이(제작대·조리대)는 통과할 수 없다
			m.interior._layout()
			var desk_hit: bool = m.interior._blocked(m.interior.DESK.get_center())
			var kit_hit: bool = m.interior._blocked(m.interior.KITCHEN.get_center())
			# 붙박이가 아닌 빈 바닥은 지나갈 수 있어야 한다 (방 한가운데는 확장한
			# 집에서 식탁이 차지할 수도 있으므로, 빈 자리가 있는지로 본다)
			var free_spot := false
			for sy in range(int(m.interior.ROOM.position.y) + 48,
					int(m.interior.ROOM.end.y) - 24, 12):
				for sx in range(int(m.interior.ROOM.position.x) + 24,
						int(m.interior.ROOM.end.x) - 24, 12):
					if not m.interior._blocked(Vector2(sx, sy)):
						free_spot = true
						break
				if free_spot:
					break
			var desk_block: bool = desk_hit and kit_hit and free_spot
			# ④ 찾아오는 사람은 자기가 서 있던 쪽에서 다가온다 (늘 남쪽이 아니라)
			var pt0 := m.player_tile()
			var from_north := Vector2((pt0.x) * m.TILE + 16.0, (pt0.y - 8) * m.TILE + 16.0)
			var spot_n := m.story._walk_tile_near_player(3, from_north)
			var from_west := Vector2((pt0.x - 8) * m.TILE + 16.0, (pt0.y) * m.TILE + 16.0)
			var spot_w := m.story._walk_tile_near_player(3, from_west)
			var side_ok: bool = spot_n.y < pt0.y and spot_w.x < pt0.x
			m.hud._toast_queue.clear()
			print("SUBFIX_OK=", chain_ok and bubble_ok and no_black_bar
				and desk_block and side_ok,
				" 농사줄기=", chain_ok, chain, " 말풍선=", bubble_ok,
				" 검은띠제거=", no_black_bar, " 붙박이충돌=", desk_block,
				"(제작대 ", desk_hit, " 조리대 ", kit_hit, " 빈바닥 ", free_spot, ")",
				" 접근방향=", side_ok, "(북 ", spot_n - pt0, " · 서 ", spot_w - pt0, ")")
			_save_shot("_bubble.png")
		288:
			# #140: 튜토리얼 퀘스트 「먼지 속의 조리대」 —
			# 세 갈래 방아쇠(A 레시피 / B 사고 나감 / C 그냥 나감) ->
			# 빗자루 -> 청소 -> 조리대 -> 만수의 선물 -> 첫 요리
			m.dialog.close()
			m.shop.close()
			m.shop_room.close()
			var k_kf := GameData.kitchen_found
			var k_kq := GameData.kitchen_quest
			var k_dust := GameData.dust_swept
			var k_ri: Dictionary = GameData.recipe_items.duplicate()
			var k_ru: Array = GameData.recipes_unlocked.duplicate()
			var k_rc: Dictionary = GameData.recipes_cooked.duplicate()
			var k_money := GameData.money
			var k_spent := GameData.today_spent

			# 준비 — 잡화점은 서 있고, 조리대는 아직 먼지 밑이다
			var had_general: bool = GameData.village_built.has("general")
			if not had_general:
				GameData.village_built.append("general")
			GameData.kitchen_found = false
			GameData.dust_swept = 0
			GameData.recipes_cooked.erase(GameData.JAM_ID)
			GameData.recipe_items.erase("broom")
			GameData.recipes_unlocked.erase("broom")
			GameData.recipes_unlocked.erase(GameData.JAM_ID)
			var k_broom := int(GameData.items["broom"])
			var k_weed := int(GameData.items["weed"])
			var k_berry := int(GameData.items["forage_berry"])
			var k_jam := int(GameData.items[GameData.JAM_ID])
			GameData.items["broom"] = 0
			GameData.items["weed"] = 0
			GameData.items["forage_berry"] = 0

			# ── 시작점은 하나뿐 — 첫 수확 뒤 만수와의 대화
			var k_s2k := GameData.story2_phase
			GameData.kitchen_quest = ""
			GameData.money = 9999
			GameData.story2_phase = "farm"
			var not_yet: bool = not GameData.kitchen_quest_ready()
			# 첫 수확이 2장을 끝내지 않는다 — 만수에게 가라고 한다
			for f9 in GameData.STORY2_FLAGS:
				GameData.tutorial[f9] = false
			GameData.tutorial["active"] = true
			m.tutorial_notify("harvest")
			var to_merchant: bool = GameData.story2_phase == "cook" \
				and GameData.kitchen_quest_ready() \
				and GameData.quest_npc_marks().get("merchant", "") == "!"
			# 가게를 나서도 붙잡지 않는다 (예전 분기 B·C가 사라졌다)
			m.shop_room.open("general")
			var free_exit: bool = m.shop_room.try_leave() \
				and not m.shop_room.visible and GameData.kitchen_quest == ""
			# 레시피를 사려 해도 여기서 시작되지 않는다 (분기 A도 사라졌다)
			var money_a := GameData.money
			m.shop._on_buy_dish_recipe("dish_grilled_fish", 200)
			var branch_a: bool = GameData.kitchen_quest == "" \
				and GameData.money == money_a \
				and not GameData.recipe_items.has("dish_grilled_fish")
			m.dialog.skip_seq()
			m.dialog.close()
			# 만수에게 말을 걸면 그제야 시작된다
			m.village.open_merchant_counter()
			var start_talk: bool = m.dialog.visible
			var intro_txt := ""
			for e8: Dictionary in m.dialog._seq:
				intro_txt += str(e8.get("text", "")) + " "
			# 「부엌」이라는 말은 게임 어디에도 없다 — 언제나 「조리대」다
			var no_kitchen_word: bool = not intro_txt.contains("부엌")
			for q8: Dictionary in GameData.quest_catalog():
				for key8: String in ["title", "obj", "desc", "reward"]:
					if str(q8.get(key8, "")).contains("부엌"):
						no_kitchen_word = false
			for nid8: String in GameData.NPCS:
				var nd8: Dictionary = GameData.NPCS[nid8]
				for key9: String in ["greet", "secret50", "secret100"]:
					if str(nd8.get(key9, "")).contains("부엌"):
						no_kitchen_word = false
			for gq8: Dictionary in GameData.GRANDPA_QUESTS:
				if str(gq8.get("name", "")).contains("부엌") \
						or str(gq8.get("desc", "")).contains("부엌"):
					no_kitchen_word = false
			var branch_b: bool = intro_txt.contains("밥은") and no_kitchen_word
			m.dialog.skip_seq()
			m.dialog.close()
			var bought_ok: bool = GameData.kitchen_quest == "broom"
			var branch_c: bool = not_yet and to_merchant and start_talk

			# ── 진행: 레시피 -> 잡초 -> 빗자루 -> 청소 -> 조리대
			GameData.give_recipe("broom")
			m.story._kitchen_update(0.0)
			var step_make: bool = GameData.kitchen_quest == "make"
			GameData.learn_recipe("broom")
			m.doing.gain_item("weed", 1)
			var goal_weed: bool = GameData.kitchen_quest_objective_short().contains("빗자루를 만들자")
			GameData.items["weed"] = 0
			GameData.items["broom"] = 1
			m.story._kitchen_update(0.0)
			var step_sweep: bool = GameData.kitchen_quest == "sweep"
			m.interior._layout()
			for i in GameData.DUST_TOTAL:
				m.interior._sweep_kitchen()
			m.dialog.close()
			m.story._kitchen_update(0.0)
			var step_found: bool = GameData.kitchen_found \
				and GameData.kitchen_quest == "found" \
				and GameData.quest_npc_marks().get("merchant", "") == "?"
			# 아직 요리 레시피는 못 산다 (튜토리얼이 안 끝났다)
			var money_b := GameData.money
			m.shop._on_buy_dish_recipe("dish_grilled_fish", 200)
			var still_block: bool = GameData.money == money_b \
				and not GameData.cook_shop_open()
			m.dialog.skip_seq()
			m.dialog.close()

			# ── 선물: 산딸기잼 레시피 1 + 산딸기 3
			m.village.open_merchant_counter()
			var gift_open: bool = m.dialog.visible
			m.dialog.skip_seq()
			var gift_ok: bool = GameData.kitchen_quest == "jam" \
				and int(GameData.recipe_items.get(GameData.JAM_ID, 0)) >= 1 \
				and int(GameData.items["forage_berry"]) >= GameData.JAM_BERRIES
			m.dialog.close()

			# ── 첫 요리: 지으면 「만수에게 가져가자」로 넘어간다
			GameData.learn_recipe(GameData.JAM_ID)
			var cooked: bool = GameData.cook(GameData.JAM_ID)
			m.story._kitchen_update(0.0)
			var deliver_step: bool = cooked and GameData.kitchen_quest == "deliver" \
				and GameData.kitchen_quest_objective_short().contains("만수") \
				and not GameData.cook_shop_open() \
				and GameData.quest_npc_marks().get("merchant", "") == "?"
			# 빈손으로 가면 보여 달라고만 한다
			var k_jam2 := int(GameData.items[GameData.JAM_ID])
			GameData.items[GameData.JAM_ID] = 0
			m.village.open_merchant_counter()
			var empty_hand: bool = m.dialog.visible \
				and GameData.kitchen_quest == "deliver"
			m.dialog.close()
			# 요리를 들고 가면 칭찬 + 판매·먹기 안내 -> 2장 완결
			GameData.items[GameData.JAM_ID] = maxi(k_jam2, 1)
			m.village.open_merchant_counter()
			var deliver_txt := ""
			for e7: Dictionary in m.dialog._seq:
				deliver_txt += str(e7.get("text", "")) + " "
			var teach_ok: bool = deliver_txt.contains("돈") \
				and deliver_txt.contains("먹") and m.dialog.visible
			m.dialog.skip_seq()
			var story2_end: bool = GameData.kitchen_quest == "done" \
				and GameData.story2_phase == "done" \
				and GameData.cook_shop_open() \
				and GameData.move_day == GameData.day \
				and m.dialog.visible \
				and GameData.completed_quests().has("조리대에서 요리를 하자 — 첫 끼를 지어 나눴다")
			m.dialog.close()
			var done_ok: bool = deliver_step and empty_hand and teach_ok \
				and story2_end
			var money_c := GameData.money
			m.shop._on_buy_dish_recipe("dish_grilled_fish", 200)
			var sell_ok: bool = GameData.money == money_c - 200 \
				and GameData.recipe_items.has("dish_grilled_fish")
			m.dialog.close()

			# 뒷정리
			if not had_general:
				GameData.village_built.erase("general")
			GameData.kitchen_found = k_kf
			GameData.kitchen_quest = k_kq
			GameData.kitchen_branch = ""
			GameData.dust_swept = k_dust
			GameData.recipe_items = k_ri
			GameData.recipes_unlocked = k_ru
			GameData.recipes_cooked = k_rc
			GameData.money = k_money
			GameData.today_spent = k_spent
			GameData.items["broom"] = k_broom
			GameData.items["weed"] = k_weed
			GameData.items["forage_berry"] = k_berry
			GameData.items[GameData.JAM_ID] = k_jam
			m.hud._toast_queue.clear()
			GameData.story2_phase = k_s2k
			print("KITCHEN_OK=", branch_a and branch_b and bought_ok and branch_c
				and free_exit and step_make and goal_weed and step_sweep
				and step_found and still_block and gift_open and gift_ok
				and done_ok and sell_ok,
				" 상점에선안열림=", branch_a, " 만수대사(밥·부엌없음)=", branch_b,
				" 수확→만수=", branch_c, " 대화로시작=", bought_ok,
				" 자유퇴장=", free_exit,
				" 레시피→제작=", step_make and goal_weed and step_sweep,
				" 청소·조리대=", step_found, " 완료전차단=", still_block,
				" 선물=", gift_open and gift_ok, " 가져가기·2장완결=", done_ok,
				" 레시피판매해금=", sell_ok)
		289:
			# #141: 한 배치 — ① 바다 지형 고정 ② 돌문 숨김·자리 ③ 낚싯대 없이
			# 낚시 금지 ④ 집 표지판으로 주인 정하기 ⑤ 지도 퀘스트 마커
			# ⑥ 제작대 그림·탭
			m.dialog.close()
			m.desk_ui.close()

			# ── ① 바다는 처음부터 그 자리에 있다 (돌을 캐도 숲이 변하지 않는다)
			var k_sea := GameData.sea_open
			var k_seaday := GameData.sea_open_day
			GameData.sea_open = false
			m.worldgen._build_sea()
			var sea_fixed: bool = str(m.grid[m.SEA_Y0 + 2][40].ground) == "water" \
				and str(m.grid[m.BEACH_Y0 + 1][40].ground) == "sand" \
				and str(m.objects.get(m.SEA_GATE[0], {}).get("kind", "")) == "bigrock"
			var land_before: Array = []
			for ly in range(m.SEA_RIDGE_Y - 6, m.SEA_RIDGE_Y):
				for lx in range(20, 100, 7):
					land_before.append(str(m.grid[ly][lx].ground))
			m.worldgen._reveal_sea()          # 길목 바위를 캐는 순간
			var land_after: Array = []
			for ly2 in range(m.SEA_RIDGE_Y - 6, m.SEA_RIDGE_Y):
				for lx2 in range(20, 100, 7):
					land_after.append(str(m.grid[ly2][lx2].ground))
			var no_morph: bool = land_before == land_after \
				and str(m.grid[m.SEA_Y0 + 2][40].ground) == "water" \
				and not m.objects.has(m.SEA_GATE[0]) \
				and not m.objects.has(m.SEA_GATE[1])
			GameData.sea_open = k_sea
			GameData.sea_open_day = k_seaday
			m.worldgen._build_sea()

			# ── ② 오래된 돌문: 세계 어디에도 없다 (상점과 겹치던 버그의 뿌리)
			var k_s18b := GameData.story18_phase
			var k_s19 := GameData.story19_phase
			var k_s20 := GameData.story20_phase
			var gate_hidden := true
			for ph: String in ["", "memo", "hill", "tale"]:
				GameData.story18_phase = ph
				GameData.story19_phase = ph
				GameData.story20_phase = ph
				m.worldgen._build_map()
				for gt: Vector2i in m.objects:
					if str(m.objects[gt].get("kind", "")) == "old_gate":
						gate_hidden = false
			GameData.story18_phase = k_s18b
			GameData.story19_phase = k_s19
			GameData.story20_phase = k_s20
			# 옛 세이브에 남아 있어도 걷어낸다
			var gate_ghost := Vector2i(40, 2)
			m.objects[gate_ghost] = {"kind": "old_gate", "hp": 0}
			m.worldgen.purge_old_gate()
			var gate_shown: bool = not m.objects.has(gate_ghost)
			# 상점 마당에는 어떤 붙박이도 남지 않는다
			var gate_clear := true
			for pid2: String in m.VILLAGE_PLOTS:
				var anc: Vector2i = m.VILLAGE_PLOTS[pid2].anchor
				var yard := Rect2i(anc.x - m.YARD_PAD, anc.y - m.YARD_PAD,
					5 + m.YARD_PAD * 2, 4 + m.YARD_PAD * 2)
				for yy in range(yard.position.y, yard.end.y):
					for xx in range(yard.position.x, yard.end.x):
						var ot := Vector2i(xx, yy)
						if str(m.objects.get(ot, {}).get("kind", "")) == "old_gate":
							gate_clear = false

			# ── ③ 낚싯대가 없으면 강이든 바다든 못 던진다 (말풍선으로 알린다)
			var k_unlocked: Array = GameData.unlocked_tools.duplicate()
			var k_slots: Array = GameData.tool_slots.duplicate()
			var k_tool := GameData.tool
			GameData.unlocked_tools.erase("rod")
			var no_rod: bool = not GameData.can_fish() \
				and "rod" not in GameData.TUTORIAL_UNLOCKS["harvest"]
			GameData.tool_slots[0] = "rod"
			GameData.tool = "rod"
			m.hud.show_message("...")
			m._target_override = Vector2i(40, m.SEA_Y0 + 2)
			m.toolwork.use_tool()
			m._target_override = Vector2i(-999, -999)
			var rod_bubble: bool = m.hud._bub_label.text.contains("낚시대가 없다") \
				and m.fishing_state == ""
			if "rod" not in GameData.unlocked_tools:
				GameData.unlocked_tools.append("rod")
			var rod_ok: bool = GameData.can_fish()
			GameData.unlocked_tools = k_unlocked
			GameData.tool_slots = k_slots
			GameData.tool = k_tool

			# ── ④ 다 지은 집의 표지판에서 「용식의 집」으로 정한다
			var k_fh := GameData.fisher_home
			var k_signs: Dictionary = GameData.home_signs.duplicate()
			var k_homes: Dictionary = GameData.settler_homes.duplicate()
			var door := Vector2i(-1, -1)
			for dy in range(44, 62):
				for dx in range(28, 48):
					var d0 := Vector2i(dx, dy)
					if m.is_passable(d0 + Vector2i(1, 0)) \
							and not m.objects.has(d0 + Vector2i(1, 0)):
						door = d0
						break
				if door.x >= 0:
					break
			var anchor2 := door - Vector2i(2, 3)
			GameData.fisher_home = "build"
			m.story._place_home_sign(anchor2, door)
			var sign_t := Vector2i(-999, -999)
			for off2: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(-1, 1), Vector2i(1, 1)]:
				if str(m.objects.get(door + off2, {}).get("kind", "")) == "home_sign":
					sign_t = door + off2
					break
			var sign_placed: bool = sign_t.x != -999 \
				and GameData.home_signs.has(str(sign_t))
			m.story.home_sign_dialog(sign_t)
			var sign_labels: Array = []
			for c9 in m.dialog.buttons_box.get_children():
				if c9.is_queued_for_deletion() or not (c9 is Button):
					continue
				sign_labels.append((c9 as Button).text.strip_edges())
			var sign_menu: bool = m.dialog.visible and sign_labels.size() == 2 \
				and str(sign_labels[0]).contains("용식의 집으로 결정")
			m.story._pick_fisher_home(sign_t)
			var picked_home: bool = GameData.fisher_home == "built" \
				and Array(GameData.settler_homes.get("fisher", [])) \
					== [anchor2.x, anchor2.y]
			m.dialog.close()
			if sign_t.x != -999:
				m.objnode._remove_object(sign_t)
			GameData.fisher_home = k_fh
			GameData.home_signs = k_signs
			GameData.settler_homes = k_homes

			# ── ⑤ 지도(M)에 진행 중인 퀘스트 목적지가 찍힌다
			var k_s18 := GameData.story18_phase
			var k_pick := GameData.tracked_pick
			GameData.story18_phase = "hill"
			GameData.tracked_pick = "story18"
			var guides: Array = m.map_ui._quest_guides()
			var guide_ok := false
			if guides.size() == 1:
				var g0: Dictionary = guides[0]
				var gt: Vector2i = g0.tile
				guide_ok = gt == m.HILL_POS and str(g0.text).contains("시계")
			GameData.story18_phase = k_s18
			GameData.tracked_pick = k_pick

			# ── ⑥ 제작대: 갈래별 탭 + 글자보다 그림
			var k_ru2: Array = GameData.recipes_unlocked.duplicate()
			for rid: String in ["broom", "spear", "flower_pot", "storage_box"]:
				if rid not in GameData.recipes_unlocked:
					GameData.recipes_unlocked.append(rid)
			m.desk_ui.open()
			var ids_all: Array = m.desk_ui.tab_ids("all")
			var ids_tool: Array = m.desk_ui.tab_ids("tool")
			var ids_furn: Array = m.desk_ui.tab_ids("furniture")
			var ids_life: Array = m.desk_ui.tab_ids("life")
			var cats_ok: bool = ids_all.size() \
					== ids_tool.size() + ids_furn.size() + ids_life.size() \
				and "spear" in ids_tool and "sword" not in ids_life \
				and "bed_wood" in ids_furn and "flower_pot" in ids_furn \
				and "broom" in ids_life and "storage_box" in ids_life
			m.desk_ui.set_tab("tool")
			var pics := 0
			var stack: Array = [m.desk_ui._root]
			while not stack.is_empty():
				var nd: Node = stack.pop_back()
				for ch in nd.get_children():
					stack.append(ch)
					if ch is TextureRect:
						pics += 1
			var tab_ok: bool = m.desk_ui._tab == "tool" \
				and m.desk_ui.tab_ids("tool").size() == ids_tool.size() \
				and pics >= ids_tool.size() * 2
			m.desk_ui.set_tab("all")
			# 창은 열어 둔 채 넘어간다 — 화면은 다음 단계(291)에서 찍는다
			# (_save_shot은 「지난 프레임」을 뜬다)
			_desk_keep = k_ru2
			m.hud._toast_queue.clear()
			print("TERRAIN_UI_OK=", sea_fixed and no_morph and gate_hidden
				and gate_shown and gate_clear and no_rod and rod_bubble and rod_ok
				and sign_placed and sign_menu and picked_home and guide_ok
				and cats_ok and tab_ok,
				" 바다고정=", sea_fixed, " 숲안변함=", no_morph,
				" 돌문없음=", gate_hidden, " 옛세이브청소=", gate_shown,
				" 상점마당깨끗=", gate_clear, " 낚싯대전금지=", no_rod,
				" 말풍선=", rod_bubble, " 낚싯대후해금=", rod_ok,
				" 표지판=", sign_placed, " 선택지=", sign_menu,
				" 용식의집=", picked_home, " 지도마커=", guide_ok,
				" 제작대탭=", cats_ok, " 그림수=", tab_ok, "(", pics, "장)")
		292:
			# #142: 배고픔(포만감) · ESC 레이어 · 재민/우체부 이름 · 돌 창 아이콘
			m.dialog.close()
			m.inventory_ui.close()

			# ── ① 이름
			var names_ok: bool = str(GameData.NPCS["explorer"].name) == "재민" \
				and str(GameData.NPCS["postman"].name) == "우체부 아저씨" \
				and str(GameData.NPC_KIND.get("postman", "")) == "core" \
				and str(m.VILLAGE_NPC.get("post", "")) == "postman" \
				and m.NPC_SCHEDULE.has("postman") \
				and GameData.affinity.has("postman")

			# ── ② 배고픔: 열리기 전에는 아무 일도 없다
			var k_open := GameData.hunger_open
			var k_hunger := GameData.hunger
			var k_energy := GameData.energy
			GameData.hunger_open = false
			GameData.hunger = GameData.HUNGER_MAX
			GameData.hunger_tick(9999.0)
			var closed_ok: bool = GameData.hunger == GameData.HUNGER_MAX \
				and not GameData.starving() \
				and is_equal_approx(GameData.hunger_speed_mult(), 1.0)
			# 열리면 시간이 지날수록 배가 꺼진다
			GameData.hunger_open = true
			GameData.hunger = GameData.HUNGER_MAX
			GameData.hunger_tick(300.0)                 # 게임 5시간
			var drain_ok: bool = GameData.hunger < GameData.HUNGER_MAX \
				and GameData.hunger > 0.0
			GameData.hunger_tick(99999.0)               # 하루를 통째로 굶으면
			var empty_ok: bool = GameData.hunger == 0.0 and GameData.starving() \
				and GameData.hunger_speed_mult() < 0.5   # 걸음이 눈에 띄게 느리다
			# 밖에서 굶으면 체력이 계속 깎인다 (바닥까지)
			GameData.energy = 50.0
			GameData.starve_tick(5.0, false)
			var out_drop: bool = GameData.energy < 50.0
			GameData.starve_tick(999.0, false)
			var out_zero: bool = GameData.energy <= 0.0
			# 집 안(안전지대)에서는 30 아래로 내려가지 않는다
			GameData.energy = GameData.ENERGY_MAX
			GameData.starve_tick(999.0, true)
			var safe_floor: bool = is_equal_approx(GameData.energy,
				GameData.HUNGER_SAFE_FLOOR)
			GameData.energy = 12.0                      # 이미 바닥이면 회복도 없다
			GameData.starve_tick(999.0, true)
			var no_heal: bool = is_equal_approx(GameData.energy, 12.0)
			# 먹으면 배가 찬다
			GameData.feed(60.0)
			var feed_ok: bool = GameData.hunger == 60.0 and not GameData.starving()
			# 게이지는 해금됐을 때만 뜬다
			m.hud.refresh(true)
			var gauge_on: bool = m.hud.hunger_panel != null and m.hud.hunger_panel.visible
			GameData.hunger_open = false
			m.hud.refresh(true)
			var gauge_off: bool = not m.hud.hunger_panel.visible
			GameData.hunger_open = k_open
			GameData.hunger = k_hunger
			GameData.energy = k_energy

			# ── ③ ESC: 겹쳐 뜬 창이 먼저 닫힌다 (집 안에서도)
			var esc := InputEventAction.new()
			esc.action = "ui_cancel"
			esc.pressed = true
			var room_before: bool = not m.room_overlay_open()
			m.inventory_ui.toggle()                      # 가방을 연다
			var overlay_ok: bool = m.inventory_ui.visible and m.room_overlay_open()
			m.interior.visible = true
			m.interior._unhandled_input(esc)             # 집 안에서 ESC
			var bag_first: bool = not m.dialog.visible   # 게임 메뉴가 뜨지 않았다
			m.inventory_ui.close()
			m.interior._unhandled_input(esc)             # 이제는 방이 받는다
			var menu_ok: bool = m.dialog.visible
			m.dialog.close()
			m.interior.visible = false

			# ── ④ 돌 창 아이콘 — 돌 검과 다른 그림이고, 비어 있지 않다
			var spear_tex: Texture2D = m.hud.tool_icon("spear")
			var sword_tex: Texture2D = m.hud.tool_icon("sword")
			var spear_px := 0
			if spear_tex != null:
				var simg := spear_tex.get_image()
				for py in simg.get_height():
					for px in simg.get_width():
						if simg.get_pixel(px, py).a > 0.5:
							spear_px += 1
			var art_ok: bool = spear_tex != null and sword_tex != null \
				and spear_tex != sword_tex and spear_px > 80 \
				and spear_tex.get_width() == 32
			m.hud._toast_queue.clear()
			print("HUNGER_UI_OK=", names_ok and closed_ok and drain_ok and empty_ok
				and out_drop and out_zero and safe_floor and no_heal and feed_ok
				and gauge_on and gauge_off and room_before and overlay_ok
				and bag_first and menu_ok and art_ok,
				" 이름·우체부=", names_ok, " 해금전무효=", closed_ok,
				" 시간감소=", drain_ok, " 0=굶주림=", empty_ok,
				" 밖체력감소=", out_drop and out_zero,
				" 집안바닥30=", safe_floor and no_heal, " 먹기=", feed_ok,
				" 게이지=", gauge_on and gauge_off,
				" ESC가방먼저=", room_before and overlay_ok and bag_first,
				" ESC방메뉴=", menu_ok, " 돌창아트=", art_ok, "(", spear_px, "px)")
		293:
			# #143: Q창 동화 이야기·감성 목표 · 지도 건설 후보지 · 요리별 배부름
			m.dialog.close()

			# ── ① Q창: 이야기는 길고 서정적으로, 목표엔 재료 수치·키가 없다
			var k_s2p := GameData.story2_phase
			var k_built4: Array = GameData.village_built.duplicate()
			var k_story := GameData.story_phase
			GameData.story_phase = "done"
			GameData.village_built.erase("general")
			GameData.story2_phase = "shop"
			var shop_entry: Dictionary = {}
			for q: Dictionary in GameData.quest_catalog():
				if str(q.id) == "story2":
					shop_entry = q
			var tale_ok: bool = not shop_entry.is_empty() \
				and str(shop_entry.desc).length() >= 80 \
				and str(shop_entry.desc).contains("\n")
			# 목표는 짧고, 괄호도 조작키 안내도 없다
			var shop_obj := str(shop_entry.get("obj", ""))
			var obj_soft: bool = shop_obj == "상점을 세우자." \
				and not shop_obj.contains("(") and not shop_obj.contains("E")
			# 지금 떠 있는 모든 퀘스트의 목표에 내부 키(밑줄)와 재료 수치가 없다
			var no_keys := true
			var soft_all := true
			for q2: Dictionary in GameData.quest_catalog():
				var ob := str(q2.get("obj", ""))
				if ob.contains("_"):
					no_keys = false
				if ob.contains("목재 ") or ob.contains("석재 ") or ob.contains("보석 "):
					soft_all = false
				if str(q2.get("desc", "")).length() < 20 and str(q2.get("cat", "")) == "main":
					soft_all = false

			# ── ② 지도 마커: **하나뿐**이고, 고정한 퀘스트의 목적지를 짚는다
			var k_pick2 := GameData.tracked_pick
			GameData.tracked_pick = "story2"
			var guides2: Array = m.map_ui._quest_guides()
			var spot_ok: bool = guides2.size() == 1
			if spot_ok:
				var g0: Dictionary = guides2[0]
				var gt: Vector2i = g0.tile
				# 상점을 세울 자리를 가리키고, 라벨은 퀘스트 이름 하나뿐이다
				spot_ok = gt == m.VILLAGE_PLOTS["general"].anchor + Vector2i(2, 2) \
					and str(g0.text) == "마을을 깨우다" \
					and not str(g0.text).contains("(")
			# 다 지으면 그 자리는 더 이상 가리키지 않는다
			GameData.village_built.append("general")
			GameData.story2_phase = "farm_talk"
			var spot_gone := true
			for g2: Dictionary in m.map_ui._quest_guides():
				var gt2: Vector2i = g2.tile
				if gt2 == m.VILLAGE_PLOTS["general"].anchor + Vector2i(2, 2):
					spot_gone = false
			GameData.tracked_pick = k_pick2
			GameData.village_built = k_built4
			GameData.story2_phase = k_s2p
			GameData.story_phase = k_story

			# ── ③ 요리마다 배부름이 다르다
			var fill_all := true
			for rid: String in GameData.RECIPE_IDS:
				if GameData.recipe_fill(rid) <= 0.0:
					fill_all = false
			# 국밥은 든든하고 차는 기운만 돈다 — 체력 순서와 뒤집힌다
			var rice: float = GameData.recipe_fill("dish_bean_rice")
			var tea: float = GameData.recipe_fill("dish_moon_tea")
			var fill_diff: bool = rice > tea \
				and float(GameData.RECIPES["dish_bean_rice"].energy) \
					< float(GameData.RECIPES["dish_moon_tea"].energy) \
				and GameData.fill_word("dish_bean_rice") != GameData.fill_word("dish_moon_tea")
			# 실제로 먹어 본다 — 배부름은 요리표의 값만큼 오른다
			var k_open2 := GameData.hunger_open
			var k_hunger2 := GameData.hunger
			var k_energy2 := GameData.energy
			var k_potato := int(GameData.items["dish_baked_potato"])
			GameData.hunger_open = true
			GameData.hunger = 0.0
			GameData.energy = 10.0
			GameData.items["dish_baked_potato"] = 1
			var mult := GameData.cook_energy_mult()
			m.doing.do_eat("dish_baked_potato")
			var eat_ok: bool = is_equal_approx(GameData.hunger,
					GameData.recipe_fill("dish_baked_potato") * mult) \
				and GameData.energy > 10.0 and not GameData.starving()
			GameData.items["dish_baked_potato"] = k_potato
			GameData.hunger_open = k_open2
			GameData.hunger = k_hunger2
			GameData.energy = k_energy2
			m.hud._toast_queue.clear()
			print("QUESTTALE_OK=", tale_ok and obj_soft and no_keys and soft_all
				and spot_ok and spot_gone and fill_all and fill_diff and eat_ok,
				" 동화이야기=", tale_ok, " 감성목표=", obj_soft,
				" 키노출없음=", no_keys, " 재료수치없음=", soft_all,
				" 마커하나=", spot_ok, " 다지으면사라짐=", spot_gone,
				" 요리별배부름=", fill_all and fill_diff, " 먹기반영=", eat_ok,
				"(밥 ", rice, " · 차 ", tea, ")")
		294:
			# #144: 첫 해 축제 없음 · 미탐사 먹구름 · 민들레(필드/가방)
			m.dialog.close()
			m.map_ui.close()

			# ── ① 계절 축제는 첫 한 해 동안 하나도 열리지 않는다
			var k_day4 := GameData.day
			var year_days: int = GameData.DAYS_PER_SEASON * 4
			var fest1 := 0
			for d in range(1, year_days + 1):
				if not GameData.festival_of_day(d).is_empty():
					fest1 += 1
			var fest2 := 0
			for d2 in range(year_days + 1, year_days * 2 + 1):
				if not GameData.festival_of_day(d2).is_empty():
					fest2 += 1
			GameData.day = 14                     # 첫 해 봄 14일 = 옛 꽃놀이 날
			GameData.minutes = 11.0 * 60.0
			GameData.reset_festival_state()
			var quiet_ok: bool = GameData.festival_today().is_empty() \
				and not GameData.festival_open() and GameData.festival_line() == "" \
				and not GameData.fest_year_ok()
			GameData.day = year_days + 14         # 두 해째 같은 날
			GameData.reset_festival_state()
			var year2_ok: bool = not GameData.festival_today().is_empty() \
				and GameData.fest_year_ok()
			GameData.day = k_day4
			GameData.reset_festival_state()
			var fest_ok: bool = fest1 == 0 and fest2 == 4 and quiet_ok and year2_ok

			# ── ② 미탐사 지역은 먹구름이 덮는다 (검은 단색이 아니다)
			_fog_keep = GameData.explored.duplicate()
			GameData.explored = {}
			var hidden: bool = not m.map_ui._visible_tile(2, 2)
			var r_a: float = m.map_ui._cloud_rand(5, 7, 1)
			var r_b: float = m.map_ui._cloud_rand(5, 7, 1)
			var r_c: float = m.map_ui._cloud_rand(6, 7, 1)
			var fogc: Color = m.map_ui.FOG
			var cloud: Color = m.map_ui.CLOUD_MID
			var cloud_ok: bool = hidden \
				and is_equal_approx(r_a, r_b) and not is_equal_approx(r_a, r_c) \
				and r_a >= 0.0 and r_a <= 1.0 \
				and fogc.a >= 1.0 and cloud.a >= 1.0 \
				and fogc.v > 0.08 and cloud.v > fogc.v      # 구름이 바탕보다 밝다
			m.map_ui.open()                       # 화면은 다음 단계(295)에서 찍는다

			# ── ③ 민들레 — 산자락에 피고, 가방 아이콘은 따로다
			var fld: Texture2D = m.tex.get("forage_dandelion")
			var ico: Texture2D = m.tex.get("icon_forage_dandelion")
			var art_ok: bool = fld != null and ico != null and fld != ico \
				and fld.get_width() == 64 and ico.get_width() == 32 \
				and str(GameData.ITEMS["forage_dandelion"].name) == "민들레" \
				and "forage_dandelion" in GameData.FORAGE_IDS \
				and "forage_dandelion" in GameData.ITEM_IDS
			# 산자락에서만 돋는다 — 몇 번 돌려 보고 자리를 확인한다
			for pos0 in m.objects.keys():
				if String(m.objects[pos0].kind) == "forage_dandelion":
					m.objnode._remove_object(pos0)
			var dan_seen := 0
			var dan_low := 0
			for i in 120:
				# 다른 채집물이 상한을 채우면 새로 돋지 않는다 — 매번 비워 준다
				for p0 in m.objects.keys():
					var k0 := String(m.objects[p0].kind)
					if k0.begins_with("forage_") and k0 != "forage_dandelion":
						m.objnode._remove_object(p0)
				m.worldgen._respawn_forage()
			for pos1 in m.objects:
				if String(m.objects[pos1].kind) == "forage_dandelion":
					dan_seen += 1
					if pos1.y > m.MOUNTAIN_Y:
						dan_low += 1
			var spawn_ok: bool = dan_seen > 0 and dan_low == 0
			# 주우면 가방에 들어가고 도감에 오른다
			var k_dan := int(GameData.items["forage_dandelion"])
			var dpos := Vector2i(-1, -1)
			for pos2 in m.objects:
				if String(m.objects[pos2].kind) == "forage_dandelion":
					dpos = pos2
					break
			var pick_ok := false
			if dpos.x >= 0:
				_saved_pos = m.player.position
				m.player.position = Vector2(dpos.x * m.TILE + 16, (dpos.y + 1) * m.TILE + 16)
				m._target_override = dpos
				m.actions.interact()
				m._target_override = Vector2i(-999, -999)
				m.player.position = _saved_pos
				pick_ok = int(GameData.items["forage_dandelion"]) > k_dan \
					and GameData.discovered.has("forage_dandelion")
			# 가방 아이콘은 「icon_」 그림을 쓴다 (필드 그림과 다르다)
			var bag_icon := ""
			for e: Dictionary in m.inventory_ui._item_entries():
				if str(e.get("name", "")) == "민들레":
					bag_icon = str(e.get("icon", ""))
			GameData.items["forage_dandelion"] = k_dan
			m.hud._toast_queue.clear()
			print("SEASONFOG_OK=", fest_ok and cloud_ok and art_ok and spawn_ok
				and pick_ok and bag_icon == "icon_forage_dandelion",
				" 첫해축제0=", fest1 == 0, " 두해째4회=", fest2 == 4,
				" 축제안열림=", quiet_ok, " 두해째열림=", year2_ok,
				" 먹구름=", cloud_ok, " 민들레아트=", art_ok,
				" 산자락스폰=", spawn_ok, "(", dan_seen, "포기)",
				" 채집=", pick_ok, " 가방아이콘=", bag_icon)
		295:
			_save_shot("_mapfog.png")             # 먹구름이 덮인 지도
			m.map_ui.close()
			GameData.explored = _fog_keep
		296:
			# #145: 지도 마커 하나 · 짧은 목표와 괄호 제거 · 안개 · 돌문 새 자리
			m.dialog.close()
			m.map_ui.close()

			# ── ① 마커는 언제나 하나, 고정한 퀘스트를 가리킨다
			var k_pick3 := GameData.tracked_pick
			var k_s18c := GameData.story18_phase
			GameData.story18_phase = "hill"
			GameData.tracked_pick = "story18"
			var gs: Array = m.map_ui._quest_guides()
			var one_ok: bool = gs.size() == 1
			if one_ok:
				var g1: Dictionary = gs[0]
				var t1: Vector2i = g1.tile
				one_ok = t1 == m.HILL_POS and str(g1.text) == "할머니의 시계"
			# 다른 퀘스트를 고정하면 그쪽 하나만 뜬다
			var k_s2c := GameData.story2_phase
			var k_builtc: Array = GameData.village_built.duplicate()
			GameData.story2_phase = "shop"
			GameData.village_built.erase("general")
			GameData.tracked_pick = "story2"
			var gs2: Array = m.map_ui._quest_guides()
			var swap_ok: bool = gs2.size() == 1
			if swap_ok:
				var g2: Dictionary = gs2[0]
				var t2: Vector2i = g2.tile
				swap_ok = t2 == m.VILLAGE_PLOTS["general"].anchor + Vector2i(2, 2)
			GameData.village_built = k_builtc
			GameData.story2_phase = k_s2c
			GameData.story18_phase = k_s18c
			GameData.tracked_pick = k_pick3

			# ── ② 목표는 짧고, 괄호도 조작키 안내도 없다
			var checks: Array = [
				["story2_phase", ["shop", "farm_talk"], "story2_objective_short"],
				["fisher_home", ["wait", "build", "built"], "fisher_home_objective_short"],
				["move_quest", ["show", "wait", "greet", "seed", "seedrep",
					"post", "postbuild", "postgreet"], "move_objective_short"],
				["kitchen_quest", ["broom", "make", "sweep", "found", "jam"],
					"kitchen_quest_objective_short"],
				["fisher_quest", ["meet", "follow", "open"], "fisher_objective_short"],
				["forest_quest", ["arrive", "found", "ask", "go", "back"],
					"forest_objective_short"],
				["story6_phase", ["show_chief", "ask_post", "wait", "visit", "told",
					"build"], "story6_objective_short"],
				["story7_phase", ["worry", "lore", "gather"], "story7_objective_short"],
				["story9_phase", ["ask", "invite", "build"], "story9_objective_short"],
				["story18_phase", ["memo", "clue", "hill", "box", "tale"],
					"story18_objective_short"],
				["story20_phase", ["tell", "gate", "inner", "letter", "plant"],
					"story20_objective_short"],
			]
			var clean := true
			var longest := 0
			var worst := ""
			for row: Array in checks:
				var prop := str(row[0])
				var keep: Variant = GameData.get(prop)
				for v: String in row[1]:
					GameData.set(prop, v)
					var txt := str(GameData.call(str(row[2])))
					if txt == "" or txt.contains("(") or txt.contains(")") \
							or txt.contains("E:") or txt.contains("(E)"):
						clean = false
					if txt.length() > longest:
						longest = txt.length()
						worst = txt
				GameData.set(prop, keep)
			var short_ok: bool = clean and longest <= 40
			# 안내(튜토리얼) 목표도 같은 규칙
			for k: String in GameData.TUTORIAL_SHORT:
				var tv := str(GameData.TUTORIAL_SHORT[k])
				if tv.contains("(") or tv.contains("%") or tv.length() > 20:
					short_ok = false
			# 세계에 뜨는 상호작용 안내에도 「E:」가 없다
			var prompt_ok := true
			_saved_pos = m.player.position
			for pk: String in ["board", "cave", "tree", "rock"]:
				var pt3 := Vector2i(30, 40)
				m.objnode._remove_object(pt3)
				m.objects[pt3] = {"kind": pk, "hp": 3}
				m._target_override = pt3
				var pr: Array = m.renderer._context_hint()
				m._target_override = Vector2i(-999, -999)
				m.objects.erase(pt3)
				if pr.size() > 0 and (str(pr[0]).contains("E:") or str(pr[0]).contains("(")):
					prompt_ok = false
			m.player.position = _saved_pos

			# ── ③ 안개: 처음에는 거의 다 가려져 있고, 걸을수록 넓어진다
			_fog_keep = GameData.explored.duplicate()
			GameData.explored = {}
			GameData.mark_explored_at(m.START_TILE)
			var seen1 := 0
			for y1 in m.MAP_H:
				for x1 in m.MAP_W:
					if m.map_ui._visible_tile(x1, y1):
						seen1 += 1
			var ratio := float(seen1) / float(m.MAP_W * m.MAP_H)
			GameData.mark_explored_at(m.START_TILE + Vector2i(24, 12))
			var seen2 := 0
			for y2 in m.MAP_H:
				for x2 in m.MAP_W:
					if m.map_ui._visible_tile(x2, y2):
						seen2 += 1
			var fog_ok: bool = GameData.EXPLORE_CHUNK == 4 \
				and seen1 > 0 and ratio < 0.02 and seen2 > seen1
			GameData.explored = _fog_keep

			# ── ④ 스토리 20의 문은 이제 동굴 입구가 가리킨다 (돌문 오브젝트 없음)
			var k_s20d := GameData.story20_phase
			var k_pick20 := GameData.tracked_pick
			GameData.story20_phase = "gate"
			GameData.tracked_pick = "story20"
			var gs20: Array = m.map_ui._quest_guides()
			var gate_hid: bool = gs20.size() == 1
			if gate_hid:
				var g20: Dictionary = gs20[0]
				var t20: Vector2i = g20.tile
				gate_hid = t20 == m.CAVE_POS
			var gate_18 := true
			for gt2: Vector2i in m.objects:
				if str(m.objects[gt2].get("kind", "")) == "old_gate":
					gate_18 = false
			GameData.story20_phase = k_s20d
			GameData.tracked_pick = k_pick20
			# 미니 트래커와 Q창이 같은 퀘스트를 본다
			var far_ok := true
			for pk: String in ["", "story2", "plot3"]:
				var k_pk := GameData.tracked_pick
				GameData.tracked_pick = pk
				var tq_h: Dictionary = GameData.tracked_quest()
				var lst: Array = GameData.quest_list()
				var found := false
				for q_h: Dictionary in lst:
					if str(q_h.get("id", "")) == str(tq_h.get("id", "")):
						found = true
				if not tq_h.is_empty() and not found:
					far_ok = false
				GameData.tracked_pick = k_pk
			m.hud._toast_queue.clear()
			print("QUESTUI_OK=", one_ok and swap_ok and short_ok and prompt_ok
				and fog_ok and gate_hid and gate_18 and far_ok,
				" 마커하나=", one_ok, " 고정따라감=", swap_ok,
				" 짧은목표=", short_ok, "(최장 ", longest, "자: ", worst, ")",
				" 상호작용안내=", prompt_ok,
				" 안개=", fog_ok, "(처음 ", "%.1f" % (ratio * 100.0), "%)",
				" 20장마커=동굴 ", gate_hid, " 돌문없음=", gate_18,
				" 트래커일치=", far_ok)
		297:
			# #146: 제4장 집터 서브퀘 · 우체국 편지·보관함 · 고가치 경제
			m.dialog.close()

			# ── ① 스토리 4가 끝나면 이장이 집터 셋을 부탁한다
			var k_s4e := GameData.story4_phase
			var k_zones: Array = GameData.zones_open.duplicate()
			var k_p3q := GameData.plot3_quest
			var k_p3n := GameData.plot3_made
			GameData.story4_phase = "ask"
			GameData.plot3_quest = ""
			GameData.plot3_made = 0
			m.story._end_story4()
			var p3_start: bool = GameData.plot3_quest == "make" \
				and GameData.plot3_made == 0
			var obj3 := GameData.plot3_objective_short()
			var p3_obj: bool = obj3.contains("0/%d" % GameData.PLOT3_GOAL) \
				and not obj3.contains("(") and obj3.length() <= 20
			# Q창에도 서브 퀘스트로 오른다
			var p3_cat := false
			for q3: Dictionary in GameData.quest_catalog():
				if str(q3.id) == "plot3":
					p3_cat = str(q3.cat) == "sub" and str(q3.npc) == "chief"
			# 집터를 셋 놓으면 보고 단계로 넘어간다
			for i3 in GameData.PLOT3_GOAL:
				GameData.plot3_add()
			var p3_ready: bool = GameData.plot3_quest == "report" \
				and GameData.plot3_objective_short() == "이장에게 알리자."
			# 다른 ❗가 없을 때만 이장 머리 위에 ? 가 뜬다
			var k_mvq := GameData.move_quest
			GameData.move_quest = ""
			var p3_mark: bool = GameData.quest_npc_marks().get("chief", "") == "?"
			GameData.move_quest = k_mvq
			var money_p3 := GameData.money
			var wood_p3 := GameData.wood
			var stone_p3 := GameData.stone
			m.story.open_plot3_dialog()
			var p3_talk: bool = m.dialog.visible
			m.dialog.skip_seq()
			m.dialog.close()
			var p3_done: bool = GameData.plot3_quest == "done" \
				and GameData.money == money_p3 + GameData.PLOT3_MONEY \
				and GameData.wood == wood_p3 + GameData.PLOT3_WOOD \
				and GameData.stone == stone_p3 + GameData.PLOT3_STONE \
				and GameData.plot3_objective_short() == ""
			GameData.money = money_p3
			GameData.wood = wood_p3
			GameData.stone = stone_p3
			GameData.plot3_quest = k_p3q
			GameData.plot3_made = k_p3n
			GameData.story4_phase = k_s4e
			GameData.zones_open = k_zones

			# ── ② 우체국 — 계산대가 편지 창을 연다
			var post_act: bool = str(m.shop_room.ROOMS["post"].get("action", "")) \
				== "mail"
			var k_mbox: Array = GameData.mail_box.duplicate()
			var k_mout: Array = GameData.mail_out.duplicate()
			var k_msent := GameData.mail_sent_day
			var k_money_m := GameData.money
			var k_built_m: Array = GameData.village_built.duplicate()
			if not GameData.village_built.has("post"):
				GameData.village_built.append("post")
			GameData.mail_box = []
			GameData.mail_out = []
			GameData.mail_sent_day = 0
			GameData.money = 5000
			m.village.room_action("mail")
			var mail_ui: bool = m.dialog.visible and GameData.mail_open()
			m.dialog.close()
			# 부치기 — 값을 치르고, 하루 한 통
			var aff_m := int(GameData.affinity.get("chief", 0))
			m.village._send_mail("chief")
			var sent_ok: bool = GameData.money == 5000 - GameData.MAIL_SEND_COST \
				and GameData.mail_out.size() == 1 \
				and GameData.mail_sent_today() \
				and GameData.mail_box.size() == 1
			m.dialog.close()
			var money_after := GameData.money
			m.village._send_mail("chief")
			var once_ok: bool = GameData.money == money_after \
				and GameData.mail_out.size() == 1
			m.dialog.close()
			# 다음 날 아침 — 답장이 보관함에 닿고 호감도가 오른다
			GameData.day += 1
			var replies_h: Array = GameData.mail_new_day()
			var reply_ok: bool = replies_h.size() == 1 \
				and GameData.mail_out.is_empty() \
				and GameData.mail_box.size() == 2 \
				and int(GameData.affinity.get("chief", 0)) \
					== aff_m + GameData.MAIL_REPLY_AFF
			GameData.day -= 1
			# 가방에서 읽은 편지가 저절로 보관함으로 옮겨진다
			var k_fare := int(GameData.items.get("farewell_letter", 0))
			var k_lastf := GameData.last_farewell
			GameData.items["farewell_letter"] = 1
			GameData.last_farewell = "무진"
			m.story.open_farewell_letter()
			m.dialog.close()
			var keep_ok: bool = GameData.mail_box.size() == 3 \
				and int(GameData.items["farewell_letter"]) == 0 \
				and str(GameData.mail_box[2].title).contains("무진")
			GameData.items["farewell_letter"] = k_fare
			GameData.last_farewell = k_lastf
			# 보관함을 열면 편지가 줄지어 보인다
			m.village._open_mail_box(0)
			var box_ui: bool = m.dialog.visible
			m.village._read_mail(0, 0)
			var read_ui: bool = m.dialog.visible
			m.dialog.close()
			GameData.mail_box = k_mbox
			GameData.mail_out = k_mout
			GameData.mail_sent_day = k_msent
			GameData.money = k_money_m
			GameData.village_built = k_built_m
			GameData.affinity["chief"] = aff_m

			# ── ③ 고가치 경제 — 벌이는 얇아지고 돈은 무거워진다
			var econ_ok: bool = GameData.START_MONEY <= 200 \
				and GameData.MAIL_SEND_COST >= 100
			var thin := 0
			for cid: String in GameData.CROPS:
				var cdef: Dictionary = GameData.CROPS[cid]
				var sell_c := int(cdef.sell_price)
				var seed_c := int(cdef.seed_price)
				# 심으면 남아야 하고, 그 남는 몫이 씨앗값을 넘지 않는다
				if sell_c <= seed_c or sell_c - seed_c > seed_c:
					econ_ok = false
				if sell_c <= 100:
					thin += 1
			# 대부분의 작물이 한 알에 100G를 넘지 않는다 (넘는 것은 긴 계절작물뿐)
			if thin < GameData.CROPS.size() - 8:
				econ_ok = false
			# 의뢰 보상·도감·상점이 모두 같은 표를 본다
			if GameData.item_value("egg") != int(GameData.ITEMS["egg"].sell) \
					or GameData.item_value("wheat") \
						!= int(GameData.CROPS["wheat"].sell_price):
				econ_ok = false
			print("MAILPLOT_OK=", p3_start and p3_obj and p3_cat and p3_ready
				and p3_mark and p3_talk and p3_done and post_act and mail_ui
				and sent_ok and once_ok and reply_ok and keep_ok and box_ui
				and read_ui and econ_ok,
				" 4장부탁=", p3_start, " 짧은목표=", p3_obj, " Q창=", p3_cat,
				" 셋완료=", p3_ready, " 이장물음표=", p3_mark,
				" 보고=", p3_talk and p3_done,
				" 우체국창=", post_act and mail_ui, " 발송=", sent_ok,
				" 하루한통=", once_ok, " 답장=", reply_ok,
				" 수락편지보관=", keep_ok, " 보관함열람=", box_ui and read_ui,
				" 경제=", econ_ok)
		298:
			# #147: 밭 갈기 안내는 바다 해금 뒤 · 용식 첫 만남 대사 분리
			m.dialog.close()

			# ── ① 호미 안내는 이장이 호미를 준 뒤에만 뜬다
			var k_s2f := GameData.story2_phase
			var k_tut: Dictionary = GameData.tutorial.duplicate()
			var k_guide := GameData.guide_active
			GameData.tutorial = GameData.fresh_tutorial()
			GameData.tutorial["active"] = true
			GameData.guide_active = false
			var order_ok := true
			var many := false
			for ph2: String in ["shop", "fisher", "farm_talk"]:
				GameData.story2_phase = ph2
				if GameData.tutorial_current_flag() != "":
					order_ok = false          # 앞선 퀘스트와 나란히 뜨면 안 된다
				# 그 사이 목록에 뜨는 퀘스트는 많아야 하나(메인 이야기)다
				var lst2: Array = GameData.quest_list()
				var mains := 0
				for q2: Dictionary in lst2:
					if str(q2.get("cat", "")) == "main":
						mains += 1
				if mains > 1:
					many = true
			GameData.story2_phase = "farm"
			var farm_on: bool = GameData.farm_chain_open() \
				and GameData.tutorial_current_flag() == "till"
			GameData.story2_phase = k_s2f
			GameData.tutorial = k_tut
			GameData.guide_active = k_guide

			# ── ② 용식 첫 만남 — 황금잉어와 바다 이야기만
			var k_fq := GameData.fisher_quest
			var k_fh := GameData.fisher_home
			GameData.fisher_quest = "meet"
			m.story._start_fisher_dialog()
			var meet_txt := ""
			for e4: Dictionary in m.dialog._seq:
				meet_txt += str(e4.get("text", "")) + " "
			var meet_ok: bool = meet_txt.contains("황금잉어") \
				and meet_txt.contains("바다") \
				and not meet_txt.contains("눌러앉") \
				and not meet_txt.contains("집을") \
				and not meet_txt.contains("*")
			m.dialog.close()
			# 「눌러앉을 집」 이야기는 사흘 뒤 분수대 앞 서브퀘에서만
			GameData.fisher_home = "wait"
			m.story._start_fisher_home_dialog()
			var home_txt := ""
			for e5: Dictionary in m.dialog._seq:
				home_txt += str(e5.get("text", "")) + " "
			var home_ok: bool = home_txt.contains("눌러앉") \
				and home_txt.contains("집")
			m.dialog.close()
			GameData.fisher_quest = k_fq
			GameData.fisher_home = k_fh
			m.hud._toast_queue.clear()
			print("ORDER_OK=", order_ok and not many and farm_on and meet_ok
				and home_ok,
				" 바다전밭안내없음=", order_ok, " 동시노출없음=", not many,
				" 호미후시작=", farm_on, " 첫만남=", meet_ok, " 집부탁분리=", home_ok)
		299:
			# #148: 영업시간·강제 퇴장 · 상점 레시피 선반 · 갇힘 구조 · 지도
			m.dialog.close()
			var k_min9 := GameData.minutes

			# ── ① 영업시간 9~18시, 점심 12~13시
			var hours_ok := true
			for row: Array in [[8.0, false, "early"], [9.0, true, ""],
					[11.5, true, ""], [12.0, false, "lunch"],
					[12.9, false, "lunch"], [13.0, true, ""],
					[17.9, true, ""], [18.0, false, "late"], [22.0, false, "late"]]:
				GameData.minutes = float(row[0]) * 60.0
				if GameData.shop_open_now() != bool(row[1]) \
						or GameData.shop_closed_why() != str(row[2]):
					hours_ok = false

			# ── ② 문 닫을 시각이 되면 주인이 손님을 내보낸다
			GameData.minutes = 10.0 * 60.0
			m.shop_room.open("general")
			var in_room: bool = m.shop_room.visible
			# 안내는 방 안에 적히고, 말풍선은 걷힌다
			m.hud.show_message("검사용 말풍선", 9.0)
			m.hud._process(0.016)
			var bub_gone: bool = m.hud._bub == null or not m.hud._bub.visible
			var notice_ok: bool = m.shop_room.notice != ""
			GameData.minutes = 18.0 * 60.0
			m.shop_room._closing_tick(0.016)
			var kick_talk: bool = m.dialog.visible
			var kick_txt := ""
			for e9: Dictionary in m.dialog._seq:
				kick_txt += str(e9.get("text", "")) + " "
			var kick_word: bool = kick_txt.contains("문 닫을 시간") \
				and kick_txt.contains("내일 다시")
			m.dialog.skip_seq()
			m.dialog.close()
			var kicked_out: bool = not m.shop_room.visible
			# 영업시간 밖에는 아예 들어가지 못한다
			var closed_msg: bool = m.shop_room.closed_text("lunch").contains("점심") \
				and m.shop_room.closed_text("late") != "" \
				and m.shop_room.closed_text("early") != ""
			GameData.minutes = k_min9

			# ── ③ 상점 선반: 「도구」는 없고 「레시피」가 그 자리에 있다
			var shelf_ok := true
			var has_recipe := false
			for sh: Array in m.shop_room.SHELVES:
				if str(sh[0]) == "tool":
					shelf_ok = false
				if str(sh[0]) == "recipe":
					has_recipe = true
			shelf_ok = shelf_ok and has_recipe \
				and "dish_berry_jam" not in GameData.SHOP_FOOD_IDS \
				and not GameData.SHOP_FOOD_RECIPES.has("dish_berry_jam")
			# 산딸기잼 레시피는 용식의 집터 보상으로 들어온다
			var k_fh9 := GameData.fisher_home
			var k_ri9: Dictionary = GameData.recipe_items.duplicate()
			var k_ru9: Array = GameData.recipes_unlocked.duplicate()
			GameData.recipe_items.erase(GameData.JAM_ID)
			GameData.recipes_unlocked.erase(GameData.JAM_ID)
			GameData.fisher_home = "built"
			m.story._end_fisher_home_reward()
			var jam_reward: bool = not GameData.recipe_locked(GameData.JAM_ID) \
				or GameData.recipe_items.has(GameData.JAM_ID)
			GameData.fisher_home = k_fh9
			GameData.recipe_items = k_ri9
			GameData.recipes_unlocked = k_ru9

			# ── ④ 갇힘 구조 — 잠긴 구역 한가운데 두면 성한 땅으로 나온다
			var k_zones9: Array = GameData.zones_open.duplicate()
			var k_pos9 := m.player.position
			var zid9: String = str(GameData.ZONE_ORDER[0])
			GameData.zones_open.erase(zid9)
			var zr9: Rect2i = GameData.VILLAGE_ZONES[zid9].rect
			var mid9: Vector2i = zr9.position + zr9.size / 2
			m.player.position = Vector2(mid9.x * m.TILE + 16, mid9.y * m.TILE + 16)
			var was_trapped: bool = not m.is_passable(m.player_tile())
			m.rescue_trapped()
			var rescued: bool = m.is_passable(m.player_tile())
			GameData.zones_open = k_zones9
			m.player.position = k_pos9
			# 맵 밖으로 밀려나도 되돌아온다
			m.player.position = Vector2(-400.0, -400.0)
			m.rescue_trapped()
			var back_in: bool = m.is_passable(m.player_tile())
			m.player.position = k_pos9

			# ── ⑤ 지도 — 더 넓게 쓰고, 미탐사 칸은 밑이 비치지 않는다
			var map_big: bool = m.map_ui.VIEW_W >= 940.0 \
				and m.map_ui.VIEW_H >= 505.0 and m.map_ui.ZOOM_MAX >= 6.0
			var k_expl9: Dictionary = GameData.explored.duplicate()
			GameData.explored = {}
			GameData.mark_explored_at(m.START_TILE)
			var far9 := Vector2i(m.MAP_W - 3, m.MAP_H - 3)
			var fog_block: bool = not m.map_ui._visible_tile(far9.x, far9.y) \
				and m.map_ui.FOG.a >= 1.0 and m.map_ui.CLOUD_MID.a >= 1.0
			GameData.explored = k_expl9
			m.hud._toast_queue.clear()
			print("SHOPTIME_OK=", hours_ok and in_room and bub_gone and notice_ok
				and kick_talk and kick_word and kicked_out and closed_msg
				and shelf_ok and jam_reward and was_trapped and rescued
				and back_in and map_big and fog_block,
				" 영업시간=", hours_ok, " 말풍선치움=", bub_gone,
				" 방안안내=", notice_ok, " 퇴장대사=", kick_talk and kick_word,
				" 밖으로=", kicked_out, " 닫힘안내=", closed_msg,
				" 레시피선반=", shelf_ok, " 잼=용식보상 ", jam_reward,
				" 갇힘=", was_trapped, " 구조=", rescued, " 맵밖복귀=", back_in,
				" 지도확장=", map_big, " 구름차단=", fog_block)
		394:
			# #149: 집터 재료 · 더딘 성장과 잠자리 결산 · 채집 문구 · 대사 기호 ·
			# 제작 문구 · 무지개송어 · 낚시 보상 · 바닷길 막힘
			m.dialog.close()

			# ── ① 집터는 초반 재료만으로 만든다 (못은 대장간이 서야 산다)
			var kit_cost: Dictionary = GameData.DESK_RECIPES["housing_kit"].cost
			var kit_ok := not kit_cost.has("nail")
			for mk: String in kit_cost:
				if mk not in ["wood", "stone"]:
					kit_ok = false

			# ── ② 성장은 더디고, 소식은 잠자리에서
			var slow_ok: bool = GameData.skill_xp_needed(1) >= 190.0 \
				and GameData.skill_xp_needed(3) >= 800.0
			var k_sk: Dictionary = GameData.skills["forest"].duplicate()
			GameData.levelup_pending = []
			GameData.skills["forest"].lv = 1
			GameData.skills["forest"].xp = 0.0
			m.toolwork.gain_skill("forest", 3.0)
			var no_lv_yet: bool = GameData.skills["forest"].lv == 1
			m.toolwork.gain_skill("forest", GameData.skill_xp_needed(1) * 3.0)
			var leveled: bool = GameData.skills["forest"].lv >= 2 \
				and not GameData.levelup_pending.is_empty()
			var report := GameData.levelup_report()
			var report_ok: bool = report.contains("Lv.") \
				and GameData.levelup_pending.is_empty()
			GameData.skills["forest"] = k_sk

			# ── ③ 채집 문구에는 개수가 없다
			var k_pos0 := m.player.position
			var ct := Vector2i(24, 40)
			for cy in range(ct.y - 2, ct.y + 3):
				for cx in range(ct.x - 2, ct.x + 3):
					m.objnode._remove_object(Vector2i(cx, cy))
			m.player.position = Vector2(ct.x * m.TILE + 16, ct.y * m.TILE + 16)
			m.player.dir = "right"
			var wt := ct + Vector2i(1, 0)
			m.objects[wt] = {"kind": "tree", "hp": 1}
			m.objnode._spawn_object_node(wt, "tree")
			m.toolwork.set_tool("axe")
			m._target_override = wt
			m.toolwork.use_tool()
			m._target_override = Vector2i(-999, -999)
			var chop_msg: String = m.hud._bub_label.text if m.hud._bub_label != null else ""
			var no_count: bool = chop_msg.contains("얻었다")
			for dch in "0123456789":
				if chop_msg.contains(dch):
					no_count = false
			m.objnode._remove_object(wt)
			m.player.position = k_pos0
			m.hud.hide_bubble()

			# ── ④ 사람이 하는 말에는 부호가 넷뿐이다
			m.dialog.open_seq("검사", null, [
				{"text": "「이건 정말 대단하구먼 — 별표★도 하트♥도 다 지운다…」"},
				{"text": "「그런데 말이야, 정말 그럴까? 물론이지!」"},
			])
			var punct_ok := true
			var kept_ok := false
			for e0: Dictionary in m.dialog._seq:
				var b0 := str(e0.get("text", ""))
				for bad: String in ["「", "」", "★", "♥", "—", "…", "·", "『"]:
					if b0.contains(bad):
						punct_ok = false
				if b0.contains("?") and b0.contains("!") and b0.contains(","):
					kept_ok = true
			m.dialog.close()

			# ── ⑤ 제작 문구 — 만든 것의 이름으로 알려 준다
			GameData.desk_done_pending.append("빗자루")
			m.hud._process(0.016)
			var made_ok := false
			for t0: Dictionary in m.hud._toast_queue:
				if str(t0.get("body", "")).contains("빗자루를 만들었다"):
					made_ok = true
			m.hud._toast_queue.clear()

			# ── ⑥ 무지개송어 그림
			var rb: Texture2D = m.tex.get("fish_rainbow")
			var art_ok: bool = rb != null and rb.get_width() == 32 \
				and rb.get_height() == 32

			# ── ⑦ 낚시는 돈을 주지 않는다
			var fish_free: bool = not GameData.TUTORIAL_REWARDS["fish"].has("money")
			var k_money0 := GameData.money
			var k_fishcnt: Dictionary = GameData.fish_caught.duplicate()
			GameData.items["fish_rainbow"] = int(GameData.items.get("fish_rainbow", 0))
			m.pending_fish = {"id": "fish_rainbow"}
			m.fishing._on_fishing_finished(true)
			fish_free = fish_free and GameData.money == k_money0
			var catch_msg: String = m.hud._bub_label.text if m.hud._bub_label != null else ""
			fish_free = fish_free and not catch_msg.contains("G")
			GameData.fish_caught = k_fishcnt
			GameData.money = k_money0
			m.hud.hide_bubble()

			# ── ⑧ 한 번 연 바닷길은 다시 막히지 않는다
			var k_sea := GameData.sea_open
			var k_fq0 := GameData.fisher_quest
			GameData.sea_open = true
			GameData.fisher_quest = "done"
			var gate0: Vector2i = m.SEA_GATE[0]
			m.objects[gate0] = {"kind": "bigrock", "hp": m.BIGROCK_HP, "fixed": true}
			m.worldgen._build_sea()
			var gate_clear2: bool = not m.objects.has(gate0)
			# 어쩌다 남아 있어도 곡괭이로 캘 수 있다
			m.objects[gate0] = {"kind": "bigrock", "hp": 1, "fixed": true}
			m.objnode._spawn_object_node(gate0, "bigrock")
			m.player.position = Vector2(gate0.x * m.TILE + 16,
				(gate0.y - 1) * m.TILE + 16)
			m.player.dir = "down"
			m.toolwork.set_tool("pickaxe")
			m._target_override = gate0
			m.toolwork.use_tool()
			m._target_override = Vector2i(-999, -999)
			var gate_mined: bool = not m.objects.has(gate0)
			m.objnode._remove_object(gate0)
			# 자연 리젠도 길목에는 놓이지 않는다
			var no_regen: bool = not m.worldgen._respawn_ok(gate0, "rock") \
				and not m.worldgen._respawn_ok(m.SEA_GATE[1], "tree")
			GameData.sea_open = k_sea
			GameData.fisher_quest = k_fq0
			m.player.position = k_pos0
			m.hud.hide_bubble()
			m.hud._toast_queue.clear()
			print("BALANCE_OK=", kit_ok and slow_ok and no_lv_yet and leveled
				and report_ok and no_count and punct_ok and kept_ok and made_ok
				and art_ok and fish_free and gate_clear2 and gate_mined and no_regen,
				" 집터재료=", kit_ok, " 더딘성장=", slow_ok,
				" 즉시알림없음=", no_lv_yet, " 잠자리결산=", leveled and report_ok,
				" 채집문구=", no_count, "(", chop_msg, ")",
				" 대사부호=", punct_ok and kept_ok, " 제작문구=", made_ok,
				" 무지개송어=", art_ok, " 낚시무보수=", fish_free,
				" 길목비움=", gate_clear2, " 곡괭이채굴=", gate_mined,
				" 리젠제외=", no_regen)
		291:
			# 새 제작대 창을 한 장 남긴다 (289에서 열어 둔 것)
			_save_shot("_desk.png")
			m.desk_ui.close()
			GameData.recipes_unlocked = _desk_keep
		270:
			# 나무 쓰러지는 모션.
			# 판정(목재·경험치)은 도끼를 휘두르는 **즉시**, 그림은 날이 닿는
			# 순간(HIT_AT)부터 움직인다. 밑동을 축으로 반동 -> 가속 -> 착지.
			var fd := Vector2i(24, 34)
			for cy in range(fd.y - 4, fd.y + 5):
				for cx in range(fd.x - 4, fd.x + 5):
					m.objnode._remove_object(Vector2i(cx, cy))
			m.objnode._clear_tree_falls()
			_saved_pos = m.player.position
			m.player.position = Vector2(fd.x * m.TILE + 16, fd.y * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m.player.dir = "right"
			m.toolwork.set_tool("axe")
			var ft2 := fd + Vector2i(1, 0)
			m.objects[ft2] = {"kind": "tree", "hp": 1}
			m.objnode._spawn_object_node(ft2, "tree")
			m.objnode._refresh_tree_sprite(ft2)
			var fspr: Sprite2D = m.obj_nodes[ft2].get_child(0)
			var wood0: int = GameData.wood
			var parts0: int = m.particles.size()
			m._pending_hits.clear()
			m._target_override = ft2
			m.toolwork.use_tool()                        # 마지막 한 방
			m._target_override = Vector2i(-999, -999)
			# 판정은 벌써 끝났는데 그림은 아직 서 있어야 한다
			var fell_now: bool = not m.objects.has(ft2) \
				and GameData.wood > wood0 and m._tree_falls.size() == 1
			m.objnode._update_tree_fall(m.HIT_AT * 0.5)
			print("FELL_START_OK=", fell_now and is_equal_approx(fspr.rotation, 0.0),
				" 목재+", GameData.wood - wood0,
				" 날 닿기 전 각=", "%.2f" % fspr.rotation)
			# 날이 닿은 뒤: 반동으로 되젖혔다가 반대쪽으로 넘어간다
			var lean := 0.0
			for i in 50:
				m.objnode._update_tree_fall(0.02)
				lean = minf(lean, fspr.rotation)
			var fall: Dictionary = m._tree_falls[0]
			var pv: Vector2 = fall.pivot
			var top0 := Vector2(m.TILE / 2.0, fspr.offset.y * fspr.scale.y)
			var top_now: Vector2 = fspr.position + top0.rotated(fspr.rotation)
			# 도끼질한 사람 반대쪽(오른쪽)으로 넘어간다 = 각도도 우듬지도 +쪽
			print("FELL_DOWN_OK=", fspr.rotation > 1.4 and lean < -0.05
					and top_now.x - top0.x > 100.0,
				" 각=", "%.2f" % fspr.rotation, " 반동=", "%.2f" % lean,
				" 우듬지 x이동=", int(top_now.x - top0.x))
			# 밑동은 제자리에 붙어 있고, 착지에 흙먼지·잎이 인다
			var pv_now: Vector2 = fspr.position + pv.rotated(fspr.rotation)
			print("FELL_PIVOT_OK=", pv_now.distance_to(pv) < 0.5
					and is_instance_valid(fall.stump) and m.particles.size() > parts0,
				" 밑동 어긋남=", "%.2f" % pv_now.distance_to(pv),
				" 그루터기=", is_instance_valid(fall.stump),
				" 파편=", m.particles.size() - parts0)
		272:
			# 화면용: 세 그루를 각각 다른 박자로 세워 반동·기울기·착지를 한 컷에 담는다.
			# 자세를 잡은 뒤 `wait`을 크게 줘서 그대로 얼려 둔다 — 안 그러면
			# 찍을 때까지 흐른 프레임만큼 자세가 밀린다.
			#
			# ※ 389 이후 번호로는 화면을 찍을 수 없다. 389의 성능 측정 루프가
			#    `m._process`를 스무 번 돌려 하네스를 그만큼 밀어 버리는데,
			#    그 사이에는 프레임이 그려지지 않아 화면이 안 바뀐다.
			m.dialog.close()
			m.objnode._clear_tree_falls()
			m.float_texts.clear()
			m.particles.clear()
			var fx := 21
			var poses := [0.26, 0.48, 0.72]     # 반동 / 넘어가는 중 / 착지 직후
			for i in poses.size():
				var pt := Vector2i(fx + i * 4, 34)
				for cy in range(pt.y - 4, pt.y + 4):
					for cx in range(pt.x - 2, pt.x + 3):
						m.objnode._remove_object(Vector2i(cx, cy))
				# 잎이 붙은 채로 넘어가는 쪽을 찍는다 (도끼를 올리면 한 방에 이렇게 된다)
				m.objects[pt] = {"kind": "tree", "hp": m.TREE_HP}
				m.objnode._spawn_object_node(pt, "tree")
				m.objnode._refresh_tree_sprite(pt)
				m.objnode._fell_tree(pt, 1.0)
				var f2: Dictionary = m._tree_falls[i]
				f2.wait = 0.0
				f2.t = float(poses[i])
			m.player.position = Vector2((fx + 4) * m.TILE + 16, 37 * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m.player.dir = "up"
			m.objnode._update_tree_fall(0.0)   # 잡은 자세를 한 번 그린 뒤
			for f3 in m._tree_falls:
				f3.wait = 999.0                # 그대로 얼린다
			m._cam_shake = 0.0                 # 착지 흔들림에 화면이 밀리지 않게
		274:
			_save_shot("_fell.png")
			m.objnode._clear_tree_falls()
			# 뒤 단계(말 사기)는 지금 서 있는 칸을 기준으로 삼는다 — 자리를 돌려준다
			m.player.position = _saved_pos
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
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
			# 조합법 드랍: 아주 드물게만 나온다.
			# ① 낡은 도구(1단계)의 확률이 좋은 도구보다 확실히 낮고
			# ② 초반 확률이 1%도 안 되며
			# ③ 그래도 오래 캐다 보면 언젠가는 나온다
			GameData.alchemy_known = ["potion_energy"]
			var k_tl: Dictionary = GameData.tool_level.duplicate()
			GameData.tool_level["pickaxe"] = 1
			var low_p := GameData.alchemy_drop_chance("bigrock")
			GameData.tool_level["pickaxe"] = 4
			var high_p := GameData.alchemy_drop_chance("bigrock")
			GameData.tool_level = k_tl
			var rare_ok: bool = low_p < 0.01 and low_p < high_p and high_p < 0.03 \
				and GameData.alchemy_drop_chance("tree") < 0.005
			var before_n: int = GameData.alchemy_known.size()
			for i in 4000:
				m.doing._maybe_drop_recipe("bigrock")
			print("RECIPE_DROP_OK=", GameData.alchemy_known.size() > before_n and rare_ok,
				" 낮은확률=", rare_ok, "(%.3f->%.3f)" % [low_p, high_p],
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
			# 곡이 **끝까지 가서** 되감기는가. 예전에 wav 루프 끝을
			# 「data 바이트/2」로 셌는데, 들여올 때 압축되면 그 셈이 안 맞아
			# 열 곡이 전부 5분의 1 지점에서 되감겼다 (소리만 들어서는 모른다).
			var loop_bad: Array = []
			for bn: String in Sound.BGM_NAMES:
				var s0: AudioStream = Sound.streams.get(bn)
				if s0 is AudioStreamWAV:
					var w: AudioStreamWAV = s0
					var want := int(round(w.get_length() * float(w.mix_rate)))
					if w.loop_mode == AudioStreamWAV.LOOP_DISABLED \
							or absf(float(w.loop_end - want)) > float(want) * 0.02:
						loop_bad.append("%s(%d/%d)" % [bn, w.loop_end, want])
				elif s0 is AudioStreamOggVorbis:
					if not (s0 as AudioStreamOggVorbis).loop:
						loop_bad.append(bn + "(ogg 루프꺼짐)")
				elif s0 is AudioStreamMP3:
					if not (s0 as AudioStreamMP3).loop:
						loop_bad.append(bn + "(mp3 루프꺼짐)")
				else:
					loop_bad.append(bn + "(모르는 형식)")
			print("BGM_LOOP_OK=", loop_bad.is_empty(), " 어긋난 곡=", loop_bad)
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
			# 발견 기록 — 지정 컬렉션은 「초반 음식」+동굴 2종(스토리 10 게이트)
			# 뿐이고, 진행 전에는 완성으로 치지 않는다 (locked 요리도 그대로)
			GameData.discovered.clear()
			GameData.collections_done.clear()
			GameData.recipes_unlocked.clear()
			GameData.collection_pending.clear()
			GameData.recipe_pending.clear()
			var keep_s10c: String = GameData.story10_phase
			GameData.story10_phase = ""   # 동굴 컬렉션이 잠긴 상태 기준으로 본다
			var was_locked := GameData.recipe_locked("dish_fried_egg")
			for cid2: String in ["potato", "carrot", "strawberry", "spinach", "onion", "pea"]:
				GameData.discover(cid2)
			var only_food: bool = GameData.COLLECTIONS.size() == 3 \
				and str(GameData.COLLECTIONS[0].id) == "col_food_starter" \
				and GameData.collections_done.is_empty()
			# 동굴 컬렉션은 스토리 10 조사 전에는 노트에 나타나지 않는다
			for gcol: Dictionary in GameData.COLLECTIONS:
				if str(gcol.get("gate", "")) != "" and GameData.collection_open(gcol):
					only_food = false
			GameData.story10_phase = keep_s10c
			var still_locked := GameData.recipe_locked("dish_fried_egg")  # locked 요리는 그대로
			var basic_open := not GameData.recipe_locked("dish_baked_potato")  # 기본 요리는 떠오른다
			var no_banner := GameData.collection_pending.is_empty()
			var dated := GameData.discovered_on("pea") != ""
			var again := not GameData.discover("pea")   # 두 번째는 기록하지 않는다
			print("COLLECT_OK=", only_food and was_locked
				and still_locked and basic_open and no_banner and dated and again,
				" 초반음식만=", only_food, " 잠긴요리유지=", still_locked,
				" 기본요리떠오름=", basic_open, " 배너없음=", no_banner,
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
			m.worldgen._build_sea()
			# 바다는 처음부터 그 자리에 있다 — 막혀 있는 건 능선의 길목뿐이다
			var hidden: bool = m.grid[m.MAP_H - 2][30].ground == "water" \
				and str(m.objects.get(m.SEA_GATE[0], {}).get("kind", "")) == "bigrock"
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
				" 열기전길막힘=", hidden, " 능선=", ridge, " 모래=", sand,
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
			m.story._end_arrival()
			var farewell := GameData.story_phase == "deliver" \
				and GameData.story_objective_short() != ""
			m.story._start_delivery_dialog()   # 우체부가 이장에게 직접 전달
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
			m.tutorial_notify("harvest")       # 첫 수확 -> 만수에게 (2막의 마지막 마디)
			var k_kf2 := GameData.kitchen_found
			var k_kq2 := GameData.kitchen_quest
			GameData.kitchen_found = false
			GameData.kitchen_quest = ""
			var s2_done: bool = GameData.story2_phase == "cook" \
				and GameData.kitchen_quest_ready()
			GameData.kitchen_found = k_kf2
			GameData.kitchen_quest = k_kq2
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
				" 밭시작=", farm, " 수확→만수=", s2_done, " 안내분리=", order_ok)
			GameData.house_lv = keep_house
			GameData.has_bed = keep_bed
			GameData.bed_lv = keep_bedlv
			GameData.story2_phase = "done"
			m.interior._layout()
		301:
			# #103/#104/#105: 마을 생활 안내 분리(스토리 3에 열림) + 게시판 1번 퀘
			# + 퀘스트 카탈로그 분류(cat/ep) + Q창 좌우 분할
			var keep_tut: Dictionary = GameData.tutorial.duplicate()
			var keep_guide := GameData.guide_active
			var keep_move := GameData.move_quest
			GameData.tutorial = GameData.fresh_tutorial()
			GameData.guide_active = false
			var no_build := true
			for pair in GameData.TUTORIAL_ORDER:
				if str(pair[0]) == "build":
					no_build = false
			# 안내가 잠겨 있으면 안내 목표는 나오지 않고, 알림도 무시된다.
			# (첫 살림 줄기의 마지막 걸음 「요리」까지는 잠금 밖이다)
			for f in GameData.FARM_CHAIN_FLAGS:
				GameData.tutorial[f] = true
			var none_flag := GameData.tutorial_current_flag() == ""
			m.tutorial_notify("board")
			var ignored: bool = not GameData.tutorial.get("board", false)
			# 스토리 3이 열면 1번 목표 = 의뢰 게시판
			GameData.guide_active = true
			var first := GameData.tutorial_current_flag() == "board"
			var keep_money := GameData.money
			m.village._open_quest_board()
			m.dialog.close()
			var board_done: bool = GameData.tutorial.get("board", false) \
				and GameData.money == keep_money \
					+ int(GameData.TUTORIAL_REWARDS["board"]["money"])
			# 「새로운 주민의 이사」= 메인 스토리 3으로 분류되고 Q창에 뜬다
			GameData.move_quest = "show"
			var cat_ok := false
			for q: Dictionary in GameData.quest_catalog():
				if str(q.id) == "move" and str(q.get("cat", "")) == "main" \
						and str(q.get("ep", "")) == "메인 스토리 3":
					cat_ok = true
			m.quest_ui._sel = "move"
			m.quest_ui.toggle()
			var listed: bool = m.quest_ui.list_box.get_child_count() > 0 \
				and m.quest_ui.detail_box.get_child_count() > 0
			m.quest_ui.close()
			print("GUIDE_OK=", no_build and none_flag and ignored and first
				and board_done and cat_ok and listed,
				" 설치퀘삭제=", no_build, " 잠금=", none_flag and ignored,
				" 게시판1번=", first, " 게시판달성=", board_done,
				" 이사=메인3=", cat_ok, " Q창좌우=", listed)
			GameData.move_quest = keep_move
			GameData.tutorial = keep_tut
			GameData.guide_active = keep_guide
		302:
			# #103: 스프링클러 = 수확 보상에서 빠지고 잡화점 레시피(배우면 해금)
			var keep_ut: Array = GameData.unlocked_tools.duplicate()
			GameData.unlocked_tools.erase("sprinkler")
			GameData.recipes_unlocked.erase("sprinkler")
			var not_in_harvest: bool = \
				"sprinkler" not in GameData.TUTORIAL_UNLOCKS["harvest"]
			var disp := GameData.recipe_display_name("sprinkler") == "스프링클러"
			var on_sale: bool = m.shop._recipe_on_sale("sprinkler")
			GameData.give_recipe("sprinkler")
			var scroll_in_bag := int(GameData.recipe_items.get("sprinkler", 0)) == 1
			var gone_while_owned: bool = not m.shop._recipe_on_sale("sprinkler")
			var learned := GameData.learn_recipe("sprinkler")
			var tool_open := GameData.is_tool_unlocked("sprinkler") \
				and "sprinkler" in GameData.recipes_unlocked
			var gone_after: bool = not m.shop._recipe_on_sale("sprinkler")
			print("SPRECIPE_OK=", not_in_harvest and disp and on_sale
				and scroll_in_bag and gone_while_owned and learned and tool_open
				and gone_after,
				" 수확보상제외=", not_in_harvest, " 이름=", disp,
				" 판매중=", on_sale, " 두루마리=", scroll_in_bag,
				" 구매후목록제거=", gone_while_owned and gone_after,
				" 배우면해금=", learned and tool_open)
			GameData.unlocked_tools = keep_ut
		305:
			# #104: 초록 풀숲 드랍 — 기본 잡초, 약초는 1%
			var herb := 0
			var weed_n := 0
			for i in 400:
				if GameData.weed_drop_id() == "forage_herb":
					herb += 1
				else:
					weed_n += 1
			print("WEEDDROP_OK=", herb < 40 and weed_n > 360,
				" 약초=", herb, "/400 잡초=", weed_n, "/400")
		306:
			# #104: 의뢰 게시판 필터 — 해금한 도구·지역·제철로만 의뢰가 붙는다
			var keep_ut2: Array = GameData.unlocked_tools.duplicate()
			var keep_md := GameData.mine_deepest
			GameData.unlocked_tools.erase("rod")
			GameData.unlocked_tools.erase("pickaxe")
			var no_fish: bool = GameData.quest_pool("fish").is_empty()
			var no_min: bool = GameData.quest_pool("mineral").is_empty()
			GameData.unlocked_tools.append("rod")
			GameData.unlocked_tools.append("pickaxe")
			var fish_pool: Array = GameData.quest_pool("fish")
			var season_ok: bool = not fish_pool.is_empty()
			for fid in fish_pool:
				for f: Dictionary in GameData.FISH:
					if str(f.id) == str(fid):
						season_ok = season_ok and (f.weather as Array).is_empty() \
							and ((f.seasons as Array).is_empty()
								or GameData.season() in f.seasons)
			var no_herb: bool = "forage_herb" not in GameData.quest_pool("forage")
			GameData.mine_deepest = 1
			var no_gem: bool = "gem" not in GameData.quest_pool("mineral")
			GameData.mine_deepest = 5
			var gem_deep: bool = "gem" in GameData.quest_pool("mineral")
			GameData.mine_deepest = keep_md
			GameData.unlocked_tools = keep_ut2
			print("QUESTPOOL_OK=", no_fish and no_min and season_ok and no_herb
				and no_gem and gem_deep,
				" 낚싯대없음=", no_fish, " 곡괭이없음=", no_min,
				" 제철만=", season_ok, " 약초금지=", no_herb,
				" 보석3층=", no_gem and gem_deep)
		309:
			# #103: 메인 스토리 완결 — 전체 화면 연출이 뜨고 알아서 걷힌다
			m.hud.story_banner("메인 스토리 검사", "완결 연출")
			var shown: bool = m.hud._sb_layer != null and m.hud._sb_layer.visible
			m.hud._update_story_banner(5.0)
			var gone_fx: bool = not m.hud._sb_layer.visible
			print("STORYFX_OK=", shown and gone_fx,
				" 표시=", shown, " 자동닫힘=", gone_fx)
		311:
			# #107: 오브젝트가 없어도 도끼/곡괭이가 휘둘러지고, 앞의 밤
			# 몬스터를 무기처럼 히트박스로 때린다
			var keep_tool2 := GameData.tool
			GameData.tool = "axe"
			m.toolwork._weapon_cd = 0.0
			var mob_node := Node2D.new()
			m.add_child(mob_node)
			mob_node.position = m.player.position \
				+ m.FACE_VECS[m.player.dir] * 30.0
			m.night_mobs.append({"node": mob_node, "hp": 1.0})
			var mobs_before := m.night_mobs.size()
			m.toolwork._swing_empty(m.player_tile())
			var swung: bool = m.toolwork._weapon_cd > 0.0
			var hit: bool = m.night_mobs.size() == mobs_before - 1
			# 쿨다운 중에는 연타가 안 먹는다
			var cd_before: float = m.toolwork._weapon_cd
			m.toolwork._swing_empty(m.player_tile())
			var cooldown_ok: bool = m.toolwork._weapon_cd == cd_before
			for mob in m.night_mobs.duplicate():
				if mob.node == mob_node:
					m.night_mobs.erase(mob)
			if is_instance_valid(mob_node):
				mob_node.queue_free()
			m.toolwork._weapon_cd = 0.0
			GameData.tool = keep_tool2
			print("SWINGEMPTY_OK=", swung and hit and cooldown_ok,
				" 휘두름=", swung, " 명중=", hit, " 쿨다운=", cooldown_ok)
		312:
			# 메인 스토리 6: 오래된 책과 사서 — 전 구간을 손으로 밟아 본다
			var keep6_forest := GameData.forest_quest
			GameData.story6_phase = ""
			GameData.old_book_stored = false
			GameData.items["old_book"] = 0
			GameData.village_built.erase("library")
			GameData.npc_greeted.erase("librarian")
			GameData.forest_quest = "done"
			m.story._story6_update(0.1)
			var placed: bool = GameData.story6_phase == "find" \
				and m.story._old_book_exists()
			var bt := Vector2i(-999, -999)
			for pos: Vector2i in m.objects:
				if str(m.objects[pos].kind) == "old_book":
					bt = pos
					break
			m.story.examine_old_book(bt)
			m.dialog.close()
			var got_book: bool = int(GameData.items.get("old_book", 0)) == 1 \
				and GameData.story6_phase == "show_chief"
			m.story._start_book_chief_dialog()
			m.dialog.close()
			m.story._end_book_chief()
			m.story._story6_update(0.1)   # 우체부가 우체국 터 앞에 선다
			var post_stand: bool = GameData.story6_phase == "ask_post" \
				and m.story._book_post != null \
				and m.story._book_post_mode == "stand"
			m.story._start_book_post_dialog()
			m.dialog.close()
			m.story._end_book_post()
			var waiting: bool = GameData.story6_phase == "wait" \
				and GameData.story6_day == GameData.day \
				and m.story._book_post == null
			m.story._start_book_reply_dialog()
			m.dialog.close()
			m.story._end_book_reply()
			var lib_npc := false
			for n in m.npcs:
				if n.id == "librarian":
					lib_npc = true
			var visit_ok: bool = GameData.story6_phase == "visit" and lib_npc
			m.story._start_librarian_book_dialog()
			m.dialog.close()
			m.story._end_librarian_book()
			# 도서관은 스토리가 build에 닿기 전에는 발전 목록에 안 나온다
			var keep6_built: Array = GameData.village_built.duplicate()
			GameData.village_built = ["post", "general", "smith", "ranch", "fish"]
			var gated: bool = m.village._next_village_build() != "library"
			m.story._start_book_chief2_dialog()
			m.dialog.close()
			m.story._end_book_chief2()
			var build_open: bool = GameData.story6_phase == "build" \
				and m.village._next_village_build() == "library"
			GameData.wood += 90
			GameData.stone += 50
			m.village._open_village_build_dialog()
			m.village._build_village_building("library")
			m.dialog.close()
			var built: bool = GameData.village_built.has("library")
			m.story._start_library_done_dialog()
			m.dialog.close()
			m.story._end_library_done()
			var settled: bool = GameData.story6_phase == "done" \
				and GameData.npc_greeted.has("librarian") \
				and GameData.old_book_stored \
				and int(GameData.items.get("old_book", 0)) == 0
			m.village._open_library_dialog()   # 서가 — 오래된 책 보관 확인
			var shelf: bool = m.dialog.visible
			m.dialog.close()
			print("STORY6_OK=", placed and got_book and post_stand and waiting
				and visit_ok and gated and build_open and built and settled
				and shelf,
				" 책놓임=", placed, " 획득=", got_book, " 우체부대기=", post_stand,
				" 답장대기=", waiting, " 사서방문=", visit_ok, " 건설잠금=", gated,
				" 건설해금=", build_open, " 완공=", built, " 정착=", settled,
				" 서가=", shelf)
			# 지도에 세운 도서관은 그대로 두고 (되돌리면 그림과 어긋난다)
			# 이야기 상태만 이어서 쓴다
			GameData.village_built = keep6_built
			GameData.village_built.append("library")
			GameData.forest_quest = keep6_forest
		315:
			# #112: 조리대를 못 찾았으면 요리 레시피를 팔지 않는다 (힌트만)
			var keep_kf := GameData.kitchen_found
			var keep_kq := GameData.kitchen_quest
			var keep_money3 := GameData.money
			GameData.kitchen_found = false
			GameData.kitchen_quest = "done"   # 이야기는 따로(288) 본다
			GameData.recipe_items.erase("dish_grilled_fish")
			GameData.recipes_unlocked.erase("dish_grilled_fish")
			m.shop._on_buy_dish_recipe("dish_grilled_fish", 200)
			var blocked: bool = GameData.money == keep_money3 \
				and not GameData.recipe_items.has("dish_grilled_fish") \
				and m.dialog.visible
			m.dialog.close()
			GameData.kitchen_found = true
			m.shop._on_buy_dish_recipe("dish_grilled_fish", 200)
			var bought: bool = GameData.money == keep_money3 - 200 \
				and GameData.recipe_items.has("dish_grilled_fish")
			GameData.kitchen_found = keep_kf
			GameData.kitchen_quest = keep_kq
			GameData.money = keep_money3
			GameData.recipe_items.erase("dish_grilled_fish")
			print("KITCHENGATE_OK=", blocked and bought,
				" 차단+힌트=", blocked, " 해금후구매=", bought)
		319:
			# #113: Q창 메인 1개만 + 마을 도착 전 「마을 소식」 숨김 + 말풍선 토스트
			var keep_sp := GameData.story_phase
			var keep_s6 := GameData.story6_phase
			var keep_mv := GameData.move_quest
			# 메인 두 줄기를 동시에 살려 놓고 목록을 뽑아 본다
			GameData.story_phase = "done"
			GameData.story6_phase = "show_chief"
			GameData.move_quest = "show"
			var mains := 0
			var has_info := false
			for e: Dictionary in m.quest_ui._entries():
				if str(e.get("cat", "")) == "main":
					mains += 1
				if str(e.get("cat", "")) == "info":
					has_info = true
			var one_main: bool = mains == 1
			var info_town: bool = has_info
			# 마을 도착 전 — 마을 소식이 아예 없어야 한다
			GameData.story_phase = "travel"
			var info_field := false
			for e: Dictionary in m.quest_ui._entries():
				if str(e.get("cat", "")) == "info":
					info_field = true
			# 말풍선 시작 토스트 — bounce 표식이 실려 큐에 들어간다
			m.hud._toast_queue.clear()
			m.hud.quest_start_toast("검사용 퀘스트")
			var bubbled: bool = not m.hud._toast_queue.is_empty() \
				and bool(m.hud._toast_queue[0].get("bounce", false)) \
				and str(m.hud._toast_queue[0].head).contains("새로운 퀘스트")
			m.hud._toast_queue.clear()
			GameData.story_phase = keep_sp
			GameData.story6_phase = keep_s6
			GameData.move_quest = keep_mv
			print("QUESTLIST_OK=", one_main and info_town and not info_field
				and bubbled,
				" 메인1개=", one_main, " 마을소식(도착후)=", info_town,
				" 마을소식(도착전숨김)=", not info_field, " 말풍선=", bubbled)
		322:
			# #115/#139/#147: 한 페이지 세 줄까지 · 문장은 페이지를 넘지 않는다 ·
			# NPC 대사에는 괄호 지문도 편집 기호도 남지 않는다
			m.dialog.open_seq("검사", null, [
				{"text": "첫 번째 문장은 짧다.\n두 번째 문장은 제법 길어서 한 줄에 담기지 않고"
					+ " 다음 줄까지 넘어가게 된다. 세 번째 문장도 이어서 붙는다."
					+ " 네 번째 문장까지 붙이면 한 화면에는 도저히 담기지 않는다."
					+ " 다섯 번째 문장으로 확실히 넘긴다.",
					"choices": [["끝", null]]},
			])
			var pages: int = m.dialog._seq.size()
			var two_lines := true
			var sent_whole := true
			for e2: Dictionary in m.dialog._seq:
				var body2 := str(e2.get("text", ""))
				if body2.split("\n").size() > m.dialog.PAGE_LINES:
					two_lines = false
				# 페이지 끝은 문장 끝이어야 한다 (한두 글자만 다음 장으로 밀리지 않게)
				if not body2.strip_edges().ends_with("."):
					sent_whole = false
				# 한 줄에 한두 글자만 덜렁 남지 않는다
				for ln2 in body2.split("\n"):
					if ln2.strip_edges().length() < 3:
						two_lines = false
			var choice_last: bool = m.dialog._seq[pages - 1].has("choices") \
				and not m.dialog._seq[0].has("choices")
			var small_font: bool = m.dialog.FONT_BODY <= 14
			m.dialog.close()
			# NPC가 하는 말에서는 괄호 지문과 편집 기호가 사라진다
			m.dialog.open_seq("검사", null, [
				{"text": "「이건 전설의 물고기라네.」 (그가 웃었다)"},
				{"text": "(문이 삐걱이며 열렸다.)"},
			])
			var spoken_clean := true
			var narration_kept := false
			for e3: Dictionary in m.dialog._seq:
				var b3 := str(e3.get("text", ""))
				if b3.contains("*"):
					spoken_clean = false
				if b3.contains("「") and (b3.contains("(") or b3.contains(")")):
					spoken_clean = false
				if b3.begins_with("(") and b3.contains(")"):
					narration_kept = true    # 지문만 있는 페이지는 그대로 둔다
			m.dialog.close()
			print("DIALOG2LINE_OK=", pages >= 2 and two_lines and choice_last
				and sent_whole and small_font and spoken_clean and narration_kept,
				" 페이지=", pages, " 세줄이하=", two_lines, " 선택지끝장=", choice_last,
				" 문장안끊김=", sent_whole, " 작은글씨=", small_font,
				" 대사정리=", spoken_clean, " 지문유지=", narration_kept)
		325:
			# #114: 잡화점 요리 레시피 — 물고기를 낚아 봐야 진열 + 상인 첫날 숨김
			var keep_fc: Dictionary = GameData.fish_caught.duplicate()
			var keep_md := GameData.merchant_day
			GameData.fish_caught.erase("fish_crucian")
			var shelf_off: bool = not GameData.shop_dish_on_shelf("dish_grilled_fish")
			GameData.fish_caught["fish_crucian"] = 1
			var shelf_on: bool = GameData.shop_dish_on_shelf("dish_grilled_fish")
			var golden: bool = GameData.SHOP_DISH_IDS.has("dish_golden_roast") \
				and not GameData.shop_dish_on_shelf("dish_golden_roast")
			# 상인 도착 첫날은 요리 레시피 절 자체가 닫혀 있다 — 다음 날부터
			GameData.merchant_day = GameData.day
			var day_off: bool = not (GameData.day > GameData.merchant_day)
			GameData.merchant_day = GameData.day - 1
			var day_on: bool = GameData.day > GameData.merchant_day
			GameData.fish_caught = keep_fc
			GameData.merchant_day = keep_md
			print("SHOPFISH_OK=", shelf_off and shelf_on and golden
				and day_off and day_on,
				" 안낚음=", shelf_off, " 낚음=", shelf_on, " 황금잉어=", golden,
				" 첫날숨김=", day_off, " 다음날=", day_on)
		329:
			# #121: 초반 음식 — 단계 진열·컬렉션·이속 보상 + 물고기=재료 칸 + 씨앗 숨김
			var keep_disc: Dictionary = GameData.discovered.duplicate()
			var keep_ck: Dictionary = GameData.recipes_cooked.duplicate()
			var keep_cdone: Array = GameData.collections_done.duplicate()
			for did9: String in ["forage_berry", "wheat", "flour"]:
				GameData.discovered.erase(did9)
			GameData.recipes_cooked.erase("flour")
			GameData.recipes_cooked.erase("dish_berry_jam")
			var st0: bool = not GameData.shop_food_on_sale("dish_berry_jam") \
				and not GameData.shop_food_on_sale("flour") \
				and not GameData.shop_food_on_sale("dish_bread") \
				and not GameData.shop_food_on_sale("dish_berry_toast")
			GameData.discovered["forage_berry"] = 1
			GameData.discovered["wheat"] = 1
			# 산딸기잼 레시피는 **상점에 아예 없다** (퀘스트로만 얻는다)
			var st1: bool = not GameData.shop_food_on_sale("dish_berry_jam") \
				and "dish_berry_jam" not in GameData.SHOP_FOOD_IDS \
				and GameData.shop_food_on_sale("flour") \
				and not GameData.shop_food_on_sale("dish_bread")
			GameData.discovered["flour"] = 1
			GameData.recipes_cooked["flour"] = 1
			var st2: bool = GameData.shop_food_on_sale("dish_bread") \
				and GameData.shop_food_on_sale("dish_berry_toast")
			# 넷을 전부 만들어 보면 「초반 음식」이 차고 걸음이 빨라진다
			GameData.collections_done.erase("col_food_starter")
			var v0: float = GameData.perk_speed_mult()
			for fid2: String in ["dish_berry_jam", "flour", "dish_bread",
					"dish_berry_toast"]:
				GameData.discovered[fid2] = 1
			GameData._check_collections()
			var col_ok: bool = "col_food_starter" in GameData.collections_done
			var sped: bool = v0 == 1.0 and GameData.perk_speed_mult() > 1.0
			GameData.collection_pending.clear()
			# 낚은 물고기는 요리 칸이 아니라 재료 칸에 정렬된다
			GameData.items["fish_sweetfish"] = maxi(1,
				int(GameData.items["fish_sweetfish"]))
			var fish_tab := ""
			for e3: Dictionary in m.inventory_ui._item_entries():
				if str(e3.get("name", "")) == "은어":
					fish_tab = str(e3.get("tab", ""))
			# 씨앗이 하나도 없으면 가방의 씨앗 주머니 항목이 사라진다
			var keep_seeds: Dictionary = GameData.seeds.duplicate()
			for cid3: String in GameData.CROP_IDS:
				GameData.seeds[cid3] = 0
			var pouch_gone: bool = GameData.seed_total() == 0
			GameData.seeds = keep_seeds
			GameData.discovered = keep_disc
			GameData.recipes_cooked = keep_ck
			GameData.collections_done = keep_cdone
			print("FOODCOL_OK=", st0 and st1 and st2 and col_ok and sped
				and fish_tab == "res" and pouch_gone,
				" 진열0=", st0, " 잼는상점밖·밀가루=", st1, " 빵토스트=", st2,
				" 컬렉션=", col_ok, " 이속=", sped,
				" 물고기재료칸=", fish_tab == "res", " 씨앗숨김=", pouch_gone)
		334:
			# #102: 가방 씨앗 슬롯 클릭 -> 씨앗 선택+주머니 장착, 나무 침대 아트
			var keep_seed_slots: Array = GameData.tool_slots.duplicate()
			var keep_tool := GameData.tool
			if not GameData.is_tool_unlocked("seed"):
				GameData.unlocked_tools.append("seed")
			if not GameData.tool_slots.has("seed"):
				GameData.tool_slots[0] = ""      # 빈 칸을 보장해 자동 장착 경로를 태운다
			GameData.seeds["corn"] = maxi(1, int(GameData.seeds.get("corn", 0)))
			GameData.seeds["wheat"] = maxi(1, int(GameData.seeds.get("wheat", 0)))
			m.inventory_ui._pick_seed("corn")
			var picked_corn := GameData.current_seed_id() == "corn" \
				and GameData.tool == "seed" and GameData.tool_slots.has("seed")
			m.inventory_ui._pick_seed("wheat")
			var picked_wheat := GameData.current_seed_id() == "wheat"
			var bedart: bool = m.tex.has("bed_wood")
			print("SEEDPICK_OK=", picked_corn and picked_wheat and bedart,
				" 옥수수선택=", picked_corn, " 밀선택=", picked_wheat,
				" 침대아트=", bedart)
			GameData.tool_slots = keep_seed_slots
			GameData.tool = keep_tool
		392:
			# 씨앗만 멀리서도 뿌릴 수 있다 (interact.SEED_REACH).
			# 다른 도구는 예전대로 바로 옆 한 칸 — 여기가 무너지면 도끼로
			# 화면 건너편 나무를 벨 수 있게 된다.
			var keep_reach_tool := GameData.tool
			var here := m.player_tile()
			GameData.tool = "seed"
			var seed_far: bool = m.actions.in_reach(Vector2i(7, 5))     # 8.6칸
			var seed_edge: bool = m.actions.in_reach(Vector2i(10, 0))   # 딱 10칸
			var seed_over: bool = m.actions.in_reach(Vector2i(9, 9))    # 12.7칸 = 밖
			GameData.tool = "axe"
			var axe_near: bool = m.actions.in_reach(Vector2i(1, 1))     # 대각선 한 칸
			var axe_far: bool = m.actions.in_reach(Vector2i(3, 0))
			# 마우스가 가리킨 먼 칸이 실제로 목표가 되는가
			GameData.tool = "seed"
			m._sel_target = Vector2i(-999, -999)
			m._mouse_target = here + Vector2i(6, 4)
			var mouse_far: bool = m.actions.target_tile() == here + Vector2i(6, 4)
			m._mouse_target = Vector2i(-999, -999)
			GameData.tool = keep_reach_tool
			print("SEEDREACH_OK=", seed_far and seed_edge and not seed_over
				and axe_near and not axe_far and mouse_far,
				" 씨앗8칸=", seed_far, " 씨앗10칸=", seed_edge,
				" 씨앗밖=", not seed_over, " 도끼옆=", axe_near,
				" 도끼멀리=", not axe_far, " 마우스목표=", mouse_far)
		393:
			# 지도를 끌 때 한 장 그리는 데 얼마나 걸리나.
			#
			# 예전에는 칸마다 draw_rect + 구름 원이라 배율 1에서 한 장에
			# 3만 번 넘게 그렸다 — 끌면 그대로 뚝뚝 끊겼다. 지금은 지형을
			# 한 장으로 구워 통째로 늘여 그린다 (map_ui._bake).
			m.map_ui.open()
			m.map_ui.reset_view()
			_bench_us = 0
			_bench_n = 0
		394, 395, 396, 397, 398, 399, 400, 401, 402, 403, 404:
			m.map_ui.pan += Vector2(4.0, 3.0)      # 끄는 흉내
			m.map_ui._clamp_pan()
			m.map_ui.canvas.queue_redraw()
			if m.map_ui.draw_us > 0:
				_bench_us += m.map_ui.draw_us
				_bench_n += 1
		405:
			var per_draw: int = _bench_us / maxi(1, _bench_n)
			m.map_ui.close()
			# 소프트웨어 렌더러(CI)에서도 8ms를 넘으면 안 된다 —
			# 넘으면 그리는 것만으로 120fps가 무너진다는 뜻이다
			print("MAPDRAW_OK=", _bench_n > 0 and per_draw < 8000,
				" 한 장=", per_draw, "us (", _bench_n, "장 평균 · 배율 1)")
		406:
			# 개발용 「메인 스토리 건너뛰기」 — 오프닝 도중에 눌러도 샌드박스로 선다.
			# 앞 이야기를 다시 볼 수 없으니 만드는 동안 제일 자주 쓰는 길이다.
			var k_all := {
				"phase": GameData.story_phase, "s2": GameData.story2_phase,
				"tut": GameData.tutorial.duplicate(true),
				"tools": GameData.unlocked_tools.duplicate(),
				"built": GameData.village_built.duplicate(),
				"house": GameData.house_lv, "sea": GameData.sea_open,
				"fisher": GameData.fisher_quest,
			}
			GameData.story_phase = "enter"        # 오프닝 한복판인 척
			GameData.story2_phase = ""
			GameData.tutorial = GameData.fresh_tutorial()
			m.story.skip_main_story()
			var skip_ok: bool = GameData.story_phase == "done" \
				and GameData.story2_phase == "done" \
				and not bool(GameData.tutorial.get("active", true)) \
				and GameData.is_tool_unlocked("hoe") and GameData.is_tool_unlocked("axe") \
				and GameData.house_lv >= 1 and GameData.has_bed \
				and GameData.sea_open \
				and GameData.village_built.size() == GameData.ALL_VILLAGE_PLOTS.size() \
				and not m.story_cutscene
			# 두 번 눌러도 탈이 없다 (이미 건너뛴 상태면 알려 주고 만다)
			m.story.skip_main_story()
			var again_ok: bool = GameData.story_phase == "done"
			GameData.story_phase = k_all.phase
			GameData.story2_phase = k_all.s2
			GameData.tutorial = k_all.tut
			GameData.unlocked_tools = k_all.tools
			GameData.village_built = k_all.built
			GameData.house_lv = k_all.house
			GameData.sea_open = k_all.sea
			GameData.fisher_quest = k_all.fisher
			print("STORYSKIP_OK=", skip_ok and again_ok,
				" 샌드박스=", skip_ok, " 두번눌러도=", again_ok)
		407: get_tree().quit()


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


# 휘두르기를 원하는 위상에 세워 둔다 (오른쪽을 보고 도끼).
#
# 동작 길이를 **아주 길게** 늘여 놓고 그 안의 비율로 세운다. 0.34초짜리
# 그대로 두면 헤드리스에서 한 프레임이 0.1초씩 걸릴 때 세워 둔 위상이
# 그려지기도 전에 지나가 버린다 (실제로 한 칸씩 밀려 찍혔다).
# 위상 경계는 swing_len이 아니라 HIT_AT/SWING_TIME으로 잡히므로 안 흔들린다.
func _swing_pose(phase: int) -> void:
	const MID := [0.075, 0.24, 0.38, 0.60, 0.85]
	const HOLD := 200.0
	m.player.dir = "right"
	m.player.start_swing("axe", Vector2.RIGHT, m.SWING_TIME)
	m.player.swing_len = HOLD
	m.player.swing_t = HOLD * (1.0 - MID[phase])
	m.player._swing_visual()
	if m.player.swing_phase() != phase:
		print("SWING_POSE_MISS: 노린 위상=", phase, " 실제=", m.player.swing_phase())


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
			# 게스트가 민 변경이 호스트를 거쳐 되돌아오는가.
			# 먼저 칸 곁으로 가서 위치 동기화(15/s)가 호스트에 닿기를 기다린다 —
			# 호스트의 게스트 요청 검문(_near_sender)이 멀리서 온 요청을 버린다
			m.player.position = Vector2(MP_TILE.x * m.TILE + 16, (MP_TILE.y + 1) * m.TILE + 16)
			GameData.tool = "hoe"
		290:
			m.netsync._req_tool.rpc_id(1, MP_TILE.x, MP_TILE.y, "hoe", "",
				int(m.player.position.x), int(m.player.position.y))
		330:
			var g: Dictionary = m.grid[MP_TILE.y][MP_TILE.x]
			print("MP_TOOL_OK=", g.ground == "soil", " 땅=", g.ground)
		340:
			_save_shot("_mp_guest.png")
		360:
			get_tree().quit()
