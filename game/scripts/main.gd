# 메인 월드: 맵, 경작, 도구, 자원, 시간, 낮/밤을 관리한다.
#
# 덩치가 커서 몇 갈래를 따로 뺐다 (전부 자식 노드로 붙고 `m`으로 여기를 부른다):
#   scripts/world_gen.gd    지형·길·마을 부지·자원 재생
#   scripts/object_nodes.gd 세계에 서 있는 것들의 노드
#   scripts/farming.gd      농사·목초지·가축
#   scripts/fishing.gd      낚시
#   scripts/riding.gd       탈 것
#   scripts/tool_use.gd     도구 쓰기
#   scripts/interact.gd     상호작용·조준·클릭
#   scripts/day_cycle.gd    하루 흐름과 밤
#   scripts/npcs.gd         NPC 배치·길찾기
#   scripts/save_load.gd    세이브 담기/펴기
#   scripts/player_actions.gd  먹기·요리·조합·아이템
#   scripts/net_sync.gd     함께하기 배관 (@rpc는 전부 여기)
#   scripts/renderer.gd     지형 위에 얹히는 것들 + 화면 안내
#   scripts/village_ui.gd   마을에서 여는 창들 (상점·여관·축제·의뢰·선물)
#   scripts/story.gd        메인 스토리 연출 (각본)
#   scripts/dev_harness.gd  검증 하네스 (KYOJIN_SHOT일 때만)
#
# 이름(class_name)을 붙여 둔 이유가 있다. 갈라낸 쪽에서 `var m: Node2D`로
# 받으면 `m.player`, `m.TILE`이 전부 Variant가 되어 `:=` 타입 추론이 죽는다.
class_name KyojinMain
extends Node2D

# 월드를 넓혔다. 마을·농장 좌표는 그대로 두고 남쪽·동쪽에 야생을 붙인다.
const MAP_W := 168   # 동쪽으로 크게 넓혔다 — 새 건물·콘텐츠가 들어설 땅
const MAP_H := 90
const TILE := 32

const MIN_PER_SEC := 10.0 / 7.0  # 실제 7초 = 게임 10분
const TREE_HP := 3
const ROCK_HP := 2
const WOOD_PER_TREE := 3
const STONE_PER_ROCK := 2

# 물 지속 시간 (게임 분): 손 물주기 6시간, 비는 하루 종일.
# 스프링클러는 이 값을 계속 다시 채워 줘서 사실상 마르지 않는다.
const WET_MANUAL := 360.0
const WET_ALL_DAY := 1200.0
# 날씨가 그날 할 일을 바꾸는 값들 (weather.md 참고)
const STORM_CROP_HURT := 0.25      # 폭풍이 지나간 아침, 작물 한 칸이 주저앉을 확률
const STORM_WOOD_MIN := 12         # 부러진 가지 (목재)
const STORM_WOOD_MAX := 30
const FORAGE_CAP := 12             # 들판에 동시에 있는 채집물 수
const FORAGE_CAP_FOG := 26         # 안개 낀 날
const STAR_FIREFLY_COUNT := 9      # 별밤의 반딧불이 (평소 3)


# 작물 성숙에 필요한 누적 성장 시간 (게임 분) — grow_days를 '시간'으로 해석


# 절반까지 자란 작물은 물을 한 번 더 받아야 계속 자란다 (성장 체크포인트)
const GROW_CHECKPOINT := 0.5


# 이 칸의 작물이 체크포인트에서 물을 기다리며 멈춰 있는가


# grid[y][x] = {ground, watered, crop_id, crop_day, dead}
var grid: Array = []
# Vector2i -> {kind: "tree"|"rock"|"house"|"fence"|"sprinkler", hp: int}
var objects: Dictionary = {}
var obj_nodes: Dictionary = {}  # Vector2i -> Node2D (설치/제거 가능한 오브젝트만)

var tex: Dictionary = {}
var world: Node2D
var overlay: Node2D  # 건물보다 앞에 그리는 안내 텍스트/화살표/날씨 레이어
var player: Node2D
var hud: CanvasLayer
var shop: CanvasLayer
var summary: CanvasLayer
var night: CanvasModulate
var sleep_dialog: ConfirmationDialog
var water_frame := 0
var water_timer := 0.0
var _growth_timer := 0.0
var tree_sprites: Array = []
var weather_time := 0.0
var animals: Array = []

# 낚시 상태: "" | "waiting"(입질 대기) | "bite"(입질!)
var fishing_state := ""
var fishing_timer := 0.0
var fishing_ui: CanvasLayer
var pending_fish: Dictionary = {}
var dialog: CanvasLayer
var map_ui: CanvasLayer
var inventory_ui: CanvasLayer
var interior: CanvasLayer
var cooking_ui: CanvasLayer
var desk_ui: CanvasLayer
var alchemy_ui: CanvasLayer
var quest_ui: CanvasLayer
var note_ui: CanvasLayer
var stats_ui: CanvasLayer
var cave: CanvasLayer
var shop_room: CanvasLayer
var pet: Node2D
var fade_rect: ColorRect

# ---- 멀티플레이 상태 ----
var remote_players := {}  # peer_id -> remote_player 노드
var _pos_sync_timer := 0.0
var _time_sync_timer := 0.0
var _net_ready := false   # 게스트: 스냅샷 수신 완료 여부
var _connect_label: Label
const PLAYER_TINTS := [
	Color(1, 1, 1), Color(1, 0.85, 0.85), Color(0.85, 1, 0.9), Color(0.88, 0.9, 1),
]
var day_transitioning := false
var particles: Array = []

# 개발/CI용: KYOJIN_SHOT=경로 로 실행하면 잠시 후 스크린샷을 저장하고 종료한다.
# KYOJIN_DAY=숫자, KYOJIN_WEATHER=0/1/2 로 시작 날짜/날씨를 강제할 수 있다.
#
# 검증 시퀀스 본체는 scripts/dev_harness.gd에 있다. KYOJIN_SHOT이 켜졌을 때만
# 자식으로 붙으므로, 실제 플레이에서는 아예 존재하지 않는다.
var _shot_path := ""
var harness: KyojinHarness = null
# 메인 스토리 연출 (scripts/story.gd). 규칙이 아니라 각본이라 따로 뺐다.
var story: KyojinStory = null
# 지형·길·마을 부지·자원 재생 (scripts/world_gen.gd)
var worldgen: KyojinWorldGen = null
# 마을에서 여는 창들 — 상점·여관·축제·의뢰·선물 (scripts/village_ui.gd)
var village: KyojinVillage = null
# 지형 위에 얹히는 것들 + 화면 안내 (scripts/renderer.gd)
var renderer: KyojinRenderer = null
# 함께하기 배관 — @rpc는 전부 여기 있다 (scripts/net_sync.gd)
var netsync: KyojinNetSync = null
# 세계에 서 있는 것들의 노드 (scripts/object_nodes.gd)
var objnode: KyojinObjects = null
# 농사·목초지·가축 (scripts/farming.gd)
var farming: KyojinFarming = null
# 낚시 (scripts/fishing.gd)
var fishing: KyojinFishing = null
# 탈 것 (scripts/riding.gd)
var riding: KyojinRiding = null
# 도구 쓰기 — 갈기·물주기·심기·베기·캐기 (scripts/tool_use.gd)
var toolwork: KyojinTools = null
# 상호작용·조준·클릭 (scripts/interact.gd)
var actions: KyojinActions = null
# 하루가 넘어가는 흐름과 밤 (scripts/day_cycle.gd)
var daycycle: KyojinDayCycle = null
# NPC 배치와 길찾기 (scripts/npcs.gd)
var npcmgr: KyojinNpcs = null
# 세이브 담기/펴기 (scripts/save_load.gd)
var saveio: KyojinSaveIO = null
# 먹기·요리·조합·아이템 얻기 (scripts/player_actions.gd)
var doing: KyojinDoing = null
var _weather_override := -1

const TEXTURE_NAMES := [
	"player_f_down_0", "player_f_down_1", "player_f_up_0", "player_f_up_1",
	"player_f_side_0", "player_f_side_1",
	"player_f_down_idle", "player_f_up_idle", "player_f_side_idle",
	"new_boy_down_idle", "new_boy_side_idle", "new_boy_up_idle",
	"new_boy_down_walk_0", "new_boy_down_walk_1",
	"new_boy_down_walk_2", "new_boy_down_walk_3", "new_boy_down_walk_4",
	"new_boy_side_walk_0", "new_boy_side_walk_1",
	"new_boy_side_walk_2", "new_boy_side_walk_3", "new_boy_side_walk_4",
	"new_boy_up_walk_0", "new_boy_up_walk_1",
	"new_boy_up_walk_2", "new_boy_up_walk_3", "new_boy_up_walk_4",
	"egg", "golden_egg", "milk", "ore", "star_ore", "gem", "memory_piece",
	"ghost_essence", "gold_crop", "world_branch",
	# 물고기 · 요리 · 다 자란 작물은 _load_textures가 GameData의 표를 보고
	# 알아서 불러온다 (FISH_IDS · RECIPE_IDS · CROP_IDS).
	"crop_sprout", "crop_small", "crop_medium", "withered",
	"tree_spring", "tree_summer", "tree_fall", "tree_winter",
	"tree_bare", "tree_half", "tree_apple",
	"tree_01", "tree_06", "tree_09", "tree_13", "tree_15",
	"rock", "house", "fence", "sprinkler", "board", "sign",
	"board_quest", "board_unlock", "bed_old", "kitchen_counter",
	"stall", "bait", "flower_pot", "trash_bin", "chief_hut", "chief_house",
	# 마을 건물: 지붕색·덧문·차양·간판이 종류마다 다르다
	"house_post", "house_general", "house_smith", "house_lab", "house_inn",
	"house_library", "house_ranch", "house_fish",
	"deco_fountain", "deco_lamp", "deco_bench",
	"cave", "slime_0", "slime_1", "bat_0", "bat_1", "ghost_0", "ghost_1",
	"ore_node", "chest", "stairs",
	# 연금술 물약 (조합대 결과물)
	"potion_energy", "potion_luck", "potion_swift", "potion_ember",
	"potion_grow", "potion_guard", "potion_moon", "sludge",
	"chicken_0", "chicken_1", "cow_0", "cow_1",
	"pet_dog_0", "pet_dog_1", "pet_cat_0", "pet_cat_1",
	"pet_owl_0", "pet_owl_1", "pet_rabbit_0", "pet_rabbit_1",
	"npc_postman_down_0", "npc_postman_down_1", "npc_postman_up_0",
	"npc_postman_up_1", "npc_postman_side_0", "npc_postman_side_1",
	"npc_postman_portrait_normal", "npc_postman_portrait_happy",
	"npc_merchant_down_0", "npc_merchant_down_1", "npc_merchant_up_0",
	"npc_merchant_up_1", "npc_merchant_side_0", "npc_merchant_side_1",
	"npc_fisher_down_0", "npc_fisher_down_1", "npc_fisher_up_0",
	"npc_fisher_up_1", "npc_fisher_side_0", "npc_fisher_side_1",
	"npc_merchant_portrait_normal", "npc_merchant_portrait_happy",
	"npc_fisher_portrait_normal", "npc_fisher_portrait_happy",
	"npc_blacksmith_down_0", "npc_blacksmith_down_1", "npc_blacksmith_up_0",
	"npc_blacksmith_up_1", "npc_blacksmith_side_0", "npc_blacksmith_side_1",
	"npc_blacksmith_portrait_normal", "npc_blacksmith_portrait_happy",
	"npc_rancher_down_0", "npc_rancher_down_1", "npc_rancher_up_0",
	"npc_rancher_up_1", "npc_rancher_side_0", "npc_rancher_side_1",
	"npc_rancher_portrait_normal", "npc_rancher_portrait_happy",
	"mob_centipede_0", "mob_centipede_1",
	"npc_chief_down_0", "npc_chief_down_1", "npc_chief_up_0",
	"npc_chief_up_1", "npc_chief_side_0", "npc_chief_side_1",
	"npc_chief_portrait_normal", "npc_chief_portrait_happy",
	# 메인 스토리 5: 모험가 무진 + 숲속의 모녀 (연화·솔이)
	"npc_explorer_down_0", "npc_explorer_down_1", "npc_explorer_up_0",
	"npc_explorer_up_1", "npc_explorer_side_0", "npc_explorer_side_1",
	"npc_explorer_portrait_normal", "npc_explorer_portrait_happy",
	"npc_forest_mom_down_0", "npc_forest_mom_down_1", "npc_forest_mom_up_0",
	"npc_forest_mom_up_1", "npc_forest_mom_side_0", "npc_forest_mom_side_1",
	"npc_forest_mom_portrait_normal", "npc_forest_mom_portrait_happy",
	"npc_forest_girl_down_0", "npc_forest_girl_down_1", "npc_forest_girl_up_0",
	"npc_forest_girl_up_1", "npc_forest_girl_side_0", "npc_forest_girl_side_1",
	"npc_forest_girl_portrait_normal", "npc_forest_girl_portrait_happy",
	"weed_plant",
	"bug_butterfly_0", "bug_butterfly_1",
	"bug_dragonfly_0", "bug_dragonfly_1", "bug_firefly_0", "bug_firefly_1",
	"treant_0", "treant_1", "barn", "icon_coin", "icon_heart",
	"icon_hoe", "icon_water", "icon_seed", "icon_axe", "icon_axe_stone",
	"icon_pickaxe", "icon_rod", "icon_wood", "icon_stone",
	"icon_spear", "icon_sword", "arrow", "desk", "recipe",
	# 대장간 장비 (무기·방어구·장신구)
	"gear_sword_wood", "gear_sword_iron", "gear_sword_star",
	"gear_vest_leather", "gear_vest_iron", "gear_vest_star",
	"gear_charm_clover", "gear_charm_ember", "gear_charm_wind",
	"star_shard",
	"horse_down_0", "horse_down_1", "horse_side_0", "horse_side_1",
	"horse_up_0", "horse_up_1",
	"grass_spring_0", "grass_spring_1", "grass_spring_2",
	"grass_summer_0", "grass_summer_1", "grass_summer_2",
	"grass_fall_0", "grass_fall_1", "grass_fall_2",
	"grass_winter_0", "grass_winter_1", "grass_winter_2",
	"soil_dry", "soil_wet", "water_0", "water_1", "path",
	"path_edge_n", "path_edge_s", "path_edge_w", "path_edge_e",
]

