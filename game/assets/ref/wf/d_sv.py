#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""d_sv — 스타듀밸리풍 농사 게임 주인공 (64x96 에 찍어 x2 확대 -> 128x192)

화풍: 머리 큰 치비, 큰 눈, 멜빵바지/앞치마/밀짚모자.
윤곽은 검정이 아니라 각 재질의 가장 어두운 단(따뜻한 윤곽).
Pillow 만 사용. numpy 없음.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SW, SH = 64, 96            # 그리는 격자
DW, DH = 128, 192          # 내보내는 크기
XOFF, YOFF = 0, 1          # dest = src*2 + off  (발바닥 94 -> 189,190)
CX = 31.5                  # 좌우 대칭축 (src)

# ---------------------------------------------------------------- 팔레트
SKIN = [(243,159,138),(250,192,170),(213,116,98),(235,128,114),
        (170,84,66),(184,99,83),(252,217,204)]
S_BASE,S_LIT,S_SHA,S_CHK,S_MTH,S_DEEP,S_HI = range(7)
HAIR = [(118,72,40),(152,100,56),(86,52,30),(58,35,20),(195,165,140)]
H_BASE,H_LIT,H_SHA,H_DEEP,H_HI = range(5)
TOP  = [(58,88,168),(38,58,120),(94,126,200),(27,41,84),(166,184,225)]
T_BASE,T_SHA,T_LIT,T_DEEP,T_HI = range(5)
BOT  = [(134,88,46),(98,62,32),(158,108,58),(69,43,22),(202,174,147)]
B_BASE,B_SHA,B_LIT,B_DEEP,B_HI = range(5)
SHOE = [(82,53,33),(56,37,25),(39,26,18)]
EYE, BROW, WHITE = (66,32,30), (136,70,42), (246,242,234)

ALLOWED = set(SKIN)|set(HAIR)|set(TOP)|set(BOT)|set(SHOE)|{EYE,BROW,WHITE}

# 재질별 윤곽색 = 그 재질의 가장 어두운 단
OUT = {'skin':SKIN[S_MTH], 'hair':HAIR[H_DEEP], 'top':TOP[T_DEEP],
       'bot':BOT[B_DEEP], 'shoe':SHOE[2], 'eye':EYE}

# ---------------------------------------------------------------- 캔버스
class Cv(object):
    def __init__(self):
        self.c = [[None]*SW for _ in range(SH)]
        self.m = [[None]*SW for _ in range(SH)]

    def set(self, x, y, col, mat):
        if 0 <= x < SW and 0 <= y < SH:
            self.c[y][x] = col
            self.m[y][x] = mat

    def over(self, x, y, col, mat):
        """이미 뭔가 찍힌 자리에만 덧칠 (실루엣 밖으로 안 삐져나감)"""
        if 0 <= x < SW and 0 <= y < SH and self.m[y][x] is not None:
            self.c[y][x] = col
            self.m[y][x] = mat

    def mat(self, x, y):
        if 0 <= x < SW and 0 <= y < SH:
            return self.m[y][x]
        return None

    def hline(self, y, x0, x1, col, mat):
        for x in range(int(x0), int(x1)+1):
            self.set(x, y, col, mat)

    def hover(self, y, x0, x1, col, mat):
        for x in range(int(x0), int(x1)+1):
            self.over(x, y, col, mat)

    def vline(self, x, y0, y1, col, mat):
        for y in range(int(y0), int(y1)+1):
            self.set(x, y, col, mat)

    def rect(self, x0, y0, x1, y1, col, mat):
        for y in range(int(y0), int(y1)+1):
            self.hline(y, x0, x1, col, mat)

    def pat(self, x0, y0, rows, key):
        """문자 그림 찍기. key: 문자->(색,재질) / ' '와 '.'은 건너뜀"""
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch in ' .':
                    continue
                col, mat = key[ch]
                self.set(x0+i, y0+j, col, mat)


# ------------------------------------------------------- 실루엣 프로파일
def prof(anchors):
    """[(y,halfwidth)] 를 선형보간해 y->float 딕셔너리로"""
    out = {}
    for (y0, h0), (y1, h1) in zip(anchors, anchors[1:]):
        for y in range(y0, y1+1):
            t = 0.0 if y1 == y0 else (y-y0)/float(y1-y0)
            out[y] = h0 + (h1-h0)*t
    return out


