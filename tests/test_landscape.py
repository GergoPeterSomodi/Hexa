"""Landscape art (hexa.campaign.landscape): ground composites, object lists, treeline, clearings, farms, winter and
closed passes. Headless: SDL runs with the dummy video driver. Run with:  python -m unittest tests.test_landscape"""
import math
import os
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

from hexa.campaign import landscape as L  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402
from hexa.hexgrid import neighbors  # noqa: E402

TILES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hexagon-pack", "PNG", "Tiles")
ALPS_PASS = (149, 44)              # the Gotthard hex on the Europe map (closed in winter)
WORLD = None


def setUpModule():
    global WORLD
    pygame.init()
    if pygame.display.get_surface() is None:
        pygame.display.set_mode((5, 5))
    WORLD = CampaignWorld(1480)


def fresh(seed=1480, map="europe"):
    """A new world (the snapshot cache makes this cheap); safe to mutate."""
    return CampaignWorld(seed, map=map)


def cats(names):
    return [cat for cat, _ in names]


def hexes(world, pred):
    for pos in world.terrain:
        if pred(pos):
            yield pos


class GroundTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.land = L.Landscape(WORLD, TILES)

    def expected_size(self, r):
        return int(round(r * math.sqrt(3))) + 1, int(round(r * 70 / (60 / math.sqrt(3)))) + 1

    def test_size_matches_the_game_sprite(self):
        pos = next(hexes(WORLD, lambda p: WORLD.terrain[p] == "plains"))
        for r in (34, 21):
            g = self.land.ground(pos, r, "summer")
            self.assertEqual(g.get_size(), self.expected_size(r), r)
        self.assertEqual(self.land.ground(pos, 34, "summer").get_size(), (60, 70))
        self.assertEqual(self.land.ground(pos, 21, "summer").get_size(), (37, 43))

    def test_deterministic(self):
        pos = (149, 45)
        a = self.land.ground(pos, 34, "summer")
        b = L.Landscape(WORLD, TILES).ground(pos, 34, "summer")
        self.assertEqual(pygame.image.tostring(a, "RGBA"), pygame.image.tostring(b, "RGBA"))

    def test_cached(self):
        pos = (149, 45)
        a = self.land.ground(pos, 34, "summer")
        self.assertIs(a, self.land.ground(pos, 34, "summer"))
        self.assertIsNot(a, self.land.ground(pos, 21, "summer"))

    def test_off_map_and_bad_season(self):
        self.assertIsNone(self.land.ground((-500, -500), 34, "summer"))
        with self.assertRaises(ValueError):
            self.land.ground((149, 45), 34, "autumn")

    def test_water_hex_gets_a_sea_composite(self):
        pos = next(hexes(WORLD, lambda p: WORLD.terrain[p] == "ocean"))
        self.assertEqual(self.land.ground(pos, 34, "summer").get_size(), self.expected_size(34))


class ObjectTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.land = L.Landscape(WORLD, TILES)

    def test_entries_are_surface_offset_sort(self):
        objs = self.land.objects(ALPS_PASS, 34, "summer")
        self.assertTrue(objs)
        for surf, dx, dy, sy in objs:
            self.assertIsInstance(surf, pygame.Surface)
            self.assertIsInstance(dx, float)
            self.assertIsInstance(dy, float)
        self.assertEqual([o[3] for o in objs], sorted(o[3] for o in objs))

    def test_objects_are_cached(self):
        pos = (149, 45)
        self.assertIs(self.land.objects(pos, 34, "summer"), self.land.objects(pos, 34, "summer"))

    def test_forest_hex_has_trees(self):
        def interior_forest(p):
            return WORLD.terrain[p] == "forest" and all(WORLD.terrain.get(n) == "forest" for n in neighbors(p))
        pos = next(hexes(WORLD, interior_forest))
        self.assertIn("tree", cats(self.land.object_names(pos, "summer")))

    def test_high_mountain_above_the_treeline_has_no_trees(self):
        def high(p):
            return WORLD.terrain[p] == "mountains" and self.land.cell_info(p, "summer")["alt"] >= 0.86
        pos = next(hexes(WORLD, high))
        self.assertGreaterEqual(self.land.cell_info(pos, "summer")["alt"], 0.86)
        self.assertNotIn("tree", cats(self.land.object_names(pos, "summer")))

    def test_closed_pass_markers_are_objects_in_winter_only(self):
        self.assertIn("barrier", [n for _, n in self.land.object_names(ALPS_PASS, "winter")])
        self.assertNotIn("barrier", [n for _, n in self.land.object_names(ALPS_PASS, "summer")])
        self.assertIsInstance(self.land.closed_marker(34), pygame.Surface)


