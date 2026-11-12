"""The perf tool (tools/perf.py) and its budget file, tests/perf_budget.json.

Nothing here times anything: the metrics are replaced by fakes. Real timings are taken only by python -m tools.perf
in the nightly workflow, never by the unit suite. No pygame needed.
"""
import json
import os
import tempfile
import unittest
from unittest import mock

from tests.support.pg import HAVE_PYGAME
from tools import perf


def fake(seconds, doc="A fake metric."):
    def metric():
        return seconds
    metric.__doc__ = doc
    return metric


def needs_pygame():
    """A fake metric that can't run here."""
    raise perf.Skip("pygame is not installed; use a venv")


class BudgetFileTest(unittest.TestCase):
    def test_every_metric_has_a_soft_and_a_hard_limit(self):
        budget = perf.load_budget()
        self.assertEqual(sorted(budget), sorted(perf.METRICS), "a budget for every metric and nothing else")
        for name, limits in budget.items():
            with self.subTest(metric=name):
                self.assertLess(0, limits["soft"])
                self.assertLess(limits["soft"], limits["hard"])

    def test_the_file_says_what_was_measured(self):
        with open(perf.BUDGET_FILE, encoding="utf-8") as f:
            data = json.load(f)
        self.assertIn("_comment", data)
        for name in data["metrics"]:
            with self.subTest(metric=name):
                self.assertIn("measured", data["metrics"][name])


class JudgeTest(unittest.TestCase):
    def test_soft_and_hard_limits(self):
        limits = {"soft": 2.0, "hard": 4.0}
        self.assertEqual(perf.judge(1.0, limits), "ok")
        self.assertEqual(perf.judge(2.0, limits), "ok")
        self.assertEqual(perf.judge(3.0, limits), "over soft")
        self.assertEqual(perf.judge(4.5, limits), "OVER HARD")
        self.assertEqual(perf.judge(9.0, None), "no budget")

    def test_the_median_counts(self):
        result = perf.Result("x", [9.0, 1.0, 1.5], {"soft": 2.0, "hard": 4.0})
        self.assertEqual(result.median, 1.5)
        self.assertEqual(result.status, "ok")
        self.assertFalse(result.failed)


class CommandTest(unittest.TestCase):
    BUDGET = {"_comment": "test", "metrics": {"fast": {"soft": 1.0, "hard": 2.0, "measured": 0.5},
                                              "slow": {"soft": 1.0, "hard": 2.0, "measured": 0.5},
                                              "drawn": {"soft": 1.0, "hard": 2.0, "measured": 0.5}}}

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        folder = temp.name
        self.budget_file = os.path.join(folder, "budget.json")
        with open(self.budget_file, "w", encoding="utf-8") as f:
            json.dump(self.BUDGET, f)
        self.summary_file = os.path.join(folder, "summary.md")
        for patcher in (mock.patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": self.summary_file}),
                        mock.patch.object(perf, "cache_memory", side_effect=AssertionError("no memory check here"))):
            patcher.start()
            self.addCleanup(patcher.stop)
        os.environ.pop(perf.REQUIRE_VAR, None)          # restored with the rest of os.environ

    def main(self, metrics, *argv):
        lines = []
        with mock.patch.dict(perf.METRICS, metrics, clear=True), \
                mock.patch.object(perf, "PYGAME_METRICS", ("drawn",)):
            status = perf.main(["--budget", self.budget_file, "--no-memory", *argv], out=lines.append)
        return status, "\n".join(lines)

    def summary(self):
        with open(self.summary_file, encoding="utf-8") as f:
            return f.read()

    def test_within_budget(self):
        status, text = self.main({"fast": fake(0.5)})
        self.assertEqual(status, 0, text)
        self.assertIn("fast: 0.500 s (0.500, 0.500, 0.500) ok", text)
        self.assertIn("| `fast` | 0.500 | 0.500, 0.500, 0.500 | 1 | 2 | ok | A fake metric. |", self.summary())

    def test_over_the_soft_limit_is_noted_but_passes(self):
        status, text = self.main({"fast": fake(0.5), "slow": fake(1.5)})
        self.assertEqual(status, 0, text)
        self.assertIn("over soft", text)
        self.assertIn("| `slow` | 1.500 |", self.summary())
        self.assertIn("over soft limit", self.summary())

    def test_over_the_hard_limit_fails_with_a_replay_line(self):
        status, text = self.main({"fast": fake(0.5), "slow": fake(2.5)})
        self.assertEqual(status, 1)
        self.assertIn("FAILED: slow took 2.500 s, over its hard limit of 2 s. "
                      "Replay: python -m tools.perf --only slow", text)
        self.assertIn("**OVER HARD LIMIT**", self.summary())

    def test_the_runs_option(self):
        status, text = self.main({"fast": fake(0.5)}, "--runs", "5")
        self.assertIn("(0.500, 0.500, 0.500, 0.500, 0.500)", text)
        self.assertIn("median of 5 runs", self.summary())

    def test_a_metric_that_needs_pygame_is_skipped_without_it(self):
        status, text = self.main({"fast": fake(0.5), "drawn": needs_pygame})
        self.assertEqual(status, 0, text)
        self.assertIn("drawn: skipped: pygame is not installed; use a venv", text)
        self.assertIn("| `drawn` | - | - | 1 | 2 | skipped: pygame is not installed |", self.summary())

    def test_unless_pygame_is_required(self):
        with mock.patch.dict(os.environ, {perf.REQUIRE_VAR: "1"}), self.assertRaises(SystemExit) as done:
            self.main({"drawn": needs_pygame})
        self.assertIn("HEXA_REQUIRE_PYGAME=1 makes this an error", str(done.exception.code))

    def test_only_and_list(self):
        status, text = self.main({"fast": fake(0.5), "slow": fake(9.0)}, "--only", "fast")
        self.assertEqual(status, 0, text)
        self.assertNotIn("slow", text)
        status, text = self.main({"fast": fake(0.5)}, "--list")
        self.assertEqual((status, text), (0, "fast: soft 1 s, hard 2 s - A fake metric."))
        with mock.patch("sys.stderr"), self.assertRaises(SystemExit):
            self.main({"fast": fake(0.5)}, "--only", "nothing")

    def test_the_memory_row_is_information_only(self):
        with mock.patch.object(perf, "cache_memory", return_value=([12.1e6, 24.3e6, 24.5e6], (3, 2))):
            lines = []
            with mock.patch.dict(perf.METRICS, {"fast": fake(0.5)}, clear=True):
                status = perf.main(["--budget", self.budget_file], out=lines.append)
        self.assertEqual(status, 0)
        self.assertIn("world caches (#29, information only): 12.1, 24.3, 24.5 MB", "\n".join(lines))
        self.assertIn("| `world_cache_memory` (#29) | +0.2 MB | 12.1, 24.3, 24.5 MB | - | - | info |", self.summary())


class MapViewTest(unittest.TestCase):
    @unittest.skipIf(HAVE_PYGAME, "pygame is installed (the metric would draw)")
    @mock.patch.dict(os.environ)
    def test_the_mapview_metrics_skip_cleanly_without_pygame(self):
        for metric in (perf.mapview_zoom1, perf.mapview_zoom4):
            with self.subTest(metric=metric.__name__), self.assertRaises(perf.Skip) as skipped:
                metric()
            self.assertIn("pygame is not installed", str(skipped.exception))


if __name__ == "__main__":
    unittest.main()
