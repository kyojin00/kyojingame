// 사서 서하 스프라이트 — 보라(rancher) 도트를 팔레트 스왑해서 만든다.
// 머리: 갈색 -> 먹빛(짙은 남흑색) / 옷: 겨자색 -> 짙은 초록 로브.
// 피부·윤곽선은 그대로. 다시 뽑으려면 이 스크립트만 돌리면 된다.
const fs = require('fs'), { PNG } = require('pngjs');
const FRAMES = ['down_0', 'down_1', 'up_0', 'up_1', 'side_0', 'side_1',
  'portrait_normal', 'portrait_happy'];
for (const f of FRAMES) {
  const im = PNG.sync.read(fs.readFileSync(
    __dirname + `/../sprites/npc_rancher_${f}.png`));
  for (let i = 0; i < im.data.length; i += 4) {
    const r = im.data[i], g = im.data[i+1], b = im.data[i+2], a = im.data[i+3];
    if (a === 0) continue;
    const skin = r > 185 && g > 130 && b > 95 && r >= g && g >= b - 10;
    if (skin) continue;
    const mustard = r > 130 && g > 95 && b < 130 && r > b + 45 && g > b + 20;
    const brown = !mustard && r > b + 18 && r >= g && r < 200 && g < 150;
    if (mustard) {           // 옷 -> 짙은 초록
      im.data[i]   = Math.round(r * 0.20);
      im.data[i+1] = Math.min(255, Math.round(g * 0.52 + 22));
      im.data[i+2] = Math.round(b * 0.30 + 24);
    } else if (brown) {      // 머리 -> 먹빛
      im.data[i]   = Math.round(r * 0.26);
      im.data[i+1] = Math.round(g * 0.28 + 6);
      im.data[i+2] = Math.round(b * 0.40 + 20);
    }
  }
  fs.writeFileSync(__dirname + `/../sprites/npc_librarian_${f}.png`,
    PNG.sync.write(im));
  console.log(`npc_librarian_${f}.png 완료`);
}
