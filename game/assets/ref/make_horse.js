// 탈 것(말) 스프라이트 생성기 — 48x40 도트로 그리고 2배 확대해 96x80으로 저장한다.
// 앞/옆/뒤 각 2프레임(다리 교차). 게임에서는 0.5배로 그려 캐릭터 밑에 깔린다.
//
// 실행:  node make_horse.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const W = 48, H = 40, Z = 2;

const C = {
  line:  [40, 26, 20],
  coat:  [150, 96, 54], coat2: [116, 72, 40], coat3: [92, 56, 30],
  belly: [186, 138, 92],
  mane:  [58, 40, 28],  mane2: [82, 58, 38],
  hoof:  [46, 38, 34],
  tack:  [96, 60, 36],  metal: [206, 176, 96],
  eye:   [24, 18, 16],  white: [244, 242, 236],
};

const canvas = () => Array.from({ length: H }, () => new Array(W).fill(null));
const inb = (x, y) => x >= 0 && y >= 0 && x < W && y < H;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col); }
function ellipse(c, cx, cy, rx, ry, col) {
  for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++)
    if ((x * x) / (rx * rx) + (y * y) / (ry * ry) <= 1.05) px(c, cx + x, cy + y, col);
}
function outline(c) {
  const out = c.map(r => r.slice());
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (c[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]])
      if (inb(x + dx, y + dy) && c[y + dy][x + dx]) near = true;
    if (near) out[y][x] = C.line;
  }
  return out;
}

// 다리 한 짝 — 2px 굵기, step으로 앞뒤로 벌어진다
function leg(c, x, top, len, fwd, col) {
  for (let i = 0; i < len; i++) {
    const off = (fwd ? 1 : -1) * Math.floor(i / 3);
    px(c, x + off, top + i, col);
    px(c, x + off + 1, top + i, col);
  }
  const foff = (fwd ? 1 : -1) * Math.floor(len / 3);
  rect(c, x + foff, top + len, 2, 2, C.hoof);
}

// ---- 옆모습 ----
function side(step) {
  const c = canvas();
  ellipse(c, 21, 18, 13, 6, C.coat);            // 몸통 (가로로 길게)
  ellipse(c, 21, 21, 11, 3, C.belly);           // 배
  rect(c, 29, 9, 5, 9, C.coat);                 // 목 (비스듬히 올라간다)
  rect(c, 31, 7, 5, 5, C.coat);
  ellipse(c, 38, 8, 6, 4, C.coat);              // 머리
  rect(c, 42, 9, 4, 3, C.coat2);                // 주둥이
  px(c, 40, 6, C.eye); px(c, 40, 7, C.eye);
  rect(c, 34, 2, 2, 4, C.coat2); rect(c, 37, 2, 2, 4, C.coat2);   // 귀
  for (let i = 0; i < 11; i++) {                // 갈기 (목을 따라)
    px(c, 29 + Math.floor(i / 2), 4 + i, C.mane);
    px(c, 30 + Math.floor(i / 2), 4 + i, C.mane2);
  }
  for (let i = 0; i < 13; i++) {                // 꼬리
    px(c, 8 - Math.floor(i / 5), 13 + i, C.mane);
    px(c, 9 - Math.floor(i / 5), 13 + i, C.mane2);
  }
  leg(c, 13, 22, 14, step, C.coat2);            // 뒷다리
  leg(c, 18, 22, 14, !step, C.coat3);
  leg(c, 26, 22, 14, !step, C.coat2);           // 앞다리
  leg(c, 30, 22, 14, step, C.coat3);
  rect(c, 16, 12, 10, 3, C.tack);               // 안장
  px(c, 20, 11, C.metal); px(c, 21, 11, C.metal);
  return c;
}

// ---- 앞/뒤 모습 (몸통을 세로로 짧게, 다리 넷) ----
function front(step, back) {
  const c = canvas();
  ellipse(c, 24, 18, 9, 8, C.coat);             // 몸통
  ellipse(c, 24, 21, 7, 5, C.belly);
  if (back) {
    for (let i = 0; i < 12; i++) px(c, 24, 4 + i, C.mane);   // 뒤: 꼬리가 보인다
    for (let i = 0; i < 12; i++) px(c, 25, 4 + i, C.mane2);
    ellipse(c, 24, 9, 5, 4, C.coat2);
  } else {
    ellipse(c, 24, 9, 6, 5, C.coat);            // 앞: 머리
    rect(c, 21, 2, 2, 4, C.coat2); rect(c, 26, 2, 2, 4, C.coat2);  // 귀
    px(c, 21, 8, C.eye); px(c, 27, 8, C.eye);
    ellipse(c, 24, 12, 3, 2, C.coat2);          // 주둥이
    rect(c, 22, 4, 5, 2, C.mane);
  }
  leg(c, 17, 23, 13, step, C.coat2);
  leg(c, 21, 24, 13, !step, C.coat3);
  leg(c, 26, 24, 13, step, C.coat3);
  leg(c, 30, 23, 13, !step, C.coat2);
  rect(c, 19, 13, 11, 3, C.tack);               // 안장
  return c;
}

const SPRITES = {
  horse_side_0: () => side(false), horse_side_1: () => side(true),
  horse_down_0: () => front(false, false), horse_down_1: () => front(true, false),
  horse_up_0: () => front(false, true), horse_up_1: () => front(true, true),
};

let n = 0;
for (const [id, make] of Object.entries(SPRITES)) {
  const c = outline(make());
  const p = new PNG({ width: W * Z, height: H * Z });
  p.data.fill(0);
  for (let y = 0; y < H * Z; y++) for (let x = 0; x < W * Z; x++) {
    const col = c[Math.floor(y / Z)][Math.floor(x / Z)];
    if (!col) continue;
    const i = (y * W * Z + x) * 4;
    p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
  }
  fs.writeFileSync(OUT + id + '.png', PNG.sync.write(p));
  n++;
}
console.log('말 스프라이트', n, '장 생성');
