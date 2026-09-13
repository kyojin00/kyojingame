#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""바깥에서 뽑아 온 그림을 게임에 들어가는 꼴로 손질한다.

생성기는 제 팔레트로 그리고 가장자리를 부드럽게 깐다. 26색이어야 할 그림이
수백 색으로 나온다. 우리 색 바꾸기는 **RGB 정확히 일치**로 치환하므로
(game_data.gd 의 APPEAR_* 0행), 한 칸이라도 어긋나면 머리색·옷색 고르기가
통째로 죽는다. 그래서 받는 즉시 팩 색으로 눌러 앉힌다.

  1 배율 찾기   4배로 그려진 그림이면 4칸이 한 칸이다. 블록이 고른지 보고
               정수 배율을 찾아 줄인다. 못 찾으면 손대지 않는다.
  2 알파 0/255  반투명은 게임에서 테두리가 번진다. 128 에서 자른다.
  3 색 앉히기   팩 팔레트에서 제일 가까운 색으로. 남자 그림은 남자 표만,
               여자 그림은 여자 표만 쓴다 — 섞으면 갈색 머리가 보라로 간다.
  4 자리 맞추기 발바닥 y=47, 발 중심 x=16.0. 안 맞으면 방향 바뀔 때 튄다.
  5 검사       한 덩어리인가, 새 색이 없는가.

쓰기: python3 ingest.py <입력.png> <boy|girl> [<나갈이름.png>]
"""

import os
import sys
from collections import deque
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 48

# 살결·신발·눈·볼은 남녀 공용
COMMON = [(255, 227, 201), (255, 244, 223), (245, 201, 177), (191, 141, 131),
          (104, 71, 73), (234, 162, 162), (199, 97, 133), (64, 37, 56), (152, 64, 100),
          (217, 223, 212), (200, 199, 188), (244, 247, 240), (64, 62, 78), (236, 240, 230)]
KIND = {
    'boy': [(75, 57, 57), (112, 81, 74), (146, 112, 98), (179, 141, 116),
            (89, 133, 159), (54, 94, 122), (128, 167, 186), (36, 70, 88), (181, 205, 209),
            (58, 57, 74), (44, 43, 58), (83, 86, 103), (31, 30, 42), (115, 125, 139)],
    'girl': [(55, 49, 70), (80, 70, 98), (107, 96, 131), (128, 117, 150), (150, 139, 172),
             (243, 236, 215), (222, 222, 206), (254, 247, 228), (172, 166, 154),
             (70, 139, 140), (40, 102, 108), (116, 170, 170),
             (168, 206, 212), (217, 183, 104)],
}


def palette(kind):
    return COMMON + KIND[kind]


def detect_scale(px, w, h):
    """정수 배율 찾기. 4배로 그려진 그림이면 네 칸이 똑같다."""
    for s in range(min(w, h, 16), 1, -1):
        if w % s or h % s:
            continue
        ok = True
        for by in range(0, h, s):
            for bx in range(0, w, s):
                first = px[bx, by]
                for y in range(by, by + s):
                    for x in range(bx, bx + s):
                        if px[x, y] != first:
                            ok = False
                            break
                    if not ok:
                        break
                if not ok:
                    break
            if not ok:
                break
        if ok:
            return s
    return 1


def near(c, pal):
    """사람 눈에 가깝게 — 초록에 무게를 더 준다."""
    r, g, b = c
    best, bd = pal[0], None
    for p in pal:
        d = 2 * (r - p[0]) ** 2 + 4 * (g - p[1]) ** 2 + 3 * (b - p[2]) ** 2
        if bd is None or d < bd:
            best, bd = p, d
    return best


def check(g):
    on = {(x, y) for y in range(H) for x in range(W) if g[y][x]}
    if not on:
        return ['빈 그림']
    bad = []
    bot = max(y for _, y in on)
    feet = [x for x, y in on if y == bot]
    if bot != 47:
        bad.append('발바닥 y=%d (47 이어야 함)' % bot)
    c = (min(feet) + max(feet)) / 2
    if abs(c - 16.0) > 0.5:
        bad.append('발 중심 %.1f (16.0 이어야 함)' % c)
    st = min(on)
    seen, q = {st}, deque([st])
    while q:
        x, y = q.popleft()
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + d[0], y + d[1])
            if n in on and n not in seen:
                seen.add(n)
                q.append(n)
    if len(seen) != len(on):
        bad.append('떨어진 조각 %d칸' % (len(on) - len(seen)))
    return bad


def ingest(path, kind, out=None):
    im = Image.open(path).convert('RGBA')
    ow, oh = im.size
    w, h = im.size
    px = im.load()
    raw = len({px[x, y][:3] for y in range(h) for x in range(w) if px[x, y][3] > 128})

    s = detect_scale(px, w, h)
    if s > 1:
        im = im.resize((w // s, h // s), Image.NEAREST)
        w, h = im.size
        px = im.load()

    # 알파를 먼저 자르고, 사람이 있는 데만 오려낸다
    box = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 128]
    if not box:
        print('%s: 불투명한 칸이 없다' % path)
        return
    bx0, bx1 = min(b[0] for b in box), max(b[0] for b in box)
    by0, by1 = min(b[1] for b in box), max(b[1] for b in box)
    cw, ch = bx1 - bx0 + 1, by1 - by0 + 1
    fit = min(1.0, W / cw, (H - 1) / ch)
    if fit < 1.0:
        # 사람이 32x48 보다 크면 줄인다. 잘라내면 발이나 머리가 날아간다
        im = im.crop((bx0, by0, bx1 + 1, by1 + 1)).resize(
            (max(1, int(cw * fit)), max(1, int(ch * fit))), Image.NEAREST)
        w, h = im.size
        px = im.load()

    pal = palette(kind)
    cells = []
    for y in range(h):
        for x in range(w):
            r, gg, b, a = px[x, y]
            if a > 128:
                cells.append((x, y, near((r, gg, b), pal)))
    if not cells:
        print('%s: 불투명한 칸이 없다' % path)
        return

    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    cx = (min(xs) + max(xs)) / 2.0
    dx = int(round(16 - cx))                     # 가로는 가운데
    dy = 47 - max(ys)                            # 발바닥을 맨 아래로

    g = [[None] * W for _ in range(H)]
    lost = 0
    for x, y, c in cells:
        nx, ny = x + dx, y + dy
        if 0 <= nx < W and 0 <= ny < H:
            g[ny][nx] = c
        else:
            lost += 1

    res = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    rp = res.load()
    for y in range(H):
        for x in range(W):
            if g[y][x]:
                rp[x, y] = g[y][x] + (255,)

    out = out or os.path.join(HERE, 'in_%s.png' % os.path.splitext(os.path.basename(path))[0])
    res.save(out)

    used = len({c[2] for c in cells})
    print('%s' % os.path.basename(path))
    print('  들어옴 %dx%d · 배율 %d · 색 %d개%s'
          % (ow, oh, s, raw, '' if fit >= 1.0 else ' · %.2f 배로 줄임' % fit))
    print('  나감   32x48 · 팩 색 %d개' % used)
    if lost:
        print('  ** 밖으로 밀려 잘린 칸 %d개 — 원본이 32x48 보다 크다' % lost)
    bad = check(g)
    print('  검사   %s' % ('통과' if not bad else ' / '.join(bad)))
    print('  저장   %s' % out)
    return out


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    ingest(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
