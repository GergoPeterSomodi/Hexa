"""The Age of Discovery window (hexa/campaign/app.py) driven through its own run() loop: choosing a country,
ending the season (Space and the End season button), the quicksave (F5, F9) and the autosave, the map modes and
goods views, zooming around the mouse, the side panels, and orders that take several seasons.

Every test opens Europe 1480 the way the launcher does (CampaignApp(TILES_DIR, tag)), sometimes changes the zoom,
the camera, the options or the turn before the loop starts, then plays the scenario with real mouse and keyboard
events and checks the world, the window state and the files in the temporary HEXA_HOME. The first window of a
process builds the map (about 2 s); later ones restore it from the world module's snapshot. Choosing a country
zooms in on its capital (zoom 4, tile art) in the middle of the map and opens its panel on the right.

    Portugal (POR): pikemen in Lisbon (124, 61), a caravel offshore at (124, 60)
    Castile (CAS): a stack of five at (131, 59): three pikemen, knights and bombards (4 moves a season)

Run with: python -m unittest tests.ui.test_campaign_app
"""
import hashlib
import json
import os
import shutil
import unittest
from unittest import mock

from tests.support import harness
from tests.support.digests import world_digest
from tests.support.harness import click, hex_pixel, key, wheel

CASTILE_STACK = (131, 59)


class CampaignCase(harness.UITestCase):
    def start(self, tag="POR"):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = CampaignApp(play.TILES_DIR, tag)
        self.world = self.app.world
        return self.app

    def play(self, frames, until=None):
        """Run the window's real loop on the script so far; return what run() returned."""
        self.driver.run_for(frames, until)
        return self.app.run()

    def on_map(self, pixel):
        """Whether a click on pixel goes to a map hex: in the map area, not on a button, the open panel or the
        minimap."""
        app = self.app
        return (app.view_rect().collidepoint(pixel) and not app.minimap_rect().collidepoint(pixel)
                and not (app.ui.panel and app.panel_rect().collidepoint(pixel))
                and not any(b.rect.collidepoint(pixel) for b in app.ui.buttons))

    def on_hex(self, pos, button=1):
        """A click on map hex pos, where it is on screen when its frame comes."""
        def events():
            pixel = hex_pixel(self.app, pos)
            if not self.on_map(pixel):
                raise AssertionError(f"hex {pos} is at {pixel}, not on the visible map: move the camera first")
            return click(pixel, button)
        return events

    def on_button(self, label=None, action=None):
        """A click on one of the window's buttons, as drawn on the last frame before this one."""
        return lambda: click(harness.button_rect(self.app, label, action).center)

    def autosave_turn(self):
        from hexa.campaign import saves
        meta = saves.meta("auto")
        return meta and meta["turn"]


class ChooserTest(CampaignCase):
    def test_click_a_country_then_play_as_starts_the_game_as_that_country(self):
        app = self.start(None)
        world = self.world
        self.assertEqual((world.player, app.view.zoom, app.ui.panel), (None, 1, None), "the chooser, zoomed out")
        lisbon, toledo = world.countries["POR"].capital, world.countries["CAS"].capital
        seen = []
        record = lambda: seen.append((world.player, world.turn, app.ui.panel, app.ui.country,      # noqa: E731
                                      [b.label for b in app.ui.buttons if b.action[0] == "choose"]))
        self.driver.at(0, key("space"))                       # no country yet: no season passes
        self.driver.at(1, self.on_hex(toledo))
        self.driver.at(2, record)
        self.driver.at(2, self.on_hex(lisbon))                # another country: its panel instead
        self.driver.at(3, record)
        self.driver.at(3, self.on_button(action=("choose",)))
        self.driver.at(4, record)
        self.driver.at(4, lambda: seen.append((app.view.zoom, app.hex_under(app.view_rect().center))))
        self.driver.at(4, key("space"))
        self.assertEqual(self.play(30, until=lambda: world.turn == 2), "quit")

        self.assertEqual(seen[0], (None, 1, "country", "CAS", ["Play as Castile"]))
        self.assertEqual(seen[1], (None, 1, "country", "POR", ["Play as Portugal"]))
        self.assertEqual(seen[2], ("POR", 1, "country", "POR", []), "Space before choosing passed no season")
        self.assertEqual(seen[3], (4, lisbon), "zoomed in on the capital")
        self.assertIn("You lead Portugal. Grow your economy, trade, and reach for the New World.", world.log)
        self.assertEqual((world.player, world.turn), ("POR", 2), "and Space now ends the season")
        self.assertEqual(self.driver.stopped_by, "until")


