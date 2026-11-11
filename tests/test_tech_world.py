"""Tech tree in the world: starting techs, research, the age gate, ideas and the rules they change.

Run with:  python -m unittest discover -s tests -t .
"""
import unittest

from hexa.campaign import geo, tech
from hexa.campaign.data import CARRACK, GALLEON, STACK_BASE, troop
from hexa.campaign.world import CampaignWorld


def fresh():
    return CampaignWorld(player="POR")


class StartTest(unittest.TestCase):
    def test_portugal_starts_with_sagres_and_its_starting_techs(self):
        w = fresh()
        c = w.countries["POR"]
        self.assertEqual(c.national, "sagres")
        self.assertTrue({"sagres", "portolan", "astrolabe"} <= c.techs)
        self.assertIn(c.researching, tech.available(c.techs, 1), "research is set to an era I tech")
        self.assertEqual(c.era, 1)
        self.assertEqual(c.queue, [])

    def test_also_knows_adds_banking_for_venice(self):
        w = fresh()
        self.assertTrue({"banco_di_rialto", "banking"} <= w.countries["VEN"].techs)

    def test_big_empires_start_with_drill_yards(self):
        w = fresh()
        self.assertIn("drill_yards", w.countries["MOS"].techs)
        self.assertNotIn("drill_yards", w.countries["POR"].techs)

    def test_regional_default_techs_follow_the_capital(self):
        w = fresh()
        c = w.countries["MAM"]                       # no national tech: its region decides
        c.capital = geo.hex_of(12.5, 42.0)
        self.assertEqual(w._know_region("MAM"), "italian")
        c.capital = geo.hex_of(10.0, 51.0)
        self.assertEqual(w._know_region("MAM"), "german")
        c.capital = geo.hex_of(10.0, 30.0)
        self.assertEqual(w._know_region("MAM"), "north_african")
        c.capital = geo.hex_of(40.0, 60.0)
        self.assertEqual(w._know_region("MAM"), "default")


class ResearchTest(unittest.TestCase):
    def test_research_accumulates_then_finishes_and_the_queue_advances(self):
        w = fresh()
        c = w.countries["POR"]
        w.set_research("POR", "printing_press")
        c.queue = ["tax_rolls", "drill_yards"]
        cost = w.tech_cost("POR", "printing_press")
        rate, _ = w.research_rate("POR")
        c.research = cost - rate + 0.5          # this season's points just finish the press
        w._research()
        self.assertIn("printing_press", c.techs)
        self.assertEqual(c.researching, "tax_rolls", "the queue starts the next tech")
        self.assertEqual(c.queue, ["drill_yards"])
        self.assertTrue(any(m.startswith("Researched Printing press") for m in w.log))
        self.assertLess(c.research, w.tech_cost("POR", "tax_rolls"), "the leftover carries over")

    def test_progress_builds_up_without_finishing(self):
        w = fresh()
        c = w.countries["POR"]
        c.research = 0.0
        w._research()
        self.assertGreater(c.research, 0)
        self.assertNotIn(c.researching, c.techs)

    def test_set_research_queues_the_path_and_refuses_later_ages(self):
        w = fresh()
        self.assertFalse(w.set_research("POR", "universities"), "era II techs wait for the age")
        self.assertTrue(w.set_research("POR", "guilds"))
        self.assertEqual(w.countries["POR"].researching, "guilds")
        self.assertTrue(w.set_research("POR", "tax_rolls"))
        w.countries["POR"].queue = ["drill_yards"]
        self.assertTrue(w.unqueue("POR", "drill_yards"))
        self.assertFalse(w.unqueue("POR", "drill_yards"))

    def test_research_parts_add_up_and_count_universities(self):
        w = fresh()
        total, parts = w.research_rate("POR")
        self.assertAlmostEqual(total, sum(parts.values()))
        self.assertEqual(parts["universities"], 0)
        capital = w.provinces[w.countries["POR"].capital]
        capital.buildings["university"] = 1
        self.assertEqual(w.research_rate("POR")[1]["universities"], 1)

    def test_funding_research_gives_fifteen_points_with_the_fund_bonus(self):
        w = fresh()
        c = w.countries["POR"]
        c.treasury = 1000
        before = c.research
        self.assertTrue(w.fund_research("POR"))
        self.assertAlmostEqual(c.research - before, 15)
        self.assertFalse(w.fund_research("POR"), "only once a year")
        w.turn += 4
        w.grant_tech("POR", "casa_di_san_giorgio")          # Fund +25%
        before = c.research
        self.assertTrue(w.fund_research("POR"))
        self.assertAlmostEqual(c.research - before, 15 * 1.25)
        self.assertAlmostEqual(c.treasury, 1000 - 2 * 60)


