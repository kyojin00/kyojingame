# 코드 배치

`main.gd`가 6900줄까지 불어서, 뭐 하나 고칠 때마다 관계없는 데가 깨지기
시작할 참이었다. 갈래별로 나눴다.

## 지금 배치

| 파일 | 줄수 | 맡은 일 |
| --- | ---: | --- |
| `main.gd` | ~3290 | 세계 상태(grid·objects·player), 도구, 시간, 낮/밤, 입력 |
| `story.gd` | ~1060 | 메인 스토리 연출 — 각본 |
| `dev_harness.gd` | ~990 | 검증 하네스 (KYOJIN_SHOT일 때만 붙는다) |
| `village_ui.gd` | ~550 | 마을에서 여는 창들 (상점·여관·축제·의뢰·선물) |
| `world_gen.gd` | ~490 | 지형·길·마을 부지·자원 재생 |
| `renderer.gd` | ~410 | 지형 위에 얹히는 것들 + 화면 안내 |
| `net_sync.gd` | ~370 | 함께하기 배관 (@rpc는 전부 여기) |
| `game_data.gd` | ~2300 | 순수 데이터 + 세이브 (autoload) |

6900줄짜리 한 파일이 3290줄 + 여섯 갈래가 됐다.

`cave_ui` · `shop_ui` · `inventory_ui` 같은 창들은 원래부터 따로 있다.

## 갈라낸 모듈의 모양

전부 **main의 자식 노드**로 붙고, `m`으로 main을 부른다.

```gdscript
extends Node
var m: KyojinMain    # main.gd
```

main은 `_ready()` **맨 앞에서** 이들을 붙인다. 바로 아래 `_build_map()`이
`worldgen`을 쓰기 때문이다 — 순서가 뒤집히면 `Nil` 호출로 `_ready`가 통째로
중단되고, 그 뒤로 매 프레임 에러가 쏟아진다.

### 왜 main에 `class_name KyojinMain`을 붙였나

모듈에서 `var m: Node2D`로 받으면 `m.player`, `m.TILE`이 전부 Variant가 된다.
그러면 `var x := m.player_tile()` 같은 줄이 **전부** 「타입을 알 수 없다」로
막힌다. 이름을 붙이니 한 번에 사라졌다.

대신 순환 참조가 되므로 main은 `preload`가 아니라 **`load`** 로 자식을 만든다.

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
- **CanvasItem 메서드.** `get_canvas_transform()`은 Node에는 없다 → `m.` 필요.
- **다른 스크립트의 옛 주소.** `dev_harness.gd`가 `m._story_t`를 계속 보고
  있어서, 스토리 하네스가 종료 조건을 못 만나고 90초를 돌다 죽었다.
  (지금은 도구가 다른 스크립트도 함께 고친다.)
- **여러 줄 문자열.** GDScript 문자열은 줄바꿈을 품는다. 함수 경계를
  「들여쓰지 않은 줄」로 찾다가 광산 대화 한가운데를 함수 끝으로 오인해
  반토막을 냈다. → 줄로 자르기 전에 문자열을 가린다.
- **`@rpc` 어노테이션.** 함수 위에 따로 있어서 두고 올 뻔했다. 그러면 함수만
  옮겨져 통신이 통째로 죽는다.

`python3 tools/check_refs.py`가 옛 주소와 `self`를 훑는다.

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

## 남은 것

main.gd에 남은 3290줄은 서로 얽혀 있는 알맹이다 — 세계 상태(grid·objects),
도구 쓰기, 시간, 낮/밤, 입력. 더 쪼개려면 상태 소유를 옮겨야 해서, 지금까지처럼
「함수만 들어내기」로는 안 된다.
