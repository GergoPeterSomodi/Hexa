"""The siege badge (release 0.2.2, design docs/design/sieges-and-retreats.md 4.7, option B "the dial in the ring", mockup
docs/design/ui/20_siege_badge.png): the battle badge's roundel with an amber ring and a gate tower, where the ring itself
is the siege's progress dial.

``siege_badge(r, progress, need, rate)`` is the sprite for a hex of radius ``r`` (the battle badge's size,
``badge_size(r)`` = min(32, 12 + 0.6 r): 17 px at r8, 32 px from r34). The ring fills clockwise from the top: amber for the
points done, dark amber for what this season will add (``rate``), a dark track for the rest, with an ink tick between
points. A long siege (or a small badge) has fewer ticks than points: one every ``tick_step`` points, at most
``MAX_TICKS`` round the ring and never closer than ``TICK_GAP`` pixels. ``lifted=True`` is the grey variant, flashed once
when a siege is lifted: the points that were done in light grey, nothing for this season.

Pure drawing: the numbers come from the caller (the siege view), nothing here reads the world. Sprites are kept in a
registered BoundedCache and handed out as they are (the map only blits them; draw on a ``.copy()``). Each one is drawn at
four times its size and scaled down, like hexa/ui/icons.py. Nothing runs at import time.
"""
import math

import pygame

from ...ui.cache import BoundedCache
from ...ui.icons import INK, gate_tower, shade
from .style import colour as kind_colour

SS = 4                      # supersampling: drawn at four times the size, then smoothscaled
UNIT = 66                   # the roundel's design box: ink edge at 33, like the battle icon (64 canvas + 3 px outline)
RING_OUT, RING_IN = 30, 22.5            # the dial's band, in design units (the battle ring is 30 to 25: this one is wider)
DISC = 21                   # the inner disc, inside a thin ink line
MAX_TICKS = 12              # never more ticks than this round the ring
TICK_GAP = 6.0              # ... nor closer than this many pixels apart (on the middle of the band)
STEPS = (1, 2, 3, 4, 5, 10, 20, 25, 50, 100)     # the points a tick may mark: round numbers a player can count in
DISC_DARK, DISC_LIT = (38, 32, 34), (58, 50, 52)        # the battle badge's disc, lit from the left
TOWER = (240, 226, 200)
GREYS = {"done": (196, 198, 204), "track": (78, 80, 86), "tower": (200, 202, 208)}
_SPRITES = BoundedCache("siege_badge", 96)      # (size, progress, need, rate, lifted, colour) -> the sprite


def badge_size(r):
    """The side of the badge, in pixels, for a hex of radius `r`: the battle badge's size (hud/battles.py)."""
    return min(32, round(12 + 0.6 * r))


def tick_step(need, size):
    """How many points one tick marks on a badge `size` px wide with `need` points: 1 (a tick a point) while the ticks
    fit, else the smallest of STEPS that keeps them at most MAX_TICKS and TICK_GAP px apart."""
    if need <= 1:
        return 1
    mid = (RING_OUT + RING_IN) / 2 * size / UNIT                  # the middle of the band, in pixels
    room = max(1, min(MAX_TICKS, int(2 * math.pi * mid / TICK_GAP)))
    least = need / room
    return next((k for k in STEPS if k >= least), math.ceil(least))


def siege_badge(r, progress, need, rate=0, lifted=False, colour=None):
    """The siege badge sprite for a hex of radius `r`: `progress` of `need` points done, `rate` more this season.
    `lifted` gives the grey flash. `colour` is the ring's amber (default: the siege colour of hud/style.py)."""
    size = badge_size(r)
    need = max(1, round(need))
    done = min(need, max(0, round(progress)))
    add = 0 if lifted else min(need - done, max(0, round(rate)))
    amber = tuple(colour or kind_colour("siege"))
    key = (size, done, need, add, bool(lifted), amber)
    return _SPRITES.get(key, lambda: _draw(*key))


def _band(s, c, centre, u, a0, a1):
    """The ring's band from a0 to a1 (fractions of a turn, clockwise from the top) in colour c."""
    if a1 <= a0:
        return
    n = max(2, math.ceil((a1 - a0) * 120))
    angs = [a0 + (a1 - a0) * i / n for i in range(n + 1)]

    def at(a, rad):
        t = 2 * math.pi * a
        return centre + rad * u * math.sin(t), centre - rad * u * math.cos(t)
    pygame.draw.polygon(s, c, [at(a, RING_OUT + 0.4) for a in angs] + [at(a, RING_IN - 0.4) for a in reversed(angs)])


def _draw(size, done, need, add, lifted, amber):
    side = size * SS
    u = side / UNIT
    c = side / 2
    s = pygame.Surface((side, side), pygame.SRCALPHA)
    P = pygame.draw
    if lifted:
        lit, now, track, tower = GREYS["done"], GREYS["done"], GREYS["track"], GREYS["tower"]
    else:
        lit, now, track, tower = amber, shade(amber, -0.4), shade(amber, -0.8), TOWER
    P.circle(s, INK, (c, c), 33 * u)                                    # the ink edge
    _band(s, track, c, u, 0, 1)                                         # still to go
    _band(s, lit, c, u, 0, done / need)                                 # done
    _band(s, now, c, u, done / need, (done + add) / need)               # this season
    if done and not lifted:                                             # the done arc lit on its outer edge
        _shine(s, shade(amber, 0.4), c, u, done / need)
    step = tick_step(need, size)
    width = max(SS, round(1.1 * SS)) if size >= 24 else SS
    for p in range(0, need, step):                                      # one ink tick a step, the first at the top
        t = 2 * math.pi * p / need
        P.line(s, INK, (c + (RING_IN - 1.5) * u * math.sin(t), c - (RING_IN - 1.5) * u * math.cos(t)),
               (c + (RING_OUT + 1) * u * math.sin(t), c - (RING_OUT + 1) * u * math.cos(t)), width)
    P.circle(s, INK, (c, c), (DISC + 1.6) * u)                          # the ink line inside the band
    P.circle(s, DISC_DARK, (c, c), DISC * u)                            # the disc, lit from the left
    P.circle(s, DISC_LIT, (c - 1.6 * u, c - 1.6 * u), (DISC - 2.5) * u)
    P.circle(s, DISC_DARK, (c + 2 * u, c + 0.8 * u), (DISC - 4.5) * u)
    box = 30 * u                                                        # the tower's 64-unit design box
    gate_tower(s, tower, (c - box / 2, c - box / 2 - 0.6 * u, box))
    return pygame.transform.smoothscale(s, (size, size))


def _shine(s, c, centre, u, a1):
    """A thin lighter line along the outer edge of the done arc where it faces the light (the left half)."""
    n = max(2, math.ceil(a1 * 120))
    pts = []
    for i in range(n + 1):
        a = a1 * i / n
        if 0.5 <= a <= 1.0:                                             # the left half of the ring
            t = 2 * math.pi * a
            pts.append((centre + (RING_OUT - 1.2) * u * math.sin(t), centre - (RING_OUT - 1.2) * u * math.cos(t)))
    if len(pts) > 1:
        pygame.draw.lines(s, c, False, pts, max(2, round(1.6 * u)))
