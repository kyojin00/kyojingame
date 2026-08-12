// 조개 일러스트(src/ref_icon_shell.png, 흰 배경)를 채집물 규격(64x64)으로.
// 배경이 흰색이라 가장자리에서 「거의 흰 색」만 흘려 지운다 — 조개 안의
// 흰 하이라이트는 바깥과 이어지지 않아 살아남는다.
// 실행:  node cut_shell.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const p = PNG.sync.read(fs.readFileSync(__dirname + '/src/ref_icon_shell.png'));
const W = p.width, H = p.height, d = p.data;
const white = (x, y) => {
  const k = (y * W + x) * 4;
  return d[k] > 228 && d[k + 1] > 228 && d[k + 2] > 228;
};
const out = new Uint8Array(W * H);
const q = [];
for (let x = 0; x < W; x++) q.push([x, 0], [x, H - 1]);
for (let y = 0; y < H; y++) q.push([0, y], [W - 1, y]);
while (q.length) {
  const [x, y] = q.pop();
  if (x < 0 || y < 0 || x >= W || y >= H) continue;
  const i = y * W + x;
  if (out[i] || !white(x, y)) continue;
  out[i] = 1;
  q.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
}
let x0 = W, x1 = -1, y0 = H, y1 = -1;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = y * W + x;
  if (out[i]) { d[i * 4 + 3] = 0; continue; }
  if (x < x0) x0 = x; if (x > x1) x1 = x;
  if (y < y0) y0 = y; if (y > y1) y1 = y;
}
const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
const SIZE = 64, T = SIZE - 4;               // 여백 2px
const s = Math.min(T / bw, T / bh), inv = 1 / s;
const ow = Math.round(bw * s), oh = Math.round(bh * s);
const ox = (SIZE - ow) >> 1, oy = (SIZE - oh) >> 1;
const o = new PNG({ width: SIZE, height: SIZE });
o.data.fill(0);
for (let y = 0; y < oh; y++) for (let x = 0; x < ow; x++) {
  let r = 0, g = 0, b = 0, a = 0, n = 0;
  for (let j = Math.floor(y * inv); j < Math.floor((y + 1) * inv); j++)
    for (let i = Math.floor(x * inv); i < Math.floor((x + 1) * inv); i++) {
      const k = ((y0 + j) * W + x0 + i) * 4, al = d[k + 3] / 255;
      n++; r += d[k] * al; g += d[k + 1] * al; b += d[k + 2] * al; a += al;
    }
  if (!n || a / n < 0.4) continue;
  const k2 = ((oy + y) * SIZE + ox + x) * 4;
  o.data[k2] = r / a; o.data[k2 + 1] = g / a; o.data[k2 + 2] = b / a; o.data[k2 + 3] = 255;
}
fs.writeFileSync(__dirname + '/../sprites/forage_shell.png', PNG.sync.write(o));
console.log('forage_shell.png <- ref_icon_shell (상자 %dx%d)', bw, bh);
