// 나무 — 마을과 **같은 물감, 같은 도트**로.
//
// 왜 다시 그리는가 —
//   숲의 나무만 홀로 옛 그림이었다. 잎을 픽셀 난수로 뿌려 놓아서, 가까이
//   가면 자글거리고 멀리서 보면 초록 뭉게구름이다. 게다가 96px 그림을
//   1.7배로 늘여 쓰는 바람에 **픽셀 하나의 크기가 들쭉날쭉**했다 —
//   집도 사람도 살림도 다 한 도트 = 화면 2px 인데 나무만 3.4px 도 되고
//   1.7px 도 됐다. 화면에서 제일 큰 물건이 제일 흐린 물건이었다.
//
// 그래서 자를 맞춘다.
//   도트    한 칸 = 원본 4px -> 게임에서 0.5배 -> 화면 2px (모두와 같다)
//   판      82x82 칸 = 화면 164x164px (지금 나무가 덮던 크기 그대로)
//   배율    OBJECT_SCALES.tree = 1.0 (/ OBJECT_TEX_DENSITY 2.0 = 0.5)
//
// 그리는 법은 건물·살림과 같다.
//   ① 톤 사다리   잎 여덟 단 · 껍질 여섯 단. 한 자로 재야 한 세계다
//   ② 덩어리로    잎을 한 장씩 뿌리지 않는다. **잎 뭉치**를 몇 개 얹고
//                 뭉치마다 왼위는 빛, 오른아래는 그늘, 뭉치 사이는 골
//   ③ 윤곽선      바탕이 무슨 색이든 나무가 떠 보여야 한다
//   ④ 다 그리지 않는다  잔가지·잎맥은 안 그린다. 실루엣과 큰 명암이 전부다
//
// 실행:  node make_trees.js            -> ref/proposed_tree_*.png
//        node make_trees.js --install  -> sprites/ 에 실제로 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');

const N = 82;                    // 논리 격자 (한 변)
const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)
const F = N * S;                 // 328

