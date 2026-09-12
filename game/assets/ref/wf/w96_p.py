#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""리틀 루트 주인공 도트 — 96 x 144 (청키 레트로).  방향 p.

참고 그림에서 읽어낸 문법:
  - 눈 하나 = 얼굴 폭의 1/4 안팎, 두 눈 사이에 눈 하나 폭만큼 비운다
  - 눈테는 살결 진한 단(SK_M / SK_DD), EYE 는 속눈썹 윗줄만
  - 흰자를 동공 양옆에 두지 않는다 (홍채로 채우고 캐치라이트만)
  - 입은 눈보다 넓게, 크게 벌린 웃는 입
  - 코는 콧등 + 콧방울 + 그늘
  - 주근깨 같은 점 장식은 두 칸 단위
실행: python3 w96_p.py
"""
from PIL import Image

W, H = 96, 144

SK, SK_L, SK_D            = (243,159,138), (250,192,170), (213,116,98)
SK_CH, SK_M, SK_DD, SK_LL = (235,128,114), (170,84,66), (184,99,83), (252,217,204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118,72,40), (152,100,56), (86,52,30), (58,35,20), (195,165,140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58,88,168), (38,58,120), (94,126,200), (27,41,84), (166,184,225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134,88,46), (98,62,32), (158,108,58), (69,43,22), (202,174,147)
SO, SO_D, SO_DD           = (82,53,33), (56,37,25), (39,26,18)
OL, EYE, BROW, WHT        = (26,20,28), (66,32,30), (136,70,42), (246,242,234)

BASE = {'skin': SK, 'hair': HR, 'shirt': SH, 'pants': PT, 'shoe': SO}
DARK = {'skin': SK_DD, 'hair': HR_DD, 'shirt': SH_DD, 'pants': PT_DD, 'shoe': SO_DD}
SKIN, HAIR = ('skin',), ('hair',)


# ----------------------------------------------------------------- 캔버스
class Cv(object):
    def __init__(self):
        self.col = {}
        self.mat = {}

    def put(self, x, y, m, c=None):
        if 0 <= x < W and 0 <= y < H:
            self.col[(x, y)] = BASE[m] if c is None else c
            self.mat[(x, y)] = m

    def paint(self, x, y, c, only=None):
        """이미 칠해진 칸의 색만 바꾼다 — 실루엣 밖으로 새지 않게."""
        k = (x, y)
        if k in self.col and (only is None or self.mat[k] in only):
            self.col[k] = c

    def hpaint(self, y, x0, x1, c, only=None):
        for x in range(x0, x1 + 1):
            self.paint(x, y, c, only)

    def band(self, rows, m, c=None):
        for y in sorted(rows):
            for a, b in rows[y]:
                for x in range(a, b + 1):
                    self.put(x, y, m, c)

    def runs(self, y, m):
        out, a = [], None
        for x in range(W):
            hit = self.mat.get((x, y)) == m
            if hit and a is None:
                a = x
            elif not hit and a is not None:
                out.append((a, x - 1)); a = None
        if a is not None:
            out.append((a, W - 1))
        return out


def mirror_rows(rows):
    return dict((y, [(95 - b, 95 - a) for a, b in sp]) for y, sp in rows.items())


def merge(*ds):
    out = {}
    for d in ds:
        for y, sp in d.items():
            out.setdefault(y, []).extend(sp)
    return out


def span_rows(tbl):
    """[(y0,y1,x0,x1), ...] -> {y: [(x0,x1)]}"""
    out = {}
    for y0, y1, x0, x1 in tbl:
        for y in range(y0, y1 + 1):
            out.setdefault(y, []).append((x0, x1))
    return out


def curve(pairs):
    """몇 점을 x 로 선형 보간해 {x: y}."""
    out = {}
    for i in range(len(pairs) - 1):
        x0, y0 = pairs[i]
        x1, y1 = pairs[i + 1]
        for x in range(x0, x1 + 1):
            t = 0.0 if x1 == x0 else float(x - x0) / (x1 - x0)
            out[x] = int(round(y0 + (y1 - y0) * t))
    return out


# ------------------------------------------------------------- 윤곽/음영
NEI = ((1, 0), (-1, 0), (0, 1), (0, -1))


def outline(cv, m, against):
    hit = []
    for (x, y), mm in cv.mat.items():
        if mm != m:
            continue
        for dx, dy in NEI:
            if cv.mat.get((x + dx, y + dy)) in against:
                hit.append((x, y)); break
    d = DARK[m]
    for p in hit:
        cv.col[p] = d


def all_outlines(cv):
    outline(cv, 'hair',  (None, 'skin', 'shirt', 'pants'))
    outline(cv, 'skin',  (None,))
    outline(cv, 'shirt', (None, 'skin'))
    outline(cv, 'pants', (None, 'shirt', 'skin'))
    outline(cv, 'shoe',  (None, 'pants', 'skin'))


def edge_shade(cv, m, light, dark, minw=6, y0=0, y1=H, lw=1, dw=2):
    for y in range(y0, y1):
        for a, b in cv.runs(y, m):
            if b - a + 1 < minw:
                continue
            for i in range(lw):
                cv.paint(a + 1 + i, y, light, (m,))
            for i in range(dw):
                cv.paint(b - 1 - i, y, dark, (m,))


def under_hair_shadow(cv):
    """앞머리 그늘 — 가로로 두 칸 이상 이어질 때만 (한 칸짜리 먼지 금지)."""
    cand = set(p for p, mm in cv.mat.items()
               if mm == 'skin' and cv.mat.get((p[0], p[1] - 1)) == 'hair')
    for (x, y) in cand:
        if ((x - 1, y) in cand or (x + 1, y) in cand) and cv.col[(x, y)] != SK_DD:
            cv.col[(x, y)] = SK_D


def hair_tone(cv, ex, ey, rx, ry, ymax, t1=0.55, t2=1.9):
    """빛은 왼쪽 위.  두개골을 따라 도는 동심 띠 — 면마다 단색."""
    for (x, y), m in list(cv.mat.items()):
        if m != 'hair' or y > ymax:
            continue
        d = ((x - ex) / float(rx)) ** 2 + ((y - ey) / float(ry)) ** 2
        cv.col[(x, y)] = HR_L if d < t1 else (HR if d < t2 else HR_D)


def fringe_shade(cv, depth=2):
    """앞머리·목덜미 끝 두 줄을 진한 단으로."""
    tgt = [p for p, m in cv.mat.items()
           if m == 'hair' and cv.mat.get((p[0], p[1] + depth)) != 'hair'
           and cv.mat.get((p[0], p[1] + 1)) == 'hair']
    for p in tgt:
        cv.col[p] = HR_D


def hair_rimlight(cv, ex, ey, rx, ry, ylim=16):
    """실루엣 상좌측 테 안쪽 한 줄만 아주 밝게 — 앞머리 끝에는 찍지 않는다."""
    edge = set(p for p, c in cv.col.items() if cv.mat.get(p) == 'hair' and c == HR_DD)
    got = []
    for (x, y) in list(cv.col.keys()):
        if cv.mat.get((x, y)) != 'hair' or (x, y) in edge or not (2 < y < ylim):
            continue
        if cv.mat.get((x, y + 1)) != 'hair' or cv.mat.get((x, y + 2)) != 'hair':
            continue
        if (x, y - 1) in edge or (x - 1, y) in edge:
            if ((x - ex) / float(rx)) ** 2 + ((y - ey) / float(ry)) ** 2 < 1.0:
                got.append((x, y))
    keep = set(got)
    for p in got:              # 이웃 없는 한 칸은 버린다
        x, y = p
        if any((x + dx, y + dy) in keep for dx, dy in
               ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1))):
            cv.col[p] = HR_LL


FAR = {SK: SK_D, SK_L: SK, SK_D: SK_M, SK_LL: SK_L, SK_CH: SK_M,
       PT: PT_D, PT_L: PT, PT_D: PT_DD,
       SH: SH_D, SH_L: SH, SH_D: SH_DD,
       SO: SO_D, SO_D: SO_DD}


def push_back(cv, x0, x1, y0, y1):
    """먼 쪽 팔·다리를 한 단 어둡게 — 뒤로 물러나 보이게."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = cv.col.get((x, y))
            if c in FAR:
                cv.col[(x, y)] = FAR[c]


