#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""여덟 방향 중 게임이 쓰는 셋만 골라 팩 규격으로 넣는다.

게임은 앞(down)·옆(side)·뒤(up) 세 방향만 쓴다. 왼쪽은 옆을 뒤집어 그린다.
그래서 여덟 장 중 셋만 쓰면 되는데, **옆을 어느 쪽으로 고를지가 중요하다.**
지금 스프라이트는 전부 오른쪽을 보고 있다. 왼쪽 보는 걸 넣으면 게임에서
방향이 통째로 뒤집힌다 — 그래서 이름을 믿지 않고 얼굴이 어느 쪽에 있는지
직접 세서 고른다. (받아 본 세트는 이름이 실제와 뒤집혀 있었다.)

쓰기: python3 install_rot.py <여덟장이 든 폴더> <boy|girl> [--write]
      --write 없으면 재보기만 하고 파일을 안 건드린다.
"""

import os
import sys
import glob
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from ingest import ingest, W, H                      # noqa: E402

FRONT = ('south', 'front', 'down', 's')
BACK = ('north', 'back', 'up', 'n')
SIDES = ('east', 'west', 'side', 'left', 'right', 'e', 'w')


def face_side(path):
    """얼굴이 그림의 어느 쪽에 쏠려 있는지. +면 오른쪽을 본다."""
    n, sc = score_img(Image.open(path).convert('RGBA'))
    return sc, n


def slice_sheet(path):
    """한 장에 격자로 들어온 시트를 칸칸이 자른다.

    내려받기가 낱장이 아니라 3x3 시트 한 장으로 나온다(252x252 = 84x84 여덟 칸).
    칸 수를 세어 격자를 알아낸다 — 여덟 칸이 차는 나눗수가 정답이다."""
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    for n in range(2, 7):
        if w % n or h % n:
            continue
        cw, ch = w // n, h // n
        cells = []
        for r in range(n):
            for c in range(n):
                box = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
                px = box.load()
                if any(px[x, y][3] > 128 for y in range(ch) for x in range(cw)):
                    cells.append(box)
        if len(cells) == 8:
            print('시트 %dx%d → %d칸씩 %dx%d 격자, 그림 있는 칸 8개' % (w, h, cw, n, n))
            return cells
    print('격자를 못 찾았다 (%dx%d)' % (w, h))
    return []


def score_img(im):
    """머리통에서 살결이 몇 칸이고 어느 쪽에 쏠렸는지.

    두 가지를 조심해야 한다. 머리통 범위는 **캔버스가 아니라 사람 키**로
    재야 한다 — 여백이 넓은 시트에서는 캔버스 기준으로 자르면 몸까지 들어온다.
    그리고 흰 신발을 살결로 세면 안 된다. 살결은 따뜻해서 R 이 B 보다
    한참 높은데(54, 68), 신발과 셔츠는 거의 같다(4, 음수)."""
    px = im.load()
    w, h = im.size
    on = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 128]
    if not on:
        return 0, 0
    ys = [y for _, y in on]
    xs = [x for x, _ in on]
    top, tall = min(ys), max(ys) - min(ys) + 1
    cx = (min(xs) + max(xs)) / 2.0
    sc = n = 0
    for x, y in on:
        if y > top + tall * 0.42:                # 사람 키의 위 42% = 머리통
            continue
        r, g, b, _ = px[x, y]
        if r > 190 and r - b > 25:               # 따뜻한 밝은 색만 = 살결
            sc += (1 if x > cx else -1)
            n += 1
    return n, sc


def pick_sheet(path, kind, write):
    cells = slice_sheet(path)
    if not cells:
        return
    stat = [(i, ) + score_img(c) for i, c in enumerate(cells)]
    for i, n, sc in stat:
        print('  %d번  얼굴살 %3d  쏠림 %+4d' % (i, n, sc))
    # 정면은 **얼굴살이 제일 많은 칸이 아니다.** 3/4 로 돌린 얼굴이 정면보다
    # 살결을 더 많이 보일 때가 있다. 정면은 얼굴이 넉넉히 보이면서
    # **좌우로 안 쏠린** 칸이다.
    top_skin = max(s[1] for s in stat)
    cand = [s for s in stat if s[1] >= top_skin * 0.6]
    front = min(cand, key=lambda s: abs(s[2]))[0]
    back = min(stat, key=lambda s: s[1])[0]
    rest = [s for s in stat if s[0] not in (front, back) and s[1] >= 8]
    side = max(rest, key=lambda s: s[2])[0] if rest else None
    print('\n  앞 ← %d번 / 옆 ← %s번 / 뒤 ← %d번'
          % (front, side, back))
    if side is None:
        print('옆을 못 골랐다.')
        return
    tmp = os.path.join('/tmp', 'sheet_cells')
    os.makedirs(tmp, exist_ok=True)
    for tag, i in (('down', front), ('side', side), ('up', back)):
        src = os.path.join(tmp, '%s_%s.png' % (kind, tag))
        cells[i].save(src)
        if write:
            out = os.path.join(HERE, '%s_%s.png' % (kind, tag))
            ingest(src, kind, out)
            Image.open(out).resize((W * 4, H * 4), Image.NEAREST).save(
                os.path.join(HERE, '%s_%s_128.png' % (kind, tag)))
    if not write:
        print('\n재보기만 했다. 실제로 넣으려면 --write 를 붙인다.')


def pick(folder):
    files = {os.path.splitext(os.path.basename(f))[0].lower(): f
             for f in glob.glob(os.path.join(folder, '**', '*.png'), recursive=True)}
    front = next((v for k, v in files.items() if k in FRONT), None)
    back = next((v for k, v in files.items() if k in BACK), None)
    cand = [(k, v) for k, v in files.items()
            if k in SIDES or (k not in FRONT and k not in BACK and '-' not in k)]
    side, best = None, None
    for k, v in cand:
        sc, n = face_side(v)
        if n < 8:                                    # 얼굴이 거의 안 보이면 옆이 아니다
            continue
        if best is None or sc > best:
            side, best = v, sc
    return front, side, back, files


def main(folder, kind, write=False):
    front, side, back, files = pick(folder)
    print('찾은 장수 %d' % len(files))
    for tag, f in (('앞', front), ('옆', side), ('뒤', back)):
        print('  %s ← %s' % (tag, os.path.basename(f) if f else '**못 찾음**'))
    if not (front and side and back):
        print('\n이름을 못 알아봤다. 파일 이름을 south/east/north 로 바꾸거나'
              '\n직접 골라 ingest.py 로 하나씩 넣으면 된다.')
        return
    sc, n = face_side(side)
    print('  (옆은 얼굴 %d칸 중 오른쪽 쏠림 %+d — 오른쪽을 본다)' % (n, sc))
    if not write:
        print('\n재보기만 했다. 실제로 넣으려면 --write 를 붙인다.')
        return
    for tag, f in (('down', front), ('side', side), ('up', back)):
        out = os.path.join(HERE, '%s_%s.png' % (kind, tag))
        ingest(f, kind, out)
        Image.open(out).resize((W * 4, H * 4), Image.NEAREST).save(
            os.path.join(HERE, '%s_%s_128.png' % (kind, tag)))


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    target = sys.argv[1]
    if os.path.isdir(target):
        main(target, sys.argv[2], '--write' in sys.argv)
    else:
        pick_sheet(target, sys.argv[2], '--write' in sys.argv)
