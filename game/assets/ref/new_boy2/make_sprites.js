// 남자 캐릭터 스프라이트 생성기 (2세대) — **지금은 안 쓴다.**
//
// 3세대(../new_boy3/)가 걷기·서기·휘두르기를 시트 한 장에서 다 뽑는다.
// 이 스크립트는 **같은 이름으로 덮어쓰므로**(new_boy_*_walk_*, new_boy_*_idle)
// 돌리면 3세대 걷기가 2세대 그림으로 바뀌어, 칠 때만 캐릭터 머리가 커진다.
// 되돌리려면 ../new_boy3/make_sprites.js를 다시 돌리면 된다.
//
// 원본: AI로 뽑은 캐릭터 시트 한 장을 칸별로 잘라 이 폴더에 넣은 것.
//   앞/옆/뒤 각각 **걷기 5프레임 + 서기 1장** = 18장.
//   1세대(new_boy/)는 걷기 4프레임이었다. 시트에서 5장이 나와 그대로 쓴다.
//
// 자르면서 이미 맞춰 둔 것 —
//   * 세 줄(걷기 앞/옆/뒤)과 서기 줄의 **바닥선을 한 자리로** 모았다.
//     줄 안의 위아래 흔들림(걸을 때 몸이 오르내리는 것)은 그대로 남겨 뒀다.
//   * 서기 3장이 걷기보다 12% 크게 그려져 있어서 0.899배로 줄여 맞췄다.
//     안 맞추면 멈출 때만 캐릭터가 커진다.
//
// 실행:  node make_sprites.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const OUT = __dirname + '/../../sprites/';

const FW = 128, FH = 192;   // 게임의 플레이어 스프라이트 규격
const FOOT_Y = 190;         // 땅에 닿은 발이 놓이는 행
// 앞머리 꼭대기 ~ 목. 1세대는 59.5였는데, 이 캐릭터는 머리가 몸에 비해
// 커서(등신이 작다) 그대로 쓰면 키가 196px이 되어 192 캔버스 위로 잘린다.
// 1세대와 **화면에서 같은 키(184px)** 가 되는 값으로 낮춘다.
const HEAD_H = 55.9;
const WALK = 5;             // 방향당 걷기 프레임 수
const NCOL = 28;            // 팔레트 색 수

const SETS = ['down', 'side', 'up'].map(d => ({
  name: 'new_boy_' + d,
  files: [...Array(WALK).keys()].map(i => `${d}_walk_${i}`).concat(`${d}_idle`),
}));
const outName = (set, i) => i < WALK ? `${set.name}_walk_${i}` : `${set.name}_idle`;

const load = n => PNG.sync.read(fs.readFileSync(REF + n + '.png'));
const median = a => { const v = a.slice().sort((x, y) => x - y); return v[v.length >> 1]; };

// 실루엣에서 머리 꼭대기 / 목 / 발바닥을 잡는다
function scan(p) {
  const { width: W, height: H, data: D } = p;
  const rw = []; let y0 = -1, y1 = -1;
  for (let y = 0; y < H; y++) {
    let l = 1e9, r = -1;
    for (let x = 0; x < W; x++) if (D[((y * W + x) * 4) + 3] >= 128) { if (x < l) l = x; if (x > r) r = x; }
    rw[y] = r < 0 ? 0 : r - l + 1;
    if (r >= 0) { if (y0 < 0) y0 = y; y1 = y; }
  }
  const maxW = Math.max(...rw);
  // 삐친 머리는 얇아서 건너뛰고, 앞머리 덩어리가 시작하는 행을 머리 꼭대기로 본다
  let hairTop = y0;
  for (let y = y0; y <= y1; y++) if (rw[y] >= maxW * 0.55) { hairTop = y; break; }
  // 목: 머리 아래 28~52% 구간에서 실루엣이 가장 좁아지는 행
  const a = hairTop + Math.round((y1 - hairTop) * 0.28), b = hairTop + Math.round((y1 - hairTop) * 0.52);
  let neck = a, nw = 1e9;
  for (let y = a; y <= b; y++) if (rw[y] < nw) { nw = rw[y]; neck = y; }
  return { y0, y1, hairTop, headH: neck - hairTop + 1 };
}

