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
    """row -> (L, R) 표를 받아 양끝을 윤곽으로, 안쪽을 fill_ch 로 채운다."""
    for y in sorted(table):
        L, R = table[y]
        hfill(g, y, L, R, '#')
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


def outline_pass(g):
    """바깥 공기와 맞닿은 칸을 전부 윤곽으로 — 위·아래 모서리까지 닫는다."""
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
        g[y][x] = '#'


def soften(g):
    """윤곽의 90도 모서리를 한 칸씩 깎는다.

    격자에 그리면 모서리가 전부 직각이라 로봇처럼 보인다. 「바깥과 맞닿은
    윤곽 칸 중 채워진 이웃이 가로 하나·세로 하나뿐인 칸」이 볼록 모서리다.
    그 칸을 지우면 모서리가 대각으로 깎여 선이 둥글어진다."""
    cut = []
    for y in range(GH):
        for x in range(GW):
            if g[y][x] != '#':
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


def draw_head(g, HEAD, BANG, lit_cols, dark_rows, eye_top,
              lash=False, blush_wide=False):
    """머리 덩어리 + 얼굴.
    명암은 실루엣을 따라가는 띠로 넣는다 — 자로 그은 사선도, 네모 딱지도 안 생긴다."""
    shell(g, HEAD, 'h')

    # --- 얼굴을 도려낸다
    for y in sorted(FACE):
        L, R = FACE[y]
        put(g, L, y, 'D' if g[y][L - 1] in HAIRCH else '#')
        put(g, R, y, 'D' if g[y][R + 1] in HAIRCH else '#')
        hfill(g, y, L + 1, R - 1, 's')
    hfill(g, 20, 12, 19, '#')
    hfill(g, 20, 14, 17, 'S')            # 목 (턱 그늘)

    # --- 앞머리: 눈 바로 위까지 내려온다 (이마가 텅 빈 살구색 판이 되지 않게)
    for c, bot in BANG.items():
        for y in range(6, bot + 1):
            put(g, c, y, 'h')

    # --- 위 테두리를 따라 밝은 띠 (빛은 왼쪽 위에서 온다)
    rim_top(g, lit_cols[0], lit_cols[1], 3, 'H')
    # --- 오른쪽 테두리를 따라 그늘 띠
    rim_right(g, dark_rows[0], dark_rows[1], 2, 'd')

    # --- 앞머리 끝은 가장 어두운 머리색 — 살결과 부딪혀 선처럼 읽힌다
    for c, bot in BANG.items():
        swap(g, c, bot, HAIRCH, 'D')

    # --- 살결 명암 (세로 면 세 장. 그라데이션·디더 금지)
    for y in range(11, 18):
        swap(g, 10, y, 's', 'l')
        swap(g, 21, y, 's', 'S')
    hfill(g, 19, 12, 19, 'S')

    # --- 눈 (3칸 폭 x 3줄). 바깥 아래 모서리를 깎아 둥글게, 흰자 한 칸을 넣는다
    t = eye_top
    for y in (t, t + 1):
        hfill(g, y, EL, EL + 2, 'e')
        hfill(g, y, ER, ER + 2, 'e')
    hfill(g, t + 2, EL + 1, EL + 2, 'e')
    hfill(g, t + 2, ER, ER + 1, 'e')
    put(g, EL, t + 1, 'W')               # 반사점 — 원본 자리 (옮겨 봤더니
    put(g, ER + 2, t + 1, 'W')           # 오히려 이상해서 되돌렸다)
    if lash:
        put(g, EL, t + 2, 'e')
        put(g, ER + 2, t + 2, 'e')

    # --- 볼 · 입
    cheek = t + 4                        # 눈에서 한 줄 떼어야 볼로 읽힌다
    for x in (10, 11):
        swap(g, x, cheek, 'sl', 'c')
    for x in (20, 21):
        swap(g, x, cheek, 'sS', 'c')
    if blush_wide:
        swap(g, 12, cheek, 's', 'c')
        swap(g, 19, cheek, 's', 'c')
    # 입 — 원본대로 두 칸. 네 칸으로 넓히면 벌린 입이 되고, 양끝을 한 줄
    # 올리면 32칸에서는 칸 사이가 벌어져 점 세 개로 읽힌다. 아랫입술에 빛을
    # 한 줄 둬 봤더니 턱 그늘 위에 얹혀 염소수염이 됐다 — 그것도 뺐다
    hfill(g, cheek + 2, 15, 16, 'm')


