"""The Godot data exporters (tools/export_data.py, export_geography.py, export_map_reference.py).

Checks the committed godot/data files against the Python tables they were exported from: that they are what the
exporters write now, that the counts the release brief lists are right, that the schema marks are there, that the
floats round-trip, and that the map reference holds the numbers of the brief's "The new Europe is checked" section.
The map reference rebuilds the Python Europe at eight seeds (about 15 seconds); HEXA_FAST=1 skips that one test.
"""
import json
import os
import unittest
from pathlib import Path

from hexa.campaign import data, geo, naming, placenames, regions
from hexa.campaign.systems import worldgen
from tools import export_data, export_geography, export_map_reference
from tools.godot_export_common import DATA_DIR, GEO_DIR, REPO, load, text


def _floats(value):
    if isinstance(value, float):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _floats(item)
    elif isinstance(value, list):
        for item in value:
            yield from _floats(item)


class ExporterFilesTest(unittest.TestCase):
    """The committed files are exactly what the exporters write."""

    @classmethod
    def setUpClass(cls):
        cls.data_payload = export_data.payload()
        cls.geo_payload = export_geography.payload()

    def test_committed_data_files_match_the_exporter(self):
        for name, obj in self.data_payload.items():
            with self.subTest(file=name):
                self.assertEqual((DATA_DIR / name).read_text(encoding="utf-8"), text(obj))

    def test_committed_geography_files_match_the_exporter(self):
        for name, obj in self.geo_payload.items():
            with self.subTest(file=name):
                self.assertEqual((GEO_DIR / name).read_text(encoding="utf-8"), text(obj))

    @unittest.skipIf(os.environ.get("HEXA_FAST"), "rebuilds the Python Europe at eight seeds (about 15 s)")
    def test_committed_map_reference_matches_the_python_builder(self):
        built = export_map_reference.build()
        self.assertEqual((DATA_DIR / "map_reference.json").read_text(encoding="utf-8"), text(built))

    def test_every_file_has_a_schema_and_is_listed_in_the_readme(self):
        readme = (DATA_DIR / "README.md").read_text(encoding="utf-8")
        files = sorted(p for p in DATA_DIR.rglob("*.json"))
        self.assertGreaterEqual(len(files), 20)
        for path in files:
            rel = path.relative_to(DATA_DIR).as_posix()
            with self.subTest(file=rel):
                obj = load(path)
                self.assertTrue(obj["schema"].startswith("hexa-godot/"), obj.get("schema"))
                self.assertIn(rel, readme)


