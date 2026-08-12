// 휘두르기 원본 만들기 — 서기 원본에서 **팔만 떼어 돌린다**.
//
// 원본(1280x720)은 도트보다 3.5배 커서, 여기서 돌린 뒤 make_sprites.js로
// 줄이면 회전 자국이 축소에 묻힌다. 128x192에서 바로 돌리면 계단이 남는다.
//
// 어떻게 떼어 내나 —
//   1. 아래팔·소매 안쪽에 씨앗을 놓고 **외곽선에 막힐 때까지 번진다**.
//      팔과 몸통은 외곽선으로 갈라져 있어서 여기서 저절로 끊긴다.
//   2. 번진 자리를 어두운 쪽으로만 몇 px 부풀려 **자기 외곽선을 챙긴다**.
//   3. 어깨는 **원으로** 함께 떼어 낸다. 축이 그 원의 한가운데라, 아무리
//      돌려도 원이 제자리를 지켜 판 자국이 안 생긴다 (컷아웃의 정석).
//      직선으로 자르면 소매가 판자처럼 떨어져 나온다 — 실제로 그랬다.
//
// 두 마디로 움직인다. 위팔은 어깨를 축으로, 아래팔은 거기에 팔꿈치 회전을
// 한 번 더 얹는다. 한 마디로 돌리면 장대를 휘두르는 것처럼 보인다.
// 이음매가 벌어지지 않게 두 마디를 팔꿈치에서 겹쳐 둔다.
//
// 팔을 뗀 자리에는 몸통의 **왼쪽 외곽선이 없다.** 마지막에 「살색이 배경과
// 맞닿은 곳」에만 외곽선을 새로 둘러 준다. 이미 어두운 곳은 건드리지 않으므로
// 원래 외곽선이 두꺼워지지 않는다.
//
// ---- 방향을 늘리려면 ----
//
// 지금은 옆모습만 있다. 앞·뒤는 **화면 오른쪽 팔**만 움직이면 되는데,
// 한 번 해 보니 마스크는 잘 잡히지만 각도 조합에서 팔이 두 동강으로 보였다.
// 위팔·아래팔 각을 눈으로 맞추는 과정이 한 번 더 필요하다.
//
// 새 방향을 넣는 순서 —
//   1. `--debug`로 돌려 마스크(빨강)가 팔만 덮는지 본다. 씨앗과 bound를 조정
//   2. shoulder / elbow를 어깨·팔꿈치 한가운데로 옮긴다
//   3. phases를 바꿔 가며 세 자세를 눈으로 맞춘다. 옆모습은 [142,-48] ->
//      [-105,20] -> [-76,14]이었다 (감음 -> 앞으로 뻗음 -> 내리침).
//      **호가 머리 위를 지나게** 해야 한다. 0을 지나가면 서기 자세로 보인다
//   4. 찍히는 SWING_HAND_DOT 값을 player.gd에 옮긴다
//
// 실행:  node make_swing_src.js [--debug]      (pngjs 필요)
//        그 다음  node make_sprites.js
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const DEBUG = process.argv.includes('--debug');

const OUTLINE = [26, 10, 3];     // 새로 두르는 외곽선 색 (원본 외곽선과 같은 계열)
const OUTLINE_W = 5;             // 원본 외곽선 두께
const GRAB_W = 3;                // 팔이 챙겨 가는 외곽선 두께.
                                 // 5로 하면 반바지와 **나눠 쓰는** 외곽선까지
                                 // 떼어 가서 허리에 이빨 빠진 자국이 남는다
const JOINT = 14;                // 팔꿈치에서 두 마디를 겹치는 폭

// 방향마다 —
//   seeds    팔 안쪽 씨앗 (여기서 번진다)
//   bound    번지는 범위 [x0, y0, x1, y1] — 어깨 위로 새는 것을 막는다
//   shoulder 어깨 축 / elbow 팔꿈치 축
//   phases   [위팔 각, 아래팔 각] x 3위상 (도, 시계방향 +)
const ARM = {
  side: {
    src: 'side_idle',
    seeds: [[600, 460], [600, 380]],
    bound: [560, 356, 640, 548],
    shoulder: [603, 360], elbow: [601, 424], cap: 48, fist: 476,
    phases: [[142, -48], [-105, 20], [-76, 14]],
  },
};

