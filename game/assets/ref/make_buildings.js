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
const OUT = INSTALL ? SPR : REF;
const PRE = INSTALL ? '' : 'proposed_';

const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)
const GW = 128, GH = 102;
const FW = GW * S, FH = GH * S;

// 옛 집에서 뽑은 색. 각 재료는 [기본, 그늘, 밝은 면] 세 톤.
const PAL = {
  '.': null,
  'O': [42, 36, 36],        // 윤곽선 (옛 집의 제일 어두운 선)
  // 기와
  'r': [214, 88, 32], 'R': [156, 58, 26], 'l': [252, 130, 60],
  // 회벽
  'w': [194, 180, 169], 'W': [150, 138, 130], 'x': [222, 212, 200],
  // 목재
  't': [148, 90, 42], 'T': [98, 60, 36], 'u': [176, 112, 56],
  // 돌
  's': [138, 132, 126], 'S': [96, 92, 88],
  // 유리
  'g': [96, 140, 176], 'G': [58, 92, 128], 'e': [150, 194, 220],
  // 잎·꽃
  'n': [86, 128, 70], 'N': [56, 92, 48], 'f': [232, 226, 210],
  // 간판
  'b': [206, 176, 122], 'B': [150, 122, 78],
  // 등불
  'y': [252, 214, 120], 'Y': [200, 150, 60],
  // 옆면 (3/4로 돌아간 면). 그늘색보다 **한 단계 더** 어둡다 —
  // 같은 색이면 결에 묻혀 정면과 안 갈린다
  'm': [152, 140, 132], 'M': [148, 56, 28],
};

// 결을 낼 때 쓰는 대응표 (기본 <-> 그늘 / 밝은 면)
const DARKEN = { r: 'R', w: 'W', t: 'T', s: 'S', n: 'N', l: 'r', x: 'w', u: 't' };
// m/M(옆면)은 일부러 뺐다 — 결이 앉으면 정면과 경계가 흐려진다
const LIGHTEN = { r: 'l', w: 'x', t: 'u', R: 'r', W: 'w', T: 't', S: 's' };

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

function roughen(g, amount = 0.13) {
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    const c = g.d[y][x];
    if (c === '.' || c === 'O') continue;
    if ((x + y) % 2) continue;
    const r = hash(x, y);
    if (r < amount && DARKEN[c]) g.px(x, y, DARKEN[c]);
    else if (r < amount + 0.09 && LIGHTEN[c]) g.px(x, y, LIGHTEN[c]);
  }
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


// 옆면을 붙여 상자로 만든다 (3/4 시점).
//
// 정면만 그리면 종이를 오려 세운 것처럼 평평하다. 실루엣을 **오른쪽 뒤로**
// 한 칸씩 밀며 어두운 색으로 깔면 옆벽·지붕면이 저절로 생긴다.
//
// 두 가지를 지킨다:
//   ① 밀면서 **위로도** 올린다. 위에서 내려다보는 시점이라 뒤쪽이 화면에서 높다
//   ② 옆면은 **한 색씩만** (벽은 벽그늘, 지붕은 지붕그늘). 정면 그림을 그대로
//      밀면 창문·문이 옆으로 죽 늘어나 얼룩이 된다
const DEPTH = 11;                // 뒤로 밀리는 칸 수 (「조금만 입체적으로」)
const RISE = 0.5;                // 한 칸 밀 때 올라가는 높이

function extrude(g, eaveY) {
  const side = new G();
  for (let i = DEPTH; i >= 1; i--) {
    const up = Math.round(i * RISE);
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
      if (g.d[y][x] === '.') continue;
      // 지붕이냐 벽이냐만 보고 한 색으로 (창·문이 늘어나지 않게)
      side.px(x + i, y - up, y < eaveY ? 'M' : 'm');
    }
  }
  // 옆면을 먼저 깔고 그 위에 정면을 얹는다
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++)
    if (g.d[y][x] === '.' && side.d[y][x] !== '.') g.px(x, y, side.d[y][x]);
  // 옆면 맨 뒤 모서리에 빛 한 줄 — 여기가 있어야 「모서리」로 읽힌다
  for (let y = 0; y < GH; y++) for (let x = GW - 1; x >= 1; x--)
    if (g.d[y][x] !== '.' && g.d[y][x - 1] === '.') { g.px(x, y, 'S'); break; }
}


