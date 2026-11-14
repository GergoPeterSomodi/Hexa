"""Castle areas and clear move refusals (0.2.2; docs/design/castle-areas.md sections 2.2, 2.3, 3, 5 and 9).

The rule of castle_of/area/area_state on a small hand-made world (a row of hexes, so the distances are plain), its siege
consequences (held land is not taken, open land is taken in one season, a fallen castle opens its land from the next
season, own land is retaken in one season), the forecast and the odds card's ``opens``, one test per refusal row of
section 5, and the AI's targets (held land is no target, the defender retakes its own land first, spare stacks claim
different open land). Pygame-free. Each test changes a fresh world, except the stub worlds of the rule tests.
"""
import unittest

from hexa.campaign import battleview, world as worldmod
from hexa.campaign.data import CARAVEL, CASTLE_AREA, CIVILIAN_LIMIT, GARRISON_HP, GENERAL, MILITIA_MEN, WAGON
from hexa.campaign.state import Province, War
from hexa.campaign import ai
from hexa.campaign.systems import areas, movement
from hexa.hexgrid import distance, neighbors
from tests.support.battles import place, setup
from tests.support.worlds import fresh


class Stub:
    """The little world of castle areas: a dict of provinces, the castles, and the table (no game around them)."""

    def __init__(self, provinces):
        self.provinces = provinces
        self._table = None

    def castles(self):
        return [p for p in self.provinces.values() if p.castle and p.owner]

    def area_table(self):
        if self._table is None:
            self._table = areas.build(self)
        return self._table


def land(owner, xs, controller=None, row=0):
    """Plains hexes (x, row) owned by one country, as a dict of provinces."""
    return {(x, row): Province(pos=(x, row), terrain="plains", good=None, coastal=False, name=f"P{x}",
                               owner=owner, controller=controller or owner) for x in xs}


def add_castle(provs, pos, level, controller=None):
    prov = provs[pos]
    prov.castle, prov.garrison = level, level * GARRISON_HP
    prov.controller = controller or prov.owner
    return prov


