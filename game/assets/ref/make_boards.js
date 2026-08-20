// 마을 게시판 두 종 — 서로 다른 디자인, 예전 팻말(64x64)보다 크게.
//
//   board_quest.png  (176x128) 의뢰 게시판 — 다리 둘 달린 큰 코르크 게시판.
//                    종이 쪽지가 압정으로 붙어 있다. (마을 광장, E: 의뢰)
//   board_unlock.png (144x136) 집터·구역 해금 게시판 — 지붕 얹은 안내판.
//                    파란 현판에 금색 장식. (집터/온실 터 같은 「열리는 자리」)
//
// 나중에 손그림을 받으면 **같은 파일 이름으로 저장**만 하면 게임에 그대로
// 적용된다 (cut_icon.js처럼 잘라 앉히면 된다). 코드는 파일 이름만 본다.
//
// 실행:  node make_boards.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

function img(w, h) {
  const p = new PNG({ width: w, height: h });
  p.data.fill(0);
  return p;
}

// 2px 도트 (도트 격자 기준 좌표)
function dot(p, x, y, c) {
  for (let j = 0; j < 2; j++) for (let i = 0; i < 2; i++) {
    const px = x * 2 + i, py = y * 2 + j;
    if (px < 0 || py < 0 || px >= p.width || py >= p.height) continue;
    const k = (py * p.width + px) * 4;
    p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2];
    p.data[k + 3] = c[3] === undefined ? 255 : c[3];
  }
}

function rect(p, x0, y0, w, h, c) {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) dot(p, x, y, c);
}

