// 플레이어 도트 한 벌 — 2등신 · 16비트 JRPG풍.
//
// 유저가 고른 비율: **2등신** (머리가 키의 절반 가까이). 어두운 윤곽선,
// 머리칼의 빛 띠, 또렷한 눈 — 참고 그림(FF6)의 문법을 2등신에 얹는다.
//
// 게임 규칙 (지키지 않으면 시스템이 깨진다):
//   판          128x192 (도트 32x48, 한 칸 4px). 발바닥이 y=190 (도트 47행)
//   허리        SWING_WAIST=136px = 도트 34행 — 휘두르기의 상·하체 분할선.
//               바지가 34행에 걸쳐 있어야 잘라도 티가 안 난다
//   표준 팔레트 옷 갈아입기(recolor_player_image)는 **색을 그대로 찾아**
//               바꾼다. 아래 색은 GameData.APPEAR_* 의 0번과 한 칸도
//               다르면 안 된다. 테두리·눈·눈썹은 교체 대상이 아니다
//   프레임      {down,up,side} × (idle · walk_0..5 · swing_0..4) + blink 둘
//   머리 4종    new_boy(민머리) · hair_short · hair_spiky · player_f(긴 머리)
//
// 실행:  node make_player.js            -> ref/proposed_*.png
//        node make_player.js --install  -> sprites/ 에 넣는다
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../sprites/';
const INSTALL = process.argv.includes('--install');

// ---- 표준 팔레트 (GameData.APPEAR_* 0번 그대로) ----
const LINE = [54, 33, 26];                 // 테두리 (교체 안 됨)
const EYE = [66, 32, 30], BROW = [136, 70, 42];
const SHIRT = [58, 88, 168], SHIRT_D = [38, 58, 120], SHIRT_L = [94, 126, 200];
const PANTS = [134, 88, 46], PANTS_D = [98, 62, 32], PANTS_L = [158, 108, 58];
const SHOE = [82, 53, 33], SHOE_D = [56, 37, 25];
const SKIN = [243, 159, 138], SKIN_L = [250, 192, 170], SKIN_D = [213, 116, 98];
const CHEEK = [235, 128, 114], MOUTH = [170, 84, 66];
const HAIR = [118, 72, 40], HAIR_L = [152, 100, 56], HAIR_D = [86, 52, 30];

class D {
  constructor() { this.w = 32; this.h = 48;
    this.d = Array.from({ length: 48 }, () => new Array(32).fill(null)); }
  px(x, y, c) { x = Math.round(x); y = Math.round(y);
    if (c && x >= 0 && y >= 0 && x < this.w && y < this.h) this.d[y][x] = c; }
  get(x, y) { return (x >= 0 && y >= 0 && x < this.w && y < this.h) ? this.d[y][x] : null; }
  rect(x0, y0, x1, y1, c) {
    for (let y = Math.round(y0); y <= Math.round(y1); y++)
      for (let x = Math.round(x0); x <= Math.round(x1); x++) this.px(x, y, c);
  }
  hline(x0, x1, y, c) { this.rect(x0, y, x1, y, c); }
  outline() {
    const add = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.d[y][x]) continue;
      for (const [ax, ay] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
        if (this.get(x + ax, y + ay) && this.get(x + ax, y + ay) !== LINE) { add.push([x, y]); break; }
    }
    for (const [x, y] of add) this.px(x, y, LINE);
  }
  render() {
    const Z = 4, im = new PNG({ width: 128, height: 192 });
    im.data.fill(0);
    for (let y = 0; y < 48; y++) for (let x = 0; x < 32; x++) {
      const c = this.d[y][x];
      if (!c) continue;
      for (let sy = 0; sy < Z; sy++) for (let sx = 0; sx < Z; sx++) {
        const i = ((y * Z + sy) * 128 + (x * Z + sx)) * 4;
        im.data[i] = c[0]; im.data[i + 1] = c[1]; im.data[i + 2] = c[2]; im.data[i + 3] = 255;
      }
    }
    return im;
  }
}

