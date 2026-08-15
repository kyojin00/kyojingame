# -*- coding: utf-8 -*-
# 도트 소년(dot_boy) 스프라이트 생성기 — 참고 그림(민머리·파란 셔츠·갈색 바지)을
# 굵은 도트로 **코드가 직접 그린다** (앞 세대들은 AI 시트를 잘라 썼다).
#
# 논리 해상도 32x48 을 4배로 키워 게임 규격 128x192 에 꼭 맞춘다.
# (처음엔 21x32의 6배였는데, 도트가 1.5배 촘촘해지며 얼굴·옷 디테일이
# 들어갈 자리가 생겼다.) 발바닥은 논리 47행 = 실제 188~191행,
# 게임의 FOOT_Y(190) 안에 들어간다.
#
# 귀여운 비율: 돔형 머리 16x18(키의 40%쯤) + 몸통 10행 + 짧은 다리.
#
# 프레임: 방향(down/side/up)마다 idle 1장 + walk 5장 + swing 5장.
# 걷기 5장은 사인 곡선을 5등분한 위상 [0, +3, +2, -2, -3] 으로 다리를 놓아
# 마지막 장에서 첫 장으로 매끄럽게 이어진다 (게임이 int(t*8)%5 로 돌린다).
#
# 실행:  python3 make_sprites.py     (Pillow 필요)
# 출력:  이 폴더에 프레임 png + preview_*.png(필름 스트립) + anim_*.gif,
#        그리고 ../../sprites/ 에 new_boy_* 이름으로 설치.
#        끝에 찍히는 SWING_HAND_DOT 값을 player.gd 에 옮겨 적는다.
import os
from PIL import Image

REF = os.path.dirname(os.path.abspath(__file__))

SCALE = 4
GW, GH = 32, 48          # 논리 캔버스 (가로 한가운데 = 15.5)
FW, FH = 128, 192        # 게임 스프라이트 규격
PAD_X = (FW - GW * SCALE) // 2

PAL = {
    'O': (54, 33, 26),      # 윤곽선
    's': (243, 159, 138),   # 살결 (참고 그림처럼 분홍기가 돈다)
    'S': (213, 116, 98),    # 살결 그늘
    'H': (250, 192, 170),   # 살결 하이라이트
    'e': (66, 32, 30),      # 눈망울
    'i': (136, 70, 42),     # 홍채 반사 (눈 아래쪽의 따뜻한 갈색)
    'w': (246, 242, 234),   # 눈 반짝이
    'r': (235, 128, 114),   # 볼터치
    'm': (170, 84, 66),     # 입
    'b': (58, 88, 168),     # 셔츠
    'B': (38, 58, 120),     # 셔츠 그늘
    'L': (94, 126, 200),    # 셔츠 밝은 면
    'p': (134, 88, 46),     # 바지
    'P': (98, 62, 32),      # 바지 그늘
    'q': (158, 108, 58),    # 바지 밝은 면
    'h': (118, 72, 40),     # 머리카락 (여자)
    'j': (152, 100, 56),    # 머리카락 밝은 면
    'g': (86, 52, 30),      # 머리카락 그늘
    'k': (82, 53, 33),      # 신발
    'K': (56, 37, 25),      # 신발 그늘
}

WALK = 5
# 오른다리 앞으로 나간 양 (논리 px). 사인 5등분 — 끝에서 처음으로 매끄럽게 돈다.
STRIDE = [0, 3, 2, -2, -3]
# 몸통이 내려앉는 양. 다리가 벌어진 칸에서 낮고(2) 모인 칸에서 높다(0).
BOB = [0, 2, 1, 1, 2]

# 세로 배치 (bob 적용 전 기준 행). 몸통 12행 + 다리 14행 — 처음(10+12)보다
# 1.2배쯤 길다. 몸통이 짧으면 거기 묶인 팔도 짧아져 머리만 큰 비율이 된다.
# 발바닥(GROUND)은 게임이 잡은 자리라 못 움직인다. 그래서 **윗몸을 통째로
# 내려** 다리를 줄인다 — 머리·몸통 크기는 그대로 두고 다리만 14행에서
# 11행이 된다. 머리가 커 보이는 쪽이 이 그림체에 맞는다.
BODY_DROP = 3            # 예전 자리에서 내려온 칸 수 (다리가 그만큼 짧아진다)
# 겨드랑이 — 팔과 몸이 갈라지는 줄 (셔츠 윗줄에서 몇 칸 아래인가).
# 어깨 바로 밑에서 갈라지면 팔이 목에 붙은 것처럼 보인다. 두 칸쯤 더
# 내려 어깨-윗팔을 한 덩어리로 두면 어깨가 넓어 보이고 자세가 편안해진다.
ARMPIT = 4
HEAD_Y = 2 + BODY_DROP   # 머리 꼭대기 (두상 16행)
SHIRT_Y = 19 + BODY_DROP # 셔츠 위 (목은 그 한 행 위)
HIP_Y = 31 + BODY_DROP   # 바지 위 (엉덩이 띠 3행)
LEG_Y = 34 + BODY_DROP   # 다리 기둥 시작
GROUND = 47              # 디딘 발바닥 행


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
# 방향마다 한 장을 그려 두고 bob 만큼 통째로 내린다. 폭 16 (열 8~23),
# 높이 18 (행 4~21) — 돔형 대두. 민머리라 정수리에 하이라이트 층을 얹는다.
#
# 눈: 4x5 눈망울 — 위아래 모서리를 둥글리고, 위에 흰 반짝이 두 점,
# 아래에 따뜻한 홍채 반사 두 점. 입은 고양이 입(ω), 양 볼에 볼터치.

HEAD_DOWN = [
    "....OOOOOOOO....",
    "..OOssssssssOO..",
    ".OssHHHHHHHHssO.",
    ".OsHHHHHHHHHHsO.",
    "OsssHHHHHHHHsssO",
    "OsssssssssssssSO",
    "OsssssssssssssSO",
    "Oss" "eee" "ssss" "eee" "sSO",
    "Osss" "ew" "ssss" "we" "ssSO",
    "Osss" "ee" "ssss" "ee" "ssSO",
    "Osss" "ei" "ssss" "ie" "ssSO",
    "OrrssssssssssrrO",
    ".Osssss" "mm" "sssssO.",
    ".OssssssssssssO.",
    "..OssssssssssO..",
    "...OOssssssOO...",
]

HEAD_SIDE = [   # 오른쪽을 본다
    "....OOOOOOOO....",
    "..OOssssssssOO..",
    ".OSsHHHHHHHHssO.",
    ".OSHHHHHHHHHHsO.",
    "OSssHHHHHHHHsssO",
    "OSsssssssssssssO",
    "OSsssssssssssssO",
    "OSsssssss" "eee" "sssO",
    "OSsssssss" "ew" "ssssO",
    "OSsssssss" "ee" "ssssO",
    "OSsssssss" "ei" "sssss",
    "OSssssrrsssssss" "S",
    ".OSsssssss" "mm" "ssO.",
    ".OssssssssssssO.",
    "..O" "sssssssssss" "O.",
    "...OO" "ssssssss" "O..",
]

