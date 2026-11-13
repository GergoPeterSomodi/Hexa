"""The end-of-turn reminder rules (campaign/reminders.py): what counts as unfinished, and what stops counting. They read
the world and change nothing. Pygame-free; the screen that lists them is tested in tests/ui/test_reminder_screen.py.
Run with: python -m unittest tests.test_reminders"""
import dataclasses
import unittest

from hexa.campaign import reminders as R
from hexa.campaign.data import RESEARCH_FUND
from tests.support.digests import quick_digest
from tests.support.worlds import fresh


def kinds(found):
    return [r.kind for r in found]


class RuleCase(unittest.TestCase):
    def setUp(self):
        self.w = fresh("POR")
        self.c = self.w.countries["POR"]

    def outside_castle(self):
        """An own province without a castle, to stand an army in (the starting armies sit in castles)."""
        return next(p for p in sorted(self.w.provinces_of("POR"), key=lambda p: p.pos)
                    if not p.castle and not self.w.units_at(p.pos))

    def army(self):
        unit = next(u for u in self.w.units_of("POR") if u.kind.war and not u.naval)
        unit.pos = self.outside_castle().pos
        return unit


class StartTest(RuleCase):
    def test_a_new_game_has_unfinished_things_in_the_order_of_the_rules(self):
        found = R.unfinished(self.w, "POR")
        self.assertEqual(kinds(found), ["fund", "merchant", "build"])
        self.assertEqual([r.kind for r in found], [r.kind for r in found if r], "no empty lines")
        for line in found:
            self.assertTrue(line.text and line.hint and line.action, line)

    def test_no_country_no_game_over_no_reminders(self):
        self.assertEqual(R.unfinished(self.w, None), [])
        self.assertEqual(R.unfinished(self.w, "XXX"), [])
        self.w.over = True
        self.assertEqual(R.unfinished(self.w, "POR"), [])

    def test_asking_changes_nothing(self):
        before = quick_digest(self.w)
        self.army()
        mid = quick_digest(self.w)
        R.unfinished(self.w, "POR")
        self.assertEqual(quick_digest(self.w), mid)
        self.assertNotEqual(before, mid, "(the test's own move did change it)")


class ResearchTest(RuleCase):
    def test_no_research_chosen(self):
        self.assertIsNone(R.research_missing(self.w, "POR"))
        self.c.researching = ""
        line = R.research_missing(self.w, "POR")
        self.assertEqual((line.kind, line.action), ("research", ("tech",)))

    def test_nothing_to_choose_is_not_a_reminder(self):
        self.c.researching = ""
        self.c.techs |= set(R.tech.TECHS)
        self.assertIsNone(R.research_missing(self.w, "POR"))

    def test_the_fund_is_offered_while_the_tech_has_no_points_and_funding_is_possible(self):
        line = R.research_unfunded(self.w, "POR")
        self.assertEqual((line.kind, line.action), ("fund", ("tech",)))
        self.assertIn(str(RESEARCH_FUND[0]), line.text)
        self.c.research = 3.0
        self.assertIsNone(R.research_unfunded(self.w, "POR"), "it has points")
        self.c.research = 0.0
        self.c.treasury = RESEARCH_FUND[0] - 1
        self.assertIsNone(R.research_unfunded(self.w, "POR"), "cannot pay")
        self.c.treasury = 500
        self.assertTrue(self.w.fund_research("POR"))
        self.c.research = 0.0
        self.assertIsNone(R.research_unfunded(self.w, "POR"), "funded this year already")
        self.c.memory.pop("funded_turn")
        self.c.researching = ""
        self.assertIsNone(R.research_unfunded(self.w, "POR"), "nothing to fund")


class IdeaTest(RuleCase):
    def test_a_pending_idea_card(self):
        self.assertIsNone(R.idea_pending(self.w, "POR"))
        self.c.pending_ideas = ["anything"]
        line = R.idea_pending(self.w, "POR")
        self.assertEqual((line.kind, line.action), ("idea", ("tech",)))
        self.assertEqual(kinds(R.unfinished(self.w, "POR"))[0], "idea", "the most pressing line is first")


