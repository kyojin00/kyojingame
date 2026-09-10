# -*- coding: utf-8 -*-
# 새 주인공 — **애니 그림체(6등신)**. 참고로 받은 은발 소녀 초상의 결을 따른다.
#
# 앞판(make_pc.py)은 3등신 치비였다. 「그림체가 완전 다르다」는 말이 맞다 —
# 참고 그림은 머리가 키의 1/6쯤인 애니 그림체다. 여기서는 등신부터 맞춘다.
#
#   머리 42x48 (키의 26%) · 목 · 어깨 y=60 · 허리 y=104 · 엉덩이 y=112 · 발 y=190
#
# 얼굴이 42px 폭이면 눈 하나에 13x10 을 줄 수 있다. 그 크기면 애니 눈이 그려진다 —
# 위 속눈썹을 두껍게, 홍채는 위가 짙고 아래로 갈수록 밝게, 흰 반짝이 하나,
# 눈꼬리에 흰자. 눈 색은 **팔레트 표에 없는 고정색**이라(윤곽선·눈썹과 같은 취급)
# 몇 가지 더 써도 옷 갈아입기에 지장이 없다.
#
# 빛 계산(구·원기둥·원뿔에 빛을 쏘아 색 띠로 끊기)은 make_pc.py 것을 그대로 쓴다.
import math
import os
from PIL import Image

from make_pc import Canvas, PAL, RAMP, CUT, _norm, L, W, H, GROUND

# 눈에만 쓰는 고정색 — APPEAR 표에 없으므로 실행 중에 안 바뀐다
PAL = dict(PAL)
PAL.update({
    'e': (58, 38, 44),        # 속눈썹 · 눈 테
    'e1': (104, 66, 70),      # 속눈썹 가장자리 (계단 눅이기)
    'i': (96, 48, 34),        # 홍채 위 (짙은)
    'i1': (146, 78, 44),      # 홍채 가운데
    'i2': (198, 132, 78),     # 홍채 아래 (빛이 도는 쪽)
    'w': (246, 242, 234),     # 반짝이
    'w1': (214, 206, 202),    # 흰자 그늘
    'br': (120, 72, 44),      # 눈썹
})

# ---- 등신 ----
HEAD_CX, HEAD_CY = 64, 34
HEAD_RX, HEAD_RY = 21, 24            # 머리 42x48
NECK_Y, SH_Y = 58, 62
WAIST_Y, HIP_Y = 104, 112
HEM_Y = 138                          # 치마 밑단 · 반바지 밑단
KNEE_Y, BOOT_Y = 156, 172

# 애니 눈 13x10 — 위 속눈썹이 두껍고 바깥으로 갈수록 처진다.
# 홍채는 위가 짙고 아래로 갈수록 밝다. 반짝이는 위쪽에 하나, 아래에 작은 것 하나.
# 홍채가 눈을 꽉 채우면 선글라스로 보인다 — **눈꼬리 양쪽에 흰자**를 두고
# 홍채는 가운데 일곱 칸만. 위 속눈썹은 두 줄로 두껍게, 아래는 한 줄 여린 색.
# 홍채는 위가 짙고 아래로 갈수록 밝다(빛이 뒤에서 통과한 것처럼).
# **세로로 긴** 눈이라야 애니 눈이다. 가로로 넓게 잡고 눈망울 둘레를 검게 두르면
# 안경이 된다 (13x9 로 그렸다가 정말 안경으로 보였다).
# 왼눈 기준 — 바깥(왼쪽)에 속눈썹이 두껍고, 안쪽(오른쪽)은 흰자 한 칸으로 끝난다.
EYE = [
    '..eeeee..',
    '.eeeeeee.',
    'eeiiiiiWe',
    'eWwwiiiiW',
    'eWwwii11W',
    'eWiii122W',
    'eWi11222W',
    'eW112w22W',
    '.E222222W',
    '..EEEEE..',
]
EYE_KEY = {'e': 'e', 'E': 'e1', 'W': 'w1', 'i': 'i', '1': 'i1', '2': 'i2',
           'w': 'w', '.': None}
