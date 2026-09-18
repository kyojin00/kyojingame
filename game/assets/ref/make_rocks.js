// 바위와 돌 — 마을과 **같은 물감, 같은 도트**로.
//
// 왜 다시 그리는가 —
//   ① **밑동이 스티커였다.** 바위 밑에 갈색 타원을 통으로 칠해 두었더니,
//      잔디 위에 붙인 딱지가 됐다. 게임이 실시간으로 까는 접지 그늘이
//      그 위를 지나가지 못해 바위 밑만 혼자 환했다.
//   ② **도트 크기가 어긋났다.** 64x64 그림을 0.72~1.38배로 늘여 썼다.
//      집도 사람도 나무도 다 한 도트 = 화면 2px 인데 바위만 0.72px 도 되고
//      1.38px 도 됐다. 같은 바위가 그루마다 다른 해상도였다.
//   ③ 그리고 **바위가 계란이었다.** 돌은 둥근 덩어리가 아니라 **면**이다 —
//      평평한 면 몇 개가 모서리에서 만나고, 그 모서리가 빛을 가른다.
//
// 그리는 법은 나무·건물·살림과 같다.
//   도트    한 칸 = 원본 4px -> 게임에서 0.5배 -> 화면 2px
//   ① 톤 사다리   돌 여덟 단. 땅(make_ground.js)의 STONE 과 같은 자다
//   ② 면으로      낟알을 뿌리지 않는다. 면을 나누고 면마다 톤을 준다
//   ③ 윤곽선      바탕이 무슨 색이든 떠 보여야 한다
//   ④ 반쯤 묻힌다 돌은 땅 위에 **놓인** 것이 아니라 땅에 **박힌** 것이다
//
// 실행:  node make_rocks.js            -> ref/proposed_rock*.png
//        node make_rocks.js --install  -> sprites/ 에 실제로 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');
const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)

