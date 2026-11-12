"""Smoke tests: each window starts headless, takes real input through its own run() loop, and the game moves on.

One test per window: the start menu returns the mode that was clicked, and Conquest, Colonisation and Age of
Discovery each go from turn 1 to turn 2 after Space. Run with:

    python -m unittest tests.ui.test_smoke
"""
import unittest

from tests.support import harness


class MenuSmokeTest(harness.UITestCase):
    def test_clicking_a_mode_and_start_returns_that_mode(self):
        import pygame
        from hexa import cli
        from hexa.menu import Menu
        from hexa.render import WINDOW_SIZE

        settings, _, _, _ = cli.parse([])
        self.assertEqual(settings["mode"], "campaign", "the menu starts on the default mode")
        menu = Menu(pygame.display.set_mode(WINDOW_SIZE), settings)
        self.driver.at(0, harness.click(harness.menu_option_rect(menu, "mode", "conquest")))
        # Conquest has fewer option rows, so the Start button moves: find it when that frame comes.
        self.driver.at(1, lambda: harness.click(harness.menu_start_rect(menu)))
        self.driver.run_for(60)

        chosen = menu.run()

        self.assertIsNotNone(chosen, "the menu was closed instead of started")
        self.assertEqual(chosen["mode"], "conquest")
        self.assertIsNone(self.driver.stopped_by, "the menu returned by itself, before the frame budget ran out")


class ConquestSmokeTest(harness.UITestCase):
    def test_space_ends_the_turn_and_the_enemy_hands_it_back(self):
        import play
        from hexa.rules import PLAYER

        app = play.App(42)
        self.assertEqual((app.world.turn, app.world.current), (1, PLAYER))
        self.driver.at(0, harness.key("space"))
        # The enemy pauses AI_STEP_MS after every move the player can see; fake time makes that a few frames.
        self.driver.run_for(1500, until=lambda: app.world.turn == 2 and app.players_turn())

        self.assertEqual(app.run(), "quit")

        self.assertEqual(self.driver.stopped_by, "until", f"still on turn {app.world.turn} after 1500 frames")
        self.assertEqual((app.world.turn, app.world.current), (2, PLAYER))
        self.assertIsNone(app.world.winner)
        self.assertIsNone(app.ai_turn)


class ColonySmokeTest(harness.UITestCase):
    def test_space_lets_rivals_and_natives_play_then_it_is_turn_2(self):
        import pygame
        import play
        from hexa.colony.app import ColonyApp
        from hexa.colony.render import WINDOW_SIZE
        from hexa.colony.rules import PLAYER

        app = ColonyApp(pygame.display.set_mode(WINDOW_SIZE), play.TILES_DIR, 5, "land", "survive")
        self.assertEqual((app.world.turn, app.world.current), (1, PLAYER))
        self.assertTrue(app.world.colonies, "a land start begins with a colony")
        self.driver.at(0, harness.key("space"))
        self.driver.run_for(4000, until=lambda: app.world.turn == 2 and app.players_turn())

        self.assertEqual(app.run(), "quit")

        self.assertEqual(self.driver.stopped_by, "until", f"still on turn {app.world.turn} after 4000 frames")
        self.assertEqual((app.world.turn, app.world.current), (2, PLAYER))
        self.assertIsNone(app.world.winner)


class CampaignSmokeTest(harness.UITestCase):
    def test_space_ends_the_season(self):
        import play
        from hexa.campaign import saves
        from hexa.campaign.app import CampaignApp

        app = CampaignApp(play.TILES_DIR, "POR")
        world = app.world
        self.assertEqual((world.player, world.turn), ("POR", 1))
        self.assertEqual(app.screen.get_size(), (1280, 720), "the default window fits the 1920x1080 fake desktop")
        spring = world.date()
        self.driver.at(0, harness.key("space"))
        self.driver.run_for(30, until=lambda: world.turn == 2)

        self.assertEqual(app.run(), "quit")

        self.assertEqual(self.driver.stopped_by, "until")
        self.assertEqual(world.turn, 2)
        self.assertNotEqual(world.date(), spring)
        self.assertFalse(app.busy)
        self.assertTrue(saves.folder().startswith(self.home), "saves go to the temporary HEXA_HOME")


if __name__ == "__main__":
    unittest.main()
