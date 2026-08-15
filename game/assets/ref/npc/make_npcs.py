# -*- coding: utf-8 -*-
# 마을 주민 스프라이트 생성기 — **플레이어와 같은 그림체**로 코드가 직접 그린다.
#
# 예전에는 보라(rancher) 도트 한 벌을 색만 바꿔 21명을 만들었다. 그래서
# 실루엣이 전부 같았다 — 대장장이도 아이도 어깨 너비와 머리 모양이 똑같았다.
# 여기서는 `dot_boy/make_sprites.py`(플레이어 생성기)를 그대로 불러 쓰고,
# **주민마다 생김새를 다르게** 만든다:
#
#   머리 모양   민머리 · 짧은 머리 · 삐죽 머리 · 단발 · 긴 머리
#   쓴 것       두건 · 밀짚모자 · 챙모자 · 광부 헬멧 · 베레모 · 머리꽃
#   얼굴        수염(짧은/덥수룩한/흰) · 안경
#   체격        아이는 다리를 줄여 머리가 커 보이게 (도트를 안 늘여서 안 뭉갠다)
#   색          머리 · 옷 · 바지 · 앞치마를 사람마다
#
# 규격: 게임의 NPC는 32x48 그림을 2배로 그린다. 플레이어는 같은 32x48 논리
# 격자를 4배로 키워 128x192로 두고 0.5배로 그린다 — 화면에서 도트 크기가
# 같다. 그래서 여기서는 논리 격자를 **1배 그대로** 32x48로 저장한다.
#
# 실행:  python3 make_npcs.py       (Pillow 필요)
#        플레이어 생성기를 import 하므로 플레이어 스프라이트도 같이 다시 그려진다
#        (같은 값으로 다시 그리는 것이라 결과는 안 바뀐다).
import os
import sys
from PIL import Image

REF = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(REF, '..', 'dot_boy')))
import make_sprites as ms          # noqa: E402  (경로를 먼저 잡아야 한다)

OUT = os.path.normpath(os.path.join(REF, '..', '..', 'sprites'))
GW, GH = ms.GW, ms.GH              # 32 x 48


# ----------------------------------------------------------------- 팔레트
#
# 플레이어와 같은 키를 쓰고(살결 s/S/H, 셔츠 b/B/L, 바지 p/P/q, 머리 h/j/g,
# 신발 k/K), 주민 전용으로 몇 개를 더 둔다. 색은 사람마다 갈아 끼운다.
#   C/c  쓴 것(모자·두건)      V/v  앞치마·조끼
#   D    수염                  N    안경테
EXTRA_DEFAULT = {
    'C': (120, 96, 72), 'c': (86, 68, 50),
    'V': (196, 188, 170), 'v': (150, 142, 126),
    'D': (86, 62, 44), 'N': (74, 70, 86),   # 안경테는 윤곽선(54,33,26)보다 밝게 — 아니면 얼굴선에 묻힌다
}


def shades(base, dark=0.68, lite=1.24):
    """기본색 하나에서 [기본, 그늘, 밝은 면]을 만든다."""
    def mul(f):
        return tuple(max(0, min(255, round(v * f))) for v in base)
    return base, mul(dark), mul(lite)


def palette(skin, hair, shirt, pants, shoe, hat=None, apron=None, beard=None):
    p = dict(ms.PAL)
    p.update(EXTRA_DEFAULT)
    s, sd, sl = shades(skin, 0.86, 1.06)
    p['s'], p['S'], p['H'] = s, sd, sl
    h, hd, hl = shades(hair)
    p['h'], p['g'], p['j'] = h, hd, hl
    b, bd, bl = shades(shirt)
    p['b'], p['B'], p['L'] = b, bd, bl
    q, qd, ql = shades(pants)
    p['p'], p['P'], p['q'] = q, qd, ql
    k, kd, _ = shades(shoe)
    p['k'], p['K'] = k, kd
    if hat:
        c, cd, _ = shades(hat)
        p['C'], p['c'] = c, cd
    if apron:
        v, vd, _ = shades(apron)
        p['V'], p['v'] = v, vd
    p['D'] = beard if beard else shades(hair, 0.82)[1]
    return p


