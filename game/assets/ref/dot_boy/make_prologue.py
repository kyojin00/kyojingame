# 프롤로그 일러스트 4장 — 오프닝 편지지 위에 얹는 도트 장면.
#
#   1 prologue_grandpa.png  별하늘 아래 망원경을 보는 할아버지 실루엣
#   2 prologue_box.png      물려받은 나무 상자 — 연구 노트와 편지
#   3 prologue_letter.png   할아버지의 편지 (필체 클로즈업)
#   4 prologue_farm.png     잡초 무성한 물려받은 농장
#
# 논리 252x108 을 2배로 키워 504x216 — 스토리 패널(540폭) 안에 꼭 맞는다.
# 실행: python3 make_prologue.py  (이 폴더에서)

import os
import random
from PIL import Image

W, H = 252, 108
SCALE = 2
REF = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))


class Canvas:
    def __init__(self):
        self.im = Image.new('RGB', (W, H))
        self.px = self.im.load()

    def p(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                self.px[x, y] = c

    def vgrad(self, stops):
        """세로 그라데이션 — stops: [(y비율, 색)]. 도트답게 계단식."""
        for y in range(H):
            t = y / (H - 1)
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t0 <= t <= t1:
                    k = (t - t0) / max(1e-6, t1 - t0)
                    k = round(k * 6) / 6          # 6단 밴딩
                    c = tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))
                    self.rect(0, y, W - 1, y, c)
                    break

    def save(self, name):
        big = self.im.resize((W * SCALE, H * SCALE), Image.NEAREST)
        big.save(os.path.join(REF, name))
        big.save(os.path.join(OUT, name))
        print('saved', name)


def mix(c0, c1, k):
    return tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))


