#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""h64 — f32e 의 구조를 그대로 쓰되 64 x 96 격자에서 다듬은 판.

왜 64 x 96 인가 (10배가 아니라):
  뷰포트 960x540, 창 1440x810 (1.5배), 카메라 zoom 0.56, 스프라이트 scale 0.5.
  128px 스프라이트 -> 월드 64px -> 화면 64*0.56*1.5 = **54 x 81 실화면 픽셀**.
  지금은 32 x 48 칸이니 한 칸이 화면 1.7px — 즉 두 배까지는 눈에 보인다.
  64 x 96 이면 화면 픽셀과 거의 1:1 이라 딱 천장이다. 그보다 올리면
  (128칸이면 2.4배, 320칸이면 6배) nearest 로 줄어들면서 계단이 떨리기만
  하고 디테일은 화면에 못 올라온다. 그래서 64 x 96 x2 = 128 x 192 로 간다.

방법: f32e 격자를 2배로 키운 뒤
  1) 실루엣의 두 칸짜리 계단을 한 칸씩으로 깎아 곡선을 부드럽게 하고
  2) 눈·코·입·눈썹을 64칸 정밀도로 다시 그린다 (32칸에서는 눈이 3x3 이라
     흰자·홍채·동공을 다 넣을 수 없었다)
  3) 머릿결·옷주름을 한 칸 굵기로 다시 얹는다
