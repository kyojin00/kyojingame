// 생선구이(todtjsrndl) — 32x32 (기존 dish_grilled_fish 규격).
// 흰 배경을 가장자리에서 흘려 지운 뒤 상자를 잡아 가운데에 앉힌다 —
// 그림 안쪽의 밝은 하이라이트는 살아남는다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/cut_grilled_fish.js
const fs = require('fs'), { PNG } = require('pngjs');
const im = PNG.sync.read(fs.readFileSync(__dirname + '/src/ref_grilled_fish.png'));
const W = im.width, H = im.height, d = im.data;

// ① 가장자리에서 「거의 흰 색」만 흘려 지운다
const isWhite = (x, y) => {
  const k = (y * W + x) * 4;
  return d[k] > 226 && d[k + 1] > 226 && d[k + 2] > 226;
};
const bg = new Uint8Array(W * H);
const q = [];
for (let x = 0; x < W; x++) q.push([x, 0], [x, H - 1]);
for (let y = 0; y < H; y++) q.push([0, y], [W - 1, y]);
while (q.length) {
  const [x, y] = q.pop();
  if (x < 0 || y < 0 || x >= W || y >= H) continue;
  const i = y * W + x;
  if (bg[i] || !isWhite(x, y)) continue;
  bg[i] = 1;
  q.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
}

// ② 남은 그림의 상자
let x0 = W, y0 = H, x1 = -1, y1 = -1;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = y * W + x;
  if (bg[i] || d[i * 4 + 3] < 60) { d[i * 4 + 3] = 0; continue; }
  if (x < x0) x0 = x; if (x > x1) x1 = x;
  if (y < y0) y0 = y; if (y > y1) y1 = y;
}
const bw = x1 - x0 + 1, bh = y1 - y0 + 1;

// ③ 32x32 한가운데로 (아이콘은 바닥에 붙이지 않는다 — 가방 칸 한가운데에 뜬다)
const S = 32;
const s = Math.min(S / bw, S / bh), inv = 1 / s;
const ow = Math.round(bw * s), oh = Math.round(bh * s);
const ox = (S - ow) >> 1, oy = (S - oh) >> 1;
const o = new PNG({ width: S, height: S });
o.data.fill(0);
for (let y = 0; y < oh; y++) for (let x = 0; x < ow; x++) {
  let r = 0, g = 0, b = 0, a = 0, n = 0;
  for (let j = Math.floor(y * inv); j < Math.max(Math.floor(y * inv) + 1, Math.floor((y + 1) * inv)); j++)
    for (let i = Math.floor(x * inv); i < Math.max(Math.floor(x * inv) + 1, Math.floor((x + 1) * inv)); i++) {
      const sy = Math.min(H - 1, y0 + j), sx = Math.min(W - 1, x0 + i);
      const k = (sy * W + sx) * 4, al = d[k + 3] / 255;
      n++; r += d[k] * al; g += d[k + 1] * al; b += d[k + 2] * al; a += al;
    }
  if (!n || a / n < 0.35) continue;
  const k2 = ((oy + y) * S + ox + x) * 4;
  o.data[k2] = r / a; o.data[k2 + 1] = g / a; o.data[k2 + 2] = b / a; o.data[k2 + 3] = 255;
}
fs.writeFileSync(__dirname + '/../sprites/dish_grilled_fish.png', PNG.sync.write(o));
console.log('dish_grilled_fish.png 32x32 완료 (상자 %dx%d)', bw, bh);
