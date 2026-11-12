"""The game manager (hexa/campaign/game.py): new, load, save, autosave and the order of end_season(). No pygame.

Run with: python -m unittest tests.test_game_manager
"""
import contextlib
import io
import os
import unittest
from unittest import mock

from hexa.campaign import ai, saves
from hexa.campaign.game import GameManager, SeasonResult
from hexa.campaign.world import CampaignWorld
from tests.support.home import TempHome
from tests.support.worlds import fresh, play_seasons


class SeasonOrderTest(TempHome):
    def test_the_phases_run_in_the_documented_order(self):
        w = fresh("POR")
        game = GameManager(w)
        calls = []
        tags = [t for t in w.countries if t != "POR"]
        with mock.patch.object(w, "settle_preview", side_effect=lambda: calls.append("settle")), \
                mock.patch.object(ai, "run", side_effect=lambda world, tag: calls.append(("ai", tag))), \
                mock.patch.object(w, "end_round", side_effect=lambda: calls.append("end_round")), \
                mock.patch.object(w, "ensure_markets", side_effect=lambda: calls.append("markets")), \
                mock.patch.object(game, "autosave", side_effect=lambda: calls.append("autosave") or False):
            result = game.end_season(orders=lambda: calls.append("orders"))
        self.assertEqual(calls, ["settle"] + [("ai", t) for t in tags]
                         + ["end_round", "orders", "autosave", "markets"])
        self.assertEqual(result, SeasonResult(False, None))
        self.assertEqual(w.bus.history[-1].kind, "season_ended")

    def test_the_players_own_country_is_left_alone_unless_asked(self):
        w = fresh("POR")
        ran = []
        with mock.patch.object(ai, "run", side_effect=lambda world, tag: ran.append(tag)):
            GameManager(w).end_season()
            self.assertNotIn("POR", ran)
            ran.clear()
            GameManager(w).end_season(player_ai=True)
            self.assertIn("POR", ran)

    def test_a_season_advances_the_turn_and_matches_the_plain_loop(self):
        a, b = fresh("POR"), fresh("POR")
        play_seasons(a, 2, player_ai=False)
        for _ in range(2):
            b.settle_preview()
            for tag in list(b.countries):
                if tag != b.player:
                    ai.run(b, tag)
            b.end_round()
            b.ensure_markets()
        self.assertEqual((a.turn, a.log), (b.turn, b.log))
        self.assertEqual(a.turn, 3)

    def test_the_events_of_a_season(self):
        w = fresh("POR")
        w.bus.clear()
        GameManager(w).end_season()
        kinds = [e.kind for e in w.bus.history]
        self.assertEqual(kinds[-1], "season_ended")
        self.assertEqual(w.bus.history[-1].get("turn"), w.turn)
        self.assertIn("message", kinds, "end_round logs the date line")
        self.assertEqual(kinds.count("season_ended"), 1)


class AutosaveTest(TempHome):
    def test_the_autosave_is_written_when_due(self):
        w = fresh("POR")
        w.turn = 4                                  # the round ends into turn 5: "every 4" saves on 1, 5, 9...
        game = GameManager(w, autosave_every=4)
        result = game.end_season()
        self.assertEqual(result, SeasonResult(True, None))
        meta = saves.meta("auto")
        self.assertEqual(meta["turn"], 5)

    def test_no_autosave_when_off_or_not_due(self):
        w = fresh("POR")
        GameManager(w, autosave_every=0).end_season()
        self.assertFalse(os.path.exists(saves.path("auto")))
        w2 = fresh("POR")
        w2.turn = 2
        self.assertEqual(GameManager(w2, autosave_every=4).end_season(), SeasonResult(False, None))
        self.assertFalse(os.path.exists(saves.path("auto")))

    def test_a_failed_autosave_is_reported_not_raised(self):
        w = fresh("POR")
        w.turn = 4
        game = GameManager(w, autosave_every=4)
        with mock.patch.object(saves, "save", side_effect=OSError("disk full")), \
                contextlib.redirect_stderr(io.StringIO()):
            result = game.end_season()
        self.assertFalse(result.saved)
        self.assertIsInstance(result.error, OSError)
        self.assertEqual(w.turn, 5, "the season still ended")

    def test_the_autosave_holds_the_orders_hook_s_log_line(self):
        w = fresh("POR")
        w.turn = 4
        GameManager(w, autosave_every=4).end_season(orders=lambda: w.message("march waits", "POR"))
        self.assertIn("march waits", saves.load("auto").log)


class NewSaveLoadTest(TempHome):
    def test_new_save_and_load(self):
        game = GameManager.new(player="POR")
        self.assertIsInstance(game.world, CampaignWorld)
        self.assertIs(game.bus, game.world.bus)
        game.save("1")
        again = GameManager.load("1")
        self.assertEqual((again.world.player, again.world.turn), ("POR", 1))
        self.assertIsNot(again.bus, game.bus)

    def test_load_of_an_empty_slot_is_none(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertIsNone(GameManager.load("7"))


if __name__ == "__main__":
    unittest.main()
