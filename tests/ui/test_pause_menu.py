"""The Age of Discovery pause menu (hexa/campaign/screens/gamemenu.py) driven through CampaignApp.run(): opening it (Esc, M,
the Menu button) and closing it, its main, save, load and options pages, the second click that overwriting a save
and leaving the game need, the options and F11 kept in settings.json, the F9 quickload confirmation, the fixed
crashes #9 and #10, and the bugs around the menu (#16, #17, #18, #19), fixed in v0.1.5.

Most tests open Europe 1480 as Portugal the way the launcher does (CampaignApp(TILES_DIR, "POR"), see
test_campaign_app.py): zoom 4 on Lisbon, Portugal's panel open on the right (Esc closes it, the next Esc opens the
menu). The menu's buttons are laid out when it is drawn, so a click on one comes at least a frame after its page
opened. Files are checked in the temporary HEXA_HOME (self.home). Run with:

    python -m unittest tests.ui.test_pause_menu
"""
import contextlib
import io
import json
import os
import unittest
from unittest import mock

from tests.support import harness
from tests.support.harness import click, hex_pixel, key
from tests.ui.test_campaign_app import CASTILE_STACK, CampaignCase

# topbar.plan() of Teutonic Order's bar with full-size fonts: (key goods shown, changes shown, wide End season, chips)
PLAN_1280 = (False, True, True, 6)
PLAN_1024 = (False, False, True, 6)

SETTINGS = {"fullscreen": False, "window": "1280x720", "autosave": "year", "scroll": "normal", "grid": True,
            "pass_names": False, "movement": "off"}       # the suite's defaults (tests/__init__.py): the game ships "normal"
DEFAULT_FONT_SCALE = 0.6875   # pygame draws its bundled font, Font(None, size), at this fraction of size


def full_size_sysfont(name, size, bold=False, italic=False, constructor=None):
    """The harness's pinned font drawn at the size asked for, as a system font (Arial, Segoe UI) is: its text is
    about 1.45 times as wide. For layouts that only run out of room with real fonts."""
    return harness.pinned_sysfont(name, round(size / DEFAULT_FONT_SCALE), bold, italic)


