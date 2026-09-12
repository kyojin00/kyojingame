#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""팩 기본 자세에서 걷기 5프레임을 만든다.

새로 그리지 않고 **기본 자세를 부위별로 뜯어 옮긴다.** 팩은 손으로 찍은
그림이라 같은 화풍을 다시 흉내 내면 반드시 어긋난다.

  다리   색으로 골라내 왼/오른쪽으로 가르고, 디딘 다리는 제자리에 두고
         드는 다리만 위로 밀어 올린다. 위가 잘린 만큼 다리가 짧아 보이는데
         그게 곧 무릎을 굽힌 모습이다.
  몸통   다리를 뺀 나머지를 통째로 한 칸 들썩인다. 디딘 다리 맨 윗줄을
         한 줄 복사해 허리까지 이어 붙인다.
  손     다리와 반대로 한 칸. 내려가면 소매를 한 줄 늘리고 올라가면
         한 줄 줄인다.
  옆모습 다리·신발을 떼고 앞뒤로 흔들어 다시 그린다. 두 발이 x 로 겹치기
         때문에 위치를 옮기는 것만으로는 안 되고, 신발은 매번 새로 찍는다.

프레임 다섯 장은 한 걸음(두 보)을 다섯 등분한 위상이다.

    위상 t        0     .2    .4    .6    .8
    허리 높이     낮음  높음  낮음  낮음  높음      |sin|
    앞뒤 위치 L   +2    +1    -2    -2    +1        cos
    드는 높이 L    0     0     0     1     2        max(0,-sin)

