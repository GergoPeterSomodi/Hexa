#!/usr/bin/env python3
"""Lint for the Godot port (godot/): the rules of docs/roadmap/godot-port-plan.md, B3.

A text scan with no third-party packages (it runs in CI as it is). It checks:

- the layers: a file may use res:// scripts and scenes of its own layer or a lower one; shell/ never
  uses core/state or core/systems directly (it reads views);
- core/ files extend RefCounted and make no engine calls (no Node, scene tree, Input, OS, Time, Engine,
  threads, await);
- core/ takes its luck only through core/rng.gd;
- no Godot 3 spellings in godot/ (yield, export var, onready var, setget, string connect, instance(), tool).

Limits: class_name references are not followed, only res:// paths. A new file under core/ must be listed in
LAYER_RANK. Comments are removed before the scan; string contents are not.

Usage: python tools/lint_godot.py godot      (exit status 1 and one line per finding when something fails)
"""

import re
import sys
from pathlib import Path

# Rank of each part of core/. A file may use res:// files of its own rank or a lower one.
# Order from B3: data -> state -> systems -> world -> game -> views -> shell.
CORE_RANK = [
    ("rng.gd", 0),
    ("hexgrid.gd", 0),
    ("geo.gd", 0),
    ("bus.gd", 0),
    ("data/", 1),
    ("state/", 2),
    ("mapgen/", 3),
    ("systems/", 3),
    ("world.gd", 4),
    ("saves.gd", 4),
    ("game.gd", 5),
    ("ai/", 5),
    ("views/", 5),
]
SHELL_RANK = 6
TOP_RANK = 9  # tests/ and tools/ may use everything
SHELL_FORBIDDEN_PREFIXES = ("core/state/", "core/systems/")

CORE_FORBIDDEN = [
    (r"\bawait\b", "await is not allowed in core/ (no coroutines)"),
    (r"(?<![\w.])(Input|OS|Time|Engine|DisplayServer|ProjectSettings|Thread|Mutex|Semaphore|WorkerThreadPool)\.",
     "engine singleton in core/ (B3: core/ runs headless with no engine calls)"),
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
    (r"\byield\b", "yield is Godot 3 (use await, but not in core/)"),
    (r"(?<!@)\bexport\s+var\b|(?<!@)\bexport\s*\(", "export var / export(...) is Godot 3 (use @export)"),
    (r"(?<!@)\bonready\s+var\b", "onready var is Godot 3 (use @onready)"),
    (r"\bsetget\b", "setget is Godot 3 (use a setter block)"),
    (r"\.instance\s*\(", "instance() is Godot 3 (use instantiate())"),
    (r"\.connect\s*\(\s*[\"']", "string connect() is Godot 3 (use signal.connect(callable))"),
    (r"\bTileMap\b", "the TileMap node is Godot 3 style (use TileMapLayer)"),
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


def lint_file(root: Path, path: Path, findings: list) -> None:
    rel = path.relative_to(root).as_posix()
    is_gd = path.suffix == ".gd"
    raw_lines = path.read_text(encoding="utf-8").splitlines()
    lines = [strip_comments(line) if is_gd else line for line in raw_lines]

    def report(lineno: int, message: str) -> None:
        findings.append(f"{root.name}/{rel}:{lineno}: {message}")

    in_core = rel.startswith("core/")
    rank = rank_of(rel)
    if in_core and rank is None:
        report(1, "not listed in CORE_RANK (tools/lint_godot.py): say which layer this file is")

    for lineno, line in enumerate(lines, start=1):
        for pattern, message in GODOT3_FORBIDDEN:
            if re.search(pattern, line):
                report(lineno, message)
        if line.strip() == "tool" and is_gd:
            report(lineno, "tool is Godot 3 (use @tool)")
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
            if base != "RefCounted" and not base.startswith('"res://core/'):
                report(lineno, f"core/ files extend RefCounted, not {base} (B3)")

        for match in RES_REF.finditer(line):
            target = match.group(0)[len("res://"):]
            if not target.endswith((".gd", ".tscn")):
                continue
            if rel.startswith("shell/") and target.startswith(SHELL_FORBIDDEN_PREFIXES):
                report(lineno, f"shell/ reads {target} directly; go through a view in core/views/ (B3)")
                continue
            target_rank = rank_of(target)
            if target_rank is None:
                report(lineno, f"{target} is not listed in CORE_RANK (tools/lint_godot.py)")
            elif rank is not None and target_rank > rank:
                report(lineno, f"{rel} uses {target}, a higher layer (B3: references point down only)")


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
