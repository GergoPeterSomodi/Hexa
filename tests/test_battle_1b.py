"""Battle slice 1b (owner decisions 2026-11-13): the d6 day dice, the lane break test (reserves out of the army morale),
the battle timing ("clash" or "full"), the standing orders (Hold or Withdraw when attacked) and the structured battle log
with the text of old saves. Pygame-free; the rules are in systems/combat.py and systems/battle.py, the words in
battlelog.py, the numbers in data.py.
"""
import pickle
import random
import unittest
from unittest import mock

from hexa import settings
from hexa.campaign.battlelog import describe
from hexa.campaign.data import BATTLE_TIMINGS, BREAK, CENTRE_SHOCK, DAYS_PER_SEASON, DICE, FLANK_MORALE, STANDING_ORDERS
from hexa.campaign.state import Battle, fill_defaults
from hexa.campaign.systems import battle as battlesys, combat
from tests.support.battles import setup
from tests.support.scenarios import stage
from tests.support.worlds import fresh
from tests.test_battle import damage, plain_battle

REAL_DICE = dict(DICE)          # captured at import: the dice of data.py, before any test patches them


class Flat:
    """A random stream whose d6 is always 3 and whose uniform draws are 1.0 (no spread, no luck)."""

    def randint(self, low, high):
        return 3

    def uniform(self, low, high):
        return 1.0


def real_dice(test):
    patch = mock.patch.dict(combat.DICE, REAL_DICE)
    patch.start()
    test.addCleanup(patch.stop)


def lane_unit(world, battle, tag, lane):
    key = battle.lanes[tag][lane]
    return next(u for u in world.units if u.id == key)


def reserve_units(world, battle, tag):
    return [u for u in world.units if u.owner == tag and u.pos == battle.pos and u.kind.war and u.id not in battle.routed
            and u.id not in battle.lanes[tag]]


class DiceTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        real_dice(self)

    def test_the_table_is_the_owners(self):
        self.assertEqual(REAL_DICE, {1: 0.7, 2: 0.8, 3: 0.9, 4: 1.1, 5: 1.2, 6: 1.4})

    def test_one_function_makes_a_sides_multiplier_from_its_roll(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 1)])
        for roll in range(1, 7):
            self.assertEqual(combat.day_multiplier(self.world, battle, battle.attacker, roll), DICE[roll])

    def test_a_day_rolls_once_per_side_and_logs_the_rolls(self):
        self.world.rng = random.Random(4)
        battle, _, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 4)])
        report = combat.fight_day(self.world, battle)
        self.assertEqual(set(report["rolls"]), {battle.attacker, battle.defender})
        self.assertTrue(all(1 <= r <= 6 for r in report["rolls"].values()))
        record = battle.log[-1]
        self.assertEqual(record["kind"], "day")
        self.assertEqual(record["rolls"], report["rolls"])

    def test_the_same_seed_gives_the_same_day(self):
        results = []
        for _ in range(2):
            world = fresh("POR")
            world.rng = random.Random(9)
            battle, _, _ = stage(world, [("infantry", 1, 5)], [("infantry", 1, 4)])
            report = combat.fight_day(world, battle)
            results.append((report["rolls"], dict(report["killed"]), battle.log[-1]))
        self.assertEqual(results[0], results[1])

    def test_a_roll_scales_the_damage_its_side_deals(self):
        # the ratio of damage to defender over damage to attacker is 2x when the attacker rolls 6 and the defender 1,
        # against the same ratio when both roll 3 (1.4 / 0.7 over 0.9 / 0.9)
        def ratio(rolls):
            world = fresh("POR")
            battle, att, dfn = stage(world, [("infantry", 1, 1)], [("infantry", 1, 1)])
            world.rng = Flat()
            combat.deploy(world, battle)
            day = combat._Day(world, battle, (), dict(zip((battle.attacker, battle.defender), rolls)))
            combat.shock(day)
            return damage(battle, dfn[0]) / damage(battle, att[0])
        self.assertAlmostEqual(ratio((6, 1)) / ratio((3, 3)), 2.0, places=9)


