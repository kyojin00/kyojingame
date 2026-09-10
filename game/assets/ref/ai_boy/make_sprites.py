# -*- coding: utf-8 -*-
# 주인공 스프라이트 생성기 4판 — **AI 시트(3세대) 그림을 밑그림으로** 쓴다.
#
# 코드가 도트를 직접 그린 2·3판(dot_boy)은 눈매를 아무리 고쳐도 「못생겼다」
# 「이상하다」는 말을 들었다. 사람 손맛(AI 시트)이 든 그림을 쓰되, 게임이 옷·살결·
# 머리색을 실행 중에 갈아입히려면(game_data.recolor_player_image) 픽셀 색이
# **표준 팔레트와 정확히** 같아야 한다. 그래서 여기서는 그리지 않고 **분류한다**:
#
#   src/<방향>_<동작>.png  (3세대 결과물 30장, 28색)
#     -> 픽셀마다 「무엇의 색인가」를 가려 팔레트 문자로 바꾼다
#        · 검정 계열 = 윤곽선 O   · 눈 안의 어두운 청록 = 눈망울 e
#        · 갈색 계열 = 덩어리의 **자리**로 머리(h/j/g) · 바지(p/q/P) · 신발(k/K)
#          (색만으로는 못 가른다 — 머리·바지·부츠가 다 갈색이다.
#           머리는 위, 부츠는 아래, 나머지는 바지. 눈 안의 갈색은 홍채 i)
#        · 살결 계열 = s/H/S, 셔츠 계열 = b/L/B
#        · 셔츠 그늘과 살결 그늘이 같은 색을 나눠 쓴 데(206,169,140 등)는
#          **이웃 다수결** — 살결 옆이면 S, 셔츠 옆이면 B
#        · 눈 근처의 흰색·크림색은 눈 반짝이 w (셔츠 밝은 면 L 이 아니라)
#     -> 머리 모양·깜빡임·속눈썹은 그 위에 덧그린다
#
# 네 벌: new_boy_(짧은 머리 = 그림 그대로) · hair_short_(단발) · hair_spiky_(삐죽) ·
#        player_f_(긴 머리 + 속눈썹). 방향마다 idle 1 + walk 5 + swing 5(4장에서
#        「다 감음」을 둘로) + 앞·옆 blink 1.
#
# 실행:  python3 make_sprites.py     (Pillow 필요)
import os
from PIL import Image

REF = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(REF, 'src')
OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))
FW, FH = 128, 192

PAL = {
    'O': (54, 33, 26), 's': (243, 159, 138), 'S': (213, 116, 98), 'H': (250, 192, 170),
    'e': (66, 32, 30), 'i': (136, 70, 42), 'w': (246, 242, 234), 'r': (235, 128, 114),
    'm': (170, 84, 66), 'b': (58, 88, 168), 'B': (38, 58, 120), 'L': (94, 126, 200),
    'p': (134, 88, 46), 'P': (98, 62, 32), 'q': (158, 108, 58), 'h': (118, 72, 40),
    'j': (152, 100, 56), 'g': (86, 52, 30), 'k': (82, 53, 33), 'n': (68, 44, 29),
    'K': (56, 37, 25),
}

# ---- 3세대 28색의 갈래 ----
#
# 밑그림은 **살결과 옷이 색을 나눠 쓴다** — 옷이 크림색이라 살결 하이라이트와
# 같은 값이 여러 개다. 그래서 색만 보고 정하지 않는다:
#   ① 확실한 색 둘만 못 박는다 — 분홍(249,194,151)은 살결, 거의 흰색은 옷
#   ② 나머지 애매한 색은 **가장 가까운 확실한 색**의 갈래를 따른다
#      (윤곽선·머리카락을 넘지 않고 번져 간다 — 소매와 손이 안 섞인다)
#   ③ 그래도 못 닿은 칸은 이웃 다수결, 그것도 없으면 살결
# 예전에는 5x5 이웃 다수결로 정했는데, 옷단·소매 끝처럼 확실한 색이 하나도
# 없는 자리에서 뒤집혀 **얼굴에 파란 점, 셔츠에 살구색 얼룩**이 흩뿌려졌다.
OUTLINE = {(3, 2, 2), (7, 10, 9), (13, 5, 2), (22, 12, 6), (32, 15, 8), (56, 45, 32)}
EYE_DARK = {(8, 22, 22), (15, 34, 34)}
BROWN_L = {(137, 78, 42), (159, 88, 50)}
BROWN_M = {(115, 60, 33), (122, 65, 35)}
BROWN_D = {(103, 54, 29), (88, 45, 24), (74, 38, 21), (64, 33, 19)}
BROWN_X = {(56, 27, 15), (41, 23, 13)}
BROWN = BROWN_L | BROWN_M | BROWN_D | BROWN_X
SURE = {(249, 194, 151): 'skin', (252, 246, 230): 'shirt'}
# 애매한 색 -> {갈래: 팔레트 문자}
FLESH = {
    (249, 194, 151): {'skin': 's', 'shirt': 'b'},
    (252, 246, 230): {'skin': 'H', 'shirt': 'L'},
    (241, 206, 174): {'skin': 'H', 'shirt': 'L'},
    (248, 232, 211): {'skin': 'H', 'shirt': 'b'},
    (206, 169, 140): {'skin': 'S', 'shirt': 'B'},
    (217, 140, 101): {'skin': 'S', 'shirt': 'B'},
    (192, 110, 72): {'skin': 'S', 'shirt': 'B'},
    (169, 135, 109): {'skin': 'S', 'shirt': 'B'},
    (127, 100, 78): {'skin': 'S', 'shirt': 'B'},
    (91, 69, 51): {'skin': 'S', 'shirt': 'B'},
}
HAIR_CH = 'hjg'
EYE_CH = 'eiw'
FACE_CH = 'eiwm'          # 정리 패스가 건드리면 안 되는 얼굴 부속


