"""Rule tests. Run with:  python -m unittest discover -s tests -t ."""
import unittest

from hexa import ai
from hexa.hexgrid import distance, hex_center, neighbors, pixel_to_hex, within
from hexa.rules import (AI, CASTLE_INCOME, IMPROVEMENTS, PLAYER, SCOUT, SETTLER, SOLDIER,
                        TURN_LIMIT, WORKER)
from hexa.world import World
from tests.support.slow import slow


def free_neighbor(world, pos):
    return next(n for n in neighbors(pos) if world.is_free(n))


class HexGridTest(unittest.TestCase):
    def test_pixel_round_trip(self):
        for pos in [(0, 0), (3, 1), (7, 4), (14, 10), (5, 9)]:
            self.assertEqual(pixel_to_hex(hex_center(pos, (15, 12)), (15, 12)), pos)

    def test_neighbors_are_distance_one(self):
        for pos in [(4, 4), (4, 5), (0, 0)]:
            ns = list(neighbors(pos))
            self.assertEqual(len(set(ns)), 6)
            self.assertTrue(all(distance(pos, n) == 1 for n in ns))


class MapTest(unittest.TestCase):
    def test_maps_are_playable_and_repeatable(self):
        for seed in range(40):
            world = World(seed)
            self.assertEqual(world.terrain, World(seed).terrain)
            home, enemy = world.capital_of(PLAYER).pos, world.capital_of(AI).pos
            self.assertIn(home, world.cost_field(enemy), f"seed {seed}: castles not connected")
            for side in (PLAYER, AI):
                kinds = sorted(u.type.key for u in world.units_of(side))
                self.assertEqual(kinds, ["scout", "soldier", "worker"])


class RulesTest(unittest.TestCase):
    def setUp(self):
        self.world = World(7)
        self.home = self.world.capital_of(PLAYER).pos
        self.enemy_home = self.world.capital_of(AI).pos

    def test_move_spends_moves_and_reveals_map(self):
        scout = next(u for u in self.world.units_of(PLAYER) if u.type is SCOUT)
        before = len(self.world.explored)
        reach = self.world.reachable(scout)
        dest = max(reach, key=lambda p: (reach[p], p[0]))
        self.assertTrue(self.world.move(scout, dest))
        self.assertEqual(scout.moves_left, SCOUT.moves - reach[dest])
        self.assertGreater(len(self.world.explored), before)

    def test_cannot_move_on_enemy_turn_or_too_far(self):
        soldier = next(u for u in self.world.units_of(PLAYER) if u.type is SOLDIER)
        self.assertFalse(self.world.move(soldier, self.enemy_home))
        self.world.end_turn()
        self.assertEqual(self.world.current, AI)
        self.assertFalse(self.world.move(soldier, next(iter(self.world.reachable(soldier)))))

    def test_combat_damages_and_kills(self):
        w = self.world
        w.units.clear()
        attacker = w.spawn(SOLDIER, PLAYER, (6, 5))
        target = w.spawn(SCOUT, AI, free_neighbor(w, attacker.pos))
        target.hp = 1
        self.assertIn(target.pos, w.attack_options(attacker))
        self.assertTrue(w.attack(attacker, target))
        self.assertNotIn(target, w.units)
        self.assertEqual(attacker.moves_left, 0)
        self.assertEqual(w.attack_options(attacker), {})

    def test_civilians_cannot_attack(self):
        w = self.world
        w.units.clear()
        worker = w.spawn(WORKER, PLAYER, (6, 5))
        w.spawn(SCOUT, AI, free_neighbor(w, worker.pos))
        self.assertEqual(w.attack_options(worker), {})

    def test_capturing_the_castle_wins(self):
        w = self.world
        w.units.clear()
        spot = free_neighbor(w, self.enemy_home)
        scout = w.spawn(SCOUT, PLAYER, spot)
        self.assertNotIn(self.enemy_home, w.reachable(scout), "scouts cannot take castles")
        w.units.remove(scout)
        raider = w.spawn(SOLDIER, PLAYER, spot)
        self.assertTrue(w.move(raider, self.enemy_home))
        self.assertEqual(w.winner, PLAYER)
        self.assertFalse(w.move(raider, spot))

    def test_resting_heals(self):
        w = self.world
        unit = w.units_of(PLAYER)[0]
        unit.hp = 3
        w.end_turn()
        self.assertGreater(unit.hp, 3)


