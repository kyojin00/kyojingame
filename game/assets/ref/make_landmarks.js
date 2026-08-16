// 랜드마크 생성기 — **고장마다 하나씩 서 있는 「엄청 큰 것」**.
//
// 세계를 네 배로 넓히고 나니 문제가 하나 생겼다. 넓어진 땅이 그냥 풀밭이라
// 걸어도 걸어도 같은 화면이다. 지역(REGIONS)으로 나무 밀도를 바꿔 봐야
// 「여기 나무가 좀 많네」에서 끝난다 — **가 볼 이유**가 안 된다.
//
// 그래서 고장마다 **한눈에 보이는 큰 것**을 하나씩 세운다. 멀리 화면
// 가장자리에 그것이 걸치는 순간 「저기 뭐지」가 되고, 그게 걸어갈 이유다.
//
//   greattree  큰나무 숲   — 산만 한 나무 한 그루 (화면 12.5칸 x 16.5칸)
//   falls      폭포골      — 두 단으로 쏟아지는 큰 폭포 (9.4칸 x 13칸)
//   spire      붉은바위    — 층층이 깎인 바위 기둥 (7.5칸 x 14.4칸)
//
// 도트 크기는 **건물·사람과 같다.** 논리 한 칸 = 원본 4px, 게임에서 0.5배로
// 얹으니 화면에서 2px이다 (make_buildings.js 와 같은 규칙). 이 규칙을 어기면
// 큰 것만 매끈해서 다른 게임에서 오려 붙인 그림이 된다.
//
// 큰 그림에서 특히 지키는 것:
//   * **실루엣이 먼저다.** 멀리서 보이는 것은 색이 아니라 윤곽이다
//   * 면은 세 톤 + 윤곽선. 크다고 톤을 늘리면 얼룩진 사진이 된다
//   * 결(무늬)은 **좌표로 묶어** 덩어리로 낸다. 점으로 흩으면 노이즈다
//   * 밑동은 땅에 앉는 자리다. 여기만 어둡게 깔아야 떠 보이지 않는다
//
// 실행:  node make_landmarks.js            -> ref/proposed_landmark_*.png
//        node make_landmarks.js --install  -> sprites/ 에 실제로 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');
const OUT = INSTALL ? SPR : REF;
const PRE = INSTALL ? '' : 'proposed_';

const S = 4;   // 논리 한 칸 = 원본 4px (화면에서 2px)

const PAL = {
  '.': null,
  'O':  [26, 22, 24],        // 윤곽선
  // ---- 나무껍질 (밝은 면 / 기본 / 그늘 / 깊은 골) ----
  'b0': [156, 118, 78], 'b1': [122, 88, 56], 'b2': [88, 62, 40], 'b3': [58, 40, 27],
  // ---- 잎 (다섯 단) — 위에서 빛을 받고 밑으로 갈수록 어둡다 ----
  'l0': [176, 220, 108], 'l1': [124, 186, 76], 'l2': [82, 150, 58],
  'l3': [50, 112, 44], 'l4': [28, 74, 34],
  // ---- 바위 (회색) ----
  'r0': [162, 158, 150], 'r1': [124, 120, 114], 'r2': [88, 85, 81],
  'r3': [58, 56, 54], 'r4': [38, 37, 36],
  // ---- 물 ----
  'w0': [236, 248, 254], 'w1': [186, 224, 246], 'w2': [124, 182, 226],
  'w3': [72, 134, 192], 'w4': [40, 90, 148],
  // ---- 이끼 ----
  'm0': [116, 164, 76], 'm1': [74, 118, 54], 'm2': [46, 80, 40],
  // ---- 붉은 바위 (사암) ----
  'k0': [226, 152, 96], 'k1': [192, 112, 68], 'k2': [152, 80, 50],
  'k3': [108, 54, 36], 'k4': [70, 34, 25],
  // ---- 그림자 (땅에 앉는 자리) ----
  'd0': [64, 78, 52], 'd1': [46, 58, 40],
};