// ---- 뼈대 ----
const X0 = 10, X1 = 100;         // 1층 벽 좌우 (오른쪽에 옆면 자리를 비워 둔다)
const JUT = 3;                   // 2층이 앞으로 나온 턱 (제티)
const GROUND = 96;               // 바닥선
const MID = 74;                  // 1층·2층 경계 (2층을 낮춰 지붕에 자리를 준다)
const EAVE = 52;                 // 처마. 낮게 내릴수록 지붕이 커진다 —
                                 // 옛 집이 아늑해 보이는 건 지붕이 몸통보다 크기 때문이다
const RIDGE = 12;                // 용마루. 옆면이 위로 DEPTH*RISE만큼 올라가므로
                                 // 너무 높이 두면 지붕 뒤가 캔버스 밖으로 잘린다
const CX = Math.round((X0 + X1) / 2);


function roof(g, x0, x1, top, base) {
  // **곧은 빗변은 상자로 보인다.** 위에서 빨리 벌어지고 아래로 갈수록
  // 완만해지게(지수 0.72) 부풀리면 종 모양이 되어 초가·동화집 느낌이 난다.
  // 마지막 세 줄은 처마가 바깥으로 들리는 것 — 이게 있어야 지붕이 「얹힌」다.
  const h = base - top, half = (x1 - x0) / 2, cx = (x0 + x1) / 2;
  for (let i = 0; i <= h; i++) {
    const t = i / h;
    let w = half * Math.pow(t, 0.58);   // 지수가 낮을수록 종 모양이 세진다
    if (i > h - 4) w += (i - (h - 4)) * 1.6;          // 처마 들림 (초가처럼 바깥으로)
    w = Math.round(w);
    g.rect(Math.round(cx - w), top + i, Math.round(cx + w), top + i, 'r');
  }
  // 기와 골 — 세 줄마다 한 줄. 굵은 격자에서는 이 정도가 「기와」로 읽힌다
  for (let y = top + 3; y <= base; y += 3)
    for (let x = 0; x < GW; x++) if (g.d[y][x] === 'r') g.px(x, y, 'R');
  // 용마루 기와 (한 칸 굵게 밝은 색)
  g.hline(Math.round(cx) - 3, Math.round(cx) + 3, top, 'l');
  // 처마 끝 — 두껍게 튀어나온 서까래
  g.hline(x0 - 2, x1 + 2, base, 'R');
  g.hline(x0 - 2, x1 + 2, base - 1, 'r');
}


function gable(g, cx, top, base) {
  // 박공 — 2층 삼각 벽면. 하프팀버(X자 브레이스)를 넣는다
  const h = base - top, half = 26;
  for (let i = 0; i <= h; i++) {
    const w = Math.round(half * (i / h));
    g.rect(cx - w, top + i, cx + w, top + i, 'w');
  }
  for (let i = 0; i <= h; i++) {          // 양 빗변에 목재
    const w = Math.round(half * (i / h));
    g.px(cx - w, top + i, 't'); g.px(cx + w, top + i, 't');
  }
  g.hline(cx - half, cx + half, base, 't');
  for (let i = 0; i < h - 3; i++) {       // X자
    g.px(cx - Math.round(half * ((i + 3) / h)) + 2 + i, top + 3 + i, 'T');
    g.px(cx + Math.round(half * ((i + 3) / h)) - 2 - i, top + 3 + i, 'T');
  }
}


function windowBox(g, x, y, w, h, flowers) {
  g.rect(x, y, x + w - 1, y + h - 1, 'T');                 // 창틀
  g.rect(x + 1, y + 1, x + w - 2, y + h - 2, 'g');
  g.hline(x + 1, x + w - 2, y + 1, 'G');                   // 위쪽 그늘
  g.px(x + 1, y + h - 2, 'e'); g.px(x + 2, y + h - 2, 'e');// 아래 반사
  g.vline(x + Math.floor(w / 2), y + 1, y + h - 2, 'T');   // 창살
  g.hline(x + 1, x + w - 2, y + Math.floor(h / 2), 'T');
  roundCorners(g, x, y, x + w - 1, y + h - 1, 1);          // 창틀 귀퉁이
  if (flowers) {                                            // 창 밑 꽃상자
    const by = y + h;
    g.rect(x - 1, by, x + w, by + 2, 't');
    g.hline(x - 1, x + w, by + 2, 'T');
    for (let i = x; i <= x + w - 1; i += 2) {
      g.px(i, by - 1, 'n');
      if ((i - x) % 4 === 0) g.px(i + 1, by - 1, 'f');
    }
  }
}