def _is(c, chars):
    return c is not None and c in chars


class Grid:
    def __init__(self, w=FW, h=FH):
        self.w, self.h = w, h
        self.d = [[None] * w for _ in range(h)]

    def at(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.d[y][x]
        return None

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.d[y][x] = c

    def copy(self):
        g = Grid(self.w, self.h)
        g.d = [row[:] for row in self.d]
        return g

    def render(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        o = im.load()
        for y in range(self.h):
            for x in range(self.w):
                c = self.d[y][x]
                if c is not None:
                    o[x, y] = PAL[c] + (255,)
        return im


def _components(cells):
    """(x,y) 집합을 8방향 연결 덩어리로 나눈다."""
    cells = set(cells)
    out = []
    while cells:
        seed = cells.pop()
        st = [seed]
        comp = [seed]
        while st:
            cx, cy = st.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (cx + dx, cy + dy)
                    if q in cells:
                        cells.remove(q)
                        st.append(q)
                        comp.append(q)
        out.append(comp)
    return out


# 눈 상자 — 서기 프레임에서 손으로 읽었다 (왼쪽 위, 오른쪽 아래). 다른 프레임은
# 머리(앞머리 덩어리) 상자가 서기 프레임에서 옮겨 간 만큼 같이 옮긴다.
# (색으로 눈을 찾으려 해 봤지만 이 그림은 눈 테가 윤곽선과 같은 검정이고 홍채가
#  머리카락과 같은 갈색이라, 앞머리 그늘과 눈을 못 갈랐다)
EYE_BOXES = {'down': [(46, 58, 58, 69), (69, 57, 82, 69)], 'side': [(77, 53, 86, 63)], 'up': []}
_HAIR_ORIGIN = {}


def _brown_kinds(im):
    """갈색 덩어리마다 머리/바지/신발 — (kind 사전, 머리 칸들, top, hgt, 불투명 칸들)"""
    W, H = im.size
    px = im.load()
    opaque = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 0]
    top = min(y for _, y in opaque)
    bot = max(y for _, y in opaque)
    hgt = bot - top
    browns = [(x, y) for (x, y) in opaque if px[x, y][:3] in BROWN]
    kind = {}
    hair_cells = []
    for comp in _components(browns):
        ys = [y for _, y in comp]
        my = sum(ys) / len(ys)
        if len(comp) < 6:
            k = 'small'
        elif min(ys) < top + 0.30 * hgt:
            k = 'hair'
        elif max(ys) > top + 0.90 * hgt and (my - top) / hgt > 0.75:
            k = 'boot'
        else:
            k = 'short'
        if k == 'hair':
            hair_cells += comp
        for c in comp:
            kind[c] = (k, len(comp))
    return kind, hair_cells, top, hgt, opaque


def classify(im, view):
    """밑그림 한 장 -> (팔레트 문자 격자, 턱 밑 줄, 눈 상자들)."""
    W, H = im.size
    px = im.load()
    g = Grid(W, H)
    kind, hair_cells, top, hgt, opaque = _brown_kinds(im)
    hair_rows = [y for _, y in hair_cells]
    head_bot = (max(hair_rows) + 30) if hair_rows else top + 70
    # 눈 상자를 머리가 옮겨 간 만큼 같이 옮긴다
    hx0 = min(x for x, _ in hair_cells) if hair_cells else 0
    hy0 = min(hair_rows) if hair_rows else 0
    if view not in _HAIR_ORIGIN:
        idle = Image.open(os.path.join(SRC, view + '_idle.png')).convert('RGBA')
        _, ic, _, _, _ = _brown_kinds(idle)
        _HAIR_ORIGIN[view] = (min(x for x, _ in ic), min(y for _, y in ic))
    ox, oy = hx0 - _HAIR_ORIGIN[view][0], hy0 - _HAIR_ORIGIN[view][1]
    boxes = [(bx0 + ox, by0 + oy, bx1 + ox, by1 + oy) for (bx0, by0, bx1, by1) in EYE_BOXES[view]]
    eyes = set()
    for (bx0, by0, bx1, by1) in boxes:
        for x in range(bx0 - 1, bx1 + 2):
            for y in range(by0 - 1, by1 + 2):
                eyes.add((x, y))
    eye_bot = max((b[3] for b in boxes), default=head_bot - 26)
    # ---- ① 확실한 것부터: 윤곽선 · 눈 · 머리/바지/신발 · 입 ----
    flesh = []
    for (x, y) in opaque:
        c = px[x, y][:3]
        if (x, y) in eyes:
            if c in OUTLINE or c in EYE_DARK:
                g.px(x, y, 'e')
            elif c in BROWN or c in ((91, 69, 51), (127, 100, 78)):
                g.px(x, y, 'i')
            elif c in ((252, 246, 230), (248, 232, 211), (206, 169, 140), (169, 135, 109)):
                g.px(x, y, 'w')
            elif c == (249, 194, 151):
                g.px(x, y, 's')
            else:
                g.px(x, y, 'S')
            continue
        if c in OUTLINE or c in EYE_DARK:
            g.px(x, y, 'O')
        elif c in BROWN:
            k, n = kind[(x, y)]
            # 얼굴 안(눈 밑~턱)의 작은 갈색 조각은 **입**이다. 그냥 두면 바지색이 된다
            if n < 60 and eye_bot < y < head_bot:
                g.px(x, y, 'm')
            elif k == 'hair' or (k == 'small' and y <= head_bot - 30):
                g.px(x, y, 'j' if c in BROWN_L else 'h' if c in BROWN_M else 'g' if c in BROWN_D else 'O')
            elif k == 'boot' or (k == 'small' and y > top + 0.85 * hgt):
                g.px(x, y, 'k' if c in (BROWN_L | BROWN_M) else 'K' if c in BROWN_D else 'O')
            else:
                g.px(x, y, 'q' if c in BROWN_L else 'p' if c in BROWN_M else 'P' if c in BROWN_D else 'O')
        elif c in FLESH:
            flesh.append((x, y))
        else:
            raise SystemExit('모르는 색 %s' % (c,))
    # ---- ② 살결이냐 옷이냐: **덩어리째** 정한다 ----
    #
    # 이 그림은 부위마다 윤곽선이 둘려 있어, 윤곽선을 넘지 않고 이어진 칸을
    # 모으면 얼굴·소매·손·다리·셔츠가 저절로 따로 떨어진다. 덩어리 안에서
    # 살결 바탕색(분홍)과 옷 바탕색(크림·흰)을 세어 많은 쪽으로 통째로 정한다.
    #
    # 칸마다 「가장 가까운 확실한 색」으로 정해 봤더니 두 번 틀렸다 — 셔츠
    # 한가운데 섞인 분홍 한 점에서 번져 옷단이 살구색이 됐고, 흰 칸이 몇 개뿐인
    # 프레임에서는 옆 팔에서 번져 와 몸통이 통째로 살색이 됐다. 덩어리로 세면
    # 점 몇 개는 표에서 진다.
    fset = set(flesh)
    seen = set()
    mat = {}
    undecided = []
    BASE_SKIN = (249, 194, 151)
    BASE_SHIRT = ((248, 232, 211), (252, 246, 230))
    for c0 in flesh:
        if c0 in seen:
            continue
        st = [c0]
        seen.add(c0)
        comp = []
        while st:
            x, y = st.pop()
            comp.append((x, y))
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n in fset and n not in seen:
                    seen.add(n)
                    st.append(n)
        skin_pts = [c for c in comp if px[c[0], c[1]][:3] == BASE_SKIN]
        shirt_pts = [c for c in comp if px[c[0], c[1]][:3] in BASE_SHIRT]
        if len(skin_pts) >= 12 and len(shirt_pts) >= 12:
            # 목에서 얼굴과 셔츠가 이어 붙은 덩어리다 — 안에서 다시 가른다.
            # 바탕색 씨앗에서 번져 가되, **뭉친 씨앗만** 쓴다 (셔츠에 섞인 분홍
            # 한 점에서 번지면 옷단이 살구색이 된다)
            cset = set(comp)
            q = []
            for want, pts in (('skin', skin_pts), ('shirt', shirt_pts)):
                for sub in _components(pts):
                    if len(sub) < 4:
                        continue
                    for c in sub:
                        mat[c] = want
                        q.append(c)
            head = 0
            while head < len(q):
                x, y = q[head]; head += 1
                m = mat[(x, y)]
                for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if n in cset and n not in mat:
                        mat[n] = m
                        q.append(n)
            left = [c for c in comp if c not in mat]
            if left:
                undecided.append(left)
            continue
        if len(skin_pts) == len(shirt_pts):
            undecided.append(comp)
            continue
        m = 'skin' if len(skin_pts) > len(shirt_pts) else 'shirt'
        for c in comp:
            mat[c] = m
    # ---- ③ 바탕색이 하나도 없는 덩어리 (머리카락 속 하이라이트 · 그늘 조각) ----
    for comp in undecided:
        vote = {}
        for (x, y) in comp:
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    k2 = mat.get((x + dx, y + dy))
                    if k2:
                        vote[k2] = vote.get(k2, 0) + 1
                    elif _is(g.at(x + dx, y + dy), HAIR_CH):
                        vote['hair'] = vote.get('hair', 0) + 1
        m = max(vote, key=vote.get) if vote else 'skin'
        for c in comp:
            mat[c] = m
    HAIR_MAP = {'s': 'h', 'H': 'j', 'S': 'g', 'b': 'h', 'L': 'j', 'B': 'g'}
    for (x, y) in flesh:
        m = mat[(x, y)]
        if m == 'hair':
            g.px(x, y, HAIR_MAP[FLESH[px[x, y][:3]]['skin']])
        else:
            g.px(x, y, FLESH[px[x, y][:3]][m])
    tidy(g, eyes)
    return g, head_bot, boxes


# ---------------------------------------------------------------- 손도트 정리
#
# 밑그림은 붓으로 그린 티가 남아 있다 — 면 한가운데 홀로 뜬 점, 한 칸씩
# 어긋난 계단, 안쪽에 낀 검은 티끌. 도트를 손으로 찍는 사람은 이런 걸 안 남긴다.
# 눈·입은 건드리지 않는다 (두 칸짜리라 「티끌」로 보여 지워진다).

def tidy(g, eyes, rounds=2):
    for _ in range(rounds):
        _kill_specks(g, eyes)
    _kill_inner_outline(g, eyes)
    _close_outline(g)


def _kill_specks(g, eyes):
    """이웃 여덟 중 다섯 이상이 한 색이고 나와 다르면 그 색으로 — 홀로 뜬 점을 지운다."""
    out = []
    for y in range(g.h):
        for x in range(g.w):
            c = g.d[y][x]
            if c is None or (x, y) in eyes or _is(c, FACE_CH):
                continue
            vote = {}
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    n = g.at(x + dx, y + dy)
                    if n is not None and not _is(n, FACE_CH):
                        vote[n] = vote.get(n, 0) + 1
            if not vote:
                continue
            top = max(vote, key=vote.get)
            if top != c and vote[top] >= 5:
                out.append((x, y, top))
    for x, y, c in out:
        g.px(x, y, c)


def _kill_inner_outline(g, eyes):
    """면 안에 낀 검은 티끌 — 실루엣에 닿지 않고 이웃 윤곽선도 둘 미만이면 지운다."""
    out = []
    for y in range(g.h):
        for x in range(g.w):
            if g.d[y][x] != 'O' or (x, y) in eyes:
                continue
            edge = False
            nb = {}
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = g.at(x + dx, y + dy)
                    if n is None:
                        edge = True
                    elif n == 'O':
                        nb['O'] = nb.get('O', 0) + 1
                    elif not _is(n, FACE_CH):
                        nb[n] = nb.get(n, 0) + 1
            if edge or nb.get('O', 0) >= 2:
                continue
            body = {k: v for k, v in nb.items() if k != 'O'}
            if body:
                out.append((x, y, max(body, key=body.get)))
    for x, y, c in out:
        g.px(x, y, c)


def _close_outline(g):
    """실루엣에 뚫린 윤곽선을 메운다 — 빈칸인데 몸이 두 칸 이상 닿아 있으면 윤곽선."""
    out = []
    for y in range(g.h):
        for x in range(g.w):
            if g.d[y][x] is not None:
                continue
            n = sum(1 for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
                    if g.at(x + dx, y + dy) not in (None, 'O'))
            if n >= 2:
                out.append((x, y))
    for x, y in out:
        g.px(x, y, 'O')


# ---------------------------------------------------------------- 덧그림 도구

def hair_bbox(g):
    """머리카락 **가장 큰 덩어리**의 상자 — 옷에 찍힌 갈색 티끌 한 점이 상자를 늘리지 않게."""
    cells = [(x, y) for y in range(g.h) for x in range(g.w) if _is(g.d[y][x], HAIR_CH)]
    comp = max(_components(cells), key=len)
    xs = [x for x, _ in comp]
    ys = [y for _, y in comp]
    return min(xs), min(ys), max(xs), max(ys)


def fill_region(g, cells, body='h', light=None, dark=None):
    """머리채 한 덩어리를 칠한다 — 안은 h, light 쪽 가장자리엔 j, dark 쪽엔 g, 둘레는 O."""
    cells = set(cells)
    for (x, y) in cells:
        g.px(x, y, body)
    if light is not None:
        for (x, y) in cells:
            if all((x + k * light, y) in cells for k in range(1, 4)) \
                    and not all((x + k * light, y) in cells for k in range(1, 7)):
                g.px(x, y, 'j')
    if dark is not None:
        for (x, y) in cells:
            if (x + dark, y) not in cells or (x + 2 * dark, y) not in cells:
                g.px(x, y, 'g')
    for (x, y) in cells:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) not in cells:
                g.px(x, y, 'O')
                break