function h(x, y, k) {
  let n = ((x | 0) * 73856093) ^ ((y | 0) * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const mix = (a, b, t) => a.map((v, i) => Math.round(v * (1 - t) + b[i] * t));

// ---- 물감 ----
//
// 잎은 **잔디와 같은 초록 줄기에서 내려온다.** 잔디(88,158,62)보다 어둡고
// 조금 더 푸르되 색상은 같다 — 무대와 배우가 같은 물감이어야 숲이 한 장이다.
// 예전 나무는 누런 올리브(48,72,26)라 새로 그린 잔디 위에서 혼자 떠 있었다.
const LEAF = [[152, 208, 100], [122, 182, 78], [96, 158, 62], [76, 134, 52],
              [58, 112, 44], [44, 90, 38], [32, 68, 32], [22, 48, 26]];
// **볕을 받은 잎은 노랗고 그늘의 잎은 푸르다.** 한 사다리로만 칠했더니
// 명암은 있는데 온도가 없어서, 잎이 초록 찰흙처럼 보였다. 밝은 쪽은
// 노란 기를, 어두운 쪽은 푸른 기를 섞은 사다리를 하나씩 더 둔다 —
// 같은 초록 줄기에서 갈라져 나오므로 나무는 여전히 한 그루다
const LEAF_SUN = [[186, 224, 104], [154, 200, 84], [124, 176, 66], [100, 152, 56],
                  [78, 128, 48], [60, 104, 40], [44, 80, 34], [30, 58, 28]];
const LEAF_SHADE = [[124, 188, 104], [98, 162, 84], [74, 138, 68], [56, 116, 58],
                    [42, 96, 50], [32, 78, 42], [22, 58, 34], [16, 42, 28]];
// 껍질 — 건물 목재(주황빛 켠 나무)와 다르다. 살아 있는 나무의 껍질은
// 잿빛이 돈다. 켠 널과 선 나무가 같은 색이면 둘 다 가짜로 보인다
const BARK = [[156, 126, 90], [128, 100, 68], [104, 78, 52], [82, 60, 40],
              [60, 43, 29], [42, 30, 21]];
const OUT = [26, 22, 26];        // 윤곽선 — 살림·건물과 같은 차가운 먹색
const FRUIT = [[226, 66, 52], [176, 38, 34], [248, 148, 120]];
const SHADOW = [30, 26, 34, 78];

class T {
  constructor(w, hh) {
    this.w = w || N; this.h = hh || N;
    this.d = Array.from({ length: this.h }, () => new Array(this.w).fill(null));
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
  hline(x0, x1, y, c) { for (let x = x0; x <= x1; x++) this.px(x, y, c); }
  vline(x, y0, y1, c) { for (let y = y0; y <= y1; y++) this.px(x, y, c); }
  rect(x0, y0, x1, y1, c) { for (let y = y0; y <= y1; y++) this.hline(x0, x1, y, c); }
  disc(cx, cy, rx, ry, c) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++)
        if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0) this.px(x, y, c);
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

// 윤곽선 — 그늘(반투명)은 물건이 아니므로 두르지 않는다
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

// 접지 그늘 — 살림(make_props.P.ground)과 같은 세 단 · 오른쪽으로 눕는 타원
function ground(g, cx, cy, rx, ry, seed) {
  const skew = rx * 0.20;
  const A = [[0.42, 108], [0.74, 74], [1.0, 42]];
  for (let y = Math.floor(cy - ry - 1); y <= Math.ceil(cy + ry + 1); y++)
    for (let x = Math.floor(cx - rx - skew - 1); x <= Math.ceil(cx + rx + skew + 1); x++) {
      const d = ((x - cx - skew) / rx) ** 2 + ((y - cy) / ry) ** 2;
      if (d > 1.0) continue;
      let a = 42;
      for (const [t, v] of A) if (d <= t * t) { a = v; break; }
      if (d > 0.64 && h(x, y, seed + 199) < 0.42) continue;   // 테두리를 허문다
      g.px(x, y, [30, 26, 34, a]);
    }
}


// ---- 줄기 ----
//
// 곧은 막대는 전봇대다. 나무는 **밑동이 벌어지고 위로 갈수록 가늘어지며**,
// 그 사이가 조금 휜다. 그 셋만 있으면 기둥이 나무가 된다.
//
// 껍질은 **세로 골**이다. 가로로 결을 넣으면 켠 널이 되고(살림에서 배운 것과
// 같은 함정), 점으로 뿌리면 이끼 낀 돌이 된다.
function trunk(g, cx, yTop, yBase, wTop, wBase, seed, lean) {
  const ln = lean || 0;
  for (let y = yTop; y <= yBase; y++) {
    const t = (y - yTop) / Math.max(1, yBase - yTop);
    // 밑동은 급하게 벌어진다 (t^3) — 위쪽 절반은 거의 곧다
    let w = wTop + (wBase - wTop) * Math.pow(t, 2.6);
    // 뿌리목 — 맨 아래 대여섯 줄에서 한 번 더 벌어진다
    if (yBase - y < 6) w += (6 - (yBase - y)) * 0.9;
    const bend = Math.sin(t * 2.0) * ln;
    const x0 = Math.round(cx + bend - w / 2), x1 = Math.round(cx + bend + w / 2);
    for (let x = x0; x <= x1; x++) {
      const u = (x - x0) / Math.max(1, x1 - x0);      // 0(왼쪽) ~ 1(오른쪽)
      let i = 2;
      if (u < 0.16) i = 0;                            // 왼쪽 = 빛
      else if (u < 0.30) i = 1;
      else if (u > 0.86) i = 5;                       // 오른쪽 = 그늘
      else if (u > 0.68) i = 4;
      // 세로 골 — 서너 칸 간격으로 한 줄씩 파인다. 골은 위아래로 이어진다
      const groove = h(Math.round(x - bend), 0, seed) < 0.26;
      if (groove && u > 0.2 && u < 0.86) i += (h(Math.round(x - bend), y >> 2, seed + 1) < 0.75 ? 2 : 1);
      g.px(x, y, BARK[clamp(i, 0, 5)]);
    }
    // 옹이 하나 — 줄기 가운데쯤에
    if (y === yTop + Math.round((yBase - yTop) * 0.62)) {
      const kx = Math.round(cx + bend + w * 0.12);
      g.disc(kx, y, 2.2, 1.6, BARK[4]);
      g.disc(kx, y, 1.1, 0.8, BARK[5]);
      g.px(kx - 1, y - 1, BARK[2]);
    }
  }
  // 뿌리 — 땅으로 뻗어 나간 세 갈래. 나무를 땅에 **박아** 준다
  for (const [rx, rw] of [[-1, 5], [1, 4], [-1, 8]]) {
    const sx = Math.round(cx + rx * (wBase / 2 - 1));
    for (let k = 0; k < rw; k++) {
      const x = sx + rx * k, y = yBase - Math.floor(k * 0.35);
      g.px(x, y, BARK[3]);
      g.px(x, y + 1, BARK[5]);
      if (k < rw - 2) g.px(x, y - 1, BARK[2]);
    }
  }
}


// ---- 잎 뭉치 ----
//
// 잎을 한 장씩 그리면 자글자글한 잡음이고, 통으로 칠하면 초록 풍선이다.
// 참고 그림들이 숲으로 읽히는 까닭은 **뭉치**로 그려서다 —
// 손바닥만 한 잎 덩어리 예닐곱이 겹쳐 앉고, 뭉치마다 왼위가 밝고
// 오른아래가 어두우며, 뭉치와 뭉치 사이에 골이 진다.
//
// 그래서 뭉치의 목록을 먼저 만들고, 칸마다 **어느 뭉치에 속하는지**와
// **그 뭉치의 중심에서 어느 쪽인지**를 물어 톤을 정한다.
const isLeafRaw = c => c && c.length < 4
  && (LEAF.indexOf(c) >= 0 || LEAF_SUN.indexOf(c) >= 0 || LEAF_SHADE.indexOf(c) >= 0);

function canopy(g, blobs, seed, opts) {
  const o = opts || {};
  const holes = o.holes === undefined ? 3 : o.holes;
  // 잎 전체가 차지한 자리 — 전체 명암의 기준이 된다
  {
    let x0 = 9e9, x1 = -9e9, y0 = 9e9, y1 = -9e9;
    for (const [bx, by, rx, ry] of blobs) {
      x0 = Math.min(x0, bx - rx); x1 = Math.max(x1, bx + rx);
      y0 = Math.min(y0, by - ry); y1 = Math.max(y1, by + ry);
    }
    o.cx = (x0 + x1) / 2; o.cy = (y0 + y1) / 2;
    o.rw = (x1 - x0) / 2; o.rh = (y1 - y0) / 2;
  }
  const hole = [];
  for (let i = 0; i < holes; i++) hole.push([
    o.hx ? o.hx[i] : null, null]);
  // ① 어느 뭉치에 속하는가 · 그 뭉치 안에서 어느 쪽인가
  for (let y = 0; y < g.h; y++) for (let x = 0; x < g.w; x++) {
    let best = -1, bd = 9e9, second = 9e9;
    for (let i = 0; i < blobs.length; i++) {
      const [bx, by, rx, ry] = blobs[i];
      // 뭉치 가장자리를 흔든다 — 매끈한 타원 여섯 개는 비눗방울이다
      const ang = Math.atan2(y - by, x - bx);
      const wob = 1.0 + (h(Math.round(ang * 6), i, seed) - 0.5) * 0.22;
      const d = ((x - bx) / (rx * wob)) ** 2 + ((y - by) / (ry * wob)) ** 2;
      if (d < bd) { second = bd; bd = d; best = i; }
      else if (d < second) second = d;
    }
    if (bd > 1.0) continue;
    const [bx, by, rx, ry] = blobs[best];
    // 뭉치 안에서 왼위(-1) ~ 오른아래(+1)
    const u = ((x - bx) / rx) * 0.62 + ((y - by) / ry) * 0.78;
    // **그리고 나무 전체에도 해가 든다.** 뭉치마다 제 명암만 주었더니
    // 잎이 여섯 개의 공으로 보였다 — 공 하나하나가 아니라 **한 그루**가
    // 왼위에서 빛을 받아야 한다. 뭉치의 명암 위에 전체 기울기를 얹는다
    const gx = (x - o.cx) / Math.max(1, o.rw);
    const gy = (y - o.cy) / Math.max(1, o.rh);
    const glob = gx * 0.5 + gy * 0.9;
    let i = 3 + Math.round(u * 2.0 + glob * 1.5);
    // 뭉치마다 낯빛이 조금 다르다 — 다 같으면 한 덩어리로 뭉개진다
    i += (h(best, 3, seed + 7) < 0.34 ? 1 : 0) - (h(best, 5, seed + 9) < 0.3 ? 1 : 0);
    // 뭉치가 맞닿은 자리는 골이다 — 두 거리가 비슷하면 어둡게
    if (second < 1.35 && Math.abs(second - bd) < 0.16) i += 2;
    // 실루엣 가까이는 한 단 어둡다 (잎이 말려 들어간다)
    if (bd > 0.86) i += 1;
    // 잔 흔들림 — 넓은 면이 통짜로 보이지 않을 만큼만 (한 단의 3분의 1)
    if (h(x, y, seed + 11) < 0.10) i += 1;
    else if (h(x, y, seed + 13) < 0.08) i -= 1;
    // 온도 — 왼위(볕)는 노랗게, 오른아래(그늘)는 푸르게. 가운데는 기본
    const lad = glob < -0.42 ? LEAF_SUN : (glob > 0.46 ? LEAF_SHADE : LEAF);
    g.px(x, y, lad[clamp(i, 0, 7)]);
  }
  // ② 하늘 구멍 — 잎 사이로 하늘이 비친다. 없으면 초록 반죽이다
  for (let k = 0; k < holes; k++) {
    const hx = o.holeAt ? o.holeAt[k][0] : Math.round(h(k, 1, seed + 21) * g.w);
    const hy = o.holeAt ? o.holeAt[k][1] : Math.round(h(1, k, seed + 22) * g.h * 0.6) + 4;
    const hr = 1.6 + h(k, 2, seed + 23) * 1.6;
    for (let y = Math.floor(hy - hr); y <= Math.ceil(hy + hr); y++)
      for (let x = Math.floor(hx - hr); x <= Math.ceil(hx + hr); x++) {
        if (((x - hx) / hr) ** 2 + ((y - hy) / (hr * 0.8)) ** 2 > 1) continue;
        if (!g.get(x, y)) continue;
        g.raw(x, y, null);
      }
    // 구멍 아랫변에는 빛이 든다
    for (let x = Math.floor(hx - hr); x <= Math.ceil(hx + hr); x++)
      if (g.get(x, Math.ceil(hy + hr))) g.px(x, Math.ceil(hy + hr), LEAF[2]);
  }
  // ③ 볕이 든 우듬지 — 제일 위 뭉치의 왼위 어깨에 밝은 잎 몇 점.
  //    이 한 점이 나무를 「빛 아래 서 있는 것」으로 만든다
  const top = blobs.reduce((a, b) => (b[1] - b[3] < a[1] - a[3] ? b : a));
  for (let i = 0; i < 26; i++) {
    const ang = Math.PI * (1.06 + h(i, 7, seed + 31) * 0.62);
    const rr = 0.62 + h(i, 8, seed + 33) * 0.34;
    const x = Math.round(top[0] + Math.cos(ang) * top[2] * rr);
    const y = Math.round(top[1] + Math.sin(ang) * top[3] * rr);
    if (!g.get(x, y)) continue;
    g.px(x, y, LEAF[h(i, 9, seed + 35) < 0.35 ? 0 : 1]);
    if (h(i, 10, seed + 37) < 0.5) g.px(x + 1, y, LEAF[1]);
  }
  // ④ **뭉치의 어깨에 얹히는 잔 잎 덩어리.** 뭉치를 매끈한 타원으로 두면
  //    잎이 아니라 비눗방울이다. 볕을 받는 왼위 호를 따라 작은 덩어리를
  //    몇 개 얹어 실루엣을 울퉁불퉁하게 만든다 — 이것이 「잎이 뭉쳐 자란
  //    모양」이고, 멀리서도 나무를 나무로 만드는 것은 이 윤곽이다
  for (let bi = 0; bi < blobs.length; bi++) {
    const [bx, by, rx, ry] = blobs[bi];
    const n = 3 + Math.floor(h(bi, 2, seed + 51) * 3);
    for (let k = 0; k < n; k++) {
      const ang = Math.PI * (0.92 + h(bi * 5 + k, 3, seed + 53) * 0.86);
      const px2 = bx + Math.cos(ang) * rx * 0.94;
      const py2 = by + Math.sin(ang) * ry * 0.94;
      const rr = 2.2 + h(bi + k, 4, seed + 55) * 2.2;
      // 덩어리도 **나무 전체의 빛**을 따른다. 다 밝게 얹었더니 아래쪽
      // 그늘까지 환해져서, 부피가 있던 잎이 다시 평평한 초록 판이 됐다
      const gb = ((px2 - o.cx) / Math.max(1, o.rw)) * 0.5
        + ((py2 - o.cy) / Math.max(1, o.rh)) * 0.9;
      const lad = gb < -0.42 ? LEAF_SUN : (gb > 0.46 ? LEAF_SHADE : LEAF);
      const base = 2 + Math.round(gb * 1.6);
      for (let y = Math.floor(py2 - rr); y <= Math.ceil(py2 + rr); y++)
        for (let x = Math.floor(px2 - rr); x <= Math.ceil(px2 + rr); x++) {
          const d2 = ((x - px2) / rr) ** 2 + ((y - py2) / (rr * 0.9)) ** 2;
          if (d2 > 1) continue;
          const t2 = ((x - px2) / rr) * 0.6 + ((y - py2) / rr) * 0.8;
          g.px(x, y, lad[clamp(base + Math.round(t2 * 2.2), 0, 7)]);
        }
    }
  }
  // ⑤ **가지가 잎 사이로 보인다.** 잎만 얹으면 초록 덩어리가 줄기 위에
  //    떠 있다. 뭉치 사이의 골을 따라 굵은 가지 끝이 한둘 비쳐야
  //    「잎이 가지에 달렸다」가 된다
  if (o.limbs) for (const [lx, ly, ldx, ldy, llen] of o.limbs) {
    let cxx = lx, cyy = ly;
    for (let k = 0; k < llen; k++) {
      const w = Math.max(0, Math.round(2.2 * (1 - k / llen)));
      for (let i2 = -w; i2 <= w; i2++)
        g.px(cxx + i2, cyy, BARK[i2 < 0 ? 2 : 4]);
      cxx += ldx; cyy += ldy;
    }
  }
  // ⑥ **잎이 제 그늘을 드리운다.** 잎 덩어리의 맨 아랫자락은 위의 잎이
  //    해를 가려 늘 어둡다. 이 한 겹이 없으면 잎이 통째로 떠 보인다
  for (let x = 0; x < g.w; x++) {
    let last = -1;
    for (let y = 0; y < g.h; y++) if (isLeafRaw(g.get(x, y))) last = y;
    if (last < 0) continue;
    for (let k = 0; k < 3; k++) {
      const c = g.get(x, last - k);
      if (!isLeafRaw(c)) continue;
      const lad = LEAF_SHADE;
      const idx = Math.max(LEAF.indexOf(c), LEAF_SUN.indexOf(c), LEAF_SHADE.indexOf(c));
      g.px(x, last - k, lad[clamp(idx + (k === 0 ? 2 : 1), 0, 7)]);
    }
  }
  // ⑦ 잎 끝 — 실루엣 바깥으로 잎 몇 장이 삐져나온다. 매끈한 윤곽은 풍선이다
  const isLeaf = isLeafRaw;
  for (let y = 1; y < g.h - 1; y++) for (let x = 1; x < g.w - 1; x++) {
    if (g.get(x, y)) continue;
    let n = 0;
    // **잎 옆에만** 잎이 돋는다. 아무 칸이나 세었더니 줄기와 접지 그늘
    // 둘레에도 초록 점이 붙어, 나무 발치에 풀부스러기가 흩어진 꼴이었다
    for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]])
      if (isLeaf(g.get(x + dx, y + dy))) n++;
    // 이웃이 하나뿐인 칸에 찍으면 잎이 아니라 **파리**다 — 윤곽선이
    // 그 한 점을 통째로 감싸 검은 점이 된다. 두 칸에 걸쳐 붙은 것만 잎이다
    if (n < 2) continue;
    if (h(x, y, seed + 41) > 0.34) continue;
    g.px(x, y, LEAF[clamp(4 + Math.round(h(x, y, seed + 43) * 2), 0, 7)]);
  }
}


