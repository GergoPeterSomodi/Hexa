"""Mountains, hills, trees and ground clutter for Hexa, plus scatter clusters and whole nature tiles.

Ported from the tile-design mockup (objects/nature.py). Imports are package-relative.

Look (same as the goods and landmark tiles): flat two-tone shading (lit from the left, darker on the right),
a 1-2 px dark ink outline, drawn at 2x and smoothscaled. Each object's base point (feet) is the bottom
centre of its surface. Sizes: "small", "medium", "large" (SIZE_SCALE).

Objects (public; each returns a cached RGBA Surface, do not mutate):
  mountains: snow_peak, twin_peak, crag, old_mountain, volcano, mesa, foothills
  hills:     hill_green, hill_dry, hill_terraced, outcrop
  trees:     oak, oak_autumn, beech, linden, birch, pine_tall, pine_short, fir_tall, fir_short,
             snowy_tall, snowy_short, cypress, umbrella, olive, date_palm, jungle, shrub, dead_tree
  ground:    grass_tuft, fern, stone, boulder
  Every public function takes (size="medium", seed=0). seed picks one of 4 variants of the same object.

Scatter:  scatter(tile, kind, density=0.6, seed=0) draws a natural cluster onto a 120 x 140 tile, in place.
          KINDS: mixed_forest, pine_forest, jungle, mediterranean, mountain_range, high_alps, hills, volcano
Tiles:    draw_tile(name, variant=0) -> 120 x 140 hex tile (2x supersampled), TILE_KINDS lists the 12 names.
"""
import math
import random
import zlib
from functools import lru_cache, partial

import pygame

from .art import hex_pts, shade
from .goodsart import ell

W, H = 120, 140
CX, CY, R = 60.0, 70.0, 69.3
K = 2
INK = (36, 38, 44)
SNOW = (236, 242, 250)
TRUNK = (118, 88, 60)
TRUNK_D = (84, 60, 40)
ROCK = (132, 128, 136)
GREEN_TREE = [(72, 142, 62), (88, 156, 72), (60, 124, 56), (104, 166, 80)]
AUTUMN = [(214, 118, 46), (196, 64, 44), (232, 168, 60), (176, 56, 40)]
PINE = [(58, 118, 64), (46, 100, 56), (72, 134, 78)]
SIZE_SCALE = {"small": 0.6, "medium": 0.8, "large": 1.2}
SIZES = ("small", "medium", "large")
VARIANTS = 4


