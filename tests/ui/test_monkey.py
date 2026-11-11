"""Seeded monkey tests: random input into each window through its own run() loop (tests/support/monkey.py).

Each seed opens a window the way the launcher would and feeds it random whitelisted keys (never QUIT), clicks
(anywhere, or aimed at its buttons, units, reachable hexes...), drags, wheel turns and mouse moves, one action a
frame or a burst of them. When Esc or M ends the loop it runs again until the frame budget is used. A session fails
on any exception and on any world invariant (tests/support/invariants.py) broken without a known open bug to
explain it.

    HEXA_MONKEY_SEEDS=30         seeds 1 to 30 in every mode (default: seeds 1 and 2); also "5-9" or "3,8,12"
    HEXA_MONKEY_FRAMES=3000      frames per session in every mode (default 800, the campaign 300); "campaign=600"
                                 changes one mode, "3000,campaign=600" both
    HEXA_MONKEY_BURST=0.5        the chance that a frame gets a burst of 2 to 6 actions (default 0.3)

A failing session prints the command that replays it, python -m tools.monkey <mode> <seed> <frames> --burst <b>,
and saves its report and last frame to test-artifacts/monkey-<mode>-<seed>.txt and .png. Run with:

    python -m unittest tests.ui.test_monkey
    HEXA_MONKEY_SEEDS=30 HEXA_MONKEY_BURST=0.5 python -m unittest tests.ui.test_monkey.MonkeyTest
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from tests.support import harness, invariants, monkey

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class MonkeyCase(harness.UITestCase):
    def assert_clean(self, outcome, artifacts=True):
        """Fail with the session's report (it ends with the replay command) if it failed."""
        if outcome.failed:
            saved = monkey.save_artifacts(outcome) if artifacts else []
            self.fail("\n" + outcome.report() + "".join(f"\nSaved {path}" for path in saved))

    def assert_fixed(self, outcome, error, where):
        """For an expectedFailure test that pins a crash: fail while the session still raises error in the function
        where (as its traceback shows). Passing otherwise, it reports an unexpected success: either the bug is fixed
        (remove the decorator) or the session now fails in some other way (printed here), which needs a look too."""
        if isinstance(outcome.error, error) and f", in {where}\n" in outcome.trace:
            self.fail("\n" + outcome.report())
        if outcome.failed:
            print(f"\n{self.id()}: the pinned crash is gone, but the session fails another way:\n{outcome.report()}",
                  file=sys.stderr)


class MonkeyTest(MonkeyCase):
    """The seeds, budgets and burst ratio of HEXA_MONKEY_SEEDS, HEXA_MONKEY_FRAMES and HEXA_MONKEY_BURST."""

    def play(self, mode):
        budget, ratio = monkey.frames(mode), monkey.burst()
        for seed in monkey.seeds(mode):
            with self.subTest(mode=mode, seed=seed):
                outcome = monkey.run_session(mode, seed, budget, ratio)
                self.assert_clean(outcome)
                self.assertGreaterEqual(outcome.frames_run, budget, "the whole budget was played")

    def test_conquest(self):
        self.play("conquest")

    def test_colony(self):
        self.play("colony")

    def test_campaign(self):
        self.play("campaign")


