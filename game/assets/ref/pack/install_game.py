#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""팩에 받아 둔 새 캐릭터를 게임 스프라이트 자리에 앉힌다.

pack/{boy,girl}_{down,side,up}[_walk_0..3].png  ->
assets/sprites/{new_boy,player_f}_{방향}_{idle|walk_N}.png

눈 감은 장(blink)은 서기 장에서 만든다. 게임은 가만히 서 있을 때 3.7초마다
`pc_<방향>_blink` 를 한 번 꺼내 쓰므로 이 장이 없으면 그 순간 주인공이
사라진다 (player.gd).

`--write` 없이 부르면 무엇을 하려는지 적어만 보고 파일은 건드리지 않는다.
"""
import colorsys
import os
import shutil
import sys
from collections import Counter, deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.abspath(os.path.join(HERE, '..', '..', 'sprites'))
PAIR = [('boy', 'new_boy'), ('girl', 'player_f')]
DIRS = ['down', 'side', 'up']
WALK = 4

# 눈자리를 손으로 짚어 준 장. 여자는 눈이 커서 얼굴 테두리에 닿는 바람에
# 「살결에 둘러싸인 구멍」으로 안 잡힌다.  (x0, y0, x1, y1)
EYES = {
    ('girl', 'down'): [(10, 18, 13, 20), (18, 18, 21, 20)],
    ('girl', 'side'): [(19, 18, 21, 20)],
}


def is_skin(c):
    h, s, v = colorsys.rgb_to_hsv(*[x / 255.0 for x in c])
    return v >= 0.80 and s <= 0.62 and (h <= 0.10 or h >= 0.95)


def face_holes(px, W, H):
    """살결 덩이 안에 갇힌 칸들 — 남자는 이것이 곧 두 눈이다."""
    skin = {(x, y) for y in range(H) for x in range(W)
            if px[x, y][3] and is_skin(px[x, y][:3])}
    seen, best = set(), []
    for p in skin:
        if p in seen:
            continue
        q, comp = deque([p]), []
        seen.add(p)
        while q:
            x, y = q.popleft()
            comp.append((x, y))
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in skin and n not in seen:
                    seen.add(n)
                    q.append(n)
        if len(comp) > len(best):
            best = comp
    xs = [p[0] for p in best]
    ys = [p[1] for p in best]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    face = set(best)
    box = {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}
    out = box - face
    q = deque(p for p in out if p[0] in (x0, x1) or p[1] in (y0, y1))
    reach = set(q)
    while q:
        x, y = q.popleft()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n in out and n not in reach:
                reach.add(n)
                q.append(n)
    return out - reach, face


def eye_groups(cells):
    """붙어 있는 칸끼리 묶는다 (눈 하나가 한 묶음)."""
    left, groups = set(cells), []
    while left:
        p = left.pop()
        q, g = deque([p]), [p]
        while q:
            x, y = q.popleft()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
                      (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)):
                if n in left:
                    left.discard(n)
                    g.append(n)
                    q.append(n)
        groups.append(g)
    return groups


def make_blink(src, who, dirn):
    """눈을 감긴다 — 눈자리를 살결로 덮고 아래쪽에 속눈썹 한 줄을 긋는다."""
    im = Image.open(src).convert('RGBA')
    px = im.load()
    W, H = im.size
    holes, face = face_holes(px, W, H)
    if (who, dirn) in EYES:
        cells = [(x, y) for (x0, y0, x1, y1) in EYES[(who, dirn)]
                 for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
                 if px[x, y][3]]
    else:
        cells = sorted(holes)
    if not cells:
        raise SystemExit('%s: 눈을 못 찾았다' % src)
    # 덮을 살결 = 얼굴에서 제일 흔한 색
    fill = Counter(px[x, y][:3] for (x, y) in face).most_common(1)[0][0]
    for g in eye_groups(cells):
        dark = min((px[x, y][:3] for (x, y) in g), key=lambda c: sum(c))
        ymax = max(y for _, y in g)
        ymin = min(y for _, y in g)
        lash = ymax - 1 if ymax - ymin >= 2 else ymax
        for (x, y) in g:
            px[x, y] = fill + (255,)
        for x in sorted({x for x, _ in g}):
            col = [y for xx, y in g if xx == x]
            if lash in col:
                px[x, lash] = dark + (255,)
    return im


def main():
    write = '--write' in sys.argv
    todo, gone = [], []
    for who, pre in PAIR:
        for d in DIRS:
            todo.append((os.path.join(HERE, '%s_%s.png' % (who, d)),
                         os.path.join(DEST, '%s_%s_idle.png' % (pre, d))))
            for i in range(WALK):
                todo.append((os.path.join(HERE, '%s_%s_walk_%d.png' % (who, d, i)),
                             os.path.join(DEST, '%s_%s_walk_%d.png' % (pre, d, i))))
        # 옛 그림체로 남아 있는 장들 — 놔두면 휘두를 때만 옛 얼굴로 바뀐다
        for d in DIRS:
            gone.append(os.path.join(DEST, '%s_%s_walk_4.png' % (pre, d)))
            for i in range(5):
                gone.append(os.path.join(DEST, '%s_%s_swing_%d.png' % (pre, d, i)))
    # 그림이 둘뿐이라 머리 스타일 넷은 못 채운다 — 안 쓰는 두 벌을 걷는다
    for pre in ('hair_short', 'hair_spiky'):
        for f in sorted(os.listdir(DEST)):
            if f.startswith(pre + '_') and f.endswith('.png'):
                gone.append(os.path.join(DEST, f))

    for src, dst in todo:
        assert os.path.exists(src), src
        print('  넣기 %-44s <- %s' % (os.path.basename(dst), os.path.basename(src)))
        if write:
            shutil.copyfile(src, dst)
    for who, pre in PAIR:
        for d in ('down', 'side'):
            out = os.path.join(DEST, '%s_%s_blink.png' % (pre, d))
            print('  눈감기 %-42s <- %s_%s.png' % (os.path.basename(out), who, d))
            im = make_blink(os.path.join(HERE, '%s_%s.png' % (who, d)), who, d)
            if write:
                im.save(out)
    n = 0
    for f in gone:
        for p in (f, f + '.import'):
            if os.path.exists(p):
                n += 1
                if write:
                    os.remove(p)
    print('  걷어냄 %d개 (옛 그림체 휘두르기·다섯째 걷기 · 안 쓰는 머리 두 벌)' % n)
    print('%s' % ('썼다' if write else '적어만 봤다 — 정말 하려면 --write'))


main()
