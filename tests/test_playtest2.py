"""Second playtest of Age of Discovery (issues #88 to #92): tech prerequisites, the war alert, the research
display on the tech screen and in the country panel, the Yes/No quit dialog, and marches that wait for the
player's order at the end of a season. Headless. Run with:  python -m unittest tests.test_playtest2"""
import os
import shutil
import tempfile
import unittest
from unittest import mock

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa.campaign import ai, tech  # noqa: E402
from hexa.campaign import app as appmod  # noqa: E402
from hexa.campaign.app import CampaignApp  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402
from tests.test_passes import SUMMER, WINTER, infantry  # noqa: E402
from tests.test_review_fixes import GOTTHARD, STALL  # noqa: E402


def key_event(key):
    return pygame.event.Event(pygame.KEYDOWN, key=key, mod=0, unicode="", scancode=0)


def click(pos, button=1):
    return pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=button, pos=pos)


class Home(unittest.TestCase):
    """A temporary HEXA_HOME, so saves and settings never touch the real ones."""

    @classmethod
    def setUpClass(cls):
        pygame.init()

    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="hexa_pt2_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home, ignore_errors=True)


# ----------------------------------------------------------------- #88 prerequisites

class PrerequisiteTest(Home):
    def world_in_era_3(self):
        w = CampaignWorld(player="POR")
        w.countries["POR"].era = 3
        return w, w.countries["POR"]

    def test_unqueueing_a_prerequisite_takes_its_dependants_too(self):
        w, c = self.world_in_era_3()
        self.assertTrue(w.set_research("POR", "volley_fire"))
        self.assertEqual(c.researching, "drill_yards")
        self.assertEqual(c.queue, ["tercio", "volley_fire"])
        self.assertTrue(w.unqueue("POR", "tercio"))
        self.assertEqual(c.queue, [], "volley fire needs tercio, so it leaves the queue with it")
        self.assertEqual(c.researching, "drill_yards", "the research in progress is not touched")

    def test_a_queued_tech_never_starts_before_its_prerequisites(self):
        w, c = self.world_in_era_3()
        c.researching, c.queue = "", ["volley_fire"]          # tercio is neither known nor queued
        w._advance("POR")
        self.assertNotEqual(c.researching, "volley_fire")

    def test_the_queue_learns_every_path_in_prerequisite_order(self):
        w, c = self.world_in_era_3()
        w.set_research("POR", "volley_fire")
        for _ in range(60):
            c.research += 50000                 # plenty of points: every queued tech finishes in turn
            w._research()
            for key in c.techs:
                if key in tech.TECHS:
                    missing = [n for n in tech.TECHS[key].needs if n not in c.techs]
                    self.assertEqual(missing, [], f"{key} was learned before its prerequisites")
            if not c.researching and not c.queue:
                break
        self.assertIn("volley_fire", c.techs)

    def test_the_tech_screen_right_click_removes_the_dependants_too(self):
        app = CampaignApp(player="POR")
        c = app.world.countries["POR"]
        c.era = 3
        app.world.set_research("POR", "volley_fire")
        app.open_tech()
        app.draw()
        rect = next(r for r, action in app.tech_buttons if action == ("node", "tercio"))
        app.handle(click(rect.center, button=3))
        self.assertEqual(c.queue, [], "right-click on a prerequisite drops what needs it")

    def test_the_ai_only_starts_techs_whose_prerequisites_it_knows(self):
        w = CampaignWorld(player="POR")
        for tag, c in w.countries.items():
            if tag == "POR" or not c.alive:
                continue
            c.researching, c.queue = "", []
            c.memory.setdefault("seed", 1)
            ai._research(w, tag)
            if c.researching:
                t = tech.TECHS.get(c.researching)
                self.assertIsNotNone(t)
                self.assertLessEqual(t.era, c.era)
                self.assertTrue(all(n in c.techs for n in t.needs),
                                f"{tag} researches {c.researching} before its prerequisites")


# ----------------------------------------------------------------- #89 war alert