# --------------------------------------------------------------- 머리 손질
#
# 머리 그림(16x16 또는 16x21 ASCII)을 만져 생김새를 바꾼다. 원본은 안 건드리고
# 복사본을 돌려준다 — 한 사람에게 씌운 모자가 다음 사람에게 남으면 안 된다.

def _put(art, r, lo, hi, ch, only=None):
    """art의 r줄 lo..hi 칸을 ch로 바꾼다. only를 주면 그 문자들만 바꾼다."""
    if r < 0 or r >= len(art):
        return
    art[r] = ''.join(
        ch if lo <= i <= hi and (only is None or c in only) else c
        for i, c in enumerate(art[r]))


def hat(arts, brim=0, deep=5):
    """정수리부터 deep줄을 모자로 덮는다. brim이면 그만큼 챙을 단다.
    챙은 **눈 위**에서 멈춘다 — 더 내리면 얼굴이 다 가려 표정이 죽는다."""
    out = []
    for art in arts:
        a = list(art)
        for r in range(0, deep):
            _put(a, r, 0, 15, 'C', 'sSHhjg')
        _put(a, 1, 4, 10, 'C', 'sSHhjg')
        _put(a, deep - 1, 0, 15, 'c', 'C')          # 모자 아랫단 그늘
        if brim:
            # 챙은 머리 옆으로 한 칸 튀어나온다 (윤곽선이 알아서 둘러진다)
            r = deep - 1 + brim
            if r < len(a):
                a[r] = 'C' + a[r][1:15] + 'C'
                _put(a, r, 1, 14, 'c', 'sSHhjg')
        out.append(a)
    return out


def helmet(arts):
    """광부 헬멧 — 모자에 이마 램프 한 점."""
    out = hat(arts, brim=0, deep=5)
    for a in out:
        _put(a, 3, 7, 8, 'w', 'Cc')                 # 램프알
        _put(a, 4, 7, 8, 'N', 'Cc')                 # 램프 테
    return out


def flower(arts):
    """머리 옆에 꽃 한 송이 (앞·옆모습만 — 뒤통수에는 안 보인다)."""
    out = [list(a) for a in arts]
    for a in out[:2]:
        _put(a, 2, 1, 2, 'V')
        _put(a, 3, 1, 1, 'v')
    return out


def beard(arts, full=False):
    """턱수염. full이면 볼까지 덥수룩하게 (앞·옆모습만)."""
    out = [list(a) for a in arts]
    for a in out[:2]:
        for r in (12, 13, 14):
            _put(a, r, 2, 13, 'D', 'sSH')
        if full:
            for r in (10, 11):
                _put(a, r, 1, 3, 'D', 'sSH')
                _put(a, r, 12, 14, 'D', 'sSH')
    return out


def glasses(arts):
    """안경 (앞·옆모습만).

    눈 위아래에 테만 두르면 **짙은 눈썹과 그늘**로 보인다 — 두 알을 잇는
    코걸이가 있어야 안경으로 읽힌다. 옆모습은 알 하나만 보이므로 대신
    귀 쪽으로 다리를 뻗는다."""
    out = [list(a) for a in arts]
    for r in (6, 11):                       # 눈 위·아래 테
        _put(out[0], r, 2, 5, 'N', 'sSH')
        _put(out[0], r, 10, 13, 'N', 'sSH')
    _put(out[0], 8, 6, 9, 'N', 'sSH')       # 코걸이 — 이 한 줄이 안경을 만든다
    for r in (6, 11):
        _put(out[1], r, 8, 13, 'N', 'sSH')
    _put(out[1], 8, 4, 7, 'N', 'sSH')       # 옆모습은 귀 쪽으로 뻗는 다리
    return out


# --------------------------------------------------------------- 몸 손질