const START_TILE := Vector2i(14, 10)
const CAVE_POS := Vector2i(50, 1)
const WORLDTREE_POS := Vector2i(68, 50)  # 세계수 동굴 (깊은 숲)
# 축사(구입 시 농장에 건설). 이 칸이 축사 **문 칸**이고, 그림은 여기서
# 위로 5칸 반 · 좌우로 3칸씩 뻗는다 (7 x 5.5칸). BARN_ART 참고.
const BARN_POS := Vector2i(10, 6)
const BARN_ART := Rect2i(-3, -4, 7, 5)   # BARN_POS 기준 그림이 덮는 칸
const HORSE_HOME := Vector2i(10, 9)      # 산 말을 세워 두는 자리 (축사 앞마당)
# ---- 탈 것 (말) ----
#
# 목장 상회에서 사면 그 자리 근처에 말이 서 있다. **F로 타고 내린다.**
# 탄 동안에는 도구를 쓸 수 없다.


# 산 직후: 축사 앞마당(HORSE_HOME)에 말을 세운다.
# 말은 목장 상회 **실내**에서 사기 때문에 player_tile()을 쓰면 마을 한복판에
# 서 있게 된다 — 「농장에 세워 뒀다」는 안내와 어긋나 말을 못 찾았다.


# 이 칸 둘레에서 오브젝트가 없고 걸어갈 수 있는 자리를 찾는다


# ---- 온실 ----
# 농장 한켠의 유리집. 이 안에서는 계절을 타지 않는다 —
# 아무 씨앗이나 심을 수 있고, 계절이 바뀌어도 시들지 않는다.
# (겨울 작물이 하나뿐이라 겨울이 통째로 비는 문제를 메운다)
const GREENHOUSE := Rect2i(4, 13, 9, 7)
const GREENHOUSE_SIGN := Vector2i(4, 20)
const GREENHOUSE_COST_WOOD := 150
const GREENHOUSE_COST_STONE := 80
const GREENHOUSE_COST_MONEY := 5000
# ---- 교진 마을 ----
# 마을에는 처음에 건물이 하나도 없다.
# 넓은 중앙 광장과 사방으로 뻗은 길, 그리고 나중에 건물이 들어설 빈 부지뿐이다.
# 건물은 진행에 따라 하나씩 세워지며, 그때마다 마을의 모습이 달라진다.
const VILLAGE_REGION := Rect2i(54, 0, 46, 44)   # 부지를 벌리면서 서쪽으로 넓혔다
# 인도는 모두 3줄. 길 폭을 한 곳에서 정하고 건물은 이 선에 맞춰 놓는다.
const ROAD_W := 3
const WEST_LANE_X := 67                    # 서쪽 세로 인도 (x 67~69)
const EAST_LANE_X := 86                    # 동쪽 세로 인도 (x 86~88)
const NS_LANE_X := 77                      # 광장을 지나는 남북 인도 (x 77~79)
const ROAD := Rect2i(30, 8, 30, 3)         # 농장/숲 -> 마을 공용 길 (3줄)
const MAIN_STREET_Y := 8                   # 마을 입구를 가로지르는 큰길 (y 8~10)
const PLAZA := Rect2i(70, 14, 16, 12)      # 중앙 광장 (아주 넓은 평지)
const FOUNTAIN := Rect2i(76, 18, 4, 4)     # 광장 중앙 분수
const FOUNTAIN_DECO := Vector2i(77, 20)    # 분수 조형물 (분수 한가운데)
# (마을을 가르던 남쪽 강과 동쪽 세로 강은 없앴다 — 맵은 하나로 이어진
#  큰 육지다. 물은 서쪽 호수·깊은 숲 연못·남쪽 바다만 남는다)
# ---- 낚시터 (마을 서쪽 호수, 맵에 하나뿐) ----
# 호숫가 잔디밭에서 물을 보고 낚싯대를 던진다. 「낚시」 목표는 여기.
const DOCK_Y := 35                         # 호수 남쪽 물가 (물은 y 28~34)
const FISH_YARD_X0 := 44
const FISH_YARD_X1 := 54
const FISH_SIGN := Vector2i(43, 35)
# 남쪽 바다 (낚시꾼 퀘스트로 열린다) — 능선이 뭍과 해변을 가른다
const SEA_RIDGE_Y := 77            # 바위 능선 줄 — 바다로 가는 길을 막는다
const BEACH_Y0 := 78               # 모래사장 (능선 아래 ~ 바다 위)
const SEA_Y0 := 83                 # 여기부터 남쪽 끝까지 바다
const SEA_GATE := [Vector2i(63, 77), Vector2i(64, 77)]  # 곡괭이로 캐서 여는 길목
const FISHER_ARRIVE := Vector2i(78, 23)  # 낚시꾼이 처음 서 있는 곳 (광장 분수 남쪽)
const SHELL_CAP := 8               # 해변 채집물(조개/산호/쓰레기...) 최대 수
# 해변 모래밭에만 밀려오는 것들 — 조개·비닐봉지·유리 조각·금속 고리(기본),
# 산호 조각·고대 조각(매우 희귀 — 숨겨진 이야기·레시피와 이어진다)
const BEACH_FORAGE := ["forage_shell", "forage_coral", "forage_trash", "forage_glass",
	"forage_ring", "forage_relic"]
const STALL_TILE := Vector2i(72, 79)   # 민지의 해변 노점 (게이트 서남쪽 모래밭)
const FISH_SPOT := Rect2i(42, 26, 14, 12)   # 이 안이면 「낚시터에 있다」
# 호수 둘레 + 마을에서 호수로 드는 어귀(x 53~60)는 나무/돌을 두지 않는다
const FISH_CLEAR := Rect2i(41, 24, 20, 14)
const BOARD_POS := Vector2i(82, 14)        # 광장 게시판 (오늘의 의뢰)
# (광장·낚시터의 가로등과 벤치는 없앴다 — 밤에는 마을도 캄캄하다)
# 메인 스토리 4 — 동쪽 다리 건너, 옛 마을의 경계를 알리는 낡은 표지판.
# 너머(GameData.VILLAGE_ZONES)는 구역을 해금해야 들어갈 수 있다.
const OLD_SIGN := Vector2i(99, 9)

# 우리집: 스토리 1 완료 후 집터(E)에서 목재로 직접 짓는다.
# 자리는 광장 남쪽 빈터 — 북쪽 줄(우체국) 마당과 겹치지 않는 곳으로 옮겼다.
const HOME_ANCHOR := Vector2i(71, 30)   # 광장에서 두 칸 떨어뜨렸다
const HOME_SITE := Vector2i(73, 30)  # 집터 표지판 (건물 그림 한가운데)

