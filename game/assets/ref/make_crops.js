// 다 자란 작물 도트 — 16x16으로 그리고 4배로 키워 64x64로 저장한다.
//
// 먼저 있던 열 종(감자·당근...)과 같은 규격이라 나란히 놓아도 안 튄다.
// 모양은 여섯 가지뿐이고 색만 갈아 끼운다 — 밭에 심겨 있을 때는 32px로
// 줄어 그려지므로, 실루엣이 다르면 그걸로 충분히 구분된다.
//
// 실행:  node make_crops.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 4;

const C = {
  leaf: [104, 176, 84], leaf2: [70, 132, 62], leaf3: [148, 204, 108],
  soil: [110, 74, 46],
  white: [238, 238, 230], cream: [232, 216, 160],
  red: [206, 62, 54], red2: [158, 40, 40],
  orange: [232, 140, 52], gold: [232, 196, 74],
  purple: [140, 88, 176], purple2: [96, 56, 130],
  pale: [206, 226, 178], ice: [214, 234, 244],
  green: [96, 160, 76], darkgreen: [56, 110, 58],
  brown: [150, 100, 58],
};

const blank = () => Array.from({ length: S }, () => new Array(S).fill(null));
const inb = (x, y) => x >= 0 && y >= 0 && x < S && y < S;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col); }
function ellipse(c, cx, cy, rx, ry, col) {
  for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++)
    if ((x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1.05) px(c, cx + x, cy + y, col);
}

// ---- 공용 모양 ----

// 잎 두 장이 V자로 뻗은 윗동 (뿌리채소·열매채소가 공유한다)
function tops(c, col, y0) {
  for (let i = 0; i < 4; i++) { px(c, 6 - i, y0 - i, col); px(c, 9 + i, y0 - i, col); }
  rect(c, 7, y0 - 1, 2, 2, col);
  px(c, 3, y0 - 3, col); px(c, 12, y0 - 3, col);
}

// 뿌리채소 — 잎 밑에 아래로 뾰족해지는 덩이 (당근·무 계열)
function root(body, shade) {
  const c = blank();
  tops(c, C.leaf, 6);
  // 길게 내려가야 뿌리로 보인다 — 짧으면 그냥 세모다
  for (let j = 0; j < 8; j++) {
    const w = 6 - Math.floor(j * 0.7);
    rect(c, 8 - Math.floor(w / 2), 7 + j, w, 1, body);
  }
  rect(c, 8, 8, 1, 5, shade);
  px(c, 8, 15, body);
  return c;
}

// 구근 — 땅 위로 둥근 알이 나와 있고 줄기가 위로 (양파·마늘)
function bulb(body, shade) {
  const c = blank();
  for (let i = 0; i < 5; i++) { px(c, 7, 2 + i, C.leaf); px(c, 9, 1 + i, C.leaf2); }
  ellipse(c, 8, 10, 4, 4, body);
  ellipse(c, 6, 9, 1, 2, shade);
  px(c, 8, 6, body);
  return c;
}

// 매달린 열매 둘 (가지·고추 계열)
function hanging(body, shade) {
  const c = blank();
  tops(c, C.leaf, 5);
  for (const x of [5, 10]) {
    rect(c, x, 6, 2, 6, body);
    px(c, x + (x === 5 ? 0 : 1), 8, shade);
    px(c, x, 12, body); px(c, x + 1, 12, body);
  }
  return c;
}

// 덩굴에 달린 깍지 (완두·콩)
function pod(body, dot) {
  const c = blank();
  for (let i = 0; i < 10; i++) px(c, 8, 4 + i, C.leaf2);
  // 깍지는 크게. 작게 흩어 놓으면 16px에서는 점으로만 보인다
  for (const [x, y] of [[4, 7], [11, 9], [5, 12]]) {
    ellipse(c, x, y, 3, 2, body);
    px(c, x - 1, y, dot); px(c, x + 1, y, dot);
  }
  px(c, 6, 4, C.leaf); px(c, 10, 5, C.leaf); px(c, 6, 11, C.leaf);
  return c;
}

