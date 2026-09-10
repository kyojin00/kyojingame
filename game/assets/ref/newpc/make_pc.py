# -*- coding: utf-8 -*-
# 새 주인공 도트 — **면을 칠하지 않고 빛을 계산해서** 찍는다.
#
# 지금까지는 「여기는 밝은 면, 여기는 그늘」을 손으로 적어 넣었다. 그러면 곡면이
# 안 생긴다 — 머리통도 팔도 두 색으로 나뉜 종이 조각이 된다. 참고로 받은 그림
# (은발 소녀 초상)의 「느낌」은 결국 **한 재질에 네다섯 단이 매끄럽게 도는 것**이다.
#
# 그래서 여기서는 부위마다 **입체(구·원기둥·원뿔)를 세우고 빛을 쏘아** 밝기를
# 구한 뒤, 그 밝기를 재질의 색 띠(ramp) 다섯 단으로 끊는다. 머리카락에는 그 위에
# 애니메이션 머리처럼 **가로로 도는 윤기 띠**를 하나 더 얹는다.
#
# 색은 game_data.gd 의 APPEAR_* 0번 줄과 **정확히** 같아야 한다 — 게임이 실행 중에
# 이 값을 찾아 옷·머리·살결 색을 갈아입힌다. (그래서 표를 벌당 다섯 단으로 늘렸다)
#
# 실행: python3 make_pc.py   ->  pc_<스타일>_<방향>.png + 미리보기
import math
import os
from PIL import Image

W, H = 128, 192
GROUND = 190
LIGHT = (-0.42, -0.56, 0.72)          # 왼쪽 위 앞에서 오는 빛

PAL = {
    'O': (54, 33, 26),                                  # 실루엣 윤곽선
    # 살결 — 어두운 쪽부터
    's4': (176, 102, 88), 's3': (213, 116, 98), 's2': (243, 159, 138),
    's1': (250, 192, 170), 's0': (252, 217, 204),
    'r': (235, 128, 114), 'm': (170, 84, 66),
    # 머리카락
    'h4': (58, 35, 20), 'h3': (86, 52, 30), 'h2': (118, 72, 40),
    'h1': (152, 100, 56), 'h0': (195, 165, 140),
    # 윗도리
    'b4': (27, 41, 84), 'b3': (38, 58, 120), 'b2': (58, 88, 168),
    'b1': (94, 126, 200), 'b0': (166, 184, 225),
    # 아랫도리
    'p4': (69, 43, 22), 'p3': (98, 62, 32), 'p2': (134, 88, 46),
    'p1': (158, 108, 58), 'p0': (202, 174, 147),
    # 신발
    'k2': (39, 26, 18), 'k1': (56, 37, 25), 'k0': (82, 53, 33),
    # 눈
    'e': (66, 32, 30), 'i': (136, 70, 42), 'w': (246, 242, 234),
}
# 재질마다 어두운 쪽 -> 밝은 쪽 색 띠
RAMP = {
    'skin': ['s4', 's3', 's2', 's1', 's0'],
    'hair': ['h4', 'h3', 'h2', 'h1', 'h0'],
    'shirt': ['b4', 'b3', 'b2', 'b1', 'b0'],
    'pants': ['p4', 'p3', 'p2', 'p1', 'p0'],
    'shoe': ['k2', 'k1', 'k0'],
}
# 재질별로 빛을 색 띠에 어떻게 나눠 담을지 — (문턱값들). 살결은 밝은 쪽을 넓게
# 써서 뽀얗게, 옷은 가운데를 넓게 써서 면이 안 부서지게.
# 살결은 **밝은 쪽을 넓게** 쓴다. 물리대로 반씩 나누면 얼굴 오른쪽이 통째로
# 붉은 덩어리가 된다 — 귀여운 얼굴은 거의 다 밝고 가장자리만 그늘이다.
# 깊은 그늘(맨 앞 칸)은 턱 밑·소매 밑처럼 **가려진 자리**에만 닿게 문턱을 낮게 둔다.
CUT = {
    'skin': [0.05, 0.20, 0.42, 0.66],
    'hair': [0.14, 0.34, 0.62, 0.93],
    'shirt': [0.10, 0.30, 0.62, 0.90],
    'pants': [0.10, 0.30, 0.62, 0.90],
    'shoe': [0.20, 0.55],
}