// 결 — 좌표를 묶어야 덩어리가 된다. hash(x,y)는 점, hash(x>>3,y>>2)는 결.
function hash(x, y) {
  let h = (x * 73856093) ^ (y * 19349663);
  h = (h ^ (h >> 13)) & 0x7FFFFFFF;
  return ((h * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}

class G {
  constructor(w, h) {
    this.w = w; this.h = h;
    this.d = Array.from({ length: h }, () => new Array(w).fill('.'));
  }
  px(x, y, c) {
    x = Math.round(x); y = Math.round(y);
    if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.d[y][x] = c;
  }
  get(x, y) {
    x = Math.round(x); y = Math.round(y);
    return (x >= 0 && y >= 0 && x < this.w && y < this.h) ? this.d[y][x] : '.';
  }
  rect(x0, y0, x1, y1, c) {
    for (let y = Math.round(y0); y <= Math.round(y1); y++)
      for (let x = Math.round(x0); x <= Math.round(x1); x++) this.px(x, y, c);
  }
  hline(x0, x1, y, c) { this.rect(x0, y, x1, y, c); }
  vline(x, y0, y1, c) { this.rect(x, y0, x, y1, c); }
  // 타원 — 잎덩이·바위덩이의 기본 단위
  ellipse(cx, cy, rx, ry, c, only) {
    for (let y = Math.round(cy - ry); y <= Math.round(cy + ry); y++) {
      const t = (y - cy) / ry;
      if (Math.abs(t) > 1) continue;
      const half = rx * Math.sqrt(1 - t * t);
      for (let x = Math.round(cx - half); x <= Math.round(cx + half); x++) {
        if (only && !only.includes(this.get(x, y))) continue;
        this.px(x, y, c);
      }
    }
  }
  // 굵기가 변하는 뼈 — 가지·뿌리처럼 끝으로 갈수록 가늘어지는 것
  bone(x0, y0, x1, y1, w0, w1, c) {
    const n = Math.max(1, Math.round(Math.hypot(x1 - x0, y1 - y0) * 2));
    for (let i = 0; i <= n; i++) {
      const t = i / n;
      const x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t;
      const w = (w0 + (w1 - w0) * t) / 2;
      this.ellipse(x, y, w, w, c);
    }
  }
  // 비어 있는 칸 중 그림에 닿은 곳에 윤곽선을 두른다
  outline(c) {
    const add = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.d[y][x] !== '.') continue;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
        const g = this.get(nx, ny);
        if (g !== '.' && g !== c) { add.push([x, y]); break; }
      }
    }
    for (const [x, y] of add) this.px(x, y, c);
  }
  render() {
    const FW = this.w * S, FH = this.h * S;
    const im = new PNG({ width: FW, height: FH });
    im.data.fill(0);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const c = PAL[this.d[y][x]];
      if (!c) continue;
      for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
        const i = ((y * S + sy) * FW + (x * S + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
      }
    }
    return im;
  }
}

// 땅에 앉는 그림자 — 없으면 아무리 잘 그려도 공중에 떠 보인다.
// 밑동보다 넓게, 아주 납작하게 깐다 (해가 높이 떠 있는 낮의 그림자).
function groundShadow(g, cx, gy, rx) {
  g.ellipse(cx, gy - 1, rx, Math.max(2, rx * 0.16), 'd1', ['.']);
  g.ellipse(cx, gy - 2, rx * 0.72, Math.max(1, rx * 0.11), 'd0', ['d1']);
}


