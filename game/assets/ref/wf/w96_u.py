#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리틀 루트 주인공 도트 — 96 x 144, 방향 u (동글동글).

모서리를 전부 깎아 원과 타원으로만 실루엣을 짠다.
눈도 입도 볼도 둥글다.  눈 하나는 얼굴 폭의 1/4 남짓이고,
눈테는 검정이 아니라 살결의 진한 단으로 잡는다.

  python3 w96_u.py   ->  w96_u_{boy,girl}_{down,side,up}.png
"""
import math

from PIL import Image

W, H = 96, 144
CX = 48.0                      # 연속 좌표 중심 (픽셀 인덱스로는 47.5)

# ── 팔레트 (SPEC96.md 표 밖의 색은 한 칸도 쓰지 않는다) ───────────────
SK, SK_L, SK_D = (243, 159, 138), (250, 192, 170), (213, 116, 98)
SK_CH, SK_M, SK_DD, SK_LL = (235, 128, 114), (170, 84, 66), (184, 99, 83), (252, 217, 204)
HR, HR_L, HR_D, HR_DD, HR_LL = (118, 72, 40), (152, 100, 56), (86, 52, 30), (58, 35, 20), (195, 165, 140)
SH, SH_D, SH_L, SH_DD, SH_LL = (58, 88, 168), (38, 58, 120), (94, 126, 200), (27, 41, 84), (166, 184, 225)
PT, PT_D, PT_L, PT_DD, PT_LL = (134, 88, 46), (98, 62, 32), (158, 108, 58), (69, 43, 22), (202, 174, 147)
SO, SO_D, SO_DD = (82, 53, 33), (56, 37, 25), (39, 26, 18)
OL, EYE, BROW, WHT = (26, 20, 28), (66, 32, 30), (136, 70, 42), (246, 242, 234)

DARK = {'sk': SK_DD, 'hr': HR_DD, 'sh': SH_DD, 'pt': PT_DD, 'so': SO_DD}
MID = {'sk': SK_D, 'hr': HR_D, 'sh': SH_D, 'pt': PT_D, 'so': SO_D}
RANK = {'sk': 0, 'hr': 1, 'sh': 2, 'pt': 3, 'so': 4}

LX, LY, LZ = -0.55, -0.62, 0.56          # 빛은 왼쪽 위 앞


# ── 캔버스 ────────────────────────────────────────────────────────────
class Canvas(object):
    def __init__(self):
        self.c = [[None] * W for _ in range(H)]
        self.m = [[None] * W for _ in range(H)]

    def put(self, x, y, col, mat):
        if 0 <= x < W and 0 <= y < H:
            self.c[y][x] = col
            self.m[y][x] = mat

    def fill(self, mask, col, mat):
        for (x, y) in mask:
            self.put(x, y, col, mat)

    def on(self, x, y):
        return 0 <= x < W and 0 <= y < H and self.c[y][x] is not None

    def matof(self, x, y):
        return self.m[y][x] if 0 <= x < W and 0 <= y < H else None

    def seams(self):
        """재질 경계 — 위에 얹힌 재질 쪽이 한 단 어두워진다."""
        todo = []
        for y in range(H):
            for x in range(W):
                a = self.m[y][x]
                if a is None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    b = self.matof(x + dx, y + dy)
                    if b is not None and b != a and RANK[a] > RANK[b]:
                        todo.append((x, y, a))
                        break
        for (x, y, a) in todo:
            self.c[y][x] = MID[a]

    def outline(self):
        """실루엣 윤곽 — 재질마다 그 재질의 가장 어두운 단.  검정 금지."""
        todo = []
        for y in range(H):
            for x in range(W):
                if self.c[y][x] is None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if not self.on(x + dx, y + dy):
                        todo.append((x, y))
                        break
        for (x, y) in todo:
            self.c[y][x] = DARK[self.m[y][x]]

    def despeck(self, limit=2, rounds=3):
        """한두 칸만 남은 색 얼룩 = 게임 크기에서 먼지.  이웃 색으로 흡수한다."""
        n8 = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
        for _ in range(rounds):
            seen = [[False] * W for _ in range(H)]
            fixed = 0
            for y in range(H):
                for x in range(W):
                    if seen[y][x] or self.c[y][x] is None:
                        continue
                    col = self.c[y][x]
                    st, comp = [(x, y)], []
                    seen[y][x] = True
                    while st:
                        ax, ay = st.pop()
                        comp.append((ax, ay))
                        for dx, dy in n8:
                            bx, by = ax + dx, ay + dy
                            if (0 <= bx < W and 0 <= by < H and not seen[by][bx]
                                    and self.c[by][bx] == col):
                                seen[by][bx] = True
                                st.append((bx, by))
                    if len(comp) > limit:
                        continue
                    same, any_ = {}, {}
                    for (ax, ay) in comp:
                        for dx, dy in n8:
                            bx, by = ax + dx, ay + dy
                            if not (0 <= bx < W and 0 <= by < H):
                                continue
                            nc = self.c[by][bx]
                            if nc is None or nc == col:
                                continue
                            key = (nc, self.m[by][bx])
                            any_[key] = any_.get(key, 0) + 1
                            if self.m[by][bx] == self.m[ay][ax]:
                                same[key] = same.get(key, 0) + 1
                    tally = same or any_
                    if not tally:
                        continue
                    bc, bm = max(tally.items(), key=lambda kv: kv[1])[0]
                    for (ax, ay) in comp:
                        self.c[ay][ax] = bc
                        self.m[ay][ax] = bm
                    fixed += 1
            if not fixed:
                break

    def save(self, path):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        p = im.load()
        for y in range(H):
            for x in range(W):
                c = self.c[y][x]
                if c is not None:
                    p[x, y] = (c[0], c[1], c[2], 255)
        im.save(path)


# ── 도형 (전부 원/타원 기반) ──────────────────────────────────────────
def ell(cx, cy, rx, ry):
    s = set()
    if rx <= 0 or ry <= 0:
        return s
    for y in range(max(0, int(cy - ry - 2)), min(H, int(cy + ry + 3))):
        dy = (y + 0.5 - cy) / float(ry)
        if abs(dy) > 1.0:
            continue
        hw = rx * math.sqrt(max(0.0, 1.0 - dy * dy))
        x0 = int(math.ceil(cx - hw - 0.5))
        x1 = int(math.floor(cx + hw - 0.5))
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            s.add((x, y))
    return s


def circ(cx, cy, r):
    return ell(cx, cy, r, r)


def _smooth(t):
    return t * t * (3 - 2 * t)


def band(rows):
    """rows = [(y, cx, halfwidth), ...] — 좌우 대칭 덩이."""
    return bandlr([(y, c - w, c + w) for (y, c, w) in rows])


def bandlr(rows):
    """rows = [(y, xleft, xright), ...] — 좌우가 다른 덩이 (3/4 용)."""
    rows = sorted(rows)
    s = set()
    for i in range(len(rows) - 1):
        ya, la, ra = rows[i]
        yb, lb, rb = rows[i + 1]
        for y in range(ya, yb + 1):
            t = 0.0 if yb == ya else _smooth((y - ya) / float(yb - ya))
            l = la + (lb - la) * t
            r = ra + (rb - ra) * t
            if r <= l:
                continue
            x0 = int(math.ceil(l - 0.5))
            x1 = int(math.floor(r - 0.5))
            for x in range(max(0, x0), min(W - 1, x1) + 1):
                if 0 <= y < H:
                    s.add((x, y))
    return s


def mx(v):
    return 96.0 - v


def runs_of(mask):
    """행마다 연속 구간 목록."""
    rows = {}
    for (x, y) in mask:
        rows.setdefault(y, []).append(x)
    out = []
    for y in sorted(rows):
        xs = sorted(rows[y])
        a = p = xs[0]
        for x in xs[1:]:
            if x == p + 1:
                p = x
                continue
            out.append((y, a, p))
            a = p = x
        out.append((y, a, p))
    return out


# ── 음영 ──────────────────────────────────────────────────────────────
def shade_sphere(cv, mask, cx, cy, rx, ry, lite, base, dark, t1, t2, mat):
    for (x, y) in mask:
        nx = (x + 0.5 - cx) / float(rx)
        ny = (y + 0.5 - cy) / float(ry)
        q = 1.0 - nx * nx - ny * ny
        nz = math.sqrt(q) if q > 0 else 0.0
        d = nx * LX + ny * LY + nz * LZ
        cv.put(x, y, lite if d > t1 else (base if d > t2 else dark), mat)


def shade_runs(cv, mask, lite, base, dark, mat, lo=0.18, hi=0.72, foot=0.92):
    """행별 연속 구간마다 왼쪽은 밝게 오른쪽은 어둡게 — 둥근 기둥."""
    ys = [y for (x, y) in mask]
    if not ys:
        return
    y0, y1 = min(ys), max(ys)
    span = max(1, y1 - y0 + 1)
    for (y, a, b) in runs_of(mask):
        n = max(1, b - a + 1)
        foot_row = (y - y0 + 0.5) / float(span) > foot
        for x in range(a, b + 1):
            u = (x - a + 0.5) / float(n)
            c = lite if u < lo else (dark if u > hi else base)
            if foot_row:
                c = dark
            cv.put(x, y, c, mat)


def despeckle(face, hair):
    """한 칸 두께로 남은 자리는 옆 재질에 흡수시킨다 (먼지 방지)."""
    for (src, dst) in ((hair, face), (face, hair)):
        for _ in range(3):
            moved = False
            for (y, a, b) in runs_of(src):
                if b - a == 0 and ((a - 1, y) in dst or (a + 1, y) in dst):
                    src.discard((a, y))
                    dst.add((a, y))
                    moved = True
            if not moved:
                break


# ── 머리 ──────────────────────────────────────────────────────────────
HAIRE = (CX, 25.0, 22.0, 24.0)             # 머리칼 바깥 타원 — 폭 44, 꼭대기 y=1
FACE_D = (CX, 31.5, 18.0, 19.5)            # 정면 얼굴 타원 — 폭 36
FACE_S = (CX + 4.6, 31.5, 15.6, 19.5)      # 3/4 얼굴 — 오른쪽으로 돌아섰다


def head_shell(kind, fc):
    sil = ell(CX, 25.0, 22.0, 24.0)
    if kind == 'side':
        sil |= ell(CX - 14.6, 33.0, 7.4, 14.0)      # 가까운(왼) 뒤통수 — 두껍다
        sil |= ell(CX + 13.2, 31.0, 5.6, 11.0)      # 먼(오른) 쪽 — 눌려 좁다
    else:
        sil |= ell(CX - 14.2, 32.5, 7.2, 13.5)
        sil |= ell(CX + 14.2, 32.5, 7.2, 13.5)
    sil |= ell(*fc)
    return sil


def fringe_mask(kind):
    """둥근 앞머리 — 원 세 덩이의 합집합.  아래 가장자리가 물결친다."""
    s = set((x, y) for y in range(0, 13) for x in range(W))
    lobes = [(34.5, 11.0, 10.2), (48.0, 10.2, 10.2), (61.5, 11.0, 10.2)]
    if kind == 'side':
        lobes = [(34.0, 12.2, 10.0), (48.5, 10.4, 10.4), (63.0, 12.6, 9.4)]
    for (lx, ly, lr) in lobes:
        for y in range(0, 34):
            dy = y + 0.5 - ly
            if abs(dy) > lr:
                continue
            hw = math.sqrt(lr * lr - dy * dy)
            for x in range(int(lx - hw - 1), int(lx + hw + 2)):
                if 0 <= x < W and abs(x + 0.5 - lx) <= hw:
                    for yy in range(0, y + 1):
                        s.add((x, yy))
    return s


def long_hair(sex, kind):
    if sex != 'girl':
        return set()
    if kind == 'up':
        return bandlr([(38, 35.2, 60.8), (46, 33.4, 62.6), (58, 32.6, 63.4),
                       (72, 33.4, 62.6), (80, 35.4, 60.6), (85, 39.4, 56.6),
                       (88, 44.0, 52.0)])
    if kind == 'side':
        far = bandlr([(26, 57.5, 65.0), (34, 56.6, 67.4), (48, 56.2, 67.0),
                      (62, 57.0, 66.2), (72, 58.6, 65.0), (76, 60.6, 63.4)])
        near = bandlr([(26, 29.0, 36.0), (34, 27.2, 36.6), (46, 27.6, 36.8),
                       (56, 29.4, 36.4), (60, 31.6, 35.0)])
        return far | near
    lk = bandlr([(26, 29.6, 36.2), (34, 27.4, 36.6), (46, 26.6, 36.4),
                 (58, 27.0, 36.0), (68, 28.6, 35.4), (74, 30.8, 34.4),
                 (77, 32.6, 33.8)])
    return lk | set((95 - x, y) for (x, y) in lk)


def draw_head(cv, sex, kind):
    fc = FACE_S if kind == 'side' else FACE_D
    sil = head_shell(kind, fc)
    if kind == 'side':
        sil |= ell(66.6, 38.5, 3.6, 3.2)             # 콧등이 옆얼굴을 밀어낸다

    lg = long_hair(sex, kind)

    if kind == 'up':
        sil |= circ(41.0, 38.0, 8.2) | circ(48.0, 40.0, 8.4) | circ(55.0, 38.0, 8.2)
        face = set()
        hair = sil | lg
    else:
        face = (ell(*fc) & sil) - fringe_mask(kind)
        hair = (sil - face) | (lg - face)
        despeckle(face, hair)

    head_part = set((x, y) for (x, y) in hair if y <= 47)
    tail_part = hair - head_part
    shade_sphere(cv, head_part, CX - 2.0, 26.5, 21.5, 23.0,
                 HR_L, HR, HR_D, 0.88, 0.46, 'hr')
    if tail_part:
        shade_runs(cv, tail_part, HR_L, HR, HR_D, 'hr', lo=0.22, hi=0.68, foot=0.90)
    if kind == 'up':                                 # 목덜미 머리끝은 한 단 어둡게
        cols = {}
        for (x, y) in head_part:
            cols.setdefault(x, []).append(y)
        for x, ys in cols.items():
            for y in sorted(ys)[-3:]:
                if y >= 38:
                    cv.put(x, y, HR_D, 'hr')
        locks = bandlr([(9, 53.5, 57.5), (19, 57.5, 62.0), (30, 60.0, 64.5),
                        (40, 58.5, 63.0), (45, 56.0, 60.0)])
        locks |= bandlr([(15, 35.5, 39.0), (26, 32.0, 36.0), (36, 32.5, 36.5),
                         (43, 34.5, 38.5)])
        for (x, y) in locks & head_part:
            if cv.c[y][x] == HR:
                cv.put(x, y, HR_D, 'hr')

    if face:
        paint_face(cv, face, hair, kind)
    return face, hair


def paint_face(cv, face, hair, kind):
    """얼굴은 단색 살결 + 큼직한 면 두 개.  얼룩지지 않게."""
    for (x, y) in face:
        cv.put(x, y, SK, 'sk')
    for (y, a, b) in runs_of(face):
        n = max(1, b - a + 1)
        for x in range(a, b + 1):
            u = (x - a + 0.5) / float(n)
            if u > 0.84:
                cv.put(x, y, SK_D, 'sk')
            elif u < 0.14 and y < 34:
                cv.put(x, y, SK_L, 'sk')
    cols = {}
    for (x, y) in face:
        cols.setdefault(x, []).append(y)
    for x, ys in cols.items():
        for y in sorted(ys)[-2:]:
            if y >= 45:
                cv.put(x, y, SK_D, 'sk')       # 턱 아래 그늘
    for (x, y) in face:
        if y < 27 and (x, y - 1) in hair:
            cv.put(x, y, SK_D, 'sk')           # 앞머리 그늘 한 줄 (이마에만)


# ── 이목구비 ──────────────────────────────────────────────────────────
EYE9 = [
    "..LLLLL..",
    ".LLLLLLL.",
    "dLIIIIILd",
    "dIWWIIIId",
    "dIWWIIIId",
    "dIIJJJIId",
    "dJJJJJJJd",
    ".dJJJJJd.",
    "..ddddd..",
]

EYE6 = [                      # 먼 눈 — 눌려 좁아진다
    "..LL..",
    ".LLLL.",
    "dLIILd",
    "dIWWId",
    "dIWWId",
    "dIJJId",
    "dJJJJd",
    ".dddd.",
]

EYECOL = {'L': EYE, 'I': HR_D, 'W': WHT, 'J': HR_L, 'd': SK_DD}

EYE_TOP = 27


def stamp(cv, pat, x0, y0, colmap, mat='sk'):
    for j, row in enumerate(pat):
        for i, ch in enumerate(row):
            if ch != '.':
                cv.put(x0 + i, y0 + j, colmap[ch], mat)


def draw_brow(cv, x0, y0, w):
    for i in range(1, w - 1):
        cv.put(x0 + i, y0, BROW, 'sk')
    for i in range(0, w):
        cv.put(x0 + i, y0 + 1, BROW, 'sk')


def draw_nose(cv, x0, y0):
    """콧등 + 콧방울 + 그늘.  여섯 칸 폭."""
    cv.put(x0 + 2, y0, SK_LL, 'sk'); cv.put(x0 + 3, y0, SK_LL, 'sk')
    for i in range(1, 5):
        cv.put(x0 + i, y0 + 1, SK_LL, 'sk')
    for i in range(0, 6):
        cv.put(x0 + i, y0 + 2, SK_D, 'sk')
    for i in range(1, 5):
        cv.put(x0 + i, y0 + 3, SK_DD, 'sk')


def draw_mouth(cv, x0, y0, w):
    """둥근 웃는 입 — 입꼬리가 올라가고 아랫입술 그늘이 분명하다."""
    for i in (0, 1, w - 2, w - 1):
        cv.put(x0 + i, y0, SK_M, 'sk')
    for i in range(0, w):
        cv.put(x0 + i, y0 + 1, SK_M, 'sk')
    for i in range(1, w - 1):
        cv.put(x0 + i, y0 + 2, SK_M, 'sk')
    for i in range(2, w - 2):
        cv.put(x0 + i, y0 + 3, SK_M, 'sk')
    for i in range(3, w - 3):
        cv.put(x0 + i, y0 + 4, SK_D, 'sk')


def draw_face(cv, sex, kind, face):
    if kind == 'up':
        return
    if kind == 'down':
        eyes = [(34, EYE9), (53, EYE9)]
        brows = [(35, 23, 6), (55, 23, 6)]
        nose_x, mouth = 45, (42, 43, 12)
        cheeks = [(35.5, 39.0, 5.0, 2.4), (60.5, 39.0, 5.0, 2.4)]
        ears = [(30.0, 34.0, 2.2, 3.6), (66.0, 34.0, 2.2, 3.6)]
    else:
        eyes = [(43, EYE9), (59, EYE6)]
        brows = [(44, 23, 6), (59, 23, 5)]
        nose_x, mouth = 52, (49, 43, 10)
        cheeks = [(44.0, 39.5, 5.8, 2.6), (64.0, 39.0, 3.4, 2.2)]
        ears = [(39.5, 34.5, 2.2, 3.6)]

    for (cx0, cy0, rx0, ry0) in cheeks:            # 볼 — 넓고 둥근 홍조
        for (x, y) in ell(cx0, cy0, rx0, ry0):
            if (x, y) in face:
                cv.put(x, y, SK_CH, 'sk')

    for (ex0, ey0, rx0, ry0) in ears:              # 귀 — 얼굴에 붙인 살점
        for (x, y) in ell(ex0, ey0, rx0, ry0):
            if (x, y) in face:
                cv.put(x, y, SK_D, 'sk')

    for (bx, by, bw) in brows:
        draw_brow(cv, bx, by, bw)

    draw_nose(cv, nose_x, 37)
    if kind == 'side':                             # 옆얼굴 콧등 — 실루엣 밖으로 나온 코
        for y in range(36, 42):
            for x in range(65, 70):
                if (x, y) in face:
                    cv.put(x, y, SK_L if y <= 38 else SK_D, 'sk')
        for x in range(63, 69):
            if (x, 41) in face:
                cv.put(x, 41, SK_D, 'sk')

    for (x0, pat) in eyes:
        stamp(cv, pat, x0, EYE_TOP, EYECOL, 'sk')

    draw_mouth(cv, mouth[0], mouth[1], mouth[2])


# ── 몸 ────────────────────────────────────────────────────────────────
def torso_mask(sex, kind):
    if kind == 'side':
        # 어깨가 비틀린다 — 가까운(왼) 어깨가 한 줄 늦게 더 멀리 벌어진다
        return bandlr([(51, 42.0, 54.0), (55, 38.2, 57.6), (57, 35.6, 59.4),
                       (59, 34.0, 60.6), (62, 33.0, 61.0), (72, 32.8, 61.0),
                       (82, 33.2, 60.6), (90, 33.8, 60.2), (96, 34.2, 59.8)])
    return band([(51, CX, 6.0), (55, CX, 9.8), (57, CX, 12.6), (60, CX, 14.8),
                 (64, CX, 15.9), (72, CX, 16.1), (82, CX, 15.5), (90, CX, 15.0),
                 (96, CX, 14.4)])


def arm_mask(near, kind):
    if kind == 'side':
        if near:
            return band([(57, 34.6, 3.2), (60, 33.2, 4.6), (67, 32.6, 4.9),
                         (78, 32.8, 4.6), (88, 33.6, 4.2), (93, 34.2, 3.9)])
        return band([(57, 60.6, 2.8), (60, 61.4, 3.8), (67, 61.8, 3.9),
                     (78, 61.6, 3.6), (88, 61.0, 3.3), (93, 60.6, 3.1)])
    c = 33.0 if near else mx(33.0)
    d = -1.0 if near else 1.0
    return band([(57, c + 1.2 * d, 3.2), (60, c - 0.2 * d, 4.6), (67, c - 0.8 * d, 4.9),
                 (78, c - 0.8 * d, 4.6), (88, c - 0.2 * d, 4.2), (93, c + 0.4 * d, 3.9)])


def hand_mask(near, kind):
    if kind == 'side':
        return circ(34.4 if near else 60.4, 96.5, 4.6 if near else 4.0)
    c = 33.4 if near else mx(33.4)
    return circ(c, 96.5, 4.5)


def draw_arm(cv, sex, near, kind, hand_only=False):
    m = arm_mask(near, kind)
    h = hand_mask(near, kind)
    if hand_only:
        if near:
            shade_runs(cv, h, SK_L, SK, SK_D, 'sk', lo=0.26, hi=0.66, foot=0.88)
        else:
            shade_runs(cv, h, SK, SK_D, SK_D, 'sk', lo=0.34, hi=0.44, foot=1.1)
        return
    cut = 74 if sex == 'girl' else 79
    sl = set(p for p in m if p[1] <= cut)
    ar = set(p for p in m if p[1] > cut) | h
    if near:
        shade_runs(cv, sl, SH_L, SH, SH_D, 'sh', lo=0.24, hi=0.68, foot=1.1)
        shade_runs(cv, ar, SK_L, SK, SK_D, 'sk', lo=0.26, hi=0.68, foot=1.1)
    else:
        shade_runs(cv, sl, SH, SH_D, SH_D, 'sh', lo=0.34, hi=0.46, foot=1.1)
        shade_runs(cv, ar, SK, SK_D, SK_D, 'sk', lo=0.34, hi=0.46, foot=1.1)


def leg_centers(sex, kind):
    if kind == 'side':
        return (42.6, 52.6)
    c = 40.0 if sex == 'boy' else 40.6
    return (c, mx(c))


def draw_legs_boy(cv, kind):
    lc, rc = leg_centers('boy', kind)
    hip = band([(92, CX, 14.6), (97, CX, 15.0), (101, CX, 14.6)])
    if kind == 'side':
        hip = bandlr([(92, 34.0, 60.0), (97, 33.4, 60.6), (101, 34.0, 60.0)])
    shade_runs(cv, hip, PT_L, PT, PT_D, 'pt', lo=0.16, hi=0.76, foot=1.1)
    for (c, near) in ((rc, kind != 'side'), (lc, True)):
        lg = band([(99, c, 6.3), (108, c, 6.1), (118, c + (0.4 if c < CX else -0.4), 5.8),
                   (126, c + (0.6 if c < CX else -0.6), 5.6)])
        if near:
            shade_runs(cv, lg, PT_L, PT, PT_D, 'pt', lo=0.20, hi=0.70, foot=1.1)
            if kind == 'side':
                for (y, a, b) in runs_of(lg):
                    cv.put(b, y, PT_DD, 'pt')
        else:
            shade_runs(cv, lg, PT, PT_D, PT_D, 'pt', lo=0.30, hi=0.48, foot=1.1)
    for (c, near) in ((rc, kind != 'side'), (lc, True)):
        if kind == 'side':
            t = 2.6 if near else 1.6
            d = 0 if near else 2
            bt = bandlr([(125 + d, c - 6.4, c + 6.0), (129 + d, c - 6.8, c + 6.6),
                         (136 + d, c - 6.8, c + 6.6 + t * 0.4), (140, c - 6.6, c + 6.4 + t),
                         (142 - d, c - 6.4, c + 6.2 + t)])
        else:
            bt = band([(125, c, 6.6), (129, c, 7.1), (136, c, 7.0),
                       (140, c, 7.2), (142, c, 7.0)])
        if near:
            shade_runs(cv, bt, SO, SO, SO_D, 'so', lo=0.22, hi=0.68, foot=0.86)
            if kind == 'side':
                for (y, a, b) in runs_of(bt):
                    cv.put(b, y, SO_DD, 'so')
        else:
            shade_runs(cv, bt, SO_D, SO_D, SO_D, 'so', lo=0.5, hi=0.5, foot=1.1)


def draw_legs_girl(cv, kind):
    lc, rc = leg_centers('girl', kind)
    if kind == 'side':
        sk = bandlr([(86, 35.4, 60.2), (90, 33.6, 61.6), (98, 31.2, 63.6),
                     (106, 29.6, 65.0), (110, 30.0, 64.6), (112, 32.0, 62.6)])
    else:
        sk = band([(86, CX, 13.4), (90, CX, 15.0), (98, CX, 17.4), (106, CX, 19.0),
                   (110, CX, 18.6), (112, CX, 16.6)])
    shade_runs(cv, sk, PT_L, PT, PT_D, 'pt', lo=0.17, hi=0.74, foot=0.95)
    for (c, near) in ((rc, kind != 'side'), (lc, True)):
        lg = band([(108, c, 5.0), (118, c, 4.8), (128, c + (0.4 if c < CX else -0.4), 4.6),
                   (133, c + (0.5 if c < CX else -0.5), 4.5)])
        if near:
            shade_runs(cv, lg, SK_L, SK, SK_D, 'sk', lo=0.22, hi=0.70, foot=1.1)
            if kind == 'side':
                for (y, a, b) in runs_of(lg):
                    cv.put(b, y, SK_DD, 'sk')
        else:
            shade_runs(cv, lg, SK, SK_D, SK_D, 'sk', lo=0.30, hi=0.46, foot=1.1)
    for (c, near) in ((rc, kind != 'side'), (lc, True)):
        if kind == 'side':
            t = 2.2 if near else 1.4
            sh = bandlr([(132, c - 5.6, c + 5.2), (135, c - 6.0, c + 5.8),
                         (139, c - 6.0, c + 5.8 + t * 0.5), (141, c - 5.8, c + 5.6 + t),
                         (142, c - 5.6, c + 5.4 + t)])
        else:
            sh = band([(132, c, 5.6), (135, c, 6.2), (139, c, 6.2),
                       (141, c, 6.4), (142, c, 6.2)])
        if near:
            shade_runs(cv, sh, SO, SO, SO_D, 'so', lo=0.24, hi=0.68, foot=0.84)
            if kind == 'side':
                for (y, a, b) in runs_of(sh):
                    cv.put(b, y, SO_DD, 'so')
        else:
            shade_runs(cv, sh, SO_D, SO_D, SO_D, 'so', lo=0.5, hi=0.5, foot=1.1)


def draw_body(cv, sex, kind):
    # 뒤 -> 앞 순서로 얹는다
    draw_arm(cv, sex, False, kind)

    if sex == 'boy':
        draw_legs_boy(cv, kind)
    else:
        draw_legs_girl(cv, kind)

    tor = torso_mask(sex, kind)
    shade_runs(cv, tor, SH_L, SH, SH_D, 'sh', lo=0.20, hi=0.70, foot=0.94)

    ncx = CX + (1.0 if kind == 'side' else 0.0)
    neck = band([(44, ncx, 5.2), (50, ncx, 5.4), (56, ncx, 5.6)])
    cv.fill(neck, SK_D, 'sk')                     # 턱 밑이라 늘 그늘
    for (x, y) in neck:
        if y >= 52:
            cv.put(x, y, SK, 'sk')
    cv.fill(ell(ncx, 57.6, 9.2, 4.4), SH_D, 'sh')   # 둥근 깃 — 단색 한 면

    draw_arm(cv, sex, True, kind)
    draw_arm(cv, sex, False, kind, hand_only=True)
    draw_arm(cv, sex, True, kind, hand_only=True)


# ── 조립 ──────────────────────────────────────────────────────────────
def build(sex, kind):
    cv = Canvas()
    draw_body(cv, sex, kind)
    face, hair = draw_head(cv, sex, kind)
    cv.seams()
    cv.outline()
    draw_face(cv, sex, kind, face)
    cv.despeck()
    return cv


def main():
    for sex in ('boy', 'girl'):
        for kind in ('down', 'side', 'up'):
            build(sex, kind).save('w96_u_%s_%s.png' % (sex, kind))
    print('w96_u: 여섯 장 기록')


if __name__ == '__main__':
    main()
