# -*- coding: utf-8 -*-
# 후보 z — 「댕기 소녀」. 128x192 를 도트로 직접 찍는다 (확대·축소 없음).
import os
from PIL import Image

PAL = {
    'O': (54, 33, 26), 's': (243, 159, 138), 'S': (213, 116, 98), 'H': (250, 192, 170),
    'e': (66, 32, 30), 'i': (136, 70, 42), 'w': (246, 242, 234), 'r': (235, 128, 114),
    'm': (170, 84, 66), 'b': (58, 88, 168), 'B': (38, 58, 120), 'L': (94, 126, 200),
    'p': (134, 88, 46), 'P': (98, 62, 32), 'q': (158, 108, 58), 'h': (118, 72, 40),
    'j': (152, 100, 56), 'g': (86, 52, 30), 'k': (82, 53, 33), 'n': (68, 44, 29),
    'K': (56, 37, 25),
}
W, H = 128, 192
GROUND = 190

# 세 벌 — 머리 모양과 차림만 다르다. 얼굴·골격은 같은 그림체를 쓴다.
STYLES = {
    'z1': {'name': '앞치마 소녀', 'pigtail': True, 'bang': 'split', 'bottom': 'skirt',
           'top': 'apron', 'sock': False},
    'z2': {'name': '반바지 소년', 'pigtail': False, 'bang': 'boy', 'bottom': 'shorts',
           'top': 'tee', 'sock': True},
    'z3': {'name': '멜빵 소녀', 'pigtail': False, 'bang': 'bob', 'bottom': 'overall',
           'top': 'overall', 'sock': False},
}
ST = STYLES['z1']

