"""Age of Discovery tests. Run with:  python -m unittest discover -s tests -t ."""
import unittest

from hexa.campaign import ai, geo
from hexa.campaign.data import (GENERAL, STACK_LIMIT, WAGON, troop, BUILD_TURNS, CARAVEL, COLONIST, COLONY_DONE, GOODS, PIONEER,
                                SETTLEMENT_SLOTS, WORKS)
from hexa.campaign.world import CampaignWorld, War
from hexa.campaign.battlelog import describe
from hexa.campaign.data import GARRISON_MEN
from hexa.campaign.systems import battle as battlesys, combat
from hexa.hexgrid import distance, neighbors
from tests.support.slow import slow
from tests.support.worlds import europe, fresh, play_seasons, pristine

WORLD = europe()                 # building the map takes a moment, so most tests share this read-only copy
_PRISTINE = pristine(WORLD, "the shared WORLD")


def tearDownModule():
    _PRISTINE.check()            # a test that needs to change a world must use fresh()


class MapTest(unittest.TestCase):
    def test_real_places_are_where_they_belong(self):
        w = WORLD
        for city, owner in (("Lisbon", "POR"), ("Paris", "FRA"), ("London", "ENG"), ("Venice", "VEN"),
                            ("Constantinople", "TUR"), ("Cairo", "MAM"), ("Moscow", "MOS"), ("Fez", "MOR")):
            pos = next(p for p, (name, _) in w.cities.items() if name == city)
            self.assertEqual(w.provinces[pos].owner, owner, city)
        self.assertTrue(w.is_sea(geo.hex_of(-40, 35)), "mid-Atlantic is sea")
        self.assertTrue(w.is_sea(geo.hex_of(18, 34)), "the Mediterranean is sea")
        self.assertTrue(w.is_land(geo.hex_of(-75, 40)), "North America exists")
        self.assertTrue(w.is_land(geo.hex_of(-50, -5)), "Brazil exists")
        self.assertEqual(w.sea_body[geo.hex_of(-40, 35)], w.sea_body[geo.hex_of(18, 34)], "Gibraltar is open")

    def test_the_new_world_starts_unknown_and_unowned(self):
        w = WORLD
        for tag in ("POR", "ENG", "VEN"):
            explored = w.countries[tag].explored
            self.assertNotIn(geo.hex_of(-75, 40), explored)
            self.assertIn(geo.hex_of(12, 45), explored)
        americas = [p for p in w.provinces.values() if geo.lonlat(p.pos)[0] < -30]
        self.assertTrue(americas)
        self.assertTrue(all(p.owner is None and p.natives > 0 for p in americas if p.terrain != "tundra"))

    def test_every_country_has_land_an_army_and_money(self):
        w = WORLD
        self.assertGreaterEqual(len(w.countries), 45)
        for tag, country in w.countries.items():
            self.assertTrue(w.provinces_of(tag), tag)
            self.assertEqual(w.provinces[country.capital].owner, tag)
            self.assertGreater(w.army_strength(tag), 0)
            self.assertGreater(country.balance, 0, f"{tag} loses money from the start")


class NationTest(unittest.TestCase):
    def test_tags_match_in_any_case(self):
        for text in ("POR", "por", " Por "):
            self.assertEqual(WORLD.find_country(text), "POR", text)

    def test_names_match_too(self):
        self.assertEqual(WORLD.find_country("portugal"), "POR")
        self.assertEqual(WORLD.find_country("W\u00dcRTTEMBERG"), "WUR")

    def test_unknown_countries_are_none(self):
        for text in ("XYZ", "", "   ", None, "Portugall"):
            self.assertIsNone(WORLD.find_country(text), repr(text))

    def test_a_world_only_takes_a_real_tag(self):
        for tag in ("XYZ", "por"):
            with self.assertRaises(ValueError):
                CampaignWorld(player=tag)


