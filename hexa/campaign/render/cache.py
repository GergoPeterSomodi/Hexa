"""Bounded caches for what the windows draw again and again, registered by name.

``BoundedCache(name, max_entries, max_bytes=None)`` keeps at most `max_entries` things (and, with `max_bytes`, at most
that much memory as `weigh` counts it), the least recently used one going first. It counts hits and misses. Every cache
is registered here and emptied when pygame quits (``pygame.quit()`` frees the surfaces and fonts a cache may hold, and
the next window must not find them). ``stats()`` says what each holds, for tests and tools (``python -m tools.perf``
prints it). Several caches may share a name (every MapView has its own landscape caches): the registry holds them
weakly, ``stats()`` adds them up, ``REGISTRY[name]`` is the newest. Nothing here runs at import time, so the module
imports against a stand-in pygame.

    _icons = BoundedCache("icons", 256)
    surf = _icons.get(key, lambda: make(key))          # made and kept on a miss
    hit = cache.get(key)                               # None on a miss (without make)
    cache.put(key, value)
"""
import functools
import itertools
import weakref
from collections import OrderedDict
from collections.abc import Mapping

import pygame

_ALL = weakref.WeakSet()                    # every live cache
_SERIAL = itertools.count()                 # which of two caches of one name is the newer
_watching = False                           # a pygame.quit() callback is registered (pygame forgets it when it quits)


class _Registry(Mapping):
    """name -> the newest live BoundedCache of that name (read only)."""

    def _newest(self):
        found = {}
        for cache in list(_ALL):
            if cache.name not in found or cache._serial > found[cache.name]._serial:
                found[cache.name] = cache
        return found

    def __getitem__(self, name):
        return self._newest()[name]

    def __iter__(self):
        return iter(self._newest())

    def __len__(self):
        return len(self._newest())


REGISTRY = _Registry()


def clear_all():
    """Empty every registered cache (pygame.quit() calls this)."""
    global _watching
    for cache in list(_ALL):
        cache.clear()
    _watching = False


def stats(detail=False):
    """{name: number of entries} of the registered caches. With detail=True: {name: {"entries", "bytes", "hits",
    "misses", "max_entries", "caches"}}, the sums over the live caches of that name."""
    out = {}
    for cache in list(_ALL):
        row = out.setdefault(cache.name, {"entries": 0, "bytes": 0, "hits": 0, "misses": 0,
                                          "max_entries": cache.max_entries, "caches": 0})
        row["entries"] += len(cache)
        row["bytes"] += cache.bytes() if detail else 0
        row["hits"] += cache.hits
        row["misses"] += cache.misses
        row["caches"] += 1
    if detail:
        return dict(sorted(out.items()))
    return {name: row["entries"] for name, row in sorted(out.items())}


def surface_bytes(value, _depth=0):
    """The pixel memory of a Surface, or of the Surfaces inside a list, tuple or dict (3 levels deep)."""
    if isinstance(value, pygame.Surface):
        return value.get_width() * value.get_height() * value.get_bytesize()
    if _depth < 3:
        if isinstance(value, (list, tuple)):
            return sum(surface_bytes(v, _depth + 1) for v in value)
        if isinstance(value, dict):
            return sum(surface_bytes(v, _depth + 1) for v in value.values())
    return 0


class BoundedCache:
    def __init__(self, name, max_entries, max_bytes=None, weigh=surface_bytes):
        self.name, self.max_entries, self.max_bytes, self.weigh = name, max_entries, max_bytes, weigh
        self.hits = self.misses = 0
        self._items = OrderedDict()
        self._weights = {}
        self._held = 0                      # bytes held, kept only when there is a max_bytes
        self._serial = next(_SERIAL)
        _ALL.add(self)

    @property
    def size(self):
        return self.max_entries

    def __len__(self):
        return len(self._items)

    def __contains__(self, key):
        return key in self._items

    def clear(self):
        self._items.clear()
        self._weights.clear()
        self._held = 0

    def bytes(self):
        """The memory the things held take, as `weigh` counts it."""
        return sum(self.weigh(v) for v in self._items.values())

    def get(self, key, make=None):
        """The thing kept for `key`. On a miss: None, or with `make` the result of ``make()``, kept."""
        global _watching
        if not _watching:
            pygame.register_quit(clear_all)
            _watching = True
        if key in self._items:
            self._items.move_to_end(key)
            self.hits += 1
            return self._items[key]
        self.misses += 1
        if make is None:
            return None
        return self.put(key, make())

    def memo(self, fn):
        """Decorator: fn(*args) made once per args (positional only) and kept in this cache, like lru_cache."""
        @functools.wraps(fn)
        def wrapper(*args):
            return self.get(args, lambda: fn(*args))
        wrapper.cache = self
        return wrapper

    def put(self, key, value):
        """Keep `value` for `key` (the newest), dropping the oldest things beyond the bounds. Returns value."""
        if self.max_bytes is not None:
            self._held += (w := self.weigh(value)) - self._weights.get(key, 0)
            self._weights[key] = w
        self._items[key] = value
        self._items.move_to_end(key)
        while len(self._items) > self.max_entries or (self.max_bytes is not None and self._held > self.max_bytes
                                                      and len(self._items) > 1):
            old, _ = self._items.popitem(last=False)
            self._held -= self._weights.pop(old, 0)
        return value