// ============================================================
// 1. 큰나무 — 산만 한 나무 한 그루
// ============================================================
//
// 「큰 나무」를 그리는 요령은 크기가 아니라 **비율**이다. 보통 나무를
// 그대로 늘리면 그냥 가까이 온 나무로 보인다. 진짜 노거수는
//   * 밑동이 뿌리째 벌어져 땅을 움켜쥐고 (판근)
//   * 줄기가 굵고 짧으며 낮은 데서 갈라지고
//   * 잎덩이가 여러 층으로 겹쳐 하나가 아니라 **숲처럼** 보인다
// 이 셋을 지키면 실루엣만으로 「오래되고 크다」가 읽힌다.
function greatTree() {
  const W = 200, H = 264, CX = 100, GY = H - 4;
  const g = new G(W, H);
  const FORK = 128;          // 줄기가 갈라지는 높이

  groundShadow(g, CX, GY, 62);

  // ---- 판근(板根) — 땅으로 벌어져 내리는 뿌리 ----
  // 밑동을 원기둥으로 끊으면 「기둥을 땅에 꽂았다」가 된다. 뿌리가
  // 부챗살로 벌어져야 나무가 땅에서 **자라 나온** 것으로 보인다.
  for (const [dx, dy, w] of [[-58, -3, 13], [-38, -10, 15], [-16, -14, 14],
                             [16, -14, 14], [40, -9, 15], [60, -2, 12]]) {
    g.bone(CX + dx * 0.24, GY - 26, CX + dx, GY + dy, 20, w, 'b1');
  }
  g.ellipse(CX, GY - 12, 46, 15, 'b1');

  // ---- 줄기 ----
  // 굵기는 위로 갈수록 줄지만 **곧지 않다** — 아주 완만하게 휜다.
  // 자로 그은 기둥은 전봇대로 보인다.
  const trunkHalf = (y) => {
    const t = (GY - y) / (GY - FORK);              // 0 밑동 → 1 갈래
    const base = 34 - 15 * Math.pow(t, 0.72);
    const flare = y > GY - 34 ? Math.pow((y - (GY - 34)) / 34, 2) * 22 : 0;
    return base + flare;
  };
  const trunkMid = (y) => CX + Math.sin((GY - y) / 58) * 5;
  for (let y = FORK; y <= GY; y++) {
    const mx = trunkMid(y), hw = trunkHalf(y);
    g.hline(mx - hw, mx + hw, y, 'b1');
  }

  // ---- 가지 ----
  // 갈래에서 위로 벌어지는 큰 팔 넷 + 잔가지. 잎덩이 속으로 파고들어야
  // 잎이 「가지에 달린 것」으로 읽힌다 (공중에 뜬 초록 구름이 아니라).
  const LIMB = [
    [-52, 62, 22, 8], [-30, 34, 24, 9], [30, 34, 24, 9], [54, 66, 22, 8],
    [-14, 22, 20, 8], [14, 20, 20, 8],
  ];
  for (const [dx, up, w0, w1] of LIMB) {
    const ex = CX + dx, ey = FORK - up;
    g.bone(CX + dx * 0.2, FORK + 12, ex, ey, w0, w1, 'b1');
    // 잔가지 둘 — 큰 팔 끝에서 다시 갈라진다
    g.bone(ex, ey, ex + dx * 0.34, ey - 20, w1, 3, 'b1');
    g.bone(ex, ey, ex - dx * 0.16, ey - 26, w1, 3, 'b1');
  }

  // ---- 껍질 결 ----
  // 세로로 길게 패인 골. 점으로 흩으면 이끼처럼 보이니 **세로줄**로 낸다.
  for (let y = FORK - 30; y <= GY; y++) {
    const mx = trunkMid(y), hw = trunkHalf(y);
    for (let x = Math.round(mx - hw); x <= Math.round(mx + hw); x++) {
      if (g.get(x, y) !== 'b1') continue;
      const rel = (x - mx) / Math.max(1, hw);       // -1 왼쪽 … +1 오른쪽
      // 빛은 왼쪽 위에서 온다 — 왼쪽 면이 밝고 오른쪽이 그늘
      let c = rel < -0.62 ? 'b0' : (rel > 0.5 ? 'b2' : 'b1');
      if (rel > 0.84) c = 'b3';
      const groove = hash(x >> 2, y >> 4);
      if (groove > 0.72) c = c === 'b0' ? 'b1' : (c === 'b1' ? 'b2' : 'b3');
      else if (groove < 0.13) c = c === 'b2' ? 'b1' : (c === 'b1' ? 'b0' : c);
      g.px(x, y, c);
    }
  }
  // 옹이 — 오래 산 나무에는 아문 자리가 있다
  for (const [ox, oy, r] of [[CX - 16, GY - 74, 7], [CX + 20, GY - 46, 5]]) {
    g.ellipse(ox, oy, r, r * 0.78, 'b3', ['b0', 'b1', 'b2']);
    g.ellipse(ox, oy, r * 0.55, r * 0.42, 'b2', ['b3']);
  }

  // ---- 잎덩이 ----
  // 큰 덩이 하나로 채우면 브로콜리가 된다. 진짜 노거수의 잎은 **가지마다
  // 따로 뭉쳐** 있고, 그 사이로 하늘이 뚫려 보인다. 그래서
  //   ① 덩이를 여럿 흩어 놓고
  //   ② 다 그린 뒤 **구멍을 뚫는다** (아래 HOLE)
  // 이 둘이 있어야 초록 사탕이 아니라 나무가 된다.
  const BLOB = [
    [100, 62, 54, 40], [58, 82, 42, 33], [142, 82, 42, 33],
    [100, 30, 44, 25], [56, 44, 34, 25], [144, 44, 34, 25],
    [28, 104, 26, 21], [172, 104, 26, 21], [100, 106, 56, 28],
    [72, 122, 26, 17], [128, 122, 26, 17],
  ];
  for (const [bx, by, rx, ry] of BLOB) g.ellipse(bx, by, rx, ry, 'l2');
  // 덩이와 덩이 **사이의 골**. 바깥에서 살짝만 베어 문다.
  //
  // 처음엔 크게 물어냈더니 크라운이 납작해져 버섯이 됐다. 노거수는
  // 위가 둥글다 — 갈라지는 곳은 옆구리와 밑이지 정수리가 아니다.
  // (한복판에도 하나 뚫어 봤는데 도넛 구멍처럼 보여서 뺐다 — 골은
  //  바깥 윤곽에서만 의미가 있다)
  for (const [bx, by, rx, ry] of [
    [26, 62, 15, 15], [174, 60, 15, 15],
    [46, 126, 15, 13], [154, 124, 15, 13],
  ]) g.ellipse(bx, by, rx, ry, '.', ['l2']);

  // 층 나누기 — 덩이마다 위쪽은 빛, 아래쪽은 그늘. 덩이 **단위로**
  // 밝기를 갈라야 겹친 것이 겹쳐 보인다 (전체 그러데이션은 한 덩이가 된다)
  for (const [bx, by, rx, ry] of BLOB) {
    g.ellipse(bx, by - ry * 0.30, rx * 0.86, ry * 0.60, 'l1', ['l2']);
    g.ellipse(bx - rx * 0.22, by - ry * 0.52, rx * 0.52, ry * 0.34, 'l0', ['l1']);
    g.ellipse(bx + rx * 0.10, by + ry * 0.46, rx * 0.80, ry * 0.48, 'l3', ['l2']);
    g.ellipse(bx + rx * 0.16, by + ry * 0.72, rx * 0.58, ry * 0.28, 'l4', ['l3']);
  }

  // 잎 결 — 서너 칸짜리 뭉텅이. 잎 한 장을 그리는 게 아니라 **다발**이다
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const c = g.d[y][x];
    if (c[0] !== 'l') continue;
    const h = hash(x >> 2, y >> 1);
    const step = { l0: ['l1', 'l0'], l1: ['l2', 'l0'], l2: ['l3', 'l1'],
                   l3: ['l4', 'l2'], l4: ['l4', 'l3'] }[c];
    if (h > 0.80) g.px(x, y, step[0]);
    else if (h < 0.17) g.px(x, y, step[1]);
  }
  // 잎덩이 가장자리를 톱니로 뜯는다 — 매끈한 타원은 풍선이 된다.
  // **세 번** 돌린다. 한 번은 한 칸밖에 못 먹어서 여전히 자로 그은 곡선이
  // 남는다. 세 번 돌리면 들쭉날쭉한 깊이가 서너 칸까지 벌어져 잎 다발의
  // 들쑥날쑥한 윤곽이 나온다 (매번 다른 씨앗을 써야 같은 자리만 안 판다)
  for (let pass = 0; pass < 3; pass++) {
    const eat = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (g.d[y][x][0] !== 'l') continue;
      let edge = false;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]])
        if (g.get(nx, ny) === '.') { edge = true; break; }
      if (edge && hash(x * 3 + 1 + pass * 97, y * 5 + 2) > 0.55) eat.push([x, y]);
    }
    for (const [x, y] of eat) g.px(x, y, '.');
  }

  // 잎 밖으로 내민 마른 가지 — 잎덩이를 뚫고 나온 가지 끝이 몇 개는 있어야
  // 잎이 「가지에 달린 것」으로 읽힌다. 초록 덩어리만 있으면 그건 덤불이다.
  //
  // 다만 잎 **위로** 그으면 안 된다. 처음에 통째로 얹었더니 초록 덩이를
  // 가로지르는 막대가 되어, 나무에 장대를 걸쳐 놓은 꼴이었다. 잎 속에서는
  // 가지가 안 보이는 게 맞다 — **잎 바깥으로 나온 토막만** 남긴다.
  {
    const tip = new G(W, H);
    for (const [x0, y0, x1, y1, w] of [
      [70, 116, 40, 134, 4], [130, 114, 162, 130, 4],
      [78, 52, 52, 22, 3], [124, 50, 150, 18, 3],
    ]) {
      tip.bone(x0, y0, x1, y1, w, 2, 'b2');
      tip.bone(x1, y1, x1 + (x1 - x0) * 0.22, y1 - 8, 2, 1, 'b2');
    }
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
      if (tip.d[y][x] !== '.' && g.d[y][x] === '.') g.px(x, y, 'b2');
  }

  // 나무 밑동 앞의 풀숲 — 뿌리와 땅이 만나는 자리를 덮는다
  for (let x = CX - 62; x <= CX + 62; x++) {
    const t = (x - CX) / 62;
    const top = GY - 4 - Math.round(Math.cos(t * 1.5) * 5 + hash(x >> 1, 3) * 3);
    for (let y = top; y <= GY; y++)
      if (g.get(x, y) === '.' || g.get(x, y) === 'd0' || g.get(x, y) === 'd1')
        g.px(x, y, hash(x, y >> 1) > 0.6 ? 'm0' : 'm1');
  }

  g.outline('O');
  return g;
}


