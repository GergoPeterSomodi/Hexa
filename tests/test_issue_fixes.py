"""Fixes for issues #23, #30, #31 and #32 (v0.1.6 and v0.1.7): the tax preview, one path search per AI move,
the geography hooks that replace Europe's special cases, and one home folder for settings and saves.
Headless. Run with:  python -m unittest tests.test_issue_fixes"""
import os
import shutil
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

from hexa import settings
from hexa.campaign import ai, geo, saves
from hexa.campaign.data import GOODS, troop
from hexa.campaign.world import CampaignWorld
from hexa.hexgrid import neighbors


def counting(world, name):
    """Record every call to one of this world's methods (the patch lives on this instance only)."""
    calls = []
    original = getattr(world, name)

    def counted(*args, **kwargs):
        calls.append(name)
        return original(*args, **kwargs)

    setattr(world, name, counted)
    return calls


class HomeFolderTest(unittest.TestCase):
    """#32: settings and saves take their folder from one place: HEXA_HOME, else ~/.hexa."""

    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.old = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home

    def tearDown(self):
        if self.old is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old
        shutil.rmtree(self.home, ignore_errors=True)

    def test_settings_and_saves_agree_on_the_folder(self):
        self.assertEqual(settings.home(), self.home)
        self.assertEqual(saves.folder(), os.path.join(self.home, "saves"))
        self.assertEqual(settings._path(), os.path.join(self.home, "settings.json"))

    def test_saves_follow_settings_home(self):
        elsewhere = os.path.join(self.home, "elsewhere")
        with mock.patch.object(settings, "home", return_value=elsewhere):
            self.assertEqual(saves.folder(), os.path.join(elsewhere, "saves"))
            self.assertEqual(settings._path(), os.path.join(elsewhere, "settings.json"))

    def test_without_hexa_home_both_use_dot_hexa(self):
        with mock.patch.dict(os.environ):
            os.environ.pop("HEXA_HOME")
            expected = os.path.join(os.path.expanduser("~"), ".hexa")
            self.assertEqual(settings.home(), expected)
            self.assertEqual(saves.folder(), os.path.join(expected, "saves"))


class TaxPreviewTest(unittest.TestCase):
    """#23: a tax change previews the economy. It must not use up the season's pending purchases or add to
    the price history, and the season's own economy must come out exactly as it would have."""

    def test_a_tax_change_keeps_pending_purchases_and_history(self):
        w = CampaignWorld(1480, map="europe")
        tag = next(iter(w.countries))
        market = next(m for m in w.markets if m.provinces)
        market.pending = {"grain": 7.0}
        lengths = {g: len(market.history[g]) for g in GOODS}
        w.set_tax(tag, "high")
        self.assertEqual(w.countries[tag].tax, "high")
        self.assertEqual(market.pending, {"grain": 7.0}, "the purchases wait for the season")
        self.assertGreaterEqual(market.demand["grain"] + market.demand["fish"], 7.0,
                                "the projection still counts them")
        self.assertEqual({g: len(market.history[g]) for g in GOODS}, lengths, "no history point added")

    def test_tax_changes_leave_the_season_exactly_as_it_would_have_been(self):
        plain = CampaignWorld(1480, map="europe")
        tried = CampaignWorld(1480, map="europe")
        tag = next(iter(plain.countries))
        for w in (plain, tried):
            w.countries[tag].tax = "normal"
            next(m for m in w.markets if m.provinces).pending = {"grain": 50.0}
        for level in ("high", "low", "high", "normal"):
            tried.set_tax(tag, level)
        plain.end_round()
        tried.end_round()
        self.assertEqual({t: c.treasury for t, c in plain.countries.items()},
                         {t: c.treasury for t, c in tried.countries.items()})
        self.assertEqual([(m.name, dict(m.price), {g: len(h) for g, h in m.history.items()}) for m in plain.markets],
                         [(m.name, dict(m.price), {g: len(h) for g, h in m.history.items()}) for m in tried.markets])