class SessionTest(MonkeyCase):
    """The monkey itself: the same seed plays the same session, and nothing it finds is swallowed."""

    def test_a_seed_plays_the_same_session_every_time(self):
        played = {}
        for mode, budget in (("conquest", 300), ("colony", 200), ("campaign", 40)):
            with self.subTest(mode=mode):
                first = played[mode] = monkey.run_session(mode, 4, budget, 0.5)
                again = monkey.run_session(mode, 4, budget, 0.5)
                self.assert_clean(first, artifacts=False)
                self.assertGreater(len(first.log), budget, "a burst frame carries several actions")
                self.assertGreater(first.turn(), 1, "the computer played a turn too")
                self.assertEqual(again.log, first.log, "the same actions, aimed at the same pixels")
                self.assertEqual(again.world_digest(), first.world_digest(), "and the same game came of it")
        other = monkey.run_session("conquest", 5, 300, 0.5)
        self.assertNotEqual(other.log_hash(), played["conquest"].log_hash(), "another seed, another session")

    def test_the_replay_command_plays_the_same_session_in_a_new_process(self):
        here = monkey.run_session("conquest", 3, 300, 0.5)
        home = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, home, True)
        env = dict(os.environ, HEXA_HOME=home, PYTHONHASHSEED="123")
        done = subprocess.run([sys.executable, "-m", "tools.monkey", "conquest", "3", "300", "--burst", "0.5",
                               "--digest"], cwd=ROOT, env=env, capture_output=True, text=True, timeout=300)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertEqual(done.stdout.splitlines()[0].rsplit(",", 1)[0], here.summary().rsplit(",", 1)[0])
        self.assertIn(f"log {here.log_hash()}  world {here.world_digest()}", done.stdout)

    def test_esc_and_m_end_the_loop_and_it_runs_again_until_the_budget_is_used(self):
        outcome = monkey.run_session("conquest", 1, 300, 0.3)
        self.assert_clean(outcome, artifacts=False)
        ends = {entry[2] for entry in outcome.log if entry[1] == "restart"}
        self.assertEqual(ends, {"quit", "menu"}, "Esc with nothing selected quits, M goes to the menu")
        self.assertEqual(outcome.restarts, sum(entry[1] == "restart" for entry in outcome.log))
        self.assertGreaterEqual(outcome.frames_run, 300)
        self.assertIn(("key", "m"), {entry[1:] for entry in outcome.log})

    def test_an_exception_in_the_window_fails_the_session_where_it_happened(self):
        import play
        real = play.App.update

        def update(app, now):
            if now >= harness.START_MS + 100 * harness.FRAME_MS:
                raise ZeroDivisionError("injected")
            return real(app, now)

        with mock.patch.object(play.App, "update", update):
            outcome = monkey.run_session("conquest", 1, 300, 0.3)
        self.assertTrue(outcome.failed)
        self.assertIsInstance(outcome.error, ZeroDivisionError)
        self.assertEqual(outcome.error_frame, 100, "the session stopped at the frame that raised")
        self.assertEqual(outcome.frames_run, 100)
        report = outcome.report().splitlines()
        self.assertIn("ZeroDivisionError at frame 100: injected", report[1])
        self.assertIn("in update", "\n".join(report), "with the traceback")
        self.assertEqual(report[-1], "Replay: python -m tools.monkey conquest 1 300 --burst 0.3")

    def test_the_known_goods_map_crash_is_not_excused_anywhere_else(self):
        """KNOWN_ISSUES withholds input; it never excuses an exception, even the one the goods map raises."""
        from hexa.campaign.app import CampaignApp
        drawn = []

        def draw_minimap(app):
            drawn.append(1)
            if len(drawn) == 20:
                raise KeyError("stone")

        with mock.patch.object(CampaignApp, "draw_minimap", draw_minimap):
            outcome = monkey.run_session("campaign", 1, 60, 0.3)
        self.assertIsInstance(outcome.error, KeyError)
        self.assertIn("in draw_minimap", outcome.trace)

    def test_a_broken_invariant_fails_the_session(self):
        def twin(app):                                       # two units with one id
            app.world.units[1].id = app.world.units[0].id

        outcome = monkey.run_session("conquest", 1, 120, 0.3, prepare=twin)
        self.assertTrue(outcome.failed)
        self.assertIsNone(outcome.error)
        frame, text = outcome.problems["unit-id"]
        self.assertLessEqual(frame, monkey.CHECK_EVERY, "found by the first check (an Esc restart checks too)")
        self.assertTrue(text.startswith("unit-id: duplicate unit ids"), text)
        self.assertIn("unit-id: duplicate unit ids", outcome.report())

    def test_an_open_bug_s_broken_invariant_is_reported_but_does_not_fail(self):
        real = invariants.colony_problems
        extra = []

        def problems(world):
            return real(world) + extra

        with mock.patch.object(invariants, "colony_problems", problems):
            extra[:] = ["colony-capital: crimson has 0 capitals among 1 colonies"]
            known = monkey.run_session("colony", 1, 100, 0.3)
            extra[:] = ["colony-pop: crimson colony Fort at (3, 4) has 0 people (1..8)"]
            new = monkey.run_session("colony", 1, 100, 0.3)
        self.assertFalse(known.failed, known.report())
        self.assertEqual(list(known.known), ["colony-capital"])
        self.assertIn("known open bugs seen", known.report())
        self.assertTrue(new.failed)
        self.assertEqual(list(new.problems), ["colony-pop"])


