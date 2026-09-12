#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""옆모습을 완전한 옆면(90도)으로 손수 찍는다.

복셀로 세워 비춰봤더니 32칸에서는 다 뭉갠다. 도트는 면을 계산한 그림이
아니라 선을 놓은 그림이라서, 매끈한 덩어리를 줄여 봐야 윤곽이 사라진다.

머리는 줄마다 실루엣 폭과 앞머리 끝 칸만 적는다. 글자 그림판은 열일곱
줄을 손으로 세야 해서 반드시 한 칸씩 어긋난다.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 48

P = {
    'boy': dict(hair=[(75, 57, 57), (112, 81, 74), (146, 112, 98), (179, 141, 116)],
                top=[(89, 133, 159), (54, 94, 122), (128, 167, 186), (36, 70, 88), (181, 205, 209)],
                bot=[(58, 57, 74), (44, 43, 58), (83, 86, 103), (31, 30, 42), (115, 125, 139)]),
    'girl': dict(hair=[(55, 49, 70), (80, 70, 98), (107, 96, 131), (128, 117, 150), (150, 139, 172)],
                 top=[(243, 236, 215), (222, 222, 206), (254, 247, 228), (172, 166, 154)],
                 bot=[(70, 139, 140), (40, 102, 108), (116, 170, 170)]),
}
SK, SKL, SKM, SKD, SKO = (255, 227, 201), (255, 244, 223), (245, 201, 177), \
    (191, 141, 131), (104, 71, 73)
BL, BLD, EYD, EYP = (234, 162, 162), (199, 97, 133), (64, 37, 56), (152, 64, 100)
SHOE = [(217, 223, 212), (200, 199, 188), (244, 247, 240), (64, 62, 78), (236, 240, 230)]

# 줄: 실루엣 (x0,x1) · 앞머리가 끝나는 칸(그 앞은 전부 얼굴)
HEAD = {
    'boy': dict(
        sil=[(5, 12, 20), (6, 11, 21), (7, 10, 22), (8, 9, 23), (9, 8, 23),
             (10, 8, 23), (11, 8, 23), (12, 8, 23), (13, 8, 23), (14, 8, 23),
             (15, 8, 23), (16, 8, 23), (17, 9, 22), (18, 10, 21), (19, 11, 19)],
        fr={11: 19, 12: 18, 13: 17, 14: 17, 15: 17, 16: 17, 17: 17, 18: 17, 19: 16},
        strand=[(13, 7), (17, 8), (11, 10), (15, 11), (19, 9), (12, 14), (16, 15)],
        lit=[(13, 6), (14, 6), (12, 7)],
        eye=20, brow=13, ear=(17, 14), neck=(13, 17),
    ),
    'girl': dict(
        sil=[(4, 12, 21), (5, 10, 23), (6, 9, 24), (7, 8, 24), (8, 7, 24),
             (9, 6, 24), (10, 6, 24), (11, 6, 24), (12, 6, 24), (13, 6, 24),
             (14, 6, 24), (15, 6, 24), (16, 6, 24), (17, 5, 23), (18, 5, 22),
             (19, 5, 20), (20, 5, 19), (21, 5, 18)],
        fr={11: 20, 12: 19, 13: 18, 14: 18, 15: 18, 16: 18, 17: 18, 18: 18, 19: 17},
        strand=[(12, 7), (17, 8), (10, 10), (15, 11), (20, 9), (11, 14), (16, 15),
                (8, 24), (11, 27), (7, 30), (10, 33), (8, 36)],
        lit=[(13, 5), (14, 5), (12, 6)],
        eye=21, brow=13, ear=(18, 14), neck=(14, 18),
    ),
}
# 긴 머리는 등 뒤 한 덩어리로 흘러내린다
GIRL_FALL = [(22, 5, 13), (23, 5, 13), (24, 5, 13), (25, 5, 13), (26, 5, 13),
             (27, 5, 13), (28, 5, 13), (29, 5, 13), (30, 5, 13), (31, 6, 13),
             (32, 6, 13), (33, 6, 13), (34, 6, 13), (35, 7, 13), (36, 7, 12),
             (37, 8, 12), (38, 8, 12), (39, 9, 12)]


def img(g):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            if g[y][x]:
                px[x, y] = g[y][x] + (255,)
    return im


def edge(g, cells, dark):
    for x, y in cells:
        for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + a, y + b
            if not (0 <= nx < W and 0 <= ny < H) or g[ny][nx] is None:
                g[y][x] = dark
                break


