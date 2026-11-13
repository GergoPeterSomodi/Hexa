"""The siege badge sprite (hud/siegebadge.py, release 0.2.2, design sieges-and-retreats 4.7, option B): its size follows the
battle badge, the dial fills clockwise from the top in amber, this season's part is dark amber, ticks are capped, the
lifted flash is grey, and the sprites live in a bounded, registered cache. Also the ``tower`` icon of ui/icons.py."""
import os
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa.campaign.hud import siegebadge as sb  # noqa: E402
from hexa.campaign.hud.battles import _badge_size  # noqa: E402
from hexa.campaign.hud.style import colour  # noqa: E402
from hexa.campaign.render import cache  # noqa: E402
from hexa.ui import icons  # noqa: E402

AMBER = colour("siege")


def ring_at(surf, turn):
    """The colour in the middle of the dial's band at `turn` (a fraction of a turn, clockwise from the top)."""
    import math
    side = surf.get_width()
    rad = (sb.RING_OUT + sb.RING_IN) / 2 * side / sb.UNIT
    t = 2 * math.pi * turn
    x, y = side / 2 + rad * math.sin(t), side / 2 - rad * math.cos(t)
    return tuple(surf.get_at((int(x), int(y))))[:3]


def near(a, b, tol=40):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


class SiegeBadgeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pygame.init()
        pygame.display.set_mode((1, 1))

    def setUp(self):
        sb._SPRITES.clear()

    def test_sizes_follow_the_battle_badge_at_every_map_zoom(self):
        for r in (8, 13, 21, 34, 40):
            surf = sb.siege_badge(r, 2, 4, 1)
            self.assertEqual(surf.get_size(), (_badge_size(r),) * 2)
        self.assertEqual((sb.badge_size(8), sb.badge_size(34), sb.badge_size(60)), (17, 32, 32))

    def test_progress_zero_half_and_full(self):
        big = 34
        empty, half, full = (sb.siege_badge(big, p, 8) for p in (0, 4, 8))
        track, now = icons.shade(AMBER, -0.8), icons.shade(AMBER, -0.4)
        for turn in (0.1, 0.4, 0.6, 0.9):
            self.assertTrue(near(ring_at(empty, turn), track), turn)
            self.assertTrue(near(ring_at(full, turn), AMBER, 60), turn)
        self.assertTrue(near(ring_at(half, 0.2), AMBER, 60))        # clockwise from the top: the right half is done
        self.assertTrue(near(ring_at(half, 0.8), track))
        part = sb.siege_badge(big, 4, 8, 2)                          # +2 this season: 4/8 to 6/8 in dark amber
        self.assertTrue(near(ring_at(part, 0.62), now))
        self.assertTrue(near(ring_at(part, 0.85), track))

    def test_rate_and_progress_are_clamped(self):
        self.assertIs(sb.siege_badge(21, 9, 8, 5), sb.siege_badge(21, 8, 8, 0))
        self.assertIs(sb.siege_badge(21, -2, 8, -1), sb.siege_badge(21, 0, 8, 0))
        self.assertIs(sb.siege_badge(21, 7, 8, 5), sb.siege_badge(21, 7, 8, 1))
        self.assertEqual(sb.siege_badge(21, 0, 0).get_width(), sb.badge_size(21))     # need 0 draws, as 1

    def test_large_need_caps_the_ticks_on_round_steps(self):
        for size in (17, 20, 25, 32):
            for need in (1, 4, 7, 12, 13, 24, 40, 60, 99, 500):
                step = sb.tick_step(need, size)
                ticks = -(-need // step)
                self.assertLessEqual(ticks, sb.MAX_TICKS, (size, need))
                self.assertTrue(step in sb.STEPS or step > sb.STEPS[-1], (size, need, step))
        self.assertEqual(sb.tick_step(12, 32), 1)                    # a tick a point while they fit
        self.assertGreater(sb.tick_step(12, 17), 1)                  # not on the smallest badge
        self.assertEqual(sb.tick_step(60, 32), 5)
        surf = sb.siege_badge(34, 30, 60, 6)
        self.assertEqual(surf.get_size(), (32, 32))

    def test_lifted_is_grey(self):
        surf = sb.siege_badge(34, 3, 7, 2, lifted=True)
        for turn in (0.15, 0.7):
            r, g, b = ring_at(surf, turn)
            self.assertLess(max(r, g, b) - min(r, g, b), 16, turn)   # no amber in the flash
        self.assertIsNot(surf, sb.siege_badge(34, 3, 7, 2))

    def test_cache_is_bounded_and_registered(self):
        for need in range(1, 30):
            for p in range(0, need + 1, 3):
                sb.siege_badge(21, p, need, 1)
        self.assertLessEqual(len(sb._SPRITES), sb._SPRITES.max_entries)
        self.assertIn("siege_badge", cache.stats())
        a = sb.siege_badge(13, 2, 4, 1)
        self.assertIs(a, sb.siege_badge(13, 2, 4, 1))                # a hit hands out the kept sprite
        self.assertIsNot(a, sb.siege_badge(13, 2, 4, 1, colour=(200, 120, 40)))

    def test_tower_icon_draws(self):
        self.assertIn("tower", icons.NAMES)
        surf = icons.icon("tower", 18)
        self.assertEqual(surf.get_size(), (18, 18))
        self.assertGreater(pygame.mask.from_surface(surf, 60).count(), 18 * 18 // 4)
        self.assertNotEqual(pygame.image.tobytes(surf, "RGBA"), pygame.image.tobytes(icons.icon("castle", 18), "RGBA"))


if __name__ == "__main__":
    unittest.main()