// ============================================================
// 2. 큰 폭포 — 두 단으로 쏟아진다
// ============================================================
//
// 물만 그리면 파란 사각형이다. 폭포로 읽히게 하는 것은 **물이 아니라
// 그 둘레**다:
//   * 물을 좌우에서 물고 있는 검은 바위벽 (여기서 실루엣이 나온다)
//   * 마루에서 물이 **넘어가며** 둥글게 휘는 자리
//   * 떨어지는 물의 세로 줄기 — 굵기가 제각각이라야 흐르는 것 같다
//   * 밑에서 튀어 오르는 흰 물보라 (여기가 없으면 물이 땅에 스민다)
function bigFalls() {
  const W = 152, H = 212, CX = 76, GY = H - 4;
  const g = new G(W, H);
  const LIP = 26;            // 물이 넘어가는 마루
  const LEDGE = 128;         // 중간 단 (여기서 한 번 부딪혀 갈라진다)
  const POOL = 176;          // 물웅덩이 수면

  // ---- 바위벽 ----
  //
  // 처음엔 판 전체를 바위로 채웠다. 그랬더니 **네모난 바위 사진**을 풀밭에
  // 붙여 놓은 꼴이 됐다 — 잔디와 만나는 자리가 자로 그은 직선이라
  // 세계의 일부로 안 읽힌다.
  //
  // 바위는 **덩어리(massif)** 다. 위는 좁고 밑으로 갈수록 벌어지며,
  // 바깥 윤곽은 들쭉날쭉하다. 그 실루엣이 먼저 보여야 「절벽에서 물이
  // 떨어진다」가 된다.
  const massifHalf = (y) => {
    const t = Math.min(1, Math.max(0, y / POOL));
    return 24 + Math.pow(t, 0.62) * (W / 2 - 20);
  };
  // 물길 — 아래로 갈수록 벌어진다 (평행하면 수로가 된다)
  const gapAt = (y) => 24 + (y - LIP) * 0.19;
  // 마루 위(멀리 보이는 윗물)의 물길은 좁다 — 좁은 내가 흘러와 넓게
  // 퍼지며 떨어져야 「쏟아진다」가 산다
  const chanAt = (y) => 15 + (y / LIP) * 9;
  for (let y = 0; y <= POOL; y++) {
    // 바깥 윤곽은 **크게** 들쭉날쭉해야 한다. 잔털처럼 흔들면 매끈한
    // 달걀에 지저분한 테두리만 두른 꼴이 된다 — 덩이째 물러나야 바위다
    const half = massifHalf(y)
      + Math.round(hash(0, y >> 4) * 11) - 5 + Math.round(hash(1, y >> 2) * 3) - 1;
    const gap = y < LIP ? chanAt(y) : gapAt(y);
    const wob = y < LIP ? 1 : 3;
    const lx = CX - gap - 2 - Math.round(Math.sin(y * 0.11) * wob);
    const rx = CX + gap + 2 + Math.round(Math.sin(y * 0.09 + 2) * wob);
    g.rect(CX - half, y, lx, y, y < LIP ? 'r3' : 'r2');
    g.rect(rx, y, CX + half, y, y < LIP ? 'r3' : 'r2');
  }

  // 바위 결 — 가로로 층이 진 퇴적암. 세로줄은 물과 헷갈린다
  for (let y = 0; y <= POOL; y++) for (let x = 0; x < W; x++) {
    if (g.d[y][x] !== 'r2' && g.d[y][x] !== 'r3') continue;
    const dark = g.d[y][x] === 'r3';
    const band = hash(0, y >> 2);
    let c = dark ? 'r3' : 'r2';
    if (band > 0.74) c = dark ? 'r4' : 'r3';
    else if (band < 0.20) c = dark ? 'r2' : 'r1';
    // 물길 쪽 모서리는 물보라에 젖어 밝다
    const edgeL = CX - gapAt(y) - 6, edgeR = CX + gapAt(y) + 6;
    if (!dark && (x > edgeL && x < CX) || (!dark && x < edgeR && x > CX)) {
      if (Math.min(Math.abs(x - edgeL), Math.abs(x - edgeR)) < 5) c = 'r1';
    }
    if (hash(x >> 2, y >> 1) > 0.86) c = c === 'r1' ? 'r0' : 'r1';
    g.px(x, y, c);
  }
  // 벽에 낀 이끼 — 늘 젖어 있는 바위에는 이끼가 산다. 물길 가장자리에만
  for (let y = LIP + 6; y <= POOL - 4; y++) {
    for (const side of [-1, 1]) {
      const ex = Math.round(CX + side * (gapAt(y) + 3));
      for (let d = 0; d < 6; d++) {
        const x = ex + side * d;
        if (g.get(x, y)[0] !== 'r') continue;
        const hh = hash(x >> 1, y >> 2);
        if (hh > 0.55 - d * 0.07) g.px(x, y, hh > 0.82 ? 'm0' : (hh > 0.68 ? 'm1' : 'm2'));
      }
    }
  }

  // ---- 물 ----
  // 마루 위 잔잔한 물 → 넘어가는 자리에서 둥글게 휨 → 세로로 떨어짐
  for (let y = 2; y < LIP; y++) {
    const gap = chanAt(y);
    g.rect(CX - gap, y, CX + gap, y, y > LIP - 5 ? 'w1' : 'w2');
  }
  // 떨어지는 물기둥
  for (let y = LIP; y <= POOL; y++) {
    const gap = gapAt(y) - 1;
    g.rect(CX - gap, y, CX + gap, y, 'w2');
  }
  // 물 줄기 — 굵기와 밝기가 제각각인 세로 띠. 이게 「흐름」을 만든다
  for (let y = LIP; y <= POOL; y++) for (let x = 0; x < W; x++) {
    if (g.d[y][x] !== 'w2') continue;
    const rel = (x - CX) / Math.max(1, gapAt(y));
    // 줄기는 x 로 묶고 y 로는 길게 이어진다 (y>>5 — 아주 완만하게만 변한다)
    const streak = hash(x >> 1, y >> 5);
    let c = 'w2';
    if (streak > 0.78) c = 'w1';
    else if (streak > 0.92) c = 'w0';
    else if (streak < 0.22) c = 'w3';
    // 양쪽 가장자리는 벽에 스쳐 하얗게 부서진다
    if (Math.abs(rel) > 0.82) c = hash(x, y) > 0.4 ? 'w1' : 'w0';
    // 가운데 굵은 본류는 짙다 (두꺼운 물은 색이 깊다)
    if (Math.abs(rel) < 0.24 && streak < 0.6) c = 'w3';
    g.px(x, y, c);
  }
  // 마루에서 넘어가는 자리 — 물이 둥글게 말리며 흰 선이 선다
  for (let x = 0; x < W; x++) {
    for (let d = 0; d < 4; d++) {
      const y = LIP + d;
      if (g.get(x, y)[0] !== 'w') continue;
      g.px(x, y, d < 2 ? 'w0' : 'w1');
    }
  }

  // ---- 중간 단 ----
  // 한 단에서 부딪혀 갈라져야 폭포에 「높이」가 생긴다. 통짜로 떨어지면
  // 아무리 길어도 파란 띠 하나다
  const lg = gapAt(LEDGE);
  g.ellipse(CX - lg - 2, LEDGE, 13, 6, 'r2');
  g.ellipse(CX + lg + 2, LEDGE + 4, 12, 6, 'r2');
  g.ellipse(CX - lg - 2, LEDGE - 2, 11, 4, 'r1', ['r2']);
  g.ellipse(CX + lg + 2, LEDGE + 2, 10, 4, 'r1', ['r2']);
  // 부딪힌 자리의 물보라
  for (const [sx, sy] of [[CX - lg + 4, LEDGE - 4], [CX + lg - 4, LEDGE]]) {
    g.ellipse(sx, sy, 11, 5, 'w0', ['w1', 'w2', 'w3']);
    g.ellipse(sx, sy + 4, 13, 4, 'w1', ['w2', 'w3']);
  }

  // ---- 물웅덩이와 물보라 ----
  // 웅덩이도 네모로 깔면 안 된다 — 바위 덩어리 안에 파인 못이라야
  // 그림 밑변이 잔디와 직선으로 만나지 않는다
  for (let y = POOL; y <= GY; y++) {
    const half = massifHalf(POOL) - 4 - (y - POOL) * 0.9 + hash(0, y) * 4;
    g.rect(CX - half, y, CX + half, y, 'w3');
  }
  for (let y = POOL; y <= GY; y++) for (let x = 0; x < W; x++) {
    if (g.d[y][x] !== 'w3') continue;
    // 웅덩이는 잔물결 — 가로로 눕는다 (세로로 두면 아직 떨어지는 물이 된다)
    const hh = hash(x >> 2, y);
    g.px(x, y, hh > 0.80 ? 'w2' : (hh < 0.18 ? 'w4' : 'w3'));
  }
  // 떨어진 자리에서 피어오르는 흰 물보라 — 폭포의 밑동이다
  for (let i = 0; i < 26; i++) {
    const t = i / 25;
    const px = CX + Math.sin(i * 2.3) * (gapAt(POOL) + 10) * (0.35 + t * 0.65);
    const py = POOL - 2 + Math.cos(i * 1.7) * 9;
    const r = 5 + hash(i, 7) * 7;
    g.ellipse(px, py, r, r * 0.55, hash(i, 3) > 0.45 ? 'w0' : 'w1');
  }
  // 웅덩이에 퍼지는 흰 테 — 물보라가 물에 닿는 자리
  for (let i = 0; i < 5; i++) {
    const ry = 5 + i * 4;
    g.ellipse(CX, POOL + 4 + i * 4, gapAt(POOL) + 8 + i * 6, ry * 0.32,
      i < 2 ? 'w0' : 'w1', ['w2', 'w3', 'w4']);
  }
  // 웅덩이 앞의 젖은 바위 몇 덩이 — 물가에 놓여야 웅덩이에 깊이가 생긴다
  for (const [rx2, ry2, r] of [[CX - 40, GY - 12, 11], [CX + 38, GY - 9, 9], [CX + 12, GY - 3, 7]]) {
    g.ellipse(rx2, ry2, r, r * 0.62, 'r2');
    g.ellipse(rx2 - r * 0.2, ry2 - r * 0.24, r * 0.6, r * 0.34, 'r1', ['r2']);
  }

  g.outline('O');
  return g;
}


