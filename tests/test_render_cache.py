"""render.cache.BoundedCache (the LRU, the byte bound, the statistics, the registry) and render.budget.FrameBudget."""
import ast
import gc
import os
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame  # noqa: E402

from hexa.campaign.render import cache  # noqa: E402
from hexa.campaign.render.budget import FrameBudget  # noqa: E402


class BoundedCacheTest(unittest.TestCase):
    def test_the_oldest_goes_first_and_a_read_makes_a_thing_young(self):
        c = cache.BoundedCache("test.lru", 3)
        for k in "abc":
            c.put(k, k.upper())
        self.assertEqual(c.get("a"), "A")                  # a is young again
        c.put("d", "D")                                    # b goes
        self.assertEqual([k in c for k in "abcd"], [True, False, True, True])
        self.assertEqual(len(c), 3)

    def test_get_with_make_keeps_the_made_thing_and_counts(self):
        c = cache.BoundedCache("test.make", 2)
        made = []
        self.assertEqual(c.get(1, lambda: made.append(1) or "x"), "x")
        self.assertEqual(c.get(1, lambda: made.append(2) or "y"), "x")
        self.assertIsNone(c.get(2))
        self.assertEqual((made, c.hits, c.misses), ([1], 1, 2))

    def test_max_bytes_bounds_the_pixels_but_keeps_the_newest(self):
        pygame.init()
        c = cache.BoundedCache("test.bytes", 100, max_bytes=2000)
        for k in range(5):
            c.put(k, pygame.Surface((10, 10), pygame.SRCALPHA))       # 400 bytes each
        self.assertEqual(len(c), 5)
        c.put(5, pygame.Surface((10, 10), pygame.SRCALPHA))
        self.assertEqual((len(c), c.bytes(), 0 in c, 5 in c), (5, 2000, False, True))
        c.put(6, pygame.Surface((30, 30), pygame.SRCALPHA))           # 3600 bytes alone: it stays, the rest go
        self.assertEqual(len(c), 1)

    def test_stats_add_up_the_caches_of_a_name_and_the_registry_is_weak(self):
        a, b = cache.BoundedCache("test.shared", 5), cache.BoundedCache("test.shared", 5)
        a.put(1, 1)
        b.put(2, 2)
        b.put(3, 3)
        self.assertEqual(cache.stats()["test.shared"], 3)
        self.assertEqual(cache.stats(detail=True)["test.shared"]["caches"], 2)
        self.assertIs(cache.REGISTRY["test.shared"], b)
        del a, b
        gc.collect()
        self.assertNotIn("test.shared", cache.stats())

    def test_clear_all_empties_every_cache(self):
        c = cache.BoundedCache("test.clear", 5)
        c.put(1, 1)
        cache.clear_all()
        self.assertEqual(len(c), 0)


class NoLooseCachesTest(unittest.TestCase):
    """The art modules keep what they draw in registered BoundedCaches: no module-level dict or lru_cache of their own."""
    MODULES = ("art", "wfctiles", "goodsart", "goodsobjects", "life", "nature", "landscape", "landmarks")

    def test_no_module_level_dict_caches(self):
        here = os.path.dirname(os.path.abspath(__file__))
        problems = []
        for name in self.MODULES:
            with open(os.path.join(here, "..", "hexa", "campaign", name + ".py"), encoding="utf-8") as f:
                tree = ast.parse(f.read())
            for node in tree.body:
                if isinstance(node, ast.Assign) and isinstance(node.value, ast.Dict) and not node.value.keys and ast.unparse(node.targets[0]) != "_BUILD":   # a registry
                    problems.append(f"{name}.{ast.unparse(node.targets[0])} is an empty dict")
                if isinstance(node, ast.FunctionDef):
                    problems += [f"{name}.{node.name} uses {ast.unparse(d)}" for d in node.decorator_list
                                 if "lru_cache" in ast.unparse(d)]
        self.assertEqual(problems, [])


class FrameBudgetTest(unittest.TestCase):
    def setUp(self):
        self.now = 100.0
        self.budget = FrameBudget(3.0, clock=lambda: self.now)

    def test_a_slice_lasts_ms_from_its_start(self):
        self.budget.start()
        self.assertTrue(self.budget.fits())
        self.now += 0.0029
        self.assertTrue(self.budget.fits())
        self.assertAlmostEqual(self.budget.left(), 0.0001)
        self.now += 0.0002
        self.assertFalse(self.budget.fits())
        self.assertEqual(self.budget.left(), 0.0)

    def test_fits_looks_ahead_by_the_expected_cost(self):
        self.budget.start()
        self.now += 0.002
        self.assertTrue(self.budget.fits(0.5))
        self.assertFalse(self.budget.fits(1.5))
        self.assertTrue(self.budget.fits(1.5, now=100.0))      # a reading taken earlier

    def test_spend_adds_up_and_start_resets_it(self):
        self.budget.start()
        for _ in range(2):
            t = self.budget.clock()
            self.now += 0.001
            self.budget.spend(t)
        self.assertAlmostEqual(self.budget.spent, 0.002)
        self.budget.start(5.0, t0=self.now)
        self.assertEqual((self.budget.spent, self.budget.ms, self.budget.end), (0.0, 5.0, self.now + 0.005))

    def test_extend_only_ever_lengthens(self):
        self.budget.start()
        self.budget.extend(self.now, 1.0)
        self.assertEqual(self.budget.end, 100.003)
        self.budget.extend(self.now + 0.01, 1.0)
        self.assertEqual(self.budget.end, 100.011)


if __name__ == "__main__":
    unittest.main()
