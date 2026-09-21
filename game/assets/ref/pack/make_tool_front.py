#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""앞에서 본 도구 그림(icon_<도구>_front.png, 32x32)을 코드로 찍는다.

앞·뒤를 보고 휘두를 때 쥐는 그림이다 (player.gd tool_tex_name). 옆에서 본 아이콘
한 장으로 앞을 향해 휘두르면 도구가 옆으로 넘어가 보여서 방향마다 그림을 달리 쥔다.

생성기(PixelLab)로도 뽑아 봤지만 32칸에서는 자루가 기울고 머리가 뭉개져서 축이 안 맞았다.
앞모습은 모양이 단순하다(세로 자루 + 위에 머리) — 코드로 찍는 편이 곧고 한결같다.
색은 지금 옆모습 아이콘에서 뽑는다(나무는 icon_axe 의 자루, 쇠는 icon_sword 의 날,
돌은 icon_axe_stone 의 머리) — 그래야 옆·앞이 같은 도구로 보인다.

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
# 톤에 맞춰 세 단을 손으로 적는다 (어두움 · 중간 · 밝음)
WOOD = [(96, 62, 36), (150, 102, 58), (196, 146, 92)]
IRON = [(118, 120, 130), (170, 172, 182), (222, 224, 232)]
STONE = [(96, 90, 88), (138, 130, 126), (186, 176, 165)]
TIN = WOOD                                    # 물뿌리개는 옆모습이 나무통이다 — 같은 색


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

    def outline(self):
        """불투명 칸에 닿은 투명 칸을 검정으로 — 한 칸 윤곽."""
        on = {(x, y) for y in range(H) for x in range(W) if self.px[x, y][3]}
        for x, y in list(on):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in on and 0 <= q[0] < W and 0 <= q[1] < H and not self.px[q][3]:
                    self.put(q[0], q[1], OUTLINE)


def handle(c, y0, y1=30, pal=None):
    """세로 자루 x 14~17: 왼쪽 밝고 오른쪽 어둡다 (빛은 왼쪽 위에서)."""
    pal = pal or WOOD
    c.vline(14, y0, y1, pal[2])
    c.vline(15, y0, y1, pal[1])
    c.vline(16, y0, y1, pal[1])
    c.vline(17, y0, y1, pal[0])
    # 나뭇결 — 몇 칸 어둡게
    for y in range(y0 + 3, y1, 5):
        c.put(15, y, pal[0])


def head_axe(c, pal):
    # 앞에서 본 도끼 머리: 위가 넓은 사다리꼴 날 + 자루를 감싼 눈(socket)
    c.trapezoid(8, 23, 11, 20, 4, 10, pal[1])
    c.hline(8, 23, 4, pal[2])                    # 위 날 — 빛 받는 면
    c.hline(9, 22, 5, pal[2])
    c.trapezoid(19, 23, 18, 20, 5, 10, pal[0])   # 오른쪽 그늘
    c.rect(13, 9, 18, 12, pal[0])                # 눈 — 자루가 박히는 자리
    c.rect(14, 10, 17, 11, pal[1])


def draw_axe():
    c = Canvas()
    handle(c, 11)
    head_axe(c, IRON)
    c.outline()
    return c.im


def draw_axe_stone():
    c = Canvas()
    handle(c, 11)
    head_axe(c, STONE)
    # 돌을 묶은 끈 두 줄
    c.hline(12, 19, 12, WOOD[0])
    c.hline(12, 19, 14, WOOD[0])
    c.outline()
    return c.im


def draw_pickaxe():
    c = Canvas()
    handle(c, 9)
    # T자 머리 — 가로 막대, 양끝은 가늘어진다
    c.hline(6, 25, 5, IRON[1])
    c.hline(5, 26, 6, IRON[1])
    c.hline(5, 26, 7, IRON[0])
    c.hline(7, 24, 4, IRON[2])
    c.put(4, 6, IRON[1]); c.put(27, 6, IRON[1])
    c.rect(13, 3, 18, 9, IRON[1])                 # 가운데 머리통
    c.hline(13, 18, 3, IRON[2])
    c.rect(17, 4, 18, 9, IRON[0])
    c.outline()
    return c.im


def draw_hoe():
    c = Canvas()
    handle(c, 9)
    c.rect(9, 3, 22, 7, IRON[1])                   # 넓적한 날
    c.hline(9, 22, 3, IRON[2])
    c.vline(21, 4, 7, IRON[0]); c.vline(22, 4, 7, IRON[0])
    c.rect(14, 8, 17, 9, IRON[0])                  # 목
    c.outline()
    return c.im


def draw_water():
    c = Canvas()
    # 몸통 — 나무통(옆모습과 같은 재질)
    c.rect(10, 11, 22, 28, TIN[1])
    c.vline(10, 11, 28, TIN[2]); c.vline(11, 11, 28, TIN[2])
    c.vline(21, 11, 28, TIN[0]); c.vline(22, 11, 28, TIN[0])
    for y in (15, 20, 25):                         # 테
        c.hline(10, 22, y, TIN[0])
    c.hline(10, 22, 10, TIN[0])                    # 윗테
    # 위 손잡이 — 아치
    c.hline(13, 19, 5, TIN[1])
    c.vline(12, 6, 9, TIN[1]); c.vline(20, 6, 9, TIN[0])
    c.put(13, 6, TIN[2])
    # 주둥이 — 보는 쪽으로 튀어나온 원 (앞에서 보면 구멍만 보인다)
    c.rect(14, 19, 18, 23, TIN[2])
    c.rect(15, 20, 17, 22, OUTLINE)
    c.put(16, 21, TIN[0])
    c.outline()
    return c.im


def draw_sword():
    c = Canvas()
    # 손잡이(나무) 아래, 날 위
    handle(c, 23, 29)
    c.rect(14, 30, 17, 30, IRON[0])                # 칼자루 끝
    c.rect(10, 21, 21, 22, IRON[0])                # 날밑
    c.hline(10, 21, 21, IRON[1])
    c.rect(14, 4, 17, 20, IRON[1])                 # 날
    c.vline(14, 4, 20, IRON[2])
    c.vline(17, 4, 20, IRON[0])
    c.vline(15, 5, 19, IRON[2])                    # 가운데 빛줄
    c.rect(15, 2, 16, 3, IRON[1])                  # 끝
    c.put(15, 1, IRON[2])
    c.outline()
    return c.im


def draw_spear():
    c = Canvas()
    c.vline(15, 9, 30, WOOD[1]); c.vline(16, 9, 30, WOOD[0])
    for y in range(12, 30, 5):
        c.put(15, y, WOOD[0])
    # 부싯돌 촉 — 위로 좁아지는 삼각
    c.trapezoid(15, 16, 13, 18, 2, 8, STONE[1])
    c.vline(15, 2, 8, STONE[2])
    c.put(18, 8, STONE[0]); c.put(17, 7, STONE[0])
    c.hline(14, 17, 9, WOOD[0])                    # 묶은 끈
    c.hline(14, 17, 10, WOOD[0])
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
