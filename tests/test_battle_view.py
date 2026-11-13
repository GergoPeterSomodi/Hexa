"""The battle read model (hexa/campaign/battleview.py, PR 6a): the view matches the battle after days are fought, the cache
is invalidated by world.changed() (battle orders included), the fog rules, sides as lists of tags, old text-log entries,
and the odds card's inputs and ratio. Pygame-free."""
import re
import unittest

from hexa.campaign.battlelog import describe
from hexa.campaign.battleview import battle_view, odds_view
from hexa.campaign.data import GARRISON_MEN, START_YEAR
from hexa.campaign.systems import combat
from tests.support.battles import setup
from tests.support.worlds import fresh
from tests.test_battle import clear_castle, plain_battle


def third_country(world, *tags):
    """A living country that is none of ``tags``."""
    return next(t for t in world.countries if t not in tags and world.countries[t].alive)


def fight_days(world, battle, days=2):
    """Fight ``days`` days by hand (combat.fight_day, as the battles phase does) and tell the world, so the battle is
    still on its hex: a battle the season ends is no longer in world.battles, and has no view."""
    for _ in range(days):
        combat.fight_day(world, battle)
    world.changed()


class ViewMatchesBattleTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.fight, self.battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.a, self.d = self.fight.attacker, self.fight.defender
        self.world.player = self.a
        fight_days(self.world, self.battle, 2)
        self.assertIn(self.battle, self.world.battles)
        self.assertEqual(self.battle.days, 2)
        self.view = battle_view(self.world, self.battle, self.a)

    def test_days_and_name_and_year(self):
        self.assertEqual(self.view["days"], self.battle.days)
        self.assertGreater(self.view["days"], 0)
        self.assertEqual(self.view["name"], self.battle.name)
        self.assertEqual(self.view["year"], START_YEAR + (self.battle.start - 1) // 4)
        self.assertEqual(self.view["seasons"], 1)

    def test_numbers_are_the_battles(self):
        for tag in (self.a, self.d):
            side = self.view["side"][tag]
            self.assertEqual(side["start"], int(round(self.battle.men0[tag])))
            self.assertEqual(side["killed"], int(round(self.battle.killed.get(tag, 0.0))))
            self.assertEqual(side["wounded"], int(round(self.battle.wounded.get(tag, 0.0))))
            self.assertEqual(side["strength"], int(round(combat.battle_strength(self.world, self.battle, tag))))
            self.assertAlmostEqual(side["front_morale"], round(combat.army_morale(self.world, self.battle, tag), 3))

    def test_lanes_hold_the_battles_regiments(self):
        for tag in (self.a, self.d):
            lanes = self.view["side"][tag]["lanes"]
            self.assertEqual(len(lanes), 3)
            self.assertEqual([lane["lane"] for lane in lanes], ["left", "centre", "right"])
            for lane, key in enumerate(self.battle.lanes[tag]):
                self.assertEqual(lanes[lane]["id"], key)
                if key is not None:
                    unit = next(u for u in self.world.units if u.id == key)
                    self.assertEqual(lanes[lane]["kind"], unit.kind.name)
                    self.assertEqual(lanes[lane]["morale"], round(unit.morale, 3))

    def test_dice_are_the_last_day(self):
        days = [rec for rec in self.battle.log if isinstance(rec, dict) and rec["kind"] == "day"]
        self.assertTrue(days)
        last = days[-1]
        self.assertEqual(self.view["dice"]["day"], last["day"])
        self.assertEqual(self.view["dice"]["rolls"], last["rolls"])
        for tag, roll in last["rolls"].items():
            self.assertAlmostEqual(self.view["dice"]["mult"][tag], {1: 0.7, 2: 0.8, 3: 0.9, 4: 1.1, 5: 1.2, 6: 1.4}[roll])

    def test_log_is_the_battlelog_text(self):
        names = {tag: self.world.countries[tag].name for tag in (self.a, self.d)}
        self.assertEqual([line["text"] for line in self.view["log"]],
                         [describe(rec, names) for rec in self.battle.log])
        self.assertTrue(any(line["kind"] == "day" for line in self.view["log"]))

    def test_orders_and_stance_for_the_attacker(self):
        side = self.view["side"][self.a]
        self.assertTrue(self.view["can_order"])
        self.assertEqual(self.view["viewer_role"], "attacker")
        self.assertEqual(side["stance"], "attack")
        self.assertEqual(set(side["orders"]), {"attack", "hold", "withdraw"})
        self.assertTrue(side["orders"]["attack"]["ok"])
        self.assertIsNone(self.view["side"][self.d]["orders"])

    def test_position_and_battle_give_the_same_view(self):
        by_pos = battle_view(self.world, self.battle.pos, self.a)
        self.assertIs(by_pos, self.view)
        self.assertIsNone(battle_view(self.world, (-99, -99), self.a))
        self.assertIsNone(battle_view(self.world, (-99, -99), None))


class CacheTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.fight, self.battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.a, self.d = self.fight.attacker, self.fight.defender
        self.world.player = self.a

    def test_the_same_view_is_reused_until_the_world_changes(self):
        first = battle_view(self.world, self.battle, self.a)
        self.assertIs(battle_view(self.world, self.battle, self.a), first)
        self.battle.days = 99                       # changed without changed(): the cache has not been told
        self.assertIs(battle_view(self.world, self.battle, self.a), first)
        self.world.changed()
        second = battle_view(self.world, self.battle, self.a)
        self.assertIsNot(second, first)
        self.assertEqual(second["days"], 99)
        self.assertEqual(first["days"], 0)           # an old view is a snapshot, never changed in place

    def test_a_battle_order_invalidates_the_view(self):
        before = battle_view(self.world, self.battle, self.a)
        self.assertEqual(before["side"][self.a]["stance"], "attack")
        self.assertTrue(self.world.battle_order(self.battle.pos, self.a, "hold"))
        after = battle_view(self.world, self.battle, self.a)
        self.assertIsNot(after, before)
        self.assertEqual(after["side"][self.a]["stance"], "hold")
        self.assertEqual(before["side"][self.a]["stance"], "attack")

    def test_a_fought_day_invalidates_the_view(self):
        before = battle_view(self.world, self.battle, self.a)
        combat.fight_day(self.world, self.battle)
        self.world.changed()
        after = battle_view(self.world, self.battle, self.a)
        self.assertIsNot(after, before)
        self.assertEqual(after["days"], 1)

    def test_an_ended_battle_has_no_view(self):
        self.assertIsNotNone(battle_view(self.world, self.battle, self.a))
        self.world.battles.remove(self.battle)
        self.world.changed()
        self.assertIsNone(battle_view(self.world, self.battle, self.a))
        self.assertIsNone(battle_view(self.world, self.battle.pos, self.a))

    def test_the_viewer_and_the_turn_are_part_of_the_key(self):
        as_attacker = battle_view(self.world, self.battle, self.a)
        as_whole = battle_view(self.world, self.battle, None)
        self.assertIsNot(as_whole, as_attacker)
        self.assertEqual(as_whole["access"], "exact")
        self.assertEqual(as_whole["viewer_role"], None)
        self.assertFalse(as_whole["can_order"])

    def test_the_odds_view_is_cached_too(self):
        group = self.fight.attackers
        first = odds_view(self.world, group, self.fight.defend_pos, self.a)
        self.assertIs(odds_view(self.world, group, self.fight.defend_pos, self.a), first)
        self.world.changed()
        self.assertIsNot(odds_view(self.world, group, self.fight.defend_pos, self.a), first)


class FogTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.fight, self.battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.a, self.d = self.fight.attacker, self.fight.defender
        self.c = third_country(self.world, self.a, self.d)
        self.world.player = self.a
        self.world.visible = set(self.world.terrain)
        fight_days(self.world, self.battle, 2)

    def test_a_side_sees_its_exact_numbers(self):
        for viewer in (self.a, self.d):
            view = battle_view(self.world, self.battle, viewer)
            self.assertEqual(view["access"], "exact")
            self.assertEqual(view["side"][self.d]["access"], "exact")
            self.assertEqual(view["side"][self.d]["strength"],
                             int(round(combat.battle_strength(self.world, self.battle, self.d))))

    def test_the_defender_is_not_the_player_so_it_gives_no_orders(self):
        self.world.player = self.a
        view = battle_view(self.world, self.battle, self.d)
        self.assertFalse(view["can_order"])
        self.assertIsNone(view["side"][self.d]["orders"])
        self.assertIsNotNone(view["side"][self.d]["stance"])

    def test_the_player_who_is_no_side_sees_a_seen_battle_rounded(self):
        self.world.player = self.c                  # fog is the player's vision: the player is the viewer
        view = battle_view(self.world, self.battle, self.c)
        self.assertEqual(view["access"], "seen")
        self.assertFalse(view["exact"])
        for tag in (self.a, self.d):
            side = view["side"][tag]
            self.assertEqual(side["access"], "seen")
            for number in (side["men"], side["start"], side["killed"], side["wounded"], side["strength"]):
                self.assertEqual(number % 100, 0)
            self.assertAlmostEqual(side["front_morale"] / 0.05, round(side["front_morale"] / 0.05))
            self.assertIsNone(side["stance"])
            self.assertIsNone(side["standing"])
            self.assertIsNone(side["orders"])
        self.assertIsNotNone(view["dice"])                   # the dice are public while the hex is seen
        self.assertFalse(view["can_order"])

    def test_the_seen_log_has_no_exact_numbers_from_the_day_records(self):
        self.world.player = self.c
        view = battle_view(self.world, self.battle, self.c)
        day_lines = [line for line in view["log"] if line["kind"] == "day"]
        self.assertTrue(day_lines)
        for line in day_lines:
            numbers = re.findall(r"(\d+) (?:killed|wounded)", line["text"])
            self.assertEqual(len(numbers), 4, line["text"])
            for number in numbers:
                self.assertEqual(int(number) % 100, 0, line["text"])

    def test_a_hidden_battle_shows_nothing_of_its_stacks(self):
        self.world.player = self.c
        self.world.visible = set()
        view = battle_view(self.world, self.battle, self.c)
        self.assertEqual(view["access"], "hidden")
        self.assertIsNone(view["pos"])
        self.assertIsNone(view["name"])
        self.assertEqual(view["sides"], {"attacker": [], "defender": []})
        self.assertEqual(view["side"], {})
        self.assertEqual(view["log"], ())
        self.assertIsNone(view["dice"])
        self.assertFalse(view["can_order"])
        self.assertEqual(set(view), set(battle_view(self.world, self.battle, self.a)))

    def test_with_no_player_everything_is_seen(self):
        self.world.player = None
        self.assertEqual(battle_view(self.world, self.battle, self.c)["access"], "seen")

    def test_the_whole_picture_is_exact_for_tools(self):
        self.world.visible = set()
        view = battle_view(self.world, self.battle, None)
        self.assertEqual(view["access"], "exact")
        self.assertEqual(view["side"][self.d]["access"], "exact")

    def test_old_text_lines_are_shown_only_to_the_exact_view(self):
        self.battle.log.append((1, 1, "Castile lost 300 men"))
        self.world.changed()
        exact = battle_view(self.world, self.battle, self.a)
        self.assertIn("Castile lost 300 men", [line["text"] for line in exact["log"]])
        self.assertEqual(next(l for l in exact["log"] if l["text"] == "Castile lost 300 men")["kind"], "text")
        self.world.player = self.c
        seen = battle_view(self.world, self.battle, self.c)
        self.assertEqual(seen["access"], "seen")
        self.assertNotIn("Castile lost 300 men", [line["text"] for line in seen["log"]])


class OldLogTest(unittest.TestCase):
    def test_a_save_with_text_lines_only_reads_as_written(self):
        world = fresh("POR")
        fight, battle = plain_battle(world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        world.player = fight.attacker
        battle.log[:] = [(3, 2, "Battle of X: Castile beat Portugal."), (3, 2, "Day 2: Castile 40 killed, 0 wounded")]
        world.changed()
        view = battle_view(world, battle, fight.attacker)
        self.assertEqual([(l["turn"], l["day"], l["kind"], l["text"]) for l in view["log"]],
                         [(3, 2, "text", "Battle of X: Castile beat Portugal."),
                          (3, 2, "text", "Day 2: Castile 40 killed, 0 wounded")])
        self.assertIsNone(view["dice"])


class SidesTest(unittest.TestCase):
    def test_sides_are_lists_of_tags_and_each_tag_has_a_side(self):
        world = fresh("POR")
        fight, battle = plain_battle(world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        world.player = fight.attacker
        view = battle_view(world, battle, fight.attacker)
        self.assertEqual(view["sides"], {"attacker": [fight.attacker], "defender": [fight.defender]})
        for role in ("attacker", "defender"):
            self.assertIsInstance(view["sides"][role], list)
            for tag in view["sides"][role]:
                self.assertIn(tag, view["side"])
        self.assertIsInstance(view["log"], tuple)
        self.assertIsInstance(view["side"][fight.attacker]["lanes"], tuple)


class OddsTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.fight = setup(self.world, [("infantry", 1, 3)], [("infantry", 1, 2)])
        clear_castle(self.world, self.fight.defend_pos)
        self.a, self.d = self.fight.attacker, self.fight.defender
        self.world.player = self.a
        self.world.visible = set(self.world.terrain)

    def test_before_the_battle_the_inputs_and_the_ratio(self):
        view = odds_view(self.world, self.fight.attackers, self.fight.defend_pos, self.a)
        self.assertTrue(view["ok"], view["reason"])
        self.assertFalse(view["battle"])
        self.assertEqual(view["attacker"], self.a)
        self.assertEqual(view["defender"], self.d)
        self.assertEqual(view["attack"]["men"], 3000)
        self.assertEqual(view["attack"]["strength"], 3000)
        self.assertEqual(view["attack"]["morale"], 1.0)
        self.assertEqual(view["defence"]["access"], "seen")
        self.assertEqual(view["defence"]["men"], 2000)
        self.assertEqual(view["ratio"], 1.5)

    def test_an_enemy_hidden_under_fog_gives_no_ratio(self):
        self.world.visible = set()
        view = odds_view(self.world, self.fight.attackers, self.fight.defend_pos, self.a)
        self.assertEqual(view["attack"]["access"], "exact")
        self.assertEqual(view["defence"]["access"], "hidden")
        self.assertIsNone(view["defence"]["strength"])
        self.assertIsNone(view["ratio"])

    def test_the_whole_picture_gives_the_enemy_exact(self):
        view = odds_view(self.world, self.fight.attackers, self.fight.defend_pos, None)
        self.assertEqual(view["defence"]["access"], "exact")
        self.assertEqual(view["ratio"], 1.5)

    def test_during_a_battle_the_defence_is_the_battles_strength(self):
        plain = fresh("POR")
        fight, battle = plain_battle(plain, [("infantry", 1, 3)], [("infantry", 1, 2)])
        plain.player = fight.attacker
        view = odds_view(plain, [u for u in fight.attackers if u in plain.units], fight.defend_pos, None)
        self.assertTrue(view["battle"])
        self.assertEqual(view["defence"]["strength"],
                         int(round(combat.battle_strength(plain, battle, fight.defender))))

    def test_an_empty_group_is_refused_with_no_numbers(self):
        view = odds_view(self.world, [], self.fight.defend_pos, self.a)
        self.assertFalse(view["ok"])
        self.assertIsNone(view["attacker"])
        self.assertIsNone(view["ratio"])
        self.assertEqual(view["attack"]["access"], "hidden")

    def test_a_garrison_counts_in_an_assault(self):
        world = fresh("POR")
        fight = setup(world, [("infantry", 1, 3)], [], castle=1)
        world.player = fight.attacker
        world.visible = set(world.terrain)
        view = odds_view(world, fight.attackers, fight.defend_pos, None)
        self.assertTrue(view["defence"]["assault"])
        self.assertEqual(view["defence"]["men"], GARRISON_MEN * world.provinces[fight.defend_pos].garrison)


class ShakenTest(unittest.TestCase):
    """The lanes' shaken flag comes from the last day's record (combat writes the ids that moved up into a lane that day)."""

    def setUp(self):
        self.world = fresh("POR")
        self.fight, self.battle = plain_battle(self.world, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.a = self.fight.attacker
        self.world.player = self.a
        fight_days(self.world, self.battle, 2)

    def last_day(self):
        return [rec for rec in self.battle.log if isinstance(rec, dict) and rec["kind"] == "day"][-1]

    def test_the_day_record_holds_the_shaken_ids_as_a_list(self):
        self.assertEqual(self.last_day()["shaken"], sorted(self.last_day()["shaken"]))
        self.assertTrue(all(isinstance(i, int) for i in self.last_day()["shaken"]))

    def test_a_regiment_that_moved_up_on_the_last_day_is_shaken_in_the_view(self):
        held = self.battle.lanes[self.a][1]
        self.assertIsNotNone(held)
        self.last_day()["shaken"] = [held]
        self.world.changed()
        lanes = battle_view(self.world, self.battle, self.a)["side"][self.a]["lanes"]
        for index, lane in enumerate(lanes):
            if lane["id"] is None:
                self.assertIsNone(lane["shaken"], lane["lane"])
            else:
                self.assertIs(lane["shaken"], index == 1, lane["lane"])

    def test_an_old_day_without_the_list_has_nobody_shaken(self):
        self.last_day().pop("shaken", None)
        self.world.changed()
        for lane in battle_view(self.world, self.battle, self.a)["side"][self.a]["lanes"]:
            self.assertIsNot(lane["shaken"], True)


class GroupStrengthTest(unittest.TestCase):
    """combat.group_strength: men and strength of a group before any battle (the odds card's numbers)."""

    def test_men_and_strength_of_the_war_units_only(self):
        world = fresh("POR")
        fight = setup(world, [("infantry", 1, 3), ("infantry", 1, 2)], [], castle=0)
        units = list(fight.attackers)
        units[0].morale = 0.5
        men, strength = combat.group_strength(world, units)
        self.assertEqual(men, float(sum(u.men for u in units)))
        self.assertEqual(strength, float(sum(u.morale * u.men for u in units)))
        self.assertEqual(combat.group_strength(world, []), (0.0, 0.0))

    def test_a_garrison_adds_its_men_at_full_morale(self):
        world = fresh("POR")
        fight = setup(world, [("infantry", 1, 3)], [], castle=1)
        prov = world.provinces[fight.defend_pos]
        prov.garrison = 2
        men, strength = combat.group_strength(world, [], fight.defend_pos)
        self.assertEqual((men, strength), (GARRISON_MEN * 2.0, GARRISON_MEN * 2.0))
        self.assertEqual(combat.group_strength(world, []), (0.0, 0.0))


class BattleMarkTest(unittest.TestCase):
    """render/battlemark.py: the two stacks of a battle hex stand either side of the centre."""

    def test_off_a_battle_nothing_moves(self):
        from hexa.campaign.render import battlemark
        self.assertEqual(battlemark.slot(None, (1, 2), "POR"), ((1, 2), None))
        self.assertEqual(battlemark.shift(13, None), 0)

    def test_the_attacker_left_the_defender_right_by_half_the_radius(self):
        from hexa.campaign.render import battlemark
        battle = type("B", (), {"pos": (1, 2), "attacker": "POR", "defender": "CAS"})()
        self.assertEqual(battlemark.slot(battle, (1, 2), "POR"), ((1, 2), "attacker"))
        self.assertEqual(battlemark.slot(battle, (1, 2), "CAS"), ((1, 2), "defender"))
        self.assertEqual(battlemark.slot(battle, (1, 2), "FRA"), ((1, 2), None))
        self.assertAlmostEqual(battlemark.shift(12, "attacker"), -6.0)
        self.assertAlmostEqual(battlemark.shift(12, "defender"), 6.0)


if __name__ == "__main__":
    unittest.main()
