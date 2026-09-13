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

import math
import os
import sys
from collections import deque
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 48

# 살결·신발은 남녀 공용
COMMON = [(255, 227, 201), (255, 244, 223), (245, 201, 177), (191, 141, 131),
          (104, 71, 73),
          (217, 223, 212), (200, 199, 188), (244, 247, 240), (64, 62, 78), (236, 240, 230)]
# 눈·볼은 **넓은 면에 쓰면 안 되는 점찍기 색**이다. 일반 팔레트에 섞어 두면
# 거리 재기에서 머리카락을 잡아먹는다 — 중간 보라 머리(140,70,110)가 눈분홍
# (152,64,100)에 붙어 머리 전체에 분홍 얼룩이 박혔다. 그래서 따로 떼어 두고,
# 원본이 그 색에 아주 가까울 때만 그대로 살린다.
ACCENT = [(234, 162, 162), (199, 97, 133), (64, 37, 56), (152, 64, 100),
          (168, 206, 212), (217, 183, 104)]
ACCENT_TOL = 2600                            # 이 거리 안이면 점찍기 색 그대로
KIND = {
    'boy': [(75, 57, 57), (112, 81, 74), (146, 112, 98), (179, 141, 116),
            (89, 133, 159), (54, 94, 122), (128, 167, 186), (36, 70, 88), (181, 205, 209),
            (58, 57, 74), (44, 43, 58), (83, 86, 103), (31, 30, 42), (115, 125, 139)],
    'girl': [(55, 49, 70), (80, 70, 98), (107, 96, 131), (128, 117, 150), (150, 139, 172),
             (243, 236, 215), (222, 222, 206), (254, 247, 228), (172, 166, 154),
             (70, 139, 140), (40, 102, 108), (116, 170, 170),
             (168, 206, 212), (217, 183, 104)],
}


SKIN = [(255, 227, 201), (255, 244, 223), (245, 201, 177), (191, 141, 131), (104, 71, 73)]
SHOE = [(217, 223, 212), (200, 199, 188), (244, 247, 240), (64, 62, 78), (236, 240, 230)]
PARTS = {
    'boy': dict(hair=[(75, 57, 57), (112, 81, 74), (146, 112, 98), (179, 141, 116)],
                top=[(89, 133, 159), (54, 94, 122), (128, 167, 186), (36, 70, 88), (181, 205, 209)],
                bot=[(58, 57, 74), (44, 43, 58), (83, 86, 103), (31, 30, 42), (115, 125, 139)]),
    'girl': dict(hair=[(55, 49, 70), (80, 70, 98), (107, 96, 131), (128, 117, 150), (150, 139, 172)],
                 top=[(243, 236, 215), (222, 222, 206), (254, 247, 228), (172, 166, 154)],
                 bot=[(70, 139, 140), (40, 102, 108), (116, 170, 170)]),
}


def mats(kind):
    p = PARTS[kind]
    return dict(hair=p['hair'], top=p['top'], bot=p['bot'], shoe=SHOE, skin=SKIN)


PENALTY = 3.0                                    # 제자리가 아닌 재료에 매기는 벌점


def expected(ym):
    """그 높이에서 **주로** 나와야 할 재료."""
    if ym < 0.44:
        return 'hair'
    if ym < 0.74:
        return 'top'
    if ym < 0.92:
        return 'bot'
    return 'shoe'


def band_near(c, kind, ym):
    """높이로 기울이되 **못 박지는 않는다.**

    처음엔 높이로 재료를 정해 버렸다. 그랬더니 생성기가 스웨터를 회색빛
    (118,134,151) 으로 그려 온 걸 바로잡는 데는 성공했지만(가슴팍 158칸이
    바지색에 앉던 것), 엉덩이까지 내려온 여자 머리카락이 "몸통 칸"에 걸려
    **살색**이 됐다 — 471칸이 살결로 앉았다.

    그래서 제자리 재료는 그대로, 아닌 재료는 거리에 벌점을 곱해서 고른다.
    색이 확실히 가까우면(머리카락) 벌점을 물고도 이기고, 애매하면
    (회색빛 스웨터 — 상의냐 바지냐) 높이가 결정한다.

    살결은 얼굴·손·맨다리 어디에나 나오므로 벌점을 안 문다."""
    p = PARTS[kind]
    want = expected(ym)
    best, bd = None, None
    for mat, pal in (('hair', p['hair']), ('top', p['top']), ('bot', p['bot']),
                     ('shoe', SHOE), ('skin', SKIN)):
        k = 1.0 if (mat == want or mat == 'skin') else PENALTY
        for col in pal:
            d = dist(c, col) * k
            if bd is None or d < bd:
                best, bd = col, d
    return best


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


