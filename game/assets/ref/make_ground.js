// 바닥 생성기 — 잔디 · 자갈길 · 밭흙을 **건물과 같은 방식**으로.
//
// 왜 다시 그리는가 —
//   1판: 64x64에 픽셀을 확률로 뿌린 잡음. 0.5배로 줄면 사포처럼 자글거렸다
//   2판: 도트 크기는 맞췄지만(16x16 논리) 색을 확률로 흔드는 데 그쳤다
//   3판: **건물에 쓴 방식을 그대로 가져온다** —
//
//     톤 사다리   재료마다 예닐곱 단. 한 자로 재야 물건들이 한 바닥에 놓인다
//     물건 하나씩 자갈 한 알, 풀 한 포기를 **윗변·속·아랫변** 세 부분으로 그린다
//     낡은 티     밟혀 닳은 알, 줄눈에 낀 이끼, 흙이 드러난 자리
//
//   건물 기와가 「윗변은 빛, 아랫변은 턱」으로 한 장이 되듯, 자갈도 풀도
//   같은 규칙으로 그려야 같은 그림의 바닥이 된다.
//
// 도트 크기: 16x16 논리 -> 4배 -> 64x64 -> 게임에서 0.5배 -> 화면 32px.
//   한 칸이 화면 2px. 캐릭터·건물과 정확히 같다.
//
// 64x64 타일은 맵에 수백 번 반복된다. 그래서 모든 좌표를 16으로 **감아서**
// 찍는다 — 타일 끝에서 잘린 잎이 반대편에서 이어져야 이음매가 안 보인다.
//
// 실행:  node make_ground.js            -> ref/proposed_*.png (제안만)
//        node make_ground.js --install  -> sprites/ 에 실제로 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');

const N = 16;                    // 논리 격자 (한 변)
const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)
const F = N * S;                 // 64

function h(x, y, k) {
  let n = (x * 73856093) ^ (y * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

class T {
  constructor() { this.d = Array.from({ length: N }, () => new Array(N).fill(null)); }
  // **감아서** 찍는다 — 이음매 없는 반복의 전부가 이 한 줄이다
  px(x, y, c) { if (c) this.d[((y % N) + N) % N][((x % N) + N) % N] = c; }
  get(x, y) { return this.d[((y % N) + N) % N][((x % N) + N) % N]; }
  render() {
    const im = new PNG({ width: F, height: F });
    im.data.fill(0);
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
        const i = ((y * S + sy) * F + (x * S + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
      }
    }
    return im;
  }
  // 경계 그림은 **한 도트에 1픽셀**로 낸다. 꼴이 256가지라 4배로 부풀리면
  // 한 벌이 16배가 된다 — 화면에서는 어차피 두 배로 늘려 그리므로
  // (프로젝트 필터가 nearest) 결과는 한 점도 다르지 않다
  small() {
    const im = new PNG({ width: N, height: N });
    im.data.fill(0);
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      const i = (y * N + x) * 4;
      im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
    }
    return im;
  }
}

// 두 칸 높이 그릇 — **벼랑면 전용**.
//
// T 는 modulo N 으로 감는다 (이음매 없는 바닥 타일의 전부가 그 한 줄이다).
// 벼랑면을 두 칸으로 그리려면 그 감기가 방해가 된다 — 아래 칸(16~31행)이
// 위 칸으로 도로 접혀 버린다. 그래서 감지 않는 그릇을 따로 둔다.
class TT {
  constructor(h) {
    this.h = h;
    this.d = Array.from({ length: h }, () => new Array(N).fill(null));
  }
  px(x, y, c) { if (c && x >= 0 && x < N && y >= 0 && y < this.h) this.d[y][x] = c; }
  get(x, y) { return (x >= 0 && x < N && y >= 0 && y < this.h) ? this.d[y][x] : null; }
  small() {
    const im = new PNG({ width: N, height: this.h });
    im.data.fill(0);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < N; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      const i = (y * N + x) * 4;
      im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
    }
    return im;
  }
}

// 경계 그림 한 벌을 **한 장에** 담는다. 파일을 천오백 개 따로 두면 불러오는
// 것부터 일이고, 한 장에 모으면 그리기가 오히려 더 잘 묶인다 (같은 텍스처)
const ATC = 16, ATR = 16;       // 꼴 값(0~255)이 그대로 자리다
function atlas(name, tiles, ch) {
  const CH = ch || N;
  const im = new PNG({ width: ATC * N, height: ATR * CH });
  im.data.fill(0);
  tiles.forEach((t, idx) => {
    if (!t) return;
    const ox = (idx % ATC) * N, oy = Math.floor(idx / ATC) * CH;
    for (let y = 0; y < CH; y++) for (let x = 0; x < N; x++) {
      const a = (y * N + x) * 4, b = ((oy + y) * im.width + ox + x) * 4;
      im.data[b] = t.data[a]; im.data[b + 1] = t.data[a + 1];
      im.data[b + 2] = t.data[a + 2]; im.data[b + 3] = t.data[a + 3];
    }
  });
  save(name, im);
}

// 지난 번 제안본은 먼저 지운다. 미리보기가 proposed_*.png 를 집어 쓰는 바람에
// 타일을 새로 뽑고도 **옛 그림을 보며** 판단할 뻔했다
for (const f of fs.readdirSync(REF)) if (f.startsWith('proposed_')) fs.unlinkSync(REF + f);

const OUT = {};
const save = (name, im) => {
  OUT[name] = im;
  fs.writeFileSync((INSTALL ? SPR : REF + 'proposed_') + name + '.png', PNG.sync.write(im));
};


// ---- 톤 사다리 ----
//
// 건물 기와가 q0..q7 한 자를 쓰듯, 바닥도 재료마다 사다리를 둔다.
// 밝은 쪽이 0. 물건 하나를 그릴 때 [윗변 = i-1, 속 = i, 아랫변 = i+2] 로
// 뽑아 쓰면 알알이 같은 규칙으로 도드라진다.
// 회색이 아니라 **따뜻한 돌**이다. 순수한 회색으로 깔면 잔디 옆에서
// 아스팔트가 된다 — 붉은 벽돌 건물과 초록 들판 사이에 놓이는 돌이라
// 둘 다에서 조금씩 얻어와야 한 마을로 보인다.
const STONE = [[214, 202, 178], [194, 180, 156], [174, 160, 138], [154, 141, 120],
               [132, 120, 102], [108, 98, 84], [84, 76, 66], [62, 56, 50]];
const EARTH = [[178, 148, 112], [156, 126, 94], [134, 106, 78], [112, 88, 64],
               [92, 70, 50], [72, 54, 38]];
const MOSS  = [[112, 140, 74], [88, 114, 58], [66, 88, 44]];


// ---- 자갈길 ----
//
// 알을 다 같은 크기로 깔면 격자가 보인다. 세 가지를 흔든다:
// **크기 · 자리 · 톤.** 그리고 밟고 다닌 길이라 가운데가 닳아 밝다.
function cobble(seed) {
  const g = new T();
  // **건물 벽돌과 똑같은 방식**이다. 알을 하나씩 놓고 사이를 흙으로 두는
  // 방식으로 두 번 실패했다 — 아무리 크게 잡아도 「진흙에 박힌 돌」이었다.
  // 포장은 돌이 이웃과 맞닿는 것이고, 줄눈은 **한 칸**이면 된다.
  //
  //   윗줄   한 단 밝다 (위를 보고 있으니 빛을 받는다)
  //   아랫줄 두 단 어둡다 = 가로 줄눈
  //   오른줄 두 단 어둡다 = 세로 줄눈. 켜마다 반 칸씩 어긋난다
  // **장마다 바탕 톤이 다르다** — 잔디·마당과 같은 규칙. 광장처럼 넓게
  // 깔리는 바닥일수록 이게 없으면 통짜 회색 판이 된다.
  //
  // 그리고 **알 크기도 흔든다.** 네 칸짜리만 깔면 아무리 톤을 흔들어도
  // 격자가 그대로 읽힌다 — 다섯에 하나쯤은 오른쪽 줄눈을 지워 여덟 칸짜리
  // 넓은 돌로 만든다. 포장은 자로 잰 것이 아니다
  // **다 그리지 않는다 — 평평한 자갈밭에 돌 몇 덩이.**
  //
  // 알을 격자로 다 그리는 길(벽돌담)과 사방 줄눈(그물)을 둘 다 지나서
  // 남은 답이다. 손으로 찍은 길은 바탕이 조용한 자갈밭이고, 그 위에
  // 도드라진 돌 몇 덩이만 손으로 놓는다 — 본채 벽(sparseStones)과
  // 같은 규칙이다.
  // 장의 밝기를 통째로 올리내리면 (PSHIFT +-1) 이웃 타일과의 경계가
  // 세로줄로 드러난다. 밝기 대신 **어두운 얼룩의 비율**을 흔든다 —
  // 같은 두 톤인데 장마다 섞임새만 달라서 경계가 안 보인다
  const MIXSHIFT = [0.12, 0.0, -0.12][((seed % 3) + 3) % 3];
  // ① 바탕 — 낮은 주파수 두 톤. 얼룩이 서너 칸에 걸친다
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const t = h(x >> 2, y >> 2, seed) * 0.55 + h(x >> 1, y >> 1, seed + 9) * 0.30
      + h(x, y, seed + 17) * 0.15;
    g.px(x, y, STONE[t < 0.42 + MIXSHIFT ? 3 : 2]);
  }
  // ② 도드라진 돌 — 두어 덩이. 타일 가장자리를 밟지 않아야 이음매가 안 보인다
  for (let k = 0; k < 3; k++) {
    if (h(k * 7 + 1, seed, 21) > 0.80) continue;
    const w = 4 + Math.floor(h(k, seed, 22) * 3);          // 폭 4~6
    const hh = 3 + Math.floor(h(seed, k, 23) * 2);         // 높이 3~4
    const ox = 1 + Math.floor(h(k * 3, seed, 24) * (N - w - 2));
    const oy = 1 + Math.floor(h(seed, k * 3, 25) * (N - hh - 2));
    const tone = h(k, seed, 26) < 0.4 ? 1 : 2;
    for (let y = oy; y < oy + hh; y++) for (let x = ox; x < ox + w; x++) {
      const corner = (x === ox || x === ox + w - 1) && (y === oy || y === oy + hh - 1);
      if (!corner) g.px(x, y, STONE[tone]);
    }
    for (let x = ox + 1; x <= ox + w - 2; x++) g.px(x, oy + hh - 1, STONE[5]);   // 밑그늘
    for (let y = oy + 1; y < oy + hh - 1; y++) g.px(ox + w - 1, y, STONE[5]);
    g.px(ox + 1, oy, STONE[clamp(tone - 1, 0, 7)]);        // 왼윗귀 빛
    g.px(ox + 2, oy, STONE[clamp(tone - 1, 0, 7)]);
  }
  // ③ 잔자갈 — 도드라진 돌 사이의 두 칸짜리 조약돌. 한 점보다 잘 읽힌다
  for (let k = 0; k < 5; k++) {
    const ox = 1 + Math.floor(h(k * 5 + 2, seed, 27) * (N - 3));
    const oy = 1 + Math.floor(h(seed, k * 5 + 2, 28) * (N - 2));
    g.px(ox, oy, STONE[1]); g.px(ox + 1, oy, STONE[3]);
    g.px(ox, oy + 1, STONE[5]);
  }
  // ④ 잔 점과 흙, 삐져나온 풀잎 — 아주 드물게. 바탕이 조용해야 돌이 보인다
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const r = h(x * 3 + 1, y * 5 + 2, seed + 29);
    if (r < 0.02) g.px(x, y, STONE[5]);
    else if (r > 0.988) g.px(x, y, EARTH[2]);
  }
  for (let k = 0; k < 2; k++) {
    const ox = 1 + Math.floor(h(k * 9 + 4, seed, 33) * (N - 2));
    const oy = 2 + Math.floor(h(seed, k * 9 + 4, 34) * (N - 3));
    g.px(ox, oy, MOSS[1]); g.px(ox + (k % 2 ? 1 : -1), oy - 1, MOSS[0]);
  }
  // 줄눈에 낀 이끼 — 어두운 줄눈 자리에만, 덩어리로
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const c = g.get(x, y);
    if (c !== STONE[5] && c !== STONE[6] && c !== STONE[7] && !EARTH.includes(c)) continue;
    if (h(x >> 1, y >> 1, seed + 11) > 0.12) continue;
    g.px(x, y, MOSS[h(x, y, seed + 13) < 0.5 ? 1 : 2]);
  }
  return g;
}


// 길 가장자리 — 풀밭 칸에 길에서 흘러나온 자갈을 얹는다.
// 직선으로 뚝 끊기면 종이를 오려 붙인 것처럼 보인다.
// dir: 0=위 1=아래 2=왼 3=오른 (길이 그쪽에 있다)
function cobbleEdge(dir) {
  const g = new T();
  const put = (i, k, c) => {
    if (dir === 0) g.px(i, k, c);
    else if (dir === 1) g.px(i, N - 1 - k, c);
    else if (dir === 2) g.px(k, i, c);
    else g.px(N - 1 - k, i, c);
  };
  // 경계는 **자로 그은 듯 곧으면 안 된다.** 첫 줄까지 통으로 깔았더니
  // 자갈 띠가 하나 더 생겨서 오히려 선이 굵어졌다.
  // 자갈이 풀 사이로 **들쭉날쭉 파고드는** 그림이어야 한다.
  for (let i = 0; i < N; i++) {
    const deep = 1 + Math.floor(h(i, dir, 11) * 5);         // 한 칸 ~ 다섯 칸
    for (let k = 0; k < deep; k++) {
      // 깊이 들어갈수록 성기게 — 끝은 자갈 몇 알만 흩어져 있다
      if (k > 0 && h(i, k, dir + 20) < 0.18 + k * 0.13) continue;
      const t = clamp(1 + Math.floor(h(i, k, dir) * 4), 1, 4);
      // 알 하나에도 윗변/아랫변을 준다 — 길 본체와 같은 규칙
      put(i, k, STONE[clamp(t + (k === deep - 1 ? 2 : 0), 0, 7)]);
    }
    // 자갈 사이로 비치는 흙
    if (h(i, 3, dir + 31) < 0.30) put(i, 0, EARTH[2]);
  }
  return g;
}