# 건물 부지(좌상단 앵커, 5x4). 처음에는 아무것도 없는 빈 공간이며
# 표지판도 건물 이름도 표시하지 않는다. 건설된 뒤에만 실제 건물이 나타난다.
# 건물은 5x4칸 그림에 둘레 마당까지 합쳐 한 채가 7x6칸을 차지한다.
# 북쪽 한 줄 + 서/동 두 줄로 벌려 놓아 서로 붙어 보이지 않는다.
# 부지 사이는 일부러 넓게 둔다 — 다닥다닥 붙으면 벽처럼 보인다.
# 북쪽 줄은 18칸 간격(그림 8칸 + 마당 사이 풀 10칸), 옆줄은 바깥으로 뺐다.
const VILLAGE_PLOTS := {
	# 북쪽 줄 (큰길 위쪽)
	"post":    {"anchor": Vector2i(56, 3),  "name": "우체국"},
	"general": {"anchor": Vector2i(74, 3),  "name": "잡화점"},
	"lab":     {"anchor": Vector2i(92, 3),  "name": "연구소"},
	# 서쪽 줄 (서쪽 세로 길가)
	"smith":   {"anchor": Vector2i(60, 12), "name": "대장간"},
	"ranch":   {"anchor": Vector2i(60, 22), "name": "목장 상회"},
	"inn":     {"anchor": Vector2i(60, 32), "name": "여관"},
	# 동쪽 줄 (동쪽 세로 길가)
	"library": {"anchor": Vector2i(91, 12), "name": "도서관"},
	"fish":    {"anchor": Vector2i(91, 26), "name": "수산시장"},
	# 광장 남쪽 — 주민 10명(플레이어 포함)부터 지을 수 있다 (마을 성장의 정점)
	"hall":    {"anchor": Vector2i(80, 28), "name": "마을회관"},
}
# 이장의 거처 — 처음부터 마을에 있는 작고 낡은 오두막 (광장 북서쪽).
# 주민이 늘면 제대로 된 집으로 다시 지어진다 (GameData.chief_house_lv)
const CHIEF_HUT := Vector2i(71, 11)
# 마당: 건물 그림(5x4) 둘레로 한 칸씩 더. 울타리를 두르고 문 앞만 터 둔다.
const YARD_PAD := 1
# 마을 발전 순서: 이장에게 이야기하면 이 순서대로 하나씩 지을 수 있다.
# (여관·연구소·도서관 부지는 자리만 잡아두고 이후 이야기에서 열린다)
const VILLAGE_BUILD_ORDER := ["post", "general", "smith", "ranch", "fish", "hall"]
const VILLAGE_BUILD_COST := {   # [목재, 석재]
	# general은 메인 스토리 2의 첫 퀘스트 — GameData.SHOP_BUILD_*와 같게 둔다
	"post": [30, 10], "general": [30, 20], "smith": [60, 50],
	"ranch": [80, 40], "fish": [100, 60], "hall": [120, 80],
}


# 마을 주민 수 (플레이어 포함) — 이장 새 집·마을회관 해금 기준
func village_residents() -> int:
	return npcs.size() + 1
# 건물이 생기면 그 건물의 주인이 마을에 자리를 잡는다 (이장은 처음부터 있다)
const VILLAGE_NPC := {"general": "merchant", "smith": "blacksmith",
	"ranch": "rancher", "fish": "fisher"}
# ---- NPC 하루 일과 ----
#
# 시간대마다 갈 곳이 바뀐다. 목적지까지는 길찾기로 걸어가고,
# 도착하면 그 둘레를 어슬렁거린다. 19시(저녁)에는 기존대로 집에 들어간다.
# 새 NPC를 넣을 때는 이 세 표에 한 줄씩만 더하면 된다.
#   [시작 시각, 장소] — 시각 순서대로 적는다
const NPC_SCHEDULE := {
	"chief":      [[6, "home"], [9, "board"], [12, "plaza"], [16, "board"]],
	"merchant":   [[6, "home"], [9, "work"], [13, "plaza"], [15, "work"]],
	"blacksmith": [[6, "home"], [9, "work"], [14, "plaza"], [16, "work"]],
	"rancher":    [[6, "home"], [8, "work"], [12, "plaza"], [15, "work"]],
	"fisher":     [[6, "home"], [8, "pier"], [13, "plaza"], [15, "pier"]],
}
# 광장에서 각자 서는 자리 (한 곳에 몰리지 않게 흩어 둔다)
const NPC_PLAZA := {
	"chief": Vector2i(74, 13), "merchant": Vector2i(70, 15),
	"blacksmith": Vector2i(80, 15), "rancher": Vector2i(70, 19),
	"fisher": Vector2i(80, 19),
}
# 건물이 없는 NPC(이장)의 집 자리
const NPC_HOME := {"chief": Vector2i(72, 20), "explorer": Vector2i(78, 16),
	"forest_mom": Vector2i(31, 28), "forest_girl": Vector2i(34, 28)}
# 낚시터에 나란히 설 순서 (겹치지 않게 한 칸씩 띄운다)
const NPC_PIER_ORDER := ["chief", "merchant", "blacksmith", "rancher", "fisher"]
const NPC_WANDER := 2   # 목적지에 닿은 뒤 어슬렁거리는 반경(타일)

const BUILDING_NAMES := {
	"home": "집", "post": "우체국", "general": "잡화점", "smith": "대장간",
	"lab": "연구소", "inn": "여관", "library": "도서관",
	"ranch": "목장 상회", "fish": "수산시장", "hall": "마을회관",
}
# 폰트 규칙: 큰 글씨(14px+)=갈무리11, 작은 글씨(13px 이하·소형 오버레이)=갈무리9
# 카메라 줌: 1보다 작을수록 더 넓게(작게) 보인다. 화면에 보이는 범위 = 960/줌 x 540/줌
const CAMERA_ZOOM := 0.8                   # 1200 x 675 월드 픽셀 = 37.5 x 21 타일
const UI_FONT := preload("res://assets/fonts/Galmuri11.ttf")
const UI_FONT_SMALL := preload("res://assets/fonts/Galmuri9.ttf")

var npcs: Array = []


func _ready() -> void:
	# 갈라낸 모듈부터 붙인다 — 바로 아래 _build_map()이 worldgen을 쓴다.
	# @rpc는 노드 경로로 상대를 찾으므로 **NetSync는 이름을 바꾸면 통신이 죽는다.**
	worldgen = _mount("world_gen", "WorldGen")
	netsync = _mount("net_sync", "NetSync")
	renderer = _mount("renderer", "Renderer")
	village = _mount("village_ui", "VillageUI")
	story = _mount("story", "Story")
	objnode = _mount("object_nodes", "ObjectNodes")
	farming = _mount("farming", "Farming")
	fishing = _mount("fishing", "Fishing")
	riding = _mount("riding", "Riding")
	toolwork = _mount("tool_use", "ToolUse")
	actions = _mount("interact", "Interact")
	daycycle = _mount("day_cycle", "DayCycle")
	npcmgr = _mount("npcs", "Npcs")
	saveio = _mount("save_load", "SaveIO")
	doing = _mount("player_actions", "PlayerActions")

	_load_textures()
	worldgen._build_map()
	farming.rebuild()

	night = CanvasModulate.new()
	add_child(night)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	overlay = Node2D.new()
	overlay.name = "Overlay"
	overlay.z_index = 100
	overlay.draw.connect(renderer._draw_overlay)
	add_child(overlay)

	player = preload("res://scenes/player.tscn").instantiate()
	player.main = self
	player.position = Vector2(START_TILE.x * TILE + 16, START_TILE.y * TILE + 16)
	world.add_child(player)
	_setup_camera()

	pet = preload("res://scripts/pet.gd").new()
	pet.main = self
	pet.position = player.position + Vector2(14, 4)
	world.add_child(pet)

	hud = preload("res://scenes/hud.tscn").instantiate()
	hud.main = self
	add_child(hud)

	shop = preload("res://scenes/shop.tscn").instantiate()
	shop.main = self
	add_child(shop)

	summary = preload("res://scenes/summary.tscn").instantiate()
	add_child(summary)

	fishing_ui = preload("res://scripts/fishing_ui.gd").new()
	fishing_ui.finished.connect(fishing._on_fishing_finished)
	add_child(fishing_ui)

	dialog = preload("res://scripts/dialog_ui.gd").new()
	add_child(dialog)

	map_ui = preload("res://scripts/map_ui.gd").new()
	map_ui.main = self
	add_child(map_ui)

	inventory_ui = preload("res://scripts/inventory_ui.gd").new()
	inventory_ui.main = self
	add_child(inventory_ui)

	interior = preload("res://scripts/interior_ui.gd").new()
	interior.main = self
	add_child(interior)

	cooking_ui = preload("res://scripts/cooking_ui.gd").new()
	cooking_ui.main = self
	add_child(cooking_ui)
	desk_ui = preload("res://scripts/desk_ui.gd").new()
	desk_ui.main = self
	add_child(desk_ui)
	alchemy_ui = preload("res://scripts/alchemy_ui.gd").new()
	alchemy_ui.main = self
	add_child(alchemy_ui)

	quest_ui = preload("res://scripts/quest_ui.gd").new()
	quest_ui.main = self
	add_child(quest_ui)

	note_ui = preload("res://scripts/note_ui.gd").new()
	note_ui.main = self
	add_child(note_ui)

	stats_ui = preload("res://scripts/stats_ui.gd").new()
	stats_ui.main = self
	add_child(stats_ui)

	cave = preload("res://scripts/cave_ui.gd").new()
	cave.main = self
	add_child(cave)

	shop_room = preload("res://scripts/shop_room.gd").new()
	shop_room.main = self
	add_child(shop_room)

	# 마을 사람들: 이장만 처음부터 광장에 있고,
	# 나머지는 자기 건물이 지어진 뒤에 마을에 자리를 잡는다
	npcmgr._spawn_npc("chief", Vector2i(71, 20))

	sleep_dialog = ConfirmationDialog.new()
	sleep_dialog.dialog_text = "잠자리에 들까요?\n다음 날 아침이 됩니다."
	sleep_dialog.ok_button_text = "잔다"
	sleep_dialog.cancel_button_text = "안 잔다"
	sleep_dialog.confirmed.connect(func() -> void:
		Sound.play_sfx("sfx_sleep")
		daycycle._fade_next_day(false))
	add_child(sleep_dialog)

	_shot_path = OS.get_environment("KYOJIN_SHOT")
	if _shot_path != "":
		harness = load("res://scripts/dev_harness.gd").new()
		harness.name = "DevHarness"
		harness.m = self
		add_child(harness)
	if OS.get_environment("KYOJIN_DAY") != "":
		GameData.day = int(OS.get_environment("KYOJIN_DAY"))
	if OS.get_environment("KYOJIN_WEATHER") != "":
		_weather_override = int(OS.get_environment("KYOJIN_WEATHER"))

	if Net.active():
		multiplayer.peer_connected.connect(netsync._on_peer_connected)
		multiplayer.peer_disconnected.connect(netsync._on_peer_disconnected)
	if Net.is_guest():
		multiplayer.server_disconnected.connect(netsync._on_server_disconnected)
		# 게스트: 로컬 저장 대신 호스트 스냅샷을 기다린다
		GameData.reset_all()
		GameData.tutorial = {"active": false}
		GameData.story_phase = "done"
		GameData.story2_phase = "done"
		GameData.village_built = GameData.ALL_VILLAGE_PLOTS.duplicate()
		GameData.unlock_all_tools()
		player.position = Vector2((START_TILE.x + multiplayer.get_unique_id() % 3 + 1) * TILE + 16,
			START_TILE.y * TILE + 16)
		netsync._show_connecting()
		# 연결이 완료된 뒤에 스냅샷을 요청한다 (그 전 RPC는 유실됨)
		multiplayer.connected_to_server.connect(func() -> void: netsync._req_snapshot.rpc_id(1))
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			netsync._req_snapshot.rpc_id(1)
		objnode._spawn_objects()
		objnode._apply_season_visuals()
		_setup_fade(false)
		return

	var loaded := GameData.load_game()
	if loaded.size() > 0:
		saveio._apply_save(loaded)
		story._apply_story_camera.call_deferred()
		# 스토리 도중 저장했다면 우체부 아저씨가 계속 동행한다
		if GameData.story_phase == "approach":
			story._spawn_postman()  # 아직 대화 전 -> 다시 걸어와 말을 건다
		elif GameData.story_phase in ["equip", "chop", "path", "map", "rock", "travel"]:
			story._spawn_postman()
			story_cutscene = false
			story._postman_state = "follow"
			story._postman.position = player.position + Vector2(-42, 6)
		elif GameData.story_phase == "deliver":
			# 이장에게 가던 도중 저장했다면 우체부가 다시 걸어가 편지를 전한다
			story._spawn_postman()
			story_cutscene = false
			story._postman_state = "deliver"
			story._postman.position = player.position + Vector2(-42, 6)
		elif GameData.story_phase == "greet":
			# 집에 들어간 직후 저장했다면, 나온 셈 치고 이장이 다가온다
			story.start_home_greet.call_deferred()
		if GameData.fisher_quest in ["meet", "follow", "open"]:
			story._restore_fisher.call_deferred()   # 낚시꾼 연출 자리 복구
		hud.show_message("저장된 농장을 불러왔다!")
	else:
		GameData.reset_all()
		var story_shot := _shot_path != "" and OS.get_environment("KYOJIN_STORY") != ""
		if (_shot_path == "" and OS.get_environment("KYOJIN_MP") == "") or story_shot:
			# 메인 스토리 1: 울창한 숲 동남쪽 구석에서 시작한다
			GameData.story_phase = "enter"
			# 스토리로 배우는 조작: 빠른 슬롯은 비운 채 시작한다
			# (도끼를 받아 가방(I)에서 직접 장착해야 사용할 수 있다)
			GameData.tool_slots = []
			for i in GameData.TOOL_SLOT_COUNT:
				GameData.tool_slots.append("")
			GameData.tool = "hoe"
			player.position = Vector2(STORY_SPAWN.x * TILE + 16, STORY_SPAWN.y * TILE + 16)
			story._plant_story_forest()
			story._apply_story_camera.call_deferred()
			hud.show_message("우거진 숲... 이 숲을 지나야 마을이 나온다.", 5.0)
			if not story_shot:
				story._show_intro.call_deferred()
		else:
			player.position = Vector2(4 * TILE + 16, 5 * TILE + 16)
		if _shot_path != "" and not story_shot:
			GameData.unlock_all_tools()  # 검증 시퀀스는 모든 도구 사용
			GameData.story2_phase = "done"
			# 스토리 3·5는 끝난 샌드박스로 시작한다 (검증은 350이 처음부터 돌린다)
			GameData.move_quest = "done"
			GameData.forest_quest = "done"
			GameData.affinity_open = true
			# 스토리 4(마을 확장)도 끝난 샌드박스 — 검증은 263이 처음부터 돌린다
			GameData.story4_phase = "done"
			GameData.zones_open = GameData.ZONE_ORDER.duplicate()
			# 이주 인사도 전부 끝난 샌드박스 — 도착 연출 검증은 265가 돌린다
			GameData.npc_greeted = ["merchant", "blacksmith", "rancher",
				"fisher", "explorer"]
			GameData.village_built = GameData.ALL_VILLAGE_PLOTS.duplicate()
			GameData.seeds["potato"] = 5  # 씨앗 심기 캡처용
			GameData.house_lv = 2         # 집/부엌/침대 캡처용
			GameData.has_bed = true
			GameData.furniture = GameData.default_furniture()  # 넓은 방 캡처용 세간
			for cy in range(0, MAP_H / GameData.EXPLORE_CHUNK + 1):
				for cx in range(0, MAP_W / GameData.EXPLORE_CHUNK + 1):
					GameData.explored[Vector2i(cx, cy)] = true  # 지도 캡처용 전체 탐사
			for y in range(HOME_ANCHOR.y, HOME_ANCHOR.y + 4):
				for x in range(HOME_ANCHOR.x, HOME_ANCHOR.x + 5):
					objects[Vector2i(x, y)] = {"kind": "house", "hp": 0}
			objects.erase(HOME_SITE)
	npcmgr._sync_village_npcs()
	objnode._spawn_objects()
	objnode._apply_season_visuals()
	if GameData.quest.is_empty() and GameData.quest_offers.is_empty():
		GameData.make_daily_quest()

	_setup_fade(loaded.size() > 0 or _shot_path != "")
	# 신규 게임은 _show_intro가 스토리 동안 화면을 가렸다가 직접 페이드한다


