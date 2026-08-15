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
// **128x102 논리 격자**에 굵은 형태로 그리고 4배로 펴서 512x408로 낸다
// (게임이 쓰는 크기 그대로라 코드는 안 건드린다).
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
const GW = 128, GH = 102;
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
  'M': [166, 52, 24], 'M2': [130, 38, 18], 'M3': [96, 28, 14],
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
  ditherFace(g, ['l', 'r', 'R'], 0, GROUND);            // 기와
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
const DEPTH = 10;                // 뒤로 물러나는 칸 수 (「조금만 입체적으로」)

// 뒤로 물러나는 면은 **멀어질수록 어두워진다.** 한 색으로 채우면 두께가
// 아니라 슬래브가 된다 — 세 단계로 갈라야 「공간」으로 읽힌다.
const BACK_ROOF = ['M', 'M2', 'M3'];      // 가까운 쪽 -> 먼 쪽
const BACK_WALL = ['m', 'm2', 'm3'];

// 뒤 색은 **처마 높이가 아니라 재료로** 고른다.
//
// 처음엔 「처마선보다 위면 지붕색」으로 잘랐는데, 덩어리가 셋이 되면서
// 처마가 세 높이로 갈라지자 날개 지붕이 벽색으로 밀려 올라갔다. 굴뚝도
// 돌인데 뒤가 주황이 됐다. 밀려 올라가는 칸 **자기 색**을 보고 정하면
// 덩어리가 몇이든 저절로 맞는다.
const BACK_STONE = ['S', 'S', 'S'];
const BACK_OF = {
  l: BACK_ROOF, r: BACK_ROOF, R: BACK_ROOF,
  s: BACK_STONE, S: BACK_STONE,
};
function extrude(g) {
  const back = new G();
  // 가까운 쪽부터 채운다 — 먼저 칠한 쪽(가까운 쪽)이 이긴다
  for (let i = 1; i <= DEPTH; i++) {
    const k = Math.min(2, Math.floor((i - 1) * 3 / DEPTH));
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
      if (g.d[y][x] === '.') continue;
      const ny = y - i;
      if (ny < 0 || back.d[ny][x] !== '.') continue;
      back.px(x, ny, (BACK_OF[g.d[y][x]] || BACK_WALL)[k]);
    }
  }
  // 지붕 뒷면에도 기와 이음매 — 뒤로 갈수록 줄 간격이 좁아진다(원근)
  for (let x = 0; x < GW; x++) {
    let seen = 0;
    for (let y = GH - 1; y >= 0; y--) {
      if (!BACK_ROOF.includes(back.d[y][x])) continue;
      seen++;
      if (seen % 3 === 0 || seen > DEPTH * 0.6 && seen % 2 === 0)
        back.px(x, y, BACK_ROOF[Math.min(2, BACK_ROOF.indexOf(back.d[y][x]) + 1)]);
    }
  }
  // 뒤를 깔고 그 위에 정면을 얹는다
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++)
    if (g.d[y][x] === '.' && back.d[y][x] !== '.') g.px(x, y, back.d[y][x]);
  // 맨 뒤 능선에 밝은 줄 — 하늘을 받는 모서리다. 지붕 뒷면에만 —
  // 굴뚝 꼭대기까지 주황으로 칠하면 그것만 튄다
  for (let x = 0; x < GW; x++) for (let y = 0; y < GH - 1; y++)
    if (g.d[y][x] !== '.') { if (BACK_ROOF.includes(g.d[y][x])) g.px(x, y, 'l'); break; }
}


// ---- 뼈대 ----
//
// 한 덩어리 상자를 아무리 잘 칠해도 창고로 보인다. 건물이 「건물」로
// 읽히는 건 **덩어리가 여럿**일 때다 —
//
//   가운데 몸채   제일 높고 **앞으로 나온다**. 시선이 여기 먼저 꽂힌다
//   양 날개       한 단 낮은 박공이 정면을 마주 본다 (좌우 대칭)
//   오목부        그 사이에 한 단 더 물러난 자리. 여기서 **지붕면**이 보인다
//
// 정면 박공이 셋이면 실루엣에 산이 셋 생겨서, 멀리서 봐도 형태가 잡힌다.
const GROUND = 95;               // 날개·오목부 바닥
const GROUND_C = 97;             // 가운데 몸채 — 앞으로 나온 만큼 바닥이 내려온다

const C0 = 49, C1 = 78;          // 가운데 몸채 좌우
const C_RIDGE = 10, C_EAVE = 50;

const L0 = 4, L1 = 40;           // 왼 날개
const R0 = 89, R1 = 123;         // 오른 날개 (몸채와의 틈을 왼쪽과 똑같이 아홉 칸)
const W_RIDGE = 24, W_EAVE = 56;

