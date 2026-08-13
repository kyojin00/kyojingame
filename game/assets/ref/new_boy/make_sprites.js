// 남자 캐릭터 스프라이트 생성기
//
// 원본: 걷기 영상에서 배경을 지운 1280x720 프레임 15장 (이 폴더의 *_walk_*.png / *_idle.png).
//   앞/옆/뒤 각각 걷기 4프레임 + 서기 1프레임.
//   한 번의 촬영에서 뽑았으므로 세 방향의 크기가 원본 단계에서 이미 같다.
//   -> 방향마다 따로 맞추지 않고 **모든 프레임에 같은 배율 하나**를 쓴다.
//      (방향별로 맞추면 원본에 없던 크기 차이를 오히려 만들어 낸다)
//
// 실행:  node make_sprites.js      (pngjs 필요)
const fs = require('fs'), { PNG } = require('pngjs');
const REF = __dirname + '/';
const OUT = __dirname + '/../../sprites/';

const FW = 128, FH = 192;   // 게임의 플레이어 스프라이트 규격
const FOOT_Y = 190;         // 땅에 닿은 발이 놓이는 행
const HEAD_H = 59.5;        // 앞머리 꼭대기 ~ 목 (크기 기준)

const SETS = [
	{ name: 'new_boy_down', files: ['down_walk_0', 'down_walk_1', 'down_walk_2', 'down_walk_3', 'down_idle'] },
	{ name: 'new_boy_side', files: ['side_walk_0', 'side_walk_1', 'side_walk_2', 'side_walk_3', 'side_idle'] },
	{ name: 'new_boy_up', files: ['up_walk_0', 'up_walk_1', 'up_walk_2', 'up_walk_3', 'up_idle'] },
];

// ---- 휘두르기(도끼질·곡괭이질) 3프레임 — 원본이 있으면 같이 뽑는다 ----
//
// 아직 이 폴더에 원본이 없다. 아래 이름으로 넣고 다시 돌리면 그대로 나온다.
//
//   <방향>_swing_0.png   다 감아올린 자세 — 도구가 어깨 뒤로 넘어가고 몸이 젖혀진 순간
//   <방향>_swing_1.png   내리치는 중간 — 도구가 얼굴 옆을 스치고 팔이 펴지는 순간
//   <방향>_swing_2.png   다 내리친 자세 — 도구가 발치에 닿고 허리가 굽은 순간
//
// (<방향> = down / side / up. 옆모습은 오른쪽을 보는 것만 찍으면 된다 —
//  왼쪽은 게임에서 좌우로 뒤집어 쓴다)
//
// **걷기 원본과 같은 촬영·같은 거리여야 한다.** 크기 기준(SCALE)은 걷기·서기
// 15장의 머리 크기 중앙값 하나뿐이라, 따로 찍어 거리가 다르면 휘두를 때만
// 캐릭터가 커졌다 작아진다.
//
// 세 장이 다 있어야 한 방향이 켜진다. 두 장만 넣으면 건너뛰고 알려 준다 —
// 반만 켜지면 게임에서 한 위상만 도트가 되고 나머지는 서기 자세로 튄다.
const SWING = ['swing_0', 'swing_1', 'swing_2'];
for (const set of SETS) {
	const dir = set.name.replace('new_boy_', '');
	const want = SWING.map(s => `${dir}_${s}`);
	const have = want.filter(f => fs.existsSync(REF + f + '.png'));
	if (have.length === want.length) set.files.push(...want);
	else if (have.length) console.warn(`! ${dir}: 휘두르기 원본이 ${have.length}/3장뿐 — 건너뛴다`);
}

// 출력 이름: 0~3 걷기 / 4 서기 / 5~7 휘두르기
const outName = (set, i) => i < 4 ? `${set.name}_walk_${i}`
	: (i === 4 ? `${set.name}_idle` : `${set.name}_swing_${i - 5}`);

const load = n => PNG.sync.read(fs.readFileSync(REF + n + '.png'));
const median = a => { const v = a.slice().sort((x, y) => x - y); return v[v.length >> 1]; };