def ints(p):
    """반폭을 정수로 굳히되, 이웃 줄과 1 칸 넘게 차이 안 나게 (계단 방지)"""
    ys = sorted(p)
    r = dict((y, int(round(p[y]))) for y in ys)
    top = max(range(len(ys)), key=lambda i: r[ys[i]])
    for i in range(top+1, len(ys)):
        a, b = r[ys[i-1]], r[ys[i]]
        r[ys[i]] = max(a-1, min(a+1, b))
    for i in range(top-1, -1, -1):
        a, b = r[ys[i+1]], r[ys[i]]
        r[ys[i]] = max(a-1, min(a+1, b))
    return r


def span(h):
    """반폭 h 에 대한 (좌, 우) 열. 대칭축 31.5"""
    return 32-h, 31+h


def fill(cv, p, col, mat):
    for y in sorted(p):
        l, r = span(p[y])
        cv.hline(y, l, r, col, mat)


# ---------------------------------------------------------------- 치수
Y_FACE_T   = 20
Y_CHIN     = 45
Y_NECK     = 44
Y_SHOULDER = 49
Y_WAIST    = 66
Y_SPLIT    = 74
Y_FOOT     = 94

FACE = ints(prof([(Y_FACE_T,10.0),(22,10.6),(25,11.3),(29,11.7),(35,11.7),
                  (39,11.2),(42,10.1),(44,8.6),(45,7.0)]))

HEAD_B = ints(prof([(10,4.6),(11,6.2),(12,7.6),(13,8.8),(14,9.8),(15,10.6),
                    (17,11.8),(20,12.8),(24,13.4),(28,13.3),(30,12.5),
                    (32,11.0),(33,9.4)]))
HEAD_G = ints(prof([(10,4.6),(11,6.2),(12,7.6),(13,8.8),(14,9.8),(15,10.6),
                    (17,11.8),(20,12.8),(24,13.4),(30,13.4),(34,13.0)]))


def head_prof(g):
    return HEAD_B if g == 'boy' else HEAD_G


# ---------------------------------------------------------------- 부위들
def draw_legs(cv, g):
    """엉덩이~다리~장화"""
    if g == 'boy':
        hip  = ints(prof([(Y_WAIST,10.4),(69,10.8),(72,10.6),(74,10.4)]))
        fill(cv, hip, BOT[B_BASE], 'bot')
        # 바지 가랑이 아래 두 갈래
        leg = ints(prof([(Y_SPLIT,10.4),(78,10.0),(85,9.6)]))
        gap = {}
        for y in sorted(leg):
            gap[y] = 2 if y < 78 else 3
        for y in sorted(leg):
            l, r = span(leg[y])
            gw = gap[y]
            cv.hline(y, l, 31-gw, BOT[B_BASE], 'bot')
            cv.hline(y, 32+gw, r, BOT[B_BASE], 'bot')
        # 장화
        boot = ints(prof([(86,10.0),(88,10.3),(91,10.5),(93,10.6),(94,10.6)]))
        for y in sorted(boot):
            l, r = span(boot[y])
            gw = 3 if y < 90 else 2
            cv.hline(y, l, 31-gw, SHOE[0], 'shoe')
            cv.hline(y, 32+gw, r, SHOE[0], 'shoe')
        # 장화 입구 띠
        for y in (86, 87):
            l, r = span(boot[y])
            cv.hover(y, l, 31-3, SHOE[1], 'shoe')
            cv.hover(y, 32+3, r, SHOE[1], 'shoe')
        # 바지 음영: 왼쪽 밝은면 / 오른쪽 그늘 / 바짓단
        for y in range(Y_WAIST, 86):
            xs = [x for x in range(SW) if cv.mat(x, y) == 'bot']
            if not xs:
                continue
            l, r = min(xs), max(xs)
            cv.hover(y, l, l+1, BOT[B_LIT], 'bot')
            cv.hover(y, r-2, r, BOT[B_SHA], 'bot')
        for y in (84, 85):
            cv.hover(y, 22, 41, BOT[B_SHA], 'bot')
        # 허리 이음선 + 주머니
        cv.hover(68, 22, 41, BOT[B_LIT], 'bot')
        cv.hover(69, 22, 41, BOT[B_SHA], 'bot')
        for y in range(71, 75):
            cv.over(25, y, BOT[B_SHA], 'bot')
            cv.over(38, y, BOT[B_SHA], 'bot')
        cv.hover(71, 23, 25, BOT[B_SHA], 'bot')
        cv.hover(71, 38, 40, BOT[B_SHA], 'bot')
    else:
        # 치마
        skirt = ints(prof([(63,10.2),(66,11.2),(70,12.6),(74,13.8),(77,14.2)]))
        fill(cv, skirt, BOT[B_BASE], 'bot')
        # 치마 음영과 밑단
        for y in sorted(skirt):
            l, r = span(skirt[y])
            cv.hover(y, l, l+1, BOT[B_LIT], 'bot')
            cv.hover(y, r-2, r, BOT[B_SHA], 'bot')
        for y in (76, 77):
            l, r = span(skirt[y])
            cv.hover(y, l, r, BOT[B_SHA], 'bot')
        # 맨다리
        legp = ints(prof([(78,9.0),(82,8.6),(86,8.4)]))
        for y in sorted(legp):
            l, r = span(legp[y])
            cv.hline(y, l, 31-2, SKIN[S_BASE], 'skin')
            cv.hline(y, 32+2, r, SKIN[S_BASE], 'skin')
        # 신발
        boot = ints(prof([(87,8.8),(89,9.4),(92,9.8),(94,9.8)]))
        for y in (87, 88):
            l, r = span(boot[y])
            cv.hline(y, l, 31-2, SHOE[1], 'shoe')
            cv.hline(y, 32+2, r, SHOE[1], 'shoe')
        for y in sorted(boot):
            l, r = span(boot[y])
            gw = 2
            cv.hline(y, l, 31-gw, SHOE[0], 'shoe')
            cv.hline(y, 32+gw, r, SHOE[0], 'shoe')


