// 이장의 낡은 오두막 — chief_hut.png
//
// 처음 판은 72x62짜리 납작한 갈색 상자였다. 두 가지가 잘못돼 있었다.
//
//  1. **도트 크기가 절반이었다.** 이 게임의 규칙은 「무엇을 그리든 한 도트가
//     화면 2px」이다. 옛 그림은 1px 밀도로 그려 sc=1.0으로 얹혀서, 옆에 선
//     사람이나 마을 집보다 도트가 절반이었다. 그래서 아무리 손을 봐도
//     혼자 사진처럼 매끈해 보이고 세계에 안 붙었다.
//  2. **사람보다 작았다.** 72x62 그림이 화면 72x62px인데 주인공이 64x96px다.
//     이장이 자기 집보다 컸다.
//
// 그래서 다시 그린다. 논리 112x112 도트를 4배로 키워 448x448 PNG로 굽고,
// object_nodes.gd 가 sc=0.5 로 얹는다 → 화면 224x224px = 7x7칸.
// 마을 사람들이 나중에 지어 주는 새 집(157x162 도트)의 3분의 2쯤 — 「아직
// 이만한 집에 산다」가 한눈에 보이는 크기다.
//
// 모습: 볏짚을 얹은 한 칸짜리 초가. 마루가 가운데로 처졌고 처마 끝에 이끼가
// 앉았다. 벽은 비에 바랜 널판이고 한 장은 색이 안 바랜 새 판자로 덧댔다.
// 문 위에 인방, 옆에 장작더미와 물독, 창턱에 화분 — 사람이 살고 있다는 표시.
//
// chief_house.png(마을이 지어 준 새 집)은 여기서 굽지 않는다. 그 그림은
// 따로 들여온 712x672 원화라, 이 파일이 덮어쓰면 안 된다.
//
// 실행: game/assets/ref 에서  node make_chief_hut.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

const W = 112, H = 112, DOT = 4;

// ---- 팔레트 ----------------------------------------------------------
// 무엇이든 「위는 빛, 몸통, 아래는 그늘」 세 단으로 잡는다.
const C = {
  th0: [216, 190, 134], th1: [193, 164, 106], th2: [167, 138, 84],   // 볏짚
  th3: [138, 111, 66], th4: [108, 85, 50], th5: [82, 63, 36],
  thk: [60, 45, 26],                                                  // 짚 속 어둠
  mo0: [126, 148, 82], mo1: [96, 118, 60], mo2: [70, 88, 44],         // 이끼
  wd0: [158, 130, 96], wd1: [133, 107, 77], wd2: [110, 87, 61],       // 바랜 널판
  wd3: [88, 68, 46], wd4: [68, 51, 34],
  nw0: [190, 150, 100], nw1: [163, 125, 79],                          // 덧댄 새 판자
  bm0: [104, 76, 48], bm1: [80, 58, 36], bm2: [58, 41, 26],           // 기둥·문틀
  st0: [180, 172, 154], st1: [148, 140, 124], st2: [114, 107, 94],    // 돌 기단
  st3: [84, 78, 68],
  li0: [255, 231, 166], li1: [236, 194, 114], li2: [193, 145, 76],    // 창 불빛
  ir0: [104, 104, 112], ir1: [70, 70, 78],                            // 쇠붙이
  gr0: [110, 146, 74], gr1: [82, 114, 54],                            // 풀
  cl0: [116, 96, 84], cl1: [92, 74, 64], cl2: [68, 54, 46],           // 물독 (질그릇)
  O: [40, 28, 19],                                                    // 윤곽·틈
  sh: [56, 44, 33],                                                   // 그늘
};

// 결정적 잡음 — 같은 자리는 늘 같은 값. (실행할 때마다 집이 달라지면 안 된다)
function h(x, y, s) {
  const n = Math.sin(x * 127.1 + y * 311.7 + (s || 0) * 74.7) * 43758.5453;
  return n - Math.floor(n);
}
const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

class D {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Array(w * h).fill(null); }
  px(x, y, c) {
    x |= 0; y |= 0;
    if (!c || x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.d[y * this.w + x] = c;
  }
  get(x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return null;
    return this.d[y * this.w + x];
  }
  rect(x, y, w, hh, c) {
    for (let j = 0; j < hh; j++) for (let i = 0; i < w; i++) this.px(x + i, y + j, c);
  }
  hline(x0, x1, y, c) { for (let x = x0; x <= x1; x++) this.px(x, y, c); }
  vline(x, y0, y1, c) { for (let y = y0; y <= y1; y++) this.px(x, y, c); }
  // 이미 칠해진 자리만 어둡게 — 그림자를 「덧씌운다」
  shade(x, y, k) {
    const c = this.get(x, y);
    if (!c) return;
    this.px(x, y, [c[0] * k | 0, c[1] * k | 0, c[2] * k | 0]);
  }
  render(scale) {
    const p = new PNG({ width: this.w * scale, height: this.h * scale });
    p.data.fill(0);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const c = this.d[y * this.w + x];
      if (!c) continue;
      for (let j = 0; j < scale; j++) for (let i = 0; i < scale; i++) {
        const k = ((y * scale + j) * p.width + (x * scale + i)) * 4;
        p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2]; p.data[k + 3] = 255;
      }
    }
    return p;
  }
}

