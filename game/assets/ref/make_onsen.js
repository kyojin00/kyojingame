// 온천·수맥 아트 (메인 스토리 15) — 세 장.
//   onsen         마을 온천 (64x96 세계 오브젝트 — 바위 탕 + 김)
//   rock_wedge    착암 쐐기 (16x16 -> 2배 아이콘)
//   spring_water  샘물 표본 (16x16 -> 2배 아이콘)
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_onsen.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

const C = {
  line:  [42, 28, 24],
  rock:  [116, 108, 112], rock2: [86, 80, 86], rock3: [148, 140, 142],
  water: [104, 178, 206], water2: [72, 140, 176], foam: [206, 238, 246],
  steam: [232, 240, 244], steam2: [206, 220, 228],
  metal: [138, 132, 128], metal2: [96, 92, 90], edge: [188, 186, 182],
  wood:  [110, 78, 48], ice: [190, 232, 246], white: [246, 244, 238],
  grass: [92, 138, 70],
};

function canvas(w, h) { return Array.from({ length: h }, () => new Array(w).fill(null)); }
function rect(c, x, y, w, h, col) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const yy = y + j, xx = x + i;
    if (c[yy] && xx >= 0 && xx < c[0].length && col) c[yy][xx] = col;
  }
}
function px(c, x, y, col) { if (c[y] && x >= 0 && x < c[0].length && col) c[y][x] = col; }
function outline(c) {
  const h = c.length, w = c[0].length;
  const out = c.map(r => r.slice());
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (c[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]])
      if (y + dy >= 0 && y + dy < h && x + dx >= 0 && x + dx < w && c[y + dy][x + dx]) near = true;
    if (near) out[y][x] = C.line;
  }
  return out;
}
function save(name, c, zoom) {
  const h = c.length, w = c[0].length;
  const p = new PNG({ width: w * zoom, height: h * zoom });
  p.data.fill(0);
  for (let y = 0; y < h * zoom; y++) for (let x = 0; x < w * zoom; x++) {
    const col = c[Math.floor(y / zoom)][Math.floor(x / zoom)];
    if (!col) continue;
    const i = (y * w * zoom + x) * 4;
    p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
  }
  fs.writeFileSync(OUT + name + '.png', PNG.sync.write(p));
}

// ---- 온천 (32x48 -> 2배 = 64x96) ----
// 바위로 두른 탕에 더운 물이 차 있고, 위로 김이 오른다.
{
  const c = canvas(32, 48);
  // 김 (위쪽으로 흩어지는 덩어리)
  rect(c, 8, 2, 6, 3, C.steam2); rect(c, 9, 1, 4, 3, C.steam);
  rect(c, 17, 4, 6, 3, C.steam2); rect(c, 18, 3, 4, 3, C.steam);
  rect(c, 12, 8, 7, 3, C.steam); rect(c, 20, 10, 4, 2, C.steam2);
  // 뒤쪽 바위 벽
  rect(c, 3, 14, 26, 8, C.rock2);
  rect(c, 4, 13, 24, 3, C.rock);
  px(c, 7, 15, C.rock3); px(c, 20, 14, C.rock3); px(c, 24, 16, C.rock3);
  // 탕 테두리 바위
  rect(c, 2, 20, 28, 4, C.rock);
  rect(c, 1, 24, 30, 14, C.rock2);
  rect(c, 2, 36, 28, 3, C.rock);
  // 물
  rect(c, 5, 24, 22, 12, C.water2);
  rect(c, 6, 25, 20, 9, C.water);
  // 물결·거품
  rect(c, 8, 27, 7, 1, C.foam);
  rect(c, 17, 30, 6, 1, C.foam);
  rect(c, 10, 32, 8, 1, C.foam);
  px(c, 7, 30, C.foam); px(c, 23, 26, C.foam); px(c, 14, 34, C.foam);
  // 물이 솟는 바위 틈 (뒤쪽 가운데)
  rect(c, 14, 20, 4, 4, C.water);
  px(c, 15, 19, C.foam); px(c, 16, 18, C.foam);
  // 탕 둘레 풀
  rect(c, 0, 38, 6, 2, C.grass); rect(c, 26, 38, 6, 2, C.grass);
  save('onsen', outline(c), 2);
}

// ---- 착암 쐐기 (16x16 -> 2배) ----
{
  const c = canvas(16, 16);
  rect(c, 6, 2, 4, 3, C.metal2);      // 때리는 머리
  rect(c, 6, 5, 4, 6, C.metal);       // 몸통
  rect(c, 7, 5, 1, 6, C.edge);        // 빛나는 결
  rect(c, 7, 11, 2, 3, C.edge);       // 뾰족한 날
  px(c, 8, 14, C.edge);
  rect(c, 4, 4, 2, 2, C.wood);        // 손잡이 감은 가죽
  rect(c, 10, 4, 2, 2, C.wood);
  px(c, 5, 3, C.white);               // 반짝임
  save('rock_wedge', outline(c), 2);
}

// ---- 샘물 표본 (16x16 -> 2배) ----
{
  const c = canvas(16, 16);
  rect(c, 7, 2, 2, 2, C.wood);        // 마개
  rect(c, 6, 4, 4, 2, C.ice);         // 병목
  rect(c, 4, 6, 8, 8, C.ice);         // 병
  rect(c, 5, 8, 6, 5, C.water);       // 온천물
  rect(c, 5, 8, 6, 1, C.foam);        // 수면
  px(c, 6, 10, C.white); px(c, 9, 11, C.foam);
  px(c, 5, 5, C.steam); px(c, 10, 4, C.steam);   // 피어오르는 김
  px(c, 3, 3, C.steam2);
  save('spring_water', outline(c), 2);
}

console.log('온천 아트 3장 생성');
