# 코드 배치

`main.gd`가 6900줄까지 불어서, 뭐 하나 고칠 때마다 관계없는 데가 깨지기
시작할 참이었다. 갈래별로 나눴다.

## 지금 배치

| 파일 | 줄수 | 맡은 일 |
| --- | ---: | --- |
| `main.gd` | ~1520 | 세계 상태(grid·objects·player), 매 프레임 흐름, 입력, 그리기 뼈대, 모듈 붙이기 |
| `story.gd` | ~1060 | 메인 스토리 연출 — 각본 |
| `dev_harness.gd` | ~1340 | 검증 하네스 (KYOJIN_SHOT일 때만 붙는다) |
| `village_ui.gd` | ~550 | 마을에서 여는 창들 (상점·여관·축제·의뢰·선물) |
| `tool_use.gd` | ~570 | 도구 쓰기 — 갈기·물주기·심기·베기·캐기 |
| `world_gen.gd` | ~490 | 지형·길·마을 부지·자원 재생 |
| `renderer.gd` | ~430 | 지형 위에 얹히는 것들 + 화면 안내 |
| `net_sync.gd` | ~370 | 함께하기 배관 (@rpc는 전부 여기) |
| `interact.gd` | ~350 | 상호작용·조준·클릭 |
| `object_nodes.gd` | ~390 | 세계에 서 있는 것들의 노드 |
| `day_cycle.gd` | ~220 | 하루가 넘어가는 흐름과 밤 |
| `save_load.gd` | ~190 | 세이브 담기/펴기 |
| `farming.gd` | ~170 | 농사·물기·스프링클러·목초지·가축 |
| `player_actions.gd` | ~140 | 먹기·요리·조합·아이템 얻기 |
| `npcs.gd` | ~110 | NPC 배치·길찾기 |
| `fishing.gd` | ~90 | 낚시 (미니게임은 fishing_ui.gd) |
| `riding.gd` | ~70 | 탈 것 |
| `game_data.gd` | ~2290 | 순수 데이터 + 세이브 (autoload) |

6900줄짜리 한 파일이 **1410줄 + 열여섯 갈래**가 됐다.
`cave_ui` · `shop_ui` · `inventory_ui` 같은 창들은 원래부터 따로 있다.

### main.gd에 남은 것

세계의 **상태**와 **매 프레임 흐름**만 남겼다.

- 상태 선언 (`grid` · `objects` · `player` · `tex` · 상수표) — 200줄
- `_ready` (모듈 붙이기 + 장면 세우기) · `_process` · `_draw` · `_unhandled_input`
- 아무 데서나 묻는 질문들 — `is_passable*` · `player_tile` · `ui_open` · `_is_path`
- 다른 창이 부르는 얇은 창구 (`tutorial_notify` · `show_ending` · `room_action`)

## 갈라낸 모듈의 모양

전부 **main의 자식 노드**로 붙고, `m`으로 main을 부른다.

```gdscript
class_name KyojinFarming
extends Node
var m: KyojinMain    # main.gd
```

main은 `_mount()` 한 줄로 붙인다:

```gdscript
	farming = _mount("farming", "Farming")
```

main은 `_ready()` **맨 앞에서** 이들을 붙인다. 바로 아래 `_build_map()`이
`worldgen`을 쓰기 때문이다 — 순서가 뒤집히면 `Nil` 호출로 `_ready`가 통째로
중단되고, 그 뒤로 매 프레임 에러가 쏟아진다.

### 이름(class_name)은 **양쪽 다** 붙여야 한다

모듈에서 `var m: Node2D`로 받으면 `m.player`, `m.TILE`이 전부 Variant가 되어
`var x := m.player_tile()` 같은 줄이 전부 「타입을 알 수 없다」로 막힌다.

반대쪽도 똑같다. main이 `var farming: Node`로 들고 있으면
`farming._grow_total(def)`가 Variant가 되어 같은 일이 벌어진다. 그래서
main은 `KyojinMain`, 모듈은 `KyojinFarming`처럼 **양쪽 다** 이름을 붙였다.

서로 참조하지만 순환 오류는 나지 않는다 — main이 `preload`가 아니라
**`load`** 로 자식을 만들기 때문이다.

`tools/fix_infer.py`가 남은 `:=` 자리를 모듈 쪽 `-> 타입`을 읽어 고쳐 준다.

### @rpc는 노드 경로로 찾아간다

`net_sync.gd`가 main의 자식이라는 점이 곧 통신의 전제다. @rpc는 **상대편의
같은 노드 경로**로 찾아가므로, 양쪽 peer에서 경로가 같아야 한다. main이
`_ready` 맨 앞에서 늘 같은 이름(`NetSync`)으로 붙이기 때문에 성립한다.
**이름을 바꾸면 통신이 죽는다.**

### `draw_*`는 main의 `_draw()` 안에서만

`renderer.gd`는 그냥 Node라 `draw_*`가 없어서 전부 `m.draw_*`로 부른다.
그리고 그 호출은 main의 `_draw()`가 도는 동안에만 유효하다 — 다른 때 부르면
아무 일도 일어나지 않는다.

### 다른 창에서 부르는 것

`tutorial_notify` · `show_ending`은 `interior_ui` · `shop_ui` · `alchemy_ui`가
`main.xxx()`로 부른다. 이런 것은 main에 **얇은 창구**를 남기고 본체만 옮겼다.

## 옮길 때 쓰는 도구