# ---------------------------------------------------- 1. 별하늘의 할아버지
def scene_grandpa():
    rnd = random.Random(7)
    g = Canvas()
    g.vgrad([(0.0, (10, 12, 34)), (0.55, (22, 28, 66)), (1.0, (44, 52, 104))])
    # 별 — 아래(지평선 근처)로 갈수록 드물게
    for _ in range(130):
        x, y = rnd.randrange(W), rnd.randrange(H - 30)
        if rnd.random() < (1.0 - y / H) * 0.9:
            c = rnd.choice([(220, 224, 240), (255, 250, 220), (150, 160, 200)])
            g.p(x, y, c)
    for _ in range(7):                     # 큰 별은 십자 반짝이
        x, y = rnd.randrange(10, W - 10), rnd.randrange(6, 52)
        g.p(x, y, (255, 252, 230))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            g.p(x + dx, y + dy, (150, 158, 205))
    # 달 (오른쪽 위) + 은은한 달무리
    mx, my, r = 206, 22, 11
    for y in range(my - r - 3, my + r + 4):
        for x in range(mx - r - 3, mx + r + 4):
            d2 = (x - mx) ** 2 + (y - my) ** 2
            if d2 <= r * r:
                g.p(x, y, (234, 230, 206))
            elif d2 <= (r + 2) ** 2:
                g.p(x, y, mix((22, 28, 66), (120, 122, 140), 0.35))
    for cx, cy, cr in ((202, 18, 3), (211, 27, 2), (204, 28, 2)):   # 크레이터
        for y in range(cy - cr, cy + cr + 1):
            for x in range(cx - cr, cx + cr + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= cr * cr:
                    g.p(x, y, (206, 200, 176))
    # 별똥별
    for i in range(16):
        g.p(30 + i * 2, 14 + i, (240, 244, 255) if i < 4 else (120, 130, 180))
    # 언덕 실루엣 (겹 2개)
    import math
    HILL = (16, 14, 30)
    BACK = (26, 26, 52)
    for x in range(W):
        yb = int(84 - 7 * math.sin(x / 46.0 + 1.2))
        for y in range(yb, H):
            g.p(x, y, BACK)
    for x in range(W):
        yf = int(92 - 9 * math.sin(x / 33.0))
        for y in range(yf, H):
            g.p(x, y, HILL)
    # 풀 몇 가닥
    for _ in range(40):
        x = rnd.randrange(W)
        y = int(92 - 9 * math.sin(x / 33.0))
        g.p(x, y - 1, HILL)
    # 할아버지 실루엣 — 언덕 위, 망원경을 올려다본다 (왼쪽을 본다)
    bx, by = 148, 66              # 발 기준
    S = HILL
    # 몸통(코트 자락) 5x12
    for y in range(by - 12, by + 1):
        w = 2 if y < by - 8 else 3
        for x in range(bx - w, bx + w + 1):
            g.p(x, y, S)
    for y in range(by - 16, by - 12):      # 머리 + 모자
        for x in range(bx - 2, bx + 3):
            g.p(x, y, S)
    g.rect(bx - 4, by - 17, bx + 4, by - 16, S)    # 모자 챙
    g.rect(bx - 2, by - 19, bx + 2, by - 17, S)    # 모자 통
    # 달빛 받는 오른쪽 윤곽 한 줄 (림 라이트)
    for y in range(by - 16, by):
        g.p(bx + (3 if y > by - 9 else 2), y, (96, 104, 150))
    # 망원경 — 왼쪽 위(별)를 향해 비스듬히. 경통은 끝으로 갈수록 굵다
    for i in range(17):
        x = bx - 5 - i
        y = by - 9 - i // 2
        g.rect(x, y - 1, x, y + (2 if i > 11 else 1), S)
    g.rect(bx - 24, by - 20, bx - 21, by - 15, S)   # 경통 끝 (대물렌즈)
    for y in range(by - 19, by - 15):               # 경통 위 달빛 한 줄
        g.p(bx - 20 - (by - 15 - y), y, (96, 104, 150))
    for i in range(9):                              # 삼각대 다리
        g.p(bx - 11 - i // 2, by - 8 + i, S)
        g.p(bx - 9 + i // 3, by - 8 + i, S)
        if i % 2:
            g.p(bx - 10, by - 8 + i, S)
    g.save('prologue_grandpa.png')


# ---------------------------------------------------- 2. 나무 상자
def scene_box():
    rnd = random.Random(3)
    g = Canvas()
    # 어두운 방 + 탁자
    g.vgrad([(0.0, (24, 16, 14)), (0.5, (38, 26, 20)), (1.0, (30, 20, 16))])
    TABLE = (86, 58, 36)
    for y in range(58, H):
        k = (y - 58) / (H - 58)
        c = mix((104, 72, 44), (66, 44, 28), k)
        g.rect(0, y, W - 1, y, c)
    for x in range(0, W, 42):                      # 널빤지 이음새
        for y in range(58, H):
            g.p(x + (y - 58) // 3, y, (60, 40, 26))
    g.rect(0, 58, W - 1, 58, (128, 92, 56))        # 탁자 모서리 빛
    # 상자 (가운데) — 열린 뚜껑이 뒤로 젖혀져 있다
    bx0, bx1 = 86, 166
    by0, by1 = 44, 84
    LID = (96, 66, 38)
    g.rect(bx0 + 4, by0 - 16, bx1 - 4, by0 - 2, LID)          # 뚜껑 안쪽
    g.rect(bx0 + 4, by0 - 16, bx1 - 4, by0 - 14, (70, 48, 28))
    FRONT = (134, 96, 54)
    g.rect(bx0, by0, bx1, by1, FRONT)
    for i, y in enumerate(range(by0, by1, 9)):                 # 널빤지
        g.rect(bx0, y, bx1, y, (108, 76, 42))
    g.rect(bx0, by0, bx1, by0 + 1, (160, 118, 68))             # 윗모서리 빛
    for x0 in (bx0, bx1 - 5):                                  # 모서리 쇠장식
        g.rect(x0, by0, x0 + 5, by0 + 6, (120, 122, 128))
        g.rect(x0, by1 - 6, x0 + 5, by1, (98, 100, 106))
        g.p(x0 + 2, by0 + 2, (170, 172, 178))
    # 상자 속 그늘
    g.rect(bx0 + 4, by0 - 1, bx1 - 4, by0 + 3, (34, 22, 16))
    # 연구 노트 — 상자에 비스듬히 기대 있다 (끈은 왼쪽에 치우쳐 십자로
    # 안 보이게, 띠 대신 모서리 장식)
    g.rect(104, 30, 148, 46, (70, 46, 30))
    g.rect(104, 30, 148, 32, (94, 62, 40))
    g.rect(111, 30, 114, 46, (150, 108, 46))       # 가죽끈 (왼쪽 1/3)
    g.p(112, 40, (108, 76, 34))                    # 끈 매듭
    g.p(113, 40, (108, 76, 34))
    g.rect(142, 33, 145, 36, (150, 130, 96))       # 모서리 장식
    g.rect(122, 38, 136, 39, (120, 92, 60))        # 표지에 눌린 제목 자국
    # 편지 봉투 — 노트 앞에 얹혀 있다
    g.rect(112, 48, 156, 66, (226, 214, 184))
    g.rect(112, 48, 156, 49, (244, 236, 212))
    for i in range(22):                            # 봉투 접힌 V
        g.p(113 + i, 49 + i // 2, (188, 172, 138))
        g.p(155 - i, 49 + i // 2, (188, 172, 138))
    for y in range(58, 63):                        # 밀랍 인장
        for x in range(131, 138):
            if (x - 134) ** 2 + (y - 60) ** 2 <= 6:
                g.p(x, y, (158, 44, 40))
    g.p(133, 59, (196, 74, 64))
    # 촛불 빛 — 왼쪽 위에서 은은히 (거리 감쇠로 밝힌다)
    lx, ly = 58, 26
    for y in range(H):
        for x in range(W):
            d = ((x - lx) ** 2 + (y - ly) ** 2) ** 0.5
            if d < 70:
                k = (1.0 - d / 70) * 0.22
                r, gr, b = g.px[x, y]
                g.px[x, y] = (min(255, int(r + 90 * k)),
                              min(255, int(gr + 62 * k)),
                              min(255, int(b + 20 * k)))
    # 촛불 자체
    g.rect(54, 30, 61, 52, (222, 210, 184))
    g.rect(54, 30, 61, 31, (240, 232, 208))
    g.p(57, 27, (255, 210, 110))
    g.p(57, 26, (255, 240, 170))
    g.p(58, 28, (240, 150, 70))
    g.rect(50, 52, 65, 55, (140, 128, 110))        # 받침
    g.save('prologue_box.png')


# ---------------------------------------------------- 3. 할아버지의 편지
def scene_letter():
    rnd = random.Random(11)
    g = Canvas()
    g.vgrad([(0.0, (40, 30, 22)), (1.0, (26, 18, 14))])
    # 양피지 — 화면을 비스듬히 채운다
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
    g.rect(33, 100, 223, 100, (60, 42, 28))        # 그림자
    for x in range(33, 223):                       # 접힌 자국 두 줄
        g.p(x, 38, (214, 198, 162))
        g.p(x, 68, (214, 198, 162))
    # 손글씨 — 짧은 획을 불규칙하게 이어 문장처럼 보이게
    INK = (88, 62, 38)
    y = 16
    para_gap = [22, 30, 44, 52, 60, 74, 82]
    for row in range(8):
        y = 15 + row * 10
        if y > 92:
            break
        x = 44 if row != 0 else 58                 # 첫 줄 들여쓰기
        while x < 200:
            seg = rnd.randrange(4, 12)             # 단어 길이
            for i in range(seg):
                yy = y + (1 if (x + i) % 7 in (2, 3) else 0)
                g.p(x + i, yy, INK)
                if rnd.random() < 0.25:            # 획 삐침
                    g.p(x + i, yy - 1, INK)
            x += seg + rnd.randrange(3, 6)         # 낱말 사이
    # 마지막 서명 — 크고 흘려 쓴 곡선
    sx, sy = 152, 88
    import math
    for i in range(40):
        t = i / 6.0
        x = sx + i
        yy = sy + int(3.2 * math.sin(t * 1.9))
        g.p(x, yy, INK)
        g.p(x, yy + 1, INK)
    # 잉크 얼룩과 눌린 꽃잎 하나
    for _ in range(14):
        x, y = rnd.randrange(40, 214), rnd.randrange(12, 96)
        g.p(x, y, (206, 190, 152))
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
        g.p(58 + dx, 84 + dy, (196, 130, 140))     # 꽃잎
    g.p(59, 85, (226, 168, 176))
    g.save('prologue_letter.png')


# ---------------------------------------------------- 4. 잡초 무성한 농장
def scene_farm():
    rnd = random.Random(5)
    g = Canvas()
    # 아침 안개 낀 하늘
    g.vgrad([(0.0, (126, 150, 190)), (0.45, (196, 186, 170)),
             (0.62, (232, 196, 140)), (1.0, (240, 210, 160))])
    # 해 — 낮게 떠 있다
    sx, sy, r = 196, 52, 7
    for y in range(sy - r - 2, sy + r + 3):
        for x in range(sx - r - 2, sx + r + 3):
            d2 = (x - sx) ** 2 + (y - sy) ** 2
            if d2 <= r * r:
                g.p(x, y, (252, 226, 150))
            elif d2 <= (r + 2) ** 2:
                g.p(x, y, mix((232, 196, 140), (250, 220, 150), 0.5))
    # 먼 숲 실루엣
    import math
    for x in range(W):
        yt = int(58 - 5 * math.sin(x / 17.0) - 3 * math.sin(x / 7.0 + 2))
        for y in range(yt, 64):
            g.p(x, y, (110, 122, 104))
    # 들판
    for y in range(62, H):
        k = (y - 62) / (H - 62)
        g.rect(0, y, W - 1, y, mix((116, 138, 78), (84, 112, 60), k))
    # 흙길 — 아래 가운데에서 집 문 앞으로
    for y in range(70, H):
        k = (y - 70) / (H - 70)
        cx = int(96 + (126 - 96) * (1 - k))
        hw = int(3 + 14 * k)
        g.rect(cx - hw, y, cx + hw, y, (188, 156, 108) if y % 3 else (172, 140, 96))
    # 집 — 지붕에 구멍 난 낡은 오두막
    hx0, hy0 = 78, 34             # 왼윗점
    g.rect(hx0, hy0 + 12, hx0 + 44, hy0 + 36, (150, 108, 62))    # 벽
    for y in range(hy0 + 14, hy0 + 36, 5):
        g.rect(hx0, y, hx0 + 44, y, (128, 90, 52))
    # 지붕 — 간단한 사다리꼴
    for i in range(13):
        g.rect(hx0 - 6 + i, hy0 + i, hx0 + 50 - i, hy0 + i, (118, 66, 52))
    g.rect(hx0 - 6, hy0 + 12, hx0 + 50, hy0 + 13, (86, 48, 38))
    for x, y in ((hx0 + 26, hy0 + 3), (hx0 + 30, hy0 + 4), (hx0 + 27, hy0 + 6),
                 (hx0 + 32, hy0 + 6), (hx0 + 29, hy0 + 8)):
        g.p(x, y, (60, 36, 30))                                  # 지붕 구멍
        g.p(x + 1, y, (60, 36, 30))
    g.rect(hx0 + 18, hy0 + 24, hx0 + 27, hy0 + 36, (96, 62, 36)) # 문
    g.rect(hx0 + 18, hy0 + 24, hx0 + 27, hy0 + 25, (76, 48, 30))
    g.p(hx0 + 25, hy0 + 30, (150, 130, 96))
    g.rect(hx0 + 33, hy0 + 20, hx0 + 40, hy0 + 27, (58, 62, 74)) # 창
    g.rect(hx0 + 36, hy0 + 20, hx0 + 36, hy0 + 27, (96, 66, 40))
    g.rect(hx0 + 5, hy0 + 20, hx0 + 12, hy0 + 27, (58, 62, 74))
    g.rect(hx0 + 8, hy0 + 20, hx0 + 8, hy0 + 27, (96, 66, 40))
    g.rect(hx0 + 38, hy0 - 8, hx0 + 43, hy0 + 2, (110, 84, 66))  # 굴뚝
    # 큰 나무 (집 왼쪽)
    tx, ty = 36, 62
    g.rect(tx - 2, ty - 18, tx + 2, ty, (98, 66, 40))
    for cx, cy, cr in ((tx, ty - 26, 13), (tx - 10, ty - 18, 9),
                       (tx + 11, ty - 19, 10), (tx + 2, ty - 33, 9)):
        for y in range(cy - cr, cy + cr + 1):
            for x in range(cx - cr, cx + cr + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= cr * cr:
                    g.p(x, y, (74, 104, 58))
    for _ in range(60):                                          # 잎 하이라이트
        a = rnd.random() * 6.283
        rr = rnd.random()
        x = int(tx + math.cos(a) * 13 * rr)
        y = int(ty - 26 + math.sin(a) * 11 * rr)
        g.p(x, y, (104, 138, 74))
    # 부서진 울타리
    for i, x in enumerate(range(140, 246, 12)):
        if i == 3:
            continue                                             # 빠진 칸
        tilt = (-1 if i % 3 == 0 else 1) if i % 2 else 0
        for y in range(72, 82):
            g.p(x + tilt * (y - 72) // 5, y, (122, 88, 52))
        g.p(x, 72, (150, 112, 66))
    g.rect(138, 75, 246, 76, (122, 88, 52))
    g.rect(138, 79, 246, 79, (108, 76, 46))
    # 잡초 — 들판 곳곳에 V자 풀 포기
    for _ in range(150):
        x, y = rnd.randrange(0, W), rnd.randrange(66, H - 2)
        if abs(x - (96 + int((126 - 96) * (1 - (y - 70) / 38.0)))) < 8 and y > 70:
            continue                                             # 길은 비워 둔다
        c = rnd.choice([(60, 92, 46), (72, 108, 50), (52, 80, 42)])
        h = rnd.randrange(2, 5)
        for k in range(h):
            g.p(x, y - k, c)
        if h > 2:
            g.p(x - 1, y - h + 1, c)
            g.p(x + 1, y - h + 1, c)
    # 새 두 마리
    for bx, by in ((60, 20), (72, 16)):
        g.p(bx, by, (60, 60, 70))
        g.p(bx - 1, by - 1, (60, 60, 70))
        g.p(bx + 1, by - 1, (60, 60, 70))
    g.save('prologue_farm.png')


scene_grandpa()
scene_box()
scene_letter()
scene_farm()
print('done')
