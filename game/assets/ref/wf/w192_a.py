#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""리틀 루트 주인공 도트 — 192 x 288.  디자인 a: 단순 명료한 선, 적은 면,
큰 눈, 최소한의 음영.  실루엣과 눈으로 승부한다.

실행하면 여섯 장을 쓴다:
    w192_a_boy_down.png  w192_a_boy_side.png  w192_a_boy_up.png
    w192_a_girl_down.png w192_a_girl_side.png w192_a_girl_up.png

처음부터 192칸 격자에 직접 찍는다.  실루엣도 음영 경계도 연속 좌표
도형을 192칸에서 반올림해 얻으므로 계단이 생기지 않는다.
"""
import math
from PIL import Image

W, H = 192, 288
CX = 96.0                      # 좌우 대칭축 (픽셀 95 와 96 사이)

# ---------------------------------------------------------------- 팔레트
SK, SK_L, SK_D            = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD           = (82,53,33), (56,37,25), (39,26,18)
OL, EYE, BROW, WHT        = (26,20,28), (66,32,30), (136,70,42), (246,242,234)

BASE = {'skin': SK, 'hair': HR, 'shirt': SH, 'pants': PT, 'shoe': SO}
DARK = {'skin': SK_DD, 'hair': HR_DD, 'shirt': SH_DD, 'pants': PT_DD, 'shoe': SO_DD}

TH_AIR  = 3      # 실루엣 윤곽 두께
TH_PART = 2      # 재질끼리 맞닿는 곳의 윤곽 두께


# ------------------------------------------------------------ 기하 도구
def disc(cx, cy, r):
    m = set()
    rr = r * r
    for y in range(max(0, int(cy - r - 1)), min(H - 1, int(cy + r + 1)) + 1):
        dy = y + 0.5 - cy
        t = rr - dy * dy
        if t < 0:
            continue
        hx = math.sqrt(t)
        for x in range(max(0, int(math.ceil(cx - hx - 0.5))),
                       min(W - 1, int(math.floor(cx + hx - 0.5))) + 1):
            m.add((x, y))
    return m


def ell(cx, cy, rx, ry, p=2.0, y0=None, y1=None):
    u"""초타원.  p=2 는 타원, p 가 크면 모서리가 둥근 사각형에 가까워진다."""
    m = set()
    a = int(math.floor(cy - ry)) if y0 is None else y0
    b = int(math.ceil(cy + ry)) if y1 is None else y1
    for y in range(max(0, a), min(H - 1, b) + 1):
        d = abs((y + 0.5 - cy) / float(ry))
        if d >= 1.0:
            continue
        hx = rx * (1.0 - d ** p) ** (1.0 / p)
        for x in range(max(0, int(math.ceil(cx - hx - 0.5))),
                       min(W - 1, int(math.floor(cx + hx - 0.5))) + 1):
            m.add((x, y))
    return m


def rrect(x0, y0, x1, y1, r=(4, 4, 4, 4)):
    u"""모서리 반지름이 제각각인 둥근 사각형 (픽셀 좌표 포함)."""
    m = set()
    cs = ((x0, y0, r[0], 1, 1), (x1 + 1, y0, r[1], -1, 1),
          (x0, y1 + 1, r[2], 1, -1), (x1 + 1, y1 + 1, r[3], -1, -1))
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        py = y + 0.5
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            px, ok = x + 0.5, True
            for (ax, ay, rr, sx, sy) in cs:
                if rr <= 0:
                    continue
                ccx, ccy = ax + sx * rr, ay + sy * rr
                if (px - ccx) * sx < 0 and (py - ccy) * sy < 0:
                    if (px - ccx) ** 2 + (py - ccy) ** 2 > rr * rr:
                        ok = False
                        break
            if ok:
                m.add((x, y))
    return m


def stroke(pts):
    u"""[(x, y, r), ...] 폴리라인을 따라 원을 이어 붙인 굵은 선."""
    m = set()
    for i in range(len(pts) - 1):
        x0, y0, r0 = pts[i]
        x1, y1, r1 = pts[i + 1]
        n = max(2, int(math.hypot(x1 - x0, y1 - y0) * 2) + 1)
        for k in range(n + 1):
            t = k / float(n)
            m |= disc(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r0 + (r1 - r0) * t)
    return m


def band(y0, y1, fl, fr):
    u"""행마다 좌/우 경계를 따로 주는 영역.  비대칭 몸통·치마에 쓴다."""
    m = set()
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        a = int(math.ceil(fl(y + 0.5) - 0.5))
        b = int(math.floor(fr(y + 0.5) - 0.5))
        for x in range(max(0, a), min(W - 1, b) + 1):
            m.add((x, y))
    return m


def mir(m):
    return set((191 - x, y) for (x, y) in m)


def below(mask, fn):
    return set((x, y) for (x, y) in mask if y + 0.5 > fn(x + 0.5))


def above(mask, fn):
    return set((x, y) for (x, y) in mask if y + 0.5 <= fn(x + 0.5))


def left_of(mask, fn):
    return set((x, y) for (x, y) in mask if x + 0.5 <= fn(y + 0.5))


def right_of(mask, fn):
    return set((x, y) for (x, y) in mask if x + 0.5 > fn(y + 0.5))


def smoothstep(a, b, t):
    t = max(0.0, min(1.0, t))
    return a + (b - a) * t * t * (3 - 2 * t)


def curve(pts):
    u"""제어점 [(x, y), ...] 을 부드럽게 잇는 함수."""
    pts = sorted(pts)

    def f(x):
        if x <= pts[0][0]:
            return pts[0][1]
        if x >= pts[-1][0]:
            return pts[-1][1]
        for i in range(len(pts) - 1):
            if pts[i][0] <= x <= pts[i + 1][0]:
                return smoothstep(pts[i][1], pts[i + 1][1],
                                  (x - pts[i][0]) / float(pts[i + 1][0] - pts[i][0]))
        return pts[-1][1]
    return f


def bez(p0, p1, p2, r, n=28):
    pts = []
    for k in range(n + 1):
        t = k / float(n)
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        rr = r if not isinstance(r, tuple) else r[0] + (r[1] - r[0]) * t
        pts.append((x, y, rr))
    return stroke(pts)


# ------------------------------------------------------------ 스프라이트
class Part(object):
    def __init__(self, name, mat, mask, noout=(), shade=None):
        self.name, self.mat, self.mask = name, mat, mask
        self.noout, self.shade = set(noout), shade


class Sprite(object):
    def __init__(self):
        self.px = [[None] * W for _ in range(H)]
        self.own = [[None] * W for _ in range(H)]

    def set(self, p, c):
        x, y = p
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = c

    def fill(self, mask, c):
        for p in mask:
            self.set(p, c)

    def add(self, part):
        c = BASE[part.mat]
        for (x, y) in part.mask:
            if 0 <= x < W and 0 <= y < H:
                self.px[y][x] = c
                self.own[y][x] = part.name

    def visible(self, name):
        return set((x, y) for y in range(H) for x in range(W) if self.own[y][x] == name)

    def image(self):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ip = im.load()
        for y in range(H):
            for x in range(W):
                c = self.px[y][x]
                if c is not None:
                    ip[x, y] = (c[0], c[1], c[2], 255)
        return im


def erode(m, n=1):
    out = set(m)
    for _ in range(n):
        out = set(p for p in out
                  if all((p[0] + d[0], p[1] + d[1]) in out
                         for d in ((1, 0), (-1, 0), (0, 1), (0, -1))))
    return out


def grow(seed, region, n):
    cur, out = set(seed), set(seed)
    for _ in range(n):
        nxt = set()
        for (x, y) in cur:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p in region and p not in out:
                    nxt.add(p)
        out |= nxt
        cur = nxt
        if not cur:
            break
    return out


def render(parts, features=()):
    sp = Sprite()
    for p in parts:
        sp.add(p)
    vis = {}
    for p in parts:
        vis[p.name] = sp.visible(p.name)
        if p.shade:
            p.shade(sp, vis[p.name])
    z = dict((p.name, i) for i, p in enumerate(parts))
    for i, p in enumerate(parts):
        cur = vis[p.name]
        if not cur:
            continue
        ea, ep = set(), set()
        for (x, y) in cur:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H):
                    ea.add((x, y))
                    continue
                o = sp.own[ny][nx]
                if o is None:
                    ea.add((x, y))
                elif o != p.name and z[o] < i and o not in p.noout:
                    ep.add((x, y))
        sp.fill(grow(ea, cur, TH_AIR - 1) | grow(ep, cur, TH_PART - 1), DARK[p.mat])
    for f in features:
        f(sp)
    return sp


# ------------------------------------------------------------ 얼굴 부품
def draw_eye(sp, cx, cy, w, h, out, lash=0):
    u"""out: 바깥쪽 방향(+1 = 오른쪽이 바깥).  홍채가 눈을 거의 채우고
    흰자는 좌우에만 남는다.  홍채 아래는 밝은 갈색이라 동공이 또렷하다.
    비율로만 잡으므로 3/4 의 눌린 눈에서도 흰자·홍채 비가 유지된다."""
    rx, ry = w / 2.0, h / 2.0
    outer = ell(cx, cy, rx, ry, 2.25)
    if lash:
        outer |= stroke([(cx + out * (rx - 2.6), cy - ry * 0.50, 3.0),
                         (cx + out * (rx + lash - 0.6), cy - ry * 0.86, 1.6)])
    inner = ell(cx, cy + ry * 0.10, rx * 0.76, ry * 0.78, 2.25) & outer
    sp.fill(outer, OL)
    sp.fill(inner, WHT)
    iris = ell(cx, cy + ry * 0.12, rx * 0.57, ry * 0.90, 2.1) & inner
    sp.fill(iris, EYE)
    sp.fill(iris & disc(cx, cy + ry * 1.42, rx * 1.55), BROW)
    sp.fill(ell(cx, cy + ry * 0.22, rx * 0.30, ry * 0.36, 2.0) & iris, OL)
    ii = erode(iris, 2)
    sp.fill(disc(cx + out * rx * 0.18, cy - ry * 0.32, rx * 0.30) & ii, WHT)
    sp.fill(disc(cx - out * rx * 0.22, cy + ry * 0.44, rx * 0.14) & ii, WHT)


def draw_brow(sp, x0, x1, y, dy=0.0, r=1.9, col=BROW):
    sp.fill(stroke([(x0, y + dy, r), (x1, y, r)]), col)


def draw_mouth(sp, cx, y, w, d=3.0, col=OL):
    sp.fill(bez((cx - w / 2.0, y), (cx, y + d), (cx + w / 2.0, y), 1.0), col)


# ------------------------------------------------- 면 나누기 짧은 이름들
def L(v, pts):
    return v & left_of(v, curve(pts))


def R(v, pts):
    return v & right_of(v, curve(pts))


def B(v, pts):
    return v & below(v, curve(pts))


def A(v, pts):
    return v & above(v, curve(pts))


# ======================================================= 공통 치수 / 머리통
CHIN = 119
TORSO_TOP = 121


def head_mass(jaw_cx=CX):
    return ell(CX, 66, 47, 46, 2.05) | ell(jaw_cx, 94, 35, 26, 2.0)


def hair_shade(sp, v, lit, drk, shine=None):
    u"""머리는 세 면뿐이다: 왼쪽 위 밝은 면, 바탕, 오른쪽 아래 어두운 면."""
    sp.fill(v & ell(lit[0], lit[1], lit[2], lit[3], 2.2), HR_L)
    sp.fill(v & disc(drk[0], drk[1], drk[2]), HR_D)
    if shine:
        sp.fill(v & stroke(shine), HR_LL)


# ----------------------------------------------------------- 몸통 만들기
def torso_mask(cx, hw_pts, top, bot, cap_hw, cap_ry=19):
    hw = curve(hw_pts)
    m = band(top, bot, lambda y: cx - hw(y), lambda y: cx + hw(y))
    m |= ell(cx, top + cap_ry, cap_hw, cap_ry, 3.3, y0=top, y1=top + cap_ry)
    return m


def shirt_shade(cx, hem, dark_pts, collar=None, back=False):
    def f(sp, v):
        sp.fill(v & disc(cx - 126, 120, 118), SH_L)
        sp.fill(R(v, dark_pts), SH_D)
        sp.fill(B(v, [(cx - 40, hem - 4), (cx + 40, hem - 6)]), SH_D)
        if collar:
            c0, c1, c2, c3 = collar
            ring = (ell(c0, c1, c2, c3, 2.2) - ell(c0, c1 - 2.8, c2 - 4.2, c3 - 1.6, 2.2))
            sp.fill(v & below(ring, lambda x: c1 - c3 * 0.55), SH_D)
    return f


def sleeve_shade(near, hem_pts, seam_pts):
    def f(sp, v):
        if near:
            sp.fill(v & disc(28, 104, 44), SH_L)
            sp.fill(R(v, seam_pts), SH_D)
        else:
            sp.fill(v & disc(178, 120, 44), SH_D)
            sp.fill(L(v, seam_pts), SH_D)
        sp.fill(B(v, hem_pts), SH_D)
    return f


def arm_shade(near, edge_pts, fingers=()):
    def f(sp, v):
        if near:
            sp.fill(L(v, edge_pts), SK_L)
        else:
            sp.fill(R(v, edge_pts), SK_D)
        for a in fingers:
            sp.fill(stroke([(a[0], a[1], 1.3), (a[2], a[3], 1.3)]) & v, SK_D)
    return f


def leg_shade(mat, near, lo, hi):
    lt, dk = (SK_L, SK_D) if mat == 'skin' else (PT_L, PT_D)

    def f(sp, v):
        if near:
            sp.fill(L(v, lo), lt)
            sp.fill(R(v, hi), dk)
        else:
            sp.fill(L(v, lo), dk)
            sp.fill(R(v, hi), dk)
    return f


def boot_shade(cuff, sole, rim=None):
    def f(sp, v):
        sp.fill(v & rrect(0, cuff[0], 191, cuff[1], (0,) * 4), SO_D)
        if rim:
            sp.fill(R(v, rim), SO_D)
        sp.fill(v & rrect(0, sole, 191, 286, (0,) * 4), SO_DD)
    return f


# ================================================================== 소년
def boy_legs(parts, cx=CX, side=False):
    u"""바지 + 장화.  side 면 먼 다리를 먼저(뒤에) 놓는다."""
    if side:
        parts.append(Part('leg_f', 'pants', rrect(99, 184, 120, 248, (0, 0, 5, 5)),
                          shade=lambda sp, v: sp.fill(v, PT_D)))
        parts.append(Part('boot_f', 'shoe', rrect(95, 244, 126, 282, (10, 12, 3, 4)),
                          shade=lambda sp, v: sp.fill(v, SO_D)))
        lhw = curve([(184, 12.9), (220, 12.4), (252, 11.8)])
        parts.append(Part('leg_n', 'pants',
                          band(184, 252, lambda y: 81.5 - lhw(y), lambda y: 81.5 + lhw(y)),
                          shade=leg_shade('pants', True,
                                          [(184, 78), (220, 77), (252, 75)],
                                          [(184, 89), (252, 87)])))
        parts.append(Part('boot_n', 'shoe', rrect(64, 250, 106, 286, (10, 15, 3, 5)),
                          shade=boot_shade((250, 256), 282, [(250, 92), (286, 91)])))
        return
    lhw = curve([(184, 12.9), (220, 12.4), (252, 11.8)])
    leg_l = band(184, 252, lambda y: 79.5 - lhw(y), lambda y: 79.5 + lhw(y))
    parts.append(Part('leg_l', 'pants', leg_l,
                      shade=leg_shade('pants', True,
                                      [(184, 76), (220, 75), (252, 73)],
                                      [(184, 87), (252, 85)])))
    parts.append(Part('leg_r', 'pants', mir(leg_l),
                      shade=leg_shade('pants', False,
                                      [(184, 108), (252, 106)],
                                      [(184, 118), (252, 116)])))
    boot_l = rrect(63, 250, 93, 286, (9, 9, 3, 3))
    parts.append(Part('boot_l', 'shoe', boot_l,
                      shade=boot_shade((250, 256), 282, [(250, 86), (286, 85)])))
    parts.append(Part('boot_r', 'shoe', mir(boot_l),
                      shade=boot_shade((250, 256), 282, [(250, 121), (286, 120)])))


def boy_torso(parts, cx=CX, back=False, side=False):
    if side:
        hl = curve([(121, 82.0), (131, 72.0), (141, 69.0), (160, 70.0), (196, 71.5)])
        hr_ = curve([(121, 112.0), (130, 122.0), (141, 125.0), (160, 124.5), (196, 124.0)])
        torso = band(121, 199, hl, hr_) | ell(99, 140, 26.5, 19, 3.3, y0=121, y1=140)
        parts.append(Part('torso', 'shirt', torso, shade=shirt_shade(
            99, 199, [(121, 117.0), (152, 119.5), (199, 121.5)],
            collar=(101, 127, 16.0, 11))))
        return
    torso = torso_mask(cx, [(121, 17.0), (130, 24.0), (141, 26.5), (156, 26.8),
                            (176, 26.0), (190, 27.0), (199, 28.0)], 121, 199, 26.5)
    parts.append(Part('torso', 'shirt', torso, shade=shirt_shade(
        cx, 199, [(121, 116.0), (152, 118.5), (199, 120.5)],
        collar=(cx, 127, 16.5, 11), back=back)))


def shift(m, dx, dy=0):
    return set((x + dx, y + dy) for (x, y) in m)


def boy_arms(parts, back=False, side=False):
    u"""맨살 팔뚝을 먼저 놓고 소매를 덮는다.  소매는 몸통과 같은 천이므로
    윤곽으로 가르지 않고 SH_D 이음선만 넣는다 (풍선처럼 떨어져 보이지 않게)."""
    fore_n = stroke([(63.5, 152, 9.0), (62, 176, 8.2), (61.5, 184, 7.6), (61, 191, 10.0), (62, 199, 8.2)])
    slv_n = A(stroke([(67, 133, 11.8), (64.5, 149, 11.2), (63.5, 158, 10.8)]),
              [(46, 161), (80, 156)])
    if side:
        parts.append(Part('arm_f', 'shirt',
                          A(stroke([(122, 133, 11.0), (125.5, 148, 10.4), (126.5, 156, 10.0)]),
                            [(112, 159), (142, 154)]),
                          noout=('torso',), shade=lambda sp, v: sp.fill(v, SH_D)))
        parts.append(Part('fore_f', 'skin',
                          stroke([(126, 152, 8.2), (128, 176, 7.4), (128.5, 184, 6.8),
                                  (129, 191, 9.2), (128, 198, 7.6)]),
                          shade=lambda sp, v: sp.fill(v, SK_D)))
    else:
        parts.append(Part('fore_r', 'skin', mir(fore_n),
                          shade=arm_shade(False, [(150, 122), (196, 124)])))
        parts.append(Part('slv_r', 'shirt', mir(slv_n), noout=('torso',),
                          shade=sleeve_shade(False, [(112, 156), (146, 161)],
                                             [(121, 114), (160, 116)])))
    if side:
        fore_n, slv_n = shift(fore_n, 1), shift(slv_n, 1)
    parts.append(Part('fore_n', 'skin', fore_n,
                      shade=arm_shade(True, [(150, 61), (172, 60), (196, 58)],
                                      fingers=((67, 192, 66, 198),))))
    parts.append(Part('slv_n', 'shirt', slv_n, noout=('torso',),
                      shade=sleeve_shade(True, [(46, 156), (80, 151)],
                                         [(121, 78), (160, 76)])))


def boy_face_hair(parts, feats, side=False):
    head = head_mass(jaw_cx=101 if side else CX)
    if side:
        head |= disc(134, 99, 5.0)
        fb = curve([(46, 104), (56, 96), (66, 80), (76, 64), (86, 55), (96, 51),
                    (106, 55), (114, 53), (122, 59), (130, 66), (140, 76), (148, 90)])
        face = (head & ell(103, 88, 33, 38, 2.05) & below(head, fb)) | \
               (head & ell(101, 96, 33, 26))
        face = (face | disc(134, 99, 5.0)) & head

        def sh_face(sp, v):
            sp.fill(v & (below(v, fb)
                         - below(v, lambda x: fb(x) + 5 + 2.0 * math.sin(x / 8.0))), SK_D)
            sp.fill(v & ell(85, 104, 8, 4, 2.0), SK_CH)
            sp.fill(v & ell(124, 104, 5.5, 3.4, 2.0), SK_CH)
            sp.fill(v & (ell(131, 103, 5.4, 3.6, 2.0) - ell(130, 99.5, 5.0, 3.2)), SK_D)

        parts.append(Part('face', 'skin', face, noout=('neck',), shade=sh_face))
        parts.append(Part('hair', 'hair', head - face, shade=lambda sp, v: hair_shade(
            sp, v, (70, 46, 38, 34), (168, 94, 62), [(86, 34, 2.7), (77, 42, 2.3), (69, 53, 1.5)])))
        parts.append(Part('ear', 'skin', ell(63, 95, 6.0, 7.5, 2.0),
                          shade=lambda sp, v: sp.fill(v & ell(65, 96, 2.6, 3.6), SK_D)))

        def f(sp):
            draw_eye(sp, 95.0, 88, 21, 26, -1)
            draw_eye(sp, 124.0, 88, 14, 24, +1)
            draw_brow(sp, 87, 101, 67, dy=1.5)
            draw_brow(sp, 131, 119, 66, dy=1.2)
            draw_mouth(sp, 117, 112, 8.5, 2.6)
        feats.append(f)
        return
    fb = curve([(44, 100), (54, 88), (63, 74), (72, 62), (81, 55), (90, 59),
                (99, 56), (108, 64), (117, 68), (126, 78), (134, 88), (148, 100)])
    face = (head & ell(CX, 88, 33, 38, 2.05) & below(head, fb)) | (head & ell(CX, 96, 33, 26))

    def sh_face(sp, v):
        sp.fill(v & (below(v, fb)
                     - below(v, lambda x: fb(x) + 5 + 2.2 * math.sin(x / 9.0))), SK_D)
        sp.fill(v & ell(76, 105, 8, 4, 2.0), SK_CH)
        sp.fill(v & ell(116, 105, 8, 4, 2.0), SK_CH)
        sp.fill(v & ell(CX, 103, 2.6, 1.8, 2.0), SK_D)

    parts.append(Part('face', 'skin', face, noout=('neck',), shade=sh_face))
    parts.append(Part('hair', 'hair', head - face, shade=lambda sp, v: hair_shade(
        sp, v, (72, 46, 38, 34), (170, 96, 62), [(84, 34, 2.7), (75, 42, 2.3), (67, 53, 1.5)])))

    def f(sp):
        draw_eye(sp, 79.0, 88, 21, 26, -1)
        draw_eye(sp, 113.0, 88, 21, 26, +1)
        draw_brow(sp, 71, 85, 67, dy=1.5)
        draw_brow(sp, 121, 107, 67, dy=1.5)
        draw_mouth(sp, 96, 111, 9.5, 2.8)
    feats.append(f)


def boy_down():
    parts, feats = [], []
    boy_legs(parts)
    parts.append(Part('neck', 'skin', rrect(83, 98, 108, 126, (7, 7, 0, 0)),
                      shade=lambda sp, v: sp.fill(v & ell(CX, 100, 30, 22), SK_D)))
    boy_torso(parts)
    boy_arms(parts)
    boy_face_hair(parts, feats)
    return parts, feats


def boy_side():
    parts, feats = [], []
    boy_legs(parts, side=True)
    parts.append(Part('neck', 'skin', rrect(87, 98, 112, 126, (7, 7, 0, 0)),
                      shade=lambda sp, v: sp.fill(v & ell(101, 100, 30, 22), SK_D)))
    boy_torso(parts, side=True)
    boy_arms(parts, side=True)
    boy_face_hair(parts, feats, side=True)
    return parts, feats


def boy_up():
    parts, feats = [], []
    boy_legs(parts)
    parts.append(Part('neck', 'skin', rrect(85, 98, 106, 126, (7, 7, 0, 0)),
                      shade=lambda sp, v: sp.fill(v & ell(CX, 104, 30, 20), SK_D)))
    boy_torso(parts, back=True)
    boy_arms(parts, back=True)
    head = head_mass()
    nape = curve([(46, 92), (56, 104), (66, 116), (78, 110), (90, 119),
                  (102, 112), (114, 118), (126, 108), (136, 98), (146, 88)])

    def sh_nape(sp, v):
        hair_shade(sp, v, (72, 44, 38, 34), (170, 94, 62),
                   [(84, 34, 2.7), (75, 42, 2.3), (67, 53, 1.5)])
        for a in ((64, 96, 65, 112), (79, 92, 78, 106), (101, 94, 102, 108),
                  (124, 96, 125, 112)):
            sp.fill(stroke([(a[0], a[1], 1.7), (a[2], a[3], 1.7)]) & v, HR_D)

    parts.append(Part('hair', 'hair', head & above(head, nape), shade=sh_nape))
    return parts, feats


# ================================================================== 소녀
def girl_legs(parts, side=False):
    if side:
        parts.append(Part('leg_f', 'skin', rrect(99, 220, 118, 268, (0, 0, 4, 4)),
                          shade=lambda sp, v: sp.fill(v, SK_D)))
        parts.append(Part('shoe_f', 'shoe', rrect(96, 266, 122, 282, (7, 8, 3, 3)),
                          shade=lambda sp, v: sp.fill(v, SO_D)))
        ghw = curve([(220, 9.8), (250, 9.4), (272, 8.8)])
        parts.append(Part('leg_n', 'skin',
                          band(220, 272, lambda y: 85.0 - ghw(y), lambda y: 85.0 + ghw(y)),
                          shade=leg_shade('skin', True,
                                          [(220, 82), (272, 80)], [(220, 91), (272, 89)])))
        parts.append(Part('shoe_n', 'shoe', rrect(72, 268, 102, 286, (7, 9, 3, 4)),
                          shade=boot_shade((268, 270), 282, [(268, 92), (286, 91)])))
        return
    ghw = curve([(220, 9.4), (250, 9.0), (272, 8.4)])
    leg_l = band(220, 272, lambda y: 83.0 - ghw(y), lambda y: 83.0 + ghw(y))
    parts.append(Part('leg_l', 'skin', leg_l,
                      shade=leg_shade('skin', True,
                                      [(220, 81), (272, 79)], [(220, 89), (272, 87)])))
    parts.append(Part('leg_r', 'skin', mir(leg_l),
                      shade=leg_shade('skin', False,
                                      [(220, 106), (272, 104)], [(220, 115), (272, 113)])))
    shoe_l = rrect(70, 268, 94, 286, (7, 7, 3, 3))
    parts.append(Part('shoe_l', 'shoe', shoe_l,
                      shade=boot_shade((268, 270), 282, [(268, 88), (286, 87)])))
    parts.append(Part('shoe_r', 'shoe', mir(shoe_l),
                      shade=boot_shade((268, 270), 282, [(268, 119), (286, 118)])))


def girl_skirt(parts, cx=CX, folds=()):
    hem = curve([(46, 226), (60, 231), (74, 225), (88, 232), (102, 226),
                 (116, 233), (130, 227), (144, 222)])
    skw = curve([(184, 26.5), (196, 31.0), (210, 38.0), (224, 44.5), (238, 47.5)])
    skirt = above(band(184, 238, lambda y: cx - skw(y), lambda y: cx + skw(y)), hem)

    def sh(sp, v):
        sp.fill(v & disc(cx - 130, 176, 116), PT_L)
        sp.fill(R(v, [(180, cx + 20), (210, cx + 26), (236, cx + 30)]), PT_D)
        for a in folds:
            sp.fill(stroke([(a[0], a[1], 1.7), (a[2], a[3], 1.7)]) & v, PT_D)

    parts.append(Part('skirt', 'pants', skirt, shade=sh))


def girl_torso(parts, cx=CX, back=False, side=False):
    if side:
        hl = curve([(121, 84.0), (131, 75.0), (141, 72.5), (160, 73.5), (188, 75.0)])
        hr_ = curve([(121, 112.0), (130, 121.0), (141, 123.5), (160, 123.0), (188, 122.0)])
        torso = band(121, 190, hl, hr_) | ell(99, 140, 25.0, 19, 3.3, y0=121, y1=140)
        parts.append(Part('torso', 'shirt', torso, shade=shirt_shade(
            99, 190, [(121, 116.5), (150, 118.5), (190, 119.5)],
            collar=(101, 127, 14.5, 10))))
        return
    torso = torso_mask(cx, [(121, 16.0), (130, 22.5), (141, 25.0), (156, 25.2),
                            (176, 24.6), (190, 25.6)], 121, 190, 25.0)
    parts.append(Part('torso', 'shirt', torso, shade=shirt_shade(
        cx, 190, [(121, 115.0), (150, 117.0), (190, 118.5)],
        collar=(cx, 127, 15.0, 10), back=back)))


def girl_arms(parts, back=False, side=False):
    fore_n = stroke([(65, 148, 8.6), (63.5, 170, 7.8), (63, 178, 7.2), (62.5, 185, 9.4), (63.5, 193, 7.8)])
    slv_n = A(stroke([(69, 132, 11.2), (66.5, 146, 10.6), (65.5, 153, 10.2)]),
              [(48, 156), (82, 151)])
    if side:
        parts.append(Part('arm_f', 'shirt',
                          A(stroke([(122, 132, 10.6), (125.5, 145, 10.0), (126.5, 152, 9.6)]),
                            [(112, 155), (142, 150)]),
                          noout=('torso',), shade=lambda sp, v: sp.fill(v, SH_D)))
        parts.append(Part('fore_f', 'skin',
                          stroke([(126, 148, 7.8), (128, 170, 7.0), (128.5, 178, 6.4),
                                  (129, 185, 8.8), (128, 192, 7.2)]),
                          shade=lambda sp, v: sp.fill(v, SK_D)))
    else:
        parts.append(Part('fore_r', 'skin', mir(fore_n),
                          shade=arm_shade(False, [(148, 124), (192, 126)])))
        parts.append(Part('slv_r', 'shirt', mir(slv_n), noout=('torso',),
                          shade=sleeve_shade(False, [(110, 151), (144, 156)],
                                             [(121, 112), (156, 114)])))
    if side:
        fore_n, slv_n = shift(fore_n, 2), shift(slv_n, 2)
    parts.append(Part('fore_n', 'skin', fore_n,
                      shade=arm_shade(True, [(148, 64), (170, 63), (192, 61)],
                                      fingers=((68, 186, 67, 192),))))
    parts.append(Part('slv_n', 'shirt', slv_n, noout=('torso',),
                      shade=sleeve_shade(True, [(48, 151), (82, 146)],
                                         [(121, 80), (156, 78)])))


def girl_back_hair(bot, wl, wr, cx=CX):
    m = ell(CX, 66, 47, 46, 2.05)
    m |= band(60, bot, lambda y: cx - wl(y), lambda y: cx + wr(y))
    return m


def girl_face_hair(parts, feats, side=False):
    head = head_mass(jaw_cx=101 if side else CX)
    if side:
        head |= disc(134, 99, 5.0)
        fb = curve([(46, 102), (56, 94), (66, 78), (76, 62), (86, 53), (96, 49),
                    (106, 53), (114, 51), (122, 57), (130, 64), (140, 74), (148, 88)])
        face = (head & ell(103, 88, 33.5, 38, 2.05) & below(head, fb)) | \
               (head & ell(101, 96, 33.5, 26))
        face = (face | disc(134, 99, 5.0)) & head

        def sh_face(sp, v):
            sp.fill(v & (below(v, fb)
                         - below(v, lambda x: fb(x) + 5 + 2.0 * math.sin(x / 8.0))), SK_D)
            sp.fill(v & ell(85, 104, 7.5, 4, 2.0), SK_CH)
            sp.fill(v & ell(124, 104, 5.5, 3.4, 2.0), SK_CH)
            sp.fill(v & (ell(131, 103, 5.4, 3.6, 2.0) - ell(130, 99.5, 5.0, 3.2)), SK_D)

        parts.append(Part('face', 'skin', face, noout=('neck',), shade=sh_face))
        hair = head - face
        hair |= stroke([(62, 76, 8.8), (57, 118, 8.2), (60, 150, 5.8), (65, 167, 3.4),
                        (68, 175, 1.9)])
        parts.append(Part('hair', 'hair', hair, shade=lambda sp, v: hair_shade(
            sp, v, (70, 46, 38, 34), (168, 94, 62), [(88, 33, 2.7), (79, 41, 2.3), (71, 52, 1.5)])))

        def f(sp):
            draw_eye(sp, 95.0, 88, 22, 27, -1, lash=3.2)
            draw_eye(sp, 124.0, 88, 14.5, 25, +1, lash=2.4)
            draw_brow(sp, 87, 101, 66, dy=1.5, r=1.7)
            draw_brow(sp, 131, 119, 65, dy=1.2, r=1.6)
            draw_mouth(sp, 117, 112, 8.5, 2.6)
        feats.append(f)
        return
    fb = curve([(44, 98), (54, 86), (63, 72), (72, 60), (81, 53), (90, 57),
                (99, 54), (108, 62), (117, 66), (126, 76), (134, 86), (148, 98)])
    face = (head & ell(CX, 88, 33.5, 38, 2.05) & below(head, fb)) | \
           (head & ell(CX, 96, 33.5, 26))

    def sh_face(sp, v):
        sp.fill(v & (below(v, fb)
                     - below(v, lambda x: fb(x) + 5 + 2.2 * math.sin(x / 9.0))), SK_D)
        sp.fill(v & ell(75, 105, 8, 4, 2.0), SK_CH)
        sp.fill(v & ell(117, 105, 8, 4, 2.0), SK_CH)
        sp.fill(v & ell(CX, 103, 2.6, 1.8, 2.0), SK_D)

    parts.append(Part('face', 'skin', face, noout=('neck',), shade=sh_face))
    hair = head - face
    hair |= stroke([(57, 82, 8.2), (54, 118, 7.4), (57, 148, 5.4), (61, 168, 3.2),
                    (64, 177, 1.8)])
    hair |= stroke([(135, 82, 8.2), (139, 122, 7.2), (137, 154, 5.0), (133, 172, 3.0),
                    (130, 180, 1.7)])
    parts.append(Part('hair', 'hair', hair, shade=lambda sp, v: hair_shade(
        sp, v, (72, 46, 38, 34), (172, 96, 62), [(82, 33, 2.7), (73, 41, 2.3), (65, 52, 1.5)])))

    def f(sp):
        draw_eye(sp, 79.0, 88, 22, 27, -1, lash=3.2)
        draw_eye(sp, 113.0, 88, 22, 27, +1, lash=3.2)
        draw_brow(sp, 71, 85, 66, dy=1.5, r=1.7)
        draw_brow(sp, 121, 107, 66, dy=1.5, r=1.7)
        draw_mouth(sp, 96, 111, 8.5, 2.6)
    feats.append(f)


def girl_down():
    parts, feats = [], []
    wf = curve([(60, 45.0), (86, 47.0), (116, 44.0), (150, 39.0), (180, 33.0), (206, 26.0)])
    hb = above(girl_back_hair(206, wf, wf),
               curve([(48, 182), (68, 200), (88, 208), (108, 197), (128, 204),
                      (146, 186), (156, 172)]))

    def sh_hb(sp, v):
        sp.fill(L(v, [(20, 92), (70, 74), (130, 58), (210, 44)]), HR_L)
        sp.fill(R(v, [(20, 104), (70, 122), (130, 138), (210, 150)]), HR_D)

    parts.append(Part('hairback', 'hair', hb, shade=sh_hb))
    girl_legs(parts)
    girl_skirt(parts, folds=((72, 192, 67, 226), (87, 196, 84, 230),
                             (110, 194, 114, 228), (126, 198, 133, 222)))
    parts.append(Part('neck', 'skin', rrect(84, 98, 107, 124, (7, 7, 0, 0)),
                      shade=lambda sp, v: sp.fill(v & ell(CX, 100, 30, 22), SK_D)))
    girl_torso(parts)
    girl_arms(parts)
    girl_face_hair(parts, feats)
    return parts, feats


def girl_side():
    parts, feats = [], []
    wl = curve([(60, 43.0), (100, 36.0), (150, 29.0), (184, 22.0)])
    wr = curve([(60, 45.0), (100, 50.0), (150, 46.0), (192, 37.0), (212, 27.0)])
    hb = above(girl_back_hair(212, wl, wr, cx=99),
               curve([(48, 172), (68, 188), (88, 200), (110, 211), (132, 202),
                      (148, 186), (158, 172)]))

    def sh_hb(sp, v):
        sp.fill(L(v, [(20, 90), (70, 72), (130, 58), (210, 48)]), HR_L)
        sp.fill(R(v, [(20, 106), (70, 124), (130, 140), (210, 148)]), HR_D)

    parts.append(Part('hairback', 'hair', hb, shade=sh_hb))
    girl_legs(parts, side=True)
    girl_skirt(parts, cx=99, folds=((76, 192, 71, 228), (92, 196, 89, 232),
                                    (116, 194, 120, 228)))
    parts.append(Part('neck', 'skin', rrect(88, 98, 111, 124, (7, 7, 0, 0)),
                      shade=lambda sp, v: sp.fill(v & ell(101, 100, 30, 22), SK_D)))
    girl_torso(parts, side=True)
    girl_arms(parts, side=True)
    girl_face_hair(parts, feats, side=True)
    return parts, feats


def girl_up():
    parts, feats = [], []
    girl_legs(parts)
    girl_skirt(parts, folds=((74, 194, 69, 226), (90, 198, 87, 230),
                             (112, 196, 116, 228)))
    parts.append(Part('neck', 'skin', rrect(84, 98, 107, 124, (7, 7, 0, 0)),
                      shade=lambda sp, v: sp.fill(v, SK_D)))
    girl_torso(parts, back=True)
    girl_arms(parts, back=True)
    wf = curve([(60, 45.0), (86, 47.0), (116, 43.0), (150, 38.0), (180, 32.0), (208, 25.0)])
    hb = above(girl_back_hair(208, wf, wf) | head_mass(),
               curve([(48, 178), (68, 196), (88, 205), (108, 194), (128, 200),
                      (146, 182), (156, 168)]))

    def sh_hb(sp, v):
        sp.fill(L(v, [(20, 90), (70, 74), (130, 62), (210, 54)]), HR_L)
        sp.fill(R(v, [(20, 102), (70, 118), (130, 132), (210, 140)]), HR_D)
        sp.fill(v & stroke([(82, 33, 2.7), (73, 41, 2.3), (65, 52, 1.5)]), HR_LL)
        sp.fill(v & stroke([(96, 22, 2.2), (94, 44, 1.8)]), HR_D)

    parts.append(Part('hairback', 'hair', hb, shade=sh_hb))
    return parts, feats


# ==================================================================== 출력
def patch_holes(sp):
    u"""둘러싸인 아주 작은 투명 구멍만 메운다.  다리 사이처럼 바깥과
    이어진 틈은 건드리지 않는다."""
    seen = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if sp.px[y][x] is not None or seen[y][x]:
                continue
            comp, st, edge = [], [(x, y)], False
            seen[y][x] = True
            while st:
                cx, cy = st.pop()
                comp.append((cx, cy))
                if cx in (0, W - 1) or cy in (0, H - 1):
                    edge = True
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] \
                            and sp.px[ny][nx] is None:
                        seen[ny][nx] = True
                        st.append((nx, ny))
            if edge or len(comp) > 6:
                continue
            cnt = {}
            for (cx, cy) in comp:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < W and 0 <= ny < H and sp.px[ny][nx] is not None:
                        c = sp.px[ny][nx]
                        cnt[c] = cnt.get(c, 0) + 1
            if cnt:
                best = max(cnt.items(), key=lambda kv: kv[1])[0]
                for q in comp:
                    sp.set(q, best)
    # 한 칸짜리 실금 (양옆이 다 불투명, 또는 위아래가 다 불투명)
    fix = []
    for y in range(H):
        for x in range(W):
            if sp.px[y][x] is not None:
                continue
            lr = (x > 0 and x < W - 1 and sp.px[y][x - 1] and sp.px[y][x + 1])
            tb = (y > 0 and y < H - 1 and sp.px[y - 1][x] and sp.px[y + 1][x])
            if lr or tb:
                ns = [sp.px[y + d[1]][x + d[0]] for d in ((1, 0), (-1, 0), (0, 1), (0, -1))
                      if 0 <= x + d[0] < W and 0 <= y + d[1] < H
                      and sp.px[y + d[1]][x + d[0]] is not None]
                cnt2 = {}
                for c in ns:
                    cnt2[c] = cnt2.get(c, 0) + 1
                fix.append(((x, y), max(cnt2.items(), key=lambda kv: kv[1])[0]))
    for q, c in fix:
        sp.set(q, c)


def finish(sp, path):
    patch_holes(sp)
    im = sp.image()
    px = im.load()
    xs = [x for y in range(H) for x in range(W) if px[x, y][3]]
    ys = [y for y in range(H) for x in range(W) if px[x, y][3]]
    minx, maxx, maxy = min(xs), max(xs), max(ys)
    dx, dy = int(round(95.5 - (minx + maxx) / 2.0)), 286 - maxy
    if dx or dy:
        out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        out.paste(im, (dx, dy))
        im = out
    im.save(path)
    return im


BUILDERS = {
    ('boy', 'down'): boy_down, ('boy', 'side'): boy_side, ('boy', 'up'): boy_up,
    ('girl', 'down'): girl_down, ('girl', 'side'): girl_side, ('girl', 'up'): girl_up,
}


def main():
    for sex in ('boy', 'girl'):
        for view in ('down', 'side', 'up'):
            parts, feats = BUILDERS[(sex, view)]()
            finish(render(parts, feats), 'w192_a_%s_%s.png' % (sex, view))
            print('w192_a_%s_%s.png' % (sex, view))


if __name__ == '__main__':
    main()
