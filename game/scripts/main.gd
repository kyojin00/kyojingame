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
#
# 넓히기만 하면 그냥 「빈 잔디밭이 늘어난 것」이라 걸어도 걸어도 같은 풍경이다.
# 그래서 **지역(REGIONS)** 으로 갈라 놓는다 — 과수원은 나무가 줄지어 서고,
# 채석장은 자갈 바닥에 바위가 널렸고, 습지는 물웅덩이가 흩어져 있다.
# 발을 들이는 순간 「다른 데 왔다」가 보여야 넓힌 값을 한다.
#
# 그리고 **세계를 네 배로 넓혔다** (224x132 -> 448x264, 넓이 4배).
# 넓힌 땅은 그냥 두면 걸어도 걸어도 같은 풀밭이라, 각 고장마다
# **한눈에 보이는 큰 것** 하나씩을 세웠다 (LANDMARKS) — 여기는 폭포가
# 어마어마하게 쏟아지고, 저기는 나무 한 그루가 산만 하다. 멀리서
# 그 하나가 보이면 「저기로 가 보자」가 된다. 그게 넓힌 값을 하는 길이다.
const MAP_W := 448   # 동쪽: 확장 구역 너머의 과수원 · 채석장 · 솔숲 · 새 고장들
# ---- 세계와 튜토리얼 공간 ----
#
# **튜토리얼은 실제 세계의 일부가 아니다.** 처음 눈을 뜨는 숲길은 세계
# 바깥(WORLD_H 아래)에 따로 붙여 둔 일회성 공간이고, 마을과는 한 칸도
# 이어져 있지 않다. 튜토리얼을 마치면 그 공간은 통째로 닫히고
# (GameData.tutorial_space = false), 다시는 발을 들일 수 없다.
# ---- 북쪽으로 넓힌 자리 ----
#
# 마을은 원래 지도 북쪽 끝(y=0)에 딱 붙어 있었다. 북쪽 가게 줄의 그림이
# y=1까지 올라가서, 마을 어디에도 구역 하나 더 낼 자리가 없었다.
#
# 그래서 **지도 위에 열두 줄을 얹고 세계 전체를 그만큼 내렸다.** 이 값을
# 세계의 모든 세로 좌표에 더한다 — 상수 정의에서 한 번씩만 더하면, 그
# 상수를 읽는 코드는 하나도 안 고쳐도 된다.
#
# 더하지 **않는** 것: BARN_ART 처럼 기준점에서 잰 상대 좌표, 그리고
# TUT_DY·MAP_H 처럼 다른 상수에서 파생되는 값 (이미 밀린 값을 쓴다).
const NORTH_PAD := 12
const WORLD_H := 252 + NORTH_PAD   # 실제 세계의 높이 (남쪽: 습지 · 초원 · 능선-해변-바다)
const TUT_Y0 := WORLD_H + 14       # 튜토리얼 숲길이 놓이는 줄 (세계 밖으로 한참 내려간 자리)
const TUT_DY := TUT_Y0 - 7          # 옛 숲길 좌표(y7~22)를 이 공간으로 옮기는 값
# 숲길 위아래로 열 줄씩 더 둔다 — 화면이 온통 숲으로 차야 「한 장의 공간」으로 보인다
const TUTORIAL_REGION := Rect2i(0, TUT_Y0 - 12, 62, 38)
const MAP_H := TUTORIAL_REGION.end.y   # 세계 + 튜토리얼 공간을 담는 격자 전체 높이
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
# 들판에 동시에 있는 채집물 수.
#
# 예전에는 12개였다 — 224x120칸짜리 세계에서 열두 개는 **없는 것과 같다.**
# 반나절을 걸어도 산딸기 한 포기 못 보는 게 정상이었다. 넉넉히 올렸다.
# **비가 오는 날은 그 두 배**다. 젖은 땅에서 풀과 열매가 쑥쑥 돋는 날이라,
# 비만 오면 나가서 줍고 싶어져야 한다.
const FORAGE_CAP := 90             # 여느 날
const FORAGE_CAP_FOG := 130        # 안개 낀 날 (발밑이 잘 보인다)
const FORAGE_CAP_RAIN := 190       # 비·폭풍 (젖은 땅에서 마구 돋는다)
# 비 오는 동안에는 아침만이 아니라 **하루 내내** 조금씩 더 돋는다
const RAIN_FORAGE_MINUTES := 25.0  # 게임 분 — 이 주기로 몇 포기씩
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
# 랜드마크 애니메이션 — 폭포는 흐르고, 큰나무는 흔들리고, 새는 날개를 친다.
# 물타일(0.8초)보다 훨씬 빨라야 「흐른다」로 보인다
var lm_frame := 0
var lm_timer := 0.0
const LANDMARK_FPS := 7.0
# 종류마다 장 수가 다르다 (ref/make_landmarks.js 와 같아야 한다)
const LANDMARK_FRAMES := {
	"landmark_greattree": 3, "landmark_falls": 4,
	# 물방앗간 곁의 물레방아 — 랜드마크는 아니지만 같은 규칙으로 돈다
	"deco_wheel": 4,
	# 돌무지 — 한 장뿐이다 (대장간 곁의 화덕으로도 쓴다). 표에 없으면
	# _tick_landmarks 가 없는 열쇠를 물어 터진다
	"deco_cairn": 1,
}
var water_timer := 0.0
# 물의 깊이 — 뭍에서 몇 걸음인지 미리 재 둔다 (0 = 뭍, 1 = 물가...).
# 그릴 때마다 이웃을 훑으면 물 한 칸마다 스물다섯 칸을 보게 된다.
# 물이 생기거나 없어지면 rebuild_water_levels()를 다시 부른다
var water_dist: Array = []
# 물 그림을 **평평한 배열**로 한 벌 더 들고 있는다 — [(깊이*3+판)*2 + 장].
# tex["water_%d_%d_%d"] 는 칸마다 글자를 짜맞추고 사전을 뒤진다
var _water_tex: Array = []

# ---- 그리기 캐시: 칸마다 「무엇을 그릴지」는 지도가 바뀔 때만 바뀐다 ----
#
# 그런데 프레임마다 다시 셈하고 있었다. 보이는 칸이 구백이면 구백 벌씩,
# 이웃 여덟 견주기 · _hash01 네댓 번 · **글자 짜맞추기와 사전 뒤지기**를.
# 지도는 밭을 갈 때 말고는 안 바뀐다. 한 번 셈해서 **텍스처 참조 그대로**
# 담아 두고, 걸음을 옮겨 새로 들어온 칸만 셈한다.
#
# 칸마다 달라지는 것(물의 장 · 흙의 젖음 · 작물)은 캐시에 안 담는다 —
# 담을 수 없어서가 아니라, 담으면 매번 버려야 해서 캐시가 아니게 된다.
const DC_NONE := 0    # 아직 안 셈했다
const DC_FIXED := 1   # 바탕이 고정 (_dc_base)
const DC_WATER := 2   # 물 — 깊이·판은 굳었고 장만 매번 (_dc_water)
const DC_SOIL := 3    # 밭 — 젖었는지는 매번
const DC_DOCK := 4    # 부두 — 물·널·널끝을 따로 그린다
var _dc_kind := PackedByteArray()
var _dc_base: Array = []            # 고정 바탕 Texture2D
var _dc_water := PackedInt32Array() # 깊이*3 + 판
var _dc_edge: Array = []            # 가장자리 Texture2D 묶음 (없으면 null)
var _dc_tall: Array = []            # 두 칸 높이로 그리는 것 (벼랑면)
# 켜(단) — 바탕을 그릴 때 이 값으로 톤을 조금 달리한다.
#
# 돌무지 언덕처럼 **다섯 단이 겹쳐 오르는** 자리에서, 바닥이 죄다 같은
# 마당 흙이라 단이 하나도 안 보였다. 마루선과 발치 그늘은 흙빛이라
# 흙 바닥 위에서는 있으나 마나였다 — 잔디 위에서만 통하던 것이다.
# 높은 단일수록 볕을 더 받는다: 한 단 오를 때마다 아주 조금 밝게.
var _dc_tier := PackedByteArray()
const TIER_TINT := [
	Color(1, 1, 1),
	Color(1, 1, 1),
	Color(1.055, 1.045, 1.025),
	Color(1.11, 1.09, 1.05),
	Color(1.165, 1.135, 1.075),
	Color(1.22, 1.18, 1.10),
	Color(1.275, 1.225, 1.125),
]
var _dc_season := ""                # 계절이 바뀌면 잔디 판 셋이 통째로 갈린다
# 경계 그림 — 종류 -> 꼴 값(0~255)로 찾는 256칸. 한 도트가 1픽셀이라
# 화면에 그릴 때 두 배로 늘어난다 (프로젝트 필터가 nearest)
const EDGE_KINDS := ["beach", "surf", "dune", "trod", "brink", "tread", "trail"]
# 판이 여럿인 것 — 한 판만 쓰면 **꼴이 같은 칸마다 같은 무늬**가 찍힌다.
# 못을 두르는 물가가 죄다 같은 그림이라 한 칸 간격으로 되풀이됐고, 그게
# 「쌓아 만든 축대」처럼 각져 보였다. 물가도 벼랑처럼 셋으로 나눈다
const EDGE_VAR_KINDS := ["cliff", "shore", "shoal"]
const EDGE_VARS := 3
const EDGE_PX := 16
var edge_tex := {}
# 땅의 높이 — 칸마다 켜(0~7, 비트 0~2)와 **오르막** 표시(비트 3).
#
# 벼랑은 따로 놓는 물건이 아니라 **높이가 다른 두 땅이 만나는 자리**다.
# 켜만 정해 두면 그림도(면과 마루) 통행도 거기서 나온다
var terrain_level: Array = []
var _growth_timer := 0.0
var tree_sprites: Array = []
# 돌려야 하는 랜드마크 그림들 — [스프라이트, 종류]. 세계에 넷뿐이라
# 매 프레임 뒤지지 않고 세울 때 한 번 적어 둔다 (_tick_landmarks)
var landmark_sprites: Array = []
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
var storage_ui: CanvasLayer   # 수납 상자 (집 안 상자 곁에서 E)
var quest_ui: CanvasLayer
var note_ui: CanvasLayer
var stats_ui: CanvasLayer
var ending: CanvasLayer
var auction_ui: CanvasLayer   # 경매장 (광장 경매 게시판 — 바깥 서버와 통신)
var settings_ui: CanvasLayer  # 설정 (ESC 메뉴 — 소리·화면·키)
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
	"egg", "golden_egg", "milk", "ore", "star_ore", "gem", "memory_piece",
	"ghost_essence", "gold_crop", "world_branch",
	# 물고기 · 요리 · 다 자란 작물은 _load_textures가 GameData의 표를 보고
	# 알아서 불러온다 (FISH_IDS · RECIPE_IDS · CROP_IDS).
	"crop_sprout", "crop_small", "crop_medium", "withered",
	"tree_spring", "tree_summer", "tree_fall", "tree_winter",
	"tree_bare", "tree_half", "tree_apple",
	"tree_01", "tree_06", "tree_09", "tree_13", "tree_15",
	# 고장마다 하나씩 선 「엄청 큰 것」 (ref/make_landmarks.js).
	# 여러 장씩이다 — 물이 흐르고 잎이 흔들린다 (LANDMARK_FRAMES)
	"landmark_greattree_0", "landmark_greattree_1", "landmark_greattree_2",
	"landmark_falls_0", "landmark_falls_1", "landmark_falls_2", "landmark_falls_3",
	# 층대 꼭대기의 돌무지 (ref/make_landmarks.js)
	"deco_cairn_0",
	"deco_wheel_0", "deco_wheel_1", "deco_wheel_2", "deco_wheel_3",
	# 돌계단을 따라 늘어선 석등 (ref/make_landmarks.js).
	# 마을 광장의 가로등(deco_lamp)과 이름이 겹치지 않게 한다
	"deco_stonelamp_0",
	# 고장의 작은 마을 집 (ref/make_buildings.js)
	"house_mill", "house_creek", "house_cabin", "house_shade",
	"rock", "house", "fence", "sprinkler", "board", "sign",
	"board_quest", "board_unlock", "bed_old", "bed_wood", "kitchen_counter",
	"icon_letter", "old_book",
	# 제작 재료·결과물 그림 — 제작대(책상) 창이 글자 대신 이 그림으로 말한다
	"nail", "cloth", "broom",
	# 밧줄 — 가게 마당에 내놓는 살림(PLOT_DECOR)에만 쓴다. 그림 파일은
	# 진작 있었는데 여기 이름이 빠져 있어서, 마당에 놓는 순간 tex["rope"]가
	# 사전에 없다며 매 프레임 오류가 났다
	"rope",
	# 민들레는 필드 그림(forage_dandelion, FORAGE_IDS로 자동 로드)과
	# 가방 아이콘 그림이 서로 다르다
	"icon_forage_dandelion",
	"npc_librarian_down_0", "npc_librarian_down_1", "npc_librarian_up_0",
	"npc_librarian_up_1", "npc_librarian_side_0", "npc_librarian_side_1",
	"npc_librarian_portrait_normal", "npc_librarian_portrait_happy",
	"npc_farmer_down_0", "npc_farmer_down_1", "npc_farmer_up_0",
	"npc_farmer_up_1", "npc_farmer_side_0", "npc_farmer_side_1",
	"npc_farmer_portrait_normal", "npc_farmer_portrait_happy",
	"npc_foodie_down_0", "npc_foodie_down_1", "npc_foodie_up_0",
	"npc_foodie_up_1", "npc_foodie_side_0", "npc_foodie_side_1",
	"npc_foodie_portrait_normal", "npc_foodie_portrait_happy",
	"npc_angler_down_0", "npc_angler_down_1", "npc_angler_up_0",
	"npc_angler_up_1", "npc_angler_side_0", "npc_angler_side_1",
	"npc_angler_portrait_normal", "npc_angler_portrait_happy",
	"npc_alchemist_down_0", "npc_alchemist_down_1", "npc_alchemist_up_0",
	"npc_alchemist_up_1", "npc_alchemist_side_0", "npc_alchemist_side_1",
	"npc_alchemist_portrait_normal", "npc_alchemist_portrait_happy",
	"npc_miner_down_0", "npc_miner_down_1", "npc_miner_up_0",
	"npc_miner_up_1", "npc_miner_side_0", "npc_miner_side_1",
	"npc_miner_portrait_normal", "npc_miner_portrait_happy",
	"npc_florist_down_0", "npc_florist_down_1", "npc_florist_up_0",
	"npc_florist_up_1", "npc_florist_side_0", "npc_florist_side_1",
	"npc_florist_portrait_normal", "npc_florist_portrait_happy",
	"npc_carpenter_down_0", "npc_carpenter_down_1", "npc_carpenter_up_0",
	"npc_carpenter_up_1", "npc_carpenter_side_0", "npc_carpenter_side_1",
	"npc_carpenter_portrait_normal", "npc_carpenter_portrait_happy",
	"npc_herbalist_down_0", "npc_herbalist_down_1", "npc_herbalist_up_0",
	"npc_herbalist_up_1", "npc_herbalist_side_0", "npc_herbalist_side_1",
	"npc_herbalist_portrait_normal", "npc_herbalist_portrait_happy",
	"npc_painter_down_0", "npc_painter_down_1", "npc_painter_up_0",
	"npc_painter_up_1", "npc_painter_side_0", "npc_painter_side_1",
	"npc_painter_portrait_normal", "npc_painter_portrait_happy",
	"npc_musician_down_0", "npc_musician_down_1", "npc_musician_up_0",
	"npc_musician_up_1", "npc_musician_side_0", "npc_musician_side_1",
	"npc_musician_portrait_normal", "npc_musician_portrait_happy",
	"npc_weaver_down_0", "npc_weaver_down_1", "npc_weaver_up_0",
	"npc_weaver_up_1", "npc_weaver_side_0", "npc_weaver_side_1",
	"npc_weaver_portrait_normal", "npc_weaver_portrait_happy",
	"stall", "bait", "flower_pot", "trash_bin", "chief_hut", "chief_house",
	# 마을 건물: 지붕색·덧문·차양·간판이 종류마다 다르다
	"house_post", "house_general", "house_smith", "house_lab", "house_inn",
	"house_library", "house_ranch", "house_fish",
	"deco_fountain", "deco_lamp", "deco_bench",
	"cave", "slime_0", "slime_1", "bat_0", "bat_1", "ghost_0", "ghost_1",
	"ore_node", "chest", "stairs",
	# 동굴 표본 (메인 스토리 10) · 낡은 상자 (메인 스토리 13)
	"crystal", "cave_moss", "glow_shroom", "old_box",
	# 온천 복구 (메인 스토리 15)
	"onsen", "rock_wedge", "spring_water",
	# 옛 전망대 (메인 스토리 18) — 굽은 나무는 tree_bare를 쓴다
	"old_lookout", "old_bench", "carved_stone",
	# 가장 오래된 자리 (메인 스토리 20)
	"grandpa_seed",
	# 수납 상자 (용식의 집터 부탁 보상)
	"storage_box",
	# 연금술 물약 (조합대 결과물)
	"water_life",
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
	# 메인 스토리 5: 모험가 재민 + 숲속의 모녀 (연화·솔이)
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
	"soil_dry", "soil_wet",
	# 물(water_<깊이>_<판>_<장>)과 경계 아틀라스(edge_*)는 이름이
	# 규칙적이라 _load_textures가 훑는다
	"path_edge_n", "path_edge_s", "path_edge_w", "path_edge_e",
	"dock_edge_n", "dock_edge_s", "dock_edge_w", "dock_edge_e",
]

const START_TILE := Vector2i(14, 10 + NORTH_PAD)
const CAVE_POS := Vector2i(50, 1 + NORTH_PAD)
# ---- 동굴은 아직 세상에 놓지 않는다 ----
#
# 들판 한가운데에 입구만 덩그러니 서 있었다 — 산도 벼랑도 없는 자리라
# 「동굴」이 아니라 「놓아 둔 문」으로 보인다. 자리를 정할 때까지 걷어 둔다.
#
# **다시 놓을 때는 두 줄이면 된다.** CAVE_POS 를 그 칸으로 바꾸고 이 값을
# true 로 되돌리면, 입구도 지도 이름표도 길잡이도 함께 돌아온다.
# 동굴 **안**(채광·층·광석)과 그걸 쓰는 이야기는 손대지 않았다.
const CAVE_PLACED := false
const WORLDTREE_POS := Vector2i(68, 50 + NORTH_PAD)  # 세계수 동굴 (깊은 숲)
# 축사(구입 시 농장에 건설). 이 칸이 축사 **문 칸**이고, 그림은 여기서
# 위로 5칸 반 · 좌우로 3칸씩 뻗는다 (7 x 5.5칸). BARN_ART 참고.
const BARN_POS := Vector2i(10, 6 + NORTH_PAD)
const BARN_ART := Rect2i(-3, -4, 7, 5)   # BARN_POS 기준 그림이 덮는 칸
const HORSE_HOME := Vector2i(10, 9 + NORTH_PAD)      # 산 말을 세워 두는 자리 (축사 앞마당)
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
const GREENHOUSE := Rect2i(4, 13 + NORTH_PAD, 9, 7)
const GREENHOUSE_SIGN := Vector2i(4, 20 + NORTH_PAD)
const GREENHOUSE_COST_WOOD := 150
const GREENHOUSE_COST_STONE := 80
const GREENHOUSE_COST_MONEY := 5000
# ---- 교진 마을 ----
# 마을에는 처음에 건물이 하나도 없다.
# 넓은 중앙 광장과 사방으로 뻗은 길, 그리고 나중에 건물이 들어설 빈 부지뿐이다.
# 건물은 진행에 따라 하나씩 세워지며, 그때마다 마을의 모습이 달라진다.
# 부지를 오므리면서 구역도 같이 줄였다 (46x44 -> 40x38). 이 사각형 안에는
# 나무·돌이 나지 않으므로, 줄인 만큼 **숲이 마을 코앞까지 다가온다** —
# 넓은 세계에 파묻힌 작은 마을이라는 그림이 여기서 나온다
const VILLAGE_REGION := Rect2i(78, -10 + NORTH_PAD, 109, 72)
# 인도는 모두 3줄. 길 폭을 한 곳에서 정하고 건물은 이 선에 맞춰 놓는다.
const ROAD_W := 3
const WEST_LANE_X := 67                    # 서쪽 세로 인도 (x 67~69)
const EAST_LANE_X := 86                    # 동쪽 세로 인도 (x 86~88)
const NS_LANE_X := 77                      # 광장을 지나는 남북 인도 (x 77~79)
const ROAD := Rect2i(30, 11 + NORTH_PAD, 52, 3)        # 농장/숲 -> 마을 공용 길 (3줄)
const MAIN_STREET_Y := 11 + NORTH_PAD                   # 마을 첫째 가로길과 이어진다
# ---- 마을 길 (모두 3줄) ----
#
# 「마을 바닥은 잔디」라는 약속은 **부지 안**의 이야기다. 부지와 부지 사이는
# 사람이 다니면서 풀이 죽은 길이 나 있어야 마을로 읽힌다 — 집들이 잔디밭에
# 그냥 얹혀 있으면 아직 모형이다.
#
# 세로 두 줄이 부지 세 칸 사이를, 가로 세 줄이 네 줄 사이를 지난다.
# 결과로 광장은 사방이 길로 둘러싸인다.
const VILLAGE_ROADS := [
	Rect2i(102, -10 + NORTH_PAD, 3, 72),     # 세로 — 첫째 칸과 둘째 칸 사이
	Rect2i(130, -10 + NORTH_PAD, 3, 72),     # 세로 — 둘째 칸과 셋째 칸 사이
	Rect2i(158, -10 + NORTH_PAD, 3, 72),     # 세로 — 셋째 칸과 넷째 칸 사이
	Rect2i(78, 11 + NORTH_PAD, 109, 3),      # 가로 — 첫째 줄 아래 (농장 큰길과 이어진다)
	Rect2i(78, 37 + NORTH_PAD, 109, 3),      # 가로 — 둘째 줄 아래
]
const PLAZA := Rect2i(138, 18 + NORTH_PAD, 17, 16)     # 중앙 광장 (격자의 한 칸을 통째로)
const FOUNTAIN := Rect2i(144, 24 + NORTH_PAD, 4, 4)    # 광장 중앙 분수
const FOUNTAIN_DECO := Vector2i(145, 26 + NORTH_PAD)   # 분수 조형물 (분수 한가운데)
# (마을을 가르던 남쪽 강과 동쪽 세로 강은 없앴다 — 맵은 하나로 이어진
#  큰 육지다. 물은 서쪽 호수·깊은 숲 연못·남쪽 바다만 남는다)
# ---- 낚시터 (마을 서쪽 호수, 맵에 하나뿐) ----
# 호숫가 잔디밭에서 물을 보고 낚싯대를 던진다. 「낚시」 목표는 여기.
const DOCK_Y := 36 + NORTH_PAD                         # 호수 남쪽 물가 (물은 y 27~35)
const FISH_YARD_X0 := 44
const FISH_YARD_X1 := 54
# 나무 부두 — 남쪽 물가에서 호수 한복판으로 걸어 나가는 판자길.
#
# 「부두」라는 말은 진작부터 있었다 (NPC 일과의 pier, 여름 낚시대회 장소).
# 그런데 정작 부두는 없었다 — dock 바닥이 세계의 어느 칸에도 안 깔려 있어서,
# 낚시꾼도 대회도 그냥 물가 잔디에 서 있었다. 실물을 놓는다.
#
# 목 두 칸 + 끝의 넓은 머리 — 머리가 있어야 여럿이 서고, 낚싯대를 드리울
# 자리가 생긴다. 곧은 막대 하나는 부두가 아니라 다리다.
const DOCK_STEM := Rect2i(48, 31 + NORTH_PAD, 2, 6)    # 물가(y36)에서 호수로 뻗는 목
const DOCK_HEAD := Rect2i(47, 29 + NORTH_PAD, 4, 2)    # 끝의 넓은 머리 (여기 서서 낚는다)
const DOCK_STAND := Vector2i(47, 29 + NORTH_PAD)       # 낚시꾼이 서 있는 자리 (머리 왼쪽)
const FISH_SIGN := Vector2i(43, 35 + NORTH_PAD)
# 남쪽 바다 (낚시꾼 퀘스트로 열린다) — 능선이 뭍과 해변을 가른다
# 북쪽 산자락 — 이 줄 위쪽의 풀밭에는 민들레가 돋는다 (산에서 캐는 채집물)
const MOUNTAIN_Y := 14 + NORTH_PAD
# 남쪽 바다는 **언제나 세계의 맨 밑에 붙어 있다.** 그래서 이 넷은 절대
# 좌표가 아니라 WORLD_H 에서 거꾸로 잰다 — 세계를 아래로 넓혀도 해안선이
# 세계 한복판에 떠 있는 일이 없다 (넓힐 때마다 네 줄을 다시 세지 않아도 된다).
const SEA_RIDGE_Y := WORLD_H - 13          # 바위 능선 줄 — 바다로 가는 길을 막는다
const BEACH_Y0 := WORLD_H - 12             # 모래사장 (능선 아래 ~ 바다 위)
const SEA_Y0 := WORLD_H - 7                # 여기부터 남쪽 끝까지 바다
const SEA_GATE := [Vector2i(63, WORLD_H - 13), Vector2i(64, WORLD_H - 13)]  # 곡괭이로 캐서 여는 길목
# 낚시꾼이 처음 서 있는 곳 — **호수 부두 끝.**
#
# 예전에는 광장 분수 앞이었다. 낚시꾼이 마을 한복판에 서 있는 것은
# 「낚싯대를 멘 낯선 사람」이라는 첫인상과 어긋난다 — 낚시꾼은 물가에 있다.
# 부두는 이 맵에 하나뿐인 낚시터이고, 그가 이 마을에 온 이유이기도 하다.
# 부두까지 걸어가는 그 길이 곧 「낚시터를 처음 보는 대목」이 된다.
const FISHER_ARRIVE := DOCK_STAND
const SHELL_CAP := 8               # 해변 채집물(조개/산호/쓰레기...) 최대 수
# 해변 모래밭에만 밀려오는 것들 — 조개·비닐봉지·유리 조각·금속 고리(기본),
# 산호 조각·고대 조각(매우 희귀 — 숨겨진 이야기·레시피와 이어진다)
const BEACH_FORAGE := ["forage_shell", "forage_coral", "forage_trash", "forage_glass",
	"forage_ring", "forage_relic"]