class WarAlertTest(Home):
    def neighbour_of_portugal(self, w):
        return sorted(t for t in w.neighbours_of("POR") if t != "POR" and w.countries[t].alive)[0]

    def test_a_war_declared_on_the_player_opens_an_alert_and_logs_a_line(self):
        app = CampaignApp(player="POR")
        w = app.world
        enemy = self.neighbour_of_portugal(w)
        before = app._war_keys()
        self.assertTrue(w.declare_war(enemy, "POR"))
        app._announce_wars(before)
        self.assertEqual(app.menu, "question", "the alert is a pause-style box")
        self.assertIn(f"{w.countries[enemy].name} declared war on you", " ".join(w.log))
        self.assertIn(w.countries[enemy].name, app.menu_question[1][0])
        app.draw()
        self.assertTrue(app.menu_rect is not None, "the alert is drawn")

    def test_a_war_the_player_declares_does_not_alert(self):
        app = CampaignApp(player="POR")
        w = app.world
        enemy = self.neighbour_of_portugal(w)
        before = app._war_keys()
        w.declare_war("POR", enemy)
        app._announce_wars(before)
        self.assertIsNone(app.menu)

    def test_the_end_of_a_season_raises_the_alert(self):
        app = CampaignApp(player="POR")
        w = app.world
        enemy = self.neighbour_of_portugal(w)

        def ai_run(world, tag):
            if tag == enemy:
                world.declare_war(enemy, "POR")
        with mock.patch.object(appmod.ai, "run", side_effect=ai_run):
            app.end_turn()
        self.assertEqual(app.menu, "question")
        self.assertIn("declared war on you", " ".join(w.log))

    def test_the_country_panel_shows_who_declared_the_war(self):
        app = CampaignApp(player="POR")
        w = app.world
        enemy = self.neighbour_of_portugal(w)
        w.declare_war(enemy, "POR")
        self.assertIn("declared war on you", app._war_line(enemy))
        app.open_country(enemy)
        app.draw()                                  # draws without error with the war on screen


# ----------------------------------------------------------------- #90 research shown

class UnknownTechTest(Home):
    """A save or a renamed tech whose key is no longer in the tree must not crash the screens."""

    def test_an_unknown_research_key_shows_the_raw_key(self):
        app = CampaignApp(player="POR")
        c = app.world.countries["POR"]
        c.researching = "gone_tech"
        self.assertIn("gone_tech", app.research_line())

    def test_the_country_panel_draws_with_an_unknown_queued_key(self):
        app = CampaignApp(player="POR")
        c = app.world.countries["POR"]
        c.researching, c.queue = "", ["gone_tech"]
        app.open_country("POR")
        app.draw()


class WarWaitTest(Home):
    def test_the_war_alert_waits_for_the_idea_card(self):
        app = CampaignApp(player="POR")
        w = app.world
        c = w.countries["POR"]
        enemy = sorted(t for t in w.neighbours_of("POR") if t != "POR" and w.countries[t].alive)[0]
        c.pending_ideas = [next(iter(tech.IDEAS))]
        before = app._war_keys()
        w.declare_war(enemy, "POR")
        app._announce_wars(before)
        self.assertIsNone(app.menu, "no alert over the idea card")
        self.assertIn("declared war on you", " ".join(w.log))
        c.pending_ideas = []
        app._show_war_news()
        self.assertEqual(app.menu, "question", "the alert shows once the card is chosen")


class ResearchShowTest(Home):
    def test_the_tech_grid_numbers_the_current_tech_and_the_queue(self):
        app = CampaignApp(player="POR")
        c = app.world.countries["POR"]
        c.era = 3
        app.world.set_research("POR", "volley_fire")
        self.assertEqual(app.tech_order(), {"drill_yards": 0, "tercio": 1, "volley_fire": 2})

    def test_the_current_research_and_queue_are_named_outside_the_tech_screen(self):
        app = CampaignApp(player="POR")
        c = app.world.countries["POR"]
        c.era = 3
        app.world.set_research("POR", "volley_fire")
        line = app.research_line()
        self.assertIn("Drill yards", line)
        self.assertIn("2 queued", line)
        app.open_country("POR")
        app.draw()                                  # the country panel shows the research without error


# ----------------------------------------------------------------- #91 quit dialog

class QuitDialogTest(Home):
    def test_exit_asks_yes_or_no_first(self):
        app = CampaignApp(player="POR")
        app.open_menu()
        app.menu_press(("exit",))
        self.assertTrue(app.running, "one click does not quit")
        self.assertEqual(app.menu, "question")
        app.menu_press(("page", "main"))                    # No
        self.assertEqual(app.menu, "main")
        self.assertTrue(app.running)

    def test_yes_quits(self):
        app = CampaignApp(player="POR")
        app.open_menu()
        app.menu_press(("exit",))
        app.menu_press(("exit_now",))                       # Yes
        self.assertFalse(app.running)
        self.assertEqual(app.result, "quit")

    def test_main_menu_asks_too(self):
        app = CampaignApp(player="POR")
        app.open_menu()
        app.menu_press(("menu",))
        self.assertTrue(app.running)
        self.assertEqual(app.menu, "question")
        app.menu_press(("menu_now",))
        self.assertFalse(app.running)
        self.assertEqual(app.result, "menu")

    def test_escape_on_the_question_goes_back_to_the_pause_menu(self):
        app = CampaignApp(player="POR")
        app.open_menu()
        app.menu_press(("exit",))
        app.menu_key(pygame.K_ESCAPE)
        self.assertEqual(app.menu, "main")
        self.assertTrue(app.running)

    def test_without_a_game_exit_does_not_ask(self):
        app = CampaignApp()
        app.open_menu()
        app.menu_press(("exit",))
        self.assertFalse(app.running)

    def test_the_dialog_is_drawn_with_yes_and_no(self):
        app = CampaignApp(player="POR")
        app.open_menu()
        app.menu_press(("exit",))
        app.draw()
        actions = [action for _, action, _ in app.menu_buttons]
        self.assertIn(("exit_now",), actions)
        self.assertIn(("page", "main"), actions)