# ----------------------------------------------------------------------------------------------- geometry
def clip(poly, keep):
    """Sutherland-Hodgman: the part of `poly` where keep(x, y) >= 0 (a half-plane test)."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        kp, kq = keep(*p), keep(*q)
        if kp >= 0:
            out.append(p)
        if (kp >= 0) != (kq >= 0):
            t = kp / (kp - kq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def _in_poly(x, y, poly):
    ins = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            ins = not ins
        j = i
    return ins


def _in_hex(x, y, margin=0.0):
    r = R - margin
    dx, dy = abs(x - CX), abs(y - CY)
    return dx <= r * 0.866 and dy * 0.866 + dx * 0.5 <= r * 0.866


def _dots(rng, poly, n, fn):
    """Call fn(x, y) at up to n random points inside `poly`."""
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    got = tries = 0
    while got < n and tries < n * 14:
        tries += 1
        x, y = rng.uniform(min(xs), max(xs)), rng.uniform(min(ys), max(ys))
        if _in_poly(x, y, poly):
            fn(x, y)
            got += 1


def _cloud(rng, n, cx, cy, rx, ry, rmin, rmax, k):
    """Random foliage blobs (x, y, rx, ry, palette index) inside an ellipse."""
    out = []
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = math.sqrt(rng.random())
        r = rng.uniform(rmin, rmax)
        out.append((cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d, r, r * rng.uniform(0.8, 1.0),
                    rng.randrange(k)))
    return out


def _flat(blobs, fx, fy):
    return [(x, y, rx * fx, ry * fy, k) for x, y, rx, ry, k in blobs]


def _drip(cap, cut_y, rng):
    """Replace the straight cut edge of a snow cap with a ragged drip line."""
    n = len(cap)
    for a in range(n):
        b = (a + 1) % n
        if abs(cap[a][1] - cut_y) < 1e-3 and abs(cap[b][1] - cut_y) < 1e-3:
            xa, xb = cap[a][0], cap[b][0]
            zig = []
            for k in range(1, 8):
                t = k / 8
                zig.append((xa + (xb - xa) * t, cut_y + (rng.uniform(0.8, 4.0) if k % 2 else 0.0)))
            return cap[:a + 1] + zig + cap[a + 1:]
    return cap


# ----------------------------------------------------------------------------------------------- canvas
class Canvas:
    """A local box of w x h units (1 unit = 1 px of a 120 x 140 tile at size 1.0). The base point is (0, 0),
    x runs from -w/2 to w/2 and y from -h (top) to 0 (feet)."""

    def __init__(self, w, h, size):
        self.s = SIZE_SCALE[size]
        self.w, self.h = w, h
        self.fw = max(2, round(w * self.s))
        self.fh = max(2, round(h * self.s))
        self.sx = self.fw * K / w
        self.sy = self.fh * K / h
        self.ink = 2 if size == "small" else 3
        self.body = pygame.Surface((self.fw * K, self.fh * K), pygame.SRCALPHA)
        self.top = pygame.Surface((self.fw * K, self.fh * K), pygame.SRCALPHA)
        self.cur = self.body

    def P(self, x, y):
        return ((x + self.w / 2) * self.sx, (y + self.h) * self.sy)

    def T(self, pts):
        return [self.P(x, y) for x, y in pts]

    def poly(self, col, pts):
        if len(pts) > 2:
            pygame.draw.polygon(self.cur, col, self.T(pts))

    def circle(self, col, x, y, r):
        pygame.draw.circle(self.cur, col, self.P(x, y), max(1, round(r * self.sx)))

    def oval(self, col, x, y, rx, ry):
        cx, cy = self.P(x, y)
        a, b = max(1, round(rx * self.sx)), max(1, round(ry * self.sy))
        pygame.draw.ellipse(self.cur, col, pygame.Rect(round(cx) - a, round(cy) - b, 2 * a, 2 * b))

    def _lw(self, w):
        return max(1, round(w * self.s * K))

    def line(self, col, a, b, w=1.0):
        pygame.draw.line(self.cur, col, self.P(*a), self.P(*b), self._lw(w))

    def lines(self, col, pts, w=1.0):
        if len(pts) > 1:
            pygame.draw.lines(self.cur, col, False, self.T(pts), self._lw(w))

    def tt(self, pts, base, lit=0.16, dark=-0.3):
        """Two-tone polygon: lit left of x = 0, shaded right of it."""
        self.poly(shade(base, lit), clip(pts, lambda x, y: -x))
        self.poly(shade(base, dark), clip(pts, lambda x, y: x))

    def on_top(self, flag=True):
        """Draw the next shapes on the unoutlined top layer (smoke) or back on the body."""
        self.cur = self.top if flag else self.body

    def finish(self, shadow=0.0):
        out = pygame.Surface(self.body.get_size(), pygame.SRCALPHA)
        if shadow:
            bx, by = self.P(0, 0)
            rx = shadow * self.sx / 2
            ry = shadow * self.sy * 0.12
            pygame.draw.ellipse(out, (14, 22, 14, 90),
                                pygame.Rect(round(bx - rx), round(by - 2 * ry), round(2 * rx), round(2 * ry)))
        if self.ink:
            sil = pygame.mask.from_surface(self.body, 40).to_surface(setcolor=INK + (255,),
                                                                     unsetcolor=(0, 0, 0, 0))
            r = self.ink
            for dx, dy in ((-r, 0), (r, 0), (0, -r), (0, r), (-0.7 * r, -0.7 * r), (0.7 * r, -0.7 * r),
                           (-0.7 * r, 0.7 * r), (0.7 * r, 0.7 * r)):
                out.blit(sil, (round(dx), round(dy)))
        out.blit(self.body, (0, 0))
        out.blit(self.top, (0, 0))
        return out


# ----------------------------------------------------------------------------------------------- registry
_BUILD = {}


def _reg(name, w, h, shadow=0.0, **kw):
    def deco(fn):
        _BUILD[name] = (partial(fn, **kw), w, h, shadow)
        return fn
    return deco


@lru_cache(maxsize=None)
def _get2x(name, size, seed):
    """(surface at 2x, final width, final height). The base point is the bottom centre of the surface."""
    build, w, h, shadow = _BUILD[name]
    c = Canvas(w, h, size)
    rng = random.Random(zlib.crc32(f"{name}|{size}|{seed}".encode()))
    build(c, rng)
    return c.finish(shadow), c.fw, c.fh


@lru_cache(maxsize=None)
def _pub(name, size, seed):
    surf, fw, fh = _get2x(name, size, seed)
    return pygame.transform.smoothscale(surf, (fw, fh))


def _public(name):
    def f(size="medium", seed=0):
        return _pub(name, size, seed)
    f.__name__ = name
    f.__doc__ = f"{name} object: size small/medium/large, seed picks one of {VARIANTS} variants."
    return f


# ----------------------------------------------------------------------------------------------- shared parts
def _trunk(c, h, w0, w1, base=TRUNK):
    c.tt([(-w0, 0), (w0, 0), (w1, -h), (-w1, -h)], base)


def _crown(c, blobs, pal):
    """Foliage: each blob is a dark shape, then a lighter one shifted up-left, then a small highlight."""
    for x, y, rx, ry, k in sorted(blobs, key=lambda b: b[1]):
        col = pal[k % len(pal)]
        c.oval(shade(col, -0.34), x, y, rx, ry)
        c.oval(col, x - rx * 0.14, y - ry * 0.18, rx * 0.84, ry * 0.8)
        c.oval(shade(col, 0.22), x - rx * 0.42, y - ry * 0.46, rx * 0.36, ry * 0.3)


def _rock(c, prof, base, rng, snow_y=None, streaks=3):
    c.tt(prof, base)
    for _ in range(streaks):
        _dots(rng, prof, 1, lambda x, y: c.line(shade(base, -0.42), (x, y),
                                                (x + rng.uniform(-2, 2), y + rng.uniform(4, 8)), 0.9))
    if snow_y is not None:
        cap = _drip(clip(prof, lambda x, y: snow_y - y), snow_y, rng)
        c.tt(cap, SNOW, lit=0.0, dark=-0.22)


# ----------------------------------------------------------------------------------------------- mountains
@_reg("snow_peak", 66, 60, shadow=40)
def _snow_peak(c, rng):
    prof = [(-31, 0), (-23, -15), (-19, -21), (-12, -32), (-7, -29), (-3, -41), (0, -50), (4, -43),
            (8, -36), (13, -31), (20, -22), (31, 0)]
    _rock(c, prof, ROCK, rng, snow_y=-34, streaks=4)


@_reg("twin_peak", 70, 62, shadow=42)
def _twin_peak(c, rng):
    prof = [(-31, 0), (-25, -14), (-19, -20), (-12, -40), (-7, -34), (-2, -30), (4, -40), (10, -50),
            (15, -40), (21, -28), (31, 0)]
    _rock(c, prof, ROCK, rng, snow_y=-38, streaks=5)


@_reg("crag", 66, 52, shadow=38)
def _crag(c, rng):
    pts = [(-31, 0)]
    for i in range(10):
        x = -27 + i * 6.1 + rng.uniform(-1.2, 1.2)
        pts.append((x, -rng.uniform(18, 46) if i % 2 == 0 else -rng.uniform(8, 20)))
    pts.append((31, 0))
    _rock(c, pts, (140, 128, 118), rng, streaks=5)


@_reg("old_mountain", 66, 46, shadow=36)
def _old_mountain(c, rng):
    prof = ell(0, 0, 32, 27, 180, 360, 24)
    c.tt(prof, (116, 132, 112), lit=0.16, dark=-0.28)
    _dots(rng, prof, 12, lambda x, y: c.line((156, 176, 118), (x, y), (x + 2, y), 1.0))
    for x, hgt in ((-21, 13), (-14, 9), (16, 10), (23, 12)):
        c.tt([(x - 4, 0), (x + 4, 0), (x, -hgt)], (38, 80, 56), lit=0.12, dark=-0.3)


@_reg("volcano", 84, 88, shadow=54)
def _volcano(c, rng):
    prof = [(-38, 0), (-24, -26), (-14, -44), (-9, -49), (-4, -51), (4, -51), (9, -49), (16, -42),
            (26, -26), (38, 0)]
    c.tt(prof, (112, 100, 94))
    _dots(rng, prof, 8, lambda x, y: c.line((80, 70, 66), (x, y), (x + 2, y + 3), 1.0))
    c.oval((58, 48, 46), 0, -51, 6.5, 2.4)
    c.oval((246, 118, 40), 0, -50.8, 3.6, 1.2)
    c.circle((255, 180, 80), 0, -50.6, 1.4)
    c.lines((246, 118, 40), [(-5, -47), (-9, -38), (-13, -30)], 1.3)
    c.lines((246, 118, 40), [(5, -47), (8, -37), (12, -28)], 1.3)
    c.on_top(True)
    for x, y, r in ((10, -58, 4.2), (16, -66, 5.2), (24, -75, 5.8), (34, -84, 5.2)):
        c.circle((166, 162, 168, 205), x, y, r)
        c.circle((212, 210, 214, 210), x + 1.2, y - 1.0, r * 0.7)
    c.on_top(False)


@_reg("mesa", 72, 54, shadow=44)
def _mesa(c, rng):
    prof = [(-31, 0), (-29, -34), (-26, -40), (26, -40), (29, -34), (31, 0)]
    c.tt([(-38, 0), (-29, -10), (29, -10), (38, 0)], (176, 150, 118), lit=0.12, dark=-0.22)
    bands = [(-40, -34, (214, 164, 110)), (-34, -28, (190, 116, 78)), (-28, -22, (228, 196, 150)),
             (-22, -16, (168, 94, 62)), (-16, -10, (214, 160, 104)), (-10, 0, (186, 124, 80))]
    for y0, y1, col in bands:
        band = clip(clip(prof, lambda x, y, y0=y0: y - y0), lambda x, y, y1=y1: y1 - y)
        c.tt(band, col, lit=0.14, dark=-0.26)
    c.lines((246, 214, 170), [(-25, -40), (25, -40)], 1.5)


@_reg("foothills", 68, 38, shadow=56)
def _foothills(c, rng):
    for cx, rx, ry, col in ((0, 24, 19, (138, 150, 96)), (-18, 17, 13, (128, 140, 88)),
                            (18, 16, 12, (118, 134, 84))):
        prof = ell(cx, 0, rx, ry, 180, 360, 18)
        c.tt(prof, col, lit=0.14, dark=-0.26)
        _dots(rng, prof, 7, lambda x, y: c.line((168, 186, 118), (x, y), (x + 1.4, y - 1.6), 1.0))
        _dots(rng, prof, 3, lambda x, y: c.oval((74, 104, 60), x, y, 2.4, 1.6))


# ----------------------------------------------------------------------------------------------- hills
def _hill_rolling(c, rng, col, tuft, hedge):
    for cx, rx, ry in ((14, 22, 14), (-13, 27, 18)):
        prof = ell(cx, 0, rx, ry, 180, 360, 24)
        c.tt(prof, col, lit=0.16, dark=-0.28)
        if cx < 0:
            for _ in range(3):
                a = (rng.uniform(-24, -4), rng.uniform(-14, -3))
                b = (a[0] + rng.uniform(6, 11), a[1] + rng.uniform(-2, 2))
                if _in_poly(*a, prof) and _in_poly(*b, prof):
                    c.line(shade(col, -0.35) if hedge else tuft, a, b, 1.0)
        _dots(rng, prof, 9, lambda x, y: c.line(tuft, (x, y), (x + 1.2, y - 1.8), 1.0))


@_reg("hill_green", 62, 30, shadow=50)
def _hill_green(c, rng):
    _hill_rolling(c, rng, (112, 168, 78), (150, 196, 104), hedge=True)


@_reg("hill_dry", 62, 30, shadow=50)
def _hill_dry(c, rng):
    _hill_rolling(c, rng, (196, 166, 100), (150, 120, 64), hedge=False)


@_reg("hill_terraced", 60, 38, shadow=44)
def _hill_terraced(c, rng):
    prof = ell(0, 0, 28, 30, 180, 360, 26)
    cols = [(150, 172, 88), (170, 180, 100), (132, 160, 78), (160, 176, 94), (140, 166, 84)]
    for i in range(5):
        y0, y1 = -30 + i * 6, -24 + i * 6
        band = clip(clip(prof, lambda x, y, y0=y0: y - y0), lambda x, y, y1=y1: y1 - y)
        c.tt(band, cols[i], lit=0.14, dark=-0.26)
        if y1 < -0.5:
            hw = 28 * math.sqrt(max(0.0, 1 - (y1 / 30) ** 2))
            c.line((78, 104, 50), (-hw, y1), (hw, y1), 1.3)
        _dots(rng, band, 4, lambda x, y: c.oval((70, 100, 52), x, y, 1.3, 1.0))


@_reg("outcrop", 58, 34, shadow=34)
def _outcrop(c, rng):
    for cx, cy, rx, ry, col in ((-13, -10, 11, 9, ROCK), (9, -12, 11, 11, (146, 142, 134)),
                                (0, -6, 9, 6, (164, 160, 150))):
        poly = []
        for i in range(9):
            a = 2 * math.pi * i / 9
            rr = 1 + rng.uniform(-0.1, 0.1)
            poly.append((cx + rx * math.cos(a) * rr, cy + ry * math.sin(a) * rr))
        c.tt(poly, col, lit=0.16, dark=-0.28)
        c.lines((90, 86, 82), [(cx - 2, cy - ry * 0.6), (cx + 1, cy), (cx - 1, cy + ry * 0.5)], 0.9)
    _dots(rng, [(-24, 0), (24, 0), (20, -3), (-20, -3)], 8,
          lambda x, y: c.line((98, 150, 74), (x, y), (x + 1.2, y - 2.6), 1.0))


# ----------------------------------------------------------------------------------------------- trees
@_reg("oak", 60, 62, shadow=18)
@_reg("oak_autumn", 60, 62, shadow=18, autumn=True)
def _oak(c, rng, autumn=False):
    pal = AUTUMN if autumn else GREEN_TREE
    _trunk(c, 16, 3.4, 2.2)
    c.lines(TRUNK_D, [(0, -14), (-9, -26)], 1.6)
    c.lines(TRUNK_D, [(0, -16), (8, -28)], 1.6)
    c.lines(TRUNK_D, [(0, -20), (-2, -34)], 1.4)
    blobs = _cloud(rng, 11, 0, -38, 18, 13, 7, 10.5, len(pal))
    blobs += [(-15, -27, 6, 5, 0), (14, -28, 6, 5, 1)]
    _crown(c, blobs, pal)


@_reg("beech", 52, 56, shadow=18)
@_reg("linden", 52, 56, shadow=18, linden=True)
def _beech(c, rng, linden=False):
    pal = [(150, 200, 110), (170, 216, 128), (128, 184, 96)] if linden else [(118, 170, 84), (136, 186, 96), (100, 150, 72)]
    _trunk(c, 20, 2.6, 1.8, base=(182, 174, 162))
    c.lines((96, 88, 80), [(-1, -7), (1, -11)], 1.0)
    c.lines((96, 88, 80), [(0.8, -14), (-0.6, -18)], 1.0)
    if linden:
        blobs = [(-7, -38, 6.5, 9, 0), (7, -38, 6.5, 9, 0), (0, -30, 8.5, 10, 1), (-4, -48, 6, 6.5, 2),
                 (4, -48, 6, 6.5, 2), (0, -23, 6, 6, 1)]
    else:
        blobs = _flat(_cloud(rng, 8, 0, -27, 20, 9, 7, 9.5, len(pal)), 1.0, 0.8)
    _crown(c, blobs, pal)


@_reg("birch", 28, 58, shadow=12)
def _birch(c, rng):
    c.tt([(-1.5, 0), (1.5, 0), (1.0, -44), (-1.0, -44)], (238, 236, 228), lit=0.08, dark=-0.22)
    for y in (-5, -11, -18, -25, -32, -38):
        x = rng.uniform(-0.6, 0.4)
        c.line((60, 56, 58), (x - 0.9, y), (x + 0.9, y + 0.3), 1.0)
    c.lines(TRUNK_D, [(0, -38), (-6, -47)], 0.9)
    c.lines(TRUNK_D, [(0, -30), (5, -38)], 0.9)
    _crown(c, _cloud(rng, 14, 0, -47, 12, 10, 3.0, 4.8, 3), [(160, 204, 96), (120, 176, 80), (186, 216, 120)])


def _conifer(c, rng):
    """Tall pine: stacked triangular tiers on a bare trunk, reads as a conifer."""
    _trunk(c, 52, 1.6, 1.0, base=(150, 92, 60))
    n = 6
    for i in reversed(range(n)):
        yb = -10 - i * 7.0
        apex = yb - 13.5
        hw = 8.8 * (1 - 0.78 * i / n)
        c.tt([(-hw, yb), (hw, yb), (0, apex)], (58, 118, 64), lit=0.16, dark=-0.32)


@_reg("pine_tall", 36, 62, shadow=12, tall=True)
@_reg("pine_short", 36, 40, shadow=12, tall=False)
def _pine(c, rng, tall=True):
    if tall:
        return _conifer(c, rng)
    top = -22
    _trunk(c, -top + 3, 1.8, 1.2, base=(150, 92, 60))
    if tall:
        c.lines(TRUNK_D, [(0, -16), (-7, -23)], 1.0)
        c.lines(TRUNK_D, [(0, -26), (6, -33)], 1.0)
    if tall:
        # a tall, narrow crown of small irregular clumps high on a bare trunk
        blobs = _cloud(rng, 8, 0, top + 2, 7, 12, 3.0, 4.6, 3)
        blobs += [(0, top - 6, 3.4, 3.0, 0)]
    else:
        blobs = _flat(_cloud(rng, 9, 0, top, 16, 6, 4.2, 6.2, 3), 1.2, 0.72)
    _crown(c, blobs, PINE)


@_reg("fir_tall", 32, 60, shadow=12, tall=True)
@_reg("fir_short", 32, 40, shadow=12, tall=False)
@_reg("snowy_tall", 32, 60, shadow=12, tall=True, snowy=True)
@_reg("snowy_short", 32, 40, shadow=12, tall=False, snowy=True)
def _fir(c, rng, tall=True, snowy=False):
    ht, n, wmax = (54, 5, 12.5) if tall else (34, 4, 11.0)
    _trunk(c, ht * 0.2, 1.3, 1.3, base=(104, 76, 52))
    sp = 0.82 * ht / (n + 0.6)
    th = 1.6 * sp
    for i in reversed(range(n)):
        yb = -ht * 0.18 - i * sp
        apex = yb - th
        hw = wmax * (1 - 0.84 * i / n)
        tri = [(-hw, yb), (hw, yb), (0, apex)]
        c.tt(tri, (40, 96, 74))
        if snowy:
            c.tt(clip(tri, lambda x, y, k=apex + th * 0.42: k - y), SNOW, lit=0.0, dark=-0.22)


@_reg("cypress", 22, 62, shadow=8)
def _cypress(c, rng):
    prof = [(0, -61), (3.8, -54), (6.4, -38), (7.2, -20), (5.4, -6), (2.6, 0), (-2.6, 0), (-5.4, -6),
            (-7.2, -20), (-6.4, -38), (-3.8, -54)]
    c.tt(prof, (44, 92, 62), lit=0.16, dark=-0.32)
    for y in (-46, -32, -18):
        c.line((30, 64, 44), (-4, y), (3, y + 1.6), 0.8)


@_reg("umbrella", 58, 56, shadow=18)
def _umbrella(c, rng):
    c.tt([(-1.8, 0), (1.8, 0), (4.6, -36), (2.4, -36)], TRUNK)
    blobs = [(-17, -34, 7, 4.4, 0), (-7, -40, 8, 5, 1), (6, -42, 9, 5.6, 0), (17, -35, 7, 4.6, 2),
             (0, -35, 10, 4.6, 1), (-11, -29, 6, 3.8, 2), (12, -29, 6, 3.8, 1)]
    _crown(c, blobs, [(62, 116, 56), (78, 132, 64), (48, 98, 48)])


@_reg("olive", 44, 44, shadow=14)
def _olive(c, rng):
    c.tt([(-4, 0), (3, 0), (1.4, -16), (-1.2, -16)], (122, 106, 84))
    c.tt([(-2.2, -13), (0.6, -13), (-8, -30), (-10.6, -28)], (118, 102, 82))
    c.tt([(0.2, -13), (2.6, -13), (10, -29), (8.6, -31)], (118, 102, 82))
    c.oval((58, 50, 42), -1, -7, 1.2, 1.8)
    _crown(c, _cloud(rng, 16, 0, -34, 19, 11, 4.4, 6.8, 3), [(150, 164, 130), (184, 196, 160), (116, 132, 108)])


@_reg("date_palm", 54, 64, shadow=14)
def _date_palm(c, rng):
    n = 12
    spine = [(5 * (i / n) ** 1.6, -44 * i / n) for i in range(n + 1)]
    left, right = [], []
    for i, (x, y) in enumerate(spine):
        w = 3.2 - 1.2 * (i / n)
        left.append((x - w, y))
        right.append((x + w, y))
    c.poly((168, 124, 80), left + right[::-1])
    c.lines(TRUNK_D, right, 1.2)
    for i in range(2, n - 1, 2):
        x, y = spine[i]
        c.line((120, 84, 50), (x - 2.6, y - 0.2), (x + 2.6, y - 0.2), 0.8)
    xc, yc = spine[-1]
    for ang, ln in ((170, 16), (140, 19), (110, 15), (80, 12), (50, 17), (20, 19), (-10, 18), (-40, 16),
                    (-75, 11)):
        a = math.radians(ang + rng.uniform(-4, 4))
        pts = [(xc + math.cos(a) * ln * t, yc - math.sin(a) * ln * t + 0.55 * ln * t * t)
               for t in [i / 6 for i in range(7)]]
        col = (74, 146, 64) if math.sin(a) > -0.2 else (44, 104, 48)
        c.lines(col, pts, 2.2)
        for t_i in (2, 3, 4, 5):
            px, py = pts[t_i]
            c.line((44, 104, 48), (px, py), (px + math.cos(a) * 2.2, py + 2.6), 1.0)
            c.line((44, 104, 48), (px, py), (px - math.cos(a) * 1.4, py + 2.2), 1.0)
    for dx, dy in ((-1.2, 3.6), (0.6, 4.2), (-0.2, 2.8)):
        c.circle((176, 100, 40), xc + dx, yc + dy, 1.5)


@_reg("jungle", 64, 78, shadow=26)
def _jungle(c, rng):
    c.tt([(-3.6, 0), (3.6, 0), (3.0, -46), (-3.0, -46)], (112, 88, 64))
    for s in (-1, 1):
        c.tt([(s * 3.2, -1), (s * 12.5, 0), (s * 3.2, -14)], (106, 82, 60))
    blobs = _cloud(rng, 16, 0, -54, 25, 15, 6, 10.5, 4)
    _crown(c, blobs, [(34, 100, 52), (52, 126, 62), (26, 84, 44), (70, 146, 70)])
    c.lines((28, 76, 42), [(-14, -46), (-16, -14)], 1.0)
    c.lines((28, 76, 42), [(10, -42), (12, -12)], 1.0)
    c.lines((28, 76, 42), [(2, -40), (1, -26)], 0.9)


@_reg("shrub", 30, 16, shadow=10)
def _shrub(c, rng):
    _crown(c, _cloud(rng, 6, 0, -7, 11, 6, 4.2, 6.2, 3), [(74, 122, 58), (90, 142, 66), (60, 104, 50)])


@_reg("dead_tree", 32, 50, shadow=12)
def _dead_tree(c, rng):
    c.tt([(-2.6, 0), (2.6, 0), (1.0, -40), (-1.0, -40)], (150, 138, 122))
    for a, b, w in (((0, -30), (-12, -44), 1.4), ((0, -26), (12, -38), 1.4), ((0, -40), (-5, -54), 1.2),
                    ((0, -40), (6, -52), 1.2), ((-12, -44), (-17, -51), 0.9), ((12, -38), (17, -46), 0.9)):
        c.line((104, 94, 84), a, b, w)


# ----------------------------------------------------------------------------------------------- ground clutter
@_reg("grass_tuft", 14, 10, shadow=0)
def _grass_tuft(c, rng):
    for i in range(7):
        x = -5 + i * 1.6 + rng.uniform(-0.5, 0.5)
        hgt = rng.uniform(4.5, 9.0)
        lean = rng.uniform(-2.2, 2.2)
        col = (104, 170, 76) if i % 2 else (62, 124, 52)
        c.poly(col, [(x - 0.9, 0), (x + 0.9, 0), (x + lean, -hgt)])


@_reg("fern", 22, 18, shadow=8)
def _fern(c, rng):
    for ang in (-160, -128, -96, -64, -32):
        a = math.radians(ang + rng.uniform(-6, 6))
        ln = rng.uniform(8, 10.5)
        pts = [(math.cos(a) * ln * t, math.sin(a) * ln * t + ln * 0.35 * t * t) for t in [i / 6 for i in range(7)]]
        c.lines((40, 96, 46), pts, 1.4)
        for t_i in (2, 3, 4, 5):
            px, py = pts[t_i]
            for side in (-1, 1):
                b = a + side * 1.0
                c.line((72, 146, 66), (px, py), (px + math.cos(b) * 2.6, py + math.sin(b) * 2.6 + 0.8), 1.0)


@_reg("stone", 16, 10, shadow=8)
def _stone(c, rng):
    pts = []
    for i in range(9):
        a = 2 * math.pi * i / 9
        rr = 1 + rng.uniform(-0.12, 0.12)
        pts.append((6.4 * math.cos(a) * rr, -4.2 + 4.0 * math.sin(a) * rr))
    c.tt(pts, (166, 162, 154))
    c.line((206, 202, 194), (-2.5, -6.2), (1.5, -6.8), 0.8)


@_reg("boulder", 26, 20, shadow=18)
def _boulder(c, rng):
    pts = []
    for i in range(11):
        a = 2 * math.pi * i / 11
        rr = 1 + rng.uniform(-0.08, 0.08)
        pts.append((11.5 * math.cos(a) * rr, -9 + 8.4 * math.sin(a) * rr))
    c.tt(pts, (148, 144, 136))
    c.lines((88, 84, 80), [(-3, -15), (0, -11), (-1, -7), (2, -4)], 1.0)
    c.oval((90, 138, 70), -5, -13, 2.2, 1.4)


OBJECT_NAMES = [
    "snow_peak", "twin_peak", "crag", "old_mountain", "volcano", "mesa", "foothills",
    "hill_green", "hill_dry", "hill_terraced", "outcrop",
    "oak", "oak_autumn", "beech", "linden", "birch", "pine_tall", "pine_short", "fir_tall", "fir_short",
    "snowy_tall", "snowy_short", "cypress", "umbrella", "olive", "date_palm", "jungle", "shrub", "dead_tree",
    "grass_tuft", "fern", "stone", "boulder",
]
for _name in OBJECT_NAMES:
    globals()[_name] = _public(_name)


# ----------------------------------------------------------------------------------------------- scatter
# count: objects wanted per full-density tile. spread: how close feet may stand (x half-widths).
KIND_SPEC = {
    "mixed_forest": dict(count=18, spread=0.5),
    "pine_forest": dict(count=16, spread=0.5),
    "jungle": dict(count=12, spread=0.55),
    "mediterranean": dict(count=12, spread=0.55),
    "mountain_range": dict(count=7, spread=0.8),
    "high_alps": dict(count=8, spread=0.8),
    "hills": dict(count=8, spread=0.7),
    "volcano": dict(count=9, spread=0.8),
}
KINDS = tuple(KIND_SPEC)
# (object, weight, max per tile or None)
SPECIES = {
    "mixed_forest": [("oak", 3, None), ("oak_autumn", 1.2, None), ("beech", 2, None), ("linden", 1.2, None),
                     ("birch", 2, None), ("pine_tall", 1, None), ("fir_short", 1, None), ("shrub", 2, None),
                     ("dead_tree", 0.3, None), ("grass_tuft", 1.5, None)],
    "pine_forest": [("pine_tall", 3, None), ("pine_short", 2, None), ("fir_tall", 4, None),
                    ("fir_short", 2, None), ("shrub", 0.8, None), ("dead_tree", 0.3, None),
                    ("grass_tuft", 1, None)],
    "jungle": [("jungle", 4, None), ("date_palm", 3, None), ("shrub", 2, None), ("fern", 3, None),
               ("grass_tuft", 1.5, None), ("boulder", 0.6, None)],
    "mediterranean": [("cypress", 3, None), ("umbrella", 3, None), ("olive", 3, None), ("shrub", 3, None),
                      ("stone", 2, None), ("boulder", 1, None)],
    "mountain_range": [("snow_peak", 3, None), ("twin_peak", 2, None), ("crag", 3, None),
                       ("old_mountain", 3, None), ("foothills", 2, None), ("fir_tall", 2, None),
                       ("outcrop", 1, None)],
    "high_alps": [("snow_peak", 4, None), ("twin_peak", 3, None), ("crag", 3, None),
                  ("snowy_short", 1, None), ("stone", 2, None), ("boulder", 2, None)],
    "hills": [("hill_green", 4, None), ("hill_dry", 2, None), ("hill_terraced", 2, None),
              ("outcrop", 1, None), ("shrub", 2, None), ("grass_tuft", 2, None), ("foothills", 1, None)],
    "volcano": [("volcano", 1, 1), ("dead_tree", 1.5, None), ("boulder", 2, None), ("stone", 3, None),
                ("crag", 0.6, None)],
}
FORCE_LARGE = {"volcano"}
SNOW_SWAP = {"fir_tall": "snowy_tall", "fir_short": "snowy_short"}


def _pick_size(depth, rng):
    """Bigger objects at the back (depth 0), smaller in front (depth 1)."""
    u = rng.random()
    if depth < 0.4:
        return "large" if u < 0.5 else ("medium" if u < 0.9 else "small")
    if depth < 0.7:
        return "medium" if u < 0.5 else ("small" if u < 0.75 else "large")
    return "small" if u < 0.6 else "medium"


def _plan(kind, density, seed, species=None, snowy=False, spread=None, force_volcano=True):
    """Choose where each object goes. Returns dicts sorted back to front."""
    rng = random.Random(zlib.crc32(f"plan|{kind}|{seed}|{snowy}".encode()))
    spec = KIND_SPEC[kind]
    sp_ = spec["spread"] if spread is None else spread
    table = list(species or SPECIES[kind])
    if snowy:
        table = [(SNOW_SWAP.get(n, n), w, m) for n, w, m in table]
    names = [t[0] for t in table]
    weights = [t[1] for t in table]
    limits = {t[0]: t[2] for t in table}
    want = max(1, round(spec["count"] * density))
    placed, counts = [], {}

    def add(name, size, x, y):
        sv = rng.randrange(VARIANTS)
        _, fw, _ = _get2x(name, size, sv)
        placed.append(dict(name=name, size=size, sv=sv, x=x, y=y, rad=fw * 0.5))
        counts[name] = counts.get(name, 0) + 1

    if kind in FORCE_LARGE and force_volcano:
        add("volcano", "large", CX + rng.uniform(-6, 6), 58 + rng.uniform(-4, 4))
    tries = 0
    while len(placed) < want and tries < 1500:
        tries += 1
        name = rng.choices(names, weights)[0]
        lim = limits.get(name)
        if lim is not None and counts.get(name, 0) >= lim:
            continue
        x, y = rng.uniform(16, 104), rng.uniform(26, 128)
        if not _in_hex(x, y, 6):
            continue
        size = "large" if name in FORCE_LARGE else _pick_size((y - 26) / 102, rng)
        sv = rng.randrange(VARIANTS)
        _, fw, _ = _get2x(name, size, sv)
        rad = fw * 0.5
        if any(math.hypot(x - p["x"], y - p["y"]) < sp_ * (rad + p["rad"]) for p in placed):
            continue
        placed.append(dict(name=name, size=size, sv=sv, x=x, y=y, rad=rad))
        counts[name] = counts.get(name, 0) + 1
    return sorted(placed, key=lambda p: p["y"])


def _draw_plan(surface, plan, scale):
    for p in plan:
        spr = _pub(p["name"], p["size"], p["sv"]) if scale == 1 else _get2x(p["name"], p["size"], p["sv"])[0]
        surface.blit(spr, (round(p["x"] * scale - spr.get_width() / 2), round(p["y"] * scale - spr.get_height())))


@lru_cache(maxsize=None)
def _hex_mask(scale):
    m = pygame.Surface((W * scale, H * scale), pygame.SRCALPHA)
    pygame.draw.polygon(m, (255, 255, 255, 255), [(x * scale, y * scale) for x, y in hex_pts(R - 0.3)])
    return m


def scatter(tile, kind, density=0.6, seed=0):
    """Draw a natural, varied cluster of `kind` onto a 120 x 140 tile surface, in place.
    density 0..1 scales how many objects are placed; seed gives a different arrangement."""
    layer = pygame.Surface((W, H), pygame.SRCALPHA)
    _draw_plan(layer, _plan(kind, density, seed), 1)
    layer.blit(_hex_mask(1), (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    tile.blit(layer, (0, 0))
    return tile


# ----------------------------------------------------------------------------------------------- whole tiles
TILE_SPECS = {
    "dense_forest": dict(kind="mixed_forest", ground=(86, 138, 60), density=1.0, spread=0.3,
                         speck=[(70, 116, 48), (104, 160, 76)]),
    "light_woodland": dict(kind="mixed_forest", ground=(134, 174, 88), density=0.42,
                           speck=[(118, 160, 76), (156, 196, 104)]),
    "pine_forest": dict(kind="pine_forest", ground=(78, 110, 66), density=1.0, spread=0.3,
                        speck=[(60, 88, 52), (96, 130, 80)]),
    "snowy_taiga": dict(kind="pine_forest", ground=(230, 238, 246), density=0.9, spread=0.35, snowy=True,
                        speck=[(196, 210, 224), (255, 255, 255)]),
    "jungle": dict(kind="jungle", ground=(54, 114, 52), density=1.0, spread=0.3,
                   speck=[(40, 92, 44), (74, 140, 64)]),
    "mediterranean_scrub": dict(kind="mediterranean", ground=(198, 178, 114), density=0.8,
                                speck=[(176, 156, 94), (222, 204, 140)]),
    "high_alps": dict(kind="high_alps", ground=(168, 174, 178), density=1.0, snow=22,
                      speck=[(120, 126, 130), (204, 210, 216)],
                      heroes=[("snow_peak", "large", 60, 116)]),
    "rocky_mountains": dict(kind="mountain_range", ground=(136, 122, 108), density=1.0,
                            speck=[(112, 100, 90), (160, 148, 134)], scree=(150, 138, 124),
                            heroes=[("crag", "large", 58, 116)]),
    "foothills": dict(kind="hills", ground=(146, 164, 96), density=0.8,
                      speck=[(124, 144, 80), (168, 182, 112)]),
    "volcano": dict(kind="volcano", ground=(112, 102, 96), density=1.0,
                    speck=[(88, 80, 76), (140, 130, 122)], crack=(240, 110, 40),
                    species=[("dead_tree", 1.5, None), ("boulder", 2, None), ("stone", 3, None),
                             ("crag", 0.6, None)],
                    force_volcano=False, heroes=[("volcano", "medium", 60, 120)]),
    "desert_mesas": dict(kind="mountain_range", ground=(224, 190, 130), density=0.8,
                         species=[("mesa", 4, None), ("boulder", 1.5, None), ("stone", 2, None),
                                  ("outcrop", 1, None)],
                         speck=[(206, 170, 112), (238, 210, 160)]),
    "rolling_hills": dict(kind="hills", ground=(128, 176, 90), density=1.0,
                          speck=[(110, 158, 74), (150, 194, 110)]),
}
TILE_KINDS = tuple(TILE_SPECS)
VARIANT_DENSITY = (1.0, 0.85, 0.7)


def draw_tile(name, variant=0):
    """A whole 120 x 140 hex tile: ground, snow or scree, specks, heroes and a scattered cluster, masked to the hex."""
    spec = TILE_SPECS[name]
    seed = 100 + 7 * variant + zlib.crc32(name.encode()) % 50
    rng = random.Random(seed)
    ground = shade(spec["ground"], rng.uniform(-0.04, 0.04))
    surf = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
    pygame.draw.polygon(surf, ground, [(x * K, y * K) for x, y in hex_pts(R - 0.3)])
    pygame.draw.polygon(surf, shade(ground, -0.14), [(x * K, y * K) for x, y in hex_pts(R - 1)], 2)
    if spec.get("scree"):
        scree = [(14, 140), (14, 128), (44, 104), (60, 94), (76, 104), (106, 128), (106, 140)]
        pygame.draw.polygon(surf, spec["scree"], [(x * K, y * K) for x, y in scree])
        for _ in range(70):
            x, y = rng.uniform(16, 104), rng.uniform(100, 136)
            if _in_hex(x, y, 3):
                pygame.draw.ellipse(surf, shade(spec["scree"], rng.uniform(-0.25, 0.2)),
                                    pygame.Rect(round(x * K), round(y * K), rng.randint(2, 4), rng.randint(2, 3)))
    for _ in range(spec.get("snow", 0)):
        x, y = rng.uniform(10, 110), rng.uniform(10, 104)
        if _in_hex(x, y, 4):
            pygame.draw.ellipse(surf, (246, 250, 252),
                                pygame.Rect(round(x * K), round(y * K), rng.randint(8, 16), rng.randint(3, 5)))
    for _ in range(90):
        x, y = rng.uniform(4, 116), rng.uniform(4, 136)
        if _in_hex(x, y, 3):
            pygame.draw.ellipse(surf, rng.choice(spec["speck"]),
                                pygame.Rect(round(x * K), round(y * K), rng.randint(2, 4), rng.randint(2, 3)))
    if spec.get("crack"):
        for _ in range(3):
            x, y = rng.uniform(30, 90), rng.uniform(60, 110)
            pygame.draw.lines(surf, spec["crack"], False, [(x * K, y * K), ((x + 4) * K, (y + 3) * K),
                                                           ((x + 2) * K, (y + 7) * K)], K)
    density = spec["density"] * VARIANT_DENSITY[variant % 3]
    plan = _plan(spec["kind"], density, seed, species=spec.get("species"), snowy=spec.get("snowy", False),
                 spread=spec.get("spread"), force_volcano=spec.get("force_volcano", True))
    for hname, hsize, hx, hy in spec.get("heroes", []):
        plan.append(dict(name=hname, size=hsize, sv=variant, x=hx + rng.uniform(-2, 2), y=hy, rad=0))
    plan.sort(key=lambda p: p["y"])
    layer = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
    _draw_plan(layer, plan, K)
    surf.blit(layer, (0, 0))
    surf.blit(_hex_mask(K), (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    return pygame.transform.smoothscale(surf, (W, H))