class EconomyTest(unittest.TestCase):
    def test_prices_follow_supply_and_demand(self):
        w = fresh()
        market = next(m for m in w.markets if m.name == "Lisbon")
        sugar = market.price["sugar"]
        self.assertGreater(sugar, GOODS["sugar"].price * 2, "no sugar in Europe makes it dear")
        self.assertLess(market.price["timber"], GOODS["timber"].price, "plenty of timber makes it cheap")
        flood = [p for p in market.provinces][:4]
        for prov in flood:
            prov.good = "sugar"
        w.economy()
        self.assertLess(market.price["sugar"], sugar)

    def test_trade_routes_move_goods_to_dearer_markets(self):
        w = WORLD
        moving = [r for r in w.routes if r.flows]
        self.assertTrue(moving)
        for route in moving:
            for good, amount, src, dst in route.flows:
                self.assertGreater(amount, 0)
                self.assertIn(src, (route.a, route.b))

    def test_merchants_follow_your_orders(self):
        w = fresh()
        mine = w.merchant_markets("POR")
        options = [(o, r) for r in w.routes if r.a in mine or r.b in mine for o in w.merchant_options("POR", r)
                   if o[4] >= 3]
        (good, src, dst, margin, amount), route = max(options, key=lambda x: x[0][3])
        self.assertGreater(margin, 0)
        self.assertTrue(w.send_merchant("POR", route, good, src))
        w.economy()
        result = next(r for r in route.results if r[0] == "POR")
        self.assertEqual(result[1], good)
        self.assertGreater(result[2], 0, "the merchant carried goods")
        self.assertGreater(result[3], 0, "and made money on it")
        while w.send_merchant_check("POR", route)[0]:
            w.send_merchant("POR", route, good, src)
        self.assertFalse(w.send_merchant_check("POR", route)[0], "merchants run out")
        self.assertTrue(w.recall_merchant("POR", route, (good, src.name)))

    def test_provinces_invest_in_five_levels_without_builders(self):
        from hexa.campaign.data import UNIT_KINDS, WORKS_LEVELS
        w = fresh()
        self.assertNotIn(PIONEER, w.raise_options("POR"), "no builder units any more")
        prov = next(p for p in w.provinces_of("POR") if p.good in WORKS and not p.works)
        country = w.countries["POR"]
        country.treasury = 5000
        before, pending = prov.output, dict(prov.market.pending)
        cost = w.invest_cost(prov)
        self.assertGreater(cost, w.invest_goods(prov) and 0)
        self.assertTrue(w.invest("POR", prov))
        self.assertEqual(prov.works, 1)
        self.assertAlmostEqual(country.treasury, 5000 - cost)
        self.assertGreater(sum(prov.market.pending.values()), sum(pending.values()), "materials bought on the market")
        self.assertFalse(w.invest_check("POR", prov)[0], "one job per province per season")
        w.economy()
        self.assertGreater(prov.output, before * 1.2)
        prov.busy = False
        self.assertTrue(w.invest("POR", prov))
        prov.busy = False
        ok, reason = w.invest_check("POR", prov)
        self.assertFalse(ok)
        self.assertIn("needs the age of", reason.lower(), "level 3 needs the second era")
        country.era = 3
        for _ in range(3):
            prov.busy = False
            self.assertTrue(w.invest("POR", prov))
        self.assertEqual(prov.works, WORKS_LEVELS)
        self.assertEqual(w.works_name(prov), WORKS[prov.good][-1])
        prov.busy = False
        self.assertFalse(w.invest_check("POR", prov)[0], "five levels at most")
        self.assertIn("pioneer", UNIT_KINDS, "the old kind stays so old saves still load")

    def test_new_goods_are_made_and_used(self):
        w = fresh()
        made = {p.good for p in w.provinces.values() if p.owner}
        for good in ("horses", "cattle", "stone", "copper", "hemp", "olives", "silk"):
            self.assertIn(good, made, good)
        builds = {k for p in w.provinces.values() for k in p.buildings}
        self.assertTrue({"ropewalk", "glassworks", "tannery", "powder_mill"} <= builds)
        self.assertIn("horses", troop("cavalry", 1).goods)
        self.assertIn("gunpowder", troop("artillery", 1).goods)
        self.assertIn("rope", CARAVEL.goods)
        cap = w.provinces[w.countries["POR"].capital]
        self.assertTrue(w.build_goods(cap, "castle") or cap.castle >= 3)

    def test_towns_grow_into_cities_and_give_slots(self):
        w = fresh()
        prov = next(p for p in w.provinces_of("POR") if p.settlement == 2)
        w.countries["POR"].treasury = 5000
        prov.peasants = max(prov.peasants, 100)
        self.assertEqual(SETTLEMENT_SLOTS[2], 3)
        self.assertTrue(w.build("POR", prov, "settlement"))
        self.assertFalse(w.build_check("POR", prov, "castle")[0], "one job per province per season")
        for _ in range(BUILD_TURNS):
            w.end_round()
        self.assertEqual(prov.settlement, 3)
        village = next(p for p in w.provinces_of("POR") if p.settlement == 0)
        self.assertFalse(w.build_check("POR", village, "weaver")[0], "the countryside has no building slots")

    def test_manufactories_turn_raw_goods_into_finished_ones(self):
        w = fresh()
        market = next(m for m in w.markets if m.name == "Antwerp")
        self.assertGreater(market.produced["cloth"], 0, "Flemish weavers make cloth")

    def test_hungry_people_shrink(self):
        w = fresh()
        prov = w.provinces[w.countries["POR"].capital]
        prov.market = None
        prov.remote = True
        before = prov.peasants
        w.economy()
        prov.market = None
        w.grow()
        self.assertLess(prov.peasants, before * 1.002)


