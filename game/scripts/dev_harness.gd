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
var _ui_saved: Array = []        # UI 없는 화면을 찍는 동안 꺼 둔 CanvasLayer들


# ---- 검증 시퀀스 ----
# 키/마우스 이벤트를 실제 InputMap 경로로 흘려보내
# 밭갈기->클릭 경작->물주기->파종->자원->설치->상점->결산까지 자동 재생한다.
#
# ※ 단계 번호는 match의 값이다. **절대 겹치면 안 된다** —
#    같은 번호를 두 번 쓰면 뒤에 쓴 쪽이 통째로 죽은 코드가 되고,
#    검사가 조용히 사라진다 (실제로 세 번 당했다).
#    새 단계를 넣기 전에: grep -n "^\t\t[0-9]\+:" 로 빈 번호를 확인할 것.

# 지도 끌기 성능 재기 (393~405단계)
var _tut_map_snapped := false
var _tut_map_done := false
var _bench_us := 0
var _bench_n := 0
var _bench_t0 := 0


# `_process`를 직접 여러 번 불러 시간을 재는 단계가 있다. 그런데 `_process`의
# 마지막 줄이 이 함수라, 그대로 두면 **재는 동안 다음 단계들이 안에서 실행된다** —
# 마을을 통째로 다시 세우는 단계가 걸리면 「한 프레임 10ms」로 잘못 읽힌다.
# 재는 동안에는 시퀀스를 멈춘다.
var _perf_probe := false

# 저장에는 적지만 **일부러 읽지 않는** 열쇠 (SAVEKEYS_OK 의 예외).
# 여기 이름을 올릴 때는 왜 안 읽어도 되는지 한 줄로 남길 것.
const SAVE_WRITE_ONLY := [
	"grid", "objects", "animals",       # 세계 — _apply_save 가 따로 푼다
	"player_x", "player_y",             # 사람 자리 — 위와 같다
	"grid_w", "grid_h",                 # 세계 크기 — 다시 지을 때 정해진다
]


