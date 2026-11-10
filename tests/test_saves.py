"""Save, load and settings tests (they use a temporary HEXA_HOME). Run with:
python -m unittest discover -s tests -t ."""
import os
import shutil
import tempfile
import unittest

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