// ---- 가지 ----
// 잎 뭉치 사이로 굵은 가지 끝이 한두 개 보여야 「잎이 가지에 달렸다」가 된다
function branch(g, x0, y0, dx, dy, len, thick) {
  for (let k = 0; k < len; k++) {
    const x = x0 + dx * k, y = y0 + dy * k;
    const w = Math.max(1, Math.round(thick * (1 - k / len)));
    for (let i = -w; i <= w; i++) {
      const u = (i + w) / Math.max(1, 2 * w);
      g.px(x + i, y, BARK[u < 0.3 ? 1 : (u > 0.72 ? 4 : 2)]);
    }
  }
}


// ---- 다 자란 나무 ----
//
// 세 그루를 그린다. 숲은 한 그루를 복사한 것이 아니라 **다른 나무들**이다 —
// 좌우 뒤집기와 낯빛만으로는 스무 그루가 서면 티가 난다.
function fullTree(v) {
  const g = new T();
  const seed = 100 + v * 31;
  const cx = 41;
  ground(g, cx + 2, 78, 15, 3.4, seed);
  // 그루마다 다른 골격 — 우듬지 높이, 벌어진 폭, 줄기의 휨
  const SPEC = [
    { top: 6, wide: 30, lean: 1.6, trunkTop: 40 },
    { top: 3, wide: 27, lean: -2.2, trunkTop: 44 },
    { top: 8, wide: 33, lean: 0.8, trunkTop: 38 },
  ][v % 3];
  trunk(g, cx, SPEC.trunkTop, 78, 7, 13, seed, SPEC.lean);
  // 큰 가지 둘 — 잎 밑으로 뻗는다
  branch(g, cx - 3, SPEC.trunkTop + 6, -1, -0.7, 9, 2);
  branch(g, cx + 3, SPEC.trunkTop + 9, 1, -0.8, 8, 2);
  // 잎 뭉치 — 가운데가 높고 양옆이 낮은 한 덩어리. 다섯에서 일곱
  const W = SPEC.wide;
  const B = [
    [cx, SPEC.top + 15, W * 0.62, 14],
    [cx - W * 0.52, SPEC.top + 22, W * 0.48, 12],
    [cx + W * 0.52, SPEC.top + 21, W * 0.5, 12.5],
    [cx - W * 0.26, SPEC.top + 31, W * 0.46, 11],
    [cx + W * 0.3, SPEC.top + 32, W * 0.44, 10.5],
    [cx, SPEC.top + 8, W * 0.4, 9],
  ];
  if (v === 2) B.push([cx - W * 0.72, SPEC.top + 34, W * 0.3, 8]);
  canopy(g, B, seed, { holes: 3, limbs: [
    [cx - 2, SPEC.top + 40, -0.9, -0.75, 12],
    [cx + 3, SPEC.top + 42, 0.85, -0.8, 11],
    [cx, SPEC.top + 38, 0.15, -1, 10],
  ] });
  return outline(g);
}


