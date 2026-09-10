# -*- coding: utf-8 -*-
# 도트 소년(dot_boy) 스프라이트 생성기 — 참고 그림(민머리·파란 셔츠·갈색 바지)을
# 굵은 도트로 **코드가 직접 그린다** (앞 세대들은 AI 시트를 잘라 썼다).
#
# 논리 해상도 32x48 을 4배로 키워 게임 규격 128x192 에 꼭 맞춘다.
# 이 굵기는 마을 사람(32x48 도트를 2배로) 과 같은 도트 밀도다 — 게임이
# 카메라 0.56배 · 최근접 필터로 그리므로, 이보다 가는 도트는 화면에서
# 한 줄씩 빠지며 걸을 때 지글거린다. 예쁘게 만드는 일은 **도트를 늘리는
# 게 아니라 같은 칸 안에서 모양을 잘 잡는 일**이다.
#
# 2판(이 파일): 머리를 18x17 로 키우고 얼굴을 다시 그렸다.
#   · 눈 4x5 — 검은 테 안에 흰 반짝이·갈색 홍채. 눈썹은 갈색 한 줄.
#   · 코 한 점, 작은 입, 눈 밑 볼터치.
#   · 옆모습 — 이마·코·턱이 실루엣으로 읽히고, 눈은 얼굴선에서 한 칸 뒤.
#     귀는 뒤통수 쪽에 그늘로 그린다.
#   · 머리 모양은 **덧그림(overlay)** 으로 얹는다 — 민머리 위에 앞머리
#     (끝이 갈라진 가닥) · 옆머리 · 뒷머리를 씌운다. 긴 머리는 어깨를
#     지나 가슴께까지 내려온다.
#   · 걷기 — 앞·뒷모습도 다리를 모으는 칸에서 몸이 한 칸 떠오른다.
#
# 발바닥은 논리 47행 = 실제 188~191행, 게임의 FOOT_Y(190) 안에 들어간다.
# 몸통 자리(셔츠 22행 · 허리 34행)는 그대로다 — player.gd 의 SWING_WAIST
# (136 = 34x4) 와 HORSE_POSE 의 자르는 줄이 여기에 묶여 있다.
#
# 프레임: 방향(down/side/up)마다 idle 1장 + walk 6장 + swing 5장,
# 앞·옆은 눈 감은 blink 1장.
#
# 실행:  python3 make_sprites.py     (Pillow 필요)
# 출력:  이 폴더에 프레임 png + preview_*.png(필름 스트립) + anim_*.gif,
#        그리고 ../../sprites/ 에 new_boy_* / hair_short_* / hair_spiky_* /
#        player_f_* 이름으로 설치.
#        끝에 찍히는 SWING_HAND_DOT 값을 player.gd 에 옮겨 적는다.
import math
import os
from PIL import Image

REF = os.path.dirname(os.path.abspath(__file__))

SCALE = 4
GW, GH = 32, 48          # 논리 캔버스 (가로 한가운데 = 15.5)
FW, FH = 128, 192        # 게임 스프라이트 규격
PAD_X = (FW - GW * SCALE) // 2

# 색은 **game_data.gd 의 표와 한 벌**이다. 게임이 실행 중에 이 값을 정확히
# 찾아 바꿔 입히므로(recolor_player_image) 한 값이라도 어긋나면 그 칸은
# 옷을 못 갈아입는다. 윤곽선·눈·눈썹·반짝이·먼 신발은 표에 없어 늘 그대로다.
PAL = {
    'O': (54, 33, 26),      # 윤곽선
    's': (243, 159, 138),   # 살결 (참고 그림처럼 분홍기가 돈다)
    'S': (213, 116, 98),    # 살결 그늘
    'H': (250, 192, 170),   # 살결 하이라이트
    'e': (66, 32, 30),      # 눈망울·눈 테
    'i': (136, 70, 42),     # 홍채 · 눈썹 (따뜻한 갈색)
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
    'n': (68, 44, 29),      # 먼 신발 — k와 K 사이. 뒤쪽 신발까지 K로 칠하면
                            # 윤곽선 O(54,33,26)와 구분이 안 돼, 두 짝 사이
                            # 경계선이 지워지고 발치가 새까만 덩이가 된다.
    'K': (56, 37, 25),      # 신발 그늘 (밑창)
}

# ── 걷기 한 바퀴 ─────────────────────────────────────────────────────
# 여섯 칸. 걸음은 두 발짝이 한 바퀴라, 한 바퀴 안에 다리를 모으는 「통과」가
# 두 번, 벌리는 「딛기」가 두 번 있어야 한다. 다섯 칸으로는 담을 수가
# 없다 — 통과는 위상 0도와 180도인데 다섯 등분의 눈금 간격이 72도라
# 180도에 눈금이 없다. 여섯이면 60도라 둘 다 눈금에 놓인다.
WALK = 6

# 다리 한 짝이 한 바퀴 도는 동안 겪는 **여섯 자세**를 뼈 길이를 못 박고
# **각도**로 적는다. 허벅지와 정강이는 언제나 같은 길이고, 그리는 것도
# 축에 수직으로 두께를 재어 긋는다. 그러면 어느 각도에서도 길이도 두께도
# 그대로다. (자리로 적으면 접는 칸에서 다리가 오그라든다.)
#
# 사람 무릎은 한 방향으로만 굽는다 — 뒤꿈치가 엉덩이 쪽으로 온다. 그래서
# 허공을 지나는 다리는 **무릎이 앞으로, 발은 그 뒤 밑에** 접히고, 뒤로
# 뻗은 다리는 발이 무릎보다 더 뒤로 간다.
#
# (골반이 앞으로 나간 칸, 허벅지 각도°, 무릎 굽힘°, 발 각도)
#   허벅지 각도  + 앞으로 / - 뒤로 (수직에서 잰다)
#   무릎 굽힘    늘 0 이상. 정강이 각도 = 허벅지 각도 - 굽힘
#   발 각도      +1 발끝 들림(뒤꿈치로 딛는다) · 0 평평 · -1 뒤꿈치 들림
LEG_L = 4.5                # 허벅지·정강이 뼈 길이 (둘이 같다)
LEG = [
    ( 1.0,  32,  4,  1),   # 0 Contact — 뻗어서 뒤꿈치로 닿는다
    ( 0.4,  14, 20,  0),   # 1 Down    — 무릎이 굽어 체중을 받는다
    (-0.2,   0,  4,  0),   # 2 Pass    — 몸 밑에 곧게 선다
    (-1.0, -28, 10, -1),   # 3 Up      — 뒤로 뻗고 발끝으로 민다
    (-0.4,   6, 62, -1),   # 4 접기    — 무릎이 오르고 뒤꿈치가 접혀 올라간다
    ( 0.6,  30, 38,  1),   # 5 내밀기  — 무릎이 앞서고 정강이가 따라 나간다
]
LEG_LAG = WALK // 2        # 먼 다리는 반 바퀴 뒤 — 표를 세 칸 밀어 쓴다


