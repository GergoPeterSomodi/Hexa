"""Landscape art for the campaign map: baked ground composites, object lists and closed-pass markers.

Ported from the approved map look in the tile-design mockup (mockups/tile-designs/final/final.py), decoupled from its
fixed Italy box and its Map class, so it works for any CampaignWorld (the Europe map or a random world).

Layers, per land hex (drawn back to front by the caller):
  ground(pos, r, season, build=True)
                           one hex-sized RGBA composite: base picture (Kenney terrain, goods tile, sea), ground
                           detail, wavy edge bands between ground kinds, forest clearings and natural field systems,
                           the wfctiles overlay (coasts, rivers, roads, towns, castles) and the hatch of a closed
                           pass. Cached in an LRU. build=False returns None instead of building a missing one.
  grid(r)                  the faint hex outline at hex radius r, the size of ground(); drawn separately (G key).
  objects(pos, r, season)  [(surface, dx, dy, sort_y)] peaks, hills, trees, farm buildings and closed-pass markers of
                           one hex. dx, dy are pixel offsets of the surface's base point (bottom centre) from the hex
                           centre. Back-to-front order: sort by centre_y + sort_y, where sort_y == dy for ordinary
                           objects and MARKER_SORT for closed-pass markers (they draw over everything). Objects may
                           extend outside their hex.
  closed_pass(pos, season) True for a mountain pass that the world's rule closes in this season (world.pass_closed).
  closed_marker(r)         the red CLOSED chip used on closed passes.

Composites are built at 2x and smooth-scaled down. Season is "winter" when world.turn % 4 == 0 (see season_now).
"""
import math
import os
import random
import zlib
from collections import OrderedDict
from dataclasses import dataclass

import pygame

from ..hexgrid import neighbors
from . import art, geo, goodsart, landmarks, life, nature, wfctiles
from .art import shade

SQ3 = math.sqrt(3)
APO = SQ3 / 2                       # centre to edge midpoint, in hex radii
SPRITE_H = 70 / (60 / SQ3)          # the game's sprite height in hex radii (mapview.SPRITE_H)
OBJ_R = 69.3                        # the hex radius the object libraries are drawn for
K = 2                               # supersampling of composites
INK = (36, 38, 44)
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
MARKER_SCALE = {"barrier": 2.0, "pass_badge": 2.3}
BASE_GROW = 1.08                   # the base picture is drawn this much larger than its hex (see _build_ground)
MARKER_SORT = 1e9                   # closed-pass markers sort after every other object
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


_COAST_WATER = {}


def coast_water(desc):
    """The water of a land hex's coast overlay as a mask at 2x tile resolution (cached): what in_water tests."""
    key = (desc.sea, desc.variant, bool(desc.town))
    mask = _COAST_WATER.get(key)
    if mask is None:
        if len(_COAST_WATER) > 600:
            _COAST_WATER.clear()
        geo = wfctiles._coast_geo(desc.sea, desc.variant, wfctiles.COAST_RD - 8 if desc.town else wfctiles.COAST_RD)
        mask = _COAST_WATER[key] = pygame.mask.from_surface(geo["water"], 8)
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


