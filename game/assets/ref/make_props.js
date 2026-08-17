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
const ST = [[216, 210, 198], [176, 170, 160], [150, 144, 136], [138, 132, 126],
            [116, 110, 104], [96, 92, 88], [72, 68, 64], [50, 47, 44]];
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
// 화로의 돌 — 집 굴뚝과 같은 **벽돌**(k·K)이 그을린 것. 길바닥 자갈과
// 같은 사다리를 썼더니 자갈 마당에 얹은 순간 바닥과 한 덩어리가 됐다
const FG = [[176, 110, 70], [146, 90, 58], [116, 68, 44], [88, 52, 34],
            [62, 36, 24], [42, 24, 18]];
const OUT = [32, 24, 28];
const SHADOW = [30, 26, 34, 78];

class P {
  constructor(w, hh) {
    this.w = w; this.h = hh;
    this.d = Array.from({ length: hh }, () => new Array(w).fill(null));
  }
  px(x, y, c) {
    if (!c) return;
    x = Math.round(x); y = Math.round(y);
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.d[y][x] = c;
  }
  get(x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return null;
    return this.d[y][x];
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
  // 바닥 그늘 — 물건이 땅에 **닿아 있다**는 유일한 표시
  ground(cx, cy, rx, ry) { this.disc(cx, cy, rx, ry, SHADOW); }
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
  for (const [x, y] of add) g.px(x, y, OUT);
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
  const d = depth || 7;
  for (let k = d; k >= 1; k--) {
    // 뒤로 갈수록 **또렷하게** 좁아지고 어두워진다. 완만하게 줄이면
    // 「깊은 윗면」이 아니라 그냥 밝은 벽이다 — 각이 안 올라간다
    // **좁아지는 데도 한도가 있다.** 줄마다 꼬박꼬박 좁혔더니 열두 칸짜리
    // 궤짝이 일곱 줄 만에 봉긋한 덩어리가 됐다 — 네모가 아니라 두건이었다.
    // 폭의 오분의 일까지만 좁힌다
    const maxIn = Math.max(0, Math.floor((x1 - x0) / 5));
    const inset = Math.min(maxIn, Math.round((k - 1) * 0.7));
    var tone = t[0];
    if (k >= d) tone = t[2];                   // 제일 먼 줄
    else if (k >= d - 1) tone = t[1];
    g.hline(x0 + inset, x1 - inset, yFront - k, tone);
  }
  g.px(x1, yFront - 1, t[1]);                  // 오른쪽 모서리
  // **앞 모서리** — 윗면과 정면이 꺾이는 자리에 한 줄 진하게 긋는다.
  // 이 한 줄이 없으면 밝은 띠 하나로 뭉개져서, 윗면을 그려 놓고도
  // 「위에서 본다」가 안 읽힌다. 두 면은 **선으로** 갈린다
  g.hline(x0, x1, yFront, t[5]);
}


// 쇠테 한 줄 — 통·여물통을 묶는다
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
const FW = 34, FH = 52;

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

// 돌탑 한 켜 — 왼쪽은 빛, 오른쪽 두 칸은 돌아간 면
function towerRow(g, x0, x1, y, seed, lift) {
  for (let x = x0; x <= x1; x++) {
    const course = Math.floor(y / 3);
    const col = Math.floor((x + (course % 2) * 2) / 4);
    let i = 2 + Math.floor(h(col, course, seed) * 2.0) + lift;
    if (y % 3 === 0) i -= 1;                      // 켜 윗줄 = 빛
    if ((x + (course % 2) * 2) % 4 === 3) i += 1; // 세로 줄눈
    if (x <= x0 + 1) i -= 1;                      // 왼쪽 = 빛을 받는 면
    if (x >= x1 - 2) i += 2;                      // 오른쪽 = 돌아간 면
    g.px(x, y, ST[clamp(i, 0, 7)]);
  }
}

function forge(f) {
  const g = new P(FW, FH);
  g.ground(17, 50, 15, 3.0);
  // ---- 받침과 **상판** ----
  //
  // 위에서 내려다보는 각이라, 화로에서 제일 크게 보여야 하는 면은 벽이
  // 아니라 **상판**이다. 예전에는 굴뚝 발을 상판 앞모서리에 딱 붙여
  // 세웠더니 상판이 통째로 굴뚝에 가려 손바닥만 한 띠로 남았다 — 그래서
  // 아무리 윗면을 밝게 칠해도 「올려다본 벽」으로 보였다.
  //
  // 굴뚝은 상판 **뒤쪽**(화면에서 위)에서 올라온다. 그래야 상판의 앞
  // 절반이 굴뚝 앞에 그대로 남아서, 대장장이가 물건을 올려 두는 넓은
  // 면으로 읽힌다.
  const BX0 = 4, BX1 = 29, DECK = 35;             // 상판 앞모서리
  for (let y = DECK + 1; y <= 49; y++) towerRow(g, BX0, BX1, y, 5, 0);
  g.hline(BX0, BX1, 49, ST[7]);                   // 밑동
  topFace(g, BX0, BX1, DECK, ST, 8);              // 상판 — 여덟 줄, 뒤로 물러난다
  // 상판에 흩어진 재와 부스러기. **앞쪽 절반에만** — 뒤쪽은 굴뚝이 선다
  for (let x = BX0 + 2; x <= BX1 - 2; x++)
    if (h(x, 0, 71) < 0.34) g.px(x, DECK - 1 - (x % 3), ST[5]);

  // ---- 굴뚝 — 위로 갈수록 좁아진다 ----
  //
  // 곧은 통은 파이프고, 좁아지는 것이 굴뚝이다.
  // 발도 **너무 벌리면 안 된다.** 반폭 9까지 벌렸더니 스물여섯 칸짜리
  // 상판을 열아홉 칸이 덮어서, 애써 여덟 줄 잡은 윗면이 다시 띠가 됐다.
  const CY0 = 11, CY1 = 26;                       // 몸통 (발은 상판 뒤쪽에 묻힌다)
  for (let y = CY0; y <= CY1; y++) {
    const t = (y - CY0) / (CY1 - CY0);            // 0(위) ~ 1(아래)
    const half = Math.round(5 + t * 2);           // 반폭 5 -> 7
    towerRow(g, 17 - half, 17 + half, y, 7, 0);
  }
  // 굴뚝 발이 상판에 닿는 자리 — 두 줄 그늘을 깔아야 「꽂혀 있다」가 된다.
  // 상판 위에 드리운 그림자니 **오른쪽으로 번진다** (빛은 왼쪽 위에서 온다)
  for (let x = 10; x <= 26; x++) {
    g.px(x, CY1 + 1, ST[6]);
    if (h(x, 1, 73) < 0.6) g.px(x + 1, CY1 + 2, ST[4]);
  }

  // ---- 갓 ----
  //
  // 맨 위로 한 번 벌어지고, **속이 뚫린 것이 위에서 보인다.** 구멍 하나가
  // 굴뚝을 기둥에서 통으로 바꾼다 — 집 굴뚝에 쓴 규칙과 같은 규칙이다.
  const KX0 = 8, KX1 = 25, KY = 7;                // 갓 앞모서리
  for (let y = KY + 1; y <= KY + 3; y++) towerRow(g, KX0, KX1, y, 7, 0);
  topFace(g, KX0, KX1, KY, ST, 6);                // 갓 윗면 — 여섯 줄
  // 연기 구멍 — 위에서 내려다보므로 **구멍의 안쪽 벽**까지 보인다.
  // 가로줄 하나로 그으면 구멍이 아니라 그림자 자국이다
  g.rect(12, 2, 21, 5, [26, 20, 18]);
  g.hline(12, 21, 2, ST[5]);                      // 저쪽 안벽 (빛이 조금 든다)
  g.hline(12, 21, 3, ST[7]);
  g.px(12, 5, ST[6]); g.px(21, 5, ST[6]);         // 아가리 앞턱
  // ---- 아치 아가리 ----
  //
  // 네모로 뚫으면 아궁이가 아니라 창문이다. 위를 둥글게 깎아야 아치가 된다
  const MX0 = 11, MX1 = 22, MY0 = 38, MY1 = 48;
  for (let y = MY0; y <= MY1; y++) {
    const dy = y - (MY0 + 6);
    const cut = dy < 0 ? Math.round(6 - Math.sqrt(Math.max(0, 36 - dy * dy))) : 0;
    for (let x = MX0 + cut; x <= MX1 - cut; x++) g.px(x, y, [24, 16, 14]);
  }
  // 아치 테두리 — 쐐기돌을 둘러 박았다
  for (let y = MY0 - 1; y <= MY1; y++) {
    const dy = y - (MY0 + 6);
    const cut = dy < 0 ? Math.round(6 - Math.sqrt(Math.max(0, 36 - dy * dy))) : 0;
    g.px(MX0 + cut - 1, y, ST[2]);
    g.px(MX1 - cut + 1, y, ST[5]);
  }
  // 그을음 — 아가리 위로 검게 번진다. **정면에만.**
  //
  // 예전에는 아홉 줄까지 올려 그었는데, 상판을 여덟 줄로 넓히고 나니
  // 그 그을음이 상판을 통째로 덮어 애써 밝게 잡은 윗면이 도로 검어졌다.
  // 그을음은 아가리에서 올라온 연기가 **벽에** 앉은 것이다 — 눕는 면이
  // 아니라 선 면에만 앉는다.
  for (let x = MX0 - 3; x <= MX1 + 3; x++)
    for (let k = 0; k < 2; k++) {
      if (k && h(x, k, 63) < 0.45) continue;         // 위쪽은 성기게
      g.px(x, MY0 - 1 - k, ST[clamp(7 - k, 4, 7)]);
    }
  // ---- 숯불과 불 ----
  for (let x = MX0 + 1; x <= MX1 - 1; x++) {
    const v = h(x, f, 17);
    g.px(x, MY1, v < 0.45 ? FI[3] : FI[4]);
    if (v < 0.30) g.px(x, MY1 - 1, FI[2]);
    if (v > 0.86) g.px(x, MY1 - 1, FI[1]);
  }
  flame(g, 16 + (f % 2), MY1 - 1, 8 + (f % 4), f, 0);
  flame(g, 19, MY1, 6 + ((f + 1) % 3), f, 2.4);
  // 아가리에서 새어 나온 빛이 **발치 돌만** 물들인다.
  //
  // 처음에는 아가리 좌우를 위아래로 죽 물들였더니, 돌탑 양쪽에 **빨간
  // 막대 두 개**가 그어졌다 — 불빛이 아니라 페인트칠로 보였다.
  // 빛은 불에서 가까울수록 세다. 아래쪽 몇 줄에만, 그것도 성기게.
  for (let y = MY1 - 3; y <= MY1; y++) {
    if (h(y, f, 23) < 0.55) g.px(MX0 - 2, y, FI[4]);
    if (h(y, f, 27) < 0.55) g.px(MX1 + 2, y, FI[4]);
  }
  for (let x = MX0 - 3; x <= MX1 + 3; x++)
    if (h(x, f, 29) < 0.45) g.px(x, MY1 + 1, FI[4]);
  // ---- 불티 ----
  for (let i = 0; i < 6; i++) {
    const sx = 17 + Math.round(Math.sin(i * 2.1 + f * 1.3) * 4);
    const sy = 3 - ((i * 3 + f * 2) % 4);
    g.px(sx, sy, i % 2 === 0 ? FI[1] : FI[2]);
  }
  // ---- 발치 ----
  g.rect(0, 46, 3, 49, ST[5]);                    // 굴러 떨어진 돌
  g.hline(0, 3, 46, ST[3]);
  g.rect(30, 47, 33, 49, ST[6]);
  g.hline(30, 33, 47, ST[4]);
  for (let x = 5; x <= 28; x++)                   // 아가리 앞에 떨어진 재
    if (h(x, f, 41) < 0.6) g.px(x, 50, ST[5]);
  return outline(g);
}

// ---- 모루 ----
//
// 대장간이라는 말을 한 칸으로 하는 물건. 그루터기에 얹어 놓는다 —
// 땅바닥에 그냥 두면 쇳덩이 하나가 굴러다니는 것으로 보인다.
//
// **작게 그려서는 모루가 안 된다.** 열여섯 도트짜리로 뭉뚱그렸더니
// 화면에서 검은 덩어리 하나였다. 모루는 생김새가 곧 이름인 물건이라,
// 그 생김새를 이루는 다섯 가지가 다 보여야 한다:
//   뿔      왼쪽으로 뾰족하게 뻗은 것. 이거 하나면 모루로 읽힌다
//   면      두들기는 윗면. 반들반들해서 제일 밝다
//   구멍    면에 뚫린 네모 구멍(하디)과 둥근 구멍(프리철)
//   허리    잘록하게 들어간 몸통. 위아래가 넓고 가운데가 좁다
//   굽      바닥에 퍼진 발. 그루터기에 얹혀 있다
function anvil() {
  const g = new P(30, 26);
  g.ground(15, 24, 12, 2.2);
  // ---- 그루터기 ----
  g.rect(7, 16, 22, 24, W[4]);
  g.hline(7, 22, 16, W[2]);            // 잘린 윗면 — 위를 보니 밝다
  g.hline(7, 22, 17, W[3]);
  g.hline(7, 22, 24, W[6]);            // 밑동
  for (let y = 18; y <= 23; y++)       // 껍질 결
    for (let x = 7; x <= 22; x++)
      if (h(x, y, 121) < 0.24) g.px(x, y, W[5]);
  hoop(g, 7, 22, 19); hoop(g, 7, 22, 22);   // 갈라지지 말라고 두른 쇠테 둘
  g.vline(7, 16, 24, W[3]); g.vline(22, 16, 24, W[5]);
  // ---- 굽 ----
  g.rect(5, 13, 24, 15, IR[3]);
  g.hline(5, 24, 13, IR[2]);
  g.hline(5, 24, 15, IR[4]);
  // ---- 허리 (잘록하다) ----
  g.rect(11, 10, 18, 12, IR[3]);
  g.vline(11, 10, 12, IR[2]);
  g.vline(18, 10, 12, IR[4]);
  // ---- 몸통과 면 ----
  g.rect(5, 6, 24, 9, IR[2]);
  g.hline(5, 24, 6, IR[0]);            // 두들기는 면 — 반들반들
  g.hline(5, 24, 7, IR[1]);
  g.hline(5, 24, 9, IR[3]);            // 면 밑의 턱
  g.px(5, 6, IR[1]); g.px(24, 6, IR[1]);
  for (let x = 6; x <= 23; x++) if (h(x, 0, 123) < 0.18) g.px(x, 8, IR[3]);
  // ---- 뿔 — 왼쪽으로 길게 뻗는다 ----
  g.hline(2, 4, 6, IR[1]);
  g.hline(0, 4, 7, IR[2]);
  g.hline(1, 4, 8, IR[3]);
  g.px(0, 6, IR[3]); g.px(0, 8, IR[4]);
  // ---- 꽁무니의 구멍 둘 ----
  g.rect(19, 6, 20, 6, IR[4]);         // 하디 (네모)
  g.px(19, 7, IR[3]);
  g.px(23, 6, IR[4]);                  // 프리철 (둥근)
  // ---- 면 위에 얹어 둔 망치 ----
  g.rect(7, 3, 10, 5, IR[2]);
  g.hline(7, 10, 3, IR[0]);
  g.hline(7, 10, 5, IR[4]);
  g.hline(11, 20, 5, W[4]);            // 자루
  g.hline(11, 20, 4, W[2]);
  g.px(21, 5, W[5]);
  // ---- 그루터기에 걸어 둔 집게 ----
  g.vline(25, 17, 23, IR[2]); g.vline(26, 18, 23, IR[3]);
  g.px(24, 16, IR[1]); g.px(25, 16, IR[1]);
  // ---- 튄 쇠비늘 ----
  g.px(3, 14, FI[3]); g.px(27, 15, FI[4]); g.px(26, 13, FI[3]);
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
  const g = new P(30, 32);
  g.ground(15, 30, 13, 2.2);
  // 시렁 — 기둥 둘에 가로대 둘. 무기보다 **뒤에** 있으므로 먼저 깐다
  g.rect(1, 13, 3, 30, W[4]); g.vline(1, 13, 30, W[3]);
  g.rect(26, 13, 28, 30, W[4]); g.vline(26, 13, 30, W[3]);
  topFace(g, 1, 3, 13); topFace(g, 26, 28, 13);      // 기둥 머리
  for (const cy of [16, 24]) {
    g.rect(1, cy, 28, cy + 1, W[3]);                 // 가로대 정면
    topFace(g, 1, 28, cy);                           // 가로대 윗면
    g.hline(1, 28, cy + 1, W[5]);
  }
  g.rect(0, 29, 29, 30, W[4]);
  topFace(g, 0, 29, 29);                             // 발치 받침 윗면
  g.hline(0, 29, 30, W[6]);
  // 셋을 **떨어뜨려** 세운다. 붙여 놓으면 날이 한 덩어리가 돼 무엇이
  // 무엇인지 안 갈린다. 끝나는 높이도 다 달리 둔다
  // ① 칼 — 날은 밝고 등날이 어둡다. 코등이와 손잡이가 있어야 칼이다
  g.rect(7, 4, 8, 19, IR[1]);
  g.vline(9, 4, 19, IR[3]);
  g.px(7, 3, IR[0]); g.px(8, 2, IR[0]); g.px(8, 3, IR[0]);
  g.rect(4, 20, 12, 21, IR[3]);                 // 코등이
  g.hline(4, 12, 22, IR[4]);
  g.rect(7, 23, 9, 26, W[4]); g.vline(9, 23, 26, W[5]);
  g.rect(6, 27, 10, 27, IR[2]);                 // 손잡이 끝 쇠
  // ② 창 — 자루가 제일 길고 끝이 좁고 뾰족하다
  g.rect(15, 8, 16, 28, W[4]); g.vline(16, 8, 28, W[5]);
  g.rect(15, 6, 16, 7, IR[3]);                  // 자루에 물린 목
  g.rect(14, 4, 17, 5, IR[2]);
  g.hline(14, 17, 4, IR[1]);
  g.rect(15, 2, 16, 3, IR[1]);
  g.px(15, 1, IR[0]);
  // ③ 도끼 — 반달 날이 옆으로 벌어진다. 셋 중 제일 낮게 둔다
  g.rect(22, 11, 23, 28, W[4]); g.vline(23, 11, 28, W[5]);
  g.rect(20, 7, 25, 10, IR[2]);
  g.hline(20, 25, 7, IR[1]);
  g.hline(20, 25, 10, IR[4]);
  g.px(19, 8, IR[1]); g.px(19, 9, IR[3]);       // 날 끝
  g.px(26, 8, IR[3]);
  // 발치에 기대 놓은 방패 한 짝
  g.disc(6, 27, 4.2, 3.4, W[3]);
  g.disc(6, 27, 2.8, 2.2, W[2]);
  g.disc(6, 27, 1.2, 1.0, IR[2]);
  for (let a = 0; a < 18; a++) {
    const t = a / 18 * Math.PI * 2;
    g.px(6 + Math.cos(t) * 4.2, 27 + Math.sin(t) * 3.4, IR[3]);
  }
  return outline(g);
}


// ---- 장작더미 ----
// 마구리(잘린 면)가 보이게 쌓는다 — 나이테 한 줄이면 통나무가 된다
function logpile() {
  const g = new P(20, 14);
  g.ground(10, 12, 9, 1.8);
  const put = (cx, cy, r, s) => {
    g.disc(cx, cy, r, r * 0.92, W[3]);
    g.disc(cx, cy, r * 0.62, r * 0.56, W[2]);
    g.disc(cx, cy, r * 0.24, r * 0.22, W[4]);
    for (let a = 0; a < 14; a++) {
      const t = a / 14 * Math.PI * 2;
      g.px(cx + Math.cos(t) * r, cy + Math.sin(t) * r * 0.92,
        Math.sin(t) < -0.2 ? W[2] : W[5]);          // 윗변은 빛, 아랫변은 턱
    }
    if (h(cx, cy, s) < 0.5) g.px(cx + 1, cy - 1, W[1]);
  };
  const rows = [[3, 11, 4], [8, 11, 4], [13, 11, 4], [17, 11, 3],
                [5, 7, 3], [11, 7, 4], [16, 7, 3],
                [8, 3, 3], [13, 4, 3]];
  for (const [x, y, r] of rows) put(x, y, r * 0.62, x + y);
  return outline(g);
}

// ---- 여물통 ----
// 목장에도 대장간에도 놓는다 (담금질통). 안에 물이 찰랑거린다
function trough(wet) {
  const g = new P(20, 12);
  g.ground(10, 10, 9, 1.6);
  plank(g, 1, 18, 9, 10, 41);
  topFace(g, 1, 18, 9, W, 6);              // 아가리 테 — 위를 보는 면
  g.rect(2, 4, 17, 6, wet ? AQUA[1] : STRAW[2]);
  if (wet) {
    g.hline(2, 17, 4, AQUA[0]);
    for (let x = 3; x <= 16; x += 3) g.px(x, 5, AQUA[0]);
    g.hline(2, 17, 6, AQUA[2]);
  } else {
    for (let x = 2; x <= 17; x++) {
      if (h(x, 1, 43) < 0.5) g.px(x, 4, STRAW[0]);
      if (h(x, 2, 45) < 0.4) g.px(x, 5, STRAW[1]);
      if (h(x, 3, 47) < 0.4) g.px(x, 6, STRAW[3]);
    }
  }
  hoop(g, 4, 5, 7); hoop(g, 14, 15, 7);
  g.hline(1, 18, 11, W[6]);
  return outline(g);
}

// ---- 볏단 ----
// 목장의 여물. 낟알 결이 세로로 흐르고 새끼줄 두 가닥으로 묶는다
function hay() {
  const g = new P(18, 14);
  g.ground(9, 12, 8, 1.6);
  // **네모로 묶는다.** 둥근 덩어리로 그렸더니 형체가 안 잡혀 잔디 위에
  // 허연 얼룩 하나로 보였다 — 볏단인지 돌인지 알 수가 없었다.
  g.rect(2, 10, 15, 12, STRAW[2]);
  topFace(g, 2, 15, 10, STRAW, 6);        // 윗면
  g.hline(2, 15, 12, STRAW[3]);       // 밑변 = 턱
  g.vline(2, 4, 12, STRAW[1]);
  g.vline(15, 4, 12, STRAW[3]);
  // 지푸라기 결 — 세로로 흐른다
  for (let x = 2; x <= 15; x++) for (let y = 6; y <= 11; y++) {
    const v = h(x, y, 51);
    if (v < 0.22) g.px(x, y, STRAW[3]);
    else if (v > 0.84) g.px(x, y, STRAW[1]);
  }
  // 삐져나온 오라기 몇 가닥 — 묶음이 팽팽하다는 표시
  for (let i = 0; i < 7; i++) {
    const x = 2 + Math.floor(h(i, 1, 55) * 14);
    g.px(x, 3, STRAW[1]);
    if (h(i, 2, 57) < 0.5) g.px(x + 1, 3, STRAW[2]);
  }
  // 새끼줄 두 가닥
  for (const bx of [5, 12]) {
    g.vline(bx, 4, 12, W[4]);
    g.vline(bx + 1, 4, 12, W[5]);
  }
  return outline(g);
}

// ---- 그물 말리는 틀 ----
// 이 한 칸이면 수산시장이다. 장대 둘에 그물이 걸려 늘어진다
function netrack() {
  const g = new P(22, 22);
  g.ground(11, 20, 9, 1.8);
  g.vline(2, 3, 20, W[4]); g.vline(3, 3, 20, W[3]);
  g.vline(18, 3, 20, W[4]); g.vline(19, 3, 20, W[3]);
  g.hline(1, 20, 3, W[2]); g.hline(1, 20, 4, W[4]);
  // 그물 — 마름모 코. 아래로 갈수록 늘어져 벌어진다
  for (let y = 5; y <= 17; y++) {
    const sag = Math.round((y - 5) * 0.28);
    for (let x = 4; x <= 17; x++) {
      const u = x + sag, v = y;
      if ((u + v) % 3 === 0 || (u - v + 30) % 3 === 0)
        g.px(x, y, y > 13 ? NET[2] : NET[1]);
    }
  }
  g.hline(4, 17, 17, NET[2]);
  for (let x = 5; x <= 16; x += 4) {   // 뜸 (부표)
    g.disc(x, 18, 1.4, 1.2, W[2]);
    g.px(x, 17, W[1]);
  }
  return outline(g);
}


// ---- 화단 ----
// 길게 짠 나무 상자에 흙을 채우고 꽃을 심었다. 여관·회관·도서관 앞
function planter() {
  const g = new P(20, 13);
  g.ground(10, 11, 9, 1.6);
  plank(g, 1, 18, 10, 11, 71);
  topFace(g, 1, 18, 10, W, 4);        // 상자 테 윗면
  g.rect(2, 4, 17, 8, [112, 88, 64]);   // 흙은 위에서 훤히 보인다
  for (let x = 2; x <= 17; x++) if (h(x, 4, 73) < 0.4) g.px(x, 4, [92, 70, 50]);
  // 잎과 꽃 — 상자 위로 봉긋하게
  for (let i = 0; i < 16; i++) {
    const x = 2 + i, hgt = 2 + Math.round(h(i, 1, 75) * 2);
    for (let k = 0; k < hgt; k++)
      g.px(x, 3 - k, k === hgt - 1 ? LEAF[0] : LEAF[1]);
    if (h(i, 2, 77) < 0.22) {
      const c = BLOOM[Math.floor(h(i, 3, 79) * 3) % 3];
      g.px(x, 3 - hgt, c); g.px(x + 1, 3 - hgt, c);
    }
  }
  g.hline(1, 18, 12, W[6]);
  return outline(g);
}

// ---- 손수레 ----
// 짐이 오간다는 표시. 우체국·잡화점 마당
function cart() {
  const g = new P(22, 16);
  g.ground(11, 14, 9, 1.6);
  plank(g, 3, 18, 9, 9, 81);
  topFace(g, 3, 18, 9, W, 6);         // 짐칸 테 윗면
  g.rect(4, 5, 17, 8, W[4]);          // 짐칸 속
  for (let x = 5; x <= 16; x += 4) g.vline(x, 5, 8, W[5]);
  g.hline(3, 18, 10, W[5]);
  g.vline(19, 6, 9, W[3]); g.vline(20, 7, 9, W[4]);   // 손잡이
  for (const cx of [7, 15]) {          // 바퀴
    g.disc(cx, 12, 3.2, 3.2, W[5]);
    g.disc(cx, 12, 2.4, 2.4, W[3]);
    g.disc(cx, 12, 0.9, 0.9, IR[3]);
    for (let a = 0; a < 6; a++) {
      const t = a / 6 * Math.PI * 2;
      g.px(cx + Math.cos(t) * 1.8, 12 + Math.sin(t) * 1.8, W[5]);
    }
  }
  return outline(g);
}

// ---- 책 무더기 ----
// 도서관 마당. 아이콘 한 장이 아니라 **쌓인 것**이라야 내놓은 책이 된다
function bookstack() {
  const g = new P(14, 12);
  g.ground(7, 10, 6, 1.4);
  const rows = [[1, 10, 12], [2, 8, 11], [1, 6, 12], [3, 4, 10]];
  rows.forEach(([x0, y, x1], i) => {
    const c = BOOK[i % 4];
    g.rect(x0, y - 1, x1, y, c);
    g.hline(x0 + 1, x1 - 1, y - 2, c.map(v => Math.min(255, v + 18)));
    g.hline(x0, x1, y - 1, c.map(v => Math.min(255, v + 46)));   // 윗면
    g.hline(x0, x1, y + 1, c.map(v => Math.round(v * 0.55)));
    g.vline(x0, y - 1, y, PAPER[1]);   // 책배
    g.px(x1, y, PAPER[2]);
  });
  g.rect(4, 1, 9, 2, PAPER[0]);        // 맨 위 펼쳐 둔 책
  g.hline(4, 9, 3, PAPER[2]);
  g.px(6, 2, PAPER[2]); g.px(7, 2, PAPER[2]);
  return outline(g);
}

// ---- 표본 선반 ----
// 연구소 마당. 유리병에 담아 세워 둔 것들
function specimen() {
  const g = new P(18, 18);
  g.ground(9, 16, 8, 1.6);
  g.vline(2, 4, 16, W[4]); g.vline(15, 4, 16, W[4]);
  for (const sy of [9, 15]) { topFace(g, 1, 16, sy); g.hline(1, 16, sy + 1, W[5]); }
  topFace(g, 1, 16, 4); g.hline(1, 16, 5, W[5]);
  const jar = (x, y, c) => {
    g.rect(x, y - 3, x + 2, y, AQUA[2]);
    g.rect(x, y - 3, x + 2, y, [c[0], c[1], c[2]]);
    g.vline(x, y - 3, y, AQUA[0]);
    g.hline(x, x + 2, y - 4, IR[1]);   // 마개
    g.px(x + 2, y - 1, AQUA[2]);
  };
  jar(3, 8, AQUA[1]); jar(7, 8, LEAF[1]); jar(11, 8, BLOOM[1]);
  jar(4, 14, [168, 120, 200]); jar(9, 14, AQUA[0]);
  g.px(13, 13, ST[2]); g.px(14, 14, ST[4]);   // 돌 표본 한 점
  g.px(13, 14, ST[3]);
  return outline(g);
}


// ---- 나무 궤짝 ----
//
// 가게 마당에 제일 많이 놓이는 것. 예전에는 가방 아이콘(old_box·chest)을
// 그대로 갖다 놨는데, 그건 **뚜껑 열린 보물상자**라 어느 가게에 놓아도
// 「누가 보물을 두고 갔나」가 됐다. 짐은 판때기를 못으로 친 궤짝이다.
function crate() {
  const g = new P(16, 15);
  g.ground(8, 13, 7, 1.6);
  g.rect(2, 11, 13, 13, W[4]);        // 정면 — 두 줄이면 된다
  topFace(g, 2, 13, 11);              // 뚜껑 윗면 (일곱 줄)
  g.hline(2, 13, 13, W[6]);           // 밑변 턱
  for (let x = 4; x <= 12; x += 3) g.vline(x, 8, 12, W[5]);   // 판 사이
  for (let x = 2; x <= 13; x++) if (h(x, 6, 91) < 0.22) g.px(x, 9 + (x % 3), W[4]);
  g.vline(2, 11, 13, W[3]); g.vline(13, 11, 13, W[6]);
  hoop(g, 2, 13, 12);                  // 쇠띠 한 줄
  g.rect(5, 5, 11, 5, W[4]);          // 위에 얹은 작은 궤짝
  topFace(g, 5, 11, 5, W, 4);
  g.hline(5, 11, 5, W[5]);
  g.vline(8, 3, 5, W[5]);
  g.px(11, 4, W[5]);
  return outline(g);
}


// ---- 마대 자루 ----
//
// 궤짝만 늘어놓으면 마당이 네모투성이가 된다. 자루는 **둥글고 늘어져**
// 있어서, 같은 짐인데도 옆에 놓으면 둘 다 살아난다
function sack() {
  const g = new P(18, 14);
  g.ground(9, 12, 8, 1.6);
  // 동그란 덩어리 셋으로 그렸더니 허연 얼룩 하나로 뭉쳤다. 자루는 **서
  // 있는 것**이다 — 아래로 벌어지는 배와, 오므려 묶은 목이 있어야 한다
  const one = (x0, x1, top, seed) => {
    const cx = Math.round((x0 + x1) / 2);
    for (let y = top; y <= 12; y++) {
      const t = (y - top) / (12 - top);
      const w = Math.round((x1 - x0) / 2 * (0.44 + t * 0.56));
      for (let x = cx - w; x <= cx + w; x++) {
        let c = SACK[1];
        if (x <= cx - w + 1) c = SACK[0];          // 왼쪽 = 빛
        if (x >= cx + w - 1) c = SACK[2];          // 오른쪽 = 그늘
        if (y >= 12) c = SACK[3];                  // 밑변 턱
        g.px(x, y, c);
      }
      if (h(y, seed, 93) < 0.35) g.px(cx - 1, y, SACK[2]);   // 주름
    }
    g.rect(cx - 1, top - 2, cx + 1, top - 1, SACK[2]);       // 오므린 목
    g.hline(cx - 2, cx + 2, top - 1, W[4]);                  // 새끼줄
    g.px(cx, top - 3, SACK[0]);
  };
  one(1, 8, 6, 3);
  one(10, 17, 5, 9);
  return outline(g);
}


// ---- 작업대 ----
//
// 처음에는 「연장 걸이」로 그렸다 — 기둥 둘에 가로대. 그런데 그건 무기
// 거치대와 **같은 실루엣**이라, 마당에 둘을 놓으면 어느 쪽이 어느 쪽인지
// 알 수가 없었다. 물건은 서로 **다르게 생겨야** 구분된다.
//
// 그래서 작업대로 바꾼다. 다리 넷에 두꺼운 상판, 그 위에 바이스와 연장,
// 아래에는 널어 둔 연장 한 벌. 세워 둔 틀이 아니라 **엎어 놓은 판**이라
// 옆에 무기 거치대가 서 있어도 한눈에 갈린다.
function toolrack() {
  const g = new P(20, 18);
  g.ground(10, 16, 9, 1.8);
  // 다리 넷
  for (const lx of [2, 15]) {
    g.rect(lx, 9, lx + 2, 16, W[4]);
    g.vline(lx, 9, 16, W[3]);
    g.vline(lx + 2, 9, 16, W[5]);
    g.hline(lx, lx + 2, 16, W[6]);
  }
  g.rect(3, 12, 16, 13, W[4]);          // 다리 사이 가로 버팀
  g.hline(3, 16, 12, W[2]);
  // 상판 — 두껍다. 윗면 두 줄 + 앞 모서리
  g.rect(0, 9, 19, 9, W[4]);
  topFace(g, 0, 19, 9, W, 6);
  g.hline(0, 19, 9, W[6]);
  for (let x = 1; x <= 18; x++) if (h(x, 0, 131) < 0.2) g.px(x, 7, W[1]);
  // 상판 위 — 바이스(쇠 물림쇠)와 망치
  g.rect(3, 4, 6, 6, IR[2]);
  g.hline(3, 6, 4, IR[0]); g.hline(3, 6, 6, IR[4]);
  g.px(2, 5, IR[3]); g.px(7, 5, IR[1]);
  g.rect(11, 3, 13, 4, IR[2]);
  g.hline(11, 13, 3, IR[0]); g.hline(11, 13, 4, IR[4]);
  g.hline(14, 17, 4, W[4]); g.hline(14, 17, 3, W[2]);
  // 상판 밑에 걸어 둔 연장 — 톱니 하나, 집게 하나
  g.vline(6, 10, 14, IR[3]);
  for (let y = 11; y <= 14; y++) g.px(7, y, IR[2]);
  g.vline(11, 10, 13, IR[2]); g.vline(12, 11, 13, IR[3]);
  return outline(g);
}


// ---- 내보내기 ----
const OUTS = {};
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
