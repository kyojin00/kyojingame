// 휘두르기 원본 만들기 — 서기 원본에서 팔을 지우고 **새로 그린다**.
//
// 처음에는 팔을 떼어 회전시켰다. 이음매는 붙었지만 팔이 통짜 막대처럼
// 보였다 — 매달린 팔을 통째로 돌린 것이라 팔꿈치가 접히지 않고, 소매도
// 길게 늘어난 채 따라 돌기 때문이다.
//
// 그래서 **지우고 새로 그린다.** 이 도트는 평면 색 + 외곽선 구조라
// 「굵기가 변하는 선분 + 둥근 끝」으로 팔을 그리면 원래 그림과 같은 결이 된다.
// 대신 자세를 마음대로 잡을 수 있다 — 팔꿈치를 접고, 소매는 짧게 두고,
// 주먹은 제자리에 둥글게 놓는다.
//
// 원본(1280x720)에서 그린 뒤 make_sprites.js로 줄인다. 도트보다 3.5배 커서
// 여기서 그리면 계단이 축소에 묻히고 팔레트도 알아서 맞춰진다.
//
// 팔을 지우는 방법은 그대로다 —
//   1. 아래팔·소매 안쪽에 씨앗을 놓고 **외곽선에 막힐 때까지 번진다.**
//      팔과 몸통은 외곽선으로 갈라져 있어 여기서 저절로 끊긴다.
//   2. 번진 자리를 어두운 쪽으로 3px 부풀려 자기 외곽선을 챙긴다.
//      5px로 하면 반바지와 **나눠 쓰는** 외곽선까지 떼어 가 허리가 파인다.
//   3. 지운 자리에 몸통 외곽선이 없어지므로, 「몸 색이 배경과 맞닿은 곳」에만
//      새로 둘러 준다. 이미 어두운 곳은 안 건드려 원래 선이 안 두꺼워진다.
//
// ---- 자세를 고치려면 ----
//
// POSE의 [위팔 각, 아래팔 각]만 만지면 된다. 0이 아래(차렷), 시계방향이 +.
// **호가 머리 위를 지나게** 잡을 것 — 0을 지나가면 팔이 몸 옆으로 내려와
// 그냥 서기 자세로 보인다.
//
// 실행:  node make_swing_src.js [--debug]      (pngjs 필요)
//        그 다음  node make_sprites.js
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const DEBUG = process.argv.includes('--debug');

const OUTLINE = [26, 10, 3];     // 새로 두르는 외곽선 색 (원본 외곽선과 같은 계열)
const OUTLINE_W = 5;             // 원본 외곽선 두께
const ARM_OUT = 7;               // 그려 넣는 팔의 외곽선. 원본보다 굵게 잡아야
                                 // 3.5배 축소 뒤에도 몸통 선과 같은 굵기로 남는다
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
    shoulder: [603, 356],
    // 팔 치수 (원본 px). 서기 그림에서 재 왔다.
    upper: 62, fore: 46, fistOut: 13,
    rSleeve: 21, rArm: 17, rWrist: 14, rFist: 18, sleeve: 40,
    // 위상별 [위팔 각, 아래팔 각]
    //   감음   팔꿈치를 위-뒤로 들고 아래팔을 접어 주먹이 머리 뒤로
    //   중간   앞-위로 쭉 뻗는다
    //   내리침 앞-아래로 곧게
    pose: [[124, 135], [-142, -69], [-41, -43]],
    // 빛은 왼쪽 위에서 온다 — 그늘은 오른쪽 아래
    light: [-0.6, -0.8],
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


// 원본에서 스포이드로 뽑은 색 (side_idle 기준)
// 도트 팔레트(28색)에 실제로 들어 있는 값을 쓴다. 중간 색을 지어내면
// k-means가 새 칸을 잡아먹어 다른 색이 밀린다.
const COL = {
  sleeve: [253, 243, 217], sleeveDark: [217, 205, 179],
  skin: [254, 213, 165], skinDark: [246, 162, 113],
  outline: [30, 12, 4],
};

