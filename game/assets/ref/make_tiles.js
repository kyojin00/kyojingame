// 지형 타일 생성기 — 64x64 (게임에서는 32px 칸에 그리므로 2배 해상도).
//
// 예전 타일은 「단색 + 점 몇 개」라 넓게 깔면 색종이처럼 보였다.
// 여기서는 세 가지를 지킨다:
//   1) 2x2 덩어리 노이즈 — 축소해서 봐도 결이 남는다 (1px 노이즈는 뭉개진다)
//   2) 이어붙여도 티가 안 난다 — 좌표를 64로 감아 쓰는 해시만 사용
//   3) 큰 무늬를 넣지 않는다 — 같은 타일이 반복되면 격자로 보이기 때문
//
// 실행:  node make_tiles.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const OUT = __dirname + '/../sprites/';
const S = 64;

// 좌표 기반 해시 (0~1). x,y를 S로 감아 써서 타일 경계가 이어진다.
function h2(x, y, seed) {
  x = ((x % S) + S) % S; y = ((y % S) + S) % S;
  // 32비트 안에서만 섞는다 — JS 정수 한계를 넘기면 값이 한쪽으로 몰린다
  let n = (Math.imul(x, 374761393) ^ Math.imul(y, 668265263) ^ Math.imul(seed, 362437)) >>> 0;
  n = Math.imul(n ^ (n >>> 13), 1274126177) >>> 0;
  n = (n ^ (n >>> 16)) >>> 0;
  return n / 4294967295;
}

const canvas = (col) => Array.from({ length: S }, () => new Array(S).fill(col));
const inb = (x, y) => x >= 0 && y >= 0 && x < S && y < S;
function px(c, x, y, col) { if (inb(x, y) && col) c[y][x] = col; }
function rect(c, x, y, w, hgt, col) {
  for (let j = 0; j < hgt; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col);
}
// 2x2 덩어리 노이즈: 축소해도 결이 남는다
function blockNoise(c, tones, seed, chance) {
  for (let y = 0; y < S; y += 2) for (let x = 0; x < S; x += 2) {
    const r = h2(x, y, seed);
    if (r > chance) continue;
    const col = tones[Math.floor(r * 997) % tones.length];
    rect(c, x, y, 2, 2, col);
  }
}

// ---- 돌길 (자갈 포석) ----
//
// 참고 도트의 마을 길은 「흙」이 아니라 둥글둥글한 포석을 깐 길이다.
// 돌 하나하나를 손으로 찍으면 이어붙일 때 티가 나므로, 씨앗점을 격자에
// 흔들어 뿌리고 보로노이로 나눠 돌을 만든다. 씨앗을 S로 감아 쓰기 때문에
// 타일 경계에서도 돌이 자연스럽게 이어진다.
const STONE_CELL = 16;                    // 씨앗 격자 (64 / 16 = 4 x 4 = 16개)
const STONE_TONES = [
  [168, 152, 124], [150, 136, 112], [180, 166, 138],
  [142, 132, 114], [160, 146, 118], [172, 158, 130],
];
const MORTAR = [118, 100, 76];            // 돌 사이 흙
const MORTAR_DARK = [98, 82, 62];

function stoneSeeds() {
  const seeds = [];
  const n = S / STONE_CELL;
  for (let gy = 0; gy < n; gy++) for (let gx = 0; gx < n; gx++) {
    seeds.push({
      x: gx * STONE_CELL + 3 + h2(gx * 13, gy * 7, 201) * (STONE_CELL - 6),
      y: gy * STONE_CELL + 3 + h2(gx * 17, gy * 11, 202) * (STONE_CELL - 6),
      tone: Math.floor(h2(gx, gy, 203) * STONE_TONES.length),
    });
  }
  return seeds;
}

// 감긴 거리 (타일 경계를 넘어가도 이어지게)
function wrapd(a, b) {
  let d = Math.abs(a - b);
  return d > S / 2 ? S - d : d;
}

