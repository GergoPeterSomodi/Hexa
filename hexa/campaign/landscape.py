"""Landscape art for the campaign map: baked ground composites, object lists and the mountain ridge crests.

Ported from the approved map look in the tile-design mockup (mockups/tile-designs/final/final.py), decoupled from its
fixed Italy box and its Map class, so it works for any CampaignWorld (the Europe map or a random world).

Layers, per land hex (drawn back to front by the caller):
  ground(pos, r, season, build=True)
                           one hex-sized RGBA composite: base picture (Kenney terrain, goods tile, sea), ground
                           detail, wavy edge bands between ground kinds, forest clearings and natural field systems,
                           the ridge crests (relief fold, band, pass corridor or winter drift), the wfctiles overlay
                           (coasts, rivers, roads, towns, castles). Cached in an LRU. build=False returns None instead
                           of building a missing one.
  grid(r)                  the faint hex outline at hex radius r, the size of ground(); drawn separately (G key).
  objects(pos, r, season)  [(surface, dx, dy, sort_y)] peaks, hills, trees, farm buildings, crest objects and pass
                           pieces (hospice, winter snowmark) of one hex. dx, dy are pixel offsets of the surface's base
                           point (bottom centre) from the hex centre. Back-to-front order: sort by centre_y + sort_y,
                           where sort_y == dy. Objects may extend outside their hex.
  ridges()                 the crest edges, looks and passes (Ridges); a pass is shown by its saddle (a pasture strip
                           and track in summer, a snow drift and a snowflake mark in winter), not by a chip.

Composites are built at 2x and smooth-scaled down. Season is "winter" when world.turn % 4 == 0 (see season_now).
"""
import math
import os
import random
import zlib
from dataclasses import dataclass

import pygame

from ..hexgrid import neighbors
from . import art, geo, goodsart, landmarks, life, nature, wfctiles
from .art import shade
from .render import draw
from .render.cache import BoundedCache
from .render.draw import in_poly

SQ3 = math.sqrt(3)
APO = SQ3 / 2                       # centre to edge midpoint, in hex radii
SPRITE_H = 70 / (60 / SQ3)          # the game's sprite height in hex radii (mapview.SPRITE_H)
OBJ_R = 69.3                        # the hex radius the object libraries are drawn for
K = 2                               # supersampling of composites
INK = (36, 38, 44)
EPS = 1e-12                        # in_poly's guard against a zero division
GROUND_CACHE = 3000
OBJECT_CACHE = 6000

# ground kind: (sprite names, multiply tint or None, priority). A higher-priority kind spills a band into a lower one.
GROUND = {
    "snow":    (["art:snow:0", "art:snow:1"], None, 90),
    "alpine":  (["Terrain/Stone/stone_07.png"], (246, 240, 230), 80),
    "montane": (["Terrain/Grass/grass_05.png", "Terrain/Grass/grass_19.png"], (196, 206, 158), 70),
    "sand":    (["Terrain/Sand/sand_07.png", "Terrain/Sand/sand_19.png"], None, 65),
    "marsh":   (["art:marsh:0", "art:marsh:1"], None, 60),
    "forest":  (["Terrain/Grass/grass_05.png", "Terrain/Grass/grass_19.png"], (168, 196, 160), 50),
    "hills":   (["Terrain/Grass/grass_19.png", "Terrain/Grass/grass_05.png"], (238, 246, 196), 40),
    "plains":  (["Terrain/Grass/grass_05.png", "Terrain/Grass/grass_19.png"], None, 30),
    "dirt":    (["Terrain/Dirt/dirt_06.png", "Terrain/Dirt/dirt_19.png"], None, 20),
    "good":    ([], None, 10),
    "water":   ([], None, 0),
}
TERRAIN_GROUND = {"plains": "plains", "forest": "forest", "hills": "hills", "mountains": "montane", "snow": "snow",
                  "steppe": "dirt", "desert": "sand", "beach": "sand", "marsh": "marsh", "tundra": "alpine",
                  "taiga": "forest", "savanna": "dirt", "jungle": "forest"}
# object scale on top of the library size, so trees, peaks and herds read at one consistent scale
OSCALE = {"peak": 1.42, "hill": 1.05, "tree": 0.62, "clutter": 0.8, "life": 0.62, "build": 0.62}
BASE_GROW = 1.08                   # the base picture is drawn this much larger than its hex (see _build_ground)
ALPINE_ALT = 0.66                   # mountain hexes above this are bare rock
TREE_LINE = 0.66                    # no trees above this altitude
PINE_LINE = 0.42                    # conifers above this, broadleaves below
SEASONS = ("summer", "winter")

BROAD = [("oak", 3), ("beech", 2.2), ("linden", 1.2), ("birch", 1.6), ("oak_autumn", 0.5)]
CONIF = [("fir_tall", 3), ("pine_tall", 2), ("fir_short", 1.6), ("pine_short", 1)]
CROPS = [((232, 192, 74), "rows"), ((218, 166, 60), "rows"), ((152, 186, 72), "rows"), ((168, 120, 74), "furrow"),
         ((240, 214, 128), "stubble"), ((132, 176, 84), "meadow"), ((226, 184, 70), "rows")]
NATURE_NAMES = set(nature.OBJECT_NAMES)
LIFE_SIZES = {"small": "s", "medium": "m", "large": "l"}


# ----------------------------------------------------------------------------------------------- geometry
def _h(*key):
    return zlib.crc32("|".join(map(str, key)).encode()) & 0xFFFFFFFF


def _u(*key):
    return _h(*key) / 4294967295.0


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hex_centre(pos):
    col, row = pos
    return (col + 0.5 * (row & 1) + 0.5) * SQ3, row * 1.5 + 1


def corner_pt(c, X=0.0, Y=0.0, rad=1.0):
    """Corner c sits between edges c and c+1 (wfctiles.corner), angle -60c-30 degrees."""
    a = math.radians(-60 * c - 30)
    return X + rad * math.cos(a), Y + rad * math.sin(a)


def edge_normal(e):
    a = math.radians(-60 * e)
    return math.cos(a), math.sin(a)


def edge_ends(e):
    """The two corners of edge e (neighbors() order): corner e-1 then corner e."""
    return corner_pt((e - 1) % 6), corner_pt(e)


def hex_poly(X, Y, rad):
    return [corner_pt(c, X, Y, rad) for c in range(6)]


_COAST_WATER = BoundedCache("landscape.coast_water", 600)


def coast_water(desc):
    """The water of a land hex's coast overlay as a mask at 2x tile resolution (cached): what in_water tests."""
    key = (desc.sea, desc.variant, bool(desc.town))
    mask = _COAST_WATER.get(key)
    if mask is None:
        geo = wfctiles._coast_geo(desc.sea, desc.variant, wfctiles.COAST_RD - 8 if desc.town else wfctiles.COAST_RD)
        mask = _COAST_WATER.put(key, pygame.mask.from_surface(geo["water"], 8))
    return mask


def in_water(mask, tx, ty, margin=4):
    """Is the tile point (tx, ty) (120 x 140 tile pixels) in the mask's water, or within `margin` px of it (the sand)?"""
    w, h = mask.get_size()
    for dx, dy in ((0, 0), (-margin, 0), (margin, 0), (0, -margin * 0.6), (0, margin * 0.6)):
        px, py = int((tx + dx) * wfctiles.K), int((ty + dy) * wfctiles.K)
        if 0 <= px < w and 0 <= py < h and mask.get_at((px, py)):
            return True
    return False


def clip_mask(size):
    """A surface to draw a clip polygon on, for a BLEND_RGBA_MIN blit: white and transparent outside the polygon.
    (Transparent *black* would zero the colour of the pixels it clips, and the antialiased edge pixels of the
    result would be darkened: a dark hairline round every clipped picture.)"""
    s = pygame.Surface(size, pygame.SRCALPHA)
    s.fill((255, 255, 255, 0))
    return s


def _hex_at(X, Y):
    """The hex (col, row) whose centre is nearest to the unit point (X, Y)."""
    row0 = int(round((Y - 1) / 1.5))
    best, bd = None, 1e9
    for rw in (row0 - 1, row0, row0 + 1):
        c0 = int(math.floor(X / SQ3 - 0.5 - 0.5 * (rw & 1)))
        for c in (c0 - 1, c0, c0 + 1, c0 + 2):
            cx, cy = hex_centre((c, rw))
            d = (X - cx) ** 2 + (Y - cy) ** 2
            if d < bd:
                best, bd = (c, rw), d
    return best


def _near_positions(pos, k):
    """All positions within k steps of pos (odd-r offset coordinates, cube-distance test)."""
    col, row = pos
    x0 = col - (row - (row & 1)) // 2
    out = []
    for dx in range(-k, k + 1):
        for dz in range(-k, k + 1):
            if abs(-dx - dz) > k:
                continue
            z = row + dz
            out.append((x0 + dx + (z - (z & 1)) // 2, z))
    return out


def lonlat_units(lon, lat):
    """A lon/lat point in the campaign's unit space (hex radii), with geo's projection."""
    xu = (lon - geo.LON0) / geo.COL_DEG
    fy = (geo.Y_TOP - geo.merc(lat)) / geo.ROW_DEG
    return xu * SQ3, fy * 1.5 + 0.25


def _seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / (dx * dx + dy * dy + 1e-9)))
    return math.hypot(p[0] - ax - t * dx, p[1] - ay - t * dy)


def _poly_dist(p, pts):
    return min(_seg_dist(p, a, b) for a, b in zip(pts, pts[1:]))


def _wave(t, seed):
    f1 = 2.0 + (seed % 7) / 7.0
    p1 = (seed % 997) / 997.0 * 6.283
    p2 = (seed % 613) / 613.0 * 6.283
    return 0.34 * math.sin(6.283 * f1 * t + p1) + 0.16 * math.sin(6.283 * f1 * 2.3 * t + p2)


def _smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def band_curve(e, depth, ca, cb, seed, n=26):
    """Points (unit hex at origin) of the inner wavy curve of a band along edge e. ca / cb: corner depth factors."""
    a, b = edge_ends(e)
    nx, ny = edge_normal(e)
    pts = []
    for i in range(n + 1):
        t = i / n
        ramp = min(ca + (1 - ca) * _smooth(t / 0.32), cb + (1 - cb) * _smooth((1 - t) / 0.32))
        d = depth * ramp * (1.0 + _wave(t, seed))
        x = a[0] + (b[0] - a[0]) * t - nx * d
        y = a[1] + (b[1] - a[1]) * t - ny * d
        pts.append((x, y))
    return pts


def _variant(pos):
    return ((pos[0] * 73856093) ^ (pos[1] * 19349663)) % 3


# ----------------------------------------------------------------------------------------------- decorations
def _rock_poly(rng, x, y, s):
    k = rng.randint(5, 6)
    return [(x + math.cos(6.283 * i / k + rng.uniform(-.3, .3)) * s * rng.uniform(.7, 1.1),
             y + math.sin(6.283 * i / k + rng.uniform(-.3, .3)) * s * rng.uniform(.55, .8)) for i in range(k)]


def deco_tuft(sf, x, y, q, col):
    w = max(1, round(q * 0.9))
    for dx, h in ((-1.6, 3.4), (0, 4.6), (1.6, 3.2)):
        pygame.draw.line(sf, col, (x, y), (x + dx * q, y - h * q), w)


def deco_pebble(sf, x, y, q, rng, base=(150, 146, 140)):
    s = q * rng.uniform(1.4, 2.4)
    poly = _rock_poly(rng, x, y, s)
    pygame.draw.polygon(sf, shade(base, rng.uniform(-.08, .1)), poly)
    pygame.draw.polygon(sf, shade(base, -0.45), poly, max(1, round(q * 0.7)))


def deco_scree(sf, x, y, q, rng, base=(160, 154, 146)):
    s = q * rng.uniform(1.8, 3.6)
    poly = _rock_poly(rng, x, y, s)
    pygame.draw.polygon(sf, base, poly)
    half = [p for p in poly if p[0] >= x - s * 0.1] + [(x, y + s * 0.3)]
    if len(half) >= 3:
        pygame.draw.polygon(sf, shade(base, -0.22), half)
    pygame.draw.polygon(sf, INK, poly, max(1, round(q * 0.8)))


def deco_ripple(sf, x, y, q, ang, col):
    ux, uy = math.cos(ang), math.sin(ang)
    L = q * 4.5
    pts = [(x + ux * L * t + (-uy) * math.sin(t * 3.14) * q * 1.4, y + uy * L * t + ux * math.sin(t * 3.14) * q * 1.4)
           for t in (-1, -0.5, 0, 0.5, 1)]
    pygame.draw.lines(sf, col, False, pts, max(1, round(q)))


