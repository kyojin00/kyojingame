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
}

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
function yard() {
  const g = new T(), p = SEASON.spring;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const v = h(x >> 1, y >> 1, 61) * 0.6 + h(x, y, 62) * 0.4;
    g.px(x, y, EARTH[v < 0.30 ? 2 : (v > 0.76 ? 0 : 1)]);
  }
  // 발에 파인 자국 — 가로로 길게 눌린 자리
  for (let i = 0; i < 5; i++) {
    const ox = Math.floor(h(i, 3, 63) * N), oy = Math.floor(h(3, i, 64) * N);
    for (let k = 0; k < 3 + Math.floor(h(i, i, 65) * 3); k++)
      g.px(ox + k, oy, EARTH[3]);
    g.px(ox, oy - 1, EARTH[2]);
  }
  // 잔돌 몇 알
  for (let i = 0; i < 3; i++) {
    const ox = Math.floor(h(i + 9, 5, 66) * N), oy = Math.floor(h(5, i + 9, 67) * N);
    g.px(ox, oy, STONE[2]); g.px(ox + 1, oy, STONE[3]);
    g.px(ox, oy + 1, STONE[4]);
  }
  // 밟히고도 살아남은 풀 두 포기 — 이게 있어야 흙바닥이 아니라 마당이다
  for (let i = 0; i < 2; i++)
    tuft(g, Math.floor(h(i + 30, 7, 68) * N), Math.floor(h(7, i + 30, 69) * N), p, false);
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

// deep = 물가에서 멀어진 한가운데. 물 타일이 한 장뿐이면 어디를 봐도 같은
// 깊이라 얕아 보인다. 가장자리 물과 **한가운데 물**을 갈라야 깊이가 생긴다.
function water(frame, deep) {
  const g = new T();
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    // 깊이 — 덩어리로 갈린다. 칸마다 흔들면 물이 아니라 모래가 된다
    const v = h(x >> 2, y >> 2, 51) * 0.6 + h(x >> 1, y >> 1, 52) * 0.4;
    g.px(x, y, WATER[deep ? (v < 0.3 ? 8 : (v > 0.72 ? 6 : 7)) : (v < 0.3 ? 6 : (v > 0.72 ? 4 : 5))]);
  }
  // 잔물결 — 가로로 짧게 그은 줄. 두 장이 서로 어긋나야 물이 흐른다
  // 잔물결은 **다섯 줄이면 족하다.** 아홉 줄을 그었더니 타일이 반복되면서
  // 대각선 줄무늬가 물 전체를 덮었다 — 물결이 아니라 빗금이었다
  for (let i = 0; i < 5; i++) {
    const ox = Math.floor(h(i, frame, 53) * N);
    const oy = Math.floor(h(frame, i, 54) * N);
    const len = 2 + Math.floor(h(i, i + frame, 55) * 3);
    const lift = deep ? 2 : 0;
    for (let k = 0; k < len; k++) g.px(ox + k, oy, WATER[(i % 2 ? 3 : 4) + lift]);
    g.px(ox - 1, oy, WATER[6 + lift]);
  }
  // 물속에 비치는 바닥 — 모래톱과 조약돌, 수초 한 포기.
  // 깊은 물이라 많이 섞는다(0.62) — 형태만 어렴풋이 보이는 정도
  for (let i = 0; i < 3; i++) {
    const ox = Math.floor(h(i + 11, frame, 81) * N), oy = Math.floor(h(frame, i + 11, 82) * N);
    for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 3; dx++)
      if (!deep && h(ox + dx, oy + dy, 83) < 0.7) g.px(ox + dx, oy + dy, thru(EARTH[1], 0.80));
  }
  for (let i = 0; i < (deep ? 0 : 4); i++) {
    const ox = Math.floor(h(i + 21, 5, 84) * N), oy = Math.floor(h(5, i + 21, 85) * N);
    g.px(ox, oy, thru(STONE[2], 0.78)); g.px(ox + 1, oy, thru(STONE[3], 0.78));
    g.px(ox, oy + 1, thru(STONE[4], 0.80));
  }
  for (let i = 0; i < (deep ? 0 : 2); i++) {                 // 수초
    const ox = Math.floor(h(i + 31, 7, 86) * N), oy = Math.floor(h(7, i + 31, 87) * N);
    for (const [dx, len] of [[-1, 2], [0, 3], [1, 2]])
      for (let k = 0; k <= len; k++)
        g.px(ox + dx, oy - k, thru(SEASON.summer[k === len ? 'tip' : 'base'], 0.72));
  }
  return g;
}

