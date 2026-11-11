"""Tests for hexa.campaign.tech on its own (no world, no pygame)."""
import random
import unittest

from hexa.campaign import tech as T


class TechDataTests(unittest.TestCase):
    def test_grid_counts_per_branch(self):
        counts = {b: 0 for b in T.BRANCHES}
        for t in T.TECHS.values():
            counts[t.branch] += 1
        self.assertEqual(counts, {"military": 11, "trade": 10, "navigation": 9, "statecraft": 7})
        self.assertEqual(len(T.TECHS), 37)

    def test_keys_match_and_branches_valid(self):
        for k, t in T.TECHS.items():
            self.assertEqual(k, t.key)
            self.assertIn(t.branch, T.BRANCHES)
            self.assertIn(t.era, (1, 2, 3))

    def test_needs_exist_and_are_not_later_era(self):
        for t in T.TECHS.values():
            for n in t.needs:
                self.assertIn(n, T.TECHS, f"{t.key} needs unknown {n}")
                self.assertLessEqual(T.TECHS[n].era, t.era, f"{t.key} needs later-era {n}")

    def test_no_cycles(self):
        state = {}

        def visit(k, stack):
            if state.get(k) == "done":
                return
            self.assertNotIn(k, stack, f"cycle through {k}")
            state.setdefault(k, "visiting")
            for n in T.TECHS[k].needs:
                visit(n, stack + [k])
            state[k] = "done"

        for k in T.TECHS:
            visit(k, [])

    def test_effect_keys_allowed(self):
        groups = [T.TECHS.values(), T.NATIONAL_TECHS.values(), T.REGIONAL_TECHS.values()]
        for group in groups:
            for t in group:
                for k in t.effects:
                    self.assertIn(k, T.EFFECT_KEYS, f"{t.key} uses unknown effect {k}")
        for ideas in [T.IDEAS.values()] + [v for v in T.NATIONAL_IDEAS.values()]:
            for i in ideas:
                for k in i.effects:
                    self.assertIn(k, T.EFFECT_KEYS, f"idea {i.key} uses unknown effect {k}")

    def test_costs_in_era_ranges(self):
        ranges = {1: (35, 45), 2: (90, 110), 3: (170, 200)}
        for t in T.TECHS.values():
            lo, hi = ranges[t.era]
            self.assertTrue(lo <= t.cost <= hi, f"{t.key} cost {t.cost} outside era {t.era}")
        self.assertEqual(T.TECHS["printing_press"].cost, 45)

    def test_every_branch_has_an_era_one_tech(self):
        for b in T.BRANCHES:
            self.assertTrue(any(t.era == 1 and t.branch == b for t in T.TECHS.values()), b)

    def test_national_and_regional_techs(self):
        self.assertEqual(len(T.NATIONAL_TECHS), 12)
        for tag in ["POR", "CAS", "VEN", "GEN", "FRA", "ENG", "TUR", "HAN", "AUS", "BUR", "MOS", "POL"]:
            self.assertIn(tag, T.NATIONAL_TECHS)
            self.assertEqual(T.NATIONAL_TECHS[tag].era, 1)
            self.assertEqual(T.NATIONAL_TECHS[tag].national, tag)
        self.assertEqual(T.national_tech("POR", "default").key, "sagres")
        self.assertEqual(T.national_tech("XXX", "italian").key, "studia_humanitatis")
        self.assertEqual(T.national_tech("XXX", "german").key, "mining_law")
        self.assertEqual(T.national_tech("XXX", "north_african").key, "corsairs")
        self.assertEqual(T.national_tech("XXX", "default").key, "local_levies")
        self.assertEqual(T.national_tech("XXX").key, "local_levies")

    def test_tech_lookup(self):
        self.assertEqual(T.tech("galleon").name, "Galleon")
        self.assertEqual(T.tech("sagres").national, "POR")
        self.assertEqual(T.tech("corsairs").key, "corsairs")
        self.assertIsNone(T.tech("nope"))

    def test_ideas_have_general_and_national(self):
        self.assertGreaterEqual(len(T.IDEAS), 14)
        for tag, lst in T.NATIONAL_IDEAS.items():
            self.assertTrue(1 <= len(lst) <= 2, tag)
            for i in lst:
                self.assertEqual(i.nation, tag)


