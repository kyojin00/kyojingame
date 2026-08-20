// 소형 구조물 — 동굴 입구 · 온천 · 해변 노점 · 옛 전망대.
//
// 넷 다 옛 1px 밀도(잔 도트)로 남아 있어서, 화면 도트 2px로 통일된
// 세계에서 홀로 「잘게 그린 스티커」로 보였다. 마을 건물과 같은 자로
// 다시 그린다: 도트 한 칸 = 그림 2px, 톤 사다리, 알의 윗변이 빛,
// 어두운 윤곽선, 조용한 면 + 드문 장식.
//
// 실행:  node make_structures.js            -> ref/proposed_*.png
//        node make_structures.js --install  -> sprites/ 에 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');

function h(x, y, k) {
  let n = (x * 73856093) ^ (y * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const mix = (a, b, t) => a.map((v, i) => Math.round(v * (1 - t) + b[i] * t));

// 도트 그릇 — 논리 한 칸이 그림 2px 로 부풀어 나간다
class D {
  constructor(w, hh) { this.w = w; this.h = hh;
    this.d = Array.from({ length: hh }, () => new Array(w).fill(null)); }
  px(x, y, c) { if (c && x >= 0 && y >= 0 && x < this.w && y < this.h) this.d[y][x] = c; }
  get(x, y) { return (x >= 0 && y >= 0 && x < this.w && y < this.h) ? this.d[y][x] : null; }
  rect(x0, y0, x1, y1, c) {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.px(x, y, c);
  }
  outline(col) {                       // 몸에 붙은 빈 칸에 윤곽선
    const add = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.d[y][x]) continue;
      for (const [ax, ay] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
        if (this.get(x + ax, y + ay) && this.get(x + ax, y + ay) !== col) { add.push([x, y]); break; }
    }
    for (const [x, y] of add) this.px(x, y, col);
  }
  render(Z) {                          // Z = 도트 한 칸의 그림 px (기본 2)
    Z = Z || 2;
    const im = new PNG({ width: this.w * Z, height: this.h * Z });
    im.data.fill(0);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      for (let sy = 0; sy < Z; sy++) for (let sx = 0; sx < Z; sx++) {
        const i = ((y * Z + sy) * this.w * Z + (x * Z + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2];
        im.data[i + 3] = c.length > 3 ? c[3] : 255;
      }
    }
    return im;
  }
}
function save(name, im) {
  fs.writeFileSync((INSTALL ? SPR : REF + 'proposed_') + name + '.png', PNG.sync.write(im));
}

const LINE = [44, 34, 28];
// 따뜻한 돌 — 건물 stonewarm 과 같은 축
const ST = [[216, 206, 186], [178, 168, 148], [146, 136, 118], [118, 108, 94],
            [92, 84, 72], [64, 58, 50]];
// 나무 — 울타리(make_fence)와 같은 축
const W = [[212, 148, 78], [182, 116, 48], [160, 96, 38], [140, 78, 28],
           [112, 60, 23], [84, 44, 18]];
const MOSS = [[124, 148, 92], [96, 122, 72]];

// 막돌 한 알 — 면(tone), 윗변 빛, 밑변 그늘. 이 세 줄이 돌의 전부다
function stone(g, x0, y0, w, hh, tone) {
  for (let y = y0; y < y0 + hh; y++) for (let x = x0; x < x0 + w; x++) {
    const corner = (x === x0 || x === x0 + w - 1) && (y === y0 || y === y0 + hh - 1);
    if (!corner) g.px(x, y, ST[tone]);
  }
  for (let x = x0 + 1; x <= x0 + w - 2; x++) {
    g.px(x, y0, ST[clamp(tone - 1, 0, 5)]);            // 윗변 빛
    g.px(x, y0 + hh - 1, ST[clamp(tone + 2, 0, 5)]);   // 밑변 그늘
  }
}

// ---- 동굴 입구 (64x96 = 32x48 도트) ----
//
// 막돌이 쌓인 언덕에 뚫린 아치. 안은 위로 갈수록 어둡다 —
// 빛은 바닥으로 들어오지 천장으로는 안 든다
function cave() {
  const g = new D(32, 48), CX = 16;
  // 언덕 실루엣 — 위가 둥근 무더기
  for (let y = 10; y < 48; y++) {
    const t = (y - 10) / 38;
    const hw = Math.round(6 + 10 * Math.sqrt(Math.min(1, t * 1.6)));
    g.rect(CX - hw, y, CX + hw - 1, y, ST[3]);
  }
  // 막돌 — 크기와 낯빛이 다른 알을 손으로 놓는다 (다 그리지 않는다)
  const spots = [[6, 14, 5, 3, 2], [15, 12, 6, 3, 1], [22, 16, 5, 3, 3],
    [4, 22, 5, 4, 3], [24, 24, 6, 3, 2], [3, 32, 6, 4, 2], [25, 33, 5, 4, 3],
    [7, 41, 6, 3, 3], [21, 41, 6, 3, 2], [12, 18, 4, 3, 3], [26, 42, 4, 3, 1]];
  for (const [x, y, w2, h2, t] of spots) stone(g, x, y, w2, h2, t);
  // 아가리 — 아치. 안은 위가 더 어둡다
  const AW = 6, AT = 22, AB = 47;
  for (let y = AT; y <= AB; y++) {
    const t2 = (y - AT) / (AB - AT);
    const hw = y < AT + 3 ? AW - (AT + 3 - y) : AW;
    const dark = mix([8, 7, 12], [30, 26, 40], t2);
    g.rect(CX - hw, y, CX + hw - 1, y, dark);
  }
  // 아치 테 — 문설주 돌. 입구는 돌로 둘렀다는 것이 보여야 한다
  for (let y = AT + 1; y <= AB; y += 4) {
    stone(g, CX - AW - 3, y, 3, 3, 1 + (y % 8 === 1 ? 1 : 0));
    stone(g, CX + AW, y, 3, 3, 2 - (y % 8 === 1 ? 1 : 0));
  }
  stone(g, CX - 4, AT - 3, 8, 3, 1);                   // 이맛돌
  // 이끼 — 그늘진 위쪽에 두어 점
  g.px(9, 13, MOSS[0]); g.px(10, 13, MOSS[1]); g.px(23, 15, MOSS[0]);
  g.px(5, 24, MOSS[1]); g.px(27, 26, MOSS[0]);
  g.outline(LINE);
  return g;
}

// ---- 온천 (128x192 = 64x96 도트 판이 아니라 64x96 그림 = 32x48 도트) ----
//
// 김이 오르는 바위 탕. 물은 청록, 가장자리에 거품 한 줄,
// 김은 반투명 두 줄기 — 멀리서도 「뜨거운 물」로 읽혀야 한다
function onsen() {
  const g = new D(32, 48), CX = 16, CY = 36;
  const WA = [[142, 214, 224], [96, 182, 202], [66, 150, 178], [46, 118, 148]];
  // 탕 — 타원. 물부터 깔고 테두리 돌을 두른다
  const RX = 13, RY = 9;
  for (let y = CY - RY; y <= CY + RY; y++) for (let x = CX - RX; x <= CX + RX; x++) {
    const dx = (x - CX) / RX, dy = (y - CY) / RY;
    const d = dx * dx + dy * dy;
    if (d > 1) continue;
    const t = (y - (CY - RY)) / (RY * 2);
    g.px(x, y, WA[t < 0.3 ? 2 : (t < 0.75 ? 1 : 2)]);
  }
  // 수면의 빛 — 위쪽 호를 따라 한 줄, 반짝임 두 점
  for (let x = CX - 7; x <= CX + 7; x++)
    if (h(x, 1, 7) < 0.7) g.px(x, CY - 5, WA[0]);
  g.px(CX - 3, CY - 1, WA[0]); g.px(CX + 5, CY + 2, WA[0]);
  // 테두리 돌 — 타원을 따라 알을 하나씩 (크기·낯빛이 다르다)
  const RIM = 14;
  for (let i = 0; i < RIM; i++) {
    const a = (i / RIM) * Math.PI * 2;
    const x = Math.round(CX + Math.cos(a) * RX) - 1;
    const y = Math.round(CY + Math.sin(a) * (RY + 1)) - 1;
    const t = h(i, 3, 11) < 0.3 ? 1 : (h(i, 5, 12) < 0.75 ? 2 : 3);
    stone(g, x - 1, y - 1, 3 + (i % 2), 3, t);
  }
  // 나무 물통 — 탕가에 하나. 사람이 다녀간다는 표
  g.rect(27, 27, 30, 30, W[2]);
  g.rect(27, 27, 30, 27, W[0]);
  g.px(27, 28, W[4]); g.px(30, 28, W[4]);
  g.rect(27, 29, 30, 29, W[4]);
  g.outline(LINE);
  // 김 — 반투명 두 줄기. **윤곽선 뒤에** 그린다: 김에 검은 테가 붙으면
  // 연기가 아니라 지렁이가 된다. 위로 갈수록 옅고 옆으로 눕는다
  for (const [sx, ph] of [[CX - 5, 0], [CX + 4, 2]]) {
    for (let k = 0; k < 14; k++) {
      const y = CY - RY - 3 - k;
      const x = sx + Math.round(Math.sin(k * 0.55 + ph) * 2.2);
      const a = Math.round(170 - k * 11);
      g.px(x, y, [236, 242, 246, a]);
      if (k % 3 !== 0) g.px(x + 1, y, [214, 226, 234, Math.round(a * 0.7)]);
    }
  }
  return g;
}

// ---- 해변 노점 (96x84 = 48x42 도트) ----
//
// 줄무늬 차양 + 널판 계산대. 차양의 비늘단, 널의 못과 결 —
// 건물의 처마·문과 같은 자다
function stall() {
  const g = new D(48, 42);
  const RED = [198, 74, 60], REDD = [162, 54, 44], CREAM = [242, 232, 208], CREAMD = [214, 202, 176];
  // 차양 — 윗면 한 줄이 빛을 받고, 세로 줄무늬, 비늘단으로 끝난다
  g.rect(2, 4, 45, 4, mix(CREAM, [255, 255, 255], 0.3));
  for (let y = 5; y <= 12; y++) for (let x = 2; x <= 45; x++) {
    const s = Math.floor((x - 2) / 6) % 2 === 0;
    g.px(x, y, s ? (y === 12 ? REDD : RED) : (y === 12 ? CREAMD : CREAM));
  }
  for (let x = 2; x <= 45; x += 6) {                    // 비늘단 — 줄무늬마다 한 칸 처진다
    const s = Math.floor((x - 2) / 6) % 2 === 0;
    g.rect(x + 2, 13, x + 3, 13, s ? REDD : CREAMD);
  }
  // 기둥 둘 — 왼변이 빛을 받는다
  for (const px2 of [4, 42]) {
    g.rect(px2, 13, px2 + 1, 38, W[3]);
    for (let y = 13; y <= 38; y++) g.px(px2, y, W[1]);
  }
  // 계산대 — 윗면(빛) + 앞면(**세로 널**). 가로 띠로 나눴더니 서랍장이
  // 됐다 — 노점의 앞면은 세로로 친 널이다
  g.rect(7, 22, 40, 23, W[0]);                          // 상판 윗면
  g.rect(7, 24, 40, 24, W[2]);
  for (let y = 25; y <= 38; y++) for (let x = 7; x <= 40; x++) {
    const m2 = (x - 7) % 5;
    g.px(x, y, m2 === 4 ? W[4] : (m2 === 0 ? W[1] : W[2]));
  }
  for (let x = 9; x <= 40; x += 5) {                    // 널머리 못 — 상판 밑 한 줄
    g.px(x, 26, W[5]); g.px(x, 36, W[5]);
  }
  // 결 — 드문 세로 점선
  for (const [gx, gy] of [[13, 29], [20, 33], [29, 28], [35, 34]]) {
    g.px(gx, gy, W[3]); g.px(gx, gy + 1, W[3]);
  }
  g.rect(7, 38, 40, 38, W[5]);                          // 밑동 그늘
  // 상판의 물건 — 소라 · 병 · 산호 (드물게, 하나씩)
  g.px(12, 21, [232, 168, 172]); g.px(13, 21, [244, 196, 196]); g.px(13, 20, [232, 168, 172]);
  g.rect(21, 19, 22, 21, [110, 170, 196]); g.px(21, 18, [80, 130, 160]);
  g.px(31, 21, [238, 130, 96]); g.px(32, 20, [238, 130, 96]); g.px(32, 21, [212, 104, 76]);
  g.outline(LINE);
  return g;
}

// ---- 옛 전망대 (64x96 = 32x48 도트) ----
//
// 무너져 가는 나무 망루. 바랜 나무(회색이 섞인 W), 부러진 난간,
// 기둥의 X자 가새 — 실루엣만으로 「높이 보던 곳」이 나와야 한다
function lookout() {
  const g = new D(32, 48);
  const gray = (c, t) => mix(c, [150, 146, 138], t);
  const LK = W.map(c => gray(c, 0.42));                 // 비바람에 바랜 나무
  // 다리 둘 + 가새
  for (const lx of [7, 22]) {
    g.rect(lx, 14, lx + 2, 46, LK[3]);
    for (let y = 14; y <= 46; y++) g.px(lx, y, LK[1]);  // 왼변 빛
  }
  for (let k = 0; k <= 12; k++) {                       // X 가새
    const t = k / 12;
    g.px(Math.round(10 + t * 11), 24 + k, LK[2]);
    g.px(Math.round(21 - t * 11), 24 + k, LK[2]);
  }
  g.rect(7, 40, 24, 41, LK[3]);                         // 아래 가로대
  g.rect(7, 40, 24, 40, LK[1]);
  // 상판 — 오른쪽이 부러져 내려앉았다
  g.rect(3, 10, 24, 11, LK[2]);
  g.rect(3, 10, 24, 10, LK[0]);
  g.rect(25, 12, 28, 13, LK[3]);                        // 부러져 처진 널
  g.px(27, 14, LK[4]);
  // 난간 — 몇 대는 부러지고 없다
  for (const bx of [4, 9, 14, 19]) g.rect(bx, 5, bx, 9, LK[2]);
  g.rect(4, 5, 19, 5, LK[1]);
  g.px(22, 7, LK[4]);                                   // 부러진 그루터기만
  // 사다리 — 왼 다리에 걸쳐 있다
  for (let y = 16; y <= 44; y += 4) g.rect(4, y, 6, y, LK[1]);
  g.rect(4, 14, 4, 46, LK[3]); g.rect(6, 14, 6, 46, LK[3]);
  // 이끼와 풀 — 밑동에
  g.px(8, 46, MOSS[0]); g.px(23, 45, MOSS[1]); g.px(24, 46, MOSS[0]);
  g.outline(LINE);
  return g;
}

save('cave', cave().render());
save('onsen', onsen().render());
save('stall', stall().render());
save('old_lookout', lookout().render());
console.log('소형 구조물 4점 — 동굴 입구 64x96 · 온천 64x96 · 노점 96x84 · 전망대 64x96');
console.log(INSTALL ? '  sprites/ 에 넣었다' : '  ref/proposed_*.png 로만 뽑았다');
