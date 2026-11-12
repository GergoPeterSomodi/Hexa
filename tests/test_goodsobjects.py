"""Goods objects (hexa/campaign/goodsobjects.py) and the map's Goods view in deposits mode: every good has an object,
each draws at the map sizes with a transparent background, the same bytes every time, cached per size, and the view
draws at every zoom with the object of each good. Headless.
Run with:  python -m unittest tests.test_goodsobjects"""
import os
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa.campaign import goodsobjects, mapview  # noqa: E402
from hexa.campaign.app import CampaignApp  # noqa: E402
from hexa.campaign.data import GOODS  # noqa: E402
from tests.test_saves import TempHome  # noqa: E402

RADII = (13, 21, 34)            # the hex radii the map draws the goods objects at (2 * r is the object's height)
TILE_W, TILE_H = 120, 140
TILES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hexagon-pack", "PNG", "Tiles")


def setUpModule():
    pygame.init()
    if pygame.display.get_surface() is None:
        pygame.display.set_mode((5, 5))


def size_of(r):
    return round(2 * r)


class ObjectsTest(unittest.TestCase):
    def test_every_good_has_an_object(self):
        missing = sorted(set(GOODS) - set(goodsobjects.OBJECTS))
        self.assertEqual(missing, [])

    def test_every_good_draws_at_the_map_sizes(self):
        for r in RADII:
            size = size_of(r)
            for key in GOODS:
                img = goodsobjects.draw_good(key, size)
                with self.subTest(good=key, r=r):
                    self.assertEqual(img.get_height(), size)
                    self.assertEqual(img.get_width(), max(3, round(size * TILE_W / TILE_H)))
                    self.assertGreater(pygame.mask.from_surface(img).count(), 0)

    def test_background_is_transparent(self):
        for r in RADII:
            for key in GOODS:
                img = goodsobjects.draw_good(key, size_of(r))
                w, h = img.get_size()
                corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
                with self.subTest(good=key, r=r):
                    for x, y in corners:
                        self.assertEqual(img.get_at((x, y)).a, 0)

    def test_deterministic(self):
        for key in GOODS:
            first = goodsobjects.draw_good(key, size_of(34))
            goodsobjects.draw_good.cache_clear()
            again = goodsobjects.draw_good(key, size_of(34))
            with self.subTest(good=key):
                self.assertEqual(pygame.image.tobytes(first, "RGBA"), pygame.image.tobytes(again, "RGBA"))

    def test_cached_per_size(self):
        goodsobjects.draw_good.cache_clear()
        a = goodsobjects.draw_good("grain", size_of(34))
        hits = goodsobjects.draw_good.cache_info().hits
        b = goodsobjects.draw_good("grain", size_of(34))
        self.assertIs(a, b)
        self.assertEqual(goodsobjects.draw_good.cache_info().hits, hits + 1)
        self.assertIsNot(a, goodsobjects.draw_good("grain", size_of(13)))

    def test_masters_are_not_kept(self):
        self.assertFalse(hasattr(goodsobjects.master, "cache_info"))
        self.assertFalse(hasattr(goodsobjects, "OBJECTS_B"))


class GoodsViewTest(TempHome):
    def setUp(self):
        super().setUp()
        self.app = CampaignApp(TILES, player="POR")
        self.app.view.mode = "goods"
        self.app.view.goods_view = "deposits"

    def goods_pos(self):
        world = self.app.world
        known = self.app.view.known()
        for pos in sorted(known):
            prov = world.provinces.get(pos)
            if prov is not None and prov.good:
                return pos
        self.fail("no known province with a good")

    def test_draws_at_every_zoom_with_the_right_objects(self):
        app = self.app
        pos = self.goods_pos()
        real = goodsobjects.draw_good
        calls = []

        def recording(key, size):
            calls.append((key, size))
            return real(key, size)

        goodsobjects.draw_good = recording
        try:
            for idx, r in enumerate(mapview.ZOOMS):
                with self.subTest(r=r):
                    calls.clear()
                    app.view.zoom = idx
                    app.look_at(pos)
                    app.draw()
                    if r >= 13:             # the map draws the objects from the tile zooms on (the small zooms are flat)
                        self.assertTrue(calls, "no goods objects drawn")
                    for key, size in calls:
                        self.assertIn(key, GOODS)
                        self.assertEqual(size, size_of(r))
        finally:
            goodsobjects.draw_good = real


if __name__ == "__main__":
    unittest.main()