class SeasonTest(CampaignCase):
    def test_space_ends_the_season_after_every_other_country_has_moved(self):
        from hexa.campaign import ai
        app = self.start("POR")
        world = self.world
        moved = []
        real = ai.run

        def spy(w, tag):
            moved.append((tag, app.busy, w.turn))
            return real(w, tag)

        patcher = mock.patch.object(ai, "run", spy)
        patcher.start()
        self.addCleanup(patcher.stop)
        units = {tag: len(world.units_of(tag)) for tag in world.countries}
        mine = [(u.id, u.pos) for u in world.units_of("POR")]
        self.assertEqual(world.date(), "Spring 1480")
        self.driver.at(1, key("space"))
        self.play(30, until=lambda: world.turn == 2)

        self.assertEqual(self.driver.stopped_by, "until")
        self.assertEqual(sorted(tag for tag, _, _ in moved), sorted(t for t in world.countries if t != "POR"),
                         "every other country moved once, and the computer never played Portugal")
        self.assertEqual({(busy, turn) for _, busy, turn in moved}, {(True, 1)},
                         "they move in spring, while the window says the others are moving")
        self.assertEqual((world.turn, world.date()), (2, "Summer 1480"))
        self.assertFalse(app.busy)
        raised = {tag for tag in world.countries if len(world.units_of(tag)) > units[tag]}
        self.assertTrue(raised, "the other countries raised troops")
        self.assertNotIn("POR", raised)
        self.assertEqual([(u.id, u.pos) for u in world.units_of("POR")], mine, "your units stayed where they were")
        self.assertTrue(world.log[-1].startswith("Summer 1480. Treasury "), world.log[-1])

    def test_the_end_season_button_ends_the_season(self):
        app = self.start("POR")
        world = self.world
        seen = []
        self.driver.at(1, lambda: seen.append([b.label for b in app.ui.buttons
                                               if b.rect == harness.end_turn_rect(app)]))
        self.driver.at(1, lambda: click(harness.end_turn_rect(app).center))
        self.driver.at(2, lambda: seen.append(world.date()))
        self.driver.at(2, lambda: click(harness.end_turn_rect(app).center))
        self.play(30, until=lambda: world.turn == 3)

        self.assertEqual(self.driver.stopped_by, "until")
        self.assertEqual(seen, [["End season"], "Summer 1480"], "one season a click")
        self.assertEqual((world.turn, world.date()), (3, "Autumn 1480"))
        self.assertFalse(app.busy)


class QuicksaveTest(CampaignCase):
    def test_f5_saves_the_game_to_the_quicksave(self):
        from hexa.campaign import saves
        app = self.start("POR")
        world = self.world
        self.driver.at(1, key("f5"))
        self.play(4)

        self.assertEqual(os.listdir(os.path.join(self.home, "saves")), ["quick.sav"])
        meta = saves.meta("quick")
        self.assertEqual({k: meta[k] for k in ("slot", "turn", "date", "tag", "country", "map")},
                         {"slot": "quick", "turn": 1, "date": "Spring 1480", "tag": "POR", "country": "Portugal",
                          "map": world.geo.name})
        self.assertEqual(world_digest(saves.load("quick")), world_digest(world), "the whole game is in the file")
        self.assertEqual(app.ui.toast, "Saved: Quicksave (Spring 1480).")
        self.assertIs(app.world, world, "saving keeps playing the same game")

    def test_f9_brings_back_the_quicksaved_game(self):
        app = self.start("POR")
        first = self.world
        saved = []
        self.driver.at(1, key("f5"))
        self.driver.at(2, lambda: saved.append(world_digest(first)))
        self.driver.at(2, key("space"))                                   # the game moves on to summer ...
        self.driver.at(3, lambda: saved.append((first.turn, app.world is first)))
        self.driver.at(3, key("f9"))                                       # ... and F9 (pressed twice) goes back
        self.driver.at(4, key("f9"))
        self.play(30, until=lambda: app.world is not first)

        self.assertEqual(self.driver.stopped_by, "until", "F9 never loaded the quicksave")
        self.assertEqual(saved[1], (2, True))
        world = app.world
        self.assertEqual((world.turn, world.date(), world.player), (1, "Spring 1480", "POR"))
        self.assertEqual(world_digest(world), saved[0], "exactly the game that was saved")
        self.assertIs(app.view.world, world, "the map shows the loaded game")
        self.assertEqual((app.view.zoom, app.hex_under(app.view_rect().center)), (4, world.countries["POR"].capital))
        self.assertEqual(app.ui.toast, "Loaded Quicksave: Spring 1480.")
        self.assertEqual(first.turn, 2)