class EconomyTest(unittest.TestCase):
    def setUp(self):
        self.world = World(7)
        self.castle = self.world.capital_of(PLAYER)

    def test_castle_income_and_soldier_upkeep(self):
        w = self.world
        income = w.income(PLAYER)
        self.assertEqual(income["food"], CASTLE_INCOME["food"] - 1)   # one soldier eats 1 food
        self.assertEqual(income["stone"], CASTLE_INCOME["stone"])
        before = dict(w.stock[PLAYER])
        w.end_turn()
        w.end_turn()
        self.assertEqual(w.stock[PLAYER]["wood"], before["wood"] + income["wood"])

    def test_training_costs_resources_once_per_turn(self):
        w = self.world
        w.stock[PLAYER] = {"food": 20, "wood": 20, "stone": 20}
        unit = w.train(self.castle, SCOUT)
        self.assertIsNotNone(unit)
        self.assertEqual(unit.moves_left, 0, "new units act next turn")
        self.assertEqual(w.stock[PLAYER]["food"], 20 - SCOUT.cost["food"])
        self.assertIsNone(w.train(self.castle, SOLDIER), "only one unit per town per turn")
        w.stock[PLAYER] = {"food": 0, "wood": 0, "stone": 0}
        w.end_turn()
        w.end_turn()
        ok, reason = w.train_check(self.castle, SETTLER)
        self.assertFalse(ok)
        self.assertIn("resources", reason)

    def test_worker_builds_inside_borders_only(self):
        w = self.world
        w.units.clear()
        w.stock[PLAYER] = {"food": 20, "wood": 20, "stone": 20}
        inside = next(p for p in within(self.castle.pos, 2) if w.in_bounds(p)
                      and w.terrain[p] in ("grass", "dirt") and p != self.castle.pos)
        worker = w.spawn(WORKER, PLAYER, inside)
        self.assertEqual(worker.pos, inside)
        food_before = w.income(PLAYER)["food"]
        self.assertTrue(w.build(worker))
        self.assertEqual(w.improvements[inside], "farm")
        self.assertEqual(w.income(PLAYER)["food"], food_before + IMPROVEMENTS["farm"].yields["food"])
        self.assertEqual(w.stock[PLAYER]["wood"], 20 - IMPROVEMENTS["farm"].cost["wood"])

        outside = next(p for p in w.terrain if w.territory_owner(p) is None
                       and w.terrain[p] in ("grass", "dirt") and w.is_free(p))
        far_worker = w.spawn(WORKER, PLAYER, outside)
        improvement, reason = w.build_check(far_worker)
        self.assertIsNone(improvement)
        self.assertIn("borders", reason)

    def test_enemy_on_a_farm_stops_its_food(self):
        w = self.world
        w.units.clear()
        w.stock[PLAYER]["wood"] = 10
        spot = next(p for p in within(self.castle.pos, 2) if w.in_bounds(p)
                    and w.terrain[p] in ("grass", "dirt") and p != self.castle.pos)
        w.build(w.spawn(WORKER, PLAYER, spot))
        with_farm = w.income(PLAYER)["food"]
        w.units.clear()
        w.spawn(SCOUT, AI, spot)
        self.assertEqual(w.income(PLAYER)["food"], with_farm - 2)

    def test_settler_founds_a_town_with_its_own_land(self):
        w = self.world
        w.units.clear()
        site = next(p for p in w.terrain if w.terrain_at(p).passable
                    and all(distance(t.pos, p) >= 4 for t in w.towns))
        settler = w.spawn(SETTLER, PLAYER, site)
        too_close = w.spawn(SETTLER, PLAYER, free_neighbor(w, self.castle.pos))
        self.assertFalse(w.found_check(too_close)[0])
        town = w.found_town(settler)
        self.assertIsNotNone(town)
        self.assertNotIn(settler, w.units)
        self.assertEqual(w.territory_owner(site), PLAYER)
        self.assertIn(town, w.towns_of(PLAYER))

    def test_capturing_a_town_does_not_end_the_game(self):
        w = self.world
        w.units.clear()
        site = next(p for p in w.terrain if w.terrain_at(p).passable
                    and all(distance(t.pos, p) >= 4 for t in w.towns))
        w.current = AI
        town = w.found_town(w.spawn(SETTLER, AI, site))
        w.current = PLAYER
        raider = w.spawn(SOLDIER, PLAYER, free_neighbor(w, town.pos))
        self.assertTrue(w.move(raider, town.pos))
        self.assertEqual(town.owner, PLAYER)
        self.assertIsNone(w.winner)

    def test_starving_soldiers_lose_hp(self):
        w = self.world
        soldier = next(u for u in w.units_of(PLAYER) if u.type is SOLDIER)
        soldier.hp = 5
        w.stock[PLAYER]["food"] = -5
        soldier.acted = True   # no resting heal
        w.end_turn()
        w.end_turn()
        self.assertEqual(soldier.hp, 4)
        self.assertEqual(w.stock[PLAYER]["food"], 0)