# ================================================================ 남자
def build_boy():
    g = blank()

    # 정수리가 오른쪽으로 쏠린 가르마, 왼쪽 구레나룻이 두 줄 더 길다
    HEAD = {
        1: (13, 20), 2: (11, 22), 3: (10, 23), 4: (8, 24), 5: (7, 24),
        6: (7, 25), 7: (6, 25), 8: (6, 25), 9: (6, 25), 10: (6, 25),
        11: (6, 25), 12: (6, 25), 13: (7, 25), 14: (7, 24), 15: (8, 23),
        16: (8, 23), 17: (9, 22), 18: (10, 21), 19: (11, 20), 20: (12, 19),
    }
    # 눈이 놓이는 칸(11~13 · 18~20)은 끝 줄이 11을 넘으면 안 된다 —
    # 넘으면 앞머리가 눈꺼풀을 덮어 한쪽 눈만 감은 것처럼 보인다
    BANG = {10: 12, 11: 11, 12: 10, 13: 10, 14: 10, 15: 10,
            16: 10, 17: 11, 18: 11, 19: 11, 20: 11, 21: 12}
    draw_head(g, HEAD, BANG, lit_cols=(6, 22), dark_rows=(3, 17), eye_top=12)


    # ================================ 몸
    BODY = {21: (10, 21), 22: (8, 23)}
    for y in range(23, 28):
        BODY[y] = (7, 24)
    for y in range(28, 32):
        BODY[y] = (6, 25)          # 손이 벙어리장갑처럼 바깥으로 불룩
    BODY[32] = (10, 21)
    for y in range(33, 46):
        BODY[y] = (10, 21)
    for y in range(46, 48):
        BODY[y] = (9, 22)
    shell(g, BODY, 't')

    # 옷깃 두 장 사이로 목이 보인다
    hfill(g, 21, 13, 14, 'U')
    hfill(g, 21, 17, 18, 'U')
    hfill(g, 21, 15, 16, 'S')
    # 팔과 몸통 사이 검정 줄
    for y in range(23, 32):
        put(g, 10, y, '#')
        put(g, 21, y, '#')
    # 소매 (왼쪽이 빛, 오른쪽이 그늘)
    for y in range(23, 28):
        L, R = BODY[y]
        hfill(g, y, L + 1, 9, 't')
        hfill(g, y, 22, R - 1, 't')
        swap(g, R - 1, y, 't', 'y')
    for y in (23, 24, 25):
        put(g, 8, y, 'T')
    hfill(g, 27, 8, 9, 'U')        # 걷어올린 소맷단 — 밝은 색이라야 보인다
    hfill(g, 27, 22, 23, 'U')
    # 손 (벙어리장갑처럼 도톰하게)
    for y in range(28, 32):
        hfill(g, y, 7, 9, 's')
        hfill(g, y, 22, 24, 's')
    hfill(g, 28, 7, 8, 'l')
    hfill(g, 29, 7, 8, 'l')
    hfill(g, 31, 7, 9, 'S')
    hfill(g, 31, 22, 24, 'S')
    swap(g, 24, 30, 's', 'S')
    # 몸통: 밝은 면 / 기본 / 그늘 세 장
    for y in range(22, 32):
        swaprow(g, y, 11, 12, 't', 'T')
        swap(g, 20, y, 't', 'y')
    swaprow(g, 22, 10, 11, 't', 'T')
    swap(g, 21, 22, 't', 'y')
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
    hfill(g, 37, 11, 14, 'q')          # 무릎 주름
    hfill(g, 37, 17, 20, 'q')
    for y in range(43, 48):
        swap(g, 14, y, 'o', 'O')
        swap(g, 20, y, 'o', 'O')
        swap(g, 21, y, 'o', 'O')
    hfill(g, 47, 10, 21, 'x')
    return g