class AutosaveTest(CampaignCase):
    def seasons(self, n):
        """Space n times, one a frame, and the autosave's turn (None: no autosave) after each season."""
        world = self.world
        seen = []
        for i in range(n):
            self.driver.at(1 + i, key("space"))
            self.driver.at(2 + i, lambda: seen.append((world.turn, self.autosave_turn())))
        self.play(n + 30, until=lambda: len(seen) == n)
        self.assertEqual(self.driver.stopped_by, "until")
        return seen

    def test_a_new_game_autosaves_at_the_start_of_every_year(self):
        from hexa import settings
        from hexa.campaign import saves
        app = self.start("POR")
        self.assertEqual(app.settings["autosave"], "year", "the default")
        every = settings.AUTOSAVE_TURNS["year"]
        self.assertEqual(every, 4, "a year is four seasons")
        seen = self.seasons(every + 1)

        # Turn 1 is spring 1480: the autosave comes with the next spring, then each spring after it.
        self.assertEqual(seen, [(2, None), (3, None), (4, None), (5, 5), (6, 5)])
        self.assertEqual(saves.meta("auto")["date"], "Spring 1481")
        self.assertEqual(sorted(os.listdir(os.path.join(self.home, "saves"))), ["auto.sav"])

    def test_the_autosave_option_sets_how_often(self):
        from hexa import settings
        # From winter 1483: spring 1484 (turn 17) is a new year, spring 1485 (turn 21) is also a fifth year.
        expected = {"year": [(17, 17), (18, 17), (19, 17), (20, 17), (21, 21)],
                    "5 years": [(17, None), (18, None), (19, None), (20, None), (21, 21)],
                    "off": [(17, None), (18, None), (19, None), (20, None), (21, None)]}
        self.assertEqual(settings.AUTOSAVE_TURNS, {"off": 0, "year": 4, "5 years": 20})
        for choice, saves_seen in expected.items():
            with self.subTest(autosave=choice):
                self.driver.reset()
                shutil.rmtree(os.path.join(self.home, "saves"), ignore_errors=True)
                with open(os.path.join(self.home, "settings.json"), "w") as f:
                    json.dump({"autosave": choice}, f)
                app = self.start("POR")
                self.assertEqual(app.settings["autosave"], choice)
                self.world.turn = 16
                self.assertEqual(self.seasons(5), saves_seen)