// 허리(반바지) 띠의 무게중심 x — 걷는 동안 가장 덜 흔들리는 기준점
function hipX(p, m) {
  const { width: W, data: D } = p;
  const a = m.hairTop + Math.round((m.y1 - m.hairTop) * 0.60);
  const b = m.hairTop + Math.round((m.y1 - m.hairTop) * 0.72);
  let sx = 0, n = 0;
  for (let y = a; y <= b; y++) for (let x = 0; x < W; x++) if (D[((y * W + x) * 4) + 3] >= 128) { sx += x; n++; }
  return n ? sx / n : W / 2;
}

// 출력 픽셀 하나 = 원본 박스 하나. 굵은 버킷의 최빈색으로 뽑아
// 안티에일리어싱 없이 도트의 단색 면을 그대로 살린다.
function sample(p, ax, ay, s, tx, ty) {
  const { width: W, height: H, data: D } = p;
  const sx0 = ax + (tx - 64) / s, sx1 = ax + (tx + 1 - 64) / s;
  const sy0 = ay + (ty - FOOT_Y) / s, sy1 = ay + (ty + 1 - FOOT_Y) / s;
  const ix0 = Math.max(0, Math.floor(sx0)), ix1 = Math.min(W - 1, Math.ceil(sx1) - 1);
  const iy0 = Math.max(0, Math.floor(sy0)), iy1 = Math.min(H - 1, Math.ceil(sy1) - 1);
  let tot = 0, op = 0; const bk = {};
  for (let y = iy0; y <= iy1; y++) for (let x = ix0; x <= ix1; x++) {
    tot++; const i = (y * W + x) * 4; if (D[i + 3] < 128) continue; op++;
    const k = ((D[i] >> 4) << 8) | ((D[i + 1] >> 4) << 4) | (D[i + 2] >> 4);
    const b = bk[k] || (bk[k] = [0, 0, 0, 0]);
    b[0] += D[i]; b[1] += D[i + 1]; b[2] += D[i + 2]; b[3]++;
  }
  if (tot === 0 || op / tot < 0.5) return null;
  let best = null;
  for (const k in bk) if (!best || bk[k][3] > best[3]) best = bk[k];
  return [Math.round(best[0] / best[3]), Math.round(best[1] / best[3]), Math.round(best[2] / best[3])];
}

// --- 1) 18장 전체를 재서 배율 하나를 정한다 ---
// 잘라 낼 때 서기와 걷기의 크기를 이미 맞춰 놨으므로 중앙값 하나면 된다.
const imgs = {}, met = {};
for (const set of SETS) for (const f of set.files) { imgs[f] = load(f); met[f] = scan(imgs[f]); }
const all = SETS.flatMap(s => s.files);
const SCALE = HEAD_H / median(all.map(f => met[f].headH));

// --- 2) 바닥선은 **18장 전체에서** 하나로 잡는다 ---
// 자를 때 네 줄의 바닥선을 한 자리로 모아 뒀다. 방향마다 따로 잡으면
// 그 차이가 도로 벌어져 방향을 바꿀 때 캐릭터가 위아래로 튄다.
const GROUND = Math.max(...all.map(f => met[f].y1));

const jobs = [];
for (const set of SETS) set.files.forEach((f, i) => {
  const px = [], ax = hipX(imgs[f], met[f]);
  for (let ty = 0; ty < FH; ty++) for (let tx = 0; tx < FW; tx++)
    px.push(sample(imgs[f], ax, GROUND, SCALE, tx, ty));
  jobs.push({ name: outName(set, i), px });
});

