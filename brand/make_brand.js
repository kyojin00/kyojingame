// 유튜브·스팀에 올릴 이미지를 게임 자산에서 뽑는다.
//
// 도트는 **최근접 확대**만 쓴다 — 보간해서 늘리면 픽셀이 뭉개져
// 도트 게임으로 안 보인다. 캐릭터는 정수배로만 키운다.
//
// 실행:  node make_brand.js        (pngjs 필요)
//   게임 스크린샷(game/1_*.png)이 있어야 한다:
//   KYOJIN_SHOT=1 godot --path game
const fs = require('fs'), { PNG } = require('pngjs');
const G = __dirname + '/../game/';
const OUT = __dirname + '/out/';
fs.mkdirSync(OUT, { recursive: true });

// 게임 팔레트에서 (잔디 어두운 쪽 / 흙 따뜻한 쪽)
const GREEN = [88, 138, 74], CREAM = [232, 206, 160];

const read = p => PNG.sync.read(fs.readFileSync(p));
const fill = (o, c) => {
  for (let i = 0; i < o.width * o.height; i++) {
    o.data[i * 4] = c[0]; o.data[i * 4 + 1] = c[1]; o.data[i * 4 + 2] = c[2]; o.data[i * 4 + 3] = 255;
  }
};
const save = (o, n, note) => {
  fs.writeFileSync(OUT + n, PNG.sync.write(o));
  console.log(`  ${n.padEnd(30)} ${o.width}x${o.height}  ${note}`);
};

// 실루엣 상자
function bbox(p, y0, y1) {
  const { width: W, height: H, data: D } = p;
  let l = W, r = -1, t = H, b = -1;
  for (let y = y0 !== undefined ? y0 : 0; y < (y1 !== undefined ? y1 : H); y++)
    for (let x = 0; x < W; x++) if (D[(y * W + x) * 4 + 3] >= 128) {
      if (x < l) l = x; if (x > r) r = x; if (y < t) t = y; if (y > b) b = y;
    }
  return { l, r, t, b, w: r - l + 1, h: b - t + 1 };
}

// 도트를 정수배로 찍어 넣는다
function blit(o, p, box, ox, oy, Z) {
  const { width: W, data: D } = p;
  for (let y = 0; y < box.h; y++) for (let x = 0; x < box.w; x++) {
    const si = ((box.t + y) * W + (box.l + x)) * 4; if (D[si + 3] < 128) continue;
    for (let dy = 0; dy < Z; dy++) for (let dx = 0; dx < Z; dx++) {
      const X = ox + x * Z + dx, Y = oy + y * Z + dy;
      if (X < 0 || Y < 0 || X >= o.width || Y >= o.height) continue;
      const di = (Y * o.width + X) * 4;
      o.data[di] = D[si]; o.data[di + 1] = D[si + 1]; o.data[di + 2] = D[si + 2];
    }
  }
}


// ---------------------------------------------------------------- 아이콘 (얼굴)
//
// 유튜브 프로필은 98px, 스팀 개발사 아이콘은 더 작게 나온다.
// **전신을 넣으면 아무것도 안 보인다** — 얼굴만 잘라 크게 쓴다.
function face(src, name, size, bg, note) {
  const p = read(G + 'assets/sprites/' + src);
  const full = bbox(p);
  const cutH = Math.round(full.h * 0.45);          // 머리~가슴께
  const box = bbox(p, full.t, full.t + cutH);
  box.t = full.t; box.h = cutH;
  const pad = Math.round(size * 0.07);
  const Z = Math.max(1, Math.floor((size - pad * 2) / Math.max(box.w, box.h)));
  const o = new PNG({ width: size, height: size });
  fill(o, bg);
  blit(o, p, box, Math.round((size - box.w * Z) / 2), Math.round((size - box.h * Z) / 2), Z);
  save(o, name, note);
}


