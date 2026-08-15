// 낡은 작은 상자 아이콘 1장 (메인 스토리 13) — make_ending_icons.js 와 같은 방식.
//   old_box  바닷물에 오래 잠겨 녹슨 작은 상자 (경첩·자물쇠에 녹과 소금기)
// 전체 생성기(make_item_icons.js)는 유저 교체 아트를 덮어쓰므로 이 한 장만 찍는다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_old_box.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 2;

const C = {
  line:  [42, 28, 24],
  wood:  [104, 78, 52],  wood2: [82, 60, 40],  wood3: [128, 98, 66],
  rust:  [148, 82, 46],  rust2: [110, 58, 34],
  salt:  [222, 224, 218], ice: [190, 232, 246],
  metal: [120, 112, 104],
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
  old_box: () => {
    const c = newCanvas();
    rect(c, 3, 5, 10, 3, C.wood3);            // 둥근 뚜껑
    rect(c, 2, 7, 12, 6, C.wood);             // 몸통
    rect(c, 2, 12, 12, 1, C.wood2);           // 바닥 그늘
    rect(c, 2, 8, 12, 1, C.wood2);            // 뚜껑 이음매
    rect(c, 4, 5, 1, 8, C.metal);             // 금속 띠 왼쪽
    rect(c, 11, 5, 1, 8, C.metal);            // 금속 띠 오른쪽
    px(c, 4, 6, C.rust); px(c, 4, 10, C.rust2);   // 띠에 슨 녹
    px(c, 11, 7, C.rust); px(c, 11, 11, C.rust2);
    rect(c, 7, 8, 2, 3, C.rust);              // 녹슨 자물쇠
    px(c, 7, 9, C.rust2);
    px(c, 3, 5, C.salt); px(c, 12, 6, C.salt);    // 하얗게 낀 소금기
    px(c, 6, 12, C.salt); px(c, 10, 5, C.salt);
    px(c, 2, 14, C.ice); px(c, 13, 14, C.ice);    // 아직 마르지 않은 물기
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
console.log('낡은 상자 아이콘', n, '장 생성');