def lock_cells(x0, w, y0, y1, taper=0.0, round_end=6, lean=0.0, tips=2):
    """세로 머리채 — x0 에서 폭 w, y0 부터 y1 까지. 가장자리는 살짝 물결치고
    끝은 뾰족한 가닥 tips 개로 갈라진다. lean: 아래로 갈수록 x 가 밀리는 양(칸/줄)."""
    import math
    out = set()
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        ww = w * (1 - taper * t)
        cx = x0 + w / 2.0 + lean * (y - y0) + math.sin(y * 0.35) * 0.8
        xa, xb = cx - ww / 2.0, cx + ww / 2.0
        if y > y1 - round_end:
            # 끝가닥: 폭을 tips 개의 삼각형으로 나눠 아래로 갈수록 좁힌다
            k = (y - (y1 - round_end)) / float(round_end)
            seg = (xb - xa) / tips
            for i in range(tips):
                c = xa + seg * (i + 0.5)
                hw = seg / 2.0 * (1 - k)
                for x in range(int(round(c - hw)), int(round(c + hw)) + 1):
                    out.add((x, y))
        else:
            for x in range(int(round(xa)), int(round(xb))):
                out.add((x, y))
    return out


def _strand(n):
    """가닥 무늬용 해시 — 같은 열은 늘 같은 값이라 프레임마다 안 지글거린다."""
    h = (n * 73856093) & 0x7FFFFFFF
    h = (h ^ (h >> 13)) & 0x7FFFFFFF
    return ((h * 1274126177) & 0x7FFFFFFF) / 2147483647.0