def deco_dune(sf, x, y, q, col):
    """A small Kenney-flat dune: lit left half, shaded right half, a darker foot line."""
    w, h = q * 8, q * 3.6
    top = (x - w * 0.12, y - h)
    left = [(x - w / 2, y), top, (x - w * 0.12, y)]
    right = [(x - w * 0.12, y), top, (x + w / 2, y)]
    pygame.draw.polygon(sf, shade(col, 0.1), left)
    pygame.draw.polygon(sf, shade(col, -0.16), right)
    pygame.draw.line(sf, shade(col, -0.36), (x - w / 2, y), (x + w / 2, y), max(1, round(q * 0.9)))


def deco_reeds(sf, x, y, q, rng):
    col = (104, 146, 66)
    for i in range(rng.randint(3, 5)):
        dx = rng.uniform(-2.6, 2.6) * q
        h = rng.uniform(4.5, 8) * q
        lean = rng.uniform(-1.2, 1.2) * q
        pygame.draw.line(sf, shade(col, rng.uniform(-.2, .1)), (x + dx, y), (x + dx + lean, y - h), max(1, round(q)))
        if rng.random() < 0.45:
            pygame.draw.ellipse(sf, (116, 74, 42), pygame.Rect(round(x + dx + lean - q), round(y - h - q * 0.5),
                                                               max(2, round(q * 2)), max(3, round(q * 3))))


def deco_puddle(sf, x, y, q):
    rect = pygame.Rect(round(x - 4 * q), round(y - 1.5 * q), round(8 * q), round(3 * q))
    pygame.draw.ellipse(sf, (92, 160, 200), rect)
    pygame.draw.ellipse(sf, (60, 118, 160), rect, max(1, round(q * 0.8)))
    pygame.draw.line(sf, (170, 214, 236), (x - 2 * q, y - 0.4 * q), (x + q, y - 0.4 * q), max(1, round(q * 0.7)))


def deco_shrub(sf, x, y, q, rng, col=(58, 112, 52)):
    for dx, dy, rr in ((-2.2, -1.6, 2.4), (1.8, -1.8, 2.6), (0, -3.0, 2.8)):
        pygame.draw.circle(sf, shade(col, -0.25), (x + dx * q + q * 0.6, y + dy * q + q * 0.6), rr * q)
    for dx, dy, rr in ((-2.2, -1.6, 2.4), (1.8, -1.8, 2.6), (0, -3.0, 2.8)):
        pygame.draw.circle(sf, col, (x + dx * q, y + dy * q), rr * q * 0.9)
    pygame.draw.circle(sf, shade(col, 0.25), (x - q, y - 3.6 * q), q * 1.0)


def deco_leaf(sf, x, y, q, rng):
    col = rng.choice([(214, 118, 46), (196, 150, 52), (160, 110, 50)])
    pygame.draw.circle(sf, col, (x, y), max(1, q * 0.8))


def deco_drift(sf, x, y, q, rng, ang):
    ux, uy = math.cos(ang), math.sin(ang)
    for i in range(3):
        t = (i - 1) * 2.6 * q
        cx, cy = x + ux * t, y + uy * t
        w, h = q * rng.uniform(5.2, 7.2), q * rng.uniform(2.4, 3.4)
        pygame.draw.ellipse(sf, (196, 212, 230), pygame.Rect(round(cx - w / 2), round(cy - h / 2 + q), round(w), round(h)))
        pygame.draw.ellipse(sf, (248, 251, 255), pygame.Rect(round(cx - w / 2), round(cy - h / 2), round(w), round(h)))


def deco_crystal(sf, x, y, q, rng):
    s = max(1, round(q * rng.uniform(1.0, 1.6)))
    pygame.draw.rect(sf, (252, 252, 250), pygame.Rect(round(x), round(y), s, s))
    pygame.draw.rect(sf, (190, 200, 210), pygame.Rect(round(x), round(y), s, s), max(1, round(q * 0.4)))


def deco_flower(sf, x, y, q, rng):
    col = rng.choice([(246, 226, 90), (250, 250, 244), (226, 120, 150)])
    pygame.draw.circle(sf, col, (x, y), max(1, q * 0.9))


def decorate(sf, kind_b, kind_a, curve, q, rng, inward, avg_b):
    """Decorations along the inner lip of a band of kind_b lying on kind_a. curve: pixel points, inward: (nx, ny)
    pointing into A (away from the edge)."""
    nx, ny = inward
    L = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(curve, curve[1:]))
    if L < 6:
        return
    ang = math.atan2(curve[-1][1] - curve[0][1], curve[-1][0] - curve[0][0])

    def along(step, jitter):
        out, acc = [], rng.uniform(0, step)
        segs = list(zip(curve, curve[1:]))
        dist = 0.0
        for a, b in segs:
            sl = math.hypot(b[0] - a[0], b[1] - a[1])
            while acc <= dist + sl:
                t = (acc - dist) / max(sl, 1e-6)
                out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
                acc += step * rng.uniform(1 - jitter, 1 + jitter)
            dist += sl
        return out[1:-1] if len(out) > 2 else out

    green_d = shade(avg_b, -0.32)
    if kind_b in ("plains", "hills", "montane", "forest") and kind_a in ("dirt", "good", "sand"):
        for x, y in along(5.5 * q, 0.5):
            s = rng.uniform(0.0, 2.6) * q
            deco_tuft(sf, x + nx * s, y + ny * s + 1.5 * q, q, green_d)
        for x, y in along(13 * q, 0.6):
            s = rng.uniform(2.5, 6.5) * q
            if kind_a == "good":
                for _ in range(2):
                    deco_crystal(sf, x + nx * s + rng.uniform(-2, 2) * q, y + ny * s + rng.uniform(-2, 2) * q, q, rng)
            else:
                deco_pebble(sf, x + nx * s, y + ny * s, q, rng)
    if kind_b == "forest":
        for x, y in along(9 * q, 0.5):
            s = rng.uniform(-1.0, 1.5) * q
            deco_shrub(sf, x + nx * s, y + ny * s + 2 * q, q * rng.uniform(0.7, 1.0), rng)
        for x, y in along(6 * q, 0.6):
            s = rng.uniform(1, 5) * q
            deco_leaf(sf, x + nx * s, y + ny * s, q, rng)
    elif kind_b in ("plains", "hills") and kind_a not in ("dirt", "good", "sand"):
        for x, y in along(8 * q, 0.6):
            s = rng.uniform(0, 3) * q
            deco_tuft(sf, x + nx * s, y + ny * s + 1.5 * q, q, green_d)
        for x, y in along(16 * q, 0.6):
            deco_flower(sf, x + nx * 2 * q, y + ny * 2 * q, q, rng)
    elif kind_b in ("alpine", "montane"):
        base = (166, 160, 150) if kind_b == "alpine" else (150, 146, 136)
        for x, y in along((4.2 if kind_b == "alpine" else 7.5) * q, 0.6):
            s = rng.uniform(-3.5, 4.0) * q
            deco_scree(sf, x + nx * s, y + ny * s, q * rng.uniform(0.6, 1.0), rng, base)
        for x, y in along(7 * q, 0.6):
            s = rng.uniform(4.0, 8.0) * q
            deco_pebble(sf, x + nx * s, y + ny * s, q * 0.8, rng)
        if kind_a not in ("alpine", "snow"):
            for x, y in along(11 * q, 0.6):
                deco_tuft(sf, x + nx * 6 * q, y + ny * 6 * q, q, (70, 130, 70))
    elif kind_b == "sand":
        for x, y in along(9 * q, 0.4):
            s = rng.uniform(-6.5, -2.5) * q
            deco_ripple(sf, x + nx * s, y + ny * s, q, ang, shade(avg_b, -0.3))
        for x, y in along(15 * q, 0.5):
            deco_dune(sf, x - nx * 1.5 * q, y - ny * 1.5 * q, q, avg_b)
        for x, y in along(7 * q, 0.6):
            s = rng.uniform(1.5, 4.5) * q
            deco_tuft(sf, x + nx * s, y + ny * s + q, q, (60, 130, 70))
    elif kind_b == "marsh":
        for x, y in along(12 * q, 0.5):
            s = rng.uniform(-7, -3) * q
            deco_puddle(sf, x + nx * s, y + ny * s, q * rng.uniform(0.6, 0.9))
        for x, y in along(6.5 * q, 0.5):
            s = rng.uniform(-1, 2.5) * q
            deco_reeds(sf, x + nx * s, y + ny * s + q, q * 0.85, rng)
    elif kind_b == "snow":
        for x, y in along(8 * q, 0.5):
            s = rng.uniform(-1.5, 1.5) * q
            deco_drift(sf, x + nx * s, y + ny * s, q * rng.uniform(0.7, 1.0), rng, ang)
        if kind_a in ("alpine", "montane"):
            for x, y in along(10 * q, 0.6):
                s = rng.uniform(3, 7) * q
                deco_scree(sf, x + nx * s, y + ny * s, q * 0.6, rng, (150, 146, 140))


# ----------------------------------------------------------------------------------------------- object sprites
_OB = BoundedCache("landscape.sprites", 4096)
_PIECE = BoundedCache("landscape.pieces", 32)
# farm buildings and markers made with the game's own goodsart pens (drawn at 2x, base point = bottom centre)
PIECES = {"barn": (44, 36), "windmill": (56, 62), "farmhouse": (40, 34), "stump": (10, 6), "haystack": (14, 12),
          "hospice": (40, 40), "snowmark": (16, 26)}


def _piece(name, seed):
    key = (name, seed)
    hit = _PIECE.get(key)
    if hit is not None:
        return hit
    w, h = PIECES[name]
    K2 = goodsart.K
    surf = pygame.Surface((w * K2, h * K2), pygame.SRCALPHA)
    p = draw.Pen(surf)
    x, y = w / 2, h - 1
    if name == "barn":
        goodsart.building(p, x - 4, y, 26, 12, 16, (184, 66, 50), (112, 82, 64), "side", rh=10, wins=0)
        p.rect((240, 230, 210), x - 8, y - 9, 8, 9)
        p.line((184, 66, 50), (x - 8, y - 9), (x, y), 1)
        p.line((184, 66, 50), (x, y - 9), (x - 8, y), 1)
    elif name == "windmill":
        goodsart.windmill(p, x, y, 0.95, (18, 30, 8, 24)[seed])
    elif name == "farmhouse":
        top = goodsart.building(p, x - 3, y, 22, 13, 14, goodsart.CREAM, goodsart.ROOF_RED, "front", wins=2)
        goodsart.chimney(p, top[0] + 7, top[1] + 10, 3, 7)
    elif name == "stump":
        p.oval(goodsart.DWOOD, x, y - 2.5, 3.6, 2.2)
        p.oval((196, 160, 110), x, y - 3.4, 2.6, 1.4)
    elif name == "haystack":
        goodsart.mound(p, x, y, 11, 10, (236, 190, 70), (255, 236, 150))
    elif name == "hospice":                 # a pass hospice: a stone house with a small chapel tower
        top = goodsart.building(p, x - 3, y, 20, 12, 12, (214, 206, 190), (84, 84, 100), "side", rh=8, wins=2)
        bx, by = x + 6, top[1] + 2
        p.rect(INK, bx - 3, by - 8, 6, 9)
        p.rect((214, 206, 190), bx - 2, by - 7, 4, 7)
        p.rect(INK, bx - 1, by - 5, 2, 3)
        p.poly(INK, [(bx - 4, by - 7), (bx, by - 12), (bx + 4, by - 7)])
        p.poly((84, 84, 100), [(bx - 3, by - 7.5), (bx, by - 11), (bx + 3, by - 7.5)])
    elif name == "snowmark":                # winter: a post with a small snowflake sign, the pass is shut by snow
        p.rect(INK, x - 1, y - 10, 2, 10)
        p.circle(INK, (x, y - 16), 7.2)
        p.circle((248, 250, 254), (x, y - 16), 6.0)
        for k in range(3):
            a = math.radians(90 + 60 * k)
            dx, dy = math.cos(a) * 4.2, math.sin(a) * 4.2
            p.line((70, 120, 190), (x - dx, y - 16 - dy), (x + dx, y - 16 + dy), 1.3)
    return _PIECE.put(key, (surf, w, h))