class AgeTest(unittest.TestCase):
    def test_the_age_gate_needs_the_year_and_four_era_one_techs(self):
        w = fresh()
        c = w.countries["POR"]                             # knows portolan and astrolabe already (2 of 4)
        w.grant_tech("POR", "drill_yards")
        w.turn = 161                                       # 1520
        w._research()
        self.assertEqual(c.era, 1, "three era I techs are not enough")
        w.grant_tech("POR", "supply_trains")
        w.turn = 1
        w._research()
        self.assertEqual(c.era, 1, "the year is not there yet")
        w.turn = 161
        w._research()
        self.assertEqual(c.era, 2)
        self.assertEqual(len(c.pending_ideas), 3)
        self.assertEqual(len(set(c.pending_ideas)), 3, "three different cards")
        self.assertEqual(w.next_era("POR"), (3, 1575, 4))

    def test_picking_an_idea_applies_its_effect(self):
        w = fresh()
        c = w.countries["POR"]
        for key in ("drill_yards", "supply_trains", "siege_craft", "guilds"):
            w.grant_tech("POR", key)
        w.turn = 161
        w._research()
        key = c.pending_ideas[0]
        idea = w._idea(key)
        before = {k: w.bonus("POR", k) for k in idea.effects}
        self.assertTrue(w.pick_idea("POR", key))
        self.assertIn(key, c.ideas)
        self.assertEqual(c.pending_ideas, [])
        for k, v in idea.effects.items():
            self.assertAlmostEqual(w.bonus("POR", k), before[k] + v, msg=k)
        self.assertFalse(w.pick_idea("POR", key), "a card is picked once")


