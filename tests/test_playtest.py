"""Fixes from the 2026-11-11 playtest of Age of Discovery: log grammar, provinces under a single army, stacks
that cannot move, the trade-order buttons, the game-over banner and the invest label.

Run with:  python -m unittest tests.test_playtest
"""
import os
import shutil
import tempfile
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame  # noqa: E402

from hexa.campaign import app as appmod  # noqa: E402
from hexa.campaign.app import CampaignApp, _ordinal  # noqa: E402
from hexa.campaign.data import GENERAL, WORKS, troop  # noqa: E402
from hexa.campaign.world import CampaignWorld, _with_article  # noqa: E402
from hexa.hexgrid import neighbors  # noqa: E402


def place(w, kind, tag, pos, moves=None):
    """One unit of `kind`; by default it has its full moves (a unit raised this season has none)."""
    return w._add_unit(kind, tag, pos, moves=kind.moves if moves is None else moves)


def front(w):
    """A Castilian province without units next to Portuguese land: (target, home)."""
    for prov in w.provinces_of("CAS"):
        if prov.castle or w.units_at(prov.pos):
            continue
        for n in neighbors(prov.pos):
            if w.provinces.get(n) and w.provinces[n].owner == "POR" and not w.units_at(n):
                return prov, n
    raise AssertionError("no front")


class LogGrammarTest(unittest.TestCase):
    def test_the_article_follows_the_name(self):
        self.assertEqual(_with_article("Armoury"), "an armoury")
        self.assertEqual(_with_article("Weaver"), "a weaver")
        self.assertEqual(_with_article("Small castle"), "a small castle")

    def test_investing_never_says_a_open(self):
        w = CampaignWorld(player="POR")
        prov = next(p for p in w.provinces_of("POR") if p.good in WORKS and p.controller == "POR")
        w.countries["POR"].treasury = 10 ** 6
        w.countries["POR"].era = 3
        prov.busy = False
        prov.works = 0
        self.assertTrue(w.invest("POR", prov))
        message = w.log[-1]
        self.assertNotIn(" a ", message)
        self.assertIn(w.works_name(prov).lower(), message)
        self.assertIn(f"{prov.name}: upgraded to", message)


class ProvinceControlTest(unittest.TestCase):
    """A province holds the side whose army stands in it, until a battle or a siege says otherwise."""

    def setUp(self):
        self.w = CampaignWorld(player="POR")
        self.w.units = [u for u in self.w.units if not u.kind.war and u.kind is not GENERAL]
        self.w.declare_war("POR", "CAS")
        self.target, self.home = front(self.w)
        self.target.owner = self.target.controller = "CAS"
        self.target.castle, self.target.garrison = 0, 0

    def test_one_army_takes_the_province_and_keeps_it(self):
        w, target = self.w, self.target
        place(w, troop("infantry", 1), "POR", target.pos)
        place(w, troop("infantry", 1), "POR", target.pos)
        for _ in range(10):
            w.sieges()
        self.assertEqual(target.controller, "POR")
        mark = len(w.log)
        for _ in range(30):
            w.sieges()
            self.assertEqual(target.controller, "POR", "control must not flip while our army stands there")
        self.assertFalse([m for m in w.log[mark:] if "took control" in m])

    def test_two_armies_on_one_hex_make_no_siege_progress(self):
        w, target = self.w, self.target
        place(w, troop("infantry", 1), "POR", target.pos)
        place(w, troop("infantry", 1), "CAS", target.pos)
        mark = len(w.log)
        for _ in range(10):
            w.sieges()
        self.assertEqual(target.controller, "CAS")
        self.assertEqual(target.siege, 0)
        self.assertFalse([m for m in w.log[mark:] if "took control" in m])


