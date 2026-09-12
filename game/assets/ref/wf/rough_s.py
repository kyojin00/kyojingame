#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""w96_s 에 손으로 찍은 결을 얹는다.

s 는 이목구비 균형과 옷 구조는 좋은데 머리·윗도리·바지·장화가 전부
매끈한 단색 면이라 벡터로 부어 놓은 것처럼 보인다. 재질마다 **짧은 획**을
불규칙하게 얹어 결을 만든다.

디더(한 칸씩 번갈아)는 쓰지 않는다 — 전에 그걸로 했다가 게임 크기에서
회색 얼룩이 됐다. 대신 2~5칸짜리 획을 길이도 자리도 제각각으로 놓는다.
획은 실루엣 가장자리(윤곽)에는 닿지 않게 해서 실루엣이 상하지 않는다.
"""

import os
import random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

SK, SK_L, SK_D = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD = (82,53,33), (56,37,25), (39,26,18)

# 재질 = (밑색, 어두운 획, 밝은 획, 윤곽색, 방향, 밀도(칸/획), 획 길이들)
MATS = [
    # 머리 — 세로 결. 길고 촘촘해야 머리카락으로 읽힌다
    ({HR, HR_L},  HR_D, HR_L,  HR_DD, 'v', 11, (3, 4, 4, 5, 6, 7)),
    # 윗도리 — 천 올. 짧게 흩어 놔야 무늬가 안 된다
    ({SH, SH_L},  SH_D, SH_L,  SH_DD, 'v', 13, (2, 2, 3, 3, 4)),
    # 아랫도리 — 능직 바지. 세로로 길게
    ({PT, PT_L},  PT_D, PT_L,  PT_DD, 'v', 11, (3, 4, 4, 5, 6)),
    # 장화 — 가죽 긁힘은 가로로 짧게
    ({SO},        SO_D, SO_D,  SO_DD, 'h', 14, (2, 2, 3, 3)),
]


def load(p):
    im = Image.open(p).convert('RGBA')
    return im, im.load(), im.size


def edge_near(px, W, H, x, y, edge, r=1):
    """윤곽(재질 최암단) 이나 캔버스 밖이 r 칸 안에 있나."""
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < W and 0 <= ny < H):
                return True
            c = px[nx, ny]
            if c[3] == 0 or c[:3] == edge:
                return True
    return False


def stroke(px, W, H, x, y, n, col, base, edge, vert):
    """한 획 — 밑색 위에만, 윤곽에서 한 칸 떨어져서."""
    laid = 0
    for i in range(n):
        nx, ny = (x, y + i) if vert else (x + i, y)
        if not (0 <= nx < W and 0 <= ny < H):
            break
        if px[nx, ny][:3] not in base:
            break
        if edge_near(px, W, H, nx, ny, edge):
            break
        px[nx, ny] = col + (255,)
        laid += 1
    return laid


def roughen(path, seed):
    im, px, (W, H) = load(path)
    rnd = random.Random(seed)
    for base, dark, lite, edge, axis, dens, lens in MATS:
        cells = [(x, y) for y in range(H) for x in range(W)
                 if px[x, y][3] and px[x, y][:3] in base]
        if not cells:
            continue
        n = max(5, len(cells) // dens)
        tries = laid = 0
        while laid < n and tries < n * 40:
            tries += 1
            x, y = cells[rnd.randrange(len(cells))]
            col = dark if rnd.random() < 0.66 else lite
            if stroke(px, W, H, x, y, rnd.choice(lens), col,
                      base, edge, axis == 'v') >= 2:
                laid += 1
    return im


def main():
    for sex in ('boy', 'girl'):
        for kind in ('down', 'side', 'up'):
            src = os.path.join(HERE, 'w96_s_%s_%s.png' % (sex, kind))
            dst = os.path.join(HERE, 'w96_s2_%s_%s.png' % (sex, kind))
            # 방향마다 씨앗을 달리해야 결이 세 장 똑같이 반복되지 않는다
            seed = hash((sex, kind)) & 0xffff
            roughen(src, seed).save(dst)
            print('%-22s -> %s' % (os.path.basename(src), os.path.basename(dst)))


if __name__ == '__main__':
    main()
