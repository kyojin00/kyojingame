// 참고 도트에서 직접 오려내는 도구.
//
// src/ref_tiles.png  — 4칸짜리 지형 견본표 (물 / 돌길 / 풀 / 밭)
// src/ref_title.png  — 타이틀용 풍경화
//
// 그냥 잘라 붙이면 두 가지가 걸린다.
//   1) 원본은 「도트처럼 보이는 그림」이라 1px 잡티가 잔뜩이다  -> 넓게 떠서 평균으로 줄인다
//   2) 자른 조각은 좌우/위아래가 안 맞물려 격자가 보인다        -> 감아 겹치기(offset blend)로 이어붙인다
//
// 실행:  node cut_ref.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const SRC = __dirname + '/src/';
const OUT = __dirname + '/../sprites/';
const S = 64;          // 지형 타일 한 변 (게임에서는 32px 칸에 그린다)
const FEATHER = 16;    // 이음새를 녹이는 폭

const load = (f) => PNG.sync.read(fs.readFileSync(SRC + f));
const at = (p, x, y) => {
  x = Math.max(0, Math.min(p.width - 1, x | 0));
  y = Math.max(0, Math.min(p.height - 1, y | 0));
  const i = (y * p.width + x) * 4;
  return [p.data[i], p.data[i + 1], p.data[i + 2]];
};

// ---- 넓은 영역을 평균으로 줄인다 (잡티가 사라지고 색이 정리된다) ----
function boxResize(p, sx, sy, sw, sh, dw, dh) {
  const out = [];
  for (let j = 0; j < dh; j++) {
    const row = [];
    for (let i = 0; i < dw; i++) {
      const x0 = sx + i * sw / dw, x1 = sx + (i + 1) * sw / dw;
      const y0 = sy + j * sh / dh, y1 = sy + (j + 1) * sh / dh;
      let r = 0, g = 0, b = 0, n = 0;
      for (let y = Math.floor(y0); y < Math.ceil(y1); y++)
        for (let x = Math.floor(x0); x < Math.ceil(x1); x++) {
          const c = at(p, x, y); r += c[0]; g += c[1]; b += c[2]; n++;
        }
      row.push([Math.round(r / n), Math.round(g / n), Math.round(b / n)]);
    }
    out.push(row);
  }
  return out;
}

// ---- 이어붙여도 티가 안 나게 (감아 겹치기) ----
// (S+F) 크기로 뜬 다음, 왼쪽 끝은 오른쪽 너머 픽셀과 섞어 S 크기로 줄인다.
function seamless(big) {
  const F = FEATHER;
  const h = (a, b, t) => [
    Math.round(a[0] * t + b[0] * (1 - t)),
    Math.round(a[1] * t + b[1] * (1 - t)),
    Math.round(a[2] * t + b[2] * (1 - t))];
  const tmp = [];
  for (let y = 0; y < S + F; y++) {
    const row = [];
    for (let x = 0; x < S; x++) {
      const t = x < F ? 0.5 + 0.5 * (x / F) : 1;
      row.push(t >= 1 ? big[y][x] : h(big[y][x], big[y][x + S], t));
    }
    tmp.push(row);
  }
  const out = [];
  for (let y = 0; y < S; y++) {
    const t = y < F ? 0.5 + 0.5 * (y / F) : 1;
    const row = [];
    for (let x = 0; x < S; x++)
      row.push(t >= 1 ? tmp[y][x] : h(tmp[y][x], tmp[y + S][x], t));
    out.push(row);
  }
  return out;
}

// ---- 색 정리 ----
// 평균으로 줄이면 색이 수백 가지로 번진다. 계단으로 끊어 도트다운 색 수로 되돌린다.
function quantize(tile, step) {
  return tile.map(r => r.map(c => c.map(v =>
    Math.max(0, Math.min(255, Math.round(v / step) * step)))));
}
// 채도/대비를 살짝 올린다 (줄이면서 죽은 색을 되살린다)
function punch(tile, sat, con) {
  return tile.map(r => r.map(c => {
    const l = (c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114);
    return c.map(v => Math.max(0, Math.min(255,
      Math.round(128 + (l + (v - l) * sat - 128) * con))));
  }));
}