ARM = {'boy':  dict(out=19, inn=22, y0=56, sleeve=62, y1=71),
       'girl': dict(out=20, inn=23, y0=56, sleeve=60, y1=70)}


def draw_torso(cv, g):
    """어깨-팔을 하나의 실루엣으로 (90도로 꺾이지 않게)"""
    if g == 'boy':
        t = ints(prof([(Y_SHOULDER,5.0),(50,6.2),(51,7.5),(52,8.8),(53,10.0),
                       (54,11.0),(55,11.9),(56,12.5),(57,12.9),(58,13.0),
                       (62,13.0),(66,12.8)]))
    else:
        t = ints(prof([(Y_SHOULDER,4.8),(50,5.9),(51,7.0),(52,8.2),(53,9.3),
                       (54,10.2),(55,11.0),(56,11.6),(57,11.9),(58,12.0),
                       (61,12.0),(64,11.8)]))
    fill(cv, t, TOP[T_BASE], 'top')
    a = ARM[g]
    inn = a['inn']
    for y in sorted(t):
        l, r = span(t[y])
        cv.hover(y, max(l, inn+1), max(l, inn+1), TOP[T_LIT], 'top')
        cv.hover(y, max(l+1, 62-inn), min(r, 62-inn), TOP[T_SHA], 'top')
    # 깃
    cv.hover(52, 26, 37, TOP[T_SHA], 'top')
    cv.hover(51, 26, 27, TOP[T_SHA], 'top')
    cv.hover(51, 36, 37, TOP[T_SHA], 'top')
    return t


def draw_overall(cv, g, t):
    if g == 'boy':
        # 멜빵
        for x in (27, 28, 35, 36):
            cv.vline(x, 52, 58, BOT[B_BASE], 'bot')
        cv.vline(27, 52, 58, BOT[B_LIT], 'bot')
        cv.vline(36, 52, 58, BOT[B_SHA], 'bot')
        # 가슴판
        cv.rect(26, 58, 37, 67, BOT[B_BASE], 'bot')
        cv.vline(26, 58, 67, BOT[B_LIT], 'bot')
        cv.vline(37, 58, 67, BOT[B_SHA], 'bot')
        cv.hline(58, 26, 37, BOT[B_LIT], 'bot')
        # 단추
        for y in (59, 60):
            cv.hline(y, 28, 29, BOT[B_HI], 'bot')
            cv.hline(y, 34, 35, BOT[B_HI], 'bot')
    else:
        # 앞치마
        ap = ints(prof([(56,5.4),(62,5.4),(63,6.6),(64,7.6),(66,8.2),
                        (70,8.9),(74,9.4),(75,9.4),(76,8.6)]))
        for y in sorted(ap):
            l, r = span(ap[y])
            cv.hover(y, l, r, BOT[B_HI], 'bot')
        for y in sorted(ap):
            l, r = span(ap[y])
            cv.hover(y, r-1, r, BOT[B_LIT], 'bot')
        # 어깨끈
        for x in (27, 28, 35, 36):
            for y in range(52, 58):
                cv.over(x, y, BOT[B_HI], 'bot')
        cv.hover(57, 27, 36, BOT[B_LIT], 'bot')
        # 허리끈
        cv.hover(63, 24, 39, BOT[B_BASE], 'bot')
        cv.hover(64, 24, 39, BOT[B_SHA], 'bot')
        # 주머니
        for y in range(68, 72):
            cv.hover(y, 28, 35, BOT[B_LIT], 'bot')
        cv.hover(68, 28, 35, BOT[B_BASE], 'bot')


