#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""도트 한 장마다 「어디가 무엇인가」를 적은 재질판을 굽는다.

새 도트는 AI가 그린 것이라 같은 재질 안에서도 색이 수십 가지고, 반대로
**다른 재질이 같은 색**을 쓴다 (검정은 윤곽이면서 동시에 남자 바지다).
그래서 색만 보고 갈아입힐 수가 없다 — 색 대신 자리로 가른다.

한 칸마다 0~5 를 매겨 assets/sprites/mat/ 에 회색 그림으로 굽는다.
  0 안 바꿈(윤곽·눈·장식) / 1 살결 / 2 머리 / 3 윗도리 / 4 아랫도리 / 5 신발
번호는 40씩 띄워 적는다 (0·40·80·…). 그래야 눈으로도 구별되고, 혹시 임포트가
값을 한둘 흔들어도 40으로 나누어 반올림하면 제 번호로 돌아온다.

가르는 순서
  살결   : 밝고 따뜻한 색 (v>=0.80, s<=0.62, 붉은 쪽) — 이것만은 색으로 는다
  눈     : 얼굴 상자 안에 있으면서 상자 **밖에는 한 번도 안 나오는** 색
  머리   : 남자는 얼굴 아래로 안 내려오니 「얼굴 밑줄 위 + 따뜻한 색」,
           여자는 머리가 허리까지 오지만 보라색을 쓰는 곳이 거기뿐이라 색으로
  윗·아랫·신발 : 먼저 높이로 어림잡고, **색마다 표결**해서 한 색이 두 군데로
           갈라지지 않게 한다 (소매 끝이 바지 높이까지 내려오는 것을 막는다)
  검정   : 바깥 공기에 닿으면 윤곽(0), 속에 있으면 이웃이 많은 재질로
