"""The HUD of the Age of Discovery window (hexa/campaign/hud/): the resource chips of the top bar and their hover cards,
the floating ribbons and the action log, drawn by the real window and driven by its real input handlers. The numbers
behind them (resources.py, feed.py) are tested in tests/test_hud_data.py. Portugal (POR) is the player.

Run with: python -m unittest tests.ui.test_hud
"""
import unittest
from unittest import mock

from tests.support import harness
from tests.support.harness import hex_pixel, wheel


class HudCase(harness.UITestCase):
    def setUp(self):
        super().setUp()
        import play
        from hexa.campaign.app import CampaignApp
        self.app = CampaignApp(play.TILES_DIR, "POR")
        self.world, self.bus = self.app.world, self.app.world.bus
        self.frame()

    def tearDown(self):
        self.assertEqual(self.bus.tap_errors, [], "a tap of the HUD's data raised")
        super().tearDown()

    def frame(self, ms=0):
        self.driver.now += ms
        self.app.process_events()
        self.app.draw()

    def button(self, label=None, action=None):
        return harness.button_rect(self.app, label, action)

    def press(self, label=None, action=None):
        self.app.left_click(self.button(label, action).center)
        self.frame()

    def own_provinces(self):
        return sorted(self.world.provinces_of("POR"), key=lambda p: p.pos)

    def on_screen(self, pos):
        """Whether hex pos is where ribbons may float: inside the view, clear of the panel and the log."""
        from hexa.campaign.hud import floating
        return floating.can_see(self.app, type("Item", (), {"pos": pos, "mine": True})())

    def open_log(self):
        self.press("Open the log")
        self.frame()
        return self.app.hud.log.box

    def aim_the_camera(self, pos, pixel):
        '''Scroll so that hex `pos` is under `pixel`.'''
        x, y = self.app.view.center(pos)
        view = self.app.view_rect()
        self.app.camera[:] = [x - (pixel[0] - view.x), y - (pixel[1] - view.y)]
        self.app.clamp()
        self.frame()
        got = hex_pixel(self.app, pos)
        self.assertLess(abs(got[0] - pixel[0]) + abs(got[1] - pixel[1]), 3, "the camera is where it was asked to be")

    def hex_on_screen(self, skip=()):
        for prov in self.own_provinces():
            if prov.pos not in skip and self.on_screen(prov.pos):
                return prov.pos
        raise AssertionError("no Portuguese hex on screen")


