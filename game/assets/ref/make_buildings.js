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
// 캔버스는 **집마다 다르다.** 회관처럼 마을에서 제일 큰 집은 그림판부터
// 커야 진짜로 커진다 — 같은 판 안에서 폭만 늘리면 옆에 붙는 종탑·깃발이
// 잘려 나갈 뿐이다.
//
// 바닥선(GROUND)은 캔버스 밑에서 일곱 칸. world_gen 이 그림 **높이**로
// 밑변을 맞추므로 판이 커져도 집은 늘 같은 땅에 선다.
let GW = 128, GH = 138;
let FW = GW * S, FH = GH * S;
let GROUND = GH - 7;
let CX = Math.round(GW / 2);
function setCanvas(w, h) {
  GW = w; GH = h; FW = w * S; FH = h * S;
  GROUND = h - 7; CX = Math.round(w / 2);
}

// 옛 집에서 뽑은 색. 각 재료는 [기본, 그늘, 밝은 면] 세 톤.
const PAL = {
  '.': null,
  'O': [32, 24, 28],        // 윤곽선. 레트로는 선이 진할수록 또렷하다
  // 기와
  'r': [232, 84, 24], 'R': [148, 44, 20], 'l': [255, 148, 56],
  // 기와 **톤 사다리** — 처마(가까움)에서 용마루(멂)까지 한 줄기 여덟 단.
  // 앞 지붕과 뒤로 누운 면을 따로 칠하면 지붕이 두 장으로 갈려 보인다.
  // 한 사다리에서 뽑아 쓰면 어디서 끊기는지 눈에 안 띈다.
  'q0': [255, 152, 62], 'q1': [244, 116, 40], 'q2': [226, 88, 28],
  'q3': [198, 68, 24], 'q4': [168, 52, 20], 'q5': [140, 40, 17],
  'q6': [112, 32, 14], 'q7': [84, 24, 11],
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
  // 굴뚝 전용 색. 벽돌색(k/K/i)으로 그렸더니 나중에 도는 **줄눈 패스가
  // 굴뚝까지 격자로 갈라서** 사다리가 됐다. 재료는 같은 벽돌이지만
  // 칠하는 규칙이 다르니 색도 따로 둔다.
  'p0': [208, 144, 98], 'p1': [172, 108, 70], 'p2': [116, 68, 44],
  'p3': [216, 210, 198], 'p4': [150, 144, 136], 'p5': [88, 84, 80],
  'p6': [84, 50, 32],       // 멀리 있는 굴뚝의 그늘 쪽 (한 단 더 어둡다)
  // 불 (대장간 화구) — 기와 사다리와 따로 둔다. 기와색은 건물마다 바뀌는데
  // 불은 어느 집에서든 불이어야 한다
  'F': [250, 140, 50], 'F2': [206, 70, 24],
  // 차양 천 — 가게 앞에 치는 줄무늬 천
  'A': [200, 62, 48], 'a': [242, 234, 214],
};

// 결을 낼 때 쓰는 대응표 (기본 <-> 그늘 / 밝은 면)
const DARKEN = { r: 'R', w: 'W', t: 'T', s: 'S', n: 'N', l: 'r', x: 'w', u: 't',
                 k: 'K', i: 'k', v: 'n' };
// m/M(옆면)은 일부러 뺐다 — 결이 앉으면 정면과 경계가 흐려진다
const LIGHTEN = { r: 'l', w: 'x', t: 'u', R: 'r', W: 'w', T: 't', S: 's',
                  k: 'i', K: 'k', n: 'v', N: 'n' };

// 건물마다 **재료만 갈아 끼운다.** 그리는 규칙(기와 한 장씩, 벽돌 줄눈,
// 뒤로 누운 지붕)은 그대로 두고 색만 바꾸면, 아홉 채가 같은 그림체를 유지한
// 채로 서로 달라진다. 형태까지 새로 그리면 아홉 개의 다른 게임 건물이 된다.
const ROOF_PAL = {
  clay:   [[255,152,62],[244,116,40],[226,88,28],[198,68,24],[168,52,20],[140,40,17],[112,32,14],[84,24,11]],
  soot:   [[164,148,140],[138,122,116],[114,100,96],[92,80,78],[72,62,62],[56,48,48],[40,34,34],[26,22,22]],
  slate:  [[152,178,192],[126,154,170],[104,132,150],[84,110,130],[66,90,110],[52,72,90],[38,54,70],[26,38,52]],
  // 대장간의 함석 지붕 — **그늘이 남보라로 기운다.** 순회색(soot)으로
  // 두었더니 지붕이 큰 잿빛 판이라 그림 전체가 우중충했다. 손으로 찍은
  // 그림의 회색은 회색이 아니다 — 빛은 하늘색, 그늘은 남보라다
  ironblue: [[212,226,236],[178,196,214],[144,166,192],[114,136,168],[90,108,146],[70,84,124],[54,64,102],[42,48,80]],
  moss:   [[156,172,112],[130,148,92],[106,124,76],[86,104,62],[68,84,48],[52,66,38],[40,50,30],[28,36,22]],
  copper: [[144,208,194],[116,184,172],[94,160,150],[76,136,128],[60,112,106],[46,90,86],[34,68,66],[24,50,48]],
};
const WALL_PAL = {
  brick: { k: [176,110,70], K: [116,68,44], i: [210,148,100] },
  stone: { k: [154,150,144], K: [98,94,90], i: [192,188,180] },
  // 따뜻한 돌 — 순회색 돌은 흙 마당 위에서 잿더미처럼 보였다. 모래빛으로
  // 아주 조금 데우면 같은 돌인데 볕을 받은 돌이 된다
  stonewarm: { k: [178, 168, 148], K: [120, 110, 96], i: [216, 206, 186] },
  pale:  { k: [198,192,174], K: [134,128,114], i: [230,226,210] },
  warm:  { k: [190,136,90], K: [128,86,58], i: [222,170,122] },
  // 헛간의 빨강 — 페인트를 칠한 널이라 채도가 높다. 크림색 테두리와
  // 짝을 이루는 고전적인 붉은 헛간의 색
  barnred: { k: [178, 64, 50], K: [118, 40, 32], i: [210, 94, 72] },
};

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
  || 0.45;
// 0.20 -> 0.32 -> 0.45. 올릴수록 장마다 색이 벌어져 오래 쓴 티가 난다.
// 0.5를 넘기면 벽돌이 「무늬」로 보이기 시작해서 이쯤이 끝이다.

// 기와를 **한 장씩** 얹는다.
//
// 가로줄만 긋고 자리마다 색을 조금씩 흩는 것으로는 「기와 무늬」까지고
// 「기와」는 안 된다. 참고한 그림은 한 장 한 장이 물건이었다 —
//
//   윗변    한 단 밝다 (위를 보고 있으니 빛을 받는다)
//   아랫변  두 단 어둡다 (앞장이 뒷장 위로 겹쳐 얹히며 생기는 **턱**)
//   세로    켜마다 반 장씩 어긋난 이음매
//
// 이 세 줄이 한 장을 만들고, 어긋난 이음매가 장들을 흩어 준다.
//
// 색은 자리에서 나온다. roofT[y][x] 는 「처마에서 얼마나 멀어졌나」(0~1)이고,
// 그걸 톤 사다리 q0..q7 에 얹으면 앞 지붕과 뒤로 누운 면이 한 줄기로 이어진다.
const ROOF_GLYPH = new Set(['r', 'R', 'l', 'Mn', 'M', 'M2', 'M3']);
const ROOF_Q = new Set(['q0', 'q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7']);
// **손으로 찍은 느낌은 「큰 조각 + 조용한 면」이다.**
//
// 지금 그림이 인위적으로 보이는 이유를 참고 그림(스타듀) 옆에 놓고 재 보니
// 색이 아니라 **잡음의 크기**였다. 우리는 기와 한 장·돌 한 장마다 톤을
// 흔들어 온 면이 고르게 자글거리고, 참고 그림은 조각이 크고 면이 조용한
// 대신 얼룩이 서너 장씩 뭉쳐 다닌다 — 사람 손은 균일한 난수를 못 찍는다.
// chunky 모드: 조각을 키우고(기와 8x4 · 돌 8~10x5), 톤은 **뭉치 단위**로만
// 흔들고, 기와 밑변 귀퉁이를 둥글려 비늘처럼 얹는다. 일단 대장간만 쓴다.
let CHUNKY = false;
let TH = 3;                      // 한 켜의 높이 (앞 지붕)
// **윗면이 제일 밝다.** 오래 「멀수록 어둡다」로 두었더니 뒤로 누운 면이
// 지붕 위에 드리운 커다란 그늘로 보여서, 그림이 위에서 본 게 아니라
// 정면 입면도에 어두운 배경을 깐 꼴이었다. 하늘을 가장 넓게 받는 면은
// 눕는 면이다 — 마당 살림(topFace)에 세운 규칙과 같은 규칙이다.
//
//   용마루 뒤 윗면   BACK_LO..BACK_HI   밝다 (멀수록 아주 조금만 어둡게)
//   앞으로 선 빗면   FRONT_LO..FRONT_HI 어둡다 (처마 쪽이 제일 어둡다)
//
// 두 구간이 겹치지 않게 벌려 두는 게 핵심이다. 붙여 두면 용마루에서
// 톤이 이어져 버려서 접힌 자리가 사라진다.
const BACK_LO = 0.04, BACK_HI = 0.30;
const FRONT_LO = 0.46, FRONT_HI = 0.74;
let FRONT_ROWS = 0;              // 앞 지붕의 켜 수 (뒤 켜 번호가 여기서 이어진다)
let roofT = null;                // 셀마다 0~1 (처마 -> 용마루), -1 이면 지붕 아님
let roofRow = null;              // 셀마다 기와 켜 번호
let TW = 5;                      // 한 장의 폭

function resetRoof() {
  roofT = Array.from({ length: GH }, () => new Float32Array(GW).fill(-1));
  roofRow = Array.from({ length: GH }, () => new Int16Array(GW).fill(-1));
}

function shingles(g) {
  const at = (x, y) => (y < 0 || y >= GH || x < 0 || x >= GW) ? -1 : roofRow[y][x];
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    const t = roofT[y][x];
    if (t < 0) continue;
    if (!ROOF_GLYPH.has(g.d[y][x])) continue;            // 창·굴뚝이 덮은 자리는 건너뛴다
    const row = roofRow[y][x];
    const u = x + ((row % 2) ? (TW >> 1) : 0);
    const col = Math.floor(u / TW);
    // 몸통 톤 — 멀수록 어둡다. **장마다 두 단까지** 흔든다.
    // 한 단만 흔들었더니 지붕이 너무 성해 보였다. 오래 쓴 지붕은 장마다
    // 색이 제법 다르고, 드문드문 이가 빠져 있다.
    const r = hash(col, row), r2 = hash(row * 3 + 1, col * 5 + 2);
    let i = Math.round(t * 5.4);
    if (CHUNKY) {
      // **다 그리지 않는다.** 기와를 한 장도 빠짐없이 격자로 그렸더니
      // 어떤 색을 입혀도 「기계가 채운 무늬」였다. 손으로 찍은 지붕은
      // 면을 평평하게 비워 두고, 드문드문 몇 획으로만 기와를 **암시**한다 —
      // 획은 켜의 자에 맞춰 눕고, 서너 장에 한 획이면 충분하다.
      const ru = ((u % TW) + TW) % TW;
      const isBottom = at(x, y + 1) !== row;
      if (r < 0.34) {
        // 이 장은 획을 얻는다 — 밑변에 짧은 어두운 획 (2~5칸)
        const len = 2 + Math.floor(hash(col * 5 + 2, row * 7 + 3) * 4);
        if (isBottom && ru >= 1 && ru <= len) i += 2;
      } else if (r > 0.88) {
        // 드문 밝은 획 — 윗변에
        if (at(x, y - 1) !== row && ru >= 2 && ru <= 4) i -= 1;
      }
      // 갈아 끼운 기와 — 아주 드문 장은 **통째로** 톤이 다르다. 지붕을
      // 오래 쓰면 깨진 자리에 새 기와를 끼우고, 그 한 장이 도드라진다
      const r3 = hash(col * 11 + 5, row * 3 + 8);
      if (r3 < 0.030) i += 2;
      else if (r3 < 0.065) i += 1;
      else if (r3 > 0.985) i -= 1;
    } else {
      i += (r < 0.10 ? 2 : (r < 0.28 ? 1 : (r > 0.92 ? -2 : (r > 0.74 ? -1 : 0))));
      // 이 빠진 장 — 아랫귀퉁이가 깨져 나가 밑장이 비친다
      if (r2 < 0.055 && at(x, y + 1) !== row) i += 3;
      if (at(x, y - 1) !== row) i -= 1;                  // 윗변 (빛)
      if (at(x, y + 1) !== row) i += 2;                  // 아랫변 (겹침 턱)
      if (u % TW === 0) i += 2;                          // 세로 이음매
    }
    g.px(x, y, 'q' + Math.max(0, Math.min(7, i)));
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
    const r = hash(col, course), r2 = hash(course * 7 + 3, col * 11 + 5);
    let t = c;
    // 구운 벽돌은 한 장도 같은 게 없다. 두 단까지 벌린다
    if (r < ROUGH * 0.45) t = 'K';
    else if (r < ROUGH * 1.5) t = DARKEN[c] || c;
    else if (r > 1.0 - ROUGH * 0.4) t = 'i';
    else if (r > 1.0 - ROUGH * 1.3) t = LIGHTEN[c] || c;
    if (r2 < 0.05) t = 'K';                    // 이 빠진 장
    // 줄눈 — 가로 한 줄 + 세로 이음매. 회반죽이 벽돌보다 어둡게 패인다
    if (y % BH === BH - 1 || u % BW === 0) t = 'K';
    g.px(x, y, t);
  }
}

