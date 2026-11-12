"""The start menu through its own Menu.run() loop: the rows of each mode, option clicks, Enter / Space / Esc /
window close, and the Continue button (it shows only for a readable save and returns ``load=<slot>``).

Saves are written by hand into the temporary HEXA_HOME: the menu reads only the header line, so a header and no
world after it is enough. One test uses a save the game wrote itself. Run with:

    python -m unittest tests.ui.test_menu
"""
import json
import os
import unittest

from tests.support import harness
from tests.support.harness import click, hover, key
from tests.support.slow import slow

GOOD_HEADER = {"version": 1, "slot": "1", "saved": 1000.0, "date": "Summer 1482", "turn": 9,
               "map": "Europe 1480", "tag": "POR", "country": "Portugal", "treasury": 250}

CAMPAIGN = {"mode": "campaign", "start": "sea", "goal": "survive", "map": "europe"}

# The option buttons each mode shows, in screen order: (setting, [values]).
ROWS = {"campaign": [("mode", ["campaign", "conquest", "colony"]), ("map", ["europe", "random"])],
        "conquest": [("mode", ["campaign", "conquest", "colony"])],
        "colony": [("mode", ["campaign", "conquest", "colony"]), ("start", ["sea", "land"]),
                   ("goal", ["survive", "independence", "endless"])]}


def put_save(slot, header=None, body=b""):
    """A save file: the header (a dict as JSON, or raw bytes) on one line, then body. The menu never reads the body."""
    from hexa.campaign import saves
    os.makedirs(saves.folder(), exist_ok=True)
    if isinstance(header, bytes):
        line = header
    else:
        line = json.dumps(dict(GOOD_HEADER, slot=slot, **(header or {}))).encode("utf-8")
    with open(saves.path(slot), "wb") as f:
        f.write(line + b"\n" + body)


class MenuCase(harness.UITestCase):
    def menu(self, **settings):
        import pygame
        from hexa.menu import Menu
        from hexa.render import WINDOW_SIZE
        self.start_settings = dict(CAMPAIGN, **settings)
        self.screen = pygame.display.set_mode(WINDOW_SIZE)
        return Menu(self.screen, self.start_settings)

    def script(self, *steps):
        """One step per frame (the menu works out its buttons once per frame, so a click that changes the rows
        must come a frame before the next one). A step is an event list or a callable returning one."""
        for frame, step in enumerate(steps):
            self.driver.at(frame, step)

    def run_menu(self, menu, frames=60):
        """Run the real loop. The result of a QUIT on budget is None, so tests that expect a return check
        driver.stopped_by too."""
        self.driver.run_for(frames)
        return menu.run()

    def chosen_pixel(self, menu, rect):
        """The colour at the top edge of an option button: the gold frame is drawn only on the chosen one."""
        buttons, start = menu._layout()
        menu.draw(buttons, start)
        return tuple(self.screen.get_at((rect.centerx, rect.y)))[:3]


class RowsTest(MenuCase):
    def test_each_mode_shows_its_own_option_rows(self):
        for mode, rows in ROWS.items():
            with self.subTest(mode=mode):
                menu = self.menu(mode=mode)
                self.assertEqual([k for k, _, _ in menu._rows()], [k for k, _ in rows])
                buttons, _ = menu._layout()
                shown = [(k, [v for _, key_, v in buttons if key_ == k]) for k, _ in rows]
                self.assertEqual(shown, rows)

    def test_option_buttons_sit_in_rows_and_never_overlap(self):
        for mode in ROWS:
            with self.subTest(mode=mode):
                buttons, start = self.menu(mode=mode)._layout()
                rects = [r for r, _, _ in buttons] + [start]
                for i, rect in enumerate(rects):
                    self.assertTrue(self.screen.get_rect().contains(rect), f"{rect} is off screen")
                    for other in rects[i + 1:]:
                        self.assertFalse(rect.colliderect(other), f"{rect} overlaps {other}")

    def test_the_start_button_moves_down_with_the_number_of_rows(self):
        starts = {mode: self.menu(mode=mode)._layout()[1].y for mode in ROWS}
        self.assertLess(starts["conquest"], starts["campaign"])
        self.assertLess(starts["campaign"], starts["colony"])

    def test_the_chosen_option_is_drawn_with_a_gold_frame_and_the_others_are_not(self):
        from hexa.menu import GOLD
        menu = self.menu(mode="colony", start="land", goal="endless")
        buttons, _ = menu._layout()
        gold = {(k, v) for r, k, v in buttons if self.chosen_pixel(menu, r) == GOLD}
        self.assertEqual(gold, {("mode", "colony"), ("start", "land"), ("goal", "endless")})

    def test_the_whole_menu_draws_in_every_mode_with_the_help_texts(self):
        # draw() looks the help text up per row and setting; a mode or option it doesn't know raises KeyError.
        from hexa.menu import GOAL_HELP, MAP_HELP, START_HELP
        for settings in ([dict(mode="conquest")] + [dict(mode="campaign", map=m) for m in MAP_HELP]
                         + [dict(mode="colony", start=s, goal=g) for s in START_HELP for g in GOAL_HELP]):
            with self.subTest(**settings):
                menu = self.menu(**settings)
                menu.draw(*menu._layout())