// ============================================================
// 3. 붉은 바위 기둥 — 층층이 깎여 남은 것
// ============================================================
//
// 바람과 물이 무른 층을 먼저 파먹고 단단한 층만 남으면 기둥이 된다.
// 그래서 **허리가 잘록하고 머리가 넓다**. 위아래 굵기가 같으면 굴뚝이다.
function rockSpire() {
  const W = 124, H = 232, CX = 62, GY = H - 4;
  const g = new G(W, H);

  groundShadow(g, CX, GY, 40);

  // 굵기 — **잘록하게 하되 좌우 대칭으로는 안 된다.**
  //
  // 처음엔 허리를 깊게 파고 위아래를 똑같이 벌렸더니 도자기(꽃병)가 됐다.
  // 자연이 깎은 바위는 한쪽이 더 파이고, 켜마다 무른 층이 다르게 물러나
  // **계단처럼 들쭉날쭉**하다. 그래서
  //   ① 허리를 얕게만 파고 (30 -> 22)
  //   ② 켜마다 좌우로 다르게 물러나게 하고 (notch)
  //   ③ 기둥 전체를 조금 기울인다 (lean) — 곧추선 것은 사람이 세운 것이다
  const TOP = 22;
  const lean = (y) => (GY - y) / (GY - TOP) * 7;   // 위로 갈수록 오른쪽으로
  const halfAt = (y) => {
    const t = (GY - y) / (GY - TOP);              // 0 밑동 → 1 꼭대기
    const waist = 30 - 10 * Math.sin(Math.min(1, t / 0.74) * Math.PI * 0.5);
    const cap = t > 0.80 ? Math.pow((t - 0.80) / 0.20, 1.2) * 11 : 0;
    const foot = t < 0.13 ? Math.pow((0.13 - t) / 0.13, 2) * 10 : 0;
    return Math.max(6, waist + cap + foot);
  };
  const midAt = (y) => CX + lean(y) + Math.sin((GY - y) / 66) * 3;

  // ---- 지층 ----
  //
  // 여기가 이 그림의 전부다. 켜를 **무늬로** 그리면 안 된다 — 켜마다
  // 실제로 **폭이 달라야** 한다. 무른 켜는 바람에 더 파여 안으로 들어가고
  // 단단한 켜는 처마처럼 남는다. 그 층계가 후두(hoodoo)의 생김새다.
  //
  // 폭이 같은 기둥에 가로줄만 그으면, 아무리 색을 잘 써도 **돌기둥**이
  // 아니라 사람이 세운 **돌기둥 조각**(로마 기둥)으로 보인다.
  const BANDS = [];
  for (let y = TOP, i = 0; y <= GY; i++) {
    const th = 4 + Math.round(hash(i, 11) * 8);
    const mid = midAt(y + th / 2), base = halfAt(y + th / 2);
    const hard = hash(i, 31);                  // 1에 가까울수록 단단한 켜
    const bite = Math.pow(1 - hard, 1.3) * 11; // 무른 켜가 물러난 깊이
    BANDS.push({
      y0: y, y1: Math.min(GY, y + th), mid: mid,
      l: base - bite * (0.35 + hash(i, 41) * 0.65),
      r: base - bite * (0.35 + hash(i, 43) * 0.65),
      tone: hash(i, 5), hard: hard,
    });
    y += th + 1;
  }
  for (const b of BANDS) g.rect(b.mid - b.l, b.y0, b.mid + b.r, b.y1, 'k2');
  // 켜와 켜 사이의 틈을 메운다 (한 줄씩 비워 두면 기둥이 토막 난다) —
  // 좁은 쪽 폭으로 이어 붙이면 그 자리가 저절로 그늘진 골이 된다
  for (let i = 0; i + 1 < BANDS.length; i++) {
    const a = BANDS[i], c = BANDS[i + 1];
    g.rect(Math.max(a.mid - a.l, c.mid - c.l), a.y1,
           Math.min(a.mid + a.r, c.mid + c.r), c.y0, 'k2');
  }

  for (const b of BANDS) {
    const tone = b.tone;
    for (let y = b.y0; y <= b.y1 + 1; y++) {
      const mx = b.mid, hw = Math.max(b.l, b.r);
      for (let x = Math.round(mx - hw - 2); x <= Math.round(mx + hw + 2); x++) {
        if (g.get(x, y) !== 'k2') continue;
        const rel = (x - mx) / Math.max(1, hw);
        // 빛은 왼쪽 위. 오른쪽 세 번째부터 그늘로 넘어간다
        let c = rel < -0.55 ? 'k1' : (rel > 0.34 ? 'k3' : 'k2');
        if (rel > 0.80) c = 'k4';
        if (rel < -0.86) c = 'k0';
        if (tone > 0.70) c = { k0: 'k1', k1: 'k2', k2: 'k3', k3: 'k4', k4: 'k4' }[c];
        else if (tone < 0.24) c = { k0: 'k0', k1: 'k0', k2: 'k1', k3: 'k2', k4: 'k3' }[c];
        if (hash(x >> 2, y) > 0.87) c = { k0: 'k1', k1: 'k0', k2: 'k1', k3: 'k2', k4: 'k3' }[c];
        g.px(x, y, c);
      }
    }
    // 단단한 켜의 밑은 처마가 되어 그늘이 진다 — 켜가 **내밀었다**를
    // 말하는 한 줄. 켜 폭 차이만으로는 눈이 단차를 잘 못 읽는다
    if (b.hard > 0.55) {
      g.hline(b.mid - b.l + 1, b.mid + b.r - 1, b.y1, 'k4');
      g.hline(b.mid - b.l + 2, b.mid + b.r - 2, b.y1 + 1, 'k3');
    }
  }

  // ---- 꼭대기 갓돌 ----
  // 단단한 층 하나가 모자처럼 얹혀 있어 그 밑이 안 깎였다 — 이 기둥이
  // 남은 이유다. 그래서 **처마처럼 내밀어야** 한다. 둥근 뚜껑을 얹으면
  // 병마개가 되고, 왜 안 깎였는지가 안 보인다.
  // 다만 **자로 잰 네모**로 얹으면 로마 기둥의 머리(주두)가 된다.
  // 갓돌도 깨진 돌이다 — 윗면이 기울고, 좌우로 내민 길이가 다르다.
  const capX = midAt(TOP), capW = halfAt(TOP) + 5;
  for (let x = Math.round(capX - capW - 4); x <= Math.round(capX + capW + 2); x++) {
    const t = (x - (capX - capW)) / (capW * 2);
    // 윗면은 오른쪽으로 살짝 기운다 + 가장자리가 조금씩 깨져 있다
    const top = TOP - 11 + t * 3 + Math.round(hash(x >> 1, 51) * 2);
    const bot = TOP + 2 + (x < capX ? 1 : 0);
    g.rect(x, top, x, bot, 'k2');
  }
  // 내민 처마 밑은 늘 그늘 — 이 두 줄이 「내밀었다」를 만든다
  g.hline(capX - capW - 3, capX + capW + 1, TOP + 2, 'k4');
  g.hline(capX - capW - 1, capX + capW - 1, TOP + 3, 'k4');
  // 갓돌 윗면의 잔금
  for (let i = 0; i < 9; i++) {
    const bx = capX - capW + hash(i, 21) * capW * 2;
    const by = TOP - 9 + Math.round(hash(i, 25) * 3);
    g.vline(bx, by, by + 1 + Math.round(hash(i, 23) * 2), 'k3');
  }
  // 갓돌 위의 마른 풀 한 줌
  for (let i = -6; i <= 6; i++) {
    const bx = capX + i * 3.0 + hash(i + 9, 4) * 2;
    const by = TOP - 10 + (i + 6) * 0.24;
    g.vline(bx, by - 4 - Math.round(hash(i + 9, 2) * 4), by, 'm1');
  }

  // ---- 밑동의 너덜 ----
  // 깎여 떨어진 조각들이 발치에 쌓여야 「깎여 나갔다」가 보인다
  for (let i = 0; i < 22; i++) {
    const side = i % 2 ? 1 : -1;
    const dx = side * (16 + hash(i, 13) * 40);
    const r = 3 + hash(i, 17) * 6;
    const y = GY - 2 - hash(i, 19) * 7;
    g.ellipse(CX + dx, y, r, r * 0.62, 'k3', ['.', 'd0', 'd1']);
    g.ellipse(CX + dx - r * 0.24, y - r * 0.26, r * 0.58, r * 0.32, 'k2', ['k3']);
  }

  g.outline('O');
  return g;
}