func _debug_tick() -> void:
	if _perf_probe:
		return
	if OS.get_environment("KYOJIN_MP") != "":
		_mp_tick()
		return
	if OS.get_environment("KYOJIN_REEL") != "":
		_shot_frames += 1
		_reel_tick()
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
			# 튜토리얼 전용 공간: 여기가 지금 세계의 전부다.
			# 마을 쪽으로는 한 칸도 갈 수 없고, 지도에도 이 띠만 뜬다.
			var tut_out: bool = GameData.tutorial_space \
				and m.STORY_SPAWN.y >= m.WORLD_H     # 시작 자리가 세계 밖이다
			var tut_walk: bool = m.is_passable(m.STORY_SPAWN + Vector2i(1, 0)) \
				and m.is_passable(m.STORY_SPAWN + Vector2i(0, 1))
			# 마을·광장·농장 어디로도 이어지지 않는다 (연결로가 아예 없다)
			var no_village: bool = not m.is_passable(Vector2i(52, 9)) \
				and not m.is_passable(Vector2i(78, 20)) \
				and not m.is_passable(m.START_TILE) \
				and not m.is_passable(Vector2i(m.STORY_SPAWN.x, m.WORLD_H - 1))
			# 지도가 보여 주는 땅도 이 띠뿐 — 마을 칸은 구름조차 그리지 않는다
			var map_tut: bool = m.world_rect() == m.TUTORIAL_REGION \
				and not m.map_ui._visible_tile(52, 9) \
				and m.map_ui._visible_tile(m.STORY_SPAWN.x, m.STORY_SPAWN.y)
			print("TUTSPACE_OK=", tut_out and tut_walk and no_village and map_tut,
				" 세계밖=", tut_out, " 숲길통행=", tut_walk,
				" 마을차단=", no_village, " 지도격리=", map_tut)
			# 새 게임 초기 마을: 건물은 다 서 있고(짓기 없음) 주인들도 첫날부터 있다
			var houses := 0
			for hp in m.objects:
				if String(m.objects[hp].kind) == "house":
					houses += 1
			var nids: Array = []
			for n2 in m.npcs:
				nids.append(n2.id)
			nids.sort()
			var hut0: bool = str(m.objects.get(m.CHIEF_HUT, {}).get("kind", "")) \
				== "chief_hut" and GameData.chief_house_lv == 0
			# 새 게임에는 낡은 표지판이 서 있고, 동쪽 확장 구역은 잠겨 있다
			var zone0: bool = str(m.objects.get(m.OLD_SIGN, {}).get("kind", "")) == "sign" \
				and GameData.story4_phase == "" \
				and not GameData.is_tile_owned(105, 10 + m.NORTH_PAD) \
				and not m.is_passable(Vector2i(105, 10 + m.NORTH_PAD))   # 동쪽 확장 구역 안의 칸(NORTH_PAD 포함)
			var owners_here := true
			for own9: String in GameData.START_GREETED:
				if own9 not in nids:
					owners_here = false
			# 새터말(S3b) — 초원에 빈 집터 여덟이 처음부터 있다: 장부·팻말·둘레 7×6 이 맨 풀밭.
			# 옛 마을 너머가 닫혀 있는 동안은 자리로 세지 않는다(재민의 이사는 내 집터로만)
			var plots8 := 0
			var plot_bad: Array = []
			for pa: Vector2i in GameData.MEADOW_PLOTS:
				var listed: bool = GameData.plot_fixed_at(pa) and not GameData.meadow_plot_used(pa)
				var sign_ok9: bool = str(m.objects.get(m.door_tile(pa), {}).get("kind", "")) == "homeplot"
				var clear9 := true
				for py9 in range(pa.y - 1, pa.y + 5):
					for px9 in range(pa.x - 1, pa.x + 6):
						var t9 := Vector2i(px9, py9)
						if m.grid[py9][px9].ground != "grass" or (m.objects.has(t9) and t9 != m.door_tile(pa)):
							clear9 = false
				if listed and sign_ok9 and clear9:
					plots8 += 1
				else:
					plot_bad.append([pa, listed, sign_ok9, clear9])
			var meadow_ok: bool = plots8 == 8 and GameData.first_empty_plot().x < 0
			print("VILLAGE_INIT_OK=", GameData.village_built.size() == GameData.ALL_VILLAGE_PLOTS.size()
				and houses >= 9 * 20 and "chief" in nids and owners_here and hut0 and zone0 and meadow_ok,
				" 건물=", GameData.village_built, " 지붕칸=", houses, " NPC=", nids,
				" 이장오두막=", hut0, " 동쪽구역잠김=", zone0, " 새터말=", meadow_ok, plot_bad)
		elif m.story._story_snapped and not _tut_map_snapped and m.story._story_t >= 3.6:
			_tut_map_snapped = true
			m.map_ui.open()
			m.map_ui.reset_view()
		elif _tut_map_snapped and not _tut_map_done and m.story._story_t >= 4.0:
			_tut_map_done = true
			_save_shot("story_map.png")
			# 튜토리얼 지도: 「내 위치」가 실제로 지나온 숲길 위에 찍혀야 한다
			# 서 있는 칸이 지도에 드러나 있어야 한다 (마커만 검은 벌판에 뜨면 안 된다)
			var pt9: Vector2i = m.player_tile()
			var here_lit: bool = m.map_ui._visible_tile(pt9.x, pt9.y)
			# 지나온 길도 드러나 있다
			var road_lit := 0
			for rx9 in range(m.STORY_ROAD_X0, pt9.x + 1):
				if m.map_ui._visible_tile(rx9, m.STORY_LANE_Y):
					road_lit += 1
			# 이름패에 아직 마을 이름은 없다 (본 적도 들은 적도 없는 곳이다)
			var plate9: String = m.map_ui.map_plate()
			print("TUTMAP_OK=", here_lit and road_lit >= 1
				and not plate9.contains("교진"),
				" 선 자리 밝음=", here_lit, " 지나온 길=", road_lit, "칸",
				" 이름패=", plate9)
			m.map_ui.close()
		elif _tut_map_done and m.story._story_t >= 4.3:
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
			GameData.aff_set("merchant", 60)
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
			m.dialog.close()                            # 건물은 처음부터 다 서 있다
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
		201:
			# ---- 장부가 맞는가 ----
			#
			# `produce` 는 총량이고 `produce_silver`/`produce_gold` 는 그
			# **부분집합**이다 (add_produce 참고). 그런데 상점 판매는 셋을
			# 서로소로 여겨 총량을 일반가로 다 팔고 은·금을 또 팔았다 —
			# 딸기 다섯(은둘·금하나)이 여섯 개 값이 아니라 아홉 개 값이었다.
			#
			# 세율도 봉급도 예산도 전부 이 숫자 위에 선다. 그래서 여기서
			# **적어 놓은 값과 손에 들어온 돈이 한 푼도 안 틀리는지** 못박는다.
			# 이 줄이 깨지면 그 위의 모든 수치가 거짓이다.
			#
			# 연구소 개량(단계마다 +8%)도 함께 건다. 예전엔 값을 적어 두는
			# 쪽만 개량을 곱하고 파는 쪽은 안 곱해서, 돈과 광석을 들여 올린
			# 개량이 수입을 한 푼도 못 올리고 있었다.
			m.shop.open("sell", ["buy", "sell"], "장부 검산")   # _rebuild 가 붙을 창
			var _eco_id := "strawberry"
			var _eco_breed_keep: int = GameData.breed_level
			GameData.breed_level = 2                # 판매가 +16%
			GameData.produce[_eco_id] = 0
			GameData.produce_silver[_eco_id] = 0
			GameData.produce_gold[_eco_id] = 0
			for _q in [0, 0, 1, 1, 2]:              # 일반2 · 은2 · 금1
				GameData.add_produce(_eco_id, _q)
			# 개당 값을 손으로 센 것과 맞춰 본다 (crop_unit_price 자기 자신과
			# 비교하면 아무것도 검사하지 않는 셈이 된다)
			var _eco_raw: float = float(GameData.CROPS[_eco_id].sell_price) * 1.16
			var _eco_hand: int = 2 * int(_eco_raw) + 2 * int(_eco_raw * 1.25) \
				+ int(_eco_raw * 1.5)
			var _eco_want: int = GameData.produce_sell_value(_eco_id)
			var _eco_max: int = m.shop._sell_qty_max("crop", _eco_id)
			var _eco_panel: int = m.shop._sell_qty_value("crop", _eco_id, _eco_max)
			var _eco_before: int = GameData.money
			m.shop.sell_mult = 1.0
			m.shop._on_sell(_eco_id, _eco_max)
			var _eco_got: int = GameData.money - _eco_before
			# 판 뒤에는 셋 다 0 이어야 한다 (남으면 다음 날 또 팔린다)
			var _eco_empty: bool = int(GameData.produce[_eco_id]) == 0 \
				and int(GameData.produce_silver.get(_eco_id, 0)) == 0 \
				and int(GameData.produce_gold.get(_eco_id, 0)) == 0
			m.shop.close()
			GameData.breed_level = _eco_breed_keep
			print("ECON_BASE_OK=", _eco_got == _eco_want and _eco_panel == _eco_want
				and _eco_want == _eco_hand and _eco_max == 5 and _eco_empty,
				" 받은돈=", _eco_got, " 셈한값=", _eco_want,
				" 손셈=", _eco_hand, " 패널합계=", _eco_panel,
				" 팔수있는수=", _eco_max, " 비었나=", _eco_empty)
		207:
			# ---- 담아만 두고 읽지 않는 열쇠가 있는가 ----
			#
			# build_save 는 백 몇 개를 꼬박꼬박 적는데, _apply_save 가 그중
			# **여덟 개를 읽지 않고 있었다.** 결혼해 놓고 하루 자고 오면
			# 남이 되어 있었고, 평생 수확 기록과 도감 완성이 지워졌다.
			#
			# 백 개를 눈으로 맞추는 일은 또 틀린다. 그래서 기계가 맞춘다 —
			# 적은 열쇠 하나하나가 불러오기 코드 어딘가에 이름으로 나오는지
			# 본다. 새 열쇠를 넣고 읽는 쪽을 잊으면 여기서 걸린다.
			var _sk_saved: Dictionary = GameData.build_save([], Vector2.ZERO)
			var _sk_src := ""
			var _sk_f := FileAccess.open("res://scripts/save_load.gd", FileAccess.READ)
			if _sk_f != null:
				_sk_src = _sk_f.get_as_text()
				_sk_f.close()
			var _sk_miss: Array = []
			for _sk_k: String in _sk_saved.keys():
				if _sk_k in SAVE_WRITE_ONLY:
					continue
				if not (_sk_src.contains("\"%s\"" % _sk_k)
						or _sk_src.contains("d.%s" % _sk_k)):
					_sk_miss.append(_sk_k)
			print("SAVEKEYS_OK=", _sk_miss.is_empty() and _sk_src != "",
				" 적어만 두고 안 읽는 열쇠=", _sk_miss,
				" 담는 열쇠=", _sk_saved.size(), "개")
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
			var wr8: Rect2i = m.world_rect()
			var mrect := Rect2(org + Vector2(wr8.position) * pc,
				Vector2(wr8.size) * pc)
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
			# 고장 사람 여섯과 읍 사람 아홉(S4c)은 교진 주민이 아니다 — 세지 않는다 (main.village_residents)
			var hamlet_n := 0
			for nh in m.npcs:
				if str(nh.id) in m.HAMLET_NPC_IDS or str(nh.id) in m.TOWN_NPC_IDS:
					hamlet_n += 1
			var res_ok: bool = res0 == m.npcs.size() + 1 - hamlet_n
			# 새 집 업그레이드 (아침 훅과 같은 조건·코드)
			var can_up: bool = GameData.chief_house_lv == 0 \
				and res0 >= GameData.CHIEF_HOUSE_RESIDENTS
			GameData.chief_house_lv = 1
			m.objnode._remove_object(m.CHIEF_HUT)
			m.objnode._place_object(m.CHIEF_HUT, "chief_hut", 0)
			var up_ok: bool = can_up and GameData.chief_house_lv == 1 \
				and str(m.objects.get(m.CHIEF_HUT, {}).get("kind", "")) == "chief_hut"
			# 마을회관: 서 있지만 스토리 9(주민 초대)를 밟기 전엔 문이 닫혀 있다
			var keep_s9: String = GameData.story9_phase
			GameData.story9_phase = ""
			var gate_before: bool = not GameData.hall_feature_open("office") \
				and GameData.story9_objective_short() == ""
			var dummies: Array = []                 # 임시 주민을 10명 초과까지 채운다
			while m.village_residents() <= GameData.HALL_RESIDENTS:
				m.npcmgr._spawn_npc("forest_girl", Vector2i(74, 22))
				dummies.append(m.npcs[m.npcs.size() - 1])
			GameData.story9_phase = "build"         # 스토리 9의 개관식 단계
			var gate_after: bool = m.village_residents() > GameData.HALL_RESIDENTS \
				and GameData.story9_objective_short().contains("접수대")
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
			# 우체국은 처음부터 서 있다 — 3장의 마지막 퀘스트는 우체부에게 인사하러 가는 것
			var k_built3: Array = GameData.village_built.duplicate()
			# 스토리 3 시점엔 옛 마을 너머가 닫혀 있다 — 새터말(S3b)의 집터가 재민의 자리로 세이면 안 된다
			var k_s4_mv := GameData.story4_phase
			GameData.story4_phase = ""
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

			# ── 3-③ 「우체국의 우체부 아저씨에게」 — 3장의 마지막 퀘스트 (우체국은 서 있다)
			var post_gated: bool = GameData.move_quest == "post"
			m.story._start_move_post_dialog()
			m.dialog.skip_seq()
			m.dialog.close()
			var post_open: bool = GameData.move_quest == "postgreet"
			var built_post: bool = GameData.village_built.has("post") \
				and str(m.objects.get(m.VILLAGE_PLOTS["post"].anchor, {})
					.get("kind", "")) == "house"
			# 우체부는 첫날부터 마을에 있다 — 찾아오는 대기열 없이 우체국에서 만난다
			var post_arrival: bool = GameData.move_quest == "postgreet" and GameData.arrivals.is_empty()
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
			GameData.story4_phase = k_s4_mv
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
			GameData.aff_set("forest_mom", GameData.FOREST_TRUST_AFF - 1)
			m.story._forest_trust_update(0.016)
			var trust_gate: bool = GameData.forest_trust == ""
			GameData.aff_set("forest_mom", GameData.FOREST_TRUST_AFF)
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
			GameData.aff_set("forest_mom", k_aff5)
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
			var aff_m := GameData.aff("forest_mom")
			m.village._mom_quest_turnin("_test")
			var served: bool = GameData.mom_quest == "" \
				and "_test" in GameData.mom_quests_done \
				and GameData.money == money_m + 120 \
				and GameData.aff("forest_mom") == aff_m + 4 \
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
		200:
			# 자동 저장 — 15분(실제 시간)마다 알아서 담는다.
			# 15분을 기다릴 수는 없으니 그만큼의 시간을 **한 번에 흘려** 본다.
			var sp: String = GameData.SAVE_PATH
			if FileAccess.file_exists(sp):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
			# ① 이야기 연출 중에는 미룬다 (그 한복판을 담을 이유가 없다)
			m.story_cutscene = true
			m.saveio.autosave_tick(m.saveio.AUTO_EVERY)
			var held: bool = not FileAccess.file_exists(sp)
			m.story_cutscene = false
			# ② 연출이 끝나면 미뤄 둔 만큼만 더 흘려도 담긴다
			m.saveio.autosave_tick(m.saveio.AUTO_RETRY)
			var saved: bool = FileAccess.file_exists(sp)
			# ③ 담고 나면 15분을 다시 센다 (안 그러면 매 프레임 담는다)
			var reset: bool = m.saveio._auto_t < 1.0
			print("AUTOSAVE_OK=", held and saved and reset,
				" 연출중엔미룸=", held, " 담김=", saved,
				" 시계리셋=", reset, " 주기=", m.saveio.AUTO_EVERY)
		224:
			# 캡슐·배너에 쓸 **UI 없는 화면**.
			# 보통 스크린샷에는 미니맵·퀘스트창·대사줄·말풍선이 얹혀 있어서,
			# 오려 쓸 수 있는 빈 띠가 100px대밖에 안 남는다. 그걸 늘려 캡슐을
			# 만들면 흐릿해진다 (brand/make_brand.js가 이걸 재서 경고한다).
			# 그래서 UI를 잠깐 다 끄고 한 장 찍어 둔다.
			m.player.position = Vector2(74 * m.TILE + 16, 21 * m.TILE + 16)   # 광장
			(m.player.get_node("Camera") as Camera2D).reset_smoothing()
			m.player.dir = "down"
			_ui_saved.clear()
			for c: Node in m.find_children("", "CanvasLayer", true, false):
				if (c as CanvasLayer).visible:
					_ui_saved.append(c)
					(c as CanvasLayer).visible = false
		225:
			_save_shot("_clean.png")
			for c: Node in _ui_saved:
				(c as CanvasLayer).visible = true
			_ui_saved.clear()
		# ==== S1 「불리는 사람」 — 사회 검사 (226~231, 스크린샷 없음) ====
		#
		# society.gd 와 game_data 의 사회 블록을 재는 여섯 단계. 전부 같은 규약이다:
		#   · _soc_keep() 으로 me·자리·지갑·호감도·숙련·작물·돈·날·시각·기력·이름·연출·
		#     호감도 해금·자리·축제·대화 기록을 맡겨 두고, 끝에 _soc_restore() 로 전부 되돌린다.
		#     되돌린 뒤 society_loaded() 가 호칭 기준선을 다시 잡는다 — 안 그러면 다음 아침
		#     결산에 거짓 「사람들이 요즘 나를…」 줄이 뜬다 (D9)
		#   · 호감도는 aff_add 로만 심고, 경계값(20·30·70) **바로 아래**로는 심지 않는다 —
		#     _talk_to 가 하루 첫 대화에 +2 를 더하므로 28 은 30 이 되어 계급이 바뀐다
		#   · 하루 넘김은 GameData.day += 1; society_new_day([0, 0, 0]) — day_cycle 과 같은 순서
		#   · 선택지는 society 의 핸들러를 직접 부른다 (버튼을 누르는 대신)
		226:
			# ① TITLE_OK — 호칭 체인(헌법 §4.2). 열 계급이 위에서부터 첫 참으로 갈리고, 하루 첫
			# 대화의 첫 페이지가 그 호칭을 NPC 의 입으로 말한다 (D1). 기대 첫마디는 _talk_to
			# **전에** call_opener 로 계산한다 — 하루 안에서 결정적이라 같은 줄이어야 하고,
			# 줄바꿈 모양은 같은 _paginate_seq 를 지나게 해 맞춘다 (_title_probe)
			m.dialog.close()
			var kp: Dictionary = _soc_keep()
			var mer: Node2D = _npc_node("merchant")
			if mer == null:
				print("TITLE_OK=false 광장에 만수가 없다")
				_soc_restore(kp)
			else:
				m.story_cutscene = true            # 곁의 주민과 삼자 대화가 되지 않게
				GameData.fest_done = true          # 축제 인사 경로를 막는다
				GameData.affinity_open = true
				GameData.player_name = "하네스"
				GameData.minutes = 10.0 * 60.0     # 온천·저녁 대사 경로를 피한다
				GameData.kitchen_quest = "done"    # 조리대 이야기가 만수 대화를 가로채지 않게
				# 자유직 재료를 전부 비운다 — 샌드박스의 벌목·낚시 기록이 free_known 을 먼저 만든다
				GameData.crops_harvested = {}
				GameData.trees_chopped = 0
				GameData.rocks_mined = 0
				GameData.fish_caught = {}
				GameData.recipes_cooked = {}
				GameData.forage_caught = {}
				GameData.mob_kills = {}
				GameData.animals_now = 0
				GameData.me = GameData.fresh_me()
				GameData.me.boldness_base = 25
				var d: int = GameData.day
				var fails: Array = []
				# 10 낯선 사람 — 아무것도 아닌 사람
				GameData.aff_add("merchant", -GameData.aff("merchant"))
				fails.append(_title_probe(mer, "stranger"))
				# 9 이름 — 호감 30 (35 로 심는다)
				GameData.aff_add("merchant", 35 - GameData.aff("merchant"))
				fails.append(_title_probe(mer, "name"))
				# 8 자유직 — 농부 문턱(수확 100), 이름보다 먼저다
				GameData.crops_harvested = {GameData.CROP_IDS[0]: 100}
				fails.append(_title_probe(mer, "free_known"))
				# 7 우리 마을 농부 양반 — 호감 70
				GameData.aff_add("merchant", 70 - GameData.aff("merchant"))
				fails.append(_title_probe(mer, "free_master"))
				# 5 직함 — 근속 14일(D5). 주인의 첫마디는 boss_calls 로 간다 (부록 §2)
				GameData.me.job = "general_clerk"
				GameData.me.rank = "clerk"
				GameData.me.job_since_day = d - 14
				GameData.aff_add("merchant", 40 - GameData.aff("merchant"))
				fails.append(_title_probe(mer, "office"))
				GameData.aff_add("merchant", 70 - GameData.aff("merchant"))
				var master_ok: bool = str(GameData.player_title("merchant").text) == "우리 점원"
				# 6 전직 — 그만둔 지 이레 안
				GameData.me.job = ""
				GameData.me.rank = ""
				GameData.me.job_history = [{"inst": "general", "rank": "clerk",
					"job": "general_clerk", "from": d - 30, "to": d - 1, "reason": "quit"}]
				GameData.aff_add("merchant", -GameData.aff("merchant"))
				GameData.crops_harvested = {}
				fails.append(_title_probe(mer, "ex"))
				# 4 그 일 있던 사람
				GameData.me.job_history = []
				GameData.me.jail_days_left = 3
				fails.append(_title_probe(mer, "jailed"))
				# 3 소문의 그 사람 — heat 2 기억이 하루 지났고, 만수는 본 사람이 아니다
				GameData.me.jail_days_left = 0
				GameData.me.memories = [{"day": d - 1, "kind": "pickpocket", "heat": 2,
					"witnesses": ["chief"], "forgiven": false, "settled": "", "reported_day": 0,
					"target": "chief", "value": 20, "region": "kyojin"}]
				fails.append(_title_probe(mer, "heard"))
				# 2 그 사람 — 만수가 봤다. 직함을 겹쳐 놓아도 목격이 먼저다
				GameData.me.memories[0].witnesses = ["merchant"]
				GameData.me.memories[0].heat = 1
				GameData.me.job = "general_clerk"
				GameData.me.rank = "clerk"
				GameData.me.job_since_day = d - 14
				fails.append(_title_probe(mer, "seen"))
				# 1 살인자 — 말소되지 않은 기록
				GameData.me.record = [{"day": d, "crime": "murder", "court": "court",
					"verdict": "guilty", "sentence": 0, "served": 0, "served_day": 0,
					"expunged": false}]
				fails.append(_title_probe(mer, "murderer"))
				# 같은 날 두 번째 대화 — 첫마디 페이지 없이 곧장 대사와 선택지다
				var opener0: Array = m.dialog._paginate_seq(
					[{"text": GameData.call_opener("merchant")}])
				mer.talked_today = true
				m.village._talk_to(mer)
				var seq2: Array = m.dialog._seq
				var retalk_ok: bool = m.society.talk_opener("merchant", false) == "" \
					and not seq2.is_empty() and seq2[-1].has("choices") \
					and str(seq2[0].text) != str(opener0[0].text)
				m.dialog.close()
				var bad: Array = fails.filter(func(s: String) -> bool: return s != "")
				_soc_restore(kp)
				print("TITLE_OK=", bad.is_empty() and master_ok and retalk_ok,
					" 계급=", 10 - bad.size(), "/10 어긋남=", bad,
					" 우리점원=", master_ok, " 재대화=", retalk_ok)
		227:
			# ② CLERK_LOOP_OK — 채용(자리가 진실, 헌법 §0.1) → 이레 근무(몫은 적립만) → 봉급날
			# 창구 앞에서 수령(§0.3) → 이레 결근이면 해고. 돈은 봉급을 받는 그 순간에만 움직인다
			m.dialog.close()
			var kp: Dictionary = _soc_keep()
			m.story_cutscene = false           # counter_menu 는 연출 중이면 물러선다 (D2)
			GameData.affinity_open = true
			GameData.kitchen_quest = "done"    # 조리대 이야기가 계산대를 가로채지 않게 (D2)
			GameData.minutes = 10.0 * 60.0
			GameData.me = GameData.fresh_me()
			GameData.me.boldness_base = 25
			GameData.skills["farm"].lv = 2     # 채용 조건 농사 Lv2 — add_skill_xp 는 잠자리 알림을 남긴다
			GameData.aff_add("merchant", 20 - GameData.aff("merchant"))
			if not GameData.npc_greeted.has("merchant"):
				GameData.npc_greeted.append("merchant")
			GameData.seats = {}
			var money0: int = GameData.money
			var hire_day: int = GameData.day
			var why: String = m.society.can_hire("general")
			m.society.hire("general")
			m.dialog.close()
			var d0: int = int(GameData.me.job_since_day)
			# 고용된 채 광장의 내 주인에게 「일자리 이야기」가 끼지 않는다(사직은 계산대에)
			var own_ch: Array = [["대화 끝", null]]
			m.society.add_talk_choices("merchant", own_ch)
			var own_boss_ok: bool = own_ch.filter(
				func(c: Array) -> bool: return str(c[0]).contains("일자리")).is_empty()
			var hire_ok: bool = why == "" and str(GameData.me.job) == "general_clerk" \
				and GameData.seat_of("general", "clerk") == "player" \
				and d0 == hire_day + 1 and int(GameData.me.wage_day) == hire_day + 8 \
				and own_boss_ok
			# 이레 근무 — 계산대 E 의 첫 메뉴에 「근무」가 있고, 손님 한 사람을 맞으면 그날은 끝
			var loop_ok := true
			var loop_why := ""
			for i in range(1, 8):
				GameData.day = d0 + i - 1
				GameData.society_new_day([0, 0, 0])
				GameData.minutes = 10.0 * 60.0
				m.shop_room.open("general")
				var menu: bool = m.society.counter_menu("general")
				var has_work := false
				for c in m.dialog.buttons_box.get_children():
					if c is Button and not c.is_queued_for_deletion() \
							and (c as Button).text == "근무":
						has_work = true
				m.dialog.close()
				m.society.work_start()
				var guest_shown: bool = m.dialog.visible
				m.society.work_pick(i % 3)
				var closed_today: bool = m.society.can_work() != ""
				m.dialog.close()
				m.shop_room.close()
				if not (menu and has_work and guest_shown and closed_today):
					loop_ok = false
					loop_why += "%d일째(메뉴 %s·근무버튼 %s·손님 %s·마감 %s) " % [
						i, menu, has_work, guest_shown, closed_today]
			var log: Array = GameData.me.work_log
			var work_ok: bool = int(GameData.me.perf) == 7 and int(GameData.me.wage_pending) == 560 \
				and not log.is_empty() and int(log[-1].day) == d0 + 6
			# 봉급날 아침 — 결산 한 줄(루프 밖에서 한 번만 읽는다), 그리고 주인 앞에서 받는다
			GameData.day = d0 + 7
			GameData.society_new_day([0, 0, 0])
			var note: String = GameData.society_note()
			GameData.minutes = 10.0 * 60.0
			m.shop_room.open("general")
			var ready: bool = m.society.wage_ready()
			m.society.collect_wage()
			m.dialog.close()
			m.shop_room.close()
			var pay_ok: bool = ready and note.contains("봉급날") and GameData.money - money0 == 560 \
				and int(GameData.me.wage_pending) == 0 and int(GameData.me.wage_day) == d0 + 14
			# 이레 결근 — 자리가 비고 이력에 남고 평판 −8
			var rep0: int = int(GameData.me.reputation.kyojin)
			for j in 7:
				GameData.day += 1
				GameData.society_new_day([0, 0, 0])
			var hist: Array = GameData.me.job_history
			# 해고 당일: 옛 주인의 첫마디는 hire.fired, 다시 묻는 채용은 「그만둔 지 이레도…」
			var fired_line: String = m.society.talk_opener("merchant", true)
			var fired_line_ok: bool = fired_line != "" \
				and fired_line == str(GameData.JOBS.general_clerk.hire.fired)
			var wait_ok: bool = m.society.can_hire("general").contains("이레")
			var fired_ok: bool = str(GameData.me.job) == "" \
				and GameData.seat_of("general", "clerk") == "" \
				and not hist.is_empty() and str(hist[-1].reason) == "fired" \
				and int(GameData.me.reputation.kyojin) == rep0 - 8 \
				and fired_line_ok and wait_ok
			_soc_restore(kp)
			print("CLERK_LOOP_OK=", hire_ok and loop_ok and work_ok and pay_ok and fired_ok,
				" 채용=", hire_ok, "(", why, ") 근무=", loop_ok, " ", loop_why,
				" 적립=", work_ok, " 봉급=", pay_ok, "(", note.replace("\n", " / "), ")",
				" 해고=", fired_ok, "(첫마디 ", fired_line_ok, " 대기 ", wait_ok, ")")
		228:
			# ③ PICKPOCKET_OK — 범죄의 파이프라인: 강제 실패 → 「그 사람」(seen) → 다음날 아침
			# 이장이 찾아오고(meeting) → 자백 → 봉사 사흘 → 용서(seen 소멸). 이어 강제 성공 —
			# 본 사람이 없으면 기억도 없다 (D23). 주사위는 인자로 고정한다
			m.dialog.close()
			var kp: Dictionary = _soc_keep()
			var mer: Node2D = _npc_node("merchant")
			if mer == null:
				print("PICKPOCKET_OK=false 광장에 만수가 없다")
				_soc_restore(kp)
			else:
				GameData.me = GameData.fresh_me()
				GameData.me.boldness_base = 40
				GameData.me.boldness_state = 0.0
				GameData.affinity_open = true
				m.story_cutscene = true
				GameData.minutes = 10.0 * 60.0
				# 목격자가 없는 자리 — 둘을 지도 구석으로 옮긴다(다른 사람에게서 일곱 칸 넘게).
				# 자리는 _soc_keep 이 맡아 두었다
				var far := Vector2(2 * m.TILE + 16, 2 * m.TILE + 16)
				mer.position = far
				m.player.position = far + Vector2(m.TILE, 0)
				GameData.npc_wallet["merchant"] = 50
				var d1: int = GameData.day
				m.society.pickpocket("merchant", 1.0)      # 굴림 1.0 — 반드시 실패
				var fail_shown: bool = m.dialog.visible
				m.dialog.close()
				var mems: Array = GameData.me.memories
				var fail_ok: bool = mems.size() == 1 and str(mems[0].target) == "merchant" \
					and str(mems[0].witnesses[0]) == "merchant" \
					and int(mems[0].reported_day) == d1 \
					and float(GameData.me.theft_xp) == 2.0 \
					and float(GameData.me.boldness_state) == 1.0 \
					and str(GameData.player_title("merchant").cls) == "seen"
				# 다음날 아침 — 축제날이면 회의가 없으니 하루 더 넘긴다 (루프 안에서 note 를 읽지 않는다)
				GameData.day += 1
				GameData.society_new_day([0, 0, 0])
				var skipped := 0
				while not GameData.festival_today().is_empty() and skipped < 40:
					GameData.day += 1
					GameData.society_new_day([0, 0, 0])
					skipped += 1
				GameData.minutes = 10.0 * 60.0     # 회의는 09~17시 — 시각을 놓은 뒤에 묻는다
				var meet_ok: bool = GameData.council_pending() \
					and GameData.society_place("chief") == "meeting"
				var note: String = GameData.society_note()
				m.society.open_council()
				var council_shown: bool = m.dialog.visible
				m.society.council_pick("confessed")
				m.dialog.close()
				var rec: Array = GameData.me.record
				# 실패 +1 → 아침 감쇠 0.0 → 자백 bold_add(−5) = −5.0 (⑦ 순서 고정)
				var confess_ok: bool = not rec.is_empty() and str(rec[-1].court) == "village" \
					and int(rec[-1].sentence) == 3 \
					and float(GameData.me.boldness_state) == -5.0
				# 자백 다음날 아침은 option.outcome 한 줄(부록 §4)이고 「봉사하는 날」은 겹치지
				# 않는다; 그 다음 아침부터는 「봉사하는 날」이 뜬다 (첫 봉사 전에도)
				var outcome_note := ""
				var serve_note := ""
				for j in 3:
					GameData.day += 1
					GameData.society_new_day([0, 0, 0])
					if j == 0:
						outcome_note = GameData.society_note()
					elif j == 1:
						serve_note = GameData.society_note()
					GameData.minutes = 10.0 * 60.0
					m.society.serve_day()
					m.dialog.close()
				var outcome_ok: bool = outcome_note.contains("사흘") \
					and not outcome_note.contains("봉사하는 날") \
					and serve_note.contains("봉사하는 날")
				rec = GameData.me.record
				mems = GameData.me.memories
				var serve_ok: bool = not rec.is_empty() and int(rec[-1].served) == 3 \
					and not mems.is_empty() and bool(mems[0].forgiven) \
					and int(GameData.me.service_days) == 3 \
					and str(GameData.player_title("merchant").cls) != "seen" \
					and outcome_ok
				# 성공 경로 — 혼자였으니 기억이 없고, 지갑에서 그만큼만 빠진다
				GameData.me.memories = []
				GameData.npc_wallet["merchant"] = 50
				m.society.force_report = 1.0
				var money1: int = GameData.money
				var take: int = mini(50, 10 + 3 * GameData.theft_lv())
				m.society.pickpocket("merchant", 0.0)      # 굴림 0.0 — 반드시 성공
				m.dialog.close()
				var quiet := true
				for mm in GameData.me.memories:
					if int(mm.reported_day) > 0 or (mm.witnesses as Array).is_empty():
						quiet = false
				var win_ok: bool = GameData.money - money1 == take \
					and int(GameData.npc_wallet.get("merchant", -1)) == 50 - take and quiet
				_soc_restore(kp)
				print("PICKPOCKET_OK=", fail_ok and fail_shown and meet_ok and note.contains("이장")
					and council_shown and confess_ok and serve_ok and win_ok,
					" 실패=", fail_ok, " 회의=", meet_ok, " 결산=", note.contains("이장"),
					"(", note.replace("\n", " / "), ") 자백=", confess_ok, " 봉사=", serve_ok,
					"(다음날 ", outcome_note.replace("\n", " / "), ") 성공=", win_ok,
					" 건너뛴 축제=", skipped)
		229:
			# ④ NIGHT_OK — 21시에 밖에 남는 사람은 NIGHT_OWLS 뿐이고(교집합 비교, 임시 스폰 없음,
			# D12), 22시가 넘으면 그들도 들어간다. 자리는 society_place 가 준다(악사 광장·강태 부두)
			m.dialog.close()
			var kp: Dictionary = _soc_keep()
			GameData.minutes = 21.0 * 60.0
			for n1 in m.npcs:
				n1._process(0.016)
			var owls: Array = []
			var vis: Array = []
			for n2 in m.npcs:
				if n2.scripted:
					continue
				if str(n2.id) in GameData.NIGHT_OWLS:
					owls.append(str(n2.id))
				if n2.visible:
					vis.append(str(n2.id))
			owls.sort()
			vis.sort()
			var same: bool = owls == vis and vis.size() <= 3
			var place_ok := true
			if "musician" in owls:
				place_ok = place_ok and m.npcmgr.npc_place_now("musician") == "plaza"
			if "angler" in owls:
				place_ok = place_ok and m.npcmgr.npc_place_now("angler") == "pier"
			GameData.minutes = 22.0 * 60.0 + 1.0
			for n3 in m.npcs:
				n3._process(0.016)
			var late: Array = []
			for n4 in m.npcs:
				if str(n4.id) in GameData.NIGHT_OWLS and n4.visible and not n4.scripted:
					late.append(str(n4.id))
			_soc_restore(kp)                # 시각과 보이기를 되돌린다
			for n5 in m.npcs:
				n5._process(0.016)          # 낮 시각으로 한 번 더 — 일과가 제자리로
			print("NIGHT_OK=", same and place_ok and late.is_empty(),
				" 21시 밖=", vis, " 밤사람=", owls, "(", owls.size(), "명) 자리=", place_ok,
				" 22시 남은 밤사람=", late)
		230:
			# ⑤ NPC_ACCESS_OK — 규율: NPC 표·호감도의 직접 첨자(NPCS·NPC_KIND·affinity 의 [ ])는
			# 더 늘지 않는다. 새 코드는 npc_def/npc_kind/aff/aff_add 만 쓴다(계약서 §4) —
			# society.gd 와 player_actions.gd 는 0 이어야 한다. BASELINE 은 2026-09-09 실측:
			#   grep -c "GameData.NPCS\[\|NPC_KIND\[\|affinity\[" scripts/*.gd   (dev_harness.gd 제외)
			# game_data 의 11 은 첨자 10(기존 9 + aff_add) 에 그 규율을 적은 주석 한 줄이 더해진 값이다
			# 패턴은 이어 붙여 만든다 — 이 줄이 제 검사에 걸리지 않게
			m.dialog.close()
			var kp: Dictionary = _soc_keep()
			var pats: Array = ["GameData.NPCS" + "[", "NPC_KIND" + "[", "affinity" + "["]
			# S4a 리팩터 뒤의 기준선 — game_data 는 접근자 구현(aff_add·aff_set)·초기화·로드 넷 + 규율 주석 한 줄,
			# save_load 는 세이브 사전(d.affinity)을 읽는 둘. 나머지 파일은 0 이어야 한다
			var baseline := {"game_data": 5, "save_load": 2}
			var counts := {}
			var over: Array = []
			for fn in DirAccess.get_files_at("res://scripts"):
				if not fn.ends_with(".gd") or fn == "dev_harness.gd":
					continue
				var src := FileAccess.open("res://scripts/" + fn, FileAccess.READ)
				if src == null:
					continue
				var hits := 0
				for line in src.get_as_text().split("\n"):
					for p in pats:
						if line.contains(p):
							hits += 1
							break
				var key: String = fn.trim_suffix(".gd")
				counts[key] = hits
				if hits > int(baseline.get(key, 0)):
					over.append("%s %d>%d" % [key, hits, int(baseline.get(key, 0))])
			var pure_ok: bool = int(counts.get("society", -1)) == 0 \
				and int(counts.get("player_actions", -1)) == 0
			_soc_restore(kp)
			print("NPC_ACCESS_OK=", over.is_empty() and pure_ok, " 초과=", over,
				" society=", counts.get("society", -1),
				" player_actions=", counts.get("player_actions", -1),
				" 파일=", counts.size())
		231:
			# ⑥ REST_OK — 순수 함수: 잠자리 배율·손버릇 레벨·밤 사람 시각·동굴 상한·
			# 대범함의 감쇠와 기절 순서(⑦ 고정: 감쇠 → ko −5). me 를 갈아 끼우고 며칠 넘기므로
			# 자리·지갑도 맡겨 둔다 — 계절 첫날이면 ③ 이 지갑을 지운다
			m.dialog.close()
			var kp: Dictionary = _soc_keep()
			var seats0: Dictionary = GameData.seats.duplicate(true)
			var wallet0: Dictionary = GameData.npc_wallet.duplicate()
			GameData.me = GameData.fresh_me()
			GameData.me.boldness_base = 25
			GameData.me.boldness_state = 0.0
			# 잠자리 배율 — 어젯밤 밖에서 4시간/8시간, 어제 근무 ×0.9
			GameData.me.night_out_day = GameData.day - 1
			GameData.me.night_out_min = 250.0
			var r1: float = GameData.rest_mult()
			GameData.me.night_out_min = 500.0
			var r2: float = GameData.rest_mult()
			GameData.me.work_log = [{"day": GameData.day - 1, "kind": "work",
				"inst": "general", "pick": 0}]
			var r3: float = GameData.rest_mult()
			var rest_ok: bool = absf(r1 - 0.75) < 0.001 and absf(r2 - 0.60) < 0.001 \
				and absf(r3 - 0.54) < 0.001
			# 손버릇 — 곡선만 빌린다: 205 → Lv2
			GameData.me.theft_xp = 0.0
			var lv1: int = GameData.theft_lv()
			GameData.me.theft_xp = 205.0
			var lv2: int = GameData.theft_lv()
			var lv_ok: bool = lv1 == 1 and lv2 == 2
			# 밤 사람 — 22시까지만
			GameData.minutes = 20.0 * 60.0
			var owl20: bool = GameData.night_owl("explorer")
			GameData.minutes = 22.0 * 60.0
			var owl22: bool = GameData.night_owl("explorer")
			var owl_ok: bool = owl20 and not owl22
			# 동굴 상한 — 3 + 3 은 5 에서 잘린다
			GameData._bold_today = {"cave": 0.0, "night": 0.0}
			GameData.bold_add(3.0, "cave")
			GameData.bold_add(3.0, "cave")
			var cap_ok: bool = float(GameData.me.boldness_state) == 5.0
			# 아침 순서 — state 0 · 기절: 감쇠 0 → ko −5.0; 이어 기절 없음: −5 → −2.0
			GameData.me.boldness_state = 0.0
			GameData.me.work_log = []
			GameData.society_new_day([0, 0, 0], true)
			var st1: float = float(GameData.me.boldness_state)
			GameData.society_new_day([0, 0, 0], false)
			var st2: float = float(GameData.me.boldness_state)
			var ko_ok: bool = st1 == -5.0 and st2 == -2.0
			# 성격을 아직 안 물었으면(base −1) 대범함은 움직이지 않고 마음 카드도 비어 있다
			GameData.me.boldness_base = -1
			var st0: float = float(GameData.me.boldness_state)
			GameData.bold_add(5.0)
			var none_ok: bool = float(GameData.me.boldness_state) == st0 \
				and GameData.bold_stage() == ""
			GameData.me.boldness_base = 25
			var stage_ok: bool = GameData.bold_stage() == "손이 굳지 않는"
			# 세이브 왕복 — arrears 속의 수도 int 로 돌아온다(D21 목록의 빈틈)
			var ar: Dictionary = GameData._apply_me({"arrears": {"amount": 3.0, "weeks": 1.0}}).arrears
			var arrears_ok: bool = ar.amount is int and int(ar.amount) == 3 and ar.weeks is int
			# 호칭 알림은 호감도 해금 뒤에만 — 기준선을 일부러 어긋나게 두고 두 번 넘긴다
			GameData.affinity_open = false
			GameData._title_mark = "probe"
			GameData.society_new_day([0, 0, 0])
			var quiet_note: String = GameData.society_note()
			GameData.affinity_open = true
			GameData._title_mark = "probe"
			GameData.society_new_day([0, 0, 0])
			var loud_note: String = GameData.society_note()
			var gate_ok: bool = not quiet_note.contains("이렇게 부른다") \
				and loud_note.contains("이렇게 부른다")
			# 손댄 seats — 랭크 밖 키·Array 아닌 값은 seat_rows 가 지우고 아래의 아침들이 죽지 않는다(자리가 진실 — 이 자리가 me.job 을 정한다)
			GameData.seats = {"general": {"clerk": ["player"], "owner": ["merchant"], "extra": 5}}
			var rows: Dictionary = GameData.seat_rows("general")
			var seat_ok: bool = not rows.has("extra") and GameData.seat_of("general", "clerk") == "player"
			# 봉급날은 이레마다 돌아오고(안 받아도), 세 주치를 넘긴 몫은 그 아침에 사라진다(D4)
			GameData.me.job = "general_clerk"
			GameData.me.rank = "clerk"
			GameData.me.job_since_day = GameData.day - 30
			GameData.me.wage_day = GameData.day - 21
			GameData.me.wage_pending = 2000
			GameData.society_new_day([0, 0, 0])
			var wnote: String = GameData.society_note()
			var wage_ok: bool = int(GameData.me.wage_day) == GameData.day \
				and int(GameData.me.wage_pending) == GameData.WAGE_CAP \
				and wnote.contains(str(GameData.SOCIETY_NOTES.wage_lost)) \
				and wnote.contains("봉급날")
			GameData.me.wage_day = GameData.day - 3      # 봉급날 사이 — 굴리지도 알리지도 않는다
			GameData.society_new_day([0, 0, 0])
			var wnote2: String = GameData.society_note()
			wage_ok = wage_ok and int(GameData.me.wage_day) == GameData.day - 3 \
				and not wnote2.contains("봉급날")
			# 「보이는 것」 페이지는 직업마다 한 번 — 잡화점에서 봤어도 대장간 것은 따로
			GameData.me.work_log = [{"day": GameData.day - 1, "kind": "sees", "inst": "general", "pick": 0}]
			var sees_ok: bool = m.society._sees_shown("general") and not m.society._sees_shown("smith")
			# 선반 메뉴는 낮 좀도둑 문턱(45)부터 — 그 아래는 구매창이 바로 뜬다
			GameData.me.boldness_state = 0.0
			GameData.me.boldness_base = 25
			var shelf_low: bool = m.society.shelf_menu(0)
			m.dialog.close()
			GameData.me.boldness_base = 45
			var shelf_high: bool = m.society.shelf_menu(0)
			m.dialog.close()
			var shelf_ok: bool = not shelf_low and shelf_high
			var v_ok: bool = GameData.society_v == 1   # 메모리의 판은 언제나 현재 판
			_soc_restore(kp)
			var kept_ok: bool = GameData.seats == seats0 and GameData.npc_wallet == wallet0
			print("REST_OK=", rest_ok and lv_ok and owl_ok and cap_ok and ko_ok and none_ok
				and stage_ok and kept_ok and arrears_ok and seat_ok and gate_ok and wage_ok
				and sees_ok and shelf_ok and v_ok,
				" 잠자리=", rest_ok, "(", r1, "/", r2, "/", r3, ") 손버릇=", lv_ok,
				" 밤사람=", owl_ok, " 동굴상한=", cap_ok, " 기절순서=", ko_ok,
				"(", st1, "/", st2, ") 질문전=", none_ok, " 마음카드=", stage_ok,
				" 되돌림=", kept_ok, " 왕복int=", arrears_ok, " 자리정리=", seat_ok,
				" 호칭게이트=", gate_ok, " 봉급날=", wage_ok, "(", wnote.replace("\n", " / "), ")",
				" 보이는것=", sees_ok, " 선반문턱=", shelf_ok, " 판=", v_ok)
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
			var gated8: bool = GameData.story8_objective_short() == "이장과 상의하자."
			m.story._end_ranch_chief()
			var s8_build: bool = GameData.story8_phase == "build" \
				and GameData.story8_objective_short() == "보라와 대화하자."
			GameData.npc_greeted.erase("rancher")
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
			var k_aff_f := GameData.aff("farmer")
			var k_aff_d := GameData.aff("foodie")
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
			var trio_aff: bool = GameData.aff("foodie") == k_aff_d + 6
			# ④ 이탈 — 「이사 가고 싶다」 대화에서 붙잡으면 남는다
			GameData.settler_leaving = "farmer"
			m.story.start_leaving_dialog("farmer")
			var leave_open: bool = m.dialog.visible
			m.dialog.close()
			var aff_before := GameData.aff("farmer")
			m.story._leave_persuade("farmer")
			var persuaded: bool = GameData.settler_leaving == "" \
				and GameData.aff("farmer") == aff_before + 15
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
			GameData.aff_set("farmer", k_aff_f)
			GameData.aff_set("foodie", k_aff_d)
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
			GameData.story9_phase = ""
			GameData.story8_phase = "done"
			m.story._story9_update(0.016)
			var s9_ask: bool = GameData.story9_phase == "ask" \
				and GameData.quest_npc_marks().get("chief", "") == "!"
			m.story._start_hall_ask_dialog()
			m.dialog.skip_seq()
			var s9_invite: bool = GameData.story9_phase == "invite" \
				and GameData.story9_objective_short() != "" \
				and not GameData.hall_feature_open("office")
			# 주민이 10명(플레이어 제외)을 넘어가면 건설 단계가 절로 열린다
			var s9_dummies: Array = []
			while m.village_residents() <= GameData.HALL_RESIDENTS:
				m.npcmgr._spawn_npc("forest_girl", Vector2i(74, 22))
				s9_dummies.append(m.npcs[m.npcs.size() - 1])
			m.story._story9_update(0.016)
			var s9_build: bool = GameData.story9_phase == "build" \
				and GameData.story9_objective_short().contains("접수대")
			m.dialog.close()
			# 개관식 — 회관 접수대(room_action)에서 이장과 이야기해야 끝난다
			m.village.room_action("hall")
			var s9_rite: bool = m.dialog.visible and GameData.story9_phase == "build"
			m.dialog.skip_seq()
			var s9_done: bool = GameData.story9_phase == "done"
			m.dialog.close()
			# 점진 해금 — 지금 주민 11명: 명부는 열리고 창고(12명)부터는 잠김
			# 점진 해금은 주민 수만 본다 — 앞선 검사가 띄운 해금 안내(hall_feat_noticed)는 잠시 치운다
			var k9_noticed: Array = GameData.hall_feat_noticed.duplicate()
			GameData.hall_feat_noticed = []
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
			var s9_aff0 := GameData.aff("chief")
			m.village._do_hall_project("lamps")
			var s9_proj: bool = GameData.hall_projects.has("lamps") \
				and GameData.aff("chief") == s9_aff0 + 3
			# 마을 회의 — 간식 나눔 가결 효과 (온 주민 호감도 +4)
			GameData.money += 800
			var s9_aff1 := GameData.aff("chief")
			m.village._meet_apply("snack")
			var s9_meet: bool = GameData.aff("chief") == s9_aff1 + 4
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
			GameData.hall_feat_noticed = k9_noticed
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
					GameData.aff_set(aid, 100)
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
				GameData.aff_set(a12, 0)
			m.story._story12_update(0.016)
			var s12_wait: bool = GameData.story12_phase == "" \
				and not GameData.story12_ready()
			# 노트 40%와 친구 5명을 채운다 (핵심 주민 호감도 + 수확 기록)
			for a13: String in GameData.NPCS:
				if GameData.settler_kind(a13) == "core":
					GameData.aff_set(a13, 100)
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
			var aff14: int = GameData.aff("chief")
			m.story._fest_toss()
			var s14_toss: bool = GameData.story14_toss \
				and GameData.money >= money14 \
				and GameData.aff("chief") == aff14 + 2
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
					GameData.aff_set(a16, 100)
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
				GameData.aff_set(a18, 100)
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
				GameData.aff_set(a20, 100)
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
			var name_ok: bool = GameData.npc_name("merchant") == "만수" \
				and GameData.npc_name("fisher") == "용식"
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
				var nd8: Dictionary = GameData.npc_def(nid8)
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
			var names_ok: bool = GameData.npc_name("explorer") == "재민" \
				and GameData.npc_name("postman") == "우체부 아저씨" \
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

			# ── ② 아직 못 가는 땅은 **검정 무지**로 덮인다 (구름 덩어리는 없앴다)
			_fog_keep = GameData.explored.duplicate()
			GameData.explored = {}
			var hidden: bool = not m.map_ui._visible_tile(2, 2)
			var fogc: Color = m.map_ui.FOG
			var cloud_ok: bool = hidden and fogc.a >= 1.0 and fogc.v <= 0.001 \
				and Color(m.hud.MM_FOG).v <= 0.001
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
			# 바다는 처음부터 물로 보이게 해 두었으므로 **뭍만** 센다
			var seen1 := 0
			for y1 in m.SEA_Y0:
				for x1 in m.MAP_W:
					if m.map_ui._visible_tile(x1, y1):
						seen1 += 1
			var ratio := float(seen1) / float(m.MAP_W * m.SEA_Y0)
			GameData.mark_explored_at(m.START_TILE + Vector2i(24, 12))
			var seen2 := 0
			for y2 in m.WORLD_H:
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
			GameData.aff_set("chief", aff_m)

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
			# 뭍의 먼 구석으로 고른다 — 바다는 가 보지 않아도 물로 보인다
			var far9 := Vector2i(m.MAP_W - 3, m.SEA_Y0 - 3)
			var fog_block: bool = not m.map_ui._visible_tile(far9.x, far9.y) \
				and m.map_ui.FOG.a >= 1.0 and m.map_ui.FOG.v <= 0.001
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
		232:
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
			# 벌목 문구만 읽는다. 아주 낮은 확률로 낡은 조합법이 떨어지면
			# 그 안내가 말풍선을 덮어써 검사가 헛돈다 — 이 한 번만
			# 「조합법은 이미 다 안다」로 두어 주사위를 없앤다
			var k_form: Array = GameData.alchemy_known.duplicate()
			for fid0: String in GameData.FORMULAS:
				if fid0 not in GameData.alchemy_known:
					GameData.alchemy_known.append(fid0)
			m.toolwork.use_tool()
			GameData.alchemy_known = k_form
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
		233:
			# #150: 튜토리얼 공간은 세계 밖에 따로 있다 · 마을이 세계의 시작점 ·
			# 주변 지역은 이야기를 따라 하나씩 열린다
			m.dialog.close()

			# ── ① 세계와 튜토리얼 공간은 격자에서부터 갈라져 있다
			var split_ok: bool = m.WORLD_H < m.TUT_Y0 \
				and m.TUTORIAL_REGION.position.y >= m.WORLD_H \
				and m.MAP_H >= m.TUTORIAL_REGION.end.y \
				and m.grid.size() == m.MAP_H

			# ── ② 마을에 도착한 뒤에는 그 공간으로 가는 길이 없다
			var k_tut := GameData.tutorial_space
			GameData.tutorial_space = false
			var tut_gone: bool = m.world_rect() == Rect2i(0, 0, m.MAP_W, m.WORLD_H)
			for ty2 in range(m.TUTORIAL_REGION.position.y, m.TUTORIAL_REGION.end.y):
				if m.is_passable(Vector2i(m.STORY_SPAWN.x, ty2)) \
						or m.map_ui._visible_tile(m.STORY_SPAWN.x, ty2):
					tut_gone = false
			# 지도도 세계만 굽는다 (튜토리얼 띠는 그림에 아예 없다)
			m.map_ui._bake()
			var bake_world: bool = m.map_ui._tex != null \
				and m.map_ui._tex.get_height() == m.WORLD_H

			# ── ③ 튜토리얼을 닫으면 그 자리의 오브젝트와 지도 기억도 사라진다
			GameData.tutorial_space = true
			var probe := Vector2i(m.STORY_SPAWN.x, m.STORY_SPAWN.y)
			m.objects[probe] = {"kind": "rock", "hp": 1}
			GameData.mark_explored_at(probe)
			m.story._close_tutorial_space()
			var closed_ok: bool = not GameData.tutorial_space \
				and not m.objects.has(probe) \
				and not GameData.is_explored_tile(probe.x, probe.y)

			# ── ④ 마을도, 세계도 **처음부터 다 걸을 수 있다.**
			#     이야기 진도로 야생 지역을 잠그던 자물쇠는 없앴다
			var k_forest := GameData.forest_quest
			var k_sea2 := GameData.sea_open
			var k_s8 := GameData.story8_phase
			GameData.forest_quest = ""
			GameData.sea_open = false
			GameData.story8_phase = ""
			var plaza9 := Vector2i(m.PLAZA.position.x + 3, m.PLAZA.position.y + 3)
			var village_open: bool = m.region_open_at(plaza9) \
				and m.is_passable(plaza9)
			# 이야기를 하나도 진행하지 않아도 세계는 다 열려 있다
			var open_ok := true
			for w9: Vector2i in [Vector2i(60, 50), Vector2i(120, 60),
					Vector2i(40, 80), Vector2i(180, 80), Vector2i(100, 100)]:
				if not m.region_open_at(w9):
					open_ok = false
			GameData.forest_quest = k_forest
			GameData.sea_open = k_sea2
			GameData.story8_phase = k_s8
			GameData.tutorial_space = k_tut
			m.map_ui._bake_age = 999.0
			print("WORLDGATE_OK=", split_ok and tut_gone and bake_world
				and closed_ok and village_open and open_ok,
				" 공간분리=", split_ok, " 복귀불가=", tut_gone,
				" 지도세계만=", bake_world, " 닫힘정리=", closed_ok,
				" 마을열림=", village_open, " 세계전역통행=", open_ok)
		234:
			# #151: 생선구이 그림 · 다가오는 걸음과 시선 · 채집 스폰과 비 ·
			# 울타리 레시피 · 검정 무지와 통행 차단 · Q창 축제 삭제
			m.dialog.close()

			# ── ① 생선구이는 유저 그림으로 (32x32)
			var grill: Texture2D = m.tex.get("dish_grilled_fish")
			var grill_ok: bool = grill != null and grill.get_width() == 32 \
				and grill.get_height() == 32

			# ── ② 다가오는 사람은 **서 있던 자리에서** 걸어오고, 오는 내내 마주 본다
			var face_ok: bool = m.story._face_dir(Vector2(100, 100), Vector2(100, 40)) == "up" \
				and m.story._face_dir(Vector2(100, 100), Vector2(100, 160)) == "down" \
				and m.story._face_dir(Vector2(100, 100), Vector2(200, 100)) == "right" \
				and m.story._face_dir(Vector2(100, 100), Vector2(20, 100)) == "left"
			var chief_n: Variant = m.story._story_chief()
			var walk_ok := false
			if chief_n != null:
				var k_cpos: Vector2 = chief_n.position
				var k_scr: bool = chief_n.scripted
				var k_ph := GameData.story_phase
				# 이장을 플레이어의 **북쪽**에 세워 둔다 — 예전에는 이 자리에서도
				# 남쪽으로 옮겨 놓아 무조건 아래에서 위로 올라왔다
				chief_n.position = m.player.position + Vector2(0.0, -160.0)
				GameData.story_phase = "greet"      # 이 연출이 도는 단계
				m.story.start_home_greet()
				walk_ok = chief_n.position.y < m.player.position.y   # 북쪽 그대로다
				m.story._update_home_greet(0.05)
				walk_ok = walk_ok and chief_n.dir == "down"          # 내려다보며 온다
				m.story._chief_greet = false
				m.story_cutscene = false
				m.dialog.close()
				chief_n.position = k_cpos
				chief_n.scripted = k_scr
				GameData.story_phase = k_ph

			# ── ③ 채집물은 흔하고, 비 오는 날은 더 흔하다
			var k_wx: int = m._weather_override
			m._weather_override = GameData.WEATHER_SUN
			var cap_clear: int = m.worldgen.forage_cap_now()
			m._weather_override = GameData.WEATHER_RAIN
			var cap_rain: int = m.worldgen.forage_cap_now()
			var grown0: int = m.worldgen.forage_count()
			m.worldgen._tick_rain_forage()          # 빗속 한 틱
			var rain_grow: bool = m.worldgen.forage_count() > grown0
			m._weather_override = k_wx
			var forage_ok: bool = cap_clear >= 60 and cap_rain > cap_clear \
				and m.worldgen.forage_count() >= 30 and rain_grow

			# ── ④ 울타리 레시피 — 목재를 가진 손님에게만
			var k_tools := GameData.unlocked_tools.duplicate()
			var k_ru := GameData.recipes_unlocked.duplicate()
			var k_ri := GameData.recipe_items.duplicate()
			GameData.unlocked_tools.erase("fence")
			GameData.recipes_unlocked.erase("fence")
			GameData.recipe_items.erase("fence")
			var fence_data: bool = "fence" not in GameData.TUTORIAL_UNLOCKS["harvest"] \
				and GameData.DESK_RECIPES.has("fence")
			GameData.give_recipe("fence")
			var learned: bool = GameData.learn_recipe("fence") \
				and GameData.is_tool_unlocked("fence")   # 배우면 도구가 열린다
			GameData.unlocked_tools = k_tools
			GameData.recipes_unlocked = k_ru
			GameData.recipe_items = k_ri
			var fence_ok: bool = fence_data and learned

			# ── ⑤ 못 가는 땅은 검정 무지 · 사람도 짐승도 지나갈 수 없다
			var black_ok: bool = m.map_ui.FOG.v <= 0.001 and m.map_ui.FOG.a >= 1.0 \
				and Color(m.hud.MM_FOG).v <= 0.001
			# 세계는 다 걸을 수 있다. 그래도 **사라진 튜토리얼 공간**만은
			# 사람도 짐승도 지나갈 수 없다 (NPC 길찾기까지 같은 문을 쓴다)
			var gone := Vector2i(m.STORY_SPAWN.x, m.STORY_SPAWN.y)
			var locked_ok: bool = not m.is_passable(gone) \
				and not m.map_ui._visible_tile(gone.x, gone.y) \
				and m.npcmgr._tile_path(m.player_tile(), gone).is_empty()
			for w8: Vector2i in [Vector2i(60, 50), Vector2i(100, 100)]:
				if not m.region_open_at(w8):
					locked_ok = false

			# ── ⑥ Q창에 계절 축제 항목이 없다
			var fest_gone := true
			for e: Dictionary in m.quest_ui._entries():
				if str(e.get("id", "")) == "info_fest" or str(e.get("title", "")) == "계절 축제":
					fest_gone = false
			m.hud._toast_queue.clear()
			print("LIVELY_OK=", grill_ok and face_ok and walk_ok and forage_ok
				and fence_ok and black_ok and locked_ok and fest_gone,
				" 생선구이=", grill_ok, " 시선=", face_ok, " 제자리에서=", walk_ok,
				" 채집=", forage_ok, "(맑음 ", cap_clear, " 비 ", cap_rain,
				" 지금 ", m.worldgen.forage_count(), ")",
				" 울타리레시피=", fence_ok, " 검정무지=", black_ok,
				" 사라진공간차단=", locked_ok, " 축제삭제=", fest_gone)
		235:
			# #152: 마을에 도착하는 순간 · 바닷길 길목으로 내려가는 길
			m.dialog.close()
			var k_tut := GameData.tutorial_space
			var k_ph2 := GameData.story_phase
			var k_pos2: Vector2 = m.player.position
			var k_expl2: Dictionary = GameData.explored.duplicate()

			# ── ① 마을 도착: 화면이 어두운 동안 카메라까지 마을로 온다
			GameData.tutorial_space = true
			GameData.story_phase = "travel"
			m.story._plant_story_forest()
			m.player.position = Vector2(m.STORY_SPAWN.x * m.TILE + 16,
				m.STORY_SPAWN.y * m.TILE + 16)
			m.story._apply_story_camera()
			var cam2: Camera2D = m.player.get_node("Camera")
			var tut_cam: bool = cam2.limit_top >= m.TUTORIAL_REGION.position.y * m.TILE
			m.story._do_world_entry()          # 페이드 한가운데에서 벌어지는 일
			var here2 := m.player_tile()
			# 주인공도 카메라도 마을에 와 있어야 한다 (예전에는 카메라만 숲에 남았다)
			var arrive_ok: bool = tut_cam and not GameData.tutorial_space \
				and here2.y < m.WORLD_H and m.is_passable(here2) \
				and cam2.limit_top < m.TUTORIAL_REGION.position.y * m.TILE \
				and absf(cam2.get_screen_center_position().y
					- m.player.position.y) < 200.0
			# 튜토리얼 숲길은 한 칸도 남지 않았다
			for ty3 in range(m.TUTORIAL_REGION.position.y, m.TUTORIAL_REGION.end.y):
				if m.is_passable(Vector2i(m.STORY_SPAWN.x, ty3)):
					arrive_ok = false
			# 전환이 도는 동안에는 컷신 잠금이 저절로 풀리지 않는다
			m.story._world_entry_running = true
			m.story_cutscene = true
			m._cutscene_idle = 0.0
			for i3 in 40:
				m.story._story_update(0.1)     # 4초 — 안전장치(1.5초)보다 길게
			var lock_ok: bool = m.story_cutscene
			m.story._world_entry_running = false
			m.story_cutscene = false
			m.dialog.close()

			# ── ② 바닷길: 길목 바위까지 걸어서 닿을 수 있다
			var k_sea3 := GameData.sea_open
			var k_fq3 := GameData.fisher_quest
			GameData.sea_open = false
			GameData.fisher_quest = "follow"    # 용식과 함께 내려가는 중
			m.worldgen._build_sea()
			var gate3: Vector2i = m.SEA_GATE[0]
			var stand := Vector2i(gate3.x, gate3.y - 1)   # 바위 바로 앞
			var reach_ok: bool = m.is_passable(stand) \
				and m.region_open_at(Vector2i(gate3.x, 100))   # 벼랑길이 열려 있다
			# 마을에서 그 자리까지 실제로 길이 이어져 있는가
			var seen3 := {}
			var q3: Array[Vector2i] = [Vector2i(74, 20)]
			var head3 := 0
			seen3[q3[0]] = true
			while head3 < q3.size():
				var cur3: Vector2i = q3[head3]
				head3 += 1
				for d3 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n3: Vector2i = cur3 + d3
					if seen3.has(n3) or not m.is_passable(n3):
						continue
					seen3[n3] = true
					q3.append(n3)
			reach_ok = reach_ok and seen3.has(stand)
			GameData.sea_open = k_sea3
			GameData.fisher_quest = k_fq3
			m.worldgen._build_sea()

			GameData.tutorial_space = k_tut
			GameData.story_phase = k_ph2
			m.player.position = k_pos2
			GameData.explored = k_expl2
			m.story._apply_story_camera()
			m.hud._toast_queue.clear()
			print("VILLAGE_ENTRY_OK=", arrive_ok and lock_ok and reach_ok,
				" 마을도착=", arrive_ok, " 전환중잠금=", lock_ok,
				" 길목까지=", reach_ok)
		236:
			# 대화키(F)와 상호작용키(E)가 갈라져 있는가.
			# 예전에는 E 하나가 캐기와 말 걸기를 겸해서, 나무를 연타하다
			# 옆 사람에게 말이 걸리곤 했다.
			m.dialog.close()
			# ① 키 배치: 대화는 F, 상호작용은 E
			var f_ok := false
			for ev_t in InputMap.action_get_events("talk"):
				if ev_t is InputEventKey and ev_t.physical_keycode == KEY_F:
					f_ok = true
			var e_ok := false
			for ev_e in InputMap.action_get_events("interact"):
				if ev_e is InputEventKey and ev_e.physical_keycode == KEY_E:
					e_ok = true
			var bind_ok: bool = f_ok and e_ok \
				and GameData.key_label("talk") == "F"
			# ② 사람 앞에서: F는 말을 걸고, E는 말을 걸지 않는다.
			# 사람이 어디 서 있느냐에 따라 E 가 문·물건을 열어 버리므로(S4a 지터로 걸음 시각이 달라진다)
			# 아무나 하나를 빈 풀밭으로 옮겨 놓고 잰다 — 위 칸까지 비어 있는 자리
			var talk_npc: Node2D = null
			for n_t in m.npcs:
				if n_t.visible:
					talk_npc = n_t
					break
			var npc_keep_pos := Vector2.ZERO
			if talk_npc != null:
				npc_keep_pos = talk_npc.position
				var base_t := Vector2i(m.START_TILE.x, m.START_TILE.y + 3)
				var spot_t := Vector2i(-1, -1)
				for dy_t in range(0, 14):
					for dx_t in range(-8, 9):
						var c_t := base_t + Vector2i(dx_t, dy_t)
						var up_t := c_t + Vector2i(0, -1)
						if m.is_passable(c_t) and m.is_passable(up_t) and not m.objects.has(c_t) and not m.objects.has(up_t) \
								and m.actions._door_kind_at(c_t) == "" and m.actions._door_kind_at(up_t) == "" \
								and m.actions._building_kind_at(c_t) == "" and m.actions._building_kind_at(up_t) == "":
							spot_t = c_t
							break
					if spot_t.x >= 0:
						break
				if spot_t.x >= 0:
					talk_npc.position = Vector2(spot_t.x * m.TILE + 16, spot_t.y * m.TILE + 16)
			var talk_ok := false
			var e_silent := false
			var t_pos: Vector2 = m.player.position
			var t_tool: String = GameData.tool
			if talk_npc != null:
				m.player.position = talk_npc.position + Vector2(0, 20)
				m.player.dir = "up"
				m._sel_target = Vector2i(-999, -999)
				m._work_lock = 0.0
				GameData.tool = "axe"          # 도끼를 들고 있어도 말은 걸린다
				talk_ok = m.actions.talk() and m.dialog.visible
				m.dialog.close()
				m.actions.interact()           # 같은 자리에서 E
				e_silent = not m.dialog.visible
				talk_npc.position = npc_keep_pos
			# ③ 아무도 없으면 F는 false를 돌려준다 (그래야 말 타기로 넘어간다)
			m.player.position = Vector2(m.START_TILE.x * m.TILE + 16,
				(m.START_TILE.y + 3) * m.TILE + 16)
			for n_f in m.npcs:
				n_f.position += Vector2(0, 4000)
			var far_ok: bool = not m.actions.talk()
			for n_b in m.npcs:
				n_b.position -= Vector2(0, 4000)
			m.dialog.close()
			GameData.tool = t_tool
			m.player.position = t_pos
			print("TALKKEY_OK=", bind_ok and talk_ok and e_silent and far_ok,
				" 키배치=", bind_ok, " F로대화=", talk_ok,
				" E는조용=", e_silent, " 아무도없을때=", far_ok)
		237:
			# 지도: 튜토리얼에서 한 번 구운 그림이 마을에 와서도 그대로 남아,
			# 세계 크기(224x120) 자리에 늘여 그려지던 버그.
			# 지형은 화면 한가운데 뭉쳐 있고 내 위치만 엉뚱한 데 찍혔다.
			var k_tut3 := GameData.tutorial_space
			GameData.tutorial_space = true
			m.map_ui._wr = Rect2i()            # 보여 줄 땅을 다시 재게 한다
			m.map_ui.open()
			m.map_ui._bake()
			var tut_sz: Vector2 = m.map_ui._tex.get_size()
			m.map_ui.close()
			GameData.tutorial_space = false
			m.map_ui.open()                    # 열면 반드시 다시 구워야 한다
			var redo: bool = m.map_ui._need_bake()
			if redo:
				m.map_ui._bake()
			var world_sz: Vector2 = m.map_ui._tex.get_size()
			m.map_ui.close()
			GameData.tutorial_space = k_tut3
			m.map_ui._wr = Rect2i()
			print("MAPBAKE_OK=", tut_sz == Vector2(m.TUTORIAL_REGION.size)
				and redo and world_sz == Vector2(m.MAP_W, m.WORLD_H),
				" 숲길=", tut_sz, " 다시굽기=", redo, " 세계=", world_sz)
		238:
			# 대화키를 쓰는 느낌 — 사거리 · 헛디딤 · 목표 갱신 · 말줄임표
			m.dialog.close()
			# ① 세 칸 떨어져도 말이 걸린다 (예전에는 한 칸 반이라 딱 붙어야 했다)
			var far_npc: Node2D = null
			for n_r in m.npcs:
				if n_r.visible:
					far_npc = n_r
					break
			var reach_ok := false
			var p_keep2: Vector2 = m.player.position
			if far_npc != null:
				# 다른 사람은 잠시 치운다 — 「누가 걸렸나」가 아니라
				# 「이만큼 떨어져도 걸리나」를 보는 검사다
				for n_o in m.npcs:
					if n_o != far_npc:
						n_o.position += Vector2(0, 4000.0)
				m.player.position = far_npc.position + Vector2(0, 84.0)
				m.player.dir = "up"
				reach_ok = m.actions.nearby_npc() == far_npc
				for n_o2 in m.npcs:
					if n_o2 != far_npc:
						n_o2.position -= Vector2(0, 4000.0)
			# ② 말이 없으면 F는 조용하다 (걷는 내내 「아직 말이 없다」가 뜨던 것)
			var k_horse := GameData.has_horse
			GameData.has_horse = false
			var quiet_ok: bool = not m.riding.can_toggle()
			GameData.has_horse = k_horse
			# ③ 만수와 말을 튼 뒤에는 목표가 다음 마디로 넘어간다
			var k_s2 := GameData.story2_phase
			var k_kq := GameData.kitchen_quest
			GameData.story2_phase = "cook"
			GameData.kitchen_quest = ""
			var obj_before := GameData.story2_objective_short()
			GameData.kitchen_quest = "broom"
			var obj_after := GameData.story2_objective_short()
			GameData.story2_phase = k_s2
			GameData.kitchen_quest = k_kq
			var step_ok: bool = obj_before != obj_after and obj_after != "" \
				and not obj_after.contains("말을 걸")
			# ④ "..."이 세 조각으로 쪼개져 점 하나만 남는 줄이 생기지 않는다
			var dots := "(눈앞에 우거진 숲이 펼쳐져 있다...)"
			var sents: PackedStringArray = m.dialog._split_sentences(dots)
			var pages2: Array = m.dialog._paginate_seq([{"text": dots}])
			var lone := false
			for pg2: Dictionary in pages2:
				for ln: String in str(pg2.text).split("\n"):
					if ln != "" and m.dialog._punct_only(ln):
						lone = true
			var sent_ok: bool = sents.size() == 1 and pages2.size() == 1 and not lone
			m.player.position = p_keep2
			m.hud._toast_queue.clear()
			print("TALKUX_OK=", reach_ok and quiet_ok and step_ok and sent_ok,
				" 세칸=", reach_ok, " 말없으면조용=", quiet_ok,
				" 만수단계=", step_ok, "(", obj_after, ") 말줄임표=", sent_ok)
		239:
			# 바다는 가 본 적이 없어도 지도에 물로 뜬다 (검은 구멍 금지).
			# 물 위는 걸어서 탐사할 수 없으니, 탐사 기록만 보면 영영 검다.
			var k_expl4: Dictionary = GameData.explored.duplicate()
			GameData.explored = {}                 # 아무 데도 안 가 본 셈 치고
			m.map_ui._ensure_vis_index()
			var sea_seen := true
			var sea_water := true
			# 해안선이 굽이치므로 물이 확실한 깊은 쪽만 잰다
			# (SEA_Y0 언저리 몇 줄은 자리마다 모래일 수 있다)
			for sx in [4, 60, 120, m.MAP_W - 3]:
				for sy in [m.SEA_Y0 + 6, m.WORLD_H - 4, m.WORLD_H - 1]:
					if not m.map_ui._visible_tile(sx, sy):
						sea_seen = false
					if str(m.grid[sy][sx].ground) != "water":
						sea_water = false
			# 격자 끝까지 물이다 — 모래사장에 서면 파란 띠 밑으로 화면 몇 줄이
			# 더 보인다. 예전에는 거기서 풀밭이 도로 나와 「바다 건너 초원」이 됐다
			var below_ok := true
			for sx2 in [70, 120, m.MAP_W - 3]:
				for sy2 in [m.WORLD_H, m.WORLD_H + 6, m.MAP_H - 1]:
					if str(m.grid[sy2][sx2].ground) != "water":
						below_ok = false
			# 튜토리얼 숲길: 살아 있는 동안에는 제 땅, 닫고 나면 바다다.
			# (닫은 자리를 잔디로 두었더니 모래사장에서 파란 바다 밑에
			#  초록 땅덩이가 떠 보였다 — 카메라가 열다섯 줄 아래까지 비춘다)
			var k_tut5 := GameData.tutorial_space
			GameData.tutorial_space = true
			m.story._plant_story_forest()
			var tut_keep: bool = str(m.grid[m.STORY_SPAWN.y][m.STORY_SPAWN.x].ground) \
				!= "water"
			m.story._close_tutorial_space()
			GameData.tutorial_space = k_tut5
			var tut_gone: bool = str(m.grid[m.STORY_SPAWN.y][m.STORY_SPAWN.x].ground) \
				== "water"
			# 뭍은 그대로 가려져 있어야 한다 (바다만 예외다)
			var land_hidden: bool = not m.map_ui._visible_tile(30, 60) \
				and not m.map_ui._visible_tile(120, 40)
			GameData.explored = k_expl4
			m.map_ui._ensure_vis_index()
			print("SEAMAP_OK=", sea_seen and sea_water and land_hidden
				and below_ok and tut_keep and tut_gone,
				" 바다보임=", sea_seen, " 전부물=", sea_water,
				" 끝까지물=", below_ok, " 숲길살아있을때=", tut_keep,
				" 닫으면바다=", tut_gone, " 뭍은가림=", land_hidden)
		251:
			# 「조리대에서 요리를 하자」가 영영 안 지워지던 버그.
			#
			# 목표를 띄우는 쪽은 FARM_CHAIN_FLAGS(+cook)를 보는데 목표를
			# 체크하는 쪽은 STORY2_FLAGS(cook 없음)를 봐서, 요리를 지어
			# 만수에게 가져다줘 2장이 끝난 뒤에도 안내 목표만 남아 있었다.
			var k_tut6: Dictionary = GameData.tutorial.duplicate()
			var k_guide := GameData.guide_active
			var k_s2b := GameData.story2_phase
			var k_kq2 := GameData.kitchen_quest
			GameData.tutorial = GameData.fresh_tutorial()
			for f6: String in ["till", "plant", "water", "harvest"]:
				GameData.tutorial[f6] = true
			GameData.guide_active = false          # 안내는 아직 안 열렸다
			GameData.story2_phase = "cook"
			# ① 지금 뜨는 안내 목표는 「요리」다
			var cook_shown: bool = GameData.tutorial_current_flag() == "cook"
			# ② 요리를 지으면 그 자리에서 체크된다 (예전에는 여기서 막혔다)
			m.story.tutorial_notify("cook")
			var cook_set: bool = bool(GameData.tutorial.get("cook", false))
			var cleared: bool = GameData.tutorial_current_flag() != "cook"
			# ③ 만수에게 가져다주는 마무리도 이 목표를 확실히 닫는다
			GameData.tutorial["cook"] = false
			GameData.kitchen_quest = "deliver"
			m.story._end_kitchen_deliver()
			var deliver_set: bool = bool(GameData.tutorial.get("cook", false))
			GameData.tutorial = k_tut6
			GameData.guide_active = k_guide
			GameData.story2_phase = k_s2b
			GameData.kitchen_quest = k_kq2
			m.hud._toast_queue.clear()
			m.dialog.close()
			print("COOKGUIDE_OK=", cook_shown and cook_set and cleared and deliver_set,
				" 목표뜸=", cook_shown, " 요리로체크=", cook_set,
				" 목표사라짐=", cleared, " 전달로도닫힘=", deliver_set)
		253:
			# ---- 세금(S2a) — 고지서·납부·체납 사다리·압류 ----
			#
			# 세금은 「내러 가는 행위」다. 계절 첫날 고지서가 편지로 오고(소득세 2,000 초과분
			# 10% + 재산세 집 100·가축 20), 창구에서 내면 마을 예산이 되고, 안 내면 여덟 주
			# 사다리(독촉장 → 이장 → 봉급 정지 → 압류)를 탄다. 전부 하루 넘김만으로 굴린다
			var k_tax := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			GameData.house_lv = 2
			GameData.animals_now = 3
			GameData.me.season_earned = 5000
			GameData.day = 57                                  # 계절 셋째의 첫날
			GameData.society_new_day([0, 0, 0])
			m.society.after_new_day()
			var b1: Dictionary = GameData.me.tax_bills[-1] if not GameData.me.tax_bills.is_empty() else {}
			var bill_ok: bool = int(b1.get("income", 0)) == 500 and int(b1.get("property", 0)) == 260 \
				and int(b1.get("total", 0)) == 760 and int(b1.get("due_day", 0)) == 63
			var mail_ok: bool = not GameData.mail_box.is_empty() \
				and str(GameData.mail_box[-1].title) == "납세 고지서"
			var n1 := GameData.society_note()
			var note_ok: bool = n1.contains("760") and n1.contains("밤길 등불")
			# 예산: 2000 + 교부금 2000 + 장부세 19×30 − 등불 착공 500
			var budget_ok: bool = int(GameData.gov_budget.kyojin) == 4070 and GameData.gov_building == "lights"
			# 납부 — 창구의 「세금 내기」
			GameData.money = 1000
			var aff0 := GameData.aff("chief")
			var rep0 := int(GameData.me.reputation.kyojin)
			var rc0 := int(GameData.items.get("tax_receipt", 0))
			m.society._pay_tax()
			var paid_ok: bool = GameData.money == 240 and int(b1.get("paid", 0)) == 760 \
				and int(GameData.gov_budget.kyojin) == 4830 \
				and int(GameData.items.get("tax_receipt", 0)) == rc0 + 1 \
				and GameData.aff("chief") == aff0 + 2 and int(GameData.me.reputation.kyojin) == rep0 + 2 \
				and GameData.tax_due_total() == 0 and m.dialog.visible
			m.dialog.close()
			# 체납 — 다음 계절 고지서(수입 3000 → 소득세 300 + 재산세 260 = 560)를 안 낸다
			GameData.me.season_earned = 3000
			GameData.day = 85
			GameData.society_new_day([0, 0, 0])
			m.society.after_new_day()
			var n2 := GameData.society_note()
			var b2: Dictionary = GameData.me.tax_bills[-1]
			# 등불 완공 → 예산 4830 + 2570 = 7400 ≥ 5000 → 포장 착공 → 2400
			var season2_ok: bool = int(b2.get("total", 0)) == 560 and "lights" in GameData.gov_done \
				and GameData.gov_building == "paving" and int(GameData.gov_budget.kyojin) == 2400 \
				and n2.contains("밤길 등불") and n2.contains("마을 길 포장") \
				and GameData.night_dark_color() != Color(0.16, 0.15, 0.26)
			GameData.day = 92                                  # 기한(91) 다음날 — 1주째
			GameData.society_new_day([0, 0, 0])
			var w1_ok: bool = GameData.arrears_weeks() == 1 and GameData.bill_due(b2) == 588 \
				and int(GameData.me.arrears.weeks) == 1
			var mails0 := GameData.mail_box.size()
			GameData.day = 99                                  # 2주째 — 독촉장
			GameData.society_new_day([0, 0, 0])
			var dun_ok: bool = GameData.arrears_weeks() == 2 and GameData.mail_box.size() == mails0 + 1 \
				and str(GameData.mail_box[-1].title) == "독촉장" and GameData.society_note().contains("독촉장")
			rep0 = int(GameData.me.reputation.kyojin)
			GameData.day = 113                                 # 4주째(계절 첫날이기도 하다 — 새 고지서 260)
			GameData.society_new_day([0, 0, 0])
			m.society.after_new_day()
			var keep_min_t := GameData.minutes
			GameData.minutes = 10 * 60
			var chief_ok: bool = GameData.arrears_weeks() == 4 and int(GameData.me.reputation.kyojin) == rep0 - 5 \
				and GameData.society_place("chief") == "meeting" \
				and m.society.talk_opener("chief", true).contains("세금") \
				and GameData.gov_done.has("paving") and GameData.path_speed_mult() > 1.0
			GameData.minutes = keep_min_t
			GameData.day = 127                                 # 6주째 — 봉급 정지
			GameData.society_new_day([0, 0, 0])
			var freeze_ok: bool = GameData.arrears_weeks() == 6 and GameData.wage_frozen()
			# 압류 — 창고(광석 5) → 가축(닭 한 마리, 내가 심은 것) → 소지금 순서
			GameData.hall_stock = {"ore": 5}
			var animals0 := m.animals.size()
			m.farming.spawn_animal("chicken")
			GameData.money = 5000
			var due_before := 0
			GameData.day = 141                                 # 8주째
			GameData.society_new_day([0, 0, 0])
			due_before = GameData.tax_seize_due
			m.society.after_new_day()
			var ore_v := GameData.item_value("ore")
			var store_got := 5 * ore_v
			var money_take: int = maxi(0, due_before - store_got - 800)
			var n3 := GameData.society_note()
			# 기한 지난 둘(560×1.4 + 260×1.2 = 1096)만 걷는다 — 오늘 아침 나온 고지서(260)는 남는다
			var seize_ok: bool = due_before == 1096 and not GameData.hall_stock.has("ore") \
				and m.animals.size() == animals0 and GameData.money == 5000 - money_take \
				and GameData.tax_due_total() == 260 and GameData.arrears_weeks() == 0 \
				and not GameData.wage_frozen() and int(GameData.me.reputation.kyojin) == rep0 - 5 - 15 \
				and n3.contains("대신 가져갔다") and n3.contains("닭")
			print("TAX_OK=", bill_ok and mail_ok and note_ok and budget_ok and paid_ok and season2_ok
				and w1_ok and dun_ok and chief_ok and freeze_ok and seize_ok,
				" 고지서=", bill_ok, " 편지=", mail_ok, " 결산=", note_ok, " 예산=", budget_ok,
				" 납부=", paid_ok, " 둘째계절=", season2_ok, " 1주=", w1_ok, " 독촉장=", dun_ok,
				" 이장=", chief_ok, " 봉급정지=", freeze_ok, " 압류=", seize_ok,
				"(", due_before, "G: 창고 ", store_got, " · 닭 800 · 돈 ", money_take, ")")
			_s2_restore(k_tax)
		254:
			# ---- 마을 예산(S2a) — 세금 0 으로 여덟 계절 ----
			#
			# 헌법 §2.4 검산: 교부금 2,000 + 장부세 (20−1)×30 = 2,570/계절, 운영비 0(파출소·진료소
			# 아직 없음). 예산은 절대 마이너스가 안 되고, 첫 사업은 첫 계절에 착공, 두 사업이 다
			# 끝난 뒤에는 계절마다 2,570 씩 쌓인다 — 「내가 낸 세금이 길이 된다」의 바닥
			var k_gov := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			GameData.house_lv = 0
			GameData.animals_now = 0
			var neg := false
			var starts: Array = []
			var dones: Array = []
			for i in 8:
				GameData.day = 29 + 28 * i
				GameData.society_new_day([0, 0, 0])
				m.society.after_new_day()
				GameData.society_note()
				if int(GameData.gov_budget.kyojin) < 0:
					neg = true
				starts.append(GameData.gov_building)
				dones.append(GameData.gov_done.duplicate())
			var first_ok: bool = starts[0] == "lights" and dones[1].has("lights")
			# 셋째 사업 「버스 개통」(S4b, 3,000)은 포장 다음 계절(1640 + 2570 = 4210)에 바로 선다
			var paving_ok: bool = starts[1] == "paving" and dones[2].has("paving") and starts[2] == "bus" \
				and dones[3].has("bus") and starts[3] == ""
			# 포장 착공(둘째 계절 뒤 1640)으로부터 여섯 계절 × 2570, 그 사이 버스 3,000
			var end_ok: bool = int(GameData.gov_budget.kyojin) == 1640 + 2570 * 6 - 3000
			var log_ok: bool = GameData.gov_log.size() == 8 and int(GameData.gov_log[-1].levy) == 570 \
				and int(GameData.gov_log[0].grant) == 2000
			var free_ok: bool = GameData.me.tax_bills.size() == 6 \
				and int(GameData.me.tax_bills[-1].total) == 0 and GameData.tax_due_total() == 0
			print("SOCIETY_BUDGET_OK=", not neg and first_ok and paving_ok and end_ok and log_ok and free_ok,
				" 마이너스없음=", not neg, " 첫사업=", first_ok, " 포장=", paving_ok,
				" 여덟계절뒤=", end_ok, "(", int(GameData.gov_budget.kyojin), ")",
				" 장부=", log_ok, " 면세=", free_ok)
			_s2_restore(k_gov)
		255:
			# ---- 면사무소 기관직(S2a) — 채용 심사·근무·봉급·체납 정지 ----
			var k_tw := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			GameData.aff_add("chief", 20 - GameData.aff("chief"))
			GameData.me.reputation.kyojin = 10
			var rep_refuse: String = m.society.can_hire_job("township_clerk")
			GameData.me.reputation.kyojin = 20
			var skill_refuse: String = m.society.can_hire_job("forest_ranger")   # forest Lv4 가 없다
			var clerk_can: String = m.society.can_hire_job("township_clerk")
			var review_ok: bool = rep_refuse.contains("좋게") and skill_refuse.contains("도끼질") and clerk_can == ""
			# 광장의 이장 대화에는 「일자리 이야기」가 없다 — 기관직은 창구에서
			var plaza: Array = [["대화 끝", null]]
			m.society.add_talk_choices("chief", plaza)
			var plaza_ok := true
			for c in plaza:
				if str(c[0]).contains("일자리"):
					plaza_ok = false
			m.society.hire_job("township_clerk")
			m.dialog.close()
			var hire_ok: bool = str(GameData.me.job) == "township_clerk" \
				and GameData.seat_of("township", "clerk") == "player" \
				and GameData.seat_of("township", "ranger") == "" \
				and GameData.seat_of("township", "head") == "chief"
			GameData.day += 1
			var keep_min_w := GameData.minutes
			GameData.minutes = 10 * 60
			var where_ok: bool = m.society.can_work("hall") == "" and m.society.can_work("general") != ""
			m.society.open_township()
			var labels := _btn_texts()
			var counter_ok: bool = m.dialog.visible and "근무" in labels and "그만두겠습니다" in labels
			m.society.work_start("hall")
			var loop_ok: bool = m.dialog.visible and m.dialog._seq.size() >= 1
			m.society.work_pick(0)
			m.dialog.close()
			var work_ok: bool = int(GameData.me.perf) == 1 and int(GameData.me.wage_pending) == 100
			# 체납 여섯 주 — 근무는 인정되고 몫만 안 적힌다
			GameData.me.tax_bills = [{"season": 0, "day": 1, "income": 100, "property": 0,
				"total": 100, "paid": 0, "due_day": GameData.day - 50}]
			GameData.day += 1
			var frozen_ok: bool = GameData.wage_frozen()
			m.society.work_start("hall")
			m.society.work_pick(1)
			m.dialog.close()
			frozen_ok = frozen_ok and int(GameData.me.perf) == 2 and int(GameData.me.wage_pending) == 100
			GameData.money = 1000
			m.society._pay_tax()
			m.dialog.close()
			var thaw_ok: bool = not GameData.wage_frozen() and GameData.tax_due_total() == 0
			GameData.minutes = keep_min_w
			print("TOWNSHIP_OK=", review_ok and plaza_ok and hire_ok and where_ok and counter_ok
				and loop_ok and work_ok and frozen_ok and thaw_ok,
				" 심사=", review_ok, " 광장에없음=", plaza_ok, " 채용=", hire_ok, " 일터=", where_ok,
				" 창구=", counter_ok, labels, " 미니루프=", loop_ok, " 근무=", work_ok,
				" 봉급정지=", frozen_ok, " 완납=", thaw_ok)
			_s2_restore(k_tw)
		256:
			# ---- 파출소(S2b) — 부지·부임·순경 채용 심사·순찰 걷기·보고·야간 몫·야간 순찰 ----
			var k_po := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			var cop_new := _s2_police_setup()
			var plot_ok: bool = "inn" in m.VILLAGE_BUILD_ORDER and m.VILLAGE_BUILD_COST.has("inn") \
				and str(m.VILLAGE_PLOTS.inn.name) == "파출소" and str(m.VILLAGE_NPC.get("inn", "")) == "officer_park" \
				and str(m.shop_room.ROOMS.inn.keeper) == "officer_park" and str(m.shop_room.ROOMS.inn.action) == "police" \
				and m.tex.has("npc_officer_park_portrait_normal") and m.tex.has("npc_officer_park_side_1") \
				and GameData.police_open() and _npc_node("officer_park") != null
			# 채용 심사 — 대범함 35 · 지네(combat Lv2) · 평판 20
			GameData.aff_add("officer_park", 20 - GameData.aff("officer_park"))
			GameData.me.reputation.kyojin = 20
			GameData.me.boldness_base = 10
			GameData.skills["combat"].lv = 2
			var bold_refuse: String = m.society.can_hire_job("constable")
			GameData.me.boldness_base = 40
			GameData.skills["combat"].lv = 1
			var skill_refuse: String = m.society.can_hire_job("constable")
			GameData.skills["combat"].lv = 2
			var review_ok: bool = bold_refuse.contains("밤길") and skill_refuse.contains("지네") \
				and m.society.can_hire_job("constable") == ""
			m.society.hire_job("constable")
			m.dialog.close()
			var hire_ok: bool = str(GameData.me.job) == "constable" \
				and GameData.seat_of("police_box", "constable") == "player"
			# 순찰 — 세 곳을 발로 찍는다. 밤 근무가 있는 직업이라 20시에도 근무다
			GameData.day += 1
			var keep_min_p := GameData.minutes
			GameData.minutes = 20 * 60
			var hours_ok: bool = m.society.can_work("inn") == "" and m.society.can_work("general") != ""
			var pos_keep: Vector2 = m.player.position
			m.story_cutscene = false                          # 걷기는 ui_open() 이 아닐 때만 찍힌다
			m.society.patrol_start()
			m.dialog.close()
			var start_ok: bool = m.society.patrol_active() and m.hud._guide_on and int(GameData.me.patrol_idx) == 0
			var pts: Array = m.society.patrol_points()
			for pt9: Vector2i in pts:
				m.player.position = Vector2(pt9.x * m.TILE + 16, pt9.y * m.TILE + 16)
				m.society._patrol_tick()
			var walk_ok: bool = m.society.patrol_done_today() and not m.hud._guide_on \
				and int(GameData.me.patrol_idx) == 3
			m.player.position = pos_keep
			m.society.patrol_report()
			var night_ok: bool = int(GameData.me.perf) == 1 and int(GameData.me.wage_pending) == 150 \
				and GameData.worked_on(GameData.day) and m.dialog.visible
			m.dialog.close()
			# 야간 순찰 — 23시엔 박 순경만 밖에 있고, 자정이 지나면 들어간다
			var cop: Node2D = _npc_node("officer_park")
			GameData.minutes = 23 * 60
			cop._process(0.016)
			var patrol_ok: bool = cop.visible and m.npcmgr.npc_place_now("officer_park") == "patrol" \
				and GameData.night_owl("officer_park")
			GameData.minutes = 24 * 60 + 30
			cop._process(0.016)
			patrol_ok = patrol_ok and not cop.visible
			GameData.minutes = keep_min_p
			cop._process(0.016)
			print("POLICE_OK=", plot_ok and review_ok and hire_ok and hours_ok and start_ok and walk_ok
				and night_ok and patrol_ok,
				" 부지=", plot_ok, " 심사=", review_ok, " 채용=", hire_ok, " 근무시간=", hours_ok,
				" 순찰시작=", start_ok, " 세곳=", walk_ok, pts, " 밤보고=", night_ok, " 야간순찰=", patrol_ok)
			_s2_police_teardown(cop_new)
			_s2_restore(k_po)
		257:
			# ---- NPC 사건(S2b) — 이레마다 한 건, 순경의 흔적 둘·검거, 그리고 저절로 닫힘 ----
			var k_cr := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			var cop_new2 := _s2_police_setup()
			GameData.settlers = ["miner", "carpenter"]
			for sid9: String in ["miner", "carpenter", "farmer", "merchant"]:
				if not GameData.npc_greeted.has(sid9):
					GameData.npc_greeted.append(sid9)
				GameData.aff_add(sid9, -GameData.aff(sid9))
			GameData.cases = []
			GameData.case_seq = 0
			GameData.day = 70                                  # 이레의 배수
			GameData.society_new_day([0, 0, 0])
			var n_c := GameData.society_note()
			var c9: Dictionary = GameData.cases[0] if not GameData.cases.is_empty() else {}
			var spawn_ok: bool = GameData.cases.size() == 1 and str(c9.get("stage", "")) == "open" \
				and str(c9.get("suspect", "")) in ["miner", "carpenter"] \
				and str(c9.get("victim", "")) != str(c9.get("suspect", "")) \
				and str(c9.get("witness", "")) != str(c9.get("victim", "")) \
				and n_c.contains("도둑이 들었다")
			# 순경으로서 — 피해자에게 묻고, 흔적 하나로 검거하면 무고, 목격자까지 물으면 검거
			GameData.me.job = "constable"
			GameData.me.rank = "constable"
			GameData.seat_rows("police_box")["constable"][0] = "player"
			var cid9 := int(c9.get("id", 0))
			var victim9 := str(c9.get("victim", ""))
			var witness9 := str(c9.get("witness", ""))
			var suspect9 := str(c9.get("suspect", ""))
			var ch_v: Array = [["대화 끝", null]]
			m.society.add_talk_choices(victim9, ch_v)
			var ask_ok: bool = str(ch_v[0][0]).contains("사건 이야기")
			m.society.case_ask(cid9, victim9)
			m.dialog.close()
			var ch_s: Array = [["대화 끝", null]]
			m.society.add_talk_choices(suspect9, ch_s)
			var arrest_choice_ok := false
			for c10 in ch_s:
				if str(c10[0]).contains("검거한다"):
					arrest_choice_ok = true
			var rep9 := int(GameData.me.reputation.kyojin)
			m.society.case_arrest(cid9, suspect9)
			m.dialog.close()
			var wrong_ok: bool = str(c9.get("stage", "")) == "open" and int(GameData.me.reputation.kyojin) == rep9 - 5
			m.society.case_ask(cid9, witness9)
			m.dialog.close()
			var budget9 := int(GameData.gov_budget.kyojin)
			m.society.case_arrest(cid9, suspect9)
			m.dialog.close()
			var n_c2 := GameData.society_note()
			var catch_ok: bool = str(c9.get("stage", "")) == "closed" and str(c9.get("closed_by", "")) == "player" \
				and int(GameData.me.arrests) == 1 and int(GameData.gov_budget.kyojin) > budget9 \
				and n_c2.contains("내가") and int(GameData.me.reputation.kyojin) == rep9 - 5 + 2 \
				and GameData.npc_greed(suspect9) < float(GameData.npc_def(suspect9).get("greed", 1.0))
			# 저절로 닫힘 — 다음 사건은 플레이어 없이 시효 안에 닫힌다(순경 검거든 시효든)
			GameData.me.job = ""
			GameData.me.rank = ""
			GameData.seat_clear_player()
			GameData.day = 77
			GameData.society_new_day([0, 0, 0])
			GameData.society_note()
			var c11: Dictionary = GameData.cases[-1]
			var auto_ok: bool = GameData.cases.size() == 2 and str(c11.get("stage", "")) == "open"
			var closed_day := -1
			for dd in range(78, 78 + 31):
				GameData.day = dd
				GameData.society_new_day([0, 0, 0])
				GameData.society_note()
				if str(c11.get("stage", "")) == "closed":
					closed_day = dd
					break
			auto_ok = auto_ok and closed_day > 0 and str(c11.get("closed_by", "")) in ["officer", "expired"]
			print("CRIME_OK=", spawn_ok and ask_ok and arrest_choice_ok and wrong_ok and catch_ok and auto_ok,
				" 사건=", spawn_ok, "(", suspect9, "→", victim9, " 목격 ", witness9, ")",
				" 흔적선택지=", ask_ok, " 검거선택지=", arrest_choice_ok, " 무고=", wrong_ok,
				" 검거=", catch_ok, " 저절로닫힘=", auto_ok, "(", closed_day, " ", str(c11.get("closed_by", "")), ")")
			_s2_police_teardown(cop_new2)
			_s2_restore(k_cr)
		258:
			# ---- 수배(S2b) — 회의에서 부인하면 박 순경이 쫓고, 곁에 2초면 즉결. 자수는 절반 ----
			var k_wa := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			var cop_new3 := _s2_police_setup()
			GameData.day = 50                                  # 샌드박스는 1일 — 「어제 신고」가 0일이 되면 안 된다
			GameData.me.boldness_base = 40
			GameData.me.memories = [{"day": GameData.day - 1, "kind": "pickpocket", "heat": 1, "region": "kyojin",
				"witnesses": ["farmer"], "forgiven": false, "target": "merchant", "value": 20,
				"reported_day": GameData.day - 1, "settled": "", "settled_day": 0}]
			m.story_cutscene = true
			m.society.open_council()
			m.society.council_pick("denied")
			m.dialog.close()
			var w9: Dictionary = GameData.me.wanted
			var wanted_ok: bool = GameData.wanted_active() and int(w9.get("fine", 0)) == 200 \
				and str(w9.get("target", "")) == "merchant"
			GameData.day += 1
			GameData.society_new_day([0, 0, 0])
			var n_w := GameData.society_note()
			var keep_min_w2 := GameData.minutes
			GameData.minutes = 10 * 60
			var chase_ok: bool = n_w.contains("찾고 있다") and GameData.society_place("officer_park") == "chase" \
				and m.npcmgr.npc_place_tile("officer_park", "chase") == m.player_tile()
			# 박 순경이 곁에 — 2초
			var cop3: Node2D = _npc_node("officer_park")
			cop3.visible = true
			cop3.position = m.player.position + Vector2(20, 0)
			m.story_cutscene = false
			m.dialog.close()
			m.society._arrest_tick(1.1)
			var not_yet: bool = not m.dialog.visible
			m.society._arrest_tick(1.1)
			var caught_ok: bool = not_yet and m.dialog.visible and m.dialog._seq.size() >= 1
			GameData.money = 1000
			var budget10 := int(GameData.gov_budget.kyojin)
			var rep10 := int(GameData.me.reputation.kyojin)
			m.society._arrest_pick("fine", 200, false)
			m.dialog.close()
			var fine_ok: bool = GameData.money == 800 and int(GameData.gov_budget.kyojin) == budget10 + 200 \
				and not GameData.wanted_active() and str(GameData.me.memories[0].settled) == "fined" \
				and bool(GameData.me.memories[0].forgiven) and int(GameData.me.reputation.kyojin) == rep10 - 5 \
				and GameData.society_place("officer_park") != "chase"
			# 자수 — 다시 수배를 심고 파출소 창구로 간다
			GameData.me.wanted = {"day": GameData.day - 2, "kind": "pickpocket", "target": "merchant",
				"value": 20, "fine": 200, "since": GameData.day}
			m.society.open_police()
			var sur_dialog: bool = m.dialog.visible and str(m.dialog._seq[0].text).contains("절반")
			rep10 = int(GameData.me.reputation.kyojin)
			m.society._arrest_pick("fine", 100, true)
			m.dialog.close()
			var sur_ok: bool = sur_dialog and GameData.money == 700 and not GameData.wanted_active() \
				and int(GameData.me.reputation.kyojin) == rep10 - 2
			GameData.minutes = keep_min_w2
			print("WANTED_OK=", wanted_ok and chase_ok and caught_ok and fine_ok and sur_ok,
				" 수배=", wanted_ok, " 추적=", chase_ok, " 체포=", caught_ok, " 벌금=", fine_ok, " 자수=", sur_ok)
			_s2_police_teardown(cop_new3)
			_s2_restore(k_wa)
		259:
			# ---- 순회 재판(S2c) — 빈집 문 앞·잠입·발각·기소·재판일·판결(벌금/구류)·방청 ----
			var k_ct := _s2_keep()
			var items_ct: Dictionary = GameData.items.duplicate()
			var homes_ct: Dictionary = GameData.settler_homes.duplicate(true)
			m.dialog.close()
			_s2_fresh_gov()
			var cop_ct := _s2_police_setup()
			# 정착민 하나에 집을 준다(노드는 안 심는다 — 잠입은 문 앞 대화로 판정된다).
			# 나는 마을 구석에 선다: 반경 여섯 칸에 아무도 없어야 목격자 셈이 0 이다
			GameData.settler_homes["farmer"] = [60, 60]
			if not GameData.npc_greeted.has("farmer"):
				GameData.npc_greeted.append("farmer")
			m.player.position = Vector2(5 * m.TILE + 16, 5 * m.TILE + 16)
			GameData.me.boldness_base = 40
			GameData.day = 5                                   # 계절 5일 — 이틀 뒤(7일)가 재판일
			var keep_min_ct := GameData.minutes
			var away_h := 10
			for hh in range(9, 18):
				GameData.minutes = hh * 60
				if m.npcmgr.npc_place_now("farmer") != "home":
					away_h = hh
					break
			GameData.minutes = away_h * 60
			# 문 앞 — 주인이 밖에 있는 낮엔 「몰래 들어간다」가 산다, 저녁엔 회색
			m.society.house_door("farmer")
			var door_ok: bool = m.dialog.visible and "몰래 들어간다" in _btn_texts()
			GameData.minutes = 20 * 60
			m.society.house_door("farmer")
			var night_gray: bool = "… 몰래 들어간다" in _btn_texts()
			GameData.minutes = away_h * 60
			m.dialog.close()
			# 잠입 성공(굴림 0) — 본 사람이 없으면 기억도 없다. 물건 하나, 손버릇 +10
			var mem_n: int = GameData.me.memories.size()
			m.society.burglary("farmer", 0.0)
			m.dialog.close()
			var loot_ok: bool = GameData.me.memories.size() == mem_n and float(GameData.me.theft_xp) >= 10.0
			# 잠입 실패(굴림 1) — 주인이 돌아왔다: heat 2 기억, 주인이 목격자, 신고 확정
			m.society.burglary("farmer", 1.0)
			m.dialog.close()
			var mem_ct: Dictionary = GameData.me.memories[-1]
			var fail_ok: bool = int(mem_ct.heat) == 2 and int(mem_ct.reported_day) == GameData.day \
				and "farmer" in mem_ct.witnesses
			# 다음날 아침 — 이장의 회의가 아니라 기소. 재판은 7일
			GameData.day += 1
			GameData.society_new_day([0, 0, 0])
			var n_ct := GameData.society_note()
			# society_new_day 의 _apply_me 가 기억 그릇을 새로 짓는다 — 옛 참조는 버리고 다시 집는다
			mem_ct = GameData.me.memories[-1]
			var charged_ok: bool = GameData.charged_active() and n_ct.contains("기소") \
				and not GameData.council_pending() and int(GameData.me.charged.court_day) == 7 \
				and str(mem_ct.settled) == "charged"
			# 재판일 아침 — 알림, 회관 첫 단추가 피고석
			GameData.day = 7
			GameData.society_new_day([0, 0, 0])
			var n_ct2 := GameData.society_note()
			m.village._open_hall_dialog()
			var hall_btns: Array = _btn_texts()
			m.dialog.close()
			# 단추 목록엔 같은 프레임에 닫힌 창의 단추가 아직 남아 있다(queue_free) — 자리가 아니라 있음을 본다
			mem_ct = GameData.me.memories[-1]
			var court_ok: bool = GameData.is_court_day() and n_ct2.contains("순회 재판") \
				and "★ 순회 재판 — 피고석에 선다" in hall_btns
			# 판결 ① 인정 — heat 2 − 1 = 벌금 200 고지서(창구 「세금·벌금 내기」), 전과 circuit, 평판 −15
			var rep_ct := int(GameData.me.reputation.kyojin)
			var bills_n: int = GameData.me.tax_bills.size()
			m.society.open_trial()
			var trial_open: bool = m.dialog.visible and m.dialog._seq.size() >= 3
			m.society.trial_pick("admit")
			m.dialog.close()
			var rec_ct: Dictionary = GameData.me.record[-1] if not GameData.me.record.is_empty() else {}
			m.society.open_township()
			var twn_btns: Array = _btn_texts()
			m.dialog.close()
			var fine_ok: bool = trial_open and not GameData.charged_active() \
				and str(rec_ct.get("verdict", "")) == "fine" and str(rec_ct.get("court", "")) == "circuit" \
				and GameData.me.tax_bills.size() == bills_n + 1 \
				and str(GameData.me.tax_bills[-1].get("kind", "")) == "fine" \
				and int(GameData.me.tax_bills[-1].total) == 200 \
				and int(GameData.me.reputation.kyojin) == rep_ct - 15 and bool(mem_ct.forgiven) \
				and ("세금·벌금 내기 — 200G" in twn_btns or "… 세금·벌금 내기 — 200G" in twn_btns)
			# 판결 ② 재판을 거르고 부인 — 거른 1 + 전과 1 + 부인 1: 구류. 아침마다 하루 줄고, 이레째 나온다
			GameData.me.charged = {"day": 7, "kind": "burglary", "target": "farmer", "value": 20,
				"others": 1, "seen": 2, "heat": 2, "court_day": 21, "skips": 0, "since": 7}
			GameData.day = 22
			GameData.society_new_day([0, 0, 0])
			var n_ct3 := GameData.society_note()
			var skip_ok: bool = n_ct3.contains("가중") and int(GameData.me.charged.skips) == 1 \
				and int(GameData.me.charged.court_day) == 35
			GameData.day = 35
			GameData.society_new_day([0, 0, 0])
			GameData.society_note()
			m.society.open_trial()
			m.society.trial_pick("deny")
			var jail_page: bool = m.dialog.visible and str(m.dialog._seq[-1].text).contains("구류")
			m.dialog.close()
			var rec_j: Dictionary = GameData.me.record[-1]
			# 구류 장부 — 고지서 기한이 이레 미뤄지고, 아침 일곱 번이면 나온다(하루 넘김 자체는 serve_jail 의 몫)
			var due_before := int(GameData.me.tax_bills[-1].due_day)
			GameData.jail_begin(GameData.JAIL_DAYS)
			var out_day := -1
			var n_jail := ""
			for dj in range(36, 36 + GameData.JAIL_DAYS):
				GameData.day = dj
				GameData.society_new_day([0, 0, 0])
				n_jail = GameData.society_note()
				if int(GameData.me.jail_days_left) == 0:
					out_day = dj
					break
			var jail_ok: bool = jail_page and str(rec_j.verdict) == "jail" and out_day == 42 \
				and int(GameData.me.jail_out_day) == 42 and n_jail.contains("파출소를 나왔다") \
				and int(GameData.me.tax_bills[-1].due_day) == due_before + GameData.JAIL_DAYS \
				and str(GameData.player_title("chief").cls) == "jailed" and not GameData.charged_active()
			# 방청 — 기소가 없는 재판일(계절 2 의 21일 = 49일), 순경이 닫은 사건을 판사가 읽는다
			GameData.day = 49
			GameData.cases = [{"id": 1, "crime": "burglary", "day": 46, "suspect": "miner", "victim": "merchant",
				"witness": "farmer", "evidence": 2, "stage": "closed", "closed_by": "officer", "deadline": 76}]
			GameData.society_new_day([0, 0, 0])
			var n_ct4 := GameData.society_note()
			m.village._open_hall_dialog()
			var hall_btns2: Array = _btn_texts()
			m.dialog.close()
			m.society.open_docket()
			var read_miner := false
			for pg in m.dialog._seq:
				if str(pg.text).contains(GameData.npc_def("miner").name):
					read_miner = true
			m.dialog.close()
			var docket_ok: bool = n_ct4.contains("윤 판사") and "순회 재판 방청" in hall_btns2 and read_miner
			GameData.minutes = keep_min_ct
			print("COURT_OK=", door_ok and night_gray and loot_ok and fail_ok and charged_ok and court_ok
				and fine_ok and skip_ok and jail_ok and docket_ok,
				" 문앞=", door_ok, " 저녁회색=", night_gray, " 잠입=", loot_ok, " 발각=", fail_ok,
				" 기소=", charged_ok, " 재판일=", court_ok, " 벌금=", fine_ok, " 가중=", skip_ok,
				" 구류=", jail_ok, " 방청=", docket_ok)
			GameData.items = items_ct
			GameData.settler_homes = homes_ct
			_s2_police_teardown(cop_ct)
			_s2_restore(k_ct)
		271:
			# ---- 전과 말소(S2c) — 면사무소 창구, 인지세 500. 형 끝 스무여드레 뒤에만, 임용 심사가 다시 0 ----
			var k_ex := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			var cop_ex := _s2_police_setup()
			GameData.money = 1000
			GameData.me.reputation.kyojin = 30
			GameData.aff_add("chief", 30 - GameData.aff("chief"))
			GameData.me.record = [{"day": 60, "crime": "burglary", "court": "circuit", "verdict": "fine",
				"sentence": 0, "served": 0, "served_day": 0, "expunged": false}]
			GameData.day = 80
			var refuse_ex: String = m.society.can_hire_job("township_clerk")
			m.society.open_township()
			var early_btns: Array = _btn_texts()
			m.dialog.close()
			var early_ok: bool = refuse_ex.contains("전과") and "… 전과 말소 — 500G" in early_btns
			GameData.day = 100
			m.society.open_township()
			var ready_ok: bool = "전과 말소 — 500G" in _btn_texts()
			m.dialog.close()
			var budget_ex := int(GameData.gov_budget.kyojin)
			m.society.expunge()
			m.dialog.close()
			var done_ok: bool = GameData.money == 500 and int(GameData.gov_budget.kyojin) == budget_ex + 500 \
				and bool(GameData.me.record[0].expunged) and int(GameData.me.reputation.kyojin) == 40 \
				and not m.society.can_hire_job("township_clerk").contains("전과")
			print("EXPUNGE_OK=", early_ok and ready_ok and done_ok, " 이르다=", early_ok, "(", refuse_ex, ")",
				" 청구=", ready_ok, " 말소=", done_ok)
			_s2_police_teardown(cop_ex)
			_s2_restore(k_ex)
		394:
			# ---- 새터말(S3b) — 초원의 빈 집터 여덟은 장부 밖에 있다: 옛 마을 너머가 열려야 자리로 센다 ----
			var k_md := _s2_keep()
			var plots_md: Array = GameData.home_plots.duplicate(true)
			var s4_md := GameData.story4_phase
			GameData.home_plots = []
			GameData.story4_phase = ""
			var closed_ok: bool = GameData.first_empty_plot().x < 0 and GameData.empty_plot_count() == 0
			GameData.story4_phase = "done"
			var a_md: Vector2i = GameData.first_empty_plot()
			var open_ok: bool = a_md == GameData.MEADOW_PLOTS[0] and GameData.empty_plot_count() == 8 \
				and GameData.plot_fixed_at(a_md)
			# 내 집터가 있으면 그것이 먼저다
			GameData.home_plots = [{"x": 20, "y": 52, "used": false}]
			var mine_first: bool = GameData.first_empty_plot() == Vector2i(20, 52) and GameData.empty_plot_count() == 9
			GameData.home_plots = []
			# 집이 서면 장부에 새 줄이 생기고, 다음 자리는 그다음 앵커다
			GameData.mark_plot_used(a_md)
			var used_ok: bool = GameData.meadow_plot_used(a_md) and GameData.home_plots.size() == 1 \
				and bool(GameData.home_plots[0].fixed) and GameData.first_empty_plot() == GameData.MEADOW_PLOTS[1] \
				and GameData.empty_plot_count() == 7
			# 팻말은 못 거둔다 — 집터도 팻말도 그대로, 가방에 집터가 생기지 않는다
			var door_md: Vector2i = m.door_tile(GameData.MEADOW_PLOTS[1])
			var had_sign: bool = str(m.objects.get(door_md, {}).get("kind", "")) == "homeplot"
			var kits_md := int(GameData.items.get("housing_kit", 0))
			m.story._pickup_home_plot(door_md)
			var keep_ok: bool = str(m.objects.get(door_md, {}).get("kind", "")) == "homeplot" \
				and int(GameData.items.get("housing_kit", 0)) == kits_md
			print("MEADOW_OK=", closed_ok and open_ok and mine_first and used_ok and had_sign and keep_ok,
				" 닫힘=", closed_ok, " 열림=", open_ok, a_md, " 내집터먼저=", mine_first, " 집섬=", used_ok,
				" 팻말=", had_sign, " 회수불가=", keep_ok)
			GameData.home_plots = plots_md
			GameData.story4_phase = s4_md
			_s2_restore(k_md)
		395:
			# ---- 자치회(S3c) — 명예직 목록·심사·청년회장의 야경·아침 보고·야경 명부·부녀회장의 살림 명부 ----
			var k_ho := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			var cop_ho := _s2_police_setup()
			GameData.day = 40
			var keep_min_ho := GameData.minutes
			GameData.minutes = 10 * 60
			m.society._open_township_jobs()
			var jl: Array = _btn_texts()
			m.dialog.close()
			var list_ok: bool = "청년회장 — 명예직, 무보수" in jl and "부녀회장 — 명예직, 무보수" in jl \
				and "서당 훈장 — 명예직, 무보수" in jl
			# 심사 — 평판 60 · 이장 호감 50 · 대범함 35 · 벌목 Lv3
			GameData.aff_add("chief", 50 - GameData.aff("chief"))
			GameData.me.reputation.kyojin = 30
			GameData.me.boldness_base = 40
			GameData.skills["forest"].lv = 3
			var rep_refuse: String = m.society.can_hire_job("youth_head")
			GameData.me.reputation.kyojin = 60
			GameData.aff_add("chief", 30 - GameData.aff("chief"))
			var aff_refuse: String = m.society.can_hire_job("youth_head")
			GameData.aff_add("chief", 50 - GameData.aff("chief"))
			var review_ok: bool = rep_refuse.contains("미는 자리") and aff_refuse.contains("잘 모르") \
				and m.society.can_hire_job("youth_head") == ""
			m.society.hire_job("youth_head")
			m.dialog.close()
			var hire_ok: bool = str(GameData.me.job) == "youth_head" \
				and GameData.seat_of("assoc", "youth_head") == "player" and int(GameData.JOBS.youth_head.wage) == 0
			# 야경 — 21시가 되면 저절로 시작, 세 군데를 찍으면 끝, 대범함이 오른다
			GameData.day += 1
			GameData.minutes = 21 * 60 + 30
			m.story_cutscene = false
			var bold_before := float(GameData.me.boldness_state)
			# 앞 검사(지도)가 지도 창을 연 채 두었다 — 야경은 창이 다 닫혀야 찍힌다(ui_open)
			var map_keep_ho: bool = m.map_ui.visible
			m.map_ui.visible = false
			m.society._patrol_tick()
			var start_ok: bool = m.society.patrol_active() and m.hud._guide_on \
				and int(GameData.me.patrol_day) == GameData.day
			var pos_ho: Vector2 = m.player.position
			for pt9: Vector2i in m.society.watch_points():
				m.player.position = Vector2(pt9.x * m.TILE + 16, pt9.y * m.TILE + 16)
				m.society._patrol_tick()
			m.player.position = pos_ho
			var walk_ok: bool = m.society.patrol_done_today() and not m.hud._guide_on \
				and float(GameData.me.boldness_state) > bold_before
			# 다음날 아침 — 결산 줄, 창구의 「야경 보고」가 근무를 인정한다. 봉급은 없다
			GameData.day += 1
			GameData.minutes = 10 * 60
			GameData.society_new_day([0, 0, 0])
			var n_ho := GameData.society_note()
			m.story_cutscene = true
			m.society.open_township()
			var tb: Array = _btn_texts()
			m.dialog.close()
			m.society.watch_report()
			m.dialog.close()
			var report_ok: bool = n_ho.contains("세 군데") and "야경 보고" in tb and "야경 명부" in tb \
				and int(GameData.me.perf) == 1 and int(GameData.me.wage_pending) == 0 \
				and GameData.worked_on(GameData.day)
			m.society._watch_roster()
			var roster_ok: bool = m.dialog.visible and str(m.dialog.body_label.text).contains("박 순경")
			m.dialog.close()
			# 부녀회장 — 오래 못 본 정착민을 알고, 하루 한 집 찾아간다(이탈이 멈춘다)
			m.society.resign()
			m.dialog.close()
			GameData.me.job_history = []
			GameData.me.reputation.kyojin = 60
			m.society.hire_job("women_head")
			m.dialog.close()
			GameData.day += 1
			GameData.settlers = ["florist"]
			if not GameData.npc_greeted.has("florist"):
				GameData.npc_greeted.append("florist")
			GameData.npc_last_talk["florist"] = GameData.day - 10
			m.society._women_roster()
			var wb: Array = _btn_texts()
			m.dialog.close()
			var aff_fl := GameData.aff("florist")
			m.society._women_visit("florist")
			m.dialog.close()
			var women_ok: bool = ("찾아간다 — " + str(GameData.npc_def("florist").name)) in wb \
				and int(GameData.npc_last_talk.florist) == GameData.day and GameData.aff("florist") == aff_fl + 3 \
				and int(GameData.me.visit_day) == GameData.day
			print("HONOR_OK=", list_ok and review_ok and hire_ok and start_ok and walk_ok and report_ok
				and roster_ok and women_ok,
				" 목록=", list_ok, " 심사=", review_ok, " 채용=", hire_ok, " 야경시작=", start_ok,
				" 세곳=", walk_ok, " 보고=", report_ok, " 명부=", roster_ok, " 부녀회=", women_ok)
			GameData.minutes = keep_min_ho
			m.map_ui.visible = map_keep_ho
			_s2_police_teardown(cop_ho)
			_s2_restore(k_ho)
		396:
			# ---- 고장 점원(S3c) — 방 없는 일터: 수길 앞 대화에서 일자리 이야기·근무·봉급 ----
			var k_hc := _s2_keep()
			m.dialog.close()
			_s2_fresh_gov()
			GameData.day = 40
			var keep_min_hc := GameData.minutes
			GameData.minutes = 10 * 60
			GameData.aff_add("miller", 25 - GameData.aff("miller"))
			GameData.skills["farm"].lv = 2
			var ch_m: Array = [["대화 끝", null]]
			m.society.add_talk_choices("miller", ch_m)
			var offer_ok := false
			for c1 in ch_m:
				if str(c1[0]) == "일자리 이야기":
					offer_ok = true
			var open_ok: bool = m.society.can_hire_job("miller_hand") == ""   # 고장 사람은 첫 인사 없이도 열려 있다
			m.society.hire_job("miller_hand")
			m.dialog.close()
			GameData.day += 1
			var ch_m2: Array = [["대화 끝", null]]
			m.society.add_talk_choices("miller", ch_m2)
			var work_choice := false
			var no_offer := true
			for c2 in ch_m2:
				if str(c2[0]) == "근무":
					work_choice = true
				if str(c2[0]) == "일자리 이야기":
					no_offer = false
			m.society.work_start("")
			var enc_ok: bool = m.dialog.visible and m.dialog._seq.size() >= 1
			m.society.work_pick(0)
			m.dialog.close()
			var work_ok: bool = int(GameData.me.perf) == 1 and int(GameData.me.wage_pending) == 80 \
				and GameData.worked_on(GameData.day)
			var ch_m3: Array = [["대화 끝", null]]
			m.society.add_talk_choices("miller", ch_m3)
			var done_gray := false
			for c3 in ch_m3:
				if str(c3[0]) == "… 근무":
					done_gray = true
			print("HAMLET_CLERK_OK=", offer_ok and open_ok and work_choice and no_offer and enc_ok and work_ok and done_gray,
				" 일자리이야기=", offer_ok, " 열림=", open_ok, " 근무선택지=", work_choice and no_offer,
				" 손님=", enc_ok, " 근무=", work_ok, " 하루한번=", done_gray)
			GameData.minutes = keep_min_hc
			_s2_restore(k_hc)
		397:
			# ---- 자유직 목수(S3c) — 제작대 완성 수가 마흔이면 「목수」로 불린다 ----
			var k_cp := _s2_keep()
			var tb_keep := GameData.things_built
			var dq_keep: Array = GameData.desk_queue.duplicate(true)
			var bin_keep := int(GameData.items.get("trash_bin", 0))
			_s2_fresh_gov()
			GameData.desk_queue = [{"id": "trash_bin", "left": 0.1}]
			GameData.desk_tick(1.0)
			var count_ok: bool = GameData.things_built == tb_keep + 1 and GameData.desk_queue.is_empty()
			GameData.desk_done_pending.clear()
			GameData.items["trash_bin"] = bin_keep
			# 문턱 — 다른 자유직 통계를 비우고 마흔을 채우면 목수
			GameData.trees_chopped = 0
			GameData.rocks_mined = 0
			GameData.fish_caught = {}
			GameData.recipes_cooked = {}
			GameData.forage_caught = {}
			GameData.mob_kills = {}
			GameData.crops_harvested = {}
			GameData.animals_now = 0
			GameData.things_built = 39
			var not_yet: bool = GameData.free_title_of() != "carpenter"
			GameData.things_built = 40
			var title_cp: Dictionary = GameData.player_title("merchant")
			# 만수 호감이 70이면 「우리 마을 목수」(free_master)로 불린다 — 둘 다 목수다
			var title_ok: bool = GameData.free_title_of() == "carpenter" \
				and str(title_cp.cls) in ["free_known", "free_master"] and str(title_cp.text).contains("목수")
			print("CARPENTER_OK=", count_ok and not_yet and title_ok, " 셈=", count_ok, " 문턱전=", not_yet,
				" 호칭=", title_ok, "(", title_cp.text, ")")
			GameData.things_built = tb_keep
			GameData.desk_queue = dq_keep
			_s2_restore(k_cp)
		398:
			# ---- 성능 3종(S4a) — 일과 지터·길찾기 프레임 예산·거리 LOD. 예순 명을 더 세우고 한 프레임을 잰다 ----
			var k_pf := _soc_keep()
			m.dialog.close()
			var keep_min_pf := GameData.minutes
			var map_keep_pf: bool = m.map_ui.visible
			m.map_ui.visible = false
			m.story_cutscene = false
			# 프레임 예산 — 한 프레임에 길찾기 둘까지(아직 이 프레임에 아무도 길을 안 찾았다 — 부모가 먼저 돈다)
			var slots: Array = [m.npcmgr.path_slot(), m.npcmgr.path_slot(), m.npcmgr.path_slot()]
			var slot_ok: bool = slots[0] and slots[1] and not slots[2]
			var far_pf: Vector2i = m.nearest_open_tile(m.HAMLETS.brookside.square)   # 물소리 마을 — 나에게서 200칸 넘게
			var spawned_pf: Array = []
			for i in 60:
				var nid_pf := str(GameData.SETTLER_POOL[i % GameData.SETTLER_POOL.size()])
				m.npcmgr._spawn_npc(nid_pf, far_pf + Vector2i(i % 8, i / 8))
				spawned_pf.append(m.npcs[-1])
			# 지터 — 자리가 바뀐 시각(순돌은 10시 광장)에 제 몫의 분만큼 늦게 움직이고, 스무 분 뒤엔 모두 제자리다
			GameData.minutes = 8 * 60 + 30
			for n in spawned_pf:
				n._process(0.016)
			GameData.minutes = 8 * 60 + 59
			for n in spawned_pf:
				n._process(0.016)
			# 거리 LOD — 물소리 마을에서 교진 일터까지는 200칸이 넘는다: 지터가 풀린 뒤(8시 59분) 자리가 있는 사람은 길을 안 찾고 목적지에 섰다
			var with_dest := 0
			var teleported := 0
			for n in spawned_pf:
				if n.dest.x == -999:
					continue
				with_dest += 1
				var nt := Vector2i(int(floor(n.position.x / m.TILE)), int(floor(n.position.y / m.TILE)))
				if nt == n.dest and n.route.is_empty():
					teleported += 1
			var lod_ok: bool = with_dest > 0 and teleported == with_dest
			var farmer_pf: Node2D = null
			var jit_set := {}
			for n in spawned_pf:
				jit_set[int(n._jitter_min)] = true
				if farmer_pf == null and str(n.id) == "farmer":
					farmer_pf = n
			GameData.minutes = 10 * 60
			for n in spawned_pf:
				n._process(0.016)
			var jit_farmer := int(farmer_pf._jitter_min) if farmer_pf != null else 0
			var delay_ok: bool = jit_farmer == 0 or str(farmer_pf.place) == "home"
			var jit_ok: bool = jit_set.size() >= 3 and delay_ok
			for jv in jit_set:
				jit_ok = jit_ok and int(jv) >= 0 and int(jv) <= 20
			GameData.minutes = 10 * 60 + 21
			for n in spawned_pf:
				n._process(0.016)
			var all_moved := true
			for n in spawned_pf:
				if str(n.place) != m.npcmgr.npc_place_now(str(n.id)):
					all_moved = false
			# 한 프레임 — 모든 NPC 를 한 번씩 돌린 시간
			var t0_pf := Time.get_ticks_usec()
			for n in m.npcs:
				n._process(0.016)
			var frame_us := Time.get_ticks_usec() - t0_pf
			var frame_ok: bool = frame_us < 50000
			print("NPC_PERF_OK=", jit_ok and all_moved and lod_ok and slot_ok and frame_ok,
				" 지터=", jit_ok, "(순돌 ", jit_farmer, "분 지터값 ", jit_set.size(), "종)",
				" 21분뒤=", all_moved, " LOD=", lod_ok, "(", teleported, "/", with_dest, ")", " 예산=", slot_ok,
				" 프레임=", frame_ok, "(", frame_us, "us, NPC ", m.npcs.size(), ")")
			for n in spawned_pf:
				m.npcs.erase(n)
				n.queue_free()
			GameData.minutes = keep_min_pf
			m.map_ui.visible = map_keep_pf
			_soc_restore(k_pf)
		399:
			# ---- 갈뫼읍(S4b) — 억새 벌판에 처음부터 서 있는 읍: 부지·문·방·장터·가로등·팻말·정류장·버스 ----
			var k_tw := _s2_keep()
			m.dialog.close()
			if m.shop_room.visible:
				m.shop_room.close()
			var keep_min_tw := GameData.minutes
			var map_keep_tw: bool = m.map_ui.visible
			m.map_ui.visible = false
			# 부지 여덟 + 주택 여덟 — 본체는 house, 문은 밟힌다, 문의 종류가 부지 id 다
			var plots_ok := true
			var bad_tw: Array = []
			for tid: String in m.TOWN_PLOTS:
				var ta: Vector2i = m.TOWN_PLOTS[tid].anchor
				var door_tw: Vector2i = m.door_tile(ta)
				var body_ok: bool = str(m.objects.get(ta, {}).get("kind", "")) == "house" \
					and str(m.objects.get(ta + Vector2i(4, 3), {}).get("kind", "")) == "house"
				var door_ok: bool = m.is_passable(door_tw) and m.actions._door_kind_at(door_tw) == tid \
					and m.actions._building_kind_at(ta + Vector2i(1, 1)) == tid
				var node_ok: bool = m.obj_nodes.has(ta) and m.shop_room.has_room(tid)
				if not (body_ok and door_ok and node_ok):
					plots_ok = false
					bad_tw.append([tid, body_ok, door_ok, node_ok])
			var homes_tw := 0
			for th: Vector2i in m.TOWN_HOMES:
				if str(m.objects.get(th, {}).get("kind", "")) == "house" and m.is_passable(m.door_tile(th)):
					homes_tw += 1
			# 읍 안에는 자연물이 없고 바닥은 자갈이다
			var wild_tw := 0
			var gravel_tw := 0
			var r_tw: Rect2i = m.TOWN_RECT
			for y_tw in range(r_tw.position.y, r_tw.end.y):
				for x_tw in range(r_tw.position.x, r_tw.end.x):
					var p_tw := Vector2i(x_tw, y_tw)
					if m.objects.has(p_tw) and m.worldgen._is_wild(str(m.objects[p_tw].kind)):
						wild_tw += 1
					if str(m.grid[y_tw][x_tw].ground) == "path":
						gravel_tw += 1
			var clear_ok: bool = wild_tw == 0 and gravel_tw > r_tw.size.x * r_tw.size.y / 2
			# 장터 여덟 · 가로등 열둘 · 팻말 · 정류장 둘
			var stalls_tw := 0
			for st_tw: Vector2i in m.TOWN_STALLS:
				if str(m.objects.get(st_tw, {}).get("kind", "")) == "market_stall":
					stalls_tw += 1
			var lamps_tw := 0
			for lp_tw: Vector2i in m.TOWN_LAMPS:
				if str(m.objects.get(lp_tw, {}).get("kind", "")) == "deco_lamp":
					lamps_tw += 1
			var fixtures_ok: bool = stalls_tw == 8 and lamps_tw == 12 \
				and str(m.objects.get(m.TOWN_SIGN, {}).get("kind", "")) == "sign" \
				and m.bus_tiles.has("kyojin") and m.bus_tiles.has("town") \
				and str(m.objects.get(m.bus_tiles.kyojin, {}).get("kind", "")) == "bus_stop" \
				and str(m.objects.get(m.bus_tiles.town, {}).get("kind", "")) == "bus_stop"
			# 발견 — 팻말을 읽으면 town_open, 지도에 이름
			GameData.town_open = false
			m.village.open_town_sign()
			var found_ok: bool = GameData.town_open and m.dialog.visible
			m.dialog.close()
			# 문으로 들어가면 방이 열리고, 창구 E 는 「사람이 없다」
			GameData.minutes = 11 * 60
			m.actions._enter_building("county")
			var room_ok: bool = m.shop_room.visible and m.shop_room.room_id == "county"
			m.village.room_action("town")   # 우두머리(강 군수)의 한마디 — 채용 자격이 없을 때의 창구
			var counter_ok: bool = m.dialog.visible and str(m.dialog.title_label.text) == "강 군수"
			m.dialog.close()
			m.shop_room.close()
			# 버스 — 개통 전엔 팻말뿐, 개통 뒤 50G 에 반 시간, 19시 뒤엔 없다, 평판 −40 이면 거부
			var gd_keep: Array = GameData.gov_done.duplicate()
			GameData.gov_done = []
			m.village.open_bus_stop(m.bus_tiles.kyojin)
			var before_ok: bool = m.dialog.visible and str(m.dialog.body_label.text).contains("아직")
			m.dialog.close()
			GameData.gov_done = ["bus"]
			GameData.money = 500
			var pos_tw: Vector2 = m.player.position
			m.village.open_bus_stop(m.bus_tiles.kyojin)
			var offer_ok: bool = "갈뫼읍행 — 50G" in _btn_texts()
			m.dialog.close()
			var budget_tw := int(GameData.gov_budget.kyojin)
			m.village._bus_ride("town")
			m.village._bus_arrive("town")
			var pt_tw: Vector2i = m.player_tile()
			var ride_ok: bool = GameData.money == 450 and int(GameData.gov_budget.kyojin) == budget_tw + 50 \
				and GameData.minutes == 11 * 60 + 30 and absi(pt_tw.x - m.bus_tiles.town.x) <= 2 \
				and absi(pt_tw.y - m.bus_tiles.town.y) <= 2
			GameData.minutes = 20 * 60
			m.village.open_bus_stop(m.bus_tiles.town)
			var night_ok: bool = m.dialog.visible and str(m.dialog.body_label.text).contains("밤")
			m.dialog.close()
			GameData.minutes = 11 * 60
			GameData.me.reputation.kyojin = -50
			m.village.open_bus_stop(m.bus_tiles.town)
			var refuse_ok: bool = m.dialog.visible and str(m.dialog.body_label.text).contains("기사")
			m.dialog.close()
			print("TOWN_OK=", plots_ok and homes_tw == 8 and clear_ok and fixtures_ok and found_ok and room_ok
				and counter_ok and before_ok and offer_ok and ride_ok and night_ok and refuse_ok,
				" 부지=", plots_ok, bad_tw, " 주택=", homes_tw, " 비움=", clear_ok, "(자연물 ", wild_tw, " 자갈 ", gravel_tw, ")",
				" 설치물=", fixtures_ok, "(점포 ", stalls_tw, " 등 ", lamps_tw, " 정류장 ", m.bus_tiles, ")",
				" 발견=", found_ok, " 방=", room_ok, " 창구=", counter_ok, " 개통전=", before_ok,
				" 승차=", offer_ok, " 도착=", ride_ok, pt_tw, " 밤=", night_ok, " 거부=", refuse_ok)
			GameData.gov_done = gd_keep
			m.player.position = pos_tw
			GameData.minutes = keep_min_tw
			m.map_ui.visible = map_keep_tw
			_s2_restore(k_tw)
		401:
			# ---- 갈뫼읍 사람들(S4c) — 손글 아홉·자리·창구 채용·판사의 근무·장물아비 ----
			var k_tn := _s2_keep()
			m.dialog.close()
			if m.shop_room.visible:
				m.shop_room.close()
			var keep_min_tn := GameData.minutes
			# 아홉이 제자리에 있고, 주민 수엔 안 들고, 그림이 실려 있다
			var here_tn := 0
			var placed_tn := 0
			var tex_tn := 0
			for nid_tn: String in m.TOWN_NPC_IDS:
				if _npc_node(nid_tn) != null:
					here_tn += 1
				if m.TOWN_RECT.grow(2).has_point(m.npcmgr.npc_place_tile(nid_tn, "work")) \
						and m.TOWN_RECT.grow(2).has_point(m.npcmgr.npc_place_tile(nid_tn, "square")):
					placed_tn += 1
				if m.tex.has("npc_%s_down_0" % nid_tn) and m.tex.has("npc_%s_portrait_normal" % nid_tn):
					tex_tn += 1
			var res_tn := m.village_residents()
			var count_tn := 1
			for n_tn in m.npcs:
				if str(n_tn.id) not in m.HAMLET_NPC_IDS and str(n_tn.id) not in m.TOWN_NPC_IDS:
					count_tn += 1
			var people_ok: bool = here_tn == 9 and placed_tn == 9 and tex_tn == 9 and res_tn == count_tn \
				and GameData.npc_kind("judge_suh") == "town"
			# 창구 — 법원 계산대: 자격이 안 되면 창구 메뉴가 안 뜨고, 되면 「일자리 이야기」
			_s2_fresh_gov()
			GameData.day = 40
			GameData.minutes = 10 * 60
			GameData.aff_add("judge_suh", 40 - GameData.aff("judge_suh"))
			GameData.me.reputation.kyojin = 50
			GameData.me.books_read = 5
			var book_refuse: String = m.society.can_hire_job("judge")
			GameData.me.books_read = 12
			m.story_cutscene = false   # 계산대 메뉴는 연출 중엔 안 뜬다
			var menu_ok: bool = book_refuse.contains("열두 권") and m.society.can_hire_job("judge") == "" \
				and m.society.counter_menu("court") and "일자리 이야기" in _btn_texts()
			m.dialog.close()
			m.society.hire_job("judge")
			m.dialog.close()
			var hire_tn: bool = str(GameData.me.job) == "judge" and GameData.seat_of("court", "judge") == "player" \
				and str(GameData.player_title("merchant").cls) != "office"   # 근속 14일 전엔 아직 판사님이 아니다
			# 다음날 법정 — 피고 하나, 판결 셋 중 하나, 일급 300
			GameData.day += 1
			m.society.work_start("court")
			var bench_ok: bool = m.dialog.visible and m.dialog._seq.size() >= 1
			m.society.work_pick(0)
			m.dialog.close()
			var work_tn: bool = int(GameData.me.perf) == 1 and int(GameData.me.wage_pending) == 300 \
				and GameData.worked_on(GameData.day)
			GameData.day += 14
			var title_tn: bool = str(GameData.player_title("merchant").text).contains("판사님")   # 만수가 70이면 「우리 판사님」
			# 장물아비 — 훔친 달걀 둘, 반값. 팔고 나면 장물이 없다
			GameData.items["egg"] = int(GameData.items.get("egg", 0)) + 2
			GameData.me.stolen = {"egg": 2}
			var ch_f: Array = [["대화 끝", null]]
			m.society.add_talk_choices("fence_gu", ch_f)
			var fence_choice := false
			for c_f in ch_f:
				if str(c_f[0]) == "물건 넘기기":
					fence_choice = true
			var money_tn := GameData.money
			var eggs_tn := int(GameData.items.egg)
			m.society.sell_stolen()
			m.dialog.close()
			var fence_ok: bool = fence_choice and GameData.money == money_tn + 24 and int(GameData.items.egg) == eggs_tn - 2 \
				and GameData.me.stolen.is_empty()
			print("TOWN_NPC_OK=", people_ok and menu_ok and hire_tn and bench_ok and work_tn and title_tn and fence_ok,
				" 사람=", people_ok, "(", here_tn, " 자리 ", placed_tn, " 그림 ", tex_tn, " 주민 ", res_tn, "/", count_tn, ")",
				" 창구=", menu_ok, "(", book_refuse, ")", " 채용=", hire_tn, " 법정=", bench_ok, " 근무=", work_tn,
				" 호칭=", title_tn, " 장물=", fence_ok)
			GameData.items["egg"] = eggs_tn - 2
			GameData.minutes = keep_min_tn
			_s2_restore(k_tn)
		273:
			# ---- 자기 상점(S3a) — 허가·좌판·올리기·손님 정산·금고·매출세·영업정지·폐업 ----
			var k_sh := _s2_keep()
			var items_sh: Dictionary = GameData.items.duplicate()
			var prod_sh: Dictionary = GameData.produce.duplicate()
			var ps_sh: Dictionary = GameData.produce_silver.duplicate()
			var pg_sh: Dictionary = GameData.produce_gold.duplicate()
			m.dialog.close()
			_s2_fresh_gov()
			GameData.money = 1000
			GameData.day = 40                                  # 계절 2 의 12일 — 첫날 고지서와 겹치지 않게
			GameData.skills["farm"].lv = 3
			GameData.skills["fish"].lv = 1
			# 허가 창구 — 농산물전은 열리고 어물전은 회색(숙련)
			m.society.open_shop_permit()
			var kinds_sh: Array = _btn_texts()
			m.dialog.close()
			var kinds_ok: bool = "농산물전 — 밭에서 난 것" in kinds_sh and "… 어물전 — 낚은 것" in kinds_sh
			var budget_sh := int(GameData.gov_budget.kyojin)
			m.society._permit("farm")
			m.dialog.close()
			var t_sh: Vector2i = m.society._stand_tile()
			var permit_ok: bool = GameData.shop_open() and GameData.money == 500 \
				and int(GameData.gov_budget.kyojin) == budget_sh + 500 and t_sh.x >= 0 \
				and str(m.objects.get(t_sh, {}).get("kind", "")) == "shop_stand" \
				and GameData.shop_permit_why() != ""
			# 올리기 — 밀 5 제값(35) · 달걀 3 비싸게(37). 가방에서 그만큼 빠진다
			GameData.produce["wheat"] = int(GameData.produce.get("wheat", 0)) + 8
			GameData.items["egg"] = int(GameData.items.get("egg", 0)) + 3
			var wheat_before := int(GameData.produce["wheat"])
			m.society._stand_put_do("wheat", 5, "fair")
			m.society._stand_put_do("egg", 3, "dear")
			m.dialog.close()
			var st_sh: Dictionary = GameData.me.shop_stock
			var put_ok: bool = int(GameData.produce["wheat"]) == wheat_before - 5 \
				and int(st_sh.get("wheat", {}).get("qty", 0)) == 5 and int(st_sh.get("wheat", {}).get("price", 0)) == 35 \
				and int(st_sh.get("egg", {}).get("qty", 0)) == 3 and int(st_sh.get("egg", {}).get("price", 0)) == 37
			# 정산 — 손님이 다 산다고 고정: 손님 수만큼 팔리고, 돈은 금고에 남는다
			GameData.shop_force_p = 1.0
			GameData.day += 1
			var cust_sh := GameData.shop_customers(GameData.day - 1)
			GameData.society_new_day([0, 0, 0])
			var n_sh := GameData.society_note()
			GameData.shop_force_p = -1.0
			var led_sh: Dictionary = GameData.me.shop_ledger[-1]
			var left_sh := 0
			for id_sh in GameData.me.shop_stock:
				left_sh += int(GameData.me.shop_stock[id_sh].qty)
			var sold_sh := int(led_sh.sold)
			var settle_ok: bool = sold_sh == mini(cust_sh, 8) and left_sh == 8 - sold_sh \
				and int(GameData.me.shop_own.till) == int(led_sh.gold) and int(led_sh.gold) > 0 \
				and n_sh.contains("팔렸다")
			# 금고 — 좌판 앞에서 받아야 내 돈이다
			var money_sh := GameData.money
			m.society._stand_collect()
			m.dialog.close()
			var till_ok: bool = GameData.money == money_sh + int(led_sh.gold) and int(GameData.me.shop_own.till) == 0
			# 매출세 — 계절 첫날 고지서에 28일 매출의 5% 한 줄(정산보다 먼저 계산된다)
			GameData.day = 57                                  # 계절 3 의 1일
			GameData.society_new_day([0, 0, 0])
			GameData.society_note()
			var bill_sh: Dictionary = GameData.me.tax_bills[-1]
			var tax_ok: bool = int(bill_sh.get("sales", -1)) == int(float(int(led_sh.gold)) * 0.05) \
				and int(bill_sh.get("season", -1)) == 2
			# 영업정지 — 여섯 주 밀린 고지서가 있으면 손님이 와도 팔지 않는다
			GameData.me.tax_bills = [{"season": 0, "day": 1, "income": 0, "property": 0, "sales": 0,
				"total": 100, "paid": 0, "due_day": GameData.day - 45}]
			GameData.me.shop_stock = {"wheat": {"qty": 3, "price": 35}}
			GameData.shop_force_p = 1.0
			GameData.day += 1
			GameData.society_new_day([0, 0, 0])
			var n_sh2 := GameData.society_note()
			GameData.shop_force_p = -1.0
			var frozen_ok: bool = GameData.wage_frozen() and n_sh2.contains("영업정지") \
				and int(GameData.me.shop_stock.wheat.qty) == 3
			# 폐업 — 물건은 가방으로, 좌판은 사라진다
			var wheat_bag := int(GameData.produce["wheat"])
			m.society._stand_close()
			m.dialog.close()
			var close_ok: bool = not GameData.shop_open() and int(GameData.produce["wheat"]) == wheat_bag + 3 \
				and not m.objects.has(t_sh) and GameData.me.shop_stock.is_empty()
			print("SHOP_OK=", kinds_ok and permit_ok and put_ok and settle_ok and till_ok and tax_ok and frozen_ok and close_ok,
				" 종류=", kinds_ok, " 허가=", permit_ok, t_sh, " 올리기=", put_ok, " 정산=", settle_ok,
				"(손님 ", cust_sh, " 팔림 ", sold_sh, " ", int(led_sh.gold), "G)", " 금고=", till_ok,
				" 매출세=", tax_ok, "(", int(bill_sh.get("sales", -1)), ")", " 영업정지=", frozen_ok, " 폐업=", close_ok)
			if m.objects.has(t_sh):
				m.objnode._remove_object(t_sh)
			GameData.items = items_sh
			GameData.produce = prod_sh
			GameData.produce_silver = ps_sh
			GameData.produce_gold = pg_sh
			_s2_restore(k_sh)
		252:
			# 집 꾸미기 — 깔려 있는 러그를 집어 옮길 수 있어야 한다.
			# 예전에는 안내에 **집는 키가 적혀 있지 않아** 「깔려 있는데
			# 못 옮기는 것」처럼 보였다. 이제 가리키고 누르면 집힌다.
			var k_lv := GameData.house_lv
			var k_furn: Array = GameData.furniture.duplicate(true)
			GameData.house_lv = 2
			m.interior._layout()
			GameData.furniture = [{"id": "heart_rug", "x": 366.0, "y": 285.0}]
			m.interior.deco_mode = true
			m.interior.held = {}
			var rug0: Dictionary = GameData.furniture[0]
			# ① 러그를 가리키면 그것이 잡힌다
			m.interior._mouse = m.interior._furn_rect(rug0).get_center()
			var aimed: Dictionary = m.interior._furn_at(m.interior._aim_point())
			var aim_ok: bool = str(aimed.get("id", "")) == "heart_rug"
			# ② 집어서 옮기고 놓는다
			m.interior._pick_up()
			var held_ok: bool = not m.interior.held.is_empty()
			m.interior._mouse = Vector2(-999, -999)
			m.interior._move_cursor(Vector2(480, 300))
			m.interior._place_held()
			var moved_ok: bool = m.interior.held.is_empty() \
				and GameData.furniture.size() == 1 \
				and absf(float(GameData.furniture[0].x) - 366.0) > 4.0
			# ③ 우클릭(취소)은 들고 있던 것을 제자리로 되돌린다
			m.interior._mouse = m.interior._furn_rect(GameData.furniture[0]).get_center()
			m.interior._pick_up()
			var back_x := float(GameData.furniture[0].get("orig_x", -1.0))
			m.interior._move_cursor(Vector2(300, 400))
			m.interior._cancel_held()
			var undo_ok: bool = back_x > 0.0 \
				and absf(float(GameData.furniture[0].x) - back_x) < 0.01
			m.interior.deco_mode = false
			m.interior.held = {}
			GameData.furniture = k_furn
			GameData.house_lv = k_lv
			m.interior._layout()
			m.hud._toast_queue.clear()
			m.hud.hide_bubble()
			print("DECO_OK=", aim_ok and held_ok and moved_ok and undo_ok,
				" 가리킴=", aim_ok, " 집힘=", held_ok, " 옮김=", moved_ok,
				" 취소=", undo_ok)
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
			_perf_probe = true          # 재는 동안 시퀀스가 안에서 돌지 않게
			var t0 := Time.get_ticks_usec()
			for i in 20:
				m._process(0.016)
			var proc_us := (Time.get_ticks_usec() - t0) / 20.0
			_perf_probe = false
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
			GameData.aff_set("merchant", 0)
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
				var d: Dictionary = GameData.npc_def(nid)
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
			var hidden: bool = m.grid[m.WORLD_H - 2][30].ground == "water" \
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
			# 해안선이 굽이치므로(world_gen._build_sea) 줄 하나를 콕 집어
			# 보면 안 된다 — 그 칸에 모래가 한 줄이라도 깔렸는지로 본다
			var sand := false
			for sy0 in range(m.BEACH_Y0 - 4, m.SEA_Y0 + 6):
				if sy0 >= 0 and sy0 < m.MAP_H and str(m.grid[sy0][30].ground) == "sand":
					sand = true
			var water: bool = m.grid[m.WORLD_H - 2][30].ground == "water"
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
			# 상점은 처음부터 서 있다 — 이장 대화가 끝나면 곧장 낚시꾼(바닷길)이다
			var shop_q: bool = GameData.story2_phase == "fisher"
			var shop_built: bool = GameData.village_built.has("general") \
				and GameData.npc_greeted.has("merchant")
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
			# 도서관은 처음부터 서 있다 — 이장이 사서에게 맡기고, 사서에게 가면 정착한다
			var keep6_built: Array = GameData.village_built.duplicate()
			var gated: bool = GameData.story6_objective_short() == "이장에게 사서 이야기를 전하자."
			m.story._start_book_chief2_dialog()
			m.dialog.close()
			m.story._end_book_chief2()
			var build_open: bool = GameData.story6_phase == "build" \
				and GameData.story6_objective_short().contains("사서에게")
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
			# 여는 순간의 한 번(굽기)은 따로 재고, 여기서부터는 **끄는 동안의
			# 한 장**만 센다 — 벤치가 보려는 것이 그것이다
			m.map_ui._bake()
			m.map_ui.draw_us = 0
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
			# 굽기는 **여는 순간 한 번**이라 예산이 다르다. 소프트웨어 렌더러의
			# 느린 CI 상자에서 2만 7천 칸에 65ms쯤 — 여유를 두고 90ms로 잡는다.
			# (칸마다 구역을 훑던 시절에는 160ms였다. 이 선이 그때로 돌아가는 것을 막는다)
			var bake: int = m.map_ui.bake_us
			print("MAPDRAW_OK=", _bench_n > 0 and per_draw < 8000 and bake < 90000,
				" 한 장=", per_draw, "us (", _bench_n, "장 평균 · 배율 1)",
				" 굽기=", bake, "us")
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
			# 새 게임 직후인 척 — 마을엔 건물이 없고 도구도 없다.
			# (하네스가 앞에서 다 지어 놨으니 여기서 되돌려 놓고 잰다)
			GameData.story_phase = "enter"        # 오프닝 한복판인 척
			GameData.story2_phase = ""
			GameData.tutorial = GameData.fresh_tutorial()
			GameData.village_built = []
			GameData.unlocked_tools = []
			m.story.skip_main_story()
			var skip_ok: bool = GameData.story_phase == "done" \
				and GameData.story2_phase == "done" \
				and not bool(GameData.tutorial.get("active", true)) \
				and GameData.is_tool_unlocked("hoe") and GameData.is_tool_unlocked("axe") \
				and GameData.house_lv >= 1 and GameData.has_bed \
				and GameData.sea_open \
				and not m.story_cutscene
			# **여기가 핵심이다.** 잡화점 한 채만 서고 나머지 부지는 비어 있어야
			# 이장의 「마을 발전 이야기」와 도서관·회관·목장 이야기가 살아 있다.
			# 예전에는 전부 세워 버려서 그 이야기들이 통째로 죽었다.
			var built_after: Array = GameData.village_built.duplicate()
			var only_shop: bool = built_after == ["general"]
			# 만들거나 부탁을 받아야 하는 도구는 잠긴 채여야 한다
			var later_locked: bool = not GameData.is_tool_unlocked("spear") \
				and not GameData.is_tool_unlocked("sword") \
				and not GameData.is_tool_unlocked("sprinkler")
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
			print("STORYSKIP_OK=", skip_ok and again_ok and only_shop and later_locked,
				" 기본상태=", skip_ok, " 잡화점만=", only_shop, "(", built_after, ")",
				" 뒷도구잠김=", later_locked, " 두번눌러도=", again_ok)
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