// 큰 돌 쌓기 — chunky 모드의 벽. 참고 그림의 돌탑은 여섯 칸짜리 벽돌이
// 아니라 **주먹만 한 돌**이 한 층에 서너 개다. 켜 높이 5, 폭 8~10으로
// 잡고, 이음매 자리를 켜마다 흔들어 크기가 들쭉날쭉하게 한다.
// 귀퉁이 네 점을 줄눈색으로 깎으면 돌이 둥글어진다 — 이 둥긂이 손맛이다.
// 톤은 뭉치 단위: 대부분 기본색으로 조용히 두고 드문드문 밝은/어두운 돌
// 막돌 벽 — chunky. **화로(make_props.rubble)와 같은 보로노이.**
//
// 벽만 회벽에 드문 돌로 두었더니, 곁의 막돌 화로와 딴 재료가 됐다.
// 같은 마당의 돌은 같은 채석장에서 나온다 — 씨앗점을 흩뿌리고 픽셀마다
// 가장 가까운 씨앗을 찾아, 돌 하나하나가 다각형 덩이가 되게 쌓는다.
//   줄눈  첫째·둘째 씨앗까지의 거리가 비슷한 골 (v5)
//   낯빛  돌마다 한 색 (v1~v4), 윗변 한 줄이 밝다
//   크기  RC2=7 — 창·문 사이 벽 폭이 돌 두어 개는 되는 크기
const RC2 = 7;
function wallSeed(ci, cj) {
  return [ci * RC2 + 1 + hash(ci * 7 + 1, cj * 3 + 5) * (RC2 - 2),
          cj * RC2 + 1 + hash(ci * 3 + 4, cj * 7 + 2) * (RC2 - 2)];
}
function rubbleWall(g) {
  const stone = new Set(['k', 'K', 'i']);
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    if (!stone.has(g.d[y][x])) continue;
    const ci0 = Math.floor(x / RC2), cj0 = Math.floor(y / RC2);
    let d1 = 1e9, d2 = 1e9, id = 0;
    for (let cj = cj0 - 1; cj <= cj0 + 1; cj++) for (let ci = ci0 - 1; ci <= ci0 + 1; ci++) {
      const sp = wallSeed(ci, cj);
      const dx = x - sp[0], dy = (y - sp[1]) * 1.4;
      const d = dx * dx + dy * dy;
      if (d < d1) { d2 = d1; d1 = d; id = ci * 131 + cj * 61; }
      else if (d < d2) d2 = d;
    }
    const gap = Math.sqrt(d2) - Math.sqrt(d1);
    if (gap < 1.15) { g.px(x, y, 'v5'); continue; }
    const rc = hash(id, 17);
    let t = 2;
    if (rc < 0.24) t -= 1; else if (rc > 0.78) t += 1;
    g.px(x, y, 'v' + Math.max(0, Math.min(4, t)));
  }
  // 윗변 빛 — 줄눈 바로 아래 한 줄
  for (let y = 1; y < GH; y++) for (let x = 0; x < GW; x++) {
    const c = g.d[y][x];
    if (typeof c !== 'string' || c[0] !== 'v' || c === 'v5') continue;
    if (g.d[y - 1][x] !== 'v5') continue;
    const t = parseInt(c[1]);
    if (t > 0) g.px(x, y, 'v' + (t - 1));
  }
}

// 목재 — 세로로 긴 결// 목재 — 세로로 긴 결// 목재 — 세로로 긴 결 (한 열이 위아래로 쭉 이어진다)
function woodGrain(g) {
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    const c = g.d[y][x];
    if (!'utT'.includes(c)) continue;
    if (hash(x, 0) < 0.30 && DARKEN[c]) g.px(x, y, DARKEN[c]);
  }
}

// 빛은 **건물 하나에 한 방향**이다. 덩어리마다 따로 밝기를 매기면
// 세 채를 붙여 놓은 것처럼 보인다 — 그래서 캔버스 전체를 한 번에 훑는다.
// 비바람 자국 — 재질을 아무리 잘 깔아도 **새것처럼** 보이는 이유는
// 얼룩이 없어서다. 오래 선 집에는 세 가지가 반드시 있다:
//
//   흘러내린 줄  처마와 창턱에서 물이 흐른 자리가 세로로 남는다
//   밑동 흙탕물  비가 땅에 튀어 벽 아래 한 뼘이 늘 지저분하다
//   이끼         처마 가까운 기와 골, 해가 덜 드는 자리에 낀다
function weather(g) {
  // ① 흘러내린 줄 — 여섯 칸에 한 줄쯤. 시작한 자리부터 아래로 이어진다
  for (let x = 0; x < GW; x++) {
    if (hash(x, 77) > 0.17) continue;
    let run = 0;
    for (let y = 0; y < GH; y++) {
      const c = g.d[y][x];
      if (!'kKiwWx'.includes(c)) { run = 0; continue; }
      if (++run > 2 && hash(x, y) < 0.72 && DARKEN[c]) g.px(x, y, DARKEN[c]);
    }
  }
  // ② 밑동 — 땅에 가까울수록 짙게, 경계는 들쭉날쭉하게
  for (let y = GROUND - 11; y <= GROUND; y++) for (let x = 0; x < GW; x++) {
    const c = g.d[y][x];
    if (!'kKiwWx'.includes(c)) continue;
    const near = (y - (GROUND - 11)) / 11;                 // 0(위) ~ 1(바닥)
    if (hash(x * 3 + 1, y) < near * 0.75 && DARKEN[c]) g.px(x, y, DARKEN[c]);
  }
}

// 이끼 — 처마 가까운 기와에만. 지붕 전체에 뿌리면 초원이 된다
function moss(g) {
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
    if (roofT[y][x] < 0.62) continue;                      // 처마 쪽 = 톤이 제일 어두운 구간
    if (!ROOF_Q.has(g.d[y][x])) continue;
    // **덩어리로** 낀다. 잔 확률로 뿌렸더니 처마를 따라 초록 띠가 생겨서
    // 이끼가 아니라 페인트 줄로 보였다 — 큰 칸(4x3)으로 자리를 먼저 정하고
    // 그 안에서만 잔 무늬를 준다
    const spot = hash(x >> 2, y / 3 | 0);
    if (spot > 0.16) continue;
    const v = hash(x, y);
    if (v < 0.45) g.px(x, y, 'N');
    else if (v < 0.80) g.px(x, y, 'n');
  }
}

function roughen(g) {

  ditherFace(g, ['i', 'k', 'K'], 0, GROUND);            // 벽돌
  ditherFace(g, ['x', 'w', 'W'], 0, GROUND);            // 석재 테두리
  shingles(g);          // 기와는 사다리 톤으로 한 장씩
  // 칠한 널(plankk)은 k/K/i 를 널 무늬로 쓰므로 막돌 패스를 건너뛴다 —
  // 안 그러면 붉은 페인트가 붉은 막돌이 된다
  if (CHUNKY && WALL !== 'plankk') rubbleWall(g);
  else if (!CHUNKY) brickCourse(g);
  wallPatches(g, 0, GROUND);
  woodGrain(g);
  weather(g);           // 흘러내린 줄 · 밑동 흙탕물
  if (MOSSY) moss(g);   // 처마 가까운 기와의 이끼
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
// 몸이 낮아진 만큼 뒤로 눕는 깊이도 서른으로 — 36이면 지붕 윗면이
// 몸통의 두 배라 다시 「지붕만 있는 집」이 된다
const DEPTH = 30;

// 그리고 **멀어질수록 좁아진다.**
//
// 일자로만 밀면 아무리 깊어도 벽이 위로 자란 것처럼 보인다. 진짜로 뒤로
// 가는 것은 작아진다 — 그게 원근이다. 좌우로 비스듬히 미는 건 이미 해 봤고
// 건물이 기울어 보여서 접었는데, **가운데로 모으는 것**은 다르다.
// 양쪽이 똑같이 좁아지므로 정면은 마주 본 채로 뒤만 멀어진다.
// 깊어진 만큼 더 모아 준다. 길이가 두 배인데 좁아지는 폭이 그대로면
// 뒤가 멀어지는 게 아니라 그냥 길쭉해 보인다
// 26%까지 모았더니 뒤가 좁아 굴뚝 놓을 자리가 없었다. 20%로 눅였다.
// (더 줄여도 소용없었다 — 지붕 **맨 뒤 폭은 용마루 폭(RH)** 이 정하지
//  좁아지는 비율이 정하는 게 아니다.)
// 원근은 좁아지는 폭 말고도 켜 간격과 톤 사다리가 같이 말해 준다.
const TAPER = 0.20;              // 맨 뒤에서 20% 좁아진다
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
      const isRoof = BACK_OF[c] === BACK_ROOF;
      for (let nx = a; nx <= b; nx++) {
        if (nx < 0 || nx >= GW || back.d[ny][nx] !== '.') continue;
        back.px(nx, ny, tone); dep[ny][nx] = i;
        // **앞이 차지한 칸에는 쓰지 않는다.** back 은 따로 둔 판이라
        // 앞에 그림이 있어도 여기선 비어 보인다 — 그대로 기록했더니
        // 앞 지붕의 켜 정보가 전부 뒷면 값으로 덮여 사라졌다
        if (!isRoof || g.d[ny][nx] !== '.') continue;
        // 뒤로 누운 면도 **같은 기와**다. 켜 번호를 앞 지붕에서 이어 받고,
        // 톤 사다리의 밝은 몫(BACK_LO~BACK_HI)을 깊이에 따라 나눠 쓴다
        // chunky 는 윗면을 한 단 누른다 — 맨 밝은 단을 평평하게 비우니
        // 지붕이 아니라 쌓인 눈이었다. 밝되 색이 있는 단에서 시작한다
        const bl = CHUNKY ? BACK_LO + 0.12 : BACK_LO;
        const bh = CHUNKY ? BACK_HI + 0.10 : BACK_HI;
        roofT[ny][nx] = bl + (bh - bl) * (i / DEPTH);
        roofRow[ny][nx] = FRONT_ROWS + [...COURSE].filter(v => v <= i).length;
      }
    }
  }
  // 뒤를 깔고 그 위에 정면을 얹는다
  for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++)
    if (g.d[y][x] === '.' && back.d[y][x] !== '.') g.px(x, y, back.d[y][x]);
  // 맨 뒤 용마루 — 하늘을 받는 모서리라 밝다. 지붕 뒷면에만 얹는다
  // (굴뚝 꼭대기까지 주황으로 칠하면 그것만 튄다)
  for (let x = 0; x < GW; x++) for (let y = 0; y < GH - 1; y++)
    if (g.d[y][x] !== '.') { if (BACK_ROOF.includes(g.d[y][x])) { g.px(x, y, 'Mn'); roofT[y][x] = -1; } break; }
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
// 아래 셋은 **건물마다 바뀐다** — build() 가 spec 을 보고 다시 잡는다
let MID = 109;                   // 1층·2층 경계
let EAVE = 87;                   // 처마. 낮을수록 지붕이 커진다
let RIDGE = 47;                  // 용마루 (위로 DEPTH만큼 더 물러날 자리를 남긴다)
// 크기는 **옛 집에서 재 왔다** — 내용이 292x384px = 73x96칸이고 캔버스
// 한가운데에 있다. 이걸 안 맞추면 집만 혼자 커져서 마을이 안 맞는다.
let X0 = 34, X1 = 94;            // 1층 벽 좌우 (build 에서 CX 기준으로 다시 잡는다)
const JUT = 3;                   // 2층이 앞으로 나온 턱 (제티)


// 벽 재료를 고를 수 있게 해 뒀다. 사진은 벽돌이고 옛 우리 집은 회벽이라,
// 어느 쪽이 마을에 맞는지는 나란히 놓고 봐야 안다.
//   brick   벽돌 쌓기 + 크림색 귀돌        (사진 쪽)
//   stucco  회벽 + 하프팀버 목재 띠         (옛 우리 집 쪽)
const WALL_CLI = (process.argv.find(a => a.startsWith('--wall=')) || '').slice(7);
let WALL = 'brick';
let MOSSY = true;                              // 이끼가 끼는 지붕인가
let WB = 'k', WD = 'K', FRAME = 'w';           // 벽 바탕 / 벽 그늘 / 창 테두리
const SHADE = 'D';                             // 구조 그늘 (덮어쓰기 안 됨)
function setWall(kind) {
  WALL = kind;
  WB = kind === 'stucco' ? 'w' : (kind === 'plank' ? 't' : 'k');
  WD = kind === 'stucco' ? 'W' : (kind === 'plank' ? 'T' : 'K');
  // 회벽·널판에 크림색 테두리를 두르면 벽에 묻힌다. 그럴 땐 진한 목재로
  FRAME = kind === 'brick' ? 'w' : 'T';
  // 칠한 널(plankk) — 널판인데 색은 벽 팔레트에서 받는다 (붉은 헛간).
  // 빨강 위의 테두리는 크림색이라야 「페인트와 트림」으로 읽힌다
  if (kind === 'plankk') { WB = 'k'; WD = 'K'; FRAME = 'w'; }
}


// 용마루 반폭 — **「위에서 본 지붕」은 뾰족한 고깔이 아니라 넓은 사다리꼴이다.**
//
// 오래 RH=4 로 두었더니 지붕이 한 점으로 모여서, 아무리 뒤로 밀어도
// 정면 입면도(전개도)로 보였다. 용마루가 **길게 누워** 있어야 그 띠가
// 그대로 뒤로 뻗어 지붕 윗면이 되고, 그제서야 「내려다본」 그림이 된다.
//
// 폭은 처마 반폭에서 지붕 높이의 절반쯤을 깎아 잡는다 — 모임지붕(우진각)의
// 귀마루가 45도보다 조금 눕는 각이다. 처마 72칸 / 용마루 38칸쯤 된다.
function ridgeHalf(half, h) { return Math.max(10, Math.round(half - h * 0.45)); }

function roofHalfW(i, h, half) {
  const RH = ridgeHalf(half, h);
  // 지수 0.94면 거의 곧은 빗변이다. 「너무 각져」서 부풀렸던 건데, 각을
  // 없애는 건 지붕이 아니라 **몸통 귀퉁이**의 일이었다 (soften이 한다).
  let w = RH + (half - RH) * Math.pow(i / h, 0.94);
  if (i > h - 4) w += (i - (h - 4)) * 1.5;               // 처마 들림
  return Math.round(w);
}

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
  for (let i = 0; i <= h; i++) {
    const w = roofHalfW(i, h, half);
    const a = Math.round(cx - w), b = Math.round(cx + w);
    g.rect(a, top + i, b, top + i, 'r');
    // 기와 한 장의 자리 정보. 켜는 **처마에서부터** 센다 — 뒤로 누운 면의
    // 켜와 번호가 이어져야 지붕이 한 면으로 읽힌다
    for (let x = a; x <= b; x++) {
      if (x < 0 || x >= GW) continue;
      roofT[top + i][x] = FRONT_LO + (FRONT_HI - FRONT_LO) * (i / h);
      roofRow[top + i][x] = Math.floor((base - (top + i)) / TH);
    }
  }
  FRONT_ROWS = Math.floor((base - top) / TH) + 1;
  // 처마 끝 서까래 — 기와보다 한 칸 튀어나온 널이라 기와를 얹지 않는다.
  // chunky 면 **비늘단**이다: 기와 한 장마다 가운데가 한 칸 처지는 물결.
  // 곧은 자로 끊긴 처마는 판금이고, 물결치는 처마가 손으로 얹은 기와다
  for (let x = x0 - 2; x <= x1 + 2; x++) {
    if (x < 0 || x >= GW) continue;
    const ph = ((x % TW) + TW) % TW;
    const drop = CHUNKY && ph >= 2 && ph <= TW - 3 ? 1 : 0;
    g.px(x, base - 1, 'r');
    g.px(x, base + drop, 'R');
    if (drop) g.px(x, base, 'r');
    g.px(x, base + drop + 1, SHADE);                       // 처마 밑 그늘
    roofT[base - 1][x] = -1; roofT[base][x] = -1;
    if (drop && base + 1 < GH) roofT[base + 1][x] = -1;
  }
}