def apron(g, y0, y1):
    """셔츠 가운데를 앞치마로 덮는다 (양옆은 소매로 남긴다).
    한 칸 건너 칠하면 천이 아니라 **바둑판 무늬**가 된다 — 통으로 칠하고
    가장자리와 아랫단에만 그늘을 둬야 앞에 덧댄 천으로 읽힌다."""
    y1 = min(y1, GH)
    for y in range(y0, y1):
        for x in range(11, 21):
            if g.d[y][x] in 'bBL':
                g.d[y][x] = 'V'
    for y in range(y0, y1):
        for x in (11, 20):
            if g.d[y][x] == 'V':
                g.d[y][x] = 'v'
    for x in range(11, 21):
        if g.d[y1 - 1][x] == 'V':
            g.d[y1 - 1][x] = 'v'


def shorten(g, n):
    """다리에서 n줄을 덜어 내고 윗몸을 그만큼 내린다.
    그림을 줄이지 않고 **행을 빼서** 아이 비율을 만든다 — 축소하면
    도트가 뭉개지는데, 이러면 찍힌 점이 그대로 남는다."""
    cut = ms.LEG_Y + 3
    rows = g.d[:cut] + g.d[cut + n:]
    g.d = [['.'] * GW for _ in range(n)] + rows


# ----------------------------------------------------------------- 그리기

def render(g, pal):
    """논리 격자를 32x48 그림으로 (NPC는 이 크기를 2배로 그린다)."""
    im = Image.new('RGBA', (GW, GH), (0, 0, 0, 0))
    px = im.load()
    for y in range(GH):
        for x in range(GW):
            c = g.d[y][x]
            if c != '.':
                px[x, y] = pal[c] + (255,)
    return im


def portrait(art, pal, happy=False):
    """대화창 초상화 64x64 — 얼굴 16x16을 4배로."""
    a = ms.closed_eyes(art) if happy else art
    im = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    px = im.load()
    for y in range(16):
        row = a[y] if y < len(a) else '.' * 16
        for x in range(16):
            c = row[x] if x < len(row) else '.'
            if c == '.':
                continue
            col = pal[c] + (255,)
            for sy in range(4):
                for sx in range(4):
                    px[x * 4 + sx, y * 4 + sy] = col
    return im


# ------------------------------------------------------------------ 주민들
#
# head:  'bald' 민머리 · 'short' 짧은 머리 · 'spiky' 삐죽 머리
#        'bob' 단발 · 'long' 긴 머리
# 나머지는 위 손질 함수 이름을 그대로 쓴다.
LONG = (ms.HEAD_DOWN_F, ms.HEAD_SIDE_F, ms.HEAD_UP_F)


def _bob(arts):
    """단발 — 긴 머리(21줄)에서 어깨 아래로 흐르는 머리채를 걷어 낸다.
    얼굴 16줄 + 턱 밑 두 줄만 남기면 귀밑에서 딱 끊긴 단발이 된다."""
    return tuple(tuple(a[:18]) for a in arts)


BASE = {
    'bald': (ms.HEAD_DOWN, ms.HEAD_SIDE, ms.HEAD_UP),
    'short': ms.HEADS_SHORT,
    'spiky': ms.HEADS_SPIKY,
    'long': LONG,
    'bob': _bob(LONG),
}

C = {                       # 자주 쓰는 색
    'skin': (243, 159, 138), 'skin_tan': (226, 166, 120), 'skin_pale': (252, 220, 203),
    'brown': (118, 72, 40), 'black': (52, 46, 50), 'gray': (150, 148, 152),
    'blond': (214, 170, 84), 'red': (190, 96, 48), 'white': (222, 218, 214),
    'ink': (84, 52, 32),
}