def strand(cv, x0, y0, n, slope, col=HR_D, w=2):
    """짧고 비스듬한 결.  정수리부터 끝까지 곧게 긋지 않는다."""
    x = float(x0)
    for i in range(n):
        for k in range(w):
            cv.paint(int(round(x)) + k, y0 + i, col, HAIR)
        x += slope


# ------------------------------------------------------- 눈 · 입 (도안)
EYE10 = (".LLLLLLLL.",
         "mDDDDDDDDm",
         "mDWWNNNIDm",
         "mIWWNNNIDm",
         "mIINNNNIDm",
         "mIINNNNIIm",
         "mIIINNIIIm",
         ".dIIIIIId.",
         "..dddddd..")

EYE7 = (".LLLLL.",
        "mDDDDDm",
        "mWWNNDm",
        "mWWNNDm",
        "mINNNDm",
        "mINNNIm",
        "mIINNIm",
        ".dIIId.",
        "..ddd..")

EYEMAP = {'L': EYE, 'm': SK_M, 'd': SK_DD, 'W': WHT,
          'D': HR_D, 'I': HR, 'N': HR_DD}

MOUTH = ("mm........mm",
         "mmmmmmmmmmmm",
         ".mmWWWWWWmm.",
         ".mEEEEEEEEm.",
         "..mEccccEm..",
         "...mmmmmm...",
         "....DDDD....")