const STALL_TILE := Vector2i(72, BEACH_Y0 + 1)  # 만수의 해변 노점 (게이트 서남쪽 모래밭)
# 마을 온천 (메인 스토리 15) — 마을 북쪽 바위 밑. 수맥을 되살리면 물이 찬다
const ONSEN_POS := Vector2i(52, -7 + NORTH_PAD)
# 옛 농지 (메인 스토리 16) — 마을 서쪽, 오래 묵어 수풀이 우거진 밭.
# 단서를 다 모으면 잡초·돌·나무가 우거진 채로 드러난다
const OLD_FARM := Rect2i(20, 44 + NORTH_PAD, 10, 7)
# 옛 헛간 (메인 스토리 17) — 목장 남쪽에 방치된 헛간과 그 둘레
const OLD_BARN := Vector2i(14, 30 + NORTH_PAD)
const OLD_BARN_AREA := Rect2i(10, 27 + NORTH_PAD, 9, 7)
# 옛 전망대 (메인 스토리 18) — 마을 북서쪽 외곽, 길 위쪽 언덕.
# 무너져 가는 나무 전망대와 그 둘레의 흔적 세 곳
const HILL_POS := Vector2i(31, 3 + NORTH_PAD)
const HILL_AREA := Rect2i(26, 1 + NORTH_PAD, 11, 6)
const HILL_TRACE_TILES := {
	"bench": Vector2i(28, 4 + NORTH_PAD),
	"stone": Vector2i(34, 4 + NORTH_PAD),
	"tree": Vector2i(27, 1 + NORTH_PAD),
}
# 두 사람의 바위 (메인 스토리 13) — 해변 서쪽 끝, 두 분이 노을을 보던 자리.
# 단서를 다 모으면 표식이 놓이고, 그 곁 바다에서 특별한 입질이 온다
const BRACELET_ROCK := Vector2i(8, SEA_Y0 - 1)
const FISH_SPOT := Rect2i(42, 26 + NORTH_PAD, 14, 12)   # 이 안이면 「낚시터에 있다」
# 호수 둘레 + 마을에서 호수로 드는 어귀(x 53~60)는 나무/돌을 두지 않는다
const FISH_CLEAR := Rect2i(41, 24 + NORTH_PAD, 20, 14)
const BOARD_POS := Vector2i(140, 20 + NORTH_PAD)        # 광장 게시판 (오늘의 의뢰)
const AUCTION_POS := Vector2i(142, 20 + NORTH_PAD)      # 경매 게시판 (온 세상 농부들의 장터)
# (광장·낚시터의 가로등과 벤치는 없앴다 — 밤에는 마을도 캄캄하다)
# 메인 스토리 4 — 동쪽 다리 건너, 옛 마을의 경계를 알리는 낡은 표지판.
# 너머(GameData.VILLAGE_ZONES)는 구역을 해금해야 들어갈 수 있다.
const OLD_SIGN := Vector2i(190, 9 + NORTH_PAD)

# ---- 야생 지역 ----
#
# 마을과 농장 바깥은 그냥 넓은 잔디밭이 아니라 **결이 다른 땅**이 이어진다.
# 여기 한 줄이 그 땅의 성격을 통째로 정한다 — 세계를 넓힐 때는 이 표에
# 한 줄을 더하면 되고, 지도(M)에도 이름이 저절로 뜬다.
#
#   rect    차지하는 칸
#   tree    그 칸에 나무가 설 확률 (0이면 나무가 없는 땅)
#   rock    나무가 안 선 자리에 바위가 놓일 확률
#   ground  바닥 ("" = 잔디 그대로 · "path" = 자갈 · "sand" = 모래)
#   grid    0보다 크면 **줄지어** 심는다 (과수원처럼 사람 손이 간 땅)
#   pond    0보다 크면 그만큼의 확률로 물웅덩이가 생긴다 (습지)
#
# 지역끼리는 일부러 사이를 벌려 둔다. 맞붙여 놓으면 경계가 자로 그은 듯해서
# 「지도를 칸으로 나눠 놨구나」가 먼저 보인다.
const REGIONS := [
	# ---- 원래 있던 땅 (마을 · 농장 둘레) ----
	# 예전부터 있던 남동쪽 깊은 숲 — 넓어진 만큼 남쪽으로 늘렸다
	{"id": "deep", "name": "깊은 숲", "rect": Rect2i(44, 40 + NORTH_PAD, 52, 24),
		"tree": 0.30, "rock": 0.10, "ground": "", "grid": 0, "pond": 0.0},
	# 옛 표지판 너머 첫 땅. 줄 맞춰 심긴 사과나무 — 사람 손이 닿았던 자리다
	{"id": "orchard", "name": "동쪽 과수원", "rect": Rect2i(172, 8 + NORTH_PAD, 48, 26),
		"tree": 0.9, "rock": 0.0, "ground": "", "grid": 4, "pond": 0.0},
	# 자갈이 깔린 채석장. 나무는 거의 없고 바위가 지천이다
	{"id": "quarry", "name": "동쪽 채석장", "rect": Rect2i(172, 40 + NORTH_PAD, 48, 26),
		"tree": 0.02, "rock": 0.34, "ground": "path", "grid": 0, "pond": 0.0},
	# 탁 트인 초원 — 아무것도 없다. 넓은 하늘과 풀뿐
	{"id": "meadow", "name": "너른 초원", "rect": Rect2i(102, 46 + NORTH_PAD, 44, 26),
		"tree": 0.02, "rock": 0.01, "ground": "", "grid": 0, "pond": 0.0},
	# 남쪽 습지 — 발밑이 질척하고 물웅덩이가 흩어져 있다
	{"id": "wetland", "name": "남쪽 습지", "rect": Rect2i(16, 64 + NORTH_PAD, 54, 30),
		"tree": 0.07, "rock": 0.02, "ground": "", "grid": 0, "pond": 0.12},
	# 동남쪽 솔숲 — 깊은 숲보다 더 깊다. 여기까지 오면 꽤 멀리 온 것이다.
	# 나무는 NATURE_CLEAR(가로 4칸)에 걸려 아무리 올려도 6%쯤에서 포화된다 —
	# 그래서 「더 깊다」는 바위로 낸다 (바위는 두 칸 간격이라 훨씬 촘촘하다)
	{"id": "pinewood", "name": "솔숲 골짜기", "rect": Rect2i(160, 70 + NORTH_PAD, 62, 24),
		"tree": 0.34, "rock": 0.26, "ground": "", "grid": 0, "pond": 0.0},

	# ---- 네 배로 넓히며 붙인 땅 ----
	#
	# 여기부터는 **고장마다 테마가 있다.** 폭포골에는 어마어마한 폭포가
	# 쏟아지고, 큰나무 숲에는 산만 한 나무 한 그루가 서 있다 (LANDMARKS).
	# 나무·바위 밀도만 흔들면 「좀 다르네」에서 끝난다 — 고장마다 **한눈에
	# 보이는 큰 것** 하나가 있어야 걸어갈 이유가 된다.

	# 폭포골 — 물소리가 나는 골짜기. 젖은 땅이라 웅덩이가 흩어져 있다
	{"id": "falls", "name": "폭포골", "rect": Rect2i(238, 6 + NORTH_PAD, 66, 52),
		"tree": 0.24, "rock": 0.14, "ground": "", "grid": 0, "pond": 0.05},
	# 자작나무 언덕 — 훤한 숲. 나무는 많은데 바닥이 밝아 어둡지 않다
	{"id": "birch", "name": "자작나무 언덕", "rect": Rect2i(316, 4 + NORTH_PAD, 60, 46),
		"tree": 0.52, "rock": 0.01, "ground": "", "grid": 0, "pond": 0.0},
	# 붉은바위 벌판 — 마른 흙땅. 돌무지 언덕이 여기 있다.
	#
	# 바닥이 **자갈(path)** 이었다. 그런데 자갈 타일도 벼랑면도 같은 돌
	# 사다리(STONE)로 칠한다 — 회색 위에 회색이라 층대의 단이 통째로
	# 배경에 묻혔다. 「배경이 같아서 구분이 잘 안 된다」가 이것이다.
	# 마른 흙(yard)으로 바꾼다: 갈색 바닥 위에 회색 바위벽이라야 단이 선다
	{"id": "redrock", "name": "붉은바위 벌판", "rect": Rect2i(384, 10 + NORTH_PAD, 58, 54),
		"tree": 0.02, "rock": 0.30, "ground": "yard", "grid": 0, "pond": 0.0},
	# 억새 벌판 — 아무것도 없다. 바람만 지나간다 (너른 초원보다 더 비었다)
	{"id": "reed", "name": "억새 벌판", "rect": Rect2i(236, 72 + NORTH_PAD, 74, 40),
		"tree": 0.01, "rock": 0.01, "ground": "", "grid": 0, "pond": 0.0},
	# 별빛 호수 — 한복판에 큰 호수가 있다 (LANDMARKS의 lake)
	{"id": "starlake", "name": "별빛 호수", "rect": Rect2i(322, 74 + NORTH_PAD, 84, 60),
		"tree": 0.10, "rock": 0.04, "ground": "", "grid": 0, "pond": 0.03},
	# 가시덤불 골 — 마을 남쪽으로 내려가는 길목. 걷기 사나운 잡목 지대
	{"id": "bramble", "name": "가시덤불 골", "rect": Rect2i(96, 80 + NORTH_PAD, 60, 32),
		"tree": 0.20, "rock": 0.22, "ground": "", "grid": 0, "pond": 0.0},
	# 버들 늪가 — 남쪽 습지에서 꽃벌판으로 넘어가는 좁은 띠
	{"id": "willow", "name": "버들 늪가", "rect": Rect2i(14, 94 + NORTH_PAD, 62, 14),
		"tree": 0.16, "rock": 0.01, "ground": "", "grid": 0, "pond": 0.09},
	# 잿빛 벌판 — 아무 색도 없는 땅. 큰나무 숲과 돌무지 사이의 빈 자리
	{"id": "ashen", "name": "잿빛 벌판", "rect": Rect2i(172, 128 + NORTH_PAD, 54, 48),
		"tree": 0.08, "rock": 0.12, "ground": "path", "grid": 0, "pond": 0.0},
	# 동쪽 끝 벼랑 — 세계의 동쪽 끝. 여기서 더는 갈 데가 없다
	{"id": "eastedge", "name": "동쪽 끝 벼랑", "rect": Rect2i(408, 76 + NORTH_PAD, 38, 60),
		"tree": 0.06, "rock": 0.28, "ground": "", "grid": 0, "pond": 0.0},
	# 꽃벌판 — 줄 맞춰 선 나무 사이로 훤한 들. 남쪽에서 제일 밝은 땅
	{"id": "flower", "name": "꽃벌판", "rect": Rect2i(14, 110 + NORTH_PAD, 66, 48),
		"tree": 0.7, "rock": 0.0, "ground": "", "grid": 5, "pond": 0.0},
	# 큰나무 숲 — 산만 한 나무 한 그루를 둘러싼 숲
	{"id": "greatwood", "name": "큰나무 숲", "rect": Rect2i(90, 116 + NORTH_PAD, 78, 60),
		"tree": 0.36, "rock": 0.06, "ground": "", "grid": 0, "pond": 0.0},
	# 돌무지 언덕 — 굴러떨어진 바위가 쌓인 비탈
	{"id": "boulder", "name": "돌무지 언덕", "rect": Rect2i(230, 128 + NORTH_PAD, 70, 48),
		"tree": 0.05, "rock": 0.34, "ground": "path", "grid": 0, "pond": 0.0},
	# 먼 솔숲 — 세계에서 제일 깊은 숲. 여기까지 오면 정말 멀리 온 것이다
	{"id": "farpine", "name": "먼 솔숲", "rect": Rect2i(330, 148 + NORTH_PAD, 96, 66),
		"tree": 0.38, "rock": 0.30, "ground": "", "grid": 0, "pond": 0.0},
	# 안개 늪 — 남쪽 습지보다 더 질척하다. 물웅덩이가 발에 채인다
	{"id": "mist", "name": "안개 늪", "rect": Rect2i(14, 170 + NORTH_PAD, 68, 46),
		"tree": 0.06, "rock": 0.01, "ground": "", "grid": 0, "pond": 0.18},
	# 남녘 들 — 바다로 내려가기 전 마지막 너른 땅
	{"id": "southfield", "name": "남녘 들", "rect": Rect2i(96, 178 + NORTH_PAD, 110, 40),
		"tree": 0.03, "rock": 0.02, "ground": "", "grid": 0, "pond": 0.0},
	# 모래벌판 — 바다가 가까워 바닥이 모래로 바뀐다
	{"id": "dune", "name": "모래벌판", "rect": Rect2i(240, 188 + NORTH_PAD, 86, 34),
		"tree": 0.02, "rock": 0.06, "ground": "sand", "grid": 0, "pond": 0.0},

	# 능선 위 벼랑길 — 바다로 내려가기 전 마지막 땅. 돌투성이다.
	# **바다는 늘 세계의 맨 밑**이므로 이 띠도 능선에서 거꾸로 잰다
	{"id": "bluff", "name": "바닷가 벼랑길", "rect": Rect2i(20, SEA_RIDGE_Y - 11, 400, 10),
		"tree": 0.04, "rock": 0.16, "ground": "", "grid": 0, "pond": 0.0},
]

# ---- 고장의 랜드마크 ----
#
# 고장마다 **한눈에 보이는 큰 것** 하나. 화면 열두 칸이 넘는 그림이라
# 멀리서도 화면 가장자리에 걸친다 — 그게 「저기 가 보자」가 된다.
#
#   kind   오브젝트 종류 ("" 면 그림 없이 지형만 — 호수처럼)
#   tile   그림이 서는 칸 (밑변 한가운데)
#   block  걸어 들어갈 수 없는 밑동 (tile 기준 상대 좌표)
#   clear  이 반지름 안에는 나무·돌을 두지 않는다 (그림이 가려지면 안 된다)
#   lakes  물을 판다 [[중심x, 중심y, 가로반지름, 세로반지름], ...]
#          폭포는 **둘**이다 — 벼랑 위의 못과 벼랑 밑의 못. 위에 물이
#          없으면 물이 벼랑에서 솟는 꼴이고, 밑에 없으면 땅에 스민다
#   spill  물을 **반드시** 채울 칸 [Rect2i, ...]
#          못은 가장자리를 흔들어 파므로(자로 잰 타원은 못이 아니다),
#          마루 바로 위처럼 **한 칸도 비면 안 되는 자리**는 따로 못박는다.
#          여기가 비면 폭포가 벼랑에서 뚝 떨어져 나온 것처럼 보인다
#   river  있으면 그 물에서 개울이 흘러나간다 [x0, y0, x1, y1, 폭]
#          — 못만 있으면 물이 고인 웅덩이다. 흘러 나가야 폭포가 산다
#   terrain 단차. {"blobs": [[중심x, 중심y, 가로, 세로, 켜, 씨앗], ...],
#           "ramps": [[x, 근처y], ...]}
#
# **단차가 이 표의 핵심이다.** 그림만 세우면 아무리 잘 그려도 평지에
# 붙인 판때기다 — 폭포는 벼랑에서 떨어져야 폭포고, 바위 기둥은 대지
# 위에 서야 높다. 세계의 켜 시스템(terrain_level)으로 진짜 높이를 주고,
# 그림은 그 벼랑의 **한 자리**를 맡는다. 그러면 그림 좌우로 벼랑이
# 이어져 나가 세계와 한 몸이 된다.
#
# 올린 땅에는 반드시 오르막(ramps)을 낸다. 안 그러면 올라갈 수 없는
# 섬이 되고, 큰 것을 세워 놓고 가까이 못 가는 꼴이 된다.
const LANDMARKS := [
	# 큰나무 — 산만 한 나무 한 그루. 세계에서 제일 큰 그림(화면 12.5 x 16.5칸)
	{"id": "greattree", "name": "큰나무", "kind": "landmark_greattree", "art": Vector2i(13, 17),
		"tile": Vector2i(128, 148 + NORTH_PAD),
		"block": Rect2i(-4, -1, 8, 2), "clear": 12, "lakes": [], "river": [],
		# 큰나무는 야트막한 둔덕 위에 선다 — 숲 어디서나 우듬지가 보이게
		"terrain": {"blobs": [[128, 152 + NORTH_PAD, 15.0, 8.0, 2, 63]],
			"ramps": [[126, 165 + NORTH_PAD]]}},
	# 큰폭포 — 절벽에서 두 단으로 쏟아진다. 밑에 못이 파여 있다
	{"id": "falls", "name": "큰폭포", "kind": "landmark_falls", "art": Vector2i(6, 6),
		# 그림은 **윗못에서 밑못까지**만 맡는다 (화면 6칸 x 6칸).
		# 좌우로는 세계의 벼랑 타일이, 위아래로는 세계의 물 타일이 이어진다.
		#
		# **자리는 벼랑 줄에 맞춘다.** 밑변이 기준이고 높이가 6칸, 마루는
		# 그 위에서 1.75칸이다 (그보다 위 한 칸 반은 윗못을 덮는 부분).
		# x261 의 벼랑 줄이 y32 이므로 밑변은 y35 — 한 칸만 어긋나도 물이
		# 벼랑 위에서 시작하거나 벼랑 밑 허공에서 시작한다
		"tile": Vector2i(261, 23 + NORTH_PAD),
		# 물기둥이 지나는 칸을 막는다 — 안 막으면 폭포 속으로 걸어 들어가진다
		"block": Rect2i(-3, -5, 6, 6), "clear": 9,
		# 벼랑 **위**의 못(켜 2)과 **밑**의 못(켜 1). 위 못은 마루까지 닿아
		# 있어서 거기서 물이 넘어간다
		# 밑못은 **벼랑에서 두 줄 떨어뜨린다.** 붙여 놓았더니 못의 흔들린
		# 위 가장자리가 벼랑을 타고 올라와 윗못과 이어져 버렸다 — 물이
		# 통째로 하나가 되니 떨어지는 자리가 없어져, 폭포가 호수 한복판에
		# 떠 있는 꼴이었다. 벼랑과 밑못 사이에 **마른 바위 두 줄**이 있어야
		# 거기가 「떨어지는 자리」가 된다 (그 두 줄은 그림이 덮는다)
		"lakes": [[259, 12 + NORTH_PAD, 8.0, 6.0],
			[261, 28 + NORTH_PAD, 9.0, 5.0]],
		# 마루(y31.75) 위 네 줄과 밑동(y35.1) 밑 네 줄 — 여기는 흔들림 없이
		# 물이다. 못만 파 두었더니 가장자리 흔들림 때문에 한두 줄이 잔디로
		# 남아, 물이 벼랑에서 **뚝 떨어져 나온** 것처럼 끊겨 보였다
		"spill": [Rect2i(255, 16 + NORTH_PAD, 13, 4),
			Rect2i(255, 23 + NORTH_PAD, 13, 4)],
		"river": [259, 31 + NORTH_PAD, 246, 74 + NORTH_PAD, 2.0],
		# 폭포는 **진짜 벼랑**에서 떨어진다. 그림 왼쪽·오른쪽으로 그 벼랑이
		# 이어져 나가고, 서쪽 끝에 오르막이 있어 폭포 위로 올라갈 수 있다
		# 벼랑을 **왼쪽 위로** 옮겼다. 폭포를 왼쪽으로 옮기려면 그 자리의
		# 벼랑 줄도 같이 와야 한다 — 벼랑은 가운데가 높고 옆으로 갈수록
		# 내려가므로, 그림만 옆으로 밀면 마루가 벼랑 밑으로 처진다
		"terrain": {"blobs": [[256, 9 + NORTH_PAD, 16.0, 11.0, 2, 91]],
			"ramps": [[244, 20 + NORTH_PAD]], "width": 4}},
	# 돌무지 언덕 — 층층이 올라가는 대지. **꼭대기까지 걸어 오른다**
	#
	# 예전에는 여기 커다란 바위 기둥이 서 있었다. 그건 「멀리서 보는 것」
	# 이지 「올라가서 보는 것」이 아니었다 — 다 올라가 봐야 바위 밑동이다.
	# 대신 사람들이 하나씩 얹고 간 돌무지를 꼭대기에 둔다. 손이 닿은
	# 흔적이라, 올라온 사람이 「나도 하나 얹고 갈까」 하게 되는 물건이다.
	{"id": "spire", "name": "돌무지 언덕", "kind": "deco_cairn", "art": Vector2i(3, 4),
		"tile": Vector2i(410, 35 + NORTH_PAD),
		"block": Rect2i(-1, 0, 3, 1), "clear": 8, "lakes": [], "river": [],
		# ---- 네 켜짜리 층대(層臺) ----
		#
		# 예전에는 두 켜였고, 올라가 봐야 바위 밑동이었다. 「올라갈 수
		# 있다」와 「올라가고 싶다」는 다르다 — 오르는 동안 **층계참이
		# 몇 번 나오고**, 그 끝에 볼 것이 있어야 한다.
		#
		# 켜 1 -> 2 -> 3 -> 4 -> 5. 대지는 남쪽으로만 깎여 있어(북쪽 자락은
		# 다 붙어 있다) 층계참이 앞쪽에 층층이 드러나고, 오르막은 켜마다
		# 좌우를 번갈아 둔다 — 지그재그로 접혀 올라가는 그 계단이다.
		# 꼭대기 켜(5)에 돌무지가 있다
		# 켜마다 **북쪽 자락이 4~5칸씩 벌어지게** 잡는다. 예전에는
		# 북쪽 끝이 35·36·36.5·37 — 네 단이 두 칸 안에 포개져 있었다.
		# 뒤에서 보면 마루선 넷이 한 줄로 겹쳐, 아무리 톤을 달리해도
		# 층이 안 세어졌다. 가운데를 거의 같은 자리에 두고 반지름만
		# 줄이면 앞뒤가 고르게 벌어진다 (덤으로 언덕이 커진다)
		"terrain": {"blobs": [[410, 39 + NORTH_PAD, 36.0, 21.0, 2, 77],
				[410, 38 + NORTH_PAD, 26.0, 15.0, 3, 78],
				[410, 37 + NORTH_PAD, 17.0, 9.0, 4, 79],
				[410, 36 + NORTH_PAD, 9.0, 4.0, 5, 80]],
			# 오르막 = 돌계단. 서 -> 동 -> 서 -> 동으로 접힌다
			# 맨 위 계단은 **바위 밑동을 피해서** 낸다. 그림이 차지하는 칸
			# (block: 좌우 세 칸)은 못 밟는 자리라, 거기로 계단을 내면
			# 다 올라와서 벽에 부딪힌다 — 켜만 보는 검사로는 안 잡힌다
			"ramps": [[392, 60 + NORTH_PAD], [424, 53 + NORTH_PAD],
				[398, 46 + NORTH_PAD], [412, 40 + NORTH_PAD]],
			# 계단과 길의 폭. 두 칸이면 화면에서 64px — 주인공 몸 폭(12px)
			# 다섯이라 「지나는 틈」이지 「오르는 계단」이 아니었다.
			# 네 칸이면 사람 넷이 나란히 오르는 길이 된다
			"width": 4,
			"lamps": true,       # 길 따라 양옆에 석등
			# 층계참을 잇는 길. 계단만 놓으면 층계참이 허허벌판이라
			# 어디로 가야 다음 계단인지 안 보인다 — 밟혀 다져진 길이
			# 이어져야 발이 저절로 따라간다
			"paths": [[[392, 68 + NORTH_PAD], [392, 57 + NORTH_PAD],
					[424, 57 + NORTH_PAD], [424, 50 + NORTH_PAD]],
				[[424, 50 + NORTH_PAD], [424, 49 + NORTH_PAD],
					[398, 49 + NORTH_PAD], [398, 43 + NORTH_PAD]],
				[[398, 43 + NORTH_PAD], [398, 42 + NORTH_PAD],
					[412, 42 + NORTH_PAD], [412, 37 + NORTH_PAD]]]}},
	# 별빛 호수 — 그림이 아니라 **지형**이 랜드마크다. 세계에서 제일 큰 물
	{"id": "starlake", "name": "별빛 호수", "kind": "",
		"tile": Vector2i(364, 104 + NORTH_PAD),
		"block": Rect2i(0, 0, 0, 0), "clear": 0,
		"lakes": [[364, 104 + NORTH_PAD, 26.0, 15.0]],
		"river": [352, 118 + NORTH_PAD, 322, 150 + NORTH_PAD, 2.4]},
]


