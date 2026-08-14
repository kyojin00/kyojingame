// 동굴 표본 아이콘 3장 (메인 스토리 10) — make_ending_icons.js 와 같은 방식.
//   crystal      수정 (푸른 결정 무더기)
//   cave_moss    동굴 이끼 (돌에 붙은 초록 이끼)
//   glow_shroom  발광 버섯 (청록빛으로 빛나는 버섯)
// 전체 생성기(make_item_icons.js)는 유저 교체 아트를 덮어쓰므로 새 석 장만 찍는다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_cave_finds.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 16, Z = 2;

const C = {
  line:  [42, 28, 24],
  white: [246, 244, 238],
  ice:   [190, 232, 246], blue: [116, 176, 232], blue2: [70, 118, 190],
  moss:  [96, 158, 74],   moss2: [64, 116, 52],  moss3: [140, 194, 104],
  rock:  [116, 108, 112], rock2: [86, 80, 86],
  glow:  [118, 235, 208], glow2: [66, 172, 152], stem: [222, 216, 190],
  teal:  [170, 248, 228],
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

const ICONS = {
  // 수정 — 굵은 결정 하나에 작은 결정 둘이 기댄 무더기
  crystal: () => {
    const c = newCanvas();
    rect(c, 6, 3, 3, 2, C.ice);               // 큰 결정 꼭짓점
    rect(c, 5, 5, 5, 5, C.blue);              // 큰 결정 몸통
    rect(c, 6, 5, 1, 4, C.ice);               // 세로 반짝임
    rect(c, 8, 7, 2, 3, C.blue2);             // 그늘 면
    rect(c, 2, 8, 3, 2, C.ice);               // 왼쪽 작은 결정
    rect(c, 2, 10, 3, 3, C.blue);
    rect(c, 11, 9, 3, 2, C.blue);             // 오른쪽 작은 결정
    rect(c, 11, 11, 3, 2, C.blue2);
    rect(c, 3, 13, 10, 1, C.rock2);           // 받침 돌
    px(c, 7, 2, C.white); px(c, 12, 8, C.white);  // 반짝
    return c;
  },
  // 동굴 이끼 — 젖은 돌 위에 이끼가 도톰하게 얹혀 있다
  cave_moss: () => {
    const c = newCanvas();
    rect(c, 3, 9, 10, 4, C.rock);             // 돌
    rect(c, 4, 12, 8, 1, C.rock2);
    rect(c, 4, 7, 8, 3, C.moss);              // 이끼 본체
    rect(c, 3, 8, 2, 2, C.moss);
    rect(c, 11, 8, 2, 2, C.moss);
    rect(c, 5, 6, 3, 1, C.moss3);             // 봉긋한 윗결
    rect(c, 9, 6, 2, 1, C.moss3);
    px(c, 6, 8, C.moss2); px(c, 9, 9, C.moss2); px(c, 11, 8, C.moss2);
    px(c, 5, 7, C.moss3); px(c, 10, 7, C.moss3);
    px(c, 4, 11, C.ice);                      // 물기 한 방울
    return c;
  },
  // 발광 버섯 — 갓이 청록으로 빛나고, 둘레에 빛가루가 떠 있다
  glow_shroom: () => {
    const c = newCanvas();
    rect(c, 5, 4, 6, 3, C.glow);              // 갓
    rect(c, 4, 6, 8, 2, C.glow);
    rect(c, 4, 7, 8, 1, C.glow2);             // 갓 밑면
    rect(c, 6, 3, 3, 1, C.teal);              // 갓 꼭대기 빛
    px(c, 6, 5, C.teal); px(c, 9, 5, C.white);
    rect(c, 7, 8, 2, 5, C.stem);              // 대
    rect(c, 6, 12, 4, 1, C.stem);             // 밑동
    px(c, 7, 9, C.glow2);                     // 대에 비치는 빛
    rect(c, 5, 13, 6, 1, C.rock2);            // 흙
    px(c, 2, 5, C.teal); px(c, 13, 4, C.teal); px(c, 12, 10, C.teal);  // 빛가루
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
console.log('동굴 표본 아이콘', n, '장 생성');
