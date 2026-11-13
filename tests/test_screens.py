"""The screen stack (hexa/campaign/screens/__init__.py): push and pop, what an opaque screen hides, who gets an event,
and the window's use of it (the pause menu, the tech screen and the idea modal are screens). The stack needs no
pygame; the window tests skip without it. Run with:  python -m unittest tests.test_screens
"""
import importlib.util
import os
import random
import shutil
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

from hexa.campaign.screens import Screen, ScreenStack


class Probe(Screen):
    """A screen that writes what happens to it in a shared log, and takes the events it is told to."""

    def __init__(self, name, log, opaque=False, takes=True):
        self.name, self.log, self.opaque, self.takes = name, log, opaque, takes

    def on_enter(self, ctx):
        self.log.append((self.name, "enter", ctx))

    def on_exit(self, ctx):
        self.log.append((self.name, "exit", ctx))

    def update(self, ctx, dt):
        self.log.append((self.name, "update", dt))

    def handle_event(self, ctx, event):
        self.log.append((self.name, "event", event))
        return self.takes

    def draw(self, ctx):
        self.log.append((self.name, "draw"))


class ScreenStackTest(unittest.TestCase):
    def setUp(self):
        self.ctx, self.log = object(), []
        self.stack = ScreenStack(self.ctx)

    def screen(self, name, **kwargs):
        return Probe(name, self.log, **kwargs)

    def events(self, kind):
        return [(name, *rest) for name, what, *rest in self.log if what == kind]

    def test_push_and_pop(self):
        a, b = self.screen("a"), self.screen("b")
        self.assertFalse(self.stack)
        self.assertIsNone(self.stack.top)
        self.assertIsNone(self.stack.pop(), "popping an empty stack does nothing")
        self.stack.push(a)
        self.stack.push(b)
        self.assertEqual((len(self.stack), self.stack.top, a in self.stack), (2, b, True))
        self.assertEqual(list(self.stack), [a, b])
        self.assertIs(self.stack.pop(), b)
        self.assertIs(self.stack.top, a)
        self.assertEqual(self.log, [("a", "enter", self.ctx), ("b", "enter", self.ctx), ("b", "exit", self.ctx)],
                         "the stack hands its ctx to on_enter and on_exit")

    def test_remove_replace_and_clear(self):
        a, b, c = self.screen("a"), self.screen("b"), self.screen("c")
        for screen in (a, b, c):
            self.stack.push(screen)
        self.stack.remove(b)                        # from the middle
        self.stack.remove(b)                        # a second time does nothing
        self.assertEqual(list(self.stack), [a, c])
        self.stack.replace(b)                       # c goes, b comes
        self.assertEqual(list(self.stack), [a, b])
        self.stack.clear()
        self.assertFalse(self.stack)
        self.assertEqual([name for name, what, *_ in self.log if what == "exit"], ["b", "c", "b", "a"])
        self.stack.replace(c)
        self.assertEqual(list(self.stack), [c], "replace on an empty stack is a push")

    def test_an_opaque_screen_hides_the_map_and_what_is_under_it(self):
        under, grid, modal = self.screen("under"), self.screen("grid", opaque=True), self.screen("modal")
        self.assertFalse(self.stack.hides_map, "no screen: the map shows")
        self.stack.push(under)
        self.assertFalse(self.stack.hides_map, "a screen that is not opaque lets the map show")
        self.stack.push(grid)
        self.stack.push(modal)
        self.assertTrue(self.stack.hides_map)
        self.stack.draw()
        self.assertEqual(self.events("draw"), [("grid",), ("modal",)], "drawing starts at the opaque screen, upward")
        self.stack.remove(grid)
        self.assertFalse(self.stack.hides_map)
        self.log.clear()
        self.stack.draw()
        self.assertEqual(self.events("draw"), [("under",), ("modal",)])

    def test_events_go_to_the_top_screen_first(self):
        a, b = self.screen("a", takes=False), self.screen("b")
        self.stack.push(a)
        self.stack.push(b)
        event = object()
        self.assertTrue(self.stack.handle_event(event))
        self.assertEqual(self.events("event"), [("b", event)], "the top screen took it: a never saw it")

    def test_an_event_nobody_takes_falls_through_to_the_window(self):
        a, b = self.screen("a", takes=False), self.screen("b", takes=False)
        self.stack.push(a)
        self.stack.push(b)
        event = object()
        self.assertFalse(self.stack.handle_event(event))
        self.assertEqual([name for name, _ in self.events("event")], ["b", "a"], "top to bottom")
        self.assertFalse(ScreenStack(self.ctx).handle_event(event), "an empty stack takes nothing")

    def test_an_opaque_screen_ends_the_search(self):
        under, grid = self.screen("under"), self.screen("grid", opaque=True, takes=False)
        self.stack.push(under)
        self.stack.push(grid)
        self.assertFalse(self.stack.handle_event(object()))
        self.assertEqual([name for name, _ in self.events("event")], ["grid"], "what the grid hides gets no input")

    def test_update_reaches_every_screen(self):
        self.stack.push(self.screen("a"))
        self.stack.push(self.screen("b"))
        self.stack.update(16)
        self.assertEqual(self.events("update"), [("a", 16), ("b", 16)])

    def test_the_base_screen_is_harmless(self):
        screen = Screen()
        self.stack.push(screen)
        self.assertFalse(screen.opaque)
        self.assertFalse(self.stack.handle_event(SimpleNamespace(type=0)))
        self.stack.update(1)
        self.stack.draw()
        self.stack.pop()


