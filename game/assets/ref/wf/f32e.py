#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""f32d — f32x4 를 32 x 48 **그대로 두고** 손본 판.

원본 f32x4 — 32 x 48 격자에 찍고 정수 4배로 키워 128 x 192 를 만드는 주인공 도트.

참고 그림과 완전히 같은 해상도(32x48)다. 칸이 적으므로 한 칸 한 칸이 결정적이다.
화풍: 면마다 단색 / 굵고 새까만 윤곽 / 팔·몸통 사이, 두 다리 사이에도 검정 줄 /
치비 비율 (머리가 키의 40% 이상) / 대비를 세게.

Pillow 만 쓴다 (numpy 없음).
"""

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GW, GH = 32, 48          # 격자
S = 4                    # 확대 배율
OW, OH = 128, 192        # 최종 크기
YSHIFT = -1              # 위로 1px — 발바닥이 y=190 에 오게 한다

# ---------------------------------------------------------------- 팔레트
# 살결 7단 [기본, 밝은면, 그늘, 볼, 입, 깊은그늘, 아주밝은면]
SK, SK_L, SK_D = (243, 159, 138), (250, 192, 170), (213, 116, 98)
SK_CH, SK_M, SK_DD, SK_LL = (235, 128, 114), (170, 84, 66), (184, 99, 83), (252, 217, 204)
# 머리 5단 [기본, 밝은면, 그늘, 깊은그늘, 아주밝은면]
HR, HR_L, HR_D, HR_DD, HR_LL = (118, 72, 40), (152, 100, 56), (86, 52, 30), (58, 35, 20), (195, 165, 140)
# 윗도리 5단 [기본, 그늘, 밝은면, 깊은그늘, 아주밝은면]
SH, SH_D, SH_L, SH_DD, SH_LL = (58, 88, 168), (38, 58, 120), (94, 126, 200), (27, 41, 84), (166, 184, 225)
# 아랫도리 5단
PT, PT_D, PT_L, PT_DD, PT_LL = (134, 88, 46), (98, 62, 32), (158, 108, 58), (69, 43, 22), (202, 174, 147)
# 신발 3단
SO, SO_D, SO_DD = (82, 53, 33), (56, 37, 25), (39, 26, 18)
# 갈아입히지 않는 색
OL, EYE, BROW, WHT = (26, 20, 28), (66, 32, 30), (136, 70, 42), (246, 242, 234)

CHARS = {
    '#': OL,
    'h': HR, 'H': HR_L, 'd': HR_D, 'D': HR_DD, 'G': HR_LL,
    's': SK, 'l': SK_L, 'S': SK_D, 'c': SK_CH, 'm': SK_M, 'k': SK_DD, 'w': SK_LL,
    'e': EYE, 'W': WHT, 'b': BROW,
    't': SH, 'T': SH_L, 'y': SH_D, 'Y': SH_DD, 'U': SH_LL,
    'p': PT, 'P': PT_L, 'q': PT_D, 'Q': PT_DD, 'u': PT_LL,
    'o': SO, 'O': SO_D, 'x': SO_DD,
}
ALLOWED = set(CHARS.values())
HAIRCH = 'hHdDG'


# ---------------------------------------------------------------- 격자 도구
def blank():
    return [['.'] * GW for _ in range(GH)]


def hfill(g, y, x0, x1, ch):
    if 0 <= y < GH:
        for x in range(max(0, x0), min(GW - 1, x1) + 1):
            g[y][x] = ch


def put(g, x, y, ch):
    if 0 <= x < GW and 0 <= y < GH:
        g[y][x] = ch


def swap(g, x, y, frm, ch):
    """frm 안의 문자일 때만 바꾼다 (덧칠 사고 방지)."""
    if 0 <= x < GW and 0 <= y < GH and g[y][x] in frm:
        g[y][x] = ch


def swaprow(g, y, x0, x1, frm, ch):
    for x in range(max(0, x0), min(GW - 1, x1) + 1):
        swap(g, x, y, frm, ch)


def band(g, rows, L, R, ch):
    for y in rows:
        hfill(g, y, L, R, ch)


def shell(g, table, fill_ch=None):
    """row -> (L, R) 표를 받아 안쪽을 fill_ch 로 채운다.

    양끝에 윤곽을 직접 써 넣지 않는다 — 윤곽은 outline_pass 가 **재질 색으로**
    두른다. 여기서 검정을 박아 두면 옆에 머리가 붙은 자리(여자 어깨)에만
    검정이 남아 남녀 어깨선이 달라진다."""
    for y in sorted(table):
        L, R = table[y]
        if fill_ch is not None and R - L >= 2:
            hfill(g, y, L + 1, R - 1, fill_ch)


def rim_top(g, x0, x1, n, ch):
    """칸마다 위에서부터 머리색 n 칸을 ch 로 — 실루엣을 그대로 따라가는 띠."""
    for x in range(max(0, x0), min(GW - 1, x1) + 1):
        cnt = 0
        for y in range(GH):
            if g[y][x] in HAIRCH:
                g[y][x] = ch
                cnt += 1
                if cnt >= n:
                    break
            elif cnt:
                break


def rim_right(g, y0, y1, n, ch):
    """줄마다 오른쪽 끝에서부터 머리색 n 칸을 ch 로."""
    for y in range(max(0, y0), min(GH - 1, y1) + 1):
        cnt = 0
        for x in range(GW - 1, -1, -1):
            if g[y][x] in HAIRCH:
                g[y][x] = ch
                cnt += 1
                if cnt >= n:
                    break
            elif cnt:
                break


def rim_prof(g, x0, prof, ch):
    """칸마다 깊이를 따로 줘서 위에서부터 머리색을 ch 로 바꾼다.

    깊이가 똑같은 띠는 실루엣을 자로 대고 따라 그은 자국이 된다 — 그게
    「기계가 뽑은 것 같다」의 정체다. 빛을 받은 자리는 덩어리로 두껍고
    그늘 쪽으로 갈수록 얇아져야 손으로 칠한 것처럼 보인다.
    prof[i] 는 x0+i 칸의 깊이, 0 이면 그 칸은 건드리지 않는다."""
    for i, n in enumerate(prof):
        x = x0 + i
        if not (0 <= x < GW) or n <= 0:
            continue
        cnt = 0
        for y in range(GH):
            if g[y][x] in HAIRCH:
                g[y][x] = ch
                cnt += 1
                if cnt >= n:
                    break
            elif cnt:
                break


def strand(g, x, y0, y1, ch='d'):
    """머리 가닥 한 줄. 길이를 제각각으로 둬야 결로 읽힌다."""
    for y in range(y0, y1 + 1):
        swap(g, x, y, 'hH', ch)


# 빛은 왼쪽 위에서 온다. 정수리 왼쪽이 가장 두껍고 오른쪽으로 갈수록 얇다.
PROF_BOY = (1, 3, 5, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1)      # x6..22
PROF_GIRL = (1, 2, 4, 5, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1)  # x4..22
PROF_SIDE = (2, 4, 5, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1)     # x7..23
PROF_BACK = (1, 3, 4, 5, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1)  # x6..25


# 재질 -> 그 재질의 가장 어두운 단. 실루엣을 **이 색으로** 두른다.
# 참고 도트에는 검정이 한 칸도 없다 — 머리는 (75,57,57), 스웨터는 (36,70,88),
# 바지는 (58,57,74) 로 재질마다 자기 가장 어두운 단이 테두리를 맡는다.
# 검정 한 색으로 두르면 선이 딱딱하고, 옷을 갈아입혀도 테두리만 그대로라 겉돈다.
EDGE = {}
for _k in 'slScmkw':
    EDGE[_k] = 'k'          # 살결 (184,99,83)
for _k in 'hHdDG':
    EDGE[_k] = 'D'          # 머리 (58,35,20)
for _k in 'tTyYU':
    EDGE[_k] = 'Y'          # 윗도리 (27,41,84)
for _k in 'pPqQu':
    EDGE[_k] = 'Q'          # 아랫도리 (69,43,22)
for _k in 'oOx':
    EDGE[_k] = 'x'          # 신발 (39,26,18)
for _k in 'ebW':
    EDGE[_k] = 'D'


def outline_pass(g):
    """바깥 공기와 맞닿은 칸을 그 재질의 가장 어두운 단으로 바꾼다."""
    todo = []
    for y in range(GH):
        for x in range(GW):
            if g[y][x] in '.#':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < GW and 0 <= ny < GH):
                    continue         # 캔버스 밖은 공기가 아니다. 세면 맨
                if g[ny][nx] == '.':  # 아랫줄이 통째로 검정 받침대가 된다
                    todo.append((x, y))
                    break
    for x, y in todo:
        vote = {}
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < GW and 0 <= ny < GH:
                e = EDGE.get(g[ny][nx])
                if e:
                    vote[e] = vote.get(e, 0) + 1
        g[y][x] = max(vote, key=vote.get) if vote else '#'


def soften(g):
    """윤곽의 90도 모서리를 한 칸씩 깎는다.

    격자에 그리면 모서리가 전부 직각이라 로봇처럼 보인다. 「바깥과 맞닿은
    윤곽 칸 중 채워진 이웃이 가로 하나·세로 하나뿐인 칸」이 볼록 모서리다.
    그 칸을 지우면 모서리가 대각으로 깎여 선이 둥글어진다."""
    cut = []
    for y in range(GH):
        for x in range(GW):
            if g[y][x] not in ('#', 'k', 'D', 'Y', 'Q', 'x'):
                continue
            hor = [dx for dx in (-1, 1)
                   if 0 <= x + dx < GW and g[y][x + dx] != '.']
            ver = [dy for dy in (-1, 1)
                   if 0 <= y + dy < GH and g[y + dy][x] != '.']
            if len(hor) == 1 and len(ver) == 1:
                dx, dy = hor[0], ver[0]
                if 0 <= x + dx < GW and 0 <= y + dy < GH \
                        and g[y + dy][x + dx] != '.':
                    cut.append((x, y))
    for x, y in cut:
        g[y][x] = '.'


# ================================================================ 머리·얼굴
# 얼굴 살결이 놓이는 자리. 양끝은 윤곽이다.
FACE = {10: (9, 22), 11: (9, 22), 12: (9, 22), 13: (9, 22), 14: (9, 22),
        15: (9, 22), 16: (9, 22), 17: (9, 22), 18: (10, 21), 19: (11, 20)}

EL, ER = 11, 18          # 왼눈·오른눈 왼쪽 칸 (각 3칸 = 얼굴 폭 12칸의 1/4)

# 3/4 얼굴 창 — 앞모습 창을 한 칸 오른쪽으로. 15줄부터 R 이 실루엣보다
# 한 칸 밖이라 돌아선 쪽 광대와 턱이 실루엣을 밀고 나간다.
FACE_Q = {10: (10, 23), 11: (10, 23), 12: (10, 23), 13: (10, 23),
          14: (10, 23), 15: (10, 23), 16: (10, 23), 17: (10, 22),
          18: (11, 21), 19: (12, 20)}



# 머리 표를 모듈 상수로 둔다 — 3/4 이 같은 덩어리를 그대로 쓴다
HEAD_BOY = {
    1: (10, 21), 2: (9, 22), 3: (8, 23), 4: (8, 23), 5: (7, 24),
    6: (7, 24), 7: (6, 25), 8: (6, 25), 9: (6, 25), 10: (6, 25),
    11: (6, 25), 12: (6, 25), 13: (6, 25), 14: (7, 24), 15: (8, 23),
    16: (8, 23), 17: (9, 22), 18: (10, 21), 19: (11, 20), 20: (12, 19),
}
BANG_BOY = {10: 12, 11: 11, 12: 11, 13: 10, 14: 10, 15: 10,
            16: 10, 17: 10, 18: 11, 19: 11, 20: 11, 21: 12}
HEAD_GIRL = {          # 위는 좁고 어깨께에서 퍼졌다 끝이 모이는 긴 머리
    1: (10, 21), 2: (9, 22), 3: (8, 23), 4: (7, 24), 5: (6, 25),
    6: (6, 25), 7: (5, 26), 8: (5, 26), 9: (5, 26), 10: (5, 26),
    11: (5, 26), 12: (5, 26), 13: (4, 27), 14: (4, 27), 15: (4, 27),
    16: (4, 27), 17: (4, 27), 18: (4, 27), 19: (4, 27), 20: (4, 27),
    21: (4, 27), 22: (5, 26), 23: (5, 26), 24: (6, 25), 25: (6, 25),
    26: (7, 24), 27: (7, 24), 28: (8, 23), 29: (8, 23),
}
BANG_GIRL = {10: 12, 11: 10, 12: 10, 13: 10, 14: 10, 15: 10,
             16: 10, 17: 10, 18: 10, 19: 10, 20: 10, 21: 12}


def draw_head(g, HEAD, BANG, lit_cols, dark_rows, eye_top,
              lash=False, blush_wide=False, prof=None, q=False):
    """머리 덩어리 + 얼굴.
    명암은 실루엣을 따라가는 띠로 넣는다 — 자로 그은 사선도, 네모 딱지도 안 생긴다."""
    shell(g, HEAD, 'h')

    # --- 얼굴을 도려낸다
    F = FACE_Q if q else FACE
    for y in sorted(F):
        L, R = F[y]
        put(g, L, y, 'D' if g[y][L - 1] in HAIRCH else '#')
        put(g, R, y, 'D' if g[y][R + 1] in HAIRCH else '#')
        hfill(g, y, L + 1, R - 1, 's')
    n = 1 if q else 0                    # 3/4 은 얼굴 부속이 통째로 한 칸 간다
    hfill(g, 20, 12 + n, 19 + n, 'k')
    hfill(g, 20, 14 + n, 17 + n, 'S')    # 목 (턱 그늘)

    # --- 앞머리: 눈 바로 위까지 내려온다 (이마가 텅 빈 살구색 판이 되지 않게)
    for c, bot in BANG.items():
        for y in range(6, bot + 1):
            put(g, c, y, 'h')

    # --- 위 테두리를 따라 밝은 띠 (빛은 왼쪽 위에서 온다)
    if prof:
        rim_prof(g, lit_cols[0], prof, 'H')
    else:
        rim_top(g, lit_cols[0], lit_cols[1], 3, 'H')
    # --- 오른쪽 테두리를 따라 그늘 띠
    rim_right(g, dark_rows[0], dark_rows[1], 2, 'd')

    # --- 앞머리 끝은 가장 어두운 머리색 — 살결과 부딪혀 선처럼 읽힌다
    for c, bot in BANG.items():
        swap(g, c, bot, HAIRCH, 'D')

    # --- 살결 명암 (세로 면 세 장. 그라데이션·디더 금지)
    for y in range(11, 18):
        swap(g, 10 + n, y, 's', 'S' if q else 'l')   # 3/4 은 먼 쪽이 그늘
        swap(g, 21 + n, y, 's', 'l' if q else 'S')   # 가까운 쪽이 빛을 받는다
    hfill(g, 19, 12 + n, 19 + n, 'S')

    # --- 눈 (3칸 폭 x 3줄). 바깥 아래 모서리를 깎아 둥글게, 흰자 한 칸을 넣는다
    # 참고 도트 구조 — 속눈썹 한 줄 · 홍채 두 줄 · 아래 한 단 밝은 줄.
    # 세 줄을 통째로 검정으로 칠하면 눈이 구멍 두 개가 된다.
    t = eye_top
    # 3/4 은 먼 눈이 두 칸으로 눌린다 — 이 비대칭 하나가 「돌아섰다」의 8할이다
    fl, fw = (EL + 2, 2) if q else (EL, 3)
    nl = ER + n
    hfill(g, t, fl, fl + fw - 1, 'e')
    hfill(g, t, nl, nl + 2, 'e')
    for y in (t + 1, t + 2):
        hfill(g, y, fl, fl + fw - 1, 'b')
        hfill(g, y, nl, nl + 2, 'b')
    put(g, fl, t + 1, 'W')               # 반사점은 바깥쪽 (참고 도트도 대칭)
    put(g, nl + 2, t + 1, 'W')
    hfill(g, t + 3, fl + fw - 2, fl + fw - 1, 'c')   # 아래 홍채 — 한 단 밝게
    hfill(g, t + 3, nl, nl + 1, 'c')
    if lash:
        put(g, fl, t, 'e')
        put(g, nl + 2, t, 'e')

    # --- 볼 · 입
    cheek = t + 3                        # 참고 도트는 볼이 아래 홍채와 같은 줄
    # 3/4 은 먼 쪽 볼이 한 칸, 가까운 쪽 볼이 세 칸 — 폭이 다른 게 핵심이다
    for x in ((12,) if q else (10, 11)):
        swap(g, x, cheek, 'sl', 'c')
    for x in ((20, 21, 22) if q else (20, 21)):
        swap(g, x, cheek, 'sSl', 'c')
    if blush_wide:
        swap(g, 12 + n, cheek, 's', 'c')
        swap(g, 19 + n, cheek, 's', 'c')
    if q:
        put(g, 21, cheek + 1, 'S')       # 코 — 광대 아래 그늘 한 칸
    # 입 — 원본대로 두 칸. 네 칸으로 넓히면 벌린 입이 되고, 양끝을 한 줄
    # 올리면 32칸에서는 칸 사이가 벌어져 점 세 개로 읽힌다. 아랫입술에 빛을
    # 한 줄 둬 봤더니 턱 그늘 위에 얹혀 염소수염이 됐다 — 그것도 뺐다
    hfill(g, cheek + 2, 15 + n, 16 + n, 'm')


# ================================================================ 남자
def build_boy():
    g = blank()

    # 정수리가 오른쪽으로 쏠린 가르마, 왼쪽 구레나룻이 두 줄 더 길다
    HEAD = HEAD_BOY
    # 눈이 놓이는 칸(11~13 · 18~20)은 끝 줄이 11을 넘으면 안 된다 —
    # 넘으면 앞머리가 눈꺼풀을 덮어 한쪽 눈만 감은 것처럼 보인다
    BANG = BANG_BOY
    draw_head(g, HEAD, BANG, lit_cols=(6, 22), dark_rows=(3, 17), eye_top=12,
              prof=PROF_BOY)
    strand(g, 11, 2, 5)            # 결 — 길이가 다른 두 가닥
    strand(g, 18, 1, 3)


    # ================================ 몸
    # 어깨 — 목에서 어깨끝까지 **네 줄**에 걸쳐 벌어지고, 그 아래로 팔이
    # 수직으로 내려간다. 전에는 목 바로 밑이 곧장 최대 폭이라 어깨가 없었다
    # 목은 20줄 한 줄뿐. 21줄부터 바로 어깨가 벌어진다 (전에는 21줄이
    # 좁은 깃이라 목이 두 줄로 길어 보였다). 어깨 폭은 18 → 20 칸
    BODY = {21: (10, 21), 22: (8, 23)}
    for y in range(23, 29):
        BODY[y] = (8, 23)          # 어깨 14칸 (전 16칸)
    for y in range(29, 32):
        BODY[y] = (7, 24)          # 손끝만 벙어리장갑처럼 불룩
    BODY[32] = (10, 21)
    for y in range(33, 46):
        BODY[y] = (10, 21)
    for y in range(46, 48):
        BODY[y] = (9, 22)
    shell(g, BODY, 't')


    # 소매 — **가르는 선을 넣지 않는다.** 왼팔을 한 단 밝게, 오른팔을 한 단
    # 어둡게 칠하면 톤만으로 팔이 갈린다. 검은 줄로 자르면 어깨가 세 갈래
    # 세로 띠가 되어 「어깨가 없는」 몸이 된다 (참고 도트도 선이 없다)
    hfill(g, 21, 11, 20, 'T')      # 어깨 뚜껑 — 빛을 정면으로 받는 면
    hfill(g, 22, 9, 22, 'T')       # 두 줄을 깔고 그 아래에서 팔만 남긴다
    for y in range(23, 28):
        hfill(g, y, 9, 10, 'T')    # 왼팔 — 이음선까지 세 칸
    for y in range(25, 32):        # 팔 이음선 — 어깨 뚜껑에서 두 줄 띄운다
        swap(g, 11, y, 't', 'y')   # (붙여 놓으면 팔이 어깨에 매달린 꼴)
        swap(g, 20, y, 't', 'y')
    # 옷깃 — 어깨 뚜껑 위에 얹는다
    hfill(g, 21, 13, 14, 'U')
    hfill(g, 21, 17, 18, 'U')
    hfill(g, 21, 15, 16, 'S')
    hfill(g, 27, 9, 11, 'U')       # 걷어올린 소맷단
    hfill(g, 27, 20, 22, 'U')
    # 손
    hfill(g, 28, 9, 11, 's')
    hfill(g, 28, 20, 22, 's')
    for y in range(29, 32):
        hfill(g, y, 8, 11, 's')
        hfill(g, y, 20, 23, 's')
    hfill(g, 28, 9, 10, 'l')
    hfill(g, 29, 8, 9, 'l')
    hfill(g, 31, 8, 11, 'S')
    hfill(g, 31, 20, 23, 'S')
    # 몸통에는 그늘 줄을 넣지 않는다. 오른소매와 같은 색이라 붙여 놓으면
    # 팔이 몸통에 녹아버린다 — 소매 두 단만으로 팔이 갈린다
    # 옷 주름 — 좌우 높이를 일부러 어긋나게 둔다. 같은 높이에 대칭으로
    # 넣으면 주름이 아니라 무늬가 되고, 그게 「기계가 찍은 것 같다」가 된다
    put(g, 13, 26, 'y')
    put(g, 13, 27, 'y')
    put(g, 18, 24, 'y')
    put(g, 18, 25, 'y')
    put(g, 14, 30, 'y')                  # 밑단 구김
    # 단추
    for y in (23, 26, 29):               # 단추 — 몸통 안쪽 12~19 의 축은 15.5
        hfill(g, y, 15, 16, 'U')         # 한 칸이면 반 칸 어긋난다
    # 윗도리 밑단
    hfill(g, 31, 11, 20, 'Y')

    # ---- 허리띠
    hfill(g, 32, 11, 20, 'Q')
    hfill(g, 32, 15, 16, 'u')

    # ---- 바지 (두 다리 사이 검정 줄)
    band(g, range(33, 42), 11, 20, 'p')
    for y in range(34, 42):
        hfill(g, y, 15, 16, 'Q')     # 바지 깊은그늘로 가른다 (검정 아님)
    for y in range(33, 42):
        swaprow(g, y, 11, 12, 'p', 'P')
        swap(g, 14, y, 'p', 'q')
        swaprow(g, y, 19, 20, 'p', 'q')
    hfill(g, 41, 11, 14, 'Q')
    hfill(g, 41, 17, 20, 'Q')

    # ---- 장화
    band(g, range(42, 46), 11, 20, 'o')
    band(g, range(46, 48), 10, 21, 'o')
    for y in range(42, 48):
        hfill(g, y, 15, 16, 'x')     # 장화 가장 어두운 단
    hfill(g, 42, 11, 14, 'O')          # 장화 목
    hfill(g, 42, 17, 20, 'O')
    hfill(g, 37, 11, 14, 'q')          # 무릎 주름 — 두 다리 높이를 어긋나게
    hfill(g, 38, 17, 20, 'q')
    hfill(g, 34, 12, 13, 'q')          # 허벅지 구김 (한쪽만)
    hfill(g, 44, 17, 19, 'O')          # 장화 접힌 자국 (한쪽만)
    for y in range(43, 48):
        swap(g, 14, y, 'o', 'O')
        swap(g, 20, y, 'o', 'O')
        swap(g, 21, y, 'o', 'O')
    hfill(g, 47, 10, 21, 'x')
    return g


# ================================================================ 여자
def build_girl():
    g = blank()

    HEAD = HEAD_GIRL
    BANG = BANG_GIRL
    draw_head(g, HEAD, BANG, lit_cols=(4, 22), dark_rows=(4, 29),
              eye_top=12, lash=True, blush_wide=True, prof=PROF_GIRL)
    strand(g, 10, 2, 6)                # 결 — 길이가 다른 두 가닥
    strand(g, 17, 1, 4)

    # 긴 머리 안쪽에 결 한 줄씩 (판자로 안 보이게)
    for y in range(15, 27):
        swap(g, 7, y, 'hH', 'd')

    for y in range(13, 28):
        swap(g, 24, y, 'd', 'D')

    # 머리핀 하나 (윗도리 색이라 옷을 갈아입으면 같이 바뀐다)
    put(g, 22, 9, 'U')
    put(g, 23, 9, 'U')
    put(g, 22, 10, 'T')
    put(g, 23, 10, 'y')

    # ================================ 몸
    BODY = {21: (11, 20), 22: (9, 22)}
    for y in range(23, 29):
        BODY[y] = (8, 23)          # 어깨 14칸 (전 16칸)
    for y in range(29, 32):
        BODY[y] = (7, 24)          # 손
    BODY[32] = (9, 22)
    BODY[33] = (8, 23)
    BODY[34] = (8, 23)
    BODY[35] = (7, 24)
    BODY[36] = (7, 24)
    BODY[37] = (7, 24)
    for y in range(38, 46):
        BODY[y] = (11, 20)
    for y in range(46, 48):
        BODY[y] = (10, 21)
    shell(g, BODY, 't')


    # 짧은 소매 — 가르는 선 없이 톤으로만 (남자와 같은 이유)
    hfill(g, 21, 12, 19, 'T')      # 어깨 뚜껑
    hfill(g, 22, 10, 21, 'T')
    for y in range(23, 26):
        hfill(g, y, 9, 10, 'T')
    for y in range(25, 32):        # 팔 이음선 — 어깨 뚜껑에서 두 줄 띄운다
        swap(g, 11, y, 't', 'y')
        swap(g, 20, y, 't', 'y')
    hfill(g, 21, 13, 14, 'U')      # 옷깃
    hfill(g, 21, 17, 18, 'U')
    hfill(g, 21, 15, 16, 'S')
    hfill(g, 26, 9, 11, 'U')
    hfill(g, 26, 20, 22, 'U')
    # 맨팔 · 손
    for y in range(27, 29):
        hfill(g, y, 9, 11, 's')
        hfill(g, y, 20, 22, 'S')
    for y in range(29, 32):
        hfill(g, y, 8, 11, 's')
        hfill(g, y, 20, 23, 's')
    hfill(g, 29, 8, 9, 'l')
    hfill(g, 30, 8, 9, 'l')
    hfill(g, 31, 20, 23, 'S')
    put(g, 13, 24, 'y')                # 옷 주름 — 좌우 높이를 어긋나게
    put(g, 13, 25, 'y')
    put(g, 18, 27, 'y')
    put(g, 18, 28, 'y')
    put(g, 14, 30, 'y')
    # 상의 명암


    # ---- 치마
    hfill(g, 31, 12, 19, 'Q')
    for y in range(32, 37):
        L, R = BODY[y]
        hfill(g, y, L + 1, R - 1, 'p')
        swaprow(g, y, L + 1, L + 2, 'p', 'P')
        swap(g, R - 1, y, 'p', 'q')
    for y in range(33, 37):         # 주름 — 길이를 제각각으로. 셋이 같은
        swap(g, 11, y, 'p', 'q')    # 길이면 자로 그은 줄무늬가 된다
    for y in range(34, 37):
        swap(g, 16, y, 'p', 'q')
    for y in range(33, 36):
        swap(g, 21, y, 'p', 'q')
    hfill(g, 37, 7, 24, 'Q')
    hfill(g, 37, 11, 20, 'Q')

    # ---- 맨다리
    for y in range(38, 42):
        hfill(g, y, 12, 19, 's')
        put(g, 15, y, 'm')           # 맨다리 사이 — 살결 가장 어두운 단
        put(g, 16, y, 'm')
        swap(g, 19, y, 's', 'S')
    hfill(g, 38, 12, 14, 'S')          # 치마가 드리운 그늘
    hfill(g, 38, 17, 19, 'S')
    hfill(g, 39, 12, 13, 'l')            # 한 칸짜리는 딱지로 보인다
    hfill(g, 40, 12, 13, 'l')
    hfill(g, 39, 17, 18, 'l')
    hfill(g, 40, 17, 18, 'l')

    # ---- 단화
    band(g, range(42, 46), 12, 19, 'o')
    band(g, range(46, 48), 11, 20, 'o')
    for y in range(42, 48):
        hfill(g, y, 15, 16, 'x')     # 단화 가장 어두운 단
    hfill(g, 42, 12, 14, 'O')          # 단화 목
    hfill(g, 42, 17, 19, 'O')
    for y in range(45, 47):
        swap(g, 14, y, 'o', 'O')
        swap(g, 19, y, 'o', 'O')
        swap(g, 20, y, 'o', 'O')
    swap(g, 19, 43, 'o', 'O')
    swap(g, 19, 44, 'o', 'O')
    hfill(g, 47, 11, 20, 'x')
    return g


# ---------------------------------------------------------------- 출력
SOFT = True


# ================================================================ 옆·뒤
# 좌우 방향은 90도 옆모습이 아니라 **3/4 (대각)** 으로 간다. 32칸에서 완전한
# 옆모습은 눈이 하나만 남아 정면과 딴 사람이 되고, 걷는 방향이 뻣뻣해진다.
#
# 뒷모습은 앞모습 몸을 그대로 쓰고 머리만 통째로 채운다 — 뒤통수에는 얼굴이
# 없으므로 앞머리·눈·입을 빼고, 대신 목덜미 그늘과 머릿결만 넣는다.

# ================================================================ 3/4 (대각)
# 참고 도트(base)를 보면 3/4 은 고개를 45도 홱 돌린 게 아니라 30도쯤
# 살짝 튼 자세다. 머리 덩어리는 앞모습과 거의 같고, 돌아선 건 이렇게 읽힌다.
#   · 이목구비가 통째로 한 칸 오른쪽으로 간다
#   · 먼 눈이 두 칸으로 눌리고, 먼 쪽 볼은 한 칸 / 가까운 쪽 볼은 세 칸
#     — 이 비대칭 하나가 「돌아섰다」의 8할이다
#   · 얼굴 면이 가까운 쪽에서 실루엣을 한 칸 밀고 나간다 (광대·코)
#   · 몸통이 앞(14칸)보다 좁은 12칸이고, 가까운 어깨가 한 줄 늦게 더 멀리
#     벌어져 어깨선이 비뚤다
#   · 가까운 팔은 몸 앞으로 나오고 먼 팔은 몸에 붙는다
#   · 가까운 다리가 넓고 앞에, 먼 다리는 좁고 뒤에 — 다리 사이는 한 칸
# 머리 덩어리·앞머리·명암은 **앞모습 것을 그대로 쓴다.** 30도쯤 튼 머리는
# 실루엣이 거의 안 변한다 (참고 도트 base 도 그렇다). 턱과 목만 한 칸
# 기울고, 돌아선 것은 이목구비 비대칭과 몸통 비틀림이 읽어 준다.
HEAD_Q = dict(HEAD_BOY)
HEAD_Q.update({18: (11, 22), 19: (12, 21), 20: (13, 20)})
HEAD_Q_GIRL = dict(HEAD_GIRL)
HEAD_Q_GIRL.update({18: (4, 27), 19: (4, 27), 20: (4, 27)})
BANG_Q = {c + 1: b for c, b in BANG_BOY.items()}
BANG_Q_GIRL = {c + 1: b for c, b in BANG_GIRL.items()}


def draw_head_q(g, girl):
    if girl:
        draw_head(g, HEAD_Q_GIRL, BANG_Q_GIRL, lit_cols=(4, 22),
                  dark_rows=(4, 29), eye_top=12, lash=True,
                  blush_wide=True, prof=PROF_GIRL, q=True)
        strand(g, 10, 2, 6)
        strand(g, 17, 1, 4)
        for y in range(15, 27):
            swap(g, 7, y, 'hH', 'd')
        put(g, 23, 9, 'U')                 # 머리핀
        put(g, 24, 9, 'U')
        put(g, 23, 10, 'T')
        put(g, 24, 10, 'y')
    else:
        draw_head(g, HEAD_Q, BANG_Q, lit_cols=(6, 22), dark_rows=(3, 17),
                  eye_top=12, prof=PROF_BOY, q=True)
        strand(g, 11, 2, 5)
        strand(g, 18, 1, 3)


def body_q(g, girl):
    """3/4 몸. 어깨선이 비뚤고 가까운 팔이 몸 앞에 온다."""
    BODY = {21: (11, 21), 22: (10, 22)}
    for y in range(23, 29):
        BODY[y] = (10, 23)             # 가까운 어깨가 한 줄 늦게 더 나간다
    for y in range(29, 32):
        BODY[y] = (9, 24)              # 손
    if girl:
        BODY[32] = (9, 22)
        BODY[33] = BODY[34] = (8, 23)
        BODY[35] = BODY[36] = BODY[37] = (7, 24)
        for y in range(38, 46):
            BODY[y] = (11, 20)
        for y in range(46, 48):
            BODY[y] = (10, 21)
    else:
        for y in range(32, 46):
            BODY[y] = (10, 21)
        for y in range(46, 48):
            BODY[y] = (9, 22)
    shell(g, BODY, 't')

    hfill(g, 21, 12, 20, 'T')          # 어깨 뚜껑 — 가까운 쪽으로 기운다
    hfill(g, 22, 11, 21, 'T')
    for y in range(23, 28):
        hfill(g, y, 21, 22, 'T')       # 가까운 팔 — 앞에 있어 밝다
    for y in range(24, 32):
        swap(g, 13, y, 't', 'y')       # 먼 팔 이음선
    for y in range(25, 32):
        swap(g, 20, y, 't', 'y')       # 가까운 팔 이음선 — 한 줄 늦게
    hfill(g, 21, 14, 15, 'U')          # 옷깃 — 목(15~18)에 맞춘다
    hfill(g, 21, 18, 19, 'U')
    hfill(g, 21, 16, 17, 'S')
    for y in (24, 27, 30):             # 단추 — 몸통 축은 16.5
        hfill(g, y, 16, 17, 'U')
    put(g, 15, 26, 'y')                # 옷 주름 — 좌우 높이를 어긋나게
    put(g, 15, 27, 'y')
    put(g, 19, 24, 'y')
    hfill(g, 28, 11, 12, 'U')          # 소맷단
    hfill(g, 28, 21, 22, 'U')
    for y in range(29, 32):            # 손 — 가까운 손이 한 칸 크다
        hfill(g, y, 10, 12, 's')
        hfill(g, y, 20, 23, 's')
    hfill(g, 29, 10, 11, 'S')          # 먼 손은 한 단 어둡다
    hfill(g, 30, 10, 11, 'S')
    hfill(g, 29, 22, 23, 'l')
    hfill(g, 31, 10, 12, 'S')
    hfill(g, 31, 20, 23, 'S')
    hfill(g, 31, 10, 21, 'Y')          # 윗도리 밑단

    if girl:
        hfill(g, 31, 11, 20, 'Q')      # ---- 치마
        for y in range(32, 37):
            L, R = BODY[y]
            hfill(g, y, L + 1, R - 1, 'p')
            swaprow(g, y, L + 1, L + 2, 'p', 'q')   # 먼 쪽이 그늘
            swap(g, R - 1, y, 'p', 'P')             # 가까운 쪽이 밝다
        for y in range(33, 37):
            swap(g, 11, y, 'p', 'q')
        for y in range(34, 37):
            swap(g, 16, y, 'p', 'q')
        for y in range(33, 36):
            swap(g, 21, y, 'p', 'q')
        hfill(g, 37, 7, 24, 'Q')
        hfill(g, 37, 11, 20, 'Q')
        for y in range(38, 42):        # ---- 맨다리 — 사이는 한 칸
            hfill(g, y, 12, 19, 's')
            put(g, 15, y, 'm')
            swaprow(g, y, 12, 13, 's', 'S')
        hfill(g, 38, 12, 14, 'S')
        hfill(g, 38, 16, 19, 'S')
        hfill(g, 39, 17, 18, 'l')
        hfill(g, 40, 17, 18, 'l')
        band(g, range(42, 46), 12, 19, 'o')         # ---- 단화
        band(g, range(46, 48), 11, 20, 'o')
        for y in range(42, 48):
            put(g, 15, y, 'x')
        hfill(g, 42, 12, 14, 'O')
        hfill(g, 42, 16, 19, 'O')
        for y in range(45, 47):
            swap(g, 14, y, 'o', 'O')
            swap(g, 19, y, 'o', 'O')
            swap(g, 20, y, 'o', 'O')
        hfill(g, 47, 11, 20, 'x')
    else:
        hfill(g, 32, 11, 20, 'Q')      # ---- 바지 — 두 다리가 겹쳐 사이 한 칸
        put(g, 16, 32, 'u')
        band(g, range(33, 42), 11, 20, 'p')
        for y in range(34, 42):
            put(g, 15, y, 'Q')
        for y in range(33, 42):
            swaprow(g, y, 11, 12, 'p', 'q')         # 먼 다리는 그늘
            swaprow(g, y, 19, 20, 'p', 'P')         # 가까운 다리는 밝다
        hfill(g, 41, 11, 14, 'Q')
        hfill(g, 41, 16, 20, 'Q')
        hfill(g, 37, 11, 14, 'q')      # 무릎 — 두 다리 높이를 어긋나게
        hfill(g, 38, 16, 20, 'q')
        band(g, range(42, 46), 11, 20, 'o')         # ---- 장화
        band(g, range(46, 48), 10, 21, 'o')
        for y in range(42, 48):
            put(g, 15, y, 'x')
        hfill(g, 42, 11, 14, 'O')
        hfill(g, 42, 16, 20, 'O')
        hfill(g, 44, 16, 19, 'O')
        for y in range(43, 48):
            swap(g, 14, y, 'o', 'O')
            swap(g, 20, y, 'o', 'O')
            swap(g, 21, y, 'o', 'O')
        hfill(g, 47, 10, 21, 'x')


def build_side(girl):
    """3/4 (대각) — 게임의 좌우 방향에 쓴다. 왼쪽을 볼 때는 통째로 뒤집는다."""
    g = blank()
    draw_head_q(g, girl)
    body_q(g, girl)
    if girl:
        # 긴 머리는 몸보다 뒤·앞에 있으니 몸을 그린 뒤 다시 얹는다.
        # 먼 쪽은 어깨 뒤로 길게, 가까운 쪽은 한 갈래만 짧게 — 그 길이
        # 차이가 3/4 에서 「머리가 뒤로 돌아가 있다」를 읽히게 한다.
        for y in range(21, 30):
            L, R = HEAD_Q_GIRL.get(y, (5, 25))
            # 몸이 차지한 구간을 재서 그 **바로 옆**까지 메운다. 고정된
            # 칸으로 채우면 어깨 폭이 줄마다 달라 사이에 구멍이 뚫린다.
            body = [x for x in range(GW) if g[y][x] != '.']
            b0, b1 = (min(body), max(body)) if body else (12, 20)
            hfill(g, y, L + 1, b0 - 1, 'h')         # 먼 쪽
            if y <= 26:
                hfill(g, y, b1 + 1, R, 'h')         # 가까운 쪽 — 짧게
        rim_right(g, 21, 29, 1, 'd')
        for y in range(15, 22):        # 결 — 길이가 다른 두 도막
            swap(g, 6, y, 'hH', 'd')
        for y in range(24, 29):
            swap(g, 7, y, 'hH', 'd')
    return g


def build_back(girl):
    """뒷모습 — 앞모습 몸을 그대로 쓰고 머리만 통째로 채운다.
    뒤통수에는 얼굴이 없으므로 앞머리·눈·입을 빼고 머릿결과 목만 남긴다."""
    g = (build_girl if girl else build_boy)()
    for y in range(1, 20):         # 머리 자리를 통째로 밀어 흔적을 지운다
        for x in range(GW):
            if g[y][x] != '.':
                g[y][x] = 'h'
    rim_prof(g, 6, PROF_BACK, 'H')  # 명암은 앞모습과 같은 방식으로 다시
    rim_right(g, 3, 19, 2, 'd')
    for x, y0, y1 in ((12, 9, 15), (20, 7, 13)):   # 머릿결 — 두 줄, 길이 다르게
        for y in range(y0, y1 + 1):
            swap(g, x, y, 'hH', 'd')
    hfill(g, 20, 13, 18, 'k')      # 목덜미
    hfill(g, 20, 14, 17, 'S')
    for y in range(21, 32):        # 깃·단추를 지운다 (뒤에는 없다)
        for x in range(11, 21):
            if g[y][x] == 'U':
                g[y][x] = 't'
    if girl:
        # 긴 머리가 등을 덮는다. 몸을 나중에 그리는 바람에 머리가 통째로
        # 가려져 있었다 — 몸 위에 다시 얹는다.
        BACKHAIR = {20: (5, 26), 21: (5, 26), 22: (6, 25), 23: (7, 24),
                    24: (8, 23), 25: (9, 22), 26: (10, 21)}
        shell(g, BACKHAIR, 'h')
        rim_right(g, 20, 26, 2, 'd')
        for x, y0, y1 in ((10, 20, 23), (21, 20, 23)):   # 머릿결
            for y in range(y0, y1 + 1):
                swap(g, x, y, 'hH', 'd')
    return g


def render(g):
    outline_pass(g)
    if SOFT:
        soften(g)
    small = Image.new('RGBA', (GW, GH), (0, 0, 0, 0))
    px = small.load()
    for y in range(GH):
        for x in range(GW):
            ch = g[y][x]
            if ch == '.':
                continue
            c = CHARS.get(ch)
            if c is None:
                raise ValueError('unknown char %r at %d,%d' % (ch, x, y))
            px[x, y] = c + (255,)
    big = small.resize((GW * S, GH * S), Image.NEAREST)
    out = Image.new('RGBA', (OW, OH), (0, 0, 0, 0))
    out.paste(big, (0, YSHIFT))
    return out


def make_view(boy, girl):
    bg = (122, 150, 96, 255)
    pad, gap = 18, 14
    b3 = boy.resize((OW * 3, OH * 3), Image.NEAREST)
    g3 = girl.resize((OW * 3, OH * 3), Image.NEAREST)
    bs = boy.resize((36, 54), Image.NEAREST)      # 게임 실제 크기 (0.28배)
    gs = girl.resize((36, 54), Image.NEAREST)
    W = pad + b3.width + gap + g3.width + 48 + bs.width + gap + gs.width + pad
    H = b3.height + pad * 2
    im = Image.new('RGBA', (W, H), bg)
    x = pad
    im.alpha_composite(b3, (x, pad)); x += b3.width + gap
    im.alpha_composite(g3, (x, pad)); x += g3.width + 48
    base = pad + b3.height
    im.alpha_composite(bs, (x, base - bs.height)); x += bs.width + gap
    im.alpha_composite(gs, (x, base - gs.height))
    return im


# ---------------------------------------------------------------- 검사
def check(name, img):
    msgs = []
    ok = True
    if img.size != (OW, OH):
        ok = False
        msgs.append('%s 크기 %s (기대 128x192)' % (name, img.size))
    px = img.load()
    alphas = set()
    colors = {}
    lowest = -1
    minx, maxx = OW, -1
    for y in range(OH):
        for x in range(OW):
            r, gg, b, a = px[x, y]
            alphas.add(a)
            if a:
                lowest = max(lowest, y)
                minx = min(minx, x); maxx = max(maxx, x)
                colors[(r, gg, b)] = colors.get((r, gg, b), 0) + 1
    if alphas - {0, 255}:
        ok = False
    msgs.append('%s 알파 %s' % (name, sorted(alphas)))
    if lowest != 190:
        ok = False
    msgs.append('%s 발바닥 y=%d (기대 190)' % (name, lowest))
    msgs.append('%s 가로 %d..%d 중심 %.1f (기대 63.5)' % (name, minx, maxx, (minx + maxx) / 2))
    off = [c for c in colors if c not in ALLOWED]
    if off:
        ok = False
    msgs.append('%s 표 밖 색 %d개 %s' % (name, len(off), off[:6]))

    seen = [[False] * OW for _ in range(OH)]
    comps = []
    for y in range(OH):
        for x in range(OW):
            if px[x, y][3] and not seen[y][x]:
                stack = [(x, y)]
                seen[y][x] = True
                n = 0
                while stack:
                    cx, cy = stack.pop()
                    n += 1
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < OW and 0 <= ny < OH and not seen[ny][nx] and px[nx, ny][3]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
                comps.append(n)
    if len(comps) != 1:
        ok = False
    msgs.append('%s 연결 요소 %d개 %s' % (name, len(comps), sorted(comps, reverse=True)[:5]))
    msgs.append('%s 쓴 색 %d종' % (name, len(colors)))
    return ok, msgs


def main():
    out = {}
    for sex, girl in (('boy', False), ('girl', True)):
        out[sex + '_down'] = render((build_girl if girl else build_boy)())
        out[sex + '_side'] = render(build_side(girl))
        out[sex + '_up'] = render(build_back(girl))
    for k, im in out.items():
        im.save(os.path.join(HERE, 'f32e_%s.png' % k))
    boy, girl = out['boy_down'], out['girl_down']
    boy.save(os.path.join(HERE, 'f32e_boy.png'))
    girl.save(os.path.join(HERE, 'f32e_girl.png'))
    make_view(boy, girl).save(os.path.join(HERE, 'f32e_view.png'))
    allok = True
    for nm, im in sorted(out.items()):
        ok, msgs = check(nm, im)
        allok = allok and ok
        for m in msgs:
            print(m)
    print('검사', 'OK' if allok else '실패')


if __name__ == '__main__':
    main()
