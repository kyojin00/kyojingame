// 남자 캐릭터 스프라이트 생성기 (3세대) — **시트 한 장에서 전부** 뽑는다.
//
// 원본: sheet.png (AI로 뽑은 캐릭터 시트, 초록 배경). 6줄 x 5칸 = 30장.
//   0줄 옆 걷기   1줄 앞 걷기   2줄 뒤 걷기
//   3줄 옆 휘두르기 4줄 앞 휘두르기 5줄 뒤 휘두르기
//   휘두르기 줄의 다섯 칸 = 서기 · 감기 시작 · 다 감음(머리 위) · 내리침 · 되돌아옴
//
// 2세대(new_boy2/)는 걷기·서기만 있어서 칠 때 코드가 몸통을 굽혀 대신했다.
// 이 시트는 휘두르기까지 **같은 그림체 한 판에** 들어 있다. 그래서 걷기를
// 2세대에서 그대로 두고 휘두르기만 여기서 가져오면 **안 된다** — 이 캐릭터가
// 머리가 조금 더 커서(등신이 작아서) 칠 때마다 머리가 커진다. 통째로 바꾼다.
//
// 자르기부터 도트까지 한 파일에서 한다 (2세대는 손으로 자른 뒤 이 스크립트를
// 돌렸는데, 자르기 값이 어디에도 안 남아서 다시 뽑을 수가 없었다).
//
// 실행:  node make_sprites.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const OUT = __dirname + '/../../sprites/';

const FW = 128, FH = 192;   // 게임의 플레이어 스프라이트 규격
const FOOT_Y = 190;         // 땅에 닿은 발이 놓이는 행
// 앞머리 꼭대기 ~ 목. **키를 2세대와 같은 184px로 맞추는 값**이다
// (머리 비율이 달라서 세대마다 다시 잡아야 한다. 아래 로그가 키를 찍어 준다).
const HEAD_H = 59.6;
const WALK = 5;             // 방향당 걷기 프레임 수
const SWING = 4;            // 방향당 휘두르기 프레임 수 (서기 칸은 idle로 뺀다)
const NCOL = 28;            // 팔레트 색 수
const SPARK_LIGHT = 195;    // 불똥으로 번져 갈 수 있는 밝기 (이보다 어두우면 몸)
const SPARK_REACH = 14;     // 불똥 씨앗에서 번져 갈 수 있는 거리 (원본 픽셀)
const SPARK_THIN = 4;       // 불똥으로 볼 수 있는 굵기 (배경에서 이보다 깊으면 몸)
const SPARK_GAP = 3;        // 이만큼 떨어진 획까지 한 무리로 본다
const SPARK_MIN = 10;       // 무리가 이보다 작으면 불똥이 아니다 (하이라이트 티끌)
const SPECK = 24;           // 도트로 줄인 뒤 이보다 작은 조각은 떼어 낸다

const DIRS = ['side', 'down', 'up'];   // 시트 줄 순서 그대로


// ---------------------------------------------------------------- 시트 자르기

const sheet = PNG.sync.read(fs.readFileSync(REF + 'sheet.png'));
const { width: SW, height: SH, data: SD } = sheet;