# 몸이 오르내리는 양은 **적지 않고 다리에서 나온다**. 벌린 다리는 아래로
# 덜 뻗으니 골반이 내려앉아야 발이 땅에 닿고, 모은 다리는 길게 뻗으니
# 골반이 올라간다. 발짝마다 한 번씩, 한 바퀴에 두 번 오르내린다.
def _leg_depth(spec):
    """골반에서 발목까지 **아래로** 뻗은 깊이. spec = LEG 표의 한 줄."""
    _, th, flex, _ = spec
    return LEG_L * (math.cos(math.radians(th))
                    + math.cos(math.radians(th - flex)))


def _joints(spec, hip_y):
    """(골반x, 무릎x, 무릎y, 발목x, 발목y, 발각도) — 골반을 원점 삼아."""
    hipo, th, flex, tilt = spec
    a1, a2 = math.radians(th), math.radians(th - flex)
    kx = hipo + LEG_L * math.sin(a1)
    ky = hip_y + LEG_L * math.cos(a1)
    ax = kx + LEG_L * math.sin(a2)
    ay = ky + LEG_L * math.cos(a2)
    return hipo, kx, ky, ax, ay, tilt


def hip_row_at(phase, sq=0):
    """그 칸에서 골반이 놓이는 줄 — 더 깊이 뻗은 발이 땅에 닿게 맞춘다."""
    d = max(_leg_depth(LEG[phase % WALK]), _leg_depth(LEG[(phase + LEG_LAG) % WALK]))
    return GROUND - 2 - d + sq


# 앞·뒷모습의 몸 오르내림. 옆모습은 다리 각도에서 저절로 나오지만 앞뒤는
# 다리가 나란해 그 값이 없다 — 다리를 모으는 「통과」 칸(2·5)에서 한 칸
# 떠오르게 적어 둔다. 이게 없으면 다리만 젓는 종이 인형이다.
BOB = [0, 0, -1, 0, 0, -1]

# **골반이 함께 흔들리는 양.** 다리만 젓고 허리가 붙박이면 인형에 다리를
# 달아 흔드는 꼴이 된다. 사람은 앞으로 나가는 다리 쪽으로 골반이 따라
# 밀리고, 딛는 순간 그 위에 체중이 얹히며 도로 끌려온다.
HIP = [1, 1, 0, -1, -1, 0]

# 옆모습 팔이 앞으로 나간 양 — 가까운 다리와 반대로.
ARM = [-5, -2, 1, 5, 2, -1]

# 정면·뒷모습에서 통과 칸에 **허공을 지나가는 다리**.
#   +1 = 화면 왼쪽 다리, -1 = 오른쪽 다리, 0 = 둘 다 딛고 있다
PASS = [0, 0, -1, 0, 0, 1]
# 정면·뒷모습 보폭. 옆모습만큼 크게 벌릴 이유가 없다.
STRIDE_F = [3, 2, 0, -3, -2, 0]

# 세로 배치. 머리 17행 + 목 2행 + 몸통 12행 + 다리 11행 = 발바닥 47행.
# 발바닥(GROUND)과 몸통 자리는 게임이 잡은 자리라 못 움직인다.
ARMPIT = 4               # 겨드랑이 — 팔과 몸이 갈라지는 줄 (셔츠 윗줄에서)
NECK_H = 2               # 목 길이 — 「목이 있다」만 딱 읽히는 두 줄
ARM_L = 8                # 팔이 붙는 열 (어깨 끝 8~23열 = 16칸, 머리 18칸)
ARM_R = 21
HEAD_TOP = 3             # 머리 그림 0행이 놓이는 줄 (턱 19행)
HEAD_X = 7               # 18칸 머리 그림의 왼쪽 열 (가운데 15.5)
HEAD_W, HEAD_H = 18, 17
SHIRT_Y = 22             # 셔츠 위 (목은 그 두 행 위)
HIP_Y = 34               # 바지 위 (엉덩이 띠 3행) = player.gd SWING_WAIST/4
LEG_Y = 37               # 다리 기둥 시작
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
# 방향마다 한 장. 18칸 x 17줄 — 둥근 대두. 윤곽선까지 그림에 넣는다
# (outline()은 빠진 데만 채운다). 눈은 5x4 아몬드꼴 진한 눈망울 — 윗줄은
# 속눈썹 선이라 바깥쪽이 두껍고 안쪽으로 갈수록 짧아지며, 아랫줄은 두 칸으로
# 좁아진다. 왼쪽 위에 흰 반짝이 한 점, 셋째 줄은 따뜻한 갈색 반사.
# (세로로 긴 타원도 해 봤는데 눈이 너무 땡그래 보였다 — 가로가 세로보다
#  넓어야 눈매가 생긴다.)
# (검은 테 안에 갈색을 채운 고리 모양도 해 봤는데 물안경처럼 보였다 —
#  이 크기에서는 눈망울이 통째로 어두워야 눈으로 읽힌다.)
# 눈썹은 갈색 한 줄, 코는 두 눈 사이 아래 그늘 한 점, 입은 두 칸,
# 볼터치는 눈 바로 밑 바깥쪽.
# 빛은 왼쪽 위에서 온다 — 오른쪽 끝 열(16)이 그늘.
#
# 눈 자리(닫힌 눈·속눈썹을 만들 때 쓴다): 앞모습 8~11행 2~6열·10~14열,
# 옆모습 8~11행 11~14열. 옆모습 귀는 9~11행 3~5열의 둥근 테.

