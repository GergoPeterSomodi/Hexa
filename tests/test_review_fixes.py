"""Fixes from the Age of Discovery code review: a tax preview must not change the season (prices, routes), the
article before "university", the stuck-stack reasons, banner(""), a manual order must not cancel the orders of
units that were not ticked, a march must wait at a snow-closed pass instead of being dropped, and the markets
view must find each market's number. Headless. Run with:  python -m unittest tests.test_review_fixes"""
import os
import random
import shutil
import tempfile
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

from hexa.campaign import ai  # noqa: E402
from hexa.campaign.app import CampaignApp  # noqa: E402
from hexa.campaign.data import troop  # noqa: E402
from hexa.campaign.mapview import MapView  # noqa: E402
from hexa.campaign.world import CampaignWorld, Market, _with_article  # noqa: E402
from tests.test_passes import GOTTHARD, SUMMER, WINTER, infantry  # noqa: E402
from tests.test_playtest import front, place  # noqa: E402


def setUpModule():
    global _home, _old_home
    _home = tempfile.mkdtemp(prefix="hexa_review_")
    _old_home = os.environ.get("HEXA_HOME")
    os.environ["HEXA_HOME"] = _home
    pygame.init()


def tearDownModule():
    if _old_home is None:
        os.environ.pop("HEXA_HOME", None)
    else:
        os.environ["HEXA_HOME"] = _old_home
    shutil.rmtree(_home, ignore_errors=True)


class TaxPreviewTest(unittest.TestCase):
    """Clicking tax is a preview: the season that follows must be the same as if nobody had clicked."""

    @staticmethod
    def season(clicks):
        w = CampaignWorld(1480, map="europe")
        w.player = "POR"
        for m in w.markets:
            m.pending["grain"] = 30.0
        for level in clicks:
            w.set_tax("POR", level)
        random.seed(1480)
        w.settle_preview()                 # what end_turn does before the AI moves
        for tag in w.countries:
            if tag != "POR":
                ai.run(w, tag)
        w.end_round()
        return w

    def test_five_tax_clicks_leave_the_season_as_if_unclicked(self):
        clicked = self.season(["high", "low", "high", "low", "normal"])
        plain = self.season([])
        self.assertEqual({t: c.treasury for t, c in clicked.countries.items()},
                         {t: c.treasury for t, c in plain.countries.items()})
        self.assertEqual([dict(m.price) for m in clicked.markets], [dict(m.price) for m in plain.markets])

    def test_the_preview_still_shows_the_new_income(self):
        w = CampaignWorld(1480, map="europe")
        w.player = "POR"
        country = w.countries["POR"]
        before = country.balance
        w.set_tax("POR", "high")
        self.assertNotEqual(before, country.balance)


class ArticleTest(unittest.TestCase):
    def test_the_article_follows_the_sound(self):
        self.assertEqual(_with_article("University"), "a university")
        self.assertEqual(_with_article("Use"), "a use")
        self.assertEqual(_with_article("Armoury"), "an armoury")
        self.assertEqual(_with_article("Barracks"), "a barracks")
        self.assertEqual(_with_article("Weaver"), "a weaver")

    def test_the_empty_name_gives_nothing(self):
        self.assertEqual(_with_article(""), "")


