#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""g64 — f32x4 의 화풍을 그대로 두고 격자만 64 x 96 으로 올린 판 (정수 2배 → 128x192).

f32x4 가 좋다는 평을 받았지만 심사에서 「실효 해상도가 32x48 그대로라 4px 블록보다
작은 디테일이 하나도 없다」는 지적이 나왔다. 눈에 홍채를 넣을 칸도, 눈썹을 놓을
줄도, 무릎을 만들 여유도 없었기 때문이다. 그래서 **화풍과 비율은 그대로 두고
격자만 네 배로** 늘렸다 — 칸이 2x2 라 각진 맛은 남고, 정보량은 네 배다.

f32x4 에서 지적된 47가지를 여기서 잡는다. 굵직한 것만:
  · 실루엣은 전부 「줄마다 반폭(정수)」으로 적고 **이웃 줄과 1칸 넘게 차이 나지
    못하게** 강제한다 → 계단·직각 어깨가 구조적으로 안 생긴다
  · 눈을 6x7 로 키워 속눈썹·홍채·동공·반사점을 나눈다. 반사점은 **양쪽 눈 모두
    왼쪽 위** (전에는 좌우 대칭이라 사시로 보였다)
  · 눈썹을 넣는다 (전 판에는 눈썹색 픽셀이 0개였다)
  · 이마를 세 줄 확보하고 앞머리 밑선을 칸마다 다르게 끊는다
  · 볼을 눈에서 두 줄 떼어 다크서클로 안 보이게 한다
  · 맨 아랫줄을 윤곽으로 메우지 않는다 → 두 발이 검정 받침대로 붙지 않는다
  · 무릎·발목·손가락·옷주름을 넣는다
  · 머리 밝은면과 바지 밝은면이 거의 같은 색이던 것을 단을 갈라 띄운다
