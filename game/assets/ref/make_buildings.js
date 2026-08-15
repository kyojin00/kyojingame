// 건물 생성기 — **캐릭터와 같은 도트 크기**로, 옛 집의 색·질감을 따라 그린다.
//
// 왜 다시 그리는가 —
//   캐릭터: 32x48 논리 격자를 화면에 2배로   -> 화면 2px = 도트 한 칸
//   옛 건물: 512x410 그림을 화면에 0.5배로   -> 화면 1px = 원본 2px
// 건물 쪽 도트가 **4배 촘촘해서**, 나란히 두면 사람만 굵고 건물은 매끈해
// 같은 게임의 그림으로 안 읽힌다.
//
// 옛 그림을 4칸씩 묶어 굵게 만들어도 봤지만 **서까래·창틀이 뭉갰다** —
// 얇은 선으로 그린 그림은 묶으면 선이 죽는다. 그래서 처음부터
// **128x114 논리 격자**에 굵은 형태로 그리고 4배로 펴서 512x456으로 낸다.
// 폭은 게임이 쓰던 512 그대로고, 세로만 뒤로 눕는 지붕 자리만큼 키웠다
// (world_gen 이 그림 높이를 읽어 밑변을 맞추므로 좌표는 저절로 따라온다).
//
// 색은 **옛 집에서 실제로 뽑았다** — 주황 기와(252,100,27), 따뜻한 갈색
// 목재(148,90,42), 회백색 회벽(194,180,169). 그래서 굵어져도 같은 마을로 보인다.
//
// 굵은 격자에서 지키는 것:
//   * 선은 **한 칸**. 두 칸이면 화면에서 4px이 되어 뭉툭해진다
//   * 면은 세 톤까지. 그 이상은 굵은 칸에서 얼룩이 된다
//   * 창·문 같은 것은 **최소 3x3칸**. 그보다 작으면 무엇인지 안 읽힌다
//   * 넓은 면에는 **결**을 흩는다 (roughen) — 한 색으로 채우면 비닐처럼 보인다
//
// 실행:  node make_buildings.js            -> ref/proposed_*.png (제안만)
//        node make_buildings.js --install  -> sprites/ 에 실제로 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');
// 그림체 — 넓은 면을 어떻게 칠할까
//   soft  면 셋(밝은 면·기본·그늘) + 경계 두 줄만 바둑판  (기본)
//   flat  면 셋, 디더 없이 칼같이 갈린다
//   8bit  면 **둘**뿐 (밝은 면·그늘). 색이 적을수록 옛 기계 느낌이 난다
const STYLE = (process.argv.find(a => a.startsWith('--style=')) || '').slice(8) || 'soft';
const OUT = INSTALL ? SPR : REF;
const PRE = INSTALL ? '' : 'proposed_';

const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)
// 캔버스를 위로 서른여섯 칸 키웠다. 앞모습은 그대로 아래로 내려앉고,
// 새로 생긴 위쪽 자리를 **뒤로 물러나는 지붕**이 전부 쓴다.
//
// 바닥선(GROUND)도 같이 내려야 한다 — world_gen 이 그림 **높이**로 밑변을
// 맞추므로, 바닥을 그대로 두고 캔버스만 키우면 집이 공중에 뜬다.
const GW = 128, GH = 138;
const FW = GW * S, FH = GH * S;

// 옛 집에서 뽑은 색. 각 재료는 [기본, 그늘, 밝은 면] 세 톤.
const PAL = {
  '.': null,
  'O': [32, 24, 28],        // 윤곽선. 레트로는 선이 진할수록 또렷하다
  // 기와
  'r': [232, 84, 24], 'R': [148, 44, 20], 'l': [255, 148, 56],
  // 회벽
  'w': [222, 206, 176], 'W': [166, 148, 122], 'x': [248, 240, 216],
  // 목재
  't': [156, 88, 32], 'T': [92, 48, 20], 'u': [200, 128, 52],
  // 벽돌. 한 색으로 칠한 회벽은 넓은 면에서 비닐처럼 보인다 —
  // 줄눈이 있어야 벽이 **쌓아 올린 것**으로 읽힌다
  'k': [176, 110, 70], 'K': [116, 68, 44], 'i': [210, 148, 100],
  // 돌
  's': [138, 132, 126], 'S': [96, 92, 88],
  // 유리
  'g': [72, 148, 200], 'G': [36, 84, 140], 'e': [168, 216, 248],
  // 잎·꽃
  'n': [84, 156, 60], 'N': [44, 96, 40], 'v': [132, 194, 88],
  'f': [248, 244, 224],
  'm2': [148, 132, 108],
  // 간판
  'b': [206, 176, 122], 'B': [150, 122, 78],
  // 등불
  'y': [252, 214, 120], 'Y': [200, 150, 60],
  // 옆면 (3/4로 돌아간 면). 그늘색보다 **한 단계 더** 어둡다 —
  // 같은 색이면 결에 묻혀 정면과 안 갈린다
  // 가까운 쪽 -> 먼 쪽 세 단계. 한 색으로 두면 뒤가 슬래브처럼 평평해진다
  'm': [176, 158, 130], 'n2': [148, 132, 108], 'm3': [120, 106, 88],
  'M': [112, 32, 14], 'M2': [88, 26, 12], 'M3': [68, 20, 10],
  // 지붕 뒤쪽 세 단계는 **앞 지붕의 그늘색(R)에서 이어 내려간다.**
  // 밝게 잡았더니 처마 쪽 밝은 기와 바로 위에 또 밝은 띠가 생겨서
  // 지붕이 두 장으로 갈려 보였다. 지붕은 한 면이다 — 처마가 제일 가깝고
  // 용마루가 제일 멀다. 색도 그 순서로 한 줄기여야 한다.
  'Mn': [138, 40, 18],
  // 구조 그늘(제티 턱·처마 밑) 전용. 벽 그늘색(K)을 쓰면 나중에 도는
  // 벽돌 줄눈 패스가 통째로 덮어써서 **턱이 사라진다** — 실제로 사라졌었다
  'D': [88, 50, 34],
};

