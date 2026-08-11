// 건물 스프라이트 생성기 — 640x512 (게임에서는 0.4배로 그려 8 x 6.4칸을 덮는다).
//
// 예전 집은 「사각형 벽 + 삼각형 지붕」이라 종이를 오려 세운 것처럼 보였다.
// 참고 도트의 마을집을 따라 3/4로 세운다. 깊이는 벡터 하나(D)로 만든다:
// 앞면에서 D만큼 밀면 뒷면이 되고, 그 사이를 채우면 옆벽과 지붕면이 나온다.
//
//        A(용마루 앞)---- A+D (용마루 뒤)
//        /   \               \
//       /     \  지붕면        \
//   앞 박공     E ------------- E+D
//      |  앞면  |    옆벽       |
//
// 여기에 깊이가 읽히는 것들을 얹는다:
//   처마 그늘 · 2층이 앞으로 나온 턱(제티)과 그 밑 그늘 · 창틀 그림자 ·
//   문이 안으로 들어간 어둠 · 옆면 전체를 한 톤 어둡게 · 바닥 그림자
//
// 실행:  node make_house.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const W = 640, H = 512;

// ---- 뼈대 좌표 ----
const FX0 = 145, FX1 = 495;      // 앞면 좌우
const FY0 = 250, FY1 = 494;      // 앞면 위(=박공 밑변) / 땅
const MID = 352;                 // 1층과 2층 경계
const JUT = 13;                  // 2층이 앞으로 나온 폭
const DX = 86, DY = -34;         // 깊이 벡터 (뒤로 갈수록 오른쪽 위)
const AX = 320, AY = 88;         // 용마루 앞끝
const EAVE = 34;                 // 처마가 벽 밖으로 나온 길이

const img = Array.from({ length: H }, () => new Array(W).fill(null));
const inb = (x, y) => x >= 0 && y >= 0 && x < W && y < H;
function px(x, y, c) { x = Math.round(x); y = Math.round(y); if (inb(x, y) && c) img[y][x] = c; }
function rect(x, y, w, h, c) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(x + i, y + j, c);
}
function hline(x0, x1, y, c) { for (let x = Math.round(x0); x <= x1; x++) px(x, y, c); }
function vline(x, y0, y1, c) { for (let y = Math.round(y0); y <= y1; y++) px(x, y, c); }
function disc(cx, cy, r, c) {
  for (let y = Math.floor(cy - r); y <= cy + r; y++)
    for (let x = Math.floor(cx - r); x <= cx + r; x++) {
      const dx = x - cx, dy = y - cy;
      if (dx * dx + dy * dy <= r * r) px(x, y, c);
    }
}
function sh(c, k) {
  return [Math.max(0, Math.min(255, c[0] + k)), Math.max(0, Math.min(255, c[1] + k)),
    Math.max(0, Math.min(255, c[2] + k))];
}
function mul(c, k) {
  return [Math.max(0, Math.min(255, Math.round(c[0] * k))),
    Math.max(0, Math.min(255, Math.round(c[1] * k))),
    Math.max(0, Math.min(255, Math.round(c[2] * k)))];
}
function h2(x, y, seed) {
  let n = (Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263)
    ^ Math.imul(seed | 0, 362437)) >>> 0;
  n = Math.imul(n ^ (n >>> 13), 1274126177) >>> 0;
  return ((n ^ (n >>> 16)) >>> 0) / 4294967295;
}

// 네 점으로 둘러싸인 면을 (u,v)로 훑어 칠한다. 옆벽·지붕면처럼 기울어진 면도
// 같은 함수로 그릴 수 있다. fn(u, v, 가로길이, 세로길이) -> 색
function quad(p0, p1, p2, p3, fn) {
  const span = Math.max(
    Math.hypot(p1[0] - p0[0], p1[1] - p0[1]), Math.hypot(p2[0] - p3[0], p2[1] - p3[1]));
  const depth = Math.max(
    Math.hypot(p3[0] - p0[0], p3[1] - p0[1]), Math.hypot(p2[0] - p1[0], p2[1] - p1[1]));
  const nu = Math.ceil(span * 2), nv = Math.ceil(depth * 2);
  for (let j = 0; j <= nv; j++) {
    const v = j / nv;
    for (let i = 0; i <= nu; i++) {
      const u = i / nu;
      const x = (p0[0] * (1 - u) + p1[0] * u) * (1 - v) + (p3[0] * (1 - u) + p2[0] * u) * v;
      const y = (p0[1] * (1 - u) + p1[1] * u) * (1 - v) + (p3[1] * (1 - u) + p2[1] * u) * v;
      px(x, y, fn(u, v, span, depth));
    }
  }
}
// 세 점 삼각형 (박공용) — 위 두 점을 붙여 사각형으로 쓴다
function tri(a, b, c, fn) { quad(a, a, b, c, fn); }

