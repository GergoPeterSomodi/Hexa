"""Milestone v0.1.5 ("UI and controls"): issues #16, #17, #18, #19, #22 and #24 of the Age of Discovery window.

Headless: a dummy video driver and a temporary HEXA_HOME. Run with:  python -m unittest tests.test_uifixes
"""
import os
import shutil
import tempfile
import unittest
from unittest import mock

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa.campaign import app as appmod, saves  # noqa: E402
from hexa.campaign.app import CampaignApp  # noqa: E402
from hexa.campaign.data import troop  # noqa: E402
from tests.test_playtest import front, place  # noqa: E402

ESC = pygame.K_ESCAPE


def key(k):
    return pygame.event.Event(pygame.KEYDOWN, key=k, mod=0, unicode="", scancode=0)


def right_button(kind, pos=(400, 300)):
    return pygame.event.Event(kind, button=3, pos=pos)


class AppTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pygame.init()

    def setUp(self):
        self.home_dir = tempfile.mkdtemp(prefix="hexa_uifix_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home_dir
        self.old_size = (appmod.WIDTH, appmod.HEIGHT)
        self.app = CampaignApp(player="POR")

    def tearDown(self):
        appmod.WIDTH, appmod.HEIGHT = self.old_size
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home_dir, ignore_errors=True)


class RightClickMenuTest(AppTest):
    """#16: the right-button press that closes the pause menu must not turn into an order on release."""

    def test_the_release_after_a_menu_closing_right_click_gives_no_order(self):
        app = self.app
        app.open_menu()
        with mock.patch.object(app, "right_click") as right_click:
            app.handle(right_button(pygame.MOUSEBUTTONDOWN))
            app.handle(right_button(pygame.MOUSEBUTTONUP))
        self.assertIsNone(app.menu)
        right_click.assert_not_called()

    def test_a_right_click_on_the_map_still_gives_an_order(self):
        app = self.app
        with mock.patch.object(app, "right_click") as right_click:
            app.handle(right_button(pygame.MOUSEBUTTONDOWN))
            app.handle(right_button(pygame.MOUSEBUTTONUP))
        right_click.assert_called_once()


class LoadConfirmTest(AppTest):
    """#17: loading a slot replaces the world, so it asks for a second click like Main menu does."""

    def setUp(self):
        super().setUp()
        self.original = self.app.world
        saves.save(self.original, "1")

    def test_the_first_click_on_a_slot_only_asks(self):
        app = self.app
        app.open_menu("load")
        app.menu_press(("load", "1"))
        self.assertIs(app.world, self.original)
        self.assertEqual(app.menu_confirm, ("load", "1"))
        self.assertEqual(app.menu, "load")

    def test_the_second_click_loads_the_slot(self):
        app = self.app
        app.open_menu("load")
        app.menu_press(("load", "1"))
        app.menu_press(("load", "1"))
        self.assertIsNot(app.world, self.original)
        self.assertIsNone(app.menu)

    def test_nothing_to_lose_means_no_question(self):
        app = self.app
        app.world.over = True
        app.open_menu("load")
        app.menu_press(("load", "1"))
        self.assertIsNot(app.world, self.original)

    def test_f9_asks_once_then_loads_the_quicksave(self):
        app = self.app
        saves.save(self.original, "quick")
        app.handle(key(pygame.K_F9))
        self.assertIs(app.world, self.original)
        self.assertIn("Press F9 again", app.ui.toast)
        app.handle(key(pygame.K_F9))
        self.assertIsNot(app.world, self.original)


class EscapeTest(AppTest):
    """#19: the first Esc clears the selected stack, the next one opens the pause menu."""

    def test_escape_clears_the_stack_then_opens_the_menu(self):
        app, w = self.app, self.app.world
        home = w.provinces_of("POR")[0].pos
        unit = place(w, troop("infantry", 1), "POR", home)
        app.select_unit(unit)
        self.assertIs(app.ui.selected, unit)
        app.handle(key(ESC))
        self.assertIsNone(app.ui.selected)
        self.assertEqual(app.ui.group, [])
        self.assertIsNone(app.menu)
        app.handle(key(ESC))
        self.assertEqual(app.menu, "main")


