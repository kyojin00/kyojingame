// 민들레 그림 자르기 — 유저가 그린 도트를 게임 규격 두 장으로 만든다.
//
//   ref/src/ref_dandelion.png       -> sprites/forage_dandelion.png       (64x64, 필드 오브젝트)
//   ref/src/ref_dandelion_icon.png  -> sprites/icon_forage_dandelion.png  (32x32, 가방 아이콘)
//
// 아이콘 원본이 아직 없으면 필드 그림을 줄여 임시로 쓴다 —
// 나중에 ref_dandelion_icon.png만 넣고 이 스크립트를 다시 돌리면 교체된다.
// 원본 배경이 흰색이라 **흰 바탕은 투명으로 뽑아낸다** (알파가 없는 그림 대비).
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/cut_dandelion.js
const fs = require('fs'), { PNG } = require('pngjs');
const SRC = __dirname + '/src/';
const OUT = __dirname + '/../sprites/';

// 배경(흰색)인가 — 알파가 있으면 알파를 믿는다
function bg(d, k) {
  if (d[k + 3] < 40) return true;
  return d[k] > 238 && d[k + 1] > 238 && d[k + 2] > 238;
}

function cut(srcFile, outFile, size) {
  const im = PNG.sync.read(fs.readFileSync(srcFile));
  let x0 = im.width, y0 = im.height, x1 = 0, y1 = 0;
  for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
    if (bg(im.data, (y * im.width + x) * 4)) continue;
    if (x < x0) x0 = x; if (x > x1) x1 = x;
    if (y < y0) y0 = y; if (y > y1) y1 = y;
  }
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  const scale = Math.min(size / bw, size / bh);
  const dw = Math.round(bw * scale), dh = Math.round(bh * scale);
  const ox = Math.floor((size - dw) / 2);
  const oy = size - dh;                  // 밑을 바닥에 붙인다 (풀은 땅에서 자란다)
  const out = new PNG({ width: size, height: size });
  for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
    const sx = x0 + Math.min(bw - 1, Math.floor(x / scale));
    const sy = y0 + Math.min(bh - 1, Math.floor(y / scale));
    const sk = (sy * im.width + sx) * 4, dk = ((y + oy) * size + x + ox) * 4;
    if (bg(im.data, sk)) continue;
    out.data[dk] = im.data[sk]; out.data[dk + 1] = im.data[sk + 1];
    out.data[dk + 2] = im.data[sk + 2]; out.data[dk + 3] = 255;
  }
  fs.writeFileSync(outFile, PNG.sync.write(out));
  console.log(outFile.split('/').pop(), size + 'x' + size, '완료 (bbox', bw, 'x', bh, ')');
}

cut(SRC + 'ref_dandelion.png', OUT + 'forage_dandelion.png', 64);
const iconSrc = fs.existsSync(SRC + 'ref_dandelion_icon.png')
  ? SRC + 'ref_dandelion_icon.png' : SRC + 'ref_dandelion.png';
cut(iconSrc, OUT + 'icon_forage_dandelion.png', 32);