HEAD_DOWN = [
    "......OOOOOO......",
    "....OOssssssOO....",
    "...OssHHHHHHssO...",
    "..OssHHHHHHHHssO..",
    ".OssHHHHHHHHHHssO.",
    ".OsssHHHHHHHHsssO.",
    "OsssssssssssssssSO",
    "OssiiisssssiiissSO",
    "O" "s" "eeee" "s" "sss" "s" "eeee" "s" "S" "O",
    "O" "s" "eweee" "sss" "eweee" "s" "S" "O",
    "O" "s" "eiiie" "sss" "eiiie" "s" "S" "O",
    "O" "sss" "ee" "ss" "S" "ss" "ee" "sss" "S" "O",
    "O" "sssssss" "S" "sssssss" "SO",
    "O" "s" "rr" "sssssssss" "rr" "s" "SO",
    ".OssssssmmsssssSO.",
    "..OssssssssssSSO..",
    "....OOOOOOOOOO....",
]

HEAD_SIDE = [   # 오른쪽을 본다. 뒤통수(왼쪽)가 그늘, 이마·코·턱이 앞(오른쪽)
    "....OOOOOOOO......",
    "..OOssssssssOO....",
    ".OSssHHHHHHssO....",
    ".OSsHHHHHHHHssO...",
    "OSssHHHHHHHHHssO..",
    "OSsssHHHHHHHHsssO.",
    "OSssssssssssssssO.",
    "OSssssssssssiiisO.",
    "OS" "sssssssss" "eeee" "s" "O.",
    "OS" "ss" "OO" "sssss" "ewee" "s" "O.",
    "OS" "s" "O" "sS" "sssss" "eiie" "ss" "O",
    "OS" "ss" "OO" "sssss" "s" "ee" "ss" "S" "O",
    "OSsssssssssssssSO.",
    ".OSssrrssssssssmO.",
    "..OSssssssssssSO..",
    "...OSsssssssSO....",
    "....OOOOOOOOO.....",
]

HEAD_UP = [
    "......OOOOOO......",
    "....OOssssssOO....",
    "...OssHHHHHHssO...",
    "..OssHHHHHHHHssO..",
    ".OssHHHHHHHHHHssO.",
    ".OsssHHHHHHHHsssO.",
    "OsssssssssssssssSO",
    "OsssssssssssssssSO",
    "OsssssssssssssssSO",
    "OsssssssssssssssSO",
    "OsssssssssssssssSO",
    "OSssssssssssssssSO",
    "OSSssssssssssssSSO",
    ".OSSssssssssssSSO.",
    ".OSSSssssssssSSSO.",
    "..OSSSssssssSSSO..",
    "....OOOOOOOOOO....",
]

for _art in (HEAD_DOWN, HEAD_SIDE, HEAD_UP):
    assert len(_art) == HEAD_H and all(len(r) == HEAD_W for r in _art), \
        [(i, len(r)) for i, r in enumerate(_art) if len(r) != HEAD_W]

# 눈 자리 — (행0, 행1, 열0, 열1)
EYES_DOWN = [(8, 11, 2, 6), (8, 11, 10, 14)]
EYES_SIDE = [(8, 11, 11, 14)]


def _put(art, dots, c):
    out = [list(r) for r in art]
    for r, x in dots:
        out[r][x] = c
    return [''.join(r) for r in out]


def closed_eyes(art, boxes, lids):
    """눈 뜬 머리에서 깜빡임(눈 감은) 머리를 만든다 — 눈 자리를 살결로
    지우고 아래로 굽은 속눈썹 선만 남긴다. 눈썹은 그대로."""
    out = [list(r) for r in art]
    for r0, r1, c0, c1 in boxes:
        for r in range(r0, r1 + 1):
            for x in range(c0, c1 + 1):
                out[r][x] = 's'
    for r, x in lids:
        out[r][x] = 'e'
    return [''.join(r) for r in out]


LIDS_DOWN = [(10, 2), (11, 3), (11, 4), (11, 5), (10, 6),
             (10, 10), (11, 11), (11, 12), (11, 13), (10, 14)]
LIDS_SIDE = [(10, 11), (11, 12), (11, 13), (10, 14)]

# 여자 얼굴 — 같은 얼굴에 아래 바깥 모서리 속눈썹 한 점씩 (옆모습은 앞머리
# 쪽으로 한 칸 더 뻗은 윗속눈썹). 그것만으로 눈매가 또렷해진다.
FACE_DOWN_F = _put(HEAD_DOWN, [(11, 2), (11, 14)], 'e')
FACE_SIDE_F = _put(HEAD_SIDE, [(8, 15), (11, 11)], 'e')


# ------------------------------------------------- 머리 모양 (덧그림)
# 민머리 위에 얹는다. '.' 는 비쳐 보인다. dy 는 그림 0행이 머리 0행에서
# 몇 줄 위에 놓이는가 — 머리 위로 부푼 만큼 음수.
# 정수리 왼쪽 위에 밝은 면(j), 끝자락·그늘 쪽에 어두운 면(g).

HAIR_SHORT = {
    'down': (-1, [
        ".....hhhhhhhh.....",
        "...hhhhhhhhhhhh...",
        "..hhhhjjjjhhhhhh..",
        ".hhhjjjjjjhhhhhhh.",
        ".hhhjjjjjhhhhhhhh.",
        "hhhhjjjhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "ghh.....h......hhg",
        "gh..............hg",
        "g................g",
    ]),
    'side': (-1, [
        "...hhhhhhhhh......",
        "..hhhhhhhhhhhh....",
        ".hhhhjjjjjhhhhhh..",
        "hhhhjjjjjjhhhhhhh.",
        "hhhhjjjjjhhhhhhhh.",
        "hhhhjjjhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "ghhhhhhhhhhhhhhhhh",
        "gghhhhhhh...h...h.",
        "gghhhhh...........",
        "gghh..............",
        "ggh...............",
        "ggh...............",
        "gg................",
        ".g................",
    ]),
    'up': (-1, [
        ".....hhhhhhhh.....",
        "...hhhhhhhhhhhh...",
        "..hhhhjjjjjhhhhh..",
        ".hhhjjjjjjjhhhhhh.",
        ".hhhjjjjjjhhhhhhh.",
        "hhhhjjjjhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "ghhhhhhhhhhhhhhhhg",
        "gghhhhhhhhhhhhhhgg",
        ".gghhhhhhhhhhhhgg.",
        ".g.ghhhhhhhhhhg.g.",
        "....gg..gg..gg....",
    ]),
}