MOUTHMAP = {'m': SK_M, 'W': WHT, 'E': EYE, 'c': SK_CH, 'D': SK_D}


def draw_eye(cv, x0, y0, pat):
    for j, row in enumerate(pat):
        for i, ch in enumerate(row):
            if ch != '.':
                cv.paint(x0 + i, y0 + j, EYEMAP[ch], SKIN)


def draw_mouth(cv, x0, y0):
    for j, row in enumerate(MOUTH):
        for i, ch in enumerate(row):
            if ch != '.':
                cv.paint(x0 + i, y0 + j, MOUTHMAP[ch], SKIN)


def draw_brow(cv, y, xa0, xa1, xb0, xb1):
    cv.hpaint(y, xa0, xa1, BROW, SKIN)
    cv.hpaint(y + 1, xb0, xb1, BROW, SKIN)


def draw_nose_front(cv, cx, y0):
    """콧등(밝은 단) + 콧방울(진한 단) + 아래 그늘.  cx, cx+1 이 콧등."""
    cv.hpaint(y0,     cx,     cx + 1, SK_L, SKIN)
    cv.hpaint(y0 + 1, cx - 1, cx + 1, SK_L, SKIN)
    cv.paint(cx + 2,  y0 + 1, SK_D, SKIN)
    cv.hpaint(y0 + 2, cx - 2, cx - 1, SK_M, SKIN)
    cv.hpaint(y0 + 2, cx,     cx + 1, SK_D, SKIN)
    cv.hpaint(y0 + 2, cx + 2, cx + 3, SK_M, SKIN)