// 배경(초록) 빼기. 기준색은 왼쪽 위 귀퉁이에서 집는다.
const bg = [SD[8], SD[9], SD[10]];
const mask = new Uint8Array(SW * SH);
for (let y = 0; y < SH; y++) for (let x = 0; x < SW; x++) {
  const i = (y * SW + x) * 4, r = SD[i], g = SD[i + 1], b = SD[i + 2];
  const d = (r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2;
  const green = g > r + 40 && g > b + 40 && g > 90;   // 덜 지워진 배경 그러데이션
  mask[y * SW + x] = (d < 60 * 60 || green) ? 0 : 1;
}
// 초록 번짐 지우기: 배경과 맞닿은 테두리 픽셀에 초록이 얹혀 있다. 이 캐릭터는
// 초록을 안 쓰므로(머리 갈색·옷 흰색·바지 갈색) 초록이 우세한 픽셀을
// 통째로 눌러도 그림이 상하지 않는다. 안 하면 도트에 초록 실선이 남는다.
for (let i = 0; i < SW * SH; i++) {
  if (!mask[i]) continue;
  const j = i * 4, r = SD[j], g = SD[j + 1], b = SD[j + 2], m = Math.max(r, b);
  if (g > m) SD[j + 1] = m;
}

// 투영으로 줄/칸 경계 찾기 (덩어리 사이가 minGap보다 좁으면 한 칸으로 본다)
function bands(n, get, minGap) {
  const out = []; let s = -1;
  for (let i = 0; i < n; i++) {
    const on = get(i);
    if (on && s < 0) s = i;
    if ((!on || i === n - 1) && s >= 0) { out.push([s, on ? i : i - 1]); s = -1; }
  }
  const m = [];
  for (const b of out) {
    if (m.length && b[0] - m[m.length - 1][1] < minGap) m[m.length - 1][1] = b[1];
    else m.push(b.slice());
  }
  return m.filter(b => b[1] - b[0] > 8);
}
const rowBands = bands(SH, y => {
  let n = 0; for (let x = 0; x < SW; x++) n += mask[y * SW + x]; return n > 3;
}, 12);
if (rowBands.length !== 6) throw new Error('줄이 6개가 아니다: ' + rowBands.length);

// 내리치는 칸에는 노란 불똥이 같이 그려져 있다. 게임은 맞는 순간 제 파티클을
// 뿌리므로 그림에 있으면 두 번 튄다 — 게다가 발치에서 옆으로 뻗어 나가
// 스프라이트 폭까지 잡아먹는다. 떼어 내는 법:
//   1) **밝고 진한 노랑**만 고른다. 캐릭터는 이런 색을 안 쓴다
//      (머리·부츠는 어둡고, 살결은 밝지만 흐리고, 옷은 거의 흰색).
//   2) 그 중 **발치에 있고 여럿이 뭉친 무리**만 남긴다. 부츠 하이라이트
//      가장자리가 한두 픽셀씩 걸리는데, 그것까지 지우면 그림에 구멍이 난다.
//   3) 거기서 **밝은 픽셀만 타고 번져** 창백한 꼬리까지 따라간다. 불똥은 노란
//      심지에서 살구빛으로 흐려지며 끝나는데, 그 끝은 주먹 살결과 색이 같아
//      색만으로는 못 가른다. 대신 불똥에는 이 그림체의 **검은 윤곽선이 없어서**,
//      어두운 픽셀에서 멈추게 하면 몸 안으로는 못 들어온다.
//   4) 마지막으로 **가장 큰 덩어리 하나만** 살린다 (몸에서 떨어져 나간 불똥).
function sparkMask(x0, x1, y0, y1) {
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const cand = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (!mask[(y0 + y) * SW + (x0 + x)]) continue;
    const i = ((y0 + y) * SW + (x0 + x)) * 4;
    const r = SD[i], g = SD[i + 1], b = SD[i + 2];
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
    if (mx < 199 || d < mx * 0.45) continue;              // 어둡거나 흐리면 아니다
    let hue = 0;
    if (d) hue = mx === r ? 60 * (((g - b) / d) % 6) : mx === g ? 60 * ((b - r) / d + 2) : 60 * ((r - g) / d + 4);
    if (hue < 0) hue += 360;
    if (hue >= 30 && hue <= 60) cand[y * w + x] = 1;      // 주황~노랑
  }
  // 불똥은 **짧은 획 여러 개**로 흩어져 그려져 있다. 획 하나하나를 세면
  // 죄다 두세 픽셀이라 걸러지므로, SPARK_GAP만큼 부풀려 붙은 것끼리 한 무리로
  // 묶어 놓고 무리의 크기를 잰다. 부츠 하이라이트 가장자리에 한두 픽셀씩
  // 걸리는 것들은 서로 떨어져 있어 이렇게 묶어도 작다.
  const fat = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (!cand[y * w + x]) continue;
    for (let dy = -SPARK_GAP; dy <= SPARK_GAP; dy++) for (let dx = -SPARK_GAP; dx <= SPARK_GAP; dx++) {
      const qx = x + dx, qy = y + dy;
      if (qx >= 0 && qy >= 0 && qx < w && qy < h) fat[qy * w + qx] = 1;
    }
  }
  const out = new Uint8Array(w * h), lab = new Int32Array(w * h).fill(-1), st = [];
  const yMin = Math.round(h * 0.68);                       // 발치
  for (let i = 0; i < w * h; i++) {
    if (lab[i] >= 0 || !fat[i]) continue;
    const cell = []; st.push(i); lab[i] = i;
    while (st.length) {
      const p = st.pop(); cell.push(p);
      const px = p % w, py = (p / w) | 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const qx = px + dx, qy = py + dy;
        if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
        const q = qy * w + qx;
        if (lab[q] >= 0 || !fat[q]) continue;
        lab[q] = i; st.push(q);
      }
    }
    const seeds = cell.filter(p => cand[p]);
    if (seeds.length >= SPARK_MIN && seeds.every(p => ((p / w) | 0) >= yMin))
      for (const p of seeds) out[p] = 1;
  }
  // 3) 밝은 픽셀만 타고 번지기.
  //    **얇은 데로만** 간다 — 불똥은 몇 픽셀짜리 획이고 몸은 두툼하다.
  //    (이 조건이 없으면 주먹 살결이 불똥 끝과 색이 같아 손 속까지 파먹는다.
  //     실제로 그렇게 나와서 손이 도넛이 됐다.)
  const thin = new Int32Array(w * h).fill(-1), tq = [];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = y * w + x;
    if (!mask[(y0 + y) * SW + (x0 + x)]) { thin[i] = 0; tq.push(i); }
  }
  for (let head = 0; head < tq.length; head++) {
    const i = tq[head], px = i % w, py = (i / w) | 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const qx = px + dx, qy = py + dy;
      if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
      const j = qy * w + qx;
      if (thin[j] >= 0) continue;
      thin[j] = thin[i] + 1; tq.push(j);
    }
  }
  //    씨앗에서 SPARK_REACH픽셀까지만 — 어디로 새더라도 거기서 멈춘다.
  const dist = new Int32Array(w * h).fill(-1), q = [];
  for (let i = 0; i < w * h; i++) if (out[i]) { dist[i] = 0; q.push(i); }
  for (let head = 0; head < q.length; head++) {
    const i = q[head]; if (dist[i] >= SPARK_REACH) continue;
    const px = i % w, py = (i / w) | 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const qx = px + dx, qy = py + dy;
      if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
      const j = qy * w + qx;
      if (dist[j] >= 0 || !mask[(y0 + qy) * SW + (x0 + qx)]) continue;
      if (thin[j] > SPARK_THIN) continue;
      const s = ((y0 + qy) * SW + (x0 + qx)) * 4;
      if (Math.max(SD[s], SD[s + 1], SD[s + 2]) < SPARK_LIGHT) continue;
      dist[j] = dist[i] + 1; out[j] = 1; q.push(j);
    }
  }
  return out;
}

