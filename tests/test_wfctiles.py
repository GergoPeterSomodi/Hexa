"""Edge-socket tiles (hexa.campaign.wfctiles): the overlay is deterministic whatever was drawn before it, edges of
neighbouring tiles line up, the pieces cached for speed (props, recycled canvases) leave no trace, and the bleed keeps
the edges free of dark fringes. Headless: SDL runs with the dummy video driver.
Run with:  python -m unittest tests.test_wfctiles"""
import hashlib
import os
import subprocess
import sys
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa import hexgrid  # noqa: E402
from hexa.campaign import wfctiles as w  # noqa: E402
from hexa.campaign.render import cache as render_cache  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = w.tile


def setUpModule():
    pygame.init()
    if pygame.display.get_surface() is None:
        pygame.display.set_mode((5, 5))


def sample_descs():
    """A spread of tiles: coasts, rivers, roads, bridges, walls, towns of every level, castles, peaks, marsh."""
    return [T(sea=[0]), T(sea=[1, 2, 3], variant=1), T(sea=[0, 1, 2, 3, 4, 5]), T(base="shallow"), T(base="reef"),
            T(river=[3]), T(river=[1, 4, 5], variant=1), T(river=[4], sea=[0, 1, 2], mouth=True), T(lake=True),
            T(road=[0, 3]), T(paved=[1, 4]), T(river=[1, 4], road=[0, 3]),
            T(river=[1, 4], road=[0, 3], crossing="ferry"), T(town=1), T(town=2, road=[0, 3]),
            T(town=3, sea=[1, 2, 3], paved=[5]), T(town=4, paved=[1, 4]), T(town=5, town_in=[2, 3], paved=[3]),
            T(town=6, paved=[2, 5], variant=1), T(wall=2, road=[0, 3]), T(wall=3, town_in=[1, 2], road=[3]),
            T(castle=1, road=[4]), T(castle=2, road=[1]), T(castle=3, road=[2, 5]), T(base="mountains", road=[0, 3]),
            T(base="marsh", river=[0, 3])]


def pixels(img):
    return pygame.image.tobytes(img, "RGBA")


def clear_caches():
    render_cache.clear_all()
    del w._POOL[:]


class Determinism(unittest.TestCase):
    def test_same_pixels_whatever_was_drawn_before(self):
        descs = sample_descs()
        clear_caches()
        first = [pixels(w.overlay(d)) for d in descs]
        clear_caches()
        second = [pixels(w.overlay(d)) for d in reversed(descs)][::-1]       # other order: other recycled canvases
        for d, a, b in zip(descs, first, second):
            self.assertEqual(a, b, f"overlay differs with the drawing history: {d}")

    def test_cached_overlay_is_the_same_object(self):
        d = T(town=2, road=[0, 3])
        self.assertIs(w.overlay(d), w.overlay(d))

    def test_same_pixels_in_another_process(self):
        code = ("import os, sys, hashlib\n"
                "os.environ['SDL_VIDEODRIVER'] = 'dummy'\n"
                f"sys.path.insert(0, {ROOT!r})\n"
                "import pygame\n"
                "pygame.init(); pygame.display.set_mode((5, 5))\n"
                "from tests.test_wfctiles import sample_descs, pixels\n"
                "from hexa.campaign import wfctiles as w\n"
                "h = hashlib.sha256()\n"
                "for d in sample_descs():\n"
                "    h.update(pixels(w.overlay(d)))\n"
                "print(h.hexdigest())\n")
        outs = []
        for seed in ("1", "977"):                              # hash randomisation must not matter
            env = dict(os.environ, PYTHONHASHSEED=seed, SDL_VIDEODRIVER="dummy")
            out = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, env=env, cwd=ROOT)
            self.assertEqual(out.returncode, 0, out.stderr)
            outs.append(out.stdout.strip().splitlines()[-1])
        self.assertEqual(outs[0], outs[1])
        here = hashlib.sha256()
        for d in sample_descs():
            here.update(pixels(w.overlay(d)))
        self.assertEqual(outs[0], here.hexdigest())