// ---- 머리 (dir: down/up/side · style · bob: 걸을 때 몸이 까딱이는 칸) ----
//
// 머리는 y(2+bob)..21+bob. 얼굴 폭 x9..22. 2등신의 절반이 이 머리다.
function head(g, dir, style, bob, blink) {
  const Y = y => y + bob;
  // 민머리든 아니든 **두상**은 같다 — 피부로 먼저 빚는다
  g.rect(10, Y(4), 21, Y(6), SKIN);
  g.rect(11, Y(3), 20, Y(3), SKIN);
  g.rect(9, Y(6), 22, Y(18), SKIN);
  g.rect(10, Y(19), 21, Y(20), SKIN);
  g.rect(11, Y(21), 20, Y(21), SKIN_D);            // 턱 그늘
  if (dir !== 'up') {
    g.rect(11, Y(3), 18, Y(4), SKIN_L);            // 정수리가 빛을 받는다 (민머리)
  }
  // 귀
  if (dir === 'down') { g.rect(8, Y(12), 8, Y(14), SKIN); g.px(8, Y(13), SKIN_D);
    g.rect(23, Y(12), 23, Y(14), SKIN); g.px(23, Y(13), SKIN_D); }
  if (dir === 'side') { g.rect(13, Y(13), 14, Y(15), SKIN_D); g.px(13, Y(14), SKIN); }
  // 얼굴 — 눈·눈썹·볼·입 (up 은 뒤통수라 없다)
  if (dir === 'down') {
    if (blink) { g.hline(12, 14, Y(13), EYE); g.hline(17, 19, Y(13), EYE); }
    else {
      g.rect(12, Y(11), 13, Y(14), EYE); g.rect(18, Y(11), 19, Y(14), EYE);
      g.px(12, Y(11), SKIN_L); g.px(18, Y(11), SKIN_L);    // 눈의 흰 점
    }
    g.hline(12, 14, Y(9), BROW); g.hline(17, 19, Y(9), BROW);
    g.px(10, Y(15), CHEEK); g.px(21, Y(15), CHEEK);
    g.hline(15, 16, Y(18), MOUTH);
  } else if (dir === 'side') {
    if (blink) g.hline(18, 20, Y(13), EYE);
    else { g.rect(18, Y(11), 19, Y(14), EYE); g.px(18, Y(11), SKIN_L); }
    g.hline(17, 20, Y(9), BROW);
    g.px(16, Y(15), CHEEK);
    g.px(22, Y(13), SKIN);                          // 코
    g.px(22, Y(14), SKIN_D);
    g.px(21, Y(18), MOUTH);
  }
  hair(g, dir, style, bob);
}

