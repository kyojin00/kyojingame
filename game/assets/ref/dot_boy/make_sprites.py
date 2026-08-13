# -*- coding: utf-8 -*-
# 도트 소년(dot_boy) 스프라이트 생성기 — 참고 그림(민머리·파란 셔츠·갈색 바지)을
# 굵은 도트로 **코드가 직접 그린다** (앞 세대들은 AI 시트를 잘라 썼다).
#
# 논리 해상도 21x32 를 6배로 키워 게임 규격 128x192 에 맞춘다
# (가로 126 이라 좌우 1px 여백). 발바닥은 논리 31행 = 실제 186~191행,
# 게임의 FOOT_Y(190) 안에 들어간다.
#
# 귀여운 비율: 머리가 키의 절반 가까이 되는 돔형 대두(13x14)에
# 몸통 6행 + 짧은 다리. 참고 그림의 등신에 맞춘 값이다.
#
# 프레임: 방향(down/side/up)마다 idle 1장 + walk 5장 (게임이 int(t*8)%5 로 돌린다).
# 걷기 5장은 사인 곡선을 5등분한 위상 [0, +2, +1, -1, -2] 로 다리를 놓아
# 마지막 장에서 첫 장으로 자연스럽게 이어진다.
#
# 실행:  python3 make_sprites.py     (Pillow 필요)
# 출력:  이 폴더에 프레임 png + preview_*.png(필름 스트립) + anim_*.gif
import os
from PIL import Image

REF = os.path.dirname(os.path.abspath(__file__))

SCALE = 6
GW, GH = 21, 32          # 논리 캔버스
FW, FH = 128, 192        # 게임 스프라이트 규격
PAD_X = (FW - GW * SCALE) // 2

PAL = {
    'O': (54, 33, 26),      # 윤곽선
    's': (243, 159, 138),   # 살결 (참고 그림처럼 분홍기가 돈다)
    'S': (213, 116, 98),    # 살결 그늘
    'H': (250, 192, 170),   # 살결 하이라이트
    'e': (66, 32, 30),      # 눈동자·눈썹
    'i': (136, 70, 42),     # 홍채 (눈동자 위쪽의 밝은 갈색)
    'w': (246, 242, 234),   # 흰자
    'r': (235, 128, 114),   # 볼터치
    'm': (170, 84, 66),     # 입
    'b': (58, 88, 168),     # 셔츠
    'B': (38, 58, 120),     # 셔츠 그늘
    'L': (94, 126, 200),    # 셔츠 밝은 면
    'p': (134, 88, 46),     # 바지
    'P': (98, 62, 32),      # 바지 그늘
    'k': (82, 53, 33),      # 신발
    'K': (56, 37, 25),      # 신발 그늘
}

WALK = 5
# 오른다리 앞으로 나간 양 (논리 px). 사인 5등분 — 끝에서 처음으로 매끄럽게 돈다.
STRIDE = [0, 2, 1, -1, -2]
# 몸통이 내려앉는 양. 다리가 벌어진 칸에서 낮고(1) 모인 칸에서 높다(0).
BOB = [0, 1, 0, 0, 1]

# 세로 배치 (bob 적용 전 기준 행)
HEAD_Y = 2               # 머리 꼭대기
SHIRT_Y = 16             # 셔츠 위 (목은 그 한 행 위)
HIP_Y = 22               # 바지 위 (엉덩이 띠 2행)
LEG_Y = 24               # 다리 기둥 시작
GROUND = 31              # 디딘 발바닥 행


class G:
    """논리 캔버스. 문자(팔레트 키)로 칠한다."""
    def __init__(self):
        self.d = [['.'] * GW for _ in range(GH)]

    def px(self, x, y, c):
        if 0 <= x < GW and 0 <= y < GH:
            self.d[y][x] = c

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
# 방향마다 한 장을 그려 두고 bob 만큼 통째로 내린다. 폭 13 (열 4~16),
# 높이 14 (행 2~15) — 키의 절반 가까운 돔형 대두. 민머리라 정수리 하이라이트.

HEAD_DOWN = [
    "....OOOOO....",
    "..OOsssssOO..",
    ".OssHHHHHssO.",
    ".OsHHHHHHHsO.",
    "OssHHHHHHHssO",
    "OsssssssssssO",
    "OsssssssssssO",
    "OseeessseeesO",
    "OswiwssswiwsO",
    "OswewssswewsO",
    "OssSsssssSssO",
    "OrsssmsmsssrO",
    ".OssssmssssO.",
    "..OOsssssOO..",
]