// 물가 — **땅 쪽**에 얹는 덧그림. 물이 그쪽에 있다 (0=위 1=아래 2=왼 3=오른)
//
// 물가는 **파인 자리**다. 흰 거품 줄만 그었더니 물이 땅 위에 얹힌 것처럼
// 얕아 보였다 (그건 파도가 치는 바다의 그림이다). 연못·호수는 다르다:
//
//   둑     가장자리에 흙이 솟는다. 윗면이 빛을 받아 한 줄 밝다
//   안쪽   둑 안으로는 **빈틈없이** 짙은 젖은 흙. 성기게 뿌리면 둑이 안 생긴다
//   바깥   마르며 잔디로 넘어간다. 여기만 성기게
function shore(dir) {
  const g = new T();
  const put = (i, k, c) => {
    if (dir === 0) g.px(i, k, c);
    else if (dir === 1) g.px(i, N - 1 - k, c);
    else if (dir === 2) g.px(k, i, c);
    else g.px(N - 1 - k, i, c);
  };
  // 물가는 **단차**다.
  //
  // 젖은 흙 띠만 둘렀더니 물이 땅과 같은 높이에 있었다. 실제 물가는
  // 땅이 한 단 꺼지는 자리라, 그 턱에 **돌이 물려 있다.** 위에서 보면
  // 돌 윗면이 빛을 받고 물 쪽 아랫면은 그늘진다 — 그 두 줄이 높이차다.
  //
  //   바깥  풀에서 넘어오는 마른 흙
  //   둑    돌 한 줄. 윗면은 밝고 아랫면은 어둡다 (여기가 턱이다)
  //   안쪽  턱 밑 그늘. 물에 잠긴 돌뿌리
  for (let i = 0; i < N; i++) {
    const lip = 4 + Math.floor(h(i, dir, 56) * 3);          // 턱이 시작되는 깊이
    const dry = lip + 2 + Math.floor(h(i, dir, 57) * 4);
    // 턱 밑 그늘 — 물에 제일 가까운 두 줄
    for (let k = 0; k < 2; k++) put(i, k, EARTH[5]);
    // 돌 한 줄 — 세 칸짜리 덩어리로 물려 있다
    const st = 1 + Math.floor(h(Math.floor(i / 3), dir, 63) * 3);
    for (let k = 2; k < lip; k++) {
      const top = (k === lip - 1);
      put(i, k, STONE[top ? Math.max(0, st - 1) : Math.min(7, st + 2)]);
    }
    if (i % 3 === 2) for (let k = 2; k < lip; k++) put(i, k, STONE[6]);  // 돌 사이 틈
    // 바깥 — 마른 흙에서 잔디로
    for (let k = lip; k < dry; k++)
      if (h(i, k, dir + 58) > 0.10 + (k - lip) * 0.18) put(i, k, EARTH[k === lip ? 2 : 3]);
  }
  return g;
}

// 여울 — **물 쪽**에 얹는 덧그림. 땅이 그쪽에 있다.
//
// 깊이는 **둑이 물에 드리우는 그늘**이 만든다. 빛은 왼쪽 위에서 오므로
// 위·왼쪽 물가는 그늘져 짙고, 아래·오른쪽은 볕이 들어 얕게 비친다.
// 사방을 똑같이 밝게 둘렀더니 물이 접시처럼 평평했다.
function shoal(dir) {
  const g = new T();
  const shadow = (dir === 0 || dir === 2);                  // 위·왼쪽이 그늘
  const put = (i, k, c) => {
    if (dir === 0) g.px(i, k, c);
    else if (dir === 1) g.px(i, N - 1 - k, c);
    else if (dir === 2) g.px(k, i, c);
    else g.px(N - 1 - k, i, c);
  };
  for (let i = 0; i < N; i++) {
    const deep = 3 + Math.floor(h(i, dir, 71) * 4);
    for (let k = 0; k < deep; k++) {
      if (k > 1 && h(i, k, dir + 72) < 0.08 + k * 0.11) continue;
      if (shadow) put(i, k, WATER[k < 2 ? 7 : 6]);          // 둑 그늘
      else put(i, k, WATER[k === 0 ? 0 : (k < 3 ? 1 : 2)]);  // 볕 드는 얕은 물
    }
    if (!shadow) {
      // 얕은 쪽은 바닥이 훨씬 잘 보인다 — 조금만 섞는다(0.3)
      if (h(i, 1, dir + 73) < 0.34) put(i, 1, thru(EARTH[1], 0.3));
      if (h(i, 2, dir + 74) < 0.22) put(i, 2, thru(STONE[3], 0.35));
      if (h(i, 3, dir + 75) < 0.18) put(i, 3, thru(EARTH[2], 0.45));
    }
  }
  return g;
}


// ---- 뽑기 ----
for (const s of Object.keys(SEASON))
  for (let v = 0; v < 3; v++) save(`grass_${s}_${v}`, grass(s, v).render());
save('path', cobble(0).render());
save('yard', yard().render());
save('water_0', water(0, false).render());
save('water_1', water(1, false).render());
save('water_deep_0', water(0, true).render());
save('water_deep_1', water(1, true).render());
['n', 's', 'w', 'e'].forEach((d, i) => save('shore_' + d, shore(i).render()));
['n', 's', 'w', 'e'].forEach((d, i) => save('shoal_' + d, shoal(i).render()));
['n', 's', 'w', 'e'].forEach((d, i) => save('path_edge_' + d, cobbleEdge(i).render()));
save('soil_dry', soil(false).render());
save('soil_wet', soil(true).render());

console.log(`바닥 ${12 + 1 + 1 + 4 + 4 + 2 + 4 + 4}장 — ${F}x${F} (논리 ${N}x${N} · 화면에서 도트 2px)`);
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
  if (isRoad(x, y)) { blit(OUT['path'], x * TILE, y * TILE, 0.5); continue; }
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