class Sockets(unittest.TestCase):
    def test_neighbours_agree_along_their_shared_edge(self):
        """Where a river, road, wall or shoreline crosses an edge, the tile across the edge has it at the same place."""
        total = bad = 0
        for seed in (1, 2, 3):
            patch = w.generate_patch(14, 10, seed)
            self.assertEqual(w.check_patch(patch), [])
            for p, d in patch.items():
                near = list(hexgrid.neighbors(p))
                for e in range(6):
                    q = near[e]
                    if q not in patch or q < p:
                        continue
                    a, b = w.overlay(d), w.overlay(patch[q])
                    n = w.normal(e)
                    tg = (-n[1], n[0])
                    miss = 0
                    for s in range(-26, 27):                  # along the edge, 2 px inside each tile
                        xa, ya = w.CX + n[0] * (w.A - 2) + tg[0] * s, w.CY + n[1] * (w.A - 2) + tg[1] * s
                        xb, yb = w.CX - n[0] * (w.A - 2) + tg[0] * s, w.CY - n[1] * (w.A - 2) + tg[1] * s
                        if abs(a.get_at((int(xa), int(ya))).a - b.get_at((int(xb), int(yb))).a) > 100:
                            miss += 1
                    total += 53
                    bad += miss
                    self.assertLessEqual(miss, 8, f"{p} edge {e}: {miss} of 53 points differ")
        self.assertLess(bad, total * 0.01)

    def test_overlay_stays_inside_the_hex(self):
        img = w.overlay(T(base="sea"))
        self.assertEqual(img.get_size(), (w.W, w.H))
        for corner in ((0, 0), (w.W - 1, 0), (0, w.H - 1), (w.W - 1, w.H - 1)):
            self.assertEqual(img.get_at(corner).a, 0)
        self.assertEqual(img.get_at((w.W // 2, w.H // 2)).a, 255)


class Edges(unittest.TestCase):
    def test_no_dark_fringe(self):
        """Soft edge pixels keep the colour of the drawing next to them (smoothscale would average in black)."""
        for d in (T(road=[0, 3]), T(paved=[1, 4]), T(river=[0, 3]), T(sea=[1, 2]), T(castle=2, road=[4])):
            img = w.overlay(d)
            for y in range(1, w.H - 1):
                for x in range(1, w.W - 1):
                    c = img.get_at((x, y))
                    if not 25 <= c.a <= 230:
                        continue
                    near = [img.get_at((x + dx, y + dy)) for dy in (-2, -1, 0, 1, 2) for dx in (-2, -1, 0, 1, 2)
                            if 0 <= x + dx < w.W and 0 <= y + dy < w.H]
                    solid = [q for q in near if q.a >= 250]
                    if solid:
                        gap = min(max(abs(q.r - c.r), abs(q.g - c.g), abs(q.b - c.b)) for q in solid)
                        self.assertLessEqual(gap, 90, f"dark fringe at {(x, y)} of {d}")

    def test_scaled_tile_has_no_dark_fringe(self):
        img = w.scale_tile(w.overlay(T(road=[0, 3])), 60, 70)
        for y in range(img.get_height()):
            for x in range(img.get_width()):
                c = img.get_at((x, y))
                if 20 <= c.a <= 235:
                    self.assertGreater(c.r + c.g + c.b, 150, f"dark pixel {(x, y)} {tuple(c)}")


class Props(unittest.TestCase):
    def test_props_are_drawn_once_and_blitted(self):
        clear_caches()
        w.overlay(T(town=2, road=[0, 3]))
        n = len(w._SPRITES)
        self.assertGreater(n, 0)
        w.overlay(T(town=2, road=[1, 4], variant=1))
        self.assertLess(len(w._SPRITES) - n, n)                  # mostly the same few houses again

    def test_canvas_is_recycled(self):
        clear_caches()
        w.overlay(T(road=[0, 3]))
        self.assertEqual(len(w._POOL), 1)
        a = pixels(w.overlay(T(river=[1, 4])))
        self.assertEqual(len(w._POOL), 1)                        # the same three surfaces came back
        clear_caches()
        self.assertEqual(a, pixels(w.overlay(T(river=[1, 4]))))  # and left nothing behind on the next tile


if __name__ == "__main__":
    unittest.main()
