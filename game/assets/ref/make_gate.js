// 마지막 장소 아트 (메인 스토리 20) — 두 장.
//   old_gate      마을에서 가장 오래된 자리의 돌문 (64x96 세계 오브젝트)
//   grandpa_seed  할아버지가 남긴 씨앗 한 알 (16x16 -> 2배 아이콘)
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_gate.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

const C = {
  line:  [42, 28, 24],
  rock:  [124, 118, 124], rock2: [92, 86, 94], rock3: [158, 152, 156],
  dark:  [46, 42, 52],    glow:  [150, 214, 226], glow2: [96, 168, 192],
  moss:  [92, 126, 66],   moss2: [70, 100, 52],
  carve: [64, 56, 62],    gold:  [214, 176, 78],
  seed:  [148, 112, 62],  seed2: [110, 80, 44], sprout: [110, 176, 84],
  white: [246, 244, 238],
};

function canvas(w, h) { return Array.from({ length: h }, () => new Array(w).fill(null)); }
function px(c, x, y, col) { if (c[y] && x >= 0 && x < c[0].length && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col);
}
function outline(c) {
  const h = c.length, w = c[0].length;
  const out = c.map(r => r.slice());
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (c[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (y + dy >= 0 && y + dy < h && x + dx >= 0 && x + dx < w && c[y + dy][x + dx]) near = true;
    if (near) out[y][x] = C.line;
  }
  return out;
}
function save(name, c, zoom) {
  const h = c.length, w = c[0].length;
  const p = new PNG({ width: w * zoom, height: h * zoom });
  p.data.fill(0);
  for (let y = 0; y < h * zoom; y++) for (let x = 0; x < w * zoom; x++) {
    const col = c[Math.floor(y / zoom)][Math.floor(x / zoom)];
    if (!col) continue;
    const i = (y * w * zoom + x) * 4;
    p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
  }
  fs.writeFileSync(OUT + name + '.png', PNG.sync.write(p));
}

// ---- 오래된 돌문 (32x48 -> 2배 = 64x96) ----
// 마을이 서기 훨씬 전부터 있던 자리. 이끼 낀 돌기둥 둘과 상인방,
// 그 사이를 메운 검은 돌벽 — 일곱 자리 홈이 나란히 파여 있다.
{
  const c = canvas(32, 48);
  rect(c, 3, 10, 6, 34, C.rock);        // 왼쪽 기둥
  rect(c, 3, 10, 2, 34, C.rock2);
  rect(c, 23, 10, 6, 34, C.rock);       // 오른쪽 기둥
  rect(c, 27, 10, 2, 34, C.rock2);
  rect(c, 2, 5, 28, 6, C.rock3);        // 상인방
  rect(c, 2, 10, 28, 2, C.rock2);
  rect(c, 9, 14, 14, 30, C.dark);       // 문을 메운 검은 돌
  for (let y = 16; y < 42; y += 5) rect(c, 9, y, 14, 1, C.rock2);   // 돌결
  // 일곱 자리 홈 — 생명의 물이 들어갈 자리
  const slots = [[11, 20], [15, 18], [19, 20], [11, 28], [15, 30], [19, 28], [15, 24]];
  for (const [sx, sy] of slots) { px(c, sx, sy, C.glow2); px(c, sx + 1, sy, C.glow2); }
  px(c, 15, 24, C.glow); px(c, 16, 24, C.glow);
  // 상인방에 새겨진 글씨 자국
  rect(c, 8, 7, 2, 1, C.carve); rect(c, 12, 7, 3, 1, C.carve);
  rect(c, 17, 7, 2, 1, C.carve); rect(c, 21, 7, 3, 1, C.carve);
  px(c, 14, 8, C.gold);
  // 이끼 — 아주 오래 아무도 손대지 않았다
  px(c, 4, 20, C.moss); px(c, 5, 33, C.moss2); px(c, 24, 26, C.moss);
  px(c, 28, 38, C.moss2); px(c, 3, 12, C.moss); px(c, 29, 13, C.moss2);
  rect(c, 2, 44, 6, 2, C.moss2);        // 밑동을 덮은 이끼
  rect(c, 24, 44, 6, 2, C.moss);
  save('old_gate', outline(c), 2);
}

// ---- 할아버지의 씨앗 (16x16 -> 2배) ----
{
  const c = canvas(16, 16);
  rect(c, 6, 6, 4, 6, C.seed);          // 씨앗 몸통
  rect(c, 6, 10, 4, 2, C.seed2);        // 아래 그늘
  px(c, 7, 7, C.white);                 // 반짝임
  rect(c, 7, 4, 2, 2, C.sprout);        // 막 트려는 눈
  px(c, 6, 3, C.sprout); px(c, 9, 3, C.sprout);
  px(c, 5, 5, C.glow); px(c, 10, 6, C.glow);     // 씨앗에서 새는 빛
  px(c, 4, 9, C.glow2); px(c, 11, 10, C.glow2);
  px(c, 8, 13, C.seed2);
  save('grandpa_seed', outline(c), 2);
}

console.log('마지막 장소 아트 2장 생성');
