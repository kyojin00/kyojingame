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
    'r': (235, 128, 114), 'm': (170, 84, 66),
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

    def rows(self, x0, y0, art, keymap=None):
        """글자 격자를 그대로 찍는다 — 얼굴 부속처럼 칸마다 뜻이 있는 것."""
        km = keymap or {}
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch == '.':
                    continue
                self.px(x0 + dx, y0 + dy, km.get(ch, ch))

    def strand(self, pts, c, edge=None, tip=None):
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
            if tip and idx > total - 14:
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
# 칸 하나하나가 표정이라 글자로 적는다. 눈은 11 x 13 — 세로로 길고, 위 속눈썹이
# 두껍고 바깥으로 처진다. 홍채는 위가 짙고 아래로 갈수록 밝다.
EYE = [
    '...eeeee...',
    '..eeeeeee..',
    '.eeeeeeeee.',
    'eeeeeeeeee.',
    'eeiiiiiiiWe',
    'eWwwiiiiiiW',
    'eWwwiiii11W',
    'eWiiii1122W',
    'eWii111222W',
    'eW1112w222W',
    '.e112222221',
    '..e2222222W',
    '..EeeeeeeE.',
]
EYE_KEY = {'e': 'e', 'E': 'e1', 'W': 'W', 'i': 'i', '1': 'i1', '2': 'i2', 'w': 'w'}
EYE_W, EYE_H = 11, 13

BROW = [
    '..bbbbbb..',
    'bbb.....bb',
]
BROW_KEY = {'b': 'br'}

LID = [
    'ee.......ee',
    '.eeeeeeeee.',
    '..eeeeeee..',
]


def flip(art):
    return [r[::-1] for r in art]


# ------------------------------------------------------------------- 머리
#
# 앞머리는 **가닥 열넷**을 손으로 찍었다. 하나씩 시작점·끝점·굵기가 다르다.
# (식으로 톱니를 만들면 톱날처럼 규칙적이라 가발로 보인다)
HEAD_CX, HEAD_CY = 64, 42
HEAD_RX, HEAD_RY = 23, 27          # 머리 46 x 54

BANGS = [
    # (시작x, 시작y, 굵기), … , (끝x, 끝y, 굵기).
    # 끝은 **눈썹 위(y 34~40)** 에서 멎어야 눈이 보인다. 끝 y 를 하나하나
    # 다르게 적어야 톱니가 아니라 가닥으로 읽힌다.
    [(46, 20, 3.5), (44, 28, 3.0), (43, 35, 1.6), (44, 40, 0.6)],
    [(51, 17, 4.0), (49, 25, 3.4), (48, 32, 1.8), (49, 36, 0.6)],
    [(56, 16, 4.0), (55, 24, 3.4), (55, 31, 2.0), (56, 39, 0.6)],
    [(61, 15, 4.5), (60, 23, 3.8), (60, 30, 2.2), (61, 35, 0.6)],
    [(66, 15, 4.5), (67, 23, 3.8), (68, 30, 2.2), (69, 38, 0.6)],
    [(71, 16, 4.0), (73, 24, 3.4), (74, 31, 2.0), (75, 35, 0.6)],
    [(76, 18, 3.5), (78, 26, 3.0), (79, 33, 1.6), (80, 39, 0.6)],
    [(81, 21, 3.0), (83, 29, 2.4), (84, 35, 1.4), (84, 38, 0.6)],
]
# 옆으로 흘러내리는 머리 — 왼쪽 셋, 오른쪽 셋. 길이와 휨이 저마다 다르다
SIDE_LOCKS = [
    [(43, 30, 4.0), (41, 42, 4.5), (40, 54, 4.0), (41, 64, 2.5), (42, 72, 1.0)],
    [(42, 34, 3.0), (39, 46, 3.5), (38, 58, 3.0), (39, 68, 1.5)],
    [(45, 26, 2.5), (44, 36, 2.5), (44, 46, 1.5)],
    [(85, 30, 4.0), (87, 42, 4.5), (88, 54, 4.0), (87, 64, 2.5), (86, 72, 1.0)],
    [(86, 34, 3.0), (89, 46, 3.5), (90, 58, 3.0), (89, 68, 1.5)],
    [(83, 26, 2.5), (84, 36, 2.5), (84, 46, 1.5)],
]


def head_front(c, blink=False):
    # 살결 — 실루엣만 식으로 채운다
    c.fill_ell(HEAD_CX, HEAD_CY, HEAD_RX, HEAD_RY, 's')
    # 그늘·밝은 면을 손으로 놓는다 (빛은 왼쪽 위)
    c.blob(HEAD_CX - 3, HEAD_CY + 1, 19, 24, 'H1', over={'s'})         # 얼굴은 거의 밝다
    c.blob(HEAD_CX - 8, HEAD_CY - 10, 9, 7, 'H2', over={'H1'})         # 이마에 빛
    c.blob(HEAD_CX + 20, HEAD_CY + 1, 5, 17, 'S1', over={'s', 'H1'})   # 오른쪽 가장자리만
    c.blob(HEAD_CX + 22, HEAD_CY + 2, 3, 11, 'S2', over={'S1'})
    # 얼굴 부속
    ey = HEAD_CY - 3
    lx, rx = HEAD_CX - 3 - EYE_W, HEAD_CX + 3
    if blink:
        c.rows(lx, ey + 5, LID)
        c.rows(rx, ey + 5, LID)
    else:
        c.rows(lx, ey, EYE, EYE_KEY)
        c.rows(rx, ey, flip(EYE), EYE_KEY)
    c.px(HEAD_CX - 1, HEAD_CY + 13, 'S1')                              # 코
    c.px(HEAD_CX, HEAD_CY + 14, 'S1')
    c.rows(HEAD_CX - 4, HEAD_CY + 17, ['m.....m', '.mmmmm.', '..HHH..'],  # 입
           {'H': 'H2'})
    for y in (HEAD_CY + 11, HEAD_CY + 12):                             # 볼터치 — 눈 밑
        for x in range(lx + 1, lx + 5):
            c.px(x, y, 'r')
        for x in range(rx + EYE_W - 5, rx + EYE_W - 1):
            c.px(x, y, 'r')
    # 머리 — 뒤통수를 먼저 깔고 가닥을 얹는다
    c.fill_ell(HEAD_CX, HEAD_CY - 6, HEAD_RX + 2, HEAD_RY - 6, 'h', only_empty=True)
    for pts in SIDE_LOCKS:
        c.strand(pts, 'h', edge='j', tip='g')
    for i, pts in enumerate(BANGS):
        c.strand(pts, 'h' if i % 2 else 'j', edge='j' if i in (1, 3, 5) else None,
                 tip='g')
    # 정수리 윤기 — 가닥 위에 손으로 얹은 얼룩 세 개
    c.blob(HEAD_CX - 10, HEAD_CY - 19, 6, 2, 'j', over={'h'})
    c.blob(HEAD_CX + 1, HEAD_CY - 21, 4, 2, 'j', over={'h'})
    c.blob(HEAD_CX - 15, HEAD_CY - 12, 3, 2, 'j', over={'h'})
    # 눈썹은 앞머리 위에 (애니 얼굴은 앞머리 사이로 눈썹이 비친다)
    c.rows(lx + 1, ey - 5, BROW, BROW_KEY)
    c.rows(rx, ey - 5, flip(BROW), BROW_KEY)


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
