#!/usr/bin/env python3
"""Lint for the Godot port (godot/): the layers of docs/architecture/godot-architecture.md (sections 2, 6 and 7).

A text scan with no third-party packages (it runs in CI as it is). It checks:

- the layers: a file may use res:// scripts and scenes of its own layer or a lower one. Bottom to top: defs, state,
  systems, game, views, ai, shell. mapgen sits beside systems and is used only by tools and tests (it runs in tools);
- core/ files extend RefCounted (core/defs/ files may extend Resource: the definitions are Resources) and make no engine calls (no Node, scene tree, Input, OS, Time, Engine,
  threads, await);
- core/ takes its luck only through core/rng.gd;
- no Godot 3 spellings in godot/ (yield, export var, onready var, setget, string connect, instance(), tool);
- the size limits (section 6): a script over 1,200 lines or a function over 100 lines fails; a script over 800 lines
  needs an entry with its reason in SIZE_REASONS below;
- UI style rules (ui-style-and-feedback-spec.md section 2, ui-and-controls-spec.md section 3.4):
  no theme_override_ in shell/**/*.tscn; no raw Color(, StyleBoxFlat.new, StyleBoxTexture.new, or assets/ui/kit
  paths in shell/{ui,hud,screens,panels,app}/ outside tokens.gd and kit_theme.gd.

Limits: class_name references are not followed, only res:// paths. A new file under core/ must be listed in
CORE_RANK. Comments are removed before the scan; string contents are not.

Usage: python tools/lint_godot.py godot      (exit status 1 and one line per finding when something fails)
"""

import re
import sys
from pathlib import Path

# Rank of each part of core/. A file may use res:// files of its own rank or a lower one.
CORE_RANK = [
    ("rng.gd", 0),
    ("hexgrid.gd", 0),
    ("geo.gd", 0),
    ("defs/", 1),
    ("state/", 2),
    ("systems/", 3),
    ("mapgen/", 3),  # beside systems: generators, run in tools (MAPGEN_USERS)
    ("game/", 4),
    ("views/", 5),
    ("ai/", 6),
]
SHELL_RANK = 7
TOP_RANK = 9  # tests/ and tools/ may use everything
# Who may name res://core/mapgen/ paths: mapgen itself, tools and tests.
MAPGEN_USERS = ("core/mapgen/", "tools/", "tests/")

# Size limits (architecture section 6).
FILE_LIMIT = 1200
FILE_NEEDS_REASON = 800
FUNC_LIMIT = 100
SIZE_REASONS = {
    "core/mapgen/world_water.gd": "one routing model: corners, courses, the flood and the router share their state; "
                                  "split again when the Europe map arrives",
    "core/views/improve_preview.gd": "one card: the cells, the brings, the paybacks, the chips and the marks read the same preview",
    "tests/shell/test_ui_monkey.gd": "one monkey: every seed shares one step table, its invariants and counters",
}

CORE_FORBIDDEN = [
    (r"\bawait\b", "await is not allowed in core/ (no coroutines)"),
    (r"(?<![\w.])(Input|OS|Time|Engine|DisplayServer|ProjectSettings|Thread|Mutex|Semaphore|WorkerThreadPool)\.",
     "engine singleton in core/ (core/ runs headless with no engine calls)"),
    (r"\bget_tree\s*\(|\bget_node\s*\(|\$[A-Za-z_]|\bget_window\s*\(",
     "scene tree access in core/ (core/ has no Node)"),
]
LUCK_FORBIDDEN = [
    (r"(?<![\w.])(randi|randf|randomize|randi_range|randf_range|randfn|seed|shuffle|pick_random)\s*\(",
     "global random function in core/ (luck goes through rng.gd)"),
    (r"\.(shuffle|pick_random)\s*\(", "array shuffle uses the global random source (luck goes through rng.gd)"),
    (r"\bRandomNumberGenerator\b", "RandomNumberGenerator outside rng.gd (luck goes through rng.gd)"),
]
GODOT3_FORBIDDEN = [
    (r"\byield\s*\(", "yield() is Godot 3 (use await, but not in core/); the peace term &\"yield\" is a name, not a call"),
    (r"(?<!@)\bexport\s+var\b|(?<!@)\bexport\s*\(", "export var / export(...) is Godot 3 (use @export)"),
    (r"(?<!@)\bonready\s+var\b", "onready var is Godot 3 (use @onready)"),
    (r"\bsetget\b", "setget is Godot 3 (use a setter block)"),
    (r"\.instance\s*\(", "instance() is Godot 3 (use instantiate())"),
    (r"\.connect\s*\(\s*[\"']", "string connect() is Godot 3 (use signal.connect(callable))"),
    (r"\bTileMap\b", "the TileMap node is Godot 3 style (use TileMapLayer)"),
]