// 결을 낼 때 쓰는 대응표 (기본 <-> 그늘 / 밝은 면)
const DARKEN = { r: 'R', w: 'W', t: 'T', s: 'S', n: 'N', l: 'r', x: 'w', u: 't',
                 k: 'K', i: 'k', v: 'n' };
// m/M(옆면)은 일부러 뺐다 — 결이 앉으면 정면과 경계가 흐려진다
const LIGHTEN = { r: 'l', w: 'x', t: 'u', R: 'r', W: 'w', T: 't', S: 's',
                  k: 'i', K: 'k', n: 'v', N: 'n' };

class G {
  constructor() { this.d = Array.from({ length: GH }, () => new Array(GW).fill('.')); }
  px(x, y, c) { if (x >= 0 && y >= 0 && x < GW && y < GH) this.d[y][x] = c; }
  get(x, y) { return (x >= 0 && y >= 0 && x < GW && y < GH) ? this.d[y][x] : '.'; }
  rect(x0, y0, x1, y1, c) {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.px(x, y, c);
  }
  hline(x0, x1, y, c) { this.rect(x0, y, x1, y, c); }
  vline(x, y0, y1, c) { this.rect(x, y0, x, y1, c); }
  outline() {
    const add = [];
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
      if (this.d[y][x] !== '.') continue;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]])
        if (this.get(nx, ny) !== '.' && this.get(nx, ny) !== 'O') { add.push([x, y]); break; }
    }
    for (const [x, y] of add) this.px(x, y, 'O');
  }
  render() {
    const im = new PNG({ width: FW, height: FH });
    im.data.fill(0);
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
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

// 결 — 넓은 면에 얼룩을 흩는다. 캐릭터의 roughen과 같은 규칙:
//   ① **바둑판 위에만** 둔다. 아무 데나 흩으면 잡음이 되어 더러워 보인다
//   ② 자리는 **칸 좌표로만** 정한다 (건물은 안 움직이지만, 같은 자리에서
//      같은 결이 나와야 다시 뽑았을 때 그림이 안 바뀐다)
function hash(x, y) {
  let h = (x * 73856093) ^ (y * 19349663);
  h = (h ^ (h >> 13)) & 0x7FFFFFFF;
  return ((h * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}

// 옛 게임기의 그림자는 **규칙적인 바둑판**이었다. 색을 많이 못 써서
// 두 색을 번갈아 찍어 중간색을 만들어 냈기 때문이다. 무작위 얼룩은
// 요즘 그림처럼 보이고, 바둑판은 그때 그 느낌이 난다.
//
// 베이어 2x2 — 네 칸에 서로 다른 문턱을 주면 밝기가 층층이 갈리면서도
// 경계에 격자무늬가 남는다.
const BAYER = [[0.0, 0.5], [0.75, 0.25]];

// 면은 **평평하게** 두고, 톤이 바뀌는 **경계에서만** 바둑판으로 섞는다.
//
// 처음엔 위아래 그러데이션 전체에 디더를 깔았는데 온 벽이 격자무늬가 되어
// 기계처럼 보였다. 옛 게임 그림도 디더는 **아껴** 썼다 — 넓은 면은 한 색으로
// 시원하게 두고, 두 색이 만나는 두어 줄만 섞어 단차를 부드럽게 했다.
// 톤 경계의 바둑판 띠는 안 쓴다. 재질 얼룩(wallPatches)이 경계를 알아서
// 흐려 주는데 그 위에 규칙적인 격자까지 얹으면 그것만 눈에 띈다.
const BAND = 0;

function ditherFace(g, tones, y0, y1) {
  let [lite, base, dark] = tones;
  if (STYLE === '8bit') base = lite;          // 가운데 톤을 버린다 (면이 둘)
  const h = Math.max(1, y1 - y0);
  const b1 = y0 + Math.round(h * (STYLE === '8bit' ? 0.52 : 0.34));
  const b2 = y0 + Math.round(h * (STYLE === '8bit' ? 0.53 : 0.74));
  for (let y = y0; y <= y1; y++) for (let x = 0; x < GW; x++) {
    if (!tones.includes(g.d[y][x])) continue;
    let c;
    if (y < b1 - BAND) c = lite;
    else if (y <= b1 + BAND) c = ((x + y) % 2) ? lite : base;
    else if (y < b2 - BAND) c = base;
    else if (y <= b2 + BAND) c = ((x + y) % 2) ? base : dark;
    else c = dark;
    g.px(x, y, c);
  }
}

// 면을 갈라 놓은 위에 **재질**을 얹는다.
//
// 픽셀 하나씩 무작위로 찍었더니 TV 노이즈처럼 보였다 — 「딱딱 도트 찍은 느낌」.
// 진짜 재질은 **덩어리와 결**이 있다. 그래서 재료마다 구조를 준다:
//
//   기와  한 장씩 벽돌처럼 엇갈려 쌓고, 장마다 색을 조금씩 달리한다
//   회벽  두세 칸짜리 뭉텅이로 얼룩진다 (미장 자국)
//   목재  세로로 긴 결이 지나간다
//
// 핵심은 **좌표를 묶는 것**이다. hash(x, y)는 점이 되고,
// hash(x>>2, y>>1)은 덩어리가 된다.
const ROUGH = parseFloat((process.argv.find(a => a.startsWith('--rough=')) || '').slice(8))
  || 0.20;

// 기와 — 4x2 한 장씩, 한 줄 걸러 반 장씩 밀어 쌓는다
function roofTiles(g, top, base) {
  const TW = 5, TH = 3;
  for (let y = top; y <= base; y++) {
    const row = Math.floor((y - top) / TH);
    const shift = (row % 2) ? TW / 2 : 0;
    for (let x = 0; x < GW; x++) {
      const c = g.d[y][x];
      if (!'lrR'.includes(c)) continue;
      const col = Math.floor((x + shift) / TW);
      const r = hash(col, row);
      if (r < ROUGH && DARKEN[c]) g.px(x, y, DARKEN[c]);
      else if (r < ROUGH * 1.8 && LIGHTEN[c]) g.px(x, y, LIGHTEN[c]);
      // 장 아랫줄에 이음매 — **한 칸 걸러** 찍는다. 통줄로 그으면
      // 가로줄무늬가 지붕을 지배해서 기와가 아니라 골판지처럼 보인다.
      if ((y - top) % TH === TH - 1 && (x + row) % 2 === 0 && DARKEN[c])
        g.px(x, y, DARKEN[c]);
    }
  }
}

// 회벽 — 두세 칸짜리 뭉텅이. 큰 얼룩 위에 작은 얼룩을 겹쳐 자연스럽게.
function wallPatches(g, y0, y1) {
  for (let y = y0; y <= y1; y++) for (let x = 0; x < GW; x++) {
    const c = g.d[y][x];
    if (!'xwW'.includes(c)) continue;
    const big = hash(x >> 2, y >> 2);          // 4x4 뭉텅이
    const small = hash(x >> 1, y >> 1);        // 2x2 얼룩
    const v = big * 0.65 + small * 0.35;
    if (v < ROUGH && DARKEN[c]) g.px(x, y, DARKEN[c]);
    else if (v > 1.0 - ROUGH * 0.8 && LIGHTEN[c]) g.px(x, y, LIGHTEN[c]);
  }
}

// 벽돌 — 6x3 한 장, 한 켜 걸러 반 장씩 어긋나게 쌓는다 (영국식 쌓기).
//
// 좌표를 **캔버스 전체 기준**으로 잡는 게 중요하다. 벽마다 원점을 따로
// 두면 덩어리가 만나는 곳에서 켜가 어긋나 종이를 이어 붙인 것처럼 보인다.
// 온 건물의 줄눈이 한 줄로 이어져야 「한 채」로 읽힌다.
const BW = 6, BH = 3;
function brickCourse(g) {
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    const c = g.d[y][x];
    if (!'kKi'.includes(c)) continue;
    const course = Math.floor(y / BH);
    const u = x + (course % 2) * (BW / 2);      // 한 켜 걸러 반 장 밀기
    const col = Math.floor(u / BW);
    // 장마다 색이 조금씩 다르다 — 구운 벽돌은 한 장도 같은 게 없다
    const r = hash(col, course);
    let t = c;
    if (r < ROUGH * 1.4) t = DARKEN[c] || c;
    else if (r > 1.0 - ROUGH * 1.2) t = LIGHTEN[c] || c;
    // 줄눈 — 가로 한 줄 + 세로 이음매. 회반죽이 벽돌보다 어둡게 패인다
    if (y % BH === BH - 1 || u % BW === 0) t = 'K';
    g.px(x, y, t);
  }
}

// 목재 — 세로로 긴 결 (한 열이 위아래로 쭉 이어진다)
function woodGrain(g) {
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    const c = g.d[y][x];
    if (!'utT'.includes(c)) continue;
    if (hash(x, 0) < 0.30 && DARKEN[c]) g.px(x, y, DARKEN[c]);
  }
}

// 빛은 **건물 하나에 한 방향**이다. 덩어리마다 따로 밝기를 매기면
// 세 채를 붙여 놓은 것처럼 보인다 — 그래서 캔버스 전체를 한 번에 훑는다.
function roughen(g) {
  // 기와는 **거꾸로** 깐다 — 처마(아래)가 밝고 용마루(위)가 어둡다.
  // 위를 밝게 뒀더니 제일 먼 자리가 제일 밝아져서 원근이 뒤집혔다
  ditherFace(g, ['R', 'r', 'l'], 0, GROUND);
  ditherFace(g, ['i', 'k', 'K'], 0, GROUND);            // 벽돌
  ditherFace(g, ['x', 'w', 'W'], 0, GROUND);            // 석재 테두리
  roofTiles(g, 0, GROUND);
  brickCourse(g);
  wallPatches(g, 0, GROUND);
  woodGrain(g);
}


// 모서리를 깎는다 — 도트에서 「둥글다」는 **귀퉁이 한두 칸을 지우는 것**이다.
// 90도 각이 그대로 남아 있으면 아무리 색을 잘 써도 상자로 보인다.
function roundCorners(g, x0, y0, x1, y1, r) {
  for (let i = 0; i < r; i++) {
    const n = r - i;                       // 위에서부터 n칸씩 깎는다
    for (let k = 0; k < n; k++) {
      g.px(x0 + k, y0 + i, '.');
      g.px(x1 - k, y0 + i, '.');
      g.px(x0 + k, y1 - i, '.');
      g.px(x1 - k, y1 - i, '.');
    }
  }
}


// 실루엣의 **바깥 90도 귀퉁이를 한 칸씩 깎는다.**
//
// 모서리를 손으로 하나하나 깎는 것보다 이 한 번이 낫다 — 벽·지붕·굴뚝·
// 꽃상자까지 전부 같은 규칙으로 둥글어져서 결이 고르게 맞는다.
// 「비어 있는 이웃이 둘인데 그 둘이 붙어 있고 사이 대각도 비었다」면
// 그 칸은 바깥으로 튀어나온 귀퉁이다.
function soften(g) {
  const cut = [];
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    if (g.d[y][x] === '.') continue;
    const e = (dx, dy) => g.get(x + dx, y + dy) === '.';
    for (const [ax, ay, bx, by] of [[-1, 0, 0, -1], [1, 0, 0, -1],
                                    [-1, 0, 0, 1], [1, 0, 0, 1]])
      if (e(ax, ay) && e(bx, by) && e(ax + bx, ay + by)) { cut.push([x, y]); break; }
  }
  for (const [x, y] of cut) g.px(x, y, '.');
  // 귀퉁이를 깎다 보면 한두 칸이 몸에서 떨어져 티끌로 남는다. 걷어 낸다.
  const lab = new Int32Array(GW * GH).fill(-1), sizes = [];
  for (let i = 0; i < GW * GH; i++) {
    if (lab[i] >= 0 || g.d[(i / GW) | 0][i % GW] === '.') continue;
    const id = sizes.length, st = [i]; lab[i] = id; let n = 0;
    while (st.length) {
      const q = st.pop(); n++;
      const qx = q % GW, qy = (q / GW) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = qx + dx, ny = qy + dy;
        if (nx < 0 || ny < 0 || nx >= GW || ny >= GH) continue;
        const r = ny * GW + nx;
        if (lab[r] >= 0 || g.d[ny][nx] === '.') continue;
        lab[r] = id; st.push(r);
      }
    }
    sizes.push(n);
  }
  for (let i = 0; i < GW * GH; i++)
    if (lab[i] >= 0 && sizes[lab[i]] < 12) g.d[(i / GW) | 0][i % GW] = '.';
}


