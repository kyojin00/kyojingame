#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""캐릭터를 **덩어리(복셀)로 한 번 세우고** 방향마다 비춰서 뽑는다.

앞·옆·뒤를 따로 그리면 반드시 어긋난다. 옆만 손대면 머리 크기가 달라지고
어깨가 틀어진다. 그래서 덩어리를 하나 세우고 카메라만 돌린다.

덩어리는 **팩 앞모습을 그대로 부풀려** 만든다. 처음부터 공과 통으로 쌓아
봤더니 목이 길어지고 어깨가 각져서 딴 사람이 됐다. 앞모습에서 부풀리면
앞은 원본과 한 칸도 안 틀어지고, 옆·뒤가 거기서 따라 나온다.

  두께  실루엣 안쪽으로 얼마나 들어왔는지(거리)를 재서 반구로 부푼다.
        가장자리는 얇고 한가운데가 제일 두껍다.
  뒤통수 머리 줄의 뒤쪽 절반은 무조건 머리카락이다. 앞모습에는 뒤통수가
        없으니 거기서 가져올 수가 없다.
  얼굴  옆·뒤에서는 이목구비를 따로 찍어 얹는다. 부풀리기만 해서는
        옆얼굴에 눈이 안 걸린다.
"""

import math
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, D = 32, 48, 22
ZC = 11                                  # 몸 한가운데 깊이

PAL = {
    'skin': dict(base=(255, 227, 201), lit=(255, 244, 223),
                 shade=(245, 201, 177), dark=(104, 71, 73)),
    'shoe': dict(base=(217, 223, 212), lit=(244, 247, 240),
                 shade=(200, 199, 188), dark=(64, 62, 78)),
    'sock': dict(base=(236, 240, 230), lit=(244, 247, 240),
                 shade=(217, 223, 212), dark=(172, 166, 154)),
    'boy.hair': dict(base=(146, 112, 98), lit=(179, 141, 116),
                     shade=(112, 81, 74), dark=(75, 57, 57)),
    'boy.top': dict(base=(89, 133, 159), lit=(128, 167, 186),
                    shade=(54, 94, 122), dark=(36, 70, 88)),
    'boy.bot': dict(base=(58, 57, 74), lit=(83, 86, 103),
                    shade=(44, 43, 58), dark=(31, 30, 42)),
    'girl.hair': dict(base=(107, 96, 131), lit=(150, 139, 172),
                      shade=(80, 70, 98), dark=(55, 49, 70)),
    'girl.top': dict(base=(243, 236, 215), lit=(254, 247, 228),
                     shade=(222, 222, 206), dark=(172, 166, 154)),
    'girl.bot': dict(base=(70, 139, 140), lit=(116, 170, 170),
                     shade=(40, 102, 108), dark=(40, 102, 108)),
}
EYE_D, EYE_P, BLUSH, BLUSH_D = (64, 37, 56), (152, 64, 100), (234, 162, 162), (199, 97, 133)
ACC = {(217, 183, 104), (168, 206, 212)}
LIGHT = (-0.42, -0.80, -0.44)

# 재료별 두께(반지름). 머리는 공, 몸은 납작, 팔다리는 가늘다
THICK = {'hair': 6.5, 'skin': 6.0, 'top': 3.6, 'bot': 2.6, 'shoe': 3.4, 'sock': 2.2}
HEAD_BOT = 21                            # 목 아랫줄


def mat_of(kind, c):
    p = PAL
    for key in ('hair', 'top', 'bot'):
        full = '%s.%s' % (kind, key)
        if c in p[full].values():
            return full
    if c in p['skin'].values() or c in (EYE_D, EYE_P, BLUSH, BLUSH_D):
        return 'skin'
    if c in p['sock'].values():
        return 'sock'
    if c in p['shoe'].values():
        return 'shoe'
    if c in ACC:
        return 'skin'
    return None


def inset(mask):
    """실루엣 안쪽으로 몇 칸 들어왔는지 (체비쇼프 거리)."""
    INF = 99
    d = [[0 if (x, y) not in mask else INF for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if d[y][x]:
                for a, b in ((x - 1, y), (x, y - 1), (x - 1, y - 1), (x + 1, y - 1)):
                    if 0 <= a < W and 0 <= b < H:
                        d[y][x] = min(d[y][x], d[b][a] + 1)
                    else:
                        d[y][x] = min(d[y][x], 1)
    for y in range(H - 1, -1, -1):
        for x in range(W - 1, -1, -1):
            if d[y][x]:
                for a, b in ((x + 1, y), (x, y + 1), (x + 1, y + 1), (x - 1, y + 1)):
                    if 0 <= a < W and 0 <= b < H:
                        d[y][x] = min(d[y][x], d[b][a] + 1)
                    else:
                        d[y][x] = min(d[y][x], 1)
    return d


def _n(v):
    m = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / m for c in v)


LV = _n(LIGHT)
FEAT = {EYE_D, EYE_P, BLUSH, BLUSH_D} | ACC


def build(kind):
    """앞모습을 부풀려 덩어리를 만든다."""
    im = Image.open(os.path.join(HERE, '%s.png' % kind)).convert('RGBA')
    px = im.load()
    src = {(x, y): px[x, y][:3] for y in range(H) for x in range(W) if px[x, y][3]}
    dist = inset(set(src))

    hx = [x for (x, y) in src if y <= 19]
    hy = [y for (x, y) in src if y <= 19]
    HCX, HRX = (min(hx) + max(hx)) / 2.0, (max(hx) - min(hx)) / 2.0 + 0.5
    HCY, HRY = (min(hy) + max(hy)) / 2.0, ((max(hy) - min(hy)) / 2.0 + 0.5) * 1.3
    HZ = HRX * 0.88

    runs = {}                                   # 줄마다 이어진 토막 — 토막이 곧 단면이다
    for y in range(H):
        xs = sorted(x for (x, yy) in src if yy == y)
        cur = []
        for x in xs:
            if cur and x == cur[-1] + 1:
                cur.append(x)
            else:
                if cur:
                    runs.setdefault(y, []).append(cur)
                cur = [x]
        if cur:
            runs.setdefault(y, []).append(cur)

    def half(x, y, mat):
        """그 칸의 반두께. 머리는 타원체, 나머지는 줄마다 타원."""
        if y <= 19:
            q = 1 - ((x - HCX) / HRX) ** 2 - ((y - HCY) / HRY) ** 2
            return max(0.6, HZ * math.sqrt(max(0.0, q)))
        for r in runs.get(y, ()):
            if r[0] <= x <= r[-1]:
                cx, a = (r[0] + r[-1]) / 2.0, (r[-1] - r[0]) / 2.0 + 0.5
                B = min(a, THICK[mat.split('.')[-1]])
                return max(0.6, B * math.sqrt(max(0.0, 1 - ((x - cx) / a) ** 2)))
        return 0.6

    fy = sorted({y for (x, y), c in src.items()
                 if y <= 19 and abs(x - 16) <= 3 and mat_of(kind, c) == 'skin'})
    FACE_Y0, FACE_Y1 = (fy[0], fy[-1]) if fy else (13, 19)

    vox, feat = {}, {}
    for (x, y), c in src.items():
        mat = mat_of(kind, c)
        if mat is None:
            continue
        h = half(x, y, mat)
        zc = ZC - 2 if mat == 'shoe' else ZC
        if 22 <= y <= 35:
            r = next((r for r in runs.get(y, ()) if r[0] <= x <= r[-1]), None)
            if r and min(x - r[0], r[-1] - x) <= 2 and len(r) >= 8:
                zc -= 1.6                       # 팔은 몸통보다 앞
        z0, z1 = int(round(zc - h)), int(round(zc + h))
        for z in range(max(0, z0), min(D, z1 + 1)):
            vox[(x, y, z)] = mat
        if c in FEAT:
            feat[(x, y)] = c
        if y <= HEAD_BOT:
            # 앞모습에는 뒤통수도 옆통수도 없다. 머리는 3차원으로 가른다 —
            # 앞쪽 아래(얼굴 창)만 살결이고 나머지는 전부 머리카락이다.
            for z in range(max(0, z0), min(D, z1 + 1)):
                face = (z < ZC - 2 and FACE_Y0 <= y <= FACE_Y1)
                vox[(x, y, z)] = 'skin' if face else '%s.hair' % kind
            if mat == 'skin' and z0 <= ZC - 3:
                vox[(x, y, max(0, z0))] = 'skin'

    if kind == 'girl':                          # 등을 덮는 긴 머리
        for y in range(19, 40):
            xs = [x for (x, yy) in src if yy == y]
            if not xs:
                continue
            a = (max(xs) - min(xs)) / 2.0 + 0.5
            cx = (max(xs) + min(xs)) / 2.0
            t = 1.0 if y < 36 else (40 - y) / 4.0          # 끝을 가늘게
            a *= 0.78                                      # 등에 붙인다
            for x in range(W):
                for z in range(ZC, D):
                    if ((x - cx) / a) ** 2 + ((z - (ZC + 3.5)) / (3.0 * t)) ** 2 <= 1.0:
                        vox[(x, y, z)] = 'girl.hair'
    return vox, feat, src


BALL = [(a, b, cc) for a in range(-2, 3) for b in range(-2, 3) for cc in range(-2, 3)
        if 0 < a * a + b * b + cc * cc <= 5]


def shade(vox, c, mat, view):
    """법선은 **넓게** 잰다. 이웃 여섯 칸만 보면 한 칸씩 단이 튀어 얼룩진다."""
    nx = ny = nz = 0.0
    for a, b, cc in BALL:
        if (c[0] + a, c[1] + b, c[2] + cc) not in vox:
            w = 1.0 / (a * a + b * b + cc * cc)
            nx += a * w; ny += b * w; nz += cc * w
    if abs(nx) + abs(ny) + abs(nz) < 1e-6:
        nx, ny, nz = {'down': (0, 0, -1), 'up': (0, 0, 1), 'side': (1, 0, 0)}[view]
    n = _n((nx, ny, nz))
    v = -(n[0] * LV[0] + n[1] * LV[1] + n[2] * LV[2])
    p = PAL[mat]
    return p['lit'] if v > 0.62 else (p['base'] if v > 0.08 else p['shade'])


def render(kind, view):
    vox, feat, src = build(kind)
    if view == 'down':
        g = [[None] * W for _ in range(H)]
        for (x, y), c in src.items():
            g[y][x] = c
        return g

    buf = {}
    for c, mat in vox.items():
        x, y, z = c
        sx, dep = (-x, D - 1 - z) if view == 'up' else (-z, -x)
        k = (sx, y)
        if k not in buf or dep < buf[k][0]:
            buf[k] = (dep, c, mat)

    xs = [k[0] for k in buf]
    off = 16 - (min(xs) + max(xs)) // 2
    g = [[None] * W for _ in range(H)]
    mt = [[None] * W for _ in range(H)]
    for (sx, y), (_, c, mat) in buf.items():
        X = sx + off
        if not (0 <= X < W and 0 <= y < H):
            continue
        col = feat.get((c[0], c[1])) if mat == 'skin' else None
        g[y][X] = col or shade(vox, c, mat, view)
        mt[y][X] = mat
    if view == 'side':
        face_rows = [y for y in range(H) if any(
            mt[y][x] == 'skin' for x in range(W))and y < 22]
        if face_rows:
            ey = min(face_rows) + 2
            for y in (ey, ey + 1, ey + 2):
                sk = [x for x in range(W) if mt[y][x] == 'skin']
                if len(sk) < 2:
                    continue
                a, b = sk[-2], sk[-1]
                if y == ey:
                    g[y][a] = g[y][b] = EYE_D
                else:
                    g[y][a], g[y][b] = EYE_P, (255, 244, 223)
            by = ey + 3
            sk = [x for x in range(W) if mt[by][x] == 'skin']
            if len(sk) >= 2:
                g[by][sk[-2]], g[by][sk[-1]] = BLUSH_D, BLUSH

    for y in range(H):
        for x in range(W):
            if g[y][x] is None or g[y][x] in FEAT:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = x + dx, y + dy
                if not (0 <= a < W and 0 <= b < H) or g[b][a] is None:
                    g[y][x] = PAL[mt[y][x]]['dark']
                    break
    return g


def img(g):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    p = im.load()
    for y in range(H):
        for x in range(W):
            if g[y][x]:
                p[x, y] = g[y][x] + (255,)
    return im


if __name__ == '__main__':
    for k in ('boy', 'girl'):
        for v in ('down', 'side', 'up'):
            img(render(k, v)).save(os.path.join(HERE, 'vox_%s_%s.png' % (k, v)))
    print('덩어리에서 세 방향 뽑음')