// ---- 넓은 얼룩 지우기 ----
// 원본은 한쪽이 밝고 한쪽이 어둡다. 그대로 이어붙이면 밝은 칸/어두운 칸이
// 번갈아 보여 바둑판이 된다. 흐린 판을 빼고 평균을 되돌려 「결」만 남긴다.
function flatten(t, R) {
  const h = t.length, w = t[0].length;
  R = R || 12;
  // 되접기: 가장자리를 거울처럼 되접어 읽는다 (자른 끝에서 흐림이 치우치지 않게)
  const rf = (v, n) => { v = Math.abs(v); return v >= n ? 2 * n - 2 - v : v; };
  const blur = [];
  for (let y = 0; y < h; y++) {
    const row = [];
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, n = 0;
      for (let j = -R; j <= R; j += 2) for (let i = -R; i <= R; i += 2) {
        const c = t[rf(y + j, h)][rf(x + i, w)];
        r += c[0]; g += c[1]; b += c[2]; n++;
      }
      row.push([r / n, g / n, b / n]);
    }
    blur.push(row);
  }
  let mr = 0, mg = 0, mb = 0;
  for (const row of t) for (const c of row) { mr += c[0]; mg += c[1]; mb += c[2]; }
  const n = h * w; mr /= n; mg /= n; mb /= n;
  return t.map((row, y) => row.map((c, x) => [
    Math.max(0, Math.min(255, Math.round(c[0] - blur[y][x][0] + mr))),
    Math.max(0, Math.min(255, Math.round(c[1] - blur[y][x][1] + mg))),
    Math.max(0, Math.min(255, Math.round(c[2] - blur[y][x][2] + mb))),
  ]));
}

// 평균색 (평탄화·대비 손질을 거쳐도 원본 색을 잃지 않게 기준으로 쓴다)
function meanOf(t) {
  let r = 0, g = 0, b = 0, n = 0;
  for (const row of t) for (const c of row) { r += c[0]; g += c[1]; b += c[2]; n++; }
  return [r / n, g / n, b / n];
}
function matchMean(t, target) {
  const m = meanOf(t);
  return t.map(row => row.map(c => c.map((v, i) =>
    Math.max(0, Math.min(255, Math.round(v + target[i] - m[i]))))));
}

function cutTile(p, win, size, opt) {
  opt = opt || {};
  let t = boxResize(p, win.x, win.y, size, size, S + FEATHER, S + FEATHER);
  const src = meanOf(t);                 // 원본 평균색을 기억해 둔다
  if (opt.flat !== false) t = flatten(t, opt.blurR);
  t = seamless(t);
  t = punch(t, opt.sat === undefined ? 1.18 : opt.sat,
    opt.con === undefined ? 1.06 : opt.con);
  // 손질하면서 색이 뜨거나 가라앉는다 — 평균을 원본으로 되돌린다
  t = matchMean(t, src);
  return quantize(t, opt.step || 8);
}

// ---- 깨끗한 자리 찾기 ----
// 견본표에는 꽃·바위·풀 가장자리가 섞여 있다. 반복해서 깔면 그것들이
// 격자로 도드라지므로, 「군더더기가 가장 적은 창」을 훑어서 고른다.
// 검은 격자선이 물린 창은 통째로 버린다 (예전엔 이게 타일 한가운데 검은 줄로 남았다)
const isInk = (c) => c[0] < 26 && c[1] < 26 && c[2] < 26;
function findWindows(p, cols, bands, size, bad, count, minGap) {
  const cand = [];
  for (const band of bands) {
    if (band[1] - band[0] < size) continue;
    for (let y = band[0]; y + size <= band[1]; y += 10)
      for (let x = cols[0]; x + size <= cols[1]; x += 10) {
        let s = 0, ink = 0;
        for (let j = 0; j < size; j += 3) for (let i = 0; i < size; i += 3) {
          const c = at(p, x + i, y + j);
          if (isInk(c)) ink++;
          if (bad(c)) s++;
        }
        if (ink > 12) continue;   // 몇 점은 그림자다 — 줄이 그어진 창만 버린다
        cand.push({ x, y, s });
      }
  }
  cand.sort((a, b) => a.s - b.s);
  const picked = [];
  for (const c of cand) {
    if (picked.length >= count) break;
    if (picked.some(q => Math.abs(q.x - c.x) < minGap && Math.abs(q.y - c.y) < minGap)) continue;
    picked.push(c);
  }
  return picked;
}
const isFlowerOrRock = (c) =>
  (c[0] > 140 && c[1] > 140 && c[2] > 110)                       // 흰/노란 꽃
  || (Math.abs(c[0] - c[1]) < 26 && Math.abs(c[1] - c[2]) < 26 && c[0] > 72);  // 회색 바위
const isGreen = (c) => c[1] > c[0] + 14 && c[1] > c[2] + 20;
const isNotBlue = (c) => !(c[2] > c[0] + 26 && c[2] > 70);