# ---- 고장의 작은 마을 ----
#
# 교진 마을 밖에도 사람이 산다. 세계를 네 배로 넓히고 랜드마크를 세웠더니
# 「크고 멋있는데 아무도 안 사는 곳」이 됐다 — 구경거리지 마을이 아니다.
# 큰 것 곁에는 그것 때문에 사는 사람이 있어야 한다. 폭포 밑에는 물로
# 먹고사는 사람이, 큰나무 그늘에는 나무로 먹고사는 사람이.
#
# 교진 마을과 다른 점 하나: **여기는 짓는 게 아니다.** 처음부터 서 있고,
# 발견하는 것이다. 마을 발전(VILLAGE_PLOTS)과 헷갈리지 않게 표를 따로 둔다.
#
#   houses  [앵커, 집 그림, 사는 사람] — 앵커는 5x4 본체의 왼쪽 위
#   square  마을 한복판. 낮에 사람들이 모인다
#   sign    마을 이름 표지판
#   props   [칸, 종류] — 물레방아처럼 그 마을에만 있는 것
const HAMLETS := {
	# 물소리 마을 — 큰폭포 바로 동쪽. 물레방아 도는 소리가 하루 종일 난다
	"brookside": {
		"name": "물소리 마을",
		"houses": [
			[Vector2i(286, 20 + NORTH_PAD), "mill", "miller"],
			[Vector2i(286, 32 + NORTH_PAD), "creek", "dyer"],
			[Vector2i(296, 26 + NORTH_PAD), "cabin", "brook"],
		],
		"square": Vector2i(292, 27 + NORTH_PAD),
		"sign": Vector2i(288, 25 + NORTH_PAD),
		# 물레방아는 방앗간 옆 **물속**에 선다 (칸은 물길이 파인다)
		"props": [[Vector2i(283, 25 + NORTH_PAD), "deco_wheel"]],
	},
	# 나무그늘 마을 — 큰나무 서쪽 그늘. 나무를 베어 먹고사는 사람들인데
	# 정작 큰나무만은 아무도 손대지 않는다
	"treeshade": {
		"name": "나무그늘 마을",
		"houses": [
			[Vector2i(96, 134 + NORTH_PAD), "cabin", "sawyer"],
			[Vector2i(96, 146 + NORTH_PAD), "shade", "teller"],
			[Vector2i(106, 156 + NORTH_PAD), "cabin", "beekeep"],
		],
		"square": Vector2i(103, 143 + NORTH_PAD),
		"sign": Vector2i(100, 141 + NORTH_PAD),
		"props": [],
	},
}
# 이 사람이 어느 고장 사람인가 (없으면 교진 마을 사람). npcs.gd 가 본다
const HAMLET_OF := {
	"miller": "brookside", "dyer": "brookside", "brook": "brookside",
	"sawyer": "treeshade", "teller": "treeshade", "beekeep": "treeshade",
}
const HAMLET_NPC_IDS := ["miller", "dyer", "brook", "sawyer", "beekeep", "teller"]


# 우리집: 스토리 1 완료 후 집터(E)에서 목재로 직접 짓는다.
# 자리는 광장 남쪽 빈터 — 북쪽 줄(우체국) 마당과 겹치지 않는 곳으로 옮겼다.
const HOME_ANCHOR := Vector2i(88, 50 + NORTH_PAD)   # 마을 남서쪽 — 격자의 한 자리
const HOME_SITE := Vector2i(90, 50 + NORTH_PAD)  # 건물 그림 한가운데 (지도 라벨 기준점)

# 건물 부지(좌상단 앵커, 5x4). 처음에는 아무것도 없는 빈 공간이며
# 표지판도 건물 이름도 표시하지 않는다. 건설된 뒤에만 실제 건물이 나타난다.
# 건물은 5x4칸 그림에 둘레 마당까지 합쳐 한 채가 7x6칸을 차지한다.
# 북쪽 한 줄 + 서/동 두 줄로 벌려 놓아 서로 붙어 보이지 않는다.
# ---- 마을을 **다시 오므렸다** ----
#
# 세계를 네 배로 넓히면서 마을만 그대로 두었더니, 걸어서 가게 셋을
# 도는 데 서른 칸을 걸었다. 넓은 세계에서 마을까지 널찍하면 마을이
# 「마을」로 안 읽힌다 — 그냥 집 몇 채가 흩어진 들판이다.
#
# **밖은 넓히고 안은 좁힌다.** 넓은 야생과 촘촘한 마을이 대비되어야
# 마을에 들어선 순간 「돌아왔다」가 된다.
#
# 북쪽 줄은 18칸 -> **12칸** 간격(그림 7칸 + 사이 풀 5칸), 서쪽 줄은
# 10칸 -> **8칸**(마당 6칸 + 사이 2칸). 이보다 더 좁히면 마당이 붙어
# 벽처럼 보인다 — 여기가 끝이다.
# 마을은 **세 줄 × 네 칸의 격자**다. 한 부지가 울타리까지 11x10칸을 쓰고,
# 부지 사이는 3줄짜리 흙길(VILLAGE_ROADS)이 지나간다. 가운데 한 자리는
# 건물 대신 광장이다.
#
#        x60          x75          x90
#   y6   우체국       연구소       도서관
#   y21  대장간       마을회관     목장 상회
#   y36  수산시장     (광장)       잡화점
#   y51  우리집       이장 집      여관
#
# 자리를 옮길 때는 **울타리 테두리(11x10)가 서로도, 길과도 닿지 않게** 둔다.
# 마을은 네 칸 × 세 줄이되, **자로 잰 격자가 아니다.**
#
# 한 부지가 울타리까지 17x16칸을 쓰고(YARD_PAD 5), 부지 사이는 28칸 · 26칸씩
# 벌어져 있다. 화면이 담는 것이 53x30칸이니 **한 화면에 한 부지**다 —
# 「여기는 대장간」이고, 길을 따라 걸어가면 「여기는 잡화점」이다.
#
# 부지 사이는 숲이고(world_gen._plant_village_greenery), 길은 자로 그은
# 네모가 아니라 굽이친다(_paint_village_lane).
#
#          x88          x116         x144         x172
#   y10    우체국       연구소       마을회관     도서관
#   y36    수산시장     대장간       (광장)       잡화점
#   y62    우리집       이장 집      여관         목장 상회
const VILLAGE_PLOTS := {
	"post":    {"anchor": Vector2i(88, -2 + NORTH_PAD),  "name": "우체국"},
	"lab":     {"anchor": Vector2i(116, -2 + NORTH_PAD), "name": "연구소"},
	"hall":    {"anchor": Vector2i(144, -2 + NORTH_PAD), "name": "마을회관"},
	"library": {"anchor": Vector2i(172, -2 + NORTH_PAD), "name": "도서관"},
	"fish":    {"anchor": Vector2i(88, 24 + NORTH_PAD),  "name": "수산시장"},
	"smith":   {"anchor": Vector2i(116, 24 + NORTH_PAD), "name": "대장간"},
	"general": {"anchor": Vector2i(172, 24 + NORTH_PAD), "name": "잡화점"},
	"inn":     {"anchor": Vector2i(144, 50 + NORTH_PAD), "name": "여관"},
	"ranch":   {"anchor": Vector2i(172, 50 + NORTH_PAD), "name": "목장 상회"},
}
# ---- 부지마다 「여기는 뭐 하는 곳」 ----
#
# 가게가 다 같은 집 그림에 이름표만 다르면, 마을은 지어 놓은 모형 줄이다.
# 마당에 그 가게다운 살림이 벌어져 있으면 이름표를 안 읽어도 읽힌다 —
# 대장간 마당에는 자갈이 깔리고 광석 더미가 쌓여 있는 식이다.
#
# 두 가지를 적는다.
#   "floor": [[Rect2i(오프셋x, 오프셋y, 폭, 높이), 바닥], ...]
#            바닥은 "path"(자갈)·"yard"(다진 흙)·"soil"(갈아 둔 흙)·"sand".
#            **소품보다 먼저** 깔린다.
#   "props": [[Vector2i(오프셋), 종류], ...]
#
# 자리는 **건물 왼쪽 위 모서리에서 잰다.** 본체는 5x4, 문은 (2,3), 마당은
# YARD_PAD 만큼 사방으로 (지금은 x -5..+9 · y -5..+8), 울타리는 그 한 칸
# 바깥이다. 문 앞 통로(x +1~+3, y +4 아래)는 무엇도 놓지 않는다 — 드나드는 길이다.
#
# 그리고 **집 그림 뒤에는 아무것도 두지 않는다.** 집 한 채가 512px 판이라
# 화면에서 여덟 칸 폭이다 — x -1~+5 · y +3 위에 놓은 것은 죄다 지붕에
# 먹힌다. 소품은 x -5~-2 와 x +6~+9 두 줄, 그리고 앞마당(y +6~+8)에 둔다.
# 앞마당 널마루(y +4~+5, x 0~4)도 비워 둔다 — 거기는 나무 널이 깔린다.
# ---- **언덕 위의 집** ----
#
# 마을이 온통 평지였다. 집도 마당도 길도 한 장의 판에 놓여 있어서, 아무리
# 마당을 채워도 「위에서 내려다본 배치도」였다 — 높이가 없으니 깊이도 없다.
#
# 그렇다고 북쪽 줄을 통째로 올리면 마을 뒤에 백 칸짜리 성벽이 선다.
# 단차는 **몇 곳만** 준다. 부지 하나가 통째로 제 언덕에 얹히고, 문 앞에서
# 큰길로 돌계단이 내려온다 — 걸어가다 보면 「저 집은 언덕 위에 있네」가
# 되는 쪽이 마을 전체가 계단식인 것보다 특색이 있다.
#
# 어느 부지를 올릴 수 있는가는 **남쪽에 큰길이 있는가**로 정해진다.
# 언덕 남쪽 두 줄은 바위벽이라 걸어 들어갈 수 없고, 계단을 내려서면
# 그 아래 첫 줄부터 다시 걷는다. 그 첫 줄이 가로 큰길이라야 마을과 이어진다.
#   북쪽 줄(y10)  언덕 3~20 · 벽 21~22 · 큰길 23  ✔
#   가운데 줄(y36) 언덕 29~46 · 벽 47~48 · 큰길 49 ✔
#   남쪽 줄(y62)  아래가 숲이라 계단이 숲으로 떨어진다  ✘
#
# 그래서 도서관(북쪽)과 대장간(가운데)을 고른다 — 마을을 가로질러 대각선으로
# 멀리 떨어져 있어서 언덕이 줄지어 선 것처럼 보이지 않는다.
const HILL_PLOTS := ["library", "smith"]


const PLOT_DECOR := {
	# ── 대장간 ── 다진 흙 일터 · 돌 화덕 · 광석 산 · 문 앞 자갈길
	#
	# 처음에는 마당 열넉 칸을 통째로 자갈로 깔았다. 그랬더니 회색 자갈 위에
	# 회색 광석이 놓여 **아무것도 안 보였다** — 대장간이 아니라 빈 주차장이었다.
	# 일터 바닥은 흙이고, 자갈은 화덕 둘레와 문 앞 길에만 깐다.
	"smith": {
		"floor": [
			[Rect2i(5, -2, 5, 6), "path"],     # 화덕 둘레 — 불티가 튀는 자리
			[Rect2i(1, 6, 3, 4), "path"],      # 문 앞에서 어귀까지 난 길
		],
		"props": [
			# **곁에 선 돌 화덕** — 이 집이 무엇을 하는 집인지 멀리서 말한다
			[Vector2i(7, -1), "deco_cairn"],
			# 캐 온 것을 부려 놓은 뒷마당.
			# **집 그림 뒤(x -1~+5, y +3 위)에는 아무것도 두지 않는다** —
			# 집 한 채가 여덟 칸 폭이라 그 안에 놓은 것은 지붕에 먹힌다
			[Vector2i(-5, -4), "old_box"], [Vector2i(-3, -4), "storage_box"],
			[Vector2i(6, -4), "ore_node"], [Vector2i(8, -4), "rock_wedge"],
			[Vector2i(-5, -2), "ore_node"], [Vector2i(-3, -2), "ore"],
			# 동쪽 광석 산 — 화덕 곁
			[Vector2i(6, 1), "ore_node"], [Vector2i(9, 0), "rock_wedge"],
			[Vector2i(6, 3), "ore"], [Vector2i(8, 2), "ore_node"],
			[Vector2i(9, 4), "star_ore"], [Vector2i(7, 5), "ore_node"],
			# 서쪽 짐짝과 궤짝
			[Vector2i(-5, 0), "chest"], [Vector2i(-3, 1), "old_box"],
			[Vector2i(-4, 2), "storage_box"], [Vector2i(-4, 4), "ore_node"],
			[Vector2i(-2, 4), "rock_wedge"],
			# 앞마당 — 식히고 두드리는 자리
			[Vector2i(-4, 6), "rock_wedge"], [Vector2i(-2, 7), "nail"],
			[Vector2i(5, 6), "broom"], [Vector2i(7, 7), "ore"],
			[Vector2i(-5, 8), "deco_lamp"], [Vector2i(5, 8), "deco_lamp"],
			[Vector2i(-3, 8), "ore_node"], [Vector2i(7, 8), "star_ore"],
			[Vector2i(9, 8), "weed"], [Vector2i(9, 6), "rock_wedge"],
		],
	},
	# ── 우체국 ── 부린 짐 궤짝 · 손수레 · 짐 싣는 흙마당
	"post": {
		"floor": [[Rect2i(-5, 6, 5, 3), "path"], [Rect2i(5, 6, 5, 3), "path"]],
		"props": [
			[Vector2i(-5, -4), "storage_box"], [Vector2i(-3, -4), "old_box"],
			[Vector2i(6, -4), "storage_box"], [Vector2i(8, -4), "old_box"],
			[Vector2i(-5, -2), "chest"], [Vector2i(-3, -1), "storage_box"],
			[Vector2i(7, -2), "old_box"], [Vector2i(9, -1), "storage_box"],
			[Vector2i(-4, 1), "old_box"], [Vector2i(8, 1), "chest"],
			[Vector2i(-4, 3), "rope"], [Vector2i(8, 3), "rope"],
			[Vector2i(-1, 4), "deco_lamp"], [Vector2i(5, 4), "deco_lamp"],
			[Vector2i(-4, 6), "storage_box"], [Vector2i(-2, 6), "old_box"],
			[Vector2i(5, 6), "storage_box"], [Vector2i(7, 6), "old_box"],
			[Vector2i(-4, 8), "deco_lamp"], [Vector2i(6, 8), "deco_lamp"],
			[Vector2i(-5, 7), "cloth"], [Vector2i(9, 7), "cloth"],
			[Vector2i(0, 8), "storage_box"], [Vector2i(4, 8), "old_box"],
		],
	},
	# ── 연구소 ── 돌등 줄 · 결정 표본 · 샘물과 진흙 단지
	"lab": {
		"floor": [[Rect2i(-5, 6, 5, 3), "soil"], [Rect2i(5, 6, 5, 3), "soil"]],
		"props": [
			[Vector2i(-5, -4), "crystal"], [Vector2i(-3, -4), "gem"],
			[Vector2i(6, -4), "crystal"], [Vector2i(8, -4), "glow_shroom"],
			[Vector2i(-5, -2), "spring_water"], [Vector2i(-3, -1), "sludge"],
			[Vector2i(7, -2), "sludge"], [Vector2i(9, -1), "spring_water"],
			[Vector2i(-4, 1), "crystal"], [Vector2i(8, 1), "gem"],
			[Vector2i(-4, 3), "glow_shroom"], [Vector2i(8, 3), "glow_shroom"],
			[Vector2i(-1, 4), "deco_stonelamp"], [Vector2i(5, 4), "deco_stonelamp"],
			[Vector2i(-4, 6), "flower_pot"], [Vector2i(-2, 7), "recipe"],
			[Vector2i(5, 6), "flower_pot"], [Vector2i(7, 7), "recipe"],
			[Vector2i(-5, 8), "deco_stonelamp"], [Vector2i(9, 8), "deco_stonelamp"],
			[Vector2i(0, 8), "crystal"], [Vector2i(4, 8), "gem"],
			[Vector2i(-3, 8), "flower_pot"], [Vector2i(7, 8), "flower_pot"],
		],
	},
	# ── 마을회관 ── 넓은 자갈 앞뜰 · 평상과 등불 · 옛 물레바퀴
	"hall": {
		"floor": [[Rect2i(-5, 6, 15, 3), "path"]],
		"props": [
			[Vector2i(-5, -4), "carved_stone"], [Vector2i(7, -4), "carved_stone"],
			[Vector2i(-5, -2), "deco_bench"], [Vector2i(8, -2), "deco_bench"],
			[Vector2i(-4, 0), "flower_pot"], [Vector2i(9, 0), "flower_pot"],
			[Vector2i(-4, 2), "deco_lamp"], [Vector2i(8, 2), "deco_lamp"],
			[Vector2i(-1, 4), "deco_lamp"], [Vector2i(5, 4), "deco_lamp"],
			[Vector2i(-4, 6), "deco_bench"], [Vector2i(-2, 6), "deco_bench"],
			[Vector2i(5, 6), "deco_bench"], [Vector2i(7, 6), "deco_bench"],
			[Vector2i(-5, 8), "flower_pot"], [Vector2i(-3, 8), "deco_lamp"],
			[Vector2i(6, 8), "deco_lamp"], [Vector2i(8, 8), "flower_pot"],
			[Vector2i(0, 8), "flower_pot"], [Vector2i(4, 8), "flower_pot"],
		],
	},
	# ── 도서관 ── 돌등 줄 · 내놓은 책 궤짝 · 앉아 읽는 평상
	"library": {
		"floor": [[Rect2i(-5, 6, 5, 3), "path"], [Rect2i(5, 6, 5, 3), "path"]],
		"props": [
			[Vector2i(-5, -4), "old_box"], [Vector2i(7, -4), "old_box"],
			[Vector2i(-5, -2), "old_book"], [Vector2i(8, -2), "recipe"],
			[Vector2i(-4, 0), "chest"], [Vector2i(9, 0), "chest"],
			[Vector2i(-4, 2), "deco_bench"], [Vector2i(8, 2), "deco_bench"],
			[Vector2i(-1, 4), "deco_stonelamp"], [Vector2i(5, 4), "deco_stonelamp"],
			[Vector2i(-4, 6), "deco_bench"], [Vector2i(-2, 7), "old_book"],
			[Vector2i(5, 6), "deco_bench"], [Vector2i(7, 7), "old_book"],
			[Vector2i(-5, 8), "deco_stonelamp"], [Vector2i(9, 8), "deco_stonelamp"],
			[Vector2i(0, 8), "old_book"], [Vector2i(4, 8), "recipe"],
			[Vector2i(-3, 8), "flower_pot"], [Vector2i(7, 8), "flower_pot"],
		],
	},
	# ── 수산시장 ── 널판 마당과 모래 · 그물과 통발 · 널어 말리는 천
	"fish": {
		"floor": [
			[Rect2i(-5, 6, 15, 3), "dock"],    # 앞마당은 물가처럼 널을 깐다
			[Rect2i(-5, -4, 4, 9), "sand"], [Rect2i(6, -4, 4, 9), "sand"],
		],
		"props": [
			[Vector2i(-5, -4), "old_box"], [Vector2i(-3, -4), "rope"],
			[Vector2i(6, -4), "old_box"], [Vector2i(8, -4), "rope"],
			[Vector2i(-5, -2), "storage_box"], [Vector2i(-3, -1), "bait"],
			[Vector2i(7, -2), "storage_box"], [Vector2i(9, -1), "bait"],
			[Vector2i(-4, 1), "cloth"], [Vector2i(8, 1), "cloth"],
			[Vector2i(-4, 3), "forage_shell"], [Vector2i(8, 3), "forage_coral"],
			[Vector2i(-1, 4), "rope"], [Vector2i(5, 4), "rope"],
			[Vector2i(-4, 6), "old_box"], [Vector2i(-2, 6), "bait"],
			[Vector2i(5, 6), "old_box"], [Vector2i(7, 6), "bait"],
			[Vector2i(-5, 8), "chest"], [Vector2i(9, 8), "storage_box"],
			[Vector2i(0, 8), "deco_lamp"], [Vector2i(4, 8), "deco_lamp"],
			[Vector2i(-3, 8), "cloth"], [Vector2i(7, 8), "cloth"],
		],
	},
	# ── 잡화점 ── 자갈 장터 앞마당 · 내놓은 궤짝 장 · 천막천과 화분
	"general": {
		"floor": [[Rect2i(-5, 6, 15, 3), "path"]],
		"props": [
			[Vector2i(-5, -4), "storage_box"], [Vector2i(7, -4), "storage_box"],
			[Vector2i(-5, -2), "old_box"], [Vector2i(8, -2), "old_box"],
			[Vector2i(-4, 0), "chest"], [Vector2i(9, 0), "chest"],
			[Vector2i(-4, 2), "broom"], [Vector2i(8, 2), "recipe"],
			[Vector2i(-1, 4), "deco_lamp"], [Vector2i(5, 4), "deco_lamp"],
			[Vector2i(-4, 6), "chest"], [Vector2i(-2, 6), "old_box"],
			[Vector2i(5, 6), "chest"], [Vector2i(7, 6), "old_box"],
			[Vector2i(-5, 8), "storage_box"], [Vector2i(-3, 8), "cloth"],
			[Vector2i(6, 8), "cloth"], [Vector2i(8, 8), "storage_box"],
			[Vector2i(0, 8), "flower_pot"], [Vector2i(4, 8), "flower_pot"],
		],
	},
	# ── 여관 ── 등불 늘어선 앞뜰 · 평상과 화분 · 뒤뜰에 널린 빨래
	"inn": {
		"floor": [[Rect2i(-5, 6, 15, 3), "path"]],
		"props": [
			[Vector2i(-5, -4), "cloth"], [Vector2i(-3, -4), "cloth"],
			[Vector2i(6, -4), "cloth"], [Vector2i(8, -4), "cloth"],
			[Vector2i(-5, -2), "storage_box"], [Vector2i(8, -2), "storage_box"],
			[Vector2i(-4, 0), "flower_pot"], [Vector2i(9, 0), "flower_pot"],
			[Vector2i(-4, 2), "broom"], [Vector2i(8, 2), "deco_bench"],
			[Vector2i(-1, 4), "deco_lamp"], [Vector2i(5, 4), "deco_lamp"],
			[Vector2i(-4, 6), "deco_bench"], [Vector2i(-2, 6), "flower_pot"],
			[Vector2i(5, 6), "deco_bench"], [Vector2i(7, 6), "flower_pot"],
			[Vector2i(-5, 8), "deco_lamp"], [Vector2i(-3, 8), "deco_bench"],
			[Vector2i(6, 8), "deco_bench"], [Vector2i(8, 8), "deco_lamp"],
			[Vector2i(0, 8), "flower_pot"], [Vector2i(4, 8), "flower_pot"],
		],
	},
	# ── 목장 상회 ── **울타리 우리** · 여물 · 사료 짐짝
	#
	# 이 부지만은 살림이 아니라 **우리 한 칸**으로 말한다. 서쪽에 네 칸 ×
	# 일곱 칸 울타리를 두르고 남쪽 한 칸을 문으로 터 둔다 — 목장이 무엇을
	# 파는 집인지 이 한 칸이면 끝난다.
	"ranch": {
		"floor": [[Rect2i(-5, 6, 15, 3), "path"]],
		"props": [
			# 우리 — 윗변
			[Vector2i(-5, -4), "fence"], [Vector2i(-4, -4), "fence"],
			[Vector2i(-3, -4), "fence"], [Vector2i(-2, -4), "fence"],
			# 우리 — 좌우 기둥. **y +1~+3 로는 내려가지 않는다** — 그 줄에는
			# 부지의 옆문이 나 있어서, 말뚝을 박으면 광장 쪽 길이 막힌다
			[Vector2i(-5, -3), "fence"], [Vector2i(-5, -2), "fence"],
			[Vector2i(-5, -1), "fence"],
			[Vector2i(-2, -3), "fence"], [Vector2i(-2, -2), "fence"],
			[Vector2i(-2, -1), "fence"],
			# 우리 — 아랫변 (가운데 한 칸이 문이다)
			[Vector2i(-5, 0), "fence"], [Vector2i(-4, 0), "fence"],
			[Vector2i(-2, 0), "fence"],
			# 우리 안 — 여물과 풀
			[Vector2i(-4, -2), "weed"], [Vector2i(-3, -1), "weed"],
			[Vector2i(-4, -3), "storage_box"],
			# 동쪽 — 사료 짐짝과 짐수레
			[Vector2i(6, -4), "storage_box"], [Vector2i(8, -4), "old_box"],
			[Vector2i(7, -2), "rope"], [Vector2i(9, -1), "storage_box"],
			[Vector2i(8, 1), "old_box"], [Vector2i(8, 3), "rope"],
			[Vector2i(-1, 4), "deco_lamp"], [Vector2i(5, 4), "deco_lamp"],
			[Vector2i(-4, 6), "storage_box"], [Vector2i(-2, 6), "weed"],
			[Vector2i(5, 6), "storage_box"], [Vector2i(7, 6), "weed"],
			[Vector2i(-5, 8), "deco_bench"], [Vector2i(9, 8), "old_box"],
			[Vector2i(0, 8), "flower_pot"], [Vector2i(4, 8), "flower_pot"],
		],
	},
}