# 갈라낸 모듈 하나를 자식으로 붙인다.
# preload가 아니라 load인 이유: 모듈이 KyojinMain을 알아서 서로 참조가 된다.
func _mount(script_name: String, node_name: String) -> Variant:
	var n: Node = load("res://scripts/%s.gd" % script_name).new()
	n.name = node_name
	n.m = self
	add_child(n)
	return n


func _setup_fade(animate_in: bool) -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1 if animate_in else 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	if animate_in:
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 0.0, 0.5)


func _load_textures() -> void:
	for n in TEXTURE_NAMES:
		tex[n] = load("res://assets/sprites/%s.png" % n)
	# 물고기·요리·작물은 표가 곧 그림 목록이다. 여기서 따라가면 표에 한 줄
	# 넣을 때마다 TEXTURE_NAMES도 고쳐야 하는 일이 없다 (빠뜨리면 아이콘이
	# 통째로 사라지는데, 어서션에 안 걸려 한참 뒤에야 눈에 띈다).
	for id: String in GameData.FISH_IDS:
		tex[id] = load("res://assets/sprites/%s.png" % id)
	for id: String in GameData.RECIPE_IDS:
		tex[id] = load("res://assets/sprites/%s.png" % id)
	for id: String in GameData.CROP_IDS:
		tex["mature_" + id] = load("res://assets/sprites/mature_%s.png" % id)
	for id: String in GameData.FORAGE_IDS:
		tex[id] = load("res://assets/sprites/%s.png" % id)
	# 휘두르기 도트는 **있으면 쓴다**. 남자는 ref/dot_boy/make_sprites.py가
	# 그려 뒀고 여자는 아직 없다 — 없는 쪽은 player.gd가 몸통을 굽혀 대신한다.
	# TEXTURE_NAMES에 넣으면 없을 때 터지므로 여기서만 따로 챙긴다. 그림을
	# sprites/에 떨어뜨리면 그날부터 켜진다.
	for g: String in ["new_boy", "player_f"]:
		for d: String in ["down", "up", "side"]:
			for i in 4:   # player.gd의 SWING_FRAMES와 같은 수
				var sn := "%s_%s_swing_%d" % [g, d, i]
				var sp := "res://assets/sprites/%s.png" % sn
				if ResourceLoader.exists(sp):
					tex[sn] = load(sp)


# 맵 밖 배경 색조 (어두운 숲처럼 보이게)
const OUT_TINT := Color(0.42, 0.47, 0.42)
const OUT_TREE_TINT := Color(0.34, 0.4, 0.35)


# 맵 끝에서도 주인공이 화면 가운데 오도록 카메라 제한을 맵 밖까지 넉넉히 둔다
# (바깥은 _draw가 어두운 숲 배경으로 채운다)
func _free_camera_limits(cam: Camera2D) -> void:
	const OUT := 40 * TILE
	cam.limit_left = -OUT
	cam.limit_top = -OUT
	cam.limit_right = MAP_W * TILE + OUT
	cam.limit_bottom = MAP_H * TILE + OUT


func _setup_camera() -> void:
	var cam: Camera2D = player.get_node("Camera")
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_free_camera_limits(cam)


# 빽빽한 숲에서는 앞쪽(아래) 나무가 주인공을 가린다.
# 가리는 나무만 잠깐 비치게 해서 자기 위치를 항상 볼 수 있게 한다.
var _faded_trees: Array = []


# 지금 시각에 이 NPC가 있어야 할 장소 이름 ("home"/"work"/"plaza"/"board"/"pier")


# 장소 이름 -> 실제 타일. 갈 수 없는 자리면 둘레에서 걸을 수 있는 칸을 찾는다.


# 건물 한 채: 5x4칸을 벽으로 채우고 그림을 세운다.
# 문 칸(아래 가운데)만 비워 둬서 걸어 들어가면 자동으로 안으로 들어간다.
func door_tile(anchor: Vector2i) -> Vector2i:
	return anchor + Vector2i(2, 3)


# 건물이 덮은 자리에는 길을 그리지 않는다 — 길은 걸어 다닐 수 있는 곳에만 있어야 한다
const BUILDING_KINDS := ["house", "art_block", "barn", "barn_block"]


# 이 칸이 다 지어진 건물의 문이면 그 건물 종류를 돌려준다


# 문으로 들어가면 열리는 것 (E로 눌렀을 때와 같다)


# 종류별 시각 배율. 텍스처가 2배 해상도(EPX)라서 실제 곱은 여기의 절반이 적용된다.
const OBJECT_SCALES := {
	# 주인공(약 3타일 키)에 맞춘 크기. 그림이 타일보다 크므로 배치 간격도 띄운다.
	"tree": 3.0, "rock": 1.9, "bigrock": 4.0, "cave": 2.2, "worldtree": 2.6,
	"barn": 1.0, "forage_berry": 1.5, "forage_herb": 1.5, "searock": 2.3,
	"forage_shell": 1.2, "forage_coral": 1.3,
	"forage_trash": 1.25, "forage_glass": 1.1, "stall": 2.6,
	"forage_ring": 1.1, "forage_relic": 1.2, "trash_bin": 2.4, "chief_hut": 2.0,
	"deco_fountain": 1.4, "deco_lamp": 1.15, "deco_bench": 1.15,
}
# 자연물 배치 간격(타일). 실제 그려지는 폭에서 뽑았다.
#
# 나무는 "옆으로 나란히" 있을 때만 그림이 지저분하게 겹친다.
# 앞뒤(위아래)로 겹치는 것은 y정렬로 앞 나무가 뒤 나무를 가려 주므로
# 오히려 깊은 숲처럼 보인다. 그래서 가로 간격만 넓게 잡고 세로는 촘촘히 둔다.
const TREE_DX := 4   # 가로로 4칸 이내이면서
const TREE_DY := 2   # 세로로 2칸 이내면 겹쳐 보인다 -> 금지
const NATURE_CLEAR := {
	"tree": 4, "bigrock": 3, "rock": 2, "forage_berry": 2, "forage_herb": 2,
}
const NATURE_CLEAR_MAX := 4
const OBJECT_TEX_DENSITY := 2.0  # 농장 오브젝트 텍스처 밀도 (월드 크기 유지용)