function h(x, y, k) {
  let n = ((x | 0) * 73856093) ^ ((y | 0) * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// ---- 물감 ----
//
// 돌빛은 **땅의 STONE 사다리와 같은 자**를 쓴다. 바위만 따로 차가운 회색을
// 쓰면 돌담·자갈길과 다른 돌이 되어, 같은 마을에 두 가지 화강암이 선다.
const ST = [[214, 202, 178], [194, 180, 156], [174, 160, 138], [154, 141, 120],
            [132, 120, 102], [108, 98, 84], [84, 76, 66], [62, 56, 50]];
// 흙 — 나무 밑동과 같은 흙이다 (make_trees.js 의 SOIL 과 같은 줄기)
const SOIL = [[118, 94, 68], [96, 76, 56], [72, 56, 42]];
// 이끼 — 해가 안 드는 쪽에 낀다. 돌을 「거기 오래 있던 것」으로 만든다
const MOSS = [[112, 140, 74], [88, 114, 58], [64, 88, 44]];
const GRASS = [[152, 208, 100], [110, 170, 70], [80, 132, 54], [56, 100, 44]];
const OUT = [26, 22, 26];        // 윤곽선 — 나무·살림·건물과 같은 먹색

class G {
  constructor(w, hh) {
    this.w = w; this.h = hh;
    this.d = Array.from({ length: hh }, () => new Array(w).fill(null));
  }
  raw(x, y, c) {
    if (!c) return;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.d[y][x] = c;
  }
  px(x, y, c) { this.raw(Math.round(x), Math.round(y), c); }
  get(x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return null;
    return this.d[y][x];
  }
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
  for (const [x, y] of add) g.raw(x, y, OUT);
  return g;
}


// ---- 바위 한 덩이 ----
//
// **돌은 면이다.** 둥근 덩어리에 얼룩을 뿌리면 감자가 되고, 낟알을 흩뿌리면
// 자갈 무더기가 된다. 참고할 만한 돌 그림이 돌로 읽히는 까닭은 면을 나눠서다 —
// 평평한 면 네댓이 모서리에서 만나고, 왼위를 보는 면은 하늘빛을 받아 밝고
// 오른아래를 보는 면은 어둡다. 모서리에는 밝은 능선과 어두운 골이 함께 선다.
//
// 그래서 ① 실루엣을 **각진 다각형**으로 잡고 ② 안을 면 씨앗으로 나눈 뒤
// ③ 면마다 「어느 쪽을 보는가」로 톤을 정하고 ④ 면과 면 사이에 모서리를 긋는다.
function boulder(W, H, seed, opt) {
  const o = opt || {};
  const g = new G(W, H);
  const cx = W / 2 + (o.dx || 0);
  const baseY = H - (o.foot || 6);            // 땅에 닿는 줄
  const RX = W * 0.44, RY = H * 0.44;
  const cy = baseY - RY * 0.62;

  // ① 실루엣 — 각진 다각형. 아래쪽 절반은 눌러서 땅에 앉힌다
  const NV = o.verts || 10;
  const P = [];
  for (let i = 0; i < NV; i++) {
    const a = (i / NV) * Math.PI * 2 + (h(i, 0, seed) - 0.5) * 0.34;
    const rr = 0.68 + 0.32 * h(i, 1, seed);
    let px = cx + Math.cos(a) * RX * rr;
    let py = cy + Math.sin(a) * RY * rr * (Math.sin(a) > 0 ? 0.82 : 1.0);
    P.push([px, Math.min(py, baseY + 1.5)]);
  }
  const inside = (x, y) => {
    let c = false;
    for (let i = 0, j = NV - 1; i < NV; j = i++) {
      const [xi, yi] = P[i], [xj, yj] = P[j];
      if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
    }
    return c;
  };

  // ② 면 씨앗 — **일부러** 배치한다. 난수에 맡겼더니 다섯 면이 다 비슷한
  //    쪽을 봐서, 면을 나눠 놓고도 톤이 한 단 안에 뭉쳤다 (흰 빵덩이가 됐다).
  //    왼위에서 오른아래로 부채꼴로 깔면 면마다 보는 쪽이 다르다
  const K = o.facets || 5;
  const F = [];
  for (let i = 0; i < K; i++) {
    const a = -Math.PI * 0.78 + (i / Math.max(1, K - 1)) * Math.PI * 1.62
      + (h(i, 2, seed) - 0.5) * 0.40;
    const r = 0.34 + 0.36 * h(i, 3, seed);
    F.push([cx + Math.cos(a) * RX * r, cy + Math.sin(a) * RY * r]);
  }
  const near = (x, y) => {
    let bi = 0, bd = 1e9;
    for (let i = 0; i < K; i++) {
      const d = ((x - F[i][0]) / RX) ** 2 + ((y - F[i][1]) / RY) ** 2;
      if (d < bd) { bd = d; bi = i; }
    }
    return bi;
  };
  // 면이 「어느 쪽을 보는가」 — 씨앗이 덩어리 중심에서 어느 쪽에 있는지로.
  // 세로(하늘을 보는가 땅을 보는가)가 가로보다 훨씬 크게 먹는다
  const tone = F.map(([fx, fy]) => {
    const u = (fx - cx) / RX, v = (fy - cy) / RY;
    return clamp(Math.round(3.3 + u * 1.8 + v * 3.0), 1, 7);
  });

  // ③ 칠하기
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!inside(x + 0.5, y + 0.5)) continue;
    const fi = near(x, y);
    let i = tone[fi];
    // 면 안에서도 미세한 기울기 — 통으로 칠하면 색종이를 오려 붙인 것이 된다
    const gy = (y - cy) / RY;
    if (gy > 0.50) i += 1;
    if (gy < -0.60) i -= 1;
    // **밑동은 늘 가장 어둡다.** 위에서 오는 빛이 못 닿고 땅에서 반사도
    // 없는 자리다. 이 그늘이 없으면 돌이 땅에 얹힌 게 아니라 떠 보인다
    const low = (baseY - y) / Math.max(1, RY);
    if (low < 0.26) i += 2; else if (low < 0.52) i += 1;
    // 결 — 성글게. 촘촘히 뿌리면 화강암이 아니라 모래가 된다
    const v = h(x, y >> 1, seed + 11);
    if (v < 0.10) i -= 1; else if (v > 0.93) i += 1;
    g.px(x, y, ST[clamp(i, 0, 7)]);
  }

  // ④ 모서리 — 면이 바뀌는 자리. 아래쪽에는 골(어둡게), 위쪽에는 능선(밝게).
  //    이 한 겹이 없으면 면을 나눠 놓고도 그냥 얼룩진 덩어리로 보인다
  const edge = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!g.get(x, y)) continue;
    const a = near(x, y), b = near(x + 1, y), c = near(x, y + 1);
    if (a !== b || a !== c) edge.push([x, y, a, (a !== c) ? c : b]);
  }
  for (const [x, y, a, b] of edge) {
    if (!g.get(x, y)) continue;
    g.px(x, y, ST[clamp(Math.max(tone[a], tone[b]) + 2, 0, 7)]);
    if (h(x, y, seed + 12) < 0.62)
      g.px(x, y - 1, ST[clamp(Math.min(tone[a], tone[b]) - 1, 0, 7)]);
  }

  // ⑤ 윗변의 빛 — 하늘을 보는 **왼위 한 줄**. 윗변을 통으로 밝히면
  //    부피가 아니라 흰 테두리가 된다
  for (let x = 0; x < W; x++) {
    if (x > cx + RX * 0.20) continue;
    for (let y = 0; y < H; y++) {
      if (!g.get(x, y)) continue;
      if (h(x, 3, seed + 13) < 0.72) g.px(x, y, ST[1]);
      else if (h(x, 4, seed + 29) < 0.30) g.px(x, y, ST[0]);
      break;
    }
  }

  // ⑥ 금 — 한두 줄. 짧게 여럿 그으면 깨진 유리가 된다
  const NC = o.cracks === undefined ? 2 : o.cracks;
  for (let k = 0; k < NC; k++) {
    let x = cx + (h(k, 5, seed + 15) - 0.5) * RX * 1.1;
    let y = cy - RY * 0.5 + h(5, k, seed + 16) * RY * 0.6;
    let ang = Math.PI * (0.28 + h(k, 6, seed + 17) * 0.44);
    const len = Math.round(RY * (1.1 + h(k, 7, seed + 18) * 0.7));
    for (let i = 0; i < len; i++) {
      const gx = Math.round(x), gy2 = Math.round(y);
      if (g.get(gx, gy2)) {
        g.px(x, y, ST[6]);
        if (h(gx, gy2, seed + 19) < 0.5)
          g.px(x - 1, y, ST[clamp(tone[near(gx, gy2)] - 1, 0, 7)]);
      }
      x += Math.cos(ang); y += Math.sin(ang);
      ang += (h(Math.round(x), Math.round(y), seed + 20) - 0.5) * 0.5;
    }
  }

  // ⑦ 이끼 — 칸마다 확률로 뿌렸더니 돌에 낀 이끼가 아니라 **초록 곰팡이**가
  //    됐다. 이끼는 덩어리로 앉는다 — 해가 안 드는 아래쪽에 두세 뭉치.
  const NM = o.moss === undefined ? 2 : o.moss;
  for (let k = 0; k < NM; k++) {
    const a = Math.PI * (0.10 + 0.78 * h(k, 40, seed + 23));
    const mx = cx + Math.cos(a) * RX * (0.24 + 0.50 * h(40, k, seed + 24));
    const my = cy + Math.sin(a) * RY * (0.34 + 0.44 * h(k, 41, seed + 25));
    const mr = Math.max(1.8, RX * (0.09 + 0.09 * h(41, k, seed + 26)));
    for (let y = Math.floor(my - mr); y <= Math.ceil(my + mr); y++)
      for (let x = Math.floor(mx - mr * 1.4); x <= Math.ceil(mx + mr * 1.4); x++) {
        const cur = g.get(x, y);
        if (!cur || cur.length > 3) continue;
        // **밝은 면에는 이끼가 안 낀다.** 볕이 드는 자리라서다 —
        // 위아래 안 가리고 뿌렸더니 돌이 아니라 이끼 덩어리가 됐다
        if (ST.indexOf(cur) >= 0 && ST.indexOf(cur) < 3) continue;
        if ((y - cy) / RY < -0.05) continue;
        const d = ((x - mx) / (mr * 1.4)) ** 2 + ((y - my) / mr) ** 2;
        if (d > 1.0) continue;
        if (d > 0.36 && h(x, y, seed + 27) < d * 0.95) continue;
        const m = h(x, y >> 1, seed + 28);
        g.px(x, y, MOSS[m < 0.26 ? 0 : (m < 0.70 ? 1 : 2)]);
      }
  }
  return { g, cx, baseY, RX };
}


