// 마당에 **세워 두는 것들** — 화로 · 모루 · 여물통 · 장작더미 · 그물 틀 …
//
// 왜 그리는가 —
//   가게 마당에 광석·못·천 따위를 늘어놓고 있었다. 그런데 그것들은 전부
//   **가방 아이콘**이다. 32px 네모 안에 물건 하나가 딱 들어차게 그린 그림이라,
//   땅에 놓으면 「거기 서 있는 물건」이 아니라 「누가 떨어뜨리고 간 물건」으로
//   보인다. 밑변도 그림자도 없으니 바닥에 붙지도 않는다.
//
//   마당에 놓을 것은 아이콘이 아니라 **살림**이다. 모루는 그루터기에 얹혀
//   있고, 여물통에는 물이 담겨 있고, 장작은 쌓여 있다. 그래서 따로 그린다.
//
// 그리는 규칙은 건물·바닥과 같다 —
//   톤 사다리   재료마다 예닐곱 단. 한 자로 재야 물건들이 한 바닥에 놓인다
//   밑그림자    바닥에 닿는 자리에 반투명 그늘. 이게 없으면 물건이 뜬다
//
// ---- **윗면을 그린다** (이제부터 만드는 것은 전부) ----
//
// 화면은 정면이 아니라 **비스듬히 위에서 내려다보는** 각이다. 그런데 한동안
// 물건을 정면(입면도)으로만 그렸다 — 옆에서 본 판때기라, 같은 화면의
// 집·바닥과 각이 안 맞아 종이를 오려 세운 것처럼 보였다.
//
// 위에서 보면 **윗면이 보인다.** 면이 있는 것에는 반드시 두 면을 그린다:
//   윗면   두 줄. 제일 밝다 (하늘을 보고 있다). 뒤 모서리는 한 칸 안으로
//   정면   그 아래. 두 단 어둡다
//   턱     맨 아랫줄. 네 단 어둡다 (땅에 닿는 자리)
// 기둥·가로대·궤짝·선반 — 예외 없이 이 규칙을 따른다 (topFace 로 찍는다)
//
// 도트 크기: 논리 한 칸 = 4px. 게임에서 0.5배로 얹으므로 화면에서 2px —
// 사람·집·바닥과 정확히 같다 (object_nodes 가 `deco_` 살림을 0.5로 못박는다).
//
// 숫돌과 통은 그렸다가 **뺐다.** 화면에서 열여섯 도트로 줄어들면 숫돌은
// 벽시계가 되고 통은 쓰레기통이 된다 — 무엇인지 모를 물건은 마당을
// 어지럽힐 뿐이다. 한 칸에 담기려면 **윤곽만으로 이름이 나와야** 한다.
//
// **화로만 여러 장이다.** 불은 흔들려야 불이다. 네 장을 돌려 찍는다
// (main.LANDMARK_FRAMES 에 {"deco_forge": 4} 로 적어 두면 알아서 돈다).
//
// 실행:  node make_props.js            -> ref/proposed_deco_*.png (제안만)
//        node make_props.js --install  -> sprites/ 에 넣는다
//                                         (뒤에 python3 make_import.py)
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');
const S = 4;                     // 논리 한 칸 = 원본 4px

function h(x, y, k) {
  let n = (x * 73856093) ^ (y * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// ---- 톤 사다리 ----
//
// **건물 그림(make_buildings.js 의 PAL)에서 그대로 가져온다.**
//
// 처음에는 「비슷한 색」으로 눈대중해 따로 잡았다. 그러자 한 마당 안에서
// 두 벌의 그림이 됐다 — 집은 따뜻한 갈색 목재에 중성 회색 돌인데, 마당의
// 살림은 더 노랗고 더 푸르렀다. 물건 하나하나는 잘 그려도 **같이 놓으면
// 따로 논다.** 색줄기가 다르면 같은 세계가 아니다.
//
// 이제 건물이 쓰는 값을 축으로 삼고, 그 사이를 메워 사다리를 늘린다.
// 늘리기만 하고 축은 안 옮긴다 — 그래야 집과 마당이 한 벌이 된다.
//   목재  PAL u(200,128,52) · t(156,88,32) · T(92,48,20)
//   돌    PAL p3(216,210,198) · s(138,132,126) · S(96,92,88) · p5(88,84,80)
//   불    PAL F(250,140,50) · F2(206,70,24)
//   윤곽  PAL O(32,24,28) — **차가운 먹색**이다. 따뜻한 갈색 선을 쓰면
//         집의 선과 나란히 놓였을 때 살림 쪽만 붉게 뜬다
const W = [[232, 168, 92], [200, 128, 52], [178, 108, 42], [156, 88, 32],
           [124, 68, 26], [92, 48, 20], [62, 32, 14]];
// 돌 — **대장간 벽과 같은 돌**이다. 눈대중으로 잡은 밝은 회색을 썼더니
// 마당에 놓았을 때 화로만 하얗게 떠서, 흙 마당에도 회색 집에도 안 붙는
// 물건이 됐다. 이제 세 칸을 건물 팔레트에 못 박는다:
//   ST[0] = WALL_PAL.stone.i (192,188,180)   벽의 제일 밝은 돌
//   ST[2] = WALL_PAL.stone.k (154,150,144)   벽의 기본 돌
//   ST[5] = WALL_PAL.stone.K ( 98, 94, 90)   벽의 그늘 돌
// 나머지는 그 사이를 메운다. 축을 옮기지 않고 사다리만 늘리는 규칙 그대로다
// 못 박은 세 칸 사이는 **마당 쪽으로 아주 조금 따뜻하게** 메운다. 순회색
// 사다리를 썼더니 갈색 흙 마당 한복판에 차가운 회색 섬이 하나 떠 있었다
const ST = [[222, 212, 192], [200, 190, 170], [178, 168, 148], [156, 146, 128],
            [136, 126, 110], [118, 108, 94], [94, 86, 74], [66, 60, 52]];
// 쇠 — 돌과 **같은 명도줄기**에 푸른 기만 아주 조금. 예전에는 확실히
// 푸르게 밀었는데, 집의 회색 돌 옆에 놓으니 모루만 다른 금속으로 보였다
const IR = [[204, 206, 210], [162, 164, 170], [120, 122, 128], [84, 86, 92],
            [52, 54, 60]];
// 불 — PAL 의 F·F2 를 가운데 두고 위아래로 한 단씩
const FI = [[255, 238, 182], [252, 196, 84], [250, 140, 50], [206, 70, 24],
            [148, 38, 18]];
// 지푸라기·마대는 간판색(b·B) 줄기다. 노란 짚색을 따로 잡았더니 마당에서
// 혼자 쨍했다
const STRAW = [[232, 204, 150], [206, 176, 122], [172, 142, 92], [130, 104, 62]];
const SACK = [[214, 186, 132], [186, 158, 108], [150, 122, 78], [112, 90, 56]];
const NET = [[242, 234, 214], [196, 186, 162], [148, 138, 116]];
// 잎·꽃·유리·물은 PAL 값 그대로
const LEAF = [[132, 194, 88], [84, 156, 60], [44, 96, 40]];
const BLOOM = [[200, 62, 48], [252, 214, 120], [248, 244, 224]];
const AQUA = [[168, 216, 248], [72, 148, 200], [36, 84, 140]];
const PAPER = [[242, 234, 214], [206, 176, 122], [150, 122, 78]];
const BOOK = [[200, 62, 48], [72, 148, 200], [84, 156, 60], [200, 150, 60]];
const OUT = [32, 24, 28];
const SHADOW = [30, 26, 34, 78];

// ---- 마당 살림의 **덩치** ----
//
// 살림은 도트 격자에 그리고 한 도트를 4px로 찍는다 — 화면에서 0.5배로
// 얹으니 도트 하나가 2px, 사람·집·바닥과 같은 자다. 문제는 **격자가
// 작았다**는 것: 자루가 18x14칸(화면 36x28px)이면 키 96px인 사람 옆에서
// 발치의 돌멩이만 하다. 마당에 내놓은 짐은 사람 허리께는 와야 짐이다.
//
// 도트를 크게 찍으면(3px) 세계와 자가 어긋나므로, **격자 자체를 키운다.**
// 그리는 코드는 그대로 두고 P가 한 칸을 K칸으로 펴서 받는다 — 칸을 정확히
// 나눠 덮으므로 틈도 겹침도 없다. 화로·모루는 이미 크게 그려 뒀으니 뺀다.
let PK = 1;

class P {
  constructor(w, hh) {
    this.K = PK;
    this.w = Math.round(w * PK); this.h = Math.round(hh * PK);
    this.d = Array.from({ length: this.h }, () => new Array(this.w).fill(null));
  }
  // 격자 좌표 그대로 찍는다 (윤곽선·마무리 패스가 쓴다)
  raw(x, y, c) {
    if (!c) return;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.d[y][x] = c;
  }
  px(x, y, c) {
    if (!c) return;
    x = Math.round(x); y = Math.round(y);
    if (this.K === 1) { this.raw(x, y, c); return; }
    // 한 칸이 차지할 자리를 반올림 경계로 잘라 덮는다 (틈 없는 타일링)
    const K = this.K;
    const x0 = Math.round(x * K), x1 = Math.round((x + 1) * K) - 1;
    const y0 = Math.round(y * K), y1 = Math.round((y + 1) * K) - 1;
    for (let yy = y0; yy <= y1; yy++) for (let xx = x0; xx <= x1; xx++) this.raw(xx, yy, c);
  }
  get(x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return null;
    return this.d[y][x];
  }
  // 이미 찍은 칸을 **지운다** — 수레바퀴 살 사이처럼 뒤가 비쳐야 하는 자리
  clr(x, y) {
    x = Math.round(x); y = Math.round(y);
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.d[y][x] = null;
  }
  hline(x0, x1, y, c) { for (let x = x0; x <= x1; x++) this.px(x, y, c); }
  vline(x, y0, y1, c) { for (let y = y0; y <= y1; y++) this.px(x, y, c); }
  rect(x0, y0, x1, y1, c) {
    for (let y = y0; y <= y1; y++) this.hline(x0, x1, y, c);
  }
  // 속을 채운 타원 — 통의 배, 장작의 마구리, 바닥 그늘에 두루 쓴다
  disc(cx, cy, rx, ry, c) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++)
        if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0) this.px(x, y, c);
  }
  // ---- 바닥 그늘 ----
  //
  // 한 가지 농도의 타원 한 장으로는 물건이 **회색 받침 위에 놓인** 꼴이
  // 된다. 실제 그늘은 물건이 땅에 닿은 자리가 제일 짙고 밖으로 갈수록
  // 빠르게 옅어지며, 해가 왼쪽 위에 있으니 **오른쪽 아래로 눕는다.**
  //
  //   ① 세 단  안(짙다) · 중간 · 가장자리(옅다). 단이 있어야 부드럽다
  //   ② 기울기  오른쪽으로 밀어 눕힌다 — 곧은 타원은 받침이고 기운
  //             타원이라야 그림자다
  //   ③ 가장자리 흐트러뜨림  제일 바깥 단은 절반만 찍는다. 매끈한
  //             타원 테두리가 보이면 그 순간 다시 「깔아 둔 판」이 된다
  ground(cx, cy, rx, ry) {
    const skew = rx * 0.20;
    const A = [[0.42, 108], [0.74, 74], [1.0, 42]];
    for (let y = Math.floor(cy - ry - 1); y <= Math.ceil(cy + ry + 1); y++)
      for (let x = Math.floor(cx - rx - skew - 1); x <= Math.ceil(cx + rx + skew + 1); x++) {
        const d = ((x - cx - skew) / rx) ** 2 + ((y - cy) / ry) ** 2;
        if (d > 1.0) continue;
        let a = 0;
        for (const [t, v] of A) if (d <= t * t) { a = v; break; }
        if (!a) a = 42;
        if (d > 0.80 * 0.80 && h(x, y, 199) < 0.42) continue;   // 테두리를 허문다
        this.px(x, y, [30, 26, 34, a]);
      }
  }
  render() {
    const im = new PNG({ width: this.w * S, height: this.h * S });
    im.data.fill(0);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      const a = c.length > 3 ? c[3] : 255;
      for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
        const i = ((y * S + sy) * this.w * S + (x * S + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2];
        im.data[i + 3] = a;
      }
    }
    return im;
  }
}

// ---- 되풀이해 쓰는 조각들 ----

// 널판 한 장 — 윗변은 빛, 속에 결, 아랫변은 턱. 나무는 다 이 규칙이다
function plank(g, x0, x1, y0, y1, seed, pal) {
  const t = pal || W;
  g.rect(x0, y0, x1, y1, t[3]);
  g.hline(x0, x1, y0, t[1]);
  g.hline(x0, x1, y1, t[5]);
  for (let x = x0; x <= x1; x++) {
    if (h(x, y0, seed) < 0.24) g.px(x, y0 + 1, t[4]);
    if (h(x, y1, seed + 3) < 0.16) g.px(x, y1 - 1, t[2]);
  }
}

// 쌓은 돌 한 덩이 — 켜마다 반 칸씩 어긋나고 줄눈이 한 칸
function stonework(g, x0, x1, y0, y1, seed, pal) {
  const t = pal || ST;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const course = Math.floor((y - y0) / 3);
    const col = Math.floor((x - x0 + (course % 2) * 2) / 4);
    let i = 1 + Math.floor(h(col, course, seed) * 3.0);
    if ((y - y0) % 3 === 0) i -= 1;                 // 윗줄 = 빛
    if ((y - y0) % 3 === 2) i += 2;                 // 아랫줄 = 줄눈
    if ((x - x0 + (course % 2) * 2) % 4 === 3) i += 2;
    g.px(x, y, t[clamp(i, 0, t.length - 1)]);
  }
}


// ---- 윤곽선 ----
//
// 바닥이 무슨 색이든 물건이 **떠 보여야** 한다. 자갈 마당에 회색 화로를
// 얹었더니 바닥과 한 덩어리가 됐다 — 색만 바꿔서는 다음번 바닥에서
// 또 같은 일이 난다. 건물 그림이 굵은 윤곽선을 쓰는 것과 같은 이유다.
//
// 그늘(반투명)은 물건이 아니므로 선을 안 두른다. 이미 그늘이 깔린 칸도
// 건드리지 않는다 — 밑변에 새까만 테가 둘리면 물건이 땅에서 다시 뜬다
function outline(g) {
  const add = [];
  for (let y = 0; y < g.h; y++) for (let x = 0; x < g.w; x++) {
    if (g.d[y][x]) continue;
    let near = false;
    for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
      const c = g.get(x + dx, y + dy);
      if (c && c.length < 4) { near = true; break; }
    }
    if (near) add.push([x, y]);
  }
  for (const [x, y] of add) g.raw(x, y, OUT);
  return g;
}

