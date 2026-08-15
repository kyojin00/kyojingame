// 집 안 제작대(cortkd) 교체 — 원본(641x641, 투명 배경)의 여백을 잘라
// 폭 105px(집 안 DESK 칸 폭)에 맞춰 줄인다. 세로는 비율대로 —
// interior_ui가 바닥선(DESK.end.y)에 밑변을 맞춰 그린다.
// 다시 갈면 이 스크립트만 돌리면 된다. 원본: ref/src/ref_desk.png
// (배경 있는 판은 ref/src/ref_desk_bg.png 보관)
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/cut_desk.js
const fs = require('fs'), { PNG } = require('pngjs');
const im = PNG.sync.read(fs.readFileSync(__dirname + '/src/ref_desk.png'));
let x0 = im.width, y0 = im.height, x1 = 0, y1 = 0;
for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
  if (im.data[(y * im.width + x) * 4 + 3] < 40) continue;
  if (x < x0) x0 = x; if (x > x1) x1 = x;
  if (y < y0) y0 = y; if (y > y1) y1 = y;
}
const bw = x1 - x0 + 1, bh = y1 - y0 + 1, W = 105;
const scale = W / bw;
const dw = W, dh = Math.round(bh * scale);
const out = new PNG({ width: dw, height: dh });
for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
  const sx = x0 + Math.min(bw - 1, Math.floor(x / scale));
  const sy = y0 + Math.min(bh - 1, Math.floor(y / scale));
  const sk = (sy * im.width + sx) * 4, dk = (y * dw + x) * 4;
  if (im.data[sk + 3] < 40) continue;
  out.data[dk] = im.data[sk]; out.data[dk + 1] = im.data[sk + 1];
  out.data[dk + 2] = im.data[sk + 2]; out.data[dk + 3] = 255;
}
fs.writeFileSync(__dirname + '/../sprites/desk.png', PNG.sync.write(out));
console.log('desk.png', dw, 'x', dh, '완료 (bbox', bw, 'x', bh, ')');
