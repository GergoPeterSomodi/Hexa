"""The save-compatibility tool (tools/save_compat.py) end to end, without git history. No pygame needed.

In CI the merge base writes the saves and the pull request loads them. Here this checkout writes them once, then
check loads them with this checkout and with temporary copies of hexa/, each changed the way a pull request could:

    bumped-renamed   saves.VERSION + 1, and the Province class renamed, so old saves can't be unpickled:
                     they must be refused quietly (exit 0)
    new-attribute    end_round reads a new world attribute that old saves lack, VERSION unchanged: exit 1,
                     naming the attribute and the save
    bumped           saves.VERSION + 1 only: saves.load still reads older versions, so they must play on (exit 0)

Every command runs in its own interpreter, as in CI, and the checks run in parallel (about 10 seconds in all).
"""
import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

import hexa
from hexa.campaign import saves
from tools import save_compat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "save_compat.py")
TIMEOUT = 300

# Appended to the copied world.py: a new attribute that new worlds would get in __init__, missing from WORLD_DEFAULTS.
NEW_ATTRIBUTE = '''

# Added by tests/test_save_compat.py: end_round reads a new world attribute that saves made before it lack.
def _plague_round(end_round):
    def end_round_with_plague(self):
        self.plague_years += 1
        return end_round(self)
    return end_round_with_plague


CampaignWorld.end_round = _plague_round(CampaignWorld.end_round)
'''


def _copy_hexa(tree):
    """A temporary 'pull request': a tree with a copy of this checkout's hexa package."""
    shutil.copytree(os.path.join(ROOT, "hexa"), os.path.join(tree, "hexa"),
                    ignore=shutil.ignore_patterns("__pycache__"))
    return tree


def _edit(tree, module, change):
    path = os.path.join(tree, "hexa", "campaign", module)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    new = change(text)
    if new == text:
        raise AssertionError(f"tests/test_save_compat.py: its change to hexa/campaign/{module} no longer applies")
    with open(path, "w", encoding="utf-8") as f:
        f.write(new)


def _bump(tree):
    _edit(tree, "saves.py", lambda text: re.sub(r"^VERSION = (\d+)", lambda m: f"VERSION = {int(m.group(1)) + 1}",
                                                 text, count=1, flags=re.M))


def _rename_province(tree):
    _edit(tree, "world.py", lambda text: re.sub(r"\bProvince\b", "Territory", text))


def _new_attribute(tree):
    _edit(tree, "world.py", lambda text: text + NEW_ATTRIBUTE)


def _env(home, summary=None):
    env = {k: v for k, v in os.environ.items() if k not in ("GITHUB_STEP_SUMMARY", "PYTHONPATH")}
    env["HEXA_HOME"] = home
    if summary:
        env["GITHUB_STEP_SUMMARY"] = summary
    return env


def _start(args, env, cwd):
    return subprocess.Popen([sys.executable, TOOL] + list(args), cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)


class Run:
    def __init__(self, process):
        self.out, self.err = process.communicate(timeout=TIMEOUT)
        self.status = process.returncode

    def __str__(self):
        return f"exit status {self.status}\n--- stdout:\n{self.out}\n--- stderr:\n{self.err}"


class SaveCompatTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        tmp = cls.tmp
        home = os.path.join(tmp, "home")
        os.makedirs(home)
        cls.out = os.path.join(tmp, "compat")
        cls.summary = os.path.join(tmp, "summary.md")
        # A checkout whose hexa has no campaign saves: write must import hexa from there (and then fail).
        stub = os.path.join(tmp, "stub")
        os.makedirs(os.path.join(stub, "hexa"))
        with open(os.path.join(stub, "hexa", "__init__.py"), "w", encoding="utf-8") as f:
            f.write('"""Not the real hexa."""\n')
        stub_run = _start(["write", stub, os.path.join(tmp, "stub-out")], _env(home), tmp)
        cls.write = Run(_start(["write", ROOT, cls.out], _env(home), tmp))
        cls.stub = Run(stub_run)
        if cls.write.status != 0:
            raise AssertionError(f"write failed:\n{cls.write}")
        trees = {"bumped-renamed": (_bump, _rename_province), "new-attribute": (_new_attribute,), "bumped": (_bump,)}
        cls.trees = {}
        for name, changes in trees.items():
            tree = _copy_hexa(os.path.join(tmp, name))
            for change in changes:
                change(tree)
            cls.trees[name] = tree
        started = {"same": _start(["check", cls.out], _env(home, cls.summary), tmp)}
        for name, tree in cls.trees.items():
            started[name] = _start(["check", cls.out, "--checkout", tree], _env(home), tmp)
        cls.checks = {name: Run(process) for name, process in started.items()}

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_write_uses_the_given_checkout_and_makes_three_real_saves(self):
        self.assertIn(f"write: hexa from {os.path.realpath(hexa.__file__)}", self.write.out)
        with open(os.path.join(self.out, "manifest.json"), encoding="utf-8") as f:
            manifest = json.load(f)
        self.assertEqual(manifest["version"], saves.VERSION)
        self.assertEqual(os.path.realpath(manifest["hexa"]), os.path.realpath(hexa.__file__))
        self.assertEqual([e["slot"] for e in manifest["saves"]], ["1", "2", "quick"])
        europe, random_world, war = manifest["saves"]
        self.assertEqual((europe["map"], europe["tag"], europe["turn"]), ("europe", "POR", 4), "3 seasons from turn 1")
        self.assertEqual((random_world["map"], random_world["seed"], random_world["turn"]), ("random", 7, 3))
        self.assertTrue(war["at_war"], "the quicksave is made during the war")
        for entry in manifest["saves"]:
            with open(os.path.join(self.out, entry["file"]), "rb") as f:
                header = json.loads(f.readline())
            self.assertEqual(header["version"], saves.VERSION, "a header written by the game's own saves.save")
            self.assertEqual(header["slot"], entry["slot"])

    def test_write_imports_hexa_from_the_checkout_not_from_the_tools_tree(self):
        stub = os.path.realpath(os.path.join(self.tmp, "stub", "hexa", "__init__.py"))
        self.assertIn(f"write: hexa from {stub}", self.stub.out, self.stub)
        self.assertEqual(self.stub.status, save_compat.WRITE_FAILED, self.stub)
        self.assertIn("FAILED while importing the checkout's hexa.campaign", self.stub.out)
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "stub-out", "manifest.json")))

    def test_the_same_code_loads_every_save_and_plays_a_season(self):
        run = self.checks["same"]
        self.assertEqual(run.status, 0, run)
        self.assertIn("check: 3 of 3 saves compatible", run.out)
        self.assertEqual(run.out.count(": ok: loaded "), 3, run)
        self.assertIn(os.path.join("tests", "support", "invariants.py"), run.out, "the invariants are checked")
        with open(self.summary, encoding="utf-8") as f:
            summary = f.read()
        self.assertIn("## Save compatibility", summary)
        self.assertIn("**compatible**", summary)
        self.assertIn("| `saves/quick.sav` |", summary)

    def test_a_version_bump_refuses_saves_it_cant_read_quietly(self):
        run = self.checks["bumped-renamed"]
        self.assertEqual(run.status, 0, run)
        self.assertIn(f"this code has VERSION {saves.VERSION + 1} (changed", run.out)
        self.assertEqual(run.out.count(": ok: refused quietly: Could not load save "), 3, run)
        # The unpickling error's wording depends on the Python version; it names the class either way.
        self.assertEqual(run.out.count("Could not load save "), run.out.count("AttributeError"), run)
        self.assertIn("'Province'", run.out)
        self.assertNotIn("Traceback", run.out + run.err)
        self.assertIn("world invariants not checked", run.out, "a tree without tests/ still works")

    def test_an_incompatible_change_without_a_bump_fails_and_says_why(self):
        run = self.checks["new-attribute"]
        self.assertEqual(run.status, save_compat.BROKEN, run)
        self.assertIn("check: 0 of 3 saves compatible", run.out)
        failed = [line for line in run.out.splitlines() if ": FAILED: " in line]
        self.assertEqual(len(failed), 3, run)
        self.assertTrue(failed[0].startswith("check: saves/1.sav (Europe 1480 as POR"), failed[0])
        self.assertIn("then playing a season raised AttributeError: 'CampaignWorld' object has no attribute "
                      "'plague_years' (at hexa/campaign/world.py:", failed[0])
        self.assertIn("in end_round_with_plague)", failed[0])
        self.assertIn("bump VERSION in hexa/campaign/saves.py", run.out)
        self.assertIn("WORLD_DEFAULTS", run.out)

    def test_a_bump_alone_still_reads_older_saves_and_they_must_play(self):
        run = self.checks["bumped"]
        self.assertEqual(run.status, 0, run)
        self.assertEqual(run.out.count(": ok: still read (older saves are migrated); loaded "), 3, run)


class UsageTest(unittest.TestCase):
    """Usage errors, in this process (no world is built)."""

    def run_tool(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = save_compat.main(list(argv))
        return status, out.getvalue() + err.getvalue()

    def test_check_without_a_manifest_says_to_run_write_first(self):
        with tempfile.TemporaryDirectory() as tmp:
            status, said = self.run_tool("check", tmp)
        self.assertEqual(status, save_compat.USAGE)
        self.assertIn("no manifest.json", said)
        self.assertIn("write <checkout>", said)

    def test_a_manifest_naming_a_missing_save_is_a_usage_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "manifest.json"), "w", encoding="utf-8") as f:
                json.dump({"version": 1, "saves": [{"slot": "1", "file": "saves/1.sav", "what": "x", "turn": 1,
                                                    "tag": "POR"}]}, f)
            status, said = self.run_tool("check", tmp)
        self.assertEqual(status, save_compat.USAGE)
        self.assertIn("saves/1.sav is listed", said)

    def test_write_needs_a_checkout_with_a_hexa_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            status, said = self.run_tool("write", tmp, os.path.join(tmp, "out"))
        self.assertEqual(status, save_compat.USAGE)
        self.assertIn("has no hexa package", said)

    def test_hexa_already_imported_from_elsewhere_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "hexa"))
            open(os.path.join(tmp, "hexa", "__init__.py"), "w").close()
            path = list(sys.path)
            with self.assertRaises(save_compat.Usage) as caught:
                save_compat.import_hexa(tmp)
            self.assertEqual(sys.path, path, "sys.path is left alone")
        self.assertIn("run the tool in a fresh interpreter", str(caught.exception))

    def test_no_command_is_a_usage_error(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            save_compat.main([])
        self.assertEqual(caught.exception.code, save_compat.USAGE)


if __name__ == "__main__":
    unittest.main()
