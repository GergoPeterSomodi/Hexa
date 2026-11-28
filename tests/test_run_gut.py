"""The GUT runner's guards (tools/run_gut.py): what may not count as a pass. No engine needed."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

from tools import run_gut  # noqa: E402

FILE = "res://tests/core/test_a.gd"
CLEAN = f"""{FILE}
* test_one
* test_later
    [Pending]:  not yet

{FILE}
- test_later
    [Pending]:  not yet

Totals
------
Scripts               1
Tests                 2
Passing Tests         1
Risky/Pending         1
Asserts              10
"""
ALLOWED = {(FILE, "test_later")}
JUNIT = ('<testsuites><testsuite name="a"><testcase name="test_one" assertions="{}" classname="tests/core/test_a.gd">'
         "</testcase></testsuite></testsuites>")


class JudgeTest(unittest.TestCase):
    def setUp(self) -> None:
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.junit = Path(folder.name) / "junit.xml"
        self.junit.write_text(JUNIT.format(10), encoding="utf-8")

    def judge(self, text: str = CLEAN, status: int | None = 0, files: tuple = (FILE,), count: int | None = None,
              allowed: set = ALLOWED) -> str:
        return " | ".join(run_gut.judge(text, status, self.junit, list(files), count, allowed))

    def test_a_clean_run_passes(self) -> None:
        self.assertEqual(self.judge(), "")

    def test_colour_codes_do_not_hide_anything(self) -> None:
        coloured = CLEAN.replace("res://", "\x1b[4m\nres://").replace("[Pending]", "\x1b[33m[Pending]\x1b[0m")
        self.assertEqual(self.judge(coloured), "")

    def test_exit_code_and_timeout(self) -> None:
        self.assertIn("exited with 1", self.judge(status=1))
        self.assertIn("timed out", self.judge(status=None))

    def test_a_script_error_fails_even_with_exit_0(self) -> None:
        self.assertIn("SCRIPT ERROR", self.judge("SCRIPT ERROR: Parse Error: x\n" + CLEAN))

    def test_an_ignored_script_fails(self) -> None:
        warned = "[GUT WARNING]:  Ignoring script res://tests/core/test_b.gd because it does not extend GutTest\n"
        self.assertIn("ignored a script", self.judge(warned + CLEAN))

    def test_a_file_that_did_not_run_fails(self) -> None:
        self.assertIn("test_b.gd", self.judge(files=(FILE, "res://tests/core/test_b.gd")))

    def test_an_inner_class_counts_for_its_file(self) -> None:
        self.assertEqual(self.judge(CLEAN.replace(FILE, FILE + ".TestInner"),
                                    allowed={(FILE + ".TestInner", "test_later")}), "")

    def test_no_totals_fails(self) -> None:
        self.assertIn("did not finish", self.judge(CLEAN.split("Totals")[0]))

    def test_a_wrong_test_count_fails(self) -> None:
        self.assertIn("expected 3", self.judge(count=3))

    def test_an_unlisted_pending_test_fails(self) -> None:
        self.assertIn("test_later", self.judge(allowed=set()))

    def test_a_risky_test_fails(self) -> None:
        self.assertIn("no assert", self.judge(CLEAN.replace("Risky/Pending         1", "Risky/Pending         2")))

    def test_too_many_asserts_in_the_process_fails(self) -> None:
        many = CLEAN.replace("Asserts              10", f"Asserts {run_gut.MAX_ASSERTS_PER_PROCESS + 1}")
        self.assertIn("in one process", self.judge(many))

    def test_too_many_asserts_in_one_test_fails(self) -> None:
        self.junit.write_text(JUNIT.format(run_gut.MAX_ASSERTS_PER_TEST + 1), encoding="utf-8")
        self.assertIn("test_one made", self.judge())

    def test_the_assert_count_is_read_when_tests_failed(self) -> None:
        many = CLEAN.replace("Asserts              10", f"Asserts {run_gut.MAX_ASSERTS_PER_PROCESS}/{run_gut.MAX_ASSERTS_PER_PROCESS + 1}")
        self.assertIn("in one process", self.judge(many, status=1))

    def test_a_missing_junit_report_fails(self) -> None:
        self.junit.unlink()
        self.assertIn("JUnit", self.judge())


class GroupTest(unittest.TestCase):
    def test_every_random_play_test_is_in_exactly_one_group(self) -> None:
        names = run_gut.monkey_tests(REPO / "godot")
        self.assertGreater(len(names), 30)
        self.assertEqual(run_gut.group_problems(names), [])

    def test_a_new_tier_without_a_group_is_refused(self) -> None:
        names = run_gut.monkey_tests(REPO / "godot") + ["test_ui_monkey_siege_seed_1600"]
        self.assertIn("matches 0 filters", " ".join(run_gut.group_problems(names)))

    def test_a_test_in_two_groups_and_an_empty_filter_are_refused(self) -> None:
        found = " ".join(run_gut.group_problems(["test_ab"], {"one": ["a", "zz"], "two": ["b"]}))
        self.assertIn("matches 2 filters", found)
        self.assertIn('"zz" matches no test', found)

    def test_core_shell_and_random_play_hold_every_test_file_once(self) -> None:
        project = REPO / "godot"
        parts = run_gut.group_files(project, "core") + run_gut.group_files(project, "shell")
        parts.append("res://" + run_gut.MONKEY_FILE)
        self.assertEqual(sorted(parts), run_gut.test_files(project))

    def test_the_allowed_pending_tests_exist(self) -> None:
        project = REPO / "godot"
        missing = []
        for script, name in run_gut.read_allowed(project / "tests" / "pending_allowed.txt"):
            path = project / script.removeprefix("res://").split(".gd")[0]
            source = path.with_suffix(".gd")
            if not source.is_file() or f"func {name}(" not in source.read_text(encoding="utf-8"):
                missing.append(f"{script} {name}")
        self.assertEqual(missing, [])


if __name__ == "__main__":
    unittest.main()