// ---- 잔디 ----
//
// 포기 하나를 **잎 여러 장**으로 그린다. 담쟁이 잎과 같은 규칙 —
// 밑동은 어둡고, 속은 기본색, 끝은 빛을 받는다. 확률로 흩은 점은
// 아무리 많이 찍어도 풀이 안 된다.
//
// 계절은 **색만** 바꾼다. 포기가 서는 자리와 모양은 그대로 둬야
// 계절이 바뀔 때 땅이 뒤집히지 않고 물만 든 것처럼 보인다.
const SEASON = {
  // 나무(tree_01)의 잎과 **같은 채도 줄기**로 올렸다. 잔디가 나무보다
  // 채도가 낮으면 화면의 절반이 물 빠진 배경이 되어, 그 위의 모든 것이
  // 스티커로 보인다 — 무대와 배우는 같은 물감이어야 한다
  spring: { base: [88, 158, 62], lo: [70, 136, 52], hi: [108, 180, 72],
            dark: [50, 104, 42], tip: [146, 208, 92],
            bloom: [[240, 228, 130], [244, 244, 234]] },
  summer: { base: [74, 146, 56], lo: [58, 124, 46], hi: [92, 168, 66],
            dark: [42, 96, 40], tip: [128, 196, 80],
            bloom: [[232, 146, 170], [150, 172, 228]] },
  fall:   { base: [146, 132, 72], lo: [126, 112, 62], hi: [166, 150, 86],
            dark: [96, 84, 48], tip: [190, 172, 100],
            bloom: [[198, 122, 54], [170, 82, 48]] },
  winter: { base: [208, 214, 224], lo: [190, 198, 212], hi: [230, 234, 242],
            dark: [162, 172, 190], tip: [244, 246, 250],
            bloom: [[228, 232, 240], [204, 210, 222]] },
};

// 포기 하나 — 잎 서너 장이 밑동에서 부챗살로 벌어진다
function tuft(g, x, y, p, big) {
  const blades = big ? [[-2, 3], [-1, 4], [0, 5], [1, 4], [2, 3]]
                     : [[-1, 2], [0, 3], [1, 2]];
  for (const [dx, len] of blades) {
    if (h(x * 7 + dx, y * 5 + len, 3) < 0.22) continue;     // 가끔 한 장 빠진다
    for (let k = 1; k <= len; k++) {
      // 위로 갈수록 바깥으로 휜다 — 곧게 세우면 빗자루가 된다
      const bend = Math.round(dx * (k / len) * 0.9);
      // 잎은 **바탕에 안 쓰는 색**으로만 그린다. base 로 칠했더니 바탕도
      // base 라 잎이 통째로 안 보였다 — 5배로 확대해서야 알았다.
      // 바탕은 lo/base, 잎은 hi/tip. 이렇게 갈라 두면 어느 자리에 심어도 읽힌다
      const lit = k === len && h(x + dx, y + k, 11) < 0.4;
      g.px(x + dx + bend, y - k, lit ? p.tip : p.hi);
    }
  }
  g.px(x, y, p.dark);                                       // 밑동은 한 칸만.
                                                            // 두 칸이면 풀이 아니라 검은 얼룩이 된다
}

function grass(season, variant) {
  const p = SEASON[season], g = new T();
  // ① 바탕 — 2x2 잔 얼룩 위에 4x4 큰 결. 톤 폭은 **좁게**.
  //    32px 타일이 수백 번 반복되므로, 여기서 대비를 주면 그게 그대로
  //    격자무늬가 된다. 무대가 튀면 배우가 안 보인다
  //    다만 **결이 세 겹**은 돼야 한다. 두 겹으로 칠했더니 4x4 네모
  //    얼룩이 그대로 보여서, 들판이 초록 체크무늬로 깔렸다.
  const mid = p.base.map((c, j) => Math.round((c + p.lo[j]) / 2));
  // **장마다 바탕 톤이 다르다.** 세 장을 다 같은 밝기로 그려 놓고 칸마다
  // 아무거나 골라 깔았더니, 아무리 여러 장을 섞어도 들판은 결국 한 색이었다.
  // 참고 그림(스타듀)의 땅이 살아 보이는 건 장이 예뻐서가 아니라 **몇 칸에
  // 걸친 얼룩**이 있어서다 — 그늘진 자리와 볕 드는 자리가 손바닥만 하게
  // 번갈아 나온다. 여기서 톤을 갈라 두고, 고르는 쪽(main._patch01)에서
  // 낮은 주파수로 뽑으면 그 얼룩이 생긴다.
  const lad = [
    p.lo.map((c, j) => Math.round((c + p.dark[j]) / 2)),   // 0 제일 그늘진 단
    p.lo, mid, p.base,
    p.base.map((c, j) => Math.round((c + p.hi[j]) / 2)),   // 4 제일 볕 드는 단
  ];
  const SHIFT = [-1, 0, 1][variant % 3];
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const v = h(x >> 2, y >> 2, variant) * 0.38 + h(x >> 1, y >> 1, variant + 9) * 0.42
      + h(x, y, variant + 17) * 0.20;
    const i = (v < 0.30 ? 1 : (v < 0.56 ? 2 : 3)) + SHIFT;
    g.px(x, y, lad[clamp(i, 0, 4)]);
  }
  // ② 흙이 드러난 자리 — 풀만 빽빽하면 양탄자가 되지만, **아주 드물게**.
  //    10%로 뿌렸더니 들판이 녹슨 카펫이 됐다. 색도 순 흙빛이 아니라
  //    잔디 쪽으로 당겨 섞는다 — 풀 사이로 비치는 흙은 그만큼 죽어 보인다
  // 흙빛을 더 많이 섞었더니 들판에 **분홍 점**이 흩뿌려졌다 — 초록 위의
  // 붉은 흙은 아무리 어두워도 눈에 띈다. 잔디 쪽으로 더 당겨 섞는다
  const soilTone = k => p.base.map((v, j) => Math.round(v * 0.62 + EARTH[k][j] * 0.38));
  const s1 = soilTone(1), s2 = soilTone(2);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    if (h(x >> 1, (y >> 1) + 40, variant) > 0.022) continue;
    g.px(x, y, season === 'winter' ? p.lo : (h(x, y, 5) < 0.5 ? s1 : s2));
  }
  // ③ 포기 — 다섯. 많이 심을수록 타일이 「무늬」로 기억된다
  for (let i = 0; i < 5; i++) {
    const ox = Math.floor(h(i, variant, 1) * N);
    const oy = Math.floor(h(variant, i, 2) * N);
    tuft(g, ox, oy, p, h(i, i + variant, 6) < 0.4);
  }
  // ③-b 홑잎 — 포기가 못 되는 **잎 한두 장**. 포기만 다섯이면 그 다섯이
  //     무늬로 기억되지만, 그 사이를 홑잎이 메우면 「풀밭」이 된다.
  //     포기와 달리 밑동(dark)을 안 찍는다 — 검은 점이 늘면 얼룩이 된다
  for (let i = 0; i < 9; i++) {
    const ox = Math.floor(h(i + 50, variant, 12) * N);
    const oy = Math.floor(h(variant, i + 50, 13) * N);
    const len = 1 + Math.floor(h(i, variant + 3, 14) * 2);
    const lean = h(i, variant, 15) < 0.5 ? -1 : 1;
    for (let k = 1; k <= len; k++)
      g.px(ox + (k === len ? lean : 0), oy - k, k === len ? p.tip : p.hi);
  }
  // ④ 잔돌 하나 — 바닥에 굴러다니는 것. 풀만 있는 땅은 없다
  {
    const ox = Math.floor(h(variant + 20, 7, 8) * N), oy = Math.floor(h(7, variant + 20, 9) * N);
    g.px(ox, oy, STONE[2]); g.px(ox + 1, oy, STONE[1]);
    g.px(ox, oy + 1, STONE[4]); g.px(ox + 1, oy + 1, STONE[3]);
  }
  // ⑤ 꽃 — 세 장 중 한 장에만, 그것도 한 송이. 꽃은 **드물어야** 눈에 띈다
  if (variant === 1) {
    const ox = Math.floor(h(40, variant, 4) * N), oy = Math.floor(h(variant, 40, 5) * N);
    const c = p.bloom[season === 'spring' ? 0 : 1];
    g.px(ox, oy, c); g.px(ox + 1, oy, c); g.px(ox, oy - 1, c);
    g.px(ox, oy + 1, p.dark);                               // 꽃대
  }
  // ⑥ 계절의 바닥 — 색만 바꾸면 「누런 봄」일 뿐이다. 계절은 바닥에
  //    **놓인 것**으로 읽힌다: 가을엔 낙엽이 구르고, 겨울엔 눈이
  //    두덩이로 쌓인다. 둘 다 드물게 — 크게 대신 드물게.
  if (season === 'fall') {
    // 낙엽 — 2px 한 장. 붉은 것과 주홍이 섞이고, 가끔 밑에 그늘 한 점
    const LEAF = [[202, 118, 52], [172, 84, 46], [216, 158, 72]];
    for (let i = 0; i < 6; i++) {
      if (h(i + 70, variant, 21) < 0.5) continue;           // 장마다 두엇만
      const ox = Math.floor(h(i + 70, variant, 22) * (N - 2));
      const oy = 1 + Math.floor(h(variant, i + 70, 23) * (N - 2));
      const c = LEAF[Math.floor(h(i, variant + 70, 24) * 3)];
      g.px(ox, oy, c); g.px(ox + 1, oy, c);
      if (h(i, variant, 25) < 0.45)
        g.px(ox + 1, oy + 1, c.map(v => Math.round(v * 0.72)));
    }
  } else if (season === 'winter') {
    // 눈 두덩 — 바람이 몰아 놓은 자리. 등성이는 희고 밑에 그늘 한 줄
    for (let i = 0; i < 2; i++) {
      if (h(i + 80, variant, 26) < 0.45) continue;
      const ox = 2 + Math.floor(h(i + 80, variant, 27) * (N - 12));
      const oy = 3 + Math.floor(h(variant, i + 80, 28) * (N - 7));
      const w = 5 + Math.floor(h(i, variant + 80, 29) * 4);
      for (let dx = 0; dx < w; dx++) {
        const edge = dx === 0 || dx === w - 1;
        g.px(ox + dx, oy, edge ? p.hi : p.tip);
        if (!edge) g.px(ox + dx, oy - 1, p.hi);
        g.px(ox + dx, oy + 1, p.dark);                      // 밑그늘이 두덩을 띄운다
      }
    }
    // 눈 반짝임 — 볕에 한두 점
    for (let i = 0; i < 3; i++) {
      if (h(i + 90, variant, 30) < 0.55) continue;
      g.px(Math.floor(h(i + 90, variant, 31) * N),
        Math.floor(h(variant, i + 90, 32) * N), [252, 253, 255]);
    }
  }
  return g;
}


// ---- 밭흙 ----
//
// 쟁기가 지나간 자리는 **이랑**이 남는다. 마루는 빛을 받고 고랑은 그늘진다.
// 통줄로 그으면 널빤지가 되므로 한 칸 걸러 끊고, 흙덩이를 얹는다.
function soil(wet) {
  const g = new T(), o = wet ? 2 : 0;                       // 젖으면 두 단 짙다
  const C = i => EARTH[clamp(i + o, 0, EARTH.length - 1)];
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const r = y % 4;                                        // 이랑 한 칸 = 4줄
    let c = C(1);
    // 이랑을 통줄로 그으면 벽돌담이 된다. **절반쯤만** 긋고 나머지는
    // 흙덩이에 맡긴다 — 갈아엎은 땅에 자로 잰 줄은 없다
    const jag = h(x, y >> 2, wet ? 5 : 6);
    if (r === 0 && jag > 0.35) c = C(0);                    // 마루
    else if (r === 2 && jag > 0.45) c = C(2);               // 고랑
    if (x % 4 === 1 && r !== 0 && h(x, y, 7) > 0.4) c = C(2);   // 호미 자국
    const v = h(x >> 1, y >> 1, wet ? 2 : 1);
    if (v > 0.78) { c = C(0); if (g.get(x, y + 1)) g.px(x, y + 1, C(3)); }
    else if (v < 0.14) c = C(3);                            // 파인 자리
    g.px(x, y, c);
  }
  if (wet) {                                                // 물기 — 고랑에 고인다
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++)
      if (y % 4 === 2 && h(x, y, 9) < 0.30) g.px(x, y, EARTH[5]);
  }

  // ---- 한 칸으로 보이게 ----
  //
  // 밭은 잔디·길과 다르다. 저 둘은 **면**이라 이어져야 하지만, 밭은
  // 호미로 **한 칸씩** 가는 것이다. 이음매 없이 깔면 갈아엎은 자리가
  // 통째로 한 덩어리가 되어, 어디까지 갈았는지 안 보인다.
  //
  // 그래서 테두리를 준다 — 파 올린 흙이 칸 가장자리에 둔덕으로 남는다:
  //   위·왼쪽  밝다 (빛을 받는 둔덕)
  //   아래·오른쪽 어둡다 (그늘진 둔덕과 그 밑 골)
  for (let i = 0; i < N; i++) {
    const jag = k => h(i, k, wet ? 21 : 22) < 0.72;         // 가장자리도 들쭉날쭉
    if (jag(0)) { g.px(i, 0, C(0)); g.px(0, i, C(0)); }
    if (jag(1)) { g.px(i, 1, C(1)); g.px(1, i, C(1)); }
    if (jag(2)) { g.px(i, N - 1, C(4)); g.px(N - 1, i, C(4)); }
    if (jag(3)) { g.px(i, N - 2, C(3)); g.px(N - 2, i, C(3)); }
  }
  return g;
}


