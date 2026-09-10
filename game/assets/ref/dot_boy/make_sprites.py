# -*- coding: utf-8 -*-
# 도트 소년(dot_boy) 스프라이트 생성기 3판 — 주인공을 **코드가 직접 그린다**.
#
# 논리 해상도 64x96 을 2배로 키워 게임 규격 128x192 에 꼭 맞춘다.
# 도트 하나 = 월드 1픽셀 — 나무·집·바닥과 같은 굵기다. (2판까지는 32x48을
# 4배로 키워 마을 사람과 같은 굵기였는데, 그 굵기로는 얼굴을 아무리 고쳐도
# 「못생겼다」는 말을 벗지 못했다. 눈 하나가 다섯 칸이면 눈매를 낼 수 없다.)
#
# 그리는 법: 머리는 타원 실루엣을 식으로 잡고 그 위에 눈·눈썹·코·입·귀
# 도장을 찍는다. 머리 모양(짧은·삐죽·긴 머리)은 실루엣 위에 앞머리 선을
# 그어 덮는 덧그림이다. 몸·팔·다리는 좌표로 그린다 — 다리는 관절 각도로
# 뼈를 긋고(굽혀도 길이·두께가 그대로), 팔은 진자로 젓는다.
#
# 발바닥은 논리 95행 = 실제 190~191행, 게임의 FOOT_Y(190) 안에 들어간다.
# 몸통 자리(셔츠 44행 · 허리 68행)는 player.gd 의 SWING_WAIST(136 = 68x2)
# 와 HORSE_POSE 의 자르는 줄에 묶여 있어 못 움직인다.
#
# 프레임: 방향(down/side/up)마다 idle 1장 + walk 6장 + swing 5장,
# 앞·옆은 눈 감은 blink 1장. 네 벌(민머리·짧은·삐죽·긴 머리) x 38장.
#
# 실행:  python3 make_sprites.py     (Pillow 필요)
# 출력:  이 폴더에 프레임 png + preview_*.png + anim_*.gif,
#        ../../sprites/ 에 new_boy_* / hair_short_* / hair_spiky_* / player_f_*.
#        끝에 찍히는 SWING_HAND_DOT 값을 player.gd 에 옮겨 적는다.
import math
import os
from PIL import Image

REF = os.path.dirname(os.path.abspath(__file__))

SCALE = 2
GW, GH = 64, 96          # 논리 캔버스 (가로 한가운데 = 31.5)
FW, FH = 128, 192        # 게임 스프라이트 규격
PAD_X = (FW - GW * SCALE) // 2

# 색은 **game_data.gd 의 표와 한 벌**이다. 게임이 실행 중에 이 값을 정확히
# 찾아 바꿔 입히므로(recolor_player_image) 한 값이라도 어긋나면 그 칸은
# 옷을 못 갈아입는다. 윤곽선·눈·눈썹·반짝이·먼 신발은 표에 없어 늘 그대로다.
PAL = {
    'O': (54, 33, 26),      # 윤곽선
    's': (243, 159, 138),   # 살결
    'S': (213, 116, 98),    # 살결 그늘
    'H': (250, 192, 170),   # 살결 하이라이트
    'e': (66, 32, 30),      # 눈망울·속눈썹
    'i': (136, 70, 42),     # 홍채 반사 · 눈썹 (따뜻한 갈색)
    'w': (246, 242, 234),   # 눈 반짝이
    'r': (235, 128, 114),   # 볼터치
    'm': (170, 84, 66),     # 입
    'b': (58, 88, 168),     # 셔츠
    'B': (38, 58, 120),     # 셔츠 그늘
    'L': (94, 126, 200),    # 셔츠 밝은 면
    'p': (134, 88, 46),     # 바지
    'P': (98, 62, 32),      # 바지 그늘
    'q': (158, 108, 58),    # 바지 밝은 면
    'h': (118, 72, 40),     # 머리카락
    'j': (152, 100, 56),    # 머리카락 밝은 면
    'g': (86, 52, 30),      # 머리카락 그늘
    'k': (82, 53, 33),      # 신발
    'n': (68, 44, 29),      # 먼 신발 — k와 K 사이 (둘 사이 경계가 살아야 한다)
    'K': (56, 37, 25),      # 신발 그늘 (밑창)
}

# ── 걷기 한 바퀴 ─────────────────────────────────────────────────────
# 여섯 칸 — 두 발짝이 한 바퀴라 「통과」 둘·「딛기」 둘이 다 눈금에 놓인다.
WALK = 6

# 다리 한 짝의 여섯 자세를 **각도**로 적는다 (골반 밀림, 허벅지°, 무릎 굽힘°, 발).
# 허벅지 각도 + 앞 / - 뒤. 무릎 굽힘은 늘 0 이상(뒤꿈치가 엉덩이 쪽으로).
# 발 +1 발끝 들림(뒤꿈치로 딛는다) · 0 평평 · -1 뒤꿈치 들림.
LEG_L = 9.0                # 허벅지·정강이 뼈 길이 (둘이 같다)
LEG = [
    ( 2.0,  32,  4,  1),   # 0 Contact — 뻗어서 뒤꿈치로 닿는다
    ( 0.8,  14, 20,  0),   # 1 Down    — 무릎이 굽어 체중을 받는다
    (-0.4,   0,  4,  0),   # 2 Pass    — 몸 밑에 곧게 선다
    (-2.0, -28, 10, -1),   # 3 Up      — 뒤로 뻗고 발끝으로 민다
    (-0.8,   6, 62, -1),   # 4 접기    — 무릎이 오르고 뒤꿈치가 접혀 올라간다
    ( 1.2,  30, 38,  1),   # 5 내밀기  — 무릎이 앞서고 정강이가 따라 나간다
]
LEG_LAG = WALK // 2
FOOT_H = 4                 # 발목 밑 신발 높이


def _leg_depth(spec):
    _, th, flex, _ = spec
    return LEG_L * (math.cos(math.radians(th)) + math.cos(math.radians(th - flex)))


def _joints(spec, hip_y):
    hipo, th, flex, tilt = spec
    a1, a2 = math.radians(th), math.radians(th - flex)
    kx = hipo + LEG_L * math.sin(a1)
    ky = hip_y + LEG_L * math.cos(a1)
    ax = kx + LEG_L * math.sin(a2)
    ay = ky + LEG_L * math.cos(a2)
    return hipo, kx, ky, ax, ay, tilt


def hip_row_at(phase, sq=0):
    d = max(_leg_depth(LEG[phase % WALK]), _leg_depth(LEG[(phase + LEG_LAG) % WALK]))
    return GROUND - FOOT_H - d + sq


BOB = [0, 0, -2, 0, 0, -2]          # 앞·뒷모습: 다리를 모으는 칸에서 몸이 떠오른다
HIP = [2, 2, 0, -2, -2, 0]          # 골반이 앞다리 쪽으로 밀리는 양
ARM = [-10, -4, 2, 10, 4, -2]       # 옆모습 팔이 앞으로 나간 양 (가까운 다리와 반대)
PASS = [0, 0, -1, 0, 0, 1]          # 앞뒤에서 허공을 지나는 다리 (+1 왼 / -1 오른)
STRIDE_F = [6, 4, 0, -6, -4, 0]     # 앞뒤 보폭