def obj_sprite(name, size, seed, cat, r, flip=False):
    """An object at hex radius r. cat picks the OSCALE family. Base point = bottom centre. Cached."""
    key = (name, size, seed % 4, cat, r, flip)
    hit = _OB.get(key)
    if hit is not None:
        return hit
    f = r / OBJ_R * OSCALE[cat]
    if name in NATURE_NAMES:
        s2, fw, fh = nature._get2x(name, size, seed % 4)
        img = pygame.transform.smoothscale(s2, (max(2, round(fw * f)), max(2, round(fh * f))))
    elif name in life.OBJECTS:
        s1 = life._obj(name, LIFE_SIZES.get(size, size), seed % 4)
        img = pygame.transform.smoothscale(s1, (max(2, round(s1.get_width() * f)), max(2, round(s1.get_height() * f))))
    elif name in PIECES:
        s2, fw, fh = _piece(name, seed % 4)
        img = pygame.transform.smoothscale(s2, (max(2, round(fw * f)), max(2, round(fh * f))))
    else:
        raise KeyError(name)
    if flip:
        img = pygame.transform.flip(img, True, False)
    return _OB.put(key, img)


# ----------------------------------------------------------------------------------------------- clearings
_BLOBS = BoundedCache("landscape.blobs", 2048)


def clearing_blob(c):
    X, Y = hex_centre(c.pos)
    rng = random.Random(_h("clear", c.pos))
    ph = [rng.uniform(0, 6.3) for _ in range(3)]
    rad = c.clearing
    out = []
    for i in range(40):
        a = 6.2832 * i / 40
        rr = rad * (1 + 0.17 * math.sin(3 * a + ph[0]) + 0.1 * math.sin(5 * a + ph[1]) + 0.06 * math.sin(7 * a + ph[2]))
        out.append((X + math.cos(a) * rr * 1.1, Y + math.sin(a) * rr * 0.92))
    return out


def _blob_cached(c):
    key = (c.pos, c.clearing)
    return _BLOBS.get(key, lambda: clearing_blob(c))


def voronoi_cells(seeds, box):
    """Convex Voronoi cells clipped to a box polygon (half-plane clipping, nearest seeds first: once the cell fits
    inside half the distance to the next seed, no farther seed can cut it)."""
    cells = []
    for i, s in enumerate(seeds):
        poly = list(box)
        reach2 = max((p[0] - s[0]) ** 2 + (p[1] - s[1]) ** 2 for p in poly)     # farthest corner of the cell so far
        order = sorted((((t[0] - s[0]) ** 2 + (t[1] - s[1]) ** 2, j) for j, t in enumerate(seeds) if j != i))
        for d2, j in order:
            if d2 > 4 * reach2:
                break
            t = seeds[j]
            mx, my = (s[0] + t[0]) / 2, (s[1] + t[1]) / 2
            nx, ny = t[0] - s[0], t[1] - s[1]
            out = []
            for k in range(len(poly)):
                p, q_ = poly[k], poly[(k + 1) % len(poly)]
                dp = (p[0] - mx) * nx + (p[1] - my) * ny
                dq = (q_[0] - mx) * nx + (q_[1] - my) * ny
                if dp <= 0:
                    out.append(p)
                if (dp <= 0) != (dq <= 0):
                    tt = dp / (dp - dq)
                    out.append((p[0] + (q_[0] - p[0]) * tt, p[1] + (q_[1] - p[1]) * tt))
            poly = out
            if len(poly) < 3:
                break
            reach2 = max((p[0] - s[0]) ** 2 + (p[1] - s[1]) ** 2 for p in poly)
        cells.append(poly)
    return cells