// ---- 열매 나무 ----
// 다 자란 나무에 사과 셋. 잎 그늘 속이 아니라 **가장자리**에 달려야 보인다
function appleTree() {
  const g = fullTreeRaw(0, 220);
  const spots = [[24, 34], [55, 30], [40, 47]];
  for (const [ax, ay] of spots) {
    g.disc(ax, ay, 3.0, 2.8, FRUIT[1]);
    g.disc(ax, ay, 2.4, 2.2, FRUIT[0]);
    g.disc(ax - 1, ay - 1, 1.0, 0.9, FRUIT[2]);
    g.px(ax, ay - 3, BARK[3]);                 // 꼭지
    g.px(ax + 1, ay - 3, LEAF[2]);
  }
  return outline(g);
}
function fullTreeRaw(v, seedBase) {
  const g = new T();
  const seed = seedBase;
  const cx = 41;
  ground(g, cx + 2, 78, 15, 3.4, seed);
  trunk(g, cx, 42, 78, 7, 13, seed, 1.2);
  branch(g, cx - 3, 48, -1, -0.7, 9, 2);
  branch(g, cx + 3, 51, 1, -0.8, 8, 2);
  const W = 29;
  canopy(g, [
    [cx, 21, W * 0.62, 14], [cx - W * 0.52, 28, W * 0.48, 12],
    [cx + W * 0.52, 27, W * 0.5, 12.5], [cx - W * 0.26, 37, W * 0.46, 11],
    [cx + W * 0.3, 38, W * 0.44, 10.5], [cx, 14, W * 0.4, 9],
  ], seed, { holes: 2, limbs: [
    [cx - 2, 46, -0.9, -0.75, 11], [cx + 3, 48, 0.85, -0.8, 10],
  ] });
  return g;
}


