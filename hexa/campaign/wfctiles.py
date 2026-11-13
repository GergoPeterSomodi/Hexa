"""Edge-socket tiles for wave function collapse: coasts, rivers, roads, town walls, castles and settlements.

Every tile is described by a small hashable `TileDesc` (base terrain + which edges carry sea, river, road, wall ...)
and drawn procedurally from that edge mask in the goodsart style (flat two-tone, ink outlines, drawn at 2x and
smooth-scaled, 120 x 140 pointy-top hexes). Because every feature crosses an edge at a fixed, mirrored place and
leaves it at a right angle, any two tiles whose sockets match join without a seam.

EDGE ORDER
    Edge e (0..5) is the edge towards the e-th position yielded by `hexgrid.neighbors(pos)`:
    0 = E, 1 = NE, 2 = NW, 3 = W, 4 = SW, 5 = SE (screen y grows downwards). The outward normal of edge e points
    at screen angle -60*e degrees, so its midpoint is CENTRE + A*(cos, sin)(-60e) with A = R*sqrt(3)/2 = 60.
    The edge seen from the neighbour across it is (e + 3) % 6.
    Corner c (0..5) sits between edges c and c+1 at screen angle -60c - 30.
    Drawing code that walks `hex_pts` / mapview's `hex_points` (corner i at angle 60i - 30, "drawing edge" i from
    corner i to corner i+1, midpoint angle 60i) relates to these by
        drawing_edge = (6 - e) % 6      and back      e = (6 - drawing_edge) % 6
    which is exactly mapview's `near[(6 - edge) % 6]`; `draw_edge(e)` returns it, and our corner c is hex_pts
    index (6 - c) % 6.

SOCKETS (see `edge_sockets` / `compatible`)
    Each edge gets one string "coast|line|wall":
      coast  "S"   the whole edge is water (sea tile, or a land tile's sea edge);
             "L"   land; flags "-" / "+" mean the shoreline crosses this edge near corner c(e-1) / c(e), i.e. the
                   neighbouring edge e-1 / e+1 of this tile is a sea edge ("L-", "L+", "L-+").
      line   ""    nothing, "r" river, "d" dirt road, "p" paved road (they always cross the edge midpoint at a
                   right angle; a river and a road never share an edge, a bridge has them on different edges).
      wall   ""    no town wall; "T" the edge lies inside a walled town that spans both hexes, with the same "-"/"+"
                   flags marking where the wall crosses the edge near a corner.
    Across an edge corner c(e) of one tile is corner c(e+2) = "c(e'-1)" of the neighbour (e' = e+3), so flags
    MIRROR: "L+" fits "L-", "L-+" fits "L-+", "L" fits "L"; the line part must be equal; the wall part mirrors
    like the coast part.

GENERATION (`generate_patch`)
    1. Land and sea: a socket-aware wave function collapse (`socket_collapse`) over 65 tiles (open sea plus a land
       tile for each of the 64 sea-edge masks) with a prior from a smooth random field (sea on one side, bays and a
       peninsula). Edge sockets force every coast tile to agree with its neighbours.
    2. Base terrain: `wfc.collapse` (the game's own WFC) with forbidden pairs, weighted by distance to the sea.
    3. Rivers and roads are long-range, so they are laid as paths (Dijkstra) first: rivers run downhill from hills to
       the first coast tile (mouth) or into an earlier river (confluence) or a lake; roads join a walled city, a
       harbour, villages and a castle and may not use a river edge (so every crossing becomes a bridge or ford).
    4. Every cell becomes a TileDesc whose sockets are derived from its masks; `check_patch` verifies that every
       pair of neighbours is compatible and every river ends at a spring, a lake or the sea.

Overlays are transparent and meant to be drawn over any base tile (Kenney grass / forest / desert, or a goodsart
tile). Results are cached by their arguments; scale per zoom in the caller.
"""
import heapq
import math
import random
import zlib
from collections import namedtuple
from dataclasses import dataclass

import pygame

from hexa import hexgrid
from hexa.campaign import wfc
from hexa.campaign.art import hex_pts, shade
from hexa.campaign.render.cache import BoundedCache
from hexa.campaign.goodsart import (CREAM, DARK, DWOOD, INK, ROOF_RED, ROOF_SLATE, STONE, THATCH, WATER, WATER_L, WHITE,
                                    WOOD, boat, building, flag, mound, tower)
from hexa.campaign.render.draw import OFFS, OFFS_THIN, Pen, hex_mask, lerp, mix, shadow_at

W, H = 120, 140
CX, CY = W / 2, H / 2
R = 69.3                                   # centre to corner
A = R * math.sqrt(3) / 2                   # centre to edge midpoint (60)
K = 2                                      # supersampling factor

SAND = (232, 214, 160)
SURF = mix(WATER, WATER_L, 0.6)
RIVER_EDGE = (40, 100, 160)
FLARE = 3.6                                # mouth width / river width
RW = 8.0                                   # river width where it crosses an edge
ROAD_W = {"dirt": 5.0, "paved": 6.0}
ROAD_COL = {"dirt": ((120, 85, 50), (192, 152, 98), (172, 132, 82)),
            "paved": ((92, 92, 100), (182, 178, 166), (150, 146, 136))}
COAST_RD = 33.0                            # shoreline radius at the middle of a sea edge
COAST_F = 0.32                             # shoreline crosses a land edge this fraction of a side from the corner
WALL_RD = 40.0
WALL_F = 0.18
MASK_R = R + 1.0                           # tiles overlap their neighbours by ~1 px (no hairline seams)
GRASS = (39, 174, 96)                      # the Kenney pack's grass
ALL = frozenset(range(6))

BASE_SPRITES = {"plains": "Grass/grass_05", "forest": "Grass/grass_12", "hills": "Grass/grass_15",
                "desert": "Sand/sand_07", "mountains": "Stone/stone_07", "marsh": "Grass/grass_05",
                "lake": "Grass/grass_05"}
BASE_COLOURS = {"plains": GRASS, "forest": (22, 131, 68), "hills": (120, 170, 100), "desert": (236, 220, 184),
                "mountains": (164, 175, 175), "marsh": (70, 150, 110), "lake": GRASS}
SEA_BASES = ("sea", "shallow", "reef")


# ===================================================================================================
# geometry
# ===================================================================================================
def _dir(deg):
    a = math.radians(deg)
    return math.cos(a), math.sin(a)


def normal(e):
    """Outward unit normal of edge e (neighbors() order)."""
    return _dir(-60 * e)


def edge_mid(e, r=A):
    nx, ny = normal(e)
    return CX + nx * r, CY + ny * r


def corner(c, r=R):
    """Corner between edges c and c+1."""
    x, y = _dir(-60 * c - 30)
    return CX + x * r, CY + y * r


def draw_edge(e):
    """Index of edge e in hex_pts / hex_points drawing order (between corners i and i+1)."""
    return (6 - e) % 6


def opposite(e):
    return (e + 3) % 6


def _polar(th, r):
    x, y = _dir(th)
    return CX + x * r, CY + y * r


def _add(a, b, k=1.0):
    return a[0] + b[0] * k, a[1] + b[1] * k


def _sub(a, b):
    return a[0] - b[0], a[1] - b[1]


def _len(v):
    return math.hypot(v[0], v[1])


def _unit(v):
    d = _len(v) or 1.0
    return v[0] / d, v[1] / d


def _dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _near_corner(e, c, f):
    """Point on edge e at f * side from its corner c (c is e or e - 1)."""
    other = (e - 1) % 6 if c % 6 == e else e
    return lerp(corner(c), corner(other), f)


_SQ3 = math.sqrt(3)


def _inside(x, y, r=R - 12):
    dx, dy = abs(x - CX), abs(y - CY)
    a = r * _SQ3 / 2
    return dy <= r and dx <= a and dx * 0.5 + dy * _SQ3 / 2 <= a


def _chaikin(pts, n=3, closed=False):
    for _ in range(n):
        out = [] if closed else [pts[0]]
        m = len(pts) if closed else len(pts) - 1
        for i in range(m):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append(lerp(a, b, 0.25))
            out.append(lerp(a, b, 0.75))
        if not closed:
            out.append(pts[-1])
        pts = out
    return pts


def _bez(p0, p1, p2, p3, n=12):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def _seg_x(p, q, r, s):
    d1, d2 = _sub(q, p), _sub(s, r)
    den = d1[0] * d2[1] - d1[1] * d2[0]
    if abs(den) < 1e-9:
        return None
    w = _sub(r, p)
    t = (w[0] * d2[1] - w[1] * d2[0]) / den
    u = (w[0] * d1[1] - w[1] * d1[0]) / den
    if 0 <= t <= 1 and 0 <= u <= 1:
        return (p[0] + d1[0] * t, p[1] + d1[1] * t), t
    return None


def _crossings(pa, pb):
    """Points where polylines pa and pb cross: [(point, index in pa, unit direction of pa there)]."""
    out = []
    boxes = [(min(p[0], q[0]), max(p[0], q[0]), min(p[1], q[1]), max(p[1], q[1])) for p, q in zip(pb, pb[1:])]
    for i in range(len(pa) - 1):
        p, q = pa[i], pa[i + 1]
        x0, x1, y0, y1 = min(p[0], q[0]), max(p[0], q[0]), min(p[1], q[1]), max(p[1], q[1])
        for j, (bx0, bx1, by0, by1) in enumerate(boxes):
            if bx1 < x0 or bx0 > x1 or by1 < y0 or by0 > y1:
                continue
            x = _seg_x(p, q, pb[j], pb[j + 1])
            if x and all(_dist(x[0], o[0]) > 6 for o in out):
                out.append((x[0], i, _unit(_sub(q, p))))
    return out


def _runs(mask):
    """Maximal cyclic runs (start edge, length) of consecutive edges in mask (1..5 edges)."""
    runs = []
    for e in range(6):
        if e in mask and (e - 1) % 6 not in mask:
            n = 0
            while (e + n) % 6 in mask and n < 6:
                n += 1
            runs.append((e, n))
    return runs


Curve = namedtuple("Curve", "pts closed outer towers")


def _boundary(mask, rd, f, rng, wob=0.0, corner_k=1.1, iters=3, ext=7.0, h=9.0):
    """Boundary of the region that fills the outer part of the sectors of the `mask` edges.

    For a run of filled edges a..b the curve enters on land edge a-1 at f * side from corner c(a-1), leaves on land edge
    b+1 at f * side from corner c(b) - both at a right angle to the edge - and swings round the run at radius `rd`.
    The crossing points depend only on which neighbouring edges are filled, so two tiles agree on them."""
    out = []
    if not mask:
        return out
    if len(mask) == 6:
        ctrl = [_polar(-30 * i, rd * (corner_k if i % 2 else 1) + rng.uniform(-wob, wob)) for i in range(12)]
        pts = _chaikin(_wiggle(ctrl, rng, wob, True), iters, True) if iters else ctrl
        out.append(Curve(pts, True, None, ctrl[1::2]))
        return out
    for a, n in _runs(mask):
        b = (a + n - 1) % 6
        pe, qe = (a - 1) % 6, (b + 1) % 6
        P, Q = _near_corner(pe, pe, f), _near_corner(qe, b, f)
        nP, nQ = normal(pe), normal(qe)
        th0 = -60 * a + 30
        ctrl = []
        for k in range(1, 2 * n):
            r = rd * (1 if k % 2 else corner_k) + rng.uniform(-wob, wob)
            ctrl.append(_polar(th0 - 30 * k, r))
        mid = _wiggle(ctrl, rng, wob) if iters else ctrl
        raw = [_add(P, nP, ext), P, _add(P, nP, -h)] + mid + [_add(Q, nQ, -h), Q, _add(Q, nQ, ext)]
        pts = _chaikin(raw, iters) if iters else raw
        outer = [corner(b - i, R + 14) for i in range(n + 1)]
        towers = ctrl[1::2] if n > 1 else ctrl
        out.append(Curve(pts, False, outer, towers))
    return out


def _wiggle(ctrl, rng, wob, closed=False):
    """Insert a jittered point between neighbouring control points (radially, about the centre)."""
    if not wob or len(ctrl) < 2:
        return ctrl
    out = []
    m = len(ctrl) if closed else len(ctrl) - 1
    for i in range(m):
        a, b = ctrl[i], ctrl[(i + 1) % len(ctrl)]
        out.append(a)
        q = lerp(a, b, 0.5)
        v = _sub(q, (CX, CY))
        out.append(_add(q, _unit(v), rng.uniform(-wob, wob) * 1.3))
    if not closed:
        out.append(ctrl[-1])
    return out


def _fill_layer(curves, color):
    s = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
    p = Pen(s)
    for c in curves:
        if c.closed:
            p.poly(color, hex_pts(R + 14))
            p.poly((0, 0, 0, 0), c.pts)
        else:
            p.poly(color, c.pts + c.outer)
    return s


def _covers(surf, x, y):
    xi, yi = int(x * K), int(y * K)
    if 0 <= xi < W * K and 0 <= yi < H * K:
        return surf.get_at((xi, yi)).a > 0
    return False


def _band(p, c, pts, w, closed=False):
    if len(pts) < 2:
        return
    p.lines(c, pts, w, closed)
    for x, y in pts:
        p.circle(c, (x, y), w / 2 - 0.2)


def _rng(*key):
    return random.Random(zlib.crc32(repr(key).encode()))


def _fs(edges):
    return frozenset(int(e) % 6 for e in (edges or ()))