class PauseCase(CampaignCase):
    def on_pause(self, action):
        """A click on a button of the menu page drawn on the last frame, by action ("resume", ("save", "1")...)."""
        return lambda: click(harness.pause_button_rect(self.app, action).center)

    def again_if_asked(self, slot_action):
        """A second click on a save or load slot (("load", "quick")) if the first one only asked: its page is still
        open. Nothing otherwise."""
        def events():
            if self.app.menu != slot_action[0]:
                return None
            return click(harness.pause_button_rect(self.app, slot_action).center)
        return events

    def page(self):
        """The menu page on screen (None: closed) and the button waiting for a second click."""
        return self.app.menu, self.app.menu_confirm

    def stored(self):
        """settings.json in the temporary HEXA_HOME, as a dict; None while there is no such file."""
        try:
            with open(os.path.join(self.home, "settings.json"), encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            return None

    def main_box(self):
        """Where the main page's box is drawn: drawn once off the record, then the menu is closed again."""
        app = self.app
        app.open_menu()
        app.draw()
        box = app.menu_rect.copy()
        app.close_menu()
        return box

    def free_province(self, avoid):
        """A province on the visible map with no unit on it, its hex centre outside the rect avoid."""
        world = self.world
        for prov in sorted(world.provinces.values(), key=lambda p: p.pos):
            pixel = hex_pixel(self.app, prov.pos)
            if (prov.owner and not world.units_at(prov.pos) and prov.pos in self.app.view.known()
                    and self.on_map(pixel) and not avoid.inflate(40, 40).collidepoint(pixel)):
                return prov
        raise AssertionError(f"no free province on screen outside {avoid}")

    def fullscreen(self):
        import pygame
        return bool(self.app.screen.get_flags() & pygame.FULLSCREEN)

    def leave_fullscreen_after(self):
        """The dummy video driver keeps the fullscreen size for the next window opened: close the display when the
        test ends, so the next test's window gets the size it asks for (the driver's reset opens it again)."""
        import pygame
        self.addCleanup(pygame.display.quit)


class OpenCloseTest(PauseCase):
    def test_esc_m_and_the_menu_button_open_it_and_esc_and_resume_close_it(self):
        app = self.start("POR")
        seen = []
        record = lambda: seen.append((app.ui.panel, app.menu))             # noqa: E731
        self.driver.at(0, key("m"))                       # M opens it over your country's panel
        self.driver.at(1, record)
        self.driver.at(1, key("escape"))                  # Esc on the main page: back to the game
        self.driver.at(2, record)
        self.driver.at(2, key("escape"))                  # with a panel open, Esc closes the panel ...
        self.driver.at(3, record)
        self.driver.at(3, key("escape"))                  # ... and with nothing open it opens the menu
        self.driver.at(4, record)
        self.driver.at(4, self.on_pause("resume"))
        self.driver.at(5, record)
        self.driver.at(5, self.on_button("Menu", "game_menu"))           # the top bar's Menu button
        self.driver.at(6, record)
        self.play(8)

        self.assertEqual(seen, [("country", "main"), ("country", None), (None, None), (None, "main"), (None, None),
                                (None, "main")])
        self.assertEqual(self.world.turn, 1, "no season passed")

    def test_a_click_outside_the_box_closes_it_and_does_not_reach_the_map(self):
        app = self.start("POR")
        prov = self.free_province(self.main_box())
        seen = []
        record = lambda: seen.append((app.menu, app.ui.panel, app.ui.province and app.ui.province.pos))  # noqa: E731
        self.driver.at(0, key("escape"))                  # close Portugal's panel
        self.driver.at(0, key("m"))
        self.driver.at(1, record)
        self.driver.at(1, self.on_hex(prov.pos))          # outside the box: closes the menu, and that is all
        self.driver.at(2, record)
        self.driver.at(2, self.on_hex(prov.pos))          # the same click with the menu closed opens the province
        self.driver.at(3, record)
        self.play(5)

        self.assertEqual(seen, [("main", None, None), (None, None, None), (None, "province", prov.pos)])

    def test_a_click_inside_the_box_but_on_no_button_keeps_it_open(self):
        app = self.start("POR")
        seen = []
        self.driver.at(0, key("m"))
        self.driver.at(1, lambda: click((app.menu_rect.centerx, app.menu_rect.y + 10)))   # by the title
        self.driver.at(2, lambda: seen.append(self.page()))
        self.driver.at(2, lambda: click((app.menu_rect.x - 10, app.menu_rect.y + 10)))    # just left of the box
        self.driver.at(3, lambda: seen.append(self.page()))
        self.play(5)
        self.assertEqual(seen, [("main", None), (None, None)])

    def test_right_click_goes_back_a_page_like_esc(self):
        app = self.start("POR")
        corner = (40, 100)                                 # on the map, outside every box
        seen = []
        self.driver.at(0, key("m"))
        self.driver.at(1, self.on_pause(("page", "options")))
        self.driver.at(2, lambda: seen.append(self.page()))
        self.driver.at(2, click(corner, button=3))        # a sub-page goes back to the main page ...
        self.driver.at(3, lambda: seen.append(self.page()))
        self.driver.at(3, click(corner, button=3))        # ... which closes
        self.driver.at(4, lambda: seen.append(self.page()))
        self.play(6)
        self.assertEqual(seen, [("options", None), ("main", None), (None, None)])

    def test_a_click_before_the_menu_is_first_drawn_is_ignored(self):
        """Issue #9 (fixed): M and a click outside the menu in one batch of events, before the menu has been drawn,
        crashed the game (AttributeError: no menu_rect). On later opens, a click could hit a button of the page
        shown before, so a Load page slot could load a game from the main page."""
        app = self.start("POR")
        first = self.world
        corner = (40, 100)                                 # on the map, outside every box
        seen = []
        self.driver.at(0, key("escape"), key("f5"))       # close Portugal's panel; quicksave
        self.driver.at(1, key("m"), click(corner))        # the same frame: handled before any draw
        self.driver.at(2, lambda: seen.append(self.page()))
        self.driver.at(2, click(corner))                  # drawn now: the same click closes it
        self.driver.at(3, lambda: seen.append(self.page()))
        self.driver.at(3, key("m"))
        self.driver.at(4, self.on_pause(("page", "load")))
        quick = []
        self.driver.at(5, lambda: quick.append(harness.pause_button_rect(app, ("load", "quick")).center))
        self.driver.at(5, lambda: seen.append(self.page()))
        self.driver.at(5, lambda: key("escape") + click(quick[0]))   # back to main, then where Quicksave was
        self.driver.at(6, lambda: seen.append((self.page(), app.world is first)))
        self.play(8)

        self.assertEqual(seen, [("main", None), (None, None), ("load", None), (("main", None), True)])
        self.assertEqual(app.ui.toast, "Saved: Quicksave (Spring 1480).", "nothing was loaded")

    def test_escape_clears_the_selection_then_opens_the_menu(self):
        """Issue #19 (fixed in v0.1.5). Esc didn't deselect a selected stack. handle() sets ui.selected to None but leaves ui.group,
        and refresh() selects ui.group[0] again, so every Esc closes the panel and the menu never opens."""
        app = self.start("POR")
        lisbon = self.world.countries["POR"].capital
        seen = []

        def record():
            ui = app.ui
            seen.append(([(u.kind.name, u.pos) for u in ui.group], ui.selected and ui.selected.kind.name, ui.panel,
                         app.menu))

        self.driver.at(0, key("escape"))                  # close Portugal's panel
        self.driver.at(1, self.on_hex(lisbon))            # select the pikemen in Lisbon
        self.driver.at(2, record)
        self.driver.at(2, key("escape"))
        self.driver.at(3, record)
        self.driver.at(3, key("escape"))
        self.driver.at(4, record)
        self.play(6)

        self.assertEqual(seen[0], ([("Pikemen", lisbon)], "Pikemen", "unit", None), "the pikemen were selected")
        self.assertEqual(seen[1:], [([], None, None, None), ([], None, None, "main")],
                         "(stack, selected, panel, menu): the first Esc clears the selection, the second opens the "
                         "menu")

    def click_menu_button(self, tag, desktop):
        """Open tag's game with full-size fonts on a screen of size desktop (the window shrinks to fit it) and click
        the middle of the top bar's Menu button. Returns (window size, Menu rect, End season rect, End season label,
        the menu page then, the turn then)."""
        import pygame
        with mock.patch.object(harness, "DESKTOP", desktop), mock.patch.object(pygame.font, "SysFont",
                                                                               full_size_sysfont):
            app = self.start(tag)
        seen = []

        def rects():
            end = next(b for b in app.ui.buttons if b.action == ("end",))
            seen.extend([app.screen.get_size(), harness.button_rect(app, "Menu"), end.rect, end.label])
            self.planned = self.plan_of(app)

        self.driver.at(1, rects)
        self.driver.at(1, self.on_button("Menu", "game_menu"))
        self.driver.at(2, lambda: seen.extend([app.menu, self.world.turn]))
        self.play(4)
        return seen

    @staticmethod
    def plan_of(app):
        """What the top bar's plan() makes of the window as it is: (key goods, changes, wide End season, chips)."""
        from hexa.campaign.hud import topbar
        snap, _ = topbar.readings(app, app.hud)
        rows = [topbar.Row(app, spec, snap) for spec in topbar.CHIPS + topbar.GOODS]
        x = 12 + 30 + app.title.size(app.world.countries[app.player].name)[0] + 16
        return topbar.layout(app, rows, x, app.screen.get_width())

    def test_with_full_size_fonts_the_menu_button_still_opens_the_menu(self):
        size, menu, end, label, page, turn = self.click_menu_button("TEU", harness.DESKTOP)
        self.assertEqual((size, label), ((1280, 720), "End season"))
        self.assertEqual(self.planned, PLAN_1280, "the plan for this window, called directly")
        self.assertFalse(menu.colliderect(end), f"Menu {menu}, End season {end}")
        self.assertEqual((page, turn), ("main", 1))

    def test_the_menu_button_opens_the_menu_on_a_1024_wide_window(self):
        """Issue #18 (fixed in v0.1.5). On a 1024-wide window End season (at least 64 wide, then labelled "End") overlaps the Menu
        button, and End comes first in ui.buttons, so a click on Menu ends the season. With the pinned font, drawn
        at 0.6875 of its size, the top bar has room to spare even at 1024 wide; text as wide as a real system font
        draws it (full_size_sysfont) puts the Teutonic Order's Menu at x 964 to 1028, End at 950 to 1014."""
        size, menu, end, label, page, turn = self.click_menu_button("TEU", (1024, 768))
        self.assertEqual(size, (1024, 708))
        self.assertEqual(self.planned, PLAN_1024, "the key goods and the changes go, End season stays whole")
        self.assertEqual(label, "End season" if self.planned[2] else "End", "the button says what the plan said")
        self.assertEqual((page, turn), ("main", 1), f"a click on Menu {menu} opens the menu, and no season passes")
        self.assertFalse(menu.colliderect(end), f"Menu {menu} and End season {end} overlap")

    def test_a_right_click_that_closes_the_menu_gives_no_order(self):
        """Issue #16 (fixed in v0.1.5). A right-button press closed the menu's main page; the release then reaches the map with no drag
        under way ((None or 0) < 6), so right_click() moves or attacks with the selected stack."""
        app = self.start("CAS")
        world = self.world
        app.look_at(CASTILE_STACK)
        stack = world.units_at(CASTILE_STACK)
        target = min(p for p in world.reachable_group(stack) if p != CASTILE_STACK)
        seen = []
        self.driver.at(0, key("escape"))                  # close Castile's panel
        self.driver.at(1, self.on_hex(CASTILE_STACK))     # select the stack of five
        self.driver.at(2, key("m"))
        self.driver.at(3, lambda: seen.append((len(app.ui.group), target in app.ui.reach, app.menu)))
        self.driver.at(3, lambda: click(hex_pixel(app, target), button=3))
        self.driver.at(4, lambda: seen.append(app.menu))
        self.play(6)

        self.assertEqual(seen, [(5, True, "main"), None], "the stack was selected, the hex in reach, then closed")
        self.assertEqual({u.pos for u in stack}, {CASTILE_STACK}, f"the stack moved to {target}")
        self.assertEqual({u.moves_left for u in stack}, {4, 6, 10})


class LeaveTest(PauseCase):
    def test_main_menu_and_exit_ask_yes_or_no_while_you_play(self):
        """#91: Main menu and Exit open a Yes/No question instead of waiting for a second click."""
        for action, yes, result in (("menu", "menu_now", "menu"), ("exit", "exit_now", "quit")):
            with self.subTest(action=action):
                self.driver.reset()
                app = self.start("POR")
                seen = []
                self.driver.at(0, key("m"))
                self.driver.at(1, self.on_pause((action,)))
                self.driver.at(2, lambda: seen.append((app.menu, app.running)))
                self.driver.at(2, self.on_pause((yes,)))
                self.assertEqual(self.play(30), result)
                self.assertEqual(self.driver.stopped_by, None, "run() ended before the frame budget")
                self.assertEqual(seen, [("question", True)], "the first click only asked")

    def test_no_on_the_question_goes_back_to_the_pause_menu(self):
        app = self.start("POR")
        seen = []
        self.driver.at(0, key("m"))
        self.driver.at(1, self.on_pause(("exit",)))
        self.driver.at(2, self.on_pause(("page", "main")))
        self.driver.at(3, lambda: seen.append((app.menu, app.running)))
        self.driver.at(4, key("escape"))
        self.play(10)
        self.assertEqual(seen, [("main", True)])

    def test_before_choosing_a_country_save_is_greyed_out_and_one_click_leaves(self):
        app = self.start(None)
        seen = []
        self.driver.at(0, key("escape"))                  # the chooser has no panel open: Esc opens the menu
        self.driver.at(1, lambda: seen.append({a: enabled for _, a, enabled in app.menu_buttons}))
        self.driver.at(1, self.on_pause(("page", "save")))
        self.driver.at(2, lambda: seen.append(self.page()))
        self.driver.at(2, self.on_pause(("page", "load")))           # the next button down works
        self.driver.at(3, lambda: seen.append(self.page()))
        self.driver.at(3, key("escape"))
        self.driver.at(4, self.on_pause(("menu",)))
        self.assertEqual(self.play(30), "menu")

        self.assertEqual(seen[0], {("resume",): True, ("page", "save"): False, ("page", "load"): True,
                                   ("page", "options"): True, ("menu",): True, ("exit",): True})
        self.assertEqual(seen[1:], [("main", None), ("load", None)])
        self.assertEqual(self.driver.stopped_by, None, "one click on Main menu left the game")


class PagesTest(PauseCase):
    def test_each_page_and_its_back_button(self):
        from hexa import settings
        from hexa.campaign import saves
        app = self.start("POR")
        seen = []
        record = lambda: seen.append((app.menu, [action for _, action, _ in app.menu_buttons]))   # noqa: E731
        script = [key("m"), self.on_pause(("page", "save")), self.on_pause(("page", "main")),
                  self.on_pause(("page", "load")), self.on_pause(("page", "main")),
                  self.on_pause(("page", "options")), key("escape"), key("escape")]
        for frame, step in enumerate(script):
            self.driver.at(frame, step)
            self.driver.at(frame + 1, record)
        self.play(len(script) + 2)

        main = [("resume",), ("page", "save"), ("page", "load"), ("page", "options"), ("menu",), ("exit",)]
        back = [("page", "main")]
        self.assertEqual(seen, [("main", main),
                                ("save", [("save", s) for s in saves.SLOTS] + back), ("main", main),
                                ("load", [("load", s) for s in saves.SPECIAL + saves.SLOTS] + back), ("main", main),
                                ("options", [("option", k) for k in settings.DEFAULTS] + back),   # every option
                                ("main", main), (None, [])])


class SaveLoadTest(PauseCase):
    def test_a_save_slot_saves_and_overwriting_it_needs_a_second_click(self):
        from hexa.campaign import saves
        app = self.start("POR")
        seen = []
        record = lambda: seen.append((self.page(), (saves.meta("1") or {}).get("date"), app.ui.toast))  # noqa: E731
        script = [key("m"), self.on_pause(("page", "save")), self.on_pause(("save", "1")),    # empty: saves at once
                  key("space"),                                                              # summer
                  key("m"), self.on_pause(("page", "save")), self.on_pause(("save", "1")),    # in use: asks first
                  self.again_if_asked(("save", "1"))]                                        # overwrites
        for frame, step in enumerate(script):
            self.driver.at(frame, step)
            self.driver.at(frame + 1, record)
        self.play(len(script) + 30, until=lambda: len(seen) == len(script))

        saved = "Saved: Slot 1 (Spring 1480)."
        self.assertEqual(seen[2], ((None, None), "Spring 1480", saved), "an empty slot saves and the menu closes")
        self.assertEqual(seen[6], (("save", ("save", "1")), "Spring 1480", saved),
                         "a slot in use only asks: the spring save is still there")
        self.assertEqual(seen[7], ((None, None), "Summer 1480", "Saved: Slot 1 (Summer 1480)."),
                         "the second click overwrites it")
        self.assertEqual(saves.meta("1")["turn"], 2)
        self.assertEqual(sorted(os.listdir(os.path.join(self.home, "saves"))), ["1.sav"])

    def test_the_load_page_offers_only_saved_slots_and_brings_one_back(self):
        from tests.support.digests import world_digest
        app = self.start("POR")
        first = self.world
        saved, seen = [], []
        self.driver.at(0, key("f5"))
        self.driver.at(1, lambda: saved.append(world_digest(first)))
        self.driver.at(1, key("space"))                   # summer: the quicksave is now behind
        self.driver.at(2, key("m"))
        self.driver.at(3, self.on_pause(("page", "load")))
        self.driver.at(4, lambda: seen.append({a[1]: enabled for _, a, enabled in app.menu_buttons
                                               if a[0] == "load"}))
        self.driver.at(4, self.on_pause(("load", "1")))   # an empty slot: greyed out, the click does nothing
        self.driver.at(5, lambda: seen.append((self.page(), app.world is first, first.turn, app.ui.toast)))
        self.driver.at(5, self.on_pause(("load", "quick")))
        self.driver.at(6, self.again_if_asked(("load", "quick")))      # once it asks first (issue #17)
        self.play(30, until=lambda: app.world is not first)

        self.assertEqual(self.driver.stopped_by, "until", "the quicksave was never loaded")
        self.assertEqual(seen[0], {"quick": True, "auto": False, "1": False, "2": False, "3": False, "4": False,
                                   "5": False, "6": False, "7": False, "8": False})
        self.assertEqual(seen[1], (("load", None), True, 2, "Saved: Quicksave (Spring 1480)."),
                         "the empty slot did nothing")
        world = app.world
        self.assertEqual((world.turn, world.player), (1, "POR"))
        self.assertEqual(world_digest(world), saved[0])
        self.assertIs(app.view.world, world)
        self.assertEqual(self.page(), (None, None))
        self.assertEqual(app.ui.toast, "Loaded Quicksave: Spring 1480.")

    def test_loading_a_save_asks_before_the_game_on_screen_is_lost(self):
        """Issue #17 (fixed in v0.1.5). A slot on the Load page replaced the game at once, losing unsaved progress, while Main menu and
        Exit ask for a second click. (F9, the other half of #17, now asks first: see the test below.)"""
        app = self.start("POR")
        first = self.world
        seen = []
        self.driver.at(0, key("f5"))
        self.driver.at(1, key("space"))                   # an unsaved summer
        self.driver.at(2, key("m"))
        self.driver.at(3, self.on_pause(("page", "load")))
        self.driver.at(4, self.on_pause(("load", "quick")))
        self.driver.at(5, lambda: seen.append((app.menu, app.world is first, app.world.date())))
        self.driver.at(5, self.again_if_asked(("load", "quick")))
        self.play(30, until=lambda: app.world is not first)

        self.assertEqual(seen, [("load", True, "Summer 1480")],
                         "(page, same game, date): the first click only asks, the summer game is still on screen")
        self.assertEqual(self.driver.stopped_by, "until", "the second click loads it")
        self.assertEqual(app.world.date(), "Spring 1480")

    def test_f9_asks_first_and_the_second_press_must_come_soon(self):
        """Issue #17, the F9 half (fixed): one F9 used to load the quicksave at once. Now it asks, and only a second
        press within QUICKLOAD_CONFIRM_MS loads; a press after that asks again."""
        from hexa.campaign.screens.gamemenu import QUICKLOAD_CONFIRM_MS
        app = self.start("POR")
        first = self.world
        app.view.zoom = 1                                  # a cheap frame: the test waits a few hundred of them
        app.look_at(first.countries["POR"].capital)
        late = QUICKLOAD_CONFIRM_MS // harness.FRAME_MS + 5   # frames after which the first press has expired
        ask = "Press F9 again to load the quicksave (unsaved progress is lost)."
        seen = []
        record = lambda: seen.append((app.world is first, first.turn, app.ui.toast,          # noqa: E731
                                      self.driver.now < app.ui.toast_until))            # the toast on screen
        self.driver.at(0, key("f5"))
        self.driver.at(1, key("space"))
        self.driver.at(2, key("f9"))
        self.driver.at(3, record)
        self.driver.at(3 + late, key("f9"))               # too late to count as the second press: asks again
        self.driver.at(4 + late, record)
        self.driver.at(4 + late, key("f9"))               # the second press: loads
        self.play(late + 30, until=lambda: app.world is not first)

        self.assertEqual(seen, [(True, 2, ask, True), (True, 2, ask, True)], "both lone presses asked")
        self.assertEqual(self.driver.stopped_by, "until", "a press right after the late one loaded it")
        self.assertEqual(app.world.turn, 1)
        self.assertEqual(app.ui.toast, "Loaded Quicksave: Spring 1480.")


class OptionsTest(PauseCase):
    def test_each_option_changes_at_once_and_is_kept_in_settings_json(self):
        from hexa import settings
        app = self.start("POR")
        self.assertIsNone(self.stored(), "the defaults: no settings.json yet")
        seen = []
        record = lambda: seen.append((dict(app.settings), self.stored(), app.screen.get_size()))   # noqa: E731
        self.driver.at(0, key("m"))
        self.driver.at(1, self.on_pause(("page", "options")))
        clicks = ["autosave", "autosave", "scroll", "grid", "pass_names", "window", "window", "window"]
        for frame, option in enumerate(clicks, start=2):
            self.driver.at(frame, self.on_pause(("option", option)))
            self.driver.at(frame + 1, record)
        self.play(len(clicks) + 4)

        expected = [(dict(SETTINGS, autosave="5 years"), (1280, 720)),
                    (dict(SETTINGS, autosave="off"), (1280, 720)),
                    (dict(SETTINGS, autosave="off", scroll="fast"), (1280, 720)),
                    (dict(SETTINGS, autosave="off", scroll="fast", grid=False), (1280, 720)),
                    (dict(SETTINGS, autosave="off", scroll="fast", grid=False, pass_names=True), (1280, 720)),
                    (dict(SETTINGS, autosave="off", scroll="fast", grid=False, pass_names=True, window="1600x900"),
                     (1600, 900)),
                    # 1920x1080 doesn't fit a 1920x1080 desktop with its task bar: 60 pixels less
                    (dict(SETTINGS, autosave="off", scroll="fast", grid=False, pass_names=True, window="1920x1080"),
                     (1920, 1020)),
                    (dict(SETTINGS, autosave="off", scroll="fast", grid=False, pass_names=True), (1280, 720))]
        self.assertEqual([(now, size) for now, _, size in seen], expected)
        self.assertEqual([stored for _, stored, _ in seen], [now for now, _ in expected], "each change is saved")
        self.assertEqual(settings.load(), app.settings, "and read back next time")
        self.assertEqual(self.page(), ("options", None), "the page stays open")
        self.assertEqual(app.view_rect().size, (1280, 720 - 46), "the map fills the window")

    def test_the_fullscreen_option_and_f11_switch_fullscreen_and_keep_it(self):
        app = self.start("POR")
        self.leave_fullscreen_after()
        seen = []

        def stored(key):
            return (self.stored() or {}).get(key)

        def record():
            window = [enabled for _, action, enabled in app.menu_buttons if action == ("option", "window")]
            seen.append((app.settings["fullscreen"], stored("fullscreen"), self.fullscreen(), window))

        self.driver.at(0, key("m"))
        self.driver.at(1, self.on_pause(("page", "options")))
        self.driver.at(2, self.on_pause(("option", "fullscreen")))
        self.driver.at(3, record)
        self.driver.at(3, self.on_pause(("option", "window")))         # greyed out in fullscreen: no effect
        self.driver.at(4, lambda: seen.append((app.settings["window"], stored("window"))))
        self.driver.at(4, key("f11"))                                  # F11 works with the menu open ...
        self.driver.at(5, record)
        self.driver.at(5, key("escape"), key("escape"))                # main page, then back to the game
        self.driver.at(6, lambda: seen.append(self.page()))
        self.driver.at(6, key("f11"))                                  # ... and without it
        self.driver.at(7, record)
        self.play(9)

        # (setting, settings.json, the window, the Window size button enabled: [] when the menu is closed)
        self.assertEqual(seen, [(True, True, True, [False]), ("1280x720", "1280x720"), (False, False, False, [True]),
                                (None, None), (True, True, True, [])])
        self.assertEqual(self.stored(), dict(SETTINGS, fullscreen=True))

    def test_options_and_f11_when_settings_json_cannot_be_written_still_apply_and_say_so(self):
        """Issue #10 (fixed): F11 or an option change crashed the game when settings.json couldn't be written.
        Here settings.json is a folder, so writing the file fails."""
        path = os.path.join(self.home, "settings.json")
        os.mkdir(path)
        app = self.start("POR")
        self.assertEqual(app.settings, SETTINGS, "an unreadable settings.json: the defaults")
        self.leave_fullscreen_after()
        warning = "Option changed, but it could not be saved for next time."
        seen = []
        self.driver.at(0, key("m"))
        self.driver.at(1, self.on_pause(("page", "options")))
        self.driver.at(2, self.on_pause(("option", "autosave")))
        self.driver.at(3, lambda: seen.append((app.settings["autosave"], app.ui.toast)))
        self.driver.at(3, key("escape"), key("escape"), key("f5"))   # back to the game; a toast of its own
        self.driver.at(4, lambda: seen.append(app.ui.toast))
        self.driver.at(4, key("f11"))
        self.driver.at(5, lambda: seen.append((app.settings["fullscreen"], self.fullscreen(), app.ui.toast)))
        self.driver.at(5, key("space"))                   # and the game goes on
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.play(30, until=lambda: self.world.turn == 2)

        self.assertEqual(seen, [("5 years", warning), "Saved: Quicksave (Spring 1480).", (True, True, warning)])
        self.assertEqual(self.driver.stopped_by, "until")
        self.assertEqual(err.getvalue().count(f"Could not save options to {path}: "), 2, err.getvalue())
        self.assertTrue(os.path.isdir(path), "left as it was")
        self.assertFalse(os.path.exists(path + ".tmp"), "no half-written file left behind")


if __name__ == "__main__":
    unittest.main()
