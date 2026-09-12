#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""리틀 루트 주인공 도트 — 96 x 144 (청키 레트로), 방향 q = 차분한 미소.

  눈은 반쯤 감긴 호선(속눈썹 윗줄이 아치), 입은 닫힌 채 넓게 휜 미소.
  순하고 어른스러운 인상, 볼 홍조는 넓게.
  96x144 격자에 바로 찍는다 (저해상도 확대도, 고해상도 축소도 아니다).

  python3 w96_q.py  ->  w96_q_{boy,girl}_{down,side,up}.png
"""
from PIL import Image

W, H = 96, 144

SK, SK_L, SK_D            = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD           = (82,53,33), (56,37,25), (39,26,18)
OL, EYE, BROW, WHT        = (26,20,28), (66,32,30), (136,70,42), (246,242,234)

SKINS = set([SK, SK_L, SK_D, SK_CH, SK_M, SK_DD, SK_LL])
HAIRS = set([HR, HR_L, HR_D, HR_DD, HR_LL])
SHRT  = set([SH, SH_D, SH_L, SH_DD, SH_LL])
PNTS  = set([PT, PT_D, PT_L, PT_DD, PT_LL])
SHOE  = set([SO, SO_D, SO_DD])

DARK = {}
for _c in SKINS: DARK[_c] = SK_DD
for _c in HAIRS: DARK[_c] = HR_DD
for _c in SHRT:  DARK[_c] = SH_DD
for _c in PNTS:  DARK[_c] = PT_DD
for _c in SHOE:  DARK[_c] = SO_DD


# ---------------------------------------------------------------- 캔버스
class Cv(object):
    def __init__(self):
        self.d = {}

    def p(self, x, y, c):
        if c is not None and 0 <= x < W and 0 <= y < H:
            self.d[(x, y)] = c

    def pif(self, x, y, c, allowed):
        if self.d.get((x, y)) in allowed:
            self.d[(x, y)] = c

    def row(self, y, x0, x1, c):
        for x in range(x0, x1 + 1):
            self.p(x, y, c)

    def rowif(self, y, x0, x1, c, allowed):
        for x in range(x0, x1 + 1):
            self.pif(x, y, c, allowed)

    def col(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.p(x, y, c)

    def colif(self, x, y0, y1, c, allowed):
        for y in range(y0, y1 + 1):
            self.pif(x, y, c, allowed)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.row(y, x0, x1, c)

    def rectif(self, x0, y0, x1, y1, c, allowed):
        for y in range(y0, y1 + 1):
            self.rowif(y, x0, x1, c, allowed)

    def g(self, x, y):
        return self.d.get((x, y))


def stamp(c, x0, y0, pat, mp, allowed=SKINS):
    for j, line in enumerate(pat):
        for i, ch in enumerate(line):
            col = mp.get(ch)
            if col is not None:
                c.pif(x0 + i, y0 + j, col, allowed)


def strand(c, x0, y0, y1, wide, col, lean=0, only=None):
    u"""세로로 흐르는 머리 가닥 (곧은 나뭇결이 되지 않게 살짝 기운다)."""
    x = x0
    for i, y in enumerate(range(y0, y1 + 1)):
        if lean and i and i % lean == 0:
            x += 1 if lean > 0 else -1
        for k in range(wide):
            if only is None:
                c.pif(x + k, y, col, HAIRS)
            elif c.g(x + k, y) in only:
                c.p(x + k, y, col)


def despeckle(c):
    u"""한 칸짜리 색 얼룩은 게임 크기에서 먼지로 보인다. 주변 색으로 메운다."""
    for fam in (HAIRS, SKINS, SHRT, PNTS, SHOE):
        for _ in range(2):
            fix = {}
            for (x, y), col in c.d.items():
                if col not in fam:
                    continue
                nb = []
                same = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = c.d.get((x + dx, y + dy))
                    if n is None:
                        continue
                    if n == col:
                        same = True
                        break
                    if n in fam:
                        nb.append(n)
                if not same and len(nb) >= 3:
                    fix[(x, y)] = max(set(nb), key=nb.count)
            if not fix:
                break
            c.d.update(fix)


def hair_edge(c):
    u"""머리카락이 살결·옷과 만나는 안쪽 경계를 HR_DD 로 잡는다."""
    src = dict(c.d)
    for (x, y), col in src.items():
        if col not in HAIRS:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = src.get((x + dx, y + dy))
            if n is not None and n not in HAIRS:
                c.d[(x, y)] = HR_DD
                break


def outline(c):
    u"""실루엣 바깥 테두리를 재질별 가장 어두운 단으로 (검정 금지)."""
    src = dict(c.d)
    for (x, y), col in src.items():
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in src:
                c.d[(x, y)] = DARK.get(col, col)
                break


def finish(c, path):
    xs = [k[0] for k in c.d]
    ys = [k[1] for k in c.d]
    dx = (95 - min(xs) - max(xs)) // 2
    dy = 142 - max(ys)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for (x, y), col in c.d.items():
        nx, ny = x + dx, y + dy
        if 0 <= nx < W and 0 <= ny < H:
            px[nx, ny] = (col[0], col[1], col[2], 255)
    im.save(path)
    return path


# ---------------------------------------------------------------- 머리통 윤곽
def head_rows_down():
    r = {1: (38, 57), 2: (35, 60), 3: (33, 62), 4: (31, 64), 5: (30, 65),
         6: (29, 66), 7: (29, 66), 8: (28, 67), 9: (28, 67)}
    for y in range(10, 34):
        r[y] = (27, 68)
    r.update({34: (28, 67), 35: (28, 67), 36: (29, 66), 37: (29, 66),
              38: (30, 65), 39: (30, 65), 40: (31, 64), 41: (32, 63),
              42: (33, 62), 43: (34, 61), 44: (35, 60), 45: (36, 59),
              46: (38, 57), 47: (40, 55), 48: (41, 54)})
    return r


def head_rows_side():
    r = head_rows_down()
    # 턱이 돌아선 쪽(오른쪽)으로 몰리고, 먼(오른) 턱선이 더 가파르다
    r.update({42: (34, 62), 43: (35, 62), 44: (36, 61), 45: (38, 60),
              46: (40, 58), 47: (43, 56), 48: (45, 54)})
    return r


def head_rows_up():
    r = head_rows_down()
    r.update({34: (28, 67), 35: (28, 67), 36: (29, 66), 37: (29, 66),
              38: (30, 65), 39: (31, 64), 40: (32, 63), 41: (33, 62),
              42: (34, 61), 43: (35, 60), 44: (36, 59), 45: (37, 58),
              46: (39, 56), 47: (41, 54), 48: (42, 53), 49: (43, 52),
              50: (44, 51)})
    return r


# 앞머리 밑선 — 다발 폭(3~7칸)도 홈 폭(1~3칸)도 홈 깊이(3~7칸)도 제각각.
# 반복되는 톱니가 되지 않게 일부러 어긋나게 짰다.
HB_B_DOWN = {27: 40, 28: 40, 29: 37, 30: 33, 31: 27, 32: 22,
             33: 18, 34: 19, 35: 20, 36: 20, 37: 19, 38: 18,
             39: 15,
             40: 18, 41: 19, 42: 19,
             43: 17, 44: 16,
             45: 18, 46: 20, 47: 21, 48: 21, 49: 20, 50: 18,
             51: 14, 52: 15,
             53: 18, 54: 19, 55: 19, 56: 18,
             57: 16,
             58: 18, 59: 19, 60: 20, 61: 19,
             62: 17, 63: 17, 64: 18,
             65: 20, 66: 25, 67: 31, 68: 37}

HB_G_DOWN = {26: 74, 27: 74, 28: 73, 29: 70, 30: 64, 31: 51,
             32: 17, 33: 18, 34: 19, 35: 20, 36: 20, 37: 19, 38: 18,
             39: 15, 40: 16,
             41: 19, 42: 20, 43: 20, 44: 19,
             45: 17,
             46: 19, 47: 20, 48: 20, 49: 19, 50: 18,
             51: 16, 52: 16, 53: 17,
             54: 19, 55: 20, 56: 20, 57: 19,
             58: 17,
             59: 19, 60: 20, 61: 19, 62: 18, 63: 18,
             64: 51, 65: 64, 66: 70, 67: 73, 68: 74, 69: 74}

HB_B_SIDE = {27: 41, 28: 41, 29: 40, 30: 38, 31: 36, 32: 33, 33: 29, 34: 25,
             35: 18, 36: 19, 37: 20, 38: 20, 39: 19, 40: 18,
             41: 15,
             42: 18, 43: 19, 44: 19,
             45: 17, 46: 16,
             47: 18, 48: 20, 49: 21, 50: 21, 51: 20, 52: 18,
             53: 14, 54: 15,
             55: 18, 56: 19, 57: 19, 58: 18,
             59: 16,
             60: 18, 61: 19, 62: 20, 63: 19,
             64: 25, 65: 27, 66: 29, 67: 33, 68: 37}

HB_G_SIDE = {26: 50, 27: 50, 28: 49, 29: 47, 30: 44, 31: 40, 32: 35, 33: 30,
             34: 25,
             35: 18, 36: 19, 37: 20, 38: 20, 39: 19, 40: 18,
             41: 15,
             42: 18, 43: 19, 44: 19,
             45: 17, 46: 16,
             47: 18, 48: 20, 49: 21, 50: 21, 51: 20, 52: 18,
             53: 14, 54: 15,
             55: 18, 56: 19, 57: 19, 58: 18,
             59: 16,
             60: 18, 61: 19, 62: 20,
             63: 58, 64: 64, 65: 69, 66: 71, 67: 73, 68: 74, 69: 74}

# 뒷머리 목덜미 — 들쭉날쭉하게
NAPE_B = {}
for _xs, _v in [(range(20, 34), 50), (range(34, 37), 46), (range(37, 40), 48),
                (range(40, 43), 47), (range(43, 47), 49), (range(47, 50), 48),
                (range(50, 53), 49), (range(53, 56), 47), (range(56, 59), 48),
                (range(59, 62), 46), (range(62, 80), 50)]:
    for _x in _xs:
        NAPE_B[_x] = _v


def hair_spans(girl, pose):
    u"""y -> [(x0,x1), ...]  머리카락 덩어리 실루엣."""
    if pose == 'up':
        base = head_rows_up()
        sp = dict((y, [v]) for y, v in base.items())
        if girl:
            tail = [(41, 28, 67), (42, 29, 66), (43, 30, 65), (44, 31, 64),
                    (45, 32, 63), (46, 34, 61), (47, 35, 60), (48, 36, 59),
                    (49, 37, 58), (50, 38, 57), (51, 38, 57), (52, 38, 57),
                    (53, 38, 57), (54, 37, 58), (55, 37, 58), (56, 36, 59),
                    (57, 36, 59), (58, 35, 60)]
            for y, a, b in tail:
                sp[y] = [(a, b)]
            for y in range(59, 86):
                sp[y] = [(36, 59)]
            for y in range(86, 95):
                sp[y] = [(37, 58)]
            for y in range(95, 100):
                sp[y] = [(38, 57)]
            for y in range(100, 104):
                sp[y] = [(40, 55)]
        return sp

    base = head_rows_side() if pose == 'side' else head_rows_down()
    sp = dict((y, [v]) for y, v in base.items())
    if not girl:
        return sp

    for y in range(30, 49):
        a, b = sp[y][0]
        sp[y] = [(min(26, a), max(69, b))]
    if pose == 'down':
        for y in range(49, 54):
            sp[y] = [(26, 32), (63, 69)]
        for y in range(54, 60):
            sp[y] = [(26, 31), (64, 69)]
        for y in range(60, 66):
            sp[y] = [(27, 31), (64, 68)]
        for y in range(66, 71):
            sp[y] = [(27, 30), (65, 68)]
        for y in range(71, 75):
            sp[y] = [(28, 30), (65, 67)]
    else:
        # 3/4 — 먼(오른) 쪽이 길고 가까운(왼) 쪽은 짧은 한 갈래
        sp[49] = [(26, 34), (62, 69)]
        sp[50] = [(27, 33), (62, 69)]
        sp[51] = [(28, 32), (62, 69)]
        for y in range(52, 70):
            sp[y] = [(62, 69)]
        for y in range(70, 75):
            sp[y] = [(63, 68)]
    return sp


# ---------------------------------------------------------------- 머리 그리기
def paint_head(c, girl, pose):
    face = head_rows_up() if pose == 'up' else (
        head_rows_side() if pose == 'side' else head_rows_down())
    hs = hair_spans(girl, pose)
    if pose == 'up':
        hb = dict((x, 300) for x in range(20, 80))
    elif pose == 'side':
        hb = HB_G_SIDE if girl else HB_B_SIDE
    else:
        hb = HB_G_DOWN if girl else HB_B_DOWN

    for y in sorted(hs):
        for a, b in hs[y]:
            if pose == 'up' and not girl:
                for x in range(a, b + 1):
                    if y <= NAPE_B.get(x, 300):
                        c.p(x, y, HR)
            else:
                c.row(y, a, b, HR)

    if pose != 'up':
        for y in sorted(face):
            a, b = face[y]
            for x in range(a, b + 1):
                if y > hb.get(x, -1):
                    c.p(x, y, SK)

    # ---- 명암 : 빛은 왼쪽 위. 정수리 등고선을 따라 띠를 얹는다
    top = {}
    for y in sorted(hs):
        for a, b in hs[y]:
            for x in range(a, b + 1):
                if c.g(x, y) in HAIRS and x not in top:
                    top[x] = y
    lit_to = 46 if pose == 'side' else 49
    for y in sorted(hs):
        for a, b in hs[y]:
            for x in range(a, b + 1):
                if c.g(x, y) != HR:
                    continue
                d = y - top.get(x, 0)
                if 2 <= d <= 7 and x <= lit_to - max(0, d - 3) * 2:
                    c.p(x, y, HR_L)
    for y in sorted(hs):
        for a, b in hs[y]:
            for x in range(a, b + 1):
                if c.g(x, y) != HR_L:
                    continue
                d = y - top.get(x, 0)
                if 32 <= x <= 47 and 3 <= d <= 4:
                    c.p(x, y, HR_LL)
    # 오른쪽·아래는 그늘
    for y in sorted(hs):
        for a, b in hs[y]:
            lo = max(a, b - 9) if b > 48 else b - 1
            for x in range(lo, b + 1):
                if c.g(x, y) == HR:
                    c.p(x, y, HR_D)

    # ---- 가닥
    if pose == 'up':
        LIGHT = set([HR, HR_L, HR_LL])
        bot = {}
        for y in sorted(hs):
            for a, b in hs[y]:
                for x in range(a, b + 1):
                    if c.g(x, y) in HAIRS:
                        bot[x] = y
        for (x, y), col in list(c.d.items()):
            if col in LIGHT and x in bot and y > bot[x] - 4:
                c.p(x, y, HR_D)
        strand(c, 56, 20, 44, 4, HR, lean=11, only=set([HR_D]))
        if girl:
            c.rect(38, 51, 57, 55, PT_D)
            c.rect(39, 52, 56, 54, PT_LL)
            strand(c, 41, 60, 96, 3, HR_D, lean=18, only=LIGHT)
            strand(c, 50, 60, 92, 3, HR, lean=-20, only=set([HR_D]))
    elif girl:
        for y in sorted(hs):
            if y < 33:
                continue
            for a, b in hs[y]:
                if b - a < 10 or True:
                    if a <= 30:
                        for x in range(a, a + 3):
                            if c.g(x, y) in (HR, HR_D):
                                c.p(x, y, HR_L)
                    if b >= 66:
                        for x in range(b - 8, b - 5):
                            if c.g(x, y) in (HR_D,):
                                c.p(x, y, HR)
        strand(c, 27, 36, 58, 2, HR_L, lean=9, only=set([HR, HR_D]))
        strand(c, 30, 44, 68, 2, HR_D, lean=-13, only=set([HR, HR_L]))
        strand(c, 64, 42, 66, 2, HR, lean=11, only=set([HR_D]))
        strand(c, 67, 36, 60, 2, HR_D, lean=-15, only=set([HR, HR_L]))

    # ---- 앞머리 밑 살결 그늘
    if pose != 'up':
        for x, by in hb.items():
            for k in (1, 2):
                y = by + k
                if y in face:
                    a, b = face[y]
                    if a <= x <= b:
                        c.pif(x, y, SK_D, SKINS)


# ---------------------------------------------------------------- 얼굴
EYE_MP = {'E': EYE, 'W': WHT, 'I': BROW, 'm': SK_M, 'd': SK_DD, '.': None}
MTH_MP = {'M': SK_M, 'L': SK_LL, 'd': SK_DD, '.': None}

# 반쯤 감긴 호선 — 속눈썹 윗줄이 아치, 흰자는 왼쪽 반짝임 하나뿐
EYE9 = ['...EEE...',
        '.EEEEEEE.',
        'mIWWIIIIm',
        'mIWWIIIIm',
        'mIIIEEIIm',
        '.ddddddd.']

EYE8 = ['..EEEE..',
        '.EEEEEE.',
        'mIWWIIIm',
        'mIWWIIIm',
        'mIIIEEIm',
        '.dddddd.']

EYE7 = ['..EEE..',
        '.EEEEE.',
        'mIWWIIm',
        'mIWWIIm',
        'mIIEEIm',
        '.ddddd.']

# 닫힌 채 넓게 휜 미소 — 입꼬리가 또렷이 올라가고 아랫입술이 밝다
MTH12 = ['MM........MM',
         '.MMM....MMM.',
         '...MMMMMM...',
         '....LLLL....']

MTH11 = ['MM.......MM',
         '.MMM...MMM.',
         '...MMMMM...',
         '....LLL....']


def face_shade(c, face, y0, y1):
    u"""그늘 쪽(오른쪽) 살결 두 칸을 한 단 낮춘다."""
    for y in range(y0, y1 + 1):
        if y not in face:
            continue
        a, b = face[y]
        n, x = 0, b
        while x >= a and n < 2:
            if c.g(x, y) in SKINS:
                c.pif(x, y, SK_D, SKINS)
                n += 1
            x -= 1


def face_down(c, girl):
    face = head_rows_down()
    face_shade(c, face, 24, 47)

    # 볼 홍조 — 눈 아래로 넓게
    for y, a, b in [(32, 32, 38), (33, 31, 39), (34, 31, 39), (35, 31, 39),
                    (36, 32, 38), (37, 33, 37)]:
        c.rowif(y, a, b, SK_CH, SKINS)
    for y, a, b in [(32, 57, 63), (33, 56, 64), (34, 56, 64), (35, 56, 64),
                    (36, 57, 63), (37, 58, 62)]:
        c.rowif(y, a, b, SK_CH, SKINS)

    # 눈썹 — 두 칸 두께의 순한 아치
    c.rowif(22, 35, 40, BROW, SKINS)
    c.rowif(23, 33, 37, BROW, SKINS)
    c.rowif(22, 55, 60, BROW, SKINS)
    c.rowif(23, 58, 62, BROW, SKINS)

    # 눈
    stamp(c, 34, 26, EYE9, EYE_MP)
    stamp(c, 53, 26, EYE9, EYE_MP)

    # 코 — 콧등 + 그늘 + 콧방울
    c.rowif(34, 47, 48, SK_D, SKINS)
    c.rowif(35, 46, 49, SK_D, SKINS)
    c.rowif(36, 45, 46, SK_M, SKINS)
    c.rowif(36, 49, 50, SK_M, SKINS)

    # 입
    stamp(c, 42, 40, MTH12, MTH_MP)


def face_side(c, girl):
    face = head_rows_side()
    face_shade(c, face, 24, 47)

    # 가까운(왼) 뺨은 넓고, 먼(오른) 뺨은 좁다
    for y, a, b in [(32, 36, 44), (33, 35, 45), (34, 35, 45), (35, 35, 45),
                    (36, 36, 44), (37, 37, 43)]:
        c.rowif(y, a, b, SK_CH, SKINS)
    for y, a, b in [(33, 58, 63), (34, 58, 63), (35, 58, 63), (36, 59, 62)]:
        c.rowif(y, a, b, SK_CH, SKINS)

    # 눈썹
    c.rowif(22, 41, 46, BROW, SKINS)
    c.rowif(23, 39, 43, BROW, SKINS)
    c.rowif(22, 56, 61, BROW, SKINS)
    c.rowif(23, 58, 62, BROW, SKINS)

    # 가까운 눈 8칸 / 먼 눈은 눌려 7칸
    stamp(c, 40, 26, EYE8, EYE_MP)
    stamp(c, 56, 26, EYE7, EYE_MP)

    # 귀 — 먼(오른) 쪽. 얼굴 가장자리에 붙여서, 옆으로 튀지 않게
    c.rowif(30, 64, 66, SK_M, SKINS)
    for _y in (31, 32, 33):
        c.pif(64, _y, SK_M, SKINS)
    c.rowif(34, 64, 66, SK_M, SKINS)

    # 코 — 돌아선 쪽으로
    c.rowif(34, 51, 52, SK_D, SKINS)
    c.rowif(35, 50, 53, SK_D, SKINS)
    c.rowif(36, 49, 50, SK_M, SKINS)
    c.rowif(36, 52, 53, SK_M, SKINS)

    # 입
    stamp(c, 46, 40, MTH11, MTH_MP)


# ---------------------------------------------------------------- 몸
def body(c, girl, pose):
    side = (pose == 'side')
    back = (pose == 'up')

    # ---- 목
    nx0, nx1 = (44, 53) if side else (42, 53)
    c.rect(nx0, 49, nx1, 53, SK)
    if not back:
        c.rect(nx0, 49, nx1, 50, SK_D)
    c.col(nx1, 49, 53, SK_D)
    c.col(nx1 - 1, 49, 53, SK_D)

    if side:
        ramp = [(54, 40, 57), (55, 37, 60), (56, 34, 63), (57, 31, 65), (58, 30, 66)]
        TL, TR = 36, 61
        AL0, AL1 = 29, 35
        AR0, AR1 = 62, 66
        sl_l, sl_r = 76, 72
    else:
        ramp = [(54, 38, 57), (55, 35, 60), (56, 33, 62), (57, 31, 64), (58, 29, 66)]
        TL, TR = 35, 60
        AL0, AL1 = 29, 34
        AR0, AR1 = 61, 66
        sl_l, sl_r = 74, 74

    for y, a, b in ramp:
        c.row(y, a, b, SH)
    c.rect(TL, 59, TR, 87, SH)
    c.rect(TL - 1, 88, TR + 1, 93, SH)
    c.rect(AL0, 59, AL1, sl_l, SH)
    c.rect(AR0, 59, AR1, sl_r, SH)

    # 윗도리 명암 — 왼쪽 밝고 오른쪽 어둡다
    for _y in range(59, 94):
        _w = 8 - (_y - 59) * 5 // 34
        c.rowif(_y, TL + 1, TL + _w, SH_L, SHRT)
        c.rowif(_y, TR - _w, TR, SH_D, SHRT)
    c.rectif(AL0, 59, AL1, sl_l, SH_L, SHRT)
    c.rectif(AR0, 59, AR1, sl_r, SH_D, SHRT)
    c.colif(TL, 59, 93, SH_D, SHRT)          # 가까운 팔이 지운 그늘
    c.colif(TR, 59, 93, SH_DD, SHRT)         # 먼 팔과의 경계
    c.rectif(AL1, 59, AL1, sl_l, SH_D, SHRT)
    # 소매 단
    c.rectif(AL0, sl_l - 1, AL1, sl_l, SH_LL, SHRT)
    c.rectif(AR0, sl_r - 1, AR1, sl_r, SH_LL, SHRT)
    # 옷단
    c.rowif(93, TL - 1, TR + 1, SH_DD, SHRT)

    # 깃
    if back:
        c.rowif(54, 41, 54, SH_LL, SHRT)
        c.rowif(55, 42, 53, SH_LL, SHRT)
    elif side:
        c.rowif(54, 41, 57, SH_LL, SHRT)
        c.rowif(55, 43, 56, SH_LL, SHRT)
        c.rowif(56, 46, 53, SH_LL, SHRT)
    else:
        c.rowif(54, 39, 56, SH_LL, SHRT)
        c.rowif(55, 41, 54, SH_LL, SHRT)
        c.rowif(56, 44, 51, SH_LL, SHRT)

    # ---- 팔뚝 + 손
    def arm(x0, x1, ytop, ybot, dim):
        c.rect(x0, ytop, x1, ybot, SK_D if dim else SK)
        if not dim:
            c.rectif(x1, ytop, x1, ybot, SK_D, SKINS)

    def hand(x0, x1, ytop, dim):
        base = SK_D if dim else SK
        c.rect(x0 + 1, ytop, x1 - 1, ytop + 1, base)
        c.rect(x0, ytop + 2, x1, ytop + 6, base)
        c.rect(x0 + 1, ytop + 7, x1 - 1, ytop + 7, base)
        if not dim:
            c.rectif(x1 - 1, ytop, x1, ytop + 7, SK_D, SKINS)

    arm(AL0 + 1, AL1, sl_l + 1, sl_l + 12, False)
    arm(AR0, AR1 - 1, sl_r + 1, sl_r + 12, side)
    hand(AL0, AL1 + 1, sl_l + 13, False)
    hand(AR0 - 1, AR1, sl_r + 13, side)

    # ---- 허리띠
    bl, br = TL - 1, TR + 1
    c.rect(bl, 94, br, 97, PT_DD)
    c.rect(bl, 94, br, 95, PT_D)
    c.rect(45, 94, 50, 97, PT_LL)
    c.rect(46, 95, 49, 96, PT_D)

    # ---- 아랫도리
    if girl:
        skirt = [(98, 34, 61), (99, 34, 61), (100, 33, 62), (101, 33, 62),
                 (102, 32, 63), (103, 32, 63), (104, 32, 63), (105, 31, 64),
                 (106, 31, 64), (107, 31, 64), (108, 30, 65), (109, 30, 65),
                 (110, 30, 65), (111, 29, 66), (112, 29, 66), (113, 29, 66),
                 (114, 29, 66), (115, 29, 66), (116, 29, 66)]
        for y, a, b in skirt:
            c.row(y, a, b, PT)
        for y, a, b in skirt:
            c.rowif(y, a, a + 3, PT_L, PNTS)
            c.rowif(y, b - 5, b, PT_D, PNTS)
        _pl = ((41, 100, 116), (50, 103, 116), (57, 99, 116)) if side else \
              ((38, 100, 116), (47, 103, 116), (55, 99, 116))
        for x0, y0, y1 in _pl:
            for y in range(y0, y1 + 1):
                c.pif(x0, y, PT_D, PNTS)
                c.pif(x0 + 1, y, PT_D, PNTS)
        c.row(116, 29, 66, PT_DD)
        # 맨다리
        if side:
            c.rect(47, 117, 57, 133, SK_D)
            c.rect(35, 117, 46, 134, SK)
            c.colif(45, 117, 134, SK_D, SKINS)
            c.colif(46, 117, 134, SK_DD, SKINS)
        else:
            c.rect(38, 117, 46, 134, SK)
            c.rect(49, 117, 57, 134, SK)
            c.colif(45, 117, 134, SK_D, SKINS)
            c.colif(46, 117, 134, SK_D, SKINS)
            c.colif(56, 117, 134, SK_D, SKINS)
            c.colif(57, 117, 134, SK_D, SKINS)
        # 단화
        if side:
            shoes = [(47, 60, 132, 142, SO_D), (33, 47, 134, 142, SO)]
        else:
            shoes = [(36, 46, 134, 142, SO), (49, 59, 134, 142, SO)]
        for a, b, y0, y1, col in shoes:
            c.rect(a + 1, y0, b - 1, y0 + 1, col)
            c.rect(a, y0 + 2, b, y1, col)
            c.rectif(b - 1, y0, b, y1, SO_D, SHOE)
            c.rect(a, y1 - 1, b, y1, SO_DD)
    else:
        c.rect(bl, 98, br, 104, PT)
        if side:
            c.rect(46, 105, 57, 128, PT_D)
            c.rect(34, 105, 47, 129, PT)
            c.col(47, 105, 129, PT_DD)
        else:
            c.rect(35, 105, 46, 129, PT)
            c.rect(49, 105, 60, 129, PT)
        c.rectif(bl, 98, bl + 3, 128, PT_L, PNTS)
        c.rectif(br - 4, 98, br, 128, PT_D, PNTS)
        if not side:
            c.colif(46, 105, 129, PT_D, PNTS)
            c.colif(49, 105, 129, PT_D, PNTS)
        # 장화
        if side:
            boots = [(47, 59, 126, 142, SO_D), (32, 46, 128, 142, SO)]
        else:
            boots = [(33, 46, 128, 142, SO), (49, 62, 128, 142, SO)]
        for a, b, y0, y1, col in boots:
            c.rect(a + 1, y0, b - 1, y0 + 1, col)
            c.rect(a, y0 + 2, b, y1, col)
            c.rectif(b - 2, y0, b, y1, SO_D, SHOE)
            c.rect(a, y1 - 2, b, y1, SO_DD)
            c.rect(a + 1, y0 + 2, b - 1, y0 + 3, PT_LL)
            c.rect(a + 1, y0 + 4, b - 1, y0 + 4, PT_D)

    if back:
        c.rectif(38, 137, 43, 142, SO_DD, SHOE)
        c.rectif(52, 137, 57, 142, SO_DD, SHOE)


# ---------------------------------------------------------------- 조립
def make(sex, kind):
    girl = (sex == 'girl')
    c = Cv()
    body(c, girl, kind)
    paint_head(c, girl, kind)
    if kind == 'down':
        face_down(c, girl)
    elif kind == 'side':
        face_side(c, girl)
    despeckle(c)
    hair_edge(c)
    outline(c)
    return finish(c, 'w96_q_%s_%s.png' % (sex, kind))


def main():
    for sex in ('boy', 'girl'):
        for kind in ('down', 'side', 'up'):
            print(make(sex, kind))


if __name__ == '__main__':
    main()