def mass(g, rows, pal, strand=(), lit=()):
    """머리 덩어리 한 채. **팩 앞머리와 같은 어휘로 칠한다.**

    앞머리를 뜯어보면 세 가지다 — 가장자리가 한 줄이 아니라 두 단
    (그늘 한 칸 안쪽, 그 바깥에 가장 어두운 단), 덩어리 안에 두 칸짜리
    짧은 가닥이 불규칙하게 흩뿌려짐, 밝은 단은 정수리 몇 칸뿐.

    한 색 덩어리에 딱딱한 외곽선 하나만 두르면 종이를 오려 붙인 꼴이 돼
    앞모습과 화풍이 달라진다."""
    HD, HS, HB, HL = pal[0], pal[1], pal[2], pal[-1]
    span = {y: (x0, x1) for y, x0, x1 in rows}
    cells = [(x, y) for y, x0, x1 in rows for x in range(x0, x1 + 1)]
    for x, y in cells:
        g[y][x] = HB
    ybot = max(span)
    for x, y in cells:                           # 가장자리 한 칸 안쪽을 그늘로
        for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
            nx, ny = x + a, y + b
            if ny not in span or not (span[ny][0] <= nx <= span[ny][1]):
                g[y][x] = HS
                break
    for y, (x0, x1) in span.items():
        if y == ybot:
            for x in range(x0, x1 + 1):
                g[y][x] = HS
    for x, y in strand:                          # 두 칸짜리 짧은 가닥
        for k in (0, 1):
            if y + k in span and span[y + k][0] < x + k < span[y + k][1]:
                g[y + k][x + k] = HS
    for x, y in lit:
        if y in span and span[y][0] <= x <= span[y][1]:
            g[y][x] = HL
    edge(g, cells, HD)
    return cells


FACE = {                                     # 줄 -> (앞머리가 끝나는 칸, 얼굴 끝 칸)
    'boy': {12: (20, 23), 13: (19, 23), 14: (19, 23), 15: (18, 23),
            16: (18, 23), 17: (17, 22), 18: (17, 22), 19: (16, 21)},
    'girl': {12: (20, 23), 13: (19, 23), 14: (19, 23), 15: (18, 23),
             16: (18, 23), 17: (17, 22), 18: (17, 22), 19: (16, 21)},
}
EYE_SRC = 18                                 # 앞모습 오른쪽 눈이 시작하는 칸
EYE_DST = 19                                 # 옆얼굴에서 눈이 앉는 칸


def head(g, src, kind):
    """옆얼굴은 **앞머리 픽셀을 옮겨** 만든다.

    새로 칠하면 결도 음영도 선도 달라져 화풍이 어긋난다. 앞머리를 통째로
    베끼고, 얼굴의 뒤쪽 절반만 머리카락으로 덮은 뒤, 남은 눈 하나를
    앞으로 민다. 덮는 머리카락도 새로 칠하지 않고 여섯 줄 위의 결을
    그대로 내려 붙인다 — 그래야 가닥이 이어진다."""
    hairset = set(P[kind]['hair'])
    HB = P[kind]['hair'][2]
    for y in range(3, 22):
        g[y] = list(src[y])

    for y, (cut, fx1) in FACE[kind].items():
        for x in range(W):                       # 뒤쪽은 위 결을 내려 붙인다
            if g[y][x] is not None and x <= cut:
                c = src[y - 6][x]
                g[y][x] = c if c in hairset else HB
        for x in range(cut + 1, fx1 + 1):
            g[y][x] = SK
        for x in range(fx1 + 1, W):
            g[y][x] = None
        g[y][fx1] = SKO if y >= 17 else SKD      # 이마는 부드럽게, 턱만 또렷이

    for y in range(14, 18):                      # 남은 눈 하나를 앞으로
        for k in range(3):
            c = src[y][EYE_SRC + k]
            if c is not None:
                g[y][EYE_DST + k] = c
    g[16][22] = SKM                              # 코 — 실루엣을 튀우면 부리가 된다

    for y in (20, 21):                           # 목은 앞모습 그대로 두되 한 칸 뒤로
        row = [None] * W
        for x in range(W):
            if src[y][x] is not None and x < 22:
                row[x - 1] = src[y][x]
        g[y] = row


