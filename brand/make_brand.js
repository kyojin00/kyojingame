// 계정용 프로필(400x400) · 배너(1500x500)를 게임 자산에서 뽑는다.
// 도트는 **최근접 확대**만 쓴다 (보간하면 픽셀이 뭉개져 도트 게임처럼 안 보인다).
const fs = require('fs'), { PNG } = require('pngjs');
const G = '/home/user/kyojingame/game/';
const OUT = __dirname + '/';   // brand/ 안에 떨어진다

// ---------- 프로필: 얼굴을 크게 (X는 48px로도 보여준다 — 전신을 넣으면 뭉갠다)
function profile(srcName, outName, bg) {
  const p = PNG.sync.read(fs.readFileSync(G + 'assets/sprites/' + srcName));
  const { width: W, height: H, data: D } = p;
  // 머리~가슴께만 잘라 쓴다. 실루엣 위쪽에서 아래로 전체 높이의 45%까지.
  let top = H, left = W, right = -1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
    if (D[(y * W + x) * 4 + 3]) { if (y < top) top = y; if (x < left) left = x; if (x > right) right = x; }
  const cutH = Math.round((H - top) * 0.45);
  // 가로는 잘린 구간 안에서 다시 잰다 (팔이 없는 얼굴 폭)
  let l2 = W, r2 = -1;
  for (let y = top; y < top + cutH; y++) for (let x = 0; x < W; x++)
    if (D[(y * W + x) * 4 + 3]) { if (x < l2) l2 = x; if (x > r2) r2 = x; }
  const cw = r2 - l2 + 1;
  const S = 400, PAD = 26;
  const Z = Math.floor((S - PAD * 2) / Math.max(cw, cutH));   // 정수배만 (도트 유지)
  const o = new PNG({ width: S, height: S });
  for (let i = 0; i < S * S; i++) {
    o.data[i * 4] = bg[0]; o.data[i * 4 + 1] = bg[1]; o.data[i * 4 + 2] = bg[2]; o.data[i * 4 + 3] = 255;
  }
  const ox = Math.round((S - cw * Z) / 2), oy = Math.round((S - cutH * Z) / 2);
  for (let y = 0; y < cutH; y++) for (let x = 0; x < cw; x++) {
    const si = ((top + y) * W + (l2 + x)) * 4; if (D[si + 3] < 128) continue;
    for (let dy = 0; dy < Z; dy++) for (let dx = 0; dx < Z; dx++) {
      const X = ox + x * Z + dx, Y = oy + y * Z + dy;
      if (X < 0 || Y < 0 || X >= S || Y >= S) continue;
      const di = (Y * S + X) * 4;
      o.data[di] = D[si]; o.data[di + 1] = D[si + 1]; o.data[di + 2] = D[si + 2];
    }
  }
  fs.writeFileSync(OUT + outName, PNG.sync.write(o));
  console.log(outName, `얼굴 ${cw}x${cutH} · ${Z}배`);
}

// ---------- 배너: 게임 화면에서 **UI가 없는 가로 띠**만 오려 낸다
// 위쪽은 미니맵·퀘스트창(베이지 패널), 아래쪽은 대사줄·소지품칸이 걸린다.
// 세로로 쓸 수 있는 높이가 3:1보다 모자라므로 **가로를 같이 줄여** 비율을 맞춘다.
// (가로만 맞추면 캐릭터가 20% 늘어난다 — 도트가 늘어난 건 바로 티가 난다)
function banner(shot, outName, y0, y1) {
  const p = PNG.sync.read(fs.readFileSync(G + shot));
  const { width: SW, data: D } = p;
  const W = 1500, H = 500;
  const bh = y1 - y0, bw = Math.min(SW, Math.round(bh * W / H));
  const x0 = Math.round((SW - bw) / 2);
  const o = new PNG({ width: W, height: H });
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const sx = x0 + Math.min(bw - 1, Math.floor(x * bw / W));
    const sy = y0 + Math.min(bh - 1, Math.floor(y * bh / H));
    const si = (sy * SW + sx) * 4, di = (y * W + x) * 4;
    o.data[di] = D[si]; o.data[di + 1] = D[si + 1]; o.data[di + 2] = D[si + 2]; o.data[di + 3] = 255;
  }
  fs.writeFileSync(OUT + outName, PNG.sync.write(o));
  console.log(outName, `${shot} x${x0}~${x0 + bw} y${y0}~${y1} (${bw}x${bh})`);
}

// 배경색은 게임 팔레트에서 (잔디 어두운 쪽 / 흙 따뜻한 쪽)
profile('new_boy_down_idle.png', 'brand_profile_green.png', [88, 138, 74]);
profile('new_boy_down_idle.png', 'brand_profile_cream.png', [232, 206, 160]);
banner('1_village.png', 'brand_banner_village.png', 210, 630);
banner('1_greenhouse.png', 'brand_banner_field.png', 210, 630);