class TopBarTest(HudCase):
    def test_the_chips_open_their_panels(self):
        ui = self.app.ui
        for label, panel in (("Ledger", "ledger"), ("Prestige", "ledger"), ("Army", "country"),
                             ("Provinces", "country"), ("Market", "market")):
            with self.subTest(chip=label):
                ui.panel = None
                self.press(label)
                self.assertEqual(ui.panel, panel)
        ui.panel = None
        self.press("Research")
        self.assertTrue(self.app.tech_open, "the research chip opens the technology screen")

    def test_the_old_buttons_still_work(self):
        self.press("Ledger")
        self.assertEqual(self.app.ui.panel, "ledger")
        self.press("Terrain", ("mode", "terrain"))
        self.assertEqual(self.app.view.mode, "terrain")
        turn = self.world.turn
        self.press("End season")
        self.assertEqual(self.world.turn, turn + 1)
        self.press("Menu")
        self.assertEqual(self.app.menu, "main")

    def test_a_chip_shows_its_value_and_what_changed(self):
        from hexa.campaign.data import troop
        snap = self.app.game.tracker.snapshot("POR")
        self.assertEqual(snap["regiments"].delta, 0)
        self.world.recruit("POR", self.own_provinces()[0], troop("infantry", 1))
        self.frame()
        from hexa.campaign.hud import topbar
        snap, _ = topbar.readings(self.app, self.app.hud)
        self.assertEqual(snap["regiments"].delta, 1)
        self.assertEqual(topbar.change("regiments", snap["regiments"], True), ("(+1)", topbar.GOOD_C))
        self.assertLess(snap["ducats"].delta, 0)

    def test_green_up_red_down_grey_nothing_and_goods_the_other_way(self):
        from hexa.campaign import resources
        from hexa.campaign.hud import topbar
        up, down, none = (resources.Reading(1, d, []) for d in (4.0, -4.0, 0.0))
        self.assertEqual(topbar.change("ducats", up, True), ("(+4)", topbar.GOOD_C))
        self.assertEqual(topbar.change("ducats", down, True), ("(-4)", topbar.BAD_C))
        self.assertEqual(topbar.change("ducats", none, True), ("(±0)", topbar.FAINT))
        self.assertEqual(topbar.change("horses", resources.Reading(2.5, 0.3, []), False), ("(+0.3)", topbar.BAD_C),
                         "a dearer horse is bad news")
        self.assertEqual(topbar.change("horses", resources.Reading(2.5, -0.3, []), False)[1], topbar.GOOD_C)

    def test_research_shows_what_was_gained_not_what_a_tech_cost(self):
        from hexa.campaign import resources
        from hexa.campaign.hud import topbar
        lines = [resources.Line("income", "Research points", 6.0, None),
                 resources.Line("oneoff", "Finished", -40, None)]
        reading = resources.Reading(10, -34.0, lines)
        self.assertEqual(topbar.change("research", reading, False), ("(+6.0)", topbar.GOOD_C))

    def test_hovering_the_ducats_chip_shows_the_seasons_lines(self):
        from hexa.campaign.data import troop
        self.press("End season")
        self.world.recruit("POR", self.own_provinces()[0], troop("infantry", 1))
        self.app.ui.mouse = self.button("Ledger").center
        for _ in range(3):
            self.frame(200)
        chip = next(b for b in self.app.ui.buttons if b.label == "Ledger")
        title, lines = chip.hint
        self.assertTrue(title.startswith("Ducats"), title)
        labels = [text.split("\t")[0] for text, colour in lines if colour is not None]
        for wanted in ("Income", "Spending", "One-off this season"):
            self.assertIn(wanted, labels)
        self.assertTrue(any(label.startswith("Raising troops") for label in labels))
        self.assertTrue(lines[-1][0].startswith("Next season, expected:"), lines[-1])
        self.assertIsNone(next(b for b in self.app.ui.buttons if b.label == "Army").hint or None,
                          "only the chip under the mouse builds its card")

    def test_every_chip_has_a_card(self):
        from hexa.campaign.hud import topbar
        snap, expected = topbar.readings(self.app, self.app.hud)
        for name, _glyph, _label, _action, footer in topbar.CHIPS + topbar.GOODS:
            title, lines = topbar.card(self.app, name, snap, expected, footer)
            self.assertTrue(title and lines, name)
            self.assertTrue(lines[-1][0].endswith(footer), name)

    def test_the_bar_fits_at_1280_and_1024(self):
        import hexa.campaign.app as appmod
        import pygame
        old = (appmod.WIDTH, appmod.HEIGHT)
        self.addCleanup(lambda: setattr(appmod, "WIDTH", old[0]) or setattr(appmod, "HEIGHT", old[1]))
        for width, height, goods in ((1280, 720, True), (1024, 700, False)):
            for size in (15, 17, 19):
                with self.subTest(width=width, font=size):
                    appmod.WIDTH, appmod.HEIGHT = width, height
                    self.app.screen = pygame.display.set_mode((width, height))
                    self.app.small = pygame.font.SysFont("segoeui", size - 3)
                    self.app.bold = pygame.font.SysFont("segoeui", size, bold=True)
                    self.app.draw()
                    bar = [b for b in self.app.ui.buttons if b.rect.y < appmod.TOP]
                    for i, a in enumerate(bar):
                        self.assertLessEqual(a.rect.right, width, a.label)
                        for b in bar[i + 1:]:
                            self.assertFalse(a.rect.colliderect(b.rect), f"{a.label} overlaps {b.label}")
                    names = [b.label for b in bar]
                    for needed in ("Ledger", "Terrain", "Menu", "End season" if size < 19 else "End"):
                        if needed == "End" and "End season" in names:
                            continue
                        self.assertTrue(any(n.startswith(needed) for n in names), (needed, names))
                    if size == 15:
                        self.assertEqual("Horses" in names, goods, "the key goods go first at 1024")

    def test_the_end_of_the_bar_stays_put_with_every_chip_dropped(self):
        import hexa.campaign.app as appmod
        import pygame
        old = (appmod.WIDTH, appmod.HEIGHT)
        self.addCleanup(lambda: setattr(appmod, "WIDTH", old[0]) or setattr(appmod, "HEIGHT", old[1]))
        appmod.WIDTH, appmod.HEIGHT = 800, 600
        self.app.screen = pygame.display.set_mode((800, 600))
        self.app.draw()
        bar = [b for b in self.app.ui.buttons if b.rect.y < appmod.TOP]
        self.assertTrue(all(b.rect.right <= 800 for b in bar))
        self.assertIn("Menu", [b.label for b in bar])


