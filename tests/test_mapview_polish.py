"""Map view polish: the closed-pass marker at the far zooms, town names over unit tokens, and the speed-ups that must
not change the picture (Voronoi field cells, the tree lattice, the cached ground lookup). Headless.
Run with:  python -m unittest tests.test_mapview_polish"""
import os
import random
import unittest
from types import SimpleNamespace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

from hexa.campaign import geo  # noqa: E402
from hexa.campaign import wfctiles  # noqa: E402
from hexa.campaign import landscape as L  # noqa: E402
from hexa.campaign import mapview  # noqa: E402
from hexa.campaign import app as appmod  # noqa: E402
from hexa.campaign import saves  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402
from hexa.hexgrid import neighbors  # noqa: E402
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


class Round4(unittest.TestCase):
    """#93, #94, #95, #96, #98."""

    @staticmethod
    def ui():
        return SimpleNamespace(selected=None, reach=None, province=None, hover=None, group=[], anim=None)

    def test_trees_stay_out_of_the_water(self):
        """#96: no tree stands in the water that a coast hex's overlay draws."""
        land = L.Landscape(WORLD, TILES)
        m = land._model("summer")
        checked = 0
        for pos in sorted(WORLD.terrain):
            c = m.cells.get(pos)
            if c is None or c.water or c.desc is None or not c.desc.sea or pos[0] % 3:
                continue
            X, Y = L.hex_centre(pos)
            geo_ = wfctiles._coast_geo(c.desc.sea, c.desc.variant, wfctiles.COAST_RD - 8 if c.desc.town else wfctiles.COAST_RD)
            for cat, _, _, _, x, y in land._specs(c, "summer"):
                if cat == "tree":
                    checked += 1
                    tx, ty = wfctiles.CX + (x - X) * wfctiles.R, wfctiles.CY + (y - Y) * wfctiles.R
                    self.assertFalse(wfctiles._covers(geo_["water"], tx, ty), f"tree in the sea of {pos}")
        self.assertGreater(checked, 200)

    def test_borders_stay_in_every_map_mode(self):
        """#98: the terrain, goods and markets modes draw the owner borders (fainter)."""
        for r in (21, 13):
            for mode in ("terrain", "goods", "markets"):
                view = mapview.MapView(WORLD, TILES)
                view.zoom = mapview.ZOOMS.index(r)
                view.mode = mode
                calls = []
                real = view._owner_borders
                view._owner_borders = lambda screen, shown, alpha=255: (calls.append(alpha), real(screen, shown, alpha))
                x, y = view.center(Seams.plains())
                view.draw(pygame.Surface((700, 500)), pygame.Rect(0, 0, 700, 500), [x - 350, y - 250], self.ui())
                self.assertEqual(calls, [mapview.MODE_BORDERS], f"r={r} {mode}")

    def test_clip_mask_keeps_the_colour_it_clips(self):
        """#93: the antialiased edge pixels of a clipped picture must not be darkened (a black mask zeroed them)."""
        pic = pygame.Surface((40, 40), pygame.SRCALPHA)
        pic.fill((60, 170, 90, 255))
        mask = L.clip_mask((40, 40))
        pygame.draw.polygon(mask, (255, 255, 255, 255), [(20, 2), (38, 12), (38, 30), (20, 38), (2, 30), (2, 12)])
        pic.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        small = pygame.transform.smoothscale(pic, (20, 20))
        for y in range(20):
            for x in range(20):
                c = small.get_at((x, y))
                if c.a:
                    self.assertGreaterEqual(c.g, 165, f"darkened edge pixel {(x, y)} {tuple(c)}")

    def test_ground_edge_pixels_are_not_darker_than_the_ground(self):
        land = L.Landscape(WORLD, TILES)
        pos = Seams.plains()
        g = land.ground(pos, 34, "summer")
        w, h = g.get_size()
        inner = g.get_at((w // 2, int(h * 0.35)))
        for x in range(w):
            for y in range(h):
                c = g.get_at((x, y))
                if 0 < c.a < 255 and abs(c.g - inner.g) < 60:        # (band decorations are far from the ground's colour)
                    self.assertGreaterEqual(c.g, inner.g * 0.8, f"dark edge pixel {(x, y)} {tuple(c)}")

    def test_the_far_zoom_shade_is_one_sheet(self):
        """#95: unseen hexes are shaded as one sheet, not hex by hex: no line over open sea."""
        world = CampaignWorld(1480, player="POR")
        country = world.countries[world.player]
        country.explored = set(world.terrain)
        world.visible = set()
        world.changed()
        for r in (3, 5, 8):
            view = mapview.MapView(world, TILES)
            view.zoom = mapview.ZOOMS.index(r)
            surf = view.surface()
            sea = [p for p, t in world.terrain.items() if t == "ocean"
                   and all(world.terrain.get(n) == "ocean" for q in neighbors(p) for n in neighbors(q))]
            x, y = view.center(sea[len(sea) // 2])
            colours = {tuple(surf.get_at((int(x) + dx, int(y) + dy)))[:3] for dx in range(-3 * r, 3 * r)
                       for dy in range(-r, r)}
            self.assertLessEqual(len(colours), 2, f"r={r}: {len(colours)} colours over open sea")

    def zoom_frames(self, r0, r1, mode="political", pos=None, frames=1):
        """Draw at r0 until settled, then at r1: the first frame(s) after the change. Returns (view, screens)."""
        view = mapview.MapView(WORLD, TILES)
        view.mode = mode
        x, y = view.center(pos or Seams.plains())
        u = ((x - view.MARGIN) / view.r, (y - view.MARGIN) / view.r)           # the hex centre in hex radii
        rect = pygame.Rect(0, 0, 700, 500)

        def cam(r):
            return [view.MARGIN + u[0] * r - 350, view.MARGIN + u[1] * r - 250]
        screen = pygame.Surface((700, 500))
        view.zoom = mapview.ZOOMS.index(r0)
        for _ in range(8):
            view.draw(screen, rect, cam(r0), self.ui())
        view.zoom = mapview.ZOOMS.index(r1)
        shots = []
        for _ in range(frames):
            view.draw(screen, rect, cam(r1), self.ui())
            shots.append(screen.copy())
        return view, shots, (rect, cam(r1))

    def test_zoom_change_keeps_a_backdrop_until_the_view_is_built(self):
        """#94: the old frame, scaled, stands in for the new zoom's unbuilt hexes (zooming in and out)."""
        for r0, r1 in ((34, 21), (13, 21), (21, 34)):
            view, _, (rect, cam) = self.zoom_frames(r0, r1)
            self.assertIsNotNone(view._backdrop, f"{r0} to {r1}")
            surf = view._backdrop[0]
            k = r1 / r0
            # only the part of the old frame that lands in the view is scaled: never much more than one view
            self.assertLessEqual(surf.get_width(), rect.w + 8 * k, f"{r0} to {r1}")
            self.assertLessEqual(surf.get_height(), rect.h + 8 * k, f"{r0} to {r1}")
            screen = pygame.Surface((700, 500))
            for _ in range(300):
                view.draw(screen, rect, cam, self.ui())
                if view._backdrop is None:
                    break
            self.assertIsNone(view._backdrop, f"{r0} to {r1}: the stand-in goes once the view is built")

    def test_a_big_zoom_jump_has_no_backdrop(self):
        view, _, _ = self.zoom_frames(13, 34)
        self.assertIsNone(view._backdrop, "13 to 34 would be a smear: no stand-in")

    def test_the_backdrop_carries_no_extra_tint(self):
        """The washes are not laid on the stand-in a second time: its colour matches the built hex (markets mode)."""
        pos = next(p for p, prov in WORLD.provinces.items() if prov.market is not None and prov.owner)
        view, shots, _ = self.zoom_frames(34, 21, mode="markets", pos=pos, frames=1)
        first = shots[0]
        screen = pygame.Surface((700, 500))
        _, _, (rect, cam) = self.zoom_frames(34, 21, mode="markets", pos=pos, frames=1)
        view.mode = "markets"
        for _ in range(300):
            view.draw(screen, rect, cam, self.ui())
            if view._backdrop is None:
                break

        def mean(img):
            box = img.subsurface((350 - 8, 250 - 8, 16, 16))
            return pygame.transform.average_color(box)[:3]
        a, b = mean(first), mean(screen)
        for ca, cb in zip(a, b):
            self.assertLessEqual(abs(ca - cb), 3, f"stand-in {a} against built {b}")

    def test_the_borders_layer_is_reused_and_borders_show(self):
        """#98 (and the per-frame allocation): one layer for all frames; the faint borders are really on screen."""
        view = mapview.MapView(WORLD, TILES)
        view.zoom = mapview.ZOOMS.index(21)
        view.mode = "terrain"
        x, y = view.center(Seams.plains())
        rect = pygame.Rect(0, 0, 700, 500)
        cam = [x - 350, y - 250]
        with_borders = pygame.Surface((700, 500))
        view.draw(with_borders, rect, cam, self.ui())
        layers = {k: v for k, v in view._tint_layers.items() if k[0] == "borders"}
        self.assertEqual(len(layers), 1)
        view.draw(pygame.Surface((700, 500)), rect, cam, self.ui())
        self.assertEqual({k: v for k, v in view._tint_layers.items() if k[0] == "borders"}, layers)
        for k, layer in layers.items():
            self.assertIs(view._tint_layers[k], layer)
        view2 = mapview.MapView(WORLD, TILES)
        view2.zoom = view.zoom
        view2.mode = "terrain"
        view2._owner_borders = lambda *a, **k: None
        without = pygame.Surface((700, 500))
        view2.draw(without, rect, cam, self.ui())
        differing = sum(1 for yy in range(0, 500, 2) for xx in range(0, 700, 2)
                        if with_borders.get_at((xx, yy)) != without.get_at((xx, yy)))
        self.assertGreater(differing, 40, "the borders show on screen")


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
