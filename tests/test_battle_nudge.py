"""The battle nudges (battle slice 1, PR 7b and the v0.2.0 items): the end-of-turn reminder line for each battle the
player is in that is still on (campaign/reminders.py battles_on, its action opens the battle panel), and the "Battle on"
ribbon at the start of a season for the player's battles only (feed.py _season_ended). Pygame-free.
Run with: python -m unittest tests.test_battle_nudge"""
import unittest

from hexa.campaign import feed, reminders as R
from hexa.campaign.battleview import battle_view
from tests.support.worlds import fresh
from tests.test_battle import plain_battle


def battle_lines(found):
    return [r for r in found if r.kind == "battle"]


class BattleReminderTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.fight, self.battle = plain_battle(self.world)

    def test_the_player_in_a_battle_that_is_on_gets_one_line_with_the_panel_action(self):
        self.world.player = self.fight.attacker
        lines = battle_lines(R.unfinished(self.world, self.fight.attacker))
        self.assertEqual(len(lines), 1)
        name = battle_view(self.world, self.battle, self.fight.attacker)["name"]
        self.assertEqual(lines[0].text, f"{name} is still on: join, withdraw or fight on")
        self.assertEqual(lines[0].action, ("battle", self.battle.pos))
        self.assertEqual(lines[0].hint, "Open the battle")

    def test_the_defender_gets_the_line_too(self):
        lines = battle_lines(R.unfinished(self.world, self.fight.defender))
        self.assertEqual(len(lines), 1)

    def test_a_battle_the_player_only_watches_gets_no_line(self):
        other = next(t for t in self.world.countries if t not in (self.fight.attacker, self.fight.defender)
                     and self.world.countries[t].alive)
        self.assertEqual(battle_lines(R.unfinished(self.world, other)), [])

    def test_a_battle_that_has_ended_gets_no_line(self):
        self.world.battles.remove(self.battle)
        self.assertEqual(battle_lines(R.unfinished(self.world, self.fight.attacker)), [])

    def test_two_battles_of_the_player_give_two_lines_first_in_the_list(self):
        fight2, battle2 = plain_battle(self.world, [("infantry", 1, 2)], [("infantry", 1, 2)])
        lines = R.unfinished(self.world, fight2.attacker)
        self.assertEqual(lines[0].kind, "battle")
        self.assertEqual(len(battle_lines(lines)), len([b for b in self.world.battles
                                                       if fight2.attacker in (b.attacker, b.defender)]))

    def test_asking_changes_nothing(self):
        before = len(self.world.battles), self.battle.pos, self.battle.men0.copy()
        R.unfinished(self.world, self.fight.attacker)
        self.assertEqual((len(self.world.battles), self.battle.pos, self.battle.men0), before)


class SeasonRibbonTest(unittest.TestCase):
    def setUp(self):
        self.world = fresh("POR")
        self.fight, self.battle = plain_battle(self.world)
        self.world.player = self.fight.attacker
        self.feed = feed.of(self.world)
        self.feed.take_floating()

    def season_starts(self):
        self.world.bus.emit("season_ended", self.world.player, turn=self.world.turn)
        return self.feed.take_floating()

    def test_a_ribbon_on_the_battle_hex_at_the_season_start(self):
        ribbons = [item for item in self.season_starts() if item.kind == "battle_on"]
        self.assertEqual(len(ribbons), 1)
        self.assertEqual(ribbons[0].pos, self.battle.pos)
        self.assertEqual(ribbons[0].text, "Battle on")
        self.assertTrue(ribbons[0].floating)
        self.assertFalse(ribbons[0].log, "a ribbon, not a log line")

    def test_no_ribbon_for_a_battle_the_player_is_not_in(self):
        self.world.player = next(t for t in self.world.countries if t not in (self.fight.attacker, self.fight.defender)
                                 and self.world.countries[t].alive)
        self.assertEqual([i for i in self.season_starts() if i.kind == "battle_on"], [])

    def test_no_ribbon_once_the_battle_is_over(self):
        self.world.battles.remove(self.battle)
        self.assertEqual([i for i in self.season_starts() if i.kind == "battle_on"], [])

    def test_no_player_no_ribbon(self):
        self.world.player = None
        self.assertEqual([i for i in self.season_starts() if i.kind == "battle_on"], [])