EYE_W, EYE_H = 9, 10

LID = [                              # 감은 눈 — 아래로 굽은 속눈썹
    'ee.......ee',
    '.eeeeeeeee.',
    '..eeeeeee..',
]
BROW = ['..bbbbb..', 'bbb.....b']


def stamp_eye(c, x0, y0, flip=False):
    for dy, row in enumerate(EYE):
        r = row[::-1] if flip else row
        for dx, ch in enumerate(r):
            key = EYE_KEY.get(ch)
            if key:
                c.hard(x0 + dx, y0 + dy, key)


def stamp(c, rows, x0, y0, flip=False, keymap=None):
    for dy, row in enumerate(rows):
        r = row[::-1] if flip else row
        for dx, ch in enumerate(r):
            if ch == '.':
                continue
            c.hard(x0 + dx, y0 + dy, (keymap or {}).get(ch, ch))


STYLES = {
    'a': {'name': '단발 소녀', 'hair': 'bob', 'bottom': 'skirt', 'top': 'vest'},
    'b': {'name': '긴머리 소녀', 'hair': 'long', 'bottom': 'skirt', 'top': 'apron'},
    'c': {'name': '소년', 'hair': 'short', 'bottom': 'pants', 'top': 'tee'},
}


def face(c, view, cx, blink=False):
    ey = HEAD_CY + 1                                   # 눈은 머리 한가운데쯤
    if view == 'side':
        ex = cx + 5
        if blink:
            stamp(c, LID, ex, ey + 4, keymap={'e': 'e'})
        else:
            stamp_eye(c, ex, ey)
        for x in range(cx + 10, cx + 13):              # 입
            c.hard(x, HEAD_CY + 15, 'm')
        for y in range(HEAD_CY + 9, HEAD_CY + 12):     # 볼
            for x in range(cx - 1, cx + 5):
                c.hard(x, y, 'r')
        return
    gap = 5
    lx, rx = cx - gap // 2 - EYE_W, cx + gap // 2 + 1
    if blink:
        stamp(c, LID, lx + 1, ey + 4, keymap={'e': 'e'})
        stamp(c, LID, rx + 1, ey + 4, keymap={'e': 'e'})
    else:
        stamp_eye(c, lx, ey)
        stamp_eye(c, rx, ey, flip=True)
    c.hard(cx - 1, HEAD_CY + 11, 'm')                  # 코 그늘
    for x in range(cx - 2, cx + 3):                    # 입 — 작게
        c.hard(x, HEAD_CY + 16, 'm')
    for y in (HEAD_CY + 13, HEAD_CY + 14):             # 볼터치 — 눈에서 떨어뜨린다
        for x in range(lx - 1, lx + 4):
            c.hard(x, y, 'r')
        for x in range(rx + EYE_W - 4, rx + EYE_W + 1):
            c.hard(x, y, 'r')


def brows(c, view, cx):
    """눈썹은 앞머리 **위에** 얹는다 — 애니 얼굴은 앞머리 사이로 눈썹이 비친다.
    머리 밑에 두면 통째로 가려져 표정이 사라진다."""
    ey = HEAD_CY + 1
    if view == 'side':
        stamp(c, BROW, cx + 5, ey - 5, keymap={'b': 'br'})
        return
    gap = 5
    lx, rx = cx - gap // 2 - EYE_W, cx + gap // 2 + 1
    stamp(c, BROW, lx, ey - 5, keymap={'b': 'br'})
    stamp(c, BROW, rx, ey - 5, flip=True, keymap={'b': 'br'})