HEAD_SIDE = [   # 오른쪽을 본다
    "....OOOOO....",
    "..OOsssssOO..",
    ".OSsHHHHHssO.",
    ".OSHHHHHHHsO.",
    "OSssssssssssO",
    "OSssssssssssO",
    "OSssssssssssO",
    "OsssssssseesO",
    "OsssssssswisO",
    "OsssssssswesO",
    "OSssssssssssO",
    "OSsssrsssmmsO",
    ".OssssssssSO.",
    "..OOsssssOO..",
]

HEAD_UP = [
    "....OOOOO....",
    "..OOsssssOO..",
    ".OssHHHHHssO.",
    ".OsHHHHHHHsO.",
    "OssHHHHHHHssO",
    "OsssssssssssO",
    "OsssssssssssO",
    "OsssssssssssO",
    "OsssssssssssO",
    "OsssssssssssO",
    "OSsssssssssSO",
    "OSsssssssssSO",
    ".OSsssssssSO.",
    "..OOSSSSSOO..",
]

HEAD_X = 4


def head(g, art, bob, lean=0):
    g.blit(art, HEAD_X + lean, HEAD_Y + bob)


# ------------------------------------------------------------------- 몸통
# bob 은 머리·몸통·팔에만 적용하고 다리는 늘 땅을 밟는다.

def torso_down(g, bob, swing, dx=0, skip=None):
    """앞모습 몸통+팔. swing: 화면 왼쪽 팔이 앞으로 나간 양 -2..+2
    dx: 휘두르기용 좌우 쏠림. skip: 'left'/'right' 팔을 안 그린다 (휘두르는 팔)"""
    y = SHIRT_Y + bob
    g.rect(9 + dx, y - 1, 11 + dx, y - 1, 's')  # 목
    g.rect(7 + dx, y, 13 + dx, y + 5, 'b')      # 몸판
    g.hline(7 + dx, 13 + dx, y + 5, 'B')        # 아랫단 그늘
    g.vline(8 + dx, y, y + 4, 'L')              # 빛 받는 왼쪽 면
    g.vline(7 + dx, y + 1, y + 4, 'B')          # 팔과 몸 사이 솔기
    g.vline(13 + dx, y + 1, y + 4, 'B')
    g.hline(9 + dx, 11 + dx, y, 'B')            # 옷깃 (목 아래 그늘)
    g.px(10 + dx, y + 1, 'B'); g.px(10 + dx, y + 2, 'B')  # 앞섶 선
    # 팔: 소매 2픽셀 폭 + 두 칸 손. 앞으로 흔들면 소매가 늘어나며 1px 내려가고
    # 뒤로 가면 접히며 올라간다 — 어깨는 늘 몸통에 붙어 있다.
    for sx, sw, side in ((5, swing, 'left'), (14, -swing, 'right')):
        if side == skip:
            continue
        sx += dx
        dy = (1 if sw >= 2 else 0) - (1 if sw <= -2 else 0)
        g.rect(sx, y + 1, sx + 1, y + 2 + dy, 'b')
        g.vline(sx if side == 'left' else sx + 1, y + 1, y + 2 + dy,
                'L' if side == 'left' else 'B')
        g.rect(sx, y + 3 + dy, sx + 1, y + 3 + dy, 'B')          # 소매단
        g.rect(sx, y + 4 + dy, sx + 1, y + 5 + dy, 's')          # 손
        g.px(sx + (1 if side == 'left' else 0), y + 5 + dy, 'S')  # 손 그늘


