"""In-game menu input tests (Age of Discovery). They need no window, and no pygame either. Run with:
python -m unittest tests.test_gamemenu"""
import sys
import unittest
from types import SimpleNamespace
from unittest import mock

from hexa import settings  # noqa: F401 - imported before gamemenu so a stubbed import below can't evict it
from hexa.campaign import saves  # noqa: F401


def _gamemenu():
    """hexa.campaign.gamemenu, with a stand-in pygame when it isn't installed (these tests never draw)."""
    try:
        import pygame  # noqa: F401
    except ImportError:
        with mock.patch.dict(sys.modules, {"pygame": mock.MagicMock()}):
            from hexa.campaign import gamemenu
            return gamemenu
    from hexa.campaign import gamemenu
    return gamemenu


class Box:
    """Just enough of pygame.Rect for menu clicks."""
    def __init__(self, x, y, w, h):
        self.x, self.y, self.w, self.h = x, y, w, h
        self.center = (x + w // 2, y + h // 2)

    def collidepoint(self, pos):
        return self.x <= pos[0] < self.x + self.w and self.y <= pos[1] < self.y + self.h


# Where draw_menu() puts the Load page on a 1024x768 window.
BOX = Box(212, 50, 600, 662)
SLOT = Box(232, 124, 560, 44)
BACK = Box(232, 650, 120, 36)
OUTSIDE = Box(0, 0, 10, 10)


class MenuClickTest(unittest.TestCase):
    """Issue #9: clicks that arrive before the menu page is drawn."""
    def setUp(self):
        gamemenu = _gamemenu()
        self.pygame = gamemenu.pygame
        app = self.app = gamemenu.GameMenu()    # the mixin alone, with just what menu input touches
        app.ui = SimpleNamespace(mouse=(0, 0))
        app.running, app.result = True, None
        app.loaded = []
        app.load_from = lambda slot: app.loaded.append(slot) or True

    def drawn(self, *buttons):
        """Leave what draw_menu() leaves after drawing the current page."""
        self.app.menu_rect = BOX
        self.app.menu_buttons = [(rect, action, True) for rect, action in buttons]

    def click(self, rect):
        self.app.menu_handle(SimpleNamespace(type=self.pygame.MOUSEBUTTONDOWN, button=1, pos=rect.center))

    def test_a_click_before_the_menu_is_first_drawn_is_ignored(self):
        self.app.open_menu()                    # M and a click in the same event batch
        self.click(OUTSIDE)                     # used to raise AttributeError: no menu_rect
        self.assertEqual(self.app.menu, "main")

    def test_buttons_of_an_earlier_page_do_not_answer_clicks(self):
        app = self.app
        app.open_menu("load")
        self.drawn((SLOT, ("load", "quick")), (BACK, ("page", "main")))
        self.click(BACK)                        # back to the main page...
        self.assertEqual(app.menu, "main")
        self.click(SLOT)                        # ...and a second click before it is drawn
        app.close_menu()
        app.open_menu()                         # and the next time the menu opens
        self.click(SLOT)
        self.assertEqual(app.loaded, [], "a slot of an earlier page loaded a game")
        self.assertIsNone(app.menu_confirm)
        self.assertEqual(app.menu, "main")

    def test_once_drawn_buttons_work_and_a_click_outside_closes(self):
        app = self.app
        app.open_menu()
        self.drawn((SLOT, ("page", "options")))
        self.click(SLOT)
        self.assertEqual(app.menu, "options")
        self.drawn()
        self.click(OUTSIDE)
        self.assertIsNone(app.menu)


if __name__ == "__main__":
    unittest.main()
