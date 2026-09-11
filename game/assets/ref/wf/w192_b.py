#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""w192_b — 리틀 루트 주인공 도트 192 x 288.

디자인 방향 (key = b): **스타듀밸리 계열**.
  · 두툼하고 안정적인 실루엣 — 어깨가 머리만큼 넓고 장화가 묵직하다
  · 옷 주름과 천 접힘이 많다 — 소매단, 옷단, 무릎, 치마 주름
  · 눈은 중간 크기(얼굴 폭의 1/3)에 또렷하다
  · 생활감 있는 농부

처음부터 192칸 격자에 직접 찍는다. 32/64칸 그림을 확대하지 않는다.
실루엣도 음영 경계도 전부 스플라인으로 줄마다 한 칸씩 흐르게 잡는다.

실행하면 여섯 장:
  w192_b_{boy,girl}_{down,side,up}.png
"""

import math
from PIL import Image

W, H = 192, 288
CXI = 96          # 좌우 대칭 기준.  x = 96-h .. 95+h  이면 중심이 정확히 95.5

# ---------------------------------------------------------------- 팔레트
# 표 밖의 색은 한 칸도 쓰지 않는다.
PAL = {
    's': (243, 159, 138), 'l': (250, 192, 170), 'd': (213, 116, 98),
    'c': (235, 128, 114), 'm': (170, 84, 66),  'S': (184, 99, 83),
    'L': (252, 217, 204),
    'h': (118, 72, 40), 'H': (152, 100, 56), 'j': (86, 52, 30),
    'J': (58, 35, 20), 'y': (195, 165, 140),
    't': (58, 88, 168), 'T': (94, 126, 200), 'u': (38, 58, 120),
    'U': (27, 41, 84), 'i': (166, 184, 225),
    'p': (134, 88, 46), 'P': (158, 108, 58), 'q': (98, 62, 32),
    'Q': (69, 43, 22), 'r': (202, 174, 147),
    'b': (82, 53, 33), 'n': (56, 37, 25), 'N': (39, 26, 18),
    'o': (26, 20, 28), 'e': (66, 32, 30), 'w': (136, 70, 42),
    'X': (246, 242, 234),
}

MAT = {}
for _c in 'sldcmSL':
    MAT[_c] = 'skin'
for _c in 'hHjJy':
    MAT[_c] = 'hair'
for _c in 'tTuUi':
    MAT[_c] = 'shirt'
for _c in 'pPqQr':
    MAT[_c] = 'pants'
for _c in 'bnN':
    MAT[_c] = 'shoe'
# 'o','e','w','X' 는 눈·입 전용 — 윤곽 대상이 아니다

DDC = {'skin': 'S', 'hair': 'J', 'shirt': 'U', 'pants': 'Q', 'shoe': 'N'}
LIT = {'s': 'l', 'h': 'H', 't': 'T', 'p': 'P', 'b': 'b'}
DRK = {'s': 'd', 'h': 'j', 't': 'u', 'p': 'q', 'b': 'n'}
BASE = 'shtpb'

# z 순서 (뒤 -> 앞)
Z_FARARM, Z_BACKHAIR, Z_LEG, Z_PANT, Z_SHOE = 6, 8, 12, 16, 19
Z_NECK, Z_SHIRT, Z_BACK2, Z_ARM, Z_HAND = 22, 25, 30, 35, 40
Z_HEAD, Z_HAIR, Z_EAR, Z_LOCK = 50, 60, 62, 64


# ---------------------------------------------------------------- 곡선
def spline(pts):
    """Catmull-Rom.  실루엣을 줄마다 한 칸씩 흐르게 만드는 도구."""
    pts = sorted(pts)
    ts = [float(p[0]) for p in pts]
    vs = [float(p[1]) for p in pts]
    n = len(pts)

    def f(t):
        if t <= ts[0]:
            return vs[0]
        if t >= ts[-1]:
            return vs[-1]
        i = 0
        while i < n - 2 and ts[i + 1] <= t:
            i += 1
        hh = ts[i + 1] - ts[i]
        u = (t - ts[i]) / hh
        m0 = ((vs[i + 1] - vs[i - 1]) / (ts[i + 1] - ts[i - 1])
              if i > 0 else (vs[i + 1] - vs[i]) / hh)
        m1 = ((vs[i + 2] - vs[i]) / (ts[i + 2] - ts[i])
              if i < n - 2 else (vs[i + 1] - vs[i]) / hh)
        u2 = u * u
        u3 = u2 * u
        return ((2 * u3 - 3 * u2 + 1) * vs[i] + (u3 - 2 * u2 + u) * hh * m0 +
                (-2 * u3 + 3 * u2) * vs[i + 1] + (u3 - u2) * hh * m1)
    return f


# ---------------------------------------------------------------- 구간(run) 연산
def rsub(A, B):
    """행별 구간 빼기 — 머리카락 고리(머리 덩어리 - 얼굴 창)를 만들 때 쓴다."""
    out = {}
    for y, ra in A.items():
        rb = B.get(y, [])
        segs = list(ra)
        for (c0, c1) in rb:
            new = []
            for (s, e) in segs:
                if c1 < s or c0 > e:
                    new.append((s, e))
                    continue
                if c0 > s:
                    new.append((s, c0 - 1))
                if c1 < e:
                    new.append((c1 + 1, e))
            segs = new
        segs = [g for g in segs if g[1] >= g[0]]
        if segs:
            out[y] = segs
    return out


def rmerge(*sets):
    out = {}
    for A in sets:
        for y, ra in A.items():
            out.setdefault(y, []).extend(ra)
    for y in out:
        out[y] = sorted(out[y])
    return out


def mirror(A):
    out = {}
    for y, ra in A.items():
        out[y] = sorted((W - 1 - b, W - 1 - a) for (a, b) in ra)
    return out


def sym(y0, y1, pts):
    """대칭 덩어리.  half 값 h -> x = 96-h .. 95+h (중심 95.5)"""
    f = spline(pts)
    rows = {}
    for y in range(y0, y1 + 1):
        hh = int(round(f(y)))
        if hh < 1:
            continue
        rows[y] = [(CXI - hh, CXI - 1 + hh)]
    return rows


def band(y0, y1, lpts, rpts):
    fl, fr = spline(lpts), spline(rpts)
    rows = {}
    for y in range(y0, y1 + 1):
        a, b = int(round(fl(y))), int(round(fr(y)))
        if b >= a:
            rows[y] = [(a, b)]
    return rows


def tube(y0, y1, cpts, rpts):
    """중심선 + 반지름으로 만드는 팔·다리."""
    fc, fr = spline(cpts), spline(rpts)
    rows = {}
    for y in range(y0, y1 + 1):
        cc, rr = fc(y), fr(y)
        a, b = int(round(cc - rr)), int(round(cc + rr))
        if b >= a:
            rows[y] = [(a, b)]
    return rows


# ---------------------------------------------------------------- 캔버스
class Canvas(object):
    def __init__(self):
        self.g = [['.'] * W for _ in range(H)]
        self.z = [[0] * W for _ in range(H)]

    def put(self, x, y, ch, z, only=None):
        """z 가 낮은 것은 이미 칠해진 앞 부위를 덮지 못한다.
        (이걸 안 하면 나중에 그린 뒷머리가 몸통을 지워 머리 망토가 된다)"""
        if 0 <= x < W and 0 <= y < H:
            if self.z[y][x] > z:
                return
            if only is not None and self.g[y][x] not in only:
                return
            self.g[y][x] = ch
            self.z[y][x] = z

    def blit(self, rows, ch, z, only=None):
        for y, ra in rows.items():
            for (a, b) in ra:
                for x in range(a, b + 1):
                    self.put(x, y, ch, z, only)

    # --- 타원 (눈·볼) -------------------------------------------------
    def ell(self, cx, cy, rx, ry, ch, z, only=None):
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, ch, z, only)

    # --- 끝이 가늘어지는 곡선 (주름·머릿결) ----------------------------
    def stroke(self, pts, ch, z, w=2.0, only=None, taper=0.8):
        n = len(pts)
        if n < 2:
            return
        fx = spline(list(zip(range(n), [p[0] for p in pts])))
        fy = spline(list(zip(range(n), [p[1] for p in pts])))
        ln = sum(math.hypot(pts[i + 1][0] - pts[i][0],
                            pts[i + 1][1] - pts[i][1]) for i in range(n - 1))
        steps = max(8, int(ln * 3))
        for s in range(steps + 1):
            t = (n - 1) * float(s) / steps
            x, y = fx(t), fy(t)
            u = 2.0 * s / steps - 1.0
            ww = w * (1.0 - taper * abs(u) ** 2.4)
            r = max(ww / 2.0, 0.55)
            for yy in range(int(y - r - 1), int(y + r + 2)):
                for xx in range(int(x - r - 1), int(x + r + 2)):
                    if (xx - x) ** 2 + (yy - y) ** 2 <= r * r:
                        self.put(xx, yy, ch, z, only)


# ---------------------------------------------------------------- 음영
def rim(c, rows, zs, lit=(4.0, 2.0, 0.0), drk=(5.0, 2.5, 1.7), only=None):
    """빛은 왼쪽 위.  덩어리 경계에서 왼위로 나가는 거리 / 오른아래로 나가는
    거리를 재서 띠를 만든다.  두께를 sin 으로 흔들어 자로 그은 자국을 없앤다."""
    ys = sorted(rows.keys())
    if not ys:
        return
    pix = []
    for y in ys:
        for (a, b) in rows[y]:
            for x in range(a, b + 1):
                if c.z[y][x] in zs and c.g[y][x] in (only or BASE):
                    pix.append((x, y))

    def walk(x, y, dx, dy):
        k = 0
        xx, yy = x, y
        while k < 16:
            xx += dx
            yy += dy
            if not (0 <= xx < W and 0 <= yy < H):
                break
            if c.z[yy][xx] not in zs:
                break
            k += 1
        return k

    a0, a1, ap = lit
    b0, b1, bp = drk
    mk = []
    for (x, y) in pix:
        dl = a0 + a1 * math.sin(y * 0.115 + ap) + a1 * 0.55 * math.cos(x * 0.083 + ap * 1.6)
        dd = b0 + b1 * math.sin(y * 0.094 + bp) + b1 * 0.5 * math.cos(x * 0.071 + bp * 1.3)
        if walk(x, y, -1, -1) < dl:
            mk.append((x, y, 1))
        elif walk(x, y, 1, 1) < dd:
            mk.append((x, y, 2))
    for (x, y, k) in mk:
        ch = c.g[y][x]
        tb = LIT if k == 1 else DRK
        if ch in tb:
            c.g[y][x] = tb[ch]


def inner_shadow(c, rows, zs, depth, ch):
    """팔·다리의 **몸통 쪽** 가장자리에 그늘.  관이 몸에서 떨어져 보인다."""
    for y, ra in rows.items():
        for (a, b) in ra:
            for x in range(a, b + 1):
                if c.z[y][x] not in zs:
                    continue
                dx = 1 if x < 96 else -1
                k = 0
                xx = x
                while k < 8:
                    xx += dx
                    if not (0 <= xx < W) or c.z[y][xx] not in zs:
                        break
                    k += 1
                d = depth + 0.9 * math.sin(y * 0.17 + (0 if dx > 0 else 1.9))
                if k < d and c.g[y][x] in BASE + 'lT':
                    c.g[y][x] = ch


# ---------------------------------------------------------------- 윤곽
def outline(c, thick=2):
    """재질마다 그 재질의 가장 어두운 단으로.  검정 윤곽은 쓰지 않는다."""
    # (1) 실루엣 — 공기와 닿는 쪽.  캔버스 밖은 공기로 세지 않는다.
    cur = set()
    for y in range(H):
        for x in range(W):
            ch = c.g[y][x]
            if ch == '.' or ch not in MAT:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and c.g[ny][nx] == '.':
                    cur.add((x, y))
                    break
    done = set(cur)
    for _ in range(thick - 1):
        nxt = set()
        for (x, y) in cur:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (0 <= nx < W and 0 <= ny < H and (nx, ny) not in done
                        and c.g[ny][nx] in MAT):
                    nxt.add((nx, ny))
        done |= nxt
        cur = nxt
    # (2) 앞 부위가 뒤 부위를 덮는 경계 — 앞쪽 가장자리에 한 칸
    snapz = [row[:] for row in c.z]
    inner = set()
    for y in range(H):
        for x in range(W):
            ch = c.g[y][x]
            if ch not in MAT:
                continue
            zz = snapz[y][x]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H):
                    continue
                n = c.g[ny][nx]
                if n not in MAT or snapz[ny][nx] >= zz:
                    continue
                # 머리카락끼리는 긋지 않는다 — 한 덩어리여야 한다
                if MAT[n] == 'hair' and MAT[ch] == 'hair':
                    continue
                inner.add((x, y))
                break
    for (x, y) in done | inner:
        ch = c.g[y][x]
        if ch in MAT:
            c.g[y][x] = DDC[MAT[ch]]


# ================================================================ 머리
HEAD_W = [(14, 13), (17, 21), (21, 28), (26, 34), (32, 39), (40, 43),
          (50, 46), (62, 47), (74, 47), (84, 46), (92, 44), (99, 41),
          (105, 35), (110, 27), (113, 19), (115, 11), (116, 5)]
FACE_W = [(48, 30), (56, 35), (66, 38), (76, 40), (86, 40), (93, 39),
          (99, 37), (105, 34), (110, 27), (113, 19), (115, 11), (116, 5)]
# 앞머리 — 가닥마다 둥근 혀 모양. 겹쳐서 max 를 잡으면 끝이 둥글고
# 사이에 좁은 홈이 생긴다. 톱니 스플라인으로 그으면 왕관처럼 각진다.
#   (중심x, 반폭, 윗기준, 늘어진 깊이)
FR_LOCKS = [(46, 24, 36, 11), (64, 18, 39, 14), (79, 15, 38, 12),
            (93, 18, 40, 15), (109, 16, 37, 13), (123, 19, 39, 12),
            (139, 22, 36, 11), (150, 16, 34, 9)]
SFR_LOCKS = [(60, 22, 34, 11), (77, 17, 38, 14), (92, 15, 37, 12),
             (106, 18, 39, 15), (120, 16, 36, 13), (133, 17, 38, 11),
             (146, 18, 35, 10)]


def fringe_fn(locks, fallback=44.0):
    def f(x):
        best = fallback
        for (lx, lw, lb, ld) in locks:
            u = (x - lx) / float(lw)
            if abs(u) < 1.0:
                v = lb + ld * math.sqrt(1.0 - u * u)
                if v > best:
                    best = v
        return best
    return f

EY = 80.0          # 눈 중심 줄
EGAP = 23.5        # 눈 중심 사이 반거리


def head_front(c, girl):
    head = sym(14, 116, HEAD_W)
    face = sym(46, 116, FACE_W)
    ffr = fringe_fn(FR_LOCKS)
    # 앞머리 아랫선 위로는 얼굴 창에서 잘라낸다
    fw = {}
    for y, ra in face.items():
        segs = []
        for (a, b) in ra:
            run = None
            for x in range(a, b + 1):
                inside = y > ffr(x)
                if inside and run is None:
                    run = x
                elif not inside and run is not None:
                    segs.append((run, x - 1))
                    run = None
            if run is not None:
                segs.append((run, b))
        if segs:
            fw[y] = segs
    hair = rsub(head, fw)

    c.blit(head, 's', Z_HEAD)          # 두개골 전부 살결로 깔고
    c.blit(hair, 'h', Z_HAIR)          # 머리카락을 위에 덮는다
    return head, fw, hair


def face_feat(c, girl, side=False):
    """눈·코·입·볼.  얼굴 폭의 1/3 씩 되는 또렷한 중간 크기 눈."""
    if side:
        return
    ew = 12.5 if not girl else 13.0     # 반폭
    eh = 10.5 if not girl else 11.0     # 반높이
    for sgn in (-1, 1):
        cx = 95.5 + sgn * EGAP
        eye(c, cx, EY, ew, eh, girl)
        brow(c, cx, sgn, girl)
    nose_front(c, 95.5)
    mouth(c, 95.5, girl)
    # 볼 홍조 — 눈 **아래**
    for sgn in (-1, 1):
        c.ell(95.5 + sgn * 27, 98.0, 8.0, 4.2, 'c', 91, only='sld')


def eye(c, cx, cy, ew, eh, girl):
    z = 90
    c.ell(cx, cy, ew, eh, 'X', z, only='sldcL')
    c.ell(cx, cy + eh * 0.12, ew * 0.68, eh * 0.93, 'e', z, only='X')
    c.ell(cx, cy + eh * 0.26, ew * 0.33, eh * 0.46, 'o', z, only='eX')
    # 윗 속눈썹 — 눈 윗변을 따라 두툼하게
    for x in range(int(cx - ew) - 1, int(cx + ew) + 2):
        u = (x - cx) / ew
        if abs(u) > 1.06:
            continue
        top = cy - eh * math.sqrt(max(0.0, 1.0 - min(1.0, u * u)))
        th = 3.2 + 1.5 * max(0.0, u * (1 if cx > 95.5 else -1))
        for y in range(int(math.floor(top)) - 1, int(top + th) + 1):
            if y >= top - 1.2:
                c.put(x, y, 'o', z, only='XeosldcL')
    # 아래 눈꺼풀 한 줄
    for x in range(int(cx - ew), int(cx + ew) + 1):
        u = (x - cx) / ew
        if abs(u) > 1.0:
            continue
        bot = cy + eh * math.sqrt(max(0.0, 1.0 - u * u))
        c.put(x, int(bot), 'd', z, only='Xe')
    # 반사점 — 큰 것은 빛이 오는 왼쪽 위, 작은 것은 반대편 아래
    c.ell(cx - ew * 0.40, cy - eh * 0.36, ew * 0.29, eh * 0.30, 'X', z, only='eo')
    c.ell(cx + ew * 0.42, cy + eh * 0.40, ew * 0.15, eh * 0.16, 'X', z, only='eo')


def brow(c, cx, sgn, girl):
    """짧고 평평하게.  길고 두껍게 안쪽으로 기울이면 화난 얼굴이 된다."""
    y0 = 64.5 if not girl else 63.5
    a = cx - sgn * 9.0
    b = cx + sgn * 9.5
    c.stroke([(a, y0 + 1.4), (cx - sgn * 2, y0 - 0.6), (cx + sgn * 5, y0 - 0.4),
              (b, y0 + 1.2)], 'j', 92, w=3.6 if not girl else 3.0,
             only='sldcLX', taper=0.45)


def nose_front(c, cx):
    c.ell(cx - 0.5, 97.5, 2.6, 2.2, 'd', 91, only='sl')
    c.put(int(cx - 2), 99, 'S', 91, only='sld')
    c.put(int(cx + 1), 99, 'S', 91, only='sld')


def mouth(c, cx, girl):
    y = 105 if not girl else 104
    wd = 5.0 if not girl else 4.2
    c.stroke([(cx - wd, y - 0.6), (cx, y + 1.6), (cx + wd, y - 0.6)],
             'e', 93, w=2.6, only='sldcL', taper=0.55)
    c.stroke([(cx - wd * 0.55, y + 1.6), (cx, y + 2.6), (cx + wd * 0.55, y + 1.6)],
             'w', 93, w=1.8, only='sldc', taper=0.5)
    c.stroke([(cx - wd * 0.5, y + 3.2), (cx, y + 3.6), (cx + wd * 0.5, y + 3.2)],
             'c', 93, w=1.6, only='sld', taper=0.6)


# ================================================================ 몸 (정면)
def body_front(c, girl):
    parts = {}
    # --- 목 -----------------------------------------------------------
    nk = sym(104, 134, [(104, 16), (110, 15), (118, 14), (126, 15), (134, 17)]
             if not girl else
             [(104, 14), (110, 13), (118, 12), (126, 13), (134, 15)])
    c.blit(nk, 's', Z_NECK)
    parts['neck'] = nk

    sh = 46 if not girl else 43
    # --- 바지 / 치마 ----------------------------------------------------
    if not girl:
        hip = sym(196, 228, [(196, 35), (202, 37), (210, 37), (220, 36),
                             (228, 34)])
        lg1 = tube(226, 258, [(226, 75), (240, 74), (252, 74), (258, 74)],
                   [(226, 17), (240, 16), (252, 15), (258, 14.5)])
        lg2 = mirror(lg1)
        pant = rmerge(hip, lg1, lg2)
        c.blit(pant, 'p', Z_PANT)
        parts['pant'] = pant
        # --- 장화 -------------------------------------------------------
        bt = band(246, 286,
                  [(246, 61), (256, 60), (264, 58), (271, 55), (278, 53),
                   (283, 53), (286, 56)],
                  [(246, 92), (256, 93), (265, 94), (273, 95), (281, 95),
                   (286, 92)])
        boots = rmerge(bt, mirror(bt))
        c.blit(boots, 'b', Z_SHOE)
        parts['shoe'] = boots
    else:
        skirt = sym(192, 238, [(192, 34), (198, 37), (206, 42), (216, 47),
                               (226, 51), (233, 53), (238, 54)])
        c.blit(skirt, 'p', Z_PANT)
        parts['pant'] = skirt
        lg1 = tube(230, 272, [(230, 80), (250, 79), (272, 79)],
                   [(230, 14), (248, 13), (264, 12), (272, 12)])
        legs = rmerge(lg1, mirror(lg1))
        c.blit(legs, 's', Z_LEG)
        parts['leg'] = legs
        sh1 = band(266, 286,
                   [(266, 66), (274, 64), (280, 63), (286, 65)],
                   [(266, 92), (274, 94), (281, 95), (286, 92)])
        shoes = rmerge(sh1, mirror(sh1))
        c.blit(shoes, 'b', Z_SHOE)
        parts['shoe'] = shoes

    # --- 윗도리 --------------------------------------------------------
    hem = 204 if not girl else 198
    tor = sym(124, hem, [(124, 21), (128, 29), (133, 34), (140, 36),
                         (152, 35), (168, 35), (184, 36), (196, 38),
                         (hem, 38)] if not girl else
              [(124, 19), (128, 27), (133, 32), (140, 34), (152, 33),
               (166, 32), (180, 33), (190, 35), (hem, 36)])
    c.blit(tor, 't', Z_SHIRT)
    parts['shirt'] = tor

    # --- 팔 (소매 + 팔뚝 + 손) -------------------------------------------
    acx = [(124, 96 - sh + 12), (132, 96 - sh + 11), (146, 96 - sh + 10),
           (168, 96 - sh + 10), (190, 96 - sh + 11), (208, 96 - sh + 12)]
    arr = [(124, 11.5), (129, 12.8), (138, 12.6), (152, 11.6), (166, 10.6),
           (178, 9.8), (186, 10.8), (196, 12.0), (204, 11.2), (208, 8.5)]
    cuff = 164 if not girl else 160
    arm1 = tube(124, cuff, acx, arr)
    fore1 = tube(cuff + 1, 208, acx, arr)
    c.blit(arm1, 't', Z_ARM)
    c.blit(mirror(arm1), 't', Z_ARM)
    c.blit(fore1, 's', Z_HAND)
    c.blit(mirror(fore1), 's', Z_HAND)
    parts['sleeve'] = rmerge(arm1, mirror(arm1))
    parts['hand'] = rmerge(fore1, mirror(fore1))
    return parts


# ================================================================ 몸 (3/4)
# 오른쪽을 비스듬히 본다.  가까운 쪽 = 화면 왼쪽, 먼 쪽 = 화면 오른쪽.
def body_side(c, girl):
    """오른쪽을 비스듬히 본 몸.  정면을 옆으로 민 것이 되면 실패다.
    · 어깨 폭이 정면의 0.85 로 줄고 가까운(왼) 어깨가 한 줄 늦게 더 벌어진다
    · 가까운 팔·다리는 크고 밝고 앞에, 먼 쪽은 작고 어둡고 뒤에
    · 두 다리가 겹쳐 사이가 없다.  발끝이 둘 다 오른쪽을 본다
    """
    parts = {}
    # 목은 턱보다 뒤(왼)쪽에 붙는다
    nk = band(102, 134, [(102, 80), (116, 79), (126, 80), (134, 81)],
              [(102, 108), (116, 106), (126, 107), (134, 109)])
    c.blit(nk, 's', Z_NECK)
    parts['neck'] = nk

    # --- 먼 쪽 팔 (뒤, 작고 어둡다) --------------------------------------
    fcx = [(124, 126), (140, 127), (166, 128), (190, 128), (208, 127)]
    frr = [(124, 9.4), (130, 10.6), (142, 10.4), (158, 9.6), (172, 8.8),
           (184, 9.4), (194, 10.4), (203, 9.6), (208, 7.0)]
    fcuff = 162 if not girl else 158
    fa = tube(124, fcuff, fcx, frr)
    ff = tube(fcuff + 1, 204, fcx, frr)
    c.blit(fa, 't', Z_FARARM)
    c.blit(ff, 's', Z_FARARM + 1)
    parts['fararm'] = rmerge(fa, ff)
    parts['farhand'] = ff

    if not girl:
        hip = band(196, 224, [(196, 66), (206, 64), (214, 65), (224, 67)],
                   [(196, 122), (206, 124), (214, 123), (224, 120)])
        far = tube(206, 254, [(206, 106), (232, 106), (254, 105)],
                   [(206, 15.5), (232, 13.5), (254, 12.5)])
        nearl = tube(206, 258, [(206, 83), (234, 81), (258, 81)],
                     [(206, 17.5), (234, 15.5), (258, 14.5)])
        c.blit(rmerge(hip, far), 'p', Z_PANT)
        c.blit(nearl, 'p', Z_PANT + 1)
        parts['pant'] = rmerge(hip, far, nearl)
        parts['farleg'] = {y: v for y, v in far.items() if y >= 216}
        # 발끝이 오른쪽을 본다.  먼 발은 위에서 끝나 뒤로 물러난다
        fb = band(244, 280, [(244, 92), (258, 91), (268, 91), (276, 92), (280, 95)],
                  [(244, 119), (256, 124), (266, 129), (274, 132), (280, 129)])
        nb = band(246, 286, [(246, 66), (260, 65), (270, 65), (280, 66), (286, 69)],
                  [(246, 97), (258, 102), (270, 108), (280, 112), (286, 109)])
        c.blit(fb, 'b', Z_SHOE)
        c.blit(nb, 'b', Z_SHOE + 1)
        parts['shoe'] = rmerge(fb, nb)
    else:
        skirt = band(192, 234, [(192, 68), (200, 64), (212, 59), (224, 55), (234, 52)],
                     [(192, 122), (200, 126), (212, 130), (224, 134), (234, 137)])
        c.blit(skirt, 'p', Z_PANT)
        parts['pant'] = skirt
        far = tube(226, 266, [(226, 105), (248, 105), (266, 104)],
                   [(226, 12.5), (248, 11.5), (266, 10.5)])
        nearl = tube(226, 272, [(226, 83), (250, 82), (272, 82)],
                     [(226, 13.5), (250, 12.5), (272, 11.5)])
        c.blit(far, 's', Z_LEG)
        c.blit(nearl, 's', Z_LEG + 1)
        parts['leg'] = rmerge(far, nearl)
        parts['farleg'] = far
        fs = band(258, 278, [(258, 93), (268, 92), (278, 95)],
                  [(258, 117), (268, 122), (278, 119)])
        ns = band(264, 286, [(264, 70), (274, 69), (286, 72)],
                  [(264, 95), (274, 101), (286, 98)])
        c.blit(fs, 'b', Z_SHOE)
        c.blit(ns, 'b', Z_SHOE + 1)
        parts['shoe'] = rmerge(fs, ns)

    hem = 204 if not girl else 198
    # 가까운(왼) 어깨가 한 줄 늦게 더 멀리 벌어진다
    tor = band(124, hem,
               [(124, 82), (129, 72), (135, 66), (142, 64), (156, 65),
                (174, 66), (190, 67), (hem, 68)],
               [(123, 110), (127, 119), (132, 125), (138, 127), (152, 127),
                (168, 126), (186, 127), (hem, 128)]) if not girl else band(
        124, hem,
        [(124, 84), (129, 75), (135, 69), (142, 67), (156, 68), (174, 69),
         (190, 70), (hem, 71)],
        [(123, 108), (127, 117), (132, 122), (138, 124), (152, 124),
         (168, 123), (186, 124), (hem, 125)])
    c.blit(tor, 't', Z_SHIRT)
    parts['shirt'] = tor

    cuff = 164 if not girl else 160
    ncx = [(124, 66), (132, 62), (148, 61), (168, 62), (188, 64), (208, 65)]
    nrr = [(124, 12.0), (130, 13.4), (140, 13.2), (154, 12.2), (168, 11.2),
           (178, 10.6), (188, 11.8), (198, 12.8), (205, 11.6), (208, 8.5)]
    na = tube(124, cuff, ncx, nrr)
    nf = tube(cuff + 1, 208, ncx, nrr)
    c.blit(na, 't', Z_ARM)
    c.blit(nf, 's', Z_HAND)
    parts['sleeve'] = na
    parts['hand'] = nf
    return parts


# ================================================================ 몸 (뒤)
def body_back(c, girl):
    parts = {}
    nk = sym(100, 134, [(100, 17), (110, 16), (120, 15), (128, 16), (134, 18)]
             if not girl else
             [(100, 15), (110, 14), (120, 13), (128, 14), (134, 16)])
    c.blit(nk, 's', Z_NECK)
    parts['neck'] = nk

    sh = 46 if not girl else 43
    if not girl:
        hip = sym(196, 228, [(196, 35), (202, 37), (210, 37), (220, 36),
                             (228, 34)])
        lg1 = tube(226, 258, [(226, 75), (240, 74), (252, 74), (258, 74)],
                   [(226, 17), (240, 16), (252, 15), (258, 14.5)])
        pant = rmerge(hip, lg1, mirror(lg1))
        c.blit(pant, 'p', Z_PANT)
        parts['pant'] = pant
        bt = band(246, 286,
                  [(246, 62), (256, 61), (265, 60), (273, 59), (281, 59), (286, 61)],
                  [(246, 91), (256, 92), (265, 93), (273, 93), (281, 93), (286, 90)])
        boots = rmerge(bt, mirror(bt))
        c.blit(boots, 'b', Z_SHOE)
        parts['shoe'] = boots
    else:
        skirt = sym(192, 238, [(192, 34), (198, 37), (206, 42), (216, 47),
                               (226, 51), (233, 53), (238, 54)])
        c.blit(skirt, 'p', Z_PANT)
        parts['pant'] = skirt
        lg1 = tube(230, 272, [(230, 80), (250, 79), (272, 79)],
                   [(230, 14), (248, 13), (264, 12), (272, 12)])
        legs = rmerge(lg1, mirror(lg1))
        c.blit(legs, 's', Z_LEG)
        parts['leg'] = legs
        sh1 = band(266, 286, [(266, 65), (274, 64), (280, 63), (286, 65)],
                   [(266, 93), (274, 94), (281, 95), (286, 92)])
        shoes = rmerge(sh1, mirror(sh1))
        c.blit(shoes, 'b', Z_SHOE)
        parts['shoe'] = shoes

    hem = 204 if not girl else 198
    tor = sym(124, hem, [(124, 21), (128, 29), (133, 34), (140, 36),
                         (152, 35), (168, 35), (184, 36), (196, 38), (hem, 38)]
              if not girl else
              [(124, 19), (128, 27), (133, 32), (140, 34), (152, 33),
               (166, 32), (180, 33), (190, 35), (hem, 36)])
    c.blit(tor, 't', Z_SHIRT)
    parts['shirt'] = tor

    acx = [(124, 96 - sh + 12), (132, 96 - sh + 11), (146, 96 - sh + 10),
           (168, 96 - sh + 10), (190, 96 - sh + 11), (208, 96 - sh + 12)]
    arr = [(124, 11.5), (129, 12.8), (138, 12.6), (152, 11.6), (166, 10.6),
           (178, 9.8), (186, 10.8), (196, 12.0), (204, 11.2), (208, 8.5)]
    cuff = 164 if not girl else 160
    arm1 = tube(124, cuff, acx, arr)
    fore1 = tube(cuff + 1, 208, acx, arr)
    c.blit(arm1, 't', Z_ARM)
    c.blit(mirror(arm1), 't', Z_ARM)
    c.blit(fore1, 's', Z_HAND)
    c.blit(mirror(fore1), 's', Z_HAND)
    parts['sleeve'] = rmerge(arm1, mirror(arm1))
    parts['hand'] = rmerge(fore1, mirror(fore1))
    return parts


# ================================================================ 옷 주름
def folds_shirt(c, girl, view, hem):
    """스타듀밸리 계열 — 주름이 많다.  높이를 어긋나게 둔다."""
    z = Z_SHIRT
    if view == 'side':
        cx = 96
        col = [(72, 146, 178), (84, 152, 190), (96, 140, 186),
               (108, 150, 180), (118, 144, 170)]
    else:
        cx = 96
        col = [(74, 148, 184), (84, 142, 192), (96, 152, 178),
               (106, 146, 190), (116, 140, 182)]
    for k, (x, y0, y1) in enumerate(col):
        if y1 > hem - 4:
            y1 = hem - 4
        dx = 1.6 if k % 2 else -1.4
        c.stroke([(x, y0), (x + dx, (y0 + y1) / 2.0), (x + dx * 0.4, y1)],
                 'u', z, w=2.2 + 0.5 * (k % 3), only='tTu', taper=0.85)
        c.stroke([(x + 3, y0 + 5), (x + 3 + dx, (y0 + y1) / 2.0 + 3)],
                 'T', z, w=1.8, only='tu', taper=0.8)
    # 옷단 위 접힘
    for k in range(4):
        x0 = cx - 30 + k * 18 + (3 if k % 2 else -2)
        c.stroke([(x0, hem - 12 - 2 * (k % 2)), (x0 + 6, hem - 6)],
                 'u', z, w=2.2, only='tT', taper=0.8)
    # 옷단 그늘
    for y in range(hem - 3, hem + 1):
        for x in range(0, W):
            if c.g[y][x] in 'tT' and c.z[y][x] == z:
                c.g[y][x] = 'u'


def folds_sleeve(c, rows, cuff):
    for y, ra in rows.items():
        if cuff - 5 <= y <= cuff:
            for (a, b) in ra:
                for x in range(a, b + 1):
                    if c.g[y][x] in 'tT':
                        c.g[y][x] = 'u'
    ys = sorted(rows.keys())
    if not ys:
        return
    for (a, b) in rows[ys[0] + 18]:
        mid = (a + b) // 2
        c.stroke([(mid - 3, ys[0] + 8), (mid - 2, ys[0] + 22)], 'u', Z_ARM,
                 w=2.0, only='tT', taper=0.85)
        c.stroke([(mid + 3, ys[0] + 12), (mid + 4, ys[0] + 26)], 'u', Z_ARM,
                 w=1.8, only='tT', taper=0.85)


def folds_pants(c, girl, view, parts):
    z = Z_PANT
    pant = parts.get('pant', {})
    ys = sorted(pant.keys())
    if not ys:
        return
    top = ys[0]
    # 허리띠 — 두께를 일정하게 두지 않는다
    for y in range(top + 2, top + 9):
        for x in range(W):
            if c.g[y][x] in 'pP' and c.z[y][x] in (z, z + 1):
                c.g[y][x] = 'q' if y < top + 7 + int(0.8 * math.sin(x * 0.1)) else 'p'
    if girl:
        # 치마 주름 — 좌우 대칭이면 무늬가 된다.  높이를 어긋나게
        base = [(-44, 232, 0), (-30, 236, 4), (-17, 230, -3), (-4, 237, 2),
                (9, 231, -2), (22, 236, 3), (35, 229, -4), (46, 234, 1)]
        for k, (dx, ybot, dy) in enumerate(base):
            x0 = 96 + dx * (0.55 if view == 'side' else 1.0)
            if view == 'side':
                x0 = 96 + dx * 0.8 + 4
            y0 = 206 + (k % 3) * 4
            c.stroke([(x0 * 1.0, y0), (x0 + dx * 0.10, ybot + dy)],
                     'q', z, w=2.4 + 0.6 * (k % 2), only='pPq', taper=0.75)
            if k % 2 == 0:
                c.stroke([(x0 + 4, y0 + 6), (x0 + 4 + dx * 0.08, ybot + dy - 4)],
                         'P', z, w=2.0, only='pq', taper=0.8)
    else:
        # 무릎 접힘 + 주머니
        kn = 236
        for sgn in (-1, 1):
            cxx = 96 + sgn * 17
            if view == 'side':
                cxx = 84 if sgn < 0 else 108
            c.stroke([(cxx - 9, kn - 4), (cxx, kn + 2), (cxx + 9, kn - 3)],
                     'q', z, w=2.4, only='pP', taper=0.8)
            c.stroke([(cxx - 8, kn + 7), (cxx + 1, kn + 11), (cxx + 8, kn + 6)],
                     'q', z, w=2.0, only='pP', taper=0.85)
            c.stroke([(cxx - 10, 214), (cxx - 11, 226)], 'q', z, w=2.0,
                     only='pP', taper=0.7)
        c.stroke([(96, 222), (96, 232)], 'q', z, w=2.2, only='pP', taper=0.7)


# ================================================================ 머리카락 결
def hair_strands(c, view, girl):
    z = Z_HAIR
    if view == 'up':
        st = [[(70, 26), (66, 44)], [(88, 20), (84, 40)],
              [(105, 24), (110, 43)], [(121, 32), (127, 50)],
              [(78, 52), (75, 72)], [(113, 56), (117, 76)]]
        if girl:
            st += [[(80, 104), (76, 128)], [(103, 112), (107, 134)],
                   [(90, 140), (87, 166)], [(112, 150), (114, 174)],
                   [(97, 122), (96, 142)], [(84, 176), (82, 196)]]
    elif view == 'side':
        st = [[(74, 26), (68, 42)], [(92, 20), (88, 37)],
              [(110, 22), (115, 38)], [(128, 30), (133, 45)]]
    else:
        st = [[(70, 24), (65, 41)], [(86, 18), (82, 35)],
              [(104, 20), (109, 37)], [(122, 28), (127, 44)]]
    for k, p in enumerate(st):
        c.stroke(p, 'j', z, w=2.6 + 0.6 * (k % 2), only='hH', taper=0.85)
    # 정수리 하이라이트 — 왼쪽 위
    if view == 'up':
        c.ell(76, 36, 19, 11, 'H', z, only='h')
        c.ell(72, 32, 9, 5, 'y', z, only='H')
    else:
        c.ell(74, 34, 17, 10, 'H', z, only='h')
        c.ell(70, 31, 8, 4.5, 'y', z, only='H')


# ================================================================ 머리 (뒤)
def head_back(c, girl):
    head = sym(14, 116 if not girl else 110, HEAD_W)
    if girl:
        # 목덜미에서 한 번 모였다가 등에서 퍼진다.  머리만큼 넓은 채로
        # 곧장 내려오면 어깨가 통째로 묻혀 소매가 허공에 뜬 판때기가 된다.
        long_ = sym(96, 212, [(96, 34), (104, 29), (112, 26), (124, 28),
                              (136, 31), (150, 38), (166, 44), (180, 46),
                              (193, 43), (202, 33), (208, 19), (212, 6)])
        # 등을 덮어 윗도리가 거의 안 보인다.  목보다 앞이어야 목덜미에
        # 살색 구멍이 안 뚫린다.  팔보다는 뒤.
        c.blit(long_, 'h', Z_BACK2)
        c.blit(head, 'h', Z_HAIR)
        return rmerge(head, long_)
    # 남자 뒷머리 — 목덜미가 물결친다
    nape = {}
    f = fringe_fn([(54, 18, 92, 10), (70, 15, 95, 11), (85, 14, 93, 12),
                   (100, 16, 96, 10), (114, 14, 93, 12), (128, 16, 94, 9),
                   (142, 16, 90, 8)], 88.0)
    for y, ra in head.items():
        for (a, b) in ra:
            seg = []
            run = None
            for x in range(a, b + 1):
                ok = y <= f(x)
                if ok and run is None:
                    run = x
                elif not ok and run is not None:
                    seg.append((run, x - 1))
                    run = None
            if run is not None:
                seg.append((run, b))
            if seg:
                nape.setdefault(y, []).extend(seg)
    c.blit(nape, 'h', Z_HAIR)
    return nape


# ================================================================ 머리 (3/4)
SHEAD_L = [(14, 82), (17, 72), (21, 64), (26, 58), (32, 53), (40, 50),
           (50, 48), (62, 48), (74, 49), (84, 51), (92, 55), (98, 60),
           (103, 66), (107, 73), (110, 80), (113, 89), (115, 96)]
# 오른쪽 = 얼굴 앞.  코는 두 줄짜리 작은 언덕이고 턱은 둥글게 말린다
SHEAD_R = [(14, 110), (18, 121), (23, 130), (29, 135), (36, 139), (45, 141),
           (56, 142), (66, 141), (75, 139), (83, 137), (89, 135), (94, 134),
           (98, 137), (101, 138), (104, 135), (107, 131), (110, 125),
           (112, 118), (114, 110), (115, 104)]
SFACE_L = [(48, 76), (58, 74), (70, 73), (82, 73), (92, 74), (98, 76),
           (103, 79), (107, 82), (110, 85), (113, 91), (115, 96)]


def head_side(c, girl):
    head = band(14, 116, SHEAD_L, SHEAD_R)
    fr = fringe_fn(SFR_LOCKS)
    fl = spline(SFACE_L)
    frr = spline(SHEAD_R)
    fw = {}
    for y in range(46, 117):
        ra = head.get(y)
        if not ra:
            continue
        a = max(ra[0][0], int(round(fl(y))))
        b = ra[-1][1] if y >= 70 else min(ra[-1][1], int(round(frr(y))) - 3)
        seg = []
        run = None
        for x in range(a, b + 1):
            ok = y > fr(x)
            if ok and run is None:
                run = x
            elif not ok and run is not None:
                seg.append((run, x - 1))
                run = None
        if run is not None:
            seg.append((run, b))
        if seg:
            fw[y] = seg
    hair = rsub(head, fw)
    c.blit(head, 's', Z_HEAD)
    c.blit(hair, 'h', Z_HAIR)
    if girl:
        # 먼 쪽(오른쪽)이 길게 흐르고 가까운 쪽은 짧은 한 갈래
        # 뒤통수에서 등으로 흘러내리는 큰 덩어리 — 머리 뒤에 숨었다가
        # 턱 밑에서 좌우로 빠져나온다 (팔보다 뒤)
        bk = band(54, 208, [(54, 48), (80, 44), (112, 42), (142, 43),
                            (170, 46), (190, 52), (202, 60), (208, 72)],
                  [(54, 118), (80, 126), (112, 132), (142, 136), (170, 134),
                   (190, 126), (202, 110), (208, 84)])
        c.blit(bk, 'h', Z_BACKHAIR)
        # 먼 쪽(오른쪽)이 어깨 앞으로 길게 흐른다.  턱 아래에서 시작해야
        # 뺨을 덮지 않는다
        lf = band(117, 196, [(117, 120), (134, 126), (158, 128), (176, 126),
                             (190, 121), (196, 115)],
                  [(117, 137), (134, 144), (158, 145), (176, 141),
                   (190, 130), (196, 115)])
        c.blit(lf, 'h', Z_LOCK)
        # 가까운 쪽은 짧은 한 갈래만 — 길면 앞팔을 통째로 먹는다
        lock = band(84, 128, [(84, 50), (102, 48), (118, 49), (126, 52), (128, 56)],
                    [(84, 66), (102, 64), (118, 61), (126, 58), (128, 56)])
        c.blit(lock, 'h', Z_LOCK)
        hair = rmerge(hair, lf, bk, lock)
    return head, fw, hair


def face_side(c, girl):
    """이목구비가 돌아선 쪽으로 몰린다.  먼 눈은 눌려 좁다."""
    z = 90
    nearx, farx = 90.0, 126.0
    ew = 12.0 if not girl else 12.5
    eh = 10.5 if not girl else 11.0
    eye(c, nearx, EY, ew, eh, girl)
    eye(c, farx, EY - 0.5, ew * 0.66, eh * 0.94, girl)
    c.stroke([(nearx - 9, 65.9), (nearx - 2, 63.7), (nearx + 5, 63.9),
              (nearx + 9.5, 65.3)], 'j', 92, w=3.4 if not girl else 2.9,
             only='sldcLX', taper=0.45)
    c.stroke([(farx - 6.5, 65.1), (farx - 1, 63.3), (farx + 4, 63.5),
              (farx + 6.5, 64.9)], 'j', 92, w=3.2 if not girl else 2.8,
             only='sldcLX', taper=0.45)
    # 코 — 실루엣을 살짝 밀고 나간다
    c.stroke([(128, 92), (134, 97), (138, 101), (134, 103)], 'd', 91,
             w=3.0, only='sl', taper=0.5)
    c.put(136, 102, 'S', 91, only='sld')
    c.put(135, 103, 'S', 91, only='sld')
    mouth(c, 120.0, girl)
    c.ell(87, 98.5, 8.0, 4.2, 'c', 91, only='sld')
    c.ell(126, 96.5, 5.0, 3.2, 'c', 91, only='sld')
    # 귀 (가까운 쪽) — 머리카락 밖으로 살짝 나온다
    c.ell(70, 86, 6.0, 8.5, 'S', Z_EAR)
    c.ell(70, 86, 4.4, 7.0, 's', Z_EAR, only='S')
    c.ell(71, 87, 2.2, 4.2, 'd', Z_EAR, only='s')
    c.ell(68, 82, 2.0, 2.6, 'l', Z_EAR, only='s')


# ================================================================ 조립
def build(sex, view):
    c = Canvas()
    girl = (sex == 'girl')

    if view == 'down':
        parts = body_front(c, girl)
        if girl:
            # 긴 머리는 팔 **뒤로** 흘러 어깨를 덮는다.  앞으로 덮으면
            # 팔이 통째로 먹혀 머리 망토가 된다.
            back = sym(58, 206, [(58, 46), (74, 48), (92, 50), (112, 51),
                                 (134, 51), (156, 50), (174, 47), (190, 42),
                                 (199, 33), (203, 22), (206, 11)])
            c.blit(back, 'h', Z_BACKHAIR)
        head, fw, hair = head_front(c, girl)
        if girl:
            # 귀 앞으로 내려오는 얇은 한 갈래 (좌우 길이를 어긋나게)
            lk = band(70, 170, [(70, 45), (100, 43), (132, 43), (154, 46),
                                (165, 51), (170, 57)],
                      [(70, 57), (100, 56), (132, 56), (154, 57), (165, 57),
                       (170, 57)])
            rk = band(70, 152, [(70, 134), (100, 135), (128, 136), (143, 138),
                                (152, 142)],
                      [(70, 146), (100, 148), (128, 149), (143, 146),
                       (152, 142)])
            c.blit(lk, 'h', Z_LOCK)
            c.blit(rk, 'h', Z_LOCK)
            hair = rmerge(hair, back, lk, rk)
    elif view == 'side':
        parts = body_side(c, girl)
        head, fw, hair = head_side(c, girl)
    else:
        parts = body_back(c, girl)
        hair = head_back(c, girl)
        fw = {}

    # ---------------- 음영 -------------------------------------------
    # 팔을 따로 rim 하면 소매가 통째로 밝아져 덧댄 판때기가 된다.
    # 윗몸 전체를 한 덩어리로 보고 띠를 두른 뒤, 팔 **안쪽**에만 그늘을 더한다.
    hem = 204 if not girl else 198
    body_z = {Z_SHIRT, Z_ARM, Z_HAND, Z_NECK}
    upper = rmerge(parts['shirt'], parts['sleeve'], parts['hand'])
    rim(c, upper, body_z, (3.6, 1.8, 0.4), (5.0, 2.4, 1.9))
    inner_shadow(c, parts['sleeve'], {Z_ARM}, 3.2, 'u')
    inner_shadow(c, parts['hand'], {Z_HAND}, 2.6, 'd')
    if 'fararm' in parts:
        for y, ra in parts['fararm'].items():
            for (a, b) in ra:
                for x in range(a, b + 1):
                    if c.z[y][x] in (Z_FARARM, Z_FARARM + 1):
                        if c.g[y][x] in 'tT':
                            c.g[y][x] = 'u'
                        elif c.g[y][x] in 'sl':
                            c.g[y][x] = 'd'
    if 'farleg' in parts:
        # 먼 쪽은 어둡고 작고 뒤에.  안 그러면 두 다리가 한 덩어리가 된다
        for y, ra in parts['farleg'].items():
            for (a, b) in ra:
                for x in range(a, b + 1):
                    if c.z[y][x] in (Z_PANT, Z_LEG):
                        if c.g[y][x] in 'pP':
                            c.g[y][x] = 'q'
                        elif c.g[y][x] in 'sl':
                            c.g[y][x] = 'd'
    lowz = {Z_PANT, Z_PANT + 1, Z_LEG, Z_LEG + 1, Z_SHOE, Z_SHOE + 1}
    low = rmerge(parts['pant'], parts.get('leg', {}), parts['shoe'])
    rim(c, low, lowz, (4.2, 2.0, 1.2), (5.4, 2.4, 0.3))
    if 'leg' in parts:
        inner_shadow(c, parts['leg'], {Z_LEG, Z_LEG + 1}, 3.0, 'd')
    rim(c, parts['shoe'], {Z_SHOE, Z_SHOE + 1}, (2.6, 1.2, 0.5), (3.6, 1.6, 2.6))
    rim(c, hair, {Z_HAIR, Z_BACKHAIR, Z_BACK2, Z_LOCK}, (5.0, 2.4, 0.2), (6.0, 2.8, 1.5))
    if view != 'up':
        rim(c, {y: v for y, v in fw.items()}, {Z_HEAD},
            (3.0, 1.4, 2.4), (4.2, 1.8, 0.9))

    # 목 그늘 — 턱이 드리운다.  줄마다 **보이는** 맨 윗칸부터 재야 한다.
    # 덩어리의 맨 윗줄부터 재면 머리에 가린 만큼이 다 빠져 그늘이 사라진다.
    nk = parts['neck']
    tops = {}
    for y in sorted(nk.keys()):
        for (a, b) in nk[y]:
            for x in range(a, b + 1):
                if c.z[y][x] == Z_NECK and x not in tops:
                    tops[x] = y
    for y, ra in nk.items():
        for (a, b) in ra:
            for x in range(a, b + 1):
                if c.z[y][x] != Z_NECK or x not in tops:
                    continue
                dep = 6.5 + 2.2 * math.sin((x - 95.5) * 0.085 + 0.6)
                k = y - tops[x]
                if k < dep * 0.55:
                    c.g[y][x] = 'm'
                elif k < dep:
                    c.g[y][x] = 'd'
    if view != 'up':
        face_shade_generic(c, fw, view)

    # ---------------- 주름 --------------------------------------------
    folds_shirt(c, girl, view, hem)
    folds_sleeve(c, parts['sleeve'], 164 if not girl else 160)
    folds_pants(c, girl, view, parts)
    hair_strands(c, view, girl)

    # 옷깃 / 소매단 / 장화 접힘
    collar(c, girl, view)
    cuff = 164 if not girl else 160
    hands(c, parts, view, cuff)
    if 'shoe' in parts:
        boot_detail(c, girl, view, parts)

    # 팔이 드리우는 그림자 — 없으면 소매가 머리카락 위에 뜬 판때기가 된다
    if view == 'up' and girl:
        for y, ra in parts['sleeve'].items():
            for (a, b) in ra:
                for dx in range(1, 5):
                    for x in (a - dx, b + dx):
                        if 0 <= x < W and c.z[y][x] in (Z_BACK2, Z_BACKHAIR) \
                                and c.g[y][x] in 'hH':
                            c.g[y][x] = 'j'
        for y, ra in parts['hand'].items():
            for (a, b) in ra:
                for dx in range(1, 4):
                    for x in (a - dx, b + dx):
                        if 0 <= x < W and c.z[y][x] in (Z_BACK2, Z_BACKHAIR) \
                                and c.g[y][x] in 'hH':
                            c.g[y][x] = 'j'

    # ---------------- 윤곽 --------------------------------------------
    outline(c, 2)

    # ---------------- 얼굴 --------------------------------------------
    if view == 'down':
        face_feat(c, girl)
    elif view == 'side':
        face_side(c, girl)
    return c


def face_shade_generic(c, fw, view):
    fr = fringe_fn(SFR_LOCKS if view == 'side' else FR_LOCKS)
    for y, ra in fw.items():
        for (a, b) in ra:
            for x in range(a, b + 1):
                if c.z[y][x] != Z_HEAD:
                    continue
                top = fr(x)
                dep = 6.0 + 2.2 * math.sin(x * 0.13 + 0.7)
                if y - top < dep:
                    c.g[y][x] = 'd'
                elif y - top < dep + 3.0 and c.g[y][x] == 'l':
                    c.g[y][x] = 's'
    if view == 'down':
        c.ell(78, 76, 14, 8, 'l', Z_HEAD, only='s')
        c.ell(113, 74, 10, 6, 'l', Z_HEAD, only='s')
    else:
        c.ell(86, 76, 13, 8, 'l', Z_HEAD, only='s')
        c.ell(122, 74, 8, 5, 'l', Z_HEAD, only='s')


def hands(c, parts, view, cuff):
    """손목 주름 한 줄 + 손가락 금 두 줄.  두꺼운 가로 띠를 두르면
    팔에 팔찌를 끼운 꼴이 되고, 금이 길면 글자처럼 보인다."""
    hd = parts.get('hand', {})
    if not hd:
        return
    wy = cuff + 20
    for (a, b) in hd.get(wy, []):
        m = (a + b) / 2.0
        hw = (b - a) / 2.0
        c.stroke([(m - hw * 0.6, wy - 0.8), (m, wy + 0.8), (m + hw * 0.6, wy - 0.6)],
                 'd', Z_HAND, w=1.8, only='sl', taper=0.6)
    for (a, b) in hd.get(wy + 12, []):
        m = (a + b) / 2.0
        c.stroke([(m - 0.4, wy + 8), (m - 1.2, wy + 16)], 'd', Z_HAND,
                 w=1.5, only='sl', taper=0.85)
        c.stroke([(m + 4.2, wy + 9.5), (m + 3.6, wy + 15.5)], 'd', Z_HAND,
                 w=1.4, only='sl', taper=0.85)


def collar(c, girl, view):
    z = Z_SHIRT
    if view == 'up':
        # 뒷목 깃
        c.stroke([(78, 131), (96, 136), (114, 131)], 'u', z, w=3.2,
                 only='tT', taper=0.55)
        # 멍에선 — 어깨를 가로지른다.  좌우 높이를 어긋나게
        c.stroke([(64, 152), (80, 148), (96, 150), (114, 147), (130, 153)],
                 'u', z, w=2.2, only='tT', taper=0.6)
        c.stroke([(68, 156), (84, 153), (96, 155)], 'T', z, w=1.6,
                 only='tu', taper=0.7)
        # 어깨죽지에서 허리로 모이는 주름
        for k, (x0, y0, x1, y1) in enumerate(
                ((76, 160, 82, 190), (86, 164, 88, 192), (98, 158, 97, 188),
                 (108, 166, 105, 192), (116, 160, 112, 186))):
            c.stroke([(x0, y0), ((x0 + x1) / 2.0 + (1 if k % 2 else -1), (y0 + y1) / 2.0),
                      (x1, y1)], 'u', z, w=2.0 + 0.4 * (k % 3), only='tT', taper=0.85)
        return
    if view == 'side':
        c.stroke([(78, 130), (96, 139), (116, 134)], 'u', z, w=3.4,
                 only='tT', taper=0.55)
        c.stroke([(84, 128), (98, 136), (112, 130)], 'T', z, w=2.0,
                 only='tu', taper=0.7)
        for k, yy in enumerate((152, 168, 184)):
            c.ell(100, yy, 2.2, 2.2, 'i', z, only='tTu')
        c.stroke([(101, 148), (100, 192)], 'u', z, w=1.6, only='tT', taper=0.45)
        c.stroke([(97, 152), (96, 186)], 'T', z, w=1.6, only='tu', taper=0.6)
        return
    c.stroke([(72, 130), (95, 141), (119, 130)], 'u', z, w=3.4,
             only='tT', taper=0.55)
    c.stroke([(78, 127), (95, 137), (113, 127)], 'T', z, w=2.0,
             only='tu', taper=0.7)
    c.stroke([(96, 146), (95, 192)], 'u', z, w=1.6, only='tT', taper=0.45)
    c.stroke([(92, 150), (91, 188)], 'T', z, w=1.6, only='tu', taper=0.6)
    for yy in (152, 168, 184):
        c.ell(95.5, yy, 2.2, 2.2, 'i', z, only='tTu')


def boot_detail(c, girl, view, parts):
    z = {Z_SHOE, Z_SHOE + 1}
    sh = parts['shoe']
    ys = sorted(sh.keys())
    if not ys:
        return
    if not girl:
        top = ys[0]
        for y in range(top + 5, top + 10):
            for (a, b) in sh.get(y, []):
                for x in range(a, b + 1):
                    if c.z[y][x] in z and c.g[y][x] in 'bn':
                        c.g[y][x] = 'n'
    if view == 'side':
        for y, ra in sh.items():
            for (a, b) in ra:
                for x in range(a, b + 1):
                    if c.z[y][x] == Z_SHOE and c.g[y][x] == 'b':
                        c.g[y][x] = 'n'
    # 밑창
    bot = ys[-1]
    for y in range(bot - 3, bot + 1):
        for (a, b) in sh.get(y, []):
            for x in range(a, b + 1):
                if c.z[y][x] in z:
                    c.g[y][x] = 'n'


# ---------------------------------------------------------------- 저장
def save(c, path):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    minx, maxx, maxy = W, -1, -1
    for y in range(H):
        for x in range(W):
            if c.g[y][x] != '.':
                minx = min(minx, x)
                maxx = max(maxx, x)
                maxy = max(maxy, y)
    dx = int(math.floor(95.5 - (minx + maxx) / 2.0 + 0.5))
    dy = 286 - maxy
    for y in range(H):
        for x in range(W):
            ch = c.g[y][x]
            if ch == '.':
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H:
                r, g, b = PAL[ch]
                px[nx, ny] = (r, g, b, 255)
    im.save(path)


def main():
    for sex in ('boy', 'girl'):
        for view in ('down', 'side', 'up'):
            c = build(sex, view)
            save(c, 'w192_b_%s_%s.png' % (sex, view))
            print('w192_b_%s_%s.png' % (sex, view))


if __name__ == '__main__':
    main()
