# 프롤로그 일러스트 — 오프닝 편지지 위에 얹는 움직이는 도트 장면.
#
#   1 prologue_grandpa_0..3.png  별하늘 아래 망원경을 보는 할아버지 (별 반짝임·별똥별)
#   2 prologue_box_0..3.png      물려받은 나무 상자 (촛불 일렁임·먼지)
#   3 prologue_letter_0..3.png   할아버지의 편지 (촛불 빛 일렁임·깃펜)
#   4 prologue_farm_0..3.png     잡초 무성한 농장 (구름·새·풀 흔들림·낙엽)
#
# 논리 252x108 을 2배로 키워 504x216 — 스토리 패널(540폭) 안에 꼭 맞는다.
# 레트로 마감: 바랜 필름 톤 + 4x4 오더드 디더링 + 굵은 색 계단 + 비네트.
# 실행: python3 make_prologue.py  (이 폴더에서)

import math
import os
import random
from PIL import Image

W, H = 252, 108
SCALE = 2
FRAMES = 4
REF = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))


class Canvas:
    def __init__(self):
        self.im = Image.new('RGB', (W, H))
        self.px = self.im.load()

    def p(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[int(x), int(y)] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                self.px[x, y] = c

    def disk(self, cx, cy, r, c):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.p(x, y, c)

    def vgrad(self, stops):
        """세로 그라데이션 — 디더링은 마지막 retro()가 얹는다."""
        for y in range(H):
            t = y / (H - 1)
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t0 <= t <= t1:
                    k = (t - t0) / max(1e-6, t1 - t0)
                    self.rect(0, y, W - 1, y, mix(c0, c1, k))
                    break

    def lighten(self, lx, ly, radius, power, warm=(90, 62, 20)):
        """한 점에서 퍼지는 온기 — 거리 감쇠로 밝힌다 (촛불·달무리)."""
        for y in range(max(0, ly - radius), min(H, ly + radius)):
            for x in range(max(0, lx - radius), min(W, lx + radius)):
                d = ((x - lx) ** 2 + (y - ly) ** 2) ** 0.5
                if d < radius:
                    k = (1.0 - d / radius) * power
                    r, g, b = self.px[x, y]
                    self.px[x, y] = (min(255, int(r + warm[0] * k)),
                                     min(255, int(g + warm[1] * k)),
                                     min(255, int(b + warm[2] * k)))


def mix(c0, c1, k):
    return tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))