# 세로 배치. 머리 31행 + 목 4행 + 몸통 24행 + 다리 23행 = 발바닥 95행.
# 머리 폭 32 · 어깨 폭(팔 포함) 34 — 머리와 어깨가 비슷해야 막대사탕이 안 된다.
# (처음엔 머리 36 · 어깨 32 였는데 「머리랑 비율이 이상하다」는 말을 들었다.
#  38로 넓혀 봤더니 이번엔 상자 위에 머리를 얹은 꼴이었다 — 팔과 몸통 사이에
#  윤곽선을 넣어 팔이 팔로 읽히게 하고, 몸통은 밑으로 갈수록 좁힌다)
ARMPIT = 8
NECK_H = 4
ARM_L = 15               # 왼팔 소매 왼쪽 열 (6칸 폭 15~20, 몸판 21~42)
ARM_R = 43
HEAD_TOP = 9
HEAD_X = 16              # 32칸 머리의 왼쪽 열 (가운데 31.5)
HEAD_W, HEAD_H = 32, 31
SHIRT_Y = 44
HIP_Y = 68               # = player.gd SWING_WAIST / 2
LEG_Y = 73
GROUND = 95


class G:
    """논리 캔버스. 문자(팔레트 키)로 칠한다."""
    def __init__(self):
        self.d = [['.'] * GW for _ in range(GH)]

    def px(self, x, y, c):
        if 0 <= x < GW and 0 <= y < GH:
            self.d[y][x] = c

    def at(self, x, y):
        if 0 <= x < GW and 0 <= y < GH:
            return self.d[y][x]
        return '.'

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def blit(self, art, x0, y0):
        for dy, row in enumerate(art):
            for dx, c in enumerate(row):
                if c != '.':
                    self.px(x0 + dx, y0 + dy, c)

    def outline(self):
        """채워진 곳 둘레의 빈 칸을 윤곽선으로 두른다 (상하좌우)."""
        edge = []
        for y in range(GH):
            for x in range(GW):
                if self.d[y][x] != '.':
                    continue
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < GW and 0 <= ny < GH and self.d[ny][nx] not in '.O':
                        edge.append((x, y))
                        break
        for x, y in edge:
            self.d[y][x] = 'O'

    def render(self):
        im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
        px = im.load()
        for y in range(GH):
            for x in range(GW):
                c = self.d[y][x]
                if c == '.':
                    continue
                col = PAL[c] + (255,)
                for sy in range(SCALE):
                    for sx in range(SCALE):
                        px[PAD_X + x * SCALE + sx, y * SCALE + sy] = col
        return im


# ------------------------------------------------------------------- 머리
#
# 머리는 **캔버스 한 장(Art)** 에 그려 두고 몸 위에 얹는다. 좌표는 머리
# 그림의 왼쪽 위(0,0) 기준이고, 머리카락은 그 밖으로 부풀 수 있어 캔버스에
# 여백(MARGIN)을 둔다.

MARGIN = 8


class Art:
    def __init__(self, extra_below=0):
        self.w = HEAD_W + MARGIN * 2
        self.h = HEAD_H + MARGIN * 2 + extra_below
        self.d = [['.'] * self.w for _ in range(self.h)]

    def px(self, x, y, c):
        x += MARGIN; y += MARGIN
        if 0 <= x < self.w and 0 <= y < self.h:
            self.d[y][x] = c

    def at(self, x, y):
        x += MARGIN; y += MARGIN
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.d[y][x]
        return '.'

    def stamp(self, rows, x0, y0, skip='.'):
        for dy, row in enumerate(rows):
            for dx, c in enumerate(row):
                if c != skip:
                    self.px(x0 + dx, y0 + dy, c)

    def rows(self):
        return [''.join(r) for r in self.d]

    def blit_to(self, g, x0, y0):
        g.blit(self.rows(), x0 - MARGIN, y0 - MARGIN)


# ---- 실루엣 ----
# 앞·뒷모습: 위는 둥글고 턱으로 갈수록 좁아지는 달걀. 줄마다 (왼끝, 오른끝).
EGG_CX = (HEAD_W - 1) / 2.0      # 15.5
EGG_CY = 14.0                    # 가장 넓은 줄
CHIN_FROM = 22                   # 여기부터 턱이 좁아진다


def _egg_rows():
    out = {}
    rx = HEAD_W / 2.0
    for r in range(HEAD_H):
        if r <= EGG_CY:
            t = (r - EGG_CY) / (EGG_CY + 1.0)
        else:
            t = (r - EGG_CY) / (HEAD_H - EGG_CY + 1.0)
        hw = rx * math.sqrt(max(0.0, 1 - t * t))
        if r > CHIN_FROM:
            hw *= 1 - 0.20 * ((r - CHIN_FROM) / float(HEAD_H - 1 - CHIN_FROM)) ** 1.6
        x0 = math.ceil(EGG_CX - hw + 0.001)
        x1 = math.floor(EGG_CX + hw - 0.001)
        if x1 >= x0:
            out[r] = (x0, x1)
    return out


# 옆모습(오른쪽 보기): 뒤통수는 타원, 앞은 이마-눈두덩-코-입-턱 윤곽을 적는다.
PROFILE_FRONT = [
    20, 24, 26, 27, 28, 29, 29, 30,         # 0~7  정수리~이마 (타원을 따라)
    30, 30, 30, 30,                         # 8~11 이마
    30, 30, 30,                             # 12~14 눈썹 뼈
    30, 30, 30,                             # 15~17 눈두덩
    31, 32, 32, 31,                         # 18~21 코 — 작고 뾰족하게
    30,                                     # 22 코 밑
    29, 29,                                 # 23~24 인중
    30, 29,                                 # 25~26 입술
    28, 26, 23, 19,                         # 27~30 턱
]
assert len(PROFILE_FRONT) == HEAD_H


def _profile_rows():
    out = {}
    rx = HEAD_W / 2.0
    for r in range(HEAD_H):
        if r <= EGG_CY:
            t = (r - EGG_CY) / (EGG_CY + 1.0)
            back = rx - rx * math.sqrt(max(0.0, 1 - t * t))
        else:
            t = (r - EGG_CY) / (HEAD_H - EGG_CY + 2.0)
            back = rx - rx * math.sqrt(max(0.0, 1 - t * t)) * (1 - 0.15 * max(0, (r - CHIN_FROM) / 8.0))
        x0 = math.ceil(back)
        x1 = PROFILE_FRONT[r]
        if r <= 7:                          # 정수리는 타원이 앞도 정한다
            x1 = min(x1, math.floor(EGG_CX + rx * math.sqrt(max(0.0, 1 - ((r - EGG_CY) / (EGG_CY + 1.0)) ** 2))))
        if x1 >= x0:
            out[r] = (x0, x1)
    return out


EGG = _egg_rows()
PROFILE = _profile_rows()


def _fill_shape(a, shape, light_x=None):
    """실루엣을 살결로 채우고 오른쪽 가장자리에 그늘, 이마에 하이라이트."""
    for r, (x0, x1) in shape.items():
        for x in range(x0, x1 + 1):
            a.px(x, r, 's')
        if 7 <= r <= HEAD_H - 3:            # 빛 반대편(오른쪽) 두 칸 그늘
            for x in range(max(x0, x1 - 1), x1 + 1):
                a.px(x, r, 'S')
        if r >= HEAD_H - 3:                 # 턱 밑 그늘
            for x in range(x0, x1 + 1):
                a.px(x, r, 'S')
    if light_x is not None:                 # 이마 하이라이트 (민머리에서만 보인다)
        cx, cy = light_x, 6.0
        for r, (x0, x1) in shape.items():
            for x in range(x0, x1 + 1):
                if ((x - cx) / 7.5) ** 2 + ((r - cy) / 4.5) ** 2 <= 1.0 and a.at(x, r) == 's':
                    a.px(x, r, 'H')