function save(name, tile, alpha) {
  const w = tile[0].length, h = tile.length;
  const p = new PNG({ width: w, height: h });
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4, c = tile[y][x];
    if (!c) { p.data[i + 3] = 0; continue; }
    p.data[i] = c[0]; p.data[i + 1] = c[1]; p.data[i + 2] = c[2];
    p.data[i + 3] = alpha ? alpha(x, y) : 255;
  }
  fs.writeFileSync(OUT + name + '.png', PNG.sync.write(p));
}

// ================= 1. 지형 타일 =================
// 견본표에서 잡티(돌·꽃) 없는 자리를 골라 떴다.
// 잘라낼 칸 크기는 「원본에서 돌 하나가 게임 8px쯤으로 보이게」를 기준으로 맞췄다.
const sheet = load('ref_tiles.png');
// 견본표 칸 경계 (검은 격자선을 훑어서 잰 값)
const COL = { water: [8, 382], path: [396, 758], grass: [784, 1130], soil: [1348, 1526] };
// 가로 격자선 사이의 띠 — 창이 이 안에 온전히 들어가야 검은 줄이 안 섞인다
const BANDS = [[270, 446], [453, 650], [658, 861], [869, 1016]];

// 물: 파랗지 않은 것(기슭·바위)이 없는 자리
const wWin = findWindows(sheet, COL.water, BANDS, 190, isNotBlue, 1, 60)[0];
// 돌길: 초록(풀 가장자리)이 없는 자리
const pWin = findWindows(sheet, COL.path, BANDS, 165, isGreen, 1, 60)[0];
// 풀: 꽃·바위가 가장 적은 자리 셋 (서로 떨어뜨려 뽑는다)
const gWins = findWindows(sheet, COL.grass, BANDS, 185, isFlowerOrRock, 3, 70);
// 밭: 새싹(초록)이 없는 자리
const sWin = findWindows(sheet, COL.soil, BANDS, 145, isGreen, 1, 40)[0];
console.log('고른 자리  물=%j 길=%j 풀=%j 밭=%j',
  [wWin.x, wWin.y], [pWin.x, pWin.y], gWins.map(w => [w.x, w.y]), [sWin.x, sWin.y]);

const tiles = {
  water: cutTile(sheet, wWin, 190, { sat: 1.22, con: 1.10 }),
  // 포석은 돌 하나하나의 명암이 곧 무늬다 — 흐림 반경을 크게 잡아
  // 「넓은 얼룩」만 걷어내고 돌의 볼록함은 남긴다
  path: cutTile(sheet, pWin, 165, { sat: 0.90, con: 1.14, blurR: 30 }),
  grass: cutTile(sheet, gWins[0], 185),
  grass2: cutTile(sheet, gWins[1], 185),
  grass3: cutTile(sheet, gWins[2], 185),
  // 밭 고랑은 「넓은 얼룩」이 아니라 무늬다 — 평탄화하면 지워진다
  soil: cutTile(sheet, sWin, 145, { flat: false, sat: 1.10, con: 1.08 }),
};

// ---- 물: 두 프레임. 이어붙이기가 되니 통째로 밀면 흐르는 것처럼 보인다 ----
function shift(t, dx, dy) {
  return t.map((_, y) => t[0].map((__, x) =>
    t[(y - dy + S) % S][(x - dx + S) % S]));
}
save('water_0', tiles.water);
save('water_1', shift(tiles.water, 3, 1));

// ---- 돌길 ----
save('path', tiles.path);

// ---- 돌길 가장자리 ----
// 길 텍스처를 그대로 쓰되, 가장자리에서 들쭉날쭉하게 끊는다.
// (색을 따로 고르지 않으니 길과 절대 안 어긋난다)
function hash01(x, y, seed) {
  let n = (Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263)
    ^ Math.imul(seed | 0, 362437)) >>> 0;
  n = Math.imul(n ^ (n >>> 13), 1274126177) >>> 0;
  return ((n ^ (n >>> 16)) >>> 0) / 4294967295;
}
['n', 's', 'w', 'e'].forEach((d, dir) => {
  const depth = [];
  for (let i = 0; i < S; i++)
    depth.push(2 + Math.floor(hash01(i, dir * 3, 51) * 10));
  save('path_edge_' + d, tiles.path, (x, y) => {
    let i, dd;
    if (dir === 0) { i = x; dd = y; }
    else if (dir === 1) { i = x; dd = S - 1 - y; }
    else if (dir === 2) { i = y; dd = x; }
    else { i = y; dd = S - 1 - x; }
    if (dd >= depth[i]) return 0;
    if (dd >= depth[i] - 3 && hash01(i, dd, 52) > 0.5) return 0;  // 끝자락은 성기게
    return 255;
  });
});

