# -*- coding: utf-8 -*-
# 메인 이미지(키 아트) — 스팀 캡슐 · 유튜브 배너 · 프로필.
#
# 게임 화면을 오려 쓰기만 하면 캡슐이 약하다. 상점 목록에서 460x215짜리
# 그림 하나로 「이게 무슨 게임인지」가 읽혀야 하는데, 풍경만 있으면
# 다른 도트 게임과 구분이 안 된다. 그래서 **조립**한다:
#
#   바탕(게임 화면) + 어둡게 깔기 + 캐릭터 + 제목
#
# 세 가지를 지킨다:
#   ① 도트는 **정수배 최근접**으로만 키운다 (보간하면 뭉개진다)
#   ② 제목은 게임에 쓰는 픽셀 폰트(Galmuri11)로, **11의 배수 크기**로만
#      — 그래야 글자도 도트로 딱 떨어진다
#   ③ 캡슐 비율마다 배치를 달리 한다. 가로로 납작한 칸에 전신을 넣으면
#      사람이 개미만 해진다 — 짧은 칸은 상반신만 크게 쓴다
#
# 실행 (리눅스·맥):   python3 make_key_art.py
#      (윈도우):       python make_key_art.py
#   윈도우의 `python3`은 **마이크로소프트 스토어 안내 스텁**이라 아무것도 안 하고
#   끝난다. 파이썬이 깔려 있어도 그렇다 — `python`으로 불러야 한다.
#
# 준비물:  pip install Pillow
#          게임 스크린샷 (아래 SHOT_HINT 참고)
import glob
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit('Pillow가 없다.  설치:  python -m pip install Pillow')

REF = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(REF, '..', 'game'))
OUT = os.path.join(REF, 'out')
os.makedirs(OUT, exist_ok=True)

TITLE = 'Little Root'
SUB = '리틀 루트'
FONT = os.path.join(GAME, 'assets', 'fonts', 'Galmuri11.ttf')
CHAR = os.path.join(GAME, 'assets', 'sprites', 'new_boy_down_idle.png')
CAST = ['npc_merchant_down_0', 'npc_blacksmith_down_0', 'npc_forest_girl_down_0']

# 바탕이 될 **UI 없는 화면**.
#
# 게임을 돌리면 game/ 에 새로 찍힌다 (KYOJIN_SHOT=1 이면 `1_clean.png` —
# 앞에 붙는 값이 달라지므로 이름을 박지 않고 찾는다). 그게 있으면 그걸 쓰고,
# 없으면 여기 넣어 둔 `bg_clean.png`로 돌린다 — **게임을 안 돌려도 캡슐이
# 나오게** 하려는 것이다 (파이썬만 있으면 되는 편이 손이 덜 간다).
# 화면이 바뀌었으면 게임을 한 번 돌려 새로 찍는 쪽이 낫다.
_shots = sorted(glob.glob(os.path.join(GAME, '*_clean.png')))
BG_SHOT = _shots[0] if _shots else os.path.join(REF, 'bg_clean.png')
if not os.path.exists(BG_SHOT):
    sys.exit("""바탕 그림이 없다 (brand/bg_clean.png 도, game/*_clean.png 도).
게임을 한 번 돌려 찍는다:

  윈도우 (PowerShell)
    cd %s
    $env:KYOJIN_SHOT = "1"
    & "C:\\경로\\Godot_v4.4-stable_win64.exe" --path .

  리눅스·맥
    cd %s
    KYOJIN_SHOT=1 godot --path .
""" % (GAME, GAME))

CREAM = (247, 238, 214)
INK = (46, 34, 26)
GOLD = (232, 190, 96)


