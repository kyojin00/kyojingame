// 이사 주민 스프라이트 — 보라(rancher) 도트를 팔레트 스왑해서 만든다
// (사서 서하를 만든 make_librarian.js 와 같은 방식·같은 판정).
//   farmer    순돌 — 옷: 밀짚빛 카키 / 머리: 짙은 갈색
//   foodie    다미 — 옷: 감귤빛 주황 / 머리: 밤색
//   angler    강태 — 옷: 바닷빛 파랑 / 머리: 흑청색
//   alchemist 묘연 — 옷: 어스름 보라 / 머리: 잿빛 은발
// -- 마을회관(스토리 9) 확장 주민 7명 --
//   miner     바우 — 옷: 석탄빛 잿색 / 머리: 숯검정
//   florist   봄이 — 옷: 연분홍 / 머리: 밝은 갈색
//   carpenter 덕구 — 옷: 진갈색 작업복 / 머리: 흑갈색
//   herbalist 향이 — 옷: 풀빛 초록 / 머리: 녹갈색
//   painter   청람 — 옷: 청록 / 머리: 남빛
//   musician  한별 — 옷: 자주 와인 / 머리: 붉은 밤색
//   weaver    솜이 — 옷: 미색 아이보리 / 머리: 연한 밤색
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
  miner: {
    cloth: (r, g, b) => [Math.round(r * 0.34 + 24), Math.round(g * 0.36 + 24), Math.round(b * 0.42 + 26)],
    hair:  (r, g, b) => [Math.round(r * 0.22 + 6), Math.round(g * 0.22 + 6), Math.round(b * 0.24 + 8)],
  },
  florist: {
    cloth: (r, g, b) => [Math.min(255, Math.round(r * 0.98 + 40)), Math.round(g * 0.62 + 46), Math.round(b * 0.68 + 52)],
    hair:  (r, g, b) => [Math.min(255, Math.round(r * 0.78 + 34)), Math.round(g * 0.62 + 22), Math.round(b * 0.46 + 12)],
  },
  carpenter: {
    cloth: (r, g, b) => [Math.round(r * 0.52 + 14), Math.round(g * 0.42 + 10), Math.round(b * 0.32 + 6)],
    hair:  (r, g, b) => [Math.round(r * 0.34 + 4), Math.round(g * 0.28 + 4), Math.round(b * 0.24 + 4)],
  },
  herbalist: {
    cloth: (r, g, b) => [Math.round(r * 0.36 + 16), Math.round(g * 0.62 + 40), Math.round(b * 0.36 + 16)],
    hair:  (r, g, b) => [Math.round(r * 0.36 + 8), Math.round(g * 0.38 + 14), Math.round(b * 0.28 + 6)],
  },
  painter: {
    cloth: (r, g, b) => [Math.round(r * 0.26 + 12), Math.round(g * 0.56 + 40), Math.round(b * 0.58 + 48)],
    hair:  (r, g, b) => [Math.round(r * 0.22 + 8), Math.round(g * 0.28 + 12), Math.round(b * 0.52 + 34)],
  },
  musician: {
    cloth: (r, g, b) => [Math.round(r * 0.64 + 34), Math.round(g * 0.30 + 10), Math.round(b * 0.44 + 28)],
    hair:  (r, g, b) => [Math.round(r * 0.56 + 20), Math.round(g * 0.32 + 6), Math.round(b * 0.30 + 6)],
  },
  weaver: {
    cloth: (r, g, b) => [Math.min(255, Math.round(r * 0.86 + 62)), Math.min(255, Math.round(g * 0.84 + 58)), Math.round(b * 0.78 + 48)],
    hair:  (r, g, b) => [Math.round(r * 0.66 + 26), Math.round(g * 0.52 + 18), Math.round(b * 0.42 + 12)],
  },
  // -- 고장의 작은 마을 사람들 (폭포골 · 큰나무 숲) --
  // 교진 마을 사람들과 **같은 도트**에서 색만 갈아 낀다. 다른 고장이라고
  // 그림체까지 달라지면 다른 게임에서 걸어 들어온 사람이 된다.
  miller: {   // 수길 — 물방앗간. 밀가루 묻은 미색 앞치마 / 희끗한 머리
    cloth: (r, g, b) => [Math.min(255, Math.round(r * 0.88 + 58)), Math.min(255, Math.round(g * 0.88 + 56)), Math.min(255, Math.round(b * 0.86 + 60))],
    hair:  (r, g, b) => [Math.round(r * 0.62 + 60), Math.round(g * 0.62 + 58), Math.round(b * 0.62 + 56)],
  },
  dyer: {     // 윤슬 — 염색장이. 폭포 물빛 쪽빛 / 검푸른 머리
    cloth: (r, g, b) => [Math.round(r * 0.22 + 18), Math.round(g * 0.44 + 46), Math.min(255, Math.round(b * 0.72 + 96))],
    hair:  (r, g, b) => [Math.round(r * 0.20 + 6), Math.round(g * 0.26 + 12), Math.round(b * 0.40 + 30)],
  },
  brook: {    // 도담 — 폭포지기 아이. 물이끼 청록 / 밝은 밤색
    cloth: (r, g, b) => [Math.round(r * 0.30 + 20), Math.min(255, Math.round(g * 0.86 + 62)), Math.round(b * 0.62 + 52)],
    hair:  (r, g, b) => [Math.min(255, Math.round(r * 0.82 + 30)), Math.round(g * 0.58 + 20), Math.round(b * 0.40 + 10)],
  },
  sawyer: {   // 동백 — 나무꾼. 짙은 팥죽빛 작업복 / 검은 머리
    cloth: (r, g, b) => [Math.round(r * 0.58 + 26), Math.round(g * 0.26 + 12), Math.round(b * 0.26 + 14)],
    hair:  (r, g, b) => [Math.round(r * 0.20 + 6), Math.round(g * 0.18 + 6), Math.round(b * 0.18 + 8)],
  },
  beekeep: {  // 꿀비 — 벌치는 사람. 꿀빛 노랑 / 옅은 금갈색
    cloth: (r, g, b) => [Math.min(255, Math.round(r * 1.04 + 20)), Math.min(255, Math.round(g * 0.84 + 36)), Math.round(b * 0.24 + 8)],
    hair:  (r, g, b) => [Math.min(255, Math.round(r * 0.86 + 40)), Math.round(g * 0.72 + 30), Math.round(b * 0.42 + 10)],
  },
  teller: {   // 글샘 — 이야기꾼. 나무그늘 짙은 초록 / 잿빛 머리
    cloth: (r, g, b) => [Math.round(r * 0.30 + 14), Math.round(g * 0.60 + 30), Math.round(b * 0.34 + 20)],
    hair:  (r, g, b) => [Math.round(r * 0.48 + 40), Math.round(g * 0.48 + 42), Math.round(b * 0.48 + 44)],
  },
  // -- 사회(S2b) --
  officer_park: {   // 박 순경 — 교진 파출소. 제복 남색 / 짧은 검은 머리
    cloth: (r, g, b) => [Math.round(r * 0.18 + 12), Math.round(g * 0.26 + 22), Math.round(b * 0.52 + 58)],
    hair:  (r, g, b) => [Math.round(r * 0.18 + 4), Math.round(g * 0.18 + 6), Math.round(b * 0.20 + 10)],
    // 지금 걷기 도트의 웃옷은 보랏빛(168,120,196 계열)이라 mustard 판정에 안 걸린다 —
    // 제복은 그 보랏빛 계열을 통째로 남색으로 넘긴다 (다른 주민은 손대지 않는다)
    uniform: (r, g, b) => [Math.round(r * 0.30 + 10), Math.round(g * 0.38 + 20), Math.round(b * 0.42 + 50)],
  },
};
// ONLY=아이디 로 한 사람만 다시 뽑는다 — 나머지는 이미 sprites/ 에 있는 그대로 둔다
const ONLY = process.env.ONLY ? process.env.ONLY.split(',') : null;

for (const [nid, tf] of Object.entries(SETTLERS)) {
  if (ONLY && !ONLY.includes(nid)) continue;
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
      const purple = tf.uniform && b > r + 10 && b > g + 20 && r > 40;
      if (purple) {
        const c = tf.uniform(r, g, b);
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2];
      } else if (mustard) {
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