// ================= 팔레트 =================
const P = {
  plaster: [231, 220, 194], plasterHi: [244, 236, 214], plasterLo: [204, 191, 164],
  beam: [104, 68, 40], beamHi: [136, 96, 60], beamLo: [72, 46, 26],
  stone: [156, 148, 136], stoneHi: [188, 182, 170], stoneLo: [108, 102, 94],
  door: [116, 74, 40], doorHi: [148, 100, 58], doorLo: [72, 44, 22],
  glass: [126, 176, 206], glassHi: [186, 218, 236], glassLit: [250, 216, 128],
  brick: [150, 84, 62], brickLo: [110, 58, 42], brickHi: [178, 108, 82],
  shadow: [0, 0, 0],
  leaf: [64, 122, 58], leafHi: [96, 158, 78], flower: [214, 88, 92],
};

// 지붕 색은 건물마다 바꾼다
function roofSet(base) {
  return { mid: base, hi: sh(base, 34), lo: sh(base, -38), edge: sh(base, -62) };
}

// ---- 회벽 무늬 (거친 미장) ----
function plasterAt(lx, ly, seed, dim) {
  let c = P.plaster;
  const r = h2(lx >> 1, ly >> 1, seed);
  if (r > 0.80) c = P.plasterHi;
  else if (r > 0.62) c = P.plasterLo;
  return dim ? mul(c, dim) : c;
}

