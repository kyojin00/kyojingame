#!/usr/bin/env python3
"""큰 배너(story_banner)는 메인 스토리가 **시작할 때와 끝날 때만** 뜬다.

중간 마디마다 뜨면 그 두 번이 특별하지 않다. 「교진 마을 도착 —
여기서부터가 진짜 하루다」처럼 어중간한 배너가 도로 끼어드는 것을 막는다.
"""
import re
import sys
from pathlib import Path

OK = re.compile(r"^메인 스토리 \d+ (시작|완결)$")
ROOT = Path(__file__).resolve().parent.parent / "game" / "scripts"

bad = []
for path in sorted(ROOT.glob("*.gd")):
    if path.name == "dev_harness.gd":
        continue
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        m = re.search(r'story_banner\(\s*"([^"]*)"', line)
        if m and not OK.match(m.group(1)):
            bad.append(f"{path.name}:{n}  「{m.group(1)}」")

if bad:
    print("메인 스토리 시작/완결이 아닌 배너:")
    for b in bad:
        print("  " + b)
    sys.exit(1)
print("배너는 스토리 시작·완결에만")
