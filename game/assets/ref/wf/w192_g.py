#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리틀 루트 주인공 192x288 도트 — key "g" : 손으로 찍은 느낌.

가장자리와 결이 일부러 불규칙하다. 머리 가닥과 옷 주름의 길이/위치가
제각각이라 기계로 뽑은 티가 안 난다.  처음부터 192칸 격자에 직접 찍는다.
"""
import math, os
from PIL import Image

W, H = 192, 288

# ---------------------------------------------------------------- 팔레트
SK, SK_L, SK_D            = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD           = (82,53,33), (56,37,25), (39,26,18)
OL, EYE, BROW, WHT        = (26,20,28), (66,32,30), (136,70,42), (246,242,234)

SKIN  = {SK, SK_L, SK_D, SK_CH, SK_M, SK_DD, SK_LL}
HAIR  = {HR, HR_L, HR_D, HR_DD, HR_LL}
SHIRT = {SH, SH_D, SH_L, SH_DD, SH_LL}
PANT  = {PT, PT_D, PT_L, PT_DD, PT_LL}
SHOE  = {SO, SO_D, SO_DD}
FACE  = {OL, EYE, BROW, WHT}

OUTC = {}
for _c in SKIN:  OUTC[_c] = SK_DD
for _c in HAIR:  OUTC[_c] = HR_DD
for _c in SHIRT: OUTC[_c] = SH_DD
for _c in PANT:  OUTC[_c] = PT_DD
for _c in SHOE:  OUTC[_c] = SO_DD
for _c in FACE:  OUTC[_c] = OL

SKINF = SKIN | {SK}


# ---------------------------------------------------------------- 캔버스
class Cv(object):
    def __init__(self):
        self.b = [[None] * W for _ in range(H)]

    def put(self, x, y, c):
        if c is not None and 0 <= x < W and 0 <= y < H:
            self.b[y][x] = c

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.b[y][x]
        return None


# ---------------------------------------------------------------- 잡동사니
def _lcg(s):
    return (1103515245 * s + 12345) & 0x7FFFFFFF


def wob(seed, n, lo=-1, hi=1, hold=4, span=5):
    """손떨림. 짧은 구간마다 -1/0/+1 로 흔들리는 계단."""
    out = []
    s = _lcg((seed * 2654435761) & 0x7FFFFFFF)
    v = 0
    while len(out) < n:
        s = _lcg(s)
        run = hold + (s >> 9) % max(1, span)
        for _ in range(run):
            out.append(v)
            if len(out) >= n:
                break
        s = _lcg(s)
        v = max(lo, min(hi, v + ((s >> 13) % 3) - 1))
    return out


def bw_(seed, base, amp=2.0, per=17.0, n=H):
    """두께가 제각각인 띠. 실루엣을 따라 일정하면 자로 그은 자국이 된다."""
    w = wob(seed, n, -1, 1, 3, 6)
    def f(y):
        return base + amp * math.sin(y / per + (seed % 7)) + w[min(max(y, 0), n - 1)] * 1.2
    return f


def knot(ks, y):
    """마디점 사이를 부드럽게 이어 반폭을 돌려준다."""
    if y <= ks[0][0]:
        return ks[0][1]
    if y >= ks[-1][0]:
        return ks[-1][1]
    for i in range(len(ks) - 1):
        y0, v0 = ks[i]
        y1, v1 = ks[i + 1]
        if y0 <= y <= y1:
            if y1 == y0:
                return v1
            t = (y - y0) / float(y1 - y0)
            t = t * t * (3 - 2 * t)
            return v0 + (v1 - v0) * t
    return ks[-1][1]


def lobes(specs, base):
    """여러 개의 둥근 혀를 겹쳐 삐죽삐죽한 끝선을 만든다. (x -> y)"""
    def f(x):
        v = base
        for cx, hw, tip in specs:
            d = (x - cx) / float(hw)
            t = tip - d * d * (tip - base)
            if t > v:
                v = t
        return v
    return f


def fillreg(cv, y0, y1, lf, rf, col, only=None):
    for y in range(y0, y1 + 1):
        a = int(round(lf(y)))
        b = int(round(rf(y)))
        if b < a:
            continue
        for x in range(a, b + 1):
            if only is None or cv.get(x, y) in only:
                cv.put(x, y, col)


def disc(cv, cx, cy, rx, ry, col, only=None):
    y0 = int(math.floor(cy - ry))
    y1 = int(math.ceil(cy + ry))
    for y in range(y0, y1 + 1):
        d = (y - cy) / float(ry)
        if abs(d) > 1.0:
            continue
        w = rx * math.sqrt(max(0.0, 1.0 - d * d))
        for x in range(int(round(cx - w)), int(round(cx + w)) + 1):
            if only is None or cv.get(x, y) in only:
                cv.put(x, y, col)


def topmap(cv, x0, x1, mat):
    t = {}
    for x in range(x0, x1 + 1):
        for y in range(H):
            if cv.get(x, y) in mat:
                t[x] = y
                break
    return t


def gloss(cv, x0, x1, tm, offf, thf, col, seed, only=HAIR):
    """머리 꼭대기 곡선을 따라가는 불규칙한 광택/가닥 띠."""
    w1 = wob(seed, W, -1, 1, 3, 5)
    w2 = wob(seed + 9, W, -1, 1, 2, 4)
    for x in range(x0, x1 + 1):
        if x not in tm:
            continue
        o = offf(x) + w1[x]
        th = thf(x) + w2[x] * 0.5
        if th <= 0:
            continue
        ya = int(round(tm[x] + o))
        yb = int(round(tm[x] + o + th))
        for y in range(ya, yb + 1):
            if cv.get(x, y) in only:
                cv.put(x, y, col)


def stroke(cv, pts, col, only=None, th=1):
    """점 목록을 이어 그리는 붓질."""
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for k in range(n + 1):
            t = k / float(n)
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            for d in range(th):
                if only is None or cv.get(int(round(x)) + d, int(round(y))) in only:
                    cv.put(int(round(x)) + d, int(round(y)), col)


# ---------------------------------------------------------------- 마무리
def fillholes(cv):
    b = cv.b
    seen = [[False] * W for _ in range(H)]
    st = []
    for x in range(W):
        for y in (0, H - 1):
            if not seen[y][x] and b[y][x] is None:
                seen[y][x] = True
                st.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if not seen[y][x] and b[y][x] is None:
                seen[y][x] = True
                st.append((x, y))
    while st:
        cx, cy = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and b[ny][nx] is None:
                seen[ny][nx] = True
                st.append((nx, ny))
    for y in range(H):
        for x in range(W):
            if b[y][x] is None and not seen[y][x]:
                cnt = {}
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    c = cv.get(x + dx, y + dy)
                    if c is not None:
                        cnt[c] = cnt.get(c, 0) + 1
                if cnt:
                    b[y][x] = max(cnt.items(), key=lambda kv: kv[1])[0]


def outline(cv):
    b = cv.b
    mark = []
    for y in range(H):
        row = b[y]
        for x in range(W):
            c = row[x]
            if c is None:
                continue
            o = OUTC.get(c)
            if o is None or o == c:
                continue
            air = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and b[ny][nx] is None:
                    air = True
                    break
            if air:
                mark.append((x, y, o))
    for x, y, o in mark:
        b[y][x] = o


def thicken(cv, seed=5):
    """오른쪽/아래쪽 윤곽만 군데군데 두 칸으로. 손으로 그은 선의 강약."""
    b = cv.b
    fr = wob(seed, H, 0, 1, 5, 9)
    fc = wob(seed + 3, W, 0, 1, 6, 11)
    mark = []
    for y in range(H):
        for x in range(W):
            c = b[y][x]
            if c is None:
                continue
            o = OUTC.get(c)
            if o is None or o == c:
                continue
            if fr[y] and x + 1 < W and b[y][x + 1] == o:
                if x - 1 >= 0 and b[y][x - 1] == c:
                    mark.append((x, y, o))
                    continue
            if fc[x] and y + 1 < H and b[y + 1][x] == o:
                if y - 1 >= 0 and b[y - 1][x] == c:
                    mark.append((x, y, o))
    for x, y, o in mark:
        b[y][x] = o


def prune(cv):
    """제일 큰 덩어리만 남긴다 (떠 있는 한 칸짜리 조각 제거)."""
    b = cv.b
    seen = [[False] * W for _ in range(H)]
    comps = []
    for y in range(H):
        for x in range(W):
            if b[y][x] is not None and not seen[y][x]:
                st = [(x, y)]
                seen[y][x] = True
                cur = []
                while st:
                    cx, cy = st.pop()
                    cur.append((cx, cy))
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and b[ny][nx] is not None:
                            seen[ny][nx] = True
                            st.append((nx, ny))
                comps.append(cur)
    if len(comps) <= 1:
        return
    comps.sort(key=len, reverse=True)
    for c in comps[1:]:
        for x, y in c:
            b[y][x] = None


def finish(cv, path):
    prune(cv)
    b = cv.b
    xs = [x for y in range(H) for x in range(W) if b[y][x] is not None]
    ys = [y for y in range(H) for x in range(W) if b[y][x] is not None]
    dx = int(round(95.5 - (min(xs) + max(xs)) / 2.0))
    dy = 286 - max(ys)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            c = b[y][x]
            if c is None:
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H:
                px[nx, ny] = (c[0], c[1], c[2], 255)
    im.save(path)


# ================================================================ 치수표
HEADK = [(14,11),(16,15.5),(18,19),(21,23),(24,26.8),(28,30.5),(32,33.6),(36,36.2),
         (40,38.4),(45,40.4),(50,41.9),(56,43.1),(62,43.7),(68,44),(75,44),(81,43.5),
         (86,42.7),(90,41.7),(94,40.2),(98,38.2),(102,35.6),(105,33),(108,29.8),
         (111,26),(113,22.8),(115,19.4),(117,15.6),(119,11.2),(121,5.5)]

HEADB = [(14,11),(16,15.5),(18,19),(21,23),(24,26.8),(28,30.5),(32,33.6),(36,36.2),
         (40,38.4),(45,40.4),(50,41.9),(56,43.1),(62,43.7),(68,44),(75,44),(81,43.5),
         (86,42.6),(90,41.4),(94,39.6),(98,37.2),(101,34.4),(104,31.0),(107,27.2),
         (110,22.8),(112,19.0),(114,15.4),(116,12.4),(118,9.6),(120,6.4),(122,3.0)]

NECKK = [(104,10.2),(114,10.6),(121,11.2),(128,12.6),(134,15.4)]

EARY0, EARY1 = 82, 98


def earb(y):
    if EARY0 <= y <= EARY1:
        t = (y - EARY0) / float(EARY1 - EARY0)
        return 3.3 * math.sin(math.pi * t)
    return 0.0


# ---- 소년
B_TOR   = [(133,15),(136,19),(139,21.6),(143,22.8),(149,23.2),(157,23.0),(166,22.6),
           (176,22.2),(186,22.0),(194,22.6),(200,23.4),(203,23.2)]
B_ARMO  = [(133,16),(135,20),(138,24.5),(141,28.6),(144,32.2),(148,34.8),(152,36.2),
           (157,35.9),(163,35.6),(169,35.2),(175,35.1),(183,35.0),(191,35.2),(198,35.6),
           (203,36.3),(208,36.5),(212,35.7),(216,34.3),(219,31.6),(221,28.4)]
B_ARMI  = [(171,24.6),(178,25.2),(186,25.8),(194,26.4),(200,26.9),(206,27.1),(212,27.5),
           (216,28.4),(219,30.0),(221,28.4)]
B_PANO  = [(195,23.4),(202,24.2),(210,24.4),(218,24.0),(228,23.4),(238,22.9),(248,22.5),(256,22.3)]
B_PANI  = [(213,0.0),(217,3.2),(223,4.2),(232,4.7),(244,5.0),(256,5.2)]
B_BOOO  = [(247,23.2),(251,24.3),(260,24.6),(270,24.8),(279,25.2),(284,24.8),(286,23.4)]
B_BOOI  = [(247,4.6),(258,4.3),(270,4.1),(280,4.0),(286,4.0)]

# ---- 소녀
G_TOR   = [(133,14.5),(136,18.4),(139,20.6),(143,21.6),(149,21.9),(158,21.4),(168,20.8),
           (178,20.4),(188,20.9),(194,21.6),(198,21.4)]
G_ARMO  = [(133,15.5),(135,19.4),(138,23.6),(141,27.4),(144,30.8),(148,33.0),(152,34.2),
           (157,34.2),(163,34.0),(169,33.6),(175,33.4),(183,33.3),(191,33.5),(198,33.9),
           (203,34.5),(208,34.7),(212,33.9),(216,32.5),(219,30.0),(221,26.9)]
G_ARMI  = [(169,23.4),(178,24.0),(186,24.6),(194,25.2),(200,25.6),(206,25.8),(212,26.2),
           (216,26.9),(219,28.5),(221,26.9)]
G_SKIRT = [(191,21.6),(196,23.6),(203,26.4),(211,29.4),(219,31.8),(227,33.6),(233,34.4),(236,34.6)]
G_LEGO  = [(230,19.2),(238,18.6),(246,17.8),(254,16.8),(262,16.0),(270,15.6)]
G_LEGI  = [(230,4.2),(242,5.0),(254,5.6),(264,6.0),(272,6.2)]
G_SHOO  = [(268,16.8),(272,18.4),(279,19.2),(284,18.8),(286,17.4)]
G_SHOI  = [(268,4.4),(278,3.8),(286,3.6)]

# 소녀 긴 머리 (정면)
G_HAIRO = [(58,41.0),(66,43.4),(74,44.8),(84,45.6),(96,46.2),(112,46.6),(130,46.4),
           (150,45.4),(168,44.0),(182,42.2),(194,40.0),(202,37.4),(208,34)]
G_HAIRI = [(98,36.0),(106,30.0),(113,22.0),(119,15.0),(126,13.0),(134,15.4),(141,21.0),
           (149,25.4),(156,29.2),(166,30.8),(178,31.4),(190,31.8),(200,32.6),(208,34)]


# ================================================================ 얼굴 부품
def eye(cv, ex, ey, rx, ry, out=+1, lash=3, tip=False, ioff=0.0):
    """세로줄 단위로 쌓는다. 홍채가 위아래 속눈썹에 닿고 흰자는 좌우에만."""
    ix = ex + out * rx * 0.05 + ioff
    irx = rx * 0.80
    iry = ry * 2.20
    whx = rx - 1.7
    why = ry - 1.5
    for x in range(int(round(ex - rx)), int(round(ex + rx)) + 1):
        d = (x - ex) / float(rx)
        if abs(d) > 1.0:
            continue
        h = ry * math.sqrt(max(0.0, 1.0 - d * d))
        for y in range(int(round(ey - h)), int(round(ey + h)) + 1):
            cv.put(x, y, OL)
    cols = {}
    for x in range(int(round(ex - whx)), int(round(ex + whx)) + 1):
        d = (x - ex) / float(whx)
        if abs(d) > 1.0:
            continue
        h = why * math.sqrt(max(0.0, 1.0 - d * d))
        t = int(round(ey - h)) + (lash - 1) + (1 if abs(d) < 0.52 else 0)
        b = int(round(ey + h))
        if b - t < 1:
            continue
        for y in range(t, b + 1):
            cv.put(x, y, WHT)
        cols[x] = (t, b)
    # 홍채 — 위아래로 넘치게 그려 속눈썹에 닿는다
    iris = {}
    for x, (t, b) in cols.items():
        dd = (x - ix) / float(irx)
        if abs(dd) > 1.0:
            continue
        h = iry * math.sqrt(max(0.0, 1.0 - dd * dd))
        t2 = max(t, int(round(ey - h)))
        b2 = min(b, int(round(ey + h)))
        if b2 < t2:
            continue
        for y in range(t2, b2 + 1):
            cv.put(x, y, EYE)
        iris[x] = (t2, b2)
    # 홍채는 갈색, 위쪽만 눈꺼풀 그늘, 가장자리는 어둡게
    for x, (t2, b2) in iris.items():
        dd = abs(x - ix) / float(irx)
        if dd > 0.86:
            continue
        k = int(round((b2 - t2) * (0.86 - 0.20 * dd)))
        for y in range(b2 - k, b2 + 1):
            if cv.get(x, y) == EYE:
                cv.put(x, y, BROW)
    # 동공
    disc(cv, ix, ey + ry * 0.12, irx * 0.44, ry * 0.34, OL, only={EYE, BROW})
    # 반사점 : 큰 것은 바깥 위, 작은 것은 안쪽 아래
    disc(cv, ix + out * irx * 0.46, ey - ry * 0.36, rx * 0.20, ry * 0.165, WHT, only={EYE, OL, BROW})
    disc(cv, ix - out * irx * 0.42, ey + ry * 0.50, rx * 0.115, ry * 0.095, WHT, only={EYE, OL, BROW})
    if tip:
        tx = ex + out * (rx - 1.0)
        ty = ey - ry * 0.40
        stroke(cv, [(tx, ty), (tx + out * 2.0, ty - 2.5), (tx + out * 3.2, ty - 4.2)], OL,
               only={SK, SK_L, SK_D, SK_CH, OL, WHT})


def brow(cv, x0, x1, y, tilt=0.0, col=BROW, th=3):
    n = x1 - x0
    for i in range(n + 1):
        t = i / float(max(1, n))
        yy = y + tilt * t - 0.9 * math.sin(math.pi * t) * 0.6
        h = th - (1 if (t < 0.10 or t > 0.90) else 0)
        for k in range(h):
            if cv.get(x0 + i, int(round(yy)) + k) in SKIN:
                cv.put(x0 + i, int(round(yy)) + k, col)


def mouth(cv, mx, my, half=4, depth=2.0, open_=False):
    for dx in range(-half, half + 1):
        t = dx / float(half)
        yy = my - depth * t * t
        cv.put(int(round(mx + dx)), int(round(yy)), OL)
        cv.put(int(round(mx + dx)), int(round(yy)) + 1, OL)
    if open_:
        for dx in range(-half + 2, half - 1):
            t = dx / float(half)
            yy = int(round(my - depth * t * t)) + 2
            if cv.get(int(round(mx + dx)), yy) in SKIN:
                cv.put(int(round(mx + dx)), yy, SK_M)


def nose(cv, nx, ny, w=3):
    for i in range(w):
        if cv.get(nx + i, ny) in SKIN:
            cv.put(nx + i, ny, SK_D)
    for i in range(max(1, w - 1)):
        if cv.get(nx + i, ny + 1) in SKIN:
            cv.put(nx + i, ny + 1, SK_D)
    if cv.get(nx + 1, ny + 1) in SKIN:
        cv.put(nx + 1, ny + 1, SK_M)


def blush(cv, bx, by, rx, ry):
    disc(cv, bx, by, rx, ry, SK_CH, only={SK, SK_L, SK_D})
    disc(cv, bx, by, rx * 0.55, ry * 0.5, SK_CH, only={SK, SK_L, SK_D, SK_CH})


# ================================================================ 다리
def legs_boy(cv):
    wo = wob(311, H); wi = wob(407, H)
    O = lambda y: knot(B_PANO, y) + wo[y] * 0.6
    I = lambda y: knot(B_PANI, y)
    # 허리~가랑이 한 덩어리
    fillreg(cv, 195, 214, lambda y: 96 - O(y), lambda y: 95 + O(y), PT)
    for side in (-1, 1):
        if side < 0:
            lf = lambda y: 96 - O(y)
            rf = lambda y: 96 - I(y)
        else:
            lf = lambda y: 95 + I(y)
            rf = lambda y: 95 + O(y)
        fillreg(cv, 213, 257, lf, rf, PT)
    # 빛 왼쪽 위 : 각 다리 왼쪽에 밝은 띠, 오른쪽에 그늘
    for side in (-1, 1):
        base = (lambda y: 96 - O(y)) if side < 0 else (lambda y: 95 + I(y))
        outr = (lambda y: 96 - I(y)) if side < 0 else (lambda y: 95 + O(y))
        lp = bw_(521 + side, 4.6, 1.8, 21)
        dp = bw_(547 + side, 6.0, 2.4, 16)
        fillreg(cv, 196, 257, base, lambda y: base(y) + lp(y), PT_L, only={PT})
        fillreg(cv, 196, 257, lambda y: outr(y) - dp(y), outr, PT_D, only={PT, PT_L})
    # 가랑이 그늘
    fillreg(cv, 200, 216, lambda y: 96 - 7 - (216 - y) * 0.15, lambda y: 95 + 7 + (216 - y) * 0.15,
            PT_D, only={PT, PT_L})
    # 주름 : 길이도 위치도 제각각, 좌우 어긋나게
    for (sx, sy, ln, dy) in ((79, 224, 10, 2), (84, 232, 6, 1), (103, 220, 11, 2),
                             (107, 230, 7, 1), (76, 243, 5, 1), (100, 240, 7, 1),
                             (81, 250, 4, 1), (110, 246, 5, 1)):
        stroke(cv, [(sx, sy), (sx + ln, sy + dy)], PT_D, only={PT, PT_L})
    # 무릎 접힘 — 좌우 높이가 어긋난다
    for (sx, sy, ln, dy) in ((76, 230, 12, 2), (78, 234, 9, 1), (100, 227, 12, 2), (103, 232, 8, 1)):
        stroke(cv, [(sx, sy), (sx + ln, sy + dy)], PT_D, only={PT, PT_L})
    boots(cv)


def boots(cv):
    wo = wob(613, H)
    O = lambda y: knot(B_BOOO, y) + wo[y] * 0.5
    I = lambda y: knot(B_BOOI, y)
    for side in (-1, 1):
        if side < 0:
            lf = lambda y: 96 - O(y)
            rf = lambda y: 96 - I(y)
        else:
            lf = lambda y: 95 + I(y)
            rf = lambda y: 95 + O(y)
        fillreg(cv, 247, 286, lf, rf, SO)
    # 왼쪽 밝은 면 / 오른쪽 그늘
    for side in (-1, 1):
        outr = (lambda y: 96 - I(y)) if side < 0 else (lambda y: 95 + O(y))
        db = bw_(733 + side, 5.0, 1.8, 13)
        fillreg(cv, 250, 284, lambda y: outr(y) - db(y), outr, SO_D, only={SO})
        if side < 0:
            fillreg(cv, 250, 280, lambda y: 96 - O(y), lambda y: 96 - O(y) + 3.0, SO, only={SO_D})
    # 장화 목 (굽은 띠, 두께 제각각)
    cw = wob(757, H)
    fillreg(cv, 247, 254, lambda y: 96 - O(y), lambda y: 95 + O(y), SO_D, only={SO})
    fillreg(cv, 248, 250 , lambda y: 96 - O(y), lambda y: 95 + O(y), SO, only={SO_D})
    # 밑창
    fillreg(cv, 281, 286, lambda y: 96 - O(y), lambda y: 95 + O(y), SO_D, only={SO})
    fillreg(cv, 284, 286, lambda y: 96 - O(y), lambda y: 95 + O(y), SO_DD, only={SO_D})


def legs_girl(cv):
    wo = wob(811, H)
    O = lambda y: knot(G_LEGO, y) + wo[y] * 0.5
    I = lambda y: knot(G_LEGI, y)
    for side in (-1, 1):
        if side < 0:
            lf = lambda y: 96 - O(y)
            rf = lambda y: 96 - I(y)
        else:
            lf = lambda y: 95 + I(y)
            rf = lambda y: 95 + O(y)
        fillreg(cv, 228, 274, lf, rf, SK)
        outr = lf if side < 0 else rf
        inr = rf if side < 0 else lf
        ll = bw_(827 + side, 3.6, 1.4, 17)
        dl = bw_(853 + side, 4.4, 1.7, 13)
        if side < 0:
            fillreg(cv, 229, 274, lambda y: 96 - O(y), lambda y: 96 - O(y) + ll(y), SK_L, only={SK})
            fillreg(cv, 229, 274, lambda y: 96 - I(y) - dl(y), lambda y: 96 - I(y), SK_D, only={SK, SK_L})
        else:
            fillreg(cv, 229, 274, lambda y: 95 + I(y), lambda y: 95 + I(y) + ll(y) * 0.7, SK_L, only={SK})
            fillreg(cv, 229, 274, lambda y: 95 + O(y) - dl(y), lambda y: 95 + O(y), SK_D, only={SK, SK_L})
    # 무릎 살짝
    stroke(cv, [(80, 246), (86, 247)], SK_D, only={SK, SK_L})
    stroke(cv, [(106, 249), (111, 250)], SK_D, only={SK, SK_L})
    shoes_girl(cv)


def shoes_girl(cv):
    wo = wob(907, H)
    O = lambda y: knot(G_SHOO, y) + wo[y] * 0.4
    I = lambda y: knot(G_SHOI, y)
    for side in (-1, 1):
        if side < 0:
            lf = lambda y: 96 - O(y)
            rf = lambda y: 96 - I(y)
        else:
            lf = lambda y: 95 + I(y)
            rf = lambda y: 95 + O(y)
        fillreg(cv, 268, 286, lf, rf, SO)
        outr = lf if side < 0 else rf
        lw = wob(929 + side, H)
        fillreg(cv, 269, 286, lambda y: (96 - I(y) - 4.5 - lw[y]) if side < 0 else (95 + O(y) - 4.5 - lw[y]),
                (lambda y: 96 - I(y)) if side < 0 else (lambda y: 95 + O(y)), SO_D, only={SO})
    fillreg(cv, 282, 286, lambda y: 96 - O(y), lambda y: 95 + O(y), SO_D, only={SO})
    fillreg(cv, 284, 286, lambda y: 96 - O(y), lambda y: 95 + O(y), SO_DD, only={SO_D})


# ================================================================ 몸통 / 팔
def fill_cap(cv, y0, y1, lf, rf, col, cap, only=None):
    """세로 한계선(cap: x -> y)을 넘지 않게 채운다."""
    for y in range(y0, y1 + 1):
        a = int(round(lf(y)))
        b = int(round(rf(y)))
        for x in range(a, b + 1):
            if y <= cap(x):
                if only is None or cv.get(x, y) in only:
                    cv.put(x, y, col)


def torso_front(cv, sex):
    girl = (sex == 'girl')
    TK = G_TOR if girl else B_TOR
    AK = G_ARMO if girl else B_ARMO
    y1 = 198 if girl else 203
    hemL = 170 if girl else 174
    hemR = 166 if girl else 169
    wl = wob(1103 if girl else 1009, H)
    wr = wob(1117 if girl else 1013, H)
    AO = lambda y: knot(AK, y)
    # 어깨/소매 (왼쪽 오른쪽 단이 다르다)
    fillreg(cv, 133, hemL, lambda y: 96 - AO(y) + wl[y] * 0.6, lambda y: 96, SH)
    fillreg(cv, 133, hemR, lambda y: 95, lambda y: 95 + AO(y) - wr[y] * 0.6, SH)
    # 몸통
    fillreg(cv, 133, y1, lambda y: 96 - knot(TK, y) + wl[y] * 0.5,
            lambda y: 95 + knot(TK, y) - wr[y] * 0.5, SH)
    # 명암 : 왼쪽 위가 밝다
    lw = bw_(1201, 6.2, 2.6, 13)
    fillreg(cv, 136, hemL, lambda y: 96 - AO(y), lambda y: 96 - AO(y) + lw(y), SH_L, only={SH})
    fillreg(cv, 141, 154, lambda y: 96 - AO(y) + 2, lambda y: 96 - AO(y) + 7, SH_LL, only={SH_L})
    rw = bw_(1213, 6.8, 2.8, 11)
    fillreg(cv, 135, hemR, lambda y: 95 + AO(y) - rw(y), lambda y: 95 + AO(y), SH_D, only={SH, SH_L})
    rw2 = bw_(1217, 5.6, 2.4, 19)
    fillreg(cv, 150, y1, lambda y: 95 + knot(TK, y) - rw2(y),
            lambda y: 95 + knot(TK, y), SH_D, only={SH, SH_L})
    lw2 = bw_(1219, 4.4, 2.0, 23)
    fillreg(cv, 150, y1, lambda y: 96 - knot(TK, y), lambda y: 96 - knot(TK, y) + lw2(y),
            SH_L, only={SH})
    # 목 그늘 / 깃
    cw = wob(1301, W)
    for x in range(78, 115):
        d = abs(x - 96) / 19.0
        y0 = 133
        y1c = int(round(141 - 4.0 * d * d + cw[x]))
        for y in range(y0, y1c + 1):
            if cv.get(x, y) in {SH, SH_L, SH_D, SH_LL}:
                cv.put(x, y, SH_D)
    for x in range(80, 113):
        d = abs(x - 96) / 17.0
        y0 = 133
        y1c = int(round(138 - 3.5 * d * d + cw[x + 20] * 0.7))
        for y in range(y0, y1c + 1):
            if cv.get(x, y) in {SH_D}:
                cv.put(x, y, SH_DD)
    # 겨드랑이 그늘
    for side in (-1, 1):
        f = (lambda y: 96 - knot(TK, y)) if side < 0 else (lambda y: 95 + knot(TK, y))
        for y in range(160, (hemL if side < 0 else hemR) + 1):
            x0 = int(round(f(y) + side * 1))
            for k in range(3):
                if cv.get(x0 + side * k, y) in {SH, SH_L}:
                    cv.put(x0 + side * k, y, SH_D)
    # 옷주름 : 길이도 시작 높이도 제각각, 좌우 어긋나게
    folds = [((82, 152), (85, 163)), ((78, 176), (81, 186)), ((110, 158), (107, 168)),
             ((113, 180), (110, 192)), ((92, 186), (94, 196)), ((101, 145), (103, 152))]
    for a, b in folds:
        stroke(cv, [a, b], SH_D, only={SH, SH_L, SH_LL})
    # 소매단 선
    for x in range(int(96 - AO(hemL)), int(96 - knot(TK, hemL)) + 1):
        if cv.get(x, hemL) in {SH, SH_L, SH_D}:
            cv.put(x, hemL, SH_DD)
        if cv.get(x, hemL - 1) in {SH, SH_L} and (x % 3):
            cv.put(x, hemL - 1, SH_D)
    for x in range(int(95 + knot(TK, hemR)), int(95 + AO(hemR)) + 1):
        if cv.get(x, hemR) in {SH, SH_L, SH_D}:
            cv.put(x, hemR, SH_DD)
        if cv.get(x, hemR - 1) in {SH, SH_L, SH_D} and (x % 4):
            cv.put(x, hemR - 1, SH_D)
    # 소매 이음선 — 어깨끝에서 겨드랑이로
    stroke(cv, [(96 - AO(146) + 4, 145), (96 - knot(TK, 162) - 1, 163)], SH_D,
           only={SH, SH_L, SH_LL})
    stroke(cv, [(95 + AO(144) - 4, 143), (95 + knot(TK, 160) + 1, 161)], SH_DD,
           only={SH, SH_D})
    # 아랫단
    fillreg(cv, y1 - 2, y1, lambda y: 96 - knot(TK, y), lambda y: 95 + knot(TK, y), SH_D,
            only={SH, SH_L})
    return hemL, hemR


def arms_front(cv, sex, hemL, hemR):
    girl = (sex == 'girl')
    AK = G_ARMO if girl else B_ARMO
    IK = G_ARMI if girl else B_ARMI
    ybot = 221
    AO = lambda y: knot(AK, y)
    AI = lambda y: knot(IK, y)
    for side in (-1, 1):
        top = (hemL if side < 0 else hemR) + 1
        w = wob(1409 + side * 7, H)
        if side < 0:
            lf = lambda y: 96 - AO(y) + w[y] * 0.5
            rf = lambda y: 96 - AI(y)
        else:
            lf = lambda y: 95 + AI(y)
            rf = lambda y: 95 + AO(y) - w[y] * 0.5
        fillreg(cv, top, ybot, lf, rf, SK)
        la = bw_(1427 + side, 3.2, 1.3, 9)
        da = bw_(1451 + side, 4.2, 1.6, 12)
        if side < 0:
            fillreg(cv, top, ybot, lambda y: 96 - AO(y), lambda y: 96 - AO(y) + la(y),
                    SK_L, only={SK})
            fillreg(cv, top, ybot, lambda y: 96 - AI(y) - da(y), lambda y: 96 - AI(y),
                    SK_D, only={SK, SK_L})
        else:
            fillreg(cv, top, ybot, lambda y: 95 + AI(y), lambda y: 95 + AI(y) + la(y) * 0.6,
                    SK_L, only={SK})
            fillreg(cv, top, ybot, lambda y: 95 + AO(y) - da(y) - 0.8, lambda y: 95 + AO(y),
                    SK_D, only={SK, SK_L})
        # 소매 그늘 (팔 맨 위)
        fillreg(cv, top, top + 2, lf, rf, SK_M, only={SK, SK_L, SK_D})
    # 손가락 자국 — 좌우 길이가 다르다
    stroke(cv, [(66, 210), (70, 211)], SK_D, only={SK, SK_L})
    stroke(cv, [(65, 215), (68, 216)], SK_D, only={SK, SK_L})
    stroke(cv, [(122, 212), (127, 213)], SK_D, only={SK, SK_L})
    stroke(cv, [(124, 217), (127, 217)], SK_D, only={SK, SK_L})


def skirt_girl(cv):
    wl = wob(1511, H)
    wr = wob(1523, H)
    SKk = G_SKIRT
    hem = lobes([(66, 17, 236), (82, 15, 234.5), (96, 16, 237.5), (111, 14, 235), (126, 17, 236.5)], 232)
    lf = lambda y: 96 - knot(SKk, y) + wl[y] * 0.6
    rf = lambda y: 95 + knot(SKk, y) - wr[y] * 0.6
    fill_cap(cv, 190, 240, lf, rf, PT, hem)
    lsk = bw_(1531, 6.0, 2.6, 14)
    rsk = bw_(1543, 7.4, 3.0, 11)
    fill_cap(cv, 190, 240, lambda y: 96 - knot(SKk, y), lambda y: 96 - knot(SKk, y) + lsk(y),
             PT_L, hem, only={PT})
    fill_cap(cv, 190, 240, lambda y: 95 + knot(SKk, y) - rsk(y), rf, PT_D, hem, only={PT, PT_L})
    # 주름 — 위치도 길이도 제각각 (좌우 대칭 금지)
    pleats = [(70, 206, 234, 3), (81, 199, 230, 2), (90, 212, 238, 2),
              (103, 202, 236, 3), (114, 209, 231, 2), (123, 197, 235, 2)]
    for px_, y0, y1, th in pleats:
        for y in range(y0, y1 + 1):
            t = (y - y0) / float(max(1, y1 - y0))
            xx = int(round(px_ + (px_ - 96) * 0.16 * t))
            for k in range(th):
                if cv.get(xx + k, y) in {PT, PT_L}:
                    cv.put(xx + k, y, PT_D)
    # 밑단 그늘
    for x in range(60, 132):
        hb = int(round(hem(x)))
        for y in range(hb - 3, hb + 1):
            if cv.get(x, y) in {PT, PT_L}:
                cv.put(x, y, PT_D)
    # 허리
    fillreg(cv, 190, 194, lambda y: 96 - knot(SKk, y), lambda y: 95 + knot(SKk, y), PT_D, only={PT, PT_L})


# ================================================================ 목 / 머리
def neck_front(cv, sex, shift=0.0):
    w = wob(1601, H)
    lf = lambda y: 96 - knot(NECKK, y) + shift + w[y] * 0.4
    rf = lambda y: 95 + knot(NECKK, y) + shift - w[y] * 0.4
    fillreg(cv, 103, 140, lf, rf, SK)
    fillreg(cv, 104, 128, lf, rf, SK_D, only={SK})
    fillreg(cv, 104, 123, lf, rf, SK_M, only={SK_D})
    fillreg(cv, 124, 140, lambda y: lf(y), lambda y: lf(y) + 4.5, SK_L, only={SK, SK_D})


BOY_FRINGE = [(58, 15, 60), (74, 16, 64), (92, 15, 57), (108, 17, 63), (124, 15, 58), (137, 12, 52)]
GIRL_FRINGE = [(56, 14, 62), (70, 15, 57), (86, 16, 51), (101, 15, 56), (117, 16, 63), (133, 13, 64)]
BOY_PADL = [(50, 14), (58, 11.5), (66, 8), (72, 4.6), (77, 2.0), (81, 0.0)]
BOY_PADR = [(50, 12), (58, 9.5), (66, 6.4), (72, 3.4), (77, 1.2), (80, 0.0)]
GIRL_PADL = [(50, 15), (60, 12), (70, 8.8), (80, 5.8), (92, 3.6), (104, 2.6), (112, 1.8), (118, 0.8), (121, 0.0)]
GIRL_PADR = [(50, 13), (60, 10.5), (70, 7.4), (80, 4.8), (92, 3.0), (104, 2.0), (112, 1.4), (118, 0.6), (121, 0.0)]


def head_front(cv, sex):
    girl = (sex == 'girl')
    wl = wob(1709 if girl else 1699, H)
    wr = wob(1723 if girl else 1721, H)

    def hwf(y):
        v = knot(HEADK, y)
        if not girl:
            v += earb(y)
        else:
            if y > 100:
                v -= (y - 100) * 0.055
        return v

    hl = lambda y: 96 - hwf(y) + wl[y] * 0.7
    hr = lambda y: 95 + hwf(y) - wr[y] * 0.7
    fillreg(cv, 14, 121, hl, hr, HR)

    fr = lobes(GIRL_FRINGE if girl else BOY_FRINGE, 34 if girl else 36)
    padl = GIRL_PADL if girl else BOY_PADL
    padr = GIRL_PADR if girl else BOY_PADR
    pw = wob(1811, H)
    fl = lambda y: hl(y) + knot(padl, y) + pw[y] * 0.5
    frt = lambda y: hr(y) - knot(padr, y) - pw[y] * 0.4
    for y in range(46, 122):
        a = int(round(fl(y)))
        b = int(round(frt(y)))
        for x in range(a, b + 1):
            if y >= fr(x) and cv.get(x, y) in HAIR:
                cv.put(x, y, SK)

    # 귀 (소년만 살짝)
    if not girl:
        for y in range(EARY0 + 1, EARY1):
            t = (y - EARY0) / float(EARY1 - EARY0)
            e = 3.3 * math.sin(math.pi * t)
            if e < 1.2:
                continue
            x0 = int(round(hl(y)))
            for x in range(x0 + 1, x0 + 3):
                if cv.get(x, y) in {SK, SK_L}:
                    cv.put(x, y, SK_D)
            x1 = int(round(hr(y)))
            for x in range(x1 - 2, x1):
                if cv.get(x, y) in {SK, SK_L, SK_D}:
                    cv.put(x, y, SK_D)

    # 얼굴 명암 : 왼쪽 위가 밝다
    lw = wob(1901, H)
    rw = wob(1913, H)
    lwf = bw_(1901, 5.2, 2.0, 15)
    rwf = bw_(1913, 6.2, 2.4, 12)
    fillreg(cv, 52, 108, fl, lambda y: fl(y) + lwf(y), SK_L, only={SK})
    fillreg(cv, 52, 118, lambda y: frt(y) - rwf(y), frt, SK_D, only={SK, SK_L})
    bw = wob(1931, W, -1, 1, 3, 5)
    chin = {}
    for y in range(92, 122):
        a = int(round(hl(y)))
        b = int(round(hr(y)))
        for x in range(a, b + 1):
            chin[x] = y
    for x, yb in chin.items():
        th = 3 + bw[x]
        for y in range(yb - th, yb + 1):
            if cv.get(x, y) in {SK, SK_L}:
                cv.put(x, y, SK_D)
        if abs(x - 96) < 16 + bw[x] * 2:
            for y in range(yb - 1, yb + 1):
                if cv.get(x, y) in {SK_D}:
                    cv.put(x, y, SK_M)
    # 앞머리 밑 그늘 — 두께가 제각각
    sw = wob(2003, W, -1, 1, 2, 4)
    for x in range(48, 144):
        f0 = int(round(fr(x)))
        th = 3 + sw[x]
        for y in range(f0, f0 + th):
            if cv.get(x, y) in {SK, SK_L}:
                cv.put(x, y, SK_M)
        for y in range(f0 + th, f0 + th + 2):
            if cv.get(x, y) in {SK, SK_L}:
                cv.put(x, y, SK_D)

    # ---- 이목구비
    ey = 84.0 if girl else 83.0
    rx = 13.0 if girl else 12.4
    ry = 16.6 if girl else 15.6
    exl, exr = 75.0, 117.0
    if girl:
        brow(cv, 63, 79, 63, tilt=1.1)
        brow(cv, 113, 128, 62, tilt=-1.0)
    else:
        brow(cv, 64, 80, 64, tilt=1.2)
        brow(cv, 112, 127, 63, tilt=-1.1)
    eye(cv, exl, ey, rx, ry, out=-1, lash=(3 if girl else 3), tip=girl)
    eye(cv, exr, ey + (0.5 if girl else 0.0), rx - 0.3, ry, out=+1, lash=(3 if girl else 3), tip=girl)
    nose(cv, 94, 103, 3 if girl else 4)
    mouth(cv, 97 if girl else 96, 111, half=(4 if girl else 5), depth=2.0, open_=not girl)
    blush(cv, 71, 104, 9.0, 5.2)
    blush(cv, 121, 105, 8.2, 4.8)

    hair_detail_front(cv, sex, hl, hr)


def hair_detail_front(cv, sex, hl, hr):
    girl = (sex == 'girl')
    tm = topmap(cv, 40, 152, HAIR)
    # 큰 광택 띠 (왼쪽 위) — 두께 제각각
    gloss(cv, 56, 128, tm,
          lambda x: 8 + 2.0 * math.sin((x - 56) / 22.0),
          lambda x: max(0.0, 5.0 - abs(x - 82) / 12.0), HR_L, 2111)
    gloss(cv, 62, 106, tm,
          lambda x: 9 + 1.6 * math.sin((x - 60) / 19.0),
          lambda x: max(0.0, 2.6 - abs(x - 80) / 15.0), HR_LL, 2113)
    # 오른쪽 어두운 면
    gloss(cv, 112, 152, tm, lambda x: 2, lambda x: 3.0 + (x - 112) * 0.10, HR_D, 2129)
    # 짧은 가닥 몇 개 — 길이도 위치도 제각각
    segs = [(52, 61, 15, 2), (98, 110, 5, 2), (122, 133, 9, 2), (69, 76, 19, 2), (137, 145, 4, 2)]
    for x0, x1, off, th in segs:
        gloss(cv, x0, x1, tm, lambda x, o=off: o, lambda x, t=th: t, HR_D, 2141 + x0)
    if girl:
        gloss(cv, 78, 92, tm, lambda x: 4, lambda x: 2, HR_D, 2203)


def longhair_front(cv):
    wo = wob(2311, H)
    wi = wob(2333, H)
    HO = lambda y: knot(G_HAIRO, y) + wo[y] * 0.7
    HI = lambda y: knot(G_HAIRI, y) + wi[y] * 0.5
    tipL = lobes([(59, 16, 204), (73, 14, 194), (86, 12, 208)], 182)
    tipR = lobes([(109, 13, 198), (123, 15, 209), (136, 13, 192)], 180)
    fill_cap(cv, 58, 214, lambda y: 96 - HO(y), lambda y: 96 - HI(y), HR, tipL)
    fill_cap(cv, 58, 214, lambda y: 95 + HI(y), lambda y: 95 + HO(y), HR, tipR)
    # 명암
    lw = bw_(2347, 6.4, 3.0, 27)
    rw = bw_(2351, 8.0, 3.4, 23)
    lw3 = bw_(2359, 5.0, 2.2, 19)
    fill_cap(cv, 60, 214, lambda y: 96 - HO(y), lambda y: 96 - HO(y) + lw(y), HR_L, tipL,
             only={HR})
    fill_cap(cv, 66, 150, lambda y: 96 - HO(y) + 2, lambda y: 96 - HO(y) + 4.5, HR_LL, tipL, only={HR_L})
    fill_cap(cv, 60, 214, lambda y: 96 - HI(y) - lw3(y), lambda y: 96 - HI(y), HR_D, tipL,
             only={HR, HR_L})
    fill_cap(cv, 60, 214, lambda y: 95 + HO(y) - rw(y), lambda y: 95 + HO(y), HR_D, tipR,
             only={HR, HR_L})
    fill_cap(cv, 60, 214, lambda y: 95 + HI(y), lambda y: 95 + HI(y) + 3.0, HR_D, tipR, only={HR})
    # 가닥 — 길이도 시작점도 제각각
    strands = [(60, 96, 168, 2), (67, 120, 176, 2), (75, 86, 138, 3),
               (122, 104, 150, 2), (131, 126, 190, 3), (139, 112, 158, 2), (114, 140, 182, 2)]
    for x0, y0, y1, th in strands:
        for y in range(y0, y1 + 1):
            t = (y - y0) / float(max(1, y1 - y0))
            xx = int(round(x0 + (x0 - 96) * 0.10 * t))
            for k in range(th):
                if cv.get(xx + k, y) in {HR, HR_L}:
                    cv.put(xx + k, y, HR_D)
    # 끝자락 그늘
    for x in range(44, 150):
        for tip in (tipL, tipR):
            b = int(round(tip(x)))
            for y in range(b - 4, b + 1):
                if cv.get(x, y) in {HR, HR_L}:
                    cv.put(x, y, HR_D)


def draw_front(cv, sex):
    if sex == 'girl':
        legs_girl(cv)
        skirt_girl(cv)
    else:
        legs_boy(cv)
    neck_front(cv, sex)
    hemL, hemR = torso_front(cv, sex)
    if sex == 'girl':
        longhair_front(cv)
    arms_front(cv, sex, hemL, hemR)
    head_front(cv, sex)




# ================================================================ 3/4 (오른쪽을 비스듬히)
#  가까운 쪽 = 화면 왼쪽 / 먼 쪽 = 화면 오른쪽 (코가 오른쪽으로 나간다)
def side_legs_boy(cv):
    wo = wob(3011, H)
    O = lambda y: knot(B_PANO, y) + wo[y] * 0.6
    fillreg(cv, 195, 214, lambda y: 96 - O(y) + 2, lambda y: 95 + O(y) - 4, PT)
    # 먼 다리 (뒤, 어둡고 좁다)
    fillreg(cv, 208, 252, lambda y: 98, lambda y: 95 + O(y) - 5, PT_D)
    fillreg(cv, 208, 252, lambda y: 98, lambda y: 101, PT_DD, only={PT_D})
    # 가까운 다리 (앞, 밝고 넓다)
    fillreg(cv, 210, 257, lambda y: 96 - O(y) + 2, lambda y: 93, PT)
    lp = bw_(3023, 5.0, 2.0, 19)
    dp = bw_(3037, 6.0, 2.2, 15)
    fillreg(cv, 196, 257, lambda y: 96 - O(y) + 2, lambda y: 96 - O(y) + 2 + lp(y), PT_L, only={PT})
    fillreg(cv, 210, 257, lambda y: 93 - dp(y), lambda y: 93, PT_D, only={PT, PT_L})
    fillreg(cv, 198, 214, lambda y: 96 - 10, lambda y: 95 + 4, PT_D, only={PT, PT_L})
    for (sx, sy, ln) in ((77, 226, 9), (82, 236, 6), (103, 222, 7), (106, 234, 4)):
        stroke(cv, [(sx, sy), (sx + ln, sy + 2)], PT_D, only={PT, PT_L})
    side_boots(cv)


def side_boots(cv):
    wo = wob(3041, H)
    # 먼 발 (뒤, 조금 높다)
    FR = [(246,110),(262,111),(268,113),(273,117),(278,121),(282,122),(284,119)]
    fillreg(cv, 246, 284, lambda y: 98, lambda y: knot(FR, y), SO_D)
    fillreg(cv, 281, 284, lambda y: 98, lambda y: knot(FR, y), SO_DD, only={SO_D})
    # 가까운 발 (앞)
    NR = [(245,93),(264,94),(270,96),(275,101),(280,105),(284,106),(286,102)]
    NL = [(245,74),(262,73),(274,72),(282,72),(286,74)]
    fillreg(cv, 245, 286, lambda y: knot(NL, y) + wo[y] * 0.5, lambda y: knot(NR, y), SO)
    db = bw_(3049, 5.4, 1.8, 13)
    fillreg(cv, 249, 286, lambda y: knot(NR, y) - db(y), lambda y: knot(NR, y), SO_D, only={SO})
    fillreg(cv, 272, 286, lambda y: 92, lambda y: knot(NR, y), SO_D, only={SO})
    fillreg(cv, 245, 253, lambda y: knot(NL, y), lambda y: knot(NR, y), SO_D, only={SO})
    fillreg(cv, 246, 248, lambda y: knot(NL, y), lambda y: knot(NR, y), SO, only={SO_D})
    fillreg(cv, 283, 286, lambda y: knot(NL, y), lambda y: knot(NR, y), SO_D, only={SO})
    fillreg(cv, 285, 286, lambda y: knot(NL, y), lambda y: knot(NR, y), SO_DD, only={SO_D, SO})


def side_legs_girl(cv):
    wo = wob(3061, H)
    O = lambda y: knot(G_LEGO, y) + wo[y] * 0.5
    fillreg(cv, 228, 270, lambda y: 98, lambda y: 95 + O(y) - 4, SK_D)
    fillreg(cv, 228, 270, lambda y: 98, lambda y: 100, SK_M, only={SK_D})
    fillreg(cv, 228, 274, lambda y: 96 - O(y) + 2, lambda y: 94, SK)
    ll = bw_(3067, 3.6, 1.4, 17)
    fillreg(cv, 229, 274, lambda y: 96 - O(y) + 2, lambda y: 96 - O(y) + 2 + ll(y), SK_L, only={SK})
    fillreg(cv, 229, 274, lambda y: 90, lambda y: 94, SK_D, only={SK, SK_L})
    stroke(cv, [(80, 247), (86, 248)], SK_D, only={SK, SK_L})
    # 먼 신
    fillreg(cv, 268, 282, lambda y: 98, lambda y: 114, SO_D)
    fillreg(cv, 276, 282, lambda y: 98, lambda y: 121, SO_D)
    fillreg(cv, 280, 282, lambda y: 98, lambda y: 121, SO_DD, only={SO_D})
    # 가까운 신
    fillreg(cv, 268, 286, lambda y: 78, lambda y: 94, SO)
    fillreg(cv, 274, 286, lambda y: 78, lambda y: 104, SO)
    fillreg(cv, 278, 286, lambda y: 78, lambda y: 110, SO)
    fillreg(cv, 269, 286, lambda y: 91, lambda y: 110, SO_D, only={SO})
    fillreg(cv, 283, 286, lambda y: 78, lambda y: 110, SO_D, only={SO})
    fillreg(cv, 285, 286, lambda y: 78, lambda y: 110, SO_DD, only={SO_D, SO})


def side_skirt_girl(cv):
    wl = wob(3101, H)
    SKk = G_SKIRT
    hem = lobes([(64, 16, 235), (80, 14, 233), (95, 15, 238), (110, 14, 234), (124, 16, 236)], 230)
    lf = lambda y: 96 - knot(SKk, y) + 2 + wl[y] * 0.6
    rf = lambda y: 95 + knot(SKk, y) - 2 - wl[y] * 0.4
    fill_cap(cv, 190, 240, lf, rf, PT, hem)
    lsk = bw_(3109, 6.0, 2.6, 14)
    rsk = bw_(3119, 9.0, 3.4, 11)
    fill_cap(cv, 190, 240, lf, lambda y: lf(y) + lsk(y), PT_L, hem, only={PT})
    fill_cap(cv, 190, 240, lambda y: rf(y) - rsk(y), rf, PT_D, hem, only={PT, PT_L})
    for px_, y0, y1, th in ((72, 205, 233, 3), (84, 199, 236, 2), (97, 210, 231, 2),
                            (109, 202, 235, 3), (118, 212, 230, 2)):
        for y in range(y0, y1 + 1):
            t = (y - y0) / float(max(1, y1 - y0))
            xx = int(round(px_ + (px_ - 96) * 0.16 * t))
            for k in range(th):
                if cv.get(xx + k, y) in {PT, PT_L}:
                    cv.put(xx + k, y, PT_D)
    for x in range(56, 136):
        hb = int(round(hem(x)))
        for y in range(hb - 3, hb + 1):
            if cv.get(x, y) in {PT, PT_L}:
                cv.put(x, y, PT_D)
    fillreg(cv, 190, 194, lf, rf, PT_D, only={PT, PT_L})


def side_torso(cv, sex):
    girl = (sex == 'girl')
    TK = G_TOR if girl else B_TOR
    AK = G_ARMO if girl else B_ARMO
    y1 = 198 if girl else 203
    SX = 3.0
    hemL = 172 if girl else 176
    hemR = 164 if girl else 167
    wl = wob(3301, H)
    wr = wob(3313, H)
    TL = lambda y: 96 - knot(TK, y) * 1.00 + SX + wl[y] * 0.5
    TR = lambda y: 95 + knot(TK, y) * 0.80 + SX - wr[y] * 0.5
    AL = lambda y: 96 - (knot(AK, y + 3) * 1.00 + 1.6) + SX + wl[y] * 0.6
    AR = lambda y: 95 + knot(AK, y - 2) * 0.78 + SX - wr[y] * 0.6
    fillreg(cv, 133, hemL, AL, lambda y: 96, SH)
    fillreg(cv, 131, hemR, lambda y: 95, AR, SH)
    fillreg(cv, 133, y1, TL, lambda y: 96, SH)
    fillreg(cv, 131, y1, lambda y: 95, TR, SH)
    lw = bw_(3323, 6.6, 2.6, 13)
    rw = bw_(3329, 7.6, 3.0, 11)
    fillreg(cv, 136, hemL, AL, lambda y: AL(y) + lw(y), SH_L, only={SH})
    fillreg(cv, 141, 156, lambda y: AL(y) + 2, lambda y: AL(y) + 6, SH_LL, only={SH_L})
    fillreg(cv, 133, hemR, lambda y: AR(y) - rw(y), AR, SH_D, only={SH, SH_L})
    fillreg(cv, 150, y1, lambda y: TR(y) - rw(y) * 0.8, TR, SH_D, only={SH, SH_L})
    fillreg(cv, 150, y1, TL, lambda y: TL(y) + lw(y) * 0.6, SH_L, only={SH})
    # 깃 — 돌아선 쪽으로 치우친다
    cw = wob(3331, W)
    for x in range(82, 118):
        d = (x - 100) / 18.0
        y1c = int(round(141 - 4.5 * d * d + cw[x]))
        for y in range(133, y1c + 1):
            if cv.get(x, y) in {SH, SH_L, SH_D, SH_LL}:
                cv.put(x, y, SH_D)
    for x in range(85, 115):
        d = (x - 100) / 16.0
        y1c = int(round(137 - 3.5 * d * d + cw[x + 20] * 0.7))
        for y in range(133, y1c + 1):
            if cv.get(x, y) == SH_D:
                cv.put(x, y, SH_DD)
    stroke(cv, [(AL(146) + 5, 146), (TL(164) - 1, 165)], SH_D, only={SH, SH_L, SH_LL})
    stroke(cv, [(AR(142) - 4, 142), (TR(158) + 1, 159)], SH_DD, only={SH, SH_D})
    for a, b in (((84, 154), (87, 166)), ((80, 178), (83, 188)), ((108, 160), (105, 170)),
                 ((111, 182), (108, 193)), ((95, 188), (97, 197))):
        stroke(cv, [a, b], SH_D, only={SH, SH_L, SH_LL})
    for x in range(int(AL(hemL)), int(TL(hemL)) + 1):
        if cv.get(x, hemL) in {SH, SH_L, SH_D}:
            cv.put(x, hemL, SH_DD)
    for x in range(int(TR(hemR)), int(AR(hemR)) + 1):
        if cv.get(x, hemR) in {SH, SH_L, SH_D}:
            cv.put(x, hemR, SH_DD)
    fillreg(cv, y1 - 2, y1, TL, TR, SH_D, only={SH, SH_L})
    return TL, TR, AL, AR, hemL, hemR


def side_arms(cv, sex, TL, TR, AL, AR, hemL, hemR):
    girl = (sex == 'girl')
    IK = G_ARMI if girl else B_ARMI
    AI = lambda y: knot(IK, y)
    # 먼 팔 (뒤, 어둡고 좁다)
    fillreg(cv, hemR + 1, 213, lambda y: TR(y) + 1, lambda y: AR(y) - 1, SK_D)
    fillreg(cv, hemR + 1, 213, lambda y: AR(y) - 4, lambda y: AR(y) - 1, SK_M, only={SK_D})
    fillreg(cv, hemR + 1, hemR + 3, lambda y: TR(y) + 1, lambda y: AR(y) - 1, SK_M, only={SK_D})
    # 가까운 팔 (앞, 밝고 넓다)
    ain = lambda y: 96 - AI(y) * 1.02 + 1.5
    fillreg(cv, hemL + 1, 221, AL, ain, SK)
    la = bw_(3401, 3.4, 1.3, 9)
    da = bw_(3407, 4.4, 1.6, 12)
    fillreg(cv, hemL + 1, 221, AL, lambda y: AL(y) + la(y), SK_L, only={SK})
    fillreg(cv, hemL + 1, 221, lambda y: ain(y) - da(y), ain, SK_D, only={SK, SK_L})
    fillreg(cv, hemL + 1, hemL + 3, AL, ain, SK_M, only={SK, SK_L, SK_D})
    stroke(cv, [(64, 211), (68, 212)], SK_D, only={SK, SK_L})
    stroke(cv, [(63, 216), (66, 217)], SK_D, only={SK, SK_L})
    stroke(cv, [(124, 206), (128, 207)], SK_M, only={SK_D})


def side_neck(cv):
    w = wob(3501, H)
    lf = lambda y: 96 - knot(NECKK, y) * 0.95 + 1.0 + w[y] * 0.4
    rf = lambda y: 95 + knot(NECKK, y) * 0.88 + 1.0 - w[y] * 0.4
    fillreg(cv, 103, 140, lf, rf, SK)
    fillreg(cv, 103, 129, lf, rf, SK_D, only={SK})
    fillreg(cv, 103, 124, lf, rf, SK_M, only={SK_D})
    fillreg(cv, 125, 140, lf, lambda y: lf(y) + 4.0, SK_L, only={SK, SK_D})


BOY_SFRINGE = [(60, 15, 64), (77, 16, 58), (94, 15, 63), (110, 16, 55), (126, 15, 61), (140, 12, 52)]
GIRL_SFRINGE = [(58, 14, 63), (73, 15, 57), (89, 16, 52), (105, 15, 58), (121, 16, 62), (137, 13, 64)]
BOY_SPADL = [(50, 16), (58, 13), (66, 10.5), (74, 8.2), (82, 6.2), (90, 4.2), (96, 2.0), (101, 0.0)]
BOY_SPADR = [(50, 10), (58, 7.5), (66, 5.0), (72, 2.6), (77, 1.0), (80, 0.0)]
GIRL_SPADL = [(50, 17), (60, 14), (70, 11.5), (80, 9.4), (92, 7.6), (104, 6.4), (112, 5.0), (118, 2.4), (121, 0.6)]
GIRL_SPADR = [(50, 11), (60, 8.6), (70, 6.4), (80, 4.4), (92, 2.6), (104, 1.6), (112, 1.0), (118, 0.4), (121, 0.0)]


def head_side(cv, sex):
    girl = (sex == 'girl')
    SX = 4.0
    wl = wob(3603 if girl else 3599, H)
    wr = wob(3617 if girl else 3621, H)

    def jaw(y):
        return 0.0 if y < 94 else (y - 94) * 0.26

    def nosf(y):
        if 97 <= y <= 113:
            return 6.6 * math.sin(math.pi * (y - 97) / 16.0) ** 0.60
        return 0.0

    def cheek(y):
        if 72 <= y <= 106:
            return 1.8 * math.sin(math.pi * (y - 72) / 34.0)
        return 0.0

    hl = lambda y: 96 - knot(HEADK, y) - cheek(y) + SX + jaw(y) * 0.60 + wl[y] * 0.7
    hr = lambda y: 95 + knot(HEADK, y) + SX + jaw(y) * 0.95 + nosf(y) - wr[y] * 0.7
    fillreg(cv, 14, 122, hl, hr, HR)

    fr = lobes(GIRL_SFRINGE if girl else BOY_SFRINGE, 34 if girl else 36)
    padl = GIRL_SPADL if girl else BOY_SPADL
    padr = GIRL_SPADR if girl else BOY_SPADR
    pw = wob(3701, H)
    fl = lambda y: hl(y) + knot(padl, y) + pw[y] * 0.5
    frt = lambda y: hr(y) - knot(padr, y) - pw[y] * 0.4
    for y in range(46, 123):
        a = int(round(fl(y)))
        b = int(round(frt(y)))
        for x in range(a, b + 1):
            if y >= fr(x) and cv.get(x, y) in HAIR:
                cv.put(x, y, SK)

    lwf = bw_(3711, 4.6, 1.8, 15)
    rwf = bw_(3719, 7.0, 2.6, 12)
    fillreg(cv, 52, 108, fl, lambda y: fl(y) + lwf(y), SK_L, only={SK})
    fillreg(cv, 52, 120, lambda y: frt(y) - rwf(y), frt, SK_D, only={SK, SK_L})
    bw2 = wob(3727, W, -1, 1, 3, 5)
    chin = {}
    for y in range(92, 123):
        for x in range(int(round(hl(y))), int(round(hr(y))) + 1):
            chin[x] = y
    for x, yb in chin.items():
        th = 3 + bw2[x]
        for y in range(yb - th, yb + 1):
            if cv.get(x, y) in {SK, SK_L}:
                cv.put(x, y, SK_D)
        if 88 < x < 116:
            for y in range(yb - 1, yb + 1):
                if cv.get(x, y) == SK_D:
                    cv.put(x, y, SK_M)
    sw = wob(3733, W, -1, 1, 2, 4)
    for x in range(48, 150):
        f0 = int(round(fr(x)))
        th = 3 + sw[x]
        for y in range(f0, f0 + th):
            if cv.get(x, y) in {SK, SK_L}:
                cv.put(x, y, SK_M)
        for y in range(f0 + th, f0 + th + 2):
            if cv.get(x, y) in {SK, SK_L}:
                cv.put(x, y, SK_D)

    # 가까운 쪽 귀
    ex0 = int(round(hl(92))) + 4
    for y in range(84, 101):
        t = (y - 84) / 16.0
        w = 5.4 * math.sin(math.pi * t) ** 0.7
        if w < 1.0:
            continue
        for x in range(int(round(ex0 - w * 0.55)), int(round(ex0 + w)) + 1):
            cv.put(x, y, SK)
    for y in range(87, 98):
        for x in range(ex0 - 1, ex0 + 2):
            if cv.get(x, y) == SK:
                cv.put(x, y, SK_D)
    for y in range(84, 101):
        for x in range(ex0 - 4, ex0 + 7):
            if cv.get(x, y) == SK:
                nb = [cv.get(x + 1, y), cv.get(x - 1, y), cv.get(x, y + 1), cv.get(x, y - 1)]
                if any(n in HAIR for n in nb):
                    cv.put(x, y, SK_DD)

    # ---- 이목구비 : 돌아선 쪽으로 몰린다
    ey = 84.0 if girl else 83.0
    rx = 12.6 if girl else 12.0
    ry = 16.6 if girl else 15.6
    if girl:
        brow(cv, 81, 98, 63, tilt=1.1)
        brow(cv, 119, 131, 61, tilt=-0.8)
    else:
        brow(cv, 82, 98, 64, tilt=1.2)
        brow(cv, 118, 130, 62, tilt=-0.9)
    eye(cv, 93.0, ey, rx, ry, out=-1, lash=3, tip=girl, ioff=2.2)
    eye(cv, 126.0, ey - 0.5, rx * 0.60, ry * 0.95, out=+1, lash=3, tip=girl, ioff=0.6)
    # 코 — 실루엣을 살짝 밀고 나간다
    for y in range(97, 113):
        e = int(round(hr(y)))
        w = 5 if 101 <= y <= 109 else 3
        for x in range(e - w, e + 1):
            if cv.get(x, y) in {SK, SK_L, SK_D}:
                cv.put(x, y, SK_D)
    for y in range(104, 110):
        e = int(round(hr(y)))
        for x in range(e - 3, e + 1):
            if cv.get(x, y) == SK_D:
                cv.put(x, y, SK_M)
    mouth(cv, 112 if girl else 111, 112, half=4, depth=1.8, open_=not girl)
    blush(cv, 82, 104, 8.6, 5.0)
    blush(cv, 131, 103, 5.0, 3.8)
    hair_detail_side(cv, sex, hl, hr)


def hair_detail_side(cv, sex, hl, hr):
    tm = topmap(cv, 40, 158, HAIR)
    gloss(cv, 60, 132, tm, lambda x: 8 + 2.0 * math.sin((x - 58) / 21.0),
          lambda x: max(0.0, 5.0 - abs(x - 86) / 12.0), HR_L, 3811)
    gloss(cv, 66, 110, tm, lambda x: 9 + 1.6 * math.sin((x - 62) / 18.0),
          lambda x: max(0.0, 2.6 - abs(x - 84) / 15.0), HR_LL, 3821)
    gloss(cv, 116, 156, tm, lambda x: 2, lambda x: 3.0 + (x - 116) * 0.10, HR_D, 3833)
    for x0, x1, off, th in ((52, 62, 14, 2), (100, 112, 5, 2), (124, 136, 8, 2), (70, 78, 18, 2)):
        gloss(cv, x0, x1, tm, lambda x, o=off: o, lambda x, t=th: t, HR_D, 3841 + x0)
    # 뒤통수 쪽 결
    for x0, y0, y1, th in ((56, 66, 96, 2), (62, 80, 104, 2), (68, 58, 82, 2)):
        for y in range(y0, y1 + 1):
            xx = int(round(x0 + (y - y0) * 0.10))
            for k in range(th):
                if cv.get(xx + k, y) in {HR, HR_L}:
                    cv.put(xx + k, y, HR_D)


G_SHAIR_BO = [(66,41.0),(78,44.0),(92,46.0),(110,47.4),(130,47.8),(150,47.0),(168,45.4),
              (182,43.2),(192,40.0),(198,36.0)]
G_SHAIR_RO = [(92,40.0),(102,42.4),(112,43.6),(126,44.4),(146,44.2),(164,43.0),(178,41.2),
              (190,38.6),(200,35.0),(206,31.0)]
G_SHAIR_RI = [(92,33.0),(100,27.0),(108,20.0),(116,14.0),(124,13.0),(134,17.0),(146,23.0),
              (158,26.4),(172,27.6),(186,28.2),(200,30.0),(206,31.0)]


def side_longhair_back(cv):
    wo = wob(3901, H)
    HO = lambda y: knot(G_SHAIR_BO, y) + wo[y] * 0.7
    tip = lobes([(56, 17, 178), (72, 15, 166), (86, 13, 184)], 154)
    fill_cap(cv, 66, 204, lambda y: 96 - HO(y), lambda y: 96 + 14, HR_D, tip)
    lw = bw_(3911, 6.0, 2.6, 25)
    fill_cap(cv, 68, 204, lambda y: 96 - HO(y), lambda y: 96 - HO(y) + lw(y), HR, tip, only={HR_D})
    for x0, y0, y1, th in ((54, 110, 176, 2), (61, 96, 160, 2), (70, 130, 188, 2), (78, 120, 168, 2)):
        for y in range(y0, y1 + 1):
            xx = int(round(x0 + (y - y0) * 0.04))
            for k in range(th):
                if cv.get(xx + k, y) in {HR, HR_D}:
                    cv.put(xx + k, y, HR_DD)
    for x in range(44, 120):
        b = int(round(tip(x)))
        for y in range(b - 4, b + 1):
            if cv.get(x, y) in {HR, HR_D}:
                cv.put(x, y, HR_DD)


def side_longhair_front(cv, hl):
    wo = wob(3931, H)
    wi = wob(3943, H)
    HO = lambda y: knot(G_SHAIR_RO, y) + wo[y] * 0.7
    HI = lambda y: knot(G_SHAIR_RI, y) + wi[y] * 0.5
    tip = lobes([(112, 14, 200), (128, 16, 211), (142, 13, 194)], 182)
    fill_cap(cv, 92, 214, lambda y: 95 + HI(y) + 3, lambda y: 95 + HO(y) + 3, HR, tip)
    rw = bw_(3951, 8.0, 3.2, 23)
    fill_cap(cv, 94, 214, lambda y: 95 + HO(y) + 3 - rw(y), lambda y: 95 + HO(y) + 3, HR_D, tip,
             only={HR})
    fill_cap(cv, 94, 214, lambda y: 95 + HI(y) + 3, lambda y: 95 + HI(y) + 6, HR_D, tip, only={HR})
    for x0, y0, y1, th in ((124, 108, 168, 2), (133, 126, 190, 3), (141, 114, 158, 2),
                           (118, 140, 184, 2)):
        for y in range(y0, y1 + 1):
            xx = int(round(x0 + (y - y0) * 0.06))
            for k in range(th):
                if cv.get(xx + k, y) in {HR, HR_L}:
                    cv.put(xx + k, y, HR_D)
    for x in range(96, 150):
        b = int(round(tip(x)))
        for y in range(b - 4, b + 1):
            if cv.get(x, y) in {HR, HR_L}:
                cv.put(x, y, HR_D)
    # 가까운 쪽 : 짧은 한 갈래
    lk = lobes([(62, 12, 156), (74, 11, 148)], 132)
    fill_cap(cv, 92, 160, lambda y: hl(y) + 1, lambda y: hl(y) + 15 + (y - 92) * 0.06, HR, lk)
    fill_cap(cv, 94, 160, lambda y: hl(y) + 10, lambda y: hl(y) + 15 + (y - 92) * 0.06, HR_D, lk,
             only={HR})
    for x in range(48, 96):
        b = int(round(lk(x)))
        for y in range(b - 3, b + 1):
            if cv.get(x, y) in {HR, HR_L}:
                cv.put(x, y, HR_D)


def draw_side(cv, sex):
    if sex == 'girl':
        side_legs_girl(cv)
        side_skirt_girl(cv)
        side_longhair_back(cv)
    else:
        side_legs_boy(cv)
    side_neck(cv)
    TL, TR, AL, AR, hemL, hemR = side_torso(cv, sex)
    if sex == 'girl':
        SX = 3.0
        wl = wob(3603, H)

        def jaw(y):
            return 0.0 if y < 96 else (y - 96) * 0.20
        hl = lambda y: 96 - knot(HEADK, y) + SX + jaw(y) * 0.60 + wl[y] * 0.7
        side_longhair_front(cv, hl)
    side_arms(cv, sex, TL, TR, AL, AR, hemL, hemR)
    head_side(cv, sex)




# ================================================================ 뒷모습
G_BHAIR = [(58,41.0),(66,43.6),(74,45.2),(84,46.4),(96,47.2),(112,47.8),(130,47.6),
           (150,46.8),(168,45.4),(182,43.4),(192,40.6),(200,37.0),(206,33.0)]


def head_back(cv, sex):
    girl = (sex == 'girl')
    wl = wob(4103 if girl else 4099, H)
    wr = wob(4117 if girl else 4121, H)
    hl = lambda y: 96 - knot(HEADB, y) + wl[y] * 0.7
    hr = lambda y: 95 + knot(HEADB, y) - wr[y] * 0.7
    fillreg(cv, 14, 122, hl, hr, HR)
    # 귀
    for side in (-1, 1):
        for y in range(83, 99):
            t = (y - 83) / 15.0
            e = 5.2 * math.sin(math.pi * t) ** 0.75
            if e < 1.2:
                continue
            if side < 0:
                a = int(round(hl(y)))
                rng = range(a, a + int(round(e)) + 1)
            else:
                b = int(round(hr(y)))
                rng = range(b - int(round(e)), b + 1)
            for x in rng:
                if cv.get(x, y) in HAIR:
                    cv.put(x, y, SK)
        for y in range(86, 96):
            if side < 0:
                a = int(round(hl(y))) + 1
                rr = range(a, a + 2)
            else:
                b = int(round(hr(y))) - 1
                rr = range(b - 1, b + 1)
            for x in rr:
                if cv.get(x, y) == SK:
                    cv.put(x, y, SK_D)
    # 목덜미
    if not girl:
        nw = wob(4201, W, -1, 1, 3, 5)
        nape = lambda x: 107 + 4.0 * math.cos(math.pi * max(-1.0, min(1.0, (x - 96) / 12.0))) + nw[x] * 1.0
        w = wob(4211, H)
        lf = lambda y: 96 - knot(NECKK, y) + w[y] * 0.4
        rf = lambda y: 95 + knot(NECKK, y) - w[y] * 0.4
        for y in range(100, 136):
            for x in range(int(round(lf(y))), int(round(rf(y))) + 1):
                cur = cv.get(x, y)
                if y >= nape(x) and (cur is None or cur in HAIR):
                    cv.put(x, y, SK_D)
        for y in range(100, 136):
            for x in range(int(round(lf(y))), int(round(rf(y))) + 1):
                if nape(x) <= y <= nape(x) + 4 and cv.get(x, y) == SK_D:
                    cv.put(x, y, SK_M)
        dn = bw_(4231, 4.6, 1.6, 11)
        fillreg(cv, 104, 135, lambda y: rf(y) - dn(y), rf, SK_M, only={SK_D})
        fillreg(cv, 112, 135, lambda y: lf(y), lambda y: lf(y) + 3.5, SK, only={SK_D})
    hair_detail_back(cv, sex, hl, hr)


def hair_detail_back(cv, sex, hl, hr):
    tm = topmap(cv, 40, 156, HAIR)
    gloss(cv, 56, 130, tm, lambda x: 9 + 2.0 * math.sin((x - 56) / 21.0),
          lambda x: max(0.0, 5.0 - abs(x - 84) / 12.0), HR_L, 4311)
    gloss(cv, 62, 104, tm, lambda x: 10 + 1.6 * math.sin((x - 60) / 18.0),
          lambda x: max(0.0, 2.4 - abs(x - 82) / 15.0), HR_LL, 4321)
    gloss(cv, 114, 152, tm, lambda x: 2, lambda x: 3.0 + (x - 114) * 0.10, HR_D, 4333)
    # 가마 — 짧은 결이 제각각 뻗는다
    cx, cy = 88, 30
    for ang, ln in ((-2.4, 9), (-1.6, 14), (-0.6, 8), (0.4, 12), (1.3, 7), (2.6, 11)):
        x0 = cx + 5 * math.cos(ang)
        y0 = cy + 3 * math.sin(ang)
        stroke(cv, [(x0, y0), (x0 + ln * math.cos(ang), y0 + ln * 0.55 * math.sin(ang) + ln * 0.35)],
               HR_D, only={HR, HR_L, HR_LL})


def longhair_back(cv):
    wo = wob(4401, H)
    HO = lambda y: knot(G_BHAIR, y) + wo[y] * 0.8
    tip = lobes([(58, 18, 208), (76, 16, 199), (94, 15, 212), (112, 16, 202), (131, 17, 209)], 201)
    fill_cap(cv, 58, 206, lambda y: 96 - HO(y), lambda y: 95 + HO(y), HR, tip)
    lw = bw_(4411, 8.0, 3.4, 27)
    rw = bw_(4421, 9.5, 3.8, 22)
    fill_cap(cv, 60, 206, lambda y: 96 - HO(y), lambda y: 96 - HO(y) + lw(y), HR_L, tip, only={HR})
    fill_cap(cv, 66, 150, lambda y: 96 - HO(y) + 3, lambda y: 96 - HO(y) + 6, HR_LL, tip, only={HR_L})
    fill_cap(cv, 60, 206, lambda y: 95 + HO(y) - rw(y), lambda y: 95 + HO(y), HR_D, tip, only={HR, HR_L})
    # 가운데 가르마 — 조금 비뚤게
    for y in range(62, 200):
        xx = int(round(92 + (y - 62) * 0.045))
        for k in range(2):
            if cv.get(xx + k, y) in {HR, HR_L}:
                cv.put(xx + k, y, HR_D)
    for x0, y0, y1, th in ((62, 100, 172, 2), (72, 120, 188, 2), (80, 88, 146, 2),
                           (104, 110, 178, 2), (116, 130, 194, 3), (126, 98, 160, 2)):
        for y in range(y0, y1 + 1):
            xx = int(round(x0 + (x0 - 96) * 0.05 * (y - y0) / float(max(1, y1 - y0))))
            for k in range(th):
                if cv.get(xx + k, y) in {HR, HR_L}:
                    cv.put(xx + k, y, HR_D)
    for x in range(44, 150):
        b = int(round(tip(x)))
        for y in range(b - 5, b + 1):
            if cv.get(x, y) in {HR, HR_L}:
                cv.put(x, y, HR_D)


def back_torso(cv, sex):
    girl = (sex == 'girl')
    TK = G_TOR if girl else B_TOR
    AK = G_ARMO if girl else B_ARMO
    y1 = 198 if girl else 203
    hemL = 170 if girl else 174
    hemR = 167 if girl else 171
    wl = wob(4501, H)
    wr = wob(4513, H)
    AO = lambda y: knot(AK, y)
    fillreg(cv, 133, hemL, lambda y: 96 - AO(y) + wl[y] * 0.6, lambda y: 96, SH)
    fillreg(cv, 133, hemR, lambda y: 95, lambda y: 95 + AO(y) - wr[y] * 0.6, SH)
    fillreg(cv, 133, y1, lambda y: 96 - knot(TK, y) + wl[y] * 0.5,
            lambda y: 95 + knot(TK, y) - wr[y] * 0.5, SH)
    lw = bw_(4521, 6.0, 2.6, 13)
    rw = bw_(4531, 7.0, 3.0, 11)
    fillreg(cv, 136, hemL, lambda y: 96 - AO(y), lambda y: 96 - AO(y) + lw(y), SH_L, only={SH})
    fillreg(cv, 135, hemR, lambda y: 95 + AO(y) - rw(y), lambda y: 95 + AO(y), SH_D, only={SH, SH_L})
    fillreg(cv, 150, y1, lambda y: 95 + knot(TK, y) - rw(y) * 0.8, lambda y: 95 + knot(TK, y),
            SH_D, only={SH, SH_L})
    fillreg(cv, 150, y1, lambda y: 96 - knot(TK, y), lambda y: 96 - knot(TK, y) + lw(y) * 0.6,
            SH_L, only={SH})
    # 뒷깃 — 뒤는 앞보다 높게 올라온다
    bc = wob(4551, W, -1, 1, 3, 5)
    for x in range(78, 115):
        d = (x - 96) / 18.0
        yt = int(round(128 + 5.0 * d * d + bc[x]))
        for y in range(yt, 134):
            if cv.get(x, y) in SKIN or cv.get(x, y) is None:
                cv.put(x, y, SH)
    cw = wob(4541, W)
    for x in range(80, 113):
        d = abs(x - 96) / 17.0
        yc = int(round(137 - 4.0 * d * d + cw[x]))
        for y in range(128, yc + 1):
            if cv.get(x, y) in {SH, SH_L, SH_D}:
                cv.put(x, y, SH_D)
    for x in range(83, 110):
        d = abs(x - 96) / 15.0
        yc = int(round(132 - 3.0 * d * d + cw[x + 20] * 0.7))
        for y in range(128, yc + 1):
            if cv.get(x, y) == SH_D:
                cv.put(x, y, SH_DD)
    # 등 주름
    for a, b in (((84, 156), (87, 168)), ((79, 180), (82, 190)), ((110, 150), (107, 162)),
                 ((113, 178), (110, 190)), ((96, 184), (98, 195))):
        stroke(cv, [a, b], SH_D, only={SH, SH_L})
    for x in range(int(96 - AO(hemL)), int(96 - knot(TK, hemL)) + 1):
        if cv.get(x, hemL) in {SH, SH_L, SH_D}:
            cv.put(x, hemL, SH_DD)
    for x in range(int(95 + knot(TK, hemR)), int(95 + AO(hemR)) + 1):
        if cv.get(x, hemR) in {SH, SH_L, SH_D}:
            cv.put(x, hemR, SH_DD)
    fillreg(cv, y1 - 2, y1, lambda y: 96 - knot(TK, y), lambda y: 95 + knot(TK, y), SH_D,
            only={SH, SH_L})
    return hemL, hemR


def back_boots(cv):
    # 뒤꿈치
    O = lambda y: knot(B_BOOO, y)
    fillreg(cv, 276, 286, lambda y: 96 - O(y), lambda y: 95 + O(y), SO_D, only={SO})
    fillreg(cv, 280, 286, lambda y: 96 - O(y), lambda y: 95 + O(y), SO_DD, only={SO_D})
    for side in (-1, 1):
        base = (lambda y: 96 - O(y) + 5) if side < 0 else (lambda y: 95 + O(y) - 10)
        fillreg(cv, 258, 278, base, lambda y: base(y) + 5, SO_D, only={SO})


def draw_back(cv, sex):
    if sex == 'girl':
        legs_girl(cv)
        skirt_girl(cv)
    else:
        legs_boy(cv)
        back_boots(cv)
    hemL, hemR = back_torso(cv, sex)
    arms_front(cv, sex, hemL, hemR)
    if sex == 'girl':
        longhair_back(cv)
    head_back(cv, sex)


DIR = os.path.dirname(os.path.abspath(__file__))


def main():
    for sex in ('boy', 'girl'):
        for kind in ('down', 'side', 'up'):
            cv = Cv()
            if kind == 'side':
                draw_side(cv, sex)
            elif kind == 'up':
                draw_back(cv, sex)
            else:
                draw_front(cv, sex)
            fillholes(cv)
            outline(cv)
            thicken(cv, seed=17 if sex == 'boy' else 23)
            outline(cv)
            finish(cv, os.path.join(DIR, 'w192_g_%s_%s.png' % (sex, kind)))


if __name__ == '__main__':
    main()