# 삐죽 머리 = 짧은 머리 + 정수리에서 솟은 가닥 두 줄 (+ 옆으로 삐친 가닥)
SPIKES = {
    'down': ["...h....h.....h...",
             "..hhh.hhhhhhhh.hh."],
    'side': ["..h...h...h.......",
             ".hhh.hhhhhhhhh.h.."],
    'up':   ["...h....h....h....",
             "..hhh.hhhhhhhh.hh."],
}


def spiky(short):
    out = {}
    for d, (dy, art) in short.items():
        rows = SPIKES[d] + list(art[1:])       # 부푼 첫 줄을 가닥 줄로 바꾼다
        out[d] = (dy - 1, rows)
    return out


HAIR_SPIKY = spiky(HAIR_SHORT)

# 긴 머리(여자) — 앞머리는 가운데가 갈라진 가닥, 옆머리가 귀를 덮고 어깨를
# 지나 가슴께(머리 아래 7줄 = 셔츠 4줄째)까지 내려온다. 뒷모습은 등을
# 덮는 머리채가 아래로 갈수록 좁아진다.
HAIR_LONG = {
    'down': (-1, [
        ".....hhhhhhhh.....",
        "...hhhhhhhhhhhh...",
        "..hhhhjjjjjhhhhh..",
        ".hhhjjjjjjjhhhhhh.",
        ".hhhjjjjjjhhhhhhh.",
        "hhhhjjjjhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhh.h.......h..hhh",
        "hh..............hh",
        "hh..............hh",
        "hh..............hh",
        "hh..............hh",
        "hh..............hh",
        "hh..............hh",
        "hh..............hh",
        "hhh............hhh",
        "hhh............hhh",
        "ghhh..........hhhg",
        "ghhh..........hhhg",
        "ghhh..........hhhg",
        ".ghh..........hhg.",
        ".ghh..........hhg.",
        "..gg..........gg..",
        "..g............g..",
    ]),
    'side': (-1, [
        "...hhhhhhhhh......",
        "..hhhhhhhhhhhh....",
        ".hhhhjjjjjhhhhhh..",
        "hhhhjjjjjjhhhhhhh.",
        "hhhhjjjjjhhhhhhhh.",
        "hhhhjjjhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhh..h...h.",
        "hhhhhhh...........",
        "hhhhhhh...........",
        "hhhhhh............",
        "hhhhhh............",
        "hhhhhh............",
        "hhhhhh............",
        "hhhhhh............",
        "hhhhhh............",
        "hhhhhh............",
        "ghhhhh............",
        "ghhhhh............",
        "ghhhh.............",
        "gghhh.............",
        ".ghh..............",
        ".gg...............",
        "..g...............",
    ]),
    'up': (-1, [
        ".....hhhhhhhh.....",
        "...hhhhhhhhhhhh...",
        "..hhhhjjjjjhhhhh..",
        ".hhhjjjjjjjhhhhhh.",
        ".hhhjjjjjjhhhhhhh.",
        "hhhhjjjjhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhjhhhhhhhjhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "hhhhhhhhhhhhhhhhhh",
        "ghhhhhhhhhhhhhhhhg",
        "ghhhhhhhhhhhhhhhhg",
        ".ghhhhhhhhhhhhhhg.",
        ".ghhhhhhhhhhhhhhg.",
        "..ghhhhhhhhhhhhg..",
        "..gghhhhhhhhhhgg..",
        "...ggghhhhhhggg...",
        "....gggggggggg....",
    ]),
}

for _hs in (HAIR_SHORT, HAIR_SPIKY, HAIR_LONG):
    for _d, (_dy, _art) in _hs.items():
        assert all(len(r) == HEAD_W for r in _art), \
            (_d, [(i, len(r)) for i, r in enumerate(_art) if len(r) != HEAD_W])


# ------------------------------------------------------------------- 몸통
# bob 은 머리·몸통·팔에만 적용하고 다리는 늘 땅을 밟는다.

def torso_down(g, bob, swing, dx=0, skip=None):
    """앞모습 몸통+팔. swing: 화면 왼쪽 팔이 앞으로 나간 양 -3..+3
    dx: 휘두르기용 좌우 쏠림. skip: 'left'/'right' 팔을 안 그린다 (휘두르는 팔)"""
    y = SHIRT_Y + bob
    # 목 — 4칸 폭에 NECK_H줄. 턱 바로 밑은 그늘(S)이 짙게 앉고, 아래로
    # 갈수록 살결(s)이 나온다 — 이 두 단이 있어야 목이 기둥으로 보인다.
    g.rect(14 + dx, y - NECK_H, 17 + dx, y - 1, 's')
    g.hline(14 + dx, 17 + dx, y - NECK_H, 'S')   # 턱 밑 그림자
    g.vline(17 + dx, y - NECK_H, y - 1, 'S')     # 오른쪽(빛 반대편) 그늘
    g.rect(10 + dx, y, 21 + dx, y + 11, 'b')     # 몸판
    g.hline(10 + dx, 21 + dx, y + 11, 'B')       # 아랫단 그늘
    g.rect(11 + dx, y, 12 + dx, y + 4, 'L')      # 빛 받는 왼쪽 어깨
    g.vline(11 + dx, y + 5, y + 10, 'L')
    g.vline(ARM_L + 2 + dx, y + ARMPIT, y + 10, 'B')   # 팔과 몸 사이 솔기 —
    g.vline(ARM_R + dx, y + ARMPIT, y + 10, 'B')       # 겨드랑이부터만
    g.hline(13 + dx, 18 + dx, y, 'B')            # 옷깃 (목 아래 그늘)
    g.px(13 + dx, y + 1, 'B')                    # 둥근 깃 양 끝
    g.px(18 + dx, y + 1, 'B')
    g.hline(ARM_L + 1 + dx, ARM_L + 2 + dx, y, 'L')   # 어깨 캡 — 몸통 윗줄이 팔
    g.hline(ARM_R + dx, ARM_R + 1 + dx, y, 'b')       # 위로 흘러 승모근 경사를 만든다
    for cx in (10 + dx, 21 + dx):                # 밑단 모서리를 깎는다
        g.px(cx, y + 11, '.')                    # (깎인 자리는 윤곽선이 채운다)
    g.px(16 + dx, y + 3, 'B')                    # 앞섶 단추 세 개
    g.px(16 + dx, y + 6, 'B')
    g.px(16 + dx, y + 9, 'B')
    g.vline(20 + dx, y + 6, y + 10, 'B')         # 오른쪽 아래 그늘 (입체)
    # 팔: 소매 3픽셀 폭 + 세 칸 손. 앞으로 흔들면 소매가 늘어나며 내려가고
    # 뒤로 가면 접히며 올라간다 — 어깨는 늘 몸통에 붙어 있다.
    # 위상은 같은 쪽 다리와 **반대** — 왼팔은 오른다리와 함께 나간다.
    for sx, sw, side in ((ARM_L, -swing, 'left'), (ARM_R, swing, 'right')):
        if side == skip:
            # 휘두르는 팔 쪽: 어깨 캡 밑을 두 줄 이어 둔다 — 안 이으면
            # 몸판에서 캡만 혹처럼 튀어나오고 실루엣이 층진다.
            if side == 'left':
                g.rect(ARM_L + dx, y + 1, ARM_L + 1 + dx, y + ARMPIT - 1, 'b')
                g.px(ARM_L + dx, y + 1, 'L')
            else:
                g.rect(ARM_R + 1 + dx, y + 1, ARM_R + 2 + dx, y + ARMPIT - 1, 'b')
            continue
        sx += dx
        dy = (1 if sw >= 2 else 0) + (1 if sw >= 3 else 0) \
            - (1 if sw <= -2 else 0) - (1 if sw <= -3 else 0)
        g.rect(sx, y + 1, sx + 2, y + 5 + dy, 'b')
        g.vline(sx if side == 'left' else sx + 2, y + 1, y + 5 + dy,
                'L' if side == 'left' else 'B')
        g.hline(sx, sx + 2, y + 6 + dy, 'B')                     # 소매단
        g.rect(sx, y + 7 + dy, sx + 2, y + 9 + dy, 's')          # 손
        g.hline(sx + 1, sx + 2, y + 9 + dy, 'S')                 # 손 그늘
        out = sx if side == 'left' else sx + 2   # 바깥쪽 열
        g.px(out, y + 1, '.')                    # 어깨 소매 모서리 깎기
        g.px(out, y + 9 + dy, '.')               # 주먹 끝 모서리 깎기