def legs_down(g, stride, dx=0, sq=0):
    """앞모습 다리. stride: 화면 왼쪽 다리가 앞으로 나간 양 -2..+2
    dx/sq: 휘두르기 때 몸이 쏠리고 주저앉는 양 — 엉덩이는 몸통을 따라가고
    발은 디딘 자리에 남아, 다리가 엉덩이에서 발로 기울어진다."""
    g.rect(7 + dx, HIP_Y + sq, 13 + dx, HIP_Y + 1 + sq, 'p')   # 엉덩이 띠
    g.hline(7 + dx, 13 + dx, HIP_Y + sq, 'P')  # 셔츠 아랫단 그늘
    g.px(10 + dx, HIP_Y + 1 + sq, 'P')
    for x0, s in ((7, stride), (11, -stride)):
        lift = min(2, -s) if s < 0 else 0      # 뒤로 간 다리는 들려 짧아진다
        pc = 'P' if lift else 'p'              # 들린 다리는 그늘에 잠긴다
        top = LEG_Y + sq
        for yy in range(top, GROUND - 2 - lift):
            t = (yy - (HIP_Y + 1 + sq)) / (GROUND - HIP_Y - 1 - sq)
            xx = x0 + round(dx * (1 - t))      # 엉덩이 쪽만 dx만큼 쏠린다
            g.rect(xx, yy, xx + 2, yy, pc)
            if yy == top:
                g.px(xx + 2, yy, 'P')
        g.rect(x0, GROUND - 2 - lift, x0 + 2, GROUND - lift, 'k')
        g.hline(x0, x0 + 2, GROUND - lift, 'K')


def torso_side(g, bob, swing, lean=0, draw_arm=True):
    """옆모습 몸통+팔(오른쪽 보기). swing: 팔이 앞으로 나간 양 -2..+2"""
    y = SHIRT_Y + bob
    c = 10 + lean                              # 몸 중심
    g.rect(c - 1, y - 1, c + 1, y - 1, 's')    # 목
    g.rect(c - 3, y, c + 3, y + 5, 'b')
    g.hline(c - 3, c + 3, y + 5, 'B')
    g.vline(c + 3, y, y + 4, 'L')              # 앞면이 밝다
    g.vline(c - 3, y, y + 4, 'B')              # 등쪽 그늘
    if not draw_arm:
        return
    # 보이는 팔 하나 — 어깨에서 손까지 진자처럼 젓는다.
    # 몸판과 같은 파랑이라 소매 둘레에 윤곽선을 직접 둘러 뗀다.
    hy = y + 4 - (1 if abs(swing) >= 2 else 0)   # 손이 시작하는 행
    for yy in range(y + 1, hy):
        t = (yy - (y + 1)) / max(1, hy - 1 - (y + 1))
        x = c - 1 + round(swing * t)
        g.px(x - 1, yy, 'O')
        if yy == hy - 1:
            g.rect(x, yy, x + 1, yy, 'B')        # 소매단
        else:
            g.px(x, yy, 'B')                     # 소매 뒷면 그늘
            g.px(x + 1, yy, 'L')                 # 소매 앞면 빛
        g.px(x + 2, yy, 'O')
    hx = c - 1 + swing
    g.px(hx - 1, hy, 'O'); g.px(hx + 2, hy, 'O')                 # 손 둘레
    g.rect(hx, hy, hx + 1, hy + 1, 's')                          # 손
    g.px(hx + 1, hy + 1, 'S')


def legs_side(g, stride, lean=0, dx=0, sq=0):
    """옆모습 다리. stride: 가까운 다리가 앞으로 나간 양 -2..+2
    허벅지는 엉덩이에 붙어 있고 발끝으로 갈수록 stride 만큼 기울어진다.
    dx/sq: 휘두르기 쏠림·주저앉음 (엉덩이만 따라가고 발은 제자리)."""
    c = 10 + lean
    g.rect(c - 3 + dx, HIP_Y + sq, c + 3 + dx, HIP_Y + 1 + sq, 'p')
    g.hline(c - 3 + dx, c + 3 + dx, HIP_Y + sq, 'P')   # 셔츠 아랫단 그늘
    g.px(c - 1 + dx, HIP_Y + 1 + sq, 'P')
    # 먼 다리를 그늘색으로 먼저, 가까운 다리를 위에 얹는다
    for off, shade in ((-stride, True), (stride, False)):
        lift = 1 if off < 0 else 0             # 뒤로 간 다리는 뒤꿈치가 들린다
        pc, kc = ('P', 'K') if shade else ('p', 'k')
        bot = GROUND - lift
        for yy in range(LEG_Y + sq, bot + 1):
            t = (yy - (HIP_Y + 1 + sq)) / (GROUND - HIP_Y - 1 - sq)  # 엉덩이 0 → 발 1
            x = 10 + round(off * t + dx * (1 - t)) + lean
            cc = pc if yy <= bot - 3 else kc
            g.rect(x - 1, yy, x + 1, yy, cc)
        x = 10 + off + lean
        if off > 0:
            g.px(x + 2, bot, kc)               # 앞으로 디딘 발끝
        elif off < 0:
            g.px(x - 2, bot, kc)               # 뒤로 차는 뒤꿈치