# ---- 얼굴 도장 ----
# 눈 10x8 — 위 속눈썹 선은 바깥쪽이 두껍고 안쪽으로 갈수록 짧다. 눈망울은
# 통째로 어둡고, 왼쪽 위에 세로로 긴 흰 반짝이, 아래 두 줄은 따뜻한 갈색
# 반사. 아랫줄이 좁아져 아몬드꼴이 된다.
EYE_L = [
    "eeeeeee..",       # 눈꼬리(바깥) 쪽으로 뻗은 속눈썹 선
    ".eeeeeee.",
    "..ewweeee",
    "..ewweeee",
    "..eeeeeee",
    "..eiiiiie",
    "..eiiiiie",
    "...eeeee.",
]
EYE_R = [
    "..eeeeeee",
    ".eeeeeee.",
    "ewweeee..",
    "ewweeee..",
    "eeeeeee..",
    "eiiiiie..",
    "eiiiiie..",
    ".eeeee...",
]
EYE_SIDE = [           # 옆모습: 앞(오른쪽)이 눈꼬리라 거기가 두껍다
    "..eeeeee",
    ".eeeeee.",
    "ewweee..",
    "ewweee..",
    "eeeeee..",
    "eiiiie..",
    "eiiiie..",
    ".eeee...",
]
# 감은 눈 — 아래로 굽은 속눈썹 선 (눈 자리 아래쪽에 찍는다)
LID_L = [
    "ee.....ee",
    ".eeeeeee.",
    "..eeeee..",
]
LID_SIDE = [
    "ee....ee",
    ".eeeeee.",
    "..eeee..",
]
BROW_L = [             # 눈썹 6x2 — 바깥이 낮은 완만한 활
    ".iiiii",
    "ii....",
]
BROW_R = [
    "iiiii.",
    "....ii",
]
BROW_SIDE = [
    ".iiiiii",
    "ii.....",
]
EAR_SIDE = [           # 옆모습 귀 5x6 — 둥근 테 안에 살결과 그늘
    ".OOO.",
    "OssSO",
    "OsSSO",
    "OsSSO",
    "OssSO",
    ".OOO.",
]

# 얼굴 자리 (머리 그림 기준)
EYE_Y = 15
EYE_LX, EYE_RX = 4, 19           # 왼눈 4~12 (눈망울 6~12) · 오른눈 19~27 (눈망울 19~25)
EYE_SX = 22                      # 옆모습 눈 22~29 (눈망울 22~27)
BROW_Y = 12
NOSE = [(15, 20), (15, 21), (15, 22), (16, 22)]     # 두 눈 사이 아래 그늘 「ㄴ」
MOUTH_Y = 26


def face_down(a, blink=False, female=False):
    a.stamp(BROW_L, EYE_LX + 2, BROW_Y)
    a.stamp(BROW_R, EYE_RX + 1, BROW_Y)
    if blink:
        a.stamp(LID_L, EYE_LX, EYE_Y + 4)
        a.stamp(LID_L, EYE_RX, EYE_Y + 4)
    else:
        a.stamp(EYE_L, EYE_LX, EYE_Y)
        a.stamp(EYE_R, EYE_RX, EYE_Y)
        if female:                          # 눈꼬리 속눈썹 — 날개를 한 칸 더, 아래 바깥에 한 점
            a.px(EYE_LX - 1, EYE_Y, 'e'); a.px(EYE_LX - 1, EYE_Y - 1, 'e')
            a.px(EYE_RX + 9, EYE_Y, 'e'); a.px(EYE_RX + 9, EYE_Y - 1, 'e')
            a.px(EYE_LX + 2, EYE_Y + 7, 'e'); a.px(EYE_RX + 6, EYE_Y + 7, 'e')
    for x, y in NOSE:
        a.px(x, y, 'S')
    for x in range(13, 19):                 # 입 — 살짝 웃는 선
        a.px(x, MOUTH_Y, 'm')
    a.px(12, MOUTH_Y - 1, 'S'); a.px(19, MOUTH_Y - 1, 'S')
    for y in (EYE_Y + 8, EYE_Y + 9):        # 볼터치
        for x in range(4, 8):
            a.px(x, y, 'r')
        for x in range(24, 28):
            a.px(x, y, 'r')


def ears_down(a):
    """앞·뒷모습 귀 — 눈높이 양옆에 3x5 볼록."""
    for r in range(EYE_Y + 1, EYE_Y + 6):
        x0, x1 = EGG[r]
        edge = 1 if r in (EYE_Y + 1, EYE_Y + 5) else 0
        for k in range(edge, 3):
            a.px(x0 - 1 - k, r, 's' if k > 0 else 'S')
            a.px(x1 + 1 + k, r, 's' if k > 0 else 'S')


def face_side(a, blink=False, female=False):
    a.stamp(BROW_SIDE, EYE_SX + 1, BROW_Y)
    if blink:
        a.stamp(LID_SIDE, EYE_SX, EYE_Y + 4)
    else:
        a.stamp(EYE_SIDE, EYE_SX, EYE_Y)
        if female:
            a.px(EYE_SX + 8, EYE_Y, 'e'); a.px(EYE_SX + 8, EYE_Y - 1, 'e')
            a.px(EYE_SX + 1, EYE_Y + 7, 'e')
    a.stamp(EAR_SIDE, 7, EYE_Y + 1)
    a.px(30, 22, 'S'); a.px(31, 22, 'S')    # 코끝 밑 그늘
    for x in range(27, 30):                 # 입
        a.px(x, MOUTH_Y - 1, 'm')
    a.px(26, MOUTH_Y - 2, 'S')
    for y in (EYE_Y + 8, EYE_Y + 9):        # 볼터치
        for x in range(17, 21):
            a.px(x, y, 'r')


# ---- 머리카락 ----
# 실루엣 위에 「앞머리 선」을 그어 그 위를 머리카락으로 덮는다. 끝이 뾰족한
# 가닥은 삼각형으로 판다. 정수리 왼쪽 위에 밝은 면(j), 끝자락에 그늘(g).

def _bang_depth(x, tips, depth=3.0, slope=0.6):
    d = 0.0
    for tc in tips:
        d = max(d, depth - abs(x - tc) * slope)
    return max(0.0, d)


def _cap(a, shape, hairline, puff=1, back_cols=None):
    """shape 의 줄마다 hairline(x) 보다 위인 칸을 머리카락으로. puff 만큼 밖으로 부푼다."""
    cells = set()
    for r, (x0, x1) in shape.items():
        for x in range(x0 - puff, x1 + puff + 1):
            if r < hairline(x) or (back_cols is not None and x < back_cols(r)):
                cells.add((x, r))
    for r in range(-puff, 0):               # 정수리 위 부풀림
        if 0 in shape:
            x0, x1 = shape[0]
            for x in range(x0 + 2 - r, x1 - 2 + r + 1):
                cells.add((x, r))
    return cells