def draw_arms(cv, g):
    """팔: 소매(윗도리) + 맨팔뚝 + 주먹. 어깨에서 몸통과 이어져 있다."""
    a = ARM[g]
    out, inn, y0, sleeve, y1 = a['out'], a['inn'], a['y0'], a['sleeve'], a['y1']
    for y in range(y0, y1+1):
        if y <= sleeve:
            col, dark, lit, mat = TOP[T_BASE], TOP[T_DEEP], TOP[T_LIT], 'top'
        else:
            col, dark, lit, mat = SKIN[S_BASE], SKIN[S_DEEP], SKIN[S_LIT], 'skin'
        lo, hi = out, inn
        if sleeve < y <= sleeve+2:          # 손목: 한 칸 잘록
            lo += 1
        if y == y1:                          # 주먹 밑 둥글게
            lo += 1
            hi -= 1
        cv.hline(y, lo, hi, col, mat)
        cv.hline(y, 63-hi, 63-lo, col, mat)
        cv.set(hi, y, dark, mat)             # 몸통과 팔 사이 어두운 줄
        cv.set(63-hi, y, dark, mat)
        if y < y1:
            cv.set(lo, y, lit, mat)
            cv.set(63-lo, y, dark, mat)
    # 손목 마디
    cv.hline(y1-3, out+1, inn-1, SKIN[S_SHA], 'skin')
    cv.hline(y1-3, 64-inn, 62-out, SKIN[S_SHA], 'skin')
    # 소매 끝단
    cv.hline(sleeve, out, inn, TOP[T_DEEP], 'top')
    cv.hline(sleeve, 63-inn, 63-out, TOP[T_DEEP], 'top')
    if g == 'girl':                          # 퍼프 소매: 끝이 살짝 벌어짐
        for y in (sleeve-1, sleeve):
            cv.hline(y, out-1, inn, TOP[T_BASE] if y < sleeve else TOP[T_DEEP], 'top')
            cv.hline(y, 63-inn, 63-out+1, TOP[T_BASE] if y < sleeve else TOP[T_DEEP], 'top')


def draw_neck(cv):
    cv.rect(28, 43, 35, 50, SKIN[S_BASE], 'skin')
    cv.hline(43, 28, 35, SKIN[S_DEEP], 'skin')
    cv.hline(44, 28, 35, SKIN[S_DEEP], 'skin')
    cv.hline(45, 28, 35, SKIN[S_DEEP], 'skin')
    cv.hline(46, 28, 35, SKIN[S_SHA], 'skin')
    for y in range(47, 51):
        cv.hline(y, 34, 35, SKIN[S_SHA], 'skin')


def draw_ears(cv):
    """귀 — 얼굴 옆선에 한 칸 튀어나온 작은 혹"""
    for y in range(34, 38):
        l, r = span(FACE[y])
        if y in (34, 37):
            cv.set(l-1, y, SKIN[S_SHA], 'skin')
            cv.set(r+1, y, SKIN[S_SHA], 'skin')
        else:
            cv.set(l-1, y, SKIN[S_BASE], 'skin')
            cv.set(r+1, y, SKIN[S_BASE], 'skin')
    for y in (35, 36):
        l, r = span(FACE[y])
        cv.set(l, y, SKIN[S_SHA], 'skin')
        cv.set(r, y, SKIN[S_SHA], 'skin')


