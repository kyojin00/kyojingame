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
// 이끼 — 잎보다 누렇고 탁하다. 잎색을 그대로 쓰면 줄기에 잎이 붙은 꼴이다
const MOSS = [[132, 156, 78], [104, 128, 60], [76, 96, 46]];
// 흙 — 나무 밑에 드러난 땅. 잔디보다 붉고 탁하되 밭흙(밭 타일)과 같은 줄기다
const SOIL = [[118, 94, 68], [96, 76, 56], [72, 56, 42]];
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

// ---- 접지 그늘은 **굽지 않는다** ----
//
// 나무에도 그늘을 구워 넣었더니, 게임이 실시간으로 까는 그늘
// (renderer._draw_object_shadows)과 겹쳐 **두 겹**이 됐다. 게다가 나무는
// 그루마다 몇 픽셀씩 어긋나 서고 도끼질에 잎이 줄어드는데, 구운 그늘은
// 그림에 붙어 있어 그 둘 다를 못 따라간다. 그늘은 게임 쪽 한 곳에서만
// 깐다 — 이 함수는 남겨 두되 아무도 부르지 않는다.
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
    // **껍질은 세로 골만으로는 부족하다.** 골만 그으면 나무가 아니라
    // 골함석 기둥이다. 참나무든 느티나무든 껍질은 세로 골이 가로 금에
    // 끊겨 **비늘판**을 이룬다 — 그 판 하나하나가 나무의 나이다.
    // 가로 금은 대여섯 줄마다 한 줄, 그것도 통으로가 아니라 끊어서.
    if (y % 6 === (Math.abs(yTop) % 6)) {
      for (let x = x0 + 1; x < x1; x++) {
        if (h(x, y, seed + 4) > 0.42) continue;
        const u = (x - x0) / Math.max(1, x1 - x0);
        if (u < 0.12 || u > 0.9) continue;
        g.px(x, y, BARK[4]);
        if (h(x, y, seed + 5) < 0.4) g.px(x, y - 1, BARK[1]);   // 금 위는 빛
      }
    }
    // 옹이 하나 — 줄기 가운데쯤에
    if (y === yTop + Math.round((yBase - yTop) * 0.62)) {
      const kx = Math.round(cx + bend + w * 0.12);
      g.disc(kx, y, 2.2, 1.6, BARK[4]);
      g.disc(kx, y, 1.1, 0.8, BARK[5]);
      g.px(kx - 1, y - 1, BARK[2]);
    }
  }
  // 이끼 — 해가 안 드는 **북쪽(그림에서는 오른쪽 아래)**에 낀다.
  // 나무를 「거기 오래 서 있던 것」으로 만드는 건 이 한 줌이다
  for (let y = yTop + Math.round((yBase - yTop) * 0.45); y <= yBase - 2; y++) {
    const t = (y - yTop) / Math.max(1, yBase - yTop);
    const w = wTop + (wBase - wTop) * Math.pow(t, 2.6)
      + (yBase - y < 6 ? (6 - (yBase - y)) * 0.9 : 0);
    const bend = Math.sin(t * 2.0) * ln;
    const x1 = Math.round(cx + bend + w / 2);
    for (let k = 0; k < 3; k++) {
      const x = x1 - k;
      if (h(x, y >> 1, seed + 6) > 0.34 - k * 0.09) continue;
      g.px(x, y, k === 0 ? MOSS[1] : MOSS[2]);
      if (h(x, y, seed + 7) < 0.3) g.px(x, y - 1, MOSS[0]);
    }
  }
  roots(g, cx, yBase, wBase, seed, ln);
}


