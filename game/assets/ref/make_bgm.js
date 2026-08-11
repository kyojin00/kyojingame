// 배경음 생성기 — 22050Hz 16비트 모노 WAV.
//
// 예전에는 계절 네 곡이 각각 15~24초였다. 몇 시간을 도는 게임에서 20초
// 루프는 사람을 지치게 만든다. 여기서는 곡마다 1~2분 반이고, 마디를
// A-B-A-C 같은 단락으로 묶어 안에서도 같은 자리가 잘 안 돌아온다.
//
// 이음매: **모든 쓰기를 버퍼 길이로 감는다**(i % N). 그래서 끝에서 울리던
// 소리가 앞으로 넘어와 이어진다 — 루프 지점에서 뚝 끊기지 않는다.
//
// 실행:  node make_bgm.js        (외부 라이브러리 없음)
const fs = require('fs');
const OUT = __dirname + '/../audio/';
const SR = 22050;

// ---- 흔들리지 않는 난수 (곡마다 씨앗 하나) ----
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}

// ---- 음이름 -> 주파수 ----
// 0 = C4. 반음 단위.
const midiHz = (n) => 261.625565 * Math.pow(2, n / 12);

// 음계 (반음 간격). 자연스러운 것만 쓴다 — 우연에 맡기면 금방 불협이 난다.
const SCALES = {
  major: [0, 2, 4, 5, 7, 9, 11],
  minor: [0, 2, 3, 5, 7, 8, 10],
  dorian: [0, 2, 3, 5, 7, 9, 10],
  pentaMajor: [0, 2, 4, 7, 9],
  pentaMinor: [0, 3, 5, 7, 10],
};

// ---- 파형 ----
function wave(kind, ph, rnd) {
  switch (kind) {
    case 'sine': return Math.sin(ph * Math.PI * 2);
    case 'tri': { const t = ph % 1; return 4 * Math.abs(t - 0.5) - 1; }
    case 'square': return (ph % 1) < 0.5 ? 1 : -1;
    case 'pulse': return (ph % 1) < 0.25 ? 1 : -1;
    case 'saw': return 2 * (ph % 1) - 1;
    case 'noise': return rnd() * 2 - 1;
  }
  return 0;
}

// 한 음을 버퍼에 더한다. 인덱스는 버퍼 길이로 감는다 (이음매 없음).
function note(buf, startSec, durSec, hz, opt) {
  const o = Object.assign({
    kind: 'tri', vol: 0.2, atk: 0.01, dec: 0.08, sus: 0.7, rel: 0.18,
    vib: 0, vibHz: 5, glide: 0, rnd: Math.random,
  }, opt);
  const N = buf.length;
  const i0 = Math.round(startSec * SR);
  const total = Math.round((durSec + o.rel) * SR);
  const atkN = Math.max(1, o.atk * SR), decN = Math.max(1, o.dec * SR);
  const relN = Math.max(1, o.rel * SR), holdN = Math.round(durSec * SR);
  let ph = 0;
  for (let i = 0; i < total; i++) {
    const t = i / SR;
    // 포락선 — 여리게 들어와 붙어 있다 사그라진다
    let env;
    if (i < atkN) env = i / atkN;
    else if (i < atkN + decN) env = 1 - (1 - o.sus) * ((i - atkN) / decN);
    else if (i < holdN) env = o.sus;
    else env = o.sus * Math.max(0, 1 - (i - holdN) / relN);
    if (env <= 0) continue;
    let f = hz;
    if (o.glide) f = hz * Math.pow(2, (o.glide * (1 - Math.min(1, t / 0.06))) / 12);
    if (o.vib) f *= 1 + o.vib * Math.sin(t * Math.PI * 2 * o.vibHz) * Math.min(1, t / 0.25);
    ph += f / SR;
    buf[(i0 + i) % N] += wave(o.kind, ph, o.rnd) * env * o.vol;
  }
}

// 타악 — 짧게 깎아 낸 소리
function perc(buf, startSec, kind, vol, rnd) {
  const N = buf.length;
  const i0 = Math.round(startSec * SR);
  if (kind === 'kick') {
    const n = Math.round(0.14 * SR);
    let ph = 0;
    for (let i = 0; i < n; i++) {
      const t = i / n;
      ph += (110 * Math.pow(2, -3.2 * t)) / SR;
      buf[(i0 + i) % N] += Math.sin(ph * Math.PI * 2) * (1 - t) * (1 - t) * vol;
    }
  } else if (kind === 'hat') {
    const n = Math.round(0.035 * SR);
    for (let i = 0; i < n; i++) {
      const t = i / n;
      buf[(i0 + i) % N] += (rnd() * 2 - 1) * Math.pow(1 - t, 3) * vol * 0.5;
    }
  } else if (kind === 'snare') {
    const n = Math.round(0.11 * SR);
    for (let i = 0; i < n; i++) {
      const t = i / n;
      const noise = (rnd() * 2 - 1) * Math.pow(1 - t, 2.2);
      const body = Math.sin((i / SR) * Math.PI * 2 * 190) * Math.pow(1 - t, 5);
      buf[(i0 + i) % N] += (noise * 0.7 + body * 0.5) * vol;
    }
  }
}

