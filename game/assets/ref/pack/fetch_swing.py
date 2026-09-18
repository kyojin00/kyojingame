#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PixelLab 에서 휘두르기 동작을 뽑아 받아 온다.

주인공 두 벌은 PixelLab 계정에 캐릭터로 남아 있다(CHAR). 걷기는 거기서
Walk 템플릿으로 뽑았지만, 골격 템플릿에는 도끼질이 없어서 휘두르기는
**글로 동작을 적어 주는 v3 방식**으로 뽑는다. 방향마다 한 번씩(생성 1회),
열 장이 온다. 게임은 그중 다섯 장을 고른다 (install_swing.py).

  python3 fetch_swing.py --submit          # 여섯 벌(남녀 × 앞·옆·뒤) 요청 -> swing_jobs.txt
  python3 fetch_swing.py --fetch           # 끝난 것을 swing_src/<boy|girl>/<down|side|up>/ 에 받는다

옆은 east 다 — 게임은 오른쪽 보는 옆모습만 쓰고 왼쪽은 뒤집어 그린다
(install_rot.py 와 같은 규약). 받은 장은 68x68 이고 색은 원본 그대로다.

키는 환경변수 PIXELLAB_API_KEY 로 받는다.
"""
import base64
import json
import os
import sys
import time
import urllib.request

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
API = 'https://api.pixellab.ai/v2'
CHAR = {
    'boy': 'c4c0509e-1c56-4912-984b-fa6c58af8347',
    'girl': '58cce11c-2f69-4705-a821-7e25b24da639',
}
DIRS = {'down': 'south', 'side': 'east', 'up': 'north'}
JOBS = os.path.join(HERE, 'swing_jobs.txt')
OUT = os.path.join(HERE, 'swing_src')

# 시험 세 벌 중 이 문구(enhance 로 늘린 것)가 「머리 위로 감았다가 허리를 굽혀
# 내리치고 되돌아오는」 다섯 위상을 다 냈다. 짧은 문구는 만세하고 절하는 데서 끝났다
PROMPT = ("The character begins by rapidly raising both arms high above their head, "
          "then forcefully swings them down in a wide arc toward the ground. As the arms "
          "descend, the character's torso bends forward at the waist until their arms are "
          "extended straight down toward their feet. After a brief moment of impact, the "
          "character fluidly straightens their torso and lowers their arms back to their "
          "sides, returning to their original standing posture. Hands are empty, no tool. "
          "Feet stay planted.")
FRAMES = 10
SEED = 4242


def call(path, body=None):
    key = os.environ.get('PIXELLAB_API_KEY', '')
    if not key:
        sys.exit('PIXELLAB_API_KEY 가 없다')
    req = urllib.request.Request(
        API + path, data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json',
                 'User-Agent': 'kyojin-fetch-swing'})
    return json.load(urllib.request.urlopen(req, timeout=120))


def submit():
    lines = []
    for kind, cid in CHAR.items():
        for d, face in DIRS.items():
            r = call('/characters/animations', {
                'character_id': cid, 'mode': 'v3', 'animation_name': 'swing_' + face,
                'action_description': PROMPT, 'frame_count': FRAMES,
                'keep_first_frame': False, 'directions': [face], 'seed': SEED})
            jid = r['background_job_ids'][0]
            print('%s %s -> %s' % (kind, d, jid))
            lines.append('%s %s %s' % (kind, d, jid))
    open(JOBS, 'w').write('\n'.join(lines) + '\n')
    print('적어 둠: %s' % JOBS)


def sheet(ims, path, scale=5):
    w, h = ims[0].size
    out = Image.new('RGBA', (len(ims) * (w * scale + 4), h * scale), (40, 40, 48, 255))
    for i, im in enumerate(ims):
        big = im.resize((w * scale, h * scale), Image.NEAREST)
        out.paste(big, (i * (w * scale + 4), 0), big)
    out.save(path)


def fetch():
    if not os.path.exists(JOBS):
        sys.exit('%s 가 없다 — 먼저 --submit' % JOBS)
    todo = [ln.split() for ln in open(JOBS) if ln.strip()]
    pending = True
    while pending:
        pending = False
        for kind, d, jid in todo:
            dest = os.path.join(OUT, kind, d)
            if os.path.exists(os.path.join(dest, 'f0.png')):
                continue
            r = call('/background-jobs/' + jid)
            st = r.get('status')
            if st == 'processing':
                pending = True
                print('%s %s 아직 (%s)' % (kind, d, str(r.get('last_response', {}).get('progress', ''))[:30]))
                continue
            if st != 'completed':
                print('%s %s 실패: %s' % (kind, d, str(r.get('last_response'))[:300]))
                continue
            os.makedirs(dest, exist_ok=True)
            ims = []
            for i, im in enumerate(r['last_response']['images']):
                raw = base64.b64decode(im['base64'])
                open(os.path.join(dest, 'f%d.png' % i), 'wb').write(raw)
                ims.append(Image.open(os.path.join(dest, 'f%d.png' % i)).convert('RGBA'))
            sheet(ims, os.path.join(OUT, 'sheet_%s_%s.png' % (kind, d)))
            print('%s %s 받음 — %d장 %dx%d' % (kind, d, len(ims), ims[0].size[0], ims[0].size[1]))
        if pending:
            time.sleep(15)


if __name__ == '__main__':
    if '--submit' in sys.argv:
        submit()
    elif '--fetch' in sys.argv:
        fetch()
    else:
        print(__doc__)