// ---- 마당 ----
//
// 집이 잔디 위에 그냥 얹혀 있으면 「놓아 둔 모형」으로 보인다. 사람이 사는
// 집 둘레에는 **풀이 못 자란 자리**가 생긴다 — 드나들며 밟아 다진 흙.
// 이 한 장이 집을 땅에 앉힌다.
//
// 길(자갈)과는 다르다. 길은 깐 것이고 마당은 **닳은 것**이라, 돌을 놓지 않고
// 흙에 잔돌과 풀 몇 포기만 남긴다.
// 지푸라기·검불 — 마당에만 있는 것. 집에서 쓸려 나오고 수레에서 떨어진다.
// 흙빛 사다리 밖의 **마른 풀색**이라 한 점만 있어도 「사람이 드나드는 자리」가 된다
const STRAW = [[196, 170, 108], [166, 140, 84], [132, 108, 62]];

function yard(v) {
  const g = new T(), p = SEASON.spring, s = v * 13;
  // ① 바탕 — 큰 결 · 중간 결 · 잔 결을 겹쳐 섞는다.
  //    예전엔 두 겹뿐이라 4x4 네모 얼룩이 그대로 보였다 (마당에 바둑판이
  //    떴다). 세 겹을 다른 비율로 섞으면 어디서 칸이 끊기는지 안 보인다.
  //    톤도 두 단에서 **네 단**으로 늘렸다 — 다진 흙은 평평한 색이 아니라
  //    밟힌 자리와 안 밟힌 자리가 얼룩덜룩한 땅이다
  //    그리고 **장마다 바탕 톤이 다르다** — 잔디와 같은 규칙이다.
  //    마당 한 판이 통짜 갈색 네모로 보이던 건 세 장이 다 같은 밝기라
  //    어떻게 섞어도 평균이 한 색이었기 때문이다
  const YSHIFT = [1, 0, -1][v % 3];
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const t = h(x >> 2, y >> 2, 60) * 0.30 + h(x >> 1, y >> 1, 61) * 0.40
      + h(x, y, 62) * 0.30;
    const i = (t < 0.22 ? 3 : (t < 0.50 ? 2 : (t < 0.84 ? 1 : 0))) + YSHIFT;
    g.px(x, y, EARTH[clamp(i, 0, EARTH.length - 1)]);
  }
  // ② 반들반들 다져진 자리 — 사람이 늘 밟고 다니는 목. 넓게 한두 군데.
  //    이게 있어야 흙이 「깔린 것」이 아니라 「닳은 것」으로 보인다
  for (let i = 0; i < 2; i++) {
    const cx = h(i + s, 11, 70) * N, cy = h(11, i + s, 71) * N;
    const rx = 3 + h(i, s, 72) * 3, ry = 2 + h(s, i, 73) * 2;
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2;
      if (d > 1) continue;
      if (d > 0.45 && h(x, y, 74) < 0.55) continue;     // 가장자리는 흩어 놓는다
      // 한복판만 훤하다. 덩어리 전부를 제일 밝은 단으로 깔았더니 마당에
      // 흰 얼룩이 규칙적으로 떠서 타일 자리가 그대로 드러났다
      g.px(x, y, EARTH[d > 0.35 ? 1 : 0]);
    }
  }
  // ③ 발자국 — 뒤꿈치가 깊고 앞이 얕다. 파인 자리는 어둡고 **파낸 흙이
  //    앞쪽에 밀려** 한 단 밝게 도드라진다. 그냥 어두운 선 하나로는
  //    자국이 아니라 긁힌 자국이었다
  for (let i = 0; i < 4; i++) {
    const ox = Math.floor(h(i + s, 3, 63) * N), oy = Math.floor(h(3, i + s, 64) * N);
    const len = 2 + Math.floor(h(i + s, i, 65) * 3);
    // 뒤꿈치를 제일 어두운 단(EARTH[5])으로 찍었더니 마당 전체에 검은
    // 점이 흩뿌려져 자국이 아니라 때가 됐다. 한 단 올린다
    g.px(ox, oy, EARTH[4]);                              // 뒤꿈치
    for (let k = 1; k <= len; k++) g.px(ox + k, oy, EARTH[4 - (k === len ? 1 : 0)]);
    g.px(ox, oy - 1, EARTH[1]); g.px(ox + 1, oy - 1, EARTH[0]);   // 밀린 흙
  }
  // ④ 마른 흙이 갈라진 금 — 짧게 꺾이며 끊긴다. 곧게 그으면 흠집이 된다
  for (let i = 0; i < 2; i++) {
    let cx = Math.floor(h(i + s + 5, 13, 75) * N), cy = Math.floor(h(13, i + s + 5, 76) * N);
    for (let k = 0; k < 5; k++) {
      if (h(cx, cy, 77) < 0.25) break;                   // 금은 끊긴다
      g.px(cx, cy, EARTH[4]);
      if (h(cx, cy, 78) < 0.45) cy += h(cx, cy, 79) < 0.5 ? 1 : -1;
      cx += 1;
    }
  }
  // ⑤ 흙에 박힌 잔돌 — 윗변은 빛, 아랫변은 턱, 둘레는 눌린 흙.
  //    이 세 부분이 있어야 「얹어 놓은 점」이 아니라 「박힌 돌」이 된다
  for (let i = 0; i < 4; i++) {
    const ox = Math.floor(h(i + 9 + s, 5, 66) * N), oy = Math.floor(h(5, i + 9 + s, 67) * N);
    g.px(ox, oy, STONE[2]); g.px(ox + 1, oy, STONE[3]);
    g.px(ox, oy + 1, STONE[5]);
    if (h(i, s, 80) < 0.5) g.px(ox + 1, oy + 1, STONE[4]);
    g.px(ox - 1, oy + 1, EARTH[4]);                      // 돌 밑에 진 그늘
  }
  // ⑥ 지푸라기 — 두어 오라기. 헛간 앞이든 가게 앞이든 마당에는 늘 있다
  for (let i = 0; i < 3; i++) {
    const ox = Math.floor(h(i + 40 + s, 9, 81) * N), oy = Math.floor(h(9, i + 40 + s, 82) * N);
    const dy = h(i, s, 83) < 0.5 ? 0 : 1;
    g.px(ox, oy, STRAW[1]); g.px(ox + 1, oy, STRAW[0]);
    g.px(ox + 2, oy + dy, STRAW[1]); g.px(ox + 3, oy + dy, STRAW[2]);
  }
  // ⑦ 밟히고도 살아남은 풀 두 포기 — 이게 있어야 흙바닥이 아니라 마당이다
  for (let i = 0; i < 2; i++)
    tuft(g, Math.floor(h(i + 30 + s, 7, 68) * N), Math.floor(h(7, i + 30 + s, 69) * N), p, false);
  return g;
}


// ---- 나무 부두 ----
//
// 물 위에 깐 판자다. 지금까지는 게임이 갈색 네모 세 개를 겹쳐 그렸다 —
// 결도 못도 없는 판이라 물 위에 색종이를 오려 붙인 것 같았다.
//
// 판자로 읽히려면 세 가지가 있어야 한다.
//   ① 널의 **이음매** — 판자 한 장의 끝이 어디인지가 보여야 한다
//   ② **나뭇결** — 이음매와 같은 방향으로 흐르는 결
//   ③ **못** — 널을 받침목에 박은 자리. 이게 있어야 「깐 것」이 된다
// 널은 **가로로** 눕힌다. 부두는 물 쪽으로 걸어 나가는 길이라, 결이
// 걸음과 직각이어야 한 걸음씩 딛는 게 보인다.
// 한 단 밝혔다 — 원래 사다리로는 툇마루가 마당에서 제일 어두운 덩어리라
// 혼자 푹 꺼져 보였다. 울타리·들보와 같은 나무 줄기에서 시작한다
const DECK = [[186, 148, 102], [162, 124, 82], [138, 102, 64],
              [114, 82, 50], [90, 63, 38], [64, 44, 26]];

function dockTile(v) {
  const g = new T(), s = v * 17;
  const PLANK = 4;                       // 널 한 장의 폭 (칸)
  for (let y = 0; y < N; y++) {
    const b = Math.floor(y / PLANK);     // 몇 번째 널인가
    const tone = h(b + s, 0, 71);        // 널마다 색이 조금씩 다르다
    const base = tone < 0.3 ? 0 : tone < 0.7 ? 1 : 2;
    for (let x = 0; x < N; x++) {
      // 결 — 널 방향(가로)으로 길게 흐른다
      const w = vnoise(x * 2, y + b * 7 + s, 72 + v, 5);
      let k = base + (w < 0.36 ? 1 : w > 0.74 ? -1 : 0);
      if (y % PLANK === 0) k += 2;       // 이음매 — 널과 널 사이의 그늘
      else if (y % PLANK === 1) k -= 1;  // 그 바로 밑은 빛을 문다
      g.px(x, y, DECK[clamp(k, 0, 5)]);
    }
  }
  // 못 — 널 끝을 받침목에 박은 자리. 좌우 끝에서 두 칸 들어온 자리에 박힌다
  for (let b = 0; b < N / PLANK; b++) {
    const yy = b * PLANK + 2;
    for (const xx of [2, N - 3]) {
      g.px(xx, yy, DECK[5]);
      g.px(xx, yy - 1, DECK[0]);
    }
  }
  return g;
}

// 부두 가장자리 — 물에 닿는 쪽. 널 끝이 잘려 있고 그 밑에 기둥이 선다.
// d: 0=북 1=남 2=서 3=동
function dockEdge(d) {
  const g = new T();
  const put = (x, y, c) => {
    if (d === 0) g.px(x, y, c);
    else if (d === 1) g.px(x, N - 1 - y, c);
    else if (d === 2) g.px(y, x, c);
    else g.px(N - 1 - y, x, c);
  };
  for (let x = 0; x < N; x++) {
    put(x, 0, DECK[5]);                  // 잘린 널 끝
    put(x, 1, DECK[4]);
  }
  // 기둥 두 대 — 물 속으로 박힌 통나무. 부두가 「떠 있지 않다」를 말한다
  if (d === 0 || d === 1) {
    for (const px of [3, N - 5]) for (let i = 0; i < 3; i++) {
      put(px + i, 0, DECK[i === 1 ? 2 : 4]);
      put(px + i, 1, DECK[i === 1 ? 3 : 5]);
      put(px + i, 2, DECK[4]);
    }
  }
  return g;
}


// ---- 모래사장 ----
//
// 바닷가는 색 한 판에 점 세 개로 칠해 두었었다. 새로 그린 바닥들 옆에
// 놓으면 혼자 종이처럼 매끈해서 딴 그림이 된다. 흙·자갈과 같은 규칙으로
// 다시 그린다 — 다만 모래는 **알이 안 보이는 재료**라, 자갈처럼 알을
// 그리는 대신 잔결과 쓸려 온 것들(조개·조약돌·해초)로 읽히게 한다.
const SAND = [[240, 226, 190], [226, 208, 166], [208, 186, 140],
              [186, 162, 116], [160, 136, 94], [132, 110, 74]];

function sandTile(v) {
  const g = new T();
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    // 물결이 남긴 잔결 — 가로로 길게 눕는다. 등방성 잡음은 사포가 된다
    const w = vnoise(x, y * 2 + v, 41 + v, 4) * 0.65 + vnoise(x, y, 42 + v, 2) * 0.35;
    g.px(x, y, ramp(SAND, 1 + (w - 0.5) * 2.2));
  }
  for (let i = 0; i < 3; i++) {                              // 쓸려 온 조약돌
    const ox = Math.floor(h(i + 3, v, 43) * N), oy = Math.floor(h(v, i + 3, 44) * N);
    g.px(ox, oy, STONE[2]); g.px(ox + 1, oy, STONE[3]); g.px(ox, oy + 1, STONE[4]);
  }
  if (v !== 1) {                                             // 조개 한 알
    const ox = Math.floor(h(v + 7, 2, 45) * N), oy = Math.floor(h(2, v + 7, 46) * N);
    g.px(ox, oy, [250, 240, 232]); g.px(ox + 1, oy, [236, 214, 206]);
    g.px(ox, oy + 1, [214, 186, 178]); g.px(ox + 1, oy + 1, [236, 214, 206]);
  }
  for (let i = 0; i < 2; i++) {                              // 마른 해초 한 가닥
    const ox = Math.floor(h(i + 11, v, 47) * N), oy = Math.floor(h(v, i + 11, 48) * N);
    for (let k = 0; k < 3; k++) g.px(ox + k, oy + (k === 1 ? 1 : 0), SAND[5]);
  }
  return g;
}


