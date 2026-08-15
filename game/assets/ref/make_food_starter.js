// 「초반 음식」 컬렉션 아이콘 4장 — make_item_icons.js 와 같은 방식
// (16x16 도트 → 2배 확대 32x32). 전체 생성기를 다시 돌리면 유저가 갈아 둔
// 그림(붕어·납자루 등)까지 덮어써 버리므로, 새 넉 장만 따로 찍는다.
//   dish_berry_jam    산딸기잼 (붉은 잼 병)
//   flour             밀가루 (묶은 자루)
//   dish_bread        빵 (통빵 한 덩이)
//   dish_berry_toast  산딸기잼 토스트 (잼 바른 토스트)
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_food_starter.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 2;

const C = {
  line:  [42, 28, 24],
  white: [246, 244, 238], cream: [236, 224, 190], shadow: [198, 186, 160],
  red:   [206, 74, 62],   red2:  [158, 48, 44],   pink: [238, 132, 140],
  brown: [150, 100, 58],  brown2:[110, 70, 40],   crust:[196, 150, 88],
  gold:  [240, 196, 72],  ice:   [190, 232, 246],
};

function newCanvas() { return Array.from({ length: S }, () => new Array(S).fill(null)); }
const inb = (x, y) => x >= 0 && y >= 0 && x < S && y < S;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col); }
function ellipse(c, cx, cy, rx, ry, col) {
  for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++)
    if ((x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1.05) px(c, cx + x, cy + y, col);
}
function outline(c) {
  const out = c.map(r => r.slice());
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    if (c[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]])
      if (inb(x + dx, y + dy) && c[y + dy][x + dx]) near = true;
    if (near) out[y][x] = C.line;
  }
  return out;
}

const ICONS = {
  // 산딸기잼 — 잼 병. 기존 딸기잼(빨강)과 갈리도록 붉은 자주에 알갱이
  dish_berry_jam: () => {
    const c = newCanvas();
    rect(c, 4, 4, 8, 2, C.brown2);             // 뚜껑
    rect(c, 4, 6, 8, 8, C.ice);                // 유리
    rect(c, 5, 8, 6, 5, C.red2);               // 잼
    px(c, 6, 9, C.pink); px(c, 9, 11, C.pink); // 산딸기 알갱이
    px(c, 8, 10, C.red);
    px(c, 5, 7, C.white); px(c, 6, 7, C.white);
    return c;
  },
  // 밀가루 — 목단 자루를 끈으로 묶고 가루가 소복이
  flour: () => {
    const c = newCanvas();
    ellipse(c, 8, 10, 5, 4, C.cream);          // 자루 몸통
    rect(c, 6, 4, 4, 3, C.cream);              // 자루 목
    rect(c, 5, 6, 6, 1, C.brown);              // 묶은 끈
    ellipse(c, 8, 4, 2, 1, C.white);           // 흘러넘친 가루
    px(c, 6, 9, C.white); px(c, 10, 11, C.white); px(c, 8, 12, C.shadow);
    return c;
  },
  // 빵 — 통빵 한 덩이. 윗면에 칼집 두 줄
  dish_bread: () => {
    const c = newCanvas();
    ellipse(c, 8, 8, 6, 4, C.crust);           // 몸통
    ellipse(c, 8, 7, 5, 2, C.gold);            // 윗면
    rect(c, 3, 10, 11, 2, C.brown);            // 아랫단
    px(c, 6, 6, C.cream); px(c, 7, 7, C.cream);   // 칼집
    px(c, 9, 6, C.cream); px(c, 10, 7, C.cream);
    return c;
  },
  // 산딸기잼 토스트 — 비스듬한 토스트에 잼을 바르고 알갱이
  dish_berry_toast: () => {
    const c = newCanvas();
    rect(c, 3, 4, 10, 9, C.crust);             // 빵 귀
    rect(c, 4, 5, 8, 7, C.cream);              // 속살
    rect(c, 5, 6, 6, 4, C.red2);               // 잼
    px(c, 6, 7, C.pink); px(c, 9, 8, C.pink);  // 알갱이
    px(c, 8, 6, C.red);
    rect(c, 4, 13, 9, 1, C.shadow);            // 그림자
    return c;
  },
};

let n = 0;
for (const [id, make] of Object.entries(ICONS)) {
  const c = outline(make());
  const p = new PNG({ width: S * Z, height: S * Z });
  p.data.fill(0);
  for (let y = 0; y < S * Z; y++) for (let x = 0; x < S * Z; x++) {
    const col = c[Math.floor(y / Z)][Math.floor(x / Z)];
    if (!col) continue;
    const i = (y * S * Z + x) * 4;
    p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
  }
  fs.writeFileSync(OUT + id + '.png', PNG.sync.write(p));
  n++;
}
console.log('초반 음식 아이콘', n, '장 생성');
