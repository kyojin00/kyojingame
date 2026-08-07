// 도트 스프라이트 정의 및 렌더링 헬퍼
// 문자 -> 색상 팔레트. '.' 은 투명.

const PALETTE = {
  // 플레이어
  'H': '#6b4423', // 머리카락
  'F': '#f2c9a0', // 피부
  'E': '#3b2d24', // 눈
  'S': '#3d6fb5', // 셔츠
  'P': '#5a4634', // 바지
  'B': '#33241a', // 신발
  // 식물
  'g': '#5cb84e', // 밝은 잎
  'd': '#357a2e', // 어두운 잎
  'o': '#e8871e', // 주황 (당근/호박)
  'O': '#c96a10', // 진한 주황
  'r': '#d43d2a', // 빨강 (딸기)
  'y': '#ffd75e', // 노랑
  'b': '#8a5a2b', // 갈색 (감자)
  'w': '#f5f0e6', // 흰 꽃
  // 오브젝트
  't': '#5d4024', // 나무 기둥
  'T': '#43301c', // 기둥 음영
  'L': '#3e7d35', // 나뭇잎
  'l': '#57a54a', // 밝은 나뭇잎
  'k': '#8a8a94', // 돌
  'K': '#63636e', // 돌 음영
  'x': '#a67c4e', // 상자 나무
  'X': '#7d5a34', // 상자 음영
  'z': '#c9a56b', // 상자 밝은 면
};

