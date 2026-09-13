#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""뒤통수 걷기를 앞걷기 다리에서 만든다.

생성기가 뒤통수 걷기를 자꾸 앞모습으로 그려 보낸다(넉 장 중 셋). 기댈
얼굴이 없어서 앞으로 도망가는 것이다. 그래서 여기서 만든다.

만들 수 있는 까닭은 둘이다.
  * 치마 아래로 보이는 건 양말과 신발뿐이라 **앞뒤가 거의 같게 보인다.**
  * 뒷모습 서 있는 그림의 다리 자리(x11-15 / x17-21)가 앞걷기 다리 자리와
    그대로 맞는다.

그래서 **뒷모습 상체 + 앞걷기 다리**를 이어 붙인다. 다만 뒤에서 보면
좌우가 바뀌므로 다리는 좌우로 뒤집는다 — 마주 볼 때 상대의 오른손은
내 왼쪽에 있지만, 뒤에서 보면 내 오른쪽에 있다.

쓰기: python3 make_back_walk.py <boy|girl> <다리가 갈리는 줄> [--write]
"""

import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 48


def grid(name):
    px = Image.open(os.path.join(HERE, name)).convert('RGBA').load()
    return [[px[x, y][:3] if px[x, y][3] else None for x in range(W)] for y in range(H)]


def save(g, name):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            if g[y][x]:
                px[x, y] = g[y][x] + (255,)
    im.save(os.path.join(HERE, name))


def span(g, y0, y1):
    xs = [x for y in range(y0, y1) for x in range(W) if g[y][x]]
    return (min(xs), max(xs)) if xs else None


def main(kind, split, write=False):
    back = grid('%s_up.png' % kind)
    # 뒤집은 다리를 뒷모습 다리 자리에 맞춘다. 그냥 x->32-x 로 뒤집으면
    # 앞뒤 다리 중심이 다를 때 한두 칸 어긋나 다리가 몸에서 비켜난다.
    bs = span(back, split, H)
    for i in range(4):
        legs = grid('%s_down_walk_%d.png' % (kind, i))
        ls = span(legs, split, H)
        shift = 0
        if bs and ls:
            shift = int(round((bs[0] + bs[1]) / 2.0 - (32 - (ls[0] + ls[1]) / 2.0)))
        out = [[back[y][x] for x in range(W)] for y in range(H)]
        for y in range(split, H):
            for x in range(W):
                out[y][x] = None
            for x in range(W):
                c = legs[y][x]
                if c:
                    nx = 32 - x + shift          # 뒤에서 보면 좌우가 바뀐다
                    if 0 <= nx < W:
                        out[y][nx] = c
        on = [(x, y) for y in range(H) for x in range(W) if out[y][x]]
        bot = max(y for _, y in on)
        ft = [x for x, y in on if y == bot]
        gap = [y for y in range(split - 1, split + 1)
               if not any(out[y][x] for x in range(W))]
        print(' %d번  바닥 y=%d  발 %.1f  색 %d%s'
              % (i, bot, (min(ft) + max(ft)) / 2,
                 len({out[y][x] for x, y in on}),
                 '  ** %d줄이 비었다' % gap[0] if gap else ''))
        if write:
            save(out, '%s_up_walk_%d.png' % (kind, i))
    if not write:
        print('재보기만 했다. 넣으려면 --write')


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], int(sys.argv[2]), '--write' in sys.argv)
