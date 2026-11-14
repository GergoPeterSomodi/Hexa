"""A castle taken in war (0.2.2 replay, "a taken castle went back"): its holder builds a garrison for it at half the normal
rate, up to half its full size, only while no siege runs there and no enemy army stands on it; the owner then needs a real
siege against it; an army inside a castle its country holds is in supply; the defeated garrison is lost when the castle
changes hands again.

Pygame-free. Each test changes a fresh world. The holder is Portugal (POR) and the owner Castile (CAS), at war.
"""
import unittest

from hexa.campaign.data import GARRISON_HELD_SHARE, GARRISON_HP, GARRISON_REGEN, GARRISON_REGEN_HELD
from hexa.campaign.state import War
from hexa.campaign.systems import supply, war
from tests.support.battles import place
from tests.support.worlds import fresh


def held(world, castle, garrison=0):
    """A Castilian province (not its capital) that Portugal holds with ``castle`` levels, ``garrison`` hit points, a war
    between the two, and no armies on the map. Returns the province."""
    if not world.at_war("POR", "CAS"):
        world.wars.append(War("POR", "CAS", world.turn))
    world.units, world.battles = [], []
    prov = next(p for p in sorted(world.provinces_of("CAS"), key=lambda p: p.pos)
                if p.pos != world.countries["CAS"].capital and p.terrain == "plains")
    prov.castle = castle
    prov.garrison = garrison
    prov.controller = "POR"
    prov.siege, prov.besieger, prov.siege_turns, prov.siege_name = 0, "", 0, ""
    world.changed(ownership=True)
    return prov


def garrison_by_season(world, prov, seasons):
    """The garrison after each season's sieges() step, with nothing on the hex."""
    out = []
    for _ in range(seasons):
        world.sieges()
        out.append(prov.garrison)
    return out


class HeldGarrisonRegrowthTest(unittest.TestCase):
    def test_constants_give_half_the_rate_and_half_the_cap(self):
        self.assertEqual(GARRISON_REGEN_HELD * 2, GARRISON_REGEN)
        self.assertEqual(GARRISON_HELD_SHARE, 0.5)

    def test_a_taken_castle_builds_a_garrison_to_half_its_full_size(self):
        for castle in (1, 2, 3):
            world = fresh("POR")
            prov = held(world, castle)
            cap = int(castle * GARRISON_HP * GARRISON_HELD_SHARE)
            seen = garrison_by_season(world, prov, cap + 3)
            self.assertEqual(seen[:cap], list(range(1, cap + 1)), f"castle {castle}: one hit point a season")
            self.assertEqual(seen[-1], cap, f"castle {castle}: stops at half the full garrison")
            self.assertLess(cap, castle * GARRISON_HP, "a held castle never reaches its full garrison")

    def test_the_owners_castle_still_regrows_at_the_full_rate(self):
        world = fresh("POR")
        prov = held(world, 2)
        prov.controller = prov.owner                       # the owner holds it
        prov.garrison = 0
        seen = garrison_by_season(world, prov, 6)
        self.assertEqual(seen[:6], [2, 4, 6, 8, 10, 12])
        self.assertEqual(GARRISON_REGEN, 2)

    def test_no_regrowth_while_a_siege_runs_there(self):
        world = fresh("POR")
        prov = held(world, 2)
        place(world, "infantry", 1, "CAS", prov.pos, 6)    # the owner's army besieges it
        world.sieges()
        self.assertEqual(prov.besieger, "CAS", "the siege starts")
        self.assertEqual(prov.garrison, 0, "a besieged castle does not regrow")
        world.sieges()
        self.assertEqual(prov.garrison, 0)

    def test_no_regrowth_while_an_enemy_army_stands_on_it(self):
        world = fresh("POR")
        prov = held(world, 2)
        place(world, "infantry", 1, "CAS", prov.pos, 1)     # one enemy regiment: it besieges (too few men: no meter)
        seen = garrison_by_season(world, prov, 2)
        self.assertEqual(seen, [0, 0], "an enemy army on the hex: no regrowth")

    def test_the_holders_own_men_on_it_do_not_stop_the_garrison(self):
        world = fresh("POR")
        prov = held(world, 2)
        place(world, "infantry", 1, "POR", prov.pos, 2)
        seen = garrison_by_season(world, prov, 2)
        self.assertEqual(seen, [GARRISON_REGEN_HELD, 2 * GARRISON_REGEN_HELD])

    def test_a_held_castle_is_not_driven_out_by_the_people(self):
        world = fresh("POR")
        prov = held(world, 1, garrison=0)
        garrison_by_season(world, prov, 12)
        self.assertEqual(prov.controller, "POR", "the garrison holds it (the six-season rule is for places with none)")

    def test_the_owner_retaking_the_castle_loses_the_garrison(self):
        world = fresh("POR")
        prov = held(world, 2, garrison=6)
        place(world, "infantry", 1, "CAS", prov.pos, 6)
        for _ in range(10):
            world.sieges()
            if prov.controller == "CAS":
                break
        self.assertEqual(prov.controller, "CAS")
        self.assertEqual(prov.garrison, 0, "the held garrison is lost; the owner's regrows from zero")
        world.units = []
        self.assertEqual(garrison_by_season(world, prov, 1), [GARRISON_REGEN])

    def test_peace_handing_the_castle_back_loses_the_garrison(self):
        world = fresh("POR")
        prov = held(world, 2, garrison=4)
        world.peace("POR", "CAS", winner="CAS")
        self.assertEqual(prov.controller, "CAS")
        self.assertEqual(prov.garrison, 0)


