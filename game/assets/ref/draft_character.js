// 캐릭터 초안 — 16비트 JRPG(FF6)풍.
//
// 참고 그림의 문법: 키의 절반 가까운 큰 머리, 모든 것에 어두운 윤곽선,
// 머리칼의 밝은 띠(빛을 받는 결), 또렷한 눈, 옷의 두 톤 주름.
// 판은 지금 캐릭터와 같은 128x192 (도트 32x48, 한 칸 4px) — 게임에
// 그대로 얹을 수 있는 크기로 그린다.
//
// 실행: node draft_character.js  -> ref/proposed_pc_draft_{down,side,up}.png
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';

class D {
  constructor(w, h) { this.w = w; this.h = h;
    this.d = Array.from({ length: h }, () => new Array(w).fill(null)); }
  px(x, y, c) { if (c && x >= 0 && y >= 0 && x < this.w && y < this.h) this.d[y][x] = c; }
  get(x, y) { return (x >= 0 && y >= 0 && x < this.w && y < this.h) ? this.d[y][x] : null; }
  rect(x0, y0, x1, y1, c) {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.px(x, y, c);
  }
  hline(x0, x1, y, c) { this.rect(x0, y, x1, y, c); }
  outline(col) {
    const add = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.d[y][x]) continue;
      for (const [ax, ay] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
        if (this.get(x + ax, y + ay) && this.get(x + ax, y + ay) !== col) { add.push([x, y]); break; }
    }
    for (const [x, y] of add) this.px(x, y, col);
  }
  render(Z) {
    const im = new PNG({ width: this.w * Z, height: this.h * Z });
    im.data.fill(0);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      for (let sy = 0; sy < Z; sy++) for (let sx = 0; sx < Z; sx++) {
        const i = ((y * Z + sy) * this.w * Z + (x * Z + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
      }
    }
    return im;
  }
}

const LINE = [44, 32, 28];
const SKIN = [244, 206, 168], SKIN_D = [212, 164, 126];
const HAIR = [138, 88, 48], HAIR_L = [182, 128, 72], HAIR_D = [98, 58, 32];
const SHIRT = [214, 104, 94], SHIRT_L = [238, 140, 124], SHIRT_D = [172, 76, 70];
const OVER = [86, 110, 160], OVER_L = [112, 138, 188], OVER_D = [60, 78, 120];
const BOOT = [112, 72, 40], BOOT_D = [82, 50, 28];
const EYE = [52, 38, 32], WHITE = [246, 244, 238];

// ---- 정면 (down) ----
function down() {
  const g = new D(32, 48), CX = 16;
  // 머리 — 키의 절반 가까이. 머리칼이 이마와 옆을 감싼다
  g.rect(9, 4, 22, 9, HAIR);                       // 윗머리
  g.rect(10, 3, 21, 3, HAIR);
  g.rect(8, 6, 8, 14, HAIR); g.rect(23, 6, 23, 14, HAIR);   // 옆머리
  g.rect(9, 10, 10, 12, HAIR); g.rect(21, 10, 22, 12, HAIR);
  g.hline(11, 20, 10, HAIR_D);                     // 이마선
  // 빛 받는 결 — 참고 그림(FF6)의 머리칼이 사는 이유는 이 밝은 띠다.
  // 넓게 한 번, 짧게 한 번, 그리고 어두운 결 두 가닥
  g.hline(11, 19, 4, HAIR_L); g.hline(12, 17, 5, HAIR_L);
  g.hline(13, 15, 6, HAIR_L); g.px(20, 5, HAIR_L);
  g.rect(14, 7, 14, 9, HAIR_D); g.rect(18, 6, 18, 8, HAIR_D);
  g.rect(9, 15, 9, 17, HAIR_D); g.rect(22, 15, 22, 17, HAIR_D);  // 귀밑머리
  // 얼굴
  g.rect(10, 11, 21, 19, SKIN);
  g.rect(11, 20, 20, 20, SKIN_D);                  // 턱 그늘
  g.rect(10, 18, 10, 19, SKIN_D); g.rect(21, 18, 21, 19, SKIN_D);
  // 눈 — 크고 또렷하게. 흰 점 하나가 생기를 만든다
  g.rect(12, 14, 13, 16, EYE); g.rect(18, 14, 19, 16, EYE);
  g.px(12, 14, WHITE); g.px(18, 14, WHITE);
  g.hline(12, 13, 13, HAIR_D); g.hline(18, 19, 13, HAIR_D);  // 눈썹
  g.px(15, 18, SKIN_D); g.px(16, 18, SKIN_D);      // 입
  // 몸통 — 셔츠 + 멜빵바지
  g.rect(10, 21, 21, 28, SHIRT);
  g.rect(10, 21, 21, 22, SHIRT_L);                 // 어깨가 빛을 받는다
  g.rect(10, 27, 21, 28, SHIRT_D);
  // 팔 (소매 + 손)
  g.rect(7, 22, 9, 29, SHIRT); g.rect(22, 22, 24, 29, SHIRT);
  g.rect(7, 22, 9, 23, SHIRT_L); g.rect(22, 22, 24, 23, SHIRT_L);
  g.rect(7, 30, 9, 32, SKIN); g.rect(22, 30, 24, 32, SKIN);
  // 멜빵바지 — 가슴판과 끈, 단추
  g.rect(12, 25, 19, 28, OVER);
  g.rect(11, 21, 12, 25, OVER); g.rect(19, 21, 20, 25, OVER);  // 끈
  g.px(12, 25, OVER_L); g.px(19, 25, OVER_L);      // 단추
  g.rect(10, 29, 21, 38, OVER);
  g.rect(10, 29, 21, 29, OVER_L);
  g.rect(15, 30, 16, 38, OVER_D);                  // 가랑이 골
  g.rect(10, 36, 21, 38, OVER_D);
  // 다리·장화
  g.rect(10, 39, 14, 43, OVER); g.rect(17, 39, 21, 43, OVER);
  g.rect(10, 43, 14, 43, OVER_D); g.rect(17, 43, 21, 43, OVER_D);
  g.rect(10, 44, 14, 46, BOOT); g.rect(17, 44, 21, 46, BOOT);
  g.rect(10, 46, 14, 46, BOOT_D); g.rect(17, 46, 21, 46, BOOT_D);
  g.outline(LINE);
  return g;
}

