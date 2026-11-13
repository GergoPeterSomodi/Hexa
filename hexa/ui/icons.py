"""Code-drawn icons: small two-tone glyphs with a dark ink outline, in the style of the Kenney tiles.

``icon(name, size, colour)`` is a ``size`` x ``size`` surface: made once per name, size and colour and kept in a
bounded cache (hexa/ui/cache.py, emptied when pygame quits), and handed out as a copy, so a caller that draws on it
cannot spoil the next one's.
Each glyph is drawn on a 64 x 64 canvas at four times the size and scaled down, so the edges are smooth at 14 to
22 px. ``NAMES`` lists the glyphs; a name that is not one draws a plain disc. Nothing here runs at import time, so
the module imports against a stand-in pygame.
"""
import math

import pygame

from .cache import BoundedCache

INK = (12, 14, 18)
GOLD = (255, 214, 70)

COLOURS = {
    "ducats": GOLD, "research": (110, 170, 240), "army": (215, 220, 228), "merchants": (196, 150, 80),
    "prestige": (240, 190, 60), "provinces": (120, 190, 235), "horses": (190, 196, 205), "powder": (170, 120, 70),
    "castle": (200, 200, 210), "flag": (230, 110, 100), "check": (120, 200, 120), "cross": (230, 110, 100),
    "down": (230, 110, 100), "up": (120, 200, 120), "scroll": (230, 215, 180), "target": (120, 175, 235),
    "sun": GOLD, "snow": (220, 235, 250), "political": (200, 90, 90), "terrain": (150, 160, 170),
    "goods": (190, 140, 80), "markets": GOLD, "battle": (240, 232, 214), "tasks": (236, 200, 96),
    "tower": (232, 214, 182),
}
NAMES = tuple(COLOURS)
_cache = BoundedCache("icons", 256)


def shade(colour, k):
    """`colour` lightened (k > 0) or darkened (k < 0) by the share k."""
    if k >= 0:
        return tuple(int(v + (255 - v) * k) for v in colour[:3])
    return tuple(int(v * (1 + k)) for v in colour[:3])


def gate_tower(s, colour, box=(0, 0, 64, 64)):
    """A gate tower (the siege glyph) drawn on `s` in `colour` inside the square `box` (x, y, side): three merlons, a
    body lit from the left, an arrow slit and a dark gate arch. Float coordinates, so it scales to any box: the
    ``tower`` icon draws it on the 64 x 64 canvas, the siege badge (campaign/hud/siegebadge.py) inside its roundel."""
    x0, y0, side = box[0], box[1], box[2]
    k = side / 64

    def pts(*xy):
        return [(x0 + x * k, y0 + y * k) for x, y in xy]
    lite, dark, deep = shade(colour, 0.25), shade(colour, -0.3), shade(colour, -0.72)
    P = pygame.draw
    P.polygon(s, colour, pts((15, 60), (15, 23), (49, 23), (49, 60)))                 # the body
    P.polygon(s, dark, pts((37, 60), (37, 23), (49, 23), (49, 60)))                   # its shaded right side
    P.polygon(s, colour, pts((11, 25), (11, 17), (53, 17), (53, 25)))                 # the parapet, wider than the body
    P.polygon(s, dark, pts((39, 25), (39, 17), (53, 17), (53, 25)))
    for mx, col in ((11, lite), (27, colour), (43, dark)):                            # three merlons
        P.polygon(s, col, pts((mx, 18), (mx, 6), (mx + 10, 6), (mx + 10, 18)))
    P.polygon(s, lite, pts((15, 60), (15, 25), (20, 25), (20, 60)))                   # the lit left edge
    P.polygon(s, deep, pts((30, 29), (30, 38), (34, 38), (34, 29)))                   # the arrow slit
    arch = [(24 + 8 - 8 * math.cos(math.radians(a)), 50 - 8 * math.sin(math.radians(a))) for a in range(0, 181, 15)]
    P.polygon(s, deep, pts((24, 61), *arch, (40, 61)))                                # the gate


def _hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i - 30)), cy + r * math.sin(math.radians(60 * i - 30)))
            for i in range(6)]


def _outline(canvas, width):
    """`canvas` with an ink outline `width` pixels wide around everything drawn on it."""
    mask = pygame.mask.from_surface(canvas, 30)
    edge = mask.to_surface(setcolor=(*INK, 255), unsetcolor=(0, 0, 0, 0))
    out = pygame.Surface(canvas.get_size(), pygame.SRCALPHA)
    for ox in range(-width, width + 1):
        for oy in range(-width, width + 1):
            if ox * ox + oy * oy <= width * width:
                out.blit(edge, (ox, oy))
    out.blit(canvas, (0, 0))
    return out


