# -*- coding: utf-8 -*-
# 주인공 — **손으로 찍는다.** (남 · 여 각 한 명)
#
# 4판까지는 눈이 얼굴 폭의 절반을 먹었다. 참고로 받은 그림을 재 보니
# 얼굴 35칸에 눈은 한쪽 8칸 — 두 눈을 합쳐도 **폭의 절반이 아니라 1/4** 이다.
# 눈이 크면 귀여운 게 아니라 못생긴다. 그래서 이 판은 비율부터 다시 적었다:
#
#   · 얼굴 폭 35 (여) / 38 (남), 눈 한쪽 8칸, 눈 사이 8칸
#   · 눈은 얼굴 세로의 55% 지점 — 위쪽 45%는 이마와 머리
#   · 명암은 **낮은 대비**. 참고 그림의 얼굴에는 안쪽 윤곽선이 아예 없고,
#     살결이 거의 한 색이며 가장자리만 반 단 가라앉는다
#   · 윤곽선은 실루엣에만. 그것도 재질마다 다른 어두운 색
#
# 여전히 모양을 만드는 것은 전부 손이다:
#   얼굴 옆선은 y 마다 반폭을 적고, 머리 실루엣도 y 마다 반폭을 적고,
#   앞머리는 가닥마다 (x, y, 굵기) 를 적고, 눈·입은 칸마다 글자를 적는다.
import os
from PIL import Image

W, H = 128, 192

# 색감의 원리 — 참고로 받은 그림을 뜯어 보면 규칙이 셋이다.
#   1. **눈만 채도가 높다.** 살결·머리·옷은 전부 회색 쪽으로 죽어 있고,
#      홍채 하나만 쨍하다. 그래서 시선이 눈으로 간다
#   2. **그늘은 어두워지는 게 아니라 보랏빛으로 돈다.** 명도만 낮춘 그늘은
#      때가 낀 것처럼 보인다
#   3. **윤곽은 거의 검정**, 그것도 푸른 보랏빛이 도는 검정. 갈색 윤곽은
#      그림을 흙빛으로 만든다
PAL = {
    # ── 윤곽. 재질마다 다르되 전부 검정에 가깝게
    'Os': (58, 38, 48), 'Oh': (32, 24, 34), 'Ob': (22, 26, 52),
    'Op': (44, 30, 24), 'Ok': (24, 18, 18),
    # 계단 진 모서리에 놓는 중간색 — 윤곽과 속살 사이
    'os': (104, 68, 78), 'oh': (74, 58, 58), 'ob': (44, 52, 88),
    'op': (78, 58, 44), 'ok': (48, 38, 34),

    # ── 살결 여섯 단. 창백하게, 그늘은 보랏빛으로
    'H2': (252, 238, 234), 'H1': (246, 220, 214), 's': (238, 198, 190),
    'S1': (216, 166, 164), 'S2': (182, 130, 136), 'S3': (140, 94, 106),
    'r': (238, 170, 172), 'm': (172, 106, 112), 'M': (120, 64, 76),

    # ── 머리 여섯 단. 갈색을 회색 쪽으로 죽인다 (주황빛 갈색은 촌스럽다)
    'G2': (54, 42, 46), 'G': (86, 68, 62), 'g': (118, 96, 82),
    'h': (150, 126, 104), 'j': (182, 158, 130), 'J': (214, 192, 164),

    # ── 눈 — 그림에서 **유일하게 채도가 높은 자리**
    'e': (44, 30, 42), 'e1': (92, 68, 82),
    'i': (86, 52, 40), 'i1': (146, 90, 42), 'i2': (206, 148, 58),
    'i3': (250, 212, 110),
    'w': (252, 250, 252), 'W': (222, 216, 224), 'V': (188, 180, 194),
    'br': (124, 100, 84),

    # ── 옷 (몸을 이을 때). 같은 규칙 — 채도를 눌러 둔다
    'B3': (26, 32, 58), 'B2': (42, 56, 96), 'B1': (64, 86, 140),
    'b': (92, 118, 176), 'L1': (132, 158, 206), 'L2': (184, 204, 234),
    'P3': (56, 42, 32), 'P2': (86, 66, 48), 'P1': (118, 94, 68),
    'p': (152, 126, 94), 'q1': (186, 162, 128), 'q2': (216, 198, 172),
    'K2': (32, 26, 24), 'K1': (58, 46, 40), 'k': (90, 74, 62),
}