"""

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GW, GH = 64, 96
S = 2
OW, OH = 128, 192
YSHIFT = -1              # 소스 95줄이 dest 189~190 → 발바닥 190
CX = 32                  # 반폭 hw 일 때 x = CX-hw .. CX-1+hw

# ---------------------------------------------------------------- 팔레트
# game_data.gd APPEAR_* 0번 줄 그대로. 표에 없는 건 윤곽·눈·눈썹·흰자뿐이다.
SK, SK_L, SK_D = (243, 159, 138), (250, 192, 170), (213, 116, 98)
SK_CH, SK_M, SK_DD, SK_LL = (235, 128, 114), (170, 84, 66), (184, 99, 83), (252, 217, 204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118, 72, 40), (152, 100, 56), (86, 52, 30), (58, 35, 20), (195, 165, 140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58, 88, 168), (38, 58, 120), (94, 126, 200), (27, 41, 84), (166, 184, 225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134, 88, 46), (98, 62, 32), (158, 108, 58), (69, 43, 22), (202, 174, 147)
SO, SO_D, SO_DD = (82, 53, 33), (56, 37, 25), (39, 26, 18)
OL, EYE, BROW, WHT = (26, 20, 28), (66, 32, 30), (136, 70, 42), (246, 242, 234)

CH = {
    '#': OL,
    'h': HR, 'H': HR_L, 'd': HR_D, 'D': HR_DD, 'G': HR_LL,
    's': SK, 'l': SK_L, 'S': SK_D, 'c': SK_CH, 'm': SK_M, 'k': SK_DD, 'w': SK_LL,
    'e': EYE, 'W': WHT, 'i': BROW,
    't': SH, 'T': SH_L, 'y': SH_D, 'Y': SH_DD, 'U': SH_LL,
    'p': PT, 'P': PT_L, 'q': PT_D, 'Q': PT_DD, 'u': PT_LL,
    'o': SO, 'O': SO_D, 'x': SO_DD,
}
HAIRCH = set('hHdDG')
SKINCH = set('slScmkw')


# ---------------------------------------------------------------- 격자 도구
def blank():
    return [['.'] * GW for _ in range(GH)]


def row(g, y, x0, x1, ch):
    if 0 <= y < GH:
        for x in range(max(0, x0), min(GW - 1, x1) + 1):
            g[y][x] = ch


def put(g, x, y, ch):
    if 0 <= x < GW and 0 <= y < GH:
        g[y][x] = ch


def art(g, x0, y0, rows, key=None):
    """글자 격자를 그대로 찍는다 — 눈·눈썹·입처럼 칸마다 뜻이 있는 것."""
    for dy, r in enumerate(rows):
        for dx, c in enumerate(r):
            if c != '.':
                put(g, x0 + dx, y0 + dy, (key or {}).get(c, c))


def ramp(anchors):
    """[(y, 반폭)] 를 줄마다 채운다. **이웃 줄과 1칸 넘게 벌어지지 못하게** 한다.

    계단과 직각 어깨는 전부 「한 줄에 폭이 두 칸 이상 변해서」 생긴다. 여기서
    막아 두면 실루엣에 그 종류의 사고가 아예 안 난다."""
    out = {}
    for i in range(len(anchors) - 1):
        (y0, w0), (y1, w1) = anchors[i], anchors[i + 1]
        for y in range(y0, y1 + 1):
            t = (y - y0) / float(y1 - y0) if y1 > y0 else 0.0
            out[y] = w0 + (w1 - w0) * t
    ys = sorted(out)
    res, prev = {}, None
    for y in ys:
        v = int(round(out[y]))
        if prev is not None:
            v = max(prev - 1, min(prev + 1, v))
        res[y] = v
        prev = v
    return res


def fill_ramp(g, rm, ch, only_empty=False):
    for y, hw in rm.items():
        if hw <= 0:
            continue
        for x in range(CX - hw, CX + hw):
            if only_empty and g[y][x] != '.':
                continue
            put(g, x, y, ch)


# ---------------------------------------------------------------- 얼굴 부속
# 눈 6 x 7. 칸이 네 배가 되어 드디어 속눈썹·홍채·동공·반사점을 나눌 수 있다.
# 반사점(W)은 **양쪽 눈 모두 왼쪽 위**다 — 좌우 대칭으로 놓으면 사시로 보인다.
EYE_M = [
    '..eeeee..',
    '.eeeeeee.',
    'eWWiiiiie',
    'eiiieeiie',
    'eiiieeiie',
    'eiiiiiiie',
    '..eeeee..',
]
EYE_F = [                       # 여자 — 위 속눈썹이 한 줄 두껍다
    '.eeeeeee.',
    'eeeeeeeee',
    'eWWiiiiie',
    'eiiieeiie',
    'eiiieeiie',
    'eiiiiiiie',
    '.eeeee...',
]
BROW_M = ['..DDDDD..', 'DD.......']   # 굵고 낮다
BROW_F = ['...DDDD..', '.DD......']   # 가늘고 높다
LID_M = ['..eeeee..', '.eeeeeee.', '..eee....']
LID_F = ['.eeeeeee.', 'eeeeeeeee', '..eeeee..']
MOUTH_M = ['m....m', '.mmmm.', '..ww..']
MOUTH_F = ['m....m', '.mmmm.', '..ww..']


def flipart(a):
    return [r[::-1] for r in a]


# ---------------------------------------------------------------- 머리 모양
# 앞머리 밑선 — 칸마다 몇 줄 더 내릴지. 일자로 자르면 바가지가 된다
# 앞머리 밑선 — **두 칸 짝**으로 몇 줄 더 내릴지. 한 칸씩 적으면 잡티가 된다
BANG_M = [1, 3, 0, 2, 1, 3, 0, 2, 3, 1, 2, 0, 3, 1, 2]
BANG_F = [2, 4, 1, 3, 2, 4, 1, 3, 4, 2, 3, 1, 4, 2, 3]

FACE = ramp([(20, 8), (23, 12), (26, 15), (36, 15), (39, 14), (41, 12),
             (43, 9), (44, 6)])
CAP_M = ramp([(5, 6), (8, 12), (11, 16), (14, 19), (17, 21), (20, 22),
              (26, 22), (30, 21), (34, 19), (38, 16), (41, 13), (43, 10)])
CAP_F = ramp([(5, 6), (8, 12), (11, 16), (14, 19), (17, 21), (20, 22),
              (30, 22), (38, 21), (44, 22)])
HANG_F = ramp([(45, 22), (52, 21), (58, 19), (63, 16), (67, 12), (70, 9)])


# 머리 바깥선을 줄마다 몇 칸 더 내밀지 — 손으로 적는다. 좌우를 다르게 적어야
# 「자로 그은 사선」이 아니라 머리카락 뭉치로 읽힌다.
# 머리 뭉치 — (시작줄, 줄수, 왼쪽 내밀기, 오른쪽 내밀기). 두세 줄짜리 덩어리로
# 적어야 머리카락으로 읽힌다 (한 줄짜리 돌기를 줄마다 찍으면 보풀이 된다).
TUFT_M = [(7, 3, 2, 0), (10, 3, 0, 2), (14, 3, 2, 1), (18, 4, 0, 2),
          (23, 3, 2, 0), (27, 4, 1, 2), (32, 3, 2, 0), (36, 3, 0, 1)]
TUFT_F = [(7, 3, 2, 0), (11, 4, 0, 2), (16, 4, 2, 1), (22, 5, 0, 2),
          (29, 5, 2, 0), (36, 5, 0, 2), (44, 5, 2, 0), (52, 5, 0, 2),
          (60, 4, 1, 0)]


def head(g, girl):
    cap = CAP_F if girl else CAP_M
    fill_ramp(g, cap, 'h')
    edge = dict(cap)
    if girl:
        edge.update(HANG_F)
    for y0, n, dl, dr in (TUFT_F if girl else TUFT_M):
        for y in range(y0, y0 + n):
            if y not in edge:
                continue
            hw = edge[y]
            for k in range(dl):
                put(g, CX - hw - 1 - k, y, 'h')
            for k in range(dr):
                put(g, CX + hw + k, y, 'h')
    fill_ramp(g, FACE, 's')
    if girl:
        fill_ramp(g, HANG_F, 'h', only_empty=True)
    # 앞머리 — 통으로 덮고 아래 끝만 칸마다 다르게 끊는다. 일자로 자르면 바가지다
    bang = BANG_F if girl else BANG_M
    base = 25 if girl else 24
    for i, n in enumerate(bang):
        for x in (CX - 15 + i * 2, CX - 14 + i * 2):
            for y in range(19, base + n + 1):     # 얼굴 첫 줄부터 덮어야
                if g[y][x] in SKINCH:             # 이마에 흰 띠가 안 생긴다
                    g[y][x] = 'h'
    # 머리 명암 — 왼쪽 위가 밝고 오른쪽·아래가 어둡다. 면으로 나눈다(그라데이션 X)
    for y in range(GH):
        for x in range(GW):
            if g[y][x] != 'h':
                continue
            u, v = (x - 24) / 22.0, (y - 17) / 24.0
            d = (u * u + v * v) ** 0.5
            g[y][x] = ('H' if d < 0.46 else 'h' if d < 0.94
                       else 'd' if d < 1.22 else 'D')
    # 정수리 윤기 — 끊어서 얹는다 (이어 놓으면 띠, 네모로 칠하면 딱지가 된다)
    for x0, x1, dep in ((13, 20, 6), (23, 31, 5), (35, 42, 6)):
        for x in range(x0, x1 + 1):
            col = [y for y in range(GH) if g[y][x] in HAIRCH]
            if not col:
                continue
            for y in (col[0] + dep, col[0] + dep + 1):
                if g[y][x] in ('h', 'H', 'd'):
                    g[y][x] = 'H'
            if x == x0 + 1:
                put(g, x, col[0] + dep, 'G')
    for x, y0, y1 in ((CX - 17, 20, 26), (CX - 8, 10, 15), (CX + 6, 12, 17),
                      (CX + 16, 21, 27), (CX - 13, 30, 36), (CX + 13, 31, 38)):
        for y in range(y0, y1 + 1):
            if g[y][x] in ('h', 'H'):
                g[y][x] = 'd'
    # 앞머리가 이마에 지우는 그늘 한 줄 + 가닥 끝은 짙게
    for i, n in enumerate(bang):
        b = base + n
        for x in (CX - 15 + i * 2, CX - 14 + i * 2):
            if g[b][x] in HAIRCH:
                g[b][x] = 'D'
            if g[b + 1][x] in SKINCH:
                g[b + 1][x] = 'S'


def face(g, girl, blink=False):
    ey, lx, rx = 29, CX - 12, CX + 3
    eye = EYE_F if girl else EYE_M
    lid = LID_F if girl else LID_M
    brow = BROW_F if girl else BROW_M
    if blink:
        art(g, lx, ey + 2, lid)
        art(g, rx, ey + 2, lid)
    else:
        # 좌우를 뒤집지 않는다 — 뒤집으면 흰자와 반사점이 서로 바깥을 봐
        # 사시로 보인다. 빛은 하나뿐이므로 두 눈이 같은 방향이어야 맞다
        art(g, lx, ey, eye)
        art(g, rx, ey, eye)
    art(g, lx, ey - 3, brow)
    art(g, rx, ey - 3, flipart(brow))
    # 볼 — 눈에서 **두 줄 떼어** 놓는다. 붙이면 다크서클로 보인다
    for x0 in (CX - 13, CX + 8):
        for y in (ey + 8, ey + 9):
            for x in range(x0, x0 + 5):
                if g[y][x] in SKINCH:
                    g[y][x] = 'c'
    # 코 — 그늘 두 칸에 빛 한 칸
    put(g, CX - 1, ey + 9, 'S')                            # 코 — 두 칸이면 족하다
    put(g, CX - 1, ey + 10, 'S')
    put(g, CX - 3, ey + 9, 'l')
    art(g, CX - 3, ey + 12, MOUTH_F if girl else MOUTH_M)
    row(g, 43, CX - 3, CX + 2, 'S')                        # 턱 밑 그늘은 좁게


# ---------------------------------------------------------------- 몸
NECK = ramp([(45, 6), (47, 6)])
# 어깨는 다섯 줄에 걸쳐 벌린다. 한 줄에 폭이 두 칸 넘게 변하면 직각 상자가 된다
TORSO_M = ramp([(48, 7), (49, 10), (50, 13), (51, 15), (52, 16), (65, 16),
                (67, 15), (68, 14)])
TORSO_F = ramp([(48, 7), (49, 10), (50, 12), (51, 14), (52, 15), (63, 15),
                (66, 13), (68, 13)])
HIP = ramp([(69, 14), (71, 14), (74, 13), (75, 13)])
SKIRT = ramp([(69, 13), (72, 16), (76, 19), (79, 20)])
TW = 9                    # 몸통 반폭 — 팔은 이 바깥에 붙는다


def body(g, girl):
    fill_ramp(g, NECK, 's')
    row(g, 45, CX - 6, CX + 5, 'S')                        # 목 그늘
    tor = TORSO_F if girl else TORSO_M
    fill_ramp(g, tor, 't')
    # 팔과 몸통을 가르는 검정 줄 — **어깨 맨 윗줄부터** 넣어야 위가 안 뚫린다
    for y, hw in sorted(tor.items()):
        if hw > TW + 1:
            put(g, CX - TW - 1, y, '#')
            put(g, CX + TW, y, '#')
    arm_x = lambda: (range(CX - 16, CX - TW - 1), range(CX + TW + 1, CX + 16))
    # 소매 끝 두 줄만 밝게 (팔 x 범위 안에서만 — 몸통까지 칠하면 가로 띠가 된다)
    cuff = 61 if girl else 63
    for y in (cuff, cuff + 1):
        for rng in arm_x():
            for x in rng:
                if g[y][x] == 't':
                    g[y][x] = 'T'
    # 팔뚝 → 손. 세 단에 걸쳐 오므린다 (한 번에 줄이면 밑에 검정 쐐기가 생긴다)
    for i, hw in enumerate((6, 6, 6, 5, 5, 4)):
        y = cuff + 2 + i
        for x in range(CX - TW - 1 - hw, CX - TW - 1):
            put(g, x, y, 's')
        for x in range(CX + TW + 1, CX + TW + 1 + hw):
            put(g, x, y, 's')
    # 팔 안쪽 그늘 한 줄 — 팔이 몸통에 녹아붙지 않게
    for y in range(52, cuff + 8):
        if g[y][CX - TW - 2] in ('t', 'T'):
            g[y][CX - TW - 2] = 'y'
        if g[y][CX + TW + 1] in ('t', 'T'):
            g[y][CX + TW + 1] = 'y'
        if g[y][CX - TW - 2] == 's':
            g[y][CX - TW - 2] = 'S'
        if g[y][CX + TW + 1] == 's':
            g[y][CX + TW + 1] = 'S'
    # 깃 — V 자
    row(g, 48, CX - 3, CX + 2, 'T')
    row(g, 49, CX - 2, CX + 1, 'T')
    row(g, 50, CX - 1, CX, 'T')
    # 옷주름 — 짧게 끊어 놓는다. 길게 그으면 자로 그은 티가 난다
    for x, y0, y1 in ((CX - 6, 56, 61), (CX + 5, 57, 63), (CX - 1, 62, 66)):
        for y in range(y0, y1 + 1):
            if g[y][x] == 't':
                g[y][x] = 'y'
    for x in range(CX - TW, CX + TW):                      # 옷단 그늘
        if g[68][x] == 't':
            g[68][x] = 'y'
    for y in (54, 58, 62):                                 # 단추 — 두 칸이라 대칭
        put(g, CX - 1, y, 'U')
        put(g, CX, y, 'U')
    for y in range(54, 67):                                # 앞섶 선
        if g[y][CX - 2] == 't':
            g[y][CX - 2] = 'y'
    for rng in arm_x():                                    # 어깨 이음선
        for x in rng:
            if g[53][x] == 't':
                g[53][x] = 'y'
    if girl:
        fill_ramp(g, SKIRT, 'p')
        for x in (CX - 12, CX - 6, CX - 1, CX + 5, CX + 10):
            for y in range(71, 80):
                if g[y][x] == 'p':
                    g[y][x] = 'q'
        row(g, 80, CX - 20, CX + 19, 'q')                  # 치마 밑단
        legs(g, 80, 87, 'sS')
        boots(g, 88)
    else:
        fill_ramp(g, HIP, 'p')
        row(g, 69, CX - 14, CX + 13, 'O')                  # 허리띠
        row(g, 70, CX - 14, CX + 13, 'O')
        for y in (69, 70):                                 # 버클 — 두 칸이라 대칭
            put(g, CX - 1, y, 'u')
            put(g, CX, y, 'u')
        for y in range(72, 76):                            # 주머니 두 개
            put(g, CX - 11, y, 'q')
            put(g, CX + 10, y, 'q')
        row(g, 72, CX - 11, CX - 8, 'q')
        row(g, 72, CX + 7, CX + 10, 'q')
        legs(g, 76, 85, 'pq')
        boots(g, 86)


def legs(g, y0, y1, chs):
    """두 다리 — 무릎에서 한 칸 좁아진다. 사이 틈은 끝까지 살려 둔다."""
    base, dark = chs[0], chs[1]
    mid = (y0 + y1) // 2
    prof = ramp([(y0, 7), (y0 + 2, 7), (mid, 6), (y1, 6)])
    for y in range(y0, y1 + 1):
        hw = prof[y]
        row(g, y, CX - 2 - hw, CX - 3, base)
        row(g, y, CX + 2, CX + 1 + hw, base)
        put(g, CX - 3, y, dark)                            # 안쪽 그늘
        put(g, CX + 1 + hw, y, dark)                       # 바깥 그늘
    for y in (mid, mid + 1):                               # 무릎 결
        put(g, CX - 2 - prof[y] + 1, y, dark)
        put(g, CX + 2, y, dark)


def boots(g, y0):
    """장화 — 발목에서 한 칸 넓어지고 밑창이 있다.
    **맨 아랫줄을 가로로 메우지 않는다** — 메우면 두 발이 검정 받침대로 붙는다."""
    prof = ramp([(y0, 6), (y0 + 1, 8), (93, 8), (95, 9)])
    for y in range(y0, 96):
        hw = prof[y]
        ch = 'x' if y >= 94 else ('O' if y >= 92 else 'o')
        row(g, y, CX - 2 - hw, CX - 3, ch)
        row(g, y, CX + 2, CX + 1 + hw, ch)
        if y == y0 + 1:                                    # 장화 목 접힘
            row(g, y, CX - 2 - hw, CX - 3, 'O')
            row(g, y, CX + 2, CX + 1 + hw, 'O')
        if ch == 'o':
            put(g, CX - 2 - hw, y, 'O')
            put(g, CX + 1 + hw, y, 'O')
        else:
            put(g, CX - 2 - hw, y, 'x')
            put(g, CX + 1 + hw, y, 'x')


# ---------------------------------------------------------------- 마무리
def outline(g):
    add = []
    for y in range(GH):
        for x in range(GW):
            if g[y][x] != '.':
                continue
            if any(0 <= x + dx < GW and 0 <= y + dy < GH and
                   g[y + dy][x + dx] not in ('.', '#')
                   for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                add.append((x, y))
    for x, y in add:
        g[y][x] = '#'


def save(g, path):
    im = Image.new('RGBA', (OW, OH), (0, 0, 0, 0))
    o = im.load()
    for y in range(GH):
        for x in range(GW):
            c = g[y][x]
            if c == '.':
                continue
            col = CH[c] + (255,)
            for dy in range(S):
                for dx in range(S):
                    py = y * S + dy + YSHIFT
                    if 0 <= py < OH:
                        o[x * S + dx, py] = col
    im.save(path)
    return im


def build(girl, blink=False):
    g = blank()
    head(g, girl)
    face(g, girl, blink)
    body(g, girl)
    outline(g)
    return g


def check(path):
    im = Image.open(path).convert('RGBA')
    px = im.load()
    ok = [im.size == (OW, OH)]
    bot = max(y for y in range(OH) for x in range(OW) if px[x, y][3])
    alphas = {px[x, y][3] for y in range(OH) for x in range(OW)}
    bad = {px[x, y][:3] for y in range(OH) for x in range(OW)
           if px[x, y][3] and px[x, y][:3] not in set(CH.values())}
    # 연결 요소
    seen, comps = set(), 0
    for sy in range(OH):
        for sx in range(OW):
            if px[sx, sy][3] and (sx, sy) not in seen:
                comps += 1
                st = [(sx, sy)]; seen.add((sx, sy))
                while st:
                    x, y = st.pop()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        n = (x + dx, y + dy)
                        if 0 <= n[0] < OW and 0 <= n[1] < OH and n not in seen \
                                and px[n[0], n[1]][3]:
                            seen.add(n); st.append(n)
    print('%-22s 크기%s 발바닥y=%d 알파%s 팔레트밖=%d 덩어리=%d'
          % (os.path.basename(path), im.size, bot, sorted(alphas), len(bad), comps))
    return ok and bot == 190 and alphas <= {0, 255} and not bad and comps == 1


if __name__ == '__main__':
    for girl, nm in ((False, 'boy'), (True, 'girl')):
        save(build(girl), os.path.join(HERE, 'g64_%s.png' % nm))
        save(build(girl, True), os.path.join(HERE, 'g64_%s_blink.png' % nm))
    for nm in ('boy', 'girl'):
        check(os.path.join(HERE, 'g64_%s.png' % nm))
