// 밀 수확물 아이콘(alf) — 밀단. 64x64 (기존 mature_wheat 규격 —
// make_crops.js의 밀 항목 대신 이 그림을 쓴다).
// 다시 갈면 이 스크립트만 돌리면 된다. 원본: ref/src/ref_wheat.png
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/cut_wheat.js
const fs = require('fs'), { PNG } = require('pngjs');
const im = PNG.sync.read(fs.readFileSync(__dirname + '/src/ref_wheat.png'));
let x0 = im.width, y0 = im.height, x1 = 0, y1 = 0;
for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
  if (im.data[(y * im.width + x) * 4 + 3] < 40) continue;
  if (x < x0) x0 = x; if (x > x1) x1 = x;
  if (y < y0) y0 = y; if (y > y1) y1 = y;
}
const bw = x1 - x0 + 1, bh = y1 - y0 + 1, S = 64;
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
fs.writeFileSync(__dirname + '/../sprites/mature_wheat.png', PNG.sync.write(out));
console.log('mature_wheat.png 64x64 완료 (bbox', bw, 'x', bh, ')');