// ---- 밑동 ----
//
// 돌은 땅 위에 **놓인** 것이 아니라 땅에 **박힌** 것이다. 밑변을 반듯하게
// 끊고 그 아래 갈색 타원을 통으로 칠하면 「접시에 올린 돌」이 된다.
// 나무 밑동에서 배운 것과 같은 규칙으로 판다.
//   ① 흙은 **반쯤 비치게** — 게임이 까는 접지 그늘이 흙 위로 함께 비쳐야 한다
//   ② **이미 그려진 칸은 건드리지 않는다** — 흙이 돌 모양을 그대로 따라간다
//   ③ 흙 속에 잠긴 윤곽선은 먹색이 아니라 **흙색**으로 낮춘다
//   ④ 흙과 잔디의 경계에는 **풀 포기** — 한 칸짜리 세로 획은 철사다
function bury(g, cx, baseY, RX, seed) {
  const rx = RX * 1.12, ry = Math.max(3.0, RX * 0.26), SK = RX * 0.08;
  for (let y = baseY - Math.ceil(ry) - 2; y <= baseY + Math.ceil(ry); y++)
    for (let x = Math.floor(cx - rx - 3); x <= Math.ceil(cx + rx + 3); x++) {
      const d = ((x - cx - SK) / rx) ** 2 + ((y - baseY + 0.6) / ry) ** 2;
      if (d > 1.0) continue;
      if (g.get(x, y) === OUT) { g.px(x, y, SOIL[2]); continue; }
      if (g.get(x, y)) continue;
      if (d > 0.40 && h(x, y, seed + 71) < d * 0.80) continue;   // 가장자리를 허문다
      const v = h(x, y >> 1, seed + 72);
      const c = d < 0.32 ? (v < 0.52 ? SOIL[2] : SOIL[1])
        : (v < 0.36 ? SOIL[1] : SOIL[0]);
      g.px(x, y, [c[0], c[1], c[2], 222]);
    }
  // 파낸 흙이 돌 앞으로 조금 밀려 나온다 — 「박혀 있다」를 말하는 한 겹
  for (let i = 0; i < 3; i++) {
    const x = Math.round(cx + (h(i, 30, seed + 73) - 0.5) * rx * 1.2);
    const y = Math.round(baseY + 0.4 + h(30, i, seed + 74) * ry * 0.5);
    for (let k = -1; k <= 1; k++) {
      if (g.get(x + k, y) && g.get(x + k, y).length < 4) continue;
      g.px(x + k, y, [SOIL[1][0], SOIL[1][1], SOIL[1][2], 236]);
      g.px(x + k, y - 1, [SOIL[0][0], SOIL[0][1], SOIL[0][2], 236]);
    }
  }
  // 곁에 떨어져 나온 잔돌 — 큰 돌 하나만 있으면 놓아 둔 모형이다
  const NS = 3;
  for (let i = 0; i < NS; i++) {
    const a = Math.PI * (0.06 + 0.88 * h(i, 31, seed + 75));
    const rr = rx * (0.62 + h(31, i, seed + 76) * 0.42);
    const x = Math.round(cx + SK + Math.cos(a) * rr);
    const y = Math.round(baseY + 0.2 + Math.sin(a) * ry * 0.72);
    const w = 1 + Math.floor(h(i, 32, seed + 77) * 2);
    for (let k = 0; k <= w; k++) {
      g.px(x + k, y, ST[3]);
      g.px(x + k, y - 1, ST[1]);
      g.px(x + k, y + 1, ST[6]);
    }
  }
  // 흙 언저리에 돋은 풀 포기
  const NG = Math.max(7, Math.round(rx * 0.65));
  for (let i = 0; i < NG; i++) {
    const a = Math.PI * (0.03 + 0.94 * h(i, 33, seed + 87));
    const rr = rx * (0.90 + h(33, i, seed + 90) * 0.26);
    const x = Math.round(cx + SK + Math.cos(a) * rr);
    const y = Math.round(baseY + 0.2 + Math.sin(a) * ry * 0.80);
    const hgt = 2 + Math.floor(h(i, 34, seed + 88) * 3);
    const sun = h(i, 35, seed + 91) < 0.34;
    for (let k = 0; k < hgt; k++)
      g.px(x, y - k, k === hgt - 1 ? (sun ? GRASS[0] : GRASS[1]) : GRASS[2]);
    const sh = Math.max(1, hgt - 1);
    g.px(x - 1, y - sh + 1, GRASS[2]);
    g.px(x + 1, y - sh + 1, GRASS[3]);
    g.px(x - 1, y, GRASS[3]);
    g.px(x + 1, y, GRASS[3]);
  }
  return g;
}


