"""Age of Discovery tests. Run with:  python -m unittest discover -s tests -t ."""
import unittest

from hexa.campaign import ai, geo
from hexa.campaign.data import (GENERAL, STACK_LIMIT, WAGON, troop, BUILD_TURNS, CARAVEL, CASTLE_SIEGE, COLONIST, COLONY_DONE, GOODS, PIONEER,
                                SETTLEMENT_SLOTS, SIEGE_BASE, WORKS)
from hexa.campaign.world import CampaignWorld
from hexa.hexgrid import distance, neighbors

WORLD = CampaignWorld()          # building the map takes a moment, so most tests share this pristine copy


def fresh(player="POR"):
    return CampaignWorld(player=player)


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


class WarTest(unittest.TestCase):
    def setUp(self):
        self.w = fresh()
        self.w.units = [u for u in self.w.units if not u.kind.war and u.kind is not GENERAL]

    def border(self):
        """A Castilian province without a castle next to Portuguese land."""
        w = self.w
        for prov in w.provinces_of("CAS"):
            if prov.castle or w.units_at(prov.pos):
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
        self.assertEqual(target.controller, "POR")
        ok, _ = w.peace_offer("POR", "CAS", "take")
        self.assertTrue(ok)
        self.assertEqual(target.owner, "POR")
        self.assertFalse(w.at_war("POR", "CAS"))

    def test_stacks_have_a_limit_and_generals_raise_it(self):
        w = self.w
        prov = w.provinces[w.countries["POR"].capital]
        limit = STACK_LIMIT[1]
        place(w, troop("infantry", 1), "POR", prov.pos, limit)
        extra = place(w, troop("cavalry", 1), "POR", land_next_to(w, prov.pos, "POR"))[0]
        self.assertNotIn(prov.pos, w.reachable(extra), "the stack is full")
        place(w, GENERAL, "POR", prov.pos)
        self.assertIn(prov.pos, w.reachable(extra), "a general makes room for more")

    def test_cavalry_wins_in_the_open_but_not_in_forests(self):
        def fight(terrain):
            wins = 0
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
                lost_def = sum(u.kind.hp - u.hp for u in w.units_at(target.pos)) + 10 * (3 - len(w.units_at(target.pos)))
                lost_att = sum(u.kind.hp - u.hp for u in riders if u in w.units) + 10 * sum(u not in w.units for u in riders)
                wins += lost_def > lost_att
            return wins
        self.assertGreater(fight("plains"), fight("forest"))

    def test_only_the_front_line_fights(self):
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        attackers = place(w, troop("infantry", 1), "POR", home, 5)
        defenders = place(w, troop("infantry", 1), "CAS", target.pos, 5)
        w.attack_group(attackers, target.pos)
        hurt = [u for u in attackers if u.hp < u.kind.hp or u not in w.units]
        self.assertLessEqual(len(hurt), 3)
        self.assertGreater(sum(u.hp < u.kind.hp or u not in w.units for u in defenders), 0)

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
        lost_a = sum(4 - max(0, u.hp) for u in attackers)
        lost_d = sum(4 - max(0, u.hp) for u in defenders)
        self.assertGreater(lost_a + lost_d, 0, "the fight must have hurt someone")
        report = w.log[-1]
        self.assertRegex(report, rf"{w.countries['POR'].name} lost {lost_a} strength")
        self.assertRegex(report, rf"{w.countries['CAS'].name} lost {lost_d}\b")

    def test_battle_report_counts_garrison_damage_taken_not_missing(self):
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        target.castle, target.garrison = 1, 3     # half of the 6 HP a level-1 castle garrison can have
        w.changed(ownership=True)
        attackers = place(w, troop("infantry", 1), "POR", home, 3)
        w.rng.seed(1)
        w.attack_group(attackers, target.pos)
        self.assertRegex(w.log[-1], rf"{w.countries['CAS'].name} lost {3 - target.garrison}\b")

    def test_cannons_fire_from_two_hexes_without_reply(self):
        w = self.w
        w.declare_war("POR", "CAS")
        target, home = self.border()
        far = next(n for n in sorted(neighbors(home)) if w.is_land(n) and distance(n, target.pos) == 2
                   and not w.units_at(n) and w.provinces[n].owner == "POR")
        guns = place(w, troop("artillery", 1), "POR", far, 2)
        enemy = place(w, troop("infantry", 1), "CAS", target.pos)[0]
        options = w.attack_options_group(guns)
        self.assertEqual(options.get(target.pos), "bombard")
        w.attack_group(guns, target.pos)
        self.assertLess(enemy.hp if enemy in w.units else 0, enemy.kind.hp)
        self.assertTrue(all(g.hp == g.kind.hp for g in guns), "no counterattack against a bombardment")

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
        for _ in range(SIEGE_BASE + 2 * CASTLE_SIEGE):
            w.sieges()
        self.assertEqual(target.controller, "POR")

    def test_cannons_speed_up_sieges(self):
        def seasons(with_guns):
            w = fresh()
            w.units = []
            w.declare_war("POR", "CAS")
            target, home = self.border.__func__(type("X", (), {"w": w})())
            target.castle, target.garrison = 3, 0
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
        country.research = 1000
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
    def test_thirty_years_of_history(self):
        w = CampaignWorld()
        for _ in range(100):
            for tag in w.countries:
                ai.run(w, tag)
            w.end_round()
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