def _paint_hair(a, cells, light=(12.0, 5.0), shade_bottom=True):
    for (x, y) in cells:
        c = 'h'
        if ((x - light[0]) / 8.0) ** 2 + ((y - light[1]) / 4.5) ** 2 <= 1.0:
            c = 'j'
        a.px(x, y, c)
    if shade_bottom:                        # 아래 가장자리 한 줄은 그늘
        for (x, y) in cells:
            if (x, y + 1) not in cells and (x, y + 2) not in cells and y > 8:
                a.px(x, y, 'g')


def hair_short(a, view):
    if view == 'down':
        tips = [3, 9, 15, 21, 27]
        cells = _cap(a, EGG, lambda x: 10 + _bang_depth(x, tips, 4.5, 0.9))
        # 구레나룻 — 눈높이까지 양옆 두 칸
        for r in range(11, EYE_Y + 4):
            x0, x1 = EGG[r]
            for k in range(2):
                cells.add((x0 + k, r)); cells.add((x1 - k, r))
        _paint_hair(a, cells)
    elif view == 'side':
        tips = [18, 23, 28]
        cells = _cap(a, PROFILE, lambda x: 10 + _bang_depth(x, tips, 4.5, 0.9) if x >= 16 else 99,
                     back_cols=lambda r: (PROFILE[r][0] + 5) if r < 24 else -99)
        _paint_hair(a, cells, light=(10.0, 4.5))
    else:
        cells = _cap(a, EGG, lambda x: 22 + _bang_depth(x, [3, 10, 17, 24], 2.5, 0.7))
        _paint_hair(a, cells, light=(12.0, 4.5))


