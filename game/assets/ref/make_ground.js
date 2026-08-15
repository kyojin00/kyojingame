// 바닥 생성기 — 잔디 · 자갈길 · 밭흙을 **캐릭터와 같은 도트 크기**로.
//
// 왜 다시 그리는가 —
//   지금 바닥은 전부 **한 픽셀씩 뿌린 잡음**이다. 64x64 안에 4096개 점을
//   확률로 찍어 놓은 것이라, 게임에서 0.5배로 줄면 사포처럼 자글거린다.
//   그 위에 도트가 굵은 사람과 건물이 서면 「사진 위에 스티커」로 보인다.
//
//   바닥도 도트 한 칸이 화면 2px이어야 한다:
//     16x16 논리 격자 -> 4배 -> 64x64 -> 게임에서 0.5배 -> 화면 32px
//     = 한 칸이 화면 2px. 캐릭터·건물과 정확히 같다.
//
// 그리고 **잡음이 아니라 물건**을 그린다:
//   잔디  포기(tuft)로 자란다. 잎 두세 장이 한 덩이, 밑동은 어둡다
//   길    자갈 한 알씩. 위는 빛을 받고 아래는 그늘, 사이는 회반죽
//   밭    쟁기가 지나간 이랑. 마루는 밝고 고랑은 어둡다
//
// 64x64 타일은 맵에 수백 번 반복된다. 그래서 모든 좌표를 16으로 **감아서**
// 찍는다 — 타일 끝에서 잘린 잎이 반대편에서 이어져야 이음매가 안 보인다.
//
// 실행:  node make_ground.js            -> ref/proposed_ground.png (한 장에 모아 보기)
//        node make_ground.js --install  -> sprites/ 에 실제로 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');

const N = 16;                    // 논리 격자 (한 변)
const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)
const F = N * S;                 // 64

// 좌표를 정수 해시로. 자리마다 늘 같은 값이 나와야 다시 뽑아도 그림이 안 바뀐다
function h(x, y, k) {
  let n = (x * 73856093) ^ (y * 19349663) ^ ((k | 0) * 83492791);
  n = (n ^ (n >> 13)) & 0x7FFFFFFF;
  return ((n * 1274126177) & 0x7FFFFFFF) / 2147483647.0;
}

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

const OUT = {};                  // 미리보기용으로 들고 있는다
const save = (name, im) => {
  OUT[name] = im;
  fs.writeFileSync((INSTALL ? SPR : REF + 'proposed_') + name + '.png', PNG.sync.write(im));
};


// ---- 잔디 ----
//
// 계절은 **색만** 바꾼다. 포기가 서는 자리와 모양은 그대로 둬야
// 계절이 바뀔 때 땅이 뒤집히지 않고 물만 든 것처럼 보인다.
// 톤 차이를 **좁게** 잡는다. 처음엔 밝은 잎과 어두운 밑동을 시원하게
// 벌렸더니, 32px 타일이 수백 번 반복되면서 그 대비가 그대로 **격자무늬**가
// 됐다 — 들판이 아니라 체크무늬 담요로 보였다.
// 바닥은 주인공이 서는 무대다. 무대가 튀면 배우가 안 보인다.
const SEASON = {
  spring: { base: [96, 152, 74], lite: [112, 170, 84], dark: [78, 132, 62],
            blade: [126, 186, 92], bloom: [[236, 226, 140], [238, 240, 232]] },
  summer: { base: [78, 140, 64], lite: [94, 160, 74], dark: [62, 118, 54],
            blade: [110, 178, 82], bloom: [[228, 148, 172], [150, 172, 226]] },
  fall:   { base: [144, 134, 74], lite: [164, 152, 86], dark: [120, 110, 60],
            blade: [178, 162, 94], bloom: [[196, 122, 56], [168, 82, 50]] },
  winter: { base: [208, 214, 224], lite: [226, 232, 242], dark: [188, 196, 210],
            blade: [172, 176, 164], bloom: [[230, 234, 242], [206, 212, 224]] },
};

