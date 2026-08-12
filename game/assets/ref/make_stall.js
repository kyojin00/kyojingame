// 해변 노점(민지의 서브 퀘스트) + 해변 채집물/낚시용품 도트.
//
//   stall.png        96x84  — 줄무늬 차양 + 나무 계산대 노점
//   forage_trash.png 48x48  — 파도에 밀려온 젖은 쓰레기 봉지
//   forage_glass.png 48x48  — 매끈하게 닳은 유리 조각
//   bait.png         32x32  — 미끼 (지렁이 든 종이컵)
//
// 유저가 그림을 주면 같은 파일 이름으로 얹기만 하면 교체된다.
// 실행: 반드시 repo 루트에서  NODE_PATH=... node game/assets/ref/make_stall.js
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

function make(w, h) { return new PNG({ width: w, height: h }); }
function px(p, x, y, c) {
  if (x < 0 || y < 0 || x >= p.width || y >= p.height) return;
  const k = (y * p.width + x) * 4;
  p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2];
  p.data[k + 3] = c.length > 3 ? c[3] : 255;
}
function rect(p, x, y, w, h, c) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(p, x + i, y + j, c);
}

// ---- 노점 ----
{
  const W = 96, H = 84, p = make(W, H);
  const DK = [46, 30, 18], WOOD = [140, 95, 52], WOOD_D = [110, 72, 38],
    WOOD_L = [176, 128, 76], RED = [198, 62, 54], CREAM = [240, 230, 206],
    POLE = [96, 62, 34];
  // 기둥 두 개 (차양을 받친다)
  rect(p, 6, 16, 6, 56, POLE); rect(p, 84, 16, 6, 56, POLE);
  rect(p, 6, 16, 2, 56, WOOD_L); rect(p, 10, 16, 2, 56, DK);
  rect(p, 84, 16, 2, 56, WOOD_L); rect(p, 88, 16, 2, 56, DK);
  // 차양: 빨강/크림 세로 줄무늬 + 물결 끝단
  for (let x = 0; x < W; x++) {
    const stripe = Math.floor(x / 12) % 2 === 0;
    const c = stripe ? RED : CREAM;
    for (let y = 4; y < 20; y++) px(p, x, y, c);
    // 끝단 물결 (12px 주기 반원 느낌)
    const t = x % 12, dip = t < 2 || t > 9 ? 0 : (t < 4 || t > 7 ? 2 : 3);
    for (let y = 20; y < 20 + dip; y++) px(p, x, y, c);
    px(p, x, 20 + dip, DK);
    px(p, x, 3, DK);
  }
  // 계산대 (널빤지 상자)
  rect(p, 4, 46, 88, 26, WOOD);
  rect(p, 4, 46, 88, 2, DK);
  rect(p, 4, 46 + 2, 88, 5, WOOD_L);        // 윗면이 밝다
  rect(p, 4, 70, 88, 2, DK);
  rect(p, 4, 46, 2, 26, DK); rect(p, 90, 46, 2, 26, DK);
  for (const sx of [26, 48, 70]) rect(p, sx, 53, 2, 17, WOOD_D);  // 널 이음매
  rect(p, 4, 60, 88, 2, WOOD_D);
  // 진열: 조개(분홍) · 병(청록) · 상자(귤색)
  rect(p, 16, 40, 8, 6, [232, 168, 172]); rect(p, 18, 38, 4, 2, [232, 168, 172]);
  rect(p, 17, 41, 3, 2, [250, 214, 216]); rect(p, 15, 45, 10, 1, DK);
  rect(p, 42, 34, 6, 12, [96, 196, 196]); rect(p, 44, 31, 2, 3, [96, 196, 196]);
  rect(p, 43, 36, 2, 6, [190, 240, 238]); rect(p, 41, 45, 8, 1, DK);
  rect(p, 64, 38, 12, 8, [214, 140, 64]); rect(p, 64, 38, 12, 2, [236, 176, 104]);
  rect(p, 63, 45, 14, 1, DK);
  fs.writeFileSync(OUT + 'stall.png', PNG.sync.write(p));
  console.log('stall.png 96x84');
}