const g = new D(W, H);

// ---- 자리잡기 --------------------------------------------------------
const GROUND = 111;          // 발치 (스프라이트 밑변)
const FOOT_Y = 100;           // 돌 기단 윗줄
const WALL_X0 = 16, WALL_X1 = 95;
const WALL_Y0 = 50;          // 벽 윗줄 (처마에 가린다)
const RIDGE_Y = 20;          // 지붕 마루
const EAVE_Y = 56;           // 처마 끝
const RIDGE_X0 = 26, RIDGE_X1 = 85;
const EAVE_X0 = 3, EAVE_X1 = 108;

// 마루의 처짐 — 오래된 초가는 가운데가 내려앉는다. 이 두 도트가
// 「낡았다」를 말한다 (판판한 사다리꼴은 새로 이은 지붕처럼 보인다).
function sagAt(x) {
  const t = clamp((x - RIDGE_X0) / (RIDGE_X1 - RIDGE_X0), 0, 1);
  return Math.round(Math.sin(Math.PI * t) * 2.2);
}
// 열 x 에서 지붕이 시작되는 줄
function roofTop(x) {
  if (x < RIDGE_X0) return RIDGE_Y + (RIDGE_X0 - x) * (EAVE_Y - RIDGE_Y) / (RIDGE_X0 - EAVE_X0);
  if (x > RIDGE_X1) return RIDGE_Y + (x - RIDGE_X1) * (EAVE_Y - RIDGE_Y) / (EAVE_X1 - RIDGE_X1);
  return RIDGE_Y + sagAt(x);
}
// 처마 네 귀는 둥글다. 초가에 직각 모서리는 없다 — 짚을 꺾어 돌려 덮으니
// 자연히 반원이 된다. 이 한 가지가 「짚」과 「판자」를 가른다.
function cornerCut(x) {
  const d = Math.min(x - EAVE_X0, EAVE_X1 - x);
  if (d >= 8) return 0;
  return Math.round(8 - Math.sqrt(Math.max(0, 64 - (8 - d) * (8 - d))));
}

// ======================================================================
// 1. 돌 기단 — 집을 땅에서 한 뼘 띄운다
// ======================================================================
function footing() {
  g.rect(WALL_X0 - 3, FOOT_Y, (WALL_X1 + 3) - (WALL_X0 - 3) + 1, GROUND - FOOT_Y + 1, C.st3);
  // 돌을 「덩어리」로 놓는다. 확률로 흩뿌리면 자갈밭이 되지 벽이 안 된다.
  let y = FOOT_Y + 1;
  for (let row = 0; row < 2; row++) {
    const hgt = row === 0 ? 5 : 4;
    let x = WALL_X0 - 2 + (row === 0 ? 0 : 4);   // 줄마다 어긋물려 쌓는다
    while (x < WALL_X1 + 3) {
      const wdt = 7 + Math.floor(h(x, row, 21) * 5);
      const t = h(x, row, 33);
      const body = t < 0.33 ? C.st1 : t < 0.72 ? C.st2 : C.st0;
      g.rect(x, y, Math.min(wdt, WALL_X1 + 3 - x), hgt, body);
      g.hline(x, Math.min(x + wdt - 1, WALL_X1 + 3), y, C.st0);          // 윗면 빛
      g.hline(x, Math.min(x + wdt - 1, WALL_X1 + 3), y + hgt - 1, C.st3); // 밑면 그늘
      g.vline(x, y, y + hgt - 1, C.st3);                                  // 돌 사이 줄눈
      x += wdt + 1;
    }
    y += hgt + 1;
  }
  g.hline(WALL_X0 - 3, WALL_X1 + 3, GROUND, C.O);
  // 땅에 닿는 그늘 — 집이 「놓여 있다」로 읽히게
  for (let x = WALL_X0 - 5; x <= WALL_X1 + 5; x++) {
    g.px(x, GROUND + 0, C.sh);
  }
}

