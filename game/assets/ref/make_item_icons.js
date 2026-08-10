// 아이템 아이콘 생성기 — 16x16 도트로 그리고 2배 확대해 32x32로 저장한다.
// 나중에 직접 그린 그림으로 바꿀 때는 같은 파일 이름(32x32)으로 덮어쓰면 된다.
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = '/home/user/kyojingame/game/assets/sprites/';
const S = 16, Z = 2;

const C = {
  line:  [42, 28, 24],      // 외곽선
  white: [246, 244, 238], cream: [236, 224, 190], shadow: [198, 186, 160],
  gold:  [240, 196, 72],  gold2: [198, 150, 40],
  red:   [206, 74, 62],   red2:  [158, 48, 44],
  pink:  [238, 132, 140],
  orange:[232, 140, 60],  orange2:[186, 100, 40],
  green: [104, 168, 82],  green2:[72, 126, 60],  leaf: [140, 196, 96],
  brown: [150, 100, 58],  brown2:[110, 70, 40],  crust:[196, 150, 88],
  grey:  [140, 140, 152], grey2: [104, 104, 118],
  blue:  [92, 156, 224],  blue2: [58, 108, 176], ice: [190, 232, 246],
  purple:[142, 96, 190],  purple2:[100, 64, 140],
  cyan:  [104, 216, 208],
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
// 불투명한 부분 바깥에 외곽선을 두른다 (도트 느낌)
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
function fish(body, belly, spark) {
  const c = newCanvas();
  ellipse(c, 8, 8, 5, 3, body);              // 몸통
  rect(c, 12, 6, 3, 1, body); rect(c, 13, 7, 2, 3, body); rect(c, 12, 10, 3, 1, body);  // 꼬리
  ellipse(c, 8, 10, 4, 2, belly);            // 배
  px(c, 5, 7, C.white); px(c, 5, 7, C.line);
  px(c, 4, 7, C.white);
  rect(c, 7, 5, 3, 1, belly);                // 등지느러미
  if (spark) { px(c, 11, 4, C.white); px(c, 12, 3, C.white); }
  return c;
}
function bowl(soup, rim) {
  const c = newCanvas();
  ellipse(c, 8, 8, 6, 2, soup);              // 국물
  rect(c, 2, 8, 13, 4, rim); rect(c, 3, 12, 11, 1, rim); rect(c, 5, 13, 7, 1, rim);
  ellipse(c, 8, 8, 5, 2, soup);
  return c;
}
function plate(food, food2) {
  const c = newCanvas();
  rect(c, 2, 11, 13, 2, C.white); rect(c, 4, 13, 9, 1, C.shadow);
  ellipse(c, 8, 8, 4, 3, food);
  if (food2) ellipse(c, 7, 7, 2, 1, food2);
  return c;
}
function jar(content) {
  const c = newCanvas();
  rect(c, 4, 4, 8, 2, C.brown2);             // 뚜껑
  rect(c, 4, 6, 8, 8, C.ice);                // 유리
  rect(c, 5, 8, 6, 5, content);              // 내용물
  px(c, 5, 7, C.white); px(c, 6, 7, C.white);
  return c;
}
function gemShape(col, col2) {
  const c = newCanvas();
  rect(c, 5, 4, 6, 2, col2);
  rect(c, 4, 6, 8, 3, col);
  rect(c, 5, 9, 6, 2, col);
  rect(c, 6, 11, 4, 1, col2);
  rect(c, 7, 12, 2, 1, col2);
  px(c, 6, 6, C.white); px(c, 7, 6, C.white); px(c, 6, 7, C.white);
  return c;
}
function rockShape(base, spot, sparkCol) {
  const c = newCanvas();
  ellipse(c, 8, 9, 6, 4, base);
  rect(c, 4, 5, 7, 2, base);
  ellipse(c, 6, 8, 1, 1, spot); ellipse(c, 10, 10, 1, 1, spot); ellipse(c, 9, 6, 1, 1, spot);
  if (sparkCol) { px(c, 8, 4, sparkCol); px(c, 7, 5, sparkCol); px(c, 9, 5, sparkCol); px(c, 8, 6, sparkCol); }
  return c;
}
function eggShape(col, shade) {
  const c = newCanvas();
  ellipse(c, 8, 9, 4, 5, col);
  ellipse(c, 9, 10, 2, 3, shade);
  px(c, 6, 6, C.white); px(c, 7, 6, C.white);
  return c;
}

// ---- 아이템별 ----
const ICONS = {
  egg: () => eggShape(C.white, C.shadow),
  golden_egg: () => { const c = eggShape(C.gold, C.gold2); px(c, 12, 4, C.white); px(c, 13, 5, C.white); return c; },
  milk: () => {
    const c = newCanvas();
    rect(c, 6, 2, 4, 2, C.blue2);             // 뚜껑
    rect(c, 5, 4, 6, 10, C.white);
    rect(c, 6, 7, 4, 4, C.blue);              // 라벨
    rect(c, 5, 4, 1, 10, C.shadow);
    return c;
  },
  fish_crucian: () => fish(C.grey, C.cream, false),
  fish_carp:    () => fish(C.orange, C.cream, false),
  fish_catfish: () => { const c = fish(C.brown2, C.brown, false); px(c, 3, 8, C.brown); px(c, 2, 9, C.brown); return c; },
  fish_golden:  () => fish(C.gold, C.cream, true),
  ore:      () => rockShape(C.grey, C.brown, null),
  star_ore: () => rockShape(C.grey2, C.blue, C.ice),
  star_shard: () => {   // 별빛 조각 — 대장간 재료 (전설 별빛 광석과 다르다)
    const c = newCanvas();
    for (let y = 3; y <= 12; y++) { const w = 5 - Math.abs(y - 8) * 0.5;
      for (let x = -w; x <= w; x++) px(c, 8 + Math.round(x), y, C.blue); }
    for (let y = 4; y <= 11; y++) px(c, 7, y, C.ice);
    px(c, 8, 3, C.white); px(c, 8, 12, C.white);
    px(c, 11, 5, C.white); px(c, 5, 10, C.white);
    return c;
  },
  gem:      () => gemShape(C.cyan, C.blue2),
  memory_piece: () => gemShape(C.gold, C.gold2),
  ghost_essence: () => { const c = jar(C.ice); px(c, 7, 9, C.white); px(c, 9, 11, C.white); return c; },
  dish_jam: () => jar(C.red),
  dish_baked_potato: () => plate(C.brown, C.crust),
  dish_soup:      () => bowl(C.green, C.white),
  dish_stew:      () => bowl(C.red, C.grey),
  dish_salad:     () => bowl(C.leaf, C.white),
  dish_punch:     () => {
    const c = newCanvas();
    rect(c, 5, 3, 6, 1, C.ice);
    rect(c, 5, 4, 6, 7, C.pink);
    rect(c, 5, 3, 6, 1, C.white);
    rect(c, 6, 11, 4, 2, C.ice); rect(c, 4, 13, 8, 1, C.ice);
    px(c, 6, 5, C.white); px(c, 9, 7, C.white);
    return c;
  },
  dish_cornbread: () => {
    const c = newCanvas();
    ellipse(c, 8, 9, 6, 3, C.crust);
    rect(c, 3, 9, 11, 3, C.gold);
    rect(c, 3, 12, 11, 1, C.crust);
    px(c, 6, 8, C.white); px(c, 10, 8, C.white);
    return c;
  },
  dish_grilled_fish: () => { const c = plate(C.brown, null); const f = fish(C.grey2, C.cream, false);
    for (let y = 0; y < 11; y++) for (let x = 0; x < S; x++) if (f[y][x]) c[y][x] = f[y][x]; return c; },
  dish_pie: () => {
    const c = newCanvas();
    rect(c, 3, 10, 11, 3, C.crust);
    for (let i = 0; i < 5; i++) rect(c, 4 + i * 2, 6 + i, 1, 1, null);
    ellipse(c, 8, 9, 5, 3, C.orange);
    rect(c, 3, 11, 11, 2, C.crust);
    px(c, 6, 7, C.orange2); px(c, 10, 8, C.orange2);
    return c;
  },
  dish_eggplant: () => {
    const c = bowl(C.purple, null);
    px(c, 6, 7, C.purple2); px(c, 9, 7, C.purple2); px(c, 8, 6, C.green);
    return c;
  },
  gold_crop: () => {
    const c = newCanvas();
    rect(c, 7, 8, 2, 6, C.green2);            // 줄기
    ellipse(c, 8, 6, 3, 3, C.ice);            // 달빛 열매
    ellipse(c, 8, 6, 2, 2, C.white);
    rect(c, 4, 10, 3, 1, C.green); rect(c, 9, 11, 3, 1, C.green);
    px(c, 12, 3, C.white); px(c, 13, 4, C.white);
    return c;
  },
  world_branch: () => {
    const c = newCanvas();
    for (let i = 0; i < 10; i++) px(c, 3 + i, 12 - i, C.brown2);
    for (let i = 0; i < 10; i++) px(c, 4 + i, 12 - i, C.brown);
    ellipse(c, 6, 8, 2, 1, C.leaf); ellipse(c, 10, 5, 2, 1, C.green);
    ellipse(c, 8, 8, 1, 2, C.green);
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
console.log('아이콘', n, '장 생성');