class MapModeTest(CampaignCase):
    def test_keys_1_to_4_switch_the_map_mode_and_redraw_the_map(self):
        import pygame
        from hexa.campaign.mapview import MODES
        app = self.start("POR")
        view = app.view
        view.zoom = 1                                         # zoomed out the map is one cached picture
        app.look_at(self.world.countries["POR"].capital)
        seen = []

        def snap():
            seen.append((view.mode, view._key, hashlib.sha1(pygame.image.tobytes(view._cache, "RGB")).hexdigest()))

        self.driver.at(1, snap)
        for frame, k in enumerate("2341", start=1):
            self.driver.at(frame, key(k))
            self.driver.at(frame + 1, snap)
        self.play(7)

        modes = [mode for mode, _, _ in seen]
        self.assertEqual(modes, ["political", "terrain", "goods", "markets", "political"])
        stamp = view.fog_stamp()
        self.assertEqual([k for _, k, _ in seen], [(1, mode, stamp) for mode in modes],
                         "the cached map is redrawn for each mode")
        pictures = {mode: picture for mode, _, picture in seen}
        self.assertEqual(seen[0][2], seen[-1][2], "political again looks as it did")
        self.assertEqual(len(set(pictures.values())), len(MODES), "each mode looks different")
        for mode in MODES:                 # and each is that mode's map, not a stale one
            view.mode = mode
            fresh = hashlib.sha1(pygame.image.tobytes(view._render(), "RGB")).hexdigest()
            self.assertEqual(pictures[mode], fresh, mode)

    def test_pressing_3_again_cycles_the_goods_view(self):
        app = self.start("POR")
        view = app.view
        view.zoom = 1
        app.look_at(self.world.countries["POR"].capital)
        seen = []
        for frame, k in enumerate("333323", start=1):
            self.driver.at(frame, key(k))
            self.driver.at(frame + 1, lambda: seen.append((view.mode, view.goods_view, view._key)))
        self.play(9)

        self.assertEqual([(mode, goods) for mode, goods, _ in seen],
                         [("goods", "chips"), ("goods", "deposits"), ("goods", "prices"), ("goods", "chips"),
                          ("terrain", "chips"), ("goods", "chips")],
                         "3 cycles the goods view only when the goods map is already on")
        stamp = view.fog_stamp()
        self.assertEqual([k for _, _, k in seen], [(1, mode, stamp) for mode, _, _ in seen],
                         "zoomed out, the goods views share one cached picture: no redraw for a new view")

    def test_the_close_up_goods_map_shows_each_goods_view(self):
        """Was a crash (found by these tests, never filed, fixed on master by v0.1.4): the goods map raised a
        KeyError at the tile zoom levels (zoom 3 and up; choosing a country starts at zoom 4), because
        MapView._mode_layer looked the good of every province on screen up in ABBR (chips and prices) and DEPOSITS
        (deposits), and neither table had the 17 goods added since (stone, olives, horses, ...)."""
        import pygame
        from hexa.campaign import mapview
        from hexa.campaign.app import PANEL_W, TOP, WIDTH
        app = self.start("POR")                              # zoom 4: the tile map, Lisbon in the middle
        view = app.view
        self.assertEqual((view.zoom, view.mode, view.goods_view), (4, "political", "chips"))
        land = pygame.Rect(300, TOP + 34, WIDTH - PANEL_W - 10 - 300, 470)   # Portugal and Spain, no buttons
        seen = []

        def snap():
            area = app.screen.subsurface(land)
            seen.append((view.mode, view.goods_view, hashlib.sha1(pygame.image.tobytes(area, "RGB")).hexdigest()))

        # The landscape art is made a few hexes a frame, as many as LAND_BUILD_MS of real time allows: lift that
        # limit so that every frame draws the whole picture whatever the machine's speed, and give every view 8
        # frames before looking at it.
        frame = 8
        for k in ("3", None, "3", "3", "3", "2", "3"):
            if k:
                self.driver.at(frame, key(k))
            frame += 8
            self.driver.at(frame, snap)
        with mock.patch.object(mapview, "LAND_BUILD_MS", 1e9):
            self.play(frame + 2)

        self.assertEqual([(mode, goods) for mode, goods, _ in seen],
                         [("goods", "chips"), ("goods", "chips"), ("goods", "deposits"), ("goods", "prices"),
                          ("goods", "chips"), ("terrain", "chips"), ("goods", "chips")],
                         "3 cycles the goods view only when the goods map is already on")
        pictures = [picture for _, _, picture in seen]
        self.assertEqual(pictures[0], pictures[1], "the picture is steady while nothing changes")
        self.assertEqual(len({pictures[1], pictures[2], pictures[3], pictures[5]}), 4,
                         "chips, deposits, prices and the terrain map all look different")
        self.assertEqual(pictures[4], pictures[1], "back to chips: the chips again")
        self.assertEqual(pictures[6], pictures[1])

    def test_the_mode_buttons_and_the_goods_view_buttons_in_the_top_bar(self):
        app = self.start("POR")
        app.view.zoom = 1
        app.look_at(self.world.countries["POR"].capital)
        seen = []
        record = lambda: seen.append((app.view.mode, app.view.goods_view,                       # noqa: E731
                                      [b.label for b in app.ui.buttons if b.action[0] == "goods_view"]))
        script = [self.on_button("Terrain", ("mode", "terrain")), self.on_button("Goods", ("mode", "goods")),
                  self.on_button("Prices", ("goods_view",)), self.on_button("Markets", ("mode", "markets")),
                  key("3"),                                  # from another map: the goods map, as it was left
                  self.on_button("Deposits", ("goods_view",)), self.on_button("Political", ("mode",))]
        for frame, events in enumerate(script, start=1):
            self.driver.at(frame, events)
            self.driver.at(frame + 1, record)
        self.play(len(script) + 3)

        views = ["Chips", "Deposits", "Prices"]
        self.assertEqual(seen, [("terrain", "chips", []), ("goods", "chips", views), ("goods", "prices", views),
                                ("markets", "prices", []), ("goods", "prices", views), ("goods", "deposits", views),
                                ("political", "deposits", [])])