// 깊이를 붙여 상자로 만든다 — **일자로 뒤(위)로** 물러난다.
//
// 정면만 그리면 종이를 오려 세운 것처럼 평평하다. 실루엣을 위로 한 칸씩
// 밀며 어두운 색으로 깔면, 정면 위로 **뒤로 물러난 면**이 생긴다.
//
// 옆(오른쪽)으로 비스듬히 밀어도 봤는데 건물이 기울어 보였다. 위에서
// 내려다보는 화면이라 **뒤 = 위**다. 일자로 밀어야 정면을 마주 본 채로
// 두께만 생긴다 (지붕은 뒤로 흐르고, 벽은 정면에 그대로 남는다).
//
// 색은 **한 가지씩만** (지붕 뒤 / 벽 뒤). 정면 그림을 그대로 밀면
// 창문·문이 위로 죽 늘어나 얼룩이 된다.
// 열 칸으로는 **두께**밖에 안 나온다. 사진의 지붕이 「면」으로 보이는 건
// 뒤로 흐르는 거리가 정면 벽만큼 길어서다. 열다섯 칸 = 화면에서 30px,
// 정면 벽(37칸)의 절반쯤 — 이제 눈이 이걸 「지붕」으로 읽는다.
// 열세 칸은 「두껍다」, 스물네 칸은 「길다」, 서른여섯 칸은 **「뻗어 있다」**이다.
// 앞 지붕(마흔 칸)과 거의 맞먹는 길이라, 지붕이 몸통 뒤로 한참 이어진다.
const DEPTH = 36;