def hair_spiky(a, view):
    hair_short(a, view)
    x0, x1 = (EGG if view != 'side' else PROFILE)[0]
    spikes = ((x0 + 1, 5, -1), (x0 + 7, 7, 0), (x0 + 13, 6, 1), (x0 + 19, 5, 1)) if view != 'side' \
        else ((x0 - 1, 5, -1), (x0 + 5, 7, 0), (x0 + 11, 6, 1))
    for sc, hgt, lean_ in spikes:           # 밑이 넓고 끝이 뾰족한 삼각 가닥, 살짝 기울여
        for k in range(hgt):
            y = -1 - k
            half = max(0, (hgt - 1 - k) * 3 // 5)
            cx = sc + (lean_ * k) // 2
            for x in range(cx - half, cx + half + 1):
                a.px(x, y, 'j' if (x < cx and k > 1) else 'h')
    # 옆으로 삐친 가닥
    if view != 'side':
        for r, ext in ((5, 2), (6, 3), (7, 2)):
            xa, xb = EGG[r]
            for k in range(1, ext + 1):
                a.px(xa - k, r, 'h'); a.px(xb + k, r, 'h')


def hair_long(a, view):
    if view == 'down':
        tips = [8, 13, 19, 24]
        cells = _cap(a, EGG, lambda x: 10 + _bang_depth(x, tips, 4.5, 0.9))
        # 옆머리 — 귀를 덮고 얼굴 **바깥으로** 곧게 흘러 어깨를 지나 가슴께까지.
        # 턱 밑에서 안으로 모으면 수염처럼 보인다 — 가장 넓은 자리의 열을 그대로 내린다
        wide0, wide1 = EGG[int(EGG_CY) + 2]
        for r in range(9, HEAD_H + 18):
            if r in EGG and r < 18:
                x0, x1 = EGG[r]
                w = 4
            else:
                x0, x1 = wide0, wide1
                w = 5
            fade = max(0, (r - (HEAD_H + 11)) // 2)     # 끝은 둥글게 좁아진다
            for k in range(w - fade):
                cells.add((x0 - 1 + k, r))
                cells.add((x1 + 1 - k, r))
        _paint_hair(a, cells, shade_bottom=False)
        for (x, y) in cells:                    # 머리채 아래·안쪽 가장자리 그늘
            if y >= HEAD_H + 8 or ((x, y + 1) not in cells and y > 30):
                a.px(x, y, 'g')
    elif view == 'side':
        tips = [19, 24, 29]
        cells = _cap(a, PROFILE, lambda x: 10 + _bang_depth(x, tips, 4.5, 0.9) if x >= 15 else 99,
                     back_cols=lambda r: (PROFILE[r][0] + 8) if r < 27 else 99)
        # 등을 덮는 머리채
        for r in range(9, HEAD_H + 18):
            back = PROFILE[min(r, HEAD_H - 1)][0] if r < HEAD_H else 11
            w = 10 if r < HEAD_H else max(3, 10 - (r - HEAD_H) // 2)
            for k in range(w):
                cells.add((back - 2 + k, r))
        _paint_hair(a, cells, light=(11.0, 5.0), shade_bottom=False)
        for (x, y) in cells:
            if y >= HEAD_H + 8 or ((x, y + 1) not in cells and y > 30):
                a.px(x, y, 'g')
    else:
        cells = _cap(a, EGG, lambda x: 99)
        for r in range(HEAD_H, HEAD_H + 18):
            hw = 15 - (r - HEAD_H) * 0.5
            for x in range(math.ceil(EGG_CX - hw), math.floor(EGG_CX + hw) + 1):
                cells.add((x, r))
        _paint_hair(a, cells, light=(12.0, 4.5), shade_bottom=False)
        for (x, y) in cells:
            if y >= HEAD_H + 12 or (x, y + 1) not in cells:
                a.px(x, y, 'g')
        for y in range(11, HEAD_H + 10):        # 결 — 밝은 줄 두 가닥
            for x in (8, 23):
                if a.at(x, y) == 'h':
                    a.px(x, y, 'j')


HAIRS = {'short': hair_short, 'spiky': hair_spiky, 'long': hair_long}


def make_head(view, hair=None, blink=False, female=False, ears=True):
    """머리 그림 한 장. hair: None | 'short' | 'spiky' | 'long'"""
    a = Art(extra_below=24)
    if view == 'side':
        _fill_shape(a, PROFILE, light_x=None if hair else 12.0)
        face_side(a, blink, female)
    elif view == 'down':
        _fill_shape(a, EGG, light_x=None if hair else 12.0)
        face_down(a, blink, female)
        if ears:
            ears_down(a)
    else:
        _fill_shape(a, EGG, light_x=None if hair else 12.0)
        if ears:
            ears_down(a)
    if hair:
        HAIRS[hair](a, view)
    return a


def head(g, art, bob, lean=0):
    art.blit_to(g, HEAD_X + lean, HEAD_TOP + bob)


# ------------------------------------------------------------------- 몸통

def torso_down(g, bob, swing, dx=0, skip=None):
    """앞모습 몸통+팔. swing: 화면 왼쪽 팔이 앞으로 나간 양 -6..+6"""
    y = SHIRT_Y + bob
    g.rect(28 + dx, y - NECK_H, 35 + dx, y - 1, 's')          # 목
    g.rect(28 + dx, y - NECK_H, 35 + dx, y - NECK_H + 1, 'S')  # 턱 밑 그림자
    g.rect(34 + dx, y - NECK_H, 35 + dx, y - 1, 'S')
    g.rect(21 + dx, y, 42 + dx, y + 11, 'b')                   # 몸판 — 어깨 22칸
    g.rect(22 + dx, y + 12, 41 + dx, y + 23, 'b')              #        허리 20칸
    g.rect(22 + dx, y + 22, 41 + dx, y + 23, 'B')              # 아랫단 그늘
    g.rect(23 + dx, y, 24 + dx, y + 20, 'L')                   # 빛 받는 왼쪽
    g.rect(39 + dx, y + 12, 40 + dx, y + 21, 'B')              # 오른쪽 아래 그늘
    g.rect(26 + dx, y, 37 + dx, y + 1, 'B')                    # 둥근 옷깃
    g.rect(26 + dx, y + 2, 27 + dx, y + 2, 'B'); g.rect(36 + dx, y + 2, 37 + dx, y + 2, 'B')
    g.rect(31 + dx, y + 2, 32 + dx, y + 3, 'B')                # 앞섶 트임
    for by in (y + 7, y + 13, y + 19):                         # 단추 셋
        g.rect(31 + dx, by, 32 + dx, by + 1, 'B')
    for cx in (21 + dx, 42 + dx):                              # 어깨 모서리 깎기
        g.px(cx, y, '.')
    for cx in (22 + dx, 41 + dx):                              # 밑단 모서리 깎기
        g.px(cx, y + 23, '.')
    for sx, sw, side in ((ARM_L, -swing, 'left'), (ARM_R, swing, 'right')):
        if side == skip:
            if side == 'left':
                g.rect(ARM_L + 2 + dx, y + 2, ARM_L + 5 + dx, y + ARMPIT - 1, 'b')
                g.rect(ARM_L + 2 + dx, y + 2, ARM_L + 2 + dx, y + ARMPIT - 1, 'L')
            else:
                g.rect(ARM_R + dx, y + 2, ARM_R + 3 + dx, y + ARMPIT - 1, 'b')
            continue
        sx += dx
        dy = (2 if sw >= 4 else 0) + (2 if sw >= 6 else 0) \
            - (2 if sw <= -4 else 0) - (2 if sw <= -6 else 0)
        g.rect(sx, y + 1, sx + 5, y + 11 + dy, 'b')             # 소매
        if side == 'left':
            g.rect(sx, y + 1, sx, y + 11 + dy, 'L')
        else:
            g.rect(sx + 5, y + 1, sx + 5, y + 11 + dy, 'B')
        g.rect(sx, y + 12 + dy, sx + 5, y + 13 + dy, 'B')       # 소매단
        g.rect(sx, y + 14 + dy, sx + 5, y + 18 + dy, 's')       # 손 (5줄, 네 모서리 둥글게)
        g.rect(sx + 1, y + 18 + dy, sx + 4, y + 18 + dy, 'S')   # 손 그늘
        g.rect(sx + 4, y + 15 + dy, sx + 5, y + 17 + dy, 'S')
        g.px(sx + 2, y + 16 + dy, 'S')                          # 손가락 사이
        out = sx if side == 'left' else sx + 5
        inn = sx + 5 if side == 'left' else sx
        g.px(out, y + 1, '.')                                   # 어깨 모서리 깎기
        for cx in (sx, sx + 5):
            g.px(cx, y + 18 + dy, '.'); g.px(cx, y + 14 + dy, '.')
        # 팔과 몸통 사이 윤곽선 — 겨드랑이부터 소매단까지. 이게 없으면 팔이
        # 몸판에 붙은 널빤지가 되어 몸 전체가 상자로 읽힌다
        g.vline(inn, y + ARMPIT, y + 13 + dy, 'O')


def legs_down(g, stride, dx=0, sq=0, pass_leg=0):
    """앞모습 다리. stride: 왼쪽 다리가 앞으로 나간 양 -6..+6"""
    g.rect(22 + dx, HIP_Y + sq, 41 + dx, HIP_Y + 4 + sq, 'p')   # 엉덩이 띠 (20칸)
    g.rect(22 + dx, HIP_Y + sq, 41 + dx, HIP_Y + 1 + sq, 'P')   # 셔츠 아랫단 그늘
    g.rect(31 + dx, HIP_Y + 3 + sq, 32 + dx, HIP_Y + 4 + sq, 'P')
    W = 9                                                       # 다리 폭
    for x0, s in ((22, stride), (33, -stride)):
        left = x0 == 22
        swinging = (pass_leg > 0 and left) or (pass_leg < 0 and not left)
        lift = 6 if swinging else (min(6, -s) if s < 0 else 0)
        pc = 'P' if lift else 'p'
        inner = x0 + W - 1 if left else x0
        top = LEG_Y + sq
        bend = (2 if left else -2) if lift >= 4 else 0
        knee_row = (top + GROUND - lift) // 2
        flare = (-2 if left else 2) if (sq >= 3 and not lift) else 0
        outer = x0 if left else x0 + W - 1
        for yy in range(top, GROUND - 6 - lift):
            t = (yy - (HIP_Y + 4 + sq)) / (GROUND - HIP_Y - 4 - sq)
            off = round(dx * (1 - t))
            if yy > knee_row:
                off += bend
            if flare and knee_row - 2 <= yy <= knee_row + 2:
                off += flare
            g.rect(x0 + off, yy, x0 + W - 1 + off, yy, pc)
            g.px(inner + off, yy, 'P')
            if not lift and left:
                g.px(outer + off, yy, 'q')
            if yy in (top, top + 1, knee_row, GROUND - 7 - lift):
                g.hline(x0 + off, x0 + W - 1 + off, yy, 'P')  # 허리·무릎·발목 접단
        # 신발 6줄 — 앞코가 둥글고 밑창은 어둡다
        sy0 = GROUND - 6 - lift
        g.rect(x0 + bend, sy0, x0 + W - 1 + bend, GROUND - 1 - lift, 'k')
        g.px(x0 + bend, sy0, '.'); g.px(x0 + W - 1 + bend, sy0, '.')
        g.hline(x0 + 1 + bend, x0 + W - 2 + bend, GROUND - lift, 'K')
        g.rect(x0 + 2 + bend, sy0, x0 + W - 3 + bend, sy0 + 1, 'p')   # 신발 코 광
        g.px((x0 if not left else x0 + W - 1) + bend, GROUND - 1 - lift, 'K')
        g.px((x0 if not left else x0 + W - 1) + bend, GROUND - 2 - lift, 'K')
        if lift:
            g.hline(x0 + bend, x0 + W - 1 + bend, GROUND - lift, 'K')


def _side_arm(g, c, y, sw, near):
    """옆모습 팔 한 짝 — 어깨(c, y+2)에서 진자로 젓는다. near=False 면 몸 뒤."""
    L = 20.0
    hy = y + 14 - round(L - math.sqrt(max(0.0, L * L - sw * sw)))
    cells = {}
    W = 8
    for yy in range(y + 2, hy):
        t = (yy - (y + 2)) / max(1, hy - 1 - (y + 2))
        x = c - 4 + round(sw * t)
        for j in range(W):
            col = 'b' if near else 'B'
            if near and j == 0:
                col = 'B'
            if near and j == W - 1:
                col = 'L'
            if near and yy >= hy - 2:
                col = 'B'                                       # 소매단
            cells[(x + j, yy)] = col
    hx = c - 3 + sw
    hand = 's' if near else 'S'
    for k in range(6):
        ox = round(sw * k / 14)
        for j in range(8):
            if (k == 0 or k == 5) and (j == 0 or j == 7):
                continue
            cells[(hx + j + ox, hy + k)] = hand
    if near:
        for k in (3, 4):
            ox = round(sw * k / 14)
            for j in (5, 6):
                cells[(hx + j + ox, hy + k)] = 'S'
    for (x, yy) in cells:
        for nx, ny in ((x - 1, yy), (x + 1, yy), (x, yy - 1), (x, yy + 1)):
            if (nx, ny) in cells or not (0 <= nx < GW and 0 <= ny < GH):
                continue
            if yy < y + ARMPIT:
                continue
            if g.d[ny][nx] != '.':
                g.d[ny][nx] = 'O'
    for (x, yy), cc in cells.items():
        g.px(x, yy, cc)


def torso_side(g, bob, swing, lean=0, draw_arm=True, arm=None, far_arm=None):
    y = SHIRT_Y + bob
    c = 31 + lean
    sw = arm if arm is not None else \
        -(swing + (2 if swing > 0 else -2 if swing < 0 else 0))
    if draw_arm:
        _side_arm(g, c, y, -sw, False)
    elif far_arm is not None:
        _side_arm(g, c, y, far_arm, False)
    g.rect(c - 2, y - NECK_H, c + 5, y - 1, 's')                # 목
    g.rect(c - 2, y - NECK_H, c + 5, y - NECK_H + 1, 'S')
    g.rect(c - 2, y - NECK_H, c - 1, y - 1, 'S')
    g.rect(c - 9, y, c + 12, y + 23, 'b')
    g.rect(c - 9, y + 22, c + 12, y + 23, 'B')
    g.rect(c + 11, y, c + 12, y + 21, 'L')                      # 앞면이 밝다
    g.rect(c + 9, y + 1, c + 10, y + 2, 'L')
    g.rect(c - 9, y, c - 8, y + 21, 'B')                        # 등쪽 그늘
    g.rect(c - 7, y + 1, c - 6, y + 2, 'B')
    g.rect(c - 2, y, c + 7, y + 1, 'B')                         # 옷깃
    for cx in (c - 9, c - 8, c + 11, c + 12):
        g.px(cx, y, '.')
    for cx in (c - 9, c + 12):
        g.px(cx, y + 23, '.')
    if draw_arm:
        _side_arm(g, c, y, sw, True)


def _bone(g, x0, y0, x1, y1, w0, w1, body, back=None, front=None, mark=None):
    d = math.hypot(x1 - x0, y1 - y0)
    if d < 0.01:
        d, ux, uy = 0.01, 0.0, 1.0
    else:
        ux, uy = (x1 - x0) / d, (y1 - y0) / d
    nx, ny = uy, -ux
    for i in range(int(d * 4) + 1):
        t = i / (d * 4)
        cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        hw = (w0 + (w1 - w0) * t) / 2.0
        j = -int(hw * 4)
        while j <= int(hw * 4):
            sv = j / 4.0
            col = body
            if back is not None and sv <= -hw + 1.0:
                col = back
            elif front is not None and sv >= hw - 1.0:
                col = front
            px_, py_ = round(cx + nx * sv), round(cy + ny * sv)
            g.px(px_, py_, col)
            if mark is not None:
                mark.add((px_, py_))
            j += 1


def _boot(g, ax, ay, tilt, body, sole, lit, mark=None):
    """신발 네 줄 — 각도에 따라 어느 줄이 땅에 닿는지가 달라진다."""
    x, y = round(ax), round(ay)
    if tilt > 0:
        hi = (x - 5, x + 7); lo = (x - 5, x + 1)
    elif tilt < 0:
        hi = (x - 7, x + 5); lo = (x + 1, x + 7)
    else:
        hi = (x - 5, x + 5); lo = (x - 5, x + 7)
    g.rect(hi[0], y + 1, hi[1], y + 2, body)
    g.rect(lo[0], y + 3, lo[1], y + 4, sole)
    g.px(hi[0], y + 1, '.')                                     # 뒤꿈치 모서리
    if lit:
        g.rect(hi[1] - 2, y + 1, hi[1], y + 1, lit)             # 발등이 빛을 문다
    if mark is not None:
        for a_, b_, yy in ((hi[0], hi[1], y + 1), (hi[0], hi[1], y + 2),
                           (lo[0], lo[1], y + 3), (lo[0], lo[1], y + 4)):
            for xx in range(a_, b_ + 1):
                mark.add((xx, yy))


def legs_side(g, stride=0, lean=0, dx=0, sq=0, phase=None, hip=0, poses=None):
    """옆모습 다리. 돌려주는 값은 골반 줄(반올림)."""
    if poses is not None:
        near_spec, far_spec = poses
        hip_row = GROUND - FOOT_H - max(_leg_depth(near_spec), _leg_depth(far_spec)) + sq
    elif phase is None:
        near_spec = far_spec = None
        hip_row = HIP_Y + 4 + sq
    else:
        near_spec = LEG[phase % WALK]
        far_spec = LEG[(phase + LEG_LAG) % WALK]
        hip_row = hip_row_at(phase, sq)
    c = 31 + lean + hip
    hr = round(hip_row)
    g.rect(c - 7 + dx, hr - 4, c + 9 + dx, hr, 'p')             # 바지 띠
    g.rect(c - 7 + dx, hr - 4, c + 9 + dx, hr - 3, 'P')
    g.hline(c - 7 + dx, c + 9 + dx, hr, 'P')
    if near_spec is None:
        near_front = None if not stride else stride > 0
    else:
        _n = _joints(near_spec, 0)[3]
        _f = _joints(far_spec, 0)[3]
        near_front = None if abs(_n - _f) < 1.0 else _n > _f
    for shade in (True, False):
        if near_spec is None:
            off = -stride if shade else stride
            hx = off * 0.35
            kx, ky = off * 0.85, hip_row + LEG_L
            ax, ay = off * 1.35, hip_row + LEG_L * 2
            tilt = -1 if off < 0 else 0
            if shade and not stride:
                hx -= 1.4; kx -= 1.4; ax -= 1.4
        else:
            hx, kx, ky, ax, ay, tilt = _joints(far_spec if shade else near_spec, hip_row)
        base = 32 + lean
        hx = base + hx + dx + hip
        kx = base + kx + (dx + hip) * 0.5
        ax = base + ax + (dx + hip) * 0.15
        pc, sc, hl = ('P', 'n', None) if shade else ('p', 'P', 'q')
        kc, kk = ('n', 'K') if shade else ('k', 'K')
        mark = None if shade else set()
        _bone(g, hx, hip_row - 2, kx, ky, 10.4, 8.6, pc, sc, hl, mark)
        _bone(g, kx, ky, ax, ay, 8.6, 7.2, pc, sc, hl, mark)
        if not shade:
            g.px(round(ax), round(ay), 'q')
        _boot(g, ax, ay, tilt, kc, kk, 'p' if not shade else None, mark)
        if shade or near_front is None:
            continue
        LEGC = ('p', 'P', 'q', 'k', 'K', 'n')
        rows = {}
        for (mx, my) in mark:
            rows.setdefault(my, []).append(mx)
        for yy, xs in rows.items():
            bx = (min(xs) - 1) if near_front else (max(xs) + 1)
            ox = bx - 1 if near_front else bx + 1
            if 0 <= bx < GW and 0 <= ox < GW and 0 <= yy < GH \
                    and g.d[yy][bx] in LEGC and g.d[yy][ox] in LEGC:
                g.px(bx, yy, 'O')
    return hr


def torso_up(g, bob, swing, dx=0, skip=None):
    y = SHIRT_Y + bob
    g.rect(28 + dx, y - NECK_H, 35 + dx, y - 1, 'S')            # 목덜미
    g.rect(21 + dx, y, 42 + dx, y + 11, 'b')
    g.rect(22 + dx, y + 12, 41 + dx, y + 23, 'b')
    g.rect(21 + dx, y, 42 + dx, y + 1, 'B')                     # 어깨 그늘
    g.rect(22 + dx, y + 22, 41 + dx, y + 23, 'B')
    g.rect(23 + dx, y + 2, 24 + dx, y + 20, 'L')
    g.rect(39 + dx, y + 12, 40 + dx, y + 21, 'B')
    g.rect(26 + dx, y + 12, 37 + dx, y + 12, 'B')               # 등판 주름
    for cx in (21 + dx, 42 + dx):
        g.px(cx, y, '.')
    for cx in (22 + dx, 41 + dx):
        g.px(cx, y + 23, '.')
    for sx, sw, side in ((ARM_L, -swing, 'left'), (ARM_R, swing, 'right')):
        if side == skip:
            continue
        sx += dx
        dy = (2 if sw >= 4 else 0) + (2 if sw >= 6 else 0) \
            - (2 if sw <= -4 else 0) - (2 if sw <= -6 else 0)
        g.rect(sx, y + 1, sx + 5, y + 11 + dy, 'b')
        if side == 'left':
            g.rect(sx, y + 1, sx, y + 11 + dy, 'L')
        else:
            g.rect(sx + 5, y + 1, sx + 5, y + 11 + dy, 'B')
        g.rect(sx, y + 12 + dy, sx + 5, y + 13 + dy, 'B')
        g.rect(sx, y + 14 + dy, sx + 5, y + 18 + dy, 's')
        g.rect(sx + 1, y + 18 + dy, sx + 4, y + 18 + dy, 'S')
        out = sx if side == 'left' else sx + 5
        inn = sx + 5 if side == 'left' else sx
        g.px(out, y + 1, '.')
        for cx in (sx, sx + 5):
            g.px(cx, y + 18 + dy, '.'); g.px(cx, y + 14 + dy, '.')
        g.vline(inn, y + ARMPIT, y + 13 + dy, 'O')


def legs_up(g, stride, dx=0, sq=0, pass_leg=0):
    legs_down(g, stride, dx, sq, pass_leg)


# --------------------------------------------------------------- 휘두르기
# 방향당 5장: 감기 시작 · 다 감음 · 휘두름 · 내리침 · 되돌아옴.
# 도구는 게임(player.gd)이 주먹 자리에 얹으므로 여기서는 몸+팔만 그린다.
#   fist    주먹 6x6 블록의 왼쪽 위
#   elbow   팔꿈치 (어깨-주먹 직선 바깥으로)
#   dx      몸이 쏠리는 방향   sq  주저앉는 양   behind  팔을 머리 뒤에
SWING_N = 5
SWING = {
    'down': {'skip': 'left', 'shoulder': (16, 48),
             'poses': [((8, 38), (8, 44), -2, 0, False),
                       ((4, 20), (2, 34), -4, 0, False),
                       ((0, 38), (6, 44), -2, 0, False),
                       ((16, 62), (16, 56), 0, 4, False),
                       ((8, 42), (8, 46), 0, 0, False)]},
    'up':   {'skip': 'right', 'shoulder': (42, 48),
             'poses': [((50, 34), (54, 40), 2, 0, False),
                       ((50, 18), (56, 32), 4, 0, False),
                       ((38, 1), (50, 18), 0, 0, True),
                       ((32, 14), (40, 26), 0, 4, True),
                       ((50, 28), (54, 36), 0, 0, False)]},
    'side': {'skip': None, 'shoulder': (30, 48),
             'poses': [((10, 34), (14, 42), -4, 0, False),
                       ((7, 20), (10, 34), -6, 0, False),
                       ((52, 26), (40, 40), 4, 2, False),
                       ((48, 66), (46, 58), 6, 2, False),
                       ((46, 54), (36, 54), 4, 0, False)],
             'legs': [((0.6, 22, 6, 0), (-0.6, -20, 6, -1)),
                      ((0.8, 26, 8, 1), (-0.8, -24, 14, -1)),
                      ((0.4, 20, 24, 0), (-0.4, -22, 10, -1)),
                      ((0.6, 34, 58, 0), (-1.0, -30, 16, -1)),
                      ((0.4, 22, 18, 0), (-0.6, -20, 10, -1))],
             'far_arm': [6, 10, 2, -8, -4]},
}
FIST = 6


def arm_stroke(g, x0, y0, fx, fy, ex, ey):
    """어깨에서 팔꿈치를 거쳐 주먹까지 6칸 굵기로 팔을 긋는다."""
    cells = set()
    for (ax, ay), (bx, by) in (((x0, y0), (ex, ey)), ((ex, ey), (fx, fy))):
        steps = max(abs(bx - ax), abs(by - ay), 1)
        for i in range(steps + 1):
            t = i / steps
            x, y = round(ax + (bx - ax) * t), round(ay + (by - ay) * t)
            for ddx in range(FIST):
                for ddy in range(FIST):
                    cells.add((x + ddx, y + ddy))
    hand = {(fx + i, fy + j) for i in range(FIST) for j in range(FIST)}
    for cx, cy in ((fx, fy), (fx + FIST - 1, fy), (fx, fy + FIST - 1), (fx + FIST - 1, fy + FIST - 1)):
        hand.discard((cx, cy)); cells.discard((cx, cy))       # 주먹 모서리 깎기
    cells |= hand
    SHIRT = ('b', 'B', 'L')
    for (x, y) in cells:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) in cells or not (0 <= nx < GW and 0 <= ny < GH):
                continue
            if (x, y) not in hand and g.d[ny][nx] in SHIRT:
                continue
            if g.d[ny][nx] != '.':
                g.d[ny][nx] = 'O'
    for (x, y) in cells:
        if (x, y) in hand:
            g.px(x, y, 's')
        else:
            near = any((x + mx, y + my) in hand for mx in (-2, -1, 0, 1, 2) for my in (-2, -1, 0, 1, 2))
            if not near and g.d[y][x] in SHIRT:
                continue
            g.px(x, y, 'B' if near else 'b')
    for (x, y) in hand:                                         # 주먹 그늘 (오른쪽 아래)
        if x >= fx + 3 and y >= fy + 3:
            g.px(x, y, 'S')


def swing_frame(direction, phase, art):
    spec = SWING[direction]
    (fx, fy), (ex, ey), dx, sq, behind = spec['poses'][phase]
    g = G()
    if direction == 'side':
        hr = legs_side(g, 0, 0, dx, sq, poses=spec['legs'][phase])
        sq = hr - (HIP_Y + 4)
        torso_side(g, sq, 0, dx, draw_arm=False, far_arm=spec['far_arm'][phase])
    elif direction == 'down':
        counter = (-2, -4, 0, 4, 2)[phase]
        step = (0, 2, 2, 0, 0)[phase]
        legs_down(g, step, dx, sq)
        torso_down(g, sq, counter, dx, skip=spec['skip'])
    else:
        legs_up(g, 0, dx, sq)
        torso_up(g, sq, 0, dx, skip=spec['skip'])
    sx, sy = spec['shoulder']
    hb = sq + (2 if phase == 3 else 0)          # 내리치는 칸은 머리를 움츠린다
    if behind:
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
        head(g, art, hb, dx)
    else:
        head(g, art, hb, dx)
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
    roughen(g)
    g.outline()
    return g


def hand_dot(direction, phase):
    """player.gd SWING_HAND_DOT — 주먹 블록 한가운데의 node 좌표.
    도트 원점은 발밑 가운데(픽셀 64,190), node = 그림의 절반 크기."""
    (fx, fy), _, _, _, _ = SWING[direction]['poses'][phase]
    dot_x = PAD_X + fx * SCALE + FIST - 64
    dot_y = fy * SCALE + FIST - 190
    return (round(dot_x / 2.0 * 10) / 10, round((dot_y + 2) / 2.0 * 10) / 10)


# ------------------------------------------------------------------- 결
# 옷·바지에 성근 얼룩을 흩어 짜인 천의 결을 낸다 — 2x2 덩이 바둑판 위에만,
# 덩이 좌표로만 (프레임마다 다시 뽑으면 걸을 때 지글거린다). 살결·신발은 뺀다.
ROUGH_DARK = {'b': 'B', 'p': 'P', 'L': 'b', 'q': 'p'}
ROUGH_LITE = {'b': 'L', 'p': 'q', 'B': 'b', 'P': 'p'}


def _rough_hash(x, y):
    h = (x * 73856093) ^ (y * 19349663)
    h = (h ^ (h >> 13)) & 0x7FFFFFFF
    return ((h * 1274126177) & 0x7FFFFFFF) / 2147483647.0


def roughen(g):
    for y in range(SHIRT_Y, GH):
        for x in range(GW):
            c = g.d[y][x]
            if c in ('.', 'O'):
                continue
            bx, by = x // 2, y // 2
            if (bx + by) % 2:
                continue
            depth = (y - SHIRT_Y) / max(1, GH - SHIRT_Y)
            r = _rough_hash(bx, by)
            if r < 0.12 + depth * 0.12 and c in ROUGH_DARK:
                g.d[y][x] = ROUGH_DARK[c]
            elif r < 0.22 and c in ROUGH_LITE:
                g.d[y][x] = ROUGH_LITE[c]


BODY = {
    'down': (torso_down, legs_down),
    'side': (torso_side, legs_side),
    'up':   (torso_up, legs_up),
}


def frame(direction, art, phase=None, bob=0):
    torso, legs = BODY[direction]
    g = G()
    if direction == 'side':
        lean = 0 if phase is None else 2
        hip = 0 if phase is None else HIP[phase % WALK]
        if phase is not None:
            bob = round(hip_row_at(phase) - (HIP_Y + 4))
        arm = None if phase is None else ARM[phase % WALK]
        legs(g, 0, lean, 0, bob, phase, hip)
        torso(g, bob, 0, lean, arm=arm)
        head(g, art, bob, lean)
    else:
        sf = 0 if phase is None else STRIDE_F[phase % WALK]
        pl = 0 if phase is None else PASS[phase % WALK]
        legs(g, sf, 0, bob, pl)
        torso(g, bob, sf)
        head(g, art, bob)
    roughen(g)
    g.outline()
    return g


# ------------------------------------------------------- 네 벌 생성
OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))


