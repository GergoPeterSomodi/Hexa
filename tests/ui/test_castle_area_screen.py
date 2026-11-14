"""The screen part of castle areas (0.2.2; docs/design/castle-areas.md sections 4 and 5): the war-stack layer on the map, the
province panel's chip (held, a castle, fallen, open), the move card on a hovered hex (refusals and notes), and the odds
card's "Taking it opens N provinces". Run with: python -m unittest tests.ui.test_castle_area_screen
"""
from unittest import mock

from tests.support import harness


def held_scene(app, player="POR"):
    """A war with the country of a castle whose land is held (distance 1 or more) and a stack of the player on a hex
    beside that land, not the enemy's. Returns (castle, held hex, stack units)."""
    from hexa.campaign.state import War
    from hexa.hexgrid import neighbors
    from tests.support.battles import place
    world = app.world
    world.player = player
    world.visible = set(world.terrain)
    for castle in sorted(world.castles(), key=lambda p: p.pos):
        if castle.owner == player or castle.controller != castle.owner:
            continue
        for held in world.area(castle.pos):
            if world.area_state(held)["state"] != "held":
                continue
            for n in sorted(neighbors(held)):
                prov = world.provinces.get(n)
                if prov is None or not world.is_land(n) or prov.owner == castle.owner or prov.castle:
                    continue
                if world.units_at(n):
                    continue
                if not world.at_war(player, castle.owner):
                    world.wars.append(War(player, castle.owner, world.turn))
                stack = place(world, "infantry", 1, player, n, 3) + place(world, "cavalry", 1, player, n, 1)
                world.changed(ownership=True)
                return castle, held, stack
    raise AssertionError("no held land beside a free hex on this world")


class CastleAreaCase(harness.UITestCase):
    def start(self):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = app = CampaignApp(play.TILES_DIR, "POR")
        self.castle, self.held, self.stack = held_scene(app)
        app.select_unit(self.stack[0])
        app.refresh()
        return app

    def panel_on(self, app, pos):
        app.ui.panel, app.ui.province = "province", app.world.provinces[pos]
        app.ui.hover, app.ui.mouse = None, (-50, -50)
        app.draw()


class WarStackLayerTest(CastleAreaCase):
    def test_no_layer_is_built_without_a_war_stack_selected(self):
        app = self.start()
        app.select_unit(None)
        app.refresh()
        app.ui.hover, app.ui.mouse = None, (-50, -50)
        app.draw()
        layer = app.view.__dict__.get("_war_layer")
        self.assertTrue(layer is None or layer._key is None, "nothing is computed with no war stack selected")

    def test_the_layer_tints_exactly_the_held_land_of_countries_at_war(self):
        from hexa.campaign.render.warareas import TINT_ALPHA
        app = self.start()
        app.ui.hover, app.ui.mouse = None, (-50, -50)
        app.draw()
        world = app.world
        layer = app.view._war_layer
        expected = set()
        for castle in world.castles():
            if castle.owner == world.player or castle.controller != castle.owner or not world.at_war(world.player, castle.owner):
                continue
            expected |= {p for p in world.area(castle.pos) if world.area_state(p)["state"] in ("held", "castle")}
        self.assertIn(self.held, expected)
        self.assertGreater(len(layer._tints), 0)
        self.assertEqual(len(layer._tints), len(expected))
        self.assertTrue(all(rgba[3] == TINT_ALPHA for rgba, _, _ in layer._tints))
        self.assertTrue(all(colour for colour, _, _ in layer._dashes))

    def test_the_layer_is_kept_until_the_world_or_the_selection_changes(self):
        app = self.start()
        app.ui.hover, app.ui.mouse = None, (-50, -50)
        app.draw()
        layer = app.view._war_layer
        with mock.patch.object(layer, "_build", wraps=layer._build) as build:
            app.draw()
            app.draw()
            self.assertEqual(build.call_count, 0, "the same world and selection: the geometry is reused")
            app.world.changed()
            app.draw()
            self.assertEqual(build.call_count, 1)

    def test_a_fallen_castle_gives_up_its_outline(self):
        app = self.start()
        app.ui.hover, app.ui.mouse = None, (-50, -50)
        app.draw()
        before = len(app.view._war_layer._tints)
        self.castle.controller = app.world.player           # the castle falls: its land is open, no longer held
        app.world.changed(ownership=True)
        app.draw()
        self.assertLess(len(app.view._war_layer._tints), before)
        self.assertNotEqual(app.world.area_state(self.held)["state"], "held")