// ---- 어린 나무 ----
// 다 자란 나무를 그냥 줄이면 **작은 어른**이다. 어린 나무는 비례가 다르다 —
// 줄기가 가늘고 길며 잎이 적다
function youngTree() {
  const g = new T();
  const seed = 300;
  const cx = 41;
  ground(g, cx + 1, 78, 9, 2.4, seed);
  trunk(g, cx, 46, 78, 4, 7, seed, 2.4);
  branch(g, cx - 2, 52, -1, -0.9, 5, 1);
  canopy(g, [
    [cx, 40, 13, 9], [cx - 9, 47, 10, 8], [cx + 10, 46, 10, 8],
    [cx, 32, 9, 7],
  ], seed, { holes: 1 });
  return outline(g);
}


// ---- 도끼가 든 나무 ----
// 두 단계. 잎이 반쯤 떨어지고(06), 줄기만 남는다(09).
function choppedTree(stage) {
  const g = new T();
  const seed = 400 + stage * 17;
  const cx = 41;
  if (stage === 0) {                            // 반쯤 남은 잎
    ground(g, cx + 2, 78, 13, 3.0, seed);
    trunk(g, cx, 42, 78, 7, 13, seed, 1.2);
    branch(g, cx - 3, 48, -1, -0.7, 11, 2);
    branch(g, cx + 3, 51, 1, -0.8, 10, 2);
    branch(g, cx, 44, 0.2, -1, 8, 2);
    canopy(g, [
      [cx - 12, 30, 14, 11], [cx + 13, 27, 13, 10], [cx - 2, 20, 11, 9],
    ], seed, { holes: 2 });
    // 떨어지는 잎 몇 장
    for (let i = 0; i < 7; i++) {
      const x = 12 + Math.round(h(i, 1, seed) * 58);
      const y = 52 + Math.round(h(1, i, seed) * 20);
      g.px(x, y, LEAF[3]); g.px(x + 1, y, LEAF[5]);
    }
  } else {                                       // 그루터기 — 잘린 면이 보인다
    ground(g, cx + 2, 78, 11, 2.8, seed);
    trunk(g, cx, 58, 78, 12, 15, seed, 0.4);
    // 잘린 면 — 타원이다. 가로 직선으로 자르면 네모난 궤짝이 된다
    const ty = 58;
    g.disc(cx, ty, 7.5, 3.0, BARK[1]);
    g.disc(cx, ty, 6.2, 2.3, [176, 148, 108]);   // 속살은 껍질보다 밝다
    for (let k = 1; k <= 3; k++) {               // 나이테
      const rr = 6.2 * (0.78 - k * 0.2);
      for (let a = 0; a < 26; a++) {
        const t = a / 26 * Math.PI * 2;
        g.px(cx + Math.cos(t) * rr, ty + Math.sin(t) * rr * 0.37, BARK[2]);
      }
    }
    // 도끼가 남긴 쐐기 자국
    for (let k = 0; k < 5; k++) {
      g.px(cx - 6 + k, ty + 2 + k, BARK[4]);
      g.px(cx - 5 + k, ty + 2 + k, BARK[3]);
    }
    // 곁에 돋은 새싹 — 「다시 자란다」는 표시
    for (let k = 0; k < 4; k++) g.px(cx + 11, 76 - k, LEAF[4]);
    g.disc(cx + 12, 71, 2.4, 2.0, LEAF[3]);
    g.disc(cx + 11, 70, 1.4, 1.2, LEAF[1]);
  }
  return outline(g);
}