function pathTile() {
  const c = canvas(MORTAR);
  blockNoise(c, [[126, 108, 82], [110, 94, 70], [134, 116, 88]], 11, 0.7);
  const seeds = stoneSeeds();
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    // 가장 가까운 씨앗 두 개 — 두 거리가 비슷하면 돌 사이 틈이다
    let b1 = 1e9, b2 = 1e9, best = null;
    for (const s of seeds) {
      const dx = wrapd(x + 0.5, s.x), dy = wrapd(y + 0.5, s.y);
      // 세로를 살짝 눌러 납작한 돌로 (위에서 비스듬히 본 느낌)
      const d = Math.sqrt(dx * dx + dy * dy * 1.35);
      if (d < b1) { b2 = b1; b1 = d; best = s; }
      else if (d < b2) b2 = d;
    }
    if (b2 - b1 < 2.2) continue;                       // 틈 = 흙 그대로
    const tone = STONE_TONES[best.tone];
    // 돌 하나 안에서 위는 밝게, 아래는 그늘 (둥글게 보이게)
    let dy = y + 0.5 - best.y;
    if (dy > S / 2) dy -= S; else if (dy < -S / 2) dy += S;
    let k = 0;
    if (dy < -2.5) k = 22;
    else if (dy > 3.0) k = -30;
    else if (dy > 1.5) k = -14;
    // 잔결
    const g = h2(x, y, 204) > 0.72 ? 8 : 0;
    px(c, x, y, [
      Math.max(0, Math.min(255, tone[0] + k + g)),
      Math.max(0, Math.min(255, tone[1] + k + g)),
      Math.max(0, Math.min(255, tone[2] + k + g)),
    ]);
    // 돌 테두리 바로 안쪽은 한 톤 어둡게 (돌끼리 붙어 보이지 않게)
    if (b2 - b1 < 3.1) px(c, x, y, [tone[0] - 34, tone[1] - 32, tone[2] - 28]);
  }
  // 틈에 낀 잔풀
  for (let i = 0; i < 10; i++) {
    const x = Math.floor(h2(i * 29, 6, 41) * S);
    const y = Math.floor(h2(i * 31, 7, 42) * S);
    if (c[y][x][0] > 150) continue;                    // 돌 위에는 안 난다
    px(c, x, y, [86, 128, 62]);
    px(c, x, y - 1, [104, 148, 74]);
  }
  return c;
}

// ---- 돌길 가장자리 ----
// 길과 풀이 만나는 자리에 덧그린다. 직선 경계를 톱니처럼 흐트러뜨리고,
// 끝자락에는 반쯤 묻힌 돌을 몇 개 흘려 놓는다.
function pathEdge(dir) {
  const c = Array.from({ length: S }, () => new Array(S).fill(null));
  const put = (i, d, col) => {
    if (dir === 0) px(c, i, d, col);                   // 위
    else if (dir === 1) px(c, i, S - 1 - d, col);      // 아래
    else if (dir === 2) px(c, d, i, col);              // 왼쪽
    else px(c, S - 1 - d, i, col);                     // 오른쪽
  };
  for (let i = 0; i < S; i++) {
    const depth = Math.floor(2 + h2(i, dir * 3, 51) * 9);   // 들쭉날쭉한 깊이
    for (let d = 0; d < depth; d++) {
      const fade = d < depth - 3;                           // 끝자락은 성기게
      if (!fade && h2(i, d, 52) > 0.5) continue;
      put(i, d, h2(i, d, 53) > 0.5 ? MORTAR : MORTAR_DARK);
    }
  }
  // 흩어진 포석 조각
  for (let k = 0; k < 5; k++) {
    const i = Math.floor(h2(k * 11, dir, 54) * S);
    const d = 2 + Math.floor(h2(k * 7, dir, 55) * 5);
    const tone = STONE_TONES[Math.floor(h2(k, dir, 56) * STONE_TONES.length)];
    for (let a = 0; a < 4; a++) for (let b = 0; b < 3; b++) {
      if (a === 0 && b === 0) continue;
      put((i + a) % S, d + b, b === 0
        ? [tone[0] + 16, tone[1] + 16, tone[2] + 16]
        : (b === 2 ? [tone[0] - 32, tone[1] - 30, tone[2] - 26] : tone));
    }
  }
  return c;
}