// ================= 한 채 그리기 =================
function build(opt) {
  for (let y = 0; y < H; y++) img[y].fill(null);
  const R = roofSet(opt.roof);
  const D = [DX, DY];
  const add = (p, q) => [p[0] + q[0], p[1] + q[1]];

  // ---- 0. 바닥 그림자 (건물이 땅에 붙어 보이게) ----
  for (let y = FY1 - 8; y < FY1 + 16; y++)
    for (let x = FX0 - 30; x < FX1 + DX + 30; x++) {
      const cx = (FX0 + FX1 + DX) / 2, cy = FY1 + 4;
      const dx = (x - cx) / ((FX1 - FX0 + DX) / 2 + 26), dy = (y - cy) / 13;
      if (dx * dx + dy * dy <= 1) px(x, y, [26, 30, 24]);
    }

  // ---- 1. 옆벽 (뒤로 물러난다 — 앞면보다 어둡게 해서 모서리를 세운다) ----
  quad([FX1, FY0], add([FX1, FY0], D), add([FX1, FY1], D), [FX1, FY1],
    (u, v, sp, dp) => {
      const lx = Math.round(u * sp), ly = Math.round(v * dp);
      // 뒤로 갈수록 조금 더 어둡게 (공기 원근)
      let c = plasterAt(lx + 300, ly, 21, 0.74 - u * 0.06);
      // 기둥 두 개
      if (lx < 5 || lx > sp - 6 || Math.abs(lx - sp * 0.5) < 4) c = mul(P.beam, 0.74);
      // 1층/2층 띠
      const gy = (MID - FY0) / (FY1 - FY0);
      if (Math.abs(v - gy) < 0.022) c = mul(P.beam, 0.7);
      if (v > 0.93) c = mul(P.stone, 0.72);
      return c;
    });
  // 앞면과 옆면이 만나는 모서리
  for (let y = FY0; y <= FY1; y++) px(FX1, y, mul(P.beam, 0.62));

  // ---- 2. 앞면 1층 ----
  quad([FX0, MID], [FX1, MID], [FX1, FY1], [FX0, FY1], (u, v, sp, dp) => {
    const lx = Math.round(u * sp), ly = Math.round(v * dp);
    let c = plasterAt(lx, ly + 200, 31, 1);
    if (lx < 6 || lx > sp - 7) c = P.beam;                 // 모서리 기둥
    if (ly < 5) c = P.beamLo;                              // 2층 밑 그늘
    else if (ly < 9) c = P.beam;
    // 가운데 기둥 두 개 (문 양옆)
    if (Math.abs(lx - 108) < 5 || Math.abs(lx - (sp - 108)) < 5) c = P.beam;
    return c;
  });
  // 2층이 앞으로 나온 턱: 그 밑에 그늘이 져야 「나왔다」로 보인다.
  // 이미 그려 둔 벽을 어둡게 눌러야 한다 — 검게 덮으면 벽 밖으로 검은 조각이 삐져나온다.
  for (let x = FX0; x <= FX1; x++)
    for (let k = 2; k < 12; k++) {
      const t = (k - 2) / 10;
      if (img[MID + k][x]) px(x, MID + k, mul(img[MID + k][x], 0.26 + t * 0.70));
    }
  // 턱 밑판 (여기가 곧 「나온 두께」다)
  for (let x = FX0 - JUT; x <= FX1 + JUT; x++) {
    px(x, MID, sh(P.beamLo, -12));
    px(x, MID + 1, P.beamLo);
  }
  for (const side of [-1, 1]) {
    const x0 = side < 0 ? FX0 - JUT : FX1 + 1;
    for (let i = 0; i < JUT; i++)
      for (let k = 2; k < 12 - Math.floor(i * 0.5); k++)
        px(x0 + i, MID + k, mul(P.beamLo, 0.72));
  }
  // 턱 받침 (까치발)
  for (let bx = FX0 + 12; bx < FX1; bx += 74) {
    for (let k = 0; k < 12; k++) {
      const w = 11 - k;
      rect(bx, MID + 1 + k, w, 1, k < 3 ? P.beamHi : P.beam);
    }
  }

  // ---- 3. 앞면 2층 (앞으로 JUT만큼 나와 있다) ----
  quad([FX0 - JUT, FY0], [FX1 + JUT, FY0], [FX1 + JUT, MID], [FX0 - JUT, MID],
    (u, v, sp, dp) => {
      const lx = Math.round(u * sp), ly = Math.round(v * dp);
      let c = plasterAt(lx, ly, 41, 1);
      if (lx < 7 || lx > sp - 8) c = P.beam;
      if (ly < 6 || ly > dp - 7) c = P.beam;
      // 기둥 + 빗댄 가새 (반목조의 얼굴)
      const cell = (sp - 14) / 4;
      for (let i = 1; i < 4; i++) if (Math.abs(lx - (7 + cell * i)) < 5) c = P.beam;
      const seg = Math.floor((lx - 7) / cell);
      const t = ((lx - 7) - seg * cell) / cell, tv = (ly - 6) / (dp - 13);
      if (seg === 0 || seg === 3) {
        const want = seg === 0 ? tv : 1 - tv;
        if (Math.abs(t - want) < 0.055) c = P.beam;
      }
      return c;
    });
  // 2층 아래·위 테두리 밝게 (나무결)
  for (let x = FX0 - JUT; x <= FX1 + JUT; x++) px(x, FY0 + 1, P.beamHi);

  // ---- 4. 주춧돌 ----
  quad([FX0, FY1 - 26], [FX1, FY1 - 26], [FX1, FY1], [FX0, FY1], (u, v, sp, dp) => {
    const lx = Math.round(u * sp), ly = Math.round(v * dp);
    // 둥근 돌: 격자에 흔들어 뿌린 씨앗으로 나눈다
    const cw = 34, ch = 13;
    const gx = Math.floor(lx / cw), gy = Math.floor(ly / ch);
    const ox = (h2(gx, gy, 51) - 0.5) * 10, oy = (h2(gx, gy, 52) - 0.5) * 4;
    const cx = gx * cw + cw / 2 + ox, cy = gy * ch + ch / 2 + oy;
    const d = Math.hypot((lx - cx) / (cw * 0.46), (ly - cy) / (ch * 0.46));
    if (d > 1) return P.stoneLo;
    const tone = h2(gx, gy, 53) > 0.5 ? P.stone : sh(P.stone, -14);
    if (ly - cy < -ch * 0.16) return sh(tone, 26);
    if (ly - cy > ch * 0.18) return sh(tone, -22);
    return tone;
  });

  // ---- 5. 지붕 ----
  const A = [AX, AY];                       // 용마루 앞끝
  const EL = [FX0 - EAVE, FY0 + 14];        // 왼쪽 처마 끝
  const ER = [FX1 + EAVE, FY0 + 14];        // 오른쪽 처마 끝
  // 5-1. 오른쪽 지붕면 (뒤로 물러나며 내려간다) — 여기서 입체가 읽힌다
  quad(A, add(A, D), add(ER, D), ER, (u, v) => {
    // 처마 쪽(v=1)으로 갈수록 기와 골이 굵어진다
    const course = Math.floor(v * 11);
    const inC = v * 11 - course;
    let c = course % 2 === 0 ? R.mid : sh(R.mid, -10);
    if (inC < 0.16) c = R.hi;                        // 기와 윗면 볕
    else if (inC > 0.80) c = R.lo;                   // 기와 아래 그늘
    // 세로 골
    const rib = (u * 26) % 1;
    if (rib < 0.10) c = sh(c, -22);
    else if (rib > 0.88) c = sh(c, 12);
    if (h2(u * 900, v * 900, 61) > 0.90) c = sh(c, -12);
    return mul(c, 0.90 + v * 0.10);
  });
  // 5-2. 앞 박공 벽 (삼각형) — 회벽 + 기둥 + 다락창
  tri(A, [FX1 + JUT, FY0], [FX0 - JUT, FY0], (u, v, sp, dp) => {
    const lx = Math.round(u * sp), ly = Math.round(v * dp);
    let c = plasterAt(lx + 90, ly + 60, 71, 1);
    if (Math.abs(lx - sp * 0.5) < 5) c = P.beam;     // 가운데 기둥
    if (ly > dp - 7) c = P.beam;                     // 밑변 보
    // 양쪽 빗기둥
    if (Math.abs(u - 0.28) < 0.028 || Math.abs(u - 0.72) < 0.028) c = P.beam;
    return c;
  });
  // 다락창
  const atticY = FY0 - 66;
  rect(AX - 22, atticY, 44, 40, P.beamLo);
  rect(AX - 18, atticY + 4, 36, 32, P.glass);
  rect(AX - 18, atticY + 4, 36, 9, P.glassHi);
  vline(AX, atticY + 4, atticY + 35, P.beamLo);
  hline(AX - 18, AX + 17, atticY + 19, P.beamLo);
  rect(AX - 26, atticY + 36, 56, 5, P.beamHi);
  // 5-3. 앞 박공 처마 (두 빗변을 따라 기와 테두리 — 두께가 있어야 판자로 안 보인다)
  function bargeboard(from, to) {
    const n = Math.hypot(to[0] - from[0], to[1] - from[1]);
    const nx = (to[1] - from[1]) / n, ny = -(to[0] - from[0]) / n;   // 바깥 법선
    for (let i = 0; i <= n * 2; i++) {
      const t = i / (n * 2);
      const bx = from[0] + (to[0] - from[0]) * t, by = from[1] + (to[1] - from[1]) * t;
      for (let k = -20; k <= 4; k++) {
        const c = k < -17 ? R.edge : (k < -13 ? R.hi : (k < -4 ? R.mid : R.lo));
        px(bx + nx * k, by + ny * k, c);
      }
      // 기와 끝 물결
      if (i % 9 < 5) px(bx + nx * -21, by + ny * -21, R.edge);
    }
  }
  bargeboard(EL, A);
  bargeboard(A, ER);
  // 용마루
  for (let k = 0; k <= 1; k++) {
    const p = add(A, [D[0] * k, D[1] * k]);
    void p;
  }
  {
    const n = Math.hypot(DX, DY);
    for (let i = 0; i <= n * 2; i++) {
      const t = i / (n * 2);
      const rx = A[0] + DX * t, ry = A[1] + DY * t;
      for (let k = -9; k <= 3; k++) px(rx, ry + k, k < -5 ? R.hi : (k < 0 ? R.mid : R.lo));
    }
  }
  // 처마 밑 그늘 (앞면 벽 위쪽) — 지붕이 「덮고 있다」로 읽힌다
  for (let x = FX0 - JUT; x <= FX1 + JUT; x++)
    for (let k = 0; k < 9; k++)
      px(x, FY0 + 2 + k, mul(img[FY0 + 2 + k][x] || P.plaster, 0.55 + k * 0.05));

  // ---- 6. 굴뚝 (지붕면 위에 선다) ----
  {
    const bx = 470, by = 196, w = 44, h = 96;
    rect(bx, by - h, w, h, P.brick);
    for (let y = by - h; y < by; y += 9) hline(bx, bx + w - 1, y, P.brickLo);
    for (let y = by - h; y < by; y++)
      for (let x = bx; x < bx + w; x++)
        if (h2(x, y, 81) > 0.80) px(x, y, P.brickHi);
    vline(bx, by - h, by, P.brickHi);
    vline(bx + w - 1, by - h, by, P.brickLo);
    rect(bx - 5, by - h - 10, w + 10, 10, P.stone);
    rect(bx - 5, by - h - 10, w + 10, 3, P.stoneHi);
    rect(bx + 6, by - h - 16, 14, 6, [40, 36, 34]);
    rect(bx + 26, by - h - 16, 12, 6, [40, 36, 34]);
  }

  // ---- 7. 창문 ----
  // 덧문 + 창틀 + 유리 + 창턱. 창턱 아래 그림자를 넣어야 벽에서 떨어져 보인다.
  function window_(cx, cy, w, h, lit, box) {
    rect(cx - w / 2 - 5, cy - 5, w + 10, h + 10, P.beamLo);          // 틀
    rect(cx - w / 2 - 3, cy - 3, w + 6, h + 6, P.beam);
    rect(cx - w / 2, cy, w, h, lit ? P.glassLit : P.glass);
    // 유리 반사 (왼쪽 위가 밝다)
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++)
      if (x + y * 1.6 < w * 0.8) px(cx - w / 2 + x, cy + y, lit ? sh(P.glassLit, 18) : P.glassHi);
    vline(cx, cy, cy + h - 1, P.beam);
    hline(cx - w / 2, cx + w / 2 - 1, cy + Math.floor(h / 2), P.beam);
    // 덧문
    for (const s of [-1, 1]) {
      const sx = s < 0 ? cx - w / 2 - 5 - 15 : cx + w / 2 + 5;
      rect(sx, cy - 5, 15, h + 10, mul(opt.shutter, 1.0));
      for (let y = cy - 3; y < cy + h + 4; y += 5) hline(sx + 1, sx + 13, y, mul(opt.shutter, 0.72));
      vline(s < 0 ? sx : sx + 14, cy - 5, cy + h + 4, mul(opt.shutter, 1.28));
    }
    // 창턱 + 그 밑 그림자
    rect(cx - w / 2 - 22, cy + h + 5, w + 44, 6, P.stoneHi);
    rect(cx - w / 2 - 22, cy + h + 11, w + 44, 4, P.stoneLo);
    for (let x = cx - w / 2 - 20; x < cx + w / 2 + 22; x++)
      for (let k = 0; k < 6; k++)
        px(x, cy + h + 15 + k, mul(img[cy + h + 15 + k][x] || P.plaster, 0.62 + k * 0.06));
    // 화분 상자
    if (box) {
      const bw = w + 30, bx = cx - bw / 2;
      rect(bx, cy + h + 15, bw, 14, P.door);
      rect(bx, cy + h + 15, bw, 3, P.doorHi);
      for (let i = 0; i < 34; i++) {
        const fx = bx + 3 + h2(i, cx, 91) * (bw - 6), fy = cy + h + 10 + h2(i, cy, 92) * 8;
        disc(fx, fy, 3.2, h2(i, 3, 93) > 0.5 ? P.leaf : P.leafHi);
      }
      for (let i = 0; i < 9; i++) {
        const fx = bx + 4 + h2(i, cx, 94) * (bw - 8), fy = cy + h + 8 + h2(i, cy, 95) * 7;
        disc(fx, fy, 2.2, P.flower);
        px(fx, fy, [252, 226, 140]);
      }
    }
  }
  window_(FX0 + 62, FY0 + 44, 46, 46, opt.lit, true);
  window_(FX1 - 62, FY0 + 44, 46, 46, opt.lit, true);
  window_(FX0 + 54, MID + 40, 42, 52, opt.lit, false);
  window_(FX1 - 54, MID + 40, 42, 52, opt.lit, false);

  // ---- 8. 문 (안으로 들어가 있다) ----
  {
    const dw = 84, dh = 132, dx = AX - dw / 2, dy = FY1 - dh - 6;
    rect(dx - 10, dy - 12, dw + 20, dh + 12, P.stoneLo);           // 문설주
    rect(dx - 10, dy - 12, dw + 20, 6, P.stoneHi);
    rect(dx - 6, dy - 6, dw + 12, dh + 6, P.beamLo);
    rect(dx, dy, dw, dh, P.door);
    // 안으로 들어간 어둠 (왼쪽 위)
    for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
      const e = Math.min(x, y * 0.8);
      if (e < 7) px(dx + x, dy + y, mul(P.door, 0.48 + e * 0.07));
    }
    // 널 + 나뭇결
    for (let x = 10; x < dw; x += 17) {
      vline(dx + x, dy + 6, dy + dh - 1, P.doorLo);
      vline(dx + x + 1, dy + 6, dy + dh - 1, P.doorHi);
    }
    for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++)
      if (h2(x, y, 101) > 0.90) px(dx + x, dy + y, sh(P.door, -14));
    // 윗부분 아치 유리
    for (let y = 0; y < 30; y++) for (let x = 0; x < dw; x++) {
      const cx2 = dw / 2, r = 30;
      if (Math.hypot((x - cx2) / 1.15, y - 32) < r && y > 5)
        px(dx + x, dy + y, y < 14 ? P.glassHi : P.glass);
    }
    // 쇠장식 + 손잡이
    for (const hy of [dy + 26, dy + dh - 30]) {
      rect(dx + 3, hy, dw - 6, 6, [58, 54, 52]);
      rect(dx + 3, hy, dw - 6, 2, [96, 92, 88]);
    }
    disc(dx + dw - 16, dy + dh / 2 + 6, 5, [214, 176, 84]);
    disc(dx + dw - 17, dy + dh / 2 + 5, 2.4, [250, 226, 150]);
    // 문지방 돌계단
    rect(dx - 18, FY1 - 8, dw + 36, 8, P.stone);
    rect(dx - 18, FY1 - 8, dw + 36, 3, P.stoneHi);
    rect(dx - 24, FY1 - 2, dw + 48, 6, P.stoneLo);
  }

  // ---- 9. 차양 (가게만) ----
  if (opt.awning) {
    const ax0 = FX0 + 6, ax1 = FX1 - 6, ay = MID + 18;
    for (let x = ax0; x <= ax1; x++) {
      const t = (x - ax0) / (ax1 - ax0);
      const drop = Math.round(26 - 8 * Math.abs(t - 0.5) * 2);
      const stripe = Math.floor((x - ax0) / 22) % 2 === 0;
      for (let k = 0; k < drop; k++)
        px(x, ay + k, k < 3 ? [250, 250, 246]
          : (stripe ? opt.awning : [244, 242, 236]));
      // 물결 밑단
      px(x, ay + drop, mul(stripe ? opt.awning : [244, 242, 236], 0.7));
      if ((x - ax0) % 11 < 6) px(x, ay + drop + 1, mul(stripe ? opt.awning : [230, 228, 222], 0.7));
    }
    rect(ax0 - 3, ay - 4, ax1 - ax0 + 7, 5, P.beam);
    rect(ax0 - 3, ay - 4, ax1 - ax0 + 7, 2, P.beamHi);
  }

  // ---- 10. 간판 (건물 종류를 한눈에) ----
  if (opt.emblem) {
    const sx = FX1 - 14, sy = MID + 30;
    rect(sx, sy - 26, 5, 26, P.beam);                 // 기둥에 붙은 팔
    rect(sx - 46, sy - 26, 50, 5, P.beam);
    rect(sx - 44, sy - 21, 3, 10, [70, 66, 62]);
    rect(sx - 12, sy - 21, 3, 10, [70, 66, 62]);
    const bw = 52, bh = 38, bx = sx - 54, by = sy - 11;
    rect(bx, by, bw, bh, P.beamLo);
    rect(bx + 3, by + 3, bw - 6, bh - 6, [238, 226, 196]);
    rect(bx + 3, by + 3, bw - 6, 3, [250, 244, 224]);
    // 문양: 색 덩어리 세 개로 「무엇을 파는 집인가」를 표시한다
    for (const e of opt.emblem) disc(bx + 26 + e[0], by + 19 + e[1], e[2], e[3]);
  }

  // ---- 11. 처마 밑 그림자를 옆벽에도 ----
  for (let i = 0; i <= DX; i++) {
    const x = FX1 + i, y0 = FY0 + Math.round(DY * i / DX);
    for (let k = 0; k < 8; k++)
      if (inb(x, y0 + k) && img[y0 + k][x]) px(x, y0 + k, mul(img[y0 + k][x], 0.6 + k * 0.05));
  }
  return img;
}