# ---- 사회(S1) 검사의 맡김·되돌림 (226~231) ----
#
# 여섯 단계는 me·자리·지갑·호감도를 통째로 갈아 끼우고 며칠씩 넘긴다. 모두 이 둘로
# 시작하고 끝난다 — 되돌린 뒤 society_loaded() 로 호칭 기준선을 다시 잡아야 다음 아침
# 결산에 거짓 「사람들이 요즘 나를…」 줄이 안 뜬다 (D9). 굴림 강제값도 여기서 푼다 —
# 남겨 두면 실제 플레이의 도둑질이 굳는다.
func _soc_keep() -> Dictionary:
	var npc_state: Array = []
	for n in m.npcs:
		npc_state.append([n, n.position, n.talked_today, n.visible])
	return {
		"me": GameData.me.duplicate(true), "seats": GameData.seats.duplicate(true),
		"npc_wallet": GameData.npc_wallet.duplicate(), "affinity": GameData.affinity.duplicate(),
		"skills": GameData.skills.duplicate(true), "crops": GameData.crops_harvested.duplicate(),
		"money": GameData.money, "day": GameData.day, "minutes": GameData.minutes,
		"energy": GameData.energy, "player_name": GameData.player_name,
		"story_cutscene": m.story_cutscene, "affinity_open": GameData.affinity_open,
		"pos": m.player.position, "fest_done": GameData.fest_done,
		"fest_greeted": GameData.fest_greeted.duplicate(),
		"npc_last_talk": GameData.npc_last_talk.duplicate(),
		# 그 밖에 검사가 만지는 것 — 자유직 재료·오늘 수입·첫인사 목록·조리대 이야기·사람들 자리
		"today_earned": GameData.today_earned, "npc_greeted": GameData.npc_greeted.duplicate(),
		"kitchen_quest": GameData.kitchen_quest, "animals_now": GameData.animals_now,
		"trees": GameData.trees_chopped, "rocks": GameData.rocks_mined,
		"fish": GameData.fish_caught.duplicate(), "recipes": GameData.recipes_cooked.duplicate(),
		"forage": GameData.forage_caught.duplicate(), "mobs": GameData.mob_kills.duplicate(),
		"npc_state": npc_state,
	}