def draw_lock(g, cells, light=-1):
    """머리채를 **세로 가닥**으로 칠한다.
    긴 머리는 결이 위에서 아래로 흐른다 — 열마다 바탕(h) · 가닥 그늘(g) ·
    윤기(j)를 정해 두고 쭉 내려 긋는다. 열 번호로만 정하므로 프레임이 바뀌어도
    무늬가 안 흔들린다. (본 머리에서 조각을 떠다 타일처럼 깔아 봤더니 같은
    무늬가 반복돼 갈매기 무늬 벽지처럼 보였다.)
    빛 쪽 가장자리는 윤기, 반대쪽 가장자리는 그늘, 둘레는 윤곽선."""
    cells = set(cells)
    rows = {}
    for (x, y) in cells:
        rows.setdefault(y, []).append(x)
    for (x, y) in cells:
        xs = rows[y]
        xa, xb = min(xs), max(xs)
        # 가닥은 곧게 내려오지 않고 아래로 갈수록 조금씩 휜다 — 빗자루가 안 되게
        r = _strand(x + (y // 14))
        c = 'g' if r < 0.44 else ('j' if r > 0.93 else 'h')
        near = x - xa if light < 0 else xb - x
        far = xb - x if light < 0 else x - xa
        if near == 0:
            c = 'j'
        elif far <= 1:
            c = 'g'
        g.px(x, y, c)
    for (x, y) in cells:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) not in cells:
                g.px(x, y, 'O')
                break


def face_span(g, y):
    """그 줄에서 살결이 차지하는 (왼끝, 오른끝) — 없으면 None."""
    xs = [x for x in range(g.w) if _is(g.d[y][x], 'sHS')]
    return (min(xs), max(xs)) if xs else None


def spike_cells(cx, base_y, hgt, half):
    out = set()
    for k in range(hgt):
        y = base_y - k
        hw = half * (1 - k / float(hgt))
        for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
            out.add((x, y))
    return out


def top_of_hair_at(g, x):
    for y in range(g.h):
        if _is(g.d[y][x], HAIR_CH) or (g.d[y][x] == 'O' and any(_is(g.at(x, y + k), HAIR_CH) for k in (1, 2))):
            return y
    return None


# ---------------------------------------------------------------- 머리 모양

def add_spiky(g, view):
    x0, y0, x1, y1 = hair_bbox(g)
    w = x1 - x0
    if view == 'side':
        spots = ((0.25, 12, 4), (0.5, 15, 5), (0.72, 11, 4))
    else:
        spots = ((0.18, 11, 4), (0.4, 15, 5), (0.62, 13, 5), (0.84, 10, 4))
    for fx, hgt, half in spots:
        cx = int(x0 + w * fx)
        ty = top_of_hair_at(g, cx)
        if ty is None:
            continue
        cells = spike_cells(cx, ty + 2, hgt + 2, half)
        # 이미 머리카락인 칸은 안 건드린다 — 가닥 밑동만 머리에 묻는다
        cells = {c for c in cells if not _is(g.at(*c), HAIR_CH)}
        draw_lock(g, cells, light=-1)


def _side_locks(g, head_bot, bottom, w, taper, tips):
    """앞모습 — 얼굴 양옆, 귀 높이에서 시작해 얼굴 가장자리를 3칸 덮으며 내려온다."""
    ear_y = head_bot - 24
    span = face_span(g, ear_y) or face_span(g, ear_y + 4)
    if span is None:
        return
    fx0, fx1 = span
    draw_lock(g, lock_cells(fx0 - w + 3, w, ear_y - 6, bottom, taper=taper, round_end=9, lean=-0.03, tips=tips), light=-1)
    draw_lock(g, lock_cells(fx1 - 2, w, ear_y - 6, bottom, taper=taper, round_end=9, lean=0.03, tips=tips), light=1)


def _back_hair_side(g, head_bot, bottom, w, taper, tips):
    """옆모습 — 목덜미(머리카락 맨 아랫줄)에서 등을 타고 내려오는 머리채 (몸 뒤).
    머리 상자 왼끝은 삐친 가닥이라 거기 매달면 목에서 떨어져 뜬다 — 아랫줄의 왼끝에 맨다."""
    x0, y0, x1, y1 = hair_bbox(g)
    nape = [x for yy in range(y1 - 5, y1 + 1) for x in range(g.w) if _is(g.d[yy][x], HAIR_CH)]
    nx0 = min(nape) if nape else x0
    cells = lock_cells(nx0 - 2, w, y1 - 8, bottom, taper=taper, round_end=10, lean=-0.04, tips=tips)
    # 머리카락이 이미 있는 칸은 두고, 몸 위로는 덮는다 (머리채는 등 뒤지만 어깨선 밖에서 보인다)
    cells = {c for c in cells if not _is(g.at(*c), HAIR_CH)}
    draw_lock(g, cells, light=-1)


def _back_hair_up(g, head_bot, bottom, w, taper, tips, round_end=10):
    """뒷모습 — 뒤통수 밑에서 등을 덮는 머리채. 어깨보다 넓으면 덩어리로 보인다."""
    x0, y0, x1, y1 = hair_bbox(g)
    cells = lock_cells((x0 + x1) // 2 - w // 2, w, y1 - 10, bottom,
                       taper=taper, round_end=round_end, tips=tips)
    cells = {c for c in cells if not _is(g.at(*c), HAIR_CH)}
    draw_lock(g, cells, light=-1)


def add_bob(g, view, head_bot):
    """단발 — 턱선에서 끝나는 짧은 머리채."""
    if view == 'down':
        _side_locks(g, head_bot, head_bot - 4, 9, 0.1, 2)
    elif view == 'side':
        _back_hair_side(g, head_bot, head_bot - 4, 14, 0.2, 2)
    else:
        _back_hair_up(g, head_bot, head_bot - 8, 42, 0.15, 1, round_end=5)


def add_long(g, view, head_bot):
    """긴 머리 — 얼굴 바깥으로 흘러 가슴께까지. 어깨보다 넓거나 허리를 넘어가면
    사람이 아니라 갈색 덩어리로 보인다."""
    bottom = head_bot + 28
    if view == 'down':
        _side_locks(g, head_bot, bottom, 10, 0.3, 2)
    elif view == 'side':
        _back_hair_side(g, head_bot, bottom, 17, 0.45, 3)
    else:
        _back_hair_up(g, head_bot, head_bot + 18, 38, 0.4, 3, round_end=8)


# ---------------------------------------------------------------- 여자 새로 그리기
#
# 남자 그림에 머리만 얹으면 **같은 사람이 가발을 쓴 것**으로 보인다. 참고 그림
# (assets/ref/f3_front.png)의 소녀를 모티브로, 머리·윗도리·치마를 다시 그린다:
#   · 머리 — 삐죽한 더벅머리를 깎아 **머리통에 붙는 둥근 단발**로. 옆에 묶은
#            머리 한 다발, 정수리에 안테나 한 가닥
#   · 윗도리 — 블라우스 위에 **조끼**(셔츠 그늘색 판) + 허리띠
#   · 아래 — 허리에서 퍼지는 **짧은 주름치마**, 맨다리, 부츠
# 골격(자세·팔다리 위치)만 남자 그림에서 가져온다 — 도트를 찍는 사람도 같은
# 골격 위에 다른 사람을 그린다.


def _hair_cells(g):
    return {(x, y) for y in range(g.h) for x in range(g.w) if _is(g.d[y][x], HAIR_CH)}


def _erode_spikes(g, passes=4, keep=13):
    """삐죽 솟은 가닥을 깎는다 — 5x5 안에 머리카락이 keep 칸 미만이면 뾰족한 끝이다."""
    H = _hair_cells(g)
    for _ in range(passes):
        out = set()
        for (x, y) in H:
            n = sum(1 for dx in range(-2, 3) for dy in range(-2, 3)
                    if (x + dx, y + dy) in H)
            if n >= keep:
                out.add((x, y))
        if out == H:
            break
        H = out
    return H


def _smooth_mask(cells, rounds=2):
    """가장자리를 둥글린다 — 이웃 여덟 중 다섯 이상이 안이면 넣고, 셋 이하면 뺀다."""
    for _ in range(rounds):
        xs = [x for x, _ in cells]; ys = [y for _, y in cells]
        box = range(min(xs) - 2, max(xs) + 3), range(min(ys) - 2, max(ys) + 3)
        out = set()
        for x in box[0]:
            for y in box[1]:
                n = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                        if (dx or dy) and (x + dx, y + dy) in cells)
                if ((x, y) in cells and n >= 4) or ((x, y) not in cells and n >= 6):
                    out.add((x, y))
        cells = out
    return cells