const CONN_EAVE = 64;            // 오목부 처마 — 제일 낮다
const CX = Math.round((C0 + C1) / 2);


// 정면 박공 — 삼각 벽면에 빗변을 따라 기와 박공널을 두른다.
//
// 앞을 보고 선 지붕은 **면이 아니라 테두리**로 그린다. 지붕면 자체는
// extrude가 이 빗변을 위로 밀어 뒤에 만들어 준다 — 그게 뒤로 흐르는 지붕이다.
// 빗변을 살짝(지수 0.86) 부풀리면 곧은 삼각형보다 지붕이 얹힌 것처럼 보인다.
function gable(g, x0, x1, top, base) {
  const h = base - top, half = (x1 - x0) / 2, cx = (x0 + x1) / 2;
  const edgeAt = i => half * Math.pow(i / h, 0.86);
  for (let i = 0; i <= h; i++) {                           // 삼각 벽면
    const w = Math.round(edgeAt(i));
    g.rect(Math.round(cx) - w, top + i, Math.round(cx) + w, top + i, 'k');
  }
  for (let i = 0; i <= h; i++) {                           // 빗변 박공널
    const w = Math.round(edgeAt(i));
    for (let t = 0; t < 3; t++) {                          // 바깥 한 줄은 그늘
      g.px(Math.round(cx) - w + t, top + i, t === 0 ? 'R' : 'r');
      g.px(Math.round(cx) + w - t, top + i, t === 0 ? 'R' : 'r');
    }
  }
  g.hline(Math.round(cx) - 2, Math.round(cx) + 2, top, 'l');   // 용마루
  // 처마 — 벽보다 두 칸 밖으로 나오고 밑에 그늘이 깔린다.
  // 이 그늘 한 줄이 없으면 지붕이 벽에 **인쇄된 것처럼** 보인다
  g.hline(x0 - 2, x1 + 2, base - 1, 'r');
  g.hline(x0 - 2, x1 + 2, base, 'R');
  g.hline(x0 - 1, x1 + 1, base + 1, 'K');
}


// 벽 — 벽돌 + 크림색 귀돌(모서리 돌). 귀돌이 각을 잡아 줘서
// 벽돌만 있을 때보다 덩어리 경계가 또렷해진다.
function wall(g, x0, x1, y0, y1) {
  g.rect(x0, y0, x1, y1, 'k');
  for (let y = y0 + 1; y < y1 - 3; y += 6) {
    g.rect(x0, y, x0 + 2, y + 2, 'w');
    g.rect(x1 - 2, y, x1, y + 2, 'w');
  }
  g.rect(x0, y1 - 2, x1, y1, 'S');                         // 주춧돌
  g.rect(x0, y1 - 2, x1, y1 - 1, 's');
}


