#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PixelLab 로 뽑은 도구 그림(옆·앞)을 게임 자리에 앉히고 쥐는 자리를 잰다.

도구 그림은 두 벌이다.
  icon_<도구>.png        옆에서 본 것 — 가방·핫바 아이콘이자 옆을 보고 휘두를 때 쥐는 그림.
                         자루 끝이 왼쪽 아래, 날이 오른쪽 위.
  icon_<도구>_front.png  앞에서 본 것 — 앞·뒤를 보고 휘두를 때 쥐는 그림 (player.gd tool_tex_name).
                         자루가 세로로 한가운데, 자루 끝이 맨 아래, 날이 위.

게임은 도구를 **쥐는 자리**(자루 끝 픽셀)를 축으로 돌린다 (player.gd TOOL_GRIP). 그림마다
자루 끝이 어디 있는지 여기서 재서 찍어 준다 — 옆 그림은 왼쪽 아래로 가장 치우친 불투명
칸, 앞 그림은 맨 아랫줄 불투명 칸들의 한가운데. 찍힌 줄을 TOOL_GRIP 에 그대로 옮긴다.

쓰기: python3 install_tools.py <뽑은 폴더> axe=21,22 pickaxe=23,21 ... [--write]
      (도구=옆씨앗,앞씨앗 — 폴더 안 <도구>_side_s<씨앗>.png · <도구>_front_s<씨앗>.png)
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.abspath(os.path.join(HERE, '..', '..', 'sprites'))


def cells(im):
    px = im.load()
    return [(x, y) for y in range(im.size[1]) for x in range(im.size[0]) if px[x, y][3] > 128]


def grip_side(on):
    # 왼쪽 아래로 가장 치우친 칸 (y 크고 x 작은 쪽)
    return max(on, key=lambda p: p[1] - p[0])


def grip_front(on):
    b = max(y for _, y in on)
    xs = [x for x, y in on if y >= b - 1]
    return (int(round((min(xs) + max(xs)) / 2.0)), b)


def clean(im):
    """반투명을 0/255 로 자른다 — 게임에서 테두리가 번지지 않게."""
    out = im.copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a > 128 else 0)
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    src = args[0]
    write = '--write' in sys.argv
    grips = []
    for a in args[1:]:
        tool, seeds = a.split('=', 1)
        s_side, s_front = seeds.split(',')
        for view, seed in (('side', s_side), ('front', s_front)):
            path = os.path.join(src, '%s_%s_s%s.png' % (tool, view, seed))
            im = clean(Image.open(path).convert('RGBA'))
            on = cells(im)
            g = grip_side(on) if view == 'side' else grip_front(on)
            name = 'icon_%s%s' % (tool, '' if view == 'side' else '_front')
            xs = [x for x, _ in on]
            ys = [y for _, y in on]
            print('  %-22s <- %-24s  %dx%d 채움 x%d~%d y%d~%d  쥐는 자리 %s'
                  % (name + '.png', os.path.basename(path), im.size[0], im.size[1],
                     min(xs), max(xs), min(ys), max(ys), g))
            grips.append((name, g))
            if write:
                im.save(os.path.join(DEST, name + '.png'))
    print('\nTOOL_GRIP 에 옮길 줄:')
    for name, g in grips:
        print('\t"%s": Vector2(%d, %d),' % (name, g[0], g[1]))
    print('썼다' if write else '적어만 봤다 — 정말 하려면 --write')


main()
