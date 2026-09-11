#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""e128hd - 128x192 native, maximum-detail HD-2D (Octopath-ish) hero sprites.

Flat banded shading (no gradients), per-material dark outlines, 3.7-head
proportions, readable face at 36x54.  Pillow only, no numpy.

    python3 e128hd.py     ->  e128hd_boy.png  e128hd_girl.png  e128hd_view.png
"""
import os, math
from PIL import Image

W, H = 128, 192
AX = 63.5                      # mirror axis: x and 127-x are partners
HERE = os.path.dirname(os.path.abspath(__file__))
GRASS = (122, 150, 96)

# ------------------------------------------------------------------ palette
SK   = (243,159,138); SK_L = (250,192,170); SK_D  = (213,116, 98)
SK_CH= (235,128,114); SK_M = (170, 84, 66); SK_DD = (184, 99, 83)
SK_LL= (252,217,204)

HR   = (118, 72, 40); HR_L = (152,100, 56); HR_D  = ( 86, 52, 30)
HR_DD= ( 58, 35, 20); HR_LL= (195,165,140)

TP   = ( 58, 88,168); TP_D = ( 38, 58,120); TP_L  = ( 94,126,200)
TP_DD= ( 27, 41, 84); TP_LL= (166,184,225)

BT   = (134, 88, 46); BT_D = ( 98, 62, 32); BT_L  = (158,108, 58)
BT_DD= ( 69, 43, 22); BT_LL= (202,174,147)

SH   = ( 82, 53, 33); SH_D = ( 56, 37, 25); SH_DD = ( 39, 26, 18)

EYE  = ( 66, 32, 30); BROW = (136, 70, 42); WHT = (246,242,234)

# per-material outline colours (free per SPEC 2)
OL = {'skin': (110, 53, 46),
      'hair': ( 30, 18, 14),
      'top' : ( 19, 27, 56),
      'bot' : ( 47, 28, 15),
      'shoe': ( 24, 16, 11)}

# base, light, dark, deep, extra-light  (used by the rim shader)
SHADE = {
    'skin': (SK, SK_L, SK_D, SK_DD, SK_LL),
    'hair': (HR, HR_L, HR_D, HR_DD, HR_LL),
    'top' : (TP, TP_L, TP_D, TP_DD, TP_LL),
    'bot' : (BT, BT_L, BT_D, BT_DD, BT_LL),
    'hair2':(HR_D, HR,  HR_DD, HR_DD, HR_L),
    'shoe': (SH, SH,   SH_D, SH_DD, SH),
}
OL['hair2'] = OL['hair']

PAL = set()
for t in SHADE.values():
    PAL |= set(t)
PAL |= {SK_CH, SK_M, BT_L, TP_L, HR_L, SH_D}
ALLOWED = PAL | {EYE, BROW, WHT} | set(OL.values())

# ------------------------------------------------------------------ canvas
PX = {}     # (x,y) -> rgb
MT = {}     # (x,y) -> material name (outline pixels are NOT in here)
CUR = {}    # per-figure profiles, filled by build()


def reset():
    PX.clear(); MT.clear(); CUR.clear()


def face_hw(y):
    return CUR['face'].get(y, -1.0)


def torso_hw(y):
    t = CUR['torso']
    return t.get(y, t[max(t)] if y > max(t) else t[min(t)])


def arm_run(y, c, only='top', m=None):
    """paint a row on the arms only - never across the torso"""
    lim = torso_hw(y) + 1.0
    for x in range(30, 98):
        if abs(x - AX) <= lim: continue
        pon(x, y, c, only, m)


def side_run(y, c, only='hair', m=None):
    """paint a row on the side hair only - never across the fringe"""
    lim = face_hw(y) - 1.5
    for x in range(30, 98):
        if lim > 0 and abs(x - AX) <= lim: continue
        pon(x, y, c, only, m)


def put(x, y, c, m=None):
    if c is None: return
    if 0 <= x < W and 0 <= y < H:
        PX[(x, y)] = c
        if m: MT[(x, y)] = m


def put2(x, y, c, m=None, only=None):
    """draw at x and at its mirror 127-x"""
    for xx in (x, 127 - x):
        if only is not None and MT.get((xx, y)) != only: continue
        put(xx, y, c, m)


def pon(x, y, c, only=None, m=None):
    """paint only where something already exists (optionally of material `only`)"""
    if (x, y) not in MT: return
    if only is not None and MT[(x, y)] != only: return
    put(x, y, c, m)


def pon2(x, y, c, only=None, m=None):
    pon(x, y, c, only, m); pon(127 - x, y, c, only, m)


def erase(x, y):
    PX.pop((x, y), None); MT.pop((x, y), None)


def scallop(ylo, yhi, mat, depths):
    """nibble the bottom edge of a material so hems / hair tips are not flat"""
    n = len(depths)
    for x in range(24, 104):
        ys = [y for y in range(ylo, yhi + 1) if MT.get((x, y)) == mat]
        if not ys: continue
        d = depths[int(abs(x - AX)) % n]
        ym = max(ys)
        for y in range(ym - d + 1, ym + 1):
            erase(x, y)


def neckline(cy, rx, ry, cd, cl, mat='top'):
    for t in range(0, 541):
        a = math.radians(t / 3.0)
        x = int(round(AX + rx * math.cos(a)))
        y = int(round(cy + ry * math.sin(a)))
        pon(x, y, cd, mat); pon(x, y + 1, cd, mat)
        pon(x, y + 2, cl, mat)


def hrun(y, xa, xb, c, only=None, m=None):
    for x in range(xa, xb + 1):
        pon(x, y, c, only, m)


def stroke(pts, c, only=None, mirror=False, m=None):
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]; x1, y1 = pts[i + 1]
        n = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(n + 1):
            t = k / n if n else 0.0
            x = int(math.floor(x0 + (x1 - x0) * t + 0.5))
            y = int(math.floor(y0 + (y1 - y0) * t + 0.5))
            pon(x, y, c, only, m)
            if mirror: pon(127 - x, y, c, only, m)


# ------------------------------------------------------------------ profiles
def prof(pts):
    """linear interpolation of (y, half-width) keys -> {y: hw}"""
    pts = sorted(pts)
    out = {}
    for i in range(len(pts) - 1):
        y0, h0 = pts[i]; y1, h1 = pts[i + 1]
        for y in range(y0, y1 + 1):
            t = 0.0 if y1 == y0 else (y - y0) / float(y1 - y0)
            out[y] = h0 + (h1 - h0) * t
    return out


def smooth(d, n=2):
    """round off the corners so the silhouette never reads as facets"""
    for _ in range(n):
        e = {}
        for y in d:
            a = d.get(y - 1, d[y]); b = d.get(y + 1, d[y])
            e[y] = (a + 2.0 * d[y] + b) / 4.0
        d = e
    return d


def sprof(pts, n=2):
    return smooth(prof(pts), n)


def band(y, ho, hi, c, m):
    """symmetric horizontal band(s) of half-width hi..ho"""
    if hi <= 0.3:
        xa = int(math.ceil(AX - ho)); xb = int(math.floor(AX + ho))
        for x in range(xa, xb + 1): put(x, y, c, m)
    else:
        xa = int(math.ceil(AX - ho)); xb = int(math.floor(AX - hi))
        for x in range(xa, xb + 1): put(x, y, c, m)
        xa = int(math.ceil(AX + hi)); xb = int(math.floor(AX + ho))
        for x in range(xa, xb + 1): put(x, y, c, m)


def fill(outer, inner=None, c=None, m=None, y0=None, y1=None):
    po = sprof(outer)
    pi = sprof(inner) if inner else None
    for y in sorted(po):
        if y0 is not None and y < y0: continue
        if y1 is not None and y > y1: continue
        ho = po[y]
        hi = pi.get(y, 0.0) if pi else 0.0
        if ho <= 0.2: continue
        band(y, ho, hi, c, m)


def crown_tops(hd):
    """for every column, the topmost row of a half-width profile"""
    tops = {}
    for y in sorted(hd):
        ho = hd[y]
        for x in range(int(math.ceil(AX - ho)), int(math.floor(AX + ho)) + 1):
            if x not in tops: tops[x] = y
    return tops


def fringe_fn(pts):
    pts = sorted(pts)
    def f(x):
        off = x - AX
        if off <= pts[0][0]: return pts[0][1]
        if off >= pts[-1][0]: return pts[-1][1]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            if a[0] <= off <= b[0]:
                t = (off - a[0]) / float(b[0] - a[0])
                return a[1] + (b[1] - a[1]) * t
        return pts[-1][1]
    return f


# ------------------------------------------------------------------ geometry
FACE_B = [(22,12.4),(25,14.2),(29,15.4),(34,16.1),(40,16.1),(45,15.5),
          (49,14.3),(52,12.7),(54,10.9),(56,9.2),(57,8.2)]
FACE_G = [(22,12.0),(25,13.8),(29,15.0),(34,15.7),(40,15.8),(45,15.3),
          (49,14.2),(52,12.7),(54,10.9),(56,9.0),(57,8.0)]

HAIR_B = [(4,5.5),(6,9.8),(8,12.8),(10,15.0),(13,16.9),(16,18.1),(20,18.9),
          (25,19.1),(30,18.8),(34,18.2),(37,17.2),(40,15.8),(42,14.6)]
CROWN_B = [(-20,0),(-17,3),(-15,0),(-12,4),(-9,1),(-6,3),(-3,0),(1,4),
           (4,0),(7,2),(10,0),(13,4),(16,1),(19,3),(21,0)]
CROWN_G = [(-20,0),(-15,1),(-9,0),(-3,1),(2,0),(8,1),(14,0),(20,1)]
HAIR_G = [(5,6.5),(7,11.0),(9,14.0),(11,16.2),(14,18.0),(17,19.2),(21,19.9),
          (26,20.3),(32,20.4),(38,20.3),(44,20.2),(52,20.0),(58,19.6)]

FRINGE_B = [(-22,45),(-19,41),(-16,34),(-14,37),(-12,30),(-10,35),(-7,28),
            (-5,33),(-2,27),(1,32),(3,28),(6,34),(9,29),(11,35),(14,31),
            (16,38),(19,42),(22,46)]
FRINGE_G = [(-22,44),(-19,40),(-17,36),(-15,33),(-13,34),(-11,30),(-9,31),
            (-7,28),(-5,29),(-3,26),(-1,25),(1,26),(3,25),(5,28),(7,27),
            (9,30),(11,29),(13,32),(15,34),(17,37),(19,40),(22,45)]

NECK_B = [(50,8.2),(60,8.2),(64,7.8),(66,7.0),(67,5.6),(68,3.0)]
NECK_G = [(50,7.4),(60,7.4),(64,7.0),(66,6.4),(67,5.2),(68,2.8)]

TORSO_B = [(62,8.6),(64,10.6),(67,13.0),(71,14.8),(76,15.6),(84,15.2),
           (94,13.9),(102,13.8),(110,15.2),(115,15.9),(117,16.0)]
TORSO_G = [(62,7.6),(64,9.4),(67,11.6),(71,13.0),(76,13.8),(84,13.2),
           (92,12.2),(97,12.6),(101,13.2),(103,13.4)]

ARM_B_O = [(64,10.8),(66,14.8),(68,18.2),(70,20.6),(73,22.3),(77,23.2),
           (86,23.2),(92,22.9),(96,21.8),(106,21.3),(114,21.0),(118,21.6),
           (122,21.8),(125,21.2),(127,19.6)]
ARM_G_O = [(64,9.6),(66,13.2),(68,16.2),(70,18.2),(73,19.6),(77,20.3),
           (84,20.3),(88,19.6),(94,19.0),(104,18.6),(112,18.4),(116,19.0),
           (120,19.2),(123,18.6),(125,17.2)]

PANTS_O = [(108,15.4),(114,15.7),(120,15.3),(126,14.8),(132,14.2),
           (139,13.5),(145,13.1),(151,12.7),(158,12.1),(164,11.6),
           (170,11.2),(174,11.0)]
PANTS_I = [(108,0.0),(116,0.0),(119,0.8),(125,1.6),(135,1.8),(146,1.4),
           (157,1.6),(170,1.9),(174,2.0)]

BOOT_O  = [(168,11.4),(172,12.4),(176,13.0),(181,13.6),(185,14.0),
           (188,14.2),(189,14.2)]
BOOT_I  = [(168,1.5),(180,1.8),(189,2.1)]

SKIRT_O = [(99,13.6),(103,15.4),(108,17.6),(115,19.8),(121,21.4),
           (127,22.2),(131,22.5),(133,22.5)]

GLEG_O  = [(120,11.2),(126,11.0),(132,10.6),(138,10.1),(144,9.7),
           (149,9.5),(153,9.8),(157,9.4),(161,8.7),(165,8.1),(169,7.6),
           (172,7.5)]
GLEG_I  = [(120,1.4),(132,1.7),(142,2.0),(152,1.5),(163,1.7),(172,2.0)]

GSHOE_O = [(168,8.2),(172,9.3),(177,10.1),(182,10.7),(186,11.1),(189,11.3)]
GSHOE_I = [(168,1.6),(189,2.0)]

BACKHAIR = [(11,11.0),(16,15.6),(22,18.8),(30,20.6),(42,21.2),(56,21.5),
            (68,21.9),(78,21.5),(88,20.4),(96,17.8),(102,14.0),(105,9.5),
            (107,5.0)]

SIDELOCK_O = [(22,19.4),(32,20.2),(44,20.4),(54,19.6),(62,18.0),(70,17.0),
              (80,16.4),(88,15.6),(92,14.8)]
SIDELOCK_I = [(22,14.2),(32,14.6),(44,15.0),(54,13.6),(60,10.4),(66,9.6),
              (72,10.2),(80,11.4),(86,12.6),(90,13.8),(92,14.4)]


# ------------------------------------------------------------------ passes
def rim_shade():
    """per-row run shading: lit on the outer-left, banded dark on the right."""
    for y in range(H):
        x = 0
        while x < W:
            m = MT.get((x, y))
            if m is None:
                x += 1; continue
            x2 = x
            while x2 + 1 < W and MT.get((x2 + 1, y)) == m:
                x2 += 1
            base, L, D, DD, LL = SHADE[m]
            w = x2 - x + 1
            lo = (x - 1, y) not in MT
            ro = (x2 + 1, y) not in MT
            nl = min(4, max(1, w // 8)) if w >= 3 else 0
            nr = min(6, max(1, w // 6)) if w >= 3 else 0
            if lo:
                for i in range(nl): put(x + i, y, L)
                if w >= 14: put(x, y, LL)
            elif w >= 3:
                put(x, y, D)
            if ro:
                for i in range(nr): put(x2 - i, y, D)
                if w >= 4: put(x2, y, DD)
            elif w >= 3:
                put(x2, y, D)
            x = x2 + 1


def cast_shadow():
    """1-2 rows of cast shadow under every material boundary"""
    ch = {}
    for (x, y), m in MT.items():
        a1 = MT.get((x, y - 1)); a2 = MT.get((x, y - 2))
        if a1 is not None and a1 != m:
            ch[(x, y)] = SHADE[m][3]
        elif a2 is not None and a2 != m:
            ch[(x, y)] = SHADE[m][2]
    PX.update(ch)


def outline():
    add = {}
    for (x, y) in list(MT.keys()):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in MT:
                add.setdefault((nx, ny), []).append(MT[(x, y)])
    for k, ms in add.items():
        best = max(set(ms), key=ms.count)
        PX[k] = OL[best]


# ------------------------------------------------------------------ body
def draw_head(girl):
    facep = FACE_G if girl else FACE_B
    hairp = HAIR_G if girl else HAIR_B
    frg = fringe_fn(FRINGE_G if girl else FRINGE_B)
    neckp = NECK_G if girl else NECK_B

    fill(neckp, None, SK, 'skin')
    fill(facep, None, SK, 'skin')

    hd = sprof(hairp); fd = sprof(facep)
    tops = crown_tops(hd)
    jag = fringe_fn(CROWN_G if girl else CROWN_B)
    ytop = min(hd); ybot = max(hd)
    for y in range(ytop, ybot + 1):
        ho = hd[y]
        xa = int(math.ceil(AX - ho)); xb = int(math.floor(AX + ho))
        fh = fd.get(y, -1.0)
        for x in range(xa, xb + 1):
            if y < tops.get(x, 0) + jag(x): continue
            if y < frg(x) or abs(x - AX) > fh:
                put(x, y, HR, 'hair')

    # ears sit in front of the side hair
    if not girl:
        fill([(40,15.8),(43,17.3),(47,17.4),(50,16.4),(52,14.6)],
             [(40,13.6),(43,13.4),(47,13.2),(50,12.6),(52,12.0)], SK, 'skin')


def draw_boy():
    fill(PANTS_O, PANTS_I, BT, 'bot')
    fill(BOOT_O, BOOT_I, SH, 'shoe')
    fill(TORSO_B, None, TP, 'top')

    # arms: sleeve / forearm / hand, inner edge peels off the torso at the pit
    ao = sprof(ARM_B_O); to = sprof(TORSO_B)
    for y in sorted(ao):
        ho = ao[y]
        tw = to.get(y, to[max(to)])
        if y <= 70: off = -2.2
        elif y >= 78: off = 2.5
        else: off = -2.2 + 4.7 * (y - 70) / 8.0
        hi = max(0.0, tw + off)
        if y >= 120: hi = min(hi, ho - 4.6)
        mat = 'top' if y <= 92 else 'skin'
        if y >= 119:                       # hand: a touch fuller than the wrist
            ho += 0.5
            hi -= 0.4
        band(y, ho, hi, TP if mat == 'top' else SK, mat)


def draw_girl():
    fill(BACKHAIR, None, HR_D, 'hair2')
    fill(GLEG_O, GLEG_I, SK, 'skin')
    fill(GSHOE_O, GSHOE_I, SH, 'shoe')
    fill(SKIRT_O, None, BT, 'bot')
    scallop(124, 136, 'bot', [0, 1, 2, 2, 1, 0, 0])
    fill(TORSO_G, None, TP, 'top')

    CUR['arm_in'] = {}
    ao = sprof(ARM_G_O); to = sprof(TORSO_G)
    tmax = to[max(to)]
    for y in sorted(ao):
        ho = ao[y]
        tw = to.get(y, tmax)
        if y <= 68: off = -2.0
        elif y >= 76: off = 2.5
        else: off = -2.0 + 4.5 * (y - 68) / 8.0
        hi = max(0.0, tw + off)
        if y >= 96: hi = min(hi, ho - 4.4)
        mat = 'top' if y <= 84 else 'skin'
        if y >= 117:
            ho += 0.5; hi -= 0.4
        CUR['arm_in'][y] = hi
        band(y, ho, hi, TP if mat == 'top' else SK, mat)

    # no back hair may show through the armpit gap - it reads as noise
    for y in range(72, 130):
        ai = CUR['arm_in'].get(y)
        if ai is None: continue
        lim = torso_hw(y) + 0.4
        for x in range(24, 104):
            o = abs(x - AX)
            if lim < o < ai - 0.4 and MT.get((x, y)) == 'hair2':
                erase(x, y)
    fill(SIDELOCK_O, SIDELOCK_I, HR, 'hair')
    # hair tips, not a flat round blob
    scallop(92, 112, 'hair2', [0, 1, 3, 2, 0, 2, 4, 1])


# ------------------------------------------------------------------ details
def eye(cx, ytop, girl):
    """7x7 eye.  cx is the OUTER (temple) column; mirrored automatically.
    col0 outer ... col6 inner.  Kept light: 4-wide iris, white on both sides."""
    y = ytop
    for x in range(cx + 1, cx + 6): put2(x, y, EYE)          # top lash arc
    for x in range(cx, cx + 7): put2(x, y + 1, EYE)          # lash line
    for r in (2, 3, 4, 5):
        if r < 3: put2(cx, y + r, EYE)
        elif r == 3: put2(cx, y + r, SK_DD)
        put2(cx + 1, y + r, WHT)
        for x in range(cx + 2, cx + 6): put2(x, y + r, EYE)
        put2(cx + 6, y + r, WHT)
    # round the iris off at the bottom corners
    put2(cx + 2, y + 5, WHT); put2(cx + 5, y + 5, WHT)
    for x in range(cx + 3, cx + 5): put2(x, y + 6, SK_DD)
    put2(cx + 2, y + 6, SK_D); put2(cx + 5, y + 6, SK_D)
    # one 2x1 glint at the top-outer of the iris
    put2(cx + 2, y + 2, WHT); put2(cx + 3, y + 2, WHT)
    if girl:
        put2(cx, y, EYE); put2(cx - 1, y + 1, EYE)


def face_details(girl):
    ey = 38 if girl else 39
    eye(52, ey, girl)

    # brows - lifted, tapering outward, never a flat bar
    if girl:
        for x in range(54, 60): put2(x, 33, BROW)
        for x in range(52, 56): put2(x, 34, BROW)
    else:
        for x in range(55, 60): put2(x, 34, BROW)
        for x in range(52, 58): put2(x, 35, BROW)
        for x in range(52, 55): put2(x, 36, BROW)

    # cheeks - flat pink patches, outer half of the cheek
    cy = 46 if girl else 46
    for y in range(cy, cy + 3):
        a, b = (50, 54) if y < cy + 2 else (51, 54)
        for x in range(a, b + 1): pon2(x, y, SK_CH, 'skin')

    # nose: a 2px wedge only
    ny = 47 if girl else 48
    pon2(63, ny, SK_D, 'skin')
    pon2(63, ny + 1, SK_DD, 'skin')

    # mouth - both smile, the girl's smaller
    my = 51 if girl else 52
    if girl:
        for x in range(62, 66): pon(x, my + 1, SK_M, 'skin')
        pon2(61, my, SK_DD, 'skin')
    else:
        pon2(61, my, SK_DD, 'skin')
        for x in range(62, 66): pon(x, my + 1, SK_M, 'skin')

    # under-chin cast shadow on the neck, narrowing downwards
    hrun(56, 59, 68, SK_D, 'skin')
    hrun(58, 58, 69, SK_DD, 'skin')
    hrun(59, 59, 68, SK_D, 'skin')
    hrun(60, 60, 67, SK_D, 'skin')

    # ear interior (boy)
    if not girl:
        stroke([(48, 44), (47, 46), (48, 48)], SK_D, 'skin', mirror=True)


def hair_details(girl):
    if girl:
        # shine band, broken so it never reads as a square sticker
        for off in range(-16, 17):
            x = int(round(AX + off))
            yy = 17 + int(round(0.020 * off * off))
            if (abs(off) % 8) in (3, 4): continue
            pon(x, yy, HR_L, 'hair'); pon(x, yy + 1, HR_L, 'hair')
        for off in (-10, -9, 5, 6, 7):
            x = int(round(AX + off)); yy = 17 + int(round(0.020 * off * off))
            pon(x, yy, HR_LL, 'hair')
        # centre part + long strand partings
        stroke([(64, 7), (64, 13)], HR_D, 'hair')
        stroke([(62, 9), (60, 16)], HR_L, 'hair')
        stroke([(66, 9), (68, 16)], HR_L, 'hair')
        for xs, ys, xe, ye in ((56, 20, 50, 40), (50, 26, 45, 48),
                               (46, 34, 43, 60), (44, 46, 41, 78)):
            stroke([(xs, ys), (xe, ye)], HR_D, 'hair', mirror=True)
        for xs, ys, xe, ye in ((53, 24, 48, 44), (45, 40, 42, 66)):
            stroke([(xs, ys), (xe, ye)], HR_L, 'hair', mirror=True)
        # back-hair length strokes - drawn in the hair2 tones or they vanish
        for pts, c in ((((41, 28), (39, 66), (40, 98)), HR),
                       (((45, 34), (43, 74), (44, 100)), HR_DD),
                       (((48, 42), (46, 86)), HR),
                       (((38, 48), (37, 88)), HR_DD),
                       (((51, 52), (49, 94)), HR_DD)):
            stroke(list(pts), c, 'hair2', mirror=True)
        # crown volume on the back hair
        for pts in (((44, 22), (40, 40)), ((50, 16), (44, 32))):
            stroke(list(pts), HR, 'hair2', mirror=True)
        # side-lock strand detail
        for pts, c in ((((47, 30), (44, 62), (45, 88)), HR_L),
                       (((51, 34), (48, 70), (48, 90)), HR_D)):
            stroke(list(pts), c, 'hair', mirror=True)
        # tips of the side locks darken
        for y in range(84, 93):
            side_run(y, HR_D)
    else:
        for off in range(-15, 16):
            x = int(round(AX + off))
            yy = 16 + int(round(0.024 * off * off))
            if (abs(off) % 7) in (3, 4): continue
            pon(x, yy, HR_L, 'hair'); pon(x, yy + 1, HR_L, 'hair')
        for off in (-11, -10, 6, 7, 8):
            x = int(round(AX + off)); yy = 16 + int(round(0.024 * off * off))
            pon(x, yy, HR_LL, 'hair')
        # spiky fringe partings
        for pts in (((59, 12), (55, 22), (52, 30)),
                    ((64, 9), (61, 18), (58, 27)),
                    ((69, 11), (72, 20), (75, 29)),
                    ((50, 18), (47, 27), (46, 36)),
                    ((77, 17), (80, 26), (81, 34))):
            stroke(list(pts), HR_D, 'hair')
        for pts in (((57, 16), (54, 25), (52, 31)),
                    ((71, 15), (74, 24), (76, 30))):
            stroke(list(pts), HR_L, 'hair')
        # sideburn darkening - side hair only, never the fringe
        for y in range(33, 43):
            side_run(y, HR_D)
        # one lock falling across the right temple (asymmetry)
        for y in range(30, 43):
            x = 78 - (y - 30) // 4
            for k in (0, 1):
                pon(x + k, y, HR if k == 0 else HR_D, 'skin', m='hair')


def cloth_details(girl):
    if girl:
        # blouse collar
        neckline(62, 9.0, 9.5, TP_D, TP_L)
        pon2(58, 73, TP_LL, 'top')
        stroke([(54, 70), (46, 75)], TP_D, 'top', mirror=True)
        # puffed sleeve hem + a gather crease on the cap
        arm_run(82, TP_D)
        for y in (83, 84):
            arm_run(y, TP_DD)
        stroke([(46, 72), (44, 79)], TP_D, 'top', mirror=True)
        # hem shadow only
        for y in (98, 99):
            hrun(y, 46, 81, TP_DD, 'top')
        stroke([(47, 72), (45, 78)], TP_D, 'top', mirror=True)
        # waistband - sits exactly at the blouse hem
        for y in (101, 102, 103):
            hrun(y, 40, 87, BT_DD if y == 101 else BT_D, 'bot')
        for y in (100, 101, 102, 103):
            hrun(y, 40, 87, TP_DD, 'top')
        # radiating pleats: dark crease with a lit edge beside it
        for f in (-0.78, -0.50, -0.22, 0.22, 0.50, 0.78):
            xt = int(round(AX + f * 15.0)); xb = int(round(AX + f * 21.6))
            stroke([(xt, 104), (xb, 130)], BT_D, 'bot')
            stroke([(xt + 1, 104), (xb + 1, 130)], BT_L, 'bot')
        # hem
        for y in range(124, 136):
            for x in range(30, 98):
                if MT.get((x, y)) == 'bot' and MT.get((x, y + 1)) != 'bot':
                    put(x, y, BT_DD); put(x, y - 1, BT_D)
        # knee highlight, calf shadow
        for y in (143, 144):
            for x in range(55, 59): pon2(x, y, SK_L, 'skin')
        for y in range(150, 162):
            pon2(54 - (y - 150) // 6, y, SK_D, 'skin')
        # shoe strap + toe
        for y in (170, 171):
            hrun(y, 50, 77, SH_DD, 'shoe')
        for y in (181, 182):
            hrun(y, 50, 77, SH_D, 'shoe')
    else:
        # collar + shoulder seams
        neckline(62, 9.6, 10.2, TP_D, TP_L)
        stroke([(56, 70), (47, 76)], TP_D, 'top', mirror=True)
        # placket + buttons
        for y in range(74, 112):
            pon(63, y, TP_DD, 'top'); pon(62, y, TP_D, 'top')
            pon(65, y, TP_L, 'top')
        for y in (80, 90, 100):
            pon(63, y, TP_LL, 'top'); pon(64, y, TP_LL, 'top')
            pon(63, y + 1, TP_DD, 'top'); pon(64, y + 1, TP_DD, 'top')
        # sleeve cuffs
        for y in (90, 91, 92):
            arm_run(y, TP_DD)
        # broad tone areas only - no hairline creases
        for y in (108, 109):                # hem shadow above the belt
            hrun(y, 46, 81, TP_DD, 'top')
        # chest pocket (one side only - a little asymmetry reads as hand-made)
        for x in range(52, 60): pon(x, 84, TP_D, 'top')
        for y in range(85, 93):
            pon(52, y, TP_D, 'top'); pon(59, y, TP_DD, 'top')
        for x in range(52, 60): pon(x, 93, TP_DD, 'top')
        for x in range(53, 59): pon(x, 85, TP_L, 'top')
        # belt
        for y in range(110, 118):
            c = SH if 110 < y < 117 else SH_DD
            for x in range(44, 84):
                if abs(x - AX) > torso_hw(y) + 0.5: continue
                pon(x, y, c, 'top', m='shoe'); pon(x, y, c, 'bot', m='shoe')
        for y in range(112, 116):
            for x in range(61, 67): pon(x, y, BT_LL, 'shoe')
        for x in range(62, 66): pon(x, 113, SH_DD, 'shoe')
        for x in range(61, 67): pon(x, 116, SH_DD, 'shoe')
        # knee creases: short slanted pairs, never one bar across both legs
        for (x0, y0), (x1, y1) in (((53, 145), (59, 143)),
                                   ((54, 151), (60, 149))):
            stroke([(x0, y0 - 1), (x1, y1 - 1)], BT_L, 'bot', mirror=True)
            stroke([(x0, y0), (x1, y1)], BT_D, 'bot', mirror=True)
        # outer seam
        for y in range(122, 168):
            pon2(51 + (y - 122) // 13, y, BT_D, 'bot')
        # trouser cuff turned over the boot
        for y in (166, 167, 168):
            hrun(y, 48, 79, BT_L if y == 166 else BT_DD, 'bot')
        # boot: cuff, vamp seam, toe
        for y in (169, 170):
            hrun(y, 48, 79, SH_DD, 'shoe')
        for y in (182, 183):
            hrun(y, 46, 81, SH_D, 'shoe')
        hrun(181, 46, 81, SH, 'shoe')
    hand_details(117 if girl else 119)
    # sole
    for y in (187, 188, 189):
        hrun(y, 36, 91, SH_DD, 'shoe')


def hand_details(hy):
    """wrist band, knuckle highlight, two finger splits, shaded fingertips"""
    for y in range(hy, hy + 11):
        xs = [x for x in range(30, 58) if MT.get((x, y)) == 'skin']
        if not xs: continue
        x0, x1 = min(xs), max(xs)
        if y <= hy + 1:
            for x in range(x0, x1 + 1): put2(x, y, SK_D)
        elif y <= hy + 3:
            for x in range(x0, x1 + 1): put2(x, y, SK_L)
            put2(x1, y, SK_D)
        else:
            for x in (x0 + 2, x0 + 4):
                if x0 < x < x1: put2(x, y, SK_D)
            if y >= hy + 8:
                for x in range(x0, x1 + 1): put2(x, y, SK_DD)


# ------------------------------------------------------------------ build
def build(kind):
    reset()
    girl = (kind == 'girl')
    CUR['face'] = sprof(FACE_G if girl else FACE_B)
    CUR['torso'] = sprof(TORSO_G if girl else TORSO_B)
    if girl:
        draw_girl()
    else:
        draw_boy()
    draw_head(girl)
    rim_shade()
    cast_shadow()
    face_details(girl)
    hair_details(girl)
    cloth_details(girl)
    outline()
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for (x, y), c in PX.items():
        img.putpixel((x, y), (c[0], c[1], c[2], 255))
    return img


# ------------------------------------------------------------------ checks
def check(img, name):
    ok = True
    lines = []
    if img.size != (W, H):
        lines.append('  SIZE  FAIL %s' % (img.size,)); ok = False
    else:
        lines.append('  size  ok 128x192')

    px = img.load()
    alphas = set()
    cols = {}
    opaque = []
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            alphas.add(a)
            if a:
                opaque.append((x, y))
                cols[(r, g, b)] = cols.get((r, g, b), 0) + 1
    if alphas - {0, 255}:
        lines.append('  ALPHA FAIL semi-transparent: %s' % sorted(alphas - {0, 255})); ok = False
    else:
        lines.append('  alpha ok (0/255 only)')

    ymax = max(y for _, y in opaque)
    if ymax != 190:
        lines.append('  FEET  FAIL lowest opaque y=%d (want 190)' % ymax); ok = False
    else:
        lines.append('  feet  ok y=190')

    bad = {c: n for c, n in cols.items() if c not in ALLOWED}
    lines.append('  colours off-table: %d  (used %d)' % (len(bad), len(cols)))
    if bad:
        for c, n in sorted(bad.items(), key=lambda kv: -kv[1])[:8]:
            lines.append('     %s x%d' % (c, n))
        ok = False

    # 4-connected components
    st = set(opaque)
    comp = 0; sizes = []
    while st:
        seed = st.pop()
        stack = [seed]; n = 1
        while stack:
            x, y = stack.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p in st:
                    st.discard(p); stack.append(p); n += 1
        comp += 1; sizes.append(n)
    sizes.sort(reverse=True)
    if comp != 1:
        lines.append('  BLOB  FAIL %d components %s' % (comp, sizes[:6])); ok = False
    else:
        lines.append('  blob  ok 1 component (%d px)' % sizes[0])

    xs = [x for x, _ in opaque]; ys = [y for _, y in opaque]
    lines.append('  bbox  x %d..%d (w=%d)  y %d..%d (h=%d)'
                 % (min(xs), max(xs), max(xs) - min(xs) + 1,
                    min(ys), max(ys), max(ys) - min(ys) + 1))
    print('%s: %s' % (name, 'OK' if ok else 'PROBLEMS'))
    for l in lines: print(l)
    return ok


# ------------------------------------------------------------------ preview
def on_grass(img):
    bg = Image.new('RGB', img.size, GRASS)
    bg.paste(img, (0, 0), img)
    return bg


def make_view(boy, girl):
    big = [on_grass(i).resize((W * 3, H * 3), Image.NEAREST) for i in (boy, girl)]
    sml = [on_grass(i).resize((36, 54), Image.LANCZOS) for i in (boy, girl)]
    tw = W * 3 * 2 + 140
    th = H * 3
    v = Image.new('RGB', (tw, th), GRASS)
    v.paste(big[0], (0, 0)); v.paste(big[1], (W * 3, 0))
    v.paste(sml[0], (W * 3 * 2 + 16, 240))
    v.paste(sml[1], (W * 3 * 2 + 72, 240))
    return v


def main():
    imgs = {}
    for k in ('boy', 'girl'):
        im = build(k)
        p = os.path.join(HERE, 'e128hd_%s.png' % k)
        im.save(p)
        imgs[k] = im
    good = True
    for k in ('boy', 'girl'):
        good &= check(imgs[k], 'e128hd_%s.png' % k)
    make_view(imgs['boy'], imgs['girl']).save(os.path.join(HERE, 'e128hd_view.png'))
    print('wrote e128hd_boy.png e128hd_girl.png e128hd_view.png -> %s'
          % ('ALL CHECKS PASS' if good else 'CHECKS FAILED'))


if __name__ == '__main__':
    main()
