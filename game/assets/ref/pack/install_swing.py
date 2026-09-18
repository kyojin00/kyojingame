#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""받아 온 휘두르기 열 장에서 다섯 장을 골라 팩 규격(48x48)으로 앉힌다.

게임의 휘두르기는 방향마다 다섯 위상이다 (player.gd SWING_FRAMES):
  0 감기 시작 · 1 다 감음(팔이 머리 위) · 2 휘두름 · 3 내리침(허리 굽힘) · 4 되돌아옴
생성기는 열 장을 주므로 어느 장이 어느 위상인지는 **사람이 시트를 보고**
고른다 (swing_src/sheet_*.png). 방향마다 순서가 조금씩 다르다.

판은 **48x48** 이다 — 서기·걷기의 32x48 보다 넓다. 팔을 옆으로 벌리거나
머리채가 퍼지는 장이 36~43칸이라 32칸 판에서는 팔이 잘려 나갔다. 게임은
그림 폭의 한가운데를 원점으로 잡으므로(player.gd _fit_offset) 폭이 달라도
된다. 세로는 그대로 48 — 발바닥 y=47 이 땅이다.

자리는 **장마다 발을 가운데(x=24)에** 둔다. 걷기(install_anim.py)는 발이
번갈아 나가니 몸통으로 묶어 맞췄지만, 휘두르기는 발이 박혀 있어야 하는
동작이다 — 생성기가 옆모습에서 몸을 앞으로 내딛게 그려도 발을 제자리에
돌려놓는다 (앞으로 쏠리는 무게는 게임이 SWING_SHIFT 로 따로 준다).
서기 그림도 발 기준으로 앉혔으니 휘두르기 첫 장과 서기가 튀지 않는다.
색은 손대지 않는다 (걷기와 같이 원본 색 그대로).

그리고 **주먹 자리**를 잰다. 게임은 도구 그림을 주먹에 얹으므로
(player.gd SWING_HAND_DOT) 장마다 주먹이 어디 있는지 알아야 한다.
살결 덩어리 중 얼굴(제일 큰 것)이 아닌 것들의 한가운데를 주먹으로 본다.
값은 게임 노드 좌표로 적어 준다 — 48x48 을 네 배로 키워 192x192 로 넣고
0.5 배·offset(-96,-188) 로 그리므로 칸 (x, y) 의 한가운데는
  node = (2x + 1 - 48, 2y - 93)
주먹이 안 보이는 장(뒷모습에서 몸에 가린 때)은 ? 로 남긴다 — 앞뒤 장에서
어림해 손으로 적는다.

