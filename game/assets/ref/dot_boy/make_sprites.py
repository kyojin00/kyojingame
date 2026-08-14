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
# 프레임: 방향(down/side/up)마다 idle 1장 + walk 5장 + swing 4장.
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
HEAD_Y = 0               # 머리 꼭대기 (캔버스 위 여백까지 키로 쓴다)
SHIRT_Y = 19             # 셔츠 위 (목은 그 한 행 위)
HIP_Y = 31               # 바지 위 (엉덩이 띠 3행)
LEG_Y = 34               # 다리 기둥 시작
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
    ".OsHHHHHHHHHHsO.",
    "OsssHHHHHHHHsssO",
    "OsssssssssssssSO",
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
    ".OSHHHHHHHHHHsO.",
    "OSssHHHHHHHHsssO",
    "OSsssssssssssssO",
    "OSsssssssssssssO",
    "OSsssssssssssssO",
    "OSsssssss" "eee" "sssO",
    "OSsssssss" "ew" "ssssO",
    "OSsssssss" "ee" "ssssO",
    "OSsssssss" "ei" "ssssO",
    "OSssssrrsssssssO",
    ".OSsssssss" "mm" "ssO.",
    ".OssssssssssssO.",
    "..OssssssssssO..",
    "...OOssssssOO...",
]