const SPRITES = {
  playerDown0: [
    '...HHHHHH...',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HFFFFFFH..',
    '..FEFFFFEF..',
    '..FFFFFFFF..',
    '...FFFFFF...',
    '..SSSSSSSS..',
    '.FSSSSSSSSF.',
    '.FSSSSSSSSF.',
    '..SSSSSSSS..',
    '...PPPPPP...',
    '...PP..PP...',
    '...PP..PP...',
    '...BB..BB...',
    '..BBB..BBB..',
  ],
  playerDown1: [
    '...HHHHHH...',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HFFFFFFH..',
    '..FEFFFFEF..',
    '..FFFFFFFF..',
    '...FFFFFF...',
    '..SSSSSSSS..',
    '.FSSSSSSSSF.',
    '.FSSSSSSSSF.',
    '..SSSSSSSS..',
    '...PPPPPP...',
    '..PP....PP..',
    '..PP....PP..',
    '..BB....BB..',
    '.BBB....BBB.',
  ],
  playerUp0: [
    '...HHHHHH...',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '...HHHHHH...',
    '..SSSSSSSS..',
    '.FSSSSSSSSF.',
    '.FSSSSSSSSF.',
    '..SSSSSSSS..',
    '...PPPPPP...',
    '...PP..PP...',
    '...PP..PP...',
    '...BB..BB...',
    '..BBB..BBB..',
  ],
  playerUp1: [
    '...HHHHHH...',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '..HHHHHHHH..',
    '...HHHHHH...',
    '..SSSSSSSS..',
    '.FSSSSSSSSF.',
    '.FSSSSSSSSF.',
    '..SSSSSSSS..',
    '...PPPPPP...',
    '..PP....PP..',
    '..PP....PP..',
    '..BB....BB..',
    '.BBB....BBB.',
  ],
  playerSide0: [
    '....HHHHH...',
    '...HHHHHHH..',
    '...HHHHHHH..',
    '...HHFFFFF..',
    '...HFFEFFF..',
    '...HFFFFFF..',
    '....FFFFF...',
    '...SSSSSS...',
    '...SSSSSSF..',
    '...SSSSSSF..',
    '....SSSS....',
    '....PPPP....',
    '....PPPP....',
    '....PP.P....',
    '....BB.B....',
    '...BBB.BB...',
  ],
  playerSide1: [
    '....HHHHH...',
    '...HHHHHHH..',
    '...HHHHHHH..',
    '...HHFFFFF..',
    '...HFFEFFF..',
    '...HFFFFFF..',
    '....FFFFF...',
    '...SSSSSS...',
    '...SSSSSSF..',
    '...SSSSSSF..',
    '....SSSS....',
    '....PPPP....',
    '...PP..PP...',
    '...PP..PP...',
    '...BB..BB...',
    '..BBB..BBB..',
  ],

  // 작물 공통 성장 단계
  cropSprout: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.......g........',
    '.......g..g.....',
    '........gg......',
    '........g.......',
    '................',
    '................',
  ],
  cropSmall: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.....g..........',
    '.....g...g......',
    '..g...g.g..g....',
    '...g..gg..g.....',
    '....g.gg.g......',
    '.....dgggd......',
    '......dgd.......',
    '................',
    '................',
  ],
  cropMedium: [
    '................',
    '................',
    '................',
    '....g......g....',
    '.....g....g.....',
    '..g...g..g...g..',
    '...g..gggg..g...',
    '....gg.gg.gg....',
    '.....ggggggg....',
    '....gggddggg....',
    '.....dgggggd....',
    '......dgggd.....',
    '.......ddd......',
    '.......dgd......',
    '................',
    '................',
  ],
  // 다 자란 작물 (작물별)
  maturePotato: [
    '................',
    '................',
    '....g.....g.....',
    '...ggg...ggg....',
    '..ggdgg.ggdgg...',
    '...gggg.gggg....',
    '....dg...gd.....',
    '.....d...d......',
    '.....dd.dd......',
    '......ddd.......',
    '....bbb..bbb....',
    '...bbbbb.bbbb...',
    '...bbbbbbbbbb...',
    '....bbbbbbbb....',
    '................',
    '................',
  ],
  matureCarrot: [
    '................',
    '....g.....g.....',
    '...g.g...g.g....',
    '....ggg.ggg.....',
    '..g..ggggg..g...',
    '...gg.ggg.gg....',
    '.....ggggg......',
    '......ggg.......',
    '.....ooooo......',
    '.....ooooo......',
    '......oOo.......',
    '......oOo.......',
    '.......O........',
    '.......O........',
    '................',
    '................',
  ],
  matureStrawberry: [
    '................',
    '................',
    '................',
    '.....w....w.....',
    '....ggg..ggg....',
    '...ggdggggdgg...',
    '..gggggggggggg..',
    '..gg.r.gg.r.gg..',
    '...grrr..rrr....',
    '...grrr..rrrg...',
    '....rr....rr....',
    '..r.............',
    '.rrr....dgd.....',
    '..rr.....d......',
    '................',
    '................',
  ],
  maturePumpkin: [
    '................',
    '................',
    '................',
    '.......d........',
    '......dd........',
    '....OOOOOO......',
    '...OooooooO.....',
    '..OoooOooooO....',
    '..OooOooOooO....',
    '..OooOooOooO....',
    '..OooOooOooO....',
    '..OoooOooooO....',
    '...OooooooO.....',
    '....OOOOOO......',
    '................',
    '................',
  ],

  // 나무 (16x32, 아래 1타일이 발판)
  tree: [
    '.....LLLLL......',
    '...LLLLLLLLL....',
    '..LLllLLLLLLL...',
    '..LLlllLLLLLL...',
    '.LLLllLLLLlLLL..',
    '.LLLLLLLLllLLL..',
    '.LLLLLLLLLlLLL..',
    '..LLLLLLLLLLL...',
    '..LLlLLLLLLLL...',
    '...LLLLLLLLL....',
    '....LLLLLLL.....',
    '......ttT.......',
    '......ttT.......',
    '......ttT.......',
    '.....tttTT......',
    '....ttttTTT.....',
  ],
  rock: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '......kkkk......',
    '....kkkkkkkk....',
    '...kkkkkkkkkk...',
    '...kkkKKkkkkk...',
    '..kkkkKKkkkkkk..',
    '..kkkkkkkkKKkk..',
    '..kKKkkkkkKKkk..',
    '...kkkkkkkkkk...',
    '....KKKKKKKK....',
    '................',
    '................',
  ],
  bin: [
    '................',
    '................',
    '.zzzzzzzzzzzzz..',
    '.zxxxxxxxxxxxz..',
    '.zx.........xz..',
    '.zxxxxxxxxxxxz..',
    '.xXxxxxxxxxxXx..',
    '.xXxzzzzzzxxXx..',
    '.xXxxxxxxxxxXx..',
    '.xXxxxxxxxxxXx..',
    '.xXxzzzzzzxxXx..',
    '.xXxxxxxxxxxXx..',
    '.xXxxxxxxxxxXx..',
    '.XXXXXXXXXXXXX..',
    '................',
    '................',
  ],
};

// 스프라이트를 캔버스에 그린다. scale = 아트 1픽셀당 캔버스 픽셀 수
function drawSprite(ctx, rows, x, y, scale, flip) {
  for (let ry = 0; ry < rows.length; ry++) {
    const row = rows[ry];
    for (let rx = 0; rx < row.length; rx++) {
      const c = PALETTE[row[rx]];
      if (!c) continue;
      const px = flip ? (row.length - 1 - rx) : rx;
      ctx.fillStyle = c;
      ctx.fillRect(x + px * scale, y + ry * scale, scale, scale);
    }
  }
}

// 좌표 기반 결정적 의사난수 (타일 디테일용)
function tileHash(x, y) {
  let h = (x * 374761393 + y * 668265263) | 0;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return (h >>> 0) / 4294967295;
}
