# -*- coding: utf-8 -*-
# 주인공 — **손으로 찍는다.**
#
# 앞의 세 판은 식이 픽셀을 놓았다(격자 좌표·구·원기둥). 그림자는 매끄러워졌지만
# 「자로 그은 티」를 못 벗었다. 완벽한 타원과 완벽한 등고선은 사람이 그린 선이
# 아니기 때문이다.
#
# 여기서는 **모양을 만드는 것은 전부 손으로 적는다**:
#   · 머리카락은 가닥마다 (x, y, 굵기) 점을 내가 찍어 잇는다. 굵기가 들쭉날쭉하고
#     끝이 저마다 다른 데서 그림 맛이 난다
#   · 얼굴 부속(눈·눈썹·코·입·볼)은 칸 하나하나를 글자로 적는다
#   · 그늘도 「여기서 여기까지」를 손으로 적는다 (빛을 계산하지 않는다)
# 식이 하는 일은 **실루엣을 채우는 것**뿐이다 — 그건 매끄러워도 된다.
#
# 색은 game_data.gd 의 APPEAR_* 0번 줄과 정확히 같다 (다섯 단으로 늘린 것).
import os
from PIL import Image

W, H = 128, 192
GROUND = 190

PAL = {
    'O': (54, 33, 26),
    # 살결 — 어두운 쪽부터 (깊은그늘, 그늘, 기본, 밝은, 아주밝은)
    'S2': (184, 99, 83), 'S1': (213, 116, 98), 's': (243, 159, 138),
    'H1': (250, 192, 170), 'H2': (252, 217, 204),
    'r': (235, 128, 114), 'm': (170, 84, 66), 'M': (126, 56, 48),
    # 머리카락
    'G': (58, 35, 20), 'g': (86, 52, 30), 'h': (118, 72, 40),
    'j': (152, 100, 56), 'J': (195, 165, 140),
    # 윗도리
    'B2': (27, 41, 84), 'B1': (38, 58, 120), 'b': (58, 88, 168),
    'L1': (94, 126, 200), 'L2': (166, 184, 225),
    # 아랫도리
    'P2': (69, 43, 22), 'P1': (98, 62, 32), 'p': (134, 88, 46),
    'q1': (158, 108, 58), 'q2': (202, 174, 147),
    # 신발
    'K2': (39, 26, 18), 'K1': (56, 37, 25), 'k': (82, 53, 33),
    # 눈 — 표에 없는 고정색
    'e': (58, 38, 44), 'e1': (104, 66, 70), 'i': (96, 48, 34),
    'i1': (146, 78, 44), 'i2': (198, 132, 78), 'w': (246, 242, 234),
    'W': (214, 206, 202), 'br': (120, 72, 44),
}


