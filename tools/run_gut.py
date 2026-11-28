#!/usr/bin/env python3
"""Runs the Godot game's GUT tests in groups, each group in its own process, and refuses a false pass.

    python tools/run_gut.py --godot <engine>                 every group, one after the other (about an hour)
    python tools/run_gut.py core shell --godot <engine>      some groups
    python tools/run_gut.py --list                           the group names (the GitHub workflow runs one job each)

The engine may come from the GODOT environment variable instead. Logs and JUnit reports go to --out.

Why groups: GUT keeps the text of every passed assert, so one process for everything runs a machine out of memory, and
the random-play tests are slow enough to be worth separate jobs.

GUT's exit code is not enough (it is 0 when a test file never loads), so a group fails when any of these is true:
it timed out or exited with an error; the output has a script error or an ignored script; a test file did not run; a
random-play group ran the wrong number of tests; a test is pending or risky without being listed in
godot/tests/pending_allowed.txt; one test or the whole process made too many asserts; or (Linux) memory use passed the
limit. One run at a time on a machine: a second one is refused while the first holds the lock.

Standard library only.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MONKEY_FILE = "tests/shell/test_ui_monkey.gd"

# The random-play groups: name -> substrings of test names (GUT's -gunit_test_name), each filter its own process.
# Every test of MONKEY_FILE must match exactly one filter; a new tier gets a new group here.
MONKEY_GROUPS: dict[str, list[str]] = {
    "monkey-early": ["monkey_seed_", "m2_", "m3_", "m4_", "m45_", "m5_", "m6_", "mouse_click"],
    "monkey-m7": ["m7_"],
    "monkey-m8": ["m8_"],
    "monkey-fog": ["fog_"],
    "monkey-tile": ["tile_"],
    "monkey-moves": ["moves_"],
}
GROUPS = ["core", "shell", *MONKEY_GROUPS]

MAX_ASSERTS_PER_TEST = 400_000
MAX_ASSERTS_PER_PROCESS = 1_500_000  # about 1.8 GB of kept assert text
MAX_PEAK_MB = 6_000                  # Linux only; the GitHub runner has 16 GB
TIMEOUT_MINUTES = 40                 # per process

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def test_files(project: Path) -> list[str]:
    """Every test file of the project, as res:// paths."""
    return sorted("res://" + p.relative_to(project).as_posix() for p in (project / "tests").rglob("test_*.gd"))


def group_files(project: Path, group: str) -> list[str]:
    """The files of the "core" or "shell" group: core is tests/core, shell is everything else but the random play."""
    monkey = "res://" + MONKEY_FILE
    core = [f for f in test_files(project) if f.startswith("res://tests/core/")]
    if group == "core":
        return core
    return [f for f in test_files(project) if f not in core and f != monkey]


def monkey_tests(project: Path) -> list[str]:
    text = (project / MONKEY_FILE).read_text(encoding="utf-8")
    return re.findall(r"^func (test_\w+)", text, re.MULTILINE)


def group_problems(names: list[str], groups: dict[str, list[str]] = MONKEY_GROUPS) -> list[str]:
    """What is wrong with the random-play groups: a test in no filter or in several, or a filter that finds nothing."""
    filters = [f for group in groups.values() for f in group]
    problems = []
    for name in names:
        matched = [f for f in filters if f in name]
        if len(matched) != 1:
            problems.append(f"{name} matches {len(matched)} filters {matched}: it must match exactly one")
    problems += [f'the filter "{f}" matches no test' for f in filters if not any(f in n for n in names)]
    return problems


def read_allowed(path: Path) -> set[tuple[str, str]]:
    """The tests that may be pending: lines of "<script> <test name>"; # starts a comment line."""
    allowed = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if parts and not parts[0].startswith("#"):
            allowed.add((parts[0], parts[1]))
    return allowed


def parse_log(text: str) -> dict:
    """What GUT printed: the scripts it ran, the pending tests of its summary, and the totals (None when absent)."""
    scripts: set[str] = set()
    pending: set[tuple[str, str]] = set()
    totals: dict[str, int] = {}
    script = test = ""
    for raw in text.splitlines():
        line = ANSI.sub("", raw).rstrip()
        if line.startswith("res://"):
            script, test = line.strip(), ""
            scripts.add(script.split(".gd")[0] + ".gd")
        elif line.startswith("- test_"):
            test = line[2:].strip()
        elif line.startswith("* test_"):
            test = ""  # the run section; only the summary's "- test" lines are counted
        elif "[Pending]" in line and test:
            pending.add((script, test))
        else:
            # With failures GUT prints the asserts as "passed/all": the last number is the count.
            found = re.match(r"(Scripts|Tests|Passing Tests|Failing Tests|Risky/Pending|Asserts)\s+(?:\d+/)?(\d+)$", line)
            if found:
                totals[found.group(1)] = int(found.group(2))
    return {"scripts": scripts, "pending": pending, "totals": totals}