func _soc_restore(k: Dictionary) -> void:
	if m.shop_room.visible:
		m.shop_room.close()
	GameData.me = k.me
	GameData.seats = k.seats
	GameData.npc_wallet = k.npc_wallet
	GameData.affinity = k.affinity
	GameData.skills = k.skills
	GameData.crops_harvested = k.crops
	GameData.money = k.money
	GameData.day = k.day
	GameData.minutes = k.minutes
	GameData.energy = k.energy
	GameData.player_name = k.player_name
	m.story_cutscene = k.story_cutscene
	GameData.affinity_open = k.affinity_open
	m.player.position = k.pos
	GameData.fest_done = k.fest_done
	GameData.fest_greeted = k.fest_greeted
	GameData.npc_last_talk = k.npc_last_talk
	GameData.today_earned = k.today_earned
	GameData.npc_greeted = k.npc_greeted
	GameData.kitchen_quest = k.kitchen_quest
	GameData.animals_now = k.animals_now
	GameData.trees_chopped = k.trees
	GameData.rocks_mined = k.rocks
	GameData.fish_caught = k.fish
	GameData.recipes_cooked = k.recipes
	GameData.forage_caught = k.forage
	GameData.mob_kills = k.mobs
	for st in k.npc_state:
		var n: Node2D = st[0]
		n.position = st[1]
		n.talked_today = st[2]
		n.visible = st[3]
	# 호칭 기준선은 재료(호감도·통계·me)가 전부 제자리로 돌아온 뒤에 잡는다 (D9)
	GameData.society_loaded()
	m.society.force_roll = -1.0
	m.society.force_report = -1.0
	m.dialog.close()


