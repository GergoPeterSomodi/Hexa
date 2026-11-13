"""The task flag in the Age of Discovery window (hexa/campaign/hud/tasks.py): one "N things to do" flag under End season
shows what is unfinished (campaign/reminders.py), a click opens the list, a line goes to the thing it names and closes
it, Esc or a click elsewhere closes it, End season never asks, and the "Task flag" option turns the flag off. The rules
themselves are in tests/test_reminders.py. Run with: python -m unittest tests.ui.test_task_flag"""
import pickle
from unittest import mock

from tests.support import harness
from tests.support.digests import quick_digest
from tests.support.harness import click, key


class FlagCase(harness.UITestCase):
    def start(self, reminders=True, tag="POR"):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = app = CampaignApp(play.TILES_DIR, tag)
        app.settings["reminders"] = reminders
        self.world = app.world
        return app

    @property
    def tasks(self):
        return self.app.hud.tasks

    def run_loop(self, frames, *steps, until=None):
        """Run the window's loop again for `frames`; the driver starts from frame 0 and each step is (frame, events)."""
        self.driver.reset()
        self.app.running, self.app.result = True, None
        for frame, events in steps:
            self.driver.at(frame, events)
        self.driver.run_for(frames, until)
        return self.app.run()

    def flag_label(self):
        """The label of the flag as the last frame drew it, or None when there is no flag."""
        for button in self.app.ui.buttons:
            if button.action == ("tasks",):
                return button.label
        return None

    def click_flag(self):
        self.run_loop(3, (1, lambda: click(self.tasks.flag.center)))

    def click_row(self, i):
        self.run_loop(3, (1, lambda: click(self.tasks.rows[i][0].center)))

    def kinds(self):
        return [line.kind for line in self.tasks.lines(self.app)]

    def idle_army(self):
        """Put the Portuguese pikemen outside their castle, so the army line shows."""
        w = self.world
        unit = next(u for u in w.units_of("POR") if u.kind.war and not u.naval)
        unit.pos = next(p.pos for p in sorted(w.provinces_of("POR"), key=lambda p: p.pos)
                        if not p.castle and not w.units_at(p.pos))
        return unit


class ShowsTest(FlagCase):
    def test_the_flag_shows_the_count_under_end_season(self):
        app = self.start()
        app.ui.panel = None                     # the campaign opens the country panel: the flag then sits beside it
        self.run_loop(3)
        n = len(self.tasks.lines(app))
        self.assertGreater(n, 0, "the start of Portugal has things to do")
        self.assertEqual(self.flag_label(), f"{n} things to do")
        end = harness.end_turn_rect(app)
        self.assertEqual(self.tasks.flag.right, end.right, "the flag is right-aligned under End season")
        self.assertGreater(self.tasks.flag.y, end.bottom)
        self.assertTrue(app.view_rect().contains(self.tasks.flag))

    def test_one_thing_is_singular(self):
        self.start()
        from hexa.campaign import reminders
        one = reminders.unfinished(self.world, "POR")[:1]
        with mock.patch.object(reminders, "unfinished", lambda world, tag: one):
            self.tasks.forget()
            self.run_loop(3)
        self.assertEqual(self.flag_label(), "1 thing to do")

    def test_the_lines_are_worked_out_once_not_every_frame(self):
        from hexa.campaign import reminders
        self.start()
        with mock.patch.object(reminders, "unfinished", wraps=reminders.unfinished) as unfinished:
            self.run_loop(30)
        self.assertEqual(unfinished.call_count, 1)

    def test_the_count_drops_when_a_task_is_done_and_the_flag_goes_at_zero(self):
        from hexa.campaign import reminders
        app = self.start()
        self.run_loop(3)
        before = len(self.tasks.lines(app))
        self.assertIn("fund", self.kinds())
        app.press(("fund",))                    # the technology screen's button: an action, so the window refreshes
        self.run_loop(3)
        self.assertNotIn("fund", self.kinds())
        after = len(self.tasks.lines(app))
        self.assertLess(after, before)
        self.assertEqual(self.flag_label(), f"{after} things to do" if after != 1 else "1 thing to do")
        with mock.patch.object(reminders, "unfinished", lambda world, tag: []):
            self.tasks.forget()
            self.run_loop(3)
        self.assertIsNone(self.tasks.flag)
        self.assertIsNone(self.flag_label())

    def test_the_flag_is_not_drawn_under_a_screen(self):
        app = self.start()
        self.run_loop(3)
        app.open_menu()
        self.run_loop(3)
        self.assertIsNone(self.tasks.flag)
        self.assertIsNone(self.tasks.box)


class EndSeasonTest(FlagCase):
    def test_end_season_never_asks_and_the_season_passes(self):
        app = self.start()
        self.run_loop(6, (1, key("space")), until=lambda: self.world.turn == 2)
        self.assertEqual(self.world.turn, 2)
        self.assertEqual(len(app.screens), 0)

    def test_the_end_season_button_passes_it_too(self):
        app = self.start()
        self.run_loop(6, (1, lambda: click(harness.end_turn_rect(app).center)), until=lambda: self.world.turn == 2)
        self.assertEqual(self.world.turn, 2)
        self.assertEqual(len(app.screens), 0)

    def test_the_list_closes_when_the_season_ends(self):
        self.start()
        self.click_flag()
        self.assertTrue(self.tasks.open)
        self.run_loop(6, (1, key("space")), until=lambda: self.world.turn == 2)
        self.assertFalse(self.tasks.open)