def judge(text: str, status: int | None, junit: Path, expect_files: list[str], expect_tests: int | None,
          allowed: set[tuple[str, str]]) -> list[str]:
    """Why one process's run does not count as a pass; empty when it does. `status` None means it timed out."""
    problems = []
    if status is None:
        problems.append("timed out")
    elif status != 0:
        problems.append(f"GUT exited with {status}")
    plain = ANSI.sub("", text)
    if "SCRIPT ERROR" in plain:
        problems.append("the output has a SCRIPT ERROR")
    if "Ignoring script" in plain:
        problems.append("GUT ignored a script (it does not extend GutTest, or did not load)")
    log = parse_log(text)
    totals = log["totals"]
    if "Tests" not in totals:
        problems.append("GUT printed no totals: the run did not finish")
        return problems
    missing = [f for f in expect_files if f not in log["scripts"]]
    if missing:
        problems.append(f"{len(missing)} test file(s) did not run: {', '.join(missing[:8])}")
    if expect_tests is not None and totals["Tests"] != expect_tests:
        problems.append(f"ran {totals['Tests']} tests, expected {expect_tests}")
    unlisted = sorted(log["pending"] - allowed)
    if unlisted:
        problems.append("pending and not in tests/pending_allowed.txt: "
                        + "; ".join(f"{s} {t}" for s, t in unlisted[:8]))
    if totals.get("Risky/Pending", 0) > len(log["pending"]):
        problems.append(f"{totals['Risky/Pending']} tests are risky or pending but only {len(log['pending'])} say why: "
                        "a test with no assert?")
    if totals.get("Asserts", 0) > MAX_ASSERTS_PER_PROCESS:
        problems.append(f"{totals['Asserts']} asserts in one process (limit {MAX_ASSERTS_PER_PROCESS}): "
                        "an assert inside a loop, or the group needs splitting")
    try:
        cases = ET.parse(junit).getroot().iter("testcase")
        for case in cases:
            count = int(case.get("assertions", "0"))
            if count > MAX_ASSERTS_PER_TEST:
                problems.append(f"{case.get('classname')} {case.get('name')} made {count} asserts "
                                f"(limit {MAX_ASSERTS_PER_TEST}): assert once, not inside a loop")
    except (OSError, ET.ParseError) as error:
        problems.append(f"no readable JUnit report: {error}")
    return problems


def _peak_mb(pid: int) -> int:
    """The process's peak memory so far, from /proc (0 where there is none)."""
    try:
        status = Path(f"/proc/{pid}/status").read_text()
    except OSError:
        return 0
    found = re.search(r"VmHWM:\s+(\d+) kB", status)
    return int(found.group(1)) // 1024 if found else 0


def _kill_tree(process: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(process.pid)], capture_output=True, check=False)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def run_process(command: list[str], log: Path, timeout_s: float) -> tuple[str, int | None, int]:
    """Runs the command, echoing and saving its output. Returns the output, the exit code (None: timed out) and the
    peak memory in MB (0 when unknown)."""
    lines: list[str] = []
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=REPO_ROOT,
                               start_new_session=os.name != "nt")

    def pump() -> None:
        with log.open("wb") as file:
            for chunk in process.stdout:
                file.write(chunk)
                file.flush()
                sys.stdout.buffer.write(chunk)
                sys.stdout.flush()
                lines.append(chunk.decode("utf-8", "replace"))

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()
    started, peak, status = time.monotonic(), 0, None
    try:
        while status is None and time.monotonic() - started < timeout_s:
            peak = max(peak, _peak_mb(process.pid))
            try:
                status = process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                pass
    finally:
        if process.poll() is None:
            _kill_tree(process)
            process.wait()
    reader.join(timeout=30)
    return "".join(lines), status, peak