class ZoomTest(CampaignCase):
    MOUSE = (700, 500)            # on the map, left of the panel, above the minimap

    def test_the_wheel_zooms_around_the_hex_under_the_mouse(self):
        from hexa.campaign.mapview import ZOOMS
        app = self.start("POR")
        under = app.hex_under(self.MOUSE)
        seen = []
        steps = (-1, -1, -1, 1, 1, 1, 1, 1)                  # out to zoom 1, in to the closest zoom, once more
        for frame, dy in enumerate(steps):
            self.driver.at(frame, wheel(dy, pos=self.MOUSE))
            self.driver.at(frame + 1, lambda: seen.append((app.view.zoom, app.hex_under(self.MOUSE))))
        self.play(len(steps) + 2)

        closest = len(ZOOMS) - 1
        self.assertEqual([zoom for zoom, _ in seen], [3, 2, 1, 2, 3, 4, closest, closest])
        self.assertEqual([pos for _, pos in seen], [under] * len(steps), "the hex under the mouse stays under it")

    def test_plus_and_minus_zoom_around_the_middle_of_the_map(self):
        app = self.start("POR")
        middle = app.view_rect().center
        lisbon = self.world.countries["POR"].capital
        self.assertEqual(app.hex_under(middle), lisbon)
        seen = []
        presses = ("-", "-", "-", "+", "=", "+", "+")       # = is + without shift
        for frame, k in enumerate(presses):
            self.driver.at(frame, key(k))
            self.driver.at(frame + 1, lambda: seen.append((app.view.zoom, app.hex_under(middle))))
        self.play(len(presses) + 2)

        self.assertEqual([zoom for zoom, _ in seen], [3, 2, 1, 2, 3, 4, 5])
        self.assertEqual([pos for _, pos in seen], [lisbon] * len(presses))

    def test_the_wheel_over_an_open_panel_does_not_zoom(self):
        app = self.start("POR")
        panel = app.panel_rect()
        over = (panel.centerx, panel.centery)
        self.assertEqual(app.ui.panel, "country")
        seen = []
        record = lambda: seen.append((app.ui.panel, app.view.zoom))           # noqa: E731
        self.driver.at(0, wheel(1, pos=over))
        self.driver.at(1, record)
        self.driver.at(1, key("escape"))                     # close the panel: the same wheel turn now zooms
        self.driver.at(2, wheel(1, pos=over))
        self.driver.at(3, record)
        self.play(5)
        self.assertEqual(seen, [("country", 4), (None, 5)])


