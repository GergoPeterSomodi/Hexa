"""Mountain passes closed by snow in winter (campaign world rule): pass_closed, move_check, movement, routes, AI
pathing, ships, random worlds, and the app's reason and grid toggle. Headless. Run with:
    python -m unittest tests.test_passes"""
import os
import shutil
import tempfile
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

from hexa.campaign import ai, geo  # noqa: E402
from hexa.campaign.app import CampaignApp  # noqa: E402
from hexa.campaign.data import CARAVEL, troop  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402
from hexa.hexgrid import neighbors  # noqa: E402

GOTTHARD = geo.hex_of(8.56, 46.56)          # (149, 44) on the Europe map
SOUTH_OF = (149, 45)                        # the hex south of the Gotthard, owned by MLO in the data
NORTH_OF = (149, 43)                        # the hex north of it (Switzerland)
SUMMER, WINTER = 2, 4                       # data.date: turn 4 is Winter, turn 2 is Summer
REASON = "The Gotthard pass is closed by snow until spring."


def fresh(seed=1480, map="europe"):
    """A new world (the snapshot cache makes this cheap); safe to mutate."""
    return CampaignWorld(seed, map=map)


def infantry(world, pos, owner="SWI", moves=None):
    kind = troop("infantry", 1)
    return world._add_unit(kind, owner, pos, moves=kind.moves if moves is None else moves)


class PassRuleTest(unittest.TestCase):
    def test_gotthard_is_closed_in_winter_only(self):
        w = fresh()
        self.assertEqual(w.pass_name(GOTTHARD), "Gotthard")
        w.turn = WINTER
        self.assertTrue(w.winter())
        self.assertTrue(w.pass_closed(GOTTHARD))
        w.turn = SUMMER
        self.assertFalse(w.winter())
        self.assertFalse(w.pass_closed(GOTTHARD))
        self.assertTrue(w.pass_closed(GOTTHARD, winter=True))      # an explicit season overrides the turn

    def test_the_geography_passes_are_land_hexes(self):
        w = fresh()
        names = set(w.passes().values())
        for name in ("Gotthard", "Brenner", "Mont Cenis", "Simplon", "Great St Bernard", "Roncesvalles"):
            self.assertIn(name, names)
        for pos in w.passes():
            self.assertTrue(w.is_land(pos), pos)

    def test_land_unit_cannot_step_onto_it_in_winter_and_is_told_why(self):
        w = fresh()
        w.turn = WINTER
        unit = infantry(w, NORTH_OF)
        self.assertEqual(w.move_check([unit], GOTTHARD), (False, REASON))
        self.assertFalse(w.may_enter(unit, GOTTHARD))
        self.assertNotIn(GOTTHARD, w.reachable(unit))
        self.assertNotIn(GOTTHARD, w.plan([unit], 99))
        self.assertFalse(w.move_group([unit], GOTTHARD))
        self.assertEqual(unit.pos, NORTH_OF)

    def test_land_unit_can_step_onto_it_in_summer(self):
        w = fresh()
        w.turn = SUMMER
        unit = infantry(w, NORTH_OF, moves=99)
        self.assertEqual(w.move_check([unit], GOTTHARD), (True, ""))
        self.assertTrue(w.may_enter(unit, GOTTHARD))
        self.assertIn(GOTTHARD, w.plan([unit], 99))
        self.assertTrue(w.move_group([unit], GOTTHARD))
        self.assertEqual(unit.pos, GOTTHARD)

    def test_unit_already_on_the_pass_may_leave_in_winter(self):
        w = fresh()
        w.turn = WINTER
        unit = infantry(w, GOTTHARD, moves=99)
        self.assertIn(NORTH_OF, w.plan([unit], 99))
        self.assertTrue(w.move_group([unit], NORTH_OF))
        self.assertEqual(unit.pos, NORTH_OF)

    def test_route_goes_around_the_pass_in_winter(self):
        w = fresh()
        w.provinces[SOUTH_OF].owner = "SWI"             # so both sides are open to the unit
        w.turn = WINTER
        unit = infantry(w, NORTH_OF, moves=99)
        path = w.route([unit], SOUTH_OF)
        self.assertEqual(path[0], NORTH_OF)
        self.assertEqual(path[-1], SOUTH_OF)
        self.assertNotIn(GOTTHARD, path)
        for a, b in zip(path, path[1:]):
            self.assertIn(b, neighbors(a))

    def test_ai_pathing_never_ends_a_move_on_the_pass_in_winter(self):
        w = fresh()
        w.turn = WINTER
        unit = infantry(w, NORTH_OF, moves=99)
        for goal in (SOUTH_OF, (149, 46), (150, 46)):
            step = w.step_toward_group([unit], goal)
            self.assertNotEqual(step, GOTTHARD, goal)
        before = {u.id: u.pos for u in w.units if not u.naval and u.pos in w.passes()}
        for tag in ("SWI", "MLO", "SAV", "FRA"):
            if tag in w.countries:
                ai.run(w, tag)
        for u in w.units:
            if not u.naval and u.pos in w.passes():
                self.assertIn(u.id, before, f"{u.owner} moved a unit onto the {w.pass_name(u.pos)} pass in winter")

    def test_ships_are_not_affected(self):
        w = fresh()
        w.turn = WINTER
        ship = w._add_unit(CARAVEL, "SWI", (10, 0), moves=CARAVEL.moves)
        self.assertEqual(w.move_check([ship], (11, 0)), (True, ""))
        self.assertTrue(w.may_enter(ship, (11, 0)))
        self.assertIn((11, 0), w.plan([ship], 3))

    def test_random_worlds_do_not_crash(self):
        for seed in (5, 9):
            w = fresh(seed, map="random")
            land = [p for p in w.terrain if w.is_land(p)][:40]
            for turn in (WINTER, SUMMER):
                w.turn = turn
                self.assertIsInstance(w.passes(), dict)
                for pos in land:
                    self.assertEqual(w.pass_closed(pos), turn == WINTER and pos in w.passes())
                unit = infantry(w, land[0], owner=next(iter(w.countries)))
                w.plan([unit], 12)
                w.move_check([unit], land[1])