function archDoor(g, cx, w, h) {
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
  const w = 24, x0 = cx - w / 2, y = EAVE + 4;
  g.vline(x0 + 3, y - 3, y, 'T');
  g.vline(x0 + w - 3, y - 3, y, 'T');
  g.rect(x0, y, x0 + w, y + 6, 'B');
  g.rect(x0 + 1, y + 1, x0 + w - 1, y + 5, 'b');
  for (let i = 0; i < 3; i++) g.rect(x0 + 5 + i * 6, y + 2, x0 + 7 + i * 6, y + 4, 'B');
}


function chimney(g, x, top) {
  g.rect(x, top, x + 6, EAVE + 6, 'S');
  g.rect(x + 1, top + 1, x + 5, EAVE + 6, 's');
  g.rect(x - 1, top, x + 7, top + 2, 'S');                 // 갓
  g.rect(x, top + 1, x + 6, top + 1, 's');
  for (let y = top + 4; y < EAVE + 6; y += 3) g.hline(x + 1, x + 5, y, 'S');  // 돌결
}


function build(spec) {
  const g = new G();
  // ---- 1층 벽 ----
  g.rect(X0, MID, X1, GROUND, 'w');
  // ---- 2층 벽 (앞으로 JUT만큼 나온다) ----
  g.rect(X0 - JUT, EAVE, X1 + JUT, MID - 1, 'w');
  // 2층 턱 밑 그늘 — 여기가 「튀어나왔다」를 만든다
  g.hline(X0 - JUT, X1 + JUT, MID, 'W');
  g.hline(X0 - JUT, X1 + JUT, MID + 1, 'W');
  // 처마 밑 그늘
  g.hline(X0 - JUT, X1 + JUT, EAVE + 1, 'W');
  // ---- 하프팀버 ----
  g.hline(X0 - JUT, X1 + JUT, MID - 1, 't');               // 층 사이 띠
  g.hline(X0, X1, GROUND - 1, 't');                        // 밑단 띠
  for (const x of [X0 + 2, CX - 26, CX + 26, X1 - 2]) g.vline(x, MID + 1, GROUND, 't');
  for (const x of [X0 - JUT + 2, X1 + JUT - 2]) g.vline(x, EAVE + 2, MID - 2, 't');
  // ---- 주춧돌 ----
  g.rect(X0 - 1, GROUND - 2, X1 + 1, GROUND, 'S');
  g.rect(X0, GROUND - 2, X1, GROUND - 1, 's');
  // ---- 창·문 ----
  windowBox(g, CX - 40, MID + 5, 13, 13, true);
  windowBox(g, CX + 28, MID + 5, 13, 13, true);
  windowBox(g, CX - 32, EAVE + 6, 11, 12, false);
  windowBox(g, CX + 22, EAVE + 6, 11, 12, false);
  archDoor(g, CX, 17, 24);
  // ---- 지붕 ----
  roof(g, X0 - JUT - 3, X1 + JUT + 3, RIDGE, EAVE);
  // 박공 벽은 안 그린다 — 이 집은 지붕이 **앞을 보고** 있어서 삼각 벽면이
  // 나올 자리가 없다. 그렸더니 지붕 위에 크림색 삼각형이 덧칠됐다.
  windowBox(g, CX - 5, RIDGE + 12, 11, 11, false);          // 다락창
  if (spec.chimney !== false) chimney(g, spec.chimneyX || X1 - 24, RIDGE + 4);
  // ---- 살림 ----
  lantern(g, CX - 14, MID + 8);
  lantern(g, CX + 10, MID + 8);
  // 귀퉁이는 **옆면을 붙이기 전에** 깎는다 — 깎은 실루엣이 그대로 밀려야
  // 옆면 모서리도 같이 둥글어진다.
  roundCorners(g, X0 - JUT, EAVE, X1 + JUT, MID - 1, 4);
  roundCorners(g, X0, MID, X1, GROUND - 3, 3);
  extrude(g, EAVE);
  // 살림은 옆면 뒤에 — 앞에 놓인 것들이라 옆면에 묻히면 안 된다
  planter(g, X0 + 2, GROUND - 1);
  planter(g, X1 - 6, GROUND - 1);
  barrel(g, X1 - 16, GROUND);
  if (spec.sign) sign(g, CX);
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
  fs.writeFileSync(OUT + PRE + name + '.png', PNG.sync.write(build(spec).render()));
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
const newH = PNG.sync.read(fs.readFileSync(OUT + PRE + 'house.png'));
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