function grass(season, variant) {
  const p = SEASON[season], g = new T();
  // ① 바탕 — 2x2 잔 얼룩 위에 4x4 큰 결. 처음엔 8x8로 잡았는데 16칸짜리
  //    타일에 8칸 덩어리는 사분면이 되어, 타일 경계가 그대로 드러났다.
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const v = h(x >> 2, y >> 2, variant) * 0.45
            + h(x >> 1, y >> 1, variant + 9) * 0.55;
    g.px(x, y, v < 0.30 ? p.dark : (v > 0.74 ? p.lite : p.base));
  }
  // ② 포기 — 잎 두세 장이 한 덩이로 선다. 이게 있어야 「풀」로 읽힌다.
  //    밑동에 어두운 점을 하나 찍는 게 핵심 — 잎이 땅에 꽂혀 보인다.
  //    다섯 포기면 충분하다. 많이 심을수록 타일이 「무늬」로 기억된다.
  const TUFT = 5;
  for (let i = 0; i < TUFT; i++) {
    const ox = Math.floor(h(i, variant, 1) * N);
    const oy = Math.floor(h(variant, i, 2) * N);
    g.px(ox, oy, p.dark);                                 // 밑동
    for (const [dx, hgt] of [[-1, 1], [0, 2], [1, 1]]) {
      if (h(i * 5 + dx, variant, 3) < 0.35) continue;      // 가끔 잎이 빠진다
      for (let k = 1; k <= hgt; k++) g.px(ox + dx, oy - k, k === hgt ? p.blade : p.lite);
    }
  }
  // ③ 꽃 — 세 장 중 한 장에만, 그것도 한 송이. 꽃은 **드물어야** 눈에 띈다
  if (variant === 1) {
    const ox = Math.floor(h(40, variant, 4) * N);
    const oy = Math.floor(h(variant, 40, 5) * N);
    const c = p.bloom[season === 'spring' ? 0 : 1];
    g.px(ox, oy, c); g.px(ox + 1, oy, c); g.px(ox, oy - 1, c);
    g.px(ox, oy + 1, p.dark);                             // 꽃대
  }
  return g;
}


// ---- 자갈길 ----
//
// 흙을 확률로 뿌려 놓은 길은 멀리서 보면 그냥 갈색 얼룩이다. **한 알씩**
// 그린 자갈은 크기와 방향이 있어서, 줄어들어도 길이 어디로 나 있는지 보인다.
//
// 4x4 한 알, 한 줄 걸러 반 알씩 밀어 깐다 (16이 4로 나뉘고 밀기가 2라
// 위아래·좌우가 저절로 맞물린다 — 이음매가 안 생긴다).
// 색은 **따뜻한 회색**이다. 순수한 회색으로 깔았더니 잔디 옆에서 아스팔트가
// 됐다 — 붉은 벽돌 건물과 초록 들판 사이에 놓이는 돌이라, 둘 다에서 조금씩
// 얻어와야 한 마을로 보인다.
const CB = {
  grout: [124, 106, 88],                                  // 회반죽 (자갈 사이)
  face: [[176, 162, 140], [186, 168, 142], [164, 154, 138], [180, 158, 130]],
  lite: [206, 196, 172], dark: [138, 124, 104],
};

// 알마다 **모양이 달라야** 한다. 3x3 둥근 알만 반복해서 깔았더니 길이
// 통째로 분홍빛 띠 하나가 됐다 — 자갈이 아니라 카펫이었다.
// 세 가지 모양을 섞고, 흙이 비치는 자리를 두면 밟고 다닌 길이 된다.
const DIRT = [138, 112, 82];
function cobble(seed) {
  const g = new T();
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++)
    g.px(x, y, h(x, y, seed + 31) < 0.18 ? DIRT : CB.grout);
  const W = 4, H = 4;
  for (let ry = 0; ry < N / H; ry++) {
    const shift = (ry % 2) ? W / 2 : 0;
    for (let rx = 0; rx < N / W; rx++) {
      const x0 = rx * W + shift, y0 = ry * H;
      const face = CB.face[Math.floor(h(rx, ry, seed) * CB.face.length)];
      const kind = h(rx, ry, seed + 1);
      if (kind < 0.18) {                                  // ① 작은 알 + 곁돌
        g.px(x0 + 1, y0, CB.lite);
        g.px(x0, y0 + 1, face); g.px(x0 + 1, y0 + 1, face);
        g.px(x0 + 1, y0 + 2, CB.dark);
        g.px(x0 + 3, y0 + 1, CB.dark);                    // 곁에 굴러 있는 조약돌
        continue;
      }
      const blocky = kind > 0.74;                         // ② 각진 알 (귀퉁이 안 깎음)
      for (let dy = 0; dy < 3; dy++) for (let dx = 0; dx < 3; dx++) {
        if (!blocky && (dx === 0 || dx === 2) && (dy === 0 || dy === 2)) continue;
        g.px(x0 + dx, y0 + dy, face);
      }
      g.px(x0 + 1, y0, CB.lite);                          // 윗면이 빛을 받는다
      if (blocky) g.px(x0, y0, CB.lite);
      g.px(x0 + 1, y0 + 2, CB.dark);                      // 밑면은 그늘
      g.px(x0 + 2, y0 + 2, CB.dark);
      if (h(rx, ry, seed + 3) < 0.45) g.px(x0, y0 + 1, CB.lite);
      if (h(rx, ry, seed + 7) < 0.22) g.px(x0 + 2, y0 + 1, CB.dark);   // ③ 금 간 알
    }
  }
  return g;
}