class CountsTest(unittest.TestCase):
    """The counts of the brief's check list, read from the committed files."""

    @classmethod
    def setUpClass(cls):
        cls.countries = load(DATA_DIR / "countries.json")["countries"]
        cls.geo_countries = load(GEO_DIR / "countries.json")["countries"]
        cls.cities = load(GEO_DIR / "cities.json")["cities"]
        cls.rivers = load(GEO_DIR / "rivers.json")["rivers"]
        cls.passes = load(GEO_DIR / "passes.json")["passes"]
        cls.terrain_shapes = load(GEO_DIR / "terrain_shapes.json")
        cls.land = load(GEO_DIR / "land.json")
        cls.tribes = load(GEO_DIR / "tribes.json")["tribes"]
        cls.markets = load(GEO_DIR / "markets.json")["markets"]
        cls.regions = load(GEO_DIR / "regions.json")["regions"]
        cls.places = load(GEO_DIR / "placenames.json")["places"]

    def test_geography_counts(self):
        self.assertEqual(len(self.countries), 49)
        self.assertEqual(len(self.geo_countries), 49)
        self.assertEqual(len(self.cities), 102)
        self.assertEqual(len(self.rivers), 35)
        self.assertEqual(len(self.passes), 24)
        self.assertEqual(len(self.terrain_shapes["mountains"]), 18)
        self.assertEqual(len(self.tribes), 56)
        self.assertEqual(len(self.markets), 41)
        self.assertEqual(len(self.regions), 684)
        self.assertEqual(len(self.land["landmasses"]), 7)
        self.assertEqual(len(self.land["islands"]), 17)
        self.assertEqual(len(self.land["lakes"]), 5)
        self.assertEqual(len(self.land["seas"]), 2)
        self.assertEqual(len(self.places), 6940)

    def test_data_counts(self):
        self.assertEqual(len(load(DATA_DIR / "terrain.json")["terrain"]), 15)
        self.assertEqual(len(load(DATA_DIR / "goods.json")["goods"]), 32)
        self.assertEqual(len(load(DATA_DIR / "buildings.json")["buildings"]), 13)
        self.assertEqual(len(load(DATA_DIR / "buildings.json")["settlements"]), 4)
        self.assertEqual(len(load(DATA_DIR / "buildings.json")["castles"]), 4)
        self.assertEqual(len(load(DATA_DIR / "units.json")["troops"]), 9)
        self.assertEqual(len(load(DATA_DIR / "wfc.json")["forbidden"]), len(worldgen.FORBIDDEN))

    def test_exported_tables_are_the_module_tables(self):
        self.assertEqual([c["tag"] for c in self.countries], list(geo.COUNTRIES))
        self.assertEqual([c["name"] for c in self.cities], [c[0] for c in geo.CITIES])
        self.assertEqual([[c["name"], c["lon"], c["lat"]] for c in self.tribes], [list(t) for t in geo.TRIBES])
        self.assertEqual([(r["name"], r["lon"], r["lat"], r["tag"]) for r in self.regions], regions.REGIONS)
        self.assertEqual(load(GEO_DIR / "naming.json")["exonyms"], naming.EXONYMS)
        self.assertEqual(sorted(load(GEO_DIR / "naming.json")["skip"]), sorted(naming.SKIP))
        parsed = [line.split("|") for line in placenames.PLACES.strip().splitlines()]
        self.assertEqual([[float(lon), float(lat), name] for lon, lat, name in parsed], self.places)
        terrain = {t["key"]: t for t in load(DATA_DIR / "terrain.json")["terrain"]}
        for key, kind in data.TERRAIN.items():
            self.assertEqual(terrain[key]["density"], kind.density)
            self.assertEqual(terrain[key]["move"], kind.move)
        self.assertEqual([t["key"] for t in load(DATA_DIR / "units.json")["troops"]], [t.key for t in data.TROOPS])
        projection = load(GEO_DIR / "projection.json")
        self.assertEqual(projection["col_deg"], geo.COL_DEG)
        self.assertEqual(projection["row_deg"], geo.ROW_DEG)
        self.assertEqual((projection["cols"], projection["rows"]), (geo.COLS, geo.ROWS))
        self.assertEqual(load(DATA_DIR / "wfc.json")["forbidden"], [list(p) for p in worldgen.FORBIDDEN])

    def test_placenames_carry_the_geonames_credit(self):
        credit = load(GEO_DIR / "placenames.json")["credit"]
        self.assertIn("GeoNames", credit["text"])
        self.assertIn("CC BY 4.0", credit["text"])
        self.assertEqual(credit["licence_url"], "https://creativecommons.org/licenses/by/4.0/")
        self.assertIn("GeoNames", (DATA_DIR / "README.md").read_text(encoding="utf-8"))


class FloatRoundTripTest(unittest.TestCase):
    """Every float reads back to the same double, and dumping what was read gives the same text."""

    def test_round_trip_is_exact(self):
        payloads = list(export_data.payload().values()) + list(export_geography.payload().values())
        checked = 0
        for obj in payloads:
            once = text(obj)
            self.assertEqual(text(json.loads(once)), once)
            self.assertEqual(json.loads(once), json.loads(json.dumps(obj)))
            for value in _floats(obj):
                self.assertEqual(float(repr(value)), value)
                checked += 1
        self.assertGreater(checked, 1000)

    def test_computed_projection_floats_are_written_in_full(self):
        projection = (GEO_DIR / "projection.json").read_text(encoding="utf-8")
        self.assertIn(repr(geo.COL_DEG), projection)
        self.assertIn(repr(geo.ROW_DEG), projection)
        self.assertIn(repr(geo.Y_TOP), projection)
        self.assertEqual(json.loads(projection)["row_deg"], geo.ROW_DEG)