// ---- 잎을 다 떨군 나무 ----
// 옛 전망대 곁의 굽은 나무(bent_tree)와 겨울 나무가 함께 쓴다.
// 잎이 없으므로 **가지의 갈라짐**이 전부다 — 굵은 데서 가는 데로, 세 번 갈린다
function bareTree() {
  const g = new T();
  const seed = 500;
  const cx = 41;
  ground(g, cx + 3, 78, 13, 3.0, seed);
  trunk(g, cx, 40, 78, 8, 14, seed, 3.2);
  const grow = (x, y, ang, len, thick, depth) => {
    let cxx = x, cyy = y;
    for (let k = 0; k < len; k++) {
      const w = Math.max(0, thick * (1 - k / len));
      const ww = Math.round(w);
      for (let i = -ww; i <= ww; i++) {
        const u = (i + ww) / Math.max(1, 2 * ww);
        g.px(cxx + i, cyy, BARK[u < 0.34 ? 1 : (u > 0.7 ? 4 : 2)]);
      }
      cxx += Math.cos(ang); cyy += Math.sin(ang);
      ang += (h(Math.round(cxx), Math.round(cyy), seed + depth) - 0.5) * 0.22;
    }
    if (depth >= 3) return;
    grow(cxx, cyy, ang - 0.45 - h(depth, 1, seed) * 0.3, Math.round(len * 0.66),
      thick * 0.6, depth + 1);
    grow(cxx, cyy, ang + 0.42 + h(depth, 2, seed) * 0.3, Math.round(len * 0.62),
      thick * 0.58, depth + 1);
  };
  grow(cx + 2, 41, -Math.PI / 2 - 0.28, 13, 3.4, 0);
  grow(cx - 2, 46, -Math.PI / 2 + 0.34, 12, 3.0, 0);
  grow(cx + 5, 50, -Math.PI / 2 + 0.75, 10, 2.4, 1);
  return outline(g);
}