// 메아리 — 감아서 더하면 루프 끝에서도 끊기지 않는다
function echo(buf, delaySec, fb, mix) {
  const N = buf.length, d = Math.round(delaySec * SR);
  const src = Float32Array.from(buf);
  for (let k = 1; k <= 3; k++) {
    const g = mix * Math.pow(fb, k);
    if (g < 0.01) break;
    for (let i = 0; i < N; i++) buf[(i + d * k) % N] += src[i] * g;
  }
}

// 한 극 저역통과 — 사각파의 날을 눌러 준다
function lowpass(buf, hz) {
  const a = Math.exp(-2 * Math.PI * hz / SR);
  let y = 0;
  // 두 바퀴 돌려 시작점 상태를 맞춘다 (그래야 앞머리가 안 튄다)
  for (let pass = 0; pass < 2; pass++)
    for (let i = 0; i < buf.length; i++) { y = (1 - a) * buf[i] + a * y; buf[i] = y; }
}

// 직류 성분 빼기 — 사각파(펄스)는 위아래가 안 맞아서 파형이 통째로
// 한쪽에 치우친다. 그대로 두면 여유 폭을 까먹고 루프 지점에서 툭 튄다.
function dcBlock(buf) {
  const R = 0.9985;
  let x1 = 0, y1 = 0;
  for (let pass = 0; pass < 2; pass++) {   // 두 바퀴 — 시작 상태를 맞춘다
    for (let i = 0; i < buf.length; i++) {
      const x = buf[i];
      y1 = x - x1 + R * y1;
      x1 = x;
      buf[i] = y1;
    }
  }
}

// 이음매 다듬기 — 끝 몇 밀리초를 처음 값 쪽으로 끌어당긴다.
// 감아 더하기(i % N)로 소리는 이어지지만, 표본 하나짜리 단차는 남는다.
function seamFix(buf) {
  const n = Math.round(SR * 0.004);        // 4ms
  const gap = buf[0] - buf[buf.length - 1];
  for (let i = 0; i < n; i++) {
    const w = (i + 1) / n;                 // 끝으로 갈수록 강하게
    buf[buf.length - n + i] += gap * w * 0.5;
  }
}

function save(name, buf) {
  dcBlock(buf);
  seamFix(buf);
  // 부드럽게 눌러 담는다 (자르면 지직거린다)
  let peak = 0;
  for (const v of buf) peak = Math.max(peak, Math.abs(v));
  const g = peak > 0 ? 0.95 / peak : 1;
  const data = Buffer.alloc(buf.length * 2);
  for (let i = 0; i < buf.length; i++) {
    // 0.7까지는 그대로 두고 그 위만 눌러 준다 (전체 tanh는 소리를 죽인다)
    const v = buf[i] * g;
    const a = Math.abs(v);
    const x = a <= 0.7 ? v : Math.sign(v) * (0.7 + Math.tanh((a - 0.7) * 3) / 3);
    data.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(x * 32767))), i * 2);
  }
  const head = Buffer.alloc(44);
  head.write('RIFF', 0); head.writeUInt32LE(36 + data.length, 4); head.write('WAVE', 8);
  head.write('fmt ', 12); head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22); head.writeUInt32LE(SR, 24); head.writeUInt32LE(SR * 2, 28);
  head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34);
  head.write('data', 36); head.writeUInt32LE(data.length, 40);
  fs.writeFileSync(OUT + name + '.wav', Buffer.concat([head, data]));
  console.log('%s  %ds', name, Math.round(buf.length / SR));
}

// ---- 곡 짜기 ----
//
// 마디마다 화음이 하나 있고, 단락(A/B/C)은 그 화음 묶음을 가리킨다.
// 가락은 「두 마디짜리 씨앗을 만들어 조금씩 바꿔 되풀이한다」 —
// 매 마디 새로 뽑으면 사람이 흥얼거릴 수가 없다.