def head_set(hair, female, ears):
    return {
        'down': make_head('down', hair, False, female, ears),
        'side': make_head('side', hair, False, female, ears),
        'up': make_head('up', hair, False, female, ears),
        'down_blink': make_head('down', hair, True, female, ears),
        'side_blink': make_head('side', hair, True, female, ears),
    }


SETS = [
    ('', 'new_boy_', head_set(None, False, True)),
    ('short_', 'hair_short_', head_set('short', False, True)),
    ('spiky_', 'hair_spiky_', head_set('spiky', False, True)),
    ('f_', 'player_f_', head_set('long', True, False)),
]


def render_set(heads, ref_prefix, out_prefix):
    images = {}
    for d in ('down', 'side', 'up'):
        images[f'{d}_idle'] = frame(d, heads[d]).render()
        for i in range(WALK):
            images[f'{d}_walk_{i}'] = frame(d, heads[d], i, BOB[i]).render()
        for i in range(SWING_N):
            images[f'{d}_swing_{i}'] = swing_frame(d, i, heads[d]).render()
    for d in ('down', 'side'):
        images[f'{d}_blink'] = frame(d, heads[f'{d}_blink']).render()
    for k, im in images.items():
        im.save(os.path.join(REF, f'{ref_prefix}{k}.png'))
        im.save(os.path.join(OUT, f'{out_prefix}{k}.png'))
    return images