// ---- 뿌리목 ----
//
// 예전 뿌리는 밑동에서 옆으로 그은 **한 칸짜리 선 세 줄**이었다. 굵기가 없으니
// 뿌리가 아니라 바닥에 댄 널이고, 셋 다 바깥으로 갈수록 **위로** 기어올라가서
// 나무가 땅을 밟은 게 아니라 담벼락에 기대 선 꼴이었다.
//
// 실제 뿌리목은 이렇게 보인다 —
//   ① 사방으로 벌어진다   비스듬히 내려다보는 그림이므로, **앞으로 오는**
//                        뿌리는 화면에서 내려가고 뒤로 가는 뿌리는 살짝
//                        올라가되 짧게 잘린다. 다 같은 높이로 그으면 십자다
//   ② 굵기가 있다         등은 볕을 받아 밝고 배는 땅에 닿아 어둡다.
//                        이 두 줄이 있어야 바닥에 **솟은 것**으로 읽힌다
//   ③ 끝이 사라진다       뿌리는 잘리지 않는다. 흙 속으로 들어간다 —
//                        끝 사분의 일을 성글게 끊어 파묻는다
//   ④ 흙을 밀어낸다       뿌리 배 밑으로 한 줄, 눌린 흙의 그늘
function roots(g, cx, yBase, wBase, seed, lean) {
  const bx = cx + Math.sin(2.0) * (lean || 0);        // 밑동은 t=1 지점
  const half = wBase / 2 + 4.0;
  // [방향, 화면에서 내려가는 칸, 길이, 밑동 굵기]
  // 뒤(-)로 가는 것을 먼저 깔아야 앞(+)의 뿌리가 그 위로 올라탄다
  // 뿌리는 **흙자리 안에서 끝나야** 한다. 흙 밖으로 삐져나간 끝은 검은
  // 윤곽선을 그대로 두르고 있어서, 좌우로 이어 붙으면 밑동이 아니라
  // 통나무를 깔아 놓은 꼴이 된다 (한 번 그렇게 그렸다가 고쳤다)
  const R = [
    [-1, -1.4, 8, 2.2], [1, -1.8, 7, 2.0],
    [-1, 0.6, 11, 3.6], [1, 1.0, 12, 3.8],
    [-1, 2.2, 7, 2.1], [1, 2.4, 8, 2.3],
  ];
  R.forEach((r, i) => {
    const dir = r[0], drop = r[1], len = r[2], th0 = r[3];
    const ph = h(i, 9, seed + 61) * 6.0;
    for (let k = 0; k <= len; k++) {
      const t = k / len;
      const x = bx + dir * (half - 4.0 + k);
      const y = yBase + drop * Math.pow(t, 1.4) + Math.sin(t * 2.6 + ph) * 0.7;
      // 굵기를 매끈하게 줄이면 뿌리가 아니라 **깎아 놓은 원뿔**이다.
      // 한 칸씩 들쭉날쭉해야 나무가 자라면서 굵어진 자국으로 읽힌다
      const th = th0 * Math.pow(1 - t, 0.75) * (0.84 + h(k, i, seed + 63) * 0.32);
      if (t > 0.74 && h(k, i, seed + 62) > 1.28 - t) continue;   // 흙에 묻히는 끝
      const top = Math.round(y - th), bot = Math.round(y + th * 0.34);
      for (let yy = top; yy <= bot; yy++) {
        const u = bot === top ? 0.5 : (yy - top) / (bot - top);
        let c = BARK[3];
        if (u < 0.30) c = (dir < 0 ? BARK[0] : BARK[1]);   // 등 — 볕은 왼쪽에서
        else if (u < 0.62) c = BARK[2];
        else if (u > 0.86) c = BARK[4];               // 배 — 땅에 닿은 그늘
        g.px(x, yy, c);
      }
    }
  });
}


// ---- 밑동 ----
//
// 나무 밑동이 잔디에 그냥 꽂혀 있으면 「심어 놓은 모형」이다. 오래 선 나무
// 밑에는 늘 **드러난 흙**이 있고, 그 위로 떨군 잎과 잔가지가 쌓이며,
// 흙과 잔디의 경계에만 풀이 웃자란다. 접지 그늘이 「닿아 있다」를 말한다면
// 이 넷은 「오래 있었다」를 말한다.
//
// 흙은 **반쯤 비치게** 깐다. 불투명하게 칠하면 잔디 위에 붙인 갈색 딱지가
// 되고, 게임이 실시간으로 까는 접지 그늘이 흙 위를 지나가지 못해 밑동만
// 혼자 환해진다. 비쳐야 그늘과 흙이 한 장으로 겹친다.
// 그리고 **이미 그려진 칸은 건드리지 않는다** — 그래야 흙이 뿌리 사이만
// 메워서, 따로 맞출 것 없이 뿌리 모양을 그대로 따라간다.
const RX = 18, RY = 3.5, SK = 1.4;                  // 흙자리 — 반지름과 기울기