def legs_down(g, stride, dx=0, sq=0, pass_leg=0):
    """앞모습 다리. stride: 화면 왼쪽 다리가 앞으로 나간 양 -3..+3
    dx/sq: 휘두르기 때 몸이 쏠리고 주저앉는 양 — 엉덩이는 몸통을 따라가고
    발은 디딘 자리에 남아, 다리가 엉덩이에서 발로 기울어진다.
    pass_leg: +1 왼쪽 다리가, -1 오른쪽 다리가 허공을 지나가는 중."""
    # 바지는 셔츠보다 한 칸씩 안으로 들어간다 (11~20, 셔츠는 10~21).
    g.rect(11 + dx, HIP_Y + sq, 20 + dx, HIP_Y + 2 + sq, 'p')   # 엉덩이 띠
    g.hline(11 + dx, 20 + dx, HIP_Y + sq, 'P')  # 셔츠 아랫단 그늘
    g.rect(15 + dx, HIP_Y + 2 + sq, 16 + dx, HIP_Y + 2 + sq, 'P')
    for x0, s in ((11, stride), (17, -stride)):
        # 통과 칸에 허공을 지나가는 다리 — 정면은 보폭이 안 보이니
        # 들어 올린 발이 걸음을 말해 주는 유일한 단서다.
        swinging = (pass_leg > 0 and x0 == 11) or (pass_leg < 0 and x0 == 17)
        lift = 3 if swinging else (min(3, -s) if s < 0 else 0)
        pc = 'P' if lift else 'p'              # 들린 다리는 그늘에 잠긴다
        inner = x0 + 3 if x0 == 11 else x0     # 가랑이 쪽 그늘 열
        top = LEG_Y + sq
        # 들린 다리는 무릎 아래가 안쪽으로 접힌다 (정면에서 본 무릎 굽힘)
        bend = (1 if x0 == 11 else -1) if lift >= 2 else 0
        knee_row = (top + GROUND - lift) // 2
        # 쪼그릴 때(휘두르기 내리침)는 디딘 무릎이 바깥으로 불거진다
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
    hy = y + 7 - round(10 - (100 - sw * sw) ** 0.5)
    cells = {}
    sleeve = ('B', 'b', 'b', 'b', 'b') if near else ('B',) * 5
    for yy in range(y + 1, hy):
        t = (yy - (y + 1)) / max(1, hy - 1 - (y + 1))
        x = c - 2 + round(sw * t)
        for j, cc in enumerate(sleeve):
            col = cc
            if near:
                # 소매단도 손목 각도를 따라 기운다
                if yy == hy - 1:
                    if abs(sw) < 3 or (sw > 0 and j <= 2) or (sw < 0 and j >= 2):
                        col = 'B'
                elif yy == hy - 2 and abs(sw) >= 3 and \
                        ((sw > 0 and j >= 3) or (sw < 0 and j <= 1)):
                    col = 'B'
            cells[(x + j, yy)] = col
    # 손: 팔 기울기를 따라 줄마다 어긋나게(전단) 그린다 — 손목이 팔
    # 방향으로 꺾여 보인다.
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
            # 겨드랑이 위로는 윤곽선을 긋지 않는다 — 어깨-윗팔이 한 덩어리로
            # 읽혀야 한다.
            if yy < y + ARMPIT:
                continue
            if g.d[ny][nx] != '.':             # (팔이 몸에 이어 붙는다)
                g.d[ny][nx] = 'O'
    for (x, yy), cc in cells.items():
        g.px(x, yy, cc)