# 오브젝트가 실제로 막는 크기(픽셀). 기준 칸(32px) 밖으로 얼마나 더 넓히는지다.
# 그림이 타일보다 훨씬 크기 때문에, 칸 하나만 막으면 캐릭터가 나무 밑동/바위 속으로
# 파고들어 겹쳐 보인다. 그래서 그림 크기에 맞춰 밑동 판정을 넓힌다.
# 다만 한 칸짜리 통로는 계속 지나갈 수 있어야 하므로(플레이어 몸 폭 12px),
# 한 변에 6px(양쪽 12px, 남는 폭 20px)을 넘지 않게 잡는다.
#
# 세로 여백(pad.y)은 특히 조심해야 한다. 같은 줄로 늘어선 오브젝트 사이의
# 한 칸 틈은 계속 지나갈 수 있어야 하기 때문이다 (퀘스트 5의 바위벽처럼).
# 위아래 오브젝트의 여백이 32px 틈을 다 먹지 않도록 pad.y는 12 이하로 잡는다.
const OBJECT_PAD := {
	# 커다란 바위는 그림이 3칸 폭이라 여백도 그만큼 넓다 (안으로 걸어 들어가지 않게)
	# 나무·돌은 서로 4칸(TREE_DX)·2칸 넘게 떨어뜨려 놓으므로,
	# 여백을 넓혀도 한 칸짜리 통로가 막히지 않는다. 그림 밑동에 맞춰 넓혔다.
	# 세로 여백(pad.y)은 12를 넘기면 안 된다 — 같은 줄로 늘어선 것들 사이의
	# 한 칸 틈이 막힌다 (퀘스트 5의 바위벽. BIGROCK_GAP_OK가 잡아낸다)
	"tree": Vector2(13, 9), "bigrock": Vector2(26, 8), "rock": Vector2(13, 9),
	"searock": Vector2(10, 8),
	"cave": Vector2(16, 8), "worldtree": Vector2(16, 8), "barn": Vector2(4, 3),
	"forage_berry": Vector2(3, 2), "forage_herb": Vector2(3, 2),
	"deco_fountain": Vector2(5, 4), "deco_lamp": Vector2(3, 3), "deco_bench": Vector2(4, 3),
	"board": Vector2(3, 2), "sign": Vector2(3, 2),
}


# 나무 상태별 이미지 규칙 (고정 매핑):
# 어린 나무=tree_15 / 다 자란 나무=tree_01 / 1회 벌목=tree_06 / 2회 벌목=tree_09


func weather_now() -> int:
	if _weather_override >= 0:
		return _weather_override
	return GameData.weather_today()


func _hash01(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h) / 4294967295.0


# ---- 통행/타겟 ----

func is_passable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return false
	if grid[t.y][t.x].ground == "water":
		return false
	if objects.has(t):
		return false
	if not _tile_accessible(t):
		return false  # 해금하지 않은 부지는 들어갈 수 없다
	return true


func _tile_accessible(t: Vector2i) -> bool:
	return VILLAGE_REGION.has_point(t) or ROAD.has_point(t) \
		or GameData.is_tile_owned(t.x, t.y)


func is_passable_px(p: Vector2) -> bool:
	var t := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	if not is_passable(t):
		return false
	# 옆 칸 오브젝트라도 그림(밑동) 안쪽이면 들어갈 수 없다 — 캐릭터가 겹쳐 보이지 않게
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n := t + Vector2i(dx, dy)
			if not objects.has(n):
				continue
			var pad: Vector2 = OBJECT_PAD.get(objects[n].kind, Vector2.ZERO)
			if pad == Vector2.ZERO:
				continue
			var r := Rect2(n.x * TILE - pad.x, n.y * TILE - pad.y,
				TILE + pad.x * 2.0, TILE + pad.y * 2.0)
			if r.has_point(p):
				return false
	return true


func is_passable_px_loose(p: Vector2) -> bool:
	# 끼임 탈출용: 설치물/나무 충돌은 무시하되
	# 물·맵 밖·미구매 부지는 어떤 경우에도 통과할 수 없다
	var t := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return false
	if grid[t.y][t.x].ground == "water":
		return false
	return _tile_accessible(t)


func player_tile() -> Vector2i:
	return Vector2i(int(floor(player.position.x / TILE)), int(floor(player.position.y / TILE)))


# 마우스가 플레이어 주변 8칸 위에 있으면 그 칸이 타겟 (대각선 선택 가능)
var _mouse_target := Vector2i(-999, -999)
# 좌클릭으로 고정한 선택 대상 (E키/더블클릭 상호작용의 기준)
var _sel_target := Vector2i(-999, -999)


func ui_open() -> bool:
	return story_cutscene or shop.visible or summary.visible or sleep_dialog.visible \
		or fishing_ui.visible or dialog.visible or map_ui.visible \
		or inventory_ui.visible or interior.visible or cave.visible \
		or (shop_room != null and shop_room.visible) \
		or cooking_ui.visible or alchemy_ui.visible or quest_ui.visible or note_ui.visible \
		or stats_ui.visible or _name_layer != null or village._gift_layer != null \
		or (story.story_layer != null and story.story_layer.visible)


func interior_only_open() -> bool:
	# 집/동굴 안에 있을 때는 시간이 흐른다 (다른 창이 겹치면 정지)
	return (interior.visible or cave.visible
		or (shop_room != null and shop_room.visible)) and not (shop.visible
		or summary.visible or sleep_dialog.visible or dialog.visible
		or map_ui.visible or inventory_ui.visible)


# ---- 도구/상호작용 ----


# ---- 낚시 ----


# 낚시터 안내 지점 — 왼쪽 부두 끝 (길라잡이 화살표가 여기를 가리킨다)


# 축사 건설: 농장 고정 위치에 세워진다 (동물 16마리 + 굳은 날씨 자동 배부름)


# 전설 재료 획득 (판매 불가, 최후의 연금술 재료 — 연구 노트에 기록)


# 숙련도 경험치를 주고, 레벨업하면 하단에 알린다
var float_texts: Array = []  # 경험치 획득 플로팅 텍스트 [{text, pos, t}]


# 다 자란 작물은 도구 없이 바로 딴다 (바구니 같은 수확 도구는 없앴다)
# 지금 든 도구가 이 칸에서 할 일이 있는가 (있으면 수확보다 도구가 먼저)


# 채집·벌목·채광 대상이 되는 것들
const AIM_KINDS := ["tree", "rock", "bigrock", "forage_berry", "forage_herb", "weed",
	"forage_shell", "forage_coral", "forage_trash", "forage_glass",
	"forage_ring", "forage_relic"]

# E는 캐기와 말 걸기를 겸한다. 캐기 시작 후 이 시간 동안은 무조건 도구로 간다.
const WORK_LOCK_TIME := 0.9
var _work_lock := 0.0

const FACE_VECS := {
	"down": Vector2(0, 1), "up": Vector2(0, -1),
	"left": Vector2(-1, 0), "right": Vector2(1, 0),
}


# 앞으로 못 가게 막고 있는 오브젝트 칸을 찾는다.
# 그림이 큰 오브젝트는 옆 칸에 있어도 길을 막기 때문에, 앞 칸이 비어 있는데
# 걸음이 막히는 경우가 생긴다. 그때 실제로 막고 있는 것을 캘 수 있게 한다.
# 지금 든 도구로 캘 수 있는 것이 바로 옆(대각선 포함)에 있으면 그 칸.
#
# 오브젝트 그림이 타일보다 크다 보니 「바위 옆에 붙어 섰는데 정면은 빈 칸」인
# 상황이 자주 생긴다. 그때 E가 헛돌지 않도록, 도구에 맞는 대상이 옆에 있으면
# 그쪽을 잡아 준다 (가장 가까운 것 하나).


# 건물 이름표: 지붕 위에 작은 나무 간판을 걸어 어느 집인지 바로 알게 한다.
# (가게 그림이 모두 같아서 이름이 없으면 구분이 되지 않는다)


# 축제날 장식: 모이는 자리 위로 삼각 깃발 줄을 걸고 계절 색을 쓴다.
# (아트를 새로 그리지 않고 도형만으로 「오늘은 다른 날」임을 알린다)
const FEST_COLORS := {
	"flower": [Color(1, 0.72, 0.82), Color(1, 0.9, 0.55), Color(0.78, 0.9, 1)],
	"fishing": [Color(0.5, 0.82, 1), Color(1, 0.95, 0.6), Color(0.6, 1, 0.85)],
	"harvest": [Color(1, 0.68, 0.32), Color(0.95, 0.85, 0.4), Color(0.85, 0.45, 0.3)],
	"star": [Color(0.75, 0.85, 1), Color(1, 1, 0.95), Color(0.6, 0.7, 1)],
}


# 그 칸 쪽으로 몸을 돌린다 (우세한 축 기준, 대각선이면 좌우 우선)


# 설치 타일이 플레이어(원격 포함) 발밑과 겹치면 끼이므로 설치를 막는다


# ---- 오프닝 스토리 / 튜토리얼 ----

# ---- 메인 스토리 1 「우체부 아저씨와의 첫 만남」 ----
const STORY_SPAWN := Vector2i(18, 16)       # 화면 왼쪽에서 시작 (집은 화면 밖)
const STORY_LANE_Y := 16                   # 우체부가 왼쪽에서 걸어오는 길
const STORY_FORK := Vector2i(34, 16)       # 숲길이 갈라지는 갈림길 (지도 퀘스트)
const STORY_ROCK := Vector2i(40, 16)       # 마을 가는 길을 막는 커다란 바위 (퀘스트 5)
# 스토리 숲의 가로 폭. 화면(37.5칸)보다 넉넉히 넓어야 카메라가 주인공을 따라
# 옆으로 움직인다. 숲길(x 4~33) 동쪽은 들어갈 수 없는 배경 숲이다.
const STORY_FOREST_W := 58
# 숲길은 4줄 폭의 흙길. 양옆은 울타리로 막혀 있어 길을 벗어날 수 없다.
const STORY_ROAD_Y0 := 15
const STORY_ROAD_Y1 := 18                  # 15·16·17·18 = 4줄
const STORY_ROAD_X0 := 18
const STORY_ROAD_X1 := 47
# 메인 스토리 5: 숲 깊은 곳의 수상한 집 (이장에게 물어본 뒤 세상에 드러난다)
const FOREST_HOUSE_ANCHOR := Vector2i(30, 24)
const FOREST_TRAIL_X := 32                 # 숲길(y18)에서 집 문 앞으로 내려가는 오솔길
const EXPLORER_ARRIVE := Vector2i(78, 16)  # 모험가 무진이 처음 서성이는 광장 언저리
const STORY_LINK_X := 44                   # 마을 큰길로 오르는 4줄 연결로 (30~33)
# 길을 가로막고 선 나무 줄 (4줄 전체를 막는다) — 베어야만 지나갈 수 있다.
# 첫 번째는 퀘스트 1의 「더 이상 갈 수 없는 길」이자 퀘스트 3의 벌목 대상.
# 길을 막은 길목. 예전에는 네 곳 x 네 줄 = 나무 16그루라 초반이 지루했다.
# 지금은 두 곳이고, 길목마다 길이 두 줄로 좁아진다 → 나무 4그루.
const STORY_GATE_XS := [27, 38]
const STORY_GATE_ROWS := [16, 17]   # 막히는 줄 (나머지 줄은 울타리로 좁힌다)
const BIGROCK_HP := 4                      # 커다란 바위는 여러 번 캐야 부서진다
const BIGROCK_STONE := 4                   # 커다란 바위에서 나오는 돌
var story_cutscene := false                # 컷신 중 조작 잠금
var house_preview := false                 # 집터 자리 고르기 (동물의 숲식 범위 표시)
const POSTMAN_STOP_DIST := 168.0           # 걸어와서 멈춰 서는 거리 (5칸쯤 앞)
const POSTMAN_TALK_DIST := 60.0            # E로 말을 걸 수 있는 거리
const POSTMAN_REFOLLOW_DIST := 420.0       # 이만큼 멀어지면 다시 따라온다
const VILLAGE_EXIT_X := 74                 # 우체부가 빠져나가는 마을 북쪽 길