function makeRock(seed, opt) {
  const o = opt || {};
  const W = o.W || 40, H = o.H || 34;
  const r = boulder(W, H, seed, o);
  outline(r.g);
  bury(r.g, r.cx, r.baseY, r.RX, seed);
  return r.g;
}


// ---- 내보내기 ----
//
// 바위도 나무와 같다 — **한 그림을 배율만 흔들어 쓰면** 같은 돌이 저마다
// 다른 해상도로 서게 된다. 크기를 바꾸는 대신 **다른 돌 셋**을 그리고
// 좌우 뒤집기를 곁들인다 (object_nodes.gd 가 자리 해시로 고른다).
const OUTS = {};
OUTS['rock'] = makeRock(101, { W: 40, H: 38, verts: 9, facets: 5 }).render();
OUTS['rock_02'] = makeRock(233, { W: 38, H: 40, verts: 8, facets: 6, cracks: 1 }).render();
OUTS['rock_03'] = makeRock(367, { W: 42, H: 36, verts: 8, facets: 5, cracks: 2 }).render();
// 큰 바위 — 작은 바위를 늘인 것이 아니라 **다른 돌**이다. 면이 더 많고
// 금이 길며, 밑동에 잔돌이 더 붙는다
OUTS['rock_big'] = makeRock(541, { W: 68, H: 62, verts: 13, facets: 7, cracks: 3 }).render();