function buildSong(cfg) {
  const rnd = rng(cfg.seed);
  const spb = 60 / cfg.bpm;              // 한 박
  const beats = cfg.beats || 4;          // 한 마디 박 수
  const barSec = spb * beats;
  const bars = cfg.form.reduce((n, s) => n + cfg.sections[s].length, 0);
  const N = Math.round(bars * barSec * SR);
  const buf = new Float32Array(N);
  const scale = SCALES[cfg.scale];
  const root = cfg.root;

  // 음계 계단 -> 반음. 옥타브를 넘어가면 감아 올린다
  const deg = (d) => {
    const oct = Math.floor(d / scale.length);
    return root + scale[((d % scale.length) + scale.length) % scale.length] + 12 * oct;
  };

  // 두 마디짜리 가락 씨앗 — [계단, 길이(박)] 짝
  function motif() {
    const out = [];
    let t = 0, d = cfg.melodyBase || 4;
    const steps = [-2, -1, -1, 0, 1, 1, 2, 3];
    while (t < beats * 2) {
      const len = [0.5, 0.5, 1, 1, 1, 1.5, 2][Math.floor(rnd() * 7)];
      if (rnd() < 0.12) { out.push([null, len]); t += len; continue; }   // 쉼
      d += steps[Math.floor(rnd() * steps.length)];
      d = Math.max(cfg.lo || 0, Math.min(cfg.hi || 11, d));
      out.push([d, Math.min(len, beats * 2 - t)]);
      t += len;
    }
    return out;
  }
  const motifs = [motif(), motif(), motif()];

  let bar = 0;
  for (const secName of cfg.form) {
    const sec = cfg.sections[secName];
    for (let b = 0; b < sec.length; b++) {
      const t0 = bar * barSec;
      const ch = sec[b];                       // [화음 뿌리 계단, 3화음 여부]
      const chordDeg = ch[0];
      const tones = [chordDeg, chordDeg + 2, chordDeg + 4];

      // 저음 — 뿌리를 두 옥타브 아래로
      for (let k = 0; k < beats; k += 2) {
        note(buf, t0 + k * spb, spb * 1.6, midiHz(deg(chordDeg) - 24), {
          kind: 'tri', vol: 0.34, atk: 0.005, dec: 0.12, sus: 0.55, rel: 0.2, rnd,
        });
      }
      // 화음 깔개 — 아주 여리게
      for (const tn of tones) {
        note(buf, t0, barSec * 0.92, midiHz(deg(tn) - 12), {
          kind: cfg.padKind || 'square', vol: 0.055, atk: 0.12, dec: 0.3,
          sus: 0.6, rel: 0.4, rnd,
        });
      }
      // 아르페지오 — 마디를 굴려 준다
      if (cfg.arp) {
        for (let k = 0; k < beats * 2; k++) {
          const tn = tones[k % 3];
          note(buf, t0 + k * spb * 0.5, spb * 0.42, midiHz(deg(tn)), {
            kind: 'pulse', vol: 0.055, atk: 0.004, dec: 0.05, sus: 0.35, rel: 0.08, rnd,
          });
        }
      }
      // 타악
      if (cfg.drums) {
        for (let k = 0; k < beats; k++) {
          if (k % 2 === 0) perc(buf, t0 + k * spb, 'kick', 0.5, rnd);
          else if (cfg.snare) perc(buf, t0 + k * spb, 'snare', 0.26, rnd);
          perc(buf, t0 + k * spb, 'hat', 0.14, rnd);
          if (cfg.hat8) perc(buf, t0 + (k + 0.5) * spb, 'hat', 0.09, rnd);
        }
      }
      // 가락 — 두 마디 씨앗을 단락마다 조금 옮겨 되풀이한다
      if (secName !== 'quiet') {
        const m = motifs[(bar >> 1) % motifs.length];
        const shift = ((bar >> 1) % 4 === 3) ? 1 : 0;   // 네 번째 되풀이만 살짝 비튼다
        let t = (bar % 2) * beats;
        let acc = t0 - (bar % 2) * barSec;
        for (const [d, len] of m) {
          const nt = t;
          t += len;
          if (nt < (bar % 2) * beats || nt >= (bar % 2 + 1) * beats) continue;
          if (d === null) continue;
          note(buf, acc + nt * spb, spb * len * 0.92, midiHz(deg(d + shift)), {
            kind: cfg.leadKind || 'tri', vol: 0.24, atk: 0.012, dec: 0.1,
            sus: 0.72, rel: 0.22, vib: 0.006, vibHz: 5.2, rnd,
          });
        }
      }
      bar++;
    }
  }

  if (cfg.echo) echo(buf, barSec / beats * (cfg.echoBeats || 1.5), 0.45, cfg.echo);
  lowpass(buf, cfg.tone || 5200);
  return buf;
}

