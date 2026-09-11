#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""w192_d — 192 x 288 리틀 루트 주인공 도트. 방향 「부드러운 파스텔」.

저해상도 그림을 확대한 게 아니다. 192칸 격자에 직접 찍는다.

  · 실루엣은 전부 Catmull-Rom 스플라인으로 뽑아 줄마다 한두 칸씩만 흐른다.
    (32칸 그림을 6배로 키우면 턱이 여섯 칸짜리 계단이 된다 — 그걸 피한다)
  · 음영은 실루엣에서 잰 거리로 띠를 만든다. 그래서 음영 경계도 실루엣과
    똑같은 정밀도로 따라 돈다. 얼굴만 정밀하고 몸이 뭉툭해지지 않는다.
  · 살결 6단(1·2·3·4·5·6) + 깊은 그늘 7 을 다 쓴다. 모서리는 거의 다 깎았다.
"""

import math
import os
from PIL import Image

W, H = 192, 288
CXF = 95.5                      # 좌우 대칭축 (검사기가 요구하는 가로 중심)

# ---------------------------------------------------------------- 팔레트
C = {
    # 살결 (밝은 쪽 -> 어두운 쪽)
    '1': (252, 217, 204), '2': (250, 192, 170), '3': (243, 159, 138),
    '4': (235, 128, 114), '5': (213, 116, 98),  '6': (184, 99, 83),
    '7': (170, 84, 66),
    # 머리
    'q': (195, 165, 140), 'w': (152, 100, 56), 'e': (118, 72, 40),
    'r': (86, 52, 30),    't': (58, 35, 20),
    # 윗도리
    'A': (166, 184, 225), 'S': (94, 126, 200), 'D': (58, 88, 168),
    'F': (38, 58, 120),   'G': (27, 41, 84),
    # 아랫도리
    'z': (202, 174, 147), 'x': (158, 108, 58), 'c': (134, 88, 46),
    'v': (98, 62, 32),    'b': (69, 43, 22),
    # 신발
    'h': (82, 53, 33), 'j': (56, 37, 25), 'k': (39, 26, 18),
    # 눈 · 입 전용
    'O': (26, 20, 28), 'I': (66, 32, 30), 'B': (136, 70, 42), '#': (246, 242, 234),
}

# 볼륨 띠: (제일밝게, 밝게, 바탕, 그늘, 깊은그늘, 윤곽)
SKIN  = ('1', '2', '3', '4', '5', '6')
HAIR  = ('q', 'w', 'e', 'r', 'r', 't')
SHIRT = ('A', 'S', 'D', 'F', 'F', 'G')
PANT  = ('z', 'x', 'c', 'v', 'v', 'b')
SHOE  = ('h', 'h', 'h', 'j', 'j', 'k')

SUN = (-1, -1)                  # 빛은 왼쪽 위에서


# ---------------------------------------------------------------- 곡선
def spline(pts):
    """Catmull-Rom(Hermite) 보간. 스플라인이라야 줄마다 한 칸씩 흐른다."""
    pts = sorted(pts)
    ts = [float(p[0]) for p in pts]
    vs = [float(p[1]) for p in pts]
    n = len(pts)
    m = [0.0] * n
    for i in range(n):
        if i == 0:
            m[i] = (vs[1] - vs[0]) / (ts[1] - ts[0])
        elif i == n - 1:
            m[i] = (vs[n - 1] - vs[n - 2]) / (ts[n - 1] - ts[n - 2])
        else:
            m[i] = (vs[i + 1] - vs[i - 1]) / (ts[i + 1] - ts[i - 1])

    def f(t):
        if t <= ts[0]:
            return vs[0]
        if t >= ts[-1]:
            return vs[-1]
        i = 0
        while ts[i + 1] < t:
            i += 1
        h = ts[i + 1] - ts[i]
        u = (t - ts[i]) / h
        u2 = u * u
        u3 = u2 * u
        return ((2 * u3 - 3 * u2 + 1) * vs[i] + (u3 - 2 * u2 + u) * h * m[i] +
                (-2 * u3 + 3 * u2) * vs[i + 1] + (u3 - u2) * h * m[i + 1])
    return f


def neg(f):
    return lambda t: -f(t)


def kd(pts):
    """음영 띠 두께를 자리마다 다르게. 일정하면 자로 그은 자국이 된다."""
    f = spline(pts)
    return lambda u, y: f(y)


# ---------------------------------------------------------------- 마스크
def mnew():
    return [bytearray(W) for _ in range(H)]


def mfill(m, y, ol, orr):
    """중심에서 잰 오프셋 구간 [ol, orr] 를 y 줄에 칠한다."""
    if orr < ol or y < 0 or y >= H:
        return
    a = int(math.ceil(CXF - 0.5 + ol))
    b = int(math.floor(CXF - 0.5 + orr))
    if b < a:
        b = a = int(round(CXF - 0.5 + (ol + orr) * 0.5))
    a = max(0, a)
    b = min(W - 1, b)
    row = m[y]
    for x in range(a, b + 1):
        row[x] = 1


def mprof(y0, y1, fl, fr):
    m = mnew()
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        mfill(m, y, fl(y), fr(y))
    return m


def mtube(y0, y1, fc, fr):
    return mprof(y0, y1, lambda y: fc(y) - fr(y), lambda y: fc(y) + fr(y))


def mell(cx, cy, rx, ry, n=2.0):
    """cx 는 중심축 기준 오프셋. n>2 면 모서리가 둥근 사각형에 가까워진다."""
    m = mnew()
    y0 = max(0, int(cy - ry - 2))
    y1 = min(H - 1, int(cy + ry + 2))
    for y in range(y0, y1 + 1):
        dy = abs((y + 0.5 - cy) / float(ry)) ** n
        if dy > 1.0:
            continue
        t = (1.0 - dy) ** (1.0 / n)
        mfill(m, y, -rx * t + cx, rx * t + cx)
    return m


def mor(*ms):
    o = mnew()
    for m in ms:
        for y in range(H):
            a, b = o[y], m[y]
            for x in range(W):
                if b[x]:
                    a[x] = 1
    return o


def mand(a, b):
    o = mnew()
    for y in range(H):
        ra, rb, ro = a[y], b[y], o[y]
        for x in range(W):
            if ra[x] and rb[x]:
                ro[x] = 1
    return o


def msub(a, b):
    o = mnew()
    for y in range(H):
        ra, rb, ro = a[y], b[y], o[y]
        for x in range(W):
            if ra[x] and not rb[x]:
                ro[x] = 1
    return o


def mregion(pred, y0=0, y1=H - 1):
    m = mnew()
    for y in range(max(0, y0), min(H - 1, y1) + 1):
        row = m[y]
        for x in range(W):
            if pred(x - CXF + 0.5, y + 0.5):
                row[x] = 1
    return m


def mshift(m, dx, dy):
    o = mnew()
    for y in range(H):
        ny = y + dy
        if ny < 0 or ny >= H:
            continue
        row, orow = m[y], o[ny]
        for x in range(W):
            if row[x]:
                nx = x + dx
                if 0 <= nx < W:
                    orow[nx] = 1
    return o


def band(m, dx, dy, k):
    """(dx,dy) 쪽 경계에서 k 칸 안쪽까지의 띠. k 는 수나 함수."""
    o = mnew()
    for y in range(H):
        row = m[y]
        if 1 not in row:
            continue
        orow = o[y]
        for x in range(W):
            if not row[x]:
                continue
            kk = int(k(x - CXF + 0.5, y) if callable(k) else k)
            for i in range(1, kk + 1):
                nx = x + dx * i
                ny = y + dy * i
                if nx < 0 or nx >= W or ny < 0 or ny >= H or not m[ny][nx]:
                    orow[x] = 1
                    break
    return o


def erode(m):
    o = mnew()
    for y in range(1, H - 1):
        a, b, c = m[y - 1], m[y], m[y + 1]
        orow = o[y]
        for x in range(1, W - 1):
            if (b[x] and b[x - 1] and b[x + 1] and a[x] and c[x]
                    and a[x - 1] and a[x + 1] and c[x - 1] and c[x + 1]):
                orow[x] = 1
    return o


def outline(m, t=2):
    cur = m
    for _ in range(int(t)):
        cur = erode(cur)
    return msub(m, cur)


def put(g, m, ch, clip=None):
    for y in range(H):
        row = m[y]
        grow = g[y]
        if clip is None:
            for x in range(W):
                if row[x]:
                    grow[x] = ch
        else:
            crow = clip[y]
            for x in range(W):
                if row[x] and crow[x]:
                    grow[x] = ch


def vol(g, m, ramp, out=2, dd=4, dk=9, hi=5, lt=10, clip=None, sun=SUN):
    """실루엣에서 잰 거리로 볼륨을 만든다. 둥근 덩어리는 이걸로 다 나온다."""
    sx, sy = sun
    put(g, m, ramp[2], clip)
    if lt:
        put(g, band(m, sx, sy, lt), ramp[1], clip)
    if hi:
        put(g, band(m, sx, sy, hi), ramp[0], clip)
    if dk:
        put(g, band(m, -sx, -sy, dk), ramp[3], clip)
    if dd:
        put(g, band(m, -sx, -sy, dd), ramp[4], clip)
    if out:
        put(g, outline(m, out), ramp[5], clip)


# ================================================================ 머리
FACE_TOP, CHIN = 36, 128
HAIR_TOP = 16


def face_profile(d):
    """얼굴 실루엣. 3/4 은 좌우를 따로 잡는다 (밀어놓은 정면이면 실패다)."""
    if d != 'side':
        fr = spline([(36, 0.5), (37, 7.5), (38.5, 11), (41, 15.5), (44, 19.5),
                     (48, 23.5), (53, 27.0), (59, 30.3), (66, 32.8),
                     (74, 34.4), (82, 35.0), (90, 34.8), (97, 34.0),
                     (104, 32.8), (110, 30.8), (114, 28.8), (118, 25.8),
                     (121, 22.2), (124, 17.0), (126, 11.0), (127, 6),
                     (128, 0.5)])
        return neg(fr), fr
    fr = spline([(36, 0.5), (37, 7.5), (38.5, 11), (41, 15.5), (44, 19.5),
                 (48, 23.5), (53, 27.5), (59, 31.0), (66, 33.6), (74, 35.4),
                 (82, 36.2), (90, 36.2), (97, 35.8), (103, 35.2), (107, 35.8),
                 (110, 36.4), (112, 35.4), (115, 32.8), (118, 30.4),
                 (121, 26.6), (124, 19.6), (126, 11), (128, 2)])
    fl = spline([(36, -0.5), (37, -7.5), (38.5, -11), (41, -15.5),
                 (44, -20), (48, -24), (53, -28), (59, -31.6), (66, -34.4),
                 (74, -36.4), (82, -37.2), (90, -36.8), (96, -35.6),
                 (102, -33.4), (107, -30.0), (111, -25.6), (115, -20.4),
                 (119, -14.0), (123, -7.0), (126, -1.5), (128, 0)])
    return fl, fr


def hair_cap(sex, d):
    """머리 덩어리. 3/4 에서도 실루엣은 거의 안 변한다 (뒤통수만 살짝)."""
    w = 44.0 if sex == 'girl' else 43.0
    if sex == 'girl':
        tail = [(91, w - 0.6), (100, w - 1.6), (110, w - 2.4),
                (120, w - 2.0), (132, w - 0.4), (144, w + 1.4),
                (152, w + 2.2), (156, w + 2.4)]
    else:
        tail = [(91, w - 0.8), (98, w - 1.8), (105, w - 3.2),
                (112, w - 5.4), (118, w - 8.4), (124, w - 13)]
    if d != 'side':
        top = spline([(16, 0.5), (17, 9), (18.5, 13.5), (21, 18.5), (24, 23),
                      (28, 28), (33, 32.4), (39, 36.4), (46, 39.6),
                      (54, w - 1.2), (63, w - 0.2), (73, w), (83, w - 0.2)]
                     + tail)
        return neg(top), top
    if sex == 'girl':
        tr = [(91, 40.6), (100, 39.6), (110, 39.0), (120, 39.4),
              (132, 40.6), (144, 42.0), (152, 42.8), (156, 43.2)]
        tl = [(91, -45.4), (100, -44.4), (110, -43.8), (120, -44.2),
              (132, -45.6), (144, -47.0), (152, -47.8), (156, -48.0)]
    else:
        tr = [(91, 40.0), (98, 39.0), (105, 37.6), (112, 35.6), (118, 32.6),
              (124, 28)]
        tl = [(91, -44.8), (98, -43.8), (105, -42.4), (112, -40.4),
              (118, -37.4), (124, -32)]
    fr = spline([(16, 0.5), (17, 8.4), (18.5, 12.6), (21, 17.4), (24, 21.6),
                 (28, 26.4), (33, 30.6), (39, 34.4), (46, 37.4), (54, 39.4),
                 (63, 40.4), (73, 40.8), (83, 40.6)] + tr)
    fl = spline([(16, -0.5), (17, -8.8), (18.5, -13.2), (21, -18.4),
                 (24, -23.0), (28, -28.2), (33, -33.0), (39, -37.4),
                 (46, -40.8), (54, -43.2), (63, -44.6), (73, -45.4),
                 (83, -45.4)] + tl)
    return fl, fr


def fringe(sex, d):
    """앞머리 아래 선. 좌우 대칭이면 무늬가 된다 — 봉우리를 어긋나게."""
    # 앞머리 끝은 옆갈래로 이어져 내려가야 한다. 옆에서 치켜올라가면
    # 옆갈래 안쪽 선과 만나는 자리에 뾰족한 살 조각이 생긴다.
    if sex == 'girl':
        if d == 'side':
            return spline([(-40, 118), (-34, 104), (-30, 90), (-27, 79),
                           (-23, 72), (-15, 71), (-6, 74), (2, 74), (9, 73),
                           (16, 71), (22, 70), (26, 74), (29.5, 86),
                           (33, 102), (40, 118)])
        return spline([(-40, 116), (-34, 102), (-30, 88), (-27, 77),
                       (-23, 70), (-15, 69), (-6, 72), (2, 72), (9, 71),
                       (16, 69), (22, 68), (26, 72), (29.5, 84), (33, 100),
                       (40, 116)])
    if d == 'side':
        return spline([(-40, 116), (-34, 102), (-30, 87), (-27, 76),
                       (-23, 69), (-15, 68), (-6, 70), (2, 70), (9, 69),
                       (16, 67), (22, 66), (26, 70), (29.5, 82), (33, 98),
                       (40, 114)])
    return spline([(-40, 114), (-34, 100), (-30, 85), (-27, 74), (-23, 67),
                   (-15, 66), (-6, 68), (2, 68), (9, 67), (16, 65),
                   (22, 64), (26, 68), (29.5, 80), (33, 96), (40, 112)])


def nape(sex, d):
    """머리 아래 끝선. 옆갈래 끝을 좌우 다른 높이로 둥글게 끊는다."""
    if sex == 'girl':
        return None
    if d == 'up':
        # 목덜미 — 잔 봉우리 세 개를 서로 다른 높이로
        return spline([(-48, 96), (-40, 110), (-31, 118), (-22, 122),
                       (-13, 121), (-4, 124), (6, 124), (15, 122),
                       (24, 120), (32, 114), (40, 104), (48, 92)])
    if d == 'side':
        return spline([(-48, 90), (-42, 104), (-36, 113), (-30, 118),
                       (-22, 116), (-12, 110), (0, 106), (12, 108),
                       (22, 112), (29, 114), (35, 108), (42, 97), (48, 86)])
    return spline([(-48, 88), (-42, 102), (-36, 111), (-31, 116), (-25, 114),
                   (-16, 108), (-4, 104), (8, 106), (18, 110), (26, 114),
                   (32, 112), (38, 103), (46, 86)])


def head(g, sex, d):
    fl, fr = face_profile(d)
    hl, hr = hair_cap(sex, d)
    face = mprof(FACE_TOP, CHIN, fl, fr)
    shift = 8.0 if d == 'side' else 0.0      # 이목구비가 돌아선 쪽으로 몰린다

    capbot = 156 if sex == 'girl' else 126
    cap = mprof(HAIR_TOP, capbot, hl, hr)
    nf = nape(sex, d)
    if nf is not None:
        cap = mand(cap, mregion(lambda u, y: y <= nf(u), HAIR_TOP, capbot))
    else:
        cap = mor(cap, girl_locks(d))
        if d != 'up':
            cap = msub(cap, mell(0.0 if d != 'side' else -1.6, 141,
                                 13.2, 16.0, 2.6))
    hairm = cap

    # ---- 얼굴 창 (머리에 안 가린 부분)
    win = None
    if d != 'up':
        frl = fringe(sex, d)
        if d == 'side':
            liml = spline([(60, 22), (80, 23.5), (96, 24.5), (106, 25.4),
                           (111, 26.2), (114, 28), (116, 33), (118, 44),
                           (130, 46)])
            limr = spline([(60, 32), (74, 34.5), (88, 36.5), (100, 38),
                           (110, 39.5), (116, 44), (130, 46)])
        else:
            liml = spline([(60, 25.0), (76, 26.6), (92, 27.8), (104, 28.6),
                           (110, 29.4), (113, 31.5), (115, 36), (118, 46),
                           (130, 46)])
            limr = spline([(60, 24.0), (76, 25.6), (92, 27.0), (106, 28.2),
                           (112, 29.2), (115, 31.5), (117, 37), (120, 46),
                           (130, 46)])
        win = mand(face, mregion(
            lambda u, y: (y >= frl(u) and -liml(y) + shift * 0.5 <= u
                          <= limr(y) + shift * 0.5), FACE_TOP, CHIN + 2))

    # ---- 머리 덩어리 (윤곽은 얼굴 찍은 뒤에)
    vol(g, hairm, HAIR, out=0, dd=5,
        dk=kd([(16, 5), (34, 10), (58, 14), (84, 17), (110, 19), (140, 17),
               (170, 14), (210, 12)]),
        hi=0,
        lt=kd([(16, 6), (34, 11), (60, 14), (86, 12), (112, 10), (150, 9),
               (200, 8)]))
    hair_shine(g, hairm, sex, d)
    if d == 'up':
        back_detail(g, hairm, sex)
    else:
        hair_strands(g, hairm, sex, d)

    if win is not None:
        vol(g, face, SKIN, out=0, dd=4,
            dk=kd([(36, 5), (58, 8), (80, 10), (100, 12), (114, 15),
                   (128, 17)]),
            hi=5,
            lt=kd([(36, 4), (58, 7), (82, 9), (104, 8), (128, 6)]),
            clip=win)
        # 앞머리 그림자 — 앞머리 선을 그대로 베끼면 톱니가 두 겹이 된다.
        # 두께를 자리마다 다르게 해서 선이 아니라 그늘로 읽히게.
        frl = fringe(sex, d)
        dep = spline([(-50, 4), (-26, 8), (-9, 6), (7, 9), (24, 5), (50, 7)])
        put(g, mand(win, mregion(
            lambda u, y: y <= frl(u) + dep(u), FACE_TOP, CHIN)), '4')
        put(g, mand(win, mregion(
            lambda u, y: y <= frl(u) + dep(u) * 0.4, FACE_TOP, CHIN)), '5')
        face_parts(g, sex, d, win, shift)
        put(g, mand(outline(face, 2), win), '6')

    vis = msub(hairm, win if win else mnew())
    if d != 'up':
        put(g, mand(band(vis, 0, 1, 5), vis), 'r')
    put(g, outline(vis, 2), 't')


def hair_shine(g, hairm, sex, d):
    """정수리 광택. 한 바퀴 두르면 후광이 된다 — 왼쪽 위에만, 끊어서."""
    cy = 62.0
    cx = -5.0 if d != 'side' else -9.0
    ring = msub(mell(cx, cy, 39, 43.5), mell(cx, cy, 33.5, 37.4))
    sec = mregion(lambda u, y: (u - cx) * 0.66 + (y - cy) < -12
                  and u - cx < 17, HAIR_TOP, 120)
    sh = mand(mand(ring, sec), msub(hairm, outline(hairm, 4)))
    sh = msub(sh, mregion(lambda u, y: -26 < u - cx < -18, HAIR_TOP, 120))
    sh = msub(sh, mregion(lambda u, y: 1 < u - cx < 5, HAIR_TOP, 120))
    put(g, sh, 'w')
    put(g, mand(sh, msub(mell(cx, cy, 37.6, 42.0), mell(cx, cy, 35.0, 39.2))),
        'q')


STEP_DOWN = {'q': 'w', 'w': 'e', 'e': 'r', 'r': 't', 't': 't'}


def shade(g, m, clip=None):
    """밑에 깔린 색을 한 단 어둡게. 그늘 진 자리에 같은 색 가닥을 그으면
    안 보이고, 어디나 같은 색으로 그으면 금이 간 것처럼 보인다."""
    for y in range(H):
        row = m[y]
        grow = g[y]
        crow = clip[y] if clip is not None else None
        for x in range(W):
            if not row[x]:
                continue
            if crow is not None and not crow[x]:
                continue
            c = grow[x]
            if c in STEP_DOWN:
                grow[x] = STEP_DOWN[c]


def strand(g, clip, pts, wd, ch='r'):
    """머리 가닥 한 올. pts 는 (y, u) 목록."""
    f = spline(pts)
    y0, y1 = int(pts[0][0]), int(pts[-1][0])
    m = mnew()
    mid = (y0 + y1) * 0.5
    for y in range(y0, y1 + 1):
        k = wd * (1.0 - abs((y - mid) / ((y1 - y0) * 0.5)) ** 2.2)
        if k < 0.5:
            continue
        mfill(m, y, f(y) - k * 0.5, f(y) + k * 0.5)
    shade(g, m, clip)


def back_detail(g, hairm, sex):
    """뒷머리는 덩어리 하나라 그냥 두면 갈색 자루가 된다."""
    inner = msub(hairm, outline(hairm, 3))
    if sex == 'girl':
        # 가운데 가르마 — 아래로 갈수록 벌어진다
        m = mnew()
        fp = spline([(18, -1.0), (34, -1.6), (50, -2.2), (62, -2.6)])
        for y in range(19, 63):
            k = 1.3 + (y - 19) * 0.05
            mfill(m, y, fp(y) - k * 0.5, fp(y) + k * 0.5)
        shade(g, m, inner)
        # 갈래 나눔 — 길이도 휨도 다 다르게, 짧게
        strand(g, inner, [(92, -29), (126, -33), (154, -36)], 4.0)
        strand(g, inner, [(128, -13), (158, -16), (184, -19)], 3.0)
        strand(g, inner, [(80, 13), (112, 17), (140, 21)], 3.6)
        strand(g, inner, [(146, 25), (172, 29), (194, 31)], 2.6)
        strand(g, inner, [(168, -24), (188, -26), (204, -27)], 2.0)
        strand(g, inner, [(104, 33), (130, 36), (150, 38)], 2.2)
    else:
        # 뒤통수는 가는 금을 긋는 게 아니라 넓은 덩어리로 나눠야 머리로 읽힌다
        strand(g, inner, [(28, 6), (48, 13), (70, 21), (92, 28),
                          (110, 32)], 11.0)
        strand(g, inner, [(32, -9), (54, -19), (76, -27), (98, -32)], 6.0)
        strand(g, inner, [(46, -1), (70, 1), (94, 4)], 2.4)
    # 목덜미 쪽이 두툼해진다
    put(g, mand(band(hairm, 0, 1, 9), hairm), 'r')


def hair_strands(g, hairm, sex, d):
    """가닥은 짧게 · 적게 · 굵게. 길게 그으면 나뭇결이 된다."""
    if d == 'up':
        seg = [(-24, 46, 76, 3.4), (10, 40, 64, 2.6), (26, 60, 92, 3.0)]
    elif d == 'side':
        seg = [(-32, 40, 66, 3.2), (-14, 34, 54, 2.4), (18, 44, 66, 2.4)]
    else:
        seg = [(-30, 36, 62, 3.2), (-13, 30, 50, 2.4), (14, 38, 60, 2.4),
               (30, 52, 76, 2.6)]
    inner = msub(hairm, outline(hairm, 3))
    for (u, y0, y1, wd) in seg:
        m = mnew()
        f = spline([(y0, u), ((y0 + y1) * 0.5, u + 2.4), (y1, u + 5.4)])
        for y in range(y0, y1 + 1):
            tt = 1.0 - abs((y - (y0 + y1) * 0.5) / ((y1 - y0) * 0.5)) ** 2
            k = wd * tt
            if k < 0.5:
                continue
            mfill(m, y, f(y) - k * 0.5, f(y) + k * 0.5)
        shade(g, m, inner)


# ---------------------------------------------------------------- 얼굴
def face_parts(g, sex, d, win, shift):
    ey = 97.0
    ry = 13.4 if sex == 'girl' else 12.8
    if d == 'side':
        # 먼 눈(오른쪽)은 눌려 좁아지고 바깥 뺨이 한 칸뿐이다
        exl, rl = -7.5, 11.4
        exr, rr = 21.6, 7.6
    else:
        exl, rl = -17.2, 11.6
        exr, rr = 17.2, 11.6

    # 볼 홍조 — 눈 아래에 (눈과 같은 줄에 두면 눈에 가려진다)
    b1 = (exl - 5.5, ey + 19.5, 8.2, 4.2)
    b2 = (exr + 5.0, ey + 18.5, 7.4, 3.8) if d != 'side' else \
         (exr + 5.0, ey + 17.5, 5.6, 3.4)
    for (bx, by, brx, bry) in (b1, b2):
        put(g, mand(mell(bx, by, brx, bry, 2.6), win), '4')

    eye(g, win, exl, ey, rl, ry, -1)
    eye(g, win, exr, ey, rr, ry, 1)

    # 눈썹 — 짧고 평평하게. 길고 두껍게 기울이면 화난 얼굴이 된다
    for (bx, ww, tilt) in ((exl, rl, 0.6), (exr, rr, -0.2)):
        by = ey - ry - 6.5
        m = mnew()
        f = spline([(bx - ww * 0.9, by + 1.7), (bx - ww * 0.1, by - 0.7),
                    (bx + ww * 0.9, by + tilt)])
        for xx in range(int(round(bx - ww * 0.9)), int(round(bx + ww * 0.9)) + 1):
            yy = int(round(f(xx)))
            for k in range(2):
                mfill(m, yy + k, xx, xx)
        put(g, mand(m, win), 'B')

    # 코 — 두어 칸
    nx = 0.6 + shift * 1.55
    ny = ey + 14
    if d == 'side':
        m = mnew()
        for (yy, a, b_) in ((ny - 4, nx - 0.6, nx + 1.4),
                            (ny - 3, nx - 1.2, nx + 2.4),
                            (ny - 2, nx - 1.6, nx + 3.4),
                            (ny - 1, nx - 2.0, nx + 4.2),
                            (ny, nx - 2.0, nx + 3.4),
                            (ny + 1, nx - 1.2, nx + 1.6)):
            mfill(m, int(yy), a, b_)
        put(g, mand(m, win), '5')
        put(g, mand(mell(nx + 0.4, ny - 1.6, 1.2, 1.0, 2.2), win), '4')
    else:
        put(g, mand(mell(nx, ny, 2.6, 1.9, 2.2), win), '5')
        put(g, mand(mell(nx - 0.7, ny - 0.7, 1.3, 1.0, 2.2), win), '4')

    # 입 — 작게. 작을수록 어려 보인다
    mx = 0.4 + shift * 1.2
    my = ey + 24
    mw = 4.2 if sex == 'girl' else 4.8
    if d == 'side':
        mw *= 0.85
    m = mnew()
    m2 = mnew()
    fm = spline([(mx - mw, my - 1.3), (mx, my + 1.4), (mx + mw, my - 1.3)])
    for xx in range(int(round(mx - mw)), int(round(mx + mw)) + 1):
        yy = int(round(fm(xx)))
        mfill(m, yy, xx, xx)
        mfill(m, yy + 1, xx, xx)
        if int(round(mx - mw)) < xx < int(round(mx + mw)):
            mfill(m2, yy + 2, xx, xx)
    put(g, mand(m, win), 'O')
    put(g, mand(m2, win), '4')


def eye(g, win, cx, cy, rx, ry, sgn):
    """홍채가 눈을 거의 채우고 흰자는 좌우에만 조금."""
    box = mell(cx, cy, rx, ry, 2.3)
    put(g, mand(box, win), '#')
    iris = mell(cx - sgn * 0.5, cy + 0.2, rx - 2.3, ry - 0.8, 2.1)
    put(g, mand(iris, win), 'I')
    # 홍채 아래쪽 한 단 밝게 — 유리알 느낌
    put(g, mand(mand(iris, mell(cx - sgn * 0.5, cy + ry * 0.66,
                                rx, ry * 0.55, 2.2)), win), 'B')
    put(g, mand(mell(cx - sgn * 0.5, cy + 0.6, rx * 0.42, ry * 0.46, 2.1),
                win), 'O')
    # 큰 반사점 (바깥 위) · 작은 반사점 (안쪽 아래)
    put(g, mand(mell(cx - sgn * rx * 0.40, cy - ry * 0.40, rx * 0.30,
                     ry * 0.27, 2.1), win), '#')
    put(g, mand(mell(cx + sgn * rx * 0.46, cy + ry * 0.46, 1.5, 1.4,
                     2.1), win), '#')
    # 위 속눈썹 — 바깥쪽이 두껍다
    lash = msub(box, mshift(mell(cx - sgn * 0.8, cy + 0.4, rx, ry, 2.3), 0, 2))
    put(g, mand(lash, win), 'O')
    # 아래 눈꺼풀은 살결 어두운 단으로 (검정으로 두르면 유리구슬이 된다)
    low = mand(msub(box, mshift(box, 0, -1)),
               mregion(lambda u, y: u > cx - rx * 0.55, 0, H - 1))
    put(g, mand(low, win), '6')


# ================================================================ 몸
def girl_locks(d):
    """긴 머리. 3/4 에서는 먼 쪽이 길게 흐르고 가까운 쪽은 짧은 한 갈래."""
    if d == 'up':
        wf = spline([(148, 46.2), (164, 47.0), (180, 46.8), (196, 45.6),
                     (208, 44.0), (218, 42.0), (224, 40.0)])
        bot = spline([(-50, 180), (-42, 198), (-33, 210), (-22, 216),
                      (-10, 218), (2, 216), (14, 212), (25, 206),
                      (35, 196), (45, 178)])
        return mand(mprof(148, 224, neg(wf), wf),
                    mregion(lambda u, y: y <= bot(u), 148, 224))
    if d == 'side':
        L = mprof(148, 212,
                  spline([(148, -47.8), (166, -48.6), (184, -48.0),
                          (198, -45.6), (208, -41), (212, -35)]),
                  spline([(148, -22), (166, -24), (184, -27), (198, -30),
                          (208, -33), (212, -35)]))
        R = mprof(148, 186,
                  spline([(148, 20), (164, 22), (176, 25), (184, 28),
                          (186, 30)]),
                  spline([(148, 43.0), (162, 43.0), (174, 41.4),
                          (182, 36), (186, 30)]))
        return mor(L, R)
    L = mprof(148, 204,
              spline([(148, -46.2), (164, -46.8), (180, -46.0),
                      (192, -43.4), (200, -39), (204, -33)]),
              spline([(148, -20), (164, -21.5), (180, -24), (192, -27),
                      (200, -31), (204, -33)]))
    R = mprof(148, 194,
              spline([(148, 20), (164, 21.5), (178, 24), (190, 28),
                      (194, 31)]),
              spline([(148, 46.2), (164, 46.4), (178, 45), (190, 40),
                      (194, 31)]))
    return mor(L, R)


def body(g, sex, d):
    side = (d == 'side')
    sx = 2.0 if side else 0.0        # 3/4 은 몸통이 조금 돌아간다

    if sex == 'boy':
        legs_boy(g, d, sx)
    else:
        legs_girl(g, d, sx)

    # ---------------- 목
    nc = (sx - 3.4) if side else 0.0
    neck = mtube(112, 152,
                 spline([(112, nc), (132, nc), (152, nc + 0.8)]),
                 spline([(112, 11.4), (126, 12.0), (138, 13.6), (146, 16.6),
                         (152, 19.4)]))
    vol(g, neck, SKIN, out=2, dd=3, dk=11, hi=0, lt=0)
    # 턱 그림자 — 턱선을 따라 둥글게 (가로로 뚝 자르면 연필 자국이 된다)
    jaw = 132 if not side else 131
    put(g, mand(neck, mregion(
        lambda u, y: y - jaw <= 5.5 - ((u - nc) / 9.0) ** 2 * 5.0,
        108, 150)), '6')
    put(g, mand(neck, mregion(
        lambda u, y: y - jaw <= 1.5 - ((u - nc) / 9.0) ** 2 * 4.0,
        108, 150)), '7')

    shirt_and_arms(g, sex, d, sx)

    if sex == 'girl':
        front_locks(g, d)


SH_LT = kd([(140, 3), (148, 6), (158, 10), (172, 11), (186, 9), (198, 7),
            (208, 5)])
SH_DK = kd([(140, 4), (150, 8), (162, 12), (176, 15), (190, 13), (208, 9)])
PT_LT = kd([(188, 5), (198, 8), (210, 10), (220, 7), (230, 5), (240, 7),
            (252, 6), (264, 5), (272, 5)])
PT_DK = kd([(188, 6), (200, 10), (212, 13), (222, 10), (232, 7), (242, 9),
            (252, 8), (264, 6), (272, 6)])


def shirt_and_arms(g, sex, d, sx):
    """윗도리는 몸통과 소매를 한 벌로 묶어 윤곽을 한 번만 두른다.
    소매마다 윤곽을 두르면 조끼를 껴입은 것처럼 보인다."""
    side = (d == 'side')
    tm = torso_mask(sex, d, sx)
    inner_t = msub(tm, outline(tm, 2))
    if side:
        fsl, ffo = arm_masks(sex, d, +1, True, sx)
        nsl, nfo = arm_masks(sex, d, -1, False, sx)
        vol(g, ffo, SKIN, out=2, dd=6, dk=13, hi=0, lt=0)
        vol(g, fsl, SHIRT, out=2, dd=7, dk=15, hi=0, lt=0)
        shirt = mor(tm, nsl)
        vol(g, shirt, SHIRT, out=0, dd=5, dk=SH_DK, hi=3, lt=SH_LT)
        torso_detail(g, tm, sex, d, sx)
        put(g, mand(outline(nsl, 2), inner_t), 'F')
        vol(g, nfo, SKIN, out=2, dd=3, dk=7, hi=3, lt=7)
        hand_detail(g, nfo, sex, d, -1, sx)
        put(g, msub(outline(shirt, 2), nfo), 'G')
    else:
        lsl, lfo = arm_masks(sex, d, -1, False, sx)
        rsl, rfo = arm_masks(sex, d, +1, False, sx)
        shirt = mor(tm, lsl, rsl)
        vol(g, shirt, SHIRT, out=0, dd=5, dk=SH_DK, hi=3, lt=SH_LT)
        torso_detail(g, tm, sex, d, sx)
        for s in (lsl, rsl):
            put(g, mand(outline(s, 2), inner_t), 'F')
        # 오른(빛 반대쪽) 소매는 한 단 더 눌러 준다
        put(g, band(rsl, 1, 1, 6), 'F')
        vol(g, lfo, SKIN, out=2, dd=3, dk=7, hi=3, lt=7)
        vol(g, rfo, SKIN, out=2, dd=4, dk=9, hi=2, lt=5)
        for (fo, s) in ((lfo, -1), (rfo, 1)):
            hand_detail(g, fo, sex, d, s, sx)
        put(g, msub(outline(shirt, 2), mor(lfo, rfo)), 'G')


def torso_mask(sex, d, sx):
    side = (d == 'side')
    if sex == 'girl':
        wr = spline([(140, 15), (143, 20.6), (146.5, 25.0), (151, 28.2),
                     (157, 30.0), (165, 30.4), (175, 29.6), (184, 28.6),
                     (190, 28.4), (196, 29.0)])
        bot = 198
    else:
        wr = spline([(140, 15), (143, 21.0), (146.5, 25.6), (151, 29.0),
                     (157, 31.2), (165, 31.8), (176, 31.4), (188, 31.2),
                     (198, 31.8), (205, 32.4), (208, 32.2)])
        bot = 208
    if side:
        # 어깨가 비틀린다 — 가까운(왼) 어깨가 한 줄 늦게 더 멀리 벌어진다
        fl = spline([(141, -13), (145, -19.6), (149, -24.6), (154, -28.0),
                     (160, -29.8), (169, -30.2), (181, -29.8), (193, -29.6),
                     (203, -30.0), (208, -29.8)])
        fr = spline([(140, 14), (143, 18.6), (146.5, 21.6), (151, 23.4),
                     (157, 24.2), (165, 24.4), (176, 24.0), (188, 23.8),
                     (198, 24.4), (205, 25.0), (208, 24.8)])
        if sex == 'girl':
            fl0, fr0 = fl, fr
            fl = lambda y: fl0(y) * 0.95
            fr = lambda y: fr0(y) * 0.95
        m = mprof(140, bot, fl, fr)
    else:
        m = mprof(140, bot, neg(wr), wr)
    # 목 구멍 — 여기 윤곽이 곧 옷깃이 된다
    if d == 'up':
        hole = mell(0, 140, 13.2, 5.6, 2.3)
    elif side:
        hole = mell(-3.0, 143, 14.0, 8.0, 2.3)
    else:
        hole = mell(0, 144, 14.6, 9.2, 2.3)
    m = msub(m, hole)
    hw = 30.0 if sex == 'boy' else 28.0
    return mand(m, mregion(
        lambda u, y: y <= bot - 2.6 * min(1.0, (u / hw) ** 2), 140, bot + 2))


def torso_detail(g, m, sex, d, sx):
    inner = msub(m, outline(m, 3))
    # 옷 주름 — 높이를 어긋나게. 좌우 대칭이면 무늬가 된다
    if sex == 'girl':
        folds = [(-17, 158, 188, 2.2), (-5, 170, 194, 1.6),
                 (10, 156, 180, 1.8), (20, 174, 192, 1.4)]
    else:
        folds = [(-18, 164, 198, 2.4), (-6, 178, 204, 1.7),
                 (11, 160, 186, 2.0), (21, 182, 206, 1.5)]
    for (u, y0, y1, wd) in folds:
        fm = mnew()
        f = spline([(y0, u), ((y0 + y1) * 0.5, u + 1.5), (y1, u + 2.8)])
        for y in range(y0, y1 + 1):
            k = wd * (1.0 - abs((y - (y0 + y1) * 0.5) / ((y1 - y0) * 0.5)) ** 2)
            if k < 0.45:
                continue
            mfill(fm, y, f(y) - k * 0.5, f(y) + k * 0.5)
        put(g, mand(fm, inner), 'F')

    if d == 'up':
        return
    if sex == 'boy':
        for by in (160, 174, 188):
            put(g, mand(mell(-1.0 + sx, by, 2.2, 2.2, 2.0), inner), 'A')
            put(g, mand(mell(-1.0 + sx, by + 1.5, 2.0, 1.1, 2.0), inner), 'F')
    else:
        # 둥근 옷깃
        col = msub(mell(-1.0 + sx * 0.6, 144, 20.0, 13.0, 2.4),
                   mell(-1.0 + sx * 0.6, 143, 15.0, 9.4, 2.3))
        col = mand(col, mregion(lambda u, y: y > 145, 140, 170))
        put(g, mand(col, inner), 'S')
        put(g, mand(msub(col, mshift(col, 0, -2)), inner), 'A')
        put(g, mand(msub(col, mshift(col, 0, 3)), inner), 'G')


def arm_masks(sex, d, sgn, far, sx):
    """소매(윗도리) + 팔뚝(살결) + 손. 가까운 팔은 밝고 크고 앞에."""
    scale = 0.88 if far else 1.0
    off = sx * (1.7 if not far else 0.2)

    if sex == 'girl':
        sc = spline([(143, 19.5), (148, 23.6), (154, 26.2), (161, 27.2),
                     (168, 27.4)])
        sr = spline([(143, 6.8), (147, 10.2), (152, 12.0), (159, 12.2),
                     (165, 11.6), (168, 10.6)])
        sbot, ftop = 168, 166
        fc = spline([(166, 27.0), (178, 28.0), (190, 28.4), (200, 28.0),
                     (210, 26.8), (218, 25.4)])
        fr_ = spline([(166, 8.0), (176, 7.5), (186, 7.0), (194, 6.6),
                      (200, 7.6), (206, 9.2), (211, 9.4), (215, 8.4),
                      (218, 5.6), (220, 2.4)])
        fbot = 220
    else:
        sc = spline([(143, 20.2), (148, 24.4), (154, 27.0), (162, 28.0),
                     (172, 28.4)])
        sr = spline([(143, 7.0), (147, 10.4), (152, 11.8), (160, 12.0),
                     (168, 11.6), (172, 10.8)])
        sbot, ftop = 172, 170
        fc = spline([(170, 28.0), (182, 28.8), (194, 29.2), (204, 28.8),
                     (214, 27.6), (222, 26.0)])
        fr_ = spline([(170, 8.4), (180, 7.9), (190, 7.4), (198, 7.0),
                      (204, 8.0), (210, 9.6), (215, 9.8), (219, 8.6),
                      (222, 5.8), (224, 2.4)])
        fbot = 224

    fore = mtube(ftop, fbot,
                 lambda y: sgn * fc(y) * scale + off,
                 lambda y: fr_(y) * scale)
    sleeve = mtube(143, sbot,
                   lambda y: sgn * sc(y) * scale + off,
                   lambda y: sr(y) * scale)
    return sleeve, fore


def hand_detail(g, fore, sex, d, sgn, sx):
    """손가락 골 두 개. 길이를 다르게 해야 손으로 읽힌다."""
    hy = 205 if sex == 'girl' else 209
    inner = msub(fore, outline(fore, 2))
    cx = sgn * (27.0 if sex == 'girl' else 28.0) + sx * 1.7
    for (dy, ln, sh) in ((0, 7.6, 0.0), (5, 6.0, 0.6)):
        fm = mnew()
        for y in range(hy + dy, hy + dy + 2):
            mfill(fm, y, cx - ln * 0.5 + sh, cx + ln * 0.5 + sh)
        put(g, mand(fm, inner), '5')


def legs_boy(g, d, sx):
    side = (d == 'side')
    hip = spline([(194, 30.4), (200, 31.6), (206, 32.0), (212, 31.2),
                  (218, 30.0)])
    notch = spline([(214, 0.0), (219, 1.4), (226, 2.6), (236, 3.6),
                    (248, 4.4), (258, 5.0)])
    lc = spline([(212, 15.2), (226, 15.6), (240, 15.8), (254, 15.8),
                 (262, 15.8)])
    lr = spline([(212, 15.2), (222, 14.0), (234, 12.6), (246, 11.8),
                 (258, 11.4), (262, 11.4)])
    cshift = {-1: 6.5, 1: -7.5} if side else {-1: 0.0, 1: 0.0}
    order = [1, -1] if side else [-1, 1]

    if side:
        hipm = mprof(194, 216, lambda y: -hip(y) * 0.80 + sx,
                     lambda y: hip(y) * 0.80 + sx * 1.6)
    else:
        hipm = mprof(194, 216, neg(hip), hip)

    legs = {}
    for s in (-1, 1):
        cs = cshift[s]
        far = side and s > 0
        sc_ = 0.84 if far else 1.0
        legm = mprof(210, 258,
                     lambda y, s=s, cs=cs, k=sc_: s * lc(y) + cs - lr(y) * k,
                     lambda y, s=s, cs=cs, k=sc_: s * lc(y) + cs + lr(y) * k)
        if not side:
            legm = mand(legm, mregion(
                lambda u, y, s=s: (u >= notch(y)) if s > 0 else (u <= -notch(y)),
                210, 258))
        legs[s] = legm

    if side:
        vol(g, legs[1], PANT, out=2, dd=7, dk=16, hi=0, lt=0)
        boot(g, d, 1, cshift[1], True, 'boy')
        pants = mor(hipm, legs[-1])
        vol(g, pants, PANT, out=2, dd=5, dk=PT_DK, hi=4, lt=PT_LT)
        boot(g, d, -1, cshift[-1], False, 'boy')
    else:
        pants = mor(hipm, legs[-1], legs[1])
        vol(g, pants, PANT, out=2, dd=5, dk=PT_DK, hi=4, lt=PT_LT)
        put(g, band(legs[1], 1, 1, 7), 'v')
        put(g, band(legs[1], 1, 1, 3), 'v')
        put(g, mand(outline(pants, 2), pants), 'b')
        for s in (-1, 1):
            boot(g, d, s, 0.0, False, 'boy')


def legs_girl(g, d, sx):
    side = (d == 'side')
    lc = spline([(226, 13.0), (240, 13.4), (252, 13.6), (264, 13.6),
                 (270, 13.6)])
    lr = spline([(226, 10.6), (238, 9.6), (250, 8.8), (262, 8.4),
                 (270, 8.4)])
    notch = spline([(226, 0.0), (234, 1.6), (244, 2.8), (256, 3.6),
                    (268, 4.2)])
    cshift = {-1: 5.5, 1: -6.5} if side else {-1: 0.0, 1: 0.0}
    order = [1, -1] if side else [-1, 1]
    for s in order:
        cs = cshift[s]
        far = side and s > 0
        sc_ = 0.9 if far else 1.0
        legm = mprof(226, 270,
                     lambda y, s=s, cs=cs, k=sc_: s * lc(y) + cs - lr(y) * k,
                     lambda y, s=s, cs=cs, k=sc_: s * lc(y) + cs + lr(y) * k)
        if not side:
            legm = mand(legm, mregion(
                lambda u, y, s=s: (u >= notch(y)) if s > 0 else (u <= -notch(y)),
                226, 270))
        if far:
            vol(g, legm, SKIN, out=2, dd=7, dk=16, hi=0, lt=0)
        else:
            vol(g, legm, SKIN, out=2, dd=3, dk=8 if s < 0 else 9,
                hi=3, lt=8 if s < 0 else 5)
        boot(g, d, s, cs, far, 'girl')

    sk = spline([(190, 27.4), (198, 30.2), (206, 33.6), (214, 37.2),
                 (222, 40.6), (230, 43.6), (236, 45.4), (240, 46.2)])
    hem = spline([(-52, 230), (-44, 240), (-36, 244), (-27, 236),
                  (-16, 247), (-4, 239), (7, 248), (18, 241), (28, 246),
                  (37, 238), (45, 243), (52, 232)])
    if side:
        skm = mprof(190, 250, lambda y: -sk(y) * 0.88 + sx,
                    lambda y: sk(y) * 0.88 + sx * 2.0)
    else:
        skm = mprof(190, 250, neg(sk), sk)
    skm = mand(skm, mregion(lambda u, y: y <= hem(u), 190, 252))
    vol(g, skm, PANT, out=2, dd=5,
        dk=kd([(190, 6), (200, 10), (212, 14), (224, 17), (236, 15),
               (250, 11)]),
        hi=4,
        lt=kd([(190, 5), (200, 8), (212, 11), (226, 13), (238, 11),
               (250, 8)]))
    inner = msub(skm, outline(skm, 3))
    for (u0, u1, y0, y1, wd) in ((-38, -33, 204, 240, 2.4),
                                 (-24, -18, 196, 243, 2.0),
                                 (-9, -5, 208, 236, 1.7),
                                 (6, 11, 194, 245, 2.3),
                                 (21, 27, 202, 239, 1.9),
                                 (33, 39, 212, 236, 1.5)):
        fm = mnew()
        f = spline([(y0, u0), (y1, u1)])
        for y in range(y0, y1 + 1):
            k = wd * (1.0 - abs((y - (y0 + y1) * 0.5) / ((y1 - y0) * 0.5)) ** 3)
            if k < 0.45:
                continue
            mfill(fm, y, f(y) - k * 0.5, f(y) + k * 0.5)
        put(g, mand(fm, inner), 'v')


def boot(g, d, s, cs, far, sex):
    side = (d == 'side')
    if sex == 'boy':
        top, sole = 250, 286
        bc = spline([(250, 15.8), (262, 16.2), (274, 16.6), (283, 16.8),
                     (286, 16.6)])
        br = spline([(250, 12.8), (254, 13.8), (264, 14.4), (274, 15.0),
                     (281, 15.6), (285, 15.4), (286, 14.2)])
    else:
        top, sole = 266, 286
        bc = spline([(266, 13.4), (276, 13.8), (283, 14.0), (286, 13.8)])
        br = spline([(266, 9.8), (270, 11.0), (277, 11.8), (282, 12.4),
                     (285, 12.2), (286, 11.0)])
    if far:
        sole -= 4
    toe = (8.0 if not far else 5.5) if side else 0.0
    bs = 0.84 if far else 1.0
    m = mprof(top, sole,
              lambda y: s * bc(y) + cs - br(y) * bs + toe * 0.45,
              lambda y: s * bc(y) + cs + br(y) * bs + toe)
    if not side:
        nt = spline([(top, 4.4), (sole, 5.2)]) if sex == 'boy' \
            else spline([(top, 4.0), (sole, 4.8)])
        m = mand(m, mregion(
            lambda u, y, s=s: (u >= nt(y)) if s > 0 else (u <= -nt(y)),
            top, sole))
    cc = s * bc(top) + cs + toe * 0.5
    ww = br(top) + 2.0
    m = mand(m, mregion(
        lambda u, y: y >= top + 3.2 * (1.0 - min(1.0, ((u - cc) / ww) ** 2)),
        top - 2, sole))
    if far:
        vol(g, m, SHOE, out=2, dd=0, dk=22, hi=0, lt=0)
    else:
        vol(g, m, SHOE, out=2, dd=3, dk=9, hi=0, lt=0)
    put(g, mand(m, mregion(lambda u, y: y >= sole - 3, top, sole)), 'j')
    put(g, mand(m, mregion(lambda u, y: y >= sole - 1, top, sole)), 'k')
    if d != 'up' and not far:
        put(g, mand(msub(m, outline(m, 2)),
                    mregion(lambda u, y: top + 4 <= y <= top + 5, top, sole)),
            'j')


def front_locks(g, d):
    """어깨 앞으로 흘러내린 갈래. 좌우 길이를 다르게."""
    if d == 'up':
        return
    if d == 'side':
        specs = [(spline([(114, -38), (138, -40), (158, -39), (172, -36),
                          (180, -31)]),
                  spline([(114, -27), (138, -29), (158, -30), (172, -31),
                          (180, -31)]), 114, 180)]
    else:
        specs = [(spline([(116, -37), (138, -39), (154, -38), (166, -35),
                          (173, -30)]),
                  spline([(116, -27), (138, -29), (154, -29.5), (166, -30),
                          (173, -30)]), 116, 173),
                 (spline([(116, 27), (136, 28), (150, 28.5), (160, 29),
                          (165, 30)]),
                  spline([(116, 37), (136, 38.5), (150, 37), (160, 34),
                          (165, 30)]), 116, 165)]
    for (fl, fr, y0, y1) in specs:
        m = mprof(y0, y1, fl, fr)
        vol(g, m, HAIR, out=2, dd=4, dk=9, hi=0, lt=4)


# ================================================================ 조립
def build(sex, d):
    g = [['.'] * W for _ in range(H)]
    gh = [['.'] * W for _ in range(H)]
    head(gh, sex, d)
    # 긴 머리는 어깨 아래쪽이 몸 뒤로 가야 소매가 보인다.
    # 머리를 따로 한 장에 찍어 두고 몸 앞뒤로 나눠 붙인다.
    # 뒷모습에서는 긴 머리가 등을 통째로 덮는다
    cut = 132 if (sex == 'girl' and d != 'up') else H
    for y in range(cut, H):
        for x in range(W):
            if gh[y][x] != '.':
                g[y][x] = gh[y][x]
    body(g, sex, d)
    for y in range(0, min(cut + 1, H)):
        for x in range(W):
            if gh[y][x] != '.':
                g[y][x] = gh[y][x]
    return g


def despeckle(g):
    """외톨이 한 칸은 그림이 아니라 먼지다. 이웃 다수 색으로 메운다."""
    for _ in range(2):
        fix = []
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                c = g[y][x]
                if c == '.':
                    continue
                cnt = {}
                same = 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                               (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    n = g[y + dy][x + dx]
                    if n == c:
                        same += 1
                    if n != '.':
                        cnt[n] = cnt.get(n, 0) + 1
                if same == 0 and cnt:
                    fix.append((x, y, max(cnt, key=cnt.get)))
        if not fix:
            break
        for (x, y, n) in fix:
            g[y][x] = n
    return g


def center_and_floor(g):
    xs = [x for y in range(H) for x in range(W) if g[y][x] != '.']
    ys = [y for y in range(H) for x in range(W) if g[y][x] != '.']
    if not xs:
        return g
    dx = int(round(95.5 - (min(xs) + max(xs)) / 2.0))
    dy = 286 - max(ys)
    if dx or dy:
        ng = [['.'] * W for _ in range(H)]
        for y in range(H):
            ny = y + dy
            if not (0 <= ny < H):
                continue
            for x in range(W):
                if g[y][x] != '.':
                    nx = x + dx
                    if 0 <= nx < W:
                        ng[ny][nx] = g[y][x]
        g = ng
    return g


def save(g, path):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            ch = g[y][x]
            if ch != '.':
                r, gg, b = C[ch]
                px[x, y] = (r, gg, b, 255)
    im.save(path)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    for sex in ('boy', 'girl'):
        for d in ('down', 'side', 'up'):
            g = build(sex, d)
            g = center_and_floor(despeckle(g))
            p = os.path.join(here, 'w192_d_%s_%s.png' % (sex, d))
            save(g, p)
            print('wrote', os.path.basename(p))


if __name__ == '__main__':
    main()