class StackOrderTest(AppTest):
    """#22: a manual order for the stack (attack, found, forage) cancels the stack's multi-season move order."""

    def setUp(self):
        super().setUp()
        self.w = self.app.world
        self.w.declare_war("POR", "CAS")
        self.target, self.home = front(self.w)
        self.far = next(p for p in self.w.terrain if self.w.is_land(p) and p not in (self.home, self.target.pos))

    def stack(self, unit):
        app = self.app
        app.ui.group, app.ui.picked, app.ui.selected = [unit], {unit.id}, unit
        app.refresh()
        return app

    def test_an_attack_cancels_the_move_order(self):
        app, w = self.app, self.w
        place(w, troop("infantry", 1), "CAS", self.target.pos)
        knight = place(w, troop("cavalry", 1), "POR", self.home)
        knight.goal = self.far
        app = self.stack(knight)
        app.ui.attacks = w.attack_options_group(app.active())
        self.assertIn(self.target.pos, app.ui.attacks)
        app.hex_under = lambda pixel: self.target.pos
        app.right_click((0, 0))
        self.assertIn(knight, w.units, "the test needs the attacker to survive the battle")
        self.assertIsNone(knight.goal)

    def test_foraging_cancels_the_move_order(self):
        w = self.w
        knight = place(w, troop("cavalry", 1), "POR", self.target.pos)
        knight.goal = self.far
        app = self.stack(knight)
        app.press(("forage",))
        self.assertEqual(knight.moves_left, 0, "the forage went through")
        self.assertIsNone(knight.goal)


class ClosePanelTest(AppTest):
    """#24: the close (x) button of a panel closes it, rather than re-opening the country or market."""

    def click_close(self):
        app = self.app
        app.draw()
        close = next(b for b in app.ui.buttons if b.label == "×")
        app.left_click(close.rect.center)

    def test_close_hides_a_foreign_country_panel(self):
        self.app.open_country("CAS")
        self.click_close()
        self.assertIsNone(self.app.ui.panel)

    def test_close_hides_the_market_panel(self):
        app, w = self.app, self.app.world
        w.ensure_markets()
        cap = w.provinces[w.countries["CAS"].capital]
        app.press(("market", cap.market))
        self.assertEqual(app.ui.panel, "market")
        self.click_close()
        self.assertIsNone(app.ui.panel)


class TopBarTest(AppTest):
    """#18: on narrow windows the End season and Menu buttons must not overlap."""

    # The headless fallback font is narrower than the Segoe UI of the playtest machine, where the bar is wider:
    # at size 16 and up the old End button sat on top of Menu (Menu 903-967, End 950-1014 at 1024 px).
    SIZES = (15, 16, 17, 18)

    def set_font(self, size):
        self.app.small = pygame.font.SysFont("segoeui,arial", size - 3)
        self.app.bold = pygame.font.SysFont("segoeui,arial", size, bold=True)

    def layout(self, width, height):
        app = self.app
        appmod.WIDTH, appmod.HEIGHT = width, height
        app.screen = pygame.display.set_mode((width, height))
        app.draw()
        return [b for b in app.ui.buttons if b.rect.y < appmod.TOP]

    def assert_no_overlap(self, bars, width):
        for i, a in enumerate(bars):
            self.assertLessEqual(a.rect.right, width, f"{a.label} runs off the window")
            for b in bars[i + 1:]:
                self.assertFalse(a.rect.colliderect(b.rect), f"{a.label} overlaps {b.label}")

    def test_no_top_bar_buttons_overlap_at_1024(self):
        for size in self.SIZES:
            with self.subTest(font=size):
                self.set_font(size)
                self.assert_no_overlap(self.layout(1024, 700), 1024)

    def test_no_top_bar_buttons_overlap_at_1280(self):
        for size in self.SIZES:
            with self.subTest(font=size):
                self.set_font(size)
                self.assert_no_overlap(self.layout(1280, 720), 1280)

    def test_the_menu_button_opens_the_menu_not_the_season(self):
        app, w = self.app, self.app.world
        self.set_font(16)
        bars = self.layout(1024, 700)
        menu = next(b for b in bars if b.label == "Menu")
        turn = w.turn
        app.left_click(menu.rect.center)
        self.assertEqual(app.menu, "main")
        self.assertEqual(w.turn, turn)


if __name__ == "__main__":
    unittest.main()