class FloatingTest(HudCase):
    def live(self):
        return [(item.text, item.colour_kind) for item, _start, _lane in self.app.hud.floaters.live]

    def test_the_motion_follows_the_sheet(self):
        from hexa.campaign.hud import floating
        rise, scale, alpha = floating.motion(0)
        self.assertEqual((rise, alpha), (0, 0))
        self.assertAlmostEqual(scale, 0.6)
        self.assertEqual(floating.motion(0.06)[1:], (1.2, 255))
        self.assertEqual(floating.motion(0.14)[1], 1.0)
        self.assertEqual(floating.motion(0.6)[2], 255, "it holds until 0.6 s")
        self.assertEqual(floating.motion(1.1)[2], 0, "and is gone by 1.1 s")
        rise = [floating.motion(t / 20)[0] for t in range(23)]
        self.assertEqual(rise, sorted(rise))
        self.assertAlmostEqual(rise[-1], floating.RISE)
        self.assertGreater(floating.motion(0.55)[0] - floating.motion(0.5)[0],
                           floating.motion(1.1)[0] - floating.motion(1.05)[0], "an ease-out: fast, then slowing")

    def test_all_six_kinds_have_a_ribbon(self):
        from hexa.campaign import feed
        from hexa.campaign.hud import floating, style
        for kind in feed.COLOUR_KINDS:
            img = floating.ribbon(self.app.hud.floaters.font, "Recruited", kind)
            self.assertGreater(img.get_width(), 60)
            self.assertEqual(style.colour(kind), style.KINDS[kind][0])
        self.assertEqual(len({style.colour(k) for k in feed.COLOUR_KINDS}), 6)

    def test_a_ribbon_rises_from_its_hex_and_is_gone_after_a_second_and_a_tenth(self):
        pos = self.hex_on_screen()
        before = self.app.screen.copy()
        self.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=1)
        self.frame()
        self.assertEqual(self.live(), [("Recruited", "own")])
        self.frame(400)
        self.assertNotEqual(pygame_bytes(self.app.screen), pygame_bytes(before), "the ribbon is drawn")
        self.frame(800)
        self.assertEqual(self.live(), [], "gone after 1.1 s")

    def test_several_at_one_hex_queue_and_at_most_three_fly(self):
        pos = self.hex_on_screen()
        for i in range(5):
            self.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=i)
        self.frame()
        floaters = self.app.hud.floaters
        self.assertEqual(len(floaters.live), 3, "the rest are only log lines")
        starts = [start for _item, start, _lane in floaters.live]
        self.assertEqual([b - a for a, b in zip(starts, starts[1:])], [300, 300], "0.3 s apart")
        self.assertEqual([lane for _item, _start, lane in floaters.live], [0, 1, 2])
        self.assertGreaterEqual(len(next(iter(self.app.game.feed.entries("all")))[2]), 5, "all five are in the log")

    def test_nothing_floats_for_a_hex_the_camera_cannot_see(self):
        far = max(self.own_provinces(), key=lambda p: abs(p.pos[0] - self.world.countries["POR"].capital[0]))
        self.app.look_at((10, 10))
        self.frame()
        self.assertFalse(self.on_screen(far.pos))
        self.bus.emit("unit_raised", "POR", far.pos, what="Pikemen", id=1)
        self.frame()
        self.assertEqual(self.live(), [])
        self.assertIn("unit_raised", [i.kind for i in self.app.game.feed.entries("all")[0][2]], "but the log has it")

    def test_nothing_floats_under_the_open_panel(self):
        self.app.ui.panel, self.app.ui.country = "country", "POR"
        under = next(p.pos for p in self.world.provinces.values()
                     if self.app.panel_rect().collidepoint(hex_pixel(self.app, p.pos))
                     and self.app.view_rect().collidepoint(hex_pixel(self.app, p.pos)))
        self.bus.emit("unit_raised", "POR", under, what="Pikemen", id=1)
        self.frame()
        self.assertEqual(self.live(), [])

    def test_a_fogged_hex_of_someone_else_floats_nothing(self):
        from hexa.campaign import feed
        hidden = next(pos for pos in self.world.terrain if pos not in self.world.visible
                      and self.on_screen_ignoring_fog(pos))
        item = feed.FeedItem("battle", "war", "Battle!", hidden, "CAS", 1, "x", False, True)
        self.app.hud.floaters.add(self.app, [item], self.driver.now)
        self.assertEqual(self.live(), [])

    def on_screen_ignoring_fog(self, pos):
        from hexa.campaign.hud import floating
        x, y = floating.screen_point(self.app, pos)
        return self.app.view_rect().inflate(-200, -200).collidepoint(x, y) and not (
            self.app.ui.panel and self.app.panel_rect().collidepoint(x, y))

    def test_ribbons_follow_the_camera(self):
        pos = self.hex_on_screen()
        from hexa.campaign.hud import floating
        self.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=1)
        self.frame()
        where = floating.screen_point(self.app, pos)
        self.app.camera[0] += 40
        self.assertEqual(floating.screen_point(self.app, pos)[0], where[0] - 40)
        self.frame(200)
        self.assertEqual(len(self.live()), 1, "still flying, over the same hex")

    def test_readable_over_every_ground(self):
        """A ribbon is an opaque dark pill with an edge in its kind's colour, so what is under it cannot change how it
        reads (the screenshots in mockups/shots show it over grass, snow, sea and towns)."""
        from hexa.campaign import feed
        from hexa.campaign.hud import floating
        img = floating.ribbon(self.app.hud.floaters.font, "Captured!", "war")
        self.assertEqual(img.get_at((img.get_width() // 2, 3))[3], 255, "an opaque edge")
        self.assertLess(sum(img.get_at((20, 14))[:3]), 150, "a dark pill")
        self.assertEqual(len(feed.COLOUR_KINDS), 6)


def pygame_bytes(surface):
    import pygame
    return pygame.image.tobytes(surface, "RGB")


class ActionLogTest(HudCase):
    def tell(self, count=3):
        pos = self.own_provinces()[0].pos
        for i in range(count):
            self.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=i)
        self.bus.emit("battle", "CAS", pos, defender="POR", ranged=False, lost=(1, 0), hurt=(2, 0))
        self.frame()

    def test_collapsed_by_default_with_a_badge_for_new_lines(self):
        self.assertFalse(self.app.hud.log.open)
        self.tell(3)
        self.assertEqual(self.app.game.feed.unread, 5, "the four, and \"You lead\"")
        self.press("Open the log")
        self.assertTrue(self.app.hud.log.open)
        self.frame()
        self.assertEqual(self.app.game.feed.unread, 0, "open: read")
        self.press("Collapse the log")
        self.assertFalse(self.app.hud.log.open)
        self.assertEqual(self.app.game.feed.unread, 0)
        self.bus.emit("forage", "POR", self.own_provinces()[0].pos)
        self.frame()
        self.assertEqual(self.app.game.feed.unread, 1)

    def test_the_filters_narrow_the_lines(self):
        from hexa.campaign.hud import actionlog
        self.tell(3)
        self.press("Open the log")
        feed = self.app.game.feed
        counts = {}
        for name in ("all", "war", "money", "mine"):
            self.app.left_click(self.button(action=("log", "filter", name)).center)
            self.frame()
            self.assertEqual(self.app.hud.log.filter, name)
            counts[name] = sum(1 for kind, _row in actionlog.rows_of(feed, name) if kind == "item")
        self.assertEqual(counts, {"all": 6, "war": 1, "money": 3, "mine": 6}, "the first lines are in them")

    def test_the_log_is_grouped_by_season(self):
        from hexa.campaign.hud import actionlog
        self.tell(2)
        self.press("End season")
        self.tell(1)
        rows = actionlog.rows_of(self.app.game.feed, "all")
        heads = [row for kind, row in rows if kind == "head"]
        self.assertEqual(len(heads), 2)
        self.assertEqual(rows[0], ("head", self.world.date()), "the newest season first")

    def test_a_place_name_moves_the_camera_and_selects_the_stack(self):
        stack = next(u for u in self.world.units if u.owner == "POR")
        self.bus.emit("unit_raised", "POR", stack.pos, what="Pikemen", id=1)
        self.app.look_at((10, 10))
        self.frame()
        self.press("Open the log")
        row = self.button(action=("log", "goto", stack.pos))
        self.app.left_click(row.center)
        for _ in range(8):
            self.frame(60)
        self.assertEqual(self.app.hud.glide, None, "the glide is over")
        centre = hex_pixel(self.app, stack.pos)
        view = self.app.view_rect()
        self.assertLess(abs(centre[0] - view.centerx), 3)
        self.assertLess(abs(centre[1] - view.centery), 3)
        self.assertIn(stack, self.app.ui.group)

    def test_the_wheel_scrolls_the_log_not_the_map(self):
        self.tell(10)
        self.press("Open the log")
        box = self.app.hud.log.box
        zoom = self.app.view.zoom
        self.driver.now += 10
        self.app.ui.mouse = box.center
        for event in wheel(-1, pos=box.center):
            self.app.handle(event)
        self.assertEqual(self.app.view.zoom, zoom)
        self.assertGreater(self.app.hud.log.scroll, 0)
        self.app.ui.mouse = (600, 200)
        for event in wheel(1, pos=(600, 200)):
            self.app.handle(event)
        self.assertEqual(self.app.view.zoom, zoom + 1 if zoom < 5 else zoom, "elsewhere it still zooms")

    def test_a_click_in_the_box_does_not_reach_the_map(self):
        self.tell(2)
        self.press("Open the log")
        box = self.app.hud.log.box
        self.app.ui.panel = None
        self.app.left_click((box.centerx, box.y + 20))              # the header, between buttons
        self.assertIsNone(self.app.ui.panel)
        self.assertIsNone(self.app.ui.province)

    def test_the_first_lines_of_the_game_are_in_the_log(self):
        self.assertTrue(self.world.log)
        self.frame()
        self.assertFalse(self.app.hud.log.open)
        sentences = [item.sentence for _, _, items in self.app.game.feed.entries("all") for item in items]
        self.assertTrue(any("age of discovery begins" in s for s in sentences), sentences)

    def test_what_the_rules_say_without_an_event_shows_in_the_log(self):
        self.press("End season")
        sentences = [item.sentence for _, _, items in self.app.game.feed.entries("money") for item in items]
        self.assertTrue(any("Treasury" in s for s in sentences), "the line of each season")
        self.world.message("Idea adopted: Test.", "POR", "idea")
        self.assertIn("Idea adopted: Test.", [i.sentence for _, _, items in self.app.game.feed.entries("mine")
                                              for i in items])

    def test_choosing_a_country_tells_the_player_in_the_log(self):
        sentences = [item.sentence for _, _, items in self.app.game.feed.entries("all") for item in items]
        self.assertTrue(any(s.startswith("You lead Portugal") for s in sentences), sentences)


class CoverTest(HudCase):
    def war_unit(self):
        return next(u for u in self.world.units if u.owner == "POR" and u.kind.war)

    def right_click(self, pixel):
        for event in harness.click(pixel, 3):
            self.app.handle(event)
        self.frame()

    def test_covers_is_the_log_the_minimap_and_the_top_bar(self):
        hud, app = self.app.hud, self.app
        box = self.open_log()
        self.assertTrue(hud.covers(app, box.center))
        self.assertTrue(hud.covers(app, app.minimap_rect().center))
        self.assertTrue(hud.covers(app, (300, 10)))
        self.assertFalse(hud.covers(app, (box.right + 40, box.y - 40)))
        self.press("Collapse the log")
        bar = self.app.hud.log.box
        self.assertTrue(hud.covers(app, bar.center))
        self.assertFalse(hud.covers(app, (bar.x + 5, bar.y - 40)), "the open box is gone")
        self.assertIsNone(app.hex_under(bar.center))
        self.assertIsNone(app.hex_under((300, 10)))

    def test_a_right_click_under_the_open_log_gives_no_order(self):
        app = self.app
        unit = self.war_unit()
        app.select_unit(unit)
        reach = [pos for pos in app.ui.reach if pos != unit.pos]
        self.assertTrue(reach, "the stack can go somewhere this season")
        target = reach[0]
        box = self.open_log()
        self.aim_the_camera(target, box.center)
        start, group = unit.pos, list(app.ui.group)
        self.right_click(box.center)
        self.assertEqual(unit.pos, start, "the log is on top of that hex: no order")
        self.assertEqual(app.ui.group, group, "and the selection stays")
        self.press("Collapse the log")                  # the same pixel is the map again
        self.aim_the_camera(target, box.center)
        self.right_click(box.center)
        self.assertEqual(unit.pos, target, "so the order was possible, and only the log stopped it")

    def test_a_drag_that_starts_on_the_log_does_not_pan_the_map(self):
        import pygame
        app = self.app
        box = self.open_log()
        camera = list(app.camera)
        app.handle(pygame.event.Event(pygame.MOUSEBUTTONDOWN, pos=box.center, button=3, touch=False))
        app.handle(pygame.event.Event(pygame.MOUSEMOTION, pos=(box.centerx + 50, box.centery), rel=(50, 0),
                                      buttons=(0, 0, 1), touch=False))
        self.assertEqual(app.camera, camera)
        self.assertIsNone(app.drag)
        app.handle(pygame.event.Event(pygame.MOUSEBUTTONUP, pos=box.center, button=3, touch=False))
        self.press("Collapse the log")
        app.handle(pygame.event.Event(pygame.MOUSEBUTTONDOWN, pos=(640, 200), button=3, touch=False))
        app.handle(pygame.event.Event(pygame.MOUSEMOTION, pos=(690, 200), rel=(50, 0), buttons=(0, 0, 1), touch=False))
        self.assertNotEqual(app.camera, camera, "elsewhere it pans")
        app.handle(pygame.event.Event(pygame.MOUSEBUTTONUP, pos=(690, 200), button=3, touch=False))

    def test_the_goods_views_never_reach_into_the_panel_and_the_panel_wins_a_click(self):
        app = self.app
        app.view.mode = "goods"
        for panel in ("ledger", "country", "market"):
            with self.subTest(panel=panel):
                app.ui.panel, app.ui.country = panel, "POR"
                if panel == "market":
                    app.ui.market = self.world.provinces[self.world.countries["POR"].capital].market
                self.frame()
                views = [b for b in app.ui.buttons if b.action[0] == "goods_view"]
                self.assertEqual(len(views), 3)
                for b in views:
                    self.assertFalse(b.rect.colliderect(app.panel_rect()), f"{b.label} {b.rect} is in the panel")
        app.ui.panel = "ledger"
        self.frame()
        before = app.view.goods_view
        app.left_click((920, 60))
        self.assertEqual((app.view.goods_view, app.ui.panel), (before, "ledger"), "the click was the panel's")

    def test_a_button_that_pokes_into_the_panel_loses_the_click_there(self):
        from hexa.ui.kit import Button
        app = self.app
        app.ui.panel = "ledger"
        self.frame()
        panel = app.panel_rect()
        pokes = Button(panel.move(-100, 0).inflate(0, 0).copy(), "Pokes", True, ("mode", "terrain"))
        app.ui.buttons.insert(0, pokes)
        app.left_click((panel.x + 20, panel.y + 20))
        self.assertNotEqual(app.view.mode, "terrain")
        app.left_click((panel.x - 20, panel.y + 20))
        self.assertEqual(app.view.mode, "terrain", "outside the panel the button works")


class HiddenMapTest(HudCase):
    def test_the_queue_waits_while_the_tech_screen_is_open(self):
        pos = self.hex_on_screen()
        self.press("Research")
        self.assertTrue(self.app.tech_open)
        self.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=1)
        self.frame(300)
        self.assertEqual(self.app.hud.floaters.live, [])
        self.assertEqual(len(self.app.game.feed._floating), 1, "told, but not shown: it waits")

    def test_the_queue_waits_while_the_menu_is_open_and_floats_when_it_closes(self):
        pos = self.hex_on_screen()
        self.app.open_menu()
        self.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=1)
        self.frame()
        self.assertEqual(self.app.hud.floaters.live, [])
        self.app.menu = None
        self.frame()
        self.assertEqual(len(self.app.hud.floaters.live), 1)

    def test_what_is_old_when_the_map_comes_back_is_dropped(self):
        from hexa.campaign import feed
        pos = self.hex_on_screen()
        self.app.open_menu()
        with mock.patch.object(feed.time, "monotonic", return_value=1000.0):
            self.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=1)
        self.app.menu = None
        with mock.patch.object(feed.time, "monotonic", return_value=1010.0):
            self.frame()
        self.assertEqual(self.app.hud.floaters.live, [], "ten seconds old")