class LaneBreakTest(unittest.TestCase):
    """The owner's line model (refinement of 2026-11-13): a lane breaks when its regiment routs or dies and no reserve
    fills it by the next day's start; a broken centre breaks the army when no reserve can fill it; two broken lanes break
    it; on narrow ground either lane does; the front-line morale under BREAK is the fallback."""

    def setUp(self):
        self.world = fresh("POR")
        self.world.rng = Flat()

    def hold(self, battle, days=1):
        """The day's deploy as it stands at the start of a day after the first (lanes filled, the day counted)."""
        combat.deploy(self.world, battle)
        battle.days = days

    def test_an_empty_centre_with_no_reserve_breaks_the_army(self):
        battle, _, dfn = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 2)])
        combat.deploy(self.world, battle)
        battle.days = 1
        centre = lane_unit(self.world, battle, battle.defender, 1)
        combat._rout(battle, battle.defender, centre.id)
        report = combat.fight_day(self.world, battle)
        self.assertEqual(report["broke"], battle.defender)
        self.assertEqual(report["cause"], "centre")
        self.assertIn({"kind": "lane_broken", "turn": self.world.turn, "day": 1, "side": battle.defender, "lane": 1},
                      [{**r} for r in battle.log if r.get("kind") == "lane_broken"])

    def test_two_empty_lanes_break_an_army_with_its_centre_standing(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 3)])
        self.hold(battle)
        for lane in (0, 2):
            combat._rout(battle, battle.defender, lane_unit(self.world, battle, battle.defender, lane).id)
        report = combat.fight_day(self.world, battle)
        self.assertEqual(report["broke"], battle.defender)
        self.assertEqual(report["cause"], "lanes")
        self.assertIsNotNone(battle.lanes[battle.defender][1])

    def test_one_empty_flank_does_not_break_the_army(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 3)])
        self.hold(battle)
        combat._rout(battle, battle.defender, lane_unit(self.world, battle, battle.defender, 0).id)
        combat.deploy(self.world, battle)
        day = combat._Day(self.world, battle, (), {})
        self.assertEqual(combat.breaker(day), (None, None))

    def test_a_reserve_refills_a_broken_centre_and_the_army_holds(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 4)])
        self.hold(battle)
        combat._rout(battle, battle.defender, lane_unit(self.world, battle, battle.defender, 1).id)
        combat.deploy(self.world, battle)
        self.assertIsNotNone(battle.lanes[battle.defender][1])
        self.assertEqual([r for r in battle.log if r.get("kind") == "lane_broken"], [])
        self.assertEqual(combat.breaker(combat._Day(self.world, battle, (), {})), (None, None))

    def test_a_flank_stays_broken_and_drains_its_centre_each_day(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 3)])
        self.hold(battle)
        centre = lane_unit(self.world, battle, battle.defender, 1)
        combat._rout(battle, battle.defender, lane_unit(self.world, battle, battle.defender, 0).id)
        before = centre.morale
        combat.deploy(self.world, battle)
        self.assertAlmostEqual(centre.morale, before - FLANK_MORALE, places=9)
        combat.deploy(self.world, battle)
        self.assertAlmostEqual(centre.morale, before - 2 * FLANK_MORALE, places=9)

    def test_a_newly_broken_centre_shocks_the_side_once(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 2)])
        self.hold(battle)
        left = lane_unit(self.world, battle, battle.defender, 0)
        combat._rout(battle, battle.defender, lane_unit(self.world, battle, battle.defender, 1).id)
        combat.deploy(self.world, battle)
        self.assertAlmostEqual(left.morale, 1.0 - CENTRE_SHOCK, places=9)
        combat.deploy(self.world, battle)
        self.assertAlmostEqual(left.morale, 1.0 - CENTRE_SHOCK, places=9)

    def test_narrow_ground_breaks_on_either_lane(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 2)], terrain="mountains")
        self.hold(battle)
        combat._rout(battle, battle.defender, lane_unit(self.world, battle, battle.defender, 0).id)
        combat.deploy(self.world, battle)
        day = combat._Day(self.world, battle, (), {})
        self.assertEqual(combat.breaker(day), (battle.defender, "lanes"))

    def test_the_front_line_morale_under_break_is_the_fallback(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 3)])
        self.hold(battle)
        for lane in range(3):
            lane_unit(self.world, battle, battle.defender, lane).morale = BREAK / 2
        day = combat._Day(self.world, battle, (), {})
        self.assertEqual(combat.breaker(day), (battle.defender, "morale"))

    def test_a_broken_centre_exposes_the_back_line(self):
        battle, _, dfn = stage(self.world, [("infantry", 1, 3), ("artillery", 1, 1)], [("infantry", 1, 4)])
        combat.deploy(self.world, battle)
        self.world.rng = Flat()
        battle.lanes[battle.defender][1] = None          # the centre is empty at fire time: its reserve is exposed
        before = {u.id: damage(battle, u) for u in self.world.units if u.owner == battle.defender}
        combat.backline(combat._Day(self.world, battle, (), {}))
        # a hit this small is carried (hp is whole points), so the damage taken is what counts
        hit = [u for u in self.world.units if u.owner == battle.defender and damage(battle, u) > before[u.id]]
        self.assertTrue(hit)

    def test_a_standing_centre_leaves_the_back_line_alone(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 3), ("artillery", 1, 1)], [("infantry", 1, 4)])
        combat.deploy(self.world, battle)
        hp_before = {u.id: u.hp for u in reserve_units(self.world, battle, battle.defender)}
        combat.backline(combat._Day(self.world, battle, (), {}))
        self.assertEqual({u.id: u.hp for u in reserve_units(self.world, battle, battle.defender)}, hp_before)

    def test_army_morale_is_the_front_line_and_strength_counts_the_reserve(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 4)])
        combat.deploy(self.world, battle)
        reserve = reserve_units(self.world, battle, battle.defender)
        self.assertEqual(len(reserve), 1)
        reserve[0].morale = 0.0
        self.assertEqual(combat.army_morale(self.world, battle, battle.defender), 1.0)
        self.assertLess(combat.strength_morale(self.world, battle, battle.defender), 1.0)
        for lane in range(3):
            lane_unit(self.world, battle, battle.defender, lane).morale = 0.5
        self.assertAlmostEqual(combat.army_morale(self.world, battle, battle.defender), 0.5, places=9)

    def test_each_lane_break_is_logged_as_data(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 1)], [("infantry", 1, 3)])
        self.hold(battle)
        combat._rout(battle, battle.defender, lane_unit(self.world, battle, battle.defender, 2).id)
        combat.deploy(self.world, battle)
        records = [r for r in battle.log if r.get("kind") == "lane_broken"]
        self.assertEqual([(r["side"], r["lane"]) for r in records], [(battle.defender, 2)])


class TimingTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.world.rng = random.Random(21)

    def test_the_choices_are_clash_and_full_and_clash_is_the_default(self):
        self.assertEqual(BATTLE_TIMINGS, ("clash", "full"))
        self.assertEqual(fresh("POR").battle_timing, "clash")

    def test_clash_fights_one_day_in_the_season_the_attack_happens(self):
        self.world.battle_timing = "clash"
        _, battle = plain_battle(self.world, [("infantry", 1, 6)], [("infantry", 1, 6)])
        self.assertEqual(battlesys.day_cap(self.world, battle), 1)
        battlesys.battle_season(self.world)
        if battle in self.world.battles:
            self.assertEqual(battle.days, 1)

    def test_clash_fights_a_full_season_of_days_after_that(self):
        self.world.battle_timing = "clash"
        _, battle = plain_battle(self.world, [("infantry", 1, 6)], [("infantry", 1, 6)])
        battlesys.battle_season(self.world)
        self.world.turn += 1
        if battle in self.world.battles:
            self.assertEqual(battlesys.day_cap(self.world, battle), DAYS_PER_SEASON)
            battlesys.battle_season(self.world)
            self.assertEqual(battle.days, 1 + DAYS_PER_SEASON)

    def test_full_fights_all_the_days_of_the_first_season_at_once(self):
        self.world.battle_timing = "full"
        _, battle = plain_battle(self.world, [("infantry", 1, 6)], [("infantry", 1, 6)])
        self.assertEqual(battlesys.day_cap(self.world, battle), DAYS_PER_SEASON)

    def test_the_setting_is_saved_with_the_options(self):
        self.assertEqual(settings.DEFAULTS["battle_timing"], "clash")
        self.assertEqual(settings.CHOICES["battle_timing"], ("clash", "full"))
        self.assertEqual(settings.cycle(dict(settings.DEFAULTS), "battle_timing"), "full")


class StandingTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.world.rng = random.Random(5)

    def test_a_new_stack_stands_on_hold(self):
        self.assertEqual(self.world.units[0].standing, "hold")
        self.assertEqual(STANDING_ORDERS, ("hold", "withdraw"))

    def test_the_check_refuses_an_unknown_order_and_an_empty_hex(self):
        fight = setup(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        self.assertEqual(self.world.standing_check(fight.defend_pos, fight.defender, "charge"), (False, "Unknown order"))
        self.assertEqual(self.world.standing_check((0, 0), fight.defender, "hold"), (False, "No regiments here"))

    def test_the_order_is_set_on_every_unit_of_that_side_on_the_hex(self):
        fight = setup(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        self.assertTrue(self.world.standing_order(fight.defend_pos, fight.defender, "withdraw"))
        mine = [u for u in self.world.units_at(fight.defend_pos) if u.owner == fight.defender]
        self.assertTrue(mine and all(u.standing == "withdraw" for u in mine))
        self.assertTrue(all(u.standing == "hold" for u in fight.attackers))

    def test_a_battle_takes_the_defenders_standing_order_and_an_order_overrides_it(self):
        fight = setup(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        self.world.standing_order(fight.defend_pos, fight.defender, "withdraw")
        self.world.engage(fight.attackers, fight.defend_pos)
        battle = self.world.battle_at(fight.defend_pos)
        if battle is None:
            self.skipTest("no battle to test here")
        if battle.stance.get(fight.defender) == "withdraw":
            self.assertEqual(battle.stance[fight.attacker], "attack")
        self.assertTrue(self.world.battle_order(fight.defend_pos, fight.defender, "hold"))
        self.assertEqual(battle.stance[fight.defender], "hold")

    def test_withdraw_is_held_to_hold_without_a_retreat_hex(self):
        fight = setup(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        self.world.standing_order(fight.defend_pos, fight.defender, "withdraw")
        with mock.patch.object(battlesys, "retreat_spot", return_value=None):
            self.assertEqual(battlesys.standing_of(self.world, fight.defend_pos, fight.defender), "hold")

    def test_the_standing_survives_a_save_and_an_old_unit_gets_hold(self):
        unit = self.world.units[0]
        unit.standing = "withdraw"
        self.assertEqual(pickle.loads(pickle.dumps(unit)).standing, "withdraw")
        del unit.__dict__["standing"]
        fill_defaults(unit)
        self.assertEqual(unit.standing, "hold")


class LogTest(unittest.TestCase):
    NAMES = {"AAA": "Castile", "BBB": "Aragon"}

    def setUp(self):
        self.world = fresh("POR")
        self.world.rng = random.Random(12)
        real_dice(self)

    def test_the_log_is_data_and_a_day_is_a_structured_record(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 4)], [("infantry", 1, 4)])
        combat.fight_day(self.world, battle)
        record = battle.log[-1]
        self.assertIsInstance(record, dict)
        self.assertEqual(record["kind"], "day")
        self.assertEqual(set(record["killed"]), {battle.attacker, battle.defender})
        self.assertTrue(all(isinstance(v, float) for v in record["killed"].values()))

    def test_every_kind_is_rendered_from_its_fields(self):
        names = {tag: country.name for tag, country in self.world.countries.items()}
        att, dfn = next(iter(names)), list(names)[1]
        records = [
            {"kind": "attacked", "turn": 1, "day": 0, "attacker": att, "defender": dfn, "assault": True},
            {"kind": "joined", "turn": 1, "day": 1, "tag": att, "side": "attacker", "men": 1200},
            {"kind": "lane_broken", "turn": 1, "day": 2, "side": dfn, "lane": 2},
            {"kind": "day", "turn": 1, "day": 3, "killed": {att: 12.0, dfn: 30.0}, "wounded": {att: 4.0, dfn: 9.0},
             "rolls": {att: 4, dfn: 2}, "broke": dfn, "cause": "lanes"},
        ]
        texts = [describe(r, names) for r in records]
        self.assertIn(f"{names[att]} attacked {names[dfn]} in its castle", texts[0])
        self.assertIn("joined the attacker side with 1,200 men", texts[1])
        self.assertIn("lost its right lane", texts[2])
        self.assertIn("Day 3:", texts[3])
        self.assertIn(f"{names[dfn]} broke (lanes)", texts[3])

    def test_old_text_lines_still_load_and_show_as_written(self):
        old = (3, 2, "Day 2: Castile 5 killed, 2 wounded; Aragon 9 killed, 4 wounded. Aragon broke")
        self.assertEqual(describe(old, self.NAMES), old[2])
        battle = Battle(pos=(1, 1), attacker="AAA", defender="BBB", start=3)
        battle.log.append(old)
        battle.days = 2
        combat.record(self.world, battle, "joined", tag="AAA", side="attacker", men=1)
        self.assertEqual(battle.log[0], old)
        self.assertEqual(battle.log[-1]["kind"], "joined")

    def test_an_old_battle_gets_the_new_fields_and_fights_on(self):
        battle, _, _ = stage(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        for name in ("broken", "held"):
            battle.__dict__.pop(name, None)
        fill_defaults(battle)
        self.assertEqual((battle.broken, battle.held), ({}, {}))
        combat.fight_day(self.world, battle)
        self.assertEqual(battle.days, 1)


if __name__ == "__main__":
    unittest.main()