class OptionClickTest(MenuCase):
    def test_clicking_the_modes_changes_the_mode_and_the_rows_that_come_with_it(self):
        menu = self.menu()
        rows = []                       # what the menu showed after each click (a step returning None posts nothing)
        self.script(lambda: click(harness.menu_option_rect(menu, "mode", "colony")),
                    lambda: rows.append([k for k, _, _ in menu._rows()]),
                    lambda: click(harness.menu_option_rect(menu, "mode", "conquest")),
                    lambda: rows.append([k for k, _, _ in menu._rows()]),
                    key("return"))
        result = self.run_menu(menu)
        self.assertEqual(rows, [["mode", "start", "goal"], ["mode"]])
        self.assertEqual(result, dict(CAMPAIGN, mode="conquest"))
        self.assertIsNone(self.driver.stopped_by, "Enter closed the menu before the budget ran out")

    def test_picking_start_goal_and_map_changes_exactly_those_settings(self):
        menu = self.menu(mode="colony")
        self.script(lambda: click(harness.menu_option_rect(menu, "start", "land")),
                    lambda: click(harness.menu_option_rect(menu, "goal", "independence")),
                    lambda: click(harness.menu_start_rect(menu)))
        self.assertEqual(self.run_menu(menu), {"mode": "colony", "start": "land", "goal": "independence",
                                               "map": "europe"})
        self.assertIsNone(self.driver.stopped_by)

        menu = self.menu()
        self.driver.reset()
        self.script(lambda: click(harness.menu_option_rect(menu, "map", "random")),
                    lambda: click(harness.menu_start_rect(menu)))
        self.assertEqual(self.run_menu(menu), dict(CAMPAIGN, map="random"))

    def test_the_menu_works_on_a_copy_of_the_settings_it_was_given(self):
        menu = self.menu()
        self.script(lambda: click(harness.menu_option_rect(menu, "mode", "conquest")), key("return"))
        result = self.run_menu(menu)
        self.assertEqual(result["mode"], "conquest")
        self.assertEqual(self.start_settings, CAMPAIGN, "the caller's dict is not changed")
        self.assertIsNot(result, self.start_settings)

    def test_clicking_a_row_the_mode_no_longer_shows_does_nothing(self):
        menu = self.menu()
        map_random = harness.menu_option_rect(menu, "map", "random")   # the campaign's Map row
        self.script(lambda: click(harness.menu_option_rect(menu, "mode", "conquest")),
                    lambda: click(map_random.center), key("return"))
        self.assertEqual(self.run_menu(menu), dict(CAMPAIGN, mode="conquest"), "map is still europe")

    def test_clicks_that_are_not_a_left_click_on_a_button_change_nothing(self):
        menu = self.menu()
        conquest = harness.menu_option_rect(menu, "mode", "conquest")
        start = harness.menu_start_rect(menu)
        self.script(click(conquest.center, button=3),          # right button on an option
                    click(conquest.center, button=2),          # middle button
                    click(start.center, button=3),             # right button on Start: must not start
                    click((3, 3)),                             # empty space
                    hover(conquest.center),
                    key("return"))
        self.assertEqual(self.run_menu(menu), CAMPAIGN)
        # Only Return closed the menu: the right click on Start (frame 2) did not return the settings early.
        self.assertIsNone(self.driver.stopped_by)
        self.assertGreaterEqual(self.driver.frame, 5, "the menu stayed open until the Return at frame 5")
        self.assertEqual(menu.hover, tuple(conquest.center), "the menu follows the mouse for its hover colour")

    def test_the_start_button_returns_the_settings(self):
        menu = self.menu()
        self.script(lambda: click(harness.menu_start_rect(menu)))
        self.assertEqual(self.run_menu(menu), CAMPAIGN)
        self.assertIsNone(self.driver.stopped_by)