class AITest(unittest.TestCase):
    def play_out(self, world):
        """Both sides played by the AI until someone wins."""
        while not world.winner:
            for _ in ai.take_turn(world, world.current):
                pass
            world.end_turn()
        return world

    def test_ai_takes_an_undefended_castle(self):
        w = World(3)
        w.units.clear()
        home = w.capital_of(PLAYER).pos
        w.spawn(SOLDIER, AI, free_neighbor(w, home))
        w.end_turn()
        list(ai.take_turn(w))
        self.assertEqual(w.winner, AI)

    def test_ai_builds_an_economy(self):
        for seed in range(6):
            w = World(seed)
            while w.turn < 15:
                if w.current == AI:
                    list(ai.take_turn(w))
                w.end_turn()
            mine = [p for p in w.improvements if w.territory_owner(p) == AI]
            self.assertGreaterEqual(len(mine), 3, f"seed {seed}: AI built too little")
            self.assertGreaterEqual(len(w.towns_of(AI)), 2, f"seed {seed}: AI never settled")

    @slow
    def test_ai_games_finish_without_errors(self):
        for seed in range(20):
            w = self.play_out(World(seed))
            self.assertIsNotNone(w.winner)
            for unit in w.units:
                self.assertTrue(w.terrain_at(unit.pos).passable)
                self.assertEqual(sum(u.pos == unit.pos for u in w.units), 1)
            for side in (PLAYER, AI):
                self.assertTrue(all(n >= 0 for n in w.stock[side].values()), f"seed {seed}: {w.stock}")

    def test_ai_beats_a_player_who_does_nothing(self):
        for seed in range(10):
            w = World(seed)
            while not w.winner:
                if w.current == AI:
                    list(ai.take_turn(w))
                w.end_turn()
            self.assertEqual(w.winner, AI, f"seed {seed}")
            self.assertLess(w.turn, 35, f"seed {seed}: AI too slow")

    def test_turn_limit_decides_on_score(self):
        w = World(5)
        w.units.remove(w.units_of(AI)[0])
        while not w.winner:
            w.end_turn()
        self.assertEqual(w.turn, TURN_LIMIT)
        self.assertEqual(w.winner, PLAYER)


if __name__ == "__main__":
    unittest.main()