// ---- 윗면 ----
//
// 네모난 것 위에 얹는 두 줄. yFront 는 **정면이 시작하는 줄**이고,
// 그 위 두 줄이 윗면이다. 뒤 모서리(제일 위)는 한 칸씩 안으로 들어가
// 「멀어지는 면」이 된다.
// depth = 윗면 줄 수. **이 값이 곧 카메라 각도다.**
//
// 두 줄로 그렸을 때는 「살짝 기울인 정면도」였다 — 여전히 평면적이라는
// 말을 들었다. 위에서 내려다볼수록 윗면은 깊어지고 정면은 얇아진다.
// 네 줄쯤 되면 「올려다보는 물건」이 아니라 「내려다보는 물건」이 된다.
//
// 뒤로 갈수록 한 칸씩 좁아져야 면이 **멀어진다**. 같은 폭으로 쌓으면
// 그건 깊은 윗면이 아니라 그냥 밝은 벽이다.
function topFace(g, x0, x1, yFront, pal, depth) {
  const t = pal || W;
  const d = depth || 9;
  const dk = i => t[Math.min(t.length - 1, i)];
  for (let k = d; k >= 1; k--) {
    // **좁아지는 폭은 줄 수가 아니라 물건 폭이 정한다.**
    //
    // 줄마다 꼬박꼬박 한 칸씩 좁혔더니, 깊은 면일수록 뒤가 반토막이 나서
    // 「위에서 본 판」이 아니라 **치마**가 됐다. 뒤로 가서 좁아지는 건
    // 원근이지 원뿔이 아니다 — 맨 뒤에서 폭의 13%쯤이면 충분하다.
    const inset = Math.round((k / d) * (x1 - x0) * 0.20);
    // 그리고 **한 면 안에서도 톤이 흐른다.** 맨 뒤 두 줄만 어둡게 했더니
    // 나머지가 통짜 밝은 띠라서, 눕는 면이 아니라 밝게 칠한 벽으로 보였다.
    // 앞에서 뒤로 네 단을 흘리면 면이 저 혼자 멀어진다
    const f = (d - k) / Math.max(1, d - 1);    // 0(제일 먼 줄) ~ 1(제일 앞줄)
    const tone = f < 0.14 ? dk(3) : (f < 0.34 ? dk(2) : (f < 0.56 ? dk(1) : t[0]));
    g.hline(x0 + inset, x1 - inset, yFront - k, tone);
  }
  g.px(x1, yFront - 1, dk(1));                 // 오른쪽 모서리
  // **앞 모서리** — 윗면과 정면이 꺾이는 자리에 한 줄 진하게 긋는다.
  // 이 한 줄이 없으면 밝은 띠 하나로 뭉개져서, 윗면을 그려 놓고도
  // 「위에서 본다」가 안 읽힌다. 두 면은 **선으로** 갈린다
  g.hline(x0, x1, yFront, dk(5));
}


// 돌을 깐 윗면 — topFace 와 같은 면이지만 **줄눈이 있다.**
//
// 열네 줄짜리 상판을 민 색으로 깔았더니 화로 위에 매끈한 흰 판이 얹혔다.
// 넓은 면일수록 재질이 없으면 종잇장이 된다. 정면 벽이 돌인데 윗면만
// 민 색이면 두 면이 다른 물건이 된다 — 눕는 면에도 같은 돌을 깐다.
//
// 줄눈은 **뒤로 갈수록 촘촘해진다.** 같은 간격으로 그으면 면이 누워 있지
// 않고 서 있는 것처럼 보인다 — 줄 간격이 곧 기울기다 (기와 켜와 같은 규칙).
function stoneTop(g, x0, x1, yFront, pal, depth) {
  const t = pal || ST;
  const d = depth || 9;
  const dk = i => t[Math.min(t.length - 1, i)];
  const cx = (x0 + x1) / 2, full = Math.max(1, x1 - x0);
  const seam = new Set();
  let gap = 5.5, at = 0;                         // 큰 돌(켜 5)에 맞춘 간격
  while (at < d) { at += Math.max(1, Math.round(gap)); seam.add(at); gap *= 0.72; }
  for (let k = d; k >= 1; k--) {
    const inset = Math.round((k / d) * full * 0.20);
    const f = (d - k) / Math.max(1, d - 1);
    const base = f < 0.14 ? 3 : (f < 0.34 ? 2 : (f < 0.56 ? 1 : 0));
    const a = x0 + inset, b = x1 - inset;
    const shrink = Math.max(0.2, (b - a) / full);
    for (let x = a; x <= b; x++) {
      // 소실점 기준으로 되돌린 좌표 — 뒤로 가도 줄눈이 **같은 돌에** 이어진다
      const u = Math.round((x - cx) / shrink) + 400;
      // **다 그리지 않는다** — 윗면도 평평하게 두고 드문 획만.
      // 획은 켜 줄에서만, 서너 돌에 하나
      const r = h(Math.floor(u / BKW), k, 51);
      let i = base;
      const ru = ((u % BKW) + BKW) % BKW;
      if (r < 0.30 && seam.has(k) && ru >= 1 && ru <= 4) i += 1;
      g.px(x, yFront - k, dk(Math.max(0, i)));
    }
  }
  // 맨 뒤 한 줄은 **밝게** — 면이 끝나는 자리다. 이 선이 없으면 넓은
  // 윗면이 뒤쪽 물건과 붙어서 어디까지가 이 면인지 안 보인다
  const bIn = Math.round(full * 0.13);
  g.hline(x0 + bIn, x1 - bIn, yFront - d, dk(1));
  g.px(x1, yFront - 1, dk(1));
  g.hline(x0, x1, yFront, dk(5));              // **앞 모서리**
}


function hoop(g, x0, x1, y) {
  g.hline(x0, x1, y, IR[1]);
  g.hline(x0, x1, y + 1, IR[3]);
}

// ---- 화로 ----
//
// 대장간 곁에 서서 **불이 보이는** 것. 집만큼 커야 한다 — 참고 그림의
// 화로는 초가지붕 집 옆에 나란히 선 **돌탑**이다. 처음에 스물넉 도트짜리
// 납작한 상자로 그렸더니 「집 옆의 작은 굴뚝」이었고, 서른두 도트로 키운
// 뒤에도 여전히 **정면 한 장**이라 평면적이었다.
//
// 부피는 세 가지로 낸다.
//   ① 면이 셋   왼쪽(빛) · 정면 · 오른쪽(그늘). 오른쪽 한 겹이 있어야
//               「돌아간 모서리」가 생기고 그제야 덩어리로 보인다
//   ② 턱마다 윗면  받침 · 어깨 · 갓. 가로로 꺾이는 자리마다 윗면 두 줄과
//               앞 모서리 한 줄 (topFace)
//   ③ 좁아진다  굴뚝은 위로 갈수록 좁아진다. 곧은 통은 파이프고,
//               좁아지는 것이 굴뚝이다
//
// 돌은 **집과 같은 회색 돌**(ST)이다. 대장간 본채가 회색 돌집이라, 곁의
// 화로가 벽돌이면 둘이 남남으로 보인다. 아가리 둘레만 그을려 검다.
// 판을 34x52 -> 44x64 -> **48x70** 으로 키워 왔다. 화면에서 96x140 —
// 가로 세 칸, 세로 네 칸 반. 대장간 마당의 주인공이니 이만해야 한다.
//
// 폭 48은 **집 그림에 안 먹히는 한계**다. 부지 x=7 칸에 놓으므로 왼쪽
// 끝이 딱 x=6.0 — 집 그림(x -1..+5)이 끝나는 자리에 닿는다. 더 넓히려면
// PLOT_DECOR 의 자리를 먼저 옮겨야 한다.
const FW = 48, FH = 70, FCX = 24;
function flame(g, cx, base, hgt, f, seed) {
  for (let k = 0; k < hgt; k++) {
    const t = k / hgt;
    const wide = (1 - t) * 4.8 + Math.sin((k * 0.58) + f * 1.9 + seed) * 1.2;
    const wd = Math.max(0, Math.round(wide));
    const sway = Math.round(Math.sin(k * 0.38 + f * 1.7 + seed) * 2.2 * t);
    for (let dx = -wd; dx <= wd; dx++) {
      let c;
      if (Math.abs(dx) === wd) c = t > 0.55 ? FI[4] : FI[3];
      else if (t > 0.62) c = FI[2];
      else if (t > 0.28) c = FI[1];
      else c = Math.abs(dx) <= 1 ? FI[0] : FI[1];
      g.px(cx + dx + sway, base - k, c);
    }
  }
}

// 돌탑 한 켜 — **건물의 boulderCourse 와 같은 큰 돌.**
//
// 4x3 잔돌로 쌓았더니 화로만 자글거려서, chunky 로 바꾼 대장간 본채와
// 딴 그림이 됐다. 같은 자로 잰다: 돌 8~10 x 5, 이음매 자리는 켜마다
// 흔들리고, 귀퉁이 네 점을 줄눈색으로 깎아 돌이 둥글다.
// 톤은 뭉치 단위로만 — 사람 손은 균일한 난수를 못 찍는다.
// 화로의 벽돌 — **집 굴뚝과 같은 벽돌이 그을린 것.** 회색 돌로 쌓았더니
// 매끈한 가마솥이었다. 화로는 벽돌 가마다: 붉은 벽돌 일곱 단 사다리,
// 위로 갈수록·아가리 곁일수록 그을어 어둡다.
const FG = [[206, 140, 96], [176, 110, 70], [146, 90, 58], [116, 68, 44],
            [88, 52, 34], [62, 36, 24], [40, 24, 18]];

// 벽돌 한 켜 — 집(brickCourse)과 같은 자(6x3), 켜마다 반 장 어긋난다.
// **거칠게**: 장마다 색이 세 단까지 벌어지고, 드문 장은 이가 빠져
// 줄눈색 구멍이 나고, 왼쪽 두 칸은 빛 / 오른쪽 두 칸은 돌아간 그늘
const BKW = 6, BKH = 3;
function brickRow(g, x0, x1, y, seed, lift) {
  for (let x = x0; x <= x1; x++) {
    const course = Math.floor(y / BKH);
    const u = x + (course % 2) * (BKW >> 1);
    const col = Math.floor(u / BKW);
    const ru = ((u % BKW) + BKW) % BKW, ry = y % BKH;
    const rc = h(col, course, seed);
    let i = 1 + lift;
    if (rc < 0.20) i -= 1; else if (rc > 0.60) i += 1;
    if (rc > 0.90) i += 2;                          // 몹시 그은 장
    if (x <= x0 + 1) i -= 1;                        // 왼쪽 = 빛
    else if (x >= x1 - 1) i += 2;                   // 오른쪽 = 돌아간 면
    if (ry === 0 && ru > 0) i -= 1;                 // 장의 윗변 = 빛 (도드라진다)
    if (ry === BKH - 1 || ru === 0) i = 4 + (lift > 0 ? 1 : 0);   // 줄눈
    if (h(col * 5 + 2, course * 7 + 3, seed) < 0.05) i = 4;       // 이 빠진 장
    g.px(x, y, FG[clamp(i, 0, 6)]);
  }
}

// 가장자리 흔들림 — 곧은 자로 선 벽은 판금이다. 두 줄마다 한 칸씩
// 들쭉날쭉해야 손으로 쌓은 가마가 된다
function jag(y, seed) { return h(y >> 1, 3, seed) < 0.22 ? 1 : 0; }

// ---- 막돌 쌓기 (rubble) ----
//
// 참고 그림의 가마는 줄 맞춘 벽돌이 아니라 **크기와 모양이 제각각인
// 막돌**이다. 격자로는 흉내가 안 난다 — 씨앗점을 흩뿌리고 픽셀마다
// 제일 가까운 씨앗을 찾으면(보로노이) 돌 하나하나가 다각형 덩이가 된다.
//   줄눈   첫째·둘째 씨앗까지의 거리가 비슷한 자리 = 두 돌이 만나는 골
//   낯빛   돌(씨앗)마다 한 색. 푸른 잿빛에 드문드문 **따뜻한 돌**이 섞인다
//   윗변   줄눈 바로 아래 한 줄이 밝다 — 돌이 도드라진다
// 돌은 가로로 길다 (dy 를 1.25배로 눌러 잰다). 사람이 눕혀 쌓으니까.
const CST = [[212, 214, 224], [184, 188, 202], [156, 160, 178], [128, 132, 152],
             [102, 106, 128], [78, 82, 104], [58, 60, 82], [40, 42, 60]];
// 씨앗 격자 한 칸 — 돌의 평균 크기다. 9로 잡았더니 몸통 폭이 돌 두 개
// 만해서 실루엣이 울퉁불퉁 뭉개졌다. 돌은 구조의 오분의 일쯤이어야
// 구조가 돌을 이긴다
const RC = 7;
function rubbleSeed(ci, cj, seed) {
  return [ci * RC + 1 + h(ci * 7 + 1, cj * 3 + 5, seed) * (RC - 2),
          cj * RC + 1 + h(ci * 3 + 4, cj * 7 + 2, seed) * (RC - 2)];
}
function rubble(g, mask, seed, lift) {
  const W2 = g.w;
  for (let y = 0; y < g.h; y++) for (let x = 0; x < g.w; x++) {
    if (!mask[y] || !mask[y][x]) continue;
    const ci0 = Math.floor(x / RC), cj0 = Math.floor(y / RC);
    let d1 = 1e9, d2 = 1e9, id = 0;
    for (let cj = cj0 - 1; cj <= cj0 + 1; cj++) for (let ci = ci0 - 1; ci <= ci0 + 1; ci++) {
      const sp = rubbleSeed(ci, cj, seed);
      const dx = x - sp[0], dy = (y - sp[1]) * 1.4;
      const d = dx * dx + dy * dy;
      if (d < d1) { d2 = d1; d1 = d; id = ci * 131 + cj * 61; }
      else if (d < d2) d2 = d;
    }
    const gap = Math.sqrt(d2) - Math.sqrt(d1);
    if (gap < 1.15) { g.px(x, y, CST[6]); continue; }        // 줄눈
    const rc = h(id, 17, seed);
    let t = 3 + (lift || 0);
    if (rc < 0.24) t -= 1; else if (rc > 0.78) t += 1;
    if (x > W2 * 0.74) t += 1;                               // 오른쪽 = 돌아간 면
    // 따뜻한 돌 — 여덟에 하나쯤. 잿빛 한 벌이면 차갑기만 하다
    const warm = h(id, 29, seed) < 0.13;
    if (warm) { g.px(x, y, ST[clamp(t, 0, 7)]); continue; }
    g.px(x, y, CST[clamp(t, 0, 7)]);
  }
  // 윗변 빛 — 줄눈 바로 아래 한 줄. 채운 뒤에 훑어야 정확하다
  for (let y = 1; y < g.h; y++) for (let x = 0; x < g.w; x++) {
    if (!mask[y] || !mask[y][x]) continue;
    const c = g.get(x, y), cu = g.get(x, y - 1);
    if (c === CST[6] || cu !== CST[6]) continue;
    let t = -1;
    for (let i = 0; i < CST.length; i++) if (CST[i] === c) t = i;
    if (t > 0) g.px(x, y, CST[t - 1]);
  }
}


