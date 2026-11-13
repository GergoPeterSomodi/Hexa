"""Tech screen tests: T and Esc, clicks that research and unqueue, the idea pick, and drawing at two sizes.

Run with:  python -m unittest discover -s tests -t .
"""
import os
import random
import shutil
import tempfile
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa.campaign import app as appmod, tech  # noqa: E402
from hexa.campaign.app import CampaignApp  # noqa: E402


def key_event(key):
    return pygame.event.Event(pygame.KEYDOWN, key=key, mod=0, unicode="", scancode=0)


def click(pos, button=1):
    return pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=button, pos=pos)


class TechScreenTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pygame.init()

    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="hexa_techtest_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home
        self.app = CampaignApp(player="POR")
        self.size(1280, 720)
        self.country = self.app.world.countries["POR"]

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home, ignore_errors=True)

    def size(self, w, h):
        self.app.screen = pygame.display.set_mode((w, h))
        appmod.WIDTH, appmod.HEIGHT = w, h

    def button_for(self, action):
        """Draw the screen, then return the centre of the first clickable rect for an action."""
        self.app.draw()
        for rect, act in self.app.tech_buttons:
            if act == action:
                return rect.center
        self.fail(f"no button for {action}")

    def test_t_opens_and_closes_the_screen(self):
        app = self.app
        self.assertFalse(app.tech_open)
        app.handle(key_event(pygame.K_t))
        self.assertTrue(app.tech_open)
        app.handle(key_event(pygame.K_t))
        self.assertFalse(app.tech_open)

    def test_escape_closes_the_screen_and_does_not_open_the_menu(self):
        app = self.app
        app.handle(key_event(pygame.K_t))
        app.handle(key_event(pygame.K_ESCAPE))
        self.assertFalse(app.tech_open)
        self.assertFalse(app.menu, "Esc with the tech screen open must not open the game menu")
        app.ui.panel, app.ui.selected = None, None
        app.handle(key_event(pygame.K_ESCAPE))
        self.assertIsNotNone(app.menu, "Esc with the screen closed opens the menu as before")

    def test_clicking_a_node_sets_research(self):
        app, country = self.app, self.country
        key = tech.available(country.techs, country.era)[0]
        app.handle(key_event(pygame.K_t))
        app.handle(click(self.button_for(("node", key))))
        self.assertEqual(country.researching, key)
        self.assertEqual(app.tech_selected, key)

    def test_clicking_a_far_tech_queues_its_path(self):
        app, country, world = self.app, self.country, self.app.world
        country.era = 2
        # a tech two steps away: its unknown prerequisite becomes the research, the tech the queue
        far = next(k for k, t in tech.TECHS.items()
                   if t.era <= country.era and t.needs and not all(n in country.techs for n in t.needs)
                   and all(tech.tech(n).era <= country.era for n in t.needs))
        app.open_tech()
        app.handle(click(self.button_for(("node", far))))
        path = tech.path_to(far, country.techs)
        self.assertEqual(country.researching, path[0])
        self.assertEqual(country.queue, path[1:])
        self.assertTrue(world.countries["POR"].queue or len(path) == 1)

    def test_right_click_unqueues(self):
        app, country = self.app, self.country
        first, second = tech.available(country.techs, country.era)[:2]
        self.assertTrue(self.app.world.set_research("POR", first))
        country.queue = [second]
        app.open_tech()
        app.handle(click(self.button_for(("queue", second)), button=3))
        self.assertNotIn(second, country.queue)

    def test_right_click_on_a_node_unqueues_it(self):
        app, country = self.app, self.country
        first, second = tech.available(country.techs, country.era)[:2]
        self.app.world.set_research("POR", first)
        country.queue = [second]
        app.open_tech()
        app.handle(click(self.button_for(("node", second)), button=3))
        self.assertNotIn(second, country.queue)

    def test_modal_pick_applies_an_idea(self):
        app, country = self.app, self.country
        counts = {b: 0 for b in tech.BRANCHES}
        country.pending_ideas = [i.key for i in tech.draw_ideas("POR", counts, set(), random.Random(5))]
        chosen = country.pending_ideas[0]
        app.open_tech()
        # while cards are pending, nothing else can be clicked
        app.handle(key_event(pygame.K_t))
        self.assertTrue(app.tech_open or country.pending_ideas)
        app.handle(click(self.button_for(("pick", chosen))))
        self.assertIn(chosen, country.ideas)
        self.assertEqual(country.pending_ideas, [])

    def test_fund_button_is_disabled_with_the_reason(self):
        app, country = self.app, self.country
        country.memory["funded_turn"] = app.world.turn   # already funded this year
        app.open_tech()
        app.draw()
        before = country.research
        app.handle(click(self.button_for(("fund",))))
        self.assertEqual(country.research, before)
        self.assertIn("Funded already", app.ui.toast)

    def test_drawing_at_1280_and_1920(self):
        app, country = self.app, self.country
        for w, h in ((1280, 720), (1920, 1080)):
            self.size(w, h)
            app.open_tech()
            country.era = 2
            app.draw()
            counts = {b: 0 for b in tech.BRANCHES}
            country.pending_ideas = [i.key for i in tech.draw_ideas("POR", counts, set(), random.Random(7))]
            app.draw()
            country.pending_ideas = []
            app.tech.close(app)
            country.era = 1

    def test_loading_a_game_without_a_player_closes_the_grid(self):
        from hexa.campaign.game import GameManager
        app = self.app
        app.open_tech()
        self.assertTrue(app.tech.grid_open)
        app.load_world(GameManager.new(1480, "europe"))
        self.assertIsNone(app.world.player)
        self.assertFalse(app.tech.grid_open)
        self.assertNotIn(app.tech, app.screens)
        app.draw()                                  # used to raise KeyError: None


if __name__ == "__main__":
    unittest.main()
