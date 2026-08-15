// 건물 생성기 — **캐릭터와 같은 도트 크기**로 그린다.
//
// 왜 다시 그리는가 —
//   캐릭터: 32x48 논리 격자를 화면에 2배로   -> 화면 2px = 도트 한 칸
//   옛 건물: 512x410 그림을 화면에 0.5배로   -> 화면 1px = 원본 2px
// 건물 쪽 도트가 **4배 촘촘해서**, 나란히 두면 사람만 굵고 건물은 매끈해
// 같은 게임의 그림으로 안 읽힌다.
//
// 옛 그림을 4칸씩 묶어 굵게 만들어도 봤지만 **서까래·창틀이 뭉갰다** —
// 얇은 선으로 그린 그림은 묶으면 선이 죽는다. 그래서 처음부터
// **128x102 논리 격자**에 굵은 형태로 그리고 4배로 펴서 512x408로 낸다
// (게임이 쓰는 크기 그대로라 코드는 안 건드린다).
//
// 굵은 격자에서 지키는 것:
//   * 선은 **한 칸**. 두 칸이면 화면에서 4px이 되어 뭉툭해진다
//   * 면은 세 톤까지 (밝은 면·기본·그늘). 그 이상은 굵은 칸에서 얼룩이 된다
//   * 창·문 같은 것은 **최소 3x3칸**. 그보다 작으면 무엇인지 안 읽힌다
//
// 실행:  node make_buildings.js            -> ref/proposed_*.png (제안만)
//        node make_buildings.js --install  -> sprites/ 에 실제로 넣는다
//
// 기본이 「제안만」인 이유: 지금 건물 그림은 얇은 선으로 곱게 그려져 있어서,
// 굵은 격자로 바꾸면 **도트 크기는 맞지만 멋은 줄어든다.** 어느 쪽을 쓸지는
// 눈으로 보고 정할 일이라, 확인하기 전에는 게임 그림을 안 건드린다.
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');
const OUT = INSTALL ? SPR : REF;
const PRE = INSTALL ? '' : 'proposed_';

const S = 4;                     // 논리 한 칸 = 원본 4px (화면에서 2px)
const GW = 128, GH = 102;        // 논리 격자 (512x408)
const FW = GW * S, FH = GH * S;

// 팔레트. 캐릭터(dot_boy)와 같은 결이 되게 채도를 낮추고 단계를 줄였다.
const PAL = {
  '.': null,
  'O': [46, 34, 30],       // 윤곽선
  // 지붕 (붉은 기와)
  'r': [186, 78, 52], 'R': [140, 54, 38], 'l': [214, 112, 78],
  // 벽 (회벽)
  'w': [226, 214, 190], 'W': [186, 172, 148], 'x': [244, 236, 216],
  // 나무 기둥·문
  't': [124, 84, 52], 'T': [88, 58, 36], 'u': [152, 110, 70],
  // 돌 (굴뚝·주춧돌)
  's': [150, 146, 140], 'S': [110, 106, 102],
  // 유리
  'g': [110, 158, 190], 'G': [72, 112, 148],
  // 풀·화단
  'n': [92, 138, 74], 'N': [64, 102, 52],
  // 간판
  'b': [214, 186, 132], 'B': [166, 138, 92],
};

class G {
  constructor() { this.d = Array.from({ length: GH }, () => new Array(GW).fill('.')); }
  px(x, y, c) { if (x >= 0 && y >= 0 && x < GW && y < GH) this.d[y][x] = c; }
  rect(x0, y0, x1, y1, c) {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.px(x, y, c);
  }
  hline(x0, x1, y, c) { this.rect(x0, y, x1, y, c); }
  vline(x, y0, y1, c) { this.rect(x, y0, x, y1, c); }
  // 윤곽선: 채워진 곳 둘레의 빈 칸을 두른다 (캐릭터와 같은 방식)
  outline() {
    const add = [];
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
      if (this.d[y][x] !== '.') continue;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]])
        if (nx >= 0 && ny >= 0 && nx < GW && ny < GH
            && this.d[ny][nx] !== '.' && this.d[ny][nx] !== 'O') { add.push([x, y]); break; }
    }
    for (const [x, y] of add) this.px(x, y, 'O');
  }
  render() {
    const im = new PNG({ width: FW, height: FH });
    im.data.fill(0);
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
      const c = PAL[this.d[y][x]];
      if (!c) continue;
      for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
        const i = ((y * S + sy) * FW + (x * S + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
      }
    }
    return im;
  }
}