// ======================================================================
// 2. 널판 벽 — 판자를 한 장씩 세운다
// ======================================================================
function wall() {
  const y0 = WALL_Y0, y1 = FOOT_Y - 1;
  g.rect(WALL_X0, y0, WALL_X1 - WALL_X0 + 1, y1 - y0 + 1, C.wd2);
  let x = WALL_X0 + 4;                        // 왼쪽 기둥 자리를 비워 둔다
  const boards = [];
  while (x < WALL_X1 - 3) {
    const wdt = 5 + Math.floor(h(x, 7, 5) * 3);
    boards.push([x, Math.min(wdt, WALL_X1 - 3 - x)]);
    x += wdt + 1;
  }
  boards.forEach(([bx, bw], bi) => {
    if (bw < 2) return;
    const t = h(bi, 1, 13);
    const body = t < 0.3 ? C.wd0 : t < 0.62 ? C.wd1 : C.wd2;
    const isNew = bi === 3;                   // 한 장만 색이 안 바랜 새 판자
    g.rect(bx, y0, bw, y1 - y0 + 1, isNew ? C.nw1 : body);
    g.vline(bx, y0, y1, isNew ? C.nw0 : C.wd0);          // 판자 왼쪽 모서리 빛
    g.vline(bx + bw - 1, y0, y1, C.wd3);                 // 오른쪽 그늘
    g.vline(bx + bw, y0, y1, C.bm2);                     // 판자 사이 틈
    // 나뭇결 — 세로로만 흐른다. 가로로 그으면 벽돌담이 된다.
    for (let yy = y0; yy <= y1; yy++) {
      if (h(bi * 3 + 1, yy, 17) < 0.13) g.px(bx + 1 + Math.floor(h(yy, bi, 4) * (bw - 2)), yy, C.wd3);
    }
    // 옹이 — 판자 한 장에 하나쯤. 가운데가 어둡고 둘레에 밝은 테가 돈다.
    if (h(bi, 9, 29) < 0.4 && bw >= 5) {
      const ky = y0 + 8 + Math.floor(h(bi, 2, 31) * (y1 - y0 - 18));
      const kx = bx + 2;
      g.rect(kx, ky, 2, 3, C.wd4);
      g.px(kx - 1, ky + 1, C.wd0); g.px(kx + 2, ky + 1, C.wd0);
      g.px(kx, ky - 1, C.wd0); g.px(kx + 1, ky + 3, C.wd0);
    }
    if (isNew) {   // 못 네 개 — 「덧댔다」는 건 못으로 말한다
      for (const ny of [y0 + 6, y1 - 5])
        for (const nx of [bx + 1, bx + bw - 2]) g.px(nx, ny, C.ir1);
    }
  });
  // 가로 띠장 두 줄 — 판자를 잡아 주는 나무. 이게 있어야 「판자벽」이 된다.
  for (const by of [y0 + 5, y1 - 9]) {
    g.rect(WALL_X0, by, WALL_X1 - WALL_X0 + 1, 3, C.bm0);
    g.hline(WALL_X0, WALL_X1, by, C.wd0);
    g.hline(WALL_X0, WALL_X1, by + 2, C.bm2);
  }
  // 모서리 기둥
  for (const px0 of [WALL_X0, WALL_X1 - 3]) {
    g.rect(px0, y0, 4, y1 - y0 + 1, C.bm1);
    g.vline(px0 === WALL_X0 ? px0 : px0 + 3, y0, y1, C.bm2);
    g.vline(px0 === WALL_X0 ? px0 + 1 : px0 + 2, y0, y1, C.bm0);
  }
  g.vline(WALL_X0 - 1, y0, y1, C.O);
  g.vline(WALL_X1 + 1, y0, y1, C.O);
}

// ======================================================================
// 3. 창 — 안에 불이 켜져 있다
// ======================================================================
function window_(x0, y0, w, hh) {
  g.rect(x0 - 2, y0 - 2, w + 4, hh + 4, C.bm1);        // 창틀
  g.hline(x0 - 2, x0 + w + 1, y0 - 2, C.bm0);
  g.hline(x0 - 2, x0 + w + 1, y0 + hh + 1, C.bm2);
  g.rect(x0, y0, w, hh, C.li1);                        // 불빛
  // 방 안쪽은 위가 밝고 아래로 잦아든다 (등불이 천장을 비춘다)
  for (let j = 0; j < hh; j++) {
    const t = j / (hh - 1);
    const c = t < 0.28 ? C.li0 : t < 0.7 ? C.li1 : C.li2;
    g.hline(x0, x0 + w - 1, y0 + j, c);
  }
  g.vline(x0 + (w >> 1) - 1, y0, y0 + hh - 1, C.bm1);  // 창살
  g.hline(x0, x0 + w - 1, y0 + (hh >> 1) - 1, C.bm1);
  // 창턱 — 밖으로 내민 판자. 이게 있어야 창이 벽에 뚫린 구멍이 아니라
  // 「달린 것」이 된다.
  g.rect(x0 - 4, y0 + hh + 2, w + 8, 3, C.wd1);
  g.hline(x0 - 4, x0 + w + 3, y0 + hh + 2, C.wd0);
  g.hline(x0 - 4, x0 + w + 3, y0 + hh + 4, C.bm2);
  for (let x = x0 - 3; x < x0 + w + 3; x++) g.shade(x, y0 + hh + 5, 0.7);
  // 창턱의 화분 — 이 집에 사람이 산다는 가장 작은 표시
  const px0 = x0 + w - 6;
  g.rect(px0, y0 + hh - 3, 6, 4, [142, 92, 66]);
  g.hline(px0, px0 + 5, y0 + hh - 3, [172, 116, 84]);
  g.hline(px0, px0 + 5, y0 + hh, [104, 64, 44]);
  for (const [dx, dy] of [[1, -2], [2, -4], [4, -3], [3, -1], [5, -5]])
    g.px(px0 + dx, y0 + hh - 3 + dy, dy < -3 ? C.gr0 : C.gr1);
  g.px(px0 + 2, y0 + hh - 8, [226, 122, 128]);        // 꽃 한 송이
  g.px(px0 + 4, y0 + hh - 7, [226, 122, 128]);
  // 덧문 두 짝은 뺐다 — 4칸짜리 널조각은 이 크기에서 「덧문」으로 안 읽히고
  // 기둥과 창틀 사이에 낀 얼룩으로만 보였다.
}