// ---- 젖은 쓰레기 ----
{
  const S = 48, p = make(S, S);
  const DK = [30, 34, 26], BAG = [86, 96, 74], BAG_L = [116, 128, 98],
    BAG_D = [62, 70, 52], BONE = [226, 222, 206], WET = [70, 92, 104, 120];
  // 젖은 모래 얼룩
  rect(p, 8, 40, 32, 4, WET);
  // 구겨진 봉지 (울퉁불퉁한 덩어리)
  rect(p, 12, 22, 24, 18, BAG);
  rect(p, 16, 16, 14, 8, BAG);
  rect(p, 10, 28, 4, 10, BAG); rect(p, 34, 26, 6, 12, BAG);
  rect(p, 17, 17, 5, 4, BAG_L); rect(p, 14, 24, 6, 5, BAG_L);
  rect(p, 26, 28, 8, 6, BAG_D); rect(p, 20, 34, 10, 5, BAG_D);
  // 묶인 매듭
  rect(p, 21, 13, 6, 4, BAG_D); rect(p, 22, 11, 4, 3, BAG);
  // 삐져나온 생선 가시
  rect(p, 33, 18, 10, 2, BONE); rect(p, 41, 15, 2, 8, BONE);
  rect(p, 36, 16, 2, 6, BONE); rect(p, 39, 16, 1, 6, BONE);
  // 테두리 (아래·옆 위주로 거칠게)
  rect(p, 11, 39, 26, 1, DK); rect(p, 10, 27, 1, 11, DK); rect(p, 39, 26, 1, 12, DK);
  fs.writeFileSync(OUT + 'forage_trash.png', PNG.sync.write(p));
  console.log('forage_trash.png 48x48');
}

// ---- 유리 조각 ----
{
  const S = 48, p = make(S, S);
  const DK = [24, 60, 66], GLASS = [110, 200, 202], GLASS_L = [188, 240, 238],
    GLASS_D = [70, 152, 158], WHITE = [240, 252, 250];
  // 비스듬한 조각 (닳아서 모서리가 둥글다)
  const shape = [
    [20, 12, 8], [17, 16, 15], [15, 20, 20], [14, 24, 22],
    [15, 28, 21], [17, 32, 17], [20, 36, 11],
  ];
  for (const [x, y, w] of shape) rect(p, x, y, w, 4, GLASS);
  rect(p, 18, 16, 6, 10, GLASS_L);                       // 윗면 반사
  rect(p, 26, 26, 8, 8, GLASS_D);                        // 아랫결 그늘
  rect(p, 22, 14, 3, 3, WHITE); rect(p, 30, 30, 2, 2, WHITE);  // 반짝임
  rect(p, 20, 40, 12, 1, DK);                            // 밑그늘
  fs.writeFileSync(OUT + 'forage_glass.png', PNG.sync.write(p));
  console.log('forage_glass.png 48x48');
}

// ---- 미끼 ----
{
  const S = 32, p = make(S, S);
  const DK = [52, 34, 24], CUP = [206, 186, 150], CUP_D = [170, 148, 112],
    DIRT = [116, 84, 52], WORM = [214, 118, 122], WORM_D = [166, 78, 88];
  // 종이컵 (흙이 담겨 있다)
  rect(p, 8, 14, 16, 12, CUP);
  rect(p, 9, 24, 14, 2, CUP_D);
  rect(p, 7, 12, 18, 3, CUP_D);
  rect(p, 7, 11, 18, 1, DK); rect(p, 8, 26, 16, 1, DK);
  rect(p, 7, 12, 1, 14, DK); rect(p, 24, 12, 1, 14, DK);
  rect(p, 9, 15, 14, 3, DIRT);                           // 흙
  // 지렁이 (구불구불 고개를 내밀었다)
  rect(p, 13, 8, 3, 8, WORM); rect(p, 16, 6, 3, 4, WORM);
  rect(p, 19, 8, 2, 3, WORM_D); rect(p, 13, 14, 6, 2, WORM_D);
  px(p, 17, 7, DK);                                       // 눈
  fs.writeFileSync(OUT + 'bait.png', PNG.sync.write(p));
  console.log('bait.png 32x32');
}
