// 울타리 생성기 — **말뚝 하나와 이어지는 가로장.**
//
// 왜 다시 그리는가 —
//   지금 쓰는 fence.png 는 그려서 넣은 그림이 아니라 참고 그림에서
//   오려 낸 것이다. 매끈한 그러데이션에 가장자리가 뭉개져 있어서
//   도트로 찍은 집·사람·바닥 사이에 놓으면 혼자 사진처럼 뜬다.
//   그리고 **한 칸짜리 조각**이라, 열 칸을 두르면 「ㅐㅐㅐㅐㅐ」 하고
//   같은 조각이 열 번 찍힌다 — 울타리가 아니라 도장이었다.
//
// 그래서 두 가지를 고친다.
//   ① 그림체   바닥·건물과 같은 규칙으로 찍는다. 논리 16x16, 한 칸 4px,
//              나무 톤 사다리 일곱 단, 윗변은 빛 · 아랫변은 턱.
//   ② 이음     이웃 넷(북·동·남·서)에 울타리가 있느냐로 **열여섯 벌**을
//              만든다. 말뚝은 언제나 서 있고, 이어진 쪽으로만 장을 뻗는다.
//              그래야 모퉁이가 모퉁이로 보이고 끝이 끝으로 보인다.
//
// 이음 번호(mask): 북1 · 동2 · 남4 · 서8. fence_<mask>.png 로 나간다.
//
// 세로줄(북/남)은 가로장을 그릴 수가 없다 — 카메라에서 멀어지는 방향이라
// 두 가로장이 말뚝과 같은 자리에 겹쳐 보인다. 그 대신 말뚝 위(북)와
// 발치(남)로 **좁은 널**을 내서 위아래 칸의 말뚝과 이어 붙인다.
//
// 도트 크기: 16x16 논리 -> 4배 -> 64x64. 게임에서 0.5배로 얹으므로
// 한 칸이 화면 2px — 사람·집·바닥과 정확히 같다.
//
// 실행:  node make_fence.js            -> ref/proposed_fence_*.png (제안만)
//        node make_fence.js --install  -> sprites/ 에 실제로 넣는다
//                                         (뒤에 make_import.py 를 꼭 돌린다)
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');

const N = 16;                    // 논리 격자 (한 변)
const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)
const F = N * S;                 // 64

