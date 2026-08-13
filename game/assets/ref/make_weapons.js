// 초반 무기 도트 — 돌 창 · 돌 검 · 화살 (컬렉션 「풋내기 모험가의 무기」).
// 유저가 그림을 주면 같은 파일 이름으로 얹으면 교체된다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_weapons.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

function make(s) { return new PNG({ width: s, height: s }); }
function px(p, x, y, c) {
  if (x < 0 || y < 0 || x >= p.width || y >= p.height) return;
  const k = (y * p.width + x) * 4;
  p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2]; p.data[k + 3] = 255;
}
function rect(p, x, y, w, h, c) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(p, x + i, y + j, c);
}
// 대각선 굵은 선 (좌하단 -> 우상단)
function shaft(p, x0, y0, len, c, w) {
  for (let i = 0; i < len; i++)
    for (let j = 0; j < w; j++) { px(p, x0 + i, y0 - i + j, c); px(p, x0 + i + 1, y0 - i + j, c); }
}
const WOOD = [140, 95, 52], WOOD_D = [104, 70, 38], STONE = [150, 150, 158],
  STONE_L = [196, 196, 204], STONE_D = [100, 100, 110], DK = [52, 44, 36],
  CORD = [180, 140, 70];

// ---- 돌 창 (느리고 강하게 한 방) ----
{
  const p = make(32);
  shaft(p, 4, 26, 17, WOOD, 2);            // 긴 자루
  shaft(p, 5, 28, 16, WOOD_D, 1);
  rect(p, 19, 7, 3, 3, CORD);              // 묶은 끈
  // 돌 촉 (크고 뾰족)
  rect(p, 21, 6, 4, 4, STONE); rect(p, 23, 4, 4, 3, STONE);
  rect(p, 25, 2, 3, 3, STONE_L); px(p, 27, 1, STONE_L);
  rect(p, 21, 9, 3, 2, STONE_D);
  px(p, 20, 10, DK); px(p, 28, 0, DK);
  fs.writeFileSync(OUT + 'icon_spear.png', PNG.sync.write(p));
  console.log('icon_spear.png');
}

// ---- 돌 검 (빠르게 두 번) ----
{
  const p = make(32);
  // 돌 날 (넓적)
  shaft(p, 10, 20, 11, STONE, 3);
  shaft(p, 11, 22, 10, STONE_L, 1);
  shaft(p, 9, 19, 10, STONE_D, 1);
  px(p, 23, 7, STONE_L);
  // 코등이 + 자루
  rect(p, 8, 21, 6, 3, DK);
  shaft(p, 4, 27, 5, WOOD, 2);
  rect(p, 3, 28, 3, 3, WOOD_D);            // 자루 끝
  fs.writeFileSync(OUT + 'icon_sword.png', PNG.sync.write(p));
  console.log('icon_sword.png');
}

// ---- 화살 ----
{
  const p = make(32);
  shaft(p, 7, 23, 15, WOOD, 1);            // 살대
  rect(p, 22, 6, 3, 3, STONE); px(p, 24, 5, STONE_L); px(p, 21, 8, STONE_D);  // 촉
  // 깃 (빨강)
  rect(p, 5, 24, 3, 2, [200, 70, 60]); rect(p, 7, 26, 3, 2, [200, 70, 60]);
  rect(p, 4, 26, 3, 2, [160, 50, 44]);
  fs.writeFileSync(OUT + 'arrow.png', PNG.sync.write(p));
  console.log('arrow.png');
}
