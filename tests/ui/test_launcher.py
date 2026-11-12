"""play.main(), the launcher loop: command line -> menu or straight into a mode -> M back to the menu -> Esc quits.

main() runs for real, with the harness's fake time. The menu and the three window classes are wrapped in
subclasses that only record what ran and what each run() returned, so a test can say which windows opened, in
which order, and how each one ended. Run with:

    python -m unittest tests.ui.test_launcher
"""
import contextlib
import io
import os
import sys
import unittest
from unittest import mock

from tests.support import harness
from tests.support.harness import click, key
from tests.support.slow import slow


class LauncherCase(harness.UITestCase):
    def setUp(self):
        super().setUp()
        import play
        self.play = play
        self.opened = []                          # (name, instance), in the order the windows were opened
        self.results = {}                         # instance -> what its run() returned
        self.frames = {}                          # instance -> the driver's frame when its run() began
        self.attempts = []                        # (name, args, kwargs) of every window the launcher tried to open
        for name in ("App", "Menu", "ColonyApp", "CampaignApp"):
            patcher = mock.patch.object(play, name, self.recording(name, getattr(play, name)))
            patcher.start()
            self.addCleanup(patcher.stop)

    def recording(self, name, real):
        case = self

        class Recorded(real):
            def __init__(self, *args, **kwargs):
                case.attempts.append((name, args, kwargs))
                super().__init__(*args, **kwargs)
                case.opened.append((name, self))

            def run(self):
                case.frames[self] = case.driver.frame
                result = super().run()
                case.results[self] = result
                return result

        Recorded.__name__ = name
        return Recorded

    def launch(self, *argv, frames=600):
        """sys.argv = play.py + argv; main() under a frame budget. Returns what it printed on stderr."""
        self.driver.run_for(frames)
        err = io.StringIO()
        with mock.patch.object(sys, "argv", ["play.py", *argv]), contextlib.redirect_stderr(err):
            self.assertIsNone(self.play.main())
        return err.getvalue()

    def names(self):
        return [name for name, _ in self.opened]

    def instance(self, name):
        found = [window for n, window in self.opened if n == name]
        self.assertEqual(len(found), 1, f"expected one {name}, opened: {self.names()}")
        return found[0]


class ConquestLauncherTest(LauncherCase):
    def test_m_goes_back_to_the_menu_and_escape_there_quits(self):
        self.driver.at(3, key("m"))                 # in the game
        self.driver.at(8, key("escape"))            # in the menu
        self.launch("--mode", "conquest", "--seed", "42")

        self.assertEqual(self.names(), ["App", "Menu"], "the game first, because --mode skips the menu")
        app, menu = self.instance("App"), self.instance("Menu")
        self.assertEqual(app.world.seed, 42)
        self.assertEqual(self.results[app], "menu")
        self.assertIsNone(self.results[menu], "Esc closes the menu with None")
        self.assertGreaterEqual(self.frames[menu], 3, "the menu opened after M, not before")
        self.assertLess(self.frames[menu], 8)
        self.assertIsNone(self.driver.stopped_by, "main() returned by itself, before the frame budget")
        self.assertEqual(menu.settings["mode"], "conquest", "the menu starts on the mode that was just played")

    def test_escape_in_the_game_quits_without_showing_the_menu(self):
        self.driver.at(3, key("escape"))
        self.launch("--mode", "conquest", "--seed", "42")

        self.assertEqual(self.names(), ["App"])
        self.assertEqual(self.results[self.instance("App")], "quit")
        self.assertIsNone(self.driver.stopped_by)

    def test_closing_the_window_quits_from_the_game_and_from_the_menu(self):
        self.launch("--mode", "conquest", "--seed", "42", frames=20)      # the driver's QUIT closes the game
        self.assertEqual((self.names(), self.driver.stopped_by), (["App"], "budget"))
        self.assertEqual(self.results[self.instance("App")], "quit")

        self.opened.clear()
        self.results.clear()
        self.driver.reset()
        self.driver.at(2, key("m"))
        self.launch("--mode", "conquest", "--seed", "42", frames=30)      # ... and the menu
        self.assertEqual(self.names(), ["App", "Menu"])
        self.assertIsNone(self.results[self.instance("Menu")])
        self.assertEqual(self.driver.stopped_by, "budget")

    def test_a_game_started_from_the_menu_uses_the_menus_settings_and_the_seed(self):
        self.driver.at(2, key("m"))
        # The menu is open from frame 2: pick Colonisation, "land", then Start, one click a frame.
        menu_of = lambda: self.opened[-1][1]            # noqa: E731 - the menu that opened last
        self.driver.at(4, lambda: click(harness.menu_option_rect(menu_of(), "mode", "colony")))
        self.driver.at(5, lambda: click(harness.menu_option_rect(menu_of(), "start", "land")))
        self.driver.at(6, lambda: click(harness.menu_start_rect(menu_of())))
        self.driver.at(20, key("escape"))                # in Colonisation the first Esc deselects the unit ...
        self.driver.at(22, key("escape"))                # ... and the second quits
        self.launch("--mode", "conquest", "--seed", "42")

        self.assertEqual(self.names(), ["App", "Menu", "ColonyApp"])
        colony = self.instance("ColonyApp")
        self.assertEqual((colony.world.seed, colony.world.start, colony.world.goal), (42, "land", "survive"))
        self.assertEqual(self.results[colony], "quit")
        self.assertEqual(self.results[self.instance("Menu")]["mode"], "colony")
        self.assertIsNone(self.driver.stopped_by)

    def test_the_menu_comes_first_without_mode_and_esc_quits_before_any_game(self):
        self.driver.at(2, key("escape"))
        self.launch()
        self.assertEqual(self.names(), ["Menu"])
        self.assertIsNone(self.results[self.instance("Menu")])
        self.assertEqual(self.instance("Menu").settings["mode"], "campaign", "the default mode")
        self.assertIsNone(self.driver.stopped_by)

    def test_main_writes_nothing_outside_the_temporary_home_and_closes_pygame(self):
        import pygame
        self.driver.at(2, key("m"))
        self.driver.at(5, key("escape"))
        self.launch("--mode", "conquest", "--seed", "42")
        self.assertFalse(pygame.get_init(), "main() ends with pygame.quit()")
        self.assertEqual(os.listdir(self.home), [], "Conquest and the menu save nothing")