def draw_face(cv, g):
    fill(cv, FACE, SKIN[S_BASE], 'skin')
    draw_ears(cv)
    # 턱 그늘
    for y in sorted(FACE):
        l, r = span(FACE[y])
        if y >= 41:
            cv.hover(y, l, l+1, SKIN[S_SHA], 'skin')
            cv.hover(y, r-1, r, SKIN[S_SHA], 'skin')
        else:
            cv.hover(y, r-1, r, SKIN[S_SHA], 'skin')
            cv.hover(y, l, l, SKIN[S_LIT], 'skin')


# 앞머리 가닥: (가운데 x, 더 내려오는 양, 퍼지는 폭)
BOY_STRANDS  = [(24.5, 2.0, 3.0), (33.5, 1.7, 3.0), (39.0, 1.2, 2.6)]
GIRL_STRANDS = [(25.5, 1.7, 3.4), (37.0, 1.5, 3.4), (31.5, -1.4, 3.0)]


def hair_fringe(g):
    """x -> 앞머리가 끝나는 y. 완만한 활에 가닥 끝만 살짝 내려온다"""
    strands = BOY_STRANDS if g == 'boy' else GIRL_STRANDS
    k, b = (0.041, 26.3) if g == 'boy' else (0.044, 25.9)
    f = {}
    for x in range(18, 46):
        d = abs(x-31.5)
        v = b + k*d*d
        for cx, amp, wid in strands:
            v += amp * max(0.0, 1.0 - abs(x-cx)/wid)
        f[x] = int(round(v))
    return f


GIRL_BACK = ints(prof([(12,7.0),(14,9.2),(16,10.8),(19,12.3),(22,13.3),
                       (26,13.8),(32,14.0),(40,14.3),(46,14.6),(50,14.6),
                       (53,14.4)]))
# 어깨 앞으로 내려온 가닥의 끝 (바깥열부터). 한 갈래가 뾰족하게 모인다
GIRL_TIPS = {18:49, 19:51, 20:52, 21:52, 22:51, 23:49}


def girl_tip(x):
    return GIRL_TIPS.get(x if x < 32 else 63-x, 50)


def draw_hair_back(cv, g):
    """여자 뒷머리 덩어리 — 끝을 칼럼마다 다르게 잘라 머리카락 끝처럼"""
    if g != 'girl':
        return
    for y in sorted(GIRL_BACK):
        l, r = span(GIRL_BACK[y])
        for x in range(l, r+1):
            if y <= girl_tip(x):
                cv.set(x, y, HAIR[H_BASE], 'hair')


def draw_hair_front(cv, g):
    HEAD = head_prof(g)
    fill(cv, HEAD, HAIR[H_BASE], 'hair')
    fr = hair_fringe(g)
    # 얼굴 구멍 뚫기
    for y in sorted(FACE):
        l, r = span(FACE[y])
        for x in range(l, r+1):
            if y > fr.get(x, 99):
                cv.set(x, y, SKIN[S_BASE], 'skin')
    draw_face_shade(cv, g, fr)
    if g == 'girl':
        draw_side_locks(cv)
    shade_hair(cv, g)


def shade_hair(cv, g):
    """머리 음영: 오른쪽 그늘 + 정수리를 따라 도는 초승달 빛"""
    for y in range(SH):
        xs = [x for x in range(SW) if cv.m[y][x] == 'hair']
        if not xs:
            continue
        r = max(xs)
        for x in range(r-2, r+1):
            if cv.m[y][x] == 'hair':
                cv.c[y][x] = HAIR[H_SHA]
    for x in range(19, 33):
        col = [y for y in range(SH) if cv.m[y][x] == 'hair']
        if not col:
            continue
        t = min(col)
        for y in (t+3, t+4):
            if 0 <= y < SH and cv.m[y][x] == 'hair':
                cv.c[y][x] = HAIR[H_LIT]
    if g == 'girl':
        # 왼쪽으로 길게 흐르는 빛 + 갈래를 가르는 그늘
        for y in range(24, 50):
            xs = [x for x in range(SW) if cv.m[y][x] == 'hair' and x < 32]
            if not xs:
                continue
            l = min(xs)
            w = 3 if y < 40 else (2 if y < 46 else 1)
            for x in range(l+1, l+1+w):
                if cv.m[y][x] == 'hair':
                    cv.c[y][x] = HAIR[H_LIT]
        for y in range(38, 58):
            for sx in (0, 1):
                xs = [x for x in range(SW) if cv.m[y][x] == 'hair'
                      and (x < 32) == (sx == 0)]
                if not xs:
                    continue
                e = min(xs)+5 if sx == 0 else max(xs)-5
                if cv.m[y][e] == 'hair':
                    cv.c[y][e] = HAIR[H_SHA]


