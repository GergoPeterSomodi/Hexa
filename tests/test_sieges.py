"""The sieges of 0.2.2 (docs/design/sieges-and-retreats.md, section 4): the pace table of 4.3 in the engine, the 2-season
floor, hunger, the lift (the besieger leaves, a relief army, peace), the storm's cut of the garrison, a besieged place's
output and its free foraging, the names, Besiege refused for too few men, and the siege read model. The meter's rules
are war.py (the crowd, need, rate, hunger); this file plays them through ``war.sieges`` season by season.

Pygame-free. Each test changes a fresh world. The pace table is also printed by tools/siege_stats.py.
"""
import math
import unittest

from hexa.campaign.battleview import odds_view, siege_view
from hexa.hexgrid import neighbors
from hexa.campaign.data import GARRISON_HP, SIEGE_HUNGER
from hexa.campaign.state import War
from hexa.campaign import saves
from hexa.campaign.systems import economy as ecosys, war
from tests.support.battles import place
from tests.support.digests import world_digest
from tests.support.home import TempHome
from tests.support.invariants import campaign_problems
from tests.support.worlds import fresh

# design 4.3: the seasons to take with a full garrison on plains, no general (no castle, castle 1, 2, 3); None: cannot
PACE = (
    ("1 regiment, no guns", [("infantry", 1, 1)], (2, 4, None, None)),
    ("3 regiments, no guns", [("infantry", 1, 3)], (2, 3, 4, 7)),
    ("6 regiments, no guns", [("infantry", 1, 6)], (2, 3, 4, 6)),
    ("3 regiments + 1 bombard", [("infantry", 1, 3), ("artillery", 1, 1)], (2, 2, 4, 6)),
    ("6 regiments + 1 bombard", [("infantry", 1, 6), ("artillery", 1, 1)], (2, 2, 3, 5)),
    ("3 regiments + 2 culverins", [("infantry", 1, 3), ("artillery", 2, 2)], (2, 2, 2, 3)),
)


def target(world, castle, garrison=True):
    """An empty Castilian province (not the capital) made a castle of ``castle`` levels with a full garrison, and a war
    between Portugal and Castile. Returns the province."""
    world.wars.append(War("POR", "CAS", world.turn))
    prov = next(p for p in sorted(world.provinces_of("CAS"), key=lambda p: p.pos)
                if p.pos != world.countries["CAS"].capital and not world.units_at(p.pos))
    prov.terrain = "plains"
    prov.castle = castle
    prov.garrison = castle * GARRISON_HP if garrison else 0
    prov.controller = "CAS"
    prov.siege, prov.besieger, prov.siege_turns, prov.siege_name = 0, "", 0, ""
    world.changed(ownership=True)
    return prov


def stand(world, pos):
    """A land hex beside pos: where a stack walks up from."""
    return next(n for n in sorted(neighbors(pos)) if n in world.provinces and world.is_land(n))


def seasons_to_fall(world, prov, limit=40):
    """Season ends until the place falls, the army being there already (None if it never does)."""
    for n in range(1, limit + 1):
        world.sieges()
        if prov.controller == "POR":
            return n
    return None


class PaceTest(unittest.TestCase):
    def test_every_cell_of_the_table_within_one_season(self):
        for label, spec, expected in PACE:
            for castle, want in zip((0, 1, 2, 3), expected):
                world = fresh("POR")
                world.units = []
                world.battles = []
                prov = target(world, castle)
                for branch, era, count in spec:
                    place(world, branch, era, "POR", prov.pos, count)
                got = seasons_to_fall(world, prov)
                if want is None:
                    self.assertIsNone(got, f"{label}, castle {castle}: cannot take it")
                else:
                    self.assertIsNotNone(got, f"{label}, castle {castle}")
                    self.assertLessEqual(abs(got - want), 1, f"{label}, castle {castle}: {got} against {want}")

    def test_no_place_falls_in_under_two_seasons(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 0, garrison=False)
        place(world, "infantry", 1, "POR", prov.pos, 6)          # guns or not, the floor holds
        world.sieges()
        self.assertEqual(prov.controller, "CAS", "the arrival season does not take the place")
        world.sieges()
        self.assertEqual(prov.controller, "POR")