function h(x, y, k) {
  let n = (x * 73856093) ^ (y * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// ---- 나무 톤 사다리 ----
//
// 건물 목재(t/T/u)와 **같은 색줄기**에서 뽑았다. 울타리만 다른 나무로
// 보이면 마을이 두 벌의 그림이 된다. 밝은 쪽이 0.
//   0 빛받는 윗면   2 정면   4 그늘   6 윤곽에 가까운 바닥
const W = [
  [216, 164, 100], [192, 138, 78], [166, 112, 58], [140, 90, 44],
  [112, 68, 32], [86, 50, 24], [58, 34, 16],
];
const OUT = [38, 26, 20];        // 윤곽. 검정이 아니라 **탄 나무빛**이다
const MOSS = [[112, 140, 74], [88, 114, 58], [66, 88, 44]];
const NAIL = [[176, 170, 158], [112, 106, 98]];

// 그림자만 반투명이다. 나머지는 전부 불투명 — 도트는 반투명으로 뭉개면
// 바로 사진처럼 보인다
const SHADOW = [30, 26, 34, 78];

// ---- 자리 ----
//
// 말뚝은 칸 한복판에 서서 밑동이 칸 밑변에 닿는다 (y=14). 위로 y=3 까지.
// 가로장 둘은 말뚝 **뒤로** 지나간다 — 먼저 그리고 말뚝으로 덮는다.
const PX0 = 6, PX1 = 9;          // 말뚝 좌우
const PTOP = 3, PBOT = 14;       // 말뚝 위·아래
const RAIL = [6, 10];            // 가로장 두 줄의 윗변 (각 3줄 두께)
const VX0 = 7, VX1 = 8;          // 세로 널 좌우

class T {
  constructor() {
    this.d = Array.from({ length: N }, () => new Array(N).fill(null));
  }
  px(x, y, c) {
    if (!c) return;
    if (x < 0 || y < 0 || x >= N || y >= N) return;   // 감지 않는다 — 물건이다
    this.d[y][x] = c;
  }
  get(x, y) {
    if (x < 0 || y < 0 || x >= N || y >= N) return null;
    return this.d[y][x];
  }
  rect(x0, y0, x1, y1, c) {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.px(x, y, c);
  }
  hline(x0, x1, y, c) { for (let x = x0; x <= x1; x++) this.px(x, y, c); }
  vline(x, y0, y1, c) { for (let y = y0; y <= y1; y++) this.px(x, y, c); }
  render() {
    const im = new PNG({ width: F, height: F });
    im.data.fill(0);
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      const a = c.length > 3 ? c[3] : 255;
      for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
        const i = ((y * S + sy) * F + (x * S + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2];
        im.data[i + 3] = a;
      }
    }
    return im;
  }
}

// ---- 물건 하나를 그리는 규칙 ----
//
// 기와 한 장이 「윗변은 빛, 속은 기본, 아랫변은 턱」이듯 나무도 같다.
// 가로장 한 개 = 윗변(밝다) · 속 · 아랫변(턱). 세 줄이면 판자가 된다.
function railH(g, x0, x1, y, seed) {
  if (x1 < x0) return;
  g.hline(x0, x1, y, W[1]);          // 윗변 — 위를 보고 있으니 빛을 받는다
  g.hline(x0, x1, y + 1, W[3]);      // 속
  g.hline(x0, x1, y + 2, W[5]);      // 아랫변 = 턱
  // 나뭇결 — 결이 없으면 판자가 아니라 색 띠다. 속줄에만, 성기게
  for (let x = x0; x <= x1; x++) {
    if (h(x, y, seed + 3) < 0.22) g.px(x, y + 1, W[4]);
    if (h(x, y, seed + 5) < 0.14) g.px(x, y, W[2]);      // 윗변에도 결 한 점
  }
  // 옹이 하나 — 판자마다는 아니고 가끔
  const kx = x0 + Math.floor(h(x0, y, seed + 7) * Math.max(1, x1 - x0));
  if (h(kx, y, seed + 9) < 0.45) {
    g.px(kx, y + 1, W[5]);
    g.px(kx + 1, y + 1, W[4]);
  }
}

// 말뚝에 장을 박은 못 — 이게 있어야 「깎아 놓은 나무」가 아니라 「짜 맞춘 것」이다
function nail(g, x, y) {
  g.px(x, y, NAIL[1]);
  g.px(x, y - 1, NAIL[0]);
}

// 말뚝 하나. 위는 도끼로 쳐낸 자리라 빛을 받고, 오른쪽은 그늘이다
function post(g, seed) {
  // 그늘 — 오른쪽 아래로 진다 (해가 왼쪽 위)
  for (let y = PTOP + 2; y <= PBOT; y++) g.px(PX1 + 1, y + 1, SHADOW);
  g.px(PX1 + 2, PBOT + 1, SHADOW);
  // 몸통
  g.rect(PX0, PTOP, PX1, PBOT, W[3]);
  g.vline(PX0, PTOP, PBOT, W[2]);          // 왼쪽 = 빛
  g.vline(PX0 + 1, PTOP, PBOT, W[2]);
  g.vline(PX1, PTOP, PBOT, W[5]);          // 오른쪽 = 그늘
  // 윗머리 — 한 줄 밝게 하고 오른쪽 모서리는 깎아 낸다
  g.hline(PX0, PX1 - 1, PTOP, W[0]);
  g.px(PX1, PTOP, W[2]);
  if (h(seed, 1, 21) < 0.5) g.px(PX1, PTOP, null);   // 쪼개진 머리
  // 결 — 세로로 흐른다. 판자와 같은 규칙(속줄에만)
  for (let y = PTOP + 1; y <= PBOT; y++) {
    if (h(y, seed, 23) < 0.30) g.px(PX0 + 1, y, W[4]);
    if (h(y, seed, 27) < 0.24) g.px(PX0 + 2, y, W[4]);
    if (h(y, seed, 29) < 0.16) g.px(PX0, y, W[3]);
  }
  // 밑동 — 흙에 박힌 자리는 젖어 어둡다
  g.hline(PX0, PX1, PBOT, W[6]);
  g.hline(PX0 + 1, PX1 - 1, PBOT - 1, W[5]);
  // 발치의 이끼 — 오래 서 있었다는 표시. 왼쪽(그늘 반대)에만 붙는다
  if (h(seed, 3, 31) < 0.7) {
    g.px(PX0 - 1, PBOT, MOSS[1]);
    g.px(PX0, PBOT - 1, MOSS[2]);
  }
  if (h(seed, 5, 33) < 0.4) g.px(PX1, PBOT - 2, MOSS[2]);
}

// 세로줄(북·남)로 이어지는 좁은 널.
//
// 카메라에서 멀어지는 방향이라 가로장을 그릴 수가 없다 — 두 장이 말뚝과
// 같은 자리에 겹쳐 보인다. 위칸·아래칸의 말뚝과 **한 줄기로 이어 붙이는**
// 좁은 널 하나면 세로줄이 끊기지 않는다.
function railV(g, up, seed) {
  // 두 칸으로 좁게, 그것도 어둡게 뒀더니 세로줄이 **끊겨** 보였다 —
  // 말뚝 사이에 그늘진 틈이 난 것처럼. 위에서 내려다보면 보이는 것은
  // 가로장의 **윗면**이라 오히려 빛을 받는다. 세 칸으로 넓히고 왼쪽
  // 한 줄은 밝게 깐다. 그래야 한 줄기 나무로 이어진다.
  // 말뚝보다 **한 칸 좁게** 둔다. 같은 폭으로 깔았더니 세로줄이 통나무
  // 한 대로 보여서 말뚝이 어디 서 있는지 안 보였다. 잘록해야 「말뚝과
  // 장」으로 읽힌다.
  if (up) {
    // 말뚝 머리 위로 — 여기만 보인다 (아래는 말뚝이 덮는다)
    g.vline(VX0, 0, PTOP + 1, W[1]);
    g.vline(VX1, 0, PTOP + 1, W[3]);
    for (let y = 0; y <= PTOP; y++) if (h(y, seed, 41) < 0.28) g.px(VX0, y, W[2]);
    g.px(VX1 + 1, 0, SHADOW); g.px(VX1 + 1, 1, SHADOW);
  } else {
    // 발치 아래 — 말뚝 밑동과 아랫칸 널 사이의 한 줄을 메운다
    g.vline(VX0, PBOT, N - 1, W[3]);
    g.vline(VX1, PBOT, N - 1, W[5]);
  }
}

// 한 벌 — 이음 번호(mask)대로 그린다
function fence(mask) {
  const g = new T();
  const nn = (mask & 1) !== 0, ee = (mask & 2) !== 0;
  const ss = (mask & 4) !== 0, ww = (mask & 8) !== 0;
  const seed = mask + 1;
  // ① 세로 널이 제일 뒤 (말뚝이 덮는다)
  if (nn) railV(g, true, seed);
  if (ss) railV(g, false, seed);
  // ② 가로장 — 말뚝 뒤로 지나간다. 이어진 쪽만 칸 끝까지 뻗는다
  for (let r = 0; r < 2; r++) {
    const y = RAIL[r];
    // 장 밑의 그늘 — 땅에 뜬 것으로 보이려면 아랫변만으로는 모자라다
    if (ww) { g.hline(0, PX0 - 1, y + 3, SHADOW); railH(g, 0, PX0 - 1, y, seed * 7 + r); }
    if (ee) { g.hline(PX1 + 1, N - 1, y + 3, SHADOW); railH(g, PX1 + 1, N - 1, y, seed * 11 + r); }
  }
  // ③ 말뚝
  post(g, seed);
  // ④ 못 — 장이 말뚝에 닿는 자리
  for (let r = 0; r < 2; r++) {
    if (ww) nail(g, PX0, RAIL[r] + 1);
    if (ee) nail(g, PX1, RAIL[r] + 1);
  }
  // ⑤ 외따로 선 말뚝은 조금 낮춰 둔다 — 끝은 끝으로 보여야 한다
  if (mask === 0) {
    g.hline(PX0, PX1, PTOP, null);
    g.hline(PX0, PX1 - 1, PTOP + 1, W[0]);
  }
  return g;
}

// ---- 내보내기 ----
const OUTS = {};
for (let mask = 0; mask < 16; mask++) OUTS['fence_' + mask] = fence(mask).render();
// 옛 이름도 한 장 남긴다 — 아직 fence 한 장만 보는 자리가 있을 수 있다
OUTS['fence'] = fence(2 | 8).render();

// 미리보기 — 열여섯 벌을 한 줄로 늘어놓고, 밑에 실제로 두른 모습을 낸다
function preview() {
  const cols = 16, W2 = cols * F, H2 = F * 6;
  const im = new PNG({ width: W2, height: H2 });
  for (let i = 0; i < im.data.length; i += 4) {
    im.data[i] = 104; im.data[i + 1] = 158; im.data[i + 2] = 82; im.data[i + 3] = 255;
  }
  const blit = (src, dx, dy) => {
    for (let y = 0; y < F; y++) for (let x = 0; x < F; x++) {
      const si = (y * F + x) * 4, a = src.data[si + 3] / 255;
      if (a === 0) continue;
      const di = ((dy + y) * W2 + (dx + x)) * 4;
      for (let c = 0; c < 3; c++)
        im.data[di + c] = Math.round(src.data[si + c] * a + im.data[di + c] * (1 - a));
    }
  };
  for (let mask = 0; mask < 16; mask++) blit(OUTS['fence_' + mask], mask * F, 0);
  // 6x4 짜리 마당 하나를 실제로 둘러 본다 (아래 변 한가운데가 문)
  const RW = 12, RH = 4;
  const has = (x, y) => {
    if (x < 0 || x >= RW || y < 0 || y >= RH) return false;
    const edge = x === 0 || x === RW - 1 || y === 0 || y === RH - 1;
    if (!edge) return false;
    return !(y === RH - 1 && Math.abs(x - 5) <= 1);   // 문 세 칸
  };
  for (let y = 0; y < RH; y++) for (let x = 0; x < RW; x++) {
    if (!has(x, y)) continue;
    const mk = (has(x, y - 1) ? 1 : 0) | (has(x + 1, y) ? 2 : 0)
      | (has(x, y + 1) ? 4 : 0) | (has(x - 1, y) ? 8 : 0);
    blit(OUTS['fence_' + mk], (x + 2) * F, (y + 1) * F);
  }
  return im;
}

if (INSTALL) {
  for (const k in OUTS) fs.writeFileSync(SPR + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('설치: sprites/fence_0..15.png (+ fence.png)');
  console.log('  다음에 반드시 -> python3 make_import.py');
} else {
  for (const k in OUTS) fs.writeFileSync(REF + 'proposed_' + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('제안: ref/proposed_fence_*.png');
}
fs.writeFileSync(REF + 'preview_fence.png', PNG.sync.write(preview()));
console.log('미리보기: ref/preview_fence.png');