// 커다란 공 (호박·수박·참외 계열)
function ball(body, spot) {
  const c = blank();
  ellipse(c, 8, 9, 6, 5, body);
  if (spot) for (const [x, y] of [[5, 7], [10, 8], [7, 11], [11, 11]]) px(c, x, y, spot);
  px(c, 8, 3, C.leaf2); px(c, 9, 2, C.leaf);
  return c;
}

// 잎만 무성한 것 (시금치·약초)
function bush(col, col2) {
  const c = blank();
  for (const [x, y, r] of [[5, 9, 3], [11, 9, 3], [8, 7, 4]]) ellipse(c, x, y, r, r - 1, col);
  for (const [x, y] of [[5, 8], [11, 8], [8, 6]]) px(c, x, y, col2);
  rect(c, 7, 11, 2, 3, C.leaf2);
  return c;
}

// 이삭이 고개를 숙인 것 (벼)
function grain(body) {
  const c = blank();
  // 줄기 두 대 + 고개 숙인 이삭. 한 줄만 그으면 실이 된다
  for (let i = 0; i < 11; i++) { px(c, 5, 15 - i, C.leaf2); px(c, 6, 15 - i, C.leaf); }
  for (let i = 0; i < 9; i++) {
    const y = 3 + Math.floor(i * 0.8);
    for (let t = 0; t < 3; t++) px(c, 6 + i, y + t, body);
    px(c, 6 + i, y + 3, C.cream);
    if (i % 2 === 0) { px(c, 5 + i, y - 1, C.cream); px(c, 7 + i, y + 4, C.cream); }
  }
  px(c, 3, 9, C.leaf); px(c, 8, 13, C.leaf); px(c, 2, 12, C.leaf2);
  return c;
}

// 길쭉한 흰 줄기 + 초록 잎 (대파)
function stalk(body, tip) {
  const c = blank();
  rect(c, 7, 8, 3, 7, body);
  px(c, 7, 8, C.white);
  for (let i = 0; i < 6; i++) { px(c, 6 - Math.floor(i / 3), 7 - i, tip); px(c, 10 + Math.floor(i / 3), 7 - i, tip); }
  rect(c, 7, 2, 3, 6, tip);
  return c;
}

// 잎이 겹겹이 싸인 공 (배추 계열)
function head(body, vein) {
  const c = blank();
  ellipse(c, 8, 9, 6, 5, body);
  ellipse(c, 8, 9, 4, 3, vein);
  for (const [x, y] of [[8, 5], [5, 9], [11, 9]]) px(c, x, y, vein);
  px(c, 8, 3, C.leaf2);
  return c;
}

// ---- 작물별 ----
const CROPS = {
  spinach: () => bush(C.leaf, C.leaf3),
  herb_leaf: () => { const c = bush(C.green, C.leaf3);
    for (const [x, y] of [[5, 7], [11, 7], [8, 5]]) px(c, x, y, C.white); return c; },
  onion: () => bulb(C.cream, C.brown),
  garlic: () => bulb(C.white, C.pale),
  pea: () => pod(C.leaf3, C.leaf2),
  bean: () => pod(C.cream, C.brown),
  pepper: () => hanging(C.red, C.red2),
  melon: () => ball(C.gold, C.cream),
  sweet_potato: () => root(C.purple, C.purple2),
  beet: () => root(C.red2, C.purple2),
  leek: () => stalk(C.white, C.leaf),
  rice: () => grain(C.gold),
  wheat: () => grain(C.cream),   // 밀 — 벼보다 옅은 밀짚색 이삭
  snow_cabbage: () => head(C.ice, C.pale),
};

let n = 0;
for (const [id, make] of Object.entries(CROPS)) {
  const c = make();
  const p = new PNG({ width: S * Z, height: S * Z });
  p.data.fill(0);
  for (let y = 0; y < S * Z; y++) for (let x = 0; x < S * Z; x++) {
    const col = c[Math.floor(y / Z)][Math.floor(x / Z)];
    if (!col) continue;
    const i = (y * S * Z + x) * 4;
    p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
  }
  fs.writeFileSync(OUT + 'mature_' + id + '.png', PNG.sync.write(p));
  n++;
}
console.log('작물 %d 장 생성', n);