// 실루엣에서 머리 꼭대기 / 목 / 발바닥을 잡는다
function scan(p) {
	const { width: W, height: H, data: D } = p;
	const rw = []; let y0 = -1, y1 = -1;
	for (let y = 0; y < H; y++) {
		let l = 1e9, r = -1;
		for (let x = 0; x < W; x++) if (D[((y * W + x) * 4) + 3] >= 128) { if (x < l) l = x; if (x > r) r = x; }
		rw[y] = r < 0 ? 0 : r - l + 1;
		if (r >= 0) { if (y0 < 0) y0 = y; y1 = y; }
	}
	const maxW = Math.max(...rw);
	// 삐친 머리(아호게)는 얇아서 건너뛰고, 앞머리 덩어리가 시작하는 행을 머리 꼭대기로 본다
	let hairTop = y0;
	for (let y = y0; y <= y1; y++) if (rw[y] >= maxW * 0.55) { hairTop = y; break; }
	// 목: 머리 아래 28~52% 구간에서 실루엣이 가장 좁아지는 행
	const a = hairTop + Math.round((y1 - hairTop) * 0.28), b = hairTop + Math.round((y1 - hairTop) * 0.52);
	let neck = a, nw = 1e9;
	for (let y = a; y <= b; y++) if (rw[y] < nw) { nw = rw[y]; neck = y; }
	return { y0, y1, hairTop, headH: neck - hairTop + 1 };
}

// 허리(반바지) 띠의 무게중심 x — 걷는 동안 가장 덜 흔들리는 기준점
function hipX(p, m) {
	const { width: W, data: D } = p;
	const a = m.hairTop + Math.round((m.y1 - m.hairTop) * 0.60);
	const b = m.hairTop + Math.round((m.y1 - m.hairTop) * 0.72);
	let sx = 0, n = 0;
	for (let y = a; y <= b; y++) for (let x = 0; x < W; x++) if (D[((y * W + x) * 4) + 3] >= 128) { sx += x; n++; }
	return n ? sx / n : W / 2;
}

// 출력 픽셀 하나 = 원본 박스 하나. 굵은 버킷의 최빈색으로 뽑아
// 안티에일리어싱 없이 도트의 단색 면을 그대로 살린다.
function sample(p, ax, ay, s, tx, ty) {
	const { width: W, height: H, data: D } = p;
	const sx0 = ax + (tx - 64) / s, sx1 = ax + (tx + 1 - 64) / s;
	const sy0 = ay + (ty - FOOT_Y) / s, sy1 = ay + (ty + 1 - FOOT_Y) / s;
	const ix0 = Math.max(0, Math.floor(sx0)), ix1 = Math.min(W - 1, Math.ceil(sx1) - 1);
	const iy0 = Math.max(0, Math.floor(sy0)), iy1 = Math.min(H - 1, Math.ceil(sy1) - 1);
	let tot = 0, op = 0; const bk = {};
	for (let y = iy0; y <= iy1; y++) for (let x = ix0; x <= ix1; x++) {
		tot++; const i = (y * W + x) * 4; if (D[i + 3] < 128) continue; op++;
		const k = ((D[i] >> 4) << 8) | ((D[i + 1] >> 4) << 4) | (D[i + 2] >> 4);
		const b = bk[k] || (bk[k] = [0, 0, 0, 0]);
		b[0] += D[i]; b[1] += D[i + 1]; b[2] += D[i + 2]; b[3]++;
	}
	if (tot === 0 || op / tot < 0.5) return null;
	let best = null;
	for (const k in bk) if (!best || bk[k][3] > best[3]) best = bk[k];
	return [Math.round(best[0] / best[3]), Math.round(best[1] / best[3]), Math.round(best[2] / best[3])];
}

// --- 1) 15장 전체를 재서 배율 하나를 정한다 ---
const imgs = {}, met = {};
for (const set of SETS) for (const f of set.files) { imgs[f] = load(f); met[f] = scan(imgs[f]); }
// 크기 기준은 **걷기·서기 15장으로만** 잡는다. 나중에 휘두르기 원본을
// 넣어도 이미 뽑아 둔 15장이 밀리지 않게 하려는 것이다.
const all = SETS.flatMap(s => s.files.slice(0, 5));
const SCALE = HEAD_H / median(all.map(f => met[f].headH));