// -------------------------------------------------------- 화면에서 오려 낸 그림
//
// 스크린샷에는 UI가 얹혀 있다 — 위는 미니맵·퀘스트창, 아래는 대사줄·소지품칸,
// 가운데는 말풍선. 쓸 수 있는 건 그 사이의 **빈 가로 띠**뿐이다.
//
// 띠 자리를 박아 두면 UI가 조금만 바뀌어도 말풍선이 캡슐 한가운데 박힌다
// (실제로 그랬다). 그래서 그림마다 **직접 찾는다** — UI 색(밝은 베이지 패널 ·
// 어두운 글자줄)이 거의 없는 행이 이어지는 구간 중 가장 긴 것.
//
// 캡슐은 **`1_clean.png`을 쓴다** — 하네스(224단계)가 UI를 다 끄고 찍어 둔
// 화면이라 통째로 쓸 수 있다. 다른 화면은 빈 띠가 100px대뿐이라 늘리면 흐릿해진다.
const CLEAN = {};
function cleanBand(shot) {
  if (CLEAN[shot]) return CLEAN[shot];
  const p = read(G + shot), { width: W, height: H, data: D } = p;
  // `_clean` 화면은 UI가 애초에 없다. 찾을 것도 없이 통째로 쓴다 —
  // 도트 그림은 간판·외곽선이 온통 UI 색과 겹쳐서, 그대로 재면
  // 멀쩡한 화면에서도 「빈 띠 140px」 같은 엉뚱한 답이 나온다.
  if (shot.includes('clean')) return (CLEAN[shot] = { a: 0, b: H });
  let best = { a: 0, b: 0 }, run = null;
  for (let y = 0; y < H; y += 4) {
    let ui = 0;
    for (let x = 0; x < W; x += 4) {
      const i = (y * W + x) * 4, r = D[i], g = D[i + 1], b = D[i + 2];
      if (r > 200 && g > 180 && b > 130 && b < 205) ui++;   // 패널·말풍선
      if (r < 70 && g < 70 && b < 70) ui++;                 // 글자줄·외곽선
    }
    if (ui / (W / 4) < 0.05) { if (!run) run = { a: y }; run.b = y; }
    else { if (run && run.b - run.a > best.b - best.a) best = run; run = null; }
  }
  if (run && run.b - run.a > best.b - best.a) best = run;
  if (best.b - best.a < 240)
    console.log(`  ! ${shot}: UI가 없는 띠가 ${best.b - best.a}px뿐이다 —`
      + ' 많이 늘려야 해서 흐릿해진다. UI 없는 화면을 따로 찍는 편이 낫다');
  return (CLEAN[shot] = best);
}

// 비어 있는 띠에서 목표 비율만큼 오려 낸다. 세로가 모자라면 **가로도 같이**
// 줄여 비율을 맞춘다 — 한쪽만 늘이면 캐릭터가 길어지고, 도트는 바로 티가 난다.
function crop(shot, name, W, H, opt) {
  const o2 = opt || {};
  const p = read(G + shot);
  const { width: SW, data: D } = p;
  const band = cleanBand(shot);
  const y0 = o2.y0 !== undefined ? o2.y0 : band.a;
  const y1 = o2.y1 !== undefined ? o2.y1 : band.b;
  let bh = y1 - y0, bw = Math.round(bh * W / H);
  if (bw > SW) { bw = SW; bh = Math.round(bw * H / W); }      // 가로가 모자라면 세로를 줄인다
  const x0 = Math.round((SW - bw) * (o2.ax !== undefined ? o2.ax : 0.5));
  const yy = y0 + Math.round((y1 - y0 - bh) * (o2.ay !== undefined ? o2.ay : 0.5));
  const o = new PNG({ width: W, height: H });
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const sx = x0 + Math.min(bw - 1, Math.floor(x * bw / W));
    const sy = yy + Math.min(bh - 1, Math.floor(y * bh / H));
    const si = (sy * SW + sx) * 4, di = (y * W + x) * 4;
    o.data[di] = D[si]; o.data[di + 1] = D[si + 1]; o.data[di + 2] = D[si + 2]; o.data[di + 3] = 255;
  }
  save(o, name, `${shot} (${bw}x${bh} 오려서)`);
}


