"""Town names on the political map: no two drawn names overlap at the hex radii 8, 13, 21 and 34 (over the Low Countries
and southern Germany, and over the whole map), the player's capital and the selected province are always drawn, and
the placement is cached on the zoom, the fog stamp and the focus. Headless.
Run with:  python -m unittest tests.test_town_labels"""
import os
import unittest
from types import SimpleNamespace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

from hexa.campaign import geo, mapview  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402

TILES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hexagon-pack", "PNG", "Tiles")
REGIONS = {"low countries": (4.4, 51.0), "southern Germany": (11.0, 48.3)}
RADII = (8, 13, 21, 34)
VIEW = (900, 600)
WORLD = None


def setUpModule():
    global WORLD
    pygame.init()
    if pygame.display.get_surface() is None:
        pygame.display.set_mode((5, 5))
    WORLD = CampaignWorld(1480)


def ui(province=None):
    return SimpleNamespace(selected=None, reach=None, province=province, hover=None, group=[], anim=None)


def view_at(r):
    view = mapview.MapView(WORLD, TILES)
    view.zoom = mapview.ZOOMS.index(r)
    return view


def frame(view, lon, lat, province=None):
    """Draws one frame centred on (lon, lat); returns the [(pos, rect)] of the town names drawn."""
    x, y = view.center(geo.hex_of(lon, lat))
    camera = [x - VIEW[0] / 2, y - VIEW[1] / 2]
    screen = pygame.Surface(VIEW)
    view.draw(screen, pygame.Rect(0, 0, *VIEW), camera, ui(province))
    return list(view._drawn_labels)


def first_clash(drawn):
    for i, (pa, a) in enumerate(drawn):
        for pb, b in drawn[i + 1:]:
            if a.colliderect(b):
                return f"{pa} {a} and {pb} {b}"
    return None


def set_player(tag):
    WORLD.player = tag
    WORLD._explore_home(WORLD.countries[tag])
    WORLD.update_visibility()
    WORLD.changed()


class NoOverlap(unittest.TestCase):
    def tearDown(self):
        WORLD.player = None
        WORLD.changed()

    def test_drawn_names_never_overlap_in_the_regions(self):
        set_player("BUR")
        for r in RADII:
            for name, (lon, lat) in REGIONS.items():
                drawn = frame(view_at(r), lon, lat)
                self.assertIsNone(first_clash(drawn), f"r={r} {name}")
                if r >= 13:
                    self.assertGreater(len(drawn), 5, f"r={r} {name}: the names are drawn")

    def test_the_placement_never_overlaps_on_the_whole_map(self):
        set_player("BUR")
        for r in RADII:
            view = view_at(r)
            rects = []
            for pos, (dx, dy, shade, _) in view._town_labels().items():
                cx, cy = view.center(pos)
                rects.append((pos, pygame.Rect(round(cx + dx), round(cy + dy), shade.get_width(), shade.get_height())))
            self.assertIsNone(first_clash(rects), f"r={r}")


class Priority(unittest.TestCase):
    def tearDown(self):
        WORLD.player = None
        WORLD.changed()

    def test_the_capital_name_is_always_drawn(self):
        set_player("BUR")
        capital = WORLD.countries["BUR"].capital
        for r in (13, 21, 34):
            drawn = frame(view_at(r), *REGIONS["low countries"])
            self.assertIn(capital, [pos for pos, _ in drawn], f"r={r}: the capital's name")

    def test_the_selected_province_name_is_always_drawn(self):
        set_player("BUR")
        antwerp = next(p for p in WORLD.provinces.values() if p.name == "Antwerp")
        for r in (13, 21, 34):
            drawn = frame(view_at(r), *REGIONS["low countries"], province=antwerp)
            self.assertIn(antwerp.pos, [pos for pos, _ in drawn], f"r={r}: the selected province's name")
            self.assertIsNone(first_clash(drawn), f"r={r} with the selection")


class Cache(unittest.TestCase):
    def tearDown(self):
        WORLD.player = None
        WORLD.changed()

    def test_placement_is_kept_until_the_zoom_fog_or_focus_changes(self):
        set_player("BUR")
        view = view_at(13)
        first = view._town_labels()
        self.assertIs(view._town_labels(), first)                       # the same key: the same placement
        frame(view, *REGIONS["southern Germany"])                       # a pan: the window does not change it
        self.assertIs(view._town_labels(), first)
        view.zoom = mapview.ZOOMS.index(21)
        self.assertIsNot(view._town_labels(), first)                    # a new zoom
        second = view._town_labels()
        WORLD.changed()
        self.assertIsNot(view._town_labels(), second)                   # a new world version
        self.assertGreater(view._label_stats["placed"], 0)


if __name__ == "__main__":
    unittest.main()
