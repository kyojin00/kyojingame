#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""k192 — 192 x 288. h64 의 세 배. 「기엽게」에 맞춰 얼굴을 다시 설계했다.

해상도만으로는 안 기여워진다. 기여움을 만드는 건 비율이다.
  · 눈이 얼굴 폭의 1/3 씩 (지금까지는 1/5)
  · 홍채가 눈의 3/4, 동공이 그 절반, 반사점 두 개 (큰 것 · 작은 것)
  · 코는 두 칸, 입은 네 칸 — 작을수록 어려 보인다
  · 볼 홍조를 넓고 흐리게
192칸이면 이걸 다 넣을 자리가 나온다 (64칸에서는 눈이 5x5 였다).

게임 쪽: 스프라이트가 192x288 이 되므로 player.tscn 의 scale 을
0.5 -> 0.3333 으로 낮추면 월드 크기(64x96)가 그대로다.
다만 화면에서는 54x81 픽셀이라 실제로 눈에 들어오는 디테일은 64칸까지다 —
192칸은 nearest 로 3.5배 줄면서 계단이 떨릴 수 있다. 원본 보관용으로 두고
게임에는 줄여서 넣는 쪽이 안전하다.
"""

import math
import os
import importlib.util
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
_s = importlib.util.spec_from_file_location('h64', os.path.join(HERE, 'h64.py'))
H = importlib.util.module_from_spec(_s)
_s.loader.exec_module(H)
F = H.F

GW, GH = 192, 288
OW, OH = 192, 288
CHARS = F.CHARS
K = 3                       # h64(64x96) 대비 배율


def put(g, x, y, ch):
    if 0 <= x < GW and 0 <= y < GH:
        g[y][x] = ch


def hfill(g, y, x0, x1, ch):
    for x in range(max(0, x0), min(GW - 1, x1) + 1):
        put(g, x, y, ch)


def swap(g, x, y, frm, ch):
    if 0 <= x < GW and 0 <= y < GH and g[y][x] in frm:
        g[y][x] = ch


def disc(g, cx, cy, r, ch, only=None):
    """원 채우기 — 눈동자처럼 둥근 건 표로 못 적는다."""
    rr = r * r
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= rr:
                if only is None:
                    put(g, x, y, ch)
                else:
                    swap(g, x, y, only, ch)


def ellipse(g, cx, cy, rx, ry, ch, only=None):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / float(rx)) ** 2 + ((y - cy) / float(ry)) ** 2 <= 1.0:
                if only is None:
                    put(g, x, y, ch)
                else:
                    swap(g, x, y, only, ch)


def upscale(g64):
    g = [['.'] * GW for _ in range(GH)]
    for y in range(96):
        for x in range(64):
            c = g64[y][x]
            for dy in range(K):
                for dx in range(K):
                    g[y * K + dy][x * K + dx] = c
    return g


def runs(row):
    """한 줄에서 채워진 구간들. 다리 사이처럼 끊긴 데가 있으니 구간별로 본다."""
    out, s = [], None
    for x, c in enumerate(row):
        if c != '.' and s is None:
            s = x
        elif c == '.' and s is not None:
            out.append((s, x - 1))
            s = None
    if s is not None:
        out.append((s, len(row) - 1))
    return out


def resmooth(g, g32, K=6):
    """실루엣을 원본 32격자에서 6배로 **보간해** 다시 깎는다.

    그냥 6배로 키우면 턱이 여섯 칸짜리 계단이 된다 — 얼굴만 192칸
    정밀도고 몸은 32칸 그대로라 따로 논다. 32격자의 위아래 줄 끝을
    선형 보간해 줄마다 한 칸씩 흐르게 만들면 어깨·팔·장화·머리 곡선이
    해상도에 맞게 매끄러워진다. 구간이 갈라지는 줄(다리 사이가 생기는
    자리)은 짝이 안 맞으므로 건드리지 않는다."""
    for y in range(GH):
        t = (y + 0.5) / K - 0.5
        y0 = int(math.floor(t))
        f = t - y0
        y1 = y0 + 1
        if y0 < 0:
            y0 = y1 = 0
            f = 0.0
        if y1 > 47:
            y0 = y1 = 47
            f = 0.0
        r0, r1 = runs(g32[y0]), runs(g32[y1])
        if not r0 or len(r0) != len(r1):
            continue
        cur = runs(g[y])
        if len(cur) != len(r0):
            continue
        for (a0, b0), (a1, b1), (ca, cb) in zip(r0, r1, cur):
            ta = int(round((a0 + (a1 - a0) * f) * K))
            tb = int(round((b0 + (b1 - b0) * f + 1) * K)) - 1
            if tb - ta < 1:
                continue
            edgeL, edgeR = g[y][ca], g[y][cb]
            for x in range(ca, ta):
                g[y][x] = '.'
            for x in range(ta, ca):
                g[y][x] = edgeL
            for x in range(tb + 1, cb + 1):
                g[y][x] = '.'
            for x in range(cb + 1, tb + 1):
                g[y][x] = edgeR


def cute_eye(g, x0, w, y0, h, flip=False):
    """기여운 눈. 핵심은 **흰자를 적게** 두는 것이다 — 홍채가 눈의 대부분을
    채우고 위는 속눈썹이 잘라먹어야 한다. 흰자가 홍채를 빙 두르면
    놀란 눈·부엉이 눈이 되지 기여워지지 않는다."""
    cx, cy = x0 + w // 2, y0 + h // 2
    for y in range(y0, y0 + h):                      # 눈 구멍 (납작한 타원)
        dy = (y - cy) / (h / 2.0)
        if abs(dy) > 1:
            continue
        half = int((w / 2.0) * max(0.0, 1 - dy * dy) ** 0.5)
        hfill(g, y, cx - half, cx + half, 'W')
    # 홍채는 **원이 아니라 타원**으로 눈 폭을 거의 다 채운다. 원으로 두면
    # 좌우에 흰자가 초승달처럼 남아 부엉이 눈이 된다.
    # 홍채는 눈보다 **좁고 길다** — 위아래로 눈 구멍에 잘리고 좌우에만
    # 흰자가 남는다. 홍채를 눈과 같은 타원으로 두면 흰자가 빙 둘러
    # 유리구슬처럼 보인다.
    rx, ry = int(w * 0.42), int(h * 0.78)   # 좌우에 흰자가 뚜렷이 남아야
                                            # 감은 눈처럼 안 보인다
    icy = cy + int(h * 0.06)
    ellipse(g, cx, icy, rx, ry, 'b', only='W')
    ellipse(g, cx, icy + int(ry * 0.18), int(rx * 0.52), int(ry * 0.58),
            'e', only='bW')                          # 동공
    for i in range(3):                               # 속눈썹이 위를 자른다
        y = y0 + i
        dy = (y - cy) / (h / 2.0)
        half = int((w / 2.0) * max(0.0, 1 - dy * dy) ** 0.5)
        hfill(g, y, cx - half - 1, cx + half + 1, 'e')
    s = 1 if flip else -1
    disc(g, cx + s * int(rx * 0.38), icy - int(ry * 0.30),
         max(3, int(rx * 0.38)), 'W', only='be')     # 큰 반사점 — 바깥 위
    disc(g, cx - s * int(rx * 0.50), icy + int(ry * 0.40),
         max(1, int(rx * 0.22)), 'W', only='b')      # 작은 반사점 — 안쪽 아래
    for i in range(w):                               # 아래 눈꺼풀 한 줄
        swap(g, x0 + i, y0 + h - 1, 'Wb', 'k')
    # 눈썹 — 짧고 평평하게. 길고 두껍게 안쪽으로 기울이면 화난 얼굴이 된다
    for i in range(w - 8):
        dy = 0 if i < w - 12 else 1
        for k in range(3):
            swap(g, x0 + 4 + i, y0 - 11 + dy + k, 'slcSd', 'D')


def cute_face(g, cx, girl, q=False):
    ew, eh = 28, 26
    ey = 74
    l0 = cx - 38
    r0 = cx + 10 if not q else cx + 8
    rw = ew if not q else 22
    cute_eye(g, l0, ew, ey, eh)
    cute_eye(g, r0, rw, ey, eh, flip=True)
    nx = cx + (5 if q else 0)                        # 코 — 두 칸이면 충분하다
    hfill(g, ey + 32, nx - 1, nx, 'S')
    hfill(g, ey + 33, nx - 1, nx, 'S')
    mx = cx + (6 if q else 0)                        # 입 — 작고 단순하게
    hfill(g, ey + 43, mx - 5, mx + 4, 'k')
    hfill(g, ey + 44, mx - 6, mx + 5, 'm')
    hfill(g, ey + 45, mx - 5, mx + 4, 'm')
    hfill(g, ey + 46, mx - 4, mx + 3, 'c')
    for dy in range(9):              # 볼 — 눈 **아래**에 놓는다. 눈과 같은
        w = 12 - abs(dy - 4) * 2     # 줄에 두면 눈에 막혀 거의 안 보였다
        for i in range(w):
            swap(g, cx - 32 + i, ey + 28 + dy, 'slS', 'c')
            swap(g, cx + 32 - i, ey + 28 + dy, 'slS', 'c')
    for dy in range(4):                              # 이마 — 앞머리 그늘
        for x in range(cx - 30, cx + 31):
            swap(g, x, ey - 16 + dy, 's', 'l')
    for x in range(cx - 16, cx + 17):                # 턱 그늘
        swap(g, x, ey + 54, 's', 'S')
        swap(g, x, ey + 55, 's', 'S')


def build(kind, girl):
    g32 = {'down': (F.build_girl if girl else F.build_boy),
           'side': lambda: F.build_side(girl),
           'up': lambda: F.build_back(girl)}[kind]()
    g64 = H.build(kind, girl)
    g = upscale(g64)
    resmooth(g, g32, 6)
    if kind != 'up':
        cx = 96 if kind == 'down' else 102
        for y in range(58, 122):                  # 얼굴 부속을 지우고 다시
            for x in range(GW):
                if g[y][x] in 'eWbmD#':      # 32칸 시절 눈·입·눈썹·윤곽 흔적을
                    g[y][x] = 's'            # 싹 밀고 192칸으로 다시 그린다
        cute_face(g, cx, girl, q=(kind == 'side'))
    H.soften(g) if False else None
    return g


def outline_pass(g):
    todo = []
    for y in range(GH):
        for x in range(GW):
            if g[y][x] in '.#':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < GW and 0 <= ny < GH):
                    continue
                if g[ny][nx] == '.':
                    todo.append((x, y))
                    break
    for x, y in todo:
        vote = {}
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < GW and 0 <= ny < GH:
                e = F.EDGE.get(g[ny][nx])
                if e:
                    vote[e] = vote.get(e, 0) + 1
        g[y][x] = max(vote, key=vote.get) if vote else '#'


def render(g):
    outline_pass(g)
    im = Image.new('RGBA', (OW, OH), (0, 0, 0, 0))
    px = im.load()
    for y in range(GH):
        for x in range(GW):
            ch = g[y][x]
            if ch != '.':
                px[x, y - 1] = CHARS[ch] + (255,)
    return im


def main():
    for sex, girl in (('boy', False), ('girl', True)):
        for kind in ('down', 'side', 'up'):
            im = render(build(kind, girl))
            im.save(os.path.join(HERE, 'k192_%s_%s.png' % (sex, kind)))
            px = im.load()
            low = max(y for y in range(OH) for x in range(OW) if px[x, y][3])
            cols = {px[x, y][:3] for y in range(OH) for x in range(OW) if px[x, y][3]}
            off = [c for c in cols if c not in F.ALLOWED]
            print('%s_%s 발바닥 y=%d 색 %d종 표밖 %d' % (sex, kind, low, len(cols), len(off)))


if __name__ == '__main__':
    main()