# ================================================================ 여자
def build_girl():
    g = blank()

    # 위는 좁고, 어깨께에서 한 번 퍼졌다가 끝이 뾰족해지는 긴 머리
    HEAD = {
        1: (13, 19), 2: (11, 21), 3: (10, 22), 4: (9, 23), 5: (8, 24),
        6: (7, 25), 7: (6, 25), 8: (6, 26), 9: (5, 26), 10: (5, 26),
        11: (6, 25), 12: (6, 26), 13: (5, 26), 14: (5, 26), 15: (5, 26),
        16: (5, 26), 17: (5, 26), 18: (4, 27), 19: (4, 27), 20: (4, 27),
        21: (4, 27), 22: (4, 26), 23: (5, 26), 24: (5, 25), 25: (6, 25),
        26: (6, 24), 27: (7, 24), 28: (7, 23), 29: (8, 23),
    }
    BANG = {10: 12, 11: 10, 12: 10, 13: 10, 14: 10, 15: 10,
            16: 10, 17: 10, 18: 10, 19: 10, 20: 10, 21: 12}
    draw_head(g, HEAD, BANG, lit_cols=(4, 22), dark_rows=(4, 29),
              eye_top=12, lash=True, blush_wide=True)

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
    BODY = {21: (10, 21), 22: (9, 22)}
    for y in range(23, 29):
        BODY[y] = (8, 23)
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

    # 옷깃
    hfill(g, 21, 13, 14, 'U')
    hfill(g, 21, 17, 18, 'U')
    hfill(g, 21, 15, 16, 'S')
    # 팔과 몸통 사이 검정 줄
    for y in range(23, 32):
        put(g, 11, y, '#')
        put(g, 20, y, '#')
    # 짧은 소매
    for y in range(23, 27):
        L, R = BODY[y]
        hfill(g, y, L + 1, 10, 't')
        hfill(g, y, 21, R - 1, 'y')
    for y in (23, 24):
        put(g, 9, y, 'T')
    hfill(g, 26, 9, 10, 'U')
    hfill(g, 26, 21, 22, 'U')
    # 맨팔 · 손
    for y in range(27, 29):
        hfill(g, y, 9, 10, 's')
        hfill(g, y, 21, 22, 'S')
    for y in range(29, 32):
        hfill(g, y, 8, 10, 's')
        hfill(g, y, 21, 23, 's')
    hfill(g, 29, 8, 9, 'l')
    hfill(g, 30, 8, 9, 'l')
    hfill(g, 31, 21, 23, 'S')
    # 상의 명암
    for y in range(22, 32):
        swaprow(g, y, 12, 13, 't', 'T')
        swap(g, 19, y, 't', 'y')

    # ---- 치마
    hfill(g, 31, 12, 19, 'Q')
    for y in range(32, 37):
        L, R = BODY[y]
        hfill(g, y, L + 1, R - 1, 'p')
        swaprow(g, y, L + 1, L + 2, 'p', 'P')
        swap(g, R - 1, y, 'p', 'q')
    for y in range(33, 37):
        swap(g, 11, y, 'p', 'q')    # 주름
        swap(g, 16, y, 'p', 'q')
        swap(g, 21, y, 'p', 'q')
    hfill(g, 37, 7, 24, '#')
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
    boy = render(build_boy())
    girl = render(build_girl())
    boy.save(os.path.join(HERE, 'f32d_boy.png'))
    girl.save(os.path.join(HERE, 'f32d_girl.png'))
    make_view(boy, girl).save(os.path.join(HERE, 'f32d_view.png'))
    allok = True
    for nm, im in (('boy ', boy), ('girl', girl)):
        ok, msgs = check(nm, im)
        allok = allok and ok
        for m in msgs:
            print(m)
    print('검사', 'OK' if allok else '실패')


if __name__ == '__main__':
    main()