# S2a(세금·예산) 검사가 만지는 것까지 — _soc_keep 위에 얹는다
func _s2_keep() -> Dictionary:
	var k := _soc_keep()
	k["s2"] = {
		"story9": GameData.story9_phase, "house_lv": GameData.house_lv,
		"hall_stock": GameData.hall_stock.duplicate(), "mail_box": GameData.mail_box.duplicate(true),
		"receipt": int(GameData.items.get("tax_receipt", 0)),
		"gov_budget": GameData.gov_budget.duplicate(), "gov_done": GameData.gov_done.duplicate(),
		"gov_building": GameData.gov_building, "gov_tax": GameData.gov_tax_season,
		"gov_log": GameData.gov_log.duplicate(true), "residents": GameData.residents_now,
		"today_spent": GameData.today_spent, "animals_n": m.animals.size(),
		# 파출소(S2b)
		"village_built": GameData.village_built.duplicate(), "arrivals": GameData.arrivals.duplicate(true),
		"cases": GameData.cases.duplicate(true), "case_seq": GameData.case_seq,
		"greed_adj": GameData.npc_greed_adj.duplicate(), "settlers": GameData.settlers.duplicate(),
	}
	return k


func _s2_restore(k: Dictionary) -> void:
	var s2: Dictionary = k.s2
	GameData.story9_phase = s2.story9
	GameData.house_lv = s2.house_lv
	GameData.hall_stock = s2.hall_stock
	GameData.mail_box = s2.mail_box
	GameData.items["tax_receipt"] = s2.receipt
	GameData.gov_budget = s2.gov_budget
	GameData.gov_done = s2.gov_done
	GameData.gov_building = s2.gov_building
	GameData.gov_tax_season = s2.gov_tax
	GameData.gov_log = s2.gov_log
	GameData.residents_now = s2.residents
	GameData.today_spent = s2.today_spent
	GameData.tax_seize_due = 0
	GameData.village_built = s2.village_built
	GameData.arrivals = s2.arrivals
	GameData.cases = s2.cases
	GameData.case_seq = s2.case_seq
	GameData.npc_greed_adj = s2.greed_adj
	GameData.settlers = s2.settlers
	m.hud.clear_guide()
	_soc_restore(k)