// 그리고 **멀어질수록 좁아진다.**
//
// 일자로만 밀면 아무리 깊어도 벽이 위로 자란 것처럼 보인다. 진짜로 뒤로
// 가는 것은 작아진다 — 그게 원근이다. 좌우로 비스듬히 미는 건 이미 해 봤고
// 건물이 기울어 보여서 접었는데, **가운데로 모으는 것**은 다르다.
// 양쪽이 똑같이 좁아지므로 정면은 마주 본 채로 뒤만 멀어진다.
// 깊어진 만큼 더 모아 준다. 길이가 두 배인데 좁아지는 폭이 그대로면
// 뒤가 멀어지는 게 아니라 그냥 길쭉해 보인다
const TAPER = 0.26;              // 맨 뒤에서 26% 좁아진다
const VPX = GW / 2;              // 소실점 x (건물 한가운데 위)

// 뒤로 물러나는 면은 **멀어질수록 어두워진다.** 한 색으로 채우면 두께가
// 아니라 슬래브가 된다 — 세 단계로 갈라야 「공간」으로 읽힌다.
const BACK_ROOF = ['Mn', 'M', 'M2'];      // 가까운 쪽 -> 먼 쪽
const BACK_WALL = ['m', 'm2', 'm3'];

// 뒤 색은 **처마 높이가 아니라 재료로** 고른다.
//
// 처음엔 「처마선보다 위면 지붕색」으로 잘랐는데, 덩어리가 셋이 되면서
// 처마가 세 높이로 갈라지자 날개 지붕이 벽색으로 밀려 올라갔다. 굴뚝도
// 돌인데 뒤가 주황이 됐다. 밀려 올라가는 칸 **자기 색**을 보고 정하면
// 덩어리가 몇이든 저절로 맞는다.
const BACK_STONE = ['S', 'S', 'S'];
const ROOF_SEAM = { Mn: 'M', M: 'M2', M2: 'M3' };   // 켜·이음매는 한 단 더 어둡게
const BACK_OF = {
  l: BACK_ROOF, r: BACK_ROOF, R: BACK_ROOF,
  s: BACK_STONE, S: BACK_STONE,
};
// 기와 켜가 **뒤로 갈수록 촘촘해진다.** 같은 간격으로 그으면 지붕이
// 누워 있지 않고 서 있는 것처럼 보인다 — 줄 간격이 곧 기울기다.
const COURSE = (() => {
  const out = new Set();
  let i = 0, gap = 4.2;
  while (i < DEPTH) { i += Math.max(1, Math.round(gap)); out.add(i); gap *= 0.70; }
  return out;
})();