// 귀마루 — 모임지붕의 **모서리 기와**. 빗변을 따라 얹히는 갓기와라서
// 박공널처럼 어둡게 두면 안 된다. 하늘을 바로 받는 모서리는 지붕면보다
// **밝고**, 그 안쪽 한 칸이 그늘이다 — 이 밝음/그늘 한 쌍이 두 면(앞면과
// 옆면)을 갈라 준다. 어둡게만 그었더니 사다리꼴에 검은 테를 두른 꼴이었다.
// **기와를 얹은 뒤에** 긋는다. 먼저 그으면 기와 패스가 덧칠해서 지붕에
// 모서리가 없어진다.
function bargeBoard(g, x0, x1, top, base) {
  const h = base - top, half = (x1 - x0) / 2, cx = (x0 + x1) / 2;
  for (let i = 0; i <= h - 2; i++) {
    const w = roofHalfW(i, h, half);
    for (const s of [-1, 1]) {
      const e = Math.round(cx) + s * w;
      if (ROOF_Q.has(g.get(e, top + i))) g.px(e, top + i, 'q1');
      if (ROOF_Q.has(g.get(e - s, top + i))) g.px(e - s, top + i, 'q2');
      if (ROOF_Q.has(g.get(e - s * 2, top + i))) g.px(e - s * 2, top + i, 'q6');
    }
  }
  // 용마루 갓기와 — 위에서 본 지붕은 **가로로 길게 누운 마루**가 제일 먼저
  // 보인다. 앞면과 뒤로 누운 면이 만나는 자리라 여기에 한 줄이 필요하다
  const rw = roofHalfW(0, h, half);
  for (let x = Math.round(cx) - rw; x <= Math.round(cx) + rw; x++) {
    if (ROOF_Q.has(g.get(x, top))) g.px(x, top, 'q1');
    if (ROOF_Q.has(g.get(x, top + 1))) g.px(x, top + 1, 'q2');
    if (ROOF_Q.has(g.get(x, top + 2))) g.px(x, top + 2, 'q5');
  }
}


// 벽 — 벽돌이면 크림색 귀돌로 각을 잡고, 회벽이면 하프팀버 목재를 두른다.
// skip: 'left' | 'right' — 다른 덩어리와 **붙는 쪽**은 귀돌을 안 넣는다.
// 양쪽 다 넣으면 이음매에 밝은 줄이 두 개 겹쳐서, 벽이 이어진 게 아니라
// 두 채가 맞닿은 것으로 보인다.
function wall(g, x0, x1, y0, y1, plinth, skip) {
  g.rect(x0, y0, x1, y1, WB);
  if (WALL === 'brick' && !CHUNKY) {
    // 귀돌 — 막돌 벽(chunky)에는 안 넣는다. 크림색 블록이 막돌 위에 떠서
    // 「벽에 붙인 스티커」가 됐다
    for (let y = y0 + 1; y < y1 - 3; y += 6) {
      if (skip !== 'left') g.rect(x0, y, x0 + 2, y + 2, 'w');
      if (skip !== 'right') g.rect(x1 - 2, y, x1, y + 2, 'w');
    }
  } else if (WALL === 'plank') {
    // 널판 — 세로로 널을 대고 이음매마다 어두운 줄. 헛간의 벽이다
    for (let x = x0; x <= x1; x += 5) g.vline(x, y0, y1, 'T');
    for (let x = x0 + 1; x <= x1; x += 5) g.vline(x, y0, y1, 'u');
  } else if (WALL === 'plankk') {
    // 칠한 널 — 이음매는 어둡게, 그 옆은 빛을. 색은 벽 팔레트(k/K/i)
    for (let x = x0; x <= x1; x += 5) g.vline(x, y0, y1, 'K');
    for (let x = x0 + 1; x <= x1; x += 5) g.vline(x, y0, y1, 'i');
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
  const on = (px, py) => g.get(px, py) !== '.';            // 실루엣 안에서만 자란다

  // 잎 한 장 — **세 색이 다 들어가야** 잎으로 보인다: 윤곽·속·빛.
  // 한 색으로 칠한 덩어리는 이끼지 잎이 아니다
  const leaf = (px, py, big) => {
    const w = big ? 2 : 1;
    for (let dy = 0; dy <= w; dy++) for (let dx = -w; dx <= w; dx++) {
      if (Math.abs(dx) + dy > w + 1) continue;
      if (on(px + dx, py + dy)) g.px(px + dx, py + dy, 'n');
    }
    if (on(px, py)) g.px(px, py, 'v');                     // 윗면이 빛을 받는다
    if (on(px, py + w)) g.px(px, py + w, 'N');             // 밑은 그늘
  };

  let side = 1;
  for (let y = yBottom; y >= yTop; y--) {
    const t = (yBottom - y) / h;
    // 줄기 — 두 파장으로 휘며 오른다. 곧게 그으면 밧줄이 된다.
    // 그리고 **띄엄띄엄** 끊는다 — 통줄이면 그것도 밧줄이다
    const sx = x + Math.round(Math.sin(y * 0.27) * 2.4 + Math.sin(y * 0.09) * 1.7);
    if (on(sx, y) && hash(sx, y) < 0.8) g.px(sx, y, 'N');
    // 잎은 줄기 **옆에 한 장씩** 번갈아. 위로 갈수록 성기다
    if (hash(sx * 5 + 1, y * 3) < 0.52 - t * 0.40) {
      side = -side;
      leaf(sx + side * 2, y, hash(y, sx) < 0.45);
    }
    // 곁가지 — 가끔 옆으로 뻗어 나가며 잎을 단다. 이게 있어야 「자란 것」이 된다
    if (t < 0.75 && hash(y, 91) < 0.055) {
      const dir = hash(y, 7) < 0.5 ? -1 : 1;
      const len = 3 + Math.floor(hash(y, 5) * 4);
      for (let k = 1; k <= len; k++) {
        const bx = sx + dir * k, by = y - (k >> 1);
        if (!on(bx, by)) break;
        g.px(bx, by, 'N');
        if (k % 2 === 0) leaf(bx, by - 1, false);
      }
    }
  }
  // 끝의 덩굴손 — 꼭대기에서 한두 가닥이 가늘게 삐져나온다.
  // 덩굴이 뭉툭하게 끝나면 잘라 붙인 것처럼 보인다
  for (let k = 0; k < 4; k++) {
    const ty = yTop - k, tx = x + Math.round(Math.sin(ty * 0.27) * 2.4) + (k % 2 ? 1 : -1);
    if (on(tx, ty)) g.px(tx, ty, k < 2 ? 'n' : 'N');
  }
}


// 널문 — 벽돌에 줄눈이 있듯 문에는 **널과 띠쇠**가 있다.
//
// 매끈한 판때기로 두면 벽만 재질이 있고 문은 색종이가 된다. 문도 사람이
// 만든 물건이라 짜 맞춘 자국이 남는다:
//
//   널     세로로 짜 맞춘다. 이음매는 어둡고 그 옆이 빛을 받는다
//   널색   한 장씩 조금씩 다르다 (같은 나무에서 잘라도 결이 다르다)
//   결·옹이 세로로 길게 지나간다
//   띠쇠   위아래 두 줄. 못머리가 박혀 있다 — 이 한 줄이 문을 「문」으로 만든다
//   밑동   비에 젖어 짙다. 문은 아래부터 썩는다
function plankFace(g, x0, x1, yTop, yBot) {
  // 널은 **다섯 칸**. 네 칸으로 좁혔더니 이음매(어두운 줄)가 문의 40%를
  // 차지해서 문이 통째로 까매졌다. 결도 0.16 -> 0.09로 줄인다 —
  // 재질을 넣는 것과 어둡게 칠하는 건 다른 일이다
  const PW = 5;
  for (let y = yTop; y <= yBot; y++) for (let x = x0; x <= x1; x++) {
    if (!'tuT'.includes(g.get(x, y))) continue;
    const col = Math.floor((x - x0) / PW), r = hash(col, 17);
    let c = r < 0.18 ? 'u' : (r > 0.72 ? 'u' : 't');       // 널마다 조금씩 다르게
    if ((x - x0) % PW === 0) c = 'T';                      // 널 사이 이음매
    else if ((x - x0) % PW === 1) c = 'u';                 // 이음매 옆이 빛을 받는다
    if (hash(x, y >> 2) < 0.09) c = (c === 'u') ? 't' : 'T';   // 결·옹이
    g.px(x, y, c);
  }
  for (const by of [yTop + 4, yBot - 5]) {                 // 띠쇠
    if (by <= yTop || by >= yBot) continue;
    g.hline(x0, x1, by, 'S');
    g.hline(x0, x1, by + 1, 'p5');
    for (let x = x0 + 2; x <= x1; x += 5) g.px(x, by, 'p3');   // 못머리
  }
  for (let y = yBot - 5; y <= yBot; y++) for (let x = x0; x <= x1; x++)  // 젖은 밑동
    if ('tu'.includes(g.get(x, y)) && hash(x, y * 3) < (y - (yBot - 6)) / 6 * 0.55)
      g.px(x, y, 'T');
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
  plankFace(g, x0 + 1, x0 + w - 2, y0 + 1, GROUND - 1);    // 널·띠쇠·결
  g.vline(x0, y0 + 4, GROUND, 'T');                        // 문설주
  g.vline(x0 + w - 1, y0 + 4, GROUND, 'T');
  g.rect(x0 + w - 4, y0 + Math.floor(h / 2) - 1, x0 + w - 3, y0 + Math.floor(h / 2), 'y');
  g.px(x0 + w - 4, y0 + Math.floor(h / 2) + 1, 'Y');       // 손잡이
  // 문 위 **현관 지붕**. 작은 차양 두 줄로는 문이 벽에 뚫린 구멍으로 보인다.
  // 처마가 밖으로 나오고 밑에 그늘이 깔려야 「들어가는 곳」이 된다
  // 현관 지붕도 **기와를 얹는다.** 주황 막대 하나로 두면 큰 지붕만 기와고
  // 여기만 색종이가 된다. roofT 를 찍어 두면 기와 패스가 알아서 깔아 준다
  for (let i = 0; i < 3; i++)
    for (let x = x0 - 2 - i; x <= x0 + w + 1 + i; x++) {
      g.px(x, y0 - 4 + i, i === 0 ? 'l' : 'r');
      markRoof(x, y0 - 4 + i, roofToneAt(y0 - 4 + i), y0 - 2);
    }
  g.hline(x0 - 4, x0 + w + 3, y0 - 1, 'R');
  g.hline(x0 - 3, x0 + w + 2, y0, 'D');                    // 현관 지붕 밑 그늘
  // 문지방 돌
  g.rect(x0 - 2, GROUND - 1, x0 + w + 1, GROUND, 'S');
  g.hline(x0 - 2, x0 + w + 1, GROUND - 1, 's');
}


// 헛간의 두짝문 — 수레가 드나드는 폭에, 문짝마다 크림색 X 버팀대.
// 이 X 하나가 건물을 「헛간」으로 만든다 (윤곽만으로 이름이 나와야 한다)
function barnDoors(g, cx, w, h, GROUND) {
  const x0 = cx - Math.floor(w / 2), y0 = GROUND - h, x1 = x0 + w - 1;
  g.rect(x0 - 1, y0 - 1, x1 + 1, GROUND, 'w');             // 크림색 문틀
  g.rect(x0 + 1, y0 + 1, x1 - 1, GROUND, 't');
  plankFace(g, x0 + 1, x1 - 1, y0 + 1, GROUND - 1);
  // 문짝마다 X — 대각선은 두 칸 두께라야 빨강 위에서 읽힌다
  for (const side of [0, 1]) {
    const a = x0 + 1 + side * ((w - 2) >> 1);
    const b = side ? x1 - 1 : x0 + ((w - 2) >> 1);
    const dw = b - a, dh = GROUND - 1 - (y0 + 1);
    for (let i = 0; i <= dh; i++) {
      const t = i / dh;
      const xa = Math.round(a + t * (dw - 1)), xb = Math.round(b - 1 - t * (dw - 1));
      g.px(xa, y0 + 1 + i, 'w'); g.px(xa + 1, y0 + 1 + i, 'W');
      g.px(xb, y0 + 1 + i, 'w'); g.px(xb + 1, y0 + 1 + i, 'W');
    }
    g.hline(a, b, y0 + 1, 'w');                            // 위아래 가로대
    g.hline(a, b, GROUND - 1, 'w');
  }
  g.vline(cx, y0 + 1, GROUND, 'T');                        // 가운데 틈
  g.rect(cx - 4, y0 + (h >> 1), cx - 3, y0 + (h >> 1) + 1, 'y');   // 손잡이
  g.rect(cx + 3, y0 + (h >> 1), cx + 4, y0 + (h >> 1) + 1, 'y');
  // 문지방 돌
  g.rect(x0 - 2, GROUND - 1, x1 + 2, GROUND, 'S');
  g.hline(x0 - 2, x1 + 2, GROUND - 1, 's');
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


// ---- 무슨 집인지 말하는 것들 ----
//
// 색과 실루엣을 갈라도 「저건 대장간이다」는 아직 안 보였다. 그건 재료가
// 아니라 **간판 그림과 문 앞의 물건**이 말한다. 마을에서 길을 찾을 때
// 사람이 실제로 보는 건 그 둘이다.
//
// 그림은 11x8칸 = 화면 22x16px. 이 크기에서 읽히려면 **덩어리 하나**로
// 그려야 한다 — 선으로 그리면 다 뭉개진다.
const ICON = {
  hammer: ['..#######..', '..#######..', '..#######..', '....###....',
           '....###....', '....###....', '...#####...', '..#######..'],
  jar:    ['....###....', '...#####...', '..#######..', '..#ooooo#..',
           '..#ooooo#..', '..#ooooo#..', '..#######..', '...#####...'],
  cow:    ['.##.....##.', '.###...###.', '..#######..', '..#o###o#..',
           '..#######..', '..#######..', '...##.##...', '...........'],
  fish:   ['...........', '...####..#.', '..######.##', '.###o#####.',
           '.#########.', '..######.##', '...####..#.', '...........'],
  mug:    ['...........', '..#####.##.', '..#ooo#.#.#', '..#ooo##..#',
           '..#ooo#...#', '..#ooo#..#.', '..#####.##.', '...........'],
  book:   ['...........', '..#######..', '..#o###o#..', '..#o###o#..',
           '..#o###o#..', '..#o###o#..', '..#######..', '...........'],
  flask:  ['....###....', '....#.#....', '....#.#....', '...#ooo#...',
           '..#ooooo#..', '..#ooooo#..', '..#ooooo#..', '...#####...'],
  bell:   ['....###....', '...#####...', '..#######..', '..#o###o#..',
           '.#########.', '###########', '....###....', '....###....'],
  letter: ['...........', '.#########.', '.##.....##.', '.#.##.##.#.',
           '.#..###..#.', '.#.......#.', '.#########.', '...........'],
  // 새싹 — 마을 문장(리틀 루트). 장사 간판이 아니라 **문패**에 쓴다
  sprout: ['.....#.....', '..##.#.##..', '.#oo##oo#..', '.#oo##oo#..',
           '..##.#.##..', '.....#.....', '....###....', '...#####...'],
};

function stampIcon(g, cx, cy, name, dark, lite) {
  const a = ICON[name];
  if (!a) return;
  for (let y = 0; y < a.length; y++) for (let x = 0; x < a[y].length; x++) {
    const c = a[y][x];
    if (c === '.') continue;
    g.px(cx - 5 + x, cy - 4 + y, c === 'o' ? lite : dark);
  }
}

// 가로로 짠 나무판 — 간판·게시판. **문과 짜는 방향이 다르다.**
// 문은 세로 널(비가 흘러내려야 하니까), 간판은 가로 판(글씨를 넓게 쓰니까).
// 방향이 다르면 같은 나무여도 다른 물건으로 읽힌다.
function boardFace(g, x0, y0, x1, y1) {
  const BH2 = 4;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    if (!'bB'.includes(g.get(x, y))) continue;
    const row = Math.floor((y - y0) / BH2), r = hash(row, 23);
    let c = r < 0.32 ? 'B' : 'b';
    if ((y - y0) % BH2 === 0) c = 'B';                     // 판 사이 이음매
    if (hash(x >> 1, y * 3) < 0.11) c = 'B';               // 결
    g.px(x, y, c);
  }
  // 귀쇠 — 네 귀퉁이를 쇠로 물린다. 간판이 「걸린 물건」이 된다
  for (const [px, py] of [[x0, y0], [x1 - 1, y0], [x0, y1 - 1], [x1 - 1, y1 - 1]]) {
    g.rect(px, py, px + 1, py + 1, 'S');
    g.px(px, py, 'p3');
  }
}

function sign(g, cx, icon) {
  const w = 24, x0 = cx - w / 2, y = EAVE + 4;
  g.vline(x0 + 4, y - 4, y, 'T');
  g.vline(x0 + w - 4, y - 4, y, 'T');
  g.rect(x0, y, x0 + w, y + 13, 'B');
  g.rect(x0 + 1, y + 1, x0 + w - 1, y + 12, 'b');
  boardFace(g, x0 + 1, y + 1, x0 + w - 1, y + 12);
  g.hline(x0 + 1, x0 + w - 1, y + 1, 'x');                 // 판 윗변이 빛을 받는다
  stampIcon(g, cx, y + 7, icon, 'T', 'u');
}

// 걸이 간판 — 벽에서 팔이 나와 판이 매달린다. 가게라는 표시로 이만한 게 없다
function hangSign(g, x, y, icon) {
  g.hline(x, x + 9, y, 'T');                               // 팔
  g.px(x + 1, y + 1, 'T'); g.px(x + 2, y + 1, 'T');        // 버팀대
  g.vline(x + 3, y + 1, y + 2, 'S'); g.vline(x + 9, y + 1, y + 2, 'S');
  g.rect(x - 1, y + 3, x + 13, y + 15, 'B');
  g.rect(x, y + 4, x + 12, y + 14, 'b');
  boardFace(g, x, y + 4, x + 12, y + 14);
  stampIcon(g, x + 6, y + 9, icon, 'T', 'u');
}

// 연기 — 굴뚝에서 오르는 것. 대장간은 늘 불을 때고 있다
function smoke(g, x, y) {
  const puff = (px, py, r) => {
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++)
      if (Math.hypot(dx, dy) <= r + 0.3)
        g.px(px + dx, py + dy, Math.hypot(dx, dy) > r - 1 ? 'p5' : 'p4');
  };
  puff(x, y, 3); puff(x - 4, y - 6, 4); puff(x + 2, y - 13, 5);
}

