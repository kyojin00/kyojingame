// 마당에 **세워 두는 것들** — 화로 · 모루 · 여물통 · 장작더미 · 그물 틀 …
//
// 왜 그리는가 —
//   가게 마당에 광석·못·천 따위를 늘어놓고 있었다. 그런데 그것들은 전부
//   **가방 아이콘**이다. 32px 네모 안에 물건 하나가 딱 들어차게 그린 그림이라,
//   땅에 놓으면 「거기 서 있는 물건」이 아니라 「누가 떨어뜨리고 간 물건」으로
//   보인다. 밑변도 그림자도 없으니 바닥에 붙지도 않는다.
//
//   마당에 놓을 것은 아이콘이 아니라 **살림**이다. 모루는 그루터기에 얹혀
//   있고, 여물통에는 물이 담겨 있고, 장작은 쌓여 있다. 그래서 따로 그린다.
//
// 그리는 규칙은 건물·바닥과 같다 —
//   톤 사다리   재료마다 예닐곱 단. 한 자로 재야 물건들이 한 바닥에 놓인다
//   윗변은 빛   위를 보는 면은 한 단 밝게, 아랫변은 두 단 어둡게 (턱)
//   밑그림자    바닥에 닿는 자리에 반투명 그늘. 이게 없으면 물건이 뜬다
//
// 도트 크기: 논리 한 칸 = 4px. 게임에서 0.5배로 얹으므로 화면에서 2px —
// 사람·집·바닥과 정확히 같다 (object_nodes 가 `deco_` 살림을 0.5로 못박는다).
//
// 숫돌과 통은 그렸다가 **뺐다.** 화면에서 열여섯 도트로 줄어들면 숫돌은
// 벽시계가 되고 통은 쓰레기통이 된다 — 무엇인지 모를 물건은 마당을
// 어지럽힐 뿐이다. 한 칸에 담기려면 **윤곽만으로 이름이 나와야** 한다.
//
// **화로만 여러 장이다.** 불은 흔들려야 불이다. 네 장을 돌려 찍는다
// (main.LANDMARK_FRAMES 에 {"deco_forge": 4} 로 적어 두면 알아서 돈다).
//
// 실행:  node make_props.js            -> ref/proposed_deco_*.png (제안만)
//        node make_props.js --install  -> sprites/ 에 넣는다
//                                         (뒤에 python3 make_import.py)
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');
const S = 4;                     // 논리 한 칸 = 원본 4px

