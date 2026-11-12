"""The soak tool (tools/soak.py): its games, reports, plans and exit status. The full soak runs in the nightly
workflow; these play a few short games. No pygame needed."""
import os
import tempfile
import unittest
from unittest import mock

from tests.support import invariants
from tools import soak


class GameTest(unittest.TestCase):
    def test_a_conquest_game_plays_to_the_end_and_is_checked_after_every_turn(self):
        game = soak.play_game("conquest", 2)
        self.assertFalse(game.failed, game.report())
        self.assertIn("won on turn", game.note)
        self.assertTrue(2 * game.turn - 1 <= game.checks <= 2 * game.turn + 1,
                        f"{game.checks} checks by turn {game.turn}: at the start and after each side's turn")
        self.assertTrue(game.summary().startswith("conquest seed 2: ok ("), game.summary())

    def test_a_new_broken_invariant_fails_the_game_and_prints_the_replay_command(self):
        real, calls = invariants.conquest_problems, []

        def problems(world):
            calls.append(1)
            return real(world) + (["unit-id: duplicate unit ids [7]"] if len(calls) == 5 else [])

        with mock.patch.object(invariants, "conquest_problems", problems):
            game = soak.play_game("conquest", 3)
        self.assertTrue(game.failed)
        self.assertEqual(game.checks, 5, "the game stops at its first new problem")
        self.assertEqual(list(game.problems), ["unit-id"])
        self.assertIn("FAILED on turn 3, before player's move: unit-id: duplicate unit ids [7]", game.summary())
        report = game.report().splitlines()
        self.assertIn("    on turn 3, before player's move: unit-id: duplicate unit ids [7]", report)
        self.assertEqual(report[-1], "Replay: python -m tools.soak conquest 3")

    def test_a_known_open_bug_is_reported_but_does_not_fail(self):
        real = invariants.colony_problems
        capital = "colony-capital: crimson has 0 capitals among 1 colonies"
        with mock.patch.object(invariants, "colony_problems", lambda world: real(world) + [capital]), \
                mock.patch.dict(invariants.KNOWN_OPEN, {("colony", "colony-capital:"): "a made-up open bug"}):       # no real open bug is left to name
            game = soak.play_game("colony", 1, turns=2)
        self.assertFalse(game.failed, game.report())
        self.assertEqual(list(game.known), ["colony-capital"])
        self.assertIn("1 known open", game.summary())
        self.assertIn(f"    at the start: {capital}  [a made-up open bug]",
                      game.report().splitlines())
        self.assertEqual(game.report().splitlines()[-1], "Replay: python -m tools.soak colony 1 --turns 2")

    def test_an_exception_fails_the_game_and_says_where(self):
        with mock.patch("hexa.ai.take_turn", side_effect=ZeroDivisionError("injected")):
            game = soak.play_game("conquest", 1)
        self.assertIsInstance(game.error, ZeroDivisionError)
        self.assertIn("FAILED in player's move on turn 1: ZeroDivisionError: injected", game.summary())
        report = game.report()
        self.assertIn("in play_conquest", report, "the end of the traceback")
        self.assertTrue(report.endswith("Replay: python -m tools.soak conquest 1"), report)

    def test_a_campaign_game_is_checked_every_season(self):
        game = soak.play_game("europe", 1480, turns=1)
        self.assertFalse(game.failed, game.report())
        self.assertEqual(game.checks, 2, "at the start and after the season")
        self.assertIn("until Summer 1480", game.note)

    def test_the_same_seed_plays_the_same_game(self):
        first = soak.play_game("colony", 4, turns=3, digest=True)
        again = soak.play_game("colony", 4, turns=3, digest=True)
        other = soak.play_game("colony", 6, turns=3, digest=True)
        self.assertEqual(again.digest, first.digest)
        self.assertNotEqual(other.digest, first.digest)

    def test_the_colony_setup_varies_with_the_seed(self):
        notes = {soak.play_game("colony", seed, turns=1).note.rsplit(", turn", 1)[0] for seed in range(6)}
        self.assertEqual(len(notes), 6, notes)