출력 크기는 128 x 192 로 같아 게임 쪽은 손댈 게 없다.
"""

import os
import importlib.util
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('f32e', os.path.join(HERE, 'f32e.py'))
F = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(F)

GW, GH = 64, 96
S = 2
OW, OH = 128, 192
YSHIFT = -1
CHARS = F.CHARS
HAIRCH = F.HAIRCH
ALLOWED = F.ALLOWED


def put(g, x, y, ch):
    if 0 <= x < GW and 0 <= y < GH:
        g[y][x] = ch


def hfill(g, y, x0, x1, ch):
    for x in range(max(0, x0), min(GW - 1, x1) + 1):
        put(g, x, y, ch)


def swap(g, x, y, frm, ch):
    if 0 <= x < GW and 0 <= y < GH and g[y][x] in frm:
        g[y][x] = ch


def span(row):
    xs = [x for x in range(len(row)) if row[x] != '.']
    return (xs[0], xs[-1]) if xs else None


def upscale(g32):
    g = [['.'] * GW for _ in range(GH)]
    for y in range(48):
        for x in range(32):
            c = g32[y][x]
            g[y * 2][x * 2] = g[y * 2][x * 2 + 1] = c
            g[y * 2 + 1][x * 2] = g[y * 2 + 1][x * 2 + 1] = c
    return g


def smooth_edges(g, g32):
    """두 칸짜리 계단을 한 칸씩으로 깎는다.

    32칸 격자를 2배로 키우면 실루엣의 모든 턱이 두 칸이 되어 곡선이
    각져 보인다. 32칸에서 이웃한 두 줄의 끝을 보고 그 중간값을 홀수 줄에
    깔아 주면 턱이 한 칸씩으로 갈라져 곡선이 부드러워진다."""
    for y32 in range(47):
        a, b = span(g32[y32]), span(g32[y32 + 1])
        if not a or not b:
            continue
        for side in (0, 1):
            e0, e1 = a[side], b[side]
            if abs(e1 - e0) != 1:
                continue                    # 턱이 없거나 두 칸 이상이면 건드리지 않는다
            y = y32 * 2 + 1                 # 아래쪽 절반 줄만 손본다
            if e1 > e0:                     # 오른쪽으로 들어간다
                x = e0 * 2 + (0 if side == 0 else 1)
                if side == 0:
                    put(g, x, y, '.')
                else:
                    put(g, x, y, '.')
            else:                           # 왼쪽으로 들어간다
                x = e1 * 2 + (1 if side == 0 else 0)
                src = g[y][x + (1 if side == 0 else -1)]
                if g[y][x] == '.' and src != '.':
                    put(g, x, y, src)


def eye64(g, x, y, w, mirror=False, lash=True):
    """64칸 눈 — 눈썹 · 속눈썹 · 흰자 · 홍채 · 동공 · 반사점.
    32칸에서는 3x3 이라 홍채 한 덩어리가 전부였다."""
    hfill(g, y - 2, x, x + w - 1, 'D')              # 눈썹
    hfill(g, y, x, x + w - 1, 'e')                  # 속눈썹
    for dy in (1, 2, 3):
        hfill(g, y + dy, x, x + w - 1, 'W')         # 흰자
    ix = x + (1 if not mirror else w - 3)
    for dy in (1, 2, 3):
        hfill(g, y + dy, ix, ix + 1, 'b')           # 홍채
    put(g, ix, y + 2, 'e')                          # 동공
    put(g, ix + 1, y + 2, 'e')
    put(g, ix if not mirror else ix + 1, y + 1, 'W')  # 반사점
    hfill(g, y + 4, x + 1, x + w - 2, 'k')          # 아래 눈꺼풀
    if lash:
        put(g, x if not mirror else x + w - 1, y + 1, 'e')


def face64(g, cx, girl, q=False):
    """얼굴 부속을 64칸 정밀도로 다시 얹는다. cx 는 얼굴 중심."""
    ey = 25                                   # 눈 윗줄 (32칸 12줄 = 24줄)
    if q:
        # 3/4 — 가까운 눈은 다섯 칸, 먼 눈은 네 칸으로 눌린다
        eye64(g, cx - 9, ey, 5, lash=girl)
        eye64(g, cx + 3, ey, 4, mirror=True, lash=girl)
        hfill(g, ey + 7, cx + 5, cx + 6, 'S')       # 콧대
        put(g, cx + 5, ey + 8, 'S')
        hfill(g, ey + 11, cx - 1, cx + 2, 'm')      # 입
        hfill(g, ey + 12, cx, cx + 1, 'c')
        hfill(g, ey + 5, cx - 11, cx - 8, 'c')      # 볼 — 가까운 쪽이 넓다
        put(g, cx + 7, ey + 5, 'c')
    else:
        eye64(g, cx - 9, ey, 5, lash=girl)
        eye64(g, cx + 5, ey, 5, mirror=True, lash=girl)
        hfill(g, ey + 7, cx - 1, cx, 'S')           # 코 — 두 칸
        put(g, cx - 1, ey + 8, 'S')
        hfill(g, ey + 11, cx - 2, cx + 1, 'm')      # 입
        hfill(g, ey + 12, cx - 1, cx, 'c')          # 아랫입술
        hfill(g, ey + 5, cx - 12, cx - 9, 'c')      # 볼
        hfill(g, ey + 5, cx + 9, cx + 12, 'c')


def build(kind, girl):
    g32 = {'down': (F.build_girl if girl else F.build_boy),
           'side': lambda: F.build_side(girl),
           'up': lambda: F.build_back(girl)}[kind]()
    g = upscale(g32)
    smooth_edges(g, g32)
    if kind != 'up':
        # 얼굴 자리를 살결로 밀고 64칸으로 다시 그린다
        cx = 32 if kind == 'down' else 34
        for y in range(20, 40):
            for x in range(GW):
                if g[y][x] in 'eWbm':
                    g[y][x] = 's'
        face64(g, cx, girl, q=(kind == 'side'))
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
    small = Image.new('RGBA', (GW, GH), (0, 0, 0, 0))
    px = small.load()
    for y in range(GH):
        for x in range(GW):
            ch = g[y][x]
            if ch == '.':
                continue
            px[x, y] = CHARS[ch] + (255,)
    big = small.resize((GW * S, GH * S), Image.NEAREST)
    out = Image.new('RGBA', (OW, OH), (0, 0, 0, 0))
    out.paste(big, (0, YSHIFT))
    return out


def main():
    out = {}
    for sex, girl in (('boy', False), ('girl', True)):
        for kind in ('down', 'side', 'up'):
            out['%s_%s' % (sex, kind)] = render(build(kind, girl))
    for k, im in out.items():
        im.save(os.path.join(HERE, 'h64_%s.png' % k))
    ok = True
    for nm, im in sorted(out.items()):
        good, msgs = F.check(nm, im)
        ok = ok and good
        print(msgs[1], '|', msgs[3], '|', msgs[4])
    print('검사', 'OK' if ok else '실패')


if __name__ == '__main__':
    main()
