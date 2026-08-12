// 낡은 침대(src/ref_bed_old.png, 어두운 배경+글로우)를 실내용 스프라이트로.
//
// 배경이 투명이 아니라 「검은 바탕 + 침대 둘레 글로우」라서 밝기 문턱만으로는
// 못 자른다. 밝은 본체(bright)를 잡고, 가장자리에서 「본체가 아닌 칸」만
// 흘려 지우면(밖 flood) 침대의 어두운 외곽선과 안쪽 그림자는 살아남는다.
//
// 실행:  node cut_bed.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const p = PNG.sync.read(fs.readFileSync(__dirname + '/src/ref_bed_old.png'));
const W = p.width, H = p.height, d = p.data;
const maxc = (x, y) => { const k = (y * W + x) * 4; return Math.max(d[k], d[k + 1], d[k + 2]); };

// ① 밝은 본체
const bright = new Uint8Array(W * H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
  if (maxc(x, y) > 72) bright[y * W + x] = 1;

// ② 가장자리에서 「본체 아님」을 타고 번지는 바깥 영역
const outside = new Uint8Array(W * H);
const q = [];
for (let x = 0; x < W; x++) { q.push([x, 0], [x, H - 1]); }
for (let y = 0; y < H; y++) { q.push([0, y], [W - 1, y]); }
while (q.length) {
  const [x, y] = q.pop();
  if (x < 0 || y < 0 || x >= W || y >= H) continue;
  const i = y * W + x;
  if (outside[i] || bright[i]) continue;
  outside[i] = 1;
  q.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
}

// ③ 바깥은 투명, 남은 것(본체+외곽선+안쪽 그림자)의 상자를 잰다
let x0 = W, x1 = -1, y0 = H, y1 = -1;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = y * W + x;
  if (outside[i]) { d[i * 4 + 3] = 0; continue; }
  if (x < x0) x0 = x; if (x > x1) x1 = x;
  if (y < y0) y0 = y; if (y > y1) y1 = y;
}
const bw = x1 - x0 + 1, bh = y1 - y0 + 1;

// ④ 상자 축소 (평균) — 실내 침대 칸(69x99)의 두 배쯤이면 넉넉하다
const TW = 100;
const s = TW / bw, inv = 1 / s;
const ow = TW, oh = Math.round(bh * s);
const o = new PNG({ width: ow, height: oh });
o.data.fill(0);
for (let y = 0; y < oh; y++) for (let x = 0; x < ow; x++) {
  let r = 0, g = 0, b = 0, a = 0, n = 0;
  for (let j = Math.floor(y * inv); j < Math.floor((y + 1) * inv); j++)
    for (let i = Math.floor(x * inv); i < Math.floor((x + 1) * inv); i++) {
      const k = ((y0 + j) * W + x0 + i) * 4, al = d[k + 3] / 255;
      n++; r += d[k] * al; g += d[k + 1] * al; b += d[k + 2] * al; a += al;
    }
  if (!n || a / n < 0.4) continue;
  const k2 = (y * ow + x) * 4;
  o.data[k2] = r / a; o.data[k2 + 1] = g / a; o.data[k2 + 2] = b / a; o.data[k2 + 3] = 255;
}
fs.writeFileSync(__dirname + '/../sprites/bed_old.png', PNG.sync.write(o));
console.log('bed_old.png %dx%d (원본 상자 %dx%d)', ow, oh, bw, bh);
