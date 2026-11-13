"""The end-of-turn reminder screen in the Age of Discovery window (hexa/campaign/screens/reminders.py): End season first
lists what is unfinished, each line goes to the thing it names, "End season anyway" (Enter) ends the season, Back (Esc)
does not, the option can turn it off, and the screen never changes the game. The rules are in tests/test_reminders.py.
Run with: python -m unittest tests.ui.test_reminder_screen"""
import pickle
from unittest import mock

from tests.support import harness
from tests.support.digests import quick_digest
from tests.support.harness import click, key


class ReminderCase(harness.UITestCase):
    def start(self, reminders=True, tag="POR"):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = app = CampaignApp(play.TILES_DIR, tag)
        app.settings["reminders"] = reminders
        self.world = app.world
        return app

    def top(self):
        from hexa.campaign.screens.reminders import ReminderScreen
        top = self.app.screens.top
        return top if isinstance(top, ReminderScreen) else None

    def run_loop(self, frames, *steps, until=None):
        """Run the window's loop again for `frames`; the driver starts from frame 0 and each step is (frame, events)."""
        self.driver.reset()
        self.app.running, self.app.result = True, None
        for frame, events in steps:
            self.driver.at(frame, events)
        self.driver.run_for(frames, until)
        return self.app.run()

    def row(self, i):
        return self.top().buttons[i][0]

    def idle_army(self):
        """Put the Portuguese pikemen outside their castle, so the army line shows."""
        w = self.world
        unit = next(u for u in w.units_of("POR") if u.kind.war and not u.naval)
        unit.pos = next(p.pos for p in sorted(w.provinces_of("POR"), key=lambda p: p.pos)
                        if not p.castle and not w.units_at(p.pos))
        return unit


class FlowTest(ReminderCase):
    def test_end_season_first_shows_the_list_and_the_season_waits(self):
        app = self.start()
        self.run_loop(6, (1, key("space")))
        screen = self.top()
        self.assertIsNotNone(screen, "the reminder list is on the stack")
        self.assertFalse(screen.opaque)
        self.assertEqual(self.world.turn, 1)
        self.assertEqual([r.kind for r in screen.found], ["fund", "merchant", "build"])
        self.assertEqual(len(app.screens), 1)

    def test_the_end_season_button_asks_too(self):
        self.start()
        self.run_loop(6, (1, lambda: click(harness.end_turn_rect(self.app).center)))
        self.assertIsNotNone(self.top())
        self.assertEqual(self.world.turn, 1)

    def test_enter_ends_the_season_anyway(self):
        self.start()
        self.run_loop(12, (1, key("space")), (4, key("return")), until=lambda: self.world.turn == 2)
        self.assertEqual(self.world.turn, 2)
        self.assertIsNone(self.top())
        self.assertEqual(len(self.app.screens), 0)

    def test_the_end_season_anyway_button_does_the_same(self):
        self.start()
        self.run_loop(12, (1, lambda: click(harness.end_turn_rect(self.app).center)),
                      (4, lambda: click(self.top().buttons[-2][0].center)), until=lambda: self.world.turn == 2)
        self.assertEqual(self.world.turn, 2)
        self.assertIsNone(self.top())

    def test_escape_the_back_button_and_a_right_click_go_back_without_a_season(self):
        self.start()
        self.run_loop(8, (1, key("space")), (4, key("escape")))
        self.assertEqual((self.top(), self.world.turn), (None, 1))
        self.run_loop(8, (1, key("space")), (4, lambda: click(self.top().buttons[-1][0].center)))
        self.assertEqual((self.top(), self.world.turn), (None, 1))
        self.run_loop(8, (1, key("space")), (4, lambda: click((5, 400), button=3)))
        self.assertEqual((self.top(), self.world.turn), (None, 1))

    def test_a_click_outside_the_box_is_back_and_space_does_nothing_on_the_list(self):
        self.start()
        self.run_loop(8, (1, key("space")), (4, key("space")))
        self.assertIsNotNone(self.top(), "a second Space is used up by the list")
        self.assertEqual(self.world.turn, 1)
        self.run_loop(8, (1, key("space")), (4, lambda: click((5, 400))))
        self.assertEqual((self.top(), self.world.turn), (None, 1))

    def test_the_option_off_ends_the_season_at_once(self):
        self.start(reminders=False)
        self.run_loop(30, (1, key("space")), until=lambda: self.world.turn == 2)
        self.assertEqual(self.world.turn, 2)
        self.assertIsNone(self.top())

    def test_nothing_unfinished_ends_the_season_at_once(self):
        from hexa.campaign import reminders
        self.start()
        with mock.patch.object(reminders, "unfinished", lambda world, tag: []):
            self.run_loop(30, (1, key("space")), until=lambda: self.world.turn == 2)
        self.assertEqual(self.world.turn, 2)

    def test_next_season_it_asks_again(self):
        self.start()
        self.run_loop(30, (1, key("space")), (4, key("return")), until=lambda: self.world.turn == 2)
        self.assertEqual(len(self.app.screens), 0)
        self.run_loop(6, (1, key("space")))
        self.assertIsNotNone(self.top())

    def test_a_running_replay_is_skipped_before_the_list_is_asked(self):
        from hexa.events import Event
        app = self.start()
        move = Event("unit_moved", "CAS", (3, 3), {"ids": [1], "path": ((1, 3), (2, 3), (3, 3)),
                                                    "seen": (True, True, True)})
        app.ui.replay.record(move, "normal")
        self.run_loop(4, (1, key("space")))
        self.assertFalse(app.ui.replay.active)
        self.assertIsNone(self.top(), "the first Space only skipped the replay")
        self.run_loop(4, (1, key("space")))
        self.assertIsNotNone(self.top())


