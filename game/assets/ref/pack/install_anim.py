#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""걷기 같은 여러 장짜리 동작을 게임 판에 앉힌다.

낱장 손질기(ingest.py)를 그냥 돌리면 안 된다. 그건 장마다 **제 발을 보고**
가운데를 맞추는데, 걷기는 장마다 발 자리가 다르다 — 그러니 장마다 다른
만큼 옮겨져서 몸이 좌우로 덜덜 떨린다.

그래서 **여러 장을 묶어 한 번에** 같은 만큼 옮긴다.
  세로 — 모든 장을 통틀어 제일 낮은 발이 y=47 에 오게
  가로 — 모든 장의 발 중심을 평균 내서 16 에 오게

쓰기: python3 install_anim.py <gif 또는 폴더> <boy|girl> <down|side|up> [--write]
"""

import os
import sys
import glob
import math
from PIL import Image, ImageSequence

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 48


def frames_of(target):
    if os.path.isdir(target):
        fs = sorted(glob.glob(os.path.join(target, '*.png')))
        return [Image.open(f).convert('RGBA') for f in fs]
    im = Image.open(target)
    return [f.convert('RGBA') for f in ImageSequence.Iterator(im)]


def cells_of(im):
    px = im.load()
    w, h = im.size
    return [(x, y, px[x, y][:3]) for y in range(h) for x in range(w) if px[x, y][3] > 128]


def main(target, kind, dirname, write=False):
    fr = frames_of(target)
    if not fr:
        print('그림이 없다')
        return
    sets = [cells_of(f) for f in fr]

    # 한 번에 정할 값 두 개
    bottom = max(max(c[1] for c in s) for s in sets)          # 제일 낮은 발
    dy = 47 - bottom
    bodies, foots = [], []
    for s in sets:
        ys = [c[1] for c in s]
        t, b = min(ys), max(ys)
        tall = b - t + 1
        bx = [c[0] for c in s if t + tall * 0.15 <= c[1] <= t + tall * 0.7]
        bodies.append((min(bx) + max(bx)) / 2.0)
        fx = [c[0] for c in s if c[1] >= b - 1]
        foots.append((min(fx) + max(fx)) / 2.0)
    dx = math.floor(16 - sum(bodies) / len(bodies) + 0.5)

    print('%s — %d장' % (os.path.basename(target), len(fr)))
    print('  묶어서 옮김  가로 %+d  세로 %+d' % (dx, dy))
    print('  몸통 중심(옮긴 뒤): %s' % ' '.join('%.1f' % (b + dx) for b in bodies))
    print('  발  중심(옮긴 뒤): %s' % ' '.join('%.1f' % (f + dx) for f in foots))
    jit = max(bodies) - min(bodies)
    print('  몸통 흔들림 %.1f칸 %s' % (jit, 'OK' if jit <= 1.0 else '** 몸이 떤다'))

    for i, s in enumerate(sets):
        g = [[None] * W for _ in range(H)]
        lost = 0
        for x, y, c in s:
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H:
                g[ny][nx] = c
            else:
                lost += 1
        on = [(x, y) for y in range(H) for x in range(W) if g[y][x]]
        bot = max(y for _, y in on)
        ft = [x for x, y in on if y == bot]
        print('   %d번  색%3d  바닥 y=%d  발 %.1f%s'
              % (i, len({g[y][x] for x, y in on}), bot,
                 (min(ft) + max(ft)) / 2, '  ** 잘림 %d칸' % lost if lost else ''))
        if write:
            im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            px = im.load()
            for x, y in on:
                px[x, y] = g[y][x] + (255,)
            im.save(os.path.join(HERE, '%s_%s_walk_%d.png' % (kind, dirname, i)))
    if not write:
        print('\n재보기만 했다. 넣으려면 --write')


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3], '--write' in sys.argv)