def nearest(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def trim(im):
    b = im.getbbox()
    return im.crop(b) if b else im


# 바탕에서 오려 낼 자리 (1_clean.png 안의 좌표). **건물이 몰린 데를 집어야**
# 한다 — 화면 전체를 쓰면 위에서 본 잔디밭이고, 빈 데를 확대하면 그냥 잔디다.
# (화면 구성이 바뀌면 이 값을 다시 잡아야 한다)
BG_FOCUS = (840, 600)


def backdrop(w, h, dim=0.45, zoom=2):
    """게임 화면의 **한 구석을 확대해** 어둡게 깐다.

    화면 전체를 축소해 넣으면 건물이 손톱만 해져서 「위에서 본 잔디밭」이
    된다. zoom배로 확대해 오리면 건물·간판이 제 크기로 보여 장면이 된다.
    확대는 정수배 최근접 — 도트가 뭉개지면 안 된다.

    어둡게 까는 건 바탕이 눈에 띄면 안 되기 때문이다. 밝은 채로 두면
    잔디 무늬가 제목을 갉아먹어 글자가 안 읽힌다."""
    src = Image.open(BG_SHOT).convert('RGB')
    bw, bh = max(1, w // zoom), max(1, h // zoom)
    x = max(0, min(src.width - bw, BG_FOCUS[0] - bw // 2))
    y = max(0, min(src.height - bh, BG_FOCUS[1] - bh // 2))
    im = src.crop((x, y, x + bw, y + bh))
    im = im.resize((bw * zoom, bh * zoom), Image.NEAREST)
    if im.size != (w, h):                       # 나머지 픽셀은 늘리지 말고 채운다
        pad = Image.new('RGB', (w, h), (34, 44, 32))
        pad.paste(im, ((w - im.width) // 2, (h - im.height) // 2))
        im = pad
    return Image.blend(im, Image.new('RGB', (w, h), (26, 30, 24)), dim).convert('RGBA')


def text(draw, xy, s, size, fill=CREAM, anchor='la'):
    """픽셀 폰트로 쓰고 검은 테를 두른다 (바탕이 무엇이든 읽히게)."""
    f = ImageFont.truetype(FONT, size)
    x, y = xy
    for dx in (-2, 0, 2):
        for dy in (-2, 0, 2):
            if dx or dy:
                draw.text((x + dx, y + dy), s, font=f, fill=INK, anchor=anchor)
    draw.text((x, y), s, font=f, fill=fill, anchor=anchor)
    return f


def char(scale, bust=False):
    """플레이어 도트. bust면 허리 위만 (납작한 칸에서 얼굴이 커진다)."""
    im = trim(Image.open(CHAR).convert('RGBA'))
    if bust:
        im = im.crop((0, 0, im.width, round(im.height * 0.58)))
    return nearest(im, scale)


def cast(scale):
    """주민 몇 명 — 「사람이 사는 마을」이 캡슐에서 읽히게."""
    out = []
    for name in CAST:
        p = os.path.join(GAME, 'assets', 'sprites', name + '.png')
        if os.path.exists(p):
            out.append(nearest(trim(Image.open(p).convert('RGBA')), scale))
    return out


# ------------------------------------------------------------------ 배치

def wide(w, h, tsize, cscale, bust, crowd=True, sub=True):
    """가로로 긴 칸 — 왼쪽에 제목, 오른쪽에 사람들."""
    im = backdrop(w, h)
    d = ImageDraw.Draw(im)
    # 오른쪽부터: 주인공을 제일 크게, 주민은 그 옆에 **같은 바닥선**으로.
    # 바닥선이 어긋나면 붕 떠 보인다 (공중에 선 사람이 된다).
    hero = char(cscale, bust)
    hx, hy = w - hero.width - round(w * 0.04), h - hero.height
    if crowd:
        gap = round(w * 0.015)
        x = hx - gap
        # 주민 도트는 32x48, 주인공은 128x192(4배로 그려 둔 것)다.
        # 같은 배율로 놓으면 주민이 4분의 1로 쪼그라든다 — 3배로 맞춰
        # 주인공보다 조금 작게(뒤에 선 것처럼) 둔다.
        for c in cast(max(1, cscale * 3)):
            x -= c.width + gap
            if x < w * 0.42:                    # 제목 자리는 침범하지 않는다
                break
            im.alpha_composite(c, (x, h - c.height))
    im.alpha_composite(hero, (hx, hy))
    text(d, (round(w * 0.05), round(h * 0.30)), TITLE, tsize)
    if sub:
        text(d, (round(w * 0.05), round(h * 0.30) + tsize + round(h * 0.03)),
             SUB, max(11, tsize // 2), GOLD)
    return im


def tall(w, h, tsize, cscale):
    """세로로 긴 칸 — 위에 제목, 아래에 사람."""
    im = backdrop(w, h)
    d = ImageDraw.Draw(im)
    hero = char(cscale)
    im.alpha_composite(hero, ((w - hero.width) // 2, h - hero.height))
    text(d, (w // 2, round(h * 0.10)), TITLE, tsize, anchor='ma')
    text(d, (w // 2, round(h * 0.10) + tsize + round(h * 0.02)), SUB,
         max(11, tsize // 2), GOLD, anchor='ma')
    return im


def face(size, scale):
    """프로필 — 얼굴만. 유튜브는 98px로 줄여 보여주므로 전신은 안 보인다."""
    im = Image.new('RGBA', (size, size), (88, 138, 74, 255))
    src = trim(Image.open(CHAR).convert('RGBA'))
    head = src.crop((0, 0, src.width, round(src.height * 0.44)))
    big = nearest(head, scale)
    im.alpha_composite(big, ((size - big.width) // 2, (size - big.height) // 2))
    return im


# 유튜브 배너는 2048x1152로 올리지만 **가운데 1235x338만 어디서나 보인다.**
def yt_banner():
    W, H, SW, SH = 2048, 1152, 1235, 338
    im = Image.new('RGBA', (W, H), (26, 30, 24, 255))
    inner = wide(SW, SH, 55, 1, False, crowd=True)
    im.alpha_composite(inner, ((W - SW) // 2, (H - SH) // 2))
    return im


JOBS = [
    ('steam_header_460.png', lambda: wide(460, 215, 33, 1, False)),
    ('steam_small_462.png', lambda: wide(462, 174, 22, 1, False, crowd=False)),
    ('steam_main_616.png', lambda: wide(616, 353, 44, 1, False)),
    ('steam_page_bg_1438.png', lambda: wide(1438, 810, 88, 3, False)),
    ('steam_libhero_3840.png', lambda: wide(3840, 1240, 121, 3, False)),
    ('steam_vertical_374.png', lambda: tall(374, 448, 33, 1)),
    ('steam_library_600.png', lambda: tall(600, 900, 44, 3)),
    ('yt_banner_2048.png', yt_banner),
    ('yt_thumbnail_1280.png', lambda: wide(1280, 720, 77, 3, False)),
    ('yt_profile_800.png', lambda: face(800, 4)),
]

for name, fn in JOBS:
    im = fn().convert('RGB')
    im.save(os.path.join(OUT, name))
    print('  %-28s %dx%d' % (name, im.width, im.height))

print('\n제목은 게임 폰트(Galmuri11)로 얹었다. 로고를 따로 만들면 이 자리에 넣으면 된다.')
