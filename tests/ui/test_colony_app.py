"""The Colonisation window (hexa/colony/app.py) driven through its own run() loop: the ship, landing, founding
and joining, the colony jobs on keys 1 to 7, the homeland market at the east edge, native villages, and the
camera (right-drag, held arrow keys and WASD, minimap clicks).

Every test starts map #5 the way the window does (ColonyApp(screen, tiles, 5, start, goal)), sometimes moves a
unit, fills the stock or moves the camera before the loop starts, then plays the scenario with real mouse and
keyboard events and checks the world and the window state. Map #5:

    "land": your colony at (24, 10) with a soldier in it, a pioneer (23, 9), a scout (23, 10) and an empty
            ship (26, 10), which is selected; the east edge (column 31) is open sea
    "sea":  your ship at (26, 10) with two colonists, a soldier and a pioneer aboard; the beach at (24, 10) is
            one hex west of where the ship can go, at (25, 10)

Run with: python -m unittest tests.ui.test_colony_app
"""
import unittest

from hexa.colony.rules import (COLONIST, COLONIST_FOOD, FOOD_LOT, FOOD_LOT_PRICE, FUR_PRICE, GIFT_CALM, GIFT_COST,
                               GROW_COST, PIONEER, PLAYER, SCOUT, SHIP, SOLDIER, STOCKADE_COST, TRADE_CALM,
                               TRADE_GET, TRADE_GIVE, WOOD_LOT, WOOD_LOT_PRICE)
from hexa.hexgrid import neighbors
from tests.support import harness
from tests.support.harness import click, drag, hex_pixel, hover, key, minimap_pixel
from tests.support.invariants import check_colony

SEED = 5
COLONY = (24, 10)          # your colony on map #5 "land", and the beach the "sea" start lands on
OFFSHORE = (25, 10)        # the sea hex next to it
RICH = {"food": 40, "wood": 40, "furs": 0, "gold": 40}


def minus(stock, cost):
    return {r: n - cost.get(r, 0) for r, n in stock.items()}


def rounded(camera):
    """The camera to a micro-pixel: it moves in float steps, and 4 steps of 30 need not add up to exactly 120."""
    return [round(c, 6) for c in camera]


class ColonyCase(harness.UITestCase):
    def start(self, start="land", goal="survive"):
        import pygame
        import play
        from hexa.colony.app import ColonyApp
        from hexa.colony.render import WINDOW_SIZE
        self.app = ColonyApp(pygame.display.set_mode(WINDOW_SIZE), play.TILES_DIR, SEED, start, goal)
        self.world = self.app.world
        return self.app

    def on_map(self, pixel):
        """Whether pixel is on the visible map, where a click goes to a hex (not the HUD, not the minimap)."""
        from hexa.colony.render import VIEW_H, WINDOW_SIZE, minimap_rect
        x, y = pixel
        return 0 <= x < WINDOW_SIZE[0] and 0 <= y < VIEW_H and not minimap_rect(self.world).collidepoint(pixel)

    def on_hex(self, pos, button=1):
        """A click on map hex pos, where it is on screen when its frame comes."""
        def events():
            pixel = hex_pixel(self.app, pos)
            if not self.on_map(pixel):
                raise AssertionError(f"hex {pos} is at {pixel}, not on the visible map: move the camera first")
            return click(pixel, button)
        return events

    def mine(self, kind):
        found = [u for u in self.world.units_of(PLAYER) if u.type is kind]
        self.assertEqual(len(found), 1, f"map #{SEED} should have one {kind.key} of yours")
        return found[0]

    def play(self, frames, until=None):
        """Run the window's real loop on the script so far; return what run() returned."""
        self.driver.run_for(frames, until)
        result = self.app.run()
        check_colony(self.world)
        return result


