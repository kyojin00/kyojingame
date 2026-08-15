// 메인 스토리 5 NPC 도트 — 기존 주민 도트에서 색만 바꿔 파생한다.
//
//   무진(explorer)     <- 무쇠(blacksmith)  : 초록 모험가 차림
//   연화(forest_mom)   <- 민지(merchant)    : 차분한 청록 옷
//   솔이(forest_girl)  <- 보라(rancher)     : 밝은 살구빛 옷
//
// 살빛(밝은 주황 계열)은 그대로 두고 옷·머리만 색상환을 돌린다.
// 유저가 진짜 그림을 주면 npc_<id>_*.png 같은 이름으로 얹으면 교체된다.
// 실행: repo 루트에서  NODE_PATH=... node game/assets/ref/make_forest_npcs.js
const fs = require('fs'), { PNG } = require('pngjs');
const DIR = __dirname + '/../sprites/';
const FRAMES = ['down_0', 'down_1', 'up_0', 'up_1', 'side_0', 'side_1',
  'portrait_normal', 'portrait_happy'];
const JOBS = [
  ['blacksmith', 'explorer', 130, 1.0, 1.02],
  ['merchant', 'forest_mom', 150, 0.82, 1.0],
  ['rancher', 'forest_girl', -75, 1.05, 1.08],
];

function rgb2hsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
  let h = 0, s = 0; const l = (mx + mn) / 2;
  if (mx !== mn) {
    const d = mx - mn;
    s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    if (mx === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    else if (mx === g) h = ((b - r) / d + 2) / 6;
    else h = ((r - g) / d + 4) / 6;
  }
  return [h, s, l];
}
function hsl2rgb(h, s, l) {
  h = ((h % 1) + 1) % 1;
  if (s === 0) { const v = Math.round(l * 255); return [v, v, v]; }
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
  const f = t => {
    t = ((t % 1) + 1) % 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };
  return [Math.round(f(h + 1 / 3) * 255), Math.round(f(h) * 255),
    Math.round(f(h - 1 / 3) * 255)];
}
// 살빛: 밝은 주황 (붉은 기 강하고 파랑이 낮다) — 색을 돌리지 않는다
function isSkin(r, g, b) {
  return r > 150 && g > 95 && b > 60 && r > g && g > b && (r - b) > 25 && (r - b) < 150;
}

for (const [src, dst, rot, satm, litm] of JOBS) {
  for (const f of FRAMES) {
    const im = PNG.sync.read(fs.readFileSync(DIR + `npc_${src}_${f}.png`));
    for (let i = 0; i < im.width * im.height; i++) {
      const k = i * 4;
      if (im.data[k + 3] === 0) continue;
      const [r, g, b] = [im.data[k], im.data[k + 1], im.data[k + 2]];
      if (isSkin(r, g, b)) continue;
      let [h, s, l] = rgb2hsl(r, g, b);
      if (s < 0.12) continue;               // 회색·검정(윤곽선)은 그대로
      h += rot / 360; s = Math.min(1, s * satm); l = Math.min(1, l * litm);
      const [nr, ng, nb] = hsl2rgb(h, s, l);
      im.data[k] = nr; im.data[k + 1] = ng; im.data[k + 2] = nb;
    }
    fs.writeFileSync(DIR + `npc_${dst}_${f}.png`, PNG.sync.write(im));
  }
  console.log(`npc_${dst}_* 8장 (from ${src})`);
}