// ---- 물 ----
//
// 참고 도트의 호수는 「파란 판」이 아니라 잔물결이 층층이 겹친 면이다.
// 낮은 주파수 사인으로 깊이를 흔들어 바탕을 만들고, 그 위에 잔물결 선과
// 반짝임을 얹는다. 사인 주기를 64의 약수로 잡아야 이어붙여도 안 튄다.
const W_DEEP = [26, 84, 152], W_MID = [42, 112, 190], W_SHALLOW = [64, 146, 216];
const W_FOAM = [150, 208, 244], W_SPARK = [226, 244, 255];

function mix(a, b, t) {
  return [Math.round(a[0] + (b[0] - a[0]) * t),
    Math.round(a[1] + (b[1] - a[1]) * t),
    Math.round(a[2] + (b[2] - a[2]) * t)];
}

function waterTile(frame) {
  const ph = frame * Math.PI;                       // 프레임마다 물결을 반 주기 민다
  const c = canvas(W_MID);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const u = x / S * Math.PI * 2, v = y / S * Math.PI * 2;
    // 깊이 얼룩 (저주파 2개를 겹쳐 규칙적으로 안 보이게)
    const d = 0.5 + 0.28 * Math.sin(u + 0.7 * Math.sin(v))
      + 0.22 * Math.sin(2 * v + 1.9 + 0.6 * Math.sin(2 * u));
    c[y][x] = d < 0.42 ? mix(W_DEEP, W_MID, d / 0.42)
      : mix(W_MID, W_SHALLOW, Math.min(1, (d - 0.42) / 0.62));
  }
  blockNoise(c, [W_MID, mix(W_MID, W_DEEP, 0.35), mix(W_MID, W_SHALLOW, 0.35)], 141, 0.28);
  // 잔물결: 가로로 길고 얕은 호. 밑에 그림자를 깔아야 「면」으로 보인다.
  for (let i = 0; i < 15; i++) {
    const y0 = Math.floor(h2(i * 13, 1, 151) * S);
    const x0 = Math.floor((h2(i * 17, 2, 152) * S + frame * 5) % S);
    const len = 13 + Math.floor(h2(i, 3, 153) * 20);
    const bright = h2(i, 4, 154) > 0.55;
    for (let k = 0; k < len; k++) {
      const x = (x0 + k) % S;
      const bend = Math.round(1.2 * Math.sin(k / len * Math.PI + ph));
      const y = ((y0 + bend) % S + S) % S;
      px(c, x, y, bright ? W_FOAM : mix(W_SHALLOW, W_FOAM, 0.35));
      px(c, x, (y + 1) % S, mix(W_MID, W_DEEP, 0.55));
    }
  }
  // 반짝임
  for (let i = 0; i < 9; i++) {
    const x = Math.floor((h2(i * 23, 5, 161) * S + frame * 11) % S);
    const y = Math.floor((h2(i * 29, 6, 162) * S + frame * 7) % S);
    px(c, x, y, W_SPARK);
    if (h2(i, 7, 163) > 0.5) px(c, (x + 1) % S, y, W_FOAM);
  }
  return c;
}

// ---- 풀 ----
const SEASONS = {
  spring: { base: [96, 160, 72], tones: [[104, 170, 80], [86, 146, 64], [114, 182, 90]],
    blade: [64, 120, 50], tip: [146, 204, 110], flower: [[240, 240, 244], [244, 200, 216]] },
  summer: { base: [78, 146, 60], tones: [[86, 156, 68], [68, 132, 52], [96, 168, 78]],
    blade: [50, 108, 40], tip: [126, 192, 96], flower: [[248, 226, 120], [240, 168, 96]] },
  fall: { base: [140, 122, 66], tones: [[148, 130, 72], [130, 112, 60], [158, 138, 80]],
    blade: [112, 94, 50], tip: [176, 152, 92], flower: [[196, 104, 60], [212, 148, 66]] },
  winter: { base: [206, 214, 224], tones: [[214, 222, 232], [196, 205, 216], [224, 230, 238]],
    blade: [178, 190, 204], tip: [240, 246, 252], flower: [[240, 248, 255], [222, 234, 246]] },
};