// 담금질통 — 대장간 앞. 벌겋게 단 쇠를 식히는 물통
function trough(g, x, y) {
  g.rect(x, y - 7, x + 13, y, 't');
  g.hline(x, x + 13, y - 7, 'u');
  g.hline(x, x + 13, y, 'T');
  g.rect(x + 1, y - 6, x + 12, y - 4, 'G');                // 물
  g.hline(x + 2, x + 11, y - 6, 'e');
  for (let i = x; i <= x + 13; i += 6) g.vline(i, y - 7, y, 'T');
}

// 울타리 — 목장 상회 앞. 가로 두 줄에 말뚝
function fence(g, x0, x1, y) {
  g.hline(x0, x1, y - 8, 't');
  g.hline(x0, x1, y - 4, 't');
  for (let x = x0; x <= x1; x += 6) { g.vline(x, y - 11, y, 'T'); g.px(x, y - 12, 'T'); }
}

// 널어 말리는 생선 — 수산시장. 이 한 줄이면 무슨 가게인지 끝난다
function fishLine(g, x0, x1, y) {
  g.hline(x0, x1, y, 'T');
  for (let x = x0 + 3; x < x1; x += 7) {
    g.vline(x, y + 1, y + 2, 'T');
    g.rect(x - 2, y + 3, x + 2, y + 6, 's');
    g.px(x - 3, y + 4, 'S'); g.px(x + 3, y + 5, 'S');      // 꼬리
    g.px(x - 1, y + 4, 'S');                                // 눈
  }
}

// 우체통 — 우체국 앞. 빨간 기둥에 투입구
function mailbox(g, x, y) {
  g.rect(x, y - 16, x + 8, y, 'A');
  g.vline(x, y - 16, y, 'a');
  g.rect(x - 1, y - 19, x + 9, y - 16, 'A');
  g.hline(x - 1, x + 9, y - 19, 'a');
  g.rect(x + 2, y - 14, x + 6, y - 13, 'O');               // 투입구
  g.rect(x - 1, y - 1, x + 9, y, 'S');
}

// 가로등 — 도서관 앞. 밤에 책 읽는 집이라는 표시
function lamppost(g, x, y) {
  g.vline(x, y - 24, y, 'S');
  g.rect(x - 1, y - 1, x + 1, y, 'S');
  g.rect(x - 3, y - 30, x + 3, y - 25, 'T');
  g.rect(x - 2, y - 29, x + 2, y - 26, 'y');
  g.hline(x - 3, x + 3, y - 31, 'S');
  g.px(x, y - 32, 'S');
}

// 긴 의자 — 여관 앞. 앉아 쉬는 집
function bench(g, x, y) {
  g.rect(x, y - 6, x + 15, y - 4, 't');
  g.hline(x, x + 15, y - 6, 'u');
  g.hline(x, x + 15, y - 4, 'T');
  for (const i of [x + 1, x + 13]) g.vline(i, y - 3, y, 'T');
  g.rect(x, y - 12, x + 15, y - 11, 't');                  // 등받이
  for (const i of [x + 1, x + 13]) g.vline(i, y - 11, y - 6, 'T');
}

// 매달린 바구니 — 잡화점 차양 밑에 주렁주렁
function baskets(g, x0, x1, y) {
  for (let x = x0; x <= x1; x += 11) {
    g.vline(x, y, y + 2, 'T');
    g.rect(x - 3, y + 3, x + 3, y + 6, 'b');
    g.hline(x - 3, x + 3, y + 3, 'B');
    g.px(x - 1, y + 2, 'n'); g.px(x + 1, y + 2, 'n');      // 삐져나온 잎
  }
}


// 굴뚝 — 기와와 **같은 방식으로.**
//
// 네모 하나를 벽돌색으로 칠하고 갓을 얹는 것으로는 굴뚝 「자리」까지다.
// 벽돌도 한 장씩 쌓아야 굴뚝이 된다:
//
//   갓돌    양옆으로 한 칸씩 나오고 **밑에 그늘**이 깔린다 — 얹혀 있다는 표시
//   몸통    3칸짜리 벽돌을 켜마다 반 장씩 어긋나게. 장마다 윗변은 밝고 아랫변은 턱
//   옆면    왼쪽 한 줄은 빛, 오른쪽 두 줄은 그늘 — 둥근 관이 아니라 각진 기둥
//   그림자  지붕에 드리운다. 없으면 굴뚝이 지붕에서 떠 보인다
// far = 뒤로 물러난 지붕면 위에 선 굴뚝. **작고 어둡게** 그린다 —
// 크기와 대비가 곧 거리다. 같은 크기·같은 밝기로 두면 아무리 위에 올려도
// 그냥 「지붕 위쪽에 있는 굴뚝」이지 「뒤에 있는 굴뚝」이 아니다.
function chimney(g, x, top, base, far, w) {
  const W = w || (far ? 5 : 7), x1 = x + W - 1;
  const TD = far ? 5 : 7;                                  // 윗면(아가리) 깊이
  const bodyY = top + 4;
  // 색은 **지붕 사다리에서** 뽑는다 (build 에서 p0..p6 을 채워 둔다).
  const LIT = 'p0', MID = 'p1', DIM = 'p2';
  // 갓은 **먼 굴뚝이라고 어둡게 두면 안 된다.** 몸통만 거리에 따라 눅이고
  // 갓 윗면은 늘 사다리 맨 위를 쓴다 — 하늘을 정면으로 받는 유일한 면이라
  // 여기가 어두우면 굴뚝이 지붕에 뚫린 구멍으로 보인다 (실제로 그랬다).
  const CAP = 'p3', CAPM = 'p4';
  // 지붕과 **같은 색줄기**를 쓰기로 한 대가로, 굴뚝이 지붕에 묻힐 수 있다.
  // 그래서 몸통 둘레에 윤곽선을 두른다 — 색이 아니라 선이 물건을 세운다.
  const mine = new Set();
  const P = (xx, yy, c) => { g.px(xx, yy, c); if (yy >= 0 && yy < GH && xx >= 0 && xx < GW) mine.add(yy * GW + xx); };
  // 밑동은 **지붕 빗변과 같은 기울기로 잘린다.**
  //
  // 수평으로 자르면 굴뚝만 딴 평면에 서 있는 것처럼 보인다. 굴뚝은
  // 비스듬한 면을 뚫고 나온 것이라, 오른쪽으로 갈수록 발이 내려가야 한다.
  // 빗변 기울기(약 1:1)를 그대로 쓰면 일곱 칸에 여섯 줄이 떨어져서 밑동이
  // **잘려 나간 것처럼** 보인다. 절반이면 「지붕을 따라간다」는 읽히면서
  // 굴뚝은 여전히 곧게 서 있다.
  // **어느 쪽 지붕에 섰느냐에 따라 기울기가 뒤집힌다.** 오른쪽 지붕은
  // 오른쪽으로 내려가고 왼쪽 지붕은 왼쪽으로 내려간다. 한 방향으로 박아
  // 두면 왼쪽에 세운 굴뚝 발이 지붕과 **반대로** 기울어 어긋나 보인다.
  const SLOPE = 0.5;
  const down = (x + W / 2 < CX) ? -1 : 1;                  // 내려가는 쪽
  const foot = xx => {
    const c = Math.max(x, Math.min(x1, xx));
    return base + Math.round((down > 0 ? c - x : x1 - c) * SLOPE);
  };

  // 벽돌 켜 — **기와와 같은 자로 잰다.** 한 장이 TW x TH 이고 켜마다 반
  // 장씩 어긋난다. 굴뚝만 다른 무늬로 쌓았더니 지붕에서 뚫고 나온 게 아니라
  // 지붕 앞에 세워 둔 딴 물건으로 보였다 — 재료가 같으면 손도 같아야 한다.
  // **먼 굴뚝이라고 톤까지 뭉개면 안 된다.** 어둡게 눌렀더니 벽돌 켜가
  // 전부 한 색으로 붙어서 굴뚝이 지붕에 뚫린 검은 홈이 됐다. 거리는
  // 크기(폭 7 vs 11)가 말한다 — 색은 두 굴뚝 다 같은 네 단을 쓴다.
  const LAD = [LIT, MID, DIM, 'p6'];
  for (let xx = x; xx <= x1; xx++) for (let y = bodyY; y <= foot(xx); y++) {
    const row = Math.floor((base - y) / TH);
    const u = xx + ((row % 2) ? (TW >> 1) : 0);
    const col = Math.floor(u / TW);
    const r = hash(col * 3 + 7, row * 5 + 1);
    // 왼쪽이 빛, 오른쪽 두 줄이 그늘 — 각진 기둥의 기본
    let i = xx === x ? 0 : (xx >= x1 - 1 ? 3 : 1);
    if (CHUNKY) {
      // 평평한 기둥에 **드문 획**만 — 지붕·벽과 같은 그림체
      const isBottom = Math.floor((base - (y + 1)) / TH) !== row;
      const ru = ((u % TW) + TW) % TW;
      if (r < 0.30 && isBottom && ru >= 1 && ru <= 4) i += 1;
    } else {
      if (r < 0.22) i += 1; else if (r > 0.80) i -= 1;
      if (Math.floor((base - (y - 1)) / TH) !== row) i -= 1;   // 윗변 (빛)
      if (Math.floor((base - (y + 1)) / TH) !== row) i += 1;   // 아랫변 (겹침 턱)
      if (u % TW === 0) i += 1;                                // 세로 이음매
    }
    P(xx, y, LAD[Math.max(0, Math.min(3, i))]);
  }

  // 갓돌 — 양옆으로 두 칸씩 나온다. 이 턱과 밑그늘이 「얹혀 있다」를 만든다
  const CO = far ? 1 : 2;                                   // 갓 내밀기
  for (let yy = top + 1; yy <= top + 3; yy++)
    for (let xx = x - CO; xx <= x1 + CO; xx++) P(xx, yy, yy === top + 3 ? 'p5' : CAPM);
  P(x1 + CO, top + 2, 'p5');

  // ---- 윗면과 아가리 ----
  //
  // 위에서 내려다본 그림이니 굴뚝은 **아가리가 보여야 한다.** 갓돌 위로
  // 윗면이 뒤로 물러나고 그 한가운데가 뚫려 안쪽 벽이 보인다 — 이 구멍
  // 하나가 굴뚝을 「기둥」에서 「통」으로 바꾼다. 넓적한 갓만 얹었을 땐
  // 아무리 색을 갈아도 회색 막대에 뚜껑을 덮은 것으로 보였다.
  //
  //   윗면    갓돌 앞모서리 위로 TD 줄. 멀어질수록 **좁아지고 조금 어둡다**
  //   앞모서리 한 줄 어둡게 — 윗면과 정면을 가르는 접힘선
  //   아가리   윗면 한가운데. 안쪽 먼 벽이 한 단 밝아야 「깊이」가 생긴다
  for (let k = 1; k <= TD; k++) {
    const inset = Math.round((k - 1) * 0.4);
    const a = x - CO + inset, b = x1 + CO - inset;
    if (a > b) break;
    for (let xx = a; xx <= b; xx++) P(xx, top - k, k >= TD - 1 ? CAPM : CAP);
  }
  for (let xx = x - CO; xx <= x1 + CO; xx++) P(xx, top, 'p5');   // **앞 모서리**
  const hx0 = x + 1, hx1 = x1 - 1, hy1 = top - 2, hy0 = top - TD + 1;
  if (hx1 > hx0 && hy1 > hy0) {
    for (let yy = hy0; yy <= hy1; yy++)
      for (let xx = hx0; xx <= hx1; xx++) P(xx, yy, 'O');
    for (let xx = hx0; xx <= hx1; xx++) {
      P(xx, hy0, CAPM);                                     // 안쪽 먼 벽
      P(xx, hy0 + 1, 'p5');
    }
    P(hx0, hy1, 'p5'); P(hx1, hy1, 'p5');                   // 아가리 앞턱
  }
  // 윤곽 — 굴뚝에 **닿은 바깥 칸**만 먹색으로. 하늘 쪽은 g.outline() 이 한다
  for (const key of [...mine]) {
    const cy = Math.floor(key / GW), cx = key % GW;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = cx + dx, ny = cy + dy;
      if (nx < 0 || ny < 0 || nx >= GW || ny >= GH) continue;
      if (mine.has(ny * GW + nx) || g.d[ny][nx] === '.') continue;
      g.px(nx, ny, 'O');
    }
  }

  // 밑동 — **물받이(납판).** 굴뚝이 지붕을 뚫고 나온 자리에는 빗물이 새지
  // 않게 납판을 둘러 댄다. 이 치마가 굴뚝을 지붕에 앉힌다.
  // 밝은 회색으로 넓게 둘렀더니 지붕 위에 붙인 딱지가 됐다 — 납판은
  // 이음매지 장식이 아니다. 어둡고 좁아야 「끼워 넣은 자리」로 읽힌다.
  // 밑동 — **큰 판을 두르지 않는다.**
  //
  // 네 줄짜리 회색 앞치마를 둘렀더니 「굴뚝 밑에 회색을 칠해 놓은 것」처럼
  // 보였다. 실제로는 기와가 굴뚝에 **맞닿아 끊기고**, 그 이음매를 따라
  // 얇은 납판이 **계단으로 물려** 내려간다. 계단 한 칸의 높이가 기와 켜
  // 높이(TH)와 같아야 「기와 사이에 끼워 넣은 것」으로 읽힌다.
  //
  // 지붕이 있는 자리에만 찍는다 — 굴뚝이 지붕 밖으로 나가도 납판은
  // 하늘에 떠 있으면 안 된다.
  const onRoof = (xx, yy) => yy >= 0 && yy < GH && xx >= 0 && xx < GW
    && roofT[yy][xx] >= 0;
  // 계단 납판도 해 봤지만 **뒤로 누운 면에는 안 맞았다.** 그 면은 좌우
  // 기울기가 없어서(켜가 수평이다) 계단이 지붕 위에 흩어진 블록이 됐다.
  // 여기서 필요한 건 계단이 아니라 「기와가 굴뚝에 부딪혀 끊긴다」는 사실이다.
  //
  //   ① 발을 두르는 얇은 이음매 — 한 칸 걸러 비워서 기와가 물고 들어오게
  //   ② 굴뚝에 **닿는 기와 줄**을 어둡게 — 부딪혀 그늘진 자리
  //   ③ 밑으로 번지는 그림자 (아래에서)
  for (let xx = x - 1; xx <= x1 + 1; xx++) {
    const b = foot(xx), inside = xx >= x && xx <= x1;
    if (inside || onRoof(xx, b - 1)) g.px(xx, b - 1, 'p5');
    // 밑줄은 한 칸 걸러 — 통줄로 그으면 다시 「칠해 놓은 판」이 된다
    if ((xx + b) % 3 !== 1 && (inside || onRoof(xx, b))) g.px(xx, b, 'p5');
  }
  for (const xx of [x - 1, x1 + 1])
    for (let yy = bodyY + 2; yy <= foot(xx) + 1; yy++)
      if (onRoof(xx, yy)) roofT[yy][xx] = Math.min(1, roofT[yy][xx] + 0.38);
  // 지붕에 드리운 그림자 — 기와 **톤 사다리를 몇 단 아래로 밀어** 준다.
  // 색을 직접 칠하면 나중에 도는 기와 패스가 그대로 덮어쓴다
  for (let y = top + 3; y <= Math.max(foot(x), foot(x1)); y++)
    for (let d = 1; d <= 4; d++) {
      const xx = x1 + d;                                   // 빛은 늘 왼쪽 위에서 온다
      if (roofT[y + 2] && roofT[y + 2][xx] >= 0)
        roofT[y + 2][xx] = Math.min(1, roofT[y + 2][xx] + (d < 3 ? 0.30 : 0.15));
    }
  // 납판 밑에도 — **발과 같이 비스듬히** 내려간다
  for (let xx = x - 2; xx <= x1 + 5; xx++)
    for (let d = 0; d < 6; d++) {
      const yy = foot(xx) + 3 + d;
      if (roofT[yy] && roofT[yy][xx] >= 0)
        roofT[yy][xx] = Math.min(1, roofT[yy][xx] + 0.30 - d * 0.045);
    }
}


