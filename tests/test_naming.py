"""Province names (GitHub #68): historical regions and real places on the Europe map, unique names everywhere.
Run with:  python -m unittest tests.test_naming"""
import os
import pickle
import re
import subprocess
import sys
import unittest

from hexa.campaign import geo, naming, placenames, regions, saves
from hexa.campaign.data import troop
from hexa.campaign.world import CampaignWorld
from tests.support.home import TempHome
from tests.support.worlds import europe, fresh, pristine, random_world

WORLD = europe()
_PRISTINE = pristine(WORLD, "the shared WORLD")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Soviet and modern roots, and names founded after 1480 that the data once held.
SOVIET = re.compile(r"(^|[\s\-])(Krasno|Sovet|Kirov|Kalinin|Lenin|Proletar|Oktyabr|Pervomay|Komsomol|Dzerzhin|Imeni|"
                    r"Novo[a-z]|Karlsk|Karlsh|Wilhelms|Bremerh)", re.I)
MODERN = set("""Karlskrona Karlshamn Karlsruhe Wilhelmshaven Bremerhaven Petrozavodsk Simferopol Tiraspol Saransk
Michurinsk Lipetsk Obninsk Dzerzhinsk Orekhovo-Zuyevo Volzhsky Volgodonsk Novomoskovsk Novovoronezh Soligorsk Kirov
Kirovsk Kalininsk Proletarsk Krasnoarmeysk Sovetskaya Dniprorudne Pivdennoukrainsk Zelenodolsk Svitlovodsk
Kamennogorsk Priozërsk Polessk Gvardeysk Krasnoznamensk Şanlıurfa Alexandroupoli Izoplit Katowice Kattowitz Tilsit
Pillau Libau Czernowitz Istanbul Kaliningrad Petersburg Volgograd Odessa Odesa""".split()) | {"Nova Gorica"}


def tearDownModule():
    _PRISTINE.check()


def at(lon, lat):
    return WORLD.provinces[geo.hex_of(lon, lat)]