// 머리 모양 — 민머리는 아무것도 안 얹는다 (recolor 가 머리색 줄을 흐리는 근거)
function hair(g, dir, style, bob) {
  const Y = y => y + bob;
  if (style === 'new_boy') return;
  if (style === 'hair_short') {
    // 짧은 단발 — 이마와 옆을 감싸는 바가지
    g.rect(10, Y(3), 21, Y(7), HAIR); g.rect(11, Y(2), 20, Y(2), HAIR);
    g.rect(9, Y(5), 9, Y(12), HAIR); g.rect(22, Y(5), 22, Y(12), HAIR);
    if (dir === 'down') {
      g.hline(11, 20, Y(8), HAIR);                 // 앞머리단
      g.px(13, Y(9), HAIR); g.px(17, Y(9), HAIR); g.px(20, Y(9), HAIR);
      g.hline(11, 17, Y(3), HAIR_L); g.hline(12, 15, Y(4), HAIR_L);
      g.px(14, Y(6), HAIR_D); g.px(18, Y(5), HAIR_D);
      g.rect(9, Y(12), 9, Y(14), HAIR_D); g.rect(22, Y(12), 22, Y(14), HAIR_D);
    } else if (dir === 'side') {
      g.rect(9, Y(5), 12, Y(13), HAIR);            // 뒤통수 덩이
      g.rect(9, Y(13), 10, Y(16), HAIR_D);
      g.hline(13, 19, Y(8), HAIR);                 // 앞머리단(옆)
      g.px(20, Y(8), HAIR);
      g.hline(11, 17, Y(3), HAIR_L);
      g.px(11, Y(6), HAIR_D);
    } else {                                       // up — 뒤통수 전부
      g.rect(9, Y(5), 22, Y(15), HAIR);
      g.hline(11, 18, Y(3), HAIR_L); g.hline(12, 17, Y(4), HAIR_L);
      g.px(14, Y(8), HAIR_D); g.px(18, Y(10), HAIR_D);
      g.rect(9, Y(14), 22, Y(15), HAIR_D);
    }
  } else if (style === 'hair_spiky') {
    // 삐죽 머리 — 정수리에서 밖으로 뻗치는 결
    g.rect(10, Y(3), 21, Y(6), HAIR); g.rect(11, Y(2), 20, Y(2), HAIR);
    for (const [sx, sy] of [[11, 1], [14, 0], [17, 0], [20, 1]]) {
      g.px(sx, Y(sy), HAIR); g.px(sx + 1, Y(sy + 1), HAIR);
    }
    g.rect(9, Y(4), 9, Y(9), HAIR); g.rect(22, Y(4), 22, Y(9), HAIR);
    if (dir === 'down') {
      g.hline(11, 20, Y(7), HAIR);
      g.px(12, Y(8), HAIR); g.px(16, Y(8), HAIR); g.px(19, Y(8), HAIR);
      g.hline(12, 16, Y(3), HAIR_L); g.px(15, Y(1), HAIR_L);
      g.px(13, Y(5), HAIR_D); g.px(18, Y(4), HAIR_D);
    } else if (dir === 'side') {
      g.rect(9, Y(4), 12, Y(12), HAIR);
      g.px(8, Y(6), HAIR); g.px(8, Y(9), HAIR);    // 뒤로 뻗친 결
      g.hline(13, 18, Y(7), HAIR);
      g.hline(11, 16, Y(3), HAIR_L);
      g.px(10, Y(11), HAIR_D);
    } else {
      g.rect(9, Y(4), 22, Y(14), HAIR);
      g.hline(11, 18, Y(3), HAIR_L);
      g.px(13, Y(7), HAIR_D); g.px(17, Y(9), HAIR_D);
      g.rect(9, Y(13), 22, Y(14), HAIR_D);
    }
  } else {                                         // player_f — 긴 머리
    g.rect(10, Y(3), 21, Y(7), HAIR); g.rect(11, Y(2), 20, Y(2), HAIR);
    g.rect(8, Y(5), 9, Y(24), HAIR); g.rect(22, Y(5), 23, Y(24), HAIR);  // 어깨까지
    g.rect(8, Y(23), 9, Y(24), HAIR_D); g.rect(22, Y(23), 23, Y(24), HAIR_D);
    if (dir === 'down') {
      g.hline(11, 20, Y(8), HAIR);
      g.px(12, Y(9), HAIR); g.px(15, Y(9), HAIR); g.px(19, Y(9), HAIR);
      g.hline(11, 17, Y(3), HAIR_L); g.hline(12, 15, Y(4), HAIR_L);
      g.px(9, Y(16), HAIR_L); g.px(22, Y(18), HAIR_L);   // 늘어진 결의 빛
      g.px(14, Y(6), HAIR_D); g.px(18, Y(5), HAIR_D);
    } else if (dir === 'side') {
      g.rect(9, Y(5), 12, Y(14), HAIR);
      g.rect(8, Y(8), 11, Y(24), HAIR);            // 뒤로 흘러내린 머리
      g.rect(8, Y(22), 11, Y(24), HAIR_D);
      g.hline(13, 19, Y(8), HAIR);
      g.hline(11, 16, Y(3), HAIR_L); g.px(9, Y(15), HAIR_L);
    } else {
      g.rect(9, Y(5), 22, Y(17), HAIR);
      g.rect(10, Y(17), 21, Y(26), HAIR);          // 등으로 흘러내린 머리
      g.rect(10, Y(24), 21, Y(26), HAIR_D);
      g.hline(11, 18, Y(3), HAIR_L); g.hline(12, 16, Y(4), HAIR_L);
      g.px(13, Y(10), HAIR_D); g.px(18, Y(13), HAIR_D);
    }
  }
}

