"""The bounded, registered caches live in hexa/campaign/render/cache.py; this keeps the old import path (icons)."""
from ..campaign.render.cache import REGISTRY, BoundedCache, clear_all, stats

__all__ = ["BoundedCache", "clear_all", "stats", "REGISTRY"]