class CampaignLauncherTest(LauncherCase):
    def test_nation_by_tag_or_name_in_any_case_starts_as_that_country(self):
        for nation, tag in (("POR", "POR"), ("por", "POR"), ("Venice", "VEN")):
            with self.subTest(nation=nation):
                self.opened.clear()
                self.driver.reset()
                err = self.launch("--mode", "campaign", "--nation", nation, frames=5)
                app = self.instance("CampaignApp")
                self.assertEqual(app.world.player, tag)
                self.assertEqual(self.results[app], "quit")
                self.assertEqual(err, "", "a known country prints nothing")

    def test_an_unknown_nation_does_not_crash_and_falls_back_to_the_country_chooser(self):
        """#11, fixed: --nation XYZ used to crash. Now the campaign opens with no country chosen (the chooser
        banner and 'Play as' buttons), tells the player in a toast, and lists the countries on stderr."""
        err = self.launch("--mode", "campaign", "--nation", "XYZ", frames=8)

        self.assertEqual(self.names(), ["CampaignApp"], "no menu: --mode skipped it")
        app = self.instance("CampaignApp")
        self.assertIsNone(app.world.player, "no country chosen: the chooser is showing")
        self.assertIn("There is no country 'XYZ'", app.ui.toast)
        self.assertTrue(err.startswith("--nation XYZ: no such country on Europe 1480. Countries: "), err[:80])
        self.assertIn("POR (Portugal)", err)
        self.assertEqual(self.results[app], "quit")
        self.assertEqual(self.driver.stopped_by, "budget")
        self.assertFalse(app.busy)

    def test_a_settings_file_that_is_not_an_object_does_not_stop_the_campaign_starting(self):
        """#7: the reader of settings.json is the campaign window (hexa/settings.py), not the menu."""
        from hexa import settings
        with open(os.path.join(self.home, "settings.json"), "w") as f:
            f.write("[1, 2]")
        self.launch("--mode", "campaign", "--nation", "POR", frames=5)
        app = self.instance("CampaignApp")
        self.assertEqual(app.settings, settings.DEFAULTS)
        self.assertEqual(app.world.player, "POR")
        self.assertEqual(self.results[app], "quit")

    def test_nation_is_for_the_command_line_only_the_menu_started_campaign_chooses_in_game(self):
        # With a menu (no --mode) the nation is not passed on: the campaign opens on the chooser. This pins what
        # main() does today ("--nation without --mode is ignored"); it is not a rule the docs state.
        self.driver.at(2, lambda: click(harness.menu_start_rect(self.opened[-1][1])))
        err = self.launch("--nation", "POR", frames=10)
        self.assertEqual(self.names(), ["Menu", "CampaignApp"])
        self.assertIsNone(self.instance("CampaignApp").world.player)
        self.assertEqual(err, "")


class ContinueLauncherTest(LauncherCase):
    def test_a_save_that_cannot_be_loaded_returns_to_the_menu_with_the_reason(self):
        from hexa.campaign import saves
        from tests.ui.test_menu import put_save
        put_save("1", body=b"garbage after a good header")
        self.driver.at(2, lambda: click(harness.menu_continue_rect(self.opened[-1][1])))
        self.driver.at(6, key("escape"))              # the second menu
        err = self.launch(frames=30)

        self.assertEqual(self.names(), ["Menu", "Menu"], "no campaign window opened, back to the menu")
        first, second = (window for _, window in self.opened)
        tried = [(n, kw.get("load")) for n, _, kw in self.attempts if n == "CampaignApp"]
        self.assertEqual(tried, [("CampaignApp", "1")], "the launcher tried to load slot 1 once")
        self.assertEqual(self.results[first]["mode"], "campaign")
        self.assertEqual(second.error, "Slot 1 could not be loaded.")
        self.assertIsNone(self.results[second])
        self.assertTrue(second.last_save, "the broken save is still offered")
        self.assertIn("Could not load save '1'", err)
        self.assertIsNone(self.driver.stopped_by)
        self.assertEqual(os.listdir(saves.folder()), ["1.sav"])

    @slow
    def test_continue_opens_the_saved_game(self):
        from hexa.campaign import saves
        from tests.support import worlds
        world = worlds.random_world(7)
        saves.save(world, "2")
        self.driver.at(2, lambda: click(harness.menu_continue_rect(self.opened[-1][1])))
        self.launch(frames=8)

        self.assertEqual(self.names(), ["Menu", "CampaignApp"])
        app = self.instance("CampaignApp")
        self.assertEqual(app.world.geo.name, world.geo.name)
        self.assertEqual(app.world.turn, world.turn)
        self.assertIn("Loaded Slot 2", app.ui.toast)
        self.assertEqual(self.results[app], "quit")


if __name__ == "__main__":
    unittest.main()
