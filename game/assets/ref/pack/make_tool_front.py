#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""앞에서 본 도구 그림(icon_<도구>_front.png, 32x32)을 코드로 찍는다.

앞·뒤를 보고 휘두를 때 쥐는 그림이다 (player.gd tool_tex_name). 옆에서 본 아이콘
한 장으로 앞을 향해 휘두르면 도구가 옆으로 넘어가 보여서 방향마다 그림을 달리 쥔다.

생성기(PixelLab)로도 뽑아 봤지만 32칸에서는 자루가 기울고 머리가 뭉개져서 축이 안 맞았다.
앞모습은 모양이 단순하다(세로 자루 + 위에 머리) — 코드로 찍는 편이 곧고 한결같다.
색은 옆모습 아이콘의 톤에 맞춘 다섯 단 팔레트(나무·쇠·돌·양철·끈)다 — 옆·앞이 같은 도구로
보이게. 빛은 왼쪽 위에서 온다: 왼쪽 면이 밝고 오른쪽 면이 어둡다.

규약: 자루는 x 14~17 세로, 자루 끝이 y 30 (쥐는 자리 (16, 30) = TOOL_GRIP 기본값),
머리는 위. 윤곽은 한 칸 검정.

쓰기: python3 make_tool_front.py [--write]   (없으면 preview_tool_front.png 만 만든다)
"""
import colorsys
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.abspath(os.path.join(HERE, '..', '..', 'sprites'))
W = H = 32
OUTLINE = (28, 18, 12)


def palette(name, pick, n=3):
    """아이콘에서 조건에 맞는 색을 밝기순으로 n 단 뽑는다 (어두운 것부터)."""
    im = Image.open(os.path.join(SPR, name + '.png')).convert('RGBA')
    px = im.load()
    cols = {}
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a > 128 and pick((r, g, b)):
                cols[(r, g, b)] = cols.get((r, g, b), 0) + 1
    cols = [c for c, k in cols.items() if k >= 3]
    cols.sort(key=lambda c: sum(c))
    if len(cols) < n:
        cols = (cols + [cols[-1]] * n)[:n] if cols else [(120, 90, 60)] * n
    step = (len(cols) - 1) / float(n - 1)
    return [cols[int(round(i * step))] for i in range(n)]


def hsv(c):
    return colorsys.rgb_to_hsv(*[x / 255.0 for x in c])


def is_wood(c):
    h, s, v = hsv(c)
    return 0.04 <= h <= 0.12 and s > 0.35 and v > 0.25


def is_metal(c):
    h, s, v = hsv(c)
    return s < 0.2 and v > 0.45


def is_stone(c):
    h, s, v = hsv(c)
    return s < 0.25 and 0.3 < v < 0.8


# 아이콘에서 뽑으려 했더니(palette) 색이 한두 개로 몰려 단이 안 나뉜다 — 옆모습 아이콘의
# 톤에 맞춰 다섯 단을 손으로 적는다 (가장 어두움 → 가장 밝음)
WOOD = [(74, 46, 26), (110, 70, 40), (150, 102, 58), (184, 136, 84), (214, 176, 122)]
IRON = [(84, 86, 98), (122, 124, 136), (168, 170, 182), (206, 208, 218), (238, 240, 246)]
STONE = [(70, 64, 62), (104, 96, 94), (140, 132, 128), (176, 168, 162), (206, 198, 190)]
CORD = [(120, 84, 40), (168, 124, 62)]                 # 끈 (어두움 · 밝음)
TIN = [(96, 92, 88), (138, 134, 128), (176, 172, 166), (208, 204, 198), (236, 232, 226)]  # 양철


class Canvas:
    def __init__(self):
        self.im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        self.px = self.im.load()

    def put(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = tuple(c) + (255,)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def trapezoid(self, top_x0, top_x1, bot_x0, bot_x1, y0, y1, c):
        """위 너비에서 아래 너비로 줄마다 선형으로 좁아지는 면."""
        n = max(1, y1 - y0)
        for y in range(y0, y1 + 1):
            t = (y - y0) / float(n)
            a = int(round(top_x0 + (bot_x0 - top_x0) * t))
            b = int(round(top_x1 + (bot_x1 - top_x1) * t))
            self.hline(a, b, y, c)

    def shade_lr(self, x0, x1, y0, y1, pal, steps=(4, 3, 2, 1)):
        """가로로 왼쪽 밝고 오른쪽 어둡게 — 세로 물건(자루·날) 입체감."""
        w = x1 - x0 + 1
        for i, x in enumerate(range(x0, x1 + 1)):
            k = steps[min(len(steps) - 1, int(i * len(steps) / float(w)))]
            self.vline(x, y0, y1, pal[k])

    def outline(self):
        """불투명 칸에 닿은 투명 칸을 검정으로 — 한 칸 윤곽 (대각선은 안 두른다: 둥글게)."""
        on = {(x, y) for y in range(H) for x in range(W) if self.px[x, y][3]}
        for x, y in list(on):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in on and 0 <= q[0] < W and 0 <= q[1] < H and not self.px[q][3]:
                    self.put(q[0], q[1], OUTLINE)


def handle(c, y0, y1=30, x0=14, x1=17):
    """세로 자루: 왼쪽 밝고 오른쪽 어둡다 (빛은 왼쪽 위). 나뭇결·끝동을 넣는다."""
    c.shade_lr(x0, x1, y0, y1, WOOD, (4, 3, 2, 1))
    for y in range(y0 + 4, y1 - 1, 6):                 # 나뭇결
        c.put(x0 + 1, y, WOOD[1])
        c.put(x0 + 2, y + 1, WOOD[1])
    c.hline(x0, x1, y1, WOOD[0])                        # 자루 끝동 (쥐는 자리)
    c.hline(x0, x1, y1 - 1, WOOD[1])


def wrap(c, x0, x1, y, rows=2):
    """자루를 감은 끈 — 줄무늬로."""
    for i in range(rows):
        c.hline(x0, x1, y + i, CORD[0] if i % 2 == 0 else CORD[1])
        c.put(x0, y + i, CORD[0])


def head_axe(c, pal, chipped=False):
    """앞에서 본 도끼 머리 — 위가 넓은 사다리꼴, 위 모서리는 둥글고, 자루를 감싼 눈이 있다."""
    c.trapezoid(8, 23, 12, 19, 3, 11, pal[2])
    c.hline(9, 22, 3, pal[3])                           # 위 모서리 밝게
    c.hline(10, 21, 2, pal[3])                          # 둥근 윗선
    c.hline(11, 20, 4, pal[4])                          # 빛줄
    c.trapezoid(20, 23, 18, 19, 3, 11, pal[1])          # 오른쪽 그늘
    c.trapezoid(8, 9, 12, 12, 4, 11, pal[3])            # 왼쪽 빛
    for y in range(6, 11):                              # 아래로 갈수록 어둡다
        c.put(15 + (y % 2), y, pal[1])
    if chipped:                                         # 돌 — 깨진 면
        for x, y in ((10, 5), (13, 7), (18, 5), (20, 8), (12, 9)):
            c.put(x, y, pal[0])
            c.put(x + 1, y, pal[4])
    c.rect(13, 10, 18, 12, pal[1])                      # 눈(socket) — 자루가 박히는 자리
    c.hline(13, 18, 10, pal[0])
    c.rect(14, 11, 17, 12, WOOD[2])                     # 눈 사이로 보이는 자루 끝
    c.hline(14, 17, 11, WOOD[3])


def draw_axe():
    c = Canvas()
    handle(c, 12)
    head_axe(c, IRON)
    wrap(c, 14, 17, 14, 2)                              # 머리 아래 끈
    c.outline()
    return c.im


def draw_axe_stone():
    c = Canvas()
    handle(c, 12)
    head_axe(c, STONE, chipped=True)
    wrap(c, 13, 18, 13, 3)                              # 돌을 묶은 끈은 굵다
    c.outline()
    return c.im


def draw_pickaxe():
    c = Canvas()
    handle(c, 10)
    # T자 머리 — 가운데 두껍고 양끝으로 가늘어져 뾰족하다
    c.hline(7, 24, 6, IRON[2])
    c.hline(5, 26, 7, IRON[2])
    c.hline(4, 27, 8, IRON[1])
    c.hline(6, 25, 9, IRON[1])
    c.hline(8, 23, 5, IRON[3])                          # 윗면 빛
    c.hline(10, 21, 4, IRON[3])
    c.put(3, 8, IRON[2]); c.put(28, 8, IRON[1])         # 끝점
    c.put(4, 9, IRON[0]); c.put(27, 9, IRON[0])
    c.rect(12, 3, 19, 11, IRON[2])                      # 가운데 머리통
    c.hline(12, 19, 3, IRON[3])
    c.hline(13, 18, 2, IRON[3])
    c.vline(12, 4, 11, IRON[3])                         # 왼쪽 빛
    c.rect(18, 4, 19, 11, IRON[1])                      # 오른쪽 그늘
    c.hline(12, 19, 11, IRON[0])                        # 아래 그늘
    c.put(14, 5, IRON[4]); c.put(15, 5, IRON[4])        # 반짝
    wrap(c, 14, 17, 12, 2)
    c.outline()
    return c.im


def draw_hoe():
    c = Canvas()
    handle(c, 10)
    # 넓적한 날 — 아래로 살짝 오므라들고, 아랫날이 밝다(갈아 둔 쇠)
    c.trapezoid(8, 23, 9, 22, 3, 8, IRON[2])
    c.hline(8, 23, 3, IRON[1])                          # 위 모서리 그늘 (뒤로 꺾인 면)
    c.hline(9, 22, 8, IRON[4])                          # 아랫날
    c.hline(9, 22, 7, IRON[3])
    c.vline(21, 4, 7, IRON[1]); c.vline(22, 4, 7, IRON[1])
    c.vline(8, 4, 7, IRON[3])
    c.rect(13, 3, 18, 5, IRON[1])                       # 목 — 자루가 들어가는 통
    c.hline(13, 18, 3, IRON[0])
    c.rect(14, 6, 17, 9, IRON[1])
    c.vline(14, 6, 9, IRON[2])
    wrap(c, 14, 17, 10, 2)
    c.outline()
    return c.im


def draw_water():
    """물뿌리개 — 옆모습 아이콘이 나무통이라 앞도 나무판을 세로로 잇고 쇠테를 두른다."""
    c = Canvas()
    # 나무판 여섯 장 — 왼쪽이 밝고 오른쪽이 어둡다, 판 사이는 어두운 줄
    staves = [(10, 11, 4), (12, 13, 3), (14, 15, 3), (16, 17, 2), (18, 19, 2), (20, 22, 1)]
    for x0, x1, k in staves:
        c.rect(x0, 11, x1, 28, WOOD[k])
        c.vline(x1, 11, 28, WOOD[max(0, k - 1)])
    c.hline(10, 22, 11, WOOD[4])                        # 윗테두리 빛
    c.hline(10, 22, 28, WOOD[0])                        # 바닥
    for y in (13, 26):                                  # 쇠테 두 줄
        c.hline(10, 22, y, IRON[1])
        c.hline(10, 22, y + 1, IRON[2])
        c.put(10, y + 1, IRON[3]); c.put(22, y + 1, IRON[0])
    # 위 손잡이 — 나무 아치
    c.hline(13, 19, 4, WOOD[3])
    c.hline(12, 20, 5, WOOD[2])
    c.vline(12, 6, 10, WOOD[3]); c.vline(20, 6, 10, WOOD[1])
    c.hline(13, 19, 4, WOOD[4])
    # 주둥이 — 이쪽으로 튀어나온 쇠 물뿌리개 머리(rose): 둥근 판에 구멍이 촘촘
    c.rect(13, 17, 19, 23, IRON[2])
    c.hline(14, 18, 16, IRON[3]); c.hline(14, 18, 24, IRON[1])
    c.vline(12, 18, 22, IRON[3]); c.vline(20, 18, 22, IRON[1])
    c.hline(14, 18, 17, IRON[4])
    for y in (19, 21):
        for x in (14, 16, 18):
            c.put(x, y, IRON[0])
    c.put(15, 20, IRON[0]); c.put(17, 20, IRON[0])
    c.outline()
    return c.im


def draw_sword():
    c = Canvas()
    # 손잡이 — 가죽 감은 자루, 아래 둥근 칼자루머리
    c.shade_lr(14, 17, 23, 28, WOOD, (3, 2, 2, 1))
    for y in (24, 26, 28):
        c.hline(14, 17, y, CORD[0])
    c.rect(13, 29, 18, 30, IRON[1])                     # 칼자루머리
    c.hline(14, 17, 30, IRON[0])
    c.put(14, 29, IRON[3])
    # 날밑 — 살짝 위로 휜 쇠막대
    c.rect(9, 21, 22, 22, IRON[1])
    c.hline(10, 21, 21, IRON[2])
    c.put(9, 20, IRON[2]); c.put(22, 20, IRON[2])
    c.hline(11, 20, 20, IRON[3])
    # 날 — 가운데 홈(fuller)이 어둡고 양날이 밝다
    c.rect(14, 3, 17, 19, IRON[2])
    c.vline(14, 3, 19, IRON[4])
    c.vline(17, 3, 19, IRON[1])
    c.vline(15, 6, 18, IRON[1])                         # 홈
    c.vline(16, 6, 18, IRON[3])
    c.rect(15, 1, 16, 2, IRON[3])                       # 끝
    c.put(15, 0, IRON[4])
    c.put(14, 2, IRON[4]); c.put(17, 2, IRON[2])
    c.outline()
    return c.im


def draw_spear():
    c = Canvas()
    c.shade_lr(15, 16, 10, 30, WOOD, (3, 1))
    for y in range(14, 30, 6):
        c.put(15, y, WOOD[1])
    c.hline(15, 16, 30, WOOD[0])
    # 부싯돌 촉 — 위로 좁아지는 삼각, 깨진 면이 보인다
    c.trapezoid(15, 16, 12, 19, 1, 8, STONE[2])
    c.trapezoid(15, 15, 12, 13, 2, 8, STONE[3])         # 왼쪽 빛
    c.trapezoid(16, 16, 18, 19, 2, 8, STONE[1])         # 오른쪽 그늘
    c.put(15, 1, STONE[4])
    for x, y in ((14, 5), (17, 6), (13, 7)):            # 깨진 면
        c.put(x, y, STONE[0])
    c.hline(13, 18, 8, STONE[1])
    wrap(c, 14, 17, 9, 3)                               # 촉을 묶은 끈
    c.outline()
    return c.im


TOOLS = {
    'icon_axe_front': draw_axe, 'icon_axe_stone_front': draw_axe_stone,
    'icon_pickaxe_front': draw_pickaxe, 'icon_hoe_front': draw_hoe,
    'icon_water_front': draw_water, 'icon_sword_front': draw_sword,
    'icon_spear_front': draw_spear,
}


def main():
    write = '--write' in sys.argv
    print('나무 %s · 쇠 %s · 돌 %s' % (WOOD, IRON, STONE))
    S = 6
    sheet = Image.new('RGBA', (len(TOOLS) * (W * S + 8), H * S * 2 + 8), (40, 40, 48, 255))
    for i, (name, fn) in enumerate(TOOLS.items()):
        im = fn()
        big = im.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (i * (W * S + 8), 0), big)
        side = name.replace('_front', '')
        if os.path.exists(os.path.join(SPR, side + '.png')):
            sb = Image.open(os.path.join(SPR, side + '.png')).convert('RGBA').resize((W * S, H * S), Image.NEAREST)
            sheet.paste(sb, (i * (W * S + 8), H * S + 8), sb)
        if write:
            im.save(os.path.join(SPR, name + '.png'))
        print('  %-24s %s' % (name, '썼다' if write else '미리보기'))
    sheet.save(os.path.join(HERE, 'preview_tool_front.png'))
    print('미리보기: preview_tool_front.png (위 앞모습 · 아래 옆모습)')


main()