def fall(g, src):
    """등 뒤로 흘러내린 머리채. 결은 앞모습 옆머리 칸을 돌려 쓴다."""
    hairset = set(P['girl']['hair'])
    cols = [x for x in range(16) if any(src[y][x] in hairset for y in range(24, 38))]
    if not cols:
        return
    cells = []
    for y, x0, x1 in GIRL_FALL:
        for x in range(x0, x1 + 1):
            k = round((x - x0) * (len(cols) - 1) / max(1, x1 - x0))
            c = src[y][cols[k]]                  # 앞모습 옆머리를 폭에 맞춰 늘인다.
                                                 # 돌려 쓰면 이음매가 줄무늬로 남는다
            g[y][x] = c if c in hairset else P['girl']['hair'][2]
            cells.append((x, y))
    edge(g, cells, P['girl']['hair'][0])


def darkest(kind, c):
    for key, i in (('top', 3), ('bot', 1), ('hair', 0)):
        pal = P[kind][key]
        if c in pal:
            return pal[min(i, len(pal) - 1)]
    if c in SHOE:
        return SHOE[3]
    if c in (SK, SKL, SKM, SKD, SKO):
        return SKO
    return c


def body(g, src, kind):
    """몸통은 앞모습을 좌우로 깎는다. 옆에서는 어깨가 좁다.
    깎아낸 자리의 새 바깥칸은 제 재료의 가장 어두운 단으로 다시 두른다."""
    hairset = set(P[kind]['hair'])
    for y in range(22, 48):
        xs = [x for x in range(W) if src[y][x] and src[y][x] not in hairset]
        if not xs:
            continue
        t = 2 if len(xs) >= 12 else (1 if len(xs) >= 8 else 0)
        keep = xs[t:len(xs) - t] if t else xs
        for x in keep:
            g[y][x] = src[y][x]
        if t:
            g[y][keep[0]] = darkest(kind, src[y][keep[0]])
            g[y][keep[-1]] = darkest(kind, src[y][keep[-1]])


def one_arm(g, kind):
    """옆에서는 팔이 하나다. 몸통 앞쪽에 소매를 세우고 손을 단다."""
    top = P[kind]['top']
    sleeve, line = top[1], top[min(3, len(top) - 1)]
    wrist = 30 if kind == 'boy' else 29
    for y in range(24, wrist + 1):
        xs = [x for x in range(W) if g[y][x]]
        if len(xs) < 6:
            continue
        g[y][xs[-2]] = sleeve
        g[y][xs[-3]] = line
    for y in range(wrist + 1, wrist + 4):
        xs = [x for x in range(W) if g[y][x]]
        if len(xs) < 6:
            continue
        g[y][xs[-2]] = SKM
        g[y][xs[-3]] = SKD


def feet(g):
    V, BASE, LIT, SOLE = SHOE[3], SHOE[0], SHOE[2], SHOE[1]
    for y in range(44, 48):
        for x in range(W):
            g[y][x] = None

    def shoe(heel, toe, ax0, ax1, base, lit, sole):
        g[44][ax0] = V; g[44][ax1] = V
        for x in range(ax0 + 1, ax1):
            g[44][x] = base
        g[45][heel] = V
        for x in range(heel + 1, ax1):
            g[45][x] = base
        g[45][ax1] = V
        g[46][heel] = V
        for x in range(heel + 1, toe):
            g[46][x] = lit if x > heel + 1 else base
        g[46][toe] = V
        g[47][heel] = V
        for x in range(heel + 1, toe):
            g[47][x] = sole
        g[47][toe] = V

    shoe(16, 21, 17, 20, SOLE, BASE, SOLE)
    shoe(11, 17, 12, 15, BASE, LIT, SOLE)


def build(kind):
    im = Image.open(os.path.join(HERE, '%s.png' % kind)).convert('RGBA')
    px = im.load()
    src = [[px[x, y][:3] if px[x, y][3] else None for x in range(W)] for y in range(H)]
    g = [[None] * W for _ in range(H)]
    head(g, src, kind)
    if kind == 'girl':
        fall(g, src)
    body(g, src, kind)                          # 옷은 머리채 위에 — 머리는 등 뒤다
    one_arm(g, kind)
    feet(g)
    return g


if __name__ == '__main__':
    for k in ('boy', 'girl'):
        im = img(build(k))
        im.save(os.path.join(HERE, '%s_side.png' % k))
        im.resize((128, 192), Image.NEAREST).save(os.path.join(HERE, '%s_side_128.png' % k))
    print('옆면')
