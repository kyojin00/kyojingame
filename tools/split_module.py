#!/usr/bin/env python3
"""main.gd에서 함수 뭉치를 떼어 별도 스크립트로 옮긴다.

손으로 옮기면 `player`, `grid` 같은 main의 멤버를 전부 `m.`으로 바꿔야 하는데,
7000줄에서 그걸 눈으로 하면 반드시 하나를 빠뜨린다. 그래서 기계로 한다.

- 문자열과 주석은 먼저 가려 둔다 (그 안의 낱말은 건드리면 안 된다)
- main의 멤버(var/const/func)만 온전한 낱말일 때 `m.`을 붙인다
- 옮겨 가는 함수·변수끼리는 안 붙인다 (같은 파일 안이니까)
- 지역 변수·인자·for 변수는 제외한다
"""
import re
import sys

KEYWORDS = set("""
if elif else for while match break continue pass return func var const enum
class class_name extends is as in not and or await yield signal static
true false null self super void int float bool String Array Dictionary
Vector2 Vector2i Vector3 Rect2 Rect2i Color Callable Node Node2D Control
range len print push_error push_warning str randi randf randf_range randi_range
min max abs sin cos floor ceil round sqrt clamp lerp minf maxf absf clampf
mini maxi absi snapped sign posmod fmod deg_to_rad Time OS Input JSON
""".split())