// ---- 오르막 = **돌계단** ----
//
// 예전에는 다져진 흙에 디딤돌 몇 개를 얹었다. 걸을 수는 있는데 「길」로만
// 보이고 「올라간다」가 안 읽혔다. 위에서 내려다보는 화면에서 오르막과
// 평지를 가르는 건 기울기가 아니라 **가로줄이 반복된다**는 사실이다 —
// 계단참이 층층이 겹쳐 보이는 그 무늬 하나가 「여기는 오른다」를 말한다.
//
// 그래서 켜마다 셋을 그린다. 이게 없으면 그냥 줄무늬 바닥이 된다:
//   디딤면(tread)  밟는 면. 하늘을 정면으로 받으니 **제일 밝다**
//   모서리         디딤면의 앞 끝. 닳아서 한 단 더 밝다
//   챌면(riser)    다음 단까지 서 있는 면. 앞으로 그늘이 져 **제일 어둡다**
// 우리 집이 지붕(눕는 면)과 벽(서는 면)으로 상자가 되는 것과 같은 말이다.
//
// 세로로 두 칸이 이어 붙으므로 무늬는 **네 칸마다** 되풀이되게 둔다 —
// 16이 4로 나누어떨어져야 위아래 칸의 계단이 어긋나지 않는다.
function rampTile(v) {
  const g = new T(), s = v * 11;
  // 바탕 — 계단 옆으로 삐져나온 흙과 이끼
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const t = h(x >> 1, y >> 1, 71 + s) * 0.6 + h(x, y, 72 + s) * 0.4;
    g.px(x, y, EARTH[t < 0.30 ? 3 : (t > 0.74 ? 1 : 2)]);
  }
  for (let row = 0; row < 4; row++) {
    const y = row * 4;
    // 한 단은 넓적한 돌 두세 장을 이어 붙인 것이다. 이음매 자리를 정해
    // 두고 그 칸만 어둡게 하면, 통돌이 아니라 **쌓아 만든 계단**이 된다
    const seam = new Set();
    let sx = 2 + Math.floor(h(row, v, 81) * 4);
    while (sx < N - 1) { seam.add(sx); sx += 4 + Math.floor(h(sx, row, 82 + s) * 4); }
    // ---- 앞 모서리는 **곧지 않다** ----
    //
    // 자로 그은 가로선 넷을 그으면 사람이 어제 부어 놓은 콘크리트 계단이
    // 된다. 참고 사진의 계단은 넓적한 자연석을 주워다 놓은 것이라, 돌마다
    // 앞 끝이 반 칸씩 어긋나고 한복판이 밟혀 옴폭하다.
    // 돌 하나(네 칸)마다 어긋남을 정해 두면 그 안에서는 이어진다
    const lip = (x2) => (h(x2 >> 2, row, 88 + s) < 0.34 ? 1 : 0)
      - (h(x2 >> 2, row, 89 + s) < 0.22 ? 1 : 0);
    for (let x2 = 0; x2 < N; x2++) {
      // 돌 하나하나의 밝기가 조금씩 다르다 (한 색이면 콘크리트가 된다)
      const k = h(x2 >> 2, row, 83 + s);
      const lift = k > 0.72 ? -1 : (k < 0.26 ? 1 : 0);
      const j = seam.has(x2) ? 2 : 0;               // 이음매는 두 단 어둡게
      const cl = (i) => STONE[clamp(i + lift + j, 0, STONE.length - 1)];
      const o = lip(x2);
      g.px(x2, y + o, cl(0));            // 모서리 — 닳아 반들거린다
      g.px(x2, y + 1 + o, cl(1));        // 디딤면
      g.px(x2, y + 2 + o, cl(3));        // 디딤면 안쪽 (조금 그늘)
      g.px(x2, y + 3, cl(6));            // 챌면 — 다음 단이 드리우는 그늘
      if (o < 0) g.px(x2, y + 3 + o, cl(3));   // 어긋난 만큼 디딤면을 늘린다
    }
    // 디딤면 한복판은 사람이 밟아 닳았다 — 가운데만 한 단 밝게.
    // 가운데가 **옴폭 꺼지도록** 양 끝으로 갈수록 덜 닳게 한다
    for (let x2 = 3; x2 < N - 3; x2++) {
      const mid = 1 - Math.abs(x2 - (N - 1) / 2) / ((N - 1) / 2);
      if (h(x2, row, 84 + s) > mid * 0.9) continue;
      g.px(x2, y + 1 + lip(x2), STONE[0]);
    }
    // 이 빠진 모서리 — 돌 하나에 한 자리쯤. 이게 있어야 「주워다 놓은 돌」이다
    if (h(row, v, 90 + s) < 0.55) {
      const bx = 1 + Math.floor(h(row, v, 91 + s) * (N - 3));
      for (let d = 0; d < 2 + Math.floor(h(row, v, 92 + s) * 2); d++) {
        g.px(bx + d, y + lip(bx), EARTH[2]);
        g.px(bx + d, y + 1 + lip(bx), EARTH[3]);
      }
    }
  }
  // 이끼 — **밟히지 않는 자리**에만 앉는다: 챌면 밑과 돌 사이 이음매.
  //
  // 처음엔 타일의 좌우 가장자리에 앉혔다. 오르막은 **두 칸 폭**이라
  // 한복판에서 두 타일의 가장자리가 맞붙는다 — 계단 한가운데로 이끼가
  // 세로줄로 흘러내렸다. 타일은 제가 왼쪽인지 오른쪽인지 모른다.
  // 자리를 타일 좌표가 아니라 **계단의 생김새**에서 뽑아야 이어 붙여도
  // 무늬가 안 겹친다 (예전 디딤돌이 같은 이유로 어긋났던 자리다).
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const riser = y % 4 === 3;                     // 챌면 — 그늘지고 축축하다
    const patch = h(x >> 2, y >> 2, 87 + s);       // 이끼는 **군데군데** 낀다
    const p = (riser ? 0.42 : 0.10) * (patch > 0.58 ? 1.0 : 0.18);
    if (h(x, y, 85 + s) < p) g.px(x, y, MOSS[h(x >> 1, y, 86 + s) < 0.4 ? 1 : 2]);
  }
  // 돌 틈에 낀 잔모래 몇 알 — 가까이 보면 볼 것이 하나 더 있어야 한다
  for (let i = 0; i < 5; i++) {
    const gx = Math.floor(h(i, v, 93) * N), gy = Math.floor(h(v, i, 94) * 4) * 4 + 3;
    g.px(gx, gy, EARTH[h(i, v, 95) < 0.5 ? 3 : 4]);
  }
  return g;
}


// ---- 물과 물가 ----
//
// 지금 물은 파란 사각형이고, 땅과 만나는 자리가 **자로 그은 선**이다.
// 실제 물가는 세 겹이다:
//
//   물     깊은 쪽은 짙고 가장자리는 옅다 (얕아지니까)
//   거품   파도가 닿는 자리에 흰 줄이 들쭉날쭉 남는다
//   젖은 땅 물이 들었다 난 자리. 마른 땅보다 짙고 조약돌이 드러난다
//
// 이 세 겹이 있어야 물이 「땅에 담긴 것」으로 보인다.
// 깊은 물은 **어둡다.** 가운데를 중간 파랑으로 두었더니 어디를 봐도 얕아
// 보였다 — 깊이는 물빛 자체가 말한다. 바탕은 아래쪽 단(4~6)을 쓰고,
// 밝은 단(0~2)은 물가 여울에만 쓴다. 그래야 가장자리만 환하고 가운데가 깊다.
const WATER = [[142, 204, 230], [104, 174, 212], [72, 142, 190], [50, 112, 162],
               [34, 84, 130], [22, 60, 100], [14, 42, 74], [9, 28, 52],
               [6, 19, 37], [4, 13, 26]];
const FOAM = [244, 250, 252];

// 물 밑이 비쳐 보이게 — **바닥색을 물색에 섞는다.**
//
// 타일 밑에는 깔린 게 없어서 알파를 낮춰 봐야 배경이 비칠 뿐이다.
// 대신 바닥(모래·조약돌·수초)을 그리되 물빛에 섞어서 그린다. 섞는 비율이
// 곧 깊이다 — 얕으면 바닥색이 세고 깊으면 물색이 이긴다.
function thru(c, depth) {
  const w = WATER[depth < 0.5 ? 3 : 5];
  return c.map((v, i) => Math.round(v * (1 - depth) + w[i] * depth));
}

// 16칸에서 **감기는** 값잡음. 격자점 사이를 부드럽게 이어 붙인다.
// h() 를 x>>2 로 바로 쓰면 4칸짜리 네모가 그대로 보인다 — 물 한가운데에
// 바둑판이 뜬 게 그 탓이었다
function vnoise(x, y, k, cell) {
  const m = N / cell;
  const gx = x / cell, gy = y / cell;
  const x0 = Math.floor(gx), y0 = Math.floor(gy);
  const sm = t => t * t * (3 - 2 * t);
  const u = sm(gx - x0), v = sm(gy - y0);
  const at = (a, b) => h(((a % m) + m) % m, ((b % m) + m) % m, k);
  return (at(x0, y0) * (1 - u) + at(x0 + 1, y0) * u) * (1 - v)
    + (at(x0, y0 + 1) * (1 - u) + at(x0 + 1, y0 + 1) * u) * v;
}

// 사다리 사이를 **반 단씩** 섞는다. 한 단이 통째로 갈리면 그 경계가
// 타일마다 같은 자리에 나타나 격자가 된다
function ramp(P, i) {
  const a = clamp(Math.floor(i), 0, P.length - 1);
  const b = clamp(a + 1, 0, P.length - 1);
  const t = Math.round((i - a) * 2) / 2;
  return P[a].map((c, k) => Math.round(c * (1 - t) + P[b][k] * t));
}

// 깊이는 **여덟 단**, 한 단이 0.42톤이다 (물가 5 -> 한가운데 7.9).
//
// 처음엔 두 단이었다. 연못 한가운데에 검푸른 **직사각형**이 오려 붙은 것
// 처럼 떴다 — 한 번에 두 톤을 뛰니 그 경계가 타일 변을 따라 그대로 보였다.
// 세 단, 다섯 단으로 늘려도 계단이 그만큼 보일 뿐이었다. 폭이 네 칸인
// 개울은 어차피 두 단밖에 못 쓰니, **단의 높이 자체를 낮춰야** 했다.
// 여덟 단 × 0.42톤이면 가장 깊은 곳은 전과 같은데 계단 하나는 반도
// 안 된다 — 사다리를 반 단씩 섞어 찍으니 경계가 아예 흩어져 버린다.
// 물빛을 **사다리 값**으로 낸다. 여울이 바깥 물로 이어질 때 그 값이
// 있어야 색을 이어 붙일 수 있다 (여울이 얹히는 칸은 언제나 lv 0이다 —
// 뭍에 닿은 물이니까)
function waterTone(x, y, lv) {
  const v = vnoise(x, y, 51, 4) * 0.62 + vnoise(x, y, 52, 2) * 0.38;
  return 5 + (lv || 0) * 0.42 + (v - 0.5) * 1.7;
}

function baseWater(x, y, lv) { return ramp(WATER, waterTone(x, y, lv)); }

const mixc = (a, b, t) => a.map((v, i) => Math.round(v * (1 - t) + b[i] * t));
const smooth = t => t * t * (3 - 2 * t);

// 물 한 장. lv = 깊이(0~2), vr = **판**(0~2).
//
// 판이 왜 셋이나 필요한가 — 한 장을 호수 스무 칸에 반복해 깔면 잔물결이
// **같은 자리마다 똑같이** 찍혀 물 위에 바둑판이 뜬다. 바탕색을 아무리
// 부드럽게 이어도 이건 안 없어진다. 잔디를 세 판 그린 것과 같은 이유다.
function water(frame, lv, vr) {
  const g = new T();
  const s = vr * 17;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) g.px(x, y, baseWater(x, y, lv));
  // 잔물결 — 가로로 짧게 그은 줄. 두 장이 서로 어긋나야 물이 흐른다.
  // 밝기는 **반 단**만 올린다. 한 단을 통째로 올렸더니 줄이 도드라져
  // 타일마다 같은 무늬가 도는 게 그대로 보였다
  for (let i = 0; i < 4; i++) {
    const ox = Math.floor(h(i, frame + s, 53) * N);
    const oy = Math.floor(h(frame + s, i, 54) * N);
    const len = 2 + Math.floor(h(i, i + frame + s, 55) * 3);
    const t = 4.5 + lv * 0.42;
    for (let k = 0; k < len; k++) g.px(ox + k, oy, ramp(WATER, t + (i % 2) * 0.5));
    g.px(ox - 1, oy, ramp(WATER, t + 1.5));
    // 물결의 머리 — 빛을 받는 쪽. 줄 끝에 한 톤 밝은 점이 물결의
    // 방향을 만든다 (꼬리는 어둡고 머리는 밝다)
    g.px(ox + len, oy, ramp(WATER, t - 1.0));
  }
  // 물비늘 — 수면이 볕을 되쏘는 한두 점. 두 장에서 자리가 달라
  // 저절로 깜빡인다. 얕은 물에만 — 깊은 물에 흰 점은 별이 뜬 것 같다
  if (lv < 4) {
    for (let i = 0; i < 2; i++) {
      if (h(i + 41 + s, frame + 3, 88) < 0.4) continue;
      const ox = Math.floor(h(i + 41 + s, frame, 89) * (N - 1));
      const oy = Math.floor(h(frame, i + 41 + s, 90) * N);
      g.px(ox, oy, mixc(FOAM, WATER[2], 0.3));
      g.px(ox + 1, oy, ramp(WATER, 3.4));                   // 꼬리는 밝은 물빛
    }
  }
  // 물속에 비치는 바닥 — 모래톱과 조약돌, 수초 한 포기.
  // 깊을수록 물빛에 더 섞여 형체만 남다가 결국 안 보인다
  const mix = Math.min(0.94, 0.80 + lv * 0.05);
  for (let i = 0; i < (lv < 3 ? 3 : 0); i++) {
    const ox = Math.floor(h(i + 11 + s, frame, 81) * N), oy = Math.floor(h(frame, i + 11 + s, 82) * N);
    for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 3; dx++)
      if (h(ox + dx, oy + dy, 83) < 0.7) g.px(ox + dx, oy + dy, thru(EARTH[1], mix));
  }
  for (let i = 0; i < (lv === 0 ? 4 : (lv < 3 ? 2 : 0)); i++) {
    const ox = Math.floor(h(i + 21 + s, 5, 84) * N), oy = Math.floor(h(5, i + 21 + s, 85) * N);
    g.px(ox, oy, thru(STONE[2], mix - 0.02)); g.px(ox + 1, oy, thru(STONE[3], mix - 0.02));
    g.px(ox, oy + 1, thru(STONE[4], mix));
  }
  for (let i = 0; i < (lv === 0 ? 2 : (lv < 2 ? 1 : 0)); i++) {  // 수초
    const ox = Math.floor(h(i + 31 + s, 7, 86) * N), oy = Math.floor(h(7, i + 31 + s, 87) * N);
    for (const [dx, len] of [[-1, 2], [0, 3], [1, 2]])
      for (let k = 0; k <= len; k++)
        g.px(ox + dx, oy - k, thru(SEASON.summer[k === len ? 'tip' : 'base'], 0.72));
  }
  return g;
}