HEAD_UP = [
    "....OOOOOOOO....",
    "..OOssssssssOO..",
    ".OssHHHHHHHHssO.",
    ".OsHHHHHHHHHHsO.",
    "OsssHHHHHHHHsssO",
    "OssssssssssssssO",
    "OssssssssssssssO",
    "OssssssssssssssO",
    "OssssssssssssssO",
    "OssssssssssssssO",
    "OssssssssssssssO",
    "OSssssssssssssSO",
    ".OSssssssssssSO.",
    ".OSssssssssssSO.",
    "..OSssssssssSO..",
    "...OOSSSSSSOO...",
]

HEAD_X = 9               # 머리를 한 둘레 깎은 만큼 한 칸 안으로 (아래 shrink_head)


# ---- 머리 한 둘레 깎기 ----
#
# 두상은 16x16으로 그려 두고, 쓸 때 **폭 14 · 높이 15**로 깎는다.
# 원본을 16으로 두는 이유: 머리 모양(_hairify)이 열 번호로 머리카락을
# 얹는데, 원본을 줄이면 그 번호가 전부 어긋난다.
#
# 어디를 깎나:
#   가로 — 2열과 13열 (눈 바로 바깥의 민 살결). 좌우 한 칸씩이라 얼굴은
#          가운데에 그대로 남고, 눈 사이 간격도 안 변한다.
#          **1열·14열은 건드리면 안 된다** — 거기에 얼굴 옆면의 그늘(S)이
#          들어 있다. 처음에 그 두 열을 깎았더니 옆 그늘이 통째로 사라져
#          두상이 납작한 판때기처럼 보였다.
#   세로 — 5행 (눈 위 이마의 민 살결 한 줄). 6행과 똑같은 줄이라
#          지워도 표 안 난다.
# 턱은 제자리에 두어야 목과 안 벌어지므로, 그린 자리를 한 줄 내린다.
HEAD_TRIM_COLS = (2, 13)
HEAD_TRIM_ROW = 5
_SHRUNK = {}


# 깎고 난 두상(14x15)의 **둥근 테두리**. 줄마다 가운데(6.5)에서 몇 칸까지
# 살결을 남길지 적어 둔다. 이 표 밖은 지운다 (윤곽선은 outline이 다시 두른다).
#
# 표가 없을 때는 정수리 바로 아래에서 폭이 8 -> 12 -> 14로 두 칸씩 뛰어
# 이마 양옆에 각이 졌고, 턱도 12칸으로 뚝 끊겨 네모난 인상이었다.
# 위아래를 한 칸씩 더 깎아 주면 같은 크기인데도 훨씬 둥글게 읽힌다.
HEAD_ROUND = [3.5, 5.0, 6.0, 6.0, 7.0,
              7.0, 7.0, 7.0, 7.0, 7.0, 7.0, 7.0,
              6.0, 5.0, 4.0]


def shrink_head(art):
    key = tuple(art)
    if key not in _SHRUNK:
        c0, c1 = HEAD_TRIM_COLS
        rows = [r[:c0] + r[c0 + 1:c1] + r[c1 + 1:]
                for i, r in enumerate(art) if i != HEAD_TRIM_ROW]
        mid = (len(rows[0]) - 1) / 2.0
        out = []
        for i, r in enumerate(rows):
            hw = HEAD_ROUND[i] if i < len(HEAD_ROUND) else 7.0
            out.append(''.join(cc if abs(x - mid) <= hw else '.'
                               for x, cc in enumerate(r)))
        _SHRUNK[key] = out
    return _SHRUNK[key]


def closed_eyes(art):
    """눈 뜬 머리에서 깜빡임(눈 감은) 머리를 만든다 — 눈 두 줄은 살결로
    지우고 맨 아랫줄만 감은 속눈썹 선으로 남긴다. 눈썹은 그대로."""
    out = list(art)
    for r, mp in ((8, {'e': 's', 'w': 's', 'i': 's'}),
                  (9, {'e': 's', 'w': 's', 'i': 's'}),
                  (10, {'i': 'e', 'w': 'e'})):
        out[r] = ''.join(mp.get(c, c) for c in art[r])
    return out


HEAD_DOWN_BLINK = closed_eyes(HEAD_DOWN)
HEAD_SIDE_BLINK = closed_eyes(HEAD_SIDE)


# ------------------------------------------------- 머리 스타일 (외형 템플릿)
# 민머리 그림에 머리카락을 심어 「짧은 머리」「삐죽 머리」를 만든다.
# 게임의 외형 선택(타이틀 새로 시작)이 이 세트들 중에서 고른다.

def _hairify(row, lo, hi, to='h'):
    """row의 lo..hi 칸 중 살결(s/S/H)만 머리카락으로 바꾼다."""
    return ''.join(to if lo <= i <= hi and c in 'sSH' else c
                   for i, c in enumerate(row))


def add_hair(spiky):
    """(down, side, up) 민머리 -> 짧은 머리. spiky면 정수리에 삐죽 가닥."""
    down = list(HEAD_DOWN)
    side = list(HEAD_SIDE)
    up = list(HEAD_UP)
    # 앞모습: 정수리~이마(1~5줄) + 구레나룻(6~7줄 바깥 한 칸)
    for r in range(1, 6):
        down[r] = _hairify(down[r], 0, 15)
    down[2] = _hairify(down[2], 5, 9, 'j')       # 윗머리에 빛
    down[3] = _hairify(down[3], 5, 8, 'j')
    for r in (6, 7):
        down[r] = _hairify(down[r], 1, 1, 'g') if r == 6 else down[r]
        down[r] = _hairify(down[r], 14, 14, 'g')
    down[6] = _hairify(down[6], 1, 1, 'g')
    # 옆모습(오른쪽 보기): 정수리(1~5줄) + 뒤통수(왼쪽 열, 11줄까지)
    for r in range(1, 6):
        side[r] = _hairify(side[r], 0, 15)
    side[2] = _hairify(side[2], 5, 9, 'j')
    side[3] = _hairify(side[3], 5, 8, 'j')
    for r in range(6, 12):                       # 뒤통수-목덜미
        side[r] = _hairify(side[r], 1, 2 if r < 9 else 1, 'g')
    side[6] = _hairify(side[6], 3, 4)            # 뒤통수 윗머리 볼륨
    side[7] = _hairify(side[7], 3, 3)
    # 뒷모습: 뒤통수 전체(1~10줄), 11줄에 목덜미 그늘
    for r in range(1, 11):
        up[r] = _hairify(up[r], 0, 15)
    up[2] = _hairify(up[2], 5, 10, 'j')
    up[3] = _hairify(up[3], 5, 9, 'j')
    up[9] = _hairify(up[9], 0, 15, 'g')
    up[10] = _hairify(up[10], 0, 15, 'g')
    if spiky:
        # 정수리 위로 삐죽 솟은 가닥 — 윤곽선은 outline()이 둘러 준다
        for art in (down, side, up):
            art[0] = ''.join('h' if i in (5, 8, 11) else c
                             for i, c in enumerate(art[0]))
    return down, side, up


HEADS_SHORT = add_hair(False)
HEADS_SPIKY = add_hair(True)
# 깜빡임 머리는 한 번만 만들어 돌려쓴다 — head()가 귀를 그릴지 그림의
# **동일성**(is)으로 판단하므로, 매번 새로 만들면 귀가 사라진다.
HEADS_SHORT_BLINK = (closed_eyes(HEADS_SHORT[0]), closed_eyes(HEADS_SHORT[1]))
HEADS_SPIKY_BLINK = (closed_eyes(HEADS_SPIKY[0]), closed_eyes(HEADS_SPIKY[1]))