def torso_up(g, bob, swing, dx=0, skip=None):
    y = SHIRT_Y + bob
    g.rect(9 + dx, y - 1, 11 + dx, y - 1, 'S')  # 목덜미
    g.rect(7 + dx, y, 13 + dx, y + 5, 'b')
    g.hline(7 + dx, 13 + dx, y, 'B')            # 어깨 그늘
    g.hline(7 + dx, 13 + dx, y + 5, 'B')
    g.vline(8 + dx, y + 1, y + 4, 'L')
    g.vline(7 + dx, y + 1, y + 4, 'B')          # 팔과 몸 사이 솔기
    g.vline(13 + dx, y + 1, y + 4, 'B')
    for sx, sw, side in ((5, -swing, 'left'), (14, swing, 'right')):
        if side == skip:                        # 뒤모습이라 팔 위상이 좌우 반대
            continue
        sx += dx
        dy = (1 if sw >= 2 else 0) - (1 if sw <= -2 else 0)
        g.rect(sx, y + 1, sx + 1, y + 2 + dy, 'b')
        g.vline(sx if side == 'left' else sx + 1, y + 1, y + 2 + dy,
                'L' if side == 'left' else 'B')
        g.rect(sx, y + 3 + dy, sx + 1, y + 3 + dy, 'B')
        g.rect(sx, y + 4 + dy, sx + 1, y + 5 + dy, 's')
        g.px(sx + (1 if side == 'left' else 0), y + 5 + dy, 'S')


def legs_up(g, stride, dx=0, sq=0):
    legs_down(g, stride, dx, sq)               # 뒤모습 다리는 앞모습과 같은 규칙


# --------------------------------------------------------------- 휘두르기
# 방향당 4장: 감기 시작 · 다 감음(머리 위) · 내리침 · 되돌아옴.
# 도구는 게임(player.gd)이 주먹 자리에 얹으므로 여기서는 몸+팔만 그린다.
# 주먹 자리는 아래에서 SWING_HAND_DOT 값으로 계산해 찍어 준다 —
# player.gd에 그대로 옮겨 적으면 도구가 손에 붙는다.
#
# 프레임 설계 — 칸마다 (fist, elbow, dx, sq, behind):
#   fist    주먹 2x2 블록의 왼쪽 위 논리 칸
#   elbow   팔꿈치가 오는 논리 칸 — 어깨-주먹 직선에서 바깥으로 뺀 자리.
#           일직선으로 그으면 팔이 막대기처럼 쭉 뻗어 로봇 같다. 감을 때는
#           팔꿈치가 굽어 있다가 내리치는 칸에서 거의 펴지는 게 자연스럽다.
#   dx      몸이 쏠리는 방향 (감을 때 뒤로 갈수록 크게, 내리칠 때 앞으로)
#   sq      주저앉는 양 (내리치는 칸만 1)
#   behind  팔을 머리 뒤에 그린다 — 뒷모습이 머리 **너머로** 내리치는 칸은
#           팔뚝이 머리 저편(=캐릭터의 앞)에 있으니 머리가 가리고 주먹만
#           위로 내민다. 앞에 그리면 팔이 뒤통수를 가로지르는 띠가 된다.
#
# 그 밖의 팔은 **앞에** 그려 어깨부터 주먹까지 다 보이게 한다 — 주먹을
# 머리 꼭대기 한가운데가 아니라 뒤통수 쪽 위로 보내면, 획이 민머리 면만
# 지나가고 눈은 안 덮는다 (앞모습 눈은 5~7열, 옆모습 눈은 12~13열).
# 팔 길이 조심: 걷기 팔이 대여섯 칸이니 어깨-주먹 거리도 그 언저리로 묶는다
# (늘려도 열 칸 안). 「다 감음」의 주먹을 머리 꼭대기 위까지 보내면 팔이
# 몸길이만큼 늘어난다 — 주먹은 **머리 옆면 높이**까지만 올리고, 그 위로는
# 게임이 주먹에 얹는 도구가 뻗어 보인다. (뒷모습 내리침만 예외 — 팔이
# 머리 뒤에 숨어 안 보이니 주먹을 머리 위로 보내도 길이가 안 드러난다.)
SWING = {
    # 앞모습: 왼쪽 위로 감았다가 오른쪽 아래로 내리친다 (옛 도트와 같은 방향)
    'down': {'skip': 'left', 'shoulder': (6, 17),
             'poses': [((3, 13), (3, 15), -1, 0, False),
                       ((3, 7), (1, 12), -2, 0, False),
                       ((14, 19), (10, 16), 1, 1, False),
                       ((13, 18), (9, 16), 0, 0, False)]},
    # 뒷모습: 등을 보이는 캐릭터의 「앞」은 화면 위쪽이다. 내리침이 왼쪽
    # 아래(화면 쪽 = 등 뒤)로 오면 제 뒤를 치는 그림이 된다 — 주먹은
    # 옆에서 감아올려 머리 **너머로** 뻗는다 (도구는 게임이 몸 뒤에 그려
    # 저편(=앞)에 있는 것처럼 보인다).
    'up':   {'skip': 'right', 'shoulder': (14, 17),
             'poses': [((16, 12), (17, 14), 1, 0, False),
                       ((16, 7), (18, 12), 2, 0, False),
                       ((9, 1), (11, 8), -1, 1, True),
                       ((16, 10), (17, 13), 0, 0, False)]},
    # 옆모습(오른쪽 보기): 뒤로 감았다가 앞으로 내리친다
    'side': {'skip': None, 'shoulder': (10, 17),
             'poses': [((4, 12), (5, 15), -1, 0, False),
                       ((4, 8), (4, 12), -2, 0, False),
                       ((16, 23), (15, 20), 2, 1, False),
                       ((15, 19), (12, 19), 1, 0, False)]},
}