// 칸 하나를 잘라 낸다 (불똥을 뗀 뒤 가장 큰 덩어리만 남긴다)
function cutCell(x0, x1, y0, y1) {
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const spark = sparkMask(x0, x1, y0, y1);
  const on = i => mask[(y0 + ((i / w) | 0)) * SW + (x0 + (i % w))] && !spark[i];
  const lab = new Int32Array(w * h).fill(-1);
  const sizes = [], stack = [];
  for (let i = 0; i < w * h; i++) {
    if (lab[i] >= 0 || !on(i)) continue;
    const id = sizes.length; let n = 0;
    stack.push(i); lab[i] = id;
    while (stack.length) {
      const p = stack.pop(); n++;
      const px = p % w, py = (p / w) | 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const qx = px + dx, qy = py + dy;
        if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
        const q = qy * w + qx;
        if (lab[q] >= 0 || !on(q)) continue;
        lab[q] = id; stack.push(q);
      }
    }
    sizes.push(n);
  }
  let keep = 0;
  for (let i = 1; i < sizes.length; i++) if (sizes[i] > sizes[keep]) keep = i;
  const dropped = sizes.reduce((a, b) => a + b, 0) - (sizes[keep] || 0)
    + spark.reduce((a, b) => a + b, 0);
  const o = new PNG({ width: w, height: h }); o.data.fill(0);
  for (let i = 0; i < w * h; i++) {
    if (lab[i] !== keep) continue;
    const si = ((y0 + ((i / w) | 0)) * SW + (x0 + (i % w))) * 4, di = i * 4;
    o.data[di] = SD[si]; o.data[di + 1] = SD[si + 1]; o.data[di + 2] = SD[si + 2];
    o.data[di + 3] = 255;
  }
  return { img: o, dropped };
}

