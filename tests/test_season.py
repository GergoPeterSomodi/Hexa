"""The season's phases (hexa/campaign/systems/season.py): their order is pinned. No pygame.

Run with: python -m unittest tests.test_season
"""
import unittest
from unittest import mock

from hexa.campaign.systems import season
from tests.support.worlds import fresh

ORDER = ["battles", "logistics", "sieges", "war_timeouts", "economy", "collect", "debt", "growth", "research", "extinction",
         "turn", "units", "exploration", "vision", "redraw", "report"]


class PhaseOrderTest(unittest.TestCase):
    def test_the_phases_are_named_in_the_documented_order(self):
        self.assertEqual([name for name, _ in season.PHASES], ORDER)

    def test_every_phase_is_a_function_of_the_world(self):
        for name, phase in season.PHASES:
            self.assertTrue(callable(phase), name)

    def test_end_round_runs_the_table_in_order(self):
        w = fresh("POR")
        calls = []
        table = tuple((name, lambda world, name=name: calls.append(name)) for name, _ in season.PHASES)
        with mock.patch.object(season, "PHASES", table):
            w.end_round()
        self.assertEqual(calls, ORDER)

    def test_the_real_phases_advance_the_turn_exactly_once_in_the_middle(self):
        w = fresh("POR")
        turn = w.turn
        seen = {}
        table = tuple((name, self._spy(name, phase, w, seen)) for name, phase in season.PHASES)
        with mock.patch.object(season, "PHASES", table):
            w.end_round()
        self.assertEqual(w.turn, turn + 1)
        self.assertEqual({name: t for name, t in seen.items() if t != turn},
                         {name: turn + 1 for name in ORDER[ORDER.index("turn") + 1:]} | {"turn": turn + 1})

    @staticmethod
    def _spy(name, phase, w, seen):
        def run(world):
            phase(world)
            seen[name] = world.turn
        return run

    def test_the_game_manager_runs_end_round_between_the_countries_and_the_orders(self):
        # the order of the manager's own steps is pinned in tests/test_game_manager.py; here only that it goes through
        # end_round, so the table is the only place the season's order is written
        from hexa.campaign.game import GameManager
        w = fresh("POR")
        names = []
        table = tuple((name, lambda world, name=name: names.append(name)) for name, _ in season.PHASES)
        with mock.patch.object(season, "PHASES", table):
            GameManager(w).end_season()
        self.assertEqual(names, ORDER)


if __name__ == "__main__":
    unittest.main()
