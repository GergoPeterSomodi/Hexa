"""Battle slice 1, PR 2: the day rules of systems/combat.py. Not wired into the season yet, so no game plays these.

The day tests put both stacks on one hex of a fresh world and run ``combat.fight_day``. Exact-damage tests use a flat
random stream (every draw is 1.0), so one hit can be compared with another. The fixed-seed bands play the five fights
of the spec's quick model (section 4) for 30 seeds each and assert the bands of section 7.3.
"""
import contextlib
import math
import random
import statistics
import unittest

from hexa.campaign.data import (BATTLE_LOG, BATTLE_MAX_SEASONS, DAYS_PER_SEASON, GARRISON_HP, GENERAL, GENERAL_MORALE,
                                HUNGER_DRAIN, RESERVE_DRAIN)
from hexa.campaign.state import Battle
from hexa.campaign.systems import combat
from tests.support.battles import place
from tests.support.worlds import fresh


class FlatRng:
    """Every draw is 1.0: a hit is exactly its formula."""

    def uniform(self, low, high):
        return 1.0


def site(world):
    """A land hex with an owner (the attacker's country) and another live country (the defender's)."""
    pos = next(p.pos for p in sorted(world.provinces.values(), key=lambda p: p.pos)
               if p.owner is not None and world.is_land(p.pos))
    attacker = world.provinces[pos].owner
    defender = next(t for t in sorted(world.countries) if t != attacker and world.countries[t].alive)
    return pos, attacker, defender


def stage(world, spec_a, spec_d, terrain="plains", castle=0):
    """Both stacks on one hex, the attacker on Attack and the defender on Hold. A spec lists regiments as
    (branch, era, count). Returns (battle, attacker units, defender units). ``castle`` gives the hex a castle of that
    level with a full garrison, held by the defender: an assault."""
    pos, a, d = site(world)
    world.units = [u for u in world.units if not (u.pos == pos and u.kind.war)]
    prov = world.provinces[pos]
    prov.terrain = terrain
    prov.owner = a
    prov.controller = d if castle else a
    prov.castle, prov.garrison = (castle, castle * GARRISON_HP) if castle else (0, 0)
    attackers = [u for branch, era, n in spec_a for u in place(world, branch, era, a, pos, n)]
    defenders = [u for branch, era, n in spec_d for u in place(world, branch, era, d, pos, n)]
    world.changed()
    battle = Battle(pos=pos, attacker=a, defender=d, start=world.turn, assault=bool(castle),
                    stance={a: "attack", d: "hold"})
    return battle, attackers, defenders


def damage(battle, unit):
    """The hp a unit has lost so far, carry included (hp alone is whole points)."""
    return unit.kind.hp - unit.hp + battle.carry.get(unit.id, 0.0)


@contextlib.contextmanager
def pikes(value):
    """Set the pike bonus against horse for the block (defense_value and the shock bonus both read it)."""
    saved = combat.PIKES_VS_HORSE
    combat.PIKES_VS_HORSE = value
    try:
        yield
    finally:
        combat.PIKES_VS_HORSE = saved


def duel(world, attacker_branch, defender_branch):
    """One regiment each in the centre, one day, flat rng. Returns (hp the attacker lost, hp the defender lost)."""
    battle, (att,), (dfn,) = stage(world, [(attacker_branch, 1, 1)], [(defender_branch, 1, 1)])
    world.rng = FlatRng()
    combat.fight_day(world, battle)
    return damage(battle, att), damage(battle, dfn)


class DeployTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")

    def test_centre_first_infantry_centre_cavalry_flanks(self):
        battle, att, _ = stage(self.world, [("cavalry", 1, 2), ("infantry", 1, 1)], [("infantry", 1, 1)])
        combat.deploy(self.world, battle)
        pike = next(u for u in att if u.kind.branch == "infantry")
        knights = {u.id for u in att if u.kind.branch == "cavalry"}
        lanes = battle.lanes[battle.attacker]
        self.assertEqual(lanes[1], pike.id)
        self.assertEqual({lanes[0], lanes[2]}, knights)

    def test_routed_regiment_leaves_and_reserve_fills_its_lane(self):
        battle, att, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 1)])
        combat.deploy(self.world, battle)
        routed = battle.lanes[battle.attacker][0]
        reserve = next(u for u in att if u.id not in battle.lanes[battle.attacker])
        battle.routed.add(routed)
        combat.deploy(self.world, battle)
        self.assertEqual(battle.lanes[battle.attacker][0], reserve.id)
        self.assertNotIn(routed, battle.lanes[battle.attacker])

    def test_narrow_ground_closes_the_right_lane(self):
        battle, att, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 3)], terrain="mountains")
        combat.deploy(self.world, battle)
        for tag in (battle.attacker, battle.defender):
            self.assertIsNone(battle.lanes[tag][2])
        self.assertEqual(sum(1 for u in att if u.id in battle.lanes[battle.attacker]), 2)

    def test_assault_garrison_holds_the_centre_and_field_units_take_the_flanks(self):
        battle, _, dfn = stage(self.world, [("infantry", 1, 1)], [("cavalry", 1, 1), ("infantry", 1, 2)], castle=2)
        combat.deploy(self.world, battle)
        lanes = battle.lanes[battle.defender]
        knight = next(u for u in dfn if u.kind.branch == "cavalry")
        in_lanes = [u for u in dfn if u.id in lanes]
        self.assertEqual(lanes[1], "garrison")
        self.assertIn(knight, in_lanes)
        self.assertEqual(sum(1 for u in in_lanes if u.kind.branch == "infantry"), 1)
        self.assertEqual(sum(1 for u in dfn if u.id not in lanes), 1)

    def test_men0_is_set_once_from_the_men_that_went_in(self):
        battle, att, _ = stage(self.world, [("infantry", 1, 2)], [("infantry", 1, 1)])
        combat.deploy(self.world, battle)
        self.assertEqual(battle.men0[battle.attacker], 2000)
        att[0].hp = 5
        combat.deploy(self.world, battle)
        self.assertEqual(battle.men0[battle.attacker], 2000)


class DayDamageTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")

    def test_pikes_bonus_against_horse_is_a_quarter_both_ways(self):
        # duel returns (hp the attacker lost, hp the defender lost). Infantry attacking horse hits 25% harder (the
        # shock bonus); horse attacking infantry hits 25% softer (pike defence). Both are off with the bonus at 1.0.
        pike_hurt, horse_hurt = duel(self.world, "infantry", "cavalry")
        with pikes(1.0):
            flat_pike_hurt, flat_horse_hurt = duel(self.world, "infantry", "cavalry")
        self.assertAlmostEqual(horse_hurt / flat_horse_hurt, 1.25, places=9)
        self.assertAlmostEqual(flat_pike_hurt / pike_hurt, 1.25, places=9)
        knight_hurt, pike_hurt = duel(self.world, "cavalry", "infantry")
        with pikes(1.0):
            flat_knight_hurt, flat_pike_hurt = duel(self.world, "cavalry", "infantry")
        self.assertAlmostEqual(knight_hurt / flat_knight_hurt, 1.25, places=9)
        self.assertAlmostEqual(flat_pike_hurt / pike_hurt, 1.25, places=9)

    def test_flank_bonus_is_a_quarter_on_the_centre(self):
        # The defender's centre pike takes the centre blow in both runs. In the first run the attacker's knight, with
        # nothing opposite, comes round the empty left of the defender and strikes the centre with FLANK_BONUS.
        world = self.world
        battle, _, dfn = stage(world, [("infantry", 1, 1)], [("infantry", 1, 1)])
        world.rng = FlatRng()
        base = self._centre_damage(world, battle, dfn[0])
        world = fresh("POR")
        battle, _, dfn = stage(world, [("cavalry", 1, 1), ("infantry", 1, 1)], [("infantry", 1, 1)])
        world.rng = FlatRng()
        with_flank = self._centre_damage(world, battle, dfn[0])
        _, plain = duel(fresh("POR"), "cavalry", "infantry")
        self.assertAlmostEqual(with_flank - base, 1.25 * plain, places=9)

    @staticmethod
    def _centre_damage(world, battle, unit):
        combat.fight_day(world, battle)
        return damage(battle, unit)

    def test_fire_from_the_back_line_adds_to_the_centre(self):
        world = self.world
        battle, _, dfn = stage(world, [("infantry", 1, 3), ("artillery", 1, 1)], [("infantry", 1, 1)])
        world.rng = FlatRng()
        combat.fight_day(world, battle)
        with_gun = damage(battle, dfn[0])
        world = fresh("POR")
        battle, _, dfn = stage(world, [("infantry", 1, 3)], [("infantry", 1, 1)])
        world.rng = FlatRng()
        combat.fight_day(world, battle)
        self.assertGreater(with_gun, damage(battle, dfn[0]))

    def test_wounds_are_half_of_the_losses(self):
        battle, _, dfn = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 1)])
        combat.fight_day(self.world, battle)
        for tag in (battle.attacker, battle.defender):
            self.assertAlmostEqual(battle.killed[tag], battle.wounded[tag], places=9)
            self.assertGreater(battle.wounded[tag], 0)
        self.assertAlmostEqual(battle.wounded_hp[dfn[0].id], damage(battle, dfn[0]) / 2, places=9)

    def test_a_dying_regiment_is_killed_and_leaves_its_lane(self):
        battle, _, dfn = stage(self.world, [("cavalry", 1, 1)], [("infantry", 1, 1)])
        dfn[0].hp = 1
        battle.carry[dfn[0].id] = 0.99
        combat.fight_day(self.world, battle)
        self.assertNotIn(dfn[0], self.world.units)
        self.assertIsNone(battle.lanes[battle.defender][1])

    def test_stance_multiplies_the_damage_taken(self):
        damages = []
        for stance in ("hold", "attack"):
            world = fresh("POR")
            battle, _, dfn = stage(world, [("infantry", 1, 1)], [("infantry", 1, 1)])
            battle.stance[battle.defender] = stance
            world.rng = FlatRng()
            combat.fight_day(world, battle)
            damages.append(damage(battle, dfn[0]))
        self.assertAlmostEqual(damages[1] / damages[0], 1.1 / 0.8, places=9)


class DayMoraleTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")

    def reserve_of(self, battle, units):
        combat.deploy(self.world, battle)
        return next(u for u in units if u.id not in battle.lanes[battle.attacker])

    def test_reserve_loses_the_reserve_drain_and_hunger_adds_to_it(self):
        battle, att, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 1)])
        reserve = self.reserve_of(battle, att)
        reserve.supplied = False
        combat.fight_day(self.world, battle)
        self.assertAlmostEqual(reserve.morale, 1 - RESERVE_DRAIN - HUNGER_DRAIN, places=9)

    def test_a_general_on_the_side_cuts_the_morale_loss(self):
        battle, att, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 1)])
        reserve = self.reserve_of(battle, att)
        self.world.add_unit(GENERAL, battle.attacker, battle.pos, moves=0)
        combat.fight_day(self.world, battle)
        self.assertAlmostEqual(reserve.morale, 1 - RESERVE_DRAIN * (1 - GENERAL_MORALE), places=9)

    def test_rank_divides_the_morale_loss(self):
        battle, att, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 1)])
        reserve = self.reserve_of(battle, att)
        reserve.xp = 3
        combat.fight_day(self.world, battle)
        self.assertAlmostEqual(reserve.morale, 1 - RESERVE_DRAIN / reserve.rank[2], places=9)

    def test_a_regiment_at_zero_morale_routs_and_the_reserve_fills_its_lane(self):
        battle, att, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 1)])
        reserve = self.reserve_of(battle, att)
        routing = next(u for u in att if u.id == battle.lanes[battle.attacker][0])
        routing.morale = 0.02
        combat.fight_day(self.world, battle)
        self.assertIn(routing.id, battle.routed)
        self.assertIsNone(battle.lanes[battle.attacker][0])
        combat.deploy(self.world, battle)
        self.assertEqual(battle.lanes[battle.attacker][0], reserve.id)


class BreakTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")

    def test_an_army_under_a_quarter_breaks_and_a_cavalry_pursuit_takes_ten_percent(self):
        battle, _, dfn = stage(self.world, [("cavalry", 1, 1)], [("infantry", 1, 3)])
        for unit in dfn:
            unit.morale = 0.0
            battle.routed.add(unit.id)
        report = combat.fight_day(self.world, battle)
        self.assertEqual(report["broke"], battle.defender)
        self.assertAlmostEqual(battle.killed[battle.defender], 0.10 * 3000, places=6)
        self.assertEqual(battle.wounded.get(battle.defender, 0.0), 0.0)

    def test_without_cavalry_the_pursuit_is_four_percent(self):
        battle, _, dfn = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 3)])
        for unit in dfn:
            unit.morale = 0.0
            battle.routed.add(unit.id)
        report = combat.fight_day(self.world, battle)
        self.assertEqual(report["broke"], battle.defender)
        self.assertAlmostEqual(battle.killed[battle.defender], 0.04 * 3000, places=6)

    def test_both_armies_under_breaks_the_attacker_on_a_tie(self):
        battle, att, dfn = stage(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        for unit in att + dfn:
            unit.morale = 0.0
            battle.routed.add(unit.id)
        self.assertEqual(combat.fight_day(self.world, battle)["broke"], battle.attacker)

    def test_three_routed_of_four_breaks_the_army(self):
        battle, _, dfn = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 4)])
        for unit in dfn[:3]:
            unit.morale = 0.0
            battle.routed.add(unit.id)
        dfn[3].morale = 0.9
        report = combat.fight_day(self.world, battle)
        self.assertEqual(report["broke"], battle.defender)
        self.assertLess(report["morale"][battle.defender], 0.25)

    def test_the_day_is_counted_and_logged_and_the_log_is_kept_short(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        for _ in range(BATTLE_LOG + 2):
            combat.fight_day(self.world, battle)
        self.assertEqual(battle.days, BATTLE_LOG + 2)
        self.assertEqual(len(battle.log), BATTLE_LOG)
        self.assertEqual(battle.log[-1][1], battle.days)


# ----- fixed-seed scenario bands (spec section 7.3.1) ------------------------------------------------------------

SCENARIOS = {
    "3 pikes v 3 pikes": ([("infantry", 1, 3)], [("infantry", 1, 3)]),
    "6 pikes v 6 pikes": ([("infantry", 1, 6)], [("infantry", 1, 6)]),
    "4 pikes, 2 knights, 1 gun, both sides": ([("infantry", 1, 4), ("cavalry", 1, 2), ("artillery", 1, 1)],
                                              [("infantry", 1, 4), ("cavalry", 1, 2), ("artillery", 1, 1)]),
    "6 pikes v 4 pikes": ([("infantry", 1, 6)], [("infantry", 1, 4)]),
    "8 mixed v 5 pikes": ([("infantry", 1, 4), ("cavalry", 1, 2), ("artillery", 1, 2)], [("infantry", 1, 5)]),
}
SEEDS = range(30)


def play(world, seed, spec_a, spec_d):
    """One scenario fight to its end, or to the safety stop. Returns a dict: days, seasons, winner (tag or None),
    loss (share of its men lost per side, killed and wounded) and the battle."""
    world.rng = random.Random(seed)
    battle, _, _ = stage(world, spec_a, spec_d)
    combat.deploy(world, battle)
    men0 = dict(battle.men0)
    broke, days = None, 0
    for days in range(1, 3 * BATTLE_MAX_SEASONS + 1):
        report = combat.fight_day(world, battle)
        if report["broke"] is not None:
            broke = report["broke"]
            break
    winner = None if broke is None else (battle.defender if broke == battle.attacker else battle.attacker)
    loss = {tag: (battle.killed.get(tag, 0.0) + battle.wounded.get(tag, 0.0)) / men0[tag]
            for tag in (battle.attacker, battle.defender)}
    return {"days": days, "seasons": math.ceil(days / DAYS_PER_SEASON), "winner": winner, "loss": loss,
            "battle": battle}


class ScenarioBandsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        world = fresh("POR")
        cls.results = {name: [play(world, seed, spec_a, spec_d) for seed in SEEDS]
                       for name, (spec_a, spec_d) in SCENARIOS.items()}

    def test_every_scenario_ends_inside_the_safety_stop(self):
        for name, rows in self.results.items():
            for row in rows:
                self.assertLessEqual(row["seasons"], BATTLE_MAX_SEASONS, name)

    def test_even_three_v_three_lasts_one_to_three_seasons_in_most_seeds(self):
        rows = self.results["3 pikes v 3 pikes"]
        inside = sum(1 for row in rows if 1 <= row["seasons"] <= 3)
        self.assertGreaterEqual(inside / len(rows), 0.8)

    def test_one_and_a_half_to_one_is_won_by_the_attacker_in_most_seeds(self):
        rows = self.results["6 pikes v 4 pikes"]
        wins = sum(1 for row in rows if row["winner"] == row["battle"].attacker)
        self.assertGreaterEqual(wins / len(rows), 0.85)

    def test_the_loser_loses_between_fifteen_and_fifty_percent(self):
        shares = []
        for row in self.results["6 pikes v 4 pikes"]:
            battle = row["battle"]
            loser = battle.defender if row["winner"] == battle.attacker else battle.attacker
            shares.append(row["loss"][loser])
        self.assertGreaterEqual(statistics.median(shares), 0.15)
        self.assertLessEqual(statistics.median(shares), 0.50)


if __name__ == "__main__":
    unittest.main()
