"""Colonisation mode rule tests. Run with:  python -m unittest discover -s tests -t ."""
import unittest

from hexa.colony import ai
from hexa.colony.rules import (BRAVE, COLONISERS, COLONIST, CROWN, FAVOUR_FOR_COLONIST, FUR_PRICE, GIFT_CALM,
                               GOAL_ENDLESS, GOAL_INDEPENDENCE, GOAL_SURVIVE, INDEPENDENCE_POP, NATIVES,
                               PIONEER, PLAYER, REGULAR, RIVALS, SHIP, SOLDIER, START_LAND, START_SEA,
                               SURVIVE_TURNS, TENSION_WAR)
from hexa.colony.world import ColonyWorld
from hexa.hexgrid import distance, neighbors, within


def first(world, side, unit_type):
    return next(u for u in world.units_of(side) if u.type is unit_type)


def free_land_near(world, pos, min_dist=1):
    return next(p for r in range(min_dist, 8) for p in sorted(within(pos, r)) if distance(p, pos) == r
                and world.is_land(p) and world.unit_at(p) is None and not world.village_at(p)
                and not world.colony_at(p))


def next_round(world):
    """End turns until it is the player's turn again (other sides do nothing)."""
    world.end_turn()
    while world.current != PLAYER and not world.winner:
        world.end_turn()


class MapTest(unittest.TestCase):
    def test_maps_are_playable(self):
        for seed in range(25):
            w = ColonyWorld(seed)
            self.assertEqual(w.terrain, ColonyWorld(seed).terrain)
            self.assertTrue(all(w.is_ocean((w.cols - 1, r)) for r in range(w.rows)), "east edge is open sea")
            for side in COLONISERS:
                land, sea = w.landings[side]
                self.assertTrue(w.is_land(land) and w.is_ocean(sea))
                ship = first(w, side, SHIP)
                self.assertEqual(sorted(u.type.key for u in w.cargo(ship)),
                                 ["colonist", "colonist", "pioneer", "soldier"])
            self.assertGreaterEqual(len(w.villages), 6)

    def test_settled_start(self):
        w = ColonyWorld(4, START_LAND)
        for side in COLONISERS:
            colony = w.capital_of(side)
            self.assertEqual(colony.pop, 2)
            self.assertEqual(w.unit_at(colony.pos).type, SOLDIER)


class LandingTest(unittest.TestCase):
    def test_sail_land_and_found_a_colony(self):
        w = ColonyWorld(2)
        ship = first(w, PLAYER, SHIP)
        land, _ = w.landings[PLAYER]
        self.assertTrue(w.move(ship, w.step_toward(ship, land)))
        colonist = next(u for u in w.cargo(ship) if u.type is COLONIST)
        shore = [p for p in w.reachable(colonist) if p != ship.pos]
        self.assertTrue(shore, "the ship reaches the coast in one turn")
        self.assertTrue(w.move(colonist, shore[0]))
        self.assertIsNone(colonist.carrier)
        self.assertEqual(colonist.moves_left, COLONIST.moves - 1, "going ashore costs one move")
        colony = w.found_colony(colonist)
        self.assertIsNotNone(colony)
        self.assertTrue(colony.capital)
        self.assertEqual(w.territory_owner(colony.pos), PLAYER)

    def test_units_board_a_ship(self):
        w = ColonyWorld(2, START_LAND)
        ship = first(w, PLAYER, SHIP)
        pioneer = first(w, PLAYER, PIONEER)
        w.units.remove(ship)
        ship.pos = next(p for p in neighbors(pioneer.pos) if w.is_ocean(p) and w.unit_at(p) is None) \
            if any(w.is_ocean(p) for p in neighbors(pioneer.pos)) else None
        if ship.pos is None:
            self.skipTest("pioneer not on the coast in this map")
        w.units.append(ship)
        self.assertIn(ship.pos, w.reachable(pioneer))
        w.move(pioneer, ship.pos)
        self.assertIs(pioneer.carrier, ship)
        self.assertIsNone(w.unit_at(ship.pos).carrier)