// 마당 흙이 튄 색 — **바닥 그림(make_ground.js)의 EARTH 사다리 그대로.**
// 눈대중으로 「갈색쯤」을 잡으면 화로 발치만 딴 흙이 된다
const GRIME = [[112, 88, 64], [92, 70, 50], [72, 54, 38]];
function weatherStone(g, seed, top) {
  const y0 = top || 0;
  const isStone = c => {
    if (!c || c.length > 3) return false;
    for (const t of ST) if (t === c) return true;
    for (const t of FG) if (t === c) return true;
    for (const t of CST) if (t === c) return true;
    return false;
  };
  const darker = c => {
    for (let i = 0; i < ST.length - 1; i++) if (ST[i] === c) return ST[i + 1];
    for (let i = 0; i < FG.length - 1; i++) if (FG[i] === c) return FG[i + 1];
    for (let i = 0; i < CST.length - 1; i++) if (CST[i] === c) return CST[i + 1];
    return c;
  };
  // ① 흘러내린 줄 — 여섯 칸에 한 줄쯤. 시작한 자리부터 아래로 이어진다.
  // 곁의 돌집이 갖고 있는 자국이라, 이게 없으면 화로만 갓 쌓은 새것이다
  // 흘러내린 줄은 **선 면에만** — 눕는 면(상판) 위로 그으면 빗물이 아니라
  // 상 위에 쏟은 물이 된다
  for (let x = 0; x < g.w; x++) {
    if (h(x, 77, seed) > 0.18) continue;
    let run = 0;
    for (let y = y0; y < g.h; y++) {
      if (!isStone(g.d[y][x])) { run = 0; continue; }
      if (++run > 2 && h(x, y, 79) < 0.7) g.px(x, y, darker(g.d[y][x]));
    }
  }
  // ② 밑동 흙탕물 — **물건을 땅에 붙이는 건 그림자가 아니라 이것이다.**
  //
  // 비가 마당 흙을 튀겨 아래 한 뼘을 늘 더럽힌다. 잔 확률로 뿌리면
  // 후추가 되므로, 큰 칸(2x2)으로 자리를 먼저 정한다.
  // 이끼는 안 넣는다 — 늘 불이 도는 물건이라 폐허로 보였다.
  const B = 13;
  for (let y = g.h - B; y < g.h; y++) for (let x = 0; x < g.w; x++) {
    if (!isStone(g.d[y][x])) continue;
    const near = (y - (g.h - B)) / B;                 // 0(위) ~ 1(바닥)
    if (h(x >> 1, y >> 1, 83) > near * near * 1.15) continue;
    const v = h(x, y, 87);
    g.px(x, y, GRIME[v < 0.4 ? 0 : (v < 0.78 ? 1 : 2)]);
  }
}

function forge(f) {
  const g = new P(FW, FH);
  g.ground(FCX, 68, 21, 3.6);

  // ---- 뼈대 — 병이 아니라 벽난로다 ----
  //
  // 여태 「넓은 갓 + 좁은 목 + 넓은 몸」의 병 모양으로 쌓아 왔는데,
  // 참고 그림의 가마는 다르다: **넓은 화덕 위에 후드가 바로 얹히고,
  // 받침켜 계단으로 좁아지며 두꺼운 굴뚝으로 오른다.** 앞면이 한 판으로
  // 흐르는 벽난로꼴이라, 아가리가 구조의 주인공이 된다.
  const mkMask = () => Array.from({ length: FH }, () => new Array(FW).fill(false));
  const span = (m, y, x0, x1) => { for (let x = Math.max(0, x0); x <= Math.min(FW - 1, x1); x++) m[y][x] = true; };
  const front = mkMask(), top = mkMask();

  // 굴뚝 왕관 — 맨 위가 한 번 벌어지고, 윗면과 아가리가 보인다
  for (let y = 1; y <= 3; y++) span(top, y, 14 + (3 - y), 33 - (3 - y));
  for (let y = 4; y <= 6; y++) span(front, y, 13, 34);
  // 굴뚝 — 두껍다. 참고 그림의 굴뚝은 몸통의 절반 폭이다
  for (let y = 7; y <= 17; y++) span(front, y, 15 - jag(y, 47), 32 + jag(y, 49));
  // 받침켜 — 두 단 계단으로 벌어지며 후드를 받는다 (계단 윗면은 밝게)
  span(top, 18, 12, 35);
  span(front, 19, 12, 35);
  span(top, 20, 9, 38);
  // 후드 — 화덕과 거의 같은 폭. 여기가 좁으면 도로 병이 된다
  for (let y = 21; y <= 32; y++) span(front, y, 9 - jag(y, 51), 38 + jag(y, 53));
  // 화덕 — 제일 넓다. 후드보다 세 칸씩 어깨가 나오고 그 윗면이 보인다
  span(top, 36, 4, 43);
  for (let y = 37; y <= 66; y++) span(front, y, 3 + jag(y, 41), 44 - jag(y, 43));

  // ---- 막돌로 채운다 ----
  rubble(g, top, 5, -1);                           // 눕는 면은 한 단 밝다
  rubble(g, front, 5, 0);
  // 구조는 그늘 띠가 말한다 — 턱마다 두 줄
  for (let x = 15; x <= 32; x++) if (h(x, 5, 57) < 0.85) g.px(x, 7, CST[6]);
  for (let x = 12; x <= 35; x++) g.px(x, 19, CST[5]);
  for (let x = 9; x <= 38; x++) if (h(x, 7, 59) < 0.8) g.px(x, 21, CST[6]);
  for (let x = 4; x <= 43; x++) g.px(x, 37, CST[6]);

  // ---- 굴뚝 아가리 — 위에서 보이는 구멍과 안벽 ----
  g.rect(17, 1, 30, 5, [24, 18, 22]);
  g.hline(17, 30, 1, CST[4]);                      // 저쪽 안벽 (빛이 조금 든다)
  g.hline(17, 30, 2, CST[7]);
  g.px(17, 5, CST[6]); g.px(30, 5, CST[6]);
  g.px(16, 3, CST[6]); g.px(31, 3, CST[6]);

  // ---- 나무 들보 — 후드와 화덕 사이의 인방 ----
  g.hline(5, 42, 33, W[1]);
  g.hline(5, 42, 34, W[3]);
  for (let x = 5; x <= 42; x++) if (h(x, 0, 87) < 0.28) g.px(x, 34, W[4]);
  g.hline(5, 42, 35, W[5]);
  g.px(5, 33, W[2]); g.px(42, 35, W[6]);
  for (const bx of [9, 38]) {                      // 쇠띠 두 줄
    g.vline(bx, 33, 35, IR[3]); g.px(bx, 33, IR[1]);
  }

  // ---- 화구 — 구조의 주인공. 크게 뚫는다 ----
  const MX0 = 13, MX1 = 34, AR = 10;
  const MY0 = 40, MY1 = 64;                        // 아치 시작(위) ~ 바닥
  for (let y = MY0; y <= MY1; y++) {
    const dy = y - (MY0 + AR);
    const cut = dy < 0 ? Math.round(AR - Math.sqrt(Math.max(0, AR * AR - dy * dy))) : 0;
    for (let x = MX0 + cut; x <= MX1 - cut; x++) g.px(x, y, [24, 16, 14]);
  }
  // 방사형 쐐기돌 — 잿빛, 이맛돌만 따뜻한 돌
  {
    const acx = (MX0 + MX1) / 2, acy = MY0 + AR;
    for (let y = MY0 - 4; y <= MY1; y++) for (let x = MX0 - 4; x <= MX1 + 4; x++) {
      const dx = x - acx, dy = y - acy;
      if (dy > 0) continue;
      const rr = Math.sqrt(dx * dx * 0.72 + dy * dy);
      if (rr < AR - 0.2 || rr > AR + 2.6) continue;
      const a2 = Math.atan2(-dy, dx);
      const wedge = Math.floor(a2 / (Math.PI / 9));
      const joint = Math.abs(a2 / (Math.PI / 9) - wedge - 0.5) > 0.40;
      let t = 2 + Math.floor(h(wedge, 3, 91) * 2.0);
      if (a2 > Math.PI * 0.55) t -= 1;
      if (joint) t = 6;
      g.px(x, y, CST[clamp(t, 0, 7)]);
    }
    g.rect(Math.round(acx) - 1, MY0 - 5, Math.round(acx) + 1, MY0 - 2, ST[2]);
    g.px(Math.round(acx) - 1, MY0 - 5, ST[0]);
    g.px(Math.round(acx) + 1, MY0 - 2, ST[5]);
  }
  // 화구 안 — 숯 바닥이 **올라와** 있다 (참고 그림처럼 허리 높이 화상)
  for (let y = 58; y <= MY1; y++) for (let x = MX0 + 1; x <= MX1 - 1; x++) {
    const v = h(x, y + f, 17);
    g.px(x, y, y === 58 ? (v < 0.5 ? FI[3] : FI[4]) : [38, 22, 16]);
    if (y > 58 && v < 0.18) g.px(x, y, FI[4]);     // 재 사이로 남은 불씨
  }
  flame(g, 21 + (f % 2), 58, 12 + (f % 5), f, 0);
  flame(g, 27, 58, 9 + ((f + 1) % 4), f, 2.4);
  flame(g, 24, 59, 7 + ((f + 2) % 3), f, 4.1);
  // 새어 나온 불빛 — 안벽 발치만
  for (let y = 54; y <= 60; y++) {
    if (h(y, f, 23) < 0.55) g.px(MX0 - 1, y, FI[4]);
    if (h(y, f, 27) < 0.55) g.px(MX1 + 1, y, FI[4]);
  }
  for (let x = MX0 - 2; x <= MX1 + 2; x++)
    if (h(x, f, 29) < 0.4) g.px(x, MY1 + 1, FI[4]);
  // 그을음 — 들보 밑 정면
  for (let x = MX0 - 2; x <= MX1 + 2; x++)
    for (let k = 0; k < 2; k++) {
      if (k && h(x, k, 63) < 0.45) continue;
      g.px(x, MY0 - 4 - k, CST[clamp(7 - k, 5, 7)]);
    }

  // ---- 불티와 연기 ----
  for (let i = 0; i < 7; i++) {
    const sx = FCX + Math.round(Math.sin(i * 2.1 + f * 1.3) * 5);
    const sy = 4 - ((i * 3 + f * 2) % 4);
    g.px(sx, sy, i % 2 === 0 ? FI[1] : FI[2]);
  }
  {
    const SMO = [[206, 200, 196], [174, 168, 166]];
    for (let i = 0; i < 3; i++) {
      const sx = FCX - 3 + ((f * 2 + i * 3) % 7);
      const sy = 2 - ((f + i) % 3);
      g.px(sx, sy, SMO[i % 2]); g.px(sx + 1, sy, SMO[(i + 1) % 2]);
      if (i === 0) g.px(sx, sy - 1, SMO[1]);
    }
  }
  // ---- 살림의 흔적 ----
  for (let k = 0; k < 9; k++) g.px(41 + (k >> 2), 48 + k, IR[k < 2 ? 1 : 3]);
  g.px(41, 47, IR[0]); g.px(42, 47, IR[1]);        // 부지깽이
  for (let k = 0; k < 3; k++)
    g.hline(6 + k, 12 - k, 66 - k, ST[k === 2 ? 1 : (k === 1 ? 2 : 3)]);
  g.px(8, 62, ST[2]); g.px(10, 63, ST[4]);         // 재무더기
  // ---- 발치 ----
  g.rect(0, 61, 3, 66, CST[4]);                    // 굴러 떨어진 막돌
  g.hline(0, 3, 61, CST[2]);
  g.rect(44, 62, 47, 66, CST[5]);
  g.hline(44, 47, 62, CST[3]);
  for (let x = 6; x <= 41; x++)
    if (h(x, f, 41) < 0.6) g.px(x, 67, ST[5]);
  weatherStone(g, f, 37);                          // 흘러내린 줄은 화덕에만
  return outline(g);
}