# ------------------------------------------------------------- 레트로 마감
# 바랜 필름 톤(뜬 검정·주저앉은 파랑) -> 비네트 -> 오더드 디더링 + 색 계단.
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def retro(im):
    px = im.load()
    cx, cy = W / 2.0, H / 2.0
    maxd = (cx * cx + cy * cy) ** 0.5
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            # 바랜 필름: 검정이 뜨고 따뜻한 쪽으로 기운다
            r = r * 0.94 + 22
            g = g * 0.92 + 16
            b = b * 0.88 + 14
            # 비네트 — 모서리로 갈수록 어둡다
            d = (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / maxd
            v = 1.0 - 0.30 * d * d
            r, g, b = r * v, g * v, b * v
            # 오더드 디더링 + 굵은 색 계단 (14단)
            dth = (BAYER[y % 4][x % 4] - 7.5) * 1.7
            out = []
            for ch in (r, g, b):
                ch = max(0.0, min(255.0, ch + dth))
                out.append(int(ch // 14) * 14 + 7)
            px[x, y] = tuple(out)
    return im


# ---------------------------------------------------- 1. 별하늘의 할아버지
def scene_grandpa(g, f):
    rnd = random.Random(7)
    g.vgrad([(0.0, (8, 10, 30)), (0.55, (20, 26, 62)), (1.0, (42, 50, 100))])
    # 은하수 — 왼쪽 아래에서 오른쪽 위로 비스듬한 밝은 띠
    for y in range(H - 30):
        for x in range(W):
            d = abs((x * 0.35 + 40) - (H - 30 - y) * 1.7 - 30)
            if d < 16 and rnd.random() < 0.5 * (1 - d / 16):
                g.p(x, y, mix(g.px[x, y], (96, 100, 150), 0.5))
    # 별 — 저마다 위상이 달라 프레임마다 다른 별이 반짝인다
    stars = []
    for _ in range(150):
        x, y = rnd.randrange(W), rnd.randrange(H - 30)
        if rnd.random() < (1.0 - y / H) * 0.9:
            stars.append((x, y, rnd.randrange(4)))
    for x, y, ph in stars:
        tw = (ph + f) % 4
        c = [(240, 242, 250), (200, 206, 230), (130, 140, 185),
             (200, 206, 230)][tw]
        g.p(x, y, c)
    for _ in range(8):                     # 큰 별 — 반짝일 때만 십자
        x, y = rnd.randrange(10, W - 10), rnd.randrange(6, 50)
        ph = rnd.randrange(4)
        g.p(x, y, (255, 252, 230))
        if (ph + f) % 4 < 2:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                g.p(x + dx, y + dy, (150, 158, 205))
    # 별똥별 — 네 프레임에 걸쳐 하늘을 가로지른다
    hx, hy = 22 + f * 16, 10 + f * 5
    for i in range(12):
        k = i / 12.0
        g.p(hx + i * 2, hy + i, mix((250, 252, 255), (60, 70, 120), k))
    # 달 + 달무리
    mx, my, r = 206, 22, 11
    for y in range(my - r - 4, my + r + 5):
        for x in range(mx - r - 4, mx + r + 5):
            d2 = (x - mx) ** 2 + (y - my) ** 2
            if d2 <= r * r:
                g.p(x, y, (236, 232, 208))
            elif d2 <= (r + 3) ** 2:
                g.p(x, y, mix(g.px[x, y], (150, 150, 170), 0.4))
    for cx, cy, cr in ((202, 18, 3), (211, 27, 2), (204, 28, 2), (209, 16, 1)):
        g.disk(cx, cy, cr, (210, 204, 180))
    g.p(mx - 6, my + 6, (222, 216, 192))
    # 뒷산 능선 + 소나무 실루엣
    BACK = (24, 24, 50)
    for x in range(W):
        yb = int(82 - 7 * math.sin(x / 46.0 + 1.2))
        for y in range(yb, H):
            g.p(x, y, BACK)
    for px_, h_ in ((14, 7), (30, 5), (57, 8), (96, 6), (188, 7), (232, 6), (216, 5)):
        base = int(82 - 7 * math.sin(px_ / 46.0 + 1.2))
        for i in range(h_):
            w = (h_ - i) // 2
            g.rect(px_ - w, base - i, px_ + w, base - i, BACK)
    # 앞 언덕
    HILL = (14, 12, 28)
    for x in range(W):
        yf = int(92 - 9 * math.sin(x / 33.0))
        for y in range(yf, H):
            g.p(x, y, HILL)
    # 풀 — 홀수 포기는 바람에 흔들린다
    for i in range(56):
        x = rnd.randrange(W)
        y = int(92 - 9 * math.sin(x / 33.0))
        sway = (f % 2) if i % 2 else 0
        h_ = rnd.randrange(2, 4)
        for k in range(h_):
            g.p(x + (sway if k == h_ - 1 else 0), y - 1 - k, HILL)
    # 할아버지 실루엣 — 언덕 위에서 망원경으로 별을 본다
    bx, by = 148, 66
    S = HILL
    for y in range(by - 12, by + 1):
        w = 2 if y < by - 8 else 3
        g.rect(bx - w, y, bx + w, y, S)
    g.rect(bx - 2, by - 16, bx + 2, by - 13, S)     # 머리
    g.rect(bx - 4, by - 17, bx + 4, by - 16, S)     # 모자 챙
    g.rect(bx - 2, by - 19, bx + 2, by - 17, S)     # 모자 통
    # 목도리 — 바람에 두 갈래로 날린다 (프레임마다 출렁)
    fl = [(0, 0), (1, 0), (1, -1), (0, -1)][f]
    for i in range(6):
        g.p(bx + 4 + i, by - 12 + (i // 3) + fl[1] * (i // 4), (52, 34, 44))
        if i > 2:
            g.p(bx + 4 + i, by - 11 + fl[0], (52, 34, 44))
    for y in range(by - 16, by):                    # 달빛 림 라이트
        g.p(bx + (3 if y > by - 9 else 2), y, (96, 104, 150))
    # 망원경 — 끝으로 갈수록 굵은 경통 + 삼각대
    for i in range(17):
        x = bx - 5 - i
        y = by - 9 - i // 2
        g.rect(x, y - 1, x, y + (2 if i > 11 else 1), S)
    g.rect(bx - 24, by - 20, bx - 21, by - 15, S)
    for y in range(by - 19, by - 15):
        g.p(bx - 20 - (by - 15 - y), y, (96, 104, 150))
    for i in range(9):
        g.p(bx - 11 - i // 2, by - 8 + i, S)
        g.p(bx - 9 + i // 3, by - 8 + i, S)
        if i % 2:
            g.p(bx - 10, by - 8 + i, S)


# ---------------------------------------------------- 2. 나무 상자
def scene_box(g, f):
    rnd = random.Random(3)
    # 판자벽 배경
    g.vgrad([(0.0, (30, 20, 16)), (1.0, (44, 30, 22))])
    for x in range(0, W, 26):
        for y in range(0, 58):
            g.p(x, y, (24, 16, 12))
    for _ in range(60):                             # 판자 나뭇결
        x, y = rnd.randrange(W), rnd.randrange(56)
        g.rect(x, y, x + rnd.randrange(2, 6), y, (36, 24, 18))
    # 벽에 걸린 낡은 지도
    g.rect(16, 12, 60, 42, (120, 104, 76))
    g.rect(16, 12, 60, 13, (86, 72, 52))
    g.rect(16, 41, 60, 42, (86, 72, 52))
    for _ in range(16):                             # 지도 위 표시들
        x, y = rnd.randrange(20, 56), rnd.randrange(16, 38)
        g.p(x, y, (74, 60, 44))
    for i in range(10):                             # 항로 점선
        g.p(22 + i * 3, 34 - i, (140, 60, 48))
    g.p(52, 22, (158, 44, 40))                      # 목적지 표시
    g.p(53, 22, (158, 44, 40))
    g.p(38, 6, (60, 44, 32))                        # 못
    for y in range(7, 12):
        g.p(38, y, (50, 36, 26))
    # 벽 액자 — 할아버지의 작은 초상
    g.rect(196, 16, 226, 44, (96, 70, 42))
    g.rect(199, 19, 223, 41, (56, 48, 40))
    g.rect(206, 24, 216, 34, (196, 158, 128))       # 얼굴
    g.rect(206, 24, 216, 26, (230, 224, 210))       # 백발
    g.rect(208, 31, 214, 34, (230, 224, 210))       # 수염
    g.p(209, 28, (60, 44, 34))
    g.p(213, 28, (60, 44, 34))
    # 탁자
    for y in range(58, H):
        k = (y - 58) / (H - 58)
        g.rect(0, y, W - 1, y, mix((104, 72, 44), (62, 42, 26), k))
    for x in range(0, W, 42):
        for y in range(58, H):
            g.p(x + (y - 58) // 3, y, (58, 38, 24))
    for _ in range(40):                             # 탁자 나뭇결
        x, y = rnd.randrange(W), rnd.randrange(60, H - 2)
        g.rect(x, y, x + rnd.randrange(3, 8), y, (82, 56, 34))
    g.rect(0, 58, W - 1, 58, (128, 92, 56))
    # 밧줄 뭉치 (상자 오른쪽)
    for ring, rr in ((0, 7), (1, 5), (2, 3)):
        cx, cy = 190, 74
        for a in range(0, 360, 8):
            x = cx + int(rr * math.cos(math.radians(a)))
            y = cy + int(rr * 0.55 * math.sin(math.radians(a)))
            g.p(x, y, (128, 100, 58) if ring % 2 else (104, 80, 46))
    # 두루마리 지도통 (상자 왼쪽)
    g.rect(52, 78, 78, 84, (110, 82, 48))
    g.rect(52, 78, 78, 79, (134, 102, 60))
    g.rect(50, 77, 53, 85, (86, 62, 38))
    g.rect(77, 77, 80, 85, (86, 62, 38))
    # 나무 상자 — 뚜껑이 뒤로 젖혀져 열려 있다
    bx0, bx1 = 86, 166
    by0, by1 = 44, 84
    g.rect(bx0 + 4, by0 - 16, bx1 - 4, by0 - 2, (96, 66, 38))
    g.rect(bx0 + 4, by0 - 16, bx1 - 4, by0 - 14, (70, 48, 28))
    for x in range(bx0 + 8, bx1 - 4, 12):           # 뚜껑 널빤지
        for y in range(by0 - 14, by0 - 2):
            g.p(x, y, (82, 56, 32))
    g.rect(bx0, by0, bx1, by1, (134, 96, 54))
    for y in range(by0, by1, 9):
        g.rect(bx0, y, bx1, y, (108, 76, 42))
    for _ in range(26):                             # 상자 나뭇결
        x, y = rnd.randrange(bx0 + 2, bx1 - 2), rnd.randrange(by0 + 2, by1 - 2)
        g.rect(x, y, x + rnd.randrange(2, 5), y, (120, 86, 48))
    g.rect(bx0, by0, bx1, by0 + 1, (160, 118, 68))
    for x0 in (bx0, bx1 - 5):                       # 모서리 쇠장식 + 못
        g.rect(x0, by0, x0 + 5, by0 + 6, (118, 120, 126))
        g.rect(x0, by1 - 6, x0 + 5, by1, (96, 98, 104))
        g.p(x0 + 2, by0 + 2, (168, 170, 176))
        g.p(x0 + 2, by1 - 3, (140, 142, 148))
    g.rect(bx0 + 4, by0 - 1, bx1 - 4, by0 + 3, (34, 22, 16))
    # 연구 노트
    g.rect(104, 30, 148, 46, (70, 46, 30))
    g.rect(104, 30, 148, 32, (94, 62, 40))
    g.rect(111, 30, 114, 46, (150, 108, 46))
    g.p(112, 40, (108, 76, 34))
    g.p(113, 40, (108, 76, 34))
    g.rect(142, 33, 145, 36, (150, 130, 96))
    g.rect(122, 38, 136, 39, (120, 92, 60))
    # 편지 봉투 + 밀랍 인장
    g.rect(112, 48, 156, 66, (226, 214, 184))
    g.rect(112, 48, 156, 49, (244, 236, 212))
    for i in range(22):
        g.p(113 + i, 49 + i // 2, (188, 172, 138))
        g.p(155 - i, 49 + i // 2, (188, 172, 138))
    g.disk(134, 60, 2, (158, 44, 40))
    g.p(133, 59, (200, 78, 66) if f % 2 else (176, 58, 52))   # 인장 반짝
    # 촛불 — 프레임마다 불꽃 모양과 빛이 일렁인다
    g.rect(54, 30, 61, 52, (222, 210, 184))
    g.rect(54, 30, 61, 31, (240, 232, 208))
    for y in range(33, 50, 5):                      # 흘러내린 촛농
        g.p(54, y, (206, 192, 164))
        g.p(61, y + 2, (206, 192, 164))
    g.rect(50, 52, 65, 55, (140, 128, 110))
    g.rect(50, 52, 65, 52, (168, 156, 136))
    flame = [((57, 26), (57, 27), (58, 28)),
             ((57, 25), (57, 26), (57, 27)),
             ((58, 26), (57, 27), (57, 28)),
             ((57, 26), (58, 27), (57, 28))][f]
    g.p(*flame[0], (255, 244, 180))
    g.p(*flame[1], (255, 214, 110))
    g.p(*flame[2], (238, 148, 66))
    radius = [66, 72, 62, 70][f]
    g.lighten(57, 28, radius, 0.26)
    # 먼지 — 촛불 빛 속을 떠다닌다
    for i in range(7):
        mx = 66 + (i * 23) % 90
        my = 20 + (i * 17 + f * 3) % 42
        g.p(mx, my, (150, 128, 96))


# ---------------------------------------------------- 3. 할아버지의 편지
def scene_letter(g, f):
    rnd = random.Random(11)
    g.vgrad([(0.0, (46, 32, 24)), (1.0, (26, 18, 14))])
    for _ in range(50):                             # 탁자 나뭇결
        x, y = rnd.randrange(W), rnd.randrange(H)
        g.rect(x, y, x + rnd.randrange(3, 8), y, (52, 36, 26))
    # 잉크병 (왼쪽 위 구석)
    g.rect(8, 14, 24, 34, (44, 52, 72))
    g.rect(8, 14, 24, 16, (60, 70, 94))
    g.rect(12, 8, 20, 14, (30, 34, 46))
    g.rect(12, 8, 20, 9, (74, 80, 98))
    g.p(10, 18, (98, 108, 134))                     # 유리 반사
    g.p(10, 19, (98, 108, 134))
    # 양피지 — 화면을 채운다 (가장자리 물결 + 질감)
    PAPER = (233, 219, 186)
    EDGE = (196, 176, 136)
    for y in range(8, 100):
        wob = int(2 * (0.5 - abs(((y * 7) % 10) / 10 - 0.5)))
        x0, x1 = 30 + wob, 222 - wob
        g.rect(x0, y, x1, y, PAPER)
        g.p(x0, y, EDGE)
        g.p(x1, y, EDGE)
    g.rect(31, 8, 221, 8, EDGE)
    g.rect(31, 99, 221, 99, EDGE)
    g.rect(33, 100, 223, 100, (54, 38, 26))
    for _ in range(180):                            # 종이 질감
        x, y = rnd.randrange(32, 221), rnd.randrange(9, 99)
        g.p(x, y, (226, 210, 175))
    for x in range(33, 222):                        # 접힌 자국
        g.p(x, 38, (212, 196, 160))
        g.p(x, 68, (212, 196, 160))
    # 찻잔 자국 (오른쪽 위)
    for a in range(0, 360, 6):
        if 40 < a < 130:
            continue                                # 끊긴 원호
        x = 196 + int(9 * math.cos(math.radians(a)))
        y = 22 + int(9 * math.sin(math.radians(a)))
        g.p(x, y, (206, 184, 146))
    # 손글씨
    INK = (88, 62, 38)
    for row in range(8):
        y = 15 + row * 10
        if y > 92:
            break
        x = 44 if row != 0 else 58
        while x < 200:
            seg = rnd.randrange(4, 12)
            for i in range(seg):
                yy = y + (1 if (x + i) % 7 in (2, 3) else 0)
                g.p(x + i, yy, INK)
                if rnd.random() < 0.25:
                    g.p(x + i, yy - 1, INK)
            x += seg + rnd.randrange(3, 6)
    for _ in range(6):                              # 잉크 얼룩
        x, y = rnd.randrange(40, 210), rnd.randrange(12, 96)
        g.p(x, y, (150, 120, 84))
    # 서명 — 흘림 곡선
    sx, sy = 148, 88
    for i in range(40):
        t = i / 6.0
        g.p(sx + i, sy + int(3.2 * math.sin(t * 1.9)), INK)
        g.p(sx + i, sy + 1 + int(3.2 * math.sin(t * 1.9)), INK)
    # 눌린 꽃잎
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
        g.p(58 + dx, 82 + dy, (196, 130, 140))
    g.p(59, 83, (226, 168, 176))
    # 깃펜 — 오른쪽 아래에 비스듬히. 깃털 끝이 바람에 살랑인다
    qx, qy = 176, 96
    for i in range(26):                             # 깃대
        g.p(qx + i, qy - i // 3, (176, 168, 150))
        g.p(qx + i, qy - i // 3 + 1, (140, 132, 116))
    sway = [0, -1, 0, 1][f]
    for i in range(10, 26):                         # 깃털 날
        wdt = (26 - i) // 3 + 1
        for k in range(wdt):
            g.p(qx + i, qy - i // 3 - 1 - k + (sway if i > 20 else 0),
                (216, 210, 194) if k % 2 else (188, 180, 162))
    g.rect(qx - 3, qy + 1, qx, qy + 2, (60, 48, 36))    # 펜촉
    g.p(qx - 4, qy + 2, (30, 26, 22))                   # 촉 끝 잉크
    # 촛불 빛이 오른쪽 위에서 일렁인다
    g.lighten(210, 6, [88, 96, 82, 92][f], [0.16, 0.20, 0.13, 0.18][f])


# ---------------------------------------------------- 4. 잡초 무성한 농장
def scene_farm(g, f):
    rnd = random.Random(5)
    g.vgrad([(0.0, (120, 146, 188)), (0.42, (196, 184, 166)),
             (0.60, (234, 196, 138)), (1.0, (242, 212, 160))])
    # 구름 — 천천히 흐른다 (프레임마다 두 칸)
    for ci, (cx0, cy0, cw) in enumerate(((30, 14, 30), (150, 24, 38), (215, 9, 24))):
        cx0 = (cx0 + f * 2) % (W + 40) - 20
        for y in range(cy0 - 4, cy0 + 5):
            for x in range(cx0 - cw // 2, cx0 + cw // 2 + 1):
                d = ((x - cx0) / (cw * 0.55)) ** 2 + ((y - cy0) / 4.2) ** 2
                if d <= 1.0:
                    g.p(x, y, (244, 240, 228) if y < cy0 + 1 else (216, 206, 192))
    # 해 + 노을 반사
    sx, sy, r = 196, 52, 7
    for y in range(sy - r - 3, sy + r + 4):
        for x in range(sx - r - 3, sx + r + 4):
            d2 = (x - sx) ** 2 + (y - sy) ** 2
            if d2 <= r * r:
                g.p(x, y, (252, 228, 152))
            elif d2 <= (r + 3) ** 2:
                g.p(x, y, mix(g.px[x, y], (250, 220, 150), 0.55))
    # 먼 산 (푸른 실루엣) -> 먼 숲
    for x in range(W):
        ym = int(52 - 6 * math.sin(x / 60.0 + 1.0) - 3 * math.sin(x / 23.0))
        for y in range(ym, 60):
            g.p(x, y, (142, 148, 158))
    for x in range(W):
        yt = int(58 - 5 * math.sin(x / 17.0) - 3 * math.sin(x / 7.0 + 2))
        for y in range(yt, 64):
            g.p(x, y, (106, 118, 100))
    # 들판
    for y in range(62, H):
        k = (y - 62) / (H - 62)
        g.rect(0, y, W - 1, y, mix((116, 138, 78), (82, 110, 58), k))
    # 흙길
    for y in range(70, H):
        k = (y - 70) / (H - 70)
        cx = int(96 + (126 - 96) * (1 - k))
        hw = int(3 + 14 * k)
        g.rect(cx - hw, y, cx + hw, y, (190, 158, 110) if y % 3 else (174, 142, 98))
        if y % 4 == 0:                              # 자갈
            g.p(cx - hw // 2, y, (150, 122, 86))
        if y % 5 == 0:
            g.p(cx + hw // 2, y, (204, 174, 124))
    # 오두막
    hx0, hy0 = 78, 34
    g.rect(hx0, hy0 + 12, hx0 + 44, hy0 + 36, (150, 108, 62))
    for y in range(hy0 + 14, hy0 + 36, 5):
        g.rect(hx0, y, hx0 + 44, y, (128, 90, 52))
    for _ in range(14):                             # 벽 얼룩
        x = rnd.randrange(hx0 + 1, hx0 + 43)
        y = rnd.randrange(hy0 + 13, hy0 + 35)
        g.p(x, y, (136, 96, 54))
    for i in range(13):                             # 지붕
        g.rect(hx0 - 6 + i, hy0 + i, hx0 + 50 - i, hy0 + i, (118, 66, 52))
    g.rect(hx0 - 6, hy0 + 12, hx0 + 50, hy0 + 13, (86, 48, 38))
    for x, y in ((hx0 + 26, hy0 + 3), (hx0 + 30, hy0 + 4), (hx0 + 27, hy0 + 6),
                 (hx0 + 32, hy0 + 6), (hx0 + 29, hy0 + 8)):
        g.p(x, y, (60, 36, 30))
        g.p(x + 1, y, (60, 36, 30))
    for x, y in ((hx0 + 2, hy0 + 9), (hx0 + 6, hy0 + 10), (hx0 + 12, hy0 + 7)):
        g.p(x, y, (96, 116, 62))                    # 지붕 이끼
        g.p(x + 1, y, (108, 128, 70))
    g.rect(hx0 + 18, hy0 + 24, hx0 + 27, hy0 + 36, (96, 62, 36))
    g.rect(hx0 + 18, hy0 + 24, hx0 + 27, hy0 + 25, (76, 48, 30))
    g.p(hx0 + 25, hy0 + 30, (150, 130, 96))
    g.rect(hx0 + 33, hy0 + 20, hx0 + 40, hy0 + 27, (58, 62, 74))
    for i in range(8):                              # 오른창은 판자로 막았다
        g.p(hx0 + 33 + i, hy0 + 21 + i, (118, 88, 52))
        g.p(hx0 + 33 + i, hy0 + 26 - i, (118, 88, 52))
    g.rect(hx0 + 5, hy0 + 20, hx0 + 12, hy0 + 27, (58, 62, 74))
    g.rect(hx0 + 8, hy0 + 20, hx0 + 8, hy0 + 27, (96, 66, 40))
    g.p(hx0 + 6, hy0 + 21, (108, 114, 128))         # 유리 반사
    g.rect(hx0 + 38, hy0 - 8, hx0 + 43, hy0 + 2, (110, 84, 66))
    g.rect(hx0 + 38, hy0 - 8, hx0 + 43, hy0 - 7, (128, 100, 80))
    # 큰 나무 — 잎이 반짝이고 낙엽이 진다
    tx, ty = 36, 62
    g.rect(tx - 2, ty - 18, tx + 2, ty, (98, 66, 40))
    g.p(tx - 3, ty - 6, (78, 52, 32))
    g.p(tx + 3, ty - 10, (78, 52, 32))
    for cx, cy, cr in ((tx, ty - 26, 13), (tx - 10, ty - 18, 9),
                       (tx + 11, ty - 19, 10), (tx + 2, ty - 33, 9)):
        g.disk(cx, cy, cr, (74, 104, 58))
    for i in range(70):                             # 잎 반짝임 — 프레임마다 다른 잎
        a = rnd.random() * 6.283
        rr = rnd.random()
        x = int(tx + math.cos(a) * 13 * rr)
        y = int(ty - 26 + math.sin(a) * 11 * rr)
        if (i + f) % 3 != 0:
            g.p(x, y, (104, 138, 74))
        else:
            g.p(x, y, (120, 152, 84))
    leaf_x = tx + 16 + f * 3                        # 낙엽 한 장
    leaf_y = ty - 20 + f * 6 + (1 if f % 2 else 0)
    g.p(leaf_x, leaf_y, (150, 122, 60))
    g.p(leaf_x + 1, leaf_y, (128, 102, 50))
    # 부서진 울타리 + 까마귀 (프레임마다 자리를 옮겨 앉는다)
    posts = []
    for i, x in enumerate(range(140, 246, 12)):
        if i == 3:
            continue
        tilt = (-1 if i % 3 == 0 else 1) if i % 2 else 0
        for y in range(72, 82):
            g.p(x + tilt * (y - 72) // 5, y, (122, 88, 52))
        g.p(x, 72, (150, 112, 66))
        posts.append(x)
    g.rect(138, 75, 246, 76, (122, 88, 52))
    g.rect(138, 79, 246, 79, (108, 76, 46))
    crow_x = posts[[1, 1, 5, 5][f]]
    wing = f % 2
    g.p(crow_x, 70, (34, 32, 40))                   # 몸통
    g.p(crow_x + 1, 70, (34, 32, 40))
    g.p(crow_x + 1, 69, (34, 32, 40))
    g.p(crow_x + 2, 69, (48, 46, 56))               # 머리
    g.p(crow_x + 3, 70, (208, 160, 60))             # 부리
    if wing:
        g.p(crow_x, 68, (34, 32, 40))               # 퍼덕이는 날개
        g.p(crow_x - 1, 67, (34, 32, 40))
    # 팻말 (길 옆)
    g.rect(146, 84, 148, 96, (110, 82, 48))
    g.rect(138, 82, 156, 88, (134, 102, 60))
    g.rect(138, 82, 156, 83, (154, 120, 72))
    g.rect(141, 85, 153, 85, (98, 74, 44))
    # 잡초 — 절반은 바람에 흔들린다 · 사이사이 들꽃
    for i in range(170):
        x, y = rnd.randrange(0, W), rnd.randrange(66, H - 2)
        if abs(x - (96 + int((126 - 96) * (1 - (y - 70) / 38.0)))) < 8 and y > 70:
            continue
        c = rnd.choice([(60, 92, 46), (72, 108, 50), (52, 80, 42)])
        h_ = rnd.randrange(2, 5)
        sway = (f % 2) if i % 2 else ((f + 1) % 2 if i % 5 == 0 else 0)
        for k in range(h_):
            g.p(x + (sway if k >= h_ - 1 else 0), y - k, c)
        if h_ > 2:
            g.p(x - 1, y - h_ + 1, c)
            g.p(x + 1, y - h_ + 1, c)
        if i % 23 == 0:                             # 들꽃
            g.p(x, y - h_, rnd.choice([(224, 200, 90), (216, 150, 170),
                                       (226, 226, 220)]))
    # 새 두 마리 — 날개짓하며 흘러간다
    for bi, (bx, by) in enumerate(((60, 20), (74, 16))):
        bx += f * 2
        by += (f % 2) - 1 + bi
        wing_up = (f + bi) % 2
        g.p(bx, by, (60, 60, 70))
        if wing_up:
            g.p(bx - 1, by - 1, (60, 60, 70))
            g.p(bx + 1, by - 1, (60, 60, 70))
        else:
            g.p(bx - 1, by, (60, 60, 70))
            g.p(bx + 1, by, (60, 60, 70))


# ------------------------------------------------------------------- 출력
SCENES = [('grandpa', scene_grandpa), ('box', scene_box),
          ('letter', scene_letter), ('farm', scene_farm)]

for name, fn in SCENES:
    frames = []
    for f in range(FRAMES):
        g = Canvas()
        fn(g, f)
        retro(g.im)
        big = g.im.resize((W * SCALE, H * SCALE), Image.NEAREST)
        fname = 'prologue_%s_%d.png' % (name, f)
        big.save(os.path.join(REF, fname))
        big.save(os.path.join(OUT, fname))
        frames.append(big.convert('P', palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(REF, 'anim_prologue_%s.gif' % name),
                   save_all=True, append_images=frames[1:], duration=260, loop=0)
    print('saved', name, 'x%d' % FRAMES)
print('done')