// ---- 곡 목록 ----
// 화음은 음계 계단으로 적는다: 0=I 1=ii 2=iii 3=IV 4=V 5=vi
const A = [[0], [3], [4], [0]];        // I  IV V  I
const B = [[5], [3], [0], [4]];        // vi IV I  V
const C = [[3], [4], [5], [3]];        // IV V  vi IV
const D = [[0], [5], [3], [4]];        // I  vi IV V

const SONGS = [
  { name: 'bgm_spring', seed: 101, bpm: 108, scale: 'major', root: 0,
    form: ['A', 'B', 'A', 'C', 'A', 'B', 'D', 'A',
      'A', 'C', 'B', 'A', 'D', 'B', 'C', 'A'],
    sections: { A, B, C, D }, drums: true, hat8: true, arp: true,
    lo: 2, hi: 13, echo: 0.16, tone: 5600 },
  { name: 'bgm_summer', seed: 202, bpm: 126, scale: 'major', root: 7,
    form: ['A', 'D', 'B', 'A', 'C', 'D', 'A', 'B',
      'D', 'A', 'C', 'B', 'A', 'D', 'B', 'A'],
    sections: { A, B, C, D }, drums: true, snare: true, hat8: true, arp: true,
    lo: 2, hi: 14, leadKind: 'pulse', echo: 0.12, tone: 6000 },
  { name: 'bgm_fall', seed: 303, bpm: 94, scale: 'dorian', root: 9,
    form: ['A', 'B', 'A', 'C', 'B', 'D', 'A', 'B',
      'C', 'A', 'D', 'B'],
    sections: { A, B, C, D }, drums: true, arp: false,
    lo: 0, hi: 11, echo: 0.22, tone: 4200 },
  { name: 'bgm_winter', seed: 404, bpm: 74, scale: 'minor', root: 2,
    form: ['A', 'quiet', 'B', 'A', 'C', 'quiet', 'B', 'A', 'C', 'B'],
    sections: { A, B, C, quiet: A }, drums: false, arp: true,
    lo: 0, hi: 10, padKind: 'tri', echo: 0.3, echoBeats: 3, tone: 3400 },
  { name: 'bgm_village', seed: 505, bpm: 104, scale: 'major', root: 5, beats: 3,
    form: ['A', 'B', 'A', 'C', 'A', 'D', 'B', 'A', 'C', 'D', 'A', 'B'],
    sections: { A, B, C, D }, drums: true, arp: true,
    lo: 2, hi: 12, echo: 0.14, tone: 5000 },
  { name: 'bgm_cave', seed: 606, bpm: 82, scale: 'minor', root: 4,
    form: ['A', 'quiet', 'B', 'quiet', 'C', 'B', 'A', 'C', 'quiet', 'B'],
    sections: { A, B, C, quiet: A }, drums: true, arp: false,
    lo: -2, hi: 8, padKind: 'saw', leadKind: 'sine', echo: 0.34, echoBeats: 3, tone: 2600 },
  { name: 'bgm_night', seed: 707, bpm: 68, scale: 'minor', root: 9,
    form: ['A', 'quiet', 'B', 'A', 'quiet', 'C', 'B', 'quiet', 'A', 'C'],
    sections: { A, B, C, quiet: A }, drums: false, arp: true,
    lo: 0, hi: 10, padKind: 'tri', leadKind: 'sine', echo: 0.3, echoBeats: 3, tone: 3000 },
  { name: 'bgm_shop', seed: 808, bpm: 130, scale: 'major', root: 0,
    form: ['A', 'D', 'A', 'B', 'D', 'A', 'B', 'A'],
    sections: { A, B, D }, drums: true, snare: true, hat8: true, arp: true,
    lo: 4, hi: 15, leadKind: 'pulse', echo: 0.1, tone: 6200 },
  { name: 'bgm_festival', seed: 909, bpm: 142, scale: 'major', root: 7,
    form: ['A', 'B', 'D', 'A', 'C', 'B', 'D', 'A', 'B', 'C'],
    sections: { A, B, C, D }, drums: true, snare: true, hat8: true, arp: true,
    lo: 4, hi: 16, leadKind: 'square', echo: 0.1, tone: 6400 },
  { name: 'bgm_title', seed: 111, bpm: 86, scale: 'major', root: 2,
    form: ['quiet', 'A', 'B', 'C', 'A', 'D', 'B', 'quiet', 'C', 'A'],
    sections: { A, B, C, D, quiet: A }, drums: false, arp: true,
    lo: 0, hi: 12, padKind: 'tri', echo: 0.28, echoBeats: 3, tone: 4600 },
];

let total = 0;
for (const cfg of SONGS) {
  const buf = buildSong(cfg);
  save(cfg.name, buf);
  total += buf.length / SR;
}
console.log('합계 %d초 / %d곡', Math.round(total), SONGS.length);
