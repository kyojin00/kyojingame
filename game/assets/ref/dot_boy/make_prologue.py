# 프롤로그 일러스트 — 오프닝 편지지 위에 얹는 움직이는 도트 장면.
#
#   1 prologue_grandpa_0..3.png  별하늘 아래 망원경을 보는 할아버지
#   2 prologue_box_0..3.png      물려받은 나무 상자 (촛불 방)
#   3 prologue_letter_0..3.png   할아버지의 편지
#   4 prologue_farm_0..3.png     해질녘의 물려받은 농장
#
# 그림체: 스타듀밸리 컷신풍 —
#   굵은 도트(168x72 논리를 3배로 키워 504x216) · 쨍한 채도의 평면 색면 ·
#   경계가 딱 떨어지는 동심 타원 빛 웅덩이 · 무늬 벽지 · 검은 실루엣 소품.
#   디더링·그라데이션은 쓰지 않는다 — 색면은 평평하게, 빛은 띠로 진다.
# 실행: python3 make_prologue.py  (이 폴더에서)

import math
import os
import random
from PIL import Image

W, H = 168, 72
SCALE = 3
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

    def rrect(self, x0, y0, x1, y1, c, r=2):
        """모서리를 깎은 사각형 — 소품이 덜 각져 보인다."""
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                dx = min(x - x0, x1 - x)
                dy = min(y - y0, y1 - y)
                if dx + dy >= r - 1:
                    self.px[x, y] = c

    def disk(self, cx, cy, r, c):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.p(x, y, c)

    def bands(self, rows):
        """가로 색 띠 — [(끝 y, 색)]. 그라데이션 대신 평평한 띠로 하늘을 짠다."""
        y = 0
        for y1, c in rows:
            self.rect(0, y, W - 1, y1, c)
            y = y1 + 1

    def pool(self, cx, cy, rx, ry, warm, steps=((0.42, 0.55), (0.72, 0.32), (1.0, 0.15))):
        """빛 웅덩이 — 경계가 딱 떨어지는 동심 타원 띠 (스타듀 컷신의
        벽난로 빛처럼). steps: (반지름 비율, 섞는 양) 안쪽부터."""
        for y in range(max(0, cy - ry), min(H, cy + ry + 1)):
            for x in range(max(0, cx - rx), min(W, cx + rx + 1)):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                for thr, k in steps:
                    if d <= thr:
                        self.px[x, y] = mix(self.px[x, y], warm, k)
                        break


def mix(c0, c1, k):
    return tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))


OUTLINE = (26, 18, 22)          # 소품 윤곽선 (완전한 검정보다 살짝 따뜻하게)