# 정부 검사의 공통 출발점 — 창구 열림 · 예산 새로 · 주민 스물
func _s2_fresh_gov() -> void:
	GameData.me = GameData.fresh_me()
	GameData.story9_phase = "done"
	GameData.gov_budget = {"kyojin": 2000}
	GameData.gov_done = []
	GameData.gov_building = ""
	GameData.gov_tax_season = 0
	GameData.gov_log = []
	GameData.tax_seize_due = 0
	GameData.residents_now = 20
	GameData.hall_stock = {}
	# 샌드박스는 부지를 다 세워 두는데, 파출소·진료소 운영비(300씩)가 예산 검산에 끼면 안 된다.
	# 복사본을 쓴다 — _s2_restore 가 원본을 되돌린다
	GameData.village_built = GameData.village_built.duplicate()
	GameData.village_built.erase("inn")
	GameData.village_built.erase("lab")
	m.story_cutscene = true


# 파출소를 세우고 박 순경을 마을에 둔다 — 돌려주는 값은 이 검사가 새로 심은 노드(정리용)
func _s2_police_setup() -> Node2D:
	if not GameData.village_built.has("inn"):
		GameData.village_built.append("inn")
	if not GameData.npc_greeted.has("officer_park"):
		GameData.npc_greeted.append("officer_park")
	var cop := _npc_node("officer_park")
	if cop != null:
		return null
	m.npcmgr._spawn_npc("officer_park", m.player_tile() + Vector2i(3, 0))
	return m.npcs[m.npcs.size() - 1]


