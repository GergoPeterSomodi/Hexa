"""Golden screenshots: fixed-seed frames of every window compared with reviewed pictures in tests/golden/linux/.

Each scene opens a window the way the launcher does, plays a short script through the window's own run() loop
(fake time, the bundled font, clicks that don't move the mouse unless the scene hovers on purpose), then draws it
with the clock stopped until the frame stops changing (the campaign's tile art is made a few tiles a frame; the
time limit on the landscape art of the close zooms is lifted) and compares that frame with its golden
(tests/support/golden.py):

    menu_campaign          the start menu on Age of Discovery: Random world picked, Continue (a save), a load error
    menu_conquest          the start menu on Conquest (one row)
    menu_colony            the start menu on Colonisation: a land start, for independence
    conquest_town          map #42, your castle selected: its train buttons and income
    conquest_turn2         map #42 after Space and the enemy's turn: turn 2, your soldier selected with its reach
    colony_sea_start       map #5, a sea start: the ship with its four passengers
    colony_land_colony     map #5, a land start for independence: your colony selected, its job buttons
    campaign_chooser       Europe 1480 before choosing a country: the flat map at zoom 1 and the banner
    campaign_por           Portugal at the start: tile art at zoom 4 around Lisbon, the country panel
    campaign_por_unit      Portugal, Tab: a unit selected, its reach, the route to a hex under the mouse, its card
    campaign_por_province  Portugal, terrain map (2), a province clicked: its panel and its hover card
    campaign_por_goods     Portugal zoomed out to 1, the goods map (3), your home market's panel
    campaign_pause         Portugal after one season (the other countries moved), the pause menu
    campaign_options       the pause menu's options page
    campaign_random7       random world #7 before choosing a country, zoomed out to 0: the whole map

The goldens are made on Linux, CI's reference; elsewhere these tests skip (golden.py says when, and the docker
one-liner in README.md runs them as CI does). RepeatTest needs no golden, so it runs everywhere: it draws two
scenes twice in one process and checks that the frames are the same bytes. Run with:

    python -m unittest tests.ui.test_screenshots
    UPDATE_GOLDEN=1 python -m unittest tests.ui.test_screenshots        # make the goldens (Linux only)
"""
import hashlib
import json
import os
import sys
import unittest
from unittest import mock

from tests.support import golden, harness
from tests.support.harness import click, hex_pixel, hover, key

CONQUEST_SEED = 42
COLONY_SEED = 5
RANDOM_SEED = 7
CASTLE = (1, 6)           # map #42: your castle, your soldier in it
COLONY = (24, 10)         # map #5, land start: your colony, your soldier in it
SETTLE_DRAWS = 60         # draws with the clock stopped, after which a frame must have stopped changing
CARD_FRAMES = 40          # frames to run when a hover card should show: it waits 350 ms, 22 frames


def tearDownModule():
    text = golden.summary()
    if text:
        print("\n" + text, file=sys.stderr)