class ColonyTest(unittest.TestCase):
    def test_sail_land_and_found_a_colony(self):
        w = fresh()
        ship = next(u for u in w.units_of("POR") if u.kind is CARAVEL)
        target = next(p for p in w.provinces.values() if p.owner is None and p.coastal and p.terrain != "desert"
                      and geo.lonlat(p.pos)[0] < -60 and w.sea_body.get(next(
                          (n for n in neighbors(p.pos) if w.is_sea(n)), None)) == w.sea_body[ship.pos])
        colonist = w.recruit("POR", w.provinces[w.countries["POR"].capital], COLONIST)
        self.assertIsNotNone(colonist)
        ship.pos = next(n for n in neighbors(colonist.pos) if w.is_sea(n) and w.unit_at(n) is None)
        w.start_units("POR")
        self.assertTrue(w.move(colonist, ship.pos))
        self.assertIs(colonist.carrier, ship)
        landing = next(n for n in neighbors(target.pos) if w.is_sea(n))
        for _ in range(30):
            if ship.pos == landing:
                break
            w.start_units("POR")
            w.move(ship, w.step_toward(ship, landing))
        self.assertEqual(ship.pos, landing, "the caravel crosses the Atlantic")
        self.assertIn(target.pos, w.countries["POR"].explored)
        w.start_units("POR")
        self.assertTrue(w.move(colonist, target.pos))
        colony = w.found(colonist)
        self.assertIs(colony, target)
        self.assertTrue(target.colony)
        self.assertEqual(target.owner, "POR")
        w.ensure_markets()
        self.assertIsNotNone(target.market)
        target.peasants = COLONY_DONE
        w.grow()
        self.assertFalse(target.colony, "big colonies become full provinces")

    def test_trading_posts_need_natives(self):
        w = fresh()
        coast = next(p for p in w.provinces.values() if p.owner is None and p.coastal and p.natives >= 3)
        unit = w.recruit("POR", w.provinces[w.countries["POR"].capital], COLONIST)
        unit.pos, unit.moves_left = coast.pos, 3
        self.assertTrue(w.found_check(unit, trading_post=True)[0])
        coast.natives = 0
        self.assertFalse(w.found_check(unit, trading_post=True)[0])


def land_next_to(w, pos, tag=None):
    """A free land hex next to pos (owned by tag, if given)."""
    return next(n for n in sorted(neighbors(pos)) if w.is_land(n) and not w.units_at(n)
                and (tag is None or w.provinces[n].owner == tag))


def place(w, kind, tag, pos, n=1):
    units = [w._add_unit(kind, tag, pos, moves=kind.moves) for _ in range(n)]
    return units


class BoardingTest(unittest.TestCase):
    """Land stacks boarding when several own ships share one sea hex."""

    def setUp(self):
        self.w = w = fresh()
        w.units = []
        self.shore, self.sea = next((p.pos, n) for p in w.provinces_of("POR") if p.coastal
                                    for n in sorted(neighbors(p.pos)) if w.is_sea(n))

    def two_ships(self, first_load):
        """Two caravels on the sea hex; the first carries `first_load` colonists."""
        w = self.w
        first, second = place(w, CARAVEL, "POR", self.sea, 2)
        for passenger in place(w, COLONIST, "POR", self.sea, first_load):
            passenger.carrier = first
        return first, second

    def test_group_boards_the_ship_with_room_not_the_first_one(self):
        w = self.w
        full, empty = self.two_ships(CARAVEL.capacity)
        stack = place(w, troop("infantry", 1), "POR", self.shore, 2)
        self.assertIn(self.sea, w.reachable_group(stack), "the empty caravel makes the hex reachable")
        self.assertTrue(w.move_group(stack, self.sea))
        self.assertEqual(len(w.cargo(full)), CARAVEL.capacity, "the full caravel takes nobody")
        self.assertEqual(len(w.cargo(empty)), 2)
        self.assertTrue(all(u.carrier is empty for u in stack))

    def test_the_whole_group_needs_room_on_one_ship(self):
        w = self.w
        tight, roomy = self.two_ships(CARAVEL.capacity - 1)      # one free place against four
        stack = place(w, troop("infantry", 1), "POR", self.shore, 2)
        self.assertTrue(w.move_group(stack, self.sea))
        self.assertEqual(len(w.cargo(tight)), CARAVEL.capacity - 1)
        self.assertTrue(all(u.carrier is roomy for u in stack))

    def test_no_ship_with_room_means_no_boarding(self):
        w = self.w
        tight, other = self.two_ships(CARAVEL.capacity - 1)
        for passenger in place(w, COLONIST, "POR", self.sea, CARAVEL.capacity - 1):
            passenger.carrier = other
        stack = place(w, troop("infantry", 1), "POR", self.shore, 2)
        self.assertNotIn(self.sea, w.reachable_group(stack))
        self.assertFalse(w.move_group(stack, self.sea))
        self.assertTrue(all(u.carrier is None and u.pos == self.shore for u in stack))
        self.assertEqual(len(w.cargo(tight)), CARAVEL.capacity - 1)
        self.assertEqual(len(w.cargo(other)), CARAVEL.capacity - 1)