// ======================================================================
// 4. 문 — 널판 세 장에 Z 버팀목
// ======================================================================
function door(x0, y0, w, hh) {
  const y1 = y0 + hh - 1;
  g.rect(x0 - 3, y0 - 3, w + 6, hh + 3, C.bm1);       // 문틀
  g.hline(x0 - 3, x0 + w + 2, y0 - 3, C.bm0);
  g.vline(x0 - 3, y0 - 3, y1, C.bm0);
  g.vline(x0 + w + 2, y0 - 3, y1, C.bm2);
  g.rect(x0, y0, w, hh, C.wd2);                       // 문짝
  const bw = Math.floor(w / 3);
  for (let i = 0; i < 3; i++) {
    const bx = x0 + i * bw;
    const t = h(i, 5, 41);
    g.rect(bx, y0, i === 2 ? w - bw * 2 : bw, hh, t < 0.4 ? C.wd1 : t < 0.75 ? C.wd2 : C.wd3);
    g.vline(bx, y0, y1, C.wd0);
    if (i > 0) g.vline(bx - 1, y0, y1, C.bm2);
  }
  // 버팀목 — 가로 둘에 빗장 하나. 이 세 줄이 「문짝」을 만든다.
  for (const by of [y0 + 3, y1 - 4]) {
    g.rect(x0, by, w, 3, C.bm0);
    g.hline(x0, x0 + w - 1, by, C.wd0);
    g.hline(x0, x0 + w - 1, by + 2, C.bm2);
  }
  const ya = y0 + 5, yb = y1 - 5;
  for (let yy = ya; yy <= yb; yy++) {
    const bx = x0 + Math.round(lerp(1, w - 4, (yy - ya) / (yb - ya)));
    g.rect(bx, yy, 3, 1, C.bm0);
    g.px(bx, yy, C.wd0);
  }
  // 돌쩌귀 두 짝 + 나무 손잡이
  for (const by of [y0 + 3, y1 - 4]) {
    g.rect(x0, by, 7, 3, C.ir0);
    g.hline(x0, x0 + 6, by + 2, C.ir1);
    g.px(x0 + 6, by + 1, C.ir1);
  }
  g.rect(x0 + w - 4, y0 + (hh >> 1) - 1, 3, 3, C.ir1);
  g.px(x0 + w - 4, y0 + (hh >> 1) - 1, C.ir0);
  // 문 위 안쪽 그늘 — 문이 벽보다 안으로 들어가 있다는 표시
  for (let j = 0; j < 2; j++) for (let x = x0; x < x0 + w; x++) g.shade(x, y0 + j, 0.72);
  // 문지방 돌
  g.rect(x0 - 4, y1 + 1, w + 8, 3, C.st1);
  g.hline(x0 - 4, x0 + w + 3, y1 + 1, C.st0);
  g.hline(x0 - 4, x0 + w + 3, y1 + 3, C.st3);
}

// 문 위 인방 — 문을 걸어 놓은 굵은 통나무 하나.
// 처음엔 판자 차양을 달았는데, 처마가 이미 13칸이나 나와 있어서 차양이
// 무슨 일을 하는지 안 보이고 문 위에 낀 널판 한 장이 됐다. 지붕이 하는
// 일을 두 번 말할 필요는 없다 — 대신 문틀을 「무엇이 받치고 있는지」만
// 보여 주면 된다.
function lintel(x0, x1, y) {
  g.rect(x0, y, x1 - x0 + 1, 4, C.bm0);
  g.hline(x0, x1, y, C.wd1);
  g.hline(x0, x1, y + 3, C.bm2);
  for (let x = x0; x <= x1; x++)                                      // 통나무 결
    if (h(x, 0, 88) < 0.22) g.px(x, y + 1 + (h(x, 1, 89) < 0.5 ? 0 : 1), C.bm1);
  for (const ex of [x0, x1 - 1]) { g.vline(ex, y, y + 3, C.bm2); g.px(ex + 1, y + 1, C.bm1); }
  for (let x = x0 + 1; x < x1; x++) g.shade(x, y + 4, 0.72);          // 밑에 지는 그늘
}