// ---- 내보내기 ----
const OUTS = {};
OUTS['tree_01'] = fullTree(0).render();
OUTS['tree_02'] = fullTree(1).render();
OUTS['tree_03'] = fullTree(2).render();
OUTS['tree_13'] = appleTree().render();
OUTS['tree_15'] = youngTree().render();
OUTS['tree_06'] = choppedTree(0).render();
OUTS['tree_09'] = choppedTree(1).render();
OUTS['tree_bare'] = bareTree().render();

function preview() {
  const names = Object.keys(OUTS);
  const CW = 180, CH = 190, cols = 4;
  const rows = Math.ceil(names.length / cols);
  const im = new PNG({ width: CW * cols, height: CH * rows });
  for (let i = 0; i < im.data.length; i += 4) {
    im.data[i] = 104; im.data[i + 1] = 158; im.data[i + 2] = 82; im.data[i + 3] = 255;
  }
  names.forEach((n, idx) => {
    const src = OUTS[n];
    const hw = Math.round(src.width / 2), hh = Math.round(src.height / 2);
    const ox = (idx % cols) * CW + Math.round((CW - hw) / 2);
    const oy = Math.floor(idx / cols) * CH + (CH - 8 - hh);
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
  console.log('설치: sprites/tree_*.png ' + Object.keys(OUTS).length + '장');
  console.log('  다음에 반드시 -> python3 make_import.py');
} else {
  for (const k in OUTS) fs.writeFileSync(REF + 'proposed_' + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('제안: ref/proposed_tree_*.png ' + Object.keys(OUTS).length + '장');
}
fs.writeFileSync(REF + 'preview_trees.png', PNG.sync.write(preview()));
console.log('미리보기: ref/preview_trees.png');
