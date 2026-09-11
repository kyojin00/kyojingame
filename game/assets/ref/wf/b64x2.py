#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""b64x2 — 64x96 격자에 찍고 정수 2배로 키워 128x192 를 만드는 주인공 도트 생성기.

화풍: 플랫 컬러 + 굵은 검정 윤곽 + 치비 비율 (SPEC.md 3장).
팔과 몸통 사이, 두 다리 사이에 검정 줄을 넣는다.
Pillow 만 쓴다 (numpy 없음).
"""

import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GW, GH = 64, 96          # 격자
OW, OH = 128, 192        # 최종 크기 (격자 x2, y 로 1 올려 발바닥이 190 에 오게 함)

# ---------------------------------------------------------------- 팔레트
# 살결 7단 [기본, 밝은면, 그늘, 볼, 입, 깊은그늘, 아주밝은면]
SK    = (243, 159, 138)
SK_L  = (250, 192, 170)
SK_D  = (213, 116, 98)
SK_CH = (235, 128, 114)
SK_M  = (170, 84, 66)
SK_DD = (184, 99, 83)
SK_LL = (252, 217, 204)
# 머리 5단 [기본, 밝은면, 그늘, 깊은그늘, 아주밝은면]
HR    = (118, 72, 40)
HR_L  = (152, 100, 56)
HR_D  = (86, 52, 30)
HR_DD = (58, 35, 20)
HR_LL = (195, 165, 140)
# 윗도리 5단 [기본, 그늘, 밝은면, 깊은그늘, 아주밝은면]
SH    = (58, 88, 168)
SH_D  = (38, 58, 120)
SH_L  = (94, 126, 200)
SH_DD = (27, 41, 84)
SH_LL = (166, 184, 225)
# 아랫도리 5단
PT    = (134, 88, 46)
PT_D  = (98, 62, 32)
PT_L  = (158, 108, 58)
PT_DD = (69, 43, 22)
PT_LL = (202, 174, 147)
# 신발 3단
SO    = (82, 53, 33)
SO_D  = (56, 37, 25)
SO_DD = (39, 26, 18)
# 갈아입히지 않는 색
OL    = (26, 20, 28)
EYE   = (66, 32, 30)
BROW  = (136, 70, 42)
WHT   = (246, 242, 234)

PALETTE = [SK, SK_L, SK_D, SK_CH, SK_M, SK_DD, SK_LL,
           HR, HR_L, HR_D, HR_DD, HR_LL,
           SH, SH_D, SH_L, SH_DD, SH_LL,
           PT, PT_D, PT_L, PT_DD, PT_LL,
           SO, SO_D, SO_DD,
           OL, EYE, BROW, WHT]

SKINS = (SK, SK_L, SK_D, SK_CH, SK_M, SK_DD, SK_LL)
HAIRS = (HR, HR_L, HR_D, HR_DD, HR_LL)
SHIRTS = (SH, SH_D, SH_L, SH_DD, SH_LL)
PANTS = (PT, PT_D, PT_L, PT_DD, PT_LL)


# ---------------------------------------------------------------- 격자 도구
def span(hw):
    """중심 31.5 에서 반폭 hw 인 좌우 끝 열."""
    l = int(math.floor(32.0 - hw + 0.5))
    l = max(0, min(31, l))
    return l, 63 - l


def curve(pts):
    """[(y, 반폭), ...] 를 행마다 선형보간한 dict."""
    d = {}
    for i in range(len(pts) - 1):
        y0, h0 = pts[i]
        y1, h1 = pts[i + 1]
        for y in range(y0, y1 + 1):
            t = 0.0 if y1 == y0 else (y - y0) / float(y1 - y0)
            d[y] = h0 + (h1 - h0) * t
    return d


class G(object):
    def __init__(self):
        self.g = [[None] * GW for _ in range(GH)]

    def put(self, x, y, c):
        if 0 <= x < GW and 0 <= y < GH:
            self.g[y][x] = c

    def get(self, x, y):
        if 0 <= x < GW and 0 <= y < GH:
            return self.g[y][x]
        return None

    def hline(self, y, x0, x1, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.hline(y, x0, x1, c)

    def over(self, x, y, c, only):
        """only 안의 색일 때만 덮어쓴다."""
        if self.get(x, y) in only:
            self.put(x, y, c)

    def hover(self, y, x0, x1, c, only):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.over(x, y, c, only)

    def fill_curve(self, cv, c, y0=None, y1=None):
        for y in sorted(cv):
            if y0 is not None and y < y0:
                continue
            if y1 is not None and y > y1:
                continue
            l, r = span(cv[y])
            self.hline(y, l, r, c)

    def leftmost(self, y):
        for x in range(GW):
            if self.g[y][x] is not None:
                return x
        return None

    def rightmost(self, y):
        for x in range(GW - 1, -1, -1):
            if self.g[y][x] is not None:
                return x
        return None

    def topmost(self, x):
        for y in range(GH):
            if self.g[y][x] is not None:
                return y
        return None


def wedge(g, ax, ay, bl, br, by, c, ease=1.7):
    """(ax, ay) 꼭지에서 by 행의 bl..br 로 퍼지는 가닥.
    ease>1 이면 꼭지 쪽이 오래 가늘어 삼각형(왕관)이 아니라 불꽃처럼 보인다."""
    for y in range(ay, by + 1):
        t = (y - ay) / float(by - ay) if by > ay else 1.0
        t = t ** ease
        l = int(round(ax + (bl - ax) * t))
        r = int(round(ax + (br - ax) * t))
        g.hline(y, l, r, c)


def dome_top_by_col(cv):
    """머리통 곡선에서 열마다 가장 위 행 — 하이라이트 띠를 두개골 곡선에 맞춘다."""
    top = {}
    for y in sorted(cv):
        l, r = span(cv[y])
        for x in range(l, r + 1):
            if x not in top:
                top[x] = y
    return top


def outline_pass(g, col=OL):
    """실루엣 바깥 둘레 한 칸을 윤곽색으로 (안쪽으로 그린다)."""
    src = [row[:] for row in g.g]
    for y in range(GH):
        for x in range(GW):
            if src[y][x] is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or nx >= GW or ny < 0 or ny >= GH or src[ny][nx] is None:
                    g.g[y][x] = col
                    break


# ---------------------------------------------------------------- 형태 표
# 얼굴(살결) 윤곽 — 위는 넓고 턱은 둥글게
FACE = curve([(19, 8.0), (20, 9.6), (21, 10.7), (22, 11.4), (23, 11.9),
              (24, 12.2), (26, 12.5), (34, 12.6), (36, 12.4), (38, 12.0),
              (40, 11.3), (41, 10.4), (42, 9.2), (43, 7.6), (44, 5.4)])

# 머리통 (머리카락 바깥) — 남자
HAIR_B = curve([(8, 3.0), (9, 5.2), (10, 6.6), (11, 7.4), (12, 10.0), (13, 11.8), (14, 13.0), (15, 13.9),
                (16, 14.6), (17, 15.1), (18, 15.5), (19, 15.8), (20, 16.0),
                (30, 16.0), (34, 15.7), (37, 15.0), (39, 14.0), (41, 12.2),
                (42, 10.0)])
# 여자 — 조금 더 둥글다
HAIR_G = curve([(7, 3.0), (8, 5.0), (9, 6.4), (10, 7.2), (11, 9.8), (12, 11.6), (13, 12.8), (14, 13.7),
                (15, 14.3), (16, 14.8), (17, 15.1), (18, 15.3), (19, 15.4),
                (32, 15.4), (36, 15.2), (40, 14.8), (42, 14.2), (44, 12.8),
                (45, 11.2), (46, 9.2), (47, 7.0)])

# 앞머리 가닥: (첫열, 끝열, 첫열 아랫끝, 끝열 아랫끝)
BANG_B = [(19, 20, 31, 30), (21, 26, 29, 26), (27, 32, 28, 24),
          (33, 38, 27, 25), (39, 42, 28, 26), (43, 44, 29, 31)]
BANG_G = [(19, 20, 31, 29), (21, 26, 27, 25), (27, 30, 27, 24),
          (31, 32, 23, 23), (33, 36, 24, 26), (37, 42, 26, 27),
          (43, 44, 29, 31)]

# 머리 윗선 — 열마다 머리카락 첫 행. 뿔을 따로 얹지 않고 윗선 자체를
# 들쭉날쭉하게 만든다 (따로 얹으면 몸과 떨어진 조각이 생긴다).
TOP_B = [(16, 21), (17, 19), (18, 17), (19, 15), (20, 13),
         (21, 12), (22, 11), (23, 12), (24, 12), (25, 12), (26, 13),
         (27, 11), (28, 8), (29, 6), (30, 6), (31, 6), (32, 7), (33, 9),
         (34, 11), (35, 12),
         (36, 11), (37, 9), (38, 8), (39, 8), (40, 10), (41, 12),
         (42, 14), (43, 16), (44, 17), (45, 19), (46, 20), (47, 22)]
TOP_G = [(16, 21), (17, 19), (18, 17), (19, 16), (20, 14), (21, 12),
         (22, 10), (23, 9), (24, 9), (25, 8), (26, 8), (27, 8),
         (28, 7), (29, 6), (30, 6), (31, 7), (32, 7), (33, 8), (34, 8),
         (35, 8), (36, 9), (37, 9), (38, 10), (39, 10), (40, 11), (41, 12),
         (42, 14), (43, 16), (44, 18), (45, 20), (46, 21), (47, 22)]

# 몸통(옷) 윤곽
BODY = curve([(47, 6.0), (48, 8.8), (49, 9.8), (50, 10.2), (51, 10.4),
              (60, 10.4), (64, 10.0), (66, 10.2), (68, 10.8), (70, 11.0),
              (73, 11.0)])
BODY_G = curve([(47, 6.0), (48, 8.6), (49, 9.4), (50, 9.8), (51, 10.0),
                (60, 9.6), (64, 9.2), (66, 9.8), (67, 10.4)])

# 치마 (여자)
SKIRT = curve([(66, 10.2), (68, 11.2), (70, 12.2), (72, 13.2), (74, 14.0),
               (76, 14.6), (78, 15.0), (79, 15.0)])


BANG_TIP_B = {22: 1, 23: 1, 29: 1, 30: 1, 36: 1, 37: 1}
BANG_TIP_G = {23: 1, 24: 1, 29: 1, 30: 1, 35: 1, 36: 1, 40: 1}


def bang_bottom(strands, tips=None):
    """가닥 표 -> {열: 마지막 머리 행}. tips 는 가닥 끝을 두 칸씩 더 내린다."""
    d = {}
    for (x0, x1, y0, y1) in strands:
        for x in range(x0, x1 + 1):
            t = (x - x0) / float(x1 - x0) if x1 > x0 else 0.0
            d[x] = int(round(y0 + (y1 - y0) * t))
    for x, dy in (tips or {}).items():
        if x in d:
            d[x] += dy
    return d


def profile(pts):
    """[(열, 행), ...] 를 열마다 선형보간 — 머리 윗선."""
    d = {}
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        for x in range(x0, x1 + 1):
            t = 0.0 if x1 == x0 else (x - x0) / float(x1 - x0)
            d[x] = int(round(y0 + (y1 - y0) * t))
    return d


def draw_head(g, sex):
    hair_cv = HAIR_B if sex == "boy" else HAIR_G
    bang = (bang_bottom(BANG_B, BANG_TIP_B) if sex == "boy"
            else bang_bottom(BANG_G, BANG_TIP_G))
    top = profile(TOP_B if sex == "boy" else TOP_G)
    dtop = dome_top_by_col(hair_cv)

    # 1) 머리통
    g.fill_curve(hair_cv, HR)
    # 2) 머리 윗선 — 두개골 위로 가닥을 세운다 (열마다 이어져 있어 조각이 안 뜬다)
    for x, yt in top.items():
        if x not in dtop:
            continue
        for y in range(min(yt, dtop[x]), dtop[x]):
            g.put(x, y, HR)

    # 3) 얼굴
    g.fill_curve(FACE, SK, y0=19)

    # 4) 앞머리 — 열마다 아랫끝이 다르다 (가닥)
    for x, ybot in bang.items():
        ytop = g.topmost(x)
        if ytop is None:
            continue
        for y in range(ytop, ybot + 1):
            if g.get(x, y) is not None:
                g.put(x, y, HR)

    # 5) 옆머리 — 얼굴 바깥쪽은 전부 머리
    for y in sorted(hair_cv):
        hl, hr = span(hair_cv[y])
        if y in FACE:
            fl, fr = span(FACE[y])
            g.hline(y, hl, fl - 1, HR)
            g.hline(y, fr + 1, hr, HR)

    # 6) 앞머리 밑 그늘선 + 이마 그늘
    for x, ybot in bang.items():
        g.over(x, ybot + 1, SK_D, (SK,))

    # 7) 머리 하이라이트 — 실제 윗선을 따라 두 칸 아래로 흐르는 띠
    for x in sorted(top):
        yt = g.topmost(x)
        if yt is None:
            continue
        for y in range(yt + 2, yt + 5):
            g.over(x, y, HR_L, (HR,))
    for y in range(16, 32):                      # 왼쪽 옆머리로 이어지는 띠
        if y not in hair_cv:
            continue
        l, _ = span(hair_cv[y])
        for x in range(l + 2, l + 4):
            g.over(x, y, HR_L, (HR,))

    # 8) 오른쪽 머리 그늘
    for y in sorted(hair_cv):
        _, r = span(hair_cv[y])
        for x in range(r - 2, r + 1):
            g.over(x, y, HR_D, (HR,))
    # 9) 옆머리 가닥선 — 실루엣을 따라 흐르는 한 줄
    for y in sorted(hair_cv):
        if y < 16:
            continue
        l, r = span(hair_cv[y])
        g.over(l + 4, y, HR_D, (HR, HR_L))
        g.over(r - 4, y, HR_L, (HR, HR_D))


def draw_face_parts(g, sex):
    # 얼굴 음영 — 왼쪽 밝은면, 오른쪽 그늘, 턱 밑 그늘
    for y in range(24, 46):
        if y not in FACE:
            continue
        l, r = span(FACE[y])
        for x in range(l, l + 2):
            g.over(x, y, SK_L, (SK,))
        for x in range(r - 1, r + 1):
            g.over(x, y, SK_D, (SK,))
    l, r = span(FACE[44])
    g.hover(44, l + 1, r - 1, SK_D, (SK, SK_L))

    ey0, ey1 = (30, 36) if sex == "boy" else (29, 36)
    exs = [(22, 27), (36, 41)] if sex == "boy" else [(21, 27), (36, 42)]
    # 눈
    for (a, b) in exs:
        for y in range(ey0, ey1 + 1):
            x0, x1 = a, b
            if y == ey0:
                x0, x1 = a + 1, b - 1
            if y == ey1:
                x0, x1 = a + 1, b - 1
            for x in range(x0, x1 + 1):
                g.over(x, y, EYE, SKINS + (BROW,))
        # 반짝임
        g.rect(a + 1, ey0 + 1, a + 2, ey0 + 2, WHT)
        g.put(b - 1, ey1 - 2, WHT)
    # 볼 — 납작한 분홍 사각
    for y in (37, 38):
        g.hover(y, 20, 23, SK_CH, SKINS)
        g.hover(y, 40, 43, SK_CH, SKINS)
    # 입 — 웃는 입 (작으면 얼굴이 텅 빈 판이 된다)
    if sex == "boy":
        g.put(29, 40, SK_M)
        g.put(34, 40, SK_M)
        g.hline(41, 30, 33, SK_M)
    else:
        g.put(30, 40, SK_M)
        g.put(33, 40, SK_M)
        g.hline(41, 31, 32, SK_M)


def draw_body(g, sex):
    body = BODY if sex == "boy" else BODY_G
    # 목
    g.rect(28, 45, 35, 46, SK)
    g.hline(45, 28, 35, SK_DD)
    # 몸통
    top = 47
    bot = 73 if sex == "boy" else 67
    g.fill_curve(body, SH, y0=top, y1=bot)
    if sex == "boy":
        g.fill_curve(body, PT_DD, y0=68, y1=69)     # 벨트
        g.fill_curve(body, PT, y0=70, y1=73)
    # 옷깃
    g.hline(47, 27, 36, SH_LL)
    g.hline(48, 28, 35, SH_LL)
    g.put(31, 49, SH_LL)
    g.put(32, 49, SH_LL)
    # 몸통 음영
    for y in range(49, bot + 1):
        if y not in body:
            continue
        l, r = span(body[y])
        g.over(l + 1, y, SH_L, (SH,))
        for x in range(r - 2, r):
            g.over(x, y, SH_D, (SH,))
    # 앞섶 + 단추 (파란 판때기 하나로 보이지 않게)
    shirt_bot = 67 if sex == "boy" else 66
    for y in range(50, shirt_bot):
        g.over(32, y, SH_DD, (SH, SH_D))
    for y in (52, 57, 62):
        g.over(30, y, SH_LL, (SH, SH_L))
        g.over(31, y, SH_LL, (SH, SH_L))


def draw_arms(g, sex):
    slv = 62 if sex == "boy" else 60      # 소매 끝
    top, bot = 50, 69
    for y in range(top, bot + 1):
        if y == 50:
            xl0, xl1 = 20, 22
        elif y == 51:
            xl0, xl1 = 19, 22
        else:
            xl0, xl1 = 18, 22
        c = SH if y <= slv else SK
        for x in range(xl0, xl1 + 1):
            g.put(x, y, c)
            g.put(63 - x, y, c)
    for y in range(66, 70):               # 손
        x0 = 19 if y == 69 else 18
        for x in range(x0, 23):
            g.put(x, y, SK)
            g.put(63 - x, y, SK)
    for x in range(18, 23):               # 손목
        g.put(x, 65, SK_D)
        g.put(63 - x, 65, SK_D)
    g.put(19, 67, SK_D)                   # 주먹 골
    g.put(44, 67, SK_D)
    g.hline(slv, 18, 22, SH_LL)           # 소매 끝단
    g.hline(slv, 41, 45, SH_LL)
    for y in range(52, bot + 1):          # 팔 음영
        base = SH if y <= slv else SK
        lit = SH_L if y <= slv else SK_L
        shd = SH_D if y <= slv else SK_D
        g.over(19, y, lit, (base,))
        g.over(21, y, shd, (base,))
        g.over(42, y, lit, (base,))
        g.over(44, y, shd, (base,))
    for y in range(52, bot + 1):          # 팔과 몸통 사이 검정 줄
        g.put(22, y, OL)
        g.put(41, y, OL)


def draw_legs(g, sex):
    if sex == "boy":
        for y in range(74, 87):           # 바지
            t = (y - 74) / 12.0
            l = int(round(22 + t))
            g.hline(y, l, 30, PT)
            g.hline(y, 33, 63 - l, PT)
            g.over(l + 1, y, PT_L, (PT,))       # 왼다리 바깥 밝은면
            g.over(29, y, PT_D, (PT,))          # 왼다리 안쪽 그늘
            g.over(30, y, PT_D, (PT,))
            g.over(34, y, PT_L, (PT,))          # 오른다리 안쪽 밝은면
            g.over(62 - l, y, PT_D, (PT,))      # 오른다리 바깥 그늘
            g.over(63 - l, y, PT_D, (PT,))
        for y in (85, 86):                # 바지 밑단 — 장화에 넣었다
            g.hover(y, 22, 30, PT_DD, PANTS)
            g.hover(y, 33, 41, PT_DD, PANTS)
        for y in range(72, 96):           # 두 다리 사이 검정 줄
            g.put(31, y, OL)
            g.put(32, y, OL)
        # 신발 — 목 있는 장화
        for y in range(87, 96):
            x0 = 20 if y >= 90 else 21
            g.hline(y, x0, 30, SO)
            g.hline(y, 33, 63 - x0, SO)
            g.over(29, y, SO_D, (SO,))
            g.over(30, y, SO_D, (SO,))
            g.over(62 - x0, y, SO_D, (SO,))
            g.over(63 - x0, y, SO_D, (SO,))
        g.hline(87, 21, 30, SO_D)         # 장화 목 테
        g.hline(87, 33, 42, SO_D)
        for y in range(94, 96):           # 밑창
            g.hline(y, 20, 30, SO_DD)
            g.hline(y, 33, 43, SO_DD)
    else:
        g.fill_curve(SKIRT, PT, y0=66, y1=79)
        for y in sorted(SKIRT):
            l, r = span(SKIRT[y])
            g.over(l + 1, y, PT_L, (PT,))
            for x in range(r - 2, r):
                g.over(x, y, PT_D, (PT,))
        for y in (66, 67):                # 허리단
            l, r = span(SKIRT[y])
            g.hover(y, l, r, PT_DD, (PT, PT_L, PT_D))
        for y in range(70, 80):           # 치마 주름
            g.over(25, y, PT_D, (PT,))
            g.over(30, y, PT_D, (PT,))
            g.over(33, y, PT_D, (PT,))
            g.over(38, y, PT_D, (PT,))
        l, r = span(SKIRT[79])            # 밑단
        g.hover(79, l, r, PT_DD, (PT, PT_L, PT_D))
        for y in range(80, 88):           # 맨다리
            g.hline(y, 24, 30, SK)
            g.hline(y, 33, 39, SK)
            g.over(25, y, SK_L, (SK,))
            g.over(30, y, SK_D, (SK,))
            g.over(34, y, SK_L, (SK,))
            g.over(39, y, SK_D, (SK,))
        for y in range(80, 96):
            g.put(31, y, OL)
            g.put(32, y, OL)
        for y in range(88, 96):           # 단화
            x0 = 22 if y >= 90 else 23
            g.hline(y, x0, 30, SO)
            g.hline(y, 33, 63 - x0, SO)
            g.over(29, y, SO_D, (SO,))
            g.over(30, y, SO_D, (SO,))
            g.over(62 - x0, y, SO_D, (SO,))
            g.over(63 - x0, y, SO_D, (SO,))
        g.hline(88, 23, 30, SO_D)
        g.hline(88, 33, 40, SO_D)
        for y in range(94, 96):
            g.hline(y, 22, 30, SO_DD)
            g.hline(y, 33, 41, SO_DD)


def draw_girl_locks(g):
    """여자 옆머리 — 어깨 앞으로 내려온다. 팔은 가리지 않는다."""
    lock = curve([(28, 15.2), (34, 15.8), (42, 16.6), (48, 17.2), (51, 17.2),
                  (53, 16.6), (55, 15.8), (56, 15.0)])
    inner = curve([(28, 13.0), (34, 13.2), (42, 13.6), (48, 13.9), (51, 14.2),
                   (53, 14.4), (55, 14.6), (56, 14.6)])
    for y in sorted(lock):
        ol, orr = span(lock[y])
        il, ir = span(inner[y])
        if il < ol:
            continue
        g.hline(y, ol, il, HR)
        g.hline(y, ir, orr, HR)
    for y in sorted(lock):
        ol, orr = span(lock[y])
        il, ir = span(inner[y])
        g.over(ol + 1, y, HR_L, (HR,))
        g.over(il, y, HR_D, (HR,))
        g.over(orr, y, HR_D, (HR,))
        g.over(ir, y, HR_D, (HR,))


def build(sex):
    g = G()
    draw_head(g, sex)
    draw_body(g, sex)
    draw_legs(g, sex)
    draw_arms(g, sex)
    if sex == "girl":
        draw_girl_locks(g)
    draw_face_parts(g, sex)
    outline_pass(g)
    return g


# ---------------------------------------------------------------- 출력
def render(g):
    im = Image.new("RGBA", (GW, GH), (0, 0, 0, 0))
    px = im.load()
    for y in range(GH):
        for x in range(GW):
            c = g.g[y][x]
            if c is not None:
                px[x, y] = (c[0], c[1], c[2], 255)
    big = im.resize((OW, OH), Image.NEAREST)
    out = Image.new("RGBA", (OW, OH), (0, 0, 0, 0))
    out.paste(big, (0, -1))
    return out


def make_view(boy, girl):
    grass = (122, 150, 96, 255)
    big_b = boy.resize((OW * 3, OH * 3), Image.NEAREST)
    big_g = girl.resize((OW * 3, OH * 3), Image.NEAREST)
    sw, sh = 36, 54
    small_b = boy.resize((sw, sh), Image.LANCZOS)
    small_g = girl.resize((sw, sh), Image.LANCZOS)
    zoom_b = small_b.resize((sw * 4, sh * 4), Image.NEAREST)
    zoom_g = small_g.resize((sw * 4, sh * 4), Image.NEAREST)

    pad = 24
    left_w = big_b.width + big_g.width + pad
    right_w = max(zoom_b.width + zoom_g.width + pad, sw * 2 + pad)
    W = pad + left_w + pad * 2 + right_w + pad
    H = pad * 2 + big_b.height
    canvas = Image.new("RGBA", (W, H), grass)
    y0 = pad
    canvas.alpha_composite(big_b, (pad, y0))
    canvas.alpha_composite(big_g, (pad + big_b.width + pad, y0))
    rx = pad + left_w + pad * 2
    canvas.alpha_composite(small_b, (rx, y0))
    canvas.alpha_composite(small_g, (rx + sw + pad, y0))
    canvas.alpha_composite(zoom_b, (rx, y0 + sh + pad))
    canvas.alpha_composite(zoom_g, (rx + zoom_b.width + pad, y0 + sh + pad))
    return canvas


# ---------------------------------------------------------------- 검사
def check(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    msgs = []
    ok = True
    if im.size != (OW, OH):
        ok = False
        msgs.append("크기 %s (128x192 아님)" % (im.size,))
    else:
        msgs.append("크기 OK 128x192")

    alphas = set()
    bottom = -1
    top = 10 ** 9
    left = 10 ** 9
    right = -1
    colors = {}
    opaque = []
    for y in range(im.height):
        for x in range(im.width):
            r, g_, b, a = px[x, y]
            alphas.add(a)
            if a > 0:
                opaque.append((x, y))
                bottom = max(bottom, y)
                top = min(top, y)
                left = min(left, x)
                right = max(right, x)
                colors[(r, g_, b)] = colors.get((r, g_, b), 0) + 1
    if bottom != 190:
        ok = False
        msgs.append("발바닥 최하단 y=%d (190 이어야 함)" % bottom)
    else:
        msgs.append("발바닥 y=190 OK")
    bad_a = sorted(a for a in alphas if a not in (0, 255))
    if bad_a:
        ok = False
        msgs.append("반투명 알파 %s" % bad_a)
    else:
        msgs.append("알파 0/255 만 OK")
    off = [c for c in colors if c not in PALETTE]
    msgs.append("표 밖 색 %d 개%s" % (len(off), (" " + str(off[:6])) if off else ""))
    if off:
        ok = False
    opset = set(opaque)
    comps = 0
    seen = set()
    biggest = 0
    for p in opaque:
        if p in seen:
            continue
        comps += 1
        stack = [p]
        seen.add(p)
        n = 0
        while stack:
            cx, cy = stack.pop()
            n += 1
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (cx + dx, cy + dy)
                if q in opset and q not in seen:
                    seen.add(q)
                    stack.append(q)
        biggest = max(biggest, n)
    if comps != 1:
        ok = False
        msgs.append("연결 요소 %d 개 (떠 있는 덩어리 있음, 가장 큰 덩어리 %d px)" % (comps, biggest))
    else:
        msgs.append("연결 요소 1 개 OK")
    msgs.append("bbox x %d..%d (중심 %.1f), y %d..%d" %
                (left, right, (left + right) / 2.0, top, bottom))
    return ok, msgs


def main():
    outs = {}
    for sex in ("boy", "girl"):
        g = build(sex)
        im = render(g)
        p = os.path.join(HERE, "b64x2_%s.png" % sex)
        im.save(p)
        outs[sex] = im
        print("== %s" % p)
        ok, msgs = check(p)
        for m in msgs:
            print("   " + m)
        print("   => %s" % ("OK" if ok else "고칠 것"))
    view = make_view(outs["boy"], outs["girl"])
    vp = os.path.join(HERE, "b64x2_view.png")
    view.save(vp)
    print("== %s (%dx%d)" % (vp, view.width, view.height))


if __name__ == "__main__":
    main()
