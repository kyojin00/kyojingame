#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""c128shade - 128 x 192 native chibi farmer sprites, CEL SHADED.

  * every material uses its full 4~5 step ramp
  * facets have hard edges (no gradients, no dithering)
  * one light, upper-left
  * heavy near-black outline, selective (lit edges get the material's
    darkest tone instead of black) so stair corners read soft

Pillow only, no numpy.   run:  python3 c128shade.py
"""
import os, math
from PIL import Image

W, H = 128, 192
CX = 64.0
HERE = os.path.dirname(os.path.abspath(__file__))

# ----------------------------------------------------------------- palette
OUT = (26, 20, 28)

SKIN   = (243,159,138); SKIN_L  = (250,192,170); SKIN_D  = (213,116, 98)
SKIN_CH= (235,128,114); SKIN_M  = (170, 84, 66); SKIN_DD = (184, 99, 83)
SKIN_LL= (252,217,204)

HAIR   = (118, 72, 40); HAIR_L  = (152,100, 56); HAIR_D  = ( 86, 52, 30)
HAIR_DD= ( 58, 35, 20); HAIR_LL = (195,165,140)

TOP    = ( 58, 88,168); TOP_D   = ( 38, 58,120); TOP_L   = ( 94,126,200)
TOP_DD = ( 27, 41, 84); TOP_LL  = (166,184,225)

BOT    = (134, 88, 46); BOT_D   = ( 98, 62, 32); BOT_L   = (158,108, 58)
BOT_DD = ( 69, 43, 22); BOT_LL  = (202,174,147)

SHOE   = ( 82, 53, 33); SHOE_D  = ( 56, 37, 25); SHOE_DD = ( 39, 26, 18)

EYE = (66,32,30); BROW = (136,70,42); WHITE = (246,242,234)
GRASS = (122,150,96)

RAMP = {
    'skin': [SKIN_DD, SKIN_D, SKIN, SKIN_L, SKIN_LL],
    'hair': [HAIR_DD, HAIR_D, HAIR, HAIR_L, HAIR_LL],
    'top' : [TOP_DD,  TOP_D,  TOP,  TOP_L,  TOP_LL],
    'bot' : [BOT_DD,  BOT_D,  BOT,  BOT_L,  BOT_LL],
    'shoe': [SHOE_DD, SHOE_D, SHOE, SHOE,   SHOE],
}
# thresholds between the 5 bands  (cel: hard steps)
THR = {
    'skin': [0.13, 0.29, 0.800, 0.900],
    'hair': [0.20, 0.44, 0.685, 0.885],
    'top' : [0.17, 0.41, 0.670, 0.925],
    'bot' : [0.17, 0.41, 0.670, 0.965],
    'shoe': [0.30, 0.62, 9.0, 9.0],
}
ALLOWED = set()
for k in RAMP:
    for c in RAMP[k]: ALLOWED.add(c)
for c in (SKIN, SKIN_L, SKIN_D, SKIN_CH, SKIN_M, SKIN_DD, SKIN_LL,
          HAIR, HAIR_L, HAIR_D, HAIR_DD, HAIR_LL,
          TOP, TOP_D, TOP_L, TOP_DD, TOP_LL,
          BOT, BOT_D, BOT_L, BOT_DD, BOT_LL,
          SHOE, SHOE_D, SHOE_DD, OUT, EYE, BROW, WHITE):
    ALLOWED.add(c)

# ----------------------------------------------------------------- helpers
def R(v):
    return int(math.floor(v + 0.5))

def sstep(t):
    if t <= 0.0: return 0.0
    if t >= 1.0: return 1.0
    return t * t * (3.0 - 2.0 * t)

def prof(keys, y):
    """smooth half-width profile - no 90 degree corners"""
    if y <= keys[0][0]:  return keys[0][1]
    if y >= keys[-1][0]: return keys[-1][1]
    for i in range(len(keys) - 1):
        y0, v0 = keys[i]; y1, v1 = keys[i + 1]
        if y0 <= y <= y1:
            return v0 + (v1 - v0) * sstep((y - y0) / float(y1 - y0))
    return keys[-1][1]

def plin(keys, x):
    """piecewise linear - for jagged hair edges"""
    if x <= keys[0][0]:  return keys[0][1]
    if x >= keys[-1][0]: return keys[-1][1]
    for i in range(len(keys) - 1):
        x0, v0 = keys[i]; x1, v1 = keys[i + 1]
        if x0 <= x <= x1:
            return v0 + (v1 - v0) * ((x - x0) / float(x1 - x0))
    return keys[-1][1]

def span(cx, hw):
    if hw <= 0.15: return (1, 0)
    return (int(math.ceil(cx - hw - 0.5)), int(math.floor(cx + hw - 0.5)))

# ---------------------------------------------------------------- lighting
LX, LY, LZ = -0.62, -0.55, 0.56        # light, upper-left, slightly front
FX, FY = 0.74, 0.67                    # flat 2d light direction

def cyl_lum(u):
    """u = -1 (left rim) .. +1 (right rim) across a vertical cylinder"""
    if u < -1.0: u = -1.0
    if u >  1.0: u =  1.0
    nz = math.sqrt(max(0.0, 1.0 - u * u))
    nd2 = -(FX * u) / FX                       # = -u
    d3 = LX * u + LZ * nz
    nd3 = (d3 - 0.11) / 0.73
    v = 0.5 + 0.5 * (0.62 * nd2 + 0.38 * nd3)
    return v

def sph_lum(nx, ny):
    r = math.hypot(nx, ny)
    if r > 1.0:
        nx /= r; ny /= r; r = 1.0
    nz = math.sqrt(max(0.0, 1.0 - r * r))
    nd2 = -(FX * nx + FY * ny)
    d3 = LX * nx + LY * ny + LZ * nz
    nd3 = (d3 - 0.156) / 0.844
    return 0.5 + 0.5 * (0.62 * nd2 + 0.38 * nd3)

# ------------------------------------------------------------------ buffer
class Buf(object):
    def __init__(self):
        self.mat = [[None] * W for _ in range(H)]
        self.lum = [[0.0] * W for _ in range(H)]
        self.col = [[None] * W for _ in range(H)]

    def put(self, x, y, mat, lum):
        if 0 <= x < W and 0 <= y < H:
            self.mat[y][x] = mat
            self.lum[y][x] = lum

    def clear(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            self.mat[y][x] = None
            self.col[y][x] = None

    def setc(self, x, y, c):
        if 0 <= x < W and 0 <= y < H and self.mat[y][x] is not None:
            self.col[y][x] = c

    def forcec(self, x, y, c, mat='out'):
        if 0 <= x < W and 0 <= y < H:
            self.col[y][x] = c
            if self.mat[y][x] is None: self.mat[y][x] = mat

    def cyl_row(self, y, cx, hw, mat, adj=0.0, mod=None):
        xa, xb = span(cx, hw)
        for x in range(xa, xb + 1):
            u = (x + 0.5 - cx) / hw
            l = cyl_lum(u) + adj
            if mod is not None: l += mod(x, y, u)
            self.put(x, y, mat, l)

    def erase_row(self, y, xa, xb):
        for x in range(xa, xb + 1):
            self.clear(x, y)

# =========================================================== body geometry
def geo(girl):
    g = {}
    if not girl:
        g['FACE'] = [(26,5),(31,13),(36,17.5),(42,20.6),(50,22.6),(58,23.2),
                     (66,22.8),(72,21.8),(78,19.8),(83,16.6),(87,11.6),
                     (89,6.5),(90,0)]
        g['HAIROUT'] = [(12,19),(16,22),(22,25),(30,27.4),(40,28.6),(52,29.0),
                        (60,28.6),(66,27.0),(70,24.5),(74,19.0),(76,10),(77,0)]
        # every segment has slope +-1 : clean 45 degree pixel diagonals
        g['TOPEDGE'] = [(28,44),(34,38),(40,32),(43,29),(47,15),(50,17),
                        (54,13),(59,18),(63,12),(66,15),(70,11),(74,15),
                        (78,13),(82,19),(86,16),(90,22),(94,28),(100,44)]
        g['FRINGE'] = [(28,40),(33,40),(40,47),(44,43),(51,50),(56,45),
                       (60,49),(65,44),(72,51),(76,47),(81,42),(85,46),
                       (89,42),(93,46),(98,40)]
        g['TOR'] = [(94,10),(98,13.0),(102,14.8),(110,15.6),(120,16.2),
                    (130,16.8),(136,17.0)]
        g['ARMCX'] = [(100,21.6),(108,23.0),(118,23.6),(130,24.0),(144,24.2),
                      (161,24.2)]
        g['ARMHW'] = [(100,5.2),(110,5.4),(120,5.2),(132,4.7),(144,4.4),
                      (147,4.1),(150,5.3),(155,5.4),(158,4.6)]
        g['arm_y0'], g['arm_y1'] = 100, 158
        g['sleeve_y1'] = 124
        g['hand_y0'] = 148
        g['torso_y1'] = 130
        g['belt'] = (131, 136)
        g['hip_y0'], g['hip_y1'] = 137, 143
        g['HIP'] = [(137,17.0),(140,17.2),(143,17.2)]
        g['LEGCX'] = 9.0
        g['LEG'] = [(144,8.0),(152,7.7),(162,7.2),(170,6.8),(176,6.6)]
        g['leg_y0'], g['leg_y1'] = 144, 176
        g['leg_mat'] = 'bot'
        g['SHOECX'] = 9.4
        g['SHOE'] = [(177,7.6),(180,8.6),(185,9.4),(188,9.4)]
        g['SEAMS'] = [(59,14,46,42,2),(64,14,58,46,2),(68,16,77,43,2),
                      (71,20,86,35,2),(40,34,37,62,2),(87,34,89,60,2)]
        g['SHINE'] = [(84,26,89,50,1)]
    else:
        g['FACE'] = [(26,5),(31,13),(36,17.2),(42,20.2),(50,22.2),(58,22.8),
                     (66,22.4),(72,21.4),(78,19.4),(83,16.2),(87,11.2),
                     (89,6.2),(90,0)]
        g['HAIROUT'] = [(12,17),(16,21),(22,24.5),(30,27.0),(40,28.6),(52,29.2),
                        (62,29.2),(72,28.6),(80,28.4),(88,29.4),(98,30.6),
                        (110,31.0),(122,29.6),(132,28.6),(140,26.0),(146,21.0),
                        (151,13.0),(154,6.0),(156,0)]
        g['TOPEDGE'] = [(28,44),(33,39),(38,34),(42,26),(46,22),(50,16),
                        (55,13),(60,12),(64,14),(68,15),(73,20),(77,24),
                        (81,30),(86,35),(92,44)]
        g['FRINGE'] = [(26,56),(30,52),(35,47),(39,51),(44,46),(49,41),
                       (54,38),(58,36),(61,40),(65,44),(68,41),(72,45),
                       (76,49),(80,45),(84,49),(88,53),(92,57),(96,60)]
        g['TOR'] = [(94,9.0),(98,11.8),(102,13.4),(112,14.2),(122,14.8),
                    (129,15.2)]
        g['ARMCX'] = [(100,20.0),(110,20.8),(122,21.3),(142,22.6),(159,23.8)]
        g['ARMHW'] = [(100,4.8),(112,4.9),(124,4.6),(142,4.2),(147,3.9),
                      (150,5.0),(155,5.1),(159,4.4)]
        g['arm_y0'], g['arm_y1'] = 100, 159
        g['sleeve_y1'] = 114
        g['hand_y0'] = 148
        g['torso_y1'] = 129
        g['belt'] = None
        g['SKIRT'] = [(130,15.4),(136,18.4),(146,22.4),(155,24.6),(160,25.4)]
        g['skirt_y0'], g['skirt_y1'] = 130, 160
        g['LEGCX'] = 8.2
        g['LEG'] = [(150,6.9),(160,6.5),(170,6.1),(176,5.9)]
        g['leg_y0'], g['leg_y1'] = 152, 176
        g['leg_mat'] = 'skin'
        g['SHOECX'] = 8.6
        g['SHOE'] = [(177,6.9),(181,7.9),(186,8.5),(188,8.5)]
        g['HAIRBOT'] = [(30,132),(34,148),(37,140),(41,152),(45,144),(49,150),
                        (54,140),(60,136),(68,140),(74,151),(78,143),(82,153),
                        (86,145),(90,149),(94,136),(98,130)]
        g['SEAMS'] = [(57,15,41,46,2),(60,14,72,40,2),(63,16,84,52,2),
                      (38,56,35,126,2),(46,82,44,132,2),(86,60,89,126,2),
                      (79,90,81,134,2),(92,74,94,116,1),(84,104,86,140,1)]
        g['SHINE'] = [(34,66,33,126,2),(92,70,93,120,2),(83,100,85,134,1)]
    return g

# ============================================================= hair shading
HCY, HHX, HHY = 52.0, 29.0, 34.0          # skull used for the hair light

def ramp_shift(b, x, y, mat, step, hi=4):
    """move one pixel up/down its own material ramp - keeps the palette clean"""
    if not (0 <= x < W and 0 <= y < H): return
    if b.mat[y][x] != mat: return
    c = b.col[y][x]
    r = RAMP[mat]
    if c not in r: return
    i = r.index(c) + step
    if i < 0: i = 0
    if i > hi: i = hi
    b.col[y][x] = r[i]

def hair_highlight(b, girl):
    """anime hair band: a broken arc of light around the skull, jagged edges"""
    sx, sy = -0.45, -0.46                  # specular point on the skull
    for y in range(8, 96):
        for x in range(W):
            if b.mat[y][x] != 'hair': continue
            nx = (x + 0.5 - CX) / HHX
            ny = (y + 0.5 - HCY) / HHY
            if ny > 0.10 or ny < -1.05: continue
            r = math.hypot(nx - sx, ny - sy)
            j = 0.045 * ((((x // 3) * 7) % 3) - 1)
            lo, hi = 0.375 + j, 0.575 + j
            if lo <= r <= hi:
                if nx < -0.05 and (lo + 0.035) <= r <= (lo + 0.10):
                    b.col[y][x] = HAIR_LL
                else:
                    b.col[y][x] = HAIR_L
    # secondary, dim band on the shadow side
    for y in range(14, 90):
        for x in range(W):
            if b.mat[y][x] != 'hair': continue
            nx = (x + 0.5 - CX) / HHX
            ny = (y + 0.5 - HCY) / HHY
            if not (-0.85 < ny < -0.15): continue
            r = math.hypot(nx - sx, ny - sy)
            if 0.92 <= r <= 1.06 and nx > 0.25:
                ramp_shift(b, x, y, 'hair', +1)

def hair_strands(b, girl, seams, step=-1, hi=4):
    """a few deliberate strand seams, one ramp step darker (or lighter)"""
    for (x0, y0, x1, y1, wdt) in seams:
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            t = i / float(max(1, n))
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            for k in range(wdt):
                ramp_shift(b, R(x) + k, R(y), 'hair', step, hi)

# =================================================================== build
def build(sex):
    girl = (sex == 'girl')
    g = geo(girl)
    b = Buf()

    FACE = g['FACE']; HAIROUT = g['HAIROUT']
    TOPEDGE = g['TOPEDGE']; FRINGE = g['FRINGE']
    TOR = g['TOR']; ARMCX = g['ARMCX']; ARMHW = g['ARMHW']

    hcy, hhx, hhy = HCY, HHX, HHY             # head sphere for hair light
    fcy, fhx, fhy = 58.0, 23.0, 31.0          # face sphere

    def hair_px(x, y, extra=0.0, hw=None):
        nx = (x + 0.5 - CX) / hhx
        ny = (y + 0.5 - hcy) / hhy
        if ny > 0.92:                         # long hair hanging below the skull
            u = (x + 0.5 - CX) / (hw if hw else hhx)
            l = 0.5 + (cyl_lum(max(-1.0, min(1.0, u))) - 0.5) * 0.80 - 0.05
        else:
            l = 0.5 + (sph_lum(nx, ny) - 0.5) * 0.80
        b.put(x, y, 'hair', l + extra)

    # ---------------------------------------------------- 1. hair curtain
    if girl:
        HB = g['HAIRBOT']
        for y in range(84, 157):
            hw = prof(HAIROUT, y)
            xa, xb = span(CX, hw)
            for x in range(xa, xb + 1):
                if y > R(plin(HB, x + 0.5)): continue
                hair_px(x, y, hw=hw)

    # ---------------------------------------------------- 2. neck
    for y in range(84, 100):
        hw = 8.6 - max(0.0, (y - 94)) * 0.10
        b.cyl_row(y, CX, hw, 'skin', adj=-0.40)

    # ---------------------------------------------------- 3. legs / shoes
    if not girl:
        for y in range(g['hip_y0'], g['hip_y1'] + 1):
            b.cyl_row(y, CX, prof(g['HIP'], y), 'bot')
    for side in (-1, 1):
        cx = CX + side * g['LEGCX']
        for y in range(g['leg_y0'], g['leg_y1'] + 1):
            b.cyl_row(y, cx, prof(g['LEG'], y), g['leg_mat'],
                      adj=(-0.04 if side > 0 else 0.0))
    for side in (-1, 1):
        cx = CX + side * g['SHOECX']
        for y in range(177, 189):
            b.cyl_row(y, cx, prof(g['SHOE'], y), 'shoe',
                      adj=(-0.05 if side > 0 else 0.0))

    # ---------------------------------------------------- 4. skirt
    if girl:
        def skirt_mod(x, y, u):
            t = ((u + 1.0) * 3.2 + 0.35) % 1.0
            if t < 0.34:  return  0.11
            if t < 0.68:  return  0.0
            return -0.13
        for y in range(g['skirt_y0'], g['skirt_y1'] + 1):
            hw = prof(g['SKIRT'], y)
            xa, xb = span(CX, hw)
            for x in range(xa, xb + 1):
                u = (x + 0.5 - CX) / hw
                l = cyl_lum(u) + skirt_mod(x, y, u)
                b.put(x, y, 'bot', l)

    # ---------------------------------------------------- 5. torso
    for y in range(94, g['torso_y1'] + 1):
        b.cyl_row(y, CX, prof(TOR, y), 'top')
    if not girl:
        y0, y1 = g['belt']
        for y in range(y0, y1 + 1):
            b.cyl_row(y, CX, prof(TOR, 136) + (y - y0) * 0.03, 'bot', adj=-0.30)

    # ---------------------------------------------------- 6. front locks
    if girl:
        LOCKW = [(86,11.0),(96,9.0),(108,8.0),(118,7.0),(124,5.0),
                 (128,2.5),(130,0)]
        LOCKO = [(86,26.0),(90,23.0),(94,19.0),(98,16.0),(102,14.6),
                 (112,15.2),(122,15.8),(130,16.2)]
        for side in (-1, 1):
            for y in range(86, 131):
                ow = prof(LOCKO, y); lw = prof(LOCKW, y)
                if lw <= 0.4: continue
                if side < 0:
                    xa = int(math.ceil(CX - ow - 0.5))
                    xb = int(math.floor(CX - (ow - lw) - 0.5))
                else:
                    xa = int(math.ceil(CX + (ow - lw) - 0.5))
                    xb = int(math.floor(CX + ow - 0.5))
                for x in range(xa, xb + 1):
                    hair_px(x, y, extra=0.045, hw=ow)

    # ---------------------------------------------------- 7. arms
    for side in (-1, 1):
        for y in range(g['arm_y0'], g['arm_y1'] + 1):
            cx = CX + side * prof(ARMCX, y)
            hw = prof(ARMHW, y)
            if y >= g['arm_y1'] - 2:
                hw -= (y - (g['arm_y1'] - 2)) * 1.1
            xa, xb = span(cx, hw)
            if y >= 104:
                if side < 0: b.erase_row(y, xb + 1, xb + 2)
                else:        b.erase_row(y, xa - 2, xa - 1)
                if side < 0: b.erase_row(y, xa - 2, xa - 1)
                else:        b.erase_row(y, xb + 1, xb + 2)
            mat = 'top' if y <= g['sleeve_y1'] else 'skin'
            adj = 0.0
            if side > 0: adj -= 0.10
            for x in range(xa, xb + 1):
                u = (x + 0.5 - cx) / max(0.5, hw)
                b.put(x, y, mat, cyl_lum(u) + adj)
        for y in range(g['arm_y1'] + 1, g['arm_y1'] + 3):
            cx = CX + side * prof(ARMCX, g['arm_y1'])
            xa, xb = span(cx, prof(ARMHW, g['arm_y1']) + 1.2)
            b.erase_row(y, xa, xb)

    # ---------------------------------------------------- 8. face
    for y in range(26, 91):
        hw = prof(FACE, y)
        xa, xb = span(CX, hw)
        for x in range(xa, xb + 1):
            nx = (x + 0.5 - CX) / fhx
            ny = (y + 0.5 - fcy) / fhy
            b.put(x, y, 'skin', sph_lum(nx, ny))

    # ---------------------------------------------------- 9. head hair
    hb = 92 if girl else 78
    for y in range(10, hb):
        hw = prof(HAIROUT, y)
        xa, xb = span(CX, hw)
        for x in range(xa, xb + 1):
            if y < R(plin(TOPEDGE, x + 0.5)): continue
            fw = prof(FACE, y)
            inface = abs(x + 0.5 - CX) < fw - 0.3
            if inface and y >= R(plin(FRINGE, x + 0.5)): continue
            hair_px(x, y, hw=hw)

    # --------------------------------------------------- 10. occlusion
    occl(b, g, girl)
    quantize(b)
    hair_strands(b, girl, g['SEAMS'])
    hair_strands(b, girl, g.get('SHINE', []), +1, 3)
    hair_highlight(b, girl)
    features(b, g, girl)
    outline(b)
    return to_image(b)

# ================================================================ occlusion
def occl(b, g, girl):
    # hair shadow on the forehead / face sides
    for y in range(H):
        for x in range(W):
            if b.mat[y][x] != 'skin': continue
            d = 0
            for k in range(1, 6):
                if y - k < 0: break
                if b.mat[y - k][x] == 'hair':
                    d = k; break
            if d:
                b.lum[y][x] -= (0.30 if d <= 3 else 0.16)
            else:
                for k in range(1, 4):
                    if (b.mat[y][x - k] == 'hair' if x - k >= 0 else False) or \
                       (b.mat[y][x + k] == 'hair' if x + k < W else False):
                        b.lum[y][x] -= 0.13
                        break
    # shirt shadow under the chin
    for y in range(94, 104):
        for x in range(W):
            if b.mat[y][x] == 'top':
                dx = abs(x + 0.5 - CX)
                if dx < 15.0 and y < 101:
                    b.lum[y][x] -= 0.26 * (1.0 - max(0.0, (y - 94)) / 7.0)
    # shadow cast by sleeve hem on the arm, and by hem on the legs
    for y in range(H):
        for x in range(W):
            m = b.mat[y][x]
            if m is None: continue
            if m in ('skin', 'bot') and y > 100:
                for k in range(1, 4):
                    if y - k < 0: break
                    if b.mat[y - k][x] in ('top',) and m == 'skin':
                        b.lum[y][x] -= 0.22; break
                    if b.mat[y - k][x] == 'bot' and m == 'skin':
                        b.lum[y][x] -= 0.26; break
    # shoes sit in the grass -> bottom row darker
    for y in range(186, 190):
        for x in range(W):
            if b.mat[y][x] == 'shoe':
                b.lum[y][x] -= 0.20

# ================================================================ quantize
def quantize(b):
    for y in range(H):
        for x in range(W):
            m = b.mat[y][x]
            if m is None: continue
            l = b.lum[y][x]
            t = THR[m]; r = RAMP[m]
            if   l < t[0]: c = r[0]
            elif l < t[1]: c = r[1]
            elif l < t[2]: c = r[2]
            elif l < t[3]: c = r[3]
            else:          c = r[4]
            b.col[y][x] = c

# ================================================================= features
def eye(b, cx, cy, girl):
    """dark chibi eye: reads as one dark oval even at 0.28 scale"""
    hw = [3.0, 4.3, 4.9, 5.1, 5.1, 5.1, 5.0, 4.9, 4.7, 4.4, 4.0, 3.4, 2.5, 1.5]
    if girl:
        hw = [3.2, 4.5, 5.1, 5.3, 5.3, 5.3, 5.2, 5.0, 4.8, 4.5, 4.1, 3.5, 2.6, 1.6]
    n = len(hw)
    for i in range(n):
        y = cy + i
        xa, xb = span(cx, hw[i])
        for x in range(xa, xb + 1):
            c = OUT if i <= 1 else EYE
            if i >= n - 3 and (x == xa or x == xb): c = OUT
            b.forcec(x, y, c)
    # one small glint, upper left, plus a two pixel bounce light low right
    for dy in (3, 4):
        b.forcec(R(cx) - 3, cy + dy, WHITE)
    b.forcec(R(cx) - 4, cy + 3, WHITE)
    b.forcec(R(cx) + 2, cy + 9, WHITE)
    b.forcec(R(cx) + 3, cy + 9, WHITE)
    # outer lash tick
    ss = 1 if cx > CX else -1
    b.forcec(R(cx) + ss * 5, cy + 1, OUT)
    b.forcec(R(cx) + ss * 5, cy + 2, OUT)
    if girl:
        b.forcec(R(cx) + ss * 6, cy + 0, OUT)
        b.forcec(R(cx) + ss * 6, cy + 1, OUT)

def features(b, g, girl):
    ecy = 56
    for side in (-1, 1):
        eye(b, CX + side * 11.0, ecy, girl)
    # brows - inner end thick, tail thin, tilted like the reference
    for side in (-1, 1):
        for i in range(10):
            x = R(CX + side * (5.5 + i))
            if not girl:
                dy = [2, 1, 0, 0, 0, 0, 1, 1, 2, 2][i]
                th = 2 if i < 7 else 1
            else:
                dy = [2, 1, 1, 0, 0, 0, 1, 1, 2, 3][i]
                th = 2 if i < 6 else 1
            for k in range(th):
                b.forcec(x, 51 + dy + k, BROW)
    # cheeks - small flat blush, clear of the eyes
    for side in (-1, 1):
        for dy in range(2):
            wsp = [3, 2][dy]
            for dx in range(-wsp, wsp + 1):
                x = R(CX + side * 16.0) + dx
                b.setc(x, 73 + dy, SKIN_CH)
    # mouth
    if not girl:
        for dx in (-2, -1, 0, 1, 2):
            b.forcec(R(CX) + dx, 78, SKIN_M)
        b.forcec(R(CX) - 3, 77, SKIN_M)
        b.forcec(R(CX) + 3, 77, SKIN_M)
        for dx in (-1, 0, 1):
            b.forcec(R(CX) + dx, 79, SKIN_M)
    else:
        for dx in (-1, 0, 1):
            b.forcec(R(CX) + dx, 78, SKIN_M)
            b.forcec(R(CX) + dx, 79, SKIN_M)
        b.forcec(R(CX) - 2, 78, SKIN_M)
        b.forcec(R(CX) + 2, 78, SKIN_M)
    # ---- collar
    COL = [(93,8.4),(96,9.8),(99,8.8),(100,6.0),(101,0)]
    for y in range(93, 103):
        hw = prof(COL, y)
        xa, xb = span(CX, hw)
        for x in range(xa, xb + 1):
            if b.mat[y][x] == 'top':
                b.col[y][x] = TOP_D
    for y in range(93, 103):
        hw = prof(COL, y)
        xa, xb = span(CX, hw)
        for x in (xa - 1, xb + 1):
            if 0 <= x < W and b.mat[y][x] == 'top':
                b.col[y][x] = TOP_DD
    # ---- buttons / placket
    if not girl:
        for y in range(103, g['torso_y1'] + 1):
            b.setc(R(CX) + 2, y, TOP_D)
        for y in (106, 114, 122):
            b.setc(R(CX) - 1, y, TOP_LL)
            b.setc(R(CX), y, TOP_LL)
    else:
        # little ribbon at the throat
        for dx in range(-3, 3):
            b.setc(R(CX) + dx, 100, TOP_LL)
        for dx in range(-2, 2):
            b.setc(R(CX) + dx, 101, TOP_LL)
        b.setc(R(CX) - 1, 102, TOP_LL)
        b.setc(R(CX), 102, TOP_LL)
    # ---- sleeve hem line
    for side in (-1, 1):
        y = g['sleeve_y1']
        cx = CX + side * prof(g['ARMCX'], y)
        xa, xb = span(cx, prof(g['ARMHW'], y))
        for x in range(xa, xb + 1):
            if b.mat[y][x] == 'top':
                b.col[y][x] = TOP_DD
    # ---- chest pocket (boy) / sleeve cuffs (girl)
    if not girl:
        px0, py0 = R(CX) - 13, 108
        for i in range(8):
            b.setc(px0 + i, py0, TOP_L)
            b.setc(px0 + i, py0 + 6, TOP_DD)
        for j in range(1, 7):
            b.setc(px0, py0 + j, TOP_D)
            b.setc(px0 + 7, py0 + j, TOP_DD)
        b.setc(px0 + 3, py0 + 6, TOP_D)
        b.setc(px0 + 4, py0 + 6, TOP_D)
    else:
        for side in (-1, 1):
            y = g['sleeve_y1']
            cx = CX + side * prof(g['ARMCX'], y)
            xa, xb = span(cx, prof(g['ARMHW'], y) + 0.5)
            cc = TOP_LL if side < 0 else TOP_L
            for x in range(xa, xb + 1):
                if b.mat[y][x] == 'top': b.col[y][x] = cc
                if b.mat[y - 1][x] == 'top': b.col[y - 1][x] = cc
    # ---- shoe sole
    for x in range(W):
        for y in (187, 188):
            if b.mat[y][x] == 'shoe': b.col[y][x] = SHOE_DD
    # ---- belt + buckle
    if not girl:
        y0, y1 = g['belt']
        for x in range(R(CX) - 3, R(CX) + 3):
            for y in range(y0 + 1, y1):
                b.setc(x, y, BOT_LL)
        for x in range(R(CX) - 1, R(CX) + 1):
            for y in range(y0 + 2, y1 - 1):
                b.setc(x, y, BOT_D)
    # ---- skirt hem
    if girl:
        y1 = g['skirt_y1']
        for x in range(W):
            ramp_shift(b, x, y1, 'bot', -1)
            ramp_shift(b, x, y1 - 1, 'bot', -1)
    # ---- shoe top line
    for x in range(W):
        for y in range(176, 181):
            if b.mat[y][x] == 'shoe' and b.mat[y - 1][x] != 'shoe':
                b.col[y][x] = SHOE_DD
    # ---- seam that lifts the front hair lock off the curtain behind it
    if girl:
        LOCKO2 = [(86,26.0),(90,23.0),(94,19.0),(98,16.0),(102,14.6),
                  (112,15.2),(122,15.8),(130,16.2)]
        for side in (-1, 1):
            for y in range(86, 106):
                ow = prof(LOCKO2, y)
                x = int(math.floor(CX + ow - 0.5)) if side > 0 else \
                    int(math.ceil(CX - ow - 0.5))
                ramp_shift(b, x, y, 'hair', -2)
                ramp_shift(b, x + side, y, 'hair', -1)
    # ---- torso volume
    for y in range(104, g['torso_y1'] + 1):
        hw = prof(g['TOR'], y)
        xa, xb = span(CX, hw)
        for k in range(3):
            ramp_shift(b, xb - k, y, 'top', -1)
    for y in range(g['torso_y1'] - 1, g['torso_y1'] + 1):
        for x in range(W):
            ramp_shift(b, x, y, 'top', -1)
    # ---- shoulder seam so the sleeve does not blob into the torso
    for side in (-1, 1):
        for y in range(99, 105):
            cx = CX + side * prof(g['ARMCX'], y)
            hw = prof(g['ARMHW'], y)
            xa, xb = span(cx, hw)
            x = xb + 1 if side < 0 else xa - 1
            for k in range(2):
                xx = x + (k if side > 0 else -k)
                if 0 <= xx < W and b.mat[y][xx] == 'top':
                    b.col[y][xx] = TOP_DD
    # ---- wrist line + knuckle shadow
    for side in (-1, 1):
        y = g['hand_y0']
        cx = CX + side * prof(g['ARMCX'], y)
        xa, xb = span(cx, prof(g['ARMHW'], y) - 0.9)
        for x in range(xa, xb + 1):
            ramp_shift(b, x, y, 'skin', -2)
            ramp_shift(b, x, y + 1, 'skin', -1)
    # ---- inner leg shadow, both legs
    for y in range(g['leg_y0'], g['leg_y1'] + 1):
        hw = prof(g['LEG'], y)
        for side in (-1, 1):
            cx = CX + side * g['LEGCX']
            xa, xb = span(cx, hw)
            inner = xb if side < 0 else xa
            for k in range(3):
                ramp_shift(b, inner - k * side, y, g['leg_mat'], -1)
    # ---- trouser cuff / sock line
    for y in (174, 175, 176):
        for x in range(W):
            if b.mat[y][x] == g['leg_mat'] and y == 174:
                ramp_shift(b, x, y, g['leg_mat'], -1)
    # ---- hair bow (girl)
    if girl:
        bow(b, 42, 24)

def bow(b, cx, cy):
    """small ribbon - two wings and a knot, lit from the upper left"""
    wing = [1, 3, 4, 5, 5, 4, 3, 1]
    for i in range(8):
        w = wing[i]
        x = cx - 3 - i
        for dy in range(-w, w + 1):
            c = TOP_L if (dy < 0 and i > 2) else (TOP if dy < w - 1 else TOP_D)
            b.forcec(x, cy + dy, c)
        b.forcec(x, cy - w, TOP_DD)
        b.forcec(x, cy + w, TOP_DD)
    for i in range(7):
        w = wing[i + 1] - 1
        x = cx + 3 + i
        for dy in range(-w, w + 1):
            c = TOP if dy < 0 else TOP_D
            b.forcec(x, cy + dy, c)
        b.forcec(x, cy - w, TOP_DD)
        b.forcec(x, cy + w, TOP_DD)
    for dx in range(-2, 3):
        for dy in range(-3, 4):
            if abs(dx) + abs(dy) <= 4:
                b.forcec(cx + dx, cy + dy, TOP_D)
    b.forcec(cx - 1, cy - 2, TOP)
    b.forcec(cx, cy - 2, TOP)
    b.forcec(cx - 1, cy - 1, TOP_L)

# ================================================================== outline
def outline(b):
    N4 = ((1,0),(-1,0),(0,1),(0,-1))
    # ring 1 : black
    ring1 = []
    for y in range(H):
        for x in range(W):
            if b.col[y][x] is not None: continue
            src = None
            for dx, dy in N4:
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and b.col[ny][nx] is not None \
                   and b.mat[ny][nx] != 'out':
                    src = b.mat[ny][nx]; break
            if src is not None:
                ring1.append((x, y, src))
    for x, y, s in ring1:
        b.col[y][x] = OUT; b.mat[y][x] = 'out'; b.lum[y][x] = -1.0
    src_of = {}
    for x, y, s in ring1: src_of[(x, y)] = s
    # ring 2 : black on the shadow side, material dark tone on the lit side
    ring2 = []
    for y in range(H):
        for x in range(W):
            if b.col[y][x] is not None: continue
            sx = sy = 0; hit = 0; src = None
            for dx, dy in N4:
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and (nx, ny) in src_of:
                    sx += dx; sy += dy; hit += 1
                    if src is None: src = src_of[(nx, ny)]
            if hit:
                ring2.append((x, y, sx, sy, src))
    for x, y, sx, sy, src in ring2:
        lit = (sx >= 0 and sy >= 0 and (sx + sy) > 0)
        if lit and src in RAMP:
            b.col[y][x] = RAMP[src][0]
        else:
            b.col[y][x] = OUT
        b.mat[y][x] = 'out'
    # fill 1px notches so the silhouette has no needle holes
    for _ in range(2):
        fix = []
        for y in range(H):
            for x in range(W):
                if b.col[y][x] is not None: continue
                n = 0
                for dx, dy in N4:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and b.col[ny][nx] is not None:
                        n += 1
                if n >= 3: fix.append((x, y))
        for x, y in fix:
            b.col[y][x] = OUT; b.mat[y][x] = 'out'

def to_image(b):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            c = b.col[y][x]
            if c is not None:
                px[x, y] = (c[0], c[1], c[2], 255)
    return im

# ==================================================================== checks
def check(im, name):
    px = im.load()
    ok = True
    out = []
    def line(label, good, txt):
        out.append('  %-18s %s  %s' % (label, 'OK  ' if good else 'FAIL', txt))
        return good

    ok &= line('size', im.size == (W, H), '%dx%d' % im.size)

    low = -1; left = W; right = -1
    for y in range(H):
        for x in range(W):
            if px[x, y][3] != 0:
                low = y
                if x < left: left = x
                if x > right: right = x
    ok &= line('sole row', low == 190, 'lowest opaque y = %d (want 190)' % low)
    ok &= line('centred', left + right == W - 1,
               'x span %d..%d, mirror sum %d (want %d)' % (left, right, left + right, W - 1))

    bad_a = 0; cols = {}
    for y in range(H):
        for x in range(W):
            a = px[x, y][3]
            if a not in (0, 255): bad_a += 1
            if a == 255:
                c = px[x, y][:3]; cols[c] = cols.get(c, 0) + 1
    ok &= line('alpha 0 or 255', bad_a == 0, '%d semi-transparent pixels' % bad_a)

    off = sorted([c for c in cols if c not in ALLOWED])
    ok &= line('palette', len(off) == 0,
               '%d colours used, %d outside the table %s' % (len(cols), len(off), off[:4]))

    seen = [[False] * W for _ in range(H)]; comps = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 255 and not seen[y][x]:
                st = [(x, y)]; seen[y][x] = True; n = 0
                while st:
                    cx, cy = st.pop(); n += 1
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] \
                           and px[nx, ny][3] == 255:
                            seen[ny][nx] = True; st.append((nx, ny))
                comps.append(n)
    ok &= line('one blob', len(comps) == 1,
               '%d connected component(s) %s' % (len(comps), sorted(comps, reverse=True)[:4]))

    # informative: silhouette left-edge jumps (topology changes are expected)
    jumps = []; prev = None
    for y in range(H):
        xs = [x for x in range(W) if px[x, y][3] == 255]
        if not xs: prev = None; continue
        if prev is not None and abs(xs[0] - prev) > 2: jumps.append(y)
        prev = xs[0]
    out.append('  %-18s ---   left-edge jumps >2px at rows %s (spike tips / limb starts)'
               % ('stair check', jumps))

    print('[%s]' % name)
    for o in out: print(o)
    return ok

# ====================================================================== view
def make_view(boy, girl):
    pad = 24
    big = 3
    bw, bh = W * big, H * big
    small = (R(W * 0.28), R(H * 0.28))
    right = small[0] * 2 + 36
    vw = pad * 3 + bw * 2 + right + pad
    vh = bh + pad * 2
    im = Image.new('RGBA', (vw, vh), GRASS + (255,))
    b3 = boy.resize((bw, bh), Image.NEAREST)
    g3 = girl.resize((bw, bh), Image.NEAREST)
    im.alpha_composite(b3, (pad, pad))
    im.alpha_composite(g3, (pad * 2 + bw, pad))
    bs = boy.resize(small, Image.NEAREST)
    gs = girl.resize(small, Image.NEAREST)
    x0 = pad * 3 + bw * 2
    y0 = pad + (bh - small[1]) // 2
    im.alpha_composite(bs, (x0, y0))
    im.alpha_composite(gs, (x0 + small[0] + 12, y0))
    return im

def main():
    boy = build('boy')
    girl = build('girl')
    boy.save(os.path.join(HERE, 'c128shade_boy.png'))
    girl.save(os.path.join(HERE, 'c128shade_girl.png'))
    view = make_view(boy, girl)
    view.save(os.path.join(HERE, 'c128shade_view.png'))
    allok = True
    for im, nm in ((boy, 'boy'), (girl, 'girl')):
        allok = check(im, nm) and allok
    print('ALL CHECKS PASSED' if allok else 'CHECKS FAILED')

if __name__ == '__main__':
    main()