def torso_side(g, bob, swing, lean=0, draw_arm=True, arm=None, far_arm=None):
    """옆모습 몸통+팔(오른쪽 보기). swing: 다리 보폭 -3..+3
    arm: 팔이 앞으로 나간 양을 직접 지정 (걷기는 ARM 표를 넘긴다).
    far_arm: draw_arm 이 꺼져 있을 때(휘두르기) 몸 뒤의 반대팔만 이만큼
    앞으로 내민다 — 도구 든 팔은 따로 긋지만 반대팔은 여기서."""
    y = SHIRT_Y + bob
    c = 15 + lean                              # 몸 중심 (반 칸 왼쪽)
    sw = arm if arm is not None else \
        -(swing + (1 if swing > 0 else -1 if swing < 0 else 0))
    if draw_arm:
        _side_arm(g, c, y, -sw, False)         # 저편 팔 — 반대 위상, 몸 뒤에
    elif far_arm is not None:
        _side_arm(g, c, y, far_arm, False)
    g.rect(c - 1, y - NECK_H, c + 2, y - 1, 's')   # 목
    g.hline(c - 1, c + 2, y - NECK_H, 'S')         # 턱 밑 그림자
    g.vline(c - 1, y - NECK_H, y - 1, 'S')         # 뒷목은 그늘
    g.rect(c - 4, y, c + 5, y + 11, 'b')
    g.hline(c - 4, c + 5, y + 11, 'B')
    g.vline(c + 5, y, y + 10, 'L')             # 앞면이 밝다
    g.px(c + 4, y + 1, 'L')
    g.vline(c - 4, y, y + 10, 'B')             # 등쪽 그늘
    g.px(c - 3, y + 1, 'B')
    g.hline(c - 1, c + 3, y, 'B')              # 옷깃
    for cx in (c - 4, c + 5):                  # 어깨·밑단 모서리 깎기
        g.px(cx, y, '.')
        g.px(cx, y + 11, '.')
    if draw_arm:
        _side_arm(g, c, y, sw, True)           # 가까운 팔 — 몸 위에


def _bone(g, x0, y0, x1, y1, w0, w1, body, back=None, front=None, mark=None):
    """뼈 하나를 **축에 수직으로 두께를 재어** 긋는다.
    back/front: 뒤·앞 모서리에 얹을 색 (그늘·하이라이트)."""
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
            if back is not None and sv <= -hw + 0.5:
                col = back
            elif front is not None and sv >= hw - 0.5:
                col = front
            px_, py_ = round(cx + nx * sv), round(cy + ny * sv)
            g.px(px_, py_, col)
            if mark is not None:
                mark.add((px_, py_))
            j += 1


def _boot(g, ax, ay, tilt, body, sole, lit, mark=None):
    """신발 두 줄 — 각도에 따라 어느 줄이 땅에 닿는지가 달라진다."""
    x, y = round(ax), round(ay)
    if tilt > 0:                           # 뒤꿈치로 딛는다 (발끝이 들림)
        hi = (x - 2, x + 3); lo = (x - 2, x + 0)
    elif tilt < 0:                         # 발끝으로 민다 (뒤꿈치가 들림)
        hi = (x - 3, x + 2); lo = (x + 0, x + 3)
    else:
        hi = (x - 2, x + 2); lo = (x - 2, x + 3)
    g.rect(hi[0], y + 1, hi[1], y + 1, body)
    g.rect(lo[0], y + 2, lo[1], y + 2, sole)
    if lit:
        g.px(hi[1], y + 1, lit)            # 발등이 빛을 문다
    if mark is not None:
        for a_, b_, yy in ((hi[0], hi[1], y + 1), (lo[0], lo[1], y + 2)):
            for xx in range(a_, b_ + 1):
                mark.add((xx, yy))
    return (hi, lo, y + 1, y + 2)


def legs_side(g, stride=0, lean=0, dx=0, sq=0, phase=None, hip=0, poses=None):
    """옆모습 다리. 돌려주는 값은 골반 줄(반올림) — 몸통이 그 위에 앉는다.
    phase 를 주면 걷기 — LEG 표(각도)의 그 칸을 가까운 다리에 쓰고, 먼
    다리에는 반 바퀴 뒤(phase + LEG_LAG)를 쓴다.
    poses 를 주면 (가까운 다리, 먼 다리) 자세 튜플을 그대로 쓴다 (휘두르기).
    둘 다 없으면 stride 로 곧은 다리를 만든다 (정지).
    hip: 골반이 앞으로 밀린 칸 — 다리와 바지 띠가 함께 움직인다."""
    if poses is not None:
        near_spec, far_spec = poses
        hip_row = GROUND - 2 - max(_leg_depth(near_spec), _leg_depth(far_spec)) + sq
    elif phase is None:
        near_spec = far_spec = None
        hip_row = HIP_Y + 2 + sq
    else:
        near_spec = LEG[phase % WALK]
        far_spec = LEG[(phase + LEG_LAG) % WALK]
        hip_row = hip_row_at(phase, sq)
    c = 15 + lean + hip
    hr = round(hip_row)
    g.rect(c - 3 + dx, hr - 2, c + 4 + dx, hr, 'p')
    g.hline(c - 3 + dx, c + 4 + dx, hr - 2, 'P')   # 셔츠 아랫단 그늘
    g.hline(c - 3 + dx, c + 4 + dx, hr, 'P')       # 가랑이 그늘 줄
    if near_spec is None:
        near_front = None if not stride else stride > 0
    else:
        _n = _joints(near_spec, 0)[3]
        _f = _joints(far_spec, 0)[3]
        near_front = None if abs(_n - _f) < 0.5 else _n > _f
    for shade in (True, False):
        if near_spec is None:
            off = -stride if shade else stride
            hx = off * 0.35
            kx, ky = off * 0.85, hip_row + LEG_L
            ax, ay = off * 1.35, hip_row + LEG_L * 2
            tilt = -1 if off < 0 else 0
            if shade and not stride:
                hx -= 0.7; kx -= 0.7; ax -= 0.7
        else:
            hx, kx, ky, ax, ay, tilt = _joints(far_spec if shade else near_spec, hip_row)
        base = 16 + lean
        hx = base + hx + dx + hip
        kx = base + kx + (dx + hip) * 0.5
        ax = base + ax + (dx + hip) * 0.15
        pc, sc, hl = ('P', 'n', None) if shade else ('p', 'P', 'q')
        kc, kk = ('n', 'K') if shade else ('k', 'K')
        mark = None if shade else set()
        _bone(g, hx, hip_row - 1, kx, ky, 4.6, 3.8, pc, sc, hl, mark)
        _bone(g, kx, ky, ax, ay, 3.8, 3.1, pc, sc, hl, mark)
        if not shade:
            g.px(round(ax), round(ay), 'q')        # 발목 접단
        _boot(g, ax, ay, tilt, kc, kk, 'p' if not shade else None, mark)
        if shade or near_front is None:
            continue
        # 가까운 다리에서 먼 다리와 맞닿는 쪽 모서리를 어둡게 눌러 뗀다.
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
    g.rect(14 + dx, y - NECK_H, 17 + dx, y - 1, 'S')  # 목덜미 (앞모습과 같은 굵기)
    g.rect(10 + dx, y, 21 + dx, y + 11, 'b')
    g.hline(10 + dx, 21 + dx, y, 'B')            # 어깨 그늘
    g.hline(10 + dx, 21 + dx, y + 11, 'B')
    g.rect(11 + dx, y + 1, 12 + dx, y + 4, 'L')
    g.vline(11 + dx, y + 5, y + 10, 'L')
    g.vline(ARM_L + 2 + dx, y + ARMPIT, y + 10, 'B')   # 팔과 몸 사이 솔기 —
    g.vline(ARM_R + dx, y + ARMPIT, y + 10, 'B')       # 겨드랑이부터만
    g.hline(13 + dx, 18 + dx, y + 6, 'B')        # 등판 주름
    g.hline(ARM_L + 1 + dx, ARM_L + 2 + dx, y, 'L')   # 어깨 캡 (승모근 경사)
    g.hline(ARM_R + dx, ARM_R + 1 + dx, y, 'b')
    for cx in (10 + dx, 21 + dx):                # 밑단 모서리 깎기
        g.px(cx, y + 11, '.')
    for sx, sw, side in ((ARM_L, -swing, 'left'), (ARM_R, swing, 'right')):
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


