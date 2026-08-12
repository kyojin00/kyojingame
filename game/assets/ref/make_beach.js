// 해변 채집물 스프라이트 — 조개(forage_shell)·산호(forage_coral), 64x64.
//
// 다른 채집물(forage_berry 등)과 같은 규격이다. 2px 굵기의 도트로 그려
// 절반 축소로 그려지는 게임 화면에서 1px 도트 밀도가 맞는다.
//
// 실행:  node make_beach.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';

function img() {
  const p = new PNG({ width: 64, height: 64 });
  p.data.fill(0);
  return p;
}

// 2px 도트 하나 (x, y는 32x32 도트 격자 기준)
function dot(p, x, y, c) {
  for (let j = 0; j < 2; j++) for (let i = 0; i < 2; i++) {
    const px = x * 2 + i, py = y * 2 + j;
    if (px < 0 || py < 0 || px >= 64 || py >= 64) continue;
    const k = (py * 64 + px) * 4;
    p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2]; p.data[k + 3] = c[3] === undefined ? 255 : c[3];
  }
}

// ---- 조개: 부채꼴 가리비 — 크림색 몸에 갈래 줄, 아래 그림자 ----
{
  const p = img();
  const CREAM = [236, 214, 178], PINK = [224, 168, 150], DARK = [168, 118, 96];
  const RIDGE = [204, 172, 136], SHADOW = [70, 60, 50, 90];
  // 몸통: 위가 넓은 부채꼴 (행마다 폭이 줄어든다)
  const rows = [
    [9, 22], [8, 23], [8, 23], [8, 23], [9, 22], [9, 22],
    [10, 21], [11, 20], [12, 19], [13, 18], [14, 17],
  ];
  const y0 = 12;
  rows.forEach(([x0, x1], i) => {
    for (let x = x0; x <= x1; x++) {
      // 갈래 줄: 부챗살 위치는 아래 꼭짓점에서 뻗는 각으로 잡는다
      const t = (x - 15.5) / (x1 - x0 + 1);
      const ridge = [0.42, 0.21, 0.0, -0.21, -0.42].some(a => Math.abs(t - a) < 0.045);
      dot(p, x, y0 + i, ridge ? RIDGE : (i < 2 ? PINK : CREAM));
    }
  });
  // 꼭지 (아래 이음매)
  dot(p, 15, y0 + 11, DARK); dot(p, 16, y0 + 11, DARK);
  dot(p, 14, y0 + 11, PINK); dot(p, 17, y0 + 11, PINK);
  // 윗변 테두리를 분홍으로 한 줄
  for (let x = 9; x <= 22; x++) dot(p, x, y0, PINK);
  // 그림자
  for (let x = 11; x <= 21; x++) dot(p, x, y0 + 12, [...SHADOW]);
  fs.writeFileSync(OUT + 'forage_shell.png', PNG.sync.write(p));
  console.log('forage_shell.png');
}

// ---- 산호: 주황 가지 셋이 위로 뻗는다 ----
{
  const p = img();
  const ORANGE = [232, 122, 74], LIGHT = [244, 158, 108], DARK = [178, 82, 48];
  const SHADOW = [70, 60, 50, 90];
  const trunk = [
    // 가운데 줄기
    [15, 24], [15, 23], [15, 22], [16, 21], [16, 20], [16, 19], [16, 18],
    [16, 17], [16, 16], [16, 15], [16, 14],
    // 왼 가지
    [14, 21], [13, 20], [12, 19], [12, 18], [11, 17], [11, 16],
    // 오른 가지
    [17, 20], [18, 19], [19, 18], [19, 17], [20, 16], [20, 15],
    // 잔가지
    [13, 15], [13, 14], [21, 13], [21, 14], [15, 12], [15, 13],
  ];
  trunk.forEach(([x, y]) => {
    dot(p, x, y, ORANGE);
    dot(p, x + 1, y, ORANGE);
  });
  // 밝은 결 + 끝눈
  [[16, 14], [11, 16], [20, 15], [13, 14], [21, 13], [15, 12]].forEach(([x, y]) => {
    dot(p, x, y, LIGHT); dot(p, x + 1, y, LIGHT);
  });
  [[15, 24], [16, 24]].forEach(([x, y]) => dot(p, x, y, DARK));
  dot(p, 17, 24, DARK);
  // 그림자
  for (let x = 12; x <= 20; x++) dot(p, x, 25, [...SHADOW]);
  fs.writeFileSync(OUT + 'forage_coral.png', PNG.sync.write(p));
  console.log('forage_coral.png');
}
