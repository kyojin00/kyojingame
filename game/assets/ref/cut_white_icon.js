// 흰(또는 투명) 배경 일러스트를 아이콘 규격으로 앉힌다 — 가장자리에서
// 「거의 흰 색」만 흘려 지우므로 그림 안쪽의 흰 하이라이트는 살아남는다.
// 표에 한 줄 적으면 된다.  실행:  node cut_white_icon.js   (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const SRC = __dirname + '/src/', OUT = __dirname + '/../sprites/';

// [원본, 저장 이름, 폭(px), 높이(px)] — 높이를 생략하면 정사각
const JOBS = [
  ['ref_icon_rod.png', 'icon_rod', 32],        // 간이낚싯대
  ['ref_deco_fountain.png', 'deco_fountain', 128, 160],  // 광장 분수대
  ['ref_fence.png', 'fence', 64, 64],          // 나무 울타리 (한 칸)
  ['ref_kitchen.png', 'kitchen_counter', 384, 256],  // 집 안 조리대 (발견 후)
];

for (const [src, out, SW, SH0] of JOBS) {
  const SH = SH0 || SW;
  const p = PNG.sync.read(fs.readFileSync(SRC + src));
  const W = p.width, H = p.height, d = p.data;
  const white = (x, y) => {
    const k = (y * W + x) * 4;
    return d[k] > 228 && d[k + 1] > 228 && d[k + 2] > 228;
  };
  const outb = new Uint8Array(W * H);
  const q = [];
  for (let x = 0; x < W; x++) q.push([x, 0], [x, H - 1]);
  for (let y = 0; y < H; y++) q.push([0, y], [W - 1, y]);
  while (q.length) {
    const [x, y] = q.pop();
    if (x < 0 || y < 0 || x >= W || y >= H) continue;
    const i = y * W + x;
    if (outb[i] || !white(x, y)) continue;
    outb[i] = 1;
    q.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
  }
  let x0 = W, x1 = -1, y0 = H, y1 = -1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    if (outb[i] || d[i * 4 + 3] < 60) { d[i * 4 + 3] = 0; continue; }
    if (x < x0) x0 = x; if (x > x1) x1 = x;
    if (y < y0) y0 = y; if (y > y1) y1 = y;
  }
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  const s = Math.min((SW - 2) / bw, (SH - 2) / bh), inv = 1 / s;
  const ow = Math.round(bw * s), oh = Math.round(bh * s);
  const ox = (SW - ow) >> 1, oy = SH - oh - 1;   // 밑변을 바닥에 붙인다
  const o = new PNG({ width: SW, height: SH });
  o.data.fill(0);
  for (let y = 0; y < oh; y++) for (let x = 0; x < ow; x++) {
    let r = 0, g = 0, b = 0, a = 0, n = 0;
    for (let j = Math.floor(y * inv); j < Math.floor((y + 1) * inv); j++)
      for (let i = Math.floor(x * inv); i < Math.floor((x + 1) * inv); i++) {
        const k = ((y0 + j) * W + x0 + i) * 4, al = d[k + 3] / 255;
        n++; r += d[k] * al; g += d[k + 1] * al; b += d[k + 2] * al; a += al;
      }
    if (!n || a / n < 0.35) continue;
    const k2 = ((oy + y) * SW + ox + x) * 4;
    o.data[k2] = r / a; o.data[k2 + 1] = g / a; o.data[k2 + 2] = b / a; o.data[k2 + 3] = 255;
  }
  fs.writeFileSync(OUT + out + '.png', PNG.sync.write(o));
  console.log('%s -> %s.png (%dx%d, 상자 %dx%d)', src, out, SW, SH, bw, bh);
}