class ScreenCase(harness.UITestCase):
    """The scenes: scene_<name>() builds its window, plays its script and returns the settled frame (the window's
    surface). The window is self.app (self.menu for the start menu)."""

    def settle(self, draw, screen):
        """Draw with the clock stopped until two frames in a row are the same; return the screen."""
        import pygame
        previous = None
        for _ in range(SETTLE_DRAWS):
            draw()
            frame = hashlib.sha256(pygame.image.tobytes(screen, "RGB")).digest()
            if frame == previous:
                return screen
            previous = frame
        self.fail(f"the frame still changes after {SETTLE_DRAWS} draws with the clock stopped")

    def script(self, steps, start=0):
        """One step a frame from frame start; a step is an event list or a callable returning one."""
        for frame, step in enumerate(steps, start=start):
            self.driver.at(frame, step)

    def on_hex(self, pos):
        """A click on map hex pos, where it is when its frame comes, without moving the mouse there."""
        return lambda: click(hex_pixel(self.app, pos), move=False)

    # ----- the start menu ------------------------------------------------------------------------------------
    def menu_scene(self, *options, settings=None):
        """The start menu with the launcher's defaults (updated with settings), then a click on each (setting,
        value) option button, one a frame: a click can change the rows below it."""
        import pygame
        from hexa import cli
        from hexa.menu import Menu
        from hexa.render import WINDOW_SIZE
        chosen, _, _, _ = cli.parse([])
        screen = pygame.display.set_mode(WINDOW_SIZE)
        self.menu = menu = Menu(screen, dict(chosen, **(settings or {})))
        self.script([lambda o=o: click(harness.menu_option_rect(menu, *o).center, move=False) for o in options])
        self.driver.run_for(len(options) + 2)
        self.assertIsNone(menu.run(), "the menu was started instead of staying open")
        # The footer shows hexa.menu.__version__: pin it, so that a release does not change the three menu goldens.
        with mock.patch("hexa.menu.__version__", "0.0.0"):
            return self.settle(lambda: menu.draw(*menu._layout()), screen)

    def scene_menu_campaign(self):
        from hexa.campaign import saves
        os.makedirs(saves.folder(), exist_ok=True)
        header = {"version": saves.VERSION, "slot": "1", "saved": 1000.0, "date": "Summer 1482", "turn": 10,
                  "map": "Europe 1480", "tag": "POR", "country": "Portugal", "treasury": 250}
        with open(saves.path("1"), "wb") as f:         # the menu reads only the header line
            f.write(json.dumps(header).encode("utf-8") + b"\n")
        error = f"{saves.slot_name('1')} could not be loaded."      # what play.main shows after a LoadError
        screen = self.menu_scene(("map", "random"), settings={"error": error})
        self.assertEqual((self.menu.settings["map"], self.menu.last_meta["country"]), ("random", "Portugal"))
        return screen

    def scene_menu_conquest(self):
        screen = self.menu_scene(("mode", "conquest"))
        self.assertEqual(self.menu.settings["mode"], "conquest")
        return screen

    def scene_menu_colony(self):
        screen = self.menu_scene(("mode", "colony"), ("start", "land"), ("goal", "independence"))
        self.assertEqual({k: self.menu.settings[k] for k in ("mode", "start", "goal")},
                         {"mode": "colony", "start": "land", "goal": "independence"})
        return screen

    # ----- Conquest and Colonisation -------------------------------------------------------------------------
    def conquest_scene(self, steps, frames=None, until=None):
        import play
        self.app = app = play.App(CONQUEST_SEED)
        self.script(steps)
        self.driver.run_for(frames or len(steps) + 2, until)
        self.assertEqual(app.run(), "quit")
        return self.settle(lambda: app.renderer.draw(app.world, app.ui), app.screen)

    def scene_conquest_town(self):
        # the first click selects the soldier in the castle, the second the castle itself
        screen = self.conquest_scene([self.on_hex(CASTLE), self.on_hex(CASTLE)])
        self.assertIsNotNone(self.app.ui.town, "the castle is selected")
        return screen

    def scene_conquest_turn2(self):
        screen = self.conquest_scene([key("space")], frames=1500,
                                     until=lambda: self.app.world.turn == 2 and self.app.players_turn())
        self.assertEqual(self.driver.stopped_by, "until", f"still on turn {self.app.world.turn} after 1500 frames")
        self.assertIsNotNone(self.app.ui.selected, "the next unit is selected")
        return screen

    def colony_scene(self, start, goal, steps):
        import pygame
        import play
        from hexa.colony.app import ColonyApp
        from hexa.colony.render import WINDOW_SIZE
        self.app = app = ColonyApp(pygame.display.set_mode(WINDOW_SIZE), play.TILES_DIR, COLONY_SEED, start, goal)
        self.script(steps)
        self.driver.run_for(len(steps) + 2)
        self.assertEqual(app.run(), "quit")
        return self.settle(lambda: app.renderer.draw(app.world, app.ui, app.camera), app.screen)

    def scene_colony_sea_start(self):
        screen = self.colony_scene("sea", "survive", [])
        self.assertEqual(len(self.app.world.cargo(self.app.ui.selected)), 4, "the ship and its passengers")
        return screen

    def scene_colony_land_colony(self):
        # the first click selects the soldier in the colony, the second the colony itself
        screen = self.colony_scene("land", "independence", [self.on_hex(COLONY), self.on_hex(COLONY)])
        self.assertIsNotNone(self.app.ui.colony, "the colony is selected")
        return screen

    # ----- Age of Discovery ------------------------------------------------------------------------------------
    def campaign_scene(self, steps, tag="POR", map="europe", seed=None, frames=None):
        """The campaign window as the launcher opens it; the steps start at frame 1, after a first frame is drawn
        (the buttons and the pause menu are laid out when drawn)."""
        import play
        from hexa.campaign import mapview
        from hexa.campaign.app import CampaignApp
        # The landscape art is made a few hexes a frame, as many as LAND_BUILD_MS of real time allows, so a slow
        # machine could settle on a frame with hexes still missing: lift the limit, every frame draws them all.
        patcher = mock.patch.object(mapview, "LAND_BUILD_MS", 1e9)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.app = app = CampaignApp(play.TILES_DIR, tag, map, seed)
        self.script(steps, start=1)
        self.driver.run_for(frames or len(steps) + 3)
        self.assertEqual(app.run(), "quit")
        return self.settle(app.draw, app.screen)

    def on_map(self, pixel):
        """Whether pixel is on the visible map: not on a button, the open panel or the minimap."""
        app = self.app
        return (app.view_rect().collidepoint(pixel) and not app.minimap_rect().collidepoint(pixel)
                and not (app.ui.panel and app.panel_rect().collidepoint(pixel))
                and not any(b.rect.collidepoint(pixel) for b in app.ui.buttons))

    def on_button(self, label=None, action=None):
        """A click on one of the campaign's buttons, as drawn on the last frame, without moving the mouse."""
        return lambda: click(harness.button_rect(self.app, label, action).center, move=False)

    def scene_campaign_chooser(self):
        screen = self.campaign_scene([], tag=None)
        self.assertEqual((self.app.player, self.app.view.zoom), (None, 1))
        return screen

    def scene_campaign_por(self):
        screen = self.campaign_scene([])
        self.assertEqual((self.app.view.zoom, self.app.ui.panel), (4, "country"))
        return screen

    def scene_campaign_por_unit(self):
        def point_at_reach():
            app = self.app
            reach = [(cost, pos) for pos, cost in app.ui.reach.items() if self.on_map(hex_pixel(app, pos))]
            return hover(hex_pixel(app, max(reach)[1]))        # the farthest hex in reach on screen
        screen = self.campaign_scene([key("tab"), point_at_reach], frames=CARD_FRAMES)
        ui = self.app.ui
        self.assertEqual(ui.panel, "unit")
        self.assertTrue(ui.reach and ui.path, "the reach and the route to the hex under the mouse are shown")
        return screen

    def scene_campaign_por_province(self):
        def click_province():
            app = self.app
            world = app.world
            for prov in sorted(world.provinces.values(), key=lambda p: p.pos):
                pixel = hex_pixel(app, prov.pos)
                if (prov.owner == "POR" and not world.units_at(prov.pos) and self.on_map(pixel)
                        and not app.panel_rect().collidepoint(pixel)):      # nor where its panel will open
                    return click(pixel)                    # the mouse stays there: the card shows
            raise AssertionError("no free Portuguese province on screen")
        screen = self.campaign_scene([key("2") + key("escape"), click_province], frames=CARD_FRAMES)
        self.assertEqual((self.app.view.mode, self.app.ui.panel), ("terrain", "province"))
        return screen

    def scene_campaign_por_goods(self):
        screen = self.campaign_scene([key("-") * 3, key("3"), self.on_button("Market", ("panel", "market"))])
        self.assertEqual((self.app.view.zoom, self.app.view.mode, self.app.ui.panel), (1, "goods", "market"))
        return screen

    def scene_campaign_pause(self):
        # Space: a season; Esc closes Portugal's panel, the next Esc opens the menu
        screen = self.campaign_scene([key("space"), key("escape"), key("escape")])
        self.assertEqual((self.app.world.turn, self.app.menu), (2, "main"))
        return screen

    def scene_campaign_options(self):
        def options():
            return click(harness.pause_button_rect(self.app, ("page", "options")).center, move=False)
        screen = self.campaign_scene([key("m"), options])
        self.assertEqual(self.app.menu, "options")
        return screen

    def scene_campaign_random7(self):
        screen = self.campaign_scene([key("-")], tag=None, map="random", seed=RANDOM_SEED)
        self.assertEqual((self.app.world.geo.name == "Europe 1480", self.app.view.zoom), (False, 0))
        return screen


