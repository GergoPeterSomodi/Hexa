"""The Godot data exporters (tools/export_data.py, export_geography.py).

Checks the committed godot/data files against the Python tables they were exported from: that they are what the
exporters write now, that the counts the release brief lists are right, that the schema marks are there, that the
floats round-trip.
"""
import json
import unittest
from pathlib import Path

from hexa.campaign import data, geo, naming, placenames, regions
from hexa.campaign.systems import worldgen
from tools import export_data, export_geography
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


class WfcDataTest(unittest.TestCase):
    """The wave function collapse numbers kept for later (wfc.json)."""

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
