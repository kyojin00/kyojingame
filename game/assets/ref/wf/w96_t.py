#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리틀 루트 주인공 도트 — 96 x 144, 방향 t (스프라이트 왕도).

90년대 SNES RPG 주인공 얼굴 문법:
  - 눈 하나가 얼굴 폭의 1/4. 두 눈 사이에 눈 하나 폭만큼 비운다.
  - 눈테 검정 금지. 아랫눈꺼풀은 살결 진한 단(SK_DD).
  - 흰자는 왼쪽 위 한 덩어리(빛점)만. 동공 양옆 초승달 금지.
  - 코는 점이 아니라 그늘 덩어리.
  - 입은 눈보다 넓다.
힘은 몸과 옷의 실루엣·명암에 준다.
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

RIMOF = {'sk': SK_DD, 'hr': HR_DD, 'sh': SH_DD, 'pt': PT_DD, 'so': SO_DD}


# ---------------------------------------------------------------- 캔버스
class Cv(object):
    def __init__(self):
        self.c = [[None] * W for _ in range(H)]
        self.m = [[None] * W for _ in range(H)]

    def put(self, x, y, col, mat=None):
        if 0 <= x < W and 0 <= y < H:
            self.c[y][x] = col
            if mat:
                self.m[y][x] = mat

    def row(self, y, x0, x1, col, mat=None):
        for x in range(x0, x1 + 1):
            self.put(x, y, col, mat)

    def box(self, x0, y0, x1, y1, col, mat=None):
        for y in range(y0, y1 + 1):
            self.row(y, x0, x1, col, mat)

    def clear(self, x0, y0, x1, y1):
        for y in range(max(y0, 0), min(y1, H - 1) + 1):
            for x in range(max(x0, 0), min(x1, W - 1) + 1):
                self.c[y][x] = None
                self.m[y][x] = None

    # 이미 불투명한 곳에만 색을 얹는다 (실루엣을 넓히지 않는다)
    def tint(self, x, y, col):
        if 0 <= x < W and 0 <= y < H and self.c[y][x] is not None:
            self.c[y][x] = col

    def trow(self, y, x0, x1, col):
        for x in range(x0, x1 + 1):
            self.tint(x, y, col)

    def tbox(self, x0, y0, x1, y1, col):
        for y in range(y0, y1 + 1):
            self.trow(y, x0, x1, col)

    def mrow(self, y, x0, x1, col, mat):
        """해당 재질인 칸에만 색을 얹는다."""
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H and self.m[y][x] == mat:
                self.c[y][x] = col

    def mbox(self, x0, y0, x1, y1, col, mat):
        for y in range(y0, y1 + 1):
            self.mrow(y, x0, x1, col, mat)


def band(cv, keys, col, mat, dx=0):
    """[(y,x0,x1)] 사이를 이어 붙인 '면'을 해당 재질 위에만 칠한다."""
    for i in range(len(keys) - 1):
        y0, a0, b0 = keys[i]
        y1, a1, b1 = keys[i + 1]
        n = max(y1 - y0, 1)
        for k in range(n):
            cv.mrow(y0 + k, a0 + (a1 - a0) * k // n + dx,
                    b0 + (b1 - b0) * k // n + dx, col, mat)
    y, a, b = keys[-1]
    cv.mrow(y, a + dx, b + dx, col, mat)


def rim_pass(cv):
    """실루엣 바깥 테두리 한 칸을 그 재질의 가장 어두운 단으로."""
    todo = []
    for y in range(H):
        for x in range(W):
            if cv.c[y][x] is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H) or cv.c[ny][nx] is None:
                    todo.append((x, y, RIMOF.get(cv.m[y][x], OL)))
                    break
    for x, y, col in todo:
        cv.c[y][x] = col


def expand(rows):
    d = {}
    for y0, y1, a, b in rows:
        for y in range(y0, y1 + 1):
            d[y] = (a, b)
    return d


# ---------------------------------------------------------------- 머리통
# 소년 폭 42 (27..68), 소녀는 각 변 한 칸 더 (26..69, 폭 44)
SKULL_DOWN = expand([
    (2, 2, 39, 56), (3, 3, 36, 59), (4, 4, 34, 61), (5, 5, 32, 63),
    (6, 6, 31, 64), (7, 7, 30, 65), (8, 9, 29, 66), (10, 11, 28, 67),
    (12, 38, 27, 68),
    (39, 40, 28, 67), (41, 41, 29, 66), (42, 42, 29, 66), (43, 43, 30, 65),
    (44, 44, 31, 64), (45, 45, 32, 63), (46, 46, 33, 62), (47, 47, 35, 60),
    (48, 48, 37, 58), (49, 49, 40, 55), (50, 50, 43, 52),
])