# 귀를 그릴 머리 그림 목록 (여자는 머리카락이 귀를 덮으므로 없다)
EARS_DOWN = [HEAD_DOWN, HEAD_DOWN_BLINK,
             HEADS_SHORT[0], HEADS_SHORT_BLINK[0],
             HEADS_SPIKY[0], HEADS_SPIKY_BLINK[0]]
EARS_SIDE = [HEAD_SIDE, HEAD_SIDE_BLINK,
             HEADS_SHORT[1], HEADS_SHORT_BLINK[1],
             HEADS_SPIKY[1], HEADS_SPIKY_BLINK[1]]


# ------------------------------------------------------------------- 몸통
# bob 은 머리·몸통·팔에만 적용하고 다리는 늘 땅을 밟는다.

def torso_down(g, bob, swing, dx=0, skip=None):
    """앞모습 몸통+팔. swing: 화면 왼쪽 팔이 앞으로 나간 양 -3..+3
    dx: 휘두르기용 좌우 쏠림. skip: 'left'/'right' 팔을 안 그린다 (휘두르는 팔)"""
    y = SHIRT_Y + bob
    g.rect(13 + dx, y - 1, 18 + dx, y - 1, 's')  # 목
    g.rect(10 + dx, y, 21 + dx, y + 11, 'b')     # 몸판
    g.hline(10 + dx, 21 + dx, y + 11, 'B')       # 아랫단 그늘
    g.rect(11 + dx, y, 12 + dx, y + 4, 'L')      # 빛 받는 왼쪽 어깨
    g.vline(11 + dx, y + 5, y + 10, 'L')
    g.vline(10 + dx, y + ARMPIT, y + 10, 'B')    # 팔과 몸 사이 솔기 —
    g.vline(21 + dx, y + ARMPIT, y + 10, 'B')    # 겨드랑이부터만 (어깨는 한 덩어리)
    g.hline(13 + dx, 18 + dx, y, 'B')            # 옷깃 (목 아래 그늘)
    g.hline(8 + dx, 9 + dx, y, 'L')              # 어깨 캡 — 몸통 윗줄이 팔 위로
    g.hline(22 + dx, 23 + dx, y, 'b')            # 흘러내려 승모근 경사를 만든다
    for cx in (10 + dx, 21 + dx):                # 밑단 모서리를 깎는다
        g.px(cx, y + 11, '.')                    # (깎인 자리는 윤곽선이 채운다)
    g.hline(15 + dx, 16 + dx, y + 2, 'B')        # 앞섶 단추 세 개
    g.hline(15 + dx, 16 + dx, y + 4, 'B')
    g.hline(15 + dx, 16 + dx, y + 6, 'B')
    g.vline(20 + dx, y + 6, y + 10, 'B')         # 오른쪽 아래 그늘 (입체)
    # 팔: 소매 3픽셀 폭 + 세 칸 손. 손끝이 엉덩이 띠 바로 위(아랫단)까지
    # 온다. 앞으로 흔들면 소매가 늘어나며 내려가고 뒤로 가면 접히며
    # 올라간다 — 어깨는 늘 몸통에 붙어 있다.
    # 위상은 같은 쪽 다리와 **반대** — 왼팔은 오른다리와 함께 나간다.
    # (4칸으로 키워 봤더니 정면 어깨가 벌어져 어색했다 — 옆모습만 4칸.)
    for sx, sw, side in ((7, -swing, 'left'), (22, swing, 'right')):
        if side == skip:
            # 휘두르는 팔 쪽: 어깨 캡 밑을 두 줄 이어 둔다 — 안 이으면
            # 몸판(10~21)에서 캡(8~9)만 혹처럼 튀어나오고, 그 밑이 파였다가
            # 휘두르는 팔에서 다시 불거져 실루엣이 층진다.
            if side == 'left':
                g.rect(8 + dx, y + 1, 9 + dx, y + ARMPIT - 1, 'b')
                g.px(8 + dx, y + 1, 'L')
            else:
                g.rect(22 + dx, y + 1, 23 + dx, y + ARMPIT - 1, 'b')
            continue
        sx += dx
        dy = (1 if sw >= 2 else 0) + (1 if sw >= 3 else 0) \
            - (1 if sw <= -2 else 0) - (1 if sw <= -3 else 0)
        # 팔 길이: 소매 5칸 + 단 + 손 3칸 (예전에는 소매가 6칸이었다).
        # 손끝이 엉덩이 띠께에 오도록 한 칸 줄였다 — 팔이 길면 원숭이처럼 보인다.
        g.rect(sx, y + 1, sx + 2, y + 5 + dy, 'b')
        g.vline(sx if side == 'left' else sx + 2, y + 1, y + 5 + dy,
                'L' if side == 'left' else 'B')
        g.hline(sx, sx + 2, y + 6 + dy, 'B')                     # 소매단
        g.rect(sx, y + 7 + dy, sx + 2, y + 9 + dy, 's')          # 손
        g.hline(sx + 1, sx + 2, y + 9 + dy, 'S')                 # 손 그늘
        out = sx if side == 'left' else sx + 2   # 바깥쪽 열
        g.px(out, y + 1, '.')                    # 어깨 소매 모서리 깎기
        g.px(out, y + 9 + dy, '.')               # 주먹 끝 모서리 깎기


def legs_down(g, stride, dx=0, sq=0):
    """앞모습 다리. stride: 화면 왼쪽 다리가 앞으로 나간 양 -3..+3
    dx/sq: 휘두르기 때 몸이 쏠리고 주저앉는 양 — 엉덩이는 몸통을 따라가고
    발은 디딘 자리에 남아, 다리가 엉덩이에서 발로 기울어진다."""
    # 바지는 셔츠보다 한 칸씩 안으로 들어간다 (11~20, 셔츠는 10~21) —
    # 셔츠 밑단이 바지를 살짝 덮은 실루엣이라, 폭이 아래로 갈수록
    # 좁아지기만 하고 옆으로 되튀어나오는 데가 없다.
    g.rect(11 + dx, HIP_Y + sq, 20 + dx, HIP_Y + 2 + sq, 'p')   # 엉덩이 띠
    g.hline(11 + dx, 20 + dx, HIP_Y + sq, 'P')  # 셔츠 아랫단 그늘
    g.rect(15 + dx, HIP_Y + 2 + sq, 16 + dx, HIP_Y + 2 + sq, 'P')
    for x0, s in ((11, stride), (17, -stride)):
        lift = min(3, -s) if s < 0 else 0      # 뒤로 간 다리는 들려 짧아진다
        pc = 'P' if lift else 'p'              # 들린 다리는 그늘에 잠긴다
        inner = x0 + 3 if x0 == 11 else x0     # 가랑이 쪽 그늘 열
        top = LEG_Y + sq
        # 들린 다리는 무릎 아래가 안쪽으로 접힌다 (정면에서 본 무릎 굽힘)
        bend = (1 if x0 == 11 else -1) if lift >= 2 else 0
        knee_row = (top + GROUND - lift) // 2
        # 쪼그릴 때(휘두르기 내리침)는 디딘 무릎이 바깥으로 불거진다 —
        # 무릎 언저리만 한 칸 밀고 발은 디딘 자리에 남아 다리가 굽어 보인다
        flare = (-1 if x0 == 11 else 1) if (sq >= 2 and not lift) else 0
        outer = x0 if x0 == 11 else x0 + 3     # 빛 받는 바깥 열 (왼쪽 다리만)
        for yy in range(top, GROUND - 3 - lift):
            t = (yy - (HIP_Y + 2 + sq)) / (GROUND - HIP_Y - 2 - sq)
            off = round(dx * (1 - t))          # 엉덩이 쪽만 dx만큼 쏠린다
            if yy > knee_row:
                off += bend
            if flare and knee_row - 1 <= yy <= knee_row + 1:
                off += flare
            g.rect(x0 + off, yy, x0 + 3 + off, yy, pc)
            g.px(inner + off, yy, 'P')
            if not lift and x0 == 11:
                g.px(outer + off, yy, 'q')     # 왼쪽 다리 하이라이트
            if yy in (top, GROUND - 4 - lift):
                g.hline(x0 + off, x0 + 3 + off, yy, 'P')   # 허리·발목 접단
        g.rect(x0 + bend, GROUND - 3 - lift, x0 + 3 + bend, GROUND - 1 - lift, 'k')
        if lift:                               # 들린 발은 기울어 밑창이 보인다
            g.hline(x0 + bend, x0 + 3 + bend, GROUND - lift, 'K')
        else:
            g.hline(x0 + 1 + bend, x0 + 2 + bend, GROUND - lift, 'K')  # 둥근 신발 바닥
        g.px((x0 if x0 == 17 else x0 + 3) + bend, GROUND - 1 - lift, 'K')
        g.px(x0 + 1 + bend, GROUND - 3 - lift, 'p')        # 신발 코 광
        g.px(x0 + 2 + bend, GROUND - 3 - lift, 'p')


