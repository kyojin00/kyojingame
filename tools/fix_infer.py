#!/usr/bin/env python3
"""모듈을 거쳐 부르는 자리의 `:=` 타입 추론을 되살린다.

모듈 참조는 `var farming: Node`이라 `farming._crop_thirsty(c)`가 Variant가 된다.
그러면 `var x := farming._crop_thirsty(c)`가 「타입을 알 수 없다」로 막힌다.
모듈 쪽 함수 선언의 `-> 타입`을 읽어 와서 `var x: bool = ...`로 바꿔 준다.

실행:  python3 tools/fix_infer.py
"""
import glob
import os
import re

SCRIPTS = "game/scripts"
HANDLES = {
    "worldgen": "world_gen.gd", "netsync": "net_sync.gd", "renderer": "renderer.gd",
    "village": "village_ui.gd", "story": "story.gd", "objnode": "object_nodes.gd",
    "farming": "farming.gd", "fishing": "fishing.gd", "riding": "riding.gd",
    "harness": "dev_harness.gd", "toolwork": "tool_use.gd", "actions": "interact.gd",
    "daycycle": "day_cycle.gd", "npcmgr": "npcs.gd", "saveio": "save_load.gd",
    "doing": "player_actions.gd",
}


def return_types(path):
    if not os.path.exists(path):
        return {}
    out = {}
    for m in re.finditer(r"^func\s+(\w+)\s*\([^)]*\)\s*->\s*([\w.]+)\s*:",
                         open(path, encoding="utf-8").read(), re.M):
        out[m.group(1)] = m.group(2)
    return out


def main():
    types = {h: return_types(os.path.join(SCRIPTS, f)) for h, f in HANDLES.items()}
    pat = re.compile(r"var\s+(\w+)\s*:=\s*((?:m\.)?(" + "|".join(HANDLES) + r")\.(\w+)\()")
    total = 0
    for path in glob.glob(os.path.join(SCRIPTS, "*.gd")):
        src = open(path, encoding="utf-8").read()
        fixed = []

        def sub(mo):
            name, call, handle, fn = mo.groups()
            t = types.get(handle, {}).get(fn)
            if not t or t == "void":
                return mo.group(0)
            fixed.append(name)
            return "var %s: %s = %s" % (name, t, call)

        new = pat.sub(sub, src)
        if fixed:
            open(path, "w", encoding="utf-8").write(new)
            print("%s: %s" % (os.path.basename(path), ", ".join(fixed)))
            total += len(fixed)
    print("고친 자리 %d개" % total)


main()
