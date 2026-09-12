#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리틀 루트 주인공 도트 — 96x144 청키 레트로.  방향 s = 두툼한 농부.
얼굴이 넓적하고 턱이 둥글다. 눈은 작지만 눈매가 굵고, 입이 크고, 코가 뚜렷하다.
옷은 작업복 — 깃·단추·주머니를 굵게."""
from PIL import Image

W, H = 96, 144

SK, SK_L, SK_D            = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD           = (82,53,33), (56,37,25), (39,26,18)
OL, EYE, BROW, WHT        = (26,20,28), (66,32,30), (136,70,42), (246,242,234)


class C(object):
    def __init__(self):
        self.p = {}

    def px(self, x, y, c):
        if c is not None and 0 <= x < W and 0 <= y < H:
            self.p[(int(x), int(y))] = c

    def row(self, y, x0, x1, c):
        if x1 < x0:
            return
        for x in range(int(x0), int(x1) + 1):
            self.px(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            self.row(y, x0, x1, c)

    def get(self, x, y):
        return self.p.get((int(x), int(y)))

    def has(self, x, y):
        return (int(x), int(y)) in self.p

    def repl(self, x, y, c):
        """이미 칠해진 칸만 덮어쓴다 (실루엣 밖으로 새지 않게)."""
        if (int(x), int(y)) in self.p:
            self.p[(int(x), int(y))] = c

    def rrect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.repl(x, y, c)


# ---------------------------------------------------------------- 머리 실루엣
# y=1..50 이 머리, y=51..56 이 목.  반폭 hw 이면 x0=48-hw, x1=47+hw.
HEAD_TOP, HEAD_BOT = 1, 50
NECK_TOP, NECK_BOT = 51, 56
NECK_HW = 8

_HW = {1: 11, 2: 14, 3: 16, 4: 17, 5: 18, 6: 19, 7: 19,
       43: 19, 44: 19, 45: 18, 46: 17, 47: 16, 48: 14, 49: 12, 50: 10}
for _y in range(8, 43):
    _HW[_y] = 20
EAR_TOP, EAR_BOT, EAR_HW = 29, 39, 22


def skull_span(y, view='down'):
    """(x0, x1) — 두개골 한 줄의 좌우 끝.  3/4 은 먼 쪽(오른쪽)이 눌린다."""
    hw = _HW[y]
    x0, x1 = 48 - hw, 47 + hw
    if view == 'side':
        if y >= 16:
            x0 -= 1; x1 -= 3
        elif y >= 10:
            x1 -= 2
        if y >= 43:                       # 턱이 돌아선 쪽으로 미끄러진다
            x0 += min(4, y - 42); x1 += min(2, y - 42)
    return x0, x1


# ---------------------------------------------------------------- 얼굴 부품
def draw_eye(c, x0, wid, ytop, flip=False):
    """굵은 눈매 + 홍채로 꽉 찬 눈.  흰자는 빛 오는 쪽 한 군데만."""
    x1 = x0 + wid - 1
    c.row(ytop,     x0 + 1, x1 - 1, EYE)  # 윗속눈썹 — 위는 둥글게
    c.row(ytop + 1, x0,     x1,     EYE)  # 굵은 눈매
    c.row(ytop + 2, x0, x1, SK_DD)        # 눈꼬리·눈앞은 살결 진한 단
    c.row(ytop + 2, x0 + 1, x1 - 1, EYE)
    c.row(ytop + 3, x0, x1, SK_DD)        # 눈꼬리 테를 두 줄로 (한 칸 점 금지)
    c.row(ytop + 3, x0 + 2, x1 - 2, EYE)  # 아래는 좁혀 눈알을 둥글게
    if flip:
        c.rect(x1 - 3, ytop + 2, x1 - 2, ytop + 3, WHT)
    else:
        c.rect(x0 + 2, ytop + 2, x0 + 3, ytop + 3, WHT)
    c.row(ytop + 4, x0 + 2, x1 - 2, SK_DD)   # 아랫눈꺼풀 — 검정 아님
    c.row(ytop + 5, x0 + 3, x1 - 3, SK_D)    # 눈 밑 그늘


def draw_brow(c, x0, wid, y, tilt=1):
    """굵고 진한 눈썹 세 줄.  바깥쪽 끝이 한 줄 처진다."""
    x1 = x0 + wid - 1
    c.row(y + 1, x0, x1, BROW)
    c.row(y + 2, x0, x1, BROW)
    if tilt > 0:
        c.row(y, x0 + 2, x1, BROW)
        c.row(y + 3, x0, x0 + 2, BROW)
    else:
        c.row(y, x0, x1 - 2, BROW)
        c.row(y + 3, x1 - 2, x1, BROW)


def draw_nose(c, x0, x1, ytop, side=0):
    """콧등 + 콧방울 + 콧구멍 + 그늘.  빛면과 그늘면이 맞붙어 하나로 읽힌다."""
    c.row(ytop - 1, x0 + 1, x1 - 1, SK_D)                 # 콧등
    c.row(ytop,     x0,     x1,     SK_D)
    c.row(ytop + 1, x0 - 1, x1 + 1, SK_D)                 # 콧방울
    c.rect(x0 - 1, ytop - 1, x0, ytop - 1, SK_L)          # 빛 받는 콧날
    c.rect(x0 - 2, ytop, x0 - 1, ytop, SK_L)
    c.rect(x0 - 3, ytop + 1, x0 - 2, ytop + 1, SK_L)
    c.row(ytop + 2, x0 - 1, x0, SK_M)                     # 콧구멍
    c.row(ytop + 2, x1, x1 + 1, SK_M)
    c.row(ytop + 2, x0 + 1, x1 - 1, SK_D)
    c.row(ytop + 3, x0, x1, SK_DD)                        # 코 밑 그늘
    if side:
        c.rect(x1 + 1, ytop - 1, x1 + 2, ytop + 1, SK_D)  # 먼 쪽 콧날
        c.rect(x0 - 3, ytop, x0 - 2, ytop + 1, SK_LL)
        c.rect(x0 - 1, ytop - 1, x0, ytop - 1, SK_LL)


def draw_mouth(c, x0, x1, ytop):
    """크게 웃는 입.  눈보다 넓다."""
    c.row(ytop,     x0, x0 + 1, SK_M)                 # 입꼬리 살짝 올림
    c.row(ytop,     x1 - 1, x1, SK_M)
    c.row(ytop + 1, x0, x1, EYE)                      # 윗입술선 (굵게)
    c.row(ytop + 2, x0, x0 + 1, EYE)
    c.row(ytop + 2, x1 - 1, x1, EYE)
    c.row(ytop + 2, x0 + 2, x1 - 2, WHT)              # 이
    c.row(ytop + 3, x0 + 1, x1 - 1, EYE)              # 아랫입술선
    c.row(ytop + 4, x0 + 2, x1 - 2, SK_M)             # 아랫입술
    c.row(ytop + 5, x0 + 3, x1 - 3, SK_D)             # 턱 앞 그늘


# ---------------------------------------------------------------- 머리 살결
def draw_head_base(c, view):
    for y in range(HEAD_TOP, HEAD_BOT + 1):
        x0, x1 = skull_span(y, view)
        c.row(y, x0, x1, SK)
    # 귀 — 얼굴에 붙인다 (몇 칸만 튀어나옴)
    if view == 'side':
        for y in range(EAR_TOP + 1, EAR_BOT + 2):
            c.row(y, 25, 27, SK)
        for y in range(EAR_TOP + 3, EAR_BOT):
            c.row(y, 25, 28, SK_D)
            c.row(y, 26, 27, SK_M)
    elif view == 'down':
        for y in range(EAR_TOP, EAR_BOT + 1):
            c.row(y, 26, 27, SK); c.row(y, 68, 69, SK)
        for y in range(EAR_TOP + 2, EAR_BOT - 1):
            c.row(y, 26, 29, SK_D); c.row(y, 27, 28, SK_M)
            c.row(y, 66, 69, SK_D); c.row(y, 67, 68, SK_M)
    # 목
    nsh = -2 if view == 'side' else 0          # 목은 턱보다 먼 쪽에
    for y in range(NECK_TOP, NECK_BOT + 1):
        c.row(y, 48 - NECK_HW + nsh, 47 + NECK_HW + nsh, SK)
    a0, b0 = 48 - NECK_HW + nsh, 47 + NECK_HW + nsh
    for i, y in enumerate((NECK_TOP, NECK_TOP + 1, NECK_TOP + 2)):
        c.row(y, a0, b0, SK_M if i < 2 else SK_D)
    c.rect(a0 + 4, NECK_TOP + 1, b0 - 4, NECK_TOP + 2, SK_D)   # 한가운데는 밝게
    c.rect(a0 + 5, NECK_TOP + 2, b0 - 5, NECK_TOP + 3, SK)
    # 재질 윤곽 — 살결 진한 단, 빛은 왼쪽 위
    for y in range(HEAD_TOP, NECK_BOT + 1):
        xs = [x for x in range(W) if c.has(x, y)]
        if not xs:
            continue
        a, b = min(xs), max(xs)
        if y <= HEAD_BOT:
            c.repl(a, y, SK_DD)
            c.repl(b, y, SK_DD)
            c.repl(b - 1, y, SK_DD if y > 40 else SK_D)
    for x in range(W):                          # 정수리 윤곽
        if c.has(x, HEAD_TOP):
            c.repl(x, HEAD_TOP, SK_DD)
    for x in range(W):                          # 턱 밑 윤곽
        if c.has(x, HEAD_BOT):
            c.repl(x, HEAD_BOT, SK_DD)
    # 넓은 왼쪽 이마·뺨 하이라이트
    hl = [(6, 34, 44), (7, 32, 46), (8, 31, 47), (9, 31, 46), (10, 31, 44),
          (11, 30, 41), (12, 30, 38), (13, 30, 36), (14, 30, 35)]
    if view == 'side':
        hl = [(y, a + 2, b + 2) for (y, a, b) in hl]
    for y, a, b in hl:
        c.rrect(a, y, b, y, SK_L)
    cheek_shadow(c, view)


def cheek_shadow(c, view, outer=0):
    """오른쪽 뺨 그늘 — 얼굴 곡선을 따라 들어온다."""
    for y in range(16, HEAD_BOT + 1):
        xs = [x for x in range(30, W) if c.has(x, y) and c.get(x, y) in
              (SK, SK_L, SK_LL, SK_CH, SK_D)]
        if not xs:
            continue
        b = max(xs)
        if EAR_TOP <= y <= EAR_BOT and view != 'side':
            b -= 3
        w = (3 if y < 38 else 4) if not outer else outer
        c.rrect(b - w, y, b, y, SK_D)


# ---------------------------------------------------------------- 얼굴 배치
FACE = {
    'down': dict(eyeL=(33, 9), eyeR=(54, 9), eyeY=26, browY=21,
                 nose=(46, 50), noseY=33, mouth=(42, 53), mouthY=39,
                 blushL=(30, 35), blushR=(60, 65), blushY=(35, 38), side=0),
    'side': dict(eyeL=(36, 9), eyeR=(55, 7), eyeY=26, browY=21,
                 nose=(50, 54), noseY=33, mouth=(45, 56), mouthY=39,
                 blushL=(30, 36), blushR=(58, 62), blushY=(35, 38), side=1),
}


def draw_face(c, view):
    f = FACE[view]
    for (bx0, bx1) in (f['blushL'], f['blushR']):     # 볼 홍조 — 넓고 계단지게
        by0, by1 = f['blushY']
        n = by1 - by0
        for i, y in enumerate(range(by0, by1 + 1)):
            k = min(i, n - i)
            c.rrect(bx0 + 1 - k, y, bx1 - 1 + k, y, SK_CH)
    cheek_shadow(c, view, outer=2)
    ex, ew = f['eyeL']
    draw_brow(c, ex - 1, ew + 2, f['browY'], tilt=1)
    draw_eye(c, ex, ew, f['eyeY'])
    ex, ew = f['eyeR']
    draw_brow(c, ex - 1, ew + 2, f['browY'], tilt=-1)
    draw_eye(c, ex, ew, f['eyeY'])
    nx0, nx1 = f['nose']
    draw_nose(c, nx0, nx1, f['noseY'], side=f['side'])
    mx0, mx1 = f['mouth']
    draw_mouth(c, mx0, mx1, f['mouthY'])


# ---------------------------------------------------------------- 머리카락
def _runs(rs):
    out = []
    for n, v in rs:
        out.extend([v] * n)
    assert len(out) == 40, len(out)
    return out


def _cols(rs):
    out = []
    for n, v in rs:
        out.extend([v] * n)
    assert len(out) == 40, len(out)
    return out


# 앞머리 밑선.  x=32..43 / 53..64 는 눈썹(y=22,23) 위에서 끝나야 한다.
FRINGE = {
 ('boy','down'): _cols([(2,29),(1,27),(1,24),(5,18),(5,16),(5,18),(5,15),
                        (5,17),(4,15),(3,18),(1,24),(1,27),(2,29)]),
 ('boy','side'): _cols([(2,29),(1,26),(1,23),(4,17),(5,15),(5,18),(5,16),
                        (5,18),(5,15),(3,21),(1,25),(1,27),(2,29)]),
 ('boy','up'):   _cols([(2,50),(1,49),(2,47),(5,44),(6,42),(8,41),(5,43),
                        (6,45),(2,47),(1,49),(2,50)]),
 ('girl','down'):_cols([(2,31),(1,29),(1,26),(5,18),(5,16),(6,19),(5,15),
                        (5,18),(5,16),(1,24),(1,28),(3,31)]),
 ('girl','side'):_cols([(2,31),(1,28),(1,25),(5,17),(6,15),(5,19),(6,15),
                        (5,18),(4,16),(1,25),(1,28),(3,31)]),
 ('girl','up'):  _cols([(40,50)]),
}


GIRL_L = [(20, 26, 27, 32), (27, 58, 26, 32), (59, 78, 26, 31),
          (79, 88, 27, 31), (89, 92, 28, 30)]
GIRL_R = [(22, 28, 63, 68), (29, 56, 63, 69), (57, 74, 64, 69),
          (75, 84, 64, 68), (85, 88, 65, 67)]
GIRL_RS = [(20, 26, 62, 67), (27, 62, 62, 68), (63, 80, 63, 68),
           (81, 88, 63, 67), (89, 92, 64, 66)]
GIRL_LS = [(20, 34, 25, 31), (35, 50, 25, 30), (51, 58, 26, 29),
           (59, 64, 27, 29)]


def _band(hair, bands):
    for y0, y1, a, b in bands:
        for y in range(y0, y1 + 1):
            for x in range(a, b + 1):
                hair.add((x, y))


def draw_hair(c, sex, view):
    bot = FRINGE[(sex, view)]
    hair, longh = set(), set()
    for y in range(HEAD_TOP, HEAD_BOT + 1):
        x0, x1 = skull_span(y, view)
        for x in range(x0, x1 + 1):
            if y <= bot[max(0, min(39, x - 28))]:
                hair.add((x, y))
    if view == 'side':
        for y in range(EAR_TOP - 2, EAR_TOP + 4):
            for x in (25, 26, 27):
                hair.add((x, y))
    if sex == 'girl':
        if view == 'up':
            _band(longh, [(51, 56, 35, 60), (57, 70, 34, 62), (71, 84, 35, 61),
                          (85, 90, 37, 59), (91, 93, 42, 54)])
        elif view == 'down':
            _band(longh, GIRL_L); _band(longh, GIRL_R)
        else:
            _band(longh, GIRL_LS); _band(longh, GIRL_RS)
    hair |= longh
    for (x, y) in hair:
        c.px(x, y, HR)
    # 그늘 — 빛은 왼쪽 위, 경계가 두개골 곡선을 따른다
    for (x, y) in hair:
        if (x, y) in longh and y > HEAD_BOT:
            if x >= 48:
                c.px(x, y, HR_D)
            continue
        d = ((x - 32) ** 2) * 1.0 + ((y - 4) ** 2) * 0.80
        if d > 26 ** 2:
            c.px(x, y, HR_D)
    # 긴 머리 왼쪽 결 (가르마·가닥) — 곧은 나뭇결 금지, 아래로 갈수록 안쪽
    if sex == 'girl' and view != 'up':
        for y in range(30, 101):
            xx = 29 - (y - 30) // 26
            for x in (xx, xx + 1):
                if (x, y) in hair and y % 17 > 2:
                    c.px(x, y, HR_L)
        for y in range(34, 100):
            xx = 66 + (y - 34) // 30
            for x in (xx, xx + 1):
                if (x, y) in hair and y % 19 > 3:
                    c.px(x, y, HR_DD)
    # 왼쪽 위 큰 하이라이트 (정수리 얼룩 금지 — 옆으로 흐르는 덩어리)
    if view != 'up':
        sw = [(4, 37, 48), (5, 34, 49), (6, 33, 48), (7, 32, 45), (8, 31, 42),
              (9, 31, 39), (10, 30, 37), (11, 30, 35), (12, 30, 34)]
    else:
        sw = [(5, 33, 45), (6, 32, 47), (7, 31, 46), (8, 30, 43), (9, 30, 40),
              (10, 29, 37), (11, 29, 35), (12, 29, 34), (13, 29, 33)]
    for y, a, b in sw:
        for x in range(a, b + 1):
            if (x, y) in hair:
                c.px(x, y, HR_L)
    for y, a, b in sw[:4]:                       # 가닥 윗결 — 떠 있는 얼룩 아님
        for x in range(a, min(b, a + 6) + 1):
            if (x, y) in hair:
                c.px(x, y, HR_LL)
    if view == 'up':                             # 뒤통수 가닥 갈림
        for i, (sx, sy, ex, ey) in enumerate(((42, 9, 34, 45), (56, 11, 61, 45))):
            n = ey - sy
            for k in range(n + 1):
                x = sx + (ex - sx) * k // n
                for xx in (x, x + 1):
                    if (xx, sy + k) in hair:
                        c.px(xx, sy + k, HR_DD if i else HR_D)
    # 재질 윤곽 — 머리 가장 어두운 단
    for (x, y) in hair:
        if (x - 1, y) not in hair or (x + 1, y) not in hair or \
           (x, y - 1) not in hair or (x, y + 1) not in hair:
            c.px(x, y, HR_DD)
    return hair



# ---------------------------------------------------------------- 몸
SHIRT_TOP, SHIRT_BOT = 57, 94


def torso_spans(view):
    s = {}
    if view == 'side':
        s[57] = (33, 63); s[58] = (31, 64); s[59] = (30, 65); s[60] = (29, 65)
        for y in range(61, 77):
            s[y] = (28, 65)
        for y in range(77, 88):
            s[y] = (29, 64)
        for y in range(88, 97):
            s[y] = (28, 65)
    else:
        s[57] = (31, 64); s[58] = (30, 65)
        for y in range(59, 77):
            s[y] = (29, 66)
        for y in range(77, 88):
            s[y] = (30, 65)
        for y in range(88, 97):
            s[y] = (29, 66)
    return s


def arm_cols(view):
    """(왼팔 소매, 오른팔 소매, 왼팔 살, 오른팔 살, 왼주먹, 오른주먹)"""
    if view == 'side':
        return (28, 36), (60, 65), (29, 36), (60, 64), (28, 36), (60, 65)
    return (29, 36), (59, 66), (30, 36), (59, 65), (29, 36), (59, 66)


def draw_body(c, sex, view):
    sp = torso_spans(view)
    for y in range(SHIRT_TOP, SHIRT_BOT + 1):
        a, b = sp[y]
        c.row(y, a, b, SH)
    # 윗도리 면 나누기 — 빛 왼쪽 위
    for y in range(SHIRT_TOP + 1, SHIRT_BOT + 1):
        a, b = sp[y]
        c.row(y, b - 4, b, SH_D)
    for y in range(60, 76):
        a, b = sp[y]
        c.row(y, a, a + 3, SH_L)
    for i, y in enumerate(range(59, 64)):          # 어깨 마루 — 빛 받는 면
        a, b = sp[y]
        c.row(y, a + i, a + 6, SH_LL)
        c.row(y, b - 6, b - i, SH_D)
    sl, sr, fl, fr, hl2, hr2 = arm_cols(view)
    if view == 'side':                         # 먼 팔은 어둡고 뒤에
        for y in range(59, 77):
            c.row(y, sr[0], sr[1], SH_D)
            c.row(y, sr[1] - 3, sr[1], SH_DD)
    # 겨드랑이 이음선 — 팔이 몸통에 붙어 보이지 않게
    for y in range(60, 77):
        c.row(y, sl[1], sl[1] + 1, SH_D)
        c.row(y, sr[0] - 1, sr[0], SH_DD)
    # 소매 끝 — 굵은 단
    for y in (75, 76):
        c.row(y, sl[0], sl[1], SH_DD)
        c.row(y, sr[0], sr[1], SH_DD)
    # 맨팔 + 주먹 — 가로 띠 금지, 손목은 폭이 좁아져서 드러난다
    for y in range(77, 89):
        c.row(y, fl[0], fl[1], SK)
        c.row(y, fr[0], fr[1], SK_D if view == 'side' else SK)
        c.row(y, fl[0], fl[0] + 1, SK_L)
        c.row(y, fr[1] - 1, fr[1], SK_D if view != 'side' else SK_M)
    draw_hands(c, view)


def draw_shirt_detail(c, sex, view):
    d = 3 if view == 'side' else 0           # 3/4 은 앞섶이 돌아선 쪽으로
    if view == 'up':
        for i, x in enumerate(range(32, 64)):          # 어깨 요크 — 가운데가 처진다
            k = 63 + (0 if i < 4 or i > 27 else (1 if i < 9 or i > 22 else 2))
            c.rect(x, k, x, k + 2, SH_DD)
            c.rect(x, k + 3, x, k + 4, SH_L)
        for y in range(70, 93):                        # 옆구리 면
            c.row(y, 29, 33, SH_D)
            c.row(y, 61, 66, SH_DD)
        for y in range(69, 93):                        # 등솔기
            c.row(y, 46, 48, SH_D)
        return

    # 굵은 깃
    lap = [(57, 35, 60, 41, 54), (58, 35, 41, 42, 53), (59, 36, 43, 44, 51),
           (60, 38, 45, 46, 49), (61, 40, 46, 0, 0), (62, 42, 47, 0, 0)]
    for y, a, b, sa, sb in lap:
        if y == 57:
            c.row(y, a + d, b + d, SH_LL)
        else:
            c.row(y, a + d, b + d, SH_LL)
            c.row(y, 95 - b + d, 95 - a + d, SH_LL)
        if sa:
            c.row(y, sa + d, sb + d, SK_M if y < 59 else SK_D)
    c.row(63, 44 + d, 51 + d, SH_LL)
    # 앞섶 + 굵은 단추
    c.rect(45 + d, 64, 50 + d, 91, SH_D)
    for by in (67, 74, 81, 88):
        c.rect(47 + d, by, 48 + d, by + 1, SH_LL)
    # 굵은 주머니 두 개 — 3/4 은 먼 쪽이 눌린다
    for px0, pw in ((38 + d, 7), (50 + d, 7 - 2 * (1 if d else 0))):
        c.rect(px0, 70, px0 + pw, 80, SH_DD)
        c.rect(px0 + 1, 73, px0 + pw - 1, 79, SH)
        c.rect(px0, 70, px0 + pw, 72, SH_LL)


def draw_legs(c, sex, view):
    if sex == 'boy':
        hip = (95, 102, 31, 64) if view != 'side' else (95, 102, 30, 63)
        a, b, u, v = hip
        for y in range(a, b + 1):
            c.row(y, u, v, PT)
        if view == 'side':
            L, R = (33, 46), (47, 60)
        else:
            L, R = (33, 46), (49, 62)
        for y in range(103, 125):
            c.row(y, L[0], L[1], PT)
            c.row(y, R[0], R[1], PT_D if view == 'side' else PT)
            c.row(y, R[1] - 3, R[1], PT_DD if view == 'side' else PT_D)
            c.row(y, L[0], L[0] + 2, PT_L)
            if view == 'side':
                c.row(y, L[1] - 1, L[1], PT_DD)
        # 굵은 허리띠
        for y in range(95, 98):
            c.row(y, u, v, PT_DD)
        if view == 'up':
            c.rect(38, 95, 40, 97, PT_L)      # 허리띠 고리
            c.rect(55, 95, 57, 97, PT_L)
        else:
            c.rect(45, 95, 50, 97, PT_LL)
            c.rect(46, 96, 49, 97, PT_D)
        # 바지 주머니
        c.rect(33, 100, 39, 101, PT_DD)
        c.rect(56, 100, 62, 101, PT_DD)
        # 장화
        if view == 'side':
            BL, BR = (32, 47), (48, 61)
        else:
            BL, BR = (31, 46), (49, 64)
        rt = 127 if view == 'side' else 125   # 먼 쪽 장화가 뒤에 (두 줄 위)
        for y in range(125, 143):
            c.row(y, BL[0], BL[1], SO)
            if view == 'side':
                c.row(y, BL[1] - 1, BL[1], SO_DD)
            if y >= rt:
                c.row(y, BR[0], BR[1], SO_D if view == 'side' else SO)
                c.row(y, BR[1] - 3, BR[1], SO_DD if view == 'side' else SO_D)
        for y in range(125, 129):            # 장화 목
            c.row(y, BL[0], BL[1], SO_D)
            if y >= rt:
                c.row(y, BR[0], BR[1], SO_DD if view == 'side' else SO_D)
        for y in range(140, 143):            # 창
            c.row(y, BL[0], BL[1], SO_DD)
            c.row(y, BR[0], BR[1], SO_DD)
    else:
        # 치마
        flare = [(95, 31, 64), (98, 31, 64), (101, 30, 65), (104, 29, 66),
                 (107, 28, 67), (110, 27, 68), (116, 27, 68)]
        for i in range(len(flare) - 1):
            y0, a0, b0 = flare[i]
            y1, a1, b1 = flare[i + 1]
            for y in range(y0, y1):
                t = float(y - y0) / max(1, (y1 - y0))
                c.row(y, int(round(a0 + (a1 - a0) * t)),
                      int(round(b0 + (b1 - b0) * t)), PT)
        c.row(116, 27, 68, PT)
        for y in range(95, 117):
            xs = [x for x in range(W) if c.get(x, y) == PT]
            if xs:
                c.row(y, max(xs) - 4, max(xs), PT_D)
                c.row(y, min(xs), min(xs) + 2, PT_L)
        for y in range(95, 98):
            c.row(y, 31, 64, PT_DD)
        c.rect(45, 95, 50, 97, PT_LL)
        for y in range(113, 117):            # 굵은 밑단
            xs = [x for x in range(W) if c.has(x, y) and c.get(x, y) in (PT, PT_D, PT_L)]
            if xs:
                c.row(y, min(xs), max(xs), PT_DD if y > 114 else PT_D)
        # 맨다리
        if view == 'side':
            L, R = (35, 44), (45, 53)
            SHL, SHR = (33, 45), (46, 57)
        else:
            L, R = (35, 43), (52, 60)
            SHL, SHR = (33, 45), (50, 62)
        rt = 137 if view == 'side' else 135
        for y in range(117, 138):
            c.row(y, L[0], L[1], SK)
            c.row(y, R[0], R[1], SK_D if view == 'side' else SK)
            c.row(y, R[1] - 2, R[1], SK_D)
            c.row(y, L[0], L[0] + 1, SK_L)
            if view == 'side':
                c.row(y, R[0], R[0] + 1, SK_M)      # 두 다리 사이 골
        for y in range(135, 143):            # 단화
            c.row(y, SHL[0], SHL[1], SO)
            if y >= rt:
                c.row(y, SHR[0], SHR[1], SO_D if view == 'side' else SO)
                c.row(y, SHR[1] - 3, SHR[1], SO_DD if view == 'side' else SO_D)
            if view == 'side':
                c.row(y, SHL[1] - 1, SHL[1], SO_DD)
        for y in range(140, 143):
            c.row(y, SHL[0], SHL[1], SO_DD)
            if y >= rt:
                c.row(y, SHR[0], SHR[1], SO_DD)


def draw_hands(c, view):
    _, _, _, _, hl2, hr2 = arm_cols(view)
    far = SK_D if view == 'side' else SK
    for y in range(89, 97):
        c.row(y, hl2[0], hl2[1], SK)
        c.row(y, hr2[0], hr2[1], far)
    c.rect(hl2[0], 89, hl2[0] + 1, 94, SK_L)          # 가까운 손 엄지쪽 빛
    c.rect(hl2[1] - 1, 89, hl2[1], 96, SK_D)
    c.rect(hr2[0], 89, hr2[0] + 1, 96, SK_D if view != 'side' else SK_M)
    c.rect(hr2[1] - 1, 89, hr2[1], 96, SK_M)
    for x in (hl2[0] + 3, hl2[0] + 4):                # 손가락 골 하나
        c.rect(x, 91, x, 96, SK_D)
    for x in (hr2[0] + 3, hr2[0] + 4):
        c.rect(x, 91, x, 96, SK_M)


DARKEN = {}
for _c in (SK, SK_L, SK_D, SK_CH, SK_M, SK_DD, SK_LL):
    DARKEN[_c] = SK_DD
for _c in (HR, HR_L, HR_D, HR_DD, HR_LL):
    DARKEN[_c] = HR_DD
for _c in (SH, SH_D, SH_L, SH_DD, SH_LL):
    DARKEN[_c] = SH_DD
for _c in (PT, PT_D, PT_L, PT_DD, PT_LL):
    DARKEN[_c] = PT_DD
for _c in (SO, SO_D, SO_DD):
    DARKEN[_c] = SO_DD


def outline(c):
    edge = []
    for (x, y), col in c.p.items():
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in c.p:
                edge.append((x, y, col))
                break
    for x, y, col in edge:
        d = DARKEN.get(col)
        if d:
            c.p[(x, y)] = d


def build(sex, view):
    c = C()
    draw_head_base(c, view)
    if view != 'up':
        draw_face(c, view)
    draw_body(c, sex, view)
    draw_legs(c, sex, view)
    draw_shirt_detail(c, sex, view)
    draw_hands(c, view)
    draw_hair(c, sex, view)
    if view == 'up':                       # 뒤통수 귀 — 머리카락 위에 얹는다
        for a, b in ((28, 31), (64, 67)):
            c.rect(a, 32, b, 39, SK)
            c.rect(a, 32, b, 33, SK_D)
            c.rect(a + 1, 35, b - 1, 38, SK_D)
            c.rect(a + 1, 36, b - 1, 37, SK_M)
        c.rect(64, 32, 67, 34, SK_D)
    outline(c)
    return c


def finish(c, path):
    xs = [x for (x, y) in c.p]
    ys = [y for (x, y) in c.p]
    lo, hi = min(xs), max(xs)
    dy = 142 - max(ys)
    dx = int(round(47.5 - (lo + hi) / 2.0))
    if abs((lo + hi + 2 * dx) / 2.0 - 47.5) > 0.5:
        dx += 1
    p = {}
    for (x, y), col in c.p.items():
        p[(x + dx, y + dy)] = col
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = im.load()
    for (x, y), col in p.items():
        if 0 <= x < W and 0 <= y < H:
            d[x, y] = (col[0], col[1], col[2], 255)
    im.save(path)
    # 자체 점검
    px = im.load()
    seen = set()
    comps = 0
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and (x, y) not in seen:
                comps += 1
                st = [(x, y)]
                seen.add((x, y))
                while st:
                    cx, cy = st.pop()
                    for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + ddx, cy + ddy
                        if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen \
                           and px[nx, ny][3]:
                            seen.add((nx, ny)); st.append((nx, ny))
    if comps != 1:
        print('  ! %s 연결요소 %d' % (path, comps))


def main():
    for sex in ('boy', 'girl'):
        for view in ('down', 'side', 'up'):
            finish(build(sex, view), 'w96_s_%s_%s.png' % (sex, view))
    print('w96_s 여섯 장 완료')


if __name__ == '__main__':
    main()