class KeysTest(MenuCase):
    def test_enter_and_space_start_the_game(self):
        for name in ("return", "space"):
            with self.subTest(key=name):
                self.driver.reset()
                menu = self.menu(mode="conquest")
                self.script(key(name))
                self.assertEqual(self.run_menu(menu), dict(CAMPAIGN, mode="conquest"))
                self.assertIsNone(self.driver.stopped_by, f"{name} ended the menu, not the frame budget")

    def test_escape_closes_the_menu_with_none(self):
        menu = self.menu()
        self.script(key("escape"))
        self.assertIsNone(self.run_menu(menu))
        self.assertIsNone(self.driver.stopped_by, "Esc closed the menu, not the frame budget")

    def test_closing_the_window_closes_the_menu_with_none(self):
        menu = self.menu()
        self.assertIsNone(self.run_menu(menu, frames=10))
        self.assertEqual(self.driver.stopped_by, "budget", "the driver's QUIT is what ended it")
        self.assertGreaterEqual(self.driver.frame, 10)

    def test_other_keys_are_ignored(self):
        menu = self.menu()
        self.script(key("m"), key("q"), key("a"), key("tab"), key("return"))
        self.assertEqual(self.run_menu(menu), CAMPAIGN)
        self.assertGreaterEqual(self.driver.frame, 4, "the stray keys did not end the menu early")


