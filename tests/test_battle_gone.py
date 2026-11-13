"""Units that leave the map outside a battle's day (starvation, desertion or disbanding, attrition, a sinking) are taken out
of their battle at once (systems/battle.units_left, called by war.lose). A side with no fighting presence left on the hex
ends the battle as "gone" (a draw, no winner, no score), once; its civilians there retreat or are lost. Regression tests for
the soak failures "battle ... lacks one of its sides (GIA v SHE)" (random seed 3) and "has unit #360 in a THA lane, which is
not a living THA unit there" (random seed 1, 160 seasons).
"""
import unittest

from hexa.campaign.data import GENERAL
from hexa.campaign.systems import battle as battlesys, combat, debt
from hexa.campaign.systems.battle import _listed
from hexa.hexgrid import neighbors
from tests.support.battles import setup
from tests.support.invariants import campaign_problems
from tests.support.worlds import fresh
from tests.test_battle import clear_castle, plain_battle


def battle_problems(world):
    return [p for p in campaign_problems(world) if p.startswith("battle")]


def ended(world):
    return world.bus.of("battle_ended")


class StarvedSideTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")

    def test_starving_the_last_regiment_of_a_side_between_seasons_ends_the_battle_gone_once(self):
        fight, battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 1)])
        self.world.bus.history.clear()
        self.world.kill(fight.defenders[0], "starved")
        self.assertEqual(self.world.battles, [])
        events = ended(self.world)
        self.assertEqual(len(events), 1)
        data = events[0].data
        self.assertEqual((data["how"], data["winner"], data["loser"]), ("gone", None, None))
        self.assertEqual(battle_problems(self.world), [])
        battlesys.battle_season(self.world)
        self.assertEqual(len(ended(self.world)), 1)

    def test_a_lane_unit_dying_outside_the_battle_leaves_the_lane_and_the_battle_goes_on(self):
        fight, battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.world.bus.history.clear()
        uid = battle.lanes[fight.defender][combat.CENTRE]
        self.assertIsNotNone(uid)
        victim = next(u for u in fight.defenders if u.id == uid)
        self.world.kill(victim, "starved")
        self.assertIn(battle, self.world.battles)
        self.assertNotIn(uid, _listed(battle))
        self.assertIsNone(battle.lanes[fight.defender][combat.CENTRE])
        self.assertEqual(ended(self.world), [])
        self.assertEqual(battle_problems(self.world), [])
        battlesys.battle_season(self.world)
        self.assertLessEqual(len(ended(self.world)), 1)
        self.assertEqual(battle_problems(self.world), [])

    def test_a_dead_unit_in_a_stack_outside_any_battle_changes_no_battle(self):
        fight, battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.world.bus.history.clear()
        neighbour = next(p for p in neighbors(fight.attack_pos) if self.world.is_land(p) and p != fight.defend_pos)
        loner = self.world.add_unit(fight.attackers[0].kind, fight.attacker, neighbour, moves=0)
        before = (set(battle.members), dict(battle.lanes))
        self.world.kill(loner, "starved")
        self.assertEqual((set(battle.members), dict(battle.lanes)), before)
        self.assertEqual(ended(self.world), [])


class DesertionTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")

    def test_disbanding_a_side_entirely_ends_its_battle_gone(self):
        fight, battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.world.bus.history.clear()
        saved, gone = debt.disband(self.world, fight.defender, need=10 ** 9, why="deserted")
        self.assertEqual(len(gone), 3)
        self.assertEqual(self.world.battles, [])
        events = ended(self.world)
        self.assertEqual(len(events), 1)
        self.assertEqual((events[0].data["how"], events[0].data["winner"]), ("gone", None))
        self.assertEqual(battle_problems(self.world), [])

    def test_disbanding_part_of_a_side_keeps_the_battle_and_prunes_the_lane(self):
        fight, battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.world.bus.history.clear()
        debt.disband(self.world, fight.defender, need=0.1, why="disbanded")
        self.assertIn(battle, self.world.battles)
        self.assertEqual(ended(self.world), [])
        self.assertEqual(battle_problems(self.world), [])
        living = {u.id for u in self.world.units}
        for lanes in battle.lanes.values():
            self.assertTrue(all(uid is None or uid in living for uid in lanes))

    def test_a_disbanded_general_is_not_left_on_the_hex_with_the_enemy(self):
        world = self.world
        fight = setup(world, [("infantry", 1, 3)], [("infantry", 1, 2)])
        clear_castle(world, fight.defend_pos)
        general = world.add_unit(GENERAL, fight.defender, fight.defend_pos, moves=0)
        world.bus.history.clear()
        self.assertTrue(world.engage(fight.attackers, fight.defend_pos))
        for unit in list(fight.defenders):
            world.kill(unit, "starved")
        self.assertEqual(world.battles, [])
        self.assertEqual(len(ended(world)), 1)
        self.assertFalse(any(u.owner == fight.defender and u.pos == fight.defend_pos for u in world.units))
        self.assertEqual(battle_problems(world), [])
        self.assertTrue(general not in world.units or general.pos != fight.defend_pos)


class DestroyedSideTest(unittest.TestCase):
    def test_a_side_destroyed_in_a_day_leaves_its_general_off_the_hex(self):
        world = fresh("POR")
        fight = setup(world, [("infantry", 1, 3)], [("infantry", 1, 2)])
        clear_castle(world, fight.defend_pos)
        general = world.add_unit(GENERAL, fight.defender, fight.defend_pos, moves=0)
        world.bus.history.clear()
        self.assertTrue(world.engage(fight.attackers, fight.defend_pos))
        battle = world.battle_at(fight.defend_pos)
        battlesys.end_battle(world, battle, "destroyed", loser=fight.defender)
        self.assertEqual(world.battles, [])
        self.assertFalse(any(u.owner == fight.defender and u.pos == fight.defend_pos for u in world.units))
        self.assertEqual(len(ended(world)), 1)
        self.assertEqual(battle_problems(world), [])
        self.assertTrue(general not in world.units or general.pos != fight.defend_pos)


class ForageTest(unittest.TestCase):
    """Owner decision: an army in a battle cannot forage, by the player's button or by the AI's logistics (the same check)."""

    def setUp(self):
        self.world = fresh("POR")

    def test_a_stack_on_a_battle_hex_cannot_forage_even_with_moves_or_at_season_end(self):
        fight, battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        stack = fight.attackers
        for end_of_round in (False, True):
            self.assertEqual(self.world.forage_check(stack, tag=fight.attacker, end_of_round=end_of_round),
                             (False, "Can't forage during a battle"))
            self.assertEqual(self.world.forage_check(stack, end_of_round=end_of_round),
                             (False, "Can't forage during a battle"))
        self.assertFalse(self.world.forage(stack, end_of_round=True))
        self.assertNotEqual(self.world.provinces[fight.defend_pos].foraged, (fight.attacker, self.world.turn))

    def test_foraging_is_allowed_again_once_the_battle_is_over(self):
        fight, battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.world.end_battles(fight.attacker, fight.defender)
        for unit in fight.attackers:
            unit.moves_left = 1
        self.assertIsNone(self.world.battle_at(fight.defend_pos))
        self.assertEqual(self.world.forage_check(fight.attackers), (True, ""))


if __name__ == "__main__":
    unittest.main()