// ---- 모루 ----
//
// 대장간이라는 말을 한 칸으로 하는 물건. 그루터기에 얹어 놓는다 —
// 땅바닥에 그냥 두면 쇳덩이 하나가 굴러다니는 것으로 보인다.
//
// **가로 막대를 쌓아서는 모루가 안 된다.** 몸통·허리·굽을 폭만 다른
// 띠 세 개로 그렸더니 회색 탁자가 됐다. 모루는 생김새가 곧 이름인
// 물건이라, 그 생김새를 이루는 것이 다 보여야 한다:
//   뿔    왼쪽으로 **길게** 뻗어 한 점으로 모인다. 이거 하나면 모루로 읽힌다
//   면    두들기는 윗면. 위에서 보는 각이니 여기가 제일 크고 제일 밝다
//   허리  잘록하다. 위아래가 넓고 가운데가 좁아야 무게가 실린다
//   굽    바닥에 퍼진 발. 그루터기 위에 **그림자를 드리우며** 얹힌다
//   구멍  면에 뚫린 네모(하디)와 둥근(프리철) 구멍
//
// 그루터기도 통나무다 — 자른 윗면에 나이테가 보이고, 껍질이 세로로
// 갈라지고, 쇠테는 **앞으로 돌아 나오면서 끝이 어두워진다.** 통줄로
// 그으면 테가 아니라 통에 칠한 줄무늬가 된다.
function anvil() {
  // 판을 32x34 -> **38x40** 으로. 화면에서 76x80, 가로 두 칸 반.
  // 면을 아홉 줄로 눕히고 나면 허리와 굽이 들어갈 자리가 그만큼 필요하다
  const g = new P(38, 40);
  g.ground(19, 38, 15, 2.8);

  // ---- 그루터기 — **자른 면이 타원으로 보인다** ----
  //
  // 앞모서리를 가로 직선으로 긋고 그 위에 몇 줄을 얹었더니, 통나무가 아니라
  // 네모난 궤짝이었다. 위에서 내려다본 원기둥의 자른 면은 **타원**이고,
  // 그 타원의 앞쪽 호가 곧 윗면과 옆면을 가르는 선이다.
  // 다만 타원을 너무 키우면 이번엔 팬케이크가 된다 — 자른 면과 껍질 옆면이
  // 둘 다 보여야 원기둥이다.
  const SX0 = 6, SX1 = 31, SBOT = 38;
  const SCY = 27.0, SRY = 5.6;                    // 타원 중심과 세로 반지름
  const SCX = (SX0 + SX1) / 2, SRX = (SX1 - SX0) / 2;
  // 톱으로 켠 속살은 껍질보다 옅다. 다만 마당에서 제일 밝은 면이 되면
  // 그루터기가 아니라 접시로 보인다
  const CUT = [[190, 160, 116], [164, 134, 92], [138, 110, 74]];
  for (let y = Math.round(SCY - SRY); y <= SBOT; y++)
    for (let x = SX0; x <= SX1; x++) {
      const dx = (x - SCX) / SRX, dy = (y - SCY) / SRY;
      if (dx * dx + dy * dy <= 1.0) {             // 자른 윗면 (타원 안)
        // 뒤로 갈수록 조금 어둡다 — 이 한 단이 면을 눕힌다
        const t = (y - (SCY - SRY)) / (SRY * 2);
        g.px(x, y, CUT[t < 0.26 ? 2 : (t < 0.52 ? 1 : 0)]);
      } else if (y > SCY && Math.abs(dx) <= 1.0) {  // 옆면 (껍질)
        g.px(x, y, W[4]);
      }
    }
  // 나이테 — **이어진 원호**여야 한다. 반쯤 지우면 나이테가 아니라 모래다
  for (const r of [0.38, 0.66]) {
    for (let a2 = 0; a2 < 128; a2++) {
      const th = (a2 / 128) * Math.PI * 2;
      const x = Math.round(SCX + Math.cos(th) * SRX * r);
      const y = Math.round(SCY + Math.sin(th) * SRY * r);
      if (h(x >> 1, y, 131) < 0.82) g.px(x, y, CUT[1]);
    }
  }
  g.px(18, 27, W[4]); g.px(19, 27, W[4]);         // 고갱이
  // 껍질의 세로 결 — 옆면에만
  for (let x = SX0; x <= SX1; x++) {
    const v = h(x, 0, 133);
    for (let y = Math.ceil(SCY); y <= SBOT; y++) {
      const dx = (x - SCX) / SRX, dy = (y - SCY) / SRY;
      if (dx * dx + dy * dy <= 1.0) continue;     // 윗면은 건드리지 않는다
      if (Math.abs(dx) > 1.0) continue;
      if (v < 0.32) g.px(x, y, W[5]);
      else if (v > 0.87) g.px(x, y, W[3]);
      if (x <= SX0 + 1) g.px(x, y, W[3]);         // 왼쪽 = 빛
      else if (x >= SX1 - 1) g.px(x, y, W[6]);    // 오른쪽 = 돌아간 면
    }
  }
  g.hline(SX0 + 1, SX1 - 1, SBOT, W[6]);          // 밑동
  // 쇠테 둘 — **가운데가 밝고 양 끝이 어둡다.** 그래야 통을 돌아 나온다.
  // 한 줄만 두른다. 두 줄씩 둘렀더니 옆면 절반이 쇠라 쇠통으로 보였다
  for (const hy of [33, 37]) {
    for (let x = SX0; x <= SX1; x++) {
      const dx = (x - SCX) / SRX, dy = (hy - SCY) / SRY;
      if (Math.abs(dx) > 1.0 || dx * dx + dy * dy <= 1.0) continue;
      const t = Math.abs(dx);
      g.px(x, hy, IR[t > 0.86 ? 4 : (t > 0.55 ? 3 : 2)]);
      if (hy + 1 <= SBOT) g.px(x, hy + 1, W[6]);
    }
    for (let x = SX0 + 5; x <= SX1 - 5; x += 7) g.px(x, hy, IR[2]);   // 대갈못
  }

  // ---- 모루 ----
  //
  // **뿔이 길어야 모루다.** 길이의 삼분의 일을 뿔로 내주고 한 점으로 모으고,
  // 오른쪽은 뭉툭하게 잘라 한 단 낮춘다 — 이 좌우 비대칭이 실루엣의 전부다.
  //
  // 그리고 **면이 정면보다 훨씬 깊어야 한다.** 두들기는 면은 모루에서 제일
  // 넓은 면이고, 내려다보는 각에서는 그 면이 화면을 향해 열린다.
  // 아홉 줄 눕히고 정면은 두 줄 — 이 비율이 곧 카메라 각도다.
  const BX0 = 12, BX1 = 30;                       // 몸통 좌우
  const FACE = 10, FD = 9;                        // 앞 모서리 줄 · 면 깊이
  // 굽 — 퍼진 발. 윗면이 **네 줄** 보이고 정면은 두 줄이다
  for (let k = 4; k >= 1; k--)
    g.hline(13 + k - 1, 29 - k + 1, 22 - k, IR[k >= 4 ? 3 : (k >= 3 ? 2 : (k >= 2 ? 1 : 0))]);
  g.rect(13, 23, 29, 23, IR[3]);
  g.hline(13, 29, 24, IR[4]);
  g.px(13, 23, IR[2]); g.px(14, 23, IR[2]);       // 왼쪽 = 빛
  for (let x = 12; x <= 30; x++)                  // 그루터기에 드리운 그림자
    if (h(x, 2, 137) < 0.82) g.px(x + 1, 25, CUT[2]);
  // 허리 — 잘록하다. 위아래가 넓고 가운데가 좁다
  for (let y = FACE + 3; y <= 18; y++) {
    const t = Math.abs(y - 15.5) / 3.0;           // 0(가운데) ~ 1(위아래)
    const w = 4 + Math.round(t * 2);
    g.rect(21 - w, y, 21 + w, y, IR[3]);
    g.px(21 - w, y, IR[2]); g.px(21 - w + 1, y, IR[2]);
    g.px(21 + w, y, IR[4]);
  }
  // 몸통 정면 — **두 줄.** 면을 눕힌 만큼 정면은 얇아진다
  g.hline(BX0, BX1, FACE + 1, IR[3]);
  g.hline(BX0 + 1, BX1 - 1, FACE + 2, IR[4]);
  g.px(BX0, FACE + 1, IR[2]);
  // 면 — 아홉 줄. 뒤로 갈수록 좁아지고 한 단씩 어둡다
  for (let k = FD; k >= 1; k--) {
    const inset = Math.round((k / FD) * (BX1 - BX0) * 0.16);
    const f = (FD - k) / (FD - 1);
    const tone = f < 0.14 ? IR[3] : (f < 0.34 ? IR[2] : (f < 0.58 ? IR[1] : IR[0]));
    g.hline(BX0 + inset, BX1 - inset, FACE - k, tone);
  }
  g.hline(BX0, BX1, FACE, IR[4]);                 // **앞 모서리**
  // 뿔 — 열두 칸을 가서 **한 점으로** 모인다. 위아래가 같이 좁아져야 원뿔이다.
  // 중심선 하나에 반높이를 매달면 끝에서 반드시 한 줄로 모인다
  const HCY = FACE - 4.0;
  for (let x = BX0 - 1; x >= 0; x--) {
    const t = (BX0 - x) / BX0;                    // 0(몸통) ~ 1(끝)
    // 끝으로 갈수록 **천천히** 가늘어진다. 곧게 줄였더니 송곳이 됐다
    const half = 4.0 * Math.pow(1 - t, 0.6);
    const top = Math.round(HCY - half), bot = Math.round(HCY + half);
    for (let y = top; y <= bot; y++)
      g.px(x, y, bot > top && y >= bot ? IR[4]
        : (bot > top && y <= top ? IR[1] : IR[0]));
  }
  // 꽁무니 — 뿔 반대쪽은 뭉툭하게 잘리고 **한 단 낮다**
  g.rect(BX1 + 1, FACE - 6, 35, FACE + 1, IR[2]);
  g.hline(BX1 + 1, 35, FACE - 6, IR[1]);
  g.hline(BX1 + 1, 35, FACE + 1, IR[4]);
  g.vline(35, FACE - 5, FACE, IR[3]);
  // 구멍 둘 — 면에 뚫려 있으니 **안쪽 벽**이 한 줄 보인다
  g.rect(24, FACE - 5, 26, FACE - 3, [30, 30, 36]);
  g.hline(24, 26, FACE - 5, IR[3]);
  g.rect(29, FACE - 4, 29, FACE - 3, [30, 30, 36]);
  g.px(29, FACE - 5, IR[3]);
  // 두들긴 자국 — 면 한복판이 반들반들하다
  for (let x = BX0 + 2; x <= 22; x++)
    for (const y of [FACE - 3, FACE - 2, FACE - 1])
      if (h(x, y, 139) < 0.26) g.px(x, y, [236, 238, 242]);

  // ---- 살림 ----
  //
  // 망치를 면 위에 얹어 보았더니 실루엣의 제일 중요한 자리를 가려서
  // 모루가 다시 「판때기」가 됐다. 연장은 그루터기 위에 둔다
  g.rect(20, 29, 23, 29, IR[2]);                  // 망치 머리
  g.hline(20, 23, 28, IR[0]);
  g.hline(20, 23, 30, IR[4]);
  g.hline(24, 29, 29, W[2]); g.hline(24, 29, 30, W[4]);   // 자루
  g.vline(33, 30, 37, IR[3]); g.vline(34, 31, 37, IR[2]); // 세워 둔 집게
  g.px(32, 29, IR[1]); g.px(33, 29, IR[1]); g.px(34, 30, IR[1]);
  // 튄 쇠비늘과 부스러기
  g.px(3, 16, FI[3]); g.px(1, 18, FI[4]); g.px(36, 18, FI[4]);
  for (let x = 7; x <= 30; x++)
    if (h(x, 4, 141) < 0.22) g.px(x, 39, IR[4]);
  // ---- 발치 흙탕물 ----
  //
  // 화로와 **같은 자국**이다. 나무는 돌 사다리(ST)가 아니므로 여기서만
  // 손으로 얹는다 — 마당 흙빛이 밑동에 섞여야 물건이 땅에 붙는다
  for (let y = SBOT - 5; y <= SBOT; y++) for (let x = SX0; x <= SX1; x++) {
    if (!g.d[y][x]) continue;
    const near = (y - (SBOT - 5)) / 5;
    if (h(x >> 1, y >> 1, 143) > near * near * 1.1) continue;
    g.px(x, y, GRIME[h(x, y, 145) < 0.5 ? 1 : 2]);
  }
  return outline(g);
}


// ---- 무기 거치대 ----
//
// 대장간이 **무엇을 만드는 집인지** 말하는 물건. 화로가 「불을 쓴다」면
// 이쪽은 「칼을 벼른다」다. 벼려 놓은 것을 세워 두는 나무 시렁이다.
//
// 셋을 세운다 — 칼 · 창 · 도끼. 한 자루만 세우면 「지팡이 하나 놓인 틀」로
// 보이고, 다섯을 꽂으면 무엇이 무엇인지 안 갈린다.
function weaponrack() {
  const g = new P(58, 62);
  g.ground(29, 58, 25, 4.0);
  // 시렁 — 기둥 둘에 가로대 셋. 무기보다 **뒤에** 있으므로 먼저 깐다
  for (const px2 of [1, 50]) {
    g.rect(px2, 24, px2 + 6, 58, W[4]);
    g.vline(px2, 24, 58, W[3]); g.rect(px2 + 4, 24, px2 + 6, 58, W[5]);
    topFace(g, px2, px2 + 6, 24, W, 4);              // 기둥 머리
    for (let y = 28; y < 57; y += 6) g.px(px2 + 2, y, W[5]);
    g.px(px2 + 3, 40, W[5]); g.px(px2 + 2, 41, W[5]);
  }
  for (const cy of [31, 44]) {
    g.rect(1, cy, 56, cy + 3, W[3]);                 // 가로대 정면
    topFace(g, 1, 56, cy, W, 4);                     // 가로대 윗면
    g.hline(1, 56, cy + 3, W[5]);
    for (let x = 5; x <= 52; x += 7) { g.px(x, cy + 1, W[5]); g.px(x, cy + 2, W[5]); }
    for (const nx of [4, 52]) { g.px(nx, cy + 1, IR[2]); g.px(nx, cy + 2, IR[4]); }
  }
  g.rect(0, 56, 57, 58, W[4]);
  topFace(g, 0, 57, 56, W, 5);                       // 발치 받침 윗면
  g.hline(0, 57, 58, W[6]);
  for (let x = 3; x <= 54; x += 8) g.px(x, 57, W[6]);
  // ① 칼 — 날은 밝고 등이 어둡고 가운데 피홈이 파인다. 코등이·자루·머리쇠
  g.rect(12, 6, 17, 37, IR[1]);
  g.vline(12, 6, 37, IR[0]);                    // 날 — 볕을 받는 쪽
  g.vline(13, 6, 37, IR[0]);
  g.vline(15, 6, 37, IR[3]);                    // 피홈
  g.vline(16, 6, 37, IR[2]); g.vline(17, 6, 37, IR[3]);   // 등날
  for (let k = 0; k < 5; k++) { g.px(12 + k, 5 - k, IR[0]); g.px(13 + k, 5 - k, IR[1]); }
  g.px(14, 2, IR[0]); g.px(15, 3, IR[1]); g.px(16, 4, IR[2]);   // 날끝
  g.rect(8, 38, 21, 41, IR[3]);                 // 코등이
  g.hline(8, 21, 38, IR[2]); g.hline(8, 21, 41, IR[4]);
  g.px(7, 39, IR[2]); g.px(7, 40, IR[3]); g.px(22, 39, IR[3]); g.px(22, 40, IR[4]);
  g.rect(12, 42, 17, 52, W[4]);                 // 자루 — 가죽을 감았다
  g.vline(12, 42, 52, W[3]); g.vline(17, 42, 52, W[5]);
  for (let y = 43; y <= 51; y += 2) { g.hline(12, 17, y, W[5]); g.px(13, y, W[3]); }
  g.rect(11, 53, 18, 55, IR[2]);                // 자루 머리쇠
  g.hline(11, 18, 53, IR[1]); g.hline(11, 18, 55, IR[4]);
  // ② 창 — 자루가 제일 길고 날이 나뭇잎 꼴이다
  g.rect(28, 15, 31, 55, W[4]); g.vline(28, 15, 55, W[3]); g.vline(31, 15, 55, W[5]);
  for (let y = 19; y <= 53; y += 6) g.px(30, y, W[5]);
  g.rect(28, 11, 31, 14, IR[3]);                // 자루에 물린 목
  g.hline(27, 32, 12, IR[2]); g.hline(27, 32, 14, IR[4]);
  for (let y = 4; y <= 10; y++) {               // 날 — 나뭇잎 꼴
    const t = (y - 7) / 3.5, w = Math.round(3 * (1 - t * t * 0.55));
    for (let x = 29 - w; x <= 30 + w; x++)
      g.px(x, y, x <= 29 - w + 1 ? IR[1] : (x >= 30 + w - 1 ? IR[4] : IR[2]));
  }
  g.vline(29, 4, 10, IR[0]); g.vline(30, 4, 10, IR[0]);   // 가운데 능선
  g.rect(29, 2, 30, 3, IR[1]); g.px(29, 1, IR[0]);
  // ③ 도끼 — **자루 꼭대기에 물린 반달 날.** 가로보다 세로가 길어야 반달이고,
  // 날 윗변이 자루 꼭대기와 같거나 더 높아야 「물렸다」가 된다
  g.rect(44, 20, 47, 55, W[4]); g.vline(44, 20, 55, W[3]); g.vline(47, 20, 55, W[5]);
  for (let y = 25; y <= 53; y += 6) g.px(46, y, W[5]);
  for (let y = 10; y <= 27; y++) {
    const t = (y - 18.5) / 9.0;
    const w = Math.round(9 * Math.sqrt(Math.max(0, 1 - t * t)) * 0.95);
    if (w <= 0) continue;
    for (let x = 44 - w; x <= 43; x++) {
      let c = IR[2];
      if (x <= 44 - w + 1) c = IR[0];           // 날끝 — 갈아서 희다
      else if (x >= 41) c = IR[3];              // 자루 쪽은 두껍고 어둡다
      g.px(x, y, c);
    }
    if (y <= 11) for (let x = 44 - w; x <= 43; x++) g.px(x, y, IR[1]);
    if (y >= 26) for (let x = 44 - w; x <= 43; x++) g.px(x, y, IR[4]);
  }
  for (let y = 13; y <= 24; y += 4) g.px(44 - Math.round(7 * Math.sqrt(Math.max(0, 1 - ((y - 18.5) / 9) ** 2))) + 2, y, IR[1]);
  g.rect(44, 16, 47, 23, IR[3]);                // 자루에 물린 대가리
  g.hline(44, 47, 16, IR[2]); g.hline(44, 47, 23, IR[4]);
  g.rect(48, 18, 50, 22, IR[3]);                // 반대쪽 짧은 뒤날
  g.hline(48, 50, 18, IR[2]); g.hline(48, 50, 22, IR[4]);
  // 발치에 기대 놓은 방패 — 널을 세로로 대고 쇠테를 두른 것.
  // 십자와 살을 그으면 수레바퀴가 된다. 방패는 **널판**이다
  g.disc(11, 52, 8.6, 7.4, W[3]);
  g.disc(11, 52, 7.2, 6.0, W[2]);
  for (let x = 4; x <= 18; x++) {                       // 세로 널
    if ((x - 4) % 4 !== 0) continue;
    for (let y = 44; y <= 60; y++) if (g.get(x, y) === W[2]) g.px(x, y, W[4]);
  }
  for (let a2 = 0; a2 < 40; a2++) {                     // 쇠테
    const t = a2 / 40 * Math.PI * 2;
    const lit = Math.cos(t) < -0.2 || Math.sin(t) < -0.4;
    g.px(11 + Math.cos(t) * 8.6, 52 + Math.sin(t) * 7.4, lit ? IR[1] : IR[4]);
    g.px(11 + Math.cos(t) * 7.9, 52 + Math.sin(t) * 6.8, lit ? IR[2] : IR[4]);
    if (a2 % 5 === 0) g.px(11 + Math.cos(t) * 7.2, 52 + Math.sin(t) * 6.2, IR[3]);  // 대갈못
  }
  g.disc(11, 52, 2.8, 2.6, IR[2]);                      // 가운데 쇠 볼록이
  g.disc(11, 52, 1.4, 1.3, IR[1]);
  g.px(10, 50, IR[0]); g.px(12, 54, IR[4]);
  return outline(g);
}


