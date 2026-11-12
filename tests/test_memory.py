"""Memory the campaign keeps between games: the world module's caches must stay bounded (#29).

Building a campaign world takes seconds, so hexa/campaign/world.py keeps a pickled snapshot of each freshly built
world (_SNAPSHOTS) and the geography of each random world (_RANDOM_GEOS). #29: if every random world a session builds
stayed there, memory would grow by a snapshot (about 8 MB) and a geography (about 4 MB) for every random game played.

The test measures what the two caches hold (every object reachable from them, counted once) rather than the whole
process with tracemalloc: tracing makes building a world about 5 times slower. The nightly perf tool
(python -m tools.perf) shows the tracemalloc view of the same thing. No pygame needed.
"""
import gc
import sys
import types
import unittest

from hexa.campaign import world as world_module
from hexa.campaign.world import CampaignWorld
from tests.support.slow import slow

SEEDS = (2901, 2902, 2903, 2904)     # seeds no other test builds, so every world here is built from scratch
SLACK = 4_000_000                    # bytes: random worlds differ a little in size; a whole world is about 12 MB
_OPAQUE = (types.ModuleType, type, types.CodeType, types.BuiltinFunctionType)


def held(roots):
    """Bytes of every object reachable from roots, each counted once. Modules, classes, code and the modules'
    globals belong to the program, not to a cache entry, so the walk doesn't go into them."""
    globals_ = {id(vars(m)) for m in list(sys.modules.values()) if isinstance(m, types.ModuleType)}
    seen, stack, total = set(), list(roots), 0
    while stack:
        obj = stack.pop()
        if id(obj) in seen or id(obj) in globals_ or isinstance(obj, _OPAQUE):
            continue
        seen.add(id(obj))
        total += sys.getsizeof(obj)
        stack.extend(gc.get_referents(obj))
    return total


def cache_bytes():
    """What the world module's caches hold: the snapshots and the random geographies."""
    return held(list(world_module._SNAPSHOTS.values()) + list(world_module._RANDOM_GEOS.values()))


def _mb(n):
    return f"{n / 1e6:.1f} MB"


@slow
class WorldCacheTest(unittest.TestCase):
    def setUp(self):
        snapshots, geos = dict(world_module._SNAPSHOTS), dict(world_module._RANDOM_GEOS)

        def put_back():                    # other tests may rely on the worlds they cached (it only saves time)
            world_module._SNAPSHOTS.clear()
            world_module._SNAPSHOTS.update(snapshots)
            world_module._RANDOM_GEOS.clear()
            world_module._RANDOM_GEOS.update(geos)
        self.addCleanup(put_back)

    def test_random_worlds_do_not_pile_up_in_the_world_caches(self):
        """#29: the module-level caches (_SNAPSHOTS, _RANDOM_GEOS) must stay bounded however many random worlds a
        session builds. Four random worlds are built and dropped one after another, as when a player starts one
        random game after another; the last two must not make the caches hold more than they did after the first
        two (the issue's suggested fix keeps Europe plus the last one or two random worlds; world.RANDOM_KEPT is 2)."""
        after = []
        for seed in SEEDS:
            CampaignWorld(seed, map="random")              # built, then dropped at once
            after.append(cache_bytes())
        grown = after[-1] - after[1]
        snapshots = world_module._SNAPSHOTS
        self.assertLess(grown, SLACK,
                        f"the world caches grew by {_mb(grown)} while 2 more random worlds were built (seeds "
                        f"{SEEDS[2]} and {SEEDS[3]}; {_mb(after[0])}, {_mb(after[1])}, {_mb(after[2])}, "
                        f"{_mb(after[3])} after each of the 4): every random world stays in memory (#29). The caches "
                        f"now hold {len(snapshots)} snapshots ({_mb(sum(len(s) for s in snapshots.values()))}: "
                        f"{sorted(snapshots, key=str)}) and {len(world_module._RANDOM_GEOS)} random geographies")

    def test_the_measure_sees_a_world(self):
        """The test above can only fail if cache_bytes() sees what a world leaves behind."""
        before = cache_bytes()
        world_module._SNAPSHOTS[("test", 0)] = bytes(5_000_000)
        world_module._RANDOM_GEOS[-1] = types.SimpleNamespace(cells=list(range(200_000)))
        self.assertGreater(cache_bytes() - before, 5_000_000 + 200_000 * 8)


if __name__ == "__main__":
    unittest.main()
