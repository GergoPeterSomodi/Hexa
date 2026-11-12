"""render.cache.BoundedCache: the LRU, the byte bound, the statistics and the registry."""
import gc
import os
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame  # noqa: E402

from hexa.campaign.render import cache  # noqa: E402


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


if __name__ == "__main__":
    unittest.main()