def draw_nose_side(cv, x0, y0):
    """3/4 — 콧등이 비스듬히 내려와 먼 쪽에서 코끝·콧방울·그늘."""
    cv.hpaint(y0,     x0,     x0 + 1, SK_L, SKIN)
    cv.hpaint(y0 + 1, x0 + 1, x0 + 2, SK_L, SKIN)
    cv.paint(x0 + 3,  y0 + 1, SK_D, SKIN)
    cv.hpaint(y0 + 2, x0 + 2, x0 + 3, SK_L, SKIN)
    cv.hpaint(y0 + 2, x0 + 4, x0 + 5, SK_D, SKIN)
    cv.hpaint(y0 + 3, x0 + 1, x0 + 2, SK_M, SKIN)
    cv.hpaint(y0 + 3, x0 + 3, x0 + 4, SK_D, SKIN)
    cv.hpaint(y0 + 3, x0 + 5, x0 + 6, SK_M, SKIN)


def blush(cv, y0, x0, x1):
    """눈 아래, 넓고 흐리게 — 네모가 아니라 렌즈꼴."""
    cv.hpaint(y0,     x0 + 1, x1 - 1, SK_CH, SKIN)
    cv.hpaint(y0 + 1, x0,     x1,     SK_CH, SKIN)
    cv.hpaint(y0 + 2, x0,     x1,     SK_CH, SKIN)
    cv.hpaint(y0 + 3, x0 + 1, x1 - 1, SK_CH, SKIN)


def freckles(cv, pts):
    """두 칸 단위 — 한 칸짜리 먼지를 만들지 않는다."""
    for x, y in pts:
        cv.paint(x, y, SK_D, SKIN)
        cv.paint(x + 1, y, SK_D, SKIN)


def ear(cv, left=True, y0=31, y1=37, big=False):
    """얼굴에 붙은 귀 — 옆으로 튀어나온 타원이 아니라 실루엣 안쪽 단."""
    xs = (28, 29, 30, 31, 32) if left else (67, 66, 65, 64, 63)
    n = 5 if big else 3
    for y in range(y0, y1 + 1):
        cv.paint(xs[0], y, SK_DD, SKIN)
        for k in range(1, n - 1):
            cv.paint(xs[k], y, SK_D, SKIN)
        cv.paint(xs[n - 1], y, SK_M, SKIN)
    for y in range(y0 + 2, y1 - 1):
        for k in range(1, n - 1):
            cv.paint(xs[k], y, SK, SKIN)


# --------------------------------------------------------------- 머리 형태
HEAD_TOP = [(1, 38, 57), (2, 36, 59), (3, 34, 61), (4, 33, 62), (5, 32, 63),
            (6, 31, 64), (7, 30, 65), (8, 30, 65), (9, 29, 66), (10, 29, 66)]

HEAD_JAW_F = [(42, 29, 66), (43, 30, 65), (44, 31, 64), (45, 32, 63),
              (46, 34, 61), (47, 36, 59), (48, 39, 56), (49, 41, 54),
              (50, 43, 52), (51, 45, 50)]

# 3/4 — 턱이 돌아선 쪽(오른쪽)으로 쏠린다
HEAD_JAW_S = [(42, 29, 66), (43, 30, 66), (44, 31, 66), (45, 33, 65),
              (46, 35, 64), (47, 38, 62), (48, 41, 61), (49, 44, 59),
              (50, 47, 57), (51, 50, 55)]

HEAD_JAW_U = [(42, 28, 67), (43, 28, 67), (44, 29, 66), (45, 30, 65),
              (46, 32, 63), (47, 35, 60), (48, 38, 57)]


def head_span(jaw):
    d = dict((y, (a, b)) for y, a, b in HEAD_TOP)
    for y in range(11, 42):
        d[y] = (28, 67)
    for y, a, b in jaw:
        d[y] = (a, b)
    return d


BANG_BOY = curve([(28, 27), (30, 27), (31, 25), (33, 22), (35, 18), (38, 19),
                  (41, 16), (44, 18), (47, 19), (50, 16), (53, 18), (56, 19),
                  (59, 17), (61, 19), (63, 23), (65, 27), (67, 27)])