function extrude(g) {
  const back = new G();
  const dep = Array.from({ length: GH }, () => new Array(GW).fill(0));
  // 가까운 쪽부터 채운다 — 먼저 칠한 쪽(가까운 쪽)이 이긴다
  for (let i = 1; i <= DEPTH; i++) {
    const k = Math.min(2, Math.floor((i - 1) * 3 / DEPTH));
    const s = 1 - TAPER * (i / DEPTH);
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
      const c = g.d[y][x];
      if (c === '.') continue;
      const ny = y - i;
      if (ny < 0) continue;
      // 칸 하나를 **폭 s의 띠**로 옮긴다. 점 하나로 옮기면 좁아지는 만큼
      // 사이가 벌어져 뒤가 빗살처럼 뚫린다
      const a = Math.round(VPX + (x - VPX - 0.5) * s);
      const b = Math.round(VPX + (x - VPX + 0.5) * s);
      const tone = (BACK_OF[c] || BACK_WALL)[k];
      for (let nx = a; nx <= b; nx++) {
        if (nx < 0 || nx >= GW || back.d[ny][nx] !== '.') continue;
        back.px(nx, ny, tone); dep[ny][nx] = i;
      }
    }
  }
  // 뒷 지붕면에 기와를 깐다 — 켜(가로줄)와 이음매(세로줄)를 함께.
  // 가로줄만 그으면 골판지, 이음매까지 있어야 한 장씩 얹은 기와가 된다
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    const c = back.d[y][x];
    if (!BACK_ROOF.includes(c)) continue;
    const i = dep[y][x], deeper = ROOF_SEAM[c];
    const row = [...COURSE].filter(v => v <= i).length;     // 몇 번째 켜인가
    if (COURSE.has(i)) { back.px(x, y, deeper); continue; }
    if ((x + row * 2) % 5 === 0) back.px(x, y, deeper);     // 켜마다 어긋난 이음매
  }
  // 뒤를 깔고 그 위에 정면을 얹는다
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++)
    if (g.d[y][x] === '.' && back.d[y][x] !== '.') g.px(x, y, back.d[y][x]);
  // 맨 뒤 용마루 — 하늘을 받는 모서리라 밝다. 지붕 뒷면에만 얹는다
  // (굴뚝 꼭대기까지 주황으로 칠하면 그것만 튄다)
  for (let x = 0; x < GW; x++) for (let y = 0; y < GH - 1; y++)
    if (g.d[y][x] !== '.') { if (BACK_ROOF.includes(g.d[y][x])) g.px(x, y, 'Mn'); break; }
}


// ---- 뼈대 ----
//
// **한 덩어리 집으로 되돌렸다.**
//
// 사진(커뮤니티 센터)을 보고 정면 박공 셋짜리로 갈라 봤지만, 그건 마을
// 회관의 형태지 우리 집의 형태가 아니었다. 사진에서 가져올 것은 **재질과
// 뒤로 눕는 지붕**이지 덩어리 구성이 아니다.
//
// 그래서 처음 그렸던 모양 그대로 —
//   1층 벽 위에 2층이 턱(제티)만큼 앞으로 나오고, 그 위에 몸통보다 큰
//   지붕 하나가 앞을 보고 얹힌다. 옛 집이 아늑해 보이는 건 지붕이 크기 때문이다.
//
// 옛 판과 다른 건 좌우 위치뿐이다. 예전엔 10..100에 그려 오른쪽이 비어
// 있었는데(비스듬히 밀던 시절의 자리), 지금은 곧게 뒤로 미니까
// 캔버스 한가운데에 놓는 게 맞다.
const GROUND = 131;              // 바닥선
const MID = 109;                  // 1층·2층 경계
const EAVE = 87;                 // 처마. 낮을수록 지붕이 커진다
const RIDGE = 47;                // 용마루 (위로 DEPTH만큼 더 물러날 자리를 남긴다)
// 크기는 **옛 집에서 재 왔다** — 내용이 292x384px = 73x96칸이고 캔버스
// 한가운데에 있다. 이걸 안 맞추면 집만 혼자 커져서 마을이 안 맞는다.
const X0 = 34, X1 = 94;          // 1층 벽 좌우 (지붕까지 73칸, 한가운데 정렬)
const JUT = 3;                   // 2층이 앞으로 나온 턱 (제티)
const CX = Math.round((X0 + X1) / 2);

// 벽 재료를 고를 수 있게 해 뒀다. 사진은 벽돌이고 옛 우리 집은 회벽이라,
// 어느 쪽이 마을에 맞는지는 나란히 놓고 봐야 안다.
//   brick   벽돌 쌓기 + 크림색 귀돌        (사진 쪽)
//   stucco  회벽 + 하프팀버 목재 띠         (옛 우리 집 쪽)
const WALL = (process.argv.find(a => a.startsWith('--wall=')) || '').slice(7) || 'brick';
const WB = WALL === 'stucco' ? 'w' : 'k';      // 벽 바탕
const WD = WALL === 'stucco' ? 'W' : 'K';      // 벽 그늘
const SHADE = 'D';                             // 구조 그늘 (덮어쓰기 안 됨)
const FRAME = WALL === 'stucco' ? 'T' : 'w';   // 창 테두리 (회벽엔 크림이 안 보인다)


// 지붕 — **곧은 빗변은 상자로 보인다.** 위에서 빨리 벌어지고 아래로 갈수록
// 완만해지게 부풀리면 종 모양이 되어 초가·동화집 느낌이 난다.
// 마지막 몇 줄은 처마가 바깥으로 들리는 것 — 이게 있어야 지붕이 「얹힌」다.
function roof(g, x0, x1, top, base) {
  const h = base - top, half = (x1 - x0) / 2, cx = (x0 + x1) / 2;
  // 지수 0.58로 크게 부풀렸더니 **마녀 모자**가 됐다 — 위가 둥근 데다
  // 뒤로 누운 면까지 얹히니 지붕 하나가 통째로 덩어리로 보였다.
  // 0.94면 거의 곧은 빗변이다. 「너무 각져」서 부풀렸던 건데, 각을 없애는
  // 건 지붕이 아니라 **몸통 귀퉁이**의 일이었다 (soften이 한다).
  // 꼭대기를 **뾰족하게 두면 안 된다.** 점 하나를 뒤로 스물네 칸 밀면
  // 점이 스물네 칸 올라간 선이 되고, 그건 지붕이 아니라 굴뚝처럼 보인다.
  // 꼭대기에 폭 RH의 **용마루**를 두면, 그 띠가 그대로 뒤로 뻗으면서
  // 양옆으로 지붕면이 흘러내린다 — 이게 「길이감」이다.
  const RH = 4;
  for (let i = 0; i <= h; i++) {
    let w = RH + (half - RH) * Math.pow(i / h, 0.94);
    if (i > h - 4) w += (i - (h - 4)) * 1.5;               // 처마 들림
    w = Math.round(w);
    g.rect(Math.round(cx - w), top + i, Math.round(cx + w), top + i, 'r');
    // 박공널 — 빗변 바깥 두 칸을 어둡게. 이 선이 있어야 지붕에 **모서리**가 생겨
    // 뒤로 누운 면과 앞 면이 갈린다
    g.px(Math.round(cx - w), top + i, 'R'); g.px(Math.round(cx - w) + 1, top + i, 'R');
    g.px(Math.round(cx + w), top + i, 'R'); g.px(Math.round(cx + w) - 1, top + i, 'R');
  }
  g.hline(Math.round(cx) - 4, Math.round(cx) + 4, top, 'l');       // 용마루 기와
  g.hline(Math.round(cx) - 4, Math.round(cx) + 4, top + 1, 'r');
  g.hline(x0 - 2, x1 + 2, base - 1, 'r');                  // 처마 끝 서까래
  g.hline(x0 - 2, x1 + 2, base, 'R');
  g.hline(x0 - 1, x1 + 1, base + 1, SHADE);                // 처마 밑 그늘
}