// --- 2) 방향마다 바닥선을 정한다 (그 방향에서 발이 가장 낮게 닿는 프레임) ---
const jobs = [];
for (const set of SETS) {
	// 바닥선도 걷기·서기 5장으로만 정한다 (같은 이유)
	const ground = Math.max(...set.files.slice(0, 5).map(f => met[f].y1));
	set.files.forEach((f, i) => {
		const name = outName(set, i);
		const px = [];
		const ax = hipX(imgs[f], met[f]);
		for (let ty = 0; ty < FH; ty++) for (let tx = 0; tx < FW; tx++)
			px.push(sample(imgs[f], ax, ground, SCALE, tx, ty));
		jobs.push({ name, px });
	});
}

// --- 3) 15장이 같은 색을 쓰도록 팔레트를 한 번에 줄인다 (k-means) ---
const cols = []; jobs.forEach(j => j.px.forEach(c => { if (c) cols.push(c); }));
const seen = new Map();
for (const c of cols) { const k = (c[0] >> 3) + ',' + (c[1] >> 3) + ',' + (c[2] >> 3); seen.set(k, (seen.get(k) || 0) + 1); }
let cent = [...seen.entries()].sort((a, b) => b[1] - a[1]).slice(0, 28)
	.map(([k]) => k.split(',').map(v => parseInt(v) * 8 + 4));
for (let it = 0; it < 30; it++) {
	const acc = cent.map(() => [0, 0, 0, 0]);
	for (const c of cols) {
		let bi = 0, bd = 1e18;
		for (let i = 0; i < cent.length; i++) {
			const d = (c[0] - cent[i][0]) ** 2 + (c[1] - cent[i][1]) ** 2 + (c[2] - cent[i][2]) ** 2;
			if (d < bd) { bd = d; bi = i; }
		}
		acc[bi][0] += c[0]; acc[bi][1] += c[1]; acc[bi][2] += c[2]; acc[bi][3]++;
	}
	for (let i = 0; i < cent.length; i++) if (acc[i][3]) cent[i] = [0, 1, 2].map(j => Math.round(acc[i][j] / acc[i][3]));
}
const snap = c => {
	let bi = 0, bd = 1e18;
	for (let i = 0; i < cent.length; i++) {
		const d = (c[0] - cent[i][0]) ** 2 + (c[1] - cent[i][1]) ** 2 + (c[2] - cent[i][2]) ** 2;
		if (d < bd) { bd = d; bi = i; }
	}
	return cent[bi];
};

const outImgs = {};
for (const j of jobs) {
	const o = new PNG({ width: FW, height: FH }); o.data.fill(0);
	for (let i = 0; i < FW * FH; i++) {
		const c = j.px[i]; if (!c) continue; const q = snap(c);
		o.data[i * 4] = q[0]; o.data[i * 4 + 1] = q[1]; o.data[i * 4 + 2] = q[2]; o.data[i * 4 + 3] = 255;
	}
	fs.writeFileSync(OUT + j.name + '.png', PNG.sync.write(o));
	outImgs[j.name] = o;
}

// --- 4) 확인용 미리보기 ---
function preview(name, list) {
	const Z = 3, w = FW * list.length * Z, h = FH * Z, pv = new PNG({ width: w, height: h });
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		const im = outImgs[list[Math.floor(x / Z / FW)]];
		const sx = Math.floor(x / Z) % FW, sy = Math.floor(y / Z), si = (sy * FW + sx) * 4;
		const di = (y * w + x) * 4, chk = ((Math.floor(x / Z / 8) + Math.floor(y / Z / 8)) % 2) ? 58 : 38;
		const a = im.data[si + 3];
		pv.data[di] = a ? im.data[si] : chk; pv.data[di + 1] = a ? im.data[si + 1] : chk;
		pv.data[di + 2] = a ? im.data[si + 2] : chk; pv.data[di + 3] = 255;
	}
	fs.writeFileSync(REF + name, PNG.sync.write(pv));
}
preview('preview_idle.png', ['new_boy_down_idle', 'new_boy_side_idle', 'new_boy_up_idle']);
for (const d of ['down', 'side', 'up'])
	preview(`preview_${d}_walk.png`, [0, 1, 2, 3].map(i => `new_boy_${d}_walk_${i}`));
for (const set of SETS) if (set.files.length > 5) {
	const d = set.name.replace('new_boy_', '');
	preview(`preview_${d}_swing.png`, [0, 1, 2].map(i => `${set.name}_swing_${i}`));
}

console.log('frames', jobs.length, 'scale', SCALE.toFixed(4),
	'headH', all.map(f => met[f].headH).join(','), 'palette', cent.length);