# ===================================================================================================
# tile descriptions and sockets
# ===================================================================================================
@dataclass(frozen=True)
class TileDesc:
    """What one hex shows. Edge sets use neighbors() order.

    base      plains / forest / hills / desert / mountains / marsh (land, drawn from the Kenney pack) or
              sea / shallow / reef (full water tiles drawn here)
    sea       land tile: edges whose sector holds sea (coast)
    river     edges a river crosses; 1 edge = spring unless mouth / lake; 3 = confluence
    mouth     the river ends in this tile's sea (needs `sea`); lake: the river(s) end in a lake here
    road      edges a road crosses; `paved` is the subset drawn as paved road (socket "p" instead of "d")
    crossing  where a road crosses the river: bridge / ford / ferry
    town      settlement level 0..6 (1 hamlet, 2 village, 3 market town, 4 walled town, 5 city, 6 great city);
              with sea edges it gets a harbour
    town_in   edges to other hexes of the same walled town (the wall runs round the group)
    castle    0..3 (motte, stone castle, fortress)
    wall      0..3 stand-alone town wall level (palisade / stone / star fort) - towns >= 4 imply one
    good      optional (good, level) goodsart tile as the base picture
    variant   0..n layout variant"""
    base: str = "plains"
    sea: frozenset = frozenset()
    river: frozenset = frozenset()
    mouth: bool = False
    lake: bool = False
    road: frozenset = frozenset()
    paved: frozenset = frozenset()
    crossing: str = "bridge"
    town: int = 0
    town_in: frozenset = frozenset()
    castle: int = 0
    wall: int = 0
    good: tuple = None
    variant: int = 0


def tile(base="plains", **kw):
    """TileDesc with edge collections normalised to frozensets (accepts lists / tuples)."""
    for k in ("sea", "river", "road", "paved", "town_in"):
        if k in kw:
            kw[k] = _fs(kw[k])
    if "paved" in kw:
        kw["road"] = kw.get("road", frozenset()) | kw["paved"]
    return TileDesc(base=base, **kw)


def wall_level(desc):
    if desc.wall:
        return desc.wall
    if desc.castle == 3:
        return 3                                   # the fortress has an outer star ring
    return {4: 2, 5: 2, 6: 3}.get(desc.town, 0)


def _flags(e, mask):
    return ("-" if (e - 1) % 6 in mask else "") + ("+" if (e + 1) % 6 in mask else "")


def edge_sockets(desc):
    """The 6 edge sockets of a tile, "coast|line|wall" each (see module doc)."""
    out = []
    walled = wall_level(desc) > 0
    for e in range(6):
        if desc.base in SEA_BASES or e in desc.sea:
            coast = "S"
        else:
            coast = "L" + _flags(e, desc.sea)
        line = "r" if e in desc.river else "p" if e in desc.paved else "d" if e in desc.road else ""
        wall = ""
        if walled and e in desc.town_in:
            outside = ALL - desc.town_in
            wall = "T" + _flags(e, outside)
        out.append(f"{coast}|{line}|{wall}")
    return tuple(out)


def _mirror(part):
    if not part or part[0] not in "LT":
        return part
    return part[0] + ("-" if "+" in part else "") + ("+" if "-" in part else "")


def compatible(a, b):
    """Whether socket a (edge e of one tile) may face socket b (edge e+3 of the neighbour)."""
    ca, la, wa = a.split("|")
    cb, lb, wb = b.split("|")
    return _mirror(ca) == cb and la == lb and _mirror(wa) == wb


def check_patch(patch, wrap_ok=False):
    """Problems in a {pos: TileDesc} map: socket mismatches, rivers / roads running off the patch, rivers that end
    anywhere but a spring, a lake or the sea. Returns a list of strings (empty = fine)."""
    problems = []
    socks = {p: edge_sockets(d) for p, d in patch.items()}
    for p, d in patch.items():
        near = list(hexgrid.neighbors(p))
        for e in range(6):
            q = near[e]
            s = socks[p][e]
            if q not in patch:
                if s.split("|")[1] and not wrap_ok:
                    problems.append(f"{p} edge {e}: {s} runs off the patch")
                continue
            if not compatible(s, socks[q][(e + 3) % 6]):
                problems.append(f"{p} edge {e} -> {q}: {s} vs {socks[q][(e + 3) % 6]}")
        if d.river & (d.sea | d.road):
            problems.append(f"{p}: river shares an edge with sea/road")
        if d.mouth and not d.sea:
            problems.append(f"{p}: mouth without sea")
        if len(d.river) == 1 and not (d.mouth or d.lake) and d.base in SEA_BASES:
            problems.append(f"{p}: river ends in a sea tile")
    return problems


def river_ends(patch):
    """Classify every tile where a river path ends: [(pos, 'spring' | 'lake' | 'sea')]. Tiles with >= 2 river edges
    and no lake / mouth are pass-throughs or confluences and are not ends."""
    ends = []
    for p, d in patch.items():
        if not d.river:
            continue
        if d.mouth:
            ends.append((p, "sea"))
        elif d.lake:
            ends.append((p, "lake"))
        elif len(d.river) == 1:
            ends.append((p, "spring"))
    return ends


# ===================================================================================================
# canvas
# ===================================================================================================


def _kernel(offs):
    pad = max(max(abs(dx), abs(dy)) for dx, dy in offs)
    k = pygame.mask.Mask((2 * pad + 1, 2 * pad + 1))
    for dx, dy in offs:
        k.set_at((pad + dx, pad + dy), 1)
    return pad, k


_KERNELS = {True: _kernel(OFFS), False: _kernel(OFFS_THIN)}


class _TrackPen(Pen):
    """A Pen that remembers the box (in canvas pixels) its strokes can have touched, so `Canvas.stamp` does not have to
    scan the whole layer for it (get_bounding_rect costs 0.2 ms). The box is a superset of the drawn pixels."""

    def __init__(self, surf):
        Pen.__init__(self, surf)
        self.box = None

    def _grow(self, x0, y0, x1, y1, pad=2):
        b = self.box
        x0, y0, x1, y1 = x0 * K - pad, y0 * K - pad, x1 * K + pad, y1 * K + pad
        if b is None:
            self.box = [x0, y0, x1, y1]
        else:
            if x0 < b[0]:
                b[0] = x0
            if y0 < b[1]:
                b[1] = y0
            if x1 > b[2]:
                b[2] = x1
            if y1 > b[3]:
                b[3] = y1

    def _pts(self, pts, w=0):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        self._grow(min(xs), min(ys), max(xs), max(ys), 2 + w * K)

    def poly(self, c, pts, w=0):
        if len(pts) > 2:
            self._pts(pts, 1 if w else 0)
            Pen.poly(self, c, pts, w)

    def circle(self, c, xy, r, w=0):
        self._grow(xy[0] - r, xy[1] - r, xy[0] + r, xy[1] + r, 3)
        Pen.circle(self, c, xy, r, w)

    def ellipse(self, c, x, y, w, h, wd=0):
        self._grow(x, y, x + w, y + h, 3)
        Pen.ellipse(self, c, x, y, w, h, wd)

    def line(self, c, a, b, w=1):
        self._pts((a, b), max(1, w))
        Pen.line(self, c, a, b, w)

    def lines(self, c, pts, w=1, closed=False):
        if len(pts) > 1:
            self._pts(pts, max(1, w))
            Pen.lines(self, c, pts, w, closed)

    def rect(self, c, x, y, w, h, wd=0, br=0):
        self._grow(x, y, x + w, y + h, 3)
        Pen.rect(self, c, x, y, w, h, wd, br)

    def take(self):
        b, self.box = self.box, None
        return b


_SPRITES = BoundedCache("wfctiles.props", 512)
_POOL = []                                  # spare (surf, layer, block) triples: allocating three 240 x 280 surfaces
_SPARE = BoundedCache("wfctiles.scratch", 64)


class Canvas:
    """2x drawing surface for one tile: ground pen g, object layer pen o (stamped with an ink outline) and a block
    layer recording where water, roads and walls are, so buildings and peaks keep clear of them.
    The surfaces are recycled: a canvas must not be used after finish()."""

    def __init__(self, size=None):
        if size is not None:                        # a small scratch canvas (see _sprite): not recycled
            self.surf = pygame.Surface(size, pygame.SRCALPHA)
            self.layer = pygame.Surface(size, pygame.SRCALPHA)
            self.block = None
        elif _POOL:
            self.surf, self.layer, self.block = _POOL.pop()
        else:
            size = (W * K, H * K)
            self.surf = pygame.Surface(size, pygame.SRCALPHA)
            self.layer = pygame.Surface(size, pygame.SRCALPHA)
            self.block = pygame.Surface(size, pygame.SRCALPHA)
        self.g, self.o, self.b = Pen(self.surf), _TrackPen(self.layer), Pen(self.block)
        self._marked = False
        self.sbox = None                            # where shadows were blitted (see _sprite)

    def blocked(self, x, y):
        xi, yi = int(x * K), int(y * K)
        if not (0 <= xi < W * K and 0 <= yi < H * K):
            return True
        return self.block.get_at((xi, yi))[3] > 8

    def free(self, x, y, w=8, h=6):
        """Nothing blocked at the 6 points of a footprint w wide and h deep standing at (x, y)."""
        get = self.block.get_at
        xs = (int(x * K), int((x - w / 2) * K), int((x + w / 2) * K))
        for yi in (int(y * K), int((y - h) * K)):
            if not 0 <= yi < H * K:
                return False
            for xi in xs:
                if not 0 <= xi < W * K or get((xi, yi))[3] > 8:
                    return False
        return True

    def mark(self, fn):
        self._marked = True
        fn(self.b)

    def shadow(self, x, y, w, h=None, a=45):
        r = shadow_at(self.surf, x, y, w, h, a)
        self.sbox = r if self.sbox is None else self.sbox.union(r)

    def stamp(self, ink=2):
        box = self.o.take()
        if box is None:
            return
        r = pygame.Rect(int(box[0]) - 1, int(box[1]) - 1, int(box[2] - box[0]) + 3, int(box[3] - box[1]) + 3)
        r = r.inflate(8, 8).clip(self.layer.get_rect())
        if not r.w or not r.h:
            return
        sub = self.layer.subsurface(r)
        if ink:
            # the silhouette smeared to every offset of the outline pattern (a convolution with the pattern's bits)
            pad, kern = _KERNELS[ink >= 2]
            sil = pygame.mask.from_surface(sub, 40).convolve(kern).to_surface(setcolor=INK + (255,),
                                                                              unsetcolor=(0, 0, 0, 0))
            self.surf.blit(sil, (r.x - pad, r.y - pad))
        self.surf.blit(sub, r.topleft)
        self.layer.fill((0, 0, 0, 0), r)

    def finish(self, under=None):
        """Mask to the hex and scale down to 120 x 140. `under`: optional 2x base drawn below."""
        surf = self.surf
        if under is not None:
            surf = under.copy()
            surf.blit(self.surf, (0, 0))
        out = _bleed_scale(surf)
        self.surf.fill((0, 0, 0, 0))                # recycle
        if self._marked:
            self.block.fill((0, 0, 0, 0))
        if self.o.box is not None:
            self.layer.fill((0, 0, 0, 0))
        _POOL.append((self.surf, self.layer, self.block))
        self.surf = self.layer = self.block = None
        return out.convert_alpha() if pygame.display.get_surface() else out


def _spare(name, size, alpha=False):
    key = (name, size, alpha)
    s = _SPARE.get(key)
    if s is None:
        s = _SPARE.put(key, pygame.Surface(size, pygame.SRCALPHA if alpha else 0, 32))
    return s


def _keyed(name, size):
    """A recycled opaque surface, black-filled, with no colour key set."""
    s = _spare(name, size)
    s.set_colorkey(None)
    s.fill((0, 0, 0))
    return s


def _mask_1x():
    """The hex mask at 1x: colour white, alpha = coverage (so a MIN blit only touches alpha)."""
    s = _SPARE.get("mask1")
    if s is None:
        s = _SPARE.put("mask1", pygame.transform.smoothscale(hex_mask(MASK_R), (W, H)))
        s.fill((255, 255, 255, 0), special_flags=pygame.BLEND_RGBA_MAX)
    return s