def _side_arm(g, c, y, sw, near):
    """옆모습 팔 한 짝 — 어깨(c, y+1)에서 진자처럼 젓는다.
    near=False 면 몸 저편의 팔: 전부 그늘색이고, 몸판을 그리기 전에
    깔려 몸 가장자리 밖으로 나온 부분만 보인다.
    손 올림은 진자 원호(√(L²-s²))로 계산해 팔 길이가 어느 위상에서든
    같다 — 안 그러면 저을 때마다 팔이 늘었다 줄었다 한다."""
    hy = y + 7 - round(10 - (100 - sw * sw) ** 0.5)   # 팔 한 칸 줄임
    cells = {}
    sleeve = ('B', 'b', 'b', 'b', 'b') if near else ('B',) * 5
    for yy in range(y + 1, hy):
        t = (yy - (y + 1)) / max(1, hy - 1 - (y + 1))
        x = c - 2 + round(sw * t)
        for j, cc in enumerate(sleeve):
            col = cc
            if near:
                # 소매단도 손목 각도를 따라 기운다 — 크게 저으면 단이
                # 두 줄에 걸쳐 비스듬히 잘린다.
                if yy == hy - 1:
                    if abs(sw) < 3 or (sw > 0 and j <= 2) or (sw < 0 and j >= 2):
                        col = 'B'
                elif yy == hy - 2 and abs(sw) >= 3 and \
                        ((sw > 0 and j >= 3) or (sw < 0 and j <= 1)):
                    col = 'B'
            cells[(x + j, yy)] = col
    # 손: 팔 기울기를 따라 줄마다 어긋나게(전단) 그린다 — 손목이 팔
    # 방향으로 꺾여 보인다. 좌우 평행이동만 하면 손만 둥둥 떠다닌다.
    hx = c - 1 + sw
    hand = 's' if near else 'S'
    for k in range(3):
        ox = round(sw * k / 7)
        for j in range(4):
            cells[(hx + j + ox, hy + k)] = hand
    if near:
        ox2 = round(sw * 2 / 7)
        cells[(hx + 2 + ox2, hy + 2)] = 'S'
        cells[(hx + 3 + ox2, hy + 2)] = 'S'
    for (x, yy) in cells:                      # 획 둘레 윤곽선 —
        for nx, ny in ((x - 1, yy), (x + 1, yy), (x, yy - 1), (x, yy + 1)):
            if (nx, ny) in cells or not (0 <= nx < GW and 0 <= ny < GH):
                continue
            # 겨드랑이 위로는 윤곽선을 **아예 긋지 않는다**. 옆으로만 열어
            # 두면 팔 양옆의 검은 세로줄이 어깨 꼭대기까지 올라와, 어깨가
            # 세 갈래로 갈린 것처럼 보인다 (팔을 목에 붙여 놓은 꼴이다).
            # 여기가 트여 있어야 어깨-윗팔이 한 덩어리로 읽힌다.
            if yy < y + ARMPIT:
                continue
            if g.d[ny][nx] != '.':             # (팔이 몸에 이어 붙는다)
                g.d[ny][nx] = 'O'
    for (x, yy), cc in cells.items():
        g.px(x, yy, cc)


def torso_side(g, bob, swing, lean=0, draw_arm=True):
    """옆모습 몸통+팔(오른쪽 보기). swing: 팔이 앞으로 나간 양 -3..+3"""
    y = SHIRT_Y + bob
    c = 15 + lean                              # 몸 중심 (반 칸 왼쪽)
    # 팔은 같은 쪽 다리와 반대로(교차 보행), 다리 보폭보다 한 칸만 크게 —
    # 손이 몸통 가장자리를 살짝 벗어나는 정도가 자연스럽다.
    sw = -(swing + (1 if swing > 0 else -1 if swing < 0 else 0))
    if draw_arm:
        _side_arm(g, c, y, -sw, False)         # 저편 팔 — 반대 위상, 몸 뒤에
    g.rect(c - 1, y - 1, c + 2, y - 1, 's')    # 목
    g.rect(c - 4, y, c + 5, y + 11, 'b')
    g.hline(c - 4, c + 5, y + 11, 'B')
    g.vline(c + 5, y, y + 10, 'L')             # 앞면이 밝다
    g.px(c + 4, y + 1, 'L')
    g.vline(c - 4, y, y + 10, 'B')             # 등쪽 그늘
    g.px(c - 3, y + 1, 'B')
    for cx in (c - 4, c + 5):                  # 어깨·밑단 모서리 깎기
        g.px(cx, y, '.')
        g.px(cx, y + 11, '.')
    if draw_arm:
        _side_arm(g, c, y, sw, True)           # 가까운 팔 — 몸 위에