class StackReasonTest(unittest.TestCase):
    def setUp(self):
        self.w = CampaignWorld(player="POR")
        self.w.units = [u for u in self.w.units if u.owner != "POR"]
        self.home = self.w.provinces_of("POR")[0].pos
        self.w.units = [u for u in self.w.units if u.pos != self.home]
        self.knights = place(self.w, troop("cavalry", 1), "POR", self.home, moves=0)
        self.pikes = place(self.w, troop("infantry", 1), "POR", self.home)
        self.neighbour = next(n for n in neighbors(self.home) if self.w.is_land(n))

    def test_a_raised_unit_holds_the_stack_and_the_reason_says_so(self):
        group = [self.knights, self.pikes]
        self.assertFalse(self.w.move_group(group, self.neighbour))
        reason = self.w.stuck_reason(group)
        self.assertIn(self.knights.kind.name, reason)
        self.assertIn("raised this season", reason)
        self.assertIn("Untick", reason)

    def test_the_reason_is_empty_when_the_stack_can_move(self):
        self.assertEqual(self.w.stuck_reason([self.pikes]), "")

    def test_a_stack_that_already_moved_says_so(self):
        self.pikes.moves_left, self.pikes.acted = 0, True
        self.assertEqual(self.w.stuck_reason([self.pikes]), "They have already moved this season.")


class ToastTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pygame.init()

    def setUp(self):
        self.home_dir = tempfile.mkdtemp(prefix="hexa_playtest_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home_dir
        self.app = CampaignApp(player="POR")

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home_dir, ignore_errors=True)

    def test_right_click_says_why_a_raised_stack_cannot_move(self):
        app, w = self.app, self.app.world
        home = w.provinces_of("POR")[0].pos
        target = next(n for n in neighbors(home) if w.is_land(n) and w.provinces.get(n)
                      and w.provinces[n].owner == "POR" and not w.units_at(n))
        knights = place(w, troop("cavalry", 1), "POR", home, moves=0)
        pikes = place(w, troop("infantry", 1), "POR", home)
        app.ui.group = [knights, pikes]
        app.ui.picked = {knights.id, pikes.id}
        app.ui.selected = pikes
        app.refresh()
        app.hex_under = lambda pixel: target
        app.right_click((0, 0))
        self.assertIn("raised this season and can't move yet", app.ui.toast)
        self.assertNotEqual(app.ui.toast, "They cannot get there.")


class TextFitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pygame.init()

    def test_fit_shortens_with_an_ellipsis(self):
        font = pygame.font.SysFont("segoeui,arial", 12)
        short = CampaignApp._fit(font, "Invest: Terraced vineyard", 70)
        self.assertLessEqual(font.size(short)[0], 70)
        self.assertTrue(short.endswith("…"))
        self.assertEqual(CampaignApp._fit(font, "Invest", 500), "Invest")


class OrdinalTest(unittest.TestCase):
    def test_ordinals(self):
        cases = {1: "1st", 2: "2nd", 3: "3rd", 4: "4th", 7: "7th", 11: "11th", 12: "12th", 13: "13th",
                 21: "21st", 22: "22nd", 112: "112th"}
        for n, text in cases.items():
            self.assertEqual(_ordinal(n), text)


class GameOverTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pygame.init()

    def setUp(self):
        self.home_dir = tempfile.mkdtemp(prefix="hexa_playtest_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home_dir
        self.app = CampaignApp(player="POR")
        self.app.world.over = True

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home_dir, ignore_errors=True)

    def test_the_banner_names_the_player_and_their_place(self):
        text = self.app.game_over_text()
        self.assertRegex(text, r"Portugal: \d+(st|nd|rd|th) of \d+, score \d+")
        self.assertIn("Final ranking:", text)

    def test_the_banner_wraps_inside_the_screen(self):
        w = 1280
        appmod.WIDTH = w
        lines = self.app._wrap_words(self.app.title, self.app.game_over_text(), w - 100)
        self.assertGreater(len(lines), 1)
        for line in lines:
            self.assertLessEqual(self.app.title.size(line)[0], w - 100)


if __name__ == "__main__":
    unittest.main()