func _s2_police_teardown(spawned: Node2D) -> void:
	if spawned != null:
		m.npcs.erase(spawned)
		spawned.queue_free()


func _btn_texts() -> Array:
	var out: Array = []
	for c in m.dialog.buttons_box.get_children():
		if c is Button:
			out.append(str(c.text))
	return out


func _npc_node(nid: String) -> Node2D:
	for n in m.npcs:
		if str(n.id) == nid:
			return n
	return null


# 호칭 상태 하나를 재 본다 — 기대 계급(cls)이 맞는지, 첫마디(call_opener)가 토큰 없이
# 나오는지, 그리고 실제 _talk_to 의 첫 페이지가 그 첫마디인지. 빈 문자열이면 통과,
# 아니면 어긋난 곳. 기대 첫마디도 같은 _paginate_seq 를 지나게 한다 — 두 줄을 넘는
# 대사는 \n 으로 접히고, 아주 긴 줄은 두 페이지가 되므로 날것끼리는 비교가 안 된다
func _title_probe(mer: Node2D, want: String) -> String:
	var t: Dictionary = GameData.player_title("merchant")
	if str(t.cls) != want:
		return "%s→cls %s(%s)" % [want, t.cls, t.text]
	var opener: String = GameData.call_opener("merchant")
	if opener == "" or opener.contains("{"):
		return "%s→첫마디 '%s'" % [want, opener]
	var want_pages: Array = m.dialog._paginate_seq([{"text": opener}])
	mer.talked_today = false
	m.village._talk_to(mer)
	var seq: Array = m.dialog._seq
	var ok: bool = m.dialog.visible and seq.size() >= want_pages.size() + 1
	for i in want_pages.size():
		ok = ok and i < seq.size() and str(seq[i].text) == str(want_pages[i].text) \
			and not seq[i].has("choices")
	var shown: String = str(seq[0].text) if not seq.is_empty() else "(없음)"
	m.dialog.close()
	if not ok:
		return "%s→첫 페이지 '%s' ≠ '%s'" % [want, shown.replace("\n", " "),
			str(want_pages[0].text).replace("\n", " ")]
	return ""


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

