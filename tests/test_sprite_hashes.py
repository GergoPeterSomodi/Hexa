"""Every generated sprite is the same bytes as when the fixture was made (tests/fixtures/sprite_hashes.json).

The proof for refactors of the art modules (render/draw.py, the cache sizes): they must not change a pixel. A failure
names the sprites that differ. Pygame draws a little differently in another build, so the fixture records the
environment it was made in and the test skips elsewhere (HEXA_SPRITES_STRICT=1 fails instead). To make the fixture
after an art change on purpose:

    UPDATE_SPRITES=1 python -m unittest tests.test_sprite_hashes
"""
import json
import os
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame  # noqa: E402

from tests.support import sprites  # noqa: E402


class SpriteHashTest(unittest.TestCase):
    def test_every_sprite_is_unchanged(self):
        pygame.init()
        env = sprites.environment()
        found = sprites.collect()
        if os.environ.get("UPDATE_SPRITES") == "1":
            os.makedirs(os.path.dirname(sprites.FIXTURE), exist_ok=True)
            with open(sprites.FIXTURE, "w", encoding="utf-8", newline="\n") as f:
                json.dump({"environment": env, "hashes": found}, f, indent=0, sort_keys=True)
                f.write("\n")
            self.skipTest(f"wrote {len(found)} hashes")
        with open(sprites.FIXTURE, encoding="utf-8") as f:
            fixture = json.load(f)
        if fixture["environment"] != env:
            reason = f"the hashes were made in another environment ({fixture['environment']} -> {env})"
            if os.environ.get("HEXA_SPRITES_STRICT") == "1":
                self.fail(reason)
            self.skipTest(reason)
        want = fixture["hashes"]
        self.assertEqual(sorted(set(want) ^ set(found)), [], "sprites added or removed")
        changed = [name for name in want if want[name] != found[name]]
        self.assertEqual(changed, [], f"{len(changed)} of {len(want)} sprites changed")

    def test_the_hashes_do_not_depend_on_what_was_cached(self):
        pygame.init()
        first = sprites.collect()
        self.assertEqual(sprites.collect(), first)


if __name__ == "__main__":
    unittest.main()