SKIN = ('H2', 'H1', 's', 'S1', 'S2', 'S3', 'r', 'm', 'M')
HAIR = ('G2', 'G', 'g', 'h', 'j', 'J')
EYEC = ('e', 'e1', 'i', 'i1', 'i2', 'i3', 'w', 'W', 'V', 'br')
MAT = {}
for _k in SKIN:
    MAT[_k] = 'Os'
for _k in HAIR + EYEC:
    MAT[_k] = 'Oh'
for _k in ('B3', 'B2', 'B1', 'b', 'L1', 'L2'):
    MAT[_k] = 'Ob'
for _k in ('P3', 'P2', 'P1', 'p', 'q1', 'q2'):
    MAT[_k] = 'Op'
for _k in ('K2', 'K1', 'k'):
    MAT[_k] = 'Ok'
SOFT = {'Os': 'os', 'Oh': 'oh', 'Ob': 'ob', 'Op': 'op', 'Ok': 'ok'}

DARKER = {'H2': 'H1', 'H1': 's', 's': 'S1', 'S1': 'S2', 'S2': 'S3'}


class C:
    def __init__(self):
        self.d = [[None] * W for _ in range(H)]

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.d[y][x] = c

    def at(self, x, y):
        return self.d[y][x] if 0 <= x < W and 0 <= y < H else None

    def table(self, top, tbl, c, cx=64, only_empty=False, inner=None):
        """y 마다 반폭을 적은 표로 실루엣을 채운다 — 옆선을 내가 정하는 방식.
        inner 를 주면 가운데를 그만큼 비운다(얼굴 옆으로 흘러내리는 머리)."""
        for i, hw in enumerate(tbl):
            y = top + i
            a = int(round(cx - hw))
            b = int(round(cx + hw))
            iw = inner[i] if inner else 0.0
            for x in range(a, b + 1):
                if iw and abs(x - cx) <= iw:
                    continue
                if only_empty and self.at(x, y) is not None:
                    continue
                self.px(x, y, c)

    def blob(self, cx, cy, rx, ry, c, over=None):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            t = (y - cy) / float(ry)
            if abs(t) > 1:
                continue
            hw = rx * (1 - t * t) ** 0.5
            for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
                if over is None or self.at(x, y) in over:
                    self.px(x, y, c)

    def band(self, cx, cy, rx, ry, c, over, phase=0):
        """한 칸 걸러 찍는 손 디더 — 단 사이 계단을 흐린다."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            t = (y - cy) / float(ry)
            if abs(t) > 1:
                continue
            hw = rx * (1 - t * t) ** 0.5
            for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
                if (x + y) % 2 == phase and self.at(x, y) in over:
                    self.px(x, y, c)

    def rows(self, x0, y0, art, keymap=None):
        km = keymap or {}
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch != '.':
                    self.px(x0 + dx, y0 + dy, km.get(ch, ch))

    def strand(self, pts, c, edge=None, tip=None, tipn=0):
        """머리 가닥 하나 — (x, y, 반폭) 점을 이어 긋는다."""
        cells = []
        for i in range(len(pts) - 1):
            x0, y0, w0 = pts[i]
            x1, y1, w1 = pts[i + 1]
            n = max(abs(x1 - x0), abs(y1 - y0), 1) * 3
            for k in range(n + 1):
                t = k / n
                cx = x0 + (x1 - x0) * t
                cy = y0 + (y1 - y0) * t
                hw = w0 + (w1 - w0) * t
                a, b = int(round(cx - hw)), int(round(cx + hw))
                for x in range(a, b + 1):
                    cells.append((x, int(round(cy)), x - a))
        total = len(cells)
        for idx, (x, y, off) in enumerate(cells):
            col = c
            if edge and off == 0:
                col = edge
            if tip and idx > total - tipn:
                col = tip
            self.px(x, y, col)

    def shade_under_hair(self):
        """머리카락이 살에 드리우는 그늘 — **아래로만** 한 단.
        사방을 두르면 얼굴에 테두리가 생겨 인쇄된 무늬처럼 보인다."""
        hit = []
        for y in range(H):
            for x in range(W):
                c = self.d[y][x]
                if c not in DARKER:
                    continue
                dist = 0
                for k in (1, 2, 3):
                    if self.at(x, y - k) in HAIR:
                        dist = k
                        break
                if not dist:
                    continue
                if dist > 3:
                    continue
                hit.append((x, y, DARKER[c]))          # 한 단만. 두 단은 때다
        for x, y, c in hit:
            self.px(x, y, c)

    def outline(self):
        edge = []
        for y in range(H):
            for x in range(W):
                if self.d[y][x] is not None:
                    continue
                vote = {}
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    m = MAT.get(self.at(x + dx, y + dy))
                    if m:
                        vote[m] = vote.get(m, 0) + 2
                if not vote:
                    continue
                for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                    m = MAT.get(self.at(x + dx, y + dy))
                    if m:
                        vote[m] = vote.get(m, 0) + 1
                n = sum(1 for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1),
                                         (-1, -1), (1, -1), (-1, 1), (1, 1))
                        if self.at(x + dx, y + dy) is not None)
                col = max(vote, key=vote.get)
                edge.append((x, y, col if n >= 5 else SOFT[col]))
        for x, y, c in edge:
            self.px(x, y, c)

    def save(self, path):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        o = im.load()
        for y in range(H):
            for x in range(W):
                c = self.d[y][x]
                if c:
                    o[x, y] = PAL[c] + (255,)
        im.save(path)
        return im


CX = 64

# ------------------------------------------------------------------ 얼굴 옆선
# y 20 부터 줄마다 반폭. 타원으로는 남녀가 안 갈린다 — 갈리는 건
# **옆선이 어디서부터 꺾이느냐**다.
FACE_TOP = 20
FACE_F = [4.4, 7.0, 8.9, 10.3, 11.4, 12.3, 13.1, 13.8, 14.3, 14.8,
          15.2, 15.5, 15.8, 16.0, 16.1, 16.2, 16.3, 16.3, 16.3, 16.2,
          16.1, 16.0, 15.8, 15.6, 15.3, 15.0, 14.7, 14.3, 13.9, 13.4,
          12.9, 12.4, 11.8, 11.2, 10.5, 9.8, 9.0, 8.2, 7.3, 6.4,
          5.4, 4.3, 3.1, 1.8]                                    # y 20~63
FACE_M = [4.8, 7.6, 9.7, 11.2, 12.4, 13.4, 14.3, 15.0, 15.6, 16.1,
          16.5, 16.9, 17.2, 17.4, 17.6, 17.7, 17.8, 17.8, 17.8, 17.8,
          17.7, 17.6, 17.5, 17.4, 17.2, 17.0, 16.8, 16.5, 16.2, 15.9,
          15.5, 15.1, 14.7, 14.2, 13.7, 13.1, 12.5, 11.8, 11.1, 10.3,
          9.4, 8.4, 7.2, 5.8, 4.2]                               # y 20~64

# ------------------------------------------------------------------ 머리 실루엣
HAIR_TOP = 12
CAP_F = [4.0, 8.0, 11.0, 13.5, 15.5, 17.2, 18.6, 19.8, 20.8, 21.6,
         21.4, 21.9, 22.2, 22.5, 22.7, 22.8, 22.9, 23.0, 23.0, 23.0,
         23.0, 23.0, 23.0, 23.0, 23.0, 23.0, 23.0, 23.0, 23.0, 23.0,
         23.0, 23.0, 23.0, 23.0, 23.0, 23.0, 23.0, 22.9, 22.8, 22.6,
         22.4, 22.1, 21.8, 21.4, 21.0]                           # y 12~56
# 턱 옆으로 흘러내리는 단발 — 바깥 반폭과 안쪽 반폭(비우는 폭)을 함께 적는다
HANG_TOP = 57
HANG_OUT = [21.7, 21.6, 21.5, 21.4, 21.2, 21.0, 20.7, 20.4, 20.0, 19.5,
            18.9, 18.2, 17.4, 16.4, 15.2, 13.8, 12.2]            # y 57~73
HANG_IN = [6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.4, 9.8, 10.1, 10.4,
           10.6, 10.8, 11.0, 11.0, 11.0, 11.0, 11.0]

CAP_M = [4.0, 7.8, 10.6, 12.9, 14.8, 16.4, 17.7, 18.8, 19.6, 20.3,
         20.8, 21.2, 21.5, 21.7, 21.8, 21.8, 21.7, 21.5, 21.3, 21.0,
         20.7, 20.4, 20.1, 19.8, 19.5, 19.2, 18.9, 18.6, 18.3, 18.0,
         17.6, 17.1, 16.4, 15.4, 14.0]                           # y 12~46

# ------------------------------------------------------------------ 앞머리
# 앞머리는 가닥을 흩뿌리는 게 아니라 **통으로 덮고 아래 끝만 이빨로 적는** 것이다.
# 이빨 하나 = (끝 x, 끝 y, 반폭). 끝 y 와 반폭을 저마다 다르게 적어야
# 톱날이 아니라 머리카락으로 읽힌다. BASE 는 이빨 사이가 올라가는 높이.
TEETH_F, BASE_F = [(48, 39, 5.5), (55, 36, 4.0), (62, 40, 6.0),
                   (70, 37, 4.5), (77, 40, 5.5), (82, 37, 3.5)], 32
# 남자 — 이빨이 얕고 높고, 오른쪽으로 갈수록 내려온다(가르마에서 쓸어 넘긴 결).
# 이마가 넓게 드러나는 것 하나가 성별을 만든다
TEETH_M, BASE_M = [(44, 35, 4.5), (50, 31, 4.0), (56, 28, 4.0),
                   (62, 31, 4.0), (69, 34, 4.5), (76, 37, 4.5),
                   (83, 38, 4.0)], 24
# 가르마에서 오른쪽 아래로 흐르는 결 — 남자 머리의 방향을 만드는 선
SWEEP_M = [(57, 16), (61, 20), (65, 24), (69, 28), (73, 31), (77, 34)]

LOCKS_F = [   # 귀 앞으로 흘러내리는 잔가닥
    [(46, 30, 2.2), (45, 40, 2.4), (45, 50, 1.6), (46, 57, 0.7)],
    [(82, 30, 2.2), (83, 40, 2.4), (83, 50, 1.6), (82, 57, 0.7)],
]
LOCKS_M = [   # 구레나룻 — 귀 앞에서 멎는다. 짧아야 남자로 읽힌다
    [(46, 30, 2.2), (45, 36, 2.0), (45, 42, 1.2), (46, 46, 0.5)],
    [(82, 30, 2.2), (83, 36, 2.0), (83, 42, 1.2), (82, 46, 0.5)],
]
# 천사링이 지나는 자리 — 가로 막대가 아니라 **머리통을 따라 휘는 호**다.
# 빛이 왼쪽 위에 있으므로 호의 꼭대기도 가운데(64)가 아니라 왼쪽(59)이다.
SHINE_X = [(45, 51), (54, 60), (63, 69), (72, 77)]   # 끊어 놓아야 고리로 읽힌다


# 빛이 닿는 꼭짓점 — 머리통의 왼쪽 위. 여기서 멀어질수록 어두워진다
LIT = (57.0, 28.0)
LIT_R = (25.0, 27.0)
# 천사링을 드러낼 각도 토막 (라디안). 이어 놓으면 띠가 되므로 끊는다
SHINE_A = [(-2.95, -2.45), (-2.30, -1.95), (-1.80, -1.40), (-1.20, -0.75)]


def sphere(x, y):
    """머리통 위에서 빛의 꼭짓점까지의 거리 — 이게 명암의 기준이다."""
    u = (x - LIT[0]) / LIT_R[0]
    v = (y - LIT[1]) / LIT_R[1]
    return (u * u + v * v) ** 0.5, u, v


def bang_bottom(x, teeth, base):
    b = float(base)
    for tx, ty, hw in teeth:
        d = abs(x - tx)
        if d <= hw:
            b = max(b, ty - (ty - base) * (d / hw) ** 2)   # 끝을 뭉툭하게
    return b

# ------------------------------------------------------------------ 얼굴 부속
# 눈 8 x 7. 참고 그림처럼 흰자는 바깥 한 칸뿐이고 홍채가 눈을 거의 채운다.
#   e 속눈썹 · E 연한 속눈썹 · W/V 흰자 · w 반짝 · i→1→2→3 홍채 네 단
EYE_KEY = {'e': 'e', 'E': 'e1', 'W': 'W', 'V': 'V', 'i': 'i', '1': 'i1',
           '2': 'i2', '3': 'i3', 'w': 'w', 'H': 'H2', 'S': 'S1'}
EW = 9

EYE_F = [
    '.eeeeeee.',
    'eeeeeeeee',
    'eViii112e',
    'eWi1w223e',
    'e11223332',
    '.EEEEEE..',
]
LID_F = ['ee.....ee', '.eeeeeee.', '..EEEEE..']
BROW_F = ['..GGGb...', '.bG....b.']

EYE_M = [
    '.eeeeeee.',
    'eeeeeeeee',
    'eVii112we',
    'e11223332',
    '.EEEEEE..',
]
LID_M = ['ee.....ee', '.eeeeeee.']
BROW_M = ['.GGGGGb..', 'bGb......']
BROW_KEY = {'b': 'br', 'G': 'G'}

MOUTH_F = ['m...m', '.mMm.', '..H..']
MOUTH_M = ['m...m', '.mmm.']
MOUTH_KEY = {'m': 'm', 'M': 'M', 'H': 'H1'}


def flip(art):
    return [r[::-1] for r in art]


def hair_shade(c, girl, teeth, base):
    """머리 명암 — 얼룩을 얹는 게 아니라 **천사링 호를 기준으로** 칠한다.

    호 위는 중간 톤, 호 자리는 밝게(끊어서), 호 아래로 갈수록 어둡게.
    빛이 왼쪽 위에 있으므로 x 가 오른쪽일수록 한 단씩 더 내린다.
    참고 그림의 머리가 부드러운 이유는 단 사이가 좁고 얼룩이 없어서다."""
    import math
    for y in range(H):
        for x in range(W):
            if c.at(x, y) not in HAIR:
                continue
            d, u, v = sphere(x, y)
            if d < 0.50:
                col = 'h'                                  # 빛 받는 정수리
            elif d < 0.76:
                a = math.atan2(v, u)
                ring = v < 0.34 and any(p <= a <= q for p, q in SHINE_A)
                col = 'J' if ring else 'j'                 # 천사링
            elif d < 1.02:
                col = 'g'
            elif d < 1.30:
                col = 'G'
            else:
                col = 'G2'
            # 단 사이 계단을 한 칸 걸러 흐린다 (경계 폭 한 칸에서만)
            if 0.96 <= d < 1.02 and (x + y) % 2:
                col = 'G'
            elif 1.24 <= d < 1.30 and (x + y) % 2:
                col = 'G2'
            c.px(x, y, col)
    # 앞머리 끝 두 칸은 어둡게 — 이마에서 머리가 떨어져 보이게 하는 건 이것뿐
    for x in range(CX - 26, CX + 27):
        b = int(round(bang_bottom(x, teeth, base)))
        for y in (b, b - 1):
            if c.at(x, y) in HAIR:
                c.px(x, y, 'G2' if y == b else 'G')
    # 이빨과 이빨 **사이**(골)에서 위로 뻗는 어두운 줄 — 가닥이 갈라진 자리
    for k in range(len(teeth) - 1):
        vx = (teeth[k][0] + teeth[k + 1][0]) // 2
        top = int(round(bang_bottom(vx, teeth, base)))
        for y in range(top - 9, top + 1):
            if c.at(vx, y) in HAIR:
                c.px(vx, y, 'G')
    # 이빨 한가운데는 한 단 밝게 — 골과 짝이 되어야 결로 읽힌다
    for tx, ty, hw in teeth:
        top = int(round(bang_bottom(tx, teeth, base)))
        for y in range(top - 10, top - 2):
            if c.at(tx, y) in HAIR:
                c.px(tx, y, 'h')


def head(c, sex, blink=False):
    girl = sex == 'f'
    face = FACE_F if girl else FACE_M
    eye = EYE_F if girl else EYE_M
    lid = LID_F if girl else LID_M
    brow = BROW_F if girl else BROW_M
    chin = FACE_TOP + len(face) - 1

    # ── 살결. 옆선표대로 채우고 명암은 **낮은 대비**로 얹는다
    c.table(FACE_TOP, face, 's')
    c.blob(CX - 4, 39, 13, 18, 'H1', over={'s'})           # 밝은 면은 왼쪽 위
    c.blob(CX - 6, 32, 7, 5, 'H2', over={'H1'})            # 이마 빛
    c.blob(CX + 14, 42, 5, 15, 'S1', over={'s', 'H1'})     # 오른쪽 가장자리
    c.band(CX + 10, 42, 1, 15, 'S1', {'H1', 's'}, phase=0)  # 경계 한 줄만
    c.blob(CX + 16, 43, 3, 10, 'S2', over={'S1'})
    # 턱 밑 반사광 — 아래에서 올라오는 빛 한 줄. 얼굴이 공처럼 떠오른다
    for i, hw in enumerate(face):
        y = FACE_TOP + i
        if y < chin - 9:
            continue
        for x in range(int(CX - hw), int(CX + hw) + 1):
            if c.at(x, y) in ('s', 'H1') and c.at(x, y + 2) is None:
                c.px(x, y, 'S1')

    # ── 눈. 얼굴 세로의 55% 지점, 눈 사이는 눈 하나 폭
    ey = 41 if girl else 42
    lx, rx = CX - 4 - EW, CX + 4
    if blink:
        c.rows(lx, ey + 3, lid, EYE_KEY)
        c.rows(rx, ey + 3, lid, EYE_KEY)
    else:
        c.rows(lx, ey, eye, EYE_KEY)
        c.rows(rx, ey, flip(eye), EYE_KEY)
    # 눈두덩 그늘 — 반 단만
    for cx0 in (lx + 3, rx + EW - 4):
        c.blob(cx0, ey - 2, 4, 0.9, 'S1', over={'H1', 's'})

    # ── 코. 한 칸 그늘 + 한 칸 빛. 두 칸을 넘기면 얼굴이 늙는다
    ny = chin - 10
    c.px(CX, ny, 'S1')
    c.px(CX + 1, ny, 'S2' if not girl else 'S1')
    c.px(CX - 1, ny, 'H2')

    # ── 입
    my = chin - 6
    c.rows(CX - 2, my, MOUTH_F if girl else MOUTH_M, MOUTH_KEY)

    # ── 볼. 여자는 옅은 홍조, 남자는 반 단만 가라앉힌다
    for cx0 in (lx + 3, rx + EW - 4):
        c.blob(cx0, ey + 9, 4, 1.4, 'r' if girl else 'S1',
               over={'H1', 's', 'S1'})

    # ── 머리. 실루엣 → 앞머리를 통으로 덮기 → 잔가닥 → 명암
    c.table(HAIR_TOP, CAP_F if girl else CAP_M, 'g', only_empty=True)
    if girl:
        c.table(HANG_TOP, HANG_OUT, 'g', only_empty=True, inner=HANG_IN)
    teeth, base = (TEETH_F, BASE_F) if girl else (TEETH_M, BASE_M)
    for x in range(CX - 26, CX + 27):
        col = [y for y in range(FACE_TOP, 62) if c.at(x, y) in SKIN]
        if not col:
            continue
        for y in range(col[0], int(round(bang_bottom(x, teeth, base))) + 1):
            if c.at(x, y) in SKIN:
                c.px(x, y, 'g')
    for pts in (LOCKS_F if girl else LOCKS_M):
        c.strand(pts, 'g')
    hair_shade(c, girl, teeth, base)
    if not girl:
        # 가르마 결 — 한 줄 어둡게 긋고 그 옆을 한 단 밝게. 두 줄이 짝이
        # 되어야 「쓸어 넘긴 방향」으로 읽힌다
        for k in range(len(SWEEP_M) - 1):
            x0, y0 = SWEEP_M[k]
            x1, y1 = SWEEP_M[k + 1]
            n = max(abs(x1 - x0), abs(y1 - y0)) * 2
            for t in range(n + 1):
                x = int(round(x0 + (x1 - x0) * t / n))
                y = int(round(y0 + (y1 - y0) * t / n))
                if c.at(x, y) in HAIR:
                    c.px(x, y, 'G')
                if c.at(x, y - 1) in HAIR:
                    c.px(x, y - 1, 'j')

    # ── 눈썹은 앞머리 위에 (애니 얼굴은 앞머리 사이로 눈썹이 비친다)
    c.rows(lx, ey - 4, brow, BROW_KEY)
    c.rows(rx, ey - 4, flip(brow), BROW_KEY)


def build(sex, blink=False):
    c = C()
    head(c, sex, blink)
    c.shade_under_hair()
    c.outline()
    return c


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    for sex in ('m', 'f'):
        for b in (False, True):
            build(sex, b).save(os.path.join(
                here, 'hand_%s%s.png' % (sex, '_blink' if b else '')))
    im = Image.open(os.path.join(here, 'hand_f.png')).convert('RGBA')
    px = im.load()
    bad = {px[x, y][:3] for y in range(im.height) for x in range(im.width)
           if px[x, y][3] and px[x, y][:3] not in set(PAL.values())}
    print('팔레트밖', len(bad), '· 색', len(PAL))