class AppTest(unittest.TestCase):
    """The app's reason on a closed pass, the hover card, and the G key."""

    @classmethod
    def setUpClass(cls):
        pygame.init()

    def setUp(self):
        self.home_dir = tempfile.mkdtemp(prefix="hexa_passes_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home_dir
        self.app = CampaignApp(player="SWI")

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home_dir, ignore_errors=True)

    def test_hover_card_says_closed_in_winter(self):
        app = self.app
        app.world.turn = WINTER
        lines = app.province_card(GOTTHARD)[1]
        self.assertIn("Closed by snow until spring", [text for text, _ in lines])
        app.world.turn = SUMMER
        lines = app.province_card(GOTTHARD)[1]
        self.assertNotIn("Closed by snow until spring", [text for text, _ in lines])

    def test_right_click_on_closed_pass_gives_the_reason_and_does_not_move(self):
        app, w = self.app, self.app.world
        w.turn = WINTER
        unit = infantry(w, NORTH_OF, moves=99)
        w.changed()
        app.select_unit(unit)
        cx, cy = app.view.center(GOTTHARD)
        vr = app.view_rect()
        app.right_click((vr.x + cx - app.camera[0], vr.y + cy - app.camera[1]))
        self.assertEqual(app.ui.toast, REASON)
        self.assertEqual(unit.pos, NORTH_OF)

    def test_g_key_toggles_the_grid_and_it_is_saved(self):
        app = self.app
        start = app.settings["grid"]
        app.handle(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_g, mod=0, unicode="g", scancode=0))
        self.assertEqual(app.settings["grid"], not start)
        app.handle(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_g, mod=0, unicode="g", scancode=0))
        self.assertEqual(app.settings["grid"], start)


if __name__ == "__main__":
    unittest.main()
