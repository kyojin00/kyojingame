// 물뿌리개 아이콘(anf) — 나무 물뿌리개. 32x32 (기존 icon_water 규격).
// 다시 갈면 이 스크립트만 돌리면 된다. 원본: ref/src/ref_water.png
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/cut_water.js
const fs = require('fs'), { PNG } = require('pngjs');
const im = PNG.sync.read(fs.readFileSync(__dirname + '/src/ref_water.png'));
let x0 = im.width, y0 = im.height, x1 = 0, y1 = 0;
for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
  if (im.data[(y * im.width + x) * 4 + 3] < 40) continue;
  if (x < x0) x0 = x; if (x > x1) x1 = x;
  if (y < y0) y0 = y; if (y > y1) y1 = y;
}
const bw = x1 - x0 + 1, bh = y1 - y0 + 1, S = 32;
const scale = Math.min(S / bw, S / bh);
const dw = Math.round(bw * scale), dh = Math.round(bh * scale);
const ox = Math.floor((S - dw) / 2), oy = Math.floor((S - dh) / 2);
const out = new PNG({ width: S, height: S });
for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
  const sx = x0 + Math.min(bw - 1, Math.floor(x / scale));
  const sy = y0 + Math.min(bh - 1, Math.floor(y / scale));
  const sk = (sy * im.width + sx) * 4, dk = ((y + oy) * S + x + ox) * 4;
  if (im.data[sk + 3] < 40) continue;
  out.data[dk] = im.data[sk]; out.data[dk + 1] = im.data[sk + 1];
  out.data[dk + 2] = im.data[sk + 2]; out.data[dk + 3] = 255;
}
fs.writeFileSync(__dirname + '/../sprites/icon_water.png', PNG.sync.write(out));
console.log('icon_water.png 32x32 완료 (bbox', bw, 'x', bh, ')');
