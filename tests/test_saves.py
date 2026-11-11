"""Save, load and settings tests (they use a temporary HEXA_HOME). Run with:
python -m unittest discover -s tests -t ."""
import json
import os
import pickle
import shutil
import tempfile
import unittest
from unittest import mock

from hexa import settings
from hexa.campaign import ai, saves
from hexa.campaign.data import GENERAL, troop
from hexa.campaign.world import CampaignWorld


class TempHome(unittest.TestCase):
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


class SaveTest(TempHome):
    def test_a_saved_game_comes_back_exactly(self):
        w = CampaignWorld(player="POR")
        for _ in range(2):
            for tag in w.countries:
                if tag != "POR":
                    ai.run(w, tag)
            w.end_round()
        w.countries["POR"].treasury = 1234.5
        meta = saves.save(w, "3")
        self.assertEqual(meta["country"], "Portugal")
        back = saves.load("3")
        self.assertEqual(back.turn, w.turn)
        self.assertEqual(back.player, "POR")
        self.assertEqual(back.countries["POR"].treasury, 1234.5)
        self.assertEqual({p: q.owner for p, q in back.provinces.items()}, {p: q.owner for p, q in w.provinces.items()})
        self.assertEqual(len(back.units), len(w.units))
        self.assertTrue(any(u.kind is GENERAL for u in back.units) == any(u.kind is GENERAL for u in w.units))
        self.assertTrue(all(u.kind is troop(u.kind.branch, u.kind.era) for u in back.units if u.kind.war),
                        "unit kinds are the game's own objects again")
        self.assertIs(back.geo, w.geo)
        # the loaded game keeps playing
        new = back._add_unit(troop("infantry", 1), "POR", back.countries["POR"].capital)
        self.assertNotIn(new.id, {u.id for u in w.units})
        back.end_round()
        self.assertEqual(back.turn, w.turn + 1)

    def test_random_worlds_save_too(self):
        w = CampaignWorld(9, player=None, map="random")
        tag = next(iter(w.countries))
        w.player = tag
        saves.save(w, "quick")
        back = saves.load("quick")
        self.assertEqual(back.terrain, w.terrain)
        self.assertEqual(back.geo.name, w.geo.name)

    def test_slots_listing_and_latest(self):
        self.assertIsNone(saves.latest())
        self.assertTrue(all(m is None for _, m in saves.listing()))
        w = CampaignWorld(player="ENG")
        saves.save(w, "1")
        saves.save(w, "auto")
        listed = dict(saves.listing())
        self.assertEqual(listed["1"]["tag"], "ENG")
        self.assertIsNone(listed["2"])
        self.assertIn(saves.latest(), ("1", "auto"))
        self.assertIsNone(saves.load("5"), "an empty slot loads nothing")
        with open(saves.path("6"), "wb") as f:
            f.write(b"not a save")
        self.assertIsNone(saves.load("6"), "a broken file loads nothing")
        self.assertIsNone(saves.meta("6"))


class OldAndBrokenSavesTest(TempHome):
    def _write(self, slot, state, version=saves.VERSION):
        os.makedirs(saves.folder(), exist_ok=True)
        meta = {"version": version, "slot": slot, "saved": 1.0, "date": "Spring 1480", "turn": 1,
                "map": "Europe 1480", "tag": "POR", "country": "Portugal", "treasury": 0}
        with open(saves.path(slot), "wb") as f:
            f.write(json.dumps(meta).encode("utf-8") + b"\n" + pickle.dumps(state))

    def test_a_removed_unit_kind_means_cant_load_not_a_crash(self):
        from hexa.campaign import data
        w = CampaignWorld(player="POR")
        saves.save(w, "2")
        gone = next(u.kind.key for u in w.units if u.kind.war)
        with mock.patch.dict(data.UNIT_KINDS):
            del data.UNIT_KINDS[gone]
            self.assertIsNone(saves.load("2"))
        self.assertIsNotNone(saves.load("2"), "the same save loads once the kind is back")

    def test_an_older_save_gets_defaults_for_newer_fields(self):
        w = CampaignWorld(player="POR")
        state = pickle.loads(pickle.dumps(w.save_state()))
        for key in ("over", "wars", "_castle_list", "_known_world"):
            state.pop(key, None)
        prov = next(iter(state["provinces"].values()))
        del prov.__dict__["queue"]
        del state["countries"]["POR"].__dict__["memory"]
        del state["units"][0].__dict__["supplies"]
        self._write("3", state)
        back = saves.load("3")
        self.assertIsNotNone(back)
        self.assertFalse(back.over)
        self.assertEqual(back.wars, [])
        self.assertEqual(back.provinces[prov.pos].queue, [])
        self.assertEqual(back.countries["POR"].memory, {})
        self.assertEqual(back.units[0].supplies, 0)
        back.end_round()                         # and the game plays on

    def test_saves_from_a_newer_version_are_refused(self):
        w = CampaignWorld(player="POR")
        self._write("4", w.save_state(), version=saves.VERSION + 1)
        self.assertIsNone(saves.meta("4"))
        self.assertIsNone(saves.load("4"))


class AppLoadingTest(TempHome):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        import pygame
        pygame.init()

    def test_a_failed_continue_does_not_start_another_game(self):
        from hexa.campaign.app import CampaignApp
        with self.assertRaises(saves.LoadError):
            CampaignApp(load="5")

    def test_f9_asks_first_then_loads_and_closes_the_menu(self):
        from hexa.campaign.app import CampaignApp
        app = CampaignApp(player="POR")
        app.toast = lambda text: setattr(app, "last_toast", text)
        app.quickload()
        self.assertIn("No quicksave", app.last_toast)
        saves.save(app.world, "quick")
        turn = app.world.turn
        app.world.end_round()
        app.open_menu("load")
        self.assertFalse(app.quickload(), "the first F9 only asks")
        self.assertEqual(app.world.turn, turn + 1)
        self.assertIn("F9 again", app.last_toast)
        self.assertTrue(app.quickload())
        self.assertEqual(app.world.turn, turn)
        self.assertIsNone(app.menu)
        app.world.end_round()
        self.assertFalse(app.quickload(), "the confirmation does not last forever")


class SettingsTest(TempHome):
    def test_defaults_cycle_and_persist(self):
        s = settings.load()
        self.assertEqual(s, settings.DEFAULTS)
        self.assertEqual(settings.cycle(s, "window"), "1600x900")
        settings.cycle(s, "fullscreen")
        settings.save(s)
        again = settings.load()
        self.assertTrue(again["fullscreen"])
        self.assertEqual(settings.window_size(again), (1600, 900))
        with open(os.path.join(self.home, "settings.json"), "w") as f:
            f.write('{"scroll": "warp", "autosave": "off"}')
        odd = settings.load()
        self.assertEqual(odd["scroll"], "normal", "unknown values fall back to the default")
        self.assertEqual(odd["autosave"], "off")


if __name__ == "__main__":
    unittest.main()