def legs_side(g, stride, lean=0, dx=0, sq=0):
    """옆모습 다리. stride: 가까운 다리가 앞으로 나간 양 -3..+3
    허벅지는 엉덩이에 붙어 있고 발끝으로 갈수록 stride 만큼 기울어진다.
    dx/sq: 휘두르기 쏠림·주저앉음 (엉덩이만 따라가고 발은 제자리)."""
    c = 15 + lean
    # 바지는 몸통(10칸)보다 한 칸씩 안으로 들어간 8칸 — 셔츠 밑단이
    # 바지를 덮은 실루엣이라 옆으로 되튀어나오는 데가 없다.
    g.rect(c - 3 + dx, HIP_Y + sq, c + 4 + dx, HIP_Y + 2 + sq, 'p')
    g.hline(c - 3 + dx, c + 4 + dx, HIP_Y + sq, 'P')   # 셔츠 아랫단 그늘
    g.hline(c - 3 + dx, c + 4 + dx, HIP_Y + 2 + sq, 'P')  # 가랑이 그늘 줄 —
    # 띠와 다리(7칸) 사이 단차를 그늘로 눌러 다리가 그늘 속에서
    # 나오는 것처럼 잇는다. 허벅지도 이 줄까지 겹쳐 세로로 이어진다.
    # 먼 다리를 그늘색으로 먼저, 가까운 다리를 위에 얹는다.
    # 옆에서 본 다리는 앞뒤 두께가 몸통과 비슷해야 한다 — 7칸 폭
    # (몸통 10칸). 가늘게 그리면 상자 밑에 젓가락을 꽂은 꼴이 된다.
    #
    # 무릎: 다리를 허벅지(엉덩이→무릎)와 정강이(무릎→발)로 갈라 긋는다.
    # 뒤로 찬 다리는 무릎이 조금만 뒤로 가고 발이 더 크게 뒤로 차올라
    # 무릎이 접힌 게 보인다. 앞 다리는 무릎이 반 발 앞서는 정도만.
    for off, shade in ((-stride, True), (stride, False)):
        back = off < 0
        lift = 2 if back else 0                # 뒤로 간 다리는 뒤꿈치가 들린다
        # 허벅지도 엉덩이를 축으로 크게 흔든다 — 무릎이 보폭의 2/3까지
        # 따라가야 다리 전체가 젓는다 (작으면 정강이만 까딱거린다).
        knee_off = off * (0.65 if back else 0.75)
        foot_off = round(off * 1.35) if back else off
        pc, kc = ('P', 'K') if shade else ('p', 'k')
        bot = GROUND - lift
        hip_row = HIP_Y + 2 + sq
        knee_row = (hip_row + bot) // 2 + 1
        ankle_row = bot - 4                    # 여기까지만 기울고, 발은 통짜다
        for yy in range(LEG_Y - 1 + sq, bot + 1):   # 띠 아래 줄부터 겹쳐 잇는다
            if yy <= knee_row:                 # 허벅지
                f = (yy - hip_row) / max(1, knee_row - hip_row)
                o = knee_off * f
            elif yy <= ankle_row:              # 정강이 (발목에서 발 위치에 닿는다)
                f = (yy - knee_row) / max(1, ankle_row - knee_row)
                o = knee_off + (foot_off - knee_off) * f
            else:                              # 발 — 줄마다 어긋나면 신발이 깨진다
                o = foot_off
            t = (yy - hip_row) / (GROUND - hip_row)
            x = 15 + round(o + dx * (1 - t)) + lean
            cc = pc if yy <= ankle_row else kc
            # 굵기 — 허벅지는 굵고 발목으로 갈수록 가늘어진다.
            # 모든 줄을 같은 폭으로 그으면 통나무 두 개를 세워 둔 꼴이다.
            # 뒤(wb)는 종아리가 불룩하고, 앞(wf)은 정강이라 곧고 가늘다.
            if yy <= knee_row:
                wb, wf = 3, 3                      # 허벅지
            elif yy < ankle_row:
                q = (yy - knee_row) / max(1, ankle_row - knee_row)
                wb = 3 if q < 0.5 else 2           # 무릎 밑 장딴지
                wf = 2                             # 정강이
            else:
                wb, wf = 3, 3                      # 발목부터는 신발이라 통짜
            if yy == bot:
                g.rect(x - 2, yy, x + 3, yy, cc)   # 뒤꿈치만 둥글게 (앞은 앞코로)
            else:
                g.rect(x - wb, yy, x + wf, yy, cc)
            # 무릎 — 굽힌 다리에만 접힌 자국을 한 줄 넣는다.
            # 이 한 줄이 있어야 다리가 「굽었다」로 보인다 (없으면 그냥 기운 막대)
            if yy == knee_row and back:
                g.rect(x, yy, x + wf, yy, 'P' if not shade else pc)
            if not shade and hip_row < yy <= bot - 4:  # 띠에 겹친 줄은 건드리지
                g.px(x - wb, yy, 'P')          # 않는다 — 가랑이 그늘 위에 밝은
                if yy == bot - 4:              # 점이 찍히면 허리가 튀어 보인다
                    g.rect(x - wb + 1, yy, x + wf, yy, 'P')   # 발목 접단
                else:
                    g.px(x + wf, yy, 'q')      # 앞쪽 하이라이트
            if not shade and yy == bot - 3:
                g.px(x + 2, yy, 'p')           # 신발 코 광
            if yy == bot:
                g.hline(x - 2, x + 3, yy, 'K') # 신발 밑창은 늘 그늘
            # 가까운 다리의 **뒤쪽 모서리**를 어둡게 눌러 먼 다리와 뗀다.
            # 둘 다 바지색이라 겹치면 한 덩어리로 보인다 — 이 한 줄이
            # 있어야 「앞다리와 뒷다리」로 읽힌다.
            if not shade:
                bx = x - wb - 1
                if 0 <= bx < GW and g.d[yy][bx] in ('p', 'P', 'q', 'k', 'K'):
                    g.px(bx, yy, 'O')
        x = 15 + foot_off + lean
        # 앞코 — 신발이 진행 방향으로 두 칸 나온 둥근 코. 뒤로 찬 발도
        # 코는 앞을 본다 (뒤꿈치만 들린다).
        g.rect(x + 4, bot - 1, x + 5, bot - 1, kc)
        g.px(x + 4, bot, kc)
        g.px(x + 4, bot - 2, 'p' if not shade else kc)   # 발등 광
        if off < 0:
            g.px(x - 4, bot - 1, kc)           # 들린 뒤꿈치


def torso_up(g, bob, swing, dx=0, skip=None):
    y = SHIRT_Y + bob
    g.rect(13 + dx, y - 1, 18 + dx, y - 1, 'S')  # 목덜미
    g.rect(10 + dx, y, 21 + dx, y + 11, 'b')
    g.hline(10 + dx, 21 + dx, y, 'B')            # 어깨 그늘
    g.hline(10 + dx, 21 + dx, y + 11, 'B')
    g.rect(11 + dx, y + 1, 12 + dx, y + 4, 'L')
    g.vline(11 + dx, y + 5, y + 10, 'L')
    g.vline(10 + dx, y + ARMPIT, y + 10, 'B')    # 팔과 몸 사이 솔기 —
    g.vline(21 + dx, y + ARMPIT, y + 10, 'B')    # 겨드랑이부터만
    g.hline(13 + dx, 18 + dx, y + 6, 'B')        # 등판 주름
    g.hline(8 + dx, 9 + dx, y, 'L')              # 어깨 캡 (승모근 경사)
    g.hline(22 + dx, 23 + dx, y, 'b')
    for cx in (10 + dx, 21 + dx):                # 밑단 모서리 깎기
        g.px(cx, y + 11, '.')
    for sx, sw, side in ((7, -swing, 'left'), (22, swing, 'right')):
        if side == skip:                         # 뒤모습이라 팔 위상이 좌우 반대
            continue
        sx += dx
        dy = (1 if sw >= 2 else 0) + (1 if sw >= 3 else 0) \
            - (1 if sw <= -2 else 0) - (1 if sw <= -3 else 0)
        g.rect(sx, y + 1, sx + 2, y + 5 + dy, 'b')
        g.vline(sx if side == 'left' else sx + 2, y + 1, y + 5 + dy,
                'L' if side == 'left' else 'B')
        g.hline(sx, sx + 2, y + 6 + dy, 'B')
        g.rect(sx, y + 7 + dy, sx + 2, y + 9 + dy, 's')
        g.hline(sx + 1, sx + 2, y + 9 + dy, 'S')
        out = sx if side == 'left' else sx + 2
        g.px(out, y + 1, '.')                    # 어깨 소매 모서리 깎기
        g.px(out, y + 9 + dy, '.')               # 주먹 끝 모서리 깎기