t=0 과 t=.5 가 두 번의 접지다. .4/.6 이 .5 를 사이에 두고 있어 허리가
두 프레임 연달아 낮은데, 그게 실제 두 발이 같이 땅에 있는 구간이다.
"""

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 48
N = 5

P = {
    'boy': dict(
        hair=[(75, 57, 57), (112, 81, 74), (146, 112, 98), (179, 141, 116)],
        top=[(89, 133, 159), (54, 94, 122), (128, 167, 186), (36, 70, 88), (181, 205, 209)],
        bot=[(58, 57, 74), (44, 43, 58), (83, 86, 103), (31, 30, 42), (115, 125, 139)],
    ),
    'girl': dict(
        hair=[(55, 49, 70), (80, 70, 98), (107, 96, 131), (128, 117, 150), (150, 139, 172)],
        top=[(243, 236, 215), (222, 222, 206), (254, 247, 228), (172, 166, 154)],
        bot=[(70, 139, 140), (40, 102, 108), (116, 170, 170)],
    ),
}
SKIN = [(255, 227, 201), (255, 244, 223), (245, 201, 177), (191, 141, 131),
        (104, 71, 73), (234, 162, 162), (199, 97, 133)]
SKINSET = set(SKIN)
SHOE = [(217, 223, 212), (200, 199, 188), (244, 247, 240), (64, 62, 78), (236, 240, 230)]
V, BASE, LIT, SOLE = SHOE[3], SHOE[0], SHOE[2], SHOE[1]

# ------------------------------------------------------------------ 위상표
BOB = (0, 1, 0, 0, 1)           # 허리 높이
# 앞뒤 — 옆모습에서만 쓴다. 디딘 발은 땅에 박혀 있으니 몸이 지나가는 만큼
# +2 → 0 → -2 로 뒤로 밀려나고, 든 발은 뒤에서 한 번에 앞으로 넘어간다.
POS_L = (2, 0, -2, -2, -2)
POS_R = (-2, -2, 2, 2, 0)
LIFT_L = (0, 0, 0, 1, 2)        # 드는 높이
LIFT_R = (0, 2, 1, 0, 0)
HAND_L = (-1, -1, 1, 1, -1)     # 정면·후면 — 위아래로 한 칸
HAND_R = (1, 1, -1, -1, 1)
# 옆모습 — 옆에서는 팔이 앞뒤로 간다. 같은 쪽 다리와 반대 위상이다.
ARM_N = (1, 1, -1, -1, 0)       # 가까운 팔 — 앞뒤로 한 칸 (+x 가 앞)
ARM_F = (1, 1, -1, -1, 0)       # 먼 팔은 몸에 가려 앞뒤가 안 보인다. 위아래로만.

# 두 다리가 실제로 갈라지는 줄. 그 위(바지통·치마)는 흔들리지 않는 몸통이다
LEG_TOP = {'boy': 41, 'girl': 40}
HAND_COL = (range(10, 13), range(21, 24))
HAND_ROW = range(28, 36)

# 옆모습에서 두 다리가 차지하는 칸 — 앞뒤로 겹쳐 있어 자동으로 못 가른다
SIDE_SRC = {
    'boy': {41: ((13, 15), (17, 19)), 42: ((13, 15), (17, 19)), 43: ((12, 15), (17, 20))},
    'girl': {40: ((12, 15), (18, 21)), 41: ((12, 15), (17, 20)),
             42: ((12, 15), (17, 20)), 43: ((12, 15), (17, 20))},
}
NEAR_ANCHOR, FAR_ANCHOR = 2, -2             # 두 발을 모았을 때의 자리로 옮기는 값
SHOE_NEAR = dict(heel=13, toe=19, ax0=14, ax1=17, base=BASE, lit=LIT, sole=SOLE)
SHOE_FAR = dict(heel=14, toe=19, ax0=15, ax1=18, base=SOLE, lit=BASE, sole=SOLE)


def grid(im):
    px = im.load()
    return [[px[x, y][:3] if px[x, y][3] else None for x in range(W)] for y in range(H)]


def img(g):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            if g[y][x]:
                px[x, y] = g[y][x] + (255,)
    return im


def swing_hands(out, src, dxy, rows=HAND_ROW, fill=False):
    """팔을 한 칸 흔든다. 손(살색)만 옮기고 소매로 길이를 맞춘다.

    옆에서는 앞뒤로 흔드는데, 이 그림은 손이 곧 몸통의 바깥선이라 손만
    옮기면 허리가 홀쭉해지거나 팔이 떨어져 나간다. 그래서 비운 자리를
    소매로 메운다 — 실루엣은 그대로 두고 살색만 앞뒤로 미끄러진다."""
    for cols, (dx, dy) in zip(HAND_COL, dxy):
        if not dx and not dy:
            continue
        hand = [(x, y) for y in rows for x in cols
                if 0 <= x < W and out[y][x] in SKINSET]
        if not hand:
            continue
        val = {c: out[c[1]][c[0]] for c in hand}
        for x, y in hand:
            out[y][x] = None
        for (x, y), c in val.items():
            if 0 <= y + dy < H and 0 <= x + dx < W:
                out[y + dy][x + dx] = c
        if fill:                                     # 비운 자리를 소매로 메운다
            for x, y in sorted(hand, key=lambda c: c[1]):
                if out[y][x] is None and out[y - 1][x] is not None:
                    out[y][x] = out[y - 1][x]
        for x in cols if dy else ():
            ys = sorted(y for xx, y in hand if xx == x)
            if not ys:
                continue
            if dy > 0:                                   # 팔이 길어졌다 — 소매를 늘린다
                for k in range(dy):
                    out[ys[0] + k][x] = src[max(0, ys[0] + k - dy)][x]
            else:                                        # 짧아졌다 — 아래를 지운다
                for k in range(-dy):
                    out[ys[-1] - k][x] = None


def repair(out, ymax=40):
    """팔을 옮기면 몸과 소매 사이에 틈이 생긴다. 갇힌 틈은 위 색으로 메우고
    떨어져 나간 조각은 지운다. 발치(ymax 아래)는 손대지 않는다 — 두 다리
    사이는 뚫려 있어야 맞다."""
    seen = set()
    for y0 in range(ymax):
        for x0 in range(W):
            if out[y0][x0] is not None or (x0, y0) in seen:
                continue
            blob, edge, stack = [], False, [(x0, y0)]
            seen.add((x0, y0))
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < W and 0 <= ny < H):
                        edge = True
                    elif out[ny][nx] is None and (nx, ny) not in seen:
                        if ny >= ymax:
                            edge = True                  # 아래로 새면 바깥이다
                        else:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
            if not edge:
                for x, y in sorted(blob, key=lambda c: c[1]):
                    out[y][x] = out[y - 1][x] or out[y][x - 1] or out[y][x + 1]

    on = [(x, y) for y in range(H) for x in range(W) if out[y][x]]
    big, left = set(), set(on)
    while left:
        st = [left.pop()]
        comp = {st[0]}
        while st:
            x, y = st.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n in left:
                    left.discard(n)
                    comp.add(n)
                    st.append(n)
        if len(comp) > len(big):
            big = comp
    for x, y in on:
        if (x, y) not in big:
            out[y][x] = None


def hoist(g, b, top):
    """몸통을 b 칸 들어 올린다.

    올린 만큼 허리 아래가 비는데, 거기에 허리줄을 한 번 더 깐다. 다리를
    늘이면 갈라진 두 짝만 남아 실루엣이 잘록해진다 — 몸통을 늘여야 한다."""
    out = [[None] * W for _ in range(H)]
    for y in range(top - b):
        out[y] = list(g[y + b])
    for y in range(max(0, top - b), top):
        out[y] = list(g[top - 1])
    for y in range(top, H):
        out[y] = list(g[y])          # 다리를 떼고 남은 것 — 발치까지 내려온 머리끝
    return out


def place_leg(out, part, dx_of, lift, top):
    """다리 한 짝을 놓는다. 드는 다리는 위가 잘리는데 그게 굽힌 무릎이다."""
    for (x, y), c in part.items():                       # 디딤발은 땅에 붙어 있으니
        ny, nx = y - lift, x + dx_of(y)                  # 드는 발만 그만큼 뜬다
        if ny >= top and 0 <= nx < W:
            out[ny][nx] = c


def put_shoe(out, dx, dy, heel, toe, ax0, ax1, base, lit, sole, short=False):
    """오른쪽을 보는 신발. 뒤꿈치는 짧고 앞코는 세 칸 앞으로 낮게 뻗는다.

    든 발은 앞코를 두 칸 줄인다 — 발끝을 내리면 옆에서 짧아 보인다."""
    if short:
        toe -= 2
    def p(y, x, c):
        y -= dy
        x += dx
        if 0 <= y < H and 0 <= x < W:
            out[y][x] = c
    p(44, ax0, V); p(44, ax1, V)
    for x in range(ax0 + 1, ax1):
        p(44, x, base)
    p(45, heel, V)
    for x in range(heel + 1, ax1):
        p(45, x, base)
    p(45, ax1, V)
    p(46, heel, V)
    for x in range(heel + 1, toe):
        p(46, x, lit if x > heel + 1 else base)
    p(46, toe, V)
    p(47, heel, V)
    for x in range(heel + 1, toe):
        p(47, x, sole)
    p(47, toe, V)


# ------------------------------------------------------------- 정면 · 후면
def build_flat(g, kind, f):
    top = LEG_TOP[kind]
    legcol = set(P[kind]['bot']) | set(SHOE)
    if kind == 'girl':
        legcol |= SKINSET                               # 맨다리
    out = [row[:] for row in g]
    swing_hands(out, g, ((0, HAND_L[f]), (0, HAND_R[f])))

    part = {}
    for y in range(top, H):
        for x in range(W):
            if out[y][x] in legcol:
                part[(x, y)] = out[y][x]
                out[y][x] = None

    b = BOB[f]
    out = hoist(out, b, top)
    zero = lambda y: 0
    place_leg(out, {k: v for k, v in part.items() if k[0] <= 16}, zero, LIFT_L[f], top)
    place_leg(out, {k: v for k, v in part.items() if k[0] > 16}, zero, LIFT_R[f], top)
    repair(out)
    return out


# ------------------------------------------------------------------ 옆모습
def build_side(g, kind, f):
    src = SIDE_SRC[kind]
    top = min(src)
    out = [row[:] for row in g]
    swing_hands(out, g, ((ARM_N[f], 0), (0, ARM_F[f])), range(30, 34), fill=True)

    near, far = {}, {}
    for y, ((n0, n1), (f0, f1)) in src.items():
        for x in range(n0, n1 + 1):
            near[(x, y)] = out[y][x]
            out[y][x] = None
        for x in range(f0, f1 + 1):
            far[(x, y)] = out[y][x]
            out[y][x] = None
    for y in range(44, H):
        for x in range(W):
            out[y][x] = None

    b = BOB[f]
    out = hoist(out, b, top)

    for part, anchor, pos, lift, sh in (
            (far, FAR_ANCHOR, POS_L[f], LIFT_L[f], SHOE_FAR),
            (near, NEAR_ANCHOR, POS_R[f], LIFT_R[f], SHOE_NEAR)):
        place_leg(out, part, lambda y, a=anchor, o=pos: a + o, lift, top)
        put_shoe(out, pos, lift, short=lift > 0, **sh)
    repair(out)
    return out


def main():
    for kind in ('boy', 'girl'):
        for view, fn in (('down', build_flat), ('up', build_flat), ('side', build_side)):
            g = grid(Image.open(os.path.join(HERE, '%s_%s.png' % (kind, view))).convert('RGBA'))
            for f in range(N):
                out = fn(g, kind, f)
                im = img(out)
                name = '%s_%s_walk_%d' % (kind, view, f)
                im.save(os.path.join(HERE, name + '.png'))
                im.resize((W * 4, H * 4), Image.NEAREST).save(
                    os.path.join(HERE, name + '_128.png'))
    print('걷기 30장 저장')


if __name__ == '__main__':
    main()