class AreaRuleTest(unittest.TestCase):
    def test_the_reach_is_three_four_and_five_hexes_by_level(self):
        self.assertEqual(CASTLE_AREA[1:], (3, 4, 5))
        self.assertEqual([areas.reach(level) for level in (1, 2, 3)], [3, 4, 5])

    def test_a_castle_holds_its_own_land_within_its_reach_and_no_further(self):
        provs = land("A", range(12))
        add_castle(provs, (0, 0), 1)
        add_castle(provs, (6, 0), 2)
        stub = Stub(provs)
        table = stub.area_table()
        self.assertEqual(table["of"][(2, 0)], (0, 0))
        self.assertEqual(table["dist"][(2, 0)], 2)
        self.assertEqual(table["of"][(10, 0)], (6, 0))
        self.assertEqual(table["dist"][(10, 0)], 4)
        self.assertNotIn((11, 0), table["of"], "five hexes from a level 2 castle: beyond its reach of 4")
        self.assertEqual(areas.area(stub, (0, 0))[0], (0, 0), "a castle is the first of its own area")

    def test_the_nearest_castle_wins_and_a_tie_goes_to_the_higher_level(self):
        provs = land("A", range(12))
        add_castle(provs, (0, 0), 1)                      # reaches x 0..3
        add_castle(provs, (6, 0), 2)                      # reaches x 2..10
        table = Stub(provs).area_table()
        self.assertEqual(table["of"][(2, 0)], (0, 0), "two from the level 1 castle, four from the level 2")
        self.assertEqual(table["of"][(3, 0)], (6, 0), "three from each: the level 2 castle takes the tie")
        self.assertEqual(table["of"][(4, 0)], (6, 0))

    def test_land_is_counted_along_its_own_country(self):
        provs = land("A", range(12))
        provs[(2, 0)].owner = provs[(2, 0)].controller = "B"          # a foreign hex cuts the road
        add_castle(provs, (0, 0), 1)
        table = Stub(provs).area_table()
        self.assertEqual(table["of"][(1, 0)], (0, 0))
        self.assertNotIn((2, 0), table["of"])
        self.assertNotIn((3, 0), table["of"], "the hex beyond the foreign land is not reached by the castle's own land")

    def test_the_table_is_the_brute_force_answer_on_the_europe_map(self):
        world = fresh("POR")
        table = world.area_table()
        best = {}
        for castle in world.castles():
            depth = {castle.pos: 0}
            frontier = [castle.pos]
            while frontier:
                nxt = []
                for pos in frontier:
                    if depth[pos] >= areas.reach(castle.castle):
                        continue
                    for n in neighbors(pos):
                        prov = world.provinces.get(n)
                        if prov is not None and prov.owner == castle.owner and n not in depth:
                            depth[n] = depth[pos] + 1
                            nxt.append(n)
                frontier = nxt
            for pos, hexes in depth.items():
                key = (hexes, -castle.castle, castle.pos)
                if pos not in best or key < best[pos]:
                    best[pos] = key
        self.assertEqual(set(table["of"]), set(best))
        for pos, key in best.items():
            self.assertEqual((table["of"][pos], table["dist"][pos]), (key[2], key[0]), pos)

    def test_states_held_fallen_open_and_the_castle_itself(self):
        provs = land("A", range(5))
        castle = add_castle(provs, (0, 0), 1)
        stub = Stub(provs)
        self.assertEqual(areas.area_state(stub, (0, 0))["state"], "castle")
        held = areas.area_state(stub, (1, 0), viewer="A")
        self.assertEqual((held["state"], held["castle"], held["distance"]), ("held", (0, 0), 1))
        self.assertEqual(held["path"], [(0, 0), (1, 0)])
        self.assertTrue(held["own"])
        self.assertEqual(areas.area_state(stub, (3, 0))["state"], "held")
        far = areas.area_state(stub, (4, 0))
        self.assertEqual((far["state"], far["castle"]), ("open", None), "four hexes: beyond a tower's reach")
        castle.controller = "B"
        self.assertEqual(areas.area_state(stub, (1, 0))["state"], "fallen")
        self.assertIsNone(areas.castle_of(stub, (1, 0)), "a fallen castle holds nothing")
        provs[(1, 0)].controller = "B"
        self.assertEqual(areas.area_state(stub, (1, 0))["state"], "open", "own land taken: nothing holds it back")

    def test_castle_of_is_the_holding_castle_or_none(self):
        provs = land("A", range(5))
        add_castle(provs, (0, 0), 1)
        stub = Stub(provs)
        self.assertEqual(areas.castle_of(stub, (2, 0)), (0, 0))
        self.assertIsNone(areas.castle_of(stub, (0, 0)), "a castle is the target, not land it holds")
        self.assertIsNone(areas.castle_of(stub, (9, 9)))

    def test_opens_counts_the_land_a_fall_gives_the_taker(self):
        provs = land("A", range(5))
        add_castle(provs, (0, 0), 1)
        stub = Stub(provs)
        self.assertEqual(areas.opens(stub, (0, 0)), 3)
        provs[(2, 0)].controller = "B"
        self.assertEqual(areas.opens(stub, (0, 0)), 2, "the land already taken does not open again")

    def test_the_table_is_a_cache_of_the_world_cleared_by_owners_and_castles(self):
        world = fresh("POR")
        first = world.area_table()
        self.assertIs(world.area_table(), first)
        world.changed(ownership=True)
        self.assertIsNone(world._areas)
        world.area_table()
        world.forget_castles()
        self.assertIsNone(world._areas)

    def test_the_table_is_never_saved(self):
        world = fresh("POR")
        world.area_table()
        self.assertIn("_areas", worldmod.WORLD_DEFAULTS)
        self.assertIn("_areas", worldmod.WORLD_CACHES)
        self.assertNotIn("_areas", world.save_state())
        self.assertEqual(areas.OWNS, ())


def clean(world):
    world.units, world.battles = [], []
    return world


def at_war(world, a="POR", b="CAS"):
    if not world.at_war(a, b):
        world.wars.append(War(a, b, world.turn))


def pair(world, a_owner, b_owner):
    """(a, b): a land hex of a_owner next to a land hex of b_owner, in hex order."""
    for prov in sorted(world.provinces.values(), key=lambda p: p.pos):
        if prov.owner != a_owner or not world.is_land(prov.pos):
            continue
        for n in sorted(neighbors(prov.pos)):
            other = world.provinces.get(n)
            if other is not None and other.owner == b_owner and world.is_land(n):
                return prov.pos, n
    raise AssertionError(f"no hex of {a_owner} beside {b_owner}")