HEAD_UP = [
    "....OOOOOOOO....",
    "..OOssssssssOO..",
    ".OssHHHHHHHHssO.",
    ".OsHHHHHHHHHHsO.",
    ".OsHHHHHHHHHHsO.",
    "OsssHHHHHHHHsssO",
    "OssssssssssssssO",
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

HEAD_X = 8


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
    g.vline(10 + dx, y + 1, y + 10, 'B')         # 팔과 몸 사이 솔기
    g.vline(21 + dx, y + 1, y + 10, 'B')
    g.hline(13 + dx, 18 + dx, y, 'B')            # 옷깃 (목 아래 그늘)
    for cx in (10 + dx, 21 + dx):                # 어깨·밑단 모서리를 깎는다
        g.px(cx, y, '.')                         # (깎인 자리는 윤곽선이 채워
        g.px(cx, y + 11, '.')                    #  둥근 어깨·허리가 된다)
    g.hline(15 + dx, 16 + dx, y + 2, 'B')        # 앞섶 단추 세 개
    g.hline(15 + dx, 16 + dx, y + 4, 'B')
    g.hline(15 + dx, 16 + dx, y + 6, 'B')
    g.vline(20 + dx, y + 6, y + 10, 'B')         # 오른쪽 아래 그늘 (입체)
    # 팔: 소매 3픽셀 폭 + 세 칸 손. 손끝이 엉덩이 띠 바로 위(아랫단)까지
    # 온다. 앞으로 흔들면 소매가 늘어나며 내려가고 뒤로 가면 접히며
    # 올라간다 — 어깨는 늘 몸통에 붙어 있다.
    # (4칸으로 키워 봤더니 정면 어깨가 벌어져 어색했다 — 옆모습만 4칸.)
    for sx, sw, side in ((7, swing, 'left'), (22, -swing, 'right')):
        if side == skip:
            continue
        sx += dx
        dy = (1 if sw >= 2 else 0) + (1 if sw >= 3 else 0) \
            - (1 if sw <= -2 else 0) - (1 if sw <= -3 else 0)
        g.rect(sx, y + 1, sx + 2, y + 6 + dy, 'b')
        g.vline(sx if side == 'left' else sx + 2, y + 1, y + 6 + dy,
                'L' if side == 'left' else 'B')
        g.hline(sx, sx + 2, y + 7 + dy, 'B')                     # 소매단
        g.rect(sx, y + 8 + dy, sx + 2, y + 10 + dy, 's')         # 손
        g.hline(sx + 1, sx + 2, y + 10 + dy, 'S')                # 손 그늘
        out = sx if side == 'left' else sx + 2   # 바깥쪽 열
        g.px(out, y + 1, '.')                    # 어깨 소매 모서리 깎기
        g.px(out, y + 10 + dy, '.')              # 주먹 끝 모서리 깎기


def legs_down(g, stride, dx=0, sq=0):
    """앞모습 다리. stride: 화면 왼쪽 다리가 앞으로 나간 양 -3..+3
    dx/sq: 휘두르기 때 몸이 쏠리고 주저앉는 양 — 엉덩이는 몸통을 따라가고
    발은 디딘 자리에 남아, 다리가 엉덩이에서 발로 기울어진다."""
    g.rect(10 + dx, HIP_Y + sq, 21 + dx, HIP_Y + 2 + sq, 'p')   # 엉덩이 띠
    g.hline(10 + dx, 21 + dx, HIP_Y + sq, 'P')  # 셔츠 아랫단 그늘
    g.rect(15 + dx, HIP_Y + 2 + sq, 16 + dx, HIP_Y + 2 + sq, 'P')
    g.px(10 + dx, HIP_Y + sq, '.')              # 엉덩이 띠 모서리 깎기
    g.px(21 + dx, HIP_Y + sq, '.')
    for x0, s in ((10, stride), (17, -stride)):
        lift = min(3, -s) if s < 0 else 0      # 뒤로 간 다리는 들려 짧아진다
        pc = 'P' if lift else 'p'              # 들린 다리는 그늘에 잠긴다
        inner = x0 + 4 if x0 == 10 else x0     # 가랑이 쪽 그늘 열
        top = LEG_Y + sq
        # 들린 다리는 무릎 아래가 안쪽으로 접힌다 (정면에서 본 무릎 굽힘)
        bend = (1 if x0 == 10 else -1) if lift >= 2 else 0
        knee_row = (top + GROUND - lift) // 2
        outer = x0 if x0 == 10 else x0 + 4     # 빛 받는 바깥 열 (왼쪽 다리만)
        for yy in range(top, GROUND - 3 - lift):
            t = (yy - (HIP_Y + 2 + sq)) / (GROUND - HIP_Y - 2 - sq)
            off = round(dx * (1 - t))          # 엉덩이 쪽만 dx만큼 쏠린다
            if yy > knee_row:
                off += bend
            g.rect(x0 + off, yy, x0 + 4 + off, yy, pc)
            g.px(inner + off, yy, 'P')
            if not lift and x0 == 10:
                g.px(outer + off, yy, 'q')     # 왼쪽 다리 하이라이트
            if yy in (top, GROUND - 4 - lift):
                g.hline(x0 + off, x0 + 4 + off, yy, 'P')   # 허리·발목 접단
        g.rect(x0 + bend, GROUND - 3 - lift, x0 + 4 + bend, GROUND - 1 - lift, 'k')
        g.hline(x0 + 1 + bend, x0 + 3 + bend, GROUND - lift, 'K')  # 바닥은 좁게 (둥근 신발)
        g.px((x0 if x0 == 17 else x0 + 4) + bend, GROUND - 1 - lift, 'K')
        g.px(x0 + 2 + bend, GROUND - 3 - lift, 'p')        # 신발 코 광
        g.px(x0 + 3 + bend, GROUND - 3 - lift, 'p')


def torso_side(g, bob, swing, lean=0, draw_arm=True):
    """옆모습 몸통+팔(오른쪽 보기). swing: 팔이 앞으로 나간 양 -3..+3"""
    y = SHIRT_Y + bob
    c = 15 + lean                              # 몸 중심 (반 칸 왼쪽)
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
    if not draw_arm:
        return
    # 보이는 팔 하나 — 어깨에서 손까지 진자처럼 젓는다. 앞모습 팔과 같은
    # 길이(어깨 y+1 ~ 손끝 y+10, 엉덩이 높이)로 내린다 — 짧으면 티가 난다.
    # 몸판과 같은 파랑이라, 획을 통째로 모아 둘레를 윤곽선으로 한 번에
    # 두른다 (픽셀마다 낱개로 두르면 대각선에서 조각조각 깨져 보인다).
    hy = y + 8 - (1 if abs(swing) >= 2 else 0) - (1 if abs(swing) >= 3 else 0)
    # 폭은 다섯 칸 — 세 칸은 몸통(10칸)에 대면 젓가락처럼 얇았다. 대신
    # 밝은 하이라이트 줄은 넣지 않는다. 전에 어색했던 건 두께가
    # 아니라 밝은 줄 때문에 팔이 몸에서 튀어 보여서였다 — 몸판 색에
    # 그늘 한 줄만 얹으면 두꺼워도 몸에 자연스럽게 붙는다.
    # 손은 소매보다 한 칸 좁게(네 칸) — 소매에서 손으로 자연스럽게 좁아진다.
    cells = {}
    for yy in range(y + 1, hy):
        t = (yy - (y + 1)) / max(1, hy - 1 - (y + 1))
        x = c - 2 + round(swing * t)
        for j, cc in enumerate(('B', 'b', 'b', 'b', 'b')):
            cells[(x + j, yy)] = 'B' if yy == hy - 1 else cc     # 마지막 줄은 소매단
    hx = c - 1 + swing
    for j in range(4):
        for k in range(3):
            cells[(hx + j, hy + k)] = 's'                        # 손 (네 칸)
    cells[(hx + 2, hy + 2)] = 'S'
    cells[(hx + 3, hy + 2)] = 'S'
    for (x, yy) in cells:                                        # 획 둘레 윤곽선
        for nx, ny in ((x - 1, yy), (x + 1, yy), (x, yy - 1), (x, yy + 1)):
            if (nx, ny) in cells or not (0 <= nx < GW and 0 <= ny < GH):
                continue
            if g.d[ny][nx] != '.':
                g.d[ny][nx] = 'O'
    for (x, yy), cc in cells.items():
        g.px(x, yy, cc)


def legs_side(g, stride, lean=0, dx=0, sq=0):
    """옆모습 다리. stride: 가까운 다리가 앞으로 나간 양 -3..+3
    허벅지는 엉덩이에 붙어 있고 발끝으로 갈수록 stride 만큼 기울어진다.
    dx/sq: 휘두르기 쏠림·주저앉음 (엉덩이만 따라가고 발은 제자리)."""
    c = 15 + lean
    g.rect(c - 4 + dx, HIP_Y + sq, c + 5 + dx, HIP_Y + 2 + sq, 'p')
    g.hline(c - 4 + dx, c + 5 + dx, HIP_Y + sq, 'P')   # 셔츠 아랫단 그늘
    g.hline(c - 4 + dx, c + 5 + dx, HIP_Y + 2 + sq, 'P')  # 가랑이 그늘 줄 —
    # 띠(10칸)와 다리(7칸) 사이 단차를 그늘로 눌러 다리가 그늘 속에서
    # 나오는 것처럼 잇는다. 허벅지도 이 줄까지 겹쳐 세로로 이어진다.
    g.px(c - 4 + dx, HIP_Y + sq, '.')          # 엉덩이 띠 모서리 깎기
    g.px(c + 5 + dx, HIP_Y + sq, '.')
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
        knee_off = off * (0.35 if back else 0.55)
        foot_off = round(off * 1.35) if back else off
        pc, kc = ('P', 'K') if shade else ('p', 'k')
        bot = GROUND - lift
        hip_row = HIP_Y + 2 + sq
        knee_row = (hip_row + bot) // 2 + 1
        for yy in range(LEG_Y - 1 + sq, bot + 1):   # 띠 아래 줄부터 겹쳐 잇는다
            if yy <= knee_row:                 # 허벅지
                f = (yy - hip_row) / max(1, knee_row - hip_row)
                o = knee_off * f
            else:                              # 정강이
                f = (yy - knee_row) / max(1, bot - knee_row)
                o = knee_off + (foot_off - knee_off) * f
            t = (yy - hip_row) / (GROUND - hip_row)
            x = 15 + round(o + dx * (1 - t)) + lean
            cc = pc if yy <= bot - 4 else kc
            if yy == bot:
                g.rect(x - 2, yy, x + 2, yy, cc)   # 바닥은 좁게 (둥근 발)
            else:
                g.rect(x - 3, yy, x + 3, yy, cc)
            if not shade and yy <= bot - 4:
                g.px(x - 3, yy, 'P')           # 가까운 다리 뒤쪽 그늘 선
                if yy == bot - 4:
                    g.rect(x - 2, yy, x + 3, yy, 'P')   # 발목 접단
                else:
                    g.px(x + 3, yy, 'q')       # 앞쪽 하이라이트
            if not shade and yy == bot - 3:
                g.px(x + 2, yy, 'p')           # 신발 코 광
        x = 15 + foot_off + lean
        if off > 0:
            g.px(x + 4, bot - 1, kc)           # 앞으로 디딘 발끝
        elif off < 0:
            g.px(x - 4, bot - 1, kc)           # 뒤로 차는 뒤꿈치


def torso_up(g, bob, swing, dx=0, skip=None):
    y = SHIRT_Y + bob
    g.rect(13 + dx, y - 1, 18 + dx, y - 1, 'S')  # 목덜미
    g.rect(10 + dx, y, 21 + dx, y + 11, 'b')
    g.hline(10 + dx, 21 + dx, y, 'B')            # 어깨 그늘
    g.hline(10 + dx, 21 + dx, y + 11, 'B')
    g.rect(11 + dx, y + 1, 12 + dx, y + 4, 'L')
    g.vline(11 + dx, y + 5, y + 10, 'L')
    g.vline(10 + dx, y + 1, y + 10, 'B')         # 팔과 몸 사이 솔기
    g.vline(21 + dx, y + 1, y + 10, 'B')
    g.hline(13 + dx, 18 + dx, y + 6, 'B')        # 등판 주름
    for cx in (10 + dx, 21 + dx):                # 어깨·밑단 모서리 깎기
        g.px(cx, y, '.')
        g.px(cx, y + 11, '.')
    for sx, sw, side in ((7, -swing, 'left'), (22, swing, 'right')):
        if side == skip:                         # 뒤모습이라 팔 위상이 좌우 반대
            continue
        sx += dx
        dy = (1 if sw >= 2 else 0) + (1 if sw >= 3 else 0) \
            - (1 if sw <= -2 else 0) - (1 if sw <= -3 else 0)
        g.rect(sx, y + 1, sx + 2, y + 6 + dy, 'b')
        g.vline(sx if side == 'left' else sx + 2, y + 1, y + 6 + dy,
                'L' if side == 'left' else 'B')
        g.hline(sx, sx + 2, y + 7 + dy, 'B')
        g.rect(sx, y + 8 + dy, sx + 2, y + 10 + dy, 's')
        g.hline(sx + 1, sx + 2, y + 10 + dy, 'S')
        out = sx if side == 'left' else sx + 2
        g.px(out, y + 1, '.')                    # 어깨 소매 모서리 깎기
        g.px(out, y + 10 + dy, '.')              # 주먹 끝 모서리 깎기


def legs_up(g, stride, dx=0, sq=0):
    legs_down(g, stride, dx, sq)               # 뒤모습 다리는 앞모습과 같은 규칙


# --------------------------------------------------------------- 휘두르기
# 방향당 4장: 감기 시작 · 다 감음 · 내리침 · 되돌아옴.
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
SWING = {
    # 앞모습: 왼쪽 위로 감았다가 오른쪽 아래로 내리친다
    'down': {'skip': 'left', 'shoulder': (9, 21),
             'poses': [((5, 16), (5, 19), -2, 0, False),
                       ((3, 7), (2, 14), -3, 0, False),
                       ((22, 25), (16, 21), 2, 2, False),
                       ((20, 23), (14, 21), 0, 0, False)]},
    # 뒷모습: 등을 보이는 캐릭터의 「앞」은 화면 위쪽 — 옆에서 감아올려
    # 머리 너머로 내리친다. 내리치는 칸의 팔·주먹은 머리가 가린다.
    'up':   {'skip': 'right', 'shoulder': (22, 21),
             'poses': [((24, 14), (26, 17), 2, 0, False),
                       ((24, 7), (27, 14), 3, 0, False),
                       ((18, 8), (20, 14), -2, 2, True),
                       ((24, 11), (26, 15), 0, 0, False)]},
    # 옆모습(오른쪽 보기): 뒤로 감았다가 앞으로 내리친다
    'side': {'skip': None, 'shoulder': (15, 21),
             'poses': [((6, 14), (8, 18), -2, 0, False),
                       ((6, 8), (6, 14), -3, 0, False),
                       ((24, 30), (23, 26), 3, 2, False),
                       ((23, 24), (18, 24), 2, 0, False)]},
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
    for (x, y) in cells:                       # 획 둘레 윤곽선
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) in cells or not (0 <= nx < GW and 0 <= ny < GH):
                continue
            if g.d[ny][nx] != '.':
                g.d[ny][nx] = 'O'
    for (x, y) in cells:
        if (x, y) in hand:
            g.px(x, y, 's')
        else:                                  # 손에 닿는 줄은 소매단
            near = any((x + mx, y + my) in hand
                       for mx in (-1, 0, 1) for my in (-1, 0, 1))
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
        legs_down(g, 0, dx, sq)
        torso_down(g, sq, 0, dx, skip=spec['skip'])
    else:
        legs_up(g, 0, dx, sq)
        torso_up(g, sq, 0, dx, skip=spec['skip'])
    art = PARTS[direction][0]
    sx, sy = spec['shoulder']
    if behind:
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
        head(g, art, sq, dx)                   # 머리가 팔을 덮고 도구만 저편에
    else:
        head(g, art, sq, dx)
        arm_stroke(g, sx + dx, sy + sq, fx, fy, ex, ey)
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
    assert len(_art) == 18 and all(len(r) == 16 for r in _art), \
        [(i, len(r)) for i, r in enumerate(_art) if len(r) != 16]


def head(g, art, bob, lean=0):
    g.blit(art, HEAD_X + lean, HEAD_Y + bob)


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
