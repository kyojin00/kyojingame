#!/usr/bin/env python3
"""밤 브금을 길게 뽑는다 — 받은 31초짜리 두 곡으로 3분짜리 두 곡을 짠다.

받은 곡(`bgm_src/night_a.mp3`, `night_b.mp3`)은 각각 30.8초다. 게임에서
밤은 길게는 열 시간이 넘는데, 31초를 계속 되감으면 두 바퀴째부터
「아까 그 소절」만 들린다.

그렇다고 같은 31초를 그냥 여섯 번 이어 붙이면 길기만 할 뿐 똑같다.
그래서 **편곡을 한다** — 두 곡이 같은 조성·같은 빠르기라 서로 겹치고
주고받을 수 있다:

    ① 곡을 번갈아 낸다 (A -> B -> A ...). 이음매는 3초 크로스페이드라
       어디서 바뀌었는지 모르게 넘어간다.
    ② 절반 속도로 늘여 저역만 남긴 **패드**를 밑에 깐다. 한 옥타브 낮게
       느리게 흐르는 소리라, 같은 재료인데도 「다른 층」으로 들린다.
    ③ 구간마다 저역 필터·좌우 폭·크기를 달리 준다. 멀리서 들리는 절,
       가까이 오는 절, 둘이 겹치는 절.
    ④ 잔향을 옅게 깔아 이음매와 층을 붙여 준다.

두 결과물은 순서와 처리를 달리해서, 이어 들어도 같은 곡을 두 번 트는
것처럼 들리지 않게 했다.

실행:
    python3 game/assets/ref/make_night_bgm.py
    (ffmpeg 필요 — mp3를 풀고 ogg로 다시 굽는 데 쓴다)
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "bgm_src")
OUT = os.path.abspath(os.path.join(HERE, "..", "audio"))
TMP = "/tmp/kyojin_bgm"


# ---- 재료 읽고 쓰기 ----

def load_mp3(path):
    """mp3 -> (n, 2) float32. ffmpeg으로 풀어서 읽는다."""
    os.makedirs(TMP, exist_ok=True)
    wav = os.path.join(TMP, os.path.basename(path) + ".wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path,
                    "-ac", "2", "-ar", str(SR), "-c:a", "pcm_s16le", wav],
                   check=True)
    with wave.open(wav) as w:
        d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    return (d.astype(np.float32) / 32768.0).reshape(-1, 2)


def save_ogg(x, path, bitrate="64k"):
    """(n, 2) float32 -> ogg. 게임은 ogg를 그대로 읽는다.

    64kbps는 낮아 보이지만 이 프로젝트의 다른 브금이 그 언저리다
    (기존 밤 곡이 44kbps). 자산 덩치를 25MB로 줄여 놓은 판에
    3분짜리 두 곡으로 6MB를 더 얹을 수는 없다.
    """
    os.makedirs(TMP, exist_ok=True)
    wav = os.path.join(TMP, "out.wav")
    pcm = np.clip(x, -1.0, 1.0)
    with wave.open(wav, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((pcm * 32767.0).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav,
                    "-c:a", "libvorbis", "-b:a", bitrate, path], check=True)


# ---- 손질 ----

def lowpass_fft(x, hz, slope=2.0):
    """긴 소리는 주파수 쪽에서 깎는 편이 훨씬 빠르다 (되먹임이 없다).

    hz를 넘는 성분을 완만하게 줄인다. 자로 자른 듯 끊으면 종소리 같은
    울림(pre-ringing)이 생기므로 기울기를 두고 서서히 줄인다.
    """
    n = x.shape[0]
    f = np.fft.rfftfreq(n, 1.0 / SR).astype(np.float32)
    gain = 1.0 / (1.0 + (f / hz) ** (2.0 * slope)) ** 0.5
    out = np.empty_like(x)
    for c in range(x.shape[1]):
        out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c]) * gain, n)
    return out


def half_speed(x):
    """절반 속도 = 한 옥타브 아래. 길이는 두 배가 된다."""
    n = x.shape[0]
    idx = np.arange(n * 2, dtype=np.float32) * 0.5
    i0 = np.floor(idx).astype(np.int32)
    i1 = np.minimum(i0 + 1, n - 1)
    t = (idx - i0)[:, None]
    return x[i0] * (1.0 - t) + x[i1] * t


def width(x, amount):
    """좌우 폭. 1.0이 그대로, 크면 넓어지고 0이면 가운데로 모인다."""
    mid = (x[:, 0] + x[:, 1]) * 0.5
    side = (x[:, 0] - x[:, 1]) * 0.5 * amount
    return np.stack([mid + side, mid - side], axis=1)


def reverb(x, seconds=1.8, mix=0.22):
    """잔향 — 지수적으로 잦아드는 잡음을 겹쳐 만든다(합성곱).

    빗소리 같은 잡음이 아니라 「방의 울림」이다. 구간이 바뀌는 자리와
    층층이 쌓인 소리를 하나로 붙여 준다.
    """
    rng = np.random.default_rng(20260815)
    ln = int(SR * seconds)
    t = np.arange(ln, dtype=np.float32) / SR
    env = np.exp(-t * (5.0 / seconds)).astype(np.float32)
    # 앞부분은 비워 둔다 — 직접음 바로 뒤에 붙으면 소리가 탁해진다
    env[: int(SR * 0.02)] = 0.0
    n = x.shape[0] + ln - 1
    nfft = 1 << (n - 1).bit_length()
    out = np.empty_like(x)
    for c in range(x.shape[1]):
        ir = (rng.standard_normal(ln).astype(np.float32) * env)
        ir /= np.sqrt((ir ** 2).sum())
        wet = np.fft.irfft(np.fft.rfft(x[:, c], nfft) * np.fft.rfft(ir, nfft),
                           nfft)[: x.shape[0]]
        out[:, c] = x[:, c] * (1.0 - mix) + wet.astype(np.float32) * mix * 2.2
    return out


def fade(x, sec_in, sec_out):
    y = x.copy()
    ni = int(SR * sec_in)
    no = int(SR * sec_out)
    if ni > 0:
        y[:ni] *= np.linspace(0.0, 1.0, ni, dtype=np.float32)[:, None] ** 1.5
    if no > 0:
        y[-no:] *= np.linspace(1.0, 0.0, no, dtype=np.float32)[:, None] ** 1.5
    return y


def place(dst, src, at_sec, gain=1.0, xfade=0.0):
    """dst의 at_sec 자리에 src를 얹는다. xfade만큼 앞을 서서히 켠다."""
    at = int(SR * at_sec)
    n = min(src.shape[0], dst.shape[0] - at)
    if n <= 0:
        return
    seg = src[:n] * gain
    if xfade > 0.0:
        k = min(int(SR * xfade), n)
        # 등출력(equal power) — 선형으로 섞으면 이음매에서 소리가 옴폭 꺼진다
        seg = seg.copy()
        seg[:k] *= np.sin(np.linspace(0.0, np.pi / 2, k, dtype=np.float32))[:, None]
    dst[at:at + n] += seg


def normalize(x, peak=0.94, rms_target=0.19):
    """받은 곡과 같은 크기로 맞춘다 — 밤에만 소리가 커지면 안 된다."""
    rms = float(np.sqrt((x ** 2).mean()))
    if rms > 0:
        x = x * (rms_target / rms)
    p = float(np.abs(x).max())
    if p > peak:
        x = x * (peak / p)
    return x


# ---- 편곡 ----
#
# 한 절 = 원곡 한 바퀴(30.8초). 절마다 무엇을 어떻게 낼지만 적어 두고
# 아래 build가 그대로 짜 준다. gain은 배수, lp는 저역 필터 자르는 곳(Hz),
# w는 좌우 폭, pad는 밑에 깔 패드 크기.
#
#   A/B  받은 두 곡. 같은 조성이라 겹쳐도 부딪히지 않는다
#   -    쉬어 가는 절 (패드만 남는다)

PLAN_A = [
    # (곡, 크기, 저역필터, 폭, 패드)
    ("A", 1.00, 20000, 1.00, 0.00),   # 그대로 — 밤이 시작된다
    ("B", 0.95, 14000, 1.10, 0.00),   # 다른 곡으로 넘어간다
    ("A", 0.90, 9000, 1.15, 0.30),    # 밑에서 패드가 올라온다
    ("-", 0.40, 4200, 0.72, 0.40),    # 멀어진다 — 창문 너머로 들리듯
    ("B", 0.92, 12000, 1.20, 0.34),   # 다시 가까이
    ("A", 0.85, 16000, 1.00, 0.22),   # 잦아들며 끝
]
PLAN_B = [
    ("B", 1.00, 20000, 1.00, 0.00),
    ("A", 0.95, 15000, 1.05, 0.26),
    ("-", 0.42, 4600, 0.75, 0.38),
    ("B", 0.90, 10000, 1.18, 0.34),
    ("A", 0.93, 13000, 1.12, 0.28),
    ("B", 0.86, 17000, 1.00, 0.20),
]


TAIL = 5.0        # 마지막 절이 끝난 뒤 잔향이 잦아들 자리


def build(plan, a, b, pad_a, pad_b):
    step = a.shape[0] / SR - 2.6          # 절 사이 2.6초는 겹친다
    # 마지막 절은 step * (len-1) 자리에서 시작해 원곡 길이만큼 흐른다.
    # len으로 잡으면 뒤에 한 절만큼 빈 자리가 남아 곡이 중간에 끊긴 것처럼 된다.
    total = int(SR * (step * (len(plan) - 1) + a.shape[0] / SR + TAIL))
    out = np.zeros((total, 2), dtype=np.float32)
    for i, (which, gain, lp, w, padg) in enumerate(plan):
        at = step * i
        # 쉬어 가는 절("-")에도 원곡을 아주 옅게 깔아 둔다.
        # 패드만 남기면 저역만 웅웅거려 「브금이 끊겼나」 싶어진다 —
        # 창문 너머로 새어 드는 정도로만 남긴다.
        src = a if which == "A" else b
        seg = src if lp >= 19000 else lowpass_fft(src, lp)
        if abs(w - 1.0) > 0.01:
            seg = width(seg, w)
        place(out, seg, at, gain, 0.0 if i == 0 else 2.6)
        if padg > 0.0:
            pad = pad_a if which != "B" else pad_b
            place(out, pad[: int(SR * (step + 2.6))], at, padg, 2.6)
    return out


def main():
    a = load_mp3(os.path.join(SRC, "night_a.mp3"))
    b = load_mp3(os.path.join(SRC, "night_b.mp3"))
    print("재료: %.1f초 · %.1f초" % (a.shape[0] / SR, b.shape[0] / SR))

    # 패드 — 절반 속도로 늘이고 저역만 남긴다. 한 옥타브 아래에서
    # 느리게 흐르는 소리라, 같은 재료인데 다른 층으로 들린다.
    pad_a = width(lowpass_fft(half_speed(a), 700, slope=2.5), 1.35)
    pad_b = width(lowpass_fft(half_speed(b), 620, slope=2.5), 1.35)

    for name, plan in (("bgm_night2", PLAN_A), ("bgm_night3", PLAN_B)):
        mix = build(plan, a, b, pad_a, pad_b)
        mix = reverb(mix, seconds=2.0, mix=0.20)
        mix = fade(mix, 2.5, 7.0)
        mix = normalize(mix)
        path = os.path.join(OUT, name + ".ogg")
        save_ogg(mix, path)
        print("%s  %.1f초  %.1fKB" % (name, mix.shape[0] / SR,
                                      os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