def castle_in_war(world, tag="CAS", level=1):
    """A castle of ``level`` of tag with a full garrison: an own land hex with no units, not its capital."""
    prov = next(p for p in sorted(world.provinces_of(tag), key=lambda p: p.pos)
                if p.pos != world.countries[tag].capital and not world.units_at(p.pos) and not p.castle)
    prov.castle, prov.garrison = level, level * GARRISON_HP
    world.changed(ownership=True)
    return prov


def held_land(world, owner="CAS"):
    """A land hex of owner that a standing castle holds, with no units on it."""
    for prov in sorted(world.provinces_of(owner), key=lambda p: p.pos):
        if not prov.castle and not world.units_at(prov.pos) and world.castle_of(prov.pos) is not None:
            return prov
    raise AssertionError("no held land")


def open_land(world, owner="CAS"):
    """A land hex of owner that no castle holds, with no units on it."""
    for prov in sorted(world.provinces_of(owner), key=lambda p: p.pos):
        if not prov.castle and not world.units_at(prov.pos) and world.castle_of(prov.pos) is None \
                and world.is_land(prov.pos):
            return prov
    raise AssertionError("no open land")


class HeldLandTest(unittest.TestCase):
    """The siege step (war.sieges) on the real Europe map: what an army can take, and when."""

    def setUp(self):
        self.w = clean(fresh("POR"))
        at_war(self.w)

    def test_held_land_is_entered_but_not_taken_while_its_castle_stands(self):
        w = self.w
        prov = held_land(w)
        stack = place(w, "infantry", 1, "POR", prov.pos, 6)
        for _ in range(4):
            w.sieges()
            w.turn += 1
        self.assertEqual(prov.controller, "CAS")
        self.assertFalse(prov.besieger, "held land has no siege")
        self.assertTrue(all(u.pos == prov.pos for u in stack), "the army may stand there")
        self.assertIsNone(w.siege_forecast(prov, "POR", stack))
        self.assertEqual(w.area_state(prov.pos)["state"], "held")

    def test_open_land_is_taken_at_the_end_of_the_season_an_army_stands_on_it_alone(self):
        w = self.w
        prov = open_land(w)
        place(w, "infantry", 1, "POR", prov.pos, 2)
        w.sieges()
        self.assertEqual(prov.controller, "POR", "one season, no floor and no meter")
        self.assertFalse(prov.besieger)

    def test_two_armies_on_open_land_leave_it_to_the_battle(self):
        w = self.w
        prov = open_land(w)
        place(w, "infantry", 1, "POR", prov.pos, 2)
        place(w, "infantry", 1, "CAS", prov.pos, 1)
        w.sieges()
        self.assertEqual(prov.controller, "CAS")

    def test_a_small_army_takes_no_open_land(self):
        w = self.w
        prov = open_land(w)
        unit = place(w, "infantry", 1, "POR", prov.pos, 1)[0]
        unit.hp = 1
        self.assertLess(unit.men, MILITIA_MEN, "the test needs a stack below the militia")
        w.sieges()
        self.assertEqual(prov.controller, "CAS")
        self.assertIsNone(w.siege_forecast(prov, "POR", [unit]))

    def test_open_land_forecast_is_one_season_for_a_stack_with_the_militia_men(self):
        w = self.w
        prov = open_land(w)
        stack = place(w, "infantry", 1, "POR", prov.pos, 2)
        self.assertEqual(w.siege_forecast(prov, "POR", stack), 1)

    def test_own_land_is_retaken_in_one_season_even_inside_a_held_area(self):
        w = self.w
        prov = next(p for p in sorted(w.provinces_of("POR"), key=lambda p: p.pos)
                    if not p.castle and w.castle_of(p.pos) is not None)
        prov.controller = "CAS"
        w.changed(ownership=True)
        place(w, "infantry", 1, "POR", prov.pos, 2)
        w.sieges()
        self.assertEqual(prov.controller, "POR")

    def test_a_castle_falls_and_its_land_opens_from_the_next_season(self):
        w = self.w
        castle = castle_in_war(w, level=1)
        near = next(n for n in sorted(neighbors(castle.pos)) if n in w.provinces and w.is_land(n)
                    and w.provinces[n].owner == "CAS" and w.castle_of(n) == castle.pos)
        place(w, "infantry", 1, "POR", castle.pos, 6)                  # the siege
        place(w, "infantry", 1, "POR", near, 6)                        # alone on the land the castle holds
        fell = None
        for season in range(1, 20):
            w.sieges()
            if castle.controller == "POR":
                fell = season
                break
            w.turn += 1
        self.assertIsNotNone(fell, "the castle falls")
        self.assertEqual(w.provinces[near].controller, "CAS", "the step that takes the castle does not open its land")
        w.turn += 1
        w.sieges()
        self.assertEqual(w.provinces[near].controller, "POR", "from the next season the army walks in")
        self.assertEqual(w.bus.of("province_captured")[-1].get("by"), "walk")

    def test_the_arrival_season_does_not_take_a_castle(self):
        w = self.w
        castle = castle_in_war(w, level=1)
        place(w, "infantry", 1, "POR", castle.pos, 6)
        w.sieges()
        self.assertEqual(castle.controller, "CAS", "the floor: a castle holds out at least two seasons")

    def test_a_fallen_castle_holds_nothing_and_a_retaken_one_holds_again(self):
        w = self.w
        castle = castle_in_war(w, level=1)
        near = next(n for n in sorted(neighbors(castle.pos)) if n in w.provinces and w.is_land(n)
                    and w.provinces[n].owner == "CAS" and w.castle_of(n) == castle.pos)
        castle.controller = "POR"
        w.changed(ownership=True)
        self.assertIsNone(w.castle_of(near), "fallen: no holding")
        self.assertEqual(w.area_state(near)["state"], "fallen")
        castle.controller = "CAS"
        w.changed(ownership=True)
        self.assertEqual(w.castle_of(near), castle.pos, "retaken: the area is held again")

    def test_the_odds_card_of_a_castle_says_what_its_fall_opens(self):
        w = self.w
        castle = castle_in_war(w, level=2)
        stand = next(n for n in sorted(neighbors(castle.pos)) if n in w.provinces and w.is_land(n))
        stack = place(w, "infantry", 1, "POR", stand, 6)
        view = battleview.odds_view(w, stack, castle.pos)                  # the whole picture: the castle is in view
        self.assertIsNotNone(view["besiege"])
        self.assertEqual(view["besiege"]["opens"], w.area_opens(castle.pos))
        self.assertGreater(view["besiege"]["opens"], 0)