os.environ.setdefault("SDL_VIDEODRIVER", "dummy")


@unittest.skipUnless(importlib.util.find_spec("pygame"), "needs pygame")
class WindowScreensTest(unittest.TestCase):
    """CampaignApp's use of the stack."""

    @classmethod
    def setUpClass(cls):
        import pygame
        pygame.init()

    def setUp(self):
        from hexa.campaign.app import CampaignApp
        self.home = tempfile.mkdtemp(prefix="hexa_screens_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home
        self.app = CampaignApp(player="POR")

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home, ignore_errors=True)

    def key(self, code):
        import pygame
        self.app.handle(pygame.event.Event(pygame.KEYDOWN, key=code, mod=0, unicode="", scancode=0))

    def map_draws(self):
        """How often MapView.draw runs in one app.draw()."""
        from hexa.campaign.mapview import MapView
        with mock.patch.object(MapView, "draw") as draw:
            self.app.draw()
        return draw.call_count

    def test_the_map_alone_has_no_screen(self):
        self.assertFalse(self.app.screens)
        self.assertEqual(self.map_draws(), 1)

    def test_escape_puts_the_pause_menu_on_the_stack_and_takes_it_off(self):
        import pygame
        app = self.app
        app.ui.panel, app.ui.selected = None, None
        self.key(pygame.K_ESCAPE)
        self.assertIs(app.screens.top, app.pause)
        self.assertEqual(app.menu, "main")
        self.assertEqual(self.map_draws(), 1, "the menu is drawn over a shaded map")
        self.assertFalse(app.screens.hides_map)
        self.key(pygame.K_ESCAPE)
        self.assertFalse(app.screens)
        self.assertIsNone(app.menu)

    def test_the_tech_screen_is_opaque_so_the_map_is_not_drawn(self):
        import pygame
        app = self.app
        self.key(pygame.K_t)
        self.assertIs(app.screens.top, app.tech)
        self.assertTrue(app.tech_open and app.screens.hides_map)
        self.assertEqual(self.map_draws(), 0, "nothing of the map is drawn under the tech screen")
        self.assertTrue(app.tech.buttons, "but the tech screen is")
        self.key(pygame.K_t)
        self.assertFalse(app.screens)
        self.assertEqual(self.map_draws(), 1)

    def test_events_go_to_the_top_screen_first(self):
        import pygame
        app = self.app
        app.open_menu()
        top = Probe("top", [], takes=True)
        app.screens.push(top)
        self.key(pygame.K_ESCAPE)                   # the menu would close on this: the top screen has it
        self.assertEqual(app.menu, "main")
        self.assertEqual([what for _, what, *_ in top.log if what == "event"], ["event"])
        app.screens.remove(top)
        self.key(pygame.K_t)                        # the menu takes every key: no tech screen under it
        self.assertFalse(app.tech_open)
        self.assertEqual(app.menu, "main")

    def test_the_hud_hides_while_any_screen_is_up(self):
        from hexa.campaign.hud import Hud
        app = self.app
        self.assertFalse(Hud.hidden(app))
        app.open_menu()
        self.assertTrue(Hud.hidden(app))
        app.close_menu()
        app.open_tech()
        self.assertTrue(Hud.hidden(app))
        app.tech.close(app)
        self.assertFalse(Hud.hidden(app))

    def test_pending_idea_cards_put_the_modal_on_the_stack_over_the_map(self):
        from hexa.campaign import tech
        app = self.app
        country = app.world.countries["POR"]
        counts = {b: 0 for b in tech.BRANCHES}
        country.pending_ideas = [i.key for i in tech.draw_ideas("POR", counts, set(), random.Random(5))]
        self.assertEqual(self.map_draws(), 1, "the modal is drawn over the map")
        self.assertIs(app.screens.top, app.tech, "the next draw (or event) puts it on the stack")
        self.assertFalse(app.tech_open or app.screens.hides_map)
        app.pause.ask(app, "Question", ["?"], [("Ok", ("resume",), False)])
        self.assertIs(app.screens.top, app.pause)
        app.draw()
        country.pending_ideas = []
        app.draw()
        self.assertNotIn(app.tech, app.screens, "no cards, no grid: the modal goes")


if __name__ == "__main__":
    unittest.main()
