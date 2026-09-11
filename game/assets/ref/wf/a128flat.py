#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""a128flat - 128x192 native chibi farmer sprites.
Flat colours + heavy 2px black outline, in the style of the reference chibi.
Pillow only, no numpy.  Run:  python3 a128flat.py
"""
import os, math
from PIL import Image

W, H = 128, 192
CX = 64.0
HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- palette
OUT     = (26, 20, 28)

SKIN    = (243,159,138); SKIN_L = (250,192,170); SKIN_D  = (213,116, 98)
SKIN_CH = (235,128,114); SKIN_M = (170, 84, 66); SKIN_DD = (184, 99, 83)
SKIN_LL = (252,217,204)

HAIR    = (118, 72, 40); HAIR_L = (152,100, 56); HAIR_D  = ( 86, 52, 30)
HAIR_DD = ( 58, 35, 20); HAIR_LL= (195,165,140)

TOP     = ( 58, 88,168); TOP_D  = ( 38, 58,120); TOP_L   = ( 94,126,200)
TOP_DD  = ( 27, 41, 84); TOP_LL = (166,184,225)

BOT     = (134, 88, 46); BOT_D  = ( 98, 62, 32); BOT_L   = (158,108, 58)
BOT_DD  = ( 69, 43, 22); BOT_LL = (202,174,147)

SHOE    = ( 82, 53, 33); SHOE_D = ( 56, 37, 25); SHOE_DD = ( 39, 26, 18)

EYE = (66,32,30); BROW = (136,70,42); WHITE = (246,242,234)

ALLOWED = set([SKIN,SKIN_L,SKIN_D,SKIN_CH,SKIN_M,SKIN_DD,SKIN_LL,
               HAIR,HAIR_L,HAIR_D,HAIR_DD,HAIR_LL,
               TOP,TOP_D,TOP_L,TOP_DD,TOP_LL,
               BOT,BOT_D,BOT_L,BOT_DD,BOT_LL,
               SHOE,SHOE_D,SHOE_DD, OUT, EYE, BROW, WHITE])

SKIN_SET = set([SKIN,SKIN_L,SKIN_D,SKIN_CH,SKIN_M,SKIN_DD,SKIN_LL])
HAIR_SET = set([HAIR,HAIR_L,HAIR_D,HAIR_DD,HAIR_LL])

GRASS = (122,150,96)

# ---------------------------------------------------------------- helpers
def R(v):
    """round half up - python round() is banker's and leaves 1px gaps"""
    return int(math.floor(v+0.5))


def sstep(t):
    if t <= 0: return 0.0
    if t >= 1: return 1.0
    return t*t*(3.0-2.0*t)

def prof(keys, y):
    """smooth (C1) interpolation of a half-width profile"""
    if y <= keys[0][0]:  return keys[0][1]
    if y >= keys[-1][0]: return keys[-1][1]
    for i in range(len(keys)-1):
        y0,v0 = keys[i]; y1,v1 = keys[i+1]
        if y0 <= y <= y1:
            return v0 + (v1-v0)*sstep((y-y0)/float(y1-y0))
    return keys[-1][1]

def plin(pts, x):
    """piecewise linear (sharp) - for jagged hair lines"""
    if x <= pts[0][0]:  return pts[0][1]
    if x >= pts[-1][0]: return pts[-1][1]
    for i in range(len(pts)-1):
        x0,v0 = pts[i]; x1,v1 = pts[i+1]
        if x0 <= x <= x1:
            return v0 + (v1-v0)*((x-x0)/float(x1-x0))
    return pts[-1][1]


class C(object):
    def __init__(self):
        self.c = [[None]*W for _ in range(H)]
        self.g = [[None]*W for _ in range(H)]

    def put(self, x, y, col, grp=None):
        if 0 <= x < W and 0 <= y < H:
            self.c[y][x] = col
            if grp is not None: self.g[y][x] = grp

    def row(self, y, x0, x1, col, grp=None):
        if x1 < x0: return
        for x in range(x0, x1+1): self.put(x, y, col, grp)

    def col_at(self, x, y):
        if 0 <= x < W and 0 <= y < H: return self.c[y][x]
        return None

    def grp_at(self, x, y):
        if 0 <= x < W and 0 <= y < H: return self.g[y][x]
        return None

    def on_skin(self, x, y, col):
        if self.col_at(x, y) in SKIN_SET: self.put(x, y, col)

    def on_hair(self, x, y, col):
        if self.col_at(x, y) in HAIR_SET: self.put(x, y, col)

    def on_grp(self, x, y, g, col):
        if self.grp_at(x, y) == g: self.put(x, y, col)


def span(off, hw):
    """inclusive pixel span of a band centred at CX+off with half width hw"""
    return int(round(CX+off-hw)), int(round(CX+off+hw))-1


def shade_row(cv, y, x0, x1, base, lit, shd, lw, sw, grp):
    """flat 3-tone banding: lit edge on the left, shadow band on the right"""
    for x in range(x0, x1+1):
        col = base
        if lit is not None and x < x0+lw:   col = lit
        elif shd is not None and x > x1-sw: col = shd
        cv.put(x, y, col, grp)