class PeaceTest(unittest.TestCase):
    def test_peace_hands_back_a_capital_and_clears_the_table(self):
        w = clean(fresh("POR"))
        at_war(w)
        table = w.area_table()
        w.peace("POR", "CAS")
        self.assertIsNone(w._areas, "peace changes owners: the table is rebuilt on the next ask")
        self.assertIsNot(w.area_table(), table)


def border_castle(world, level):
    """A Castilian hex beside Portuguese land, made a castle of ``level`` with a full garrison."""
    for prov in sorted(world.provinces_of("CAS"), key=lambda p: p.pos):
        if prov.castle or world.units_at(prov.pos) or not world.is_land(prov.pos):
            continue
        if any(world.provinces.get(n) is not None and world.provinces[n].owner == "POR" for n in neighbors(prov.pos)):
            prov.castle, prov.garrison = level, level * GARRISON_HP
            world.changed(ownership=True)
            return prov
    raise AssertionError("no Castilian hex beside Portugal")


def search(world, group, accept, radius):
    """The first land hex (in hex order) within radius of the stack whose refusal satisfies accept: (hex, refusal)."""
    origin = group[0].pos
    for dest in sorted(p for p in world.provinces if p != origin and world.is_land(p)
                       and distance(origin, p) <= radius):
        result = movement.refusal(world, group, dest)
        if result and accept(result):
            return dest, result
    return None, None