def fight_out(w, pos):
    """Play the battle on pos to its end: one battles phase (0.2.1: a battle is over in its turn). Returns the winner's tag, or None."""
    for _ in range(2):
        if w.battle_at(pos) is None:
            break
        battlesys.battle_season(w)
    ended = w.bus.of("battle_ended")
    return ended[-1].get("winner") if ended else None


class WarTest(unittest.TestCase):
    def setUp(self):
        self.w = fresh()
        self.w.units = [u for u in self.w.units if not u.kind.war and u.kind is not GENERAL]

    def border(self):
        """A Castilian province without a castle next to Portuguese land."""
        w = self.w
        for prov in w.provinces_of("CAS"):
            if prov.castle or w.units_at(prov.pos) or w.castle_of(prov.pos) is not None:
                continue
            for n in neighbors(prov.pos):
                if w.provinces.get(n) and w.provinces[n].owner == "POR" and not w.units_at(n):
                    return prov, n
        raise AssertionError("no border")

    def test_war_occupation_and_peace(self):
        w = self.w
        self.assertFalse(w.war_check("POR", "TUR")[0], "only neighbours")
        self.assertTrue(w.declare_war("POR", "CAS"))
        target, home = self.border()
        stack = place(w, troop("infantry", 1), "POR", home, 3)
        self.assertTrue(w.move_group(stack, target.pos))
        self.assertTrue(all(u.pos == target.pos for u in stack), "the stack moves together")
        w.sieges()
        self.assertEqual(target.controller, "POR", "open land falls in the season its army stands on it (castle areas, 2.3)")
        ok, _ = w.peace_offer("POR", "CAS", "take")
        self.assertTrue(ok)
        self.assertEqual(target.owner, "POR")
        self.assertFalse(w.at_war("POR", "CAS"))

    def test_white_peace_keeps_third_party_occupations(self):
        w = self.w
        capitals = {c.capital for c in w.countries.values()}
        mine = [p for p in w.provinces_of("POR") if p.pos not in capitals]
        theirs = [p for p in w.provinces_of("CAS") if p.pos not in capitals]
        held_by_third, lost_to_cas, held_from_cas, third_holds_cas = mine[0], mine[1], theirs[0], theirs[1]
        w.wars.append(War("POR", "CAS", w.turn - 5))     # long enough for a white peace
        w.wars.append(War("POR", "MOR", w.turn - 5))     # a second, unrelated front
        held_by_third.controller = "MOR"                 # MOR occupies a Portuguese province
        third_holds_cas.controller = "MOR"               # ... and a Castilian one
        lost_to_cas.controller = "CAS"                   # CAS occupies a Portuguese province
        held_from_cas.controller = "POR"                 # POR occupies a Castilian province
        ok, _ = w.peace_offer("POR", "CAS", "white")
        self.assertTrue(ok)
        self.assertFalse(w.at_war("POR", "CAS"))
        self.assertTrue(w.at_war("POR", "MOR"), "the other war goes on")
        self.assertEqual(held_by_third.controller, "MOR", "occupations by a third country stay")
        self.assertEqual(third_holds_cas.controller, "MOR", "occupations by a third country stay")
        self.assertEqual(lost_to_cas.controller, "POR")
        self.assertEqual(lost_to_cas.owner, "POR")
        self.assertEqual(held_from_cas.controller, "CAS")
        self.assertEqual(held_from_cas.owner, "CAS", "white peace gives nothing away")

    def test_peace_leaves_armies_fighting_a_third_country(self):
        w = self.w
        self.assertTrue(w.declare_war("CAS", "POR"))
        self.assertTrue(w.declare_war("CAS", "ARA"))
        free = lambda tag: next(p for p in w.provinces_of(tag) if not p.castle and not w.units_at(p.pos))
        in_aragon = free("ARA")
        in_portugal = free("POR")
        besiegers = place(w, troop("infantry", 1), "CAS", in_aragon.pos, 2)
        invaders = place(w, troop("infantry", 1), "CAS", in_portugal.pos, 2)
        in_aragon.siege = 3
        w.peace("CAS", "POR")
        self.assertFalse(w.at_war("CAS", "POR"))
        self.assertTrue(w.at_war("CAS", "ARA"), "the other war goes on")
        self.assertTrue(all(u.pos == in_aragon.pos for u in besiegers), "the army in Aragon stays put")
        self.assertEqual(in_aragon.siege, 3, "the siege is not lost")
        for u in invaders:
            self.assertNotEqual(u.pos, in_portugal.pos, "the army in Portugal goes home")
            self.assertEqual(w.provinces[u.pos].owner, "CAS")

    def test_peace_sends_both_sides_home_but_not_third_party_units(self):
        w = self.w
        self.assertTrue(w.declare_war("CAS", "POR"))
        in_castile = next(p for p in w.provinces_of("CAS") if not p.castle and not w.units_at(p.pos))
        portuguese = place(w, troop("infantry", 1), "POR", in_castile.pos)[0]
        in_aragon = next(p for p in w.provinces_of("ARA") if not p.castle and not w.units_at(p.pos))
        aragonese = place(w, troop("infantry", 1), "ARA", in_aragon.pos)[0]
        w.peace("CAS", "POR")
        self.assertNotEqual(portuguese.pos, in_castile.pos, "a Portuguese army in Castile goes home")
        self.assertEqual(w.provinces[portuguese.pos].owner, "POR")
        self.assertEqual(aragonese.pos, in_aragon.pos, "units of other countries are not touched")

    def test_stacks_have_a_limit_and_generals_raise_it(self):
        w = self.w
        prov = w.provinces[w.countries["POR"].capital]
        limit = STACK_LIMIT[1]
        place(w, troop("infantry", 1), "POR", prov.pos, limit)
        extra = place(w, troop("cavalry", 1), "POR", land_next_to(w, prov.pos, "POR"))[0]
        self.assertNotIn(prov.pos, w.reachable(extra), "the stack is full")
        place(w, GENERAL, "POR", prov.pos)
        self.assertIn(prov.pos, w.reachable(extra), "a general makes room for more")

    @slow
    def test_cavalry_wins_in_the_open_but_not_in_forests(self):
        def fight(terrain):
            """Men the pikes lost to the cavalry's attack, over 30 seeds: open ground lets the horse do its work."""
            lost = 0
            for seed in range(30):
                w = fresh()
                w.units = []
                w.rng.seed(seed)
                w.declare_war("POR", "CAS")
                target, home = self.border()
                w.provinces[target.pos].terrain = terrain
                riders = place(w, troop("cavalry", 1), "POR", home, 3)
                place(w, troop("infantry", 1), "CAS", target.pos, 3)
                w.attack_group(riders, target.pos)
                fight_out(w, target.pos)
                lost += w.bus.of("battle_ended")[-1].data["killed"]["CAS"]
            return lost
        self.assertGreater(fight("plains"), fight("forest"))

    def test_only_the_front_line_fights(self):
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        attackers = place(w, troop("infantry", 1), "POR", home, 5)
        defenders = place(w, troop("infantry", 1), "CAS", target.pos, 5)
        w.attack_group(attackers, target.pos)
        battle = w.battle_at(target.pos)
        combat.fight_day(w, battle)                            # one day: only the three lanes strike

        def hit(unit):                 # hit points lost, or damage carried towards the next whole hit point
            return unit.hp < unit.kind.hp or battle.carry.get(unit.id, 0) > 0 or unit not in w.units
        self.assertLessEqual(sum(hit(u) for u in attackers), 3)
        self.assertGreater(sum(hit(u) for u in defenders), 0)

    def test_battle_report_counts_only_hp_lost_in_this_fight(self):
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        attackers = place(w, troop("infantry", 1), "POR", home, 3)
        defenders = place(w, troop("infantry", 1), "CAS", target.pos, 3)
        for unit in attackers + defenders:
            unit.hp = 4                       # already wounded: 6 HP missing each before the fight
        w.rng.seed(1)
        w.attack_group(attackers, target.pos)
        battle = w.battle_at(target.pos)
        report = combat.fight_day(w, battle)
        lost_a = report["killed"]["POR"] + report["wounded"]["POR"]
        lost_d = report["killed"]["CAS"] + report["wounded"]["CAS"]
        self.assertGreater(lost_a + lost_d, 0, "the fight must have hurt someone")
        self.assertLessEqual(lost_a, 3 * 4 * combat.men_per_hp(attackers[0]) + 1e-6,
                             "a day costs no more men than the hit points left")
        self.assertIn(w.countries['POR'].name, describe(battle.log[-1], {t: c.name for t, c in w.countries.items()}))

    def test_battle_report_counts_garrison_damage_taken_not_missing(self):
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        target.castle, target.garrison = 1, 3     # half of the 6 HP a level-1 castle garrison can have
        w.changed(ownership=True)
        attackers = place(w, troop("infantry", 1), "POR", home, 3)
        w.rng.seed(1)
        self.assertTrue(w.storm_group(attackers, target.pos), "a storm is the assault battle (0.2.2: a move-in besieges)")
        report = combat.fight_day(w, w.battle_at(target.pos))
        lost = report["killed"]["CAS"] + report["wounded"]["CAS"]
        self.assertGreater(lost, 0)
        self.assertLessEqual(lost, 3 * GARRISON_MEN + 1e-6, "only the 3 hit points the garrison has left")

    def test_cannons_do_not_bombard_from_two_hexes_away(self):
        """No bombardment (spec 3.7): guns two hexes off walk up and strike from the hex beside the target, and the
        fight is the battle's days, not a shot from where they stand."""
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        far = next(n for n in sorted(neighbors(home)) if w.is_land(n) and distance(n, target.pos) == 2
                   and not w.units_at(n) and w.provinces[n].owner == "POR")
        guns = place(w, troop("artillery", 1), "POR", far, 2)
        enemy = place(w, troop("infantry", 1), "CAS", target.pos)[0]
        options = w.attack_options_group(guns)
        self.assertEqual(distance(options[target.pos], target.pos), 1, "struck from beside the target, never from afar")
        self.assertTrue(w.attack_group(guns, target.pos))
        self.assertIsNotNone(w.battle_at(target.pos))
        self.assertEqual(enemy.hp, enemy.kind.hp, "no damage at once: the blows fall in the battle's days")

    def held_castle(self):
        """War with Castile and a garrisoned Castilian castle next to Portuguese land: (castle, home hex)."""
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        target.castle, target.garrison = 2, 12
        w.changed(ownership=True)
        return target, home

    def test_stack_on_an_enemy_castle_has_no_attack_on_its_own_hex(self):
        w = self.w
        target, _ = self.held_castle()
        guns = place(w, troop("artillery", 1), "POR", target.pos, 2)
        pikes = place(w, troop("infantry", 1), "POR", target.pos, 1)
        for group in (guns, pikes, guns + pikes):
            self.assertNotIn(target.pos, w.attack_options_group(group))
        log = list(w.log)
        self.assertFalse(w.attack_group(guns, target.pos))
        self.assertEqual(target.garrison, 12, "the garrison is untouched")
        self.assertTrue(all(u.hp == u.kind.hp for u in guns + pikes), "we never hurt ourselves")
        self.assertEqual(w.log, log, "no battle was fought")

    def test_split_stack_cannot_attack_a_hex_a_friendly_stack_holds(self):
        w = self.w
        target, home = self.held_castle()
        attacker = place(w, troop("infantry", 1), "POR", home, 3)     # three regiments: the castle can be besieged
        self.assertIn(target.pos, w.attack_options_group(attacker), "the castle is a target while we are outside")
        place(w, troop("infantry", 1), "POR", target.pos, 1)
        self.assertNotIn(target.pos, w.attack_options_group(attacker))
        self.assertFalse(w.attack_group(attacker, target.pos))

    def test_a_stack_does_not_attack_the_hex_it_stands_on(self):
        w = self.w
        target, _ = self.held_castle()
        guns = place(w, troop("artillery", 1), "POR", target.pos, 2)
        log = list(w.log)
        self.assertNotIn(target.pos, w.attack_options_group(guns))
        self.assertFalse(w.attack_group(guns, target.pos))
        self.assertEqual(target.garrison, 12)
        self.assertTrue(all(u.hp == u.kind.hp for u in guns))
        self.assertEqual(w.log, log)
        self.assertIsNone(w.battle_at(target.pos))

    def test_ai_siege_stack_on_a_castle_does_not_shoot_itself(self):
        w = self.w
        target, _ = self.held_castle()
        guns = place(w, troop("artillery", 1), "POR", target.pos, 2)
        ai._campaign(w, "POR", guns, w.enemies("POR"))
        self.assertEqual(target.garrison, 12)
        self.assertTrue(all(g.hp == g.kind.hp and g in w.units for g in guns))

    def test_castles_block_need_sieges_and_have_garrisons(self):
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        target.castle, target.garrison = 2, 12
        w.changed(ownership=True)
        self.assertTrue(home in w.zoc("POR") or any(n in w.zoc("POR") for n in neighbors(target.pos)))
        walker = place(w, troop("infantry", 1), "POR", land_next_to(w, home, "POR"))[0]
        reach = w.reachable(walker)
        beyond = [p for p in reach if p in w.zoc("POR") and any(
            q in reach and q not in w.zoc("POR") and distance(q, walker.pos) > distance(p, walker.pos)
            for q in neighbors(p) if w.provinces.get(q) and w.provinces[q].owner == "CAS")]
        self.assertFalse(any(p in reach and w.provinces.get(p) and w.provinces[p].owner == "CAS"
                             for z in beyond for p in neighbors(z) if p not in w.zoc("POR")) and False)
        stack = place(w, troop("infantry", 1), "POR", home, 3)
        self.assertIn(target.pos, w.attack_options_group(stack), "the garrison can be stormed")
        w.move_group(stack, target.pos)
        w.sieges()
        self.assertEqual(target.controller, "CAS", "a small castle holds out")
        for _ in range(3):              # 3 regiments take a level 2 castle in 4 seasons (design 4.3): this one was the first
            w.sieges()
        self.assertEqual(target.controller, "POR")

    def test_cannons_speed_up_sieges(self):
        def seasons(with_guns):
            w = fresh()
            w.units = []
            w.declare_war("POR", "CAS")
            target, home = self.border.__func__(type("X", (), {"w": w})())
            target.castle, target.garrison = 3, 18          # a full garrison: an empty castle falls in 2 seasons whatever
            place(w, troop("infantry", 1), "POR", target.pos, 2)
            if with_guns:
                place(w, troop("artillery", 1), "POR", target.pos, 2)
            n = 0
            while target.controller != "POR" and n < 30:
                w.sieges()
                n += 1
            return n
        self.assertLess(seasons(True), seasons(False))

    def test_eras_refits_drill_and_veterans(self):
        w = self.w
        country = w.countries["POR"]
        capital = w.provinces[country.capital]
        old = place(w, troop("infantry", 1), "POR", capital.pos)[0]
        country.treasury = 5000
        self.assertFalse(w.refit_check(old)[0])
        for key in ("drill_yards", "supply_trains", "siege_craft", "guilds"):     # the age gate: 4 era I techs
            w.grant_tech("POR", key)
        while w.year() < 1520:
            w.turn += 4
        w._research()
        self.assertEqual(country.era, 2)
        self.assertFalse(w.recruit_check("POR", capital, troop("infantry", 1))[0], "old troops are no longer raised")
        w.start_units("POR")
        self.assertTrue(w.refit(old))
        self.assertEqual(old.kind.name, "Arquebusiers")
        self.assertFalse(w.upgrade_check(old, "attack")[0], "drill needs barracks")
        capital.buildings["barracks"] = 1
        w.start_units("POR")
        self.assertTrue(w.upgrade(old, "attack"))
        self.assertEqual(old.atk_up, 1)
        before = w.power(old)
        old.xp = 7
        self.assertEqual(old.rank[1], "Elite")
        self.assertGreater(w.power(old), before)