// ---- 물가 ----
//
// 곧은 덧그림 넷으로는 물가가 **꺾일 때마다 직각**이다. 타일의 변을 그대로
// 따라 그렸으니 당연하다 — 자연의 물가에 직각은 없다. 게다가 방향마다
// 따로 그린 그림은 이웃끼리 조금씩 어긋나 이음매에 턱이 진다.
//
// 그래서 「어느 변이냐」로 그리기를 그만뒀다. 한 점마다 딱 둘만 잰다:
//
//   s   물가에서 뭍으로 들어간 **거리** (음수면 물)
//   n   그 자리에서 **물 쪽을 가리키는 방향**
//
// 층은 s로 쌓고, 벽이 보이는지는 n으로 정한다. 그러면 물가가 직선이든
// 호(arc)든 **같은 자**로 그려진다 — 곧은 변, 볼록한 귀퉁이, 오목한
// 귀퉁이, 곶, 섬까지 한 함수가 다 낸다. 이웃과 어긋날 수가 없다.

// 물가 한 점.
//   nay > 0  물이 남쪽 = 뭍의 턱이 나를 마주 본다 -> **벽면이 보인다**
//   nay < 0  둑의 윗면만 보인다.  nax 만 크면 비스듬한 옆면
//
// **벽면은 한 방향에서만 보인다.** 사방에 돌벽을 둘렀더니 연못이 「수조」가
// 됐다. 위에서 내려다보는 화면에서 벽의 면이 보이는 건 그 벽이 나를 마주
// 볼 때뿐이다. 옆은 벽이 아니라 **둑이 돌아 나가는 윗면**이다 — 같은 벽을
// 90도 돌려 쓰면 돌결이 세로로 서서 벽이 누워 버린다.
function bankPx(g, x, y, s, nax, nay, i, seed, fill) {
  if (s < 0) {
    // 물 쪽 — 여울.
    //
    // 여기를 **확률로 성기게** 뿌렸었다. 물가에 잔모래를 뿌린 것처럼
    // 자글거려서, 얕아지는 물이 아니라 흰 점이 흩어진 테두리로 보였다.
    // 땅 쪽을 층으로 쌓아 고쳤듯 물 쪽도 값으로 잇는다 — 물가의 톤에서
    // **바깥 물의 톤까지 이어지는 값**을 재서 사다리에 얹는다. 여울이
    // 얹히는 칸은 언제나 lv 0이라 바깥 물빛을 여기서 그대로 알 수 있다.
    //
    // 물가 톤은 빛이 정한다. 빛은 왼쪽 위에서 오니, 둑이 북·서쪽에 있으면
    // 그 그늘이 물에 드리워 짙고(7.7) 남·동쪽이면 볕이 들어 옅다(0.9).
    // 참·거짓으로 가르면 호가 돌다 그늘에서 볕으로 넘어가는 자리에서
    // 가장 어두운 색 옆에 가장 밝은 색이 와 얼룩이 진다 — 비율로 섞는다.
    const d = -s;
    const shade = clamp((nax + nay) * 0.5 + 0.707, 0, 1.414) / 1.414;
    const t1 = waterTone(x, y, 0);                           // 바깥 물
    // 띠 폭은 물가를 따라 흔든다. 일정하면 물가를 그대로 복사한 선이 하나
    // 더 생겨서, 물가가 두 겹으로 보인다
    const band = 3.8 + h(i, 0, 71 + seed) * 2.6 + h(Math.floor(i / 5), 0, 70 + seed) * 2.0;
    if (d >= band) { if (fill) g.px(x, y, ramp(WATER, t1)); return; }
    const t0 = 0.9 + (7.7 - 0.9) * shade;                    // 물가 바로 옆
    const u = smooth(clamp(d / band, 0, 1));
    let c = ramp(WATER, t0 + (t1 - t0) * u);
    // 볕 드는 얕은 물에는 바닥이 비친다. 낱알로 뿌리면 또 자글거리니
    // **덩어리로** 뜨는 값잡음에서 모양을 얻는다
    if (shade < 0.55 && u < 0.62) {
      const b = vnoise(x, y, 93 + seed, 2) * 0.6 + vnoise(x, y, 94 + seed, 4) * 0.4;
      if (b > 0.58) {
        const sandy = mixc(b > 0.74 ? STONE[3] : EARTH[1], c, 0.30 + u * 0.62);
        c = sandy;
      }
    }
    g.px(x, y, c);
    return;
  }
  const k = Math.floor(s);
  // ---- 물가는 **둑이 아니라 비탈이다** ----
  //
  // 여태 벼랑과 같은 붓(rockFace)으로 그렸다. 「둘 다 땅이 끊어져 떨어지는
  // 자리」라는 생각이었는데, 못 가장자리는 끊어져 떨어지는 자리가 아니다 —
  // 물이 흙을 씻어 완만하게 눕힌 자리다. 돌벽을 두르니 못이 아니라
  // **축대를 쌓은 저수지**가 됐고, 곧고 각져 보인 게 그 탓이었다.
  //
  // 물에서 멀어지는 순서로 눕힌다:
  //   젖은 흙 -> 마른 흙 -> 잔돌이 드러난 자리 -> 풀
  // 폭은 자리마다 다르고, 끝은 성글게 흩어져 풀로 넘어간다. 돌은 **벽이
  // 아니라 하나씩** 놓인다.
  const wet = 2 + (h(Math.floor(i / 3), 0, 97 + seed) < 0.45 ? 0 : 1);
  if (k < wet) { g.px(x, y, EARTH[5]); return; }             // 물에 닿아 젖은 자리
  // 물가에 놓인 돌 — 여섯 칸에 하나쯤. 윗면이 밝고 밑이 어두운 한 덩이
  if (h(Math.floor(i / 6), 0, 106 + seed) < 0.24) {
    const sk = k - wet;
    if (sk < 3) {
      g.px(x, y, STONE[sk === 0 ? 2 : (sk === 1 ? 4 : 6)]);
      return;
    }
  }
  // 비탈의 폭 — 두 겹으로 흔든다 (일곱 칸짜리 들쭉날쭉 · 열세 칸짜리 너울).
  //
  // 처음엔 열 켜까지 갔다. 마을 낚시터에 대 보니 못 둘레로 **갈색 진흙이
  // 넓게 둘러** 물이 진흙탕에 담긴 꼴이었다. 물가는 띠지 벌판이 아니다 —
  // 서너 켜면 「물이 씻어 낸 자리」로 충분하고, 그 바깥은 풀이 이긴다
  const band = wet + 1 + Math.round(h(Math.floor(i / 7), 0, 102 + seed) * 2)
    + (h(Math.floor(i / 13), 0, 103 + seed) < 0.35 ? 1 : 0);
  if (k < band) {
    const u = (k - wet) / Math.max(1, band - wet);
    let c = EARTH[4 - Math.round(u * 1.6)];                  // 젖은 흙 -> 마른 흙
    if (h(x, y, 104 + seed) > 0.88) c = STONE[h(x, y, 105 + seed) < 0.5 ? 4 : 5];
    g.px(x, y, c);
    return;
  }
  // 풀로 넘어가는 자락 — 성글게 흩어져야 자로 자른 선이 안 남는다.
  // 빨리 옅어지게 한다 (넓게 깔면 그게 다시 진흙 벌판이 된다)
  if (k < band + 3 && h(x, y, 58 + seed) > 0.30 + (k - band) * 0.34)
    g.px(x, y, EARTH[3]);
}

// 모래사장의 물가 — 같은 자, 다른 재료.
//
// 연못가에는 흙이 솟아 **둑**이 서지만 바닷가에는 그런 턱이 없다. 모래가
// 물속으로 그대로 기울어 들어간다. 그래서 여기엔 돌벽도, 벽이 드리우는
// 그늘도 없다 — 젖은 모래와 밀려온 거품, 그리고 바닥이 비치는 얕은 물뿐이다.
// (모래 위에 돌벽을 세워 놨더니 해변에 옹벽을 친 꼴이었다)
function beachPx(g, x, y, s, nax, nay, i, seed, fill) {
  if (s < 0) {                                               // 물 쪽 — 파도가 닿는 자리
    const d = -s;
    const t1 = waterTone(x, y, 0);                           // 바깥 물
    const band = 5 + h(i, 0, 76 + seed) * 4;
    if (d >= band) { if (fill) g.px(x, y, ramp(WATER, t1)); return; }
    if (d < 1) { g.px(x, y, FOAM); return; }                  // 밀려온 거품 한 줄
    if (d < 2 && h(i, 0, 77 + seed) < 0.45) { g.px(x, y, FOAM); return; }
    // 얕아서 바닥이 훤히 비친다 — 깊어질수록 모래가 물빛에 잠긴다.
    // 여기도 **이어지는 값**으로 섞는다. 층으로 끊으면 물가에 테가 진다
    const u = smooth(clamp((d - 1) / (band - 1), 0, 1));
    const bed = SAND[clamp(Math.round(d) - 1, 0, 5)];
    g.px(x, y, mixc(bed, ramp(WATER, t1), 0.22 + u * 0.78));
    return;
  }
  const k = Math.floor(s);
  if (k < 2) { g.px(x, y, SAND[4]); return; }                 // 젖은 모래 — 짙다
  if (k < 4) { g.px(x, y, SAND[3 - (k - 2)]); return; }       // 마르며 밝아진다
  if (k < 7 && h(x, y, 79 + seed) > 0.22 + (k - 4) * 0.24) g.px(x, y, SAND[2]);
  // 물이 밀어 올려 놓은 것들 — 조개껍데기 부스러기와 조약돌
  if (k === 2 && h(x, y, 80 + seed) < 0.10) g.px(x, y, [246, 236, 226]);
  if (k === 3 && h(x, y, 81 + seed) < 0.08) g.px(x, y, STONE[3]);
}

// 흘러드는 경계 — **이웃 칸의 재료가 이쪽으로 파고든다.**
//
// 물가만 손보고 났더니 이번엔 잔디와 모래, 잔디와 마당의 경계가 계단으로
// 남았다. 바람에 날린 모래도 밟혀 번진 마당 흙도 풀밭 쪽으로 손가락처럼
// 파고들지, 자로 자른 듯 끊기지 않는다. 물가와 같은 자를 쓰되 층은
// 둘뿐이다 — 젖은 둑도 돌벽도 없으니까.
function spill(P, key) {
  return function (g, x, y, s, nax, nay, i, seed) {
    if (s < 2) { g.px(x, y, ramp(P, 1.0)); return; }          // 깎인 귀퉁이까지 통으로
    const k = Math.floor(s);
    // 안으로 갈수록 성기게 — 끝은 알갱이 몇 개만 풀 사이에 남는다
    if (k < 7 && h(x, y, key + seed) > 0.08 + (k - 2) * 0.21)
      g.px(x, y, P[k < 4 ? 1 : 2]);
  };
}

// 두 빛깔 사이를 섞는다. 그냥 섞으면 색이 무한정 늘어나 도트가 사진처럼
// 뭉개지므로 **일곱 단으로 끊어** 섞는다
function mix(a, b, t) {
  const q = Math.round(clamp(t, 0, 1) * 6) / 6;
  return a.map((c, k) => Math.round(c * (1 - q) + b[k] * q));
}

// 계단 마감 — 돌빛이 **점점 흙빛으로** 옅어진다.
//
// 오르막 칸은 통째로 디딤돌이라, 계단이 시작하고 끝나는 자리에서 회색 돌이
// 갈색 흙에 딱 맞붙었다 — 오려 붙인 것처럼 보인다.
//
// 두 번 헛짚었다. ① 끝머리를 흙으로 덮었더니 이음매는 사라졌지만
// **계단이 짧아졌다** (네 단짜리가 두 단이 된다). ② 흙알을 뿌렸더니
// 이번엔 뿌린 자리와 안 뿌린 자리의 경계가 그대로 또렷했다.
//
// 옅어져야 하는 건 **빛깔**이다. 덮는 양은 바깥 한두 켜에만 몰아 주고
// (제곱으로 떨어뜨린다 — 계단은 그대로 네 단이다), 그 대신 찍는 빛깔을
// 변에서는 마당 흙, 안으로 갈수록 돌빛에 가깝게 이어서 섞는다.
function treadPx(g, x, y, s, nax, nay, i, seed) {
  if (s < 0) return;                                  // 딴 쪽 — 그 칸이 그린다
  const k = Math.floor(s);
  // 오르내리는 끝머리는 멀리까지, 옆구리는 짧게 (옆은 벼랑이 바로 붙는다)
  const end = Math.abs(nay) > Math.abs(nax) ? 1.0 : 0.5;
  const reach = (5.5 + h(Math.floor(i / 5), 0, 133 + seed) * 3.2) * end;
  if (k > reach) return;
  const p = clamp(1 - k / Math.max(1, reach), 0, 1);
  // 질감은 낱알보다 **덩이**로 — 두 칸짜리 결에 잔 흔들림을 얹는다
  const t = h(x >> 1, y >> 1, 135 + seed) * 0.66 + h(x, y, 141 + seed) * 0.34;
  if (t > p * p * 0.92) return;                       // 디딤돌이 그대로 보이는 자리
  const soil = EARTH[t < 0.30 ? 2 : (t > 0.76 ? 0 : 1)];   // 마당과 같은 배합
  g.px(x, y, mix(STONE[3], soil, 0.30 + p * 0.70));
}