class EffectTest(unittest.TestCase):
    def setUp(self):
        self.w = fresh()

    def test_standing_army_raises_the_stack_limit(self):
        w = self.w
        self.assertEqual(w.stack_limit("POR"), STACK_BASE)
        w.grant_tech("POR", "standing_army")
        self.assertEqual(w.stack_limit("POR"), STACK_BASE + 1)

    def test_drill_yards_allow_a_third_drill(self):
        w = self.w
        prov = w.provinces[w.countries["POR"].capital]
        prov.buildings["barracks"] = 1
        w.countries["POR"].treasury = 5000
        unit = w._add_unit(troop("infantry", 1), "POR", prov.pos, moves=3)
        unit.atk_up = 2
        self.assertFalse(w.upgrade_check(unit, "attack")[0], "two drills is the old limit")
        w.grant_tech("POR", "drill_yards")
        self.assertTrue(w.upgrade_check(unit, "attack")[0])

    def test_ropewalk_needs_its_tech(self):
        w = self.w
        prov = w.provinces[w.countries["POR"].capital]
        prov.buildings.pop("ropewalk", None)
        prov.queue, prov.busy = [], False
        w.countries["POR"].treasury = 5000
        ok, reason = w.build_check("POR", prov, "ropewalk")
        self.assertFalse(ok)
        self.assertIn("Ropewalk", reason)
        w.grant_tech("POR", "ropewalk")
        self.assertNotIn("tech", w.build_check("POR", prov, "ropewalk")[1])

    def test_university_needs_a_city_and_its_tech(self):
        w = self.w
        capital = w.provinces[w.countries["POR"].capital]
        capital.queue, capital.busy = [], False
        w.countries["POR"].treasury = 5000
        ok, reason = w.build_check("POR", capital, "university")
        self.assertFalse(ok)
        self.assertIn("Universities", reason)
        w.grant_tech("POR", "universities")
        ok, reason = w.build_check("POR", capital, "university")
        self.assertIn("city", reason)

    def test_carracks_need_the_tech_and_a_shipyard(self):
        w = self.w
        port = w.provinces[w.countries["POR"].capital]
        port.busy = False
        w.countries["POR"].treasury = 10000
        ok, reason = w.recruit_check("POR", port, CARRACK)
        self.assertFalse(ok)
        self.assertIn("Carrack tech", reason)
        w.grant_tech("POR", "carrack")
        ok, reason = w.recruit_check("POR", port, CARRACK)
        self.assertIn("shipyard", reason)

    def test_galleons_are_a_unit_kind_that_needs_the_galleon_tech(self):
        w = self.w
        self.assertIn(GALLEON, w.raise_options("POR"))
        port = w.provinces[w.countries["POR"].capital]
        port.busy = False
        port.buildings["shipyard"] = 1
        w.countries["POR"].treasury = 10000
        ok, reason = w.recruit_check("POR", port, GALLEON)
        self.assertFalse(ok)
        self.assertIn("Galleon tech", reason)

    def test_trace_italienne_is_needed_for_a_large_castle(self):
        w = self.w
        prov = w.provinces[w.countries["POR"].capital]
        prov.castle, prov.queue, prov.busy = 2, [], False
        w.countries["POR"].treasury = 10000
        ok, reason = w.build_check("POR", prov, "castle")
        self.assertFalse(ok)
        self.assertIn("Trace italienne", reason)
        w.grant_tech("POR", "trace_italienne")
        self.assertTrue(w.build_check("POR", prov, "castle")[0])

    def test_neighbours_that_know_a_tech_make_it_cheaper(self):
        w = self.w
        base = w.tech_cost("POR", "printing_press")
        from hexa.campaign import tech
        self.assertEqual(base, round(tech.TECHS["printing_press"].cost * tech.COST_SCALE[1]))
        other = next(p.owner for m in w.merchant_markets("POR") for p in m.provinces
                     if p.owner not in (None, "POR"))
        w.grant_tech(other, "printing_press")
        self.assertLess(w.tech_cost("POR", "printing_press"), base)

    def test_cartography_explores_the_sea_around_your_markets(self):
        w = self.w
        explored = w.countries["POR"].explored
        partners = {m for r in w.routes for m in (r.a, r.b) if r.a in w.merchant_markets("POR")
                    or r.b in w.merchant_markets("POR")}
        centres = [m.center for m in partners if m.center is not None]
        self.assertTrue(centres)
        w.grant_tech("POR", "cartography")
        self.assertTrue(all(pos in explored for pos in centres if pos in w.terrain))


class MigrationTest(unittest.TestCase):
    def test_an_old_save_gets_its_national_tech_and_the_gate_techs(self):
        w = fresh()
        c = w.countries["FRA"]
        c.techs, c.era, c.researching = set(), 3, ""
        w._migrate()
        self.assertEqual(c.national, "gendarmerie")
        self.assertIn("gendarmerie", c.techs)
        era1 = [k for k in c.techs if tech.TECHS.get(k) and tech.TECHS[k].era == 1]
        era2 = [k for k in c.techs if tech.TECHS.get(k) and tech.TECHS[k].era == 2]
        self.assertGreaterEqual(len(era1), tech.ERA_GATE_TECHS)
        self.assertGreaterEqual(len(era2), tech.ERA_GATE_TECHS)
        for k in c.techs:                                  # prerequisites come along with the gate techs
            t = tech.tech(k)
            self.assertTrue(all(n in c.techs for n in t.needs), k)
        self.assertIn(c.researching, tech.available(c.techs, 3))
        self.assertGreater(w.tech_cost("FRA", c.researching), 0)

    def test_an_old_save_at_era_one_gets_only_its_national_tech(self):
        w = fresh()
        c = w.countries["ENG"]
        c.techs, c.era = set(), 1
        w._migrate()
        self.assertEqual(c.techs, {"wool_staple"})


if __name__ == "__main__":
    unittest.main()