// 길 가장자리 — 풀밭 칸에 **길 쪽에서 흘러나온 자갈**을 얹는다.
// 직선으로 뚝 끊기면 종이를 오려 붙인 것처럼 보인다.
// dir: 0=위 1=아래 2=왼 3=오른 (길이 그쪽에 있다)
function cobbleEdge(dir) {
  const g = new T();
  for (let i = 0; i < N; i++) {
    // 안쪽으로 파고드는 깊이 — 자리마다 들쭉날쭉해야 톱니로 안 보인다.
    // 첫 두 줄은 **반드시** 깔아야 한다. 성기게 뿌렸더니 점선이 되어
    // 길과 풀 사이 경계가 오히려 더 또렷해졌다 (반대 효과)
    const deep = 2 + Math.floor(h(i, dir, 11) * 4);
    for (let k = 0; k < deep; k++) {
      if (k > 1 && h(i, k, dir + 20) < 0.42) continue;    // 깊이 들어갈수록 성기게
      const c = (k < 2) ? CB.face[Math.floor(h(i, k, dir) * CB.face.length)]
        : (h(i, k, dir + 5) < 0.45 ? DIRT : CB.grout);
      if (dir === 0) g.px(i, k, c);
      else if (dir === 1) g.px(i, N - 1 - k, c);
      else if (dir === 2) g.px(k, i, c);
      else g.px(N - 1 - k, i, c);
    }
    // 길 쪽 첫 줄에 그늘 — 자갈이 풀보다 살짝 낮게 깔린 것처럼 보인다
    const s = CB.dark;
    if (dir === 0) g.px(i, 0, h(i, 9, dir) < 0.35 ? s : g.get(i, 0));
    else if (dir === 1) g.px(i, N - 1, h(i, 9, dir) < 0.35 ? s : g.get(i, N - 1));
    else if (dir === 2) g.px(0, i, h(i, 9, dir) < 0.35 ? s : g.get(0, i));
    else g.px(N - 1, i, h(i, 9, dir) < 0.35 ? s : g.get(N - 1, i));
  }
  return g;
}


// ---- 밭흙 ----
//
// 쟁기가 지나간 자리는 **이랑**이 남는다. 마루(솟은 줄)는 빛을 받고
// 고랑(파인 줄)은 그늘진다. 이 두 줄만 있으면 흙이 갈려 있다고 읽힌다.
const SOIL = {
  dry: { base: [124, 88, 58], crest: [146, 108, 72], trough: [98, 68, 44],
         clod: [158, 122, 84] },
  wet: { base: [84, 58, 40], crest: [100, 72, 50], trough: [64, 44, 30],
         clod: [110, 82, 56] },
};

function soil(kind) {
  const p = SOIL[kind], g = new T();
  const k = kind === 'wet' ? 2 : 1;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const r = y % 4;                                      // 이랑 한 칸 = 4줄
    let c = p.base;
    // 마루·고랑을 **통줄로 그으면 널빤지**가 된다. 처음 뽑았을 때 밭이
    // 나무 데크로 보인 게 그래서였다. 한 칸 걸러 끊어 찍으면 같은 이랑인데
    // 흙덩이가 얹힌 두둑으로 읽힌다.
    if (r === 0 && (x + (y >> 2)) % 3 !== 2) c = p.crest;
    else if (r === 2 && (x + (y >> 2)) % 3 !== 0) c = p.trough;
    // 호미 자국 — 세로로도 한 번 긁고 지나간다 (격자로 갈린 밭)
    if (x % 4 === 1 && r !== 0) c = p.trough;
    const v = h(x >> 1, y >> 1, k);
    if (v > 0.88) c = p.clod;
    g.px(x, y, c);
  }
  return g;
}