def arm_stroke(g, x0, y0, fx, fy, ex=None, ey=None):
    """어깨(x0,y0)에서 (팔꿈치를 거쳐) 주먹 블록(fx,fy)까지 2픽셀 굵기로
    팔을 긋는다. 몸이나 머리 위를 지나가므로 획 둘레를 윤곽선으로 눌러 뗀다."""
    cells = set()
    pts = [(x0, y0)] + ([(ex, ey)] if ex is not None else []) + [(fx, fy)]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        steps = max(abs(bx - ax), abs(by - ay), 1)
        for i in range(steps + 1):
            t = i / steps
            x, y = round(ax + (bx - ax) * t), round(ay + (by - ay) * t)
            for ddx in (0, 1):
                for ddy in (0, 1):
                    cells.add((x + ddx, y + ddy))
    hand = {(fx, fy), (fx + 1, fy), (fx, fy + 1), (fx + 1, fy + 1)}
    cells |= hand
    for (x, y) in cells:                       # 획 둘레 윤곽선
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) in cells or not (0 <= nx < GW and 0 <= ny < GH):
                continue
            if g.d[ny][nx] != '.':
                g.d[ny][nx] = 'O'
    for (x, y) in cells:
        g.px(x, y, 's' if (x, y) in hand else 'b')
    g.px(fx + 1, fy + 1, 'S')                  # 주먹 그늘


def swing_frame(direction, phase):
    spec = SWING[direction]
    (fx, fy), (ex, ey), dx, sq, behind = spec['poses'][phase]
    g = G()
    if direction == 'side':
        # 발은 네 장 내내 같은 자리를 디디고(벌린 자세), 엉덩이·다리 윗동이
        # 몸통을 따라 쏠린다 — 허리가 어긋나지 않고 다리도 같이 움직인다.
        legs_side(g, 2, 0, dx, sq)
        torso_side(g, sq, 0, dx, draw_arm=False)
    elif direction == 'down':
        legs_down(g, 0, dx, sq)
        torso_down(g, sq, 0, dx, skip=spec['skip'])
    else:
        legs_up(g, 0, dx, sq)
        torso_up(g, sq, 0, dx, skip=spec['skip'])
    art = PARTS[direction][0]
    sx, sy = spec['shoulder']
    if behind:
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
        head(g, art, sq, dx)                   # 머리가 팔을 덮고 주먹만 남는다
    else:
        head(g, art, sq, dx)
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
    g.outline()
    return g