class StuckReasonTest(unittest.TestCase):
    def setUp(self):
        self.w = CampaignWorld(player="POR")
        self.w.units = [u for u in self.w.units if u.owner != "POR"]
        self.home = self.w.provinces_of("POR")[0].pos
        self.w.units = [u for u in self.w.units if u.pos != self.home]
        self.pikes = troop("infantry", 1)

    def test_a_forage_mark_on_the_hex_does_not_blame_a_stack_that_did_not_forage(self):
        w = self.w
        prov = w.provinces[self.home]
        prov.foraged = ("POR", w.turn)
        raised = place(w, self.pikes, "POR", self.home, moves=0)
        reason = w.stuck_reason([raised])
        self.assertNotIn("foraged", reason)
        self.assertIn("raised this season", reason)

    def test_a_stack_that_foraged_says_so(self):
        w = self.w
        target = next(p for p in w.provinces_of("CAS") if not w.units_at(p.pos))
        a = place(w, self.pikes, "POR", target.pos, moves=0)
        b = place(w, troop("cavalry", 1), "POR", target.pos, moves=0)
        self.assertTrue(w.forage([a, b], end_of_round=True))
        self.assertIn("foraged", w.stuck_reason([a, b]))

    def test_two_raised_units_of_one_kind_are_counted(self):
        w = self.w
        a = place(w, self.pikes, "POR", self.home, moves=0)
        b = place(w, self.pikes, "POR", self.home, moves=0)
        reason = w.stuck_reason([a, b])
        self.assertIn(f"2 {self.pikes.name} were raised this season", reason)
        self.assertNotIn(f"{self.pikes.name} was raised", reason)

    def test_one_raised_unit_does_not_say_was_with_a_plural_name(self):
        w = self.w
        a = place(w, self.pikes, "POR", self.home, moves=0)
        reason = w.stuck_reason([a])
        self.assertIn(f"{self.pikes.name} raised this season", reason)
        self.assertNotIn("was raised", reason)


class BannerTest(unittest.TestCase):
    def test_an_empty_banner_is_skipped(self):
        app = CampaignApp(player="POR")
        app.banner("")


class ManualOrderTest(unittest.TestCase):
    """A manual order cancels the move orders of the units that acted, not of the unticked ones in the stack."""

    def setUp(self):
        self.app = CampaignApp(player="POR")
        self.w = self.app.world
        self.target, self.home = front(self.w)
        self.far = next(p for p in self.w.terrain if self.w.is_land(p) and p not in (self.home, self.target.pos))

    def test_forage_with_one_ticked_unit_keeps_the_others_goal(self):
        w, app = self.w, self.app
        a = place(w, troop("cavalry", 1), "POR", self.target.pos)
        b = place(w, troop("infantry", 1), "POR", self.target.pos)
        a.goal = b.goal = self.far
        app.ui.group, app.ui.picked, app.ui.selected = [a, b], {a.id}, a
        app.refresh()
        app.press(("forage",))
        self.assertEqual(a.moves_left, 0, "the forage went through")
        self.assertIsNone(a.goal)
        self.assertEqual(b.goal, self.far, "the unticked unit keeps its march")


STALL = (148, 43)                           # a Swiss hex whose only way on to the Gotthard is the closed pass in winter


class MarchAtPassTest(unittest.TestCase):
    """A march stopped by a pass closed in winter is kept, and resumes in spring."""

    def setUp(self):
        self.app = CampaignApp(player="SWI")
        self.w = self.app.world
        self.w.units = [u for u in self.w.units if u.pos not in (STALL, GOTTHARD)]

    def test_the_march_waits_at_the_closed_pass_and_says_so_once(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = WINTER
        mark = len(w.log)
        app._advance_orders()
        self.assertEqual(unit.goal, GOTTHARD, "the march is kept")
        self.assertEqual(unit.pos, STALL)
        notes = [m for m in w.log[mark:] if "waits for spring" in m]
        self.assertEqual(notes, ["The Gotthard pass is closed by snow; the march waits for spring."])
        self.assertIn("waits for spring", app.ui.toast)
        app._advance_orders()
        self.assertEqual(len([m for m in w.log[mark:] if "waits for spring" in m]), 1, "no repeated line")
        self.assertEqual(unit.goal, GOTTHARD)

    def test_the_march_resumes_in_spring(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = WINTER
        app._advance_orders()
        w.turn = SUMMER
        app._advance_orders()
        self.assertEqual(unit.pos, GOTTHARD)
        self.assertIsNone(unit.goal, "arrived, so the order is done")


class MarketNumberTest(unittest.TestCase):
    def test_each_market_gets_its_index(self):
        w = CampaignWorld(1480, map="europe")
        w.ensure_markets()
        view = MapView(w)
        for i, market in enumerate(w.markets):
            self.assertEqual(view._market_number(market), i)

    def test_a_market_not_in_the_world_gives_none(self):
        w = CampaignWorld(1480, map="europe")
        w.ensure_markets()
        view = MapView(w)
        stray = Market(name="stray", point=(0, 0), colonial=False)
        self.assertIsNone(view._market_number(stray))


if __name__ == "__main__":
    unittest.main()