// 계단이 바닥으로 흘러나온 자리 — **바닥 칸 쪽**에 깐다.
//
// 계단은 그대로 두고 바닥이 마중 나간다. 다만 둘레를 **띠로 두르면**
// 계단에 판을 깔아 놓은 꼴이 된다 — 밟혀 닳은 자리는 띠가 아니라
// **동그랗게 몇 군데**다. 둘레를 따라 크게 부풀렸다 오므라들게 해서
// 짧고 둥근 자국이 이어지게 한다.
//
// 질감도 낱알이 아니라 **두 칸짜리 덩이**로 찍는다. 한 점씩 뿌리면
// 모래를 흩은 것처럼 자글거려서, 거친 맨흙으로 안 보인다
function trailPx(g, x, y, s, nax, nay, i, seed) {
  if (s < 0) return;
  const k = Math.floor(s);
  const lobe = h(Math.floor(i / 7), 0, 136 + seed) * 0.78
    + h(Math.floor(i / 3), 0, 139 + seed) * 0.42;
  const end = Math.abs(nay) > Math.abs(nax) ? 1.0 : 0.5;
  const reach = (1.4 + lobe * 4.4) * end;
  if (k > reach) return;
  const p = clamp(1 - k / Math.max(1, reach), 0, 1);
  const t = h(x >> 1, y >> 1, 137 + seed) * 0.74 + h(x, y, 140 + seed) * 0.26;
  // 밟혀 닳은 맨흙 — 변에 붙을수록 돌빛이 섞인다
  if (t < 0.24 + p * p * 0.66) {
    const soil = EARTH[t < 0.26 ? 3 : (t > 0.70 ? 1 : 2)];
    g.px(x, y, mix(soil, STONE[4], p * p * 0.5));
    return;
  }
  // 굴러 나온 돌 조각 — 가까울수록 잦다. 이것도 멀수록 흙빛에 잠긴다
  if (t > 0.74 && h(Math.floor(i / 3), k >> 1, 138 + seed) < p * p * 0.66)
    g.px(x, y, mix(STONE[k < 3 ? 2 : 4], EARTH[1], (1 - p) * 0.6));
}

// ---- 경계는 이웃 **아홉 칸**으로 잰다 ----
//
// 이웃 넷만 보고 그렸더니, 볼록한 귀퉁이에서 땅 칸은 제 모서리를 깎아
// 물을 들이는데 바로 옆 물 칸은 물가가 아직 타일 변에 있는 줄 알았다.
// 같은 자리를 두 칸이 서로 다르게 그리니 여울 띠가 모서리마다 어긋나
// 뚝 끊겼다 — 「물 쪽이 잘 안 된」 게 이거였다.
//
// 한 칸의 경계 모양은 **이웃 아홉 칸이면 완전히 정해진다**: 변을 이루는
// 두 칸과 그 변의 양 끝에 닿는 네 칸이 모두 그 안에 든다. 그래서 여덟
// 이웃을 비트로 모아 꼴마다 한 장씩 뽑는다. 이웃한 두 칸은 서로 겹치는
// 창을 보므로 경계를 **똑같이** 재고, 이음매가 생길 수가 없다.
//
// 모양은 식이 아니라 **재서** 얻는다. 창을 덮개(0/1)로 깔고 뭉갠 뒤
// 0.5에서 자르면 모서리가 둥글려지고 — 볼록이든 오목이든 한꺼번에 —
// 거기서 부호 거리를 재면 어떤 꼴이든 같은 자로 층을 쌓을 수 있다.
// ---- 벼랑 ----
//
// 높이 차가 있는 땅. 물가와 **똑같은 자**로 잰다 — 위쪽 땅이 「제 편」이고
// 아래쪽 땅이 「딴 쪽」일 뿐이다. 다만 그림은 물가와 주인이 반대다:
// 둑은 높은 쪽(뭍)에 서지만, 벼랑면은 **아래쪽 칸**에 드리운다. 위에서
// 내려다보는 화면에서 벽면이 차지하는 자리가 거기이기 때문이다.
//
// 면은 나를 마주 볼 때만 보인다 — 위쪽 땅이 북쪽에 있을 때. 옆이면
// 비스듬해 좁은 띠만 드러나고, 남쪽이면 등을 돌려 아예 안 보인다.
// (사방에 면을 두르면 땅이 상자가 된다. 물가에서 이미 겪었다)
// 바위면 한 점 — **벼랑과 물가가 같은 붓을 쓴다.**
//
// 물가의 둑을 따로 그렸더니, 같은 세계 안에서 바다 능선은 바위 벼랑이고
// 연못가는 돌담이었다. 둘 다 「땅이 끊어져 떨어지는 자리」다 — 한 붓으로
// 그려야 한 세계가 된다.
//
//   drop  0(마루) ~ 1(발치). 어느 쪽에서 재든 이 값만 맞추면 된다
//   n     면의 높이. 무늬가 면 안에서 어디쯤인지 가늠하는 데 쓴다
function rockFace(g, x, y, drop, n, i, seed) {
  const k = Math.round(drop * Math.max(1, n - 1));
  // **벼랑은 사람이 쌓은 게 아니다.** 막돌(보로노이)로 갈아 봤더니 온
  // 마을이 축대에 둘러싸인 요새가 됐다 — 돌쌓기는 벽·화로처럼 사람 손이
  // 닿은 곳의 말이고, 언덕은 **땅이 잘린 단면**이다. 흙 벼랑:
  //   지층   가로로 눕는 띠. 층마다 낯빛이 조금 다르고 경계는 굽이친다
  //   바위   드문드문 박힌 돌덩이 — 흙에 묻힌 것이라 둘레가 눌린다
  //   풀     마루에서 드리운 풀포기와 뿌리
  const wob = Math.round((h(Math.floor(i / 7), 0, 52 + seed) - 0.5) * 3.0);
  const layer = Math.floor((k + wob) / 3);
  let t = 1.3 + drop * 2.4;
  t += (h(layer, 0, 53 + seed) - 0.5) * 1.1;              // 층마다 낯빛
  // 지층 경계 — 경계 줄은 그늘 골, 바로 아래는 볕 받는 윗변
  if ((k + wob) % 3 === 0 && h(i, layer, 54 + seed) < 0.75) t += 1.0;
  else if ((k + wob) % 3 === 1) t -= 0.4;
  // 세로 물길 — 빗물이 흘러내린 자국. 드물게, 위에서 아래로
  if (h(i, 0, 56 + seed) < 0.10 && k >= 2) t += 0.8;
  if (k === 0) t = 5.4;                                   // 마루에서 드리우는 그늘
  else if (k <= 2) t -= 0.8;                              // 볕이 닿는 윗머리
  g.px(x, y, EARTH[clamp(Math.round(t), 0, EARTH.length - 1)]);
  // 박힌 바위 — 대여섯 칸에 하나. 2x2 덩이로, 윗변이 밝다
  const bi = Math.floor(i / 5), bk = Math.floor(k / 4);
  if (h(bi, bk, 57 + seed) < 0.16 && k > 1) {
    const ri = ((i % 5) + 5) % 5, rk = ((k % 4) + 4) % 4;
    if (ri >= 1 && ri <= 2 && rk >= 1 && rk <= 2) {
      g.px(x, y, STONE[rk === 1 ? 3 : 5]);
      if (ri === 1 && rk === 1) g.px(x, y, STONE[2]);
    }
  }
  // 마루에서 늘어진 풀 — 낱알로 뿌리면 자글거리니 **포기로** 앉힌다.
  // 이게 있어야 벼랑이 땅에서 잘린 것으로 보인다
  if (k >= 1 && k <= 5 && h(Math.floor(i / 2), 0, 55 + seed) < 0.30
    && h(i, k, 63 + seed) < 0.68 - k * 0.09) g.px(x, y, MOSS[k < 3 ? 1 : 2]);
}

// 등을 돌린 벼랑의 **발치.**
//
// 남쪽 땅이 높으면 그 벽은 저쪽을 향해 서 있다 — 면은 안 보인다. 그래서
// 아예 아무것도 안 그렸더니, 대지 뒤쪽이 뒤 배경과 같은 잔디라 **땅이
// 끊어진 자리가 통째로 사라졌다.** 마루선 한 줄로는 어림도 없었다.
//
// 안 보이는 건 벽의 **면**이지 벽이 아니다. 위에서 내려다보면 벽이 선
// 자리에는 늘 접지 그늘이 깔리고, 그 밑으로 부스러진 돌이 흘러내린다.
// 그것만 그린다 — 회색 벽을 세우지 않고도 「여기서 땅이 떨어진다」가 읽힌다.
//
// **끊기지 않는 것이 핵심이다.** 폭은 자리마다 흔들되 한 줄은 반드시 깐다.
// 예전에 옆면 붓으로 뒤쪽을 때웠을 때 회색 토막이 점점이 흩어져 보인 건,
// 「서·동이 높은」 칸에만 그려지고 그 사이 칸은 비었기 때문이다.
function backFoot(g, x, y, k, i, seed) {
  // 그늘 폭 — **두 겹으로** 흔든다. 열두 칸짜리 너울(여기는 깊고 저기는
  // 얕다)에 다섯 칸짜리 들쭉날쭉을 얹는다. 한 겹만 쓰면 폭이 고르게 나와
  // 갈색 리본을 자로 대고 그은 꼴이 된다 — 벼랑 높이(faceH)와 같은 규칙이다
  const b = 3 + Math.round((h(Math.floor(i / 11), 0, 118 + seed) - 0.2) * 3.4)
    + (h(Math.floor(i / 4), 0, 119 + seed) < 0.34 ? 1 : 0);
  // 경계에 바짝 붙은 한 줄은 **벽을 바로 위에서 내려다본 자리**다. 늘 가장
  // 짙고 늘 이어진다 — 이 줄 하나가 「여기서 땅이 끊어진다」를 말한다
  if (k === 0) {
    g.px(x, y, h(i, 0, 120 + seed) < 0.72 ? STONE[7] : EARTH[5]);
    return;
  }
  if (k <= b) {
    // 벽에서 멀어질수록 그늘이 흙빛으로 풀린다. 자리마다 큰 덩이의
    // 명암을 얹어야 한 색으로 발리지 않는다
    const rel = (k - 1) / Math.max(1, b - 1);
    let t = 5.2 - rel * 3.0 + (h(Math.floor(i / 9), 0, 123 + seed) - 0.5) * 1.1;
    t += (h(i, k, 124 + seed) - 0.5) * 0.8;                   // 낱알 흔들림
    g.px(x, y, EARTH[clamp(Math.round(t), 2, 5)]);
    // 흙 사이로 솟은 바위 — 몇 자리에만. 늘어놓으면 다시 회색 실이 된다
    if (k <= 2 && h(Math.floor(i / 5), k, 121 + seed) < 0.26)
      g.px(x, y, STONE[4 + (k % 2)]);
    return;
  }
  // 그늘이 잔디로 풀려 나가는 자리 — 여기서 가장자리가 흐려져야 띠가
  // 그림 위에 얹힌 테이프로 안 보인다
  const d = k - b;
  if (d <= 2 && h(x, y, 125 + seed) < 0.55 - d * 0.22) { g.px(x, y, EARTH[2]); return; }
  if (d <= 3 && h(Math.floor(i / 3), Math.floor((d - 1) / 2), 122 + seed) < 0.22) {
    g.px(x, y, STONE[d % 2 === 0 ? 4 : 5]);
    return;
  }
  if (d <= 3 && h(Math.floor(i / 2), d, 126 + seed) < 0.22) g.px(x, y, MOSS[d < 2 ? 1 : 2]);
}

// 벽 끝을 흘리는 어깨 — 가장자리로 갈수록 낮아진다. 원호라 **바깥이
// 급하고 안이 완만하다** (모서리가 부풀어 보이는 그 곡선이다).
//
// 끝에서 **0까지 떨구면 안 된다.** 비스듬한 경계에서는 칸마다 한쪽씩
// 어깨가 지므로, 0까지 흘리면 벼랑이 낱개 바위 여럿으로 흩어진다 —
// 이어진 벽이 아니라 알을 늘어놓은 꼴이 됐다. 바닥값을 두어 「끊기는」
// 대신 「내려앉게」 한다: 끝머리는 반 칸 높이의 둥근 턱으로 남는다
const SHOULDER = 5;
const SH_FLOOR = 0.0;
function shoulder(d, i, seed) {
  if (d >= SHOULDER) return 1;
  if (d < 0) return SH_FLOOR;
  const t = (SHOULDER - d) / SHOULDER;
  const arc = Math.sqrt(Math.max(0, 1 - t * t));
  return clamp(SH_FLOOR + (1 - SH_FLOOR) * arc
    + (h(i, d, 131 + seed) - 0.5) * 0.14, 0, 1);
}

