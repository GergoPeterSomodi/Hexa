"""Ridge crest art: the looks of the crest edges, the pass saddles, the peaks, and the far-zoom fold. The rule
(which edges block, which passes close) is the world's; this is only how it looks. Headless.
Run with:  python -m unittest tests.test_ridge_art"""
import os
import tempfile
import unittest
from types import SimpleNamespace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa import settings  # noqa: E402
from hexa.campaign import landscape as L  # noqa: E402
from hexa.campaign import mapview  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402
from hexa.hexgrid import neighbors  # noqa: E402

TILES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hexagon-pack", "PNG", "Tiles")
WORLD = None
LAND = None


def setUpModule():
    global WORLD, LAND
    pygame.init()
    if pygame.display.get_surface() is None:
        pygame.display.set_mode((5, 5))
    WORLD = CampaignWorld(1480)
    LAND = L.Landscape(WORLD, TILES)


def ui():
    return SimpleNamespace(selected=None, reach=None, province=None, hover=None, group=[], anim=None)


def snapshot(img):
    return pygame.image.tobytes(img, "RGBA")


class Looks(unittest.TestCase):
    def test_every_crest_edge_has_a_look_in_both_hexes(self):
        ridges = LAND.ridges()
        self.assertGreater(len(WORLD.ridge_edges()), 100)
        for edge in WORLD.ridge_edges():
            a, b = sorted(edge)
            ia, ib = list(neighbors(a)).index(b), list(neighbors(b)).index(a)
            self.assertIn(ridges.look_of(a, ia)["kind"], L.RANK)
            self.assertIn(ridges.look_of(b, ib)["kind"], L.RANK)
        self.assertEqual(set(WORLD.ridge_edges()) | {e for _, _, e, _ in WORLD.pass_edges()}, set(ridges.look))

    def test_the_four_looks_all_occur(self):
        kinds = {lk["kind"] for lk in LAND.ridges().look.values()}
        self.assertEqual(kinds, {"alpine", "rocky", "forest", "scarp"})

    def test_the_alps_are_alpine_and_the_apennines_are_not(self):
        ridges = LAND.ridges()
        gotthard = next(e for n, _, e, _ in WORLD.pass_edges() if n == "Gotthard")
        self.assertEqual(ridges.look[gotthard]["kind"], "alpine")
        cisa = next(e for n, _, e, _ in WORLD.pass_edges() if n == "Cisa")
        self.assertNotEqual(ridges.look[cisa]["kind"], "alpine")

    def test_range_heights_come_from_the_geography(self):
        self.assertEqual(len(WORLD.geo.MOUNTAIN_HEIGHT), len(WORLD.geo.MOUNTAINS))
        self.assertEqual(max(WORLD.geo.MOUNTAIN_HEIGHT), 1.0)


class Determinism(unittest.TestCase):
    def crest_hex(self):
        ridges = LAND.ridges()
        return next(p for p in sorted(ridges.crest) if ridges.key(p, "summer") != ridges.key(p, "winter"))

    def test_same_desc_same_pixels_and_objects(self):
        pos = self.crest_hex()
        other = L.Landscape(WORLD, TILES)
        for season in ("summer", "winter"):
            self.assertEqual(snapshot(LAND.ground(pos, 34, season)), snapshot(other.ground(pos, 34, season)))
            self.assertEqual(LAND._specs(LAND._cell(pos, season), season), other._specs(other._cell(pos, season), season))

    def test_cache_keys_change_with_season_and_crest(self):
        ridges = LAND.ridges()
        pos = self.crest_hex()
        self.assertNotEqual(ridges.key(pos, "summer"), ridges.key(pos, "winter"))
        self.assertNotEqual(ridges.key(pos, "summer"), ())
        plain = next(p for p, t in WORLD.terrain.items() if t == "plains" and p not in ridges.crest
                     and p not in ridges.passe)
        self.assertEqual(ridges.key(plain, "summer"), ())
        self.assertNotEqual(snapshot(LAND.ground(pos, 34, "summer")), snapshot(LAND.ground(pos, 34, "winter")))

    def test_the_crest_is_in_the_ground(self):
        """The same hex with its crest looks removed draws differently (the crest is part of the composite)."""
        pos = self.crest_hex()
        a = LAND.ground(pos, 34, "summer")
        other = L.Landscape(WORLD, TILES)
        other.ridges().crest.pop(pos), other.ridges().passe.pop(pos, None)
        self.assertNotEqual(snapshot(a), snapshot(other.ground(pos, 34, "summer")))