// 벽 — 벽돌이면 크림색 귀돌로 각을 잡고, 회벽이면 하프팀버 목재를 두른다.
function wall(g, x0, x1, y0, y1, plinth) {
  g.rect(x0, y0, x1, y1, WB);
  if (WALL === 'brick') {
    for (let y = y0 + 1; y < y1 - 3; y += 6) {             // 귀돌
      g.rect(x0, y, x0 + 2, y + 2, 'w');
      g.rect(x1 - 2, y, x1, y + 2, 'w');
    }
  } else {
    g.vline(x0 + 1, y0 + 1, y1 - 1, 't');                  // 기둥
    g.vline(x1 - 1, y0 + 1, y1 - 1, 't');
    g.hline(x0, x1, y0, 't');                              // 층 사이 띠
  }
  if (plinth !== false) {
    g.rect(x0, y1 - 2, x1, y1, 'S');                       // 주춧돌
    g.rect(x0, y1 - 2, x1, y1 - 1, 's');
  }
}


// 아치창 — 위가 둥근 창. 네모창보다 훨씬 「건물」로 읽힌다.
// 크림색 석재 테두리가 핵심이다. 벽돌에 유리만 뚫으면 그냥 구멍이 된다.
function archWin(g, x, y, w, h, flowers) {
  const x1 = x + w - 1, y1 = y + h - 1, r = Math.min(3, (w - 2) >> 1);
  for (let i = 0; i < r; i++) g.rect(x + (r - 1 - i), y + i, x1 - (r - 1 - i), y + i, FRAME);
  g.rect(x, y + r, x1, y1, FRAME);
  for (let i = 0; i < r; i++)
    g.rect(x + 1 + (r - 1 - i), y + 1 + i, x1 - 1 - (r - 1 - i), y + 1 + i, 'g');
  g.rect(x + 1, y + r + 1, x1 - 1, y1 - 1, 'g');
  g.hline(x + 1, x1 - 1, y + r + 1, 'G');                  // 위쪽 그늘
  g.px(x + 1, y1 - 2, 'e'); g.px(x + 2, y1 - 2, 'e');      // 아래 반사
  g.vline(x + ((w - 1) >> 1), y + 2, y1 - 1, 'T');         // 창살
  g.hline(x + 1, x1 - 1, y + Math.round(h * 0.62), 'T');
  g.hline(x - 1, x1 + 1, y1, WALL === 'stucco' ? 't' : 'x');   // 창턱이 한 칸 나온다
  g.hline(x - 1, x1 + 1, y1 + 1, WD);
  if (flowers) {                                           // 창 밑 꽃상자
    const by = y1 + 2;
    g.rect(x - 1, by, x1 + 1, by + 2, 't');
    g.hline(x - 1, x1 + 1, by + 2, 'T');
    g.hline(x - 1, x1 + 1, by, 'u');
    for (let i = x; i <= x1; i += 2) {
      g.px(i, by - 1, 'n');
      if ((i - x) % 4 === 0) g.px(i + 1, by - 1, 'f');
    }
  }
}


// 둥근 창 (오큘러스) — 박공 삼각형 한가운데. 온통 직선인 그림에서
// 원 하나가 시선을 잡아 준다.
function roundWin(g, cx, cy, r) {
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) {
    const d = Math.hypot(x, y);
    if (d > r + 0.4) continue;
    g.px(cx + x, cy + y, d > r - 1.7 ? 'w' : 'g');
  }
  g.vline(cx, cy - r + 2, cy + r - 2, 'T');
  g.hline(cx - r + 2, cx + r - 2, cy, 'T');
  g.px(cx - 2, cy + 2, 'e'); g.px(cx - 1, cy + 2, 'e');
}


// 시계 — 마을 한복판 건물에만. 이런 큰 한 점이 있으면 건물에 「이름」이 생긴다.
function clockFace(g, cx, cy, r) {
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) {
    const d = Math.hypot(x, y);
    if (d > r + 0.4) continue;
    g.px(cx + x, cy + y, d > r - 1.2 ? 'T' : (d > r - 2.2 ? 'w' : 'x'));
  }
  for (const [dx, dy] of [[0, -r + 3], [r - 3, 0], [0, r - 3], [-r + 3, 0]])
    g.px(cx + dx, cy + dy, 'T');
  g.vline(cx, cy - r + 4, cy, 'O');                        // 긴바늘
  g.rect(cx, cy, cx + r - 4, cy, 'O');                     // 짧은바늘
}