// ---- 뼈대 ----
// 게임이 8칸(256px) 폭에 앉히므로 논리 폭 128 전부를 쓴다.
// 바닥은 아래에서 두 칸 띄운다 (그림자 자리).
const X0 = 14, X1 = 113;         // 앞면 좌우
const GROUND = 97;               // 바닥선
const EAVE = 52;                 // 처마 (여기 위가 지붕)
const RIDGE = 14;                // 용마루


function roof(g, x0, x1, top, base, mainC, darkC, liteC) {
  // 맞배지붕 — 한 줄씩 좁혀 올라간다. 한 칸씩만 좁혀야 계단이 곱게 진다.
  const h = base - top;
  const halfW = (x1 - x0) / 2;
  for (let i = 0; i <= h; i++) {
    const t = i / h;
    const w = Math.round(halfW * t);
    const cx = (x0 + x1) / 2;
    const y = top + i;
    g.rect(Math.round(cx - w), y, Math.round(cx + w), y, mainC);
  }
  // 기와 결 — 세 줄마다 한 줄 어둡게. 굵은 격자에서는 이 정도가 「기와」로 읽힌다
  for (let y = top + 2; y <= base; y += 3) {
    for (let x = 0; x < GW; x++) if (g.d[y][x] === mainC) g.px(x, y, darkC);
  }
  // 용마루에 빛
  g.hline(Math.round((x0 + x1) / 2) - 2, Math.round((x0 + x1) / 2) + 2, top, liteC);
}


function window3(g, x, y, w = 5, h = 6) {
  // 창은 최소 3x3칸 — 그보다 작으면 굵은 격자에서 점으로 보인다
  g.rect(x, y, x + w - 1, y + h - 1, 't');            // 창틀
  g.rect(x + 1, y + 1, x + w - 2, y + h - 2, 'g');    // 유리
  g.hline(x + 1, x + w - 2, y + 1, 'G');              // 위쪽 그늘
  g.vline(x + Math.floor(w / 2), y + 1, y + h - 2, 't');   // 창살 세로
}


function door(g, cx, w = 9, h = 16) {
  const x0 = cx - Math.floor(w / 2), y0 = GROUND - h;
  g.rect(x0, y0, x0 + w - 1, GROUND, 'T');            // 문틀
  g.rect(x0 + 1, y0 + 1, x0 + w - 2, GROUND, 't');    // 문짝
  g.vline(x0 + 1, y0 + 1, GROUND, 'u');               // 왼쪽에 빛
  g.px(x0 + w - 3, y0 + Math.floor(h / 2), 'b');      // 손잡이
  // 문 위 차양
  g.rect(x0 - 2, y0 - 2, x0 + w + 1, y0 - 1, 'r');
  g.hline(x0 - 2, x0 + w + 1, y0 - 2, 'l');
}


function chimney(g, x, top) {
  g.rect(x, top, x + 5, EAVE + 4, 'S');
  g.rect(x + 1, top + 1, x + 4, EAVE + 4, 's');
  g.rect(x - 1, top, x + 6, top + 2, 'S');            // 갓
  g.rect(x, top + 1, x + 5, top + 1, 's');
}


function sign(g, cx, text) {
  // 간판 — 글자는 못 넣으니 색 띠로 자리만 만든다 (게임이 이름을 따로 띄운다)
  const w = 22, x0 = cx - w / 2, y = EAVE + 3;
  g.rect(x0, y, x0 + w, y + 5, 'B');
  g.rect(x0 + 1, y + 1, x0 + w - 1, y + 4, 'b');
  for (let i = 0; i < 3; i++) g.rect(x0 + 4 + i * 6, y + 2, x0 + 6 + i * 6, y + 3, 'B');
  g.vline(x0 + 2, y - 2, y, 'T');                      // 매단 줄
  g.vline(x0 + w - 2, y - 2, y, 'T');
}


function bushes(g, cx) {
  for (const dx of [-46, -38, 40, 47]) {
    const x = cx + dx;
    g.rect(x, GROUND - 4, x + 5, GROUND, 'N');
    g.rect(x + 1, GROUND - 5, x + 4, GROUND - 1, 'n');
  }
}


