#!/usr/bin/env python3
"""갈라낸 모듈로 옮겨 간 이름을 아직 옛 주소로 부르는 곳을 찾는다.

main.gd에서 story.gd·world_gen.gd로 함수를 옮기면, main 안의 호출부는
split_module.py가 고쳐 준다. 하지만 **다른 스크립트**가 `main.xxx` /
`m.xxx`로 부르던 자리는 그대로 남는다. 그 자리는 컴파일 때 안 걸리고
그 코드가 실제로 도는 순간에야 터진다 — 스토리 하네스가 90초를 돌다
죽은 적이 있다.

실행:  python3 tools/check_refs.py
"""
import glob
import os
import re
import sys

SCRIPTS = "game/scripts"
MAIN = os.path.join(SCRIPTS, "main.gd")
# main의 자식으로 붙는 모듈들 (파일 -> main에서 부르는 이름)
MODULES = {
    "story.gd": "story",
    "world_gen.gd": "worldgen",
    "village_ui.gd": "village",
    "dev_harness.gd": "harness",
}


def top_level_names(path):
    src = open(path, encoding="utf-8").read()
    out = set()
    for pat in (r"^(?:@onready\s+|@export\s+)?(?:var|const)\s+(\w+)", r"^func\s+(\w+)"):
        out.update(m.group(1) for m in re.finditer(pat, src, re.M))
    out.discard("m")
    return out


def main():
    main_names = top_level_names(MAIN)
    bad = []
    for fname, handle in MODULES.items():
        path = os.path.join(SCRIPTS, fname)
        if not os.path.exists(path):
            continue
        moved = top_level_names(path) - main_names   # main에는 없고 모듈에만 있는 이름
        for other in glob.glob(os.path.join(SCRIPTS, "*.gd")):
            if os.path.basename(other) == fname:
                continue
            src = open(other, encoding="utf-8").read()
            for name in moved:
                for pref in ("main.", "m."):
                    if re.search(r"(?<![\w.])" + re.escape(pref + name) + r"\b", src):
                        bad.append("%s: %s%s  ->  %s.%s.%s"
                                   % (other, pref, name, pref.rstrip("."), handle, name))
    if bad:
        print("옛 주소로 부르는 곳 %d군데:" % len(bad))
        for b in sorted(bad):
            print("  " + b)
        sys.exit(1)
    print("옛 주소로 부르는 곳 없음")


main()
