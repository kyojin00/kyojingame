// 올려 준 일러스트(1536x1024 투명 PNG)를 아이템 아이콘 규격으로 앉힌다.
//
// 실루엣만 남기고 목표 크기에 꽉 채워 박스 축소한다. 원본은 src/에 두고
// 표에 한 줄 적으면 된다. 같은 이름으로 저장하므로 코드는 손댈 게 없다.
//
// 실행:  node cut_icon.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const SRC = __dirname + '/src/';
const OUT = __dirname + '/../sprites/';

// [원본, 저장 이름, 한 변(px)]
const JOBS = [
  ['ref_icon_corn.png', 'mature_corn', 64],
  ['ref_icon_omurice.png', 'dish_omurice', 32],
  ['ref_icon_stone.png', 'icon_stone', 32],
  ['ref_icon_fried_egg.png', 'dish_fried_egg', 32],
  ['ref_icon_weed.png', 'weed', 64],           // 잡초 — 주웠을 때(묶음)
  ['ref_icon_weed_plant.png', 'weed_plant', 64], // 잡초 — 자연에 서 있는 풀숲
  ['ref_icon_pickaxe.png', 'icon_pickaxe', 32],  // 첫(나무) 곡괭이
];

for (const [src, out, size] of JOBS) {
  const p = PNG.sync.read(fs.readFileSync(SRC + src));
  const { width: W, height: H, data: d } = p;
  let x0 = W, x1 = -1, y0 = H, y1 = -1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
    if (d[(y * W + x) * 4 + 3] > 60) {
      if (x < x0) x0 = x; if (x > x1) x1 = x;
      if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  const T = size - 2;                       // 한 변 여백 1px
  const s = Math.min(T / bw, T / bh), inv = 1 / s;
  const ow = Math.round(bw * s), oh = Math.round(bh * s);
  const ox = (size - ow) >> 1, oy = (size - oh) >> 1;
  const o = new PNG({ width: size, height: size });
  o.data.fill(0);
  for (let y = 0; y < oh; y++) for (let x = 0; x < ow; x++) {
    let r = 0, g = 0, b = 0, a = 0, n = 0;
    for (let j = Math.floor(y * inv); j < Math.floor((y + 1) * inv); j++)
      for (let i = Math.floor(x * inv); i < Math.floor((x + 1) * inv); i++) {
        const q = ((y0 + j) * W + x0 + i) * 4, al = d[q + 3] / 255;
        n++; r += d[q] * al; g += d[q + 1] * al; b += d[q + 2] * al; a += al;
      }
    if (!n || a / n < 0.35) continue;
    const k = ((oy + y) * size + ox + x) * 4;
    o.data[k] = r / a; o.data[k + 1] = g / a; o.data[k + 2] = b / a; o.data[k + 3] = 255;
  }
  fs.writeFileSync(OUT + out + '.png', PNG.sync.write(o));
  console.log('%s -> %s.png (%dpx)', src, out, size);
}
