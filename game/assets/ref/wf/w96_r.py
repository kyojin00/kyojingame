#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리틀 루트 주인공 도트 — 96 x 144 청키 레트로 / 방향 r (또렷한 만화).

눈은 크지 않다(얼굴 폭의 1/4). 검정 테 없이 윗속눈썹만 EYE,
아랫테는 살결 진한 단. 흰자 초승달 없음. 입은 눈보다 넓은 고양이 입.
"""
import os
from PIL import Image

W, H = 96, 144

SK, SK_L, SK_D            = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD           = (82,53,33), (56,37,25), (39,26,18)
OL, EYE, BROW, WHT        = (26,20,28), (66,32,30), (136,70,42), (246,242,234)

DARK = {'skin': SK_DD, 'hair': HR_DD, 'shirt': SH_DD, 'pants': PT_DD, 'shoe': SO_DD}


class Cv(object):
    def __init__(self):
        self.p, self.m = {}, {}

    def s(self, x, y, c, mat):
        if 0 <= x < W and 0 <= y < H:
            self.p[(x, y)] = c
            self.m[(x, y)] = mat

    def span(self, y, x0, x1, c, mat):
        for x in range(x0, x1 + 1):
            self.s(x, y, c, mat)

    def rect(self, x0, y0, x1, y1, c, mat):
        for y in range(y0, y1 + 1):
            self.span(y, x0, x1, c, mat)


def outline(cv):
    ch = {}
    for (x, y), mat in cv.m.items():
        d = DARK.get(mat)
        if d is None:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in cv.p:
                ch[(x, y)] = d
                break
    cv.p.update(ch)


def despeckle(cv):
    """한 칸짜리 점·얼룩·먼지를 지운다 (게임 크기에서 먼지로 보인다)."""
    N8 = ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1))
    for _ in range(3):
        ch = {}
        for (x, y), c in cv.p.items():
            nb, edge = [], False
            for dx, dy in N8:
                k = (x + dx, y + dy)
                if k in cv.p:
                    nb.append(cv.p[k])
                elif abs(dx) + abs(dy) == 1:
                    edge = True
            if edge or not nb or c in nb:
                continue
            ch[(x, y)] = max(set(nb), key=nb.count)
        if not ch:
            break
        cv.p.update(ch)


def save(cv, path):
    xs = [x for (x, y) in cv.p]
    cen = (min(xs) + max(xs)) / 2.0
    lo = int((47.5 - cen) // 1)
    sh = lo if abs(cen + lo - 47.5) <= abs(cen + lo + 1 - 47.5) else lo + 1
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for (x, y), c in cv.p.items():
        nx = x + sh
        if 0 <= nx < W:
            px[nx, y] = (c[0], c[1], c[2], 255)
    im.save(path)


def band(tbl):
    out = {}
    for (a, b), (x0, x1) in tbl:
        for y in range(a, b + 1):
            out[y] = (x0, x1)
    return out


# ---------------------------------------------------------------- 형태표
FACE = band([
    ((10, 10), (33, 62)), ((11, 11), (32, 63)), ((12, 12), (31, 64)),
    ((13, 34), (30, 65)),
    ((35, 36), (31, 64)), ((37, 38), (32, 63)), ((39, 40), (33, 62)),
    ((41, 41), (34, 61)), ((42, 42), (35, 60)), ((43, 43), (36, 59)),
    ((44, 44), (37, 58)), ((45, 45), (38, 57)), ((46, 46), (40, 55)),
    ((47, 47), (41, 54)), ((48, 48), (43, 52)), ((49, 49), (44, 51)),
])

SKULL = band([
    ((1, 1), (38, 57)), ((2, 2), (35, 60)), ((3, 3), (33, 62)),
    ((4, 4), (31, 64)), ((5, 5), (30, 65)), ((6, 6), (29, 66)),
    ((7, 8), (28, 67)), ((9, 31), (27, 68)), ((32, 32), (28, 67)),
    ((33, 33), (29, 66)), ((34, 34), (30, 65)),
])

# 앞머리 — 오른쪽으로 쓸린 갈래 넷. 끝이 뾰족하고 다음 갈래에서 툭 끊긴다.
BANG_B = {
    30: 15, 31: 15, 32: 16, 33: 16, 34: 17, 35: 17, 36: 18, 37: 18,
    38: 19, 39: 19, 40: 15, 41: 15, 42: 16, 43: 16, 44: 17, 45: 17,
    46: 18, 47: 18, 48: 14, 49: 14, 50: 15, 51: 15, 52: 16, 53: 16,
    54: 17, 55: 17, 56: 14, 57: 15, 58: 15, 59: 16, 60: 16, 61: 17,
    62: 17, 63: 17, 64: 18, 65: 18,
}

# 여자 앞머리 — 가르마가 왼쪽에 있고 가운데 한 갈래가 길게 내려온다.
GBANG = {
    30: 16, 31: 17, 32: 17, 33: 18, 34: 18, 35: 19, 36: 19, 37: 20,
    38: 15, 39: 16, 40: 16, 41: 17, 42: 17, 43: 18, 44: 18, 45: 21,
    46: 21, 47: 15, 48: 15, 49: 16, 50: 16, 51: 17, 52: 17, 53: 18,
    54: 18, 55: 14, 56: 15, 57: 15, 58: 16, 59: 16, 60: 17, 61: 17,
    62: 18, 63: 18, 64: 19, 65: 19,
}

# 여자 옆머리. 정면은 좌우 대칭, 3/4 은 먼(오른) 쪽이 길고 가까운(왼) 쪽은 짧다.
GLOCK = band([
    ((18, 40), (26, 29)), ((41, 52), (25, 30)), ((53, 64), (25, 31)),
    ((65, 70), (25, 31)), ((71, 74), (26, 30)), ((75, 77), (27, 29)),
    ((78, 79), (27, 28)),
])
GLOCK_NEAR = band([
    ((20, 49), (28, 33)), ((50, 58), (27, 33)), ((59, 63), (28, 32)),
    ((64, 66), (29, 31)), ((67, 68), (30, 31)),
])
GLOCK_FAR = band([
    ((20, 44), (67, 70)), ((45, 58), (66, 71)), ((59, 72), (65, 72)),
    ((73, 80), (66, 71)), ((81, 86), (67, 70)), ((87, 89), (68, 69)),
])

BACK_B = band([
    ((35, 38), (27, 68)), ((39, 39), (28, 67)), ((40, 40), (28, 66)),
    ((41, 41), (29, 65)), ((42, 42), (30, 64)), ((43, 43), (32, 62)),
    ((44, 44), (35, 59)), ((45, 45), (39, 56)),
])

BACK_G = band([
    ((35, 48), (27, 68)), ((49, 56), (26, 69)), ((57, 66), (30, 65)),
    ((67, 76), (33, 62)), ((77, 84), (36, 59)), ((85, 89), (39, 56)),
    ((90, 91), (43, 52)),
])


# ---------------------------------------------------------------- 이목구비
def eye(cv, x0, y0, w, out_left):
    """9칸(먼 눈 6칸). 속눈썹 윗줄만 EYE, 아랫테는 살결 진한 단.
    흰자는 두지 않고 홍채가 눈을 채운다 — 초승달 둘이 생기면 사시가 된다."""
    x1 = x0 + w - 1
    cv.span(y0, x0, x1, EYE, 'eyelid')                       # 윗속눈썹
    cv.span(y0 + 1, x0, x1, HR_D, 'eyelid')                  # 눈꺼풀에 가린 윗홍채
    cv.span(y0 + 2, x0, x1, HR_D, 'eyelid')
    cv.span(y0 + 3, x0, x1, HR, 'eyelid')                    # 빛 받는 아랫홍채
    cv.span(y0 + 4, x0, x1, HR, 'eyelid')
    cv.span(y0 + 5, x0 + 1, x1 - 1, HR, 'eyelid')
    cv.span(y0 + 6, x0 + 1, x1 - 1, SK_DD, 'skin')           # 아랫테 — 살결 진한 단
    if out_left:                                             # 바깥 눈꼬리
        cv.span(y0 + 1, x0, x0 + 1, EYE, 'eyelid')
        cv.s(x0 - 1, y0, EYE, 'eyelid')
        cv.s(x0 - 1, y0 + 1, EYE, 'eyelid')
    else:
        cv.span(y0 + 1, x1 - 1, x1, EYE, 'eyelid')
        cv.s(x1 + 1, y0, EYE, 'eyelid')
        cv.s(x1 + 1, y0 + 1, EYE, 'eyelid')
    pw = 3 if w >= 9 else 2
    px0 = x0 + (w - pw) // 2
    cv.rect(px0, y0 + 1, px0 + pw - 1, y0 + 5, OL, 'eyelid')  # 동공
    cv.rect(px0 - 1, y0 + 1, px0, y0 + 2, WHT, 'eyelid')      # 반사점


def brow(cv, x0, y0, w, inner_right):
    x1 = x0 + w - 1
    if inner_right:
        cv.span(y0,     x0 + 2, x1, BROW, 'brow')
        cv.span(y0 + 1, x0,     x1 - 1, BROW, 'brow')
    else:
        cv.span(y0,     x0, x1 - 2, BROW, 'brow')
        cv.span(y0 + 1, x0 + 1, x1, BROW, 'brow')


def nose(cv, cx, y0):
    cv.rect(cx - 1, y0, cx, y0 + 1, SK_L, 'skin')        # 콧등 (왼쪽 위 빛)
    cv.s(cx + 1, y0 + 1, SK_D, 'skin')
    cv.span(y0 + 2, cx - 2, cx + 1, SK_M, 'skin')        # 콧방울
    cv.span(y0 + 3, cx - 1, cx + 1, SK_D, 'skin')        # 코밑 그늘


def mouth(cv, cx, y0):
    """고양이 입 (w) — 입꼬리·가운데 봉우리가 올라가고 아랫입술 한 단."""
    xl, xr = cx - 6, cx + 5
    for x in (xl, xl + 1, cx - 1, cx, xr - 1, xr):
        cv.s(x, y0, SK_M, 'skin')                        # 입꼬리 · 가운데 봉우리
    cv.span(y0 + 1, xl + 1, xr - 1, SK_M, 'skin')        # 두 골을 잇는 웃음선
    cv.span(y0 + 2, xl + 2, xr - 2, SK_D, 'skin')        # 아랫입술 한 단


def blush(cv, x0, x1, y0):
    cv.rect(x0, y0, x1, y0 + 1, SK_CH, 'skin')
    cv.rect(x0 + 1, y0 + 2, x1 - 1, y0 + 2, SK_CH, 'skin')


def shade_hair(cv):
    """빛은 왼쪽 위. 띠가 아니라 면으로 나눈다 (면마다 단색)."""
    hp = [k for k, m in cv.m.items() if m == 'hair']
    cols, rows = {}, {}
    for (x, y) in hp:
        cols.setdefault(x, []).append(y)
        rows.setdefault(y, []).append(x)
    for k in cols:
        cols[k].sort()
    for k in rows:
        rows[k].sort()
    for (x, y) in hp:
        ybot = cols[x][-1]
        xl, xr = rows[y][0], rows[y][-1]
        c = HR
        if y <= 44 and x > 56 + y * 0.12:
            c = HR_D                                     # 오른쪽 그늘 면
        if x >= xr - 2 and y >= 4:
            c = HR_D
        if (x - 27) + (y - 1) * 1.3 < 20:
            c = HR_L                                     # 왼쪽 위 빛 면
        if y > 34 and x >= xr - 3:
            c = HR_D
        if y > 34 and x <= xl + 3:
            c = HR_L                                     # 늘어진 갈래의 빛
        if ybot < 34 and y >= ybot:
            c = HR_DD                                    # 앞머리 끝
        cv.p[(x, y)] = c


def lock_spans(kind, sex):
    """여자 옆머리 구간 목록 [(y, x0, x1), ...]."""
    out = []
    if kind == 'side':
        for y, (a, b) in GLOCK_NEAR.items():
            out.append((y, a, b))
        for y, (a, b) in GLOCK_FAR.items():
            out.append((y, a, b))
    else:
        for y, (a, b) in GLOCK.items():
            out.append((y, a, b))
            out.append((y, 95 - b, 95 - a))
    return out


def head(cv, sex, kind):
    if kind == 'up':
        for y, (x0, x1) in SKULL.items():
            cv.span(y, x0, x1, HR, 'hair')
        tbl = BACK_G if sex == 'girl' else BACK_B
        for y, (x0, x1) in tbl.items():
            cv.span(y, x0, x1, HR, 'hair')
        if sex == 'boy':
            for x, d in ((33, 1), (34, 2), (35, 1), (52, 1), (53, 2), (54, 1)):
                cv.span(35 + d, x, x, HR, 'hair')
        shade_hair(cv)
        # 가르마와 머릿결 — 정수리에서 비스듬히, 좌우 다르게
        part = ((46, 5), (46, 6), (47, 7), (47, 8), (48, 9), (48, 10), (48, 11))
        for (x, y) in part:
            cv.s(x, y, HR_D, 'hair')
            cv.s(x + 1, y, HR_D, 'hair')
        for (x, y) in ((37, 15), (36, 16), (36, 17), (35, 18), (35, 19), (34, 20),
                       (41, 22), (40, 23), (40, 24), (39, 25),
                       (57, 14), (58, 15), (58, 16), (59, 17), (59, 18),
                       (54, 24), (55, 25), (55, 26), (56, 27)):
            cv.s(x, y, HR_D, 'hair')
        if sex == 'girl':
            cv.rect(43, 40, 52, 42, HR_D, 'hair')      # 뒤로 묶은 자리
            for (x, y) in ((37, 52), (36, 53), (36, 54), (35, 55), (35, 56),
                           (58, 50), (59, 51), (59, 52), (60, 53),
                           (44, 70), (44, 71), (45, 72), (45, 73),
                           (52, 74), (52, 75), (51, 76), (51, 77)):
                cv.s(x, y, HR_D, 'hair')
        return

    sh = 1 if kind == 'side' else 0
    for y, (x0, x1) in SKULL.items():
        cv.span(y, x0 + sh, x1 + sh, HR, 'hair')
    if sex == 'girl':
        for y, a, b in lock_spans(kind, sex):
            cv.span(y, a, b, HR, 'hair')

    bang = GBANG if sex == 'girl' else BANG_B
    face = {}
    for y, (x0, x1) in FACE.items():
        if kind == 'side':
            hx1 = SKULL.get(y, (0, 68))[1] + sh
            face[y] = (x0 + 4, min(x1 + 4, hx1))
        else:
            face[y] = (x0, x1)
    for y, (x0, x1) in sorted(face.items()):
        for x in range(x0, x1 + 1):
            if y > bang.get(x - (4 if kind == 'side' else 0), 0):
                cv.s(x, y, SK, 'skin')

    # 귀 — 얼굴에 딱 붙는다
    if kind == 'down':
        if sex == 'boy':
            cv.rect(27, 28, 29, 33, SK, 'skin')
            cv.rect(29, 29, 29, 32, SK_D, 'skin')
            cv.rect(66, 28, 68, 33, SK, 'skin')
            cv.rect(66, 29, 66, 32, SK_M, 'skin')
    else:
        cv.rect(67, 29, 69, 34, SK, 'skin')
        cv.rect(67, 30, 67, 33, SK_M, 'skin')

    # 뺨·턱 가장자리만 한 단 어둡게 (덩어리 그늘 금지)
    for y, (x0, x1) in sorted(face.items()):
        if y < 16:
            continue
        cv.s(x1, y, SK_D, 'skin')
        if kind == 'side' and y >= 22:
            cv.s(x1 - 1, y, SK_D, 'skin')
    d = 4 if kind == 'side' else 0
    cv.span(48, 43 + d, 52 + d, SK_D, 'skin')
    cv.span(49, 44 + d, 51 + d, SK_D, 'skin')

    shade_hair(cv)

    if kind == 'down':
        ea, ew, eb, ew2 = 34, 9, 53, 9
        ba, bb, bw2 = 35, 53, 8
        ncx, mcx = 47, 47
        bl, br = (31, 36), (59, 64)
    else:
        ea, ew, eb, ew2 = 40, 9, 57, 6
        ba, bb, bw2 = 41, 57, 7
        ncx, mcx = 53, 51
        bl, br = (36, 41), (61, 66)
    eye(cv, ea, 26, ew, True)
    eye(cv, eb, 26, ew2, False)
    brow(cv, ba, 22, 8, True)
    brow(cv, bb, 22, bw2, False)
    blush(cv, bl[0], bl[1], 34)
    blush(cv, br[0], br[1], 34)
    nose(cv, ncx, 34)
    mouth(cv, mcx, 40)


# ---------------------------------------------------------------- 몸
def shade_runs(cv, base, lit, shd, y0=0, y1=H, nl=2, ns=2):
    for y in range(y0, y1):
        xs = [x for x in range(W) if cv.p.get((x, y)) == base]
        if not xs:
            continue
        runs, s, pv = [], xs[0], xs[0]
        for x in xs[1:]:
            if x != pv + 1:
                runs.append((s, pv))
                s = x
            pv = x
        runs.append((s, pv))
        for a, b in runs:
            if b - a + 1 < nl + ns + 2:
                continue
            for x in range(a, a + nl):
                cv.p[(x, y)] = lit
            for x in range(b - ns + 1, b + 1):
                cv.p[(x, y)] = shd


def arm(cv, x0, x1, ytop, ys, yf, yh, far=False):
    """소매 -> 팔뚝 -> 손. 먼 쪽 팔은 한 단 어둡게 (뒤에 있다)."""
    sl, cf = (SH_D, SH_DD) if far else (SH, SH_D)
    sm, gr = (SK_D, SK_M) if far else (SK, SK_D)
    cv.rect(x0, ytop, x1, ys, sl, 'shirt')
    cv.rect(x0, ys - 1, x1, ys, cf, 'shirt')
    cv.rect(x0, ys + 1, x1, yf, sm, 'skin')
    cv.rect(x0 - 1, yf + 1, x1 + 1, yh, sm, 'skin')
    cv.rect(x0 - 1, yf + 3, x1 + 1, yf + 3, gr, 'skin')   # 손가락 골
    cv.rect(x0 - 1, yf + 5, x1 + 1, yf + 5, gr, 'skin')


def boot(cv, x0, x1, y0, y1, back=False, far=False):
    cv.rect(x0, y0, x1, y1, SO_D if far else SO, 'shoe')
    cv.rect(x0, y0, x1, y0 + 1, SO_DD if far else SO_D, 'shoe')
    cv.rect(x0, y1 - 1, x1, y1, SO_DD if far else SO_D, 'shoe')
    if back:
        cv.rect(x0 + 2, y1 - 5, x1 - 2, y1 - 3, SO_D, 'shoe')


def body(cv, sex, kind):
    sd = 1 if kind == 'side' else 0
    if kind == 'up':
        cv.rect(44, 45, 51, 49, SK_M, 'skin')
        cv.rect(44, 50, 51, 53, SK_D, 'skin')
    else:
        cv.rect(44 + sd, 50, 51 + sd, 51, SK_M, 'skin')
        cv.rect(44 + sd, 52, 51 + sd, 53, SK_D, 'skin')

    if kind == 'side':
        SHOU = [(54, 42, 56), (55, 39, 59), (56, 35, 61), (57, 32, 63)]
        AL, SL, TOR, SR, AR = (29, 34), 35, (36, 58), 59, (60, 64)
        cv.rect(29, 58, 64, 92, SH, 'shirt')
    else:
        SHOU = [(54, 40, 55), (55, 37, 58), (56, 34, 61), (57, 31, 64)]
        AL, SL, TOR, SR, AR = (30, 34), 35, (36, 59), 60, (61, 65)
        cv.rect(30, 58, 65, 92, SH, 'shirt')
    for y, a, b in SHOU:
        cv.span(y, a, b, SH, 'shirt')
    cv.rect(TOR[0], 54, TOR[1], 94, SH, 'shirt')

    if kind == 'side':
        arm(cv, AL[0], AL[1], 58, 81, 89, 97)
        arm(cv, AR[0], AR[1], 56, 78, 85, 92, far=True)
    else:
        arm(cv, AL[0], AL[1], 57, 80, 88, 96)
        arm(cv, AR[0], AR[1], 57, 80, 88, 96)
    cv.rect(SL, 58, SL, 80, SH_D, 'shirt')
    cv.rect(SR, 58, SR, 80, SH_D, 'shirt')

    if kind == 'up':
        cv.rect(38, 54, 57, 57, SH_D, 'shirt')
        cv.rect(46, 58, 49, 92, SH_D, 'shirt')
    else:
        cv.rect(40 + sd, 54, 55 + sd, 55, SH_L, 'shirt')
        cv.rect(43 + sd, 56, 52 + sd, 57, SH_D, 'shirt')
        cv.rect(47 + sd, 64, 48 + sd, 65, SH_LL, 'shirt')
        cv.rect(47 + sd, 75, 48 + sd, 76, SH_LL, 'shirt')

    cv.rect(TOR[0], 95, TOR[1], 99, PT_D, 'pants')
    if kind != 'up':
        cv.rect(45 + sd, 96, 50 + sd, 97, PT_L, 'pants')

    if sex == 'boy':
        if kind == 'side':
            cv.rect(37, 100, 58, 108, PT, 'pants')
            cv.rect(48, 109, 57, 128, PT_D, 'pants')
            cv.rect(38, 109, 47, 127, PT, 'pants')
            cv.rect(48, 109, 48, 128, PT_DD, 'pants')
            boot(cv, 48, 59, 129, 142, far=True)
            boot(cv, 36, 47, 128, 142)
            cv.rect(48, 129, 48, 142, SO_DD, 'shoe')   # 먼 신발 앞테
        else:
            cv.rect(37, 100, 58, 108, PT, 'pants')
            cv.rect(37, 109, 46, 127, PT, 'pants')
            cv.rect(49, 109, 58, 127, PT, 'pants')
            boot(cv, 35, 46, 128, 142, kind == 'up')
            boot(cv, 49, 60, 128, 142, kind == 'up')
    else:
        wide = 65 if kind != 'side' else 66
        rows = [(100, 36, 59), (103, 35, 60), (106, 34, 61), (109, 33, 62),
                (112, 32, 63), (114, 31, wide - 1), (116, 30, wide)]
        prev = None
        for y, a, b in rows:
            if prev:
                py, pa, pb = prev
                for yy in range(py, y):
                    t = (yy - py) / float(y - py)
                    cv.span(yy, int(round(pa + (a - pa) * t)),
                            int(round(pb + (b - pb) * t)), PT, 'pants')
            prev = (y, a, b)
        cv.span(116, 30, wide, PT, 'pants')
        cv.span(117, 31, wide - 1, PT_D, 'pants')
        for x, a, b in ((39, 105, 117), (47, 109, 117), (55, 102, 117), (61, 111, 117)):
            cv.rect(x, a, x, b, PT_D, 'pants')
        if kind == 'side':
            cv.rect(49, 118, 57, 130, SK_D, 'skin')
            cv.rect(40, 118, 48, 129, SK, 'skin')
            cv.rect(49, 118, 49, 130, SK_M, 'skin')
            boot(cv, 49, 59, 131, 142, far=True)
            boot(cv, 37, 48, 130, 142)
            cv.rect(49, 131, 49, 142, SO_DD, 'shoe')
        else:
            cv.rect(38, 118, 46, 129, SK, 'skin')
            cv.rect(49, 118, 57, 129, SK, 'skin')
            boot(cv, 36, 46, 130, 142, kind == 'up')
            boot(cv, 49, 59, 130, 142, kind == 'up')


def relock(cv, kind):
    for y, a, b in lock_spans(kind, 'girl'):
        if y >= 50:
            cv.span(y, a, b, HR, 'hair')


def build(sex, kind):
    cv = Cv()
    if kind == 'up':
        body(cv, sex, kind)
        head(cv, sex, kind)
    else:
        head(cv, sex, kind)
        body(cv, sex, kind)
        if sex == 'girl':
            relock(cv, kind)
            shade_hair(cv)
    shade_runs(cv, SH, SH_L, SH_D, 58, 95)
    shade_runs(cv, PT, PT_L, PT_D, 99, 134)
    shade_runs(cv, SK, SK_L, SK_D, 57, 143)
    shade_runs(cv, SO, SO, SO_D, 131, 143, nl=0, ns=2)
    outline(cv)
    despeckle(cv)
    return cv


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    for sex in ('boy', 'girl'):
        for kind in ('down', 'side', 'up'):
            save(build(sex, kind),
                 os.path.join(here, 'w96_r_%s_%s.png' % (sex, kind)))
    print('wrote 6')


if __name__ == '__main__':
    main()