def hand_dot(direction, phase):
    """player.gd SWING_HAND_DOT 값 — 주먹 2x2 블록 한가운데의 node 좌표.
    도트 원점은 발밑 가운데(픽셀 64,190), node = 그림의 절반 크기."""
    (fx, fy), _, _, _, _ = SWING[direction]['poses'][phase]
    dot_x = PAD_X + fx * 6 + 6 - 64
    dot_y = fy * 6 + 6 - 190
    return (round(dot_x / 2.0 * 10) / 10, round((dot_y + 2) / 2.0 * 10) / 10)


# ------------------------------------------------------------------- 조립

PARTS = {
    'down': (HEAD_DOWN, torso_down, legs_down),
    'side': (HEAD_SIDE, torso_side, legs_side),
    'up':   (HEAD_UP, torso_up, legs_up),
}


def frame(direction, stride=None, bob=0):
    art, torso, legs = PARTS[direction]
    g = G()
    s = 0 if stride is None else stride
    if direction == 'side':
        lean = 0 if stride is None else 1      # 걸을 때 몸이 살짝 앞으로 쏠린다
        legs(g, s, lean)
        torso(g, bob, s, lean)
        head(g, art, bob, lean)
    else:
        legs(g, s)
        torso(g, bob, s)
        head(g, art, bob)
    g.outline()
    return g


def save(name, g):
    g.render().save(os.path.join(REF, name + '.png'))
    return g


FRAMES = {}
for d in ('down', 'side', 'up'):
    FRAMES[f'{d}_idle'] = save(f'{d}_idle', frame(d))
    for i in range(WALK):
        FRAMES[f'{d}_walk_{i}'] = save(f'{d}_walk_{i}', frame(d, STRIDE[i], BOB[i]))
    for i in range(4):
        FRAMES[f'{d}_swing_{i}'] = save(f'{d}_swing_{i}', swing_frame(d, i))

# 게임에 설치 — 플레이어 텍스처 이름(new_boy_*)으로 sprites/에 복사한다.
OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))
for k, g in FRAMES.items():
    g.render().save(os.path.join(OUT, f'new_boy_{k}.png'))

# player.gd SWING_HAND_DOT에 옮겨 적을 주먹 좌표
print('SWING_HAND_DOT (player.gd):')
for d in ('side', 'down', 'up'):
    pts = ', '.join('Vector2(%g, %g)' % hand_dot(d, i) for i in range(4))
    print('  "%s": [%s],' % (d, pts))


# ----------------------------------------------------------------- 확인용 그림

CHECK = ((58, 58, 58), (38, 38, 38))
SAND = (219, 172, 102)      # 참고 그림의 모랫바닥


def strip(name, keys, z=2):
    im = Image.new('RGB', (FW * len(keys) * z, FH * z))
    px = im.load()
    for i, k in enumerate(keys):
        fim = FRAMES[k].render().load()
        for y in range(FH * z):
            for x in range(FW * z):
                sx, sy = x // z, y // z
                c = fim[sx, sy]
                if c[3] == 0:
                    c = CHECK[((sx // 12) + (sy // 12)) % 2]
                px[i * FW * z + x, y] = c[:3]
    im.save(os.path.join(REF, name))


def gif(name, keys, ms=125):
    ims = []
    for k in keys:
        base = Image.new('RGBA', (FW, FH), SAND + (255,))
        base.alpha_composite(FRAMES[k].render())
        ims.append(base.convert('RGB').convert('P', palette=Image.ADAPTIVE))
    ims[0].save(os.path.join(REF, name), save_all=True, append_images=ims[1:],
                duration=ms, loop=0)


strip('preview_idle.png', ['down_idle', 'side_idle', 'up_idle'])
for d in ('down', 'side', 'up'):
    keys = [f'{d}_walk_{i}' for i in range(WALK)]
    strip(f'preview_{d}_walk.png', keys)
    gif(f'anim_{d}_walk.gif', keys)
    sw = [f'{d}_swing_{i}' for i in range(4)]
    strip(f'preview_{d}_swing.png', sw)
    gif(f'anim_{d}_swing.gif', sw, ms=170)
gif('anim_idle.gif', ['down_idle', 'side_idle', 'up_idle'], ms=600)

print('done: %d frames + previews + gifs (sprites/에 설치됨)' % len(FRAMES))