class ShipTest(ColonyCase):
    def test_the_ship_sails_with_its_cargo_and_a_passenger_goes_ashore(self):
        app = self.start("sea")
        world = self.world
        ship = app.ui.selected
        self.assertIs(ship.type, SHIP, "the ship is selected at the start")
        cargo = world.cargo(ship)
        self.assertEqual([u.type for u in cargo], [COLONIST, COLONIST, SOLDIER, PIONEER])
        self.assertEqual([b.label for b in app.ui.buttons], ["Colonist", "Colonist", "Soldier", "Pioneer"])
        self.assertEqual(world.reachable(ship)[OFFSHORE], 1)
        colonist = cargo[0]
        seen = []
        self.driver.at(0, self.on_hex(OFFSHORE))
        self.driver.at(1, lambda: seen.append((ship.pos, ship.moves_left, {u.pos for u in cargo})))
        self.driver.at(1, key("1"))                            # the first passenger
        self.driver.at(2, lambda: seen.append((app.ui.selected, dict(app.ui.reach))))
        self.driver.at(2, key("b"))                            # still aboard: can't found here
        self.driver.at(3, self.on_hex(COLONY))                 # a highlighted beach: go ashore
        self.play(5)

        self.assertEqual(seen[0], (OFFSHORE, SHIP.moves - 1, {OFFSHORE}), "the cargo sailed with the ship")
        landing = {p: 1 for p in neighbors(OFFSHORE) if world.is_land(p)}
        self.assertEqual(seen[1], (colonist, {OFFSHORE: 0, **landing}))
        self.assertEqual(world.colonies_of(PLAYER), [], "B did nothing aboard the ship")
        self.assertEqual((colonist.carrier, colonist.pos, colonist.moves_left), (None, COLONY, COLONIST.moves - 1))
        self.assertEqual(world.cargo(ship), cargo[1:])
        self.assertIs(app.ui.selected, colonist)
        self.assertIn(COLONY, world.visible)
        self.assertNotIn("Aboard ship", app.ui.status)

    def test_b_founds_a_colony_ashore_and_j_joins_it(self):
        app = self.start("sea")
        world = self.world
        ship = app.ui.selected
        first, second = world.cargo(ship)[:2]
        beside = (24, 9)                                      # land next to the beach and to the ship
        self.assertTrue(world.is_land(beside) and beside in neighbors(COLONY) and beside in neighbors(OFFSHORE))
        self.driver.at(0, self.on_hex(OFFSHORE))
        self.driver.at(1, key("1"))
        self.driver.at(2, self.on_hex(COLONY))
        self.driver.at(3, key("b"))                           # found
        self.driver.at(4, self.on_hex(OFFSHORE))              # the ship again ...
        self.driver.at(5, key("1"))                           # ... its first passenger is now the other colonist
        self.driver.at(6, self.on_hex(beside))
        self.driver.at(7, key("j"))                           # join
        picked = []
        self.driver.at(6, lambda: picked.append(app.ui.selected))
        self.play(9)

        self.assertEqual(picked, [second])
        colony = world.colony_at(COLONY)
        self.assertIsNotNone(colony, "B founded a colony on the beach")
        self.assertEqual((colony.owner, colony.capital, colony.pop), (PLAYER, True, 2), "and J added the second")
        self.assertNotIn(first, world.units)
        self.assertNotIn(second, world.units)
        self.assertEqual([u.type for u in world.cargo(ship)], [SOLDIER, PIONEER])
        self.assertIn(f"A colonist joined {colony.name} (2 population).", world.log)
        self.assertIsNone(app.ui.selected, "the colonist is gone, nothing is selected")