# 이 모서리가 마을 부지인가 (아니면 빈 문자열). 마당을 꾸밀 때만 쓴다 —
# 농장 집·고장 집·숲속 집은 같은 _build_yard 를 지나가지만 꾸미지 않는다.
func plot_at_anchor(anchor: Vector2i) -> String:
	for pid: String in VILLAGE_PLOTS:
		if VILLAGE_PLOTS[pid].anchor == anchor:
			return pid
	return ""


# 이 칸을 몸통으로 삼는 마을 부지 (아니면 빈 문자열).
# 건물이 처음부터 다 서 있게 되면서, 「이 집은 어느 가게인가」를 물을 일이
# `village_built` 바깥에서도 생겼다 — 아직 사람이 들지 않은 가게가 그렇다.
func plot_body_at(t: Vector2i) -> String:
	for pid: String in VILLAGE_PLOTS:
		var a: Vector2i = VILLAGE_PLOTS[pid].anchor
		if t.x >= a.x and t.x < a.x + 5 and t.y >= a.y and t.y < a.y + 4:
			return pid
	return ""


# 부지 앞 게시판이 서는 칸 — **문 옆**이다.
#
# 예전에는 문 칸(anchor+(2,3))에 세웠다. 그때는 빈 터였으니 문이랄 것도
# 없었지만, 건물이 처음부터 서 있는 지금 그 자리는 드나드는 문이다.
func plot_board_tile(anchor: Vector2i) -> Vector2i:
	return anchor + Vector2i(-1, 4)


# 이장의 거처 — 처음부터 마을에 있는 집 (광장 북쪽). 주민이 늘면 회관 급
# 새 집으로 다시 지어진다 (GameData.chief_house_lv).
#
# 이 값은 **문 칸**이다 — 건물 왼쪽 위 모서리가 아니다. 마을 건물이
# door_tile(anchor) = anchor + (2,3) 을 문으로 쓰는 것과 같은 자리라,
# 물건 배치의 기본 규칙(밑변을 한 칸 아래, 가로는 칸 한가운데)이 그대로
# 5x4 본체에 맞아떨어진다. 그림이 다른 집들과 같은 512x552 판이 되면서
# 한 칸짜리 물건처럼 세우면 집이 문 앞으로 반쯤 튀어나왔다.
const CHIEF_ANCHOR := Vector2i(116, 50 + NORTH_PAD)        # 본체 5x4 의 왼쪽 위
const CHIEF_HUT := Vector2i(118, 53 + NORTH_PAD)           # = door_tile(CHIEF_ANCHOR)
const CHIEF_ART := Rect2i(115, 48 + NORTH_PAD, 7, 6)       # 그림이 덮는 칸
# 마당: 건물 그림(5x4) 둘레로 한 칸씩 더. 울타리를 두르고 문 앞만 터 둔다.
const YARD_PAD := 5
# 마을 발전 순서: 이장에게 이야기하면 이 순서대로 하나씩 지을 수 있다.
# (여관·연구소·도서관 부지는 자리만 잡아두고 이후 이야기에서 열린다)
const VILLAGE_BUILD_ORDER := ["post", "general", "smith", "library", "ranch",
	"fish", "hall"]
const VILLAGE_BUILD_COST := {   # [목재, 석재]
	# general은 메인 스토리 2의 첫 퀘스트 — GameData.SHOP_BUILD_*와 같게 둔다
	"post": [30, 10], "general": [30, 20], "smith": [60, 50],
	"ranch": [80, 40], "fish": [100, 60], "hall": [120, 80],
	# 도서관은 메인 스토리 6(오래된 책과 사서)에서만 열리는 건설이다
	"library": [90, 50],
}


# 마을 주민 수 (플레이어 포함) — 이장 새 집·마을회관 해금 기준
func village_residents() -> int:
	return npcs.size() + 1
# 건물이 생기면 그 건물의 주인이 마을에 자리를 잡는다 (이장은 처음부터 있다)
const VILLAGE_NPC := {"general": "merchant", "smith": "blacksmith",
	"ranch": "rancher", "fish": "fisher", "library": "librarian",
	"post": "postman"}
# ---- NPC 하루 일과 ----
#
# 시간대마다 갈 곳이 바뀐다. 목적지까지는 길찾기로 걸어가고,
# 도착하면 그 둘레를 어슬렁거린다. 19시(저녁)에는 기존대로 집에 들어간다.
# 새 NPC를 넣을 때는 이 세 표에 한 줄씩만 더하면 된다.
#   [시작 시각, 장소] — 시각 순서대로 적는다
const NPC_SCHEDULE := {
	"chief":      [[6, "home"], [9, "board"], [12, "plaza"], [16, "board"]],
	"merchant":   [[6, "home"], [9, "work"], [13, "plaza"], [15, "work"]],
	# 우체부 — 아침 첫 배달을 돌고(광장) 낮부터 우체국을 지킨다
	"postman":    [[6, "work"], [8, "plaza"], [10, "work"], [16, "plaza"]],
	"blacksmith": [[6, "home"], [9, "work"], [14, "plaza"], [16, "work"]],
	"rancher":    [[6, "home"], [8, "work"], [12, "plaza"], [15, "work"]],
	# 사서 — 방문객일 때는 work가 광장(집이 없어서)으로, 도서관이 서면
	# 도서관 앞으로 저절로 풀린다 (npc_place_tile의 기본 규칙)
	"librarian":  [[6, "plaza"], [9, "work"], [13, "plaza"], [15, "work"]],
	"fisher":     [[6, "home"], [8, "pier"], [13, "plaza"], [15, "pier"]],
	# 이사 온 일반/특수 주민 — 오전엔 집 곁, 낮엔 광장에서 어울린다
	"farmer":     [[6, "home"], [10, "plaza"], [15, "home"]],
	"foodie":     [[6, "home"], [11, "plaza"], [16, "home"]],
	"angler":     [[6, "home"], [9, "pier"], [14, "plaza"], [17, "home"]],
	# 연금술사는 마을에 살지 않는다 — 깊은 숲 오두막 곁만 지킨다 (스토리 12)
	"alchemist":  [[6, "home"]],
	"miner":      [[6, "home"], [9, "plaza"], [13, "home"]],
	"florist":    [[6, "home"], [10, "plaza"], [16, "home"]],
	"carpenter":  [[6, "home"], [11, "plaza"], [15, "home"]],
	"herbalist":  [[6, "home"], [9, "plaza"], [14, "home"]],
	"painter":    [[6, "home"], [12, "plaza"], [17, "home"]],
	"musician":   [[6, "home"], [13, "plaza"], [17, "home"]],
	"weaver":     [[6, "home"], [10, "plaza"], [14, "home"]],
	# ---- 고장 사람들 ----
	# plaza 는 교진 마을 광장이라 여기 사람들은 안 간다. 대신 제 마을
	# 한복판(square)에 모인다 — 하루가 제 고장 안에서 돈다
	"miller":     [[6, "work"], [12, "square"], [14, "work"], [19, "home"]],
	"dyer":       [[7, "work"], [11, "square"], [13, "work"], [19, "home"]],
	"brook":      [[8, "square"], [10, "falls"], [15, "square"], [18, "home"]],
	"sawyer":     [[6, "work"], [11, "square"], [13, "work"], [19, "home"]],
	"beekeep":    [[7, "work"], [12, "square"], [15, "work"], [19, "home"]],
	"teller":     [[9, "square"], [12, "tree"], [17, "square"], [19, "home"]],
}
# 광장에서 각자 서는 자리 (한 곳에 몰리지 않게 흩어 둔다)
# 광장(x71~82 · y32~43) 안에서 분수(x75~78 · y36~39)를 비켜 선다.
# 분수 북쪽 한 줄, 남쪽 한 줄, 양옆 기둥 — 그러면 열여섯이 겹치지 않는다
# 광장(x105~119 · y25~38) 안에서 분수(x110~113 · y29~32)를 비켜 선다.
# 분수 북쪽 한 줄, 남쪽 한 줄, 양옆 기둥 — 그러면 열여섯이 겹치지 않는다
# 광장(x114~126 · y26~37) 안에서 분수(x119~122 · y30~33)를 비켜 선다
# 광장(x138~154 · y30~45) 안에서 분수(x144~147 · y36~39)를 비켜 선다
const NPC_PLAZA := {
	"chief": Vector2i(144, 20 + NORTH_PAD), "merchant": Vector2i(146, 20 + NORTH_PAD),
	"blacksmith": Vector2i(142, 20 + NORTH_PAD), "alchemist": Vector2i(148, 20 + NORTH_PAD),
	"miner": Vector2i(150, 20 + NORTH_PAD),
	# 이사 온 주민들 — 분수 남쪽에 삼삼오오 모여 수다를 떤다
	"rancher": Vector2i(140, 29 + NORTH_PAD), "fisher": Vector2i(142, 29 + NORTH_PAD),
	"farmer": Vector2i(144, 29 + NORTH_PAD), "foodie": Vector2i(146, 29 + NORTH_PAD),
	"angler": Vector2i(148, 29 + NORTH_PAD), "musician": Vector2i(150, 29 + NORTH_PAD),
	"weaver": Vector2i(152, 29 + NORTH_PAD),
	# 양옆 기둥
	"florist": Vector2i(139, 23 + NORTH_PAD), "herbalist": Vector2i(139, 26 + NORTH_PAD),
	"carpenter": Vector2i(153, 23 + NORTH_PAD), "painter": Vector2i(153, 26 + NORTH_PAD),
}
# 건물이 없는 NPC(이장)의 집 자리
const NPC_HOME := {"chief": Vector2i(118, 54 + NORTH_PAD), "explorer": Vector2i(146, 26 + NORTH_PAD),
	"forest_mom": Vector2i(31, 28 + NORTH_PAD), "forest_girl": Vector2i(34, 28 + NORTH_PAD),
	"librarian": Vector2i(144, 31 + NORTH_PAD),  # 방문객 시절 — 광장 분수 곁
	"rancher": Vector2i(142, 31 + NORTH_PAD),    # 방문객 시절 — 광장 분수 남쪽
	"alchemist": Vector2i(58, 50 + NORTH_PAD)}   # 깊은 숲 오두막 문 앞 (ALCH_HOUSE_ANCHOR 문+1)
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
const CAMERA_ZOOM := 0.56                  # 1714 x 964 월드 픽셀 = 53.6 x 30 타일
# (0.8에서 0.7배 더 줌 아웃 — 화면에 담기는 세상이 한층 넓다)
const UI_FONT := preload("res://assets/fonts/Galmuri11.ttf")
const UI_FONT_SMALL := preload("res://assets/fonts/Galmuri9.ttf")

var npcs: Array = []


const KyojinLoading := preload("res://scripts/loading.gd")


# 세계를 짓는 도중에 로딩판의 막대를 민다.
#
# 가장 긴 대목이 `_build_map()` 하나다. 그 앞뒤에서만 값을 바꾸면 짓는 내내
# 막대가 한 자리에 붙박여 「멈췄다」로 보이므로, 안에서도 몇 번 부른다.
# **await 로 부른다** — 막대가 거기까지 차오르는 동안 진짜 프레임이 돈다.
func mark_build(text: String, ratio: float) -> void:
	await KyojinLoading.breathe(get_tree(), text, ratio)


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

	# 여기부터 몇 초쯤 화면이 굳는다 — 그동안 무엇을 하고 있는지 말해 준다.
	# await 가 아니라 그 자리에서 다시 그리는 방식이라(loading.gd 참고),
	# 절반만 지어진 세계에 남의 _process 가 끼어들 일이 없다
	# **짓는 동안 트리는 멈추고 세계는 감춘다.**
	#
	# 아래 breathe() 들이 진짜 프레임을 흘려 보내므로(막대가 차오르는 자리다),
	# 그대로 두면 절반만 지어진 세계가 그려지고 남의 _process 도 끼어든다.
	# 로딩판은 PROCESS_MODE_ALWAYS 라 멈춘 트리에서도 혼자 움직인다.
	visible = false
	get_tree().paused = true
	await KyojinLoading.breathe(get_tree(), "그림을 굽는 중…", 0.14)
	_load_textures()
	await KyojinLoading.breathe(get_tree(), "옷을 입히는 중…", 0.26)
	apply_appearance()   # 새 게임: 타이틀에서 고른 외형 / 게스트: 기본 외형
	await KyojinLoading.breathe(get_tree(), "땅을 고르고 숲을 심는 중…", 0.34)
	await worldgen._build_map()
	await KyojinLoading.breathe(get_tree(), "물길을 내는 중…", 0.72)
	rebuild_water_levels()
	await KyojinLoading.breathe(get_tree(), "밭을 일구는 중…", 0.75)
	farming.rebuild()
	get_tree().paused = false
	visible = true

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
	storage_ui = preload("res://scripts/storage_ui.gd").new()
	storage_ui.main = self
	add_child(storage_ui)

	quest_ui = preload("res://scripts/quest_ui.gd").new()
	quest_ui.main = self
	add_child(quest_ui)

	note_ui = preload("res://scripts/note_ui.gd").new()
	note_ui.main = self
	add_child(note_ui)

	stats_ui = preload("res://scripts/stats_ui.gd").new()
	stats_ui.main = self
	add_child(stats_ui)

	auction_ui = preload("res://scripts/auction_ui.gd").new()
	auction_ui.main = self
	add_child(auction_ui)

	settings_ui = preload("res://scripts/settings_ui.gd").new()
	settings_ui.main = self
	add_child(settings_ui)

	cave = preload("res://scripts/cave_ui.gd").new()
	cave.main = self
	add_child(cave)

	shop_room = preload("res://scripts/shop_room.gd").new()
	shop_room.main = self
	add_child(shop_room)

	# 마을 사람들: 이장만 처음부터 광장에 있고,
	# 나머지는 자기 건물이 지어진 뒤에 마을에 자리를 잡는다
	npcmgr._spawn_npc("chief", Vector2i(144, 20 + NORTH_PAD))

	sleep_dialog = ConfirmationDialog.new()
	sleep_dialog.dialog_text = "잠자리에 들까요?\n다음 날 아침이 됩니다."
	sleep_dialog.ok_button_text = "잔다"
	sleep_dialog.cancel_button_text = "안 잔다"
	sleep_dialog.confirmed.connect(func() -> void:
		Sound.play_sfx("sfx_sleep")
		daycycle._fade_next_day(false))
	add_child(sleep_dialog)

	ending = preload("res://scripts/ending_ui.gd").new()
	ending.main = self
	add_child(ending)

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
		# 접속 실패 — 이 신호를 안 받으면 「접속하는 중...」에서 하염없이 멈춘다
		multiplayer.connection_failed.connect(netsync._on_connection_failed)
		# 게스트: 로컬 저장 대신 호스트 스냅샷을 기다린다
		GameData.reset_all()
		GameData.tutorial = {"active": false}
		GameData.tutorial_space = false   # 합동 농장은 세계에서 바로 시작한다
		dirty_walk()
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
		rebuild_water_levels()   # 세이브의 물길로 깊이를 다시 잰다
		apply_appearance()   # 세이브에 담긴 외형으로 다시 굽는다
		# 옛 세이브의 튜토리얼은 세계 안(y7~22)에 있었다. 그 자리는 이제 마을 곁의
		# 평범한 들판이라, 그대로 두면 세계 밖으로 옮겨 온 숲길과 어긋난다 —
		# 튜토리얼 도중에 저장한 것이라면 그 숲길을 새로 깔고 첫 자리에 세운다.
		if GameData.tutorial_space and player_tile().y < WORLD_H:
			story._plant_story_forest()
			player.position = Vector2(STORY_SPAWN.x * TILE + 16, STORY_SPAWN.y * TILE + 16)
			GameData.explored.clear()
			GameData.mark_explored_at(STORY_SPAWN)
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
		if GameData.fisher_quest in ["meet", "cast", "open"]:
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
			player.dir = "right"   # 등 뒤는 지나온 들판, 눈앞이 숲이다
			story._plant_story_forest()
			story._apply_story_camera.call_deferred()
			hud.show_message("숲 어귀에 닿았다. 이 숲을 지나야 마을이 나온다.", 5.0)
			if not story_shot:
				story._show_intro.call_deferred()
		else:
			# 검증 샌드박스·합동 농장은 튜토리얼을 건너뛴 셈이다 — 처음부터 세계 안이다
			GameData.tutorial_space = false
			dirty_walk()
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
			dirty_walk()
			# 이주 인사도 전부 끝난 샌드박스 — 도착 연출 검증은 265가 돌린다
			GameData.npc_greeted = ["merchant", "blacksmith", "rancher",
				"fisher", "explorer"]
			GameData.village_built = GameData.ALL_VILLAGE_PLOTS.duplicate()
			GameData.seeds["potato"] = 5  # 씨앗 심기 캡처용
			GameData.house_lv = 2         # 집/조리대/침대 캡처용
			GameData.has_bed = true
			GameData.furniture = GameData.default_furniture()  # 넓은 방 캡처용 세간
			for cy in range(0, WORLD_H / GameData.EXPLORE_CHUNK + 1):
				for cx in range(0, MAP_W / GameData.EXPLORE_CHUNK + 1):
					GameData.explored[Vector2i(cx, cy)] = true  # 지도 캡처용 전체 탐사
			# (집 칸을 손으로 채우고 「집터」 표지판을 지우던 네 줄은 없앴다 —
			#  이제 우리집도 세계를 지을 때 다른 건물과 같이 선다. 표지판을
			#  지우던 그 한 줄이 이제는 **집 한복판에 구멍을 뚫는다**)
	npcmgr._sync_village_npcs()
	objnode._spawn_objects()
	objnode._apply_season_visuals()
	if GameData.quest.is_empty() and GameData.quest_offers.is_empty():
		GameData.make_daily_quest()

	KyojinLoading.mark(get_tree(), "마을 사람들을 깨우는 중…", 1.0)
	_setup_fade(loaded.size() > 0 or _shot_path != "")
	# 신규 게임은 _show_intro가 스토리 동안 화면을 가렸다가 직접 페이드한다
	# 다 지었다 — 막대를 100까지 마저 채우고, 다 찬 뒤 두 박자 쉬었다가
	# 로딩판을 걷는다 (기다리는 동안 트리는 서 있다: loading.gd 참고)
	KyojinLoading.finish(get_tree(), 2.0)


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
	# 울타리 — **이웃 넷의 꼴마다 한 장**(북1 · 동2 · 남4 · 서8).
	#
	# 예전에는 한 장을 열 칸에 그대로 찍었다. 조각 하나에 말뚝이 둘,
	# 그 사이에 가로장 — 그것을 나란히 놓으면 말뚝이 두 개씩 붙어 서고
	# 모퉁이에서는 장이 허공으로 뻗었다. 울타리가 아니라 도장이었다.
	# 이제는 이어진 쪽으로만 장을 뻗는다 (ref/make_fence.js).
	for fm in 16:
		tex["fence_%d" % fm] = load("res://assets/sprites/fence_%d.png" % fm)
	# 물 — 깊이 다섯 단 × 판 셋 × 장 둘.
	#   깊이  물가에서 멀수록 짙다. 한 단이 반 톤이라 경계가 안 보인다
	#   판    한 장을 호수에 반복해 깔면 잔물결이 같은 자리마다 찍혀
	#         물 위에 바둑판이 뜬다. 잔디처럼 판을 나눠 칸마다 골라 쓴다
	_water_tex.resize(WATER_LV * 3 * 2)
	for lv in WATER_LV:
		for vr in 3:
			for f in 2:
				var wn := "water_%d_%d_%d" % [lv, vr, f]
				tex[wn] = load("res://assets/sprites/%s.png" % wn)
				_water_tex[(lv * 3 + vr) * 2 + f] = tex[wn]
	# 경계 — 이웃 **여덟 칸**의 꼴(0~255)마다 한 칸씩 담긴 아틀라스 한 장.
	#
	# 이웃 넷만 보고 그렸더니, 볼록한 귀퉁이에서 땅 칸은 제 모서리를 깎아
	# 물을 들이는데 바로 옆 물 칸은 물가가 아직 타일 변에 있는 줄 알았다.
	# 같은 자리를 두 칸이 다르게 그려서 여울 띠가 모서리마다 어긋나 끊겼다.
	# 아홉 칸을 보면 이웃한 두 칸이 겹치는 창을 보므로 경계를 똑같이 잰다.
	#
	#   shore/shoal  연못·강 — 둑이 서고 남쪽을 보는 면에 돌벽
	#   beach/surf   바다 — 벽 없이 모래가 기울어 들고 거품이 민다
	#   dune/trod    잔디 칸으로 흘러드는 모래 · 마당 흙
	#
	# 꼴이 256가지라 파일로 두면 천오백 장이다. 한 장에 모으면 불러오기도
	# 가볍고, 같은 텍스처라 그리기가 오히려 더 잘 묶인다
	var sheets: Array[String] = []
	for kind: String in EDGE_KINDS:
		sheets.append(kind)
	for kind: String in EDGE_VAR_KINDS:
		for v in EDGE_VARS:
			sheets.append("%s_%d" % [kind, v])
	# 못 불러오면 **조용히 넘어가지 않는다.** AtlasTexture는 atlas가 null이어도
	# 오류 없이 아무것도 안 그린다 — edge_*.png에 .import가 빠졌을 때 물가
	# 타일 256장이 통째로 사라졌는데 로그에 한 줄도 안 남고, 연못만 각진 파란
	# 덩어리로 나왔다. 실행하자마자 몇 장이 붙었는지 한 줄로 찍는다.
	var edge_ok := 0
	var edge_bad: Array[String] = []
	for kind: String in sheets:
		var sheet: Texture2D = load("res://assets/sprites/edge_%s.png" % kind)
		if sheet == null:
			edge_bad.append(kind)
		else:
			edge_ok += 1
		# 벼랑면만 **두 칸 높이**다 (make_ground.js 의 KIND 표에서 rows=2).
		# 한 칸으로는 아무리 잘 칠해도 높이가 안 느껴져 층계참이 낮은 턱으로
		# 보였다. 아틀라스 칸도 그만큼 세로로 길다
		var ch: int = EDGE_PX * 2 if kind.begins_with("cliff") else EDGE_PX
		var arr: Array[Texture2D] = []
		arr.resize(256)
		for c in 256:
			var a := AtlasTexture.new()
			a.atlas = sheet
			a.region = Rect2((c % 16) * EDGE_PX, (c / 16) * ch, EDGE_PX, ch)
			arr[c] = a
		edge_tex[kind] = arr
	if edge_bad.is_empty():
		print("[물가] 아틀라스 %d/%d 장 붙음 — 정상" % [edge_ok, sheets.size()])
	else:
		print("[물가] !!! %d장을 못 불렀다: %s" % [edge_bad.size(), ", ".join(edge_bad)])
		print("[물가]     assets/sprites/edge_*.png.import 가 있는지 보라.")
		print("[물가]     없으면 물가 타일이 통째로 안 그려져 연못이 각지게 나온다.")
		push_error("물가 아틀라스 %d장 로드 실패: %s" % [edge_bad.size(), ", ".join(edge_bad)])
	# 모래·길·마당도 판을 셋씩 — 한 장만 깔면 무늬가 같은 자리마다 찍힌다
	for v in 3:
		for kind: String in ["sand_", "path_", "yard_", "ramp_", "dock_"]:
			tex[kind + str(v)] = load("res://assets/sprites/%s%d.png" % [kind, v])
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
	# 고장 마을 사람들 — 여덟 장씩(걷기 6 + 초상 2)이라 이름을 하나씩
	# 적으면 표만 마흔여덟 줄이 된다. 표에서 따라간다
	for nid: String in HAMLET_NPC_IDS:
		for sfx: String in ["down_0", "down_1", "up_0", "up_1", "side_0", "side_1",
				"portrait_normal", "portrait_happy"]:
			var nn := "npc_%s_%s" % [nid, sfx]
			tex[nn] = load("res://assets/sprites/%s.png" % nn)
	# 프롤로그 일러스트 — 오프닝 편지지 위에 얹는 움직이는 장면 (4프레임)
	for pn: String in ["grandpa", "box", "letter", "farm"]:
		for i in 4:
			var an := "prologue_%s_%d" % [pn, i]
			var ap := "res://assets/sprites/%s.png" % an
			if ResourceLoader.exists(ap):
				tex[an] = load(ap)
	# 플레이어 도트 — 머리 스타일(외형 템플릿)마다 한 벌씩. ref/dot_boy/
	# make_sprites.py가 표준 팔레트로 그려 둔다. 없는 프레임은 조용히
	# 건너뛴다 (휘두르기 도트가 없으면 player.gd가 몸통을 굽혀 대신한다).
	for g: String in GameData.HAIR_PREFIX:
		for sfx: String in _player_suffixes():
			var sn := "%s_%s" % [g, sfx]
			var sp := "res://assets/sprites/%s.png" % sn
			if ResourceLoader.exists(sp):
				tex[sn] = load(sp)