// ---- 팔 하나 — 어깨(sx,sy)에서 주먹(fx,fy)까지 곧게 ----
// 소매(셔츠)가 절반, 나머지가 맨팔. 주먹은 피부 두 칸.
// edged: 몸통 **위에** 놓이는 팔(옆모습)은 같은 색에 묻히므로,
// 먼저 윤곽선으로 한 둘레 두껍게 깔고 그 위에 팔을 그린다
function arm(g, sx, sy, fx, fy, edged) {
  // 팔뚝은 **세 도트** — 두 도트는 2등신의 몸집에 비해 철사처럼 얇다
  const n = Math.max(Math.abs(fx - sx), Math.abs(fy - sy), 1);
  if (edged) {
    for (let k = 0; k <= n; k++) {
      const x = sx + (fx - sx) * k / n, y = sy + (fy - sy) * k / n;
      g.rect(x - 2, y - 1, x + 2, y + 2, LINE);
    }
    g.rect(fx - 2, fy - 1, fx + 2, fy + 3, LINE);
  }
  for (let k = 0; k <= n; k++) {
    const x = sx + (fx - sx) * k / n, y = sy + (fy - sy) * k / n;
    const c = k < n * 0.45 ? SHIRT : SKIN;
    g.rect(x - 1, y, x + 1, y + 1, c);
  }
  g.rect(fx - 1, fy, fx + 1, fy + 1, SKIN);
  g.hline(fx - 1, fx + 1, fy + 2, SKIN_D);
}

// ---- 몸통·다리 (dir · bob · legs: [왼발 올림, 오른발 올림] 0~2 · sideStep) ----
function body(g, dir, bob, legL, legR, sideStep) {
  const Y = y => y + bob;
  if (dir === 'side') {
    // 옆 — 폭이 좁다. 셔츠 x11..19
    g.rect(11, Y(22), 19, Y(33), SHIRT);
    g.rect(11, Y(22), 19, Y(23), SHIRT_L);
    g.rect(11, Y(32), 19, Y(33), SHIRT_D);
    // 바지 — 허리(34행)에 걸친다. 다리는 앞뒤로 벌어진다 (sideStep -2..2)
    g.rect(11, 34, 19, 37, PANTS);
    g.hline(11, 19, 34, PANTS_L);
    const f = 15 + sideStep, b = 13 - sideStep;      // 앞다리 x, 뒷다리 x
    g.rect(b - 1, 38, b + 2, 43, PANTS_D);           // 뒷다리
    g.rect(f - 1, 38, f + 2, 43, PANTS);             // 앞다리
    g.rect(b - 2, 44, b + 3, 46, SHOE_D);
    g.rect(f - 2, 44, f + 3, 47, SHOE);
    g.hline(f - 2, f + 3, 47, SHOE_D);
  } else {
    // 앞·뒤 — 셔츠 x10..21
    g.rect(10, Y(22), 21, Y(33), SHIRT);
    g.rect(10, Y(22), 21, Y(23), SHIRT_L);
    g.rect(10, Y(32), 21, Y(33), SHIRT_D);
    if (dir === 'down') {                            // 앞섶 단추
      g.px(15, Y(26), SHIRT_D); g.px(15, Y(29), SHIRT_D);
    }
    // 바지 (34..41) + 가랑이 골
    g.rect(10, 34, 21, 41, PANTS);
    g.hline(10, 21, 34, PANTS_L);
    g.rect(15, 36, 16, 41, PANTS_D);
    // 다리·장화 — 올린 발은 장화가 위로 들린다
    for (const [x0, x1, lift] of [[10, 14, legL], [17, 21, legR]]) {
      g.rect(x0, 42 - lift, x1, 43 - lift, PANTS);
      g.rect(x0, 44 - lift, x1, 46 - lift, SHOE);
      g.hline(x0, x1, 47 - lift, SHOE_D);
    }
  }
}