// --- 3) 18장이 같은 색을 쓰도록 팔레트를 한 번에 줄인다 (k-means) ---
const cols = []; jobs.forEach(j => j.px.forEach(c => { if (c) cols.push(c); }));
const seen = new Map();
for (const c of cols) { const k = (c[0] >> 3) + ',' + (c[1] >> 3) + ',' + (c[2] >> 3); seen.set(k, (seen.get(k) || 0) + 1); }
let cent = [...seen.entries()].sort((a, b) => b[1] - a[1]).slice(0, NCOL)
  .map(([k]) => k.split(',').map(v => parseInt(v) * 8 + 4));
for (let it = 0; it < 30; it++) {
  const acc = cent.map(() => [0, 0, 0, 0]);
  for (const c of cols) {
    let bi = 0, bd = 1e18;
    for (let i = 0; i < cent.length; i++) {
      const d = (c[0] - cent[i][0]) ** 2 + (c[1] - cent[i][1]) ** 2 + (c[2] - cent[i][2]) ** 2;
      if (d < bd) { bd = d; bi = i; }
    }
    acc[bi][0] += c[0]; acc[bi][1] += c[1]; acc[bi][2] += c[2]; acc[bi][3]++;
  }
  for (let i = 0; i < cent.length; i++) if (acc[i][3]) cent[i] = [0, 1, 2].map(j => Math.round(acc[i][j] / acc[i][3]));
}
const snap = c => {
  let bi = 0, bd = 1e18;
  for (let i = 0; i < cent.length; i++) {
    const d = (c[0] - cent[i][0]) ** 2 + (c[1] - cent[i][1]) ** 2 + (c[2] - cent[i][2]) ** 2;
    if (d < bd) { bd = d; bi = i; }
  }
  return cent[bi];
};

const outImgs = {};
for (const j of jobs) {
  const o = new PNG({ width: FW, height: FH }); o.data.fill(0);
  for (let i = 0; i < FW * FH; i++) {
    const c = j.px[i]; if (!c) continue; const q = snap(c);
    o.data[i * 4] = q[0]; o.data[i * 4 + 1] = q[1]; o.data[i * 4 + 2] = q[2]; o.data[i * 4 + 3] = 255;
  }
  fs.writeFileSync(OUT + j.name + '.png', PNG.sync.write(o));
  outImgs[j.name] = o;
}

// --- 4) 확인용 미리보기 ---
function preview(name, list) {
  const Z = 3, w = FW * list.length * Z, h = FH * Z, pv = new PNG({ width: w, height: h });
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const im = outImgs[list[Math.floor(x / Z / FW)]];
    const sx = Math.floor(x / Z) % FW, sy = Math.floor(y / Z), si = (sy * FW + sx) * 4;
    const di = (y * w + x) * 4, chk = ((Math.floor(x / Z / 8) + Math.floor(y / Z / 8)) % 2) ? 58 : 38;
    const a = im.data[si + 3];
    pv.data[di] = a ? im.data[si] : chk; pv.data[di + 1] = a ? im.data[si + 1] : chk;
    pv.data[di + 2] = a ? im.data[si + 2] : chk; pv.data[di + 3] = 255;
  }
  fs.writeFileSync(REF + name, PNG.sync.write(pv));
}
preview('preview_idle.png', SETS.map(s => s.name + '_idle'));
for (const d of ['down', 'side', 'up'])
  preview(`preview_${d}_walk.png`, [...Array(WALK).keys()].map(i => `new_boy_${d}_walk_${i}`));

// 게임에서 보이는 키 = (바닥선 - 머리 꼭대기) x 배율
const tallest = Math.max(...all.map(f => (GROUND - met[f].y0) * SCALE));
console.log('frames', jobs.length, 'scale', SCALE.toFixed(4),
  'headH', all.map(f => met[f].headH).join(','), 'palette', cent.length);
console.log('게임에서 키 %d px (192 캔버스 기준)', Math.round(tallest));
