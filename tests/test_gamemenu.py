"""Pause menu input tests (Age of Discovery). They need no window, and no pygame either. Run with:
python -m unittest tests.test_gamemenu"""
import sys
import unittest
from types import SimpleNamespace
from unittest import mock

from hexa import settings  # noqa: F401 - imported before gamemenu so a stubbed import below can't evict it
from hexa.campaign import saves  # noqa: F401


def _gamemenu():
    """hexa.campaign.screens.gamemenu, with a stand-in pygame when it isn't installed (these tests never draw)."""
    try:
        import pygame  # noqa: F401
    except ImportError:
        with mock.patch.dict(sys.modules, {"pygame": mock.MagicMock()}):
            from hexa.campaign.screens import gamemenu
            return gamemenu
    from hexa.campaign.screens import gamemenu
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


real_load_from = _gamemenu().load_from


class MenuClickTest(unittest.TestCase):
    """Issue #9: clicks that arrive before the menu page is drawn."""
    def setUp(self):
        from hexa.campaign.screens import ScreenStack
        gamemenu = _gamemenu()
        self.pygame = gamemenu.pygame
        menu = self.menu = gamemenu.PauseMenu()
        # the window as the menu sees it: just what menu input touches (see hexa/campaign/screens/__init__.py)
        app = self.app = SimpleNamespace(ui=SimpleNamespace(mouse=(0, 0)), running=True, result=None, loaded=[],
                                         pause=menu, player=None)
        app.screens = ScreenStack(app)
        app.close_menu = lambda: menu.close(app)
        gamemenu.load_from = lambda ctx, slot: ctx.loaded.append(slot) or True
        self.addCleanup(lambda: setattr(gamemenu, "load_from", real_load_from))

    def drawn(self, *buttons):
        """Leave what draw_menu() leaves after drawing the current page."""
        self.menu.rect = BOX
        self.menu.buttons = [(rect, action, True) for rect, action in buttons]

    def click(self, rect):
        self.menu.handle_event(self.app, SimpleNamespace(type=self.pygame.MOUSEBUTTONDOWN, button=1, pos=rect.center))

    def test_a_click_before_the_menu_is_first_drawn_is_ignored(self):
        self.menu.open(self.app)                # M and a click in the same event batch
        self.click(OUTSIDE)                     # used to raise AttributeError: no menu_rect
        self.assertEqual(self.menu.page, "main")

    def test_buttons_of_an_earlier_page_do_not_answer_clicks(self):
        app, menu = self.app, self.menu
        menu.open(app, "load")
        self.drawn((SLOT, ("load", "quick")), (BACK, ("page", "main")))
        self.click(BACK)                        # back to the main page...
        self.assertEqual(menu.page, "main")
        self.click(SLOT)                        # ...and a second click before it is drawn
        menu.close(app)
        menu.open(app)                          # and the next time the menu opens
        self.click(SLOT)
        self.assertEqual(app.loaded, [], "a slot of an earlier page loaded a game")
        self.assertIsNone(menu.confirm)
        self.assertEqual(menu.page, "main")

    def test_once_drawn_buttons_work_and_a_click_outside_closes(self):
        app, menu = self.app, self.menu
        menu.open(app)
        self.drawn((SLOT, ("page", "options")))
        self.click(SLOT)
        self.assertEqual(menu.page, "options")
        self.drawn()
        self.click(OUTSIDE)
        self.assertIsNone(menu.page)


if __name__ == "__main__":
    unittest.main()