// ---- 그 집에 사는 티 ----
//
// 간판 하나에 물건 하나로는 아직 밋밋했다. 진짜로 「저 집은 대장간이다」가
// 되는 건 **연장이 벽에 걸려 있고 창턱에 물건이 널려 있을 때**다.
// 사람이 쓰는 집은 늘 어질러져 있다.

// 벽에 건 연장 — 집마다 다른 세 가지가 나란히 걸린다
function wallHang(g, x, y, kind) {
  if (kind === 'smith') {
    g.rect(x, y, x + 5, y + 1, 'S'); g.vline(x + 2, y + 2, y + 8, 'T');      // 망치
    g.vline(x + 9, y, y + 6, 'S'); g.vline(x + 11, y, y + 6, 'S');           // 집게
    g.px(x + 10, y + 7, 'S'); g.px(x + 10, y, 'S');
    for (const [dx, dy] of [[16,1],[17,0],[20,0],[21,1],[16,3],[21,3],[17,5],[20,5]])
      g.px(x + dx, y + dy, 'p4');                                            // 편자
  } else if (kind === 'ranch') {
    for (const [dx, dy] of [[0,0],[1,0],[5,0],[6,0],[0,1],[6,1],[1,2],[5,2],[2,3],[4,3],[3,4]])
      g.px(x + dx, y + dy, 'T');                                             // 굴레
    g.rect(x + 10, y, x + 12, y + 7, 'b'); g.hline(x + 10, x + 12, y, 'B');  // 우유통
    g.hline(x + 9, x + 13, y + 7, 'B');
    g.rect(x + 16, y + 1, x + 21, y + 6, 't');                               // 밧줄 타래
    g.rect(x + 17, y + 2, x + 20, y + 5, 'u');
  } else if (kind === 'fish') {
    for (let dy = 0; dy < 7; dy++) for (let dx = 0; dx < 22; dx++)           // 그물
      if ((dx + dy) % 3 === 0 || (dx - dy + 30) % 3 === 0) g.px(x + dx, y + dy, 'b');
    g.hline(x, x + 21, y, 'T');
  } else if (kind === 'herb') {
    for (let i = 0; i < 3; i++) {                                            // 말린 약초 다발
      const px = x + i * 8;
      g.vline(px, y, y + 1, 'T');
      g.rect(px - 2, y + 2, px + 2, y + 4, 'N');
      g.px(px - 3, y + 5, 'n'); g.px(px + 3, y + 5, 'n'); g.px(px, y + 6, 'n');
    }
  }
}

// 창턱에 늘어놓은 물건 — 그 가게가 파는 것
function sillGoods(g, x0, x1, y, kind) {
  const C = { jar: ['b', 'B'], bottle: ['g', 'G'], book: ['A', 'T'],
              flask: ['n', 'N'], fish: ['s', 'S'] }[kind] || ['b', 'B'];
  for (let x = x0; x <= x1 - 3; x += 5) {
    const h = 3 + ((x >> 1) % 3);
    g.rect(x, y - h, x + 2, y - 1, C[0]);
    g.px(x, y - h, C[1]); g.px(x + 2, y - 1, C[1]);
    if (kind === 'flask') g.px(x + 1, y - h - 1, C[1]);                      // 목
    if (kind === 'jar') g.px(x + 1, y - h - 1, C[1]);
  }
}

// 불똥 — 화구에서 튄다. 대장간이 「일하는 중」으로 보인다
function sparks(g, cx, y) {
  for (const [dx, dy] of [[-8,-3],[-6,-7],[-3,-10],[2,-9],[6,-6],[9,-2],[-10,1],[11,0]])
    g.px(cx + dx, y + dy, (dx + dy) % 2 ? 'y' : 'F');
}

// 그을음 — 화구 위 벽이 검게 탄다. 이게 있어야 오래 쓴 대장간이다
function soot(g, x0, x1, y) {
  for (let dy = 0; dy < 9; dy++) for (let x = x0 + dy; x <= x1 - dy; x++)
    if (hash(x, y + dy) < 0.75 - dy * 0.07) g.px(x, y - dy, 'D');
}

// 만국기 — 잡화점 앞에 걸린 삼각 깃발
function bunting(g, x0, x1, y) {
  for (let x = x0; x <= x1; x++) g.px(x, y + Math.round(Math.sin((x - x0) / (x1 - x0) * Math.PI) * 3), 'T');
  for (let i = 0; x0 + i * 9 + 4 < x1; i++) {
    const px = x0 + i * 9 + 2;
    const sag = Math.round(Math.sin((px - x0) / (x1 - x0) * Math.PI) * 3);
    for (let k = 0; k < 4; k++)
      g.rect(px + k, y + sag + 1 + k, px + 5 - k, y + sag + 1 + k, i % 2 ? 'A' : 'a');
  }
}

// 빨랫줄 — 우리집. 사람이 사는 집이라는 표시로 이만한 게 없다
function laundry(g, x0, x1, y) {
  for (let x = x0; x <= x1; x++) g.px(x, y + Math.round(Math.sin((x - x0) / (x1 - x0) * Math.PI) * 2), 'T');
  const cloth = [['x', 7], ['g', 6], ['A', 8]];
  cloth.forEach(([c, h], i) => {
    const px = x0 + 6 + i * 12;
    const sag = Math.round(Math.sin((px - x0) / (x1 - x0) * Math.PI) * 2);
    g.rect(px, y + sag, px + 7, y + sag + h, c);
    // 주름 — 천은 평평하지 않다. 세로 접힘 두 줄과 아랫단 그늘이면 충분하다
    const fold = { x: 'W', g: 'G', A: 'B' }[c] || 'W';
    g.vline(px + 2, y + sag + 1, y + sag + h - 1, fold);
    g.vline(px + 5, y + sag + 2, y + sag + h - 1, fold);
    g.hline(px, px + 7, y + sag, 'x');                     // 줄에 걸린 윗변
    g.hline(px, px + 7, y + sag + h, fold);
    g.px(px + 1, y + sag + h + 1, fold); g.px(px + 6, y + sag + h + 1, fold);
  });
}

// 관 — 연구소 벽을 타고 오르는 배관
function pipes(g, x, y0, y1) {
  g.vline(x, y0, y1, 'S'); g.vline(x + 1, y0, y1, 's');
  for (let y = y0 + 4; y < y1; y += 7) g.rect(x - 1, y, x + 2, y + 1, 'S');
  g.rect(x - 1, y0 - 2, x + 2, y0, 'S');
}

// 쌓아 둔 것 — 책(도서관) · 소포(우체국) · 석탄(대장간)
function pile(g, x, y, kind) {
  if (kind === 'book') {
    const c = ['A', 'g', 'b', 'N'];
    for (let i = 0; i < 4; i++) {
      g.rect(x + (i % 2), y - 3 - i * 3, x + 11 - (i % 2), y - 1 - i * 3, c[i]);
      g.hline(x + (i % 2), x + 11 - (i % 2), y - 1 - i * 3, 'T');
    }
  } else if (kind === 'parcel') {
    for (const [dx, dy, w, h] of [[0, 0, 11, 7], [2, 8, 8, 6], [1, 15, 6, 5]]) {
      g.rect(x + dx, y - dy - h, x + dx + w, y - dy, 'b');
      g.hline(x + dx, x + dx + w, y - dy - h, 'B');
      g.vline(x + dx + (w >> 1), y - dy - h, y - dy, 'A');                   // 노끈
      g.hline(x + dx, x + dx + w, y - dy - (h >> 1), 'A');
    }
  } else {                                                                    // 석탄
    for (let i = 0; i < 26; i++) {
      const px = x + Math.floor(hash(i, 3) * 14), py = y - Math.floor(hash(3, i) * 7);
      g.px(px, py, 'O'); g.px(px + 1, py, hash(i, i) < 0.3 ? 'S' : 'O');
    }
  }
}

// 갈매기 — 수산시장 지붕에. 작은 실루엣 하나가 바닷가라고 말해 준다
function gull(g, x, y) {
  g.rect(x + 1, y - 2, x + 5, y, 'x');
  g.px(x, y - 1, 'x'); g.px(x + 6, y - 3, 'x');
  g.px(x + 5, y - 3, 'x'); g.px(x + 6, y - 2, 'y');
  g.px(x + 2, y + 1, 'Y'); g.px(x + 4, y + 1, 'Y');
}


// 종 — 회관 종탑에 매단다. 마을을 부르는 물건이라 회관에만 있다
function bell(g, cx, y) {
  g.vline(cx, y - 3, y - 2, 'T');
  for (let i = 0; i < 5; i++) {
    const w = 1 + Math.round(i * 0.9);
    g.rect(cx - w, y - 1 + i, cx + w, y - 1 + i, i < 2 ? 'y' : 'Y');
  }
  g.rect(cx - 5, y + 4, cx + 5, y + 4, 'Y');
  g.px(cx, y + 5, 'y');                                    // 종설
}

// 돌계단 — 여럿이 드나드는 집. 문 앞이 넓게 열려 있다는 표시
function steps(g, cx, w, ground) {
  for (let i = 0; i < 3; i++) {
    const e = i * 4;
    g.rect(cx - (w >> 1) - e, ground - 4 + i * 2, cx + (w >> 1) + e, ground - 3 + i * 2, 'S');
    g.hline(cx - (w >> 1) - e, cx + (w >> 1) + e, ground - 4 + i * 2, 's');
  }
}