class C:
    def __init__(self):
        self.d = [[None] * W for _ in range(H)]
    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.d[y][x] = c
    def at(self, x, y):
        return self.d[y][x] if 0 <= x < W and 0 <= y < H else None
    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)
    def ell(self, cx, cy, rx, ry, c, yr=None):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            if yr and not (yr[0] <= y <= yr[1]):
                continue
            t = (y - cy) / ry
            if abs(t) > 1:
                continue
            hw = rx * (1 - t * t) ** 0.5
            for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
                self.px(x, y, c)
    def stamp(self, rows, x0, y0):
        for dy, r in enumerate(rows):
            for dx, ch in enumerate(r):
                if ch != '.':
                    self.px(x0 + dx, y0 + dy, ch)
    def outline(self):
        edge = []
        for y in range(H):
            for x in range(W):
                if self.d[y][x] is not None:
                    continue
                if any(self.at(x + dx, y + dy) not in (None, 'O')
                       for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    edge.append((x, y))
        for x, y in edge:
            self.px(x, y, 'O')
    def save(self, path):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        o = im.load()
        for y in range(H):
            for x in range(W):
                c = self.d[y][x]
                if c:
                    o[x, y] = PAL[c] + (255,)
        im.save(path)

# ---- 자리 ----
HEAD_CX, HEAD_CY, HEAD_RX, HEAD_RY = 64, 48, 37, 40      # 머리 74x80 (키의 42%)
NECK_Y = 88
SH_Y = 92                                                 # 어깨
WAIST_Y = 126
HIP_Y = 132
SKIRT_Y = 152
KNEE_Y = 168
BOOT_Y = 176

# 큰 눈 18x22 — 검은 눈망울, 흰 반짝이 둘, 아래에 밝은 홍채
EYE = [
    '....eeeeeeeeee....',
    '..eeeeeeeeeeeeee..',
    '.eeeeeeeeeeeeeeee.',
    'eeeeeeeeeeeeeeeeee',
    'eeewwwweeeeeeeeeee',
    'eeewwwweeeeeeeeeee',
    'eeewwwweeeeeeeeeee',
    'eeeewweeeeeeeeeeee',
    'eeeeeeeeeeeeeeeeee',
    'eeeeeeeeeeeeeeeeee',
    'eeeeeeeeeeeeeeeeee',
    'eeeeeeeeeeeeeewwee',
    'eeiiiiiiiiiiiiwwee',
    'eeiiiiiiiiiiiiiiee',
    '.eiiiiiiiiiiiiiie.',
    '.eeiiiiiiiiiiiiee.',
    '..eeeiiiiiiiieee..',
    '...eeeeeeeeeeee...',
]
BROW = [
    '..iiiiiiiiii..',
    'iiii......iiii',
]


def face(c, blink=False):
    ex_l, ex_r, ey = 26, 84, 44
    if blink:
        for x0 in (ex_l, ex_r):
            for k, row in enumerate(('ee............ee', '.eeeeeeeeeeeeee.', '..eeeeeeeeeeee..')):
                c.stamp([row], x0 + 1, ey + 12 + k)
    else:
        c.stamp(EYE, ex_l, ey)
        c.stamp([r[::-1] for r in EYE], ex_r, ey)
    c.stamp(BROW, ex_l + 2, ey - 9)
    c.stamp([r[::-1] for r in BROW], ex_r + 2, ey - 9)
    c.rect(62, 70, 63, 71, 'S')                       # 코
    for x in range(58, 70):                           # 입 — 살짝 웃는 선
        c.px(x, 78, 'm')
    c.px(57, 77, 'm'); c.px(70, 77, 'm')
    c.rect(33, 69, 40, 73, 'r')                       # 볼터치 — 얼굴 안쪽
    c.rect(88, 69, 95, 73, 'r')


def hair_front(c):
    # 머리통 위를 덮는 앞머리 — 가운데가 살짝 갈라지고 끝이 뾰족
    for x in range(HEAD_CX - HEAD_RX - 3, HEAD_CX + HEAD_RX + 4):
        d = abs(x - HEAD_CX)
        top = HEAD_CY - HEAD_RY - 3 + int((d / HEAD_RX) ** 2 * 8)
        tips = {'split': [(29, 11), (44, 7), (58, 12), (72, 8), (86, 13), (99, 9)],
                'boy': [(32, 9), (46, 13), (62, 8), (78, 12), (94, 9)],
                'bob': [(30, 8), (48, 11), (64, 7), (80, 11), (98, 8)]}[ST['bang']]
        deep = max(0.0, max(dv - abs(x - t) * 1.15 for t, dv in tips))
        bot = 30 + deep
        if d > HEAD_RX - 4:
            bot = {'split': 74, 'boy': 58, 'bob': 84}[ST['bang']]   # 구레나룻 길이
        for y in range(top, int(bot)):
            if c.at(x, y) is not None or (x - HEAD_CX) ** 2 / (HEAD_RX + 3.0) ** 2 + (y - HEAD_CY) ** 2 / (HEAD_RY + 3.0) ** 2 <= 1:
                c.px(x, y, 'h')
    if ST['pigtail']:                                  # 옆으로 낮게 묶은 댕기 두 갈래
        for d, sx in ((-1, HEAD_CX - HEAD_RX + 2), (1, HEAD_CX + HEAD_RX - 2)):
            for y in range(62, 118):
                t = (y - 62) / 55.0
                wd = int(round(11 - 5 * t * t))
                cxp = sx + d * (3 + int(6 * t * t))
                for k in range(wd):
                    c.px(cxp + d * k, y, 'h')
    elif ST['bang'] == 'bob':                          # 턱선에서 안으로 말리는 단발
        for d, sx in ((-1, HEAD_CX - HEAD_RX + 1), (1, HEAD_CX + HEAD_RX - 1)):
            for y in range(70, 96):
                t = (y - 70) / 25.0
                wd = int(round(10 - 6 * t * t))
                cxp = sx - d * int(2 * t * t)
                for k in range(wd):
                    c.px(cxp + d * k, y, 'h')
    # 결 — 밝은 면 · 그늘
    for y in range(H):
        for x in range(W):
            if c.at(x, y) != 'h':
                continue
            if 34 <= x <= 58 and 14 <= y <= 30:
                c.px(x, y, 'j')
            elif c.at(x, y + 1) is None or c.at(x + 1, y) is None:
                c.px(x, y, 'g')


def _arm(c, sx, sy, ex, ey, w0, w1, cuff, hand_r, light):
    """어깨에서 손목까지 팔 하나 — 축을 따라 두께를 재어 긋는다(꺾여도 굵기가 산다)."""
    import math
    d = math.hypot(ex - sx, ey - sy)
    ux, uy = (ex - sx) / d, (ey - sy) / d
    nx, ny = uy, -ux
    cells = []
    n = int(d * 2) + 1
    for i in range(n + 1):
        t = i / n
        cx, cy = sx + (ex - sx) * t, sy + (ey - sy) * t
        hw = (w0 + (w1 - w0) * t) / 2.0
        j = -int(hw * 2)
        while j <= int(hw * 2):
            v = j / 2.0
            px_, py_ = round(cx + nx * v), round(cy + ny * v)
            col = 'b'
            if t > cuff:
                col = 'B'
            elif (v <= -hw + 1.2 and light < 0) or (v >= hw - 1.2 and light > 0):
                col = 'L'
            elif (v >= hw - 1.2 and light < 0) or (v <= -hw + 1.2 and light > 0):
                col = 'B'
            cells.append((px_, py_, col))
            j += 1
    for x, y, col in cells:
        c.px(x, y, col)
    c.ell(ex, ey + hand_r - 1, hand_r, hand_r + 1, 's')
    c.ell(ex + (2 if light < 0 else -2), ey + hand_r, hand_r - 3, hand_r - 2, 'S')


def _skirt(c, cx, y0, y1, w0, w1, pleats=(0.3, 0.52, 0.74)):
    for y in range(y0, y1 + 1):
        t = (y - y0) / float(max(1, y1 - y0))
        hw = w0 + (w1 - w0) * t * t
        for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
            c.px(x, y, 'p')
    for y in range(y0, y1 + 1):
        xs = [x for x in range(W) if c.at(x, y) == 'p']
        if not xs:
            continue
        xa, xb = min(xs), max(xs)
        for x in xs:
            f = (x - xa) / float(max(1, xb - xa))
            if x - xa <= 2:
                c.px(x, y, 'q')
            elif xb - x <= 2 or y >= y1 - 1 or y <= y0 + 1:
                c.px(x, y, 'P')
            elif any(abs(f - pf) * (xb - xa) < 0.8 for pf in pleats):
                c.px(x, y, 'P')


def _shorts(c, cx, y0, y1, w0, w1):
    for y in range(y0, y1 + 1):
        t = (y - y0) / float(max(1, y1 - y0))
        hw = w0 + (w1 - w0) * t
        for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
            c.px(x, y, 'p')
    for y in range(y0, y1 + 1):
        xs = [x for x in range(W) if c.at(x, y) == 'p']
        if not xs:
            continue
        xa, xb = min(xs), max(xs)
        for x in xs:
            if x - xa <= 2:
                c.px(x, y, 'q')
            elif xb - x <= 2 or y >= y1 - 1 or y <= y0 + 1:
                c.px(x, y, 'P')
    if cx > 40:                                        # 정면만 가랑이를 낸다
        c.rect(cx - 1, y1 - 6, cx + 1, y1, 'P')


def _pants(c, pairs, y0):
    for lx, inner in pairs:
        c.rect(lx - 8, y0, lx + 8, BOOT_Y - 1, 'p')
        c.rect(lx - 8, y0, lx - 6, BOOT_Y - 1, 'q')
        c.rect(lx + 6, y0, lx + 8, BOOT_Y - 1, 'P')
        c.rect(lx - 8, y0, lx + 8, y0 + 2, 'P')
    if len(pairs) == 2:
        c.rect(63, y0 + 4, 65, BOOT_Y - 1, 'P')


def _legs(c, pairs, top):
    for lx, inner in pairs:
        c.rect(lx - 6, top, lx + 6, BOOT_Y, 's')
        c.rect(lx + inner * 3, top, lx + inner * 6, BOOT_Y, 'S')
        c.rect(lx - 7, BOOT_Y, lx + 7, GROUND - 1, 'k')          # 부츠
        c.rect(lx - 7, GROUND - 4, lx + 7, GROUND - 1, 'K')
        c.rect(lx - 5, BOOT_Y, lx + 5, BOOT_Y + 1, 'n')          # 발목 접단
        c.px(lx - 7, BOOT_Y, None)
        c.px(lx + 7, BOOT_Y, None)
        c.px(lx - 7, GROUND - 1, None)
        c.px(lx + 7, GROUND - 1, None)


def body_front(c):
    c.rect(58, NECK_Y - 3, 69, NECK_Y + 4, 's')                  # 목
    c.rect(58, NECK_Y - 3, 69, NECK_Y - 1, 'S')
    # 몸통 — 어깨에서 허리로 살짝 좁아진다
    for y in range(SH_Y, WAIST_Y + 1):
        t = (y - SH_Y) / float(WAIST_Y - SH_Y)
        hw = 24 - 3 * t
        if y < SH_Y + 4:                                          # 어깨 모서리 둥글리기
            hw -= (SH_Y + 4 - y) * 1.6
        for x in range(int(round(64 - hw)), int(round(64 + hw)) + 1):
            c.px(x, y, 'b')
    for y in range(SH_Y, WAIST_Y + 1):
        xs = [x for x in range(W) if c.at(x, y) in ('b', 'B', 'L')]
        if xs:
            for k in range(3):
                c.px(min(xs) + k, y, 'L')
                c.px(max(xs) - k, y, 'B')
    # 블라우스는 밝은 칸, 앞치마는 어두운 칸 — 한 단 차이로는 「좀 짙은 옷」으로만 보인다
    for y in range(SH_Y, WAIST_Y + 1):
        for x in range(W):
            if c.at(x, y) == 'b':
                c.px(x, y, 'L')
    if ST['top'] == 'apron':
        c.rect(50, SH_Y + 7, 78, WAIST_Y, 'B')                   # 앞치마
        c.rect(53, SH_Y - 1, 57, SH_Y + 7, 'B')                  # 어깨끈 둘
        c.rect(71, SH_Y - 1, 75, SH_Y + 7, 'B')
    elif ST['top'] == 'overall':
        c.rect(47, SH_Y + 12, 81, WAIST_Y, 'B')                  # 멜빵바지 앞판
        c.rect(52, SH_Y - 1, 58, SH_Y + 14, 'B')                 # 멜빵 둘
        c.rect(70, SH_Y - 1, 76, SH_Y + 14, 'B')
        c.px(56, SH_Y + 16, 'q'); c.px(72, SH_Y + 16, 'q')       # 단추
    else:                                                        # 반팔 티
        c.rect(40, WAIST_Y - 6, 88, WAIST_Y, 'B')                # 아랫단
    c.rect(40, WAIST_Y - 4, 88, WAIST_Y, 'B')                    # 허리띠
    c.rect(56, SH_Y - 1, 72, SH_Y + 1, 'b')                      # 깃
    _arm(c, 44, SH_Y + 4, 34, SH_Y + 28, 14, 10, 0.72, 7, -1)    # 왼팔
    _arm(c, 84, SH_Y + 4, 94, SH_Y + 28, 14, 10, 0.72, 7, 1)     # 오른팔
    if ST['bottom'] == 'skirt':
        _skirt(c, 64, HIP_Y, SKIRT_Y, 23, 42)
        _legs(c, ((54, 1), (74, -1)), SKIRT_Y - 2)
    elif ST['bottom'] == 'shorts':
        _shorts(c, 64, HIP_Y, SKIRT_Y - 4, 23, 26)
        _legs(c, ((54, 1), (74, -1)), SKIRT_Y - 6)
    else:                                                        # 긴바지
        _pants(c, ((54, 1), (74, -1)), HIP_Y)
        _legs(c, ((54, 1), (74, -1)), BOOT_Y - 1)


def side(c):
    cx = 66
    c.ell(cx - 2, HEAD_CY, HEAD_RX - 2, HEAD_RY, 's')
    for y in range(54, 68):                                       # 코
        w = 4 - abs(y - 61) // 2
        for x in range(cx + HEAD_RX - 4, cx + HEAD_RX - 4 + w):
            c.px(x, y, 's')
    c.rect(cx + HEAD_RX - 4, 66, cx + HEAD_RX - 2, 67, 'S')
    for y in range(20, 80):                                       # 뒤통수 그늘
        for x in range(cx - HEAD_RX, cx - HEAD_RX + 7):
            if c.at(x, y) == 's':
                c.px(x, y, 'S')
    c.ell(cx - 12, HEAD_CY - 14, 16, 12, 'H')
    c.stamp(EYE, cx + 10, 46)
    c.stamp(BROW, cx + 12, 37)
    for x in range(cx + 18, cx + 26):
        c.px(x, 78, 'm')
    c.px(cx + 17, 77, 'm')
    c.rect(cx + 2, 68, cx + 9, 72, 'r')
    c.rect(cx - 14, 56, cx - 11, 62, 'S')                         # 귀
    c.px(cx - 13, 58, 's'); c.px(cx - 13, 59, 's')
    # 머리 — 앞머리 + 뒤로 흐르는 머리채
    for x in range(cx - HEAD_RX - 3, cx + HEAD_RX + 2):
        d = x - (cx - 2)
        top = HEAD_CY - HEAD_RY - 3 + int((abs(d) / float(HEAD_RX)) ** 2 * 8)
        deep = max(0.0, max(dv - abs(x - t) * 1.1 for t, dv in ((52, 12), (66, 8), (79, 13), (90, 9))))
        bot = 30 + deep if d > -8 else 80
        for y in range(top, int(bot)):
            if c.at(x, y) is not None or d ** 2 / (HEAD_RX + 2.0) ** 2 + (y - HEAD_CY) ** 2 / (HEAD_RY + 3.0) ** 2 <= 1:
                c.px(x, y, 'h')
    # 뒤로 넘어간 머리 — 머리통 뒤에 붙여서 좁게. 넓게 깔면 머리 모양이 안 읽힌다
    if ST['pigtail']:
        for y in range(64, 118):                                  # 묶은 다발 하나
            t = (y - 64) / 53.0
            wd = int(round(11 - 6 * t * t))
            sx = cx - HEAD_RX - 1 - int(4 * t * t)
            for k in range(wd):
                c.px(sx + k, y, 'h')
    elif ST['bang'] == 'bob':
        for y in range(60, 92):                                   # 턱선 단발
            t = (y - 60) / 31.0
            wd = int(round(13 - 8 * t * t))
            sx = cx - HEAD_RX - 1 + int(3 * t * t)
            for k in range(wd):
                c.px(sx + k, y, 'h')
    else:
        for y in range(58, 74):                                   # 짧은 뒷머리
            t = (y - 58) / 15.0
            wd = int(round(10 - 7 * t * t))
            sx = cx - HEAD_RX - 1 + int(2 * t)
            for k in range(wd):
                c.px(sx + k, y, 'h')
    for y in range(H):
        for x in range(W):
            if c.at(x, y) == 'h':
                if 42 <= x <= 64 and 14 <= y <= 30:
                    c.px(x, y, 'j')
                elif c.at(x, y + 1) is None or c.at(x + 1, y) is None:
                    c.px(x, y, 'g')
    c.rect(cx - 5, NECK_Y - 3, cx + 3, NECK_Y + 4, 's')
    c.rect(cx - 5, NECK_Y - 3, cx + 3, NECK_Y - 1, 'S')
    for y in range(SH_Y, WAIST_Y + 1):
        t = (y - SH_Y) / float(WAIST_Y - SH_Y)
        hw = 16 - 2 * t
        if y < SH_Y + 4:
            hw -= (SH_Y + 4 - y) * 1.2
        for x in range(int(round(cx - 2 - hw)), int(round(cx - 2 + hw)) + 1):
            c.px(x, y, 'b')
    for y in range(SH_Y, WAIST_Y + 1):
        xs = [x for x in range(W) if c.at(x, y) in ('b', 'B', 'L')]
        if xs:
            for k in range(3):
                c.px(max(xs) - k, y, 'L')
                c.px(min(xs) + k, y, 'B')
    for y in range(SH_Y, WAIST_Y + 1):
        for x in range(W):
            if c.at(x, y) == 'b':
                c.px(x, y, 'L')
    c.rect(cx - 12, SH_Y + 7, cx + 5, WAIST_Y, 'B')               # 앞치마
    c.rect(cx - 18, WAIST_Y - 4, cx + 14, WAIST_Y, 'B')           # 허리띠
    c.rect(cx - 4, SH_Y - 1, cx + 4, SH_Y + 1, 'b')               # 깃
    _arm(c, cx + 2, SH_Y + 5, cx + 4, SH_Y + 29, 13, 10, 0.72, 7, 1)
    if ST['bottom'] == 'skirt':
        _skirt(c, cx - 2, HIP_Y, SKIRT_Y, 17, 30)
        _legs(c, ((cx - 4, -1),), SKIRT_Y - 2)
    elif ST['bottom'] == 'shorts':
        _shorts(c, cx - 2, HIP_Y, SKIRT_Y - 4, 17, 19)
        _legs(c, ((cx - 4, -1),), SKIRT_Y - 6)
    else:
        _pants(c, ((cx - 4, -1),), HIP_Y)
        _legs(c, ((cx - 4, -1),), BOOT_Y - 1)
def build_down():
    c = C()
    body_front(c)
    c.ell(HEAD_CX, HEAD_CY, HEAD_RX, HEAD_RY, 's')
    c.ell(HEAD_CX - 8, HEAD_CY - 14, 20, 14, 'H')
    for y in range(HEAD_CY - 6, HEAD_CY + HEAD_RY):                # 오른쪽 그늘
        for x in range(HEAD_CX + HEAD_RX - 6, HEAD_CX + HEAD_RX + 1):
            if c.at(x, y) == 's':
                c.px(x, y, 'S')
    face(c)
    hair_front(c)
    c.outline()
    return c


def build_side():
    c = C()
    side(c)
    c.outline()
    return c


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    for key in STYLES:
        ST = STYLES[key]
        globals()['ST'] = ST
        build_down().save(os.path.join(here, '%s_down.png' % key))
        build_side().save(os.path.join(here, '%s_side.png' % key))
        for n in ('%s_down' % key, '%s_side' % key):
            im = Image.open(os.path.join(here, n + '.png')).convert('RGBA')
            px = im.load()
            ys = [y for y in range(im.height) for x in range(im.width) if px[x, y][3]]
            bad = {px[x, y][:3] for y in range(im.height) for x in range(im.width)
                   if px[x, y][3] and px[x, y][:3] not in set(PAL.values())}
            print(ST['name'], n, im.size, '발바닥', max(ys), '키', max(ys) - min(ys), '팔레트밖', len(bad))