# 3/4 — 오른쪽(돌아선 쪽)으로 이목구비가 몰리고 턱끝이 오른쪽으로
SKULL_SIDE = expand([
    (2, 2, 39, 56), (3, 3, 36, 59), (4, 4, 34, 61), (5, 5, 32, 63),
    (6, 6, 31, 64), (7, 7, 30, 65), (8, 9, 29, 66), (10, 11, 28, 67),
    (12, 36, 27, 68),
    (37, 38, 27, 67), (39, 39, 27, 66), (40, 40, 27, 66), (41, 41, 28, 65),
    (42, 42, 28, 65), (43, 43, 29, 64), (44, 44, 30, 64), (45, 45, 32, 63),
    (46, 46, 34, 63), (47, 47, 36, 62), (48, 48, 39, 60), (49, 49, 42, 58),
    (50, 50, 45, 55),
])

SKULL_UP = expand([
    (2, 2, 39, 56), (3, 3, 36, 59), (4, 4, 34, 61), (5, 5, 32, 63),
    (6, 6, 31, 64), (7, 7, 30, 65), (8, 9, 29, 66), (10, 11, 28, 67),
    (12, 40, 27, 68),
    (41, 42, 28, 67), (43, 43, 29, 66), (44, 44, 30, 65), (45, 45, 31, 64),
    (46, 46, 32, 63), (47, 47, 34, 61), (48, 48, 36, 59), (49, 49, 38, 57),
    (50, 50, 41, 54),
])

SKULL = {'down': SKULL_DOWN, 'side': SKULL_SIDE, 'up': SKULL_UP}


def skull_of(sex, view):
    s = SKULL[view]
    out = {}
    for y, (a, b) in s.items():
        if sex == 'girl' and y >= 6:
            out[y] = (a - 1, b + 1)
        else:
            out[y] = (a, b)
    return out


# 앞머리 밑선: (x0, x1, 마지막 머리카락 줄)
BANGS = {
    ('boy', 'down'): [(28, 32, 23), (33, 36, 20), (37, 41, 17), (42, 46, 15),
                      (47, 51, 18), (52, 56, 20), (57, 61, 22), (62, 68, 23)],
    ('boy', 'side'): [(27, 32, 24), (33, 38, 21), (39, 44, 18), (45, 50, 16),
                      (51, 55, 18), (56, 60, 20), (61, 68, 22)],
    ('girl', 'down'): [(27, 32, 23), (33, 37, 21), (38, 42, 19), (43, 47, 18),
                       (48, 52, 19), (53, 57, 21), (58, 63, 22), (64, 69, 23)],
    ('girl', 'side'): [(26, 32, 24), (33, 38, 22), (39, 44, 19), (45, 50, 17),
                       (51, 56, 19), (57, 62, 21), (63, 69, 23)],
}


def bang_bottom(sex, view, x):
    for a, b, yb in BANGS[(sex, view)]:
        if a <= x <= b:
            return yb
    return -1


SIDEHAIR = {'boy': 3, 'girl': 4}


def draw_head_mass(cv, sex, view):
    sk = skull_of(sex, view)
    ys = sorted(sk)
    for y in ys:
        a, b = sk[y]
        cv.row(y, a, b, SK, 'sk')

    if view == 'up':
        for y in ys:
            a, b = sk[y]
            cv.row(y, a, b, HR, 'hr')
        return sk

    t = SIDEHAIR[sex]
    tl, tr = t, t
    if view == 'side':          # 가까운(왼) 쪽 옆머리가 더 두껍다
        tl, tr = t + 2, t - 1
    for y in ys:
        a, b = sk[y]
        for x in range(a, b + 1):
            if y <= bang_bottom(sex, view, x):
                cv.put(x, y, HR, 'hr')
        if y <= 39:
            kl, kr = tl, tr
        elif y <= 42:
            kl, kr = max(tl - 1, 1), max(tr - 1, 1)
        elif y <= 44:
            kl, kr = max(tl - 2, 1), max(tr - 2, 0)
        else:
            kl = kr = 0
        for x in range(a, a + kl):
            cv.put(x, y, HR, 'hr')
        for x in range(b - kr + 1, b + 1):
            cv.put(x, y, HR, 'hr')
        if y <= 12:
            cv.row(y, a, b, HR, 'hr')
    return sk


