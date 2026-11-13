"""Every generated sprite is the same bytes as when the fixture was made (tests/fixtures/sprite_hashes/<platform>.json).

The proof for refactors of the art modules (render/draw.py, the cache sizes): they must not change a pixel. A failure
names the sprites that differ. Pygame draws a little differently in another build, so there is one fixture per
platform (OS, Python, pygame, SDL, smoothscale backend; sprites.platform_key()). With no fixture for this platform
the test skips and says which file to make; a fixture that differs always fails (HEXA_SPRITES_STRICT=1, set in the
CI ui job, documents that and changes nothing: a missing fixture still skips). To make this platform's fixture (after an art change on purpose, or for a
new platform: the goldens workflow does it for Linux):

    UPDATE_SPRITES=1 python -m unittest tests.test_sprite_hashes
"""
import json
import os
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from tests.support import sprites  # noqa: E402


class SpriteHashTest(unittest.TestCase):
    def test_every_sprite_is_unchanged(self):
        pygame.init()
        path = sprites.fixture_path()
        found = sprites.collect()
        if os.environ.get("UPDATE_SPRITES") == "1":
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                json.dump({"environment": sprites.environment(), "hashes": found}, f, indent=0, sort_keys=True)
                f.write("\n")
            self.skipTest(f"wrote {len(found)} hashes to {os.path.relpath(path)}")
        if not os.path.exists(path):
            self.skipTest(f"no sprite fixture for this platform: UPDATE_SPRITES=1 makes {os.path.relpath(path)}")
        with open(path, encoding="utf-8") as f:
            want = json.load(f)["hashes"]
        self.assertEqual(sorted(set(want) ^ set(found)), [], "sprites added or removed")
        changed = [name for name in want if want[name] != found[name]]
        self.assertEqual(changed, [], f"{len(changed)} of {len(want)} sprites changed")

    def test_the_hashes_do_not_depend_on_what_was_cached(self):
        pygame.init()
        first = sprites.collect()
        self.assertEqual(sprites.collect(), first)


if __name__ == "__main__":
    unittest.main()
