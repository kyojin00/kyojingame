// 웹 프로토타입의 도트 데이터 -> Godot용 PNG 변환
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const REPO = '/home/user/kyojingame';
const OUT = path.join(REPO, 'game/assets/sprites');
fs.mkdirSync(OUT, { recursive: true });

const src = fs.readFileSync(path.join(REPO, 'web-prototype/js/sprites.js'), 'utf8');
const { SPRITES, PALETTE } = new Function(src + '; return {SPRITES, PALETTE};')();

// M3 추가 색상
Object.assign(PALETTE, {
  'u': '#6d3aa8', // 가지 보라
  'U': '#4e2a7a', // 가지 진보라
  'c': '#cfe3b4', // 배추 연두
  'C': '#a7c98a', // 배추 진연두
  'q': '#9a8a68', // 시든 줄기
  'Q': '#6e6248', // 시든 줄기 음영
  'a': '#e8a08c', // 볼터치
  'e': '#ddd3ba', // 크림 음영
});

// M3 신규 작물 + 시든 작물 도트
const EXTRA = {
  forage_berry: [
    '................',
    '................',
    '................',
    '....LLLL........',
    '...LLlLLL.......',
    '..LLrLLlLL......',
    '..LlLLrLLL......',
    '.LLrLLLLrLL.....',
    '.LLLLrLLLLL.....',
    '.LLlLLLlLLL.....',
    '..LLLrLLLL......',
    '...LLLLLL.......',
    '....tt..........',
    '....tt..........',
    '................',
    '................',
  ],
  forage_herb: [
    '................',
    '................',
    '................',
    '......g.........',
    '.....ggg........',
    '....gg.gg.......',
    '...gg.w.gg......',
    '...g.www.g......',
    '....g.w.g.......',
    '.....ggg........',
    '....g.g.g.......',
    '.....ggg........',
    '......d.........',
    '......d.........',
    '................',
    '................',
  ],
  bug_butterfly_0: [
    '........',
    '.rr..rr.',
    'rrrnnrrr',
    'rprnnprr',
    '.rrnnrr.',
    '..rnnr..',
    '...nn...',
    '........',
  ],
  bug_butterfly_1: [
    '........',
    '........',
    '.rr..rr.',
    'rrrnnrrr',
    '.rpnnpr.',
    '..rnnr..',
    '...nn...',
    '........',
  ],
  bug_dragonfly_0: [
    '........',
    'kk.nn.kk',
    '.kknnkk.',
    '..knnk..',
    '...nn...',
    '...nn...',
    '...n....',
    '........',
  ],
  bug_dragonfly_1: [
    '........',
    '........',
    'kk.nn.kk',
    '.kknnkk.',
    '...nn...',
    '...nn...',
    '...n....',
    '........',
  ],
  bug_firefly_0: [
    '........',
    '........',
    '...nn...',
    '..nyyn..',
    '..nyyn..',
    '...yy...',
    '....y...',
    '........',
  ],
  bug_firefly_1: [
    '........',
    '...nn...',
    '..nyyn..',
    '.nyyyyn.',
    '..nyyn..',
    '...yy...',
    '....y...',
    '........',
  ],
  treant_0: [
    '........................',
    '.......tt....tt.........',
    '......ttt...ttt.........',
    '....LLtttLLLtttLL.......',
    '...LLLttLLLLLttLLL......',
    '..LLlLLLLLlLLLLlLL......',
    '..LLLLLLLLLLLLLLLL......',
    '...LLLtttttttttLL.......',
    '.....tttttttttt.........',
    '....tttTTTTTTttt........',
    '....ttEETTTTEEtt........',
    '....ttEETTTTEEtt........',
    '....tttTTnnTTttt........',
    '....ttTTTnnTTTtt........',
    '...tttTTTTTTTTttt.......',
    '..tt.ttTTTTTTtt.tt......',
    '.tt..ttTTTTTTtt..tt.....',
    '.t...ttTTTTTTtt...t.....',
    '.....ttTT..TTtt.........',
    '.....ttTT..TTtt.........',
    '.....tttT..Tttt.........',
    '....tttt....tttt........',
    '....ttt......ttt........',
    '........................',
  ],
  treant_1: [
    '........................',
    '.......tt....tt.........',
    '......ttt...ttt.........',
    '....LLtttLLLtttLL.......',
    '...LLLttLLLLLttLLL......',
    '..LLlLLLLLlLLLLlLL......',
    '..LLLLLLLLLLLLLLLL......',
    '...LLLtttttttttLL.......',
    '.....tttttttttt.........',
    '...t.ttTTTTTTtt.t.......',
    '..tt.tEETTTTEEt.tt......',
    '.tt..tEETTTTEEt..tt.....',
    '.t...ttTTnnTTtt...t.....',
    '.....tTTTnnTTTt.........',
    '....ttTTTTTTTTtt........',
    '....ttTTTTTTTTtt........',
    '....ttTTTTTTTTtt........',
    '.....ttTTTTTTtt.........',
    '.....ttTT..TTtt.........',
    '.....ttTT..TTtt.........',
    '.....tttT..Tttt.........',
    '....tttt....tttt........',
    '....ttt......ttt........',
    '........................',
  ],
  barn: [
    '................................',
    '..........rrrrrrrrrrrr..........',
    '.......rrrrrrrrrrrrrrrrrr.......',
    '.....rrrrrrrrrrrrrrrrrrrrrr.....',
    '...rrrrrrrrrrrrrrrrrrrrrrrrrr...',
    '..RRRRRRRRRRRRRRRRRRRRRRRRRRRR..',
    '..xwwxxxxxxxxxxxxxxxxxxxxxwwx...',
    '..xwwxxxxxxxxxxxxxxxxxxxxxwwx...',
    '..xxxxxxxxxxxTTTTxxxxxxxxxxxx...',
    '..xxxxxxxxxxTTTTTTxxxxxxxxxxx...',
    '..xXxxxxxxxxTTttTTxxxxxxxxXxx...',
    '..xXxxxxxxxxTTttTTxxxxxxxxXxx...',
    '..xXxxxxxxxxTTttTTxxxxxxxxXxx...',
    '..xXxxxxxxxxTTttTTxxxxxxxxXxx...',
    '..xxxxxxxxxxTTttTTxxxxxxxxxxx...',
    '..XXXXXXXXXXTTttTTXXXXXXXXXXX...',
    '................................',
    '................................',
    '................................',
    '................................',
    '................................',
    '................................',
    '................................',
    '................................',
  ],
  icon_coin: [
    '..yyyy....',
    '.yyyyyy...',
    'yyOyyOyy..',
    'yyOyyOyy..',
    'yyOOOOyy..',
    'yyOyyOyy..',
    '.yyyyyy...',
    '..yyyy....',
    '..........',
    '..........',
  ],
  icon_heart: [
    '.rr..rr...',
    'rrrrrrrr..',
    'rrrrrrrr..',
    'rrrrrrrr..',
    '.rrrrrr...',
    '..rrrr....',
    '...rr.....',
    '..........',
    '..........',
    '..........',
  ],

  // ---- 펫 (16x16, 2프레임, 왼쪽 보기) ----
  pet_dog_0: [
    '................',
    '................',
    '................',
    '...XX...........',
    '...bbbX.........',
    '..bbEbb.........',
    '..bbbwb.....X...',
    '...bbbb....XX...',
    '...bbbbbbbbbX...',
    '...wbbbbbbbb....',
    '...wwbbbbbbb....',
    '....bb....bb....',
    '....bT....bT....',
    '................',
    '................',
    '................',
  ],
  pet_dog_1: [
    '................',
    '................',
    '................',
    '...XX.......X...',
    '...bbbX....X....',
    '..bbEbb.........',
    '..bbbwb.........',
    '...bbbb.....X...',
    '...bbbbbbbbbX...',
    '...wbbbbbbbb....',
    '...wwbbbbbbb....',
    '...bb......bb...',
    '...Tb......Tb...',
    '................',
    '................',
    '................',
  ],
  pet_cat_0: [
    '................',
    '................',
    '................',
    '...k.k..........',
    '...kkk..........',
    '..kEkk......K...',
    '...kkw......K...',
    '...kkkkkkkkK....',
    '...kKkkKkkk.....',
    '...kkkkkkkk.....',
    '....kk...kk.....',
    '....KK...KK.....',
    '................',
    '................',
    '................',
    '................',
  ],
  pet_cat_1: [
    '................',
    '................',
    '................',
    '...k.k......K...',
    '...kkk......K...',
    '..kEkk......K...',
    '...kkw.....K....',
    '...kkkkkkkkK....',
    '...kKkkKkkk.....',
    '...kkkkkkkk.....',
    '...kk.....kk....',
    '...KK.....KK....',
    '................',
    '................',
    '................',
    '................',
  ],
  pet_owl_0: [
    '................',
    '................',
    '................',
    '.....bbbb.......',
    '....bwwwwb......',
    '...bwEwwEwb.....',
    '...bwwyywwb.....',
    '....bwwwwb......',
    '...Tbbbbbbb.....',
    '...Tbbbbbbb.....',
    '...Tbbbbbb......',
    '....bbbbbb......',
    '.....o..o.......',
    '................',
    '................',
    '................',
  ],
  pet_owl_1: [
    '................',
    '................',
    '................',
    '.....bbbb.......',
    '....bwwwwb......',
    '...bwwwwwwb.....',
    '...bwEyyEwb.....',
    '....bwwwwb......',
    '..T.bbbbbbb.....',
    '..Tbbbbbbbb.....',
    '...Tbbbbbb......',
    '....bbbbbb......',
    '.....o..o.......',
    '................',
    '................',
    '................',
  ],
  pet_rabbit_0: [
    '................',
    '................',
    '...w..w.........',
    '...wF.wF........',
    '...w..w.........',
    '...ww.w.........',
    '...wwww.........',
    '..wEwww.........',
    '..wwwww.........',
    '...wwwwwwww.....',
    '...wwwwwwwww....',
    '...wwwwwwwww....',
    '....ww....ww....',
    '................',
    '................',
    '................',
  ],
  pet_rabbit_1: [
    '................',
    '................',
    '................',
    '...w..w.........',
    '...wF.wF........',
    '...w..w.........',
    '...ww.w.........',
    '...wwww.........',
    '..wEwww.........',
    '..wwwwwwwww.....',
    '...wwwwwwwww....',
    '...wwwwwwwww....',
    '...ww......ww...',
    '................',
    '................',
    '................',
  ],
  mature_tomato: [
    '................',
    '....g.....g.....',
    '...ggg...ggg....',
    '..g.ggg.ggg.g...',
    '...gggggggg.....',
    '..ggrr.gg.rr....',
    '..grrrr.rrrr....',
    '..grrrr.rrrr....',
    '...rrr...rrr....',
    '....r.....r.....',
    '.....g...g......',
    '......dgd.......',
    '.......d........',
    '.......d........',
    '................',
    '................',
  ],
  mature_corn: [
    '.......g........',
    '......gg.g......',
    '.....ggg.g......',
    '....g.gggg......',
    '.....gggg.......',
    '....yyOgg.......',
    '...yyyyOg.......',
    '...yyyyOg.......',
    '....yyOgg.......',
    '......ggg.......',
    '.....g.gg.......',
    '....g..gg..g....',
    '.......ggg......',
    '.......gg.......',
    '.......dd.......',
    '................',
  ],
  mature_watermelon: [
    '................',
    '................',
    '....g......g....',
    '..ggdg....g.....',
    '....gggggg......',
    '.....g..........',
    '....LLLLLL......',
    '...LlLLlLLL.....',
    '..LLdLLdLLLL....',
    '..LldLldLlLL....',
    '..LLdLLdLLLL....',
    '...LLlLLlLL.....',
    '....LLLLLL......',
    '................',
    '................',
    '................',
  ],
  mature_eggplant: [
    '................',
    '....g.....g.....',
    '...ggg...ggg....',
    '....gggggg......',
    '.....gggg.......',
    '....g.gg.g......',
    '....u..u........',
    '...uu..uu.......',
    '...uu..uu.......',
    '...uU..uU.......',
    '....U...U.......',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  mature_cabbage: [
    '................',
    '................',
    '................',
    '................',
    '....ccccc.......',
    '...ccCCCcc......',
    '..ccCggCccc.....',
    '..cCgggggCc.....',
    '..cCgggggCc.....',
    '..ccCgggCcc.....',
    '...ccCCCcc......',
    '....ccccc.......',
    '................',
    '................',
    '................',
    '................',
  ],
  mature_winter_radish: [
    '................',
    '....g.....g.....',
    '...g.g...g.g....',
    '....ggg.ggg.....',
    '.....ggggg......',
    '......ggg.......',
    '.....wwwww......',
    '.....wwwww......',
    '......www.......',
    '......www.......',
    '.......w........',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  fence: [
    '................',
    '....t.....t.....',
    '...ttt...ttt....',
    '...tTt...tTt....',
    '...tTt...tTt....',
    '..ttttttttttt...',
    '...tTt...tTt....',
    '...tTt...tTt....',
    '..ttttttttttt...',
    '...tTt...tTt....',
    '...tTt...tTt....',
    '...tTt...tTt....',
    '....T.....T.....',
    '................',
    '................',
    '................',
  ],
  sprinkler: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '......kKk.......',
    '.....kKKKk......',
    '.....KkkkK......',
    '.....KkkkK......',
    '......KKK.......',
    '.......K........',
    '......tKt.......',
    '.....ttttt......',
    '................',
    '................',
    '................',
  ],
  chicken_0: [
    '................',
    '................',
    '................',
    '................',
    '.....r..........',
    '....rwww........',
    '..owwEww........',
    '....wwwww.......',
    '...wwwwwwwE.....',
    '...wwwwwwwww....',
    '....wwwwwwww....',
    '.....wwwwww.....',
    '......w..w......',
    '......o..o......',
    '.....oo..oo.....',
    '................',
  ],
  chicken_1: [
    '................',
    '................',
    '................',
    '................',
    '.....r..........',
    '....rwww........',
    '..owwEww........',
    '....wwwww.......',
    '...wwwwwwwE.....',
    '...wwwwwwwww....',
    '....wwwwwwww....',
    '.....wwwwww.....',
    '.....w....w.....',
    '.....o....o.....',
    '....oo....oo....',
    '................',
  ],
  cow_0: [
    '................',
    '................',
    '................',
    '...EE...........',
    '..wwww.EEEE.....',
    '..wEwwwwwwwwww..',
    '..wwwwwwwwEEww..',
    '..FFwwwwwwEEww..',
    '..FFwEEwwwwwww..',
    '...wwEEwwwwww...',
    '...ww.wwwwFF....',
    '...ww..ww.ww....',
    '...TT..TT.TT....',
    '...TT..TT.TT....',
    '................',
    '................',
  ],
  cow_1: [
    '................',
    '................',
    '................',
    '...EE...........',
    '..wwww.EEEE.....',
    '..wEwwwwwwwwww..',
    '..wwwwwwwwEEww..',
    '..FFwwwwwwEEww..',
    '..FFwEEwwwwwww..',
    '...wwEEwwwwww...',
    '...ww.wwwwFF....',
    '..ww....ww..ww..',
    '..TT....TT..TT..',
    '..TT....TT..TT..',
    '................',
    '................',
  ],
  icon_hoe: [
    '................',
    '..........kkk...',
    '.........kkkk...',
    '........kkkk....',
    '.......ttkk.....',
    '......tt........',
    '.....tt.........',
    '....tt..........',
    '...tt...........',
    '..tt............',
    '.tt.............',
    '.tt.............',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_water: [
    '................',
    '................',
    '.....KKKK.......',
    '....K....K......',
    '............kk..',
    '...kkkkkkk.kk...',
    '..kkkkkkkkkk....',
    '..kkkkkkkkk.....',
    '..kKKkkkkkk.....',
    '..kKKkkkkkk.....',
    '..kkkkkkkkk.....',
    '...kkkkkkk......',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_seed: [
    '................',
    '................',
    '......tt........',
    '.....btbb.......',
    '....bbbbbb......',
    '...bbbbbbbb.....',
    '...bybbbbyb.....',
    '...bbbybbbb.....',
    '...bybbbyby.....',
    '...bbbybbbb.....',
    '....bbbbbb......',
    '.....bbbb.......',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_basket: [
    '................',
    '................',
    '................',
    '....r..o..r.....',
    '...rrrooorr.....',
    '..xxxxxxxxxx....',
    '..xXxXxXxXxx....',
    '...xxxxxxxx.....',
    '...xXxXxXxx.....',
    '....xxxxxx......',
    '....XXXXXX......',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_axe: [
    '................',
    '......kkk.......',
    '.....kkkkk......',
    '.....kkkkk......',
    '......kktt......',
    '.......tt.......',
    '......tt........',
    '.....tt.........',
    '....tt..........',
    '...tt...........',
    '..tt............',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_pickaxe: [
    '................',
    '....kk..........',
    '...kkkkkk.......',
    '....kkkkkkk.....',
    '......ttkkk.....',
    '.......tt.kk....',
    '......tt........',
    '.....tt.........',
    '....tt..........',
    '...tt...........',
    '..tt............',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_rod: [
    '................',
    '...........tt...',
    '..........tt....',
    '.........tt.....',
    '........tt.w....',
    '.......tt..w....',
    '......tt...w....',
    '.....tt....w....',
    '....tt....ww....',
    '...tt....wy.....',
    '..........y.....',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_wood: [
    '................',
    '................',
    '................',
    '....ttttttttz...',
    '...ztttttttzz...',
    '...zzttttttz....',
    '..ttttttttz.....',
    '.ztttttttzz.....',
    '.zztttttttz.....',
    '..ttttttttt.....',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  icon_stone: [
    '................',
    '................',
    '................',
    '................',
    '......kkk.......',
    '....kkkkkkk.....',
    '...kkkkKKkkk....',
    '..kkkkkKKkkkk...',
    '..kKKkkkkkkkk...',
    '...kkkkkkkkk....',
    '....KKKKKKK.....',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  slime_0: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '......gggg......',
    '....gggggggg....',
    '...gggggggggg...',
    '...ggEggggEgg...',
    '..gggggggggggg..',
    '..ggggggdggggg..',
    '..dggggggggggd..',
    '...dddddddddd...',
    '................',
    '................',
    '................',
  ],
  slime_1: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '.....gggggg.....',
    '...gggggggggg...',
    '..ggEggggggEgg..',
    '.gggggggggggggg.',
    '.ggggggddgggggg.',
    '.dgggggggggggdd.',
    '..dddddddddddd..',
    '................',
    '................',
  ],
  bat_0: [
    '................',
    '................',
    '................',
    '..E..........E..',
    '.EE..........EE.',
    '.EEE...EE...EEE.',
    '..EEEEEEEEEEEE..',
    '...EEErEErEEE...',
    '....EEEEEEEE....',
    '......EEEE......',
    '.......EE.......',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  bat_1: [
    '................',
    '................',
    '................',
    '................',
    '................',
    '.......EE.......',
    '..EE.EEEEEE.EE..',
    '.EEEEEErEErEEEE.',
    '..EEEEEEEEEEEE..',
    '....EEEEEEEE....',
    '......EEEE......',
    '................',
    '................',
    '................',
    '................',
    '................',
  ],
  ghost_0: [
    '................',
    '......wwww......',
    '....wwwwwwww....',
    '...wwwwwwwwww...',
    '...wEEwwwwEEw...',
    '..wwEEwwwwEEww..',
    '..wwwwwwwwwwww..',
    '..wwwwwwwwwwww..',
    '..wwwEEEEEwwww..',
    '..wwwwwwwwwwww..',
    '..wwwwwwwwwwww..',
    '..ww.www.www.w..',
    '................',
    '................',
    '................',
    '................',
  ],
  ghost_1: [
    '................',
    '......wwww......',
    '....wwwwwwww....',
    '...wwwwwwwwww...',
    '...wEEwwwwEEw...',
    '..wwEEwwwwEEww..',
    '..wwwwwwwwwwww..',
    '..wwwwwwwwwwww..',
    '..wwwEEEEEwwww..',
    '..wwwwwwwwwwww..',
    '..wwwwwwwwwwww..',
    '..w.www.www.ww..',
    '................',
    '................',
    '................',
    '................',
  ],
  ore_node: [
    '................',
    '................',
    '......v.........',
    '.....vVv........',
    '....kvvvkk......',
    '...kkkvkkkkk....',
    '..kkkkkkkkkkk...',
    '..kkVvvkkvVkk...',
    '..kkkvvkkvvkkk..',
    '..kkkkkkkkkkkk..',
    '...kkkkkkkkkk...',
    '....KKKKKKKK....',
    '................',
    '................',
    '................',
    '................',
  ],
  chest: [
    '................',
    '................',
    '................',
    '................',
    '...xxxxxxxxxx...',
    '..xzzzzzzzzzzx..',
    '..xzzzzzzzzzzx..',
    '..xxxxxxxxxxxx..',
    '..xXyyXXXXyyXx..',
    '..xXxxxyyxxxXx..',
    '..xXxxxxxxxxXx..',
    '..XXXXXXXXXXXX..',
    '................',
    '................',
    '................',
    '................',
  ],
  stairs: [
    '................',
    '.nnnnnnnnnnnnnn.',
    '.nEEEEEEEEEEEEn.',
    '.nEEEEEEEEEEEEn.',
    '.nEEkkkkkkkkEEn.',
    '.nEEkEEEEEEkEEn.',
    '.nEEkEkkkkEkEEn.',
    '.nEEkEkEEkEkEEn.',
    '.nEEkEkkkkEkEEn.',
    '.nEEkEEEEEEkEEn.',
    '.nEEkkkkkkkkEEn.',
    '.nnnnnnnnnnnnnn.',
    '................',
    '................',
    '................',
    '................',
  ],
  cave: [
    '....kkkkkkkk....',
    '..kkkkkkkkkkkk..',
    '.kkkkkkkkkkkkkk.',
    '.kkkKnnnnnnKkkk.',
    '.kkKnnnnnnnnKkk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '.kKnnnnnnnnnnKk.',
    '................',
  ],
  sign: [
    '................',
    '................',
    '................',
    '..tttttttttttt..',
    '..tzzzzzzzzzzt..',
    '..tzEzzEzEzzzt..',
    '..tzzzzzzzzzzt..',
    '..tttttttttttt..',
    '.......tt.......',
    '.......tt.......',
    '.......tt.......',
    '......tttt......',
    '................',
    '................',
    '................',
    '................',
  ],
  board: [
    '................',
    '...tttttttttt...',
    '..tzzzzzzzzzzt..',
    '..tzEzzEzzEzzt..',
    '..tzzzzzzzzzzt..',
    '..tzEzzEzzzzzt..',
    '..tzzzzzzzzzzt..',
    '..tttttttttttt..',
    '......tttt......',
    '......tTTt......',
    '......tTTt......',
    '......tTTt......',
    '.....ttTTtt.....',
    '................',
    '................',
    '................',
  ],
  withered: [
    '................',
    '................',
    '................',
    '....q......q....',
    '.....q....q.....',
    '..q...q..q..q...',
    '...q..qqq..q....',
    '....Q.qqq.Q.....',
    '.....qqqq.......',
    '......qq........',
    '......Qq........',
    '.......q........',
    '.......Q........',
    '................',
    '................',
    '................',
  ],
};

function hex(c) {
  return [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)];
}

function newImg(w, h) {
  const png = new PNG({ width: w, height: h });
  png.data.fill(0);
  return png;
}

function setPx(png, x, y, rgb, a = 255) {
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (png.width * y + x) << 2;
  png.data[i] = rgb[0]; png.data[i + 1] = rgb[1]; png.data[i + 2] = rgb[2]; png.data[i + 3] = a;
}

function fillRect(png, x, y, w, h, rgb) {
  for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) setPx(png, xx, yy, rgb);
}

const SAVED_NAMES = [];
function save(png, name) {
  SAVED_NAMES.push(name);
  fs.writeFileSync(path.join(OUT, name + '.png'), PNG.sync.write(png));
  console.log('wrote', name + '.png', png.width + 'x' + png.height);
}

function spriteToPng(rows, name, override) {
  const w = rows[0].length, h = rows.length;
  const png = newImg(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const ch = rows[y][x];
      const col = (override && override[ch]) || PALETTE[ch];
      if (col) setPx(png, x, y, hex(col));
    }
  }
  save(png, name);
}

// ---- 캐릭터/작물/오브젝트 (기존 도트 데이터 그대로) ----
const names = {
  cropSprout: 'crop_sprout', cropSmall: 'crop_small', cropMedium: 'crop_medium',
  maturePotato: 'mature_potato', matureCarrot: 'mature_carrot',
  matureStrawberry: 'mature_strawberry', maturePumpkin: 'mature_pumpkin',
  rock: 'rock', bin: 'bin',
};
for (const [key, name] of Object.entries(names)) spriteToPng(SPRITES[key], name);
for (const [name, rows] of Object.entries(EXTRA)) spriteToPng(rows, name);


// ---- 신규 대형 플레이어 (32x48, 시안 디테일 재현) ----
// 셔츠/조끼는 S/s (NPC 팔레트 스왑 호환). t: 허리끈/등끈, x: 주머니, y: 단추, a: 볼터치
const NEW_PLAYER = {
  down_0: [
    '..............nnn...............',
    '.............nHHn...............',
    '............nHHn................',
    '.........nnnHHHnnn..............',
    '.......nnHHHHHHHHHnn............',
    '......nHHHHHHHHHHHHHnn..........',
    '.....nHHhHHHHHHHHHhHHHn.........',
    '....nHHhhHHHHHHHHHhhHHHn........',
    '....nHHhHHHHHHHHHHHhHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHFFHHHFFFFFFHHHFFHn........',
    '...nHFFFHHFFFFFFFFHHFFFn........',
    '...nHFFFFFFFFFFFFFFFFFHn........',
    '..nHFFnEEnFFFFFFFFnEEnFHn.......',
    '..nHFFnEwEnFFFFFFnEwEnFHn.......',
    '..nHFFnEEEnFFFFFFnEEEnFHn.......',
    '..nHFFFnnnFFFFFFFFnnnFFHn.......',
    '...nFaaFFFFFFFFFFFFFaaFn........',
    '...nGFFFFFFFFnnFFFFFFFGn........',
    '....nGFFFFFFFFFFFFFFGn..........',
    '.....nnFFFFFFFFFFFFnn...........',
    '.......nwwwwwwwwwwn.............',
    '......nwwwnSSSSnwwwn............',
    '.....nwwwnSySSySnwwwn...........',
    '....nwwwwnSSSSSSnwwwwn..........',
    '...nwwwwsSSSSSSSSswwwwn.........',
    '...nwewwsSSSSSSSSswwewn.........',
    '...nwwnbsSSSSSSSSsbnwwn.........',
    '....nnbbsSSSSSSSSsbbnn..........',
    '....nbbbnSSSSSSSSnbbbn..........',
    '....nbbnttttttttttnbbn..........',
    '....nbbntTttttTttXxxbn..........',
    '.....nn.nsSSSSSSnxXxn...........',
    '........nsSSSSSSnxxn............',
    '.........nSSSSSSnnn.............',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPnnnnPPPPn...........',
    '.......nPPkPn..nPkPPn...........',
    '.......nPPPPn..nPPPPn...........',
    '.......nbbbbn..nbbbbn...........',
    '.......nbbbbn..nbbbbn...........',
    '.......nbbbbn..nbbbbn...........',
    '......nbBBBBn..nBBBBbn..........',
    '......nnnnnn....nnnnnn..........',
    '................................',
  ],
  down_1: [
    '..............nnn...............',
    '.............nHHn...............',
    '............nHHn................',
    '.........nnnHHHnnn..............',
    '.......nnHHHHHHHHHnn............',
    '......nHHHHHHHHHHHHHnn..........',
    '.....nHHhHHHHHHHHHhHHHn.........',
    '....nHHhhHHHHHHHHHhhHHHn........',
    '....nHHhHHHHHHHHHHHhHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHFFHHHFFFFFFHHHFFHn........',
    '...nHFFFHHFFFFFFFFHHFFFn........',
    '...nHFFFFFFFFFFFFFFFFFHn........',
    '..nHFFnEEnFFFFFFFFnEEnFHn.......',
    '..nHFFnEwEnFFFFFFnEwEnFHn.......',
    '..nHFFnEEEnFFFFFFnEEEnFHn.......',
    '..nHFFFnnnFFFFFFFFnnnFFHn.......',
    '...nFaaFFFFFFFFFFFFFaaFn........',
    '...nGFFFFFFFFnnFFFFFFFGn........',
    '....nGFFFFFFFFFFFFFFGn..........',
    '.....nnFFFFFFFFFFFFnn...........',
    '.......nwwwwwwwwwwn.............',
    '......nwwwnSSSSnwwwn............',
    '.....nwwwnSySSySnwwwn...........',
    '....nwwwwnSSSSSSnwwwwn..........',
    '...nwwwwsSSSSSSSSswwwwn.........',
    '...nwewwsSSSSSSSSswwewn.........',
    '...nwwnbsSSSSSSSSsbnwwn.........',
    '....nnbbsSSSSSSSSsbbnn..........',
    '....nbbbnSSSSSSSSnbbbn..........',
    '....nbbnttttttttttnbbn..........',
    '....nbbntTttttTttXxxbn..........',
    '.....nn.nsSSSSSSnxXxn...........',
    '........nsSSSSSSnxxn............',
    '.........nSSSSSSnnn.............',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPnnnnPPPPn...........',
    '......nPPkPn...nPkPPn...........',
    '......nPPPPn....nPPPPn..........',
    '......nbbbbn....nbbbbn..........',
    '.....nbbbbn......nbbbbn.........',
    '.....nbbbbn......nbbbbn.........',
    '....nbBBBn........nBBBbn........',
    '....nnnnn..........nnnnn........',
    '................................',
  ],
  up_0: [
    '..............nnn...............',
    '.............nHHn...............',
    '............nHHn................',
    '.........nnnHHHnnn..............',
    '.......nnHHHHHHHHHnn............',
    '......nHHHHHHHHHHHHHnn..........',
    '.....nHHhHHHHHHHHHhHHHn.........',
    '....nHHhhHHHHHHHHHhhHHHn........',
    '....nHHhHHHHHHHHHHHhHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHhHHHHHHHHHHHhHHHHn........',
    '..nHHHhHHHHHHHHHHHHhHHHn........',
    '..nHHHHHHHHHHHHHHHHHHHHn........',
    '..nHHHHHHHHHHHHHHHHHHHHn........',
    '..nHHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHn.........',
    '...nHHHHHHHHHHHHHHHHHHn.........',
    '....nHHHHHHHHHHHHHHHn...........',
    '.....nnHHHHHHHHHHnn.............',
    '.......nwwwwwwwwwwn.............',
    '......nwwwSsssSwwwwn............',
    '.....nwwwsSttSssSwwwn...........',
    '....nwwwwsStttSsSwwwwn..........',
    '...nwwwwsSSttttSSswwwwn.........',
    '...nwewwsSStttSSSswwewn.........',
    '...nwwnbsSSttttSSsbnwwn.........',
    '....nnbbsSSSSSSSSsbbnn..........',
    '....nbbbnSSSSSSSSnbbbn..........',
    '....nbbnttttttttttnbbn..........',
    '....nbbnttttttttttnbbn..........',
    '.....nn.nsSSSSSSns.nn...........',
    '........nsSSSSSSn...............',
    '.........nSSSSSSn...............',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPnnnnPPPPn...........',
    '.......nPPPPn..nPPPPn...........',
    '.......nPPPPn..nPPPPn...........',
    '.......nbbbbn..nbbbbn...........',
    '.......nbbbbn..nbbbbn...........',
    '.......nbbbbn..nbbbbn...........',
    '......nbBBBBn..nBBBBbn..........',
    '......nnnnnn....nnnnnn..........',
    '................................',
  ],
  up_1: [
    '..............nnn...............',
    '.............nHHn...............',
    '............nHHn................',
    '.........nnnHHHnnn..............',
    '.......nnHHHHHHHHHnn............',
    '......nHHHHHHHHHHHHHnn..........',
    '.....nHHhHHHHHHHHHhHHHn.........',
    '....nHHhhHHHHHHHHHhhHHHn........',
    '....nHHhHHHHHHHHHHHhHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHHn........',
    '...nHHhHHHHHHHHHHHhHHHHn........',
    '..nHHHhHHHHHHHHHHHHhHHHn........',
    '..nHHHHHHHHHHHHHHHHHHHHn........',
    '..nHHHHHHHHHHHHHHHHHHHHn........',
    '..nHHHHHHHHHHHHHHHHHHHHn........',
    '...nHHHHHHHHHHHHHHHHHHn.........',
    '...nHHHHHHHHHHHHHHHHHHn.........',
    '....nHHHHHHHHHHHHHHHn...........',
    '.....nnHHHHHHHHHHnn.............',
    '.......nwwwwwwwwwwn.............',
    '......nwwwSsssSwwwwn............',
    '.....nwwwsSttSssSwwwn...........',
    '....nwwwwsStttSsSwwwwn..........',
    '...nwwwwsSSttttSSswwwwn.........',
    '...nwewwsSStttSSSswwewn.........',
    '...nwwnbsSSttttSSsbnwwn.........',
    '....nnbbsSSSSSSSSsbbnn..........',
    '....nbbbnSSSSSSSSnbbbn..........',
    '....nbbnttttttttttnbbn..........',
    '....nbbnttttttttttnbbn..........',
    '.....nn.nsSSSSSSns.nn...........',
    '........nsSSSSSSn...............',
    '.........nSSSSSSn...............',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPPPPPPPPPn...........',
    '.......nPPPPnnnnPPPPn...........',
    '......nPPkPn...nPkPPn...........',
    '......nPPPPn....nPPPPn..........',
    '......nbbbbn....nbbbbn..........',
    '.....nbbbbn......nbbbbn.........',
    '.....nbbbbn......nbbbbn.........',
    '....nbBBBn........nBBBbn........',
    '....nnnnn..........nnnnn........',
    '................................',
  ],
  side_0: [
    '..............nnn...............',
    '.............nHHnn..............',
    '...........nnHHHn...............',
    '.........nnHHHHHnn..............',
    '........nHHHHHHHHHnn............',
    '.......nHHHHHHHHHHHHn...........',
    '......nHHhHHHHHHHHHHn...........',
    '......nHHhhHHHHHHHHHHn..........',
    '......nHHhHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHFFFFHn...........',
    '.....nHHHHHHHFFFFFFFn...........',
    '.....nHHHHHFFFFFFFFFn...........',
    '.....nHHHHFFnEEnFFFGn...........',
    '.....nHHHHFFnEwEnFFGn...........',
    '.....nHHHHFFnEEEnFFGn...........',
    '.....nHHHHFFFnnnFFGn............',
    '.....nHHHHFFFFFFaaGn............',
    '......nHHGFFFFFFFGn.............',
    '.......nHGFFFFFFGn..............',
    '........nnFFFFFnn...............',
    '.........nwwwwwwn...............',
    '........nwwSSSSwwn..............',
    '........nwsSySSswwn.............',
    '.......nwwsSSSSsswwn............',
    '.......nwwsSSSSSsswn............',
    '.......nwesSSSSSswen............',
    '.......nwnbsSSSSsnwn............',
    '........nnbbSSSSbnn.............',
    '........nbbnSSSSnbn.............',
    '........nbbtttttxxn.............',
    '........nbbttTttxXxn............',
    '.........nnsSSSSnxxn............',
    '..........nsSSSSnnn.............',
    '...........nSSSSn...............',
    '.........nPPPPPPPPn.............',
    '.........nPPPPPPPPn.............',
    '.........nPPPPPPPn..............',
    '.........nPPkPPPn...............',
    '.........nPPPPPPn...............',
    '.........nbbbbbn................',
    '.........nbbbbbn................',
    '.........nbbbbbn................',
    '........nbBBBBBn................',
    '........nnnnnnn.................',
    '................................',
  ],
  side_1: [
    '..............nnn...............',
    '.............nHHnn..............',
    '...........nnHHHn...............',
    '.........nnHHHHHnn..............',
    '........nHHHHHHHHHnn............',
    '.......nHHHHHHHHHHHHn...........',
    '......nHHhHHHHHHHHHHn...........',
    '......nHHhhHHHHHHHHHHn..........',
    '......nHHhHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHHHHHHHn..........',
    '.....nHHHHHHHHHFFFFHn...........',
    '.....nHHHHHHHFFFFFFFn...........',
    '.....nHHHHHFFFFFFFFFn...........',
    '.....nHHHHFFnEEnFFFGn...........',
    '.....nHHHHFFnEwEnFFGn...........',
    '.....nHHHHFFnEEEnFFGn...........',
    '.....nHHHHFFFnnnFFGn............',
    '.....nHHHHFFFFFFaaGn............',
    '......nHHGFFFFFFFGn.............',
    '.......nHGFFFFFFGn..............',
    '........nnFFFFFnn...............',
    '.........nwwwwwwn...............',
    '........nwwSSSSwwn..............',
    '........nwsSySSswwn.............',
    '.......nwwsSSSSsswwn............',
    '.......nwwsSSSSSsswn............',
    '.......nwesSSSSSswen............',
    '.......nwnbsSSSSsnwn............',
    '........nnbbSSSSbnn.............',
    '........nbbnSSSSnbn.............',
    '........nbbtttttxxn.............',
    '........nbbttTttxXxn............',
    '.........nnsSSSSnxxn............',
    '..........nsSSSSnnn.............',
    '...........nSSSSn...............',
    '.........nPPPPPPPPn.............',
    '........nPPPPnPPPPn.............',
    '........nPPPn.nPPPn.............',
    '.......nPPPn...nPPPn............',
    '.......nbbbn...nbbbn............',
    '.......nbbbn...nbbbn............',
    '......nbBBn.....nBBbn...........',
    '......nnnn.......nnnn...........',
    '................................',
    '........nnnnnnn.................',
    '................................',
  ],
};
const PLAYER_VEST = { S: '#6f7d3c', s: '#575f2e' };  // 플레이어 전용 올리브 조끼
// 플레이어 스프라이트는 사용자 원본 도트(128x192, game/assets/ref/)에서 변환한
// PNG를 직접 사용하므로 여기서 다시 생성하지 않는다 (NEW_PLAYER 데이터는 NPC 스왑용으로 유지).

// NPC (플레이어 도트의 팔레트 스왑: 머리/셔츠 색)
const NPCS = {
  // 상인 민지: 자주 머리, 분홍 옷 / 낚시꾼 철수: 금발, 초록 옷
  merchant: { H: '#4a3242', h: '#5d4053', S: '#b5486b', s: '#8f3652' },
  fisher: { H: '#caa04a', h: '#dbb669', S: '#3f7d4a', s: '#2f6139' },
  // 대장장이 무쇠: 검은 머리, 회색 작업복 / 목장주 보라: 갈색 머리, 노란 옷 /
  // 이장 덕수: 흰 머리, 남색 옷
  blacksmith: { H: '#2b2b30', h: '#3d3d44', S: '#6e6e78', s: '#54545c' },
  rancher: { H: '#7a4a2b', h: '#8f5c38', S: '#d9a53c', s: '#b2842c' },
  chief: { H: '#d8d8d2', h: '#e8e8e2', S: '#3a4a7d', s: '#2b3760' },
  // 우체부 아저씨: 회갈색 머리, 하늘색 제복
  postman: { H: '#6b5d4f', h: '#7d6e5e', S: '#4a7ab5', s: '#37619c' },
};
const PLAYER_FRAMES = {
  down_0: 'playerDown0', down_1: 'playerDown1',
  up_0: 'playerUp0', up_1: 'playerUp1',
  side_0: 'playerSide0', side_1: 'playerSide1',
};
for (const [npc, colors] of Object.entries(NPCS)) {
  for (const frame of Object.keys(NEW_PLAYER)) {
    spriteToPng(NEW_PLAYER[frame], `npc_${npc}_${frame}`, colors);
  }
}

// NPC 초상화 32x32 (표정 2종, 팔레트 스왑 공유)
Object.assign(PALETTE, { 'p': '#e8a2a2', 'v': '#59d6d0', 'V': '#2f9e99' }); // 홍조
const PORTRAITS = {
  normal: [
    '..........nnnnnnnnnnnn..........',
    '........nnHHHHHHHHHHHHnn........',
    '......nnHHHHHHHHHHHHHHHHnn......',
    '.....nHHHHHHHHHHHHHHHHHHHHn.....',
    '....nHHHhhHHHHHHHHHHHHhhHHn.....',
    '....nHHHHHHHHHHHHHHHHHHHHHn.....',
    '...nHHHHHHHHHHHHHHHHHHHHHHHHn...',
    '...nHHHFFFHHFFFFFFFFHHFFFHHHn...',
    '...nHFFFFFFFFFFFFFFFFFFFFFFHn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '...nFFFHHHHFFFFFFFFFHHHHFFFFn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '...nFFFnEEwFFFFFFFFwEEnFFFFFn...',
    '...nFFFnEEnFFFFFFFFnEEnFFFFFn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '...nFFFFFFFFFFFGGFFFFFFFFFFFn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '...nFFFFFFFFFGGGGGGFFFFFFFFFn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '....nFFFFFFFFFFFFFFFFFFFFFFn....',
    '.....nFFFFFFFFFFFFFFFFFFFFn.....',
    '......nnFFFFFFFFFFFFFFFFnn......',
    '........nnFFFFFFFFFFFFnn........',
    '...........nFFFFFFFFn...........',
    '..........nFFFFFFFFFFn..........',
    '.......nnSSSSnFFFFnSSSSnn.......',
    '.....nSSSSSSSSSSSSSSSSSSSSn.....',
    '....nSSSSSSSSSSSSSSSSSSSSSSn....',
    '...nSSSSSSSSSSSSSSSSSSSSSSSSn...',
    '...nssSSSSSSSSSSSSSSSSSSSSssn...',
    '...nssSSSSSSSSSSSSSSSSSSSSssn...',
    '...nnnnnnnnnnnnnnnnnnnnnnnnnn...',
  ],
  happy: [
    '..........nnnnnnnnnnnn..........',
    '........nnHHHHHHHHHHHHnn........',
    '......nnHHHHHHHHHHHHHHHHnn......',
    '.....nHHHHHHHHHHHHHHHHHHHHn.....',
    '....nHHHhhHHHHHHHHHHHHhhHHn.....',
    '....nHHHHHHHHHHHHHHHHHHHHHn.....',
    '...nHHHHHHHHHHHHHHHHHHHHHHHHn...',
    '...nHHHFFFHHFFFFFFFFHHFFFHHHn...',
    '...nHFFFFFFFFFFFFFFFFFFFFFFHn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '...nFFFHHHHFFFFFFFFFHHHHFFFFn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '...nFFnEEnFFFFFFFFFFnEEnFFFFn...',
    '...nFnnFFnnFFFFFFFFnnFFnnFFFn...',
    '...nFFFFFFFFFFFFFFFFFFFFFFFFn...',
    '...nFFFFFFFFFFFGGFFFFFFFFFFFn...',
    '...nFppFFFFFFFFFFFFFFFFFppFFn...',
    '...nFppFFFFFnrrrrrrnFFFFFppFn...',
    '...nFFFFFFFFFnnnnnnFFFFFFFFFn...',
    '....nFFFFFFFFFFFFFFFFFFFFFFn....',
    '.....nFFFFFFFFFFFFFFFFFFFFn.....',
    '......nnFFFFFFFFFFFFFFFFnn......',
    '........nnFFFFFFFFFFFFnn........',
    '...........nFFFFFFFFn...........',
    '..........nFFFFFFFFFFn..........',
    '.......nnSSSSnFFFFnSSSSnn.......',
    '.....nSSSSSSSSSSSSSSSSSSSSn.....',
    '....nSSSSSSSSSSSSSSSSSSSSSSn....',
    '...nSSSSSSSSSSSSSSSSSSSSSSSSn...',
    '...nssSSSSSSSSSSSSSSSSSSSSssn...',
    '...nssSSSSSSSSSSSSSSSSSSSSssn...',
    '...nnnnnnnnnnnnnnnnnnnnnnnnnn...',
  ],
};
for (const [npc, colors] of Object.entries(NPCS)) {
  for (const [expr, rows] of Object.entries(PORTRAITS)) {
    spriteToPng(rows, `npc_${npc}_portrait_${expr}`, colors);
  }
}

// 계절별 나무 (잎 색 교체)
const TREE_LEAVES = {
  spring: { L: '#4f7c39', l: '#6b9a4e' },
  summer: { L: '#43703a', l: '#5b8a49' },
  fall:   { L: '#b05a26', l: '#d07f35' },
  winter: { L: '#dfe6ef', l: '#f2f6fa' },
};
for (const [season, colors] of Object.entries(TREE_LEAVES)) {
  spriteToPng(SPRITES.tree, 'tree_' + season, colors);
}

// ---- 지형 타일 (웹 버전 색상 + 디테일을 텍스처로 굽기) ----
function hash(x, y) {
  let h = (x * 374761393 + y * 668265263) | 0;
  h = ((h ^ (h >> 13)) * 1274126177) | 0;
  h = h ^ (h >> 16);
  return (h >>> 0) / 4294967295;
}

// 계절별 잔디 3종 (겨울은 눈밭)
const GRASS_SETS = {
  spring: { bases: ['#7da35a', '#769c54', '#83aa60'], detail: '#5f8443', lite: '#8fb56a', flower: '#e8e0f0' },
  summer: { bases: ['#6a9a4c', '#639347', '#71a152'], detail: '#4f7c39', lite: '#7cab58', flower: '#f0d878' },
  fall:   { bases: ['#b5904e', '#ad8848', '#bb9854'], detail: '#8f6f3a', lite: '#c7a25e', flower: '#c9703a' },
  winter: { bases: ['#e8ecf2', '#e2e6ee', '#edf1f6'], detail: '#c9d2e0', lite: '#f6f9fc', flower: '#dfe8f2' },
};
for (const [season, set] of Object.entries(GRASS_SETS)) {
  set.bases.forEach((base, i) => {
    const png = newImg(64, 64);
    fillRect(png, 0, 0, 64, 64, hex(base));
    // 은은한 톤 얼룩 (땅의 밝기 변화)
    for (let k = 0; k < 10; k++) {
      const x = Math.floor(hash(i * 41 + k, k * 29 + 3) * 58);
      const y = Math.floor(hash(k * 37 + 5, i * 43 + k) * 58);
      const w = 4 + Math.floor(hash(x, k) * 6), h = 3 + Math.floor(hash(k, y) * 4);
      if (hash(x + 1, y + 1) < 0.5) fillRect(png, x, y, w, h, hex(set.bases[(i + 1) % 3]));
    }
    // 풀잎 다발 (뿌리 2톤 + 밝은 끝, 3~5px)
    for (let k = 0; k < 30; k++) {
      const x = Math.floor(hash(i * 31 + k, k * 7 + 1) * 61) + 1;
      const y = Math.floor(hash(k * 13 + 2, i * 17 + k) * 56) + 4;
      const tall = 3 + Math.floor(hash(x, y + k) * 3);
      for (let t = 0; t < tall; t++) setPx(png, x, y + t, hex(set.detail));
      setPx(png, x, y, hex(set.lite));
      if (hash(x, y) < 0.6) {
        for (let t = 1; t < tall; t++) setPx(png, x + 1, y + t, hex(set.detail));
        setPx(png, x + 1, y + Math.max(1, tall - 3), hex(set.lite));
      }
    }
    // 어두운 점 (흙 틈)
    for (let k = 0; k < 14; k++) {
      const x = Math.floor(hash(k * 19 + i, k * 3 + 7) * 64);
      const y = Math.floor(hash(k * 5 + 11, k * 23 + i) * 64);
      setPx(png, x, y, hex(set.detail));
    }
    // 들꽃 (꽃잎 4장 + 중심)
    if (i === 2) {
      [[14 + Math.floor(hash(i, 99) * 20), 14 + Math.floor(hash(99, i) * 20)],
       [34 + Math.floor(hash(i, 55) * 16), 36 + Math.floor(hash(55, i) * 16)]].forEach(([fx, fy]) => {
        setPx(png, fx, fy - 1, hex(set.flower)); setPx(png, fx, fy + 1, hex(set.flower));
        setPx(png, fx - 1, fy, hex(set.flower)); setPx(png, fx + 1, fy, hex(set.flower));
        setPx(png, fx, fy, hex('#f5e28a'));
      });
    }
    save(png, 'grass_' + season + '_' + i);
  });
}

// 밭 (마른/젖은): 흙덩이 알갱이 + 고랑 2줄 + 하이라이트
[['soil_dry', '#8a6a42', '#80613c', '#755835', '#97764c'],
 ['soil_wet', '#5a4028', '#513a24', '#48331f', '#66492e']]
  .forEach(([name, a, b, line, hi]) => {
    const png = newImg(64, 64);
    fillRect(png, 0, 0, 64, 64, hex(a));
    // 흙덩이 알갱이 (2x1~2x2 덩어리 + 하이라이트)
    for (let k = 0; k < 110; k++) {
      const x = Math.floor(hash(k * 5, k + 3) * 63);
      const y = Math.floor(hash(k + 9, k * 3) * 63);
      setPx(png, x, y, hex(b));
      if (hash(k, x) < 0.5) setPx(png, x + 1, y, hex(b));
      if (hash(k, y) < 0.3) setPx(png, x + 1, y + 1, hex(b));
      if (hash(k, x) < 0.35) setPx(png, x, y - 1, hex(hi));
    }
    // 밭고랑 2줄 (2px 골 + 아래 밝은 모서리)
    [20, 44].forEach((gy) => {
      fillRect(png, 0, gy, 64, 2, hex(line));
      fillRect(png, 0, gy + 2, 64, 1, hex(hi));
    });
    save(png, name);
  });

// 길: 자갈 몇 개 + 모래알
{
  const png = newImg(64, 64);
  fillRect(png, 0, 0, 64, 64, hex('#c2a878'));
  // 모래알
  for (let k = 0; k < 70; k++) {
    const x = Math.floor(hash(k * 3 + 1, k * 7 + 2) * 63);
    const y = Math.floor(hash(k * 11 + 5, k * 5 + 3) * 64);
    setPx(png, x, y, hex('#b09668'));
    if (hash(k, x) < 0.5) setPx(png, x + 1, y, hex('#b09668'));
  }
  // 자갈 (3~4px 돌: 밝은 윗면 + 그림자)
  [[9, 44, 4], [42, 15, 3], [26, 30, 4], [52, 52, 3], [14, 10, 3], [50, 34, 4], [30, 55, 3]]
    .forEach(([x, y, s]) => {
      fillRect(png, x, y, s, s - 1, hex('#d8c298'));
      fillRect(png, x, y, s - 1, 1, hex('#e8d4ac'));
      fillRect(png, x, y + s - 1, s, 1, hex('#8f7a52'));
    });
  save(png, 'path');
}

// 물 2종: 물결 곡선 + 반짝임
[0, 1].forEach((i) => {
  const png = newImg(64, 64);
  fillRect(png, 0, 0, 64, 64, hex(i ? '#356598' : '#3b6ea5'));
  fillRect(png, 0, 0, 64, 3, hex(i ? '#3b6ea5' : '#356598'));
  const wave = hex('#5b8cc0'), deep = hex('#2f5a88');
  // 물결 4가닥 (끝이 처지는 곡선)
  [[10 + i * 12, 16, 14], [34 - i * 10, 34, 12], [44 + i * 6, 50, 12], [6 - i * 4, 56, 10]]
    .forEach(([x, y, w]) => {
      fillRect(png, x, y, w, 1, wave);
      setPx(png, x - 1, y + 1, wave); setPx(png, x + w, y + 1, wave);
      fillRect(png, x + 2, y + 2, w - 4, 1, deep);
    });
  // 반짝임
  [[52, 10 + i * 6], [16, 44 - i * 4], [58, 40 + i * 3], [28, 22 + i * 5]].forEach(([x, y]) => {
    setPx(png, x, y, hex('#a8cbe8')); setPx(png, x + 1, y, hex('#d5e8f5'));
  });
  save(png, 'water_' + i);
});

// ---- 집 (80x64 = 5x4 타일) ----
{
  const png = newImg(80, 64);
  const wall = hex('#c9a56b'), roof = hex('#a5402f'), roofDark = hex('#8c3325');
  const door = hex('#6b4423'), knob = hex('#ffd75e'), glass = hex('#9ecbe8');
  // 벽
  fillRect(png, 4, 16, 72, 48, wall);
  // 지붕 (삼각형)
  for (let y = 0; y < 20; y++) {
    const half = Math.floor((y / 19) * 40);
    fillRect(png, 40 - half, y, half * 2, 1, roof);
  }
  fillRect(png, 0, 19, 80, 3, roofDark);
  // 문 (캐릭터와 1:1 — 20x30 아트 = 월드 64x96)
  fillRect(png, 29, 33, 22, 31, hex('#4a2f16'));
  fillRect(png, 30, 34, 20, 30, door);
  [35, 41, 47].forEach((dx) => fillRect(png, dx, 35, 1, 29, hex('#5b3a1e')));
  fillRect(png, 30, 34, 20, 1, hex('#7a4e28'));
  fillRect(png, 46, 48, 2, 2, knob);
  // 창문
  [[12, 28], [56, 28]].forEach(([x, y]) => {
    fillRect(png, x, y, 12, 9, glass);
    fillRect(png, x, y, 12, 1, door); fillRect(png, x, y + 8, 12, 1, door);
    fillRect(png, x, y, 1, 9, door); fillRect(png, x + 11, y, 1, 9, door);
  });
  save(png, 'house');
}

console.log('done');


// ---- 32px 세계: 아직 1x인 스프라이트를 전부 2배로 (최근접) ----
const SKIP_2X = /^(player_|npc_.+_(down|up|side)_|grass_|soil_|path$|water_)/;
for (const name of SAVED_NAMES) {
  if (SKIP_2X.test(name)) continue;
  const file = path.join(OUT, name + '.png');
  const img = PNG.sync.read(fs.readFileSync(file));
  const big = new PNG({ width: img.width * 2, height: img.height * 2 });
  for (let y = 0; y < big.height; y++) for (let x = 0; x < big.width; x++) {
    const si = ((y >> 1) * img.width + (x >> 1)) * 4;
    const di = (y * big.width + x) * 4;
    big.data[di] = img.data[si]; big.data[di + 1] = img.data[si + 1];
    big.data[di + 2] = img.data[si + 2]; big.data[di + 3] = img.data[si + 3];
  }
  fs.writeFileSync(file, PNG.sync.write(big));
}
console.log('2x upscale pass done');

// ---- 농장 맵 오브젝트: Scale2x(EPX)로 한 번 더 2배 (64px 밀도, 계단 완화) ----
// 코드에서 절반 스케일로 그려 월드 크기는 그대로 유지된다.
const FARM_EPX = /^(tree_|rock$|bin$|house$|fence$|sprinkler$|board$|sign$|cave$|barn$|forage_|crop_|mature_|withered$)/;
function epx2x(img) {
  const big = new PNG({ width: img.width * 2, height: img.height * 2 });
  const get = (x, y) => {
    if (x < 0 || y < 0 || x >= img.width || y >= img.height) return -1;
    const i = (y * img.width + x) * 4;
    return img.data[i] << 24 | img.data[i + 1] << 16 | img.data[i + 2] << 8 | img.data[i + 3];
  };
  const put = (x, y, v) => {
    const i = (y * big.width + x) * 4;
    big.data[i] = (v >>> 24) & 255; big.data[i + 1] = (v >>> 16) & 255;
    big.data[i + 2] = (v >>> 8) & 255; big.data[i + 3] = v & 255;
  };
  for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
    const P = get(x, y), A = get(x, y - 1), B = get(x + 1, y), C = get(x - 1, y), D = get(x, y + 1);
    let e0 = P, e1 = P, e2 = P, e3 = P;
    if (C === A && C !== D && A !== B) e0 = A;
    if (A === B && A !== C && B !== D) e1 = B;
    if (D === C && D !== B && C !== A) e2 = C;
    if (B === D && B !== A && D !== C) e3 = D;
    put(x * 2, y * 2, e0); put(x * 2 + 1, y * 2, e1);
    put(x * 2, y * 2 + 1, e2); put(x * 2 + 1, y * 2 + 1, e3);
  }
  return big;
}
for (const name of SAVED_NAMES) {
  if (!FARM_EPX.test(name)) continue;
  const file = path.join(OUT, name + '.png');
  fs.writeFileSync(file, PNG.sync.write(epx2x(PNG.sync.read(fs.readFileSync(file)))));
}
console.log('farm epx pass done');