class RefusalRowsTest(unittest.TestCase):
    """One test per row of castle-areas.md section 5 (the case and its words), and the moves that simply happen."""

    def setUp(self):
        self.w = clean(fresh("POR"))

    def stack(self, branch, pos, n=1, tag="POR"):
        return place(self.w, branch, 1, tag, pos, n)

    def test_a_legal_move_has_no_refusal(self):
        w = self.w
        a, b = pair(w, "POR", "POR")
        group = self.stack("infantry", a)
        self.assertIsNone(movement.refusal(w, group, b))
        self.assertIsNone(movement.refusal(w, group, a), "the stack's own hex")
        self.assertIsNone(w.refusal([], b))

    def test_row_1_a_stack_in_battle_is_told_to_withdraw(self):
        w = self.w
        fight = setup(w, [("infantry", 1, 5)], [("infantry", 1, 3)])
        w.attack_group(fight.attackers, fight.defend_pos)
        group = [u for u in w.units_at(fight.defend_pos) if u.owner == fight.attacker]
        self.assertTrue(group, "the attackers stand on the battle hex")
        out = next(n for n in sorted(neighbors(fight.defend_pos)) if w.is_land(n) and n in w.provinces
                   and not w.units_at(n))
        self.assertEqual(movement.refusal(w, group, out), ("refusal", "In battle: order Withdraw to leave", None))

    def test_row_2_a_ridge_crest_stops_the_march(self):
        w = self.w
        a, b = next((x, y) for x, y in sorted(w.pass_data()[4]) if w.is_land(x) and w.is_land(y))
        group = self.stack("infantry", a)
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", "Nobody can cross the ridge here; armies need a pass.", None))

    def test_row_3_a_pass_shut_by_snow_names_the_pass(self):
        w = self.w
        w.turn = 4                                                     # winter: every fourth season
        passes = w.pass_data()[2]
        a, b = next((x, y) for x, y in sorted(w.pass_data()[5]) if (x, y) not in w.pass_data()[4]
                    and frozenset((x, y)) in passes and w.is_land(x) and w.is_land(y))
        name = passes[frozenset((a, b))][0]
        group = self.stack("infantry", a)
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", f"The {name} pass is closed by snow until spring.", None))

    def test_row_4_an_army_cannot_walk_onto_the_sea(self):
        w = self.w
        a, s = next((p, n) for p in sorted(w.provinces) for n in sorted(neighbors(p))
                    if w.is_land(p) and w.is_sea(n))
        group = self.stack("infantry", a)
        self.assertEqual(movement.refusal(w, group, s),
                         ("refusal", "Armies cannot walk on water.", "Load them onto a ship first."))

    def test_row_5_a_stack_with_no_moves_left_says_why(self):
        w = self.w
        a, b = pair(w, "POR", "POR")
        group = self.stack("infantry", a, 2)
        for unit in group:
            unit.moves_left, unit.foraged_turn = 0, w.turn
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", "They foraged this season and have no moves left.", None))
        for unit in group:
            unit.foraged_turn, unit.acted = -1, True
        self.assertEqual(movement.refusal(w, group, b), ("refusal", "They have already moved this season.", None))

    def test_row_6_foreign_land_at_peace_is_closed(self):
        w = self.w
        w.wars = []
        a, b = pair(w, "POR", "CAS")
        group = self.stack("infantry", a)
        name = w.countries["CAS"].name
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", f"Not at war with {name}: their land is closed to your army.",
                          f"Declare war on {name} first, or go round."))

    def test_row_7_wagons_do_not_enter_enemy_land(self):
        w = self.w
        at_war(w)
        a, b = pair(w, "POR", "CAS")
        wagon = w.add_unit(WAGON, "POR", a, moves=WAGON.moves)
        self.assertEqual(movement.refusal(w, [wagon], b),
                         ("refusal", "Only soldiers, generals and scouts may enter enemy land.",
                          "Split off the wagons and settlers."))

    def test_row_8_an_enemy_army_on_the_hex_is_named_with_its_men(self):
        w = self.w
        at_war(w)
        a, b = pair(w, "POR", "CAS")
        group = self.stack("infantry", a, 3)
        place(w, "infantry", 1, "CAS", b, 3)
        men = sum(u.men for u in w.units_at(b))
        ok, why = w.engage_check(group, b)
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", f"An enemy army stands there ({men:,} men).",
                          "Right-click again to attack." if ok else why))

    def test_row_9_another_countrys_army_on_our_land_is_pick_another_hex(self):
        w = self.w
        w.wars = []
        a, b = pair(w, "POR", "POR")
        group = self.stack("infantry", a)
        place(w, "infantry", 1, "CAS", b, 1)
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", "Another country's army stands there: pick another hex.", None))

    def test_row_10_a_full_stack_has_no_room_and_a_part_full_one_says_how_full(self):
        w = self.w
        a, b = pair(w, "POR", "POR")
        limit = w.stack_limit("POR", [])
        place(w, "infantry", 1, "POR", b, limit)
        group = self.stack("infantry", a)
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", f"No room: the stack there has {limit} of {limit} troops.",
                          "Split the army or pick another hex."))
        w.units = [u for u in w.units if u.pos != b]
        place(w, "infantry", 1, "POR", b, limit - 2)
        group = self.stack("infantry", a, 3)
        self.assertEqual(movement.refusal(w, group, b),
                         ("refusal", f"No room: the stack there has {limit - 2} of {limit} troops and you are sending 3.",
                          "Split the army or pick another hex."))

    def test_row_11_a_hex_holds_three_settlers_and_scouts(self):
        w = self.w
        a, b = pair(w, "POR", "POR")
        for _ in range(CIVILIAN_LIMIT):
            w.add_unit(WAGON, "POR", b, moves=0)
        wagon = w.add_unit(WAGON, "POR", a, moves=WAGON.moves)
        self.assertEqual(movement.refusal(w, [wagon], b),
                         ("refusal", f"A hex holds {CIVILIAN_LIMIT} settlers and scouts.", "Pick another hex."))

    def test_row_11_a_hex_holds_one_general(self):
        w = self.w
        a, b = pair(w, "POR", "POR")
        w.add_unit(GENERAL, "POR", b, moves=0)
        general = w.add_unit(GENERAL, "POR", a, moves=GENERAL.moves)
        self.assertEqual(movement.refusal(w, [general], b), ("refusal", "A hex holds one general.", "Pick another hex."))

    def test_row_12_the_march_halts_beside_an_enemy_castle_and_goes_on_next_season(self):
        w = self.w
        at_war(w)
        castle = border_castle(w, 1)
        found = (None, None)
        for start in sorted(p.pos for p in w.provinces_of("POR") if w.is_land(p.pos)
                            and 2 <= distance(p.pos, castle.pos) <= 3):
            group = self.stack("infantry", start, 3)
            found = search(w, group, lambda r: r[0] == "note" and r[1].startswith("Stops beside"), 6)
            if found[0] is not None:
                break
            w.units = [u for u in w.units if u not in group]
        self.assertIsNotNone(found[0], "a march past a Castilian castle to test")
        kind, text, way = found[1]
        self.assertEqual((kind, way), ("note", "Goes on next season."))
        self.assertTrue(text.startswith("Stops beside the castle of "), text)
        self.assertTrue(text.endswith(" this season: enemy castles halt a march."), text)
        self.assertNotIn(found[0], w.reachable_group(group))

    def test_row_13_a_march_of_more_seasons_is_a_note_that_names_the_slow_unit(self):
        w = self.w
        start = next(p.pos for p in sorted(w.provinces_of("POR"), key=lambda p: p.pos) if w.is_land(p.pos))
        group = self.stack("infantry", start)
        dest, result = search(w, group, lambda r: r[0] == "note" and r[1].startswith("About "), 10)
        self.assertIsNotNone(dest)
        self.assertIn("seasons away: the ", result[1])
        self.assertTrue(result[1].endswith(" slow the march."), result[1])
        self.assertIsNone(result[2])

    def test_row_14_too_far_and_no_way_by_land(self):
        w = self.w
        for tag, country in w.countries.items():               # at war with every country: peace shuts no road
            if tag != "POR" and country.alive:
                at_war(w, "POR", tag)
        start = next(p.pos for p in sorted(w.provinces_of("POR"), key=lambda p: p.pos) if w.is_land(p.pos))
        group = self.stack("infantry", start)
        moves = min(u.moves_left for u in group)
        speed = min(w.unit_moves(u) for u in group)
        big = w.plan(group, moves + speed * 11, zoc_halts=False)
        far = [p for p in sorted(big) if big[p][0] > moves + speed * 3 and w.is_land(p)]
        self.assertTrue(far, "the map has land more than four seasons away")
        self.assertEqual(movement.refusal(w, group, far[0]), ("refusal", "Too far: more than 4 seasons away.", None))
        unreached = [p for p in sorted(w.provinces) if w.is_land(p) and p not in big]
        self.assertTrue(unreached, "the map has land no walk reaches")
        self.assertEqual(movement.refusal(w, group, unreached[0]),
                         ("refusal", "No way there by land: a ridge or the sea lies between.", None))

    def test_row_15_held_land_is_entered_with_a_note(self):
        w = self.w
        at_war(w)
        held = held_land(w, "CAS")
        near = next(n for n in sorted(neighbors(held.pos)) if n in w.provinces and w.is_land(n))
        group = self.stack("infantry", near)
        name = w.place(w.provinces[w.castle_of(held.pos)])
        self.assertEqual(movement.refusal(w, group, held.pos),
                         ("note", f"Moves in, but cannot take it: held by the castle of {name}.", "Take the castle first."))

    def test_row_16_a_ship_cannot_sail_onto_land(self):
        w = self.w
        sea, land = next((p, n) for p in sorted(w.terrain) for n in sorted(neighbors(p)) if w.is_sea(p) and w.is_land(n))
        ship = w.add_unit(CARAVEL, "POR", sea, moves=CARAVEL.moves)
        self.assertEqual(movement.refusal(w, [ship], land), ("refusal", "They cannot get there.", None))