var _name_layer: CanvasLayer = null


var _cutscene_idle := 0.0
var _last_explore_tile := Vector2i(-999, -999)


# ---- 퀘스트 5 「마을로 가는 길을 열어보자」 (커다란 바위 / 곡괭이) ----


# ---- 밤 몬스터: 지네 (21시 이후 야외에서 등장, 아침에 사라진다) ----
# 밤늦게까지 밖에서 채집하는 것이 위험해지도록 만드는 요소.

var _shell_cd := 0.0        # 다음 조개가 밀려올 때까지 남은 게임 분
var night_mobs: Array = []  # [{node, spr, anim}]
var _mob_hit_cd := 0.0
var _mob_spawn_cd := 0.0


# ---- 집 건설 (스토리 1 완료 후 집터에서 직접 짓는다) ----


# ---- 마을 발전 (빈 부지에 건물을 하나씩 세운다) ----
# 처음 마을에는 건물이 하나도 없다. 이장에게 이야기하면 정해진 순서대로
# 재료를 모아 건물을 짓고, 그때마다 마을의 모습과 기능이 늘어난다.


# 지나갈 수 있는 칸만 밟는 최단 경로 (BFS). 반환값은 칸 중심의 월드 좌표 배열.
# 길이 아예 없으면 빈 배열을 돌려준다.


const STORY_PAGES := [
	["탐험가 할아버지", "나의 할아버지는 유명한 탐험가이자\n연금술 연구자였다.\n\n평생 신비한 생명체와 전설 속 재료를 찾아\n세계 곳곳을 누비셨다."],
	["비웃음", "사람들은 할아버지의 연구를\n'허황된 꿈'이라며 비웃었다.\n\n하지만 할아버지는 단 한 번도\n포기하지 않으셨다."],
	["이별", "수많은 연구 노트와 기록을 남기고도,\n할아버지는 끝내 마지막 연구를\n완성하지 못한 채 세상을 떠나셨다.\n\n무엇을 만들려 하셨는지는\n아무도 알지 못한다."],
	["나무 상자", "장례식이 끝난 뒤,\n부모님이 낡은 나무 상자를 건네주셨다.\n\n안에는 대부분 비어 있는 연구 노트 한 권과\n손으로 눌러쓴 편지 한 통."],
	["할아버지의 편지", "\"이 편지를 읽고 있다면, 나는 이미 떠났겠구나.\n내가 마지막까지 조사하던 곳은 '교진 마을'이다.\n그곳에 내가 평생 찾던 답이 있을지도 모른다.\n\n...내가 이루지 못한 꿈을,\n네가 이어주었으면 좋겠다.\""],
	["교진 마을로", "할아버지가 무엇을 찾고 계셨는지,\n나는 아직 아무것도 모른다.\n\n하지만 상자 속 빈 노트가\n왠지 나를 부르는 것 같았다.\n\n나는 짐을 싸서 교진 마을로 향했다."],
	["물려받은 농장", "마을 어귀, 할아버지가 머물던 작은 농장.\n오래 방치되어 잡초가 무성하고\n시설은 낡아 있었다.\n\n당분간은... 여기서 살아가 보자.\n농사도 짓고, 이웃도 사귀면서."],
]

# 진 엔딩: 전설 재료 7종을 모아 최후의 연금술로 '유니콘의 뿔'을 완성한다.
# (최종 목표는 게임 내에서 이 순간까지 절대 공개되지 않는다)
const ENDING_PAGES := [
	["마지막 연금술", "연구실 책상 위에 일곱 재료를 늘어놓았다.\n\n달빛 작물, 황금잉어, 세계수 가지,\n별빛 광석, 유령의 정수, 황금 달걀,\n그리고... 할아버지의 기억 조각."],
	["완성되는 노트", "재료를 노트의 마지막 장에 겹쳐 놓자,\n빈 페이지에 글씨가 스며들 듯 떠올랐다.\n\n할아버지가 평생 찾아 헤매던 것.\n그것은 자연 어디에도 없는 재료 —\n일곱 개의 정성이 모여야만 태어나는 것."],
	["유니콘의 뿔", "빛이 잦아들자, 책상 위에는\n나선형으로 빛나는 뿔 하나가 놓여 있었다.\n\n세상에 단 하나뿐인, 유니콘의 뿔.\n\n사람들이 비웃던 할아버지의 연구는\n허황된 꿈이 아니었다."],
	["이어진 꿈", "'내가 이루지 못한 꿈을\n네가 이어주었으면 좋겠다.'\n\n...할아버지, 보이시나요.\n농사를 짓고, 물고기를 잡고,\n사람들과 웃고 지내던 그 모든 날들이\n전부 할아버지의 연구였어요.\n\n그리고 오늘, 그 꿈이 완성됐어요."],
]


# ---- 할아버지의 부탁 ----
#
# 기본 안내가 끝나면 노트에서 할아버지의 부탁이 하나씩 떠오른다.
# 조건을 채우면 다음 부탁이 이어지고, 일곱을 다 들어주면
# 마지막 부탁(최후의 연금술)이 남는다.


# ---- NPC 대화 / 선물 / 퀘스트 ----


# ---- 온실 ----


# 온실 유리집을 밭 위에 겹쳐 그린다 (지붕 뼈대 + 유리 반사)


# 동굴 입구: 1층부터 갈지, 이미 내려가 본 승강기 층으로 갈지 고른다.
# (한 번도 안 내려가 봤으면 묻지 않고 바로 1층)


# ---- 여관 · 연구소 · 도서관 ----
#
# 거래 창이 없는 방들. 계산대 앞에서 E를 누르면 각자의 일을 한다.
const INN_REST_COST := 100
const INN_REST_HOURS := 3.0


# 도서관: 아직 못 구한 전설 재료 중 하나의 힌트를 짚어 준다


# ---- 계절 축제 ----
#
# 이장에게 「축제 이야기」를 하면 열린다. 참가 방식은 축제마다 다르다:
#   봄   주민 모두와 인사 (대화하면 저절로 센다)
#   여름 낚시터에서 물고기 5마리 (낚으면 저절로 센다)
#   가을 작물 하나 출품 / 겨울 요리 하나 나눠 주기 (여기서 고른다)


# 가진 것 중 가장 좋은 작물 (금 > 은 > 일반)


# 선물은 플레이어가 직접 고른다 — 가진 수확물/생산물 목록에서 선택


# 게시판: 아직 안 골랐으면 오늘 붙은 의뢰 셋 중 하나를 고르고,
# 고른 뒤에는 진행 상황/납품을 보여 준다.


# ---- 동물 ----


# ---- 하루 진행 ----


# 곤충: 계절/시간대에 맞는 곤충들이 들판을 날아다닌다
var bugs: Array = []


# ---- 저장 ----


# ---- 루프 ----

func _process(delta: float) -> void:
	_bgm_tick(delta)
	story._story_update(delta)
	story._fisher_update(delta)
	story._move_update(delta)
	story._forest_update(delta)
	story._spear_update(delta)
	story._movein_update(delta)
	if house_preview:
		overlay.queue_redraw()   # 집터 프리뷰가 마우스를 따라다닌다
	_work_lock = maxf(_work_lock - delta, 0.0)
	toolwork._update_hit_fx(delta)
	objnode._update_tree_fall(delta)
	objnode._update_object_fade(delta)
	if GameData.story_phase == "done":
		story._grandpa_update(delta)
	for ft in float_texts:
		ft.t += delta
	float_texts = float_texts.filter(func(ft: Dictionary) -> bool: return ft.t < 1.3)
	if not ui_open() or interior_only_open():
		if not Net.is_guest():
			# 시간은 호스트/솔로만 진행 (게스트는 동기화 수신)
			GameData.minutes += delta * MIN_PER_SEC
			if GameData.minutes >= GameData.DAY_END and not day_transitioning:
				daycycle._fade_next_day(true)
		water_timer += delta
		if water_timer > 0.8:
			water_timer = 0.0
			water_frame = 1 - water_frame
		_growth_timer += delta
		if _growth_timer >= 0.7:
			farming._growth_tick(_growth_timer * MIN_PER_SEC)
			_growth_timer = 0.0
		# 해변: 게임 시간 10~15분마다 조개가 하나씩 밀려온다 (상한에서 멈춘다)
		if GameData.sea_open and not Net.is_guest():
			toolwork._weapon_cd = maxf(0.0, toolwork._weapon_cd - delta)
			_shell_cd -= delta * MIN_PER_SEC
			if _shell_cd <= 0.0:
				_shell_cd = GameData.shell_respawn_minutes()
				worldgen._tick_beach()
		actions._update_mouse_target()
		fishing._update_fishing(delta)
		if player_tile() != _last_explore_tile:
			_last_explore_tile = player_tile()
			GameData.mark_explored_at(_last_explore_tile)
			# 문 앞에 서면 그대로 들어간다 (E를 누르지 않아도 된다)
			var dk: String = actions._door_kind_at(_last_explore_tile)
			if dk != "" and not ui_open() and not Net.is_guest():
				player.position = Vector2(_last_explore_tile.x * TILE + 16,
					(_last_explore_tile.y + 1) * TILE + 16)
				_last_explore_tile = player_tile()
				actions._enter_building(dk)
		if player.walked > 40.0:
			tutorial_notify("moved")
	weather_time += delta
	# 체력은 동굴 밖에서 천천히 회복된다 (요리를 먹으면 즉시 회복)
	if not cave.visible:
		GameData.energy = minf(GameData.ENERGY_MAX, GameData.energy + delta * 2.0)
	renderer._update_particles(delta)
	daycycle._update_night_mobs(delta)
	objnode._update_tree_fade()
	story._update_u_intro()
	netsync._net_process(delta)
	daycycle._update_night()
	hud.refresh()
	queue_redraw()
	overlay.queue_redraw()
	if _shot_path != "":
		harness._debug_tick()


# 젖은 밭 위 작물은 실시간으로 자라고, 물기는 서서히 마른다
# ---- 목초지 ----
#
# 울타리(또는 나무·바위 같은 막힌 것)로 **완전히 둘러싸인 빈 공간**을 목초지로 본다.
# 판정은 간단하다: 지도 가장자리에서 물을 흘려 보내고(flood fill), 그 물이 닿지
# 못한 칸이 곧 「갇힌 칸」이다. 울타리를 어떤 모양으로 쳐도 알아서 맞는다.
#
# 목초지 안의 동물은 밖으로 나가지 않고(울타리가 막는다), 아침마다 알아서
# 배부르며, 생산물이 가끔 하나 더 나온다. — 울타리를 칠 이유가 생긴다.
var pasture := {}                      # Vector2i -> true (갇힌 칸)
const PASTURE_MAX := 900               # 이보다 넓으면 「가둔 것」으로 치지 않는다
const PASTURE_BONUS := 0.35            # 생산물이 하나 더 나올 확률
const PASTURE_GOLDEN_EGG := 0.09       # 목초지 닭의 황금 달걀 확률 (평소 0.03)


# 스프링클러: 설치해 두면 둘레 네 칸을 **계속** 적신다.
# 예전에는 아침에 딱 한 번만 뿌렸다 — 그래서 방금 설치한 스프링클러도,
# 낮에 새로 간 밭도 다음 날이 되어야 물이 갔다.