# 플레이어 한 벌을 이루는 프레임 이름들 (idle 3 + walk 18 + blink 2 + swing 15)
func _player_suffixes() -> Array[String]:
	var out: Array[String] = ["down_idle", "up_idle", "side_idle",
		"down_blink", "side_blink"]
	for d: String in ["down", "up", "side"]:
		for i in GameData.WALK_FRAMES:
			out.append("%s_walk_%d" % [d, i])
		for i in 5:   # player.gd의 SWING_FRAMES와 같은 수
			out.append("%s_swing_%d" % [d, i])
	return out


# 고른 외형을 플레이어 텍스처로 굽는다 — 게임은 언제나 pc_* 이름만 본다.
# 머리 스타일이 원본 한 벌을 정하고, 옷·바지·신발 색은 표준 팔레트를
# 골라 둔 색으로 바꿔 만든다 (GameData.recolor_player_image).
func apply_appearance() -> void:
	var ap: Dictionary = GameData.appearance
	var src: String = GameData.HAIR_PREFIX[clampi(int(ap.hair), 0, GameData.HAIR_PREFIX.size() - 1)]
	var plain: bool = int(ap.shirt) == 0 and int(ap.pants) == 0 and int(ap.shoes) == 0
	for sfx: String in _player_suffixes():
		var t: Texture2D = tex.get("%s_%s" % [src, sfx])
		if t == null:
			continue
		if plain:
			tex["pc_" + sfx] = t
		else:
			var img: Image = t.get_image()
			GameData.recolor_player_image(img, ap)
			tex["pc_" + sfx] = ImageTexture.create_from_image(img)


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
	# chief_hut은 여기 없다 — object_nodes.gd 가 sc=0.5로 못 박는다 (도트 밀도)
	"forage_ring": 1.1, "forage_relic": 1.2, "trash_bin": 2.4,
	"deco_fountain": 1.4, "deco_lamp": 1.15, "deco_bench": 1.15,
	# 가게 마당의 소품 — 32x32 한 칸짜리라 2.0이면 화면에서 딱 한 칸이다.
	# 조금씩 다르게 두어 늘어놓았을 때 자로 잰 듯 보이지 않게 한다
	"flower_pot": 2.0, "chest": 2.1, "storage_box": 2.2, "ore_node": 2.2,
	"rock_wedge": 2.0, "bait": 2.0, "crystal": 1.9, "rope": 1.9, "broom": 2.0,
	"old_box": 2.1, "ore": 2.1, "star_ore": 2.1, "nail": 1.9, "cloth": 1.9,
	"gem": 1.8, "recipe": 1.8, "glow_shroom": 1.9, "spring_water": 1.9,
	"sludge": 1.9,
}
# 자연물 배치 간격(타일). 실제 그려지는 폭에서 뽑았다.
#
# 나무는 "옆으로 나란히" 있을 때만 그림이 지저분하게 겹친다.
# 앞뒤(위아래)로 겹치는 것은 y정렬로 앞 나무가 뒤 나무를 가려 주므로
# 오히려 깊은 숲처럼 보인다. 그래서 가로 간격만 넓게 잡고 세로는 촘촘히 둔다.
# ---- 자연물이 **절대** 나면 안 되는 칸 ----
#
# 「나무 한 그루가 그림을 반쯤 가린다」는 자리마다 따로 막아 왔다 —
# 랜드마크는 clear 값으로, 낚시터는 다 흩고 나서 지우기로, 오르막은
# is_ramp 로. 자리를 하나 새로 만들 때마다 그 예외를 어딘가에 또 적어야
# 했고, 지역(REGIONS) 안에서는 바닥 종류 검사가 통째로 건너뛰어져서
# **깔아 놓은 길과 돌계단 위에 나무가 돋았다.**
#
# 칸마다 한 바이트로 못박아 둔다. 지형을 지을 때 표시해 두면, 처음 흩을
# 때도 아침마다 되살아날 때도 같은 자리를 본다.
var no_spawn := PackedByteArray()


func spawn_blocked(x: int, y: int) -> bool:
	if no_spawn.is_empty() or x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
		return false
	return no_spawn[y * MAP_W + x] != 0


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
	# 석등(계단 옆)은 마을 광장의 가로등(deco_lamp)과 **다른 물건**이다.
	# 계단 바로 옆에 서므로 여백이 넓으면 두 칸짜리 계단을 양쪽에서
	# 좁혀 지나갈 수가 없어진다
	"deco_stonelamp": Vector2(2, 2),
	# 마당 소품은 여백을 거의 안 준다 — 가게 앞 한 칸 틈으로도 지나갈 수 있어야 한다
	"flower_pot": Vector2(2, 2), "chest": Vector2(2, 2), "storage_box": Vector2(2, 2),
	"ore_node": Vector2(2, 2), "rock_wedge": Vector2(2, 2), "bait": Vector2(2, 2),
	"crystal": Vector2(2, 2), "rope": Vector2(2, 2), "broom": Vector2(2, 2),
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

# ---- 걸을 수 있는 땅 ----
#
# 물건(나무·돌·설치물)만 빼면 이 답은 **좀처럼 안 바뀐다** — 물길, 벼랑,
# 해금된 구역으로 정해진다. 그런데 물을 때마다 지역 스물셋과 마을 구역들의
# 네모를 하나씩 물어봤다. 한 번에 4µs다.
#
# 길찾기가 이걸 수만 번 부른다. 길 하나에 60ms가 여기서 갔다 — 걸음마다,
# 밤 몬스터가 나올 자리를 찾을 때마다, 끼임을 풀 때마다 같이 물었다.
# 칸마다 한 번만 재고 담아 둔다. 지형이나 해금이 바뀌면 통째로 버린다.
const WALK_UNKNOWN := 0
const WALK_OK := 1
const WALK_NO := 2
var _walk := PackedByteArray()


func dirty_walk() -> void:
	# 136KB 한 판을 0으로 미는 것뿐 — 구역을 살 때마다 불러도 된다
	var n := MAP_W * MAP_H
	if _walk.size() != n:
		_walk.resize(n)
	_walk.fill(WALK_UNKNOWN)


func is_passable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return false
	if objects.has(t):
		return false
	if grid.is_empty():
		return false
	# 검증 하네스는 해금 상태(구역·튜토리얼 공간)를 직접 뒤집는다 —
	# 거기서는 캐시를 안 쓴다. 중요한 건 빠르기가 아니라 답이 맞는 것이다
	if harness != null:
		return grid[t.y][t.x].ground != "water" and not _cliff_foot(t.x, t.y) \
			and _tile_accessible(t)
	if _walk.size() != MAP_W * MAP_H:
		dirty_walk()
	var i := t.y * MAP_W + t.x
	var w: int = _walk[i]
	if w == WALK_UNKNOWN:
		# 벼랑 밑은 오르막으로만 오르내리고, 해금하지 않은 부지에는 못 든다
		w = WALK_OK if (grid[t.y][t.x].ground != "water"
			and not _cliff_foot(t.x, t.y) and _tile_accessible(t)) else WALK_NO
		_walk[i] = w
	return w == WALK_OK


func _tile_accessible(t: Vector2i) -> bool:
	# 튜토리얼 중에는 **울타리 안의 숲길**이 세계의 전부다
	if GameData.tutorial_space:
		return tutorial_walkable(t)
	# 마을에 들어선 뒤로 튜토리얼 공간은 사라진 곳이다 — 돌아갈 길이 없다
	if t.y >= WORLD_H:
		return false
	if not region_open_at(t):
		return false          # 아직 이야기가 닿지 않은 땅
	return VILLAGE_REGION.has_point(t) or ROAD.has_point(t) \
		or GameData.is_tile_owned(t.x, t.y)


# 튜토리얼 숲길 — **길 위**만 걸을 수 있다.
#
# 예전에는 튜토리얼 공간(TUTORIAL_REGION) 전체를 열어 두었다. 울타리는
# 세워 두었지만 그 너머도 통행 가능한 땅이라, 나무 사이 틈으로 빠져나가면
# 숲 바깥 풀밭을 마음대로 걸어 다닐 수 있었다 — 우체부와 말도 섞기 전에
# 길 밖으로 나가 버리는 일이 그래서 생겼다.
#
# 지금은 꺾은선 두 개(본길 · 우회로)가 덮는 칸이 곧 걸을 수 있는 땅이다.
# 상태를 들고 있지 않는다 — 숲을 아직 심지 않았어도, 두 번 심어도 같은 답이
# 나온다 (하네스가 심기 전후로 이걸 묻는다).
func tutorial_walkable(t: Vector2i) -> bool:
	if STORY_CLEARING.has_point(t):
		return true          # 숲 어귀의 빈터 (길이 여기서 넓어진다)
	return on_story_lane(t, STORY_LANE) or on_story_lane(t, STORY_DETOUR)


func on_story_lane(t: Vector2i, lane: Array) -> bool:
	for i in range(lane.size() - 1):
		if story_lane_rect(lane[i], lane[i + 1]).has_point(t):
			return true
	for i in range(1, lane.size() - 1):
		if story_corner_rect(lane[i]).has_point(t):
			return true
	return false


# 마디 하나가 덮는 칸 — 한복판의 -STORY_LANE_BACK ~ +STORY_LANE_FWD.
func story_lane_rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var w: int = STORY_LANE_BACK + STORY_LANE_FWD + 1
	if a.y == b.y:
		return Rect2i(mini(a.x, b.x), a.y - STORY_LANE_BACK,
			absi(b.x - a.x) + 1, w)
	return Rect2i(a.x - STORY_LANE_BACK, mini(a.y, b.y),
		w, absi(b.y - a.y) + 1)


# 꺾이는 자리마다 놓는 **정사각형 한 칸**.
#
# 마디 둘만 겹쳐 두면 안쪽 모서리는 이어지지만 **바깥쪽 모서리가 옴폭 팬다.**
# 그 옴폭한 자리에 선 나무는 제 칸에서 위로 세 칸을 덮어 그리므로, 꺾어져
# 올라가는 길을 통째로 가려 버린다 — 길이 꺾이는 바로 그 순간에 길이
# 안 보인다. 모서리를 길 폭만큼 네모나게 터 준다.
func story_corner_rect(v: Vector2i) -> Rect2i:
	var w: int = STORY_LANE_BACK + STORY_LANE_FWD + 1
	return Rect2i(v.x - STORY_LANE_BACK, v.y - STORY_LANE_BACK, w, w)


# 길이 덮는 사각형 전부 (마디 + 꺾이는 자리). 한 번 받아 두고 훑는 쪽에서 쓴다.
func story_road_rects() -> Array:
	var out: Array = [STORY_CLEARING]
	for lane: Array in [STORY_LANE, STORY_DETOUR]:
		for i in range(lane.size() - 1):
			out.append(story_lane_rect(lane[i], lane[i + 1]))
		for i in range(1, lane.size() - 1):
			out.append(story_corner_rect(lane[i]))
	return out


# 밟혀 다져진 흙이 깔리는 가운데 세 줄 (양옆은 풀 갓길로 남는다)
func story_dirt_rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var w: int = STORY_DIRT_BACK + STORY_DIRT_FWD + 1
	if a.y == b.y:
		return Rect2i(mini(a.x, b.x), a.y - STORY_DIRT_BACK,
			absi(b.x - a.x) + 1, w)
	return Rect2i(a.x - STORY_DIRT_BACK, mini(a.y, b.y),
		w, absi(b.y - a.y) + 1)


# 길 전체를 감싸는 칸 범위 — 카메라가 숲을 어디까지 비출지 여기서 잰다
func story_lane_bounds() -> Rect2i:
	var out := Rect2i()
	var first := true
	for r: Rect2i in story_road_rects():
		out = r if first else out.merge(r)
		first = false
	return out


# 이 칸이 속한 지역이 이미 열렸는가 (지금은 언제나 열려 있다 — 아래 주석 참고)
func region_open_at(t: Vector2i) -> bool:
	for reg: Dictionary in REGIONS:
		var r: Rect2i = reg.rect
		if r.has_point(t):
			return GameData.region_unlocked(str(reg.id))
	return true


# 지금 걸어 다닐 수 있는 세계의 테두리 (지도·미니맵이 이 안만 그린다)
func world_rect() -> Rect2i:
	if GameData.tutorial_space:
		return TUTORIAL_REGION
	return Rect2i(0, 0, MAP_W, WORLD_H)


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


# 개발/테스트용 — 지도를 통째로 연다 (F7).
# ---- 개발자 메뉴 (ESC -> [개발] 개발자 메뉴) ----
#
# 개발용 기능이 F키에만 달려 있었다. 손가락이 기억하는 사람에게는 그게 제일
# 빠르지만, **어떤 기능이 있는지 알 길이 없다** — 코드를 열어 keycode 를
# 훑어야 안다. 같은 일을 하는 단추를 한자리에 늘어놓고 옆에 단축키를 적는다.
#
# 순서는 「자주 쓰는 것부터」가 아니라 **되돌릴 수 없는 것을 아래로**.
# 건너뛰기는 한 번 누르면 그 이야기를 그 세이브에서 다시 못 본다.
func _dev_menu() -> void:
	Sound.play_sfx("sfx_ui")
	var phase := str(GameData.story_phase)
	var walking: bool = story.INTRO_PHASES.has(phase)
	var btns: Array = [
		["아이템 채우기 (F10)", func() -> void:
			dialog.close()
			_dev_fill_stock()],
		["지도 전부 열기 (F7)", func() -> void:
			dialog.close()
			_dev_open_world()],
		["프레임 시간 %s (F3)" % ("끔" if perf_show else "켬"), func() -> void:
			dialog.close()
			perf_show = not perf_show
			if not perf_show and _perf_label != null:
				_perf_label.visible = false
			hud.show_message("[개발] 프레임 시간 %s" % ("켬 — F3으로 끈다" if perf_show else "끔"))],
		["하루 넘기기", func() -> void:
			dialog.close()
			daycycle._fade_next_day(false)],
		# ---- 여기서부터는 되돌릴 수 없다 ----
		["숲길 건너뛰기 (F6)" if walking else "숲길 건너뛰기 — 지났다 (F6)", func() -> void:
			dialog.close()
			story.skip_intro_walk()],
		["스토리 건너뛰기 (F8)", func() -> void:
			dialog.close()
			story.skip_main_story()],
		["닫기", null],
	]
	var body := "지금 이야기: %s\n마우스 자리로 순간이동은 F9다 " % phase \
		+ "(단추로는 자리를 못 집는다).\n\n※ 아래 두 개는 되돌릴 수 없다."
	dialog.open("[개발] 개발자 메뉴", body, btns)


func _dev_open_world() -> void:
	var wr := world_rect()
	var cw: int = GameData.EXPLORE_CHUNK
	for cy in range((wr.end.y + cw - 1) / cw):
		for cx in range((wr.end.x + cw - 1) / cw):
			GameData.explored[Vector2i(cx, cy)] = true
	GameData.zones_open = GameData.ZONE_ORDER.duplicate()
	dirty_walk()
	# 가게는 **짓는 것과 같은 길**로 세운다 (_fill_building). 세계를 다시
	# 만들면 밭도 심은 것도 날아간다.
	var built := 0
	for pid: String in VILLAGE_BUILD_ORDER:
		if GameData.village_built.has(pid):
			continue
		GameData.village_built.append(pid)
		objnode._remove_object(door_tile(VILLAGE_PLOTS[pid].anchor))
		worldgen._fill_building(VILLAGE_PLOTS[pid].anchor, pid)
		built += 1
	queue_redraw()
	hud.show_message("[개발] 지도를 다 열었다 — 안개·확장 구역·가게 %d채" % built, 2.5)


# 개발/테스트용 — 가방을 통째로 채운다.
# 장터에 올려 보거나 요리·조합을 훑어볼 때 손으로 모으고 있을 수 없다.
func _dev_fill_stock() -> void:
	if not GameData.DEV_MODE:
		return
	dialog.close()          # ESC 메뉴에서 눌렀으면 창을 치우고 결과를 보여 준다
	GameData.dev_fill_stock()
	Sound.play_sfx("sfx_ui")
	hud.show_message("[개발] 씨앗·수확물·물건을 %d개씩 채웠다. 도구도 전부 열었다."
		% GameData.DEV_STOCK, 4.0)
	saveio.save_now()
	if Net.is_host():
		netsync._broadcast_stats()
	queue_redraw()


func ui_open() -> bool:
	return story_cutscene or shop.visible or summary.visible or sleep_dialog.visible \
		or fishing_ui.visible or dialog.visible or map_ui.visible \
		or inventory_ui.visible or interior.visible or cave.visible \
		or (shop_room != null and shop_room.visible) \
		or cooking_ui.visible or alchemy_ui.visible or quest_ui.visible or note_ui.visible \
		or (storage_ui != null and storage_ui.visible) \
		or stats_ui.visible or auction_ui.visible \
		or (settings_ui != null and settings_ui.visible) \
		or village._gift_layer != null \
		or (story.story_layer != null and story.story_layer.visible)


# 방(집·동굴·가게) **위에** 겹쳐 뜬 창이 있는가.
#
# 이런 창이 하나라도 열려 있으면 ESC·E는 그 창의 몫이다. 방이 먼저
# 가로채면 가방을 닫으려고 누른 ESC에 게임 메뉴가 떠 버린다 —
# 실제로 「집 안에서 가방 열고 ESC」가 그랬다.
func room_overlay_open() -> bool:
	return dialog.visible or inventory_ui.visible or quest_ui.visible \
		or note_ui.visible or stats_ui.visible or map_ui.visible \
		or shop.visible or cooking_ui.visible or alchemy_ui.visible \
		or desk_ui.visible or sleep_dialog.visible or summary.visible \
		or fishing_ui.visible or auction_ui.visible \
		or (storage_ui != null and storage_ui.visible) \
		or (settings_ui != null and settings_ui.visible)


