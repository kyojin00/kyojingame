# -*- coding: utf-8 -*-
# 도트 소년(dot_boy) 스프라이트 생성기 — 참고 그림(민머리·파란 셔츠·갈색 바지)을
# 굵은 도트로 **코드가 직접 그린다** (앞 세대들은 AI 시트를 잘라 썼다).
#
# 논리 해상도 21x32 를 6배로 키워 게임 규격 128x192 에 맞춘다
# (가로 126 이라 좌우 1px 여백). 발바닥은 논리 31행 = 실제 186~191행,
# 게임의 FOOT_Y(190) 안에 들어간다.
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
    's': (240, 166, 128),   # 살결
    'S': (211, 125, 92),    # 살결 그늘
    'H': (249, 196, 158),   # 살결 하이라이트
    'e': (66, 32, 30),      # 눈
    'm': (170, 84, 66),     # 입
    'b': (62, 96, 186),     # 셔츠
    'B': (40, 62, 136),     # 셔츠 그늘
    'L': (100, 138, 220),   # 셔츠 밝은 면
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
HEAD_Y = 3               # 머리 꼭대기
NECK_Y = 15              # 목 (살결 1행)
SHIRT_Y = 16             # 셔츠 위
HIP_Y = 23               # 바지 위 (엉덩이 띠 2행)
LEG_Y = 25               # 다리 기둥 시작
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
# 방향마다 한 장을 그려 두고 bob 만큼 통째로 내린다. 폭 11 (열 5~15),
# 높이 12 (행 3~14). 민머리라 정수리에 하이라이트를 얹는다.

HEAD_DOWN = [
    "..OOOOOOO..",
    ".OsHHHHHsO.",
    "OssHHHHHssO",
    "OsssssssssO",
    "OsssssssssO",
    "OseessseesO",
    "OseessseesO",
    "OseessseesO",
    "OsssssssssO",
    "OSssmmsssSO",
    ".OsssssssO.",
    "..OOsssOO..",
]

HEAD_SIDE = [   # 오른쪽을 본다
    "..OOOOOOO..",
    ".OsHHHHHsO.",
    "OSsHHHHHssO",
    "OSssssssssO",
    "OSssssssssO",
    "OSssssssssO",
    "OssSssssesO",
    "OssSssssesO",
    "OssSssssesO",
    "OSsssssmssO",
    ".OsssssssO.",
    "..OOsssOO..",
]

HEAD_UP = [
    "..OOOOOOO..",
    ".OsHHHHHsO.",
    "OssHHHHHssO",
    "OsssssssssO",
    "OsssssssssO",
    "OsssssssssO",
    "OsssssssssO",
    "OsssssssssO",
    "OsssssssssO",
    "OSsssssssSO",
    ".OSsssssSO.",
    "..OOSSSOO..",
]

HEAD_X = 5


def head(g, art, bob, lean=0):
    g.blit(art, HEAD_X + lean, HEAD_Y + bob)


# ------------------------------------------------------------------- 몸통
# bob 은 머리·몸통·팔에만 적용하고 다리는 늘 땅을 밟는다.

def torso_down(g, bob, swing):
    """앞모습 몸통+팔. swing: 화면 왼쪽 팔이 앞으로 나간 양 -2..+2"""
    y = SHIRT_Y + bob
    g.rect(9, y - 1, 11, y - 1, 's')           # 목
    g.rect(7, y, 13, y + 6, 'b')               # 몸판
    g.hline(7, 13, y + 6, 'B')                 # 아랫단 그늘
    g.vline(7, y, y + 5, 'L')                  # 빛 받는 왼쪽 면
    g.px(8, y, 'L')
    g.px(10, y + 1, 'B'); g.px(10, y + 2, 'B')  # 앞섶 선
    # 팔: 소매 2픽셀 폭 + 두 칸 손. 앞으로 흔들면 소매가 늘어나며 1px 내려가고
    # 뒤로 가면 접히며 올라간다 — 어깨는 늘 몸통에 붙어 있다.
    for sx, sw in ((5, swing), (14, -swing)):
        dy = (1 if sw >= 2 else 0) - (1 if sw <= -2 else 0)
        g.rect(sx, y + 1, sx + 1, y + 2 + dy, 'b')
        g.vline(5 if sx == 5 else 15, y + 1, y + 2 + dy, 'L' if sx == 5 else 'B')
        g.rect(sx, y + 3 + dy, sx + 1, y + 3 + dy, 'B')          # 소매단
        g.rect(sx, y + 4 + dy, sx + 1, y + 5 + dy, 's')          # 손
        g.px(sx + (0 if sx == 14 else 1), y + 5 + dy, 'S')       # 손 그늘