def load(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def members_of(src):
    """main.gd의 최상위 멤버 이름 (들여쓰기 없는 선언만)."""
    out = set()
    for m in re.finditer(r"^(?:@onready\s+|@export\s+)?(?:var|const)\s+(\w+)", src, re.M):
        out.add(m.group(1))
    for m in re.finditer(r"^func\s+(\w+)", src, re.M):
        out.add(m.group(1))
    for m in re.finditer(r"^signal\s+(\w+)", src, re.M):
        out.add(m.group(1))
    return out


def split_blocks(src):
    """(머리주석 + func 본문) 덩어리로 자른다. [(name, text), ...] + 앞부분."""
    lines = src.split("\n")
    starts = [i for i, l in enumerate(lines) if l.startswith("func ")]
    blocks = []
    for idx, s in enumerate(starts):
        # 바로 위에 붙은 주석줄까지 함께 가져간다
        head = s
        while head > 0 and (lines[head - 1].startswith("#") or
                            (lines[head - 1].strip() == "" and head - 2 >= 0
                             and lines[head - 2].startswith("#"))):
            head -= 1
        # 함수 본문은 반드시 들여쓰기되어 있다. 들여쓰지 않은 줄이 나오면
        # 거기서 끝이다 — 함수 사이에 낀 `var` 선언까지 끌고 가면 안 된다.
        end = len(lines)
        for k in range(s + 1, len(lines)):
            l = lines[k]
            if l and not l[0].isspace() and not l.startswith("#"):
                end = k
                break
        # 다음 함수의 머리주석은 넘겨준다
        nxt = end
        while nxt > s and (lines[nxt - 1].strip() == "" or lines[nxt - 1].startswith("#")):
            nxt -= 1
        name = re.match(r"func\s+(\w+)", lines[s]).group(1)
        blocks.append({"name": name, "head": head, "start": s, "end": nxt})
    return lines, blocks


def mask(text):
    """문자열과 주석을 자리표시자로 바꾼다."""
    store = []

    def keep(m):
        store.append(m.group(0))
        return "\x00%d\x00" % (len(store) - 1)

    # 여러 줄 문자열 -> 홑/겹따옴표 -> 주석 순서로 가린다
    text = re.sub(r'"""(?:.|\n)*?"""', keep, text)
    text = re.sub(r'"(?:\\.|[^"\\])*"', keep, text)
    text = re.sub(r"'(?:\\.|[^'\\])*'", keep, text)
    text = re.sub(r"#[^\n]*", keep, text)
    return text, store


def unmask(text, store):
    # 자리표시자가 겹칠 수 있다: 주석 안에 문자열이 있으면 주석 자리표시자를
    # 되돌렸을 때 그 안에서 문자열 자리표시자가 다시 나온다. 다 없어질 때까지 돈다.
    for _ in range(8):
        if "\x00" not in text:
            break
        text = re.sub(r"\x00(\d+)\x00", lambda m: store[int(m.group(1))], text)
    return text


def locals_in(text):
    """옮기는 코드 안에서 새로 만들어지는 이름 (지역변수·인자·for 변수)."""
    out = set()
    for m in re.finditer(r"\bvar\s+(\w+)", text):
        out.add(m.group(1))
    for m in re.finditer(r"\bfor\s+(\w+)\s+in\b", text):
        out.add(m.group(1))
    for m in re.finditer(r"^func\s+\w+\(([^)]*)\)", text, re.M):
        for part in m.group(1).split(","):
            p = part.strip()
            if p:
                out.add(re.split(r"[:=\s]", p)[0])
    # 람다 인자
    for m in re.finditer(r"\bfunc\(([^)]*)\)", text):
        for part in m.group(1).split(","):
            p = part.strip()
            if p:
                out.add(re.split(r"[:=\s]", p)[0])
    return out


def prefix(text, names, ref):
    """온전한 낱말인 main 멤버 앞에 `ref.`를 붙인다 (문자열·주석은 알아서 가린다)."""
    masked, store = mask(text)
    return unmask(prefix_masked(masked, names, ref), store)


# CanvasItem/Node2D의 것 — 옮겨 간 모듈은 그냥 Node라 자기 것이 없다.
# 그대로 두면 「Function ... not found in base self」로 터진다.
CANVAS_CALLS = """
queue_redraw draw_texture_rect draw_rect draw_line draw_circle draw_string
draw_texture draw_polygon draw_colored_polygon draw_arc draw_set_transform
draw_multiline draw_dashed_line draw_char draw_string_outline
get_canvas_transform get_global_mouse_position get_local_mouse_position
get_viewport_transform to_local to_global make_canvas_position_local
""".split()


def fix_canvas_calls(masked, ref):
    for name in CANVAS_CALLS:
        masked = re.sub(r"(?<![\w.])" + name + r"\(", ref + "." + name + "(", masked)
    return masked


def prefix_masked(masked, names, ref):
    """이미 가려 둔 글에 접두사를 붙인다."""
    skip = locals_in(masked) | KEYWORDS

    def sub(m):
        w = m.group(0)
        if w in skip or w not in names:
            return w
        # 이미 무언가의 멤버로 쓰이는 중이면 (앞이 `.`) 건드리지 않는다
        i = m.start()
        j = i - 1
        while j >= 0 and masked[j] == " ":
            j -= 1
        if j >= 0 and masked[j] == ".":
            return w
        # 선언부(`var x`, `func x`, `const x`)도 건드리지 않는다
        pre = masked[max(0, i - 12):i]
        if re.search(r"\b(var|const|func|signal)\s+$", pre):
            return w
        return ref + "." + w

    return re.sub(r"\b\w+\b", sub, masked)


def main():
    cfg = __import__("json").loads(load(sys.argv[1]))
    src_path = cfg["source"]
    src = load(src_path)
    # 문자열·주석을 **줄로 자르기 전에** 가린다.
    # GDScript 문자열은 줄바꿈을 품을 수 있어서, 그냥 자르면 여러 줄 대사
    # 한가운데가 함수 경계로 오인된다 (실제로 광산 대화가 반토막 났다).
    msrc, store = mask(src)
    lines, blocks = split_blocks(msrc)

    move_funcs = set(cfg["funcs"])
    move_vars = set(cfg.get("vars", []))
    ref = cfg.get("ref", "m")

    missing = move_funcs - {b["name"] for b in blocks}
    if missing:
        sys.exit("!! 없는 함수: %s" % sorted(missing))

    all_members = members_of(msrc)
    # 함께 옮겨 가는 것들은 같은 파일에 있으니 접두사를 안 붙인다
    keep_names = all_members - move_funcs - move_vars

    # ---- 옮길 본문 모으기 ----
    taken = []
    drop = set()
    for b in blocks:
        if b["name"] not in move_funcs:
            continue
        taken.append("\n".join(lines[b["head"]:b["end"]]))
        drop.update(range(b["head"], b["end"]))

    # ---- 옮길 변수 선언 ----
    var_decls = []
    for i, l in enumerate(lines):
        m = re.match(r"^(?:@onready\s+)?var\s+(\w+)", l)
        if m and m.group(1) in move_vars:
            var_decls.append(l)
            drop.add(i)

    body = fix_canvas_calls(prefix_masked("\n\n\n".join(taken), keep_names, ref), ref)
    var_text = "\n".join(prefix_masked(v, keep_names, ref) for v in var_decls)

    module = cfg["header"].rstrip() + "\nextends Node\n\n"
    module += "var %s: KyojinMain    # main.gd\n" % ref
    if var_text:
        module += var_text + "\n"
    module += "\n\n" + body + "\n"
    with open(cfg["out"], "w", encoding="utf-8") as f:
        f.write(unmask(module, store))

    # ---- main에서 덜어내고, 남은 호출부를 모듈 쪽으로 돌린다 ----
    masked_rest = "\n".join(l for i, l in enumerate(lines) if i not in drop)
    handle = cfg["handle"]
    for name in sorted(move_funcs | move_vars, key=len, reverse=True):
        masked_rest = re.sub(r"(?<![\w.])" + re.escape(name) + r"\b",
                             handle + "." + name, masked_rest)
    rest = unmask(masked_rest, store)
    # 남은 줄바꿈 정리
    rest = re.sub(r"\n{4,}", "\n\n\n", rest)
    with open(src_path, "w", encoding="utf-8") as f:
        f.write(rest)

    # ---- 다른 스크립트가 옛 주소로 부르던 곳도 새 주소로 ----
    # (main.gd만 고치면, 다른 창이 부르는 자리는 컴파일에 안 걸리고
    #  그 코드가 실제로 도는 순간에야 터진다)
    keep = set(cfg.get("keep_wrapper", []))
    fixed = []
    for other in __import__("glob").glob("game/scripts/*.gd"):
        if other in (src_path, cfg["out"]):
            continue
        t = load(other)
        t2, tstore = mask(t)
        before = t2
        for name in sorted((move_funcs | move_vars) - keep, key=len, reverse=True):
            for pre in ("main.", "m."):
                t2 = re.sub(r"(?<![\w.])" + re.escape(pre + name) + r"\b",
                            pre + handle + "." + name, t2)
        if t2 != before:
            with open(other, "w", encoding="utf-8") as f:
                f.write(unmask(t2, tstore))
            fixed.append(other.split("/")[-1])
    if fixed:
        print("옛 주소 고침: %s" % ", ".join(sorted(fixed)))

    print("옮김: 함수 %d개 · 변수 %d개 -> %s" %
          (len(taken), len(var_decls), cfg["out"]))
    print("main.gd: %d줄 -> %d줄" % (len(lines), rest.count("\n") + 1))


main()