def hair(c, st, view, cx):
    kind = st['hair']
    tips = {'bob': [(-0.72, 12), (-0.32, 8), (0.06, 13), (0.44, 9), (0.80, 12)],
            'long': [(-0.76, 13), (-0.36, 9), (0.02, 14), (0.42, 10), (0.78, 13)],
            'short': [(-0.68, 9), (-0.26, 13), (0.18, 8), (0.62, 12)]}[kind]
    side_to = {'bob': HEAD_CY + 24, 'long': HEAD_CY + 22, 'short': HEAD_CY + 2}[kind]

    def keep(x, y):
        u = (x - cx) / float(HEAD_RX + 2)
        top = HEAD_CY - HEAD_RY - 2
        deep = max([dv - abs(u - t) * 26 for t, dv in tips] + [0.0])
        if view == 'side' and u > 0.30:
            deep = max(0.0, deep - 3)
        if y < top + 16 + deep:
            return True
        return abs(u) > 0.66 and y < side_to           # 옆머리

    c.sphere(cx, HEAD_CY, HEAD_RX + 2, HEAD_RY + 2, 'hair', gain=0.80, bias=0.14, mask=keep)
    # 곡면을 따라 도는 가는 윤기 활
    for y in range(HEAD_CY - HEAD_RY - 2, HEAD_CY + 4):
        for x in range(cx - HEAD_RX - 2, cx + HEAD_RX + 3):
            if c.at(x, y) != 'hair':
                continue
            u, v = (x - cx) / float(HEAD_RX + 2), (y - HEAD_CY) / float(HEAD_RY + 2)
            d = math.sqrt(u * u + v * v)
            if abs(d - 0.72) < 0.11 and v < -0.20 and -0.85 < u < 0.50:
                c.lit[y][x] = min(1.0, c.lit[y][x] + 0.34)
    if kind == 'long':                                  # 등까지 흐르는 머리채
        sides = (-1, 1) if view != 'side' else (-1,)
        for d in sides:
            for y in range(HEAD_CY - 4, HIP_Y - 4):
                t = (y - (HEAD_CY - 4)) / float(HIP_Y - 4 - HEAD_CY + 4)
                wd = 11 - 5 * t * t
                base = cx + d * (HEAD_RX - 3 + int(4 * t * t))
                for k in range(int(round(wd))):
                    u = (k / wd) * 2 - 1
                    nz = math.sqrt(max(0.0, 1 - u * u))
                    n = _norm([u * d, -0.2, nz])
                    lit = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
                    c.put(base + d * k, y, 'hair', min(1.0, lit * 0.9 + 0.12))


def body(c, st, view):
    cx = 64 if view != 'side' else 65
    half = 15 if view != 'side' else 11                  # 어깨 반폭
    c.tube(cx, NECK_Y - 4, cx, NECK_Y + 3, 9, 9, 'skin', gain=0.8, bias=0.28)
    c.tube(cx, SH_Y, cx, WAIST_Y, half * 2, half * 2 - 5, 'shirt', gain=1.0, bias=0.16)
    c.sphere(cx, SH_Y + 4, half, 6, 'shirt', gain=1.0, bias=0.16)
    if st['top'] == 'apron':
        for y in range(SH_Y + 6, WAIST_Y + 1):
            for x in range(cx - 9, cx + 10):
                c.shade(x, y, 0.46)
        for y in range(SH_Y - 1, SH_Y + 7):
            for x in list(range(cx - 8, cx - 5)) + list(range(cx + 6, cx + 9)):
                c.shade(x, y, 0.46)
    elif st['top'] == 'vest':
        for y in range(SH_Y + 2, WAIST_Y + 1):
            for x in range(cx - 8, cx + 9):
                c.shade(x, y, 0.48)
    for y in range(WAIST_Y - 3, WAIST_Y + 1):            # 허리띠
        for x in range(cx - half, cx + half + 1):
            c.shade(x, y, 0.55)
    arms = [(-1, cx - half + 2), (1, cx + half - 2)] if view != 'side' else [(1, cx + 1)]
    for d, ax in arms:
        c.tube(ax, SH_Y + 4, ax + d * 4, WAIST_Y + 4, 10, 7, 'shirt', gain=1.0, bias=0.14)
        for y in range(SH_Y + 22, SH_Y + 25):            # 소매단
            for x in range(ax - 6, ax + 7):
                c.shade(x, y, 0.62)
        c.tube(ax + d * 3, SH_Y + 25, ax + d * 4, WAIST_Y + 4, 7, 6, 'skin', gain=0.9, bias=0.24)
        c.sphere(ax + d * 4, WAIST_Y + 7, 5, 6, 'skin', gain=0.9, bias=0.24)
    if st['bottom'] == 'skirt':
        c.cone(cx, HIP_Y - 6, HEM_Y, 15, 26 if view != 'side' else 19, 'pants',
               gain=1.0, bias=0.16, pleats=(-0.58, -0.2, 0.2, 0.58))
        leg_top = HEM_Y - 2
    else:
        c.cone(cx, HIP_Y - 6, HIP_Y + 4, 15, 16, 'pants', gain=1.0, bias=0.16)
        leg_top = HIP_Y + 2
    legs = [(cx - 8, 1), (cx + 8, -1)] if view != 'side' else [(cx - 2, -1)]
    for lx, inner in legs:
        if st['bottom'] == 'pants':
            c.tube(lx, leg_top, lx, BOOT_Y - 2, 15, 12, 'pants', gain=1.0, bias=0.16)
        else:
            c.tube(lx, leg_top, lx, BOOT_Y - 2, 13, 11, 'skin', gain=0.9, bias=0.26)
        c.tube(lx, BOOT_Y - 2, lx, GROUND - 2, 14, 14, 'shoe', gain=1.0, bias=0.2)
        c.sphere(lx, GROUND - 4, 8, 4, 'shoe', gain=1.0, bias=0.2)
        for y in range(GROUND - 3, GROUND):
            for x in range(lx - 8, lx + 9):
                c.shade(x, y, 0.5)
    c.occlude([(x, NECK_Y - 5) for x in range(cx - 6, cx + 7)], 0.5, 3)
    c.occlude([(x, WAIST_Y) for x in range(cx - half, cx + half + 1)], 0.6, 2)
    if st['bottom'] == 'skirt':
        c.occlude([(x, HEM_Y - 1) for x in range(cx - 26, cx + 27)], 0.55, 3)