def _wipe(g, cells):
    """그 칸들과, 그 칸에만 붙어 있던 윤곽선을 지운다."""
    for c in cells:
        g.px(c[0], c[1], None)
    for _ in range(2):
        drop = []
        for y in range(g.h):
            for x in range(g.w):
                if g.d[y][x] != 'O':
                    continue
                if not any(g.at(x + dx, y + dy) not in (None, 'O')
                           for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    drop.append((x, y))
        for x, y in drop:
            g.px(x, y, None)


def female_head(g, view):
    """더벅머리를 둥근 단발로 깎고, 옆으로 묶은 머리와 안테나 한 가닥을 얹는다."""
    old = _hair_cells(g)
    if not old:
        return
    cap = _smooth_mask(_erode_spikes(g), 2)
    if not cap:
        return
    _wipe(g, old - cap)
    xs = [x for x, _ in cap]; ys = [y for _, y in cap]
    hx0, hx1, hy0, hy1 = min(xs), max(xs), min(ys), max(ys)
    add = set(cap)
    rows = {}
    for (x, y) in cap:
        rows.setdefault(y, []).append(x)
    cols = {}
    for (x, y) in cap:
        cols.setdefault(x, []).append(y)

    def extent(y):
        """그 줄에서 머리통이 차지하는 (왼끝, 오른끝) — 아래로 벗어나면 맨 아랫줄."""
        r = rows.get(min(y, hy1))
        while r is None and y > hy0:
            y -= 1
            r = rows.get(y)
        return (min(r), max(r)) if r else (hx0, hx1)

    # 귀 옆으로 흘러내리는 머리 — 머리통 **가장자리에 붙여서** 턱선까지.
    # (머리 상자 끝에 맞춰 놨더니 둥근 머리통에서 떨어져 막대가 떠 있었다)
    start = hy1 - 8
    jaw = hy1 + 13
    for d in (-1, 1):
        for y in range(start, jaw + 1):
            t = (y - start) / max(1, jaw - start)
            wdt = max(2, int(round(7 - 4 * t * t)))
            xa, xb = extent(y)
            edge = xa if d < 0 else xb
            for k in range(wdt):
                add.add((edge + d * k - d * 1, y))
    # 옆으로 묶은 머리 한 다발 (화면 오른쪽) — 귀 높이에서 시작해 밖으로 흐른다
    py0 = hy0 + (hy1 - hy0) * 2 // 3
    for y in range(py0, py0 + 20):
        t = (y - py0) / 19.0
        wdt = max(2, int(round(9 * (1 - 0.5 * t))))
        _, xb = extent(y)
        cxp = xb + 1 + int(round(3 * t))
        for k in range(wdt):
            add.add((cxp - k, y))
    if view != 'up':                            # 정수리 안테나 — 머리통 꼭대기에 붙인다
        ax = (hx0 + hx1) // 2 - 1
        atop = min(cols.get(ax, [hy0]))
        for k in range(4):
            add.add((ax, atop - 1 - k))
    draw_lock(g, add - cap, light=-1)
    for (x, y) in cap:                          # 깎인 자리의 결은 그대로 둔다
        if g.d[y][x] is None:
            g.px(x, y, 'h')
    _close_outline(g)


def add_vest(g, view):
    """블라우스 위에 조끼 — 셔츠 그늘색 판을 가슴 가운데에 두고 허리띠를 두른다.
    소매와 깃은 밝은 채로 남아 「조끼를 껴입었다」로 읽힌다."""
    shirt = [(x, y) for y in range(g.h) for x in range(g.w) if _is(g.d[y][x], 'bLB')]
    if not shirt:
        return
    comp = max(_components(shirt), key=len)
    xs = [x for x, _ in comp]; ys = [y for _, y in comp]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    rows = {}
    for (x, y) in comp:
        rows.setdefault(y, []).append(x)
    top = y0 + max(2, (y1 - y0) // 5)
    vest = set()
    for y in range(top, y1 + 1):
        r = rows.get(y)
        if not r:
            continue
        xa, xb = min(r), max(r)
        w = xb - xa
        inset = max(1, round(w * (0.30 if view == 'side' else 0.22)))
        for x in range(xa + inset, xb - inset + 1):
            if _is(g.at(x, y), 'bLB'):
                vest.add((x, y))
    # **조끼는 어둡게, 블라우스는 밝게.** 조끼만 한 단 어둡게 칠했더니 같은 파랑
    # 안에서 명암 차이로만 남아 「좀 짙은 셔츠」로 보였다. 소매·깃을 밝은 칸으로
    # 올려 두 겹(블라우스 위에 조끼)으로 읽히게 한다
    for (x, y) in comp:
        c = g.at(x, y)
        if (x, y) in vest:
            g.px(x, y, 'B')
        elif c == 'b':
            g.px(x, y, 'L')
        elif c == 'B':
            g.px(x, y, 'b')
    for y in (y1 - 1, y1):                      # 허리띠
        r = rows.get(y)
        if r:
            for x in range(min(r), max(r) + 1):
                if _is(g.at(x, y), 'bLB'):
                    g.px(x, y, 'B')


# ---------------------------------------------------------------- 여자 차림
#
# 머리만 길게 얹으면 게임 화면 크기에서 남녀가 안 갈린다 — 머리는 스물몇 픽셀인데
# 그 절반이 가려지고, 걷는 동안 흔들려 실루엣이 안 남는다. **치마**를 입힌다.
# (참고 그림 assets/ref/f3_front.png 의 소녀 — 조끼에 빨간 주름치마, 맨다리에 부츠)
#
# 반바지 자리에 치마를 덮어 그린다. 아래로 갈수록 벌어지고, 반바지보다
# 길고 넓어서 통째로 가린다. 색은 바지 칸(p/P/q)을 그대로 쓰므로 생성창에서
# 「바지」 색을 고르면 치마 색이 바뀐다.
PANTS_CH = 'pPq'


def add_skirt(g, view):
    cells = [(x, y) for y in range(g.h) for x in range(g.w) if _is(g.d[y][x], PANTS_CH)]
    if not cells:
        return
    comp = max(_components(cells), key=len)
    xs = [x for x, _ in comp]
    ys = [y for _, y in comp]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    cx = (x0 + x1) / 2.0
    waist = (x1 - x0 + 1) * 0.78          # 허리는 반바지보다 좁게
    hem_y = y1 + 2                        # 반바지보다 두 줄만 길게 — 참고 그림처럼 짧게
    span = max(1, hem_y - y0)
    skirt = set()
    for y in range(y0, hem_y + 1):
        t = (y - y0) / span
        hw = (waist / 2.0) + t * t * (x1 - x0) * 0.58      # 아래로 갈수록 확 벌어진다
        for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
            if not (0 <= x < g.w and 0 <= y < g.h):
                continue
            # 밑단은 주름 끝마다 한 칸씩 오르내린다 — 자로 자른 듯 곧으면 판자로 보인다
            if y > hem_y - 1 - (1 if _strand(x * 5) < 0.45 else 0):
                continue
            skirt.add((x, y))
    # 치마 밖으로 삐져나온 옛 반바지는 허벅지(살결)로 되돌린다
    for (x, y) in comp:
        if (x, y) not in skirt:
            g.px(x, y, 'S' if x < cx else 's')
    for (x, y) in skirt:
        g.px(x, y, 'p')
    rows = {}
    for (x, y) in skirt:
        rows.setdefault(y, []).append(x)
    PLEATS = (0.3, 0.52, 0.74)
    for (x, y) in skirt:
        xa, xb = min(rows[y]), max(rows[y])
        w = max(1, xb - xa)
        f = (x - xa) / w
        if y <= y0 + 1:
            g.px(x, y, 'P')               # 허리띠
        elif x - xa <= 1:
            g.px(x, y, 'q')               # 빛 받는 왼쪽
        elif xb - x <= 1 or (x, y + 1) not in skirt:
            g.px(x, y, 'P')               # 오른쪽·밑단 그늘
        elif any(abs(f - pf) * w < 0.6 for pf in PLEATS):
            # 주름은 **허리에서 밑단으로 부챗살처럼 퍼진다** — 폭의 몇 할 자리에
            # 긋는다. 열 간격으로 그으면 아래로 갈수록 줄이 늘어 줄무늬 천이 된다
            g.px(x, y, 'P')
    for (x, y) in skirt:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) not in skirt:
                g.px(x, y, 'O')
                break


def add_lashes(g, view, boxes):
    """여자 — 눈꼬리(바깥 위)에 속눈썹 날개."""
    for (bx0, by0, bx1, by1) in boxes:
        cx = (bx0 + bx1) / 2.0
        outer = bx0 if cx < g.w / 2 else bx1
        d = -1 if outer == bx0 else 1
        if view == 'side':
            outer, d = bx1, 1
        for k in range(1, 4):
            g.px(outer + d * k, by0 + 1 - (k // 2), 'e')
            g.px(outer + d * k, by0 + 2 - (k // 2), 'e')


def close_eyes(g, boxes):
    """눈 자리를 살결로 메우고 아래로 굽은 속눈썹 선을 긋는다."""
    for (bx0, by0, bx1, by1) in boxes:
        # 눈 둘레에서 가장 흔한 살결색으로 메운다
        cnt = {}
        for y in range(by0 - 3, by1 + 4):
            for x in range(bx0 - 3, bx1 + 4):
                c = g.at(x, y)
                if c in ('s', 'H', 'S'):
                    cnt[c] = cnt.get(c, 0) + 1
        fillc = max(cnt, key=cnt.get) if cnt else 's'
        for y in range(by0, by1 + 1):
            for x in range(bx0, bx1 + 1):
                if _is(g.at(x, y), EYE_CH):
                    g.px(x, y, fillc)
        # 눈망울을 둘렀던 윤곽선(눈 상자 바로 안쪽 O)도 지운다
        for y in range(by0, by1 + 1):
            for x in range(bx0, bx1 + 1):
                if g.at(x, y) == 'O' and sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                                             if _is(g.at(x + dx, y + dy), 'sHS')) >= 4:
                    g.px(x, y, fillc)
        mid = (by0 + by1) // 2 + 1
        w = bx1 - bx0
        for x in range(bx0, bx1 + 1):
            t = (x - bx0) / max(1.0, w)
            dip = int(round(3 * (1 - (2 * t - 1) ** 2)))
            g.px(x, mid + dip, 'e')
            g.px(x, mid + dip + 1, 'e')


# ---------------------------------------------------------------- 조립

DIRS = ('down', 'side', 'up')
WALK = 5
SWING_MAP = [0, 1, 1, 2, 3]     # 게임 위상 5 (감기 시작·다 감음·휘두름·내리침·되돌아옴) <- 시트 4장

SETS = [
    ('new_boy_', 'short', None),
    ('hair_short_', 'bob', add_bob),
    ('hair_spiky_', 'spiky', add_spiky),
    ('player_f_', 'long', add_long),
]


def load_frame(view, sname):
    im = Image.open(os.path.join(SRC, '%s_%s.png' % (view, sname))).convert('RGBA')
    return classify(im, view)


def build_set(prefix, style, deco):
    images = {}
    for d in DIRS:
        srcs = {'idle': 'idle'}
        for i in range(WALK):
            srcs['walk_%d' % i] = 'walk_%d' % i
        for i, si in enumerate(SWING_MAP):
            srcs['swing_%d' % i] = 'swing_%d' % si
        cache = {}
        for key, sname in srcs.items():
            if sname not in cache:
                g, head_bot, boxes = load_frame(d, sname)
                if style == 'long':
                    female_head(g, d)
                    add_vest(g, d)
                    add_skirt(g, d)
                    if d != 'up':
                        add_lashes(g, d, boxes)
                elif deco is not None:
                    if style == 'spiky':
                        deco(g, d)
                    else:
                        deco(g, d, head_bot)
                cache[sname] = (g, boxes)
            g, boxes = cache[sname]
            images['%s_%s' % (d, key)] = g.render()
            if key == 'idle' and d != 'up':
                gb = g.copy()
                close_eyes(gb, boxes)
                images['%s_blink' % d] = gb.render()
    for k, im in images.items():
        im.save(os.path.join(OUT, prefix + k + '.png'))
        im.save(os.path.join(REF, 'out_' + style + '_' + k + '.png'))
    return images


if __name__ == '__main__':
    SAND = (219, 172, 102)
    ALL = []
    for prefix, style, deco in SETS:
        ALL.append((style, build_set(prefix, style, deco)))
    # 미리보기: 벌마다 서기·깜빡임·옆·뒤 (2배)
    faces = []
    for style, images in ALL:
        faces += [images['down_idle'], images['down_blink'], images['side_idle'], images['up_idle']]
    sheet = Image.new('RGB', (FW * 2 * len(faces), FH * 2), SAND)
    for i, fim in enumerate(faces):
        base = Image.new('RGBA', (FW, FH), SAND + (255,))
        base.alpha_composite(fim)
        sheet.paste(base.convert('RGB').resize((FW * 2, FH * 2), Image.NEAREST), (i * FW * 2, 0))
    sheet.save(os.path.join(REF, 'preview_faces.png'))
    for style, images in ALL:
        for d in DIRS:
            keys = ['%s_walk_%d' % (d, i) for i in range(WALK)] + ['%s_swing_%d' % (d, i) for i in range(5)]
            st = Image.new('RGB', (FW * len(keys), FH), SAND)
            for i, k in enumerate(keys):
                base = Image.new('RGBA', (FW, FH), SAND + (255,))
                base.alpha_composite(images[k])
                st.paste(base.convert('RGB'), (i * FW, 0))
            st.save(os.path.join(REF, 'preview_%s_%s.png' % (style, d)))
    print('done: %d frames x %d sets (sprites/에 설치됨)' % (len(ALL[0][1]), len(ALL)))
