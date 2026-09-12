#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""팩의 재질끼리 겹친 색을 떼어낸다.

recolor_player_image() 는 정확한 RGB 치환이라, 한 색이 두 재질에 쓰이면
옷을 갈아입을 때 엉뚱한 데까지 같이 바뀐다. 실제로 겹친 곳:

  (255,244,223)  남자 얼굴 밝은면 · 남자 운동화 · 여자 블라우스 · 여자 신발
  ( 58, 57, 74)  남자 바지 · 남자 신발 윤곽 · 여자 신발 윤곽
  (217,223,212)  남자 운동화 · 여자 블라우스 · 여자 양말 윤곽
  (243,236,215)  여자 블라우스 · 여자 양말
  (181,205,209)  남자 스웨터 아주밝은면 · 여자 머리핀

겹친 쪽 중 **덜 중요한 재질**만 눈에 안 보일 만큼 옮긴다 (차이 3~10).
얼굴·스웨터·바지 같은 큰 면은 원본 값을 그대로 지킨다.
"""

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'packfix')
OUT = os.path.join(HERE, 'packpal')
os.makedirs(OUT, exist_ok=True)

# 새로 떼어낸 전용 색
SHOE_LIGHT = (244, 247, 240)     # 운동화 밝은면 (was 255,244,223 = 살결 밝은면)
SHOE_EDGE = (64, 62, 78)         # 신발 윤곽    (was 58,57,74 = 남자 바지)
SOCK = (236, 240, 230)           # 양말         (was 243,236,215 = 블라우스)
BL_LIGHT = (254, 247, 228)       # 블라우스 밝은면 (was 255,244,223)
BL_SHADE = (222, 222, 206)       # 블라우스 그늘   (was 217,223,212)
PIN = (168, 206, 212)            # 머리핀        (was 181,205,209 = 스웨터)


def repaint(im, rules):
    """rules: [(원래색, 새색, y0, y1)] — y 구간 안에서만 바꾼다."""
    px = im.load()
    W, H = im.size
    n = 0
    for old, new, y0, y1 in rules:
        for y in range(y0, y1 + 1):
            for x in range(W):
                if px[x, y][3] and px[x, y][:3] == old:
                    px[x, y] = new + (255,)
                    n += 1
    return n


BOY = [
    ((58, 57, 74), SHOE_EDGE, 44, 47),        # 신발 윤곽만 (바지는 43줄까지)
    ((255, 244, 223), SHOE_LIGHT, 44, 47),    # 운동화 갑피
]
GIRL = [
    ((58, 57, 74), SHOE_EDGE, 44, 47),
    ((255, 244, 223), SHOE_LIGHT, 44, 47),
    ((243, 236, 215), SOCK, 42, 43),          # 양말
    ((217, 223, 212), SOCK, 42, 43),
    ((255, 244, 223), BL_LIGHT, 20, 39),      # 블라우스
    ((217, 223, 212), BL_SHADE, 20, 39),
    ((181, 205, 209), PIN, 14, 18),           # 머리핀
]


def audit(paths):
    """색마다 어느 재질 구간에 나타나는지 세어 겹침을 잡는다."""
    ZONE = [(0, 21, '머리·얼굴'), (22, 33, '윗도리·팔'),
            (34, 41, '아랫도리·다리'), (42, 47, '양말·신발')]
    seen = {}
    for p in paths:
        im = Image.open(p).convert('RGBA')
        px = im.load()
        W, H = im.size
        for y in range(H):
            z = next(n for a, b, n in ZONE if a <= y <= b)
            for x in range(W):
                if px[x, y][3]:
                    seen.setdefault(px[x, y][:3], set()).add(z)
    bad = {c: z for c, z in seen.items() if len(z) > 1}
    # 살결은 얼굴·손·다리에 걸쳐 나오는 게 정상이다
    SKIN = {(255, 227, 201), (255, 244, 223), (245, 201, 177),
            (191, 141, 131), (104, 71, 73), (234, 162, 162), (199, 97, 133)}
    bad = {c: z for c, z in bad.items() if c not in SKIN}
    return bad


def main():
    outs = []
    for n, rules in (('boy', BOY), ('girl', GIRL)):
        im = Image.open(os.path.join(SRC, '%s.png' % n)).convert('RGBA')
        k = repaint(im, rules)
        p = os.path.join(OUT, '%s.png' % n)
        im.save(p)
        outs.append(p)
        print('%-6s %d칸 옮김' % (n, k))
    before = audit([os.path.join(SRC, '%s.png' % n) for n in ('boy', 'girl')])
    after = audit(outs)
    print('떼어내기 전 겹친 색 %d개:' % len(before))
    for c, z in sorted(before.items()):
        print('   ', c, sorted(z))
    print('떼어낸 뒤 겹친 색 %d개:' % len(after))
    for c, z in sorted(after.items()):
        print('   ', c, sorted(z))


if __name__ == '__main__':
    main()