class KnownIssuesTest(MonkeyCase):
    """The input withheld for known open crashes (monkey.KNOWN_ISSUES): exactly what would crash, nothing more."""

    def test_the_goods_map_is_withheld_only_where_it_would_crash(self):
        import pygame
        import play
        from hexa.campaign.app import CampaignApp
        from hexa.campaign.mapview import TILE_FROM
        from tests.support.harness import click, key, wheel

        app = CampaignApp(play.TILES_DIR, "POR")
        app.draw()
        view = app.view
        withheld = lambda events: [monkey._goods_close_up(app, e) for e in events if e.type in (   # noqa: E731
            pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN, pygame.MOUSEWHEEL)]
        goods = harness.button_rect(app, "Goods", ("mode", "goods")).center
        terrain = harness.button_rect(app, "Terrain", ("mode", "terrain")).center
        middle = app.view_rect().center
        self.assertEqual((view.zoom, view.mode), (4, "political"))
        self.assertEqual(withheld(key("3") + click(goods) + click(goods, 3)), [True, True, False])
        self.assertEqual(withheld(key("2") + click(terrain) + key("+") + wheel(1, pos=middle)), [False] * 4)
        view.zoom = TILE_FROM - 1
        self.assertEqual(withheld(key("3") + click(goods)), [False, False], "zoomed out the goods map is fine")
        view.mode = "goods"
        self.assertEqual(withheld(key("+") + key("=") + key("[+]") + wheel(1, pos=middle)), [True] * 4)
        self.assertEqual(withheld(key("-") + wheel(-1, pos=middle) + key("3")), [False] * 3)
        app.ui.panel, app.ui.mouse = "country", app.panel_rect().center       # the window keeps the mouse there
        self.assertEqual(withheld(wheel(1, pos=app.ui.mouse)), [False], "the wheel over a panel")
        app.open_menu()
        self.assertEqual(withheld(key("+")), [False], "the pause menu takes the keys")
        app.close_menu()
        view.zoom = TILE_FROM - 2
        self.assertEqual(withheld(key("+")), [False], "one step in stays below the tile zoom levels")

    def test_a_click_on_a_greyed_out_troop_button_is_withheld_and_nothing_else(self):
        import pygame
        import play
        from hexa.campaign.app import CampaignApp
        from tests.support.harness import click

        app = CampaignApp(play.TILES_DIR, "POR")
        world = app.world
        world.countries["POR"].treasury = 0                  # every troop greyed out, and Fund research
        app.press(("raise", world.provinces[world.countries["POR"].capital]))
        app.draw()
        troops = [b for b in app.ui.buttons if b.action[0] == "recruit"]
        self.assertTrue(troops)
        self.assertFalse(any(b.enabled for b in troops))
        self.assertIsInstance(troops[0].hint, tuple, "a hover card")
        fund = next(b for b in app.ui.buttons if b.action == ("fund",))
        self.assertEqual((fund.enabled, type(fund.hint)), (False, str))
        back = harness.button_rect(app, "Back to the province").center
        withheld = lambda events: [monkey._card_toast(app, e) for e in events                     # noqa: E731
                                   if e.type == pygame.MOUSEBUTTONDOWN]
        self.assertEqual(withheld(click(troops[0].rect.center) + click(troops[-1].rect.center)), [True, True])
        self.assertEqual(withheld(click(fund.rect.center) + click(back) + click(troops[0].rect.center, 3)),
                         [False] * 3, "a greyed-out button with a line of hint, an enabled one, a right click")
        app.open_menu()
        self.assertEqual(withheld(click(troops[0].rect.center)), [False], "the pause menu takes the clicks")

    @unittest.expectedFailure
    def test_seed_1_without_withholding_the_goods_map(self):
        """New bug, no GitHub issue filed yet (KNOWN_ISSUES "goods-close-up", pinned on its own by test_campaign_app
        MapModeTest.test_the_close_up_goods_map_shows_each_goods_view): with that input let through, campaign seed 1
        turns the goods map on at a tile zoom level at frame 95 and crashes with KeyError: 'cattle' in
        MapView._mode_layer. When the bug is fixed, remove this decorator and the KNOWN_ISSUES row.
        Replay: python -m tools.monkey campaign 1 300 --burst 0.3 --hit goods-close-up"""
        outcome = monkey.run_session("campaign", 1, 300, 0.3, hit=("goods-close-up",))
        self.assert_fixed(outcome, KeyError, "_mode_layer")


class NewBugsTest(MonkeyCase):
    """Crashes this monkey found that no GitHub issue covers yet. Each replays the session that found it with that
    bug's input let through (KNOWN_ISSUES withholds it in every other session, so they can find other bugs). The fix
    removes the decorator and the KNOWN_ISSUES row."""

    @unittest.expectedFailure
    def test_campaign_25_300_burst_0_5(self):
        """New bug, no GitHub issue filed yet (KNOWN_ISSUES "card-toast"): clicking a greyed-out troop button in the
        Raise panel crashes the game with TypeError: text must be a unicode or bytes. left_click() shows a disabled
        button's hint as a toast and draw_hint() draws the toast as one line of text, but the troop buttons' hint is
        a (title, lines) hover card. Austria at frame 204 here, clicking a troop its province can't raise this season.
        Replay: python -m tools.monkey campaign 25 300 --burst 0.5 --hit card-toast"""
        outcome = monkey.run_session("campaign", 25, 300, 0.5, hit=("card-toast",))
        self.assert_fixed(outcome, TypeError, "_one_line")


if __name__ == "__main__":
    unittest.main()