class EconomyTest(unittest.TestCase):
    def setUp(self):
        self.w = ColonyWorld(6, START_LAND)
        self.colony = self.w.capital_of(PLAYER)

    def test_buildings_need_people_to_work_them(self):
        w, colony = self.w, self.colony
        sites = [p for p in within(colony.pos, 2) if w.terrain.get(p) in ("grass", "dirt")
                 and p != colony.pos and not w.village_land(p)][:3]
        for pos in sites:
            w.improvements[pos] = "farm"
        self.assertEqual(len(w.worked(colony)), colony.pop)
        before = w.income_of_colony(colony)["food"]
        w.stock[PLAYER]["food"] = 50
        self.assertTrue(w.grow(colony))
        self.assertEqual(w.income_of_colony(colony)["food"], before + 3 - 1, "new family works a farm, eats 1")
        self.assertFalse(w.grow(colony), "one job per colony per turn")

    def test_winter_freezes_farms_and_burns_firewood(self):
        w, colony = self.w, self.colony
        spot = next(p for p in within(colony.pos, 2) if w.terrain.get(p) in ("grass", "dirt") and p != colony.pos)
        w.improvements[spot] = "farm"
        summer = w.income_of_colony(colony)
        w.turn = 4
        self.assertEqual(w.season(), "Winter")
        winter = w.income_of_colony(colony)
        self.assertEqual(winter["food"], summer["food"] - 3)
        self.assertEqual(winter["wood"], summer["wood"] - 1)

    def test_cold_hurts_units_outside_your_land(self):
        w = self.w
        scout = next(u for u in w.units_of(PLAYER) if u.type.key == "scout")
        scout.pos = next(p for p in w.terrain if w.is_land(p) and w.territory_owner(p) is None
                         and w.unit_at(p) is None)
        while w.season() != "Autumn":
            next_round(w)
        hp = scout.hp
        scout.acted = True
        next_round(w)
        self.assertEqual(w.season(), "Winter")
        self.assertEqual(scout.hp, hp - 1)

    def test_starvation_shrinks_the_colony(self):
        w, colony = self.w, self.colony
        colony.pop = 3
        w.stock[PLAYER]["food"] = -10
        next_round(w)
        self.assertEqual(colony.pop, 2)
        self.assertEqual(w.stock[PLAYER]["food"], 0)

    def test_colonist_from_a_colony_and_joining_back(self):
        w, colony = self.w, self.colony
        colonist = w.make_colonist(colony)
        self.assertIsNotNone(colonist)
        self.assertEqual(colony.pop, 1)
        next_round(w)
        self.assertTrue(w.join(colonist))
        self.assertEqual(colony.pop, 2)


class HomelandTest(unittest.TestCase):
    def test_trading_at_the_east_edge(self):
        w = ColonyWorld(3)
        ship = first(w, PLAYER, SHIP)
        self.assertFalse(w.market_check(ship, ("sell_furs",))[0])
        for passenger in w.cargo(ship):
            w.units.remove(passenger)
        ship.pos = (w.cols - 1, ship.pos[1])
        w.stock[PLAYER].update(furs=5, gold=0)
        self.assertTrue(w.market(ship, ("sell_furs",)))
        self.assertEqual(w.stock[PLAYER]["gold"], 5 * FUR_PRICE)
        self.assertEqual(w.favour[PLAYER], 5)
        self.assertTrue(w.market(ship, ("buy", COLONIST)))
        self.assertEqual(len(w.cargo(ship)), 1)

    def test_crown_favour_sends_a_colonist_in_spring(self):
        w = ColonyWorld(3, START_LAND)
        w.favour[PLAYER] = FAVOUR_FOR_COLONIST
        before = sum(1 for u in w.units_of(PLAYER) if u.type is COLONIST)
        while w.season() != "Spring" or w.turn == 1:
            next_round(w)
        self.assertEqual(sum(1 for u in w.units_of(PLAYER) if u.type is COLONIST), before + 1)
        self.assertEqual(w.favour[PLAYER], 0)