// 줄 -> 칸 5개
const grid = [];
rowBands.forEach((rb, ri) => {
  const cols = bands(SW, x => {
    let n = 0; for (let y = rb[0]; y <= rb[1]; y++) n += mask[y * SW + x]; return n > 2;
  }, 14);
  if (cols.length !== 5) throw new Error(`${ri}줄의 칸이 5개가 아니다: ` + cols.length);
  grid.push(cols.map(cb => cutCell(cb[0], cb[1], rb[0], rb[1])));
});
const totalDropped = grid.flat().reduce((a, c) => a + c.dropped, 0);


// ---------------------------------------------------------- 재기 (머리 / 바닥)

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

// 허리(반바지) 띠의 무게중심 x — **걷기 줄**의 좌우 기준점.
// 걷는 동안 다리는 벌어져도 허리는 제자리라 가장 덜 흔들린다.
function hipX(p, m) {
  const { width: W, data: D } = p;
  const a = m.hairTop + Math.round((m.y1 - m.hairTop) * 0.60);
  const b = m.hairTop + Math.round((m.y1 - m.hairTop) * 0.72);
  let sx = 0, n = 0;
  for (let y = a; y <= b; y++) for (let x = 0; x < W; x++) if (D[((y * W + x) * 4) + 3] >= 128) { sx += x; n++; }
  return n ? sx / n : W / 2;
}

// 휘두르기 줄은 허리를 못 쓴다 — 팔을 뻗은 칸·굽힌 칸은 허리 띠가 팔다리를
// 같이 집어서 실루엣 한가운데(=팔 따라 움직이는 값)로 흘러간다.
// 대신 **밟고 선 자리의 무게중심**을 쓴다. 발을 벌리든 앞으로 내딛든
// 두 발의 한가운데는 거의 그대로라, 이걸 칸마다 같은 x에 두면 발이 안 미끄러진다.
// (앞으로 쏠리는 느낌은 게임이 실행 중에 pose.shift로 따로 준다)
function footX(p, m) {
  const { width: W, data: D } = p;
  const a = m.y1 - Math.round((m.y1 - m.y0) * 0.10);
  let sx = 0, n = 0;
  for (let y = a; y <= m.y1; y++) for (let x = 0; x < W; x++)
    if (D[((y * W + x) * 4) + 3] >= 128) { sx += x; n++; }
  return n ? sx / n : W / 2;
}

const median = a => { const v = a.slice().sort((x, y) => x - y); return v[v.length >> 1]; };

const met = grid.map(row => row.map(c => scan(c.img)));
// 배율은 **걷기 15장**의 머리 높이 중앙값으로 잡는다. 팔을 든 칸·굽힌 칸은
// 실루엣이 달라져 목 찾기가 어긋나므로 재는 데 쓰지 않는다 (그림 자체는
// 같은 판에서 뽑혀 크기가 같으니 배율 하나면 된다).
const walkHeads = [];
for (let ri = 0; ri < 3; ri++) for (let ci = 0; ci < 5; ci++) walkHeads.push(met[ri][ci].headH);
const SCALE = HEAD_H / median(walkHeads);

// 바닥선은 **줄마다** 잡는다. 줄 안에서는 발이 같은 자리에 있고,
// 줄끼리는 시트가 알아서 나눠 놨다 (한 줄이 한 장의 캔버스가 아니므로
// 30장을 한 기준으로 묶으면 줄 간격이 그대로 오차가 된다).
const GROUND = met.map(row => Math.max(...row.map(m => m.y1)));


// ------------------------------------------------------------------ 도트 뽑기

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

// 시트 칸 -> 게임 스프라이트 이름
//   걷기 줄(0~2): walk_0 .. walk_4
//   휘두르기 줄(3~5): 0번 칸은 idle, 1~4번 칸이 swing_0 .. swing_3
const outName = (ri, ci) => ri < 3
  ? `new_boy_${DIRS[ri]}_walk_${ci}`
  : (ci === 0 ? `new_boy_${DIRS[ri - 3]}_idle` : `new_boy_${DIRS[ri - 3]}_swing_${ci - 1}`);