// ---- 뽑기 ----
const made = [];
for (const s of Object.keys(SEASON))
  for (let v = 0; v < 3; v++) { save(`grass_${s}_${v}`, grass(s, v).render()); made.push(1); }
save('path', cobble(0).render());
['n', 's', 'w', 'e'].forEach((d, i) => save('path_edge_' + d, cobbleEdge(i).render()));
save('soil_dry', soil('dry').render());
save('soil_wet', soil('wet').render());

console.log(`바닥 ${12 + 1 + 4 + 2}장 — ${F}x${F} (논리 ${N}x${N} · 화면에서 도트 2px)`);
console.log(INSTALL ? '  sprites/ 에 넣었다'
  : '  ref/proposed_*.png 로만 뽑았다 (--install 을 붙이면 게임에 넣는다)');


// ---- 미리보기 ----
//
// 타일 한 장만 봐서는 아무것도 모른다. **게임에 그려지는 크기(0.5배)** 로
// 깔아 놓고, 그 위에 건물과 사람을 세워 봐야 같은 그림인지 알 수 있다.
const TILE = 32;                 // 화면 한 칸
const VW = 26, VH = 13;
const PW = VW * TILE, PH = VH * TILE;
const scene = new PNG({ width: PW, height: PH });
scene.data.fill(255);

// 0.5배로 얹기 (알파 0은 건너뛴다)
function blit(im, ox, oy, scale) {
  const st = 1 / scale;
  for (let y = 0; y < im.height * scale; y++) for (let x = 0; x < im.width * scale; x++) {
    const s = ((Math.floor(y * st)) * im.width + Math.floor(x * st)) * 4;
    if (im.data[s + 3] < 128) continue;
    const X = ox + x, Y = oy + y;
    if (X < 0 || Y < 0 || X >= PW || Y >= PH) continue;
    const d = (Y * PW + X) * 4;
    scene.data[d] = im.data[s]; scene.data[d + 1] = im.data[s + 1];
    scene.data[d + 2] = im.data[s + 2]; scene.data[d + 3] = 255;
  }
}

// 길은 가로로 한 줄, 문 앞으로 한 줄 올라온다 (게임의 마을 길과 같은 모양)
const DOOR_X = 12;
const isRoad = (x, y) => (y >= 9 && y <= 10) || (x >= DOOR_X && x <= DOOR_X + 1 && y >= 7);
for (let y = 0; y < VH; y++) for (let x = 0; x < VW; x++) {
  if (isRoad(x, y)) { blit(OUT['path'], x * TILE, y * TILE, 0.5); continue; }
  blit(OUT[`grass_spring_${Math.floor(h(x, y, 77) * 3)}`], x * TILE, y * TILE, 0.5);
  // 길에 닿는 칸에는 가장자리 자갈
  if (isRoad(x, y - 1)) blit(OUT['path_edge_n'], x * TILE, y * TILE, 0.5);
  if (isRoad(x, y + 1)) blit(OUT['path_edge_s'], x * TILE, y * TILE, 0.5);
  if (isRoad(x - 1, y)) blit(OUT['path_edge_w'], x * TILE, y * TILE, 0.5);
  if (isRoad(x + 1, y)) blit(OUT['path_edge_e'], x * TILE, y * TILE, 0.5);
}
for (let y = 3; y < 5; y++) for (let x = 20; x < 24; x++)       // 밭 한 뙈기
  blit(OUT[x < 22 ? 'soil_wet' : 'soil_dry'], x * TILE, y * TILE, 0.5);

const grab = f => { try { return PNG.sync.read(fs.readFileSync(f)); } catch (e) { return null; } };
const house = grab(REF + 'proposed_house.png') || grab(SPR + 'house.png');
const boy = grab(SPR + 'new_boy_down_idle.png');
if (house) blit(house, (DOOR_X - 3) * TILE, 1 * TILE - 6, 0.5);
if (boy) {
  blit(boy, (DOOR_X - 1) * TILE + 4, 8 * TILE - 24, 0.5);      // 문 앞
  blit(boy, 5 * TILE, 9 * TILE - 20, 0.5);                     // 길 위
}
fs.writeFileSync(REF + 'preview_ground.png', PNG.sync.write(scene));
console.log('preview_ground.png — 길·잔디·밭 위에 건물과 사람 (게임 크기 그대로)');
