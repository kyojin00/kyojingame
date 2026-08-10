// 물약 아이콘 생성기 — 16x16 도트로 그리고 2배 확대해 32x32로 저장한다.
// 병 모양은 하나로 통일하고 **약물 색과 무늬**만 달리해서, 한눈에 "물약"으로 읽히게 한다.
//
// 실행:  node make_potion_icons.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 2;

const C = {
  line:  [42, 28, 24],
  glass: [206, 222, 230], glassDark: [166, 186, 198],
  cork:  [150, 100, 58],  cork2: [110, 70, 40],
  shine: [255, 255, 255],
};

const newCanvas = () => Array.from({ length: S }, () => new Array(S).fill(null));
const inb = (x, y) => x >= 0 && y >= 0 && x < S && y < S;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col);
}
function outline(c) {
  const out = c.map(r => r.slice());
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    if (c[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (inb(x + dx, y + dy) && c[y + dy][x + dx]) near = true;
    if (near) out[y][x] = C.line;
  }
  return out;
}

// 공통 병: 좁은 목 + 둥근 몸통. liquid = [밝은색, 어두운색]
// mark(c) 로 몸통 위에 무늬를 하나 더 얹는다.
function flask(liquid, mark) {
  const c = newCanvas();
  rect(c, 6, 1, 4, 2, C.cork);          // 코르크
  rect(c, 6, 1, 4, 1, C.cork2);
  rect(c, 6, 3, 4, 3, C.glass);         // 목
  rect(c, 4, 6, 8, 2, C.glass);         // 어깨
  rect(c, 3, 8, 10, 6, C.glass);        // 몸통
  rect(c, 4, 14, 8, 1, C.glassDark);    // 바닥
  // 약물 (몸통 아래쪽을 채운다)
  rect(c, 4, 9, 8, 5, liquid[1]);
  rect(c, 4, 9, 8, 3, liquid[0]);
  rect(c, 6, 5, 4, 1, liquid[0]);       // 목에 살짝 차 있다
  if (mark) mark(c, liquid);
  rect(c, 4, 8, 1, 3, C.shine);         // 유리 반사
  px(c, 5, 7, C.shine);
  return c;
}

const P = {
  potion_energy: [[236, 108, 96], [186, 58, 56]],     // 붉은 원기
  potion_luck:   [[248, 214, 96], [206, 158, 40]],    // 금빛 행운
  potion_swift:  [[150, 226, 232], [86, 168, 190]],   // 하늘빛 바람
  potion_ember:  [[248, 146, 58], [198, 90, 30]],     // 주황 불꽃
  potion_grow:   [[136, 214, 108], [80, 154, 68]],    // 초록 성장
  potion_guard:  [[168, 158, 210], [110, 100, 158]],  // 보랏빛 수호
  potion_moon:   [[224, 232, 255], [140, 160, 226]],  // 창백한 달빛
};

// 물약마다 몸통에 작은 무늬 하나 — 색만으로는 구분이 어렵다
const MARKS = {
  potion_energy: (c) => { rect(c, 7, 10, 2, 3, C.shine); rect(c, 6, 11, 4, 1, C.shine); },
  potion_luck:   (c) => { px(c, 7, 10, C.shine); px(c, 6, 11, C.shine); px(c, 8, 11, C.shine);
                          px(c, 7, 12, C.shine); },
  potion_swift:  (c) => { rect(c, 5, 10, 5, 1, C.shine); rect(c, 6, 12, 5, 1, C.shine); },
  potion_ember:  (c) => { px(c, 7, 12, C.shine); px(c, 8, 11, C.shine); px(c, 7, 10, C.shine);
                          px(c, 6, 11, C.shine); },
  potion_grow:   (c) => { rect(c, 7, 10, 1, 3, C.shine); px(c, 6, 11, C.shine);
                          px(c, 9, 10, C.shine); },
  potion_guard:  (c) => { rect(c, 6, 10, 4, 1, C.shine); rect(c, 6, 10, 1, 3, C.shine);
                          rect(c, 9, 10, 1, 3, C.shine); px(c, 7, 13, C.shine); px(c, 8, 13, C.shine); },
  potion_moon:   (c) => { rect(c, 6, 10, 3, 3, C.shine); rect(c, 7, 10, 3, 3, P.potion_moon[1]); },
};

const ICONS = {};
for (const id of Object.keys(P)) ICONS[id] = () => flask(P[id], MARKS[id]);

// 실패물: 병 없이 흐물흐물한 앙금 덩어리
ICONS.sludge = () => {
  const c = newCanvas();
  const a = [110, 96, 82], b = [78, 68, 58];
  rect(c, 3, 10, 10, 4, b);
  rect(c, 4, 8, 8, 3, a);
  rect(c, 6, 7, 4, 1, a);
  px(c, 5, 12, b); px(c, 11, 12, b);
  px(c, 6, 9, [140, 128, 110]);
  return c;
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
console.log('물약 아이콘', n, '장 생성');