# ---------------------------------------------------------------- 머리 명암
def hair_split(view, y):
    """빛 반대쪽 경계 — 두상 곡면을 따라 비스듬히."""
    s = 3 if view == 'side' else 0
    return max(56, 66 - (y - 2) * 3 // 8) - s


# 왼쪽 끝은 실루엣까지 닿게 (사이에 밑색 한 칸이 끼지 않도록)
HL_CRESCENT = [(3, 36, 49), (4, 33, 46), (5, 31, 44), (6, 30, 42),
               (7, 29, 40), (8, 28, 38), (9, 28, 36), (10, 27, 35),
               (11, 29, 34), (12, 29, 33), (13, 30, 32)]


def shade_hair(cv, view):
    for y in range(0, 95):
        lim = hair_split(view, min(y, 40))
        for x in range(W):
            if cv.m[y][x] == 'hr' and x >= lim:
                cv.c[y][x] = HR_D
    off = -1 if view == 'side' else 0
    for y, a, b in HL_CRESCENT:
        cv.mrow(y, a + off, b + off, HR_L, 'hr')


# ---------------------------------------------------------------- 얼굴
def face_shade(cv, sex, view, sk):
    """얼굴 오른쪽(빛 반대쪽) 면 그늘 — 살결 칸에만, 넉넉한 면 하나로."""
    for y in range(36, 47):
        if y not in sk:
            continue
        xs = [x for x in range(W) if cv.m[y][x] == 'sk']
        if not xs:
            continue
        b = max(xs)
        cv.mrow(y, b - 3, b, SK_D, 'sk')
    # 턱 아래 모서리만 살짝
    cv.mrow(49, 40, 55, SK_D, 'sk')
    cv.mrow(50, 43, 52, SK_D, 'sk')


def eye(cv, x0, x1, y0, wide=True):
    """세로 다섯 줄 눈. 검정 테 없음. 흰자는 왼쪽 위 한 덩어리."""
    cv.trow(y0,     x0 + 1, x1 - 1, EYE)
    cv.trow(y0 + 1, x0,     x1,     EYE)
    cv.trow(y0 + 2, x0,     x1,     EYE)
    cv.trow(y0 + 3, x0,     x1,     EYE)
    cv.trow(y0 + 4, x0 + 1, x1 - 1, EYE)
    cv.trow(y0 + 1, x0 + 1, x0 + 2, WHT)       # 빛점 — 왼쪽 위 한 덩어리
    if wide:
        cv.trow(y0 + 2, x0 + 1, x0 + 2, WHT)
    cv.trow(y0 + 5, x0 + 1, x1 - 1, SK_DD)     # 아랫눈꺼풀 = 살결 진한 단


def brow(cv, x0, x1, y0, inner_low):
    n = (x1 - x0 + 1) // 2
    if inner_low:                      # 왼쪽 눈썹
        cv.trow(y0,     x0, x0 + n, BROW)
        cv.trow(y0 + 1, x0 + n - 1, x1, BROW)
    else:
        cv.trow(y0,     x1 - n, x1, BROW)
        cv.trow(y0 + 1, x0, x1 - n + 1, BROW)


def mouth(cv, cx, half, y0, sex):
    a, b = cx - half, cx + half
    cv.trow(y0,     a,     a + 1, SK_M)        # 올라간 입꼬리
    cv.trow(y0,     b - 1, b,     SK_M)
    cv.trow(y0 + 1, a,     b,     SK_M)
    cv.trow(y0 + 2, a + 2, b - 2, SK_M)        # 벌어진 입 안
    cv.trow(y0 + 3, a + 3, b - 3, SK_CH)       # 아랫입술 그늘


def nose(cv, cx, y0):
    cv.trow(y0,     cx,     cx + 2, SK_D)      # 콧등 — 빛 반대쪽에만
    cv.trow(y0 + 1, cx - 1, cx + 3, SK_D)
    cv.trow(y0 + 2, cx - 1, cx,     SK_M)      # 콧방울 그늘
    cv.trow(y0 + 2, cx + 2, cx + 3, SK_M)


def ear(cv, x0, x1, y0, flip=False):
    """얼굴에 붙은 둥근 귓바퀴. 손잡이처럼 튀지 않게."""
    if flip:
        cv.trow(y0,     x0,     x1 - 1, SK_D)
        cv.trow(y0 + 1, x0,     x1,     SK_D)
        cv.trow(y0 + 2, x0,     x1,     SK_D)
        cv.trow(y0 + 3, x0,     x1,     SK_D)
        cv.trow(y0 + 4, x0,     x1 - 1, SK_D)
        cv.trow(y0 + 2, x0,     x0 + 1, SK_M)
    else:
        cv.trow(y0,     x0 + 1, x1,     SK_D)
        cv.trow(y0 + 1, x0,     x1,     SK_D)
        cv.trow(y0 + 2, x0,     x1,     SK_D)
        cv.trow(y0 + 3, x0,     x1,     SK_D)
        cv.trow(y0 + 4, x0 + 1, x1,     SK_D)
        cv.trow(y0 + 2, x1 - 1, x1,     SK_M)


def face_down(cv, sex):
    if sex == 'boy':
        brow(cv, 34, 43, 24, True)
        brow(cv, 52, 61, 24, False)
    else:
        cv.trow(24, 36, 43, BROW)
        cv.trow(24, 52, 59, BROW)
        cv.trow(25, 34, 37, BROW)
        cv.trow(25, 58, 61, BROW)
    ear(cv, 30, 32, 32)                        # 귀 — 얼굴에 붙여서
    ear(cv, 63, 65, 32, flip=True)
    eye(cv, 35, 43, 30)
    eye(cv, 52, 60, 30)
    if sex == 'girl':
        cv.trow(29, 34, 37, EYE)               # 바깥 눈초리로 이어지는 속눈썹
        cv.trow(29, 58, 61, EYE)
    nose(cv, 47, 37)
    cv.trow(40, 34, 39, SK_CH)                 # 볼 홍조 — 넓게 퍼지게
    cv.trow(41, 33, 40, SK_CH)
    cv.trow(40, 56, 61, SK_CH)
    cv.trow(41, 55, 62, SK_CH)
    mouth(cv, 47, 6 if sex == 'boy' else 5, 43, sex)


def face_side(cv, sex):
    """이목구비가 돌아선 쪽(오른쪽)으로 몰린다. 먼 눈(오른쪽)이 눌린다."""
    if sex == 'boy':
        brow(cv, 37, 46, 24, True)
        brow(cv, 55, 62, 24, False)
    else:
        cv.trow(24, 39, 46, BROW)
        cv.trow(24, 55, 61, BROW)
        cv.trow(25, 37, 40, BROW)
        cv.trow(25, 60, 62, BROW)
    ear(cv, 32, 35, 32)                        # 가까운(왼) 쪽 귀만 — 크게
    eye(cv, 38, 46, 30)                        # 가까운 눈 — 온전한 폭
    eye(cv, 56, 61, 30, wide=False)            # 먼 눈 — 눌려 좁다
    if sex == 'girl':
        cv.trow(29, 37, 40, EYE)
        cv.trow(29, 59, 62, EYE)
    nose(cv, 52, 37)
    cv.trow(39, 56, 58, SK_D)                  # 콧등에서 먼 쪽 뺨으로 이어지는 그늘
    cv.trow(40, 56, 59, SK_D)
    cv.trow(41, 58, 61, SK_D)
    cv.trow(40, 36, 42, SK_CH)                 # 가까운 뺨 — 넓다
    cv.trow(41, 35, 43, SK_CH)
    cv.trow(42, 36, 42, SK_CH)
    cv.trow(40, 58, 62, SK_CH)                 # 먼 뺨 — 좁다
    cv.trow(41, 57, 62, SK_CH)
    mouth(cv, 51, 6 if sex == 'boy' else 5, 43, sex)


def head_back(cv, sex):
    """뒷모습 — 가마, 목덜미, 귓바퀴 끝."""
    for y, a, b in [(5, 45, 51), (6, 44, 48), (7, 46, 50), (8, 48, 51)]:
        cv.mrow(y, a, b, HR_D, 'hr')
    if sex == 'boy':
        for y, a, b in [(44, 35, 42), (45, 33, 46), (46, 33, 60),
                        (47, 35, 59), (48, 37, 57), (49, 39, 55),
                        (50, 42, 53)]:
            cv.mrow(y, a, b, HR_D, 'hr')
        for y, a, b in [(43, 36, 41), (44, 35, 40), (45, 34, 39)]:
            cv.mrow(y, a, b, HR_L, 'hr')


# ---------------------------------------------------------------- 목
def neck(cv, view):
    a, b = (41, 52) if view == 'side' else (42, 53)
    top = 51 if view != 'up' else 47
    cv.box(a, top, b, 58, SK_D, 'sk')
    cv.box(a + 2, top, b - 2, top + 1, SK_M, 'sk')
    if view == 'up':
        cv.box(a + 1, 50, b - 1, 56, SK, 'sk')


# ---------------------------------------------------------------- 몸통
def geom(sex, view):
    if sex == 'boy':
        g = dict(sh_l=29, sh_r=66, ch_l=33, ch_r=62, wa_l=35, wa_r=60,
                 al=(30, 35), ar=(60, 65), hl=(29, 36), hr=(59, 66))
    else:
        g = dict(sh_l=31, sh_r=64, ch_l=34, ch_r=61, wa_l=36, wa_r=59,
                 al=(32, 37), ar=(58, 63), hl=(31, 38), hr=(57, 64))
    if view == 'side':                        # 어깨가 비틀린다
        g['sh_l'] -= 1
        g['sh_r'] -= 3
        for k in ('ch_l', 'ch_r', 'wa_l', 'wa_r'):
            g[k] -= 2
        g['al'] = (g['al'][0] - 2, g['al'][1] - 1)
        g['ar'] = (g['ar'][0] - 3, g['ar'][1] - 3)
        g['hl'] = (g['hl'][0] - 2, g['hl'][1] - 1)
        g['hr'] = (g['hr'][0] - 3, g['hr'][1] - 3)
    return g


def torso(cv, sex, view, g):
    sl, sr = g['sh_l'], g['sh_r']
    ramp = [(57, sl + 6, sr - 6), (58, sl + 4, sr - 4),
            (59, sl + 2, sr - 2), (60, sl + 1, sr - 1)]
    if view == 'side':        # 가까운(왼) 어깨가 한 줄 늦게 더 벌어진다
        ramp = [(57, sl + 8, sr - 4), (58, sl + 6, sr - 2),
                (59, sl + 3, sr - 1), (60, sl + 1, sr - 1)]
    for y, a, b in ramp:
        cv.row(y, a, b, SH, 'sh')
    cv.box(sl, 61, sr, 72, SH, 'sh')                       # 반소매까지
    cv.box(g['ch_l'], 61, g['ch_r'], 74, SH, 'sh')
    cv.box(g['wa_l'], 75, g['wa_r'], 85, SH, 'sh')         # 허리
    cv.box(g['ch_l'], 86, g['ch_r'], 93, SH, 'sh')         # 밑단


def shade_shirt(cv, sex, view, g):
    sl, sr = g['sh_l'], g['sh_r']
    dx = sr - 66 if sex == 'boy' else sr - 63
    band(cv, [(57, 58, 70), (60, 56, 70), (66, 55, 70), (72, 55, 70),
              (78, 56, 70), (86, 54, 70), (93, 53, 70)], SH_D, 'sh', dx)
    dx2 = sl - 29 if sex == 'boy' else sl - 32
    band(cv, [(61, 31, 40), (65, 31, 42), (70, 31, 42), (75, 33, 41),
              (80, 34, 40), (85, 36, 39)], SH_L, 'sh', dx2)
    # 목둘레 — 뒤는 높고 앞은 파이게
    if view == 'up':
        cv.mrow(57, 40, 55, SH_LL, 'sh')
        cv.mrow(58, 39, 56, SH_LL, 'sh')
        cv.mrow(59, 41, 54, SH_DD, 'sh')
    elif view == 'side':
        cv.mrow(57, 39, 52, SH_LL, 'sh')
        cv.mrow(58, 38, 53, SH_LL, 'sh')
        cv.mrow(59, 42, 50, SH_DD, 'sh')
        cv.mrow(60, 43, 49, SH_DD, 'sh')
    else:
        cv.mrow(57, 41, 54, SH_LL, 'sh')
        cv.mrow(58, 40, 55, SH_LL, 'sh')
        cv.mrow(59, 44, 51, SH_DD, 'sh')
        cv.mrow(60, 45, 50, SH_DD, 'sh')
    # 소매단 — 두께를 좌우 다르게
    cv.mrow(70, sl, sl + 5, SH_DD, 'sh')
    cv.mrow(71, sl, sl + 6, SH_DD, 'sh')
    cv.mrow(72, sl, sl + 6, SH_DD, 'sh')
    cv.mrow(71, sr - 5, sr, SH_DD, 'sh')
    cv.mrow(72, sr - 6, sr, SH_DD, 'sh')
    # 옷 주름 — 좌우 비대칭, 두 칸 이상
    w = g['wa_l']
    band(cv, [(80, w + 2, w + 8), (83, w + 4, w + 9), (85, w + 6, w + 10)],
         SH_D, 'sh')
    band(cv, [(88, g['ch_l'] + 2, g['ch_l'] + 7),
              (92, g['ch_l'] + 3, g['ch_l'] + 9)], SH_D, 'sh')


def arms(cv, sex, view, g):
    la0, la1 = g['al']
    ra0, ra1 = g['ar']
    hl0, hl1 = g['hl']
    hr0, hr1 = g['hr']
    cv.box(la0, 73, la1, 94, SK, 'sk')
    cv.box(ra0, 73, ra1, 94, SK, 'sk')
    for x0, x1 in ((hl0, hl1), (hr0, hr1)):
        cv.row(95, x0 + 1, x1 - 1, SK, 'sk')
        cv.box(x0, 96, x1, 100, SK, 'sk')
        cv.row(101, x0 + 1, x1 - 1, SK, 'sk')
    # 팔 안쪽 그늘 — 몸통과 갈라 보이게
    for y in range(73, 102):
        cv.tint(la1, y, SK_D)
    cv.mbox(ra0, 73, ra1, 101, SK_D, 'sk')
    cv.mbox(hr0, 95, hr1, 101, SK_D, 'sk')
    if view == 'side':
        for y in range(73, 102):                        # 먼 팔은 한 단 뒤로
            cv.tint(ra0 - 1, y, SK_M)
            cv.tint(ra0, y, SK_M)
        for y in range(95, 102):
            cv.tint(hr0 - 1, y, SK_M)
    cv.mrow(98, hl0 + 1, hl1 - 1, SK_D, 'sk')            # 손가락 골
    cv.mrow(99, hl0 + 2, hl1 - 2, SK_D, 'sk')


# ---------------------------------------------------------------- 아랫도리
def legs_boy(cv, view):
    if view == 'side':
        hip = (32, 59)
        L, R = (34, 48), (46, 58)
        gap = None
    else:
        hip = (33, 62)
        L, R = (33, 46), (49, 62)
        gap = (47, 48)

    cv.box(hip[0], 92, hip[1], 95, PT_DD, 'pt')          # 허리띠
    cv.box(hip[0], 96, hip[1], 106, PT, 'pt')
    if view == 'side':
        cv.box(R[0], 107, R[1], 126, PT, 'pt')      # 먼 다리 먼저 (뒤)
        cv.box(L[0], 107, L[1], 126, PT, 'pt')      # 가까운 다리 나중 (앞)
    else:
        cv.box(L[0], 107, L[1], 126, PT, 'pt')
        cv.box(R[0], 107, R[1], 126, PT, 'pt')
    if gap:
        cv.clear(gap[0], 107, gap[1], 142)

    d = hip[1] - 62
    band(cv, [(96, 55, 70), (104, 53, 70), (110, 52, 70), (118, 53, 70),
              (126, 54, 70)], PT_D, 'pt', d)
    d0 = hip[0] - 33
    band(cv, [(97, 35, 42), (104, 34, 42), (112, 34, 41), (120, 36, 40)],
         PT_L, 'pt', d0)
    if view == 'side':
        cv.mbox(L[1] + 1, 107, R[1], 126, PT_D, 'pt')    # 먼 다리는 뒤로
        for y in range(107, 127):
            cv.tint(L[1], y, PT_DD)
            cv.tint(L[1] - 1, y, PT_D)
    band(cv, [(114, L[0] + 1, L[0] + 7), (117, L[0] + 3, L[0] + 8)],
         PT_D, 'pt')                                     # 무릎 주름 — 한쪽만
    band(cv, [(101, hip[0] + 2, hip[0] + 7), (104, hip[0] + 4, hip[0] + 10)],
         PT_D, 'pt')

    # 장화 — 목이 넓고 발이 좁다
    bl = (L[0] - 1, L[1])
    br = (R[0], R[1] + 1)
    if view == 'side':
        bl = (L[0] - 2, L[1] + 1)
        br = (L[1] + 1, R[1] + 1)
    if view == 'side':
        cv.box(br[0], 127, br[1], 142, SO, 'so')    # 먼 발이 뒤에, 조금 위
        cv.box(bl[0], 124, bl[1], 142, SO, 'so')
        for y in range(127, 143):
            cv.tint(bl[1], y, SO_DD)
    else:
        cv.box(bl[0], 124, bl[1], 142, SO, 'so')
        cv.box(br[0], 125, br[1], 142, SO, 'so')
    if gap:
        cv.clear(gap[0], 124, gap[1], 142)
    cv.mbox(bl[0], 124, bl[1], 128, SO_D, 'so')          # 접힌 목
    cv.mbox(br[0], 125, br[1], 130, SO_D, 'so')
    cv.mbox(br[1] - 5, 130, br[1], 142, SO_D, 'so')
    band(cv, [(131, bl[0] + 1, bl[0] + 4), (135, bl[0] + 1, bl[0] + 6),
              (138, bl[0] + 2, bl[0] + 7)], SO, 'so')
    cv.mbox(bl[0], 139, bl[1], 142, SO_DD, 'so')         # 바닥창
    cv.mbox(br[0], 139, br[1], 142, SO_DD, 'so')


def legs_girl(cv, view):
    if view == 'side':
        wst = (34, 57)
        keys = [(93, 34, 57), (99, 32, 59), (105, 30, 62), (111, 28, 64),
                (115, 28, 64)]
        L, R = (38, 45), (46, 53)
        gap = None
    else:
        wst = (35, 60)
        keys = [(93, 35, 60), (99, 33, 62), (105, 31, 64), (111, 29, 66),
                (115, 29, 66)]
        L, R = (39, 46), (49, 56)
        gap = (47, 48)

    for i in range(len(keys) - 1):
        y0, a0, b0 = keys[i]
        y1, a1, b1 = keys[i + 1]
        n = max(y1 - y0, 1)
        for k in range(n):
            a = a0 + (a1 - a0) * k // n
            b = b0 + (b1 - b0) * k // n
            cv.row(y0 + k, a, b, PT, 'pt')
    cv.row(keys[-1][0], keys[-1][1], keys[-1][2], PT, 'pt')
    cv.box(wst[0], 90, wst[1], 93, PT_DD, 'pt')

    d = wst[1] - 60
    band(cv, [(94, 52, 70), (100, 51, 70), (106, 50, 70), (112, 49, 70),
              (115, 49, 70)], PT_D, 'pt', d)
    d0 = wst[0] - 35
    band(cv, [(96, 33, 40), (102, 31, 40), (108, 30, 39), (113, 29, 38)],
         PT_L, 'pt', d0)
    for y in range(100, 116):                            # 치마 주름 — 비대칭
        cv.mrow(y, 43, 46, PT_D, 'pt')
    for y in range(106, 116):
        cv.mrow(y, 35, 38, PT_D, 'pt')
    cv.mbox(26, 113, 70, 115, PT_DD, 'pt')               # 치마단

    cv.box(L[0], 112, L[1], 133, SK, 'sk')
    cv.box(R[0], 112, R[1], 133, SK, 'sk')
    if gap:
        for y in range(116, 134):
            for x in range(gap[0], gap[1] + 1):
                if cv.m[y][x] == 'sk':
                    cv.c[y][x] = None
                    cv.m[y][x] = None
    cv.mbox(L[1] - 1, 116, L[1], 133, SK_D, 'sk')
    cv.mbox(R[0], 116, R[1], 133, SK_D, 'sk')
    if view == 'side':
        cv.mbox(R[0], 116, R[1], 133, SK_M, 'sk')
        for y in range(116, 134):
            cv.tint(L[1], y, SK_DD)

    sl = (L[0] - 3, L[1] + 1)
    sr = (R[0] - 1, R[1] + 3)
    if view == 'side':
        sl = (L[0] - 4, L[1] + 1)
        sr = (R[0], R[1] + 3)
    cv.box(sl[0], 134, sl[1], 142, SO, 'so')
    cv.box(sr[0], 134, sr[1], 142, SO, 'so')
    if gap:
        for y in range(134, 143):
            for x in range(gap[0], gap[1] + 1):
                if cv.m[y][x] == 'so':
                    cv.c[y][x] = None
                    cv.m[y][x] = None
    cv.mbox(sr[0], 134, sr[1], 142, SO_D, 'so')
    band(cv, [(136, sl[0] + 1, sl[0] + 4), (139, sl[0] + 1, sl[0] + 6)],
         SO, 'so')
    cv.mbox(sl[0], 140, sl[1], 142, SO_DD, 'so')
    cv.mbox(sr[0], 140, sr[1], 142, SO_DD, 'so')


# ---------------------------------------------------------------- 소녀 긴 머리
def lobe(a_keys):
    """[(y, x0, x1)] 사이를 채워 한 갈래를 만든다."""
    out = []
    for i in range(len(a_keys) - 1):
        y0, a0, b0 = a_keys[i]
        y1, a1, b1 = a_keys[i + 1]
        n = max(y1 - y0, 1)
        for k in range(n):
            out.append((y0 + k, a0 + (a1 - a0) * k // n, b0 + (b1 - b0) * k // n))
    out.append(a_keys[-1])
    return out


def girl_hair_back(cv, view):
    if view == 'down':
        left = lobe([(43, 30, 35), (46, 27, 35), (56, 26, 35), (68, 26, 34),
                     (74, 28, 32), (77, 30, 31)])
        right = [(y, 95 - b, 95 - a) for y, a, b in left]
        segs = left + right
    elif view == 'side':
        left = lobe([(42, 29, 34), (45, 26, 35), (56, 26, 36), (70, 26, 35),
                     (78, 28, 33), (82, 30, 32)])
        right = lobe([(41, 62, 67), (44, 62, 69), (50, 63, 69), (58, 63, 68),
                      (65, 64, 68), (70, 65, 67)])
        segs = left + right
    else:
        # 목덜미에서 한 다발로 모여 등을 타고 내려간다 — 어깨선이 드러나게
        segs = lobe([(40, 28, 67), (44, 26, 69), (50, 27, 68), (54, 31, 64),
                     (58, 37, 58), (70, 37, 58), (74, 38, 57)])
        for a, b, yb in ((38, 43, 78), (44, 49, 81), (50, 55, 76)):
            for y in range(74, yb + 1):
                segs.append((y, a, b))
    for y, a, b in segs:
        cv.row(y, a, b, HR, 'hr')


def girl_hair_shade(cv, view):
    lim = 50 if view == 'side' else 52
    for y in range(40, 95):
        for x in range(W):
            if cv.m[y][x] == 'hr' and x >= lim:
                cv.c[y][x] = HR_D
    if view == 'up':
        band(cv, [(42, 32, 38), (50, 31, 37), (58, 38, 42), (70, 38, 42),
                  (77, 39, 42)], HR_L, 'hr')
        band(cv, [(44, 43, 49), (54, 44, 50), (64, 45, 50), (76, 45, 50)],
             HR_D, 'hr')
        band(cv, [(46, 57, 64), (54, 55, 62), (60, 52, 57), (72, 52, 57),
                  (79, 51, 56)], HR_DD, 'hr')
    elif view == 'down':
        cv.mbox(27, 48, 30, 70, HR_L, 'hr')
        cv.mbox(65, 52, 68, 68, HR_DD, 'hr')
    else:
        cv.mbox(27, 48, 31, 76, HR_L, 'hr')
        cv.mbox(65, 52, 68, 64, HR_DD, 'hr')


# ---------------------------------------------------------------- 조립
def build(sex, view):
    cv = Cv()
    if sex == 'girl' and view != 'up':
        girl_hair_back(cv, view)          # 앞/옆에서는 어깨 뒤로 넘어간다
    sk = draw_head_mass(cv, sex, view)
    neck(cv, view)
    g = geom(sex, view)
    torso(cv, sex, view, g)
    if sex == 'girl' and view == 'up':
        girl_hair_back(cv, view)          # 뒤에서는 등을 덮는다
    (legs_boy if sex == 'boy' else legs_girl)(cv, view)
    arms(cv, sex, view, g)

    shade_hair(cv, view)
    if sex == 'girl':
        girl_hair_shade(cv, view)
    if view != 'up':
        face_shade(cv, sex, view, sk)
    shade_shirt(cv, sex, view, g)

    if view == 'down':
        face_down(cv, sex)
    elif view == 'side':
        face_side(cv, sex)
    else:
        head_back(cv, sex)

    rim_pass(cv)
    return cv


def save(cv, path):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            c = cv.c[y][x]
            if c is not None:
                px[x, y] = (c[0], c[1], c[2], 255)
    im.save(path)


def main():
    for sex in ('boy', 'girl'):
        for view in ('down', 'side', 'up'):
            save(build(sex, view), 'w96_t_%s_%s.png' % (sex, view))
    print('wrote 6')


if __name__ == '__main__':
    main()