function litter(g, cx, base, seed) {
  // ① 드러난 흙
  for (let y = base - 4; y <= base + 3; y++)
    for (let x = cx - RX - 3; x <= cx + RX + 3; x++) {
      const d = ((x - cx - SK) / RX) ** 2 + ((y - base - 0.2) / RY) ** 2;
      if (d > 1.0) continue;
      // 흙 속에 잠긴 윤곽선은 **먹색에서 흙색으로** 바꾼다. 뿌리는 흙 위에
      // 놓인 물건이 아니라 흙에 묻힌 것이라, 검은 테를 두르면 밑동이
      // 시커먼 얼룩이 된다 — 테는 지우지 말고 흙빛으로 낮춘다
      if (g.get(x, y) === OUT) { g.px(x, y, SOIL[2]); continue; }
      if (g.get(x, y)) continue;
      if (d > 0.40 && h(x, y, seed + 71) < d * 0.80) continue;   // 가장자리를 허문다
      const v = h(x, y >> 1, seed + 72);
      const c = d < 0.32 ? (v < 0.52 ? SOIL[2] : SOIL[1])
        : (v < 0.36 ? SOIL[1] : SOIL[0]);
      g.px(x, y, [c[0], c[1], c[2], 222]);
    }
  // 줄기가 흙에 닿는 자리 — 어두운 골 한 겹. 이게 없으면 줄기가 흙 위에
  // 세워 놓은 것처럼 보인다. 파묻힌 것과 얹힌 것의 차이는 이 한 겹이다
  for (let y = base - 2; y <= base + 2; y++)
    for (let x = cx - 14; x <= cx + 14; x++) {
      const d = ((x - cx - SK) / 9.5) ** 2 + ((y - base - 0.2) / 2.2) ** 2;
      if (d > 1.0) continue;
      const cur = g.get(x, y);
      if (cur && cur.length < 4) continue;
      if (h(x, y, seed + 75) < 0.18) continue;
      g.px(x, y, [34, 26, 22, d < 0.45 ? 116 : 64]);
    }
  // 흙에 박힌 잔돌 둘 — 크기 대비를 준다
  for (let i = 0; i < 2; i++) {
    const x = Math.round(cx + (h(i, 11, seed + 73) - 0.5) * RX * 1.5);
    const y = Math.round(base + 0.5 + h(11, i, seed + 74) * 2.0);
    if (g.get(x, y) && g.get(x, y).length < 4) continue;
    g.px(x, y, [128, 122, 118, 235]); g.px(x + 1, y, [104, 98, 96, 235]);
    g.px(x, y + 1, [72, 68, 68, 235]); g.px(x + 1, y + 1, [72, 68, 68, 235]);
  }
  // ② 떨군 잎 — 흙 위에 더 많이, 잔디 쪽으로 갈수록 성글게
  for (let i = 0; i < 20; i++) {
    const a = Math.PI * 2 * h(i, 1, seed + 81);
    const rr = 5 + h(1, i, seed + 82) * (RX + 3);
    const x = Math.round(cx + SK + Math.cos(a) * rr);
    const y = Math.round(base + Math.sin(a) * rr * 0.27);
    if (rr > RX * 0.85 && h(i, 12, seed + 92) < 0.45) continue;
    const c = [LEAF[5], LEAF_SHADE[5], [126, 104, 58], [148, 118, 62]][i % 4];
    g.px(x, y, c);
    if (h(i, 2, seed + 83) < 0.6) g.px(x + 1, y, c);
    if (h(i, 13, seed + 93) < 0.3) g.px(x, y + 1, [c[0] * 0.7 | 0, c[1] * 0.7 | 0, c[2] * 0.7 | 0]);
  }
  // ③ 잔가지 — 두 칸 두께에, 흙자리 안에
  for (let i = 0; i < 4; i++) {
    const x = Math.round(cx + (h(i, 3, seed + 84) - 0.5) * RX * 1.6);
    const y = base + (h(3, i, seed + 85) < 0.5 ? 0 : 1);
    const len = 3 + Math.floor(h(i, 4, seed + 86) * 3);
    for (let k = 0; k < len; k++) {
      g.px(x + k, y, BARK[2]);
      g.px(x + k, y + 1, BARK[4]);
    }
  }
  // ④ 흙 언저리에 돋은 풀 — 한 칸짜리 세로 획은 풀이 아니라 철사다.
  //    두세 칸으로 벌어진 **포기**여야 풀로 읽힌다. 흙과 잔디의 경계에만 둔다
  for (let i = 0; i < 12; i++) {
    const a = Math.PI * (0.03 + 0.94 * h(i, 5, seed + 87));      // 앞쪽 반원
    const rr = RX * (0.92 + h(5, i, seed + 90) * 0.26);
    const x = Math.round(cx + SK + Math.cos(a) * rr);
    const y = Math.round(base + 0.2 + Math.sin(a) * RY * 0.80);
    const hgt = 2 + Math.floor(h(i, 6, seed + 88) * 3);
    const sun = h(i, 8, seed + 91) < 0.34;
    for (let k = 0; k < hgt; k++)
      g.px(x, y - k, k === hgt - 1 ? (sun ? LEAF_SUN[2] : LEAF[2]) : LEAF[4]);
    const sh = Math.max(1, hgt - 1);
    g.px(x - 1, y - sh + 1, LEAF[3]);
    g.px(x + 1, y - sh + 1, LEAF_SHADE[3]);
    g.px(x - 1, y, LEAF[5]);
    g.px(x + 1, y, LEAF[5]);
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
  // ①-b **잎 뭉치 안에도 잎 뭉치가 있다.**
  //
  // 큰 뭉치 예닐곱으로 부피는 났는데, 뭉치 하나하나가 여전히 매끈한 면이라
  // 가까이 보면 초록 언덕이었다. 실제 나무의 잎은 **두 겹으로 뭉친다** —
  // 큰 가지마다 덩어리가 앉고, 그 덩어리 안에 잔가지마다 손바닥만 한
  // 잎 뭉치가 다시 앉는다.
  //
  // 잔 뭉치는 다섯 칸쯤이다. 격자를 흔들어 보로노이로 나누고, 뭉치마다
  // 왼위를 한 단 밝게 오른아래를 한 단 어둡게, 경계는 한 단 더 어둡게.
  // **난수가 아니라 덩어리**라야 잡음이 아니라 결이 된다.
  {
    const C = 5;
    const cell = (ci, cj) => [
      ci * C + h(ci, cj, seed + 61) * (C - 1),
      cj * C + h(cj, ci, seed + 63) * (C - 1)];
    const snap = new Map();
    const at = (ci, cj) => {
      const k = ci * 8191 + cj;
      if (!snap.has(k)) snap.set(k, cell(ci, cj));
      return snap.get(k);
    };
    const buf = [];
    for (let y = 0; y < g.h; y++) for (let x = 0; x < g.w; x++) {
      const c0 = g.get(x, y);
      if (!isLeafRaw(c0)) continue;
      const ci = Math.floor(x / C), cj = Math.floor(y / C);
      let bd = 9e9, sd = 9e9, bx2 = 0, by2 = 0;
      for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) {
        const [px2, py2] = at(ci + di, cj + dj);
        const d = (x - px2) ** 2 + (y - py2) ** 2;
        if (d < bd) { sd = bd; bd = d; bx2 = px2; by2 = py2; }
        else if (d < sd) sd = d;
      }
      let sh = 0;
      const t2 = ((x - bx2) * 0.55 + (y - by2) * 0.85) / C;
      sh += Math.round(t2 * 1.9);
      // 잔 뭉치의 경계 — 두 거리가 비슷하면 잎과 잎 사이의 골
      if (Math.sqrt(sd) - Math.sqrt(bd) < 0.9) sh += 1;
      if (sh === 0) continue;
      buf.push([x, y, c0, sh]);
    }
    for (const [x, y, c0, sh] of buf) {
      const lad = LEAF_SUN.indexOf(c0) >= 0 ? LEAF_SUN
        : (LEAF_SHADE.indexOf(c0) >= 0 ? LEAF_SHADE : LEAF);
      const idx = Math.max(LEAF.indexOf(c0), LEAF_SUN.indexOf(c0), LEAF_SHADE.indexOf(c0));
      g.px(x, y, lad[clamp(idx + sh, 0, 7)]);
    }
  }
  // ①-c **볕이 든 자리 — 잎 몇 뭉치는 통째로 반짝인다.**
  // 명암이 고르게 흐르기만 하면 그림자 그린 공이다. 나무가 살아 보이는 건
  // 잎 사이로 새어 든 볕이 **몇 군데만** 환하게 얹히기 때문이다
  for (let k = 0; k < 12; k++) {
    const ang = Math.PI * (1.02 + h(k, 6, seed + 65) * 0.76);
    const rr = 0.34 + h(k, 7, seed + 67) * 0.52;
    const sx = Math.round(o.cx + Math.cos(ang) * o.rw * rr);
    const sy = Math.round(o.cy + Math.sin(ang) * o.rh * rr);
    for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 3; dx++) {
      const c0 = g.get(sx + dx, sy + dy);
      if (!isLeafRaw(c0)) continue;
      const idx = Math.max(LEAF.indexOf(c0), LEAF_SUN.indexOf(c0), LEAF_SHADE.indexOf(c0));
      g.px(sx + dx, sy + dy, LEAF_SUN[clamp(idx - 2, 0, 7)]);
    }
    g.px(sx + 1, sy - 1, LEAF_SUN[0]);
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


// ---- 실루엣 밖으로 뻗은 잎 가지 ----
//
// 윤곽을 아무리 울퉁불퉁하게 해도 그건 「덩어리의 가장자리」다. 나무의
// 윤곽이 살아 있는 건 잔가지 끝의 잎이 **한 뭉치씩** 삐져나오기 때문이다.
//
// 다만 **윤곽선을 두른 뒤에** 얹어야 한다. 먼저 얹었더니 한 칸짜리 잎마다
// 검은 테가 통째로 둘려서, 나무가 아니라 **가시 돋친 밤송이**가 됐다.
// 그리고 한 칸이 아니라 두세 칸 뭉치라야 잎으로 보인다.
function sprigs(g, o, seed) {
  for (let k = 0; k < 20; k++) {
    const ang = Math.PI * 2 * h(k, 11, seed + 71);
    let sx = o.cx + Math.cos(ang) * o.rw * 0.99;
    let sy = o.cy + Math.sin(ang) * o.rh * 0.99;
    let tries = 0;
    while (!isLeafRaw(g.get(Math.round(sx), Math.round(sy))) && tries < 10) {
      sx -= Math.cos(ang) * 1.2; sy -= Math.sin(ang) * 1.2; tries++;
    }
    if (tries >= 10) continue;
    const dark = Math.sin(ang) > 0.15;
    const lad = dark ? LEAF_SHADE : LEAF_SUN;
    const px2 = Math.round(sx + Math.cos(ang) * 2.2);
    const py2 = Math.round(sy + Math.sin(ang) * 2.2);
    // 두 칸짜리 잎 뭉치 — 가운데가 밝고 아랫변이 그늘이다
    for (let dy = 0; dy <= 1; dy++) for (let dx = 0; dx <= 1; dx++) {
      const x = px2 + dx, y = py2 + dy;
      if (x < 1 || y < 1 || x >= g.w - 1 || y >= g.h - 1) continue;
      g.px(x, y, lad[dy ? 5 : 3]);
    }
    if (h(k, 13, seed + 77) < 0.55) {
      const x2 = px2 + Math.round(-Math.sin(ang) * 2);
      const y2 = py2 + Math.round(Math.cos(ang) * 2);
      g.px(x2, y2, lad[4]); g.px(x2 + 1, y2, lad[3]);
    }
    // 잎을 매단 잔가지 — 잎 뭉치와 몸통을 잇는다
    for (let t = 1; t < 3; t++) {
      const x = Math.round(sx + Math.cos(ang) * t);
      const y = Math.round(sy + Math.sin(ang) * t);
      g.px(x, y, BARK[3]);
    }
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
  const opt = { holes: 3, limbs: [
    [cx - 2, SPEC.top + 40, -0.9, -0.75, 12],
    [cx + 3, SPEC.top + 42, 0.85, -0.8, 11],
    [cx, SPEC.top + 38, 0.15, -1, 10],
  ] };
  canopy(g, B, seed, opt);
  outline(g);
  // **윤곽선 뒤에** 얹는 것들 — 한 칸짜리 잎과 잔가지는 테를 두르면
  // 잎이 아니라 검은 가시가 된다
  sprigs(g, opt, seed);
  litter(g, cx, 78, seed);
  return g;
}


// ---- 열매 나무 ----
// 다 자란 나무에 사과 셋. 잎 그늘 속이 아니라 **가장자리**에 달려야 보인다
function appleTree() {
  const g = fullTreeRaw(0, 220);   // 이미 윤곽선과 잔가지까지 마친 나무
  const spots = [[24, 34], [55, 30], [40, 47]];
  for (const [ax, ay] of spots) {
    g.disc(ax, ay, 3.0, 2.8, FRUIT[1]);
    g.disc(ax, ay, 2.4, 2.2, FRUIT[0]);
    g.disc(ax - 1, ay - 1, 1.0, 0.9, FRUIT[2]);
    g.px(ax, ay - 3, BARK[3]);                 // 꼭지
    g.px(ax + 1, ay - 3, LEAF[2]);
    // 사과에는 제 테를 두른다 — 잎 속에 묻히면 붉은 얼룩이 된다
    for (let a2 = 0; a2 < 22; a2++) {
      const t = a2 / 22 * Math.PI * 2;
      const x = Math.round(ax + Math.cos(t) * 3.4), y = Math.round(ay + Math.sin(t) * 3.2);
      if (!g.get(x, y) || FRUIT.indexOf(g.get(x, y)) < 0) g.px(x, y, OUT);
    }
  }
  return g;
}
const ARaw = { holes: 2, limbs: [
  [39, 46, -0.9, -0.75, 11], [44, 48, 0.85, -0.8, 10],
] };
function fullTreeRaw(v, seedBase) {
  const g = new T();
  const seed = seedBase;
  const cx = 41;
  trunk(g, cx, 42, 78, 7, 13, seed, 1.2);
  branch(g, cx - 3, 48, -1, -0.7, 9, 2);
  branch(g, cx + 3, 51, 1, -0.8, 8, 2);
  const W = 29;
  canopy(g, [
    [cx, 21, W * 0.62, 14], [cx - W * 0.52, 28, W * 0.48, 12],
    [cx + W * 0.52, 27, W * 0.5, 12.5], [cx - W * 0.26, 37, W * 0.46, 11],
    [cx + W * 0.3, 38, W * 0.44, 10.5], [cx, 14, W * 0.4, 9],
  ], seed, ARaw);
  outline(g);
  sprigs(g, ARaw, seedBase);
  litter(g, cx, 78, seedBase);
  return g;
}


// ---- 어린 나무 ----
// 다 자란 나무를 그냥 줄이면 **작은 어른**이다. 어린 나무는 비례가 다르다 —
// 줄기가 가늘고 길며 잎이 적다
function youngTree() {
  const g = new T();
  const seed = 300;
  const cx = 41;
  trunk(g, cx, 46, 78, 4, 7, seed, 2.4);
  branch(g, cx - 2, 52, -1, -0.9, 5, 1);
  const yo = { holes: 1 };
  canopy(g, [
    [cx, 40, 13, 9], [cx - 9, 47, 10, 8], [cx + 10, 46, 10, 8],
    [cx, 32, 9, 7],
  ], seed, yo);
  outline(g);
  sprigs(g, yo, seed);
  litter(g, cx, 78, seed);
  return g;
}


// ---- 도끼가 든 나무 ----
// 두 단계. 잎이 반쯤 떨어지고(06), 줄기만 남는다(09).
function choppedTree(stage) {
  const g = new T();
  const seed = 400 + stage * 17;
  const cx = 41;
  if (stage === 0) {                            // 반쯤 남은 잎
    trunk(g, cx, 42, 78, 7, 13, seed, 1.2);
    branch(g, cx - 3, 48, -1, -0.7, 11, 2);
    branch(g, cx + 3, 51, 1, -0.8, 10, 2);
    branch(g, cx, 44, 0.2, -1, 8, 2);
    const co = { holes: 2 };
    canopy(g, [
      [cx - 12, 30, 14, 11], [cx + 13, 27, 13, 10], [cx - 2, 20, 11, 9],
    ], seed, co);
    g._co = co;
    // 떨어지는 잎 몇 장
    for (let i = 0; i < 7; i++) {
      const x = 12 + Math.round(h(i, 1, seed) * 58);
      const y = 52 + Math.round(h(1, i, seed) * 20);
      g.px(x, y, LEAF[3]); g.px(x + 1, y, LEAF[5]);
    }
  } else {                                       // 그루터기 — 잘린 면이 보인다
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
  outline(g);
  if (g._co) sprigs(g, g._co, seed);
  litter(g, cx, 78, seed);
  return g;
}


// ---- 잎을 다 떨군 나무 ----
// 옛 전망대 곁의 굽은 나무(bent_tree)와 겨울 나무가 함께 쓴다.
// 잎이 없으므로 **가지의 갈라짐**이 전부다 — 굵은 데서 가는 데로, 세 번 갈린다
function bareTree() {
  const g = new T();
  const seed = 500;
  const cx = 41;
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
  outline(g);
  litter(g, cx, 78, seed);        // 잎을 떨군 나무일수록 밑동에 쌓인 게 많다
  return g;
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