class EuropeNamesTest(unittest.TestCase):
    def test_every_name_is_unique(self):
        names = [p.name for p in WORLD.provinces.values()]
        self.assertEqual(len(set(names)), len(names), f"{len(names) - len(set(names))} duplicate names")

    def test_no_near_names_left(self):
        for p in WORLD.provinces.values():
            self.assertFalse(p.name.startswith("near "), p.name)
            self.assertNotIn("countryside", p.name)

    def test_few_names_carry_a_number(self):
        numbered = [p.name for p in WORLD.provinces.values() if re.search(r" \d+\)$", p.name)]
        self.assertLess(len(numbered) / len(WORLD.provinces), 0.10)
        self.assertTrue(all(int(re.search(r" (\d+)\)$", n).group(1)) <= 9 for n in numbered), "no number above 9")

    def test_every_province_has_a_region(self):
        self.assertTrue(all(p.region for p in WORLD.provinces.values()))
        self.assertGreaterEqual(len(regions.REGIONS), 300)

    def test_known_hexes(self):
        braga = at(-8.42, 41.55)
        self.assertEqual((braga.name, braga.region), ("Braga", "Minho"))
        self.assertEqual(WORLD.place(braga), "Braga (Minho)")
        self.assertEqual(at(-8.61, 41.15).region, "Douro")           # Porto's hex
        self.assertEqual(at(-9.14, 38.72).region, "Estremadura")     # Lisbon
        self.assertEqual(at(2.17, 41.39).region, "Catalonia")
        self.assertEqual(at(-99.13, 19.43).name, "Tenochtitlan")
        self.assertEqual(at(28.97, 41.01).name, "Constantinople")

    def test_cities_sit_in_the_right_region(self):
        for city, region in regions.CITY_REGION.items():
            pos = next(p for p, (name, _) in WORLD.cities.items() if name == city)
            self.assertEqual(WORLD.provinces[pos].region, region, city)
        self.assertEqual({c[0] for c in geo.CITIES} - set(regions.CITY_REGION), set(), "a region for every geo city")

    def test_known_places_sit_in_the_right_region(self):
        for (lon, lat), region in {(-0.12, 51.5): "Middlesex", (-1.55, 47.22): "Brittany", (1.44, 43.6): "Languedoc",
                                   (4.35, 50.85): "Brabant", (7.69, 45.07): "Piedmont", (23.73, 37.98): "Attica",
                                   (9.99, 53.55): "Holstein", (1.1, 49.44): "Normandy", (-5.8, 35.77): "Tingitana",
                                   (10.93, 44.65): "Emilia", (28.97, 41.01): "Thrace"}.items():
            self.assertEqual(at(lon, lat).region, region, (lon, lat))

    def test_regions_do_not_cross_the_sea(self):
        """Africa's coast is not Spain's, and Britain's hexes are English or Scottish regions."""
        tangier = at(-5.8, 35.77)
        self.assertNotEqual(tangier.region, "Cádiz")
        self.assertEqual(WORLD.landmass[tangier.pos], WORLD.landmass[geo.hex_of(-5.0, 34.03)])

    def test_new_world_and_africa_have_no_modern_names(self):
        """Nothing in the Americas, the Atlantic islands or below the Sahara's edge has a modern town name: only
        native lands, or a region described by its land. (Cities, and colonies founded in play, are excepted.)"""
        for prov in WORLD.provinces.values():
            lon, lat = geo.lonlat(prov.pos)
            if prov.city or not (lon < -12 or lat < 24):
                continue
            self.assertTrue(" lands" in prov.name or prov.name.startswith(prov.region + " ("),
                            f"{prov.name} at {lon:.1f},{lat:.1f}")

    def test_modern_names_are_replaced(self):
        names = {p.name for p in WORLD.provinces.values()}
        for modern, old in naming.EXONYMS.items():
            if modern != old:
                self.assertNotIn(modern, names)
        self.assertIn("Danzig", names)
        self.assertNotIn("Istanbul", names)

    def test_no_soviet_or_post_1480_names(self):
        for prov in WORLD.provinces.values():
            self.assertIsNone(SOVIET.search(prov.name), prov.name)
            self.assertNotIn(prov.name.split(" (")[0], MODERN, prov.name)

    def test_the_filter_for_the_names_pattern_bites(self):
        self.assertTrue(SOVIET.search("Krasnoarmeysk") and SOVIET.search("Novomoskovsk"))
        self.assertIsNone(SOVIET.search("Novo Mesto") or SOVIET.search("Novgorod"))

    def test_the_data_is_small_and_credited(self):
        self.assertLess(len(placenames.PLACES), 1_000_000)
        path = os.path.join(os.path.dirname(placenames.__file__), "placenames.py")
        self.assertLess(os.path.getsize(path), 1_000_000)
        for text in ("GeoNames (https://www.geonames.org)", "CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/",
                     "pruned and adapted"):
            self.assertIn(text, placenames.__doc__)

    def test_naming_is_deterministic(self):
        w = fresh()
        before = {pos: (p.name, p.region) for pos, p in w.provinces.items()}
        for p in w.provinces.values():
            if not p.city:
                p.name, p.region = "", ""
        naming.name_europe(w)
        self.assertEqual({pos: (p.name, p.region) for pos, p in w.provinces.items()}, before)

    def test_names_do_not_depend_on_the_hash_seed(self):
        """Two interpreters with different PYTHONHASHSEEDs build the same names and regions."""
        code = ("import hashlib; from hexa.campaign.world import CampaignWorld; w = CampaignWorld(); "
                "print(hashlib.sha256(repr(sorted((p, v.name, v.region) for p, v in w.provinces.items()))"
                ".encode('utf-8')).hexdigest())")
        home = os.path.join(os.environ.get("TMP", "."), "hexa-hash-test")
        seen = set()
        for seed in ("1", "12345"):
            env = dict(os.environ, PYTHONHASHSEED=seed, HEXA_HOME=home, SDL_VIDEODRIVER="dummy")
            out = subprocess.run([sys.executable, "-c", code], cwd=ROOT, env=env, capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stderr)
            seen.add(out.stdout.strip().splitlines()[-1])
        self.assertEqual(len(seen), 1)


