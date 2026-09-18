// 자연 돌(곡괭이) 교체 — wkdusehf 원본(641x641, 투명 배경, 흙받침 포함)을
// **더 이상 쓰지 않는다.** 바위는 make_rocks.js 가 우리 도트 밀도(한 칸 =
// 원본 4px)로 새로 그린다. 이 스크립트를 돌리면 64x64 옛 그림이 덮어써져
// 바위만 다시 어긋난 해상도로 돌아간다. 기록으로만 남겨 둔다.
//
// 여백을 잘라내고 64x64 격자(기존 rock.png와 같은 규격)로 앉힌다.
// 원본은 ref/src/ref_rock.png 로 보관한다. 다시 갈면 이 스크립트만 돌리면 된다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/cut_rock.js
const fs = require('fs'), { PNG } = require('pngjs');
const SRC = __dirname + '/src/ref_rock.png';
const OUT = __dirname + '/../sprites/rock.png';
const im = PNG.sync.read(fs.readFileSync(SRC));

// 알파 있는 픽셀의 bbox
let x0 = im.width, y0 = im.height, x1 = 0, y1 = 0;
for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
  if (im.data[(y * im.width + x) * 4 + 3] < 40) continue;
  if (x < x0) x0 = x; if (x > x1) x1 = x;
  if (y < y0) y0 = y; if (y > y1) y1 = y;
}
const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
console.log('bbox', bw, 'x', bh);

// 64x64 안에 가로 맞춤 + 밑변 정렬 (흙받침이 바닥에 닿게)
const S = 64, scale = Math.min(S / bw, S / bh);
const dw = Math.round(bw * scale), dh = Math.round(bh * scale);
const ox = Math.floor((S - dw) / 2), oy = S - dh;
const out = new PNG({ width: S, height: S });
for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
  const sx = x0 + Math.min(bw - 1, Math.floor(x / scale));
  const sy = y0 + Math.min(bh - 1, Math.floor(y / scale));
  const sk = (sy * im.width + sx) * 4, dk = ((y + oy) * S + x + ox) * 4;
  if (im.data[sk + 3] < 40) continue;
  out.data[dk] = im.data[sk]; out.data[dk + 1] = im.data[sk + 1];
  out.data[dk + 2] = im.data[sk + 2]; out.data[dk + 3] = 255;
}
fs.writeFileSync(OUT, PNG.sync.write(out));
console.log('rock.png 64x64 완료');