def draw_side_locks(cv):
    """어깨 앞으로 내려온 옆머리 — 몸통 위에 겹쳐 그린다"""
    for y in sorted(GIRL_BACK):
        if y < 27:
            continue
        l, r = span(GIRL_BACK[y])
        band = list(range(l, min(l+6, 32))) + list(range(max(r-5, 32), r+1))
        for x in band:
            if y <= girl_tip(x):
                cv.set(x, y, HAIR[H_BASE], 'hair')
    # 덩어리와 가르는 줄은 얼굴 아래에서만 (얼굴을 액자처럼 가두지 않게)
    for y in range(46, 58):
        if y not in GIRL_BACK:
            continue
        l, r = span(GIRL_BACK[y])
        if y <= girl_tip(l+5):
            cv.set(l+5, y, HAIR[H_SHA], 'hair')
        if y <= girl_tip(r-5):
            cv.set(r-5, y, HAIR[H_SHA], 'hair')


def draw_face_shade(cv, g, fr):
    # 앞머리 그림자 한 줄
    for x, y in fr.items():
        if cv.mat(x, y+1) == 'skin':
            cv.set(x, y+1, SKIN[S_SHA], 'skin')


def draw_features(cv, g):
    ey = 32
    pat_l = [
        " XXX ",
        "XPPPX",
        "XGPPX",
        "XPPPX",
        " XPX ",
    ]
    key = {'X': (EYE, 'eye'), 'P': (EYE, 'eye'),
           'G': (WHITE, 'eye'), 'W': (WHITE, 'eye')}
    cv.pat(24, ey, pat_l, key)
    cv.pat(35, ey, pat_l, key)
    # 코 — 두 점만
    cv.hover(ey+7, 31, 32, SKIN[S_SHA], 'skin')
    # 볼
    cv.hover(ey+6, 23, 25, SKIN[S_CHK], 'skin')
    cv.hover(ey+7, 23, 24, SKIN[S_CHK], 'skin')
    cv.hover(ey+6, 38, 40, SKIN[S_CHK], 'skin')
    cv.hover(ey+7, 39, 40, SKIN[S_CHK], 'skin')
    # 입 — 살짝 웃는 입
    cv.hover(ey+9, 30, 30, SKIN[S_MTH], 'skin')
    cv.hover(ey+9, 33, 33, SKIN[S_MTH], 'skin')
    cv.hover(ey+10, 31, 32, SKIN[S_MTH], 'skin')


def draw_hat(cv):
    """밀짚모자: 낮고 둥근 크라운 + 넓고 납작한 챙"""
    crown = ints(prof([(10,4.8),(11,6.8),(12,8.2),(13,9.2),(15,10.0),
                       (17,10.5),(19,10.8)]))
    fill(cv, crown, BOT[B_HI], 'bot')
    for y in sorted(crown):
        l, r = span(crown[y])
        cv.hover(y, r-2, r, BOT[B_LIT], 'bot')
        cv.hover(y, l, l, BOT[B_HI], 'bot')
    # 모자 띠
    cv.hline(17, 21, 42, TOP[T_BASE], 'top')
    cv.hline(18, 21, 42, TOP[T_SHA], 'top')
    # 이마에 지는 챙 그림자 (가운데만 한 줄)
    for x in range(23, 41):
        col = [y for y in range(20, 34) if cv.mat(x, y) == 'skin']
        if col:
            cv.set(x, min(col), SKIN[S_SHA], 'skin')
    # 챙 — 납작한 타원
    brim = ints(prof([(19,13.4),(20,16.0),(21,17.4),(22,17.8),(23,16.4)]))
    fill(cv, brim, BOT[B_HI], 'bot')
    for y in sorted(brim):
        l, r = span(brim[y])
        cv.hover(y, r-4, r, BOT[B_LIT], 'bot')
        if y >= 22:
            cv.hline(y, l, r, BOT[B_BASE], 'bot')


# ---------------------------------------------------------------- 윤곽
def outline(cv):
    src = [row[:] for row in cv.m]
    for y in range(SH):
        for x in range(SW):
            m = src[y][x]
            if m is None:
                continue
            edge = False
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                nx, ny = x+dx, y+dy
                if nx < 0 or nx >= SW or ny < 0 or ny >= SH or src[ny][nx] is None:
                    edge = True
                    break
            if edge:
                cv.c[y][x] = OUT[m]


