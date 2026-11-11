"""Water, coast, life and ruin objects and scatter clusters (ported from the tile-design mockup).

Style = goodsart: flat two-tone shading (lit left, darker right), 1-2 px dark ink outlines, drawn at 2x, smooth-scaled.
Water colours are wfctiles' own (goodsart WATER / WATER_L), so objects sit on the existing sea and coasts.

OBJECTS  every object function is f(size="m", seed=0) -> pygame.Surface (RGBA, transparent).
         The BASE POINT is at (w // 2, h - 1), the bottom centre. Sizes: "s" x0.6, "m" x1.0, "l" x1.5.
         Water objects are drawn on water; land objects on grass. OBJECTS maps name -> function.
scatter  scatter(tile, kind, density=1.0, seed=0) blits a varied natural cluster onto `tile` IN PLACE, back to front,
         and returns it. KINDS: coast_life, open_sea, arctic_sea, pasture_life, wild_woods_life, desert_life, ruins,
         holy_place.
"""
import math
import random
import zlib

import pygame

from .art import shade
from .goodsart import (DARK, DWOOD, INK, ROOF_RED, ROOF_SLATE, THATCH, WATER, WATER_L, WHITE, WOOD,
                       Pen, building, cow, ell, flag, horse, lerp, mix, pine, round_tree, sheep, tower, wheel)
from .wfctiles import SAND, scale_tile

W, H = 120, 140
CX, CY = W / 2, H / 2
R = 69.3
MASK_R = R + 1.0
K = 2
SIZES = {"s": 0.6, "m": 1.0, "l": 1.5}
SIZE_MAX = {"monastery": "m", "aqueduct": "m", "camel_caravan": "m", "roman_ruins": "m", "ruined_castle": "m",
            "market_fair": "m", "native_village": "m", "windmill_post": "m", "cattle_herd": "m",
            "horse_herd": "m", "watchtower": "m", "gallows_hill": "m", "battlefield": "m", "storks_roof": "m",
            "pilgrimage_chapel": "m", "shipwreck": "m"}

# palette: water and coast come from wfctiles / goodsart so they match the existing sea exactly
GRASS = (39, 174, 96)
GRASS_D = (74, 130, 66)
SURF_C = mix(WATER, WATER_L, 0.6)           # wfctiles.SURF
WATER_DEEP = (58, 120, 178)                 # wfctiles.RIVER_EDGE family: the darker sea tone
ROCK = (150, 142, 130)
ROCK_D = shade(ROCK, -0.3)
ROCK_B = (170, 160, 142)
MOSS = (96, 132, 74)
WHALE = (72, 94, 116)
ICE, ICE_S, ICE_D = (240, 248, 252), (186, 216, 236), (128, 170, 204)
REED = (112, 150, 70)
CATTAIL = (116, 74, 42)
STONE_C = (206, 200, 186)
STONE_D = (188, 180, 166)
BARK = (168, 128, 86)
CLOTH = (236, 230, 214)
PAD = (84, 150, 80)
PAD_D = (58, 116, 60)
STRAW = (222, 190, 104)
GOAT_C = (206, 190, 160)
DEER_C = (176, 128, 84)
SKIN_C = (238, 200, 165)


# ===================================================================================================
# drawing frame: object units -> pixels, with a 2x ground layer, a 2x outline layer and stamping
# ===================================================================================================
OFFS = [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)]
OFFS_THIN = [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)]
_MASKS = {}


class Frame:
    """Pen-like wrapper so goodsart helpers (building, tower, cow, boat ...) draw in object units.
    Coordinates are relative to the base point (0, 0 = bottom centre, y negative upwards)."""

    def __init__(self, surf, ox, oy, f):
        self.pen = Pen(surf)
        self.ox, self.oy, self.f = ox, oy, f

    def T(self, x, y):
        return (self.ox + x * self.f, self.oy + y * self.f)

    def _p(self, pts):
        return [self.T(x, y) for x, y in pts]

    def _lw(self, w):
        return max(0.5, w * (0.5 + 0.5 * self.f)) if w else 0

    def poly(self, c, pts, w=0):
        self.pen.poly(c, self._p(pts), self._lw(w))

    def circle(self, c, xy, r, w=0):
        self.pen.circle(c, self.T(*xy), r * self.f, self._lw(w))

    def oval(self, c, cx, cy, rx, ry, wd=0):
        x, y = self.T(cx, cy)
        self.pen.oval(c, x, y, rx * self.f, ry * self.f, self._lw(wd))

    def line(self, c, a, b, w=1):
        self.pen.line(c, self.T(*a), self.T(*b), self._lw(w))

    def lines(self, c, pts, w=1, closed=False):
        self.pen.lines(c, self._p(pts), self._lw(w), closed)

    def band(self, c, pts, w):
        self.pen.band(c, self._p(pts), w * self.f)

    def rect(self, c, x, y, w, h, wd=0, br=0):
        x0, y0 = self.T(x, y)
        self.pen.rect(c, x0, y0, w * self.f, h * self.f, self._lw(wd), br * self.f)


class Obj:
    """One object: `g` = ground layer (shadows, foam, water; not outlined), `o` = object layer (outlined)."""

    def __init__(self, size, bw, bh, minf=0.0):
        f = max(SIZES[size], minf)
        self.f = f
        self.cw, self.ch = max(4, round(bw * f)), max(4, round(bh * f))
        ox, oy = self.cw / 2, self.ch - 1
        self.ox, self.oy = ox, oy
        self.surf = pygame.Surface((self.cw * K, self.ch * K), pygame.SRCALPHA)
        self.layer = pygame.Surface((self.cw * K, self.ch * K), pygame.SRCALPHA)
        self.g = Frame(self.surf, ox, oy, f)
        self.o = Frame(self.layer, ox, oy, f)

    def shadow(self, x, y, w, h=None, a=45):
        h = h or w * 0.35
        cx, cy = self.g.T(x, y)
        sw, sh = max(1, int(w * self.f * K)), max(1, int(h * self.f * K))
        sur = pygame.Surface((sw, sh), pygame.SRCALPHA)
        pygame.draw.ellipse(sur, (0, 0, 0, a), sur.get_rect())
        self.surf.blit(sur, (round(cx * K - sw / 2), round(cy * K - sh / 2)))

    def glow(self, pts, rgba):
        """Translucent polygon (light beams) on the ground layer."""
        tmp = pygame.Surface(self.surf.get_size(), pygame.SRCALPHA)
        pygame.draw.polygon(tmp, rgba, [((self.ox + x * self.f) * K, (self.oy + y * self.f) * K) for x, y in pts])
        self.surf.blit(tmp, (0, 0))

    def stamp(self, ink=2):
        r = self.layer.get_bounding_rect(1)
        if not r.w:
            return
        r = r.inflate(8, 8).clip(self.layer.get_rect())
        sub = self.layer.subsurface(r)
        if ink:
            sil = pygame.mask.from_surface(sub, 40).to_surface(setcolor=INK + (255,), unsetcolor=(0, 0, 0, 0))
            for dx, dy in (OFFS if ink >= 2 else OFFS_THIN):
                self.surf.blit(sil, (r.x + dx, r.y + dy))
        self.surf.blit(sub, r.topleft)
        self.layer.fill((0, 0, 0, 0), r)

    def finish(self, ink=2):
        self.stamp(ink)
        return scale_tile(self.surf, self.cw, self.ch)


def _rng(*key):
    return random.Random(zlib.crc32("|".join(map(str, key)).encode()))


def _boulder(p, x, y, w, h, col=ROCK):
    p.poly(col, [(x - w / 2, y), (x - w * 0.42, y - h * 0.7), (x - w * 0.08, y - h), (x + w * 0.32, y - h * 0.92),
                 (x + w / 2, y - h * 0.25), (x + w / 2, y)])
    p.poly(shade(col, -0.3), [(x + w * 0.02, y - h * 0.98), (x + w * 0.32, y - h * 0.92), (x + w / 2, y - h * 0.25),
                              (x + w / 2, y), (x + w * 0.12, y)])
    p.line(shade(col, -0.35), (x - w * 0.3, y - h * 0.4), (x + w * 0.05, y - h * 0.5), 0.8)


def _stone_block(p, x, y, w, h, col=STONE_C):
    p.rect(col, x - w / 2, y - h, w, h)
    p.rect(shade(col, -0.25), x + w * 0.2, y - h, w * 0.3, h)


