// 이사 주민 4명 스프라이트 — 보라(rancher) 도트를 팔레트 스왑해서 만든다
// (사서 서하를 만든 make_librarian.js 와 같은 방식·같은 판정).
//   farmer    순돌 — 옷: 밀짚빛 카키 / 머리: 짙은 갈색
//   foodie    다미 — 옷: 감귤빛 주황 / 머리: 밤색
//   angler    강태 — 옷: 바닷빛 파랑 / 머리: 흑청색
//   alchemist 묘연 — 옷: 어스름 보라 / 머리: 잿빛 은발
// 피부·윤곽선은 그대로. 다시 뽑으려면 이 스크립트만 돌리면 된다.
const fs = require('fs'), { PNG } = require('pngjs');
const FRAMES = ['down_0', 'down_1', 'up_0', 'up_1', 'side_0', 'side_1',
  'portrait_normal', 'portrait_happy'];

// 옷(cr,cg,cb 계수·보정)과 머리 변환을 주민마다 달리 준다
const SETTLERS = {
  farmer: {
    cloth: (r, g, b) => [Math.round(r * 0.62 + 20), Math.round(g * 0.60 + 26), Math.round(b * 0.42 + 14)],
    hair:  (r, g, b) => [Math.round(r * 0.52), Math.round(g * 0.40 + 4), Math.round(b * 0.36 + 4)],
  },
  foodie: {
    cloth: (r, g, b) => [Math.min(255, Math.round(r * 1.02 + 26)), Math.round(g * 0.52 + 18), Math.round(b * 0.30 + 6)],
    hair:  (r, g, b) => [Math.round(r * 0.62 + 8), Math.round(g * 0.42 + 6), Math.round(b * 0.36 + 6)],
  },
  angler: {
    cloth: (r, g, b) => [Math.round(r * 0.24 + 10), Math.round(g * 0.48 + 30), Math.min(255, Math.round(b * 0.66 + 84))],
    hair:  (r, g, b) => [Math.round(r * 0.24), Math.round(g * 0.28 + 8), Math.round(b * 0.46 + 22)],
  },
  alchemist: {
    cloth: (r, g, b) => [Math.round(r * 0.52 + 26), Math.round(g * 0.34 + 12), Math.min(255, Math.round(b * 0.62 + 66))],
    hair:  (r, g, b) => [Math.round(r * 0.72 + 52), Math.round(g * 0.74 + 52), Math.round(b * 0.80 + 56)],
  },
};

for (const [nid, tf] of Object.entries(SETTLERS)) {
  for (const f of FRAMES) {
    const im = PNG.sync.read(fs.readFileSync(
      __dirname + `/../sprites/npc_rancher_${f}.png`));
    for (let i = 0; i < im.data.length; i += 4) {
      const r = im.data[i], g = im.data[i + 1], b = im.data[i + 2], a = im.data[i + 3];
      if (a === 0) continue;
      const skin = r > 185 && g > 130 && b > 95 && r >= g && g >= b - 10;
      if (skin) continue;
      const mustard = r > 130 && g > 95 && b < 130 && r > b + 45 && g > b + 20;
      const brown = !mustard && r > b + 18 && r >= g && r < 200 && g < 150;
      if (mustard) {
        const c = tf.cloth(r, g, b);
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2];
      } else if (brown) {
        const c = tf.hair(r, g, b);
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2];
      }
    }
    fs.writeFileSync(__dirname + `/../sprites/npc_${nid}_${f}.png`,
      PNG.sync.write(im));
  }
  console.log(`npc_${nid} 8장 완료`);
}