if __name__ == '__main__':
    ALL = [(render_set(h, rp, op), rp) for rp, op, h in SETS]

    print('SWING_HAND_DOT (player.gd):')
    for d in ('side', 'down', 'up'):
        pts = ', '.join('Vector2(%g, %g)' % hand_dot(d, i) for i in range(SWING_N))
        print('  "%s": [%s],' % (d, pts))

    # ------------------------------------------------------------- 확인용 그림
    CHECK = ((58, 58, 58), (38, 38, 38))
    SAND = (219, 172, 102)

    def strip(images, name, keys, z=2):
        im = Image.new('RGB', (FW * len(keys) * z, FH * z))
        px = im.load()
        for i, k in enumerate(keys):
            fim = images[k].load()
            for y in range(FH * z):
                for x in range(FW * z):
                    sx, sy = x // z, y // z
                    c = fim[sx, sy]
                    if c[3] == 0:
                        c = CHECK[((sx // 12) + (sy // 12)) % 2]
                    px[i * FW * z + x, y] = c[:3]
        im.save(os.path.join(REF, name))

    def gif(images, name, keys, ms=125):
        ims = []
        for k in keys:
            base = Image.new('RGBA', (FW, FH), SAND + (255,))
            base.alpha_composite(images[k])
            ims.append(base.convert('RGB').convert('P', palette=Image.ADAPTIVE))
        ims[0].save(os.path.join(REF, name), save_all=True, append_images=ims[1:],
                    duration=ms, loop=0)

    for images, tag in ALL:
        strip(images, f'preview_{tag}idle.png', ['down_idle', 'side_idle', 'up_idle'])
        for d in ('down', 'side', 'up'):
            keys = [f'{d}_walk_{i}' for i in range(WALK)]
            strip(images, f'preview_{tag}{d}_walk.png', keys)
            gif(images, f'anim_{tag}{d}_walk.gif', keys)
            sw = [f'{d}_swing_{i}' for i in range(SWING_N)]
            strip(images, f'preview_{tag}{d}_swing.png', sw)
            gif(images, f'anim_{tag}{d}_swing.gif', sw, ms=170)
        gif(images, f'anim_{tag}idle.gif', ['down_idle', 'side_idle', 'up_idle'], ms=600)

    faces = []
    for images, tag in ALL:
        faces += [images['down_idle'], images['down_blink'], images['side_idle'], images['up_idle']]
    sheet = Image.new('RGB', (FW * 2 * len(faces), FH * 2))
    for i, fim in enumerate(faces):
        base = Image.new('RGBA', (FW, FH), SAND + (255,))
        base.alpha_composite(fim)
        sheet.paste(base.convert('RGB').resize((FW * 2, FH * 2), Image.NEAREST), (i * FW * 2, 0))
    sheet.save(os.path.join(REF, 'preview_faces.png'))
    print('done: %d frames x %d sets + previews + gifs (sprites/에 설치됨)'
          % (len(ALL[0][0]), len(ALL)))