class QuickloadTest(ReminderCase):
    def test_a_quickload_while_the_list_is_up_drops_it(self):
        from hexa.campaign import saves
        app = self.start()
        self.run_loop(4, (1, key("f5")))                     # a quicksave of this game
        self.assertIsNotNone(saves.meta("quick"))
        self.run_loop(6, (1, key("space")))
        self.assertIsNotNone(self.top())
        old = app.world
        self.run_loop(10, (1, key("f9")), (3, key("f9")))      # a second F9 loads it
        self.assertIsNot(app.world, old)
        self.assertIsNone(self.top(), "the list was about the old game")


class LineTest(ReminderCase):
    """A click on a line goes to the thing it names, and the list closes."""

    def open_list(self):
        self.run_loop(5, (1, key("space")))
        self.assertIsNotNone(self.top())

    def click_row(self, i):
        self.run_loop(4, (1, lambda: click(self.row(i).center)))
        self.assertIsNone(self.top(), "the list closed")
        self.assertEqual(self.world.turn, 1, "and no season passed")

    def test_the_merchant_line_opens_the_market(self):
        app = self.start()
        self.open_list()
        self.click_row([r.kind for r in self.top().found].index("merchant"))
        self.assertEqual(app.ui.panel, "market")
        self.assertIn(app.ui.market, self.world.merchant_markets("POR"))

    def test_the_research_line_opens_the_technology_screen(self):
        app = self.start()
        self.open_list()
        self.assertEqual(self.top().found[0].action, ("tech",))
        self.click_row(0)
        self.assertTrue(app.tech_open)

    def test_the_build_line_opens_the_province(self):
        app = self.start()
        self.open_list()
        shown = self.top().found[-1]
        self.assertEqual(shown.kind, "build")
        self.click_row(len(self.top().found) - 1)
        self.assertEqual((app.ui.panel, app.ui.province), ("province", shown.action[1]))

    def test_the_army_line_goes_to_the_army_and_selects_it(self):
        app = self.start()
        unit = self.idle_army()
        self.open_list()
        found = self.top().found
        self.assertEqual(found[-1].kind, "army")
        self.click_row(len(found) - 1)
        self.assertIs(app.ui.selected, unit)
        self.assertEqual(app.ui.panel, "unit")


class DrawingTest(ReminderCase):
    def test_the_list_never_changes_the_world(self):
        app = self.start()
        self.idle_army()
        before = (quick_digest(self.world), pickle.dumps(self.world.save_state(), protocol=pickle.HIGHEST_PROTOCOL))
        self.run_loop(40, (1, key("space")))
        self.assertIsNotNone(self.top())
        for _ in range(20):
            app.draw()
        self.run_loop(4, (1, key("escape")))
        after = (quick_digest(self.world), pickle.dumps(self.world.save_state(), protocol=pickle.HIGHEST_PROTOCOL))
        self.assertEqual(before, after)

    def test_every_row_and_both_buttons_fit_in_the_box_and_the_window(self):
        app = self.start()
        self.idle_army()
        self.run_loop(6, (1, key("space")))
        screen = self.top()
        self.assertTrue(app.screen.get_rect().contains(screen.rect))
        for rect, _ in screen.buttons:
            self.assertTrue(screen.rect.contains(rect), (rect, screen.rect))
        self.assertEqual([action[0] for _, action in screen.buttons], ["go"] * len(screen.found) + ["end", "back"])


class OptionsTest(ReminderCase):
    def test_the_options_page_has_the_reminders_row_and_it_toggles_and_is_saved(self):
        from hexa import settings
        app = self.start(reminders=True)
        app.pause.open(app, "options")
        app.draw()
        self.assertIsNotNone(harness.pause_button_rect(app, ("option", "reminders")))
        app.pause.press(app, ("option", "reminders"))
        self.assertFalse(app.settings["reminders"])
        self.assertFalse(settings.load()["reminders"])
        app.pause.press(app, ("option", "reminders"))
        self.assertTrue(settings.load()["reminders"])