// ======================================================================
// 5. 볏짚 지붕 — 이 집의 얼굴
// ======================================================================
// 첫 판은 지붕이 **대나무 발**처럼 보였다. 켜의 끝단을 자로 잰 듯 곧게
// 긋고 그 위아래에 밝은 줄·어두운 줄을 나란히 깔았더니, 가로줄이 세로
// 짚올보다 세져서 격자무늬가 된 것이다.
//
// 짚은 그렇게 안 생겼다. 이엉은 **한 다발씩** 처마부터 위로 겹쳐 올리는데,
// 다발마다 길이가 조금씩 달라서 켜의 끝단이 애초에 들쭉날쭉하다. 그러니
// 켜를 「선」으로 긋지 말고, **다발을 하나씩 놓고 그 밑동이 만드는 선**을
// 그대로 두면 된다. 아래 코드는 그 순서를 그대로 따른다.
const NB = 22;                        // 짚단 수 — 마루에서 처마로 부챗살처럼 벌어진다
const NC = 5;                         // 이엉 켜
const SPAN = EAVE_Y - RIDGE_Y;
const STEP = SPAN / NC;
// c번째 켜의 b번째 다발이 끝나는 줄. ±2칸 흔들려 처마가 텁수룩해진다.
const bundleBot = (c, b) => EAVE_Y - c * STEP + (h(b, c, 5) * 4.4 - 2.2);