// 벼랑면 — **아래쪽 칸**에 드리운다. 나를 마주 볼 때(위쪽 땅이 북쪽)만
// 온전히 보이고, 옆이면 좁은 띠, 남쪽이면 등을 돌려 발치만 남는다
function cliffPx(g, x, y, s, nax, nay, i, seed, _fill, code) {
  if (s < 0) return;                                          // 위쪽 땅 — 그 칸이 그린다
  const k = Math.floor(s);
  // 면이 **얼마나 나를 마주 보는가.** 정면이면 1, 옆이면 0.
  //
  // 그대로 쓰면 경계가 비스듬해지는 자리에서 값이 훅 떨어져 벽이 사라진다.
  // 조금이라도 마주 보면 바닥값을 준다 — 비스듬한 벽은 낮아 보일 뿐
  // 없어지지는 않는다
  // 어느 쪽 땅이 높은가는 **꼴 값이 이미 말해 준다** (1=북 2=남 4=서 8=동).
  //
  // 여태 거리장의 기울기(nax/nay)로 짐작했다. 경계가 비뚤면 그 기울기가
  // 칸마다 흔들려서, 같은 벽인데 어느 칸은 그려지고 어느 칸은 안 그려졌다 —
  // 대지 뒤쪽 어깨에서 벽이 토막토막 끊겨 보인 것이 이것이다.
  // 짐작을 그만두고 꼴 값을 그대로 쓴다.
  const hasN = (code & 1) !== 0;                 // 북쪽이 높다 -> 나를 마주 보는 벽
  const hasS = (code & 2) !== 0;                 // 남쪽이 높다 -> 등을 돌린 벽
  const hasW = (code & 4) !== 0, hasE = (code & 8) !== 0;
  const face = clamp(-nay, 0, 1);
  // **벽이 옆에서 끊기는 자리를 둥글린다.**
  //
  // 옆 칸이 벽을 안 세우면(대각선만 높은 칸은 안 세운다 — 계단이 묻히니까)
  // 두 칸 높이 벽이 잔디 위에서 **직각으로 뚝 잘린다.** 세계를 훑어 보니
  // 맞닿은 벽 기둥 1,506쌍 중 530쌍이 그랬다.
  //
  // 옆에 벽이 서는지는 꼴 값이 말해 준다: 북쪽이 높은데 북서가 안 높으면
  // 서쪽 칸에는 벽이 없다(그 칸의 북쪽 = 내 북서다). 그 끝으로 갈수록
  // 벽을 낮춰 **어깨처럼 둥글게** 흘린다. 옆이 이미 높은 땅이면(안쪽
  // 모서리) 그쪽은 옆면이 덮으므로 건드리지 않는다
  const hasNW = (code & 16) !== 0, hasNE = (code & 32) !== 0;
  let taper = 1;
  if (hasN && !hasNW && !hasW) taper = Math.min(taper, shoulder(x, i, seed));
  if (hasN && !hasNE && !hasE) taper = Math.min(taper, shoulder(15 - x, i, seed));
  const lean = hasN ? Math.max(face, 0.56) * taper : 0;  // 북쪽이 아니면 정면은 없다
  const H = faceH(lean, i, seed, true);

  // ---- ⓪ 등을 돌린 쪽 — 면은 없고 발치만 있다 ----
  //
  // 벼랑면은 제 칸과 **그 아래 칸**에 걸쳐 선다. 그런데 남쪽 땅이 높으면
  // 그 아래 칸은 높은 땅 자신이다 — 거기까지 붓이 내려가면 대지 윗면에
  // 회색 자국이 얹힌다 (경계가 꺾이는 모서리에서 옆면 붓이 그럴 수 있다).
  if (hasS && y >= N) return;
  if (hasS && !hasN) backFoot(g, x, y, k, i, seed);

  // ---- ① 옆면을 **먼저 깔고** 정면을 그 위에 얹는다 ----
  //
  // 예전에는 둘 중 하나만 그렸다(정면이면 옆면은 건너뛰기). 경계가 가로에서
  // 세로로 꺾이는 자리마다 벽이 뚝 끊겨, 벼랑이 회색 덩어리 몇 개로 흩어져
  // 보였다 — 「비는 부분」이 그것이다. 먼저 깔아 두면 모서리에서 둘이
  // 이어 붙고, 정면이 있는 칸은 정면이 덮으므로 손해가 없다.
  //
  // 여기서 k는 경계에서 **옆으로** 들어간 거리다. 모서리가 밝고 안으로
  // 갈수록 어두워지면, 그 폭이 곧 벽의 두께로 읽힌다.
  //
  // 뒤쪽 어깨에서 이 붓이 **점선처럼 끊긴 회색 토막**을 남긴 적이 있다 —
  // 「서·동이 높은」 칸에만 그려지고 그 사이 「남쪽만 높은」 칸은 비어서다.
  // 그때는 옆면을 뒤에서 걷어내 고쳤는데, 그러자 뒤쪽이 통째로 사라져
  // 대지와 배경이 구분되지 않았다. 이제 뒤쪽은 발치(backFoot)가 먼저
  // 깔아 두므로 사이가 비지 않는다 — 옆면은 제 할 일만 하면 된다.
  // (경계가 꺾이는 자리에서는 옆 벽이 정말로 조금 보이는 게 맞다)
  if (hasW || hasE) {
    const w = 6 + Math.round(h(Math.floor(i / 4), 0, 110 + seed) * 3);
    if (k < w) {
      let t = 2.2 + (k / Math.max(1, w - 1)) * 3.6;
      t += (h(Math.floor(i / 3), 0, 111 + seed) - 0.5) * 1.2;   // 돌결
      if (h(i, k, 112 + seed) > 0.86) t += 1.0;
      if (k === 0) t -= 0.8;                                    // 모서리는 볕을 받는다
      g.px(x, y, STONE[clamp(Math.round(t), 0, 7)]);
    } else if (k === w) {
      g.px(x, y, EARTH[5]);                                     // 발치 그늘
    } else if (k === w + 1 && h(x, y, 113 + seed) < 0.55) {
      g.px(x, y, EARTH[4]);
    } else if (k === w + 2 && h(x, y, 114 + seed) < 0.25) {
      g.px(x, y, EARTH[3]);
    }
  }

  // ---- ② 나를 마주 보는 면 ----
  if (H >= 3 && k < H) { rockFace(g, x, y, k / (H - 1), H, i, seed); return; }
  if (H >= 3) scree(g, x, y, k - H, i, seed);
}

// 면의 높이. **두 겹으로** 흔든다 — 다섯 칸짜리 덩이(들쭉날쭉)와 열두 칸짜리
// 너울(어디는 높고 어디는 낮은 벼랑). 칸마다 흔들면 밑동이 빗살이 된다.
//
// **벼랑과 물가의 높이가 달라야 한다.** 둘 다 「땅이 끊어져 떨어지는 자리」
// 라 같은 붓을 쓰는데, 벼랑면을 두 칸으로 키우면서 이 값을 그냥 올렸더니
// **연못가도 같이 두 칸짜리 돌벽**이 됐다 — 물가 칸이 통째로 바위로 덮여,
// 못 둘레에 축대를 두른 것처럼 곧고 각진 띠가 생겼다.
// 벼랑은 사람 키만 한 벽이고, 물가는 발에 걸리는 턱이다.
// 물가 쪽은 **더 낮고 더 들쭉날쭉하게.** 열한 켜짜리 돌벽이 못을 한 바퀴
// 두르면 그건 물가가 아니라 **축대**다 — 곧고 각져 보인 진짜 이유다.
// 여섯 켜쯤으로 낮추고 너울을 키우면, 어떤 자리는 돌턱이 서고 어떤 자리는
// (H가 3 밑으로 떨어져) 흙둑만 남는다. 그 둘이 섞여야 자연스러워진다
function faceH(face, i, seed, tall) {
  // 벼랑면의 켜 수. 두 칸짜리 그림(32켜)에 29켜를 꽉 채웠더니 **깎아지른
  // 옹벽**이 됐다 — 마을 부지를 언덕에 얹고 나서 그 벽이 집 앞을 가로로
  // 가로막았다. 스물두 켜로 낮추면 남는 아래쪽은 scree(흘러내린 돌)가
  // 받아, 사람 키 남짓한 돌벽 밑에 자갈 비탈이 깔린 모양이 된다
  const base = tall ? 22.0 : 6.8;
  // 칸마다 확 달라지면 물가에 **빗살**이 선다 — 잔 흔들림은 줄이고
  // 열두 칸짜리 너울로 높낮이를 준다 (둔덕이 오르내리는 결)
  const bump = tall ? 2.5 : 1.4;
  const wave = tall ? 6.0 : 4.2;
  // **잔 결이 없으면 밑동이 자로 그은 수평선이 된다.**
  //
  // 여태 흔들림을 i/5 와 i/12 로만 줬다. 그런데 그림 한 장 안에서 i 는
  // 0~15밖에 안 된다 — i/12 는 값이 둘뿐이고, 같은 꼴(code)·같은 판이면
  // 칸이 몇이든 **완전히 같은 그림**이다. 그래서 벼랑 밑동이 열 칸 내내
  // 한 치도 안 흔들리는 수평선으로 끊겼다 (벽이 아니라 잘라 붙인 판자다).
  // 한 칸짜리·두 칸짜리 결을 더해 밑동을 부스러뜨린다. 물가는 애초에
  // 낮으니 폭을 훨씬 줄인다 — 여기서 크게 흔들면 다시 빗살이 선다
  const fine = tall
    ? (h(i, 0, 128 + seed) - 0.5) * 2.4 + (h(Math.floor(i / 2), 0, 129 + seed) - 0.5) * 3.6
    : (h(i, 0, 128 + seed) - 0.5) * 0.7 + (h(Math.floor(i / 2), 0, 129 + seed) - 0.5) * 1.1;
  // 칸보다 **긴** 너울은 i 로 못 만든다 (i 는 한 장 안에서 0~15뿐이라,
  // i/12 로 주면 칸마다 같은 자리 — 4분의 3 지점 — 에서 턱이 진다).
  // 판(0~2)은 칸마다 골라 쓰므로 그 씨앗으로 준다: 판마다 밑동 높이가
  // 달라져서 벼랑이 칸 단위로 오르내린다
  const stage = (h(0, 0, 67 + seed) - 0.5) * wave;
  return Math.round((base + (h(Math.floor(i / 5), 0, 51 + seed) < 0.45 ? 0 : bump)
    + stage + fine) * face);
}

// 발치 — 접지 그늘과 흘러내린 돌덩이. 이게 없으면 바위가 땅에 꽂힌
// 판자처럼 보인다 (d = 면이 끝난 뒤로 몇 칸)
function scree(g, x, y, d, i, seed) {
  // 접지 그늘 — **두 줄로** 깐다. 높이는 벽 자체보다 그 밑에 지는 그늘이
  // 말해 준다. 한 줄이면 바위와 땅이 그냥 맞닿은 것으로 보인다
  if (d === 0) { g.px(x, y, EARTH[6] || EARTH[5]); return; }
  if (d === 1) { g.px(x, y, h(x, y, 56 + seed) < 0.72 ? EARTH[5] : EARTH[4]); return; }
  if (d === 2 && h(x, y, 96 + seed) < 0.5) { g.px(x, y, EARTH[4]); return; }
  // 낱알로 뿌리면 모래가 된다. 두세 칸짜리 덩이를 놓고 윗변은 밝게
  // 아랫변은 어둡게 (자갈 한 알과 같은 규칙)
  if (d >= 1 && d <= 4 && h(Math.floor(i / 3), Math.floor((d - 1) / 2), 69 + seed) < 0.30) {
    g.px(x, y, STONE[(d - 1) % 2 === 0 ? 3 : 5]);
    if (i % 3 === 2) g.px(x, y, STONE[6]);                    // 덩이 사이 그늘
    return;
  }
  if (d <= 3 && h(x, y, 57 + seed) < 0.22 - d * 0.05) {
    g.px(x, y, STONE[clamp(4 + d, 0, 7)]);
    return;
  }
  // 발치에 돋은 잡풀 — 바위와 잔디가 맞닿기만 하면 잘라 붙인 것처럼
  // 보인다. 몇 포기가 그 사이를 물어야 한 땅이 된다
  if (d >= 1 && d <= 3 && h(Math.floor(i / 2), d, 70 + seed) < 0.20)
    g.px(x, y, MOSS[d < 3 ? 1 : 2]);
}

// 벼랑 마루 — **위쪽 칸**에 얹는다.
//
// 아래쪽 땅이 남쪽이면 그 마루가 빛을 받아 한 줄 밝다. 바로 아래에 붙는
// 바위면의 첫 줄이 짙은 그늘이라, 둘이 만나 「밝은 모서리 -> 그늘 -> 바위」
// 가 되고 그제서야 땅이 **끊어져 떨어지는** 것으로 읽힌다.
function brinkPx(g, x, y, s, nax, nay, i, seed) {
  if (s < 0) return;
  const k = Math.floor(s);
  const lip = clamp(nay, 0, 1);
  // 자로 그은 밝은 줄은 칠해 놓은 선으로 보인다 — 군데군데 흙이 물린다
  const worn = h(Math.floor(i / 3), 0, 60 + seed) < 0.30;
  if (lip <= 0.35) {
    // 등을 돌린 쪽 — 벼랑면이 안 보이는 쪽이다. 여기를 낱알로 흩뿌렸더니
    // (테두리처럼 보일까 봐 그랬다) 뒤쪽 마루가 아예 읽히지 않았다.
    //
    // 밟혀 닳은 **마른 흙 한 줄**을 이어서 깐다. 바로 너머 낮은 땅에는
    // 발치 그늘(backFoot)이 짙게 깔려 있으므로, 밝은 이 줄이 그 위에
    // 얹히면 「밝은 마루 -> 그늘 -> 낮은 땅」이 되어 단이 선다.
    // 색은 흙빛이라 돌벽처럼 튀지 않는다 — 테두리가 아니라 닳은 자리다
    const w = h(Math.floor(i / 6), 0, 66 + seed);
    const b = w < 0.42 ? 0 : (w < 0.86 ? 1 : 2);
    if (k <= b) {
      // 한 줄 안에서도 톤이 흔들려야 칠한 선으로 안 보인다
      const g2 = h(Math.floor(i / 2), k, 71 + seed);
      g.px(x, y, k === 0
        ? (g2 < 0.22 ? STONE[1] : (g2 < 0.62 ? EARTH[0] : EARTH[1]))
        : EARTH[2 + (g2 < 0.5 ? 0 : 1)]);
      return;
    }
    if (k <= b + 2 && h(x, y, 72 + seed) < 0.34 - (k - b) * 0.12) g.px(x, y, EARTH[3]);
    return;
  }
  if (k === 0) { g.px(x, y, worn ? EARTH[2] : STONE[0]); return; }
  if (k === 1) { g.px(x, y, worn ? EARTH[4] : STONE[3]); return; }
  if (k === 2 && h(x, y, 61 + seed) < 0.5) { g.px(x, y, EARTH[2]); return; }
  if (k === 3 && h(x, y, 62 + seed) < 0.22) g.px(x, y, EARTH[3]);
}

const EPAD = 20;                   // 덧대는 논리 칸 (띠가 최대 열세 칸)
const EG = N + 2 * EPAD;           // 창 한 변
const EROUND = 5;                  // 모서리를 둥글리는 반지름 (논리 칸)

