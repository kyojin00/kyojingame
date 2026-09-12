#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""96x144 주인공 도트 검사기.  사용법:  python3 check96.py <PREFIX>"""
import sys, os
from PIL import Image

OW, OH = 96, 144
P = [(243,159,138),(250,192,170),(213,116,98),(235,128,114),(170,84,66),
     (184,99,83),(252,217,204),(118,72,40),(152,100,56),(86,52,30),(58,35,20),
     (195,165,140),(58,88,168),(38,58,120),(94,126,200),(27,41,84),(166,184,225),
     (134,88,46),(98,62,32),(158,108,58),(69,43,22),(202,174,147),
     (82,53,33),(56,37,25),(39,26,18),(26,20,28),(66,32,30),(136,70,42),(246,242,234)]
ALLOWED = set(P)


def check(path):
    msgs, ok = [], True
    if not os.path.exists(path):
        return False, ['%s 없음' % path]
    im = Image.open(path).convert('RGBA')
    if im.size != (OW, OH):
        return False, ['%s 크기 %s (기대 96x144)' % (path, im.size)]
    px = im.load()
    alphas, colors, low, minx, maxx = set(), {}, -1, OW, -1
    for y in range(OH):
        for x in range(OW):
            r, g, b, a = px[x, y]
            alphas.add(a)
            if a:
                low = max(low, y); minx = min(minx, x); maxx = max(maxx, x)
                colors[(r, g, b)] = colors.get((r, g, b), 0) + 1
    if alphas - {0, 255}:
        ok = False; msgs.append('알파가 0/255 가 아님: %s' % sorted(alphas)[:8])
    if low != OH - 2:
        ok = False; msgs.append('발바닥 y=%d (기대 %d)' % (low, OH - 2))
    cen = (minx + maxx) / 2.0
    if abs(cen - 47.5) > 0.5:
        ok = False; msgs.append('가로 중심 %.1f (기대 47.5)' % cen)
    off = [c for c in colors if c not in ALLOWED]
    if off:
        ok = False; msgs.append('팔레트 밖 색 %d종: %s' % (len(off), off[:6]))
    seen = [[False] * OW for _ in range(OH)]
    comps = []
    for y in range(OH):
        for x in range(OW):
            if px[x, y][3] and not seen[y][x]:
                st, n = [(x, y)], 0
                seen[y][x] = True
                while st:
                    cx, cy = st.pop(); n += 1
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        nx, ny = cx+dx, cy+dy
                        if 0 <= nx < OW and 0 <= ny < OH and not seen[ny][nx] and px[nx,ny][3]:
                            seen[ny][nx] = True; st.append((nx, ny))
                comps.append(n)
    if len(comps) != 1:
        ok = False; msgs.append('연결 요소 %d개 %s (기대 1개)' % (len(comps), sorted(comps, reverse=True)[:5]))
    msgs.append('색 %d종, 높이 %d, 폭 %d' % (len(colors), low - min(y for y in range(OH) for x in range(OW) if px[x,y][3]) + 1, maxx - minx + 1))
    return ok, msgs


def main():
    pre = sys.argv[1]
    allok = True
    for sex in ('boy', 'girl'):
        for kind in ('down', 'side', 'up'):
            p = '%s_%s_%s.png' % (pre, sex, kind)
            ok, msgs = check(p)
            allok = allok and ok
            print('%-28s %s  %s' % (os.path.basename(p), 'OK ' if ok else '실패', ' | '.join(msgs)))
    print('전체', 'OK' if allok else '실패')
    sys.exit(0 if allok else 1)


if __name__ == '__main__':
    main()
