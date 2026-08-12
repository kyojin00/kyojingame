// 휘두르기 도트 도면 — 이 위에 그리면 자리가 맞는다.
//
// 캐릭터 도트는 128x192다. 여기에 3방향 x 3위상 = 9칸을 깔고, 각 칸에
// 서기 자세를 어둡게 깔아 준다. 그 위에 **팔만** 고쳐 그리면 된다.
//
// 칸 하나가 정확히 128x192라, 쓰고 싶은 칸을 그대로 오려 새 파일로 만들면
// 규격이 저절로 맞는다. 게임에 넣는 그림이 아니라 사람이 보고 그리는
// 도면이라 docs/에 둔다.
//
// 표시하는 것 —
//   흰 선     발바닥(188행). 여기가 어긋나면 휘두를 때만 캐릭터가 뜬다
//   초록 점선 허리(136행). 게임이 여기서 상·하체를 갈라 상체만 돌린다
//   파랑 점선 어깨(78행). 팔이 시작하는 높이
//   회색 점선 엉덩이 중심(x=64). 어긋나면 휘두를 때 옆으로 순간이동한다
//   주황 십자 **손잡이 끝이 와야 할 자리.** 주먹 한가운데를 여기 맞춘다
//   주황 선   도구가 뻗는 방향 (날 끝까지)
//   왼쪽 위 네모  위상 번호 (1개=swing_0 / 2개=swing_1 / 3개=swing_2)
//
// ※ **도구는 그리지 않는다.** 게임이 손잡이 끝을 축으로 도구 그림을 따로
//    얹는다 (도끼·곡괭이·호미·물뿌리개가 같은 도트를 나눠 쓴다). 도구까지
//    그리면 두 개가 겹친다. 주황 십자에 주먹만 맞춰 두면 된다.
//
// 실행:  node make_swing_guide.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const SPR = __dirname + '/../../sprites/';
const OUT = __dirname + '/../../../docs/';

const FW = 128, FH = 192;        // 캐릭터 도트 규격
const FOOT = 188;                // 발바닥이 놓이는 행 (scenes/player.tscn의 offset)
const HIP_X = 64;                // 엉덩이 중심 열
const ART = 0.5;                 // 게임에서 그리는 배율 (node 1px = 도트 2px)

// scripts/player.gd 의 값을 그대로 옮긴 것. 저기를 고치면 여기도 고친다.
const SWING_SHIFT = 5.0;
const POSE = {
  side: { file: 'new_boy_side_idle', hand: [12, -38], mid: 0.95, arc: 2.9, shift: [5, 1] },
  down: { file: 'new_boy_down_idle', hand: [10, -36], mid: 0.85, arc: 2.6, shift: [1, 3] },
  up:   { file: 'new_boy_up_idle',   hand: [-9, -40], mid: 0.80, arc: 2.4, shift: [1, -3] },
};
// 위상마다 대표로 삼는 휘두르기 값 (player.gd `swing_phase`의 갈림값 한가운데)
const PHASE_C = [-1.0, 0.1, 1.0];
// 도트가 이미 있는 방향은 **그 도트의 주먹 자리**를 찍는다 (player.gd SWING_HAND_DOT).
// make_swing_src.js가 팔을 돌린 각도에서 계산해 준 값이다.
const HAND_DOT = { side: [[-21, -52], [14, -47], [13, -39]] };
const TOOL_LEN = 34;             // 손잡이 끝 ~ 날 끝 (node px)

const DIRS = ['side', 'down', 'up'];
const W = FW * PHASE_C.length, H = FH * DIRS.length;

const C = {
  bg: [26, 28, 34], cell: [44, 48, 58],
  foot: [240, 240, 240], waist: [92, 196, 108],
  shoulder: [96, 150, 226], hip: [90, 96, 112],
  hand: [236, 146, 58], reach: [150, 92, 40],
};

