// 광장 분수(qnstn) — 원본(641x641, 투명 배경)의 여백을 잘라
// 128x160 격자(기존 deco_fountain.png 규격)에 밑변을 맞춰 앉힌다.
// 다시 갈면 이 스크립트만 돌리면 된다. 원본: ref/src/ref_fountain.png
const fs = require('fs'), { PNG } = require('pngjs');
const im = PNG.sync.read(fs.readFileSync(__dirname + '/src/ref_fountain.png'));
let x0 = im.width, y0 = im.height, x1 = 0, y1 = 0;
for (let y = 0; y < im.height; y++)
  for (let x = 0; x < im.width; x++)
    if (im.data[(y * im.width + x) * 4 + 3] > 8) {
      if (x < x0) x0 = x; if (x > x1) x1 = x;
      if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
const bw = x1 - x0 + 1, bh = y1 - y0 + 1, W = 128, H = 160;
const s = Math.min(W / bw, H / bh);
const dw = Math.max(1, Math.round(bw * s)), dh = Math.max(1, Math.round(bh * s));
const ox = Math.floor((W - dw) / 2), oy = H - dh;   // 밑변을 바닥에
const out = new PNG({ width: W, height: H });
for (let y = 0; y < dh; y++)
  for (let x = 0; x < dw; x++) {
    const sx = x0 + Math.min(bw - 1, Math.floor(x / s));
    const sy = y0 + Math.min(bh - 1, Math.floor(y / s));
    const si = (sy * im.width + sx) * 4, di = ((y + oy) * W + (x + ox)) * 4;
    out.data[di] = im.data[si]; out.data[di+1] = im.data[si+1];
    out.data[di+2] = im.data[si+2]; out.data[di+3] = im.data[si+3];
  }
fs.writeFileSync(__dirname + '/../sprites/deco_fountain.png', PNG.sync.write(out));
console.log('deco_fountain.png', W, 'x', H, '완료 (bbox', bw, 'x', bh, ')');