class Roads(unittest.TestCase):
    def test_no_road_crosses_a_crest_edge(self):
        for season in ("summer", "winter"):
            for pos, edges in LAND.ridges().crest.items():
                c = LAND._cell(pos, season)
                if c is not None and c.desc is not None:
                    self.assertFalse(c.desc.road & set(edges), f"{pos} {season}")

    def test_a_road_laid_over_a_crest_is_cut_and_the_others_stay(self):
        land = L.Landscape(WORLD, TILES)
        land._sync()
        ridges = land.ridges()
        pos = sorted(ridges.crest)[0]
        crest = sorted(ridges.crest[pos])[0]
        free = next(e for e in range(6) if e not in ridges.crest[pos] and e not in ridges.passe.get(pos, {}))
        land._roads[pos] = {crest, free}
        land._cells.clear()
        desc = land._cell(pos, "summer").desc
        self.assertIsNotNone(desc)
        self.assertNotIn(crest, desc.road)
        self.assertIn(free, desc.road)

    def test_tile_art_cuts_them_too(self):
        view = mapview.MapView(WORLD, TILES)
        for pos, edges in LAND.ridges().crest.items():
            prov = WORLD.provinces.get(pos)
            if prov is None:
                continue
            desc = view.overlay_desc(prov)
            if desc is not None:
                self.assertFalse(desc.road & set(edges), f"{pos}")


class Passes(unittest.TestCase):
    def test_nothing_tall_stands_on_a_pass_track_or_saddle(self):
        ridges = LAND.ridges()
        hexes = set()
        for _, a, b in ridges.pass_sites():
            hexes |= {a, b}
            hexes |= set(neighbors(a)) | set(neighbors(b))
        checked = 0
        for pos in sorted(hexes):
            for season in ("summer", "winter"):
                c = LAND._cell(pos, season)
                if c is None or c.water:
                    continue
                for cat, name, _, _, x, y in LAND._specs(c, season):
                    if cat in ("peak", "tree"):
                        checked += 1
                        self.assertFalse(ridges.on_pass(pos, x, y), f"{name} on a pass at {pos} {season}")
        self.assertGreater(checked, 200)

    def test_old_markers_are_gone(self):
        self.assertFalse(hasattr(LAND, "closed_marker"))
        self.assertFalse(hasattr(LAND, "closed_pass"))
        self.assertNotIn("closed", LAND.cell_info((149, 45), "winter"))
        self.assertFalse(hasattr(mapview.MapView, "_closed_passes"))
        self.assertFalse(hasattr(mapview.MapView, "pass_chip"))
        self.assertNotIn("barrier", L.PIECES)
        self.assertNotIn("pass_badge", L.PIECES)
        for _, a, _ in LAND.ridges().pass_sites():
            names = [n for _, n in LAND.object_names(a, "winter")]
            self.assertFalse({"barrier", "pass_badge", "closed_chip"} & set(names))

    def test_a_pass_shows_a_hospice_in_summer_and_a_snowmark_in_winter(self):
        ridges = LAND.ridges()
        summer = winter = 0
        for name, (pos, _) in ridges.hospice.items():
            summer += "hospice" in [n for _, n in LAND.object_names(pos, "summer")]
            winter += "snowmark" in [n for _, n in LAND.object_names(pos, "winter")]
        self.assertGreater(summer, 3)
        self.assertGreater(winter, 10)

    def test_the_winter_saddle_is_snow_and_the_summer_one_is_not(self):
        pos = next(iter(ridges_hexes()))
        summer, winter = LAND.ground(pos, 34, "summer"), LAND.ground(pos, 34, "winter")
        self.assertNotEqual(snapshot(summer), snapshot(winter))


def ridges_hexes():
    return sorted(LAND.ridges().passe)


class Peaks(unittest.TestCase):
    def test_fewer_peaks_per_mountain_hex(self):
        """The landscape's own peaks are about half of the old 2.7 per mountain or snow hex."""
        m = LAND._model("summer")
        total = n = 0
        for pos, terrain in WORLD.terrain.items():
            if terrain in ("mountains", "snow"):
                out = []
                c = LAND._cell(pos, "summer")
                X, Y = L.hex_centre(pos)
                LAND._relief(out, m, c, X, Y, False)
                total += sum(1 for o in out if o[0] == "peak")
                n += 1
        self.assertLessEqual(total / n, 1.6)
        self.assertGreaterEqual(total / n, 1.0)

    def test_a_crest_hex_gets_one_to_three_crest_objects_per_edge(self):
        ridges = LAND.ridges()
        checked = 0
        for pos, edges in sorted(ridges.crest.items())[:400]:
            c = LAND._cell(pos, "summer")
            if c is None or L._crowded(c) or c.water or pos in ridges.passe:
                continue
            added = LAND._ridge_objects(c, "summer", [])          # only what the crest adds
            self.assertGreaterEqual(len(added), 1, f"{pos}")
            self.assertLessEqual(len(added), 3 * len(edges), f"{pos}")
            checked += 1
        self.assertGreater(checked, 100)