class ListTest(FlagCase):
    def test_a_click_on_the_flag_opens_the_list_and_a_second_one_closes_it(self):
        self.start()
        self.click_flag()
        self.assertTrue(self.tasks.open)
        self.assertIsNotNone(self.tasks.box)
        self.assertEqual(len(self.tasks.rows), len(self.tasks.lines(self.app)))
        self.assertGreaterEqual(self.tasks.box.top, self.tasks.flag.bottom)
        self.run_loop(3, (1, lambda: click(self.tasks.flag.center)))
        self.assertFalse(self.tasks.open)

    def test_the_list_fits_the_window_and_it_is_over_the_map(self):
        app = self.start()
        self.click_flag()
        self.assertTrue(app.screen.get_rect().contains(self.tasks.box))
        self.assertTrue(app.hud.covers(app, self.tasks.box.center))
        self.assertIsNone(app.hex_under(self.tasks.box.center), "the list is over the map: no hex under it")

    def test_a_click_on_the_map_closes_the_list_and_selects_nothing(self):
        app = self.start()
        self.click_flag()
        pos = sorted(self.world.provinces_of("POR"), key=lambda p: p.pos)[0].pos
        pixel = harness.hex_pixel(app, pos)
        self.assertFalse(app.hud.covers(app, pixel), "the test hex is on the map, not under the HUD")
        province, panel = app.ui.province, app.ui.panel
        self.run_loop(3, (1, lambda: click(pixel)))
        self.assertFalse(self.tasks.open)
        self.assertIs(app.ui.province, province, "the click only closed the list: the hex was not selected")
        self.assertEqual(app.ui.panel, panel)

    def test_esc_closes_the_list_and_does_not_open_the_menu(self):
        app = self.start()
        self.click_flag()
        self.run_loop(3, (1, key("escape")))
        self.assertFalse(self.tasks.open)
        self.assertIsNone(app.menu)
        self.assertEqual(len(app.screens), 0)

    def test_the_flag_works_with_a_side_panel_open(self):
        app = self.start()
        app.open_country("POR")
        self.run_loop(3)
        self.assertEqual(self.tasks.flag.right, app.panel_rect().left - 10, "beside the panel, on the map")
        self.click_flag()
        self.assertTrue(self.tasks.open)
        self.assertEqual(app.ui.panel, "country", "the click on the flag did not reach the panel")
        self.assertLessEqual(self.tasks.box.right, app.panel_rect().left, "the list opens over the map")

    def test_the_list_never_changes_the_world(self):
        app = self.start()
        self.idle_army()
        before = (quick_digest(self.world), pickle.dumps(self.world.save_state(), protocol=pickle.HIGHEST_PROTOCOL))
        self.click_flag()
        for _ in range(20):
            app.draw()
        after = (quick_digest(self.world), pickle.dumps(self.world.save_state(), protocol=pickle.HIGHEST_PROTOCOL))
        self.assertEqual(before, after)


class LineTest(FlagCase):
    """A click on a line goes to the thing it names, and the list closes; no season passes."""

    def line_index(self, kind):
        return self.kinds().index(kind)

    def test_the_fund_line_opens_the_technology_screen(self):
        app = self.start()
        self.click_flag()
        self.click_row(self.line_index("fund"))
        self.assertTrue(app.tech_open)
        self.assertFalse(self.tasks.open)
        self.assertEqual(self.world.turn, 1)

    def test_the_merchant_line_opens_the_market(self):
        app = self.start()
        self.click_flag()
        self.click_row(self.line_index("merchant"))
        self.assertEqual(app.ui.panel, "market")
        self.assertIn(app.ui.market, self.world.merchant_markets("POR"))
        self.assertFalse(self.tasks.open)

    def test_the_build_line_opens_the_province(self):
        app = self.start()
        self.click_flag()
        i = self.line_index("build")
        shown = self.tasks.lines(app)[i]
        self.click_row(i)
        self.assertEqual((app.ui.panel, app.ui.province), ("province", shown.action[1]))

    def test_the_army_line_goes_to_the_army_and_selects_it(self):
        app = self.start()
        unit = self.idle_army()
        self.click_flag()
        self.assertEqual(self.kinds()[-1], "army")
        self.click_row(len(self.tasks.rows) - 1)
        self.assertIs(app.ui.selected, unit)
        self.assertEqual(app.ui.panel, "unit")

    def test_a_click_on_the_title_strip_of_the_list_does_nothing(self):
        self.start()
        self.click_flag()
        box = self.tasks.box
        self.run_loop(3, (1, lambda: click((box.x + 4, box.y + 4))))
        self.assertTrue(self.tasks.open)
        self.assertEqual(self.world.turn, 1)


class OptionTest(FlagCase):
    def test_the_option_off_hides_the_flag(self):
        self.start(reminders=False)
        self.run_loop(3)
        self.assertIsNone(self.tasks.flag)
        self.assertIsNone(self.flag_label())
        self.run_loop(3, (1, key("space")), until=lambda: self.world.turn == 2)
        self.assertEqual(self.world.turn, 2)
        self.assertFalse(self.tasks.open)

    def test_the_options_page_has_the_task_flag_row_and_it_toggles_and_is_saved(self):
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
