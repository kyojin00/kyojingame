// 건물 도면 — 이 위에 그리면 자리가 맞는다.
//
// 512x410 캔버스에 「어디까지가 발자국이고, 문은 어디여야 하고, 어디부터는
// 걸어서 통과되는지」를 색으로 표시한다. 게임에 넣는 그림이 아니라
// 사람이 보고 그리는 도면이라 docs/에 둔다.
//
// 실행:  node make_guide.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../../docs/';
const W = 512, H = 410;
const TILE = 64;                 // 게임 한 칸 = 아트 64px

const img = Array.from({ length: H }, () => new Array(W).fill([26, 28, 34]));
const inb = (x, y) => x >= 0 && y >= 0 && x < W && y < H;
function px(x, y, c) { x = Math.round(x); y = Math.round(y); if (inb(x, y)) img[y][x] = c; }
function rect(x, y, w, h, c) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(x + i, y + j, c);
}
function box(x, y, w, h, c, th) {
  th = th || 2;
  for (let k = 0; k < th; k++) {
    for (let i = 0; i < w; i++) { px(x + i, y + k, c); px(x + i, y + h - 1 - k, c); }
    for (let j = 0; j < h; j++) { px(x + k, y + j, c); px(x + w - 1 - k, y + j, c); }
  }
}
function dash(x0, y0, x1, y1, c, on, off) {
  const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
  for (let i = 0; i <= n; i++) {
    if (i % (on + off) >= on) continue;
    px(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, c);
  }
}

// ---- 칸 격자 (64px = 게임 한 칸) ----
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  if (x % TILE === 0 || y % TILE === 0) px(x, y, [44, 48, 58]);
}
// 캔버스 한가운데 세로선 (문 중심)
dash(W / 2, 0, W / 2, H - 1, [90, 96, 112], 4, 6);

// ---- 걸어서 통과되지 않는 범위 (노랑) ----
// main.gd의 _block_under_art: 앵커 기준 7 x 6칸.
// 이 밖으로 삐져나온 그림은 **그냥 통과된다** — 지붕이 여기서 끝나야 한다.
box(32, 26, 480 - 32, 410 - 26, [214, 178, 64], 2);

// ---- 발자국 5 x 4칸 (초록) ----
// 건물이 실제로 차지하는 칸. 이 안은 전부 막힌다.
box(96, 154, 320, 256, [92, 196, 108], 2);
for (let x = 96; x < 416; x++) for (let y = 154; y < 410; y++) {
  if ((x + y) % 16 === 0) px(x, y, [52, 96, 62]);
}

// ---- 문 칸 (빨강) ----
// 앵커 + (2,3). 문은 **반드시 여기 가운데**에 와야 한다.
rect(224, 346, 64, 64, [86, 40, 44]);
box(224, 346, 64, 64, [226, 92, 92], 2);

// ---- 땅에 닿는 선 (흰색) ----
// 벽 밑동은 여기. 아래 15px는 바닥 그림자 자리다.
for (let x = 0; x < W; x++) { px(x, 394, [240, 240, 240]); px(x, 395, [240, 240, 240]); }
dash(0, 409, W - 1, 409, [120, 120, 120], 3, 5);

// ---- 눈금 (왼쪽/위) ----
for (let t = 0; t <= 8; t++) {
  const x = t * TILE;
  for (let k = 0; k < (t % 2 === 0 ? 10 : 5); k++) { px(x, k, [200, 200, 210]); }
}
for (let t = 0; t * TILE < H; t++) {
  const y = t * TILE;
  for (let k = 0; k < (t % 2 === 0 ? 10 : 5); k++) { px(k, y, [200, 200, 210]); }
}

const p = new PNG({ width: W, height: H });
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = (y * W + x) * 4, c = img[y][x];
  p.data[i] = c[0]; p.data[i + 1] = c[1]; p.data[i + 2] = c[2]; p.data[i + 3] = 255;
}
fs.writeFileSync(OUT + 'building_guide.png', PNG.sync.write(p));
console.log('건물 도면 생성: docs/building_guide.png (%dx%d)', W, H);