# (자동 도구 선택은 제거됨 — 도구는 반드시 슬롯에 장착하고 숫자키/클릭으로
#  직접 선택해야 하며, 대상에 접근하는 것만으로는 아무 일도 일어나지 않는다)


func _unhandled_input(event: InputEvent) -> void:
	if Net.is_guest() and not _net_ready:
		return  # 접속 완료 전에는 조작 금지
	if _name_layer != null:
		return  # 이름 입력 중에는 다른 조작을 받지 않는다
	if story_cutscene and story._postman_state == "approach" and story._postman != null \
			and event.is_action_pressed("ui_cancel"):
		# 걸어오는 연출 스킵: 우체부가 바로 도착해 말을 건다
		story._postman.position = player.position + Vector2(-44, 0)
		story._postman_state = "talk"
		story._start_postman_dialog()
		get_viewport().set_input_as_handled()
		return
	if story.story_layer != null:
		# 스토리 연출 중 ESC = 스킵. 텍스트만 건너뛰고 후속 이벤트는 그대로 진행된다.
		if event.is_action_pressed("ui_cancel"):
			Sound.play_sfx("sfx_ui")
			if story._story_mode == "intro":
				# 마지막 선택 페이지(시작하기/튜토리얼 건너뛰기)로 점프
				story._story_idx = story._story_pages.size()
				story._show_story_page()
			else:
				story._close_story()  # 부지/엔딩: 정상 종료 루틴 (HUD 복구 등)
			get_viewport().set_input_as_handled()
		return
	if house_preview:
		# 집터 자리 고르기 — 좌클릭: 설치 / 우클릭·ESC: 취소
		if event.is_action_pressed("ui_cancel") \
				or (event is InputEventMouseButton and event.pressed
					and event.button_index == MOUSE_BUTTON_RIGHT):
			house_preview = false
			hud.show_message("집터 설치를 그만뒀다.")
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion:
			actions.mouse_screen = event.position
			return
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			actions.mouse_screen = event.position
			story.confirm_house_preview()
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if ui_open():
		if event.is_action_pressed("ui_cancel"):
			shop.close()
			summary.close()
			map_ui.close()
			inventory_ui.close()
			quest_ui.close()
			note_ui.close()
			stats_ui.close()
			# 오프닝 스토리 중(화면이 어두울 때)에는 ESC로 대화창을 닫지 않는다
			if fade_rect == null or fade_rect.color.a < 0.5:
				dialog.close()
		elif event.is_action_pressed("open_map") and map_ui.visible:
			map_ui.close()
		elif event.is_action_pressed("open_inventory") and inventory_ui.visible:
			inventory_ui.close()
		elif (event.is_action_pressed("open_inventory")
				or event.is_action_pressed("open_quest")
				or event.is_action_pressed("open_note")) \
				and (interior.visible or cave.visible
				or (shop_room != null and shop_room.visible)) and not (dialog.visible
				or shop.visible or cooking_ui.visible or alchemy_ui.visible or desk_ui.visible
				or quest_ui.visible or note_ui.visible or stats_ui.visible or map_ui.visible
				or sleep_dialog.visible or summary.visible or story_cutscene):
			# 집/동굴/가게 안에서도 가방·퀘스트·연구노트는 열려야 한다
			Sound.play_sfx("sfx_ui")
			if event.is_action_pressed("open_inventory"):
				inventory_ui.toggle()
			elif event.is_action_pressed("open_quest"):
				quest_ui.toggle()
			else:
				note_ui.toggle()
		elif event.is_action_pressed("open_quest") and quest_ui.visible:
			quest_ui.close()
		elif event.is_action_pressed("open_note") and note_ui.visible:
			note_ui.close()
		elif event.is_action_pressed("open_stats") and stats_ui.visible:
			stats_ui.close()
		return
	if event.is_action_pressed("open_map"):
		Sound.play_sfx("sfx_ui")
		map_ui.open()
		tutorial_notify("map")
		return
	if event.is_action_pressed("open_inventory"):
		Sound.play_sfx("sfx_ui")
		inventory_ui.toggle()
		return
	if event.is_action_pressed("open_quest"):
		Sound.play_sfx("sfx_ui")
		quest_ui.toggle()
		tutorial_notify("quest")
		return
	if event.is_action_pressed("open_note"):
		Sound.play_sfx("sfx_ui")
		note_ui.toggle()
		tutorial_notify("note")
		return
	if event.is_action_pressed("open_stats"):
		Sound.play_sfx("sfx_ui")
		stats_ui.toggle()
		return
	if event.is_action_pressed("ui_cancel"):
		# 게임 메뉴: 저장 후 타이틀로
		Sound.play_sfx("sfx_ui")
		dialog.open("게임 메뉴", "타이틀 화면으로 돌아갈까?\n(진행 상황은 자동 저장된다)", [
			["저장 후 타이틀로", _back_to_title],
			["계속하기", null],
		])
		return
	for slot_i in 9:
		if event.is_action_pressed("tool_%d" % (slot_i + 1)):
			if slot_i < GameData.tool_slots.size() and GameData.tool_slots[slot_i] != "":
				toolwork.set_tool(GameData.tool_slots[slot_i])
			return
	if event.is_action_pressed("cycle_seed"):
		GameData.cycle_seed()
		toolwork.set_tool("seed")
	elif event.is_action_pressed("use_tool"):
		toolwork.use_tool()
	elif event.is_action_pressed("mount"):
		riding.toggle_ride()
	elif event.is_action_pressed("interact"):
		actions.interact()
	elif event.is_action_pressed("save_game"):
		saveio.save_now()
		hud.show_message("저장했다!")
	elif event is InputEventMouseMotion:
		# 마우스 화면 좌표는 **움직일 때만** 적어 둔다.
		# get_global_mouse_position()은 매번 창 시스템에 물어보기 때문에 비싸다
		# (프레임당 0.13ms — 매 프레임 도는 것 중 제일 컸다).
		actions.mouse_screen = event.position
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		actions.mouse_screen = event.position
		actions._click_at(get_canvas_transform().affine_inverse() * event.position,
			event.double_click)


func _back_to_title() -> void:
	saveio.save_now()
	Sound.stop_bgm()
	Net.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# ---- 파티클 ----

# c=색 / n=개수 / up=처음 솟는 속도 / g=중력 / drift=좌우로 흩어지는 폭
# size=한 알 크기(px) / life=수명 배수 / sway=팔랑거리는 폭 (0이면 안 흔들린다)
# 뒤 넷은 없으면 기본값이다 (renderer.spawn_burst 참고).
const PARTICLE_DEFS := {
	"water": {"c": Color(0.45, 0.65, 1.0), "n": 8, "up": -18.0, "g": 40.0},
	"sparkle": {"c": Color(1.0, 0.85, 0.3), "n": 10, "up": -45.0, "g": 25.0},
	"wood": {"c": Color(0.55, 0.38, 0.2), "n": 7, "up": -35.0, "g": 70.0},
	"stone": {"c": Color(0.62, 0.62, 0.68), "n": 7, "up": -35.0, "g": 70.0},
	"seed": {"c": Color(0.4, 0.75, 0.35), "n": 6, "up": -28.0, "g": 50.0},
	"dirt": {"c": Color(0.52, 0.4, 0.26), "n": 6, "up": -25.0, "g": 60.0},
	# 나뭇잎: 도끼질마다 우듬지에서 떨어진다. 중력을 아주 낮게 주고 좌우로
	# 팔랑거리게 해서, 흙먼지가 아니라 **잎**으로 읽히게 했다.
	"leaf": {"c": Color(0.35, 0.6, 0.28), "n": 9, "up": -10.0, "g": 14.0,
		"drift": 22.0, "size": 2.0, "life": 2.6, "sway": 26.0},
	# 쓰러진 나무가 땅에 닿을 때 이는 흙먼지 (옆으로 낮게 퍼진다)
	"dust": {"c": Color(0.74, 0.68, 0.54), "n": 14, "up": -12.0, "g": 18.0,
		"drift": 34.0, "size": 2.0, "life": 1.6},
}


# ---- 캐기 모션 ----
#
# 판정은 예전 그대로 **즉시** 일어난다 (조작감을 건드리지 않는다).
# 눈에 보이는 것만 뒤로 미룬다: 휘두르는 동작이 내려찍히는 순간(HIT_AT)에
# 파편이 튀고, 그림이 손상 단계로 바뀌고, 나무가 쓰러지기 시작한다.
#
# 여기가 어긋나면 눈에 바로 띈다 — 예전에는 도끼가 아직 머리 위에 있는데
# 나무가 먼저 사라졌다. 지금은 그림 쪽 일을 전부 `_pending_hits`에 실어
# 보내서, 날이 나무에 박히는 그 프레임에 한꺼번에 터지게 했다.
const SWING_TIME := 0.34        # 휘두르는 동작 길이
const HIT_AT := 0.15            # 내려찍히는 순간 (동작 시작부터)
const SHAKE_TIME := 0.22        # 맞은 오브젝트가 흔들리는 시간
const HIT_SQUASH := 0.09        # 맞는 순간 그림이 눌리는 정도 (0.09 = 9%)

var _pending_hits: Array = []   # {t, tile, particle, heavy, after}
var _obj_shakes: Array = []     # {node, base, t, dir, spr, sc}
var _tree_falls: Array = []     # 쓰러지는 중인 나무 (object_nodes.gd가 굴린다)
var _cam_shake := 0.0
var _cam_shake_amp := 0.0


# 도구를 휘두른다 — 대상이 있든 없든 동작은 나간다


# 맞는 순간: 파편 + 대상 흔들림 + (큰 것이면) 화면 흔들림


# ---- 앞에 선 오브젝트 비쳐 보이기 ----
#
# 나무·커다란 바위는 그림이 여러 칸을 덮는다. 플레이어가 그 뒤에 서면
# 통째로 가려져 어디 있는지 안 보인다.
#
# 충돌 범위를 그림만큼 넓히면 그림 뒤에 설 수는 없지만, 숲과 바위밭을
# 지나갈 수 없게 된다 (한 칸짜리 통로가 다 막힌다). 그래서 범위는 그대로 두고,
# **가리는 동안만 반투명**하게 해서 플레이어가 언제나 보이게 한다.
const FADE_KINDS := ["tree", "bigrock", "cave", "worldtree", "barn",
	"deco_fountain", "deco_lamp", "house", "art_block"]
const FADE_ALPHA := 0.35
const FADE_SPEED := 6.0

var _fade_a := {}     # Vector2i -> 지금 알파


# 이 오브젝트 그림이 플레이어를 덮고 있는가 (그리고 앞에 그려지는가)


