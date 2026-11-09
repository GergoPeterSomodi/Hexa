"""Rule tests. Run with:  python -m unittest discover tests"""
import unittest

from hexa import ai
from hexa.hexgrid import distance, hex_center, neighbors, pixel_to_hex
from hexa.rules import AI, PLAYER, SCOUT, SOLDIER, SPAWN_EVERY, TURN_LIMIT
from hexa.world import World


def clear_units(world):
    world.units.clear()


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
            again = World(seed)
            self.assertEqual(world.terrain, again.terrain)
            home, enemy = (c.pos for c in world.castles)
            self.assertIn(home, world.cost_field(enemy), f"seed {seed}: castles not connected")
            self.assertEqual(len(world.units_of(PLAYER)), 2)
            self.assertEqual(len(world.units_of(AI)), 2)


class RulesTest(unittest.TestCase):
    def setUp(self):
        self.world = World(7)
        self.home = self.world.castles_of(PLAYER)[0].pos
        self.enemy_home = self.world.castles_of(AI)[0].pos

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
        clear_units(w)
        attacker = w.spawn(SOLDIER, PLAYER, (6, 5))
        free = [n for n in neighbors(attacker.pos) if w.is_free(n)]
        target = w.spawn(SCOUT, AI, free[0])
        target.hp = 1
        self.assertIn(target.pos, w.attack_options(attacker))
        self.assertTrue(w.attack(attacker, target))
        self.assertNotIn(target, w.units)
        self.assertEqual(attacker.moves_left, 0)
        self.assertEqual(w.attack_options(attacker), {})

    def test_capturing_the_castle_wins(self):
        w = self.world
        clear_units(w)
        free = [n for n in neighbors(self.enemy_home) if w.is_free(n)]
        scout = w.spawn(SCOUT, PLAYER, free[0])
        self.assertNotIn(self.enemy_home, w.reachable(scout), "scouts cannot take castles")
        w.units.remove(scout)
        raider = w.spawn(SOLDIER, PLAYER, free[0])
        self.assertTrue(w.move(raider, self.enemy_home))
        self.assertEqual(w.winner, PLAYER)
        self.assertFalse(w.move(raider, free[0]))

    def test_castles_train_soldiers(self):
        w = self.world
        while w.turn < SPAWN_EVERY:
            w.end_turn()
        self.assertEqual(len([u for u in w.units_of(PLAYER) if u.type is SOLDIER]), 2)

    def test_resting_heals(self):
        w = self.world
        unit = w.units_of(PLAYER)[0]
        unit.hp = 3
        w.end_turn()
        self.assertGreater(unit.hp, 3)


class AITest(unittest.TestCase):
    def play_out(self, world, max_turns=100):
        """Both sides played by the AI until someone wins."""
        while not world.winner and world.turn <= max_turns:
            for _ in ai.take_turn(world, world.current):
                pass
            world.end_turn()
        return world

    def test_ai_takes_an_undefended_castle(self):
        w = World(3)
        clear_units(w)
        home = w.castles_of(PLAYER)[0].pos
        free = [n for n in neighbors(home) if w.is_free(n)]
        w.spawn(SOLDIER, AI, free[0])
        w.end_turn()
        list(ai.take_turn(w))
        self.assertEqual(w.winner, AI)

    def test_ai_games_finish_without_errors(self):
        finished = 0
        for seed in range(25):
            w = self.play_out(World(seed))
            finished += w.winner is not None
            for unit in w.units:
                self.assertTrue(w.terrain_at(unit.pos).passable)
                self.assertEqual(sum(u.pos == unit.pos for u in w.units), 1)
        self.assertEqual(finished, 25, "every game ends by conquest or at the turn limit")

    def test_ai_beats_a_player_who_does_nothing(self):
        for seed in range(10):
            w = World(seed)
            while not w.winner:
                if w.current == AI:
                    list(ai.take_turn(w))
                w.end_turn()
            self.assertEqual(w.winner, AI, f"seed {seed}")
            self.assertLess(w.turn, 30, f"seed {seed}: AI too slow")

    def test_turn_limit_decides_on_army_strength(self):
        w = World(5)
        w.units.remove(w.units_of(AI)[0])
        while not w.winner:
            w.end_turn()
        self.assertEqual(w.turn, TURN_LIMIT)
        self.assertEqual(w.winner, PLAYER)


if __name__ == "__main__":
    unittest.main()
