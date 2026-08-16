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
  const CW = 4, CH = 4;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const course = Math.floor(y / CH);
    const u = x + (course % 2) * (CW / 2);
    const col = Math.floor(u / CW);
    const r = h(col, course, seed);
    let i = 1 + Math.floor(r * 4.0);                        // 알마다 톤이 다르다
    const ry = y % CH, rx = ((u % CW) + CW) % CW;
    if (ry === 0) i -= 1;                                   // 윗줄 = 빛
    if (ry === CH - 1) i += 2;                              // 아랫줄 = 가로 줄눈
    if (rx === CW - 1) i += 2;                              // 오른줄 = 세로 줄눈
    // 밟혀 닳은 알 — 가운데가 유난히 밝다
    if (ry === 1 && rx === 1 && h(col, course, seed + 5) < 0.30) i -= 2;
    // 금 간 알
    if (ry === 1 && rx === 2 && h(col, course, seed + 7) < 0.20) i += 3;
    g.px(x, y, STONE[clamp(i, 0, 7)]);
    // 빠진 알 — 흙이 드러난 자리. 이게 있어야 깔아 놓기만 한 길이 아니라
    // 밟고 다닌 길이 된다
    if (h(col, course, seed + 9) < 0.10)
      g.px(x, y, EARTH[2 + (h(x, y, seed + 3) < 0.4 ? 1 : 0)]);
  }
  // 줄눈에 낀 이끼 — 어두운 줄눈 자리에만, 덩어리로
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const c = g.get(x, y);
    if (c !== STONE[5] && c !== STONE[6] && c !== STONE[7] && !EARTH.includes(c)) continue;
    if (h(x >> 1, y >> 1, seed + 11) > 0.20) continue;
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
  spring: { base: [96, 150, 74], lo: [80, 130, 62], hi: [112, 168, 86],
            dark: [58, 100, 48], tip: [140, 194, 104],
            bloom: [[238, 228, 138], [240, 242, 232]] },
  summer: { base: [80, 138, 64], lo: [64, 118, 54], hi: [96, 158, 74],
            dark: [46, 92, 44], tip: [124, 184, 88],
            bloom: [[230, 148, 172], [152, 172, 226]] },
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
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const v = h(x >> 2, y >> 2, variant) * 0.45 + h(x >> 1, y >> 1, variant + 9) * 0.55;
    g.px(x, y, v < 0.38 ? p.lo : p.base);                   // 바탕은 두 단만
  }
  // ② 흙이 드러난 자리 — 풀만 빽빽하면 양탄자가 되지만, **아주 드물게**.
  //    10%로 뿌렸더니 들판이 녹슨 카펫이 됐다. 색도 순 흙빛이 아니라
  //    잔디 쪽으로 당겨 섞는다 — 풀 사이로 비치는 흙은 그만큼 죽어 보인다
  const soilTone = k => p.base.map((v, j) => Math.round(v * 0.45 + EARTH[k][j] * 0.55));
  const s1 = soilTone(1), s2 = soilTone(2);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    if (h(x >> 1, (y >> 1) + 40, variant) > 0.035) continue;
    g.px(x, y, season === 'winter' ? p.lo : (h(x, y, 5) < 0.5 ? s1 : s2));
  }
  // ③ 포기 — 다섯. 많이 심을수록 타일이 「무늬」로 기억된다
  for (let i = 0; i < 5; i++) {
    const ox = Math.floor(h(i, variant, 1) * N);
    const oy = Math.floor(h(variant, i, 2) * N);
    tuft(g, ox, oy, p, h(i, i + variant, 6) < 0.4);
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
function yard(v) {
  const g = new T(), p = SEASON.spring, s = v * 13;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const t = h(x >> 1, y >> 1, 61) * 0.6 + h(x, y, 62) * 0.4;
    g.px(x, y, EARTH[t < 0.30 ? 2 : (t > 0.76 ? 0 : 1)]);
  }
  // 발에 파인 자국 — 가로로 길게 눌린 자리
  for (let i = 0; i < 5; i++) {
    const ox = Math.floor(h(i + s, 3, 63) * N), oy = Math.floor(h(3, i + s, 64) * N);
    for (let k = 0; k < 3 + Math.floor(h(i + s, i, 65) * 3); k++)
      g.px(ox + k, oy, EARTH[3]);
    g.px(ox, oy - 1, EARTH[2]);
  }
  // 잔돌 몇 알
  for (let i = 0; i < 3; i++) {
    const ox = Math.floor(h(i + 9 + s, 5, 66) * N), oy = Math.floor(h(5, i + 9 + s, 67) * N);
    g.px(ox, oy, STONE[2]); g.px(ox + 1, oy, STONE[3]);
    g.px(ox, oy + 1, STONE[4]);
  }
  // 밟히고도 살아남은 풀 두 포기 — 이게 있어야 흙바닥이 아니라 마당이다
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
const DECK = [[168, 130, 88], [146, 110, 72], [124, 92, 58],
              [102, 74, 46], [80, 57, 35], [58, 40, 24]];

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
  if (k < 2) { g.px(x, y, EARTH[5]); return; }               // 물에 닿는 젖은 자리
  // 물가의 턱은 **벼랑과 같은 붓**으로 그린다.
  //
  // 따로 그렸더니 같은 세계 안에서 바다 능선은 바위 벼랑이고 연못가는
  // 돌담이었다. 둘 다 「땅이 끊어져 떨어지는 자리」다. 다만 재는 방향이
  // 반대라 — 여기서는 k가 물에서 뭍으로 들어가고, 벼랑에서는 마루에서
  // 발치로 내려간다 — drop 을 뒤집어 넘긴다
  const H = faceH(clamp(nay, 0, 1), i, seed);
  if (H >= 3) {
    const top = 2 + H;
    if (k < top) { rockFace(g, x, y, 1.0 - (k - 2) / (H - 1), H, i, seed); return; }
    // 마루 — 하늘을 보는 한 줄. 여기가 밝아야 바로 밑 바위면의 윗변이 되고,
    // 둘이 만나 땅이 끊어져 떨어지는 것으로 읽힌다
    if (k === top) { g.px(x, y, STONE[h(Math.floor(i / 3), 0, 60 + seed) < 0.3 ? 3 : 1]); return; }
    if (k === top + 1) { g.px(x, y, EARTH[2]); return; }
    if (k < top + 3 && h(x, y, 58 + seed) > 0.25) g.px(x, y, EARTH[3]);
    return;
  }
  // 둑의 윗면. 옆으로 갈수록(nax) 넓고 돌이 많이 드러난다
  const side = Math.abs(nax) > 0.55;
  const w2 = side ? 6 : 4;
  if (k < w2 && h(x, y, 57 + seed) > 0.14 + (k - 2) * 0.17)
    g.px(x, y, EARTH[k < 4 ? 4 : 3]);
  if (side) {
    const st = 2 + Math.floor(h(Math.floor(i / 3), 0, 66) * 3);
    if (k < 5 && h(x, y, 67 + seed) > 0.35) g.px(x, y, STONE[clamp(st + (k - 2), 0, 7)]);
    if (k === 2 && i % 3 === 0) g.px(x, y, STONE[6]);
  } else {
    if (k === 2 && h(x, y, 62 + seed) < 0.28) g.px(x, y, STONE[4]);
    if (k === 3 && h(x, y, 64 + seed) < 0.20) g.px(x, y, STONE[3]);
  }
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
  // 바위는 **세로로 쪼개진다.** 벽돌처럼 가로 켜로 쌓았더니 벼랑이 아니라
  // 정원 담장이 됐다. 다만 기둥마다 톤을 크게 흔들면 이번엔 나무 울타리가
  // 된다 — 결은 은근히 두고, 몇 자리에만 깊은 틈과 가로 선반을 넣는다.
  // 바위는 고른 결이 아니라 **몇 개의 큰 사건**으로 읽힌다
  const v = (h(i, 0, 52 + seed) - 0.5) * 0.9 + (h(Math.floor(i / 4), 0, 53 + seed) - 0.5) * 0.9;
  // 위는 더 밝게, 발치는 더 어둡게. **높이는 명암차로 읽힌다** — 면을 두
  // 칸으로 늘려 놓고 톤 폭이 그대로면 늘어난 만큼 밋밋해질 뿐이다
  let t = 2.2 + drop * 3.4 + v;
  // 갈라진 틈 — 위에서 아래까지 곧게 뚫리면 기둥이 선 담장이 된다.
  // 시작과 끝을 자리마다 달리해 **조각조각** 갈라지게 한다
  if (h(i, 0, 54 + seed) < 0.17) {
    const c0 = Math.floor(h(i, 1, 79 + seed) * n * 0.55);
    if (k >= c0 && k <= c0 + 1 + Math.floor(h(i, 2, 80 + seed) * n * 0.5)) t += 2.0;
  }
  // 큰 덩이의 명암 — 어디는 볕을 받고 어디는 그늘에 든다. 이게 없으면
  // 면 전체가 한 색이라 콘크리트가 된다
  t += (h(Math.floor(i / 9), 0, 81 + seed) - 0.5) * 0.9;
  // 무늬층 — 가로로 눕는 켜. 세로 결만 있으면 나무 판자로 보인다
  t += (h(Math.floor((k + Math.floor(i / 7)) / 3), 0, 68 + seed) - 0.5) * 0.9;
  // 바위 선반 — 자리마다 높이가 다르고, 없는 데도 있다
  const sh = h(Math.floor(i / 5), 0, 64 + seed);
  const shelf = sh < 0.62 ? 2 + Math.floor(sh * 1.6 * Math.max(1, n - 5)) : -9;
  if (k === shelf) t -= 1.2;                                  // 윗면이 빛을 받는다
  else if (k === shelf + 1) t += 0.9;                         // 그 밑은 그늘
  if (drop > 0.82) t += 0.7;                                  // 발치는 그늘에 잠긴다
  if (k === 0) t = 7.4;                                       // 위에서 드리우는 그늘
  else if (k <= 2) t -= 1.0;                                  // 볕이 닿는 윗면
  g.px(x, y, STONE[clamp(Math.round(t), 0, 7)]);
  // 마루에서 늘어진 이끼 — 낱알로 뿌리면 자글거리니 **포기로** 앉힌다.
  // 이게 있어야 바위가 땅에서 솟은 것으로 보인다
  if (k >= 1 && k <= 5 && h(Math.floor(i / 2), 0, 55 + seed) < 0.22
    && h(i, k, 63 + seed) < 0.62 - k * 0.09) g.px(x, y, MOSS[k < 3 ? 1 : 2]);
}