class ContinueTest(MenuCase):
    def test_no_save_no_continue_button(self):
        menu = self.menu()
        self.assertIsNone(menu.last_save)
        self.assertIsNone(menu.last_meta)
        self.assertIsNone(harness.menu_continue_rect(menu))
        self.assertEqual(menu._layout()[1].centerx, self.screen.get_width() // 2, "Start is centred alone")

    def test_a_readable_save_shows_continue_beside_start(self):
        put_save("3")
        menu = self.menu()
        self.assertEqual(menu.last_save, "3")
        self.assertEqual(menu.last_meta["country"], "Portugal")
        resume, start = harness.menu_continue_rect(menu), harness.menu_start_rect(menu)
        self.assertIsNotNone(resume)
        self.assertEqual((resume.y, resume.right < start.x), (start.y, True), "Continue is left of Start")
        self.assertFalse(resume.colliderect(start))
        self.assertTrue(self.screen.get_rect().contains(resume))
        menu.draw(*menu._layout())                       # and it draws (country and date under the label)

    def test_continue_returns_the_newest_save_as_load_and_keeps_the_other_settings(self):
        put_save("1", {"saved": 100.0})
        put_save("5", {"saved": 300.0})
        put_save("quick", {"saved": 200.0})
        menu = self.menu(map="random")
        self.script(lambda: click(harness.menu_continue_rect(menu)))
        result = self.run_menu(menu)
        self.assertEqual(result, dict(CAMPAIGN, map="random", load="5"))
        self.assertIsNone(self.driver.stopped_by)

    def test_continue_always_opens_the_campaign_whatever_mode_is_selected(self):
        put_save("2")
        menu = self.menu()
        self.script(lambda: click(harness.menu_option_rect(menu, "mode", "colony")),
                    lambda: click(harness.menu_continue_rect(menu)))      # the rows changed: Continue moved
        result = self.run_menu(menu)
        self.assertEqual((result["mode"], result["load"]), ("campaign", "2"))
        self.assertEqual((result["start"], result["goal"]), ("sea", "survive"))

    def test_start_with_a_save_present_starts_a_new_game_without_load(self):
        put_save("1")
        menu = self.menu(mode="conquest")
        self.script(lambda: click(harness.menu_start_rect(menu)))
        result = self.run_menu(menu)
        self.assertEqual(result, dict(CAMPAIGN, mode="conquest"))
        self.assertNotIn("load", result)

    def test_the_error_of_a_failed_load_is_kept_for_the_screen_not_the_settings(self):
        put_save("1")
        message = "Slot 1 could not be loaded."
        menu = self.menu(error=message)
        self.assertEqual(menu.error, message)
        self.script(lambda: click(harness.menu_continue_rect(menu)))
        result = self.run_menu(menu)
        self.assertNotIn("error", result)
        self.assertEqual(result["load"], "1")
        self.driver.reset()
        menu.draw(*menu._layout())                       # the message is drawn under the buttons

    @slow
    def test_a_save_the_game_wrote_is_offered_with_its_country_and_date(self):
        from hexa.campaign import saves
        from tests.support import worlds
        world = worlds.random_world(7)
        saves.save(world, "4")
        menu = self.menu()
        self.assertEqual(menu.last_save, "4")
        self.assertEqual(menu.last_meta["date"], world.date())
        self.assertEqual(menu.last_meta["country"], "")           # a random world starts without a player
        self.assertIsNotNone(harness.menu_continue_rect(menu))


class BadSaveHeaderTest(MenuCase):
    """A save whose first line the game can't use is an empty slot: no Continue, no crash (#7)."""

    HEADERS = {"a number": b"1", "null": b"null", "a list": b"[1, 2]", "a string": b'"text"', "true": b"true",
               "an empty object": b"{}", "a cut-off object": b'{"version": 1, "saved": ',
               "version 0": json.dumps(dict(GOOD_HEADER, version=0)).encode(),
               "a newer version": json.dumps(dict(GOOD_HEADER, version=99)).encode(),
               "version as text": json.dumps(dict(GOOD_HEADER, version="1")).encode(),
               "binary garbage": b"\x00\xff\xfe garbage", "nothing at all": b""}

    def test_a_header_that_is_not_a_usable_header_is_no_save(self):
        for name, header in self.HEADERS.items():
            with self.subTest(header=name):
                put_save("1", header)
                menu = self.menu()                       # must not raise
                self.assertIsNone(menu.last_save)
                self.assertIsNone(harness.menu_continue_rect(menu))
                menu.draw(*menu._layout())

    def test_a_bad_header_does_not_hide_a_good_save_in_another_slot(self):
        put_save("1", b"[]")
        put_save("2", {"saved": 50.0})
        menu = self.menu()
        self.assertEqual(menu.last_save, "2")
        self.assertIsNotNone(harness.menu_continue_rect(menu))

    def test_a_header_with_the_right_version_but_no_saved_time_does_not_crash_the_menu(self):
        """New bug, no GitHub issue filed yet (the same crash as tests/test_saves.py HeaderFieldsTest, seen from
        the window): meta() accepts any object with a good ``version``, then ``latest()`` raises KeyError:
        'saved', so the start menu crashes at launch. Country and date are read the same way when it draws."""
        put_save("1", b'{"version": 1}')
        menu = self.menu()
        menu.draw(*menu._layout())


class CreditsTest(MenuCase):
    def test_the_credits_button_opens_a_box_that_esc_closes_before_it_quits(self):
        menu = self.menu()
        centre = menu._credits_rect().center
        self.script(click(centre), key("escape"), [], key("escape"))
        self.assertIsNone(self.run_menu(menu))
        self.assertIsNone(self.driver.stopped_by, "the second Esc closed the menu")
        self.assertGreaterEqual(self.driver.frame, 3, "the first Esc only closed the credits box")
        self.assertFalse(menu.credits)

    def test_the_box_names_geonames_and_kenney(self):
        from hexa.menu import CREDITS
        text = " ".join(CREDITS)
        self.assertIn("GeoNames", text)
        self.assertIn("CC BY 4.0", text)
        self.assertIn("Kenney", text)
        self.assertIn("CC0", text)
        menu = self.menu()
        menu.credits = True
        menu.draw(*menu._layout())


if __name__ == "__main__":
    unittest.main()