# ===================================================================================================
# 1. WATER AND COAST
# ===================================================================================================
def waterfall(size="m", seed=0):
    ob = Obj(size, 46, 56)
    g, o = ob.g, ob.o
    g.oval(WATER_DEEP, 0, -3, 22, 5.5)
    g.oval(WATER, 0, -3.6, 20, 4.2)
    g.oval(WATER_L, 0, -4.2, 11, 1.6)
    face = [(-18, -46), (-13, -50), (-4, -48), (5, -52), (13, -47), (19, -43), (20, -20), (16, -8), (9, -5),
            (-9, -5), (-16, -9), (-19, -22)]
    o.poly(ROCK, face)
    o.poly(ROCK_D, [(2, -51), (13, -47), (19, -43), (20, -20), (16, -8), (9, -5), (3, -6), (6, -26), (2, -40)])
    for yy in (-30, -21, -13):
        o.line(ROCK_D, (-16, yy), (-6, yy + 2), 0.9)
    o.poly(MOSS, [(-18, -46), (-13, -50), (-4, -48), (5, -52), (13, -47), (19, -43), (17, -41), (9, -45), (-1, -44),
                  (-12, -44), (-17, -41)])
    o.poly(WATER, [(-5, -48), (2, -48), (4, -10), (-7, -10)])
    o.line(WATER_L, (-2.5, -46), (-2, -12), 1.2)
    o.oval(WHITE, 0, -7, 12, 3.2)
    return ob.finish()


def rapids(size="m", seed=0):
    rng = _rng("rapids", seed)
    ob = Obj(size, 54, 26)
    g, o = ob.g, ob.o
    band = [(-26, -4), (-14, -9), (0, -11), (14, -9), (26, -4)]
    g.band(WATER, band, 11)
    g.band(WATER_L, [(x, y - 1.2) for x, y in band], 3)
    for _ in range(7):
        x, y = rng.uniform(-22, 22), rng.uniform(-14, -4)
        g.line(WHITE, (x, y), (x + rng.uniform(3, 6), y - 0.4), 1.1)
    for x, y, w, h in [(-10, -5, 7, 6), (4, -9, 8, 7), (16, -4, 6, 5)]:
        g.oval(WHITE, x, y, w * 0.75, 2)
        _boulder(o, x, y, w, h)
    return ob.finish()


def sea_rocks(size="m", seed=0):
    rng = _rng("sea_rocks", seed)
    ob = Obj(size, 40, 28)
    rocks = [(-9, -2, 12, 9), (7, -1, 9, 6), (0, -6, 6, 6)]
    if rng.random() < 0.5:
        rocks = [(-10, -3, 10, 8), (8, -2, 12, 9)]
    for x, y, w, h in rocks:
        ob.g.oval(SURF_C, x, y + 0.5, w * 0.95, 3.2)
        ob.g.oval(WHITE, x, y, w * 0.72, 2.0)
    for x, y, w, h in sorted(rocks, key=lambda q: q[1]):
        _boulder(ob.o, x, y, w, h)
    return ob.finish()


def sea_stack(size="m", seed=0):
    ob = Obj(size, 42, 52)
    g, o = ob.g, ob.o
    g.oval(SURF_C, 0, -3, 17, 4.5)
    g.oval(WHITE, 0, -3.5, 14, 2.6)
    column = [(-10, -1), (-12, -16), (-9, -32), (-6, -41), (-2, -46), (3, -44), (6, -35), (9, -20), (11, -1)]
    o.poly(ROCK, column)
    o.poly(ROCK_D, [(1, -45), (3, -44), (6, -35), (9, -20), (11, -1), (3, -1), (2, -22), (0, -38)])
    o.line(ROCK_D, (-11, -18), (9, -20), 0.9)
    o.line(ROCK_D, (-10, -30), (7, -31), 0.9)
    o.poly(MOSS, [(-6, -41), (-2, -46), (3, -44), (0, -42)])
    g.oval(WHITE, 17, -2, 7, 2)
    o.poly(ROCK, [(12, -1), (13, -9), (17, -14), (19, -11), (22, -1)])
    o.poly(ROCK_D, [(16, -13), (19, -11), (22, -1), (17, -1)])
    return ob.finish()


def reef_surf(size="m", seed=0):
    """Surf only: white breaker arcs along an outer reef edge (no rocks)."""
    rng = _rng("reef", seed)
    ob = Obj(size, 60, 26)
    g = ob.g
    for i in range(8):
        x = -26 + i * 7.5 + rng.uniform(-1, 1)
        g.lines(WHITE, [(x - 4.5, -10), (x, -13.5), (x + 4.5, -10)], 1.6)
        g.lines(SURF_C, [(x - 5, -6), (x, -8.5), (x + 5, -6)], 1.2)
    g.oval(WHITE, 0, -4, 24, 2.2)
    return ob.finish(ink=0)


CORAL = [(236, 112, 140), (240, 150, 72), (246, 210, 96), (150, 96, 200), (232, 92, 110)]
TURQ = (104, 210, 206)


def _coral_branch(p, x, y, col, s, rng):
    for _ in range(5):
        a = math.radians(-90 + rng.uniform(-48, 48))
        L = rng.uniform(6, 10) * s
        ex, ey = x + math.cos(a) * L * 0.6, y + math.sin(a) * L
        p.line(shade(col, -0.15), (x, y), (ex, ey), 2.8 * s)
        p.circle(shade(col, 0.3), (ex, ey), 1.6 * s)


def _coral_brain(p, x, y, col, s):
    p.oval(col, x, y - 2.8 * s, 4.8 * s, 3.0 * s)
    p.oval(shade(col, -0.22), x + 1.4 * s, y - 2.4 * s, 3.4 * s, 2.3 * s)
    for k in (-1.4, 0, 1.4):
        p.line(shade(col, -0.45), (x - 3.2 * s, y - 2.8 * s + k * s), (x + 3.2 * s, y - 2.8 * s + k * s), 0.7)


def coral_patch(size="m", seed=0):
    """A small coral head cluster: branching and brain corals in pink, orange, yellow and purple."""
    rng = _rng("coral", seed)
    ob = Obj(size, 44, 28)
    ob.g.oval(TURQ, 0, -4, 20, 6)
    spots = [(-12, -5), (0, -7), (12, -4), (-5, -2), (7, -2)]
    rng.shuffle(spots)
    for x, y in sorted(spots[:4], key=lambda q: q[1]):
        col = rng.choice(CORAL)
        s_ = rng.uniform(0.85, 1.1)
        if rng.random() < 0.5:
            _coral_branch(ob.o, x, y, col, s_, rng)
        else:
            _coral_brain(ob.o, x, y, col, s_)
    return ob.finish()


def sandbar(size="m", seed=0):
    rng = _rng("sandbar", seed)
    ob = Obj(size, 50, 20)
    g = ob.g
    g.oval(mix(WATER, WATER_L, 0.75), 0, -5, 24, 8.5)
    g.oval(WHITE, 0, -5.5, 22, 6.2)
    g.oval(SAND, 0, -6, 19, 5.2)
    g.oval(shade(SAND, -0.12), 0, -4.4, 17, 2.4)
    for _ in range(3):
        x = rng.uniform(-10, 8)
        g.line(shade(SAND, -0.25), (x, -8), (x + 3, -8.4), 0.8)
    g.lines(GRASS_D, [(-3, -9), (-2.4, -12), (-1.8, -9)], 1.0)
    g.lines(GRASS_D, [(-1, -9), (0.2, -13), (1.2, -9)], 1.0)
    return ob.finish()


def lily_pond(size="m", seed=0):
    rng = _rng("lily", seed)
    ob = Obj(size, 40, 20)
    g = ob.g
    g.oval(WATER_DEEP, 0, -9, 18, 7.5)
    g.oval(WATER, 0, -9.6, 16.5, 6)
    g.oval(WATER_L, -4, -11, 6, 1.4)
    for x, y, r in [(-9, -8, 3.6), (3, -12, 3.2), (10, -7, 3.4), (-3, -5, 2.8), (-13, -12, 2.6)]:
        g.oval(PAD_D, x, y + 0.5, r, r * 0.5)
        g.oval(PAD, x, y, r, r * 0.5)
        g.poly(WATER, [(x, y), (x + r * 0.7, y - r * 0.4), (x + r, y + 0.1)])
        if rng.random() < 0.3:
            g.circle((246, 170, 200), (x, y - 1), 1.6)
            g.circle((250, 236, 150), (x, y - 1), 0.7)
    return ob.finish(ink=1)


def reeds(size="m", seed=0):
    rng = _rng("reeds", seed)
    ob = Obj(size, 26, 36)
    o = ob.o
    ob.g.oval(WATER_DEEP, 0, -2, 11, 3)
    ob.g.oval(WATER, 0, -2.5, 10, 2.2)
    for i in range(8):
        x = -9 + i * 2.6 + rng.uniform(-0.8, 0.8)
        h = rng.uniform(20, 33)
        lean = rng.uniform(-2.5, 2.5)
        o.lines(REED, [(x, -1), (x + lean * 0.4, -h * 0.5), (x + lean, -h)], 1.2)
        o.poly(shade(REED, 0.14), [(x + lean * 0.4, -h * 0.45), (x + lean * 0.4 + 3.5, -h * 0.55),
                                   (x + lean * 0.4 - 0.6, -h * 0.62)])
    return ob.finish(ink=1)