// ---- 내보내기 ----
const WORKS = {
  landmark_greattree: greatTree,
  landmark_falls: bigFalls,
  landmark_spire: rockSpire,
};
const made = [];
for (const [name, fn] of Object.entries(WORKS)) {
  const g = fn();
  const im = g.render();
  fs.writeFileSync(OUT + PRE + name + '.png', PNG.sync.write(im));
  made.push([name, im.width, im.height]);
  console.log('%s  %dx%d px  (화면 %d x %d px = %.1f x %.1f 칸)',
    name, im.width, im.height, im.width / 2, im.height / 2,
    im.width / 64, im.height / 64);
}

// 한 장에 나란히 — 크기 비교가 되어야 「엄청 크다」가 맞는지 눈으로 본다.
// 곁에 주인공(2 x 3칸)을 세워 둔다. 사람 없이 큰 것만 보면 큰지 알 수 없다.
{
  const pad = 16;
  let tw = pad, th = 0;
  const ims = made.map(([n]) => PNG.sync.read(fs.readFileSync(OUT + PRE + n + '.png')));
  for (const im of ims) { tw += im.width + pad; th = Math.max(th, im.height); }
  tw += 64 + pad;                       // 주인공 자리
  const cmp = new PNG({ width: tw, height: th + pad * 2 });
  for (let i = 0; i < cmp.data.length; i += 4) {
    cmp.data[i] = 122; cmp.data[i + 1] = 152; cmp.data[i + 2] = 104; cmp.data[i + 3] = 255;
  }
  let x = pad;
  for (const im of ims) {
    for (let y = 0; y < im.height; y++) for (let xx = 0; xx < im.width; xx++) {
      const si = (y * im.width + xx) * 4;
      if (im.data[si + 3] === 0) continue;
      const di = ((y + pad + (th - im.height)) * cmp.width + (x + xx)) * 4;
      cmp.data[di] = im.data[si]; cmp.data[di + 1] = im.data[si + 1];
      cmp.data[di + 2] = im.data[si + 2]; cmp.data[di + 3] = 255;
    }
    x += im.width + pad;
  }
  // 주인공 실루엣 (64x96 화면px -> 이 판에서는 원본 배율이라 128x192)
  for (let y = 0; y < 192; y++) for (let xx = 0; xx < 64; xx++) {
    const di = ((y + pad + th - 192) * cmp.width + (x + 32 + xx)) * 4;
    cmp.data[di] = 40; cmp.data[di + 1] = 48; cmp.data[di + 2] = 60;
  }
  fs.writeFileSync(REF + 'preview_landmarks.png', PNG.sync.write(cmp));
  console.log('preview_landmarks.png  (맨 오른쪽 검은 실루엣이 주인공 크기)');
}