class RuleTest(unittest.TestCase):
    def test_town_clears_the_forest_round_it(self):
        world = fresh()
        land = L.Landscape(world, TILES)
        pos = None
        for p, prov in world.provinces.items():
            if world.terrain.get(p) == "forest" and prov.settlement >= 2 and not prov.castle:
                pos = p
                break
        self.assertIsNotNone(pos, "a forest town on the map")
        with_town = cats(land.object_names(pos, "summer")).count("tree")
        prov = world.provinces[pos]
        prov.settlement = 0
        world.changed(ownership=True)
        without = cats(land.object_names(pos, "summer")).count("tree")
        self.assertGreater(without, with_town)
        self.assertEqual(land.cell_info(pos, "summer")["clearing"], 0.0)

    def test_farm_with_works_4_gets_fields(self):
        world = fresh()
        land = L.Landscape(world, TILES)
        pos = next(p for p, prov in world.provinces.items()
                   if world.terrain.get(p) == "plains" and not prov.settlement and not prov.castle and prov.owner)
        before = pygame.image.tostring(land.ground(pos, 34, "summer"), "RGBA")
        prov = world.provinces[pos]
        prov.good, prov.works = "grain", 4
        world.changed()
        self.assertEqual(land.cell_info(pos, "summer")["fields"], 4)
        names = [n for _, n in land.object_names(pos, "summer")]
        self.assertIn("windmill", names)
        self.assertIn("haystack", names)
        self.assertNotEqual(before, pygame.image.tostring(land.ground(pos, 34, "summer"), "RGBA"))

    def test_winter_turns_high_hexes_to_snow(self):
        land = L.Landscape(WORLD, TILES)
        pos = next(hexes(WORLD, lambda p: WORLD.terrain[p] == "mountains"
                         and land.cell_info(p, "summer")["alt"] >= 0.6))
        self.assertIn(land.cell_info(pos, "summer")["ground"], ("alpine", "montane"))
        self.assertEqual(land.cell_info(pos, "winter")["ground"], "snow")
        self.assertIsNotNone(land.ground(pos, 34, "winter"))

    def test_closed_pass_is_art_in_winter_only(self):
        land = L.Landscape(WORLD, TILES)
        self.assertTrue(land.closed_pass(ALPS_PASS, "winter"))
        self.assertFalse(land.closed_pass(ALPS_PASS, "summer"))
        self.assertFalse(land.closed_pass((150, 44), "winter"))
        self.assertTrue(land.cell_info(ALPS_PASS, "winter")["impassable"])

    def test_only_closed_passes_get_the_hatch(self):
        """Snow hexes are passable (move cost 3), so the snow turns white with no hatch; only closed passes get one."""
        land = L.Landscape(WORLD, TILES)
        pos = next(hexes(WORLD, lambda p: WORLD.terrain[p] == "mountains" and p not in WORLD.passes()
                         and land.cell_info(p, "summer")["alt"] >= 0.6))
        info = land.cell_info(pos, "winter")
        self.assertEqual(info["ground"], "snow")
        self.assertFalse(info["impassable"])
        self.assertFalse(info["closed"])
        self.assertFalse(land.closed_pass(pos, "winter"))

    def test_objects_can_wait_until_built(self):
        """build=False returns None for a hex whose object list is not built yet (the frame budget), then it builds."""
        land = L.Landscape(WORLD, TILES)
        pos = next(hexes(WORLD, lambda p: WORLD.terrain[p] == "mountains"))
        self.assertIsNone(land.objects(pos, 21, "summer", build=False))
        n = land.object_builds
        self.assertIsInstance(land.objects(pos, 21, "summer"), list)
        self.assertEqual(land.object_builds, n + 1)
        self.assertIsNotNone(land.objects(pos, 21, "summer", build=False))

    def test_grid_is_its_own_surface_the_size_of_the_ground(self):
        land = L.Landscape(WORLD, TILES)
        pos = next(hexes(WORLD, lambda p: WORLD.terrain[p] == "plains"))
        self.assertEqual(land.grid(34).get_size(), land.ground(pos, 34, "summer").get_size())
        self.assertIs(land.grid(34), land.grid(34))

    def test_season_follows_the_turn(self):
        world = fresh()
        land = L.Landscape(world, TILES)
        world.turn = 4
        self.assertEqual(land.season_now(), "winter")
        world.turn = 5
        self.assertEqual(land.season_now(), "summer")

    def test_sprites_can_be_made_before_the_object_list(self):
        """make_sprites() makes the sprites of a hex (counted in sprite_builds) and objects() then only assembles."""
        L._OB.clear()                       # the sprite cache is module-level: start cold
        land = L.Landscape(WORLD, TILES)
        pos = next(p for p in hexes(WORLD, lambda p: WORLD.terrain[p] == "mountains")
                   if land.object_names(p, "summer"))
        made = land.make_sprites(pos, 21, "summer")
        self.assertGreater(made, 0)
        self.assertEqual(land.sprite_builds, made)
        self.assertEqual(land.make_sprites(pos, 21, "summer"), 0)
        self.assertIsNone(land.objects(pos, 21, "summer", build=False))
        n = land.object_builds
        self.assertIsInstance(land.objects(pos, 21, "summer"), list)
        self.assertEqual(land.object_builds, n + 1)

    def test_overlay_is_prepared_once(self):
        """prepare() makes the hex's wfc overlay and base picture; the second call has nothing to make."""
        land = L.Landscape(WORLD, TILES)
        pos = next(hexes(WORLD, lambda p: WORLD.terrain[p] == "plains"))
        self.assertTrue(land.prepare(pos, 34, "summer"))
        self.assertFalse(land.prepare(pos, 34, "summer"))
        self.assertFalse(land.prepare((-5, -5), 34, "summer"))


class RandomWorldTest(unittest.TestCase):
    def test_runs_on_a_random_world(self):
        world = CampaignWorld(5, map="random")
        land = L.Landscape(world, TILES)
        land_hexes = [p for p, t in world.terrain.items() if t not in ("ocean", "lake")][:60]
        for season in ("summer", "winter"):
            for pos in land_hexes:
                g = land.ground(pos, 34, season)
                self.assertEqual(g.get_size(), (60, 70))
                for surf, dx, dy, sy in land.objects(pos, 34, season):
                    self.assertIsInstance(surf, pygame.Surface)
        self.assertGreater(len(land._ridges), 0, "random worlds carry mountain ridge lines")


if __name__ == "__main__":
    unittest.main()