def legs_up(g, stride, dx=0, sq=0):
    legs_down(g, stride, dx, sq)               # 뒤모습 다리는 앞모습과 같은 규칙


# --------------------------------------------------------------- 휘두르기
# 방향당 5장: 감기 시작 · 다 감음 · 휘두름 · 내리침 · 되돌아옴.
# 「휘두름」은 다 감은 팔이 내리침으로 넘어가는 중간 칸 — 없으면 주먹이
# 머리 옆에서 반대편 아래로 한 칸에 건너뛰어 호가 안 보인다.
# 도구는 게임(player.gd)이 주먹 자리에 얹으므로 여기서는 몸+팔만 그린다.
# 주먹 자리는 아래에서 SWING_HAND_DOT 값으로 계산해 찍어 준다.
#
# 팔 길이 조심: 걷기 팔이 예닐곱 칸이니 어깨-주먹 거리도 그 언저리로 묶는다
# (늘려도 열다섯 칸 안). 「다 감음」의 주먹은 머리 옆면 높이까지만 올리고,
# 그 위로는 주먹에 얹히는 도구가 뻗어 보인다. 뒷모습 내리침은 주먹까지
# 머리 저편(=캐릭터의 앞)으로 넘어가 통째로 가려진다 — 안 보이는 쪽이 맞다.
#
# 칸마다 (fist, elbow, dx, sq, behind):
#   fist    주먹 3x3 블록의 왼쪽 위 논리 칸
#   elbow   팔꿈치 — 어깨-주먹 직선 바깥으로 뺀 자리 (일직선이면 막대팔이 된다)
#   dx      몸이 쏠리는 방향 (감을 때 뒤로 갈수록 크게, 내리칠 때 앞으로)
#   sq      주저앉는 양 (내리치는 칸만 2)
#   behind  팔을 머리 뒤에 그린다 (뒷모습 내리침)
SWING_N = 5                     # 방향당 칸 수 (player.gd SWING_FRAMES와 같아야 한다)
SWING = {
    # 앞모습: **화면 쪽으로** 내리친다 (원근). 팔이 닿는 왼쪽 옆에서
    # 위로 감았다가 그대로 내리 긋는다 — 주먹을 정수리나 몸통 가운데까지
    # 억지로 끌고 가면 팔이 고무줄처럼 늘어난다. 내리친 주먹은 어깨 바로
    # 앞이라 팔이 짧아 보이고(단축법), 도구가 화면 쪽으로 넘어온다.
    # 몸은 옆으로 밀지 않고 정중앙에서 쪼그린다.
    'down': {'skip': 'left', 'shoulder': (9, 24),
             'poses': [((5, 19), (5, 22), -1, 0, False),
                       ((3, 10), (2, 17), -2, 0, False),
                       ((1, 19), (4, 22), -1, 0, False),
                       ((8, 31), (8, 28), 0, 2, False),
                       ((5, 21), (5, 23), 0, 0, False)]},
    # 뒷모습: 등을 보이는 캐릭터의 「앞」은 화면 위쪽 — 어깨 옆으로 감아올려
    # 정수리 너머 저편으로 내리친다. 휘두름부터는 팔이 머리 저쪽(=캐릭터의
    # 앞)이라 머리가 가리고, 주먹만 정수리 위로 잠깐 보인다.
    'up':   {'skip': 'right', 'shoulder': (22, 24),
             'poses': [((24, 17), (26, 20), 1, 0, False),
                       ((24, 10), (27, 17), 2, 0, False),
                       ((19, 4), (24, 11), 0, 0, True),
                       ((16, 9), (20, 14), 0, 2, True),
                       ((24, 14), (26, 18), 0, 0, False)]},
    # 옆모습(오른쪽 보기): 뒤로 감았다가 앞으로 내리친다
    'side': {'skip': None, 'shoulder': (15, 24),
             'poses': [((6, 17), (8, 21), -2, 0, False),
                       ((6, 11), (6, 17), -3, 0, False),
                       ((25, 15), (19, 21), 2, 1, False),
                       ((24, 33), (23, 29), 3, 2, False),
                       ((23, 27), (18, 27), 2, 0, False)]},
}


def arm_stroke(g, x0, y0, fx, fy, ex, ey):
    """어깨(x0,y0)에서 팔꿈치를 거쳐 주먹 블록(fx,fy)까지 3픽셀 굵기로
    팔을 긋는다. 몸이나 머리 위를 지나가므로 획 둘레를 윤곽선으로 눌러 뗀다."""
    cells = set()
    for (ax, ay), (bx, by) in (((x0, y0), (ex, ey)), ((ex, ey), (fx, fy))):
        steps = max(abs(bx - ax), abs(by - ay), 1)
        for i in range(steps + 1):
            t = i / steps
            x, y = round(ax + (bx - ax) * t), round(ay + (by - ay) * t)
            for ddx in (0, 1, 2):
                for ddy in (0, 1, 2):
                    cells.add((x + ddx, y + ddy))
    hand = {(fx + i, fy + j) for i in (0, 1, 2) for j in (0, 1, 2)}
    cells |= hand
    SHIRT = ('b', 'B', 'L')
    for (x, y) in cells:                       # 획 둘레 윤곽선
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) in cells or not (0 <= nx < GW and 0 <= ny < GH):
                continue
            # 셔츠에 닿는 자리는 두르지 않는다 — 어깨든 가슴이든, 두르면
            # 팔이 몸통에서 잘려 붙인 막대처럼 뜨고 가슴에 금이 간 것처럼
            # 보인다. 몸 앞을 지나는 팔은 셔츠와 한 덩어리다(원근 단축).
            # 주먹 둘레만은 셔츠 위라도 둘러서 손이 또렷이 읽히게 한다.
            if (x, y) not in hand and g.d[ny][nx] in SHIRT:
                continue
            if g.d[ny][nx] != '.':
                g.d[ny][nx] = 'O'
    for (x, y) in cells:
        if (x, y) in hand:
            g.px(x, y, 's')
        else:                                  # 손에 닿는 줄은 소매단
            near = any((x + mx, y + my) in hand
                       for mx in (-1, 0, 1) for my in (-1, 0, 1))
            if not near and g.d[y][x] in SHIRT:
                continue                       # 셔츠 위 팔뚝은 덧그리지 않는다
            g.px(x, y, 'B' if near else 'b')
    g.px(fx + 2, fy + 2, 'S')                  # 주먹 그늘
    g.px(fx + 1, fy + 2, 'S')