def _glyph(name, s, c):
    """Draw glyph `name` on the 64 x 64 canvas `s` in main colour `c`."""
    dark, lite, P = shade(c, -0.35), shade(c, 0.35), pygame.draw
    if name == "ducats":
        P.circle(s, dark, (32, 34), 22)
        P.circle(s, c, (30, 32), 21)
        P.circle(s, lite, (30, 32), 14, 3)
        P.rect(s, dark, (27, 22, 6, 20))
    elif name == "research":                    # an open book
        P.polygon(s, c, [(6, 18), (30, 14), (32, 50), (8, 52)])
        P.polygon(s, dark, [(34, 14), (58, 18), (56, 52), (32, 50)])
        for y in (24, 31, 38):
            P.line(s, lite, (12, y), (26, y - 2), 3)
            P.line(s, shade(c, -0.1), (38, y - 2), (52, y), 3)
    elif name == "army":                        # crossed swords
        for a, col in ((1, c), (-1, lite)):
            P.line(s, col, (32 - 20 * a, 8), (32 + 16 * a, 50), 7)
            P.line(s, dark, (32 + 6 * a, 38), (32 + 22 * a, 32), 7)
    elif name == "merchants":                   # a money bag
        P.circle(s, dark, (33, 40), 18)
        P.circle(s, c, (31, 39), 17)
        P.polygon(s, c, [(22, 12), (42, 12), (36, 24), (28, 24)])
        P.line(s, dark, (26, 24), (38, 24), 5)
        P.circle(s, lite, (25, 36), 5)
    elif name == "prestige":                    # a crown
        P.polygon(s, c, [(8, 46), (10, 18), (22, 32), (32, 12), (42, 32), (54, 18), (56, 46)])
        P.rect(s, dark, (8, 44, 48, 9))
        for x in (10, 32, 54):
            P.circle(s, lite, (x, 15 if x == 32 else 18), 5)
    elif name == "provinces":                   # a banner on a pole
        P.line(s, dark, (14, 6), (14, 60), 5)
        P.polygon(s, c, [(16, 8), (54, 14), (42, 24), (54, 34), (16, 32)])
        P.polygon(s, lite, [(16, 8), (54, 14), (50, 17), (16, 15)])
    elif name == "horses":                      # a horseshoe
        P.arc(s, c, (10, 8, 44, 48), math.radians(-30), math.radians(210), 11)
        for x, y in ((14, 26), (50, 26), (22, 46), (42, 46)):
            P.circle(s, dark, (x, y), 2)
    elif name == "powder":                      # a barrel
        P.ellipse(s, c, (12, 10, 40, 46))
        P.rect(s, dark, (12, 22, 40, 5))
        P.rect(s, dark, (12, 40, 40, 5))
        P.ellipse(s, lite, (20, 12, 10, 40), 3)
    else:
        _glyph_more(name, s, c, dark, lite)


