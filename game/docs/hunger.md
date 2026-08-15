# 배고픔(포만감)

메인 스토리 3의 두 번째 퀘스트 「씨앗 한 줌」에서 열린다. 재민이 씨앗을
건네며 알려 주는 것이 곧 규칙이다 — **밭을 일구는 이유**를 시스템으로
만든 장치다.

관련 코드: `game_data.gd`(수치·판정) · `main.gd`(시간·굶주림 처리) ·
`player.gd`(걸음) · `player_actions.gd`(먹기) · `day_cycle.gd`(취침) ·
`hud.gd`(게이지) · `dev_harness.gd` 스텝 292(`HUNGER_UI_OK`)

---

## 1. 수치

```gdscript
const HUNGER_MAX := 100.0
const HUNGER_PER_MIN := 0.1       # 게임 1분마다 — 가득 차면 1000분(≈하루)
const HUNGER_STARVE_DPS := 1.5    # 굶을 때 초당 깎이는 체력
const HUNGER_SAFE_FLOOR := 30.0   # 집 안에서는 여기까지만
const HUNGER_SLOW_MULT := 0.35    # 굶으면 걸음이 이만큼으로
const HUNGER_WAKE_MIN := 40.0     # 자고 일어나면 최소 이만큼
var hunger := HUNGER_MAX
var hunger_open := false          # 스토리 3-②에서 열린다
```

`hunger_open`이 거짓이면 **아무 일도 일어나지 않는다** — 게이지도 뜨지
않고, 시간이 흘러도 배가 꺼지지 않는다. (스토리 3 전의 플레이어에게
굶주림을 들이밀지 않는다)

## 2. 흐름

```
시간이 흐른다 (main._process)          먹는다 (do_eat)
   hunger_tick(게임 분)                    feed(요리의 회복량)
        │                                      │
        ▼                                      ▼
   hunger 0 = starving()  ────────────►  hunger 회복 · 굶주림 해제
        │
        ├─ 걸음: hunger_speed_mult() = 0.35  (player.gd)
        ├─ 체력 자연 회복 정지            (main._process)
        └─ starve_tick(delta, 집 안인가)
              ├─ 밖:   체력 0까지 깎이고 → **쓰러진다** (다음 날 아침)
              └─ 집 안: 체력 30(HUNGER_SAFE_FLOOR)에서 멈춘다
```

- **안전지대 규칙**: 집 안(`interior.visible`)에서는 굶주림으로 체력이
  30 아래로 내려가지 않는다. 자리를 비워 두고 한참 있어도 죽지 않는다.
  이미 30 밑이면(전투 등으로) 굶주림이 더 깎지도, 채우지도 않는다.
- **취침**: 아침에 일어나면 `hunger`가 최소 40까지는 차 있다. 하룻밤을
  자면 조금은 든든하지만, 그날 끼니는 여전히 필요하다.
- **먹기**: 요리를 먹으면 체력과 배부름이 **같은 양**씩 오른다
  (`RECIPES[id].energy`). 요리가 곧 밥이다.

## 3. 화면

체력 막대 바로 위에 밥그릇 그림 + 막대 하나. 글자는 없다.

- 배부름에 따라 색이 바뀐다: 노릇함(45% 위) → 주황(15% 위) → 붉음
- 0이 되면 밥그릇이 깜빡인다 — 말 대신 그림이 재촉한다
- `hunger_open`이 거짓이면 패널 자체가 숨는다

## 4. 검증 (`dev_harness.gd` 스텝 292 · `HUNGER_UI_OK`)

- 해금 전에는 시간이 아무리 흘러도 배가 안 꺼지고 걸음도 그대로
- 해금 뒤에는 시간에 따라 줄고, 다 꺼지면 `starving()` + 걸음 0.5배 미만
- 밖에서 굶으면 체력이 계속 깎여 0까지 간다
- 집 안에서는 딱 30에서 멈추고, 이미 12면 그대로 12다
- 먹으면 배가 차고 굶주림이 풀린다
- 게이지는 해금됐을 때만 보인다