// spec: 지붕색 · 간판 유무 · 굴뚝 자리 · 덧붙임
function build(spec) {
  const g = new G();
  const cx = Math.round((X0 + X1) / 2);
  // 벽
  g.rect(X0, EAVE, X1, GROUND, 'w');
  // 벽에 결 — 아래로 갈수록 한 톤 어둡게 (굵은 격자라 두 톤이면 충분하다)
  g.rect(X0, GROUND - 12, X1, GROUND, 'W');
  // 나무 기둥 (하프팀버) — 한 칸 굵기
  for (const x of [X0 + 3, cx - 22, cx + 22, X1 - 3]) g.vline(x, EAVE + 1, GROUND, 't');
  g.hline(X0, X1, GROUND - 13, 't');
  g.hline(X0, X1, EAVE + 1, 'T');
  // 주춧돌
  g.rect(X0 - 2, GROUND - 3, X1 + 2, GROUND, 'S');
  g.rect(X0 - 1, GROUND - 3, X1 + 1, GROUND - 1, 's');
  // 창 둘 + 문
  window3(g, cx - 38, EAVE + 12, 11, 12);
  window3(g, cx + 27, EAVE + 12, 11, 12);
  door(g, cx, 15, 26);
  // 지붕 (처마가 벽보다 좌우로 세 칸 나온다)
  roof(g, X0 - 4, X1 + 4, RIDGE, EAVE, spec.roof, spec.roofD, spec.roofL);
  g.hline(X0 - 5, X1 + 5, EAVE, spec.roofD);           // 처마 끝
  // 다락창
  window3(g, cx - 5, RIDGE + 16, 11, 10);
  if (spec.chimney !== false) chimney(g, spec.chimneyX || X1 - 22, RIDGE + 6);
  if (spec.sign) sign(g, cx);
  bushes(g, cx);
  g.outline();
  return g;
}


const ROOFS = {
  red: { roof: 'r', roofD: 'R', roofL: 'l' },
};

const KINDS = {
  house: { sign: false },                    // 우리집
  house_general: { sign: true },             // 잡화점
  house_ranch: { sign: true },               // 목장 상회
  house_smith: { sign: true, chimneyX: 20 }, // 대장간 (굴뚝이 크다)
  house_fish: { sign: true },                // 수산시장
  house_inn: { sign: true },                 // 여관
  house_library: { sign: true },             // 도서관
  house_lab: { sign: true },                 // 연구소
  house_post: { sign: true },                // 우체국
};

let n = 0;
for (const [name, spec] of Object.entries(KINDS)) {
  const g = build(Object.assign({}, ROOFS.red, spec));
  fs.writeFileSync(OUT + PRE + name + '.png', PNG.sync.write(g.render()));
  n++;
}
console.log(`건물 ${n}채 — ${FW}x${FH} (논리 ${GW}x${GH} · 화면에서 도트 2px)`);
console.log(INSTALL ? '  sprites/ 에 넣었다' : '  ref/proposed_*.png 로만 뽑았다 (--install 을 붙이면 게임에 넣는다)');

// 확인용: 캐릭터를 옆에 세워 도트 크기가 맞는지 본다
const house = PNG.sync.read(fs.readFileSync(OUT + PRE + 'house.png'));
const boy = PNG.sync.read(fs.readFileSync(SPR + 'new_boy_down_idle.png'));
const W = FW / 2 + 200, H = FH / 2;
const cmp = new PNG({ width: W, height: H });
for (let i = 0; i < W * H; i++) {
  cmp.data[i * 4] = 96; cmp.data[i * 4 + 1] = 132; cmp.data[i * 4 + 2] = 78;
  cmp.data[i * 4 + 3] = 255;
}
// 집은 0.5배, 캐릭터도 0.5배 — 게임에서 그려지는 그대로
const half = (im, ox, oy) => {
  for (let y = 0; y < im.height; y += 2) for (let x = 0; x < im.width; x += 2) {
    const si = (y * im.width + x) * 4;
    if (im.data[si + 3] < 128) continue;
    const di = ((oy + y / 2) * W + ox + x / 2) * 4;
    if (di < 0 || di >= cmp.data.length) continue;
    cmp.data[di] = im.data[si]; cmp.data[di + 1] = im.data[si + 1];
    cmp.data[di + 2] = im.data[si + 2];
  }
};
half(house, 0, 0);
half(boy, FW / 2 + 40, H - boy.height / 2);
fs.writeFileSync(REF + 'preview_buildings.png', PNG.sync.write(cmp));
console.log('preview_buildings.png — 게임에 그려지는 크기로 집과 캐릭터를 나란히');