class ColonyJobsTest(ColonyCase):
    """Keys 1 to 7 press the colony panel's buttons: Scout, Pioneer, Soldier, Colonist, Grow, Stockade and, in
    the Independence game, Independence."""

    def open_colony(self, goal="survive"):
        app = self.start("land", goal)
        self.world.stock[PLAYER] = dict(RICH)
        colony = self.world.colony_at(COLONY)
        self.driver.at(0, self.on_hex(COLONY))               # the soldier standing in the colony ...
        self.driver.at(1, self.on_hex(COLONY))               # ... clicked again: the colony
        return app, colony

    def test_keys_1_to_6_do_the_colony_job_once_per_turn(self):
        jobs = {"1": SCOUT, "2": PIONEER, "3": SOLDIER, "4": COLONIST, "5": "grow", "6": "stockade"}
        for hotkey, job in jobs.items():
            with self.subTest(key=hotkey):
                self.driver.reset()
                app, colony = self.open_colony()
                world = self.world
                before = list(world.units)
                self.driver.at(2, key(hotkey))
                self.driver.at(3, key("5" if hotkey != "5" else "6"))     # a second job this turn: refused
                self.play(5)
                new = [u for u in world.units if u not in before]
                self.assertTrue(colony.busy)
                self.assertIs(app.ui.colony, colony)
                self.assertFalse(any(b.enabled for b in app.ui.buttons), "every job is done for this turn")
                if job == "grow":
                    self.assertEqual((colony.pop, new), (3, []))
                    self.assertEqual(world.stock[PLAYER], minus(RICH, GROW_COST))
                elif job == "stockade":
                    self.assertEqual((colony.stockade, colony.pop, new), (True, 2, []))
                    self.assertEqual(world.stock[PLAYER], minus(RICH, STOCKADE_COST))
                else:
                    self.assertEqual([(u.type, u.owner, u.moves_left) for u in new], [(job, PLAYER, 0)])
                    cost = job.cost if job is not COLONIST else {"food": COLONIST_FOOD}
                    self.assertEqual(world.stock[PLAYER], minus(RICH, cost))
                    self.assertEqual(colony.pop, 1 if job is COLONIST else 2)

    def test_key_7_declares_independence(self):
        from hexa.colony.rules import INDEPENDENCE_POP, INDEPENDENCE_SOLDIERS, MAX_POP
        app, colony = self.open_colony("independence")
        world = self.world
        colony.pop = MAX_POP                                     # 8 here and 4 in a second colony make 12
        settler = world.spawn(COLONIST, PLAYER, COLONY)
        settler.pos = next(p for p in sorted(world.terrain)
                           if world.unit_at(p) is None and world.found_check(settler, p)[0])
        world.found_colony(settler).pop = INDEPENDENCE_POP - MAX_POP
        for _ in range(INDEPENDENCE_SOLDIERS - 1):
            world.spawn(SOLDIER, PLAYER, COLONY)
        self.assertEqual(world.independence_check(), (True, ""))
        labels = []
        self.driver.at(2, lambda: labels.append([b.label for b in app.ui.buttons]))
        self.driver.at(2, key("7"))
        self.play(4)
        self.assertEqual(labels, [["Scout", "Pioneer", "Soldier", "Colonist", "Grow", "Stockade", "Independence"]])
        self.assertEqual(world.declared, 1)
        self.assertTrue(world.log[-1].startswith("You declared independence!"), world.log[-1])
        self.assertFalse(app.ui.buttons[6].enabled, "it can only be declared once")
        self.assertFalse(colony.busy, "declaring is not the colony's job for the turn")

    def test_key_7_does_nothing_in_a_game_without_independence(self):
        app, colony = self.open_colony("survive")
        before = (len(self.world.units), colony.pop, dict(self.world.stock[PLAYER]))
        self.driver.at(2, key("7"))
        self.play(4)
        self.assertEqual(len(app.ui.buttons), 6)
        self.assertEqual((len(self.world.units), colony.pop, self.world.stock[PLAYER]), before)
        self.assertFalse(colony.busy)


class HomelandTest(ColonyCase):
    def test_a_ship_at_the_east_edge_trades_with_the_homeland(self):
        app = self.start("land")
        world = self.world
        ship = app.ui.selected
        self.assertIs(ship.type, SHIP)
        edge = (world.cols - 1, ship.pos[1])
        self.assertEqual(world.reachable(ship).get(edge), edge[0] - ship.pos[0], "the edge is one turn away")
        self.assertIn("Sail to the glowing east edge", app.ui.status)
        self.assertEqual(app.ui.buttons, [], "no market away from the edge")
        world.stock[PLAYER]["furs"] = 5
        stock = dict(world.stock[PLAYER])
        labels = []
        self.driver.at(0, self.on_hex(edge))
        self.driver.at(1, lambda: labels.append([b.label for b in app.ui.buttons]))
        # 1 sells the furs, 2 a lot of wood, 3 buys food and 4 a colonist, one key a frame
        for frame, hotkey in enumerate(("1", "2", "3", "4"), start=1):
            self.driver.at(frame, key(hotkey))
        self.play(7)

        self.assertEqual(labels, [["Sell furs", "Sell wood", "Buy food", "Buy colonist", "Buy pioneer", "Buy soldier"]])
        self.assertTrue(world.at_homeland(ship))
        gold = stock["gold"] + 5 * FUR_PRICE + WOOD_LOT_PRICE - FOOD_LOT_PRICE - COLONIST.price
        self.assertEqual(world.stock[PLAYER], {"food": stock["food"] + FOOD_LOT, "wood": stock["wood"] - WOOD_LOT,
                                               "furs": 0, "gold": gold})
        self.assertEqual(world.favour[PLAYER], 5, "selling furs pleases the Crown")
        aboard = world.cargo(ship)
        self.assertEqual([(u.type, u.moves_left) for u in aboard], [(COLONIST, 0)])
        self.assertIn("A colonist boarded your ship.", world.log)