# 굶주림이 몸을 갉는다. 집 안(지붕 밑)은 안전지대라 체력이 일정선
# 아래로 내려가지 않는다 — 밖에서 굶으면 그대로 쓰러진다.
func _starve_process(delta: float) -> void:
	if Net.is_guest() or not GameData.starving():
		return
	var indoors := interior.visible
	var before := GameData.energy
	GameData.starve_tick(delta, indoors)
	if before > 0.0 and GameData.energy <= 0.0 and not indoors \
			and not day_transitioning:
		hud.show_message("배가 고파 눈앞이 캄캄하다... 정신을 잃었다.", 4.0)
		daycycle._fade_next_day(true)


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
	"forage_ring", "forage_relic", "old_book"]

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
#
# **숲길의 모양은 아래 꺾은선 두 개가 전부다.**
#
# 예전에는 고정된 가로 띠 하나였다 — 한복판이 STORY_LANE_Y 한 줄, 그
# 위아래로 네 줄. 길이 자로 잰 듯 곧아서 「숲을 걸어간다」가 아니라
# 「복도를 지난다」에 가까웠고, 갈림길의 두 갈래는 **둘 다 막다른 길**이라
# 고를 것이 없었다. 지도를 펴 볼 구실로만 서 있던 갈림길이다.
#
# 지금은 점을 차례로 이은 꺾은선이 길의 한복판이다. 우체부의 걸음도,
# 카메라도, 길목 판정도 전부 이 배열만 읽는다 — 길 모양을 바꾸고 싶으면
# 여기 점만 옮기면 되고, 고정 y를 아는 코드는 어디에도 없다.
#
#   STORY_LANE    서쪽 시작 -> 갈림길 -> **지름길** -> 합류 -> 마을 어귀
#   STORY_DETOUR  갈림길 -> 남쪽 골짜기로 크게 돌아 -> 같은 자리에서 합류
#
# 길의 폭은 **여섯 칸**(한복판의 -2 ~ +3), 그중 가운데 **세 줄**이 밟혀
# 다져진 흙이고 위아래 한 줄씩은 풀 갓길이다.
#
# 네 칸·다섯 칸으로도 가 봤는데 둘 다 좁았다. 나무가 제 칸에서 위로 세 칸을
# 덮어 그리는 통에, 걸을 수 있는 폭은 넉넉해도 **눈에 보이는 길**은 두 줄이
# 전부였다 — 나뭇잎 사이로 난 틈처럼 보이지 길로 보이지 않는다.
#
# **남쪽이 한 칸 더 넓은 것도 그 그림 때문이다.** 길 남쪽 가장자리에 선
# 나무는 그 위 두 줄을 가린다. 남쪽 여유가 딱 맞으면 가려지는 줄 하나가
# 다져진 흙길이 되지만, 한 칸을 더 두면 가려지는 것은 풀 갓길뿐이다.
const STORY_LANE_BACK := 2                 # 한복판에서 이만큼 뒤(북)까지가 길
const STORY_LANE_FWD := 3                  # 한복판에서 이만큼 앞(남)까지가 길
const STORY_DIRT_BACK := 1                 # 그중 흙이 깔리는 몫 (한복판의 -1 ~ +1)
const STORY_DIRT_FWD := 1
const STORY_LANE := [
	Vector2i(1, 13 + TUT_DY),    # ① 숲 어귀의 빈터 — 여기서 이야기가 시작한다
	Vector2i(25, 13 + TUT_DY),   # ② 길이 북으로 꺾이는 자리
	Vector2i(25, 6 + TUT_DY),    # ③ 오르막 — 여기서 첫 나무가 쓰러진다
	Vector2i(33, 6 + TUT_DY),    # ④ 갈림길
	Vector2i(41, 6 + TUT_DY),    # ⑤ 지름길: 쓰러진 나무를 넘어 곧장 동쪽으로
	Vector2i(41, 13 + TUT_DY),   # ⑥ 다시 남으로 내려와
	Vector2i(55, 13 + TUT_DY),   # ⑦ 마을 어귀
]
# 우회로는 **지름길의 두 배쯤** 된다. 조금 돌아가는 정도로는 「골랐다」는
# 느낌이 안 난다 — 남쪽 골짜기까지 한참 내려갔다 올라와야 돌아온 보람이 있다.
const STORY_DETOUR := [
	Vector2i(33, 6 + TUT_DY),    # 갈림길에서 갈라져
	Vector2i(33, 24 + TUT_DY),   # 남쪽 골짜기로 깊이 내려가
	Vector2i(45, 24 + TUT_DY),   # 동쪽으로 길게 돌고
	Vector2i(45, 13 + TUT_DY),   # 다시 올라와 본길에 합류한다
]
# ---- 이야기가 시작하는 자리는 숲 **한복판**이 아니라 **어귀**다 ----
#
# 예전에는 길 한가운데에 툭 놓였다. 앞도 뒤도 빽빽한 숲이라, 밝아지자마자
# 나오는 독백 「눈앞에 우거진 숲이 펼쳐져 있다」가 화면과 맞지 않았고 —
# 숲은 눈앞이 아니라 사방에 있었다 — 무엇보다 **여기까지 어떻게 왔는지**에
# 대한 답이 화면 어디에도 없었다. 세계가 만들어지고 사람이 그 안에 얹힌
# 것처럼 보였다.
#
# 이 빈터가 그 답이다. 성긴 나무가 선 들판이 화면 **서쪽 끝까지** 이어져
# 지나온 길이 화면 밖으로 나가고(그래서 등 뒤에 벽이 없다), 흙길은 그
# 들판을 가로질러 동쪽의 빽빽한 숲으로 빨려 들어간다. 그 입구에 표지판이
# 서 있다 — 이 길이 어디로 가는 길인지 화면이 먼저 말해 준다.
const STORY_CLEARING := Rect2i(1, 9 + TUT_DY, 14, 9)
const STORY_TRAIL_SIGN := Vector2i(13, 10 + TUT_DY)   # 숲으로 드는 입구의 낡은 표지판
# 꺾은선 위의 이름난 자리들 (위 배열의 ①·④·⑦ 과 같은 점이어야 한다 —
# 어긋나면 하네스의 STORY_LANE_OK 가 잡아낸다)
const STORY_SPAWN := Vector2i(5, 13 + TUT_DY)    # 빈터 한복판 — 숲을 마주 보고 선다
const STORY_FORK := Vector2i(33, 6 + TUT_DY)     # 숲길이 갈라지는 갈림길 (지도 퀘스트)
const STORY_MERGE := Vector2i(45, 13 + TUT_DY)   # 두 길이 다시 만나는 자리
const STORY_EXIT := Vector2i(55, 13 + TUT_DY)    # 여기 서면 마을로 넘어간다
const STORY_ROCK := Vector2i(51, 13 + TUT_DY)    # 길을 막는 커다란 바위 (퀘스트 5)
# ---- 눈앞에서 쓰러지는 첫 나무가 **서 있는** 자리 ----
#
# **양쪽에서 한 그루씩** 넘어온다. 길이 여섯 칸이라 한 그루로는 길을 다
# 못 덮고, 한쪽에서만 넘어오면 반대쪽에 훤히 트인 틈이 남아 「막혔다」로
# 안 읽힌다. 좌우에서 동시에 넘어와 길 위에서 겹치는 것이 훨씬 세다.
#
# **반드시 길 밖이어야 한다.** 쓰러진 자리는 빈 칸이 되는데, 그 칸이 길
# 위였다면 나무가 넘어지는 순간 길목 옆으로 빠져나갈 틈이 생긴다 —
# 막으려고 쓰러뜨린 나무가 길을 여는 셈이다. (STORY_LANE_OK가 지킨다)
#
# dir: +1 이면 오른쪽으로, -1 이면 왼쪽으로 넘어간다 (길 쪽으로).
const STORY_FALL_TREES := [
	{"at": Vector2i(22, 10 + TUT_DY), "dir": 1, "take": 2},   # 서쪽 그루 — 앞 두 칸을 덮는다
	{"at": Vector2i(29, 10 + TUT_DY), "dir": -1, "take": 1},  # 동쪽 그루 — 남은 칸을 덮는다
]
# 스토리 숲의 가로 폭. 화면(53.6칸)보다 넉넉히 넓어야 카메라가 주인공을 따라
# 옆으로 움직인다. 길(x 18~54)의 동쪽은 들어갈 수 없는 배경 숲이다.
const STORY_FOREST_W := 58
# 메인 스토리 5: 숲 깊은 곳의 수상한 집 (이장에게 물어본 뒤 세상에 드러난다)
const FOREST_HOUSE_ANCHOR := Vector2i(30, 24 + NORTH_PAD)
# 연금술사의 오두막 (메인 스토리 12) — 깊은 숲(deep_rect) 연못 서쪽.
# 소문을 다 모으면 숨은 길과 함께 세상에 놓인다 (worldgen._spawn_alch_house)
const ALCH_HOUSE_ANCHOR := Vector2i(56, 46 + NORTH_PAD)
# 모험가 재민이 처음 서성이는 자리 — **분수 남쪽**이다.
# 예전 값(146, 26+PAD)은 분수 네모(144~147 · 24~27+PAD) **한복판**이라,
# 재민이 물 위에 서 있었다. 광장이 맨 잔디밭이던 시절에는 분수가 눈에
# 안 띄어서 아무도 몰랐다.
const EXPLORER_ARRIVE := Vector2i(146, 29 + NORTH_PAD)
# ---- 길을 막고 선 것들 ----
#
# 자리와 성격을 **여기 한 곳에** 적는다. 예전에는 「가로막는 x 두 개
# (STORY_GATE_XS) × 막히는 y 두 줄 (STORY_GATE_ROWS)」이라, 길이 세로로
# 꺾이는 순간 뜻을 잃는 표였다.
#
#   at    **한복판 칸.** 여기를 가운데로 span 칸이 막히고, 길의 나머지 폭은
#         숲으로 채워 좁힌다 (여섯 줄을 다 뚫게 하면 초반부터 지루하다)
#   axis  "h" 가로 구간 (위아래가 좁아진다) · "v" 세로 구간 (좌우가 좁아진다)
#   span  막는 칸 수. 나무 길목은 다져진 흙 세 줄을 그대로 막고, 바위는
#         두 칸이다 (커다란 바위는 한 덩이에 곡괭이 네 번이라 셋이면 길다)
#   kind  tree 선 나무 / log 쓰러진 나무 (도끼는 같다) / bigrock 커다란 바위
#   role  이야기에서 맡은 몫
const STORY_GATES := [
	# ③ 눈앞에서 쓰러지는 첫 나무 — 처음에는 비어 있다가, 다가서면 **양쪽**
	#    길가의 나무(STORY_FALL_TREES)가 이 자리로 넘어와 겹쳐 눕는다
	{"at": Vector2i(25, 10 + TUT_DY), "axis": "v", "span": 3,
		"kind": "log", "role": "first"},
	# ② 지름길을 가로막은 오래된 등걸 — 넘어가려면 도끼가 필요하다.
	#    누운 나무는 **세로 구간**에만 놓는다 — 가로 구간에 놓으면 몸통이
	#    길과 나란히 누워, 막고 선 것이 아니라 길가에 치워 둔 것으로 보인다
	{"at": Vector2i(41, 9 + TUT_DY), "axis": "v", "span": 3,
		"kind": "log", "role": "short"},
	# ② 우회로 끝, 마을 어귀 직전의 한 그루 — 돌아와도 도끼는 배우게 된다
	{"at": Vector2i(45, 17 + TUT_DY), "axis": "v", "span": 3,
		"kind": "tree", "role": "detour"},
	# ④ 광석이 박힌 커다란 바위 (곡괭이 대목) — 두 길이 합친 뒤라 어느 쪽으로
	#    와도 반드시 만난다
	{"at": Vector2i(51, 13 + TUT_DY), "axis": "h", "span": 2,
		"kind": "bigrock", "role": "rock"},
]
const BIGROCK_HP := 4                      # 커다란 바위는 여러 번 캐야 부서진다
const BIGROCK_STONE := 4                   # 커다란 바위에서 나오는 돌
# 숲길을 막은 그 바위에는 **광석이 박혀 있다.**
#
# 예전에는 돌 넉 장만 떨어졌다. 곡괭이를 처음 쥐는 대목인데 나오는 것이
# 나무를 벨 때와 다를 바 없어서, 「새 도구를 얻었다」가 아니라 「또 치웠다」가
# 됐다. 반짝이는 것이 하나 나오면 곡괭이가 무엇을 하는 도구인지 손이 먼저
# 안다 — 동굴에 들어갈 이유도 여기서 생긴다.
const STORY_ROCK_ORE := 2                  # 그 바위에만 박혀 있는 광석
var story_cutscene := false                # 컷신 중 조작 잠금
var house_preview := false                 # 집터 자리 고르기 (동물의 숲식 범위 표시)
const POSTMAN_STOP_DIST := 168.0           # 걸어와서 멈춰 서는 거리 (5칸쯤 앞)
const POSTMAN_TALK_DIST := 96.0            # 대화키로 말을 걸 수 있는 거리 (세 칸)
const POSTMAN_REFOLLOW_DIST := 420.0       # 이만큼 멀어지면 다시 따라온다
const VILLAGE_EXIT_X := 74                 # 우체부가 빠져나가는 마을 북쪽 길




var _cutscene_idle := 0.0
var _last_explore_tile := Vector2i(-999, -999)


# ---- 퀘스트 5 「마을로 가는 길을 열어보자」 (커다란 바위 / 곡괭이) ----


# ---- 밤 몬스터: 지네 (21시 이후 야외에서 등장, 아침에 사라진다) ----
# 밤늦게까지 밖에서 채집하는 것이 위험해지도록 만드는 요소.

var _shell_cd := 0.0        # 다음 조개가 밀려올 때까지 남은 게임 분
var _rain_forage_cd := 0.0  # 빗속에서 다음 채집물이 돋을 때까지 남은 게임 분
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

# (유니콘의 뿔 엔딩은 걷어냈다 — 엔딩은 꿈속의 배웅(ending_ui) 하나다)


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

# ---- 갇힘 구조대 ----
#
# 세계는 자란다 — 구역이 열리고 닫히고, 건물이 서고, 지형이 바뀐다.
# 그 사이에 **못 지나가는 칸 위에 서 있게 되는** 일이 생기면
# 사방이 막혀 영영 움직일 수 없다 (미해금 구역 안, 맵 밖, 물 위).
# 그래서 1초에 한 번, 서 있는 자리가 성한지 훑어보고 가까운 땅으로 옮긴다.
const RESCUE_EVERY := 1.0
var _rescue_t := 0.0


# t에서 가장 가까운 「설 수 있는 칸」 (없으면 -1,-1)
func nearest_open_tile(t: Vector2i, max_r := 24) -> Vector2i:
	if is_passable(t):
		return t
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := t + Vector2i(dx, dy)
				if is_passable(n):
					return n
	return Vector2i(-1, -1)


func rescue_trapped() -> void:
	if interior.visible or cave.visible or shop_room.visible:
		return
	# 주인공 — 맵 밖·미해금 구역·물 위에 서 있으면 가까운 땅으로
	var pt := player_tile()
	var stuck: bool = pt.x < 0 or pt.y < 0 or pt.x >= MAP_W or pt.y >= MAP_H \
		or not _tile_accessible(pt) or grid[clampi(pt.y, 0, MAP_H - 1)][clampi(pt.x, 0, MAP_W - 1)].ground == "water"
	# **깔고 앉은 것도 갇힌 것이다.**
	#
	# 여기는 「못 가는 지역인가 · 물인가」만 봤다. 그런데 통행을 막는 것은
	# 지형만이 아니라 **그 칸에 놓인 것**이기도 하다(is_passable 이 제일 먼저
	# objects 를 본다) — 집 칸 위에 서면 사방이 다 제 몸이라 한 칸도 못
	# 움직이는데, 이 검사는 멀쩡한 것으로 봤다. 집을 드나드는 대목에서
	# 지붕 위에 끼이던 것이 이것이다.
	#
	# 말을 타고 있을 때는 뺀다 — 그때는 말 칸 위에 서 있는 것이 정상이다.
	if not stuck and not GameData.riding and objects.has(pt):
		stuck = true
	if stuck:
		var to := nearest_open_tile(Vector2i(clampi(pt.x, 1, MAP_W - 2),
			clampi(pt.y, 1, MAP_H - 2)))
		if to.x < 0:
			to = START_TILE
		player.position = Vector2(to.x * TILE + 16, to.y * TILE + 16)
		hud.show_message("길이 없는 곳에 갇혀 있었다 — 가까운 땅으로 나왔다.", 4.0)
	# 마을 사람 — 잠긴 구역이나 맵 밖으로 밀려났으면 제 자리로 돌려보낸다.
	#
	# **튜토리얼 동안에는 한 사람도 건드리지 않는다.**
	#
	# 그때는 세계가 통째로 「닿을 수 없는 땅」이다 — `_tile_accessible` 이
	# 숲길만 참으로 보기 때문이다. 그래서 이 고리가 **마을 사람 전부를
	# 갇힌 것으로 읽고** 제 자리로 돌려보냈는데, NPC_HOME 에 없는 사람은
	# 갈 곳이 START_TILE 이었다. 숲길을 걷는 동안 시골 마을 여섯이 농장
	# 한복판(14, 22)에 모여 있다가, 마을에 도착하는 순간 거기서 제 고장까지
	# **맵을 가로질러 걸어가던 것**이 이것이다. 길이 안 나오는 사람은
	# 15초씩 서 있었고(npc._route_cd), 그게 「가만히 있는 NPC」다.
	if GameData.tutorial_space:
		return
	for n in npcs:
		var nt := Vector2i(int(n.position.x / TILE), int(n.position.y / TILE))
		if nt.x >= 0 and nt.y >= 0 and nt.x < MAP_W and nt.y < MAP_H \
				and _tile_accessible(nt):
			continue
		var home: Vector2i = npc_home_tile(n.id)
		var ht := nearest_open_tile(home)
		if ht.x < 0:
			ht = home
		n.position = Vector2(ht.x * TILE + 16, ht.y * TILE + 16)


# 이 사람을 돌려보낼 자리.
#
# NPC_HOME 은 교진 마을 사람들의 표다 — 고장 사람은 거기 없어서 START_TILE
# (농장 한복판)로 떨어졌다. 제 고장이 있는 사람은 제 고장으로 보낸다.
func npc_home_tile(nid: String) -> Vector2i:
	if NPC_HOME.has(nid):
		return NPC_HOME[nid]
	if HAMLET_OF.has(nid):
		for entry: Array in HAMLETS[HAMLET_OF[nid]].houses:
			if str(entry[2]) == nid:
				return door_tile(entry[0]) + Vector2i(0, 1)
		return HAMLETS[HAMLET_OF[nid]].square
	return START_TILE


