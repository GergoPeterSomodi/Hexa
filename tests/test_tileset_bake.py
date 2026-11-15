"""The full tile bake (tools/worldmap/tileset_bake/bake.py, spec m1-build-spec.md section 3): names and counts of section 3.3,
coast tiles of neighbouring hexes agreeing where they overlap, a bake that reads no map and no layers file, and the six
sets having the same tiles at the same places. No map files are used."""
import json
import os
import shutil
import sys
import tempfile
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
try:
    import pygame
except ImportError:                                  # the Python tests run without pygame in some environments
    pygame = None

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BAKE = os.path.join(REPO, "tools", "worldmap", "tileset_bake")
GODOT_BAKE = os.path.join(REPO, "tools", "worldmap", "godot_bake")


def _setup():
    if BAKE not in sys.path:
        sys.path.insert(0, BAKE)
    if GODOT_BAKE not in sys.path:
        sys.path.append(GODOT_BAKE)             # after the tile bake: both folders have a bake.py
    pygame.init()
    pygame.display.set_mode((5, 5))


def _load_bake():
    """tileset_bake/bake.py (tools/worldmap/godot_bake has a bake.py too, so the tile bake's folder must come first)."""
    _setup()
    if sys.path[0] != BAKE:
        sys.path.insert(0, BAKE)
    mod = sys.modules.get("bake")
    if mod is not None and os.path.dirname(os.path.abspath(mod.__file__)) != BAKE:
        del sys.modules["bake"]
    import bake
    return bake


@unittest.skipIf(pygame is None, "pygame is not installed")
class NamesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _setup()
        bake = _load_bake()
        import coast_tiles
        import decor_tiles
        import flat_tiles
        cls.bake, cls.coast, cls.decor, cls.flat = bake, coast_tiles, decor_tiles, flat_tiles

    def test_counts_of_section_3_3(self):
        ground = [n for n, _ in self.bake.ground_names()]
        self.assertEqual(sum(n.startswith("ground/") for n in ground), 72)
        self.assertEqual(sum(n.startswith("sea/") for n in ground), 9)
        self.assertEqual(len(self.bake.tree_names()), 324)
        self.assertEqual(len(self.bake.relief_names()), 45)
        coast = self.bake.coast_names()
        self.assertEqual(len(coast), 756 + 96)
        self.assertEqual(sum(n.endswith("/bay") for n in coast), 96)
        self.assertEqual(len(set(coast)), len(coast))
        self.assertEqual((self.flat.SHADE_LEVELS, self.flat.LIGHT_LEVELS), (10, 6))

    def test_names_are_unique_and_shaped(self):
        names = [n for n, _ in self.bake.ground_names()] + self.bake.tree_names() + self.bake.relief_names()
        self.assertEqual(len(set(names)), len(names))
        self.assertIn("ground/woods/4/2", names)
        self.assertIn("ground/sand/0/0", names)
        self.assertIn("sea/deep/2", names)
        self.assertIn("coast/cliff/63/5", self.bake.coast_names())
        self.assertIn("coast/beach/48/0/bay", self.bake.coast_names())
        self.assertNotIn("coast/cliff/48/0/bay", self.bake.coast_names())
        self.assertIn("trees/conifer/outerroad/5/1", names)
        self.assertIn("relief/ridge_snow/back/2", names)

    def test_ground_ranks(self):
        z = dict(self.bake.ground_names())
        ranks = {"sand": 0, "farmland": 1, "grassland": 2, "marsh": 3, "tundra": 4, "woods": 5, "rock": 6, "snow": 7}
        for cover, rank in ranks.items():
            self.assertEqual(z["ground/%s/0/0" % cover], rank)
        self.assertEqual([z["sea/%s/0" % d] for d in ("shelf", "sea", "deep")], [0, 1, 2])

    def test_piece_names(self):
        import pieces_bake
        import piece_tiles
        specs = pieces_bake.enumerate_specs()
        names = {piece_tiles.piece_name(s["family"], s["level"], s["variant"], s["mirror"], s["extra"], "front") for s in specs}
        self.assertEqual(len(names), len(specs))
        self.assertTrue(any(n.startswith("piece/harbour_addon/") and "/carved/" in n for n in names))
        self.assertGreater(len(specs) * 3, 1500)

    def test_palettes(self):
        summer = self.flat.palette("summer")
        self.assertEqual(summer["base"]["grassland"], self.flat.C_GRASS)
        for season, climate in (("spring", "snow"), ("autumn", "snow"), ("winter", "snow"), ("winter", "frost"), ("winter", "mild")):
            p = self.flat.palette(season, climate)
            self.assertEqual(set(p["base"]), set(self.flat.COVERS))
            self.assertEqual(set(p["sea"]), {"shelf", "sea", "deep"})
        self.assertNotEqual(self.flat.palette("winter", "snow")["base"]["farmland"], summer["base"]["farmland"])