# ---------------------------------------------------------------- geometry
FACE = [(30,18.8),(40,21.4),(50,23.0),(60,23.5),(70,23.0),(78,20.9),
        (84,17.2),(88,13.2),(92,7.8)]
FACE_TOP, CHIN = 30, 92

FACE_G = [(30,18.2),(40,20.8),(50,22.4),(60,22.9),(70,22.4),(78,20.1),
          (84,16.4),(88,12.6),(92,7.4)]

def face_hw(y, girl=False): return prof(FACE_G if girl else FACE, y)

CROWN_CY, CROWN_RX, CROWN_RY = 36.0, 27.0, 28.0
def crown_hw(y):
    t = (y-CROWN_CY)/CROWN_RY
    if t*t >= 1.0: return 0.0
    return CROWN_RX*math.sqrt(1.0-t*t)

BOY_SIDE = [(36,27.4),(48,27.0),(56,26.4),(61,25.2),(65,21.6),(68,16.0)]
GIRL_SIDE= [(36,27.6),(50,27.4),(58,27.0),(64,26.4),(70,26.0)]

def hair_out_hw(y, girl):
    if y < 36: return crown_hw(y)
    k = GIRL_SIDE if girl else BOY_SIDE
    if y > k[-1][0]: return 0.0          # hair stops, does NOT clamp
    return prof(k, y)

BOY_BANG = [(30,40),(35,43),(39,52),(44,40),(51,58),(57,44),(62,50),
            (68,37),(74,55),(79,41),(84,49),(88,44),(92,57),(96,44)]
GIRL_BANG= [(30,46),(37,50),(42,53),(47,46),(53,52),(58,45),(62,40),
            (66,44),(70,52),(76,47),(81,54),(86,50),(91,45),(96,43)]

def bang_y(x, girl):
    return plin(GIRL_BANG if girl else BOY_BANG, x)

NECK = [(86,8.6),(94,8.8),(100,10.0),(103,11.5)]

BOY_TORSO = [(98,12.0),(103,16.6),(108,20.2),(118,20.6),(130,19.8),(140,19.2)]
GIRL_TORSO= [(98,11.4),(103,15.4),(108,18.6),(118,18.8),(130,17.4),(139,16.8)]

BOY_ARM_OFF = [(100,20.2),(112,20.8),(130,21.4),(156,22.0)]
BOY_ARM_HW  = [(100,7.1),(106,7.2),(124,6.3),(142,5.6),(146,7.2),(152,7.0),(156,4.2)]
GIRL_ARM_OFF= [(100,18.8),(112,19.4),(130,20.0),(154,20.6)]
GIRL_ARM_HW = [(100,6.9),(106,7.0),(120,6.0),(138,5.2),(142,6.7),(148,6.5),(152,4.0)]

BOY_PANTS = [(138,19.4),(146,18.6),(158,17.8),(170,17.2),(176,16.8)]
BOY_SHOE  = [(174,8.2),(178,9.8),(184,10.6),(188,10.6)]

GIRL_SKIRT= [(136,16.4),(142,18.2),(150,21.8),(157,24.4),(161,25.0),(163,25.0)]
GIRL_LEG  = [(156,6.0),(166,5.4),(174,5.0),(180,5.2)]
GIRL_SHOE = [(178,7.4),(182,8.8),(186,9.4),(188,9.4)]


# ---------------------------------------------------------------- parts
def draw_back_hair(cv):
    """girl: long hair curtain behind the body"""
    keys = [(24,15.0),(30,21.6),(42,25.0),(66,25.8),(92,27.2),(112,28.6),
            (122,28.4),(126,27.0),(128,23.0),(130,15.0),(131,6.0)]
    for y in range(24, 132):
        hw = prof(keys, y)
        if hw < 1: continue
        x0, x1 = span(0.0, hw)
        for x in range(x0, x1+1):
            d = abs(x-63.5)
            col = HAIR
            if d > hw-3.0: col = HAIR_D            # rim of the curtain
            if x < 63.5 and d < hw-3.0 and d > hw-7.0: col = HAIR_L
            cv.put(x, y, col, 'HAIR')
        # inner darkness right behind the neck / shoulders
        if 58 <= y <= 118:
            i0, i1 = span(0.0, min(hw, 19.0))
            cv.row(y, i0, i1, HAIR_DD, 'HAIR')


def draw_neck(cv):
    for y in range(86, 104):
        hw = prof(NECK, y)
        x0, x1 = span(0.0, hw)
        shade_row(cv, y, x0, x1, SKIN, None, SKIN_D, 0, 5, 'SKIN')
    # shadow cast by the jaw, fading downwards
    for y in range(88, 98):
        hw = prof(NECK, y)
        x0, x1 = span(0.0, hw)
        if y < 94:
            cv.row(y, x0, x1, SKIN_DD, 'SKIN')
        else:
            shade_row(cv, y, x0, x1, SKIN_D, None, SKIN_DD, 0, 5, 'SKIN')