def legs_up(g, stride, dx=0, sq=0, pass_leg=0):
    legs_down(g, stride, dx, sq, pass_leg)     # 뒤모습 다리는 앞모습과 같은 규칙


# --------------------------------------------------------------- 휘두르기
# 방향당 5장: 감기 시작 · 다 감음 · 휘두름 · 내리침 · 되돌아옴.
# 도구는 게임(player.gd)이 주먹 자리에 얹으므로 여기서는 몸+팔만 그린다.
# 주먹 자리는 아래에서 SWING_HAND_DOT 값으로 계산해 찍어 준다.
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
    # 위로 감았다가 그대로 내리 긋는다.
    'down': {'skip': 'left', 'shoulder': (10, 24),
             'poses': [((4, 19), (4, 22), -1, 0, False),
                       ((2, 10), (1, 17), -2, 0, False),
                       ((0, 19), (3, 22), -1, 0, False),
                       ((8, 31), (8, 28), 0, 2, False),
                       ((4, 21), (4, 23), 0, 0, False)]},
    # 뒷모습: 어깨 옆으로 감아올려 정수리 너머 저편으로 내리친다. 휘두름부터는
    # 팔이 머리 저쪽(=캐릭터의 앞)이라 머리가 가리고, 주먹만 정수리 위로
    # 잠깐 보인다. (머리가 두 줄 커져서 주먹도 두 줄 올렸다.)
    'up':   {'skip': 'right', 'shoulder': (21, 24),
             'poses': [((25, 17), (27, 20), 1, 0, False),
                       ((25, 9), (28, 16), 2, 0, False),
                       ((19, 1), (25, 9), 0, 0, True),
                       ((16, 7), (20, 13), 0, 2, True),
                       ((25, 14), (27, 18), 0, 0, False)]},
    # 옆모습(오른쪽 보기): 뒤로 감았다가 앞으로 내리친다. 머리가 커져 뒤통수가
    # 7열까지 오므로, 감은 주먹은 그보다 더 뒤(4열)로 뺀다.
    'side': {'skip': None, 'shoulder': (15, 24),
             'poses': [((5, 17), (7, 21), -2, 0, False),
                       ((4, 10), (5, 17), -3, 0, False),
                       ((26, 13), (20, 20), 2, 1, False),
                       ((24, 33), (23, 29), 3, 1, False),
                       ((23, 27), (18, 27), 2, 0, False)],
             # 다리 (가까운 다리=앞, 먼 다리=뒤) — (골반 밀림, 허벅지°, 무릎 굽힘°, 발)
             # 감을수록 뒷다리에 무게가 실려 앞발 끝이 들리고, 내리칠 때는
             # 앞무릎이 깊게 굽어 골반이 내려앉는다 (몸통은 그 위에 앉는다).
             'legs': [((0.3, 22, 6, 0), (-0.3, -20, 6, -1)),
                      ((0.4, 26, 8, 1), (-0.4, -24, 14, -1)),
                      ((0.2, 20, 24, 0), (-0.2, -22, 10, -1)),
                      ((0.3, 34, 58, 0), (-0.5, -30, 16, -1)),
                      ((0.2, 22, 18, 0), (-0.3, -20, 10, -1))],
             # 반대팔 (몸 뒤) 이 앞으로 나간 양 — 감을 때 앞으로 뻗어 균형을 잡고,
             # 내리칠 때 뒤로 젖혀진다
             'far_arm': [3, 5, 1, -4, -2]},
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
            # 셔츠에 닿는 자리는 두르지 않는다 — 몸 앞을 지나는 팔은 셔츠와
            # 한 덩어리다(원근 단축). 주먹 둘레만은 둘러서 손이 또렷하게.
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


def swing_frame(direction, phase, spec_head):
    spec = SWING[direction]
    (fx, fy), (ex, ey), dx, sq, behind = spec['poses'][phase]
    g = G()
    if direction == 'side':
        # 발은 다섯 장 내내 같은 자리를 디디고, 무릎·골반이 칸마다 달라진다.
        # 몸통은 다리가 정한 골반 줄에 앉으므로 내리칠 때 저절로 주저앉는다.
        hr = legs_side(g, 0, 0, dx, sq, poses=spec['legs'][phase])
        sq = hr - (HIP_Y + 2)
        torso_side(g, sq, 0, dx, draw_arm=False, far_arm=spec['far_arm'][phase])
    elif direction == 'down':
        counter = (-1, -2, 0, 2, 1)[phase]
        step = (0, 1, 1, 0, 0)[phase]
        legs_down(g, step, dx, sq)
        torso_down(g, sq, counter, dx, skip=spec['skip'])
    else:
        legs_up(g, 0, dx, sq)
        torso_up(g, sq, 0, dx, skip=spec['skip'])
    sx, sy = spec['shoulder']
    # 내리치는 칸은 머리를 한 칸 더 움츠린다 — 어깨 사이로 목이 파묻히는
    # 크런치가 있어야 팔만 도는 게 아니라 온몸으로 찍는 느낌이 난다
    hb = sq + (1 if phase == 3 else 0)
    if behind:
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
        head(g, spec_head, hb, dx, direction == 'side')   # 머리가 팔을 덮는다
    else:
        head(g, spec_head, hb, dx, direction == 'side')
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