// 각(도) -> 방향. 0이 아래(차렷), 시계방향이 +.
const dirOf = (deg) => {
  const a = deg * Math.PI / 180;
  return [-Math.sin(a), Math.cos(a)];
};

// 점에서 선분까지의 거리와, 선분 위 어디쯤인지(0~1)
function segDist(px, py, ax, ay, bx, by) {
  const vx = bx - ax, vy = by - ay;
  const L2 = vx * vx + vy * vy;
  let t = L2 ? ((px - ax) * vx + (py - ay) * vy) / L2 : 0;
  t = Math.max(0, Math.min(1, t));
  const dx = px - (ax + vx * t), dy = py - (ay + vy * t);
  return [Math.hypot(dx, dy), t];
}

// 굵기가 변하는 선분 하나. grow만큼 부풀려 외곽선으로도 쓴다.
function stroke(p, a, b, r0, r1, col, dark, light, grow) {
  const W = p.width, H = p.height;
  const rMax = Math.max(r0, r1) + grow + 1;
  const x0 = Math.max(0, Math.floor(Math.min(a[0], b[0]) - rMax));
  const x1 = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0]) + rMax));
  const y0 = Math.max(0, Math.floor(Math.min(a[1], b[1]) - rMax));
  const y1 = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1]) + rMax));
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const [d, t] = segDist(x + 0.5, y + 0.5, a[0], a[1], b[0], b[1]);
    const r = r0 + (r1 - r0) * t;
    if (d > r + grow) continue;
    const i = idx(p, x, y);
    // 그늘: 빛 반대쪽 바깥 1/3
    let c = col;
    if (dark) {
      const nx = (x + 0.5 - (a[0] + (b[0] - a[0]) * t)) / Math.max(1, r);
      const ny = (y + 0.5 - (a[1] + (b[1] - a[1]) * t)) / Math.max(1, r);
      if (nx * light[0] + ny * light[1] < -0.35) c = dark;
    }
    if (d > r) c = COL.outline;                 // 부풀린 만큼은 외곽선
    p.data[i] = c[0]; p.data[i + 1] = c[1]; p.data[i + 2] = c[2]; p.data[i + 3] = 255;
  }
}

// 팔 하나를 그린다. 어깨 -> 팔꿈치 -> 손목 -> 주먹.
function drawArm(p, cfg, phase) {
  const [sx, sy] = cfg.shoulder;
  const [a1, a2] = cfg.pose[phase];
  const d1 = dirOf(a1), d2 = dirOf(a2);
  const E = [sx + d1[0] * cfg.upper, sy + d1[1] * cfg.upper];
  const Wr = [E[0] + d2[0] * cfg.fore, E[1] + d2[1] * cfg.fore];
  const F = [Wr[0] + d2[0] * cfg.fistOut, Wr[1] + d2[1] * cfg.fistOut];
  const Sl = [sx + d1[0] * cfg.sleeve, sy + d1[1] * cfg.sleeve];
  const L = cfg.light;
  // 외곽선을 먼저 통째로 깔고(grow), 그 위에 속을 채운다(grow 0).
  // 그래야 마디 사이 이음매에 선이 끼어들지 않는다.
  const parts = [
    [[sx, sy], Sl, cfg.rSleeve, cfg.rSleeve * 0.94, COL.sleeve, COL.sleeveDark],
    [Sl, E, cfg.rArm * 1.02, cfg.rArm, COL.skin, COL.skinDark],
    [E, Wr, cfg.rArm, cfg.rWrist, COL.skin, COL.skinDark],
    [F, F, cfg.rFist, cfg.rFist, COL.skin, COL.skinDark],
  ];
  for (const [a, b, r0, r1] of parts)
    stroke(p, a, b, r0, r1, COL.outline, null, L, ARM_OUT);
  for (const [a, b, r0, r1, col, dk] of parts)
    stroke(p, a, b, r0, r1, col, dk, L, 0);
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

// 팔을 지우면, 팔과 몸통이 **나눠 쓰던** 외곽선의 바깥쪽이 몸에서 떨어져
// 가느다란 검은 선으로 남는다. 몸 색에 붙어 있지 않은 어두운 점을 걷어낸다.
//
// **팔이 있던 자리 안에서만** 본다. 온 그림에 대고 돌리면 머리카락과 부츠처럼
// 원래 어두운 덩어리가 통째로 갉인다 (실제로 그랬다).
function dropOrphanOutline(p, mask, near) {
  const W = p.width, H = p.height;
  const zone = new Uint8Array(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!mask[y * W + x]) continue;
    for (let dy = -near; dy <= near; dy++) for (let dx = -near; dx <= near; dx++) {
      const nx = x + dx, ny = y + dy;
      if (nx >= 0 && ny >= 0 && nx < W && ny < H) zone[ny * W + nx] = 1;
    }
  }
  for (let pass = 0; pass < OUTLINE_W + 2; pass++) {
    const kill = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (!zone[y * W + x]) continue;
      if (!solid(p, x, y) || !dark(p, x, y)) continue;
      let attached = false;
      for (let dy = -1; dy <= 1 && !attached; dy++)
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          if (solid(p, x + dx, y + dy) && !dark(p, x + dx, y + dy)) { attached = true; break; }
        }
      if (!attached) kill.push(idx(p, x, y));
    }
    if (!kill.length) break;
    for (const i of kill) p.data[i + 3] = 0;
  }
}