def cattails(size="m", seed=0):
    rng = _rng("cattails", seed)
    ob = Obj(size, 24, 38)
    o = ob.o
    ob.g.oval(WATER_DEEP, 0, -2, 10, 2.6)
    ob.g.oval(WATER, 0, -2.4, 9, 2)
    for i in range(5):
        x = -6 + i * 3 + rng.uniform(-0.6, 0.6)
        h = rng.uniform(24, 34)
        o.line((96, 132, 62), (x, -1), (x + rng.uniform(-1, 1), -h), 1.0)
        o.rect(CATTAIL, x - 1.3, -h - 6, 2.6, 6.5, br=1.2)
        o.line(shade(CATTAIL, 0.3), (x - 0.4, -h - 5), (x - 0.4, -h + 0.5), 0.6)
    o.poly((100, 146, 70), [(-8, -1), (-3, -20), (-7, -16)])
    o.poly((90, 136, 62), [(7, -1), (3, -22), (8, -14)])
    return ob.finish(ink=1)


def sea_cliff(size="m", seed=0):
    ob = Obj(size, 60, 48)
    g, o = ob.g, ob.o
    g.oval(WHITE, 0, -2, 28, 3)
    g.oval(SURF_C, 0, -2.5, 31, 4.5)
    face = [(-26, -1), (-27, -18), (-24, -30), (-20, -38), (-12, -44), (-4, -42), (4, -46), (14, -42), (22, -38),
            (26, -26), (27, -1)]
    o.poly(ROCK, face)
    o.poly(ROCK_D, [(4, -45), (14, -42), (22, -38), (26, -26), (27, -1), (8, -1), (10, -22), (6, -34)])
    for yy in (-12, -24, -34):
        o.line(ROCK_D, (-24, yy), (2, yy + 2), 0.9)
        o.line(ROCK_D, (4, yy + 3), (24, yy - 1), 0.9)
    o.poly(MOSS, [(-20, -38), (-12, -44), (-4, -42), (4, -46), (14, -42), (22, -38), (20, -35), (10, -39), (0, -37),
                  (-10, -38), (-18, -34)])
    return ob.finish()


def lighthouse(size="m", seed=0):
    ob = Obj(size, 64, 60)
    o = ob.o

    def hw(y):
        return 6.5 - 2.6 * ((-y - 1) / 39)

    ob.glow([(0, -46), (-31, -60), (-31, -36)], (255, 244, 170, 58))
    ob.glow([(0, -46), (31, -60), (31, -36)], (255, 244, 170, 58))
    o.poly(ROCK, [(-14, -1), (-12, -5), (-6, -6), (6, -6), (12, -5), (14, -1)])
    body = [(-hw(-1), -1), (-hw(-40), -40), (hw(-40), -40), (hw(-1), -1)]
    o.poly(WHITE, body)
    o.poly(shade(WHITE, -0.22), [(hw(-40) * 0.2, -40), (hw(-40), -40), (hw(-1), -1), (hw(-1) * 0.2, -1)])
    for y0, y1 in ((-14, -20), (-30, -35)):
        o.poly(ROOF_RED, [(-hw(y0), y0), (hw(y0), y0), (hw(y1), y1), (-hw(y1), y1)])
    o.rect(DARK, -1.6, -9, 3.2, 8, br=1.4)
    o.rect(DARK, -1, -26, 2, 3)
    o.poly(ROOF_SLATE, [(-5.5, -40), (5.5, -40), (5.5, -38), (-5.5, -38)])
    o.line(DARK, (-5.5, -40), (5.5, -40), 0.6)
    o.rect((250, 240, 180), -3.5, -50, 7, 10)
    o.rect(DARK, -3.5, -50, 7, 10, wd=0.8)
    o.line(DARK, (0, -50), (0, -40), 0.6)
    o.poly(ROOF_RED, [(-4.8, -50), (4.8, -50), (0, -55)])
    o.circle((255, 246, 190), (0, -45), 2.2)
    return ob.finish()


def fishing_boat(size="m", seed=0):
    ob = Obj(size, 34, 30)
    g, o = ob.g, ob.o
    g.oval(SURF_C, 0, -3, 18, 4)
    g.lines(WHITE, [(-19, -4), (-16, -2.4), (-13, -4)], 1.0)
    g.lines(WHITE, [(13, -3), (17, -4.5), (20, -3)], 1.0)
    o.poly((176, 72, 58), [(-14, -9), (14, -9), (10, -2), (-10, -2)])
    o.poly(shade((176, 72, 58), -0.25), [(4, -9), (14, -9), (10, -2), (2, -2)])
    o.line(DWOOD, (-14, -9), (14, -9), 1.2)
    o.rect((226, 222, 214), -7, -18, 11, 9)
    o.rect(shade((226, 222, 214), -0.2), 2, -18, 2, 9)
    o.poly((60, 70, 88), [(-8, -18), (5, -18), (5, -20), (-8, -20)])
    o.rect(DARK, -4.5, -15, 3, 3)
    o.line(DWOOD, (9, -9), (9, -28), 1.1)
    flag(o, 9, -28, 5, (240, 200, 60))
    o.line(DWOOD, (-11, -10), (-18, -20), 1.0)
    return ob.finish()


def whale_spout(size="m", seed=0):
    ob = Obj(size, 56, 44)
    g, o = ob.g, ob.o
    g.oval(SURF_C, 0, -4, 24, 6)
    g.lines(WHITE, [(-25, -3), (-21, -2.2), (-17, -3)], 1.0)
    g.lines(WHITE, [(14, -2), (19, -3.2), (25, -2)], 1.0)
    o.poly(WHALE, ell(0, -6, 20, 8, 180, 360, 20))
    o.poly((160, 176, 190), ell(0, -6, 19, 2.4, 0, 180, 12))
    o.poly(WHALE, [(18, -7), (29, -16), (25, -5)])
    o.poly(WHALE, [(-2, -13), (2, -19), (5, -12)])
    for dx, dy in [(-4, -12), (-6, -14), (-2, -12)]:
        o.line(WHITE, (-6, -14), (-6 + dx, -14 + dy), 1.8)
        o.circle(WHITE, (-6 + dx, -14 + dy), 1.4)
    return ob.finish()


def seabirds(size="m", seed=0):
    rng = _rng("seabirds", seed)
    n = {"s": 3, "m": 5, "l": 7}[size]
    ob = Obj(size, 40, 22, minf=0.8)
    o = ob.o
    for i in range(n):
        x = -15 + i * (30 / max(1, n - 1)) + rng.uniform(-1.5, 1.5)
        y = -9 + rng.uniform(-6, 2) + (i % 2) * -3
        s = rng.uniform(1.5, 1.9)
        o.poly(WHITE, [(x, y), (x - 3.8 * s, y - 2.4 * s), (x - 5.2 * s, y + 0.2 * s), (x - 1.8 * s, y - 0.7 * s)])
        o.poly(WHITE, [(x, y), (x + 3.8 * s, y - 2.4 * s), (x + 5.2 * s, y + 0.2 * s), (x + 1.8 * s, y - 0.7 * s)])
        o.line((40, 42, 50), (x - 5.2 * s, y + 0.2 * s), (x - 3.4 * s, y - 1.6 * s), 1.2)
        o.line((40, 42, 50), (x + 5.2 * s, y + 0.2 * s), (x + 3.4 * s, y - 1.6 * s), 1.2)
    return ob.finish(ink=2)


def iceberg(size="m", seed=0):
    ob = Obj(size, 48, 38)
    g, o = ob.g, ob.o
    g.oval(mix(WATER_L, WHITE, 0.5), 0, -4, 22, 5)
    g.oval(WHITE, 0, -4.5, 19, 3)
    g.poly(ICE, [(-26, -3), (-22, -6), (-18, -3), (-22, -1)])
    g.poly(ICE_S, [(20, -2), (25, -5), (28, -2), (23, -1)])
    main = [(-20, -4), (-16, -14), (-10, -22), (-5, -29), (-1, -34), (4, -38), (7, -31), (10, -25), (15, -14), (20, -4)]
    o.poly(ICE, main)
    o.poly(ICE_S, [(4, -38), (7, -31), (10, -25), (15, -14), (20, -4), (8, -5), (4, -16), (5, -28)])
    o.line(ICE_D, (-5, -29), (2, -18), 0.8)
    o.line(ICE_D, (8, -22), (13, -12), 0.7)
    o.poly((190, 230, 242), [(-18, -4), (18, -4), (12, -1), (-12, -1)])
    return ob.finish()