def field_system(c):
    """Geometry of a natural field system round a farm cell: [(poly_units, crop, angle, i)], hedges [(a, b)],
    blob polygon, hedge tree points [(x, y)]. Grows with the level; never hex-shaped."""
    lvl = c.fields
    X, Y = hex_centre(c.pos)
    rng = random.Random(_h("fields", c.pos, lvl // 5))
    rad = [0, 0.55, 0.85, 1.15, 1.48][lvl]
    ph1, ph2, ph3 = rng.uniform(0, 6.3), rng.uniform(0, 6.3), rng.uniform(0, 6.3)
    blob = []
    for i in range(48):
        a = 6.2832 * i / 48
        rr = rad * (1 + 0.16 * math.sin(3 * a + ph1) + 0.09 * math.sin(5 * a + ph2) + 0.05 * math.sin(8 * a + ph3))
        blob.append((X + math.cos(a) * rr * 1.08, Y + math.sin(a) * rr * 0.92))
    rng2 = random.Random(_h("seeds", c.pos))
    seeds = []
    for _ in range(400):
        if len(seeds) >= 60:
            break
        x, y = X + rng2.uniform(-1.8, 1.8), Y + rng2.uniform(-1.6, 1.6)
        if all(math.hypot(x - s[0], y - s[1]) > 0.3 for s in seeds):
            seeds.append((x, y))
    box = [(X - 2.0, Y - 1.8), (X + 2.0, Y - 1.8), (X + 2.0, Y + 1.8), (X - 2.0, Y + 1.8)]
    vcells = voronoi_cells(seeds, box)
    fields, hedges, trees = [], [], []
    for i, poly in enumerate(vcells):
        sx, sy = seeds[i]
        if not in_poly(sx, sy, blob, EPS) or len(poly) < 3:
            continue
        crop = CROPS[_h("crop", c.pos, i) % len(CROPS)]
        fields.append((poly, crop, _u("ang", c.pos, i) * 3.14, i))
        for k in range(len(poly)):
            a, b = poly[k], poly[(k + 1) % len(poly)]
            mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            if _u("hedge", c.pos, round(mid[0], 2), round(mid[1], 2)) < 0.62 + 0.06 * lvl and in_poly(*mid, blob, EPS):
                hedges.append((a, b))
                if _u("ht", round(mid[0], 2), round(mid[1], 2)) < 0.26:
                    trees.append(mid)
    return fields, hedges, blob, trees


# ----------------------------------------------------------------------------------------------- tree rules
def _forest_edge_dist(m, c, x, y):
    """Distance (units) from (x, y) in a non-forest hex to the nearest shared edge with a forest neighbour."""
    X, Y = hex_centre(c.pos)
    best = 9.0
    for e, n in enumerate(m.nbrs(c.pos)):
        nb = m.cells.get(n)
        if nb is None or nb.terrain != "forest" or nb.built:
            continue
        nx, ny = edge_normal(e)
        d = APO - ((x - X) * nx + (y - Y) * ny)
        best = min(best, d)
    return best


def tree_density(m, c, x, y):
    """(probability, kind) of a tree at lattice point (x, y) in cell c."""
    if c.built and not c.clearing:
        return 0.0, None
    if c.built or c.ground == "good" or c.fields:
        return 0.0, None
    # forests thin out round a clearing (a town's cleared land) and are gone inside it
    for t in m.clearings_near(c.pos):
        tx, ty = hex_centre(t.pos)
        if abs(tx - x) < 3.2 and abs(ty - y) < 3.2:
            if in_poly(x, y, _blob_cached(t), EPS):
                return 0.0, None
            d = math.hypot(x - tx, y - ty)
            if d < 2.3:
                thin = 0.25 + 0.75 * _smooth((d - t.clearing) / 1.4)
                base, k = tree_density_plain(m, c, x, y)
                return base * thin, k
    return tree_density_plain(m, c, x, y)


def tree_density_plain(m, c, x, y):
    X, Y = hex_centre(c.pos)
    if c.terrain == "forest":
        return 0.97, "forest"
    if c.ground in ("snow", "alpine", "marsh", "sand", "dirt") or c.terrain == "snow":
        return 0.0, None
    if c.terrain == "mountains":
        # treeline: trees only on the lower slopes (front of the hex, below the peaks) and on foothill edges
        dy = y - Y
        low_edge = 0.0
        for e, n in enumerate(m.nbrs(c.pos)):
            nb = m.cells.get(n)
            if nb is None or nb.water or nb.terrain in ("mountains", "snow"):
                continue
            nx, ny = edge_normal(e)
            d = APO - ((x - X) * nx + (y - Y) * ny)
            low_edge = max(low_edge, 1 - d / 0.45)
        slope = _smooth((dy - 0.12) / 0.4)
        return max(slope, low_edge) * 0.85, "slope"
    d = _forest_edge_dist(m, c, x, y)
    if d < 0.30 and c.ground in ("plains", "hills", "montane"):
        return 0.8 * (1 - d / 0.30), "forest"
    if c.terrain == "hills":
        return 0.12, "scatter"
    if c.terrain == "plains":
        return 0.04, "scatter"
    return 0.0, None


def tree_species(c, a, gi, gj, kind, winter):
    """(object name, size) of a tree on cell c at altitude a. Conifers above PINE_LINE, stunted at the treeline."""
    rng = random.Random(_h("sp", gi, gj))
    pine_p = _smooth((a - PINE_LINE + 0.08) / 0.16)              # conifers higher up, broadleaves below
    if kind == "forest" and c.terrain == "forest":
        pine_p = max(pine_p, 0.18)
    table = CONIF if rng.random() < pine_p else BROAD
    name = rng.choices([t[0] for t in table], [t[1] for t in table])[0]
    if a > TREE_LINE - 0.08:                                    # stunted at the treeline
        size = "small"
    else:
        u = rng.random()
        size = "large" if u < 0.22 else ("medium" if u < 0.72 else "small")
    if winter and name in ("fir_tall", "pine_tall") and a > 0.2:
        name = "snowy_tall"
    elif winter and name in ("fir_short", "pine_short") and a > 0.2:
        name = "snowy_short"
    elif winter and name in ("oak", "beech", "linden", "oak_autumn", "birch") and a > 0.2:
        name = "dead_tree"
    return name, size


# ----------------------------------------------------------------------------------------------- cells and model
@dataclass
class Cell:
    """One hex of the campaign map, derived from the world for one season (built lazily, see Landscape)."""
    pos: tuple
    terrain: str
    ground: str = "plains"
    variant: int = 0
    alt: float = 0.0
    good: str = None
    works: int = 0
    settlement: int = 0
    castle: int = 0
    owner: str = None
    name: str = ""
    city: bool = False
    desc: object = None                # wfctiles TileDesc or None
    landmark: str = None
    shallow: bool = False
    fields: int = 0                    # natural field system level 0..4 (grain farms)
    clearing: float = 0.0              # forest clearing radius round a town (hex radii)

    @property
    def water(self):
        return self.terrain in ("ocean", "lake")

    @property
    def built(self):
        return bool(self.settlement or self.castle or self.landmark)

    @property
    def goods_tile(self):
        return self.works > 0 and self.good in goodsart._GOODS and self.good != "grain" and not self.built


class _CellView:
    """Dict-like access to a season's cells, built on demand (the map is never fully derived)."""

    def __init__(self, land, season):
        self._land, self._season = land, season

    def get(self, pos, default=None):
        c = self._land._cell(pos, self._season)
        return default if c is None else c

    def __getitem__(self, pos):
        c = self._land._cell(pos, self._season)
        if c is None:
            raise KeyError(pos)
        return c

    def __contains__(self, pos):
        return self._land._cell(pos, self._season) is not None


class _Model:
    """What the rule functions need from a season: cells, neighbours, altitude, clearings."""

    def __init__(self, land, season):
        self.land, self.season = land, season
        self.cells = _CellView(land, season)
        self._clr = {}

    def nbrs(self, pos):
        return list(neighbors(pos))

    def alt_at(self, X, Y):
        return self.land._alt_at(X, Y)

    def clearings_near(self, pos):
        if pos not in self._clr:
            out = []
            for p in _near_positions(pos, 4):
                c = self.cells.get(p)
                if c is not None and c.clearing:
                    out.append(c)
            self._clr[pos] = out
        return self._clr[pos]


class _Frame:
    """Unit -> pixel transform for one composite: the hex centre sits in the middle of the canvas."""

    def __init__(self, X, Y, S, w, h):
        self.X, self.Y, self.S, self.w, self.h = X, Y, S, w, h

    def px(self, X, Y):
        return self.w / 2 + (X - self.X) * self.S, self.h / 2 + (Y - self.Y) * self.S


def check_season(season):
    if season not in SEASONS:
        raise ValueError(f"season must be 'summer' or 'winter', not {season!r}")
    return season


def _ridges_of(geo_lines):
    """Ridge polylines (unit space, bbox) from geo.MOUNTAINS-style lon/lat lines. Tall ridges (reaching 45 N or
    further north) get the Alpine height and fall; the rest get the Apennine ones."""
    out = []
    for line in geo_lines or ():
        if len(line) < 2:
            continue
        pts = [lonlat_units(lon, lat) for lon, lat in line]
        tall = max(lat for _, lat in line) >= 45.0
        hgt, fall = (1.0, 5.2) if tall else (0.5, 3.0)
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        bbox = (min(xs) - fall, min(ys) - fall, max(xs) + fall, max(ys) + fall)
        out.append((pts, hgt, fall, bbox))
    return out


def _edge_index(world):
    """River and road edges per hex: ({pos: edges}, {pos: edges}) in neighbors() order."""
    rivers, roads = {}, {}
    river_at = getattr(world, "river_at", {})

    def link(table, a, b):
        near_a, near_b = list(neighbors(a)), list(neighbors(b))
        if b in near_a and a in near_b:
            table.setdefault(a, set()).add(near_a.index(b))
            table.setdefault(b, set()).add(near_b.index(a))

    for name, path in getattr(world, "rivers", {}).items():
        for a, b in zip(path, path[1:]):
            link(rivers, a, b)
        end = path[-1]                      # a tributary flows into the river next to it
        for n in neighbors(end):
            if river_at.get(n) not in (None, name) and n not in path:
                link(rivers, end, n)
                break
    for path in getattr(world, "road_paths", []):
        for a, b in zip(path, path[1:]):
            link(roads, a, b)
    return rivers, roads


# ----------------------------------------------------------------------------------------------- ridge crests
# A crest edge (world.ridge_edges) is the line of a mountain range between two hexes: no army crosses it except at a
# pass (world.pass_edges). Here is only its look. Each half of an edge (each of the two hexes) picks a LOOK from the
# range height (geo.MOUNTAIN_HEIGHT, read with a default), the altitude of the land, the hex's terrain and the climate:
#   alpine  mountain hexes at 0.85 and up: a rock band, snow on the crest, one snow peak per side (staggered)
#   rocky   middle ranges in mountain hexes (hills when high): a narrow rock band, one crag or foothill per side
#           (dry rock in the dry lands: warm stone, shrubs)
#   forest  wet lower ridges: a dark forest-floor band, a rock lip, a green hump and two conifers per side
#   scarp   dry lower ridges: an ochre escarpment with strata, an outcrop and a dry hill
# Every look draws one band and a soft relief fold along the edge, so the line reads at r=21 and r=13 as a calm
# natural border, never a wall. The palettes are keyed by look and season (summer, winter; others fall back to summer).
RIDGE_HEIGHT = 0.6                  # the height of a range that geo.MOUNTAIN_HEIGHT does not list
DRY_TERRAIN = {"desert", "steppe", "savanna", "beach"}
LEVEL = {"snow": 4, "mountains": 3, "hills": 2, "forest": 1, "taiga": 1, "jungle": 1}
RANK = {"alpine": 3, "rocky": 2, "scarp": 1, "forest": 1}
RIDGE_DEPTH = {"alpine": 0.3, "rocky": 0.24, "forest": 0.28, "scarp": 0.26}   # band depth into the hex (r)
RIDGE_FOLD = {"alpine": 1.0, "rocky": 1.35, "forest": 1.5, "scarp": 1.4}      # the low crests fold a little stronger
RIDGE_WASH = {"alpine": 0.62, "rocky": 0.72, "forest": 0.78, "scarp": 0.74}   # how far the fold reaches (r)
RIDGE_PAL = {                           # (kind, dry): {season: (lit band, shaded band, crest strip or None)}
    ("alpine", False): {"summer": ((184, 178, 172), (118, 112, 122), (250, 251, 253)),
                        "winter": ((236, 240, 248), (170, 186, 212), (252, 253, 255))},
    ("rocky", False): {"summer": ((170, 160, 146), (116, 106, 100), None),
                       "winter": ((170, 160, 146), (116, 106, 100), (244, 246, 250))},
    ("rocky", True): {"summer": ((206, 182, 140), (150, 122, 92), None),
                      "winter": ((200, 180, 146), (146, 122, 96), None)},
    ("forest", False): {"summer": ((78, 120, 66), (34, 64, 44), (156, 148, 132)),
                        "winter": ((84, 112, 92), (58, 82, 72), (226, 232, 242))},
    ("scarp", True): {"summer": ((222, 180, 116), (168, 116, 70), (120, 82, 52)),
                      "winter": ((214, 178, 124), (160, 116, 76), (120, 82, 52))},
}
PIECE_SCALE = {"hospice": 2.6, "snowmark": 2.0}      # object scale on top of the library size (see _sprite_key)


def ridge_palette(look, season):
    """(lit, shade, crest strip) of a look in a season."""
    key = (look["kind"], look["dry"] if look["kind"] == "rocky" else look["kind"] == "scarp")
    pal = RIDGE_PAL.get(key) or RIDGE_PAL[("rocky", False)]
    lit, shade_, top = pal.get(season) or pal["summer"]
    snow = look["snow_winter"] if season == "winter" else look["snow_summer"]
    if look["kind"] == "rocky" and snow:
        top = (244, 246, 250)
    if not snow and look["kind"] in ("alpine", "rocky"):
        top = None
    return lit, shade_, top


def _unit_mid(a, b):
    (ax, ay), (bx, by) = hex_centre(a), hex_centre(b)
    return (ax + bx) / 2, (ay + by) / 2


def _crowded(c):
    """Development that a ridge must leave alone: a town or castle, a landmark, fields, a goods tile."""
    return bool(c.built or c.landmark or c.fields or c.ground == "good")


class Ridges:
    """The crest edges, passes and looks of one world (the geography is fixed, so it is built once per Landscape).

    crest {pos: {edge index: edge}}   the crest edges of a hex (neighbors() order); passe {pos: {edge index: name}}
    side {(pos, edge index): look}    the look of that hex's half; look {edge: look} the stronger half of each edge
    pass_mids, pass_tracks            where the saddles are (unit points) and the hex centre to saddle lines"""

    def __init__(self, land):
        world = land.world
        g = world.geo
        lines = getattr(g, "MOUNTAINS", None) or []
        heights = list(getattr(g, "MOUNTAIN_HEIGHT", None) or [])
        heights += [RIDGE_HEIGHT] * (len(lines) - len(heights))
        self._lines = [([lonlat_units(lon, lat) for lon, lat in line], heights[i]) for i, line in enumerate(lines)
                       if len(line) > 1]
        self.crest, self.passe, self.hospice, self.side, self.look = {}, {}, {}, {}, {}
        self.pass_mids, self.pass_tracks, self.corners = [], [], {}
        self.pass_set = set()                           # the pass edges (a subset of the keys of look)
        self._near, self._far = {}, None
        edges = [(e, None) for e in world.ridge_edges()] + [(e, name) for name, _, e, _ in world.pass_edges()]
        for edge, name in edges:
            a, b = sorted(edge)
            ia, ib = list(neighbors(a)).index(b), list(neighbors(b)).index(a)
            la, lb = self._classify(land, world, a, b), self._classify(land, world, b, a)
            self.side[(a, ia)], self.side[(b, ib)] = la, lb
            self.look[edge] = max(la, lb, key=lambda lk: RANK[lk["kind"]])
            for p, e in ((a, ia), (b, ib)):
                if name is None:
                    self.crest.setdefault(p, {})[e] = edge
                else:
                    self.passe.setdefault(p, {})[e] = name
            if name is not None:
                self.pass_set.add(edge)
                self.hospice.setdefault(name, (a, ia))
                mid = _unit_mid(a, b)
                self.pass_mids.append(mid)
                for p in (a, b):
                    self.pass_tracks.append((hex_centre(p), mid))
        for edge in self.look:
            a, b = sorted(edge)
            X, Y = hex_centre(a)
            for p in edge_ends(list(neighbors(a)).index(b)):
                k = (round(X + p[0], 2), round(Y + p[1], 2))
                self.corners[k] = self.corners.get(k, 0) + 1

    def _classify(self, land, world, pos, other):
        """The look of one hex's half of the crest edge pos|other."""
        x, y = _unit_mid(pos, other)
        h, best = RIDGE_HEIGHT, 1e9
        for pts, height in self._lines:
            d = min(_seg_dist((x, y), p, q) for p, q in zip(pts, pts[1:]))
            if d < best:
                best, h = d, height
        alt = land._alt_at(x, y)
        eff = min(alt, h)                               # a low range stays low even where the model's ridge is tall
        t = world.terrain.get(pos)
        level = LEVEL.get(t, 0)
        lon, lat = world.geo.lonlat(pos)
        dry = t in DRY_TERRAIN or lat < 39.5 or (lat < 41.5 and lon < 0)
        if level >= 3 and eff >= 0.85:
            kind = "alpine"
        elif level >= 3 and eff >= 0.48:
            kind = "rocky"
        elif level >= 2 and eff >= 0.6:
            kind = "rocky"
        else:
            kind = "scarp" if dry else "forest"
        if kind == "forest" and level >= 3 and dry:
            kind = "rocky"
        snow_winter = (kind == "alpine" or (kind == "rocky" and not dry and (eff > 0.55 or lat > 45))
                       or (kind == "forest" and lat > 46))
        return {"kind": kind, "dry": dry and kind != "forest", "h": h, "alt": alt, "eff": eff, "lat": lat,
                "snow_summer": kind == "alpine", "snow_winter": snow_winter}

    def edges(self, pos):
        """{edge index: pass name or None} of the crest and pass edges of a hex."""
        return {**{e: None for e in self.crest.get(pos, {})}, **self.passe.get(pos, {})}

    def look_of(self, pos, e):
        return self.side.get((pos, e))

    def chain_end(self, pos, e, end):
        """True if the corner at this end of edge e (0: first corner, 1: second) is where a crest chain ends."""
        X, Y = hex_centre(pos)
        p = edge_ends(e)[end]
        return self.corners.get((round(X + p[0], 2), round(Y + p[1], 2)), 0) <= 1

    def key(self, pos, season):
        """What the ground composite of a hex takes from the ridges (part of its cache key): per edge the look, the
        season's snow, whether the corners end a chain, and whether it is a pass."""
        out = []
        for e, name in sorted(self.edges(pos).items()):
            lk = self.side.get((pos, e))
            if lk is not None:
                snow = lk["snow_winter"] if season == "winter" else lk["snow_summer"]
                out.append((e, lk["kind"], lk["dry"], snow, self.chain_end(pos, e, 0), self.chain_end(pos, e, 1),
                            name is not None))
        return tuple(out)

    def near_pass(self, pos):
        """(saddles, tracks) within reach of a hex: what its trees and peaks keep off."""
        hit = self._near.get(pos)
        if hit is None:
            X, Y = hex_centre(pos)
            mids = [m for m in self.pass_mids if (m[0] - X) ** 2 + (m[1] - Y) ** 2 < 2.4 ** 2]
            tracks = [t for t in self.pass_tracks if _seg_dist((X, Y), t[0], t[1]) < 1.5]
            hit = self._near[pos] = (mids, tracks)
        return hit

    def on_pass(self, pos, x, y):
        """Is (x, y) on a pass saddle (0.55 r) or on a pass track (0.22 r)?"""
        mids, tracks = self.near_pass(pos)
        for mx, my in mids:
            if (x - mx) ** 2 + (y - my) ** 2 < 0.55 ** 2:
                return True
        for p, q in tracks:
            if _seg_dist((x, y), p, q) < 0.22:
                return True
        return False

    def pass_sites(self):
        """[(pass name, hex, hex across)] of every pass edge, one entry per edge (sorted)."""
        out = []
        for edge in sorted(self.pass_set, key=lambda e: sorted(e)):
            a, b = sorted(edge)
            name = self.passe[a][list(neighbors(a)).index(b)]
            out.append((name, a, b))
        return out

    def far_edges(self):
        """[(hex a, hex b, (corner point, corner point), look, is_pass)] of every crest and pass edge, in unit points,
        for the zooms that draw the fold without the landscape art."""
        if self._far is None:
            out = []
            for edge, look in self.look.items():
                a, b = sorted(edge)
                e = list(neighbors(a)).index(b)
                X, Y = hex_centre(a)
                p, q = edge_ends(e)
                out.append((a, b, ((X + p[0], Y + p[1]), (X + q[0], Y + q[1])), look, edge in self.pass_set))
            self._far = out
        return self._far


def hospice_spot(pos, e):
    """Where a pass's hospice stands: a unit point near the hex centre, set to the side of the track."""
    X, Y = hex_centre(pos)
    nx, ny = edge_normal(e)
    return X + nx * 0.18 - ny * 0.3, Y + ny * 0.18 + nx * 0.3 + 0.12


def _drift(gs, cx, cy, P, q, e):
    """The winter snow drift in a pass saddle."""
    nx, ny = edge_normal(e)
    tx, ty = -ny, nx
    pts = []
    for i in range(17):
        a = i / 16 * math.pi * 2
        r1 = 0.24 + 0.03 * math.sin(a * 3)
        x = nx * (APO * 0.8) + tx * math.cos(a) * r1 * 1.25 + nx * math.sin(a) * r1 * 0.7
        y = ny * (APO * 0.8) + ty * math.cos(a) * r1 * 1.25 + ny * math.sin(a) * r1 * 0.7
        pts.append((cx + x * P, cy + y * P))
    pygame.draw.polygon(gs, (250, 252, 255), pts)
    pygame.draw.lines(gs, (150, 170, 204), True, pts, max(1, round(q * 1.6)))


def _snowflake(sf, centre, size):
    """A small six-armed snowflake with a dark outline, readable on snow, grass and sea."""
    x, y = centre
    arms = [(math.cos(math.pi / 6 + i * math.pi / 3) * size, math.sin(math.pi / 6 + i * math.pi / 3) * size)
            for i in range(3)]
    width = max(1, round(size / 3))
    for colour, w in (((28, 40, 64, 255), width + 2), ((246, 250, 255, 255), width)):
        for dx, dy in arms:
            pygame.draw.line(sf, colour, (x - dx, y - dy), (x + dx, y + dy), w)
    pygame.draw.circle(sf, (150, 200, 240, 255), (x, y), max(1, size * 0.22))


def draw_far_ridges(sf, r, winter, to_px, items):
    """The relief fold at the zooms without landscape art (r <= 13): a soft shade on the side away from the light and a
    faint lit line, weighted by the look; r=13 also one small peak on alpine and rocky edges. items: [((a, b), look,
    is_pass)] with a, b the edge's corners in unit points; to_px maps them to the surface sf."""
    lay = pygame.Surface(sf.get_size(), pygame.SRCALPHA)
    strength = {"alpine": 1.0, "rocky": 1.0, "forest": 0.85, "scarp": 0.95}
    for (a, b), look, is_pass in items:
        k = strength[look["kind"]]
        pa, pb = to_px(a), to_px(b)
        dx, dy = pb[0] - pa[0], pb[1] - pa[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        if nx + ny < 0:
            nx, ny = -nx, -ny
        spans = [(0, 1)] if not is_pass else [(0, 0.22), (0.78, 1)]
        tint = (60, 40, 20) if look["kind"] == "scarp" else (20, 40, 24) if look["kind"] == "forest" else (26, 26, 56)
        for t0, t1 in spans:
            p = (pa[0] + dx * t0, pa[1] + dy * t0)
            q = (pa[0] + dx * t1, pa[1] + dy * t1)
            w = max(3, r * (0.6 if r <= 8 else 0.45))
            poly = [p, q, (q[0] + nx * w, q[1] + ny * w), (p[0] + nx * w, p[1] + ny * w)]
            pygame.draw.polygon(lay, tint + (int((150 if r <= 8 else 80) * k),), poly)
            pygame.draw.line(lay, (255, 255, 255, int((210 if r <= 8 else 120) * k)),
                             (p[0] - nx, p[1] - ny), (q[0] - nx, q[1] - ny), 2 if r >= 5 else 1)
        if is_pass and r >= (13 if winter else 8):    # closed-pass snowflakes only from r=13 (owner)
            m = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2)
            if winter:                  # a closed pass: a frozen snowflake, the owner's winter signal
                _snowflake(lay, m, max(4.5, r * 0.36))
            else:
                pygame.draw.line(lay, (214, 184, 128, 255), (m[0] - nx * r * 0.25, m[1] - ny * r * 0.25),
                                 (m[0] + nx * r * 0.25, m[1] + ny * r * 0.25), max(1, round(r / 8)))
    sf.blit(lay, (0, 0))
    if r == 13:
        for (a, b), look, is_pass in items:
            if is_pass or look["kind"] not in ("alpine", "rocky"):
                continue
            pa, pb = to_px(a), to_px(b)
            m = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2 + 1)
            h, w = r * (0.7 if look["kind"] == "alpine" else 0.5), r * 0.65
            pygame.draw.polygon(sf, (132, 128, 142), [(m[0] - w / 2, m[1]), (m[0], m[1] - h), (m[0], m[1])])
            pygame.draw.polygon(sf, (70, 66, 84), [(m[0], m[1]), (m[0], m[1] - h), (m[0] + w / 2, m[1])])
            if look["kind"] == "alpine" or (winter and look["snow_winter"]):
                pygame.draw.polygon(sf, (246, 248, 252), [(m[0] - w * 0.17, m[1] - h * 0.66), (m[0], m[1] - h),
                                                          (m[0] + w * 0.17, m[1] - h * 0.66)])


# ----------------------------------------------------------------------------------------------- the landscape
class Landscape:
    """Landscape art for one CampaignWorld. Everything is derived from the world's current state; caches are keyed by
    the inputs, and object lists are dropped when world.version changes.

    tiles_dir: the Kenney Tiles folder (hexagon-pack/PNG/Tiles).
    landmark_at: optional {pos: landmark name} (art.landmarks.draw_city names), empty by default.
    life: optional {pos: [(name, size, dx, dy)]} extra life objects in hex-radius units; empty by default.
    """

    def __init__(self, world, tiles_dir):
        self.world = world
        self.tiles_dir = tiles_dir
        self.landmark_at = {}
        self.life = {}
        self._ridges = _ridges_of(getattr(getattr(world, "geo", None), "MOUNTAINS", None))
        self._src_cache, self._scaled_cache, self._avg_cache = {}, {}, {}
        self._grounds = BoundedCache("landscape.grounds", GROUND_CACHE)
        self._grid = {}
        self._gquick = {}                   # (pos, r, season) -> (world version, composite key): skips the key work
        self.builds = 0                     # ground composites built so far (MapView budgets them per frame)
        self.object_builds = 0              # object lists built so far (budgeted the same way)
        self.sprite_builds = 0              # object sprites made so far (make_sprites; budgeted the same way)
        self.overlay_builds = 0             # hexes whose wfc overlay / base picture was made by prepare()
        self._objs = BoundedCache("landscape.objects", OBJECT_CACHE)
        self._specs_cache = {}
        self._field_geo = {}
        self._ridge = None                  # Ridges, built on first use
        self._version = None
        self._sync()

    # ----- season and sync
    def season_now(self):
        """'winter' when world.winter() (turn % 4 == 0), else 'summer'."""
        return "winter" if self.world.winter() else "summer"

    def _sync(self):
        v = getattr(self.world, "version", 0)
        if v != self._version:
            self._version = v
            self._cells = {}
            self._models = {}
            self._rivers, self._roads = _edge_index(self.world)
            self._objs.clear()
            self._specs_cache.clear()

    def _model(self, season):
        self._sync()
        if season not in self._models:
            self._models[season] = _Model(self, season)
        return self._models[season]

    # ----- altitude
    def _alt_at(self, X, Y):
        if self._ridges:
            best = 0.0
            for pts, hgt, fall, (x0, y0, x1, y1) in self._ridges:
                if X < x0 or X > x1 or Y < y0 or Y > y1:
                    continue
                d = _poly_dist((X, Y), pts)
                if d < fall:
                    best = max(best, hgt * (1.0 - d / fall))
            return best
        # no ridge lines: fall back to the terrain under the point
        return {"mountains": 0.45, "snow": 0.92}.get(self.world.terrain.get(_hex_at(X, Y)), 0.0)

    # ----- cells
    def _cell(self, pos, season):
        self._sync()
        key = (pos, season)
        if key not in self._cells:
            self._cells[key] = self._make_cell(pos, season)
        return self._cells[key]

    def _make_cell(self, pos, season):
        world = self.world
        terrain = world.terrain.get(pos)
        if terrain is None:
            return None
        prov = world.provinces.get(pos)
        c = Cell(pos, terrain)
        c.variant = _variant(pos)
        c.landmark = self.landmark_at.get(pos)
        if prov is not None:
            c.good, c.works, c.settlement, c.castle = prov.good, prov.works, prov.settlement, prov.castle
            c.owner, c.name = prov.owner, prov.name
            c.city = prov.settlement >= 2 or bool(prov.castle)
        X, Y = hex_centre(pos)
        c.alt = self._alt_at(X, Y)
        if terrain == "snow":
            c.alt = max(c.alt, 0.92)
        nbrs = list(neighbors(pos))
        if c.water:
            c.ground = "water"
            c.shallow = any(world.terrain.get(n) not in (None, "ocean", "lake") for n in nbrs)
            return c
        g = TERRAIN_GROUND.get(terrain, "plains")
        if terrain == "mountains" and c.alt >= ALPINE_ALT:
            g = "alpine"
        if season == "winter" and (g == "alpine" or (g == "montane" and c.alt > 0.46)):
            g = "snow"
        if c.goods_tile:
            g = "good"
        c.ground = g
        if c.good == "grain" and c.works and not c.built:
            c.fields = min(4, c.works)
        c.desc = self._desc(pos, prov, c.variant, nbrs)
        forest_n = sum(1 for n in nbrs if world.terrain.get(n) == "forest")
        if c.built and (terrain == "forest" or forest_n >= 3):
            c.clearing = 0.62 + 0.1 * min(3, c.settlement)
        return c

    def _desc(self, pos, prov, variant, nbrs):
        """The wfctiles TileDesc of what lies on top of a land hex (as MapView.overlay_desc builds it)."""
        sea = frozenset(e for e, n in enumerate(nbrs) if self.world.terrain.get(n) == "ocean")
        river = frozenset(self._rivers.get(pos, ()))
        road = frozenset(self._roads.get(pos, ())) - frozenset(self.ridges().crest.get(pos, ()))   # none over a crest
        mouth = bool(river) and bool(sea) and len(river) == 1
        town = castle = 0
        if prov is not None:
            if prov.settlement:
                town = {1: 2, 2: 4 if prov.castle else 3,
                        3: 6 if getattr(prov, "pop", 0) >= 60 else 5}.get(prov.settlement, 0)
                if prov.settlement == 1 and prov.castle:
                    town, castle = 0, prov.castle
            elif prov.castle:
                castle = prov.castle
        if not (sea or river or road or town or castle):
            return None
        return wfctiles.TileDesc(sea=sea, river=river - sea, mouth=mouth, road=road - sea,
                                 paved=(road - sea) if town >= 3 else frozenset(), town=town, castle=castle,
                                 variant=variant)

    # ----- sprite sources (per tiles folder)
    def _src(self, name):
        if name in self._src_cache:
            return self._src_cache[name]
        if isinstance(name, tuple):
            if name[0] == "good":
                img = goodsart.good_tile(name[1], name[2], self.tiles_dir, name[3])
            elif name[0] == "sea":
                img = wfctiles.sea_tile(name[1], name[2])
            elif name[0] == "city":
                img = landmarks.draw_city(name[1], name[2])
            elif name[0] == "wfc":
                img = wfctiles.overlay(name[1])
            elif name[0] == "tint":
                img = self._src(name[1]).copy()
                img.fill(name[2] + (255,), special_flags=pygame.BLEND_RGBA_MULT)
            else:
                raise KeyError(name)
        elif name.startswith("art:"):
            _, kind, v = name.split(":")
            img = art.make_tile(kind, self.tiles_dir, int(v))
        else:
            img = pygame.image.load(os.path.join(self.tiles_dir, name)).convert_alpha()
        self._src_cache[name] = img
        return img

    def _ground_src(self, kind, variant):
        sprites, tint_, _ = GROUND[kind]
        name = sprites[variant % len(sprites)]
        return ("tint", name, tint_) if tint_ else name

    def _scaled(self, name, P, f=1.0):
        """A source picture scaled to hex radius P px (the game's sprite size formula), times f."""
        key = (name, P, f)
        if key not in self._scaled_cache:
            img = self._src(name)
            w, h = int(round(P * SQ3 * f)) + 1, int(round(P * SPRITE_H * f)) + 1
            self._scaled_cache[key] = wfctiles.scale_tile(img, w, h)
        return self._scaled_cache[key]

    def _avg(self, name):
        if name not in self._avg_cache:
            img = self._src(name)
            self._avg_cache[name] = tuple(pygame.transform.average_color(img, pygame.Rect(30, 40, 60, 60))[:3])
        return self._avg_cache[name]

    # ----- ground composite
    def ground(self, pos, r, season, build=True):
        """The baked ground of one hex at hex radius r, as an RGBA Surface the size of the game's tile sprite
        (int(round(r*sqrt3))+1 by int(round(r*SPRITE_H))+1). None for hexes not on the map, and for hexes not yet
        built when build is False (the caller draws the old sprite until a later frame)."""
        check_season(season)
        model = self._model(season)                      # also syncs with world.version
        quick = (pos, r, season)
        hit = self._gquick.get(quick)
        c = None
        if hit is not None and hit[0] == self._version:  # this hex's key was worked out for this world version
            key = hit[1]
            img = self._grounds.get(key)
            if img is not None:
                return img
            if not build:                                # not built yet (a frame asks again every frame while it waits)
                return None
        else:
            key = None
        c = model.cells.get(pos)
        if c is None:
            return None
        if key is None:
            nbrs = list(neighbors(pos))
            key = (pos, r, season, c.ground, c.variant, _base_name(c), c.desc, c.fields, round(c.clearing, 3),
                   self.ridges().key(pos, season), c.landmark, c.owner, c.built, c.water,
                   tuple(self._nbr_sig(model, n) for n in nbrs))
            self._gquick[quick] = (self._version, key)
            hit = self._grounds.get(key)
            if hit is not None:
                return hit
            if not build:
                return None
        self.builds += 1
        return self._grounds.put(key, self._build_ground(model, c, r))

    def grid(self, r):
        """The faint hex outline at hex radius r, the size of ground(). Cached per radius."""
        if r not in self._grid:
            tw, th = int(round(r * SQ3)) + 1, int(round(r * SPRITE_H)) + 1
            P = r * K
            gl = pygame.Surface((tw * K, th * K), pygame.SRCALPHA)
            pts = [(tw * K / 2 + x * P, th * K / 2 + y * P) for x, y in hex_poly(0, 0, 1.0)]
            pygame.draw.polygon(gl, (10, 20, 16, 46), pts, max(1, K))
            self._grid[r] = pygame.transform.smoothscale(gl, (tw, th))
        return self._grid[r]

    def _nbr_sig(self, model, n):
        nb = model.cells.get(n)
        if nb is None:
            return None
        return (nb.ground, nb.variant, nb.owner, nb.built, bool(nb.fields), nb.water)

    def _build_ground(self, m, c, r):
        P = r * K
        tw, th = int(round(r * SQ3)) + 1, int(round(r * SPRITE_H)) + 1
        cw, ch = tw * K, th * K
        X, Y = hex_centre(c.pos)
        fr = _Frame(X, Y, P, cw, ch)
        gs = pygame.Surface((cw, ch), pygame.SRCALPHA)
        # base picture, on a rim of its own colour: the clip below grows past the picture's own (antialiased) edge
        grow = (tw + 2) / (r * SQ3)
        rim = [fr.px(*p) for p in hex_poly(X, Y, grow)]
        gs.fill(self._avg(_base_name(c)) + (255,))              # (so the clip below keeps real colours at its edge)
        img = self._scaled(_base_name(c), P, BASE_GROW)         # a little large: the pack's baked edge falls outside
        cx, cy = fr.px(X, Y)
        gs.blit(img, (cx - img.get_width() / 2, cy - img.get_height() / 2))
        self._ground_detail(gs, fr, c, P)
        self._draw_bands(gs, fr, m, c, P)
        self._draw_ridge(gs, fr, m, c, P)
        if c.clearing:
            self._draw_clearing(gs, fr, c, P)
        if c.fields:
            self._paint_fields(gs, fr, c, P)
        if c.desc is not None and not c.landmark:
            ov = self._scaled(("wfc", c.desc), P)
            gs.blit(ov, (cx - ov.get_width() / 2, cy - ov.get_height() / 2))
        # the sprite is clipped to its hex (the grid is a separate overlay, see grid())
        mask = clip_mask((cw, ch))
        # the clip is the hex grown to fill the whole sprite width: neighbours are blitted at whole pixels (spacing
        # r*sqrt3 is not one), so a hex-sized clip leaves 1 px seams (and half-transparent antialiased edge pixels)
        # that show the dark background; grown, the tiles overlap by about a pixel and the sprite's own left and
        # right columns are fully opaque
        pygame.draw.polygon(mask, (255, 255, 255, 255), rim)
        gs.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        return pygame.transform.smoothscale(gs, (tw, th))

    def _draw_bands(self, gs, fr, m, c, P):
        q = P / 68.0
        bands = band_edges(m, c)
        if not bands:
            return
        X, Y = hex_centre(c.pos)
        cx, cy = fr.px(X, Y)
        kinds = {e: nb.ground for e, nb in bands}
        tw, th = int(P * SQ3 * 1.3) + 4, int(P * 2 * 1.3) + 4
        for e, nb in bands:
            kb = nb.ground
            depth = 0.30 + 0.06 * _u("depth", kb, c.ground)              # 8-12 px at r = 34
            if kb in ("alpine", "snow"):
                depth += 0.04
            prev_k, next_k = kinds.get((e - 1) % 6), kinds.get((e + 1) % 6)
            ca = 1.0 if prev_k == kb else 0.08
            cb = 1.0 if next_k == kb else 0.08
            a_pos, b_pos = sorted([c.pos, nb.pos])
            seed = _h("band", a_pos, b_pos)
            curve_u = band_curve(e, depth, ca, cb, seed)
            a, b = edge_ends(e)
            nx, ny = edge_normal(e)
            outer = [(b[0] + nx * 0.06, b[1] + ny * 0.06), (a[0] + nx * 0.06, a[1] + ny * 0.06)]
            poly_u = curve_u + outer
            loc = [(tw / 2 + x * P, th / 2 + y * P) for x, y in poly_u]
            tex = self._scaled(self._ground_src(kb, nb.variant), P, 1.0)
            layer = pygame.Surface((tw, th), pygame.SRCALPHA)
            layer.blit(tex, (tw / 2 - tex.get_width() / 2, th / 2 - tex.get_height() / 2))
            mk = clip_mask((tw, th))
            pygame.draw.polygon(mk, (255, 255, 255, 255), loc)
            layer.blit(mk, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
            gs.blit(layer, (cx - tw / 2, cy - th / 2))
            curve_px = [(cx + x * P, cy + y * P) for x, y in curve_u]
            avg_b = self._avg(self._ground_src(kb, nb.variant))
            lip = shade(avg_b, -0.38)
            pygame.draw.lines(gs, lip, False, curve_px, max(1, round(q * 1.6)))
            rng = random.Random(_h("deco", c.pos, e))
            decorate(gs, kb, c.ground, curve_px, q, rng, (-nx, -ny), avg_b)

    def _ground_detail(self, gs, fr, c, P):
        if c.water or c.landmark or c.ground in ("good", "marsh"):
            return
        q = P / 68.0
        X, Y = hex_centre(c.pos)
        rng = random.Random(_h("detail", c.ground, c.variant, c.pos))

        def spot(k=0.78):
            while True:
                x, y = rng.uniform(-k, k), rng.uniform(-k, k)
                if abs(x) <= APO * k / 0.9 and abs(y) + abs(x) / SQ3 <= k:
                    return fr.px(X + x, Y + y)

        if c.ground == "alpine":
            for _ in range(4):
                x, y = spot(0.7)
                deco_drift(gs, x, y, q * rng.uniform(0.8, 1.2), rng, rng.uniform(-0.3, 0.3))
            for _ in range(26):
                x, y = spot()
                deco_scree(gs, x, y, q * rng.uniform(0.45, 0.75), rng, (170, 164, 156))
            for _ in range(3):
                x, y = spot(0.7)
                pts = [(x + i * 3 * q, y + rng.uniform(-1.5, 1.5) * q + i * 1.2 * q) for i in range(4)]
                pygame.draw.lines(gs, (120, 116, 112), False, pts, max(1, round(q)))
        elif c.ground == "montane":
            for _ in range(10):
                x, y = spot()
                deco_tuft(gs, x, y, q, (60, 110, 64))
            for _ in range(7):
                x, y = spot()
                deco_pebble(gs, x, y, q * 0.8, rng)
        elif c.ground in ("plains", "hills"):
            for _ in range(7):
                x, y = spot()
                deco_tuft(gs, x, y, q, shade(self._avg(self._ground_src(c.ground, c.variant)), -0.25))
            for _ in range(4):
                x, y = spot()
                deco_flower(gs, x, y, q, rng)
        elif c.ground == "snow":
            for _ in range(6):
                x, y = spot()
                w = rng.uniform(6, 11) * q
                pygame.draw.arc(gs, (196, 210, 228), pygame.Rect(round(x - w / 2), round(y), round(w), round(w * 0.4)),
                                3.4, 6.0, max(1, round(q)))
        elif c.ground == "dirt":
            for _ in range(8):
                x, y = spot()
                deco_pebble(gs, x, y, q * 0.8, rng, (170, 140, 110))

    def _draw_clearing(self, gs, fr, c, P):
        q = P / 68.0
        blob = clearing_blob(c)
        pts = [fr.px(*p) for p in blob]
        tex = self._scaled(self._ground_src("plains", c.variant), P, 1.3)
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        bb = pygame.Rect(int(min(xs)) - 4, int(min(ys)) - 4, int(max(xs) - min(xs)) + 9, int(max(ys) - min(ys)) + 9)
        layer = pygame.Surface(bb.size, pygame.SRCALPHA)
        X, Y = hex_centre(c.pos)
        cx, cy = fr.px(X, Y)
        for ox in (-1, 0, 1):                 # tile the grass texture under the blob
            for oy in (-1, 0, 1):
                layer.blit(tex, (cx - bb.x - tex.get_width() / 2 + ox * P * SQ3,
                                 cy - bb.y - tex.get_height() / 2 + oy * P * 1.5))
        mk = clip_mask(bb.size)
        pygame.draw.polygon(mk, (255, 255, 255, 255), [(x - bb.x, y - bb.y) for x, y in pts])
        layer.blit(mk, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        gs.blit(layer, bb.topleft)
        forest_avg = self._avg(self._ground_src("forest", 0))
        pygame.draw.lines(gs, shade(forest_avg, -0.35), True, pts, max(1, round(q * 1.6)))
        rng = random.Random(_h("cdeco", c.pos))
        for i in range(0, len(pts), 2):
            x, y = pts[i]
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy) or 1
            s = rng.uniform(-2.5, 0.5) * q
            deco_shrub(gs, x + dx / d * (3 * q) + s, y + dy / d * (3 * q), q * rng.uniform(0.6, 0.9), rng)
        for i in range(1, len(pts), 3):
            x, y = pts[i]
            dx, dy = cx - x, cy - y
            d = math.hypot(dx, dy) or 1
            deco_tuft(gs, x + dx / d * 4 * q, y + dy / d * 4 * q, q, (40, 120, 70))

    def _paint_fields(self, gs, fr, c, P):
        fields, hedges, blob, _ = self._fields_of(c)
        q = P / 68.0
        layer = pygame.Surface(gs.get_size(), pygame.SRCALPHA)
        for poly, (col, kind), ang, i in fields:
            pts = [fr.px(*p) for p in poly]
            cxp = sum(p[0] for p in pts) / len(pts)
            cyp = sum(p[1] for p in pts) / len(pts)
            ins = [(cxp + (x - cxp) * 0.9, cyp + (y - cyp) * 0.9) for x, y in pts]       # a grass margin round each
            if kind == "meadow":
                pygame.draw.polygon(layer, col, ins)
                continue
            pygame.draw.polygon(layer, col, ins)
            # crop rows across the field, clipped to it
            xs, ys = [p[0] for p in ins], [p[1] for p in ins]
            bb = pygame.Rect(int(min(xs)) - 2, int(min(ys)) - 2, int(max(xs) - min(xs)) + 5, int(max(ys) - min(ys)) + 5)
            rows = pygame.Surface(bb.size, pygame.SRCALPHA)
            ux, uy = math.cos(ang), math.sin(ang)
            step = (4.2 if kind == "rows" else 3.2 if kind == "furrow" else 6.0) * q
            lc = shade(col, -0.16 if kind != "stubble" else -0.1)
            span = int(math.hypot(bb.w, bb.h) / step) + 2
            for k in range(-span, span + 1):
                ox, oy = bb.w / 2 + (-uy) * k * step, bb.h / 2 + ux * k * step
                L = bb.w + bb.h
                pygame.draw.line(rows, lc, (ox - ux * L, oy - uy * L), (ox + ux * L, oy + uy * L), max(1, round(q * 0.9)))
            mk = clip_mask(bb.size)
            pygame.draw.polygon(mk, (255, 255, 255, 255), [(x - bb.x, y - bb.y) for x, y in ins])
            rows.blit(mk, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
            layer.blit(rows, bb.topleft)
            pygame.draw.polygon(layer, shade(col, -0.3), ins, max(1, round(q * 0.9)))
        hedge_c, hedge_d = (54, 108, 50), (36, 76, 38)
        for a, b in hedges:
            pa, pb = fr.px(*a), fr.px(*b)
            pygame.draw.line(layer, hedge_d, (pa[0], pa[1] + q), (pb[0], pb[1] + q), max(2, round(q * 3.4)))
            pygame.draw.line(layer, hedge_c, pa, pb, max(2, round(q * 2.6)))
            for pt in (pa, pb):
                pygame.draw.circle(layer, hedge_c, pt, q * 1.4)
        mk = clip_mask(gs.get_size())
        pygame.draw.polygon(mk, (255, 255, 255, 255), [fr.px(*p) for p in blob])
        layer.blit(mk, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        gs.blit(layer, (0, 0))

    def _fields_of(self, c):
        key = (c.pos, c.fields)
        if key not in self._field_geo:
            self._field_geo[key] = field_system(c)
        return self._field_geo[key]

    # ----- objects
    def objects(self, pos, r, season, build=True):
        """[(surface, dx, dy, sort_y)] of one hex at hex radius r: peaks, hills, trees, farm buildings, life and
        closed-pass markers. dx, dy: offset of the surface's base point (bottom centre) from the hex centre, in
        pixels. sort_y == dy: sort by (centre_y + sort_y) for the back-to-front order. Cached per
        (pos, world.version, season, r); do not mutate the returned list. A sprite that does not exist yet is made
        here; make_sprites() makes them first, so a caller can budget that work on its own."""
        check_season(season)
        self._sync()
        key = (pos, self._version, season, r)
        hit = self._objs.get(key)
        if hit is not None:
            return hit
        if not build:                       # not built yet: None, and the caller draws the hex later
            return None
        self.object_builds += 1
        out = []
        c = self._cell(pos, season)
        if c is not None:
            X, Y = hex_centre(pos)
            for cat, name, size, seed, x, y in self._specs_of(c, season):
                dx, dy = (x - X) * r, (y - Y) * r
                _, rs, flip = _sprite_key(cat, name, size, seed, r)
                surf = obj_sprite(name, size, seed, cat, rs, flip)
                out.append((surf, dx, dy, dy))
            out.sort(key=lambda o: o[3])
        return self._objs.put(key, out)

    def make_sprites(self, pos, r, season):
        """Makes the object sprites of one hex that do not exist yet (the first use of a sprite is the costly part of
        objects()). Returns how many were made; objects() then only assembles the list. Counted in sprite_builds."""
        c = self._cell(pos, check_season(season))
        if c is None:
            return 0
        n = 0
        for cat, name, size, seed, x, y in self._specs_of(c, season):
            key, rs, flip = _sprite_key(cat, name, size, seed, r)
            if key not in _OB:
                obj_sprite(name, size, seed, cat, rs, flip)
                self.sprite_builds += 1
                n += 1
        return n

    def prepare(self, pos, r, season):
        """The first-use work behind ground(pos): the hex's wfc overlay (4-15 ms the first time, the costly part of a
        composite) and its base picture, so that the composite itself is cheap. True if anything was made."""
        check_season(season)
        c = self._model(season).cells.get(pos)
        if c is None:
            return False
        names = [_base_name(c)]
        if c.desc is not None and not c.landmark:
            names.append(("wfc", c.desc))
        made = False
        for name in names:
            if name not in self._src_cache:
                self._src(name)
                made = True
        if made:
            self.overlay_builds += 1
        return made

    def warm_sources(self):
        """Loads the Kenney ground pictures the composites blend with (once; about a dozen images)."""
        for kind, (sprites, _, _) in GROUND.items():
            for v in range(len(sprites)):
                self._src(self._ground_src(kind, v))

    def _specs_of(self, c, season):
        key = (c.pos, season)
        if key not in self._specs_cache:
            self._specs_cache[key] = self._specs(c, season)
        return self._specs_cache[key]

    def object_names(self, pos, season):
        """[(category, object name)] of one hex, without rendering (for tests and debugging)."""
        c = self._cell(pos, check_season(season))
        return [] if c is None else [(cat, name) for cat, name, *_ in self._specs(c, season)]

    def _specs(self, c, season):
        """[(cat, name, size, seed, X, Y)] in hex-radius units, absolute."""
        pos = c.pos
        X, Y = hex_centre(pos)
        m = self._model(season)
        winter = season == "winter"
        out = []
        if not c.water:
            if not (c.built or c.ground == "good" or c.fields):
                self._relief(out, m, c, X, Y, winter)
            self._trees(out, m, c, winter)
            if c.fields:
                self._farm(out, m, c, X, Y)
        for name, size, dx, dy in self.life.get(pos, ()):
            out.append(("life", name, size, _h("lf", pos, name), X + dx, Y + dy))
        out = self._ridge_objects(c, season, out)
        if not c.water and c.desc is not None and c.desc.sea:           # no tree in the water the coast overlay draws
            wet = coast_water(c.desc)
            out = [o for o in out if o[0] != "tree"
                   or not in_water(wet, (o[4] - X) * wfctiles.R + wfctiles.CX, (o[5] - Y) * wfctiles.R + wfctiles.CY)]
        return out

    def _relief(self, out, m, c, X, Y, winter):
        pos = c.pos
        rng = random.Random(_h("relief", pos))
        if c.terrain in ("mountains", "snow"):
            alpine = c.ground in ("alpine", "snow") or c.alt >= ALPINE_ALT
            # about half the peaks there were, fewer and larger, so a range is calm rather than crowded
            if alpine:
                plan = [(-0.4, -0.18, "large"), (0.38, 0.2, "large")]
                names = ["snow_peak", "twin_peak", "snow_peak", "crag", "snow_peak"]
            elif c.alt > 0.36:
                plan = [(-0.34, -0.1, "large"), (0.4, 0.2, "medium")]
                names = ["twin_peak", "crag", "old_mountain", "snow_peak"]
            else:
                plan = [(0.0, 0.0, "large")]
                names = ["old_mountain", "crag", "foothills", "old_mountain"]
            if _blocked_tall(m, pos):
                plan = [(x, y + 0.2, "medium" if s == "large" else "small") for x, y, s in plan]
            for i, (dx, dy, size) in enumerate(plan):
                name = names[_h("pk", pos, i) % len(names)]
                if winter and name in ("old_mountain", "crag") and c.alt > 0.4:
                    name = "snow_peak"
                out.append(("peak", name, size, _h("pv", pos, i), X + dx + rng.uniform(-.08, .08),
                            Y + dy + rng.uniform(-.06, .06)))
        elif c.terrain == "hills":
            for i, (dx, dy) in enumerate([(-0.38, -0.1), (0.36, 0.18)]):
                name = ("hill_green", "hill_green", "hill_terraced", "hill_dry")[_h("hl", pos, i) % 4]
                out.append(("hill", name, "medium" if i == 0 else "small", _h("hv", pos, i),
                            X + dx + rng.uniform(-.06, .06), Y + dy + rng.uniform(-.05, .05)))

    def _trees(self, out, m, c, winter):
        """Trees on one global jittered lattice (step 0.33), so forests run on across hex borders."""
        step = 0.33
        pos = c.pos
        X, Y = hex_centre(pos)
        segs = _corridor_segs(m, pos)
        for gi in range(int(math.floor((X - APO) / step)) - 2, int(math.floor((X + APO) / step)) + 3):
            for gj in range(int(math.floor((Y - 1) / step)) - 2, int(math.floor((Y + 1) / step)) + 3):
                # the lattice point's jitter moves it by at most half a step: skip those that cannot reach this hex
                mx = abs((gi + 0.5 * (gj & 1) + 0.25) * step + 0.5 * step * 0.5 - X)
                my = abs((gj + 0.25) * step + 0.5 * step * 0.5 - Y)
                if mx > APO + 0.2 or my > 1.2 or my + mx / SQ3 > 1.3:
                    continue
                jx, jy = _u("jx", gi, gj), _u("jy", gi, gj)
                x = (gi + 0.5 * (gj & 1) + 0.25 + 0.5 * jx) * step
                y = (gj + 0.25 + 0.5 * jy) * step
                dx, dy = abs(x - X), abs(y - Y)                     # (x, y) lies in this hex (not a neighbour's)
                if dx > APO or dy > 1 or dy + dx / SQ3 > 1:
                    continue
                dens, kind = tree_density(m, c, x, y)
                if dens <= 0 or _u("keep", gi, gj) > dens:
                    continue
                if _near_corridor(segs, x, y, 0.14):
                    continue
                a = self._alt_at(x, y) if c.terrain in ("mountains", "snow", "hills", "forest") else 0.0
                if a > TREE_LINE:
                    continue
                name, size = tree_species(c, a, gi, gj, kind, winter)
                out.append(("tree", name, size, _h("tv", gi, gj), x, y))

    def _allowed(self, m, c, x, y):
        """Field systems may cover their own hex and open same-owner neighbours (plains or hills, no field)."""
        p = _hex_at(x, y)
        if p == c.pos:
            return True
        if p not in m.nbrs(c.pos):
            return False
        nb = m.cells.get(p)
        return (nb is not None and not nb.water and nb.ground in ("plains", "hills") and not nb.built
                and nb.owner == c.owner and not nb.fields)

    def _farm(self, out, m, c, X, Y):
        """Hedgerow trees and farm buildings of a natural field system (level c.fields)."""
        _, _, blob, trees = self._fields_of(c)
        for i, (x, y) in enumerate(trees):
            if not in_poly(x, y, blob, EPS) or not self._allowed(m, c, x, y):
                continue
            name = ("oak", "beech", "linden", "oak")[_h("hn", i, c.pos) % 4]
            out.append(("tree", name, ("small", "medium")[_h("hs", i, c.pos) % 2], _h("hv", i, c.pos), x, y + 0.02))
        if c.fields >= 1:
            out.append(("build", "haystack", "m", 0, X + 0.28, Y + 0.42))
        if c.fields >= 2:
            out.append(("build", "haystack", "m", 1, X - 0.36, Y + 0.30))
            out.append(("build", "farmhouse", "m", 0, X + 0.05, Y + 0.12))
        if c.fields >= 3:
            out.append(("build", "barn", "m", 0, X - 0.32, Y - 0.05))
        if c.fields >= 4:
            out.append(("build", "windmill", "m", c.variant, X + 0.42, Y - 0.12))

    # ----- ridge crests (see Ridges)
    def ridges(self):
        """The crest edges, passes and looks of this world (built on first use)."""
        if self._ridge is None:
            self._ridge = Ridges(self)
        return self._ridge

    def _draw_ridge(self, gs, fr, m, c, P):
        """Ground of a crest hex: the relief fold, the band, strata or scree, the crest strip, and the pass corridor and
        track (summer) or snow drift (winter). Drawn after the edge bands and before the wfc overlay."""
        ridges = self.ridges()
        edges = ridges.edges(c.pos)
        if not edges or c.water:
            return
        season = m.season
        winter = season == "winter"
        X, Y = hex_centre(c.pos)
        cx, cy = fr.px(X, Y)
        q = P / 68.0
        passes = ridges.passe.get(c.pos, {})
        near = list(neighbors(c.pos))
        crowd = _crowded(c)
        lay = pygame.Surface(gs.get_size(), pygame.SRCALPHA)

        def to_px(pts):
            return [(cx + x * P, cy + y * P) for x, y in pts]
        for e in sorted(edges):
            look = ridges.look_of(c.pos, e)
            if look is None:
                continue
            kind = look["kind"]
            (ax, ay), (bx, by) = edge_ends(e)
            nx, ny = edge_normal(e)
            prev_on, next_on = not ridges.chain_end(c.pos, e, 0), not ridges.chain_end(c.pos, e, 1)  # taper at chain ends
            seed = _h("rb", *sorted(frozenset((c.pos, near[e]))))
            depth = RIDGE_DEPTH[kind] * (0.45 if crowd else 1.0)
            lit_c, shade_c, top_c = ridge_palette(look, season)
            lit = max(0.0, min(1.0, 0.5 - 0.5 * (-nx * 0.7 - ny * 0.7)))
            band = mix(shade_c, lit_c, lit)
            foot = shade(band, -0.18)
            n = 24
            ends = [(ax + (bx - ax) * i / n, ay + (by - ay) * i / n) for i in range(n + 1)]
            taper = [min(1.0, (i / n / 0.3 if not prev_on else 1.0), ((1 - i / n) / 0.3 if not next_on else 1.0))
                     for i in range(n + 1)]
            inner, mid, snowline = [], [], []
            for i, ((ex, ey), tp) in enumerate(zip(ends, taper)):
                t = i / n
                d = depth * (1 + 0.22 * _wave(t, seed)) * (0.3 + 0.7 * tp)
                if e in passes:
                    d *= 1 - 0.8 * math.exp(-((t - 0.5) / 0.16) ** 2)
                inner.append((ex - nx * d, ey - ny * d))
                mid.append((ex - nx * d * 0.55, ey - ny * d * 0.55))
                snowline.append((ex - nx * d * 0.38, ey - ny * d * 0.38))
            outer = [(bx + nx * 0.04, by + ny * 0.04), (ax + nx * 0.04, ay + ny * 0.04)]
            # the relief fold: a soft wash over the slope, dark on the side away from the light, pale on the lit side,
            # fading into the hex (a little stronger on the low crests, so they stay readable as a natural border)
            reach, fold = RIDGE_WASH[kind], RIDGE_FOLD[kind]
            for k, a_ in ((1.0, 1.0), (0.66, 1.4), (0.36, 1.8)):
                wash = [(ex - nx * reach * k * (0.3 + 0.7 * tp), ey - ny * reach * k * (0.3 + 0.7 * tp))
                        for (ex, ey), tp in zip(ends, taper)]
                col = ((20, 24, 50, min(255, int(44 * a_ * fold * (1 - lit)))) if lit < 0.5
                       else (255, 252, 236, min(255, int(34 * a_ * fold * lit))))
                pygame.draw.polygon(lay, col, to_px(wash + outer))
            pygame.draw.polygon(lay, band + (235,), to_px(inner + outer))
            pygame.draw.polygon(lay, foot + (235,), to_px(inner + mid[::-1]))
            rng = random.Random(seed + e)
            if kind == "scarp":                                  # strata: lines along the scarp face
                for k in (0.3, 0.55, 0.78):
                    pts = [(ix + (ox_ - ix) * k, iy + (oy_ - iy) * k) for (ix, iy), (ox_, oy_) in
                           zip(inner, [(ex + nx * 0.02, ey + ny * 0.02) for ex, ey in ends])]
                    pygame.draw.lines(lay, shade(band, -0.25) + (255,), False, to_px(pts[3:-3]), max(1, round(q * 1.2)))
            elif kind in ("alpine", "rocky") and not (winter and look["snow_winter"]):
                for i in range(int(5 * depth / 0.2)):            # scree ticks falling away from the crest
                    t = rng.uniform(0.1, 0.9)
                    px_, py_ = mid[int(t * n)]
                    pygame.draw.line(lay, shade(band, -0.38) + (255,), (cx + px_ * P, cy + py_ * P),
                                     (cx + (px_ - nx * 0.05) * P, cy + (py_ - ny * 0.05) * P), max(1, round(q * 1.3)))
            if top_c is not None:                                # the crest strip: snow, a rock lip or a dark lip
                strip = snowline if kind == "alpine" else \
                    [(ex - (ex - ix) * 0.4, ey - (ey - iy) * 0.4) for (ix, iy), (ex, ey) in zip(inner, ends)]
                pygame.draw.polygon(lay, top_c + (255,), to_px(strip + outer))
            pygame.draw.lines(lay, shade(band, -0.42) + (255,), False, to_px(inner), max(1, round(q * 1.5)))
        gs.blit(lay, (0, 0))
        # pass hexes: a strip of pasture (dry: bare earth) with a winding track up into the saddle; winter: a drift
        for e in passes:
            look = ridges.look_of(c.pos, e)
            if look is None:
                continue
            if winter:
                _drift(gs, cx, cy, P, q, e)
                continue
            if crowd:
                continue
            self._pass_corridor(gs, cx, cy, P, c, e, look)
            if c.desc is not None and e in c.desc.road:
                continue                                         # the wfc road already runs through the pass
            nx, ny = edge_normal(e)
            tx, ty = -ny, nx
            mx, my = nx * APO, ny * APO
            pts = []
            for i in range(13):
                t = i / 12
                w = 0.12 * math.sin(t * math.pi * 2.2) * (1 - t * 0.6)
                pts.append((cx + (mx * (0.1 + 0.92 * t) + tx * w) * P, cy + (my * (0.1 + 0.92 * t) + ty * w) * P))
            pygame.draw.lines(gs, (92, 66, 44), False, pts, max(4, round(q * 7)))
            pygame.draw.lines(gs, (226, 196, 136), False, pts, max(2, round(q * 4.4)))

    def _pass_corridor(self, gs, cx, cy, P, c, e, look):
        nx, ny = edge_normal(e)
        tx, ty = -ny, nx
        left, right = [], []
        for i in range(11):
            t = i / 10
            w = 0.32 - 0.1 * t + 0.04 * math.sin(t * 7 + e)
            bx_, by_ = nx * APO * (-0.05 + 1.08 * t), ny * APO * (-0.05 + 1.08 * t)
            left.append((cx + (bx_ + tx * w) * P, cy + (by_ + ty * w) * P))
            right.append((cx + (bx_ - tx * w) * P, cy + (by_ - ty * w) * P))
        tw, th = gs.get_size()
        layer = pygame.Surface((tw, th), pygame.SRCALPHA)
        tex = self._scaled(self._ground_src("dirt" if look["dry"] else "montane", c.variant), P, 1.0)
        layer.blit(tex, (cx - tex.get_width() / 2, cy - tex.get_height() / 2))
        mk = clip_mask((tw, th))
        pygame.draw.polygon(mk, (255, 255, 255, 255), left + right[::-1])
        layer.blit(mk, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        gs.blit(layer, (0, 0))

    def _ridge_objects(self, c, season, out):
        """The hex's objects with the ridge applied: nothing tall on a pass saddle or track, the hex's own peaks give way
        on a crest, 1 to 3 crest objects per edge by its look, a hospice (and in winter a snowmark) at each pass."""
        ridges = self.ridges()
        if c.water:
            return out
        X, Y = hex_centre(c.pos)
        winter = season == "winter"
        edges = ridges.edges(c.pos)
        passes = ridges.passe.get(c.pos, {})
        if ridges.pass_mids:
            out = [o for o in out if not (o[0] in ("peak", "tree") and ridges.on_pass(c.pos, o[4], o[5]))]
        if not edges:
            return out
        crowd = _crowded(c)
        near = list(neighbors(c.pos))
        new = []
        for e in sorted(edges):
            look = ridges.look_of(c.pos, e)
            if look is None:
                continue
            nx, ny = edge_normal(e)
            # a crest is a ridge line, not a pile: the hex's own peaks stand back from it
            out = [o for o in out if not (o[0] == "peak" and APO - ((o[4] - X) * nx + (o[5] - Y) * ny) < 0.4)]
            if crowd or e in passes:
                continue
            (ax, ay), (bx, by) = edge_ends(e)
            key = frozenset((c.pos, near[e]))
            first = sorted(key)[0] == c.pos
            side_hash = _h("side", *sorted(key))
            kind = look["kind"]
            rng = random.Random(_h("crest", c.pos, e))

            def at(t, inset):
                return X + ax + (bx - ax) * t - nx * inset, Y + ay + (by - ay) * t - ny * inset

            if kind == "alpine":                                 # one snow peak per side, staggered: 2 per edge
                name = ("snow_peak", "twin_peak")[side_hash % 2] if look["alt"] > 0.75 else "snow_peak"
                size = "medium" if (side_hash >> 2) % 3 else "small"
                x, y = at(0.32 if first else 0.68, 0.22)
                if not ridges.on_pass(c.pos, x, y):
                    new.append(("peak", name, size, _h("cp", c.pos, e), x, y))
            elif kind == "rocky":                                # a crag on one side, a low foothill on the other
                mine = (side_hash % 2 == 0) == first
                if look["dry"]:
                    name = "old_mountain" if mine else "hill_dry"
                else:
                    name = ("crag", "old_mountain")[(side_hash >> 1) % 2] if mine else "foothills"
                if winter and look["snow_winter"] and name == "crag":
                    name = "old_mountain"
                x, y = at((0.38 if first else 0.62) + rng.uniform(-0.06, 0.06), 0.2)
                if not ridges.on_pass(c.pos, x, y):
                    new.append(("hill" if name.startswith("hill") else "peak", name, "small" if mine else "medium",
                                _h("cp", c.pos, e), x, y))
                if look["dry"]:
                    x, y = at(rng.uniform(0.15, 0.85), 0.36)
                    new.append(("tree", "shrub", "small", _h("sh", c.pos, e), x, y))
            elif kind == "forest":                               # a green hump on the line, conifers on its flanks
                x, y = at(0.36 if first else 0.64, 0.2)
                if not ridges.on_pass(c.pos, x, y):
                    new.append(("hill", "hill_green", "medium", _h("fh", c.pos, e), x, y))
                for i, t in enumerate((0.1, 0.62) if first else (0.38, 0.9)):
                    x, y = at(t + rng.uniform(-0.04, 0.04), 0.14)
                    if ridges.on_pass(c.pos, x, y):
                        continue
                    name = ("fir_tall", "pine_tall", "fir_short")[(side_hash + i) % 3]
                    if winter and look["snow_winter"]:
                        name = "snowy_tall" if "tall" in name else "snowy_short"
                    new.append(("tree", name, "medium", _h("ft", c.pos, e, i), x, y))
            elif kind == "scarp":                                # an outcrop on one side, a dry hill on the other
                mine = (side_hash % 2 == 0) == first
                x, y = at((0.38 if first else 0.62) + rng.uniform(-0.06, 0.06), 0.2)
                if mine:
                    new.append(("peak", ("outcrop", "mesa")[(side_hash >> 1) % 2], "small", _h("cp", c.pos, e), x, y))
                else:
                    new.append(("hill", "hill_dry", "small", _h("cp", c.pos, e), x, y))
        for e, name in sorted(passes.items()):
            nx, ny = edge_normal(e)
            across = self._cell(near[e], season)
            if (ridges.hospice.get(name) == (c.pos, e) and not crowd and not (across is not None and _crowded(across))):
                new.append(("build", "hospice", "m", 0, *hospice_spot(c.pos, e)))
            if winter and ridges.hospice.get(name, (None,))[0] == c.pos:
                new.append(("build", "snowmark", "m", 0, X + nx * 0.48 + ny * 0.22, Y + ny * 0.48 - nx * 0.22 + 0.05))
        if passes:                                               # the pass valley: a few trees beside the track
            out = [o for o in out if o[0] != "tree"]
            e = sorted(passes)[0]
            look = ridges.look_of(c.pos, e)
            if look and not winter and not crowd and not look["dry"]:
                nx, ny = edge_normal(e)
                for j, (u, v) in enumerate(((0.25, 0.3), (0.45, -0.28), (0.65, 0.34))):
                    x, y = X - nx * (u - 0.1) - ny * v, Y - ny * (u - 0.1) + nx * v
                    if not ridges.on_pass(c.pos, x, y):          # (another pass's track may run here)
                        new.append(("tree", ("fir_short", "pine_short", "fir_tall")[j], "small", _h("pt", c.pos, j),
                                    x, y))
        return out + new

    # ----- inspection
    def cell_info(self, pos, season):
        """The derived state of one hex for a season (for tests and debugging); None off the map."""
        c = self._cell(pos, check_season(season))
        if c is None:
            return None
        return {"terrain": c.terrain, "ground": c.ground, "alt": c.alt, "good": c.good, "works": c.works,
                "fields": c.fields, "clearing": c.clearing, "built": c.built, "water": c.water,
                "owner": c.owner}


def _sprite_key(cat, name, size, seed, r):
    """(cache key, scaled radius, flip) of an object sprite, as obj_sprite() keys it."""
    rs = r * PIECE_SCALE.get(name, 1.0)
    flip = (seed >> 7) & 1 == 1 and cat in ("tree", "peak", "hill", "life")
    return (name, size, seed % 4, cat, rs, flip), rs, flip


def _blocked_tall(m, pos):
    """True if a neighbour is built, a goods tile or a field system: no tall objects stand in front of it."""
    for n in neighbors(pos):
        nb = m.cells.get(n)
        if nb is not None and (nb.built or nb.ground == "good" or nb.fields):
            return True
    return False


def _base_name(c):
    if c.water:
        if c.terrain == "lake":
            return "Terrain/Grass/lake.png"
        return ("sea", "sea", c.variant)
    if c.landmark:
        return ("city", c.landmark, 2)
    if c.ground == "good":
        return ("good", c.good, min(5, c.works), c.variant)
    sprites, tint_, _ = GROUND[c.ground]
    name = sprites[c.variant % len(sprites)]
    return ("tint", name, tint_) if tint_ else name


def band_edges(m, c):
    """[(edge, neighbour cell)] that put a band on cell c, lowest priority first."""
    if c.water or c.landmark:
        return []
    out = []
    pa = GROUND[c.ground][2]
    for e, n in enumerate(m.nbrs(c.pos)):
        nb = m.cells.get(n)
        if nb is None or nb.water or nb.landmark or nb.ground == c.ground:
            continue
        if GROUND[nb.ground][2] > pa:
            out.append((e, nb))
    out.sort(key=lambda t: GROUND[t[1].ground][2])
    return out


def _corridor_segs(m, pos):
    """Road and river corridors of a hex and its neighbours: trees keep off them."""
    segs = []
    for p in [pos] + m.nbrs(pos):
        c = m.cells.get(p)
        if c is None or c.desc is None:
            continue
        X, Y = hex_centre(p)
        for e in set(c.desc.road) | set(c.desc.river):
            nx, ny = edge_normal(e)
            segs.append(((X, Y), (X + nx * APO * 1.02, Y + ny * APO * 1.02)))
    return segs


def _near_corridor(segs, x, y, d):
    for a, b in segs:
        if abs(a[0] - x) > 1.2 or abs(a[1] - y) > 1.2:
            continue
        if _seg_dist((x, y), a, b) < d:
            return True
    return False
