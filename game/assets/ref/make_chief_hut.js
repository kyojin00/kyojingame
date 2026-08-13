// 이장의 거처 도트 — 낡은 오두막(초반)과 제대로 된 집(마을 성장 후).
//   chief_hut.png   72x62 — 판자 덧댄 작고 낡은 오두막
//   chief_house.png 112x92 — 마을 사람들이 지어 준 아담한 새 집
// 유저가 그림을 주면 같은 파일 이름으로 얹으면 교체된다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_chief_hut.js
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
const DK = [46, 32, 20];

// ---- 낡은 오두막 ----
{
  const W = 72, H = 62, p = make(W, H);
  const WALL = [122, 96, 62], WALL_D = [98, 76, 48], ROOF = [88, 74, 52],
    ROOF_D = [68, 56, 40], PATCH = [140, 118, 80];
  // 벽 (판자 — 군데군데 색이 바랬다)
  rect(p, 8, 26, 56, 32, WALL);
  for (let y = 30; y < 58; y += 7) rect(p, 8, y, 56, 1, WALL_D);
  rect(p, 12, 34, 8, 10, PATCH);          // 덧댄 판자
  rect(p, 50, 44, 10, 8, PATCH);
  rect(p, 8, 26, 1, 32, DK); rect(p, 63, 26, 1, 32, DK);
  rect(p, 8, 57, 56, 1, DK);
  // 삐뚜름한 초가 지붕
  for (let i = 0; i < 16; i++)
    rect(p, 6 + i * 2, 24 - i, 60 - i * 4, 2, i % 3 === 0 ? ROOF_D : ROOF);
  rect(p, 4, 24, 64, 3, ROOF_D);
  rect(p, 4, 23, 64, 1, DK);
  px(p, 34, 6, DK); px(p, 36, 6, DK);     // 지붕 위 이엉 삐죽
  // 문 + 작은 창
  rect(p, 30, 40, 12, 18, [74, 54, 34]);
  rect(p, 31, 41, 10, 16, [92, 66, 42]);
  px(p, 39, 49, [200, 180, 120]);          // 손잡이
  rect(p, 16, 36, 9, 8, [70, 90, 110]);    // 창 (희미한 불빛)
  rect(p, 17, 37, 7, 6, [150, 170, 150]);
  rect(p, 16, 36, 9, 1, DK); rect(p, 16, 43, 9, 1, DK);
  // 굴뚝 연기 자국
  rect(p, 52, 12, 4, 12, [90, 90, 96]); rect(p, 52, 11, 4, 1, DK);
  fs.writeFileSync(OUT + 'chief_hut.png', PNG.sync.write(p));
  console.log('chief_hut.png 72x62');
}

// ---- 제대로 된 이장 집 ----
{
  const W = 112, H = 92, p = make(W, H);
  const WALL = [214, 196, 164], WALL_D = [186, 168, 138], ROOF = [164, 82, 66],
    ROOF_D = [126, 62, 50], TRIM = [110, 80, 50];
  // 벽 (밝은 회벽 + 목재 테)
  rect(p, 10, 40, 92, 46, WALL);
  rect(p, 10, 40, 92, 4, WALL_D);
  rect(p, 10, 40, 2, 46, TRIM); rect(p, 100, 40, 2, 46, TRIM);
  rect(p, 10, 84, 92, 2, DK);
  // 기와 지붕
  for (let i = 0; i < 20; i++)
    rect(p, 8 + i * 2, 38 - i, 96 - i * 4, 2, i % 2 === 0 ? ROOF : ROOF_D);
  rect(p, 6, 38, 100, 4, ROOF_D);
  rect(p, 6, 37, 100, 1, DK);
  // 굴뚝
  rect(p, 82, 10, 8, 16, [120, 120, 128]); rect(p, 81, 9, 10, 2, DK);
  // 문 (가운데) + 창 두 개 + 화분
  rect(p, 48, 60, 16, 26, [96, 66, 40]);
  rect(p, 49, 61, 14, 24, [122, 86, 52]);
  px(p, 60, 73, [220, 190, 120]);
  for (const wx of [20, 78]) {
    rect(p, wx, 56, 14, 12, [92, 128, 150]);
    rect(p, wx + 1, 57, 12, 10, [180, 210, 220]);
    rect(p, wx + 6, 57, 2, 10, TRIM); rect(p, wx, 61, 14, 1, TRIM);
    rect(p, wx - 1, 68, 16, 3, TRIM);                     // 창턱
    rect(p, wx + 2, 66, 3, 2, [200, 90, 90]);             // 창가 화분 꽃
    rect(p, wx + 9, 66, 3, 2, [230, 200, 90]);
  }
  // 문패
  rect(p, 40, 50, 32, 6, [150, 120, 80]); rect(p, 40, 50, 32, 1, DK);
  fs.writeFileSync(OUT + 'chief_house.png', PNG.sync.write(p));
  console.log('chief_house.png 112x92');
}
