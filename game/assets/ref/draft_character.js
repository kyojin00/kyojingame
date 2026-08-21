// 캐릭터 초안 — 16비트 JRPG(FF6)풍 · 2판.
//
// 1판은 머리가 키의 절반인 2등신이었다 — 참고 그림(FF6)의 비율은
// **2.5~3등신**이다: 머리가 키의 1/3, 몸통과 다리가 제 몫을 갖는다.
// 그 비율이 있어야 걷고 일하는 「사람」으로 읽힌다.
//
//   머리   y4..18  (15칸 ≈ 키의 1/3)
//   몸통   y19..31 (셔츠 + 멜빵 가슴판, 팔이 옆에 늘어진다)
//   하체   y32..46 (멜빵바지 다리 + 장화 — 다리 사이가 갈라져 보인다)
//
// 판은 지금 캐릭터와 같은 128x192 (도트 32x48, 한 칸 4px).
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
const HAIR = [138, 88, 48], HAIR_L = [186, 132, 76], HAIR_D = [98, 58, 32];
const SHIRT = [214, 104, 94], SHIRT_L = [238, 140, 124], SHIRT_D = [172, 76, 70];
const OVER = [86, 110, 160], OVER_L = [112, 138, 188], OVER_D = [60, 78, 120];
const BOOT = [112, 72, 40], BOOT_D = [82, 50, 28];
const EYE = [52, 38, 32], WHITE = [246, 244, 238];

// ---- 정면 (down) ----
function down() {
  const g = new D(32, 48);
  // 머리 (y4..18) — 키의 1/3. 머리칼이 이마와 옆을 감싼다
  g.rect(11, 5, 20, 8, HAIR);
  g.rect(12, 4, 19, 4, HAIR);
  g.rect(10, 6, 10, 13, HAIR); g.rect(21, 6, 21, 13, HAIR);
  g.rect(11, 9, 11, 10, HAIR); g.rect(20, 9, 20, 10, HAIR);
  g.hline(12, 19, 9, HAIR_D);                      // 이마선
  g.hline(12, 18, 5, HAIR_L); g.hline(13, 16, 6, HAIR_L);   // 빛 받는 결
  g.px(14, 7, HAIR_D); g.px(17, 7, HAIR_D);        // 어두운 결
  g.rect(10, 14, 10, 15, HAIR_D); g.rect(21, 14, 21, 15, HAIR_D);  // 귀밑머리
  // 얼굴 (y10..17)
  g.rect(11, 10, 20, 17, SKIN);
  g.rect(12, 17, 19, 17, SKIN_D);                  // 턱 그늘
  g.rect(11, 15, 11, 16, SKIN_D); g.rect(20, 15, 20, 16, SKIN_D);
  // 눈 — 크고 또렷하게, 흰 점 하나
  g.rect(13, 12, 14, 14, EYE); g.rect(17, 12, 18, 14, EYE);
  g.px(13, 12, WHITE); g.px(17, 12, WHITE);
  g.px(15, 16, SKIN_D); g.px(16, 16, SKIN_D);      // 입
  g.rect(13, 18, 18, 18, SKIN_D);                  // 목
  // 몸통 (y19..31) — 셔츠 + 멜빵 가슴판. 어깨가 빛을 받는다
  g.rect(11, 19, 20, 27, SHIRT);
  g.rect(11, 19, 20, 20, SHIRT_L);
  g.rect(11, 26, 20, 27, SHIRT_D);
  g.rect(13, 23, 18, 27, OVER);                    // 가슴판
  g.rect(12, 19, 13, 23, OVER); g.rect(18, 19, 19, 23, OVER);  // 끈
  g.px(13, 23, OVER_L); g.px(18, 23, OVER_L);      // 단추
  // 팔 — 소매 짧게, 팔뚝과 손
  g.rect(8, 20, 10, 24, SHIRT); g.rect(21, 20, 23, 24, SHIRT);
  g.rect(8, 20, 10, 21, SHIRT_L); g.rect(21, 20, 23, 21, SHIRT_L);
  g.rect(8, 25, 10, 29, SKIN); g.rect(21, 25, 23, 29, SKIN);
  g.rect(8, 29, 10, 30, SKIN_D); g.rect(21, 29, 23, 30, SKIN_D);
  // 하체 (y28..40) — 멜빵바지. 허리에서 다리로
  g.rect(11, 28, 20, 34, OVER);
  g.rect(11, 28, 20, 28, OVER_L);
  // 다리 (y35..43) — 사이가 갈라진다. 이게 있어야 「서 있는 사람」이다
  g.rect(11, 35, 14, 42, OVER); g.rect(17, 35, 20, 42, OVER);
  g.rect(11, 41, 14, 42, OVER_D); g.rect(17, 41, 20, 42, OVER_D);
  g.rect(14, 35, 14, 42, OVER_D); g.rect(17, 35, 17, 42, OVER_D);  // 안쪽 그늘
  // 장화 (y43..46)
  g.rect(10, 43, 14, 45, BOOT); g.rect(17, 43, 21, 45, BOOT);
  g.rect(10, 45, 14, 46, BOOT_D); g.rect(17, 45, 21, 46, BOOT_D);
  g.outline(LINE);
  return g;
}