// ---- 장작더미 ----
//
// 마구리(잘린 면)가 보이게 쌓는다 — 나이테 한 줄이면 통나무가 된다.
// 스무 칸에서는 통 하나가 반지름 두 칸 반이라 갈색 자갈 무더기였고,
// 서른두 칸에서 나이테가 들어왔다. 마흔여섯 칸이면 통 하나에
// **껍질의 세로 골 · 백재 · 나이테 넷 · 심재 · 쪼갠 금**이 다 들어간다.
function logpile() {
  const g = new P(46, 34);
  g.ground(23, 30, 20, 3.4);
  const put = (cx, cy, r, s) => {
    g.disc(cx, cy, r, r * 0.94, W[5]);                    // 껍질
    g.disc(cx, cy, r - 1.4, (r - 1.4) * 0.94, W[2]);      // 백재
    // 나이테 — **두 줄이면 족하다.** 넷을 촘촘히 그었더니 마구리가
    // 자글자글해져서 장작이 아니라 **호두 무더기**가 됐다. 좁은 면에
    // 선을 많이 그으면 무늬가 아니라 잡음이다
    for (let k = 1; k <= 2; k++) {
      const rr = (r - 1.4) * (0.82 - k * 0.28);
      for (let a2 = 0; a2 < 30; a2++) {
        const t = a2 / 30 * Math.PI * 2;
        g.px(cx + Math.cos(t) * rr, cy + Math.sin(t) * rr * 0.94, W[3]);
      }
    }
    g.disc(cx, cy, r * 0.16, r * 0.15, W[4]);             // 심재
    // 쪼갠 금 — 마구리를 가로지르는 한 줄. 장작은 쪼갠 것이다
    if (h(cx, cy, s) < 0.66) {
      const ang = h(cx, s, 61) * Math.PI;
      for (let t2 = -r + 1.4; t2 <= r - 1.4; t2 += 0.4) {
        g.px(cx + Math.cos(ang) * t2, cy + Math.sin(ang) * t2 * 0.94, W[4]);
        if (h(Math.round(t2), s, 62) < 0.22)
          g.px(cx + Math.cos(ang) * t2 + 1, cy + Math.sin(ang) * t2 * 0.94, W[3]);
      }
    }
    // 껍질 — 세로로 골이 파인다. 두께가 보여야 껍질이다
    for (let a2 = 0; a2 < 40; a2++) {
      const t = a2 / 40 * Math.PI * 2;
      const lit = Math.sin(t) < -0.25;
      g.px(cx + Math.cos(t) * r, cy + Math.sin(t) * r * 0.94, lit ? W[3] : W[6]);
      if (a2 % 6 === 0 && !lit)
        g.px(cx + Math.cos(t) * (r - 0.8), cy + Math.sin(t) * (r - 0.8) * 0.94, W[6]);
    }
    if (h(cx, cy, s + 3) < 0.55) g.px(cx + 1, cy - r + 1.4, W[0]);   // 볕 한 점
  };
  // 아래가 넓고 위가 좁은 무더기. 켜마다 반 통씩 어긋난다
  const rows = [[5, 27, 5.4], [16, 27, 5.6], [27, 27, 5.4], [38, 27, 4.6],
                [10, 17, 5.0], [21, 17, 5.4], [32, 17, 5.0],
                [15, 8, 4.6], [26, 8, 4.6],
                [21, 1, 4.0]];
  for (const [x, y, r] of rows) put(x, y, r, x + y);
  // 무더기 밑에 굴러 나온 장작 한 개 — 옆으로 누워 껍질 결이 보인다
  g.rect(1, 29, 12, 33, W[4]);
  g.hline(1, 12, 29, W[2]); g.hline(1, 12, 33, W[6]);
  for (let x = 2; x <= 11; x += 2) { g.px(x, 31, W[5]); if (x % 4 === 0) g.px(x, 32, W[5]); }
  g.disc(12, 31, 2.4, 2.2, W[2]); g.disc(12, 31, 1.2, 1.1, W[3]);
  g.px(12, 31, W[4]);
  // 쪼갠 부스러기 — 무더기 발치에 흩어진다
  for (let i = 0; i < 6; i++) {
    const x = 14 + Math.floor(h(i, 5, 67) * 30);
    g.px(x, 32, W[5]); g.px(x + 1, 32, W[4]);
    if (h(i, 6, 68) < 0.4) g.px(x, 31, W[3]);
  }
  return outline(g);
}

// ---- 여물통 ----
//
// 목장에도 대장간에도 놓는다 (담금질통). 안에 물이 찰랑거린다.
// 스무 칸에서는 판때기 두 장, 서른두 칸에서 널과 쇠테가 들어왔다.
// 마흔여섯 칸이면 **통을 짠 방식**까지 보인다 — 널 일곱 장을 대고
// 위아래로 쇠테를 두르고, 통 밑에 받침목을 괴고, 물에는 하늘이 비친다.
function trough(wet) {
  const g = new P(46, 30);
  g.ground(23, 26, 20, 3.2);
  // 받침목 — 통이 땅에서 조금 떠 있어야 물통이지 구유가 아니다
  for (const lx of [4, 35]) {
    g.rect(lx, 22, lx + 6, 26, W[5]);
    g.hline(lx, lx + 6, 22, W[3]); g.hline(lx, lx + 6, 26, W[6]);
    g.vline(lx, 22, 26, W[4]);
  }
  // 몸통 — 널 일곱 장을 세로로 세운다
  g.rect(1, 11, 44, 23, W[4]);
  for (let x = 1; x <= 44; x++) {
    const b2 = Math.floor((x - 1) / 6.3);
    const inb = (x - 1) % 6.3;
    if (inb < 1) g.vline(x, 11, 23, W[6]);                 // 널 사이 이음매
    else if (inb < 2) g.vline(x, 11, 23, W[3]);            // 그 옆은 빛
    for (let y = 13; y <= 22; y += 3)
      if (h(b2 * 7 + x, y, 41) < 0.22) g.px(x, y, W[5]);   // 결
  }
  g.hline(1, 44, 23, W[6]);                                // 밑변 턱
  g.rect(0, 11, 1, 23, W[3]); g.rect(44, 11, 45, 23, W[5]);
  // 아가리 테 — 위를 보는 면. 깊게 파야 안이 보인다
  topFace(g, 1, 44, 11, W, 9);
  // 속 — 물이든 여물이든 테 안쪽에만 담긴다
  g.rect(4, 4, 41, 10, wet ? AQUA[2] : STRAW[2]);
  if (wet) {
    g.rect(4, 4, 41, 5, AQUA[1]);
    // 잔물결 — 짧은 획 열둘. 통줄로 그으면 파란 판때기가 된다
    for (let i = 0; i < 12; i++) {
      const x = 5 + Math.floor(h(i, 1, 43) * 34), y = 4 + Math.floor(h(1, i, 44) * 5);
      const len = 2 + Math.floor(h(i, 2, 45) * 3);
      for (let k = 0; k < len && x + k <= 41; k++) g.px(x + k, y, AQUA[0]);
      if (h(i, 3, 46) < 0.4) g.px(x, y + 1, AQUA[2]);
    }
    g.hline(4, 41, 10, AQUA[2]);
    // 하늘이 비친다 — 흰 점 셋. 물이 「고여 있다」를 말하는 건 이것이다
    for (const [sx, sy] of [[9, 6], [24, 5], [34, 8]]) {
      g.px(sx, sy, [255, 255, 255]); g.px(sx + 1, sy, [232, 244, 252]);
    }
    // 물에 잠긴 통벽 — 물빛이 널을 타고 한 줄 어른거린다
    for (let x = 4; x <= 41; x += 7) g.px(x, 9, AQUA[1]);
  } else {
    // 마른 여물 — 테 위로 삐져나와야 짚이다
    for (let x = 4; x <= 41; x++) {
      const hgt = 1 + (h(x, 1, 43) < 0.42 ? 1 : 0);
      for (let k = 0; k < hgt; k++)
        g.px(x, 4 - k, k === hgt - 1 ? STRAW[0] : STRAW[1]);
      if (h(x, 2, 45) < 0.45) g.px(x, 6, STRAW[3]);
      if (h(x, 3, 47) < 0.3) g.px(x, 8, STRAW[2]);
    }
    for (let i = 0; i < 12; i++) {           // 낟알
      const x = 5 + Math.floor(h(i, 4, 48) * 35), y = 5 + Math.floor(h(4, i, 49) * 5);
      g.px(x, y, STRAW[0]);
    }
  }
  // 쇠테 둘 — 통을 통으로 묶는 것. **밝게 두면 쇠가 아니라 흰 기둥**이다
  for (const bx of [9, 33]) {
    g.rect(bx, 12, bx + 2, 23, IR[3]);
    g.vline(bx, 12, 23, IR[2]); g.vline(bx + 2, 12, 23, IR[4]);
    for (const ny of [14, 18, 22]) { g.px(bx, ny, IR[1]); g.px(bx + 2, ny + 1, IR[4]); }
  }
  // 통 아래로 새어 젖은 자국 — 물통에만
  if (wet) for (let i = 0; i < 5; i++) {
    const x = 12 + Math.floor(h(i, 6, 50) * 22);
    g.px(x, 24, [76, 60, 44]); g.px(x + 1, 25, [76, 60, 44]);
  }
  return outline(g);
}

// ---- 볏단 ----
//
// 목장의 여물. 헤맨 자취를 남겨 둔다 — 둥근 덩어리(허연 얼룩) → 네모로
// 묶음(윗면을 깊게 파 굴 입구) → 삐져나온 짚 세 줄(양쪽에 뿔).
// 볏단을 볏단으로 만드는 것은 **가로로 눕는 낟알 다발**, 그 다발을
// 가로지르는 **가는 새끼줄 둘**, 묶인 자리의 **잘록한 허리**다.
function hay() {
  const g = new P(40, 32);
  g.ground(20, 28, 17, 3.0);
  g.rect(3, 15, 36, 28, STRAW[1]);
  topFace(g, 3, 36, 15, STRAW, 7);          // 윗면은 얕게
  g.hline(3, 36, 28, STRAW[3]);             // 밑변 = 턱
  g.rect(3, 15, 4, 28, STRAW[0]);           // 왼쪽 = 빛
  g.rect(35, 15, 36, 28, STRAW[3]);         // 오른쪽 = 그늘
  // 낟알 다발 — 가로로 눕는다. 짧은 획이라야 짚단이고, 통줄이면 판때기다
  for (let i = 0; i < 74; i++) {
    const x = 4 + Math.floor(h(i, 1, 51) * 31), y = 16 + Math.floor(h(1, i, 52) * 12);
    const len = 3 + Math.floor(h(i, 2, 53) * 4);
    const c = h(i, 3, 54) < 0.42 ? STRAW[2] : STRAW[0];
    for (let k = 0; k < len && x + k <= 35; k++) g.px(x + k, y, c);
    if (h(i, 4, 58) < 0.18) g.px(x, y + 1, STRAW[3]);      // 다발 밑의 그늘
  }
  // 낟알 이삭 — 볏단 겉으로 튀어나온 알갱이
  for (let i = 0; i < 18; i++) {
    const x = 4 + Math.floor(h(i, 4, 55) * 31), y = 16 + Math.floor(h(4, i, 56) * 12);
    g.px(x, y, STRAW[0]); g.px(x, y - 1, STRAW[0]);
  }
  // 잘린 짚 끝 — 볏단 옆면은 잘라 낸 자리라 자잘하게 들쭉날쭉하다
  for (let y = 16; y <= 27; y++) {
    if (h(y, 1, 59) < 0.4) g.px(2, y, STRAW[1]);
    if (h(y, 2, 59) < 0.4) g.px(37, y, STRAW[2]);
  }
  // 삐져나온 오라기 — **한 줄 위까지만.** 세 줄 솟구치면 뿔이 된다
  for (let i = 0; i < 13; i++) g.px(4 + Math.round(i * 2.5), 8, STRAW[0]);
  // 새끼줄 둘 — 두 가닥을 꼬았다. 묶인 자리가 파이므로 양옆에 그늘이 진다
  // 다만 **볏단 위로 솟구치지 않게.** 줄 끝을 윗면보다 높이 올렸더니
  // 볏단 양쪽에 더듬이가 돋았다 — 새끼줄은 볏단을 감는 것이지 매다는 게 아니다
  for (const bx of [11, 27]) {
    g.vline(bx, 11, 28, W[4]);
    g.vline(bx + 1, 11, 28, W[5]);
    for (let y = 12; y <= 27; y += 2) g.px(bx, y, W[2]);   // 꼬임
    g.px(bx, 15, W[2]); g.px(bx + 1, 15, W[3]);            // 윗면을 넘는 자리
    for (let y = 17; y <= 26; y += 3) { g.px(bx - 1, y, STRAW[3]); g.px(bx + 2, y + 1, STRAW[3]); }
  }
  return outline(g);
}