class C:
    def __init__(self):
        self.d = [[None] * W for _ in range(H)]

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.d[y][x] = c

    def at(self, x, y):
        return self.d[y][x] if 0 <= x < W and 0 <= y < H else None

    def fill_ell(self, cx, cy, rx, ry, c, only_empty=False):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            t = (y - cy) / ry
            if abs(t) > 1:
                continue
            hw = rx * (1 - t * t) ** 0.5
            for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
                if only_empty and self.at(x, y) is not None:
                    continue
                self.px(x, y, c)

    def blob(self, cx, cy, rx, ry, c, over=None):
        """타원 얼룩 — 그늘 뭉치를 손으로 놓을 때. over 에 든 색 위에만 얹는다."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            t = (y - cy) / float(ry)
            if abs(t) > 1:
                continue
            hw = rx * (1 - t * t) ** 0.5
            for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
                if over is None or self.at(x, y) in over:
                    self.px(x, y, c)

    def band(self, cx, cy, rx, ry, c, over, phase=0):
        """타원 테두리를 한 칸 걸러 찍는다 — 명암 계단을 흐리는 손 디더."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            t = (y - cy) / float(ry)
            if abs(t) > 1:
                continue
            hw = rx * (1 - t * t) ** 0.5
            for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
                if (x + y) % 2 != phase:
                    continue
                if self.at(x, y) in over:
                    self.px(x, y, c)

    def rows(self, x0, y0, art, keymap=None):
        """글자 격자를 그대로 찍는다 — 얼굴 부속처럼 칸마다 뜻이 있는 것."""
        km = keymap or {}
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch == '.':
                    continue
                self.px(x0 + dx, y0 + dy, km.get(ch, ch))

    def strand(self, pts, c, edge=None, tip=None, tipn=14):
        """머리 가닥 하나 — (x, y, 반폭) 점을 이어 긋는다.

        굵기를 점마다 내가 적으므로 가닥이 저마다 다르게 부풀고 여윈다.
        edge 를 주면 왼쪽 모서리에, tip 을 주면 끝 몇 칸에 그 색을 얹는다."""
        cells = []
        for i in range(len(pts) - 1):
            x0, y0, w0 = pts[i]
            x1, y1, w1 = pts[i + 1]
            n = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
            for k in range(n + 1):
                t = k / n
                cx = x0 + (x1 - x0) * t
                cy = y0 + (y1 - y0) * t
                hw = w0 + (w1 - w0) * t
                a = int(round(cx - hw))
                b = int(round(cx + hw))
                for x in range(a, b + 1):
                    cells.append((x, int(round(cy)), x - a, b - a))
        total = len(cells)
        for idx, (x, y, off, wid) in enumerate(cells):
            col = c
            if edge and off == 0:
                col = edge
            if tip and idx > total - tipn:
                col = tip
            self.px(x, y, col)

    def outline(self):
        edge = []
        for y in range(H):
            for x in range(W):
                if self.d[y][x] is not None:
                    continue
                if any(self.at(x + dx, y + dy) is not None
                       for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    edge.append((x, y))
        for x, y in edge:
            self.px(x, y, 'O')

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


# ---------------------------------------------------------------- 얼굴 부속
#
# 칸 하나하나가 표정이라 글자로 적는다. 눈은 12 x 13.
#   · 위 속눈썹은 세 겹으로 두껍고, 바깥(왼쪽)으로 흘러내린다
#   · 홍채는 **다섯 단** — 윗눈꺼풀 그늘(i) 에서 아래 테두리 빛(2) 까지
#   · 동공은 가운데 4x3, 하이라이트는 큰 것(왼쪽 위)·작은 것(오른쪽 아래) 둘
#   · 맨 아랫줄은 애교살 — 이게 있어야 눈이 웃는다
EYE = [
    '....eeeee...',
    '..eeeeeeeee.',
    'eeeeeeeeeeee',
    'eEiiiiiiiiiE',
    'eWiwwiiiii1W',
    'eWiwwieei11W',
    'eW1iieeee11W',
    'eE11ieeee22W',
    '.E11iiee2wwW',
    '..E1122222wW',
    '..EE222222E.',
    '...EEEEEEE..',
    '....HHHH....',
]
EYE_KEY = {'e': 'e', 'E': 'e1', 'W': 'W', 'i': 'i', '1': 'i1', '2': 'i2',
           'w': 'w', 'H': 'H2'}
EYE_W, EYE_H = 12, 13

# 눈썹 — 안쪽이 굵고 바깥으로 가늘게 빠진다. 두 색을 써야 붓 자국이 난다
BROW = [
    '..GGGGb...',
    'bbG.....bb',
]
BROW_KEY = {'b': 'br', 'G': 'g'}

# 감은 눈 — 아래로 휜 선 + 바깥 속눈썹 두 갈래 + 애교살
LID = [
    'ee........ee',
    '.eeeeeeeeee.',
    '..EEEEEEEE..',
    '...HHHHHH...',
]

# 입 — 다문 미소. 양 끝이 살짝 올라가고 아랫입술에 빛이 앉는다
MOUTH = [
    'm.....m',
    '.mMMMm.',
    '..HHH..',
]
MOUTH_KEY = {'m': 'm', 'M': 'M', 'H': 'H2'}

# 볼터치 — 통으로 얹고 모서리만 둥글린다 (한 칸 걸러 찍으면 바느질 자국이 된다)
BLUSH = [
    '..rrrr..',
    '.rrrrrr.',
    'rrrrrrrr',
    '.rrrrrr.',
    '..rrrr..',
]


def flip(art):
    return [r[::-1] for r in art]


# ------------------------------------------------------------------- 머리
#
# 앞머리는 **가닥 여덟**을 손으로 찍었다. 하나씩 시작점·끝점·굵기가 다르다.
# (식으로 톱니를 만들면 톱날처럼 규칙적이라 가발로 보인다)
HEAD_CX, HEAD_CY = 64, 42
HEAD_RX, HEAD_RY = 23, 27          # 머리 46 x 54

BANGS = [
    # (시작x, 시작y, 굵기), … , (끝x, 끝y, 굵기).
    # 끝은 **눈썹 언저리(y 33~38)** 에서 멎어야 눈이 보인다. 끝 y 를 하나하나
    # 다르게 적어야 톱니가 아니라 가닥으로 읽힌다.
    [(47, 24, 3.0), (44, 29, 3.0), (43, 34, 1.6), (44, 38, 0.6)],
    [(52, 20, 3.8), (49, 25, 3.4), (48, 30, 1.8), (49, 34, 0.6)],
    [(57, 17, 4.0), (55, 23, 3.4), (55, 29, 2.0), (56, 37, 0.6)],
    [(61, 15, 4.5), (60, 22, 3.8), (60, 28, 2.2), (61, 33, 0.6)],
    [(67, 15, 4.5), (67, 22, 3.8), (68, 28, 2.2), (69, 36, 0.6)],
    [(71, 17, 4.0), (73, 23, 3.4), (74, 29, 2.0), (75, 33, 0.6)],
    [(76, 20, 3.8), (78, 25, 3.0), (79, 31, 1.6), (80, 37, 0.6)],
    [(81, 24, 3.0), (83, 28, 2.4), (84, 33, 1.4), (84, 36, 0.6)],
]
# 옆으로 흘러내리는 머리 — 왼쪽 셋, 오른쪽 셋. 길이와 휨이 저마다 다르다
SIDE_LOCKS = [
    [(43, 30, 4.0), (41, 42, 4.5), (40, 54, 4.0), (41, 64, 2.5), (42, 72, 1.0)],
    [(42, 34, 3.0), (39, 46, 3.5), (38, 58, 3.0), (39, 68, 1.5)],
    [(45, 26, 2.5), (44, 36, 2.5), (44, 46, 1.5)],
    [(85, 30, 4.0), (87, 42, 4.5), (88, 55, 4.0), (87, 66, 2.5), (86, 75, 1.0)],
    [(86, 34, 3.0), (89, 46, 3.5), (90, 59, 3.0), (89, 70, 1.5)],
    [(83, 26, 2.5), (84, 36, 2.5), (84, 46, 1.5)],
]
# 삐져나온 잔머리 — 규칙을 깨는 건 이것 몇 가닥이면 된다
FLYAWAY = [
    [(64, 21, 0.6), (61, 16, 0.5), (57, 13, 0.4), (53, 14, 0.3)],
]
# 정수리 윤기(천사링) — 고리를 **끊어서** 얹는다. 이어 놓으면 띠로 보인다
ANGEL = [
    (49, 28, 4, 2), (57, 24, 5, 2), (66, 23, 4, 2), (74, 26, 5, 2), (81, 30, 3, 2),
]


# 턱선 — 타원 그대로면 얼굴이 넓적하다. y 마다 반폭을 손으로 적어 깎는다
JAW = {52: 21.0, 53: 20.8, 54: 20.5, 55: 20.1, 56: 19.6, 57: 19.0, 58: 18.3,
       59: 17.5, 60: 16.6, 61: 15.6, 62: 14.4, 63: 13.0, 64: 11.4, 65: 9.6,
       66: 7.4, 67: 4.6}


def head_front(c, blink=False):
    # ── 살결. 실루엣만 식으로 채우고, 명암은 손으로 얹는다 (빛은 왼쪽 위)
    c.fill_ell(HEAD_CX, HEAD_CY, HEAD_RX, HEAD_RY, 's')
    for y in range(min(JAW), HEAD_CY + HEAD_RY + 1):
        hw = JAW.get(y, -1.0)
        for x in range(HEAD_CX - HEAD_RX - 1, HEAD_CX + HEAD_RX + 2):
            if abs(x - HEAD_CX) > hw and c.at(x, y) == 's':
                c.px(x, y, None)
    c.blob(HEAD_CX - 3, HEAD_CY + 1, 19, 24, 'H1', over={'s'})
    c.blob(HEAD_CX - 8, HEAD_CY - 10, 9, 7, 'H2', over={'H1'})
    c.blob(HEAD_CX + 20, HEAD_CY + 1, 5, 17, 'S1', over={'s', 'H1'})
    c.blob(HEAD_CX + 22, HEAD_CY + 2, 3, 11, 'S2', over={'S1'})
    # 그늘 경계를 한 칸 걸러 어긋내 계단 자국을 지운다
    c.band(HEAD_CX + 14, HEAD_CY + 1, 2, 19, 'S1', {'H1', 's'}, phase=0)
    c.band(HEAD_CX + 19, HEAD_CY + 2, 2, 13, 'S2', {'S1'}, phase=1)
    c.band(HEAD_CX - 8, HEAD_CY - 10, 10, 8, 'H2', {'H1'}, phase=1)

    # ── 눈·눈썹
    ey = HEAD_CY - 2
    lx, rx = HEAD_CX - 3 - EYE_W, HEAD_CX + 3
    if blink:
        c.rows(lx, ey + 5, LID, EYE_KEY)
        c.rows(rx, ey + 5, LID, EYE_KEY)
    else:
        c.rows(lx, ey, EYE, EYE_KEY)
        c.rows(rx, ey, flip(EYE), EYE_KEY)
        # 눈꺼풀이 눈알에 지우는 그늘 — 속눈썹 바로 아래 한 줄
        for x in range(lx + 2, lx + EYE_W - 1):
            if c.at(x, ey + 3) == 'i':
                c.px(x, ey + 3, 'e')
        for x in range(rx + 1, rx + EYE_W - 2):
            if c.at(x, ey + 3) == 'i':
                c.px(x, ey + 3, 'e')

    # ── 코. 콧등 그늘 두 칸 + 콧볼에 빛 한 칸
    c.px(HEAD_CX - 1, HEAD_CY + 13, 'S1')
    c.px(HEAD_CX, HEAD_CY + 14, 'S1')
    c.px(HEAD_CX + 1, HEAD_CY + 14, 'S2')
    c.px(HEAD_CX - 2, HEAD_CY + 14, 'H2')

    # ── 입. 인중 그늘 한 칸을 위에 둔다
    c.px(HEAD_CX, HEAD_CY + 16, 'S1')
    c.rows(HEAD_CX - 4, HEAD_CY + 18, MOUTH, MOUTH_KEY)

    # ── 볼터치. 가장자리를 한 칸 걸러 찍어 뭉치지 않게
    for cx in (lx + 2, rx + EYE_W - 6):
        for dy, row in enumerate(BLUSH):
            for dx, ch in enumerate(row):
                if ch != '.' and c.at(cx + dx, HEAD_CY + 11 + dy) in ('H1', 's', 'S1'):
                    c.px(cx + dx, HEAD_CY + 11 + dy, 'r')

    # ── 머리. 뒤통수를 깔고 → 옆머리 → 앞머리 → 잔머리 순으로 얹는다
    c.fill_ell(HEAD_CX, HEAD_CY - 4, HEAD_RX + 3, HEAD_RY - 2, 'g', only_empty=True)
    for k, pts in enumerate(SIDE_LOCKS):
        c.strand(pts, 'h', edge='j' if k % 3 == 0 else None,
                 tip='g', tipn=(22, 16, 5)[k % 3])
    for i, pts in enumerate(BANGS):
        c.strand(pts, 'h' if i % 2 else 'j',
                 edge='j' if i in (1, 3, 5) else ('g' if i in (0, 6) else None),
                 tip='g', tipn=9 + (i * 5) % 11)
    for pts in FLYAWAY:
        c.strand(pts, 'h', tip='g', tipn=6)
    for bx, by, brx, bry in ANGEL:
        c.blob(bx, by, brx, bry, 'j', over={'h', 'g'})
        c.px(bx, by - 1, 'J')
    for hx, hy, hry in ((41, 46, 7), (44, 34, 4), (87, 46, 7), (84, 34, 4)):
        c.blob(hx, hy, 1, hry, 'j', over={'h', 'g'})
    # 앞머리가 이마에 지우는 그늘 — 가닥 끝 바로 아래 한두 칸
    for pts in BANGS:
        tx, ty, _ = pts[-1]
        if c.at(tx, ty + 1) in ('H1', 'H2', 's'):
            c.px(tx, ty + 1, 'S1')

    # ── 눈썹은 앞머리 **위에** (애니 얼굴은 앞머리 사이로 눈썹이 비친다)
    c.rows(lx + 1, ey - 6, BROW, BROW_KEY)
    c.rows(rx + 1, ey - 6, flip(BROW), BROW_KEY)


def build_front(blink=False):
    c = C()
    head_front(c, blink)
    c.outline()
    return c


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    build_front().save(os.path.join(here, 'hand_head.png'))
    build_front(True).save(os.path.join(here, 'hand_head_blink.png'))
    im = Image.open(os.path.join(here, 'hand_head.png')).convert('RGBA')
    px = im.load()
    bad = {px[x, y][:3] for y in range(im.height) for x in range(im.width)
           if px[x, y][3] and px[x, y][:3] not in set(PAL.values())}
    print('팔레트밖', len(bad))
