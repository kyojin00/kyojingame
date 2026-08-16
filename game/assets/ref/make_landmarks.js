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
//   falls      폭포골      — 벼랑에 걸린 물 (5.5칸 x 6.5칸)
//                            좌우로는 세계의 벼랑 타일이, 위아래로는
//                            세계의 물 타일이 이어진다
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
  // ---- 색은 **게임에서 뽑았다** ----
  //
  // 크게 잘 그려 놓고도 세계에 놓으면 겉도는 이유의 절반이 색이다.
  // 큰나무만 쨍한 풀빛이면 둘레의 보통 나무들과 **다른 종**으로 보이고,
  // 폭포 바위만 차가운 회색이면 게임 벼랑과 다른 돌이 된다.
  // 그래서 실제 그림에서 색을 찍어 왔다:
  //   잎    sprites/tree_01.png (누런 올리브빛 — 우리 숲의 색이다)
  //   바위  sprites/rock.png + make_ground.js 의 STONE (따뜻한 회색)
  //   흙·껍질  make_ground.js 의 EARTH
  //   이끼  make_ground.js 의 MOSS
  // ---- 나무껍질 (밝은 면 / 기본 / 그늘 / 깊은 골) ----
  'b0': [156, 126, 94], 'b1': [124, 98, 72], 'b2': [96, 74, 54], 'b3': [68, 52, 38],
  // ---- 잎 (다섯 단) — 위에서 빛을 받고 밑으로 갈수록 어둡다 ----
  'l0': [126, 156, 34], 'l1': [108, 136, 22], 'l2': [74, 98, 24],
  'l3': [48, 72, 26], 'l4': [30, 48, 28],
  // ---- 바위 (따뜻한 회색 — 게임 벼랑·돌과 같은 돌이다) ----
  'r0': [190, 174, 158], 'r1': [166, 150, 134], 'r2': [130, 117, 107],
  'r3': [100, 90, 82], 'r4': [67, 62, 58],
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
  // 게임 호수가 WATER[5] 언저리(짙은 남색)인데, 떨어지는 물을 WATER[0~2]
  // 로 잡았더니 폭포만 하늘색이라 **딴 물**로 보였다. 공기가 섞여 밝은 건
  // 맞지만 그건 한두 단 차이지 다른 색이 아니다. 사다리를 통째로 내렸다.
  'w0': [244, 250, 252],                                  // FOAM (마루·물보라만)
  'w1': [104, 174, 212], 'w2': [72, 142, 190],            // WATER[1..2]
  'w3': [50, 112, 162], 'w4': [34, 84, 130],              // WATER[3..4]
  'w5': [22, 60, 100], 'w6': [14, 42, 74],                // WATER[5..6] 호수와 같은 단
  // ---- 이끼 ----
  'm0': [112, 140, 74], 'm1': [88, 114, 58], 'm2': [66, 88, 44],   // MOSS
  // ---- 붉은 바위 (사암) ----
  'k0': [226, 152, 96], 'k1': [192, 112, 68], 'k2': [152, 80, 50],
  'k3': [108, 54, 36], 'k4': [70, 34, 25],
  // ---- 그림자 (땅에 앉는 자리) ----
  'd0': [72, 92, 54], 'd1': [54, 70, 44],   // 잔디를 어둡게 한 색
  // ---- 곁들이 ----
  'f0': [246, 232, 128], 'f1': [232, 176, 72],   // 꽃·열매
  'u0': [232, 214, 190], 'u1': [196, 108, 92],   // 버섯 (갓·대)
  'n0': [58, 46, 34],                             // 나무 구멍 속 (제일 어두운 데)
  'i0': [246, 246, 250], 'i1': [64, 60, 72],      // 새 (몸·부리)
  // ---- 석등의 불 ----
  'g0': [255, 240, 190], 'g1': [246, 206, 122], 'g2': [214, 158, 78],
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
  const ROOTS = [[-58, -3, 13], [-38, -10, 15], [-16, -14, 14],
                 [16, -14, 14], [40, -9, 15], [60, -2, 12]];
  for (const [dx, dy, w] of ROOTS) {
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
    // 살짝 울퉁불퉁하게 — 매끈한 원뿔은 깎아 세운 기둥으로 보인다.
    // 굵기가 아주 조금씩 오르내려야 「자란 것」이 된다
    const lump = Math.sin((GY - y) * 0.085) * 1.5 + Math.sin((GY - y) * 0.21) * 0.8;
    return base + flare + lump;
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
      // ---- 껍질 골은 **원기둥을 따라 감긴다** ----
      //
      // hash(x>>2, y>>4) 로 뿌리면 그건 **화면 좌표의 격자**다. 어디서나
      // 같은 폭으로 늘어서니 판때기에 그은 세로줄이지 원기둥의 골이 아니다.
      // 실제 원기둥은 옆으로 갈수록 면이 우리에게서 비껴서 **골이 촘촘해
      // 보인다** — 그 압축 하나가 「이건 둥글다」를 말한다.
      // rel(-1..1)을 asin 으로 펼치면 그 간격이 저절로 나온다.
      const u = Math.asin(Math.max(-1, Math.min(1, rel)));
      // 또렷함도 가장자리와 코어 섀도에서 죽는다 (거기서는 면이 안 보인다)
      const crisp = 1 - rel * rel * 0.65;
      const groove = hash(Math.round(u * 7), y >> 4);
      const fine = hash(Math.round(u * 17), y >> 2);
      if (groove > 0.80 - crisp * 0.14) c = DARKER[c] || c;
      else if (groove < 0.10 + crisp * 0.06) c = LIGHTER[c] || c;
      if (fine > 0.86 - crisp * 0.10) c = DARKER[c] || c;
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
  // ---- 판근 하나하나를 **따로** 살린다 ----
  //
  // 바로 위의 통 계산은 「그 줄에 있는 나무 픽셀」을 통째로 원기둥 하나로
  // 친다. 줄기에서는 맞는 말인데 밑동에서는 치명적이다 — 여섯 갈래로
  // 벌어진 뿌리가 한 덩어리로 뭉쳐 **나팔처럼 벌어진 기둥**이 된다.
  //
  // 뿌리마다 축을 두고, 축에 가까우면 볼록(밝고) 축에서 멀면 오목(어둡게)
  // 칠한다. 뿌리와 뿌리 사이가 골로 파여야 여섯 개가 여섯 개로 보인다.
  for (let y = GY - 42; y <= GY + 2; y++) for (let x = 0; x < W; x++) {
    if (g.get(x, y)[0] !== 'b') continue;
    let best = 1e9, side = 0;
    for (const [dx, dy, w] of ROOTS) {
      const ax = CX + dx * 0.24, ay = GY - 26, bx = CX + dx, by = GY + dy;
      const vx = bx - ax, vy = by - ay;
      const tt = Math.max(0, Math.min(1,
        ((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy)));
      const px2 = ax + vx * tt, py = ay + vy * tt;
      const hw = Math.max(2, (20 + (w - 20) * tt) / 2);
      const d = Math.hypot(x - px2, y - py) / hw;
      if (d < best) { best = d; side = (x - px2) / hw; }
    }
    if (best > 1.35) continue;
    let c = g.get(x, y);
    // 빛은 왼쪽 위 — 축의 왼쪽 위가 볼록의 꼭대기다
    const lit = -side * 0.55 + (1 - best) * 0.85;
    if (lit > 0.62) c = LIGHTER[c] || c;
    else if (lit < -0.22) c = DARKER[c] || c;
    if (best > 0.98) c = DARKER[c] || c;          // 뿌리와 뿌리 사이의 골
    g.px(x, y, c);
  }

  // ---- 판근의 **윗면** ----
  //
  // 위에서 비스듬히 내려다보는 화면이라, 밖으로 벌어져 내린 뿌리는 저마다
  // 등이 하늘을 향한다. 그 등을 안 밝히면 뿌리가 줄기와 한 덩어리로 뭉쳐
  // 「나팔처럼 벌어진 기둥」이 된다 — 뿌리 여섯 개가 따로 보여야 밑동이
  // 땅을 움켜쥔 것으로 읽힌다.
  //
  // 우리 집에서 지붕(눕는 면)이 벽(서는 면)보다 밝은 것과 같은 규칙이다.
  for (let y = GY - 38; y <= GY; y++) for (let x = 0; x < W; x++) {
    const c = g.get(x, y);
    if (c[0] !== 'b') continue;
    if (g.get(x, y - 1)[0] === 'b') continue;      // 위가 나무면 등이 아니다
    g.px(x, y, LIGHTER[c] || c);
    const c2 = g.get(x, y + 1);
    if (c2[0] === 'b' && hash(x, y) > 0.3) g.px(x, y + 1, LIGHTER[c2] || c2);
  }
  // 뿌리와 뿌리 **사이**는 골이다 — 등을 밝혔으면 그 사이는 어두워야
  // 둘이 갈라진다. 위가 비어 있지 않은데 좌우가 비었으면 골의 안쪽이다
  for (let y = GY - 30; y <= GY; y++) for (let x = 1; x < W - 1; x++) {
    if (g.get(x, y)[0] !== 'b') continue;
    if (g.get(x, y - 1)[0] === 'b') continue;
    if (g.get(x - 1, y - 1)[0] === 'b' && g.get(x + 1, y - 1)[0] === 'b')
      g.px(x, y, DARKER[g.get(x, y)]);
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
  //
  // ---- 캐노피에도 **지붕처럼 윗면이 있다** ----
  //
  // 우리 집이 상자로 보이는 까닭은 셋이다. 지붕의 **윗면**이 뒤로 누워
  // 보이고, 그 밑에 벽이 마주 서고, 처마가 벽 위로 그늘을 던진다.
  //
  // 나무도 똑같다. 위에서 비스듬히 내려다보는 화면이니 잎덩이의 **위쪽은
  // 하늘을 향해 누운 면**이고 아래쪽은 우리를 마주 보는 면이다. 예전에는
  // 덩이를 위아래 똑같이 동그랗게 그렸다 — 둥글기는 한데 「내려다보고
  // 있다」가 안 읽혀서, 크라운이 통째로 공 하나였다.
  //
  //   윗면(HZ 위)    **눌린** 타원. 위로 갈수록 더 눌리고 작아진다 (원근).
  //                  하늘을 정면으로 받으니 한 단 밝다
  //   앞면(HZ 아래)  동그란 덩이. 우리를 마주 보니 한 단 어둡다
  //   처마           윗면 앞끝이 앞면 위로 내밀어 그늘을 던진다 — 이 한 줄이
  //                  「윗면이 위에 있다」를 말한다
  //   용마루         맨 뒤 테두리는 하늘을 스치므로 제일 밝다
  const HZ = 94;                       // 캐노피의 지평선 (윗면 / 앞면)
  const CROWN_TOP = 14;
  // 어느 만큼 누운 면인가 (1 = 완전히 윗면, 0 = 마주 보는 앞면)
  const lay = (by) => Math.max(0, Math.min(1, (HZ - by) / (HZ - CROWN_TOP)));

  const BLOB = [
    // 윗면 — 뒤로 갈수록(위로 갈수록) 작고 촘촘하다. 집 지붕의 기와 켜가
    // 뒤로 갈수록 촘촘해지는 것과 같은 말이다 (그 간격이 곧 기울기다)
    [100, 18, 30, 15], [68, 26, 23, 12], [132, 26, 23, 12],
    [100, 38, 40, 20], [52, 46, 30, 16], [148, 46, 30, 16],
    [100, 62, 52, 30], [56, 78, 40, 25], [144, 78, 40, 25],
    // 앞면 — 우리를 마주 보는 처마 밑. 여기는 동그랗다
    [28, 104, 26, 21], [172, 104, 26, 21], [100, 106, 56, 28],
    [72, 122, 26, 17], [128, 122, 26, 17],
  ].map(([bx, by, rx, ry]) => [bx + sway(by), by, rx, ry, lay(by)]);

  // **뒤에서 앞으로** 그린다 (화면에서 위에 있는 덩이가 뒤다).
  // 하나 그리기 직전에 그 덩이의 그림자를 먼저 던져 두면, 그림자는 이미
  // 그려진 뒤쪽 덩이 위에만 앉는다 — 순서 하나로 앞뒤가 맞는다.
  const ORDER = BLOB.slice().sort((a, b) => a[1] - b[1]);
  for (const [bx, by, rx, ry0, up] of ORDER) {
    // 누운 만큼 눌린다. 위에서 내려다본 원은 타원이 되고, 뒤로 갈수록
    // 더 납작해진다 — 이 하나로 크라운이 「면」이 된다
    const ry = ry0 * (1 - 0.42 * up);
    // 그늘은 앞(아래)으로 진다. 누운 면일수록 제 그늘이 짧다
    g.castEllipse(bx + rx * 0.12, by + ry * (0.34 + 0.30 * up),
      rx * 0.90, ry * 0.86, 0.78 - up * 0.22);
    // 바탕 — 윗면은 한 단 밝은 데서 시작한다 (하늘을 정면으로 받는다)
    g.ellipse(bx, by, rx, ry, up > 0.5 ? 'l1' : 'l2');
    if (up > 0.5) {
      // 윗면: 위(뒤)가 밝고 앞끝이 조금 어둡다. 아랫배 그늘은 거의 없다 —
      // 누운 면에는 아랫배가 안 보인다
      g.ellipse(bx, by - ry * 0.22, rx * 0.90, ry * 0.70, 'l0', ['l1']);
      g.ellipse(bx - rx * 0.22, by - ry * 0.40, rx * 0.56, ry * 0.42, 'l0', ['l0']);
      g.ellipse(bx + rx * 0.10, by + ry * 0.52, rx * 0.84, ry * 0.42, 'l2', ['l1']);
      g.ellipse(bx + rx * 0.16, by + ry * 0.80, rx * 0.62, ry * 0.24, 'l3', ['l2']);
    } else {
      // 앞면: 덩이 하나하나가 **공**이다 — 위쪽 밝은 면 -> 아랫배 그늘 ->
      // 밑에서 되비치는 빛. 이 셋이 있어야 원반이 아니라 덩어리로 보인다
      g.ellipse(bx, by - ry * 0.28, rx * 0.88, ry * 0.62, 'l1', ['l2']);
      g.ellipse(bx - rx * 0.24, by - ry * 0.50, rx * 0.54, ry * 0.36, 'l0', ['l1']);
      g.ellipse(bx + rx * 0.12, by + ry * 0.44, rx * 0.82, ry * 0.50, 'l3', ['l2']);
      g.ellipse(bx + rx * 0.20, by + ry * 0.70, rx * 0.60, ry * 0.30, 'l4', ['l3']);
    }
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
  // 빛점은 왼쪽 **위**인데, 세로를 더 좁게 잡아 **위아래 차이가 크게** 만든다.
  // 동그란 등고선으로 두면 크라운이 공으로만 보인다 — 우리가 원하는 건
  // 「위에서 내려다본 면」이라, 밝기가 좌우보다 위아래로 더 갈려야 한다
  {
    const LX = 74, LY = 22;                  // 크라운의 빛점 (왼쪽 위)
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const c = g.d[y][x];
      if (c[0] !== 'l') continue;
      const d = Math.hypot((x - LX) / 168, (y - LY) / 96);
      // 경계에 테가 생기지 않게 문턱을 칸마다 조금씩 흔든다
      const j = (hash(x, y) - 0.5) * 0.09;
      if (d + j > 1.06) g.px(x, y, DARKER[DARKER[c]]);
      else if (d + j > 0.80) g.px(x, y, DARKER[c]);
      else if (d + j < 0.30) g.px(x, y, LIGHTER[c]);
    }
  }

  // ---- 처마 — 윗면 앞끝이 앞면 위로 내민다 ----
  //
  // 집에서 지붕이 「위에 얹혀 있다」를 말하는 건 처마 밑의 그늘 한 줄이다.
  // 면을 아무리 잘 칠해도 그 그늘이 없으면 지붕과 벽이 같은 판에 그린
  // 무늬가 된다. 캐노피도 같다.
  //
  // 지평선은 **곧은 가로선이 아니다.** 둥근 덩어리를 위에서 비스듬히 보면
  // 윗면과 앞면의 경계는 타원의 앞쪽 반이라 **한복판이 아래로 처진다**
  // (우리 쪽으로 가장 가까운 데가 한복판이다). 곧게 그으면 크라운이 그
  // 자리에서 접힌 종이가 된다 — 갓돌·켜에 쓴 sag 와 같은 규칙이다.
  {
    const CW = 94;                           // 크라운 반너비
    for (let x = 0; x < W; x++) {
      const rel = (x - CX) / CW;
      if (Math.abs(rel) > 1) continue;
      const hz = HZ + Math.round(15 * Math.sqrt(1 - rel * rel));
      for (let d = 0; d < 20; d++) {
        const c = g.get(x, hz + d);
        if (c[0] !== 'l') continue;
        const t = 1 - d / 20;                // 처마 바로 밑이 제일 어둡다
        if (hash(x * 5 + 7, (hz + d) * 3 + 2) < t * 0.88) g.px(x, hz + d, DARKER[c]);
      }
    }
  }

  // ---- 용마루 — 맨 뒤 테두리는 하늘을 스친다 ----
  //
  // 집도 지붕 맨 뒤 모서리 한 줄만 밝게 둔다. 그 한 줄이 「여기서 면이
  // 끝나고 하늘이다」를 말해서, 뒤로 누운 면이 정말 누워 보인다.
  for (let x = 0; x < W; x++) {
    for (let y = 0; y < H; y++) {
      if (g.get(x, y)[0] !== 'l') continue;
      for (let d = 0; d < 3; d++) {
        const c2 = g.get(x, y + d);
        if (c2[0] === 'l' && hash(x * 3 + d * 29, y) > 0.22) g.px(x, y + d, LIGHTER[c2]);
      }
      break;
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
    const SX = CX + 26, SR = 62, SY = GY - 3, SH = 8;   // 그림자 한가운데·반지름
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
        if (hash(x, y) > 1.25 - d * 0.8) continue;   // 가장자리만 성글게 (반그림자)
        g.px(x, y, at === '.' ? (d > 0.74 ? 'd0' : 'd1') : DARKER[at]);
      }
    }
  }

  g.outline('O', ['d0', 'd1']);
  return g;
}


// ============================================================
// 2. 큰 폭포 — 물만 그린다
// ============================================================
//
// 세 번 고쳐서 여기 왔다.
//
//   ① 화면 12.5칸짜리 바위 덩어리 — 풀밭에 세운 조형물이었다
//   ② 5.5칸으로 줄이고 양옆에 젖은 바위를 붙였다 — 게임에 넣어 보니
//      그 바위가 **물가 타일과 다른 돌**이라 이음매가 그대로 보였다
//   ③ 바위를 통째로 걷어냈다. 물가는 세계가 이미 제 타일로 그린다.
//      그림은 **물만** 맡는다 — 넘어가는 마루, 떨어지는 물, 부서지는 흰 물.
//
// 이으려면 겹치는 것을 줄여야 한다. 세계가 그릴 수 있는 것은 세계에 맡기고,
// 세계가 못 그리는 것(떨어지는 물)만 그린다.
function bigFalls(f, NF) {
  // 4칸으로 줄였더니 이번엔 **물줄기가 가늘어** 큰 폭포로 안 보였다.
  // 벼랑에서 물이 넘어가는 자리는 벼랑에 팬 **넓은 홈**이다 — 6칸으로 넓힌다
  // 마루 **위쪽 한 칸 반**을 그림이 같이 덮는다.
  //
  // 게임에 넣고서야 보였다 — 세계는 물가마다 **돌 테두리**(shore 타일)를
  // 두른다. 그래서 윗못의 물과 폭포 사이에 그 돌 테두리가 한 줄 끼어,
  // 물이 이어지지 않고 「돌 위에서 물이 새로 시작하는」 꼴이었다.
  //
  // 물칸을 못박아도 소용없다. 물이 있는 한 그 가장자리에는 테두리가 선다.
  // 그러니 그림이 그 위를 **덮어** 지나가야 한다 — 윗못 안에서 시작해,
  // 테두리를 건너, 마루를 넘어, 밑못까지. 그림 하나가 셋을 잇는다.
  const W = 96, H = 96, CX = 48;
  const HEAD = 28;               // 마루 위 — 아직 잔잔한 윗물 (테두리를 덮는다)
  const LIP = HEAD;              // 물이 넘어가는 마루
  const BASE = 82;               // 부서지는 자리 (밑 물의 수면)
  const g = new G(W, H);
  // 물은 **아래로** 흐른다. hash(y + f*6) 으로 두면 프레임마다 아래 것이
  // 위로 올라와 물이 거꾸로 솟는다 — 게임에 넣고서야 보였다. 빼야 내려간다
  const flowY = -f * 6;          // 결 폭 8 · 네 장에 24 = 딱 맞아떨어진다
  const wob = (f / NF) * Math.PI * 2;
  const halfAt = (y) => 34 + Math.max(0, y - LIP) * 0.12;

  // ---- 마루 위: **물을 칠하지 않는다** ----
  //
  // 윗못을 덮는 판을 한 장 깔아 봤다. 색을 게임 호수 단에서 가져와도
  // 못 위에 **네모난 딴 물**이 얹혀 보였다 — 잔물결 무늬가 타일과 따로
  // 놀아서, 아무리 가장자리를 뜯어도 그 자리만 결이 어긋난다.
  //
  // 마루 위에서 그림이 할 일은 물을 그리는 게 아니라 **물이 빨려 드는
  // 것**을 그리는 일이다. 바탕은 비워 세계의 못이 그대로 비치게 두고,
  // 홈으로 모여드는 흐름 줄기 몇 가닥만 얹는다. 안 그리는 게 제일 잘 잇는다.
  for (let i = 0; i < 18; i++) {
    const t0 = hash(i, 91);
    // 줄기는 바깥에서 시작해 마루 한복판으로 모인다.
    // 짧은 것을 많이 뿌렸더니 비 오는 것처럼 보였다 — 길게, 성글게
    const x0 = CX + (t0 - 0.5) * 76;
    const y0 = Math.floor(hash(i, 92) * (HEAD - 8));
    const len = 6 + Math.floor(hash(i, 93) * 10);
    for (let k = 0; k < len; k++) {
      const t = (y0 + k) / HEAD;
      // 아래로 갈수록 마루 쪽으로 모인다
      const x = Math.round(x0 * (1 - t * 0.42) + CX * t * 0.42);
      const y = y0 + k + ((f * 2) % 4) - 1;
      if (y < 0 || y >= HEAD) continue;
      if (Math.abs(x - CX) > halfAt(LIP) + 14) continue;
      g.px(x, y, hash(i, 94) > 0.72 ? 'w1' : 'w2');
    }
  }
  // 마루로 다가갈수록 물이 얕아져 밝아진다 — 마지막 세 줄만 옅게 깔아
  // 마루가 어디서 시작하는지 알려 준다 (성글게 찍어 못과 섞이게)
  for (let y = HEAD - 5; y < HEAD; y++) {
    const hw = halfAt(LIP) + (HEAD - y);
    for (let x = Math.round(CX - hw); x <= Math.round(CX + hw); x++) {
      const d = (y - (HEAD - 5)) / 5.0;
      if (hash(x, y + f * 3) > 0.25 + d * 0.7) continue;
      g.px(x, y, d > 0.6 ? 'w2' : 'w3');
    }
  }
  // 떨어지는 물
  for (let y = LIP; y <= BASE; y++) g.rect(CX - halfAt(y), y, CX + halfAt(y), y, 'w3');
  for (let y = LIP; y <= BASE; y++) {
    const hw = halfAt(y);
    for (let x = Math.round(CX - hw); x <= Math.round(CX + hw); x++) {
      if (g.get(x, y)[0] !== 'w') continue;
      const rel = (x - CX) / hw;
      // 두 겹 — 안 움직이는 긴 줄기 + 흘러내리는 결
      const streak = hash(x >> 1, y >> 5);
      const flow = hash(x >> 1, (y + flowY) >> 3);
      let c = 'w3';
      if (streak > 0.74) c = 'w2';
      else if (streak < 0.26) c = 'w4';
      if (flow > 0.80) c = LIGHTER[c];
      else if (flow < 0.16) c = DARKER[c];
      // 양옆은 바위에 스쳐 부서진다 (물가 타일과 맞닿는 자리라 밝게)
      if (Math.abs(rel) > 0.84) c = hash(x, y + flowY) > 0.45 ? 'w1' : 'w0';
      // 커튼은 평평한 천이 아니다 — 가운데가 불룩하고 양옆이 말려 든다
      else if (Math.abs(rel) > 0.62) c = DARKER[c];
      g.px(x, y, c);
    }
    // ---- 가장자리를 **뜯어 놓는다** ----
    //
    // 게임에서 보니 물줄기 좌우가 자로 자른 세로선이라, 폭포 자리에
    // **네모난 경계**가 보였다. 물이 바위에 스치는 자리는 갈라지고 튀어
    // 들쭉날쭉하다 — 바깥 세 줄을 성글게 지우고, 그 너머로 물방울을
    // 몇 개 튀겨 경계를 흐린다.
    for (let k = 0; k < 3; k++) {
      for (const side of [-1, 1]) {
        const xin = Math.round(CX + side * (hw - k));
        if (g.get(xin, y)[0] === 'w'
            && hash(xin * 3 + 1, y * 5 + side) < 0.30 + k * 0.22)
          g.px(xin, y, '.');
        const xout = Math.round(CX + side * (hw + 1 + k));
        if (g.get(xout, y) === '.'
            && hash(xout * 7 + 5, y * 3 + flowY) > 0.90 - k * 0.03)
          g.px(xout, y, hash(xout, y) > 0.5 ? 'w1' : 'w0');
      }
    }
  }
  // 넘어가는 마루 — 물이 둥글게 말리며 흰 선이 선다. 폭포의 시작점이라
  // 여기가 또렷해야 「여기서 떨어진다」가 보인다
  for (let d = 0; d < 4; d++) {
    const y = LIP + d;
    for (let x = Math.round(CX - halfAt(y)); x <= Math.round(CX + halfAt(y)); x++)
      if (g.get(x, y)[0] === 'w') g.px(x, y, d < 2 ? 'w0' : (d < 3 ? 'w1' : 'w2'));
  }

  // 부서지는 흰 물 — 못은 안 그린다 (세계가 진짜 물을 깔아 둔다)
  for (let i = 0; i < 26; i++) {
    const t = i / 25;
    const px = CX + Math.sin(i * 2.3) * 40 * (0.3 + t * 0.7);
    const py = BASE - 2 + Math.cos(i * 1.7) * 5;
    const r = (3.4 + hash(i, 7) * 4.4) * (1.0 + Math.sin(wob + i * 1.9) * 0.26);
    g.ellipse(px, py - Math.sin(wob + i) * 1.2, r, r * 0.5,
      hash(i, 3) > 0.45 ? 'w0' : 'w1');
  }
  // 수면에 퍼지는 흰 테 — 아주 납작해야 물 위에 누운 것으로 보인다
  for (let i = 0; i < 4; i++) {
    const grow = ((i + f) % 4);
    g.ellipse(CX, BASE + 1 + grow * 2.6, 20 + grow * 9, 1.8 + grow * 0.9,
      grow < 2 ? 'w0' : 'w1', ['.']);
  }
  // 물보라에 선 무지개 — 옅게, 흰 물 위에만
  for (let a = 0; a <= 80; a++) {
    const th = Math.PI + (a / 80) * Math.PI;
    for (let k = 0; k < 4; k++) {
      const rr = 30 + k * 2.5;
      const x = CX + Math.cos(th) * rr;
      const y = BASE - 3 + Math.sin(th) * rr * 0.7;
      const at = g.get(x, y);
      if ((at === 'w0' || at === 'w1') && a % 2 === 0)
        g.px(x, y, ['c0', 'c1', 'c2', 'c3'][k]);
    }
  }

  // **테를 두르지 않는다.** 물은 세계의 물·물가 타일과 이어져야 한다 —
  // 검은 선을 두르면 그 자리가 그대로 이음매가 된다
  return g;
}


// ============================================================
// 3. 붉은 바위 기둥 — 층층이 깎여 남은 것
// ============================================================
//
// 바람과 물이 무른 층을 먼저 파먹고 단단한 층만 남으면 기둥이 된다.
// 그래서 **허리가 잘록하고 머리가 넓다**. 위아래 굵기가 같으면 굴뚝이다.
function rockSpire(f, NF) {
  // 올라갈 수 있는 바위가 됐으니 그만큼 커야 한다 — 사람이 네 켜를 걸어
  // 올라온 끝에 서는 것인데, 그 앞의 바위가 제 키의 열 배는 되어야
  // 「여기가 꼭대기다」가 된다 (7.75 x 14.5칸 -> 9.5 x 17.25칸)
  const W = 152, H = 276, CX = 76, GY = H - 4;
  const g = new G(W, H);
  const wob = (f / NF) * Math.PI * 2;

  groundShadow(g, CX, GY, 48);

  // 굵기 — **잘록하게 하되 좌우 대칭으로는 안 된다.**
  //
  // 처음엔 허리를 깊게 파고 위아래를 똑같이 벌렸더니 도자기(꽃병)가 됐다.
  // 자연이 깎은 바위는 한쪽이 더 파이고, 켜마다 무른 층이 다르게 물러나
  // **계단처럼 들쭉날쭉**하다. 그래서
  //   ① 허리를 얕게만 파고 (30 -> 22)
  //   ② 켜마다 좌우로 다르게 물러나게 하고 (notch)
  //   ③ 기둥 전체를 조금 기울인다 (lean) — 곧추선 것은 사람이 세운 것이다
  const TOP = 24;
  const lean = (y) => (GY - y) / (GY - TOP) * 8;   // 위로 갈수록 오른쪽으로
  const halfAt = (y) => {
    const t = (GY - y) / (GY - TOP);              // 0 밑동 → 1 꼭대기
    const waist = 37 - 12 * Math.sin(Math.min(1, t / 0.74) * Math.PI * 0.5);
    const cap = t > 0.80 ? Math.pow((t - 0.80) / 0.20, 1.2) * 13 : 0;
    const foot = t < 0.13 ? Math.pow((0.13 - t) / 0.13, 2) * 12 : 0;
    return Math.max(7, waist + cap + foot);
  };
  const midAt = (y) => CX + lean(y) + Math.sin((GY - y) / 78) * 3;

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
  // ---- 켜 하나하나가 **원반**이다 ----
  //
  // 여기가 「평면이냐 입체냐」를 가른다.
  //
  // 켜를 네모로 쌓으면 아무리 톤을 잘 넣어도 **앞면만 있는 판**이다.
  // 실제 기둥의 켜는 원반이고, 위에서 비스듬히 내려다보면 그 원반의
  // 아랫변이 **가운데가 아래로 처진 곡선**으로 보인다 (원이 타원으로
  // 눌린 것의 앞쪽 반). 그 곡선 하나가 「이건 원기둥이다」를 말한다.
  //
  // 곧은 가로선은 그 자리에서 종이가 접힌 것처럼 보인다 — 자연이 만든
  // 것에는 곧은 가로선이 없다.
  const sag = (rel, amt) => amt * Math.sqrt(Math.max(0, 1 - rel * rel));
  for (const b of BANDS) {
    const hw = Math.max(1, (b.l + b.r) / 2);
    b.sagAmt = Math.max(1.6, hw * 0.26);
    for (let x = Math.round(b.mid - b.l); x <= Math.round(b.mid + b.r); x++) {
      const rel = (x - b.mid) / hw;
      g.rect(x, b.y0, x, b.y1 + Math.round(sag(rel, b.sagAmt)), 'k2');
    }
  }
  // 켜와 켜 사이의 틈을 메운다 (한 줄씩 비워 두면 기둥이 토막 난다) —
  // 좁은 쪽 폭으로 이어 붙이면 그 자리가 저절로 그늘진 골이 된다
  for (let i = 0; i + 1 < BANDS.length; i++) {
    const a = BANDS[i], c = BANDS[i + 1];
    const lo = Math.max(a.mid - a.l, c.mid - c.l);
    const hi = Math.min(a.mid + a.r, c.mid + c.r);
    const hw = Math.max(1, (hi - lo) / 2), mid = (lo + hi) / 2;
    for (let x = Math.round(lo); x <= Math.round(hi); x++) {
      const rel = (x - mid) / hw;
      g.rect(x, a.y1, x, c.y0 + Math.round(sag(rel, a.sagAmt)), 'k2');
    }
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
    // 단단한 켜의 밑은 처마가 되어 그늘이 진다 — 그 그늘도 **곡선**을
    // 따라가야 한다. 곧게 그으면 방금 만든 원반이 도로 납작해진다
    if (b.hard > 0.55) {
      const hw2 = Math.max(1, (b.l + b.r) / 2);
      for (let x = Math.round(b.mid - b.l + 1); x <= Math.round(b.mid + b.r - 1); x++) {
        const rel = (x - b.mid) / hw2;
        const yy = b.y1 + Math.round(b.sagAmt * Math.sqrt(Math.max(0, 1 - rel * rel)));
        if (g.get(x, yy)[0] === 'k') g.px(x, yy, 'k4');
        if (g.get(x, yy - 1)[0] === 'k') g.px(x, yy - 1, 'k4');
        if (g.get(x, yy + 1)[0] === 'k') g.px(x, yy + 1, 'k3');
      }
    }
  }

  // ---- 켜의 **윗면** — 내려다보이는 턱 ----
  //
  // 여기가 「우리 집처럼」의 핵심이다.
  //
  // 아래 켜가 위 켜보다 넓으면 그 차이만큼 **윗면이 드러난다.** 집으로
  // 치면 벽 위로 내민 처마의 윗면이고, 갓돌로 치면 이미 그려 둔 그 원반이다.
  // 그런데 켜에서는 그걸 안 그려서, 넓어지는 자리가 죄다 **곧은 가로 단차**
  // 였다 — 판을 층층이 쌓아 올린 것처럼 보인 진짜 이유다.
  //
  // 윗면의 뒤 테두리는 앞 밑변과 **반대로 휜다** (원반의 뒤쪽 반이라
  // 한복판이 위로 부푼다). 그리고 서는 면보다 **밝다** — 하늘을 정면으로
  // 받는 면이니까. 우리 집 지붕이 벽보다 밝은 것과 같은 이유다.
  for (let i = 1; i < BANDS.length; i++) {
    const b = BANDS[i], a = BANDS[i - 1];
    const hw = Math.max(1, (b.l + b.r) / 2);
    const lo = Math.max(a.mid - a.l, b.mid - b.l);   // 위 켜에 덮이는 구간
    const hi = Math.min(a.mid + a.r, b.mid + b.r);
    const ledge = [];
    for (let x = Math.round(b.mid - b.l); x <= Math.round(b.mid + b.r); x++) {
      if (x >= lo && x <= hi) continue;              // 덮인 데는 윗면이 안 보인다
      const rel = (x - b.mid) / hw;
      const back = Math.round(sag(rel, b.sagAmt * 0.85));
      if (back < 1) continue;
      ledge.push([x, back]);
      for (let d = 1; d <= back; d++) g.px(x, b.y0 - d, 'k1');
    }
    // 윗면 안에서도 뒤가 밝고 앞이 조금 어둡다 (하늘에 가까운 쪽이 밝다)
    for (const [x, back] of ledge) {
      for (let d = 1; d <= back; d++) {
        const t = d / back;                          // 1 = 뒤 테두리
        g.px(x, b.y0 - d, t > 0.62 ? 'k0' : (t > 0.28 ? 'k1' : 'k2'));
      }
      // 윗면과 서는 면이 만나는 모서리 한 줄 — 이 선이 두 면을 가른다
      if (g.get(x, b.y0)[0] === 'k') g.px(x, b.y0, 'k2');
    }
  }

  // ---- 꼭대기 갓돌 ----
  // 단단한 층 하나가 모자처럼 얹혀 있어 그 밑이 안 깎였다 — 이 기둥이
  // 남은 이유다. 그래서 **처마처럼 내밀어야** 한다. 둥근 뚜껑을 얹으면
  // 병마개가 되고, 왜 안 깎였는지가 안 보인다.
  // ---- 갓돌은 **내려다보이는 원반**이다 ----
  //
  // 네모로 얹으면 로마 기둥의 머리(주두)가 되고, 무엇보다 **윗면이 안
  // 보인다** — 그러면 아무리 잘 칠해도 앞에서 본 판 한 장이다.
  //
  // 우리 집들이 하는 그대로 한다. 집은 지붕의 **윗면**이 뒤로 누워 보이고,
  // 그 밑에 벽이 마주 서고, 처마가 벽 위로 내밀어 그늘을 던진다.
  // 그 셋이 있어서 집이 상자로 보인다. 갓돌도 똑같이:
  //
  //   윗면   위에서 내려다본 원 -> **눌린 타원** (가로:세로 = 1:0.46).
  //          이 게임이 세상을 내려다보는 각도가 그쯤이다
  //   옆면   원반의 두께. 윗면보다 어둡다 (눕는 면 / 서는 면)
  //   처마   옆면 밑으로 내민 그늘 — 기둥이 갓돌 **밑에** 있다는 표시
  // 폭은 기둥보다 **조금만** 내민다. 넉넉히 내밀었더니 버섯 갓이 됐다 —
  // 갓돌은 기둥에서 떨어져 나가다 만 켜지 딴 물건이 아니다
  const capX = midAt(TOP), capW = halfAt(TOP) + 2;
  const capRy = capW * 0.42;                 // 내려다본 만큼 눌린 세로
  const capCy = TOP - 6;                     // 윗면 한가운데
  const THICK = 7;                           // 원반의 두께
  const capHalf = (dy) => {                  // 그 줄에서 원반의 반너비
    const t = dy / capRy;
    return Math.abs(t) > 1 ? -1 : capW * Math.sqrt(1 - t * t);
  };
  // 옆면 — 윗면 타원의 **앞쪽 반**을 두께만큼 아래로 늘인다
  for (let x = Math.round(capX - capW); x <= Math.round(capX + capW); x++) {
    const rel = (x - capX) / capW;
    const front = capRy * Math.sqrt(Math.max(0, 1 - rel * rel));
    g.rect(x, capCy, x, capCy + front + THICK, 'k3');
  }
  // 윗면 — 눌린 타원. 옆면보다 **한 단 밝다** (하늘을 정면으로 받는 면)
  for (let dy = -Math.ceil(capRy); dy <= Math.ceil(capRy); dy++) {
    const hw = capHalf(dy);
    if (hw < 0) continue;
    const jag = Math.round(hash(dy, 51) * 2) - 1;   // 가장자리가 조금씩 깨져 있다
    for (let x = Math.round(capX - hw - jag); x <= Math.round(capX + hw + jag); x++) {
      // 윗면 안에서도 빛은 왼쪽 위 — 뒤쪽(위)이 밝고 앞쪽(아래)이 조금 어둡다
      const t = (dy + capRy) / (capRy * 2);
      g.px(x, capCy + dy, t < 0.34 ? 'k0' : (t < 0.72 ? 'k1' : 'k2'));
    }
  }
  // 윗면과 옆면이 만나는 모서리 — 한 줄만 또렷하게. 이 선이 두 면을 가른다
  for (let x = Math.round(capX - capW); x <= Math.round(capX + capW); x++) {
    const rel = (x - capX) / capW;
    const front = Math.round(capRy * Math.sqrt(Math.max(0, 1 - rel * rel)));
    if (g.get(x, capCy + front)[0] === 'k') g.px(x, capCy + front, 'k2');
  }
  // 내민 처마 밑의 그늘 — 이 그늘도 원반의 곡선을 따라간다
  for (let x = Math.round(capX - capW); x <= Math.round(capX + capW); x++) {
    const rel = (x - capX) / capW;
    const yy = Math.round(capCy + capRy * Math.sqrt(Math.max(0, 1 - rel * rel))) + THICK;
    for (let d = 0; d < 2; d++)
      if (g.get(x, yy + d)[0] === 'k') g.px(x, yy + d, d === 0 ? 'k4' : 'k3');
  }
  // 갓돌 윗면의 잔금 — 윗면에 있어야 윗면으로 읽힌다
  for (let i = 0; i < 10; i++) {
    const dy = Math.round((hash(i, 25) - 0.5) * capRy * 1.6);
    const hw = capHalf(dy);
    if (hw < 0) continue;
    const bx = capX + (hash(i, 21) - 0.5) * hw * 1.8;
    if (g.get(bx, capCy + dy)[0] === 'k') {
      g.px(bx, capCy + dy, 'k2');
      g.px(bx + 1, capCy + dy, 'k2');
    }
  }
  // 갓돌 위의 마른 풀 한 줌 — 바람에 눕는다.
  // 이 그림에서 유일하게 살아 있는 것이라, 여기가 흔들려야 그림이 산다
  // 풀은 윗면 **뒤쪽 테두리**를 따라 난다. 한복판에 심으면 낙서처럼 보이고,
  // 테두리를 따라 서야 그 테두리가 「둥근 윗면」임을 한 번 더 말해 준다
  for (let i = 0; i < 16; i++) {
    const th = Math.PI * (0.08 + (i / 15) * 0.84);        // 뒤쪽 반원
    const bx = capX - Math.cos(th) * capW * 0.88;
    const by = capCy - Math.sin(th) * capRy * 0.86;
    const h2 = 3 + Math.round(hash(i + 9, 2) * 4);
    const lean2 = Math.sin(wob + i * 0.6) * 1.8;
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

  // (밑동의 돌무지는 뺐다. 「사람 손이 닿았다」는 표시로 얹어 둔 것인데,
  //  이제 그 말은 **꼭대기까지 난 돌계단**이 훨씬 크게 하고 있다 —
  //  같은 말을 두 번 하면 작은 쪽이 군더더기가 된다)

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
// 4. 물레방아 — 방앗간 옆에서 돈다
// ============================================================
//
// 처음엔 바퀴만 그렸다. 게임에 넣으니 **수레바퀴 하나가 풀밭에 떠 있었다** —
// 굴대도 받침도 없고, 물에 잠기지도 않았다.
//
// 물레방아가 물레방아로 보이려면 셋이 있어야 한다:
//   ① 두께   바퀴는 판이 아니라 **원반**이다. 뒤쪽 테를 살짝 어긋나게
//            겹쳐 그리면 그 사이가 두께가 된다 (갓돌과 같은 규칙)
//   ② 받침   굴대를 얹은 나무 기둥과 들보. 이게 없으면 공중에 뜬다
//   ③ 물길   바퀴 아랫도리가 **물에 잠겨** 있어야 물이 돌린다
//
// 살은 여섯. 한 장에 15도씩 돌려 네 장에 60도 = 살 하나 간격이라 딱 이어진다
// (여덟 살을 45도로 두면 반 바퀴에서 처음과 같아 보여 안 도는 것 같다).
function millWheel(f, NF) {
  const W = 64, H = 76, CX = 33, CY = 30, R = 24;
  const g = new G(W, H);
  const rot = (f / NF) * (Math.PI * 2 / 6);
  const DX = -3, DY = -3;                  // 뒤쪽 테가 어긋나는 만큼 = 두께

  // ---- 받침 ----
  // 굴대를 받치는 기둥 두 대와 들보. 방앗간 벽에 기대 서 있는 짜임이다
  g.rect(CX - R - 8, CY - 4, CX - R - 5, H - 6, 'b2');     // 왼쪽 기둥
  g.rect(CX + R + 5, CY - 4, CX + R + 8, H - 6, 'b2');     // 오른쪽 기둥
  g.rect(CX - R - 8, CY - 6, CX + R + 8, CY - 4, 'b1');    // 들보
  for (let y = CY - 4; y < H - 6; y++)                     // 기둥의 결
    for (const bx of [CX - R - 7, CX + R + 6])
      if (hash(bx, y >> 1) > 0.6) g.px(bx, y, 'b3');
  // 버팀목 — 비스듬한 나무 하나가 있어야 짜임으로 보인다
  g.bone(CX - R - 6, CY + 2, CX - R + 4, CY + 18, 3, 3, 'b2');
  g.bone(CX + R + 6, CY + 2, CX + R - 4, CY + 18, 3, 3, 'b2');

  // ---- 뒤쪽 테 (두께) ----
  for (let a = 0; a < 220; a++) {
    const th = a / 220 * Math.PI * 2;
    for (let k = -1; k <= 1; k++)
      g.px(CX + DX + Math.cos(th) * (R + k), CY + DY + Math.sin(th) * (R + k), 'b3');
  }

  // ---- 살과 물받이 ----
  for (let i = 0; i < 6; i++) {
    const th = rot + i * (Math.PI * 2 / 6);
    const ex = CX + Math.cos(th) * R, ey = CY + Math.sin(th) * R;
    // 뒤쪽 살 (두께 쪽) 먼저 — 앞쪽 살이 그 위를 덮는다
    g.bone(CX + DX + Math.cos(th) * 5, CY + DY + Math.sin(th) * 5,
      ex + DX, ey + DY, 3, 2, 'b3');
    g.bone(CX + Math.cos(th) * 5, CY + Math.sin(th) * 5, ex, ey, 4, 3, 'b1');
    // 물받이 널 — 살 끝에서 바퀴를 따라 접힌다. 두께만큼 뒤로도 이어진다
    const tx = ex + Math.cos(th + Math.PI / 2) * 6;
    const ty = ey + Math.sin(th + Math.PI / 2) * 6;
    g.bone(ex + DX, ey + DY, tx + DX, ty + DY, 5, 4, 'b3');
    g.bone(ex, ey, tx, ty, 5, 4, 'b2');
    // 올라가는 쪽 통에는 물이 담겨 넘친다
    if (Math.sin(th) > 0.1) {
      g.ellipse(tx, ty, 3, 2.2, 'w1');
      g.px(tx, ty + 3, 'w0');
      g.px(tx + 1, ty + 4, 'w1');
    }
  }
  // 앞쪽 테 — 안팎 두 겹. 한 겹만 두면 바퀴가 아니라 별이 된다
  for (let a = 0; a < 240; a++) {
    const th = a / 240 * Math.PI * 2;
    for (let k = -1; k <= 1; k++)
      g.px(CX + Math.cos(th) * (R + k), CY + Math.sin(th) * (R + k), 'b1');
    g.px(CX + Math.cos(th) * (R - 5), CY + Math.sin(th) * (R - 5), 'b2');
  }
  // 굴대
  g.ellipse(CX + DX, CY + DY, 4, 4, 'b3');
  g.ellipse(CX, CY, 5, 5, 'b2');
  g.ellipse(CX - 1, CY - 1, 3, 3, 'b0');
  // ---- 결 ----
  //
  // 방앗간 바퀴는 **거친 나무**다. 물을 맞으며 몇십 년을 돈 널이라
  // 매끈할 수가 없다 — 결이 일어나고, 옹이가 박히고, 톱자국이 남고,
  // 물에 잠기는 아랫도리는 검게 삭는다.
  //
  // 처음엔 잔 얼룩만 뿌렸더니 새로 깎은 나무처럼 보였다. 거칠게 보이려면
  // 얼룩이 아니라 **결의 방향**이 있어야 한다 — 널을 따라 길게.
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const c = g.d[y][x];
    if (c[0] !== 'b') continue;
    // 바퀴살·물받이는 나뭇결이 **바큇살 방향**으로 간다. 굴대에서
    // 바깥으로 뻗는 결이라, 굴대 기준 각도로 묶으면 저절로 그 방향이 된다
    const dx = x - CX, dy = y - CY;
    const rr = Math.hypot(dx, dy), th = Math.atan2(dy, dx);
    const grain = hash(Math.round(th * 9), Math.round(rr / 2.2));
    let n = c;
    if (grain > 0.70) n = DARKER[n];
    else if (grain < 0.20) n = LIGHTER[n];
    // 톱자국 — 결을 가로지르는 짧은 금
    if (hash(x >> 1, y) > 0.93) n = DARKER[n];
    // 옹이
    if (hash(x >> 2, y >> 2) > 0.965) { n = 'b3'; }
    // 물에 잠기는 아랫도리는 삭아서 검다
    if (y > CY + 12 && hash(x, y >> 1) > 0.42) n = DARKER[n];
    g.px(x, y, n);
  }
  // 널의 이음매 — 물받이 널 하나하나가 갈라져 보여야 짜 맞춘 것이 된다
  for (let i = 0; i < 6; i++) {
    const th = rot + i * (Math.PI * 2 / 6) + Math.PI / 6;
    for (let r2 = R - 6; r2 <= R + 2; r2++) {
      const x = CX + Math.cos(th) * r2, y = CY + Math.sin(th) * r2;
      if (g.get(x, y)[0] === 'b') g.px(x, y, 'b3');
    }
  }

  // ---- 물에 잠긴다 ----
  //
  // 바퀴는 물을 **퍼 올려야** 돌아간다. 수면에 얹혀만 있으면 헛돈다.
  // 그래서 아랫도리 한 자락이 물속에 들어가 있어야 하고, 그 자리에는
  //   ① 물에 잠긴 부분이 **어두워지는 물선**
  //   ② 그 밑으로 비쳐 보이는 흐릿한 나무
  //   ③ 수면에서 튀는 흰 물
  // 이 셋이 다 있어야 「잠겼다」로 읽힌다. 하나만 있으면 물때가 낀 것 같다.
  const WL = CY + R - 12;                    // 물선 (여기부터 잠긴다)
  for (let y = WL; y < H; y++) for (let x = 0; x < W; x++) {
    const c = g.d[y][x];
    if (c[0] !== 'b') continue;
    // 깊이 들어갈수록 물빛에 먹힌다 — 형체만 남다가 결국 안 보인다
    const d = Math.min(1.0, (y - WL) / 14.0);
    g.px(x, y, d > 0.66 ? 'w5' : (d > 0.3 ? DARKER[DARKER[c]] : DARKER[c]));
  }
  // 물선 — 수면이 나무를 자르는 자리. 이 한 줄이 제일 크게 말한다
  for (let x = 0; x < W; x++) {
    if (g.get(x, WL)[0] === 'b' || g.get(x, WL)[0] === 'w')
      g.px(x, WL, hash(x + f * 2, 3) > 0.5 ? 'w0' : 'w1');
    if (g.get(x, WL + 1)[0] !== '.' && hash(x + f * 2, 5) > 0.6)
      g.px(x, WL + 1, 'w1');
  }
  // 잠긴 자리에서 튀는 물
  for (let i = 0; i < 12; i++) {
    const px = CX - 18 + i * 3.2 + Math.sin(f * 1.7 + i) * 1.6;
    const py = WL - 1 + Math.cos(f + i) * 2.2;
    g.ellipse(px, py, 4, 2.0, i % 2 ? 'w0' : 'w1');
  }
  // 바퀴가 물을 퍼 올리며 떨어뜨리는 물줄기
  for (let i = 0; i < 5; i++) {
    const px = CX + 10 + i * 2.4;
    const y0 = CY + 4 + ((f * 3 + i * 5) % 18);
    g.vline(px, y0, y0 + 3, i % 2 ? 'w1' : 'w0');
  }

  g.outline('O', ['w0', 'w1', 'w2', 'w3']);
  return g;
}


// ============================================================
// 5. 석등 — 돌계단을 따라 늘어선다
// ============================================================
//
// 계단만 놓으면 「지형이 낮아졌다 높아졌다」로 보인다. 참고 사진에서
// 그 길을 **길로** 만드는 건 계단이 아니라 **양옆에 늘어선 등**이다.
// 같은 것이 되풀이되면서 길의 방향과 길이를 한눈에 말해 준다 —
// 우리 집들이 처마 밑에 같은 창을 늘어놓아 「벽」을 말하는 것과 같다.
//
// 그래서 이 그림은 하나로 잘 보일 필요가 없다. **여럿이 줄지어 섰을 때**
// 리듬이 나와야 한다. 그러려면 실루엣이 단순하고 위아래가 또렷해야 한다:
//   갓   위에서 내려다보이는 **눌린 사각뿔** — 지붕이다
//   불집 네모 상자. 앞면에 불빛이 새는 창
//   기둥 원기둥 (다섯 켜)
//   받침 땅에 앉는 **눌린 원반**
function stoneLamp(f, NF) {
  const W = 20, H = 34, CX = 10, GY = H - 2;
  const g = new G(W, H);
  groundShadow(g, CX, GY, 7);

  // ---- 받침 — 내려다본 원반 ----
  const baseCy = GY - 3, baseW = 7, baseRy = baseW * 0.42;
  for (let x = CX - baseW; x <= CX + baseW; x++) {
    const rel = (x - CX) / baseW;
    const front = baseRy * Math.sqrt(Math.max(0, 1 - rel * rel));
    g.rect(x, baseCy, x, baseCy + front + 3, 'r3');
  }
  g.ellipse(CX, baseCy, baseW, baseRy, 'r1');
  g.ellipse(CX, baseCy - baseRy * 0.3, baseW * 0.8, baseRy * 0.6, 'r0', ['r1']);

  // ---- 기둥 — 원기둥 다섯 켜 ----
  const postTop = 13, postW = 3;
  for (let y = postTop; y <= baseCy; y++) {
    for (let x = CX - postW; x <= CX + postW; x++) {
      const rel = (x - CX) / postW;
      let c = rel < -0.72 ? 'r1' : (rel < -0.24 ? 'r0' : (rel < 0.2 ? 'r1'
        : (rel < 0.6 ? 'r2' : (rel < 0.9 ? 'r3' : 'r2'))));
      if (hash(x, y >> 1) > 0.86) c = DARKER[c] || c;   // 돌결
      g.px(x, y, c);
    }
  }

  // ---- 불집 — 상자. 앞면에 불빛이 새는 창 ----
  const boxY0 = 6, boxY1 = 13, boxW = 5;
  for (let y = boxY0; y <= boxY1; y++)
    for (let x = CX - boxW; x <= CX + boxW; x++)
      g.px(x, y, x - CX < -1 ? 'r1' : (x - CX > 2 ? 'r3' : 'r2'));
  // 창 — 안쪽이 제일 밝고 테두리로 갈수록 잦아든다 (등은 **속이** 밝다)
  for (let y = boxY0 + 2; y <= boxY1 - 2; y++)
    for (let x = CX - boxW + 2; x <= CX + boxW - 2; x++) {
      const d = Math.hypot((x - CX + 0.5) / (boxW - 1.5), (y - (boxY0 + boxY1) / 2) / 2.6);
      g.px(x, y, d < 0.45 ? 'g0' : (d < 0.8 ? 'g1' : 'g2'));
    }
  // 창살 — 세로 두 줄. 이게 없으면 노란 네모다
  for (let y = boxY0 + 1; y <= boxY1 - 1; y++) {
    g.px(CX - 2, y, 'r3');
    g.px(CX + 1, y, 'r3');
  }

  // ---- 갓 — **내려다보이는 지붕** ----
  //
  // 여기가 우리 집과 같은 자리다. 처마가 불집 밖으로 내밀고, 그 윗면이
  // 뒤로 누워 보이고, 처마 밑에 그늘 한 줄이 진다. 그 셋이 있어야 상자
  // 위에 얹힌 뚜껑이 아니라 「지붕」이 된다
  const capW = boxW + 3, capCy = boxY0 - 3, capRy = capW * 0.40;
  for (let x = CX - capW; x <= CX + capW; x++) {
    const rel = (x - CX) / capW;
    const front = capRy * Math.sqrt(Math.max(0, 1 - rel * rel));
    g.rect(x, capCy, x, capCy + front + 2, 'r3');       // 갓의 두께(서는 면)
  }
  for (let dy = -Math.ceil(capRy); dy <= Math.ceil(capRy); dy++) {
    const t = (dy + capRy) / (capRy * 2);
    const hw = capW * Math.sqrt(Math.max(0, 1 - (dy / capRy) ** 2));
    for (let x = Math.round(CX - hw); x <= Math.round(CX + hw); x++)
      g.px(x, capCy + dy, t < 0.34 ? 'r0' : (t < 0.72 ? 'r1' : 'r2'));
  }
  // 처마 밑 그늘 — 「갓이 위에 있다」를 말하는 한 줄
  for (let x = CX - capW; x <= CX + capW; x++) {
    const rel = (x - CX) / capW;
    const yy = Math.round(capCy + capRy * Math.sqrt(Math.max(0, 1 - rel * rel))) + 2;
    if (g.get(x, yy)[0] === 'r' || g.get(x, yy)[0] === 'g') g.px(x, yy, 'r4');
  }
  // 꼭지 — 갓 위의 작은 구슬
  g.ellipse(CX, capCy - capRy - 1, 2, 1.6, 'r1');
  g.ellipse(CX - 0.5, capCy - capRy - 1.4, 1.2, 0.9, 'r0', ['r1']);

  // 이끼 — 밑동과 북쪽 면에. 오래 서 있었다는 표시
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (g.d[y][x][0] !== 'r') continue;
    const low = y > baseCy - 4 ? 0.34 : (y > postTop ? 0.10 : 0.04);
    if (hash(x * 3 + 1, y * 5 + 2) < low) g.px(x, y, hash(x, y) < 0.5 ? 'm1' : 'm2');
  }

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
  deco_stonelamp: { fn: stoneLamp, frames: 1 },
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