class PanelTest(CampaignCase):
    def state(self):
        """What the side panel shows, and the pause menu (None: closed)."""
        ui = self.app.ui
        shows = {"province": lambda: ui.province.pos, "country": lambda: ui.country,
                 "market": lambda: ui.market.name}.get(ui.panel, lambda: None)()
        return ui.panel, shows, self.app.menu

    def province_on_screen(self, owner):
        """The first province of owner (by position) on the visible map with no unit on it."""
        world = self.world
        for prov in sorted(world.provinces.values(), key=lambda p: p.pos):
            if prov.owner == owner and not world.units_at(prov.pos) and self.on_map(hex_pixel(self.app, prov.pos)):
                return prov
        raise AssertionError(f"no province of {owner} on screen")

    def test_escape_closes_your_country_and_its_button_and_c_open_it_again(self):
        self.start("POR")
        seen = []
        self.driver.at(0, lambda: seen.append(self.state()))     # choosing Portugal opened its panel
        self.driver.at(0, key("escape"))
        self.driver.at(1, lambda: seen.append(self.state()))
        self.driver.at(1, self.on_button(action=("panel", "country")))       # the flag left of the name
        self.driver.at(2, lambda: seen.append(self.state()))
        self.driver.at(2, key("escape"))
        self.driver.at(3, lambda: seen.append(self.state()))
        self.driver.at(3, key("c"))
        self.driver.at(4, lambda: seen.append(self.state()))
        self.play(6)

        opened, closed = ("country", "POR", None), (None, None, None)
        self.assertEqual(seen, [opened, closed, opened, closed, opened], "and Esc never opened the pause menu")

    def test_the_ledger_button_and_l_open_and_close_the_ledger(self):
        self.start("POR")
        seen = []
        self.driver.at(1, self.on_button("Ledger"))
        self.driver.at(2, lambda: seen.append(self.app.ui.panel))
        self.driver.at(2, self.on_button("Ledger"))
        self.driver.at(3, lambda: seen.append(self.app.ui.panel))
        self.driver.at(3, key("l"))
        self.driver.at(4, lambda: seen.append(self.app.ui.panel))
        self.driver.at(4, key("l"))
        self.driver.at(5, lambda: seen.append(self.app.ui.panel))
        self.play(7)
        self.assertEqual(seen, ["ledger", None, "ledger", None])

    def test_the_market_buttons_open_your_home_market(self):
        self.start("POR")
        lisbon = self.world.provinces[self.world.countries["POR"].capital]
        seen = []
        self.driver.at(1, self.on_button("Open your home market"))           # in your country's panel
        self.driver.at(2, lambda: seen.append(self.state()))
        self.driver.at(2, key("escape"))
        self.driver.at(3, lambda: seen.append(self.state()))
        self.driver.at(3, self.on_button("Market", ("panel", "market")))     # the top bar
        self.driver.at(4, lambda: seen.append(self.state()))
        self.play(6)

        self.assertEqual(lisbon.market.name, "Lisbon")
        self.assertEqual(seen, [("market", "Lisbon", None), (None, None, None), ("market", "Lisbon", None)])

    def test_clicking_a_province_opens_its_panel_and_its_buttons_lead_on(self):
        app = self.start("POR")
        own, foreign = self.province_on_screen("POR"), self.province_on_screen("CAS")
        seen = []
        record = lambda: seen.append(self.state())           # noqa: E731
        self.driver.at(1, self.on_hex(own.pos))
        self.driver.at(2, record)
        self.driver.at(2, self.on_button(action=("market", own.market)))     # "Open the Lisbon market"
        self.driver.at(3, record)
        self.driver.at(3, key("escape"))
        self.driver.at(4, record)
        self.driver.at(4, self.on_hex(foreign.pos))
        self.driver.at(5, record)
        self.driver.at(5, self.on_button(action=("country", "CAS")))        # "Diplomacy with Castile"
        self.driver.at(6, record)
        self.driver.at(6, self.on_hex(foreign.pos))
        self.driver.at(7, record)
        self.driver.at(7, self.on_button("×"))                              # the province panel's close button
        self.driver.at(8, record)
        self.play(10)

        self.assertEqual(seen, [("province", own.pos, None), ("market", own.market.name, None), (None, None, None),
                                ("province", foreign.pos, None), ("country", "CAS", None),
                                ("province", foreign.pos, None), (None, None, None)])
        self.assertIsNone(app.ui.selected, "clicking provinces selected no unit")