# UI style rules (Studiolo): ui-style-and-feedback-spec.md section 2, ui-and-controls-spec.md section 3.4.
THEME_OVERRIDE_ALLOWLIST: set[str] = set()
UI_STYLE_DIRS = ("shell/ui/", "shell/hud/", "shell/screens/", "shell/panels/", "shell/app/")
UI_STYLE_ALLOWLIST = {"shell/ui/tokens.gd", "shell/ui/kit_theme.gd", "shell/ui/parchment_tokens.gd"}
UI_STYLE_FORBIDDEN = [
    (r"\bColor\s*\(", "raw Color( literal in UI script (read Tokens instead)"),
    (r"\bStyleBoxFlat\.new\b", "StyleBoxFlat.new outside shell/ui/kit_theme.gd (use the generated Theme)"),
    (r"\bStyleBoxTexture\.new\b", "StyleBoxTexture.new outside shell/ui/kit_theme.gd (use the generated Theme)"),
    (r"assets/ui/kit\b", "direct assets/ui/kit path outside shell/ui/kit_theme.gd (use get_theme_icon / Theme)"),
]

RES_REF = re.compile(r"res://[^\"'\s)]+")


def strip_comments(line: str) -> str:
    """Removes a # comment, leaving # inside string literals alone."""
    quote = ""
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            return line[:i]
        i += 1
    return line


def core_rank(rel: str):
    """Rank of a path under core/ (rel is relative to godot/), or None when the file is not listed."""
    inner = rel[len("core/"):]
    for prefix, rank in CORE_RANK:
        if inner == prefix or inner.startswith(prefix):
            return rank
    return None


def rank_of(rel: str):
    if rel.startswith("core/"):
        return core_rank(rel)
    if rel.startswith("shell/"):
        return SHELL_RANK
    return TOP_RANK


def function_lengths(lines: list):
    """(line, length, name) of every top-level func: from its first line to its last indented or blank line."""
    starts = [i for i, line in enumerate(lines) if re.match(r"(static )?func \w+", line)]
    out = []
    for i in starts:
        end = len(lines)
        for j in range(i + 1, len(lines)):
            line = lines[j]
            if line and line[0] not in " \t#":
                end = j
                break
        while end - 1 > i and (lines[end - 1].strip() == "" or lines[end - 1].lstrip().startswith("#")):
            end -= 1
        name = re.match(r"(?:static )?func (\w+)", lines[i]).group(1)
        out.append((i + 1, end - i, name))
    return out


