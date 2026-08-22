// 플레이어 도트 한 벌 — 2등신 · 16비트 JRPG풍.
//
// 유저가 고른 비율: **2등신** (머리가 키의 절반 가까이). 어두운 윤곽선,
// 머리칼의 빛 띠, 또렷한 눈 — 참고 그림(FF6)의 문법을 2등신에 얹는다.
//
// 게임 규칙 (지키지 않으면 시스템이 깨진다):
//   판          128x192 (도트 32x48, 한 칸 4px). 발바닥이 y=190 (도트 47행)
//   허리        SWING_WAIST=136px = 도트 34행 — 휘두르기의 상·하체 분할선.
//               바지가 34행에 걸쳐 있어야 잘라도 티가 안 난다
//   표준 팔레트 옷 갈아입기(recolor_player_image)는 **색을 그대로 찾아**
//               바꾼다. 아래 색은 GameData.APPEAR_* 의 0번과 한 칸도
//               다르면 안 된다. 테두리·눈·눈썹은 교체 대상이 아니다
//   프레임      {down,up,side} × (idle · walk_0..5 · swing_0..4) + blink 둘
//   머리 4종    new_boy(민머리) · hair_short · hair_spiky · player_f(긴 머리)
//
// 실행:  node make_player.js            -> ref/proposed_*.png
//        node make_player.js --install  -> sprites/ 에 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
// **보류** — 유저가 원본 캐릭터를 선택했다 (2026-08). 이 생성기를 돌려도
// 게임에는 안 들어간다. 정말 갈아끼우려면 --force 를 붙일 것.
if (process.argv.includes('--install') && !process.argv.includes('--force')) {
  console.log('보류 중 — 유저가 원본 캐릭터를 선택했다. --install 은 --force 와 함께만 동작한다.');
  process.exit(0);
}
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');

// ---- 표준 팔레트 (GameData.APPEAR_* 0번 그대로) ----
const LINE = [54, 33, 26];                 // 테두리 (교체 안 됨)
const EYE = [66, 32, 30], BROW = [136, 70, 42];
const SHIRT = [58, 88, 168], SHIRT_D = [38, 58, 120], SHIRT_L = [94, 126, 200];
const PANTS = [134, 88, 46], PANTS_D = [98, 62, 32], PANTS_L = [158, 108, 58];
const SHOE = [82, 53, 33], SHOE_D = [56, 37, 25];
const SKIN = [243, 159, 138], SKIN_L = [250, 192, 170], SKIN_D = [213, 116, 98];
const CHEEK = [235, 128, 114], MOUTH = [170, 84, 66];
const HAIR = [118, 72, 40], HAIR_L = [152, 100, 56], HAIR_D = [86, 52, 30];