# ----------------------------------------------------------------- #92 marches

class MarchTest(Home):
    def setUp(self):
        super().setUp()
        self.app = CampaignApp(player="SWI")
        self.w = self.app.world
        self.w.units = [u for u in self.w.units if u.pos not in (STALL, GOTTHARD)]

    def test_the_end_of_a_season_keeps_the_march_where_it_is(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        app._advance_orders()
        self.assertEqual(unit.pos, STALL, "the stack does not move on its own")
        self.assertEqual(unit.goal, GOTTHARD, "the order is kept")

    def test_continue_march_moves_the_stack_on(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        app.continue_march([unit])
        self.assertEqual(unit.pos, GOTTHARD)
        self.assertIsNone(unit.goal, "arrived, so the order is done")

    def test_continue_with_no_moves_left_keeps_the_order(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI", moves=0)
        unit.goal = GOTTHARD
        w.turn = SUMMER
        app.continue_march([unit])
        self.assertEqual(unit.pos, STALL)
        self.assertEqual(unit.goal, GOTTHARD, "a stack that moved this season waits for the next one")

    def test_the_planned_route_runs_from_the_stack_to_its_goal(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        routes = app.march_routes()
        self.assertEqual(len(routes), 1)
        route = routes[0]
        self.assertEqual(route[0], STALL)
        self.assertEqual(route[-1], GOTTHARD)

    def test_the_march_waits_at_the_closed_pass_and_says_so_once_a_season(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = WINTER
        mark = len(w.log)
        for _ in range(2):                      # two presses in the same winter
            app.ui.toast = ""
            app.continue_march([unit])
            self.assertIn("waits for spring", app.ui.toast, "every blocked press says so")
        self.assertEqual(unit.goal, GOTTHARD)
        self.assertEqual(unit.pos, STALL)
        notes = [m for m in w.log[mark:] if "waits for spring" in m]
        self.assertEqual(len(notes), 1, "the log line comes once a season")

    def test_the_closed_pass_is_announced_again_in_the_next_winter(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = WINTER
        mark = len(w.log)
        app.continue_march([unit])
        w.turn = WINTER + 4                     # the next winter, a stack that never moved
        app.ui.toast = ""
        app.continue_march([unit])
        self.assertIn("waits for spring", app.ui.toast)
        notes = [m for m in w.log[mark:] if "waits for spring" in m]
        self.assertEqual(len(notes), 2, "one line per winter, not one per stack ever")

    def test_the_planned_route_changes_with_the_season(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        summer = app.march_routes()
        self.assertTrue(summer, "a route in summer")
        w.turn = WINTER
        winter = app.march_routes()
        self.assertNotEqual(winter, summer, "the closed pass is not on the route in winter")
        w.turn = SUMMER + 4
        self.assertEqual(app.march_routes(), summer, "the route comes back when the pass opens")

    def test_r_continues_the_selected_march(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        app.ui.group, app.ui.picked, app.ui.selected = [unit], {unit.id}, unit
        app.refresh()
        app.handle(key_event(pygame.K_r))
        self.assertEqual(unit.pos, GOTTHARD)

    def test_c_still_opens_the_country_panel_with_a_march_selected(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        app.ui.group, app.ui.picked, app.ui.selected = [unit], {unit.id}, unit
        app.refresh()
        app.handle(key_event(pygame.K_c))
        self.assertEqual(app.ui.panel, "country")
        self.assertEqual(unit.pos, STALL, "C does not move the march")

    def test_tab_reaches_a_stack_on_a_march(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        for other in w.units_of("SWI"):
            if other is not unit:
                other.moves_left = 0
        app.ui.group, app.ui.picked, app.ui.selected = [], set(), None
        app.refresh()
        app.handle(key_event(pygame.K_TAB))
        self.assertIs(app.ui.selected, unit, "the marching stack is in the Tab cycle")

    def test_the_unit_panel_has_a_continue_march_button(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="SWI")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        app.ui.group, app.ui.picked, app.ui.selected = [unit], {unit.id}, unit
        app.ui.panel = "unit"
        app.refresh()
        app.draw()
        self.assertIn(("continue",), [b.action for b in app.ui.buttons])

    def test_the_ai_is_not_affected(self):
        w, app = self.w, self.app
        unit = infantry(w, STALL, owner="CAS")
        unit.goal = GOTTHARD
        w.turn = SUMMER
        app._advance_orders()
        self.assertEqual(unit.pos, STALL)


if __name__ == "__main__":
    unittest.main()
