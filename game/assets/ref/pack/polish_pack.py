#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""daily_rpg_pair_pack 의 두 장을 마감만 다듬는다.

디자인은 손대지 않는다. 실제로 잡히는 결함만 고친다.
  1) 남자 오른쪽 관자놀이에 한 칸이 허공으로 튀어나와 있다 (24,11)
  2) 남자 정수리 오른쪽 어깨가 한 줄에 세 칸을 뛴다 (y5: 19 -> 22).
     그 자리만 두 칸 채워 한 칸씩 흐르게 한다
  3) 발바닥이 y=46 이라 아래 한 줄이 비어 있다 — 한 줄 내려 캔버스를 꽉 채운다
그리고 게임이 쓰는 128x192 로 정수 4배 확대한 판을 같이 낸다
(발바닥이 y=190 에 오도록 한 픽셀 올린다 — 기존 스프라이트와 같은 규약).
"""

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'pack2')
OUT = os.path.join(HERE, 'packfix')
os.makedirs(OUT, exist_ok=True)

HAIR_TOP = (75, 57, 57)          # 남자 머리 가장 어두운 단 (정수리 윤곽)


def polish_boy(px):
    px[24, 11] = (0, 0, 0, 0)                       # 1) 허공에 뜬 한 칸
    for x in (20, 21):                              # 2) 정수리 오른쪽 어깨
        px[x, 4] = HAIR_TOP + (255,)


def shift_down(im, n=1):
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im, (0, n))
    return out


def report(im, name):
    px = im.load()
    W, H = im.size
    a = {px[x, y][3] for y in range(H) for x in range(W)}
    on = [(x, y) for y in range(H) for x in range(W) if px[x, y][3]]
    xs = [p[0] for p in on]
    ys = [p[1] for p in on]
    seen = set()
    comps = 0
    for p in on:
        if p in seen:
            continue
        comps += 1
        st = [p]
        seen.add(p)
        while st:
            cx, cy = st.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (cx + dx, cy + dy)
                if q not in seen and 0 <= q[0] < W and 0 <= q[1] < H and px[q[0], q[1]][3]:
                    seen.add(q)
                    st.append(q)
    nub = sum(1 for x, y in on
              if sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                     if 0 <= x + dx < W and 0 <= y + dy < H and px[x + dx, y + dy][3]) <= 1)
    print('%-22s 알파%s  발바닥 y=%d  가로 %d..%d  연결 %d개  돌기 %d개'
          % (name, sorted(a), max(ys), min(xs), max(xs), comps, nub))


def main():
    for n in ('boy', 'girl'):
        im = Image.open(os.path.join(SRC, '%s.png' % n)).convert('RGBA')
        if n == 'boy':
            polish_boy(im.load())
        im = shift_down(im, 1)                      # 3) 발바닥을 맨 아랫줄로
        im.save(os.path.join(OUT, '%s.png' % n))
        report(im, '%s.png (32x48)' % n)
        big = im.resize((128, 192), Image.NEAREST)  # 게임용 4배
        g = Image.new('RGBA', (128, 192), (0, 0, 0, 0))
        g.paste(big, (0, -1))                       # 발바닥 y=190 규약
        g.save(os.path.join(OUT, '%s_128.png' % n))
        report(g, '%s_128.png (128x192)' % n)


if __name__ == '__main__':
    main()