# ---------------------------------------------------- 1. 별하늘의 할아버지
def scene_grandpa(g, f):
    rnd = random.Random(7)
    g.bands([(16, (16, 16, 46)), (32, (26, 26, 72)),
             (46, (40, 38, 100)), (H - 1, (58, 52, 124))])
    # 별 — 위상 따라 반짝인다. 굵은 도트라 한 알이 또렷하다
    for _ in range(90):
        x, y = rnd.randrange(W), rnd.randrange(50)
        ph = rnd.randrange(4)
        tw = (ph + f) % 4
        if tw == 0:
            g.p(x, y, (255, 252, 235))
        elif tw < 3:
            g.p(x, y, (190, 196, 230))
    for _ in range(6):                     # 큰 별 — 반짝일 때 십자
        x, y = rnd.randrange(8, W - 8), rnd.randrange(4, 36)
        ph = rnd.randrange(4)
        g.p(x, y, (255, 252, 235))
        if (ph + f) % 4 < 2:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                g.p(x + dx, y + dy, (170, 178, 215))
    # 별똥별 — 네 프레임에 걸쳐 가로지른다
    hx, hy = 14 + f * 11, 7 + f * 3
    for i in range(8):
        g.p(hx + i * 2, hy + i, (250, 252, 255) if i < 3 else (110, 118, 170))
    # 달 — 또렷한 윤곽 + 평평한 달무리 띠
    mx, my, r = 137, 15, 8
    g.disk(mx, my, r + 3, mix((26, 26, 72), (120, 120, 150), 0.45))
    g.disk(mx, my, r + 1, (190, 186, 168))
    g.disk(mx, my, r, (248, 242, 216))
    g.disk(mx - 2, my - 2, 2, (226, 218, 190))      # 크레이터
    g.p(mx + 3, my + 3, (226, 218, 190))
    g.p(mx - 4, my + 4, (226, 218, 190))
    # 뒷능선 (짙은 남보라) + 소나무
    BACK = (30, 26, 62)
    for x in range(W):
        yb = int(54 - 4 * math.sin(x / 30.0 + 1.2))
        for y in range(yb, H):
            g.p(x, y, BACK)
    for px_, h_ in ((10, 5), (20, 4), (38, 6), (64, 4), (126, 5), (156, 4)):
        base = int(54 - 4 * math.sin(px_ / 30.0 + 1.2))
        for i in range(h_):
            w = (h_ - i) // 2
            g.rect(px_ - w, base - i, px_ + w, base - i, BACK)
    # 능선 위 오두막 — 창에만 불이 켜져 있고, 창 둘레로 빛이 진다
    g.rect(16, 46, 28, 51, BACK)
    for i in range(4):
        g.rect(16 + i, 45 - i, 28 - i, 45 - i, BACK)
    g.rect(25, 40, 26, 43, BACK)                    # 굴뚝
    g.pool(21, 48, 7, 5, (222, 174, 92), ((0.5, 0.4), (1.0, 0.2)))
    g.rect(20, 47, 22, 49, (244, 206, 120))         # 불 켜진 창
    # 앞 언덕 (더 짙게)
    HILL = (18, 14, 40)
    for x in range(W):
        yf = int(62 - 5 * math.sin(x / 22.0))
        for y in range(yf, H):
            g.p(x, y, HILL)
    # 풀 — 홀수 포기는 흔들린다
    for i in range(36):
        x = rnd.randrange(W)
        y = int(62 - 5 * math.sin(x / 22.0))
        sway = (f % 2) if i % 2 else 0
        g.p(x + sway, y - 1, HILL)
        g.p(x, y - 2 if i % 3 else y - 1, HILL)
    # 반딧불이
    for i, (fx, dy) in enumerate(((30, 3), (52, 4), (80, 3), (112, 5), (150, 4))):
        fy = int(62 - 5 * math.sin(fx / 22.0)) - dy
        ph = (i * 2 + f) % 4
        if ph == 0:
            g.p(fx, fy, (232, 206, 104))
        elif ph == 1:
            g.p(fx, fy, (150, 132, 66))
    # 할아버지 실루엣 — 뒷능선 위에서 망원경으로 별을 본다
    bx, by = 100, 58
    S = (12, 10, 26)
    for y in range(by - 8, by + 1):                 # 코트
        w = 1 if y < by - 5 else 2
        g.rect(bx - w, y, bx + w, y, S)
    g.rect(bx - 1, by - 11, bx + 1, by - 9, S)      # 머리
    g.rect(bx - 3, by - 12, bx + 3, by - 12, S)     # 모자 챙
    g.rect(bx - 1, by - 14, bx + 1, by - 12, S)     # 모자 통
    fl = [(0, 0), (1, 0), (1, -1), (0, -1)][f]
    for i in range(4):                              # 목도리 날림
        g.p(bx + 3 + i, by - 8 + fl[1] * (i // 2), (58, 34, 52))
    for y in range(by - 11, by):                    # 달빛 림 라이트
        g.p(bx + (2 if y > by - 6 else 1) + 1, y, (108, 112, 160))
    for i in range(11):                             # 망원경 경통
        x = bx - 3 - i
        y = by - 6 - i // 2
        g.rect(x, y - 1, x, y + (1 if i > 7 else 0), S)
    g.rect(bx - 16, by - 13, bx - 14, by - 10, S)   # 대물렌즈
    g.p(bx - 14, by - 12, (108, 112, 160))          # 렌즈에 비친 달빛
    for i in range(6):                              # 삼각대
        g.p(bx - 7 - i // 2, by - 5 + i, S)
        g.p(bx - 5 + i // 3, by - 5 + i, S)


# ---------------------------------------------------- 2. 나무 상자 (촛불 방)
def scene_box(g, f):
    rnd = random.Random(3)
    # 무늬 벽지 — 짙은 보라 바탕에 덩굴 무늬와 작은 꽃 (스타듀 벽지풍)
    g.rect(0, 0, W - 1, 40, (58, 42, 88))
    for gy in range(0, 40, 10):
        for gx in range(0, W, 14):
            ox = 7 if (gy // 10) % 2 else 0
            x, y = gx + ox, gy + 3
            g.p(x, y, (80, 58, 116))                # 덩굴 고리
            g.p(x + 1, y + 1, (80, 58, 116))
            g.p(x + 2, y, (80, 58, 116))
            g.p(x + 1, y - 1, (80, 58, 116))
            if (gx + gy) % 28 == 0:
                g.p(x + 5, y + 2, (176, 100, 146))  # 작은 꽃
                g.p(x + 6, y + 2, (146, 78, 120))
    g.rect(0, 40, W - 1, 41, (38, 26, 58))          # 걸레받이
    # 창 — 밤하늘과 별
    g.rrect(118, 4, 146, 26, (120, 92, 54), 2)
    g.rect(121, 7, 143, 23, (24, 30, 66))
    g.rect(131, 7, 132, 23, (120, 92, 54))          # 창살
    g.rect(121, 14, 143, 15, (120, 92, 54))
    for i, (sx2, sy2) in enumerate(((125, 10), (138, 11), (127, 19), (140, 20), (124, 17))):
        if (i + f) % 3 != 0:
            g.p(sx2, sy2, (222, 228, 248))
    # 바닥 — 금빛 널마루 (쨍한 주황 골드)
    for y in range(42, H):
        g.rect(0, y, W - 1, y, (196, 138, 58))
    for y in range(42, H, 7):
        g.rect(0, y, W - 1, y, (156, 104, 44))      # 널 이음새
    for i, x in enumerate(range(-10, W + 20, 24)):
        for y in range(42, H):
            g.p(x + ((y - 42) // 7) * 12, y, (156, 104, 44))
    for _ in range(30):                             # 널 나뭇결
        x, y = rnd.randrange(W), rnd.randrange(43, H - 1)
        if (y % 7) != 0:
            g.rect(x, y, x + rnd.randrange(2, 5), y, (176, 122, 50))
    # 달빛 줄기 — 창에서 바닥으로 비껴 내리는 평평한 띠
    for i in range(40):
        for wdt in range(12):
            x = 120 - i + wdt
            y = 26 + i - wdt // 3
            if 0 <= x < W and 0 <= y < H:
                g.px[x, y] = mix(g.px[x, y], (150, 160, 210), 0.15)
    # 촛불 빛 — 바닥에 넓게 고이는 웅덩이 (컷신의 벽난로 빛처럼)
    br = [1.0, 1.1, 0.92, 1.05][f]
    g.pool(52, 56, int(66 * br), int(17 * br), (255, 190, 90),
           ((0.35, 0.35), (0.7, 0.2), (1.0, 0.1)))
    # 상자 그림자 — 바닥에 딱 붙인다
    g.pool(86, 62, 34, 5, (60, 36, 30), ((1.0, 0.45),))
    # 나무 상자 — 실루엣을 따라 도는 윤곽선 (검은 사각 틀이 아니라)
    bx0, bx1 = 60, 112
    by0, by1 = 32, 61
    g.rrect(bx0 + 1, by0 - 12, bx1 - 1, by0 - 1, OUTLINE, 3)        # 뚜껑 윤곽
    g.rrect(bx0 - 1, by0 - 1, bx1 + 1, by1 + 1, OUTLINE, 4)         # 몸통 윤곽
    g.rrect(bx0 + 2, by0 - 11, bx1 - 2, by0 - 2, (96, 64, 38), 3)   # 뚜껑
    g.rect(bx0 + 4, by0 - 11, bx1 - 4, by0 - 10, (66, 44, 28))
    g.rrect(bx0, by0, bx1, by1, (140, 96, 50), 3)
    for y in range(by0 + 7, by1 - 1, 7):
        g.rect(bx0 + 1, y, bx1 - 1, y, (112, 74, 40))
    g.rect(bx0 + 2, by0, bx1 - 2, by0 + 1, (172, 122, 66))
    for x0 in (bx0, bx1 - 4):                       # 쇠장식
        g.rrect(x0, by0, x0 + 4, by0 + 5, (128, 130, 138), 2)
        g.rrect(x0, by1 - 5, x0 + 4, by1, (104, 106, 114), 2)
        g.p(x0 + 2, by0 + 2, (176, 178, 186))
    g.rect(bx0 + 2, by0 - 1, bx1 - 2, by0 + 2, (40, 26, 18))   # 속 그늘
    # 연구 노트 (상자에 기대 있다)
    g.rrect(72, 22, 100, 32, (74, 48, 32), 2)
    g.rect(74, 22, 98, 23, (98, 66, 42))
    g.rect(77, 22, 79, 32, (154, 110, 48))          # 가죽끈
    g.p(93, 25, (150, 130, 96))                     # 모서리 장식
    g.p(94, 25, (150, 130, 96))
    # 편지 봉투 + 밀랍 인장
    g.rrect(76, 34, 104, 46, (238, 226, 196), 2)
    g.rect(78, 34, 102, 35, (250, 244, 222))
    for i in range(14):
        g.p(77 + i, 35 + i // 2, (198, 182, 148))
        g.p(103 - i, 35 + i // 2, (198, 182, 148))
    g.disk(90, 42, 1, (170, 48, 42))
    g.p(89, 41, (206, 82, 68) if f % 2 else (184, 62, 54))
    # 촛대 탁자 — 촛불이 설 자리 (다리 달린 작은 협탁)
    g.pool(33, 62, 22, 4, (60, 36, 30), ((1.0, 0.4),))          # 탁자 그림자
    g.rrect(16, 36, 50, 39, (124, 86, 48), 2)                   # 상판
    g.rect(18, 36, 48, 36, (150, 108, 60))
    g.rect(19, 40, 21, 58, (96, 66, 38))                        # 다리
    g.rect(45, 40, 47, 58, (96, 66, 38))
    g.rect(19, 58, 21, 58, (66, 44, 28))
    g.rect(45, 58, 47, 58, (66, 44, 28))
    # 촛불 — 탁자 위에 선다
    g.rrect(28, 33, 39, 36, (146, 132, 112), 2)     # 받침
    g.rrect(30, 16, 35, 33, (228, 214, 186), 2)
    g.rect(31, 16, 34, 17, (246, 238, 212))
    g.p(30, 21, (208, 194, 166))                    # 촛농
    g.p(35, 26, (208, 194, 166))
    flame = [((32, 12), (32, 13), (33, 14)),
             ((32, 11), (32, 12), (32, 13)),
             ((33, 12), (32, 13), (32, 14)),
             ((32, 12), (33, 13), (32, 14))][f]
    g.p(*flame[0], (255, 246, 190))
    g.p(*flame[1], (255, 216, 110))
    g.p(*flame[2], (240, 150, 66))
    # 불꽃 곁 은은한 무리 — 벽에는 작고 옅게만 진다
    g.pool(32, 14, int(16 * br), int(11 * br), (255, 200, 100),
           ((0.35, 0.3), (1.0, 0.1)))
    # 나방 — 촛불 곁을 맴돈다
    mo = [(40, 9), (43, 12), (39, 14), (36, 10)][f]
    g.p(mo[0], mo[1], (214, 204, 178))
    g.p(mo[0] + (-1 if f % 2 else 1), mo[1] - (f % 2), (168, 158, 136))
    # 바닥 소품 — 열쇠와 동전 (촛불 빛 웅덩이 안에서 반짝인다)
    g.rect(120, 52, 124, 52, (170, 150, 100))
    g.p(125, 51, (170, 150, 100))
    g.p(126, 52, (170, 150, 100))
    g.p(121, 53, (136, 118, 78))
    g.p(132, 56, (204, 174, 94))
    g.p(133, 56, (228, 198, 112))
    # 구석 실루엣 소품 — 컷신처럼 앞을 어둡게 막는다
    for cx2, cy2, cr in ((6, 70, 9), (12, 66, 6), (2, 62, 6)):      # 화분 덤불
        g.disk(cx2, cy2, cr, (22, 16, 26))
    g.rect(150, 60, 167, 71, (22, 16, 26))          # 낡은 궤짝 실루엣
    g.rect(148, 56, 167, 59, (30, 22, 34))


# ---------------------------------------------------- 3. 할아버지의 편지
def scene_letter(g, f):
    rnd = random.Random(11)
    # 책상 — 짙은 밤색 널
    g.rect(0, 0, W - 1, H - 1, (74, 46, 30))
    for y in range(0, H, 9):
        g.rect(0, y, W - 1, y, (58, 36, 24))
    for _ in range(26):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if y % 9:
            g.rect(x, y, x + rnd.randrange(2, 6), y, (88, 56, 36))
    # 잉크병 (왼쪽 위)
    g.rrect(6, 8, 16, 22, (46, 56, 84), 3)
    g.rect(8, 8, 14, 9, (66, 78, 106))
    g.rrect(8, 4, 14, 8, (32, 38, 54), 2)
    g.p(7, 11, (108, 120, 150))
    g.p(7, 12, (108, 120, 150))
    # 양피지 — 평평한 색면 + 또렷한 가장자리
    PAPER = (240, 226, 190)
    g.rrect(22, 5, 146, 66, (204, 184, 142), 3)     # 가장자리 톤
    g.rrect(24, 6, 144, 65, PAPER, 3)
    g.rect(26, 68, 146, 68, (44, 30, 22))           # 그림자
    for x in range(25, 144):                        # 접힌 자국
        g.p(x, 25, (222, 206, 168))
        g.p(x, 45, (222, 206, 168))
    # 손글씨 — 짧은 획 뭉치
    INK = (92, 64, 38)
    for row in range(8):
        y = 10 + row * 7
        if y > 62:
            break
        x = 30 if row else 40
        while x < 132:
            seg = rnd.randrange(3, 9)
            for i in range(seg):
                g.p(x + i, y + (1 if (x + i) % 6 in (2, 3) else 0), INK)
            x += seg + rnd.randrange(2, 5)
    # 서명
    for i in range(26):
        g.p(96 + i, 60 + int(2.4 * math.sin(i / 3.4)), INK)
        g.p(96 + i, 61 + int(2.4 * math.sin(i / 3.4)), INK)
    # 밀랍 인장 (왼쪽 아래)
    g.disk(34, 58, 3, (170, 48, 42))
    g.p(33, 57, (206, 82, 68))
    # 눌린 꽃잎
    g.p(44, 56, (200, 132, 142))
    g.p(45, 56, (222, 160, 168))
    g.p(44, 57, (200, 132, 142))
    # 돋보기 안경 — 편지 위에 벗어 두었다
    for cx in (58, 70):
        for a in range(0, 360, 24):
            x = cx + int(4.5 * math.cos(math.radians(a)))
            y = 16 + int(4 * math.sin(math.radians(a)))
            g.p(x, y, (132, 110, 62))
        g.p(cx - 1, 14, (250, 244, 222))            # 렌즈 반사
    g.rect(62, 15, 66, 16, (132, 110, 62))          # 브리지
    for i in range(5):
        g.p(75 + i, 17 + i // 2, (154, 130, 76))    # 접힌 다리
    # 깃펜 — 오른쪽 아래
    qx, qy = 116, 62
    for i in range(18):
        g.p(qx + i, qy - i // 3, (182, 174, 154))
        g.p(qx + i, qy - i // 3 + 1, (146, 138, 120))
    sway = [0, -1, 0, 1][f]
    for i in range(7, 18):
        wdt = (18 - i) // 3 + 1
        for k in range(wdt):
            g.p(qx + i, qy - i // 3 - 1 - k + (sway if i > 13 else 0),
                (222, 216, 198) if k % 2 else (192, 184, 166))
    g.rect(qx - 2, qy + 1, qx, qy + 1, (62, 50, 38))
    g.p(qx - 3, qy + 2, (32, 28, 24))
    # 구석 실루엣 — 앞을 어둡게 막는 책더미
    g.rect(0, 60, 14, 71, (24, 16, 14))
    g.rect(2, 56, 12, 59, (34, 24, 20))
    g.rect(152, 62, 167, 71, (24, 16, 14))
    # 촛불 빛 — 오른쪽 위에서 띠로 진다 (일렁임)
    br = [1.0, 1.14, 0.9, 1.08][f]
    g.pool(150, 4, int(66 * br), int(46 * br), (255, 196, 96),
           ((0.35, 0.34), (0.68, 0.2), (1.0, 0.1)))


# ---------------------------------------------------- 4. 해질녘의 농장
def scene_farm(g, f):
    rnd = random.Random(5)
    g.bands([(8, (44, 34, 84)), (16, (92, 54, 100)), (24, (170, 88, 86)),
             (32, (228, 144, 72)), (H - 1, (246, 194, 98))])
    # 구름 — 두 톤 평면 구름이 흐른다
    for cx0, cy0, cw in ((26, 10, 22), (104, 17, 28), (150, 6, 18)):
        cx0 = (cx0 + f) % (W + 30) - 15
        for y in range(cy0 - 3, cy0 + 3):
            for x in range(cx0 - cw // 2, cx0 + cw // 2 + 1):
                d = ((x - cx0) / (cw * 0.55)) ** 2 + ((y - cy0) / 3.0) ** 2
                if d <= 1.0:
                    g.p(x, y, (252, 214, 150) if y < cy0 else (216, 150, 110))
    # 해 — 지평선에 걸린 큰 등불. 평평한 달무리 띠 + 빛 웅덩이
    sx, sy = 130, 30
    g.disk(sx, sy, 8, mix((228, 144, 72), (252, 208, 120), 0.5))
    g.disk(sx, sy, 6, (255, 224, 140))
    g.disk(sx, sy, 4, (255, 244, 190))
    # 먼 산 + 숲 실루엣 (짙은 보라)
    for x in range(W):
        ym = int(34 - 4 * math.sin(x / 40.0 + 1.0) - 2 * math.sin(x / 15.0))
        for y in range(ym, 40):
            g.p(x, y, (86, 60, 96))
    for x in range(W):
        yt = int(39 - 3 * math.sin(x / 11.0) - 2 * math.sin(x / 5.0 + 2))
        for y in range(yt, 43):
            g.p(x, y, (56, 44, 70))
    # 들판 — 어스름 초록 두 단
    g.rect(0, 42, W - 1, 54, (66, 76, 48))
    g.rect(0, 55, W - 1, H - 1, (52, 60, 40))
    # 흙길
    for y in range(47, H):
        k = (y - 47) / (H - 47)
        cx = int(64 + 20 * (1 - k))
        hw = int(2 + 9 * k)
        g.rect(cx - hw, y, cx + hw, y, (172, 130, 78) if y % 3 else (150, 110, 66))
    # 오두막 — 검은 윤곽의 세모 지붕 집
    hx0, hy0 = 52, 22
    g.rrect(hx0, hy0 + 8, hx0 + 30, hy0 + 24, (128, 90, 52), 3)
    for y in range(hy0 + 10, hy0 + 24, 4):
        g.rect(hx0 + 1, y, hx0 + 29, y, (108, 74, 44))
    for i in range(9):                              # 세모 지붕
        half = 3 + round(15 * i / 8.0)
        g.rect(hx0 + 15 - half, hy0 + i, hx0 + 15 + half, hy0 + i, (96, 52, 44))
    g.rect(hx0 + 13, hy0 - 1, hx0 + 17, hy0 - 1, (116, 66, 56))
    g.rect(hx0 - 3, hy0 + 8, hx0 + 33, hy0 + 9, (66, 38, 32))
    for x, y in ((hx0 + 17, hy0 + 2), (hx0 + 19, hy0 + 4), (hx0 + 15, hy0 + 5)):
        g.p(x, y, (52, 30, 26))                     # 지붕 구멍
    g.rrect(hx0 + 20, hy0 - 5, hx0 + 24, hy0 + 4, (104, 78, 62), 2)   # 굴뚝
    g.rrect(hx0 + 12, hy0 + 16, hx0 + 18, hy0 + 25, (78, 50, 30), 3)  # 문
    g.p(hx0 + 17, hy0 + 20, (150, 130, 96))
    g.rrect(hx0 + 4, hy0 + 13, hx0 + 9, hy0 + 18, (46, 52, 82), 2)    # 창
    g.p(hx0 + 5, hy0 + 14, (96, 104, 138))
    g.rrect(hx0 + 22, hy0 + 13, hx0 + 27, hy0 + 18, (46, 52, 82), 2)
    for i in range(6):                              # 판자로 막은 창
        g.p(hx0 + 22 + i, hy0 + 14 + i // 2, (110, 82, 48))
    # 집 윤곽선
    for x in range(hx0 - 1, hx0 + 32):
        g.p(x, hy0 + 25, OUTLINE)
    # 큰 나무 — 검붉은 어스름 잎
    tx, ty = 22, 42
    g.rect(tx - 1, ty - 12, tx + 1, ty, (66, 44, 30))
    for cx2, cy2, cr in ((tx, ty - 17, 9), (tx - 7, ty - 12, 6),
                         (tx + 8, ty - 13, 7), (tx + 1, ty - 22, 6)):
        g.disk(cx2, cy2, cr, (46, 60, 42))
    for i in range(40):                             # 잎 반짝임
        a = rnd.random() * 6.283
        rr = rnd.random()
        x = int(tx + math.cos(a) * 9 * rr)
        y = int(ty - 17 + math.sin(a) * 8 * rr)
        if (i + f) % 3 == 0:
            g.p(x, y, (66, 82, 54))
    leaf_x = tx + 11 + f * 2                        # 낙엽
    leaf_y = ty - 14 + f * 4 + (1 if f % 2 else 0)
    g.p(leaf_x, leaf_y, (150, 122, 60))
    # 부서진 울타리 + 까마귀
    posts = []
    for i, x in enumerate(range(94, 166, 9)):
        if i == 3:
            continue
        tilt = (-1 if i % 3 == 0 else 1) if i % 2 else 0
        for y in range(48, 55):
            g.p(x + tilt * (y - 48) // 4, y, (92, 64, 40))
        g.p(x, 48, (116, 84, 52))
        posts.append(x)
    g.rect(93, 50, 166, 50, (92, 64, 40))
    g.rect(93, 53, 166, 53, (78, 54, 34))
    crow_x = posts[[1, 1, 5, 5][f]]
    g.p(crow_x, 46, (26, 24, 32))
    g.p(crow_x + 1, 46, (26, 24, 32))
    g.p(crow_x + 1, 45, (34, 32, 42))
    g.p(crow_x + 2, 46, (208, 160, 60))
    if f % 2:
        g.p(crow_x, 44, (26, 24, 32))
    # 우편함 — 길 어귀
    g.rect(82, 60, 83, 68, (78, 54, 34))
    g.rrect(78, 55, 88, 60, (140, 62, 50), 2)
    g.rect(80, 55, 86, 56, (166, 84, 64))
    g.p(89, 54, (232, 186, 100))
    # 갈대 — 왼쪽 가장자리
    for i, rx in enumerate((5, 9, 13)):
        rh = 7 + i
        sway = (f % 2) if i % 2 == 0 else ((f + 1) % 2)
        for k in range(rh):
            g.p(rx + (sway if k > rh - 3 else 0), 66 - k, (40, 52, 34))
        g.p(rx + sway, 66 - rh, (122, 104, 62))     # 이삭
    # 잡초 — 어스름 들판 곳곳, 절반은 흔들린다
    for i in range(90):
        x, y = rnd.randrange(0, W), rnd.randrange(44, H - 2)
        if abs(x - (64 + int(20 * (1 - (y - 47) / 25.0)))) < 6 and y > 47:
            continue
        c = (40, 52, 34) if i % 2 else (58, 72, 44)
        sway = (f % 2) if i % 2 else 0
        g.p(x + sway, y - 2, c)
        g.p(x, y - 1, c)
        g.p(x, y, c)
        if i % 19 == 0:
            g.p(x, y - 3, (196, 160, 90))           # 들꽃
    # 새 — 해를 등지고 날아간다
    for bi, (bx, by) in enumerate(((100, 12), (110, 9))):
        bx += f
        wing_up = (f + bi) % 2
        g.p(bx, by, (40, 34, 48))
        if wing_up:
            g.p(bx - 1, by - 1, (40, 34, 48))
            g.p(bx + 1, by - 1, (40, 34, 48))
        else:
            g.p(bx - 1, by, (40, 34, 48))
            g.p(bx + 1, by, (40, 34, 48))
    # 해의 빛 웅덩이 — 지평선과 들판에 띠로 진다
    g.pool(sx, sy, 44, 26, (255, 200, 100), ((0.3, 0.35), (0.65, 0.2), (1.0, 0.1)))
    g.pool(sx, 46, 54, 12, (255, 190, 90), ((0.45, 0.25), (1.0, 0.12)))
    # 반딧불이 — 어스름 들판
    for i, (fx, fy) in enumerate(((20, 62), (44, 66), (95, 64), (118, 60),
                                  (150, 63), (70, 58))):
        ph = (i * 2 + f) % 4
        if ph == 0:
            g.p(fx, fy, (236, 208, 106))
        elif ph == 1:
            g.p(fx, fy, (158, 140, 70))


# ------------------------------------------------------------------- 출력
SCENES = [('grandpa', scene_grandpa), ('box', scene_box),
          ('letter', scene_letter), ('farm', scene_farm)]

for name, fn in SCENES:
    frames = []
    for f in range(FRAMES):
        g = Canvas()
        fn(g, f)
        big = g.im.resize((W * SCALE, H * SCALE), Image.NEAREST)
        fname = 'prologue_%s_%d.png' % (name, f)
        big.save(os.path.join(REF, fname))
        big.save(os.path.join(OUT, fname))
        frames.append(big.convert('P', palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(REF, 'anim_prologue_%s.gif' % name),
                   save_all=True, append_images=frames[1:], duration=260, loop=0)
    print('saved', name, 'x%d' % FRAMES)
print('done')