def build(key, view, blink=False):
    st = STYLES[key]
    c = Canvas()
    body(c, st, view)
    cx = HEAD_CX if view != 'side' else HEAD_CX + 1
    c.sphere(cx, HEAD_CY, HEAD_RX, HEAD_RY, 'skin', gain=0.58, bias=0.46)
    if view == 'side':                                   # 코 · 턱
        for y in range(HEAD_CY - 2, HEAD_CY + 10):
            wdt = 3 - abs(y - (HEAD_CY + 3)) // 3
            for k in range(max(0, wdt)):
                c.put(cx + HEAD_RX - 2 + k, y, 'skin', 0.86 - 0.06 * k)
    if view != 'up':
        face(c, view, cx, blink)
    hair(c, st, view, cx)
    if view != 'up':
        brows(c, view, cx)
    c.outline()
    c.antialias()
    return c


def _render(c):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    o = im.load()
    for y in range(H):
        for x in range(W):
            key = c.fix[y][x]
            if key is None:
                m = c.mat[y][x]
                if m is None or m == 'fixed':
                    continue
                ramp, cuts = RAMP[m], CUT[m]
                lit = c.lit[y][x]
                idx = 0
                while idx < len(cuts) and lit >= cuts[idx]:
                    idx += 1
                key = ramp[idx]
            o[x, y] = PAL[key] + (255,)
    return im


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    made = []
    for key in STYLES:
        for view in ('down', 'side', 'up'):
            p = os.path.join(here, 'an_%s_%s.png' % (key, view))
            _render(build(key, view)).save(p)
            made.append(p)
    ok = set(PAL.values())
    for p in made:
        im = Image.open(p).convert('RGBA')
        px = im.load()
        ys = [y for y in range(im.height) for x in range(im.width) if px[x, y][3]]
        bad = {px[x, y][:3] for y in range(im.height) for x in range(im.width)
               if px[x, y][3] and px[x, y][:3] not in ok}
        print(os.path.basename(p), im.size, '발바닥', max(ys), '키', max(ys) - min(ys),
              '머리비율 %.0f%%' % (100.0 * (HEAD_RY * 2 + 4) / (max(ys) - min(ys))),
              '팔레트밖', len(bad))
