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
//   falls      폭포골      — 두 단으로 쏟아지는 큰 폭포 (12.5칸 x 13칸)
//   spire      붉은바위    — 층층이 깎인 바위 기둥 (7.75칸 x 14.5칸)
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
// ---- 움직인다 ----
//
// 폭포가 안 흐르면 그건 폭포 그림이지 폭포가 아니다. 세워 두는 것마다
// **몇 장씩** 뽑아 게임에서 돌린다 (main.gd 의 lm_frame).
//
//   falls      4장  물줄기가 흘러내리고, 물보라가 부풀고, 못에 물결이 간다
//   greattree  3장  잎덩이가 흔들린다 — 위로 갈수록 크게 (덩굴도 같이)
//   spire      2장  꼭대기 마른 풀이 눕고, 앉은 새가 날개를 친다
//
// 물줄기는 **딱 맞아떨어지게** 흘려야 한다. 결의 세로 폭이 8이고 한 장에
// 6씩 내리면 네 장에 24 — 8의 배수라 네 장째가 첫 장과 이어진다.
// 안 맞으면 한 바퀴 돌 때마다 물이 한 번씩 튄다.
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
  //
  // **게임의 물에서 그대로 가져왔다** (make_ground.js 의 WATER 사다리).
  // 처음엔 내가 고른 하늘빛 파랑이었는데, 폭포 밑에 게임이 깔아 놓은
  // 연못 타일과 나란히 놓이니 물 두 가지가 만난 꼴이었다 — 폭포만
  // 환하고 못은 검푸르러서, 폭포가 못 위에 붙인 종이로 보였다.
  //
  // 사다리 자리도 뜻이 다르다:
  //   w0 물보라(FOAM) · w1~w3 **떨어지는 물** (공기가 섞여 밝다)
  //   w4~w6 **고인 물** (게임 연못과 같은 단 — 여기서 이어 붙는다)
  'w0': [244, 250, 252],                                  // FOAM
  'w1': [142, 204, 230], 'w2': [104, 174, 212],           // WATER[0..1]
  'w3': [72, 142, 190], 'w4': [34, 84, 130],              // WATER[2], WATER[4]
  'w5': [22, 60, 100], 'w6': [14, 42, 74],                // WATER[5..6] 깊은 물
  // ---- 이끼 ----
  'm0': [116, 164, 76], 'm1': [74, 118, 54], 'm2': [46, 80, 40],
  // ---- 붉은 바위 (사암) ----
  'k0': [226, 152, 96], 'k1': [192, 112, 68], 'k2': [152, 80, 50],
  'k3': [108, 54, 36], 'k4': [70, 34, 25],
  // ---- 그림자 (땅에 앉는 자리) ----
  'd0': [64, 78, 52], 'd1': [46, 58, 40],
  // ---- 곁들이 ----
  'f0': [246, 232, 128], 'f1': [232, 176, 72],   // 꽃·열매
  'u0': [232, 214, 190], 'u1': [196, 108, 92],   // 버섯 (갓·대)
  'n0': [58, 46, 34],                             // 나무 구멍 속 (제일 어두운 데)
  'i0': [246, 246, 250], 'i1': [64, 60, 72],      // 새 (몸·부리)
  // 무지개 — 물보라에 뜬다. 옅게만 (진하면 스티커가 된다)
  'c0': [232, 152, 132], 'c1': [232, 206, 132], 'c2': [156, 214, 152],
  'c3': [140, 186, 226],
};

