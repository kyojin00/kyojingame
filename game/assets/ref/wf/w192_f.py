#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리틀 루트 주인공 192x288 — 방향 f.
조금 더 자란 비율(머리 = 키의 34%), 긴 팔다리, 촘촘한 옷 디테일.
192칸 격자에 직접 찍는다. 확대 금지.
"""
import math
from PIL import Image

# ----------------------------------------------------------------- palette
SK, SK_L, SK_D            = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD           = (82,53,33), (56,37,25), (39,26,18)
OL, EYE, BROW, WHT        = (26,20,28), (66,32,30), (136,70,42), (246,242,234)

TONES = {
  'sk': {0:SK, 1:SK_L, 2:SK_D, 3:SK_DD, 4:SK_CH, 5:SK_M, 6:SK_LL},
  'hr': {0:HR, 1:HR_L, 2:HR_D, 3:HR_DD, 4:HR_LL},
  'sh': {0:SH, 1:SH_L, 2:SH_D, 3:SH_DD, 4:SH_LL},
  'pt': {0:PT, 1:PT_L, 2:PT_D, 3:PT_DD, 4:PT_LL},
  'so': {0:SO, 1:SO,   2:SO_D, 3:SO_DD, 4:SO},
  'ey': {0:EYE, 1:WHT, 2:OL,   3:OL,    4:BROW, 5:SK_D},
}
OUTL = {'sk':3, 'hr':3, 'sh':3, 'pt':3, 'so':3, 'ey':3}

OX, OY = 56, 40
MW, MH = 192 + 112, 288 + 80
XMIN, XMAX = -OX, MW - OX - 1
YMIN, YMAX = -OY, MH - OY - 1


class Grid(object):
    __slots__ = ('d',)

    def __init__(self):
        self.d = [[None] * MW for _ in range(MH)]

    def put(self, x, y, mat, tone):
        xx = x + OX
        yy = y + OY
        if 0 <= xx < MW and 0 <= yy < MH:
            self.d[yy][xx] = (mat, tone)

    def get(self, x, y):
        xx = x + OX
        yy = y + OY
        if 0 <= xx < MW and 0 <= yy < MH:
            return self.d[yy][xx]
        return None

    def clr(self, x, y):
        xx = x + OX
        yy = y + OY
        if 0 <= xx < MW and 0 <= yy < MH:
            self.d[yy][xx] = None


# ----------------------------------------------------------------- helpers
def disk(g, cx, cy, r, mat, tone, only=None):
    if r <= 0.0:
        return
    y0 = int(math.floor(cy - r - 1))
    y1 = int(math.ceil(cy + r + 1))
    for y in range(y0, y1 + 1):
        dy = y + 0.5 - cy
        if abs(dy) > r:
            continue
        dx = math.sqrt(r * r - dy * dy)
        x0 = int(math.ceil(cx - dx - 0.5))
        x1 = int(math.floor(cx + dx - 0.5))
        for x in range(x0, x1 + 1):
            if only is not None:
                c = g.get(x, y)
                if c is None or c[0] not in only:
                    continue
            g.put(x, y, mat, tone)


def ell(g, cx, cy, rx, ry, mat, tone, n=2.0, only=None):
    if rx <= 0 or ry <= 0:
        return
    y0 = int(math.floor(cy - ry - 1))
    y1 = int(math.ceil(cy + ry + 1))
    for y in range(y0, y1 + 1):
        v = abs((y + 0.5 - cy) / ry)
        if v > 1.0:
            continue
        if n == 2.0:
            f = math.sqrt(1.0 - v * v)
        else:
            f = (1.0 - v ** n) ** (1.0 / n)
        dx = rx * f
        x0 = int(math.ceil(cx - dx - 0.5))
        x1 = int(math.floor(cx + dx - 0.5))
        for x in range(x0, x1 + 1):
            if only is not None:
                c = g.get(x, y)
                if c is None or c[0] not in only:
                    continue
            g.put(x, y, mat, tone)


def limb(g, pts, mat, tone, shift=0.0, scale=1.0, only=None):
    for i in range(len(pts) - 1):
        x0, y0, r0 = pts[i]
        x1, y1, r1 = pts[i + 1]
        d = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(d * 4))
        for k in range(n + 1):
            t = k / float(n)
            rr = r0 + (r1 - r0) * t
            disk(g, x0 + (x1 - x0) * t + shift * rr, y0 + (y1 - y0) * t,
                 rr * scale, mat, tone, only)


def cyl(g, pts, mat, lit=1, drk=2, base=0, lw=0.30):
    """원통 음영: 밑칠 + 오른쪽 그늘 + 왼쪽 하이라이트 (빛은 왼쪽 위)."""
    limb(g, pts, mat, base)
    limb(g, pts, mat, drk, shift=0.44, scale=0.58)
    limb(g, pts, mat, lit, shift=-0.62, scale=lw)


def band(g, y0, y1, cf, wf, mat, tone, excl=None, only=None):
    for y in range(y0, y1 + 1):
        c = cf(y) if callable(cf) else cf
        w = wf(y) if callable(wf) else wf
        if w <= 0:
            continue
        x0 = int(math.ceil(c - w - 0.5))
        x1 = int(math.floor(c + w - 0.5))
        for x in range(x0, x1 + 1):
            if excl is not None and excl(x + 0.5, y + 0.5):
                continue
            if only is not None:
                cc = g.get(x, y)
                if cc is None or cc[0] not in only:
                    continue
            g.put(x, y, mat, tone)


def shade(g, box, pred, mats, tone):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = g.get(x, y)
            if c is None or c[0] not in mats:
                continue
            if pred(x + 0.5, y + 0.5):
                g.put(x, y, c[0], tone)


def smooth(t):
    return t * t * (3.0 - 2.0 * t)


def curve(pts):
    """[(a, b), ...] a 오름차순.  f(a) -> b, 매끄러운 보간."""
    pts = sorted(pts)

    def f(a):
        if a <= pts[0][0]:
            return pts[0][1]
        if a >= pts[-1][0]:
            return pts[-1][1]
        for i in range(len(pts) - 1):
            a0, b0 = pts[i]
            a1, b1 = pts[i + 1]
            if a0 <= a <= a1:
                t = smooth((a - a0) / float(a1 - a0))
                return b0 + (b1 - b0) * t
        return pts[-1][1]
    return f


def edge_over(g, box, top, bots, tone, dirs):
    x0, y0, x1, y1 = box
    hits = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = g.get(x, y)
            if c is None or c[0] != top:
                continue
            for dx, dy in dirs:
                n = g.get(x + dx, y + dy)
                if n is not None and n[0] in bots:
                    hits.append((x, y))
                    break
    for x, y in hits:
        g.put(x, y, top, tone)


def cast_shadow(g, box, srcs, dst, tone, off, reach):
    ox, oy = off
    hits = []
    for y in range(box[1], box[3] + 1):
        for x in range(box[0], box[2] + 1):
            c = g.get(x, y)
            if c is None or c[0] != dst:
                continue
            for k in range(1, reach + 1):
                n = g.get(x - ox * k, y - oy * k)
                if n is not None and n[0] in srcs:
                    hits.append((x, y))
                    break
    for x, y in hits:
        g.put(x, y, dst, tone)


def prune(g, minsize=24):
    """떠 있는 부스러기 제거 — 연결 요소는 하나여야 한다."""
    seen = [[False] * MW for _ in range(MH)]
    comps = []
    for y in range(MH):
        for x in range(MW):
            if g.d[y][x] is not None and not seen[y][x]:
                st = [(x, y)]
                seen[y][x] = True
                cells = []
                while st:
                    cx, cy = st.pop()
                    cells.append((cx, cy))
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < MW and 0 <= ny < MH and not seen[ny][nx] \
                                and g.d[ny][nx] is not None:
                            seen[ny][nx] = True
                            st.append((nx, ny))
                comps.append(cells)
    if len(comps) <= 1:
        return
    comps.sort(key=len)
    for c in comps[:-1]:
        for (x, y) in c:
            g.d[y][x] = None


def outline(g):
    src = [row[:] for row in g.d]
    for y in range(MH):
        row = src[y]
        for x in range(MW):
            c = row[x]
            if c is None:
                continue
            if (x + 1 >= MW or src[y][x + 1] is None or
                    x - 1 < 0 or src[y][x - 1] is None or
                    y + 1 >= MH or src[y + 1][x] is None or
                    y - 1 < 0 or src[y - 1][x] is None):
                g.d[y][x] = (c[0], OUTL[c[0]])


def rim(g):
    """윤곽 안쪽 오른/아래 한 칸을 어둡게 — 축소했을 때 선이 살아난다."""
    src = [row[:] for row in g.d]
    for y in range(MH):
        for x in range(MW):
            c = src[y][x]
            if c is None or c[0] == 'ey':
                continue
            if c[1] == OUTL[c[0]]:
                continue
            hit = False
            for dx, dy in ((1, 0), (0, 1), (1, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < MW and 0 <= ny < MH:
                    n = src[ny][nx]
                    if n is not None and n[0] == c[0] and n[1] == OUTL[c[0]]:
                        hit = True
                        break
            if hit and c[1] in (0, 1):
                g.d[y][x] = (c[0], 2)


# ----------------------------------------------------------------- head box
def base_w(y, mid=58.0, rtop=50.0, rbot=46.0, R=41.0, nb=2.6):
    if y < mid:
        t = (mid - y) / rtop
        if t >= 1.0:
            return 0.0
        return R * math.sqrt(1.0 - t * t)
    t = (y - mid) / rbot
    if t >= 1.0:
        return 0.0
    return R * (1.0 - t ** nb) ** (1.0 / nb)


HEAD_TOP = 9
CHIN = 103
BACK_BOT = 99


def head_edges(view):
    """(L(y), R(y), ytop, ybot)"""
    if view == 'up':
        def w(y):
            return base_w(y, rbot=41.0, nb=2.1)

        def L(y):
            return 96.0 - w(y)

        def R(y):
            return 96.0 + w(y)
        return L, R, HEAD_TOP, BACK_BOT
    if view == 'down':
        def L(y):
            return 96.0 - base_w(y)

        def R(y):
            return 96.0 + base_w(y)
        return L, R, HEAD_TOP, CHIN

    # side : 3/4, 오른쪽을 비스듬히 본다
    def jaw_shift(y):
        if y <= 72:
            return 0.0
        return 5.4 * ((y - 72) / 31.0) ** 1.5

    def occ(y):          # 뒤통수가 살짝 부풀어
        if 18 <= y <= 74:
            return 1.6 * math.sin((y - 18) / 56.0 * math.pi)
        return 0.0

    def nose(y):         # 코가 실루엣을 살짝 밀고 나간다
        if 78 <= y <= 94:
            return 2.0 * math.sin((y - 78) / 16.0 * math.pi) ** 1.4
        return 0.0

    def L(y):
        return 98.0 - base_w(y) - occ(y) + jaw_shift(y) * 1.55

    def R(y):
        return 98.0 + base_w(y) * 0.985 + nose(y) + jaw_shift(y) * 0.55
    return L, R, HEAD_TOP, CHIN


def head_skin(g, sex, view):
    L, R, y0, y1 = head_edges(view)
    for y in range(y0, y1 + 1):
        xl = int(math.ceil(L(y) - 0.5))
        xr = int(math.floor(R(y) - 0.5))
        for x in range(xl, xr + 1):
            g.put(x, y, 'sk', 0)


# ----------------------------------------------------------------- neck
def neck_cx(view):
    if view == 'side':
        return 94.0
    return 96.0


def draw_neck(g, sex, view):
    cx = neck_cx(view)
    w = 11.0 if sex == 'boy' else 10.0
    if view == 'up':
        w -= 1.4
    top = 88 if view == 'up' else 94
    for y in range(top, 126):
        ww = w + (0.8 if y > 114 else 0.0) + (1.6 if y > 119 else 0.0) + (1.4 if y > 122 else 0.0)
        x0 = int(math.ceil(cx - ww - 0.5))
        x1 = int(math.floor(cx + ww - 0.5))
        for x in range(x0, x1 + 1):
            g.put(x, y, 'sk', 0)
    box = (int(cx - 18), top, int(cx + 18), 126)
    shade(g, box, lambda x, y: x > cx - 6.0, ('sk',), 2)
    shade(g, box, lambda x, y: x < cx - 8.5, ('sk',), 1)
    if view != 'up':
        # 턱 그림자 — 위 두세 줄만, 오른쪽으로 치우쳐
        shade(g, box, lambda x, y: y < 101 + 2.0 * (x - cx) / 9.0 and x > cx - 8.0, ('sk',), 5)
    else:
        shade(g, box, lambda x, y: y < 104, ('sk',), 2)


# ----------------------------------------------------------------- torso
def shirt_prof(sex, view):
    """(cx, w(y), ytop, yhem) — 몸통만.  소매는 따로."""
    if sex == 'boy':
        chest, waist, hem, flare = 24.8, 23.2, 183, 3.4
    else:
        chest, waist, hem, flare = 23.4, 21.4, 177, 4.2
    if view == 'side':
        chest -= 2.0
        waist -= 1.6
    cx = 95.0 if view == 'side' else 96.0

    def w(y):
        if y < 128:
            return chest - (chest - 11.5) * ((128 - y) / 16.0) ** 1.9
        if y < 158:
            return chest - (chest - waist) * ((y - 128) / 30.0) ** 1.4
        return waist + flare * ((y - 158) / float(hem - 158)) ** 1.7
    return cx, w, 112, hem


SLEEVE = {
    'boy':  [(116, 18.5), (119, 23.5), (123, 28.0), (129, 31.0), (137, 32.2),
             (145, 31.8), (152, 30.6), (157, 28.4)],
    'girl': [(116, 18.5), (119, 24.0), (123, 29.0), (128, 31.8), (134, 32.6),
             (140, 31.6), (146, 29.0), (149, 25.5)],
}


def sleeve_spec(sex, view, side):
    pts = SLEEVE[sex]
    k = 1.0
    dy = 0
    if view == 'side':
        k = 1.07 if side < 0 else (0.68 if sex == 'girl' else 0.76)
        dy = 2 if side < 0 else -2
    f = curve([(y + dy, w * k) for (y, w) in pts])
    y0 = pts[0][0] + dy
    y1 = pts[-1][0] + dy
    if view == 'side' and side > 0:
        y1 -= 6
    _, tw, _, _ = shirt_prof(sex, view)

    def inn(y):
        return min(19.0, max(6.0, tw(y) - 1.5))
    return f, y0, y1, inn


def draw_sleeve(g, sex, view, side):
    cx, tw, ytop, hem = shirt_prof(sex, view)
    out, y0, y1, innf = sleeve_spec(sex, view, side)
    cells = []
    for y in range(y0, y1 + 1):
        o = out(y)
        inn = innf(y)
        if o <= inn:
            continue
        a = cx + side * inn
        b = cx + side * o
        lo, hi = min(a, b), max(a, b)
        for x in range(int(math.ceil(lo - 0.5)), int(math.floor(hi - 0.5)) + 1):
            g.put(x, y, 'sh', 0)
            cells.append((x, y))
    # 소매 음영 — 어깨 위가 밝고 소매 끝 안쪽이 어둡다
    for (x, y) in cells:
        o = out(y)
        t = (cx + side * o - (x + 0.5)) * side * -1.0
        ph = (y - y0) / float(y1 - y0 + 1)
        if side < 0:
            lit = t < 6.5 - 5.0 * ph + 1.2 * math.sin(y / 7.0)
            drk = t > 12.0 - 6.0 * ph
        else:
            lit = t > (o - inn) - 4.5 and ph < 0.38
            drk = t < 9.0 + 5.0 * ph
        if lit:
            g.put(x, y, 'sh', 1)
        elif drk:
            g.put(x, y, 'sh', 2)
    # 진동 솔기 — 짧게 두 도막
    seam = curve([(y0, cx + side * (innf(y0) + 0.5)), (y0 + 9, cx + side * (innf(y0 + 9) + 2.0)),
                  (y1 - 4, cx + side * (innf(y1 - 4) + 3.0))])
    for y in list(range(y0 + 4, y0 + 14)) + list(range(y0 + 17, y1 - 9)):
        x = int(round(seam(y) - 0.5))
        c = g.get(x, y)
        if c is not None and c[0] == 'sh':
            g.put(x, y, 'sh', 2)
    return cells


def neckline(sex, view):
    cx = neck_cx(view)
    if view == 'up':
        return cx, 108.0, 16.0, 5.5
    if sex == 'boy':
        return cx + (4.0 if view == 'side' else 0.0), 110.0, 16.5, 12.0
    return cx + (4.0 if view == 'side' else 0.0), 111.0, 15.0, 13.5


def torso_asym(view, ytop):
    if view != 'side':
        return (lambda y: 0.0), (lambda y: 0.0)
    r = curve([(ytop, 0.0), (ytop + 10, 0.7), (ytop + 24, 1.0), (200, 1.0)])
    return (lambda y: 2.6 * r(y)), (lambda y: -2.8 * r(y))


def draw_torso(g, sex, view):
    cx, w, ytop, hem = shirt_prof(sex, view)
    nx, ny, nrx, nry = neckline(sex, view)
    al, ar = torso_asym(view, ytop)

    def hemline(x):
        h = hem + 1.6 * math.sin((x - 61.0) / 12.5) - 1.0 * math.sin((x - 61.0) / 31.0)
        if view == 'side':
            h -= 2.4 * max(0.0, (x - cx) / 26.0)
        return h

    for y in range(ytop, hem + 4):
        ww = w(y)
        if ww <= 0:
            continue
        lo = cx - ww - al(y)
        hi = cx + ww + ar(y)
        for x in range(int(math.ceil(lo - 0.5)), int(math.floor(hi - 0.5)) + 1):
            px, py = x + 0.5, y + 0.5
            if ((px - nx) / nrx) ** 2 + ((py - ny) / nry) ** 2 < 1.0:
                continue
            if py > hemline(px):
                continue
            g.put(x, y, 'sh', 0)

    box = (int(cx - 40), ytop - 2, int(cx + 40), hem + 4)
    dk = curve([(112, cx + 10.0), (124, cx + 16.0), (136, cx + 17.4),
                (148, cx + 15.8), (160, cx + 18.2), (172, cx + 16.4), (188, cx + 18.6)])
    lt = curve([(112, cx - 10.0), (126, cx - 17.0), (138, cx - 15.6),
                (152, cx - 18.8), (166, cx - 16.6), (182, cx - 19.4)])
    if view == 'side':
        dk = curve([(112, cx + 8.0), (126, cx + 12.0), (140, cx + 13.6),
                    (156, cx + 12.0), (172, cx + 14.2), (188, cx + 12.6)])
        lt = curve([(112, cx - 12.0), (128, cx - 18.4), (144, cx - 17.0),
                    (160, cx - 20.0), (176, cx - 18.2), (188, cx - 20.6)])
    shade(g, box, lambda x, y: x > dk(y), ('sh',), 2)
    shade(g, box, lambda x, y: x < lt(y), ('sh',), 1)


# ----------------------------------------------------------------- arms
def arm_paths(sex, view):
    """[(fore pts, hand, thumb, near?, sgn), ...]  먼 팔 먼저."""
    if sex == 'boy':
        f_r, h_r, ytop = 6.9, 7.8, 150
        off = 23.4
    else:
        f_r, h_r, ytop = 6.4, 7.3, 142
        off = 22.4
    cx = 95.0 if view == 'side' else 96.0
    out = []
    if view in ('down', 'up'):
        for sgn in (-1, 1):
            ax = cx + sgn * off
            fo = [(ax, ytop, f_r + 1.1), (ax - sgn * 0.6, 172.0, f_r + 0.2),
                  (ax - sgn * 1.6, 197.0, f_r - 0.5)]
            hd = (ax - sgn * 2.0, 205.5, h_r)
            th = (ax + sgn * 5.6, 199.0, 4.0)
            out.append((fo, hd, th, True, sgn))
        return out
    far_x = cx + off * 0.82
    far = ([(far_x, ytop - 4, f_r + 0.2), (far_x + 1.0, 170.0, f_r - 0.3),
            (far_x + 1.6, 192.0, f_r - 0.8)],
           (far_x + 2.0, 200.5, h_r - 1.4), (far_x - 5.0, 195.0, 3.2), False, 1)
    near_x = cx - off * 0.97
    near = ([(near_x, ytop + 2, f_r + 1.2), (near_x - 0.8, 174.0, f_r + 0.6),
             (near_x - 1.6, 199.0, f_r + 0.3)],
            (near_x - 2.4, 208.5, h_r + 0.5), (near_x + 6.0, 202.0, 4.2), True, -1)
    return [far, near]


def draw_arm(g, sex, view, spec):
    fo, hd, th, near, sgn = spec
    cyl(g, fo, 'sk')
    disk(g, th[0], th[1], th[2], 'sk', 0)
    disk(g, hd[0], hd[1], hd[2], 'sk', 0)
    disk(g, hd[0] + hd[2] * 0.44, hd[1] + 0.8, hd[2] * 0.58, 'sk', 2)
    disk(g, hd[0] - hd[2] * 0.50, hd[1] - hd[2] * 0.40, hd[2] * 0.26, 'sk', 1)
    fx, fy, fr = hd
    for k, dxk in enumerate((-0.34, 0.16)):
        gx = fx + fr * dxk
        gy = fy + fr * 0.40
        for t in range(2 + k):
            c = g.get(int(round(gx)), int(round(gy + t)))
            if c is not None and c[0] == 'sk':
                g.put(int(round(gx)), int(round(gy + t)), 'sk', 2)
    if not near:
        shade(g, (int(min(p[0] for p in fo) - 12), int(fo[0][1] - 4),
                  int(max(p[0] for p in fo) + 14), int(fy + fr + 2)),
              lambda x, y: True, ('sk',), 2)
    # 손목
    wx, wy, wr = fo[-1]
    for k in range(2):
        disk(g, wx, wy + k, wr - 0.4, 'sk', 2 if k else 0)


# ----------------------------------------------------------------- legs
def draw_legs_boy(g, view):
    cx = 95.0 if view == 'side' else 96.0
    if view == 'side':
        lcx, rcx = cx - 11.5, cx + 10.0
        lw, rw = 13.4, 12.2
    else:
        lcx, rcx = cx - 16.0, cx + 16.0
        lw = rw = 13.4

    def hip_excl(x, y):
        return y > 202.0 - 8.0 * math.exp(-((x - cx) / 10.0) ** 2)

    band(g, 168, 203, cx, lambda y: 29.6 - 1.2 * ((y - 168) / 35.0), 'pt', 0, excl=hip_excl)
    far = [(rcx, 190.0, rw), (rcx + 1.2, 222.0, rw - 1.0), (rcx + 1.6, 252.0, rw - 2.2)]
    near = [(lcx, 190.0, lw), (lcx - 1.2, 222.0, lw - 1.0), (lcx - 1.6, 252.0, lw - 2.2)]
    if view == 'side':
        cyl(g, far, 'pt')
        shade(g, (int(rcx - 20), 188, int(rcx + 20), 256), lambda x, y: True, ('pt',), 2)
        cyl(g, near, 'pt')
    else:
        cyl(g, far, 'pt')
        cyl(g, near, 'pt')
    box = (int(cx - 34), 166, int(cx + 34), 258)
    dk = curve([(168, cx + 15.0), (182, cx + 13.0), (196, cx + 12.4), (210, cx + 14.0)])
    shade(g, (int(cx - 34), 166, int(cx + 34), 204), lambda x, y: x > dk(y), ('pt',), 2)
    shade(g, (int(cx - 34), 166, int(cx + 34), 204), lambda x, y: x < cx - 19.0, ('pt',), 1)
    # 가랑이 주름 — 좌우 높이를 어긋나게
    for (sx, sy, ex, ey) in ((cx - 13, 196, cx - 5, 205), (cx + 12, 199, cx + 4, 207)):
        n = int(max(abs(ex - sx), abs(ey - sy)))
        for k in range(n + 1):
            t = k / float(n)
            g.put(int(round(sx + (ex - sx) * t)), int(round(sy + (ey - sy) * t)), 'pt', 2)
    # 무릎 주름 — 좌우 높이 어긋나게
    for (kx, ky, kw) in ((lcx - 0.8, 226, 7), (rcx + 0.8, 231, 6)):
        for i in range(-kw, kw + 1):
            t = i / float(kw)
            yy = int(ky + round(1.6 * t * t))
            c = g.get(int(kx + i), yy)
            if c is not None and c[0] == 'pt' and c[1] in (0, 1):
                g.put(int(kx + i), yy, 'pt', 2)
    # 주머니 — 높이 다르게
    for (px0, py0, pw, ph) in ((cx - 27, 180, 11, 13), (cx + 17, 183, 10, 12)):
        for yy in range(int(py0), int(py0 + ph)):
            for xx in range(int(px0), int(px0 + pw)):
                if (xx == int(px0) or yy == int(py0) or
                        yy == int(py0 + ph) - 1 and abs(xx - (px0 + pw / 2.0)) < pw / 2.0 - 1):
                    c = g.get(xx, yy)
                    if c is not None and c[0] == 'pt':
                        g.put(xx, yy, 'pt', 3)
    # 밑단
    for lx, rr in ((lcx - 1.6, lw - 2.2), (rcx + 1.6, rw - 2.2)):
        for k in range(4):
            disk(g, lx, 250 - k, rr + 0.3, 'pt', 2)
        disk(g, lx, 246, rr + 0.2, 'pt', 1)
    return (lcx - 1.6, rcx + 1.6, lw - 2.2, rw - 2.2)


def draw_boots(g, view, geo):
    lx, rx, lw, rw = geo
    order = ((rx, rw, False), (lx, lw, True))
    for (bx, bw, near) in order:
        toe = 0.0
        dz = 0
        if view == 'side':
            toe = 9.5 if near else 7.0
            dz = 0 if near else -3
        top = 246 + dz
        # 장화 목
        for y in range(top, 272):
            t = (y - top) / 26.0
            w = bw + 2.6 - 1.4 * smooth(min(1.0, t * 2.2))
            x0 = int(math.ceil(bx - w - 0.5))
            x1 = int(math.floor(bx + w - 0.5))
            for x in range(x0, x1 + 1):
                g.put(x, y, 'so', 0)
        # 발
        for y in range(268 + dz, 287 + dz):
            t = (y - (268 + dz)) / 18.0
            w = bw + 1.2 + 2.6 * smooth(min(1.0, t * 1.45))
            c = bx + toe * smooth(min(1.0, t * 1.15))
            x0 = int(math.ceil(c - w - 0.5))
            x1 = int(math.floor(c + w + toe * 0.30 - 0.5))
            for x in range(x0, x1 + 1):
                g.put(x, y, 'so', 0)
        box = (int(bx - 24), top - 2, int(bx + 30), 288)
        shade(g, box, lambda x, y: x > bx + bw * 0.55 + toe * 0.45, ('so',), 2)
        if not near and view == 'side':
            shade(g, box, lambda x, y: True, ('so',), 2)
        # 목 접힘
        for y in range(top, top + 6):
            for x in range(int(bx - bw - 4), int(bx + bw + 5)):
                c = g.get(x, y)
                if c is not None and c[0] == 'so':
                    g.put(x, y, 'so', 0 if y < top + 4 else 2)
        for x in range(int(bx - bw - 4), int(bx + bw + 5)):
            c = g.get(x, top + 6)
            if c is not None and c[0] == 'so':
                g.put(x, top + 6, 'so', 3)
        # 발등 이음
        for x in range(int(bx - bw - 3), int(bx + bw + toe + 5)):
            c = g.get(x, 272 + dz)
            if c is not None and c[0] == 'so':
                g.put(x, 272 + dz, 'so', 2)
        # 밑창
        for y in range(281 + dz, 287 + dz):
            for x in range(int(bx - bw - 6), int(bx + bw + toe + 8)):
                c = g.get(x, y)
                if c is not None and c[0] == 'so':
                    g.put(x, y, 'so', 3 if y >= 283 + dz else 2)
        if view == 'side' and not near:
            edge_over(g, box, 'so', ('pt',), 3, ((0, -1),))


def draw_legs_girl(g, view):
    cx = 95.0 if view == 'side' else 96.0
    if view == 'side':
        lcx, rcx = cx - 9.5, cx + 8.0
    else:
        lcx, rcx = cx - 13.0, cx + 13.0
    far = [(rcx, 208.0, 10.4), (rcx + 1.0, 238.0, 9.0), (rcx + 1.4, 266.0, 8.2)]
    near = [(lcx, 208.0, 10.6), (lcx - 1.0, 238.0, 9.2), (lcx - 1.4, 266.0, 8.4)]
    cyl(g, far, 'sk')
    if view == 'side':
        shade(g, (int(rcx - 16), 206, int(rcx + 16), 270), lambda x, y: True, ('sk',), 2)
    cyl(g, near, 'sk')
    # 무릎 — 살짝만
    for (kx, ky, kr) in ((lcx + 2.4, 233, 2.4), (rcx + 2.6, 236, 2.0)):
        disk(g, kx, ky, kr, 'sk', 2)
    for (ax, ay) in ((lcx - 1.4, 262), (rcx + 1.4, 264)):
        disk(g, ax + 1.6, ay, 2.2, 'sk', 2)
    return (lcx - 1.4, rcx + 1.4, 8.4, 8.2)


def draw_shoes(g, view, geo):
    lx, rx, lw, rw = geo
    for (bx, bw, near) in ((rx, rw, False), (lx, lw, True)):
        toe = 0.0
        dz = 0
        if view == 'side':
            toe = 8.5 if near else 6.0
            dz = 0 if near else -3
        for y in range(267 + dz, 287 + dz):
            t = (y - (267 + dz)) / 19.0
            w = bw + 1.8 + 2.8 * smooth(min(1.0, t * 1.5))
            c = bx + toe * smooth(min(1.0, t * 1.2))
            x0 = int(math.ceil(c - w - 0.5))
            x1 = int(math.floor(c + w + toe * 0.28 - 0.5))
            for x in range(x0, x1 + 1):
                g.put(x, y, 'so', 0)
        box = (int(bx - 22), 264 + dz, int(bx + 28), 288)
        shade(g, box, lambda x, y: x > bx + bw * 0.5 + toe * 0.45, ('so',), 2)
        if not near and view == 'side':
            shade(g, box, lambda x, y: True, ('so',), 2)
        for y in range(282 + dz, 287 + dz):
            for x in range(int(bx - bw - 6), int(bx + bw + toe + 8)):
                c = g.get(x, y)
                if c is not None and c[0] == 'so':
                    g.put(x, y, 'so', 3 if y >= 284 + dz else 2)
        # 발등 띠
        for x in range(int(bx - bw - 4), int(bx + bw + toe + 5)):
            c = g.get(x, 271 + dz)
            if c is not None and c[0] == 'so':
                g.put(x, 271 + dz, 'so', 3)


# ----------------------------------------------------------------- skirt
def draw_skirt(g, view):
    cx = 95.0 if view == 'side' else 96.0
    top, bot = 170, 218

    def w(y):
        return 25.0 + 16.0 * ((y - top) / float(bot - top)) ** 1.35

    hem = curve([(50, 216), (60, 219), (68, 215), (78, 220), (88, 216),
                 (96, 221), (104, 217), (114, 221), (122, 216), (132, 220), (142, 216)])

    def excl(x, y):
        return y > hem(x)

    band(g, top, bot + 4, cx, w, 'pt', 0, excl=excl)
    box = (int(cx - 46), top - 2, int(cx + 46), bot + 5)
    dkc = curve([(170, cx + 11.0), (186, cx + 13.5), (200, cx + 15.5), (218, cx + 18.0)])
    ltc = curve([(170, cx - 12.0), (188, cx - 15.0), (204, cx - 19.0), (218, cx - 23.0)])
    shade(g, box, lambda x, y: x > dkc(y), ('pt',), 2)
    shade(g, box, lambda x, y: x < ltc(y), ('pt',), 1)
    # 주름 — 시작 높이와 굵기를 제각각으로
    folds = ((cx - 30.0, 196, 2.4, 1.10), (cx - 17.5, 184, 1.9, 1.00),
             (cx - 5.0, 190, 2.2, 0.96), (cx + 8.5, 181, 1.7, 1.05),
             (cx + 20.0, 193, 2.3, 1.12), (cx + 31.0, 200, 1.8, 1.18))
    for (fx, fy, fw, spread) in folds:
        for y in range(fy, bot + 4):
            t = (y - top) / float(bot - top)
            xx = cx + (fx - cx) * (0.68 + 0.32 * spread * t * 2.0)
            ww = fw * (0.55 + 0.8 * (y - fy) / float(bot - fy + 1))
            for x in range(int(round(xx - ww)), int(round(xx + ww)) + 1):
                c = g.get(x, y)
                if c is not None and c[0] == 'pt' and c[1] != 3:
                    g.put(x, y, 'pt', 2)
    # 허리단
    for y in range(170, 176):
        for x in range(int(cx - 30), int(cx + 30)):
            c = g.get(x, y)
            if c is not None and c[0] == 'pt':
                g.put(x, y, 'pt', 1 if y < 173 else 2)
    for x in range(int(cx - 30), int(cx + 30)):
        c = g.get(x, 175)
        if c is not None and c[0] == 'pt':
            g.put(x, 175, 'pt', 3)


# ----------------------------------------------------------------- 옷 디테일
def shirt_details(g, sex, view):
    cx, w, ytop, hem = shirt_prof(sex, view)
    nx, ny, nrx, nry = neckline(sex, view)
    box = (int(cx - 40), ytop - 4, int(cx + 40), hem + 6)

    # 깃
    if view == 'up':
        for y in range(ytop - 1, ytop + 12):
            for x in range(int(nx - nrx - 7), int(nx + nrx + 8)):
                c = g.get(x, y)
                if c is None or c[0] != 'sh':
                    continue
                e = ((x + 0.5 - nx) / (nrx + 5.0)) ** 2 + ((y + 0.5 - ny) / (nry + 5.0)) ** 2
                if e < 1.0:
                    g.put(x, y, 'sh', 1 if x < nx else 0)
        for y in range(ytop - 1, ytop + 14):
            for x in range(int(nx - nrx - 9), int(nx + nrx + 10)):
                c = g.get(x, y)
                if c is None or c[0] != 'sh':
                    continue
                e = ((x + 0.5 - nx) / (nrx + 5.0)) ** 2 + ((y + 0.5 - ny) / (nry + 5.0)) ** 2
                if 0.94 < e < 1.16:
                    g.put(x, y, 'sh', 3)
    elif sex == 'boy':
        # 깃 두 쪽 — 짧게
        tris = (((nx - 0.5, ny + nry - 3), (nx - 1.5, ny + nry + 7), (nx - 11.0, ny + nry - 6)),
                ((nx + 1.5, ny + nry - 4), (nx + 2.5, ny + nry + 6), (nx + 12.0, ny + nry - 7)))
        for tri in tris:
            xs = [p[0] for p in tri]
            ys = [p[1] for p in tri]
            for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
                for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
                    c = g.get(x, y)
                    if c is None or c[0] != 'sh':
                        continue
                    px, py = x + 0.5, y + 0.5
                    d1 = ((tri[1][0] - tri[0][0]) * (py - tri[0][1]) -
                          (tri[1][1] - tri[0][1]) * (px - tri[0][0]))
                    d2 = ((tri[2][0] - tri[1][0]) * (py - tri[1][1]) -
                          (tri[2][1] - tri[1][1]) * (px - tri[1][0]))
                    d3 = ((tri[0][0] - tri[2][0]) * (py - tri[2][1]) -
                          (tri[0][1] - tri[2][1]) * (px - tri[2][0]))
                    if (d1 >= 0 and d2 >= 0 and d3 >= 0) or (d1 <= 0 and d2 <= 0 and d3 <= 0):
                        g.put(x, y, 'sh', 1)
        for tri in tris:
            sgn = -1 if tri[2][0] < nx else 1
            for k in range(11):
                t = k / 10.0
                x = int(round(tri[2][0] + (tri[1][0] - tri[2][0]) * t))
                y = int(round(tri[2][1] + (tri[1][1] - tri[2][1]) * t))
                c = g.get(x, y)
                if c is not None and c[0] == 'sh':
                    g.put(x, y, 'sh', 3)
        edge_over(g, box, 'sh', ('sk',), 3, ((0, -1), (-1, 0), (1, 0)))
    else:
        # 둥근 깃 두 쪽
        for (ccx, ccy, rr) in ((nx - 9.5, ny + nry - 1.0, 9.4), (nx + 10.5, ny + nry - 2.0, 9.0)):
            disk(g, ccx, ccy, rr, 'sh', 1, only=('sh',))
        for (ccx, ccy, rr) in ((nx - 9.5, ny + nry - 1.0, 9.4), (nx + 10.5, ny + nry - 2.0, 9.0)):
            for y in range(int(ccy - rr - 2), int(ccy + rr + 3)):
                for x in range(int(ccx - rr - 2), int(ccx + rr + 3)):
                    c = g.get(x, y)
                    if c is None or c[0] != 'sh':
                        continue
                    d = math.hypot(x + 0.5 - ccx, y + 0.5 - ccy)
                    if rr - 1.3 < d <= rr:
                        g.put(x, y, 'sh', 3)

    # 앞섶 + 단추
    if view != 'up':
        pl = cx + (7.0 if view == 'side' else 0.0)
        b0 = ny + nry + (16 if sex == 'boy' else 13)
        for y in range(int(b0 - 2), hem - 2):
            for x in (int(pl - 1), int(pl)):
                c = g.get(x, y)
                if c is not None and c[0] == 'sh':
                    g.put(x, y, 'sh', 2)
        n_b = 3 if sex == 'boy' else 4
        step = (hem - 6 - b0) / float(n_b)
        for i in range(n_b):
            by = b0 + step * i + 3
            disk(g, pl - 0.5, by, 2.9, 'sh', 3, only=('sh',))
            disk(g, pl - 0.5, by, 1.9, 'sh', 4, only=('sh',))
            g.put(int(pl - 1), int(by - 1), 'sh', 4)
    else:
        # 등 요크 이음선
        yk = curve([(56, 132), (72, 128), (88, 125), (96, 126), (108, 124), (124, 129), (140, 133)])
        for x in range(int(cx - 34), int(cx + 35)):
            y = int(round(yk(x)))
            c = g.get(x, y)
            if c is not None and c[0] == 'sh':
                g.put(x, y, 'sh', 2)

    # 가슴 주머니 (앞모습만, 한쪽에만)
    if view == 'down':
        px0, py0, pw, ph = int(cx - 19), 137, 14, 17
        for y in range(py0, py0 + ph):
            for x in range(px0, px0 + pw):
                c = g.get(x, y)
                if c is None or c[0] != 'sh':
                    continue
                onedge = (x == px0 or x == px0 + pw - 1 or y == py0 or
                          y >= py0 + ph - 1 - int(2.5 * (abs(x - (px0 + pw / 2.0)) / (pw / 2.0)) ** 2))
                if y > py0 + ph - 1 - int(2.5 * (abs(x - (px0 + pw / 2.0)) / (pw / 2.0)) ** 2):
                    continue
                if onedge:
                    g.put(x, y, 'sh', 3)
                elif y < py0 + 3:
                    g.put(x, y, 'sh', 4)
                elif y > py0 + ph - 6:
                    g.put(x, y, 'sh', 2)

    # 밑단 — 두께가 자리마다 다르다
    hemc = curve([(50, 5), (70, 4), (86, 6), (104, 4), (120, 5), (142, 3)])
    hw = w(hem) + 1.5
    for x in range(int(cx - hw), int(cx + hw) + 1):
        th = int(round(hemc(x)))
        col = []
        for y in range(hem + 6, ytop, -1):
            c = g.get(x, y)
            if c is not None and c[0] == 'sh':
                col.append(y)
        if not col:
            continue
        ybot = col[0]
        for k in range(th):
            c = g.get(x, ybot - k)
            if c is not None and c[0] == 'sh':
                g.put(x, ybot - k, 'sh', 2)
        c = g.get(x, ybot - th)
        if c is not None and c[0] == 'sh':
            g.put(x, ybot - th, 'sh', 1)

    # 옷 주름 몇 가닥 (좌우 높이 어긋나게)
    if view != 'up':
        strokes = ((cx - 19, 150, cx - 15, 172, 2.0), (cx + 17, 142, cx + 20, 166, 1.7),
                   (cx - 8, 166, cx - 6, 178, 1.4))
    else:
        strokes = ((cx - 20, 146, cx - 16, 170, 2.0), (cx + 18, 140, cx + 21, 164, 1.8))
    for (sx, sy, ex, ey, sw) in strokes:
        n = int(abs(ey - sy)) * 2
        for k in range(n + 1):
            t = k / float(n)
            xx = sx + (ex - sx) * t
            yy = sy + (ey - sy) * t
            ww = sw * (1.0 - 0.55 * t)
            for x in range(int(round(xx - ww)), int(round(xx + ww)) + 1):
                c = g.get(x, int(round(yy)))
                if c is not None and c[0] == 'sh' and c[1] in (0, 1):
                    g.put(x, int(round(yy)), 'sh', 2)


# ----------------------------------------------------------------- 머리카락
BANGS = {
    ('boy', 'down'): [(52, 76), (58, 60), (64, 51), (70, 45), (76, 40), (83, 38),
                      (88, 40), (92, 44), (96, 41), (101, 37), (109, 35), (117, 37),
                      (124, 43), (130, 54), (137, 70), (142, 80)],
    ('boy', 'side'): [(52, 84), (58, 66), (64, 55), (70, 47), (77, 42), (85, 38),
                      (92, 40), (98, 46), (103, 41), (110, 36), (118, 35), (125, 37),
                      (131, 42), (136, 52), (141, 68)],
    ('girl', 'down'): [(50, 84), (56, 68), (62, 56), (68, 49), (75, 44), (81, 42),
                       (86, 45), (90, 50), (94, 53), (98, 48), (102, 43), (109, 41),
                       (116, 42), (122, 47), (128, 56), (134, 70), (140, 84)],
    ('girl', 'side'): [(50, 86), (56, 70), (62, 58), (69, 50), (76, 45), (83, 42),
                       (89, 45), (94, 50), (99, 53), (103, 47), (108, 42), (115, 40),
                       (122, 41), (128, 46), (134, 56), (139, 70)],
}
RIM_L = {
    ('boy', 'down'): [(30, 11.0), (48, 11.0), (60, 10.0), (70, 7.0), (79, 0.0)],
    ('boy', 'side'): [(30, 13.0), (50, 17.0), (66, 18.5), (76, 15.0), (86, 7.0), (93, 0.0)],
    ('girl', 'down'): [(30, 11.5), (50, 12.0), (70, 12.0), (90, 12.0), (200, 12.0)],
    ('girl', 'side'): [(30, 14.0), (50, 18.0), (66, 20.0), (86, 19.0), (200, 18.0)],
}
RIM_R = {
    ('boy', 'down'): [(30, 9.0), (48, 9.0), (58, 8.0), (66, 5.0), (73, 0.0)],
    ('boy', 'side'): [(30, 6.0), (50, 4.5), (68, 3.2), (78, 2.4), (88, 0.0)],
    ('girl', 'down'): [(30, 10.0), (50, 10.5), (70, 11.0), (90, 11.0), (200, 11.0)],
    ('girl', 'side'): [(30, 6.5), (50, 5.0), (70, 4.0), (86, 3.2), (200, 3.0)],
}
NAPE = [(56, 80), (66, 90), (76, 96), (86, 100), (94, 99), (102, 101),
        (111, 98), (121, 91), (131, 82), (140, 73)]


def draw_hair(g, sex, view):
    L, R, y0, y1 = head_edges(view)
    if view == 'up':
        nape = curve(NAPE)
        for y in range(y0, y1 + 1):
            xl = int(math.ceil(L(y) - 0.5))
            xr = int(math.floor(R(y) - 0.5))
            for x in range(xl, xr + 1):
                if sex == 'girl' or y + 0.5 <= nape(x + 0.5):
                    g.put(x, y, 'hr', 0)
    else:
        bang = curve(BANGS[(sex, view)])
        tl = curve(RIM_L[(sex, view)])
        tr = curve(RIM_R[(sex, view)])
        for y in range(y0, y1 + 1):
            lo, ro = L(y), R(y)
            xl = int(math.ceil(lo - 0.5))
            xr = int(math.floor(ro - 0.5))
            for x in range(xl, xr + 1):
                px, py = x + 0.5, y + 0.5
                if py <= bang(px) or (px - lo) < tl(py) or (ro - px) < tr(py):
                    g.put(x, y, 'hr', 0)
    hair_shade(g, sex, view)


def hair_shade(g, sex, view):
    L, R, y0, y1 = head_edges(view)
    box = (int(L(58)) - 50, y0 - 2, int(R(58)) + 50, 215)
    hx = 98.0 if view == 'side' else 96.0
    # 오른쪽 그늘
    dk = curve([(8, hx + 8.0), (24, hx + 14.0), (40, hx + 19.0), (58, hx + 22.0),
                (76, hx + 21.0), (100, hx + 24.0), (140, hx + 26.0), (200, hx + 22.0)])
    shade(g, box, lambda x, y: x > dk(y), ('hr',), 2)
    # 왼쪽 위 빛
    ltx = curve([(8, hx - 4.0), (22, hx - 10.0), (38, hx - 16.0), (54, hx - 22.0),
                 (72, hx - 26.0), (96, hx - 28.0), (140, hx - 30.0), (200, hx - 26.0)])
    lty = curve([(40, 44), (60, 50), (80, 46), (96, 40), (110, 34), (130, 26), (144, 16)])
    shade(g, box, lambda x, y: x < ltx(y) and y < lty(x), ('hr',), 1)
    # 광택 — 짧게 두 도막
    gx, gy = hx - 22.0, 30.0
    for (ax, ay, rx, ry, x0c, x1c) in ((gx, gy, 22.0, 15.0, gx - 20, gx - 3),
                                       (gx + 5, gy - 1, 22.0, 15.0, gx + 4, gx + 15)):
        for y in range(int(ay - ry - 2), int(ay + ry + 3)):
            for x in range(int(x0c), int(x1c) + 1):
                c = g.get(x, y)
                if c is None or c[0] != 'hr':
                    continue
                d = ((x + 0.5 - ax) / rx) ** 2 + ((y + 0.5 - ay) / ry) ** 2
                if 0.80 < d < 1.0:
                    g.put(x, y, 'hr', 4)
    if view == 'up':
        # 정수리 가르마 — 왼쪽 위에서 시작해 짧게 흩어진다
        pv = curve([(14, hx - 3.0), (28, hx - 7.0), (46, hx - 9.0), (62, hx - 8.0)])
        for y in range(14, 63):
            x = int(round(pv(y) - 0.5))
            for k in range(2 if y < 34 else 1):
                c = g.get(x + k, y)
                if c is not None and c[0] == 'hr' and c[1] != 3:
                    g.put(x + k, y, 'hr', 2)
        for (ax, ay, rr) in ((hx - 8.0, 18.0, 4.0),):
            disk(g, ax, ay, rr, 'hr', 1, only=('hr',))
            disk(g, ax + 1.0, ay + 1.0, rr - 1.6, 'hr', 0, only=('hr',))
    # 짧은 가닥 몇 개
    if view == 'up':
        sts = ((hx - 5, 24, hx - 11, 38), (hx + 11, 30, hx + 17, 43),
               (hx - 1, 52, hx - 4, 63), (hx + 22, 50, hx + 25, 64),
               (hx - 19, 62, hx - 22, 74))
    elif view == 'side':
        sts = ((hx - 15, 20, hx - 21, 32), (hx + 7, 18, hx + 12, 28))
    else:
        sts = ((hx - 11, 18, hx - 17, 30), (hx + 9, 16, hx + 14, 26))
    for (sx, sy, ex, ey) in sts:
        n = int(math.hypot(ex - sx, ey - sy) * 2)
        for k in range(n + 1):
            t = k / float(n)
            x = int(round(sx + (ex - sx) * t))
            y = int(round(sy + (ey - sy) * t))
            wdt = 2 if 0.15 < t < 0.85 else 1
            for j in range(wdt):
                c = g.get(x + j, y)
                if c is not None and c[0] == 'hr' and c[1] != 3:
                    g.put(x + j, y, 'hr', 2 if c[1] != 2 else 3)
    # 머리끝/이마 경계는 머리의 가장 어두운 단
    edge_over(g, box, 'hr', ('sk',), 3, ((0, 1), (-1, 0), (1, 0), (0, -1)))


HAIR_L = {
    'down': [(38, 38.5), (58, 41.5), (82, 36.5), (104, 42.0), (126, 41.0),
             (148, 35.5), (168, 29.5), (182, 22.5), (191, 13.0), (196, 4.0)],
    'up':   [(14, 20.0), (28, 32.0), (44, 38.5), (62, 40.0), (86, 39.5),
             (112, 37.0), (138, 34.0), (162, 30.5), (180, 26.0), (191, 17.0), (197, 7.0)],
}
HAIR_R = {
    'down': [(38, 38.0), (58, 40.5), (80, 35.5), (100, 40.5), (124, 40.0),
             (146, 36.0), (170, 31.0), (188, 25.0), (199, 15.0), (205, 5.0), (208, 2.0)],
    'up':   [(14, 19.5), (28, 31.5), (44, 38.0), (62, 39.5), (86, 39.0),
             (114, 36.5), (140, 33.5), (168, 30.0), (188, 26.0), (199, 17.0), (204, 7.0)],
}
HAIR_HEM = {
    'down': [(48, 193), (58, 200), (70, 194), (82, 201), (96, 196),
             (110, 203), (122, 197), (132, 204), (144, 197)],
    'up':   [(48, 194), (60, 202), (74, 196), (86, 203), (98, 197),
             (112, 205), (124, 198), (136, 204), (148, 197)],
}


def hair_back(g, view):
    """여자 긴 머리 덩어리."""
    if view in ('down', 'up'):
        wl = curve(HAIR_L[view])
        wr = curve(HAIR_R[view])
        hem = curve(HAIR_HEM[view])
        y0 = min(HAIR_L[view][0][0], HAIR_R[view][0][0])
        y1 = int(max(p[0] for p in HAIR_L[view] + HAIR_R[view])) + 2
        hw = head_edges(view)[1]
        for y in range(y0, y1 + 1):
            cap = (hw(y) - 96.0 + 0.6) if y < 62 else 99.0
            xl = int(math.ceil(96.0 - min(wl(y), cap) - 0.5))
            xr = int(math.floor(96.0 + min(wr(y), cap) - 0.5))
            for x in range(xl, xr + 1):
                if y + 0.5 <= hem(x + 0.5):
                    g.put(x, y, 'hr', 0)
    else:
        # 뒤통수 쪽(왼쪽) 덩어리 — 어깨 뒤로 흐른다
        el = curve([(34, 58.0), (56, 52.5), (86, 50.0), (120, 50.5), (150, 53.0),
                    (170, 57.0), (182, 63.0), (190, 72.0)])
        heml = curve([(48, 176), (58, 185), (70, 179), (82, 187), (94, 181), (102, 184)])
        for y in range(34, 192):
            xl = int(math.ceil(el(y) - 0.5))
            for x in range(xl, 100):
                if y + 0.5 <= heml(x + 0.5):
                    g.put(x, y, 'hr', 0)


def hair_side_front(g):
    cr = curve([(46, 121.0), (80, 126.0), (120, 129.5), (160, 131.0),
                (188, 130.0), (204, 127.0)])
    wr = curve([(46, 15.0), (76, 14.5), (112, 13.0), (150, 11.5), (180, 9.0),
                (196, 5.5), (206, 2.0)])
    for y in range(46, 209):
        c0 = cr(y)
        ww = wr(y)
        xl = max(100, int(math.ceil(c0 - ww - 0.5)))
        xr = int(math.floor(c0 + ww - 0.5))
        for x in range(xl, xr + 1):
            g.put(x, y, 'hr', 0)


def hair_long_detail(g, view):
    """긴 머리 속 결 — 짧고 드문드문."""
    if view == 'down':
        sts = ((66, 118, 62, 150, 2), (128, 110, 133, 146, 2), (58, 160, 56, 182, 1),
               (136, 152, 134, 178, 1), (72, 96, 69, 122, 1))
        lts = ((62, 104, 59, 134, 2), (126, 92, 129, 116, 1))
    elif view == 'up':
        sts = ((64, 120, 60, 152, 2), (130, 112, 135, 148, 2), (98, 150, 96, 178, 1),
               (56, 166, 54, 188, 1))
        lts = ((60, 106, 57, 138, 2), (122, 60, 126, 96, 1))
    else:
        sts = ((62, 110, 58, 142, 2), (126, 120, 129, 156, 2), (120, 70, 122, 100, 1),
               (70, 156, 68, 176, 1))
        lts = ((58, 96, 55, 126, 2), (133, 96, 135, 130, 1))
    for (sx, sy, ex, ey, ww) in sts:
        n = int(math.hypot(ex - sx, ey - sy) * 2)
        for k in range(n + 1):
            t = k / float(n)
            x0 = sx + (ex - sx) * t
            y = int(round(sy + (ey - sy) * t))
            for x in range(int(round(x0)), int(round(x0 + ww))):
                c = g.get(x, y)
                if c is not None and c[0] == 'hr' and c[1] in (0, 1):
                    g.put(x, y, 'hr', 2)
    for (sx, sy, ex, ey, ww) in lts:
        n = int(math.hypot(ex - sx, ey - sy) * 2)
        for k in range(n + 1):
            t = k / float(n)
            x0 = sx + (ex - sx) * t
            y = int(round(sy + (ey - sy) * t))
            for x in range(int(round(x0)), int(round(x0 + ww))):
                c = g.get(x, y)
                if c is not None and c[0] == 'hr' and c[1] in (0, 2):
                    g.put(x, y, 'hr', 1 if c[1] == 0 else 0)


def hair_front(g, view):
    """여자 — 어깨 앞으로 내린 갈래 (몸 위에 올린다)."""
    if view == 'down':
        locks = (((71.0, 62.0, 8.8), (68.5, 100.0, 9.4), (67.5, 124.0, 7.8),
                  (68.5, 136.0, 4.6), (70.0, 143.0, 1.8)),
                 ((121.0, 60.0, 8.0), (124.0, 96.0, 8.6), (126.0, 118.0, 7.0),
                  (126.0, 128.0, 4.0), (125.0, 134.0, 1.6)))
    elif view == 'side':
        locks = (((75.0, 66.0, 9.2), (72.5, 102.0, 9.8), (71.5, 126.0, 8.0),
                  (72.5, 139.0, 4.6), (73.5, 146.0, 1.8)),)
    else:
        locks = ()
    for lk in locks:
        cyl(g, list(lk), 'hr')
        edge_over(g, (int(min(p[0] for p in lk)) - 16, 60,
                      int(max(p[0] for p in lk)) + 16, 200),
                  'hr', ('sh', 'sk', 'pt'), 3, ((0, 1), (-1, 0), (1, 0)))


def draw_ears(g, sex, view):
    if sex == 'girl':
        return
    L, R, _, _ = head_edges(view)
    if view == 'side':
        ears = ((L(72) + 3.0, 74.0, 5.0, 10.5, -1),)
    else:
        ey0 = 70.0 if view == 'down' else 68.0
        rr = (4.6, 9.8) if view == 'down' else (4.0, 8.4)
        ears = ((L(ey0) + 3.0, ey0, rr[0], rr[1], -1),
                (R(ey0) - 3.0, ey0, rr[0], rr[1], 1))
    for (ex, ey, rx, ry, sgn) in ears:
        ell(g, ex, ey, rx, ry, 'sk', 0)
        ell(g, ex + sgn * 1.0, ey + 1.0, rx * 0.55, ry * 0.6, 'sk', 2)
        ell(g, ex + sgn * 1.2, ey + 1.4, rx * 0.28, ry * 0.34, 'sk', 0)


# ----------------------------------------------------------------- 얼굴
def draw_eye(g, cx, cy, rw, rh, outer, girl):
    n = 2.32
    x0, x1 = int(cx - rw - 3), int(cx + rw + 3)
    y0, y1 = int(cy - rh - 3), int(cy + rh + 3)

    def ins(x, y, ax, ay, arx, ary, p=2.0):
        u = abs((x + 0.5 - ax) / arx)
        v = abs((y + 0.5 - ay) / ary)
        if u > 1.0 or v > 1.0:
            return False
        return u ** p + v ** p <= 1.0

    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if ins(x, y, cx, cy, rw, rh, n):
                g.put(x, y, 'ey', 3)
    irw, irh, icy = rw - 1.75, rh - 2.05, cy + 1.05
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if ins(x, y, cx, icy, irw, irh, n):
                g.put(x, y, 'ey', 1)
    arx, ary = rw * 0.67, rh * 1.00
    acx, acy = cx, cy + 1.7
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if g.get(x, y) == ('ey', 1) and ins(x, y, acx, acy, arx, ary):
                g.put(x, y, 'ey', 4)          # 따뜻한 홍채
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = g.get(x, y)
            if c is not None and c[0] == 'ey' and c[1] == 4 and \
                    y + 0.5 < acy - ary * 0.12:
                g.put(x, y, 'ey', 0)          # 위쪽은 짙게
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = g.get(x, y)
            if c is not None and c[0] == 'ey' and c[1] in (0, 4) and \
                    y + 0.5 < cy - rh * 0.34:
                g.put(x, y, 'ey', 3)          # 눈꺼풀 그림자
    prx, pry = rw * 0.33, rh * 0.42
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = g.get(x, y)
            if c is not None and c[0] == 'ey' and c[1] in (0, 3, 4) and \
                    ins(x, y, acx, acy + rh * 0.06, prx, pry):
                g.put(x, y, 'ey', 3)
    for (hx, hy, hr) in ((cx + outer * rw * 0.40, cy - rh * 0.40, rw * 0.31),
                         (cx - outer * rw * 0.33, cy + rh * 0.43, rw * 0.155)):
        for y in range(int(hy - hr - 2), int(hy + hr + 3)):
            for x in range(int(hx - hr - 2), int(hx + hr + 3)):
                c = g.get(x, y)
                if c is None or c[0] != 'ey' or c[1] == 1:
                    continue
                if math.hypot(x + 0.5 - hx, y + 0.5 - hy) <= hr:
                    g.put(x, y, 'ey', 1)
    if girl:  # 바깥 끝 속눈썹
        for k in range(3):
            g.put(int(cx + outer * (rw - 0.5 + k)), int(cy - rh * 0.52 - k * 0.9), 'ey', 3)
            if k < 2:
                g.put(int(cx + outer * (rw - 0.5 + k)), int(cy - rh * 0.52 - k * 0.9) + 1, 'ey', 3)


def draw_brow(g, cx, cy, hw, th, tiltd):
    for i in range(-int(hw), int(hw) + 1):
        t = i / float(hw)
        y = cy + 1.7 * abs(t) ** 1.6 + tiltd * t
        tt = th if abs(t) < 0.62 else th - 1
        for k in range(tt):
            g.put(int(cx + i), int(round(y)) + k, 'ey', 4)


def draw_mouth(g, cx, cy, hw):
    for i in range(-int(hw), int(hw) + 1):
        t = i / float(hw)
        y = cy - round(3.2 * t * t)
        g.put(int(cx + i), int(y), 'ey', 3)
        if abs(t) < 0.52:
            g.put(int(cx + i), int(y) + 1, 'ey', 3)
        if abs(t) < 0.34:
            c = g.get(int(cx + i), int(y) + 2)
            if c is not None and c[0] == 'sk':
                g.put(int(cx + i), int(y) + 2, 'sk', 6)


def draw_face(g, sex, view):
    girl = (sex == 'girl')
    L, R, _, _ = head_edges(view)
    if view == 'down':
        rw = 11.4 if girl else 11.0
        rh = 13.2 if girl else 12.6
        ec = ((78.4, 68.6, -1), (113.6, 68.6, 1))
        brows = ((77.0, 49.5, 7.4), (115.0, 49.5, 7.4))
        nose = (96.0, 84.5, 1.0)
        mouth = (96.0, 92.5, 5.4 if girl else 6.0)
        blush = ((72.0, 88.5, 8.6, 4.6), (120.0, 88.5, 8.6, 4.6))
    else:
        rw = 10.9 if girl else 10.6
        rh = 13.0 if girl else 12.5
        ec = ((99.0, 69.0, -1), (125.6, 67.6, 1))
        brows = ((97.5, 49.6, 7.2), (126.0, 47.8, 4.8))
        nose = (120.0, 84.5, 1.0)
        mouth = (116.0, 92.5, 5.0 if girl else 5.4)
        blush = ((91.0, 89.0, 8.8, 4.8), (128.5, 87.0, 6.0, 3.6))

    # 볼 (눈 아래)
    for (bx, by, brx, bry) in blush:
        for y in range(int(by - bry - 1), int(by + bry + 2)):
            for x in range(int(bx - brx - 1), int(bx + brx + 2)):
                c = g.get(x, y)
                if c is None or c[0] != 'sk' or c[1] not in (0, 1, 2):
                    continue
                if ((x + 0.5 - bx) / brx) ** 2 + ((y + 0.5 - by) / bry) ** 2 <= 1.0:
                    g.put(x, y, 'sk', 4)

    # 코
    nx, ny, _ = nose
    if view == 'down':
        for (dy, x0, x1) in ((0, -3, 2), (1, -3, 3), (2, -2, 2)):
            for x in range(int(nx + x0), int(nx + x1)):
                c = g.get(x, int(ny + dy))
                if c is not None and c[0] == 'sk':
                    g.put(x, int(ny + dy), 'sk', 2)
        g.put(int(nx + 1), int(ny + 2), 'sk', 5)
        g.put(int(nx - 2), int(ny - 1), 'sk', 6)
    else:
        for (dy, x0, x1) in ((0, -3, 3), (1, -2, 3), (2, 0, 3)):
            for x in range(int(nx + x0), int(nx + x1)):
                c = g.get(x, int(ny + dy))
                if c is not None and c[0] == 'sk':
                    g.put(x, int(ny + dy), 'sk', 2)
        g.put(int(nx + 2), int(ny + 2), 'sk', 5)
        g.put(int(nx - 3), int(ny - 1), 'sk', 6)

    draw_mouth(g, mouth[0], mouth[1], mouth[2])
    for (bx, by, hw) in brows:
        draw_brow(g, bx, by, hw, 3 if not girl else 2, 0.0)
    for (ex, ey, outer) in ec:
        w = rw if (view == 'down' or outer < 0) else rw * 0.66
        h = rh if (view == 'down' or outer < 0) else rh * 0.93
        draw_eye(g, ex, ey, w, h, outer, girl)


def face_shade(g, sex, view):
    L, R, y0, y1 = head_edges(view)
    box = (int(L(58)) - 6, y0, int(R(58)) + 6, y1 + 2)
    if view == 'side':
        dw = curve([(40, 8.0), (60, 7.0), (78, 6.0), (92, 9.0), (103, 13.0)])
        lw = curve([(40, 6.5), (60, 10.0), (80, 9.0), (95, 5.5), (103, 3.0)])
    else:
        dw = curve([(40, 10.5), (58, 9.5), (74, 8.0), (92, 11.0), (103, 15.0)])
        lw = curve([(40, 7.5), (58, 9.0), (78, 7.5), (94, 5.0), (103, 3.0)])
    shade(g, box, lambda x, y: x > R(y - 0.5) - dw(y), ('sk',), 2)
    shade(g, box, lambda x, y: x < L(y - 0.5) + lw(y), ('sk',), 1)
    # 턱 밑 안쪽 그늘
    shade(g, box, lambda x, y: y > y1 - 5 and abs(x - (L(y - .5) + R(y - .5)) / 2) < 9, ('sk',), 2)


# ----------------------------------------------------------------- 조립
def render(sex, view):
    g = Grid()
    if sex == 'girl' and view != 'up':
        hair_back(g, view)
    if sex == 'boy':
        geo = draw_legs_boy(g, view)
        draw_boots(g, view, geo)
    else:
        geo = draw_legs_girl(g, view)
        draw_shoes(g, view, geo)
    draw_neck(g, sex, view)

    arms = arm_paths(sex, view)
    if view == 'side':
        draw_arm(g, sex, view, arms[0])
        draw_sleeve(g, sex, view, 1)
        arms = arms[1:]

    draw_torso(g, sex, view)
    if sex == 'girl':
        draw_skirt(g, view)
        if view == 'up':
            hair_back(g, view)
    for a in arms:
        draw_arm(g, sex, view, a)
    draw_sleeve(g, sex, view, -1)
    if view != 'side':
        draw_sleeve(g, sex, view, 1)
    shirt_details(g, sex, view)

    abox = (48, 108, 144, 222)
    cast_shadow(g, abox, ('sh',), 'sk', 2, (0, 1), 2)
    edge_over(g, abox, 'sk', ('sh',), 3, ((-1, 0), (1, 0), (0, -1)))
    edge_over(g, abox, 'sh', ('sk',), 3, ((0, 1),))
    edge_over(g, (48, 160, 144, 232), 'sh', ('pt',), 3, ((0, 1),))
    edge_over(g, (48, 236, 144, 288), 'so', ('pt', 'sk'), 3, ((0, -1),))

    if sex == 'girl' and view == 'side':
        hair_side_front(g)
    head_skin(g, sex, view)
    draw_hair(g, sex, view)
    face_shade(g, sex, view)
    draw_ears(g, sex, view)
    if sex == 'girl':
        hair_front(g, view)
        hair_long_detail(g, view)
    if view != 'up':
        draw_face(g, sex, view)

    edge_over(g, (42, 86, 150, 132), 'sk', ('sh',), 3, ((0, 1),))
    prune(g)
    outline(g)
    rim(g)
    return to_image(g)


def to_image(g):
    minx, maxx, miny, maxy = 10 ** 9, -10 ** 9, 10 ** 9, -10 ** 9
    for y in range(MH):
        row = g.d[y]
        for x in range(MW):
            if row[x] is not None:
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y
    w = maxx - minx + 1
    h = maxy - miny + 1
    assert w <= 192 and h <= 288, '너무 큼 %dx%d' % (w, h)
    dx = int(round(95.5 - (minx + maxx) / 2.0))
    dy = 286 - maxy
    im = Image.new('RGBA', (192, 288), (0, 0, 0, 0))
    px = im.load()
    for y in range(MH):
        row = g.d[y]
        Y = y + dy
        if Y < 0 or Y >= 288:
            continue
        for x in range(MW):
            c = row[x]
            if c is None:
                continue
            X = x + dx
            if 0 <= X < 192:
                px[X, Y] = TONES[c[0]][c[1]] + (255,)
    return im


def main():
    for sex in ('boy', 'girl'):
        for view in ('down', 'side', 'up'):
            im = render(sex, view)
            im.save('w192_f_%s_%s.png' % (sex, view))
            print('w192_f_%s_%s.png' % (sex, view))


if __name__ == '__main__':
    main()
