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
    """뒷모습. 뒤통수는 **통째로 다시 칠한다.**

    앞모습에서 얼굴만 머리색으로 덮었더니 이마 위 머리선(가장 어두운 단)이
    뒤통수 한가운데 가로 띠로 남았다 — 그게 눈에 띄던 「경계」다. 머리 영역을
    밑색으로 싹 밀고 위 테두리 밝은 띠 · 오른쪽 그늘 띠 · 결 두 가닥만
    다시 얹으면 이음매가 없다."""
    hair = P[kind]['hair']
    top = P[kind]['top']
    HD, HS, HB = hair[0], hair[1], hair[2]          # 가장어두운 · 그늘 · 밑색
    HL = hair[3] if len(hair) > 3 else hair[2]      # 밝은 단
    out = [row[:] for row in g]

    head = [(x, y) for y in range(4, HEAD_BOT[kind] + 1) for x in range(W)
            if out[y][x] is not None]
    for x, y in head:                                # 밑색으로 싹 민다
        out[y][x] = HB
    for x, y in head:                                # 실루엣만 가장 어두운 단
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < W and 0 <= ny < H) or out[ny][nx] is None:
                out[y][x] = HD
                break
    # 위 테두리를 따라 밝은 띠 — 칸마다 깊이를 달리해 자로 그은 자국을 피한다
    depth = (1, 2, 3, 3, 4, 4, 3, 3, 2, 3, 3, 2, 2, 1, 2, 1, 1)
    for i, x in enumerate(sorted({x for x, _ in head})):
        n = depth[i % len(depth)]
        k = 0
        for y in sorted(yy for xx, yy in head if xx == x):
            if out[y][x] == HB:
                out[y][x] = HL
                k += 1
                if k >= n:
                    break
    # 오른쪽 테두리를 따라 그늘 띠 두 칸
    for y in range(4, HEAD_BOT[kind] + 1):
        xs = sorted(xx for xx, yy in head if yy == y)
        k = 0
        for x in reversed(xs):
            if out[y][x] in (HB, HL):
                out[y][x] = HS
                k += 1
                if k >= 2:
                    break
    for x, y0, y1 in ((13, 7, 15), (19, 5, 11)):     # 결 두 가닥, 길이 다르게
        for y in range(y0, y1 + 1):
            if out[y][x] in (HB, HL):
                out[y][x] = HS
    ny = HEAD_BOT[kind]                              # 목덜미
    for x in range(W):
        if out[ny][x] and g[ny][x] in SKIN:
            out[ny][x] = NECK[kind]
    if kind == 'girl':
        for y in range(21, 37):                      # 긴 머리가 등을 덮는다
            xs = [x for x in range(W) if out[y][x]]
            if not xs:
                continue
            l, r = xs[0], xs[-1]
            if out[y][l] not in hair or out[y][r] not in hair:
                continue
            for x in range(l + 1, r):
                if out[y][x] and out[y][x] not in hair:
                    out[y][x] = HB
        for y in range(21, 37):
            for x in (12, 20):
                if out[y][x] == HB:
                    out[y][x] = HS
        for x in range(W):
            if out[36][x] == HB:
                out[36][x] = HD
    for y in range(22, 34):                          # 깃·단추를 지운다
        for x in range(W):
            c = out[y][x]
            if c in ACC:
                out[y][x] = top[0]
            elif len(top) > 2 and c == top[2] and 12 <= x <= 19:
                out[y][x] = top[0]
    for y in range(24, 32):                          # 등솔기
        if out[y][16] == top[0]:
            out[y][16] = top[1]
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

    def shoe(heel, toe, ax0, ax1, base, lit, sole):
        """오른쪽을 보는 신발. **좌우 대칭이면 방향이 없다.**
        뒤꿈치는 발목 바로 뒤에서 짧게 서고, 앞코는 발목보다 세 칸 더
        앞으로 낮게 뻗는다."""
        out[44][ax0] = V                         # 발목 — 뒤쪽에만
        out[44][ax1] = V
        for x in range(ax0 + 1, ax1):
            out[44][x] = base
        out[45][heel] = V                        # 뒤꿈치가 서는 줄
        for x in range(heel + 1, ax1):
            out[45][x] = base
        out[45][ax1] = V
        out[46][heel] = V                        # 발등 — 앞코까지 뻗는다
        for x in range(heel + 1, toe):
            out[46][x] = lit if x > heel + 1 else base
        out[46][toe] = V
        out[47][heel] = V                        # 밑창
        for x in range(heel + 1, toe):
            out[47][x] = sole
        out[47][toe] = V

    # 먼 다리를 한 칸 당겨 먼 발목과 잇는다 (x18~21 -> x17~20)
    for y in range(34, 44):
        row = out[y]
        xs = [x for x in range(W) if row[x]]
        if not xs:
            continue
        gaps = [x for x in range(xs[0], xs[-1]) if row[x] is None]
        if not gaps:
            continue
        far = [x for x in range(gaps[-1] + 1, xs[-1] + 1)]
        sh = row[:]
        for x in far:
            sh[x] = None
        for x in far:
            sh[x - 1] = row[x]
        out[y] = sh
    # 뒤꿈치 · 앞코 · 발목. 두 발 합쳐 x11~21 이라 중심이 앞모습과 같은 16.0
    # 가까운 발을 너무 길게 뽑으면 먼 발을 통째로 덮어 토막만 남는다.
    # 겹치는 구간을 두 칸으로 줄여 먼 발의 앞코 네 칸이 보이게 한다
    shoe(16, 21, 17, 20, SOLE, BASE, SOLE)       # 먼 발 — 한 단 어둡게, 뒤에
    shoe(11, 17, 12, 15, BASE, LIT, SOLE)        # 가까운 발 — 위에 덮는다


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