class OwnerRetakeTest(unittest.TestCase):
    def test_the_owner_needs_a_real_siege_against_a_full_held_garrison(self):
        world = fresh("POR")
        prov = held(world, 2, garrison=int(2 * GARRISON_HP * GARRISON_HELD_SHARE))
        units = place(world, "infantry", 1, "CAS", prov.pos, 3)
        forecast = war.siege_forecast(world, prov, "CAS", units)
        self.assertIsNotNone(forecast)
        self.assertGreater(forecast, 2, "more than the two-season floor when the held garrison is full")
        seasons = 0
        for seasons in range(1, 20):
            world.sieges()
            if prov.controller == "CAS":
                break
        self.assertEqual(seasons, forecast, "the engine agrees with the card's forecast")

    def test_one_regiment_takes_a_full_held_castle_only_slowly(self):
        # OPEN QUESTION (see the 0.2.2 replay report): a held garrison is 100 men a hit point, half the owner's, so one
        # 1,000-man regiment outnumbers a full held level 2 castle (600 men) and takes it in its need's seasons, not never.
        world = fresh("POR")
        prov = held(world, 2, garrison=int(2 * GARRISON_HP * GARRISON_HELD_SHARE))
        units = place(world, "infantry", 1, "CAS", prov.pos, 1)
        forecast = war.siege_forecast(world, prov, "CAS", units)
        self.assertEqual(forecast, 5, "need 7 at one point a season, with hunger from the third season")
        seasons = 0
        for seasons in range(1, 20):
            world.sieges()
            if prov.controller == "CAS":
                break
        self.assertEqual(seasons, forecast)


class HeldSupplyTest(unittest.TestCase):
    def test_a_castle_its_country_holds_is_a_depot_for_the_holder(self):
        world = fresh("POR")
        prov = held(world, 2)
        self.assertTrue(world.is_depot("POR", prov.pos))
        self.assertFalse(world.is_depot("CAS", prov.pos), "the owner has no depot in a castle it has lost")

    def test_an_army_inside_a_held_castle_is_in_supply_and_fed(self):
        world = fresh("POR")
        prov = held(world, 2, garrison=2)
        stack = place(world, "infantry", 1, "POR", prov.pos, 2)
        self.assertTrue(world.in_supply("POR", prov.pos))
        self.assertEqual(supply.supply_state(world, stack)[0], "supplied")
        world.logistics()
        self.assertTrue(all(u.supplied for u in stack))

    def test_a_town_its_holder_has_not_won_is_no_depot_for_the_holder(self):
        world = fresh("POR")
        prov = held(world, 0)
        prov.settlement = 2
        self.assertFalse(world.is_depot("POR", prov.pos), "a town needs its owner's holding too, as before")


if __name__ == "__main__":
    unittest.main()