class CrowdAndFloorTest(unittest.TestCase):
    def test_one_regiment_cannot_take_a_castle_of_level_2_or_3(self):
        for castle in (2, 3):
            world = fresh("POR")
            world.units = []
            prov = target(world, castle)
            place(world, "infantry", 1, "POR", prov.pos, 1)
            for _ in range(40):
                world.sieges()
                world.turn += 1
            self.assertEqual(prov.controller, "CAS")
            self.assertEqual((prov.besieger, prov.siege, prov.siege_turns), ("", 0, 0),
                             "too few men: no meter, no hunger")

    def test_too_few_men_keep_the_output(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        place(world, "infantry", 1, "POR", prov.pos, 1)
        world.sieges()
        self.assertFalse(prov.besieger)
        self.assertFalse(war.besieged(prov))

    def test_besieger_too_few_is_refused_with_the_men(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        stack = place(world, "infantry", 1, "POR", stand(world, prov.pos), 1)
        ok, reason = war.besiege_check(world, stack, prov.pos)
        self.assertFalse(ok)
        self.assertIn("Too few men to hold a siege (need 1,200, you have 1,000)", reason)


class HungerAndLiftTest(unittest.TestCase):
    def test_hunger_adds_points_after_the_stores_run_out(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 3)
        place(world, "infantry", 1, "POR", prov.pos, 3)
        events = []
        world.bus.tap(lambda e: events.append(e) if e.kind == "siege_progress" else None)
        seasons_to_fall(world, prov)
        hunger = [(e.get("seasons"), e.get("hunger")) for e in events]
        self.assertEqual([h for s, h in hunger if s <= 4], [0, 0, 0, 0], "the stores (1 + castle level) last 4 seasons")
        self.assertEqual(hunger[4][1], SIEGE_HUNGER, "the fifth season starves the garrison")

    def test_a_relief_army_lifts_the_siege_and_its_progress_is_lost(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        besiegers = place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        self.assertEqual(prov.besieger, "POR")
        lifted = []
        world.bus.tap(lambda e: lifted.append(e) if e.kind == "siege_lifted" else None)
        for unit in besiegers:
            world.units.remove(unit)
        place(world, "infantry", 1, "CAS", prov.pos, 2)
        world.sieges()
        self.assertEqual((prov.besieger, prov.siege, prov.siege_turns), ("", 0, 0))
        self.assertEqual(lifted[0].get("why"), "relief")

    def test_the_besieger_leaving_lifts_the_siege(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        besiegers = place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        for unit in besiegers:
            unit.pos = stand(world, prov.pos)
        world.sieges()
        self.assertEqual(prov.besieger, "")

    def test_peace_ends_every_siege(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        self.assertTrue(prov.siege > 0)
        world.peace("POR", "CAS")
        self.assertEqual((prov.besieger, prov.siege, prov.siege_turns, prov.siege_name), ("", 0, 0, ""))

    def test_a_retreated_stack_makes_no_progress_that_season(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 0, garrison=False)
        place(world, "infantry", 1, "POR", prov.pos, 3)
        world.retreated[prov.pos] = world.turn
        world.sieges()
        self.assertEqual((prov.besieger, prov.siege, prov.siege_turns), ("", 0, 0))


class StormTest(unittest.TestCase):
    def test_the_storm_cuts_the_garrison_by_the_progress_share(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 3)
        place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        need = world.siege_terms(prov, "POR", [u for u in world.units if u.pos == prov.pos])["need"]
        self.assertEqual(prov.siege, 1, "3 regiments against a level 3 castle: one point a season")
        self.assertEqual(war.storm_garrison(world, prov), math.ceil(18 * (1 - 0.5 * 1 / need)))
        prov.siege = need // 2
        self.assertLess(war.storm_garrison(world, prov), 18)
        prov.siege = 0
        self.assertEqual(war.storm_garrison(world, prov), 18, "an arrival storm faces the whole garrison")

    def test_a_storm_in_a_siege_is_a_battle_with_the_cut_garrison(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        stack = place(world, "infantry", 1, "POR", prov.pos, 4)
        world.sieges()
        self.assertTrue(world.storm_check(stack, prov.pos)[0], "Storm now is open every season of a siege")
        self.assertTrue(world.storm_group(stack, prov.pos))
        self.assertIsNotNone(world.battle_at(prov.pos))


    def test_the_cut_lasts_for_the_storm_battle_only_and_the_losses_come_off_the_uncut_garrison(self):
        from hexa.campaign.systems import battle as battlesys
        world = fresh("POR")
        world.units = []
        prov = target(world, 3)
        stack = place(world, "infantry", 1, "POR", prov.pos, 4)
        world.sieges()
        world.sieges()
        uncut, progress = prov.garrison, prov.siege
        self.assertTrue(world.storm_group(stack, prov.pos))
        self.assertLess(prov.garrison, uncut, "the storm faces the cut garrison")
        cut = prov.garrison
        battlesys.battle_season(world)
        if prov.controller == "CAS":
            self.assertGreaterEqual(prov.garrison, uncut - (uncut - cut) - 0)
            self.assertLessEqual(prov.garrison, uncut)
            self.assertEqual(prov.siege, progress, "the meter keeps its progress: the cut is not taken twice")
            self.assertTrue(all(b.storm_from == 0 for b in world.battles), "no cut left on a battle")
        self.assertEqual(campaign_problems(world), [])


class OutputAndNameTest(unittest.TestCase):
    def test_a_besieged_place_produces_nothing(self):
        world = fresh("POR")
        world.units = []
        prov = next(p for p in world.provinces_of("POR") if p.market and p.good and p.controller == "POR")
        prov.peasants = max(prov.peasants, 5.0)
        ecosys.economy(world, preview=True)
        self.assertGreater(prov.output, 0, "unbesieged, the place works")
        prov.besieger = "CAS"
        ecosys.economy(world, preview=True)
        self.assertEqual(prov.output, 0.0, "a besieged place produces nothing")

    def test_besiegers_forage_the_place_free(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        stack = place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        hp = [u.hp for u in stack]
        world.logistics()
        self.assertEqual([u.hp for u in stack], hp, "a besieging stack loses no men to supply")
        self.assertTrue(all(u.supplied for u in stack))

    def test_sieges_are_named_and_a_repeat_says_second(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 2)
        place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        first = prov.siege_name
        self.assertTrue(first.startswith("Siege of "), first)
        self.assertIn(", ", first)
        self.assertEqual(war.siege_name(world, prov.pos).split(",")[0].split(" of ")[0], "Second Siege")


class SiegeViewTest(unittest.TestCase):
    def test_the_read_model_has_the_meter_the_hunger_the_seasons_and_the_forecast(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 3)
        place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        view = siege_view(world, prov.pos, viewer=None)
        self.assertEqual(view["besieger"], "POR")
        self.assertEqual((view["progress"], view["need"], view["rate"]), (prov.siege, 13, 1))
        self.assertEqual(view["seasons"], 1)
        self.assertEqual(view["stores_left"], 3)
        self.assertFalse(view["starving"])
        self.assertEqual(view["falls_in"], 6, "a level 3 castle with 3 regiments falls in 7 seasons; 6 more from now")
        self.assertIsNone(siege_view(world, (0, 0), viewer=None))

    def test_the_besiege_entry_of_the_odds_card_gives_the_seasons_and_the_war_clock(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 3)
        stack = place(world, "infantry", 1, "POR", stand(world, prov.pos), 3)
        world.player = "POR"
        view = odds_view(world, stack, prov.pos, "POR")
        self.assertIsNotNone(view["besiege"])
        self.assertEqual(view["besiege"]["seasons"], 7)
        self.assertEqual(view["besiege"]["need"], 13)
        self.assertTrue(view["besiege"]["ok"])
        self.assertIsNotNone(view["besiege"]["war_left"])
        self.assertFalse(view["besiege"]["war_ends_first"])
        world.player = None


class SaveTest(TempHome):
    def test_a_save_taken_mid_siege_comes_back_exactly_and_the_siege_plays_on(self):
        world = fresh("POR")
        world.units = []
        prov = target(world, 3)
        place(world, "infantry", 1, "POR", prov.pos, 3)
        world.sieges()
        world.sieges()
        world.update_visibility()           # a saved game is always drawn from its own fog (loading recomputes it)
        digest, progress = world_digest(world), (prov.besieger, prov.siege, prov.siege_turns, prov.siege_name)
        saves.save(world, "2")
        back = saves.load("2")
        self.assertIsNotNone(back)
        self.assertEqual(world_digest(back), digest)
        again = back.provinces[prov.pos]
        self.assertEqual((again.besieger, again.siege, again.siege_turns, again.siege_name), progress)
        back.end_round()
        self.assertEqual(again.siege_turns, 3, "the next season plays the siege on")
        self.assertEqual(campaign_problems(back), [])


if __name__ == "__main__":
    unittest.main()
