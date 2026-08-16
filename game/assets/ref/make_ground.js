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

// 깊이는 **세 단**이다 (lv 0 얕은 물 · 1 중간 · 2 한가운데).
//
// 두 단뿐일 때는 연못 한가운데에 **검푸른 직사각형**이 오려 붙은 것처럼
// 떴다. 한 번에 두 계단을 뛰니 그 경계가 타일 변을 따라 그대로 보인 것이다.
// 사이에 한 단을 끼워 계단을 한 칸씩으로 낮추면, 같은 직각 경계라도 눈에
// 걸리지 않고 물이 가운데로 갈수록 깊어지는 것처럼 읽힌다.
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

// 깊이는 **다섯 단**, 한 단이 반 톤이다 (물가 5 -> 한가운데 7).
//
// 처음엔 두 단이었다. 연못 한가운데에 검푸른 **직사각형**이 오려 붙은 것
// 처럼 떴다 — 한 번에 두 톤을 뛰니 그 경계가 타일 변을 따라 그대로 보였다.
// 세 단으로 늘려도 계단이 셋 보일 뿐이었다. 계단을 **반 톤**까지 낮추고
// 단을 다섯으로 늘리자 비로소 경계가 안 보이고 물이 가운데로 갈수록
// 깊어지는 것처럼 읽힌다. 반 톤은 사다리 사이를 절반씩 섞어 만든다.
function baseWater(x, y, lv) {
  const v = vnoise(x, y, 51, 4) * 0.62 + vnoise(x, y, 52, 2) * 0.38;
  return ramp(WATER, 5 + (lv || 0) * 0.72 + (v - 0.5) * 1.7);
}

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
    const t = 4.5 + lv * 0.72;
    for (let k = 0; k < len; k++) g.px(ox + k, oy, ramp(WATER, t + (i % 2) * 0.5));
    g.px(ox - 1, oy, ramp(WATER, t + 1.5));
  }
  // 물속에 비치는 바닥 — 모래톱과 조약돌, 수초 한 포기.
  // 깊을수록 물빛에 더 섞여 형체만 남다가 결국 안 보인다
  const mix = Math.min(0.95, 0.80 + lv * 0.045);
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
  for (let i = 0; i < (lv === 0 ? 2 : 0); i++) {             // 수초
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
    // 물 쪽 — 여울. 둑이 드리우는 그늘은 뭍이 **북·서쪽**에 있을 때 진다.
    //
    // 그늘이냐 아니냐를 **참·거짓으로 가르면** 호가 돌아 나가다 그늘에서
    // 볕으로 넘어가는 순간 가장 어두운 색 옆에 가장 밝은 색이 와서 얼룩이
    // 진다. 빛은 왼쪽 위에서 오니 물 쪽 방향 n 을 그 빛에 견줘 **비율로**
    // 섞는다 — 곧은 물가에서는 그대로 0 아니면 1이라 이웃과 어긋나지 않는다
    const d = Math.floor(-s);
    const shade = clamp((nax + nay) * 0.5 + 0.707, 0, 1.414) / 1.414;
    const deep = 3 + Math.floor(h(i, 0, 71 + seed) * 4);
    const bare = d >= deep || (d > 1 && h(x, y, 72 + seed) < 0.08 + d * 0.11);
    // fill = 이 칸은 **땅 타일**이다. 깎아 낸 자리는 밑에 물이 깔려 있지
    // 않으니 성기게 두면 잔디가 비친다 — 물 바탕부터 깔고 여울을 얹는다
    if (bare) { if (fill) g.px(x, y, baseWater(x, y)); return; }
    const lit = d === 0 ? 0 : (d < 3 ? 1 : 2);
    g.px(x, y, WATER[Math.round(lit + ((d < 2 ? 7 : 6) - lit) * shade)]);
    if (shade > 0.5) return;                                 // 그늘엔 바닥이 안 비친다
    if (d === 1 && h(x, y, 73 + seed) < 0.34) g.px(x, y, thru(EARTH[1], 0.3));
    if (d === 2 && h(x, y, 74 + seed) < 0.22) g.px(x, y, thru(STONE[3], 0.35));
    if (d === 3 && h(x, y, 75 + seed) < 0.18) g.px(x, y, thru(EARTH[2], 0.45));
    return;
  }
  const k = Math.floor(s);
  if (k < 2) { g.px(x, y, EARTH[5]); return; }               // 물에 닿는 젖은 자리
  // 벽 높이는 자리마다 한 칸씩 흔든다 — 자로 그은 마루는 담장이지 둑이 아니다.
  // 호를 따라 돌면서 서서히 낮아져 옆면으로 넘어간다
  const wall = Math.round((6 + (h(i, 0, 56 + seed) < 0.5 ? 0 : 1)) * clamp(nay, 0, 1));
  if (wall > 1) {
    const top = 2 + wall;
    if (k < top) {
      const st = h(Math.floor(i / 3), 0, 63 + seed);
      const up = (k - 2) / Math.max(1, wall - 1);
      let t = 6 - Math.round(up * 3.4) + (st < 0.35 ? 1 : (st > 0.72 ? -1 : 0));
      if ((i + Math.floor(k / 3)) % 3 === 0) t += 2;         // 돌 사이 틈
      g.px(x, y, STONE[clamp(t, 0, 7)]);
      return;
    }
    if (k === top) { g.px(x, y, STONE[0]); return; }         // 벽 마루 — 하늘을 본다
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
    const d = Math.floor(-s);
    const deep = 4 + Math.floor(h(i, 0, 76 + seed) * 4);
    if (d >= deep) { if (fill) g.px(x, y, baseWater(x, y)); return; }
    if (d === 0) { g.px(x, y, FOAM); return; }                // 밀려온 거품
    if (d === 1 && h(i, 0, 77 + seed) < 0.45) { g.px(x, y, FOAM); return; }
    // 얕아서 바닥이 훤히 비친다 — 깊어질수록 모래가 물빛에 잠긴다
    const mix = clamp(0.18 + d * 0.17, 0, 0.86);
    g.px(x, y, thru(SAND[clamp(d - 1, 0, 5)], mix));
    if (h(x, y, 78 + seed) < 0.16) g.px(x, y, thru(SAND[4], mix + 0.06));
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

const RC = 16;                     // 굽는 반지름 (논리 칸). 타일 한 변까지 굽는다

// 물가 한 장 — 이웃 넷 중 어디가 **딴 쪽**인지(mask)만 보고 그린다.
//   mask 비트  1=북 2=남 4=서 8=동
//   isLand     true면 땅 타일(그 방향이 물), false면 물 타일(그 방향이 뭍)
//
// 이 칸의 제 편(땅 타일이면 땅, 물 타일이면 물)을 **모서리 둥근 상자**로
// 본다. 딴 쪽이 있는 변만 상자의 변이 되고, 없는 변은 저 멀리 밀어 둔다.
// 그러면 열여섯 가지 이웃 꼴이 상자 하나로 다 나온다:
//
//   한 변      곧은 물가          두 변 맞은편  좁은 물목
//   두 변 이웃 볼록/오목 귀퉁이   세 변         곶      네 변  섬
//
// 물 타일은 **부호만 뒤집으면** 된다 — 물이 상자 안이니 뭍으로 가는 거리가
// 음수다. 볼록한 귀퉁이는 뭍이 깎여 물이 돌아 나가고, 오목한 귀퉁이는
// 뭍이 메워 들어간다. 같은 원의 안팎일 뿐이다.
function edgeTile(mask, isLand, paint) {
  const g = new T();
  const px = paint || bankPx;
  const FAR = 64;
  const x0 = (mask & 4) ? -0.5 : -FAR;
  const x1 = (mask & 8) ? N - 0.5 : N - 1 + FAR;
  const y0 = (mask & 1) ? -0.5 : -FAR;
  const y1 = (mask & 2) ? N - 0.5 : N - 1 + FAR;
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  const bx = (x1 - x0) / 2, by = (y1 - y0) / 2;
  const R = Math.min(RC, bx, by);                            // 상자보다 크게는 못 굽는다
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const ex = x - cx, ey = y - cy;
    const ax = Math.abs(ex) - (bx - R), ay = Math.abs(ey) - (by - R);
    let s, nx, ny;
    if (ax > 0 && ay > 0) {                                  // 귀퉁이 — 호를 돈다
      const d = Math.hypot(ax, ay) || 1e-4;
      s = R - d;
      nx = (ax / d) * Math.sign(ex);
      ny = (ay / d) * Math.sign(ey);
    } else {                                                 // 곧은 변 — 가까운 쪽
      const dx = bx - Math.abs(ex), dy = by - Math.abs(ey);
      if (dx <= dy) { s = dx; nx = Math.sign(ex); ny = 0; }
      else { s = dy; nx = 0; ny = Math.sign(ey); }
    }
    if (!isLand) { s = -s; nx = -nx; ny = -ny; }
    // 물가를 따라가는 자리 — 돌 이음매가 변을 따라 흐르게 한다
    const i = Math.round(x * Math.abs(ny) + y * Math.abs(nx));
    px(g, x, y, s, nx, ny, i, mask, isLand);
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
// water_<깊이>_<판>_<장> — 깊이 다섯 × 판 셋 × 장 둘
for (let lv = 0; lv < 5; lv++) for (let vr = 0; vr < 3; vr++) for (let f = 0; f < 2; f++)
  save(`water_${lv}_${vr}_${f}`, water(f, lv, vr).render());
for (let v = 0; v < 3; v++) save('sand_' + v, sandTile(v).render());
// 물가 — 이웃 꼴(mask) 열다섯 가지 × 네 종류.
//   shore 땅 타일 · shoal 물 타일      (연못·강 — 둑이 서고 벽이 진다)
//   beach 모래 타일 · surf 물 타일     (바다 — 모래가 그대로 기울어 든다)
for (let m = 1; m < 16; m++) {
  save('shore_m' + m, edgeTile(m, true).render());
  save('shoal_m' + m, edgeTile(m, false).render());
  save('beach_m' + m, edgeTile(m, true, beachPx).render());
  save('surf_m' + m, edgeTile(m, false, beachPx).render());
  save('dune_m' + m, edgeTile(m, true, spill(SAND, 84)).render());
  save('trod_m' + m, edgeTile(m, true, spill(EARTH, 96)).render());
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
