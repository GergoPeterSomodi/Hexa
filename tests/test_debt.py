"""Debt in the Age of Discovery: the AI's distress (no new spending, high taxes, troops disbanded), the debt
limit (interest stops there, unpaid troops desert, then creditors seize buildings) and the log messages.
Headless. Run with:  python -m unittest tests.test_debt"""
import unittest

from hexa.campaign import ai, data
from hexa.campaign.data import troop
from hexa.campaign.world import CampaignWorld

GEN = "GEN"


def fresh(player=None):
    w = CampaignWorld(1480, map="europe")
    w.player = player
    return w


def troops(world, tag, n, era=1):
    """n pikemen (or other infantry) for tag at its capital."""
    kind = troop("infantry", era)
    cap = world.countries[tag].capital
    for _ in range(n):
        world._add_unit(kind, tag, cap, moves=kind.moves)


def war_units(world, tag):
    return [u for u in world.units_of(tag) if u.kind.war]


class AIDistressTest(unittest.TestCase):
    def test_deep_debt_with_an_army_disbands_and_recovers_within_40_seasons(self):
        w = fresh()
        troops(w, GEN, 30)
        c = w.countries[GEN]
        c.treasury = -400
        self.assertGreater(len(war_units(w, GEN)), 20)
        recovered = None
        for season in range(1, 41):
            ai.run(w, GEN)
            w.end_round()
            if c.treasury >= 0 and c.balance >= 0:
                recovered = season
                break
        self.assertIsNotNone(recovered, f"still {c.treasury:.0f} ducats after 40 seasons")
        self.assertLess(len(war_units(w, GEN)), 30)       # troops were disbanded to pay the debt

    def test_distressed_country_taxes_high_and_builds_nothing(self):
        w = fresh()
        c = w.countries[GEN]
        c.treasury = -50
        before = len(w.units_of(GEN))
        ai.run(w, GEN)
        self.assertEqual(c.tax, "high")
        self.assertTrue(c.memory["distress"])
        self.assertLessEqual(len(w.units_of(GEN)), before)  # no recruits in distress

    def test_two_seasons_of_deficit_is_distress_and_positive_again_clears_it(self):
        w = fresh()
        c = w.countries[GEN]
        c.treasury = 100
        c.income = {"upkeep": -5.0}
        self.assertFalse(ai._distressed(c))                 # the first deficit season is not yet distress
        self.assertTrue(ai._distressed(c))                  # the second is
        c.income = {"upkeep": 5.0}
        self.assertFalse(ai._distressed(c))                 # back in surplus with a positive treasury


class DebtRuleTest(unittest.TestCase):
    def test_interest_stops_at_the_debt_limit(self):
        w = fresh()
        c = w.countries[GEN]
        c.treasury = -100000
        w.economy()
        limit = w.debt_limit(GEN)
        self.assertGreaterEqual(limit, data.DEBT_FLOOR)
        self.assertAlmostEqual(c.income["interest"], -data.DEBT_INTEREST * limit, places=6)

    def test_unpaid_troops_desert_over_the_limit_and_the_player_is_told(self):
        w = fresh(player=GEN)
        troops(w, GEN, 80)
        c = w.countries[GEN]
        c.treasury = -(w.debt_limit(GEN) + 500)
        w.economy()
        self.assertLess(c.balance, 0)
        before = len(war_units(w, GEN))
        w.collect()
        w._unpaid()
        self.assertLess(len(war_units(w, GEN)), before)
        self.assertTrue(any("desert" in line for line in w.log), w.log[-3:])

    def test_no_desertion_below_the_limit(self):
        w = fresh(player=GEN)
        troops(w, GEN, 80)
        c = w.countries[GEN]
        c.treasury = -(w.debt_limit(GEN) - 50)
        w.economy()
        before = len(war_units(w, GEN))
        w._unpaid()
        self.assertEqual(len(war_units(w, GEN)), before)

    def test_creditors_seize_buildings_when_no_troops_are_left(self):
        w = fresh(player=GEN)
        c = w.countries[GEN]
        for u in list(w.units_of(GEN)):
            w.units.remove(u)
        prov = w.provinces[c.capital]
        prov.controller = GEN
        prov.castle, prov.settlement = 2, 2
        c.income = {"upkeep": -50.0, "production": 0.0}
        c.treasury = -(w.debt_limit(GEN) + 100)
        self.assertLess(c.balance, 0)
        w._unpaid()
        self.assertLess(prov.castle + prov.settlement, 4)
        self.assertGreaterEqual(c.treasury, -w.debt_limit(GEN) - 1e-6)     # held at the limit, not below it
        self.assertTrue(any("seize" in line for line in w.log), w.log[-3:])


if __name__ == "__main__":
    unittest.main()