def head(g, spec, bob, lean=0, profile=False):
    """머리 = 얼굴 그림 + (귀) + 머리 모양 덧그림.
    spec = (얼굴, 머리덧그림 or None, 귀를 그릴까)
    profile: 옆모습 — 귀는 얼굴 그림 안에 있으니 양옆 조각을 안 붙인다"""
    art, hair, ears = spec
    top = HEAD_TOP + bob
    g.blit(art, HEAD_X + lean, top)
    if ears and not profile:                   # 눈높이 양옆에 볼록 두 칸
        for ex in (HEAD_X - 1, HEAD_X + HEAD_W):
            g.px(ex + lean, top + 9, 's')
            g.px(ex + lean, top + 10, 'S')
    if hair is not None:
        dy, hart = hair
        g.blit(hart, HEAD_X + lean, top + dy)


# ------------------------------------------------------------------- 결
# 한 색으로 넓게 채운 면은 도트가 아니라 비닐처럼 보인다. 옷·바지에 성근
# 얼룩을 흩어 **짜인 천의 결**을 낸다. 바둑판 위에만, 칸 좌표로만(프레임마다
# 다시 뽑으면 걸을 때 지글거린다). 살결·신발은 건드리지 않는다.
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
            if (x + y) % 2:
                continue
            depth = (y - SHIRT_Y) / max(1, GH - SHIRT_Y)
            r = _rough_hash(x, y)
            if r < 0.14 + depth * 0.14 and c in ROUGH_DARK:
                g.d[y][x] = ROUGH_DARK[c]
            elif r < 0.26 and c in ROUGH_LITE:
                g.d[y][x] = ROUGH_LITE[c]


BODY = {
    'down': (torso_down, legs_down),
    'side': (torso_side, legs_side),
    'up':   (torso_up, legs_up),
}


def frame(direction, spec_head, phase=None, bob=0):
    """한 칸을 그린다. phase 를 주면 걷기(LEG 표의 그 칸), 없으면 정지."""
    torso, legs = BODY[direction]
    g = G()
    if direction == 'side':
        lean = 0 if phase is None else 1       # 걸을 때 몸이 살짝 앞으로 쏠린다
        hip = 0 if phase is None else HIP[phase % WALK]
        if phase is not None:
            bob = round(hip_row_at(phase) - (HIP_Y + 2))
        arm = None if phase is None else ARM[phase % WALK]
        legs(g, 0, lean, 0, bob, phase, hip)
        # 몸통은 골반만큼 따라가지 않는다. 그 한 칸 차이가 허리다.
        torso(g, bob, 0, lean, arm=arm)
        head(g, spec_head, bob, lean, True)
    else:
        sf = 0 if phase is None else STRIDE_F[phase % WALK]
        pl = 0 if phase is None else PASS[phase % WALK]
        legs(g, sf, 0, bob, pl)
        torso(g, bob, sf)
        head(g, spec_head, bob)
    roughen(g)
    g.outline()
    return g


# ------------------------------------------------------- 네 벌 생성
# 몸·모션은 같고 머리만 다르다. 네 벌 모두 **같은 표준 팔레트**로 뽑는다 —
# 옷·살결·머리색은 게임이 외형 선택에 맞춰 실행 중에 갈아입힌다.
#   new_boy_     민머리 (귀 보임)
#   hair_short_  짧은 머리
#   hair_spiky_  삐죽 머리
#   player_f_    긴 머리 (여자 얼굴 — 눈꼬리 속눈썹, 귀는 머리카락에 가린다)
OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))


def head_set(face_d, face_s, hair, ears):
    return {
        'down': (face_d, hair['down'] if hair else None, ears),
        'side': (face_s, hair['side'] if hair else None, ears),
        'up': (HEAD_UP, hair['up'] if hair else None, ears),
        'down_blink': (closed_eyes(face_d, EYES_DOWN, LIDS_DOWN),
                       hair['down'] if hair else None, ears),
        'side_blink': (closed_eyes(face_s, EYES_SIDE, LIDS_SIDE),
                       hair['side'] if hair else None, ears),
    }


SETS = [
    ('', 'new_boy_', head_set(HEAD_DOWN, HEAD_SIDE, None, True)),
    ('short_', 'hair_short_', head_set(HEAD_DOWN, HEAD_SIDE, HAIR_SHORT, True)),
    ('spiky_', 'hair_spiky_', head_set(HEAD_DOWN, HEAD_SIDE, HAIR_SPIKY, True)),
    ('f_', 'player_f_', head_set(FACE_DOWN_F, FACE_SIDE_F, HAIR_LONG, False)),
]


def render_set(heads, ref_prefix, out_prefix):
    images = {}
    for d in ('down', 'side', 'up'):
        images[f'{d}_idle'] = frame(d, heads[d]).render()
        for i in range(WALK):
            images[f'{d}_walk_{i}'] = frame(d, heads[d], i, BOB[i]).render()
        for i in range(SWING_N):
            images[f'{d}_swing_{i}'] = swing_frame(d, i, heads[d]).render()
    for d in ('down', 'side'):                 # 눈 감은 정지 한 장씩
        images[f'{d}_blink'] = frame(d, heads[f'{d}_blink']).render()
    for k, im in images.items():
        im.save(os.path.join(REF, f'{ref_prefix}{k}.png'))
        im.save(os.path.join(OUT, f'{out_prefix}{k}.png'))
    return images


ALL = [(render_set(h, rp, op), rp) for rp, op, h in SETS]

# player.gd SWING_HAND_DOT에 옮겨 적을 주먹 좌표 (네 벌이 같은 골격이라 공용)
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

# 네 벌의 서기·깜빡임을 한 장에 — 얼굴을 견줘 보는 용도
_faces = []
for images, tag in ALL:
    _faces += [images['down_idle'], images['down_blink'], images['side_idle'], images['up_idle']]
_sheet = Image.new('RGB', (FW * 2 * len(_faces), FH * 2))
for i, fim in enumerate(_faces):
    base = Image.new('RGBA', (FW, FH), SAND + (255,))
    base.alpha_composite(fim)
    _sheet.paste(base.convert('RGB').resize((FW * 2, FH * 2), Image.NEAREST), (i * FW * 2, 0))
_sheet.save(os.path.join(REF, 'preview_faces.png'))

print('done: %d frames x %d sets + previews + gifs (sprites/에 설치됨)'
      % (len(ALL[0][0]), len(ALL)))