class JumpTest(HudCase):
    def test_a_jump_sets_the_province_as_a_click_on_the_map_does(self):
        prov = self.own_provinces()[3]
        self.app.hud.go(self.app, prov.pos)
        self.assertIs(self.app.ui.province, prov)

    def test_a_zoom_on_the_way_does_not_leave_a_stale_target(self):
        prov = self.own_provinces()[3]
        self.app.look_at((10, 10))
        self.frame()
        self.app.hud.go(self.app, prov.pos)
        self.frame(80)
        self.app.zoom(-1)
        for _ in range(8):
            self.frame(60)
        self.assertIsNone(self.app.hud.glide)
        centre = hex_pixel(self.app, prov.pos)
        view = self.app.view_rect()
        self.assertLess(abs(centre[0] - view.centerx) + abs(centre[1] - view.centery), 4, "centred at the new zoom")


class RibbonCoverTest(HudCase):
    def seen(self, pos):
        from hexa.campaign.hud import floating
        return floating.can_see(self.app, type("Item", (), {"pos": pos, "mine": True})())

    def test_no_ribbon_for_a_hex_under_the_open_log(self):
        pos = self.hex_on_screen()
        box = self.open_log()
        self.aim_the_camera(pos, box.center)
        self.assertFalse(self.seen(pos))
        self.press("Collapse the log")
        self.aim_the_camera(pos, box.center)
        self.assertTrue(self.seen(pos), "the same hex is fine once the box is gone")

    def test_no_ribbon_for_a_hex_under_the_minimap(self):
        pos = self.hex_on_screen()
        mini = self.app.minimap_rect()
        self.aim_the_camera(pos, mini.center)
        self.assertFalse(self.seen(pos))
        self.aim_the_camera(pos, (mini.centerx - 400, mini.centery))
        self.assertTrue(self.seen(pos))