class VillageTest(ColonyCase):
    VILLAGE = (16, 13)

    def test_gift_and_trade_with_a_village_next_to_your_scout(self):
        app = self.start("land")
        world = self.world
        village = world.village_at(self.VILLAGE)
        scout = self.mine(SCOUT)
        scout.pos = min(p for p in neighbors(village.pos)
                        if world.is_land(p) and world.unit_at(p) is None and not world.village_at(p))
        world.update_visibility()
        world.tension[village.tribe][PLAYER] = 50
        app.look_at(village.pos)
        stock = dict(world.stock[PLAYER])
        shown = []
        self.driver.at(0, self.on_hex(village.pos))
        self.driver.at(1, lambda: shown.append((app.ui.village, [b.label for b in app.ui.buttons])))
        self.driver.at(1, key("1"))                               # gift
        self.driver.at(2, lambda: click(harness.button_rect(app, "Trade").center))
        self.driver.at(3, key("2"))                               # trade again: once per turn
        self.driver.at(4, lambda: hover(harness.button_rect(app, "Trade").center))
        self.play(6)

        self.assertEqual(shown, [(village, ["Gift", "Trade"])])
        self.assertEqual(world.stock[PLAYER], {"food": stock["food"], "wood": stock["wood"] - TRADE_GIVE["wood"],
                                               "furs": stock["furs"] + TRADE_GET["furs"],
                                               "gold": stock["gold"] - GIFT_COST["gold"]})
        self.assertEqual(world.tension[village.tribe][PLAYER], 50 - GIFT_CALM - TRADE_CALM)
        self.assertEqual(village.traded, {PLAYER: world.turn})
        self.assertIs(app.ui.village, village)
        self.assertEqual(app.ui.hover_button.hint, "Already traded with this village this turn")

    def test_a_village_out_of_reach_takes_no_gift(self):
        app = self.start("land")
        world = self.world
        village = world.village_at((19, 16))
        world.explored.add(village.pos)
        app.look_at(village.pos)
        stock = dict(world.stock[PLAYER])
        self.driver.at(0, self.on_hex(village.pos))
        self.driver.at(1, key("1"))
        self.driver.at(2, lambda: hover(harness.button_rect(app, "Gift").center))
        self.play(4)
        self.assertIs(app.ui.village, village)
        self.assertEqual(world.stock[PLAYER], stock)
        self.assertEqual(app.ui.hover_button.hint, "Needs a unit next to the village or a colony within 4 hexes")


