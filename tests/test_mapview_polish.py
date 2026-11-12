"""Map view polish: the closed-pass marker at the far zooms, town names over unit tokens, and the speed-ups that must
not change the picture (Voronoi field cells, the tree lattice, the cached ground lookup). Headless.
Run with:  python -m unittest tests.test_mapview_polish"""
import os
import random
import unittest
from types import SimpleNamespace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

from hexa.campaign import landscape as L  # noqa: E402
from hexa.campaign import mapview  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402

TILES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hexagon-pack", "PNG", "Tiles")
RED = (190, 40, 38)
WORLD = None


def setUpModule():
    global WORLD
    pygame.init()
    if pygame.display.get_surface() is None:
        pygame.display.set_mode((5, 5))
    WORLD = CampaignWorld(1480)


def area(poly):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(poly, poly[1:] + poly[:1]))) / 2


def draw(world, r, turn):
    world.turn = turn
    world.changed()
    view = mapview.MapView(world, TILES)
    view.zoom = mapview.ZOOMS.index(r)
    ui = SimpleNamespace(selected=None, reach=None, province=None, hover=None, group=[], anim=None)
    rect = pygame.Rect(0, 0, 700, 500)
    screen = pygame.Surface((700, 500))
    pos = next(iter(world.passes()))
    x, y = view.center(pos)
    camera = [x - 350, y - 250]
    view.draw(screen, rect, camera, ui)
    return view, screen, (350, 250)


def count(screen, centre, colour, half=30):
    n = 0
    for dy in range(-half, half):
        for dx in range(-half, half):
            if tuple(screen.get_at((centre[0] + dx, centre[1] + dy)))[:3] == colour:
                n += 1
    return n


class ClosedPasses(unittest.TestCase):
    def tearDown(self):
        WORLD.turn = 1
        WORLD.changed()

    def test_marker_on_the_far_zooms_in_winter_only(self):
        for r in (13, 8, 5):
            _, summer, c = draw(WORLD, r, 2)
            _, winter, c = draw(WORLD, r, 4)
            self.assertEqual(count(summer, c, RED), 0, f"r={r}: no marker in summer")
            self.assertGreater(count(winter, c, RED), 0, f"r={r}: a red marker on the closed pass")

    def test_marker_shrinks_with_the_zoom(self):
        view = mapview.MapView(WORLD, TILES)
        sizes = [view.pass_chip(r).get_width() for r in (13, 8, 5, 3)]
        self.assertEqual(sizes, sorted(sizes, reverse=True))
        self.assertGreater(sizes[0], sizes[-1])

    def test_random_worlds_have_passes(self):
        world = CampaignWorld(7, map="random")
        self.assertGreater(len(world.passes()), 0)


class Labels(unittest.TestCase):
    def test_far_zoom_names_wait_for_the_tokens(self):
        view = mapview.MapView(WORLD, TILES)
        view.zoom = mapview.ZOOMS.index(13)
        ui = SimpleNamespace(selected=None, reach=None, province=None, hover=None, group=[], anim=None)
        town = next(p for p in WORLD.provinces.values() if p.settlement >= 3 and p.owner and p.name
                    and not p.name.startswith(("near ", "New ")))
        x, y = view.center(town.pos)
        screen = pygame.Surface((700, 500))
        view.draw(screen, pygame.Rect(0, 0, 700, 500), [x - 350, y - 250], ui)
        self.assertEqual(view._late_labels, [])                     # drawn and cleared within the frame
        self.assertTrue(any(k[0] == town.name for k in view._labels))


class Speedups(unittest.TestCase):
    def test_voronoi_cells_tile_the_box(self):
        rng = random.Random(5)
        seeds = []
        while len(seeds) < 40:
            p = (rng.uniform(-1.8, 1.8), rng.uniform(-1.6, 1.6))
            if all(((p[0] - s[0]) ** 2 + (p[1] - s[1]) ** 2) ** 0.5 > 0.3 for s in seeds):
                seeds.append(p)
        box = [(-2.0, -1.8), (2.0, -1.8), (2.0, 1.8), (-2.0, 1.8)]
        cells = L.voronoi_cells(seeds, box)
        self.assertAlmostEqual(sum(area(c) for c in cells), 4.0 * 3.6, places=6)
        for s, c in zip(seeds, cells):
            self.assertTrue(L._in_poly(s[0], s[1], c))

    def test_ground_is_stable_for_a_built_hex(self):
        land = L.Landscape(WORLD, TILES)
        pos = next(p for p, t in WORLD.terrain.items() if t == "plains")
        a = land.ground(pos, 21, "summer")
        self.assertIs(land.ground(pos, 21, "summer", build=False), a)
        self.assertIsNone(land.ground((0, 0), 21, "summer", build=False) if (0, 0) not in WORLD.terrain else None)


if __name__ == "__main__":
    unittest.main()