NPCS = {
    # -- 마을 상인·기술자 --
    'merchant':   dict(head='bob',   hair=C['brown'], shirt=(214, 96, 116),
                       pants=(126, 92, 70), apron=(238, 232, 214)),
    'blacksmith': dict(head='bald',  hair=C['black'], shirt=(96, 96, 104),
                       pants=(70, 62, 58), hat=(150, 60, 52), deep=3,
                       beard='full', skin=C['skin_tan'], apron=(92, 74, 60)),
    'carpenter':  dict(head='short', hair=(58, 42, 32), shirt=(140, 96, 56),
                       pants=(96, 76, 54), hat=(196, 176, 120), deep=3,
                       beard='short'),
    'rancher':    dict(head='long',  hair=(96, 62, 44), shirt=(168, 120, 196),
                       pants=(96, 84, 118)),
    'weaver':     dict(head='bob',   hair=(174, 140, 104), shirt=(236, 226, 200),
                       pants=(158, 142, 118), apron=(206, 190, 158)),

    # -- 바깥일 하는 사람들 --
    'farmer':     dict(head='short', hair=(92, 66, 40), shirt=(176, 168, 106),
                       pants=(120, 104, 62), hat=(226, 196, 116), brim=1,
                       skin=C['skin_tan']),
    'fisher':     dict(head='short', hair=(46, 58, 82), shirt=(72, 118, 176),
                       pants=(60, 74, 108), hat=(96, 122, 150), brim=1,
                       skin=C['skin_tan']),
    'angler':     dict(head='spiky', hair=(40, 56, 88), shirt=(58, 104, 160),
                       pants=(52, 66, 96), skin=C['skin_tan']),
    'miner':      dict(head='bald',  hair=(46, 44, 48), shirt=(104, 100, 96),
                       pants=(78, 74, 70), helmet=True, skin=C['skin_tan'],
                       beard='short'),
    'explorer':   dict(head='spiky', hair=(96, 60, 34), shirt=(140, 132, 90),
                       pants=(104, 96, 66), skin=C['skin_tan']),
    'postman':    dict(head='short', hair=(70, 52, 40), shirt=(186, 72, 66),
                       pants=(72, 72, 88), hat=(150, 52, 48), brim=1, deep=4),

    # -- 마을 어른 --
    'chief':      dict(head='bald',  hair=C['white'], shirt=(84, 96, 140),
                       pants=(72, 68, 84), beard='full', beard_col=(226, 222, 216),
                       skin=(232, 186, 166)),
    'librarian':  dict(head='bob',   hair=(64, 54, 48), shirt=(120, 104, 148),
                       pants=(84, 78, 96), glasses=True, skin=C['skin_pale']),
    'alchemist':  dict(head='long',  hair=(186, 182, 190), shirt=(122, 88, 158),
                       pants=(78, 66, 98), glasses=True, skin=C['skin_pale']),
    'herbalist':  dict(head='long',  hair=(72, 56, 36), shirt=(104, 148, 90),
                       pants=(78, 96, 66)),
    'florist':    dict(head='bob',   hair=(198, 150, 92), shirt=(230, 168, 190),
                       pants=(150, 118, 130), flower=True),
    'foodie':     dict(head='bob',   hair=(126, 78, 48), shirt=(226, 142, 76),
                       pants=(140, 100, 66), apron=(240, 230, 212)),
    'painter':    dict(head='short', hair=(60, 50, 44), shirt=(84, 148, 152),
                       pants=(66, 88, 96), hat=(60, 96, 120), deep=3),
    'musician':   dict(head='long',  hair=(132, 62, 44), shirt=(150, 76, 110),
                       pants=(94, 62, 84)),

    # -- 숲 --
    'forest_mom':  dict(head='long', hair=(58, 44, 34), shirt=(96, 132, 92),
                        pants=(74, 92, 70)),
    'forest_girl': dict(head='bob',  hair=(206, 176, 96), shirt=(232, 214, 132),
                        pants=(150, 132, 92), child=True, skin=C['skin_pale']),
}