class OrdersTest(CampaignCase):
    """Castile's stack of five starts at (131, 59) and moves 4 a season. A right-click beyond this season's reach
    sends it there over the coming seasons (unit.goal); End season walks it on (CampaignApp._advance_orders)."""

    def order(self, goal):
        app = self.start("CAS")
        world = self.world
        app.view.zoom = 2                                    # zoomed out: a goal seasons away is on screen
        app.look_at(CASTILE_STACK)
        stack = world.units_at(CASTILE_STACK)
        self.assertEqual(len(stack), 5)
        self.assertNotIn(goal, world.reachable_group(stack), "too far for this season ...")
        self.assertTrue(world.path_to(stack, goal), "... but the map shows a route of at most 4 seasons")
        return app, stack

    def march(self, goal, seasons):
        """Select the stack, right-click goal, then End season `seasons` times. Returns, after the right-click and
        after each season: (turn, the hexes the stack is on, its goals)."""
        app, stack = self.order(goal)
        world = self.world
        trail, toasts = [], []
        record = lambda: trail.append((world.turn, {u.pos for u in stack}, {u.goal for u in stack}))   # noqa: E731
        self.driver.at(0, self.on_hex(CASTILE_STACK))
        self.driver.at(1, self.on_hex(goal, button=3))
        self.driver.at(2, record)
        self.driver.at(2, lambda: toasts.append(app.ui.toast))
        for i in range(seasons):
            self.driver.at(2 + i, key("space"))
            self.driver.at(3 + i, record)
        self.play(seasons + 30, until=lambda: len(trail) == seasons + 1)
        self.assertEqual(self.driver.stopped_by, "until")
        self.assertEqual(toasts, ["On their way: they keep moving there in the coming seasons."])
        return trail

    def test_a_far_destination_is_reached_over_several_seasons(self):
        goal = (128, 51)                                     # north, in Castile all the way
        trail = self.march(goal, 5)
        distance = self.world.cost_field(goal)
        self.assertTrue(all(len(hexes) == 1 for _, hexes, _ in trail), f"the stack stays together: {trail}")
        hexes = [next(iter(h)) for _, h, _ in trail]
        arrived = hexes.index(goal) if goal in hexes else None
        self.assertIsNotNone(arrived, f"never got there: {hexes}")
        self.assertGreaterEqual(arrived, 2, "a walk of several seasons")
        self.assertNotEqual(hexes[0], CASTILE_STACK, "the first leg starts at once")
        on_the_way = [distance[pos] for pos in hexes[:arrived + 1]]
        self.assertEqual(on_the_way, sorted(set(on_the_way), reverse=True), f"closer every season: {hexes}")
        self.assertEqual([goals for _, _, goals in trail],
                         [{goal}] * arrived + [{None}] * (len(trail) - arrived), "the order ends on arrival")
        self.assertEqual(hexes[arrived:], [goal] * (len(trail) - arrived), "and the stack stays there")
        self.assertEqual([turn for turn, _, _ in trail], list(range(1, len(trail) + 1)))

    @unittest.expectedFailure
    def test_an_order_whose_route_goes_around_foreign_land_gets_there(self):
        """New bug, no GitHub issue filed yet: orders walk a cost field (world.cost_field, used by
        step_toward_group) that ignores land the stack may not enter. Castile's route to (134, 52) has to go round
        Aragon, as the route the map shows does (world.path_to), but the stack heads straight for the Aragonese
        border at (134, 57). There every hex it may enter is farther from the goal, so _advance_orders finds no
        step, quietly drops the order at the end of the first season and leaves the stack at the border."""
        goal = (134, 52)
        trail = self.march(goal, 6)
        self.assertEqual(trail[-1][1:], ({goal}, {None}), f"6 seasons later; (turn, hexes, goals): {trail}")


if __name__ == "__main__":
    unittest.main()
