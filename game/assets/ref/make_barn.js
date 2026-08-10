// 축사 스프라이트 생성기 — 224x176 도트로 그리고 2배 확대해 448x352로 저장한다.
// 게임에서는 0.5배로 그려 7 x 5.5칸(224 x 176 월드픽셀)을 차지한다.
// (예전 축사는 128x96짜리라 주인공보다 조금 큰 정도였다)
//
// 정면에서 본 감브렐(꺾인) 지붕 헛간. 위에서 아래로:
//   지붕 처마 -> 다락문 -> 벽(널판) -> 큰 두짝문 -> 주춧돌
//
// 실행:  node make_barn.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const W = 224, H = 176, Z = 2;
const CX = 112;                       // 좌우 대칭 기준

const C = {
  line:   [38, 20, 18],
  wall:   [176, 58, 48], wall2: [152, 46, 38], wall3: [198, 76, 62],
  roof:   [88, 42, 38], roof2: [114, 56, 50],
  trim:   [238, 232, 216], trim2: [204, 196, 180],
  door:   [98, 64, 42], door2: [78, 50, 32], door3: [120, 82, 54],
  glass:  [152, 198, 216], glass2: [108, 158, 186],
  stone:  [124, 120, 116], stone2: [100, 96, 92],
  metal:  [206, 176, 96],
};

const canvas = () => Array.from({ length: H }, () => new Array(W).fill(null));
const inb = (x, y) => x >= 0 && y >= 0 && x < W && y < H;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col);
}
function frame(c, x, y, w, h, t, col) {   // 테두리만
  rect(c, x, y, w, t, col); rect(c, x, y + h - t, w, t, col);
  rect(c, x, y, t, h, col); rect(c, x + w - t, y, t, h, col);
}

// 감브렐 실루엣: y줄마다 중심에서 좌우로 몇 칸까지 건물인지
function halfWidth(y) {
  if (y < 4) return -1;
  if (y < 40) return 26 + ((86 - 26) * (y - 4)) / 36;    // 위쪽 완만한 지붕면
  if (y < 68) return 86 + ((104 - 86) * (y - 40)) / 28;  // 아래쪽 가파른 지붕면
  return 104;                                            // 수직 벽
}

// 세로 널판 무늬 (8칸마다 한 줄 어둡게)
function plank(x, y) {
  const m = ((x % 8) + 8) % 8;
  if (m === 0) return C.wall2;
  if (m === 1) return C.wall3;
  return C.wall;
}

function barn() {
  const c = canvas();

  // ---- 몸통 + 지붕면을 실루엣대로 채운다 ----
  for (let y = 4; y < H; y++) {
    const hw = Math.round(halfWidth(y));
    if (hw < 0) continue;
    for (let x = CX - hw; x <= CX + hw; x++) {
      const onRoof = y < 68;
      const edge = Math.min(x - (CX - hw), (CX + hw) - x);
      if (onRoof && edge < 12) px(c, x, y, edge < 4 ? C.trim : C.roof);
      else if (onRoof && edge < 16) px(c, x, y, C.roof2);
      else px(c, x, y, plank(x, y));
    }
  }

  // ---- 처마 (지붕과 벽이 만나는 곳의 가로 띠) ----
  rect(c, CX - 108, 64, 216, 4, C.roof);
  rect(c, CX - 108, 68, 216, 4, C.trim);

  // ---- 다락문 + 도르래 들보 ----
  rect(c, CX - 8, 20, 16, 4, C.door2);        // 들보
  rect(c, CX - 3, 24, 6, 6, C.door);
  px(c, CX, 30, C.metal); px(c, CX - 1, 30, C.metal);
  frame(c, CX - 18, 32, 36, 30, 3, C.trim);
  rect(c, CX - 15, 35, 30, 24, C.door);
  for (let x = CX - 15; x < CX + 15; x += 5) rect(c, x, 35, 1, 24, C.door2);
  rect(c, CX - 15, 45, 30, 2, C.door3);       // 가로 띠장

  // ---- 벽 모서리 흰 기둥 ----
  rect(c, CX - 104, 72, 10, 104, C.trim);
  rect(c, CX + 94, 72, 10, 104, C.trim);
  rect(c, CX - 94, 72, 2, 104, C.trim2);
  rect(c, CX + 92, 72, 2, 104, C.trim2);

  // ---- 창문 두 짝 ----
  for (const wx of [CX - 78, CX + 50]) {
    frame(c, wx, 88, 28, 28, 4, C.trim);
    rect(c, wx + 4, 92, 20, 20, C.glass);
    rect(c, wx + 4, 102, 20, 10, C.glass2);   // 아래쪽은 그늘
    rect(c, wx + 13, 92, 2, 20, C.trim2);     // 창살
    rect(c, wx + 4, 101, 20, 2, C.trim2);
  }

  // ---- 큰 두짝문 ----
  const dx = CX - 38, dw = 76, dy = 100, dh = 66;
  frame(c, dx - 5, dy - 5, dw + 10, dh + 5, 5, C.trim);
  rect(c, dx, dy, dw, dh, C.door);
  for (let x = dx; x < dx + dw; x += 6) rect(c, x, dy, 1, dh, C.door2);
  // 문짝마다 흰 X 버팀대
  for (const side of [0, 1]) {
    const ox = dx + side * (dw / 2), ow = dw / 2;
    for (let i = 0; i < dh; i++) {
      const t = i / dh;
      rect(c, Math.round(ox + t * (ow - 4)), dy + i, 4, 1, C.trim2);
      rect(c, Math.round(ox + (1 - t) * (ow - 4)), dy + i, 4, 1, C.trim2);
    }
    rect(c, ox, dy, ow, 4, C.trim2);
    rect(c, ox, dy + dh - 4, ow, 4, C.trim2);
  }
  rect(c, CX - 1, dy, 2, dh, C.door2);        // 가운데 틈
  rect(c, CX - 12, dy + 30, 8, 4, C.metal);   // 손잡이
  rect(c, CX + 4, dy + 30, 8, 4, C.metal);

  // ---- 주춧돌 ----
  for (let y = 166; y < H; y++)
    for (let x = CX - 104; x <= CX + 104; x++)
      px(c, x, y, ((x >> 3) + (y >> 2)) % 2 === 0 ? C.stone : C.stone2);

  return c;
}

function outline(c) {
  const out = c.map(r => r.slice());
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (c[y][x]) continue;
    let near = false;
    for (const [ax, ay] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (inb(x + ax, y + ay) && c[y + ay][x + ax]) near = true;
    if (near) out[y][x] = C.line;
  }
  return out;
}

const c = outline(barn());
const p = new PNG({ width: W * Z, height: H * Z });
p.data.fill(0);
for (let y = 0; y < H * Z; y++) for (let x = 0; x < W * Z; x++) {
  const col = c[Math.floor(y / Z)][Math.floor(x / Z)];
  if (!col) continue;
  const i = (y * W * Z + x) * 4;
  p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
}
fs.writeFileSync(OUT + 'barn.png', PNG.sync.write(p));
console.log('축사 스프라이트 생성:', W * Z, 'x', H * Z);