def shipwreck(size="m", seed=0):
    ob = Obj(size, 58, 42)
    g, o = ob.g, ob.o
    g.oval(SURF_C, 0, -3, 27, 5)
    g.oval(WHITE, 0, -3, 24, 3.2)
    _boulder(o, -24, -2, 12, 9)
    _boulder(o, 22, -2, 14, 11)
    _boulder(o, 4, -1, 8, 5)
    hull = [(-20, -10), (-8, -14), (10, -12), (20, -16), (24, -12), (14, -3), (-4, -2), (-18, -4)]
    o.poly((112, 74, 44), hull)
    o.poly((86, 56, 34), [(-4, -2), (14, -3), (24, -12), (20, -16), (10, -12), (-8, -14), (-4, -8)])
    o.lines(DWOOD, [(-18, -8), (16, -9)], 0.8)
    o.poly((112, 74, 44), [(18, -16), (22, -24), (26, -19), (24, -12)])
    o.line(DWOOD, (-2, -13), (-6, -34), 2.2)
    o.poly(DWOOD, [(-6, -34), (-4.8, -37), (-6, -37.5), (-7.2, -36)])
    o.poly(CLOTH, [(-6, -33), (-1, -30), (4, -28), (8, -18), (4, -22), (0, -20), (-3, -24), (-6, -26)])
    o.poly(shade(CLOTH, -0.14), [(-1, -30), (4, -28), (8, -18), (4, -22), (0, -20), (-1, -25)])
    o.line(DWOOD, (-6, -33), (-18, -16), 0.6)
    o.line(DWOOD, (-6, -33), (14, -14), 0.6)
    return ob.finish()


# ===================================================================================================
# 2. LIFE
# ===================================================================================================
def _herd_draw(ob, items, drawer):
    for x, y, *rest in sorted(items, key=lambda q: q[1]):
        ob.shadow(x, y + 0.5, 14, 3.2, a=45)
    for x, y, *rest in sorted(items, key=lambda q: q[1]):
        drawer(ob.o, x, y, *rest)


def cattle_herd(size="m", seed=0):
    rng = _rng("cattle", seed)
    ob = Obj(size, 50, 28, minf=0.8)
    herd = [(-15, -1, 0.95, False, WHITE, (40, 40, 46)),
            (1, -6, 0.9, True, (150, 100, 66), (60, 40, 30)),
            (16, -2, 0.95, False, WHITE, (56, 54, 60))]
    if rng.random() < 0.5:
        herd[1] = (1, -6, 0.9, True, (110, 74, 48), (232, 226, 214))
    _herd_draw(ob, [(x, y) for x, y, *_ in herd],
               lambda p, x, y: None)
    for x, y, s, flip, col, sp in sorted(herd, key=lambda q: q[1]):
        cow(ob.o, x, y, s, flip, col, sp)
    return ob.finish()