function save(name) {
  const p = new PNG({ width: W, height: H });
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4, c = img[y][x];
    if (!c) { p.data[i + 3] = 0; continue; }
    p.data[i] = c[0]; p.data[i + 1] = c[1]; p.data[i + 2] = c[2]; p.data[i + 3] = 255;
  }
  fs.writeFileSync(OUT + name + '.png', PNG.sync.write(p));
}

// ================= 건물 종류 =================
// 지붕색 · 덧문색 · 차양 · 간판 문양으로 구분한다.
const RED = [190, 84, 48], BLUE = [78, 108, 168], SLATE = [96, 106, 126];
const GREEN = [86, 132, 76], PLUM = [126, 84, 148], TEAL = [64, 138, 148];
const BROWN = [150, 100, 58], NAVY = [64, 82, 132];
const KINDS = {
  house: { roof: RED, shutter: [92, 122, 92], lit: false },
  post: { roof: BLUE, shutter: [200, 196, 188], lit: true,
    emblem: [[0, -4, 9, [232, 232, 226]], [0, 2, 6, [90, 120, 180]]] },
  general: { roof: GREEN, shutter: [176, 132, 72], lit: true, awning: [92, 150, 92],
    emblem: [[-8, 2, 7, [176, 132, 72]], [8, 0, 8, [150, 108, 60]]] },
  smith: { roof: SLATE, shutter: [72, 70, 68], lit: true,
    emblem: [[-6, 2, 8, [96, 94, 92]], [8, -4, 6, [128, 88, 48]]] },
  lab: { roof: PLUM, shutter: [120, 96, 152], lit: true,
    emblem: [[0, 2, 9, [128, 196, 168]], [0, -7, 4, [230, 226, 240]]] },
  inn: { roof: [206, 118, 56], shutter: [150, 104, 60], lit: true, awning: [214, 150, 84],
    emblem: [[-6, 2, 8, [162, 116, 66]], [8, 1, 6, [214, 176, 92]]] },
  library: { roof: NAVY, shutter: [92, 106, 140], lit: true,
    emblem: [[-7, 0, 8, [176, 76, 64]], [4, 1, 8, [214, 196, 150]]] },
  ranch: { roof: BROWN, shutter: [140, 108, 66], lit: true,
    emblem: [[-6, 2, 8, [226, 216, 196]], [7, -2, 6, [176, 132, 84]]] },
  fish: { roof: TEAL, shutter: [96, 148, 156], lit: true, awning: [104, 168, 178],
    emblem: [[-4, 2, 8, [138, 180, 200]], [8, 2, 4, [96, 140, 168]]] },
};

for (const k in KINDS) {
  build(KINDS[k]);
  save(k === 'house' ? 'house' : 'house_' + k);
}
console.log('건물 %d채 생성 완료 (640x512)', Object.keys(KINDS).length);
