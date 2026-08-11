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
	if Net.is_guest() and not m._net_ready:
		return  # 접속 완료 후부터 시퀀스 시작
	_shot_frames += 1
	if OS.get_environment("KYOJIN_STORY") != "":
		# 스토리 화면만 캡처하고 종료 (프레임 수가 아니라 스토리 진행 시간 기준 —
		# 헤드리스 환경은 프레임 속도가 들쭉날쭉하다)
		if not m.story._story_snapped and m.story._story_t >= 3.2:
			m.story._story_snapped = true
			_save_shot("_story.png")
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
			m._open_gift_picker("chief")
		103: _save_shot("_gift.png")
		104:
			m._close_gift_picker()
			m.dialog.close()
			GameData.money = 200000
		122: m.interior.open()                           # 집 내부 확인
		128: _save_shot("_house.png")
		129: _send_key(KEY_F)                          # 꾸미기 모드
		133: _save_shot("_deco.png")
		134: _send_key(KEY_F)                          # 꾸미기 종료
		136: m.interior.ppos = Vector2(645, 174)         # 조리대 앞으로
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
			m._build_village_building("post")
			m._build_village_building("general")
			m._build_village_building("smith")
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
			m.set_tool("rod")
		217: _save_shot("_pier.png")
		218:
			# 회귀 검사: 비가 와서 이미 젖은 밭에서도 「50% 물주기」가 되어야 한다
			var wt: Vector2i = m.player_tile() + Vector2i(0, 1)
			var wc: Dictionary = m.grid[wt.y][wt.x]
			m.objects.erase(wt)
			wc.ground = "soil"
			wc.crop_id = "potato"
			wc.crop_day = m._grow_total(GameData.CROPS["potato"]) * 0.7
			wc.dead = false
			m._wet(wc, m.WET_ALL_DAY)      # 비로 이미 젖은 상태
			wc.half_fed = false        # 아직 체크포인트 물은 안 줬다
			m.set_tool("water")
			m._sel_target = wt
			m.player.dir = "down"
			m.interact()
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
			m.set_tool("pickaxe")
			print("ROCK_SIDE_TARGET_OK=", m._tool_target_nearby().x != -999)
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
				sched.append("%d시=%s" % [h, m.npc_place_now("merchant")])
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
				" npc_place=", m.npc_place_now("merchant"))
			m.player.position = Vector2(74 * m.TILE + 16, 14 * m.TILE + 16)
			m._apply_season_visuals()
		313: _save_shot("_festival.png")
		314:
			# 인사를 다 채우면 축제가 끝나고 상금이 나온다
			for nid: String in GameData.NPCS:
				if not GameData.fest_greeted.has(nid):
					GameData.fest_greeted.append(nid)
			m._finish_festival()
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
			m._do_breed()
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
			m._do_rest()
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
			m._build_greenhouse()
			m.dialog.close()
			GameData.day = GameData.DAYS_PER_SEASON * 3 + 1   # 겨울
			m._apply_season_visuals()
			m.player.position = Vector2((m.GREENHOUSE.position.x + 4) * m.TILE + 16,
				(m.GREENHOUSE.end.y + 1) * m.TILE + 16)
			print("GREENHOUSE_OK=", GameData.greenhouse_built,
				" winter_plantable=", m.in_greenhouse(m.GREENHOUSE.position))
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
				m._spawn_object_node(rp, "bigrock")
			m._sel_target = Vector2i(-999, -999)
			m._mouse_target = Vector2i(-999, -999)
			m.set_tool("pickaxe")
			var py: float = ry * m.TILE + 16.0
			var px: float = (rx - 3) * m.TILE + 16.0
			while m.is_passable_px(Vector2(px + 1.0, py)):
				px += 1.0                       # 막힐 때까지 오른쪽으로 (실제 이동과 같은 판정)
			m.player.position = Vector2(px, py)
			m.player.dir = "right"
			var before: int = int(m.objects[Vector2i(rx, ry)].hp)
			m.interact()
			var after: int = int(m.objects.get(Vector2i(rx, ry), {"hp": -1}).hp)
			print("ROCK_WALL: player_tile=", m.player_tile(), " rock_x=", rx,
				" target=", m.target_tile(), " hp ", before, "->", after,
				" MINED_OK=", after != before)
			# 더 나쁜 상황: 두 칸 떨어져 반대쪽을 보고 있어도 캘 수 있어야 한다
			m._work_lock = 0.0
			m._sel_target = Vector2i(-999, -999)
			m.player.position = Vector2((rx - 2) * m.TILE + 16, py)
			m.player.dir = "left"
			var b2: int = int(m.objects[Vector2i(rx, ry)].hp)
			m.interact()
			var a2: int = int(m.objects.get(Vector2i(rx, ry), {"hp": -1}).hp)
			print("ROCK_FAR: player_tile=", m.player_tile(), " (두 칸 떨어져 반대쪽 보기) hp ",
				b2, "->", a2, " MINED_OK=", a2 != b2)
		340:
			var where := []
			for n in m.npcs:
				where.append("%s:%s" % [n.id, n.place])
			print("NPC_PLACES=", ", ".join(where))
			_save_shot("_npcday.png")
		344:
			# 탈 것: 사기 -> 타기 -> 속도 -> 내리기
			GameData.money = 99999
			GameData.has_horse = false
			GameData.riding = false
			GameData.horse_tile = m.player_tile() + Vector2i(1, 0)
			m.shop.main = m
			m.shop._on_buy_horse()
			var parked: bool = m.objects.has(GameData.horse_tile)
			m._mount_horse(GameData.horse_tile)
			print("HORSE: parked=", parked, " riding=", GameData.riding)
		346:
			print("HORSE_DRAW: vis=", m.player.horse_sprite.visible,
				" tex=", m.player.horse_sprite.texture != null,
				" pos=", m.player.horse_sprite.position, " scale=", m.player.horse_sprite.scale)
			_save_shot("_horse.png")
		347:
			m.dismount_horse()
			print("HORSE_DISMOUNT_OK=", not GameData.riding
				and m.objects.has(GameData.horse_tile))
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
			m._remove_object(m.HOME_SITE)
			m.worldgen._fill_building(m.HOME_ANCHOR)
			m.worldgen._spawn_house_node(m.HOME_ANCHOR)
			GameData.day = 1                 # 봄으로 되돌려 눈 없이 찍는다
			m._apply_season_visuals()
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
			m.build_barn()
			m.place_horse()
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
				m._spawn_object_node(mt, "bigrock")
			m._pending_hits.clear()
			m._obj_shakes.clear()
			m.set_tool("pickaxe")
			m.swing_at(mt, "stone", true)
			var swung: bool = m.player.swing_t > 0.0 and m.player.tool_sprite.texture != null
			var queued: int = m._pending_hits.size()
			# 맞는 순간까지 시간을 흘려 본다
			for i in 20:
				m._update_hit_fx(0.01)
			print("SWING_OK=", swung, " 예약된 타격=", queued,
				" 터진 뒤 남은 예약=", m._pending_hits.size(),
				" 흔들리는 오브젝트=", m._obj_shakes.size(),
				" 화면흔들림=", m._cam_shake > 0.0)
			# ---- 화면용 ----
			# 앞선 검사에서 세워 둔 커다란 바위 벽이 캐릭터를 덮으므로
			# 깨끗한 자리로 옮겨 작은 돌 하나만 놓고 찍는다.
			m._remove_object(mt)
			var demo := Vector2i(24, 20)
			for cy in range(demo.y - 3, demo.y + 4):
				for cx in range(demo.x - 3, demo.x + 4):
					m._remove_object(Vector2i(cx, cy))
			var rt2 := demo + Vector2i(1, 0)
			m.objects[rt2] = {"kind": "rock", "hp": m.ROCK_HP}
			m._spawn_object_node(rt2, "rock")
			m.player.position = Vector2(demo.x * m.TILE + 16, demo.y * m.TILE + 16)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m.player.dir = "right"
			m.swing_at(rt2, "stone")
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
					m._remove_object(Vector2i(cx, cy))
			m.objects[ft] = {"kind": "tree", "hp": m.TREE_HP}
			m._spawn_object_node(ft, "tree")
			# 나무 그림이 덮는 자리(바로 위 칸)에 선다
			m.player.position = Vector2(ft.x * m.TILE + 16, (ft.y - 1) * m.TILE + 24)
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m._fade_a.clear()
			var covered: bool = m._covers_player(ft, m.obj_nodes[ft])
			for i in 30:
				m._update_object_fade(0.02)
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
			m.fishing_ui.start(34.0, 3, 1.5, str(GameData.FISH_HINT["fish_golden"]))
			m.fishing_ui.zone_x = 0.0
			m.fishing_ui.zone_w = m.fishing_ui.BAR_W
			m.fishing_ui._input(ev_hook)
		368:
			_save_shot("_fishing.png")
			m.fishing_ui.visible = false
			m.pending_fish = []
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
			for m in m.cave.monsters:
				if str(m.type) == "treant":
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
			m._turn_in_quest()
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
			m._recount_pasture()
			var before_pen: int = m.pasture.size()
			for i in 5:
				m.objects[Vector2i(p0.x - 1 + i, p0.y - 1)] = {"kind": "fence", "hp": 0}
				m.objects[Vector2i(p0.x - 1 + i, p0.y + 3)] = {"kind": "fence", "hp": 0}
				m.objects[Vector2i(p0.x - 1, p0.y - 1 + i)] = {"kind": "fence", "hp": 0}
				m.objects[Vector2i(p0.x + 3, p0.y - 1 + i)] = {"kind": "fence", "hp": 0}
			m._recount_pasture()
			var closed: int = m.pasture.size()
			var inside: bool = m.in_pasture(p0 + Vector2i(1, 1))
			# 문을 하나 내면 (울타리 한 칸 걷어내면) 목초지가 풀려야 한다
			m.objects.erase(Vector2i(p0.x + 1, p0.y - 1))
			m._recount_pasture()
			print("PASTURE_OK=", inside and closed > before_pen,
				" 닫았을 때=", closed - before_pen, "칸  문 내면=",
				m.pasture.size() - before_pen, "칸  OPEN_OK=", not m.in_pasture(p0 + Vector2i(1, 1)))
		357:
			# 스프링클러: 설치하면 바로, 그리고 계속 물을 준다
			var sp := Vector2i(20, 20)
			for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				m.objects.erase(sp + d2)
				m.grid[sp.y + d2.y][sp.x + d2.x].ground = "soil"
				m.grid[sp.y + d2.y][sp.x + d2.x].wet_min = 0.0
				m.grid[sp.y + d2.y][sp.x + d2.x].watered = false
			m.objects.erase(sp)
			m._place_object(sp, "sprinkler", 0)
			m._sprinkle(sp)
			var wet_now: bool = m.grid[sp.y][sp.x + 1].watered
			# 하루가 지나 마른 뒤에도, 낮에 새로 간 밭까지 다시 적셔야 한다
			for d3 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				m.grid[sp.y + d3.y][sp.x + d3.x].wet_min = 0.0
				m.grid[sp.y + d3.y][sp.x + d3.x].watered = false
			m._sprinkler_tick()
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
			m.do_brew(trio)
			print("ALCHEMY_BREW: dud=\"", dud, "\" got=", got,
				" learned=", GameData.knows_formula("potion_energy"),
				" bottles=", int(GameData.items["potion_energy"]))
		360:
			m.dialog.close()
			# 약효: 바람 물약을 마시면 이동 속도 배율이 오른다
			var spd0: float = GameData.pet_speed_mult()
			GameData.learn_formula("potion_swift")
			GameData.items["potion_swift"] = 1
			m.do_drink("potion_swift")
			print("POTION_BUFF: speed ", spd0, " -> ", GameData.pet_speed_mult(),
				" luck=", GameData.bonus_drop_chance("mine"))
			GameData.reset_daily()
			print("POTION_CLEAR_OK=", not GameData.has_potion("swift"))
			# 조합법 드랍: 확률을 1로 올려 실제로 습득되는지 본다
			GameData.alchemy_known = ["potion_energy"]
			var before_n: int = GameData.alchemy_known.size()
			for i in 40:
				m._maybe_drop_recipe("bigrock")
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
			var r_fail: Dictionary = m.do_brew(["milk", "milk", "milk"])
			var r_ok: Dictionary = m.do_brew(["egg", "egg", "egg"])
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
			m._apply_season_visuals()
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
			m._open_quest_board()
		381: _save_shot("_board.png")
		388: get_tree().quit()


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
