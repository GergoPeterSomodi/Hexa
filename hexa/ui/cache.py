"""Bounded caches for what the windows draw again and again (icons today), registered by name.

``BoundedCache(name, size)`` keeps at most `size` things, the least recently used one going first. Every cache is
registered here and emptied when pygame quits (``pygame.quit()`` frees the surfaces and fonts a cache may hold, and the
next window must not find them). ``stats()`` says what each holds, for tests and tools. Nothing here runs at import
time, so the module imports against a stand-in pygame.
"""
from collections import OrderedDict

import pygame

_REGISTRY = {}              # name -> BoundedCache
_watching = False           # a pygame.quit() callback is registered (pygame forgets it when it quits)


def clear_all():
    """Empty every registered cache (pygame.quit() calls this)."""
    global _watching
    for cache in _REGISTRY.values():
        cache.clear()
    _watching = False


def stats():
    """{name: number of entries} of the registered caches."""
    return {name: len(cache) for name, cache in _REGISTRY.items()}


class BoundedCache:
    def __init__(self, name, size):
        self.name, self.size = name, size
        self._items = OrderedDict()
        _REGISTRY[name] = self

    def __len__(self):
        return len(self._items)

    def clear(self):
        self._items.clear()

    def get(self, key, make):
        """The thing kept for `key`, made with ``make()`` (and kept) when there is none."""
        global _watching
        if not _watching:
            pygame.register_quit(clear_all)
            _watching = True
        if key in self._items:
            self._items.move_to_end(key)
            return self._items[key]
        value = self._items[key] = make()
        while len(self._items) > self.size:
            self._items.popitem(last=False)
        return value