class MovePathTest(unittest.TestCase):
    """#30: one path search per move, and the cargo of a stack is looked up once, not at every step."""

    def setUp(self):
        self.w = CampaignWorld(1480, map="europe")
        self.tag = next(iter(self.w.countries))
        cap = self.w.countries[self.tag].capital
        kind = troop("infantry", 1)
        self.group = [self.w._add_unit(kind, self.tag, cap, moves=kind.moves) for _ in range(3)]
        self.far = self.w.countries[list(self.w.countries)[-1]].capital

    def farthest_stop(self):
        reach = self.w.reachable_group(self.group)
        return max((p for p in reach if p != self.group[0].pos), key=lambda p: reach[p])

    def test_moving_a_stack_to_a_stop_plans_the_route_once(self):
        dest = self.farthest_stop()
        plans = counting(self.w, "plan")
        self.assertTrue(self.w.move_group(self.group, dest))
        self.assertEqual(len(plans), 1)

    def test_walking_a_stack_looks_up_cargo_once_per_unit(self):
        dest = self.farthest_stop()
        scans = counting(self.w, "cargo")
        self.assertTrue(self.w.move_group(self.group, dest))
        self.assertLessEqual(len(scans), len(self.group), "cargo was looked up at every step")

    def test_an_ai_style_move_toward_a_goal_plans_the_route_once(self):
        plans = counting(self.w, "plan")
        self.w.move_toward_group(self.group, self.far)
        self.assertLessEqual(len(plans), 1)

    def test_moving_toward_a_goal_ends_where_the_two_step_way_did(self):
        """move_toward_group (one plan) and move_group(step_toward_group(...)) (two plans) must agree."""
        a = CampaignWorld(1480, map="europe")
        b = CampaignWorld(1480, map="europe")
        goals = [a.countries[t].capital for t in list(a.countries)[:5]]
        moves = 0
        for turn in range(4):
            for tag in a.countries:
                a.start_units(tag)
                b.start_units(tag)
            for index, (ua, ub) in enumerate(zip(a.units, b.units)):
                if ua.kind.war and ua.moves_left > 0 and not ua.carrier and ua.kind.moves > 0:
                    goal = goals[(index + turn) % len(goals)]
                    a.move_group([ua], a.step_toward_group([ua], goal))
                    b.move_toward_group([ub], goal)
                    moves += 1
            self.assertEqual([(u.id, u.pos, u.moves_left) for u in a.units],
                             [(u.id, u.pos, u.moves_left) for u in b.units])
        self.assertGreater(moves, 20)


class RegionTest(unittest.TestCase):
    """#31: the Old World, the New World and colonisable land come from the map's own geography, not from
    map == "random" checks. Europe keeps its cut-offs; a random world uses its own Old World."""

    def test_region_agrees_with_in_old_world_and_new_world_on_europe(self):
        w = CampaignWorld(1480, map="europe")
        for pos in w.terrain:
            lon = geo.lonlat(pos)[0]
            self.assertEqual(w.region(pos) == "old", w.in_old_world(pos), pos)
            self.assertEqual(w.region(pos) == "new", lon < -30, pos)

    def test_random_world_old_world_is_its_known_world(self):
        w = CampaignWorld(7, map="random")
        known = {p for p in w.terrain if w.geo.KNOWN_WORLD(*geo.lonlat(p))}
        self.assertTrue(known)
        for pos in w.terrain:
            self.assertEqual(w.in_old_world(pos), pos in known, pos)
            self.assertEqual(w.region(pos) == "old", pos in known, pos)

    def test_random_world_colonises_east_of_20_degrees_in_the_south(self):
        """The AI used to drop every site east of 20 degrees on any map. A random world's southern land there
        is colonisable (it is not its Old World)."""
        w = CampaignWorld(7, map="random")
        good = next(g for g, d in GOODS.items() if d.kind != "money")
        tag = next(iter(w.countries))
        site = None
        for pos in sorted(w.provinces):
            lon, lat = geo.lonlat(pos)
            if not (lon > 20 and lat < 13) or w.region(pos) == "old" or w.provinces[pos].owner is not None:
                continue
            sea = [n for n in neighbors(pos) if w.is_sea(n)]
            if sea:
                site = (pos, sea[0])
                break
        self.assertIsNotNone(site, "seed 7 has a southern colony site east of 20 degrees")
        pos, sea = site
        prov = w.provinces[pos]
        prov.coastal, prov.good, prov.terrain = True, good, "plains"
        w.countries[tag].explored = {pos}
        self.assertEqual(ai._pick_site(w, tag, SimpleNamespace(pos=sea)), pos)

    def test_europe_still_keeps_its_africa_east_cut_off(self):
        w = CampaignWorld(1480, map="europe")
        good = next(g for g, d in GOODS.items() if d.kind != "money")
        tag = next(iter(w.countries))
        pos = next(p for p in sorted(w.terrain)
                   if w.is_land(p) and geo.lonlat(p)[0] > 25 and geo.lonlat(p)[1] < 13
                   and any(w.is_sea(n) for n in neighbors(p)) and w.provinces[p].owner is None)
        prov = w.provinces[pos]
        prov.coastal, prov.good, prov.terrain = True, good, "plains"
        w.countries[tag].explored = {pos}
        sea = next(n for n in neighbors(pos) if w.is_sea(n))
        self.assertIsNone(ai._pick_site(w, tag, SimpleNamespace(pos=sea)))

    def test_trading_posts_use_the_map_s_own_tropics(self):
        europe = CampaignWorld(1480, map="europe")
        self.assertTrue(europe.tropical(geo.hex_of(10, 10)), "Africa, south of 17 degrees")
        self.assertFalse(europe.tropical(geo.hex_of(-25, 10)), "the Americas are not Africa")
        random = CampaignWorld(7, map="random")
        southern = [p for p in random.terrain if random.is_land(p) and geo.lonlat(p)[1] < 17]
        self.assertTrue(any(random.tropical(p) for p in southern))
        self.assertFalse(any(random.tropical(p) for p in random.terrain if geo.lonlat(p)[1] >= 17))
        self.assertFalse(any(random.tropical(p) for p in random.terrain if random.region(p) == "new"))


if __name__ == "__main__":
    unittest.main()
