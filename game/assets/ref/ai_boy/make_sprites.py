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
OUTLINE = {(3, 2, 2), (7, 10, 9), (13, 5, 2), (22, 12, 6), (32, 15, 8)}
EYE_DARK = {(8, 22, 22), (15, 34, 34)}
BROWN_L = {(137, 78, 42), (159, 88, 50)}
BROWN_M = {(115, 60, 33), (122, 65, 35)}
BROWN_D = {(103, 54, 29), (88, 45, 24), (74, 38, 21), (64, 33, 19)}
BROWN_X = {(56, 27, 15), (41, 23, 13)}
BROWN = BROWN_L | BROWN_M | BROWN_D | BROWN_X
SKIN_SURE = {(249, 194, 151): 's', (241, 206, 174): 'H'}
SHIRT_SURE = {(248, 232, 211): 'b', (252, 246, 230): 'L'}
SHIRT_DARK = {(56, 45, 32): 'O', (91, 69, 51): 'B'}
# 살결 그늘인지 셔츠 그늘인지 자리를 봐야 아는 색 — (살결이면, 셔츠면)
AMBIG = {(206, 169, 140): ('S', 'B'), (217, 140, 101): ('S', 'B'),
         (192, 110, 72): ('m', 'B'), (169, 135, 109): ('S', 'B'), (127, 100, 78): ('S', 'B')}
HAIR_CH = 'hjg'
EYE_CH = 'eiw'


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
    """갈색 덩어리마다 머리/바지/신발 — (kind 사전, 머리 덩어리 줄들, top, hgt)"""
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
            kind[c] = k
    return kind, hair_cells, top, hgt, opaque


def classify(im, view):
    """3세대 프레임 한 장 -> (팔레트 문자 격자, 턱 밑 줄, 눈 상자들)."""
    W, H = im.size
    px = im.load()
    g = Grid(W, H)
    kind, hair_cells, top, hgt, opaque = _brown_kinds(im)
    hair_rows = [y for _, y in hair_cells]
    head_bot = (max(hair_rows) + 30) if hair_rows else top + 70
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
    ambig = []
    for (x, y) in opaque:
        c = px[x, y][:3]
        if (x, y) in eyes:
            # 눈 안: 어두운 색은 눈망울, 갈색은 홍채, 크림색·흰색은 반짝이
            if c in OUTLINE or c in EYE_DARK or c == (56, 45, 32):
                g.px(x, y, 'e')
            elif c in BROWN or c in ((91, 69, 51), (127, 100, 78)):
                g.px(x, y, 'i')
            elif c in SHIRT_SURE or c in ((206, 169, 140), (169, 135, 109)):
                g.px(x, y, 'w')
            elif c in SKIN_SURE:
                g.px(x, y, SKIN_SURE[c])
            else:
                g.px(x, y, 'S')
            continue
        if c in OUTLINE or c in EYE_DARK:
            g.px(x, y, 'O')
        elif c in BROWN:
            k = kind[(x, y)]
            if k == 'hair' or (k == 'small' and y <= head_bot - 30):
                g.px(x, y, 'j' if c in BROWN_L else 'h' if c in BROWN_M else 'g' if c in BROWN_D else 'O')
            elif k == 'boot' or (k == 'small' and y > top + 0.85 * hgt):
                g.px(x, y, 'k' if c in (BROWN_L | BROWN_M) else 'K' if c in BROWN_D else 'O')
            else:
                g.px(x, y, 'q' if c in BROWN_L else 'p' if c in BROWN_M else 'P' if c in BROWN_D else 'O')
        elif c in SKIN_SURE:
            g.px(x, y, SKIN_SURE[c])
        elif c in SHIRT_SURE:
            g.px(x, y, SHIRT_SURE[c])
        elif c in SHIRT_DARK:
            g.px(x, y, SHIRT_DARK[c])
        elif c in AMBIG:
            ambig.append((x, y))
        else:
            raise SystemExit('모르는 색 %s' % (c,))
    # 애매한 색: 반경 2 안의 확실한 이웃이 살결이 많으면 살결, 셔츠가 많으면 셔츠
    for (x, y) in ambig:
        skin = shirt = 0
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                q = g.at(x + dx, y + dy)
                if q in ('s', 'H'):
                    skin += 1
                elif q in ('b', 'L'):
                    shirt += 1
        c = px[x, y][:3]
        s_ch, b_ch = AMBIG[c]
        if skin == 0 and shirt == 0:
            g.px(x, y, s_ch if c in ((217, 140, 101), (192, 110, 72)) else b_ch)
        else:
            g.px(x, y, s_ch if skin >= shirt else b_ch)
    # 입(m)은 얼굴 안에서만 — 몸에 찍힌 m 은 살결 그늘로
    for (x, y) in ambig:
        if g.at(x, y) == 'm' and y >= head_bot:
            g.px(x, y, 'S')
    return g, head_bot, boxes


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