def dist(c, p):
    return 2 * (c[0] - p[0]) ** 2 + 4 * (c[1] - p[1]) ** 2 + 3 * (c[2] - p[2]) ** 2


def near(c, pal):
    """사람 눈에 가깝게 — 초록에 무게를 더 준다.

    눈·볼 같은 점찍기 색은 **아주 가까울 때만** 쓴다. 안 그러면 넓은 면을
    잡아먹는다."""
    a = min(ACCENT, key=lambda p: dist(c, p))
    if dist(c, a) <= ACCENT_TOL:
        return a
    return min(pal, key=lambda p: dist(c, p))


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


def ingest(path, kind, out=None, raw=False):
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

    # 원본 색마다 **주로 어느 높이에 나오는지**를 먼저 센다. 색 하나가
    # 몸 전체에 흩어져 있으면 그 평균 높이로 재료를 정한다.
    on = [(x, y, px[x, y][:3]) for y in range(h) for x in range(w) if px[x, y][3] > 128]
    ys = [c[1] for c in on]
    ytop, tall = min(ys), max(ys) - min(ys) + 1
    acc = {}
    for x, y, c in on:
        a = acc.setdefault(c, [0, 0])
        a[0] += (y - ytop) / tall
        a[1] += 1
    lut, dark = {}, {}
    for c, a in ((), acc.items())[not raw]:
        if max(c) < 34:                          # 검정은 나중에 이웃을 보고 정한다
            lut[c] = None
            continue
        ym = a[0] / a[1]
        m = min(ACCENT, key=lambda q: dist(c, q))
        lut[c] = m if dist(c, m) <= ACCENT_TOL else band_near(c, kind, ym)
    for mat, pal in mats(kind).items():
        for col in pal:
            dark[col] = pal[0] if mat in ('hair',) else pal[min(3, len(pal) - 1)]
    # **검정 외곽선을 재료별로 나눈다.**
    # 생성기는 온 몸을 검정 한 색으로 두르는데(여자는 스물여덟 칸 중 하나가
    # 검정이었다), 우리 팩은 검정을 한 칸도 안 쓴다 — 재료마다 제 색 중
    # 가장 어두운 단으로 두른다. 그래서 검은 칸마다 **둘레에 뭐가 있는지**
    # 보고 그 재료의 가장 어두운 단을 준다.
    grid = {(x, y): (c if raw else lut[c]) for x, y, c in on}
    ymof = {(x, y): (y - ytop) / tall for x, y, c in on}
    for _ in range(12):
        todo = [p for p, v in grid.items() if v is None]
        if not todo:
            break
        fixed = {}
        for (x, y) in todo:
            near_mat = {}
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    v = grid.get((x + dx, y + dy))
                    if v:
                        wgt = 3 if abs(dx) + abs(dy) == 1 else 1
                        near_mat[v] = near_mat.get(v, 0) + wgt
            if near_mat:
                fixed[(x, y)] = dark.get(max(near_mat, key=near_mat.get))
        if not fixed:
            break
        grid.update(fixed)
    # 둘레까지 전부 검정이라 끝내 못 정한 칸 — 버리면 구멍이 나고 조각이
    # 떨어진다. 그 높이에 있어야 할 재료의 가장 어두운 단으로 메운다.
    for p, v in list(grid.items()):
        if v is None:
            pal = mats(kind)[expected(ymof[p])]
            grid[p] = pal[0] if len(pal) == 4 else pal[min(3, len(pal) - 1)]
    cells = [(x, y, grid[(x, y)]) for x, y, c in on]
    if not cells:
        print('%s: 불투명한 칸이 없다' % path)
        return

    ys = [c[1] for c in cells]
    # 가로는 **발**을 기준으로 맞춘다. 몸 전체로 맞추면 머리채가 한쪽으로
    # 쏠린 방향에서 발이 옆으로 밀려, 방향이 바뀔 때 캐릭터가 튄다.
    foot = [c[0] for c in cells if c[1] >= max(ys) - 1]
    cx = (min(foot) + max(foot)) / 2.0
    # 파이썬 round 는 0.5 를 짝수로 붙인다(round(-0.5)==0). 발이 반 칸
    # 어긋난 채 굳어 버리므로 항상 0.5 를 더해 내림한다.
    dx = math.floor(16 - cx + 0.5)
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
    print('%s%s' % (os.path.basename(path), ' [원본색]' if raw else ''))
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
    outp = next((a for a in sys.argv[3:] if not a.startswith('--')), None)
    ingest(sys.argv[1], sys.argv[2], outp, raw='--raw' in sys.argv)