const load = n => PNG.sync.read(fs.readFileSync(REF + n + '.png'));
const idx = (p, x, y) => ((y * p.width + x) << 2);
const solid = (p, x, y) => x >= 0 && y >= 0 && x < p.width && y < p.height
  && p.data[idx(p, x, y) + 3] >= 128;
const dark = (p, x, y) => {
  const i = idx(p, x, y);
  return p.data[i] + p.data[i + 1] + p.data[i + 2] < 260;   // 외곽선/그늘
};
function blank(w, h) { const p = new PNG({ width: w, height: h }); p.data.fill(0); return p; }
function copyPx(src, si, dst, di) { for (let k = 0; k < 4; k++) dst.data[di + k] = src.data[si + k]; }

// 외곽선에 막힐 때까지 번진다
function flood(p, seeds, [bx0, by0, bx1, by1]) {
  const W = p.width, m = new Uint8Array(W * p.height);
  const q = seeds.slice();
  for (const [x, y] of seeds) m[y * W + x] = 1;
  while (q.length) {
    const [x, y] = q.pop();
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (nx < bx0 || ny < by0 || nx >= bx1 || ny >= by1) continue;
      if (m[ny * W + nx] || !solid(p, nx, ny) || dark(p, nx, ny)) continue;
      m[ny * W + nx] = 1; q.push([nx, ny]);
    }
  }
  return m;
}

// 어두운 쪽으로만 부풀려 자기 외곽선을 챙긴다
function grabOutline(p, m, n) {
  const W = p.width, H = p.height;
  for (let k = 0; k < n; k++) {
    const add = [];
    for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) {
      if (m[y * W + x] || !solid(p, x, y) || !dark(p, x, y)) continue;
      if (m[y * W + x - 1] || m[y * W + x + 1] || m[(y - 1) * W + x] || m[(y + 1) * W + x])
        add.push(y * W + x);
    }
    for (const i of add) m[i] = 1;
  }
  return m;
}

// 어깨를 원으로 함께 떼어 낸다. 축이 원의 한가운데라 돌려도 자국이 없다.
function capDisc(p, m, [cx, cy], r) {
  for (let y = cy - r; y <= cy + r; y++) for (let x = cx - r; x <= cx + r; x++) {
    const dx = x - cx, dy = y - cy;
    if (dx * dx + dy * dy <= r * r && solid(p, x, y)) m[y * p.width + x] = 1;
  }
  return m;
}


function unrot(x, y, cx, cy, deg) {
  const a = -deg * Math.PI / 180, c = Math.cos(a), s = Math.sin(a);
  const dx = x - cx, dy = y - cy;
  return [cx + dx * c - dy * s, cy + dx * s + dy * c];
}

// 몸 색이 배경과 맞닿은 곳에만 외곽선을 두른다 (이미 어두우면 그냥 둔다)
function reOutline(p) {
  const W = p.width, H = p.height, add = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (solid(p, x, y)) continue;
    let near = false;
    for (let dy = -OUTLINE_W; dy <= OUTLINE_W && !near; dy++)
      for (let dx = -OUTLINE_W; dx <= OUTLINE_W; dx++) {
        if (dx * dx + dy * dy > OUTLINE_W * OUTLINE_W) continue;
        const nx = x + dx, ny = y + dy;
        if (solid(p, nx, ny) && !dark(p, nx, ny)) { near = true; break; }
      }
    if (near) add.push(idx(p, x, y));
  }
  for (const i of add) {
    p.data[i] = OUTLINE[0]; p.data[i + 1] = OUTLINE[1];
    p.data[i + 2] = OUTLINE[2]; p.data[i + 3] = 255;
  }
}

