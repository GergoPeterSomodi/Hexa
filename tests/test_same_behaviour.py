"""The behaviour oracle (tools/same_behaviour.py) end to end, on short runs (--quick). No pygame needed.

    identical copies   two temporary copies of hexa/ play the same games (exit 0)
    planted changes    each is made in a copy of hexa/ and must be caught (exit 1, naming the suite and the step):
                         a hill's defence 2 -> 3                  Conquest
                         the generated road_paths lose one road   the static map section of the campaign digest
                         the creditors' order of seizure reversed the prepared debt state
    crashes            a copy whose code raises is reported as ORACLE FAILED, not as a changed behaviour
    usage errors       a folder without hexa/, the checkout itself, an unknown --only: exit 2, nothing played

The runs go in parallel, in a few seconds in all.
"""
import concurrent.futures
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "same_behaviour.py")

ROAD_PATHS = '''

# Added by tests/test_same_behaviour.py: one generated road is missing.
_plant_init = CampaignWorld.__init__


def _init_without_a_road(self, *args, **kwargs):
    _plant_init(self, *args, **kwargs)
    self.road_paths = self.road_paths[:-1]


CampaignWorld.__init__ = _init_without_a_road
'''

CRASH = '''

# Added by tests/test_same_behaviour.py: the world cannot be built.
def _no_world(self, *args, **kwargs):
    raise RuntimeError("planted crash")


CampaignWorld.__init__ = _no_world
'''


def oracle(*args):
    done = subprocess.run([sys.executable, TOOL, *args], capture_output=True, text=True, timeout=300)
    return done.returncode, done.stdout + done.stderr


def plant(tmp, name, path, old, new, append=""):
    """A copy of hexa/ in tmp/name with one snippet of `path` (relative to hexa/) replaced, or text appended."""
    folder = os.path.join(tmp, name)
    shutil.copytree(os.path.join(ROOT, "hexa"), os.path.join(folder, "hexa"),
                    ignore=shutil.ignore_patterns("__pycache__"))
    target = os.path.join(folder, "hexa", path)
    with open(target, newline="") as f:
        text = f.read()
    if old:
        assert text.count(old) == 1, f"the planted change no longer applies to {path}: pick another snippet"
        text = text.replace(old, new)
    with open(target, "w", newline="") as f:
        f.write(text + append.replace("\n", "\r\n" if "\r\n" in text else "\n"))
    return folder


class SameBehaviourTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="hexa-same-test-")
        cls.addClassCleanup(shutil.rmtree, cls.tmp, True)
        keep = shutil.ignore_patterns("__pycache__")
        same = os.path.join(cls.tmp, "same")
        shutil.copytree(os.path.join(ROOT, "hexa"), os.path.join(same, "hexa"), ignore=keep)
        hills = '"Hills", ("Terrain/Grass/grass_15.png",), 2, 2'
        seize = 'rank = (-saving, prov.pos, kind, key or "")'
        runs = {
            "same": (same, "--only", "conquest", "--only", "campaign europe", "--only", "debt"),
            "hills": (plant(cls.tmp, "hills", "rules.py", hills, hills[:-1] + "3"), "--only", "conquest"),
            "roads": (plant(cls.tmp, "roads", os.path.join("campaign", "world.py"), "", "", ROAD_PATHS),
                      "--only", "campaign europe"),
            "seize": (plant(cls.tmp, "seize", os.path.join("campaign", "systems", "debt.py"), seize,
                            seize.replace("(-saving", "(saving")), "--only", "debt"),
            "crash": (plant(cls.tmp, "crash", os.path.join("campaign", "world.py"), "", "", CRASH),
                      "--only", "campaign europe"),
        }
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(runs)) as pool:
            futures = {k: pool.submit(oracle, args[0], "--quick", *args[1:]) for k, args in runs.items()}
            cls.out = {k: f.result() for k, f in futures.items()}

    def test_identical_copies_pass(self):
        code, out = self.out["same"]
        self.assertEqual(code, 0, out)
        self.assertIn("Same behaviour", out)

    def test_planted_rule_change_is_caught(self):
        code, out = self.out["hills"]
        self.assertEqual(code, 1, out)
        self.assertIn("BEHAVIOUR CHANGED", out)
        self.assertIn("conquest 3: differs at step", out)

    def test_planted_road_change_is_caught_by_the_static_map_digest(self):
        code, out = self.out["roads"]
        self.assertEqual(code, 1, out)
        self.assertIn("BEHAVIOUR CHANGED", out)
        self.assertIn("campaign europe 1480: differs at step 0", out)

    def test_planted_change_in_the_debt_state_is_caught(self):
        code, out = self.out["seize"]
        self.assertEqual(code, 1, out)
        self.assertIn("BEHAVIOUR CHANGED", out)
        self.assertIn("debt: differs at step", out)

    def test_a_crash_is_not_a_changed_behaviour(self):
        code, out = self.out["crash"]
        self.assertEqual(code, 1, out)
        self.assertIn("ORACLE FAILED", out)
        self.assertNotIn("BEHAVIOUR CHANGED", out)
        self.assertIn("planted crash", out)

    def test_usage_errors_exit_cleanly(self):
        empty = os.path.join(self.tmp, "empty")
        os.makedirs(empty, exist_ok=True)
        for args in ([], [empty], [ROOT], [os.path.join(self.tmp, "same"), "--only", "no such suite"]):
            code, out = oracle(*args)
            self.assertEqual(code, 2, f"{args}: {out}")
            self.assertNotIn("Traceback", out)


if __name__ == "__main__":
    unittest.main()