class LogicTests(unittest.TestCase):
    def test_path_to_prereqs_first(self):
        path = T.path_to("galleon", set())
        self.assertEqual(path[-1], "galleon")
        for need in ["carrack", "guilds", "ropewalk"]:
            self.assertIn(need, path)
        self.assertLess(path.index("guilds"), path.index("ropewalk"))
        self.assertLess(path.index("ropewalk"), path.index("galleon"))
        self.assertLess(path.index("carrack"), path.index("galleon"))
        self.assertEqual(len(path), len(set(path)))

    def test_path_to_skips_known(self):
        self.assertEqual(T.path_to("ropewalk", {"guilds"}), ["ropewalk"])
        self.assertEqual(T.path_to("ropewalk", {"guilds", "ropewalk"}), [])

    def test_available_respects_prereqs_and_era(self):
        avail = T.available({"drill_yards"}, 1)
        self.assertIn("supply_trains", avail)
        self.assertNotIn("tercio", avail)           # era II, too late for era I
        self.assertIn("tercio", T.available({"drill_yards"}, 2))  # prereq known, era II
        self.assertNotIn("volley_fire", avail)      # era III
        self.assertNotIn("drill_yards", avail)      # known
        self.assertNotIn("standing_army", T.available(set(), 1))  # era II
        self.assertIn("standing_army", T.available(set(), 2))

    def test_cost_diffusion_and_cap(self):
        # Tercio: 90 base, military. 2 neighbours know it: 20% off.
        scale = T.COST_SCALE[2]
        self.assertEqual(T.cost("tercio", 2, {}), round(T.TECHS["tercio"].cost * scale * 0.8))
        # 10 neighbours: capped at 30%.
        self.assertEqual(T.cost("tercio", 10, {}), round(T.TECHS["tercio"].cost * scale * 0.7))
        # diffusion_cap +0.2 raises the cap to 50%.
        self.assertEqual(T.cost("tercio", 10, {"diffusion_cap": 0.2}), round(T.TECHS["tercio"].cost * scale * 0.5))

    def test_cost_navigation_discount(self):
        # Galleon: 180 base, navigation. Sagres -25%.
        self.assertEqual(T.cost("galleon", 0, {"nav_cost": -0.25}),
                         round(T.TECHS["galleon"].cost * T.COST_SCALE[3] * 0.75))
        # Non-navigation techs ignore nav_cost.
        self.assertEqual(T.cost("tercio", 0, {"nav_cost": -0.25}), round(T.TECHS["tercio"].cost * T.COST_SCALE[2]))

    def test_era_ready_year_and_techs(self):
        era1 = {"drill_yards", "supply_trains", "siege_craft", "guilds"}
        self.assertFalse(T.era_ready(1, 1519, era1))          # too early
        self.assertFalse(T.era_ready(1, 1520, {"drill_yards", "supply_trains", "siege_craft"}))
        self.assertTrue(T.era_ready(1, 1520, era1))
        self.assertTrue(T.era_ready(1, 1600, era1))
        # The national tech is era I and counts.
        self.assertFalse(T.era_ready(1, 1520, {"sagres", "drill_yards", "supply_trains", "siege_craft"}),
                         "the free national tech does not count toward the gate")
        self.assertTrue(T.era_ready(1, 1520, {"guilds", "drill_yards", "supply_trains", "siege_craft"}))
        # Era II needs 1575 and 4 era II techs.
        era2 = {"tercio", "standing_army", "bronze_guns", "trace_italienne"}
        self.assertFalse(T.era_ready(2, 1574, era2))
        self.assertFalse(T.era_ready(2, 1575, {"tercio", "standing_army", "trace_italienne"}))
        self.assertTrue(T.era_ready(2, 1575, era2))
        # No era beyond III.
        self.assertFalse(T.era_ready(3, 2000, era2))

    def test_draw_ideas_three_distinct_with_national(self):
        for seed in range(20):
            rng = random.Random(seed)
            cards = T.draw_ideas("POR", {"military": 3}, set(), rng)
            keys = [c.key for c in cards]
            self.assertEqual(len(cards), 3)
            self.assertEqual(len(set(keys)), 3)
            self.assertIn("casa_da_india", keys)
            self.assertEqual(cards[0].nation, "POR")

    def test_draw_ideas_respects_taken(self):
        rng = random.Random(3)
        cards = T.draw_ideas("POR", {}, {"casa_da_india"}, rng)
        keys = [c.key for c in cards]
        self.assertEqual(len(cards), 3)
        self.assertNotIn("casa_da_india", keys)
        self.assertTrue(all(c.nation == "" for c in cards))
        taken = {"humanism", "condottieri", "fuggers_credit"}
        for seed in range(10):
            cards = T.draw_ideas("XXX", {"trade": 2}, taken, random.Random(seed))
            self.assertFalse(taken & {c.key for c in cards})

    def test_draw_ideas_no_national_card_for_untagged_country(self):
        cards = T.draw_ideas("XXX", {}, set(), random.Random(1))
        self.assertEqual(len(cards), 3)
        self.assertTrue(all(c.nation == "" for c in cards))

    def test_effects_sum_techs_ideas_and_national(self):
        eff = T.effects({"drill_yards", "tercio", "printing_press"},
                        {"humanism", "condottieri"}, "sagres")
        self.assertEqual(eff["upgrade_max"], 1)
        self.assertEqual(eff["vs_horse"], 0.25)
        self.assertAlmostEqual(eff["research"], 0.15 + 0.10)  # printing press + humanism
        self.assertEqual(eff["general_stack"], 1)             # condottieri
        self.assertAlmostEqual(eff["cavalry_cost"], -0.25)
        self.assertAlmostEqual(eff["nav_cost"], -0.25)        # sagres
        self.assertNotIn("stack", eff)                        # nothing gives it

    def test_effects_empty_and_unknown(self):
        self.assertEqual(T.effects(set(), set(), ""), {})
        self.assertEqual(T.effects({"no_such_tech"}, {"no_such_idea"}, "no_such_nation"), {})

    def test_effects_accepts_country_tag_for_national(self):
        eff = T.effects(set(), set(), "POL")
        self.assertEqual(eff, {"cavalry_attack": 1})  # Hussars, looked up by tag

    def test_research_points(self):
        # base 2 + burghers 40/40 = 1 + universities 1 + coffee (0.5 * 40/40 * 0.25 * 1 = 0.125)
        # = 4.125, times (1 + 0.15) = 4.74375
        rp = T.research_points(2, 40, 1, 0.5, {"research": 0.15, "coffee_research": 1})
        self.assertAlmostEqual(rp, 4.74375)
        self.assertAlmostEqual(T.research_points(0.6, 40, 0, 0, {}), 1.6)


if __name__ == "__main__":
    unittest.main()