function thatch() {
  for (let y = RIDGE_Y - 1; y <= EAVE_Y + 4; y++) {
    const t = (y - RIDGE_Y) / SPAN;
    const xl = lerp(RIDGE_X0, EAVE_X0, t), xr = lerp(RIDGE_X1, EAVE_X1, t);
    for (let x = Math.floor(xl) - 1; x <= Math.ceil(xr) + 1; x++) {
      if (y < roofTop(x) - 0.5) continue;
      const u = (x - xl) / (xr - xl);
      if (u < 0 || u > 1) continue;
      const b = Math.floor(clamp(u, 0, 0.9999) * NB);
      if (y > bundleBot(0, b) - cornerCut(x)) continue;   // 처마 밖 (귀는 둥글게)
      // 이 도트를 덮고 있는 켜 = 밑동이 아직 이 줄보다 아래인 것 중 제일 위
      let c = NC - 1;
      while (c > 0 && bundleBot(c, b) < y) c--;
      const yb = Math.round(bundleBot(c, b));
      // 다발 하나 — 왼쪽 올이 빛을 받고 오른쪽 올이 그늘진다.
      // **세로 결이 주인공**이고 켜의 끝단은 거들 뿐이다.
      const inner = u * NB - b;
      const bt = h(b, c, 3);
      const step = bt < 0.24 ? 1 : bt < 0.54 ? 2 : bt < 0.82 ? 3 : 4;
      const LAD = [C.th0, C.th1, C.th2, C.th3, C.th4, C.th5, C.thk];
      let k = step + (c >= NC - 2 ? 0 : 1);          // 위 켜가 볕을 더 받는다
      // 해는 왼쪽 위에 있다. 지붕 전체에 걸린 이 완만한 기울기가 없으면
      // 짚결은 살아도 지붕 자체는 **판판한 판자 한 장**으로 보인다.
      // 소수로 더한 뒤 마지막에 반올림하니 띠가 지지 않고 짚올에 섞인다.
      k += (u - 0.40) * 2.3;
      if (inner < 0.2) k -= 1;
      else if (inner > 0.78) k += 1;
      if (h(b * 5 + Math.floor(inner * 4), y, 23) < 0.10) k += 1;   // 흐트러진 올
      if (y === yb) k += 2;                          // 잘린 밑동은 그늘에 잠긴다
      else if (y === yb - 1) k -= 1;                 // 그 위 한 줄이 빛을 문다
      g.px(x, y, LAD[clamp(Math.round(k), 0, 6)]);
    }
  }
  // 처마 밑 — 짚 끝이 삐죽 나오고 그 아래로 어둠이 깔린다
  for (let x = EAVE_X0; x <= EAVE_X1; x++) {
    const t = (EAVE_Y - RIDGE_Y) / SPAN;
    const xl = lerp(RIDGE_X0, EAVE_X0, t), xr = lerp(RIDGE_X1, EAVE_X1, t);
    const u = (x - xl) / (xr - xl);
    if (u < 0 || u > 1) continue;
    const b = Math.floor(clamp(u, 0, 0.9999) * NB);
    const yb = Math.round(bundleBot(0, b) - cornerCut(x));
    // 삐져나온 짚 — 처마 밑동에 붙은 자리에만. 둥근 귀퉁이에 찍으면
    // 실루엣에서 떨어져 나가고, 윤곽선이 둘러지며 **검은 티끌**이 된다.
    if (cornerCut(x) === 0 && g.get(x, yb) && h(x, 4, 61) < 0.3) g.px(x, yb + 1, C.thk);
  }
  // 용마름 — 마루를 덮어 묶은 짚 두루마리. 가로로 누운 원기둥이라
  // 위가 밝고 아랫단이 어둡다. 새끼줄로 군데군데 묶어 놓았다.
  const ROLL = [C.th3, C.th1, C.th0, C.th0, C.th1, C.th2, C.th3, C.th4, C.th5];
  // 마루를 넘어선 양 끝에서는 두루마리가 **지붕 빗변을 타고 내려가야** 한다.
  // 마루 높이에 그대로 두면 지붕이 이미 기울어 내려간 자리에서 두루마리만
  // 허공에 떠 버린다 (지붕과 용마름 사이에 하늘이 보였다).
  const rollTop = (x) => Math.max(RIDGE_Y + sagAt(clamp(x, RIDGE_X0, RIDGE_X1)), roofTop(x)) - 6;
  for (let x = RIDGE_X0 - 4; x <= RIDGE_X1 + 4; x++) {
    const top = Math.round(rollTop(x));
    const end = Math.min(x - (RIDGE_X0 - 4), (RIDGE_X1 + 4) - x);   // 양끝은 낮게 여민다
    for (let j = end < 3 ? 2 - end : 0; j < ROLL.length; j++) g.px(x, top + j, ROLL[j]);
    if (h(x, 0, 77) < 0.34) g.px(x, top + 2 + Math.floor(h(x, 1, 78) * 4), C.th2);
  }
  for (let x = RIDGE_X0 + 4; x < RIDGE_X1; x += 12) {              // 새끼줄
    const top = Math.round(rollTop(x));
    for (let j = 1; j < ROLL.length - 1; j++) {
      g.px(x, top + j, C.th4);
      g.px(x + 1, top + j, C.th5);
    }
    g.px(x, top + 2, C.th2);
  }
  // 이끼 — 볕이 덜 드는 처마 언저리에만. 지붕 한복판에 뿌리면 얼룩이 된다.
  // 납작한 타원이라야 「앉았다」로 보인다 (동그라미는 붙여 놓은 것 같다).
  //
  // 색은 **짚색 쪽으로 끌어당겨** 쓴다. 순수한 초록을 얹었더니 지붕에
  // 붙인 나뭇잎 스티커처럼 떠 버렸다. 이끼는 짚 위에 낀 것이지 짚 위에
  // 놓인 게 아니다 — 밑색이 비쳐야 낀 것으로 보인다.
  const mossy = (base, k) => [
    Math.round(lerp(base[0], k[0], 0.72)),
    Math.round(lerp(base[1], k[1], 0.72)),
    Math.round(lerp(base[2], k[2], 0.72)),
  ];
  for (const [mx, my, rx, ry] of [[15, 51, 8, 3], [98, 50, 7, 3], [58, 54, 5, 2]]) {
    for (let j = -ry; j <= ry; j++) for (let i = -rx; i <= rx; i++) {
      const d = (i * i) / (rx * rx) + (j * j) / (ry * ry);
      const base = g.get(mx + i, my + j);
      if (d > 1 || !base) continue;
      if (h(mx + i, my + j, 12) < 0.3 + d * 0.4) continue;   // 가장자리는 성기게
      g.px(mx + i, my + j, mossy(base, d < 0.34 ? C.mo0 : d < 0.74 ? C.mo1 : C.mo2));
    }
  }
  // 짚이 해진 자리 — 속이 비쳐 어둡다. 한 군데만 말한다.
  for (let j = 0; j < 6; j++) for (let i = 0; i < 11; i++) {
    const d = (i - 5) * (i - 5) / 30 + (j - 3) * (j - 3) / 10;
    if (d > 1 || h(i, j, 91) < 0.3) continue;
    if (g.get(30 + i, 34 + j)) g.px(30 + i, 34 + j, d < 0.5 ? C.thk : C.th5);
  }
  // 처마 그늘 — 지붕이 벽 위에 「얹혀 있다」로 읽히는 결정타.
  // 처마 밑동이 들쭉날쭉하니 그늘도 그 선을 따라가야 한다. 고정된 띠로
  // 깔면 어떤 자리는 지붕을, 어떤 자리는 허공을 어둡게 만든다.
  for (let x = WALL_X0 - 2; x <= WALL_X1 + 2; x++) {
    let yb = EAVE_Y + 5;
    while (yb > EAVE_Y - 8 && !g.get(x, yb)) yb--;      // 이 열의 짚 끝을 찾는다
    for (let j = 1; j <= 4; j++) g.shade(x, yb + j, 0.52 + j * 0.1);
  }
}

