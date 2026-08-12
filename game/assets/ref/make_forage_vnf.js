// 들판 채집물(산딸기·약초)을 vnf 풀숲(weed_plant.png)을 바탕으로 다시 만든다.
//
//   forage_berry — vnf 풀숲 + 빨간 산딸기 송이
//   forage_herb  — vnf 풀숲을 청록빛으로 물들이고 흰 꽃을 얹은 약초
//
// weed_plant.png(64x64, cut_icon.js가 vnf 원본에서 앉힌 것)을 읽으므로
// vnf 그림을 갈면 이 스크립트만 다시 돌리면 셋이 같은 결로 맞춰진다.
//
// 실행:  node make_forage_vnf.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const base = PNG.sync.read(fs.readFileSync(OUT + 'weed_plant.png'));
const W = base.width, H = base.height;

function clone() {
  const p = new PNG({ width: W, height: H });
  base.data.copy(p.data);
  return p;
}

// 2x2 점 하나
function dot(p, x, y, c) {
  for (let j = 0; j < 2; j++) for (let i = 0; i < 2; i++) {
    const px = x + i, py = y + j;
    if (px < 0 || py < 0 || px >= W || py >= H) continue;
    const k = (py * W + px) * 4;
    p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2]; p.data[k + 3] = 255;
  }
}

// 열매 송이: 4x4 몸통 + 밝은 점
function berry(p, x, y) {
  const R = [196, 44, 52], D = [140, 26, 36], L = [240, 120, 110];
  for (let j = 0; j < 4; j++) for (let i = 0; i < 4; i++) {
    if ((i === 0 || i === 3) && (j === 0 || j === 3)) continue;  // 모서리 깎기
    const k = ((y + j) * W + x + i) * 4;
    if (x + i >= W || y + j >= H) continue;
    const c = (j >= 2) ? D : R;
    p.data[k] = c[0]; p.data[k + 1] = c[1]; p.data[k + 2] = c[2]; p.data[k + 3] = 255;
  }
  const k2 = ((y + 1) * W + x + 1) * 4;
  p.data[k2] = L[0]; p.data[k2 + 1] = L[1]; p.data[k2 + 2] = L[2];
}

// ---- 산딸기 풀숲 ----
{
  const p = clone();
  [[18, 30], [34, 22], [44, 34], [26, 42], [38, 46]].forEach(([x, y]) => berry(p, x, y));
  fs.writeFileSync(OUT + 'forage_berry.png', PNG.sync.write(p));
  console.log('forage_berry.png (vnf + 열매)');
}

// ---- 약초 풀숲 (청록빛 + 흰 꽃) ----
{
  const p = clone();
  for (let i = 0; i < W * H; i++) {
    const k = i * 4;
    if (p.data[k + 3] === 0) continue;
    // 초록 -> 청록: 빨강을 줄이고 파랑을 키운다
    p.data[k] = Math.round(p.data[k] * 0.62);
    p.data[k + 2] = Math.min(255, Math.round(p.data[k + 2] * 1.1 + 46));
  }
  const FLOWER = [244, 244, 236], CORE = [240, 210, 90];
  [[22, 24], [40, 28], [30, 40]].forEach(([x, y]) => {
    dot(p, x - 2, y, FLOWER); dot(p, x + 2, y, FLOWER);
    dot(p, x, y - 2, FLOWER); dot(p, x, y + 2, FLOWER);
    dot(p, x, y, CORE);
  });
  fs.writeFileSync(OUT + 'forage_herb.png', PNG.sync.write(p));
  console.log('forage_herb.png (vnf 청록 + 꽃)');
}