class ProvinceChipTest(CastleAreaCase):
    def test_held_land_says_whose_castle_holds_it_and_how_far(self):
        from hexa.campaign.panels import province
        app = self.start()
        with mock.patch.object(province, "_chip", wraps=province._chip) as chip:
            self.panel_on(app, self.held)
        line1 = [c.args[4] for c in chip.call_args_list]
        self.assertIn(f"Held by the castle of {app.world.provinces[self.castle.pos].name}", line1)
        titles = [card[0] for _, card in app.ui.hoverables]
        held_title = next(t for t in titles if "hex" in t and "away" in t)
        d = app.world.area_state(self.held)["distance"]
        self.assertEqual(held_title, f"{app.world.provinces[self.castle.pos].name} is {d} hex{'' if d == 1 else 'es'} away")
        lines = next(card[1] for _, card in app.ui.hoverables if card[0] == held_title)
        self.assertIn("Counted along", " ".join(text for text, _ in lines))

    def test_a_castle_chip_lists_up_to_twelve_provinces(self):
        from hexa.campaign.panels import province
        app = self.start()
        with mock.patch.object(province, "_chip", wraps=province._chip) as chip:
            self.panel_on(app, self.castle.pos)
        line1 = [c.args[4] for c in chip.call_args_list]
        n = app.world.area_opens(self.castle.pos)
        self.assertIn(f"Holds {n} province{'' if n == 1 else 's'}, up to", " ".join(line1))
        lines = next(card[1] for _, card in app.ui.hoverables if card[0].startswith("The castle of"))
        names = lines[:lines.index(("", None))]              # the name lines, before the rule
        self.assertLessEqual(len(names), 4 + 1)               # up to twelve names, three to a line, plus "and N more"
        if n > 12:
            self.assertTrue(any(text == f"and {n - 12} more" for text, _ in lines))

    def test_open_land_says_no_castle_holds_it(self):
        from hexa.campaign.panels import province
        app = self.start()
        world = app.world
        open_pos = next(p for p in sorted(world.terrain) if (world.provinces.get(p) and world.provinces[p].owner
                        and world.area_state(p) and world.area_state(p)["state"] == "open"
                        and world.area_state(p)["castle"] is None and world.is_land(p)))
        with mock.patch.object(province, "_chip", wraps=province._chip) as chip:
            self.panel_on(app, open_pos)
        self.assertIn("Open land: no castle holds it", [c.args[4] for c in chip.call_args_list])

    def test_a_fallen_castle_leaves_its_land_open_with_the_broken_shield(self):
        from hexa.campaign.panels import province
        app = self.start()
        self.castle.controller = app.world.player
        app.world.changed(ownership=True)
        with mock.patch.object(province, "_chip", wraps=province._chip) as chip:
            self.panel_on(app, self.held)
        calls = chip.call_args_list
        self.assertIn(f"Open: the castle of {app.world.provinces[self.castle.pos].name} has fallen",
                      [c.args[4] for c in calls])
        fallen = next(c for c in calls if c.args[4].startswith("Open: the castle"))
        self.assertEqual(fallen.args[6], ("shield_broken", (150, 150, 150)))


