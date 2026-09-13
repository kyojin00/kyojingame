#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""걷기 같은 여러 장짜리 동작을 게임 판에 앉힌다.

낱장 손질기(ingest.py)를 그냥 돌리면 안 된다. 그건 장마다 **제 발을 보고**
가운데를 맞추는데, 걷기는 장마다 발 자리가 다르다 — 그러니 장마다 다른
만큼 옮겨져서 몸이 좌우로 덜덜 떨린다.

그래서 **여러 장을 묶어 한 번에** 같은 만큼 옮긴다.
  세로 — 모든 장을 통틀어 제일 낮은 발이 y=47 에 오게
  가로 — 모든 장의 발 중심을 평균 내서 16 에 오게

세로는 **방향마다** 제 바닥을 47 에 맞춘다. 방향을 통틀어 한 값으로 묶었더니
판 크기가 달라(앞은 68칸, 옆은 48칸) 옆모습이 장당 109칸씩 잘려 나갔다.
다 땅을 딛고 있으니 방향마다 제 발바닥을 47 에 두면 그게 같은 지면이다.

장수가 다르게 올 때가 있다. 여자는 4프레임, 남자는 6프레임으로 왔다.
게임은 한 값(WALK_FRAMES)을 쓰니 맞춰야 한다. --pick 으로 고른다.
6프레임은 한 걸음 세 장씩 두 걸음이라 --pick 0,1,3,4 로 걸음마다 두 장씩
뽑으면 번갈아 딛는 게 유지된다.

쓰기: python3 install_anim.py <boy|girl> down=앞 side=옆 up=뒤 [--pick 0,1,3,4] [--write]
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


def body_foot(s):
    ys = [c[1] for c in s]
    t, b = min(ys), max(ys)
    tall = b - t + 1
    bx = [c[0] for c in s if t + tall * 0.15 <= c[1] <= t + tall * 0.7]
    fx = [c[0] for c in s if c[1] >= b - 1]
    return (min(bx) + max(bx)) / 2.0, (min(fx) + max(fx)) / 2.0


def main(kind, jobs, write=False, pick=None):
    for d, t in jobs:
        sets = [cells_of(f) for f in frames_of(t)]
        if pick:
            sets = [sets[i] for i in pick if i < len(sets)]
        # 그 방향 안에서는 **모든 장을 묶어** 한 값. 장마다 맞추면 몸이 떤다
        dy = 47 - max(max(c[1] for c in s) for s in sets)
        one(kind, d, sets, dy, os.path.basename(t), write)


def one(kind, dirname, sets, dy, label, write):
    bodies, foots = zip(*[body_foot(s) for s in sets])
    dx = math.floor(16 - sum(bodies) / len(bodies) + 0.5)

    print('\n%s → %s  (%d장)  가로 %+d  세로 %+d' % (label, dirname, len(sets), dx, dy))
    print('  몸통 중심(옮긴 뒤): %s' % ' '.join('%.1f' % (b + dx) for b in bodies))
    print('  발  중심(옮긴 뒤): %s' % ' '.join('%.1f' % (f + dx) for f in foots))
    jit = max(bodies) - min(bodies)
    print('  몸통 흔들림 %.1f칸 %s' % (jit, 'OK' if jit <= 1.0 else '** 몸이 떤다'))

    # **방향이 뒤집혔는지** 본다. 생성기가 뒤통수 걷기에서 넉 장 중 셋을
    # 앞모습으로 그려 보낸 적이 있다. 낱장 검사로는 안 잡힌다 — 알파도
    # 발바닥도 멀쩡하니까. 머리통에 얼굴 살결이 얼마나 보이는지로 잡는다.
    face = []
    for s in sets:
        ys = [c[1] for c in s]
        t, tall = min(ys), max(ys) - min(ys) + 1
        face.append(sum(1 for x, y, c in s
                        if y <= t + tall * 0.42 and c[0] > 190 and c[0] - c[2] > 25))
    print('  장별 얼굴살: %s' % ' '.join(str(f) for f in face))
    lo, hi = min(face), max(face)
    # 차이가 아니라 **비율**로 본다. 남자 옆모습은 79~96 으로 다 높은데
    # (머리가 얼굴을 안 가리니 당연) 차이만 보면 걸린다. 진짜 뒤집힌 세트는
    # 여자 뒤통수처럼 6 대 62 로 자릿수가 다르다.
    if hi and lo < hi * 0.35:
        print('  ** 장마다 얼굴이 딴판이다 — 방향이 뒤집힌 장이 섞였다')
    elif dirname == 'up' and hi > 12:
        print('  ** 뒤통수여야 하는데 얼굴이 보인다')

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


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    kind = args[0]
    jobs = [tuple(a.split('=', 1)) for a in args[1:] if '=' in a]
    if not jobs:
        print(__doc__)
        sys.exit(1)
    pick = None
    if '--pick' in sys.argv:
        pick = [int(v) for v in sys.argv[sys.argv.index('--pick') + 1].split(',')]
    main(kind, jobs, '--write' in sys.argv, pick)
    if '--write' not in sys.argv:
        print('\n재보기만 했다. 넣으려면 --write')