@unittest.skipIf(pygame is None, "pygame is not installed")
class CoastJoinTest(unittest.TestCase):
    """Two land hexes side by side whose shore is the same sea hex: wherever both tiles paint a pixel, they paint the same."""

    @classmethod
    def setUpClass(cls):
        _setup()
        import coast_tiles
        import lattice
        cls.C, cls.LT = coast_tiles, lattice

    def overlap(self, a, b, dx):
        """(pixels both paint, pixels they paint differently); b's picture lies dx px to the right of a's."""
        both = diff = 0
        for y in range(self.C.C_H):
            for x in range(self.C.C_W):
                xb = x - dx
                if not 0 <= xb < self.C.C_W:
                    continue
                pa, pb = a.get_at((x, y)), b.get_at((xb, y))
                if pa.a and pb.a:
                    both += 1
                    if tuple(pa) != tuple(pb):
                        diff += 1
        return both, diff

    def test_neighbours_agree_on_the_overlap(self):
        # hex (c, 0) and (c + 1, 0) in an even row: the NE neighbour of the left one is the NW neighbour of the right one
        for c in range(3):
            for style in ("beach", "cliff"):
                a = self.C.coast_tile(0b000010, c % 3, style)
                b = self.C.coast_tile(0b000100, (c + 1) % 3, style)
                both, diff = self.overlap(a, b, self.LT.CELL_W)
                self.assertGreater(both, 0, (c, style))
                self.assertEqual(diff, 0, (c, style))

    def test_lower_shore_agrees(self):
        # in an even row the SE neighbour of the left hex is the SW neighbour of the right hex
        a = self.C.coast_tile(0b100000, 3, "beach")
        b = self.C.coast_tile(0b010000, 4, "beach")
        both, diff = self.overlap(a, b, self.LT.CELL_W)
        self.assertEqual(diff, 0)

    def test_nothing_painted_far_inside(self):
        t = self.C.coast_tile(0b000001, 0, "beach")
        self.assertEqual(t.get_at((self.C.C_W // 2 - 40, self.C.C_H // 2)).a, 0)       # the west side of an east-facing coast

    def test_palette_changes_colour_not_shape(self):
        import flat_tiles
        a = self.C.coast_tile(3, 0, "beach")
        b = self.C.coast_tile(3, 0, "beach", False, flat_tiles.palette("winter", "snow"))
        alpha = lambda s: [s.get_at((x, y)).a for y in range(0, self.C.C_H, 3) for x in range(0, self.C.C_W, 3)]
        self.assertEqual(alpha(a), alpha(b))
        self.assertNotEqual(pygame.image.tobytes(a, "RGBA"), pygame.image.tobytes(b, "RGBA"))


@unittest.skipIf(pygame is None, "pygame is not installed")
class QuickBakeTest(unittest.TestCase):
    """A quick bake of two sets: no map, no STYLE_FRAME_LAYERS; the sets have the same tiles at the same places."""

    @classmethod
    def setUpClass(cls):
        _setup()
        cls._env = os.environ.pop("STYLE_FRAME_LAYERS", None)
        bake = _load_bake()
        cls.out = tempfile.mkdtemp(prefix="hexa_tiles_")
        cls.indexes = bake.run(cls.out, ["summer", "winter_frost"], jobs=2, quick=True, log=lambda *a: None)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.out, ignore_errors=True)
        if cls._env is not None:
            os.environ["STYLE_FRAME_LAYERS"] = cls._env

    @staticmethod
    def read(path):
        with open(path, "rb") as f:
            return f.read()

    def test_files(self):
        for name in ("summer", "winter_frost"):
            folder = os.path.join(self.out, name)
            with open(os.path.join(folder, "index.json"), encoding="utf-8") as f:
                ix = json.load(f)
            self.assertEqual(ix["set"], name)
            names = [s["name"] for s in ix["sources"]]
            self.assertEqual(names[:2], ["ground", "shade"])
            self.assertEqual(names[-1], "marks")
            self.assertIn("trees", names)
            self.assertIn("relief", names)
            self.assertTrue(any(n.startswith("coast_") for n in names))
            self.assertTrue(any(n.startswith("pieces_") for n in names))
            for s in ix["sources"]:
                self.assertTrue(os.path.exists(os.path.join(folder, s["file"])), s["file"])
                self.assertLessEqual(max(s["size"]), 4096)
            self.assertFalse([f for f in os.listdir(folder) if f.endswith(".import")])

    def test_shared_and_same_places(self):
        a, b = self.indexes["summer"], self.indexes["winter_frost"]
        key = lambda ix: [(s["name"], s["region"], [(t["name"], t["at"], t["anchor"], t["y_sort"], t["z"]) for t in s["tiles"]])
                          for s in ix["sources"]]
        self.assertEqual(key(a), key(b))
        for f in ("shade.png", "marks.png"):
            self.assertEqual(self.read(os.path.join(self.out, "summer", f)), self.read(os.path.join(self.out, "winter_frost", f)))

    def test_contents(self):
        ix = self.indexes["summer"]
        by = {s["name"]: s for s in ix["sources"]}
        self.assertEqual(len(by["marks"]["tiles"]), 4)
        self.assertEqual(len(by["shade"]["tiles"]), 16)
        self.assertEqual(by["ground"]["region"], [172, 170])
        self.assertEqual(by["shade"]["region"], [252, 216])
        self.assertEqual(by["trees"]["region"], [76, 84])
        self.assertEqual(by["relief"]["region"], [236, 150])
        pieces = [s for s in ix["sources"] if s["name"].startswith("pieces_")]
        self.assertTrue(pieces)
        for s in pieces:
            self.assertIn(s["region"][0], (120, 152, 184))
            self.assertEqual(s["region"][0], s["region"][1])
            for t in s["tiles"]:
                self.assertTrue(t["name"].startswith("piece/"))
                self.assertIn(t["name"].split("/")[-1], ("ground", "shadow", "back", "front"))
                self.assertTrue(0 <= t["anchor"][0] <= s["region"][0] and 0 <= t["anchor"][1] <= s["region"][1])
        sorts = {t["name"].split("/")[-1]: t["y_sort"] for s in pieces for t in s["tiles"] if "harbour_addon" not in t["name"]}
        self.assertEqual((sorts.get("back"), sorts.get("front")), (-12, 12))

    def test_summer_and_winter_differ(self):
        self.assertNotEqual(self.read(os.path.join(self.out, "summer", "ground.png")),
                            self.read(os.path.join(self.out, "winter_frost", "ground.png")))


@unittest.skipIf(pygame is None, "pygame is not installed")
class WithoutLayersTest(unittest.TestCase):
    def test_decor_tile_needs_no_layers_file(self):
        _setup()
        env = os.environ.pop("STYLE_FRAME_LAYERS", None)
        try:
            import art
            import decor_tiles
            painter = art.Painter("summer", "snow")
            surf = decor_tiles.tree_tile(painter, 2, "broad", "full", 0)
            self.assertEqual(surf.get_size(), (decor_tiles.T_W, decor_tiles.T_H))
            self.assertGreater(surf.get_bounding_rect().width, 0)
        finally:
            if env is not None:
                os.environ["STYLE_FRAME_LAYERS"] = env


if __name__ == "__main__":
    unittest.main()
