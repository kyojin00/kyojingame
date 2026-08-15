// 엔딩 아이템 아이콘 2장 — make_item_icons.js 와 같은 방식(16x16 → 2배).
// 전체 생성기를 돌리면 유저가 갈아 둔 그림까지 덮어써서, 새 두 장만 찍는다.
//   water_life    생명의 물 (맑게 빛나는 유리병 — 할아버지의 유품)
//   potion_dream  기억의 물약 (은은한 보랏빛, 금빛 마개)
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_ending_icons.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 2;

const C = {
  line:  [42, 28, 24],
  white: [246, 244, 238], ice: [190, 232, 246],
  blue:  [92, 156, 224],  blue2: [58, 108, 176],
  purple:[142, 96, 190],  purple2:[100, 64, 140], pink: [238, 132, 140],
  gold:  [240, 196, 72],  gold2: [198, 150, 40],
  brown2:[110, 70, 40],
};

function newCanvas() { return Array.from({ length: S }, () => new Array(S).fill(null)); }
const inb = (x, y) => x >= 0 && y >= 0 && x < S && y < S;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col); }
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
  // 생명의 물 — 코르크 마개의 둥근 병, 안에서 물이 빛난다
  water_life: () => {
    const c = newCanvas();
    rect(c, 7, 2, 2, 2, C.brown2);            // 코르크
    rect(c, 6, 4, 4, 2, C.ice);               // 병목
    rect(c, 4, 6, 8, 8, C.ice);               // 병 몸통
    rect(c, 5, 8, 6, 5, C.blue);              // 물
    rect(c, 5, 8, 6, 1, C.white);             // 수면의 빛
    px(c, 6, 10, C.white); px(c, 9, 11, C.ice);   // 반짝임
    px(c, 3, 4, C.white); px(c, 13, 6, C.white);  // 새어 나오는 빛
    return c;
  },
  // 기억의 물약 — 금빛 마개, 보랏빛 물약에 별이 잠겨 있다
  potion_dream: () => {
    const c = newCanvas();
    rect(c, 7, 2, 2, 2, C.gold);              // 금빛 마개
    rect(c, 7, 4, 2, 1, C.gold2);
    rect(c, 6, 5, 4, 2, C.ice);               // 병목
    rect(c, 4, 7, 8, 7, C.ice);               // 병 몸통
    rect(c, 5, 9, 6, 4, C.purple);            // 물약
    px(c, 7, 10, C.white);                    // 잠긴 별
    px(c, 6, 11, C.pink); px(c, 9, 12, C.purple2);
    px(c, 5, 9, C.white);                     // 하이라이트
    px(c, 13, 4, C.white); px(c, 2, 8, C.white);  // 새어 나오는 빛
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
console.log('엔딩 아이콘', n, '장 생성');