class D {
  constructor() { this.w = 32; this.h = 48;
    this.d = Array.from({ length: 48 }, () => new Array(32).fill(null)); }
  px(x, y, c) { x = Math.round(x); y = Math.round(y);
    if (c && x >= 0 && y >= 0 && x < this.w && y < this.h) this.d[y][x] = c; }
  get(x, y) { return (x >= 0 && y >= 0 && x < this.w && y < this.h) ? this.d[y][x] : null; }
  rect(x0, y0, x1, y1, c) {
    for (let y = Math.round(y0); y <= Math.round(y1); y++)
      for (let x = Math.round(x0); x <= Math.round(x1); x++) this.px(x, y, c);
  }
  hline(x0, x1, y, c) { this.rect(x0, y, x1, y, c); }
  outline() {
    const add = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.d[y][x]) continue;
      for (const [ax, ay] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
        if (this.get(x + ax, y + ay) && this.get(x + ax, y + ay) !== LINE) { add.push([x, y]); break; }
    }
    for (const [x, y] of add) this.px(x, y, LINE);
  }
  render() {
    const Z = 4, im = new PNG({ width: 128, height: 192 });
    im.data.fill(0);
    for (let y = 0; y < 48; y++) for (let x = 0; x < 32; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      for (let sy = 0; sy < Z; sy++) for (let sx = 0; sx < Z; sx++) {
        const i = ((y * Z + sy) * 128 + (x * Z + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
      }
    }
    return im;
  }
}

// ---- 머리 (dir: down/up/side · style · bob: 걸을 때 몸이 까딱이는 칸) ----
//
// 머리 y(4+bob)..22. 폭 x8..23 — 몸보다 넉넉히 넓다 (2등신의 얼굴이
// 그림의 절반이다). **이마는 좁게** — 앞머리가 눈썹 자리까지 내려와야
// 아기 같은 비율이 되고, 눈은 크게 — 세로 네 칸의 눈이 생김새를 정한다.
function head(g, dir, style, bob, blink) {
  const Y = y => y + bob;
  // 두상 — 계단식 3단 깎기로 둥글게. 턱은 더 좁혀 갸름하게
  g.rect(12, Y(4), 19, Y(4), SKIN);
  g.rect(11, Y(5), 20, Y(5), SKIN);
  g.rect(10, Y(6), 21, Y(6), SKIN);
  g.rect(9, Y(7), 22, Y(7), SKIN);
  g.rect(8, Y(8), 23, Y(17), SKIN);
  g.rect(9, Y(18), 22, Y(19), SKIN);
  g.rect(10, Y(20), 21, Y(20), SKIN);
  g.rect(12, Y(21), 19, Y(21), SKIN);
  g.rect(13, Y(22), 18, Y(22), SKIN_D);            // 좁은 턱 그늘
  if (style === 'new_boy' && dir !== 'up')
    g.rect(12, Y(4), 18, Y(6), SKIN_L);            // 민머리 정수리 빛
  // 귀
  if (dir === 'down') { g.rect(7, Y(13), 7, Y(15), SKIN); g.px(7, Y(14), SKIN_D);
    g.rect(24, Y(13), 24, Y(15), SKIN); g.px(24, Y(14), SKIN_D); }
  if (dir === 'side') { g.rect(12, Y(14), 13, Y(16), SKIN_D); g.px(12, Y(15), SKIN); }
  // 얼굴 — 눈은 **타원**이다. 네모 눈이 못난 인상의 절반이었다.
  // 위아래가 한 칸 좁고 가운데가 넓은 3-4-3, 빛점은 위 안쪽에 두 칸
  if (dir === 'down') {
    if (blink) { g.hline(11, 13, Y(15), EYE); g.hline(18, 20, Y(15), EYE); }
    else {
      g.rect(12, Y(12), 13, Y(12), EYE); g.rect(11, Y(13), 13, Y(15), EYE);
      g.rect(12, Y(16), 13, Y(16), EYE);
      g.rect(18, Y(12), 19, Y(12), EYE); g.rect(18, Y(13), 20, Y(15), EYE);
      g.rect(18, Y(16), 19, Y(16), EYE);
      g.rect(12, Y(13), 12, Y(14), SKIN_L); g.rect(19, Y(13), 19, Y(14), SKIN_L);
    }
    g.px(9, Y(17), CHEEK); g.px(22, Y(17), CHEEK);
    g.rect(23, Y(11), 23, Y(16), SKIN_D);          // 오른볼 그늘 — 얼굴이 둥글어진다
    g.hline(15, 16, Y(19), MOUTH);
  } else if (dir === 'side') {
    if (blink) g.hline(17, 20, Y(15), EYE);
    else {
      g.rect(18, Y(12), 20, Y(12), EYE);           // 윗줄이 한 칸 길다 — 속눈썹
      g.rect(17, Y(13), 19, Y(15), EYE);
      g.rect(18, Y(16), 19, Y(16), EYE);
      g.rect(18, Y(13), 18, Y(14), SKIN_L);
    }
    g.px(15, Y(17), CHEEK); g.px(16, Y(17), CHEEK);
    g.px(23, Y(14), SKIN); g.px(24, Y(15), SKIN);   // 콧등과 둥근 코끝
    g.px(23, Y(15), SKIN); g.px(23, Y(16), SKIN_D);
    g.px(21, Y(19), MOUTH);
    g.px(20, Y(21), SKIN_D);                        // 턱선
  }
  hair(g, dir, style, bob);
}

// 머리 모양 — 앞머리가 눈썹 자리(11행)까지 내려온다. 이마가 좁아야
// 아기 같은 비율이 된다. 민머리는 아무것도 안 얹는다
function hair(g, dir, style, bob) {
  const Y = y => y + bob;
  if (style === 'new_boy') return;
  // 공통 뚜껑 — 두상을 따라 둥글게
  const cap = () => {
    g.rect(12, Y(2), 19, Y(2), HAIR);
    g.rect(11, Y(3), 20, Y(3), HAIR);
    g.rect(10, Y(4), 21, Y(4), HAIR);
    g.rect(9, Y(5), 22, Y(6), HAIR);
    g.rect(8, Y(7), 23, Y(9), HAIR);
  };
  if (style === 'hair_short') {
    cap();
    if (dir === 'down') {
      g.rect(8, Y(10), 23, Y(10), HAIR);
      g.hline(9, 22, Y(11), HAIR);                 // 앞머리단 — 눈 바로 위
      for (const fx of [10, 14, 17, 21]) g.px(fx, Y(12), HAIR);  // 삐죽단
      g.rect(8, Y(11), 8, Y(15), HAIR); g.rect(23, Y(11), 23, Y(15), HAIR);
      g.rect(8, Y(15), 8, Y(16), HAIR_D); g.rect(23, Y(15), 23, Y(16), HAIR_D);
      g.hline(11, 18, Y(3), HAIR_L); g.hline(12, 16, Y(4), HAIR_L);
      g.px(14, Y(7), HAIR_D); g.px(19, Y(6), HAIR_D);
    } else if (dir === 'side') {
      g.rect(8, Y(10), 15, Y(11), HAIR);           // 앞머리단(옆)
      g.px(16, Y(11), HAIR); g.px(17, Y(12), HAIR);   // 눈가로 쓸리는 사선단
      g.rect(8, Y(10), 11, Y(16), HAIR);           // 뒤통수 덩이
      g.rect(8, Y(12), 9, Y(17), HAIR_D);          // 뒷결은 그늘
      g.rect(8, Y(17), 9, Y(18), HAIR_D);
      g.hline(11, 17, Y(3), HAIR_L); g.hline(13, 16, Y(4), HAIR_L);  // 빛 호
      g.px(10, Y(8), HAIR_D);
    } else {
      g.rect(8, Y(10), 23, Y(16), HAIR);
      g.hline(11, 18, Y(3), HAIR_L); g.hline(12, 17, Y(4), HAIR_L);
      g.px(14, Y(9), HAIR_D); g.px(18, Y(12), HAIR_D);
      g.rect(8, Y(15), 23, Y(16), HAIR_D);
    }
  } else if (style === 'hair_spiky') {
    cap();
    for (const [sx, sy] of [[10, 1], [13, 0], [16, 0], [19, 1], [22, 2]]) {
      g.px(sx, Y(sy), HAIR); g.px(sx + 1, Y(sy + 1), HAIR);
    }
    if (dir === 'down') {
      g.rect(8, Y(10), 23, Y(10), HAIR);
      g.hline(9, 22, Y(11), HAIR);
      for (const fx of [9, 12, 15, 18, 21]) g.px(fx, Y(12), HAIR);   // 뾰족단
      g.hline(12, 17, Y(3), HAIR_L); g.px(15, Y(1), HAIR_L);
      g.px(13, Y(6), HAIR_D); g.px(19, Y(5), HAIR_D);
    } else if (dir === 'side') {
      g.rect(8, Y(10), 15, Y(11), HAIR);
      g.px(16, Y(11), HAIR); g.px(17, Y(12), HAIR);
      g.rect(8, Y(10), 11, Y(15), HAIR);
      g.px(7, Y(8), HAIR); g.px(7, Y(12), HAIR);   // 뒤로 뻗친 결
      g.rect(8, Y(12), 9, Y(15), HAIR_D);
      g.hline(11, 16, Y(3), HAIR_L); g.hline(13, 15, Y(4), HAIR_L);
    } else {
      g.rect(8, Y(10), 23, Y(15), HAIR);
      g.hline(11, 18, Y(3), HAIR_L);
      g.px(13, Y(8), HAIR_D); g.px(18, Y(11), HAIR_D);
      g.rect(8, Y(14), 23, Y(15), HAIR_D);
    }
  } else {                                         // player_f — 긴 머리
    cap();
    g.rect(7, Y(8), 8, Y(26), HAIR); g.rect(23, Y(8), 24, Y(26), HAIR);
    g.rect(7, Y(25), 8, Y(26), HAIR_D); g.rect(23, Y(25), 24, Y(26), HAIR_D);
    if (dir === 'down') {
      g.rect(8, Y(10), 23, Y(10), HAIR);
      g.hline(9, 22, Y(11), HAIR);
      for (const fx of [11, 15, 20]) g.px(fx, Y(12), HAIR);
      g.hline(11, 18, Y(3), HAIR_L); g.hline(12, 16, Y(4), HAIR_L);
      g.px(8, Y(18), HAIR_L); g.px(23, Y(20), HAIR_L);
      g.px(14, Y(7), HAIR_D); g.px(19, Y(6), HAIR_D);
    } else if (dir === 'side') {
      g.rect(8, Y(10), 15, Y(11), HAIR);
      g.px(16, Y(11), HAIR); g.px(17, Y(12), HAIR);
      g.rect(7, Y(9), 11, Y(26), HAIR);            // 뒤로 흘러내린 머리
      g.rect(7, Y(12), 8, Y(22), HAIR_D);          // 뒷결 그늘
      g.rect(7, Y(24), 11, Y(26), HAIR_D);
      g.hline(11, 16, Y(3), HAIR_L); g.hline(13, 15, Y(4), HAIR_L);
      g.px(10, Y(18), HAIR_L);                     // 흘러내린 결의 빛
    } else {
      g.rect(8, Y(10), 23, Y(18), HAIR);
      g.rect(9, Y(18), 22, Y(28), HAIR);           // 등으로 흘러내린 머리
      g.rect(9, Y(26), 22, Y(28), HAIR_D);
      g.hline(11, 18, Y(3), HAIR_L); g.hline(12, 16, Y(4), HAIR_L);
      g.px(13, Y(11), HAIR_D); g.px(18, Y(14), HAIR_D);
    }
  }
}

// ---- 팔 하나 — 어깨(sx,sy)에서 주먹(fx,fy)까지 곧게 ----
// 소매(셔츠)가 절반, 나머지가 맨팔. 주먹은 피부 두 칸.
// edged: 몸통 **위에** 놓이는 팔(옆모습)은 같은 색에 묻히므로,
// 먼저 윤곽선으로 한 둘레 두껍게 깔고 그 위에 팔을 그린다
function arm(g, sx, sy, fx, fy, edged) {
  // 팔뚝은 **세 도트** — 두 도트는 2등신의 몸집에 비해 철사처럼 얇다
  const n = Math.max(Math.abs(fx - sx), Math.abs(fy - sy), 1);
  if (edged) {
    for (let k = 0; k <= n; k++) {
      const x = sx + (fx - sx) * k / n, y = sy + (fy - sy) * k / n;
      g.rect(x - 2, y - 1, x + 2, y + 2, LINE);
    }
    g.rect(fx - 2, fy - 1, fx + 2, fy + 3, LINE);
  }
  for (let k = 0; k <= n; k++) {
    const x = sx + (fx - sx) * k / n, y = sy + (fy - sy) * k / n;
    const c = k < n * 0.34 ? SHIRT : SKIN;
    g.rect(x - 1, y, x + 1, y + 1, c);
  }
  g.rect(fx - 1, fy, fx + 1, fy + 1, SKIN);
  g.px(fx, fy + 2, SKIN_D);
}

// ---- 몸통·다리 (dir · bob · legs · sideStep) ----
//
// 몸통은 머리보다 **네 칸 좁다** (x11..20). 머리가 크고 몸이 좁아야
// 2등신이 귀엽게 선다. 어깨는 한 칸 물러나고, 다리는 허리(34행)
// 아래에서 곧장 갈라진다 — 바지 통짜 상자는 다리가 아니다.
function body(g, dir, bob, legL, legR, sideStep) {
  const Y = y => y + bob;
  if (dir === 'side') {
    g.rect(14, Y(23), 17, Y(23), SHIRT);
    g.rect(13, Y(24), 18, Y(24), SHIRT);
    g.rect(12, Y(25), 19, Y(30), SHIRT);
    g.rect(14, Y(24), 17, Y(24), SHIRT_L);
    g.rect(13, Y(31), 18, Y(32), SHIRT_D);         // 허리 잘록
    g.rect(12, Y(25), 12, Y(30), SHIRT_D);         // 등쪽 그늘 (뒤가 어둡다)
    g.rect(12, 33, 19, 36, PANTS);
    g.hline(13, 18, 33, PANTS_L);
    g.rect(12, 34, 12, 36, PANTS_D);
    const f = 15 + sideStep, b = 13 - sideStep;
    g.rect(b - 1, 37, b + 2, 42, PANTS_D);
    g.rect(f - 1, 37, f + 2, 42, PANTS);
    g.rect(b - 1, 43, b + 2, 45, SHOE_D);
    g.rect(f - 1, 43, f + 2, 46, SHOE);
    g.hline(f, f + 1, 47, SHOE_D);
  } else {
    g.rect(13, Y(23), 18, Y(23), SHIRT);           // 어깨 2단 경사
    g.rect(12, Y(24), 19, Y(24), SHIRT);
    g.rect(11, Y(25), 20, Y(30), SHIRT);
    g.rect(13, Y(24), 18, Y(24), SHIRT_L);
    g.rect(12, Y(31), 19, Y(32), SHIRT_D);         // 허리 잘록
    g.rect(20, Y(26), 20, Y(30), SHIRT_D);         // 오른 그늘 기둥 — 빛은 왼쪽 위
    if (dir === 'down') { g.px(15, Y(27), SHIRT_D); g.px(15, Y(30), SHIRT_D); }
    g.rect(11, 33, 20, 36, PANTS);                 // 엉덩이 (34행이 이 안)
    g.hline(12, 19, 33, PANTS_L);
    g.rect(20, 34, 20, 36, PANTS_D);
    for (const [x0, x1, lift] of [[11, 14, legL], [17, 20, legR]]) {
      g.rect(x0, 37 - lift, x1, 42 - lift, PANTS);
      g.rect(x1, 37 - lift, x1, 42 - lift, PANTS_D);   // 다리 오른 그늘
      g.rect(x0, 43 - lift, x1, 46 - lift, SHOE);
      g.px(x1, 44 - lift, SHOE_D);
      g.hline(x0 + 1, x1 - 1, 47 - lift, SHOE_D);  // 밑단은 안쪽만 — 둥근 발
    }
  }
}

// ---- 한 장 ----
//
// kind: 'idle' | 'blink' | 'walk' | 'swing',  i: 프레임 번호
function frame(style, dir, kind, i) {
  const g = new D();
  const bob = kind === 'walk' ? [0, -1, 0, 0, -1, 0][i] : 0;

  if (kind === 'swing') {
    // 주먹 자리 — player.gd 의 도구 손잡이 좌표(TOOL)와 맞춘 도트.
    // 도구는 게임이 이 주먹에 쥐여 준다
    const FIST = {
      down: [[6, 21], [4, 12], [3, 20], [9, 32], [6, 22]],
      up:   [[24, 19], [24, 12], [20, 6], [17, 11], [24, 16]],
      // 옆 — 주먹이 얼굴을 가로지르면 안 된다. 와인드업은 머리 **뒤로**
      // 넘어갔다가(7,6) 정수리 위(17,3)를 지나 앞으로 내리친다
      side: [[8, 17], [7, 6], [17, 3], [24, 25], [20, 31]],
    }[dir][i];
    const lean = [0, -1, -1, 1, 1][i];               // 젖혔다 숙인다
    body(g, dir, lean, 0, 0, 0);
    head(g, dir, style, lean, false);
    if (dir === 'side') {
      arm(g, 15, 25 + lean, FIST[0], FIST[1], true); // 보이는 팔 하나
    } else {
      // 두 손 모아 쥔다 — 주먹 자리에 양팔이 모인다
      arm(g, 12, 25 + lean, FIST[0], FIST[1]);
      arm(g, 19, 25 + lean, FIST[0] + 1, FIST[1]);
    }
  } else {
    const legL = kind === 'walk' ? [0, 1, 2, 0, 0, 0][i] : 0;
    const legR = kind === 'walk' ? [0, 0, 0, 0, 1, 2][i] : 0;
    const sideStep = kind === 'walk' ? [0, 2, 3, 0, -2, -3][i] : 0;
    body(g, dir, bob, legL, legR, sideStep);
    head(g, dir, style, bob, kind === 'blink');
    if (dir === 'side') {
      const sw = kind === 'walk' ? [0, -2, -3, 0, 2, 3][i] : 0;   // 팔은 다리와 반대로
      arm(g, 15, 25 + bob, 15 + sw, 32 + bob, true);
    } else {
      const swL = kind === 'walk' ? -legR : 0;       // 왼팔은 오른발과 함께
      const swR = kind === 'walk' ? -legL : 0;
      arm(g, 9, 25 + bob, 8, 32 + bob + swL);
      arm(g, 22, 25 + bob, 23, 32 + bob + swR);
    }
  }
  g.outline();
  return g;
}

// ---- 뽑기 ----
const STYLES = ['new_boy', 'hair_short', 'hair_spiky', 'player_f'];
let n = 0;
for (const st of STYLES) {
  const jobs = [['down', 'idle', 0], ['up', 'idle', 0], ['side', 'idle', 0],
    ['down', 'blink', 0], ['side', 'blink', 0]];
  for (const d of ['down', 'up', 'side']) {
    for (let i = 0; i < 6; i++) jobs.push([d, 'walk', i]);
    for (let i = 0; i < 5; i++) jobs.push([d, 'swing', i]);
  }
  for (const [d, k, i] of jobs) {
    const name = k === 'idle' ? `${st}_${d}_idle`
      : k === 'blink' ? `${st}_${d}_blink`
      : `${st}_${d}_${k}_${i}`;
    fs.writeFileSync((INSTALL ? SPR : REF + 'proposed_') + name + '.png',
      PNG.sync.write(frame(st, d, k, i).render()));
    n++;
  }
}
console.log(`플레이어 도트 ${n}장 — 128x192 (2등신 · 머리 4종 · 표준 팔레트)`);
console.log(INSTALL ? '  sprites/ 에 넣었다' : '  ref/proposed_*.png 로만 뽑았다');