def sheep_flock(size="m", seed=0):
    rng = _rng("sheep", seed)
    n = {"s": 3, "m": 5, "l": 7}[size]
    ob = Obj(size, 40, 20)
    pts = []
    for k in range(n):
        row = k % 2
        x = -14 + (k // 2) * 11 + row * 5.5 + rng.uniform(-1, 1)
        y = -2 - row * 5
        pts.append((x, y, rng.random() < 0.5))
    for x, y, _ in pts:
        ob.shadow(x, y + 0.5, 12, 3, a=40)
    for x, y, flip in sorted(pts, key=lambda q: q[1]):
        sheep(ob.o, x, y, 0.9, flip)
    return ob.finish()


def horse_herd(size="m", seed=0):
    ob = Obj(size, 56, 34)
    herd = [(-17, -3, False, (130, 82, 50), 1.0, False), (3, -9, True, (204, 204, 208), 0.9, True),
            (16, -2, False, (56, 46, 42), 1.0, False)]
    for x, y, flip, col, s, gal in herd:
        ob.shadow(x, y + 0.5, 20 * s, 3.5)
    for x, y, flip, col, s, gal in sorted(herd, key=lambda q: q[1]):
        horse(ob.o, x, y, col=col, s=s, flip=flip, gallop=gal)
    return ob.finish()


def goat(p, x, y, s=1.0, flip=False, col=GOAT_C):
    f = -1 if flip else 1
    dk = shade(col, -0.3)
    for lx in (-3.5, -1.5, 2.5, 4):
        p.line(dk, (x + lx * s, y - 3 * s), (x + lx * s, y), 0.9 * s)
    p.oval(col, x, y - 8 * s, 5.8 * s, 3.2 * s)
    p.oval(shade(col, -0.2), x - f * 1.5 * s, y - 7 * s, 3.5 * s, 2.2 * s)
    p.line(dk, (x - f * 5.5 * s, y - 9 * s), (x - f * 7.5 * s, y - 11 * s), 0.9 * s)
    hx, hy = x + f * 6.5 * s, y - 12 * s
    p.oval(col, hx, hy, 2.6 * s, 2.1 * s)
    p.poly(DARK, [(hx + f * 1.5 * s, hy + 1.6 * s), (hx + f * 2.8 * s, hy + 4 * s), (hx + f * 0.8 * s, hy + 2.2 * s)])
    p.line(WHITE, (hx - f * 0.5 * s, hy - 1.8 * s), (hx - f * 1.5 * s, hy - 5.5 * s), 0.9 * s)
    p.line(WHITE, (hx + f * 0.5 * s, hy - 1.8 * s), (hx + f * 0.2 * s, hy - 5 * s), 0.9 * s)


def goat_herd(size="m", seed=0):
    ob = Obj(size, 42, 26)
    herd = [(-11, -2, 0.95, False, GOAT_C), (4, -7, 0.85, True, (120, 88, 60)), (15, -1, 0.95, False, (236, 234, 226))]
    for x, y, s, f, c in herd:
        ob.shadow(x, y + 0.5, 12 * s, 3)
    for x, y, s, f, c in sorted(herd, key=lambda q: q[1]):
        goat(ob.o, x, y, s, f, c)
    return ob.finish()


def deer(p, x, y, s=1.0, flip=False, col=DEER_C, antlers=True):
    f = -1 if flip else 1
    dk = shade(col, -0.3)
    for lx in (-2.8, 2.6):
        p.line(dk, (x + lx * s, y - 4 * s), (x + lx * s * 1.1, y), 0.9 * s)
    p.oval(col, x, y - 8 * s, 6.2 * s, 3.0 * s)
    p.oval(shade(col, 0.15), x, y - 6.5 * s, 4.5 * s, 1.4 * s)
    p.line(col, (x + f * 4.5 * s, y - 9 * s), (x + f * 8 * s, y - 14.5 * s), 2.6 * s)
    hx, hy = x + f * 9.2 * s, y - 15.2 * s
    p.oval(col, hx, hy, 2.4 * s, 1.9 * s)
    p.circle(WHITE, (x - f * 6 * s, y - 8 * s), 1.0 * s)
    if antlers:
        p.line((100, 76, 46), (hx, hy - 1.5 * s), (hx + f * 1 * s, hy - 7 * s), 0.9 * s)
        p.line((100, 76, 46), (hx + f * 1 * s, hy - 4.5 * s), (hx + f * 4 * s, hy - 6.5 * s), 0.8 * s)
        p.line((100, 76, 46), (hx + f * 1 * s, hy - 7 * s), (hx + f * 3 * s, hy - 9.5 * s), 0.8 * s)


def deer_family(size="m", seed=0):
    ob = Obj(size, 46, 34)
    group = [(-6, -2, 1.0, True, DEER_C, False),       # doe, facing left
             (9, -1, 1.05, False, (150, 100, 62), True),  # stag, facing right
             (-1, 2.5, 0.6, False, (196, 150, 100), False)]  # fawn, in front
    for x, y, s, f, c, a in group:
        ob.shadow(x, y + 0.5, 14 * s, 3.5)
    for x, y, s, f, c, a in sorted(group, key=lambda q: q[1]):
        deer(ob.o, x, y, s, f, c, a)
    for x, y, s, f, c, a in group[2:]:
        for sx, sy in [(-1, -8), (1, -10), (0, -6)]:
            ob.o.circle((236, 226, 200), (x + sx * s, y + sy * s), 0.7)
    return ob.finish()


def wild_boar(size="m", seed=0):
    ob = Obj(size, 36, 22)
    o = ob.o
    ob.shadow(0, 0.5, 20, 3.5)
    body, head = (96, 70, 50), (120, 90, 64)
    for lx in (-5, -2.5, 3, 5.5):
        o.line(shade(body, -0.3), (lx, -3), (lx, 0), 1.3)
    o.oval(body, 0, -7, 8.5, 4.8)
    o.poly(shade(body, -0.3), [(-6, -9), (-4, -12), (-1, -10), (1, -13), (4, -10), (7, -11), (6, -8)])
    o.oval(shade(body, 0.15), -1, -8.5, 4, 2)
    o.oval(head, 9.5, -6, 4, 3.6)
    o.rect((216, 150, 140), 12.4, -7.2, 2.4, 2.6, br=0.8)
    o.line(WHITE, (10.5, -3.5), (12.6, -5.5), 1.0)
    o.poly(shade(body, -0.25), [(8.5, -10), (10.2, -12.6), (11, -9)])
    o.line(body, (-8.5, -8), (-10.5, -10.5), 0.8)
    return ob.finish()


def bird_flock(size="m", seed=0):
    rng = _rng("flock", seed)
    n = {"s": 5, "m": 7, "l": 10}[size]
    ob = Obj(size, 42, 30, minf=0.8)
    o = ob.o
    for i in range(n):
        side = 1 if i % 2 else -1
        k = (i + 1) // 2
        x = side * k * 4.8 + rng.uniform(-0.8, 0.8)
        y = -18 + k * 2.6 + rng.uniform(-1, 1) if i else -18
        s = rng.uniform(0.9, 1.1)
        o.lines((44, 42, 50), [(x - 5.4 * s, y - 4.0 * s), (x, y), (x + 5.4 * s, y - 4.0 * s)], 2.2)
    return ob.finish(ink=2)


def stork(p, x, y, s=1.0, flip=False):
    f = -1 if flip else 1
    p.line((214, 60, 60), (x - 1.2 * s, y - 9 * s), (x - 1.2 * s, y), 0.9 * s)
    p.line((214, 60, 60), (x + 1.2 * s, y - 9 * s), (x + 1.2 * s, y), 0.9 * s)
    p.oval(WHITE, x, y - 12 * s, 4.6 * s, 2.7 * s)
    p.poly((58, 60, 68), [(x + f * 0.5 * s, y - 14.5 * s), (x - f * 5.5 * s, y - 12.5 * s),
                          (x - f * 2.5 * s, y - 9.8 * s)])
    p.line(WHITE, (x + f * 3.5 * s, y - 14 * s), (x + f * 6.5 * s, y - 21 * s), 2.2 * s)
    p.circle(WHITE, (x + f * 7 * s, y - 22.5 * s), 1.8 * s)
    p.poly((214, 70, 60), [(x + f * 8.5 * s, y - 23.5 * s), (x + f * 18 * s, y - 21.2 * s),
                           (x + f * 8.5 * s, y - 21.5 * s)])
    p.circle(DARK, (x + f * 7.6 * s, y - 23 * s), 0.5 * s)


def storks_roof(size="m", seed=0):
    ob = Obj(size, 54, 58)
    o = ob.o
    building(o, -4, -1, 24, 15, 13, (238, 220, 190), ROOF_RED, "front", door=True, wins=2)
    o.oval((120, 88, 56), -4, -29, 6, 2.4)
    for dx in (-4, -1, 2, 5):
        o.line((96, 66, 40), (-4 + dx, -29.5), (-4 + dx * 1.3 + 1, -31.5), 0.6)
    stork(o, -4, -31, 1.0, False)
    round_tree(o, 20, -2, r=6.5, col=(70, 150, 80))
    return ob.finish()


def shepherd(size="m", seed=0):
    ob = Obj(size, 26, 40)
    o = ob.o
    ob.shadow(0, 0.5, 14, 3)
    ob.shadow(10, 0.5, 9, 2.4)
    o.line(DARK, (-1.5, -14), (-2.2, -1), 1.3)
    o.line(DARK, (1.5, -14), (2.2, -1), 1.3)
    o.poly((82, 104, 140), [(-4, -20), (4, -20), (5.5, -6), (-5.5, -6)])
    o.poly(shade((82, 104, 140), -0.28), [(0.5, -20), (4, -20), (5.5, -6), (0.5, -6)])
    o.circle(SKIN_C, (0, -24), 2.4)
    o.poly((96, 70, 44), [(-4.5, -25.5), (4.5, -25.5), (3, -27.8), (-3, -27.8)])
    o.line(DWOOD, (6, -30), (6, -1), 1.3)
    o.lines(DWOOD, [(6, -30), (7.6, -33), (9.2, -31.4)], 1.1)
    o.oval((176, 120, 72), 10, -4, 3.8, 1.9)
    o.circle((186, 130, 80), (13.2, -6.2), 1.9)
    for lx in (-2.5, -0.8, 1.8, 3.5):
        o.line(shade((186, 130, 80), -0.3), (lx + 7.5, -2.5), (lx + 7.5, 0), 0.8)
    o.line((186, 130, 80), (6.5, -6), (4.5, -11), 0.9)
    return ob.finish()


def _peasant(p, x, y, s, coat, hoe=True):
    p.line(DARK, (x - 1.2 * s, y - 6 * s), (x - 2 * s, y), 1.0 * s)
    p.line(DARK, (x + 1.2 * s, y - 6 * s), (x + 2 * s, y), 1.0 * s)
    p.poly(coat, [(x - 2.8 * s, y - 6 * s), (x + 2.8 * s, y - 6 * s), (x + 6 * s, y - 12 * s), (x + 2.6 * s, y - 14 * s)])
    p.poly(shade(coat, -0.3), [(x + 0.5 * s, y - 6 * s), (x + 2.8 * s, y - 6 * s), (x + 6 * s, y - 12 * s),
                               (x + 2.6 * s, y - 14 * s)])
    p.circle(SKIN_C, (x + 6.5 * s, y - 15 * s), 2.1 * s)
    p.oval(THATCH, x + 6.5 * s, y - 16.4 * s, 4 * s, 1.2 * s)
    if hoe:
        p.line(DWOOD, (x + 9 * s, y - 7 * s), (x + 15 * s, y + 0.5), 1.0 * s)
        p.poly(DARK, [(x + 14 * s, y), (x + 17 * s, y + 0.3), (x + 14.5 * s, y + 1.2)])


def peasants_field(size="m", seed=0):
    ob = Obj(size, 60, 30)
    g, o = ob.g, ob.o
    g.poly((196, 160, 90), [(-28, -1), (28, -1), (24, -24), (-24, -24)])
    for i in range(7):
        yy = -3 - i * 3
        xl, xr = -26 + i * 0.6, 26 - i * 0.6
        g.line((160, 126, 70), (xl, yy), (xr, yy), 0.8)
    for i in range(6):
        yy = -6 - i * 3.2
        g.line((120, 170, 80), (-22 + i, yy), (22 - i, yy), 1.6)
    for x, coat in [(-17, (70, 90, 150)), (0, (170, 70, 60)), (16, (120, 100, 80))]:
        _peasant(o, x, 0, 1.0, coat)
    return ob.finish()


def _camel(p, x, y, s=1.0, flip=False, col=(196, 160, 110), rider=False, load=False):
    f = -1 if flip else 1
    dk = shade(col, -0.25)
    for lx in (-6, -3, 3.5, 6):
        p.line(dk, (x + lx * s, y - 6 * s), (x + lx * s, y), 1.2 * s)
    p.oval(col, x, y - 9 * s, 9 * s, 4.5 * s)
    p.oval(shade(col, -0.25), x + f * 0.5 * s, y - 6.5 * s, 7 * s, 1.6 * s)
    p.circle(shade(col, 0.05), (x - f * 2.4 * s, y - 14.5 * s), 3.4 * s)
    p.circle(shade(col, 0.05), (x + f * 3.2 * s, y - 13.8 * s), 3 * s)
    p.line(col, (x + f * 6 * s, y - 9 * s), (x + f * 10 * s, y - 19 * s), 3.6 * s)
    p.oval(col, x + f * 12 * s, y - 20 * s, 3.2 * s, 2.2 * s)
    p.line(dk, (x - f * 9 * s, y - 10 * s), (x - f * 12 * s, y - 6 * s), 0.8 * s)
    if load:
        p.rect((150, 100, 60), x - 4.5 * s, y - 20.5 * s, 5 * s, 4 * s)
        p.rect((120, 80, 46), x + 1 * s, y - 21 * s, 5 * s, 4.5 * s)
    if rider:
        p.circle(SKIN_C, (x + f * 0 * s, y - 22.5 * s), 2 * s)
        p.poly((96, 80, 60), [(x - 2 * s, y - 20.5 * s), (x + 2 * s, y - 20.5 * s), (x + 1.5 * s, y - 15 * s),
                              (x - 1.5 * s, y - 15 * s)])
        p.line(DARK, (x - 1.5 * s, y - 15 * s), (x - 2.5 * s, y - 11 * s), 1.0 * s)


def camel_caravan(size="m", seed=0):
    ob = Obj(size, 74, 42)
    group = [(-24, -2, False, (196, 160, 110), False, True),
             (-2, -7, False, (184, 146, 96), True, False),
             (20, -2, True, (206, 170, 118), False, True)]
    for x, y, f, c, r, l in group:
        ob.shadow(x, y + 0.5, 22, 3.5)
    for x, y, f, c, r, l in sorted(group, key=lambda q: q[1]):
        _camel(ob.o, x, y, 1.0, f, c, r, l)
    return ob.finish()


def _wigwam(p, x, y, w, h, col=(176, 132, 88)):
    body = [(x - w / 2, y), (x - w * 0.36, y - h * 0.7), (x - w * 0.1, y - h), (x + w * 0.12, y - h * 0.98),
            (x + w * 0.36, y - h * 0.66), (x + w / 2, y)]
    p.poly(col, body)
    p.poly(shade(col, -0.28), [(x + w * 0.02, y - h * 0.98), (x + w * 0.12, y - h * 0.98), (x + w * 0.36, y - h * 0.66),
                               (x + w / 2, y), (x + w * 0.06, y)])
    p.line((96, 66, 40), (x - w * 0.12, y - h * 0.98), (x - w * 0.4, y - h * 0.68), 0.6)
    p.line((96, 66, 40), (x + w * 0.1, y - h * 0.98), (x + w * 0.38, y - h * 0.66), 0.6)
    p.poly(DARK, [(x - 1.6, y), (x - 1.6, y - 5), (x, y - 6.2), (x + 1.6, y - 5), (x + 1.6, y)])
    p.circle(DWOOD, (x, y - h - 1), 0.8)


def _longhouse(p, x, y, w, h):
    p.rect((168, 128, 86), x - w / 2, y - h, w, h)
    p.rect(shade((168, 128, 86), -0.25), x + w * 0.2, y - h, w * 0.3, h)
    roof = ell(x, y - h, w / 2 + 1, h * 0.7, 180, 360, 16)
    p.poly((186, 150, 96), roof)
    p.poly(shade((186, 150, 96), -0.2), [(x + w * 0.1, y - h - h * 0.6), (x + w / 2 + 1, y - h), (x + w * 0.1, y - h)])
    for dx in (-w * 0.3, 0, w * 0.3):
        p.line((120, 84, 50), (x + dx, y - h - h * 0.6 + 1), (x + dx, y - h), 0.6)
    p.rect(DARK, x - 2, y - 6, 4, 6, br=1)


def native_village(size="m", seed=0):
    ob = Obj(size, 66, 40)
    g, o = ob.g, ob.o
    ob.shadow(0, 0.5, 56, 6, a=40)
    for x, y in [(-2, 2)]:
        g.oval((150, 110, 70), x, y - 1, 26, 4)
    _longhouse(o, 12, -14, 30, 10)
    _wigwam(o, -18, -3, 13, 14)
    _wigwam(o, -4, -2, 11, 12)
    _wigwam(o, 22, -2, 12, 13)
    for ang in range(5):
        a = math.radians(-160 + ang * 40)
        g.circle(ROCK, (4 + 4 * math.cos(a), -6 + 2.2 * math.sin(a)), 1.4)
    g.circle((240, 120, 50), (4, -6), 1.6)
    g.poly((255, 200, 80), [(3, -6), (5, -6), (4, -9)])
    return ob.finish()


def _awning(p, x, y, w, h, c1, c2, n=6):
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        bx0, bx1 = x - w / 2 + w * t0, x - w / 2 + w * t1
        tx0, tx1 = x - w * 0.36 + w * 0.72 * t0, x - w * 0.36 + w * 0.72 * t1
        p.poly(c1 if i % 2 == 0 else c2, [(bx0, y), (bx1, y), (tx1, y - h), (tx0, y - h)])
    p.line(DWOOD, (x, y - h), (x, y - h - 6), 1.0)


def market_fair(size="m", seed=0):
    ob = Obj(size, 58, 44)
    o = ob.o
    ob.shadow(0, 0.5, 52, 6, a=40)
    _awning(o, -14, -14, 24, 14, (206, 62, 52), (246, 240, 224))
    _awning(o, 14, -16, 22, 16, (60, 100, 170), (246, 240, 224), n=5)
    o.rect(WOOD, -18, -10, 36, 2.5)
    o.rect(DWOOD, -18, -7.5, 2, 7.5)
    o.rect(DWOOD, 16, -7.5, 2, 7.5)
    for x, col in [(-12, (232, 180, 60)), (-6, (120, 170, 80)), (2, (200, 80, 90))]:
        o.rect(col, x - 2.5, -14, 5, 4, br=1)
    barrel(o, -26 + 2, -2.5, 1.0)
    flag(o, -22, -36, 9, (222, 80, 60))
    flag(o, 22, -40, 10, (220, 190, 70))
    return ob.finish()


def barrel(p, x, y, s=1.0):
    p.rect((160, 105, 60), x - 3 * s, y - 7 * s, 6 * s, 7 * s, br=1)
    p.rect((120, 78, 45), x, y - 7 * s, 3 * s, 7 * s)
    p.line((80, 70, 70), (x - 3 * s, y - 2 * s), (x + 3 * s, y - 2 * s), 0.8)
    p.line((80, 70, 70), (x - 3 * s, y - 5 * s), (x + 3 * s, y - 5 * s), 0.8)


def windmill_post(size="m", seed=0):
    ob = Obj(size, 46, 60)
    o = ob.o
    ob.shadow(0, 0.5, 26, 4, a=40)
    o.poly(DWOOD, [(-1.6, 0), (-2.4, -6), (2.4, -6), (1.6, 0)])
    o.line(DWOOD, (0, -7), (17, 0), 1.4)
    o.line(DWOOD, (11, 0), (6, -15), 1.0)
    o.line(DWOOD, (13, 0), (8, -15), 1.0)
    for i in range(1, 6):
        t = i / 6
        o.line(DWOOD, (lerp((11, 0), (6, -15), t)[0] - 1.4, lerp((11, 0), (6, -15), t)[1]),
               (lerp((13, 0), (8, -15), t)[0] - 1.4, lerp((13, 0), (8, -15), t)[1]), 0.7)
    o.rect((168, 120, 80), -8, -24, 16, 17)
    o.rect(shade((168, 120, 80), -0.25), 3, -24, 5, 17)
    for xx in (-5, -1, 3):
        o.line((126, 88, 52), (xx, -24), (xx, -7), 0.6)
    o.rect(DARK, -2, -14, 4, 6)
    roof = [(-11, -23), (-1, -35), (11, -23)]
    o.poly((124, 96, 76), roof)
    o.poly(shade((124, 96, 76), -0.25), [(0, -35), (11, -23), (2, -23)])
    hub = (-9, -28)
    for k in range(4):
        a = math.radians(-35 + k * 90)
        ux, uy = math.cos(a), math.sin(a)
        nx, ny = -uy, ux
        L, sw = 22, 5.5
        p0 = (hub[0] + ux * 3, hub[1] + uy * 3)
        p1 = (hub[0] + ux * L, hub[1] + uy * L)
        quad = [p0, p1, (p1[0] + nx * sw, p1[1] + ny * sw), (p0[0] + nx * sw, p0[1] + ny * sw)]
        o.poly((236, 228, 210), quad)
        o.line(DWOOD, p0, p1, 1.2)
        o.line((150, 110, 70), quad[0], quad[3], 0.7)
    o.circle(DWOOD, hub, 2.2)
    return ob.finish()


# ===================================================================================================
# 3. RUINS, LANDMARKS AND HOLY PLACES
# ===================================================================================================
def _column(p, x, y, h, w=5.0, broken=False):
    shaft_h = h * (0.62 if broken else 1.0)
    p.rect(STONE_C, x - w / 2, y - shaft_h, w, shaft_h - 3.5)
    p.rect(shade(STONE_C, -0.25), x + w * 0.15, y - shaft_h, w * 0.35, shaft_h - 3.5)
    for k in range(1, 4):
        p.line(STONE_D, (x - w * 0.22 + k * w * 0.0, y - shaft_h + 2), (x - w * 0.22, y - 5), 0.5)
    if broken:
        top = y - shaft_h
        p.poly(STONE_C, [(x - w / 2, top), (x - w * 0.2, top - 2.4), (x + w * 0.1, top + 0.6), (x + w / 2, top - 1.6),
                         (x + w / 2, top)])
    else:
        p.rect(STONE_C, x - w / 2 - 1.4, y - h - 1.4, w + 2.8, 2.6)
        p.rect(STONE_C, x - w / 2 - 0.6, y - h + 1.2, w + 1.2, 1.4)
    p.rect(STONE_D, x - w / 2 - 1.2, y - 3.6, w + 2.4, 3.6)


def roman_ruins(size="m", seed=0):
    rng = _rng("roman", seed)
    ob = Obj(size, 66, 44)
    g, o = ob.g, ob.o
    ob.shadow(0, 0.5, 58, 6, a=40)
    for _ in range(9):
        x, y = rng.uniform(-28, 26), rng.uniform(-3, 0)
        g.poly(STONE_D, [(x, y), (x + 2.5, y - 1.8), (x + 4.5, y), (x + 2, y + 0.8)])
    _column(o, -24, -1, 34)
    _column(o, -13, -1, 30)
    _column(o, 6, -1, 21, broken=True)
    _column(o, 22, -1, 30)
    _column(o, 33, -1, 30)
    arch = ell(27.5, -29, 5.5, 6, 180, 360, 14)
    o.lines(STONE_C, arch, 3.2)
    o.lines(STONE_D, arch, 1.0)
    o.rect(STONE_C, 26, -36, 3, 3.0)
    o.rect(shade(STONE_C, -0.3), -26, -4.5, 25, 0.8)
    return ob.finish()


def aqueduct(size="m", seed=0):
    ob = Obj(size, 74, 42)
    g, o = ob.g, ob.o
    ob.shadow(0, 0.5, 66, 5, a=40)
    piers = [-30, -20, -10, 0, 10, 20, 30]
    for px in piers:
        o.rect(STONE_C, px - 2.6, -26, 5.2, 26)
        o.rect(shade(STONE_C, -0.25), px + 0.8, -26, 1.8, 26)
    for a, b in zip(piers, piers[1:]):
        cx = (a + b) / 2
        o.poly((56, 70, 62), ell(cx, -26, 4.6, 5.2, 180, 360, 12))
        o.lines(STONE_C, ell(cx, -26, 4.6, 5.2, 180, 360, 12), 1.2)
    o.rect(STONE_C, -34, -36, 68, 10)
    o.rect(shade(STONE_C, -0.2), -34, -30, 68, 4)
    o.rect((96, 150, 190), -31, -35, 62, 3.2)
    g.line(WHITE, (-29, -33.5), (-6, -33.6), 0.8)
    g.line(WHITE, (6, -33.5), (29, -33.5), 0.8)
    for px in piers:
        o.rect(STONE_D, px - 3.2, -2, 6.4, 2)
    return ob.finish()


def standing_stones(size="m", seed=0):
    rng = _rng("stones", seed)
    ob = Obj(size, 54, 34)
    g, o = ob.g, ob.o
    ring = []
    for k in range(7):
        a = math.radians(k * 360 / 7 + rng.uniform(-8, 8))
        ring.append((19 * math.cos(a), -5 + 8.5 * math.sin(a), rng.uniform(9, 14), rng.uniform(4, 5.5)))
    for x, y, h, w in ring:
        ob.shadow(x, y + 0.5, w * 1.6, 2.4, a=50)
    g.oval(SAND, 0, -4, 7, 2.6)
    g.oval(shade(SAND, -0.2), 0, -3.2, 6, 1.4)
    for x, y, h, w in sorted(ring, key=lambda q: q[1]):
        o.poly(STONE_C, [(x - w / 2, y), (x - w / 2 + 0.6, y - h * 0.75), (x - w * 0.2, y - h), (x + w * 0.3, y - h * 0.92),
                         (x + w / 2, y - h * 0.6), (x + w / 2, y)])
        o.poly(shade(STONE_C, -0.3), [(x + w * 0.05, y - h * 0.94), (x + w * 0.3, y - h * 0.92), (x + w / 2, y - h * 0.6),
                                      (x + w / 2, y), (x + w * 0.1, y)])
    for _ in range(6):
        x, y = rng.uniform(-24, 24), rng.uniform(-3, 2)
        g.lines(GRASS_D, [(x - 1, y), (x, y - 2), (x + 1, y)], 1.0)
    return ob.finish()


def wayside_cross(size="m", seed=0):
    ob = Obj(size, 22, 42, minf=0.8)
    o = ob.o
    ob.shadow(0, 0.5, 14, 3)
    o.rect(STONE_D, -7, -4, 14, 4)
    o.rect(shade(STONE_D, -0.1), -5, -7, 10, 3)
    o.rect(STONE_C, -4, -15, 8, 8)
    o.rect(shade(STONE_C, -0.25), 1.5, -15, 2.5, 8)
    o.rect((176, 170, 160), -1.5, -36, 3, 21)
    o.rect((176, 170, 160), -6, -31, 12, 3)
    o.rect(shade((176, 170, 160), -0.25), 0.8, -36, 0.7, 21)
    o.poly(ROOF_SLATE, [(-7, -36.5), (7, -36.5), (0, -43)])
    o.circle((250, 200, 90), (0, -33), 0.8)
    return ob.finish()


def pilgrimage_chapel(size="m", seed=0):
    ob = Obj(size, 44, 52)
    g, o = ob.g, ob.o
    ob.shadow(0, 0.5, 34, 4, a=40)
    g.poly((206, 186, 140), [(-3, 0), (3, 0), (4, -14), (-4, -14)])
    building(o, -4, -2, 22, 15, 12, (222, 214, 196), ROOF_SLATE, "front", door=True, wins=0)
    o.circle((110, 130, 170), (-4, -15), 2.2)
    tower(o, 13, -2, 3.8, 30, (222, 214, 196), roof=ROOF_SLATE, cone=9)
    o.line(DARK, (13, -41), (13, -47), 1.0)
    o.line(DARK, (10.5, -44), (15.5, -44), 1.0)
    o.rect(DARK, 12.2, -17, 2.4, 4)
    return ob.finish()


def monastery(size="m", seed=0):
    ob = Obj(size, 72, 62)
    o = ob.o
    ob.shadow(0, 0.5, 66, 6, a=40)
    stone = (216, 210, 196)
    wall = [(-32, -3), (32, -3), (32, -20), (-32, -20), (-32, -3)]
    o.lines(shade(stone, -0.2), wall, 3.0)
    o.lines(stone, wall, 2.2)
    tower(o, -32, -3, 3.8, 28, stone, roof=ROOF_SLATE, cone=8)
    building(o, -6, -6, 24, 18, 14, stone, ROOF_SLATE, "front", door=True, wins=3)
    tower(o, 15, -4, 4.4, 40, stone, roof=ROOF_SLATE, cone=14)
    for i in range(6):
        o.rect((210, 190, 160), -28 + i * 4.6, -11, 2.4, 5)
    o.rect(shade(stone, -0.2), -29, -6, 27, 2)
    building(o, 27, -8, 10, 10, 8, (232, 220, 196), (176, 96, 66), "flat", door=True)
    return ob.finish()


def ruined_castle(size="m", seed=0):
    ob = Obj(size, 74, 60)
    o = ob.o
    ob.shadow(0, 0.5, 66, 6, a=40)
    stone = (196, 190, 178)
    wall = [(-30, -4), (-30, -22), (-26, -22), (-26, -17), (-20, -17), (-20, -23), (-14, -23), (-14, -19), (-8, -19),
            (-8, -22), (0, -22), (0, -16), (4, -16), (4, -18), (30, -18), (30, -4)]
    o.poly(stone, wall)
    o.poly(shade(stone, -0.25), [(4, -4), (30, -4), (30, -18), (4, -16)])
    for yy in (-12, -7):
        o.line(shade(stone, -0.25), (-28, yy), (-10, yy + 1), 0.7)
    o.poly(stone, [(-38, -2), (-38, -34), (-35, -34), (-32, -30), (-29, -36), (-24, -33), (-22, -2)])
    o.poly(shade(stone, -0.25), [(-28, -2), (-22, -2), (-24, -33), (-29, -36)])
    o.rect(DARK, -34, -22, 2.4, 6)
    o.poly(stone, [(22, -2), (22, -30), (25, -31), (28, -26), (31, -33), (35, -28), (38, -2)])
    o.poly(shade(stone, -0.25), [(29, -2), (38, -2), (35, -28), (31, -33), (30, -20)])
    o.rect(DARK, 28, -18, 2.4, 6)
    o.rect(STONE_D, -20, -4, 8, 4)
    o.rect(STONE_D, 8, -4, 7, 3)
    o.rect(STONE_D, -10, -3, 5, 3)
    round_tree(o, 4, -4, r=7, col=(64, 140, 70))
    return ob.finish()


def battlefield(size="m", seed=0):
    rng = _rng("battle", seed)
    ob = Obj(size, 64, 40)
    g, o = ob.g, ob.o
    g.oval((140, 114, 80), 0, -6, 30, 8)
    for _ in range(8):
        x, y = rng.uniform(-24, 24), rng.uniform(-10, -2)
        g.oval((110, 88, 60), x, y, rng.uniform(2, 4), 1.4)
    wheel(o, -17, -5, 5.5, WOOD, spokes=6, paddles=False)
    o.poly((120, 84, 56), [(-23, -11), (-9, -12), (-11, -17), (-22, -16)])
    o.line(DWOOD, (-9, -10), (-3, -4), 1.6)
    o.line(DWOOD, (-22, -12), (-24, -18), 0.8)
    o.line(DWOOD, (-3, -2), (-5, -30), 0.9)
    o.poly((150, 150, 160), [(-5.8, -30), (-4.2, -30), (-5, -33)])
    o.line(DWOOD, (3, -2), (2, -26), 0.9)
    flag(o, 2, -26, 14, (190, 50, 50))
    o.line(DWOOD, (19, -2), (20, -24), 0.9)
    flag(o, 20, -24, 13, (56, 84, 166))
    o.poly((150, 150, 160), [(22, -4), (27, -4), (27, -7), (25, -9), (22, -7)])
    o.poly((150, 150, 160), [(-30, -3), (-26, -3), (-26, -6), (-28, -8), (-30, -6)])
    o.rect(DWOOD, 29, -9, 2, 9)
    for x, y in [(-11, -3), (25, -2)]:
        g.line(DARK, (x - 1, y), (x + 1, y - 2), 0.8)
    return ob.finish()


def burial_mound(size="m", seed=0):
    ob = Obj(size, 50, 34)
    g, o = ob.g, ob.o
    g.oval(shade(GRASS, -0.4), 0, -3, 24, 5)
    dome_pts = ell(0, -5, 22, 16, 180, 360, 22)
    o.poly((96, 150, 88), dome_pts)
    o.poly((78, 128, 72), [(0, -21), (22, -5), (0, -5)])
    for x in (-14, -8, 12, 16):
        o.line((70, 120, 64), (x, -9), (x + 1, -14), 0.9)
    o.rect(STONE_C, -9, -10, 3, 9)
    o.rect(STONE_C, 6, -10, 3, 9)
    o.poly(STONE_D, [(-10, -11), (-5, -15), (5, -15), (10, -11)])
    o.rect(DARK, -3.6, -8, 7.2, 8, br=0.8)
    for x in (-19, 19):
        o.rect(STONE_D, x - 1.4, -6, 2.8, 6)
    return ob.finish()


def gallows_hill(size="m", seed=0):
    ob = Obj(size, 52, 56)
    g, o = ob.g, ob.o
    ob.shadow(0, 0.5, 48, 6, a=40)
    hill = ell(0, -6, 26, 14, 180, 360, 22)
    g.poly((150, 126, 86), hill)
    g.poly((120, 98, 64), [(0, -20), (26, -6), (0, -6)])
    o.line(DWOOD, (-9, -16), (-9, -44), 2.2)
    o.line(DWOOD, (9, -16), (9, -44), 2.2)
    o.line(DWOOD, (-11, -44), (11, -44), 2.6)
    o.line(DWOOD, (-6, -44), (-9, -40), 1.0)
    o.line(DWOOD, (6, -44), (9, -40), 1.0)
    o.line(DARK, (0, -43), (0, -33), 0.7)
    o.oval(WHITE, 0, -31, 2.4, 2.4)
    o.oval((112, 80, 60), 0, -31, 1.6, 1.6)
    for x, y in [(-6, -45.5), (5, -46)]:
        o.oval(DARK, x, y, 2.2, 1.2)
    return ob.finish()


def watchtower(size="m", seed=0):
    ob = Obj(size, 34, 60)
    o = ob.o
    ob.shadow(0, 0.5, 22, 4, a=40)
    o.poly(ROCK, [(-10, 0), (10, 0), (8, -4), (-8, -4)])
    o.rect(STONE_C, -8, -44, 16, 41)
    o.rect(shade(STONE_C, -0.25), 3, -44, 5, 41)
    for yy in range(-40, -2, 6):
        o.line(STONE_D, (-8, yy), (8, yy), 0.6)
    o.rect(STONE_C, -9.5, -45.5, 19, 2.2)
    for x in (-8, -4.6, -1.2, 2.2, 5.6):
        o.rect(STONE_C, x, -51, 3, 5.6)
    o.rect(DARK, -2, -12, 4, 8, br=2)
    o.rect(DARK, -1, -30, 2, 6)
    o.rect(DARK, -1, -40, 2, 4)
    o.line(DWOOD, (0, -51), (0, -64), 0.9)
    flag(o, 0, -64, 9, (200, 60, 60))
    return ob.finish()


# ===================================================================================================
# 4. TREES (used by the whole tiles)
# ===================================================================================================
def tree(size="m", seed=0, kind="pine"):
    rng = _rng("tree", kind, seed)
    ob = Obj(size, 18, 30)
    if kind == "pine":
        col = (40, 120, 70) if rng.random() < 0.5 else (32, 104, 60)
        pine(ob.o, 0, 0, h=24, col=col)
    else:
        round_tree(ob.o, 0, 0, r=6.5, col=(72, 150, 72), th=5)
    return ob.finish()


# ===================================================================================================
# registry
# ===================================================================================================
OBJECTS = {
    "waterfall": waterfall, "rapids": rapids, "sea_rocks": sea_rocks, "sea_stack": sea_stack,
    "reef_surf": reef_surf, "coral_patch": coral_patch, "sandbar": sandbar, "lily_pond": lily_pond, "reeds": reeds, "cattails": cattails,
    "sea_cliff": sea_cliff, "lighthouse": lighthouse, "fishing_boat": fishing_boat, "whale_spout": whale_spout,
    "seabirds": seabirds, "iceberg": iceberg, "shipwreck": shipwreck,
    "cattle_herd": cattle_herd, "sheep_flock": sheep_flock, "horse_herd": horse_herd, "goat_herd": goat_herd,
    "deer_family": deer_family, "wild_boar": wild_boar, "bird_flock": bird_flock, "storks_roof": storks_roof,
    "shepherd": shepherd, "peasants_field": peasants_field, "camel_caravan": camel_caravan,
    "native_village": native_village, "market_fair": market_fair, "windmill_post": windmill_post,
    "roman_ruins": roman_ruins, "aqueduct": aqueduct, "standing_stones": standing_stones,
    "wayside_cross": wayside_cross, "pilgrimage_chapel": pilgrimage_chapel, "monastery": monastery,
    "ruined_castle": ruined_castle, "battlefield": battlefield, "burial_mound": burial_mound,
    "gallows_hill": gallows_hill, "watchtower": watchtower,
}
WATER_OBJECTS = ("waterfall", "rapids", "sea_rocks", "sea_stack", "reef_surf", "sandbar", "reeds", "cattails",
                 "sea_cliff", "lighthouse", "fishing_boat", "whale_spout", "seabirds", "iceberg", "shipwreck")


_OBJ_CACHE = {}


def _obj(name, size, seed):
    """Cached object render: scatter draws from 4 variants per object and size, so rejected candidates are free."""
    key = (name, size, seed)
    if key not in _OBJ_CACHE:
        _OBJ_CACHE[key] = OBJECTS[name](size, seed)
    return _OBJ_CACHE[key]


# ===================================================================================================
# scatter: natural clusters on a tile, back to front
# ===================================================================================================
KINDS = {
    "coast_life": (7, [("reeds", 3), ("cattails", 2), ("seabirds", 2), ("sea_rocks", 2), ("fishing_boat", 1),
                       ("sandbar", 2), ("lily_pond", 1)]),
    "open_sea": (6, [("whale_spout", 2), ("seabirds", 2), ("fishing_boat", 1), ("sea_rocks", 1),
                     ("sea_stack", 1)]),
    "arctic_sea": (6, [("iceberg", 4), ("seabirds", 2), ("sea_rocks", 1)]),
    "pasture_life": (9, [("sheep_flock", 3), ("cattle_herd", 3), ("horse_herd", 2), ("goat_herd", 2),
                         ("shepherd", 1)]),
    "wild_woods_life": (7, [("deer_family", 3), ("wild_boar", 2), ("bird_flock", 2)]),
    "desert_life": (5, [("camel_caravan", 2), ("goat_herd", 1), ("bird_flock", 2)]),
    "ruins": (5, [("roman_ruins", 2), ("aqueduct", 1), ("standing_stones", 1), ("ruined_castle", 1),
                  ("burial_mound", 1), ("watchtower", 1)]),
    "holy_place": (5, [("wayside_cross", 3), ("pilgrimage_chapel", 1), ("standing_stones", 1),
                       ("monastery", 1), ("burial_mound", 1)]),
}


def _in_hex(x, y, r):
    dx, dy = abs(x - CX), abs(y - CY)
    return dx <= r * 0.866 and dy + dx / 1.732 <= r


def _overlap(a, b, m=2):
    return not (a[2] + m < b[0] or b[2] + m < a[0] or a[3] + m < b[1] or b[3] + m < a[1])


def scatter(tile, kind, density=1.0, seed=0):
    """Blit a varied cluster of `kind` onto `tile` (a 120 x 140 Surface), in place, back to front. Returns tile."""
    n_base, pool = KINDS[kind]
    rng = _rng("scatter", kind, seed)
    count = max(1, round(n_base * density))
    names = [n for n, _ in pool]
    weights = [w for _, w in pool]
    placed, fps = [], []
    tries = 0
    while len(placed) < count and tries < 500:
        tries += 1
        if placed and rng.random() < 0.45:
            ax, ay = rng.choice(placed)[:2]
            x, y = ax + rng.uniform(-15, 15), ay + rng.uniform(-6, 6)
        else:
            x, y = rng.uniform(18, 102), rng.uniform(24, 128)
        if not _in_hex(x, y, R - 8):
            continue
        name = rng.choices(names, weights)[0]
        size = rng.choices(["s", "m", "l"], [3, 4, 2])[0]
        cap = SIZE_MAX.get(name, "l")
        if SIZES[size] > SIZES[cap]:
            size = cap
        surf = _obj(name, size, rng.randrange(4))
        w, h = surf.get_size()
        fp = (x - w / 2, y - h + 1, x + w / 2, y)
        corners = [(fp[0], fp[1]), (fp[2], fp[1]), (fp[0], fp[3]), (fp[2], fp[3])]
        if not all(_in_hex(px, py, R - 4) for px, py in corners):
            continue
        if any(_overlap(fp, q) for q in fps):
            continue
        fps.append(fp)
        placed.append((x, y, surf))
    for x, y, surf in sorted(placed, key=lambda q: q[1]):
        tile.blit(surf, (round(x - surf.get_width() / 2), round(y - surf.get_height() + 1)))
    return tile
