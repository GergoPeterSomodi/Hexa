"""Map view polish: the closed-pass marker at the far zooms, town names over unit tokens, and the speed-ups that must
not change the picture (Voronoi field cells, the tree lattice, the cached ground lookup). Headless.
Run with:  python -m unittest tests.test_mapview_polish"""
import os
import random
import unittest
from types import SimpleNamespace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa.campaign import geo  # noqa: E402
from hexa.campaign import landscape as L  # noqa: E402
from hexa.campaign import mapview  # noqa: E402
from hexa.campaign import app as appmod  # noqa: E402
from hexa.campaign import saves  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402
from tests.test_saves import TempHome  # noqa: E402

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


class Seams(unittest.TestCase):
    """#71: with the grid off, neighbouring land hexes join without a gap or a line."""

    @staticmethod
    def plains():
        centre = geo.hex_of(2.3, 47.0)                  # the plains south of Paris, well inside the known world
        return min((p for p, t in WORLD.terrain.items() if t == "plains" and p in WORLD.provinces
                    and not WORLD.provinces[p].settlement),
                   key=lambda p: (p[0] - centre[0]) ** 2 + (p[1] - centre[1]) ** 2)

    def test_ground_edges_are_opaque(self):
        land = L.Landscape(WORLD, TILES)
        for r in (34, 21):
            g = land.ground(self.plains(), r, "summer")
            w, h = g.get_size()
            for y in range(int(h * 0.3), int(h * 0.7)):
                for x in (0, w - 1):
                    self.assertEqual(g.get_at((x, y)).a, 255, f"r={r}: edge pixel {(x, y)} lets the background through")

    def test_tile_sprites_are_opaque_at_the_edges(self):
        view = mapview.MapView(WORLD, TILES)
        prov = WORLD.provinces[self.plains()]
        for r in (13, 21, 34):
            view.zoom = mapview.ZOOMS.index(r)
            img = view.sprite(view.tile_sprite(prov))
            w, h = img.get_size()
            for y in range(int(h * 0.3), int(h * 0.7)):
                for x in (0, w - 1):
                    self.assertEqual(img.get_at((x, y)).a, 255, f"r={r}: edge pixel {(x, y)}")

    def test_tint_is_one_even_sheet(self):
        view = mapview.MapView(WORLD, TILES)
        for r in (34, 21, 13):
            view.zoom = mapview.ZOOMS.index(r)
            screen = pygame.Surface((1100, 700))
            screen.fill((90, 140, 90))
            base = tuple(screen.get_at((0, 0)))[:3]
            items = []
            for row in range(0, 6):
                for col in range(0, 8):
                    x, y = view.center((col, row))
                    items.append(((0, 0, 0, 105), x, y))
            view._tint(screen, items)
            colours = set()
            for row in range(1, 4):                       # inside the block, across the shared edges
                for col in range(1, 5):
                    x, y = view.center((col, row))
                    for dx in range(-int(r * 0.8), int(r * 0.8) + 1):
                        colours.add(tuple(screen.get_at((int(x + dx), int(y))))[:3])
            self.assertEqual(len(colours), 1, f"r={r}: {len(colours)} colours across the tinted hexes")
            self.assertNotEqual(colours.pop(), base)

    def test_no_background_between_land_hexes(self):
        for r in (34, 21, 13):
            view = mapview.MapView(WORLD, TILES)
            view.zoom = mapview.ZOOMS.index(r)
            view.grid_on = False
            ui = SimpleNamespace(selected=None, reach=None, province=None, hover=None, group=[], anim=None)
            screen = pygame.Surface((700, 500))
            x, y = view.center(self.plains())
            for _ in range(6):                            # a few frames: the composites are built over several
                view.draw(screen, pygame.Rect(0, 0, 700, 500), [x - 350, y - 250], ui)
            self.assertEqual(count(screen, (350, 250), mapview.BLACK_FOG[:3], half=120), 0, f"r={r}")


class FogCaches(unittest.TestCase):
    """#26: hexes explored on the way through a move (no version bump) must redraw the map layer and the minimap."""

    def test_explored_count_is_part_of_the_cache_key(self):
        world = CampaignWorld(1480, player="POR")
        view = mapview.MapView(world, TILES)
        first = view.surface()
        self.assertIs(view.surface(), first)
        country = world.countries[world.player]
        new = next(p for p in world.terrain if p not in country.explored)
        country.explored.add(new)                        # what see_from(refresh=False) does mid-walk
        self.assertIsNot(view.surface(), first)

    def test_minimap_redraws_too(self):
        app = appmod.CampaignApp(player="POR")
        app.draw_minimap()
        key = app._mini_key
        country = app.world.countries[app.world.player]
        country.explored.add(next(p for p in app.world.terrain if p not in country.explored))
        app.draw_minimap()
        self.assertNotEqual(app._mini_key, key)


class Cleanups(TempHome):
    """#33 and #34."""

    def test_loading_builds_one_map_view(self):
        world = CampaignWorld(1480, player="POR")
        saves.save(world, "quick")
        built = []
        real = appmod.MapView

        def counting(*a, **k):
            built.append(1)
            return real(*a, **k)
        appmod.MapView = counting
        try:
            app = appmod.CampaignApp(load="quick")
        finally:
            appmod.MapView = real
        self.assertEqual(len(built), 1)
        self.assertEqual(app.world.player, "POR")
        self.assertIsNotNone(app.view)

    def test_dead_code_is_gone(self):
        self.assertFalse(hasattr(appmod, "SCROLL"))
        self.assertFalse(hasattr(mapview.MapView, "_unit"))


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