// ---- 그물 말리는 틀 ----
//
// 이 한 칸이면 수산시장이다. 장대 둘에 그물이 걸려 늘어진다.
// 스물두 칸에서는 그물코가 한 칸이라 회색 체크무늬 판이었고, 서른네
// 칸에서 구멍이 보이기 시작했다. 마흔여덟 칸이면 **코가 세 칸**이 되어
// 그물이 아래로 갈수록 늘어지고 벌어지는 것까지 읽힌다.
function netrack() {
  const g = new P(48, 48);
  g.ground(24, 44, 20, 3.4);
  // 장대 둘 — 아래가 굵고 위가 좁다. 나무 결과 옹이도 보인다
  for (const px2 of [4, 40]) {
    g.rect(px2, 6, px2 + 3, 44, W[4]);
    g.vline(px2, 6, 44, W[3]); g.vline(px2 + 3, 6, 44, W[5]);
    g.hline(px2, px2 + 3, 44, W[6]);
    for (let y = 10; y < 43; y += 5) g.px(px2 + 1 + (y % 2), y, W[5]);
    g.disc(px2 + 1, 24, 1.2, 1.6, W[5]);
    topFace(g, px2, px2 + 3, 6, W, 3);
  }
  // 가로대 — 위에 하나, 아래에 버팀 하나
  g.rect(1, 4, 46, 6, W[3]);
  topFace(g, 1, 46, 4, W, 3);
  g.hline(1, 46, 7, W[5]);
  for (let x = 6; x <= 42; x += 8) { g.px(x, 5, W[5]); g.px(x, 6, W[5]); }
  // 버팀목 — 비스듬히 받친다. 없으면 장대가 그냥 서 있는 막대 둘이다
  for (let k = 0; k < 8; k++) {
    g.px(8 + k, 36 + k, W[5]); g.px(9 + k, 36 + k, W[6]);
    g.px(39 - k, 36 + k, W[5]); g.px(38 - k, 36 + k, W[6]);
  }
  // 그물 — 코 사이를 **비워 두면 안 된다.** 윤곽선 패스가 빈 칸마다
  // 검은 테를 둘러 흑백 체크무늬 판이 된다. 반투명한 그늘을 먼저 깔면
  // 뒤가 비치면서 윤곽선도 끼어들지 못한다
  for (let y = 8; y <= 40; y++) for (let x = 8; x <= 39; x++) g.px(x, y, [34, 46, 38, 62]);
  for (let y = 8; y <= 39; y++) {
    const sag = Math.round((y - 8) * 0.32);
    for (let x = 8; x <= 39; x++) {
      const u = x + sag, v = y;
      if (!((u + v) % 5 === 0 || (u - v + 50) % 5 === 0)) continue;
      const c = y > 32 ? NET[2] : (y > 20 ? NET[1] : NET[0]);
      g.px(x, y, c);
      if (h(x, y, 63) < 0.3) g.px(x, y + 1, NET[2]);      // 코가 엉킨 자리
      if (h(x, y, 64) < 0.12) g.px(x + 1, y, NET[1]);
    }
  }
  // 그물 윗줄 — 장대에 묶인 자리. 매듭이 있어야 걸린 것이 된다
  g.hline(8, 39, 8, NET[1]); g.hline(8, 39, 9, NET[2]);
  for (let x = 9; x <= 38; x += 5) {
    g.px(x, 7, W[4]); g.px(x, 8, NET[0]); g.px(x + 1, 8, NET[0]);
  }
  // 아랫자락 — 늘어진 끝이 고르지 않다
  for (let x = 8; x <= 39; x++) {
    const d = 39 + (h(x, 2, 65) < 0.45 ? 1 : 0) + (h(x, 3, 66) < 0.2 ? 1 : 0);
    g.px(x, d, NET[2]);
  }
  // 그물에 걸린 것 — 작은 물고기 하나. 여기가 무슨 가게인지 못을 박는다
  g.disc(20, 26, 3.0, 1.8, [148, 176, 196]);
  g.disc(20, 26, 2.0, 1.2, [196, 214, 226]);
  g.px(18, 26, [72, 92, 112]);                            // 눈
  for (let k = 0; k < 3; k++) { g.px(23 + k, 25 - k, [148, 176, 196]); g.px(23 + k, 27 + k, [148, 176, 196]); }
  // 뜸(부표) 셋 — 나무 공. 이게 있어야 어구다
  for (const bx of [13, 24, 35]) {
    g.disc(bx, 42, 3.0, 2.8, W[3]);
    g.disc(bx, 42, 1.8, 1.6, W[2]);
    g.px(bx - 1, 40, W[1]); g.px(bx + 2, 44, W[5]);
    g.vline(bx, 39, 40, NET[2]);
    for (let a2 = 0; a2 < 14; a2++) {
      const t = a2 / 14 * Math.PI * 2;
      g.px(bx + Math.cos(t) * 3.0, 42 + Math.sin(t) * 2.8, W[5]);
    }
  }
  return outline(g);
}

// ---- 화단 ----
//
// 길게 짠 나무 상자에 흙을 채우고 꽃을 심었다. 여관·회관·도서관 앞.
// 스무 칸에서는 잎이 두 칸, 꽃이 한 칸이라 초록 띠 위의 색점이었다.
// 서른두 칸에서 꽃송이가 들어왔고, 마흔여섯 칸이면 **잎맥과 꽃잎의
// 겹침**까지 보인다. 꽃은 세 포기, 종류를 다르게 — 같은 꽃 셋은 무늬다.
function planter() {
  const g = new P(46, 30);
  g.ground(23, 27, 20, 3.0);
  // 상자 — 널 일곱 장에 모서리 각목, 그리고 발 둘
  g.rect(1, 18, 44, 26, W[4]);
  for (let x = 1; x <= 44; x++) {
    const inb = (x - 1) % 6.3;
    if (inb < 1) g.vline(x, 18, 26, W[6]);
    else if (inb < 2) g.vline(x, 18, 26, W[3]);
    if (h(x, 20, 71) < 0.18) g.px(x, 20 + (x % 4), W[5]);
  }
  g.rect(1, 18, 3, 26, W[3]); g.rect(42, 18, 44, 26, W[5]);
  g.hline(1, 44, 26, W[6]);
  for (const lx of [4, 37]) { g.rect(lx, 27, lx + 5, 28, W[6]); g.hline(lx, lx + 5, 27, W[5]); }
  topFace(g, 1, 44, 18, W, 6);              // 상자 테 윗면
  // 흙 — 테 안쪽에만. 위에서 훤히 보인다
  g.rect(4, 12, 41, 17, [112, 88, 64]);
  for (let i = 0; i < 30; i++) {            // 흙덩이
    const x = 4 + Math.floor(h(i, 1, 73) * 37), y = 12 + Math.floor(h(1, i, 74) * 6);
    const c = h(i, 2, 75) < 0.38 ? [92, 70, 50] : [134, 106, 78];
    g.px(x, y, c); if (h(i, 3, 76) < 0.4) g.px(x + 1, y, c);
  }
  // 포기 — 부채처럼 벌어진 잎, 잎맥 한 줄, 그 위에 꽃 한 송이
  const clump = (cx, top, s, kind) => {
    for (let k = -6; k <= 6; k++) {
      const hh = 7 - Math.abs(k) + (Math.abs(k) > 3 ? 2 : 0);
      for (let y = 0; y < hh; y++) {
        const yy = 11 - y;
        let c = k < 0 ? LEAF[1] : LEAF[2];
        if (y === hh - 1) c = LEAF[0];                  // 잎 끝이 빛을 받는다
        g.px(cx + k, yy, c);
      }
      if (Math.abs(k) % 3 === 1) g.px(cx + k, 11 - Math.floor((7 - Math.abs(k)) / 2), LEAF[0]);  // 잎맥
    }
    g.px(cx, 12, LEAF[2]); g.px(cx - 1, 12, LEAF[2]);
    const c = BLOOM[kind % 3];
    const dk = c.map(v => Math.round(v * 0.66));
    const lt = c.map(v => Math.min(255, v + 46));
    const cy = top + 3;
    // 꽃송이 — 7x7. 꽃잎 다섯 장이 겹쳐 둥글게 앉는다
    const F = ['..ppp..', '.ppppp.', 'pppppppppppp'.slice(0, 7), 'ppp0ppp',
               'ppppppp', '.ppppp.', '..ppp..'];
    for (let y = 0; y < 7; y++) for (let x = 0; x < 7; x++) {
      const ch = F[y][x];
      if (ch === '.') continue;
      if (ch === '0') { g.px(cx - 3 + x, cy - 3 + y, BLOOM[1]); continue; }
      g.px(cx - 3 + x, cy - 3 + y, (x + y >= 9) ? dk : c);
    }
    g.px(cx - 2, cy - 1, lt); g.px(cx - 1, cy - 2, lt);   // 왼위에 빛
    g.px(cx, cy, BLOOM[1]); g.px(cx + 1, cy, BLOOM[1]);   // 꽃술
    g.px(cx, cy + 1, BLOOM[1].map(v => Math.round(v * 0.8)));
    for (const [dx, dy] of [[-3, 0], [3, 0], [0, -3], [0, 3]])   // 꽃잎 사이 골
      g.px(cx + Math.round(dx * 0.66), cy + Math.round(dy * 0.66), dk);
    g.vline(cx, cy + 4, 11, LEAF[2]);        // 꽃대
    g.px(cx - 1, cy + 5, LEAF[1]);
  };
  clump(10, 4, 1, 0); clump(23, 2, 5, 1); clump(36, 5, 9, 2);
  // 곁잎 — 포기 사이를 메운다
  for (let i = 0; i < 14; i++) {
    const x = 4 + Math.floor(h(i, 5, 81) * 37);
    g.px(x, 11, LEAF[1]); if (h(i, 6, 82) < 0.5) g.px(x, 10, LEAF[0]);
  }
  return outline(g);
}

// ---- 손수레 ----
//
// 짐이 오간다는 표시. 우체국·잡화점 마당.
//
// 스물두 칸에 그렸을 때는 바퀴가 지름 여섯 칸이라, 0.5배로 줄면 살도
// 테도 사라지고 **밑에 붙은 검은 점 둘**이 됐다. 그래서 수레가 아니라
// 갈색 덩어리로 보였다. 손수레를 손수레로 만드는 건 **바퀴**다 —
// 바퀴가 읽히는 크기(지름 열 칸)까지 판을 키우고, 테·살·바퀴통을
// 따로 그린다. 그리고 짐칸은 **비우지 않는다**: 빈 상자는 상자고,
// 짚과 자루가 실려야 「짐을 나르는 것」이 된다.
function cart() {
  const g = new P(56, 44);
  g.ground(28, 40, 24, 3.4);
  // 굴대 — 두 바퀴를 잇는다. **바퀴보다 먼저** 깔아야 한다. 나중에 그으면
  // 바퀴통 위를 가로질러, 바퀴가 굴대에 꿰인 게 아니라 굴대에 가려진다
  g.rect(13, 29, 43, 31, IR[3]); g.hline(13, 43, 29, IR[2]);
  g.hline(13, 43, 31, IR[4]);
  // 바퀴 — **속이 비어 있다.** 살 사이로 뒤가 비쳐야 바퀴로 읽힌다.
  // 열 칸에서는 살이 뭉갰고, 열넉 칸이면 테·살·바퀴통이 다 갈린다
  const wheel = (cx, cy) => {
    g.disc(cx, cy, 9.6, 9.6, W[5]);          // 쇠테
    g.disc(cx, cy, 8.4, 8.4, W[2]);          // 나무 테
    for (let y = -9; y <= 9; y++) for (let x = -9; x <= 9; x++)
      if ((x * x + y * y) <= 6.6 * 6.6) g.clr(cx + x, cy + y);   // 속을 비운다
    for (let a2 = 0; a2 < 10; a2++) {        // 살 열
      const t = a2 / 10 * Math.PI * 2 + 0.25;
      for (let r = 0; r <= 7.2; r += 0.3) {
        const lit = Math.cos(t) < 0 || Math.sin(t) < 0;
        g.px(cx + Math.cos(t) * r, cy + Math.sin(t) * r, lit ? W[3] : W[4]);
      }
      g.px(cx + Math.cos(t) * 7.4, cy + Math.sin(t) * 7.4, W[5]);   // 살이 테에 박힌 자리
    }
    g.disc(cx, cy, 3.2, 3.2, IR[2]);         // 바퀴통
    g.disc(cx, cy, 2.0, 2.0, IR[3]);
    g.disc(cx, cy, 0.9, 0.9, IR[4]);
    g.px(cx - 2, cy - 2, IR[0]); g.px(cx + 2, cy + 2, IR[4]);
    for (let a2 = 0; a2 < 44; a2++) {        // 테 — 왼위는 빛, 오른아래는 그늘
      const t = a2 / 44 * Math.PI * 2;
      const lit = Math.cos(t) < -0.2 || Math.sin(t) < -0.4;
      g.px(cx + Math.cos(t) * 9.1, cy + Math.sin(t) * 9.1, lit ? W[3] : W[6]);
      g.px(cx + Math.cos(t) * 7.9, cy + Math.sin(t) * 7.9, lit ? W[0] : W[4]);
      if (a2 % 5 === 0) g.px(cx + Math.cos(t) * 8.5, cy + Math.sin(t) * 8.5, IR[3]);  // 테를 문 못
    }
  };
  wheel(14, 30); wheel(42, 30);
  // 짐칸 — 앞널 넉 줄 + 깊은 윗면(= 안이 보인다)
  g.rect(2, 22, 53, 27, W[4]);
  for (let x = 2; x <= 53; x++) {
    const inb = (x - 2) % 7;
    if (inb === 0) g.vline(x, 22, 27, W[6]);
    else if (inb === 1) g.vline(x, 22, 27, W[3]);
    if (h(x, 24, 88) < 0.2) g.px(x, 24 + (x % 3), W[5]);
  }
  g.hline(2, 53, 27, W[6]);
  g.rect(0, 21, 2, 28, W[3]); g.rect(53, 21, 55, 28, W[5]);
  topFace(g, 2, 53, 22, W, 15);
  g.rect(5, 8, 50, 20, W[5]);                // 짐칸 속 그늘
  g.hline(5, 50, 8, W[6]);
  for (let x = 5; x <= 50; x += 7) g.vline(x, 9, 19, W[6]);   // 안쪽 널
  // 실린 짐 — 짚 한 아름과 자루 둘, 그리고 궤짝 하나
  for (let x = 7; x <= 24; x++) {
    const hh = 4 + Math.round(h(x, 1, 84) * 4);
    for (let k = 0; k < hh; k++) g.px(x, 12 - k, k === hh - 1 ? STRAW[0] : STRAW[2]);
    if (h(x, 2, 85) < 0.3) g.px(x, 13, STRAW[3]);
    if (h(x, 3, 86) < 0.22) g.px(x, 12 - Math.floor(h(x, 4, 87) * 3), STRAW[1]);
  }
  for (let i = 0; i < 11; i++) g.px(8 + i * 2, 6 - (i % 2), STRAW[1]);
  const sackAt = (cx, top, hw) => {
    for (let y = top; y <= 19; y++) {
      const t = (y - top) / (19 - top);
      const w = Math.round(hw * (0.5 + Math.sin(Math.min(1, t * 1.1) * Math.PI * 0.8) * 0.55));
      for (let x = cx - w; x <= cx + w; x++)
        g.px(x, y, x <= cx - w + 1 ? SACK[0] : (x >= cx + w - 1 ? SACK[2] : SACK[1]));
      if ((y - top) % 3 === 1) g.px(cx - Math.round(w * 0.4), y, SACK[2]);
    }
    g.rect(cx - 2, top - 4, cx + 2, top - 1, SACK[1]);
    g.vline(cx - 2, top - 4, top - 1, SACK[0]);
    g.hline(cx - 3, cx + 3, top - 3, W[3]);   // 새끼줄
    g.hline(cx - 3, cx + 3, top - 2, W[5]);
    g.px(cx + 4, top - 1, W[4]);
  };
  sackAt(33, 9, 6); sackAt(44, 12, 5);
  // 짐칸 옆널의 못과 쇠 귀
  for (const nx of [3, 52]) { g.px(nx, 22, IR[1]); g.px(nx, 25, IR[1]); }
  for (const [bx, by] of [[2, 22], [50, 22]]) {
    g.rect(bx, by, bx + 2, by + 2, IR[2]);
    g.px(bx + 1, by + 1, IR[0]);
  }
  // 손잡이 — 짐칸에서 뒤로 뻗어 위로 꺾인다. 두 자루가 나란하다
  for (let k = 0; k < 8; k++) {
    g.px(53 + (k >> 2), 21 - k, W[3]); g.px(54 + (k >> 2), 21 - k, W[5]);
  }
  g.rect(51, 11, 55, 13, W[2]); g.hline(51, 55, 13, W[5]);
  for (let x = 51; x <= 55; x += 2) g.px(x, 12, W[4]);       // 미끄럼 막는 홈
  // 앞 받침대 — 세워 뒀다는 표시. 없으면 수레가 공중에 뜬다
  g.rect(2, 28, 5, 38, W[4]); g.vline(2, 28, 38, W[3]); g.vline(5, 28, 38, W[5]);
  g.rect(0, 38, 8, 40, W[5]); g.hline(0, 8, 38, W[3]); g.hline(0, 8, 40, W[6]);
  return outline(g);
}