// 게시판 — 회관 앞 코르크판. 종이가 몇 장 붙어 있다
function noticeboard(g, x, y) {
  g.vline(x + 2, y - 8, y, 'T'); g.vline(x + 14, y - 8, y, 'T');
  g.rect(x, y - 24, x + 16, y - 7, 'T');
  g.rect(x + 1, y - 23, x + 15, y - 8, 'b');
  boardFace(g, x + 1, y - 23, x + 15, y - 8);
  for (const [dx, dy, w, h] of [[2, 21, 5, 6], [9, 20, 5, 7], [4, 13, 8, 4]]) {
    g.rect(x + dx, y - dy, x + dx + w, y - dy + h, 'x');
    g.px(x + dx + (w >> 1), y - dy, 'A');                  // 압정
  }
  for (let i = 0; i < 5; i++) g.rect(x - 1, y - 26 + i, x + 17, y - 26 + i, i ? 'r' : 'l');
}


// ---- 실루엣을 가르는 덩어리 ----
//
// 색만 바꿨더니 아홉 채가 「같은 집을 아홉 번 칠한 것」이었다. 멀리서
// 알아보는 건 색이 아니라 **실루엣**이다. 그래서 몸통에 혹을 붙인다 —
// 지붕창 · 곁채 · 탑 · 풍향계. 몸통 자체는 그대로 두니 같은 마을로 남는다.

// 덧붙인 지붕은 **본채와 같은 자로 재야 한다.**
//
// 처음엔 곁채·탑의 지붕 톤을 손으로 박아 뒀는데, 그 값은 본채 지붕이
// 쓰는 사다리와 무관해서 이어지는 자리에서 색이 뚝 끊겼다. 붙는 자리가
// 어디냐(본채 지붕의 몇 번째 톤 옆이냐)를 보고 폭을 정해야 한다.
//
// 그리고 본채는 옆에 붙은 것 위로 **그림자를 드리운다.** 낮은 곁채 지붕이
// 높은 본채 옆에서 그늘 없이 밝으면, 두 채가 그냥 나란히 서 있어 보인다.
// 본채 지붕이 쓰는 자 — 높이만 넣으면 그 자리의 톤이 나온다.
// 덧붙인 지붕은 전부 이걸 써야 이어지는 자리에서 색이 안 끊긴다.
function roofToneAt(y) {
  const t = FRONT_HI - (FRONT_HI - FRONT_LO) * (EAVE - y) / Math.max(1, EAVE - RIDGE);
  return Math.max(0, Math.min(1, t));
}

function markRoof(x, y, t, base) {
  if (y < 0 || y >= GH || x < 0 || x >= GW) return;
  roofT[y][x] = t;
  roofRow[y][x] = Math.floor((base - y) / TH);
}

// 지붕창 — 지붕에서 튀어나온 작은 박공. 실루엣에 혹이 하나 생겨서
// 멀리서도 「저 집은 다르다」가 보인다
function dormer(g, cx, base) {
  const half = 10, top = base - 15;
  for (let i = 0; i <= 11; i++) {
    const w = Math.round(half * Math.pow(i / 11, 0.9));
    for (let x = cx - w; x <= cx + w; x++) { g.px(x, top + i, 'r'); markRoof(x, top + i, 0.30 - i / 11 * 0.20, base); }
  }
  g.rect(cx - half + 2, top + 12, cx + half - 2, base, WB);
  g.hline(cx - half, cx + half, top + 11, 'R');
  archWin(g, cx - 4, top + 13, 9, base - top - 13, false);
  g.hline(cx - half - 1, cx + half + 1, base + 1, SHADE);   // 지붕창 밑 그늘
}

// 곁채 — 본채에 기대 붙인 낮은 헛간. 외쪽지붕이 바깥으로 흘러내린다.
// 대장간처럼 「작업하는 집」은 이 덩어리 하나로 성격이 정해진다
function leanTo(g, xa, xb, top) {
  const inner = xa < CX ? xb : xa;                         // 본채에 붙는 쪽
  wall(g, xa, xb, top + 7, GROUND, true, xa < CX ? 'right' : 'left');
  for (let x = xa; x <= xb; x++) {
    const t = Math.abs(x - inner) / Math.max(1, xb - xa);
    const y = top + Math.round(t * 8);
    // 본채가 드리우는 그림자 — 붙는 쪽이 제일 어둡고 멀어지며 옅어진다
    const shade = Math.max(0, 0.30 - Math.abs(x - inner) * 0.035);
    for (let k = 0; k < 6; k++) {
      g.px(x, y + k, 'r');
      // 톤은 **본채 자**로 재고, 켜도 본채 처마 기준으로 세어 줄이 이어진다
      markRoof(x, y + k, Math.min(1, roofToneAt(y + k) + shade), EAVE);
    }
    g.px(x, y + 6, SHADE);
  }
  archWin(g, Math.round((xa + xb) / 2) - 5, top + 15, 11, 14, false);
}

// 탑 — 한쪽에 세운 좁고 높은 덩어리. 도서관·회관처럼 「위를 보는 집」에.
//
// 몸통(벽)과 고깔지붕을 따로 잡는다. 원뿔 하나를 통째로 늘리면 높일수록
// 뾰족해지기만 하고 **탑이 아니라 송곳**이 된다 — 높아져야 하는 건
// 지붕이 아니라 그 밑의 기둥이다. 종은 그 기둥 꼭대기 살창에 매단다.
function tower(g, cx, wallTop, hgt, withBell) {
  const a = cx - 9, b = cx + 9, CONE = 24;
  const H = hgt || 28;                                     // 벽 위로 솟는 높이
  const shaftTop = wallTop - (H - CONE), rt = shaftTop - CONE;
  wall(g, a, b, shaftTop, GROUND, true, cx < CX ? 'right' : 'left');
  for (let i = 0; i <= CONE; i++) {
    const w = Math.round(2 + 9 * Math.pow(i / CONE, 0.9));
    for (let x = cx - w; x <= cx + w; x++) {
      g.px(x, rt + i, 'r');
      markRoof(x, rt + i, 0.82 - i / CONE * 0.58, shaftTop);
    }
  }
  g.hline(a - 2, b + 2, shaftTop, 'R');
  g.hline(a - 1, b + 1, shaftTop + 1, SHADE);
  const ly = shaftTop + 5;                                 // 종탑 살창
  louver(g, cx, ly, 11, 11);
  if (withBell) bell(g, cx, ly + 3);
  archWin(g, cx - 5, wallTop + 6, 11, 15, false);
}

// 이어 나온 한 칸 (wing) — 곁채와 달리 **본채의 일부처럼** 보여야 한다.
//
// 「붙인 느낌」은 세 가지에서 온다: 이음매의 어두운 줄, 겹친 귀돌,
// 그리고 지붕 켜가 안 맞는 것. 셋을 다 지운다 —
//   * 이음매 줄을 안 긋는다 (벽이 그냥 이어진다)
//   * 붙는 쪽 귀돌을 생략한다
//   * 지붕 켜를 **본채 처마 기준**으로 세어 기와 줄이 그대로 이어진다
function wing(g, xa, xb, eaveY) {
  const rightSide = xa > CX;
  wall(g, xa, xb, eaveY + 6, GROUND, true, rightSide ? 'left' : 'right');
  for (let x = xa; x <= xb; x++) {
    for (let k = 0; k < 6; k++) {
      g.px(x, eaveY + k, 'r');
      markRoof(x, eaveY + k, roofToneAt(eaveY + k), EAVE);
    }
    g.px(x, eaveY + 6, SHADE);                             // 처마 밑 그늘
  }
  const mx = Math.round((xa + xb) / 2);
  archWin(g, mx - 6, eaveY + 14, 13, 15, false);
  archWin(g, mx - 6, eaveY + 34, 13, 15, false);
}

// 풍향계 — 용마루 위에 꽂는 것. 한 줄짜리지만 하늘로 삐죽 나와서
// 실루엣 꼭대기를 바꾼다
function vane(g, cx, y) {
  g.vline(cx, y - 13, y, 'T');
  g.hline(cx - 5, cx + 5, y - 9, 'T');
  g.px(cx - 5, y - 10, 'T'); g.px(cx + 5, y - 10, 'T');
  g.rect(cx + 1, y - 16, cx + 6, y - 14, 'S');             // 화살 깃
  g.rect(cx - 4, y - 15, cx, y - 15, 'S');
  g.px(cx, y - 17, 's');
}

// 열린 가게 앞 — 문 대신 판매대. 수산시장처럼 「밖에서 사는 집」에
function stall(g, x0, x1, ground) {
  g.rect(x0, ground - 18, x1, ground - 2, 'O');            // 안쪽 어둠
  for (const x of [x0, x1]) g.vline(x, ground - 18, ground, 'T');
  g.hline(x0, x1, ground - 18, 'T');
  g.hline(x0, x1, ground - 17, 'D');
  g.rect(x0, ground - 7, x1, ground - 3, 't');             // 판매대
  g.hline(x0, x1, ground - 7, 'u');
  g.hline(x0, x1, ground - 3, 'T');
  for (let x = x0 + 2; x < x1; x += 5) g.px(x, ground - 9, 'e');   // 늘어놓은 물건
}


// ---- 건물마다 다른 설비 ----
//
// 아홉 채가 달라 보이는 건 **재료(색)** 와 **비례(폭·지붕 높이)** 와 이
// 설비들 덕이다. 몸통은 새로 안 그린다 — 그러면 같은 마을이 아니게 된다.

// 차양 — 가게 앞에 치는 줄무늬 천. 아래로 갈수록 한 칸씩 벌어지고,
// 밑단은 물결로 끊는다 (천이라는 표시. 일자로 끊으면 널빤지가 된다)
function awning(g, x0, x1, y) {
  const H = 7;                                             // 일곱 줄 = 화면 14px.
  for (let i = 0; i < H; i++) {                            // 이만해야 천으로 읽힌다
    const e = Math.round(i * 0.6);                         // 아래로 갈수록 벌어진다
    for (let x = x0 - e; x <= x1 + e; x++)
      g.px(x, y + i, (Math.floor((x + e) / 5) % 2 === 0) ? 'A' : 'a');
  }
  const e = Math.round(H * 0.6);
  for (let x = x0 - e; x <= x1 + e; x++) {                  // 물결 밑단
    if ((x + 2) % 5 < 3) g.px(x, y + H, (Math.floor((x + e) / 5) % 2 === 0) ? 'A' : 'a');
    g.px(x, y + H + 1, SHADE);
  }
}

// 다락문 — 헛간의 짐 올리는 문. 위에 도르래 팔이 나온다
function loftDoor(g, cx, y, w, h) {
  const a = cx - (w >> 1), b = cx + (w >> 1);
  g.rect(a, y, b, y + h, 'T');
  g.rect(a + 1, y + 1, b - 1, y + h - 1, 't');
  plankFace(g, a + 1, b - 1, y + 1, y + h - 1);
  g.hline(a, b, y, 'u');
  g.vline(cx, y - 5, y - 3, 'T');                          // 도르래 팔
  g.rect(cx - 3, y - 6, cx + 1, y - 5, 'T');
  g.px(cx - 3, y - 4, 'S');
}

// 장미창 — 도서관의 큰 원창. 살이 바퀴살처럼 뻗는다
function roseWin(g, cx, cy, r) {
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) {
    const d = Math.hypot(x, y);
    if (d > r + 0.4) continue;
    g.px(cx + x, cy + y, d > r - 2 ? 'w' : (d > r - 3 ? 'W' : 'g'));
  }
  for (let a = 0; a < 8; a++) {
    const dx = Math.cos(a * Math.PI / 4), dy = Math.sin(a * Math.PI / 4);
    for (let t = 1; t < r - 2; t++)
      g.px(cx + Math.round(dx * t), cy + Math.round(dy * t), 'T');
  }
  g.px(cx - 2, cy + 2, 'e');
}

// 환기 살창 — 연구소·헛간의 박공에 다는 것. 가로살만 있으면 된다
function louver(g, cx, y, w, h) {
  const a = cx - (w >> 1), b = cx + (w >> 1);
  g.rect(a, y, b, y + h, 'T');
  for (let i = y + 1; i < y + h; i += 2) g.hline(a + 1, b - 1, i, 'u');
}

// 옥탑 채광창 — 지붕 위에 얹은 작은 유리방
function cupola(g, cx, y) {
  g.rect(cx - 6, y - 11, cx + 6, y, 'i');
  g.rect(cx - 5, y - 9, cx + 5, y - 2, 'g');
  g.hline(cx - 5, cx + 5, y - 9, 'G');
  g.vline(cx, y - 9, y - 2, 'T');
  g.hline(cx - 5, cx + 5, y - 5, 'T');
  for (let i = 0; i < 5; i++) g.rect(cx - 8 + i, y - 16 + i, cx + 8 - i, y - 16 + i, 'r');
  g.hline(cx - 2, cx + 2, y - 16, 'l');
  g.hline(cx - 8, cx + 8, y - 11, SHADE);
}

// 화구 — 대장간의 아궁이. 문 대신 뚫린 아치에서 불빛이 샌다
function forge(g, cx, w, h, ground) {
  const x0 = cx - (w >> 1), y0 = ground - h;
  for (let i = 0; i < 3; i++) g.rect(x0 + (2 - i), y0 + i, x0 + w - 1 - (2 - i), y0 + i, 'S');
  g.rect(x0, y0 + 3, x0 + w - 1, ground, 'S');
  g.rect(x0 + 1, y0 + 4, x0 + w - 2, ground - 1, 's');
  g.rect(x0 + 2, y0 + 5, x0 + w - 3, ground - 1, 'O');     // 아궁이 속 어둠
  g.rect(x0 + 3, ground - 11, x0 + w - 4, ground - 2, 'F2');
  g.rect(x0 + 4, ground - 9, x0 + w - 5, ground - 3, 'F');
  g.rect(x0 + 5, ground - 7, x0 + w - 6, ground - 4, 'y'); // 제일 뜨거운 속
  g.px(x0 + 4, ground - 12, 'F2'); g.px(x0 + w - 5, ground - 13, 'F2');
  g.rect(x0 - 2, ground - 1, x0 + w + 1, ground, 'S');     // 문지방 돌
}

// 깃발 — 우체국 표시. 장대와 천 한 장
function flag(g, x, y) {
  g.vline(x, y - 22, y, 'T');
  g.px(x, y - 23, 'S');
  for (let i = 0; i < 6; i++)
    g.rect(x + 1, y - 22 + i, x + 11 - (i > 3 ? (i - 3) * 3 : 0), y - 22 + i,
      i % 3 === 1 ? 'a' : 'A');
}

// 나무궤짝 — 잡화점·수산시장 앞에 쌓아 둔 것
function crate(g, x, y, h) {
  g.rect(x, y - h, x + 9, y, 't');
  g.hline(x, x + 9, y - h, 'u');
  g.vline(x, y - h, y, 'T'); g.vline(x + 9, y - h, y, 'T');
  g.hline(x, x + 9, y, 'T');
  g.hline(x, x + 9, y - (h >> 1), 'T');
}