BANG_GIRL = curve([(29, 31), (31, 27), (33, 22), (35, 19), (38, 18), (41, 17),
                   (44, 19), (47, 17), (50, 18), (53, 17), (56, 19), (59, 18),
                   (61, 20), (63, 25), (66, 31)])

BANG_SIDE = curve([(28, 29), (32, 29), (33, 26), (35, 23), (37, 20), (40, 18),
                   (43, 20), (46, 17), (49, 19), (52, 18), (55, 17), (58, 18),
                   (61, 18), (63, 19), (65, 21), (66, 24), (67, 27)])

BANG_GIRL_SIDE = curve([(28, 33), (31, 32), (33, 28), (35, 24), (37, 21),
                        (40, 19), (43, 21), (46, 18), (49, 20), (52, 19),
                        (55, 18), (58, 19), (61, 19), (63, 20), (65, 22),
                        (66, 25), (67, 28)])

NAPE_BOY = curve([(28, 37), (31, 43), (35, 46), (39, 48), (43, 50), (51, 50),
                  (55, 48), (59, 46), (63, 43), (67, 37)])

NAPE_GIRL = curve([(28, 44), (32, 47), (38, 48), (44, 48), (51, 48),
                   (57, 48), (63, 47), (67, 44)])


def build_head(cv, span, bang, face=True):
    for y in sorted(span):
        a, b = span[y]
        for x in range(a, b + 1):
            if y <= bang.get(x, -99):
                cv.put(x, y, 'hair')
            elif face:
                cv.put(x, y, 'skin')


# ---------------------------------------------------- 여자 머리 덩어리
LOCK_FRONT = span_rows([(15, 19, 27, 29), (20, 40, 26, 28), (41, 48, 26, 30),
                        (49, 64, 26, 31), (65, 72, 27, 31), (73, 78, 28, 31),
                        (79, 81, 29, 31)])

# 3/4 — 뒤통수 쪽(우리 왼쪽)으로 머리가 쏠려 길게 흐르고 가까운 쪽은 짧다
LOCK_SIDE_BACK = span_rows([(16, 24, 26, 30), (25, 44, 25, 31), (45, 62, 25, 32),
                            (63, 74, 26, 32), (75, 84, 27, 31), (85, 90, 28, 31)])
LOCK_SIDE_NEAR = span_rows([(20, 26, 65, 67), (27, 42, 65, 68), (43, 50, 65, 68),
                            (51, 55, 66, 68), (56, 58, 67, 68)])

TAIL_UP = span_rows([(42, 47, 39, 56), (48, 51, 41, 54), (52, 68, 38, 57),
                     (69, 76, 39, 56), (77, 82, 40, 55), (83, 86, 42, 53),
                     (87, 89, 44, 51), (90, 91, 46, 49)])


# ------------------------------------------------------------------ 몸통
def arm_rows(sleeve_end, hand_top=85, hand_bot=90):
    sl = {58: [(32, 34)], 59: [(31, 34)], 60: [(30, 33)]}
    for y in range(61, sleeve_end + 1):
        sl[y] = [(29, 33)]
    sk = {}
    for y in range(sleeve_end + 1, hand_top):
        sk[y] = [(30, 33)]
    for y in range(hand_top, hand_bot):
        sk[y] = [(29, 33)]
    sk[hand_bot] = [(30, 33)]
    return sl, sk


TORSO_F = span_rows([(55, 55, 41, 54), (56, 56, 38, 57), (57, 57, 36, 59),
                     (58, 58, 34, 61), (59, 76, 34, 61), (77, 91, 35, 60)])

# 3/4 — 어깨가 비틀려 가까운(왼) 어깨가 한 줄 늦게 더 멀리 벌어진다
TORSO_S = span_rows([(55, 55, 43, 55), (56, 56, 40, 57), (57, 57, 36, 59),
                     (58, 58, 34, 60), (59, 76, 33, 60), (77, 91, 34, 59)])