// ---- 책 무더기 ----
//
// 도서관 마당. 아이콘 한 장이 아니라 **쌓인 것**이라야 내놓은 책이 된다.
// 열넉 칸에서는 한 권이 두 칸이라 색동 줄무늬 벽돌이었고, 스물넉 칸에서
// 책배와 책등이 들어왔다. 서른넉 칸이면 **표지의 테두리 금박과 책배의
// 종이 켜**까지 보인다 — 그제야 「책」이지 「색 띠」가 아니다.
function bookstack() {
  const g = new P(34, 28);
  g.ground(17, 25, 14, 2.6);
  const GOLD = [232, 196, 96];
  // 한 권 — 앞이 책배(종이 켜), 위가 표지, 한쪽 끝이 책등
  const book = (x0, x1, y, c, flip) => {
    const dk = c.map(v => Math.round(v * 0.55));
    const lt = c.map(v => Math.min(255, v + 40));
    g.rect(x0, y - 4, x1, y, c);
    g.hline(x0, x1, y - 5, lt);                   // 윗면(표지)
    g.hline(x0 + 1, x1 - 1, y - 6, c);            // 표지가 살짝 튀어나온다
    g.hline(x0, x1, y, dk);                       // 아랫변 턱
    // 책배 — 종이 켜. 이 흰 줄이 책의 이름표다
    for (let y2 = y - 3; y2 <= y - 1; y2++)
      for (let x = x0 + 2; x <= x1 - 2; x++)
        g.px(x, y2, (x % 2 === 0) ? PAPER[0] : PAPER[1]);
    for (let x = x0 + 2; x <= x1 - 2; x += 4) g.px(x, y - 2, PAPER[2]);
    // 책등 — 반대쪽 끝. 천으로 싸고 금박 줄이 둘
    const sx = flip ? x1 : x0;
    const dir = flip ? -1 : 1;
    g.rect(Math.min(sx, sx + dir), y - 4, Math.max(sx, sx + dir), y, c);
    g.vline(sx + dir * 2, y - 4, y, dk);
    g.px(sx, y - 4, GOLD); g.px(sx + dir, y - 4, GOLD);
    g.px(sx, y - 1, GOLD); g.px(sx + dir, y - 1, GOLD);
    g.px(sx, y - 3, lt);
    // 표지 테두리 금박 — 윗면 가장자리를 한 줄 두른다
    g.px(x0 + 1, y - 5, GOLD); g.px(x1 - 1, y - 5, GOLD);
  };
  const rows = [[1, 31, 25, 0, false], [3, 29, 19, 1, true],
                [1, 28, 13, 2, false], [5, 26, 7, 3, true]];
  rows.forEach(([x0, x1, y, ci, f]) => book(x0, x1, y, BOOK[ci], f));
  // 맨 위 펼쳐 둔 책 — 두 쪽이 벌어지고 가운데가 접혔다
  g.rect(8, 1, 24, 5, PAPER[0]);
  g.hline(8, 24, 0, PAPER[1]);
  g.hline(8, 24, 5, PAPER[2]);
  g.vline(16, 0, 5, PAPER[2]); g.vline(17, 0, 5, PAPER[1]);   // 접힌 등
  for (const ly of [1, 2, 3, 4]) {                            // 글줄
    for (let x = 9; x <= 14; x += 2) g.px(x, ly, PAPER[2]);
    for (let x = 19; x <= 23; x += 2) g.px(x, ly, PAPER[2]);
  }
  g.px(7, 3, PAPER[1]); g.px(25, 3, PAPER[1]);                // 넘어가는 쪽
  g.px(6, 4, PAPER[2]); g.px(26, 4, PAPER[2]);
  // 책갈피 두 오라기 — 붉은 끈이 삐져나온다
  g.vline(28, 14, 19, BOOK[0]); g.px(28, 20, BOOK[0].map(v => Math.round(v * 0.6)));
  g.vline(4, 20, 24, BOOK[1]);
  return outline(g);
}

// ---- 표본 선반 ----
//
// 연금 연구소 마당. 유리병에 담아 세워 둔 것들.
// 열여덟 칸에서는 병 하나가 3x4칸이라 색점 다섯이었고, 서른 칸에서
// 목·마개·액면이 들어왔다. 마흔둘이면 병 하나에 **어깨의 곡선 ·
// 유리에 비친 창 · 담긴 것이 가라앉은 자리 · 라벨**까지 들어간다.
function specimen() {
  const g = new P(42, 42);
  g.ground(21, 39, 18, 3.2);
  // 틀 — 기둥 둘에 선반 셋. 뒤판은 널을 세로로 댄다
  g.rect(5, 2, 36, 38, W[5]);
  for (let x = 5; x <= 36; x++) if ((x - 5) % 6 === 0) g.vline(x, 2, 38, W[6]);
  for (let x = 5; x <= 36; x++) if ((x - 5) % 6 === 1) g.vline(x, 2, 38, W[4]);
  g.rect(1, 0, 4, 39, W[4]); g.vline(1, 0, 39, W[3]); g.vline(4, 0, 39, W[6]);
  g.rect(37, 0, 40, 39, W[4]); g.vline(37, 0, 39, W[5]); g.vline(40, 0, 39, W[6]);
  g.rect(1, 0, 40, 1, W[3]); g.hline(1, 40, 0, W[2]);   // 갓
  g.hline(1, 40, 2, W[6]);
  // 유리병 하나 — 어깨가 둥글고, 왼쪽에 창이 비치고, 담긴 것이 가라앉는다
  const jar = (x, y, c, tall) => {
    const hgt = tall ? 10 : 7, x1 = x + 5;
    const GL = [96, 132, 152];
    for (let yy = y - hgt; yy <= y; yy++) {
      const t = (yy - (y - hgt)) / hgt;
      const nar = t < 0.16 ? 1 : 0;             // 어깨 — 위가 한 칸 좁다
      for (let xx = x + nar; xx <= x1 - nar; xx++) g.px(xx, yy, GL);
    }
    // 담긴 것 — 아래 3/4. 액면이 밝다
    const lv = y - Math.round(hgt * 0.72);
    g.rect(x, lv, x1, y - 1, c);
    g.hline(x, x1, lv, c.map(v => Math.min(255, v + 50)));
    g.hline(x, x1, lv + 1, c);
    for (let i = 0; i < 4; i++)                 // 가라앉은 알갱이
      g.px(x + 1 + Math.floor(h(i, x, 141) * 4), y - 1 - Math.floor(h(x, i, 142) * 2),
        c.map(v => Math.round(v * 0.6)));
    // 유리 — 왼쪽에 창이 비친 흰 줄, 오른쪽 아래에 어두운 테
    g.vline(x, lv, y - 1, [168, 200, 216]);
    g.px(x + 1, lv + 1, [255, 255, 255]); g.px(x + 1, lv + 2, [232, 244, 252]);
    g.vline(x1, lv, y - 1, [56, 80, 96]);
    g.hline(x, x1, y, [40, 56, 68]);            // 밑동
    // 목과 마개
    g.rect(x + 1, y - hgt - 2, x1 - 1, y - hgt - 1, GL);
    g.px(x + 1, y - hgt - 2, [168, 200, 216]);
    g.rect(x + 1, y - hgt - 4, x1 - 1, y - hgt - 3, W[4]);
    g.hline(x + 1, x1 - 1, y - hgt - 4, W[2]);
    g.px(x1 - 1, y - hgt - 3, W[5]);
    // 라벨 — 병 배에 붙인 종잇조각
    g.rect(x + 1, y - 3, x1 - 1, y - 2, PAPER[0]);
    g.px(x + 2, y - 3, PAPER[2]); g.px(x + 4, y - 3, PAPER[2]);
  };
  // 선반 셋 — 판 위에 물건, 판 밑에 그늘
  for (const sy of [17, 28, 38]) {
    g.rect(5, sy, 36, sy + 1, W[4]);
    topFace(g, 5, 36, sy, W, 4);
    g.hline(5, 36, sy + 1, W[6]);
    g.hline(5, 36, sy + 2, W[6]);
  }
  jar(7, 16, LEAF[1], true); jar(16, 16, BLOOM[0], false); jar(26, 16, AQUA[1], true);
  jar(7, 27, [168, 120, 200], false); jar(18, 27, BLOOM[1], true);
  // 아래 칸 — 돌 표본과 마른 잎 묶음, 그리고 작은 절구
  g.disc(11, 35, 4.0, 3.0, ST[3]); g.disc(11, 34, 2.6, 1.8, ST[1]);
  g.px(8, 36, ST[5]); g.px(14, 36, ST[5]); g.px(10, 32, ST[0]);
  for (let k = 0; k < 7; k++) g.px(20 + k, 35 - (k >> 1), LEAF[2]);
  g.px(25, 32, LEAF[0]); g.px(26, 32, LEAF[1]); g.px(26, 31, LEAF[0]);
  g.rect(19, 37, 27, 37, W[4]);
  g.disc(32, 36, 3.0, 2.2, ST[2]); g.disc(32, 35, 2.0, 1.2, ST[4]);
  g.vline(34, 31, 34, W[4]);                    // 공이
  // 위 칸 — 펼쳐 둔 공책과 깃펜
  g.rect(28, 23, 34, 27, PAPER[0]);
  g.hline(28, 34, 22, PAPER[1]);
  for (const ly of [24, 25, 26]) for (let x = 29; x <= 33; x += 2) g.px(x, ly, PAPER[2]);
  for (let k = 0; k < 6; k++) g.px(34 - k, 21 - k, k > 3 ? PAPER[0] : PAPER[1]);
  return outline(g);
}


// ---- 나무 궤짝 ----
//
// 가게 마당에 제일 많이 놓이는 것. 예전에는 가방 아이콘(old_box·chest)을
// 그대로 갖다 놨는데, 그건 **뚜껑 열린 보물상자**라 어느 가게에 놓아도
// 「누가 보물을 두고 갔나」가 됐다. 짐은 판때기를 못으로 친 궤짝이다.
//
// 그런데 16칸 격자에 그려 놓고 기계로 1.4배 늘렸더니, 판 사이 틈이
// 뭉개져 **줄무늬 진 둔덕**이 됐다 — 마당에 놓으니 궤짝인지 벌통인지
// 알 수가 없다는 말을 들었다. 자루와 같은 처방이다: 제 격자에 크게 그린다.
//
// 궤짝을 궤짝으로 만드는 것은 셋이다.
//   ① 판 사이의 **검은 틈**  — 아래 판의 윗변이 밝아 틈이 깊어진다
//   ② 모서리 **세로 덧댐**   — 네 귀에 세워 댄 각목. 상자의 뼈다
//   ③ 귀의 **쇠 거멀못**     — 나무 상자에 쇠가 한 점 박히면 짐칸이 된다
// 위에 작은 궤짝을 하나 더 얹던 것은 지웠다. 실루엣이 둔덕이 되는 주범이
// 그것이었다 — 하나를 또렷하게가 둘을 흐리게보다 낫다.
function crate() {
  const g = new P(42, 38);
  g.ground(21, 34, 19, 3.6);
  // 정면 + 뚜껑 윗면
  g.rect(3, 15, 38, 34, W[4]);
  topFace(g, 3, 38, 15, W, 13);
  // 판 넉 켜 — 틈은 검고, 그 아래 판의 윗변은 밝다
  const plankRow = (y0, y1) => {
    g.hline(3, 38, y0, W[2]);                       // 윗변 = 빛
    g.rect(3, y0 + 1, 38, y1 - 1, W[4]);
    g.hline(3, 38, y1 - 1, W[5]);
    g.hline(3, 38, y1, W[5]);                       // 아랫변 = 턱
  };
  plankRow(16, 20); g.hline(3, 38, 21, W[6]);
  plankRow(22, 26); g.hline(3, 38, 27, W[6]);
  plankRow(28, 32); g.hline(3, 38, 33, W[6]);
  // 결 — 판마다 서너 줄. 옹이도 둘
  for (let i = 0; i < 22; i++) {
    const x = 5 + Math.floor(h(i, 1, 91) * 32);
    const y = [17, 19, 23, 25, 29, 31][i % 6];
    const len = 2 + Math.floor(h(i, 2, 92) * 4);
    for (let k = 0; k < len && x + k <= 37; k++) g.px(x + k, y, W[5]);
  }
  for (const [kx, ky] of [[28, 18], [12, 30]]) {
    g.disc(kx, ky, 2.2, 1.6, W[5]);
    g.disc(kx, ky, 1.2, 0.9, W[6]);
    g.px(kx - 1, ky - 1, W[4]);
  }
  // 모서리 덧댐 — 왼쪽은 빛, 오른쪽은 그늘. 세로 각목이라 결도 세로다
  g.rect(3, 16, 6, 34, W[3]); g.vline(3, 16, 34, W[2]); g.vline(6, 16, 34, W[5]);
  g.rect(35, 16, 38, 34, W[5]); g.vline(38, 16, 34, W[6]); g.vline(35, 16, 34, W[4]);
  for (let y = 18; y <= 32; y += 4) { g.px(4, y, W[4]); g.px(37, y, W[6]); }
  // 밑동 — 바닥에 눌린 자리. 받침목 두 도막이 궤짝을 흙에서 띄운다
  g.hline(3, 38, 34, W[6]);
  g.rect(1, 33, 40, 35, W[5]); g.hline(1, 40, 33, W[3]); g.hline(1, 40, 35, W[6]);
  for (const sx of [5, 33]) { g.rect(sx, 36, sx + 4, 37, W[6]); g.hline(sx, sx + 4, 36, W[5]); }
  // 쇠 거멀못 네 귀 — 접힌 쇠판에 대갈못 셋
  for (const [bx, by, fx] of [[3, 16, 1], [35, 16, -1], [3, 29, 1], [35, 29, -1]]) {
    g.rect(bx, by, bx + 3, by + 4, IR[2]);
    g.hline(bx, bx + 3, by, IR[1]); g.hline(bx, bx + 3, by + 4, IR[4]);
    g.vline(fx > 0 ? bx : bx + 3, by, by + 4, IR[1]);
    g.px(bx + 1, by + 1, IR[0]); g.px(bx + 2, by + 3, IR[0]);
  }
  for (const nx of [8, 33]) for (const ny of [21, 27]) { g.px(nx, ny, IR[1]); g.px(nx, ny + 1, IR[4]); }
  // 뚜껑 — 판 셋에 이음매, 그리고 낙인 찍은 표
  for (const ly of [6, 10]) { g.hline(6, 35, ly, W[5]); g.hline(6, 35, ly + 1, W[2]); }
  g.rect(15, 2, 26, 6, W[5]);
  g.hline(15, 26, 2, W[6]); g.vline(15, 2, 6, W[6]);
  g.hline(15, 26, 6, W[3]);
  g.px(18, 3, W[2]); g.px(19, 4, W[2]); g.px(20, 3, W[2]);   // 낙인 무늬
  g.px(22, 3, W[2]); g.px(22, 4, W[2]); g.px(23, 4, W[2]);
  // 걸쇠 — 뚜껑과 몸을 잇는 쇠. 궤짝이 「여닫는 것」이 된다
  g.rect(19, 13, 22, 17, IR[3]);
  g.hline(19, 22, 13, IR[1]); g.hline(19, 22, 17, IR[4]);
  g.rect(20, 15, 21, 16, IR[0]);
  return outline(g);
}