// v = 0,1,2 (변형). 큰 무늬를 넣지 않아야 넓게 깔아도 격자로 안 보인다.
function grassTile(season, v) {
  const p = SEASONS[season];
  const c = canvas(p.base);
  blockNoise(c, p.tones, 61 + v * 7, 0.78);
  // 풀잎: 위로 뻗는 3~5px 선 몇 개
  const blades = [10, 14, 8][v];
  for (let i = 0; i < blades; i++) {
    const x = Math.floor(h2(i * 11 + v, 1, 71 + v) * S);
    const y = Math.floor(h2(i * 19 + v, 2, 72 + v) * S);
    const len = 3 + Math.floor(h2(i, 3, 73) * 3);
    const lean = h2(i, 4, 74) > 0.5 ? 1 : -1;
    for (let k = 0; k < len; k++) {
      px(c, x + (k > len - 2 ? lean : 0), y - k, p.blade);
    }
    px(c, x + lean, y - len, p.tip);
  }
  if (v === 2) {
    // 작은 꽃 세 송이 (계절 색)
    for (let i = 0; i < 3; i++) {
      const x = Math.floor(h2(i * 23, 5, 81) * (S - 4)) + 1;
      const y = Math.floor(h2(i * 29, 6, 82) * (S - 4)) + 1;
      const col = p.flower[i % p.flower.length];
      px(c, x, y - 1, col); px(c, x - 1, y, col); px(c, x + 1, y, col); px(c, x, y + 1, col);
      px(c, x, y, [250, 224, 140]);
    }
  }
  if (season === 'winter') {
    // 눈 반짝임
    for (let i = 0; i < 6; i++) {
      const x = Math.floor(h2(i * 37, 7, 91) * S);
      const y = Math.floor(h2(i * 41, 8, 92) * S);
      px(c, x, y, [255, 255, 255]); px(c, x + 1, y, [252, 254, 255]);
    }
  }
  return c;
}

// ---- 밭 ----
function soilTile(wet) {
  const base = wet ? [86, 62, 42] : [124, 92, 62];
  const c = canvas(base);
  blockNoise(c, wet
    ? [[92, 68, 46], [78, 56, 38], [98, 74, 50]]
    : [[132, 100, 68], [116, 86, 56], [140, 108, 74]], 101, 0.75);
  // 고랑: 16px마다 파인 줄 (위 그늘 + 아래 밝은 면)
  for (let y = 6; y < S; y += 16) {
    for (let x = 0; x < S; x++) {
      const wob = Math.floor(h2(x, y, 111) * 2);
      rect(c, x, y + wob, 1, 2, wet ? [62, 44, 30] : [96, 70, 46]);
      rect(c, x, y + wob + 2, 1, 1, wet ? [104, 78, 54] : [148, 116, 80]);
    }
  }
  // 흙덩이
  for (let i = 0; i < 18; i++) {
    const x = Math.floor(h2(i * 13, 1, 121) * S);
    const y = Math.floor(h2(i * 17, 2, 122) * S);
    rect(c, x, y, 2, 2, wet ? [72, 52, 36] : [110, 80, 52]);
    px(c, x, y, wet ? [104, 78, 54] : [146, 112, 76]);
  }
  if (wet) {
    // 젖은 광택 (푸르스름한 점)
    for (let i = 0; i < 10; i++) {
      const x = Math.floor(h2(i * 19, 3, 131) * S);
      const y = Math.floor(h2(i * 23, 4, 132) * S);
      rect(c, x, y, 2, 1, [118, 106, 96]);
    }
  }
  return c;
}

function save(name, c) {
  const p = new PNG({ width: S, height: S });
  p.data.fill(0);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const col = c[y][x];
    const i = (y * S + x) * 4;
    if (!col) { p.data[i + 3] = 0; continue; }
    p.data[i] = col[0]; p.data[i + 1] = col[1]; p.data[i + 2] = col[2]; p.data[i + 3] = 255;
  }
  fs.writeFileSync(OUT + name + '.png', PNG.sync.write(p));
}

save('path', pathTile());
['n', 's', 'w', 'e'].forEach((d, i) => save('path_edge_' + d, pathEdge(i)));
for (const season of Object.keys(SEASONS))
  for (let v = 0; v < 3; v++) save(`grass_${season}_${v}`, grassTile(season, v));
save('soil_dry', soilTile(false));
save('soil_wet', soilTile(true));
save('water_0', waterTile(0));
save('water_1', waterTile(1));
console.log('지형 타일 생성 완료 (돌길 1 + 가장자리 4 + 풀 12 + 밭 2 + 물 2)');
