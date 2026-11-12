"""The shared test helpers in tests/support."""
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from hexa.campaign import ai
from tests.support import monkey, pg, slow, worlds
from tests.support.home import TempHome
from tests.support.worlds import fresh, play_seasons, pristine, random_world

TEST_SEED = 10 ** 6 + 7             # no real test builds this random world
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Runs the CI ui job's command in a Python where "import pygame" fails, whether or not pygame is installed.
UI_SUITE_WITHOUT_PYGAME = ("import sys, unittest; sys.modules['pygame'] = None; "
                           "unittest.main(module=None, argv=['unittest', 'discover', '-s', 'tests/ui', '-t', '.'])")


def _run(case_class):
    result = unittest.TestResult()
    unittest.defaultTestLoader.loadTestsFromTestCase(case_class).run(result)
    return result


def _decorated(env):
    """A test class whose one test is @slow, decorated while HEXA_FAST is set to env (None: unset)."""
    with mock.patch.dict(os.environ):
        os.environ.pop("HEXA_FAST", None)
        if env is not None:
            os.environ["HEXA_FAST"] = env

        class Sample(unittest.TestCase):
            @slow.slow
            def test_it(self):
                pass
    return Sample


class SlowTest(unittest.TestCase):
    def test_hexa_fast_skips_a_slow_test(self):
        result = _run(_decorated("1"))
        self.assertEqual((result.testsRun, len(result.skipped)), (1, 1))

    def test_a_slow_test_runs_when_hexa_fast_is_unset(self):
        result = _run(_decorated(None))
        self.assertEqual((result.testsRun, len(result.skipped)), (1, 0))

    def test_only_the_value_1_turns_fast_mode_on(self):
        for value in ("0", "", "no"):
            self.assertEqual(len(_run(_decorated(value)).skipped), 0, repr(value))

    def test_slow_works_on_a_whole_class(self):
        with mock.patch.dict(os.environ, {"HEXA_FAST": "1"}):
            @slow.slow
            class Sample(unittest.TestCase):
                def test_a(self):
                    pass

                def test_b(self):
                    pass
        self.assertEqual(len(_run(Sample).skipped), 2)


class TempHomeTest(unittest.TestCase):
    def test_hexa_home_is_a_temporary_folder_while_a_test_runs(self):
        seen = {}

        class Inner(TempHome):
            def test_it(self):
                seen["home"] = self.home
                seen["env"] = os.environ.get("HEXA_HOME")
                seen["exists"] = os.path.isdir(self.home)

        with mock.patch.dict(os.environ, {"HEXA_HOME": "/before"}):
            self.assertTrue(_run(Inner).wasSuccessful())
            self.assertEqual(os.environ["HEXA_HOME"], "/before", "restored afterwards")
        self.assertEqual(seen["env"], seen["home"])
        self.assertTrue(seen["exists"])
        self.assertFalse(os.path.exists(seen["home"]), "the folder is removed afterwards")

    def test_an_unset_hexa_home_is_unset_again_afterwards(self):
        class Inner(TempHome):
            def test_it(self):
                self.assertIn("HEXA_HOME", os.environ)

        with mock.patch.dict(os.environ):
            os.environ.pop("HEXA_HOME", None)
            self.assertTrue(_run(Inner).wasSuccessful())
            self.assertNotIn("HEXA_HOME", os.environ)


class WorldsTest(unittest.TestCase):
    def tearDown(self):
        for seed in (TEST_SEED, TEST_SEED + 1):
            worlds._RANDOM.pop(seed, None)

    def test_europe_is_one_shared_world(self):
        self.assertIs(worlds.europe(), worlds.europe())

    def test_fresh_worlds_are_separate_and_playable(self):
        a, b = fresh(), fresh("FRA")
        self.assertIsNot(a, b)
        self.assertIsNot(a, worlds.europe())
        self.assertEqual((a.player, b.player), ("POR", "FRA"))

    def test_random_world_is_built_once_per_seed(self):
        with mock.patch.object(worlds, "CampaignWorld", side_effect=lambda seed, map: object()) as build:
            first = random_world(TEST_SEED)
            self.assertIs(random_world(TEST_SEED), first)
            self.assertEqual(build.call_count, 1)
            self.assertIsNot(random_world(TEST_SEED + 1), first)
            self.assertEqual(build.call_count, 2)
            build.assert_any_call(TEST_SEED, map="random")

    def test_play_seasons_advances_the_turn_counter(self):
        w = fresh()
        start = w.turn
        self.assertIs(play_seasons(w, 3), w)
        self.assertEqual(w.turn, start + 3)

    def test_play_seasons_can_leave_the_player_alone(self):
        w = fresh("POR")
        with mock.patch.object(ai, "run") as run:
            play_seasons(w, 2, player_ai=False)
        self.assertEqual(run.call_count, 2 * (len(w.countries) - 1))
        self.assertNotIn("POR", [call.args[1] for call in run.call_args_list])
        with mock.patch.object(ai, "run") as run:
            play_seasons(w, 1)
        self.assertEqual(run.call_count, len(w.countries))