def _bleed_scale(surf):
    """surf (2x, straight alpha, not yet masked; used up) -> 120 x 140, masked to the hex, where every pixel with any
    alpha has the colour of the drawn pixels near it instead of transparent black (a plain smoothscale would average
    black into the edges: dark hairlines between tiles, dark fringes on overlays).
    The drawn colours are spread 1 px in all 8 directions at 2x (two separable passes of colour-keyed blits, black is
    the key) and MAXed into the transparent pixels, which fills every 2 x 2 block that has a drawn pixel; that is all
    the colour a pixel of alpha > 0 needs. Fully transparent pixels keep a black fringe: scale_tile bleeds them again
    before every rescale. Drawn pixels that are exactly black are simply not spread (their own colour is right)."""
    size = surf.get_size()
    key = _keyed("k", size)
    key.blit(surf, (0, 0))                                       # alpha-blended over black: shadows stay black
    key.set_colorkey((0, 0, 0))
    hz = _keyed("h", size)
    hz.blit(key, (-1, 0))
    hz.blit(key, (1, 0))
    hz.blit(key, (0, 0))
    hz.set_colorkey((0, 0, 0))
    col = _keyed("c", size)
    col.blit(hz, (0, -1))
    col.blit(hz, (0, 1))
    col.blit(hz, (0, 0))
    surf.blit(col, (0, 0), special_flags=pygame.BLEND_RGB_MAX)     # transparent pixels (colour 0) take the bled colour
    out = pygame.transform.smoothscale(surf, (W, H))
    out.blit(_mask_1x(), (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    return out


_BLEED_OFFS = [(dx, dy) for r in (4, 3, 2, 1) for dx, dy in ((-r, 0), (r, 0), (0, -r), (0, r), (-r, -r), (r, -r),
                                                               (-r, r), (r, r))]


_BLEED_KEYS = [(255, 0, 255), (0, 255, 255), (255, 255, 0), (255, 0, 128), (128, 255, 0), (0, 128, 255)]


def _bleed_key(solid):
    """A colour that no drawn (opaque) pixel of solid has, to key the transparent pixels with."""
    for key in _BLEED_KEYS:
        if pygame.mask.from_threshold(solid, key, (1, 1, 1, 255)).count() == 0:
            return key
    raise ValueError("no free colour key for the bleed")


def _bleed(surf):
    """Give fully transparent pixels the colour of the nearest drawn pixel (alpha unchanged), so smoothscale does
    not average transparent black into the edges (dark hairlines between tiles, dark fringes on overlays).
    The 33 offset copies are colour-keyed blits (same pixels as alpha blits of an opaque copy, much faster)."""
    solid = surf.copy()
    solid.fill((0, 0, 0, 255), special_flags=pygame.BLEND_RGBA_MAX)
    solid = pygame.mask.from_surface(surf, 0).to_surface(setsurface=solid, unsetcolor=(0, 0, 0, 0))
    key = _bleed_key(solid)
    keyed = pygame.Surface(surf.get_size())
    keyed.fill(key)
    keyed.blit(solid, (0, 0))
    keyed.set_colorkey(key)
    out = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
    for dx, dy in _BLEED_OFFS:
        out.blit(keyed, (dx, dy))
    out.blit(keyed, (0, 0))
    alpha = surf.copy()
    alpha.fill((255, 255, 255, 0), special_flags=pygame.BLEND_RGBA_MAX)
    out.blit(alpha, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    return out


SPRITE = (72, 64)                           # scratch size (1x px) for a prop; its anchor sits at (36, 52)
_ANCHOR = (36, 52)


def _sprite(key, draw, ink=1, ground_layer=False):
    """Draw a prop once (draw(cv, ax, ay) puts it at the anchor of a scratch canvas, shadow and all, and it gets its
    ink outline) and keep the picture: (surface, dx, dy), where (dx, dy) is the offset in canvas pixels from the
    anchor to the surface's corner."""
    s = _SPRITES.get(key)
    if s is None:
        cv = Canvas((SPRITE[0] * K, SPRITE[1] * K))
        draw(cv, _ANCHOR[0], _ANCHOR[1])
        r = None
        if not ground_layer:
            box = cv.o.box
            if box is not None:                                 # the strokes' box, the shadows' and the ink's margin
                r = pygame.Rect(int(box[0]), int(box[1]), int(box[2] - box[0]) + 1, int(box[3] - box[1]) + 1)
                r = (r.union(cv.sbox) if cv.sbox is not None else r).inflate(2 * 3 + 2, 2 * 3 + 2)
            cv.stamp(ink)
        if r is None:
            r = cv.surf.get_bounding_rect(1)
        else:
            r = r.clip(cv.surf.get_rect())
        s = _SPRITES.put(key, (cv.surf.subsurface(r).copy(), r.x - _ANCHOR[0] * K, r.y - _ANCHOR[1] * K))
    return s


def _prop(key, sort_y, x, y, draw, ink=1):
    """An object (see _draw_objects) that is a cached picture blitted at (x, y)."""
    spr, ox, oy = _sprite(key, draw, ink)
    pos = (round(x * K) + ox, round(y * K) + oy)
    return (sort_y, lambda cv: cv.surf.blit(spr, pos), 0)


def _draw_objects(cv, objs):
    """objs: [(sort y, fn(o), ink)] drawn back to front, each stamped with its outline."""
    for _, fn, ink in sorted(objs, key=lambda q: q[0]):
        fn(cv)
        cv.stamp(ink)


# ===================================================================================================
# water: sea tiles and coasts
# ===================================================================================================
def _ripples(cv, rng, n, test, keep=()):
    for _ in range(n):
        x, y = rng.uniform(8, 112), rng.uniform(10, 130)
        if _inside(x, y, R - 11) and test(x, y) and all(min((_dist((x, y), q) for q in c), default=99) > 9
                                                        for c in keep):
            w = rng.uniform(3, 5)
            cv.g.lines(WATER_L, [(x - w, y), (x - w / 2, y - 1.5), (x, y), (x + w / 2, y - 1.5), (x + w, y)], 1)


def _paint_sea(cv, kind, variant):
    rng = _rng("sea", kind, variant)
    cv.g.poly(WATER, hex_pts(R + 2))
    keep = []
    if kind == "shallow":
        c = (CX + rng.uniform(-8, 8), CY + rng.uniform(-8, 8))
        ctrl = [_add(c, _dir(i * 45 + rng.uniform(-10, 10)), rng.uniform(13, 19) * (1.25 if i % 4 == 0 else 1))
                for i in range(8)]
        bank = _chaikin(ctrl, 3, True)
        halo = _chaikin([_add(c, _unit(_sub(q, c)), _dist(q, c) + 9) for q in ctrl], 3, True)
        cv.g.poly(mix(WATER, WATER_L, 0.45), halo)
        cv.g.poly(mix(WATER, WATER_L, 0.8), _chaikin([_add(c, _unit(_sub(q, c)), _dist(q, c) + 4) for q in ctrl], 3,
                                                     True))
        cv.g.poly(SAND, bank)
        cv.g.poly(shade(SAND, -0.08), [_add(q, (1.5, 2)) for q in bank[len(bank) // 4: len(bank) * 3 // 4]] + [c])
        cv.g.lines(WHITE, halo, 1, True)
        for _ in range(3):
            a = rng.uniform(0, 360)
            q = _add(c, _dir(a), rng.uniform(2, 8))
            cv.g.line((120, 150, 80), q, _add(q, (rng.uniform(-1, 1), -4)), 1.2)
        keep.append(halo)
    elif kind == "reef":
        for _ in range(7):
            q = (CX + rng.uniform(-28, 28), CY + rng.uniform(-30, 30))
            cv.g.circle(SURF, q, 7)
        for _ in range(9):
            q = (CX + rng.uniform(-28, 28), CY + rng.uniform(-30, 30))
            cv.o.poly((150, 150, 158), [_add(q, (-4, 1)), _add(q, (-1, -4)), _add(q, (3, -2)), _add(q, (4, 1))])
            cv.o.poly((115, 115, 126), [_add(q, (0, 1)), _add(q, (-1, -4)), _add(q, (3, -2)), _add(q, (4, 1))])
            keep.append([q])
        cv.stamp(1)
    _ripples(cv, rng, 9, lambda x, y: True, keep)


def _coast_geo(sea, variant, rd=COAST_RD):
    rng = _rng("coast", tuple(sorted(sea)), variant)
    curves = _boundary(sea, rd + rng.uniform(-2, 2), COAST_F, rng, wob=4.0)
    return {"curves": curves, "water": _fill_layer(curves, WATER), "rd": rd, "rng": rng}


def _paint_coast_sand(cv, geo):
    for c in geo["curves"]:
        _band(cv.g, SAND, c.pts, 13, c.closed)


def _paint_coast_water(cv, geo):
    cv.surf.blit(geo["water"], (0, 0))
    for c in geo["curves"]:
        _band(cv.g, SURF, c.pts, 5, c.closed)
    for c in geo["curves"]:
        cv.g.lines(WHITE, c.pts, 1.5, c.closed)
    water = geo["water"]
    _ripples(cv, geo["rng"], 12, lambda x, y: _covers(water, x, y), [c.pts for c in geo["curves"]])
    cv.mark(lambda b: (b.s.blit(water, (0, 0)), [_band(b, (0, 0, 0, 255), c.pts, 16, c.closed)
                                                  for c in geo["curves"]]))


# ===================================================================================================
# rivers and roads: smooth paths from edge midpoints to a hub
# ===================================================================================================
def _hub(edges, rng, jit=4.0):
    edges = sorted(edges)
    v = (0.0, 0.0)
    if len(edges) == 2:
        a, b = edges
        gap = min((a - b) % 6, (b - a) % 6)
        s = {1: 15.0, 2: 6.0, 3: 0.0}[gap]
        v = _unit(_add(normal(a), normal(b)))
        v = (v[0] * s, v[1] * s)
    return CX + v[0] + rng.uniform(-jit, jit), CY + v[1] + rng.uniform(-jit, jit)


def _paths(edges, J, ext=8.0):
    """{edge: polyline from just outside the edge midpoint to J}. With two edges the halves join smoothly at J."""
    edges = sorted(edges)
    out = {}
    if len(edges) == 2:
        a, b = edges
        Ma, Mb = edge_mid(a), edge_mid(b)
        Ca = _add(Ma, normal(a), -0.42 * _dist(Ma, J))
        Cb = _add(Mb, normal(b), -0.42 * _dist(Mb, J))
        d = _unit(_sub(Cb, Ca))
        kj = 0.33 * min(_dist(Ma, J), _dist(Mb, J))
        out[a] = [_add(Ma, normal(a), ext)] + _bez(Ma, Ca, _add(J, d, -kj), J)
        out[b] = [_add(Mb, normal(b), ext)] + _bez(Mb, Cb, _add(J, d, kj), J)
        return out
    for e in edges:
        M = edge_mid(e)
        C = _add(M, normal(e), -0.42 * _dist(M, J))
        d = _unit(_sub(C, J))
        out[e] = [_add(M, normal(e), ext)] + _bez(M, C, _add(J, d, 0.3 * _dist(M, J)), J)
    return out


def _river_geo(desc, coast):
    edges = desc.river
    if not edges and not desc.lake:
        return None
    rng = _rng("river", tuple(sorted(edges)), desc.variant, desc.lake, desc.mouth)
    J = _hub(edges, rng, 3.0 if desc.lake else 5.0)
    geo = {"paths": [], "flare": None, "spring": None, "lake": None, "J": J}
    if desc.mouth and desc.sea and edges:
        avg = _unit(_add((0.0, 0.0), tuple(sum(-normal(e)[i] for e in edges) for i in (0, 1))) or (1, 0))
        s = max(desc.sea, key=lambda q: normal(q)[0] * avg[0] + normal(q)[1] * avg[1]
                + 0.3 * sum(1 for d in (-1, 1) if (q + d) % 6 in desc.sea))
        rd = coast["rd"] if coast else COAST_RD
        T = _polar(-60 * s, rd + 14)
        ns = normal(s)
        if len(edges) == 1:
            e = next(iter(edges))
            M = edge_mid(e)
            k = 0.4 * _dist(M, T)
            flare = [_add(M, normal(e), 8)] + _bez(M, _add(M, normal(e), -k), _add(T, ns, -k * 0.9), T)
        else:
            geo["paths"] += list(_paths(edges, J).values())
            k = 0.4 * _dist(J, T)
            flare = _bez(J, lerp(J, T, 0.3), _add(T, ns, -k), T)
        geo["flare"] = flare
    elif edges:
        geo["paths"] += list(_paths(edges, J).values())
        if len(edges) == 1 and not desc.lake:
            geo["spring"] = J
    if desc.lake:
        c = (J[0], J[1])
        n = 10
        ctrl = [_add(c, _dir(i * 360 / n + rng.uniform(-8, 8)), rng.uniform(17, 24) * (1.15 if i % 5 == 0 else 1))
                for i in range(n)]
        geo["lake"] = _chaikin(ctrl, 3, True)
    return geo


def _flare_circles(path, w0, w1, start=0.3):
    """(point, radius) along a path whose width grows from w0 to w1 after fraction `start` of its length."""
    seg = [_dist(a, b) for a, b in zip(path, path[1:])]
    total = sum(seg) or 1
    out, run = [], 0.0
    for i, q in enumerate(path):
        f = run / total
        t = max(0.0, (f - start) / (1 - start))
        out.append((q, (w0 + (w1 - w0) * t * t) / 2))
        if i < len(seg):
            run += seg[i]
    dense = []
    for (a, ra), (b, rb) in zip(out, out[1:]):
        for k in range(3):
            dense.append((lerp(a, b, k / 3), ra + (rb - ra) * k / 3))
    dense.append(out[-1])
    return dense


def _paint_river_bank(cv, geo):
    for p in geo["paths"]:
        _band(cv.g, RIVER_EDGE, p, RW + 3)
    if geo["flare"]:
        for q, r in _flare_circles(geo["flare"], RW + 3, RW * FLARE + 3):
            cv.g.circle(RIVER_EDGE, q, r)
    if geo["lake"]:
        _band(cv.g, (150, 170, 110), geo["lake"], 8, True)


def _paint_river_water(cv, geo, rng):
    g = cv.g
    for p in geo["paths"]:
        _band(g, WATER, p, RW)
    if geo["flare"]:
        for q, r in _flare_circles(geo["flare"], RW, RW * FLARE):
            g.circle(WATER, q, r)
    for p in geo["paths"]:
        _band(g, mix(WATER, WATER_L, 0.55), p, 2.2)
    if geo["flare"]:
        _band(g, mix(WATER, WATER_L, 0.55), geo["flare"][:len(geo["flare"]) * 2 // 3], 2.2)
        T = geo["flare"][-1]
        u = _unit(_sub(geo["flare"][-1], geo["flare"][-4]))
        v = (-u[1], u[0])
        for s in (-1, 1):                      # two sandbars in the delta
            q = _add(_add(T, u, -7), v, s * 7)
            g.poly(SAND, [_add(_add(q, u, -6), v, -s * 1.5), _add(q, v, s * 2.5), _add(_add(q, u, 5), v, s * 1),
                          _add(q, v, -s * 2.2)])
            g.line((110, 150, 80), q, _add(q, (0.5, -3)), 1)
            g.line((110, 150, 80), _add(q, u, -2), _add(_add(q, u, -2), (-0.5, -2.5)), 1)
    if geo["lake"]:
        lake = geo["lake"]
        g.poly(WATER, lake)
        c = geo["J"]
        g.poly(mix(WATER, WATER_L, 0.3), [lerp(c, q, 0.55) for q in lake])
        g.lines(mix(WATER, WATER_L, 0.7), [lerp(c, q, 0.9) for q in lake], 1, True)
        for _ in range(3):
            q = lerp(c, rng.choice(lake), rng.uniform(0.2, 0.6))
            g.lines(WATER_L, [(q[0] - 3, q[1]), (q[0] - 1.5, q[1] - 1.2), (q[0], q[1]), (q[0] + 1.5, q[1] - 1.2),
                              (q[0] + 3, q[1])], 1)
        for _ in range(6):                     # reeds round the shore
            q = rng.choice(lake)
            q = lerp(c, q, 1.08)
            for k in range(3):
                g.line((90, 130, 60), (q[0] + k * 1.4 - 1.4, q[1]), (q[0] + k * 1.8 - 2, q[1] - 4 - k % 2 * 1.5), 0.8)
    if geo["spring"]:
        J = geo["spring"]
        g.circle(RIVER_EDGE, J, 7.5)
        g.circle(WATER, J, 6)
        g.circle(mix(WATER, WATER_L, 0.6), (J[0] - 1, J[1] - 1), 3)
        for k in range(4):
            a = rng.uniform(0, 360)
            q = _add(J, _dir(a), 7.5)
            g.circle((150, 150, 156), q, 1.8)
            g.circle((185, 185, 190), (q[0] - 0.5, q[1] - 0.5), 1)
    # a few glints well inside the tile
    for p in geo["paths"]:
        for q in p[3:-2:5]:
            if _inside(q[0], q[1], R - 16) and rng.random() < 0.5:
                g.line(WHITE, (q[0] - 1.2, q[1]), (q[0] + 1.2, q[1]), 0.8)


def _mark_river(cv, geo):
    def f(b):
        for p in geo["paths"]:
            _band(b, (0, 0, 0, 255), p, RW + 9)
        if geo["flare"]:
            for q, r in _flare_circles(geo["flare"], RW + 9, RW * FLARE + 9):
                b.circle((0, 0, 0, 255), q, r)
        if geo["lake"]:
            b.poly((0, 0, 0, 255), geo["lake"])
            _band(b, (0, 0, 0, 255), geo["lake"], 10, True)
        if geo["spring"]:
            b.circle((0, 0, 0, 255), geo["spring"], 11)
    cv.mark(f)


def _road_geo(desc, river):
    edges = desc.road
    if not edges:
        return None
    rng = _rng("road", tuple(sorted(edges)), desc.variant)
    if desc.town:
        J = (CX + rng.uniform(-2, 2), CY + rng.uniform(-2, 2))
    elif desc.castle:
        J = (CX, CY + 22)
    elif len(edges) == 1:
        e = next(iter(edges))
        J = edge_mid(e, A - 32)
    else:
        J = _hub(edges, rng, 3.0)
        if river and river["paths"] and _dist(J, river["J"]) < 14:
            v = tuple(sum(normal(e)[i] for e in edges) for i in (0, 1))
            if _len(v) < 0.3:
                v = (-normal(min(edges))[1], normal(min(edges))[0])
            J = _add(J, _unit(v), 15)
    paths = _paths(edges, J)
    if river and len(edges) == 1 and not desc.town and not desc.castle:
        # a dead end stops short of the river instead of running into it
        e = next(iter(edges))
        rivers = river["paths"] + ([river["flare"]] if river["flare"] else [])
        for rp in rivers:
            xs = _crossings(paths[e], rp)
            if xs:
                paths[e] = paths[e][:max(2, xs[0][1] - 1)]
    kinds = {e: "paved" if e in desc.paved else "dirt" for e in edges}
    return {"paths": paths, "kinds": kinds, "J": J}


def _paint_road(cv, geo, rng):
    g = cv.g
    paths, kinds = geo["paths"], geo["kinds"]
    for e, p in paths.items():
        k = kinds[e]
        _band(g, ROAD_COL[k][0], p, ROAD_W[k] + 1.8)
    for e, p in paths.items():
        k = kinds[e]
        _band(g, ROAD_COL[k][1], p, ROAD_W[k])
    for e, p in paths.items():
        k = kinds[e]
        if k == "dirt":
            _band(g, ROAD_COL[k][2], p, 1.6)
        else:                                   # cobble ticks every 3.5 px measured from the edge (seamless)
            run, nxt = 0.0, 1.75 + 8.0
            for a, b in zip(p, p[1:]):
                d = _dist(a, b)
                while run + d >= nxt:
                    q = lerp(a, b, (nxt - run) / d if d else 0)
                    u = _unit(_sub(b, a))
                    v = (-u[1] * ROAD_W[k] * 0.42, u[0] * ROAD_W[k] * 0.42)
                    g.line(ROAD_COL[k][2], _add(q, v), _add(q, v, -1), 0.7)
                    nxt += 3.5
                run += d
    if len(paths) >= 3 or any(len(p) < 10 for p in paths.values()):
        J = geo["J"]
        k = "paved" if "paved" in kinds.values() else "dirt"
        g.circle(ROAD_COL[k][0], J, ROAD_W[k] / 2 + 0.9)
        g.circle(ROAD_COL[k][1], J, ROAD_W[k] / 2)


def _mark_road(cv, geo, extra=7):
    def f(b):
        for e, p in geo["paths"].items():
            _band(b, (0, 0, 0, 255), p, ROAD_W[geo["kinds"][e]] + extra)
    cv.mark(f)


def _bridge(cv, X, u, kind):
    """A bridge deck centred on X along unit direction u."""
    o = cv.o
    v = (-u[1], u[0])
    L, w = RW + 11, ROAD_W[kind] + 3
    def quad(l2, w2, off=(0, 0)):
        return [_add(_add(_add(X, u, s * l2), v, t * w2), off) for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    if kind == "paved":
        o.poly((120, 116, 108), quad(L / 2, w / 2, (0, 2.2)))
        o.poly((206, 200, 186), quad(L / 2, w / 2))
        for t in (-1, 1):
            a, b = _add(_add(X, u, -L / 2), v, t * w / 2), _add(_add(X, u, L / 2), v, t * w / 2)
            o.line((236, 232, 220) if t < 0 else (160, 154, 142), a, b, 1.3)
    else:
        o.poly(DWOOD, quad(L / 2, w / 2, (0, 2)))
        o.poly((176, 128, 78), quad(L / 2, w / 2))
        for i in range(1, 7):
            a = _add(_add(X, u, -L / 2 + L * i / 7), v, -w / 2)
            o.line((140, 98, 58), a, _add(a, v, w), 0.6)
        for t in (-1, 1):
            a, b = _add(_add(X, u, -L / 2), v, t * w / 2), _add(_add(X, u, L / 2), v, t * w / 2)
            o.line(DWOOD, a, b, 1)


def _crossing_objects(cv, road, river, crossing):
    objs = []
    if not road or not river:
        return objs
    rivers = river["paths"] + ([river["flare"]] if river["flare"] else [])
    for e, p in road["paths"].items():
        for rp in rivers:
            for X, _, u in _crossings(p, rp):
                kind = road["kinds"][e]
                if crossing == "ford":
                    def fn(c, X=X, u=u, kind=kind):
                        v = (-u[1], u[0])
                        c.g.poly(mix(WATER, SAND, 0.45), [_add(_add(X, u, s * (RW / 2 + 1)), v, t * (ROAD_W[kind] / 2 + 1))
                                                          for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
                        for i in range(-2, 3):
                            q = _add(X, u, i * 2.2)
                            for t in (-1, 1):
                                c.o.circle((170, 168, 160), _add(q, v, t * 1.8), 1.1)
                    objs.append((X[1], fn, 1))
                elif crossing == "ferry":
                    def fn(c, X=X, u=u):
                        v = (-u[1], u[0])
                        c.g.line((90, 70, 50), _add(X, u, -RW), _add(X, u, RW), 0.6)
                        c.o.poly((170, 120, 72), [_add(_add(X, u, s * 3.2), v, t * 4.5)
                                                  for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
                        c.o.line(DWOOD, _add(_add(X, u, -3.2), v, 4.5), _add(_add(X, u, 3.2), v, 4.5), 1)
                        c.o.rect((200, 60, 50), X[0] - 1, X[1] - 4, 2, 3)
                    objs.append((X[1], fn, 1))
                else:
                    objs.append((X[1] - 2, lambda c, X=X, u=u, kind=kind: _bridge(c, X, u, kind), 1))
    return objs


# ===================================================================================================
# walls
# ===================================================================================================
def _wall_geo(desc, road, level):
    rng = _rng("wall", tuple(sorted(desc.town_in)), desc.variant)
    outside = ALL - desc.town_in
    rd = 45.0 if desc.castle else {1: 37.0, 2: WALL_RD, 3: 38.0}[level]
    curves = _boundary(outside, rd, WALL_F, rng, wob=0, corner_k=1.12, iters=0, ext=8.0, h=7.0)
    gates = []
    if road:
        for p in road["paths"].values():
            for c in curves:
                pts = c.pts + ([c.pts[0]] if c.closed else [])
                for X, _, u in _crossings(p, pts):
                    gates.append((X, u))
    return {"curves": curves, "gates": gates, "out": _fill_layer(curves, (0, 0, 0, 255)), "level": level}


def _split_at_gates(pts, gates, gap=6.0):
    """Cut a polyline into pieces leaving `gap` either side of each gate point."""
    pieces, cur = [], [pts[0]]
    for a, b in zip(pts, pts[1:]):
        cuts = []
        for X, _ in gates:
            d = _dist(a, b)
            if d < 1e-6:
                continue
            u = _unit(_sub(b, a))
            t = (X[0] - a[0]) * u[0] + (X[1] - a[1]) * u[1]
            off = abs((X[0] - a[0]) * u[1] - (X[1] - a[1]) * u[0])
            if off < 3 and -gap < t < d + gap:
                cuts.append((t - gap, t + gap))
        if not cuts:
            cur.append(b)
            continue
        d = _dist(a, b)
        u = _unit(_sub(b, a))
        pos = 0.0
        for t0, t1 in sorted(cuts):
            if t0 > pos:
                cur.append(_add(a, u, min(t0, d)))
            if len(cur) > 1:
                pieces.append(cur)
            cur = [_add(a, u, min(max(t1, 0), d))] if t1 < d else []
            pos = t1
        if pos < d:
            if not cur:
                cur = [_add(a, u, max(pos, 0))]
            cur.append(b)
    if len(cur) > 1:
        pieces.append(cur)
    return pieces


def _merge_straight(pts):
    """Drop interior points where the polyline runs straight on (no outline seam where a wall crosses an edge)."""
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        u, v = _unit(_sub(pts[i], out[-1])), _unit(_sub(pts[i + 1], pts[i]))
        if u[0] * v[0] + u[1] * v[1] < 0.9995:
            out.append(pts[i])
    out.append(pts[-1])
    return out


def _wall_segment(c, a, b, level, col):
    o = c.o
    if level == 1:
        n = max(1, int(_dist(a, b) / 3.0))
        for i in range(n + 1):
            x, y = lerp(a, b, i / n)
            cc = WOOD if i % 2 == 0 else shade(WOOD, -0.18)
            o.poly(cc, [(x - 1.7, y), (x + 1.7, y), (x + 1.7, y - 8), (x, y - 10.5), (x - 1.7, y - 8)])
        return
    h = 7.5 if level == 2 else 4.5
    u = _unit(_sub(b, a))
    nrm = (-u[1], u[0]) if u[0] >= 0 else (u[1], -u[0])
    face = shade(col, -0.06 - 0.22 * max(0.0, nrm[0] if nrm[1] >= 0 else -nrm[0]))
    o.poly(face, [a, b, (b[0], b[1] - h), (a[0], a[1] - h)])
    top = [(a[0], a[1] - h), (b[0], b[1] - h)]
    _band(o, shade(col, 0.18), top, 2.6)
    n = max(1, int(_dist(a, b) / 3.2))
    for i in range(n):
        q = lerp(top[0], top[1], (i + 0.5) / n)
        if i % 2 == 0 and _inside(q[0], q[1] + h, R - 8):     # none near the hex edge (their phase differs)
            o.rect(shade(col, 0.05), q[0] - 0.9, q[1] - 2.6, 1.8, 1.6)


def _wall_objects(cv, geo, water=None, centre=(CX, CY)):
    wet = (lambda q: _covers(water, *q)) if water is not None else (lambda q: False)
    level = geo["level"]
    col = (200, 194, 180) if level == 2 else (186, 176, 150)
    objs = []
    for c in geo["curves"]:
        pts = c.pts + ([c.pts[0]] if c.closed else [])
        for piece in _split_at_gates(pts, geo["gates"]):
            piece = _merge_straight(piece)
            for a, b in zip(piece, piece[1:]):
                if _dist(a, b) < 0.5 or wet(lerp(a, b, 0.5)):
                    continue
                ym = max(a[1], b[1]) - 1
                objs.append((ym, lambda cc, a=a, b=b: _wall_segment(cc, a, b, level, col), 1))
        for q in c.towers:
            if any(_dist(q, X) < 9 for X, _ in geo["gates"]) or wet(q):
                continue
            if level == 1:
                def post(cc, x, y):
                    cc.o.rect(WOOD, x - 3.5, y - 15, 7, 15)
                    cc.o.rect(shade(WOOD, -0.25), x, y - 15, 3.5, 15)
                    cc.o.poly(DWOOD, [(x - 5, y - 15), (x + 5, y - 15), (x, y - 21)])
                objs.append(_prop(("wtower", 1), q[1] + 0.5, q[0], q[1], post))
            elif level == 2:
                roof = ROOF_RED if int(q[0] + q[1]) % 3 else ROOF_SLATE
                objs.append(_prop(("wtower", 2, roof), q[1] + 0.5, q[0], q[1],
                                  lambda cc, x, y, roof=roof: tower(cc.o, x, y, 4.2, 13, col, roof, 7)))
            else:
                u = _unit(_sub(q, centre))
                v = (-u[1], u[0])
                def bastion(cc, q=q, u=u, v=v):
                    tip = _add(q, u, 9)
                    l, r = _add(_add(q, v, -6.5), u, -1), _add(_add(q, v, 6.5), u, -1)
                    cc.o.poly(shade(col, -0.3), [(x, y + 4) for x, y in (l, tip, r)] + [r, tip, l])
                    cc.o.poly(shade(col, 0.12), [l, tip, r, q])
                    cc.o.line(shade(col, -0.15), l, tip, 0.8)
                objs.append((q[1] + 6, bastion, 1))
    for X, u in geo["gates"]:
        v = (-u[1], u[0])
        if abs(v[0]) < 0.3:
            v = (1.0, 0.0)
        v = (round(v[0] * 6) / 6, round(v[1] * 6) / 6)            # a handful of gate orientations: draw each once
        a, b = _add(X, v, -5.5), _add(X, v, 5.5)

        def gate(cc, X0, Y0, v=v):
            Xp = (X0, Y0)
            a, b = _add(Xp, v, -5.5), _add(Xp, v, 5.5)
            if level == 1:
                for q in (a, b):
                    cc.o.rect(WOOD, q[0] - 1.6, q[1] - 13, 3.2, 13)
                cc.o.line(DWOOD, (a[0] - 1, a[1] - 12), (b[0] + 1, b[1] - 12), 1.8)
            else:
                cc.o.poly(shade(col, -0.05), [(a[0], a[1] - 11), (b[0], b[1] - 11), (b[0], b[1] - 6), (a[0], a[1] - 6)])
                cc.o.rect(DARK, Xp[0] - 2.2, Xp[1] - 8, 4.4, 4)
                for q in (a, b):
                    tower(cc.o, q[0], q[1], 3.2, 12, col, ROOF_SLATE if level == 2 else None, 5,
                          crenel=level == 3)
        objs.append(_prop(("wgate", level, col, v), max(a[1], b[1]) + 0.6, X[0], X[1], gate))
    return objs


def _paint_glacis(cv, geo):
    if geo["level"] == 3:
        for c in geo["curves"]:
            _band(cv.g, (126, 196, 108, 255), c.pts, 15, c.closed)
            _band(cv.g, (104, 176, 92, 255), c.pts, 9, c.closed)


def _mark_wall(cv, geo):
    def f(b):
        b.s.blit(geo["out"], (0, 0))
        for c in geo["curves"]:
            _band(b, (0, 0, 0, 255), c.pts, 9, c.closed)
            for q in c.towers:
                b.circle((0, 0, 0, 255), q, 7)
    cv.mark(f)


# ===================================================================================================
# settlements, harbours, castles, mountains, marsh
# ===================================================================================================
WALLS = [CREAM, (236, 214, 180), (222, 204, 174), WHITE, (214, 190, 160)]
ROOFS = {1: [THATCH, (200, 160, 84)], 2: [THATCH, THATCH, ROOF_RED],
         3: [ROOF_RED, ROOF_RED, (190, 84, 60), THATCH], 4: [ROOF_RED, (190, 84, 60), ROOF_SLATE],
         5: [ROOF_RED, (190, 84, 60), ROOF_SLATE, (168, 98, 72)], 6: [ROOF_RED, (186, 80, 58), ROOF_SLATE, (120, 128, 146)]}
# level: houses, radius, grid step, house scale, square radius, suburbs
TOWN = {1: (3, 20, 12, 1.0, 0, 0), 2: (6, 26, 11, 0.95, 0, 0), 3: (11, 32, 10, 0.9, 8, 0),
        4: (15, 36, 9.5, 0.85, 8, 0), 5: (22, 36, 8.5, 0.78, 9, 5), 6: (28, 35, 8.0, 0.74, 10, 9)}


HOUSE_VARIANTS = 12                        # distinct houses per (scale, roof set): they are drawn once and blitted


def _house(c, x, y, s, rng, roofs, tall=False):
    k = rng.randrange(HOUSE_VARIANTS)
    roofs = tuple(roofs)

    def draw(cv, ax, ay):
        r = _rng("house", s, tall, roofs, k)
        w = r.uniform(9, 12) * s
        h = r.uniform(6, 8) * s * (1.4 if tall else 1)
        d = r.uniform(6, 8) * s
        kind = r.choice(["front", "side", "side", "hip"])
        wall = r.choice(WALLS)
        roof = r.choice(roofs)
        seed = r.random()
        cv.shadow(ax + 3, ay, w + 6, a=40)
        building(cv.o, ax, ay, w, h, d, wall, roof, kind, rh=h * 0.75 if kind != "front" else None,
                 wins=2 if w > 10 else 1, door=seed < 0.7)
    return _prop(("house", s, tall, roofs, k), y, x, y, draw)


def _church(x, y, big=False, spire=True):
    def draw(cv, x, y):
        o = cv.o
        if big:
            cv.shadow(x + 6, y, 34, a=45)
            building(o, x + 4, y, 24, 13, 12, STONE, ROOF_SLATE, "side", rh=9, door=False)
            o.circle((90, 110, 170), (x - 8 + 0.5, y - 8), 1.8)
            for dx in (-10, -3):
                tower(o, x + dx, y + 1.5, 3.4, 22, STONE, ROOF_SLATE, 12)
            o.rect(DARK, x - 7.6, y - 6, 3.2, 6)
        else:
            cv.shadow(x + 4, y, 24, a=45)
            building(o, x + 3, y, 15, 8, 8, CREAM, ROOF_SLATE if spire else ROOF_RED, "side", rh=6, door=False)
            if spire:
                tower(o, x - 6, y + 1, 3.2, 15, CREAM, ROOF_SLATE, 10)
            else:
                o.rect(CREAM, x - 7.5, y - 13, 4, 13)
                o.poly(ROOF_RED, [(x - 8.5, y - 13), (x - 2.5, y - 13), (x - 5.5, y - 17)])
    return _prop(("church", big, spire), y, x, y, draw)


def _palace(x, y):
    def draw(cv, x, y):
        cv.shadow(x + 5, y, 34, a=45)
        building(cv.o, x, y, 24, 11, 12, (236, 226, 204), (90, 104, 130), "hip", rh=7, wins=4)
        flag(cv.o, x, y - 20, 8, (200, 40, 50))
    return _prop(("palace",), y, x, y, draw)


def _market(cv, J, rad, rng):
    k = rng.randrange(8)

    def ground(cv, jx, jy):
        r = _rng("market", rad, k)
        g = cv.g
        pts = [_add((jx, jy), (math.cos(math.radians(a)) * rad * 1.25, math.sin(math.radians(a)) * rad * 0.85))
               for a in range(0, 360, 30)]
        g.poly((150, 140, 120), [(x, y + 1) for x, y in pts])
        g.poly((206, 196, 172), pts)
        for _ in range(int(rad * 2)):
            q = _add((jx, jy), (r.uniform(-rad, rad), r.uniform(-rad * 0.6, rad * 0.6)))
            g.circle((186, 176, 152), q, 0.7)
    pts = [_add(J, (math.cos(math.radians(a)) * rad * 1.25, math.sin(math.radians(a)) * rad * 0.85))
           for a in range(0, 360, 30)]
    spr, ox, oy = _sprite(("market", rad, k), ground, 0, ground_layer=True)
    cv.surf.blit(spr, (round(J[0] * K) + ox, round(J[1] * K) + oy))
    cv.mark(lambda b: b.poly((0, 0, 0, 255), [_add(J, _sub(q, J), 1.25) for q in pts]))

    def well(cc, J=J):
        cc.o.circle((150, 150, 156), J, 3)
        cc.o.circle(WATER, J, 1.8)
    objs = [(J[1] + 1, well, 1)]
    cols = [(220, 60, 50), (60, 110, 200), (240, 190, 60), (80, 160, 80)]
    for i in range(min(4, int(rad / 3))):
        a = math.radians(40 + i * 95 + rng.uniform(-15, 15))
        q = _add(J, (math.cos(a) * rad * 0.8, math.sin(a) * rad * 0.5))
        col = cols[i % 4]

        def draw(cv, qx, qy, col=col):
            q = (qx, qy)
            cv.o.line(DWOOD, (q[0] - 3, q[1]), (q[0] - 3, q[1] - 4), 0.8)
            cv.o.line(DWOOD, (q[0] + 3, q[1]), (q[0] + 3, q[1] - 4), 0.8)
            cv.o.poly(col, [(q[0] - 4, q[1] - 4), (q[0] + 4, q[1] - 4), (q[0] + 3, q[1] - 7), (q[0] - 3, q[1] - 7)])
            cv.o.line(WHITE, (q[0] - 1, q[1] - 4), (q[0] - 0.5, q[1] - 7), 0.8)
        objs.append(_prop(("stall", col), q[1], q[0], q[1], draw))
    return objs


def _fields(cv, rng, n, rmin, rmax):
    cols = [(214, 196, 96), (196, 186, 84), (128, 188, 84), (176, 200, 92)]
    placed = 0
    for _ in range(60):
        if placed >= n:
            break
        a = rng.uniform(0, 360)
        q = _polar(a, rng.uniform(rmin, rmax))
        ang = rng.uniform(-25, 25)
        u = _dir(ang)
        v = _dir(ang + 80)
        w, h = rng.uniform(13, 18), rng.uniform(8, 11)
        if not _inside(q[0], q[1], R - 8) or cv.blocked(*q):
            continue
        quad = [_add(_add(q, u, s * w / 2), v, t * h / 2) for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        if not all(_inside(x, y, R - 8) and not cv.blocked(x, y) for x, y in quad + [q]):
            continue
        col = rng.choice(cols)
        cv.g.poly(shade(col, -0.12), [(x, y + 1) for x, y in quad])
        cv.g.poly(col, quad)
        for i in range(1, 4):
            cv.g.line(shade(col, -0.15), lerp(quad[0], quad[3], i / 4), lerp(quad[1], quad[2], i / 4), 0.7)
        cv.mark(lambda b, quad=quad: b.poly((0, 0, 0, 255), [_add(q, _sub(p, q), 1.2) for p in quad]))
        placed += 1


def _piers(cv, coast, level, rng):
    """Piers from the shore into the sea plus moored boats (harbour)."""
    objs = []
    water = coast["water"]
    want = {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3}.get(level, 1)
    spots = []
    for c in coast["curves"]:
        pts = c.pts
        for i in range(4, len(pts) - 4, 3):
            q = pts[i]
            if not _inside(q[0], q[1], R - 13):
                continue
            t = _unit(_sub(pts[i + 2], pts[i - 2]))
            n = (-t[1], t[0])
            if not _covers(water, *_add(q, n, 6)):
                n = (t[1], -t[0])
            if not _covers(water, *_add(q, n, 6)):
                continue
            end = _add(q, n, 17)
            if _inside(end[0], end[1], R - 11) and _covers(water, *end) and _covers(water, *_add(q, n, 9)):
                spots.append((q, n))
    rng.shuffle(spots)
    chosen = []
    for q, n in spots:
        if len(chosen) < want and all(_dist(q, o) > 16 for o, _ in chosen):
            chosen.append((q, n))
    for q, n in chosen:
        a, b = _add(q, n, -4), _add(q, n, 14)
        v = (-n[1], n[0])
        if v[1] < 0:
            v = (-v[0], -v[1])                     # v points down the screen: the pier's visible side

        def pier(c, a=a, b=b, v=v, n=n):
            deck = [_add(a, v, -2.2), _add(b, v, -2.2), _add(b, v, 2.2), _add(a, v, 2.2)]
            for k in range(1, 5):                  # posts under the near side
                p = _add(lerp(a, b, k / 5), v, 2.2)
                c.o.rect(DWOOD, p[0] - 0.7, p[1] - 0.5, 1.4, 3.2)
            c.o.poly((132, 92, 56), [(x, y + 1.4) for x, y in deck])
            c.o.poly((184, 136, 84), deck)
            for k in range(1, 9):
                p = lerp(a, b, k / 9)
                c.o.line((150, 108, 64), _add(p, v, -2.2), _add(p, v, 2.2), 0.5)
        objs.append((max(a[1], b[1]) - 2, pier, 1))
        bq = _add(_add(b, n, -4), v, 6.5)
        if _inside(bq[0], bq[1] - 10, R - 10) and _inside(bq[0], bq[1], R - 10) and _covers(water, *bq):
            objs.append((bq[1] + 2, lambda c, bq=bq: boat(c.o, bq[0], bq[1] + 2, 0.55, WHITE, bq[0] > CX), 1))
    if level >= 3 and chosen:                    # a crane on the first pier
        q, n = chosen[0]
        p = _add(q, n, -1)

        def crane(c, p=p):
            c.o.line(DWOOD, p, (p[0], p[1] - 14), 1.6)
            c.o.line(DWOOD, (p[0], p[1] - 14), (p[0] + 8, p[1] - 10), 1.2)
            c.o.line((80, 70, 60), (p[0] + 8, p[1] - 10), (p[0] + 8, p[1] - 5), 0.6)
            c.o.rect((160, 110, 60), p[0] + 6.5, p[1] - 5, 3, 2.5)
        objs.append((p[1] + 1, crane, 1))
    return objs


def _settlement_objects(cv, desc, wall_geo, coast, rng):
    lvl = max(1, min(6, desc.town))
    n, rad, step, s, sq, sub = TOWN[lvl]
    roofs = ROOFS[lvl]
    objs = []
    J = (CX, CY)
    if sq:
        objs += _market(cv, J, sq, rng)
    inside_test = (lambda x, y: not _covers(wall_geo["out"], x, y)) if wall_geo else (lambda x, y: True)
    cells = []                                   # the staggered grid the houses sit on (before their jitter)
    y = CY - 60
    row = 0
    while y < CY + 64:
        x = CX - 60 + (step / 2 if row % 2 else 0)
        while x < CX + 60:
            cells.append((x, y))
            x += step
        y += step * 0.78
        row += 1

    def spot(x, y):
        return x + rng.uniform(-0.3, 0.3) * step, y + rng.uniform(-0.25, 0.25) * step, rng.random()
    reach = (rad + 6 + 0.4 * step) ** 2           # a spot further out can never be an inner one: no need to jitter it
    cand = [spot(x, y) for x, y in cells if (x - CX) ** 2 + (y - CY) ** 2 < reach]
    hw = 11 * s
    def ok(x, y):
        return _inside(x, y + 2, R - 10) and _inside(x, y - 14 * s, R - 6) and cv.free(x, y, hw, 6 * s)
    inner = [(x, y, r) for x, y, r in cand if _dist((x, y), J) < rad + r * 6 and ok(x, y) and inside_test(x, y)]
    inner.sort(key=lambda q: _dist((q[0], q[1]), J) + q[2] * 8)
    used = []

    def take(x, y, gap):
        g2 = gap * gap
        for ux, uy in used:
            if (x - ux) ** 2 + (y - uy) ** 2 <= g2:
                return False
        used.append((x, y))
        return True
    if lvl >= 2:                                 # landmark first, close to the centre
        for x, y, _ in inner:
            if _dist((x, y), J) > sq + 4 and cv.free(x - 4, y, 22, 10) and cv.free(x + 6, y, 10, 8):
                if lvl >= 5:
                    objs.append(_church(x, y, big=True))
                    gap = 18
                else:
                    objs.append(_church(x, y, spire=lvl >= 3))
                    gap = 14
                used += [(x - 6, y), (x + 6, y), (x, y)]
                for k in range(int(gap / 6)):
                    used.append((x - 12 + k * 6, y - 4))
                break
    if lvl >= 6:
        for x, y, _ in inner:
            if all(_dist((x, y), u) > 16 for u in used) and cv.free(x, y, 24, 10):
                objs.append(_palace(x, y))
                used += [(x - 7, y), (x + 7, y), (x, y)]
                break
    count = 0
    for x, y, r in inner:
        if count >= n:
            break
        if take(x, y, step * 0.82):
            objs.append(_house(cv, x, y, s, rng, roofs, tall=lvl >= 5 and r < 0.3))
            count += 1
    if sub:                                      # suburbs outside the wall
        order = list(cells)                      # try the grid in random order until there are enough
        rng.shuffle(order)
        k = 0
        for gx, gy in order:
            if k >= sub:
                break
            x, y, _ = spot(gx, gy)
            if not inside_test(x, y) and ok(x, y) and take(x, y, step * 0.9):
                objs.append(_house(cv, x, y, s * 0.95, rng, ROOFS[3]))
                k += 1
    if lvl <= 2:
        _fields(cv, rng, 3 if lvl == 1 else 4, rad + 8, 50)
    if coast:
        objs += _piers(cv, coast, lvl, rng)
    return objs


def _castle_objects(cv, level, rng, wall_geo=None):
    """Castle on a mound in the middle of the tile; the gate faces south at (CX, CY + 22)."""
    objs = []
    g = cv.g
    cx, cy = CX, CY + 4
    hill = (88, 166, 84)
    mound(g, cx, cy + 20, 86, 40, hill, shade(hill, 0.25))
    cv.mark(lambda b: b.oval((0, 0, 0, 255), cx, cy, 38, 26))
    col = (200, 194, 180)
    if level == 1:
        mx, my = cx + 8, cy - 4
        objs.append((my - 20, lambda c: mound(c.g, mx, my, 40, 20, (150, 126, 86), (190, 170, 130)), 0))

        def keep(c):
            building(c.o, mx, my - 16, 12, 11, 9, WOOD, DWOOD, "front", rh=7, wins=1)
        objs.append((my - 15, keep, 1))
        ring = [(mx + math.cos(math.radians(a)) * 15, my - 10 + math.sin(math.radians(a)) * 6)
                for a in range(200, 345, 18)]
        objs.append((my - 17, lambda c: [(_wall_segment(c, a, b, 1, col)) for a, b in zip(ring, ring[1:])], 1))
        bailey = [(cx - 10 + math.cos(math.radians(a)) * 20, cy + 10 + math.sin(math.radians(a)) * 10)
                  for a in range(0, 361, 20)]
        back = [q for q in bailey if q[1] < cy + 10]
        front = [q for q in bailey if q[1] >= cy + 10]
        objs.append((cy, lambda c: [_wall_segment(c, a, b, 1, col) for a, b in zip(back, back[1:])], 1))
        for hx, hy in ((cx - 18, cy + 12), (cx - 6, cy + 9)):
            objs.append((hy, lambda c, hx=hx, hy=hy: building(c.o, hx, hy, 9, 6, 7, (166, 120, 80), THATCH, "front"), 1))
        front.sort(key=lambda q: q[0])
        objs.append((cy + 21, lambda c: [_wall_segment(c, a, b, 1, col) for a, b in zip(front, front[1:])
                                          if abs(a[0] - CX) > 4 or abs(b[0] - CX) > 4], 1))
        objs.append((cy + 22, lambda c: flag(c.o, mx + 1, my - 32, 8, (200, 40, 50)), 1))
        return objs
    s = 1.0 if level == 2 else 0.92
    bl, br = (cx - 22 * s, cy - 8 * s), (cx + 22 * s, cy - 8 * s)
    fl, fr = (cx - 24 * s, cy + 16 * s), (cx + 24 * s, cy + 16 * s)
    gate = (cx, cy + 16 * s)
    objs.append((bl[1], lambda c: _wall_segment(c, bl, br, 2, col), 1))
    for q in (bl, br):
        objs.append((q[1] + 0.5, lambda c, q=q: tower(c.o, q[0], q[1], 5, 17, col, ROOF_SLATE, 9, crenel=False), 1))
    objs.append((cy + 3, lambda c: (_wall_segment(c, bl, fl, 2, col), _wall_segment(c, br, fr, 2, col)), 1))

    def keep(c):
        k = (cx + 2, cy + 6)
        c.shadow(k[0] + 4, k[1], 26, a=50)
        building(c.o, k[0], k[1], 16, 22, 12, shade(col, 0.05), shade(col, -0.1), "flat", door=False, wins=2)
        for i in range(5):
            c.o.rect(shade(col, 0.1), k[0] - 8 + i * 3.6, k[1] - 25, 2, 3)
        flag(c.o, k[0] + 2, k[1] - 32, 9, (200, 40, 50) if level == 2 else (40, 70, 170))
    objs.append((cy + 6, keep, 1))
    objs.append((fl[1], lambda c: (_wall_segment(c, fl, (gate[0] - 6, gate[1]), 2, col),
                                   _wall_segment(c, (gate[0] + 6, gate[1]), fr, 2, col)), 1))
    for q in (fl, fr):
        objs.append((q[1] + 0.5, lambda c, q=q: tower(c.o, q[0], q[1], 5.5, 19, col, ROOF_RED, 10), 1))

    def gatehouse(c):
        for dx in (-6, 6):
            tower(c.o, gate[0] + dx, gate[1] + 0.5, 3.6, 14, col, None, crenel=True)
        c.o.poly(shade(col, -0.05), [(gate[0] - 6, gate[1] - 12), (gate[0] + 6, gate[1] - 12),
                                     (gate[0] + 6, gate[1] - 6), (gate[0] - 6, gate[1] - 6)])
        c.o.poly(DARK, ell_arch(gate[0], gate[1], 2.6, 7))
    objs.append((gate[1] + 1, gatehouse, 1))
    if level == 3:
        objs.append((cy - 9, lambda c: flag(c.o, bl[0], bl[1] - 28, 7, (240, 200, 40)), 1))
        objs.append((cy - 9, lambda c: flag(c.o, br[0], br[1] - 28, 7, (240, 200, 40)), 1))
    return objs


def ell_arch(x, y, r, h):
    pts = [(x - r, y), (x - r, y - h + r)]
    for i in range(9):
        a = math.radians(180 + i * 180 / 8)
        pts.append((x + r * math.cos(a), y - h + r + r * math.sin(a)))
    pts += [(x + r, y)]
    return pts


def _mountain_objects(cv, rng, snow=True, n=7):
    """Big two-tone peaks in three rows (back to front), keeping clear of roads and rivers."""
    lit, dark = (178, 182, 190), (118, 122, 138)
    objs, placed = [], []
    for row, (y0, size) in enumerate(((CY - 18, 15), (CY + 8, 16), (CY + 34, 13))):
        x = CX - 46 + rng.uniform(-4, 8)
        while x < CX + 50 and len(placed) < n:
            hw = size * rng.uniform(0.85, 1.15)
            ht = hw * rng.uniform(1.45, 1.8)
            y = y0 + rng.uniform(-4, 4)
            px = x + hw
            x += hw * 2.3 + rng.uniform(0, 6)
            if not (_inside(px - hw * 1.4, y, R - 5) and _inside(px + hw * 1.3, y, R - 5) and _inside(px, y - ht, R - 3)):
                continue
            if any(cv.blocked(px + dx * hw, y + dy * ht) for dx, dy in
                   ((0, 0), (-1, 0), (1, 0), (0, -0.5), (-0.6, -0.3), (0.6, -0.3), (-1.3, 0), (1.2, 0))):
                continue
            placed.append((px, y))

            def peak(c, x=px, y=y, hw=hw, ht=ht):
                top = (x, y - ht)
                left, mid, right = (x - hw * 1.4, y), (x + hw * 0.25, y), (x + hw * 1.3, y)
                c.shadow(x + hw * 0.3, y, hw * 3, hw * 0.6, 40)
                c.o.poly(lit, [left, top, mid])
                c.o.poly(dark, [top, right, mid])
                c.o.line(shade(lit, 0.2), lerp(top, left, 0.15), lerp(top, left, 0.55), 1)
                if snow and ht > 20:
                    k = 0.32
                    a, b, cc = lerp(top, left, k), lerp(top, mid, k * 1.1), lerp(top, right, k)
                    c.o.poly(WHITE, [top, a, lerp(a, b, 0.4), (b[0], b[1] - 2), b])
                    c.o.poly(mix(WHITE, dark, 0.35), [top, b, lerp(b, cc, 0.5), cc])
            objs.append((y, peak, 1))
    return objs


def _marsh(cv, rng):
    g = cv.g
    pools = 0
    for _ in range(60):
        if pools >= 4:
            break
        q = (CX + rng.uniform(-42, 42), CY + rng.uniform(-44, 44))
        rx, ry = rng.uniform(10, 16), rng.uniform(4.5, 7)
        if not (_inside(q[0] - rx - 4, q[1], R - 8) and _inside(q[0] + rx + 4, q[1], R - 8)) or                 any(cv.blocked(q[0] + dx * (rx + 3), q[1] + dy * (ry + 3)) for dx, dy in
                    ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1))):
            continue
        blob = [(q[0] + math.cos(math.radians(a)) * rx * rng.uniform(0.8, 1.15),
                 q[1] + math.sin(math.radians(a)) * ry * rng.uniform(0.8, 1.15)) for a in range(0, 360, 40)]
        blob = _chaikin(blob, 2, True)
        g.poly((58, 118, 96), [(x + 0.6, y + 1) for x, y in blob])
        g.poly(mix(WATER, (90, 150, 120), 0.3), blob)
        g.line(mix(WATER_L, WHITE, 0.3), (q[0] - rx * 0.4, q[1] - ry * 0.3), (q[0] + rx * 0.1, q[1] - ry * 0.3), 0.8)
        cv.mark(lambda b, blob=blob: b.poly((0, 0, 0, 255), blob))
        pools += 1
    for _ in range(26):
        q = (CX + rng.uniform(-50, 50), CY + rng.uniform(-52, 52))
        if not _inside(q[0], q[1] - 6, R - 7) or cv.blocked(*q):
            continue
        for k in range(5):
            tip = (q[0] + (k - 2) * 1.7, q[1] - 5 - (k % 2) * 2)
            g.line((60, 112, 58), (q[0] + (k - 2) * 0.6, q[1]), tip, 0.9)
        g.oval((120, 80, 50), q[0] + 1.6, q[1] - 6.5, 0.8, 1.6)


# ===================================================================================================
# composition
# ===================================================================================================
def _compose(desc):
    """Draw the overlay for desc on a 2x canvas and return the canvas (not yet masked / scaled)."""
    cv = Canvas()
    rng = _rng("tile", desc)
    if desc.base in SEA_BASES:
        _paint_sea(cv, desc.base, desc.variant)
        return cv
    # a harbour gets a deeper bay; the shoreline still crosses the edges at the same points
    coast = _coast_geo(desc.sea, desc.variant, COAST_RD - 8 if desc.town else COAST_RD) if desc.sea else None
    river = _river_geo(desc, coast)
    road = _road_geo(desc, river)
    wl = wall_level(desc)
    wall = _wall_geo(desc, road, wl) if wl else None
    if coast:
        _paint_coast_sand(cv, coast)
    if river:
        _paint_river_bank(cv, river)
    if coast:
        _paint_coast_water(cv, coast)
    if road and desc.crossing == "ferry":
        _paint_road(cv, road, rng)
    if river:
        _paint_river_water(cv, river, rng)
        _mark_river(cv, river)
    if wall:
        _paint_glacis(cv, wall)
    if desc.base == "marsh":
        _marsh(cv, rng)
    objs = []
    if road:
        if desc.crossing != "ferry":
            _paint_road(cv, road, rng)
        _mark_road(cv, road)
        objs += _crossing_objects(cv, road, river, desc.crossing)
    if wall:
        objs += _wall_objects(cv, wall, coast["water"] if coast else None)
        _mark_wall(cv, wall)
    if desc.castle:
        objs += _castle_objects(cv, desc.castle, rng)
    if desc.town:
        objs += _settlement_objects(cv, desc, wall, coast, rng)
    if desc.base == "mountains":
        objs += _mountain_objects(cv, rng, n=6 if desc.road else 9)
    _draw_objects(cv, [o for o in objs if o])
    return cv


_CACHE = BoundedCache("wfctiles.tiles", 1024)        # about 590 tiles cover Europe at zoom 3 (67 KB each)


@_CACHE.memo
def overlay(desc):
    """Transparent 120 x 140 overlay for a TileDesc (sea tiles are opaque). Cached."""
    return _compose(desc).finish()


@BoundedCache("wfctiles.bases", 64).memo
def base_tile(kind, tiles_dir=None):
    """The base picture for a land kind: the Kenney pack tile when tiles_dir (".../PNG/Tiles") is given, else flat."""
    img = None
    if tiles_dir and kind in BASE_SPRITES:
        import os
        path = os.path.join(tiles_dir, "Terrain", *BASE_SPRITES[kind].split("/")) + ".png"
        if os.path.exists(path):
            img = pygame.image.load(path)
            img = img.convert_alpha() if pygame.display.get_surface() else img
    if img is None:
        img = pygame.Surface((W, H), pygame.SRCALPHA)
        pygame.draw.polygon(img, BASE_COLOURS.get(kind, GRASS), hex_pts(R))
    return img


def render_tile(desc, tiles_dir=None):
    """Full 120 x 140 tile: base terrain (Kenney / goodsart / flat) with the overlay composed at 2x. Cached."""
    key = ("full", desc, tiles_dir)
    hit = _CACHE.get(key)
    if hit is not None:
        return hit
    cv = _compose(desc)
    if desc.base in SEA_BASES:
        out = cv.finish()
    else:
        if desc.good:
            from hexa.campaign.goodsart import good_tile
            base = good_tile(desc.good[0], desc.good[1], tiles_dir, desc.variant)
        else:
            # a castle brings its own hill, so it sits on grass rather than the pack's rocky hills
            base = base_tile("plains" if desc.castle and desc.base == "hills" else desc.base, tiles_dir)
        under = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        rim = base.get_at((1, H // 2))                 # pad the base past the hex so tiles overlap seamlessly
        pygame.draw.polygon(under, rim[:3], [(x * K, y * K) for x, y in hex_pts(MASK_R + 1)])
        under.blit(pygame.transform.smoothscale(_bleed(base), (W * K, H * K)), (0, 0))
        out = cv.finish(under)
    return _CACHE.put(key, out)


# ----- convenience wrappers (all cached through overlay()) -----------------------------------------------
def sea_tile(kind="sea", variant=0):
    """Open water ("sea"), a sandbank in shallows ("shallow") or rocks ("reef"). Edges are plain water."""
    return overlay(TileDesc(base=kind, variant=variant))


def coast_overlay(sea_edges, variant=0):
    """Sea filling the sectors of sea_edges with a beach; any of the 64 masks (6 = an islet)."""
    return overlay(TileDesc(sea=_fs(sea_edges), variant=variant))


def river_overlay(edges, variant=0, mouth=False, lake=False, sea_edges=()):
    """River through edges: 1 = spring, 2 = straight / bend, 3 = confluence; mouth widens into sea_edges' sea
    (drawn too); lake ends the river(s) in a lake (0 edges = pond)."""
    return overlay(TileDesc(river=_fs(edges), mouth=mouth, lake=lake, sea=_fs(sea_edges), variant=variant))


def road_overlay(edges, variant=0, kind="dirt", river_edges=(), crossing="bridge"):
    """Road through edges (1 = dead end); with river_edges the river is NOT drawn but bridges / fords / ferries are
    placed where the road crosses it, so draw river_overlay(river_edges) underneath."""
    edges = _fs(edges)
    d = TileDesc(road=edges, paved=edges if kind == "paved" else frozenset(), river=_fs(river_edges),
                 crossing=crossing, variant=variant)
    key = ("road", d)
    out = _CACHE.get(key)
    if out is None:
        cv = Canvas()
        river = _river_geo(d, None)
        road = _road_geo(d, river)
        if crossing != "ferry" or not river:
            _paint_road(cv, road, _rng("tile", d))
        _draw_objects(cv, _crossing_objects(cv, road, river, crossing))
        out = _CACHE.put(key, cv.finish())
    return out


def wall_overlay(inside=(), level=2, gates=(), variant=0):
    """Town wall (1 palisade, 2 stone with towers, 3 star fort) round the tile; `inside` edges lead to other hexes of
    the same town (the wall crosses them near the corners); `gates` are road edges (roads are drawn, with gates)."""
    return overlay(TileDesc(town_in=_fs(inside), wall=level, road=_fs(gates), variant=variant))


def settlement_tile(level, variant=0, road_edges=(), sea_edges=(), river_edges=(), town_in=(), paved=None):
    """Hamlet (1) .. great city (6); streets come in from road_edges; sea_edges make it a harbour."""
    roads = _fs(road_edges)
    paved = roads if (paved is None and level >= 3) else _fs(paved)
    return overlay(TileDesc(town=level, road=roads, paved=paved, sea=_fs(sea_edges), river=_fs(river_edges),
                            town_in=_fs(town_in), variant=variant))


def castle_tile(level, variant=0, road_edges=()):
    """Motte and bailey (1), stone castle (2), fortress (3) on a mound; roads lead to the south gate."""
    return overlay(TileDesc(castle=level, road=_fs(road_edges), variant=variant))


def lake_overlay(river_edges=(), variant=0):
    return overlay(TileDesc(lake=True, river=_fs(river_edges), variant=variant))


def marsh_overlay(river_edges=(), variant=0):
    return overlay(TileDesc(base="marsh", river=_fs(river_edges), variant=variant))


def mountain_overlay(road_edges=(), variant=0, river_edges=()):
    """Peaks (draw over a stone / grass base); with road_edges it is a mountain pass."""
    return overlay(TileDesc(base="mountains", road=_fs(road_edges), river=_fs(river_edges), variant=variant))


def harbour_tile(sea_edges, level=3, road_edges=(), variant=0):
    return settlement_tile(level, variant, road_edges, sea_edges)


# ===================================================================================================
# socket-aware wave function collapse
# ===================================================================================================
def socket_collapse(cells, tiles, weight, rng, sockets=edge_sockets, fits=compatible, fixed=None, tries=10):
    """WFC where tile a at p and tile b across edge e must satisfy fits(sockets(a)[e], sockets(b)[e + 3]).

    cells: positions; tiles: candidate tiles (hashable); weight(pos, tile) -> prior weight (0 = not allowed);
    fixed: {pos: tile}. Neighbours come from hexgrid.neighbors (edge order). Restarts on a contradiction.
    Returns {pos: tile} or None."""
    cells = list(cells)
    cellset = set(cells)
    tiles = list(tiles)
    n = len(tiles)
    socks = [sockets(t) for t in tiles]
    supp = [[0] * n for _ in range(6)]
    for e in range(6):
        for i in range(n):
            m = 0
            for j in range(n):
                if fits(socks[i][e], socks[j][(e + 3) % 6]):
                    m |= 1 << j
            supp[e][i] = m
    near = {p: [q if q in cellset else None for q in hexgrid.neighbors(p)] for p in cells}
    w = {p: [max(0.0, weight(p, t)) for t in tiles] for p in cells}
    cache = {}

    def allowed(e, mask):
        key = (e, mask)
        got = cache.get(key)
        if got is None:
            got, m, i = 0, mask, 0
            while m:
                if m & 1:
                    got |= supp[e][i]
                m >>= 1
                i += 1
            cache[key] = got
        return got

    for _ in range(tries):
        dom = {}
        for p in cells:
            m = 0
            for i in range(n):
                if w[p][i] > 0:
                    m |= 1 << i
            dom[p] = m
        for p, t in (fixed or {}).items():
            if p in dom:
                dom[p] = 1 << tiles.index(t)

        def propagate(queue):
            while queue:
                p = queue.pop()
                for e, q in enumerate(near[p]):
                    if q is None:
                        continue
                    nd = dom[q] & allowed(e, dom[p])
                    if nd != dom[q]:
                        if not nd:
                            return False
                        dom[q] = nd
                        queue.append(q)
            return True

        if not propagate(list(cells)):
            continue
        result = {}
        failed = False
        while len(result) < len(cells):
            best, bc = None, None
            for p in cells:
                if p in result:
                    continue
                c = bin(dom[p]).count("1") + rng.random() * 0.5
                if bc is None or c < bc:
                    best, bc = p, c
            p = best
            opts = [i for i in range(n) if dom[p] >> i & 1]
            ws = [w[p][i] or 1e-6 for i in opts]
            i = rng.choices(opts, ws)[0]
            dom[p] = 1 << i
            result[p] = tiles[i]
            if not propagate([p]):
                failed = True
                break
        if not failed:
            return result
    return None


# ===================================================================================================
# demo generator
# ===================================================================================================
_SEA, _ALLMASKS = "sea", [frozenset(e for e in range(6) if m >> e & 1) for m in range(64)]


def _coast_sockets(t):
    """Stage-1 sockets: "S" sea tile, "s" a land tile's sea edge (must face a sea tile), "L.." land with flags."""
    if t == _SEA:
        return ("S",) * 6
    return tuple("s" if e in t else "L" + _flags(e, t) for e in range(6))


def _coast_fits(a, b):
    if a == "S":
        return b in ("S", "s")
    if a == "s":
        return b == "S"
    return b != "S" and b != "s" and _mirror(a) == b


def _smooth_field(cols, rows, rng, n=7, amp=0.35, sigma=0.28):
    blobs = [(rng.uniform(-0.2, 1.2), rng.uniform(-0.2, 1.2), rng.uniform(-amp, amp)) for _ in range(n)]

    def f(x, y):
        return sum(a * math.exp(-((x - bx) ** 2 + (y - by) ** 2) / (2 * sigma * sigma)) for bx, by, a in blobs)
    return f


def _norm_xy(pos, cols, rows):
    x, y = hexgrid.hex_center(pos)
    return x / (cols * hexgrid.HEX_W), y / (rows * hexgrid.ROW_H)


def _dijkstra(starts, is_goal, step, rng):
    dist = {s: 0.0 for s in starts}
    prev = {}
    heap = [(0.0, rng.random(), s) for s in starts]
    heapq.heapify(heap)
    while heap:
        d, _, p = heapq.heappop(heap)
        if d > dist.get(p, 1e18):
            continue
        if is_goal(p) and p not in starts:
            path = [p]
            while path[-1] in prev:
                path.append(prev[path[-1]])
            return path[::-1]
        for q in hexgrid.neighbors(p):
            c = step(p, q)
            if c is None:
                continue
            nd = d + c
            if nd < dist.get(q, 1e18):
                dist[q] = nd
                prev[q] = p
                heapq.heappush(heap, (nd, rng.random(), q))
    return None


def _edge(a, b):
    return list(hexgrid.neighbors(a)).index(b)


def generate_patch(cols=14, rows=10, seed=0):
    """A small map {pos: TileDesc} whose edge sockets all match: coast with bays and a peninsula (socket WFC),
    terrain (wfc.collapse), rivers from the hills to the sea with a confluence, a lake, roads linking a two-hex
    walled city, a harbour town, villages and a castle, bridges / fords where roads cross rivers."""
    for attempt in range(12):
        out = _generate(cols, rows, seed * 101 + attempt)
        if out is not None:
            return out
    raise RuntimeError("could not generate a patch")


def _generate(cols, rows, seed):
    rng = random.Random(seed)
    cells = [(c, r) for r in range(rows) for c in range(cols)]
    cellset = set(cells)
    # ---- 1. land / sea: socket WFC with a smooth prior --------------------------------------------------
    th = rng.uniform(0, 2 * math.pi)
    sx, sy = math.cos(th), math.sin(th)
    noise = _smooth_field(cols, rows, rng)
    pen_t = rng.uniform(-0.25, 0.25)                 # peninsula: a ridge pointing out to sea
    pen_perp = (-sy, sx)
    bays = [(rng.uniform(-0.35, 0.35), rng.uniform(0.08, 0.14)) for _ in range(2)]

    def land_value(pos):
        x, y = _norm_xy(pos, cols, rows)
        x, y = x - 0.5, y - 0.5
        d = x * sx + y * sy                          # distance towards the sea side
        along = x * pen_perp[0] + y * pen_perp[1]
        v = 0.12 - d + noise(x + 0.5, y + 0.5)
        v += 0.55 * math.exp(-((along - pen_t) ** 2) / (2 * 0.075 ** 2)) * (1 if -0.1 < d < 0.42 else 0.2)
        for bt, bw in bays:
            if abs(bt - pen_t) > 0.18:
                v -= 0.32 * math.exp(-((along - bt) ** 2) / (2 * bw ** 2) - ((d - 0.08) ** 2) / (2 * 0.12 ** 2))
        return v

    lv = {}

    def land_p(pos):
        if pos not in lv:
            lv[pos] = 1 / (1 + math.exp(-14 * land_value(pos)))
        return lv[pos]

    tiles = [_SEA] + _ALLMASKS

    def weight(p, t):
        lp = land_p(p)
        if t == _SEA:
            return 1 - lp
        wgt = lp
        for e, q in enumerate(hexgrid.neighbors(p)):
            sp = 1 - land_p(q)
            wgt *= sp if e in t else (1 - sp)
        return wgt
    res = socket_collapse(cells, tiles, weight, rng, _coast_sockets, _coast_fits)
    if res is None:
        return None
    sea = {p for p, t in res.items() if t == _SEA}
    # small enclosed seas become lakes
    lakes = set()
    seen = set()
    for p in sea:
        if p in seen:
            continue
        comp, stack = [], [p]
        seen.add(p)
        while stack:
            q = stack.pop()
            comp.append(q)
            for n in hexgrid.neighbors(q):
                if n in sea and n not in seen:
                    seen.add(n)
                    stack.append(n)
        border = any(n not in cellset for q in comp for n in hexgrid.neighbors(q))
        if len(comp) <= 2 and not border:
            lakes |= set(comp)
    sea -= lakes
    land = [p for p in cells if p not in sea]
    if len(land) < len(cells) * 0.4 or len(sea) < len(cells) * 0.15:
        return None
    seamask = {}
    for p in land:
        m = set()
        for e, q in enumerate(hexgrid.neighbors(p)):
            if q in sea or (q not in cellset and e in res[p]):
                m.add(e)
        seamask[p] = frozenset(m)
    coast = {p for p in land if seamask[p]}
    # ---- 2. elevation and terrain (wfc.collapse) --------------------------------------------------------------
    dist = {p: 0 for p in coast}
    frontier = list(coast)
    while frontier:
        nxt = []
        for p in frontier:
            for q in hexgrid.neighbors(p):
                if q in cellset and q not in sea and q not in dist:
                    dist[q] = dist[p] + 1
                    nxt.append(q)
        frontier = nxt
    for p in land:
        dist.setdefault(p, 3)
    hn = _smooth_field(cols, rows, rng, n=6, amp=1.2, sigma=0.22)
    elev = {p: dist[p] + hn(*_norm_xy(p, cols, rows)) + rng.uniform(0, 0.6) for p in land}
    emax = max(elev.values()) or 1
    dry = _smooth_field(cols, rows, rng, n=3, amp=1.0, sigma=0.2)

    def prior(p):
        t = max(0.0, elev[p] / emax)
        dx = dry(*_norm_xy(p, cols, rows))
        w = {"plains": 3.0 * (1 - t) + 0.4, "forest": 1.6, "hills": 4 * t * t,
             "mountains": 6 * max(0.0, t - 0.72), "marsh": 0.9 if (p in coast or t < 0.2) else 0.02,
             "desert": max(0.0, dx) * 3}
        if p in coast:
            w["mountains"] = 0
            w["hills"] *= 0.3
        if p in lakes:
            w = {"plains": 1.0}
        return w
    forbidden = [("marsh", "mountains"), ("marsh", "hills"), ("marsh", "desert"), ("desert", "forest"),
                 ("mountains", "plains"), ("desert", "mountains")]
    terrain = wfc.collapse(land, {p: prior(p) for p in land}, forbidden,
                           lambda p: hexgrid.neighbors(p), rng, affinity=1.6)
    for p in lakes:
        terrain[p] = "plains"
    # ---- 3. rivers ------------------------------------------------------------------------------------------
    river = {p: set() for p in land}
    mouths, lake_cells = set(), set(lakes)
    rivered = set()

    def add_path(path):
        for a, b in zip(path, path[1:]):
            e = _edge(a, b)
            river[a].add(e)
            river[b].add((e + 3) % 6)
        rivered.update(path)

    def rstep(a, b):
        rise = elev[b] - elev[a]
        return 1.0 + max(0.0, rise) * 3 + (0.6 if terrain[b] == "mountains" else 0) + rng.random() * 0.3

    inland = sorted([p for p in land if p not in coast and p not in lakes], key=lambda p: -elev[p])
    sources = []
    for p in inland:
        if all(hexgrid.distance(p, s) >= 4 for s in sources) and min((hexgrid.distance(p, c) for c in coast),
                                                                       default=0) >= 3:
            sources.append(p)
        if len(sources) == 2:
            break
    if len(sources) < 2:
        return None
    made = 0
    for k, s in enumerate(sources):
        def goal(p, k=k):
            if p in coast and p not in lakes:
                return len(seamask[p]) <= 4
            if p in lake_cells:
                return k > 0                         # the first river always reaches the sea
            return k > 0 and p in rivered and len(river[p]) == 2 and p not in mouths
        def step(a, b, goal=goal):
            if b not in cellset or b in sea:
                return None
            if (b in coast or b in rivered or b in lake_cells) and not goal(b):
                return None
            if a != s and a in rivered:
                return None
            return rstep(a, b)
        path = _dijkstra([s], goal, step, rng)
        if not path or len(path) < 3:
            continue
        end = path[-1]
        add_path(path)
        made += 1
        if end in coast:
            mouths.add(end)
    if made < 2:
        return None
    # a short stream into a lake (make one if the coast WFC left none)
    if not lake_cells:
        cand = [p for p in land if p not in coast and p not in rivered and terrain[p] in ("plains", "forest", "marsh")
                and all(q in cellset and q not in rivered and q not in sea for q in hexgrid.neighbors(p))]
        if cand:
            lp = rng.choice(cand)
            lake_cells.add(lp)
            terrain[lp] = "plains"
    for lp in sorted(lake_cells)[:1]:                # one stream feeds a lake
        if river[lp]:
            continue
        cand = [p for p in land if 2 <= hexgrid.distance(p, lp) <= 3 and p not in rivered and p not in coast
                and p not in lake_cells and all(hexgrid.distance(p, q) >= 2 for q in rivered)]
        cand.sort(key=lambda p: -elev[p])
        for s in cand[:4]:
            def step(a, b, lp=lp):
                if b not in cellset or b in sea or b in coast or (b in rivered) or (b in lake_cells and b != lp):
                    return None
                if any(n in rivered for n in hexgrid.neighbors(b)) and b != lp:
                    return 3.0
                return 1.0
            path = _dijkstra([s], lambda p, lp=lp: p == lp, step, rng)
            if path and len(path) <= 4:
                add_path(path)
                break
    # ---- 4. settlements ------------------------------------------------------------------------------------------
    blocked = rivered | lake_cells
    town, town_in, castle = {}, {}, {}

    def far(p, d):
        return all(hexgrid.distance(p, q) >= d for q in list(town) + list(castle))
    good_land = [p for p in land if p not in lake_cells and terrain[p] in ("plains", "forest", "desert", "hills")]
    harb = [p for p in coast if p not in blocked and p not in mouths and 1 <= len(seamask[p]) <= 3
            and sum(1 for q in hexgrid.neighbors(p) if q in cellset and q not in sea) >= 3]
    if harb:
        harb.sort(key=lambda p: (terrain[p] != "plains", rng.random()))
        town[harb[0]] = 3
    pairs = []
    for p in good_land:
        if p in coast or p in blocked:
            continue
        for e, q in enumerate(hexgrid.neighbors(p)):
            if q in cellset and q in good_land and q not in coast and q not in blocked and p < q:
                score = sum(1 for n in list(hexgrid.neighbors(p)) + list(hexgrid.neighbors(q)) if n in rivered)
                score += (terrain[p] == "plains") + (terrain[q] == "plains") + rng.random()
                pairs.append((score, p, q, e))
    pairs.sort(reverse=True)
    for score, p, q, e in pairs:
        if far(p, 3) and far(q, 3):
            town[p], town[q] = 5, 4
            town_in[p], town_in[q] = {e}, {(e + 3) % 6}
            terrain[p] = terrain[q] = "plains"
            break
    hills = [p for p in land if terrain[p] == "hills" and p not in blocked and p not in coast]
    rng.shuffle(hills)
    for p in hills:
        if far(p, 3):
            castle[p] = 2
            break
    vill = [p for p in good_land if p not in coast and p not in lake_cells and (p not in rivered or len(river[p]) == 2)
            and terrain[p] != "hills"]
    rng.shuffle(vill)
    nv = 0
    for p in vill:
        if nv >= 4:
            break
        if far(p, 3):
            town[p] = rng.choice((1, 2, 2))
            if terrain[p] == "forest":
                terrain[p] = "plains"
            nv += 1
    if not town_in or not castle or nv < 2:
        return None
    # ---- 5. roads (Prim's tree over Dijkstra paths) ---------------------------------------------------------
    road = {p: set() for p in land}
    paved = {p: set() for p in land}
    sites = [p for p in town if town[p] >= 4][:1] + [p for p in town if town[p] < 4 or p not in town_in] + list(castle)
    sites = list(dict.fromkeys(sites))
    network = {sites[0]} | {q for q in town_in}
    todo = [s for s in sites if s not in network]
    cost_t = {"plains": 1.0, "desert": 1.3, "forest": 1.8, "hills": 2.4, "marsh": 3.0, "mountains": 4.0}
    while todo:
        best = None
        for target in todo:
            def rstep2(a, b, target=target):
                if b not in cellset or b in sea or b in lake_cells:
                    return None
                if b in river and len(river[b]) == 1 and b != target:
                    return None
                if b in mouths:
                    return None
                if b in castle and b != target:
                    return None
                if _edge(a, b) in river[a]:
                    return None
                c = cost_t[terrain[b]]
                if river[b]:
                    if len(river[b]) != 2:
                        return None
                    c += 2.5
                if road[b]:
                    c *= 0.45
                if b in town and b != target and b not in network:
                    c += 1.5
                if len(seamask.get(b, ())) >= 4:
                    c += 3
                return c
            path = _dijkstra(list(network), lambda p, t=target: p == t, rstep2, rng)
            if path:
                cost = len(path)
                if best is None or cost < best[0]:
                    best = (cost, target, path)
        if best is None:
            return None
        _, target, path = best
        is_paved = town.get(target, 0) >= 3
        for a, b in zip(path, path[1:]):
            e = _edge(a, b)
            road[a].add(e)
            road[b].add((e + 3) % 6)
            if is_paved:
                paved[a].add(e)
                paved[b].add((e + 3) % 6)
        network |= set(path)
        todo.remove(target)
    # the two halves of the walled city are joined by a street
    for p, ins in town_in.items():
        for e in ins:
            road[p].add(e)
            paved[p].add(e)
    # ---- 6. goods art on a few untouched cells ---------------------------------------------------------------
    goods = {}
    plain = [p for p in land if p not in coast and not river[p] and not road[p] and p not in town and p not in castle
             and p not in lake_cells]
    rng.shuffle(plain)
    want = {"plains": ["grain", "wool", "cattle", "horses"], "hills": ["wine"], "mountains": ["iron"]}
    for p in plain:
        if len(goods) >= 4:
            break
        opts = want.get(terrain[p])
        if opts and all(hexgrid.distance(p, q) >= 2 for q in goods):
            goods[p] = (rng.choice(opts), rng.randint(2, 4))
    # ---- 7. tile descriptions --------------------------------------------------------------------------------
    patch = {}
    for p in cells:
        v = rng.randrange(3)
        if p in sea:
            shallow = any(q in cellset and q not in sea for q in hexgrid.neighbors(p)) and rng.random() < 0.18
            patch[p] = TileDesc(base="shallow" if shallow else "sea", variant=v)
            continue
        base = terrain[p]
        if p in castle:
            base = "hills"
        cross = "bridge" if (paved[p] or rng.random() < 0.7) else "ford"
        patch[p] = TileDesc(base=base, sea=seamask[p], river=frozenset(river[p]), mouth=p in mouths,
                            lake=p in lake_cells, road=frozenset(road[p]), paved=frozenset(paved[p]),
                            crossing=cross, town=town.get(p, 0), town_in=frozenset(town_in.get(p, ())),
                            castle=castle.get(p, 0), good=goods.get(p), variant=v)
    if check_patch(patch):
        return None
    return patch


def scale_tile(img, w, h):
    """Smooth-scale a tile or overlay without dark edges (bleeds edge colours into transparent pixels first).
    Use this instead of a bare smoothscale when drawing these tiles at map zoom."""
    return pygame.transform.smoothscale(_bleed(img), (max(1, int(w)), max(1, int(h))))


def render_patch(patch, tiles_dir=None, tile_w=60, margin=10):
    """Draw a {pos: TileDesc} patch with tiles scaled to tile_w wide (the hexgrid layout)."""
    cols = max(c for c, _ in patch) + 1
    rows = max(r for _, r in patch) + 1
    s = tile_w / hexgrid.HEX_W
    tw, th = tile_w, round(tile_w * H / W)
    surf = pygame.Surface((int((cols + 0.5) * hexgrid.HEX_W * s) + 2 * margin,
                           int(((rows - 1) * hexgrid.ROW_H + hexgrid.HEX_H) * s) + 2 * margin), pygame.SRCALPHA)
    scaled = {}
    for p in sorted(patch, key=lambda q: (q[1], q[0])):
        d = patch[p]
        if d not in scaled:
            scaled[d] = scale_tile(render_tile(d, tiles_dir), tw + 1, th + 1)
        x, y = hexgrid.hex_center(p)
        surf.blit(scaled[d], (round(margin + x * s - tw / 2), round(margin + y * s - th / 2)))
    return surf


__all__ = ["TileDesc", "tile", "edge_sockets", "compatible", "check_patch", "river_ends", "socket_collapse",
           "generate_patch", "render_patch", "scale_tile", "render_tile", "overlay", "base_tile", "sea_tile", "coast_overlay",
           "river_overlay", "road_overlay", "wall_overlay", "settlement_tile", "castle_tile", "lake_overlay",
           "marsh_overlay", "mountain_overlay", "harbour_tile", "normal", "edge_mid", "corner", "draw_edge", "opposite"]