// ======================================================================
// 6. 굴뚝 — 진흙 바른 돌 굴뚝
// ======================================================================
// 굴뚝 — 돌을 쌓고 진흙을 바른 굴뚝.
// 처음엔 회색 돌로만 쌓았더니 따뜻한 짚·나무 옆에서 저 혼자 차가워,
// 집에 붙은 게 아니라 **집 옆에 세워 둔 것**처럼 보였다. 진흙을 발라
// 색을 이쪽으로 데려오고, 밑동을 넓혀 지붕에 뿌리내리게 한다.
// **짚보다 먼저** 그린다. 그러면 지붕이 굴뚝의 아랫도리를 알아서 덮어,
// 굴뚝이 지붕을 뚫고 나온 선이 저절로 맞는다.
// (앞서는 짚 뒤에 그려 놓고 뿌리께에 짚을 손으로 둘러 봤는데, 그 짚이
//  지붕의 빗변을 따라 흘러 **깃발 하나가 걸린 꼴**이 됐다. 겹침 순서로
//  풀리는 문제를 덧칠로 풀려 한 셈이다.)
function chimney() {
  const x0 = 64, w = 12, y0 = 2, y1 = 46;
  const D0 = [156, 134, 108], D1 = [128, 107, 84], D2 = [100, 82, 63], D3 = [72, 58, 44];
  for (let y = y0; y < y1; y++) {
    const flare = y > y1 - 10 ? Math.round((y - (y1 - 10)) * 0.35) : 0;  // 밑동이 벌어진다
    for (let i = -flare; i < w + flare; i++) {
      const u = (i + flare) / (w + flare * 2 - 1);
      g.px(x0 + i, y, u < 0.2 ? D0 : u < 0.62 ? D1 : u < 0.88 ? D2 : D3);
    }
  }
  // 진흙 밖으로 드러난 돌 — 몇 개만. 다 드러내면 돌담이지 굴뚝이 아니다.
  for (const [sx, sy, sw, sh_] of [[2, 12, 5, 4], [6, 19, 4, 3], [1, 25, 6, 4], [7, 27, 4, 3]]) {
    g.rect(x0 + sx, y0 + sy, sw, sh_, C.st2);
    g.hline(x0 + sx, x0 + sx + sw - 1, y0 + sy, C.st1);
    g.hline(x0 + sx, x0 + sx + sw - 1, y0 + sy + sh_ - 1, C.st3);
  }
  g.rect(x0 - 2, y0, w + 4, 4, D1);                 // 갓 — 처마처럼 조금 내민다
  g.hline(x0 - 2, x0 + w + 1, y0, D0);
  g.hline(x0 - 2, x0 + w + 1, y0 + 3, D3);
  g.rect(x0 + 2, y0, w - 4, 2, C.O);                // 그을린 아궁이 목
  for (let i = 3; i < w - 3; i++) g.px(x0 + i, y0 + 2, [58, 48, 44]);
  for (let j = 4; j < y1 - y0; j++) g.shade(x0 + w - 1 + (j > y1 - y0 - 10 ? 1 : 0), y0 + j, 0.82);
}

// 굴뚝이 용마름을 뚫고 나온 자리에 짚을 봉긋하게 여며 올린다.
// 짚을 다 덮은 **뒤에** 부르는 마무리 — 맞물린 선을 부드럽게 눌러 준다.
//
// 굴뚝 자리를 지붕 오른쪽 빗면에서 **마루 위**로 옮겼다. 빗면에 세우면
// 굴뚝이 지붕 실루엣 바깥으로 삐져나와 허공에 뜬다 — 정면에서 본
// 우진각지붕은 오른쪽으로 갈수록 지붕 끝이 가팔라 내려오기 때문이다.
// 마루 위라면 어디에 세워도 지붕 안이다. 대신 굴뚝이 보이려면 마루보다
// 높이 솟아야 해서, 캔버스를 여덟 줄 늘려 머리 위 자리를 냈다.
function chimneySkirt() {
  const x0 = 64, w = 12;
  for (let x = x0 - 4; x <= x0 + w + 3; x++) {
    if (x >= x0 && x < x0 + w) continue;            // 굴뚝 몸통은 건드리지 않는다
    const top = Math.round(Math.max(RIDGE_Y + sagAt(clamp(x, RIDGE_X0, RIDGE_X1)), roofTop(x)) - 6);
    const dx = Math.abs(x - (x0 + w / 2)) / (w / 2 + 4);
    for (let j = -Math.round((1 - dx * dx) * 4); j < 2; j++)
      g.px(x, top + j, j < -2 ? C.th2 : j < 1 ? C.th1 : C.th3);
  }
}