// 건초더미 — 목장 상회
function hay(g, x, y) {
  for (let i = 0; i < 4; i++) g.rect(x + i, y - 7 + i, x + 12 - i, y - 7 + i, 'b');
  g.rect(x, y - 4, x + 12, y, 'b');
  for (let i = x + 1; i < x + 12; i += 3) g.vline(i, y - 5, y - 1, 'B');
  g.hline(x, x + 12, y, 'B');
}

// 모루 — 대장간 앞. 실루엣만으로 알아보는 물건이라 형태만 정확하면 된다
function anvil(g, x, y) {
  g.rect(x + 1, y - 3, x + 7, y, 'T');                     // 나무 그루터기
  g.rect(x + 2, y - 4, x + 6, y - 4, 'S');
  g.rect(x + 3, y - 6, x + 5, y - 5, 'S');
  g.rect(x, y - 9, x + 8, y - 7, 'S');                     // 몸통
  g.hline(x, x + 8, y - 9, 's');
  g.px(x + 9, y - 8, 'S'); g.px(x - 1, y - 8, 'S');        // 뿔
}


// 그리는 **차례가 곧 깊이다.** 뒤에 있는 것부터 깔고 앞엣것으로 덮는다:
//   1층 벽 -> 2층 벽(제티) -> 창·문 -> 지붕 -> 뒤로 눕히기 -> 살림·담쟁이
function build(spec) {
  // 캔버스를 **격자를 만들기 전에** 잡는다. 순서를 반대로 뒀더니 이전 집
  // 크기로 격자가 만들어진 뒤에 판이 커져서 밖으로 쓰다가 터졌다
  setCanvas(spec.canvas ? spec.canvas[0] : 128, spec.canvas ? spec.canvas[1] : 138);
  const g = new G();
  resetRoof();

  // ---- 재료와 비례를 spec 에서 갈아 끼운다 ----
  // 대장간에서 실험한 chunky 가 **기본**이 됐다 — 큰 기와, 막돌 벽,
  // 비늘단 처마, 조용한 면. 한 채만 새 그림체면 그 한 채가 떠 보인다
  CHUNKY = spec.chunky !== false;
  TW = CHUNKY ? 8 : 5;
  TH = CHUNKY ? 4 : 3;
  const rp = ROOF_PAL[spec.roofPal || 'clay'];
  for (let i = 0; i < 8; i++) PAL['q' + i] = rp[i];
  // 기와를 얹기 **전** 색(r/R/l)과 뒤 지붕색도 같은 사다리에서 뽑는다.
  // 안 그러면 서까래만 주황으로 남아 지붕이 두 색이 된다
  PAL.l = rp[0]; PAL.r = rp[2]; PAL.R = rp[5];
  PAL.Mn = rp[4]; PAL.M = rp[5]; PAL.M2 = rp[6]; PAL.M3 = rp[7];
  // 불 켜진 창 — 유리색을 통째로 간다. 여관·도서관처럼 밤에도 사람이
  // 있는 집은 창 하나로 분위기가 갈린다
  if (spec.lit) { PAL.g = [246, 196, 96]; PAL.G = [206, 148, 56]; PAL.e = [254, 238, 186]; }
  else { PAL.g = [72, 148, 200]; PAL.G = [36, 84, 140]; PAL.e = [168, 216, 248]; }
  const wp = WALL_PAL[spec.wallPal || 'brick'];
  PAL.k = wp.k; PAL.K = wp.K; PAL.i = wp.i;
  // 막돌 사다리 (v0 밝음 ~ v4 어두움, v5 줄눈) — 벽 색 세 칸을 축으로
  // 사이를 메운다. 화로(rubble)와 같은 손이 되려면 단 수가 같아야 한다
  const mixv = (a2, b2, t2) => a2.map((v, i2) => Math.round(v * (1 - t2) + b2[i2] * t2));
  PAL.v0 = mixv(wp.i, [255, 255, 255], 0.25);
  PAL.v1 = wp.i; PAL.v2 = mixv(wp.i, wp.k, 0.5); PAL.v3 = wp.k;
  PAL.v4 = mixv(wp.k, wp.K, 0.55); PAL.v5 = wp.K;
  // 굴뚝은 **지붕에서 색을 받는다.**
  //
  // 벽 색에서 뽑았더니, 지붕이 집마다 갈리는데 굴뚝만 늘 벽 색이라
  // 「지붕 앞에 세워 둔 딴 물건」으로 보였다. 굴뚝은 지붕을 뚫고 나온
  // 것이니 같은 사다리에서 뽑아야 한 채로 읽힌다. 켜 무늬도 기와와
  // 같은 자(TW x TH)로 재니, 이제 재료와 손이 둘 다 같다.
  //   p0..p2  몸통 (빛 / 정면 / 그늘)   — 사다리 가운데
  //   p3..p5  갓돌과 윗면              — 사다리 위쪽 (하늘을 받는 면)
  //   p6      멀리 있는 굴뚝의 그늘
  PAL.p0 = rp[2]; PAL.p1 = rp[4]; PAL.p2 = rp[6];
  PAL.p3 = rp[0]; PAL.p4 = rp[2]; PAL.p5 = rp[7];
  PAL.p6 = rp[7];
  setWall(WALL_CLI || spec.wall || 'brick');
  // 그을린 지붕(대장간)과 청동 지붕(연구소)에는 이끼가 안 낀다 —
  // 하나는 늘 뜨겁고 하나는 늘 닦는 집이다
  MOSSY = !['soot', 'copper'].includes(spec.roofPal || 'clay');

  const wide = spec.w || 0, st = spec.storey || 0;         // 폭 가감 / 층높이 가감
  X0 = CX - 30 - wide; X1 = CX + 30 + wide;
  // **낮고 넓적하게.** 층고 22+22, 지붕 40으로 지은 집은 폭 90에 키
  // 120이 넘는 탑이었다 — 참고 맵(스타듀)의 집은 키가 폭과 엇비슷하다.
  // 1층 20, 2층은 다락으로 14, 지붕 34: 같은 집인데 앉은 자세가 낮아진다
  MID = GROUND - 20 - st;                                  // 1층 천장
  EAVE = MID - 14 - st + (spec.eave || 0);                 // 다락 천장 = 처마
  RIDGE = EAVE - 34 - (spec.pitch || 0);                   // +면 더 뾰족

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
  for (const x of [X0 - JUT + 1, X1 + JUT - 1]) {          // 제티 받침
    g.vline(x, MID + 2, MID + 5, 't');
    g.px(x + (x < CX ? 1 : -1), MID + 2, 'T');
  }

  // ---- 창 ----
  const bw = spec.bigWin ? 17 : 13;                        // 가게는 진열창이 넓다
  // 차양을 치는 집은 창을 **내려 단다.** 안 그러면 천이 창 위쪽을 덮어
  // 창이 반만 보이고, 그건 가게가 아니라 공사 중으로 보인다
  const wy = spec.awning ? MID + 10 : MID + 4;
  const wh = (spec.awning ? 10 : 12) + Math.round(st * 0.7);   // 층이 높으면 창도 크다
  archWin(g, CX - 13 - bw, wy, bw, wh, !spec.bigWin && !spec.awning);
  archWin(g, CX + 14, wy, bw, wh, !spec.bigWin && !spec.awning);
  if (spec.win3) {                                          // 여관 — 다락 창이 셋
    const h2 = 9 + Math.round(st * 0.5);
    archWin(g, CX - 31, EAVE + 3, 11, h2, false);
    archWin(g, CX - 5, EAVE + 3, 11, h2, false);
    archWin(g, CX + 21, EAVE + 3, 11, h2, false);
  } else {
    archWin(g, CX - 24, EAVE + 3, 12, 9 + Math.round(st * 0.5), false);
    archWin(g, CX + 13, EAVE + 3, 12, 9 + Math.round(st * 0.5), false);
  }

  // ---- 문 ----
  if (spec.forge) forge(g, CX, 19, 24, GROUND);
  else if (spec.barnDoor) barnDoors(g, CX, 34, 26, GROUND);
  else archDoor(g, CX, 15, 22, GROUND);
  if (spec.awning) awning(g, X0 + 2, X1 - 2, MID + 2);

  // ---- 지붕 ----
  // 박공 벽은 안 그린다 — 이 집은 지붕이 **앞을 보고** 있어서 삼각 벽면이
  // 나올 자리가 없다. 그렸더니 지붕 위에 크림색 삼각형이 덧칠됐다.
  roof(g, X0 - JUT - 3, X1 + JUT + 3, RIDGE, EAVE);
  const gy = RIDGE + 22;                                   // 박공 장식 자리
  switch (spec.gable) {
    case 'clock': clockFace(g, CX, gy, 9); break;
    case 'rose':  roseWin(g, CX, gy, 9); break;
    case 'loft':  loftDoor(g, CX, gy - 7, 15, 16); break;
    case 'vent':  louver(g, CX, gy - 6, 15, 13); break;
    default:      roundWin(g, CX, gy - 2, 6);
  }

  // ---- 실루엣을 가르는 덩어리 (extrude 앞에 — 뒤 지붕까지 같이 생긴다) ----
  let footL = X0, footR = X1;                              // 발자국 좌우 끝
  if (spec.dormer) dormer(g, CX + 22, EAVE - 6);
  if (spec.lean) {
    const r = spec.lean === 'right';
    const a = r ? X1 + JUT + 1 : X0 - JUT - 21, b = r ? X1 + JUT + 21 : X0 - JUT - 1;
    leanTo(g, a, b, MID - 16);
    footL = Math.min(footL, a); footR = Math.max(footR, b);
  }
  if (spec.tower) {
    const r = spec.tower === 'right';
    const c = r ? X1 + JUT + 11 : X0 - JUT - 11;
    tower(g, c, EAVE + 10, spec.towerH, spec.bell);
    footL = Math.min(footL, c - 9); footR = Math.max(footR, c + 9);
  }
  if (spec.wing) {
    const r = spec.wing === 'right';
    const a = r ? X1 + JUT - 1 : X0 - JUT - 25, b = r ? X1 + JUT + 25 : X0 - JUT + 1;
    wing(g, a, b, EAVE + 16);
    footL = Math.min(footL, a); footR = Math.max(footR, b);
  }
  if (spec.stall) stall(g, CX - 16, CX + 16, GROUND);
  if (spec.steps) steps(g, CX, 22, GROUND);
  // 옆으로 늘어난 만큼 **주춧돌을 하나로 잇는다.** 덩어리마다 따로 두면
  // 밑에 틈이 생겨서 두 채를 나란히 세워 놓은 것처럼 보인다 — 한 채의
  // 집은 한 장의 땅 위에 선다
  g.rect(footL, GROUND - 2, footR, GROUND, 'S');
  g.rect(footL, GROUND - 2, footR, GROUND - 1, 's');
  g.hline(footL - 1, footR + 1, GROUND, 'S');

  extrude(g);                                              // 뒤로 눕는 지붕
  if (spec.cupola) cupola(g, CX, RIDGE + 2);
  if (spec.vane) vane(g, CX, RIDGE - DEPTH + 2);
  // 굴뚝 — 뒤로 누운 지붕면 위. 발만 지붕에 붙어 있으면 윗동은 하늘로 나가도 된다
  // 굴뚝은 **불을 쓰는 집에만.**
  //
  // 아홉 채 전부에 꽂아 두었더니 굴뚝이 지붕의 기본 장식이 되어 버려서,
  // 정작 대장간·여관처럼 하루 종일 불을 때는 집이 눈에 안 띄었다.
  // 기본값을 「없음」으로 두고 필요한 집만 chim 을 적는다.
  if (spec.chim) {
    const big = spec.chim === 'big';
    // 지붕이 사다리꼴이 되면서 **용마루 뒤 윗면이 좁아졌다.** 예전 자리
    // (CX+14)에 그대로 두면 굴뚝 오른쪽 절반이 지붕 밖 허공에 뜬다.
    chimney(g, spec.chimneyX !== undefined ? spec.chimneyX : CX + 7,
      RIDGE - (big ? 33 : 30), RIDGE - (big ? 2 : 11), !big, big ? 11 : 7);
  }

  // ---- 살림 ----
  if (!spec.barnDoor) {                                    // 헛간 문에는 등이 없다
    lantern(g, CX - 13, MID + 8);
    lantern(g, CX + 9, MID + 8);
  }
  for (const [kind, at] of (spec.props || [])) {
    const px = at < 0 ? X0 - JUT + at : X1 + JUT + at;     // 음수=왼쪽 밖, 양수=오른쪽 밖
    if (kind === 'planter') planter(g, px, GROUND - 1);
    else if (kind === 'barrel') barrel(g, px, GROUND);
    else if (kind === 'crate') crate(g, px, GROUND, 7);
    else if (kind === 'crate2') crate(g, px, GROUND - 8, 6);
    else if (kind === 'hay') hay(g, px, GROUND);
    else if (kind === 'anvil') anvil(g, px, GROUND);
    else if (kind === 'trough') trough(g, px, GROUND);
    else if (kind === 'mailbox') mailbox(g, px, GROUND);
    else if (kind === 'lamppost') lamppost(g, px, GROUND);
    else if (kind === 'bench') bench(g, px, GROUND);
    else if (kind === 'fence') fence(g, px, px + 26, GROUND);
    else if (kind === 'books') pile(g, px, GROUND, 'book');
    else if (kind === 'parcel') pile(g, px, GROUND, 'parcel');
    else if (kind === 'coal') pile(g, px, GROUND, 'coal');
    else if (kind === 'notice') noticeboard(g, px, GROUND);
  }
  if (spec.flag) flag(g, X1 + JUT + 5, GROUND);
  if (spec.sign) sign(g, CX, spec.icon);
  if (spec.hang) hangSign(g, X1 + JUT - 14, MID - 10, spec.icon);   // 다락 벽 가운데
  if (spec.baskets) baskets(g, CX - 22, CX + 22, MID + 11);
  // 연장·약초는 **처마 밑에** 건다. 벽은 창과 문으로 이미 꽉 차서 걸 데가
  // 없었다 — 실제로도 이런 건 처마 밑에 매단다
  if (spec.hang2) wallHang(g, X0 - JUT + 3, EAVE + 4, spec.hang2);
  if (spec.sill) {                                               // 창턱에 늘어놓은 물건
    const sy = (spec.awning ? MID + 20 : MID + 16);
    sillGoods(g, CX - 26 - (spec.bigWin ? 4 : 0), CX - 14, sy, spec.sill);
    sillGoods(g, CX + 14, CX + 26 + (spec.bigWin ? 4 : 0), sy, spec.sill);
  }
  if (spec.soot) { soot(g, CX - 12, CX + 12, GROUND - 27); sparks(g, CX, GROUND - 10); }
  if (spec.bunting) bunting(g, X0 - JUT, X1 + JUT, EAVE + 3);
  if (spec.laundry) laundry(g, X0 - JUT + 3, X1 + JUT - 3, EAVE + 4);
  if (spec.pipes) { pipes(g, X0 + 3, EAVE + 4, GROUND - 4); pipes(g, X1 - 4, EAVE + 4, GROUND - 4); }
  if (spec.gull) gull(g, CX + 26, EAVE - 4);
  if (spec.fishLine) fishLine(g, X0 + 4, X1 - 4, MID - 26);
  if (spec.smoke) smoke(g, (spec.chimneyX !== undefined ? spec.chimneyX : CX + 7) + 3, RIDGE - 39);
  // 담쟁이는 **맨 마지막**에. 창틀·간판 위로 조금 넘어가야 자란 것처럼 보인다
  const iv = spec.ivy === undefined ? 2 : spec.ivy;
  // 덩어리가 붙은 쪽은 담쟁이를 **안으로 들인다.** 이음매 위에 얹으면
  // 가려 주기는커녕 「여기가 경계다」를 초록으로 표시하는 꼴이 된다
  const att = k => spec.tower === k || spec.lean === k || spec.wing === k;
  if (iv >= 1) ivy(g, att('left') ? X0 + 9 : X0 - JUT + 2, GROUND - 3, EAVE + 3);
  if (iv >= 2) ivy(g, att('right') ? X1 - 9 : X1 + JUT - 2, GROUND - 3, EAVE + 3);

  roughen(g);           // 기와 한 장씩 얹기 + 벽 줄눈·결
  bargeBoard(g, X0 - JUT - 3, X1 + JUT + 3, RIDGE, EAVE);  // 빗변 널은 기와 위에
  soften(g);            // 남은 90도 귀퉁이를 전부 깎는다
  g.outline();
  return g;
}