// ---- 풀: 봄/여름은 원본 그대로, 가을/겨울은 색만 옮긴다 ----
function rgb2hsv(c) {
  const r = c[0] / 255, g = c[1] / 255, b = c[2] / 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d) {
    if (mx === r) h = ((g - b) / d + 6) % 6;
    else if (mx === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h /= 6;
  }
  return [h, mx ? d / mx : 0, mx];
}
function hsv2rgb(h, s, v) {
  const i = Math.floor(h * 6), f = h * 6 - i;
  const p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
  const m = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][i % 6];
  return m.map(x => Math.max(0, Math.min(255, Math.round(x * 255))));
}
// 계절: [색상 목표, 채도 배율, 명도 배율, 색상으로 끌어당기는 정도]
// [색상 목표, 채도 배율, 명도 배율, 색상 끌어당김, 덧입힐 색, 덧입힘 정도]
const SEASON = {
  spring: null,
  summer: [0.29, 1.12, 0.92, 0.55],                            // 조금 더 짙은 초록
  fall: [0.10, 0.82, 1.04, 0.92],                              // 누렇게
  winter: [0.58, 0.10, 1.45, 0.95, [236, 243, 252], 0.55],     // 눈 덮인 흰빛
};
function reseason(tile, sp) {
  if (!sp) return tile;
  const [hue, sm, vm, pull, tint, tw] = sp;
  return tile.map(r => r.map(c => {
    const [h, s, v] = rgb2hsv(c);
    const out = hsv2rgb((h + (hue - h) * pull + 1) % 1, Math.min(1, s * sm), Math.min(1, v * vm));
    if (!tint) return out;
    return out.map((x, i) => Math.round(x * (1 - tw) + tint[i] * tw));
  }));
}
const GRASS_SRC = [tiles.grass, tiles.grass2, tiles.grass3];
for (const season in SEASON)
  GRASS_SRC.forEach((t, v) =>
    save(`grass_${season}_${v}`, quantize(reseason(t, SEASON[season]), 8)));

// ---- 밭: 마른 흙 + 물 준 흙 ----
save('soil_dry', tiles.soil);
save('soil_wet', quantize(tiles.soil.map(r => r.map(c => [
  Math.round(c[0] * 0.68), Math.round(c[1] * 0.66), Math.round(c[2] * 0.70),
])), 6));

// ================= 2. 타이틀 배경 =================
// 1536x1024 -> 16:9로 잘라(1536x864) 960x540으로 줄인다.
// 위쪽 하늘이 넉넉해서 위를 더 덜어내고, 발치 돌길은 남긴다.
const scene = load('ref_title.png');
const CROP_Y = 118;
const big = boxResize(scene, 0, CROP_Y, 1536, 864, 960, 540);
save('title_bg', punch(big, 1.08, 1.03));

console.log('오려내기 완료 — 지형 %d장 + 타이틀 1장',
  2 + 1 + 4 + Object.keys(SEASON).length * 3 + 2);

// ================= 3. 건물 재질 =================
//
// 건물을 손으로 칠하면 넓은 면이 단색이라, 참고 그림에서 오려 온 바닥 타일
// 옆에 세웠을 때 혼자 매끈해서 튄다. 그래서 **결(grain)** 을 참고 그림의
// 마을집에서 그대로 떠 온다.
//
// 결 = 밝기에서 「넓은 얼룩」을 뺀 나머지. 색은 버리고 요철만 남기므로,
// 지붕 색을 건물마다 바꿔도 결은 그대로 쓸 수 있다.
const MAT = __dirname + '/mat/';
if (!fs.existsSync(MAT)) fs.mkdirSync(MAT);
const scene2 = load('ref_title.png');
const MAT_S = 48;   // 결 한 장 크기 (건물 그릴 때 이 크기로 반복해 쓴다)

function lum(c) { return c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114; }

// 결은 참고 그림에서 **통째로 떠 오지 않는다.**
// 그렇게 했더니 창틀·기와 줄 같은 큰 무늬까지 딸려 와서, 벽에 벽돌 자국처럼
// 규칙적으로 반복돼 보였다 (마을집 벽이 작아 깨끗한 조각을 뜰 수가 없다).
// 대신 그 자리의 **결의 세기만 재고**, 무늬는 이어붙는 잡음으로 직접 만든다.