// 담쟁이 — 사진과 제일 크게 다른 게 이것이었다.
//
// 도트 건물이 딱딱해 보이는 건 선이 전부 자와 직각이기 때문이다. 벽을
// 기어오르는 잎 몇 줌이 그 격자를 깨 준다. 규칙은 하나 — **모서리와
// 처마 밑**을 타고 오른다. 넓은 면 한복판에 붙이면 얼룩으로 보인다.
function ivy(g, x, yBottom, yTop) {
  const h = Math.max(1, yBottom - yTop);
  for (let y = yBottom; y >= yTop; y--) {
    const t = (yBottom - y) / h;
    const px = x + Math.round(Math.sin(y * 0.42) * 1.7 + Math.sin(y * 0.17) * 1.2);
    const dens = 0.66 - t * 0.40;                          // 끝으로 갈수록 성기게
    for (const [dx, dy] of [[0, 0], [-1, 0], [1, 0], [0, -1], [-2, 1], [2, -1], [1, 1], [-1, 1]]) {
      if (dx && hash(px * 3 + dx, y * 5 + dy) > dens) continue;
      if (g.get(px + dx, y + dy) === '.') continue;        // 실루엣 밖으로는 안 뻗는다
      g.px(px + dx, y + dy, hash(px + dx * 7, y + dy * 11) < 0.28 ? 'v'
        : (hash(px + dx, y - dy) < 0.35 ? 'N' : 'n'));
    }
  }
}


function archDoor(g, cx, w, h, GROUND) {
  // 아치문 — 위 세 줄을 한 칸씩 좁혀 둥글린다
  const x0 = cx - Math.floor(w / 2), y0 = GROUND - h;
  for (let i = 0; i < 3; i++)
    g.rect(x0 + (2 - i), y0 + i, x0 + w - 1 - (2 - i), y0 + i, 'T');
  g.rect(x0, y0 + 3, x0 + w - 1, GROUND, 'T');
  for (let i = 0; i < 3; i++)
    g.rect(x0 + 1 + (2 - i), y0 + 1 + i, x0 + w - 2 - (2 - i), y0 + 1 + i, 't');
  g.rect(x0 + 1, y0 + 4, x0 + w - 2, GROUND, 't');
  g.vline(x0 + 1, y0 + 4, GROUND, 'u');                    // 왼쪽 빛
  g.vline(cx, y0 + 4, GROUND, 'T');                        // 가운데 널
  g.px(x0 + w - 3, y0 + Math.floor(h / 2), 'y');           // 손잡이
  // 문 위 **현관 지붕**. 작은 차양 두 줄로는 문이 벽에 뚫린 구멍으로 보인다.
  // 처마가 밖으로 나오고 밑에 그늘이 깔려야 「들어가는 곳」이 된다
  for (let i = 0; i < 3; i++)
    g.rect(x0 - 2 - i, y0 - 4 + i, x0 + w + 1 + i, y0 - 4 + i, i === 0 ? 'l' : 'r');
  g.hline(x0 - 4, x0 + w + 3, y0 - 1, 'R');
  g.hline(x0 - 3, x0 + w + 2, y0, 'D');                    // 현관 지붕 밑 그늘
  // 문지방 돌
  g.rect(x0 - 2, GROUND - 1, x0 + w + 1, GROUND, 'S');
  g.hline(x0 - 2, x0 + w + 1, GROUND - 1, 's');
}


function lantern(g, x, y) {
  g.vline(x, y - 3, y - 2, 'T');                           // 걸이
  g.hline(x, x + 2, y - 3, 'T');
  g.rect(x + 1, y - 1, x + 3, y + 2, 'T');
  g.rect(x + 2, y, x + 2, y + 1, 'y');
  g.px(x + 2, y + 2, 'Y');
}


function planter(g, x, y) {
  g.rect(x, y - 1, x + 4, y + 2, 't');
  g.hline(x, x + 4, y + 2, 'T');
  g.hline(x, x + 4, y - 1, 'u');
  for (let i = 0; i <= 4; i += 2) g.px(x + i, y - 2, 'n');
  g.px(x + 2, y - 3, 'N');
}


function barrel(g, x, y) {
  g.rect(x, y - 5, x + 5, y, 't');
  g.hline(x, x + 5, y - 5, 'u');
  g.hline(x, x + 5, y - 3, 'T');
  g.hline(x, x + 5, y, 'T');
}


function sign(g, cx) {
  const w = 24, x0 = cx - w / 2, y = EAVE + 5;
  g.vline(x0 + 3, y - 4, y, 'T');
  g.vline(x0 + w - 3, y - 4, y, 'T');
  g.rect(x0, y, x0 + w, y + 7, 'B');
  g.rect(x0 + 1, y + 1, x0 + w - 1, y + 6, 'b');
  for (let i = 0; i < 3; i++) g.rect(x0 + 5 + i * 6, y + 3, x0 + 7 + i * 6, y + 5, 'B');
}


// 굴뚝 — **벽돌로, 작게.** 돌로 크게 세웠더니 공장 연통이 돼서
// 집보다 굴뚝이 먼저 보였다. 지붕에서 조금만 고개를 내밀면 된다.
function chimney(g, x, top, base) {
  g.rect(x, top, x + 4, base, 'k');
  g.vline(x, top + 3, base, 'K');                          // 왼쪽 그늘
  g.rect(x - 1, top, x + 5, top + 2, 's');                 // 갓돌
  g.hline(x - 1, x + 5, top + 2, 'S');
  g.rect(x + 1, top + 3, x + 2, top + 4, 'O');             // 연기 구멍
}


