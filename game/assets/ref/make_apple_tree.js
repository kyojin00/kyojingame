// 사과나무(과수원, S6a) — 다 자란 작물 그림 mature_apple.png(64x64). 원본 없이 도트로 그린다.
// 실행: cd game/assets/ref && node make_apple_tree.js
const fs = require('fs'), { PNG } = require('pngjs');
const S = 64, im = new PNG({ width: S, height: S });
function px(x, y, r, g, b, a = 255) {
  if (x < 0 || y < 0 || x >= S || y >= S) return;
  const i = (y * S + x) * 4; im.data[i] = r; im.data[i + 1] = g; im.data[i + 2] = b; im.data[i + 3] = a;
}
function disc(cx, cy, rad, col, jitter) {
  for (let y = -rad; y <= rad; y++) for (let x = -rad; x <= rad; x++) {
    const d = Math.sqrt(x * x + y * y);
    if (d > rad + 0.3) continue;
    const k = 1 - d / (rad + 1) * 0.35;                       // 가장자리는 어둡게 — 둥근 맛
    const n = ((x * 7 + y * 13) % 5) * jitter;                   // 잎의 결
    px(cx + x, cy + y, Math.round(col[0] * k + n), Math.round(col[1] * k + n), Math.round(col[2] * k + n));
  }
}
// 밑동 그림자
for (let x = 22; x < 42; x++) for (let y = 58; y < 62; y++) px(x, y, 40, 30, 20, 90);
// 줄기
for (let y = 36; y < 60; y++) for (let x = 28; x < 36; x++) {
  const edge = x === 28 || x === 35;
  px(x, y, edge ? 74 : 108, edge ? 48 : 74, edge ? 28 : 40);
}
for (let y = 40; y < 50; y++) { px(24 + Math.floor((49 - y) / 2), y, 92, 62, 34); px(25 + Math.floor((49 - y) / 2), y, 108, 74, 40); }
// 잎 — 겹친 원 넷
disc(32, 24, 17, [60, 130, 52], 3);
disc(22, 30, 11, [52, 118, 46], 3);
disc(43, 29, 11, [66, 138, 56], 3);
disc(32, 15, 10, [78, 150, 64], 3);
// 사과 — 붉은 점 일곱, 밝은 점 하나씩
[[24, 22], [36, 18], [42, 30], [28, 32], [18, 31], [34, 27], [40, 21]].forEach(([x, y]) => {
  for (let dy = -1; dy <= 2; dy++) for (let dx = -1; dx <= 2; dx++) {
    const d = Math.abs(dx - 0.5) + Math.abs(dy - 0.5);
    if (d <= 2.2) px(x + dx, y + dy, 196, 44, 40);
  }
  px(x, y, 236, 110, 100); px(x + 1, y - 2, 96, 66, 30);
});
fs.writeFileSync(__dirname + '/../sprites/mature_apple.png', PNG.sync.write(im));
console.log('wrote sprites/mature_apple.png');