// ---- 마대 자루 ----
//
// 궤짝만 늘어놓으면 마당이 네모투성이가 된다. 자루는 **둥글고 늘어져**
// 있어서, 같은 짐인데도 옆에 놓으면 둘 다 살아난다.
//
// 두 번 틀렸다.
//   1판 18x14 격자를 기계로 늘림 — 배의 곡선이 계단으로 부서졌다
//   2판 25x20에 직접 그렸는데 **위로 갈수록 뾰족했다** — 개미집 둘
//
// 자루는 **뾰족하지 않다.** 곡식이 들어차 아래가 불룩하고, 그 무게에
// 눌려 밑동이 평평하게 퍼지며, 목만 오므려 묶는다. 실루엣으로 치면
// 「배 큰 항아리 위에 작은 매듭」이지 원뿔이 아니다. 그리고 그 매듭이
// 자루의 이름표다 — 새끼줄이 나무빛으로 또렷해야 자루가 된다.
function sack() {
  const g = new P(46, 36);
  const one = (cx, top, hw, seed) => {
    const base = 33;
    for (let y = top; y <= base; y++) {
      const t = (y - top) / (base - top);
      // 배 — 아래 3/4 지점이 제일 불룩하고 밑동에서 살짝 오므린다
      const bulge = Math.sin(Math.min(1, t * 1.12) * Math.PI * 0.78);
      let w = Math.round(hw * (0.46 + bulge * 0.58));
      if (y >= base - 1) w -= 1;
      for (let x = cx - w; x <= cx + w; x++) {
        let c = SACK[1];
        if (x <= cx - w + 2) c = SACK[0];               // 왼쪽 = 빛
        else if (x >= cx + w - 2) c = SACK[2];          // 오른쪽 = 그늘
        if (y >= base - 1) c = SACK[3];                 // 눌려 퍼진 밑동
        g.px(x, y, c);
      }
      // 주름 — 목에서 배로 흘러내린다. 두 줄기가 갈라진다
      if (y > top + 1 && y < base - 1) {
        if ((y - top) % 3 === 1) g.px(cx - Math.round(w * 0.42), y, SACK[2]);
        if ((y - top) % 4 === 3) g.px(cx + Math.round(w * 0.5), y, SACK[3]);
        if ((y - top) % 5 === 2) g.px(cx - Math.round(w * 0.1), y, SACK[2]);
      }
    }
    // 오므린 목 — 배보다 훨씬 좁다. 이 잘록함이 자루를 자루로 만든다
    g.rect(cx - 4, top - 5, cx + 4, top - 1, SACK[1]);
    g.rect(cx + 3, top - 5, cx + 4, top - 1, SACK[2]);
    g.rect(cx - 4, top - 5, cx - 3, top - 1, SACK[0]);
    // 새끼줄 — **나무빛**이라야 마대 위에서 보인다. 두 가닥 꼬아 감고 매듭
    g.hline(cx - 5, cx + 5, top - 4, W[3]);
    g.hline(cx - 5, cx + 5, top - 3, W[5]);
    g.hline(cx - 5, cx + 5, top - 2, W[4]);
    for (let x = cx - 5; x <= cx + 5; x += 2) g.px(x, top - 3, W[2]);   // 꼬임
    g.px(cx - 6, top - 4, W[4]); g.px(cx - 6, top - 3, W[5]);           // 매듭
    g.px(cx + 6, top - 2, W[4]); g.px(cx + 7, top - 1, W[5]);           // 늘어뜨린 끝
    g.px(cx + 7, top, W[5]); g.px(cx + 8, top + 1, W[4]);
    // 여민 아가리 — 새끼줄 위로 천이 벌어진다
    g.rect(cx - 4, top - 11, cx + 4, top - 5, SACK[1]);
    g.rect(cx - 4, top - 11, cx - 3, top - 5, SACK[0]);
    g.rect(cx + 3, top - 11, cx + 4, top - 5, SACK[2]);
    g.px(cx - 2, top - 11, SACK[0]); g.px(cx + 2, top - 11, SACK[2]);
    g.rect(cx - 1, top - 11, cx + 1, top - 9, SACK[3]);   // 벌어진 틈 — 속이 어둡다
    g.px(cx, top - 10, [72, 58, 36]);
    if (h(cx, seed, 93) < 0.6) g.px(cx + 5, top - 8, SACK[2]);
    // 마대의 씨줄날줄 — 성긴 격자 자국
    for (let i = 0; i < 16; i++) {
      const x = cx - hw + 2 + Math.floor(h(i, seed, 95) * (hw * 2 - 3));
      const y = top + 2 + Math.floor(h(seed, i, 96) * (base - top - 4));
      g.px(x, y, SACK[2]);
      if (h(i, seed, 99) < 0.4) g.px(x + 1, y, SACK[2]);
    }
    // 자루에 박음질한 이음선 한 줄 — 옆구리를 따라 내려온다
    for (let y = top + 3; y < base - 2; y += 2) g.px(cx - Math.round(hw * 0.75), y, SACK[3]);
  };
  g.ground(13, 33, 12, 3.0);
  g.ground(32, 33, 11, 2.8);
  one(13, 16, 11, 3);
  one(32, 20, 9, 9);
  // 흘린 낟알 — 자루에 곡식이 들었다는 유일한 증거
  for (let i = 0; i < 11; i++) {
    const x = 2 + Math.floor(h(i, 7, 97) * 42), y = 33 + (h(i, 8, 98) < 0.5 ? 0 : 1);
    g.px(x, y, STRAW[0]);
    if (h(i, 9, 99) < 0.35) g.px(x + 1, y, STRAW[1]);
  }
  return outline(g);
}


// ---- 작업대 ----
//
// 처음에는 「연장 걸이」로 그렸다 — 기둥 둘에 가로대. 그런데 그건 무기
// 거치대와 **같은 실루엣**이라, 마당에 둘을 놓으면 어느 쪽이 어느 쪽인지
// 알 수가 없었다. 물건은 서로 **다르게 생겨야** 구분된다.
//
// 그래서 작업대로 바꿨는데, 스무 칸 격자에서는 상판 위의 바이스도 망치도
// 두세 칸이라 0.5배로 줄면 **상판 위의 회색 점 몇**이었다 — 그냥 탁자였다.
// 서른두 칸으로 키우고 연장을 하나씩 알아보게 그린다: 바이스(물림쇠),
// 망치, 걸어 둔 톱과 집게, 그리고 상판에 흩어진 쇳가루와 못.
function toolrack() {
  const g = new P(46, 40);
  g.ground(23, 37, 20, 3.2);
  // 다리 넷 — 앞 둘은 굵고 뒤 둘은 한 칸 안쪽으로 얇게. 발밑에 굄돌
  for (const lx of [3, 36]) {
    g.rect(lx, 20, lx + 6, 36, W[4]);
    g.vline(lx, 20, 36, W[3]); g.rect(lx + 4, 20, lx + 6, 36, W[5]);
    g.hline(lx, lx + 6, 36, W[6]);
    for (let y = 23; y <= 34; y += 5) g.px(lx + 2, y, W[5]);
    g.rect(lx - 1, 37, lx + 7, 38, ST[4]);      // 굄돌
    g.hline(lx - 1, lx + 7, 37, ST[2]);
  }
  g.rect(9, 27, 36, 30, W[5]);                  // 다리 사이 가로 버팀
  g.hline(9, 36, 27, W[3]); g.hline(9, 36, 30, W[6]);
  for (let x = 11; x <= 34; x += 6) g.px(x, 29, W[6]);
  // 상판 — 두껍다. 깊은 윗면 + 앞 모서리 + 켜켜이 팬 자국
  g.rect(0, 18, 45, 21, W[4]);
  topFace(g, 0, 45, 18, W, 10);
  g.hline(0, 45, 21, W[6]);
  g.hline(0, 45, 20, W[5]);
  g.hline(0, 45, 19, W[3]);
  for (let x = 1; x <= 44; x++) {
    if (h(x, 0, 131) < 0.26) g.px(x, 12 + (x % 4), W[1]);      // 대패 자국
    if (h(x, 1, 132) < 0.14) g.px(x, 14 + (x % 3), W[5]);      // 벤 자국
  }
  for (const nx of [4, 22, 41]) { g.px(nx, 19, IR[2]); g.px(nx, 20, IR[4]); }   // 못
  // 상판 위 ① 바이스 — 턱 둘 사이에 벌겋게 단 쇠막대가 물려 있다
  g.rect(4, 9, 12, 15, IR[2]);
  g.hline(4, 12, 9, IR[0]); g.hline(4, 12, 15, IR[4]);
  g.rect(4, 9, 5, 15, IR[1]); g.rect(11, 9, 12, 15, IR[3]);    // 물림턱 둘
  g.rect(7, 4, 9, 9, IR[3]);                                   // 물린 쇠막대
  g.rect(7, 2, 9, 3, FI[2]); g.px(8, 1, FI[1]);                // 벌겋게 단 끝
  g.px(6, 2, FI[3]); g.px(10, 3, FI[3]);
  g.rect(13, 11, 15, 12, IR[3]); g.px(16, 11, IR[2]); g.px(16, 12, IR[4]);  // 조임 손잡이
  g.rect(5, 16, 11, 17, IR[4]);                                // 받침
  // 상판 위 ② 망치 — 자루가 나무, 머리가 쇠. 자루 끝에 가죽끈
  g.rect(23, 15, 34, 17, W[3]);
  g.hline(23, 34, 15, W[2]); g.hline(23, 34, 17, W[5]);
  g.rect(19, 11, 25, 17, IR[2]);
  g.hline(19, 25, 11, IR[0]); g.hline(19, 25, 17, IR[4]);
  g.rect(17, 12, 18, 16, IR[3]);                               // 뒤쪽 갈래
  g.px(34, 16, W[5]); g.px(35, 16, W[4]);
  // 상판 위 ③ 못과 쇳가루, 그리고 연장통
  for (let i = 0; i < 11; i++) {
    const x = 26 + Math.floor(h(i, 1, 133) * 12);
    g.px(x, 13 + (i % 2), IR[3]);
    if (h(i, 2, 134) < 0.55) g.px(x + 1, 13 + (i % 2), IR[4]);
  }
  g.rect(37, 9, 44, 17, W[5]);
  g.hline(37, 44, 9, W[3]); g.hline(37, 44, 17, W[6]);
  g.vline(40, 5, 9, W[4]); g.vline(41, 5, 9, W[5]);            // 손잡이
  g.hline(38, 43, 5, W[4]);
  g.px(38, 8, IR[2]); g.px(43, 7, IR[1]); g.px(42, 8, W[2]);   // 삐져나온 연장
  // 상판 밑에 걸어 둔 것 ④ 톱 — 날에 톱니가 보여야 톱이다
  g.rect(12, 23, 14, 34, IR[2]); g.vline(12, 23, 34, IR[1]);
  for (let y = 24; y <= 33; y++) g.px(15, y, y % 2 ? IR[3] : IR[1]);
  g.rect(11, 21, 15, 23, W[4]); g.hline(11, 15, 21, W[2]);     // 손잡이
  g.px(13, 22, W[6]);
  // ⑤ 집게
  g.vline(21, 23, 33, IR[3]); g.vline(24, 23, 33, IR[3]);
  g.px(22, 32, IR[2]); g.px(23, 32, IR[2]); g.px(22, 33, IR[4]); g.px(23, 33, IR[4]);
  g.px(21, 22, IR[4]); g.px(24, 22, IR[4]);
  // ⑥ 줄자 아닌 **쇠자** 한 자루와 걸린 가죽 앞치마
  g.rect(29, 23, 30, 32, IR[1]); g.vline(30, 23, 32, IR[3]);
  for (let y = 24; y <= 31; y += 2) g.px(29, y, IR[4]);
  g.rect(33, 22, 39, 31, [124, 88, 56]);
  g.hline(33, 39, 22, [156, 112, 72]);
  g.rect(34, 32, 38, 33, [124, 88, 56]);
  g.px(33, 31, [92, 64, 40]); g.px(39, 31, [92, 64, 40]);
  return outline(g);
}


// ---- 내보내기 ----
// 떨어진 가지 — 주우면 목재가 된다. 나무 밑에 떨어져 있는 잔가지라
// 한 칸짜리다: 비스듬한 굵은 가지 하나 + 갈라진 잔가지 둘 + 잎 몇 장.
// 물건이 작을수록 실루엣이 이름을 말해야 한다 — 갈라짐이 곧 「가지」다
function branch() {
  const g = new P(22, 14);
  g.ground(11, 12, 9, 2.0);
  // 굵은 가지 — 왼아래에서 오른위로
  for (let k = 0; k < 14; k++) {
    const x = 3 + k, y = 10 - (k >> 1);
    g.px(x, y, W[3]); g.px(x, y + 1, W[5]);
    if (k % 4 === 0) g.px(x, y, W[2]);              // 결
  }
  g.px(2, 11, W[4]); g.px(2, 12, W[6]);             // 부러진 밑동
  g.px(3, 12, W[5]);
  // 갈라진 잔가지 둘
  for (let k = 0; k < 4; k++) g.px(9 + k, 7 - k, W[4]);
  for (let k = 0; k < 3; k++) g.px(14 + k, 8 + (k >> 1), W[4]);
  // 아직 붙어 있는 잎 몇 장
  g.px(12, 3, LEAF[1]); g.px(13, 3, LEAF[0]); g.px(13, 2, LEAF[0]);
  g.px(17, 4, LEAF[1]); g.px(18, 5, LEAF[2]);
  return outline(g);
}

const OUTS = {};
OUTS['forage_branch'] = branch().render();
for (let f = 0; f < 4; f++) OUTS['deco_forge_' + f] = forge(f).render();
OUTS['deco_anvil'] = anvil().render();
OUTS['deco_weaponrack'] = weaponrack().render();
OUTS['deco_crate'] = crate().render();
OUTS['deco_sack'] = sack().render();
OUTS['deco_toolrack'] = toolrack().render();
OUTS['deco_logpile'] = logpile().render();
OUTS['deco_trough'] = trough(true).render();
OUTS['deco_feedbox'] = trough(false).render();
OUTS['deco_hay'] = hay().render();
OUTS['deco_netrack'] = netrack().render();
OUTS['deco_planter'] = planter().render();
OUTS['deco_cart'] = cart().render();
OUTS['deco_bookstack'] = bookstack().render();
OUTS['deco_specimen'] = specimen().render();

// 미리보기 — 잔디 위에 게임과 같은 크기(0.5배)로 늘어놓는다
function preview() {
  const names = Object.keys(OUTS);
  const CW = 96, CH = 132, cols = 7;
  const rows = Math.ceil(names.length / cols);
  const im = new PNG({ width: CW * cols, height: CH * rows });
  for (let i = 0; i < im.data.length; i += 4) {
    im.data[i] = 104; im.data[i + 1] = 158; im.data[i + 2] = 82; im.data[i + 3] = 255;
  }
  names.forEach((n, idx) => {
    const src = OUTS[n];
    const ox = (idx % cols) * CW + Math.round((CW - src.width / 2) / 2);
    const oy = Math.floor(idx / cols) * CH + (CH - 8 - Math.round(src.height / 2));
    for (let y = 0; y < Math.round(src.height / 2); y++)
      for (let x = 0; x < Math.round(src.width / 2); x++) {
        const si = ((y * 2) * src.width + x * 2) * 4, a = src.data[si + 3] / 255;
        if (a === 0) continue;
        const dx = ox + x, dy = oy + y;
        if (dx < 0 || dy < 0 || dx >= im.width || dy >= im.height) continue;
        const di = (dy * im.width + dx) * 4;
        for (let c = 0; c < 3; c++)
          im.data[di + c] = Math.round(src.data[si + c] * a + im.data[di + c] * (1 - a));
      }
  });
  return im;
}

if (INSTALL) {
  for (const k in OUTS) fs.writeFileSync(SPR + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('설치: sprites/deco_*.png ' + Object.keys(OUTS).length + '장');
  console.log('  다음에 반드시 -> python3 make_import.py');
} else {
  for (const k in OUTS) fs.writeFileSync(REF + 'proposed_' + k + '.png', PNG.sync.write(OUTS[k]));
  console.log('제안: ref/proposed_deco_*.png ' + Object.keys(OUTS).length + '장');
}
fs.writeFileSync(REF + 'preview_props.png', PNG.sync.write(preview()));
console.log('미리보기: ref/preview_props.png');