// 결 — 좌표를 묶어야 덩어리가 된다. hash(x,y)는 점, hash(x>>3,y>>2)는 결.
function hash(x, y) {
  let h = (x * 73856093) ^ (y * 19349663);
  h = (h ^ (h >> 13)) & 0x7FFFFFFF;
  return ((h * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}

// 한 단 어둡게 — 그늘을 던질 때 쓴다. 색을 새로 만들지 않고 **팔레트의
// 다음 단**으로 내려야 그림 전체가 같은 색조로 묶인다
const DARKER = {
  l0: 'l1', l1: 'l2', l2: 'l3', l3: 'l4', l4: 'l4',
  b0: 'b1', b1: 'b2', b2: 'b3', b3: 'b3',
  r0: 'r1', r1: 'r2', r2: 'r3', r3: 'r4', r4: 'r4',
  k0: 'k1', k1: 'k2', k2: 'k3', k3: 'k4', k4: 'k4',
  w0: 'w1', w1: 'w2', w2: 'w3', w3: 'w4', w4: 'w5', w5: 'w6', w6: 'w6',
  m0: 'm1', m1: 'm2', m2: 'm2', u0: 'u1', u1: 'u1',
  f0: 'f1', f1: 'f1', d0: 'd1', d1: 'd1', O: 'O', n0: 'n0',
};

// 한 단 밝게 — 큰 덩어리의 빛을 얹을 때 쓴다
const LIGHTER = {
  l0: 'l0', l1: 'l0', l2: 'l1', l3: 'l2', l4: 'l3',
  b0: 'b0', b1: 'b0', b2: 'b1', b3: 'b2',
  r0: 'r0', r1: 'r0', r2: 'r1', r3: 'r2', r4: 'r3',
  k0: 'k0', k1: 'k0', k2: 'k1', k3: 'k2', k4: 'k3',
  w0: 'w0', w1: 'w0', w2: 'w1', w3: 'w2', w4: 'w3', w5: 'w4', w6: 'w5',
  m0: 'm0', m1: 'm0', m2: 'm1',
};

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
  // 드리운 그늘 — 덩이가 **제 뒤에 있는 것 위로** 그림자를 던진다.
  //
  // 큰 그림이 납작해 보이는 진짜 이유는 톤이 모자라서가 아니다. 덩이마다
  // 밝기를 잘 나눠 놔도, 덩이끼리 그림자를 안 주고받으면 전부 **같은
  // 평면에 붙은 무늬**로 읽힌다. 하나가 다른 하나를 덮고 그 위에 그늘을
  // 던져야 그제서야 「앞뒤가 있다」가 된다.
  //
  // 그래서 덩이는 **뒤에서 앞으로** 그린다. 하나 그리기 직전에 그 덩이의
  // 그림자를 먼저 던지면, 그 그림자는 이미 그려진 것(=뒤에 있는 것) 위에만
  // 앉는다. 순서 하나로 앞뒤가 저절로 맞는다.
  // dither < 1 이면 그만큼만 어둡게 한다. **깨끗한 타원 그림자는 쓰면 안
  // 된다** — 잎덩이 밑에 접시를 깔아 놓은 것처럼 층층이 겹쳐 보인다.
  // 성글게 찍어야 잎 사이로 새는 볕이 되고, 그게 나뭇잎 그늘이다.
  castEllipse(cx, cy, rx, ry, dither = 1.0, depth = 1) {
    for (let y = Math.round(cy - ry); y <= Math.round(cy + ry); y++) {
      const t = (y - cy) / ry;
      if (Math.abs(t) > 1) continue;
      // 가장자리로 갈수록 옅어진다 (그림자에도 가장자리가 있다)
      const half = rx * Math.sqrt(1 - t * t);
      for (let x = Math.round(cx - half); x <= Math.round(cx + half); x++) {
        let c = this.get(x, y);
        if (c === '.') continue;
        const edge = Math.hypot((x - cx) / rx, (y - cy) / ry);
        if (hash(x * 7 + 3, y * 5 + 1) > dither * (1.25 - edge * 0.55)) continue;
        for (let d = 0; d < depth; d++) c = DARKER[c] || c;
        this.px(x, y, c);
      }
    }
  }
  // 비어 있는 칸 중 그림에 닿은 곳에 윤곽선을 두른다
  // skip 에 든 색에는 테를 안 두른다.
  //
  // 고인 물이 그렇다. 세계가 이 그림 둘레에 **진짜 물 타일**을 깔아 두므로,
  // 못 가장자리에 검은 선을 그으면 물 한복판에 구멍이 뚫린 것처럼 보인다.
  // 바위·나무처럼 물건인 것만 테를 두른다.
  outline(c, skip = []) {
    const add = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.d[y][x] !== '.') continue;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
        const g = this.get(nx, ny);
        if (g !== '.' && g !== c && !skip.includes(g)) { add.push([x, y]); break; }
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
function greatTree(f, NF) {
  const W = 200, H = 264, CX = 100, GY = H - 4;
  const g = new G(W, H);
  const FORK = 128;          // 줄기가 갈라지는 높이
  // 바람 — 줄기는 안 흔들리고 **위로 갈수록** 크게 흔들린다.
  // 나무를 통째로 밀면 뿌리째 뽑혀 옮겨 다니는 것처럼 보인다.
  const phase = (f / NF) * Math.PI * 2;
  const sway = (y) => Math.sin(phase) * 3.2 * Math.max(0, (FORK - y) / FORK);

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

  // ---- 줄기와 뿌리의 **부피** ----
  //
  // 줄기는 원기둥이다. 왼쪽 밝고 오른쪽 어둡게만 해서는 부피가 안 산다 —
  // 그건 「반씩 칠한 판때기」다. 원기둥이 원기둥으로 보이려면 다섯 켜가
  // 다 있어야 한다:
  //
  //   ① 하이라이트   빛 쪽으로 살짝 치우친 **좁은** 띠 (넓으면 납작해진다)
  //   ② 밝은 면
  //   ③ 중간
  //   ④ 코어 섀도    제일 어두운 데. **가장자리가 아니라 안쪽**이다
  //   ⑤ 되비침       그늘 쪽 맨 끝. 땅과 하늘에서 튕겨 온 빛이라 한 단 밝다
  //
  // ④와 ⑤가 핵심이다. 그늘 쪽 끝까지 새카맣게 두면 기둥이 **잘려** 보이고,
  // 끝을 한 단 올리면 그 순간 뒤로 말려 들어간다.
  //
  // 뿌리도 같은 규칙으로 칠한다. 예전에는 줄기 폭 안쪽만 칠해서, 밖으로
  // 벌어진 판근이 통째로 한 색 — 나무 밑동에 갈색 종이를 오려 붙인 꼴이었다.
  const barrel = (rel) => {
    const a = Math.abs(rel);
    if (rel < -0.72) return 'b1';       // 왼쪽 끝 — 빛을 스쳐 지나 조금 어둡다
    if (rel < -0.28) return 'b0';       // ① 하이라이트
    if (rel < 0.16) return 'b1';        // ② 밝은 면
    if (rel < 0.52) return 'b2';        // ③ 중간
    if (rel < 0.86) return 'b3';        // ④ 코어 섀도
    return 'b2';                        // ⑤ 되비침
  };
  for (let y = FORK - 34; y <= GY; y++) {
    const mx = trunkMid(y), hw = trunkHalf(y);
    for (let x = Math.round(mx - hw - 26); x <= Math.round(mx + hw + 26); x++) {
      if (g.get(x, y) !== 'b1') continue;
      // 뿌리 쪽은 줄기보다 넓다 — 그 칸의 **실제 폭**을 재서 나눈다
      let lft = x, rgt = x;
      while (g.get(lft - 1, y)[0] === 'b') lft--;
      while (g.get(rgt + 1, y)[0] === 'b') rgt++;
      const w2 = Math.max(1, (rgt - lft) / 2);
      const rel = (x - (lft + rgt) / 2) / w2;
      let c = barrel(rel);
      // 껍질 골 — 세로로 길게 (점으로 흩으면 이끼처럼 보인다)
      const groove = hash(x >> 2, y >> 4);
      if (groove > 0.72) c = DARKER[c] || c;
      else if (groove < 0.13) c = { b0: 'b0', b1: 'b0', b2: 'b1', b3: 'b2' }[c] || c;
      g.px(x, y, c);
    }
  }
  // 잎덩이가 줄기에 던지는 그늘 — 나무에서 제일 큰 그림자다.
  // 이게 없으면 잎이 줄기 **뒤**가 아니라 **옆**에 붙은 것처럼 보인다
  for (let y = FORK - 20; y <= FORK + 34; y++) {
    const t = 1 - Math.min(1, (y - (FORK - 20)) / 54);
    const mx = trunkMid(y), hw = trunkHalf(y);
    for (let x = Math.round(mx - hw); x <= Math.round(mx + hw); x++) {
      if (g.get(x, y)[0] !== 'b') continue;
      if (hash(x >> 1, y >> 2) < t * 0.85) g.px(x, y, DARKER[g.get(x, y)]);
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
  ].map(([bx, by, rx, ry]) => [bx + sway(by), by, rx, ry]);

  // **뒤에서 앞으로** 그린다 (화면에서 위에 있는 덩이가 뒤다).
  // 하나 그리기 직전에 그 덩이의 그림자를 먼저 던져 두면, 그림자는 이미
  // 그려진 뒤쪽 덩이 위에만 앉는다 — 순서 하나로 앞뒤가 맞는다.
  const ORDER = BLOB.slice().sort((a, b) => a[1] - b[1]);
  for (const [bx, by, rx, ry] of ORDER) {
    // 빛은 왼쪽 위에서 온다 -> 그늘은 오른쪽 아래로 진다
    g.castEllipse(bx + rx * 0.12, by + ry * 0.34, rx * 0.90, ry * 0.86, 0.78);
    g.ellipse(bx, by, rx, ry, 'l2');
    // 덩이 하나하나가 **공**이다: 위쪽 밝은 면 -> 아랫배 그늘 -> 밑에서
    // 되비치는 빛. 이 셋이 있어야 잎덩이가 원반이 아니라 덩어리로 보인다
    g.ellipse(bx, by - ry * 0.28, rx * 0.88, ry * 0.62, 'l1', ['l2']);
    g.ellipse(bx - rx * 0.24, by - ry * 0.50, rx * 0.54, ry * 0.36, 'l0', ['l1']);
    g.ellipse(bx + rx * 0.12, by + ry * 0.44, rx * 0.82, ry * 0.50, 'l3', ['l2']);
    g.ellipse(bx + rx * 0.20, by + ry * 0.70, rx * 0.60, ry * 0.30, 'l4', ['l3']);
    // 되비침 — 아래 가장자리 한 겹만 한 단 올린다 (땅에서 튕겨 온 빛)
    for (let a = 0; a < 90; a++) {
      const th = (a / 90) * Math.PI;                 // 아래쪽 반원만
      const x = bx + Math.cos(th) * rx * 0.96;
      const y = by + Math.sin(th) * ry * 0.96;
      if (g.get(x, y) === 'l4') g.px(x, y, 'l3');
    }
  }
  // 덩이와 덩이 **사이의 골**. 바깥에서 살짝만 베어 문다.
  //
  // 처음엔 크게 물어냈더니 크라운이 납작해져 버섯이 됐다. 노거수는
  // 위가 둥글다 — 갈라지는 곳은 옆구리와 밑이지 정수리가 아니다.
  // (한복판에도 하나 뚫어 봤는데 도넛 구멍처럼 보여서 뺐다 — 골은
  //  바깥 윤곽에서만 의미가 있다)
  for (const [bx, by, rx, ry] of [
    [26, 62, 15, 15], [174, 60, 15, 15],
    [46, 126, 15, 13], [154, 124, 15, 13],
  ]) g.ellipse(bx + sway(by), by, rx, ry, '.', ['l2']);

  // ---- 크라운 전체의 빛 (large form) ----
  //
  // 잎덩이를 하나하나 공처럼 칠하고 그림자까지 던져도, **크라운 전체**가
  // 공으로 안 보이면 여전히 납작하다. 작은 덩어리마다 빛이 따로 놀아서
  // 「구슬을 한 판에 늘어놓은」 그림이 된다.
  //
  // 큰 것을 그릴 때는 켜가 둘이다:
  //   큰 덩어리(large form)  크라운 전체가 하나의 공 — 왼쪽 위가 밝고
  //                          오른쪽 아래가 어둡다
  //   작은 덩어리(small form) 그 위에 얹힌 잎덩이 하나하나
  // 작은 것만 있으면 납작하고, 큰 것만 있으면 브로콜리다. 둘 다 있어야 한다.
  {
    const LX = 66, LY = 24;                  // 크라운의 빛점 (왼쪽 위)
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const c = g.d[y][x];
      if (c[0] !== 'l') continue;
      const d = Math.hypot((x - LX) / 132, (y - LY) / 124);
      // 경계에 테가 생기지 않게 문턱을 칸마다 조금씩 흔든다
      const j = (hash(x, y) - 0.5) * 0.09;
      if (d + j > 1.06) g.px(x, y, DARKER[DARKER[c]]);
      else if (d + j > 0.80) g.px(x, y, DARKER[c]);
      else if (d + j < 0.30) g.px(x, y, LIGHTER[c]);
    }
  }

  // 톤 경계를 **뜯는다.**
  //
  // 공처럼 칠하고 그림자까지 던지고 나면 부피는 생기는데, 경계가 죄다
  // 자로 그은 타원이라 잎덩이가 도자기 접시처럼 보인다. 진짜 잎덩이의
  // 경계는 잎 다발 하나하나가 들쭉날쭉 물고 있다.
  //
  // 그래서 마지막에 **톤이 바뀌는 자리만** 찾아 이웃 톤과 섞는다.
  // 면은 그대로 두고 경계만 뜯으니 부피는 안 무너지고 자국만 사라진다.
  for (let pass = 0; pass < 2; pass++) {
    const swap = [];
    for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) {
      const c = g.d[y][x];
      if (c[0] !== 'l') continue;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
        const n = g.get(nx, ny);
        if (n[0] !== 'l' || n === c) continue;
        if (hash(x * 13 + pass * 71, y * 17 + 5) > 0.62) swap.push([x, y, n]);
        break;
      }
    }
    for (const [x, y, c] of swap) g.px(x, y, c);
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
      const s0 = sway(y0), s1 = sway(y1);
      tip.bone(x0 + s0, y0, x1 + s1, y1, w, 2, 'b2');
      tip.bone(x1 + s1, y1, x1 + s1 + (x1 - x0) * 0.22, y1 - 8, 2, 1, 'b2');
    }
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
      if (tip.d[y][x] !== '.' && g.d[y][x] === '.') g.px(x, y, 'b2');
  }

  // ---- 곁들이 ----
  //
  // 여기까지는 「큰 나무」다. 여기서부터가 **살아 온 나무**다.
  // 큰 것 하나만 잘 그려도 크게는 보이지만, 가까이 갔을 때 볼 게 없으면
  // 배경 그림이 된다. 세월이 앉은 자리를 몇 군데 만든다.

  // 나무 구멍 — 오래된 나무에는 구멍이 있다. 속이 제일 어두워야 깊어 보인다
  g.ellipse(CX - 22, GY - 44, 13, 17, 'b3', ['b0', 'b1', 'b2']);
  g.ellipse(CX - 22, GY - 45, 10, 14, 'n0', ['b3']);
  g.ellipse(CX - 22, GY - 52, 7, 6, 'b3', ['n0']);      // 구멍 위턱의 되비침
  // 구멍 언저리는 아물면서 도톰해진다 — 다만 **줄기 위에만**.
  // 그냥 원을 그렸더니 왼쪽 테두리가 줄기 밖 허공에 활처럼 떴다
  for (let a = 0; a < 80; a++) {
    const th = a / 80 * Math.PI * 2;
    const x = CX - 22 + Math.cos(th) * 13.6, y = GY - 44 + Math.sin(th) * 17.6;
    if (g.get(x, y)[0] === 'b') g.px(x, y, 'b0');
  }

  // 이끼 — 늘 그늘인 쪽(오른쪽 아래)에만 앉는다. 사방에 두르면 이끼 옷이 된다
  // 점으로 흩었더니 초록 바둑판이 됐다 — 이끼는 **덩어리로** 앉는다.
  // 큰 좌표(x>>3, y>>4)로 「이끼가 앉은 자리」를 먼저 정하고, 그 안에서만
  // 잔 무늬를 준다. 그리고 밑동에 가까울수록 짙다 (물이 고이는 쪽)
  for (let y = GY - 60; y <= GY - 6; y++) {
    const mx = trunkMid(y), hw = trunkHalf(y);
    const low = Math.min(1, (y - (GY - 60)) / 54);
    for (let x = Math.round(mx + hw * 0.34); x <= Math.round(mx + hw); x++) {
      if (g.get(x, y)[0] !== 'b') continue;
      if (hash(x >> 3, y >> 4) < 0.62) continue;       // 이끼가 앉은 덩어리 안에서만
      const hh = hash(x >> 1, y >> 1);
      if (hh > 0.72 - low * 0.3) g.px(x, y, hh > 0.9 ? 'm1' : 'm2');
    }
  }

  // 덩굴 — 아래 가지에서 늘어진다. 잎덩이 **밑으로** 나와야 보인다.
  // 바람에 나무보다 크게 흔들린다 (가벼운 것이 더 흔들리는 게 눈에 맞다)
  for (const [vx, vy, len] of [[52, 118, 34], [148, 116, 28], [86, 132, 22],
                               [118, 130, 26], [34, 112, 18]]) {
    const sw = sway(vy) * 1.6;
    for (let i = 0; i < len; i++) {
      const t = i / len;
      const x = vx + sw * (1 + t * 1.4) + Math.sin(t * 3.4 + vx) * 2.0;
      const y = vy + i;
      if (g.get(x, y) !== '.') continue;
      g.px(x, y, i % 5 === 4 ? 'l1' : 'l3');
      if (i % 7 === 3) { g.px(x - 1, y, 'l2'); g.px(x + 1, y, 'l2'); }
    }
  }

  // 꽃 — 잎덩이 사이에 노란 점 몇. 이 한 줌이 나무에 「철」을 준다
  for (let i = 0; i < 34; i++) {
    const bi = BLOB[i % BLOB.length];
    const th = hash(i, 31) * Math.PI * 2, rr = 0.35 + hash(i, 37) * 0.55;
    const fx = bi[0] + Math.cos(th) * bi[2] * rr;
    const fy = bi[1] + Math.sin(th) * bi[3] * rr;
    if (g.get(fx, fy)[0] !== 'l') continue;
    g.px(fx, fy, 'f0');
    if (hash(i, 41) > 0.5) g.px(fx + 1, fy, 'f1');
  }

  // 버섯 — 뿌리 사이에 돋는다. 밑동에 시선이 머물 거리를 만든다
  for (const [mx2, my2, r] of [[CX - 48, GY - 6, 4], [CX - 40, GY - 3, 3],
                               [CX + 44, GY - 5, 4], [CX + 52, GY - 2, 3],
                               [CX + 12, GY - 2, 3]]) {
    g.rect(mx2 - 1, my2, mx2 + 1, my2 + 3, 'u0');
    g.ellipse(mx2, my2, r, r * 0.72, 'u1');
    g.ellipse(mx2 - r * 0.3, my2 - r * 0.3, r * 0.4, r * 0.3, 'u0', ['u1']);
  }

  // 나무 밑동 앞의 풀숲 — 뿌리와 땅이 만나는 자리를 덮는다
  for (let x = CX - 62; x <= CX + 62; x++) {
    const t = (x - CX) / 62;
    const top = GY - 4 - Math.round(Math.cos(t * 1.5) * 5 + hash(x >> 1, 3) * 3);
    for (let y = top; y <= GY; y++)
      if (g.get(x, y) === '.' || g.get(x, y) === 'd0' || g.get(x, y) === 'd1')
        g.px(x, y, hash(x, y >> 1) > 0.6 ? 'm0' : 'm1');
  }

  // 땅에 눕는 그림자 — **맨 마지막에** 다시 깐다.
  //
  // 맨 처음 깔았더니 뿌리와 풀숲이 그 위를 덮어 흔적도 안 남았다.
  // 그림자가 없으면 아무리 잘 그려도 나무가 땅에 안 붙는다 — 잔디 위에
  // 세워 놓은 판때기가 된다. 빛이 왼쪽 위에서 오니 그림자는 오른쪽 아래로,
  // 그리고 **아주 납작하게** (해가 높이 뜬 낮이다)
  {
    const SX = CX + 34, SR = 88, SY = GY - 3, SH = 11;   // 그림자 한가운데·반지름
    for (let y = SY - SH; y <= SY + SH; y++) {
      const t = (y - SY) / SH;
      if (Math.abs(t) > 1) continue;
      const half = SR * Math.sqrt(1 - t * t);
      for (let x = Math.round(SX - half); x <= Math.round(SX + half); x++) {
        const at = g.get(x, y);
        // 빈 땅에는 그림자를 깔고, 밑동 풀숲 위에는 **한 단 어둡게** 덮는다.
        // 빈 칸만 칠했더니 뿌리와 풀에 다 가려 흔적도 안 남았다
        if (at !== '.' && at !== 'm0' && at !== 'm1') continue;
        const d = Math.hypot((x - SX) / SR, t);
        if (hash(x, y) > 1.06 - d * 0.5) continue;   // 가장자리는 성글게 (반그림자)
        g.px(x, y, at === '.' ? (d > 0.62 ? 'd0' : 'd1') : DARKER[at]);
      }
    }
  }

  g.outline('O', ['d0', 'd1']);
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
function bigFalls(f, NF) {
  const W = 200, H = 208, CX = 100, GY = H - 4;
  const g = new G(W, H);
  // 물이 한 장에 여섯 칸씩 내려간다. 결의 세로 폭이 8이라 네 장이면
  // 24 = 8의 배수 — 마지막 장이 첫 장과 이어져 튀지 않는다
  const flowY = f * 6;
  const wob = (f / NF) * Math.PI * 2;
  const LIP = 26;            // 물이 넘어가는 마루
  const LEDGE = 124;         // 중간 단 (여기서 한 번 부딪혀 갈라진다)
  const POOL = 172;          // 물웅덩이 수면

  // ---- 바위벽 ----
  //
  // 처음엔 판 전체를 바위로 채웠다. 그랬더니 **네모난 바위 사진**을 풀밭에
  // 붙여 놓은 꼴이 됐다 — 잔디와 만나는 자리가 자로 그은 직선이라
  // 세계의 일부로 안 읽힌다.
  //
  // 바위는 **덩어리(massif)** 다. 위는 좁고 밑으로 갈수록 벌어지며,
  // 바깥 윤곽은 들쭉날쭉하다. 그 실루엣이 먼저 보여야 「절벽에서 물이
  // 떨어진다」가 된다.
  // 밑으로 갈수록 **크게** 벌어진다. 처음엔 완만하게 넓혔더니 서 있는
  // 달걀 하나가 됐다 — 절벽은 좌우로 뻗은 벽이지 세워 둔 물건이 아니다.
  const massifHalf = (y) => {
    const t = Math.min(1, Math.max(0, y / POOL));
    return 22 + Math.pow(t, 0.5) * (W / 2 - 26);
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
    // 마루 **위**는 내려다보는 바닥(r1), 마루 **아래**는 마주보는 벽(r2).
    // 이 게임은 위에서 비스듬히 내려다보는 화면이라, 눕는 면과 서는 면의
    // 밝기가 갈려야 「높이」가 생긴다. 다 같은 회색으로 칠하면 아무리 잘
    // 그려도 벽에 붙인 그림 한 장이다 (건물 지붕과 벽이 갈리는 것과 같다)
    g.rect(CX - half, y, lx, y, y < LIP ? 'r1' : 'r2');
    g.rect(rx, y, CX + half, y, y < LIP ? 'r1' : 'r2');
  }
  // 벼랑 마루 — 눕는 면과 서는 면이 만나는 **모서리**. 여기가 제일 밝다.
  // 이 한 줄이 「여기서 뚝 떨어진다」를 말한다
  for (let y = LIP - 3; y < LIP; y++)
    for (let x = 0; x < W; x++)
      if (g.get(x, y)[0] === 'r') g.px(x, y, y === LIP - 3 ? 'r1' : 'r0');
  // 골짜기 벽의 **윗변** — 벽 꼭대기도 눕는 면이라 밝다.
  // 없으면 벽이 종이처럼 얇아 보인다
  for (let y = LIP; y <= POOL; y++) {
    const half = massifHalf(y);
    for (const side of [-1, 1]) {
      for (let k = 0; k < 4; k++) {
        const x = Math.round(CX + side * (half - k));
        if (g.get(x, y)[0] === 'r') g.px(x, y, k < 2 ? 'r1' : 'r2');
      }
    }
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
  // ---- 골짜기 벽의 **부피** ----
  //
  // 가로로 켜만 그으면 벽이 아니라 **줄무늬 벽지**다. 골짜기 벽은
  // 오목한 면이라, 바깥 마루에서 물길 쪽으로 들어갈수록 하늘이 안 보여
  // 어두워진다 (그늘이 지는 게 아니라 **빛이 안 닿는** 것이다).
  //
  // 줄기와 같은 다섯 켜를 눕혀서 준다:
  //   바깥 마루   하늘을 정면으로 받는다 — 제일 밝다
  //   비탈        점점 어두워진다
  //   물길 언저리 제일 깊다 (코어)
  //   물가 한 겹  흰 물이 튕겨 온 빛 — 한 단 밝다 (되비침)
  for (let y = 2; y <= POOL; y++) {
    const half = massifHalf(y);
    const gap = (y < LIP ? chanAt(y) : gapAt(y)) + 3;
    for (const side of [-1, 1]) {
      const outer = CX + side * (half + 6);
      const inner = CX + side * gap;
      const span = Math.max(1, Math.abs(outer - inner));
      for (let k = 0; k <= span; k++) {
        const x = Math.round(inner + side * k);      // 물길 -> 바깥
        if (g.get(x, y)[0] !== 'r') continue;
        const t = k / span;                          // 0 물길 · 1 바깥 마루
        const j = (hash(x, y >> 1) - 0.5) * 0.10;
        let step = 0;
        if (t + j > 0.74) step = -1;                 // 바깥 마루 — 밝게
        else if (t + j < 0.10) step = -1;            // 물가 되비침
        else if (t + j < 0.34) step = 1;             // 물길 언저리 — 깊다
        if (step > 0) g.px(x, y, DARKER[g.get(x, y)]);
        else if (step < 0) g.px(x, y, LIGHTER[g.get(x, y)]);
      }
    }
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
  // 윗물도 **흐른다.** 마루 위가 멎어 있으면 폭포가 어디서 오는지 없어져
  // 물이 벽에서 솟는 꼴이 된다. 게임 물 타일과 같은 가로 잔물결
  for (let i = 0; i < 16; i++) {
    const y0 = 3 + Math.floor(hash(i, 71) * (LIP - 5)) ;
    const gap = chanAt(y0);
    const x0 = Math.round(CX - gap + hash(i, 72) * gap * 2) + ((f * 3 + i) % 5) - 2;
    const len = 2 + Math.floor(hash(i, 73) * 4);
    for (let k = 0; k < len; k++)
      if (g.get(x0 + k, y0)[0] === 'w') g.px(x0 + k, y0, LIGHTER[g.get(x0 + k, y0)]);
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
    // 두 겹이다 — **안 움직이는 긴 줄기**(물길의 결)와 그 위를
    // **흘러내리는 결**. 흐르는 것만 있으면 물이 통째로 미끄러지고,
    // 긴 줄기만 있으면 얼어붙은 물이 된다
    const streak = hash(x >> 1, y >> 5);
    const flow = hash(x >> 1, (y + flowY) >> 3);
    let c = 'w2';
    if (streak > 0.78) c = 'w1';
    else if (streak < 0.22) c = 'w3';
    if (flow > 0.82) c = (c === 'w1') ? 'w0' : 'w1';
    else if (flow < 0.15) c = (c === 'w3') ? 'w4' : 'w3';
    // 양쪽 가장자리는 벽에 스쳐 하얗게 부서진다
    if (Math.abs(rel) > 0.82) c = hash(x, y + flowY) > 0.4 ? 'w1' : 'w0';
    // 가운데 굵은 본류는 짙다 (두꺼운 물은 색이 깊다)
    if (Math.abs(rel) < 0.24 && streak < 0.6 && flow > 0.2) c = 'w3';
    g.px(x, y, c);
  }
  // 왼쪽 벽이 물 위로 던지는 그늘 — 물이 골짜기 **안에** 있다는 표시다.
  // 이게 없으면 물 커튼이 바위 앞에 걸려 있는 것처럼 떠 보인다
  for (let y = LIP; y <= POOL; y++) {
    const gap = gapAt(y);
    for (let k = 0; k < 9; k++) {
      const x = Math.round(CX - gap + k);
      if (g.get(x, y)[0] !== 'w') continue;
      if (hash(x * 5, y * 3 + 1) < 0.82 - k * 0.09)
        g.px(x, y, DARKER[g.get(x, y)]);
    }
  }
  // 물 커튼도 평평한 천이 아니다 — 가운데가 앞으로 불룩하고 양쪽은
  // 뒤로 말려 든다. 양 끝 한 겹을 한 단 내려 두께를 준다
  for (let y = LIP; y <= POOL; y++) {
    const gap = gapAt(y);
    for (const side of [-1, 1]) for (let k = 0; k < 4; k++) {
      const x = Math.round(CX + side * (gap - 1 - k));
      if (g.get(x, y) === 'w1' || g.get(x, y) === 'w2')
        g.px(x, y, DARKER[g.get(x, y)]);
    }
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

  // ---- 못 ----
  //
  // 못은 **땅바닥에 누워 있다.** 세로로 선 물 커튼과 같은 면일 수가 없다.
  // 그래서 위에서 내려다본 **납작한 타원**으로 그린다 (게임의 연못이 그렇게
  // 보인다). 앞서는 사각형에 가깝게 깔았는데, 그러니 폭포가 물을 벽에다
  // 쏟는 꼴이었다 — 물이 어디에 담기는지가 안 보였다.
  //
  // 색은 게임 연못과 **같은 단**을 쓴다 (w4~w6). 세계가 이 그림 둘레에
  // 진짜 물 타일을 깔아 두므로, 여기서 색이 어긋나면 경계가 그대로 보인다.
  const PR = massifHalf(POOL) - 6;          // 못의 가로 반지름
  const PY = POOL + 14;                     // 못 한가운데 (그림 밑동 쪽)
  for (let y = POOL - 6; y <= GY; y++) {
    const t = (y - PY) / 20.0;
    if (Math.abs(t) > 1) continue;
    const half = PR * Math.sqrt(1 - t * t) * (0.94 + hash(0, y) * 0.12);
    for (let x = Math.round(CX - half); x <= Math.round(CX + half); x++) {
      if (g.get(x, y)[0] === 'r') continue;       // 바위는 물에 안 잠긴다
      // 가장자리는 얕고 가운데는 깊다 — 깊이는 물빛 자체가 말한다
      const d = Math.hypot((x - CX) / PR, (y - PY) / 20.0);
      g.px(x, y, d > 0.86 ? 'w4' : (d > 0.55 ? 'w5' : 'w6'));
    }
  }
  // 잔물결 — **가로로 짧게 그은 줄**. 게임 물 타일과 같은 방식이다
  // (세로로 그으면 아직 떨어지는 중인 물이 된다). 장마다 어긋나게 찍어
  // 물이 흐르게 한다
  for (let i = 0; i < 46; i++) {
    const ang = hash(i, 61) * Math.PI * 2, rr = Math.sqrt(hash(i, 62)) * 0.92;
    const x0 = Math.round(CX + Math.cos(ang) * PR * rr);
    const y0 = Math.round(PY + Math.sin(ang) * 20.0 * rr) + ((f * 2 + i) % 3) - 1;
    const len = 2 + Math.floor(hash(i, 63) * 4);
    for (let k = 0; k < len; k++) {
      const c = g.get(x0 + k, y0);
      if (c[0] !== 'w' || c === 'w0' || c === 'w1') continue;
      g.px(x0 + k, y0, LIGHTER[c]);
    }
  }
  // 떨어진 자리에서 피어오르는 흰 물보라 — 폭포의 밑동이다
  for (let i = 0; i < 26; i++) {
    const t = i / 25;
    const px = CX + Math.sin(i * 2.3) * (gapAt(POOL) + 10) * (0.35 + t * 0.65);
    const py = POOL - 2 + Math.cos(i * 1.7) * 9;
    // 물보라는 **부푸는 것**이다. 덩이마다 다른 박자로 커졌다 작아진다
    const r = (5 + hash(i, 7) * 7) * (1.0 + Math.sin(wob + i * 1.9) * 0.22);
    // 물보라는 물이 **떨어져 부딪히는 자리**에 인다 — 수면에 붙어
    // 납작하게 퍼진다 (동그란 구름을 띄우면 솜뭉치가 뜬 것 같다)
    g.ellipse(px, py - Math.sin(wob + i) * 1.5, r, r * 0.46,
      hash(i, 3) > 0.45 ? 'w0' : 'w1');
  }
  // 웅덩이에 퍼지는 흰 테 — 물보라가 물에 닿는 자리
  // 흰 테는 **퍼져 나간다** — 물보라가 물에 닿아 밀려 나가는 자리다.
  // 한 장에 한 칸씩 커지고, 다 커지면 처음 크기로 돌아온다
  // 수면에 퍼지는 흰 테 — **아주 납작해야** 물 위에 누운 것으로 보인다.
  // 동그랗게 그리면 물속에 박힌 고리가 된다
  for (let i = 0; i < 5; i++) {
    const grow = ((i + f) % 5);
    g.ellipse(CX, POOL + 5 + grow * 3.4, PR * (0.36 + grow * 0.15),
      (2.4 + grow * 1.1), grow < 2 ? 'w0' : 'w1', ['w4', 'w5', 'w6']);
  }
  // 웅덩이 앞의 젖은 바위 몇 덩이 — 물가에 놓여야 웅덩이에 깊이가 생긴다
  for (const [rx2, ry2, r] of [[CX - 46, PY + 10, 11], [CX + 44, PY + 12, 9],
                               [CX + 14, PY + 17, 7]]) {
    g.ellipse(rx2, ry2, r, r * 0.62, 'r2');
    g.ellipse(rx2 - r * 0.2, ry2 - r * 0.24, r * 0.6, r * 0.34, 'r1', ['r2']);
  }

  // ---- 곁들이 ----

  // 무지개 — 물보라가 이는 곳에는 무지개가 선다. **옅게만** 얹는다.
  // 진하게 그리면 폭포 위에 스티커를 붙인 꼴이 된다.
  // 물 위에는 안 그린다 (물빛을 먹어 얼룩이 된다) — 바위와 물보라 위에만
  // 처음엔 바위 위에만 그렸더니 무지개가 어디에도 안 걸려 사라졌다.
  // 무지개가 서는 자리는 **물보라 속**이다 — 흰 물보라(w0/w1) 위에만,
  // 세 칸에 한 칸씩만 찍는다 (촘촘히 찍으면 색 테이프가 된다)
  for (let a = 0; a <= 120; a++) {
    const th = Math.PI + (a / 120) * Math.PI;        // 위로 볼록한 반원
    for (let k = 0; k < 4; k++) {
      const rr = 48 + k * 3;
      const x = CX + Math.cos(th) * rr;
      const y = POOL + 2 + Math.sin(th) * rr * 0.66;
      const at = g.get(x, y);
      if (at !== 'w0' && at !== 'w1') continue;
      // 세 칸에 한 칸씩 찍었더니 색종이 조각을 뿌린 꼴이었다.
      // **각도로** 끊어야 띠로 보인다 — 한 각도에서는 네 색을 다 찍는다
      if (a % 2 === 0) g.px(x, y, ['c0', 'c1', 'c2', 'c3'][k]);
    }
  }

  // 고사리 — 늘 젖어 있는 바위 턱에 돋는다. 폭포 곁이라야 사는 것들
  for (const [fx, fy] of [[CX - 68, 118], [CX + 66, 126], [CX - 78, 150],
                          [CX + 76, 146], [CX - 60, 96], [CX + 62, 92]]) {
    for (let b = -3; b <= 3; b++) {
      const len = 9 - Math.abs(b);
      for (let i = 0; i < len; i++) {
        const x = fx + b * 1.6 + Math.sin(wob + b) * 0.8 * (i / len);
        const y = fy - i;
        if (g.get(x, y)[0] !== 'r') continue;
        g.px(x, y, i > len - 3 ? 'm0' : 'm1');
      }
    }
  }

  // 물에 걸린 통나무 — 물가에 하나 놓이면 못에 크기가 생긴다
  g.bone(CX - 60, PY + 8, CX - 24, PY + 14, 7, 6, 'b2');
  g.bone(CX - 60, PY + 7, CX - 26, PY + 12, 3, 3, 'b1');
  g.ellipse(CX - 24, PY + 14, 3, 3.4, 'b3');
  // 물에 잠긴 자리 — 나무 밑동에 물이 닿는 선이 있어야 **떠 있는** 게 된다
  for (let x = CX - 66; x <= CX - 18; x++)
    for (let y = PY + 12; y <= PY + 18; y++)
      if (g.get(x, y)[0] === 'b' && hash(x, y) > 0.55) g.px(x, y, DARKER[g.get(x, y)]);

  g.outline('O', ['w4', 'w5', 'w6']);
  return g;
}


// ============================================================
// 3. 붉은 바위 기둥 — 층층이 깎여 남은 것
// ============================================================
//
// 바람과 물이 무른 층을 먼저 파먹고 단단한 층만 남으면 기둥이 된다.
// 그래서 **허리가 잘록하고 머리가 넓다**. 위아래 굵기가 같으면 굴뚝이다.
function rockSpire(f, NF) {
  const W = 124, H = 232, CX = 62, GY = H - 4;
  const g = new G(W, H);
  const wob = (f / NF) * Math.PI * 2;

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
        // 원기둥 다섯 켜 — 하이라이트 · 밝은 면 · 중간 · 코어 섀도 ·
        // **되비침**. 마지막 한 겹을 한 단 올려야 기둥이 뒤로 말려 든다
        // (끝까지 새카맣게 두면 칼로 잘라 놓은 것처럼 보인다)
        let c = rel < -0.55 ? 'k1' : (rel > 0.34 ? 'k3' : 'k2');
        if (rel > 0.78) c = 'k4';
        if (rel > 0.93) c = 'k3';
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
  // 갓돌 위의 마른 풀 한 줌 — 바람에 눕는다.
  // 이 그림에서 유일하게 살아 있는 것이라, 여기가 흔들려야 그림이 산다
  for (let i = -6; i <= 6; i++) {
    const bx = capX + i * 3.0 + hash(i + 9, 4) * 2;
    const by = TOP - 10 + (i + 6) * 0.24;
    const h2 = 4 + Math.round(hash(i + 9, 2) * 4);
    const lean2 = Math.sin(wob + i * 0.6) * 2.0;
    for (let k = 0; k <= h2; k++)
      g.px(bx + lean2 * (k / h2), by - k, k > h2 - 2 ? 'm0' : 'm1');
  }

  // ---- 곁들이 ----

  // 갓돌에 앉은 새 — 날개를 친다. 이 하나가 기둥의 크기를 말해 준다
  // (사람이 못 올라가는 데 앉은 것이라야 「높다」가 읽힌다)
  {
    const bx = capX + 6, by = TOP - 14;
    g.ellipse(bx, by, 3.2, 2.4, 'i1');            // 몸
    g.ellipse(bx - 1, by - 1, 1.8, 1.4, 'i0', ['i1']);
    g.px(bx + 4, by - 1, 'i1'); g.px(bx + 5, by - 1, 'i1');   // 부리
    g.px(bx + 3, by - 3, 'i1');                                // 머리
    // 날개 — 프레임마다 접었다 폈다
    const up = f % 2 === 0;
    if (up) { g.bone(bx - 1, by - 1, bx - 5, by - 6, 2, 1, 'i1'); }
    else { g.bone(bx - 1, by, bx - 6, by + 2, 2, 1, 'i1'); }
  }

  // 돌탑 — 지나던 사람들이 하나씩 얹고 간 돌무지.
  // 사람 손이 닿았다는 표시 하나로, 세상 끝의 바위가 「가 볼 데」가 된다
  {
    const tx = CX - 40;
    let ty = GY - 2;
    for (const r of [7, 6, 5, 4.2, 3.4, 2.6]) {
      g.ellipse(tx, ty, r, r * 0.55, 'r2');
      g.ellipse(tx - r * 0.24, ty - r * 0.2, r * 0.6, r * 0.3, 'r1', ['r2']);
      g.hline(tx - r + 1, tx + r - 1, ty + Math.round(r * 0.55), 'r3');
      ty -= Math.max(3, Math.round(r * 0.9));
    }
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


// ============================================================
// 4. 물레방아 — 폭포골 마을의 방앗간 곁에서 돈다
// ============================================================
//
// 랜드마크는 아니지만 여기 있는 게 맞다. **돌아가는 그림**을 뽑는
// 규칙이 이 파일에 다 있고, 물레방아는 돌지 않으면 아무 의미가 없다.
//
// 도는 것을 그리는 요령은 **바큇살을 대칭으로 두지 않는 것**이다.
// 여덟 살을 45도로 두면 반 바퀴에서 처음과 똑같아 보여 안 도는 것 같다.
// 살을 여섯으로 두고 네 장에 15도씩 돌리면 (총 60도 = 살 간격) 딱 한
// 칸 넘어가 매끄럽게 이어진다.
function millWheel(f, NF) {
  const W = 60, H = 68, CX = 30, CY = 30, R = 26;
  const g = new G(W, H);
  const rot = (f / NF) * (Math.PI * 2 / 6);      // 살 하나 간격만 돈다

  // 물받이 통 — 살 끝에 달린 널. 물이 여기 담겨 바퀴를 돌린다
  for (let i = 0; i < 6; i++) {
    const th = rot + i * (Math.PI * 2 / 6);
    const ex = CX + Math.cos(th) * R, ey = CY + Math.sin(th) * R;
    // 살
    g.bone(CX + Math.cos(th) * 6, CY + Math.sin(th) * 6, ex, ey, 4, 3, 'b1');
    // 물받이 — 살 끝에서 바퀴를 따라 접힌다
    const tx = ex + Math.cos(th + Math.PI / 2) * 6;
    const ty = ey + Math.sin(th + Math.PI / 2) * 6;
    g.bone(ex, ey, tx, ty, 5, 4, 'b2');
    // 물이 담긴 통은 물이 넘친다 (위로 올라가는 쪽 셋만)
    if (Math.sin(th) > 0.1) {
      g.ellipse(tx, ty, 3, 2.4, 'w1');
      g.px(tx, ty + 3, 'w0');
      g.px(tx + 1, ty + 4, 'w1');
    }
  }
  // 테 — 안팎 두 겹. 한 겹만 두면 바퀴가 아니라 별이 된다
  for (let a = 0; a < 260; a++) {
    const th = a / 260 * Math.PI * 2;
    for (let k = -1; k <= 1; k++)
      g.px(CX + Math.cos(th) * (R + k), CY + Math.sin(th) * (R + k), 'b1');
    g.px(CX + Math.cos(th) * (R - 5), CY + Math.sin(th) * (R - 5), 'b2');
  }
  // 축
  g.ellipse(CX, CY, 5, 5, 'b2');
  g.ellipse(CX - 1, CY - 1, 3, 3, 'b0');
  // 결 — 젖은 나무라 아래쪽이 짙다
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (g.d[y][x][0] !== 'b') continue;
    if (y > CY + 8 && hash(x >> 1, y >> 1) > 0.55) g.px(x, y, 'b3');
    else if (hash(x >> 2, y >> 2) > 0.84) g.px(x, y, 'b0');
  }
  // 물이 떨어지는 자리 — 바퀴 밑에 흰 물보라
  for (let i = 0; i < 9; i++) {
    const px = CX - 10 + i * 2.6 + Math.sin(f * 1.7 + i) * 1.2;
    g.ellipse(px, H - 8 + Math.cos(f + i) * 2, 4, 2.6, i % 2 ? 'w0' : 'w1');
  }
  g.rect(0, H - 4, W - 1, H - 1, 'w2');
  for (let x = 0; x < W; x++)
    if (hash((x + f * 3) >> 1, 5) > 0.6) g.px(x, H - 4, 'w1');

  g.outline('O');
  return g;
}


// ---- 내보내기 ----
//
// 하나에 여러 장. 이름은 landmark_<id>_<장번호>.png 이고, 게임은
// main.gd 의 LANDMARK_FRAMES 표를 보고 돌린다.
const WORKS = {
  landmark_greattree: { fn: greatTree, frames: 3 },
  landmark_falls: { fn: bigFalls, frames: 4 },
  landmark_spire: { fn: rockSpire, frames: 2 },
  deco_wheel: { fn: millWheel, frames: 4 },
};
const made = [];
for (const [name, w] of Object.entries(WORKS)) {
  for (let f = 0; f < w.frames; f++) {
    const im = w.fn(f, w.frames).render();
    fs.writeFileSync(OUT + PRE + name + '_' + f + '.png', PNG.sync.write(im));
    if (f === 0) made.push([name, im.width, im.height, w.frames]);
  }
}
for (const [name, ww, hh, nf] of made)
  console.log('%s  %d장  %dx%d px  (화면 %.2f x %.2f 칸)',
    name, nf, ww, hh, ww / 64, hh / 64);

// 한 장에 나란히 — 크기 비교가 되어야 「엄청 크다」가 맞는지 눈으로 본다.
// 곁에 주인공(2 x 3칸)을 세워 둔다. 사람 없이 큰 것만 보면 큰지 알 수 없다.
{
  const pad = 16;
  const ims = made.map(([n]) => PNG.sync.read(fs.readFileSync(OUT + PRE + n + '_0.png')));
  let tw = pad, th = 0;
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
  for (let y = 0; y < 192; y++) for (let xx = 0; xx < 64; xx++) {
    const di = ((y + pad + th - 192) * cmp.width + (x + 32 + xx)) * 4;
    cmp.data[di] = 40; cmp.data[di + 1] = 48; cmp.data[di + 2] = 60;
  }
  fs.writeFileSync(REF + 'preview_landmarks.png', PNG.sync.write(cmp));
}

// 움직이는지 보려면 장을 가로로 늘어놓고 봐야 한다 (한 줄에 한 랜드마크)
{
  const pad = 10;
  let tw = 0, th = pad;
  const rows = [];
  for (const [name, , , nf] of made) {
    const ims = [];
    for (let f = 0; f < nf; f++)
      ims.push(PNG.sync.read(fs.readFileSync(OUT + PRE + name + '_' + f + '.png')));
    rows.push(ims);
    tw = Math.max(tw, pad + ims.length * (ims[0].width / 2 + pad));
    th += ims[0].height / 2 + pad;
  }
  const cmp = new PNG({ width: Math.round(tw), height: Math.round(th) });
  for (let i = 0; i < cmp.data.length; i += 4) {
    cmp.data[i] = 112; cmp.data[i + 1] = 144; cmp.data[i + 2] = 96; cmp.data[i + 3] = 255;
  }
  let oy = pad;
  for (const ims of rows) {
    let ox = pad;
    for (const im of ims) {
      // 게임에 그려지는 크기(0.5배) 그대로 — 이 크기에서 움직임이 보여야 한다
      for (let y = 0; y < im.height; y += 2) for (let x = 0; x < im.width; x += 2) {
        const si = (y * im.width + x) * 4;
        if (im.data[si + 3] === 0) continue;
        const X = Math.round(ox + x / 2), Y = Math.round(oy + y / 2);
        if (X < 0 || Y < 0 || X >= cmp.width || Y >= cmp.height) continue;
        const di = (Y * cmp.width + X) * 4;
        cmp.data[di] = im.data[si]; cmp.data[di + 1] = im.data[si + 1];
        cmp.data[di + 2] = im.data[si + 2];
      }
      ox += im.width / 2 + pad;
    }
    oy += ims[0].height / 2 + pad;
  }
  fs.writeFileSync(REF + 'preview_landmark_frames.png', PNG.sync.write(cmp));
  console.log('preview_landmarks.png · preview_landmark_frames.png (장별로 늘어놓은 것)');
}
