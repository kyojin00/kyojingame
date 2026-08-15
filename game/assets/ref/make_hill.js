// 옛 전망대 아트 (메인 스토리 18) — 세 장.
//   old_lookout   무너져 가는 나무 전망대 (64x96 세계 오브젝트)
//   old_bench     비바람에 삭은 나무 의자 (64x64)
//   carved_stone  글씨가 새겨진 납작한 돌 (64x64)
// 굽은 나무는 기존 tree_bare 그림을 그대로 쓴다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_hill.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

const C = {
  line:  [42, 28, 24],
  wood:  [122, 92, 58], wood2: [94, 68, 42], wood3: [148, 114, 74],
  rot:   [78, 62, 44],  moss:  [96, 128, 68], moss2: [72, 102, 54],
  rock:  [128, 120, 118], rock2: [96, 90, 90], rock3: [162, 154, 150],
  carve: [64, 54, 50],  shine: [232, 226, 210],
  grass: [92, 138, 70], grass2: [70, 112, 56],
};

function canvas(w, h) { return Array.from({ length: h }, () => new Array(w).fill(null)); }
function px(c, x, y, col) { if (c[y] && x >= 0 && x < c[0].length && col) c[y][x] = col; }
function rect(c, x, y, w, h, col) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col);
}
function outline(c) {
  const h = c.length, w = c[0].length;
  const out = c.map(r => r.slice());
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (c[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
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

// ---- 옛 전망대 (32x48 -> 2배 = 64x96) ----
// 언덕 끝에 선 낡은 나무 발판. 기둥 넷이 기울고 난간 한쪽이 무너졌다.
{
  const c = canvas(32, 48);
  // 발판 아래 기둥 네 개 (오른쪽 기둥은 삭아 짧다)
  rect(c, 7, 30, 3, 15, C.wood2);
  rect(c, 13, 30, 3, 16, C.wood);
  rect(c, 19, 30, 3, 16, C.wood2);
  rect(c, 25, 33, 3, 12, C.rot);      // 주저앉은 기둥
  // 기둥을 묶은 가로대
  rect(c, 7, 38, 21, 1, C.wood2);
  rect(c, 7, 43, 15, 1, C.rot);
  // 발판
  rect(c, 4, 26, 25, 4, C.wood);
  rect(c, 4, 29, 25, 1, C.wood2);
  for (let x = 5; x < 29; x += 3) rect(c, x, 26, 1, 3, C.wood2);   // 널판 이음매
  rect(c, 24, 26, 5, 2, C.rot);       // 오른쪽 끝은 내려앉았다
  // 난간 — 왼쪽은 남고 오른쪽은 부러졌다
  rect(c, 5, 16, 2, 10, C.wood3);
  rect(c, 12, 18, 2, 8, C.wood3);
  rect(c, 5, 18, 12, 2, C.wood);      // 가로 난간
  rect(c, 5, 23, 9, 1, C.wood2);
  rect(c, 19, 21, 2, 5, C.rot);       // 부러진 기둥 밑동
  px(c, 21, 20, C.rot); px(c, 22, 21, C.rot);
  // 이끼 — 오래 비어 있었다는 표시
  px(c, 8, 44, C.moss); px(c, 9, 45, C.moss2);
  px(c, 14, 45, C.moss); px(c, 20, 44, C.moss2);
  px(c, 4, 28, C.moss); px(c, 27, 28, C.moss2);
  px(c, 6, 21, C.moss);
  // 밑동 둘레 풀
  rect(c, 5, 45, 4, 2, C.grass);
  rect(c, 17, 45, 5, 2, C.grass2);
  rect(c, 24, 44, 5, 2, C.grass);
  save('old_lookout', outline(c), 2);
}

// ---- 무너진 나무 의자 (32x32 -> 2배) ----
{
  const c = canvas(32, 32);
  rect(c, 5, 20, 22, 3, C.wood);       // 앉는 판
  rect(c, 5, 22, 22, 1, C.wood2);
  rect(c, 20, 20, 7, 3, C.rot);        // 오른쪽 끝은 썩어 내려앉았다
  rect(c, 7, 23, 2, 6, C.wood2);       // 다리
  rect(c, 23, 23, 2, 5, C.rot);
  rect(c, 6, 12, 2, 8, C.wood3);       // 등받이 기둥
  rect(c, 22, 13, 2, 7, C.wood3);
  rect(c, 6, 13, 18, 2, C.wood);       // 등받이 가로대
  rect(c, 6, 17, 15, 2, C.wood2);      // 두 사람이 기댔던 자리 — 닳아 얇다
  px(c, 12, 17, C.rot); px(c, 16, 18, C.rot);
  px(c, 8, 22, C.moss); px(c, 18, 21, C.moss2);   // 이끼
  px(c, 24, 19, C.moss);
  rect(c, 4, 28, 5, 2, C.grass);       // 발밑 풀
  rect(c, 22, 27, 6, 2, C.grass2);
  save('old_bench', outline(c), 2);
}

// ---- 글씨가 새겨진 돌 (32x32 -> 2배) ----
{
  const c = canvas(32, 32);
  rect(c, 6, 16, 20, 10, C.rock);      // 납작한 돌
  rect(c, 8, 14, 16, 2, C.rock3);      // 볕 드는 윗면
  rect(c, 6, 24, 20, 2, C.rock2);      // 그늘진 밑동
  px(c, 5, 20, C.rock2); px(c, 26, 19, C.rock2);
  // 나란히 새긴 두 글자 — 왼쪽은 반듯하고 오른쪽은 삐뚤다
  rect(c, 10, 18, 1, 5, C.carve);
  rect(c, 10, 18, 4, 1, C.carve);
  rect(c, 10, 20, 3, 1, C.carve);
  px(c, 18, 18, C.carve); px(c, 19, 19, C.carve); px(c, 18, 20, C.carve);
  px(c, 19, 21, C.carve); px(c, 20, 19, C.carve); px(c, 17, 22, C.carve);
  px(c, 15, 20, C.carve);              // 가운데 새긴 점
  px(c, 9, 15, C.shine); px(c, 22, 15, C.shine);   // 빛 반사
  px(c, 7, 23, C.moss); px(c, 24, 22, C.moss2);    // 이끼
  rect(c, 5, 25, 5, 2, C.grass);       // 둘레 풀
  rect(c, 22, 25, 6, 2, C.grass2);
  save('carved_stone', outline(c), 2);
}

console.log('옛 전망대 아트 3장 생성');
