#!/usr/bin/env python3
"""하네스 단계 번호가 겹치는지 본다.

단계 번호는 `match _shot_frames:`의 갈래다. 번호가 겹치면 **뒤에 온 갈래가
통째로 죽은 코드가 되고, 검사가 조용히 사라진다.** 실제로 다섯 번 당했다.

함수마다 따로 센다 — `_debug_tick`과 `_mp_tick`은 각자의 match라 같은 번호를
써도 상관없다.

실행:  python3 tools/check_steps.py
"""
import collections
import re
import sys

PATH = "game/scripts/dev_harness.gd"


def main():
    src = open(PATH, encoding="utf-8").read()
    # 최상위 func 단위로 자른다
    parts = re.split(r"^(func\s+\w+)", src, flags=re.M)
    bad = False
    for i in range(1, len(parts), 2):
        name, body = parts[i], parts[i + 1]
        # `394:` 한 갈래도, `394, 395, 396:`처럼 여러 번호를 묶은 갈래도 센다.
        # (묶은 쪽을 빼먹었더니 394가 두 번 쓰인 것을 오래도록 놓쳤다)
        nums = []
        for m in re.finditer(r"^\t\t(\d+(?:\s*,\s*\d+)*):", body, re.M):
            nums += [int(n) for n in m.group(1).split(",")]
        c = collections.Counter(nums)
        dup = sorted(n for n, k in c.items() if k > 1)
        if dup:
            bad = True
            print("%s: 겹친 단계 번호 %s — 뒤에 온 쪽이 죽은 코드다" % (name, dup))
    if bad:
        sys.exit(1)
    print("겹친 단계 번호 없음")


main()