function preview() {
  const names = Object.keys(OUTS);
  const CW = 190, CH = 130, cols = 4;
  const rows = Math.ceil(names.length / cols);
  const im = new PNG({ width: CW * cols, height: CH * rows });
  for (let i = 0; i < im.data.length; i += 4) {
    im.data[i] = 104; im.data[i + 1] = 158; im.data[i + 2] = 82; im.data[i + 3] = 255;
  }
  names.forEach((n, idx) => {
    const src = OUTS[n];
    const hw = Math.round(src.width / 2), hh = Math.round(src.height / 2);
    const ox = (idx % cols) * CW + Math.round((CW - hw) / 2);
    const oy = Math.floor(idx / cols) * CH + (CH - 10 - hh);
    for (let y = 0; y < hh; y++) for (let x = 0; x < hw; x++) {
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
  console.log('설치: sprites/rock*.png ' + Object.keys(OUTS).length + '장');
  console.log('  다음에 반드시 -> python3 make_import.py');
} else {
  for (const k in OUTS) fs.writeFileSync(REF + 'proposed_' + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('제안: ref/proposed_rock*.png ' + Object.keys(OUTS).length + '장');
}
fs.writeFileSync(REF + 'preview_rocks.png', PNG.sync.write(preview()));
console.log('미리보기: ref/preview_rocks.png');