def swing_frame(direction, phase):
    spec = SWING[direction]
    (fx, fy), (ex, ey), dx, sq, behind = spec['poses'][phase]
    g = G()
    if direction == 'side':
        # 발은 네 장 내내 같은 자리를 디디고(벌린 자세), 엉덩이·다리 윗동이
        # 몸통을 따라 쏠린다 — 허리가 어긋나지 않고 다리도 같이 움직인다.
        legs_side(g, 3, 0, dx, sq)
        torso_side(g, sq, 0, dx, draw_arm=False)
    elif direction == 'down':
        # 반대팔·발도 조금씩 따라 움직인다 — 내려치면서 몸이 사는 정도만.
        # 반대팔은 감을 때 살짝 접혔다가 내리칠 때 뒤로 흔들리고,
        # 오른발은 감는 동안 뒤꿈치가 한 칸 들렸다가 내리칠 때 쾅 디딘다.
        counter = (-1, -2, 0, 2, 1)[phase]
        step = (0, 1, 1, 0, 0)[phase]
        legs_down(g, step, dx, sq)
        torso_down(g, sq, counter, dx, skip=spec['skip'])
    else:
        legs_up(g, 0, dx, sq)
        torso_up(g, sq, 0, dx, skip=spec['skip'])
    art = PARTS[direction][0]
    sx, sy = spec['shoulder']
    # 내리치는 칸은 머리를 한 칸 더 움츠린다 — 어깨 사이로 목이 파묻히는
    # 크런치가 있어야 팔만 도는 게 아니라 온몸으로 찍는 느낌이 난다
    hb = sq + (1 if (direction == 'down' and phase == 3) else 0)
    if behind:
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
        head(g, art, hb, dx)                   # 머리가 팔을 덮고 도구만 저편에
    else:
        head(g, art, hb, dx)
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
    roughen(g)
    g.outline()
    return g


def hand_dot(direction, phase):
    """player.gd SWING_HAND_DOT 값 — 주먹 3x3 블록 한가운데의 node 좌표.
    도트 원점은 발밑 가운데(픽셀 64,190), node = 그림의 절반 크기."""
    (fx, fy), _, _, _, _ = SWING[direction]['poses'][phase]
    dot_x = PAD_X + fx * SCALE + 6 - 64
    dot_y = fy * SCALE + 6 - 190
    return (round(dot_x / 2.0 * 10) / 10, round((dot_y + 2) / 2.0 * 10) / 10)


# ------------------------------------------------------------------- 조립

PARTS = {
    'down': (HEAD_DOWN, torso_down, legs_down),
    'side': (HEAD_SIDE, torso_side, legs_side),
    'up':   (HEAD_UP, torso_up, legs_up),
}

for _art in (HEAD_DOWN, HEAD_SIDE, HEAD_UP):
    assert len(_art) == 16 and all(len(r) == 16 for r in _art), \
        [(i, len(r)) for i, r in enumerate(_art) if len(r) != 16]


def head(g, art, bob, lean=0):
    # 한 줄 깎은 만큼 한 줄 내려 붙인다 — 턱이 제자리에 있어야 목과 안 벌어진다
    g.blit(shrink_head(art), HEAD_X + lean, HEAD_Y + 1 + bob)
    # 귀 — 민머리 남자만. 여자는 머리카락이 귀를 덮는다.
    if any(art is a for a in EARS_DOWN):             # 눈높이 양옆에 볼록 한 칸
        for ex in (HEAD_X - 1, HEAD_X + 14):
            g.px(ex + lean, HEAD_Y + 9 + bob, 's')
            g.px(ex + lean, HEAD_Y + 10 + bob, 'S')
    elif any(art is a for a in EARS_SIDE):           # 옆모습은 귓바퀴 모양
        g.px(12 + lean, HEAD_Y + 9 + bob, 'S')
        g.px(13 + lean, HEAD_Y + 9 + bob, 'S')
        g.px(12 + lean, HEAD_Y + 10 + bob, 'S')
        g.px(13 + lean, HEAD_Y + 10 + bob, 's')
        g.px(12 + lean, HEAD_Y + 11 + bob, 'S')
        g.px(13 + lean, HEAD_Y + 11 + bob, 'S')


# ------------------------------------------------------------------- 결
#
# 한 색으로 넓게 채운 면은 도트가 아니라 비닐처럼 보인다. 옷·바지·신발에
# 성근 얼룩을 흩어 **짜인 천의 결**을 낸다.
#
# 두 가지를 지킨다:
#   ① 얼굴은 건드리지 않는다 (셔츠 윗줄 위) — 눈·입이 지저분해진다
#   ② 얼룩 자리는 **칸 좌표로만** 정한다. 프레임마다 다시 뽑으면 걸을 때
#      결이 지글지글 끓는다 (도트 게임에서 제일 눈에 띄는 실수다)
# 신발(k/K)은 뺀다 — 칸이 몇 개 안 되는 데다 어두워서, 얼룩이 앉으면
# 결이 아니라 흙이 묻은 것처럼 보인다.
ROUGH_DARK = {'b': 'B', 'p': 'P', 's': 'S', 'L': 'b', 'q': 'p'}
ROUGH_LITE = {'b': 'L', 'p': 'q', 'B': 'b', 'P': 'p', 'S': 's'}


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
            # **바둑판 위에만 얼룩을 둔다.** 아무 데나 흩으면 잡음(노이즈)이
            # 되어 옷이 더러워 보인다. 한 칸 건너 한 칸으로 두면 도트를
            # 찍는 사람이 쓰는 디더링이 되어 「짜인 천」으로 읽힌다.
            if (x + y) % 2:
                continue
            # 아래로 갈수록 짙게 — 천은 접히는 쪽(아랫단·무릎)에 그늘이 앉는다
            depth = (y - SHIRT_Y) / max(1, GH - SHIRT_Y)
            r = _rough_hash(x, y)
            if r < 0.16 + depth * 0.16 and c in ROUGH_DARK:
                g.d[y][x] = ROUGH_DARK[c]
            elif r < 0.30 and c in ROUGH_LITE:
                g.d[y][x] = ROUGH_LITE[c]


def frame(direction, stride=None, bob=0):
    art, torso, legs = PARTS[direction]
    g = G()
    s = 0 if stride is None else stride
    # 엉덩이도 몸통 바운스를 따라간다 (sq=bob) — 안 그러면 몸·다리는
    # 움직이는데 허리 띠만 공중에 고정돼 상하체가 따로 논다.
    # 발은 땅에 붙어 있으니 그만큼 무릎이 눌린다.
    if direction == 'side':
        lean = 0 if stride is None else 1      # 걸을 때 몸이 살짝 앞으로 쏠린다
        legs(g, s, lean, 0, bob)
        torso(g, bob, s, lean)
        head(g, art, bob, lean)
    else:
        legs(g, s, 0, bob)
        torso(g, bob, s)
        head(g, art, bob)
    roughen(g)
    g.outline()
    return g


def save(name, g):
    g.render().save(os.path.join(REF, name + '.png'))
    return g


# ------------------------------------------------------- 남/녀 두 벌 생성
# 몸·모션은 같고 머리 그림과 셔츠 색만 다르다. 여자는 밤색 단발머리
# (앞머리 + 옆 갈래)에 분홍 셔츠 — 이름은 player_f_* 로 설치한다.