// 아치창 — 위가 둥근 창. 네모창보다 훨씬 「건물」로 읽힌다.
// 크림색 석재 테두리가 핵심이다. 벽돌에 유리만 뚫으면 그냥 구멍이 된다.
function archWin(g, x, y, w, h) {
  const x1 = x + w - 1, y1 = y + h - 1, r = Math.min(3, (w - 2) >> 1);
  for (let i = 0; i < r; i++) g.rect(x + (r - 1 - i), y + i, x1 - (r - 1 - i), y + i, 'w');
  g.rect(x, y + r, x1, y1, 'w');
  for (let i = 0; i < r; i++)
    g.rect(x + 1 + (r - 1 - i), y + 1 + i, x1 - 1 - (r - 1 - i), y + 1 + i, 'g');
  g.rect(x + 1, y + r + 1, x1 - 1, y1 - 1, 'g');
  g.hline(x + 1, x1 - 1, y + r + 1, 'G');                  // 위쪽 그늘
  g.px(x + 1, y1 - 2, 'e'); g.px(x + 2, y1 - 2, 'e');      // 아래 반사
  g.vline(x + ((w - 1) >> 1), y + 2, y1 - 1, 'T');         // 창살
  g.hline(x + 1, x1 - 1, y + Math.round(h * 0.62), 'T');
  g.hline(x - 1, x1 + 1, y1, 'x');                         // 창턱이 한 칸 나온다
  g.hline(x - 1, x1 + 1, y1 + 1, 'W');
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
  // 문 위 작은 차양
  g.rect(x0 - 3, y0 - 3, x0 + w + 2, y0 - 2, 'r');
  g.hline(x0 - 3, x0 + w + 2, y0 - 3, 'l');
  g.hline(x0 - 3, x0 + w + 2, y0 - 1, 'R');                // 차양 밑 그늘
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
  const w = 24, x0 = cx - w / 2, y = C_EAVE + 5;
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
//   오목부 -> 양 날개 -> 가운데 몸채
// 겹치는 칸은 나중에 그린 쪽이 이기고, 그게 그대로 앞뒤가 된다.
function build(spec) {
  const g = new G();

  // ---- 오목부 (제일 뒤) ----
  // 처마가 제일 낮아서 여기서만 **지붕면**이 넓게 보인다 (extrude가 만든다)
  const RECESS = [[L1 - 2, C0 + 2], [C1 - 2, R0 + 2]];
  for (const [a, b] of RECESS) {
    g.rect(a, CONN_EAVE, b, GROUND, 'k');
    g.rect(a, GROUND - 2, b, GROUND, 'S');
    g.rect(a, GROUND - 2, b, GROUND - 1, 's');
    g.hline(a, b, CONN_EAVE, 'r');                         // 처마 기와
    g.hline(a, b, CONN_EAVE + 1, 'R');
    g.hline(a, b, CONN_EAVE + 2, 'K');                     // 처마 밑 그늘
  }
  // 오목부에 큰 창은 안 넣는다 — 보이는 폭이 아홉 칸뿐이라 창을 끼우면
  // 벽이 사라진다. 위쪽에 작은 창 하나만 두고 나머지는 담쟁이에 내준다
  for (const x of [L1 + 2, C1 + 4]) {
    g.rect(x, CONN_EAVE + 6, x + 5, CONN_EAVE + 12, 'w');
    g.rect(x + 1, CONN_EAVE + 7, x + 4, CONN_EAVE + 11, 'g');
    g.vline(x + 2, CONN_EAVE + 7, CONN_EAVE + 11, 'T');
    g.px(x + 1, CONN_EAVE + 10, 'e');
  }

  // ---- 양 날개 ----
  for (const [x0, x1] of [[L0, L1], [R0, R1]]) {
    const mx = Math.round((x0 + x1) / 2);
    wall(g, x0, x1, W_EAVE, GROUND);
    gable(g, x0, x1, W_RIDGE, W_EAVE);
    roundWin(g, mx, W_RIDGE + 14, 6);
    archWin(g, mx - 14, W_EAVE + 8, 11, 20);
    archWin(g, mx + 4, W_EAVE + 8, 11, 20);
  }

  // ---- 가운데 몸채 (제일 앞) ----
  wall(g, C0, C1, C_EAVE, GROUND_C);
  gable(g, C0, C1, C_RIDGE, C_EAVE);
  if (spec.clock) clockFace(g, CX, C_RIDGE + 21, 8);
  else roundWin(g, CX, C_RIDGE + 21, 6);
  archDoor(g, CX, 19, 26, GROUND_C);
  // 몸채가 앞으로 나온 표 — 옆구리가 오목부 벽에 드리우는 그늘.
  // 이 두 줄이 없으면 세 덩어리가 한 평면에 나란히 선 것처럼 보인다
  for (const x of [C0 - 1, C0 - 2, C1 + 1, C1 + 2])
    g.vline(x, C_EAVE + 2, GROUND, 'K');

  extrude(g);                                              // 뒤로 물러나는 면
  // 굴뚝은 **뒤를 붙인 뒤에** 세운다. 정면 박공 벽면에 붙이면 벽기둥처럼
  // 보인다 — 오목부의 낮은 지붕면에서 솟아야 굴뚝으로 읽힌다
  if (spec.chimney !== false)
    chimney(g, spec.chimneyX || C1 + 5, CONN_EAVE - 21, CONN_EAVE - 1);
  // ---- 살림 (옆면 뒤에 — 앞에 놓인 것들이라 묻히면 안 된다) ----
  lantern(g, C0 + 2, C_EAVE + 22);
  lantern(g, C1 - 5, C_EAVE + 22);
  planter(g, L0 + 4, GROUND - 1);
  planter(g, R1 - 8, GROUND - 1);
  barrel(g, C1 + 6, GROUND);
  if (spec.sign) sign(g, CX);
  // 담쟁이는 **맨 마지막**에. 창틀·간판 위로도 조금 넘어가야 자란 것처럼 보인다
  ivy(g, L0 + 2, GROUND - 3, W_RIDGE + 6);                 // 날개 바깥 모서리
  ivy(g, R1 - 2, GROUND - 3, W_RIDGE + 6);
  ivy(g, L1 + 3, GROUND - 3, CONN_EAVE + 14);              // 오목부 — 작은 창 밑까지만
  ivy(g, C1 + 5, GROUND - 3, CONN_EAVE + 14);

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