const img = Array.from({ length: H }, () => new Array(W).fill(C.bg));
const inb = (x, y) => x >= 0 && y >= 0 && x < W && y < H;
function px(x, y, c) { x = Math.round(x); y = Math.round(y); if (inb(x, y)) img[y][x] = c; }
function line(x0, y0, x1, y1, c, on, off) {
  const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
  for (let i = 0; i <= n; i++) {
    if (off && i % (on + off) >= on) continue;
    px(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, c);
  }
}
function disc(cx, cy, r, c) {
  for (let j = -r; j <= r; j++) for (let i = -r; i <= r; i++)
    if (i * i + j * j <= r * r) px(cx + i, cy + j, c);
}

const load = n => PNG.sync.read(fs.readFileSync(SPR + n + '.png'));

DIRS.forEach((dir, row) => {
  const pose = POSE[dir];
  const idle = load(pose.file);
  PHASE_C.forEach((c, col) => {
    const ox = col * FW, oy = row * FH;

    // 서기 자세를 어둡게 깔아 준다 (이걸 고쳐 그리면 된다)
    for (let y = 0; y < FH; y++) for (let x = 0; x < FW; x++) {
      const i = ((y * idle.width) + x) * 4;
      if (idle.data[i + 3] < 128) continue;
      px(ox + x, oy + y, [0, 1, 2].map(k =>
        Math.round(idle.data[i + k] * 0.38 + C.bg[k] * 0.62)));
    }

    // 규격선
    line(ox, oy + FOOT, ox + FW - 1, oy + FOOT, C.foot, 1, 0);
    line(ox, oy + 136, ox + FW - 1, oy + 136, C.waist, 3, 3);      // player.gd SWING_WAIST
    line(ox, oy + 78, ox + FW - 1, oy + 78, C.shoulder, 3, 5);
    line(ox + HIP_X, oy, ox + HIP_X, oy + FH - 1, C.hip, 3, 6);

    // 손잡이 끝이 와야 할 자리 — player.gd `_swing_visual`의 tool_sprite.position
    let hx, hy;
    if (HAND_DOT[dir]) {
      [hx, hy] = HAND_DOT[dir][col];            // 도트가 있는 방향
    } else {
      hx = pose.hand[0] + c * 7.0 + pose.shift[0] * c * (SWING_SHIFT / 5.0);
      hy = pose.hand[1] + c * 9.0 + pose.shift[1] * c * (SWING_SHIFT / 5.0);
    }
    const tx = ox + HIP_X + hx / ART, ty = oy + FOOT + hy / ART;
    // 도구가 뻗는 방향 (회전 0 = 위로 곧게 선 도구)
    const rot = pose.mid + c * pose.arc * 0.5;
    line(tx, ty, tx + Math.sin(rot) * TOOL_LEN / ART,
      ty - Math.cos(rot) * TOOL_LEN / ART, C.reach, 2, 2);
    disc(tx, ty, 3, C.hand);
    line(tx - 6, ty, tx + 6, ty, C.hand, 1, 0);
    line(tx, ty - 6, tx, ty + 6, C.hand, 1, 0);

    // 위상 번호 (네모 개수)
    for (let k = 0; k <= col; k++)
      for (let j = 0; j < 4; j++) for (let i = 0; i < 4; i++)
        px(ox + 3 + k * 6 + i, oy + 3 + j, C.hand);

    // 칸 테두리 (칸 하나가 정확히 128x192 — 오려서 그대로 쓰면 된다)
    for (let x = 0; x < FW; x++) { px(ox + x, oy, C.cell); px(ox + x, oy + FH - 1, C.cell); }
    for (let y = 0; y < FH; y++) { px(ox, oy + y, C.cell); px(ox + FW - 1, oy + y, C.cell); }
  });
});

const p = new PNG({ width: W, height: H });
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = (y * W + x) * 4, c = img[y][x];
  p.data[i] = c[0]; p.data[i + 1] = c[1]; p.data[i + 2] = c[2]; p.data[i + 3] = 255;
}
fs.writeFileSync(OUT + 'swing_guide.png', PNG.sync.write(p));
console.log('휘두르기 도면 생성: docs/swing_guide.png (%dx%d) — 가로 위상 3, 세로 %s',
  W, H, DIRS.join('/'));
