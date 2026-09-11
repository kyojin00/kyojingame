#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리틀 루트 주인공 도트 — 192 x 288, 디자인 e 「또렷한 대비」.

처음부터 192칸 격자에 좌표를 잡는다. 저해상도 확대 없음.
  · 윤곽은 재질별 가장 어두운 단으로 3칸, 재질 경계는 2칸 (한 단 더 진하게)
  · 명암은 실루엣을 왼위로 밀어 만든 큰 면 하나로 크게 갈라, 멀리서도 읽힌다
  · 눈은 얼굴 폭의 1/3, 홍채가 눈을 거의 채우고 동공이 진하다

실행하면 여섯 장을 쓴다:
    w192_e_{boy,girl}_{down,side,up}.png
"""

import math
from PIL import Image

W, H = 192, 288
CX = 95.5          # 세로 중심선 (95 칸과 96 칸 사이)
GROUND = 286       # 발바닥 맨 아랫줄

# ---------------------------------------------------------------- 팔레트
SK, SK_L, SK_D = (243, 159, 138), (250, 192, 170), (213, 116, 98)
SK_CH, SK_M, SK_DD, SK_LL = (235, 128, 114), (170, 84, 66), (184, 99, 83), (252, 217, 204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118, 72, 40), (152, 100, 56), (86, 52, 30), (58, 35, 20), (195, 165, 140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58, 88, 168), (38, 58, 120), (94, 126, 200), (27, 41, 84), (166, 184, 225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134, 88, 46), (98, 62, 32), (158, 108, 58), (69, 43, 22), (202, 174, 147)
SO, SO_D, SO_DD = (82, 53, 33), (56, 37, 25), (39, 26, 18)
OL, EYE, BROW, WHT = (26, 20, 28), (66, 32, 30), (136, 70, 42), (246, 242, 234)

SKIN, HAIR, SHIRT, PANT, SHOE = 1, 2, 3, 4, 5
DARKEST = {SKIN: SK_DD, HAIR: HR_DD, SHIRT: SH_DD, PANT: PT_DD, SHOE: SO_DD}
SKINSET = set([SK, SK_L, SK_D, SK_CH, SK_M, SK_DD, SK_LL])

# 재질 A 가 재질 B 위에 얹힌다 -> A 쪽 가장자리에 A 의 제일 어두운 단
OVER = {
    HAIR:  (SKIN, SHIRT, PANT),
    SHIRT: (SKIN, PANT, HAIR),
    SKIN:  (HAIR,),
    PANT:  (SKIN,),
    SHOE:  (SKIN, PANT),
}


# ---------------------------------------------------------------- 자료구조
class C(object):
    """색 격자 + 재질 격자."""

    def __init__(self):
        self.col = [[None] * W for _ in range(H)]
        self.mat = [[0] * W for _ in range(H)]

    def put(self, x, y, c, m):
        if 0 <= x < W and 0 <= y < H:
            self.col[y][x] = c
            self.mat[y][x] = m

    def recolor(self, x, y, c):
        if 0 <= x < W and 0 <= y < H and self.col[y][x] is not None:
            self.col[y][x] = c

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.col[y][x]
        return None


class Sp(object):
    """줄 단위 구간 모음.  rows[y] = [(x0,x1), ...]"""

    def __init__(self):
        self.rows = {}

    def add(self, y, x0, x1):
        if x1 < x0 or y < 0 or y >= H:
            return
        lst = self.rows.setdefault(y, [])
        lst.append((x0, x1))
        lst.sort()
        out = []
        for a, b in lst:
            if out and a <= out[-1][1] + 1:
                out[-1] = (out[-1][0], max(out[-1][1], b))
            else:
                out.append((a, b))
        self.rows[y] = out

    def pixels(self):
        for y in sorted(self.rows):
            for a, b in self.rows[y]:
                for x in range(a, b + 1):
                    yield x, y

    def cols(self):
        d = {}
        for x, y in self.pixels():
            if x in d:
                a, b = d[x]
                d[x] = (min(a, y), max(b, y))
            else:
                d[x] = (y, y)
        return d

    def has(self, x, y):
        for a, b in self.rows.get(y, ()):
            if a <= x <= b:
                return True
        return False

    def fill(self, cv, c, m):
        for x, y in self.pixels():
            cv.put(x, y, c, m)

    def fill_on(self, cv, c, m, only):
        for x, y in self.pixels():
            if cv.get(x, y) in only:
                cv.put(x, y, c, m)

    def union(self, o):
        s = Sp()
        for src in (self, o):
            for y, lst in src.rows.items():
                for a, b in lst:
                    s.add(y, a, b)
        return s

    def diff(self, o):
        s = Sp()
        for x, y in self.pixels():
            if not o.has(x, y):
                s.add(y, x, x)
        return s

    def cut(self, keep):
        s = Sp()
        for x, y in self.pixels():
            if keep(x, y):
                s.add(y, x, x)
        return s


def cr_fn(pts):
    """Catmull-Rom 보간.  pts = [(y, v), ...]"""
    pts = sorted(pts)
    ys = [p[0] for p in pts]
    vs = [p[1] for p in pts]
    n = len(pts)

    def f(y):
        if y <= ys[0]:
            return vs[0]
        if y >= ys[-1]:
            return vs[-1]
        i = 0
        while i < n - 2 and y >= ys[i + 1]:
            i += 1
        t = (y - ys[i]) / float(ys[i + 1] - ys[i])
        p0 = vs[i - 1] if i > 0 else vs[i]
        p1, p2 = vs[i], vs[i + 1]
        p3 = vs[i + 2] if i + 2 < n else vs[i + 1]
        return 0.5 * (2 * p1 + (-p0 + p2) * t +
                      (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                      (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
    return f


def band(y0, y1, fl, fr):
    s = Sp()
    for y in range(y0, y1 + 1):
        a = int(math.ceil(fl(y)))
        b = int(math.floor(fr(y)))
        if b >= a:
            s.add(y, a, b)
    return s


def sym(y0, y1, hw, cx=None):
    if cx is None:
        cx = lambda y: CX
    return band(y0, y1, lambda y: cx(y) - hw(y), lambda y: cx(y) + hw(y))


def blob(cx, cy, rx, ry, n=2.0):
    s = Sp()
    for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
        t = (y - cy) / float(ry)
        if abs(t) >= 1.0:
            continue
        hw = rx * (1.0 - abs(t) ** n) ** (1.0 / n)
        a = int(math.ceil(cx - hw))
        b = int(math.floor(cx + hw))
        if b >= a:
            s.add(y, a, b)
    return s


def limb(pts, y0=None, y1=None):
    cxf = cr_fn([(p[0], p[1]) for p in pts])
    hwf = cr_fn([(p[0], p[2]) for p in pts])
    if y0 is None:
        y0 = int(pts[0][0])
    if y1 is None:
        y1 = int(pts[-1][0])
    return sym(y0, y1, hwf, cxf)


# ---------------------------------------------------------------- 명암 판정
def ell(cx, cy, rx, ry, n=2.0):
    def f(x, y):
        return (abs((x - cx) / float(rx)) ** n +
                abs((y - cy) / float(ry)) ** n) <= 1.0
    return f


def NOT(f):
    return lambda x, y: not f(x, y)


def AND(*fs):
    return lambda x, y: all(g(x, y) for g in fs)


def OR(*fs):
    return lambda x, y: any(g(x, y) for g in fs)


def shade(cv, sp, mat, tests):
    for x, y in sp.pixels():
        if cv.mat[y][x] != mat:
            continue
        for f, c in tests:
            if f(x, y):
                cv.col[y][x] = c
                break


def shade_tube(cv, sp, mat, clight, cdark, lw=0.20, dw=0.34,
               inset=3, wob=1.0, per=0.14):
    """원기둥 명암. 밝은 띠를 3칸 안쪽에서 시작해 윤곽에 먹히지 않게 하고,
       경계를 줄마다 조금씩 흔들어 자로 그은 자국을 없앤다."""
    for y in sorted(sp.rows):
        for a, b in sp.rows[y]:
            w = b - a
            if w < 5:
                continue
            l0 = a + inset
            l1 = a + inset + max(2.0, lw * w) + wob * math.sin(y * per)
            d0 = b - max(3.0, dw * w) - wob * math.sin(y * per + 2.0)
            for x in range(a, b + 1):
                if cv.mat[y][x] != mat:
                    continue
                if clight is not None and l0 <= x <= l1:
                    cv.col[y][x] = clight
                elif x >= d0:
                    cv.col[y][x] = cdark


def rim(cv, sp, which, width):
    """겹친 쪽 모서리에만 그 재질의 제일 어두운 단 — 실루엣 바깥은 안 건드린다."""
    for y, lst in sp.rows.items():
        if not lst:
            continue
        if which == 'r':
            x1 = max(b for a, b in lst)
            if cv.get(x1 + 1, y) is None:
                continue
            for i in range(width):
                m = cv.mat[y][x1 - i] if 0 <= x1 - i < W else 0
                if m in DARKEST:
                    cv.recolor(x1 - i, y, DARKEST[m])
        else:
            x0 = min(a for a, b in lst)
            if cv.get(x0 - 1, y) is None:
                continue
            for i in range(width):
                m = cv.mat[y][x0 + i] if 0 <= x0 + i < W else 0
                if m in DARKEST:
                    cv.recolor(x0 + i, y, DARKEST[m])


# ---------------------------------------------------------------- 윤곽
def _bfs(seed, filled, maxd):
    dist = {}
    cur = list(seed)
    for p in cur:
        dist[p] = 0
    d = 0
    while cur and d < maxd:
        d += 1
        nxt = []
        for (x, y) in cur:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p in dist:
                    continue
                if not (0 <= p[0] < W and 0 <= p[1] < H):
                    continue
                if not filled(p[0], p[1]):
                    continue
                dist[p] = d
                nxt.append(p)
        cur = nxt
    return dist


def outline_silhouette(cv, width=3):
    seed = [(x, y) for y in range(H) for x in range(W) if cv.col[y][x] is None]
    filled = lambda x, y: cv.col[y][x] is not None
    for (x, y), d in _bfs(seed, filled, width).items():
        if 1 <= d <= width and cv.col[y][x] is not None:
            cv.col[y][x] = DARKEST[cv.mat[y][x]]


def outline_borders(cv, width=2):
    for top, unders in OVER.items():
        seed = [(x, y) for y in range(H) for x in range(W)
                if cv.mat[y][x] in unders]
        if not seed:
            continue
        filled = lambda x, y: cv.mat[y][x] == top
        for (x, y), d in _bfs(seed, filled, width).items():
            if 1 <= d <= width and cv.mat[y][x] == top:
                cv.col[y][x] = DARKEST[top]


# ---------------------------------------------------------------- 머리통
HTOP, HCHIN, HCY, HA = 14, 121, 70, 52.0
BUP, NUP, BDN, NDN = 57.0, 2.4, 54.0, 1.65


def _sup(y, cy, a, bup, nup, bdn, ndn):
    if y <= cy:
        t, n, b = (cy - y), nup, bup
    else:
        t, n, b = (y - cy), ndn, bdn
    t = t / float(b)
    if t >= 1.0:
        return 0.0
    return a * (1.0 - t ** n) ** (1.0 / n)


def head_hw(y):
    return _sup(y, HCY, HA, BUP, NUP, BDN, NDN)


def hair_hw(y):
    return _sup(y, HCY, HA + 3.0, BUP + 3.0, NUP, BDN + 3.0, NDN)


def hairline(x, locks, base):
    v = base
    for lx, lw, ld, lp in locks:
        t = abs(x - lx) / float(lw)
        if t < 1.0:
            v = max(v, base + ld * (1.0 - t ** lp))
    return v


# ---------------------------------------------------------------- 눈
def draw_eye(cv, ex, ey, rx, ry, outer, sclera=3.0, lash=5, flick=0):
    """outer = -1 왼눈(바깥이 왼쪽) / +1 오른눈."""
    ok = SKINSET | set([WHT, EYE, BROW, OL])
    eye = blob(ex, ey, rx, ry, 2.15)
    eye.fill_on(cv, OL, 0, ok)
    inner = blob(ex, ey, rx - 2.0, ry - 2.0, 2.15)
    inner.fill_on(cv, WHT, 0, set([OL]))

    irx = max(2.0, rx - 2.0 - sclera)

    blob(ex, ey + 1.0, irx, ry + 4.0, 2.1).fill_on(cv, BROW, 0, set([WHT]))
    blob(ex, ey - ry * 1.04, irx, ry * 0.62, 2.0).fill_on(cv, EYE, 0, set([BROW]))
    blob(ex + outer * 0.6, ey + ry * 0.16, irx * 0.50, ry * 0.34, 2.1).fill_on(
        cv, OL, 0, set([EYE, BROW]))

    # 속눈썹 — 바깥으로 갈수록 두껍게
    cs = eye.cols()
    xs = sorted(cs)
    for x in xs:
        y0 = cs[x][0]
        t = (x - ex) / float(rx)
        th = lash - 1.7 * abs(t) ** 2 + flick * (t * outer) * 1.4
        for y in range(y0, y0 + int(round(max(2.0, th)))):
            if cv.get(x, y) in (WHT, EYE, BROW, OL):
                cv.put(x, y, OL, 0)

    # 반사점: 큰 것 바깥 위, 작은 것 안쪽 아래
    blob(ex + outer * irx * 0.42, ey - ry * 0.14, irx * 0.36, ry * 0.20, 2.0).fill_on(
        cv, WHT, 0, set([EYE, BROW, OL]))
    blob(ex - outer * irx * 0.40, ey + ry * 0.46, irx * 0.20, 2.0, 2.0).fill_on(
        cv, WHT, 0, set([EYE, BROW, OL]))


def stroke(cv, x0, y0, x1, y1, w, mat, col):
    """짧은 주름 한 줄 — 그 재질 위에만."""
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n):
        t = i / float(max(1, n - 1))
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        for k in range(w):
            if 0 <= x + k < W and 0 <= y < H and cv.mat[y][x + k] == mat:
                cv.recolor(x + k, y, col)


def hand_sp(cx, cy, rx, ry, thumb):
    """주먹 + 엄지 혹. thumb = 엄지가 붙는 쪽(+1 오른쪽)."""
    s = blob(cx, cy, rx, ry, 2.3)
    s = s.union(blob(cx + thumb * rx * 0.78, cy - ry * 0.26,
                     rx * 0.42, ry * 0.36, 2.2))
    return s


def hand_lines(cv, cx, cy, rx, ry, thumb):
    """손가락 골 두 줄 — 길이가 다르게."""
    for i, (off, ln) in enumerate(((1.0, 0.62), (4.6, 0.44))):
        x0 = int(round(cx - thumb * (rx * 0.10 + off)))
        y0 = int(round(cy + ry * 0.02))
        y1 = int(round(cy + ry * ln))
        for y in range(y0, y1 + 1):
            for k in range(2):
                x = x0 + k
                if cv.mat[y][x] == SKIN and cv.get(x, y) in (SK, SK_L, SK_D):
                    cv.put(x, y, SK_D if cv.get(x, y) != SK_D else SK_M, SKIN)


def draw_brow(cv, bx, by, halfw, th, arch, tilt):
    for x in range(int(round(bx - halfw)), int(round(bx + halfw)) + 1):
        t = (x - bx) / float(halfw)
        yy = by - arch * (1.0 - t * t) + tilt * t
        h = th - 1.3 * abs(t) ** 1.6
        if h < 1.0:
            continue
        for y in range(int(round(yy)), int(round(yy + h)) + 1):
            if cv.get(x, y) in SKINSET:
                cv.put(x, y, BROW, SKIN)


def draw_mouth(cv, mx, my, halfw, depth, th=3):
    for x in range(int(round(mx - halfw)), int(round(mx + halfw)) + 1):
        t = (x - mx) / float(halfw)
        yy = my - depth * t * t
        h = th - (1 if abs(t) > 0.72 else 0)
        for y in range(int(round(yy)), int(round(yy)) + h):
            if cv.get(x, y) in SKINSET:
                cv.put(x, y, OL, SKIN)


# ---------------------------------------------------------------- 저장
def save(cv, path):
    xs = [x for y in range(H) for x in range(W) if cv.col[y][x] is not None]
    ys = [y for y in range(H) for x in range(W) if cv.col[y][x] is not None]
    dx = int(round(CX - (min(xs) + max(xs)) / 2.0))
    dy = GROUND - max(ys)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            c = cv.col[y][x]
            if c is None:
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H:
                px[nx, ny] = (c[0], c[1], c[2], 255)
    im.save(path)
    return path


# ================================================================ 본체
def build(sex, view):
    boy = (sex == 'boy')
    side = (view == 'side')
    up = (view == 'up')
    cv = C()

    # 3/4 — 턱이 돌아선 쪽(오른쪽)으로 밀린다
    if side:
        def head_cx(y):
            if y <= 96:
                return CX
            return CX + 5.5 * ((y - 96) / 25.0) ** 1.3
    else:
        head_cx = lambda y: CX
    hdx = 4.0 if side else 0.0     # 3/4 에서 몸통이 밀리는 양

    def nose_bump(y):
        if not side:
            return 0.0
        t = (y - 104) / 9.0
        return 3.6 * (1.0 - t * t) if abs(t) < 1.0 else 0.0

    # ================= 여자 뒷머리 (몸 뒤) =================
    backhair = None
    if not boy:
        if up:
            hwo = cr_fn([(60, 44), (90, 45), (120, 44), (150, 42),
                         (172, 39), (188, 34), (198, 25), (203, 13)])
            backhair = sym(60, 203, hwo).cut(
                lambda x, y: y <= hairline(x, [(CX - 25, 26, 10, 0.9),
                                               (CX + 5, 24, 16, 0.85),
                                               (CX + 30, 21, 7, 0.9)], 186))
        elif side:
            hwl = cr_fn([(60, 45), (90, 49), (122, 48), (150, 45),
                         (166, 40), (176, 31), (183, 19), (186, 11), (203, 10)])
            hwr = cr_fn([(60, 39), (95, 44), (130, 46), (158, 45),
                         (178, 42), (191, 35), (199, 24), (203, 12)])
            backhair = band(60, 203,
                            lambda y: CX + hdx - hwl(y),
                            lambda y: CX + hdx + hwr(y))
        else:
            hwo = cr_fn([(58, 43), (78, 49), (100, 51), (128, 51),
                         (152, 49), (172, 44), (186, 37), (194, 28), (198, 16)])
            backhair = sym(58, 198, hwo)
        backhair.fill(cv, HR, HAIR)

    # ================= 다리 · 신발 =================
    legs, boots, pantsp = [], [], Sp()
    if boy:
        hipw = cr_fn([(188, 37.0), (196, 39.5), (204, 40.5), (212, 40.0)])
        if side:
            hips = band(188, 212, lambda y: CX + hdx - hipw(y) * 0.90,
                        lambda y: CX + hdx + hipw(y) * 0.88)
        else:
            hips = sym(188, 212, hipw)
        hips.fill(cv, PT, PANT)
        pantsp = hips

        if side:
            farleg = limb([(206, CX + 15, 14.5), (222, CX + 16, 13.6),
                           (234, CX + 16, 12.8), (250, CX + 16, 12.4)])
            nearleg = limb([(206, CX - 9, 16.0), (222, CX - 10, 15.0),
                            (236, CX - 11, 14.0), (254, CX - 11, 13.4)])
            farleg.fill(cv, PT, PANT)
            nearleg.fill(cv, PT, PANT)
            legs = [farleg, nearleg]
            pantsp = pantsp.union(farleg).union(nearleg)
        else:
            legw = cr_fn([(208, 17.0), (226, 16.4), (242, 15.6), (256, 15.0)])
            lcx = cr_fn([(208, 21.0), (232, 21.8), (256, 22.2)])
            for s in (-1, 1):
                lg = sym(208, 256, legw, lambda y, s=s: CX + s * lcx(y))
                lg.fill(cv, PT, PANT)
                legs.append(lg)
                pantsp = pantsp.union(lg)

        # 장화
        if side:
            fr = cr_fn([(244, 29.0), (264, 29.0), (269, 33.0), (273, 37.0),
                        (277, 39.5), (280, 39.5), (282, 38.0)])
            bf = band(244, 282, lambda y: CX + 1.0, lambda y: CX + fr(y))
            nr = cr_fn([(248, 5.0), (266, 5.5), (271, 11.0), (275, 16.0),
                        (279, 19.0), (283, 19.5), (GROUND, 18.0)])
            nl = cr_fn([(248, -27.0), (274, -27.0), (280, -29.0), (GROUND, -29.5)])
            bn = band(248, GROUND, lambda y: CX + nl(y), lambda y: CX + nr(y))
            bf.fill(cv, SO, SHOE)
            bn.fill(cv, SO, SHOE)
            boots = [bf, bn]
        else:
            for s in (-1, 1):
                bw = cr_fn([(248, 17.2), (256, 18.8), (270, 19.4),
                            (280, 19.4), (GROUND, 18.0)])
                bcx = cr_fn([(248, 21.5), (266, 22.5), (GROUND, 23.0)])
                b = sym(248, GROUND, bw, lambda y, s=s: CX + s * bcx(y))
                b.fill(cv, SO, SHOE)
                boots.append(b)
    else:
        if side:
            farleg = limb([(210, CX + 14, 12.0), (230, CX + 15, 11.0),
                           (248, CX + 15, 10.0), (258, CX + 15, 9.6)])
            nearleg = limb([(210, CX - 9, 13.0), (230, CX - 10, 12.0),
                            (250, CX - 11, 10.6), (262, CX - 11, 10.0)])
            farleg.fill(cv, SK, SKIN)
            nearleg.fill(cv, SK, SKIN)
            legs = [farleg, nearleg]
        else:
            legw = cr_fn([(208, 13.8), (228, 12.8), (248, 11.4), (262, 10.6)])
            lcx = cr_fn([(208, 17.0), (238, 17.8), (262, 18.2)])
            for s in (-1, 1):
                lg = sym(208, 262, legw, lambda y, s=s: CX + s * lcx(y))
                lg.fill(cv, SK, SKIN)
                legs.append(lg)
        # 단화
        if side:
            fr = cr_fn([(258, 25.0), (266, 25.0), (270, 28.5), (274, 31.5),
                        (278, 33.0), (281, 32.0)])
            sf = band(258, 281, lambda y: CX + 4.0, lambda y: CX + fr(y))
            nr = cr_fn([(262, 2.0), (270, 2.5), (274, 7.0), (278, 11.0),
                        (282, 13.5), (GROUND, 12.5)])
            sn = band(262, GROUND, lambda y: CX - 22.5, lambda y: CX + nr(y))
            sf.fill(cv, SO, SHOE)
            sn.fill(cv, SO, SHOE)
            boots = [sf, sn]
        else:
            for s in (-1, 1):
                sw = cr_fn([(262, 12.6), (270, 14.2), (280, 15.0), (GROUND, 14.0)])
                scx = cr_fn([(262, 18.0), (GROUND, 19.0)])
                sh = sym(262, GROUND, sw, lambda y, s=s: CX + s * scx(y))
                sh.fill(cv, SO, SHOE)
                boots.append(sh)

    # ================= 먼 팔 (3/4 에서 몸 뒤) =================
    hands = []
    fararm = None
    if side:
        if boy:
            fararm = limb([(136, CX + 26, 10.0), (152, CX + 30, 9.6),
                           (170, CX + 33, 9.0), (186, CX + 34, 8.4),
                           (196, CX + 34, 8.0)])
            fh = hand_sp(CX + 34, 206, 8.4, 9.4, +1)
            hands.append((CX + 34, 206, 8.4, 9.4, +1))
        else:
            fararm = limb([(137, CX + 24, 9.2), (154, CX + 28, 8.8),
                           (172, CX + 30, 8.2), (188, CX + 31, 7.6),
                           (196, CX + 31, 7.2)])
            fh = hand_sp(CX + 31, 204, 7.8, 8.8, +1)
            hands.append((CX + 31, 204, 7.8, 8.8, +1))
        fararm.fill(cv, SK, SKIN)
        fh.fill(cv, SK, SKIN)
        fararm = fararm.union(fh)

    # ================= 몸통 =================
    if boy:
        if side:
            twl = cr_fn([(127, 15), (132, 25), (138, 33), (145, 36.0),
                         (156, 35.5), (168, 34.0), (180, 34.5), (190, 37.5), (196, 39)])
            twr = cr_fn([(125, 14), (130, 22), (136, 28), (144, 30.0),
                         (156, 29.5), (168, 28.5), (180, 29.5), (190, 32.5), (196, 34)])
            torso = band(125, 196, lambda y: CX + hdx - twl(y),
                         lambda y: CX + hdx + twr(y))
        else:
            tw = cr_fn([(127, 16), (132, 26), (138, 32.5), (145, 35.5),
                        (156, 36.0), (168, 34.8), (178, 34.2), (188, 36), (196, 38.5)])
            torso = sym(127, 196, tw)
    else:
        if side:
            twl = cr_fn([(128, 14), (133, 23), (139, 30), (146, 32.0),
                         (158, 31.0), (170, 30.0), (180, 31.5), (188, 36.5),
                         (198, 44), (210, 50), (217, 53)])
            twr = cr_fn([(126, 13), (131, 20), (137, 26), (145, 27.5),
                         (158, 26.5), (170, 26.0), (180, 27.5), (188, 32.5),
                         (198, 39), (210, 44), (217, 46.5)])
            torso = band(126, 217, lambda y: CX + hdx - twl(y),
                         lambda y: CX + hdx + twr(y))
        else:
            tw = cr_fn([(127, 15), (132, 24.5), (138, 30.5), (146, 32.0),
                        (158, 31.0), (170, 30.0), (180, 31.5), (188, 36.5),
                        (198, 44), (208, 49), (215, 51.0)])
            torso = sym(127, 215, tw)
    torso.fill(cv, SH, SHIRT)

    # 치마 (여자)
    skirt = None
    if not boy:
        ytop = 176
        skirt = torso.cut(lambda x, y: y >= ytop + 4.0 * math.sin((x - CX) * 0.10 + 0.7))
        skirt.fill(cv, PT, PANT)
        pantsp = skirt

    # ================= 가까운 팔 =================
    arms = []
    if side:
        if boy:
            a = limb([(134, CX - 30, 11.0), (150, CX - 35, 10.5),
                      (168, CX - 38, 10.0), (184, CX - 39, 9.4),
                      (196, CX - 39, 9.0)])
            hand = hand_sp(CX - 39, 208, 9.2, 10.2, +1)
            hands.append((CX - 39, 208, 9.2, 10.2, +1))
        else:
            a = limb([(136, CX - 28, 10.0), (152, CX - 32, 9.6),
                      (170, CX - 35, 9.0), (186, CX - 36, 8.4),
                      (196, CX - 36, 8.0)])
            hand = hand_sp(CX - 36, 205, 8.6, 9.6, +1)
            hands.append((CX - 36, 205, 8.6, 9.6, +1))
        a.fill(cv, SK, SKIN)
        hand.fill(cv, SK, SKIN)
        arms.append(a.union(hand))
    else:
        for s in (-1, 1):
            if boy:
                a = limb([(133, CX + s * 31, 10.8), (150, CX + s * 35, 10.2),
                          (168, CX + s * 38.5, 9.6), (184, CX + s * 40, 9.0),
                          (196, CX + s * 40.5, 8.6)])
                hand = hand_sp(CX + s * 40.5, 208, 9.0, 10.0, -s)
                hands.append((CX + s * 40.5, 208, 9.0, 10.0, -s))
            else:
                a = limb([(134, CX + s * 29, 9.8), (150, CX + s * 33, 9.2),
                          (168, CX + s * 36, 8.6), (184, CX + s * 37, 8.0),
                          (194, CX + s * 37.5, 7.6)])
                hand = hand_sp(CX + s * 37.5, 204, 8.4, 9.4, -s)
                hands.append((CX + s * 37.5, 204, 8.4, 9.4, -s))
            a.fill(cv, SK, SKIN)
            hand.fill(cv, SK, SKIN)
            arms.append(a.union(hand))

    # 소매
    sleeves = []
    cut_y = 170 if boy else 164
    allarms = list(arms) + ([fararm] if fararm else [])
    for i, a in enumerate(allarms):
        if side:
            sg = -1.0 if i == 0 else 1.0
        else:
            sg = -1.0 if i == 0 else 1.0
        sl = a.cut(lambda x, y, sg=sg: y <= cut_y + sg * (x - CX) * 0.14)
        sl.fill(cv, SH, SHIRT)
        sleeves.append(sl)

    # ================= 목 =================
    if up:
        neck = sym(104, 132, cr_fn([(104, 11.0), (118, 11.2), (126, 12.8), (132, 16.0)]))
    else:
        ncx = (lambda y: CX + 2.0) if side else (lambda y: CX)
        neck = sym(110, 132, cr_fn([(110, 10.4), (120, 10.8), (126, 12.6), (132, 16.0)]), ncx)
    neck.fill(cv, SK, SKIN)

    # ================= 얼굴 · 머리 =================
    face = None
    if not up:
        face = band(HTOP, HCHIN,
                    lambda y: head_cx(y) - head_hw(y),
                    lambda y: head_cx(y) + head_hw(y) + nose_bump(y))
        face.fill(cv, SK, SKIN)

    # ---- 앞머리 치수를 머리 모양보다 먼저 정한다 (틈이 벌어지지 않게) ----
    if side:
        insL = cr_fn([(44, 27), (60, 25), (81, 23), (96, 17),
                      (104, 13), (111, 8), (117, 2), (121, 0)])
        insR = cr_fn([(44, 10), (60, 7), (81, 5), (96, 3),
                      (106, 2), (114, 0.5), (121, 0)])
        locks = [(CX - 22, 26, 11, 0.8), (CX + 6, 22, 18, 0.75),
                 (CX + 30, 20, 9, 0.85), (CX + 46, 16, 14, 0.9)]
        base, tipL, tipR = 39, 119, 103
    elif boy:
        insL = cr_fn([(44, 13), (60, 11.5), (81, 10.5), (96, 7),
                      (104, 3.5), (112, 1), (121, 0)])
        insR = insL
        locks = [(CX - 34, 22, 10, 0.85), (CX - 12, 21, 16, 0.75),
                 (CX + 12, 19, 8, 0.85), (CX + 33, 21, 14, 0.8)]
        base, tipL, tipR = 39, 109, 104
    else:
        insL = cr_fn([(44, 14), (60, 12.5), (81, 11.5), (96, 8),
                      (104, 4), (112, 1), (121, 0)])
        insR = insL
        locks = [(CX - 36, 20, 12, 0.8), (CX - 15, 22, 7, 0.85),
                 (CX + 8, 21, 17, 0.75), (CX + 32, 22, 10, 0.85)]
        base, tipL, tipR = 37, 115, 110

    hcx = (lambda y: CX + 1.0) if side else (lambda y: CX)
    hair = Sp()
    if up:
        nape = 112 if boy else 122
        hwf = cr_fn([(92, hair_hw(92)), (100, head_hw(100) + 3.5),
                     (108, head_hw(108) + 4.0), (116, head_hw(116) + 8.0),
                     (124, 22.0), (nape + 10, 16.0)])
        for y in range(10, nape + 11):
            hw = hair_hw(y) if y <= 92 else hwf(y)
            if hw <= 0:
                continue
            hair.add(y, int(math.ceil(CX - hw)), int(math.floor(CX + hw)))
        hair = hair.cut(lambda x, y: y <= hairline(x, [
            (CX - 28, 26, 9, 0.85), (CX - 2, 24, 15, 0.8),
            (CX + 26, 24, 6, 0.9)], nape))
    else:
        gL = cr_fn([(84, 3.0), (98, 2.0), (104, -1.0), (tipL, -7.0)])
        gR = cr_fn([(84, 3.0), (97, 1.6), (102, -1.4), (tipR, -7.0)])
        for sgn, tip, g in ((-1, tipL, gL), (1, tipR, gR)):
            half = Sp()
            for y in range(10, tip + 1):
                hw = hair_hw(y) if y <= 84 else head_hw(y) + g(y)
                if hw <= 0:
                    continue
                if sgn < 0:
                    half.add(y, int(math.ceil(hcx(y) - hw)), int(math.floor(hcx(y))))
                else:
                    half.add(y, int(math.ceil(hcx(y))), int(math.floor(hcx(y) + hw)))
            hair = hair.union(half)
    hair.fill(cv, HR, HAIR)

    # 앞머리 — 얼굴 창을 파낸다
    facewin = None
    if not up:
        facewin = band(40, HCHIN,
                       lambda y: head_cx(y) - (head_hw(y) - insL(y)),
                       lambda y: head_cx(y) + (head_hw(y) - insR(y)) + nose_bump(y))
        facewin = facewin.cut(lambda x, y: y > hairline(x, locks, base))
        facewin.fill(cv, SK, SKIN)

        if side and boy:      # 가까운 쪽 귀
            ear = blob(CX - 35, 89, 5.5, 9.5, 2.3)
            ear.fill(cv, SK, SKIN)
            facewin = facewin.union(ear)

    # ================================================ 명암
    # --- 머리카락 ---
    headpart = hair
    longpart = backhair.diff(hair) if backhair is not None else Sp()
    gx = CX + (3 if side else 0)
    # 정수리 윤기 — 닫힌 고리가 아니라 왼위로 치우친 초승달
    sheen = AND(ell(gx - 10, 42, 46, 38), NOT(ell(gx - 11, 47, 37, 27)),
                ell(gx - 24, 36, 45, 47))
    shade(cv, headpart, HAIR, [
        (AND(sheen, ell(gx - 28, 30, 14, 8, 2.2)), HR_LL),
        (sheen, HR_L),
        (NOT(ell(gx - 14, 54, 53, 66)), HR_D),
    ])
    if longpart.rows:
        shade_tube(cv, longpart, HAIR, HR_L, HR_D,
                   lw=0.15, dw=0.34, inset=3, wob=2.6, per=0.075)
        for x, y in longpart.pixels():
            if y > 176 and cv.get(x, y) == HR_L:
                cv.put(x, y, HR, HAIR)
        # 짧은 가닥 몇 개만 (정수리부터 긋지 않는다)
        for (sx, sy0, sy1, sw) in ((-38, 124, 148, 3), (30, 140, 158, 3),
                                   (-30, 168, 182, 2), (40, 176, 190, 2)):
            for y in range(sy0, sy1):
                xx = int(round(CX + sx + (y - sy0) * 0.18))
                for i in range(sw):
                    if cv.mat[y][min(W - 1, xx + i)] == HAIR:
                        cv.recolor(xx + i, y, HR_D)
        for y in range(140, 150):
            xx = int(round(CX - 36 + (y - 140) * 0.14))
            for i in range(3):
                if cv.mat[y][max(0, xx + i)] == HAIR:
                    cv.recolor(xx + i, y, HR_L)

    if up and boy:
        # 목덜미 가닥 — 머리 아랫선에 붙여서 그어야 가닥으로 읽힌다
        hc = hair.cols()
        for (sx, ln, ww) in ((-30, 15, 3), (-7, 21, 3), (14, 12, 2), (30, 17, 2)):
            xx0 = int(round(CX + sx))
            if xx0 not in hc:
                continue
            ybot = hc[xx0][1]
            for k in range(ln):
                y = ybot - k
                xx = xx0 + int(round(k * 0.18)) * (1 if sx > 0 else -1)
                for i in range(ww):
                    if cv.mat[y][xx + i] == HAIR:
                        cv.recolor(xx + i, y, HR_D)

    # --- 얼굴 살결 ---
    if facewin is not None:
        fdx = 7.0 if side else 0.0
        shade(cv, facewin, SKIN, [
            (ell(CX - 30 + fdx, 58, 27, 42), SK_L),
            (NOT(ell(CX - 13 + fdx, 62, 41, 73)), SK_D),
        ])
        # 앞머리 그늘 — 두께가 천천히 달라진다
        cs = facewin.cols()
        for x in sorted(cs):
            y0, y1 = cs[x]
            if y0 > 80:
                continue
            th = 4.0 + 1.8 * math.sin(x * 0.055 + 0.6) + 1.0 * math.sin(x * 0.13)
            for y in range(y0, y0 + int(round(th))):
                if cv.get(x, y) in (SK, SK_L):
                    cv.put(x, y, SK_D, SKIN)
        # 턱 아래 반사광
        ch = ell(CX + (5 if side else 0), 117, 20, 7)
        for x, y in facewin.pixels():
            if ch(x, y) and cv.get(x, y) == SK_D:
                cv.put(x, y, SK, SKIN)

    # --- 목 ---
    for y in sorted(neck.rows):
        for a, b in neck.rows[y]:
            for x in range(a, b + 1):
                if cv.mat[y][x] != SKIN:
                    continue
                t = (x - a) / float(max(1, b - a))
                if up:
                    cv.col[y][x] = SK if t < 0.26 else SK_D
                elif y < 126:
                    cv.col[y][x] = SK_D if t < 0.24 else SK_M
                else:
                    cv.col[y][x] = SK if t < 0.24 else SK_D

    # --- 팔다리 살결 ---
    limbs = list(arms)
    if fararm:
        limbs.append(fararm)
    if not boy:
        limbs += legs
    for a in limbs:
        isfar = (fararm is not None and a is fararm) or (side and a is legs[0])
        if isfar:
            shade_tube(cv, a, SKIN, None, SK_D, dw=0.62, wob=1.0, per=0.19)
        else:
            shade_tube(cv, a, SKIN, SK_L, SK_D, lw=0.20, dw=0.32,
                       inset=3, wob=1.0, per=0.17)

    # --- 윗도리 ---
    body_all = torso
    for sl in sleeves:
        body_all = body_all.union(sl)
    shade(cv, body_all, SHIRT, [
        (ell(CX - 40 + hdx, 140, 34, 42), SH_L),
        (NOT(ell(CX - 16 + hdx, 150, 42, 74)), SH_D),
    ])
    # 목 그림자
    csh = ell(CX + (2 if side else 0), 128, 22, 14)
    for x, y in torso.pixels():
        if cv.mat[y][x] == SHIRT and csh(x, y):
            cv.col[y][x] = SH_D
    # 옷깃
    if not up:
        col = blob(CX + (2 if side else 0), 124, 24, 14, 2.4).diff(
            blob(CX + (2 if side else 0), 120, 18.0, 11, 2.4))
        for x, y in col.pixels():
            if cv.mat[y][x] == SHIRT:
                cv.col[y][x] = SH_LL
    else:
        col = blob(CX, 126, 22, 12.5, 2.4).diff(blob(CX, 122, 16.5, 10, 2.4))
        for x, y in col.pixels():
            if cv.mat[y][x] == SHIRT:
                cv.col[y][x] = SH_LL

    # 옷 주름 — 높이를 어긋나게 (좌우 대칭이면 무늬가 된다)
    wd = hdx
    if boy:
        stroke(cv, CX + wd + 16, 166, CX + wd + 26, 169, 2, SHIRT, SH_DD)
        stroke(cv, CX + wd + 12, 181, CX + wd + 23, 184, 2, SHIRT, SH_DD)
        stroke(cv, CX + wd - 30, 156, CX + wd - 22, 159, 2, SHIRT, SH)
        stroke(cv, CX + wd - 27, 176, CX + wd - 19, 178, 2, SHIRT, SH)
    else:
        stroke(cv, CX + wd + 14, 158, CX + wd + 23, 161, 2, SHIRT, SH_DD)
        stroke(cv, CX + wd + 10, 170, CX + wd + 20, 172, 2, SHIRT, SH_DD)
        stroke(cv, CX + wd - 26, 150, CX + wd - 19, 152, 2, SHIRT, SH)
    if boy:
        if side:
            stroke(cv, CX - 21, 226, CX - 3, 229, 2, PANT, PT_D)
            stroke(cv, CX + 7, 234, CX + 23, 236, 2, PANT, PT_D)
        else:
            stroke(cv, CX - 30, 226, CX - 13, 229, 2, PANT, PT_D)
            stroke(cv, CX + 14, 234, CX + 30, 236, 2, PANT, PT_D)

    # 앞단과 단추
    if not up:
        pcx = CX + (5 if side else -3)
        for y in range(136, 175):
            xx = int(round(pcx + (y - 136) * (0.10 if side else -0.05)))
            for i in range(3):
                if cv.mat[y][xx + i] == SHIRT:
                    cv.recolor(xx + i, y, SH_DD)
        for by in (146, 163):
            bx = int(round(pcx + (by - 136) * (0.10 if side else -0.05))) - 3
            for x, y in blob(bx, by, 2.6, 2.0, 2.4).pixels():
                if cv.mat[y][x] == SHIRT:
                    cv.recolor(x, y, SH_LL)

    # --- 아랫도리 ---
    shade(cv, pantsp, PANT, [
        (ell(CX - 34 + hdx, 196, 28, 26), PT_L),
        (NOT(ell(CX - 16 + hdx, 200, 46, 62)), PT_D),
    ])
    if boy:
        # 허리띠
        for x, y in pantsp.pixels():
            if cv.mat[y][x] == PANT and 199 <= y <= 205:
                cv.col[y][x] = PT_DD
        bk = blob(CX + (3 if side else 0) - 1, 202, 5.0, 2.6, 2.6)
        for x, y in bk.pixels():
            if cv.mat[y][x] == PANT:
                cv.col[y][x] = PT_LL
    elif skirt is not None:
        # 치마 주름 — 높이와 폭이 제각각
        for (fx, fy0, fw0, fw1) in ((-26, 190, 2.0, 5.0), (-6, 182, 2.5, 6.5),
                                    (16, 194, 2.0, 4.5), (33, 186, 2.0, 5.5)):
            ybot = max(skirt.rows) if skirt.rows else 210
            for y in range(fy0, ybot + 1):
                u = (y - fy0) / float(max(1, ybot - fy0))
                ww = fw0 + (fw1 - fw0) * u
                x0 = int(round(CX + fx + hdx * 0.6 + u * fx * 0.10))
                for i in range(int(round(ww))):
                    if cv.mat[y][min(W - 1, x0 + i)] == PANT:
                        cv.recolor(x0 + i, y, PT_D)

    # --- 신발 ---
    shoe_all = Sp()
    for b in boots:
        shoe_all = shoe_all.union(b)
    for a in boots:
        shade_tube(cv, a, SHOE, None, SO_D, dw=0.38, wob=1.2, per=0.2)
    # 밑창
    for x, y in shoe_all.pixels():
        if cv.mat[y][x] == SHOE and y >= GROUND - 5:
            cv.col[y][x] = SO_DD

    for (hx, hy, hrx, hry, ht) in hands:
        hand_lines(cv, hx, hy, hrx, hry, ht)

    # ================================================ 겹친 모서리
    if side:
        rim(cv, arms[0], 'r', 2)
        rim(cv, legs[1], 'r', 2)
        rim(cv, boots[1], 'r', 2)

    # ================================================ 윤곽
    outline_borders(cv, 2)
    outline_silhouette(cv, 3)

    # ================================================ 얼굴 세부
    if not up:
        if side:
            exn, exf = CX + 3, CX + 32
            ry = 15.5 if boy else 16.5
            draw_eye(cv, exf, 83, 8.8, ry * 0.94, +1, sclera=2.0,
                     lash=5 if boy else 6, flick=0 if boy else 1)
            draw_eye(cv, exn, 83, 13.0, ry, -1, sclera=3.0,
                     lash=5 if boy else 6, flick=0 if boy else 1)
            draw_brow(cv, exf, 59, 7.5, 4.5 if boy else 3.6, 1.5, -1.0)
            draw_brow(cv, exn, 59, 9.5, 5.0 if boy else 4.0, 2.0, -1.0)
            draw_mouth(cv, CX + 19, 111, 6, 2.5, 3)
            blob(CX + 21, 103, 3.4, 2.4, 2.0).fill_on(cv, SK_M, SKIN, SKINSET)
            blob(CX - 3, 102, 9.5, 5.0, 2.3).fill_on(
                cv, SK_D, SKIN, set([SK, SK_L]))
            blob(CX + 37, 102, 5.5, 4.0, 2.3).fill_on(
                cv, SK_D, SKIN, set([SK, SK_L]))
        else:
            ex = 21.0
            ry = 15.5 if boy else 16.5
            draw_eye(cv, CX - ex, 83, 13.0, ry, -1, sclera=3.0,
                     lash=5 if boy else 6, flick=0 if boy else 1)
            draw_eye(cv, CX + ex, 83, 13.0, ry, +1, sclera=3.0,
                     lash=5 if boy else 6, flick=0 if boy else 1)
            draw_brow(cv, CX - ex, 59, 9.5, 5.0 if boy else 4.0, 2.0, 1.0)
            draw_brow(cv, CX + ex, 59, 9.5, 5.0 if boy else 4.0, 2.0, -1.0)
            draw_mouth(cv, CX + 1, 111, 7, 3.0, 3)
            blob(CX + 2, 103, 3.6, 2.4, 2.0).fill_on(cv, SK_M, SKIN, SKINSET)
            for s in (-1, 1):
                blob(CX + s * 24, 102, 9.0, 5.0, 2.3).fill_on(
                    cv, SK_D, SKIN, set([SK, SK_L]))

    return cv


def main():
    for sex in ('boy', 'girl'):
        for view in ('down', 'side', 'up'):
            cv = build(sex, view)
            save(cv, 'w192_e_%s_%s.png' % (sex, view))
            print('w192_e_%s_%s.png' % (sex, view))


if __name__ == '__main__':
    main()