class Lock:
    """One test run at a time on this machine. The system drops the lock when the process ends, however it ends."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.file = None

    def __enter__(self) -> "Lock":
        self.file = self.path.open("a+b")
        try:
            if os.name == "nt":
                import msvcrt
                self.file.seek(0)
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.file.close()
            raise SystemExit(f"run_gut: another test run holds {self.path}: wait for it to finish") from None
        return self

    def __exit__(self, *exc: object) -> None:
        self.file.close()


def run_group(group: str, godot: str, project: Path, out: Path, timeout_s: float,
              allowed: set[tuple[str, str]]) -> list[dict]:
    """One group's processes; a result per process."""
    base = [godot, "--headless", "--path", str(project), "-s", "res://addons/gut/gut_cmdln.gd"]
    if group in MONKEY_GROUPS:
        names = monkey_tests(project)
        runs = [(f"{group}.{part.strip('_')}", [f"-gtest=res://{MONKEY_FILE}", f"-gunit_test_name={part}"],
                 ["res://" + MONKEY_FILE], sum(part in n for n in names)) for part in MONKEY_GROUPS[group]]
    else:
        files = group_files(project, group)
        runs = [(group, ["-gtest=" + ",".join(files)], files, None)]
    results = []
    for name, options, files, count in runs:
        junit = out / f"gut-junit-{name}.xml"
        junit.unlink(missing_ok=True)
        print(f"run_gut: {name}", flush=True)
        started = time.monotonic()
        text, status, peak = run_process(base + options + ["-gexit", f"-gjunit_xml_file={junit}"],
                                         out / f"gut-{name}.log", timeout_s)
        problems = judge(text, status, junit, files, count, allowed)
        if peak > MAX_PEAK_MB:
            problems.append(f"peak memory {peak} MB (limit {MAX_PEAK_MB})")
        totals = parse_log(text)["totals"]
        results.append({"name": name, "problems": problems, "tests": totals.get("Tests", 0),
                        "asserts": totals.get("Asserts", 0), "peak_mb": peak,
                        "minutes": (time.monotonic() - started) / 60})
    return results


def report(results: list[dict]) -> str:
    rows = ["| run | tests | asserts | peak MB | minutes | verdict |", "|---|---|---|---|---|---|"]
    for r in results:
        rows.append(f"| {r['name']} | {r['tests']} | {r['asserts']} | {r['peak_mb'] or '-'} | {r['minutes']:.1f} | "
                    f"{'FAIL' if r['problems'] else 'ok'} |")
    return "\n".join(rows)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("groups", nargs="*", help="which groups to run (default: all)")
    parser.add_argument("--godot", default=os.environ.get("GODOT", ""), help="the engine (default: $GODOT)")
    parser.add_argument("--project", type=Path, default=REPO_ROOT / "godot")
    parser.add_argument("--out", type=Path, default=Path(tempfile.gettempdir()) / "hexa-gut",
                        help="where the logs and JUnit reports go")
    parser.add_argument("--timeout-minutes", type=float, default=TIMEOUT_MINUTES, help="per process")
    parser.add_argument("--list", action="store_true", help="print the group names as JSON and stop")
    args = parser.parse_args(argv)
    if args.list:
        print(json.dumps(GROUPS))
        return 0
    unknown = [g for g in args.groups if g not in GROUPS]
    if unknown:
        parser.error(f"unknown group(s) {', '.join(unknown)}; the groups are {', '.join(GROUPS)}")
    if not args.godot:
        parser.error("give --godot or set GODOT")
    project = args.project.resolve()
    out = args.out.resolve()
    problems = group_problems(monkey_tests(project))
    if problems:
        print("run_gut: the random-play groups are wrong (MONKEY_GROUPS in tools/run_gut.py):\n  "
              + "\n  ".join(problems))
        return 1
    out.mkdir(parents=True, exist_ok=True)
    allowed = read_allowed(project / "tests" / "pending_allowed.txt")
    results = []
    with Lock(Path(tempfile.gettempdir()) / "hexa-gut.lock"):
        for group in args.groups or GROUPS:
            results += run_group(group, args.godot, project, out, args.timeout_minutes * 60, allowed)
    table = report(results)
    print(f"\n{table}\n")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
            summary.write(table + "\n")
    failed = [r for r in results if r["problems"]]
    for r in failed:
        for problem in r["problems"]:
            print(f"::error::{r['name']}: {problem}" if os.environ.get("GITHUB_ACTIONS")
                  else f"FAIL {r['name']}: {problem}")
    print("run_gut: FAILED" if failed else "run_gut: all passed", f"(logs in {out})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