// 그리는 **차례가 곧 깊이다.** 뒤에 있는 것부터 깔고 앞엣것으로 덮는다:
//   1층 벽 -> 2층 벽(제티) -> 창·문 -> 지붕 -> 뒤로 눕히기 -> 살림·담쟁이
function build(spec) {
  const g = new G();

  // ---- 몸통 ----
  wall(g, X0, X1, MID, GROUND);                            // 1층
  wall(g, X0 - JUT, X1 + JUT, EAVE, MID - 1, false);       // 2층 (앞으로 JUT만큼)
  // 2층 턱 밑 그늘 — 여기가 「튀어나왔다」를 만든다. 이 두 줄이 없으면
  // 두 층이 한 장의 벽으로 붙어 버린다
  g.hline(X0 - JUT, X1 + JUT, MID, SHADE);
  g.hline(X0 - JUT, X1 + JUT, MID + 1, SHADE);
  g.hline(X0 - JUT, X1 + JUT, MID - 1, 't');               // 층 사이 목재 띠
  g.hline(X0 - JUT, X1 + JUT, MID - 2, 'u');               // 띠 윗면이 빛을 받는다
  g.hline(X0 - JUT, X1 + JUT, EAVE + 1, SHADE);            // 처마 밑 그늘
  // 제티 옆구리 — 2층이 1층보다 JUT만큼 넓으니 그 밑에 받침이 있어야 한다
  for (const x of [X0 - JUT + 1, X1 + JUT - 1]) {
    g.vline(x, MID + 2, MID + 5, 't');
    g.px(x + (x < CX ? 1 : -1), MID + 2, 'T');
  }

  // ---- 창·문 ----
  archWin(g, CX - 26, MID + 4, 13, 12, true);              // 1층 (꽃상자)
  archWin(g, CX + 14, MID + 4, 13, 12, true);
  archWin(g, CX - 24, EAVE + 6, 12, 13, false);            // 2층
  archWin(g, CX + 13, EAVE + 6, 12, 13, false);
  archDoor(g, CX, 15, 25, GROUND);          // 문은 벽폭의 1/4쯤. 넓으면 창고 문이 된다

  // ---- 지붕 ----
  // 박공 벽은 안 그린다 — 이 집은 지붕이 **앞을 보고** 있어서 삼각 벽면이
  // 나올 자리가 없다. 그렸더니 지붕 위에 크림색 삼각형이 덧칠됐다.
  roof(g, X0 - JUT - 3, X1 + JUT + 3, RIDGE, EAVE);
  roundWin(g, CX, RIDGE + 17, 6);                          // 다락창

  extrude(g);                                              // 뒤로 눕는 지붕
  // 굴뚝은 **뒤를 붙인 뒤에.** 앞 지붕면에 세우면 벽기둥처럼 보인다 —
  // 뒤로 누운 면에서 솟아야 굴뚝으로 읽힌다
  if (spec.chimney !== false)
    chimney(g, spec.chimneyX || X1 - 16, RIDGE - 10, RIDGE + 8);

  // ---- 살림 (뒷면 뒤에 — 앞에 놓인 것들이라 묻히면 안 된다) ----
  lantern(g, CX - 13, MID + 8);
  lantern(g, CX + 9, MID + 8);
  // 살림은 **벽에 기대 놓는다.** 멀찍이 떨어뜨렸더니 잔디 위에 굴러다니는
  // 점이 되어 집과 아무 상관 없어 보였다
  planter(g, X0 - JUT - 4, GROUND - 1);
  barrel(g, X1 + JUT - 1, GROUND);
  if (spec.sign) sign(g, CX);
  // 담쟁이는 **맨 마지막**에. 창틀·간판 위로 조금 넘어가야 자란 것처럼 보인다
  ivy(g, X0 - JUT + 2, GROUND - 3, EAVE + 3);
  ivy(g, X1 + JUT - 2, GROUND - 3, EAVE + 3);

  roughen(g);
  soften(g);            // 남은 90도 귀퉁이를 전부 깎는다
  g.outline();
  return g;
}


const KINDS = {
  house: { sign: false },                    // 우리집
  house_general: { sign: true },             // 잡화점
  house_ranch: { sign: true },               // 목장 상회
  house_smith: { sign: true, chimneyX: 22 }, // 대장간 (굴뚝이 반대편)
  house_fish: { sign: true },                // 수산시장
  house_inn: { sign: true },                 // 여관
  house_library: { sign: true },             // 도서관
  house_lab: { sign: true },                 // 연구소
  house_post: { sign: true },                // 우체국
};

let n = 0;
for (const [name, spec] of Object.entries(KINDS)) {
  const tag = STYLE === 'soft' ? '' : STYLE + '_';
  fs.writeFileSync(OUT + PRE + tag + name + '.png', PNG.sync.write(build(spec).render()));
  n++;
}
console.log(`건물 ${n}채 — ${FW}x${FH} (논리 ${GW}x${GH} · 화면에서 도트 2px)`);
console.log(INSTALL ? '  sprites/ 에 넣었다'
  : '  ref/proposed_*.png 로만 뽑았다 (--install 을 붙이면 게임에 넣는다)');

// 확인용: 옛 집 · 새 집 · 캐릭터를 **게임에 그려지는 크기(0.5배)** 로 나란히
const half = (im, o, ox, oy, W, H) => {
  for (let y = 0; y < im.height; y += 2) for (let x = 0; x < im.width; x += 2) {
    const si = (y * im.width + x) * 4;
    if (im.data[si + 3] < 128) continue;
    const X = ox + x / 2, Y = oy + y / 2;
    if (X < 0 || Y < 0 || X >= W || Y >= H) continue;
    const di = (Y * W + X) * 4;
    o.data[di] = im.data[si]; o.data[di + 1] = im.data[si + 1]; o.data[di + 2] = im.data[si + 2];
  }
};
const oldH = PNG.sync.read(fs.readFileSync(SPR + 'house.png'));
const newH = PNG.sync.read(fs.readFileSync(OUT + PRE + (STYLE === 'soft' ? '' : STYLE + '_') + 'house.png'));
const boy = PNG.sync.read(fs.readFileSync(SPR + 'new_boy_down_idle.png'));
const W = 600, H = 230, cmp = new PNG({ width: W, height: H });
for (let i = 0; i < W * H; i++) {
  cmp.data[i * 4] = 96; cmp.data[i * 4 + 1] = 132; cmp.data[i * 4 + 2] = 78; cmp.data[i * 4 + 3] = 255;
}
half(oldH, cmp, 4, 12, W, H);
half(boy, cmp, 258, 122, W, H);
half(newH, cmp, 292, 12, W, H);
half(boy, cmp, 552, 122, W, H);
fs.writeFileSync(REF + 'preview_buildings.png', PNG.sync.write(cmp));
console.log('preview_buildings.png — 왼쪽 옛 집 / 오른쪽 새 집 (게임 크기)');