// 고주파 밝기의 흩어진 정도. 창틀 같은 큰 경계에 휘둘리지 않게 중앙절대편차로 잰다.
function grainSigma(p, box, R) {
  const vals = [];
  for (let y = box[1]; y < box[3]; y += 2)
    for (let x = box[0]; x < box[2]; x += 2) {
      let s2 = 0, n = 0;
      for (let j = -R; j <= R; j++) for (let i = -R; i <= R; i++) {
        s2 += lum(at(p, x + i, y + j)); n++;
      }
      vals.push(Math.abs(lum(at(p, x, y)) - s2 / n));
    }
  vals.sort((a, b) => a - b);
  return vals[vals.length >> 1] * 1.4826;
}

// 이어붙는 값잡음 한 겹 (period는 N의 약수여야 감았을 때 안 튄다)
function valueNoise(N, period, seed) {
  const cells = N / period;
  const lat = [];
  for (let j = 0; j < cells; j++) {
    const row = [];
    for (let i = 0; i < cells; i++) {
      let n = (Math.imul(i + 1, 374761393) ^ Math.imul(j + 1, 668265263)
        ^ Math.imul(seed, 362437)) >>> 0;
      n = Math.imul(n ^ (n >>> 13), 1274126177) >>> 0;
      row.push(((n ^ (n >>> 16)) >>> 0) / 4294967295 - 0.5);
    }
    lat.push(row);
  }
  const out = [];
  for (let y = 0; y < N; y++) {
    const row = [];
    for (let x = 0; x < N; x++) {
      const fx = x / period, fy = y / period;
      const i0 = Math.floor(fx) % cells, j0 = Math.floor(fy) % cells;
      const i1 = (i0 + 1) % cells, j1 = (j0 + 1) % cells;
      const tx = fx - Math.floor(fx), ty = fy - Math.floor(fy);
      const sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty);
      const a = lat[j0][i0] * (1 - sx) + lat[j0][i1] * sx;
      const b = lat[j1][i0] * (1 - sx) + lat[j1][i1] * sx;
      row.push(a * (1 - sy) + b * sy);
    }
    out.push(row);
  }
  return out;
}

// 여러 겹을 겹쳐 「굵은 얼룩 + 잔 알갱이」를 만든 뒤, 잰 세기에 맞춰 키운다
function makeGrain(N, weights, sigma, seed) {
  const layers = weights.map((w, i) => valueNoise(N, [16, 8, 4, 2][i], seed + i * 17));
  const raw = [];
  for (let y = 0; y < N; y++) {
    const row = [];
    for (let x = 0; x < N; x++) {
      let v = 0;
      layers.forEach((L, i) => { v += L[y][x] * weights[i]; });
      row.push(v);
    }
    raw.push(row);
  }
  let m = 0, n = 0;
  for (const r of raw) for (const v of r) { m += v * v; n++; }
  const rms = Math.sqrt(m / n) || 1;
  return raw.map(r => r.map(v => {
    const q = Math.max(0, Math.min(255, Math.round(128 + v / rms * sigma)));
    return [q, q, q];
  }));
}

function saveMat(name, tile) {
  const w = tile[0].length, h = tile.length;
  const png = new PNG({ width: w, height: h });
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4, c = tile[y][x];
    png.data[i] = c[0]; png.data[i + 1] = c[1]; png.data[i + 2] = c[2]; png.data[i + 3] = 255;
  }
  fs.writeFileSync(MAT + name + '.png', PNG.sync.write(png));
}

// 마을집이 실제로 서 있는 자리 (하늘·산이 안 물리게 잡는다)
const VILLAGE = [1150, 430, 1530, 690];
// [세기를 잴 자리, 겹 무게(굵은->잔), 대표색]
const MATS = {
  plaster: [VILLAGE, [0.55, 0.85, 1.0, 0.75], [226, 226, 214]],
  roof: [[1368, 428, 1530, 480], [0.30, 0.60, 1.0, 0.9], [206, 112, 46]],
  wood: [[30, 690, 540, 1000], [0.25, 0.55, 1.0, 1.0], [122, 84, 46]],
  stone: [[1230, 320, 1420, 560], [0.60, 0.90, 1.0, 0.8], [176, 176, 168]],
};
const mats = {};
let seed0 = 91;
for (const k in MATS) {
  const [box, weights, col] = MATS[k];
  const sigma = grainSigma(scene2, box, 3);
  saveMat('grain_' + k, makeGrain(MAT_S, weights, sigma, seed0));
  seed0 += 131;
  mats[k] = col;
  console.log('재질 %s  결의 세기=%.1f  색=%j', k, sigma, col);
}
fs.writeFileSync(MAT + 'colors.json', JSON.stringify(mats, null, 1));