function h(x, y, k) {
  let n = (x * 73856093) ^ (y * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// ---- 톤 사다리 ----
// 나무는 울타리(make_fence.js)와, 돌은 바닥(make_ground.js)과 같은 줄기다
const W = [[216, 164, 100], [192, 138, 78], [166, 112, 58], [140, 90, 44],
           [112, 68, 32], [86, 50, 24], [58, 34, 16]];
const ST = [[214, 202, 178], [194, 180, 156], [174, 160, 138], [154, 141, 120],
            [132, 120, 102], [108, 98, 84], [84, 76, 66], [62, 56, 50]];
// 쇠 — 돌보다 **푸른 쪽**으로 민다. 회색끼리 두면 모루가 돌덩이로 보인다
const IR = [[186, 194, 206], [146, 154, 168], [104, 112, 128], [70, 78, 92],
            [42, 48, 60]];
// 불 — 속은 희고 겉으로 갈수록 붉다. 다섯 단이 있어야 「타오른다」가 된다
const FI = [[255, 246, 206], [255, 212, 104], [250, 156, 44], [214, 84, 26],
            [148, 44, 18]];
const STRAW = [[238, 216, 150], [208, 184, 118], [172, 148, 84], [130, 108, 58]];
const NET = [[226, 218, 196], [186, 176, 150], [140, 130, 106]];
const LEAF = [[140, 200, 96], [92, 162, 66], [48, 102, 44]];
const BLOOM = [[244, 128, 148], [250, 212, 100], [238, 244, 238]];
const AQUA = [[132, 198, 226], [92, 160, 202], [58, 118, 168]];
const PAPER = [[236, 226, 200], [200, 186, 152], [152, 138, 106]];
const BOOK = [[196, 76, 62], [64, 108, 150], [86, 130, 76], [176, 140, 68]];
// 화로의 돌 — **불에 그을린 검붉은 돌.** 길바닥 자갈(ST)과 같은 사다리를
// 썼더니, 자갈 마당에 얹은 순간 바닥과 한 덩어리가 돼 화로가 안 보였다.
// 화로는 하루 종일 불을 때는 물건이라 돌이 검게 그을리는 게 맞기도 하다
const FG = [[152, 112, 92], [126, 90, 72], [100, 70, 56], [78, 52, 42],
            [58, 38, 32], [42, 28, 24]];
// 마대 자루 — 나무도 짚도 아닌 거친 삼베. 궤짝 옆에 놓으면 재료가 갈린다
const SACK = [[214, 192, 152], [186, 162, 122], [154, 132, 96], [118, 98, 68]];
// 광석 덩이 — **쇠보다 어둡고 푸르다.** 길바닥 자갈로 그렸더니 마당에서
// 회색 얼룩이었다. 부순 광석은 검고, 깨진 면에서만 쇳빛이 번쩍인다
const ORE = [[112, 122, 138], [86, 94, 110], [62, 70, 84], [42, 48, 60],
             [28, 32, 42]];
const ORE_LIT = [[196, 214, 232], [150, 172, 198]];
const OUT = [38, 26, 20];
const SHADOW = [30, 26, 34, 78];

class P {
  constructor(w, hh) {
    this.w = w; this.h = hh;
    this.d = Array.from({ length: hh }, () => new Array(w).fill(null));
  }
  px(x, y, c) {
    if (!c) return;
    x = Math.round(x); y = Math.round(y);
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.d[y][x] = c;
  }
  get(x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return null;
    return this.d[y][x];
  }
  hline(x0, x1, y, c) { for (let x = x0; x <= x1; x++) this.px(x, y, c); }
  vline(x, y0, y1, c) { for (let y = y0; y <= y1; y++) this.px(x, y, c); }
  rect(x0, y0, x1, y1, c) {
    for (let y = y0; y <= y1; y++) this.hline(x0, x1, y, c);
  }
  // 속을 채운 타원 — 통의 배, 장작의 마구리, 바닥 그늘에 두루 쓴다
  disc(cx, cy, rx, ry, c) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++)
        if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0) this.px(x, y, c);
  }
  // 바닥 그늘 — 물건이 땅에 **닿아 있다**는 유일한 표시
  ground(cx, cy, rx, ry) { this.disc(cx, cy, rx, ry, SHADOW); }
  render() {
    const im = new PNG({ width: this.w * S, height: this.h * S });
    im.data.fill(0);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      const a = c.length > 3 ? c[3] : 255;
      for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
        const i = ((y * S + sy) * this.w * S + (x * S + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2];
        im.data[i + 3] = a;
      }
    }
    return im;
  }
}

// ---- 되풀이해 쓰는 조각들 ----

// 널판 한 장 — 윗변은 빛, 속에 결, 아랫변은 턱. 나무는 다 이 규칙이다
function plank(g, x0, x1, y0, y1, seed, pal) {
  const t = pal || W;
  g.rect(x0, y0, x1, y1, t[3]);
  g.hline(x0, x1, y0, t[1]);
  g.hline(x0, x1, y1, t[5]);
  for (let x = x0; x <= x1; x++) {
    if (h(x, y0, seed) < 0.24) g.px(x, y0 + 1, t[4]);
    if (h(x, y1, seed + 3) < 0.16) g.px(x, y1 - 1, t[2]);
  }
}

// 쌓은 돌 한 덩이 — 켜마다 반 칸씩 어긋나고 줄눈이 한 칸
function stonework(g, x0, x1, y0, y1, seed, pal) {
  const t = pal || ST;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const course = Math.floor((y - y0) / 3);
    const col = Math.floor((x - x0 + (course % 2) * 2) / 4);
    let i = 1 + Math.floor(h(col, course, seed) * 3.0);
    if ((y - y0) % 3 === 0) i -= 1;                 // 윗줄 = 빛
    if ((y - y0) % 3 === 2) i += 2;                 // 아랫줄 = 줄눈
    if ((x - x0 + (course % 2) * 2) % 4 === 3) i += 2;
    g.px(x, y, t[clamp(i, 0, t.length - 1)]);
  }
}