// 팔은 몸통 **앞을** 덮고 있다. 그냥 지우면 그 뒤에 있던 몸통까지 없어져
// 상체가 반쪽이 된다 (옆모습에서 셔츠 폭이 31px -> 15px로 줄었다).
// 지운 자리를 옆에 남은 몸 색으로 메워, 팔이 가리고 있던 몸통을 되살린다.
function fillBehind(p, mask) {
  const W = p.width, H = p.height;
  for (let pass = 0; pass < 60; pass++) {
    const add = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (!mask[y * W + x] || solid(p, x, y)) continue;
      // 옆(가로)에 붙은 몸 색을 가져온다. 세로로 번지면 셔츠가 반바지로 샌다
      for (const dx of [1, -1]) {
        const nx = x + dx;
        if (nx < 0 || nx >= W || !solid(p, nx, y) || dark(p, nx, y)) continue;
        add.push([idx(p, x, y), idx(p, nx, y)]);
        break;
      }
    }
    if (!add.length) break;
    for (const [di, si] of add) copyPx(p, si, p, di);
  }
}


function build(dir, phase) {
  const cfg = ARM[dir];
  const base = load(cfg.src);
  const W = base.width, H = base.height;
  const mask = grabOutline(base, capDisc(base,
    flood(base, cfg.seeds, cfg.bound), cfg.shoulder, cfg.cap), GRAB_W);
  // 1) 팔을 지운 몸
  const out = blank(W, H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
    if (!mask[y * W + x] && solid(base, x, y)) copyPx(base, idx(base, x, y), out, idx(out, x, y));
  // 지우고 남은 몸을 정리한다: 떨어진 외곽선 조각을 걷어내고,
  // 그러고 나서 몸 색이 드러난 자리에 외곽선을 새로 두른다
  dropOrphanOutline(out, mask, OUTLINE_W + 2);
  fillBehind(out, mask);          // 팔이 가리고 있던 몸통을 되살린다
  reOutline(out);

  // 2) 새 팔을 그린다
  drawArm(out, cfg, phase);

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
  const [sx, sy] = cfg.shoulder;
  const [a1, a2] = cfg.pose[phase];
  const d1 = dirOf(a1), d2 = dirOf(a2);
  const ex = sx + d1[0] * cfg.upper, ey = sy + d1[1] * cfg.upper;
  const fx = ex + d2[0] * (cfg.fore + cfg.fistOut);
  const fy = ey + d2[1] * (cfg.fore + cfg.fistOut);
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