쓰기: python3 install_swing.py <boy|girl> down=2,4,5,7,10 side=... up=... [--write]
"""
import colorsys
import math
import os
import sys
from collections import deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'swing_src')
W, H = 48, 48       # 휘두르기 판 (서기·걷기는 32x48)
N = 5


def is_skin(c):
    h, s, v = colorsys.rgb_to_hsv(*[x / 255.0 for x in c])
    return v >= 0.80 and s <= 0.62 and (h <= 0.10 or h >= 0.95)


def cells_of(path):
    """알파를 128 에서 자르고, 사람이 든 상자만 오려서 키가 47 을 넘으면 키로만 줄인다
    (ingest.py 와 같은 규칙 — 서기·걷기가 그렇게 들어갔다)."""
    im = Image.open(path).convert('RGBA')
    px = im.load()
    w, h = im.size
    on = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 128]
    x0, x1 = min(x for x, _ in on), max(x for x, _ in on)
    y0, y1 = min(y for _, y in on), max(y for _, y in on)
    ch = y1 - y0 + 1
    fit = min(1.0, (H - 1) / ch)
    im = im.crop((x0, y0, x1 + 1, y1 + 1))
    if fit < 1.0:
        im = im.resize((max(1, int((x1 - x0 + 1) * fit)), max(1, int(ch * fit))), Image.NEAREST)
    px = im.load()
    w, h = im.size
    return [(x, y, px[x, y][:3]) for y in range(h) for x in range(w) if px[x, y][3] > 128]


def foot_center(s):
    b = max(c[1] for c in s)
    fx = [c[0] for c in s if c[1] >= b - 1]
    return (min(fx) + max(fx)) / 2.0


def blobs(pts):
    pts = set(pts)
    out = []
    while pts:
        p = pts.pop()
        q, comp = deque([p]), [p]
        while q:
            x, y = q.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in pts:
                        pts.remove(n)
                        q.append(n)
                        comp.append(n)
        out.append(comp)
    return sorted(out, key=len, reverse=True)


def fist(g):
    """주먹 자리 (판 칸). 살결 덩어리 중 얼굴(제일 큰 것)이 아닌 것들의 한가운데.
    발치(y 44 아래)에서 시작하는 덩어리는 뺀다 — 여자 양말·신발이 흰색이라 살결로 잡힌다."""
    skin = [(x, y) for y in range(H) for x in range(W) if g[y][x] and is_skin(g[y][x])]
    bs = [b for b in blobs(skin) if min(y for _, y in b) < 44]
    if len(bs) < 2:
        return None
    hands = [p for b in bs[1:] if len(b) >= 2 for p in b]
    if not hands:
        return None
    return (sum(x for x, _ in hands) / len(hands), sum(y for _, y in hands) / len(hands))


def node_of(p):
    return (round(2 * p[0] + 1 - W), round(2 * p[1] - 93))


def one(kind, dirname, picks, write):
    folder = os.path.join(SRC, kind, dirname)
    sets = [cells_of(os.path.join(folder, 'f%d.png' % i)) for i in picks]
    print('\n%s %s  고른 장 %s' % (kind, dirname, picks))
    hands = []
    for i, s in enumerate(sets):
        # 장마다 발을 가운데, 발바닥을 맨 아래에. 몸을 앞으로 내딛어 판을 넘치면
        # (옆모습 내리침) 발을 조금 비켜서라도 팔이 잘리지 않게 한다
        dx = math.floor(W / 2 - foot_center(s) + 0.5)
        sx0, sx1 = min(c[0] for c in s), max(c[0] for c in s)
        if sx1 + dx > W - 1:
            dx = max(W - 1 - sx1, -sx0)
        elif sx0 + dx < 0:
            dx = min(-sx0, W - 1 - sx1)
        dy = 47 - max(c[1] for c in s)
        g = [[None] * W for _ in range(H)]
        lost = 0
        for x, y, c in s:
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H:
                g[ny][nx] = c
            else:
                lost += 1
        on = [(x, y) for y in range(H) for x in range(W) if g[y][x]]
        top = min(y for _, y in on)
        xs = [x for x, _ in on]
        f = fist(g)
        hands.append(f)
        print('   위상 %d (f%d)  색%3d  x %d~%d  머리끝 y=%d  발 %.1f  주먹 %s%s'
              % (i, picks[i], len({g[y][x] for x, y in on}), min(xs), max(xs), top,
                 foot_center(s) + dx,
                 '(%.1f, %.1f) -> node %s' % (f[0], f[1], node_of(f)) if f else '?',
                 '  ** 잘림 %d칸' % lost if lost else ''))
        if write:
            im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            px = im.load()
            for x, y in on:
                px[x, y] = g[y][x] + (255,)
            im.save(os.path.join(HERE, '%s_%s_swing_%d.png' % (kind, dirname, i)))
    print('  SWING_HAND_DOT 후보  "%s": [%s],' % (
        dirname, ', '.join('Vector2(%d, %d)' % node_of(f) if f else 'Vector2(?, ?)' for f in hands)))
    return hands


def preview(kind, rows):
    """방향마다 다섯 장을 4배로 늘어놓고 주먹 자리에 붉은 십자를 찍는다 — 눈으로 확인용."""
    S = 4
    out = Image.new('RGBA', (N * (W * S + 4), len(rows) * (H * S + 4)), (40, 40, 48, 255))
    for r, (dirname, hands) in enumerate(rows):
        for i in range(N):
            path = os.path.join(HERE, '%s_%s_swing_%d.png' % (kind, dirname, i))
            if not os.path.exists(path):
                continue
            big = Image.open(path).convert('RGBA').resize((W * S, H * S), Image.NEAREST)
            ox, oy = i * (W * S + 4), r * (H * S + 4)
            out.paste(big, (ox, oy), big)
            f = hands[i]
            if f:
                px = out.load()
                cx, cy = ox + int(f[0] * S + S / 2), oy + int(f[1] * S + S / 2)
                for k in range(-5, 6):
                    for q in ((cx + k, cy), (cx, cy + k)):
                        if 0 <= q[0] < out.size[0] and 0 <= q[1] < out.size[1]:
                            px[q] = (255, 40, 40, 255)
    out.save(os.path.join(HERE, 'preview_swing_%s.png' % kind))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    kind = args[0]
    rows = []
    for a in args[1:]:
        d, ids = a.split('=', 1)
        picks = [int(v) for v in ids.split(',')]
        if len(picks) != N:
            sys.exit('%s: 다섯 장을 골라야 한다 (%d장)' % (d, len(picks)))
        rows.append((d, one(kind, d, picks, '--write' in sys.argv)))
    if '--write' in sys.argv:
        preview(kind, rows)
        print('\n미리보기: preview_swing_%s.png' % kind)
    else:
        print('\n재보기만 했다. 넣으려면 --write')