func _process(delta: float) -> void:
	var _p := Time.get_ticks_usec() if perf_show else 0
	_bgm_tick(delta)
	GameData.playtime_sec += delta   # 엔딩 통계 리포트용 실제 플레이 시간
	_rescue_t += delta
	if _rescue_t >= RESCUE_EVERY:
		_rescue_t = 0.0
		rescue_trapped()
	if perf_show:
		_p = _pm("갇힘구조", _p)
	saveio.autosave_tick(delta)   # 15분마다 알아서 담는다 (시계는 save_load.gd)
	if perf_show:
		_p = _pm("자동저장", _p)
	story._story_update(delta)
	story._fisher_update(delta)
	story._move_update(delta)
	story._forest_update(delta)
	story._spear_update(delta)
	story._movein_update(delta)
	story._story6_update(delta)
	story._story7_update(delta)
	story._story8_update(delta)
	story._story9_update(delta)
	story._story10_update(delta)
	story._story11_update(delta)
	story._story12_update(delta)
	story._story13_update(delta)
	story._story14_update(delta)
	story._story15_update(delta)
	story._story16_update(delta)
	story._story17_update(delta)
	story._story18_update(delta)
	story._story19_update(delta)
	story._story20_update(delta)
	story._fisher_home_update(delta)
	story._kitchen_update(delta)
	story._settler_update(delta)
	if perf_show:
		_p = _pm("이야기", _p)
	if house_preview:
		overlay.queue_redraw()   # 집터 프리뷰가 마우스를 따라다닌다
	_work_lock = maxf(_work_lock - delta, 0.0)
	toolwork._update_hit_fx(delta)
	objnode._update_tree_fall(delta)
	var _pt := Time.get_ticks_usec() if perf_show else 0
	objnode._update_object_fade(delta)
	if perf_show:
		_perf["fade"] = Time.get_ticks_usec() - _pt
		_pt = _pm("비침", _pt)
	# 화면 둘레 것만 노드로 세워 둔다 (칸이 바뀔 때만 도는 일이라 싸다)
	objnode._stream_nodes()
	if perf_show:
		_perf["stream"] = Time.get_ticks_usec() - _pt
		_pt = _pm("스트림", _pt)
	objnode._drain_spawn_queue()   # 세우는 일은 프레임마다 몇 개씩만
	if perf_show:
		_perf["spawn"] = Time.get_ticks_usec() - _pt
		_p = _pm("세우기", _pt)
	if GameData.story_phase == "done":
		story._grandpa_update(delta)
	for ft in float_texts:
		ft.t += delta
	float_texts = float_texts.filter(func(ft: Dictionary) -> bool: return ft.t < 1.3)
	if not ui_open() or interior_only_open():
		if not Net.is_guest():
			# 시간은 호스트/솔로만 진행 (게스트는 동기화 수신)
			GameData.minutes += delta * MIN_PER_SEC
			GameData.hunger_tick(delta * MIN_PER_SEC)   # 시간이 흐르면 배가 꺼진다
			if GameData.minutes >= GameData.DAY_END and not day_transitioning:
				daycycle._fade_next_day(true)
		water_timer += delta
		if water_timer > 0.8:
			water_timer = 0.0
			water_frame = 1 - water_frame
		lm_timer += delta
		if lm_timer > 1.0 / LANDMARK_FPS:
			lm_timer = 0.0
			lm_frame += 1
			objnode._tick_landmarks()
		_growth_timer += delta
		if _growth_timer >= 0.7:
			farming._growth_tick(_growth_timer * MIN_PER_SEC)
			_growth_timer = 0.0
			if perf_show:
				_p = _pm("자람", _p)
		# 해변: 게임 시간 10~15분마다 조개가 하나씩 밀려온다 (상한에서 멈춘다)
		if GameData.sea_open and not Net.is_guest():
			toolwork._weapon_cd = maxf(0.0, toolwork._weapon_cd - delta)
			_shell_cd -= delta * MIN_PER_SEC
			if _shell_cd <= 0.0:
				_shell_cd = GameData.shell_respawn_minutes()
				worldgen._tick_beach()
				if perf_show:
					_p = _pm("조개", _p)
		# 비 오는 날은 걷는 동안에도 풀과 열매가 계속 돋는다
		if not Net.is_guest() and weather_now() in [GameData.WEATHER_RAIN,
				GameData.WEATHER_STORM]:
			_rain_forage_cd -= delta * MIN_PER_SEC
			if _rain_forage_cd <= 0.0:
				_rain_forage_cd = RAIN_FORAGE_MINUTES
				worldgen._tick_rain_forage()
				if perf_show:
					_p = _pm("비채집", _p)
		actions._update_mouse_target()
		fishing._update_fishing(delta)
		if perf_show:
			_p = _pm("조준", _p)
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
	# 체력은 동굴 밖에서 천천히 회복된다 (요리를 먹으면 즉시 회복).
	# 다만 굶고 있으면 회복은커녕 계속 깎인다.
	if not cave.visible and not GameData.starving():
		GameData.energy = minf(GameData.ENERGY_MAX, GameData.energy + delta * 2.0)
	_starve_process(delta)
	renderer._update_particles(delta)
	daycycle._update_night_mobs(delta)
	objnode._update_tree_fade()
	story._update_u_intro()
	if perf_show:
		_p = _pm("효과", _p)
	netsync._net_process(delta)
	if perf_show:
		_p = _pm("그물", _p)
	daycycle._update_night()
	hud.refresh()
	if perf_show:
		_p = _pm("HUD", _p)
		_perf_tick(delta)
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
		# 접속 완료 전에는 조작 금지 — 다만 기다리다 그만둘 수는 있어야 한다
		if event.is_action_pressed("ui_cancel"):
			_back_to_title()
		return
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
			# 겹쳐 뜬 창은 **위에 있는 것부터 하나씩** 닫는다.
			# 한 번에 다 닫아 버리면 가방을 닫으려던 ESC에 뒤에 있던
			# 상점 창까지 같이 사라진다.
			var stack: Array = [settings_ui, storage_ui, stats_ui, note_ui,
				quest_ui, inventory_ui, map_ui, summary, shop]
			for w: Variant in stack:
				if w != null and bool(w.visible):
					w.close()
					get_viewport().set_input_as_handled()
					return
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
	# 개발/테스트: F10 — 가방을 10000개씩 채운다 (DEV_MODE에서만)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F10 and GameData.DEV_MODE:
		_dev_fill_stock()
		return
	# 개발/테스트: F9 — **마우스 자리로 순간이동** (DEV_MODE에서만)
	#
	# 맵이 120x90이라 걸어서 구석을 확인하는 데만 몇 분이 걸린다. 지형을
	# 손볼 때는 「거기까지 가는 일」이 작업 시간을 다 먹는다. 물·절벽처럼
	# 멀리 있는 것을 고칠 때 이 한 줄이 없으면 확인을 안 하게 된다.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F9 and GameData.DEV_MODE:
		var w: Vector2 = world.get_global_mouse_position()
		var tx := clampi(int(w.x / TILE), 0, MAP_W - 1)
		var ty := clampi(int(w.y / TILE), 0, MAP_H - 1)
		player.position = Vector2(tx * TILE + 16, ty * TILE + 16)
		hud.show_message("[개발] (%d, %d) 로 이동" % [tx, ty], 1.5)
		return
	# 개발/테스트: F7 — **지도를 통째로 연다** (DEV_MODE에서만)
	#
	# 지형을 손볼 때 제일 오래 걸리는 일이 「거기까지 가서 안개를 걷는 것」이다.
	# 미니맵은 밟아 본 청크만 그리므로, 새로 넓힌 땅을 확인하려면 구석구석
	# 걸어 다녀야 한다. F9(순간이동)로 날아가도 안개는 한 칸씩만 걷힌다.
	#
	# 세 가지를 한 번에 연다:
	#   ① 탐사 안개 — 세계 전체 청크를 밟은 것으로 친다
	#   ② 확장 구역 — 메인 스토리 4로 열리는 옛 마을 동쪽 땅
	#   ③ 마을 부지 — 아직 안 지은 가게를 전부 세운다
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F7 and GameData.DEV_MODE:
		_dev_open_world()
		return
	# 개발/테스트: F3 — 프레임 시간 재기 (끊길 때 어디가 먹는지 본다)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F3 and GameData.DEV_MODE:
		perf_show = not perf_show
		if not perf_show and _perf_label != null:
			_perf_label.visible = false
		hud.show_message("[개발] 프레임 시간 %s" % ("켬 — F3으로 끈다" if perf_show else "끔"))
		return
	# 개발/테스트: F8 — 메인 스토리 건너뛰기
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F8 and GameData.DEV_MODE:
		story.skip_main_story()
		return
	# 개발/테스트: F6 — **숲길만** 건너뛰기 (우체부를 따라 마을까지 걷는 대목)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F6 and GameData.DEV_MODE:
		story.skip_intro_walk()
		return
	if event.is_action_pressed("ui_cancel"):
		# 게임 메뉴: 함께하기 방 코드 + 저장 후 타이틀로.
		# (방 코드를 화면에 늘 띄우면 눈에 거슬려서 여기서 꺼내 본다)
		Sound.play_sfx("sfx_ui")
		var body := "타이틀 화면으로 돌아갈까?\n(진행 상황은 자동 저장된다)"
		# 설정은 여기서 바로 연다 — 소리 하나 줄이자고 농장을 나갔다 올 수 없다
		var btns := [["설정", func() -> void:
				dialog.close()
				settings_ui.open()],
			["저장 후 타이틀로", _back_to_title], ["계속하기", null]]
		var rcode := str(Net.rooms.code) if Net.is_host() and Net.rooms != null else ""
		if rcode != "":
			body = "방 코드   %s\n친구에게 알려 주면 이 농장으로 들어온다.\n\n%s" \
				% [rcode, body]
			btns.push_front(["코드 복사", func() -> void:
				DisplayServer.clipboard_set(rcode)
				hud.show_message("방 코드 %s — 복사했다!" % rcode)])
		elif Net.is_guest():
			body = "친구의 농장에서 함께 일하는 중이다.\n\n%s" % body
		if GameData.DEV_MODE:
			# 테스트용 — 출시 전에 DEV_MODE를 끄면 이 단추도 같이 사라진다.
			# 단추를 여기 죄다 늘어놓으면 「계속하기」가 저 아래로 밀려서,
			# 정작 늘 쓰는 단추를 찾느라 눈이 헤맨다 — 한 겹 더 들어간다
			btns.push_front(["[개발] 개발자 메뉴", func() -> void:
					dialog.close()
					_dev_menu()])
		dialog.open("게임 메뉴", body, btns)
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
	elif event.is_action_pressed("talk"):
		# 대화키(F)는 말 걸기가 먼저다. 앞에 사람도 가축도 없고 **탈 말이
		# 실제로 곁에 있을 때만** 같은 키가 말 타기/내리기로 넘어간다.
		# (그냥 넘기면 말을 걸려고 F를 누르며 걷는 내내 「아직 말이 없다」가 뜬다)
		if not actions.talk() and riding.can_toggle():
			riding.toggle_ride()
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
	"deco_fountain", "deco_lamp", "house", "art_block",
	# 랜드마크는 화면 열두 칸이 넘는다 — 뒤로 걸어 들어가면 주인공이
	# 통째로 사라지므로 반드시 비쳐야 한다
	"landmark_greattree", "landmark_falls", "deco_cairn"]
const FADE_ALPHA := 0.35
const FADE_SPEED := 6.0

var _fade_a := {}     # Vector2i -> 지금 알파

# ---- 프레임 시간 재기 (F3) ----
#
# 끊김의 원인을 **짐작으로** 여러 번 고쳤다. 세 번은 맞았고 그때마다
# 「이번엔 됐겠지」였다. 짐작을 그만두려면 재야 한다.
#
# F3 을 누르면 한 프레임이 어디서 몇 밀리초를 쓰는지 화면 왼쪽 위에 뜬다.
# 16.7ms 가 60프레임의 예산이다 — 어느 줄이 그 예산을 먹는지 보면 된다.
var perf_show := false
var _perf := {"draw": 0, "fade": 0, "stream": 0, "spawn": 0}
# 하루가 넘어갈 때 **한 번** 터지는 값 — 평균에 섞으면 사라져 버린다.
# 마지막으로 넘어간 하루가 어디서 몇 밀리초를 썼는지 그대로 들고 있는다
var _perf_day := {"total": 0, "farm": 0, "grow": 0, "spawn": 0, "save": 0}
var _perf_n := 0
var _perf_acc := {"draw": 0, "fade": 0, "stream": 0, "spawn": 0}
var _perf_worst := 0.0
var _perf_label: Label = null

# ---- 한 번씩 터지는 프레임을 잡는 그물 ----
#
# 「스크립트 전체 566ms 인데 최악 5.6ms」가 같이 떴다. 둘 다 맞을 수는 없다.
# 최악을 **서른 프레임마다** 지우고 있었기 때문이다 — 180프레임이면 0.17초다.
# 튀는 프레임은 몇 초에 한 번 오니까 거의 언제나 지워진 뒤였다.
#
# 창을 3초로 늘리고, 그 창 안에서 **토막마다 가장 오래 걸린 값**을 들고 있는다.
# 평균은 튀는 것을 감춘다 — 끊김을 볼 때 봐야 하는 건 최댓값이다.
const PERF_WIN := 3.0
var _perf_win_t := 0.0
var _perf_max := {}          # 토막 이름 -> 창 안에서 가장 오래 걸린 usec
var _perf_max_show := {}     # 화면에 띄우고 있는 판 (창이 넘어갈 때 갈린다)
var _perf_proc_worst := 0.0  # 엔진이 잰 _process 시간의 창 안 최댓값
var _perf_worst_show := 0.0
var _perf_proc_show := 0.0