def _glyph_more(name, s, c, dark, lite):
    P = pygame.draw
    if name == "castle":
        P.rect(s, c, (10, 24, 44, 32))
        for x in (10, 22, 34, 46):
            P.rect(s, c, (x, 16, 8, 10))
        P.rect(s, dark, (26, 38, 12, 18))
    elif name == "flag":
        P.line(s, dark, (14, 6), (14, 60), 5)
        P.polygon(s, c, [(16, 8), (54, 14), (42, 24), (54, 34), (16, 32)])
    elif name == "check":
        P.lines(s, c, False, [(10, 34), (26, 50), (54, 16)], 10)
    elif name == "cross":
        P.line(s, c, (14, 14), (50, 50), 10)
        P.line(s, c, (50, 14), (14, 50), 10)
    elif name == "down":
        P.polygon(s, c, [(32, 54), (56, 20), (8, 20)])
    elif name == "up":
        P.polygon(s, c, [(32, 10), (56, 44), (8, 44)])
    elif name == "scroll":                      # the log
        P.rect(s, c, (14, 10, 36, 44))
        for y in (20, 28, 36, 44):
            P.line(s, dark, (20, y), (44, y), 3)
        P.circle(s, lite, (14, 10), 6)
        P.circle(s, lite, (50, 54), 6)
    elif name == "target":                      # jump to a place
        P.circle(s, c, (32, 32), 22, 6)
        P.circle(s, c, (32, 32), 7)
        for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            P.line(s, c, (32 + 24 * dx, 32 + 24 * dy), (32 + 31 * dx, 32 + 31 * dy), 6)
    elif name == "battle":                      # crossed swords on a war-red roundel: the mark of a battle on the map
        P.circle(s, (214, 72, 60), (32, 32), 30)            # the ring
        P.circle(s, (38, 32, 34), (32, 32), 25)             # the inner disc, lit from the left
        P.circle(s, (58, 50, 52), (30, 30), 22)
        P.circle(s, (38, 32, 34), (35, 33), 20)
        for sx in (1, -1):
            tip, hilt = (32 - 16 * sx, 15), (32 + 10 * sx, 40)
            mid = ((tip[0] + hilt[0]) // 2, (tip[1] + hilt[1]) // 2)
            P.line(s, (240, 232, 214), tip, hilt, 7)                                     # the blade
            P.line(s, (255, 255, 255), tip, mid, 2)                                      # its highlight
            P.line(s, (110, 72, 40), hilt, (hilt[0] + 7 * sx, hilt[1] + 7), 5)           # the grip
            P.line(s, GOLD, (hilt[0] - 5 * sx, hilt[1] + 5), (hilt[0] + 5 * sx, hilt[1] - 5), 4)   # the crossguard
            P.circle(s, GOLD, (hilt[0] + 8 * sx, hilt[1] + 8), 3)                        # the pommel
    elif name == "tower":                       # a gate tower: the siege (log, panels, the siege badge's glyph)
        gate_tower(s, c)
    elif name == "sun":
        P.circle(s, c, (32, 32), 14)
        for a in range(8):
            ang = math.radians(a * 45)
            P.line(s, c, (32 + 19 * math.cos(ang), 32 + 19 * math.sin(ang)),
                   (32 + 28 * math.cos(ang), 32 + 28 * math.sin(ang)), 5)
    elif name == "snow":
        for a in range(3):
            ang = math.radians(a * 60)
            P.line(s, c, (32 - 26 * math.cos(ang), 32 - 26 * math.sin(ang)),
                   (32 + 26 * math.cos(ang), 32 + 26 * math.sin(ang)), 6)
    elif name == "tasks":                       # a clipboard with a tick: the task flag (not the idea card's glyph)
        P.rect(s, dark, (12, 10, 40, 50))
        P.rect(s, c, (15, 13, 34, 44))
        P.rect(s, dark, (23, 4, 18, 13))
        P.line(s, lite, (23, 7), (41, 7), 3)
        P.lines(s, dark, False, [(20, 32), (27, 39), (41, 25)], 5)
        P.line(s, dark, (20, 46), (42, 46), 4)
    else:
        _glyph_map(name, s, c, dark, lite)


def _glyph_map(name, s, c, dark, lite):
    """The map-mode icons."""
    P = pygame.draw
    if name == "political":
        P.polygon(s, c, _hexagon(32, 32, 26))
        P.polygon(s, dark, [(32, 32)] + _hexagon(32, 32, 26)[0:3])
    elif name == "terrain":
        P.polygon(s, dark, [(4, 54), (24, 16), (44, 54)])
        P.polygon(s, c, [(20, 54), (40, 10), (60, 54)])
        P.polygon(s, (240, 244, 248), [(40, 10), (34, 22), (46, 22)])
    elif name == "goods":                       # a crate
        P.rect(s, c, (8, 14, 48, 40))
        P.rect(s, dark, (8, 14, 48, 40), 4)
        P.line(s, dark, (8, 14), (56, 54), 5)
        P.line(s, lite, (14, 22), (50, 22), 3)
    elif name == "markets":                     # scales
        P.line(s, dark, (32, 8), (32, 54), 5)
        P.line(s, c, (8, 16), (56, 16), 5)
        P.ellipse(s, c, (2, 34, 22, 10))
        P.ellipse(s, c, (40, 34, 22, 10))
        P.rect(s, dark, (20, 52, 24, 6))
    else:
        P.circle(s, c, (32, 32), 20)


def icon(name, size=16, colour=None):
    """The icon `name` as a `size` x `size` surface, in `colour` (default: the glyph's own): a copy of the kept one."""
    return _cache.get((name, size, colour), lambda: _make(name, size, colour)).copy()


def _make(name, size, colour):
    canvas = pygame.Surface((64, 64), pygame.SRCALPHA)
    _glyph(name, canvas, colour or COLOURS.get(name, (235, 238, 242)))
    big = pygame.Surface((72, 72), pygame.SRCALPHA)
    big.blit(canvas, (4, 4))
    big = _outline(big, 3)
    box = big.get_bounding_rect(min_alpha=20)           # fill the square: crop, keep the aspect
    side = max(box.w, box.h)
    square = pygame.Surface((side, side), pygame.SRCALPHA)
    square.blit(big, ((side - box.w) // 2, (side - box.h) // 2), box)
    return pygame.transform.smoothscale(square, (size, size))