def build(g):
    cv = Cv()
    draw_hair_back(cv, g)
    draw_legs(cv, g)
    t = draw_torso(cv, g)
    draw_overall(cv, g, t)
    draw_arms(cv, g)
    draw_neck(cv)
    draw_face(cv, g)
    draw_hair_front(cv, g)
    draw_features(cv, g)
    if g == 'boy':
        draw_hat(cv)
    outline(cv)
    return cv


def to_image(cv):
    img = Image.new('RGBA', (DW, DH), (0,0,0,0))
    p = img.load()
    for y in range(SH):
        for x in range(SW):
            c = cv.c[y][x]
            if c is None:
                continue
            for dy in (0,1):
                for dx in (0,1):
                    X, Y = x*2+dx+XOFF, y*2+dy+YOFF
                    if 0 <= X < DW and 0 <= Y < DH:
                        p[X,Y] = (c[0], c[1], c[2], 255)
    return img


# ---------------------------------------------------------------- 검사
def check(name, img):
    ok = True
    px = img.load()
    msg = []
    if img.size != (DW, DH):
        ok = False
        msg.append('크기 %s' % (img.size,))
    opaque = []
    alphas = set()
    cols = {}
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r,gg,b,a = px[x,y]
            alphas.add(a)
            if a:
                opaque.append((x,y))
                cols[(r,gg,b)] = cols.get((r,gg,b),0)+1
    if not opaque:
        return False, ['빈 그림']
    ymax = max(p[1] for p in opaque)
    xmin = min(p[0] for p in opaque)
    xmax = max(p[0] for p in opaque)
    if ymax != 190:
        ok = False
    msg.append('발바닥 y=%d (190 이어야 함)' % ymax)
    msg.append('가로 %d..%d 중심 %.1f' % (xmin, xmax, (xmin+xmax)/2.0))
    bad = alphas - {0,255}
    if bad:
        ok = False
    msg.append('알파 종류 %s' % sorted(alphas))
    outside = [c for c in cols if c not in ALLOWED]
    if outside:
        ok = False
    msg.append('표 밖 색 %d 개 %s' % (len(outside), outside[:6]))
    # 연결요소 (4-이웃)
    seen = set()
    comp = 0
    opset = set(opaque)
    biggest = 0
    for st in opaque:
        if st in seen:
            continue
        comp += 1
        stack = [st]
        seen.add(st)
        n = 0
        while stack:
            x,y = stack.pop()
            n += 1
            for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                q = (x+dx, y+dy)
                if q in opset and q not in seen:
                    seen.add(q)
                    stack.append(q)
        biggest = max(biggest, n)
    if comp != 1:
        ok = False
    msg.append('연결요소 %d 개 (가장 큰 덩어리 %d px / 전체 %d px)'
               % (comp, biggest, len(opaque)))
    print('[%s] %s  %s' % (name, 'OK ' if ok else 'FAIL', ' | '.join(msg)))
    return ok, msg


# ---------------------------------------------------------------- 미리보기
def make_view(boy, girl):
    BG = (122,150,96)
    big = 3
    bw, bh = DW*big, DH*big
    sw, sh = int(round(DW*0.28)), int(round(DH*0.28))   # 36 x 54
    pad, gap = 14, 16
    W = pad + bw + gap + bw + pad*3 + sw + gap + sw + pad
    H = pad + bh + pad
    view = Image.new('RGBA', (W, H), BG+(255,))
    for i, im in enumerate((boy, girl)):
        b = im.resize((bw, bh), Image.NEAREST)
        view.alpha_composite(b, (pad + i*(bw+gap), pad))
    x = pad + bw + gap + bw + pad*3
    ybase = (H - sh)//2
    for i, im in enumerate((boy, girl)):
        small = im.resize((sw, sh), Image.NEAREST)
        view.alpha_composite(small, (x + i*(sw+gap), ybase))
    return view


def main():
    out = {}
    for g in ('boy','girl'):
        cv = build(g)
        img = to_image(cv)
        path = os.path.join(HERE, 'd_sv_%s.png' % g)
        img.save(path)
        out[g] = img
        check(g, img)
    view = make_view(out['boy'], out['girl'])
    view.convert('RGB').save(os.path.join(HERE, 'd_sv_view.png'))
    print('view %s' % (view.size,))


if __name__ == '__main__':
    main()