class MoveCardTest(CastleAreaCase):
    def test_a_held_hex_shows_the_note_with_its_way_out(self):
        from hexa.campaign.hud.floating import screen_point
        app = self.start()
        app.ui.hover = self.held
        app.ui.mouse = (-50, -50)
        found = app.hud.moves.why(app)
        self.assertIsNotNone(found)
        pos, (kind, text, way) = found
        self.assertEqual((pos, kind), (self.held, "note"))
        self.assertTrue(text.startswith("Moves in, but cannot take it: held by the castle of"))
        self.assertEqual(way, "Take the castle first.")
        app.ui.mouse = tuple(int(v) for v in screen_point(app, self.held))
        app.draw()
        self.assertIsNotNone(app.hud.moves._surface, "the card is drawn beside the hex")

    def test_a_refusal_is_red_and_the_hex_card_gives_way_to_it(self):
        from hexa.campaign.app import card_of
        app = self.start()
        world = app.world
        sea = next(p for p in sorted(world.terrain) if world.is_sea(p))
        app.ui.hover = sea
        app.ui.mouse = (-50, -50)
        kind, text, way = app.hud.moves.why(app)[1]
        self.assertEqual(kind, "refusal")
        self.assertEqual(text, "Armies cannot walk on water.")
        self.assertEqual(way, "Load them onto a ship first.")
        with mock.patch("hexa.campaign.app.card_of", wraps=card_of) as hex_card:
            app.draw()
        self.assertFalse(hex_card.called, "the move card replaces the province card of the hex")

    def test_no_move_card_on_the_stacks_own_hex_or_without_a_selection(self):
        app = self.start()
        app.ui.hover = self.stack[0].pos
        app.ui.mouse = (-50, -50)
        self.assertIsNone(app.hud.moves.why(app))
        app.select_unit(None)
        app.refresh()
        app.ui.hover = self.held
        self.assertIsNone(app.hud.moves.why(app))


class OddsOpensTest(harness.UITestCase):
    def test_the_odds_card_of_a_castle_says_what_its_fall_opens(self):
        import play
        from hexa.campaign.app import CampaignApp
        from hexa.campaign.battleview import odds_view
        from hexa.campaign.data import GARRISON_HP
        from hexa.campaign.hud import odds
        from hexa.campaign.state import War
        from tests.support.battles import place
        app = CampaignApp(play.TILES_DIR, "POR")
        world = app.world
        world.player = "POR"
        world.visible = set(world.terrain)
        castle, stack_pos = _castle_with_free_neighbour(world)
        castle.garrison = max(castle.garrison, castle.castle * GARRISON_HP)
        if not world.at_war("POR", castle.owner):
            world.wars.append(War("POR", castle.owner, world.turn))
        stack = place(world, "infantry", 1, "POR", stack_pos, 4)
        world.changed(ownership=True)
        app.refresh()
        app.select_unit(stack[0])
        app.refresh()
        view = odds_view(world, stack, castle.pos, "POR")
        siege = view["besiege"]
        self.assertIsNotNone(siege)
        n = world.area_opens(castle.pos)
        self.assertEqual(siege["opens"], n)
        self.assertGreater(n, 0, "the castle holds land of its owner")
        rows = [entry[0] for entry in odds._besiege_rows(view) if entry]
        if n:
            want = f"Taking it opens {n} province{'' if n == 1 else 's'}"
            self.assertIn(want, rows)
        else:
            self.assertFalse(any(text.startswith("Taking it opens") for text in rows))


def _castle_with_free_neighbour(world):
    """An enemy castle on the map (standing, not the player's) and a free land hex beside it."""
    from hexa.hexgrid import neighbors
    for castle in sorted(world.castles(), key=lambda p: p.pos):
        if castle.owner == "POR" or castle.controller != castle.owner:
            continue
        for n in sorted(neighbors(castle.pos)):
            prov = world.provinces.get(n)
            if prov is not None and world.is_land(n) and not prov.castle and not world.units_at(n):
                return castle, n
    raise AssertionError("no enemy castle with a free neighbour")