# 토막 하나를 재고, 다음 토막의 시작 시각을 돌려준다.
# perf_show 가 꺼져 있으면 아무 데서도 안 불린다
func _pm(pname: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	var dt := now - t0
	if dt > int(_perf_max.get(pname, 0)):
		_perf_max[pname] = dt
	return now


# 이 오브젝트 그림이 플레이어를 덮고 있는가 (그리고 앞에 그려지는가)


# 물의 깊이를 잰다 — 뭍에서 몇 걸음(여덟 방향)인지.
#
# 물을 두 장(얕은 물·깊은 물)으로만 그렸더니 연못 한가운데에 검푸른
# **직사각형**이 오려 붙은 것처럼 떴다. 깊이가 두 단뿐이라 그 경계가 타일
# 변을 따라 그대로 보인 것이다. 단을 다섯으로 늘리고 한 단을 반 톤으로
# 낮추면 경계가 눈에 안 걸리고 물이 가운데로 갈수록 깊어지는 것처럼 읽힌다.
#
# 여덟 방향으로 재는 이유 — 네 방향으로만 재면 깊이 띠가 마름모로 각진다.
# 앞뒤 두 번 훑는 체스판 거리(chamfer)면 한 번에 맵 전체가 채워진다.
const WATER_LV := 8

func rebuild_water_levels() -> void:
	water_dist = []
	if grid.is_empty():
		return
	var big := 99
	for y in MAP_H:
		var row := PackedByteArray()
		row.resize(MAP_W)
		for x in MAP_W:
			row[x] = 0 if grid[y][x].ground != "water" else big
		water_dist.append(row)
	# 앞으로 한 번(왼위 이웃), 뒤로 한 번(오른아래 이웃)
	for y in MAP_H:
		for x in MAP_W:
			if water_dist[y][x] == 0:
				continue
			var d: int = water_dist[y][x]
			for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= MAP_W or ny >= MAP_H:
					continue
				d = mini(d, water_dist[ny][nx] + 1)
			water_dist[y][x] = mini(d, big)
	for y in range(MAP_H - 1, -1, -1):
		for x in range(MAP_W - 1, -1, -1):
			if water_dist[y][x] == 0:
				continue
			var d: int = water_dist[y][x]
			for o: Vector2i in [Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 0)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= MAP_W or ny >= MAP_H:
					continue
				d = mini(d, water_dist[ny][nx] + 1)
			water_dist[y][x] = mini(d, big)
	# 물길이 바뀌면 깊이도 물가도 다 바뀐다 — 그려 둔 것을 통째로 버린다.
	# (지도를 짓고 나서도, 세이브를 읽고 나서도 여기를 지나간다)
	dirty_all()
	dirty_walk()   # 물이 바뀌었으면 걸을 수 있는 땅도 바뀐다


# ---- 그리기 캐시 버리기 ----
#
# 가장자리는 **이웃 여덟 칸**을 보고 그린다. 그러니 한 칸이 바뀌면 그 칸
# 하나가 아니라 둘레 아홉 칸이 같이 상한다. 여기를 한 칸으로 줄이면
# 갈아엎은 밭 언저리에 옛 잔디 테두리가 남는다.
func dirty_tile(x: int, y: int) -> void:
	if _dc_kind.is_empty():
		return
	for yy in range(maxi(0, y - 1), mini(MAP_H, y + 2)):
		var b := yy * MAP_W
		for xx in range(maxi(0, x - 1), mini(MAP_W, x + 2)):
			_dc_kind[b + xx] = DC_NONE


# 텍스처 참조까지 비우지는 않는다 — 종류가 DC_NONE 이면 어차피 다시 셈해서
# 덮어쓴다. 여기서 하는 일은 136KB 한 판을 0으로 미는 것뿐이라, 반복문
# 안에서 불러도 부담이 없다
func dirty_all() -> void:
	var n := MAP_W * MAP_H
	if _dc_kind.size() != n:
		_dc_kind.resize(n)
		_dc_water.resize(n)
		_dc_base.resize(n)
		_dc_edge.resize(n)
		_dc_tall.resize(n)
		_dc_tier.resize(n)
	_dc_kind.fill(DC_NONE)


func _water_level(x: int, y: int) -> int:
	if water_dist.is_empty():
		return 0
	return clampi(water_dist[y][x] - 1, 0, WATER_LV - 1)


func level_at(x: int, y: int) -> int:
	if terrain_level.is_empty() or x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
		return 0
	return terrain_level[y][x] & 7


func is_ramp(x: int, y: int) -> bool:
	if terrain_level.is_empty() or x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
		return false
	return (terrain_level[y][x] & 8) != 0


# 벼랑 밑 — **위쪽 땅에 붙은 칸**으로는 들어갈 수 없다. 그 칸이 곧 바위면이
# 서 있는 자리다. 오르내리는 길은 오르막뿐이다.
#
# 통행을 「칸에서 칸으로 건널 수 있는가」로 두면 검사할 자리가 사방으로
# 늘어난다. 벼랑 밑 한 줄을 막아 두면 애초에 그 자리에 설 수가 없어서,
# 아래에서 위로 붙는 일 자체가 없다 — 검사는 칸 하나로 끝난다
func _cliff_foot(x: int, y: int) -> bool:
	if terrain_level.is_empty() or is_ramp(x, y):
		return false
	var lv := level_at(x, y)
	if level_at(x, y - 1) > lv or level_at(x, y + 1) > lv \
			or level_at(x - 1, y) > lv or level_at(x + 1, y) > lv:
		return true
	# ---- 벼랑면이 **두 칸**이 됐다 ----
	#
	# 높이를 느끼게 하려고 바위벽을 아래로 한 칸 더 늘였는데, 그 둘째 칸은
	# 여태 걸을 수 있는 땅이었다 — 벽 한복판에 사람이 박혀 서 있었다.
	# 「올라가지는 경우」가 이것이다. 그림이 벽이면 통행도 벽이라야 한다.
	#
	# **북쪽으로만** 본다. 옆이나 남쪽을 보는 벼랑은 면이 좁은 띠로만
	# 드러나므로(cliffPx) 그림이 아래 칸까지 내려오지 않는다.
	# 오르막 밑은 뺀다 — 계단은 벼랑을 끊고 낸 자리다
	if is_ramp(x, y - 1):
		return false
	return level_at(x, y - 1) == lv and level_at(x, y - 2) > lv


# 바닥 종류를 **숫자**로. 경계를 가릴 때 칸마다 여덟 이웃을 문자열로
# 견주면 그 비교만 수만 번이라, 줄을 읽어 둘 때 한 번만 표를 뒤진다
const K_GRASS := 0
const K_WATER := 1
const K_SAND := 2
const K_YARD := 3
const K_PATH := 4
const KIND_OF := {"water": K_WATER, "sand": K_SAND, "yard": K_YARD, "path": K_PATH}

# 한 줄어치 바닥 종류. 맵 밖은 **물로 친다** — 세계의 끝은 바다이고,
# 가장자리 칸의 물가가 끊겨 보이면 거기가 세계의 끝이라는 게 드러난다
func _row_kind(y: int, xa: int, n: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(n)
	# 맵 밖은 **물로 친다** — 세계의 끝은 바다이고, 가장자리 칸의 물가가
	# 끊겨 보이면 거기가 세계의 끝이라는 게 드러난다. 다만 **켜는 안쪽을
	# 따라간다**: 0으로 두면 세계 둘레에 있지도 않은 벼랑이 한 바퀴 선다
	var cy: int = clampi(y, 0, MAP_H - 1)
	var off_y: bool = y != cy
	var row: Array = grid[cy]
	var lv: PackedByteArray = terrain_level[cy] if not terrain_level.is_empty() \
		else PackedByteArray()
	for i in n:
		var x: int = xa + i
		var cx: int = clampi(x, 0, MAP_W - 1)
		# 바닥 종류(0~2비트) · 켜(3~5비트) · 오르막(6비트)을 한 바이트에.
		# 벼랑 경계도 물가와 같은 이웃 여덟 칸을 보므로, 따로 훑으면
		# 격자를 또 여덟 번 뒤지게 된다
		var b: int = K_WATER if (off_y or x != cx) else KIND_OF.get(row[cx].ground, K_GRASS)
		if not lv.is_empty():
			var t: int = lv[cx]
			b |= ((t & 7) << 3) | ((t & 8) << 3)
		out[i] = b
	return out


# ---- 렌더링 ----


# 한 칸이 무엇을 그리는지 **한 번만** 셈해서 담아 둔다.
#
# 여기 적힌 일이 전부 프레임마다 돌던 것이다 — 이웃 여덟 견주기, _hash01
# 네댓 번, 그리고 "water_%d_%d_%d" 같은 **글자 짜맞추기와 사전 뒤지기**.
# 보이는 칸이 구백이면 프레임마다 구백 벌이었다. 지도는 밭을 갈 때 말고는
# 안 바뀌니, 한 번 셈해서 텍스처 참조 그대로 들고 있으면 된다.
func _dc_fill(x: int, y: int, ci: int, i: int, above: PackedByteArray,
		cur: PackedByteArray, below: PackedByteArray, grass_prefix: String) -> int:
	var ground: String = grid[y][x].ground
	var kc: int = cur[i]
	# 이웃 여덟 칸 (1=북 2=남 4=서 8=동 16=북서 32=북동 64=남서 128=남동)
	var kn: int = above[i]
	var ks: int = below[i]
	var kw: int = cur[i - 1]
	var ke: int = cur[i + 1]
	var knw: int = above[i - 1]
	var kne: int = above[i + 1]
	var ksw: int = below[i - 1]
	var kse: int = below[i + 1]
	# **종류만 뽑아 쓴다.** 이 바이트에는 켜(3~5비트)와 오르막(6비트)이
	# 같이 들어 있어서, 통째로 K_WATER 와 견주면 켜가 0이 아닌 칸에서는
	# 물이 물로 안 읽힌다. _build_levels 가 능선 북쪽을 전부 켜 1로
	# 깔아 두므로 **지도 거의 전부가** 그랬다 — 물가도 길도 모래도
	# 가장자리가 통째로 안 그려지던 진짜 이유다.
	var gc := kc & 7
	var gn := kn & 7
	var gs := ks & 7
	var gw := kw & 7
	var gek := ke & 7
	var gnw := knw & 7
	var gne := kne & 7
	var gsw := ksw & 7
	var gse := kse & 7
	var el: Array[Texture2D] = []
	var kind := DC_FIXED
	if (kc & 64) != 0:
		# 오르막 — 벼랑을 깎아 낸 길. 밟혀 다져진 흙에 디딤돌을 놓았다
		_dc_base[ci] = tex["ramp_%d" % (int(_hash01(x * 13, y * 3) * 3.0) % 3)]
		# 계단이 **시작하고 끝나는** 자리 — 돌이 타일 변에서 딱 끊기면
		# 바닥과 맞붙어 오려 붙인 것으로 보인다. 끝머리 한두 단은 흙에
		# 묻히고 밟혀 뭉개진 것이 맞다 (make_ground.js 의 treadPx)
		var rc := 0
		if (kn & 64) == 0: rc |= 1
		if (ks & 64) == 0: rc |= 2
		if (kw & 64) == 0: rc |= 4
		if (ke & 64) == 0: rc |= 8
		if (knw & 64) == 0: rc |= 16
		if (kne & 64) == 0: rc |= 32
		if (ksw & 64) == 0: rc |= 64
		if (kse & 64) == 0: rc |= 128
		if rc != 0:
			el.append(edge_tex["tread"][rc])
	elif ground == "dock":
		kind = DC_DOCK
	elif ground == "sand":
		# 모래사장 — 물결이 남긴 잔결에 조개·조약돌이 쓸려 와 있다.
		# 색 한 판에 점 세 개로 칠했더니 새로 그린 바닥들 옆에서
		# 혼자 종이처럼 매끈했다
		_dc_base[ci] = tex["sand_%d" % (int(_hash01(x * 5, y * 11) * 3.0) % 3)]
	elif ground == "water":
		# 물가에서 멀수록 깊다 — 여덟 단, 한 단이 0.42톤.
		# 판(0~2)은 칸마다 골라 쓴다. 한 판만 깔면 잔물결이 같은
		# 자리마다 찍혀 물 위에 바둑판이 뜬다.
		# 깊이와 판은 여기서 굳고, **장**만 그릴 때 고른다
		kind = DC_WATER
		_dc_water[ci] = _water_level(x, y) * 3 \
			+ int(_hash01(x * 3 + 1, y * 7 + 5) * 3.0) % 3
	elif ground == "soil":
		kind = DC_SOIL
	elif ground == "path":
		_dc_base[ci] = tex["path_%d" % (int(_hash01(x * 7, y * 3) * 3.0) % 3)]
	elif ground == "yard":
		# 집 둘레의 다져진 흙 — 길처럼 깐 게 아니라 밟혀서 풀이 죽은 자리
		_dc_base[ci] = tex["yard_%d" % (int(_hash01(x * 9, y * 5) * 3.0) % 3)]
	else:
		_dc_base[ci] = tex[grass_prefix + str(int(_hash01(x, y) * 3.0) % 3)]
		# 흙길과 풀이 만나는 자리는 직선으로 끊기면 종이처럼 보인다.
		# 길 쪽에서 자갈이 조금 흘러나온 것처럼 톱니 가장자리를 덧그린다
		if gn == K_PATH:
			el.append(tex["path_edge_n"])
		if gs == K_PATH:
			el.append(tex["path_edge_s"])
		if gw == K_PATH:
			el.append(tex["path_edge_w"])
		if gek == K_PATH:
			el.append(tex["path_edge_e"])
	# 물가 — 물과 뭍의 경계. 물 칸에는 여울을, 뭍 칸에는 젖은 흙과
	# 둑을. 이게 없으면 연못이 파란 사각형을 오려 붙인 것처럼 보인다
	if ground != "dock":
		var wet := gc == K_WATER
		var code := 0
		if (gn == K_WATER) != wet: code |= 1
		if (gs == K_WATER) != wet: code |= 2
		if (gw == K_WATER) != wet: code |= 4
		if (gek == K_WATER) != wet: code |= 8
		if (gnw == K_WATER) != wet: code |= 16
		if (gne == K_WATER) != wet: code |= 32
		if (gsw == K_WATER) != wet: code |= 64
		if (gse == K_WATER) != wet: code |= 128
		if code != 0:
			# 모래에 닿는 물은 파도가 밀려드는 자리다 — 둑도 그늘도 없다
			var wk: String
			var wv := int(_hash01(x * 17 + 2, y * 5 + 9) * 3.0) % 3
			if wet:
				wk = "surf" if (gn == K_SAND or gs == K_SAND
					or gw == K_SAND or gek == K_SAND) else "shoal_%d" % wv
			else:
				wk = "beach" if gc == K_SAND else "shore_%d" % wv
			el.append(edge_tex[wk][code])
		# 잔디와 모래·마당의 경계 — 날린 모래도 밟혀 번진 흙도
		# 풀밭으로 파고든다. 안 그리면 여기가 자로 자른 계단으로 남는다
		if gc != K_SAND:
			var sc := 0
			if gn == K_SAND: sc |= 1
			if gs == K_SAND: sc |= 2
			if gw == K_SAND: sc |= 4
			if gek == K_SAND: sc |= 8
			if gnw == K_SAND: sc |= 16
			if gne == K_SAND: sc |= 32
			if gsw == K_SAND: sc |= 64
			if gse == K_SAND: sc |= 128
			if sc != 0:
				el.append(edge_tex["dune"][sc])
		# 계단 앞뒤 — 돌 조각과 닳은 흙이 바닥으로 흘러나온다.
		# 계단 쪽(tread)과 바닥 쪽(trail)이 양쪽에서 마중 나가야
		# 회색 돌과 갈색 흙이 한 줄에서 안 갈린다
		if (kc & 64) == 0:
			var tc := 0
			if (kn & 64) != 0: tc |= 1
			if (ks & 64) != 0: tc |= 2
			if (kw & 64) != 0: tc |= 4
			if (ke & 64) != 0: tc |= 8
			if (knw & 64) != 0: tc |= 16
			if (kne & 64) != 0: tc |= 32
			if (ksw & 64) != 0: tc |= 64
			if (kse & 64) != 0: tc |= 128
			if tc != 0:
				el.append(edge_tex["trail"][tc])
		if gc != K_YARD:
			var yc := 0
			if gn == K_YARD: yc |= 1
			if gs == K_YARD: yc |= 2
			if gw == K_YARD: yc |= 4
			if gek == K_YARD: yc |= 8
			if gnw == K_YARD: yc |= 16
			if gne == K_YARD: yc |= 32
			if gsw == K_YARD: yc |= 64
			if gse == K_YARD: yc |= 128
			if yc != 0:
				el.append(edge_tex["trod"][yc])
	# 벼랑 — 높이가 다른 두 땅이 만나는 자리. 면은 **아래쪽 칸**에
	# 드리우고(위에서 내려다보면 벽이 차지하는 자리가 거기다),
	# 마루는 위쪽 칸에 얹는다. 오르막끼리 맞닿은 자리만 경계에서
	# 빼면 그 사이로 길이 뚫리고 양옆에는 바위벽이 남는다
	# 평지가 대부분이라 **먼저 싸게 가른다** — 이웃 여덟의 켜가 다
	# 나와 같으면 여기는 볼 것이 없다
	var lvb: int = kc & 56
	if (kn & 56) != lvb or (ks & 56) != lvb or (kw & 56) != lvb \
		or (ke & 56) != lvb or (knw & 56) != lvb or (kne & 56) != lvb \
		or (ksw & 56) != lvb or (kse & 56) != lvb:
		var ramp: bool = (kc & 64) != 0
		var nbuf: Array[int] = [kn, ks, kw, ke, knw, kne, ksw, kse]
		var up := 0
		var dn := 0
		for b in 8:
			var nb: int = nbuf[b]
			if ramp and (nb & 64) != 0:
				continue          # 오르막끼리는 경계가 아니다
			# **계단 쪽으로는 벽을 이어 붙이지 않는다.**
			#
			# 대각선 이웃이 오르막이면 그 칸은 (오르막끼리 경계가 아니므로)
			# 벽을 안 세운다. 그런데 이쪽은 「저 대각선이 높다」고 읽어
			# 벽을 끝까지 세우니, 계단 옆에서 두 칸 높이 벽이 직각으로 뚝
			# 잘렸다. 그 비트를 빼면 벽이 어깨를 지고 계단 쪽으로 흘러내린다
			if b >= 4 and (nb & 64) != 0:
				continue
			var nlb: int = nb & 56
			if nlb > lvb:
				up |= 1 << b
			elif nlb < lvb:
				dn |= 1 << b
		# **물 위에는 벼랑을 안 그린다.**
		#
		# 벼랑면은 「위 칸이 더 높다」는 표시로 **아랫 칸에** 그린다.
		# 그런데 그 아랫 칸이 물이면, 호수 한복판에 돌담 토막이
		# 떠 있는 꼴이 된다 — 폭포골처럼 켜가 다른 두 못이 나란히
		# 있는 데서 이게 그대로 보였다. 물에 잠긴 벼랑은 안 보이는 게
		# 맞다 (보이는 건 수면이다). 마루선(brink)도 마찬가지다.
		# **모서리로만 닿은 자리에는 벽을 안 세운다.**
		#
		# up 은 이웃 여덟을 본다. 대각선 하나만 높아도 벼랑면을 그렸는데,
		# 면이 한 칸일 때는 귀퉁이에 자국이 조금 남는 정도였다. 두 칸이
		# 되고 나서는 그게 **온전한 벽 한 장**이 된다:
		#   · 들판 한복판에 회색 실이 토막토막 흩어졌다 (대지 옆구리의
		#     대각선 칸마다 벽이 한 장씩 섰다)
		#   · 계단 발치의 걸을 수 있는 칸이 벽으로 덮여 계단이 묻혔다
		# 통행 규칙(_cliff_foot)은 **네 방향만** 본다. 그림도 거기 맞춘다 —
		# 못 서는 칸에만 벽이 서야 벽이 벽으로 읽힌다.
		# (귀퉁이는 이웃한 네 방향 칸들이 저마다 그리는 벽이 덮어 준다.
		#  꼴 값은 여덟 비트 그대로 넘겨야 모양이 맞는다)
		# 남쪽 땅이 더 높으면 그 벼랑은 **등을 돌리고 있다.**
		#
		# 위에서 비스듬히 내려다보는 화면이라, 내 남쪽이 높으면 그 벼랑면은
		# 저쪽을 향해 서 있어 보이지 않는다 (보이는 건 그 땅의 윗면이다).
		# 그래서 한동안 남쪽만 높은 칸(비트 2)을 아예 뺐다 — 그러자 대지
		# **뒤쪽이 배경 잔디와 구분되지 않았다.** 높은 땅과 낮은 땅이 같은
		# 잔디라, 사이에 아무 표시가 없으면 그냥 한 벌판으로 보인다.
		#
		# 안 보이는 건 벽의 면이지 벽이 아니다. 그 자리에는 접지 그늘과
		# 흘러내린 돌이 남는다 (make_ground.js 의 backFoot). 네 방향은
		# 다시 다 그리고, 대각선만 뺀다 (1 | 2 | 4 | 8 = 15) —
		# 통행 규칙(_cliff_foot)도 네 방향만 보므로 그림과 발이 맞는다.
		if gc != K_WATER:
			if (up & 15) != 0:
				# 두 칸 높이라 딴 통에 담는다 (그리는 크기가 다르다)
				_dc_tall[ci] = edge_tex["cliff_%d"
					% (int(_hash01(x * 11, y * 7) * 3.0) % 3)][up]
			if dn != 0:
				el.append(edge_tex["brink"][dn])
	_dc_kind[ci] = kind
	_dc_edge[ci] = el if not el.is_empty() else null
	_dc_tier[ci] = mini((kc & 56) >> 3, TIER_TINT.size() - 1)
	return kind


func _draw() -> void:
	var _t0 := Time.get_ticks_usec() if perf_show else 0
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

	# 캐시가 아직 없거나(첫 프레임), 계절이 넘어가 잔디 판이 통째로 갈렸으면
	# 여기서 버린다. 계절은 글자 하나 견주는 값이면 알아낼 수 있다
	if _dc_kind.size() != MAP_W * MAP_H or _dc_season != grass_prefix:
		_dc_season = grass_prefix
		dirty_all()
	# 검증 하네스는 격자를 직접 뜯어고친다 — 문 앞을 잔디로 밀고, 집을 지우고.
	# 그 자리마다 손대라고 할 것 없이, 하네스가 붙어 있으면 캐시를 안 쓴다.
	# 거기서 중요한 건 빠르기가 아니라 찍힌 그림이 격자 그대로인 것이다
	if harness != null:
		_dc_kind.fill(DC_NONE)

	# ---- 텍스처별로 모았다가 한 번에 그린다 ----
	#
	# 칸 순서대로 그리면 잔디->물->길->잔디로 텍스처가 계속 바뀌어 배치(batch)가
	# 매번 끊긴다. 그래서 보이는 칸 수만큼(800여 번) 드로우콜이 났다.
	# 같은 텍스처끼리 붙여 그리면 스무 번 안쪽으로 줄어든다.
	#
	# 겹치는 순서는 지켜야 한다: 바탕 -> 길 가장자리 -> 작물.
	# 바탕끼리는 한 칸에 하나뿐이라 서로 안 겹친다 — 순서를 바꿔도 안전하다.
	var base := {}      # Texture2D -> Array[Vector2] (지도 밖 들판)
	# 켜마다 하나씩 — 같은 그림이라도 단이 다르면 톤이 다르다
	var base_t: Array[Dictionary] = []
	for _i in TIER_TINT.size():
		base_t.append({})
	var edges := {}
	var tall := {}      # 두 칸 높이 (벼랑면) — 아래 칸까지 덮는다
	var crops := {}
	var docks: Array[Vector2] = []

	var put := func(bin: Dictionary, t: Texture2D, at: Vector2) -> void:
		if not bin.has(t):
			bin[t] = [] as Array[Vector2]
		bin[t].append(at)

	# 맵 바깥: 화면 가장자리가 비지 않도록 어두운 숲을 깔아 둔다.
	# (카메라 제한을 풀어 주인공을 항상 화면 가운데 두기 위한 배경)
	var out_grass := {}
	var out_trees: Array[Vector2] = []
	# 잔디 판 셋은 미리 꺼내 둔다 — 칸마다 글자를 붙여 사전을 뒤질 일이 아니다
	var g3: Array[Texture2D] = [tex[grass_prefix + "0"], tex[grass_prefix + "1"],
		tex[grass_prefix + "2"]]
	for y in range(vy0, vy1):
		for x in range(vx0, vx1):
			if x >= 0 and y >= 0 and x < MAP_W and y < MAP_H:
				continue
			put.call(out_grass, g3[int(_hash01(x, y) * 3.0) % 3],
				Vector2(x * TILE, y * TILE))
			# 드문드문 나무 실루엣을 세워 숲이 이어지는 것처럼 보이게 한다
			if x % 3 == 0 and y % 2 == 0 and _hash01(x * 5 + 1, y * 7 + 3) < 0.55:
				out_trees.append(Vector2(x * TILE, y * TILE))

	# 이웃 여덟 칸을 칸마다 따로 훑으면 격자를 여덟 번씩 뒤지게 된다.
	# **줄 단위로** 읽어 두고, 그마저도 **아직 안 셈한 칸이 있는 줄에서만**
	# 읽는다. 걸음을 멈추고 있으면 여기서 다 걸러져 셈이 통째로 빠진다
	var xa := x0 - 1
	var span := x1 - x0 + 2
	var rows := {}
	var rowk := func(ry: int) -> PackedByteArray:
		if not rows.has(ry):
			rows[ry] = _row_kind(ry, xa, span)
		return rows[ry]

	var soil_wet: Texture2D = tex["soil_wet"]
	var soil_dry: Texture2D = tex["soil_dry"]
	var no_row := PackedByteArray()
	for y in range(y0, y1):
		var row: Array = grid[y]
		var rb := y * MAP_W
		var above := no_row
		var cur := no_row
		var below := no_row
		for x in range(x0, x1):
			if _dc_kind[rb + x] == DC_NONE:
				above = rowk.call(y - 1)
				cur = rowk.call(y)
				below = rowk.call(y + 1)
				break
		for x in range(x0, x1):
			var cell: Dictionary = row[x]
			var at := Vector2(x * TILE, y * TILE)
			var ci := rb + x
			var dk: int = _dc_kind[ci]
			if dk == DC_NONE:
				_dc_tall[ci] = null
				dk = _dc_fill(x, y, ci, x - xa, above, cur, below, grass_prefix)
			# 바탕은 한 칸에 하나뿐이다. 매번 달라지는 것만 여기서 고른다 —
			# 물은 **장**, 밭은 **젖었는지**. 나머지는 캐시가 들고 있다
			var bt: Texture2D = null
			if dk == DC_FIXED:
				bt = _dc_base[ci]
			elif dk == DC_WATER:
				bt = _water_tex[_dc_water[ci] * 2 + water_frame]
			elif dk == DC_SOIL:
				bt = soil_wet if cell.watered else soil_dry
			else:
				docks.append(at)
			# put 을 안 쓰고 펼쳐 적는다 — 칸마다 도는 자리라 Callable 부르는
			# 값이 그대로 곱해진다
			if bt != null:
				# 켜마다 통이 따로다 — 한 통은 한 번의 그리기라, 통이 늘어도
				# 값은 그 켜가 실제로 화면에 있을 때만 든다
				var tb: Dictionary = base_t[_dc_tier[ci]]
				var bl = tb.get(bt)
				if bl == null:
					bl = [] as Array[Vector2]
					tb[bt] = bl
				bl.append(at)
			# 가장자리 — 물가·모래·마당·벼랑. 들판은 대부분 여기가 비어 있다
			var el = _dc_edge[ci]
			if el != null:
				for t: Texture2D in el:
					var eb = edges.get(t)
					if eb == null:
						eb = [] as Array[Vector2]
						edges[t] = eb
					eb.append(at)
			var tt = _dc_tall[ci]
			if tt != null:
				var tb = tall.get(tt)
				if tb == null:
					tb = [] as Array[Vector2]
					tall[tt] = tb
				tb.append(at)
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
	# 올라선 단은 볕을 더 받는다 — 겹쳐 오르는 대지가 층으로 읽힌다
	for lv in base_t.size():
		var tb: Dictionary = base_t[lv]
		if tb.is_empty():
			continue
		var tint: Color = TIER_TINT[lv]
		for t: Texture2D in tb:
			for at: Vector2 in tb[t]:
				draw_texture_rect(t, Rect2(at, tile_size), false, tint)
	# 물 위에 깐 나무 부두.
	#
	# 예전엔 여기서 갈색 네모 세 개를 겹쳐 그렸다 — 결도 못도 없는 판이라
	# 물 위에 색종이를 오려 붙인 것 같았다. 이제 널 타일을 깔고, 물에
	# 닿는 쪽에는 잘린 널 끝과 물 속으로 박힌 기둥을 얹는다.
	if not docks.is_empty():
		var wt: Texture2D = _water_tex[water_frame]
		for at: Vector2 in docks:
			draw_texture_rect(wt, Rect2(at, tile_size), false)   # 판자 밑으로 물이 비친다
		for at: Vector2 in docks:
			var dx := int(at.x) / TILE
			var dy := int(at.y) / TILE
			draw_texture_rect(tex["dock_%d" % (int(_hash01(dx * 7, dy * 3) * 3.0) % 3)],
				Rect2(at, tile_size), false)
		for at: Vector2 in docks:
			var dx := int(at.x) / TILE
			var dy := int(at.y) / TILE
			for d in 4:
				var o: Vector2i = [Vector2i(0, -1), Vector2i(0, 1),
					Vector2i(-1, 0), Vector2i(1, 0)][d]
				var n := Vector2i(dx + o.x, dy + o.y)
				if n.x < 0 or n.y < 0 or n.x >= MAP_W or n.y >= MAP_H:
					continue
				if grid[n.y][n.x].ground == "dock":
					continue     # 부두끼리 맞닿은 쪽은 이어진 널이다
				draw_texture_rect(tex["dock_edge_%s" % ["n", "s", "w", "e"][d]],
					Rect2(at, tile_size), false)
	for t: Texture2D in edges:
		for at: Vector2 in edges[t]:
			draw_texture_rect(t, Rect2(at, tile_size), false)
	# 벼랑면 — **제 칸과 그 아래 칸**에 걸쳐 선다.
	#
	# 한 칸(화면 32px)으로는 아무리 잘 칠해도 높이가 안 느껴진다. 두 칸이면
	# 주인공(96px)의 3분의 2라 눈이 「벽」으로 읽는다. 아래 칸은 통째로
	# 바위벽이 아니라 무너져 쌓인 발치라, 거기 서면 벽 **앞에** 선 것으로
	# 보인다 (통행은 그대로 — 못 서는 칸은 예전과 같이 벼랑 밑 한 줄뿐이다)
	var tall_size := Vector2(TILE, TILE * 2)
	for t: Texture2D in tall:
		for at: Vector2 in tall[t]:
			draw_texture_rect(t, Rect2(at, tall_size), false)
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
	if perf_show:
		_perf["draw"] = Time.get_ticks_usec() - _t0
		_pm("그리기", _t0)


# ---- F3: 한 프레임이 어디서 몇 밀리초를 쓰는가 ----
#
# 짐작으로 고치는 것을 그만두려고 넣었다. 예산은 16.7ms(60프레임)이고,
# 어느 줄이 그걸 먹는지 보면 답이 나온다. **worst** 는 최근 1초 동안의
# 최악 프레임이다 — 끊김은 평균이 아니라 최악에서 온다.
func _perf_tick(delta: float) -> void:
	if _perf_label == null:
		_perf_label = Label.new()
		_perf_label.position = Vector2(8, 8)
		_perf_label.add_theme_font_size_override("font_size", 15)
		_perf_label.add_theme_color_override("font_color", Color(1, 1, 0.75))
		_perf_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_perf_label.add_theme_constant_override("outline_size", 5)
		hud.add_child(_perf_label)
	_perf_label.visible = true
	for k: String in _perf_acc:
		_perf_acc[k] = int(_perf_acc[k]) + int(_perf[k])
	_perf_n += 1
	# **프레임마다** 재 둔다. 창이 넘어갈 때만 보면 튀는 프레임은 그 사이에
	# 지나가 버린다 — 「스크립트 566ms 인데 최악 5.6ms」가 그래서 나왔다
	_perf_worst = maxf(_perf_worst, delta * 1000.0)
	_perf_proc_worst = maxf(_perf_proc_worst,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	# 창(3초)이 넘어가면 최댓값 판을 화면 쪽으로 넘기고 새로 센다
	_perf_win_t += delta
	if _perf_win_t >= PERF_WIN:
		_perf_win_t = 0.0
		_perf_max_show = _perf_max
		_perf_max = {}
		_perf_worst_show = _perf_worst
		_perf_proc_show = _perf_proc_worst
		_perf_worst = 0.0
		_perf_proc_worst = 0.0
	if _perf_n < 30:
		return
	var n := float(_perf_n)
	# 엔진이 재 주는 값 — **내가 안 잰 데**가 어디인지 여기서 갈린다.
	# 스크립트가 크면 내 코드, 그리기 호출/정점이 크면 화면에 너무 많이
	# 그리는 것이다. 짐작할 자리가 없어진다.
	#
	# **TIME_PROCESS 는 「지금 프레임」이 아니다.** 고도는 1초 동안의
	# _process 중 **가장 오래 걸린 것**을 담아 두었다가 초가 바뀔 때
	# 내놓는다. 그걸 「지금」으로 읽어서 「스크립트 566ms 인데 프레임
	# 5.6ms」 같은 말이 안 되는 짝이 나왔다 — 그건 최악 한 프레임이었고,
	# 실제로 그 초의 FPS가 반토막이었다. 이름을 바로 적어 둔다.
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var mine := (int(_perf_acc.draw) + int(_perf_acc.fade) + int(_perf_acc.stream)
		+ int(_perf_acc.spawn)) / n / 1000.0
	var lines := "FPS %d   프레임 %.1fms   최악(3초) %.1fms / 스크립트 %.1fms\n" % [
		Engine.get_frames_per_second(), delta * 1000.0,
		maxf(_perf_worst, _perf_worst_show), maxf(_perf_proc_worst, _perf_proc_show)]
	lines += "스크립트 최악(1초) %.1f · 물리 %.1f · 내가 잰 것(평균) %.2f (ms)\n" % [
		proc_ms, phys_ms, mine]
	lines += "  그리기 %.2f · 비침 %.2f · 스트림 %.2f · 세우기 %.2f\n" % [
		int(_perf_acc.draw) / n / 1000.0, int(_perf_acc.fade) / n / 1000.0,
		int(_perf_acc.stream) / n / 1000.0, int(_perf_acc.spawn) / n / 1000.0]
	# 프레임이 안 올라가는 게 **못 올라가는** 것인지 **안 올리는** 것인지.
	# 수직 동기화가 켜져 있으면 주사율 위로는 그려 봐야 화면에 안 나온다 —
	# 남는 힘이 없는 게 아니라 쓸 데가 없는 것이다. 헷갈릴 자리를 없앤다
	var vs := DisplayServer.window_get_vsync_mode()
	var hz := DisplayServer.screen_get_refresh_rate()
	lines += "그리기 호출 %d · 정점묶음 %d · 그린 것 %d · 수직동기 %s%s\n" % [
		calls, prims, objs, "켬" if vs != DisplayServer.VSYNC_DISABLED else "끔",
		(" (화면 %.0fHz)" % hz) if hz > 0.0 else ""]
	# 끊김은 평균이 아니라 **한 번 터지는 것**에서 온다. 하루 넘김이
	# 그중 제일 크다 — 어느 토막이 먹는지 여기서 바로 읽힌다
	lines += "하루넘김 %.0fms (밭 %.0f · 자람 %.0f · 리젠 %.0f · 저장 %.0f)\n" % [
		int(_perf_day.total) / 1000.0, int(_perf_day.farm) / 1000.0,
		int(_perf_day.grow) / 1000.0, int(_perf_day.spawn) / 1000.0,
		int(_perf_day.save) / 1000.0]
	# ---- 창 안에서 **가장 오래 걸린 토막** 넷 ----
	#
	# 평균은 한 번 터지는 것을 감춘다. 몇 초에 한 번 오는 0.5초짜리를
	# 찾으려면 평균이 아니라 최댓값을 봐야 하고, 그게 어느 토막인지
	# 이름이 나와야 한다. 짐작할 자리를 여기서 없앤다.
	var top: Array = []
	for k3: String in _perf_max_show:
		top.append([int(_perf_max_show[k3]), k3])
	for k4: String in _perf_max:
		var v4 := int(_perf_max[k4])
		var seen := false
		for e in top:
			if e[1] == k4:
				e[0] = maxi(int(e[0]), v4)
				seen = true
		if not seen:
			top.append([v4, k4])
	top.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var tline := ""
	for i in mini(4, top.size()):
		tline += "%s %.1f · " % [str(top[i][1]), int(top[i][0]) / 1000.0]
	lines += "가장 오래 걸린 토막: %s\n" % tline.trim_suffix(" · ")
	lines += "노드 %d (월드 자식 %d) · 물건 %d · 세울 차례 %d" % [
		obj_nodes.size(), world.get_child_count(), objects.size(),
		objnode._spawn_queue.size()]
	_perf_label.text = lines
	_perf_n = 0
	for k2: String in _perf_acc:
		_perf_acc[k2] = 0


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
# 이 둘은 다른 스크립트(net_sync·tool_use·shop_ui·hud)가 읽는 공용 상태다.
# 언더스코어를 붙이면 「이 클래스 안에서만 쓰는 값」으로 보여 안 쓰인다는
# 경고가 뜬다 — 밖에서 쓰는 값이니 이름에도 그렇게 적는다.
var forced_seed := ""
var remote_acting := false


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


# 상점 안(shop_room.gd)에서 부르는 창구 — 본체는 scripts/village_ui.gd
func room_action(kind: String) -> void:
	village.room_action(kind)


# ---- 배경음 고르기 ----
#
# 계절 곡만 틀면 어디를 가나 같은 소리가 난다. 지금 어디에 있고 무슨
# 때인지를 보고 골라 준다. 0.4초에 한 번만 본다 — 매 프레임 볼 이유가 없고,
# 경계에서 곡이 왔다 갔다 하면 그게 더 거슬린다.
const VILLAGE_AREA := Rect2i(58, 2 + NORTH_PAD, 38, 34)   # 마을 전체 (오므린 부지 전체)
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