def draw_torso(cv, girl):
    keys = GIRL_TORSO if girl else BOY_TORSO
    y0, y1 = 98, (139 if girl else 140)
    for y in range(y0, y1+1):
        hw = prof(keys, y)
        x0, x1 = span(0.0, hw)
        lw = 4 if y > 106 else 3
        shade_row(cv, y, x0, x1, TOP, TOP_L, TOP_D, lw, 7, 'TOP')
        if y > y1-3:                       # hem shadow
            shade_row(cv, y, x0, x1, TOP_D, None, TOP_DD, 0, 6, 'TOP')


def draw_arms(cv, girl):
    offk = GIRL_ARM_OFF if girl else BOY_ARM_OFF
    hwk  = GIRL_ARM_HW  if girl else BOY_ARM_HW
    sleeve_end = 118 if girl else 124
    top, bot = 100, (152 if girl else 156)
    for y in range(top, bot+1):
        off = prof(offk, y); hw = prof(hwk, y)
        if hw < 1: continue
        sleeve = (y <= sleeve_end)
        if sleeve:
            base, lit, shd, grp = TOP, TOP_L, TOP_D, 'TOP'
        else:
            base, lit, shd, grp = SKIN, SKIN_L, SKIN_D, 'SKIN'
        # left arm
        x0, x1 = span(-off, hw)
        shade_row(cv, y, x0, x1, base, lit, shd, 2, 3, grp)
        # right arm (mirror)
        x0, x1 = span(off, hw)
        shade_row(cv, y, x0, x1, base, lit, shd, 2, 3, grp)
    # puff-sleeve gather line for the girl
    if girl:
        for y in (116, 117):
            off = prof(offk, y); hw = prof(hwk, y)
            for s in (-1, 1):
                x0, x1 = span(s*off, hw)
                cv.row(y, x0, x1, TOP_DD, 'TOP')


def arm_inner_edge(y, girl):
    offk = GIRL_ARM_OFF if girl else BOY_ARM_OFF
    hwk  = GIRL_ARM_HW  if girl else BOY_ARM_HW
    off = prof(offk, y); hw = prof(hwk, y)
    return span(-off, hw)[1]          # last pixel of the left arm


def draw_pants(cv):
    for y in range(138, 177):
        hw = prof(BOY_PANTS, y)
        x0, x1 = span(0.0, hw)
        if y < 150:
            shade_row(cv, y, x0, x1, BOT, BOT_L, BOT_D, 3, 5, 'BOT')
        else:
            shade_row(cv, y, x0, 61, BOT, BOT_L, BOT_D, 3, 3, 'BOT')
            shade_row(cv, y, 66, x1, BOT, BOT_L, BOT_D, 2, 4, 'BOT')
            cv.put(61, y, BOT_D, 'BOT')
    # belt
    for y in range(138, 142):
        hw = prof(BOT_BELT_K, y)
        x0, x1 = span(0.0, hw)
        cv.row(y, x0, x1, BOT_DD, 'BOT')
    cv.row(140, 61, 66, BOT_LL, 'BOT'); cv.row(139, 61, 66, BOT_LL, 'BOT')

BOT_BELT_K = [(138,19.4),(142,19.0)]


def draw_shoes(cv, girl):
    keys = GIRL_SHOE if girl else BOY_SHOE
    off  = 9.6 if girl else 10.2
    y0   = 178 if girl else 174
    sole = 186 if girl else 185
    for y in range(y0, 189):
        hw = prof(keys, y)
        for s in (-1, 1):
            x0, x1 = span(s*off, hw)
            if y >= sole:
                cv.row(y, x0, x1, SHOE_DD, 'SHOE')
            elif y >= sole-2:
                cv.row(y, x0, x1, SHOE_D, 'SHOE')
            else:
                shade_row(cv, y, x0, x1, SHOE, None, SHOE_D, 0, 3, 'SHOE')
    # strap / ankle line
    for y in (y0+1, y0+2):
        for s in (-1, 1):
            hw = prof(keys, y)
            x0, x1 = span(s*off, hw)
            cv.row(y, x0, x1, SHOE_D, 'SHOE')


def draw_skirt(cv):
    for y in range(136, 164):
        hw = prof(GIRL_SKIRT, y)
        x0, x1 = span(0.0, hw)
        shade_row(cv, y, x0, x1, BOT, BOT_L, BOT_D, 4, 7, 'BOT')
        if y == 160:
            cv.row(y, x0+3, x1-3, BOT_LL, 'BOT')
        if y >= 161:
            cv.row(y, x0, x1, BOT_DD, 'BOT')
    # pleats
    for k, ox in enumerate((-16.0, -6.0, 6.0, 16.0)):
        for y in range(142, 161):
            t = (y-142)/18.0
            hw = prof(GIRL_SKIRT, y)
            x = R(CX + ox*(0.55+0.75*t))
            if abs(x-63.5) < hw-2:
                cv.on_grp(x, y, 'BOT', BOT_D)