class PlanTest(harness.UITestCase):
    """``topbar.plan``: what goes first as the bar narrows, on chips of known widths."""

    class Chip:
        def __init__(self, main, wide, narrow):
            self.main, self.wide, self.narrow = main, wide, narrow

        def width(self, _ctx, deltas):
            return self.wide if deltas else self.narrow

    def rows(self):
        return [self.Chip(True, 100, 70) for _ in range(6)] + [self.Chip(False, 90, 60) for _ in range(2)]

    def plan(self, room_wide, room_short=None):
        from hexa.campaign.hud import topbar
        short = room_wide - 56 if room_short is None else room_short
        return topbar.plan(None, self.rows(), lambda wide: room_wide if wide else short)

    def test_everything_fits(self):
        self.assertEqual(self.plan(1000), (True, True, True, 6))

    def test_the_key_goods_go_first(self):
        self.assertEqual(self.plan(700), (False, True, True, 6))

    def test_then_the_changes(self):
        self.assertEqual(self.plan(500), (False, False, True, 6))

    def test_then_end_season_becomes_end(self):
        self.assertEqual(self.plan(410, 440), (False, False, False, 6))

    def test_then_chips_go_from_the_right(self):
        self.assertEqual(self.plan(300, 300), (False, False, False, 4))
        self.assertEqual(self.plan(10, 10), (False, False, False, 1))


