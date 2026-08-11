// 손그림 건물(src/ref_house.png · src/ref_shop.png)을 게임 규격으로 앉힌다.
//
// 원본은 1536x1024짜리 잘라낸 그림이고, 게임이 쓰는 자리는 512x410이다
// (docs/building_art.md). 크기만 줄이면 문이 문 칸에서 벗어나고 지붕이
// 막히는 한계선 밖으로 나가므로, 여기서 세 가지를 맞춘다:
//
//   1. 실루엣을 노란 한계선(가로 448) 안에 넣는다
//   2. 문 한가운데를 캔버스 정가운데(x = 256)에 세운다
//   3. 벽 밑동을 땅 선(y ≈ 394)에 올리고 그 아래를 그림자로 둔다
//
// 실행:  node cut_house.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const SRC = __dirname + '/src/';
const OUT = __dirname + '/../sprites/';

const CW = 512, CH = 410;        // 캔버스
const LIM_X0 = 32, LIM_X1 = 480; // 막히는 한계선 (가로 448)
const LIM_Y0 = 26;               // 〃 (세로 384)
const DOOR_CX = 256;             // 문 중심
const BASE_Y = 404;              // 그림 밑동이 앉는 줄 (아래는 그림자 자리)

// door: 원본에서 문 한가운데 x. 눈으로 재서 적는다 — 자동으로 찾으면
//       현관 기둥이나 덧창의 나무색을 문으로 착각한다.
// sky:  이 y 위쪽을 지운다. 굴뚝 연기가 남으면 그만큼 집이 작아진다.
const JOBS = [
  { src: 'ref_house.png', out: 'house', door: 758 },
  { src: 'ref_shop.png', out: 'house_general', door: 768, sky: { x0: 1000, y1: 185 } },
  { src: 'ref_post.png', out: 'house_post', door: 767 },
  { src: 'ref_lab.png', out: 'house_lab', door: 514 },
  { src: 'ref_smith.png', out: 'house_smith', door: 506 },
  { src: 'ref_ranch.png', out: 'house_ranch', door: 509 },
  { src: 'ref_inn.png', out: 'house_inn', door: 628 },
  { src: 'ref_library.png', out: 'house_library', door: 636 },
  { src: 'ref_fish.png', out: 'house_fish', door: 508 },
];

for (const job of JOBS) cut(job);

function cut(job) {
  const p = PNG.sync.read(fs.readFileSync(SRC + job.src));
  const W = p.width, H = p.height, d = p.data;
  const A = (x, y) => d[(y * W + x) * 4 + 3];

  // ---- 하늘(연기) 지우기 ----
  if (job.sky) {
    for (let y = 0; y < job.sky.y1; y++)
      for (let x = job.sky.x0; x < W; x++) d[(y * W + x) * 4 + 3] = 0;
  }

  // ---- 실루엣 범위 ----
  // 반투명한 바닥 그림자는 빼고 「단단한」 부분만으로 잰다. 그림자까지
  // 세면 집이 그만큼 위로 떠서 땅에 안 붙어 보인다.
  let x0 = W, x1 = -1, y0 = H, y1 = -1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (A(x, y) <= 200) continue;
    if (x < x0) x0 = x; if (x > x1) x1 = x;
    if (y < y0) y0 = y; if (y > y1) y1 = y;
  }
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1;

  // ---- 배율: 한계선 안에 들어가는 가장 큰 크기 ----
  const s = Math.min((LIM_X1 - LIM_X0) / bw, (CH - LIM_Y0) / bh);

  // ---- 자리: 문 중심을 x=256에, 밑동을 BASE_Y에 ----
  let left = DOOR_CX - (job.door - x0) * s;     // 캔버스에서 x0이 놓이는 자리
  const top = BASE_Y - bh * s;                  // 〃 y0
  // 문이 원본에서 정중앙이 아니면 실루엣이 한쪽으로 삐져나온다. 문은 칸
  // (224~288)보다 훨씬 좁으니, 칸 안에 남는 만큼은 밀어서 실루엣을 넣는다.
  const shift = Math.max(Math.min(0, LIM_X1 - (left + bw * s)), LIM_X0 - left);
  if (shift !== 0) left += Math.max(-24, Math.min(24, shift));

  // 원본 → 캔버스 를 뒤집어, 캔버스 한 점이 원본의 어느 네모를 덮는지 본다.
  const inv = 1 / s;
  const o = new PNG({ width: CW, height: CH });
  for (let cy = 0; cy < CH; cy++) for (let cx = 0; cx < CW; cx++) {
    const sx = x0 + (cx - left) * inv, sy = y0 + (cy - top) * inv;
    let r = 0, g = 0, b = 0, a = 0, n = 0;
    for (let j = Math.floor(sy); j < Math.floor(sy + inv); j++)
      for (let i = Math.floor(sx); i < Math.floor(sx + inv); i++) {
        n++;
        if (i < 0 || j < 0 || i >= W || j >= H) continue;
        const q = (j * W + i) * 4, al = d[q + 3] / 255;
        // 미리 곱해서 더한다 — 그냥 더하면 투명한 이웃의 검정이 배어
        // 테두리에 어두운 띠가 생긴다.
        r += d[q] * al; g += d[q + 1] * al; b += d[q + 2] * al; a += al;
      }
    const k = (cy * CW + cx) * 4;
    if (!n || a <= 0.004) { o.data[k + 3] = 0; continue; }
    // 색 계단 6 — 바닥 타일과 같은 굵기로 끊는다 (make_house.js와 같은 값)
    const q6 = (v) => Math.max(0, Math.min(255, Math.round(v / a / 6) * 6));
    o.data[k] = q6(r); o.data[k + 1] = q6(g); o.data[k + 2] = q6(b);
    o.data[k + 3] = Math.round(255 * Math.min(1, a / n));
  }

  fs.writeFileSync(OUT + job.out + '.png', PNG.sync.write(o));
  const artW = Math.round(bw * s), artH = Math.round(bh * s);
  console.log('%s -> %s.png  배율 %s  실루엣 %dx%d  가로 %d~%d  위 %d',
    job.src, job.out, s.toFixed(4), artW, artH,
    Math.round(left), Math.round(left + bw * s), Math.round(top));
}
