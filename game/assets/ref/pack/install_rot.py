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
    """얼굴(밝은 살결)이 그림의 어느 쪽에 쏠려 있는지. +면 오른쪽을 본다."""
    im = Image.open(path).convert('RGBA')
    px = im.load()
    w, h = im.size
    on = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 128]
    if not on:
        return 0, 0
    top = min(y for _, y in on)
    xs = [x for x, _ in on]
    cx = (min(xs) + max(xs)) / 2.0
    score = 0
    n = 0
    for x, y in on:
        if y > top + 20:                             # 머리통만 본다
            continue
        r, g, b, _ = px[x, y]
        if r > 200 and g > 170 and b > 140:          # 살결
            score += (1 if x > cx else -1)
            n += 1
    return score, n


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
    main(sys.argv[1], sys.argv[2], '--write' in sys.argv)