class MapReferenceTest(unittest.TestCase):
    """The reference numbers of the brief's section 'The new Europe is checked', as the Python builder gives them."""

    @classmethod
    def setUpClass(cls):
        cls.ref = load(DATA_DIR / "map_reference.json")

    def test_equal_facts_hold_in_every_seed(self):
        for name, fact in self.ref["equal"].items():
            with self.subTest(fact=name):
                self.assertTrue(fact.get("same_in_all_seeds", True), name)

    def test_equal_counts(self):
        equal = self.ref["equal"]
        self.assertEqual(equal["grid"]["value"], [203, 150])
        self.assertEqual(equal["hex_classes"]["value"], {"land": 14411, "ocean": 15956, "lake": 83})
        self.assertEqual(equal["coastal_provinces"]["value"], 1459)
        self.assertEqual(len(equal["cities"]["value"]), 102)
        self.assertEqual(equal["rivers"]["value"], 35)
        self.assertEqual(equal["river_hexes"]["value"], 680)
        self.assertEqual(equal["ridge_edges"]["value"], 441)
        self.assertEqual(equal["pass_edges"]["value"], 47)
        self.assertEqual(equal["passes"]["value"], 72)
        self.assertEqual(len(equal["capitals"]["value"]), 49)
        self.assertEqual(len(equal["castle2"]["value"]), 42)
        self.assertEqual(len(equal["castle3"]["value"]), 7)
        self.assertEqual(len(equal["towns2"]["value"]), 73)
        self.assertEqual(len(equal["towns3"]["value"]), 33)
        self.assertTrue(equal["names_all_distinct"]["value"])
        self.assertTrue(equal["names_none_empty"]["value"])

    def test_close_counts_fall_in_the_python_ranges(self):
        close = self.ref["close"]
        ranges = {
            "towers": (11, 21, 18),
            "small_towns": (392, 447, 432),
            "roads_hexes": (595, 630, 623),
            "road_paths": (348, 350, 349),
            "owned_provinces": (4292, 4315, 4311),
            "starting_units": (130, 133, 133),
            "provinces_without_good": (1963, 2016, 1963),
            "goods_present": (25, 25, 25),
        }
        for name, (low, high, value) in ranges.items():
            with self.subTest(fact=name):
                fact = close[name]
                self.assertLessEqual(low, fact["min"])
                self.assertGreaterEqual(high, fact["max"])
                self.assertEqual(fact["value"], value)
        self.assertGreater(close["population"]["min"], 31046 - 1)
        self.assertLess(close["population"]["max"], 32047 + 1)
        self.assertEqual(close["population"]["value"] // 1, 31721)

    def test_per_hex_facts_are_complete(self):
        hexes = self.ref["hexes_1480"]
        self.assertEqual(len(hexes["class_rows"]), 150)
        self.assertTrue(all(len(row) == 203 for row in hexes["class_rows"]))
        self.assertTrue(all(len(row) == 203 for row in hexes["owner_rows"]))
        classes = "".join(hexes["class_rows"])
        self.assertEqual((classes.count("L"), classes.count("O"), classes.count("K")), (14411, 15956, 83))


class BuilderRulesTest(unittest.TestCase):
    """The Python functions the builder ports are all in the steps file, with their steps."""

    @classmethod
    def setUpClass(cls):
        cls.rules = load(DATA_DIR / "rules" / "builder_functions.json")["functions"]

    def test_the_map_functions_are_there(self):
        for key in ("geo.py::merc", "geo.py::land_cells", "worldgen.py::build_map", "worldgen.py::terrain_prior",
                    "worldgen.py::good_for", "worldgen.py::build_countries", "worldgen.py::build_roads",
                    "worldgen.py::starting_units", "worldgen.py::trace", "naming.py::name_europe",
                    "wfc.py::collapse", "hexgrid.py::neighbors"):
            with self.subTest(function=key):
                matches = [k for k in self.rules if k.endswith(key)]
                self.assertEqual(len(matches), 1, key)
                self.assertTrue(self.rules[matches[0]]["steps"])

    def test_terrain_prior_keeps_the_branches(self):
        steps = next(v for k, v in self.rules.items() if k.endswith("worldgen.py::terrain_prior"))["steps"]
        returns = [s for s in steps if s["op"] == "return"]
        self.assertTrue(returns)
        flat = json.dumps(steps)
        self.assertIn("mount < 0.8", flat)
        self.assertIn("hills", flat)

    def test_schema_marks_and_values_of_the_ports(self):
        self.assertEqual(export_data.affinity_in_build_map(), 1.6)
        wfc = load(DATA_DIR / "wfc.json")
        self.assertEqual(wfc["affinity_in_build_map"], 1.6)
        self.assertEqual(wfc["affinity_default"], 1.5)


class ExportersRunTest(unittest.TestCase):
    """The exporters write into a folder the caller picks, and only there."""

    def test_export_writes_into_a_temporary_folder(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            written = export_data.export(tmp)
            self.assertEqual(sorted(p.name for p in written.values()),
                             sorted(Path(name).name for name in export_data.payload()))
            for path in written.values():
                self.assertTrue(path.is_relative_to(Path(tmp)))
                self.assertEqual(path.read_text(encoding="utf-8"),
                                 (DATA_DIR / path.relative_to(tmp)).read_text(encoding="utf-8"))
        self.assertTrue(REPO.joinpath("tools", "export_geography.py").exists())


if __name__ == "__main__":
    unittest.main()
