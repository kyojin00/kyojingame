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

// ---- 흙길 ----
// 다져진 흙 + 잔자갈 + 희미한 바퀴 자국
function pathTile() {
  const base = [150, 126, 96];
  const c = canvas(base);
  blockNoise(c, [[158, 134, 103], [142, 118, 88], [163, 139, 108]], 11, 0.72);
  // 다져진 결 (가로로 길게, 아주 옅게)
  for (let i = 0; i < 5; i++) {
    const y = Math.floor(h2(i * 7, 3, 21) * S);
    const len = 14 + Math.floor(h2(i, 9, 22) * 30);
    const x0 = Math.floor(h2(i, 5, 23) * S);
    for (let k = 0; k < len; k++) {
      const x = (x0 + k) % S;
      px(c, x, y, [138, 114, 85]);
      px(c, x, y + 1, [146, 122, 92]);
    }
  }
  // 잔자갈 (밝은 윗면 + 그림자)
  for (let i = 0; i < 16; i++) {
    const x = Math.floor(h2(i * 13, 1, 31) * S);
    const y = Math.floor(h2(i * 17, 2, 32) * S);
    const big = h2(i, 4, 33) > 0.65;
    const w = big ? 4 : 2, hh = big ? 3 : 2;
    rect(c, x, y, w, hh, [122, 116, 108]);
    rect(c, x, y, w, 1, [166, 160, 150]);
    rect(c, x, y + hh, w, 1, [110, 92, 70]);
  }
  // 흙 부스러기
  for (let i = 0; i < 26; i++) {
    const x = Math.floor(h2(i * 29, 6, 41) * S);
    const y = Math.floor(h2(i * 31, 7, 42) * S);
    rect(c, x, y, 2, 1, [134, 110, 82]);
  }
  return c;
}

// ---- 흙길 가장자리 ----
// 길과 풀이 만나는 자리에 덧그린다. 직선 경계를 톱니처럼 흐트러뜨린다.
function pathEdge(dir) {
  const c = Array.from({ length: S }, () => new Array(S).fill(null));
  for (let i = 0; i < S; i++) {
    const depth = Math.floor(2 + h2(i, dir * 3, 51) * 9);   // 들쭉날쭉한 깊이
    for (let d = 0; d < depth; d++) {
      const fade = d < depth - 3;                            // 끝자락은 성기게
      if (!fade && h2(i, d, 52) > 0.5) continue;
      const tone = h2(i, d, 53) > 0.5 ? [150, 126, 96] : [142, 118, 88];
      if (dir === 0) px(c, i, d, tone);                      // 위
      else if (dir === 1) px(c, i, S - 1 - d, tone);         // 아래
      else if (dir === 2) px(c, d, i, tone);                 // 왼쪽
      else px(c, S - 1 - d, i, tone);                        // 오른쪽
    }
  }
  return c;
}

// ---- 풀 ----
const SEASONS = {
  spring: { base: [86, 148, 76], tones: [[92, 156, 82], [80, 140, 70], [98, 162, 88]],
    blade: [64, 118, 56], tip: [124, 186, 104], flower: [[236, 232, 240], [244, 200, 216]] },
  summer: { base: [72, 140, 64], tones: [[78, 148, 70], [66, 130, 58], [86, 158, 76]],
    blade: [52, 106, 46], tip: [110, 178, 92], flower: [[248, 226, 120], [240, 168, 96]] },
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
console.log('지형 타일 생성 완료 (흙길 1 + 가장자리 4 + 풀 12 + 밭 2)');