class RandomWorlds(unittest.TestCase):
    def test_random_worlds_have_crests_and_draw_them(self):
        world = CampaignWorld(7, map="random")
        land = L.Landscape(world, TILES)
        ridges = land.ridges()
        self.assertGreater(len(ridges.look), 5)
        self.assertEqual(len(world.geo.MOUNTAIN_HEIGHT), len(world.geo.MOUNTAINS))
        pos = sorted(ridges.crest)[0]
        for season in ("summer", "winter"):
            self.assertIsNotNone(land.ground(pos, 34, season))
            land.objects(pos, 34, season)


class PassNames(unittest.TestCase):
    def labels(self, r, on=True):
        world = CampaignWorld(1480)
        view = mapview.MapView(world, TILES)
        view.zoom = mapview.ZOOMS.index(r)
        view.pass_names_on = on
        name, a, b = next(s for s in view.land.ridges().pass_sites() if s[0] == "Gotthard")
        x, y = view.center(a)
        screen = pygame.Surface((700, 500))
        for _ in range(6):
            view.draw(screen, pygame.Rect(0, 0, 700, 500), [x - 350, y - 250], ui())
        return [k for k, _ in view._drawn_labels if isinstance(k, tuple) and k[0] == "pass"], view

    def test_names_only_at_the_closest_zoom(self):
        self.assertIn(("pass", "Gotthard"), self.labels(34)[0])
        self.assertEqual(self.labels(21)[0], [])
        self.assertEqual(self.labels(13)[0], [])

    def test_the_setting_hides_them_and_persists(self):
        self.assertEqual(self.labels(34, on=False)[0], [])
        self.assertFalse(settings.DEFAULTS["pass_names"])     # off by default (owner, 2026-11-12)
        old = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = tempfile.mkdtemp()
        try:
            s = settings.load()
            self.assertFalse(s["pass_names"])
            settings.cycle(s, "pass_names")
            self.assertTrue(s["pass_names"])
            self.assertTrue(settings.save(s))
            self.assertTrue(settings.load()["pass_names"])
        finally:
            if old is None:
                os.environ.pop("HEXA_HOME", None)
            else:
                os.environ["HEXA_HOME"] = old

    def test_the_plates_keep_clear_of_towns_and_the_hospice(self):
        view = self.labels(34)[1]
        rects = [box for k, box in view._drawn_labels]
        for i, a in enumerate(rects):
            for b in rects[i + 1:]:
                self.assertFalse(a.colliderect(b), "two names overlap")


class FarZooms(unittest.TestCase):
    def test_the_flat_map_is_cached_per_season(self):
        world = CampaignWorld(1480)
        view = mapview.MapView(world, TILES)
        view.zoom = 0
        world.turn = 2
        summer = view.surface()
        self.assertIs(view.surface(), summer)
        world.turn = 4
        self.assertIsNot(view.surface(), summer)
        world.turn = 1

    def test_the_fold_is_drawn_at_r13_and_r5(self):
        for r in (13, 5):
            world = CampaignWorld(1480)
            view = mapview.MapView(world, TILES)
            view.zoom = mapview.ZOOMS.index(r)
            a, b = next((a, b) for n, a, b in view.land.ridges().pass_sites() if n == "Gotthard")
            x, y = view.center(a)
            rect = pygame.Rect(0, 0, 600, 400)
            with_fold, without = pygame.Surface((600, 400)), pygame.Surface((600, 400))
            view.draw(with_fold, rect, [x - 300, y - 200], ui())
            view2 = mapview.MapView(world, TILES)
            view2.zoom = view.zoom
            view2._ridge_items = lambda *a, **k: []
            view2.draw(without, rect, [x - 300, y - 200], ui())
            diff = sum(1 for yy in range(0, 400, 2) for xx in range(0, 600, 2)
                       if with_fold.get_at((xx, yy)) != without.get_at((xx, yy)))
            self.assertGreater(diff, 150, f"r={r}")


if __name__ == "__main__":
    unittest.main()