// ---- 옆 (side · 오른쪽 보기) ----
function side() {
  const g = new D(32, 48);
  // 머리 — 뒤통수가 크고 코가 살짝 나온다
  g.rect(11, 5, 20, 8, HAIR);
  g.rect(12, 4, 19, 4, HAIR);
  g.rect(10, 6, 10, 15, HAIR);                     // 뒤통수
  g.rect(11, 9, 13, 13, HAIR);                     // 옆머리 덩이
  g.rect(11, 14, 12, 16, HAIR_D);                  // 귀밑
  g.hline(12, 17, 5, HAIR_L); g.px(18, 6, HAIR_L);
  g.hline(14, 18, 9, HAIR_D);
  // 얼굴
  g.rect(14, 10, 20, 17, SKIN);
  g.px(21, 13, SKIN); g.px(21, 14, SKIN_D);        // 코
  g.rect(15, 17, 19, 17, SKIN_D);
  g.rect(17, 12, 18, 14, EYE); g.px(17, 12, WHITE);
  g.px(19, 16, SKIN_D);                            // 입
  g.px(13, 14, SKIN_D);                            // 귀
  g.rect(14, 18, 17, 18, SKIN_D);                  // 목
  // 몸통 — 옆이라 폭이 좁다
  g.rect(12, 19, 19, 27, SHIRT);
  g.rect(12, 19, 19, 20, SHIRT_L);
  g.rect(12, 26, 19, 27, SHIRT_D);
  g.rect(14, 23, 18, 27, OVER);
  g.rect(14, 19, 15, 23, OVER);
  // 앞팔 하나만 보인다
  g.rect(13, 20, 15, 24, SHIRT);
  g.rect(13, 25, 15, 29, SKIN);
  g.rect(13, 29, 15, 30, SKIN_D);
  // 하체와 다리 — 앞뒤로 살짝 벌려 선다
  g.rect(12, 28, 19, 34, OVER);
  g.rect(12, 28, 19, 28, OVER_L);
  g.rect(12, 35, 15, 42, OVER); g.rect(16, 35, 19, 41, OVER_D);
  g.rect(11, 43, 15, 45, BOOT); g.rect(16, 42, 19, 44, BOOT_D);
  g.rect(11, 45, 15, 46, BOOT_D);
  g.outline(LINE);
  return g;
}

// ---- 뒤 (up) ----
function up() {
  const g = new D(32, 48);
  // 뒤통수 — 결이 그림의 전부다
  g.rect(11, 5, 20, 16, HAIR);
  g.rect(12, 4, 19, 4, HAIR);
  g.rect(10, 6, 10, 14, HAIR); g.rect(21, 6, 21, 14, HAIR);
  g.hline(12, 18, 5, HAIR_L); g.hline(13, 17, 6, HAIR_L);   // 정수리 빛
  g.px(15, 9, HAIR_D); g.px(18, 11, HAIR_D);
  g.rect(11, 14, 20, 16, HAIR_D);                  // 목덜미 그늘
  g.rect(13, 17, 18, 18, SKIN_D);                  // 목
  // 등판 — 멜빵이 X로 갈린다
  g.rect(11, 19, 20, 27, SHIRT);
  g.rect(11, 19, 20, 20, SHIRT_L);
  g.rect(11, 26, 20, 27, SHIRT_D);
  g.rect(12, 19, 13, 24, OVER); g.rect(18, 19, 19, 24, OVER);
  g.px(14, 24, OVER); g.px(17, 24, OVER);
  g.rect(8, 20, 10, 24, SHIRT); g.rect(21, 20, 23, 24, SHIRT);
  g.rect(8, 20, 10, 21, SHIRT_L); g.rect(21, 20, 23, 21, SHIRT_L);
  g.rect(8, 25, 10, 29, SKIN); g.rect(21, 25, 23, 29, SKIN);
  g.rect(8, 29, 10, 30, SKIN_D); g.rect(21, 29, 23, 30, SKIN_D);
  g.rect(11, 28, 20, 34, OVER);
  g.rect(11, 28, 20, 28, OVER_L);
  g.rect(11, 35, 14, 42, OVER); g.rect(17, 35, 20, 42, OVER);
  g.rect(14, 35, 14, 42, OVER_D); g.rect(17, 35, 17, 42, OVER_D);
  g.rect(11, 41, 14, 42, OVER_D); g.rect(17, 41, 20, 42, OVER_D);
  g.rect(10, 43, 14, 45, BOOT); g.rect(17, 43, 21, 45, BOOT);
  g.rect(10, 45, 14, 46, BOOT_D); g.rect(17, 45, 21, 46, BOOT_D);
  g.outline(LINE);
  return g;
}

for (const [n, f] of [['down', down], ['side', side], ['up', up]])
  fs.writeFileSync(REF + 'proposed_pc_draft_' + n + '.png', PNG.sync.write(f().render(4)));
console.log('캐릭터 초안 2판 (2.5~3등신) — 128x192 (도트 32x48)');