def _norm(v):
    d = math.sqrt(sum(c * c for c in v)) or 1.0
    return [c / d for c in v]


L = _norm(LIGHT)


class Canvas:
    """재질과 밝기를 따로 담아 두고, 마지막에 색 띠로 끊어 칠한다."""

    def __init__(self):
        self.mat = [[None] * W for _ in range(H)]
        self.lit = [[0.0] * W for _ in range(H)]
        self.fix = [[None] * W for _ in range(H)]   # 색을 못 박은 칸 (눈·입 등)

    def put(self, x, y, mat, lit):
        if 0 <= x < W and 0 <= y < H:
            self.mat[y][x] = mat
            self.lit[y][x] = lit

    def hard(self, x, y, key):
        if 0 <= x < W and 0 <= y < H:
            self.fix[y][x] = key
            if self.mat[y][x] is None:
                self.mat[y][x] = 'fixed'

    def at(self, x, y):
        return self.mat[y][x] if 0 <= x < W and 0 <= y < H else None

    # ---- 입체 ----
    def sphere(self, cx, cy, rx, ry, mat, gain=1.0, bias=0.0, mask=None, squash=1.0):
        """구 — 머리통. 화면 안쪽으로 부푼 만큼 빛을 받는다."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                u, v = (x - cx) / rx, (y - cy) / ry
                q = u * u + v * v
                if q > 1.0:
                    continue
                if mask and not mask(x, y):
                    continue
                nz = math.sqrt(max(0.0, 1.0 - q)) * squash
                n = _norm([u, v, nz])
                lit = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
                self.put(x, y, mat, min(1.0, lit * gain + bias))

    def tube(self, x0, y0, x1, y1, w0, w1, mat, gain=1.0, bias=0.0, round_cap=True):
        """원기둥 — 팔·다리·몸통. 축에서 옆으로 얼마나 갔는지로 밝기를 낸다."""
        d = math.hypot(x1 - x0, y1 - y0) or 0.001
        ux, uy = (x1 - x0) / d, (y1 - y0) / d
        nx, ny = uy, -ux
        steps = int(d * 3) + 1
        for i in range(steps + 1):
            t = i / steps
            cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            hw = (w0 + (w1 - w0) * t) / 2.0
            j = -int(hw * 3)
            while j <= int(hw * 3):
                s = j / 3.0
                u = s / hw
                if abs(u) > 1.0:
                    j += 1
                    continue
                nz = math.sqrt(max(0.0, 1.0 - u * u))
                n = _norm([nx * u, ny * u, nz])
                lit = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
                if round_cap and (t < 0.02 or t > 0.98):
                    lit *= 0.9
                self.put(round(cx + nx * s), round(cy + ny * s), mat,
                         min(1.0, lit * gain + bias))
                j += 1

    def cone(self, cx, y0, y1, r0, r1, mat, gain=1.0, bias=0.0, pleats=()):
        """원뿔 — 치마. 주름은 빛을 깎아 낸다 (색을 따로 칠하지 않는다)."""
        for y in range(y0, y1 + 1):
            t = (y - y0) / float(max(1, y1 - y0))
            r = r0 + (r1 - r0) * t * t
            for x in range(int(round(cx - r)), int(round(cx + r)) + 1):
                u = (x - cx) / r
                if abs(u) > 1.0:
                    continue
                nz = math.sqrt(max(0.0, 1.0 - u * u))
                n = _norm([u, -0.35, nz])
                lit = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
                for pf in pleats:                       # 주름 골
                    if abs(u - pf) < 0.075:
                        lit *= 0.62
                self.put(x, y, mat, min(1.0, lit * gain + bias))

    def slab(self, x0, y0, x1, y1, mat, lit):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, mat, lit)

    # ---- 마무리 ----
    def shade(self, x, y, f):
        if 0 <= x < W and 0 <= y < H and self.mat[y][x]:
            self.lit[y][x] = max(0.0, min(1.0, self.lit[y][x] * f))

    def occlude(self, cells, f=0.55, spread=3):
        """무엇에 가려진 자리에 그림자를 깐다 — 머리 밑 목, 소매 밑 팔."""
        for (x, y) in cells:
            for k in range(1, spread + 1):
                self.shade(x, y + k, f + (1 - f) * (k - 1) / float(spread))

    def outline(self):
        edge = []
        for y in range(H):
            for x in range(W):
                if self.mat[y][x] is not None:
                    continue
                if any(self.at(x + dx, y + dy) is not None
                       for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    edge.append((x, y))
        for x, y in edge:
            self.mat[y][x] = 'fixed'
            self.fix[y][x] = 'O'

    def antialias(self):
        """계단진 실루엣을 한 단 눅인다.

        도트를 손으로 찍는 사람은 비스듬한 가장자리에 중간색을 한 칸씩 놓아
        계단을 눅인다. 여기서는 **윤곽선 바로 안쪽** 칸 중에 바깥이 두 방향으로
        트인 칸(= 계단의 모서리)만 골라 한 단 어둡게 한다. 재질 색 띠 안에서만
        움직이므로 팔레트를 벗어나지 않는다."""
        soft = []
        for y in range(H):
            for x in range(W):
                m = self.mat[y][x]
                if m is None or m == 'fixed':
                    continue
                open_n = 0
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    qx, qy = x + dx, y + dy
                    if 0 <= qx < W and 0 <= qy < H and self.fix[qy][qx] == 'O':
                        open_n += 1
                if open_n >= 2:
                    soft.append((x, y))
        for x, y in soft:
            self.lit[y][x] = max(0.0, self.lit[y][x] - 0.22)

    def render(self):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        o = im.load()
        for y in range(H):
            for x in range(W):
                key = self.fix[y][x]
                if key is None:
                    m = self.mat[y][x]
                    if m is None or m == 'fixed':
                        continue
                    ramp, cuts = RAMP[m], CUT[m]
                    lit = self.lit[y][x]
                    idx = 0
                    while idx < len(cuts) and lit >= cuts[idx]:
                        idx += 1
                    key = ramp[idx]
                o[x, y] = PAL[key] + (255,)
        return im


# --------------------------------------------------------------------- 얼굴
#
# 눈은 계산으로 안 나온다 — 한 칸 한 칸이 표정이라 손으로 찍는다.
# 위 속눈썹은 바깥으로 갈수록 두껍고, 눈망울은 위가 어둡고 아래로 갈수록
# 밝아진다(홍채 반사). 흰 반짝이는 큰 것 하나 + 작은 것 하나.
EYE = [
    '...eeeeeeeeee....',
    '..eeeeeeeeeeeee..',
    '.eeeeeeeeeeeeeee.',
    'eeeeeeeeeeeeeeeee',
    'eewwwweeeeeeeeeee',
    'eewwwweeeeeeeeeee',
    'eewwwweeeeeeeeeee',
    'eeewweeeeeeeeeeee',
    'eeeeeeeeeeeeeeeee',
    'eeeeeeeeeeeeeeeee',
    'eeiiiiiiiiiiiwwee',
    'eeiiiiiiiiiiiwwee',
    '.eiiiiiiiiiiiiiee',
    '.eeiiiiiiiiiiiee.',
    '..eeeiiiiiiieee..',
    '...eeeeeeeeeee...',
]
LID = [                       # 감은 눈
    'ee........ee',
    '.eeeeeeeeee.',
    '..eeeeeeee..',
]
BROW = ['..iiiiiiiii..', 'iii.......iii']

EYE_W = len(EYE[0])
EYE_H = len(EYE)


def stamp(c, rows, x0, y0, flip=False):
    for dy, row in enumerate(rows):
        r = row[::-1] if flip else row
        for dx, ch in enumerate(r):
            if ch != '.':
                c.hard(x0 + dx, y0 + dy, ch)


# ------------------------------------------------------------------ 사람 하나

HEAD_CX, HEAD_CY, HEAD_RX, HEAD_RY = 64, 50, 36, 39
NECK_Y, SH_Y, WAIST_Y, HIP_Y = 88, 92, 128, 132
HEM_Y, BOOT_Y = 154, 176

STYLES = {
    'a': {'name': '앞치마 소녀', 'hair': 'pigtail', 'bottom': 'skirt', 'top': 'apron'},
    'b': {'name': '반바지 소년', 'hair': 'short', 'bottom': 'shorts', 'top': 'tee'},
    'c': {'name': '단발 소녀', 'hair': 'bob', 'bottom': 'skirt', 'top': 'vest'},
}


def head(c, st, view, blink=False):
    cx = HEAD_CX if view != 'side' else HEAD_CX + 2
    c.sphere(cx, HEAD_CY, HEAD_RX, HEAD_RY, 'skin', gain=0.62, bias=0.42)
    if view == 'side':                                  # 코 · 턱
        for y in range(54, 70):
            wdt = 4 - abs(y - 61) // 3
            for k in range(wdt):
                c.put(cx + HEAD_RX - 3 + k, y, 'skin', 0.9 - 0.05 * k)
    if view != 'up':
        face(c, st, view, blink, cx)
    hair(c, st, view, cx)


def face(c, st, view, blink, cx):
    ey = 51
    if view == 'side':
        ex = cx + 14
        if blink:
            stamp(c, LID, ex, ey + 6)
        else:
            stamp(c, EYE, ex, ey)
        stamp(c, BROW, ex + 2, ey - 8)
        for x in range(cx + 20, cx + 27):
            c.hard(x, 78, 'm')
        for y in (72, 73, 74, 75):                      # 볼
            for x in range(cx + 2, cx + 10):
                c.hard(x, y, 'r')
        return
    gap = 5                                             # 두 눈 사이 — 한 눈 너비보다 좁게
    lx = cx - gap // 2 - EYE_W
    rx = cx + gap // 2
    if blink:
        stamp(c, LID, lx + 1, ey + 6)
        stamp(c, LID, rx + 1, ey + 6)
    else:
        stamp(c, EYE, lx, ey)
        stamp(c, EYE, rx, ey, flip=True)
    stamp(c, BROW, lx + 2, ey - 8)
    stamp(c, BROW, rx + 2, ey - 8, flip=True)
    c.hard(cx - 1, 74, 'm')                             # 코 그늘 한 점
    for x in range(cx - 4, cx + 5):                     # 입 — 살짝 웃는 두 줄
        c.hard(x, 80, 'm')
    for x in range(cx - 2, cx + 3):
        c.hard(x, 81, 'm')
    c.hard(cx - 5, 79, 'm')
    c.hard(cx + 5, 79, 'm')
    for y in (78, 79, 80, 81):                          # 볼터치 — 눈 바깥 아래
        for x in range(lx - 1, lx + 7):
            c.hard(x, y, 'r')
        for x in range(rx + EYE_W - 7, rx + EYE_W + 1):
            c.hard(x, y, 'r')


def _hair_shell(c, cx, keep):
    """머리통을 감싸는 껍질 — 구의 빛을 그대로 받되 한 겹 부풀린다."""
    c.sphere(cx, HEAD_CY, HEAD_RX + 2, HEAD_RY + 2, 'hair', gain=0.78, bias=0.16,
             mask=keep)
    # 애니메이션 머리의 윤기 — **머리통 곡면을 따라 도는 가는 활**이다.
    # 가로로 곧은 띠를 얹었더니 머리띠를 두른 것처럼 보였다. 머리 중심에서 잰
    # 거리로 띠를 만들면 저절로 머리 모양을 따라 휜다.
    for y in range(HEAD_CY - HEAD_RY - 2, HEAD_CY + 6):
        for x in range(cx - HEAD_RX - 2, cx + HEAD_RX + 3):
            if c.at(x, y) != 'hair':
                continue
            u, v = (x - cx) / float(HEAD_RX + 2), (y - HEAD_CY) / float(HEAD_RY + 2)
            d = math.sqrt(u * u + v * v)
            if abs(d - 0.74) < 0.10 and v < -0.15 and -0.85 < u < 0.55:
                c.lit[y][x] = min(1.0, c.lit[y][x] + 0.34)


def hair(c, st, view, cx):
    kind = st['hair']
    tips = {'pigtail': [(0.08, 20), (0.30, 13), (0.50, 21), (0.71, 14), (0.93, 19)],
            'short': [(0.12, 15), (0.34, 21), (0.58, 13), (0.83, 19)],
            'bob': [(0.10, 15), (0.32, 20), (0.57, 13), (0.84, 18)]}[kind]
    sidelen = {'pigtail': 30, 'short': 12, 'bob': 40}[kind]

    def keep(x, y):
        u = (x - cx) / float(HEAD_RX + 2)
        top = HEAD_CY - HEAD_RY - 2
        deep = max((dv - abs(u - t) * 34 for t, dv in
                    [(t * 2 - 1, dv) for t, dv in tips]), default=0)
        if view == 'side' and u > 0.25:
            deep = max(0.0, deep - 3)
        if y < top + 28 + deep:
            return True
        return abs(u) > 0.68 and y < top + 30 + sidelen   # 구레나룻

    _hair_shell(c, cx, keep)
    if kind == 'pigtail':                               # 낮게 묶은 두 갈래
        for d in ((-1, 1) if view != 'side' else (-1,)):
            for y in range(62, 122):
                t = (y - 62) / 59.0
                wd = 15 - 8 * t * t
                base = cx + d * (HEAD_RX - 5 + int(6 * t * t))
                for k in range(int(round(wd))):
                    xx = base + d * k
                    u = (k / wd) * 2 - 1
                    nz = math.sqrt(max(0.0, 1 - u * u))
                    n = _norm([u * d, -0.2, nz])
                    lit = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
                    c.put(xx, y, 'hair', min(1.0, lit * 1.15 + 0.06))
    elif kind == 'bob' and view == 'side':
        for y in range(64, 100):
            t = (y - 64) / 35.0
            wd = 14 - 9 * t * t
            base = cx - HEAD_RX - 1
            for k in range(int(round(wd))):
                u = (k / wd) * 2 - 1
                nz = math.sqrt(max(0.0, 1 - u * u))
                n = _norm([-u, -0.2, nz])
                lit = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
                c.put(base + k, y, 'hair', min(1.0, lit * 1.15 + 0.06))


def body(c, st, view):
    cx = 64 if view != 'side' else 66
    half = 24 if view != 'side' else 17
    c.tube(cx, NECK_Y - 4, cx, NECK_Y + 4, 13, 13, 'skin', gain=1.0, bias=0.05)
    # 몸통 — 어깨에서 허리로 좁아지는 원기둥
    c.tube(cx, SH_Y + 1, cx, WAIST_Y, half * 2, half * 2 - 6, 'shirt',
           gain=1.1, bias=0.10)
    # 어깨 둥글리기
    c.sphere(cx, SH_Y + 6, half, 8, 'shirt', gain=1.1, bias=0.10)
    # 겹쳐 입은 것 — 빛을 깎아 어두운 판을 만든다 (색을 따로 칠하지 않는다)
    if st['top'] == 'apron':
        for y in range(SH_Y + 8, WAIST_Y + 1):
            for x in range(cx - 15, cx + 16):
                c.shade(x, y, 0.42)
        for y in range(SH_Y - 1, SH_Y + 9):
            for x in list(range(cx - 13, cx - 8)) + list(range(cx + 9, cx + 14)):
                c.shade(x, y, 0.42)
    elif st['top'] == 'vest':
        for y in range(SH_Y + 3, WAIST_Y + 1):
            for x in range(cx - 12, cx + 13):
                c.shade(x, y, 0.45)
    for y in range(WAIST_Y - 4, WAIST_Y + 1):           # 허리띠
        for x in range(cx - half, cx + half + 1):
            c.shade(x, y, 0.5)
    # 팔
    arms = [(-1, cx - half + 3), (1, cx + half - 3)] if view != 'side' else [(1, cx + 1)]
    for d, ax in arms:
        c.tube(ax, SH_Y + 6, ax + d * 5, SH_Y + 30, 15, 11, 'shirt', gain=1.1, bias=0.08)
        for y in range(SH_Y + 22, SH_Y + 25):           # 소매단
            for x in range(ax - 8, ax + 9):
                c.shade(x, y, 0.6)
        c.sphere(ax + d * 6, SH_Y + 35, 7, 8, 'skin', gain=1.1, bias=0.10)
    # 아래
    if st['bottom'] == 'skirt':
        c.cone(cx, HIP_Y, HEM_Y, 22, 40 if view != 'side' else 30, 'pants',
               gain=1.1, bias=0.10, pleats=(-0.55, -0.2, 0.2, 0.55))
        legs = [(cx - 11, HEM_Y - 2), (cx + 11, HEM_Y - 2)] if view != 'side' else [(cx - 3, HEM_Y - 2)]
    else:
        c.cone(cx, HIP_Y, HEM_Y - 8, 22, 25 if view != 'side' else 18, 'pants',
               gain=1.1, bias=0.10)
        if view != 'side':
            for y in range(HEM_Y - 18, HEM_Y - 7):      # 가랑이
                for x in range(cx - 2, cx + 3):
                    c.shade(x, y, 0.45)
        legs = [(cx - 11, HEM_Y - 10), (cx + 11, HEM_Y - 10)] if view != 'side' else [(cx - 3, HEM_Y - 10)]
    for lx, ly in legs:
        c.tube(lx, ly, lx, BOOT_Y, 15, 13, 'skin', gain=1.05, bias=0.10)
        c.tube(lx, BOOT_Y, lx, GROUND - 1, 17, 17, 'shoe', gain=1.1, bias=0.12)
        c.sphere(lx, GROUND - 4, 9, 5, 'shoe', gain=1.1, bias=0.12)
        for y in range(GROUND - 3, GROUND):             # 밑창
            for x in range(lx - 9, lx + 10):
                c.shade(x, y, 0.45)
    # 그림자 — 머리 밑 목, 소매 밑 팔, 치마 밑 다리
    c.occlude([(x, NECK_Y - 5) for x in range(cx - 8, cx + 9)], 0.45, 4)
    c.occlude([(x, WAIST_Y) for x in range(cx - half, cx + half + 1)], 0.55, 3)
    c.occlude([(x, HEM_Y - 1) for x in range(cx - 40, cx + 41)], 0.5, 4)


def build(style_key, view, blink=False):
    st = STYLES[style_key]
    c = Canvas()
    body(c, st, view)
    head(c, st, view, blink)
    c.outline()
    c.antialias()
    return c


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    made = []
    for key in STYLES:
        for view in ('down', 'side', 'up'):
            im = build(key, view).render()
            p = os.path.join(here, 'pc_%s_%s.png' % (key, view))
            im.save(p)
            made.append(p)
    ok_cols = set(PAL.values())
    for p in made:
        im = Image.open(p).convert('RGBA')
        px = im.load()
        ys = [y for y in range(im.height) for x in range(im.width) if px[x, y][3]]
        bad = {px[x, y][:3] for y in range(im.height) for x in range(im.width)
               if px[x, y][3] and px[x, y][:3] not in ok_cols}
        print(os.path.basename(p), im.size, '발바닥', max(ys), '키', max(ys) - min(ys),
              '색', len({px[x, y][:3] for y in range(im.height) for x in range(im.width) if px[x, y][3]}),
              '팔레트밖', len(bad))
