"""The campaign map's hex geometry (hexa/campaign/mapview.py): MapView.center, hex_at and size at every zoom.

The window turns mouse pixels into hexes with hex_at and draws every hex at center, so the two must agree, and
size() is the picture every hex is drawn on. Pointy-top hexes, "odd-r" rows (odd rows half a hex to the right),
radius r = ZOOMS[zoom] pixels: a point closer than r * sqrt(3) / 2 (about 0.87 r) to a hex's centre is inside
that hex. No window or driver: a MapView over the shared Europe world (read-only), with pygame headless because
MapView makes its fonts. Run with:

    python -m unittest tests.ui.test_mapview_geometry
"""
import math
import random
import unittest

from tests.support import harness, worlds
from tests.support.pg import requires_pygame

SEED = 53
SAMPLE = 300                    # hexes per zoom for the pixel tests (every hex for the round trip)
REPRO = "python -m unittest tests.ui.test_mapview_geometry"


@requires_pygame
class MapViewGeometryTest(unittest.TestCase):
    view = None                 # one MapView for the class, made by the first test (in setUp, not setUpClass:
                                # with HEXA_REQUIRE_PYGAME=1 and no pygame, each test must error on its own)

    def setUp(self):
        harness.install()       # headless pygame and the bundled font
        import pygame
        pygame.font.init()      # MapView() makes fonts; an earlier test may have run play.main(), which quits pygame
        cls = type(self)
        if cls.view is None:
            from hexa.campaign.mapview import MapView, ZOOMS
            cls.zooms = range(len(ZOOMS))
            cls.view = MapView(worlds.europe())
            cls.hexes = [(col, row) for row in range(cls.view.world.rows) for col in range(cls.view.world.cols)]
            cls.sample = random.Random(SEED).sample(cls.hexes, SAMPLE)
        self.view.zoom = 1

    def test_every_hex_centre_is_inside_that_hex(self):
        view = self.view
        for zoom in self.zooms:
            view.zoom = zoom
            wrong = [(p, view.hex_at(*view.center(p))) for p in self.hexes if view.hex_at(*view.center(p)) != p]
            self.assertEqual(wrong[:5], [], f"zoom {zoom}: hex_at(*center(p)) != p for {len(wrong)} hexes")

    def test_points_within_0_8_r_of_a_centre_are_in_that_hex(self):
        """Toward the 6 neighbours (where the edges are closest), the 6 corners, and at random, with the
        sample of hexes from random.Random(SEED)."""
        view = self.view
        rng = random.Random(SEED)
        for zoom in self.zooms:
            view.zoom = zoom
            r = view.r
            wrong = []
            for p in self.sample:
                cx, cy = view.center(p)
                points = [(0.8, math.radians(30 * k)) for k in range(12)]
                points += [(0.8 * math.sqrt(rng.random()), rng.uniform(0, 2 * math.pi)) for _ in range(8)]
                for d, angle in points:
                    x, y = cx + d * r * math.cos(angle), cy + d * r * math.sin(angle)
                    if view.hex_at(x, y) != p:
                        wrong.append((p, round(d, 3), round(math.degrees(angle)), view.hex_at(x, y)))
            self.assertEqual(wrong[:5], [], f"zoom {zoom}, seed {SEED}: {len(wrong)} points in the wrong hex. "
                                            f"Repro: {REPRO}")

    def test_crossing_an_edge_lands_on_the_neighbour_the_game_means(self):
        """The hex beyond each edge on screen is hexgrid.neighbors(), the adjacency the rules use: neighbouring
        centres are r * sqrt(3) apart, and a point 0.9 r from a centre toward a neighbour is in the neighbour."""
        from hexa.hexgrid import neighbors
        view = self.view
        world = view.world
        for zoom in self.zooms:
            view.zoom = zoom
            r = view.r
            wrong = []
            for p in self.sample:
                cx, cy = view.center(p)
                for n in neighbors(p):
                    if not (0 <= n[0] < world.cols and 0 <= n[1] < world.rows):
                        continue
                    nx, ny = view.center(n)
                    gap = math.hypot(nx - cx, ny - cy)
                    across = (cx + (nx - cx) * 0.9 * r / gap, cy + (ny - cy) * 0.9 * r / gap)
                    if abs(gap - r * math.sqrt(3)) > 1e-9 or view.hex_at(*across) != n:
                        wrong.append((p, n, gap, view.hex_at(*across)))
            self.assertEqual(wrong[:5], [], f"zoom {zoom}, seed {SEED}: {len(wrong)} edges. Repro: {REPRO}")

    def test_the_map_picture_holds_every_hex(self):
        """size() covers every centre, and every whole hex (r * sqrt(3) wide, 2 r high) around it."""
        view = self.view
        for zoom in self.zooms:
            view.zoom = zoom
            r, w = view.r, view.r * math.sqrt(3)
            width, height = view.size()
            outside = [p for p in self.hexes
                       if not (w / 2 <= view.center(p)[0] <= width - w / 2 and r <= view.center(p)[1] <= height - r)]
            self.assertEqual(outside[:5], [], f"zoom {zoom}: {len(outside)} hexes stick out of {width}x{height}")
            right = max(view.center(p)[0] for p in self.hexes) + w / 2
            bottom = max(view.center(p)[1] for p in self.hexes) + r
            self.assertLessEqual(width - right, view.MARGIN, "and no more to spare than the margin")
            self.assertLessEqual(height - bottom, view.MARGIN)

    def test_river_and_road_points_use_the_same_centres(self):
        """unit_point (rivers and roads, drawn as unit_point * r + MARGIN) is center at radius 1."""
        view = self.view
        for zoom in self.zooms:
            view.zoom = zoom
            for p in self.sample:
                ux, uy = view.unit_point(p)
                cx, cy = view.center(p)
                self.assertAlmostEqual(view.MARGIN + ux * view.r, cx, places=9)
                self.assertAlmostEqual(view.MARGIN + uy * view.r, cy, places=9)


if __name__ == "__main__":
    unittest.main()