// ---- 옆 (side · 오른쪽 보기) ----
function side() {
  const g = new D(32, 48), CX = 16;
  // 머리 — 옆모습. 뒤통수가 크고 코가 살짝 나온다
  g.rect(9, 4, 21, 9, HAIR);
  g.rect(10, 3, 20, 3, HAIR);
  g.rect(8, 6, 8, 16, HAIR);                       // 뒤통수
  g.rect(9, 10, 12, 14, HAIR);                     // 옆머리 덩이
  g.rect(9, 15, 10, 18, HAIR_D);                   // 귀밑
  g.hline(11, 16, 4, HAIR_L); g.px(18, 5, HAIR_L); // 결
  g.hline(13, 19, 10, HAIR_D);
  // 얼굴 (오른쪽)
  g.rect(13, 11, 21, 19, SKIN);
  g.px(22, 15, SKIN); g.px(22, 16, SKIN_D);        // 코
  g.rect(14, 20, 20, 20, SKIN_D);
  g.rect(18, 14, 19, 16, EYE); g.px(18, 14, WHITE);
  g.hline(17, 20, 13, HAIR_D);                     // 눈썹
  g.px(20, 18, SKIN_D);                            // 입
  g.px(12, 16, SKIN_D); g.px(12, 15, SKIN);        // 귀
  // 몸 — 옆이라 폭이 좁다
  g.rect(11, 21, 19, 28, SHIRT);
  g.rect(11, 21, 19, 22, SHIRT_L);
  g.rect(11, 27, 19, 28, SHIRT_D);
  g.rect(14, 25, 18, 28, OVER);                    // 멜빵 가슴판(옆)
  g.rect(14, 21, 15, 25, OVER);
  g.rect(12, 22, 14, 29, SHIRT);                   // 앞팔
  g.rect(12, 30, 14, 32, SKIN);
  g.rect(11, 29, 19, 38, OVER);
  g.rect(11, 29, 19, 29, OVER_L);
  g.rect(11, 36, 19, 38, OVER_D);
  // 다리 — 걸음의 앞뒤
  g.rect(11, 39, 15, 43, OVER); g.rect(16, 39, 19, 42, OVER_D);
  g.rect(11, 44, 15, 46, BOOT); g.rect(16, 43, 19, 45, BOOT_D);
  g.rect(11, 46, 15, 46, BOOT_D);
  g.outline(LINE);
  return g;
}

// ---- 뒤 (up) ----
function up() {
  const g = new D(32, 48), CX = 16;
  // 뒤통수 — 얼굴이 없으니 머리칼의 결이 그림의 전부다
  g.rect(9, 4, 22, 18, HAIR);
  g.rect(10, 3, 21, 3, HAIR);
  g.rect(8, 6, 8, 15, HAIR); g.rect(23, 6, 23, 15, HAIR);
  g.hline(11, 16, 4, HAIR_L); g.hline(12, 18, 5, HAIR_L);   // 정수리 빛
  g.rect(9, 15, 22, 18, HAIR_D);                   // 목덜미 그늘
  g.rect(13, 19, 18, 20, SKIN_D);                  // 목
  // 몸 — 등판. 멜빵 X자가 등에서 갈린다
  g.rect(10, 21, 21, 28, SHIRT);
  g.rect(10, 21, 21, 22, SHIRT_L);
  g.rect(10, 27, 21, 28, SHIRT_D);
  g.rect(11, 21, 12, 26, OVER); g.rect(19, 21, 20, 26, OVER);
  g.px(13, 26, OVER); g.px(18, 26, OVER);
  g.rect(7, 22, 9, 29, SHIRT); g.rect(22, 22, 24, 29, SHIRT);
  g.rect(7, 22, 9, 23, SHIRT_L); g.rect(22, 22, 24, 23, SHIRT_L);
  g.rect(7, 30, 9, 32, SKIN); g.rect(22, 30, 24, 32, SKIN);
  g.rect(10, 29, 21, 38, OVER);
  g.rect(10, 29, 21, 29, OVER_L);
  g.rect(15, 30, 16, 38, OVER_D);
  g.rect(10, 36, 21, 38, OVER_D);
  g.rect(10, 39, 14, 43, OVER); g.rect(17, 39, 21, 43, OVER);
  g.rect(10, 44, 14, 46, BOOT); g.rect(17, 44, 21, 46, BOOT);
  g.rect(10, 46, 14, 46, BOOT_D); g.rect(17, 46, 21, 46, BOOT_D);
  g.outline(LINE);
  return g;
}

for (const [n, f] of [['down', down], ['side', side], ['up', up]])
  fs.writeFileSync(REF + 'proposed_pc_draft_' + n + '.png', PNG.sync.write(f().render(4)));
console.log('캐릭터 초안 3면 — 128x192 (도트 32x48)');
