// 대장간 장비 아이콘 생성기 — 16x16 도트로 그리고 2배 확대해 32x32로 저장한다.
// 무기 3 · 방어구 3 · 장신구 3. 같은 이름(32x32)으로 덮어쓰면 직접 그린 그림으로 바뀐다.
//
// 실행:  node make_gear_icons.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 2;

const C = {
  line:   [42, 28, 24],
  white:  [246, 244, 238], cream: [236, 224, 190],
  gold:   [240, 196, 72],  gold2: [198, 150, 40],
  wood:   [162, 116, 68],  wood2: [116, 80, 46],
  iron:   [176, 180, 192], iron2: [120, 126, 140], iron3: [86, 92, 106],
  star:   [176, 208, 250], star2: [120, 156, 214], glow: [238, 246, 255],
  leather:[168, 116, 66],  leather2:[126, 84, 46],
  green:  [104, 168, 82],  green2:[72, 126, 60],
  red:    [206, 74, 62],   ember: [244, 148, 60],
  cyan:   [136, 224, 216], cyan2: [86, 172, 176],
  purple: [142, 96, 190],
};

function newCanvas() { return Array.from({ length: S }, () => new Array(S).fill(null)); }
const inb = (x, y) => x >= 0 && y >= 0 && x < S && y < S;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col); }
function disc(c, cx, cy, r, col) {
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++)
    if (x * x + y * y <= r * r + r * 0.4) px(c, cx + x, cy + y, col);
}
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

// ---- 공용 모양 ----
// 오른쪽 위를 향한 검: 날 + 코등이 + 손잡이
function sword(blade, blade2, guard, spark) {
  const c = newCanvas();
  for (let i = 0; i < 9; i++) { px(c, 4 + i, 11 - i, blade2); px(c, 5 + i, 11 - i, blade); }
  px(c, 13, 2, blade); px(c, 12, 2, blade);          // 칼끝
  rect(c, 3, 10, 4, 1, guard); rect(c, 4, 9, 1, 3, guard);   // 코등이
  for (let i = 0; i < 3; i++) px(c, 3 - i, 12 + i, C.wood2); // 손잡이
  for (let i = 0; i < 3; i++) px(c, 2 - i, 12 + i, C.wood);
  px(c, 0, 15, C.gold2);
  if (spark) { px(c, 14, 1, C.glow); px(c, 11, 4, C.glow); px(c, 8, 7, C.glow); }
  return c;
}
// 조끼/갑옷: 어깨 + 몸통
function armor(body, body2, trim, spark) {
  const c = newCanvas();
  rect(c, 4, 4, 8, 2, body2);                 // 어깨
  rect(c, 3, 5, 2, 3, body2); rect(c, 11, 5, 2, 3, body2);
  rect(c, 4, 6, 8, 7, body);                  // 몸통
  rect(c, 5, 13, 6, 1, body2);
  rect(c, 7, 6, 2, 7, trim);                  // 가운데 여밈
  px(c, 6, 5, C.line); px(c, 9, 5, C.line);   // 목선
  if (spark) { px(c, 5, 8, C.glow); px(c, 10, 10, C.glow); }
  return c;
}
// 목걸이형 장신구: 줄 + 알
function charm(core, core2, extra) {
  const c = newCanvas();
  for (let i = 0; i < 5; i++) { px(c, 4 + i, 3 + i, C.gold2); px(c, 12 - i, 3 + i, C.gold2); }
  disc(c, 8, 10, 3, core2);
  disc(c, 8, 10, 2, core);
  px(c, 7, 9, C.white);
  if (extra) extra(c);
  return c;
}

const ICONS = {
  // ---- 무기 ----
  gear_sword_wood: () => sword(C.wood, C.wood2, C.gold2, false),
  gear_sword_iron: () => sword(C.iron, C.iron2, C.gold, false),
  gear_sword_star: () => sword(C.star, C.star2, C.gold, true),
  // ---- 방어구 ----
  gear_vest_leather: () => armor(C.leather, C.leather2, C.wood2, false),
  gear_vest_iron: () => armor(C.iron, C.iron3, C.iron2, false),
  gear_vest_star: () => armor(C.star, C.star2, C.glow, true),
  // ---- 장신구 ----
  gear_charm_clover: () => charm(C.green, C.green2, (c) => {
    px(c, 8, 9, C.white); px(c, 7, 10, C.white);
  }),
  gear_charm_ember: () => charm(C.ember, C.red, (c) => {
    px(c, 8, 8, C.gold); px(c, 8, 9, C.white);
  }),
  gear_charm_wind: () => charm(C.cyan, C.cyan2, (c) => {
    rect(c, 3, 12, 3, 1, C.white); rect(c, 11, 9, 3, 1, C.white);
  }),
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
console.log('장비 아이콘', n, '장 생성');