PANTS_BOY = span_rows([(92, 98, 35, 60)])
for _y in range(99, 126):
    PANTS_BOY.setdefault(_y, []).extend([(35, 45), (50, 60)])
BOOT_BOY = span_rows([(126, 137, 34, 46), (126, 137, 49, 61),
                      (138, 142, 33, 46), (138, 142, 49, 62)])

PANTS_SIDE = span_rows([(92, 98, 34, 59)])
for _y in range(99, 126):
    PANTS_SIDE.setdefault(_y, []).extend([(35, 46), (49, 57)])
BOOT_SIDE = span_rows([(126, 137, 34, 47), (125, 135, 49, 57),
                       (138, 142, 33, 48), (136, 140, 49, 59)])

SKIRT_GIRL = span_rows([(92, 95, 35, 60), (96, 97, 34, 61), (98, 99, 33, 62),
                        (100, 101, 32, 63), (102, 103, 31, 64), (104, 111, 30, 65)])
LEG_GIRL = span_rows([(112, 134, 37, 44), (112, 134, 51, 58)])
SHOE_GIRL = span_rows([(135, 139, 36, 45), (135, 139, 50, 59),
                       (140, 142, 35, 46), (140, 142, 49, 60)])

SKIRT_SIDE = span_rows([(92, 95, 34, 60), (96, 97, 33, 61), (98, 99, 32, 62),
                        (100, 101, 31, 63), (102, 103, 30, 64), (104, 111, 29, 64)])
LEG_SIDE = span_rows([(112, 134, 37, 45), (112, 133, 49, 56)])
SHOE_SIDE = span_rows([(135, 139, 36, 46), (133, 137, 48, 56),
                       (140, 142, 35, 48), (138, 140, 48, 58)])


# ---------------------------------------------------------------- 옷 장식
def shirt_detail(cv, front=True, cx=47):
    for y in (55, 56):
        for a, b in cv.runs(y, 'shirt'):
            cv.hpaint(y, a + 1, b - 1, SH_L, ('shirt',))
    for a, b in cv.runs(57, 'shirt'):
        if b - a > 6:
            cv.hpaint(57, a + 2, b - 2, SH_L, ('shirt',))
    for y in range(58, 92):
        for a, b in cv.runs(y, 'shirt'):
            if b - a > 8:
                cv.hpaint(y, b - 2, b - 1, SH_D, ('shirt',))
                cv.paint(a + 1, y, SH_L, ('shirt',))
    if front:
        for y in range(63, 88, 7):
            cv.hpaint(y, cx - 1, cx, SH_D, ('shirt',))
            cv.hpaint(y + 1, cx - 1, cx, SH_D, ('shirt',))
    for y in (89, 90):
        for a, b in cv.runs(y, 'shirt'):
            if b - a > 8:
                cv.hpaint(y, a + 2, b - 3, SH_D, ('shirt',))