class PristineTest(unittest.TestCase):
    def test_reading_a_world_does_not_trip_the_guard(self):
        w = fresh()
        guard = pristine(w)
        w.provinces_of("POR")
        w.update_visibility()
        w.find_country("portugal")
        guard.check()

    def test_a_changed_turn_trips_the_guard(self):
        w = fresh()
        guard = pristine(w, "the test world")
        w.turn += 1
        with self.assertRaisesRegex(AssertionError, "the test world was modified.*turn"):
            guard.check()

    def test_a_quiet_change_to_a_province_trips_the_guard(self):
        w = fresh()
        guard = pristine(w)
        prov = next(p for p in w.provinces.values() if p.owner)
        prov.owner = None
        with self.assertRaisesRegex(AssertionError, "game state changed"):
            guard.check()

    def test_a_whole_season_trips_the_guard(self):
        w = fresh()
        guard = pristine(w)
        play_seasons(w, 1)
        with self.assertRaises(AssertionError):
            guard.check()


class RequiresPygameTest(unittest.TestCase):
    """tests/support/pg.py: UI tests skip without pygame, unless HEXA_REQUIRE_PYGAME=1 says they must run."""

    def _run_sample(self, have, require=None):
        """Run a one-test class decorated with @requires_pygame while pygame is (not) there."""
        with mock.patch.object(pg, "HAVE_PYGAME", have), mock.patch.dict(os.environ):
            os.environ.pop(pg.REQUIRE_VAR, None)
            if require is not None:
                os.environ[pg.REQUIRE_VAR] = require

            @pg.requires_pygame
            class Sample(unittest.TestCase):
                def test_it(self):
                    pass
        return _run(Sample)

    def test_have_pygame_says_whether_pygame_can_be_found(self):
        self.assertEqual(pg.HAVE_PYGAME, importlib.util.find_spec("pygame") is not None)

    def test_a_ui_test_runs_when_pygame_is_installed(self):
        result = self._run_sample(True)
        self.assertEqual((result.testsRun, len(result.skipped)), (1, 0))

    def test_a_ui_test_is_skipped_without_pygame_and_says_how_to_force_it(self):
        result = self._run_sample(False)
        self.assertEqual((result.testsRun, len(result.skipped)), (1, 1))
        self.assertIn(pg.REQUIRE_VAR, result.skipped[0][1])

    def test_hexa_require_pygame_1_runs_it_even_without_pygame(self):
        result = self._run_sample(False, "1")
        self.assertEqual((result.testsRun, len(result.skipped)), (1, 0))

    def test_only_the_value_1_requires_pygame(self):
        for value in ("0", "", "yes"):
            self.assertEqual(len(self._run_sample(False, value).skipped), 1, repr(value))