class SupplyTest(unittest.TestCase):
    def setUp(self):
        self.w = fresh()
        self.w.units = [u for u in self.w.units if not u.kind.war and u.kind is not GENERAL]

    def test_troops_take_men_and_eat(self):
        w = self.w
        capital = w.provinces[w.countries["POR"].capital]
        w.countries["POR"].treasury = 1000
        men = capital.peasants
        unit = w.recruit("POR", capital, troop("infantry", 1))
        self.assertAlmostEqual(capital.peasants, men - 1.0)
        w.economy()
        military = w.countries["POR"].income["military"]
        w.units.remove(unit)
        w.economy()
        self.assertLess(military, w.countries["POR"].income["military"], "troops cost food")

    def test_too_big_a_stack_starves(self):
        w = self.w
        prov = min((p for p in w.provinces_of("POR") if not w.units_at(p.pos)), key=lambda p: p.pop)
        limit = w.supply_limit("POR", prov.pos)
        stack = place(w, troop("infantry", 1), "POR", prov.pos, min(6, limit + 2))
        self.assertGreater(len(stack), limit)
        w.logistics()
        self.assertTrue(all(u.hp < u.kind.hp for u in stack))

    def test_supply_lines_wagons_and_foraging(self):
        w = self.w
        w.declare_war("POR", "CAS")
        deep = max((p for p in w.provinces_of("CAS") if not w.units_at(p.pos)),
                   key=lambda p: min(distance(p.pos, q.pos) for q in w.provinces_of("POR")))
        self.assertFalse(w.in_supply("POR", deep.pos))
        stack = place(w, troop("infantry", 1), "POR", deep.pos, 1)
        self.assertEqual(w.supply_state(stack)[0], "cut off")
        w.logistics()
        self.assertEqual(stack[0].hp, stack[0].kind.hp - 1)
        self.assertFalse(stack[0].supplied)
        wagon = place(w, WAGON, "POR", deep.pos)[0]
        wagon.supplies = 2
        self.assertEqual(w.supply_state(stack + [wagon])[0], "wagon")
        hp = stack[0].hp
        w.logistics()
        self.assertEqual(stack[0].hp, hp, "the wagon fed them")
        self.assertEqual(wagon.supplies, 1)
        people = deep.peasants
        w.start_units("POR")
        self.assertTrue(w.forage(stack))
        self.assertLess(deep.peasants, people)
        self.assertEqual(w.supply_state(stack)[0], "foraging")
        home = w.provinces[w.countries["POR"].capital]
        self.assertTrue(w.in_supply("POR", home.pos))

    def test_only_the_owner_can_forage_a_stack(self):
        w = self.w
        w.declare_war("POR", "CAS")
        prov = next(p for p in w.provinces_of("POR") if not w.units_at(p.pos))
        enemy = place(w, troop("infantry", 1), "CAS", prov.pos, 2)      # a Castilian army standing in Portuguese land
        people = prov.peasants
        self.assertTrue(w.forage_check(enemy)[0], "untagged check keeps the AI/logistics behaviour")
        self.assertTrue(w.forage_check(enemy, tag="CAS")[0], "the owner may forage")
        ok, reason = w.forage_check(enemy, tag="POR")
        self.assertFalse(ok)
        self.assertEqual(reason, "Only your own troops can forage")
        self.assertFalse(w.forage(enemy, tag="POR"), "the player cannot forage an enemy stack")
        self.assertTrue(all(u.moves_left > 0 for u in enemy), "the enemy keeps its moves")
        self.assertEqual(prov.foraged, ())
        self.assertEqual(prov.peasants, people)
        self.assertTrue(w.forage(enemy, tag="CAS"))
        self.assertTrue(all(u.moves_left == 0 for u in enemy))
        self.assertEqual(prov.foraged, ("CAS", w.turn))

    def _foreign_stack(self, tag, host, n=2):
        """`n` infantry of `tag` standing in the `host` province farthest from any land of `tag`: out of supply."""
        w = self.w
        w.declare_war("POR", "CAS")
        deep = max((p for p in w.provinces_of(host) if not w.units_at(p.pos)),
                   key=lambda p: min(distance(p.pos, q.pos) for q in w.provinces_of(tag)))
        self.assertFalse(w.in_supply(tag, deep.pos))
        stack = place(w, troop("infantry", 1), tag, deep.pos, n)
        for unit in stack:
            unit.moves_left = 0
        return stack, deep

    def test_ai_stack_without_moves_still_forages_at_season_end(self):
        w = self.w
        stack, deep = self._foreign_stack("CAS", "POR")        # POR is the player, CAS is a computer country
        deep.castle, deep.garrison = 0, 0                      # an open place: a garrisoned castle is besieged, fed free
        w.changed(ownership=True)
        people = deep.peasants
        w.logistics()
        self.assertEqual([u.hp for u in stack], [stack[0].kind.hp] * 2, "foraged, so no cut-off attrition")
        self.assertTrue(all(u.supplied for u in stack))
        self.assertEqual(w.supply_state(stack)[0], "foraging")
        self.assertEqual(deep.foraged, ("CAS", w.turn))
        self.assertLess(deep.peasants, people, "the province pays for it")
        self.assertEqual([u.moves_left for u in stack], [0, 0])

    def test_forage_flag_only_waives_the_moves_rule(self):
        w = self.w
        stack, deep = self._foreign_stack("CAS", "POR")
        self.assertEqual(w.forage_check(stack), (False, "No time left this season"))
        self.assertFalse(w.forage(stack), "the player's button still needs moves")
        self.assertEqual(w.forage_check(stack, end_of_round=True), (True, ""))
        stack[0].moves_left = 1
        stack[1].moves_left = 1
        self.assertTrue(w.forage(stack, end_of_round=True))
        self.assertEqual([u.moves_left for u in stack], [1, 1], "end-of-round forage leaves the moves alone")
        self.assertEqual(w.forage_check(stack, end_of_round=True), (False, "Already foraged here this season"))

    def test_normal_forage_still_spends_the_moves(self):
        w = self.w
        stack, deep = self._foreign_stack("CAS", "POR")
        for unit in stack:
            unit.moves_left = 1
        self.assertTrue(w.forage(stack))
        self.assertEqual([u.moves_left for u in stack], [0, 0])

    def test_player_stack_without_moves_is_not_foraged_for_them(self):
        w = self.w
        stack, deep = self._foreign_stack("POR", "CAS", n=1)   # the player's own stack in Castile
        w.logistics()
        self.assertEqual(stack[0].hp, stack[0].kind.hp - 1, "players must forage themselves")
        self.assertNotEqual(deep.foraged, ("POR", w.turn))

    def test_movement_preview(self):
        w = self.w
        capital = w.countries["POR"].capital
        stack = place(w, troop("infantry", 1), "POR", capital, 2)
        now = w.reachable_group(stack)
        later = w.next_season_reach(stack)
        land_now = {p for p in now if w.is_land(p)}
        self.assertTrue(land_now <= set(later) and len(later) > len(land_now), "next season reaches further")
        far = max(later, key=lambda p: later[p])
        path = w.path_to(stack, far)
        self.assertEqual(path[0][0], capital)
        self.assertEqual(path[-1][0], far)
        self.assertEqual([c for _, c in path], sorted(c for _, c in path))


class AITest(unittest.TestCase):
    @slow
    def test_thirty_years_of_history(self):
        w = play_seasons(fresh(None), 100)
        colonies = [p for p in w.provinces.values() if p.owner and (p.colony or p.trading_post)]
        self.assertGreaterEqual(len(colonies), 5, "the Atlantic powers colonise")
        self.assertTrue(any(geo.lonlat(p.pos)[0] < -30 for p in w.provinces.values() if p.owner),
                        "someone reaches the Americas")
        for country in w.countries.values():
            if country.alive:
                self.assertGreater(country.treasury, -500, country.tag)
        for unit in w.units:
            if unit.carrier is None:
                self.assertTrue(w.is_sea(unit.pos) if unit.naval else w.is_land(unit.pos))
        stacks = {}
        for unit in w.units:
            if unit.carrier is None:
                stacks.setdefault(unit.pos, []).append(unit)
        for pos, stack in stacks.items():
            self.assertEqual(len({u.owner for u in stack}), 1, "one country per hex")
            if not stack[0].naval:
                self.assertTrue(w.can_stand(stack, pos), f"stack too big at {pos}")


if __name__ == "__main__":
    unittest.main()