def legs_down(g, stride):
    """앞모습 다리. stride: 화면 왼쪽 다리가 앞으로 나간 양 -2..+2"""
    g.rect(7, HIP_Y, 13, HIP_Y + 1, 'p')       # 엉덩이 띠
    g.px(10, HIP_Y + 1, 'P')
    for x0, s in ((7, stride), (11, -stride)):
        lift = min(2, -s) if s < 0 else 0      # 뒤로 간 다리는 들려 짧아진다
        pc = 'P' if lift else 'p'              # 들린 다리는 그늘에 잠긴다
        g.rect(x0, LEG_Y, x0 + 2, GROUND - 3 - lift, pc)
        g.px(x0 + 2, LEG_Y, 'P')
        g.px(x0 + 2, LEG_Y + 1, 'P')
        g.rect(x0, GROUND - 2 - lift, x0 + 2, GROUND - lift, 'k')
        g.hline(x0, x0 + 2, GROUND - lift, 'K')


def torso_side(g, bob, swing, lean=0):
    """옆모습 몸통+팔(오른쪽 보기). swing: 팔이 앞으로 나간 양 -2..+2"""
    y = SHIRT_Y + bob
    c = 10 + lean                              # 몸 중심
    g.rect(c - 1, y - 1, c + 1, y - 1, 's')    # 목
    g.rect(c - 3, y, c + 3, y + 6, 'b')
    g.hline(c - 3, c + 3, y + 6, 'B')
    g.vline(c + 3, y, y + 5, 'L')              # 앞면이 밝다
    g.vline(c - 3, y, y + 5, 'B')              # 등쪽 그늘
    # 보이는 팔 하나 — 어깨에서 손까지 진자처럼 젓는다. 몸판과 구분되게 그늘색.
    hy = y + 4 - (1 if abs(swing) >= 2 else 0)   # 손이 시작하는 행
    for yy in range(y + 1, hy):
        t = (yy - (y + 1)) / max(1, hy - 1 - (y + 1))
        x = c - 1 + round(swing * t)
        g.rect(x, yy, x + 1, yy, 'B')          # 소매 2픽셀 폭
    g.rect(c - 1 + swing, hy, c + swing, hy + 1, 's')            # 손
    g.px(c + swing, hy + 1, 'S')


def legs_side(g, stride, lean=0):
    """옆모습 다리. stride: 가까운 다리가 앞으로 나간 양 -2..+2
    허벅지는 엉덩이에 붙어 있고 발끝으로 갈수록 stride 만큼 기울어진다."""
    c = 10 + lean
    g.rect(c - 3, HIP_Y, c + 3, HIP_Y + 1, 'p')
    g.px(c - 1, HIP_Y + 1, 'P')
    # 먼 다리를 그늘색으로 먼저, 가까운 다리를 위에 얹는다
    for off, shade in ((-stride, True), (stride, False)):
        lift = 1 if off < 0 else 0             # 뒤로 간 다리는 뒤꿈치가 들린다
        pc, kc = ('P', 'K') if shade else ('p', 'k')
        bot = GROUND - lift
        for yy in range(LEG_Y, bot + 1):
            t = (yy - (HIP_Y + 1)) / (GROUND - HIP_Y - 1)   # 엉덩이 0 → 발 1
            x = 10 + round(off * t) + lean
            cc = pc if yy <= bot - 3 else kc
            g.rect(x - 1, yy, x + 1, yy, cc)
        x = 10 + off + lean
        if off > 0:
            g.px(x + 2, bot, kc)               # 앞으로 디딘 발끝
        elif off < 0:
            g.px(x - 2, bot, kc)               # 뒤로 차는 뒤꿈치


def torso_up(g, bob, swing):
    y = SHIRT_Y + bob
    g.rect(9, y - 1, 11, y - 1, 'S')           # 목덜미
    g.rect(7, y, 13, y + 6, 'b')
    g.hline(7, 13, y, 'B')                     # 어깨 그늘
    g.hline(7, 13, y + 6, 'B')
    g.vline(7, y, y + 5, 'L')
    for sx, sw in ((5, -swing), (14, swing)):  # 뒤모습이라 팔 위상이 좌우 반대
        dy = (1 if sw >= 2 else 0) - (1 if sw <= -2 else 0)
        g.rect(sx, y + 1, sx + 1, y + 2 + dy, 'b')
        g.vline(5 if sx == 5 else 15, y + 1, y + 2 + dy, 'L' if sx == 5 else 'B')
        g.rect(sx, y + 3 + dy, sx + 1, y + 3 + dy, 'B')
        g.rect(sx, y + 4 + dy, sx + 1, y + 5 + dy, 's')
        g.px(sx + (0 if sx == 14 else 1), y + 5 + dy, 'S')


def legs_up(g, stride):
    legs_down(g, stride)                       # 뒤모습 다리는 앞모습과 같은 규칙


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
gif('anim_idle.gif', ['down_idle', 'side_idle', 'up_idle'], ms=600)

print('done: 18 frames + previews + gifs')