func _is_path(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
		return false
	return grid[y][x].ground == "path"


# ---- 렌더링 ----


func _draw() -> void:
	# 카메라에 보이는 타일만 그린다 (120x90 맵 컬링)
	var vis: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var vx0 := int(floor(vis.position.x / TILE)) - 1
	var vy0 := int(floor(vis.position.y / TILE)) - 1
	var vx1 := int(vis.end.x / TILE) + 2
	var vy1 := int(vis.end.y / TILE) + 2
	var x0 := maxi(0, vx0)
	var y0 := maxi(0, vy0)
	var x1 := mini(MAP_W, vx1)
	var y1 := mini(MAP_H, vy1)

	var grass_prefix := "grass_" + GameData.season_key() + "_"
	var tile_size := Vector2(TILE, TILE)

	# ---- 텍스처별로 모았다가 한 번에 그린다 ----
	#
	# 칸 순서대로 그리면 잔디->물->길->잔디로 텍스처가 계속 바뀌어 배치(batch)가
	# 매번 끊긴다. 그래서 보이는 칸 수만큼(800여 번) 드로우콜이 났다.
	# 같은 텍스처끼리 붙여 그리면 스무 번 안쪽으로 줄어든다.
	#
	# 겹치는 순서는 지켜야 한다: 바탕 -> 길 가장자리 -> 작물.
	# 바탕끼리는 한 칸에 하나뿐이라 서로 안 겹친다 — 순서를 바꿔도 안전하다.
	var base := {}      # Texture2D -> Array[Vector2]
	var edges := {}
	var crops := {}
	var docks: Array[Vector2] = []
	var sands: Array[Vector2] = []

	var put := func(bin: Dictionary, t: Texture2D, at: Vector2) -> void:
		if not bin.has(t):
			bin[t] = [] as Array[Vector2]
		bin[t].append(at)

	# 맵 바깥: 화면 가장자리가 비지 않도록 어두운 숲을 깔아 둔다.
	# (카메라 제한을 풀어 주인공을 항상 화면 가운데 두기 위한 배경)
	var out_grass := {}
	var out_trees: Array[Vector2] = []
	for y in range(vy0, vy1):
		for x in range(vx0, vx1):
			if x >= 0 and y >= 0 and x < MAP_W and y < MAP_H:
				continue
			put.call(out_grass, tex[grass_prefix + str(int(_hash01(x, y) * 3.0) % 3)],
				Vector2(x * TILE, y * TILE))
			# 드문드문 나무 실루엣을 세워 숲이 이어지는 것처럼 보이게 한다
			if x % 3 == 0 and y % 2 == 0 and _hash01(x * 5 + 1, y * 7 + 3) < 0.55:
				out_trees.append(Vector2(x * TILE, y * TILE))

	for y in range(y0, y1):
		var row: Array = grid[y]
		for x in range(x0, x1):
			var cell: Dictionary = row[x]
			var at := Vector2(x * TILE, y * TILE)
			var ground: String = cell.ground
			if ground == "dock":
				docks.append(at)
			elif ground == "sand":
				sands.append(at)
			elif ground == "water":
				put.call(base, tex["water_%d" % water_frame], at)
			elif ground == "soil":
				put.call(base, tex["soil_wet"] if cell.watered else tex["soil_dry"], at)
			elif ground == "path":
				put.call(base, tex["path"], at)
			else:
				put.call(base, tex[grass_prefix + str(int(_hash01(x, y) * 3.0) % 3)], at)
				# 흙길과 풀이 만나는 자리는 직선으로 끊기면 종이처럼 보인다.
				# 길 쪽에서 흙이 조금 흘러나온 것처럼 톱니 가장자리를 덧그린다.
				if _is_path(x, y - 1):
					put.call(edges, tex["path_edge_n"], at)
				if _is_path(x, y + 1):
					put.call(edges, tex["path_edge_s"], at)
				if _is_path(x - 1, y):
					put.call(edges, tex["path_edge_w"], at)
				if _is_path(x + 1, y):
					put.call(edges, tex["path_edge_e"], at)
			if cell.crop_id != "":
				put.call(crops, renderer._crop_texture(cell), at)

	# 맵 바깥 (어둡게)
	for t: Texture2D in out_grass:
		for at: Vector2 in out_grass[t]:
			draw_texture_rect(t, Rect2(at, tile_size), false, OUT_TINT)
	if not out_trees.is_empty():
		var ot: Texture2D = tex["tree_01"]
		var osc := 1.5
		var osize: Vector2 = ot.get_size() * osc
		for at: Vector2 in out_trees:
			draw_texture_rect(ot, Rect2(
				Vector2(at.x + 16 - osize.x / 2.0, at.y + TILE - osize.y), osize),
				false, OUT_TREE_TINT)
	# 바탕 -> 길 가장자리 -> 작물
	for t: Texture2D in base:
		for at: Vector2 in base[t]:
			draw_texture_rect(t, Rect2(at, tile_size), false)
	# 해변 모래밭 — 옅은 모래 바탕에 알갱이를 점점이 뿌린다
	if not sands.is_empty():
		for at: Vector2 in sands:
			draw_rect(Rect2(at, tile_size), Color(0.87, 0.79, 0.57))
		for at: Vector2 in sands:
			var gx := int(at.x / TILE)
			var gy := int(at.y / TILE)
			for i in 3:
				var hx := _hash01(gx * 7 + i * 13, gy * 11 + i * 5)
				var hy := _hash01(gx * 5 + i * 3, gy * 13 + i * 7)
				draw_rect(Rect2(at + Vector2(hx * 28.0 + 2.0, hy * 28.0 + 2.0),
					Vector2(2, 2)), Color(0.76, 0.66, 0.44, 0.85))
			# 바다와 닿는 줄에는 물거품 띠
			if gy + 1 < MAP_H and grid[gy + 1][gx].ground == "water":
				draw_rect(Rect2(at + Vector2(0, TILE - 3), Vector2(TILE, 3)),
					Color(0.95, 0.97, 0.98, 0.75))
	# 강 위 나무 부두 — 물 위에 판자를 깐 것처럼 보이게 한다
	if not docks.is_empty():
		var wt: Texture2D = tex["water_%d" % water_frame]
		for at: Vector2 in docks:
			draw_texture_rect(wt, Rect2(at, tile_size), false)
		for at: Vector2 in docks:
			draw_rect(Rect2(at + Vector2(0, 2), Vector2(TILE, TILE - 4)),
				Color(0.55, 0.38, 0.22))
			for i in 3:
				draw_rect(Rect2(at + Vector2(0, 2 + i * 9), Vector2(TILE, 1)),
					Color(0.38, 0.25, 0.14))
			draw_rect(Rect2(at + Vector2(0, 2), Vector2(TILE, 2)), Color(0.68, 0.5, 0.3))
	for t: Texture2D in edges:
		for at: Vector2 in edges[t]:
			draw_texture_rect(t, Rect2(at, tile_size), false)
	for t: Texture2D in crops:
		for at: Vector2 in crops[t]:
			draw_texture_rect(t, Rect2(at, tile_size), false)

	# 타겟 타일 하이라이트 (호버: 흰 실선 / 좌클릭 선택: 금색 강조)
	if player != null:
		var tt: Vector2i = actions.target_tile()
		if tt.x >= 0 and tt.y >= 0 and tt.x < MAP_W and tt.y < MAP_H:
			if tt == _sel_target:
				draw_rect(Rect2(Vector2(tt.x * TILE + 1, tt.y * TILE + 1),
					Vector2(TILE - 2, TILE - 2)), Color(1, 0.85, 0.3, 0.9), false, 2.0)
			else:
				draw_rect(Rect2(Vector2(tt.x * TILE, tt.y * TILE), Vector2(TILE, TILE)),
					Color(1, 1, 1, 0.6), false, 1.0)


# 건물/오브젝트 위에 그려야 하는 것들 (안내 텍스트·화살표·파티클·날씨)


# 머리 위 느낌표 (도트 그대로 — 굵은 막대 + 점)


# 타겟 타일/주변 상황에 맞는 안내 문구를 월드에 띄운다


# 현재 목표에 목적지가 있으면 플레이어 주위에 방향 화살표를 띄운다


# 지금 화면에 보이는 월드 범위 (화면 전체를 덮는 효과에 쓴다)


# ==== 멀티플레이 ====


# 위치 동기화 (15Hz, 비신뢰)


var _snapshot_retry := 0.0


# 도구 사용 결과 영역 동기화 (호스트 -> 전체)


# 게스트 행동 요청: 호스트가 같은 로직을 실행하고 결과를 전파한다
var _target_override := Vector2i(-999, -999)
var _perp_override := Vector2i.ZERO
var _forced_seed := ""
var _remote_acting := false


# 게스트가 상점 조작 후 호출 (호스트면 즉시 전파)


# 몬스터 처치 기록 (도감용)


# 아이템 획득 (동굴 보상/낚시 등) — 멀티에서는 호스트가 확정한다


# 요리/먹기 — 멀티에서는 호스트가 재고를 확정한다 (에너지는 각자)


# ---- 연금술 (집 안 조합대) ----
#
# 재료 3가지를 올리고 돌린다. 속성 합계가 어느 조합법의 조건을 넘으면
# 그 물약이 나오고 조합법을 알아낸다. 아니면 탁한 앙금만 남는다.
# 재료는 성공하든 실패하든 없어진다 — 실험에는 값이 따른다.
# 무엇이 나왔는지를 조합대 창이 그대로 띄울 수 있게 결과를 돌려준다.
# {ok, fid, name, effect, hint, first, ids}


# 물약 마시기: 즉효 + 그날 밤까지 가는 약효


# 나무·바위·몬스터에서 아주 가끔 나오는 「낡은 조합법」.
# 실험으로 직접 맞히는 길 말고, 돌아다니다 얻는 두 번째 길이다.


# 집 꾸미기 변경 동기화: 가구 배치 목록 + 돈 변화(구입/판매)를 호스트가 확정한다


# ---- 다른 창에서 부르는 스토리 창구 ----
# (연출 본체는 scripts/story.gd에 있다)
func tutorial_notify(flag: String) -> void:
	story.tutorial_notify(flag)


func show_ending() -> void:
	story.show_ending()


# 상점 안(shop_room.gd)에서 부르는 창구 — 본체는 scripts/village_ui.gd
func room_action(kind: String) -> void:
	village.room_action(kind)


# ---- 배경음 고르기 ----
#
# 계절 곡만 틀면 어디를 가나 같은 소리가 난다. 지금 어디에 있고 무슨
# 때인지를 보고 골라 준다. 0.4초에 한 번만 본다 — 매 프레임 볼 이유가 없고,
# 경계에서 곡이 왔다 갔다 하면 그게 더 거슬린다.
const VILLAGE_AREA := Rect2i(60, 6, 40, 36)   # 마을 전체 (큰길~강가)
var _bgm_t := 0.0


func _bgm_tick(delta: float) -> void:
	_bgm_t -= delta
	if _bgm_t > 0.0:
		return
	_bgm_t = 0.4
	Sound.play_track(_want_bgm())


func _want_bgm() -> String:
	if cave.visible:
		return "bgm_cave"
	# 집이나 가게에 들어가도 배경음은 그대로 흐른다 —
	# 곡이 바뀌는 별세계는 동굴뿐이다 (bgm_shop 전환은 없앴다)
	if GameData.festival_open():
		return "bgm_festival"
	var h := GameData.minutes / 60.0
	if h >= 19.0 or h < 5.0:
		return "bgm_night"
	# 낮의 바깥(밭·마을)은 올려 준 곡 하나로 간다 — 제일 오래 듣는 자리다
	return "bgm_main"
