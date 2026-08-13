// 해변 채집 확장 + 레시피 아이콘 도트.
//
//   forage_ring.png   48x48 — 녹슨 금속 고리
//   forage_relic.png  48x48 — 무늬 새겨진 고대 돌조각 (희귀)
//   dish_coral_tea.png 32x32 — 산호빛 차 (숨겨진 레시피)
//   flower_pot.png    32x32 — 화분 레시피 아이콘 (상점 진열용)
//   trash_bin.png     32x32 — 쓰레기통 레시피 아이콘 (노점 진열용)
//
// 유저가 그림을 주면 같은 파일 이름으로 얹기만 하면 교체된다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_beach2.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

function make(w, h) { return new PNG({ width: w, height: h }); }
function px(p, x, y, c) {
  if (x < 0 || y < 0 || x >= p.width || y >= p.height) return;
  const k = (y * p.width + x) * 4;
  p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2]; p.data[k + 3] = 255;
}
function rect(p, x, y, w, h, c) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(p, x + i, y + j, c);
}
// 두꺼운 원 고리 (r0~r1 사이만 칠한다)
function ring(p, cx, cy, r0, r1, c) {
  for (let y = -r1; y <= r1; y++) for (let x = -r1; x <= r1; x++) {
    const d = Math.sqrt(x * x + y * y);
    if (d >= r0 && d <= r1) px(p, cx + x, cy + y, c);
  }
}

// ---- 금속 고리 ----
{
  const S = 48, p = make(S, S);
  const IRON = [138, 140, 148], DARK = [88, 90, 100], RUST = [150, 96, 58],
    LITE = [190, 192, 200];
  ring(p, 24, 26, 9, 14, IRON);
  ring(p, 24, 26, 12.5, 14, DARK);          // 바깥 테
  ring(p, 24, 26, 9, 10.5, DARK);           // 안쪽 테
  // 녹 얼룩 + 하이라이트
  rect(p, 30, 16, 6, 5, RUST); rect(p, 12, 30, 5, 6, RUST); rect(p, 26, 36, 6, 4, RUST);
  rect(p, 15, 17, 5, 4, LITE); rect(p, 13, 21, 3, 4, LITE);
  rect(p, 16, 42, 16, 2, [40, 44, 40]);     // 밑그늘
  fs.writeFileSync(OUT + 'forage_ring.png', PNG.sync.write(p));
  console.log('forage_ring.png 48x48');
}

// ---- 고대 조각 ----
{
  const S = 48, p = make(S, S);
  const STONE = [130, 124, 108], DK = [78, 74, 62], LT = [168, 162, 142],
    GLYPH = [86, 150, 140], GLOW = [140, 220, 205];
  // 비스듬히 깨진 판 모양
  const rows = [
    [14, 8, 20], [12, 12, 25], [10, 16, 28], [10, 20, 28],
    [11, 24, 26], [12, 28, 24], [14, 32, 20], [17, 36, 14],
  ];
  for (const [x, y, w] of rows) rect(p, x, y, w, 4, STONE);
  rect(p, 12, 12, 4, 20, LT);               // 왼쪽 빛
  rect(p, 32, 16, 5, 18, DK);               // 오른쪽 그늘
  // 새겨진 무늬 — 은은히 빛나는 소용돌이와 획
  rect(p, 19, 15, 8, 2, GLYPH); rect(p, 19, 15, 2, 6, GLYPH);
  rect(p, 19, 21, 6, 2, GLYPH); rect(p, 23, 21, 2, 4, GLYPH);
  rect(p, 21, 29, 8, 2, GLYPH); rect(p, 27, 25, 2, 6, GLYPH);
  px(p, 20, 16, GLOW); px(p, 24, 22, GLOW); px(p, 28, 26, GLOW);
  rect(p, 14, 40, 18, 2, [40, 44, 40]);     // 밑그늘
  fs.writeFileSync(OUT + 'forage_relic.png', PNG.sync.write(p));
  console.log('forage_relic.png 48x48');
}

// ---- 산호빛 차 ----
{
  const S = 32, p = make(S, S);
  const CUP = [236, 232, 222], CUP_D = [196, 190, 176], TEA = [244, 138, 122],
    TEA_L = [252, 190, 168], STEAM = [225, 235, 235], DK = [70, 60, 56];
  rect(p, 7, 14, 18, 10, CUP);              // 찻잔
  rect(p, 8, 22, 16, 2, CUP_D);
  rect(p, 6, 13, 20, 1, DK); rect(p, 6, 24, 20, 1, DK);
  rect(p, 6, 13, 1, 12, DK); rect(p, 25, 13, 1, 12, DK);
  rect(p, 26, 16, 3, 5, CUP); rect(p, 28, 17, 1, 3, DK);   // 손잡이
  rect(p, 9, 15, 14, 4, TEA);               // 노을빛 찻물
  rect(p, 10, 15, 5, 2, TEA_L);
  rect(p, 9, 26, 16, 2, CUP_D);             // 받침
  rect(p, 12, 6, 2, 4, STEAM); rect(p, 17, 4, 2, 5, STEAM);  // 김
  fs.writeFileSync(OUT + 'dish_coral_tea.png', PNG.sync.write(p));
  console.log('dish_coral_tea.png 32x32');
}

// ---- 화분 아이콘 ----
{
  const S = 32, p = make(S, S);
  const POT = [178, 108, 62], POT_D = [138, 80, 46], LEAF = [86, 168, 92],
    LEAF_L = [130, 205, 120], DK = [60, 42, 30];
  rect(p, 10, 17, 12, 10, POT);
  rect(p, 8, 15, 16, 3, POT_D);
  rect(p, 8, 14, 16, 1, DK); rect(p, 11, 27, 10, 1, DK);
  rect(p, 11, 19, 3, 6, [200, 132, 84]);
  rect(p, 14, 6, 4, 9, LEAF);               // 줄기
  rect(p, 9, 8, 6, 5, LEAF); rect(p, 17, 7, 6, 5, LEAF);
  rect(p, 10, 9, 3, 2, LEAF_L); rect(p, 18, 8, 3, 2, LEAF_L);
  fs.writeFileSync(OUT + 'flower_pot.png', PNG.sync.write(p));
  console.log('flower_pot.png 32x32');
}

// ---- 쓰레기통 아이콘 ----
{
  const S = 32, p = make(S, S);
  const BIN = [116, 130, 138], BIN_L = [156, 170, 176], BIN_D = [80, 92, 100],
    DK = [48, 56, 62];
  rect(p, 9, 10, 14, 16, BIN);
  rect(p, 11, 12, 3, 12, BIN_L);
  rect(p, 8, 13, 16, 2, BIN_D); rect(p, 8, 21, 16, 2, BIN_D);  // 금속 고리 두 줄
  rect(p, 7, 7, 18, 3, BIN_D);              // 뚜껑
  rect(p, 13, 5, 6, 2, DK);                 // 손잡이
  rect(p, 7, 6, 18, 1, DK); rect(p, 9, 26, 14, 1, DK);
  fs.writeFileSync(OUT + 'trash_bin.png', PNG.sync.write(p));
  console.log('trash_bin.png 32x32');
}