"""
import colorsys
import os
import sys
from collections import Counter, deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.abspath(os.path.join(HERE, '..', '..', 'sprites'))
OUT = os.path.join(SPR, 'mat')

NONE, SKIN, HAIR, TOP, BOT, SHOE = range(6)
STEP = 40          # 번호 사이 간격 (임포트가 값을 흔들어도 버티게)
DARK = 36          # 이보다 어두우면 「검정」으로 미뤄 둔다

EYE_MAX = 40       # 얼굴 안의 섬이 이보다 작으면 눈·무늬로 본다

# 갈아입혀도 그대로 두는 색 — 여자 머리핀(하늘)과 넥타이(금). 옷 색을 바꿔도
# 남아 있어야 장식으로 보인다.
ACCENT = {
    'player_f': {(123, 230, 234), (158, 203, 221), (173, 214, 227), (186, 236, 231),
                 (233, 155, 48), (245, 173, 64), (211, 136, 36)},
}

CFG = {
    'new_boy':  dict(hair_hue=[(0.86, 1.001), (0.0, 0.16)], hair_anywhere=False,
                     split=(38, 43)),
    'player_f': dict(hair_hue=[(0.72, 0.98)], hair_anywhere=True,
                     split=(34, 42)),
}
SFX = (['%s_idle' % d for d in ('down', 'side', 'up')]
       + ['%s_walk_%d' % (d, i) for d in ('down', 'side', 'up') for i in range(4)]
       + ['%s_swing_%d' % (d, i) for d in ('down', 'side', 'up') for i in range(5)]
       + ['down_blink', 'side_blink'])
# 게임 판은 팩의 네 배다 (install_game.py). 가르기는 팩 칸(32x48·48x48)에서 하고
# 결과를 도로 네 배로 키운다 — split 행 번호 같은 상수가 전부 팩 칸 기준이다
UP = 4


def hsv(c):
    return colorsys.rgb_to_hsv(*[x / 255.0 for x in c])


def is_skin(c):
    h, s, v = hsv(c)
    return v >= 0.80 and s <= 0.62 and (h <= 0.10 or h >= 0.95)


def in_hue(h, spans):
    return any(a <= h < b for a, b in spans)


def blob(cells):
    """붙어 있는 칸끼리 묶어 가장 큰 덩이를 돌려준다."""
    left, best = set(cells), []
    while left:
        p = left.pop()
        q, g = deque([p]), [p]
        while q:
            x, y = q.popleft()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in left:
                    left.discard(n)
                    g.append(n)
                    q.append(n)
        if len(g) > len(best):
            best = g
    return best


def groups8(cells):
    """붙어 있는 칸끼리 묶는다 (대각선도 붙은 것으로 친다)."""
    left, out = set(cells), []
    while left:
        p = left.pop()
        q, g = deque([p]), [p]
        while q:
            x, y = q.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in left:
                        left.discard(n)
                        g.append(n)
                        q.append(n)
        out.append(g)
    return out


def stage1(path, pre, cfg):
    """검정과 몸통을 뺀 나머지를 가른다."""
    im = Image.open(path).convert('RGBA')
    if im.size[1] % (48 * UP) == 0:            # 네 배로 키워 넣은 게임 판 -> 팩 칸으로
        im = im.resize((im.size[0] // UP, im.size[1] // UP), Image.NEAREST)
    px, (W, H) = im.load(), im.size
    op = [(x, y) for y in range(H) for x in range(W) if px[x, y][3]]
    mat = {}
    skin = [p for p in op if is_skin(px[p][:3])]
    face = blob(skin)
    fx0, fx1 = min(x for x, _ in face), max(x for x, _ in face)
    fy0, fy1 = min(y for _, y in face), max(y for _, y in face)
    for p in skin:
        mat[p] = SKIN
    cand = [p for p in op if p not in mat and max(px[p][:3]) > DARK]
    # 눈 — 얼굴 상자 안에만 있는 작은 섬. 색으로 가르면 안 된다. 눈동자의
    # 흰 점은 양말 흰색과 같은 색이고, 여자 눈매는 머리색과 같은 자주다.
    inface = set()
    for g in groups8(cand):
        if len(g) <= EYE_MAX and all(fx0 <= x <= fx1 and fy0 <= y <= fy1 for x, y in g):
            inface.update(g)
    acc = ACCENT.get(pre, set())
    body = []
    for p in cand:
        c = px[p][:3]
        if p in inface or c in acc:
            mat[p] = NONE
        elif in_hue(hsv(c)[0], cfg['hair_hue']) and (cfg['hair_anywhere'] or p[1] <= fy1):
            mat[p] = HAIR
        else:
            body.append(p)
    return im, px, W, H, mat, body


def band(y, split):
    return TOP if y < split[0] else (BOT if y < split[1] else SHOE)


def fill_black(px, W, H, mat, split):
    """검정 칸 나누기 — 바깥에 닿으면 윤곽, 속이면 이웃 표결."""
    todo = [(x, y) for y in range(H) for x in range(W)
            if px[x, y][3] and (x, y) not in mat]
    for p in todo:
        x, y = p
        rim = any(not (0 <= x + dx < W and 0 <= y + dy < H) or px[x + dx, y + dy][3] == 0
                  for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        if rim:
            mat[p] = NONE
    rest = [p for p in todo if p not in mat]
    for _ in range(12):
        if not rest:
            break
        add = {}
        for (x, y) in rest:
            vote = Counter()
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    q = (x + dx, y + dy)
                    m = mat.get(q)
                    if m is None or m == NONE:
                        continue
                    vote[m] += 3 if (dx == 0 or dy == 0) else 1
            if vote:
                add[(x, y)] = vote.most_common(1)[0][0]
        if not add:
            break
        mat.update(add)
        rest = [p for p in rest if p not in mat]
    for p in rest:
        mat[p] = band(p[1], split)


def run(write):
    if write:
        os.makedirs(OUT, exist_ok=True)
    for pre, cfg in CFG.items():
        frames = []
        vote = {}                  # 색 -> 높이 표결 (한 색이 두 군데로 안 갈라지게)
        for sfx in SFX:
            path = os.path.join(SPR, '%s_%s.png' % (pre, sfx))
            if not os.path.exists(path):
                continue                       # 휘두르기가 아직 없는 방향
            im, px, W, H, mat, body = stage1(path, pre, cfg)
            for p in body:
                vote.setdefault(px[p][:3], Counter())[band(p[1], cfg['split'])] += 1
            frames.append((sfx, px, W, H, mat, body))
        pick = {c: v.most_common(1)[0][0] for c, v in vote.items()}
        tally = Counter()
        for sfx, px, W, H, mat, body in frames:
            for p in body:
                mat[p] = pick[px[p][:3]]
            fill_black(px, W, H, mat, cfg['split'])
            img = Image.new('L', (W, H), 0)
            ip = img.load()
            for (x, y), m in mat.items():
                ip[x, y] = m * STEP
                tally[m] += 1
            if write:
                img.resize((W * UP, H * UP), Image.NEAREST).save(
                    os.path.join(OUT, '%s_%s.png' % (pre, sfx)))
        print('  %-9s %s' % (pre, ' '.join(
            '%s=%d' % (n, tally[i]) for i, n in enumerate(
                ['안바꿈', '살결', '머리', '윗도리', '아랫도리', '신발']))))
    print('썼다' if write else '적어만 봤다 — 정말 하려면 --write')


run('--write' in sys.argv)