# ---------------------------------------------------------------- 시연 영상
#
# 유튜브·스팀에 올릴 **트레일러 원본**을 뽑는다. 검증 시퀀스(_debug_tick)는
# 창을 열었다 닫았다 하며 이 잡는 게 목적이라 영상으로는 못 쓴다.
#
#   KYOJIN_SHOT=1 KYOJIN_REEL=1 godot --path game \
#       --write-movie /tmp/reel.avi --fixed-fps 60
#
# `--fixed-fps`가 붙으면 Godot이 **실제 시간과 무관하게** 한 프레임씩 그려
# 저장한다. 그래서 아래 프레임 번호가 그대로 초가 된다 (60 = 1초).
# 이게 없으면 헤드리스에서 프레임이 들쭉날쭉해 동작이 튄다.
const REEL_END := 1290          # 21.5초
var _reel_walk := KEY_NONE      # 지금 누르고 있는 이동 키


# 그 자리에 세계를 비워 두고 플레이어를 옮긴다 (장면 전환)
func _reel_go(t: Vector2i, face: String, clear: int) -> void:
	for cy in range(t.y - clear, t.y + clear + 1):
		for cx in range(t.x - clear, t.x + clear + 1):
			m.objnode._remove_object(Vector2i(cx, cy))
	m.objnode._clear_tree_falls()
	m.player.position = Vector2(t.x * m.TILE + 16, t.y * m.TILE + 16)
	(m.player.get_node("Camera") as Camera2D).reset_smoothing()
	m.player.dir = face
	_reel_stop()


func _reel_walk_key(code: Key) -> void:
	_reel_stop()
	_reel_walk = code
	_send_key_press(code)


func _reel_stop() -> void:
	if _reel_walk != KEY_NONE:
		_send_key_release(_reel_walk)
		_reel_walk = KEY_NONE


func _reel_tick() -> void:
	match _shot_frames:
		# ---- 농사 (밭 갈기 -> 씨앗 -> 물) ----
		1:
			GameData.minutes = 8.0 * 60.0
			# 개발 빌드는 소지금이 1억G이고 씨앗이 9999개다 — 화면에 그대로
			# 나오면 영상이 우스워진다. 보여 줄 만한 값으로 낮춰 둔다.
			GameData.money = 2450
			for sid: String in GameData.seeds.keys():
				GameData.seeds[sid] = mini(int(GameData.seeds[sid]), 12)
			# 튜토리얼은 **끄지 않는다.** `tutorial.active = false`로 내려 봤더니
			# 대신 할아버지 편지창(퀘스트 안내)이 떠서 20초 내내 화면 한가운데를
			# 덮었다. 목표 상자는 화면 구석이라 이쪽이 훨씬 낫다.
			_reel_go(m.START_TILE, "down", 2)
		40: _reel_walk_key(KEY_D)
		130: _reel_stop()
		160: _send_key(KEY_1)                    # 호미
		180: _send_key(KEY_SPACE)
		240: _send_key(KEY_3)                    # 씨앗
		260: _send_key(KEY_SPACE)
		320: _send_key(KEY_2)                    # 물뿌리개
		340: _send_key(KEY_SPACE)

		# ---- 나무 베기 (쓰러지는 모션이 이 영상의 핵심) ----
		400:
			# 나무는 **마지막 한 방**이 볼거리다. 남은 체력만큼 다 쳐 줘야
			# 쓰러지는 데까지 간다 (2번만 치고 넘어갔더니 다음 장면에서
			# 뒤늦게 쓰러져 화면에 안 나왔다).
			var ft := Vector2i(24, 34)
			_reel_go(ft, "right", 4)
			m.toolwork.set_tool("axe")
			var tr := ft + Vector2i(1, 0)
			m.objects[tr] = {"kind": "tree", "hp": m.TREE_HP}
			m.objnode._spawn_object_node(tr, "tree")
		440: _send_key(KEY_SPACE)
		480: _send_key(KEY_SPACE)
		520: _send_key(KEY_SPACE)                # 여기서 쓰러진다
		# 쓰러지고 밑동이 남는 것까지 보여 주고 넘어간다

		# ---- 바위 캐기 ----
		640:
			var rk := Vector2i(29, 40)
			_reel_go(rk, "right", 3)
			m.toolwork.set_tool("pickaxe")
			var ro := rk + Vector2i(1, 0)
			m.objects[ro] = {"kind": "rock", "hp": 1}
			m.objnode._spawn_object_node(ro, "rock")
		690: _send_key(KEY_SPACE)

		# ---- 마을 ----
		# ---- 마을 (주민들이 보이는 대목 — 여기가 제일 길다) ----
		760:
			GameData.minutes = 13.0 * 60.0
			_reel_go(Vector2i(74, 26), "up", 0)
		800: _reel_walk_key(KEY_W)
		1000: _reel_stop()

		# ---- 밤 ----
		1050:
			GameData.minutes = 21.0 * 60.0
			m._weather_override = GameData.WEATHER_STAR
		1090: _reel_walk_key(KEY_A)
		1210: _reel_stop()

		REEL_END:
			print("REEL_DONE: %d프레임 (%.1f초)" % [REEL_END, REEL_END / 60.0])
			get_tree().quit()


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
