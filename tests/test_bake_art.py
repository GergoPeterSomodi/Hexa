"""The art baker (tools/bake_art.py, release 0.3.0 item 5): it runs, its index matches its atlases, the sizes are the
pinned ones (hex radius 60, tile 104 x 120, sprites 106 x 122 with a 2 px extruded border, pages at most 2048 px), and
the committed bake under godot/assets/baked/ is what the baker makes now (the same sprites at the same places; the same
bytes too when it was baked on this platform)."""
import hashlib
import json
import os
import tempfile
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from tools import bake_art  # noqa: E402


class BakeArtTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = cls.tmp.name
        cls.index = bake_art.bake(cls.out, log=lambda *a: None)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_the_sizes_are_the_pinned_ones(self):
        ix = self.index
        self.assertEqual(ix["hex_radius"], 60)
        self.assertEqual(ix["tile_size"], [104, 120])
        self.assertEqual(ix["region_size"], [106, 122])
        self.assertEqual(ix["anchor"], [53, 61])
        self.assertEqual(ix["extrude"], 2)
        self.assertEqual(ix["cell"], [110, 126])
        for name, page in ix["atlases"].items():
            self.assertLessEqual(max(page["size"]), 2048, name)

    def test_the_index_matches_the_atlases(self):
        ix = self.index
        seen = {}
        for name, page in ix["atlases"].items():
            path = os.path.join(self.out, name)
            with open(path, "rb") as f:
                self.assertEqual(hashlib.sha256(f.read()).hexdigest(), page["sha256"], name)
            img = pygame.image.load(path)
            self.assertEqual(list(img.get_size()), page["size"], name)
            seen[name] = img
        counts = {}
        cells = set()
        for name, s in ix["sprites"].items():
            self.assertIn(s["atlas"], seen, name)
            x, y, w, h = s["rect"]
            pw, ph = ix["atlases"][s["atlas"]]["size"]
            self.assertEqual((w, h), (106, 122), name)
            self.assertTrue(x >= 2 and y >= 2 and x + w + 2 <= pw and y + h + 2 <= ph, name)
            self.assertEqual(((x - 2) % 110, (y - 2) % 126), (0, 0), name)    # on the cell grid: no overlaps
            cell = (s["atlas"], x, y)
            self.assertNotIn(cell, cells, name)
            cells.add(cell)
            counts[s["atlas"]] = counts.get(s["atlas"], 0) + 1
        self.assertEqual(counts, {n: p["sprites"] for n, p in ix["atlases"].items()})

    def test_the_border_is_extruded_and_ground_is_opaque(self):
        ix = self.index
        pages = {n: pygame.image.load(os.path.join(self.out, n)) for n in ix["atlases"]}
        for name in ("terrain/plains/0", "goods/wine/3/1", "sea/sea/2", "coast/9/0", "town/5/1"):
            s = ix["sprites"][name]
            page = pages[s["atlas"]]
            x, y, w, h = s["rect"]
            for yy in (y, y + h // 2, y + h - 1):
                self.assertEqual(page.get_at((x - 2, yy)), page.get_at((x, yy)), name)
                self.assertEqual(page.get_at((x + w + 1, yy)), page.get_at((x + w - 1, yy)), name)
            if s["layer"] == "ground":
                self.assertEqual(page.get_at((x + 53, y + 61)).a, 255, name)
                self.assertEqual(page.get_at((x + 53, y + 1)).a, 255, name)     # the top corner is covered

    def test_every_piece_the_map_needs_is_there(self):
        names = set(self.index["sprites"])
        from hexa.campaign.data import TERRAIN_SPRITES
        for kind, options in TERRAIN_SPRITES.items():
            for i in range(len(options)):
                self.assertIn(f"terrain/{kind}/{i}", names)
        for mask in range(1, 64):
            self.assertIn(f"coast/{mask}/2", names)
            self.assertIn(f"road/dirt/{mask}", names)
            self.assertIn(f"road/paved/{mask}", names)
        for level in (2, 3, 4, 5, 6):
            self.assertIn(f"town/{level}/0", names)
            self.assertIn(f"harbour/{level}/62", names)
        for level in (1, 2, 3):
            self.assertIn(f"castle/{level}/2", names)
        self.assertIn("mouth/0/62", names)
        self.assertIn("river/15/1", names)
        self.assertTrue(os.path.exists(os.path.join(self.out, "kenney", "License.txt")))
        for rel in self.index["kenney"]["files"]:
            self.assertTrue(os.path.exists(os.path.join(self.out, "kenney", *rel.split("/"))), rel)

    def test_the_committed_bake_is_current(self):
        path = os.path.join(bake_art.OUT_DIR, "index.json")
        if not os.path.exists(path):
            self.skipTest("no committed bake")
        with open(path, encoding="utf-8") as f:
            committed = json.load(f)
        fresh = self.index
        self.assertEqual({n: s["rect"] + [s["atlas"]] for n, s in committed["sprites"].items()},
                         {n: s["rect"] + [s["atlas"]] for n, s in fresh["sprites"].items()})
        if committed["platform"] == fresh["platform"]:
            self.assertEqual({n: p["sha256"] for n, p in committed["atlases"].items()},
                             {n: p["sha256"] for n, p in fresh["atlases"].items()},
                             "the art changed: re-run python -m tools.bake_art")


if __name__ == "__main__":
    unittest.main()