function build(dir, phase) {
  const cfg = ARM[dir];
  const base = load(cfg.src);
  const W = base.width, H = base.height;
  const mask = grabOutline(base, capDisc(base,
    flood(base, cfg.seeds, cfg.bound), cfg.shoulder, cfg.cap), GRAB_W);
  const [upDeg, foreDeg] = cfg.phases[phase];
  const [sx, sy] = cfg.shoulder;
  const [ex, ey] = cfg.elbow;
  const ra = upDeg * Math.PI / 180;
  const ex2 = sx + (ex - sx) * Math.cos(ra) - (ey - sy) * Math.sin(ra);
  const ey2 = sy + (ex - sx) * Math.sin(ra) + (ey - sy) * Math.cos(ra);

  // 1) 팔을 지운 몸
  const out = blank(W, H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
    if (!mask[y * W + x] && solid(base, x, y)) copyPx(base, idx(base, x, y), out, idx(out, x, y));
  // 지우고 남은 몸에 먼저 외곽선을 둘러 준다 (팔이 덮기 전에)
  reOutline(out);

  // 2) 돌린 팔을 얹는다. 위팔 -> 아래팔 순 (아래팔이 이음매를 덮는다)
  const put = (deg2, lo, hi) => {
    const px = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let ux = x, uy = y;
      if (deg2 !== null) [ux, uy] = unrot(x, y, ex2, ey2, deg2);
      [ux, uy] = unrot(ux, uy, sx, sy, upDeg);
      const si = Math.round(ux), sj = Math.round(uy);
      if (si < 0 || sj < 0 || si >= W || sj >= H) continue;
      if (!mask[sj * W + si] || sj < lo || sj > hi) continue;
      px.push([idx(out, x, y), idx(base, si, sj)]);
    }
    for (const [di, si] of px) copyPx(base, si, out, di);
  };
  put(null, 0, ey + JOINT);                 // 위팔 (어깨 회전만)
  put(foreDeg, ey - JOINT, H);              // 아래팔 (팔꿈치 회전 추가)

  if (DEBUG) {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (!mask[y * W + x]) continue;
      const i = idx(out, x, y);
      if (out.data[i + 3] < 128) { out.data[i] = 255; out.data[i + 1] = 60; out.data[i + 3] = 110; }
    }
  }
  return out;
}

// 주먹이 어디로 갔는지 알려 준다 — player.gd의 SWING_HAND_DOT에 그대로 적는다.
// (도구 그림은 손잡이 끝을 주먹 한가운데에 얹는다)
//   원본 -> 도트: tx = 64 + (sx - hipX) * SCALE,  ty = 190 + (sy - ground) * SCALE
//   도트 -> node: nx = (tx - 64) * 0.5,           ny = (ty - 188) * 0.5
const FIT = { side: { hipX: 638.9, ground: 680, scale: 0.2874 } };
function fistNode(cfg, dir, phase) {
  const base = load(cfg.src), W = base.width;
  const mask = grabOutline(base, capDisc(base,
    flood(base, cfg.seeds, cfg.bound), cfg.shoulder, cfg.cap), GRAB_W);
  let sx = 0, sy = 0, n = 0;
  for (let y = cfg.fist; y < base.height; y++) for (let x = 0; x < W; x++)
    if (mask[y * W + x]) { sx += x; sy += y; n++; }
  if (!n) return null;
  sx /= n; sy /= n;
  const [ux, uy] = cfg.shoulder, [ex, ey] = cfg.elbow;
  const [upDeg, foreDeg] = cfg.phases[phase];
  const rot = (px, py, cx, cy, deg) => {
    const a = deg * Math.PI / 180, c = Math.cos(a), s = Math.sin(a);
    return [cx + (px - cx) * c - (py - cy) * s, cy + (px - cx) * s + (py - cy) * c];
  };
  let [fx, fy] = rot(sx, sy, ex, ey, foreDeg);
  [fx, fy] = rot(fx, fy, ux, uy, upDeg);
  const f = FIT[dir];
  const tx = 64 + (fx - f.hipX) * f.scale, ty = 190 + (fy - f.ground) * f.scale;
  return [(tx - 64) * 0.5, (ty - 188) * 0.5];
}

for (const dir of Object.keys(ARM)) {
  const hands = [];
  for (let ph = 0; ph < 3; ph++) {
    const name = `${dir}_swing_${ph}`;
    fs.writeFileSync(REF + name + '.png', PNG.sync.write(build(dir, ph)));
    const f = fistNode(ARM[dir], dir, ph);
    hands.push(f ? `Vector2(${f[0].toFixed(0)}, ${f[1].toFixed(0)})` : '?');
    console.log('원본 생성:', name + '.png');
  }
  console.log(`  player.gd SWING_HAND_DOT["${dir}"] = [${hands.join(', ')}]`);
}
console.log('이어서:  node make_sprites.js');