class GoldenCase(ScreenCase):
    """Skipped where the goldens weren't made (golden.require_environment), before any window is built."""

    def setUp(self):
        harness.install().reset()            # pygame up, so the environment can be read
        golden.require_environment(self)
        super().setUp()

    def check(self, name, max_pixels=0):
        golden.check(self, name, getattr(self, f"scene_{name}")(), max_pixels)


class MenuScreens(GoldenCase):
    def test_menu_campaign(self):
        self.check("menu_campaign")

    def test_menu_conquest(self):
        self.check("menu_conquest")

    def test_menu_colony(self):
        self.check("menu_colony")


class ConquestScreens(GoldenCase):
    def test_conquest_town(self):
        self.check("conquest_town")

    def test_conquest_turn2(self):
        self.check("conquest_turn2")


class ColonyScreens(GoldenCase):
    def test_colony_sea_start(self):
        self.check("colony_sea_start")

    def test_colony_land_colony(self):
        self.check("colony_land_colony")


class CampaignScreens(GoldenCase):
    def test_campaign_chooser(self):
        self.check("campaign_chooser")

    def test_campaign_por(self):
        self.check("campaign_por")

    def test_campaign_por_unit(self):
        self.check("campaign_por_unit")

    def test_campaign_por_province(self):
        self.check("campaign_por_province")

    def test_campaign_por_goods(self):
        self.check("campaign_por_goods")

    def test_campaign_pause(self):
        self.check("campaign_pause")

    def test_campaign_options(self):
        self.check("campaign_options")

    def test_campaign_random7(self):
        self.check("campaign_random7")


class RepeatTest(ScreenCase):
    """A scene drawn twice in one process gives the same bytes. The second window of a kind starts from warm caches
    (the campaign world's snapshot, loaded sprites, a settled event queue); the first may not have."""

    def frame_hash(self, name):
        import pygame
        self.driver.reset()
        return hashlib.sha256(pygame.image.tobytes(getattr(self, f"scene_{name}")(), "RGB")).hexdigest()

    def test_a_scene_drawn_twice_is_the_same(self):
        for name in ("conquest_turn2", "campaign_por_unit"):
            with self.subTest(scene=name):
                self.assertEqual(self.frame_hash(name), self.frame_hash(name))


if __name__ == "__main__":
    unittest.main()