// 칸마다의 좌우 기준점 (칸을 따로 잘라 놔서 좌표계도 칸마다 따로다)
const ANCHOR = [];
for (let ri = 0; ri < 6; ri++) {
  if (ri < 3) { ANCHOR.push(grid[ri].map((c, ci) => hipX(c.img, met[ri][ci]))); continue; }
  // 서 있는 칸(0번)의 허리를 기준으로 잡고, 나머지 칸은 발 무게중심이
  // 그 칸에서 얼마나 옮겨 갔는지만큼 같이 옮긴다
  const h0 = hipX(grid[ri][0].img, met[ri][0]), f0 = footX(grid[ri][0].img, met[ri][0]);
  ANCHOR.push(grid[ri].map((c, ci) => h0 + footX(c.img, met[ri][ci]) - f0));
}
// 캔버스 밖으로 나가면 그만큼만 기준점을 민다. 몸을 깊이 숙인 칸은 머리가
// 앞으로 쏠려서 128px 폭을 몇 픽셀 넘긴다 — 안 밀면 머리카락이 잘려 나간다.
// (미는 만큼 발이 옮겨 가지만, 그 순간 게임이 pose.shift로 앞으로 실어 주는
//  양과 방향이 반대라 거의 상쇄된다. 넘긴 양은 아래 로그에 찍힌다.)
const NUDGE = [];
for (let ri = 0; ri < 6; ri++) for (let ci = 0; ci < 5; ci++) {
  const { width: W, data: D } = grid[ri][ci].img;
  let l = 1e9, r = -1;
  for (let i = 0; i < D.length; i += 4) if (D[i + 3] >= 128) { const x = (i / 4) % W; if (x < l) l = x; if (x > r) r = x; }
  const over = (r - ANCHOR[ri][ci]) * SCALE - (FW - 65);      // 오른쪽으로 넘긴 도트
  const under = (ANCHOR[ri][ci] - l) * SCALE - 64;            // 왼쪽으로 넘긴 도트
  let d = 0;
  if (over > 0) d = over / SCALE;
  else if (under > 0) d = -under / SCALE;
  if (d !== 0) {
    ANCHOR[ri][ci] += d;
    NUDGE.push(`${outName(ri, ci)} ${d > 0 ? '←' : '→'}${Math.abs(d * SCALE).toFixed(1)}`);
  }
}

const jobs = [];
for (let ri = 0; ri < 6; ri++) {
  for (let ci = 0; ci < 5; ci++) {
    const img = grid[ri][ci].img;
    const ax = ANCHOR[ri][ci];
    const px = [];
    for (let ty = 0; ty < FH; ty++) for (let tx = 0; tx < FW; tx++)
      px.push(sample(img, ax, GROUND[ri], SCALE, tx, ty));
    jobs.push({ name: outName(ri, ci), px, ri, ci });
  }
}

// --- 30장이 같은 색을 쓰도록 팔레트를 한 번에 줄인다 (k-means) ---
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

// 도트로 줄이고 나면 원본에서 실 한 오라기로 붙어 있던 것이 끊어져
// 몸 옆에 티끌로 남는다 (떼다 만 불똥 꼬리 끝 같은 것). 여기서 마저 턴다.
function dropSpecks(o) {
  const lab = new Int32Array(FW * FH).fill(-1), sizes = [], st = [];
  for (let i = 0; i < FW * FH; i++) {
    if (lab[i] >= 0 || !o.data[i * 4 + 3]) continue;
    const id = sizes.length; let n = 0;
    st.push(i); lab[i] = id;
    while (st.length) {
      const p = st.pop(); n++;
      const px = p % FW, py = (p / FW) | 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const qx = px + dx, qy = py + dy;
        if (qx < 0 || qy < 0 || qx >= FW || qy >= FH) continue;
        const q = qy * FW + qx;
        if (lab[q] >= 0 || !o.data[q * 4 + 3]) continue;
        lab[q] = id; st.push(q);
      }
    }
    sizes.push(n);
  }
  let keep = 0, gone = 0;
  for (let i = 1; i < sizes.length; i++) if (sizes[i] > sizes[keep]) keep = i;
  for (let i = 0; i < FW * FH; i++)
    if (lab[i] >= 0 && lab[i] !== keep && sizes[lab[i]] < SPECK) { o.data[i * 4 + 3] = 0; gone++; }
  return gone;
}