// ---- 윤곽선 ----
//
// 바닥이 무슨 색이든 물건이 **떠 보여야** 한다. 자갈 마당에 회색 화로를
// 얹었더니 바닥과 한 덩어리가 됐다 — 색만 바꿔서는 다음번 바닥에서
// 또 같은 일이 난다. 건물 그림이 굵은 윤곽선을 쓰는 것과 같은 이유다.
//
// 그늘(반투명)은 물건이 아니므로 선을 안 두른다. 이미 그늘이 깔린 칸도
// 건드리지 않는다 — 밑변에 새까만 테가 둘리면 물건이 땅에서 다시 뜬다
function outline(g) {
  const add = [];
  for (let y = 0; y < g.h; y++) for (let x = 0; x < g.w; x++) {
    if (g.d[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
      const c = g.get(x + dx, y + dy);
      if (c && c.length < 4) { near = true; break; }
    }
    if (near) add.push([x, y]);
  }
  for (const [x, y] of add) g.px(x, y, OUT);
  return g;
}

// 쇠테 한 줄 — 통·여물통을 묶는다
function hoop(g, x0, x1, y) {
  g.hline(x0, x1, y, IR[1]);
  g.hline(x0, x1, y + 1, IR[3]);
}

// ---- 화로 ----
//
// 대장간 곁에 서서 **불이 보이는** 것. 지금까지는 돌무지(deco_cairn)를
// 갖다 놨는데 그건 돌을 쌓아 둔 무더기지 화로가 아니었다 — 불이 없으니
// 대장간인지 채석장인지 알 수가 없었다.
//
// 세 부분으로 그린다.
//   ① 돌 아궁이  쌓은 돌. 아가리는 어둡고 그 안에 숯불이 벌겋다
//   ② 쇠 굴뚝    아가리 위로 좁아지며 올라가는 후드와 연통
//   ③ 불         아가리에서 굴뚝 밑까지 솟는다. **장마다 다르게 흔들린다**
const FW = 24, FH = 30;

function flame(g, cx, base, hgt, f, seed) {
  for (let k = 0; k < hgt; k++) {
    const t = k / hgt;
    // 밑동은 굵고 끝은 한 점. 장마다 다른 결로 흔들린다
    const wide = (1 - t) * 3.4 + Math.sin((k * 0.8) + f * 1.9 + seed) * 0.85;
    const wd = Math.max(0, Math.round(wide));
    const sway = Math.round(Math.sin(k * 0.55 + f * 1.7 + seed) * 1.6 * t);
    for (let dx = -wd; dx <= wd; dx++) {
      let c;
      if (Math.abs(dx) === wd) c = t > 0.55 ? FI[4] : FI[3];
      else if (t > 0.62) c = FI[2];
      else if (t > 0.28) c = FI[1];
      // **속불은 심지처럼 가늘게.** 밑동을 통째로 제일 밝은 단으로
      // 칠했더니 아궁이 안에 흰 종이 뭉치가 든 것처럼 보였다
      else c = Math.abs(dx) <= 1 ? FI[0] : FI[1];
      g.px(cx + dx + sway, base - k, c);
    }
  }
  // 튀는 불티 — 굴뚝 쪽으로 서너 점
  for (let i = 0; i < 4; i++) {
    const sx = cx + Math.round(Math.sin(i * 2.1 + f * 1.3) * 4);
    const sy = base - hgt - 1 - ((i * 3 + f * 2) % 7);
    g.px(sx, sy, i % 2 === 0 ? FI[1] : FI[2]);
  }
}

function forge(f) {
  const g = new P(FW, FH);
  g.ground(12, 28, 10, 2.2);
  // ② 쇠 후드와 연통 — 먼저 그리고 돌로 덮는다 (아궁이가 앞이다)
  for (let y = 10; y <= 17; y++) {
    const inset = Math.round((17 - y) * 0.55);
    g.rect(5 + inset, y, 18 - inset, y, IR[3]);
    g.px(5 + inset, y, IR[2]);
    g.px(18 - inset, y, IR[4]);
  }
  g.rect(10, 2, 14, 10, IR[3]);
  g.vline(10, 2, 10, IR[2]);
  g.vline(14, 2, 10, IR[4]);
  g.hline(9, 15, 2, IR[2]);          // 연통 갓
  g.hline(9, 15, 3, IR[4]);
  for (let y = 4; y <= 9; y++) if (h(y, f, 11) < 0.3) g.px(12, y, IR[3]);
  // ① 돌 아궁이
  stonework(g, 3, 20, 17, 28, 5, FG);
  g.hline(3, 20, 17, FG[0]);         // 상판 — 위를 보는 면
  g.hline(3, 20, 18, FG[2]);
  g.hline(3, 20, 28, FG[5]);         // 밑동
  // 아가리 — 안쪽은 그을려 새까맣다
  g.rect(8, 20, 15, 27, [26, 18, 16]);
  g.hline(8, 15, 20, OUT);
  g.px(8, 20, FG[5]); g.px(15, 20, FG[5]);
  // 아가리 둘레는 불빛에 물든다 — 그을린 돌 위의 벌건 테
  for (let y = 21; y <= 26; y++) { g.px(7, y, FG[1]); g.px(16, y, FG[1]); }
  g.px(7, 24, FI[4]); g.px(16, 24, FI[4]);
  // 숯불 — 아가리 바닥에 깔린다. 장마다 벌겋고 어둡고
  for (let x = 8; x <= 15; x++) {
    const v = h(x, f, 17);
    g.px(x, 27, v < 0.45 ? FI[3] : FI[4]);
    if (v < 0.30) g.px(x, 26, FI[2]);
    if (v > 0.86) g.px(x, 26, FI[1]);
  }
  // ③ 불
  flame(g, 11 + (f % 2), 26, 11 + (f % 3), f, 0);
  flame(g, 13, 27, 7 + ((f + 1) % 3), f, 2.4);
  // 아가리에서 새어 나온 빛이 돌 상판을 물들인다
  for (let x = 7; x <= 16; x++) {
    if (h(x, f, 23) < 0.6) g.px(x, 19, FI[4]);
    if (h(x, f, 29) < 0.3) g.px(x, 18, FI[4]);
  }
  return outline(g);
}

// ---- 모루 ----
//
// 대장간이라는 말을 한 칸으로 하는 물건. 그루터기에 얹어 놓는다 —
// 땅바닥에 그냥 두면 쇳덩이 하나가 굴러다니는 것으로 보인다
function anvil() {
  const g = new P(16, 15);
  g.ground(8, 13, 6, 1.8);
  // 그루터기
  g.rect(4, 8, 11, 13, W[4]);
  g.hline(4, 11, 8, W[2]);
  g.hline(4, 11, 13, W[6]);
  for (let y = 9; y <= 12; y++) if (h(y, 3, 31) < 0.5) g.px(5 + (y % 3), y, W[5]);
  // 모루 — 상판 · 잘록한 허리 · 밑굽
  g.rect(3, 4, 12, 5, IR[2]);
  g.hline(3, 12, 4, IR[0]);          // 두들기는 면 (반들반들하다)
  g.hline(3, 12, 6, IR[3]);
  g.px(2, 5, IR[2]); g.px(1, 5, IR[3]);   // 뿔
  g.rect(6, 6, 9, 8, IR[3]);
  g.rect(4, 9, 11, 9, IR[2]);
  g.hline(4, 11, 10, IR[4]);
  g.px(12, 4, IR[1]);                // 꽁무니의 각진 구멍 자리
  g.px(11, 5, IR[4]);
  return outline(g);
}


// ---- 장작더미 ----
// 마구리(잘린 면)가 보이게 쌓는다 — 나이테 한 줄이면 통나무가 된다
function logpile() {
  const g = new P(20, 14);
  g.ground(10, 12, 9, 1.8);
  const put = (cx, cy, r, s) => {
    g.disc(cx, cy, r, r * 0.92, W[3]);
    g.disc(cx, cy, r * 0.62, r * 0.56, W[2]);
    g.disc(cx, cy, r * 0.24, r * 0.22, W[4]);
    for (let a = 0; a < 14; a++) {
      const t = a / 14 * Math.PI * 2;
      g.px(cx + Math.cos(t) * r, cy + Math.sin(t) * r * 0.92,
        Math.sin(t) < -0.2 ? W[2] : W[5]);          // 윗변은 빛, 아랫변은 턱
    }
    if (h(cx, cy, s) < 0.5) g.px(cx + 1, cy - 1, W[1]);
  };
  const rows = [[3, 11, 4], [8, 11, 4], [13, 11, 4], [17, 11, 3],
                [5, 7, 3], [11, 7, 4], [16, 7, 3],
                [8, 3, 3], [13, 4, 3]];
  for (const [x, y, r] of rows) put(x, y, r * 0.62, x + y);
  return outline(g);
}

// ---- 여물통 ----
// 목장에도 대장간에도 놓는다 (담금질통). 안에 물이 찰랑거린다
function trough(wet) {
  const g = new P(20, 12);
  g.ground(10, 10, 9, 1.6);
  plank(g, 1, 18, 4, 10, 41);
  g.hline(1, 18, 3, W[2]);           // 아가리 테
  g.rect(2, 4, 17, 6, wet ? AQUA[1] : STRAW[2]);
  if (wet) {
    g.hline(2, 17, 4, AQUA[0]);
    for (let x = 3; x <= 16; x += 3) g.px(x, 5, AQUA[0]);
    g.hline(2, 17, 6, AQUA[2]);
  } else {
    for (let x = 2; x <= 17; x++) {
      if (h(x, 1, 43) < 0.5) g.px(x, 4, STRAW[0]);
      if (h(x, 2, 45) < 0.4) g.px(x, 5, STRAW[1]);
      if (h(x, 3, 47) < 0.4) g.px(x, 6, STRAW[3]);
    }
  }
  hoop(g, 4, 5, 7); hoop(g, 14, 15, 7);
  g.hline(1, 18, 11, W[6]);
  return outline(g);
}

// ---- 볏단 ----
// 목장의 여물. 낟알 결이 세로로 흐르고 새끼줄 두 가닥으로 묶는다
function hay() {
  const g = new P(18, 14);
  g.ground(9, 12, 8, 1.6);
  // **네모로 묶는다.** 둥근 덩어리로 그렸더니 형체가 안 잡혀 잔디 위에
  // 허연 얼룩 하나로 보였다 — 볏단인지 돌인지 알 수가 없었다.
  g.rect(2, 4, 15, 12, STRAW[2]);
  g.hline(2, 15, 4, STRAW[0]);        // 윗면 = 빛
  g.hline(2, 15, 5, STRAW[1]);
  g.hline(2, 15, 12, STRAW[3]);       // 밑변 = 턱
  g.vline(2, 4, 12, STRAW[1]);
  g.vline(15, 4, 12, STRAW[3]);
  // 지푸라기 결 — 세로로 흐른다
  for (let x = 2; x <= 15; x++) for (let y = 6; y <= 11; y++) {
    const v = h(x, y, 51);
    if (v < 0.22) g.px(x, y, STRAW[3]);
    else if (v > 0.84) g.px(x, y, STRAW[1]);
  }
  // 삐져나온 오라기 몇 가닥 — 묶음이 팽팽하다는 표시
  for (let i = 0; i < 7; i++) {
    const x = 2 + Math.floor(h(i, 1, 55) * 14);
    g.px(x, 3, STRAW[1]);
    if (h(i, 2, 57) < 0.5) g.px(x + 1, 3, STRAW[2]);
  }
  // 새끼줄 두 가닥
  for (const bx of [5, 12]) {
    g.vline(bx, 4, 12, W[4]);
    g.vline(bx + 1, 4, 12, W[5]);
  }
  return outline(g);
}

// ---- 그물 말리는 틀 ----
// 이 한 칸이면 수산시장이다. 장대 둘에 그물이 걸려 늘어진다
function netrack() {
  const g = new P(22, 22);
  g.ground(11, 20, 9, 1.8);
  g.vline(2, 3, 20, W[4]); g.vline(3, 3, 20, W[3]);
  g.vline(18, 3, 20, W[4]); g.vline(19, 3, 20, W[3]);
  g.hline(1, 20, 3, W[2]); g.hline(1, 20, 4, W[4]);
  // 그물 — 마름모 코. 아래로 갈수록 늘어져 벌어진다
  for (let y = 5; y <= 17; y++) {
    const sag = Math.round((y - 5) * 0.28);
    for (let x = 4; x <= 17; x++) {
      const u = x + sag, v = y;
      if ((u + v) % 3 === 0 || (u - v + 30) % 3 === 0)
        g.px(x, y, y > 13 ? NET[2] : NET[1]);
    }
  }
  g.hline(4, 17, 17, NET[2]);
  for (let x = 5; x <= 16; x += 4) {   // 뜸 (부표)
    g.disc(x, 18, 1.4, 1.2, W[2]);
    g.px(x, 17, W[1]);
  }
  return outline(g);
}


// ---- 화단 ----
// 길게 짠 나무 상자에 흙을 채우고 꽃을 심었다. 여관·회관·도서관 앞
function planter() {
  const g = new P(20, 13);
  g.ground(10, 11, 9, 1.6);
  plank(g, 1, 18, 6, 11, 71);
  g.rect(2, 4, 17, 5, [112, 88, 64]);
  for (let x = 2; x <= 17; x++) if (h(x, 4, 73) < 0.4) g.px(x, 4, [92, 70, 50]);
  // 잎과 꽃 — 상자 위로 봉긋하게
  for (let i = 0; i < 16; i++) {
    const x = 2 + i, hgt = 2 + Math.round(h(i, 1, 75) * 2);
    for (let k = 0; k < hgt; k++)
      g.px(x, 3 - k, k === hgt - 1 ? LEAF[0] : LEAF[1]);
    if (h(i, 2, 77) < 0.22) {
      const c = BLOOM[Math.floor(h(i, 3, 79) * 3) % 3];
      g.px(x, 3 - hgt, c); g.px(x + 1, 3 - hgt, c);
    }
  }
  g.hline(1, 18, 12, W[6]);
  return outline(g);
}

// ---- 손수레 ----
// 짐이 오간다는 표시. 우체국·잡화점 마당
function cart() {
  const g = new P(22, 16);
  g.ground(11, 14, 9, 1.6);
  plank(g, 3, 18, 4, 9, 81);
  g.hline(3, 18, 3, W[1]);
  g.rect(4, 5, 17, 8, W[4]);          // 짐칸 속
  for (let x = 5; x <= 16; x += 4) g.vline(x, 5, 8, W[5]);
  g.hline(3, 18, 10, W[5]);
  g.vline(19, 6, 9, W[3]); g.vline(20, 7, 9, W[4]);   // 손잡이
  for (const cx of [7, 15]) {          // 바퀴
    g.disc(cx, 12, 3.2, 3.2, W[5]);
    g.disc(cx, 12, 2.4, 2.4, W[3]);
    g.disc(cx, 12, 0.9, 0.9, IR[3]);
    for (let a = 0; a < 6; a++) {
      const t = a / 6 * Math.PI * 2;
      g.px(cx + Math.cos(t) * 1.8, 12 + Math.sin(t) * 1.8, W[5]);
    }
  }
  return outline(g);
}

// ---- 책 무더기 ----
// 도서관 마당. 아이콘 한 장이 아니라 **쌓인 것**이라야 내놓은 책이 된다
function bookstack() {
  const g = new P(14, 12);
  g.ground(7, 10, 6, 1.4);
  const rows = [[1, 10, 12], [2, 8, 11], [1, 6, 12], [3, 4, 10]];
  rows.forEach(([x0, y, x1], i) => {
    const c = BOOK[i % 4];
    g.rect(x0, y - 1, x1, y, c);
    g.hline(x0, x1, y - 1, c.map(v => Math.min(255, v + 34)));
    g.hline(x0, x1, y + 1, c.map(v => Math.round(v * 0.55)));
    g.vline(x0, y - 1, y, PAPER[1]);   // 책배
    g.px(x1, y, PAPER[2]);
  });
  g.rect(4, 1, 9, 2, PAPER[0]);        // 맨 위 펼쳐 둔 책
  g.hline(4, 9, 3, PAPER[2]);
  g.px(6, 2, PAPER[2]); g.px(7, 2, PAPER[2]);
  return outline(g);
}

// ---- 표본 선반 ----
// 연구소 마당. 유리병에 담아 세워 둔 것들
function specimen() {
  const g = new P(18, 18);
  g.ground(9, 16, 8, 1.6);
  g.vline(2, 4, 16, W[4]); g.vline(15, 4, 16, W[4]);
  for (const sy of [9, 15]) { g.hline(1, 16, sy, W[2]); g.hline(1, 16, sy + 1, W[5]); }
  g.hline(1, 16, 4, W[2]); g.hline(1, 16, 5, W[5]);
  const jar = (x, y, c) => {
    g.rect(x, y - 3, x + 2, y, AQUA[2]);
    g.rect(x, y - 3, x + 2, y, [c[0], c[1], c[2]]);
    g.vline(x, y - 3, y, AQUA[0]);
    g.hline(x, x + 2, y - 4, IR[1]);   // 마개
    g.px(x + 2, y - 1, AQUA[2]);
  };
  jar(3, 8, AQUA[1]); jar(7, 8, LEAF[1]); jar(11, 8, BLOOM[1]);
  jar(4, 14, [168, 120, 200]); jar(9, 14, AQUA[0]);
  g.px(13, 13, ST[2]); g.px(14, 14, ST[4]);   // 돌 표본 한 점
  g.px(13, 14, ST[3]);
  return outline(g);
}


// ---- 나무 궤짝 ----
//
// 가게 마당에 제일 많이 놓이는 것. 예전에는 가방 아이콘(old_box·chest)을
// 그대로 갖다 놨는데, 그건 **뚜껑 열린 보물상자**라 어느 가게에 놓아도
// 「누가 보물을 두고 갔나」가 됐다. 짐은 판때기를 못으로 친 궤짝이다.
function crate() {
  const g = new P(16, 15);
  g.ground(8, 13, 7, 1.6);
  g.rect(2, 6, 13, 13, W[3]);
  g.hline(2, 13, 6, W[1]);            // 뚜껑 윗면 = 빛
  g.hline(2, 13, 7, W[2]);
  g.hline(2, 13, 13, W[6]);           // 밑변 턱
  for (let x = 4; x <= 12; x += 3) g.vline(x, 8, 12, W[5]);   // 판 사이
  for (let x = 2; x <= 13; x++) if (h(x, 6, 91) < 0.22) g.px(x, 9 + (x % 3), W[4]);
  g.vline(2, 6, 13, W[2]); g.vline(13, 6, 13, W[5]);
  hoop(g, 2, 13, 8);                  // 쇠띠 한 줄
  g.rect(5, 2, 11, 5, W[3]);          // 위에 얹은 작은 궤짝
  g.hline(5, 11, 2, W[1]);
  g.hline(5, 11, 5, W[5]);
  g.vline(8, 3, 5, W[5]);
  g.px(5, 3, W[2]); g.px(11, 4, W[5]);
  return outline(g);
}


// ---- 마대 자루 ----
//
// 궤짝만 늘어놓으면 마당이 네모투성이가 된다. 자루는 **둥글고 늘어져**
// 있어서, 같은 짐인데도 옆에 놓으면 둘 다 살아난다
function sack() {
  const g = new P(18, 14);
  g.ground(9, 12, 8, 1.6);
  // 동그란 덩어리 셋으로 그렸더니 허연 얼룩 하나로 뭉쳤다. 자루는 **서
  // 있는 것**이다 — 아래로 벌어지는 배와, 오므려 묶은 목이 있어야 한다
  const one = (x0, x1, top, seed) => {
    const cx = Math.round((x0 + x1) / 2);
    for (let y = top; y <= 12; y++) {
      const t = (y - top) / (12 - top);
      const w = Math.round((x1 - x0) / 2 * (0.44 + t * 0.56));
      for (let x = cx - w; x <= cx + w; x++) {
        let c = SACK[1];
        if (x <= cx - w + 1) c = SACK[0];          // 왼쪽 = 빛
        if (x >= cx + w - 1) c = SACK[2];          // 오른쪽 = 그늘
        if (y >= 12) c = SACK[3];                  // 밑변 턱
        g.px(x, y, c);
      }
      if (h(y, seed, 93) < 0.35) g.px(cx - 1, y, SACK[2]);   // 주름
    }
    g.rect(cx - 1, top - 2, cx + 1, top - 1, SACK[2]);       // 오므린 목
    g.hline(cx - 2, cx + 2, top - 1, W[4]);                  // 새끼줄
    g.px(cx, top - 3, SACK[0]);
  };
  one(1, 8, 6, 3);
  one(10, 17, 5, 9);
  return outline(g);
}


// ---- 광석 더미 ----
//
// 캐 온 것을 부려 놓은 자리. 회색 돌로 그렸더니 자갈 바닥과 한 값이라
// 안 보였다 — 부순 광석은 **검고**, 깨진 면에서만 쇳빛이 번쩍인다
function orepile() {
  const g = new P(18, 12);
  g.ground(9, 10, 8, 1.6);
  const chunk = (cx, cy, r, seed) => {
    for (let y = Math.round(cy - r); y <= Math.round(cy + r); y++)
      for (let x = Math.round(cx - r - 1); x <= Math.round(cx + r + 1); x++) {
        const d = Math.abs(x - cx) * 0.8 + Math.abs(y - cy);
        if (d > r + h(x, y, seed) * 0.8) continue;
        let c = ORE[2];
        if (y <= cy - r + 1) c = ORE[1];               // 윗면 = 빛
        if (y >= cy + r - 0.5) c = ORE[4];             // 아랫변 = 턱
        g.px(x, y, c);
      }
    // 깨진 면 — 한두 점만. 많으면 광석이 아니라 별이 된다
    if (h(cx, cy, seed + 3) < 0.75) g.px(cx, Math.round(cy - r + 1), ORE_LIT[0]);
    if (h(cx, cy, seed + 7) < 0.45) g.px(cx + 1, cy, ORE_LIT[1]);
  };
  chunk(4, 9, 2.4, 11); chunk(9, 9, 2.8, 17); chunk(14, 9, 2.2, 23);
  chunk(6, 5, 2.2, 29); chunk(11, 5, 2.4, 31);
  chunk(9, 2, 2.0, 37);
  return outline(g);
}


// ---- 연장 걸이 ----
//
// 대장간·잡화점 앞. 망치와 집게가 걸려 있으면 「여기서 만든다」가 된다
function toolrack() {
  const g = new P(16, 18);
  g.ground(8, 16, 7, 1.6);
  g.vline(2, 3, 16, W[4]); g.vline(3, 3, 16, W[3]);
  g.vline(12, 3, 16, W[4]); g.vline(13, 3, 16, W[3]);
  g.hline(1, 14, 3, W[1]); g.hline(1, 14, 4, W[5]);
  g.hline(1, 14, 16, W[5]);
  g.vline(5, 6, 12, W[4]);            // 망치 자루
  g.rect(4, 5, 7, 7, IR[2]);
  g.hline(4, 7, 5, IR[1]); g.hline(4, 7, 7, IR[4]);
  g.vline(9, 6, 9, IR[2]); g.vline(11, 6, 9, IR[2]);   // 집게
  g.px(9, 10, IR[3]); g.px(10, 11, IR[3]); g.px(11, 10, IR[3]);
  g.px(10, 5, IR[1]);
  for (const hx of [5, 10]) {         // 편자 둘
    for (let a = 2; a <= 10; a++) {
      const t = a / 12 * Math.PI * 2;
      g.px(hx + Math.cos(t) * 1.8, 14 + Math.sin(t) * 1.6, IR[2]);
    }
  }
  return outline(g);
}


// ---- 내보내기 ----
const OUTS = {};
for (let f = 0; f < 4; f++) OUTS['deco_forge_' + f] = forge(f).render();
OUTS['deco_anvil'] = anvil().render();
OUTS['deco_crate'] = crate().render();
OUTS['deco_sack'] = sack().render();
OUTS['deco_orepile'] = orepile().render();
OUTS['deco_toolrack'] = toolrack().render();
OUTS['deco_logpile'] = logpile().render();
OUTS['deco_trough'] = trough(true).render();
OUTS['deco_feedbox'] = trough(false).render();
OUTS['deco_hay'] = hay().render();
OUTS['deco_netrack'] = netrack().render();
OUTS['deco_planter'] = planter().render();
OUTS['deco_cart'] = cart().render();
OUTS['deco_bookstack'] = bookstack().render();
OUTS['deco_specimen'] = specimen().render();

// 미리보기 — 잔디 위에 게임과 같은 크기(0.5배)로 늘어놓는다
function preview() {
  const names = Object.keys(OUTS);
  const CW = 96, CH = 132, cols = 7;
  const rows = Math.ceil(names.length / cols);
  const im = new PNG({ width: CW * cols, height: CH * rows });
  for (let i = 0; i < im.data.length; i += 4) {
    im.data[i] = 104; im.data[i + 1] = 158; im.data[i + 2] = 82; im.data[i + 3] = 255;
  }
  names.forEach((n, idx) => {
    const src = OUTS[n];
    const ox = (idx % cols) * CW + Math.round((CW - src.width / 2) / 2);
    const oy = Math.floor(idx / cols) * CH + (CH - 8 - Math.round(src.height / 2));
    for (let y = 0; y < Math.round(src.height / 2); y++)
      for (let x = 0; x < Math.round(src.width / 2); x++) {
        const si = ((y * 2) * src.width + x * 2) * 4, a = src.data[si + 3] / 255;
        if (a === 0) continue;
        const dx = ox + x, dy = oy + y;
        if (dx < 0 || dy < 0 || dx >= im.width || dy >= im.height) continue;
        const di = (dy * im.width + dx) * 4;
        for (let c = 0; c < 3; c++)
          im.data[di + c] = Math.round(src.data[si + c] * a + im.data[di + c] * (1 - a));
      }
  });
  return im;
}

if (INSTALL) {
  for (const k in OUTS) fs.writeFileSync(SPR + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('설치: sprites/deco_*.png ' + Object.keys(OUTS).length + '장');
  console.log('  다음에 반드시 -> python3 make_import.py');
} else {
  for (const k in OUTS) fs.writeFileSync(REF + 'proposed_' + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('제안: ref/proposed_deco_*.png ' + Object.keys(OUTS).length + '장');
}
fs.writeFileSync(REF + 'preview_props.png', PNG.sync.write(preview()));
console.log('미리보기: ref/preview_props.png');