// ---- 아홉 채 ----
//
// 개성은 **몸통을 새로 그려서** 내지 않는다. 그러면 아홉 개의 다른 게임
// 건물이 된다. 같은 뼈대에 네 가지만 갈아 끼운다:
//
//   재료   지붕 색 사다리(roofPal) · 벽 색(wallPal) · 벽 쌓는 법(wall)
//   비례   폭(w) · 지붕 뾰족함(pitch)
//   설비   박공 장식(gable) · 차양(awning) · 굴뚝(chim) · 옥탑 · 깃발
//   살림   문 앞에 놓인 물건(props) — 무슨 집인지는 사실 이게 제일 크게 말한다
//
// props 의 숫자는 벽에서의 거리다. 음수면 왼쪽 벽 바깥, 양수면 오른쪽.
const KINDS = {
  // 우리집 — 간판이 없는 유일한 집. 대신 빨래가 널려 있다.
  // 「사람이 산다」를 말하는 데 빨랫줄만 한 게 없다
  house: { laundry: true, props: [['planter', -7], ['barrel', 2]] },

  // 잡화점 — 항아리 간판 + 만국기. 차양 밑에 바구니, 창턱에 병,
  // 벽에는 말린 약초 다발. 궤짝을 쌓아 뒀다
  house_general: { sign: true, icon: 'jar', hang: true, awning: 2, bigWin: true,
    baskets: true, bunting: true, dormer: true, ivy: 1,
    hang2: 'herb', sill: 'jar',
    props: [['crate', -13], ['crate2', -13], ['barrel', 3]] },

  // 목장 상회 — 소 간판. 벽에 굴레·우유통·밧줄, 앞에 울타리와 건초더미
  house_ranch: { sign: true, icon: 'cow', wall: 'plank', wallPal: 'warm',
    roofPal: 'moss', w: 7, pitch: -8, gable: 'loft', vane: true, ivy: 1,
    hang2: 'ranch',
    props: [['hay', -20], ['fence', 4]] },

  // 대장간 — 망치 간판. 화구 위 벽이 그을리고 불똥이 튄다. 벽에는
  // 망치·집게·편자, 앞에는 모루·담금질통·석탄더미. 옆에 작업 곁채
  house_smith: {
    sign: true, icon: 'hammer', hang: true, roofPal: 'ironblue',
    wallPal: 'stonewarm', chim: 'big', chimneyX: 38, smoke: true, forge: true,
    lean: 'right', ivy: 0, soot: true, hang2: 'smith',
    props: [['anvil', 26], ['trough', -16], ['coal', 40]] },

  // 수산시장 — 생선 간판. 벽에 그물, 처마 밑에 널어 말리는 생선,
  // 창턱에 생선, 지붕에 갈매기. 문 대신 판매대
  house_fish: { sign: true, icon: 'fish', hang: true, roofPal: 'slate',
    awning: 2, w: 9, pitch: -10, bigWin: true, stall: true, fishLine: true,
    ivy: 0, hang2: 'fish', sill: 'fish', gull: true,
    props: [['crate', -14], ['crate2', -14], ['crate', 3]] },

  // 여관 — 맥주잔 간판. **창에 불이 켜져 있다.** 창턱에 술병, 문 앞 긴 의자.
  // 부엌 아궁이가 하루 종일 도는 집이라 굴뚝을 둔 세 채 중 하나다
  house_inn: { sign: true, icon: 'mug', hang: true, w: 6, pitch: 5, win3: true,
    dormer: true, lit: true, sill: 'bottle', chim: 'far', smoke: true,
    props: [['bench', -20], ['barrel', 3]] },

  // 도서관 — 책 간판. 창에 불이 켜져 있고 앞에 가로등과 책더미.
  // 돌벽, 뾰족 지붕, 장미창, 왼쪽에 탑
  house_library: { sign: true, icon: 'book', wallPal: 'stone', pitch: 9,
    gable: 'rose', tower: 'left', lit: true, sill: 'book',
    props: [['lamppost', 6], ['books', 16]] },

  // 연금 연구소 — 플라스크 간판. 벽을 타고 오르는 배관, 창턱에 약병.
  // 청동 지붕에 옥탑 채광창. 담쟁이는 없다(깔끔해야 한다)
  house_lab: { sign: true, icon: 'flask', roofPal: 'copper', wallPal: 'pale',
    gable: 'vent', cupola: true, vane: true, ivy: 0,
    pipes: true, sill: 'flask', props: [['barrel', 3]] },

  // 우체국 — 편지 간판에 박공 시계, 깃발, 우체통, 쌓아 둔 소포
  house_post: { sign: true, icon: 'letter', wallPal: 'warm', gable: 'clock',
    flag: true, ivy: 1, props: [['mailbox', -12], ['parcel', 3]] },

  // ---- 고장의 작은 마을 (폭포골 · 큰나무 숲) ----
  //
  // 교진 마을 밖에도 사람이 산다. 다만 **가게가 아니라 사는 집**이다.
  // 그래서 장사 간판 대신 살림으로 말한다 — 빨래, 장작, 화분, 연기.
  //
  // 그림체는 교진 마을과 **똑같이** 둔다. 다른 고장이지 다른 세계가
  // 아니다. 대신 재료를 그 땅에 맞춘다:
  //   폭포골     늘 젖어 있다 -> 돌벽 · 이끼 낀 지붕 · 굴뚝 연기
  //   큰나무 숲  나무가 지천이다 -> 널벽(plank) · 따뜻한 나무색

  // 물방앗간 — 폭포골의 중심. 물가에 선 집이라 돌벽에 이끼 낀 지붕.
  // 문 앞에 곡식 자루와 궤짝이 쌓여 있다 (곁의 물레방아는 따로 돈다)
  house_mill: { wallPal: 'stone', roofPal: 'moss', w: 4, pitch: -6, storey: 4,
    gable: 'loft', vane: true, dormer: true, ivy: 2, lit: true,
    sign: true, icon: 'jar', hang: true,
    props: [['barrel', -15], ['crate', 4]] },

  // 물가 오두막 — 비가 잦은 골짜기라 지붕이 가파르고 굴뚝에서 연기가 난다
  house_creek: { wallPal: 'pale', roofPal: 'slate', w: -2, pitch: 6, storey: 2,
    chim: 'big', smoke: true, ivy: 1, laundry: true, dormer: true,
    props: [['planter', -10], ['barrel', 3]] },

  // 통나무집 — 큰나무 숲. 나무를 켜서 지은 집. 장작과 건초가 쌓여 있다
  house_cabin: { wall: 'plank', wallPal: 'warm', roofPal: 'moss', w: 2,
    pitch: -10, storey: 2, gable: 'loft', ivy: 2, laundry: true,
    props: [['crate', -13], ['hay', 4]] },

  // 그늘집 — 큰나무 그늘에 든 집이라 낮에도 창에 불이 켜져 있다.
  // 문 앞 긴 의자는 나무 밑에서 쉬어 가라는 자리다
  house_shade: { wallPal: 'warm', roofPal: 'clay', w: 3, pitch: 4, storey: 4,
    win3: true, lit: true, dormer: true, ivy: 2, laundry: true,
    props: [['bench', -19], ['planter', 4]] },

  // 마을 회관 — 마을에서 **제일 크고 제일 높은** 집. 여기만 종탑이 있다.
  //
  // 회관의 성격은 「여럿이 모인다」이다. 그래서 다른 집엔 없는 것만 모았다:
  //   종탑과 종     마을을 불러 모으는 물건
  //   박공 시계     마을의 시간이 여기서 나온다
  //   돌계단        문 앞이 넓게 열려 있다 (혼자 사는 집엔 계단이 없다)
  //   게시판        모두가 읽는 것
  //   만국기·깃발   행사가 열리는 집
  // 창은 전부 불이 켜져 있다 — 회관은 밤에도 사람이 있다.
  //
  // 회관만 **그림판이 크다** (164x168 -> 656x672). 같은 판에서 폭만 늘렸더니
  // 왼쪽 종탑과 오른쪽 깃발이 캔버스 밖으로 잘렸다 — 회관은 옆에 붙는 게
  // 많아서 판부터 키워야 한다. 층높이도 열두 칸 올려 창까지 같이 커진다.
  chief_house: { canvas: [178, 168], w: 14, storey: 12,
    sign: true, icon: 'bell', pitch: 10, win3: true,
    gable: 'clock', tower: 'left', towerH: 64, bell: true, steps: true, bunting: true,
    wing: 'right', flag: true, dormer: true, lit: true, wallPal: 'stone', ivy: 2,
    props: [['notice', -34], ['bench', -18]] },   // 의자는 종탑 밑에 — 깃발과 안 겹치게

  // 이장의 집 — 마을에서 **제일 오래된 집**. 처음부터 여기 있었고, 마을이
  // 크면 회관(chief_house)으로 다시 지어진다.
  //
  // 가게가 아니라 사람이 사는 집이라 장사 간판을 안 단다. 대신 마을 문장
  // (새싹)을 새긴 문패를 걸었다.
  //
  // 이장다움은 건물 자체보다 **문 앞에 모이는 것들**이 말한다. 다른 집에는
  // 하나도 안 붙는 것만 골랐다:
  //   게시판   마을 소식이 여기 붙는다 — 회관이 서기 전까지는 이 집이 그 일을 한다
  //   벤치     찾아온 사람이 앉아 기다린다
  //   깃발     마을 문장이 걸린 유일한 집
  //   돌계단   문 앞이 넓게 열려 있다 (혼자 사는 집엔 계단이 없다)
  //   화분     이장도 제 밭을 맨다
  //
  // 회칠한 벽에 이끼 낀 기와 — 낡았지만 손이 가 있는 집. 폭은 가게들보다
  // 좁게(-2) 잡아 「크지 않지만 중심인 집」으로 둔다. 창에는 불이 켜져
  // 있다: 마을 일이 밤까지 이어지는 집이다.
  // 지붕은 **낮게** 눕히고(-16) 벽을 올린다(층높이 +6). 뾰족함이 양수면 지붕이 집의 3분의 2를 먹어
  // 커다란 초록 고깔이 된다 — 벽이 안 보이면 문 앞에 뭘 놓아도 안 읽힌다.
  // 문 앞 물건은 왼쪽에 모았다. 오른쪽은 깃발 자리다 (겹쳤었다).
  chief_hut: { w: -2, pitch: -16, storey: 6, wallPal: 'pale', roofPal: 'moss',
    gable: 'loft', vane: true, dormer: true, lit: true, ivy: 2, steps: true,
    flag: true, sign: true, icon: 'sprout',
    props: [['notice', -12], ['bench', -26], ['planter', 14]] },

  // 농장의 축사 — 마을에서 홀로 옛 그림체(뿌연 잡음 널판)로 남아 있던
  // 마지막 건물. 붉게 칠한 널벽에 크림색 트림, 수레가 드나드는 X자
  // 두짝문, 지붕엔 다락문 — 실루엣과 색만으로 「헛간」이 나와야 한다.
  // 지붕은 잿빛(slate) — 빨강 벽이 주인공이다. 판은 다른 집과 같은
  // 기본 판 — 납작했던 몸집 자체가 이질감의 절반이었다.
  // (make_barn.js 는 이 항목으로 대체됐다)
  barn: { w: 10, pitch: -8, storey: 2,
    wall: 'plankk', wallPal: 'barnred', roofPal: 'slate',
    gable: 'loft', barnDoor: true, vane: true, ivy: 1,
    props: [['hay', -14], ['barrel', 3]] },
};

// 접지 그림자 — **집이 땅을 누르는 자국.**
//
// 참고 맵의 물건들이 땅에 「서 있는」 건 그림자 덕이다. 밑변 바로 아래로
// 반투명한 어둠이 서너 줄 깔리고 좌우로 조금 번진다 — 이게 없으면
// 어떤 집이든 종이 인형처럼 뜬다. 마당 살림(P.ground)과 같은 규칙을
// 건물에도 편다. 밑변에서 멀수록 옅어진다.
function groundShadow(im) {
  const W2 = im.width, H2 = im.height;
  const opaque = (x, y) => x >= 0 && x < W2 && y >= 0 && y < H2
    && im.data[(y * W2 + x) * 4 + 3] > 128;
  // 밑변 찾기 — 각 열에서 제일 아래 불투명 픽셀
  for (let x = 0; x < W2; x++) {
    let base = -1;
    for (let y = H2 - 1; y >= 0; y--) if (opaque(x, y)) { base = y; break; }
    if (base < 0 || base < H2 * 0.7) continue;             // 허공 장식은 건너뛴다
    for (let k = 1; k <= 8; k++) {
      const y = base + k;
      if (y >= H2 || opaque(x, y)) continue;
      const a = Math.max(0, 96 - k * 11);
      const i = (y * W2 + x) * 4;
      if (im.data[i + 3] > 0) continue;
      im.data[i] = 30; im.data[i + 1] = 26; im.data[i + 2] = 34;
      im.data[i + 3] = a;
    }
  }
  return im;
}

let n = 0;
for (const [name, spec] of Object.entries(KINDS)) {
  const tag = STYLE === 'soft' ? '' : STYLE + '_';
  fs.writeFileSync(OUT + PRE + tag + name + '.png',
    PNG.sync.write(groundShadow(build(spec).render())));
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
