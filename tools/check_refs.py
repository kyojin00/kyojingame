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
    "renderer.gd": "renderer",
    "net_sync.gd": "netsync",
    "object_nodes.gd": "objnode",
    "farming.gd": "farming",
    "fishing.gd": "fishing",
    "riding.gd": "riding",
    "tool_use.gd": "toolwork",
    "interact.gd": "actions",
    "day_cycle.gd": "daycycle",
    "npcs.gd": "npcmgr",
    "save_load.gd": "saveio",
    "player_actions.gd": "doing",
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
    # `self`는 옮겨 오기 전에는 main이었다. 이제는 모듈 노드라 뜻이 바뀐다.
    # 컴파일에 안 걸리고 그 코드가 도는 순간에야 터지므로 여기서 잡는다.
    for fname in MODULES:
        path = os.path.join(SCRIPTS, fname)
        if not os.path.exists(path):
            continue
        for i, line in enumerate(open(path, encoding="utf-8"), 1):
            code = line.split("#")[0]
            if re.search(r"(?<![\w.])self\b", code):
                bad.append("%s:%d: self — main을 뜻하던 자리인지 확인 (아마 `m`)"
                           % (path, i))
            # 지역 이름 `m`은 모듈의 main 참조를 통째로 가린다
            if re.search(r"\b(?:for|var)\s+m\b", code) and "var m: Kyojin" not in code:
                bad.append("%s:%d: 지역 이름 `m` — main 참조를 가린다" % (path, i))
    if bad:
        print("옛 주소로 부르는 곳 %d군데:" % len(bad))
        for b in sorted(bad):
            print("  " + b)
        sys.exit(1)
    print("옛 주소로 부르는 곳 없음")


main()