class DescribedNamesTest(unittest.TestCase):
    def test_place_and_colony_names(self):
        w = WORLD
        braga = at(-8.42, 41.55)
        self.assertEqual(naming.place(braga), "Braga (Minho)")
        city = w.provinces[next(p for p, (n, _) in w.cities.items() if n == "Seville")]
        self.assertEqual(naming.place(city), "Seville", "no repeat of a name that is its region")
        wild = next(p for p in w.provinces.values() if p.region == "Lucayan lands")
        self.assertEqual(naming.place(wild), wild.name, "native lands name themselves")
        self.assertTrue(wild.name.startswith("Lucayan lands ("))
        self.assertEqual(naming.colony_name(w, wild), "New Lucayan")

    def test_place_tests_the_region_exactly(self):
        prov = type("P", (), {"name": "Ironbridge", "region": "Iron"})()
        self.assertEqual(naming.place(prov), "Ironbridge (Iron)", "a region that is only inside the name is shown")
        prov.name = "Iron (north)"
        self.assertEqual(naming.place(prov), "Iron (north)")


class WarMessageTest(unittest.TestCase):
    def test_the_repro_of_issue_68(self):
        """Seed 1480, Portugal against Castile: the hexes that changed hands no longer share a name."""
        w = fresh("POR")
        pos = [(125, 53), (126, 54), (125, 55)]
        places = [w.place(w.provinces[p]) for p in pos]
        self.assertEqual(len(set(places)), 3, places)
        self.assertTrue(w.declare_war("POR", "CAS"))
        target = w.provinces[(126, 54)]
        self.assertEqual(target.owner, "POR")
        holder = w.castle_of(target.pos)                 # its own castle holds it: that castle has fallen (castle areas)
        if holder is not None:
            w.provinces[holder].controller = "CAS"
            w.changed(ownership=True)
        w.units = []
        for _ in range(3):
            w._add_unit(troop("infantry", 1), "CAS", target.pos, moves=1)
        for _ in range(40):
            w.sieges()
            if target.controller == "CAS":
                break
        self.assertEqual(target.controller, "CAS")
        said = [m for m in w.log if "took control of" in m]
        self.assertTrue(said and f"Castile took control of {w.place(target)}." in said, said)
        self.assertNotIn("near", said[-1])
        self.assertIn("(", said[-1], "the region is in the message")


class OldSaveTest(TempHome):
    def old_style(self, w):
        """Turn a world into what an older version saved: "near X" names and no regions."""
        for p in w.provinces.values():
            if not p.city and not p.name.startswith("New "):
                p.name = "near Porto" if p.owner else f"{p.tribe or 'Taíno'} lands"
            p.__dict__.pop("region", None)
        return w

    def test_old_europe_saves_get_real_names(self):
        w = self.old_style(fresh("POR"))
        colony = next(p for p in w.provinces.values() if p.tribe and not p.city)
        colony.name = "New Taíno"
        saves.save(w, 1)
        world = saves.load(1)
        self.assertIsNotNone(world)
        names = [p.name for p in world.provinces.values()]
        self.assertEqual(len(set(names)), len(names))
        self.assertFalse(any(n.startswith("near ") for n in names))
        self.assertIn("New Taíno", names)
        self.assertEqual(world.provinces[geo.hex_of(-8.42, 41.55)].name, "Braga")
        self.assertEqual(world.provinces[geo.hex_of(-9.14, 38.72)].name, "Lisbon")

    def test_new_saves_are_left_alone(self):
        w = fresh("POR")
        w.provinces[(125, 55)].name = "Elsewhere"
        again = CampaignWorld.from_state(pickle.loads(pickle.dumps(w.save_state())))
        self.assertEqual(again.provinces[(125, 55)].name, "Elsewhere")


class RandomNamesTest(unittest.TestCase):
    def test_random_world_names_are_unique(self):
        for seed in (3, 11):
            w = random_world(seed)
            names = [p.name for p in w.provinces.values()]
            self.assertEqual(len(set(names)), len(names), f"seed {seed}: {len(names) - len(set(names))} repeats")
            self.assertTrue(all(p.region == "" for p in w.provinces.values()))
            numbered = sum(1 for n in names if re.search(r" \d+\)$", n))
            self.assertLess(numbered / len(names), 0.25, f"seed {seed}")


if __name__ == "__main__":
    unittest.main()