class MerchantTest(RuleCase):
    def test_merchants_without_orders(self):
        line = R.idle_merchants(self.w, "POR")
        self.assertEqual(line.kind, "merchant")
        self.assertIn(str(self.w.merchants("POR")), line.text)
        self.assertEqual(line.action[0], "market")
        self.assertIn(line.action[1], self.w.merchant_markets("POR"), "the market is one of the player's")

    def test_one_merchant_is_singular(self):
        self.c.orders = [("r", "grain", "x")] * (self.w.merchants("POR") - 1)
        self.assertIn("1 merchant has", R.idle_merchants(self.w, "POR").text)

    def test_all_merchants_busy(self):
        self.c.orders = [("r", "grain", "x")] * self.w.merchants("POR")
        self.assertIsNone(R.idle_merchants(self.w, "POR"))

    def test_no_route_with_anything_to_carry_is_nothing_to_remind(self):
        self.w.merchant_options = lambda tag, route: []
        self.assertIsNone(R.idle_merchants(self.w, "POR"))


class BuildTest(RuleCase):
    def test_nothing_is_being_built_and_the_treasury_pays(self):
        line = R.nothing_built(self.w, "POR")
        self.assertEqual((line.kind, line.action[0]), ("build", "province"))
        self.assertTrue(any(self.w.build_check("POR", line.action[1], key)[0] for key in (*R.BUILDINGS, "settlement", "castle")),
                        "the province it names can really start something")

    def test_something_under_construction_is_enough(self):
        self.w.provinces_of("POR")[0].queue.append(["weaver", 2])
        self.assertIsNone(R.nothing_built(self.w, "POR"))

    def test_a_poor_treasury_is_not_a_reminder(self):
        self.c.treasury = R.CHEAPEST - 1
        self.assertIsNone(R.nothing_built(self.w, "POR"))
        self.c.treasury = 0
        self.assertIsNone(R.nothing_built(self.w, "POR"))

    def test_the_line_shows_only_what_build_check_allows(self):
        self.w.build_check = lambda tag, prov, key: (False, "no")
        self.assertIsNone(R.nothing_built(self.w, "POR"))


class ArmyTest(RuleCase):
    def test_an_army_that_did_nothing_is_idle(self):
        unit = self.army()
        line = R.idle_armies(self.w, "POR")
        self.assertEqual((line.kind, line.action), ("army", ("log", "goto", unit.pos)))
        self.assertIn("1 army has", line.text)

    def test_stacks_are_counted_not_units(self):
        first = self.army()
        second = dataclasses.replace(first, id=max(u.id for u in self.w.units) + 1)
        self.w.units.append(second)
        self.assertIn("1 army has", R.idle_armies(self.w, "POR").text, "two units, one stack")
        second.pos = next(p.pos for p in sorted(self.w.provinces_of("POR"), key=lambda p: p.pos)
                          if not p.castle and p.pos != first.pos)
        self.assertIn("2 armies have", R.idle_armies(self.w, "POR").text)

    def test_an_army_that_moved_attacked_foraged_or_marches_is_not_idle(self):
        unit = self.army()
        for change in ({"acted": True}, {"attacked": True}, {"foraged_turn": self.w.turn}, {"moves_left": 0},
                       {"goal": (1, 1)}):
            with self.subTest(change):
                old = {k: getattr(unit, k) for k in change}
                for k, v in change.items():
                    setattr(unit, k, v)
                self.assertIsNone(R.idle_armies(self.w, "POR"))
                for k, v in old.items():
                    setattr(unit, k, v)
        self.assertIsNotNone(R.idle_armies(self.w, "POR"))

    def test_a_castle_garrison_is_not_idle(self):
        unit = next(u for u in self.w.units_of("POR") if u.kind.war and not u.naval)
        castle = next(p for p in self.w.provinces_of("POR") if p.castle)
        unit.pos = castle.pos
        self.assertIsNone(R.idle_armies(self.w, "POR"))

    def test_a_besieging_army_is_not_idle(self):
        unit = self.army()
        prov = self.w.provinces[unit.pos]
        prov.controller = "CAS"                        # held by another country: the army is sieging it
        self.w.at_war = lambda a, b: True
        self.assertIsNone(R.idle_armies(self.w, "POR"))

    def test_ships_and_cargo_are_not_armies(self):
        unit = self.army()
        ship = next(u for u in self.w.units_of("POR") if u.naval)
        unit.carrier = ship
        self.assertIsNone(R.idle_armies(self.w, "POR"))
        unit.carrier = None
        self.assertIsNotNone(R.idle_armies(self.w, "POR"))
        unit.acted = True
        ship.acted = False
        self.assertIsNone(R.idle_armies(self.w, "POR"), "the idle caravel is not an army")


if __name__ == "__main__":
    unittest.main()