class IconCacheTest(HudCase):
    def test_a_caller_that_draws_on_an_icon_does_not_spoil_the_next(self):
        import pygame
        from hexa.ui.icons import icon
        first = icon("ducats", 18)
        first.fill((255, 0, 255, 255))
        second = icon("ducats", 18)
        self.assertNotEqual(second.get_at((9, 9)), pygame.Color(255, 0, 255, 255))

    def test_the_cache_is_bounded_registered_and_emptied_on_quit(self):
        from hexa.ui import cache, icons
        for size in range(8, 8 + cache.REGISTRY["icons"].size + 20):
            icons.icon("check", size)
        self.assertLessEqual(cache.stats()["icons"], cache.REGISTRY["icons"].size)
        cache.clear_all()
        self.assertEqual(cache.stats()["icons"], 0)
        icons.icon("check", 16)
        self.assertEqual(cache.stats()["icons"], 1)


class KitFixesTest(HudCase):
    def test_fit_gives_the_ellipsis_alone_when_only_that_fits(self):
        from hexa.ui import kit
        font = self.app.small
        ellipsis = font.size("…")[0]
        self.assertEqual(kit.fit(font, "hello", ellipsis), "…")
        self.assertEqual(kit.fit(font, "hello", ellipsis - 1), "")
        self.assertEqual(kit.fit(font, "hello", 0), "")
        self.assertEqual(kit.fit(font, "hello", 10000), "hello")
        self.assertEqual(kit.fit(font, "", 0), "")

    def test_a_width_of_zero_draws_nothing(self):
        from hexa.ui import kit
        self.assertEqual(kit.text(self.app.screen, self.app.small, "hello", (5, 5), width=0).width, 0)
        self.assertGreater(kit.text(self.app.screen, self.app.small, "hello", (5, 5)).width, 0)

    def test_new_font_clears_the_cache_when_pygame_was_quit(self):
        """Fonts made before a pygame.quit() are dead, so the cached ones go before the font module starts again.
        (The module is only pretended to be down: really quitting it would kill the other windows' fonts.)"""
        import pygame
        from hexa.ui import theme
        theme._fonts["sentinel"] = object()
        with mock.patch.object(pygame.font, "get_init", return_value=False), mock.patch.object(
                pygame.font, "init") as init:
            theme.new_font(14)
        init.assert_called_once()
        self.assertNotIn("sentinel", theme._fonts)
        theme.new_font(14)
        self.assertNotIn("sentinel", theme._fonts)

    def test_pygame_quit_empties_the_font_cache(self):
        """A cached font outliving pygame.quit() crashes the next window that draws with it (the quit callback is
        called directly: really quitting would kill the other windows' fonts)."""
        from hexa.ui import theme
        theme.font(14)
        theme._forget_fonts()
        self.assertEqual(theme._fonts, {})
        theme.font(14)
        self.assertTrue(theme._watching and theme._fonts)


if __name__ == "__main__":
    unittest.main()