class NativesTest(unittest.TestCase):
    def setUp(self):
        self.w = ColonyWorld(5, START_LAND)
        self.village = self.w.villages[0]

    def test_attacking_natives_starts_a_war_and_gifts_end_it(self):
        w, village = self.w, self.village
        brave = w.unit_at(village.pos)
        soldier = first(w, PLAYER, SOLDIER)
        soldier.pos = free_land_near(w, village.pos)
        self.assertIn(brave.pos, w.attack_options(soldier))
        w.attack(soldier, brave.pos)
        self.assertIn(PLAYER, w.war[village.tribe])
        self.assertEqual(w.mood(village.tribe, PLAYER), "at war")
        self.assertFalse(w.trade_check(PLAYER, village)[0])
        w.stock[PLAYER]["gold"] = 100
        for _ in range(4):
            w.gift(PLAYER, village)
        self.assertNotIn(PLAYER, w.war[village.tribe])

    def test_braves_at_war_raid_and_burn(self):
        w, village = self.w, self.village
        colony = w.capital_of(PLAYER)
        w.units = [u for u in w.units if u.owner != PLAYER]
        w.add_tension(village.tribe, PLAYER, TENSION_WAR)
        spot = free_land_near(w, colony.pos)
        brave = w._new_unit(BRAVE, NATIVES, spot, home=village)
        w.improvements[spot] = "farm"
        w.current = NATIVES
        self.assertIn(colony.pos, w.attack_options(brave))
        pop = colony.pop
        w.attack(brave, colony.pos)
        self.assertEqual(colony.pop, pop - 1)
        brave.moves_left, brave.acted, brave.attacked = 3, False, False
        self.assertTrue(w.raze(brave))
        self.assertNotIn(spot, w.improvements)

    def test_village_contact_needed_to_trade(self):
        w, village = self.w, self.village
        w.stock[PLAYER]["wood"] = 20
        self.assertFalse(w.trade_check(PLAYER, village)[0])
        scout = next(u for u in w.units_of(PLAYER) if u.type.key == "scout")
        scout.pos = free_land_near(w, village.pos)
        self.assertTrue(w.trade(PLAYER, village))
        self.assertEqual(w.stock[PLAYER]["furs"], 3)
        self.assertFalse(w.trade_check(PLAYER, village)[0], "once per village per turn")

    def test_colonies_cannot_crowd_villages(self):
        w, village = self.w, self.village
        spot = free_land_near(w, village.pos, 2)
        colonist = w.spawn(COLONIST, PLAYER, spot)
        if distance(colonist.pos, village.pos) <= 2:
            self.assertFalse(w.found_check(colonist)[0])


class IndependenceTest(unittest.TestCase):
    def test_declare_and_win_by_holding_out(self):
        w = ColonyWorld(8, START_LAND, GOAL_INDEPENDENCE)
        colony = w.capital_of(PLAYER)
        self.assertFalse(w.independence_check()[0])
        colony.pop = INDEPENDENCE_POP
        for _ in range(2):
            w.spawn(SOLDIER, PLAYER, colony.pos)
        self.assertTrue(w.declare_independence())
        ship = first(w, PLAYER, SHIP)
        ship.pos = (w.cols - 1, ship.pos[1])
        self.assertFalse(w.market_check(ship, ("buy_food",))[0], "the Crown stops trading")
        landed = False
        while not w.winner:
            next_round(w)
            landed = landed or any(u.type is REGULAR for u in w.units)
            for unit in w.units_of(CROWN):
                w.units.remove(unit)     # our defenders win every fight in this test
        self.assertTrue(landed, "the royal army lands")
        self.assertEqual(w.winner, PLAYER)

    def test_losing_every_colony_loses(self):
        w = ColonyWorld(8, START_LAND, GOAL_ENDLESS)
        w.colonies = [c for c in w.colonies if c.owner != PLAYER]
        w.check_end()
        self.assertIn(w.winner, RIVALS)


class AITest(unittest.TestCase):
    def play(self, world, passive_player=False, limit=60):
        while not world.winner and world.turn <= limit:
            if not (passive_player and world.current == PLAYER):
                for _ in ai.take_turn(world, world.current):
                    pass
            world.end_turn()
        return world

    def test_companies_settle_and_grow(self):
        for seed in range(4):
            w = ColonyWorld(seed)
            self.play(w, passive_player=True, limit=16)
            for side in RIVALS:
                self.assertGreaterEqual(len(w.colonies_of(side)), 2, f"seed {seed}: {side} did not expand")
                self.assertGreaterEqual(w.population(side), 5, f"seed {seed}: {side} did not grow")

    def test_survival_games_end_on_time(self):
        for seed in range(4):
            w = self.play(ColonyWorld(seed, START_SEA, GOAL_SURVIVE))
            self.assertIsNotNone(w.winner, f"seed {seed}")
            self.assertLessEqual(w.turn, SURVIVE_TURNS)
            for unit in w.units:
                if unit.carrier is None:
                    self.assertTrue(w.is_ocean(unit.pos) if unit.type.naval else w.is_land(unit.pos))
            for side in COLONISERS:
                self.assertTrue(all(n >= 0 for n in w.stock[side].values()), f"seed {seed}: {w.stock[side]}")


if __name__ == "__main__":
    unittest.main()