// 윤곽선 — 마을의 모든 것이 어두운 따뜻한 선으로 둘려 있는데 게시판만
// 맨살이라 바닥 위에 떠 보였다. 도트 격자에서 몸에 붙은 빈 칸을 두른다
// (반투명 발밑 그림자에는 안 두른다 — 그림자에 테가 지면 웅덩이가 된다)
const LINE = [44, 34, 28];
function outline(p) {
  const gw = p.width / 2, gh = p.height / 2;
  const alphaAt = (x, y) => (x < 0 || y < 0 || x >= gw || y >= gh)
    ? 0 : p.data[((y * 2) * p.width + x * 2) * 4 + 3];
  const add = [];
  for (let y = 0; y < gh; y++) for (let x = 0; x < gw; x++) {
    if (alphaAt(x, y) !== 0) continue;
    for (const [ax, ay] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      if (alphaAt(x + ax, y + ay) >= 200) { add.push([x, y]); break; }
  }
  for (const [x, y] of add) dot(p, x, y, LINE);
}

// ---- 의뢰 게시판: 다리 둘 + 넓은 코르크판 + 종이 쪽지 ----
{
  const p = img(176, 128);                       // 도트 격자 88x64
  const WOOD = [122, 82, 46], WOOD_D = [92, 60, 32], WOOD_L = [150, 106, 62];
  const CORK = [196, 158, 108], CORK_D = [176, 140, 92];
  const PAPER = [244, 240, 226], PAPER_Y = [240, 226, 160], PIN = [200, 70, 60];
  const SHADOW = [70, 60, 50, 90];
  // 다리 (판 뒤에서 내려온다)
  rect(p, 12, 34, 5, 26, WOOD_D);
  rect(p, 71, 34, 5, 26, WOOD_D);
  rect(p, 12, 34, 2, 26, WOOD);                  // 다리 하이라이트
  rect(p, 71, 34, 2, 26, WOOD);
  // 판 틀
  rect(p, 4, 6, 80, 40, WOOD);
  rect(p, 4, 6, 80, 3, WOOD_L);                  // 윗틀
  rect(p, 4, 43, 80, 3, WOOD_D);                 // 아랫틀
  rect(p, 4, 6, 3, 40, WOOD_D);
  rect(p, 81, 6, 3, 40, WOOD_D);
  // 코르크 속
  rect(p, 8, 10, 72, 32, CORK);
  for (let i = 0; i < 90; i++) {                 // 코르크 얼룩
    const x = 8 + (i * 13) % 72, y = 10 + (i * 7) % 32;
    if ((x * 31 + y * 17) % 5 < 2) dot(p, x, y, CORK_D);
  }
  // 종이 쪽지 셋 (흰 둘 + 누런 하나) + 압정
  rect(p, 14, 14, 14, 18, PAPER);
  rect(p, 34, 16, 18, 14, PAPER_Y);
  rect(p, 58, 13, 15, 20, PAPER);
  // 쪽지의 글줄
  const INK = [110, 100, 96];
  for (const [x0, y0, w, n] of [[16, 18, 10, 4], [36, 19, 14, 3], [60, 17, 11, 5]])
    for (let l = 0; l < n; l++) rect(p, x0, y0 + l * 3, w - (l % 2) * 3, 1, INK);
  for (const [x, y] of [[20, 14], [42, 16], [65, 13]]) dot(p, x, y, PIN);
  // 지붕 널 (비 가림)
  rect(p, 2, 2, 84, 4, WOOD_D);
  rect(p, 2, 2, 84, 2, WOOD_L);
  outline(p);
  // 발밑 그림자 — 윤곽선 뒤에 (그림자에 테가 지면 웅덩이가 된다)
  rect(p, 8, 60, 74, 2, SHADOW);
  fs.writeFileSync(OUT + 'board_quest.png', PNG.sync.write(p));
  console.log('board_quest.png 176x128');
}

// ---- 집터·구역 해금 게시판: 외기둥 + 박공지붕 + 파란 현판 ----
{
  const p = img(144, 136);                       // 도트 격자 72x68
  const WOOD = [122, 82, 46], WOOD_D = [92, 60, 32], WOOD_L = [150, 106, 62];
  const BLUE = [58, 92, 138], BLUE_D = [42, 68, 104], BLUE_L = [96, 132, 176];
  const GOLD = [222, 178, 84], PAPER = [244, 240, 226];
  const SHADOW = [70, 60, 50, 90];
  // 기둥 하나 (가운데)
  rect(p, 33, 30, 6, 32, WOOD);
  rect(p, 33, 30, 2, 32, WOOD_L);
  rect(p, 37, 30, 2, 32, WOOD_D);
  // 박공지붕 (계단식 삼각)
  for (let i = 0; i < 7; i++)
    rect(p, 10 + i * 2, 8 - i, 52 - i * 4, 2, i % 2 ? WOOD_D : WOOD);
  rect(p, 8, 9, 56, 2, WOOD_D);
  // 현판 (파란 바탕 + 금테)
  rect(p, 14, 12, 44, 22, GOLD);
  rect(p, 16, 14, 40, 18, BLUE);
  rect(p, 16, 14, 40, 2, BLUE_L);
  rect(p, 16, 30, 40, 2, BLUE_D);
  // 금색 장식 무늬 (마름모 + 글줄 자리)
  for (const [x, y] of [[20, 22], [52, 22]]) {
    dot(p, x, y, GOLD); dot(p, x + 1, y - 1, GOLD);
    dot(p, x + 1, y + 1, GOLD); dot(p, x + 2, y, GOLD);
  }
  rect(p, 27, 19, 18, 2, GOLD);
  rect(p, 29, 24, 14, 2, GOLD);
  // 기둥에 붙은 작은 안내 쪽지
  rect(p, 30, 38, 12, 10, PAPER);
  rect(p, 32, 41, 8, 1, [110, 100, 96]);
  rect(p, 32, 44, 6, 1, [110, 100, 96]);
  outline(p);
  // 발밑 그림자 — 윤곽선 뒤에
  rect(p, 22, 62, 28, 2, SHADOW);
  fs.writeFileSync(OUT + 'board_unlock.png', PNG.sync.write(p));
  console.log('board_unlock.png 144x136');
}