// ======================================================================
// 7. 살림살이 — 사람이 산다는 표시
// ======================================================================
// 장작더미 — 마구리(자른 단면)가 이쪽을 본다. 통나무는 **둥글다**:
// 네모로 쌓으면 벽돌더미가 되고, 그러면 벽에 벽이 하나 더 붙은 꼴이다.
function firewood(x0, y0) {
  for (let row = 0; row < 2; row++) {
    const y = y0 - row * 8;
    const n = 3 - row;
    for (let i = 0; i < n; i++) {
      const cx = x0 + i * 9 + row * 5, cy = y;
      const r = 3 + (h(i, row, 45) < 0.4 ? 1 : 0);
      for (let j = -r; j <= r; j++) for (let k = -r; k <= r; k++) {
        const d = (j * j + k * k) / (r * r);
        if (d > 1.15) continue;
        // 껍질은 어둡고 쪼갠 속살은 밝다 — 그 대비가 「장작」이다
        g.px(cx + k, cy + j, d > 0.72 ? C.wd4 : d > 0.42 ? C.nw1 : C.nw0);
      }
      for (let k = -r; k <= r; k += 2) g.px(cx + k, cy + Math.round(k * 0.4), C.wd2);  // 결
      g.px(cx - 1, cy - 1, C.nw0);
    }
  }
  g.hline(x0 - 5, x0 + 22, y0 + 4, C.sh);
}

// 물독 — 질그릇. 어깨가 가장 넓고 밑동은 그 절반쯤에서 평평하게 앉는다.
// (처음엔 사인 곡선으로 그렸다가 밑이 뾰족한 물방울이 나왔다. 항아리는
//  땅에 놓이는 물건이라 밑이 **평평해야** 놓인 것으로 보인다.)
function waterJar(cx, by) {
  const PROF = [5, 7, 8, 9, 9, 9, 8, 8, 7, 7, 6, 6, 6, 6];   // 위→아래 반지름
  for (let j = 0; j < PROF.length; j++) {
    const w = PROF[j], y = by - PROF.length + 1 + j;
    for (let i = -w; i <= w; i++) {
      const u = (i + w) / (2 * w);
      g.px(cx + i, y, u < 0.22 ? C.cl0 : u < 0.62 ? C.cl1 : C.cl2);
    }
    g.px(cx - w, y, C.O); g.px(cx + w, y, C.O);
    if (j === 2) g.hline(cx - w + 1, cx + w - 1, y, C.cl2);   // 어깨의 띠
  }
  g.rect(cx - 6, by - PROF.length - 2, 13, 3, C.wd2);         // 나무 뚜껑
  g.hline(cx - 6, cx + 6, by - PROF.length - 2, C.wd0);
  g.hline(cx - 6, cx + 6, by - PROF.length, C.bm2);
  g.hline(cx - 8, cx + 8, by + 1, C.sh);
}

function weeds() {                   // 기단 밑동의 풀 — 손이 안 가는 집
  for (const x0 of [12, 20, 46, 74, 92, 100, 104]) {
    const n = 3 + Math.floor(h(x0, 0, 67) * 3);
    for (let i = 0; i < n; i++) {
      const x = x0 + i - (n >> 1);
      const hh = 3 + Math.floor(h(x, 1, 68) * 4);
      for (let j = 0; j < hh; j++)
        g.px(x + Math.round((j / hh) * (i - (n >> 1)) * 0.8), GROUND - j, j > hh - 3 ? C.gr0 : C.gr1);
    }
  }
}

// ======================================================================
// 조립 — 뒤에 있는 것부터
// ======================================================================
footing();
wall();
window_(28, 66, 16, 14);
door(54, 68, 22, 32);
lintel(48, 82, 62);
chimney();
thatch();
chimneySkirt();
firewood(10, 96);
waterJar(101, 100);

// 실루엣 윤곽 — 풀밭 위에 얹혔을 때 형태가 뭉개지지 않게 테두리를 두른다
{
  const src = g.d.slice();
  const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H) ? null : src[y * W + x];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (at(x, y)) continue;
    if (at(x - 1, y) || at(x + 1, y) || at(x, y - 1) || at(x, y + 1)) g.px(x, y, C.O);
  }
}
// 풀은 윤곽선 뒤에 심는다 — 검은 테를 두르면 풀잎이 아니라 철사가 된다
weeds();

fs.writeFileSync(OUT + 'chief_hut.png', PNG.sync.write(g.render(DOT)));
console.log(`chief_hut.png ${W * DOT}x${H * DOT} (논리 ${W}x${H} 도트, sc=0.5로 화면 ${W * 2}x${H * 2}px)`);