// -------------------------------------------------------------- 유튜브 배너
//
// 2048x1152로 올리지만 **가운데 1235x338만 어디서나 보인다.**
// TV에서는 전체가, 휴대폰에서는 그 가운데만 나온다. 글자나 캐릭터를
// 가장자리에 두면 휴대폰에서 잘려 나간다 — 안전 구역을 표시해 둔다.
function ytBanner(shot, name) {
  const W = 2048, H = 1152, SW = 1235, SH = 338;
  const p = read(G + shot);
  const { width: PW, data: D } = p;
  const o = new PNG({ width: W, height: H });
  fill(o, [26, 32, 24]);
  // 안전 구역에 게임 화면을 채운다
  const band = cleanBand(shot);
  const bh = band.b - band.a, bw = Math.min(PW, Math.round(bh * SW / SH));
  const x0 = Math.round((PW - bw) / 2);
  const sx0 = Math.round((W - SW) / 2), sy0 = Math.round((H - SH) / 2);
  for (let y = 0; y < SH; y++) for (let x = 0; x < SW; x++) {
    const sx = x0 + Math.min(bw - 1, Math.floor(x * bw / SW));
    const sy = band.a + Math.min(bh - 1, Math.floor(y * bh / SH));
    const si = (sy * PW + sx) * 4, di = ((sy0 + y) * W + sx0 + x) * 4;
    o.data[di] = D[si]; o.data[di + 1] = D[si + 1]; o.data[di + 2] = D[si + 2];
  }
  save(o, name, `가운데 ${SW}x${SH}가 안전 구역`);
}


console.log('유튜브');
face('new_boy_down_idle.png', 'yt_profile_800.png', 800, GREEN, '프로필 (98px로 보인다)');
ytBanner('1_clean.png', 'yt_banner_2048.png');
crop('1_clean.png', 'yt_thumbnail_1280.png', 1280, 720, {});

console.log('스팀 — 캡슐 (상점·라이브러리에서 이 그림으로 게임을 알아본다)');
crop('1_clean.png', 'steam_header_460.png', 460, 215, {});      // 상점 페이지 위
crop('1_clean.png', 'steam_small_462.png', 462, 174, {});       // 검색 결과 줄
crop('1_clean.png', 'steam_main_616.png', 616, 353, {});        // 특집·추천
crop('1_clean.png', 'steam_vertical_374.png', 374, 448, {});    // 세로 캡슐
crop('1_clean.png', 'steam_library_600.png', 600, 900, {});     // 라이브러리 표지
crop('1_clean.png', 'steam_libhero_3840.png', 3840, 1240, {});  // 라이브러리 배경
crop('1_clean.png', 'steam_page_bg_1438.png', 1438, 810, {});   // 상점 배경

console.log('스팀 — 스크린샷 (1920x1080, 최소 5장. UI가 보여야 하므로 통째로)');
for (const [n, s] of [['1', '1_village.png'], ['2', '1_greenhouse.png'], ['3', '1_festival.png'],
    ['4', '1_weather_star.png'], ['5', '1_cave.png']]) {
  const p = read(G + s);
  const o = new PNG({ width: 1920, height: 1080 });
  for (let y = 0; y < 1080; y++) for (let x = 0; x < 1920; x++) {
    const sx = Math.min(p.width - 1, Math.floor(x * p.width / 1920));
    const sy = Math.min(p.height - 1, Math.floor(y * p.height / 1080));
    const si = (sy * p.width + sx) * 4, di = (y * 1920 + x) * 4;
    o.data[di] = p.data[si]; o.data[di + 1] = p.data[si + 1];
    o.data[di + 2] = p.data[si + 2]; o.data[di + 3] = 255;
  }
  save(o, `steam_ss_${n}.png`, s);
}

console.log('\n캡슐에는 **게임 이름을 크게 얹어야 한다** — 여기서 나온 건 바탕이다.');
console.log('스팀 심사는 이름 없는 캡슐을 반려한다.');