// ---- 한 장 ----
//
// kind: 'idle' | 'blink' | 'walk' | 'swing',  i: 프레임 번호
function frame(style, dir, kind, i) {
  const g = new D();
  const bob = kind === 'walk' ? [0, -1, 0, 0, -1, 0][i] : 0;

  if (kind === 'swing') {
    // 주먹 자리 — player.gd 의 도구 손잡이 좌표(TOOL)와 맞춘 도트.
    // 도구는 게임이 이 주먹에 쥐여 준다
    const FIST = {
      down: [[6, 21], [4, 12], [3, 20], [9, 32], [6, 22]],
      up:   [[24, 19], [24, 12], [20, 6], [17, 11], [24, 16]],
      // 옆 — 주먹이 얼굴을 가로지르면 안 된다. 와인드업은 머리 **뒤로**
      // 넘어갔다가(7,6) 정수리 위(17,3)를 지나 앞으로 내리친다
      side: [[8, 17], [7, 6], [17, 3], [24, 25], [20, 31]],
    }[dir][i];
    const lean = [0, -1, -1, 1, 1][i];               // 젖혔다 숙인다
    body(g, dir, lean, 0, 0, 0);
    head(g, dir, style, lean, false);
    if (dir === 'side') {
      arm(g, 14, 24 + lean, FIST[0], FIST[1], true); // 보이는 팔 하나
    } else {
      // 두 손 모아 쥔다 — 주먹 자리에 양팔이 모인다
      arm(g, 11, 24 + lean, FIST[0], FIST[1]);
      arm(g, 20, 24 + lean, FIST[0] + 1, FIST[1]);
    }
  } else {
    const legL = kind === 'walk' ? [0, 1, 2, 0, 0, 0][i] : 0;
    const legR = kind === 'walk' ? [0, 0, 0, 0, 1, 2][i] : 0;
    const sideStep = kind === 'walk' ? [0, 2, 3, 0, -2, -3][i] : 0;
    body(g, dir, bob, legL, legR, sideStep);
    head(g, dir, style, bob, kind === 'blink');
    if (dir === 'side') {
      const sw = kind === 'walk' ? [0, -2, -3, 0, 2, 3][i] : 0;   // 팔은 다리와 반대로
      arm(g, 14, 24 + bob, 14 + sw, 31 + bob, true);
    } else {
      const swL = kind === 'walk' ? -legR : 0;       // 왼팔은 오른발과 함께
      const swR = kind === 'walk' ? -legL : 0;
      arm(g, 8, 24 + bob, 7, 31 + bob + swL);
      arm(g, 22, 24 + bob, 23, 31 + bob + swR);
    }
  }
  g.outline();
  return g;
}

// ---- 뽑기 ----
const STYLES = ['new_boy', 'hair_short', 'hair_spiky', 'player_f'];
let n = 0;
for (const st of STYLES) {
  const jobs = [['down', 'idle', 0], ['up', 'idle', 0], ['side', 'idle', 0],
    ['down', 'blink', 0], ['side', 'blink', 0]];
  for (const d of ['down', 'up', 'side']) {
    for (let i = 0; i < 6; i++) jobs.push([d, 'walk', i]);
    for (let i = 0; i < 5; i++) jobs.push([d, 'swing', i]);
  }
  for (const [d, k, i] of jobs) {
    const name = k === 'idle' ? `${st}_${d}_idle`
      : k === 'blink' ? `${st}_${d}_blink`
      : `${st}_${d}_${k}_${i}`;
    fs.writeFileSync((INSTALL ? SPR : REF + 'proposed_') + name + '.png',
      PNG.sync.write(frame(st, d, k, i).render()));
    n++;
  }
}
console.log(`플레이어 도트 ${n}장 — 128x192 (2등신 · 머리 4종 · 표준 팔레트)`);
console.log(INSTALL ? '  sprites/ 에 넣었다' : '  ref/proposed_*.png 로만 뽑았다');
