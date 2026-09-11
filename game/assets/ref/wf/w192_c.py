#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""w192_c — 애니 치비 극단.  192 x 288 격자에 처음부터 직접 작도한다.

방향: 머리가 키의 45%, 눈 하나가 얼굴 폭의 40%.  몸통·팔다리는 짧고 동글.
저해상도 그림을 확대한 게 아니라 실루엣·음영 경계를 전부 실수 곡선
(단조 3차 에르미트 보간)으로 잡아 줄마다 한 칸씩 흐르게 만든다.

실행하면 여섯 장:  w192_c_{boy,girl}_{down,side,up}.png
"""

import math
import os
from PIL import Image

GW, GH = 192, 288
CX = 95.5

# ---------------------------------------------------------------- 팔레트
PAL = {
    'a': (243, 159, 138), 'b': (250, 192, 170), 'c': (213, 116, 98),
    'd': (235, 128, 114), 'e': (170, 84, 66), 'f': (184, 99, 83),
    'g': (252, 217, 204),
    'h': (118, 72, 40), 'i': (152, 100, 56), 'j': (86, 52, 30),
    'k': (58, 35, 20), 'l': (195, 165, 140),
    'm': (58, 88, 168), 'n': (38, 58, 120), 'o': (94, 126, 200),
    'p': (27, 41, 84), 'q': (166, 184, 225),
    'r': (134, 88, 46), 's': (98, 62, 32), 't': (158, 108, 58),
    'u': (69, 43, 22), 'v': (202, 174, 147),
    'w': (82, 53, 33), 'x': (56, 37, 25), 'y': (39, 26, 18),
    'O': (26, 20, 28), 'E': (66, 32, 30), 'B': (136, 70, 42),
    'W': (246, 242, 234),
}
GRP = {}
for _c in 'abcdefg':
    GRP[_c] = 'sk'
for _c in 'hijkl':
    GRP[_c] = 'hr'
for _c in 'mnopq':
    GRP[_c] = 'sh'
for _c in 'rstuv':
    GRP[_c] = 'pt'
for _c in 'wxy':
    GRP[_c] = 'so'
DARK = {'sk': 'f', 'hr': 'k', 'sh': 'p', 'pt': 'u', 'so': 'y'}

# ---------------------------------------------------------------- 부위 번호
P_LEG, P_SHOE, P_LOW, P_TOR, P_COL = 1, 2, 3, 4, 5
P_NECK, P_ARM_N, P_ARM_F, P_HAND_N, P_HAND_F = 6, 7, 8, 9, 10
P_FACE, P_EAR, P_HAIR, P_HAIR2 = 11, 12, 13, 14
P_EYE_L, P_EYE_R, P_FEAT = 15, 16, 17

L_ARMF, L_LEG, L_SHOE, L_LOW, L_TOR = 3, 2, 3, 4, 5
L_NECK, L_COL, L_ARM, L_HEAD, L_HAIR, L_HAIR2, L_FEAT = 4, 7, 7, 9, 10, 11, 13


# ---------------------------------------------------------------- 곡선
def pchip(pts):
    """단조 3차 에르미트.  제어점 사이가 부풀지 않아 실루엣에 안전하다."""
    pts = sorted(pts)
    xs = [float(p[0]) for p in pts]
    ys = [float(p[1]) for p in pts]
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[n - 1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0:
            m[i] = 0.0
        else:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])

    def f(t):
        if t <= xs[0]:
            return ys[0]
        if t >= xs[-1]:
            return ys[-1]
        i = 0
        while i < n - 2 and t > xs[i + 1]:
            i += 1
        s = (t - xs[i]) / h[i]
        s2, s3 = s * s, s * s * s
        return ((2 * s3 - 3 * s2 + 1) * ys[i] + (s3 - 2 * s2 + s) * h[i] * m[i]
                + (-2 * s3 + 3 * s2) * ys[i + 1] + (s3 - s2) * h[i] * m[i + 1])
    return f


def leafline(base, leaves):
    """아래로 뾰족한 잎을 여럿 겹쳐 그 최댓값을 선으로 삼는다 (목덜미용)."""
    def f(x):
        v = base
        for (tx, tip, kl, kr, p) in leaves:
            dv = tip - (kl if x <= tx else kr) * abs(x - tx) ** p
            if dv > v:
                v = dv
        return v
    return f


def lowpass(f, x0, x1, w):
    """곡선을 뭉갠 것.  앞머리 그늘이 앞머리 모양을 그대로 되풀이하면
    지그재그가 두 겹이 된다 — 그늘은 뭉갠 선을 따라가야 한다."""
    tab = {}
    for x in range(int(x0) - 2, int(x1) + 3):
        s, n = 0.0, 0
        for d in range(-w, w + 1):
            s += f(x + d)
            n += 1
        tab[x] = s / n

    def g(x):
        return tab.get(int(round(x)), f(x))
    return g


# ---------------------------------------------------------------- 캔버스
class Cv(object):
    def __init__(self):
        self.ch = [['.'] * GW for _ in range(GH)]
        self.lay = [[-9] * GW for _ in range(GH)]
        self.pid = [[0] * GW for _ in range(GH)]

    def put(self, x, y, ch, lay, pid):
        x, y = int(x), int(y)
        if 0 <= x < GW and 0 <= y < GH and lay >= self.lay[y][x]:
            self.ch[y][x] = ch
            self.lay[y][x] = lay
            self.pid[y][x] = pid

    def row(self, y, x0, x1, ch, lay, pid):
        a = int(math.ceil(x0 - 0.5))
        b = int(math.floor(x1 - 0.5))
        for x in range(a, b + 1):
            self.put(x, y, ch, lay, pid)

    def part(self, y0, y1, fl, fr, ch, lay, pid):
        for y in range(int(y0), int(y1) + 1):
            self.row(y, fl(y), fr(y), ch, lay, pid)

    def ell(self, cx, cy, rx, ry, ch, lay, pid):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, ch, lay, pid)

    # --- pid 안쪽만 덧칠 (음영) ---
    def pin(self, pids, x, y, ch):
        x, y = int(x), int(y)
        if 0 <= x < GW and 0 <= y < GH and self.pid[y][x] in pids:
            self.ch[y][x] = ch

    def rin(self, pids, y, x0, x1, ch):
        a = int(math.ceil(x0 - 0.5))
        b = int(math.floor(x1 - 0.5))
        for x in range(max(0, a), min(GW - 1, b) + 1):
            self.pin(pids, x, y, ch)

    def bandin(self, pids, y0, y1, f0, f1, ch):
        for y in range(int(y0), int(y1) + 1):
            self.rin(pids, y, f0(y), f1(y), ch)

    def ein(self, pids, cx, cy, rx, ry, ch):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                    self.pin(pids, x, y, ch)

    def ein_out(self, pids, cx, cy, rx, ry, ch):
        """타원 바깥쪽만 (초승달 음영에 쓴다)"""
        for y in range(GH):
            for x in range(GW):
                if self.pid[y][x] in pids:
                    if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 > 1.0:
                        self.ch[y][x] = ch

    def stroke(self, pts, w, ch, lay, pid):
        """점열을 굵기 w 로 이은 선.  머릿결·주름용."""
        for i in range(len(pts) - 1):
            x0, y0 = pts[i]
            x1, y1 = pts[i + 1]
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for s in range(n + 1):
                t = s / float(n)
                self.ell(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t,
                         w / 2.0, w / 2.0, ch, lay, pid)

    def stroke_in(self, pids, pts, w, ch):
        for i in range(len(pts) - 1):
            x0, y0 = pts[i]
            x1, y1 = pts[i + 1]
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for s in range(n + 1):
                t = s / float(n)
                self.ein(pids, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t,
                         w / 2.0, w / 2.0, ch)


# ---------------------------------------------------------------- 머리 실루엣
HTOP, CHIN = 6, 133
HEAD_HW = pchip([(6, 7), (8, 14.5), (11, 23), (15, 31.5), (20, 39), (26, 46),
                 (33, 52.5), (41, 58), (50, 62.5), (60, 65.5), (70, 67),
                 (80, 67), (89, 65.5), (97, 63.2), (104, 60.2), (110, 56.5),
                 (116, 51), (121, 45), (125, 37.5), (128, 29), (130, 21),
                 (132, 13), (133, 8)])

# 뒷모습은 턱이 없다 — 아래를 넓게 유지해 목덜미를 만든다
HEAD_UP_HW = pchip([(6, 7), (8, 14.5), (11, 23), (15, 31.5), (20, 39), (26, 46),
                    (33, 52.5), (41, 58), (50, 62.5), (60, 65.5), (70, 67),
                    (80, 67), (89, 65.5), (97, 63.2), (104, 60.2), (112, 56),
                    (120, 50.5), (127, 43), (133, 35), (138, 27), (141, 19)])

# 3/4 — 덩어리는 거의 그대로, 중심만 보는 쪽으로 흐른다
SIDE_SHIFT = pchip([(6, 0.5), (30, 1.2), (60, 2.4), (85, 4.0), (105, 6.0),
                    (120, 8.0), (133, 9.5)])


def head_edges(view):
    if view != 'side':
        return (lambda y: CX - HEAD_HW(y), lambda y: CX + HEAD_HW(y))
    nose = pchip([(104, 0), (110, 1.4), (116, 3.2), (120, 3.4), (124, 1.2),
                  (128, 0)])

    def fl(y):
        return CX + SIDE_SHIFT(y) - HEAD_HW(y) * 1.035

    def fr(y):
        return CX + SIDE_SHIFT(y) + HEAD_HW(y) * 0.975 + nose(y)
    return fl, fr


# ---------------------------------------------------------------- 눈
def draw_eye(cv, cx, cy, rx, ry, outer, pid, tilt=2.6, irisdx=0.0,
             lashes=False, tail=0.0):
    """기여움의 90%.
    · 눈꼬리가 바깥으로 살짝 올라간 초타원 (정원이면 유리구슬이 된다)
    · 홍채는 따뜻한 갈색이 바탕, 위 1/3 만 눈꺼풀 그늘로 어둡게,
      동공은 그 안에서 새까맣게 — 세 단이 겹쳐야 눈이 반짝인다
    · 흰자는 좌우 구석에만 남는다
    outer: 바깥쪽 방향 (-1 왼눈, +1 오른눈)"""
    P = (pid,)
    # 홍채는 눈높이를 꽉 채우는 세로 타원이다.  원을 눈 안에 띄우면
    # 흰자가 빙 둘러 유리구슬이 된다 — 위는 속눈썹이, 아래는 아래꺼풀이 자른다.
    irx, iry = rx * 0.78, ry * 1.02
    icx, icy = cx + irisdx, cy + ry * 0.11
    rb = ry * 0.965

    def base(u):
        return cy - tilt * u * outer

    for xx in range(int(cx - rx) - 2, int(cx + rx) + 3):
        u = (xx + .5 - cx) / rx
        if abs(u) >= 1.0:
            continue
        hh = (1.0 - abs(u) ** 2.45) ** (1 / 2.45)
        b = base(u)
        top, bot = b - ry * hh, b + rb * hh
        lash = 4.9 + 2.0 * max(0.0, u * outer) ** 1.5 - 1.0 * max(0.0, -u * outer)
        for yy in range(int(math.floor(top)), int(math.ceil(bot)) + 1):
            if not (0 <= yy < GH and 0 <= xx < GW):
                continue
            fy = yy + .5
            if fy < top or fy > bot:
                continue
            ch = 'W'
            dx, dy = xx + .5 - icx, fy - icy
            if (dx / irx) ** 2 + (dy / iry) ** 2 <= 1.0:
                ch = 'B'
                if dy < -iry * 0.30 + 0.36 * dx * dx / irx:
                    ch = 'E'
                if (dx / (irx * 0.46)) ** 2 + ((dy - iry * 0.06) / (iry * 0.40)) ** 2 <= 1:
                    ch = 'O'
            bl = 1.3 + 1.1 * max(0.0, u * outer)
            if fy < top + lash or fy > bot - bl or abs(u) > 0.958:
                ch = 'O'
            if cv.pid[yy][xx] in (P_FACE, pid):
                cv.put(xx, yy, ch, L_FEAT, pid)
    # 반사점 — 큰 것 바깥 위, 작은 것 안쪽 아래
    cv.ein(P, icx + outer * irx * 0.50, icy - iry * 0.42, irx * 0.36, irx * 0.36, 'W')
    cv.ein(P, icx - outer * irx * 0.46, icy + iry * 0.44, irx * 0.19, irx * 0.19, 'W')
    if lashes:
        cv.stroke_in(P + (P_FACE,),
                     [(cx + outer * (rx - 2.5), cy - ry * 0.70),
                      (cx + outer * (rx + 2.5 + tail), cy - ry * 0.96)], 2.6, 'O')


def draw_brow(cv, cx, y, w, th, tilt, pid):
    """짧고 평평하게.  길고 두껍게 안쪽으로 기울이면 화난 얼굴이 된다.
    앞머리에 가리는 건 가려진 채로 둔다 (얼굴 안쪽만 칠한다)."""
    n = 30
    for s in range(n + 1):
        t = s / float(n) - 0.5
        x = cx + t * w
        yy = y + tilt * t + 1.1 * (t * t * 4 - 0.55)
        hw = th / 2.0 * (1.0 - 0.55 * max(0.0, (abs(t) - 0.30) / 0.20) ** 2)
        cv.ein((P_FACE,), x, yy, 1.9, max(0.9, hw), 'B')


# ---------------------------------------------------------------- 얼굴
def draw_face(cv, sex, view):
    sh = 10.0 if view == 'side' else 0.0
    ecy = 92.0
    ry = 23.0 if sex == 'boy' else 23.8
    rx = 22.5 if sex == 'boy' else 22.0
    gl = (sex == 'girl')
    if view == 'side':
        lx, rxc = CX + sh - 27.0, CX + sh + 24.0
        draw_eye(cv, lx, ecy, rx, ry, -1, P_EYE_L, irisdx=1.8,
                 lashes=gl, tail=1.0)
        draw_eye(cv, rxc, ecy - 0.5, rx * 0.66, ry * 0.97, +1, P_EYE_R,
                 irisdx=1.0, lashes=gl)
        draw_brow(cv, lx - 1.0, 65.5, 18, 4.0, 1.4 if sex == 'boy' else 1.0,
                  P_FEAT)
        draw_brow(cv, rxc + 1.5, 64.0, 13, 3.8, 1.0, P_FEAT)
    else:
        ex = 27.0 if sex == 'boy' else 26.0
        draw_eye(cv, CX - ex, ecy, rx, ry, -1, P_EYE_L, lashes=gl, tail=1.0)
        draw_eye(cv, CX + ex, ecy, rx, ry, +1, P_EYE_R, lashes=gl, tail=1.0)
        draw_brow(cv, CX - 27.0, 65.5, 19, 4.0, 1.5 if sex == 'boy' else 1.0,
                  P_FEAT)
        draw_brow(cv, CX + 27.5, 64.3, 19, 4.0, -1.5 if sex == 'boy' else -1.0,
                  P_FEAT)
    # 코 — 두어 칸
    nx = CX + sh * 1.5
    cv.ein((P_FACE,), nx + 1, 114.5, 3.4, 2.4, 'c')
    cv.ein((P_FACE,), nx + 1.5, 113.0, 2.0, 1.4, 'd')
    # 입 — 작을수록 어리다
    mx = CX + sh * 1.25
    my = 122.0 if sex == 'boy' else 121.5
    wm = 6.0 if sex == 'boy' else 5.2
    pts = []
    n = 16
    for s in range(n + 1):
        t = s / float(n) * 2 - 1
        pts.append((mx + t * wm, my - 2.0 * t * t))
    cv.stroke_in((P_FACE,), pts, 2.6, 'O')

    # 볼 홍조 — 반드시 눈 아래
    bl = CX + sh * 0.7 - 30
    br = CX + sh * 1.2 + 30
    cv.ein((P_FACE,), bl, 114.5, 14.0, 6.0, 'd')
    cv.ein((P_FACE,), br, 114.0, 13.0 if view != 'side' else 9.5, 5.8, 'd')


# ---------------------------------------------------------------- 머리통
HAIRLINE = {
    # 앞머리.  뾰족한 잎을 겹치면 빗살무늬가 된다 — 가닥마다 둥근 덩이로,
    # 봉우리와 골의 간격·깊이를 전부 어긋나게 잡는다.
    'boy':  [(14, 130), (24, 92), (33, 76), (41, 64), (48, 56), (57, 49),
             (69, 45), (81, 52), (95, 58.5), (108, 51), (120, 46), (131, 52),
             (142, 59), (150, 57), (157, 66), (165, 82), (176, 130)],
    'girl': [(12, 134), (22, 96), (31, 78), (39, 66), (46, 56), (55, 46),
             (67, 41), (79, 48), (93, 54.5), (105, 47), (117, 42), (129, 49),
             (140, 56), (148, 54), (155, 64), (163, 80), (174, 134)],
}


def hairline_of(sex, view):
    pts = HAIRLINE[sex]
    if view == 'side':
        pts = [(x + 9 + (x - 95.5) * 0.03, y + (1.5 if x > 95 else -1.0))
               for (x, y) in pts]
    return pchip(pts), pts


def side_thick(sex):
    if sex == 'boy':
        return pchip([(HTOP, 40), (38, 13.5), (60, 11.5), (78, 9.6), (92, 8),
                      (102, 5), (110, 0.2), (133, 0.2)])
    return pchip([(HTOP, 40), (38, 11.0), (60, 10.6), (80, 10.0), (100, 9.4),
                  (118, 9.0), (133, 8.6)])


def draw_head(cv, sex, view):
    fl, fr = head_edges(view)
    hline, _pts = hairline_of(sex, view)
    st = side_thick(sex)
    lsc = 1.6 if view == 'side' else 1.0     # 3/4 은 먼 쪽 머리가 더 보인다
    rsc = 0.62 if view == 'side' else 1.0
    if view == 'up':
        # 뒤통수 — 턱처럼 뾰족하게 좁히면 안 된다.  목덜미는 넓고 둥글게
        # 내려와 목을 덮는다.
        nape = leafline(0, [(CX - 19, 141, 0.055, 0.05, 1.7),
                            (CX + 4, 135, 0.06, 0.045, 1.7),
                            (CX + 26, 139, 0.04, 0.07, 1.7)])

        def napeY(x):
            return min(nape(x), 141 - 19 * ((x - CX) / 40.0) ** 2)
        for y in range(HTOP, 146):
            hw = HEAD_UP_HW(y)
            xa = int(math.ceil(CX - hw - .5))
            xb = int(math.floor(CX + hw - .5))
            for x in range(xa, xb + 1):
                if y <= napeY(x + .5):
                    cv.put(x, y, 'h', L_HAIR, P_HAIR)
        return
    for y in range(HTOP, CHIN + 1):
        a, b = fl(y), fr(y)
        tl, tr = st(y) * lsc, st(y) * rsc
        xa = int(math.ceil(a - .5))
        xb = int(math.floor(b - .5))
        for x in range(xa, xb + 1):
            xf = x + .5
            inface = (xf >= a + tl and xf <= b - tr and y >= hline(xf))
            if inface:
                cv.put(x, y, 'a', L_HEAD, P_FACE)
            else:
                cv.put(x, y, 'h', L_HAIR, P_HAIR)


def gloss(cv, pids, cx, cy, rx, ry, segs, r0, r1):
    """머리 광택 띠 — 두개골 곡률을 따라 도는 호.  길이가 다른 토막으로 끊는다."""
    for y in range(GH):
        for x in range(GW):
            if cv.pid[y][x] not in pids:
                continue
            u, v = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            rad = math.sqrt(u * u + v * v)
            if not (r0 <= rad <= r1):
                continue
            ang = math.degrees(math.atan2(-v, u))
            for (a0, a1, t0, t1) in segs:
                if a0 <= ang <= a1:
                    f = (ang - a0) / float(a1 - a0)
                    lo = r0 + (r1 - r0) * (1 - t0 * (1 - f) - t1 * f) * 0.5
                    hi = r1 - (r1 - r0) * (1 - t0 * (1 - f) - t1 * f) * 0.5
                    if lo <= rad <= hi:
                        cv.ch[y][x] = 'l'
                    break


def backhair(cv, pids, strands):
    """뒤통수 가닥.  한 점에서 뻗어나가게 그리면 거미가 된다.
    출발점을 흩고, 중력 따라 흘러내리게, 길이를 제각각으로."""
    for (pts, w) in strands:
        cv.stroke_in(pids, pts, w, 'j')


def shade_head(cv, sex, view):
    fl, fr = head_edges(view)
    hline, hpts = hairline_of(sex, view)
    F = (P_FACE,)
    if view != 'up':
        # 앞머리 그늘 — 앞머리를 그대로 따라가면 지그재그가 두 겹이 된다.
        # 뭉갠 선을 바닥으로 삼아 띠 두께가 제각각이 되게 한다.
        soft = lowpass(hline, 20, 172, 13)
        for x in range(GW):
            y0 = hline(x + .5)
            y1 = max(y0 + 2.0, soft(x + .5) + 3.0)
            for y in range(int(y0), int(y1)):
                cv.pin(F, x, y, 'c')
            for y in range(int(y1), int(y1) + 2):
                cv.pin(F, x, y, 'd')
        # 오른뺨 그늘 / 왼뺨 빛
        rsh = (pchip([(40, 14), (70, 11), (95, 10), (115, 11), (133, 14)])
               if view != 'side' else
               pchip([(40, 22), (70, 18), (95, 16), (115, 14), (133, 11)]))
        for y in range(38, CHIN + 1):
            cv.rin(F, y, fr(y) - rsh(y), fr(y), 'c')
        lsh = pchip([(40, 7), (70, 6), (95, 5.5), (115, 6), (133, 8)])
        for y in range(40, CHIN + 1):
            cv.rin(F, y, fl(y), fl(y) + lsh(y), 'b')
        # 턱 아래 그늘
        for y in range(CHIN - 7, CHIN + 1):
            t = (y - (CHIN - 7)) / 7.0
            cv.rin(F, y, CX - 30 * (1 - t * 0.4), CX + 30 * (1 - t * 0.4), 'c')
        for y in range(CHIN - 2, CHIN + 1):
            cv.rin(F, y, CX - 20, CX + 20, 'e')
    # --- 머리카락 음영 ---
    H = (P_HAIR, P_HAIR2)
    sx = 6 if view == 'side' else 0
    cv.ein(H, CX - 22 + sx, 50, 58, 52, 'i')
    cv.ein(H, CX - 36 + sx, 38, 34, 30, 'i')
    cv.ein_out(H, CX - 12 + sx, 62, 74, 70, 'j')
    gloss(cv, H, CX + sx, 78, 67, 74, [(99, 119, 0.40, 1.0),
                                       (127, 149, 1.0, 0.55),
                                       (155, 166, 0.45, 0.25)], 0.600, 0.672)
    if view == 'up':
        cv.ein(H, CX - 20, 44, 50, 42, 'i')
        if sex == 'boy':
            backhair(cv, H, [
                ([(79, 26), (73, 44)], 2.6),
                ([(115, 34), (121, 55)], 2.4),
                ([(63, 74), (60, 92)], 2.0),
                ([(100, 116), (102, 133)], 2.2),
                ([(129, 96), (133, 111)], 1.9)])
        else:
            backhair(cv, H, [
                ([(74, 30), (66, 56)], 2.8),
                ([(117, 40), (124, 68)], 2.4),
                ([(57, 104), (54, 132)], 2.2),
                ([(132, 122), (130, 152)], 2.0),
                ([(88, 150), (86, 176)], 1.9),
                ([(110, 182), (112, 206)], 2.2)])
    else:
        # 가닥마다 오른쪽 아랫단을 어둡게 — 긁힌 자국을 긋지 않는다
        for i in range(1, len(hpts) - 1):
            x0, y0 = hpts[i]
            if y0 <= hpts[i - 1][1] or y0 <= hpts[i + 1][1]:
                continue
            xr = hpts[i + 1][0]
            for x in range(int(x0) + 1, int(xr) + 1):
                t = (x + .5 - x0) / max(1.0, xr - x0)
                d = 0.5 + 6.0 * t ** 1.6
                yb = hline(x + .5)
                for y in range(int(yb - d), int(yb) + 1):
                    if cv.ch[y][x] in 'hi':
                        cv.pin(H, x, y, 'j')


# ---------------------------------------------------------------- 몸통
def body_tables(sex, view):
    t = {}
    nar = 0.86 if view == 'side' else 1.0
    if sex == 'boy':
        t['tor_hw'] = pchip([(143, 15), (145, 20.5), (148, 26), (151, 29.5),
                             (156, 31.5), (165, 32), (175, 31), (185, 30),
                             (193, 30.5), (199, 31.5), (203, 31), (205, 28)])
        t['tor'] = (143, 205)
    else:
        t['tor_hw'] = pchip([(143, 14.5), (145, 19.5), (148, 24.5), (151, 27.5),
                             (157, 29), (166, 28.5), (176, 27), (184, 27),
                             (191, 28.5), (196, 29.5), (199, 28.5), (201, 26)])
        t['tor'] = (143, 201)
    t['nar'] = nar
    return t


def draw_body(cv, sex, view):
    t = body_tables(sex, view)
    hw = t['tor_hw']
    y0, y1 = t['tor']
    nar = t['nar']
    if view == 'side':
        def fl(y):
            return CX - 2 - hw(y) * nar * 1.06
        def fr(y):
            return CX - 2 + hw(y) * nar * 0.94
    else:
        def fl(y):
            return CX - hw(y)
        def fr(y):
            return CX + hw(y)
    cv.part(y0, y1, fl, fr, 'm', L_TOR, P_TOR)
    T = (P_TOR,)
    # 왼쪽 위 빛
    litw = pchip([(143, 11), (149, 19), (156, 23), (166, 21), (176, 17),
                  (188, 13), (y1, 10)])
    for y in range(y0, y1 + 1):
        cv.rin(T, y, 0, fl(y) + litw(y), 'o')
    for y in range(y0 + 4, y0 + 26):
        cv.rin(T, y, fl(y), fl(y) + 4.5, 'q')
    shw = pchip([(143, 5), (152, 9), (165, 12), (180, 13), (192, 11),
                 (y1, 9)])
    for y in range(y0, y1 + 1):
        cv.rin(T, y, fr(y) - shw(y), GW, 'n')
    # 깃 밑 그늘 — 깃에 가려 초승달만 남는다
    cv.ein(T, CX + (1 if view != 'side' else 2.5), y0 + 3.5, 16.0, 8.5, 'n')
    # 옷단 주름 — 높이를 어긋나게
    for (fx, fy, fh, fw) in ((-19, 8, 13, 2.8), (-6, 14, 9, 2.4),
                             (9, 6, 15, 3.0), (20, 12, 8, 2.6)):
        cv.stroke_in(T, [(CX + fx, y1 - fy), (CX + fx + 1.5, y1 - fy + fh)],
                     fw, 'n')
    # 깃
    cy0 = y0 - 1
    if view == 'up':
        cv.ell(CX, cy0 + 3.0, 17.5, 7.0, 'o', L_COL, P_COL)
        cv.ell(CX, cy0 + 1.0, 13.5, 4.4, 'n', L_COL, P_COL)
        cv.ein(T, CX, cy0 + 4, 15.5, 6.0, 'n')
    else:
        cx0 = CX + (1.5 if view == 'side' else 0)
        cv.ell(cx0, cy0 + 6.0, 17.0, 6.5, 'o', L_COL, P_COL)
        cv.ell(cx0, cy0 + 4.0, 13.0, 4.2, 'm', L_COL, P_COL)
        cv.ein((P_COL,), cx0 + 6, cy0 + 7.5, 8.0, 3.4, 'm')


def draw_neck(cv, sex, view):
    hwn = pchip([(120, 15.5), (130, 14.6), (140, 13.8), (152, 13.5)])
    dx = 0.0
    if view == 'side':
        dx = -1.5
    cv.part(120, 152, lambda y: CX + dx - hwn(y), lambda y: CX + dx + hwn(y),
            'a', L_NECK, P_NECK)
    N = (P_NECK,)
    for y in range(120, 153):
        cv.rin(N, y, 0, CX + dx - hwn(y) + 3.5, 'c')
        cv.rin(N, y, CX + dx + hwn(y) - 5.5, GW, 'c')
    if view != 'up':
        for y in range(CHIN - 1, CHIN + 4):
            cv.rin(N, y, 0, GW, 'e')
        for y in range(CHIN + 4, CHIN + 8):
            cv.rin(N, y, 0, GW, 'c')
    else:
        for y in range(126, 146):
            cv.rin(N, y, 0, GW, 'e')


# ---------------------------------------------------------------- 팔
def arm_curves(sex, view, side):
    """side: -1 왼팔(3/4 에서 가까운 팔), +1 오른팔(먼 팔)"""
    if sex == 'boy':
        inn = [(149, 26), (156, 28.5), (168, 30), (178, 31.5), (184, 32.5),
               (188, 31.2), (193, 30.8), (198, 32.6), (201, 36), (203, 39)]
        out = [(149, 26), (152, 33), (157, 40), (162, 43.5), (171, 44.5),
               (179, 43.5), (184, 42.4), (188, 44), (194, 45), (198, 44.2),
               (201, 42), (203, 39)]
        cuff = 179
    else:
        inn = [(149, 25), (156, 27), (168, 28.5), (176, 29.5), (182, 30),
               (186, 28.8), (191, 28.6), (196, 30.4), (199, 33.6), (201, 36.5)]
        out = [(149, 25), (152, 31), (157, 37.5), (162, 41), (170, 41.8),
               (177, 41), (182, 40), (186, 41.4), (192, 42.4), (196, 41.6),
               (199, 39.6), (201, 36.5)]
        cuff = 177
    if view == 'side':
        if side < 0:      # 가까운 팔 — 크고 앞에, 한 줄 늦게 더 멀리
            inn = [(y + 1, v * 0.62) for (y, v) in inn]
            out = [(y + 1, v * 1.06) for (y, v) in out]
        else:             # 먼 팔 — 작고 뒤에
            inn = [(y - 1, v * 0.74) for (y, v) in inn]
            out = [(y - 1, v * 0.94) for (y, v) in out]
    return pchip(inn), pchip(out), cuff


def draw_arm(cv, sex, view, side):
    inn, out, cuff = arm_curves(sex, view, side)
    near = (side < 0)
    lay = L_ARM if (view != 'side' or near) else L_ARMF
    hlay = lay - 1 if (view != 'side' or near) else lay
    pid = P_ARM_N if near else P_ARM_F
    hpid = P_HAND_N if near else P_HAND_F
    ox = 0.0
    if view == 'side':
        ox = -2.0 if near else -4.0
    y0, y1 = 149, 204
    cf = cuff + (0 if side < 0 else 2)

    def fl(y):
        return CX + ox + side * out(y) if side > 0 else CX + ox - out(y)

    def fr(y):
        return CX + ox + side * inn(y) if side > 0 else CX + ox - inn(y)
    lo = (lambda y: min(fl(y), fr(y)))
    hi = (lambda y: max(fl(y), fr(y)))
    for y in range(y0, y1 + 1):
        if lo(y) >= hi(y):
            continue
        if y < cf:
            cv.row(y, lo(y), hi(y), 'm', lay, pid)
        else:
            cv.row(y, lo(y), hi(y), 'a', hlay, hpid)
    # 소매단 — 바깥이 조금 더 내려온다
    for y in range(int(cf), int(cf) + 4):
        tt = (y - cf) / 4.0
        if side < 0:
            cv.rin((hpid,), y, lo(y), lo(y) + (hi(y) - lo(y)) * (1 - tt), 'm')
        else:
            cv.rin((hpid,), y, hi(y) - (hi(y) - lo(y)) * (1 - tt), hi(y), 'm')
    A, H = (pid,), (hpid,)
    dark = 'n' if not (view == 'side' and not near) else 'p'
    skd = 'c' if not (view == 'side' and not near) else 'e'
    if side < 0:
        for y in range(y0, y1 + 1):
            cv.rin(A, y, hi(y) - 9, hi(y), dark)
            cv.rin(H, y, hi(y) - 7, hi(y), skd)
            cv.rin(A, y, lo(y), lo(y) + 5, 'o')
            cv.rin(H, y, lo(y), lo(y) + 4, 'b')
        cv.stroke_in(A, [(CX + ox - out(158) + 3, 156),
                         (CX + ox - out(166) + 4, 168)], 3.0, 'q')
    else:
        for y in range(y0, y1 + 1):
            cv.rin(A, y, hi(y) - 8, hi(y), dark)
            cv.rin(H, y, hi(y) - 6, hi(y), skd)
            cv.rin(A, y, lo(y), lo(y) + 4, 'm' if view == 'side' else 'o')
            cv.rin(H, y, lo(y), lo(y) + 3, 'a' if view == 'side' else 'b')
    if view == 'side' and not near:
        cv.rin(A, 0, 0, 0, 'n')
        for y in range(y0, y1 + 1):
            cv.rin(A, y, 0, GW, 'n')
            cv.rin(H, y, 0, GW, 'c')
        for y in range(y0, y1 + 1):
            cv.rin(A, y, hi(y) - 6, hi(y), 'p')
            cv.rin(H, y, hi(y) - 5, hi(y), 'e')
    # 손가락 — 두 줄만
    fy = 187 if sex == 'boy' else 185
    for d in (0, 5):
        cv.stroke_in(H, [(CX + ox + side * (inn(fy) + 4 + d), fy + 4),
                         (CX + ox + side * (inn(fy) + 4 + d), fy + 11)],
                     2.2, skd)
    # 팔 안쪽 경계선 (같은 재질이라 자동 윤곽이 안 생긴다)
    for y in range(y0, y1 + 1):
        if lo(y) >= hi(y):
            continue
        e = (hi(y) if side < 0 else lo(y))
        cc = 'p' if y < cf else 'f'
        cv.rin((pid, hpid), y, e - 2.0, e, cc) if side < 0 else \
            cv.rin((pid, hpid), y, e, e + 2.0, cc)


# ---------------------------------------------------------------- 하체
def draw_lower_boy(cv, view):
    hip = pchip([(188, 28.5), (194, 30.5), (200, 31), (208, 31)])
    gap = pchip([(206, 0), (209, 1.6), (213, 2.8), (230, 3.0), (250, 3.2)])
    out = pchip([(188, 28.5), (196, 30.5), (206, 31), (218, 30.6),
                 (232, 30.0), (246, 29.4), (250, 29.2)])
    sq = 0.9 if view == 'side' else 1.0
    dx = -2.0 if view == 'side' else 0.0
    for y in range(188, 251):
        if y <= 206:
            cv.row(y, CX + dx - hip(y) * sq, CX + dx + hip(y) * sq, 'r',
                   L_LOW, P_LOW)
        else:
            g, o = gap(y) * sq, out(y) * sq
            cv.row(y, CX + dx - o, CX + dx - g, 'r', L_LOW, P_LOW)
            cv.row(y, CX + dx + g * (0.2 if view == 'side' else 1.0),
                   CX + dx + o, 'r', L_LOW, P_LOW)
    L = (P_LOW,)
    for y in range(188, 251):
        o = out(y) * sq
        cv.rin(L, y, CX + dx - o, CX + dx - o + 6.5, 't')
        cv.rin(L, y, CX + dx + o - 8, CX + dx + o, 's')
        if y > 206:
            cv.rin(L, y, CX + dx - gap(y) * sq - 5, CX + dx + gap(y) * sq + 5,
                   's')
    for y in range(188, 197):
        cv.rin(L, y, 0, GW, 's')
    if view == 'side':
        for y in range(207, 251):
            cv.rin(L, y, CX + dx + gap(y) * sq - 3, GW, 's')
            e = CX + dx + gap(y) * sq
            cv.rin(L, y, e - 2.4, e, 'u')
    # 무릎 주름 — 좌우 높이를 어긋나게
    for (px, py, ph, pw) in ((-24, 222, 10, 3.0), (-13, 236, 7, 2.6),
                             (14, 228, 11, 3.0), (25, 243, 6, 2.6)):
        cv.stroke_in(L, [(CX + dx + px, py), (CX + dx + px + 2, py + ph)],
                     pw, 's')
    # 장화
    bo = pchip([(244, 31.0), (250, 32.6), (258, 32.2), (270, 32.6),
                (279, 33.4), (283, 33.2), (286, 31.6)])
    bi = pchip([(244, 2.6), (252, 3.0), (268, 3.4), (280, 4.2), (286, 5.0)])
    for y in range(244, 287):
        g, o = bi(y) * sq, bo(y) * sq
        if view == 'side':
            cv.row(y, CX + dx - o, CX + dx - g * 0.2, 'w', L_SHOE, P_SHOE)
            cv.row(y, CX + dx + g * 0.1, CX + dx + o * 0.92, 'w', L_SHOE,
                   P_SHOE)
        else:
            cv.row(y, CX + dx - o, CX + dx - g, 'w', L_SHOE, P_SHOE)
            cv.row(y, CX + dx + g, CX + dx + o, 'w', L_SHOE, P_SHOE)
    S = (P_SHOE,)
    for y in range(244, 287):
        o = bo(y) * sq
        cv.rin(S, y, CX + dx + o - 9, CX + dx + o, 'x')
        cv.rin(S, y, CX + dx - bi(y) * sq - 4, CX + dx + bi(y) * sq + 4, 'x')
    for y in range(275, 287):
        cv.rin(S, y, 0, GW, 'x')
    for y in range(250, 256):
        cv.rin(S, y, 0, GW, 'x')
    if view == 'side':
        for y in range(244, 287):
            e = CX + dx + bi(y) * sq
            cv.rin(S, y, e - 1, GW, 'x')
            cv.rin(S, y, e - 2.4, e, 'y')


def draw_lower_girl(cv, view):
    hem = 232.0
    hw = pchip([(184, 27), (190, 28.5), (197, 31.5), (206, 36), (215, 41),
                (224, 45.5), (230, 47.5), (233, 48)])
    sq = 0.9 if view == 'side' else 1.0
    dx = -2.0 if view == 'side' else 0.0
    # 치맛단이 가운데가 처진다
    def hemy(x):
        return hem + 3.4 - 5.0 * ((x - (CX + dx)) / 48.0) ** 2
    for y in range(184, 240):
        a = CX + dx - hw(y) * sq * (1.06 if view == 'side' else 1.0)
        b = CX + dx + hw(y) * sq * (0.94 if view == 'side' else 1.0)
        xa, xb = int(math.ceil(a - .5)), int(math.floor(b - .5))
        for x in range(xa, xb + 1):
            if y <= hemy(x + .5):
                cv.put(x, y, 'r', L_LOW, P_LOW)
    L = (P_LOW,)
    for y in range(184, 240):
        a = CX + dx - hw(y) * sq
        b = CX + dx + hw(y) * sq
        cv.rin(L, y, a, a + 7, 't')
        cv.rin(L, y, b - 10, b, 's')
    for y in range(184, 192):
        cv.rin(L, y, 0, GW, 's')
    # 주름 — 굵기·길이·높이 제각각
    for (px, top, bot, w, cc) in ((-35, 209, 232, 3.4, 's'), (-24, 197, 224, 2.2, 's'),
                                  (-11, 204, 236, 2.8, 's'), (2, 213, 228, 2.0, 's'),
                                  (13, 199, 235, 3.6, 's'), (26, 207, 226, 2.4, 's'),
                                  (36, 216, 233, 3.0, 's'),
                                  (-30, 201, 221, 2.6, 't'), (-6, 218, 233, 2.2, 't'),
                                  (18, 211, 230, 2.0, 't')):
        x0 = CX + dx + px * 0.62
        x1 = CX + dx + px
        cv.stroke_in(L, [(x0, top), (x1, bot)], w, cc)
    # 맨다리
    lc = 15.0
    lhw = pchip([(224, 11.2), (236, 11.6), (248, 10.2), (260, 8.9), (266, 8.7)])
    for sgn in (-1, 1):
        c0 = CX + dx + sgn * lc * (0.62 if view == 'side' else 1.0) + \
            (2.0 if (view == 'side' and sgn > 0) else 0.0)
        cv.part(224, 268, lambda y, c=c0: c - lhw(y), lambda y, c=c0: c + lhw(y),
                'a', L_LEG, P_LEG)
        G = (P_LEG,)
        for y in range(224, 269):
            cv.rin(G, y, c0 + lhw(y) - 5.5, c0 + lhw(y), 'c')
            cv.rin(G, y, c0 - lhw(y), c0 - lhw(y) + 3.5, 'b')
        if view == 'side' and sgn > 0:
            for y in range(224, 269):
                cv.rin(G, y, c0 - lhw(y), GW, 'c')
                cv.rin(G, y, c0 - lhw(y), c0 - lhw(y) + 2.2, 'f')
    # 단화
    sh = pchip([(266, 12.0), (272, 13.2), (279, 14.0), (284, 14.4), (286, 13.6)])
    for sgn in (-1, 1):
        c0 = CX + dx + sgn * lc * (0.62 if view == 'side' else 1.0) + \
            (2.0 if (view == 'side' and sgn > 0) else 0.0)
        cv.part(266, 286, lambda y, c=c0: c - sh(y) - (1.5 if sgn < 0 else 0),
                lambda y, c=c0: c + sh(y) + (1.5 if sgn > 0 else 0),
                'w', L_SHOE, P_SHOE)
        S = (P_SHOE,)
        for y in range(266, 287):
            cv.rin(S, y, c0 + sh(y) - 6, c0 + sh(y) + 2, 'x')
        for y in range(280, 287):
            cv.rin(S, y, 0, GW, 'x')


# ---------------------------------------------------------------- 여자 긴머리
def draw_longhair(cv, view):
    if view == 'up':
        out = pchip([(HTOP, 8), (40, 48), (70, 63), (95, 63), (120, 57),
                     (145, 48), (165, 41), (182, 36), (196, 34), (208, 31),
                     (216, 28), (220, 26)])
        tipY = leafline(150, [(CX - 26, 210, 0.075, 0.065, 1.7),
                              (CX + 5, 218, 0.06, 0.07, 1.7),
                              (CX + 31, 206, 0.05, 0.09, 1.7)])
        for y in range(HTOP, 220):
            if y <= CHIN:
                a = min(CX - HEAD_HW(y), CX - out(y))
                b = max(CX + HEAD_HW(y), CX + out(y))
            else:
                a, b = CX - out(y), CX + out(y)
            xa, xb = int(math.ceil(a - .5)), int(math.floor(b - .5))
            for x in range(xa, xb + 1):
                if y <= tipY(x + .5):
                    cv.put(x, y, 'h', L_HAIR2, P_HAIR2)
        H = (P_HAIR, P_HAIR2)
        cv.ein(H, CX - 22, 60, 56, 58, 'i')
        cv.ein_out(H, CX - 12, 66, 76, 80, 'j')
        for (gx, gw, gy, gh) in ((CX - 44, 14, 44, 4.4), (CX - 20, 20, 38, 4.8),
                                 (CX + 10, 10, 40, 3.8)):
            cv.ein(H, gx, gy, gw, gh, 'l')
        for (x0, y0, x1, y1, w) in ((CX - 40, 96, CX - 44, 150, 3.4),
                                    (CX - 14, 120, CX - 18, 186, 3.0),
                                    (CX + 16, 104, CX + 22, 164, 3.2),
                                    (CX + 40, 132, CX + 44, 192, 2.8),
                                    (CX - 30, 150, CX - 33, 198, 2.4)):
            cv.stroke_in(H, [(x0, y0), (x1, y1)], w, 'j')
        return
    # down / side — 옆갈래가 어깨를 덮는다
    if view == 'side':
        specs = [(-1, pchip([(70, 67), (95, 66), (112, 63), (130, 60),
                             (148, 56), (162, 51), (172, 44), (178, 34),
                             (181, 25)]),
                  pchip([(70, 52), (90, 51), (105, 48), (118, 42), (130, 38),
                         (142, 31), (154, 28), (166, 33), (176, 33),
                         (181, 25)])),
                 (+1, pchip([(70, 66), (95, 65), (115, 64), (140, 63),
                             (165, 61), (186, 57), (199, 50), (208, 40),
                             (213, 28)]),
                  pchip([(70, 54), (88, 53), (104, 50), (118, 44), (130, 39),
                         (144, 30), (158, 26), (174, 29), (190, 34),
                         (202, 36), (213, 28)]))]
    else:
        specs = [(-1, pchip([(70, 67), (95, 65.5), (112, 63), (132, 61),
                             (152, 59.5), (172, 56.5), (186, 51), (196, 42),
                             (202, 31)]),
                  pchip([(70, 56.5), (85, 56), (100, 53.5), (112, 46.5),
                         (122, 43), (133, 38), (145, 31), (158, 28.5),
                         (170, 34.5), (182, 41), (192, 41.5), (202, 31)])),
                 (+1, pchip([(70, 67), (95, 65.5), (112, 62.5), (132, 60.5),
                             (152, 58.5), (170, 55.5), (182, 50), (192, 41),
                             (198, 31)]),
                  pchip([(70, 56), (85, 55.5), (100, 53), (112, 46),
                         (122, 42), (133, 37), (144, 30), (156, 27.5),
                         (168, 33.5), (180, 40), (189, 40.5), (198, 31)]))]
    for (sgn, ou, ins) in specs:
        sx = 0.0
        if view == 'side':
            sx = 6.0 if sgn > 0 else 2.0
        for y in range(70, 216):
            o, i = ou(y), ins(y)
            if o <= i:
                continue
            a = CX + sx + sgn * i
            b = CX + sx + sgn * o
            cv.row(y, min(a, b), max(a, b), 'h', L_HAIR2, P_HAIR2)
    H = (P_HAIR, P_HAIR2)
    sx = 6 if view == 'side' else 0
    cv.ein(H, CX - 22 + sx, 56, 56, 54, 'i')
    cv.ein_out(H, CX - 14 + sx, 66, 76, 76, 'j')
    for (gx, gw, gy, gh) in ((CX - 46 + sx, 13, 46, 4.2),
                             (CX - 23 + sx, 20, 39, 4.6),
                             (CX + 8 + sx, 9, 41, 3.6)):
        cv.ein(H, gx, gy, gw, gh, 'l')
    for (x0, y0, x1, y1, w) in ((CX - 52, 110, CX - 56, 164, 3.2),
                                (CX - 44, 140, CX - 47, 190, 2.6),
                                (CX + 50, 104, CX + 54, 152, 3.0),
                                (CX + 42, 136, CX + 45, 184, 2.6)):
        cv.stroke_in(H, [(x0 + sx, y0), (x1 + sx, y1)], w, 'j')


# ---------------------------------------------------------------- 귀
def draw_ear(cv, view, sex):
    if sex == 'girl':
        return
    fl, fr = head_edges(view)
    for sgn in (-1, 1):
        if view == 'side' and sgn > 0:
            continue
        cy, ry = (102.0, 9.0) if view == 'side' else \
            ((101.0, 8.5) if view == 'down' else (101.0, 7.0))
        ex = (fl(cy) if sgn < 0 else fr(cy)) - sgn * 1.6
        cv.ell(ex, cy - 2, 4.4 if view != 'up' else 3.6, ry, 'a', L_HAIR, P_EAR)
        cv.ein((P_EAR,), ex - sgn * 1.4, cy - 0.5, 2.2, ry * 0.5, 'c')
        cv.ein((P_EAR,), ex + sgn * 1.6, cy - ry * 0.75, 2.0, 2.2, 'b')


# ---------------------------------------------------------------- 조립
def build(sex, view):
    cv = Cv()
    if view == 'side':
        draw_arm(cv, sex, view, +1)
    draw_neck(cv, sex, view)
    if sex == 'boy':
        draw_lower_boy(cv, view)
    else:
        draw_lower_girl(cv, view)
    draw_body(cv, sex, view)
    if view != 'side':
        draw_arm(cv, sex, view, +1)
    draw_arm(cv, sex, view, -1)
    draw_head(cv, sex, view)
    draw_ear(cv, view, sex)
    if sex == 'girl':
        draw_longhair(cv, view)
    shade_head(cv, sex, view)
    if view != 'up':
        draw_face(cv, sex, view)
    return cv


# ---------------------------------------------------------------- 윤곽 + 출력
def outline(cv):
    out = [row[:] for row in cv.ch]
    for y in range(GH):
        for x in range(GW):
            ch = cv.ch[y][x]
            g = GRP.get(ch)
            if g is None:
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < GW and 0 <= ny < GH):
                    continue
                nch = cv.ch[ny][nx]
                if nch == '.':
                    edge = True
                    break
                ng = GRP.get(nch)
                if ng is None:
                    continue
                if ng != g and cv.lay[ny][nx] < cv.lay[y][x]:
                    edge = True
                    break
            if edge:
                out[y][x] = DARK[g]
    return out


def emit(grid, path):
    xs = [x for y in range(GH) for x in range(GW) if grid[y][x] != '.']
    ys = [y for y in range(GH) for x in range(GW) if grid[y][x] != '.']
    dx = int(round(95.5 - (min(xs) + max(xs)) / 2.0))
    dy = 286 - max(ys)
    im = Image.new('RGBA', (GW, GH), (0, 0, 0, 0))
    px = im.load()
    for y in range(GH):
        for x in range(GW):
            ch = grid[y][x]
            if ch == '.':
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < GW and 0 <= ny < GH:
                r, g, b = PAL[ch]
                px[nx, ny] = (r, g, b, 255)
    im.save(path)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    for sex in ('boy', 'girl'):
        for view in ('down', 'side', 'up'):
            cv = build(sex, view)
            emit(outline(cv), os.path.join(here, 'w192_c_%s_%s.png' % (sex, view)))
            print('w192_c_%s_%s.png' % (sex, view))


if __name__ == '__main__':
    main()