const outImgs = {};
let specks = 0;
for (const j of jobs) {
  const o = new PNG({ width: FW, height: FH }); o.data.fill(0);
  for (let i = 0; i < FW * FH; i++) {
    const c = j.px[i]; if (!c) continue; const q = snap(c);
    o.data[i * 4] = q[0]; o.data[i * 4 + 1] = q[1]; o.data[i * 4 + 2] = q[2]; o.data[i * 4 + 3] = 255;
  }
  specks += dropSpecks(o);
  fs.writeFileSync(OUT + j.name + '.png', PNG.sync.write(o));
  outImgs[j.name] = o;
}


// ----------------------------------------------------------------- 확인용 그림

// 도구를 얹을 주먹 자리를 눈으로 집어야 해서 좌표 눈금을 같이 그린다
// (player.gd의 SWING_HAND_DOT에 그 값을 적는다. 원점은 발밑 가운데.)
function preview(name, list, gridOn) {
  const Z = 3, w = FW * list.length * Z, h = FH * Z, pv = new PNG({ width: w, height: h });
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const im = outImgs[list[Math.floor(x / Z / FW)]];
    const sx = Math.floor(x / Z) % FW, sy = Math.floor(y / Z), si = (sy * FW + sx) * 4;
    const di = (y * w + x) * 4, chk = ((Math.floor(x / Z / 8) + Math.floor(y / Z / 8)) % 2) ? 58 : 38;
    const a = im.data[si + 3];
    let c = a ? [im.data[si], im.data[si + 1], im.data[si + 2]] : [chk, chk, chk];
    if (gridOn && !a) {
      // 발밑 가운데(64, FOOT_Y)에서 10픽셀 눈금, 50픽셀마다 밝게
      const gx = sx - 64, gy = sy - FOOT_Y;
      if (gx % 10 === 0 && gy % 10 === 0) c = (gx % 50 === 0 || gy % 50 === 0) ? [120, 90, 60] : [80, 70, 60];
    }
    pv.data[di] = c[0]; pv.data[di + 1] = c[1]; pv.data[di + 2] = c[2]; pv.data[di + 3] = 255;
  }
  fs.writeFileSync(REF + name, PNG.sync.write(pv));
}
preview('preview_idle.png', DIRS.map(d => `new_boy_${d}_idle`));
for (const d of DIRS) {
  preview(`preview_${d}_walk.png`, [...Array(WALK).keys()].map(i => `new_boy_${d}_walk_${i}`));
  preview(`preview_${d}_swing.png`, [...Array(SWING).keys()].map(i => `new_boy_${d}_swing_${i}`), true);
}

// 게임에서 보이는 키 = (바닥선 - 머리 꼭대기) x 배율
const tall = [], wide = [];
for (let ri = 0; ri < 6; ri++) for (let ci = 0; ci < 5; ci++) {
  tall.push((GROUND[ri] - met[ri][ci].y0) * SCALE);
  const { width: W, data: D } = grid[ri][ci].img;
  let l = 1e9, r = -1;
  for (let i = 0; i < D.length; i += 4) if (D[i + 3] >= 128) { const x = (i / 4) % W; if (x < l) l = x; if (x > r) r = x; }
  wide.push(Math.max(ANCHOR[ri][ci] - l, r - ANCHOR[ri][ci]) * SCALE);
}
console.log('frames %d  scale %s  palette %d  불똥 등 떼어 낸 픽셀 %d + 도트 티끌 %d',
  jobs.length, SCALE.toFixed(4), cent.length, totalDropped, specks);
console.log('걷기 머리높이 %s', walkHeads.join(','));
if (NUDGE.length) console.log('캔버스 밖으로 나가 민 칸: %s', NUDGE.join(', '));
console.log('키 최대 %d px (캔버스 %d) · 중심에서 좌우 최대 %d px (반폭 64)',
  Math.round(Math.max(...tall)), FH, Math.round(Math.max(...wide)));
