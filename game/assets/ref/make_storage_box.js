// 수납 상자 아이콘 1장 (용식의 집터 부탁 보상) — make_old_box.js 와 같은 방식.
//   storage_box  목재 8개로 짜는 작은 보관함 (튼튼한 나무 궤, 쇠 걸쇠)
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_storage_box.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 2;

const C = {
  line:  [42, 28, 24],
  wood:  [146, 106, 62], wood2: [112, 80, 46], wood3: [176, 134, 84],
  metal: [128, 122, 116], metal2: [92, 88, 84], shine: [236, 226, 200],
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

const c = newCanvas();
rect(c, 2, 4, 12, 3, C.wood3);        // 뚜껑
rect(c, 2, 6, 12, 1, C.wood2);        // 뚜껑 이음매
rect(c, 2, 7, 12, 6, C.wood);         // 몸통
rect(c, 2, 12, 12, 1, C.wood2);       // 바닥 그늘
rect(c, 5, 7, 1, 6, C.wood2);         // 널판 결
rect(c, 10, 7, 1, 6, C.wood2);
rect(c, 3, 4, 1, 9, C.metal);         // 쇠 띠 왼쪽
rect(c, 12, 4, 1, 9, C.metal);        // 쇠 띠 오른쪽
px(c, 3, 8, C.metal2); px(c, 12, 10, C.metal2);
rect(c, 7, 6, 2, 3, C.metal);         // 앞면 걸쇠
px(c, 7, 7, C.metal2);
px(c, 4, 4, C.shine); px(c, 9, 4, C.shine);   // 뚜껑에 드는 빛
px(c, 6, 10, C.wood3);

const p = new PNG({ width: S * Z, height: S * Z });
p.data.fill(0);
const out = outline(c);
for (let y = 0; y < S * Z; y++) for (let x = 0; x < S * Z; x++) {
  const col = out[Math.floor(y / Z)][Math.floor(x / Z)];
  if (!col) continue;
  const i = (y * S * Z + x) * 4;
  p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
}
fs.writeFileSync(OUT + 'storage_box.png', PNG.sync.write(p));
console.log('수납 상자 아이콘 1장 생성');