def pants_detail(cv, skirt=False):
    for y in range(92, 143):
        for a, b in cv.runs(y, 'pants'):
            if b - a > 5:
                cv.paint(a + 1, y, PT_L, ('pants',))
                cv.hpaint(y, b - 2, b - 1, PT_D, ('pants',))
    for y in (92, 93):
        for a, b in cv.runs(y, 'pants'):
            cv.hpaint(y, a + 1, b - 1, PT_D, ('pants',))
    if skirt:
        for x0, y0, n in ((40, 100, 10), (53, 98, 12)):
            for i in range(n):
                cv.paint(x0 + i // 4, y0 + i, PT_D, ('pants',))
                cv.paint(x0 + 1 + i // 4, y0 + i, PT_D, ('pants',))


def shoe_detail(cv):
    for y in range(120, 143):
        for a, b in cv.runs(y, 'shoe'):
            if b - a > 4:
                cv.paint(a + 1, y, SO, ('shoe',))
                cv.hpaint(y, b - 2, b - 1, SO_D, ('shoe',))


# ------------------------------------------------------------- 얼굴 조립
EYE_Y, BROW_Y = 25, 21


def face_front(cv):
    blush(cv, 35, 30, 38)
    blush(cv, 35, 57, 65)
    draw_brow(cv, BROW_Y, 34, 41, 33, 40)
    draw_brow(cv, BROW_Y, 54, 61, 55, 62)
    draw_eye(cv, 33, EYE_Y, EYE10)
    draw_eye(cv, 53, EYE_Y, EYE10)
    draw_nose_front(cv, 47, 36)
    draw_mouth(cv, 42, 42)
    freckles(cv, [(31, 39), (35, 39), (33, 41),
                  (60, 39), (64, 39), (62, 41)])


def face_side(cv):
    blush(cv, 34, 35, 43)
    blush(cv, 33, 62, 67)
    draw_brow(cv, BROW_Y, 46, 53, 45, 52)
    draw_brow(cv, BROW_Y, 59, 65, 60, 66)
    draw_eye(cv, 45, EYE_Y, EYE10)
    draw_eye(cv, 59, EYE_Y, EYE7)
    draw_nose_side(cv, 55, 36)
    draw_mouth(cv, 48, 42)
    freckles(cv, [(36, 39), (40, 39), (38, 41), (63, 39)])


# ------------------------------------------------------------------ 조립
def build(sex, kind):
    cv = Cv()
    girl = (sex == 'girl')
    side = (kind == 'side')
    up = (kind == 'up')

    # 1) 여자 뒷머리 — 몸보다 뒤
    if girl and not up:
        if side:
            cv.band(LOCK_SIDE_BACK, 'hair')
        else:
            cv.band(merge(LOCK_FRONT, mirror_rows(LOCK_FRONT)), 'hair')

    # 2) 목
    cv.band(span_rows([(45 if up else 52, 56, 43, 52)]), 'skin')

    # 3) 몸통
    cv.band(TORSO_S if side else TORSO_F, 'shirt')

    # 4) 다리
    if girl:
        cv.band(SKIRT_SIDE if side else SKIRT_GIRL, 'pants')
        cv.band(LEG_SIDE if side else LEG_GIRL, 'skin')
        cv.band(SHOE_SIDE if side else SHOE_GIRL, 'shoe')
    else:
        cv.band(PANTS_SIDE if side else PANTS_BOY, 'pants')
        cv.band(BOOT_SIDE if side else BOOT_BOY, 'shoe')

    # 5) 여자 뒷모습 머리 타래 — 몸 위, 팔 아래
    if girl and up:
        cv.band(TAIL_UP, 'hair')

    # 6) 팔 — 3/4 에서는 먼 팔이 어둡고 작고 뒤에
    se = 70 if girl else 73
    if side:
        cv.band(span_rows([(56, 56, 58, 61), (57, se - 2, 59, 62)]), 'shirt')
        cv.band(span_rows([(se - 1, 80, 59, 61), (81, 85, 59, 62),
                           (86, 86, 59, 61)]), 'skin')
        near_sl = {59: [(30, 34)], 60: [(29, 34)]}
        for y in range(61, se + 1):
            near_sl[y] = [(28, 33)]
        near_sk = {}
        for y in range(se + 1, 85):
            near_sk[y] = [(29, 33)]
        for y in range(85, 91):
            near_sk[y] = [(28, 33)]
        near_sk[91] = [(29, 33)]
        cv.band(near_sl, 'shirt')
        cv.band(near_sk, 'skin')
    else:
        sl, sk = arm_rows(se)
        cv.band(merge(sl, mirror_rows(sl)), 'shirt')
        cv.band(merge(sk, mirror_rows(sk)), 'skin')

    # 7) 머리
    if up:
        build_head(cv, head_span(HEAD_JAW_U),
                   NAPE_GIRL if girl else NAPE_BOY, face=False)
        if not girl:      # 뒤에서도 귀는 보인다
            for y in range(30, 37):
                for x in (28, 29, 30):
                    cv.put(x, y, 'skin', SK_D)
                    cv.put(95 - x, y, 'skin', SK_D)
    elif side:
        build_head(cv, head_span(HEAD_JAW_S),
                   BANG_GIRL_SIDE if girl else BANG_SIDE)
    else:
        build_head(cv, head_span(HEAD_JAW_F), BANG_GIRL if girl else BANG_BOY)

    # 8) 여자 가까운 쪽 짧은 갈래 — 얼굴 위
    if girl and side:
        cv.band(LOCK_SIDE_NEAR, 'hair')

    # 9) 윤곽 + 재질 음영
    all_outlines(cv)
    ex, ey, ymax = (38, 11, 45) if not up else (34, 5, 52)
    hair_tone(cv, ex, ey, 15, 13, ymax,
              t1=0.55 if not up else 1.05, t2=1.9 if not up else 2.6)
    fringe_shade(cv)
    all_outlines(cv)
    hair_rimlight(cv, ex, ey, 19, 17, ylim=16 if not up else 20)
    edge_shade(cv, 'hair', HR_L, HR_D, minw=5, y0=ymax + 1)
    edge_shade(cv, 'skin', SK_L, SK_D, minw=13, y0=26, y1=53)
    edge_shade(cv, 'skin', SK_L, SK_D, minw=5, y0=53)
    under_hair_shadow(cv)
    if side:
        ear(cv, True, 29, 39, big=True)
    elif not girl:
        if up:
            ear(cv, True, 30, 36); ear(cv, False, 30, 36)
        else:
            ear(cv, True, 31, 37); ear(cv, False, 31, 37)
    if side:
        push_back(cv, 57, 67, 56, 95)
        push_back(cv, 48, 62, 99, 143)
    shirt_detail(cv, front=not up, cx=45 if side else 47)
    pants_detail(cv, skirt=girl)
    shoe_detail(cv)

    # 목 그늘
    cv.hpaint(52 if not up else 49, 44, 51, SK_M, SKIN)
    cv.hpaint(53 if not up else 50, 45, 50, SK_D, SKIN)

    # 10) 머리 결
    if up:
        strand(cv, 54, 22, 6, 0.35, w=2)
        strand(cv, 60, 30, 5, 0.2, w=2)
        if girl:
            for y in (49, 50, 51):        # 머리끈
                cv.hpaint(y, 41, 54, HR_DD, HAIR)
            cv.hpaint(50, 43, 52, HR_D, HAIR)
            strand(cv, 45, 56, 7, 0.2, w=2)
            strand(cv, 51, 64, 6, -0.15, w=2)
    elif girl:
        if side:
            strand(cv, 27, 42, 26, 0.12, w=2)
            strand(cv, 66, 36, 16, 0.06, w=2)
        else:
            strand(cv, 27, 44, 24, 0.10, w=2)
            strand(cv, 67, 44, 24, -0.10, w=2)

    # 11) 얼굴
    if kind == 'down':
        face_front(cv)
    elif kind == 'side':
        face_side(cv)

    return cv


# ------------------------------------------------------------------ 저장
def save(cv, path):
    xs = [p[0] for p in cv.col]
    ys = [p[1] for p in cv.col]
    dx = int(round(47.5 - (min(xs) + max(xs)) / 2.0))
    dy = 142 - max(ys)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for (x, y), c in cv.col.items():
        nx, ny = x + dx, y + dy
        assert 0 <= nx < W and 0 <= ny < H, (path, nx, ny)
        px[nx, ny] = (c[0], c[1], c[2], 255)
    im.save(path)


def main():
    for sex in ('boy', 'girl'):
        for kind in ('down', 'side', 'up'):
            save(build(sex, kind), 'w96_p_%s_%s.png' % (sex, kind))
    print('wrote 6')


if __name__ == '__main__':
    main()
