#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""팩 앞모습에서 옆(3/4)·뒷모습을 만든다.

새로 그리지 않고 **앞모습을 변형**한다. 팩은 손으로 찍은 그림이라 같은 화풍을
다시 흉내 내면 반드시 어긋난다 — 실제 픽셀을 옮기면 눈·볼·옷주름·윤곽이
한 칸도 안 틀어진다.

  뒷모습: 얼굴 자리를 머리로 덮고, 깃·단추를 지우고, 목덜미와 뒷머리 결을 넣는다
  옆모습(3/4): 이목구비를 한 칸 오른쪽으로 밀고 먼 눈을 한 칸 눌러 좁힌다.
               몸통은 좌우 한 칸씩 줄이고 먼 팔을 한 단 어둡게 깐다.
               두 다리를 겹쳐 사이를 좁히고 앞발을 한 칸 내민다.
"""

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 48

P = {
    'boy': dict(
        hair=[(75, 57, 57), (112, 81, 74), (146, 112, 98), (179, 141, 116)],
        top=[(89, 133, 159), (54, 94, 122), (128, 167, 186), (36, 70, 88), (181, 205, 209)],
        bot=[(58, 57, 74), (44, 43, 58), (83, 86, 103), (31, 30, 42), (115, 125, 139)],
    ),
    'girl': dict(
        hair=[(55, 49, 70), (80, 70, 98), (107, 96, 131), (128, 117, 150), (150, 139, 172)],
        top=[(243, 236, 215), (222, 222, 206), (254, 247, 228), (172, 166, 154)],
        bot=[(70, 139, 140), (40, 102, 108), (116, 170, 170)],
    ),
}
SKIN = [(255, 227, 201), (255, 244, 223), (245, 201, 177), (191, 141, 131),
        (104, 71, 73), (234, 162, 162), (199, 97, 133)]
FACE = set(SKIN) | {(64, 37, 56), (152, 64, 100)}     # 살결 + 눈
SHOE = [(217, 223, 212), (200, 199, 188), (244, 247, 240), (64, 62, 78), (236, 240, 230)]
ACC = {(217, 183, 104), (168, 206, 212)}              # 단추 · 머리핀

HEAD_BOT = {'boy': 21, 'girl': 21}      # 목 아랫줄
NECK = {'boy': (104, 71, 73), 'girl': (104, 71, 73)}


def grid(im):
    px = im.load()
    return [[px[x, y][:3] if px[x, y][3] else None for x in range(W)] for y in range(H)]


def img(g):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            if g[y][x]:
                px[x, y] = g[y][x] + (255,)
    return im


# ----------------------------------------------------------------- 뒷모습
def build_back(g, kind):
    hair = P[kind]['hair']
    top = P[kind]['top']
    out = [row[:] for row in g]
    # 얼굴·눈·머리핀을 머리색으로 덮는다 (머리 영역 안에서만)
    for y in range(4, HEAD_BOT[kind]):
        for x in range(W):
            c = out[y][x]
            if c and (c in FACE or c in ACC):
                out[y][x] = hair[2] if kind == 'boy' else hair[2]
    # 덮은 자리 가장자리를 머리 윤곽으로 정리
    for y in range(4, HEAD_BOT[kind]):
        for x in range(W):
            if out[y][x] == hair[2]:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < W and 0 <= ny < H) or out[ny][nx] is None:
                        out[y][x] = hair[0]
                        break
    # 뒷머리 결 — 길이가 다른 두 가닥
    for x, y0, y1 in ((13, 8, 16), (19, 6, 12)):
        for y in range(y0, y1 + 1):
            if out[y][x] in (hair[2], hair[3]):
                out[y][x] = hair[1]
    # 목덜미 — 가운데 몇 칸만 (가로로 다 칠하면 목도리가 된다)
    ny = HEAD_BOT[kind]
    for x in range(W):
        if out[ny][x] and g[ny][x] in SKIN:     # 앞모습에서 살결이던 칸만
            out[ny][x] = NECK[kind]
    if kind == 'girl':
        # 긴 머리가 등을 덮는다 — 앞모습에서 어깨 양옆에 있던 머리를
        # 가운데까지 채운다. 안 그러면 뒤에서 블라우스가 다 보인다
        for y in range(21, 37):
            xs = [x for x in range(W) if out[y][x]]
            if not xs:
                continue
            l, r = xs[0], xs[-1]
            if out[y][l] not in hair or out[y][r] not in hair:
                continue
            for x in range(l + 1, r):
                if out[y][x] and out[y][x] not in hair:
                    out[y][x] = hair[2]
        for y in range(21, 37):                 # 덮은 자리에 결
            for x in (12, 20):
                if out[y][x] == hair[2]:
                    out[y][x] = hair[1]
        for x in range(W):                      # 아랫단
            if out[36][x] == hair[2]:
                out[36][x] = hair[0]
    return out


# ----------------------------------------------------------------- 옆(3/4)
# 머리는 **직접 찍는다.** 앞모습 픽셀을 밀어서 만들려니 눈이 실루엣 밖으로
# 밀려나고 머리가 이상하게 잘렸다. 팩의 색과 눈 구조(속눈썹 한 줄 · 흰자
# 한 칸 · 홍채 두 칸)는 그대로 쓰되 자리만 다시 잡았다.
#   먼 쪽(오른) 머리는 두 칸, 가까운(왼) 쪽은 다섯 칸 — 고개가 돌아간 만큼
#   뒤통수가 왼쪽으로 나온다. 가까운 눈 세 칸, 먼 눈 두 칸.
HEAD_SIDE = {}

HEAD_SIDE['boy'] = """\
...........AAAAAAAAA............
..........ABBCCDDDBBA...........
.........AACCDDDDDDBBA..........
.........ABDDDDDDDDDBAA.........
........ABDDDBBDDDDDDBA.........
........ABDDBBDDDDDDDBAA........
........ADDBBDDDDDDDDDBA........
........ABBDDDAAAABAAABA........
........ABBDDAEEEEAEEEBA........
........ABBDAEFFFEEFFEBA........
........ABBDAEGHHEEHGEBA........
........IABDAEGHHEEHGEBA........
........JABDAKKLLEELLKBA........
.........ABDAEEEEEEEEMM.........
..........ABDEEEEEEEMM..........
...........AMMMMMMMM............
.............JIIJ..............."""

HEAD_SIDE['girl'] = """\
............AAAAAAAAA...........
...........ABBBBBBBBBA..........
.........AABCDDDDDCCBBA.........
.........AABCCCCCCCCCBBA........
........AABCCCCCCCCCCCBA........
........AABCCCCCCCCCCCBA........
.......AABCCCCCCCCCCCCBA........
.......AABBCCCCAAABAAABA........
.......AABEBBBAFFFFAFFFBA.......
.......AABEABBAFGGGFFGGBA.......
.......AABEABBAFHIIFFIHBA.......
.......AABEABBAFHIIFFIHBJJK.....
.......AABEABBALLMMFFMLBA.......
.......AAAEABBANFFFFFFNBA.......
.......AEAEABBANNFFFFNNBA.......
.......AEAAABBENNNNNNEBAA.......
.......AEAABBBEEOPPOEEBAA......."""

LETTER = {
    'boy': dict(zip('ABCDEFGHIJKLM', [
        (75,57,57), (112,81,74), (179,141,116), (146,112,98), (255,227,201),
        (64,37,56), (255,244,223), (152,64,100), (245,201,177), (191,141,131),
        (234,162,162), (199,97,133), (104,71,73)])),
    'girl': dict(zip('ABCDEFGHIJKLMNOP', [
        (55,49,70), (107,96,131), (128,117,150), (150,139,172), (80,70,98),
        (255,227,201), (64,37,56), (255,244,223), (152,64,100), (168,206,212),
        (217,183,104), (234,162,162), (199,97,133), (104,71,73),
        (191,141,131), (245,201,177)])),
}


def side_feet(out, kind):
    """옆에서 본 신발. 고개를 돌렸으면 발도 돌아야 한다.

    앞모습 신발은 좌우 대칭 상자다 — 그걸 그대로 두면 몸만 돌고 발은 정면인
    꼴이 된다. 옆신발은 뒤꿈치가 왼쪽, 앞코가 오른쪽으로 길다.
    먼 발은 한 단 어둡게 깔고 뒤(오른쪽 위)에 둔다.
    발 중심은 앞모습과 같은 16.0 으로 맞춘다 — 안 맞으면 방향이 바뀔 때
    캐릭터가 한 칸 옆으로 튄다."""
    V, BASE, LIT, SOLE = SHOE[3], SHOE[0], SHOE[2], SHOE[1]

    for y in range(44, 48):
        for x in range(W):
            out[y][x] = None

    def shoe(x0, x1, ax0, ax1, base, lit, sole):
        for y in (44, 45):                      # 발목
            out[y][ax0] = V
            out[y][ax1] = V
            for x in range(ax0 + 1, ax1):
                out[y][x] = base
        out[46][x0] = V                          # 발등 — 앞코가 오른쪽으로
        out[46][x1] = V
        for x in range(x0 + 1, x1):
            out[46][x] = lit if x0 + 1 < x < x1 - 1 else base
        out[47][x0] = V                          # 밑창
        out[47][x1] = V
        for x in range(x0 + 1, x1):
            out[47][x] = sole

    # 발목은 다리 바로 밑에 (가까운 다리 x13~16, 먼 다리 x18~21)
    shoe(16, 22, 18, 21, SOLE, BASE, SOLE)       # 먼 발 — 한 단 어둡게, 뒤에
    shoe(10, 16, 12, 15, BASE, LIT, SOLE)        # 가까운 발 — 위에 덮는다
    # 가까운 발을 한 칸 왼쪽에 둬 두 발 중심이 앞모습과 같은 16.0 이 된다.
    # 안 맞으면 방향이 바뀔 때 캐릭터가 옆으로 튄다


def build_side(g, kind):
    """머리는 새로 찍고, 몸은 앞모습을 좁혀 쓴다."""
    hair = P[kind]['hair']
    top = P[kind]['top']
    bot = P[kind]['bot']
    out = [row[:] for row in g]

    # 1) 머리를 통째로 갈아 끼운다 (5줄부터 21줄까지)
    lut = LETTER[kind]
    rows = HEAD_SIDE[kind].split('\n')
    for y in range(5, 22):
        for x in range(W):
            out[y][x] = None
        r = rows[y - 5]
        for x, ch in enumerate(r[:W]):
            if ch != '.':
                out[y][x] = lut[ch]

    # 2) 몸통을 좌우 한 칸씩 줄이고 먼 팔·소매를 한 단 어둡게
    for y in range(22, 34):
        xs = [x for x in range(W) if out[y][x]]
        if len(xs) < 6:
            continue
        out[y][xs[0]] = None
        out[y][xs[-1]] = None
        xs = [x for x in range(W) if out[y][x]]
        for x in xs[-3:]:
            if out[y][x] == top[0]:
                out[y][x] = top[1]
            elif len(top) > 2 and out[y][x] == top[2]:
                out[y][x] = top[0]

    # 3) 두 다리 — 가까운(왼) 쪽을 한 칸 밀어 틈을 좁히고 먼 쪽을 어둡게.
    #    통째로 메우면 무릎도 발목도 없는 기둥이 된다
    for y in range(34, 48):
        row = out[y]
        xs = [x for x in range(W) if row[x]]
        if not xs:
            continue
        gaps = [x for x in range(xs[0], xs[-1]) if row[x] is None]
        if not gaps:
            continue
        g0 = gaps[0]
        # 다리는 밀지 않는다. 밀었더니 신발 자리와 겹쳐 두 다리가 하나로
        # 붙어 무릎도 발목도 없는 기둥이 됐다. 먼 쪽을 한 단 어둡게 까는
        # 것만으로 앞뒤가 갈린다
        for x in range(g0 + 1, xs[-1] + 1):
            c = out[y][x]
            if c == bot[0]:
                out[y][x] = bot[1]
            elif len(bot) > 2 and c == bot[2]:
                out[y][x] = bot[0]
            elif c == SHOE[0]:
                out[y][x] = SHOE[1]
            elif c == SHOE[2]:
                out[y][x] = SHOE[0]
    side_feet(out, kind)
    return out


def main():
    for kind in ('boy', 'girl'):
        g = grid(Image.open(os.path.join(HERE, '%s.png' % kind)).convert('RGBA'))
        img(g).save(os.path.join(HERE, '%s_down.png' % kind))
        img(build_side(g, kind)).save(os.path.join(HERE, '%s_side.png' % kind))
        img(build_back(g, kind)).save(os.path.join(HERE, '%s_up.png' % kind))
        print('%s: down · side · up' % kind)


if __name__ == '__main__':
    main()