class PlanTest(unittest.TestCase):
    def test_the_full_scale(self):
        planned = {suite: (seeds, turns) for suite, seeds, turns in soak.plan(soak.SUITES)}
        self.assertEqual(planned["conquest"], (list(range(200)), None))
        self.assertEqual(planned["colony"], (list(range(50)), 40))
        self.assertEqual(planned["europe"], ([1480], 100))
        self.assertEqual(planned["random"], ([1, 2, 3], 40))

    def test_quick_and_chosen_seeds_and_turns(self):
        self.assertEqual(soak.plan(["colony"], quick=True), [("colony", [0, 1, 2], 10)])
        self.assertEqual(soak.plan(["random"], seeds=(5, 9), turns=2), [("random", [5, 9], 2)])
        self.assertEqual(soak.plan(["conquest"], turns=5), [("conquest", list(range(200)), None)],
                         "Conquest always plays to the end")

    def test_the_replay_command_names_the_turns_only_when_they_differ(self):
        self.assertEqual(soak.repro("colony", 7, 40), "python -m tools.soak colony 7")
        self.assertEqual(soak.repro("europe", 1480, 8), "python -m tools.soak europe 1480 --turns 8")
        self.assertEqual(soak.repro("conquest", 17, None), "python -m tools.soak conquest 17")


class CommandTest(unittest.TestCase):
    def setUp(self):
        handle, self.summary_file = tempfile.mkstemp(suffix=".md")
        os.close(handle)
        self.addCleanup(os.remove, self.summary_file)
        patcher = mock.patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": self.summary_file})
        patcher.start()
        self.addCleanup(patcher.stop)

    def main(self, *argv):
        lines = []
        status = soak.main(list(argv), out=lines.append)
        return status, "\n".join(lines)

    def test_one_game_passes(self):
        status, text = self.main("conquest", "2")
        self.assertEqual(status, 0, text)
        self.assertIn("1 of 1 games passed", text)
        with open(self.summary_file, encoding="utf-8") as f:
            summary = f.read()
        self.assertIn("| conquest | 1 | 0 | 0 |", summary)

    def test_a_failure_gives_status_1_and_its_replay_line(self):
        real = invariants.colony_problems
        with mock.patch.object(invariants, "colony_problems",
                               lambda world: real(world) + ["colony-pop: crimson colony at (3, 4) has 0 people"]):
            status, text = self.main("colony", "3,5", "--turns", "1")
        self.assertEqual(status, 1)
        self.assertIn("0 of 2 games passed", text)
        self.assertIn("FAILED colony seed 5: Replay: python -m tools.soak colony 5 --turns 1", text)
        with open(self.summary_file, encoding="utf-8") as f:
            summary = f.read()
        self.assertIn("python -m tools.soak colony 3 --turns 1", summary)

    def test_known_open_bugs_are_listed_in_the_summary(self):
        real = invariants.colony_problems
        dead = "dead-side-units: ['crimson'] still have units"
        with mock.patch.object(invariants, "colony_problems", lambda world: real(world) + [dead]), \
                mock.patch.dict(invariants.KNOWN_OPEN, {("colony", "dead-side-units:"): "a made-up open bug"}):       # no real open bug is left to name
            status, text = self.main("colony", "2", "--turns", "1")
        self.assertEqual(status, 0, text)
        self.assertIn("known open: a made-up open bug: 1 game(s), e.g. colony seed 2 at the start", text)
        with open(self.summary_file, encoding="utf-8") as f:
            self.assertIn("Known open bugs seen (they don't fail the run):", f.read())

    def test_bad_arguments_are_refused(self):
        for argv in (["all", "3"], ["conquest", "--turns", "5"], ["colony", "x"], ["colony", "1", "--turns", "0"]):
            with self.subTest(argv=argv), mock.patch("sys.stderr"), self.assertRaises(SystemExit) as done:
                soak.main(argv, out=lambda line: None)
            self.assertEqual(done.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