class MonkeyPlanTest(unittest.TestCase):
    """tests/support/monkey.py without pygame: the plan of a session, the environment variables, the report."""

    def test_a_seed_always_gives_the_same_plan(self):
        for mode in monkey.MODES:
            first = monkey.plan(mode, 5, 400, 0.5)
            self.assertEqual(monkey.plan(mode, 5, 400, 0.5).digest(), first.digest(), mode)
            self.assertNotEqual(monkey.plan(mode, 6, 400, 0.5).digest(), first.digest(), mode)
            self.assertNotEqual(monkey.plan(mode, 5, 400, 0.3).digest(), first.digest(), mode)
        self.assertNotEqual(monkey.plan("conquest", 5, 400).frames, monkey.plan("colony", 5, 400).frames)

    def test_a_shorter_session_is_the_start_of_a_longer_one(self):
        for mode in monkey.MODES:
            self.assertEqual(monkey.plan(mode, 9, 100, 0.5).frames, monkey.plan(mode, 9, 3000, 0.5).frames[:99])
        frames = [frame for frame, _ in monkey.plan("colony", 9, 100).frames]
        self.assertEqual(frames, list(range(1, 100)), "an action list for every frame but the last (the QUIT's)")

    def test_burst_is_the_share_of_frames_with_several_actions(self):
        for ratio in (0.0, 0.3, 0.5, 1.0):
            schedule = monkey.plan("conquest", 1, 4001, ratio).frames
            bursts = [actions for _, actions in schedule if len(actions) > 1]
            self.assertAlmostEqual(len(bursts) / len(schedule), ratio, delta=0.03, msg=ratio)
            self.assertTrue(all(monkey.BURST_SIZE[0] <= len(a) <= monkey.BURST_SIZE[1] for a in bursts))
            self.assertFalse(any(action == ("wait",) for actions in bursts for action in actions),
                             "a burst frame never idles")

    def test_keys_come_from_the_whitelist_and_every_action_is_known(self):
        kinds = {"key", "end", "click", "aim", "drag", "wheel", "hover", "hold", "release", "wait"}
        for mode in monkey.MODES:
            schedule = monkey.plan(mode, 2, 3000, 0.5).frames
            actions = [action for _, actions in schedule for action in actions]
            self.assertLessEqual({"key", "end", "click", "aim", "drag", "hover"}, {a[0] for a in actions}, mode)
            self.assertLessEqual({a[0] for a in actions}, kinds)
            pressed = {a[1] for a in actions if a[0] == "key" or (a[0] == "end" and a[1] != "click")}
            self.assertLessEqual(pressed, monkey.keys_of(mode), mode)
            self.assertEqual(pressed, monkey.keys_of(mode), f"{mode}: 3000 frames press every key at least once")
            self.assertLessEqual({a[1] for a in actions if a[0] == "aim"}, set(monkey.AIMS[mode]), mode)
        self.assertFalse(any(a[0] in ("hold", "release") for _, f in monkey.plan("conquest", 2, 3000).frames
                             for a in f), "Conquest has no scrolling")

    def test_the_window_each_seed_opens(self):
        from hexa.campaign import geo
        from hexa.colony.rules import GOAL_NAMES, START_NAMES
        self.assertEqual(monkey.setup_of("conquest", 7), {"map": 7})
        colony = [monkey.setup_of("colony", seed) for seed in range(1, 40)]
        self.assertEqual({s["map"] for s in colony}, set(range(1, 40)))
        self.assertEqual({s["start"] for s in colony}, set(START_NAMES))
        self.assertEqual({s["goal"] for s in colony}, set(GOAL_NAMES))
        nations = {monkey.setup_of("campaign", seed)["nation"] for seed in range(1, 40)}
        self.assertLessEqual(nations, set(geo.COUNTRIES))
        self.assertGreater(len(nations), 10)
        self.assertEqual(monkey.setup_of("campaign", 25), monkey.setup_of("campaign", 25))

    def test_the_environment_sets_seeds_frames_and_burst(self):
        self.assertEqual(monkey.seeds("colony", {}), monkey.DEFAULT_SEEDS["colony"])
        self.assertEqual(monkey.seeds("colony", {monkey.SEEDS_VAR: "3"}), (1, 2, 3))
        self.assertEqual(monkey.seeds("colony", {monkey.SEEDS_VAR: "5-7, 12"}), (5, 6, 7, 12))
        self.assertEqual(monkey.parse_seeds("7", count=False), (7,), "the tool's seed is one seed")
        self.assertEqual({mode: monkey.frames(mode, {}) for mode in monkey.MODES},
                         {"conquest": 800, "colony": 800, "campaign": 300})
        env = {monkey.FRAMES_VAR: "3000,campaign=600"}
        self.assertEqual({mode: monkey.frames(mode, env) for mode in monkey.MODES},
                         {"conquest": 3000, "colony": 3000, "campaign": 600})
        self.assertEqual(monkey.frames("conquest", {monkey.FRAMES_VAR: "campaign=600"}), 800)
        self.assertEqual((monkey.burst({}), monkey.burst({monkey.BURST_VAR: "0.5"})), (0.3, 0.5))
        bad = [(monkey.seeds, ("colony", {monkey.SEEDS_VAR: "x"}), monkey.SEEDS_VAR),
               (monkey.seeds, ("colony", {monkey.SEEDS_VAR: "0"}), monkey.SEEDS_VAR),
               (monkey.seeds, ("colony", {monkey.SEEDS_VAR: "9-3"}), "empty range"),
               (monkey.frames, ("colony", {monkey.FRAMES_VAR: "bogus=5"}), "not a mode"),
               (monkey.frames, ("colony", {monkey.FRAMES_VAR: "1"}), "at least 2"),
               (monkey.burst, ({monkey.BURST_VAR: "1.5"},), "between 0 and 1"),
               (monkey.plan, ("chess", 1, 10), "unknown mode")]
        for function, args, says in bad:
            with self.subTest(args=args), self.assertRaisesRegex(ValueError, says):
                function(*args)

    def test_a_report_ends_with_the_command_that_replays_the_session(self):
        outcome = monkey.Outcome("colony", 7, 800, 0.5, monkey.setup_of("colony", 7))
        self.assertFalse(outcome.failed)
        outcome.problems["unit-hp"] = (150, "unit-hp: crimson soldier #4 at (3, 4) has 0 HP (max 10)")
        outcome.known["colony-capital"] = (50, "colony-capital: golden has 0 capitals among 1 colonies", "bug")
        outcome.log = [(149, "key", "tab"), (150, "click", (10, 20), 1)]
        self.assertTrue(outcome.failed)
        report = outcome.report().splitlines()
        self.assertTrue(report[0].startswith("Colonisation monkey, seed 7 (map 7, start "), report[0])
        self.assertIn("    frame 150: unit-hp: crimson soldier #4 at (3, 4) has 0 HP (max 10)", report)
        self.assertIn("    frame 50: colony-capital: golden has 0 capitals among 1 colonies  [bug]", report)
        self.assertEqual(report[-1], "Replay: python -m tools.monkey colony 7 800 --burst 0.5")
        self.assertEqual(monkey.repro("campaign", 25, 300, 0.5, ("card-toast",)),
                         "python -m tools.monkey campaign 25 300 --burst 0.5 --hit card-toast")

    def test_every_known_issue_is_documented(self):
        ids = [issue[0] for issue in monkey.KNOWN_ISSUES]
        self.assertEqual(len(ids), len(set(ids)))
        for issue in monkey.KNOWN_ISSUES:
            self.assertEqual(len(issue), 5)
            self.assertIn(issue[1], monkey.MODES)
            self.assertTrue(all(isinstance(text, str) and len(text) > 20 for text in issue[2:]), issue[0])
            self.assertIn("pinned by", issue[4], f"{issue[0]}: which test pins the bug")
        self.assertEqual(sorted(monkey._WITHHOLD), sorted(ids), "each issue has its predicate")