class CameraTest(ColonyCase):
    def test_right_drag_scrolls_the_map_and_keeps_the_selection(self):
        app = self.start("land")
        ship = app.ui.selected
        camera = list(app.camera)
        where = hex_pixel(app, COLONY)
        self.driver.at(0, drag((400, 300), (520, 360), button=3))
        self.play(2)
        self.assertEqual(rounded(app.camera), rounded([camera[0] - 120, camera[1] - 60]))
        self.assertEqual(hex_pixel(app, COLONY), (where[0] + 120, where[1] + 60), "the map moved with the mouse")
        self.assertIs(app.ui.selected, ship, "a drag is not a right-click: the ship stays selected")

    def test_a_right_click_without_dragging_deselects(self):
        app = self.start("land")
        camera = list(app.camera)
        self.driver.at(0, drag((400, 300), (403, 302), button=3))        # moved 5 pixels: still a click
        self.play(2)
        self.assertIsNone(app.ui.selected)
        self.assertEqual(rounded(app.camera), rounded([camera[0] - 3, camera[1] - 2]))

    def test_the_camera_stops_at_the_edges_of_the_map(self):
        from hexa.colony.render import MAP_MARGIN, VIEW_H, WINDOW_SIZE, map_pixel_size
        app = self.start("land")
        width, height = map_pixel_size(self.world)
        cameras = []
        self.driver.at(0, drag((100, 100), (900, 580), button=3))
        self.driver.at(1, drag((100, 100), (900, 580), button=3))
        self.driver.at(2, lambda: cameras.append((list(app.camera), app.renderer.origin)))
        self.driver.at(2, drag((900, 580), (100, 100), button=3))
        self.driver.at(3, drag((900, 580), (100, 100), button=3))
        self.driver.at(4, drag((900, 580), (100, 100), button=3))
        self.play(6)
        self.assertEqual(cameras, [([0, 0], (MAP_MARGIN, MAP_MARGIN))], "the top left corner")
        self.assertEqual(app.camera, [width - WINDOW_SIZE[0], height - VIEW_H], "the bottom right corner")

    def test_held_arrow_keys_and_wasd_scroll_every_frame(self):
        from hexa.colony.app import SCROLL_SPEED
        app = self.start("land")
        keys = self.hold_keys()
        camera = list(app.camera)
        self.assertGreater(camera[1], 5 * SCROLL_SPEED, "room to scroll down and up")
        seen = []
        record = lambda: seen.append(list(app.camera))            # noqa: E731
        self.driver.at(2, lambda: keys.press("left"))
        self.driver.at(12, lambda: keys.release("left"))         # held for 10 frames
        self.driver.at(12, lambda: keys.press("s"))
        self.driver.at(17, lambda: keys.release("s"))            # 5 frames
        self.driver.at(17, lambda: keys.press("d", "w"))
        self.driver.at(20, lambda: keys.release())               # 3 frames, both at once
        self.driver.at(20, record)
        self.driver.at(20, lambda: keys.press("up"))
        self.driver.at(80, record)                               # the top of the map stops it
        self.play(82)
        self.assertEqual(rounded(seen[0]), rounded([camera[0] - 7 * SCROLL_SPEED, camera[1] + 2 * SCROLL_SPEED]))
        self.assertEqual(rounded(seen[1]), rounded([camera[0] - 7 * SCROLL_SPEED, 0]))
        self.assertIs(app.ui.selected.type, SHIP, "scrolling changes no selection")

    def test_clicking_the_minimap_looks_at_that_hex(self):
        from hexa.colony.render import VIEW_H, WINDOW_SIZE, map_pixel_size
        app = self.start("land")
        world = self.world
        ship = app.ui.selected
        middle = (WINDOW_SIZE[0] // 2, VIEW_H // 2)
        inner = [(12, 9), (13, 10), (20, 7), (9, 13)]        # far enough from the edges to be centred
        corners = [(0, 0), (world.cols - 1, world.rows - 1)]
        centred, shown = [], []
        for frame, pos in enumerate(inner + corners):
            self.driver.at(frame, click(minimap_pixel(app, pos)))
            self.driver.at(frame + 1, lambda: centred.append(app.hex_at(middle)))
            self.driver.at(frame + 1, lambda pos=pos: shown.append(self.on_map(hex_pixel(app, pos))))
        self.play(len(inner + corners) + 2)
        self.assertEqual(centred[:len(inner)], inner, "the map is centred on the hex clicked on the minimap")
        self.assertEqual(shown, [True] * len(inner + corners), "near the edges it is at least on screen")
        width, height = map_pixel_size(world)
        self.assertEqual(app.camera, [width - WINDOW_SIZE[0], height - VIEW_H], "the last click: bottom right")
        self.assertIs(app.ui.selected, ship)
        self.assertEqual((ship.pos, ship.moves_left), ((26, 10), SHIP.moves), "the clicks went to the minimap only")

    def test_a_click_anywhere_on_a_hexs_minimap_cell_looks_at_that_hex(self):
        """New bug, no GitHub issue filed yet: ColonyApp.click() turns a minimap pixel into a column with the
        minimap's whole width, which includes the half cell odd rows are shifted by, and ignores that shift. So
        about a quarter of the pixels of the cells as drawn (the left edge of a cell in an even row, the right
        edge in an odd row) look at the neighbouring column instead. Only the centre pixel is always right."""
        from hexa.colony.render import MINI_CELL, VIEW_H, WINDOW_SIZE
        app = self.start("land")
        middle = (WINDOW_SIZE[0] // 2, VIEW_H // 2)
        inner = [(12, 9), (13, 10), (20, 7), (17, 12)]          # odd and even rows, centred without clamping
        half = MINI_CELL // 2
        corners = [(-half, -half), (half - 1, -half), (-half, half - 1), (half - 1, half - 1)]
        clicks = [(pos, (x + dx, y + dy)) for pos in inner for x, y in [minimap_pixel(app, pos)] for dx, dy in corners]
        centred = []
        for frame, (pos, pixel) in enumerate(clicks):
            self.driver.at(frame, click(pixel))
            self.driver.at(frame + 1, lambda pos=pos, pixel=pixel: centred.append((pos, pixel, app.hex_at(middle))))
        self.play(len(clicks) + 2)
        self.assertEqual([(pos, pixel) for pos, pixel, at in centred if at != pos], [],
                         "minimap pixels (of the hex's drawn cell) that looked at another hex")


if __name__ == "__main__":
    unittest.main()