def _in_poly(x, y, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            inside = not inside
        j = i
    return inside


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
_OB = {}
_PIECE = {}
# farm buildings and markers made with the game's own goodsart pens (drawn at 2x, base point = bottom centre)
PIECES = {"barn": (44, 36), "windmill": (56, 62), "farmhouse": (40, 34), "stump": (10, 6), "haystack": (14, 12),
          "barrier": (40, 22), "pass_badge": (30, 34)}


def _piece(name, seed):
    key = (name, seed)
    if key in _PIECE:
        return _PIECE[key]
    w, h = PIECES[name]
    K2 = goodsart.K
    surf = pygame.Surface((w * K2, h * K2), pygame.SRCALPHA)
    p = goodsart.Pen(surf)
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
    elif name == "barrier":
        for px_ in (x - 15, x + 15):
            p.rect(INK, px_ - 1.8, y - 14, 3.6, 14)
            p.rect((120, 84, 56), px_ - 1, y - 13.2, 2, 12.4)
        p.rect(INK, x - 18, y - 13, 36, 6.4)
        for i in range(6):
            p.rect((214, 48, 44) if i % 2 == 0 else (250, 250, 246), x - 17.2 + i * 5.73, y - 12.2, 5.73, 4.8)
    elif name == "pass_badge":
        p.poly(INK, [(x - 1.6, y), (x + 1.6, y), (x + 1.6, y - 14), (x - 1.6, y - 14)])
        p.circle(INK, (x, y - 21), 11.4)
        p.circle((214, 48, 44), (x, y - 21), 10.2)
        p.circle((250, 250, 246), (x, y - 21), 7.6)
        for k in range(3):
            a = math.radians(90 + 60 * k)
            dx, dy = math.cos(a) * 6.0, math.sin(a) * 6.0
            p.line((60, 120, 200), (x - dx, y - 21 - dy), (x + dx, y - 21 + dy), 1.7)
            for s in (-1, 1):
                bx, by = x + s * dx * 0.62, y - 21 + s * dy * 0.62
                a2 = math.radians(90 + 60 * k + 40)
                p.line((60, 120, 200), (bx, by), (bx + math.cos(a2) * 2.2 * s, by + math.sin(a2) * 2.2 * s), 1.1)
        p.circle((60, 120, 200), (x, y - 21), 1.6)
    res = (surf, w, h)
    _PIECE[key] = res
    return res


def obj_sprite(name, size, seed, cat, r, flip=False):
    """An object at hex radius r. cat picks the OSCALE family. Base point = bottom centre. Cached."""
    key = (name, size, seed % 4, cat, r, flip)
    if key in _OB:
        return _OB[key]
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
    _OB[key] = img
    return img


# ----------------------------------------------------------------------------------------------- hatch and clearings
_HATCH = {}
_BLOBS = {}


def hatch_tile(P):
    """The winter impassable hatch: diagonal ink lines inside a hex, tinted slate."""
    if P in _HATCH:
        return _HATCH[P]
    w, h = int(P * SQ3) + 2, int(2 * P) + 2
    s = pygame.Surface((w, h), pygame.SRCALPHA)
    step = max(4, int(P * 0.22))
    for k in range(-h, w + h, step):
        pygame.draw.line(s, (54, 66, 96, 92), (k, 0), (k + h * 0.6, h), max(2, int(P * 0.06)))
    mk = clip_mask((w, h))
    pygame.draw.polygon(mk, (255, 255, 255, 255), hex_poly(w / 2, h / 2, P * 0.98))
    s.blit(mk, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    tint_ = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.polygon(tint_, (40, 52, 84, 46), hex_poly(w / 2, h / 2, P * 0.98))
    tint_.blit(s, (0, 0))
    _HATCH[P] = tint_
    return tint_


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
    if key not in _BLOBS:
        _BLOBS[key] = clearing_blob(c)
    return _BLOBS[key]


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
        if not _in_poly(sx, sy, blob) or len(poly) < 3:
            continue
        crop = CROPS[_h("crop", c.pos, i) % len(CROPS)]
        fields.append((poly, crop, _u("ang", c.pos, i) * 3.14, i))
        for k in range(len(poly)):
            a, b = poly[k], poly[(k + 1) % len(poly)]
            mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            if _u("hedge", c.pos, round(mid[0], 2), round(mid[1], 2)) < 0.62 + 0.06 * lvl and _in_poly(*mid, blob):
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
            if _in_poly(x, y, _blob_cached(t)):
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
    closed: bool = False               # winter: closed pass
    impassable: bool = False           # winter: no crossing (hatched)
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


def _lru_get(cache, key):
    hit = cache.get(key)
    if hit is not None:
        cache.move_to_end(key)
    return hit


def _lru_put(cache, key, value, cap):
    cache[key] = value
    if len(cache) > cap:
        cache.popitem(last=False)
    return value


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
        self._grounds = OrderedDict()
        self._grid = {}
        self._gquick = {}                   # (pos, r, season) -> (world version, composite key): skips the key work
        self.builds = 0                     # ground composites built so far (MapView budgets them per frame)
        self.object_builds = 0              # object lists built so far (budgeted the same way)
        self.sprite_builds = 0              # object sprites made so far (make_sprites; budgeted the same way)
        self.overlay_builds = 0             # hexes whose wfc overlay / base picture was made by prepare()
        self._objs = OrderedDict()
        self._specs_cache = {}
        self._field_geo = {}
        self._chips = {}
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
        if self.world.pass_closed(pos, season == "winter"):
            c.closed = c.impassable = True          # only closed passes get the hatch, barrier and CLOSED chip
        return c

    def _desc(self, pos, prov, variant, nbrs):
        """The wfctiles TileDesc of what lies on top of a land hex (as MapView.overlay_desc builds it)."""
        sea = frozenset(e for e, n in enumerate(nbrs) if self.world.terrain.get(n) == "ocean")
        river = frozenset(self._rivers.get(pos, ()))
        road = frozenset(self._roads.get(pos, ()))
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
            img = _lru_get(self._grounds, key)
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
                   c.impassable, c.landmark, c.owner, c.built, c.water,
                   tuple(self._nbr_sig(model, n) for n in nbrs))
            self._gquick[quick] = (self._version, key)
            hit = _lru_get(self._grounds, key)
            if hit is not None:
                return hit
            if not build:
                return None
        self.builds += 1
        return _lru_put(self._grounds, key, self._build_ground(model, c, r), GROUND_CACHE)

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
        if c.clearing:
            self._draw_clearing(gs, fr, c, P)
        if c.fields:
            self._paint_fields(gs, fr, c, P)
        if c.desc is not None and not c.landmark:
            ov = self._scaled(("wfc", c.desc), P)
            gs.blit(ov, (cx - ov.get_width() / 2, cy - ov.get_height() / 2))
        if c.impassable:
            hatch = hatch_tile(P)
            gs.blit(hatch, (cx - hatch.get_width() / 2, cy - hatch.get_height() / 2))
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
        hit = _lru_get(self._objs, key)
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
                if cat == "chip":
                    surf = self.closed_marker(r)
                    dy = 0.3 * r + surf.get_height() - 1
                    out.append((surf, 0.0, dy, MARKER_SORT))
                    continue
                _, rs, flip = _sprite_key(cat, name, size, seed, r)
                surf = obj_sprite(name, size, seed, cat, rs, flip)
                out.append((surf, dx, dy, MARKER_SORT if name in MARKER_SCALE else dy))
            out.sort(key=lambda o: o[3])
        return _lru_put(self._objs, key, out, OBJECT_CACHE)

    def make_sprites(self, pos, r, season):
        """Makes the object sprites of one hex that do not exist yet (the first use of a sprite is the costly part of
        objects()). Returns how many were made; objects() then only assembles the list. Counted in sprite_builds."""
        c = self._cell(pos, check_season(season))
        if c is None:
            return 0
        n = 0
        for cat, name, size, seed, x, y in self._specs_of(c, season):
            if cat == "chip":
                if r not in self._chips:
                    self.closed_marker(r)
                    n += 1
                continue
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
            if c.desc is not None and c.desc.sea:               # no tree in the water the coast overlay draws
                wet = coast_water(c.desc)
                out = [o for o in out if o[0] != "tree"
                       or not in_water(wet, (o[4] - X) * wfctiles.R + wfctiles.CX, (o[5] - Y) * wfctiles.R + wfctiles.CY)]
        if c.closed:
            out.append(("build", "barrier", "m", 0, X, Y + 0.22))
            out.append(("build", "pass_badge", "m", 0, X + 0.02, Y - 0.12))
            out.append(("chip", "closed_chip", "m", 0, X, Y))
        for name, size, dx, dy in self.life.get(pos, ()):
            out.append(("life", name, size, _h("lf", pos, name), X + dx, Y + dy))
        return out

    def _relief(self, out, m, c, X, Y, winter):
        pos = c.pos
        rng = random.Random(_h("relief", pos))
        if c.terrain in ("mountains", "snow"):
            alpine = c.ground in ("alpine", "snow") or c.alt >= ALPINE_ALT
            if alpine:
                plan = [(-0.45, -0.22, "large"), (0.42, -0.12, "large"), (-0.1, 0.36, "medium"), (0.5, 0.52, "small")]
                names = ["snow_peak", "twin_peak", "snow_peak", "crag", "snow_peak"]
            elif c.alt > 0.36:
                plan = [(-0.36, -0.12, "large"), (0.42, 0.02, "medium"), (-0.05, 0.40, "medium")]
                names = ["twin_peak", "crag", "old_mountain", "snow_peak"]
            else:
                plan = [(-0.3, -0.05, "medium"), (0.38, 0.12, "medium"), (0.0, 0.5, "small")]
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
            if not _in_poly(x, y, blob) or not self._allowed(m, c, x, y):
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

    # ----- closed passes
    def closed_pass(self, pos, season):
        """True for a mountain pass that the world's rule closes in this season (the same rule as movement)."""
        check_season(season)
        return self.world.pass_closed(pos, season == "winter")

    def closed_marker(self, r):
        """The red CLOSED chip drawn on closed passes, at hex radius r (cached)."""
        if r not in self._chips:
            font = pygame.font.SysFont("segoeui,arial", max(9, r // 4), bold=True)
            lab = font.render("CLOSED", True, (255, 255, 255))
            box = pygame.Rect(0, 0, lab.get_width() + 8, lab.get_height() + 2)
            surf = pygame.Surface(box.size, pygame.SRCALPHA)
            pygame.draw.rect(surf, (190, 40, 38), surf.get_rect(), border_radius=3)
            pygame.draw.rect(surf, (90, 16, 16), surf.get_rect(), 1, border_radius=3)
            surf.blit(lab, (4, 1))
            self._chips[r] = surf
        return self._chips[r]

    # ----- inspection
    def cell_info(self, pos, season):
        """The derived state of one hex for a season (for tests and debugging); None off the map."""
        c = self._cell(pos, check_season(season))
        if c is None:
            return None
        return {"terrain": c.terrain, "ground": c.ground, "alt": c.alt, "good": c.good, "works": c.works,
                "fields": c.fields, "clearing": c.clearing, "built": c.built, "water": c.water,
                "impassable": c.impassable, "closed": c.closed, "owner": c.owner}


def _sprite_key(cat, name, size, seed, r):
    """(cache key, scaled radius, flip) of an object sprite, as obj_sprite() keys it."""
    rs = r * MARKER_SCALE.get(name, 1.0)
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