class UISuiteWithoutPygameTest(unittest.TestCase):
    """End to end, in a subprocess where pygame can't be imported: the ui job's command skips or errors."""

    def _ui_suite(self, require):
        home = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, home, True)
        env = dict(os.environ, HEXA_HOME=home)
        env.pop(pg.REQUIRE_VAR, None)
        env.pop(slow.FAST_VAR, None)            # @slow window tests would show as skipped, not as errors
        if require:
            env[pg.REQUIRE_VAR] = "1"
        done = subprocess.run([sys.executable, "-c", UI_SUITE_WITHOUT_PYGAME], cwd=ROOT, env=env,
                              capture_output=True, text=True, timeout=300)
        ran = re.search(r"^Ran (\d+) tests?", done.stderr, re.MULTILINE)
        self.assertIsNotNone(ran, done.stderr)
        return done, int(ran.group(1)), done.stderr.strip().splitlines()[-1]

    def test_without_pygame_every_ui_test_is_skipped(self):
        done, ran, summary = self._ui_suite(require=False)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertGreaterEqual(ran, 4, "the smoke tests were found")
        self.assertEqual(summary, f"OK (skipped={ran})", done.stderr)

    def test_hexa_require_pygame_1_turns_the_skips_into_errors(self):
        done, ran, summary = self._ui_suite(require=True)
        self.assertNotEqual(done.returncode, 0, done.stderr)
        self.assertEqual(summary, f"FAILED (errors={ran})", done.stderr)
        self.assertIn(pg.REQUIRE_VAR, done.stderr, "the error says why the tests did not skip")

    def test_importing_the_harness_and_ui_tests_does_not_import_pygame(self):
        code = ("import sys, tests.support.harness, tests.support.monkey, tests.ui.test_smoke, tests.ui.test_menu, "
                "tests.ui.test_launcher, tests.ui.test_monkey, tools.monkey; "
                "sys.exit(1 if 'pygame' in sys.modules else 0)")
        done = subprocess.run([sys.executable, "-c", code], cwd=ROOT, capture_output=True, text=True, timeout=60)
        self.assertEqual(done.returncode, 0, f"pygame was imported at module level\n{done.stderr}")


if __name__ == "__main__":
    unittest.main()