손으로 옮기면 `player`, `grid` 같은 main의 멤버를 전부 `m.`으로 바꿔야 하는데,
수천 줄에서 눈으로 하면 반드시 하나를 빠뜨린다.

```
python3 tools/split_module.py <설정.json>
```

문자열·주석을 가린 뒤 **최상위 멤버 이름만** 온전한 낱말일 때 바꾼다
(지역변수·인자·for 변수는 제외). 설정은 이렇게 생겼다:

```json
{
 "source": "game/scripts/main.gd",
 "out": "game/scripts/world_gen.gd",
 "ref": "m", "handle": "worldgen",
 "funcs": ["_build_map", "..."],
 "vars": [],
 "header": "# 파일 머리 주석"
}
```

### 도구가 못 잡는 것 (전부 실제로 당했다)

- **`self`가 더 이상 main이 아니다.** `shop.main = self`가 하네스를 넘겼다.
  같은 실수를 `net_sync`(원격 플레이어) · `world_gen`(건물) · `farming`(가축) ·
  `npcs`(NPC)에서 네 번 더 했다.
- **지역 이름 `m`.** 밤 몹 루프가 `for m in night_mobs`였다. 모듈에서 `m`은
  main이라, 루프 안에서 main이 통째로 가려졌다 (`m.player`가 몹을 가리켰다).
  도구가 이제 이런 코드를 만나면 **옮기지 않고 멈춘다.**
- **CanvasItem 메서드.** `get_canvas_transform()`은 Node에는 없다 → `m.` 필요.
- **다른 스크립트의 옛 주소.** `dev_harness.gd`가 `m._story_t`를 계속 보고
  있어서, 스토리 하네스가 종료 조건을 못 만나고 90초를 돌다 죽었다.
  (지금은 도구가 다른 스크립트도 함께 고친다.)
- **여러 줄 문자열.** GDScript 문자열은 줄바꿈을 품는다. 함수 경계를
  「들여쓰지 않은 줄」로 찾다가 광산 대화 한가운데를 함수 끝으로 오인해
  반토막을 냈다. → 줄로 자르기 전에 문자열을 가린다.
- **`@rpc` 어노테이션.** 함수 위에 따로 있어서 두고 올 뻔했다. 그러면 함수만
  옮겨져 통신이 통째로 죽는다.

`python3 tools/check_refs.py`가 옛 주소·`self`·지역 `m`을 훑는다.
`python3 tools/check_steps.py`는 하네스 단계 번호가 겹치는지 본다 —
겹치면 뒤에 온 갈래가 죽은 코드가 되고 검사가 조용히 사라진다 (다섯 번 당했다).

## 옮긴 뒤 반드시 하는 검증

하네스 출력을 **리팩터 전과 통째로 비교한다.** 눈으로 「돌아는 가네」가
아니라 51줄이 한 글자도 다르지 않아야 한다.

```
git worktree add /tmp/base HEAD
KYOJIN_SHOT=/tmp/bshots/ godot --path /tmp/base/game | grep -E "_OK=|:" > /tmp/base.txt
KYOJIN_SHOT=/tmp/shots/  godot --path game          | grep -E "_OK=|:" > /tmp/new.txt
diff /tmp/base.txt /tmp/new.txt
```

난수 때문에 흔들리는 줄이 셋 있다 — `RECIPE_DROP_OK`(조합법 드랍 확률),
`CAVE_LAYOUT_OK` · `CAVE_STAIRS_OK`(동굴 생성). **같은 코드로 두 번 돌려서
그 셋만 다른지** 먼저 확인하고, 리팩터 전후 차이가 그 안에 들어가는지 본다.

## 함께하기 검증

통신은 헤드리스 한 판으로 확인할 수가 없어서, 옮기기 **전에** 그물부터 만들었다.

```
KYOJIN_SHOT=/tmp/x/ KYOJIN_MP=host  godot --path game &
sleep 6
KYOJIN_SHOT=/tmp/x/ KYOJIN_MP=guest godot --path game
```

게스트가 셋을 확인하고 양쪽 다 스스로 끝낸다:

- `MP_CONNECT_OK` 붙었는가
- `MP_SNAPSHOT_OK` 호스트의 세계가 통째로 넘어왔는가
- `MP_TOOL_OK` 게스트가 민 변경이 호스트를 거쳐 되돌아오는가

이 그물이 실제로 `rp.main = self`를 잡았다. 그물 없이 옮겼으면 원격
플레이어가 조용히 망가진 채로 넘어갔을 것이다.

## 스크린샷 비교는 회귀 신호가 못 된다

그리기를 옮긴 뒤 샷 51장을 기준선과 픽셀 단위로 비교했더니 절반 넘게
달랐다. 그런데 **같은 코드로 두 번 돌려도 똑같이 달랐다** — 헤드리스에서
프레임 간격이 들쭉날쭉해 캐릭터·NPC 위치가 매번 조금씩 달라지기 때문이다.
믿을 수 있는 그물은 `*_OK=` 어서션뿐이고, 그림은 눈으로 확인한다.

## 더 쪼갤까

여기서 멈추는 게 맞다. 남은 1410줄은 **상태와 흐름**이라, 더 나누려면
`grid`·`objects` 같은 세계 상태의 주인을 옮겨야 한다. 그러면 모듈끼리
서로를 부르기 시작하고, 지금의 「main이 가운데, 모듈은 바깥」이라는 단순한
모양이 깨진다. 파일 수가 는다고 깨끗해지지는 않는다.