HEAD_DOWN_F = [
    "....OOOOOOOO....",
    "..OOhhhhhhhhOO..",
    ".OhhjjjjjjjjhhO.",
    ".OhjjjjjjjjjjhO.",
    "OhhjjjjjjjjjjhhO",
    "OhhjjhhhhhhjjhhO",
    "Ohh" "ssssssssss" "hhO",
    "Oh" "s" "eee" "ssss" "eee" "s" "h" "O",
    "Oh" "ss" "ew" "ssss" "we" "ss" "h" "O",
    "Oh" "ss" "ee" "ssss" "ee" "ss" "h" "O",
    "Oh" "ss" "ei" "ssss" "ie" "ss" "h" "O",
    "Oh" "r" "ssssssssss" "r" "h" "O",
    ".hh" "ssss" "mm" "ssss" "hh.",
    ".hh" "ssssssssss" "hh.",
    ".hh" "ssssssssss" "hh.",
    ".hh" "OO" "ssssss" "OO" "hh.",
    ".hh" ".........." "hh.",
    ".gg" ".........." "gg.",
]

HEAD_SIDE_F = [   # 오른쪽을 본다
    "....OOOOOOOO....",
    "..OOhhhhhhhhOO..",
    ".OhhjjjjjjjjhhO.",
    ".OhjjjjjjjjjjhO.",
    "OhhjjjjjjjjjjhhO",
    "OhhhjjhhhhhhhhhO",
    "Ohhhhhhhh" "ssssss" "O",
    "Ohhhh" "ssss" "eee" "sss" "O",
    "OhjhssssssewsssO",
    "OhjhsssssseesssO",
    "Ohjhsssssseissss",
    "Ohh" "sss" "rr" "sssssss" "S",
    ".hhh" "ssssss" "mm" "ss" "O.",
    ".hhh" "ssssssssss" "O.",
    ".hhh" "ssssssssss" "O.",
    ".hhh" "O" "ssssssss" "O" "..",
    ".hhh" "............",
    ".ggg" "............",
]

HEAD_UP_F = [
    "....OOOOOOOO....",
    "..OOhhhhhhhhOO..",
    ".OhhjjjjjjjjhhO.",
    ".OhjjjjjjjjjjhO.",
    "OhhjjjjjjjjjjhhO",
    "OhhhjhhhhhhjhhhO",
    "OhhhjhhhhhhjhhhO",
    "OhhhjhhhhhhjhhhO",
    "OhhhjhhhhhhjhhhO",
    "OhhhjhhhhhhjhhhO",
    "OhhhjhhhhhhjhhhO",
    "OhhhjhhhhhhjhhhO",
    "OghhhhhhhhhhhhgO",
    ".hhhjhhhhhhjhhh.",
    ".hhhjhhhhhhjhhh.",
    ".hghhhhhhhhhhgh.",
    ".gghhhhhhhhhhgg.",
    "..gggggggggggg..",
]

# 여자 머리는 어깨 위까지 — 16행 얼굴 + 2행 머리채 = 18행.
# 머리를 몸 위에 겹쳐 그리므로 늘어난 행이 어깨를 자연스럽게 덮는다.
for _art in (HEAD_DOWN_F, HEAD_SIDE_F, HEAD_UP_F):
    assert len(_art) == 18 and all(len(r) == 16 for r in _art), \
        [(i, len(r)) for i, r in enumerate(_art) if len(r) != 16]

OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))


def render_set(heads, blinks, ref_prefix, out_prefix):
    """머리 그림만 갈아 끼워 전체 프레임(정지+걷기+휘두르기+깜빡임)을 뽑는다.
    지금 PAL 값으로 즉시 그려 두므로, 부른 뒤 PAL을 바꿔도 안 변한다."""
    for d in heads:
        PARTS[d] = (heads[d], PARTS[d][1], PARTS[d][2])
    images = {}
    for d in ('down', 'side', 'up'):
        images[f'{d}_idle'] = frame(d).render()
        for i in range(WALK):
            images[f'{d}_walk_{i}'] = frame(d, STRIDE[i], BOB[i]).render()
        for i in range(SWING_N):
            images[f'{d}_swing_{i}'] = swing_frame(d, i).render()
    for d, art in blinks.items():              # 눈 감은 정지 한 장씩
        keep = PARTS[d]
        PARTS[d] = (art, keep[1], keep[2])
        images[f'{d}_blink'] = frame(d).render()
        PARTS[d] = keep
    for k, im in images.items():
        im.save(os.path.join(REF, f'{ref_prefix}{k}.png'))
        im.save(os.path.join(OUT, f'{out_prefix}{k}.png'))
    return images


# 네 세트(머리 스타일) 모두 **같은 표준 팔레트**(파란 셔츠·갈색 바지)로
# 뽑는다 — 옷 색은 게임이 외형 선택에 맞춰 실행 중에 갈아입힌다
# (game_data.gd recolor_player_image가 이 PAL 값을 그대로 찾아 바꾼다).
FRAMES = render_set(
    {'down': HEAD_DOWN, 'side': HEAD_SIDE, 'up': HEAD_UP},
    {'down': HEAD_DOWN_BLINK, 'side': HEAD_SIDE_BLINK}, '', 'new_boy_')

FRAMES_S = render_set(
    {'down': HEADS_SHORT[0], 'side': HEADS_SHORT[1], 'up': HEADS_SHORT[2]},
    {'down': HEADS_SHORT_BLINK[0], 'side': HEADS_SHORT_BLINK[1]},
    'short_', 'hair_short_')

FRAMES_K = render_set(
    {'down': HEADS_SPIKY[0], 'side': HEADS_SPIKY[1], 'up': HEADS_SPIKY[2]},
    {'down': HEADS_SPIKY_BLINK[0], 'side': HEADS_SPIKY_BLINK[1]},
    'spiky_', 'hair_spiky_')

FRAMES_F = render_set(
    {'down': HEAD_DOWN_F, 'side': HEAD_SIDE_F, 'up': HEAD_UP_F},
    {'down': closed_eyes(HEAD_DOWN_F), 'side': closed_eyes(HEAD_SIDE_F)},
    'f_', 'player_f_')

# player.gd SWING_HAND_DOT에 옮겨 적을 주먹 좌표 (남녀 같은 골격이라 공용)
print('SWING_HAND_DOT (player.gd):')
for d in ('side', 'down', 'up'):
    pts = ', '.join('Vector2(%g, %g)' % hand_dot(d, i) for i in range(SWING_N))
    print('  "%s": [%s],' % (d, pts))


# ----------------------------------------------------------------- 확인용 그림

CHECK = ((58, 58, 58), (38, 38, 38))
SAND = (219, 172, 102)      # 참고 그림의 모랫바닥


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


for images, tag in ((FRAMES, ''), (FRAMES_F, 'f_'),
                    (FRAMES_S, 'short_'), (FRAMES_K, 'spiky_')):
    strip(images, f'preview_{tag}idle.png', ['down_idle', 'side_idle', 'up_idle'])
    for d in ('down', 'side', 'up'):
        keys = [f'{d}_walk_{i}' for i in range(WALK)]
        strip(images, f'preview_{tag}{d}_walk.png', keys)
        gif(images, f'anim_{tag}{d}_walk.gif', keys)
        sw = [f'{d}_swing_{i}' for i in range(SWING_N)]
        strip(images, f'preview_{tag}{d}_swing.png', sw)
        gif(images, f'anim_{tag}{d}_swing.gif', sw, ms=170)
    gif(images, f'anim_{tag}idle.gif', ['down_idle', 'side_idle', 'up_idle'], ms=600)

print('done: %d+%d frames + previews + gifs (sprites/에 설치됨)'
      % (len(FRAMES), len(FRAMES_F)))