// 비트: 1=북 2=남 4=서 8=동 16=북서 32=북동 64=남서 128=남동. 1이면 딴 쪽
function otherAt(code, cx, cy) {
  if (cx === 0 && cy === 0) return false;
  let b;
  if (cy < 0) b = cx < 0 ? 16 : (cx > 0 ? 32 : 1);
  else if (cy > 0) b = cx < 0 ? 64 : (cx > 0 ? 128 : 2);
  else b = cx < 0 ? 4 : 8;
  return (code & b) !== 0;
}

// 상자흐림 세 번 = 종 모양. 모서리를 둥글리는 건 이 한 번뿐이다
function blur3(a, w, r) {
  const t = new Float32Array(a.length);
  const cl = v => clamp(v, 0, w - 1);
  for (let pass = 0; pass < 3; pass++) {
    for (let y = 0; y < w; y++) for (let x = 0; x < w; x++) {
      let sum = 0;
      for (let k = -r; k <= r; k++) sum += a[y * w + cl(x + k)];
      t[y * w + x] = sum / (2 * r + 1);
    }
    for (let y = 0; y < w; y++) for (let x = 0; x < w; x++) {
      let sum = 0;
      for (let k = -r; k <= r; k++) sum += t[cl(y + k) * w + x];
      a[y * w + x] = sum / (2 * r + 1);
    }
  }
}

// 두 번 훑는 체스판 거리 — want 인 칸에서 아닌 칸까지
function chamfer(bin, w, want) {
  const INF = 1e6, d = new Float32Array(w * w).fill(INF);
  const A = 0.9619, B = 1.3604;                              // 오차가 가장 작은 짝
  for (let i = 0; i < d.length; i++) if (bin[i] !== want) d[i] = 0;
  const rd = (x, y) => (x < 0 || y < 0 || x >= w || y >= w) ? INF : d[y * w + x];
  for (let y = 0; y < w; y++) for (let x = 0; x < w; x++) {
    let v = d[y * w + x];
    v = Math.min(v, rd(x - 1, y) + A, rd(x, y - 1) + A,
      rd(x - 1, y - 1) + B, rd(x + 1, y - 1) + B);
    d[y * w + x] = v;
  }
  for (let y = w - 1; y >= 0; y--) for (let x = w - 1; x >= 0; x--) {
    let v = d[y * w + x];
    v = Math.min(v, rd(x + 1, y) + A, rd(x, y + 1) + A,
      rd(x + 1, y + 1) + B, rd(x - 1, y + 1) + B);
    d[y * w + x] = v;
  }
  return d;
}

const FIELD = {};
function edgeField(code) {
  if (FIELD[code]) return FIELD[code];
  const cov = new Float32Array(EG * EG);
  for (let y = 0; y < EG; y++) for (let x = 0; x < EG; x++) {
    const cx = clamp(Math.floor((x - EPAD) / N), -1, 1);
    const cy = clamp(Math.floor((y - EPAD) / N), -1, 1);
    cov[y * EG + x] = otherAt(code, cx, cy) ? 1 : 0;
  }
  blur3(cov, EG, EROUND);
  const bin = new Uint8Array(EG * EG);
  for (let i = 0; i < cov.length; i++) bin[i] = cov[i] < 0.5 ? 1 : 0;   // 1 = 제 편
  const din = chamfer(bin, EG, 1), dout = chamfer(bin, EG, 0);
  const s = new Float32Array(EG * EG);
  for (let i = 0; i < s.length; i++) s[i] = bin[i] ? din[i] - 0.5 : -(dout[i] - 0.5);
  return (FIELD[code] = s);
}

// 한 장. paint 는 (거리 s, 딴 쪽 방향 n, 물가를 따라가는 자리 i)만 본다.
// 물 칸은 부호만 뒤집는다 — 붓은 언제나 「s>0이 뭍」으로 그린다
function edgeTile(code, isLand, paint, vr, hh) {
  const H2 = hh || N;
  const s = edgeField(code), g = H2 > N ? new TT(H2) : new T(), px = paint || bankPx;
  const at = (x, y) => s[(y + EPAD) * EG + (x + EPAD)];
  for (let y = 0; y < H2; y++) for (let x = 0; x < N; x++) {
    let sv = at(x, y);
    // 딴 쪽을 가리키는 방향 = 거리가 줄어드는 쪽
    let gx = (at(x + 1, y) - at(x - 1, y)) * 0.5;
    let gy = (at(x, y + 1) - at(x, y - 1)) * 0.5;
    const L = Math.hypot(gx, gy) || 1;
    let nx = -gx / L, ny = -gy / L;
    if (!isLand) { sv = -sv; nx = -nx; ny = -ny; }
    const i = Math.round(x * Math.abs(ny) + y * Math.abs(nx));
    px(g, x, y, sv, nx, ny, i, (vr || 0) * 31, isLand, code);
  }
  return g;
}


// ---- 뽑기 ----
for (const s of Object.keys(SEASON))
  for (let v = 0; v < 3; v++) save(`grass_${s}_${v}`, grass(s, v).render());
// 길과 마당도 판을 셋씩. 한 장만 깔면 닳은 자국이 같은 자리마다 찍혀
// 바닥에 격자가 뜬다 (자갈은 줄눈이 이어져야 하므로 **배치는 그대로** 두고
// 알의 톤·닳음만 흔든다)
for (let v = 0; v < 3; v++) save('path_' + v, cobble(v * 5).render());
for (let v = 0; v < 3; v++) save('yard_' + v, yard(v).render());
for (let v = 0; v < 3; v++) save('ramp_' + v, rampTile(v).render());
// water_<깊이>_<판>_<장> — 깊이 여덟 × 판 셋 × 장 둘
for (let lv = 0; lv < 8; lv++) for (let vr = 0; vr < 3; vr++) for (let f = 0; f < 2; f++)
  save(`water_${lv}_${vr}_${f}`, water(f, lv, vr).render());
for (let v = 0; v < 3; v++) save('sand_' + v, sandTile(v).render());
for (let v = 0; v < 3; v++) save('dock_' + v, dockTile(v).render());
['n', 's', 'w', 'e'].forEach((d, i) => save('dock_edge_' + d, dockEdge(i).render()));
// 경계 — 이웃 여덟 칸의 꼴(256가지) × 여섯 종류.
//   shore 땅 칸 · shoal 물 칸    연못·강 — 둑이 서고 남쪽을 보는 면에 돌벽
//   beach 모래 칸 · surf 물 칸   바다 — 벽 없이 모래가 기울어 들고 거품이 민다
//   dune · trod                  잔디 칸으로 흘러드는 모래 · 마당 흙
//
// 256가지라지만 **같은 그림이 수두룩하다** — 대각선 이웃은 그 변이 이미
// 경계일 때 아무것도 바꾸지 않는다. 그려 놓고 같은 것끼리 합치면 예순
// 남짓으로 준다. 어느 꼴이 몇 번 그림인지는 표로 내보내 게임이 읽는다.
const KIND = [
  // 물가도 **판을 셋씩.** 꼴(code)이 같으면 그림도 같으므로, 못을 두르는
  // 물가 칸이 죄다 똑같은 무늬였다 — 한 칸마다 되풀이되는 그 무늬가
  // 「쌓아 만든 축대」로 보인 진짜 이유다 (벼랑은 이미 셋이었다)
  ['shore', true, null, 3], ['shoal', false, null, 3],
  ['beach', true, beachPx], ['surf', false, beachPx],
  ['dune', true, spill(SAND, 84)], ['trod', true, spill(EARTH, 96)],
  // tread 는 **오르막 칸 제 안쪽**에 깐다 — 계단이 흙에 묻혀 드는 자리
  ['tread', true, treadPx], ['trail', true, trailPx],
  // 벼랑 — 둘 다 **제 칸 안쪽**으로 층을 쌓는다. cliff 는 아래쪽 칸에서
  // 위를 향해(면), brink 는 위쪽 칸에서 아래를 향해(마루)
  // 벼랑면만 **두 칸 높이**다. 한 칸(화면 32px)으로는 아무리 잘 칠해도
  // 높이가 안 느껴진다 — 층계참이 낮은 턱으로 보인다. 같은 거리장에서
  // 아래로 한 칸 더 이어 뽑으므로 이음매가 생기지 않는다
  ['cliff', true, cliffPx, 3, 2], ['brink', true, brinkPx],
];
// 그림 번호는 **꼴 값 그대로**다. 표를 따로 두면 게임 쪽과 어긋날 여지가
// 생기는데, 어차피 겹치는 꼴이 거의 없어서 아낄 것도 없다 (256 -> 255).
// 0번 자리는 비워 둔다 — 딴 쪽 이웃이 하나도 없으면 그릴 게 없다.
for (const [name, isLand, paint, vars, rows] of KIND) {
  const CH = (rows || 1) * N;
  for (let vr = 0; vr < (vars || 1); vr++) {
    const tiles = new Array(256).fill(null);
    for (let code = 1; code < 256; code++)
      tiles[code] = edgeTile(code, isLand, paint, vr, CH).small();
    atlas('edge_' + name + (vars ? '_' + vr : ''), tiles, CH);
  }
}

['n', 's', 'w', 'e'].forEach((d, i) => save('path_edge_' + d, cobbleEdge(i).render()));

// 연석 — **길 안쪽** 가장자리의 어두운 한 단. 길이 끝나는 자리가 접혀
// 내려가는 골이다. 남쪽(아래) 변은 그늘이 지는 쪽이라 한 단 더 짙다.
// 자로 그은 통줄이면 테두리 액자가 되므로 드문드문 이가 빠진다
function pathCurb(dir) {
  const g = new T();
  const put = (i, k, c) => {
    if (dir === 0) g.px(i, k, c);
    else if (dir === 1) g.px(i, N - 1 - k, c);
    else if (dir === 2) g.px(k, i, c);
    else g.px(N - 1 - k, i, c);
  };
  const deep = dir === 1;                       // 남쪽 변 = 그늘
  for (let i = 0; i < N; i++) {
    if (h(i, dir, 95) < 0.88) put(i, 0, STONE[deep ? 6 : 5]);
    if (h(i, dir, 97) < (deep ? 0.55 : 0.35)) put(i, 1, STONE[deep ? 5 : 4]);
  }
  return g;
}
['n', 's', 'w', 'e'].forEach((d, i) => save('path_curb_' + d, pathCurb(i).render()));
save('soil_dry', soil(false).render());
save('soil_wet', soil(true).render());

console.log(`바닥 ${Object.keys(OUT).length}장 — ${F}x${F} (논리 ${N}x${N} · 화면에서 도트 2px)`);
console.log(INSTALL ? '  sprites/ 에 넣었다'
  : '  ref/proposed_*.png 로만 뽑았다 (--install 을 붙이면 게임에 넣는다)');


// ---- 미리보기 ----
//
// 타일 한 장만 봐서는 아무것도 모른다. **게임에 그려지는 크기(0.5배)** 로
// 깔아 놓고, 그 위에 건물과 사람을 세워 봐야 같은 그림인지 알 수 있다.
const TILE = 32, VW = 30, VH = 15;
const PW = VW * TILE, PH = VH * TILE;
const scene = new PNG({ width: PW, height: PH });
scene.data.fill(255);

function blit(im, ox, oy, scale) {
  for (let y = 0; y < im.height * scale; y++) for (let x = 0; x < im.width * scale; x++) {
    const s = ((Math.floor(y / scale)) * im.width + Math.floor(x / scale)) * 4;
    if (im.data[s + 3] < 128) continue;
    const X = ox + x, Y = oy + y;
    if (X < 0 || Y < 0 || X >= PW || Y >= PH) continue;
    const d = (Y * PW + X) * 4;
    scene.data[d] = im.data[s]; scene.data[d + 1] = im.data[s + 1];
    scene.data[d + 2] = im.data[s + 2]; scene.data[d + 3] = 255;
  }
}

const DOOR_X = 13;
const isRoad = (x, y) => (y >= 10 && y <= 11) || (x >= DOOR_X && x <= DOOR_X + 1 && y >= 8);
for (let y = 0; y < VH; y++) for (let x = 0; x < VW; x++) {
  if (isRoad(x, y)) { blit(OUT['path_' + Math.floor(h(x, y, 88) * 3)], x * TILE, y * TILE, 0.5); continue; }
  blit(OUT[`grass_spring_${Math.floor(h(x, y, 77) * 3)}`], x * TILE, y * TILE, 0.5);
  if (isRoad(x, y - 1)) blit(OUT['path_edge_n'], x * TILE, y * TILE, 0.5);
  if (isRoad(x, y + 1)) blit(OUT['path_edge_s'], x * TILE, y * TILE, 0.5);
  if (isRoad(x - 1, y)) blit(OUT['path_edge_w'], x * TILE, y * TILE, 0.5);
  if (isRoad(x + 1, y)) blit(OUT['path_edge_e'], x * TILE, y * TILE, 0.5);
}
for (let y = 3; y < 6; y++) for (let x = 22; x < 27; x++)       // 밭 한 뙈기
  blit(OUT[x < 25 ? 'soil_wet' : 'soil_dry'], x * TILE, y * TILE, 0.5);

const grab = f => { try { return PNG.sync.read(fs.readFileSync(f)); } catch (e) { return null; } };
const house = grab(REF + 'proposed_house.png') || grab(SPR + 'house.png');
const boy = grab(SPR + 'new_boy_down_idle.png');
if (house) blit(house, (DOOR_X - 3) * TILE - 8, 10 * TILE - Math.round(house.height * 0.5), 0.5);
if (boy) {
  blit(boy, (DOOR_X - 1) * TILE + 4, 11 * TILE - 24, 0.5);
  blit(boy, 5 * TILE, 12 * TILE - 20, 0.5);
}
fs.writeFileSync(REF + 'preview_ground.png', PNG.sync.write(scene));
console.log('preview_ground.png — 길·잔디·밭 위에 건물과 사람 (게임 크기 그대로)');