def hair_patch(g, size=18):
    """AI 머리카락 한 조각(size x size) — 덧그리는 머리채의 결로 쓴다.
    머리 상자 안에서 머리카락·윤곽선만으로 찬 창을 찾는다."""
    x0, y0, x1, y1 = hair_bbox(g)
    best = None
    for y in range(y0 + 4, y1 - size, 2):
        for x in range(x0 + 4, x1 - size, 2):
            n = sum(1 for dy in range(size) for dx in range(size)
                    if _is(g.at(x + dx, y + dy), HAIR_CH + 'O'))
            if n == size * size:
                return [[g.at(x + dx, y + dy) for dy in range(size)] for dx in range(size)]
            if best is None or n > best[0]:
                best = (n, x, y)
    _, x, y = best
    return [[g.at(x + dx, y + dy) if _is(g.at(x + dx, y + dy), HAIR_CH + 'O') else 'h'
             for dy in range(size)] for dx in range(size)]


def draw_lock(g, cells, patch, light=-1):
    """머리채를 AI 머리카락 조각으로 채운다 — 결이 본 머리와 이어진다.
    타일이 티 나지 않게 줄 띠마다 어긋나게 깔고, 둘레는 O, 빛 쪽 가장자리엔 j."""
    cells = set(cells)
    n = len(patch)
    rows = {}
    for (x, y) in cells:
        rows.setdefault(y, []).append(x)
    for (x, y) in cells:
        band = y // n
        shift = (band * 7 + (band * band) % 5) % n        # 띠마다 다르게 어긋나 타일 티가 안 난다
        c = patch[(x + shift) % n][y % n]
        xs = rows[y]
        xa, xb = min(xs), max(xs)
        edge = x - xa if light < 0 else xb - x
        if 1 <= edge <= 2 and (y // 6) % 2 == 0 and c != 'O':
            c = 'j'
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
        draw_lock(g, cells, hair_patch(g), light=-1)


def _side_locks(g, head_bot, bottom, w, taper, tips):
    """앞모습 — 얼굴 양옆, 귀 높이에서 시작해 얼굴 가장자리를 3칸 덮으며 내려온다."""
    ear_y = head_bot - 24
    span = face_span(g, ear_y) or face_span(g, ear_y + 4)
    if span is None:
        return
    fx0, fx1 = span
    patch = hair_patch(g)
    draw_lock(g, lock_cells(fx0 - w + 3, w, ear_y - 6, bottom, taper=taper, round_end=9, lean=-0.03, tips=tips), patch, light=-1)
    draw_lock(g, lock_cells(fx1 - 2, w, ear_y - 6, bottom, taper=taper, round_end=9, lean=0.03, tips=tips), patch, light=1)


def _back_hair_side(g, head_bot, bottom, w, taper, tips):
    """옆모습 — 목덜미(머리카락 맨 아랫줄)에서 등을 타고 내려오는 머리채 (몸 뒤).
    머리 상자 왼끝은 삐친 가닥이라 거기 매달면 목에서 떨어져 뜬다 — 아랫줄의 왼끝에 맨다."""
    x0, y0, x1, y1 = hair_bbox(g)
    nape = [x for yy in range(y1 - 5, y1 + 1) for x in range(g.w) if _is(g.d[yy][x], HAIR_CH)]
    nx0 = min(nape) if nape else x0
    cells = lock_cells(nx0 - 2, w, y1 - 8, bottom, taper=taper, round_end=10, lean=-0.04, tips=tips)
    # 머리카락이 이미 있는 칸은 두고, 몸 위로는 덮는다 (머리채는 등 뒤지만 어깨선 밖에서 보인다)
    cells = {c for c in cells if not _is(g.at(*c), HAIR_CH)}
    draw_lock(g, cells, hair_patch(g), light=-1)


def _back_hair_up(g, head_bot, bottom, w, taper, tips, round_end=10):
    """뒷모습 — 뒤통수 밑에서 등을 덮는 머리채. 어깨보다 넓으면 덩어리로 보인다."""
    x0, y0, x1, y1 = hair_bbox(g)
    cells = lock_cells((x0 + x1) // 2 - w // 2, w, y1 - 10, bottom,
                       taper=taper, round_end=round_end, tips=tips)
    cells = {c for c in cells if not _is(g.at(*c), HAIR_CH)}
    draw_lock(g, cells, hair_patch(g), light=-1)


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
        _back_hair_up(g, head_bot, bottom, 44, 0.4, 3, round_end=8)


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
                if deco is not None:
                    if style == 'spiky':
                        deco(g, d)
                    else:
                        deco(g, d, head_bot)
                if style == 'long' and d != 'up':
                    add_lashes(g, d, boxes)
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