class AiCastleAreasTest(unittest.TestCase):
    def setUp(self):
        self.w = clean(fresh("POR"))
        at_war(self.w)

    def test_the_defender_walks_back_onto_its_own_land_first(self):
        w = self.w
        a, b = pair(w, "POR", "POR")
        w.provinces[b].controller = "CAS"
        w.changed(ownership=True)
        stack = place(w, "infantry", 1, "POR", a, 6)
        self.assertTrue(ai._besiege_nearest(w, "POR", stack, w.attack_options_group(stack), {"CAS"}))
        self.assertEqual(stack[0].pos, b)

    def test_a_spare_stack_does_not_go_for_open_land_another_stack_claimed_this_season(self):
        w = self.w
        target = open_land(w, "CAS")
        stand = next(n for n in sorted(neighbors(target.pos)) if n in w.provinces and w.is_land(n)
                     and not w.units_at(n))
        memory = w.countries["POR"].memory
        memory["claims"] = {str(target.pos): (w.turn, -1)}          # another stack's claim, this season
        stack = place(w, "infantry", 1, "POR", stand, 6)
        ai._besiege_nearest(w, "POR", stack, w.attack_options_group(stack), {"CAS"})
        self.assertNotEqual(stack[0].pos, target.pos)

    def test_a_claim_of_an_earlier_season_is_forgotten(self):
        w = self.w
        target = open_land(w, "CAS")
        stand = next(n for n in sorted(neighbors(target.pos)) if n in w.provinces and w.is_land(n)
                     and not w.units_at(n))
        memory = w.countries["POR"].memory
        memory["claims"] = {str(target.pos): (w.turn - 1, -1)}
        stack = place(w, "infantry", 1, "POR", stand, 6)
        ai._besiege_nearest(w, "POR", stack, w.attack_options_group(stack), {"CAS"})
        self.assertEqual(memory["claims"].get(str(target.pos), (w.turn,))[0], w.turn,
                         "a claim lasts the season it was made in: an old one is forgotten")

    def test_no_ai_stack_stays_on_held_land_for_more_than_two_seasons(self):
        from hexa.campaign.game import GameManager
        from hexa.campaign.world import CampaignWorld
        world = CampaignWorld(7, map="random")
        world.player = None
        game = GameManager(world)
        parked = {}
        worst = 0
        for _ in range(40):
            game.end_season(player_ai=True)
            seen = {}
            for unit in world.units:
                if not unit.kind.war or unit.carrier is not None:
                    continue
                held = world.castle_of(unit.pos) is not None and world.at_war(unit.owner, world.provinces[unit.pos].owner)
                if held:
                    count = parked.get(unit.id, (unit.pos, 0))
                    count = (unit.pos, count[1] + 1) if count[0] == unit.pos else (unit.pos, 1)
                    seen[unit.id] = count
                    worst = max(worst, count[1])
            parked = seen
        self.assertLessEqual(worst, 2, "an AI stack parked on held land for three seasons")


if __name__ == "__main__":
    unittest.main()