def build(spec):
    """설정 하나로 머리 그림 세 장과 팔레트를 만든다."""
    arts = [list(a) for a in BASE[spec['head']]]
    if spec.get('helmet'):
        arts = helmet(arts)
    elif spec.get('hat'):
        arts = hat(arts, brim=spec.get('brim', 0), deep=spec.get('deep', 5))
    if spec.get('flower'):
        arts = flower(arts)
    if spec.get('beard'):
        arts = beard(arts, full=spec['beard'] == 'full')
    if spec.get('glasses'):
        arts = glasses(arts)
    arts = [tuple(a) for a in arts]      # head()가 is 로 비교하므로 고정해 둔다
    pal = palette(spec.get('skin', C['skin']), spec['hair'], spec['shirt'],
                  spec['pants'], spec.get('shoe', (82, 53, 33)),
                  hat=spec.get('hat'), apron=spec.get('apron'),
                  beard=spec.get('beard_col'))
    return arts, pal


# 걷기 두 장은 다리가 가장 크게 엇갈리는 위상으로 고른다 (2프레임뿐이라
# 어중간한 위상을 쓰면 제자리걸음처럼 보인다)
WALK_A, WALK_B = 1, 3

made = 0
for npc_id, spec in NPCS.items():
    arts, pal = build(spec)
    # 머리 그림이 민머리 계열이면 귀를 그린다 (여자 머리·모자는 귀를 덮는다)
    if spec['head'] in ('bald', 'short', 'spiky') and not spec.get('hat') \
            and not spec.get('helmet'):
        ms.EARS_DOWN.append(arts[0])
        ms.EARS_SIDE.append(arts[1])
    for d, art in zip(('down', 'side', 'up'), arts):
        ms.PARTS[d] = (art, ms.PARTS[d][1], ms.PARTS[d][2])
    for d in ('down', 'side', 'up'):
        for i, (st, bo) in enumerate(((ms.STRIDE[WALK_A], ms.BOB[WALK_A]),
                                      (ms.STRIDE[WALK_B], ms.BOB[WALK_B]))):
            g = ms.frame(d, st, bo)
            if spec.get('apron'):
                apron(g, ms.SHIRT_Y + 3, ms.HIP_Y + 2)
            if spec.get('child'):
                shorten(g, 4)
            render(g, pal).save(os.path.join(OUT, f'npc_{npc_id}_{d}_{i}.png'))
    portrait(arts[0], pal).save(
        os.path.join(OUT, f'npc_{npc_id}_portrait_normal.png'))
    portrait(arts[0], pal, happy=True).save(
        os.path.join(OUT, f'npc_{npc_id}_portrait_happy.png'))
    made += 1

print('주민 %d명 · 프레임 %d장 + 초상화 %d장' % (made, made * 6, made * 2))


# ----------------------------------------------------------------- 확인용 그림
def sheet(name, cols, keys, z=5):
    """주민들을 격자로 늘어놓는다. 작게 보면 개성이 안 보여서 크게 뽑는다.
    칸 크기는 **그림에서 잰다** — 32x48로 박아 두면 64x64 초상화가 넘쳐 겹친다."""
    first = Image.open(os.path.join(OUT, keys[0] + '.png'))
    cw, ch = first.width * z, first.height * z
    rows = (len(keys) + cols - 1) // cols
    im = Image.new('RGB', (cw * cols, ch * rows), (46, 52, 44))
    for i, key in enumerate(keys):
        f = Image.open(os.path.join(OUT, key + '.png')).convert('RGBA')
        big = f.resize((f.width * z, f.height * z), Image.NEAREST)
        im.paste(big, ((i % cols) * cw, (i // cols) * ch), big)
    im.save(os.path.join(REF, name))
    return im


ids = list(NPCS)
sheet('preview_npcs.png', 7, [f'npc_{i}_down_0' for i in ids])
sheet('preview_npcs_side.png', 7, [f'npc_{i}_side_0' for i in ids])
sheet('preview_npcs_up.png', 7, [f'npc_{i}_up_0' for i in ids])
sheet('preview_portraits.png', 7, [f'npc_{i}_portrait_normal' for i in ids], z=2)
print('preview_npcs.png · _side · _up · _portraits (%d명)' % len(ids))