// 벼랑면 — **아래쪽 칸**에 드리운다. 나를 마주 볼 때(위쪽 땅이 북쪽)만
// 온전히 보이고, 옆이면 좁은 띠, 남쪽이면 등을 돌려 아예 안 보인다
function cliffPx(g, x, y, s, nax, nay, i, seed) {
  if (s < 0) return;                                          // 위쪽 땅 — 그 칸이 그린다
  const k = Math.floor(s);
  const face = clamp(-nay, 0, 1);
  const H = faceH(face, i, seed);
  if (H >= 3 && k < H) { rockFace(g, x, y, k / (H - 1), H, i, seed); return; }
  if (H >= 3) { scree(g, x, y, k - H, i, seed); return; }
  // 비스듬히 보이는 옆면 — 바위가 좁게 드러날 뿐이다
  if (Math.abs(nax) > 0.5) {
    const w = 3 + (h(i, 0, 58 + seed) < 0.5 ? 0 : 1);
    if (k < w) g.px(x, y, STONE[clamp(3 + k + (h(i, k, 59 + seed) < 0.30 ? -1 : 0), 0, 7)]);
    else if (k === w && h(x, y, 60 + seed) < 0.4) g.px(x, y, EARTH[4]);
  }
}

// 면의 높이. **두 겹으로** 흔든다 — 다섯 칸짜리 덩이(들쭉날쭉)와 열두 칸짜리
// 너울(어디는 높고 어디는 낮은 벼랑). 칸마다 흔들면 밑동이 빗살이 된다
function faceH(face, i, seed) {
  // 한 칸(16)에서 **스물넷**으로. 화면에서 32px -> 48px 이다.
  // 나머지 여덟 칸은 발치(scree)가 받아, 두 칸째가 통째로 바위벽이 아니라
  // 「벽 밑에 무너져 쌓인 자리」가 된다 — 거기 사람이 서면 벽 앞에 선
  // 것으로 보이지, 벽 속에 박힌 것으로 보이지 않는다
  return Math.round((24.0 + (h(Math.floor(i / 5), 0, 51 + seed) < 0.45 ? 0 : 3.0)
    + (h(Math.floor(i / 12), 0, 67 + seed) - 0.5) * 5.0) * face);
}

// 발치 — 접지 그늘과 흘러내린 돌덩이. 이게 없으면 바위가 땅에 꽂힌
// 판자처럼 보인다 (d = 면이 끝난 뒤로 몇 칸)
function scree(g, x, y, d, i, seed) {
  if (d === 0) { g.px(x, y, EARTH[5]); return; }
  if (d === 1 && h(x, y, 56 + seed) < 0.62) { g.px(x, y, EARTH[4]); return; }
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
    // 등을 돌린 쪽 — 여기서는 벼랑면이 아예 안 보인다. 마루까지 또렷하게
    // 그으면 땅에 테두리를 두른 꼴이 된다. 흙이 조금 드러날 뿐이다
    if (k <= 1 && h(x, y, 66 + seed) < 0.5 - k * 0.26) g.px(x, y, EARTH[3]);
    return;
  }
  if (k === 0) { g.px(x, y, worn ? EARTH[3] : STONE[1]); return; }
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
    px(g, x, y, sv, nx, ny, i, (vr || 0) * 31, isLand);
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
  ['shore', true, null], ['shoal', false, null],
  ['beach', true, beachPx], ['surf', false, beachPx],
  ['dune', true, spill(SAND, 84)], ['trod', true, spill(EARTH, 96)],
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