def draw_legs_girl(cv):
    for y in range(154, 182):
        hw = prof(GIRL_LEG, y)
        for s in (-1, 1):
            x0, x1 = span(s*9.6, hw)
            shade_row(cv, y, x0, x1, SKIN, SKIN_L, SKIN_D, 2, 3, 'SKIN')
    for s in (-1, 1):                       # knee + calf hints
        for i, y in enumerate((166, 167, 168)):
            x0, x1 = span(s*9.6, prof(GIRL_LEG, y))
            cv.row(y, x0+2+i//2, x0+3+i//2, SKIN_L, 'SKIN')
        for y in range(170, 176):
            x0, x1 = span(s*9.6, prof(GIRL_LEG, y))
            cv.put(x1-2, y, SKIN_D, 'SKIN')


def draw_face(cv, girl):
    for y in range(FACE_TOP, CHIN+1):
        hw = face_hw(y, girl)
        x0, x1 = span(0.0, hw)
        shade_row(cv, y, x0, x1, SKIN, SKIN_L, SKIN_D, 3, 5, 'SKIN')
    # ears
    for i, y in enumerate(range(60, 74)):
        t = (y-60)/13.0
        ehw = 3.6*math.sin(math.pi*min(1.0, max(0.0, t)))+1.2
        hw = face_hw(y, girl)
        for s in (-1, 1):
            base = R(CX + s*hw)
            for k in range(int(round(ehw))+1):
                x = base + s*k - (1 if s > 0 else 0)
                cv.put(x, y, SKIN if k < 2 else SKIN_D, 'SKIN')


def draw_hair(cv, girl):
    hi = 0
    for y in range(8, 96):
        ohw = hair_out_hw(y, girl)
        if ohw < 0.6: continue
        x0, x1 = span(0.0, ohw)
        fhw = face_hw(y, girl) if FACE_TOP <= y <= CHIN else -1
        for x in range(x0, x1+1):
            d = abs(x-63.5)
            inside_face = (fhw > 0 and d <= fhw)
            if inside_face and y >= bang_y(x, girl):
                continue                              # forehead shows
            col = HAIR
            if d > ohw-3.0: col = HAIR_D              # rounded rim
            if inside_face:                           # bangs over skin
                col = HAIR if y < bang_y(x, girl)-4 else HAIR_D
            cv.put(x, y, col, 'HAIR')
    # spiky tufts grown off the skull so the silhouette is not a mushroom
    if not girl:
        spike(cv, -1.24, 0.30,  3.6, -0.06)
        spike(cv, -0.82, 0.26,  4.6, -0.20)
        spike(cv, -0.30, 0.22,  3.6, -0.10)
        spike(cv,  0.26, 0.24,  4.4,  0.12)
        spike(cv,  0.78, 0.26,  5.6,  0.18)
        spike(cv,  1.16, 0.26,  6.0,  0.10)
    else:
        spike(cv, -1.15, 0.30,  4.0,  0.22)
        spike(cv,  0.95, 0.26,  3.0,  0.18)


def ell(a, gx=0.0, gy=0.0):
    return (63.5 + (CROWN_RX+gx)*math.sin(a), CROWN_CY - (CROWN_RY+gy)*math.cos(a))


def spike(cv, a, half, ln, bend):
    """triangular hair tuft grown off the skull ellipse (always connected)"""
    p0 = ell(a-half, -1.0, -1.0)
    p1 = ell(a+half, -1.0, -1.0)
    ap = ell(a+bend, ln, ln)
    mid = ell(a+bend*0.4, ln*0.45, ln*0.45)
    tuft(cv, [(int(round(p0[0])), int(round(p0[1]))),
              (int(round(mid[0]+ (p0[0]-p1[0])*0.16)), int(round(mid[1]+(p0[1]-p1[1])*0.16))),
              (int(round(ap[0])), int(round(ap[1]))),
              (int(round(p1[0])), int(round(p1[1])))])


def tuft(cv, pts):
    """filled convex-ish polygon of hair (keeps the silhouette lively)"""
    ys = [p[1] for p in pts]
    for y in range(min(ys), max(ys)+1):
        xs = []
        n = len(pts)
        for i in range(n):
            x0,y0 = pts[i]; x1,y1 = pts[(i+1) % n]
            if y0 == y1: continue
            if min(y0,y1) <= y <= max(y0,y1):
                t = (y-y0)/float(y1-y0)
                xs.append(x0+(x1-x0)*t)
        if len(xs) < 2: continue
        xs.sort()
        cv.row(y, int(round(xs[0])), int(round(xs[-1])), HAIR, 'HAIR')


def draw_side_locks(cv):
    """girl: two long locks framing the face"""
    keys = [(34,4.0),(44,5.6),(70,6.2),(95,6.2),(112,5.4),(120,4.2),(126,2.4),(128,1.2)]
    offk = [(34,23.0),(60,25.0),(90,26.0),(120,27.0),(124,27.0)]
    for y in range(34, 129):
        hw = prof(keys, y); off = prof(offk, y)
        if hw < 0.8: continue
        for s in (-1, 1):
            if s > 0 and y > 120: continue          # right lock ends sooner
            x0, x1 = span(s*off, hw)
            for x in range(x0, x1+1):
                col = HAIR
                if s < 0 and x < x0+2: col = HAIR_L
                if x > x1-2: col = HAIR_D
                cv.put(x, y, col, 'HAIR')


def draw_ribbon(cv):
    """girl: ribbon tied on the left side, attached to the hair mass"""
    kx, ky = 44, 22
    tuft_col(cv, [(kx-2,ky-3),(kx+2,ky-3),(kx+2,ky+3),(kx-2,ky+3)], TOP_L)
    tuft_col(cv, [(kx-2,ky-2),(kx-11,ky-7),(kx-12,ky+4),(kx-2,ky+3)], TOP)
    tuft_col(cv, [(kx+2,ky-2),(kx+11,ky-6),(kx+12,ky+5),(kx+2,ky+3)], TOP)
    for k in range(5):
        cv.put(kx-10+k, ky-4+k, TOP_D)
        cv.put(kx+10-k, ky-3+k, TOP_D)
    cv.put(kx-1, ky-3, TOP_LL); cv.put(kx, ky-3, TOP_LL)


def tuft_col(cv, pts, col, grp='RIB'):
    ys = [p[1] for p in pts]
    for y in range(min(ys), max(ys)+1):
        xs = []
        n = len(pts)
        for i in range(n):
            x0,y0 = pts[i]; x1,y1 = pts[(i+1) % n]
            if y0 == y1: continue
            if min(y0,y1) <= y <= max(y0,y1):
                t = (y-y0)/float(y1-y0)
                xs.append(x0+(x1-x0)*t)
        if len(xs) < 2: continue
        xs.sort()
        cv.row(y, int(round(xs[0])), int(round(xs[-1])), col, grp)


# ---------------------------------------------------------------- ink
def ink_groups(cv):
    marks = []
    for y in range(H):
        for x in range(W):
            g = cv.g[y][x]
            if g is None or g == 'INK': continue
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                g2 = cv.grp_at(x+dx, y+dy)
                if g2 is not None and g2 != g and g2 != 'INK':
                    marks.append((x, y)); break
    for x, y in marks: cv.put(x, y, OUT, 'INK')


def ink_arm_seam(cv, girl):
    top = 106
    bot = 152 if girl else 156
    for y in range(top, bot+1):
        xe = arm_inner_edge(y, girl)
        w = 3 if y > top+3 else 2
        for k in range(w):
            cv.put(xe-k, y, OUT, 'INK')
            cv.put(127-(xe-k), y, OUT, 'INK')


def ink_inseam(cv, girl):
    if girl:
        for y in range(160, 189):
            w = 2 if y < 164 else 3
            cv.row(y, 64-w, 63+w, OUT, 'INK')
    else:
        for y in range(147, 189):
            w = [1, 1, 2, 2, 3][min(4, y-147)]
            cv.row(y, 64-w, 63+w, OUT, 'INK')


def outline(cv, r=2):
    offs = [(dx,dy) for dx in range(-r,r+1) for dy in range(-r,r+1)
            if 0 < dx*dx+dy*dy <= r*r+1]
    mask = [[cv.c[y][x] is not None for x in range(W)] for y in range(H)]
    add = []
    for y in range(H):
        for x in range(W):
            if mask[y][x]: continue
            for dx, dy in offs:
                nx, ny = x+dx, y+dy
                if 0 <= nx < W and 0 <= ny < H and mask[ny][nx]:
                    add.append((x, y)); break
    for x, y in add: cv.put(x, y, OUT, 'INK')


# ---------------------------------------------------------------- details
def face_details(cv, girl):
    # shadow under the bangs (follows the jagged hair line)
    for x in range(30, 98):
        by = R(bang_y(x, girl))
        for y in range(by, by+2):
            cv.on_skin(x, y, SKIN_D)

    # jaw shadow so the chin is not a blank slab
    for y in range(83, CHIN+1):
        hw = face_hw(y, girl)
        x0, x1 = span(0.0, hw)
        for x in range(x0, x1+1):
            d = abs(x-63.5)
            if d > hw-3.4 or y >= CHIN-1:
                cv.on_skin(x, y, SKIN_D)
    for y in range(CHIN-1, CHIN+1):
        hw = face_hw(y, girl); x0, x1 = span(0.0, hw)
        for x in range(x0, x1+1):
            if abs(x-63.5) > hw-2.0: cv.on_skin(x, y, SKIN_D)

    ey = 71 if not girl else 72
    ew, eh = (5.4, 6.6) if not girl else (5.6, 7.0)
    for sgn in (-1, 1):
        ecx = 63.5 + sgn*11.0
        cells = []
        for y in range(ey-9, ey+9):
            for x in range(R(ecx-ew)-1, R(ecx+ew)+2):
                dx = (x-ecx)/ew; dy = (y-ey)/eh
                if dx*dx+dy*dy <= 1.0 and cv.col_at(x, y) in SKIN_SET:
                    cells.append((x, y, dx, dy))
        for (x, y, dx, dy) in cells:
            cv.put(x, y, OUT)
        for (x, y, dx, dy) in cells:                 # warm core, lower half
            if dx*dx+dy*dy <= 0.46 and dy > -0.30:
                cv.put(x, y, EYE)
        gx, gy = R(ecx-2.6), ey-4                    # main glint
        for x in range(gx, gx+3):
            for y in range(gy, gy+2):
                if cv.col_at(x, y) in (OUT, EYE): cv.put(x, y, WHITE)
        for x in range(R(ecx+1.4), R(ecx+3.4)):      # small lower glint
            if cv.col_at(x, ey+3) in (OUT, EYE): cv.put(x, ey+3, WHITE)
        # lashes: only pixels that touch the eye mass, no floating specks
        lash = [(sgn*1, -1), (sgn*2, -1), (sgn*2, 0)]
        if girl: lash += [(sgn*3, -1), (sgn*3, 0)]
        for (dxp, dyp) in lash:
            x = R(ecx + sgn*(ew-1.0)) + dxp
            y = ey - R(eh) + 2 + dyp
            if cv.col_at(x, y) in SKIN_SET:
                near = any(cv.col_at(x+a, y+b) in (OUT, EYE, WHITE)
                           for a, b in ((1,0),(-1,0),(0,1),(0,-1)))
                if near: cv.put(x, y, OUT)

    # brows: solid slanted bars
    for sgn in (-1, 1):
        bcx = 63.5 + sgn*11.0
        th = 2
        for i in range(-4, 5):
            x = R(bcx+i)
            y0 = (57 - R(i*sgn*0.34)) if not girl else (56 + R(i*sgn*0.30))
            for y in range(y0, y0+th):
                cv.on_skin(x, y, BROW)

    # cheeks: flat blocks
    cy0 = 80 if not girl else 81
    for sgn in (-1, 1):
        for i in range(0, 8):
            x = R(63.5 + sgn*(8.5+i)) if sgn > 0 else R(63.5 - (8.5+i))
            for y in range(cy0, cy0+3):
                if abs(x-63.5) < face_hw(y, girl)-1.5:
                    cv.on_skin(x, y, SKIN_CH)

    # nose hint (two pixels, no more)
    ny = 82 if not girl else 83
    cv.on_skin(63, ny, SKIN_D); cv.on_skin(64, ny, SKIN_D)

    # mouth
    my = 87 if not girl else 88
    if girl:
        cv.on_skin(62, my, SKIN_M); cv.on_skin(63, my+1, SKIN_M)
        cv.on_skin(64, my+1, SKIN_M); cv.on_skin(65, my, SKIN_M)
    else:
        cv.on_skin(61, my-1, SKIN_M); cv.on_skin(62, my, SKIN_M)
        cv.on_skin(63, my+1, SKIN_M); cv.on_skin(64, my+1, SKIN_M)
        cv.on_skin(65, my, SKIN_M);   cv.on_skin(66, my-1, SKIN_M)


def ehh_i(v): return int(round(v))


BOY_STRANDS = [(45,38,41,51,1),(57,36,52,54,1),(70,34,74,50,1),
               (84,38,87,52,1),(37,46,35,58,1),(90,44,92,55,1)]
GIRL_STRANDS= [(58,36,49,50,1),(68,36,79,50,1),(63,30,63,38,1),
               (40,66,38,104,1),(90,72,92,110,1)]


def hline(cv, x0, y0, x1, y1, col, w=1):
    n = max(abs(x1-x0), abs(y1-y0))
    for i in range(n+1):
        t = i/float(n) if n else 0
        x = R(x0+(x1-x0)*t); y = R(y0+(y1-y0)*t)
        for k in range(w):
            cv.on_hair(x+k, y, col)


def hair_details(cv, girl):
    # curved highlight arc following the skull, broken into segments
    segs = [(-1.24,-0.52),(-0.34,0.16)] if not girl else [(-1.28,-0.62),(-0.44,0.20)]
    for a0, a1 in segs:
        steps = int(abs(a1-a0)*46)
        for i in range(steps+1):
            a = a0 + (a1-a0)*i/float(steps)
            for rr in (CROWN_RX-4.4, CROWN_RX-6.0, CROWN_RX-7.6, CROWN_RX-9.2):
                x = R(63.5 + rr*math.sin(a))
                y = R(CROWN_CY - (CROWN_RY-3.0)*math.cos(a))
                cv.on_hair(x, y, HAIR_L)
    # strand splits: strokes that follow how the fringe falls
    strokes = BOY_STRANDS if not girl else GIRL_STRANDS
    for (x0, y0, x1, y1, w) in strokes:
        hline(cv, x0, y0, x1, y1, HAIR_D, w)
    # dark under-edge of every bang tip
    for x in range(30, 98):
        by = R(bang_y(x, girl))
        for y in range(by-2, by):
            cv.on_hair(x, y, HAIR_D)


def cloth_details(cv, girl):
    # collar
    for y in range(98, 110):
        for x in range(46, 82):
            d = math.hypot((x-63.5), (y-96)*1.15)
            if 11.5 <= d <= 13.8:
                cv.on_grp(x, y, 'TOP', TOP_DD)
    if not girl:
        # button placket
        for y in range(106, 138):
            cv.on_grp(63, y, 'TOP', TOP_DD)
        for by in (112, 122, 132):
            for x in range(65, 67):
                for y in range(by, by+2):
                    cv.on_grp(x, y, 'TOP', TOP_LL)
        # shoulder seams
        for sgn in (-1, 1):
            for k in range(8):
                x = R(63.5 + sgn*(11.5+k*0.85))
                y = 102 + k
                cv.on_grp(x, y, 'TOP', TOP_DD)
        # chest pocket
        for x in range(45, 55):
            cv.on_grp(x, 115, 'TOP', TOP_DD); cv.on_grp(x, 124, 'TOP', TOP_DD)
        for y in range(115, 125):
            cv.on_grp(45, y, 'TOP', TOP_DD); cv.on_grp(54, y, 'TOP', TOP_DD)
        for x in range(46, 54):
            cv.on_grp(x, 116, 'TOP', TOP_L)
        # waist folds
        for x0, y0 in ((49,128), (75,131)):
            for k in range(5):
                cv.on_grp(x0+k, y0+k//2, 'TOP', TOP_DD)
        for x0, y0 in ((52,135), (72,136)):
            for k in range(4):
                cv.on_grp(x0+k, y0-k//2, 'TOP', TOP_D)
        # pocket lines
        for s in (-1, 1):
            for k in range(7):
                x = R(63.5+s*(9+k)); y = 148+abs(k-3)//3
                cv.on_grp(x, y, 'BOT', BOT_D)
        # knee folds + cuffs
        for s in (-1, 1):
            for k in range(5):
                cv.on_grp(R(63.5+s*(6+k)), 162+k//3, 'BOT', BOT_D)
        for y in (170, 171):
            for x in range(44, 84):
                cv.on_grp(x, y, 'BOT', BOT_DD)
        for sgn in (-1, 1):
            for y in range(153, 169):
                cv.on_grp(R(63.5 + sgn*(10.5+(y-153)*0.05)), y, 'BOT', BOT_L)
    else:
        for by in (110, 120):
            for x in range(62, 65):
                for y in range(by, by+2):
                    cv.on_grp(x, y, 'TOP', TOP_LL)
        for sgn in (-1, 1):
            for k in range(7):
                x = R(63.5 + sgn*(11.0+k*0.85))
                cv.on_grp(x, 102+k, 'TOP', TOP_DD)
        for k in range(5):
            cv.on_grp(51+k, 127+k//2, 'TOP', TOP_DD)
            cv.on_grp(75+k, 129-k//2, 'TOP', TOP_DD)


def wrist_line(cv, girl):
    offk = GIRL_ARM_OFF if girl else BOY_ARM_OFF
    hwk  = GIRL_ARM_HW  if girl else BOY_ARM_HW
    wy = 141 if girl else 145
    off = prof(offk, wy); hw = prof(hwk, wy)
    for sgn in (-1, 1):
        x0, x1 = span(sgn*off, hw)
        for x in range(x0+1, x1):
            cv.on_skin(x, wy, SKIN_D)


def hand_details(cv, girl):
    offk = GIRL_ARM_OFF if girl else BOY_ARM_OFF
    y0 = 146 if girl else 150
    y1 = 151 if girl else 155
    for sgn in (-1, 1):
        off = prof(offk, y0)
        cx = 63.5 + sgn*off
        for y in range(y1-1, y1+2):                  # shaded finger tips
            for x in range(R(cx-6), R(cx+7)):
                cv.on_skin(x, y, SKIN_D)
        for k in (-2, 2):                            # two finger creases
            x = R(cx+k)
            for y in range(y0+1, y1+2):
                cv.on_skin(x, y, SKIN_D)
        tx = R(cx + sgn*4)                           # thumb, outer side
        for y in range(y0-2, y0+2):
            cv.on_skin(tx, y, SKIN_D)
            cv.on_skin(tx+sgn, y, SKIN_L)


# ---------------------------------------------------------------- assemble
def build(kind):
    girl = (kind == 'girl')
    cv = C()
    if girl:
        draw_back_hair(cv)
    draw_neck(cv)
    draw_torso(cv, girl)
    if girl:
        draw_skirt(cv); draw_legs_girl(cv)
    else:
        draw_pants(cv)
    draw_shoes(cv, girl)
    draw_arms(cv, girl)
    draw_face(cv, girl)
    draw_hair(cv, girl)
    if girl:
        draw_side_locks(cv); draw_ribbon(cv)

    ink_groups(cv)
    ink_arm_seam(cv, girl)
    ink_inseam(cv, girl)
    outline(cv, 2)

    face_details(cv, girl)
    wrist_line(cv, girl)
    hair_details(cv, girl)
    cloth_details(cv, girl)
    hand_details(cv, girl)
    return cv


def to_image(cv):
    im = Image.new('RGBA', (W, H), (0,0,0,0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            c = cv.c[y][x]
            if c is not None:
                px[x, y] = (c[0], c[1], c[2], 255)
    return im


# ---------------------------------------------------------------- checks
def check(im, name):
    px = im.load()
    ok = True
    msg = []
    if im.size != (W, H):
        ok = False; msg.append('size %s != (128,192)' % (im.size,))
    else:
        msg.append('size 128x192 OK')

    ys = [y for y in range(H) for x in range(W) if px[x, y][3] > 0]
    xs = [x for y in range(H) for x in range(W) if px[x, y][3] > 0]
    bot = max(ys) if ys else -1
    msg.append('bottom y=%d %s' % (bot, 'OK' if bot == 190 else 'FAIL(need 190)'))
    if bot != 190: ok = False
    bx = [x for y in range(120, 191) for x in range(W) if px[x, y][3] > 0]
    cxm = (min(bx)+max(bx))/2.0 if bx else -1
    msg.append('bbox x %d..%d  body centre %.1f (want 63.5)  top y=%d' % (min(xs), max(xs), cxm, min(ys)))
    if abs(cxm-63.5) > 1.5: ok = False; msg.append('  centre off')

    alphas = set(px[x, y][3] for y in range(H) for x in range(W))
    msg.append('alphas %s %s' % (sorted(alphas), 'OK' if alphas <= set([0,255]) else 'FAIL'))
    if not alphas <= set([0,255]): ok = False

    bad = {}
    for y in range(H):
        for x in range(W):
            r,g,b,a = px[x, y]
            if a and (r,g,b) not in ALLOWED:
                bad[(r,g,b)] = bad.get((r,g,b), 0)+1
    msg.append('off-palette colours: %d %s' % (len(bad), sorted(bad.items(), key=lambda t:-t[1])[:5]))
    if bad: ok = False

    # 4-connectivity flood
    seen = [[False]*W for _ in range(H)]
    comps = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0 or seen[y][x]: continue
            n = 0; st = [(x, y)]; seen[y][x] = True
            while st:
                cx0, cy0 = st.pop(); n += 1
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = cx0+dx, cy0+dy
                    if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and px[nx, ny][3]:
                        seen[ny][nx] = True; st.append((nx, ny))
            comps.append(n)
    comps.sort(reverse=True)
    msg.append('components %d %s %s' % (len(comps), comps[:5], 'OK' if len(comps) == 1 else 'FAIL'))
    if len(comps) != 1: ok = False

    # transparent holes inside the body
    holes = 0
    seenb = [[False]*W for _ in range(H)]
    st = [(0,0)]
    if px[0,0][3] == 0:
        seenb[0][0] = True
        while st:
            cx0, cy0 = st.pop()
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                nx, ny = cx0+dx, cy0+dy
                if 0 <= nx < W and 0 <= ny < H and not seenb[ny][nx] and px[nx, ny][3] == 0:
                    seenb[ny][nx] = True; st.append((nx, ny))
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0 and not seenb[y][x]: holes += 1
    msg.append('interior holes %d %s' % (holes, 'OK' if holes == 0 else 'note'))

    # silhouette step check
    jumps = 0
    prev = None
    for y in range(H):
        r = [x for x in range(W) if px[x, y][3]]
        if not r: prev = None; continue
        cur = (min(r), max(r))
        if prev and abs(cur[0]-prev[0]) > 3 and y > 12 and y < 186: jumps += 1
        prev = cur
    msg.append('edge jumps>3px: %d' % jumps)

    print('--- %s' % name)
    for m in msg: print('   ' + m)
    return ok


# ---------------------------------------------------------------- preview
def make_view(boy, girl):
    pad, gap = 16, 18
    big = 3
    bw, bh = W*big, H*big
    sw, sh = 36, 54
    tw = pad + bw + gap + bw + gap*3 + sw + gap + sw + pad
    th = pad + bh + pad
    view = Image.new('RGB', (tw, th), GRASS)
    for i, im in enumerate((boy, girl)):
        b = im.resize((bw, bh), Image.NEAREST)
        view.paste(b, (pad + i*(bw+gap), pad), b)
    x0 = pad + bw*2 + gap + gap*3
    gy = pad + bh - sh
    for i, im in enumerate((boy, girl)):
        s_ = im.resize((sw, sh), Image.NEAREST)
        view.paste(s_, (x0 + i*(sw+gap), gy), s_)
    return view


def main():
    imgs = {}
    for kind in ('boy', 'girl'):
        cv = build(kind)
        im = to_image(cv)
        p = os.path.join(HERE, 'a128flat_%s.png' % kind)
        im.save(p)
        imgs[kind] = im
        check(im, kind)
    v = make_view(imgs['boy'], imgs['girl'])
    v.save(os.path.join(HERE, 'a128flat_view.png'))
    print('wrote a128flat_boy.png a128flat_girl.png a128flat_view.png')


if __name__ == '__main__':
    main()