def lint_file(root: Path, path: Path, findings: list) -> None:
    rel = path.relative_to(root).as_posix()
    is_gd = path.suffix == ".gd"
    raw_lines = path.read_text(encoding="utf-8").splitlines()
    lines = [strip_comments(line) if is_gd else line for line in raw_lines]

    def report(lineno: int, message: str) -> None:
        findings.append(f"{root.name}/{rel}:{lineno}: {message}")

    if is_gd:
        if len(raw_lines) > FILE_LIMIT:
            report(1, f"{len(raw_lines)} lines: over {FILE_LIMIT}, split it (architecture section 6)")
        elif len(raw_lines) > FILE_NEEDS_REASON and rel not in SIZE_REASONS:
            report(1, f"{len(raw_lines)} lines: over {FILE_NEEDS_REASON} needs a reason in SIZE_REASONS (tools/lint_godot.py)")
        for start, length, name in function_lengths(raw_lines):
            if length > FUNC_LIMIT:
                report(start, f"function {name} is {length} lines: over {FUNC_LIMIT}, split it (architecture section 6)")

    in_core = rel.startswith("core/")
    in_shell_tscn = rel.startswith("shell/") and path.suffix == ".tscn"
    in_ui_style = rel.startswith(UI_STYLE_DIRS) and rel not in UI_STYLE_ALLOWLIST
    rank = rank_of(rel)
    if in_core and rank is None:
        report(1, "not listed in CORE_RANK (tools/lint_godot.py): say which layer this file is")

    for lineno, line in enumerate(lines, start=1):
        for pattern, message in GODOT3_FORBIDDEN:
            if re.search(pattern, line):
                report(lineno, message)
        if line.strip() == "tool" and is_gd:
            report(lineno, "tool is Godot 3 (use @tool)")
        if in_shell_tscn and not line.lstrip().startswith(";"):
            if rel not in THEME_OVERRIDE_ALLOWLIST and re.search(r"\btheme_override_", line):
                report(lineno, "theme_override_ in shell/ .tscn (use the generated Theme variations)")
            if re.search(r"assets/ui/kit\b", line):
                report(lineno, "direct assets/ui/kit path in shell/ .tscn (use Theme)")
        if is_gd and in_ui_style:
            for pattern, message in UI_STYLE_FORBIDDEN:
                if re.search(pattern, line):
                    report(lineno, message)
        if is_gd and in_core:
            for pattern, message in CORE_FORBIDDEN:
                if re.search(pattern, line):
                    report(lineno, message)
            if rel != "core/rng.gd":
                for pattern, message in LUCK_FORBIDDEN:
                    if re.search(pattern, line):
                        report(lineno, message)
        if is_gd and in_core and line.lstrip().startswith("extends "):
            base = line.split("extends ", 1)[1].strip()
            defs_resource = rel.startswith("core/defs/") and base == "Resource"
            if base != "RefCounted" and not defs_resource and not base.startswith('"res://core/'):
                report(lineno, f"core/ files extend RefCounted, not {base}")

        for match in RES_REF.finditer(line):
            target = match.group(0)[len("res://"):]
            if not target.endswith((".gd", ".tscn")):
                continue
            if target.startswith("core/mapgen/") and not rel.startswith(MAPGEN_USERS):
                report(lineno, f"{rel} uses {target}: mapgen runs only in tools (architecture section 2)")
                continue
            target_rank = rank_of(target)
            if target_rank is None:
                report(lineno, f"{target} is not listed in CORE_RANK (tools/lint_godot.py)")
            elif rank is not None and target_rank > rank:
                report(lineno, f"{rel} uses {target}, a higher layer (architecture section 2: references point down only)")


def main(argv: list) -> int:
    root = Path(argv[1] if len(argv) > 1 else "godot").resolve()
    if not (root / "project.godot").is_file():
        print(f"lint_godot: {root} has no project.godot", file=sys.stderr)
        return 2
    findings: list = []
    files = sorted(
        p for p in root.rglob("*")
        if p.is_file()
        and p.suffix in (".gd", ".tscn")
        and "addons" not in p.relative_to(root).parts
        and not any(part.startswith(".") for part in p.relative_to(root).parts)
    )
    for path in files:
        lint_file(root, path, findings)
    for finding in findings:
        print(finding)
    print(f"lint_godot: {len(files)} files, {len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
