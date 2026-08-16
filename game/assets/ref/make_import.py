#!/usr/bin/env python3
# .import 파일 만들기 — **이걸 빠뜨리면 그림이 조용히 사라진다.**
#
# 고도(Godot)의 .import 는 「지워도 되는 캐시」가 아니다. 그림의 UID와
# 가져오기 설정이 여기 들어 있고, 이 파일이 없으면 load() 가 null 을
# 돌려준다. 그런데 AtlasTexture 는 atlas 가 null 이어도 **오류 한 줄 없이
# 아무것도 안 그린다** — 물가 타일 256장이 통째로 사라졌는데 로그가
# 깨끗해서 한참을 헤맸다.
#
# 그래서 sprites/ 에 PNG를 새로 넣을 때는 반드시 이걸 같이 돌린다.
#
#   python3 make_import.py                  # 짝 없는 PNG를 모두 찾아 만든다
#   python3 make_import.py a.png b.png      # 지정한 것만
#
# .ctex 경로의 해시는 고도가 쓰는 것과 같다 — 원본 경로 문자열의 md5.
import hashlib
import os
import random
import sys

SPR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites")
SPR = os.path.normpath(SPR)

TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{name}-{h}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/sprites/{name}"
dest_files=["res://.godot/imported/{name}-{h}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

# 고도의 UID 는 base-32 비슷한 제 나름의 글자표를 쓴다. 값 자체는 아무거나
# 되어도 되고 **서로 겹치지만 않으면** 된다 — 파일 이름에서 뽑아 늘 같은
# 값이 나오게 한다 (다시 돌려도 UID 가 안 바뀐다)
ALPHA = "abcdefghijklmnopqrstuvwxyz0123456789"


def uid_for(name: str) -> str:
    rnd = random.Random("kyojin-uid:" + name)
    return "".join(rnd.choice(ALPHA) for _ in range(13))


def write_one(name: str) -> bool:
    dst = os.path.join(SPR, name + ".import")
    if os.path.exists(dst):
        return False
    src = "res://assets/sprites/" + name
    h = hashlib.md5(src.encode("utf-8")).hexdigest()
    with open(dst, "w", encoding="utf-8") as f:
        f.write(TEMPLATE.format(name=name, h=h, uid=uid_for(name)))
    return True


def main() -> None:
    names = [os.path.basename(a) for a in sys.argv[1:]]
    if not names:
        names = sorted(n for n in os.listdir(SPR) if n.endswith(".png"))
    made = [n for n in names if write_one(n)]
    if made:
        print("%d개 만들었다: %s" % (len(made), ", ".join(made)))
    else:
        print("모두 이미 있다 (%d개 확인)" % len(names))


if __name__ == "__main__":
    main()
