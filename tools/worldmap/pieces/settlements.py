"""Settlements, levels 1-5 (reference family; see docs/design/map/pieces/GUIDE.md).

1 hamlet - 2 village (chapel) - 3 town (palisade, church) - 4 walled town (stone wall, towers) - 5 city (cathedral,
suburbs). No name plate and no plate strip: the ground in front of the place is ordinary ground. The piece draws
no wild trees or bushes (the map's); only the fruit trees by the houses are planted. Roads end at GATES.

Two layouts (LAYOUT) and the mirror. Layout 0: the place round the middle of the hex, a round ring wall, the church
in the middle. Layout 1: a long oval town lying from the lower left to the upper right (its ring is turned in the
plan), the church and its green at the west end, the gardens in the free corners to the north-west and south-east.

python settlements.py      writes docs/design/map/pieces/settlements.png and settlements_variants.png
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(1, 6)
NAMES = {1: "hamlet", 2: "village", 3: "town", 4: "walled town", 5: "city"}
VARIANTS = 2
CX, CY = 0, -7                                        # layout 0: the middle of the place, the same in every level
# Where the map's road layer joins the place's roads (unmirrored, 10+ px inside the border). The south one serves
# every level, the east one from level 2, the west one from level 4. One table per layout.
GATES = [{"south": (-5, 36), "east": (40, 3), "west": (-40, 3)},
         {"south": (-10, 34), "east": (40, -5), "west": (-40, 6)}]

#        houses, ring rx, ry, wall kind   (layout 0)
SPEC = {1: (3, 0, 0, None), 2: (7, 0, 0, None), 3: (11, 25, 14, "palisade"), 4: (16, 31, 17, "stone"), 5: (24, 38, 20.5, "stone")}
#        houses, ring a, b (half axes in the plan, before the tilt), wall kind   (layout 1)
SPEC1 = {1: (3, 0, 0, None), 2: (7, 0, 0, None), 3: (11, 28, 14.5, "palisade"), 4: (16, 34, 17.5, "stone"), 5: (24, 40, 21, "stone")}
RC1 = (2, -6)                                         # layout 1: the middle of the oval ring (the same in every level)
ROT1 = -24.0                                          # layout 1: the ring lies from the lower left to the upper right
LM1 = (-16, -8)                                       # layout 1: the landmark's base: the well, chapel, church and cathedral stand on it
HAM1 = (-10, -9)                                       # layout 1: the middle of the hamlet's houses (the first houses are the nearest)


def _sites():
    """House sites, the same list for every level: sorted from the middle outward, so a bigger place keeps every
    house of the smaller one and adds a ring round it. The green in front of the church stays free."""
    rnd = random.Random(11)
    out = []
    tries = 0
    while len(out) < 40 and tries < 6000:
        tries += 1
        a, d = rnd.uniform(0, 2 * math.pi), math.sqrt(rnd.random())
        x, y = CX + math.cos(a) * 34 * d, CY + 1.5 + math.sin(a) * 17.5 * d
        if -11 < x - CX < 13 and y - CY > -5:              # the church and its green: nothing stands in front of it
            continue
        if any(abs(x - q[0]) < 6.6 and abs(y - q[1]) < 3.6 for q in out):
            continue
        out.append((x, y))
    key = lambda q: ((q[0] - CX) / 34) ** 2 + ((q[1] - CY - 1.5) / 17.5) ** 2
    return sorted(out, key=key)


def _sites1(seed=56):
    """Layout 1: sites in the turned oval, sorted from the hamlet's middle outward (same rule as layout 0). The green
    at the west end (the church and the lane in front of it) stays free."""
    rnd = random.Random(seed)
    th = math.radians(ROT1)
    c, s = math.cos(th), math.sin(th)
    out = []
    tries = 0
    while len(out) < 40 and tries < 6000:
        tries += 1
        a, d = rnd.uniform(0, 2 * math.pi), math.sqrt(rnd.random())
        u, v = math.cos(a) * 35.5 * d, math.sin(a) * 19.5 * d
        x, y = RC1[0] + u * c - v * s, RC1[1] + 1.5 + (u * s + v * c) * kit.TILT
        if -10 < x - LM1[0] < 12 and y - LM1[1] > -4:     # the church and its green: nothing stands in front of it
            continue
        if any(abs(x - q[0]) < 6.6 and abs(y - q[1]) < 3.6 for q in out):
            continue
        out.append((x, y))

    def key(q):                                       # nearer the ring's middle first, with a pull towards the church
        def d(o, a, b):
            dx, dy = q[0] - o[0], (q[1] - o[1]) / kit.TILT
            return math.hypot((dx * c + dy * s) / a, (-dx * s + dy * c) / b)
        return d(RC1, 34, 19) + 0.45 * d(HAM1, 34, 19)
    return sorted(out, key=key)


# One table per layout. houses: sites (the first n of the level); suburb: level 5 houses outside the wall;
# plots: cx, cy, w, h, angle, strips, from level, to level (gardens); trees: fruit trees (planted) x, y, size,
# from level, to level, style; lm: the landmark's base (well +1,+5; chapel -1,+5; church -1,+6; cathedral -1.5,+8).
LAYOUT = [
    dict(
        sites=_sites(), lm=(CX, CY),
        suburb=[(-33, 19), (-25, 22), (30, 20), (37, 16)],
        plots=[
            (-22, 9, 14, 9, 8, 3, 1, 2), (20, -20, 14, 8, -6, 3, 1, 2), (24, 8, 15, 9, -8, 3, 2, 2), (-24, -17, 14, 8, 6, 3, 2, 2),
            (-35, 6, 12, 9, 80, 3, 3, 4), (36, 4, 12, 9, 96, 3, 3, 4), (-20, 21, 14, 7, 6, 3, 3, 4), (22, 21, 14, 7, -6, 3, 3, 4),
        ],
        trees=[(10, 17, 0.9, 1, 2, 3), (-15, 12, 0.9, 1, 2, 4), (-30, 16, 0.9, 3, 4, 8), (32, 16, 0.9, 3, 4, 9)],
    ),
    dict(
        sites=_sites1(), lm=LM1,
        suburb=[(-31, -13), (-23, -20), (29, 20), (37, 13)],
        plots=[
            (-29, -13, 13, 8, -24, 3, 1, 2), (-12, -24, 14, 8, 8, 3, 1, 2), (28, 14, 13, 8, -20, 3, 2, 2), (-4, 21, 14, 7, 6, 3, 2, 2),
            (-29, -14, 13, 8, -26, 3, 3, 4), (-11, -25, 14, 8, 6, 3, 3, 4), (27, 17, 14, 8, -22, 3, 3, 4), (13, 28, 14, 7, 4, 3, 3, 4),
        ],
        trees=[(-3, 8, 0.9, 1, 2, 3), (-26, 4, 0.9, 1, 2, 4), (-39, -8, 0.9, 3, 4, 8), (37, 24, 0.9, 3, 4, 9)],
    ),
]
SITES = LAYOUT[0]["sites"]                                   # kept for the tools that read them
SUBURB = LAYOUT[0]["suburb"]
PLOTS = LAYOUT[0]["plots"]
TREES = LAYOUT[0]["trees"]


def well(p, x, y):
    def fn(pen):
        pen.ellipse(x, y - 1, 3.6, 2.4, kit.STONE_GREY, kit.INK, 0.5)
        pen.line((x - 1.8, y - 1), (x - 1.8, y - 5), kit.TIMBER_D, 0.5)
        pen.line((x + 1.8, y - 1), (x + 1.8, y - 5), kit.TIMBER_D, 0.5)
        pen.poly([(x - 2.8, y - 4.6), (x + 2.8, y - 4.6), (x, y - 6.6)], kit.THATCH_D if not p.winter else kit.SNOW, kit.INK, 0.5)
    return p.stand(y, fn)


# ------------------------------------------------------------------ layout 1: the ring wall turned in the plan
def ring_arcs(cx, cy, a, b, rot, n=96):
    """A ring wall's outline turned by `rot` degrees in the plan (then tilted), as two arcs from the right end to the
    left end: the front one through the bottom, the back one through the top. Unmirrored."""
    th = math.radians(rot)
    c, s = math.cos(th), math.sin(th)
    pts = []
    for q in range(n):
        t = 2 * math.pi * q / n
        u, v = a * math.cos(t), b * math.sin(t)
        pts.append((cx + u * c - v * s, cy + (u * s + v * c) * kit.TILT))
    i = max(range(n), key=lambda q: pts[q][0])
    pts = pts[i:] + pts[:i]
    return pts[:n // 2 + 1], pts[n // 2:] + [pts[0]]


def rot_wall(p, cx, cy, a, b, rot, kind, towers=(), back_towers=(), height=4.0):
    """kit.wall for a ring turned in the plan. The kit's own wall is an upright ellipse; this one is drawn from
    outline points. The geometry is worked out unmirrored and every point is turned round when the piece is
    mirrored (the kit moves a standing thing, it cannot turn a lopsided ring), so the whole ring is queued with
    x=0 (no move of its own). Returns (front handle, the gate point, the right-most point)."""
    front, back = ring_arcs(cx, cy, a, b, rot)
    m = p.m
    col = kit.STONE if kind == "stone" else kit.TIMBER
    hw = height
    gi = max(range(len(front)), key=lambda q: front[q][1])              # the gate: the lowest point of the front
    gate = front[gi]
    X = lambda q: (q[0] * m, q[1])
    fr, bk = [X(q) for q in front], [X(q) for q in back]
    full = ring_arcs(cx, cy, a + 2, b + 2, rot)
    p.shadow(cx + m * a * 0.15, cy + b * kit.TILT * 0.4, a * 2.0, b * 2.0 * kit.TILT * 1.1)
    p.claim([q for arc in full for q in arc])                            # no wild tree inside or on the wall
    winter = p.winter

    def stakes(pen, pts, c):
        for q in pts:
            pen.line((q[0], q[1] - hw + 0.4), (q[0], q[1] - hw - 0.9), c, 0.5)

    def fb(pen):
        top = [(q[0], q[1] - hw) for q in bk]
        pen.poly(bk + top[::-1], kit.shade(col, 0.82), None)
        if kind == "palisade":
            stakes(pen, bk, kit.shade(col, 0.7))
        pen.lines(top, kit.INK if kind == "stone" else kit.TIMBER_D, 0.5)
        for f in back_towers:
            q = bk[int(len(bk) * f)]
            pen.box(q[0], q[1], 3.6, hw + 3, kit.shade(col, 0.9), kit.INK)

    def ff(pen):
        top = [(q[0], q[1] - hw) for q in fr]
        pen.poly(fr + top[::-1], col, None)
        if kind == "stone":
            for q in range(0, len(fr), 3):
                t = top[q]
                pen.rect(t[0] - 0.8, t[1] - 1.4, 1.6, 1.5, col if not winter else kit.SNOW, None)
        else:
            stakes(pen, fr, kit.TIMBER_D)
            for q in range(2, len(fr), 4):
                t = fr[q]
                pen.line((t[0], t[1] - hw + 0.8), (t[0], t[1] - 0.4), kit.TIMBER_D, 0.5)
        pen.lines(top, kit.INK, 0.5)
        pen.lines(fr, kit.INK, 0.5)
        for f in towers:
            q = fr[int((len(fr) - 1) * f)]
            tw, th_ = 4.2, hw + 3.5
            pen.box(q[0], q[1], tw, th_, col, kit.INK)
            if winter:
                pen.rect(q[0] - tw / 2, q[1] - th_ - 0.6, tw, 1.0, kit.SNOW, None)
        g = X(gate)
        pen.rect(g[0] - 1.6, g[1] - 3.0, 3.2, 3.0, kit.DOOR, None)
        if kind == "palisade":
            pen.rect(g[0] - 2.4, g[1] - hw - 1.6, 4.8, 1.2, kit.TIMBER_D, None)
    p.stand(min(q[1] for q in back) - 0.5, fb, x=0)
    h = p.stand(max(q[1] for q in front) + 0.5, ff, x=0)
    return h, gate, max(front, key=lambda q: q[0])


def draw(level, season, variant=0, mirror=False):
    p = kit.Piece(season, ground="grass", seed=2, mirror=mirror)
    L = LAYOUT[variant]
    gates = GATES[variant]
    sites, suburb, plots, trees = L["sites"], L["suburb"], L["plots"], L["trees"]
    lx, ly = L["lm"]                                  # the landmark's base: the same in every level
    cx, cy = (CX, CY) if variant == 0 else RC1        # the ring's middle
    if variant == 0:
        n, rx, ry, wall = SPEC[level]
    else:
        n, rx, ry, wall = SPEC1[level]
    grey = (204, 198, 188)
    # ---- ground plane
    if level <= 2:                                    # the village green in front of the well or chapel: kept clear of the map's trees
        p.blob(lx, ly + 7, 26, 14, kit.ROAD if not p.winter else grey, alpha=0.3)
    if level >= 3:                                    # trodden ground inside the ring (its rim lies under the wall)
        if variant == 0:
            p.blob(cx, cy + 1, rx * 2 + 1, ry * 2 + 1, kit.ROAD if not p.winter else grey, alpha=0.45 if not p.winter else 1.0)
        else:
            fa, ba = ring_arcs(cx, cy, rx + 0.5, ry + 0.5, ROT1)
            p.over(lambda pen: pen.poly(fa + ba, kit.ROAD if not p.winter else grey, None), 0.45 if not p.winter else 1.0)
    for pcx, pcy, w, h, ang, st, lo, hi in plots:
        if lo <= level <= hi:
            p.field(pcx, pcy, w, h, ang, kit.crop("garden", season), st, furrows=True)
    if variant == 0:
        gate_y = cy + (ry if level >= 3 else 6)
        p.road([(cx, gate_y - 2), (cx - 1, gate_y + 8), gates["south"]], 1.4 if level < 3 else 2.0 if level < 5 else 2.4, track=level < 3)
        if level >= 2:
            p.road([(cx + (rx or 14) - 2, cy + 3), (min(cx + (rx or 14) + 5, gates["east"][0]), cy + 5), gates["east"]], 1.4 if level < 3 else 2.0, track=level < 3)
        if level >= 4:
            p.road([(cx - rx + 2, cy + 3), (max(cx - rx - 4, gates["west"][0]), cy + 5), gates["west"]], 2.0)
    else:
        fa, _ = ring_arcs(cx, cy, rx, ry, ROT1) if level >= 3 else (None, None)
        wd = 1.4 if level < 3 else 2.0 if level < 5 else 2.4
        if level >= 3:
            gate = max(fa, key=lambda q: q[1])
            right = max(fa, key=lambda q: q[0])
            left = min(fa, key=lambda q: q[0])
            p.road([(lx + 1, ly + 14), (gate[0] - 2, gate[1] - 4), (gate[0], gate[1] - 2)], 1.6, track=False)       # the lane from the church green to the gate
            p.road([(gate[0], gate[1] - 2), (gate[0] - 0.5, gate[1] + 8), gates["south"]], wd)
            p.road([(right[0] - 2, right[1] + 1), (right[0] + 3, right[1] + 3), gates["east"]], 2.0)
            if level >= 4:
                p.road([(left[0] + 2, left[1] - 1), (max(left[0] - 3, gates["west"][0]), left[1] + 1), gates["west"]], 2.0)
        else:
            p.road([(lx + 0.5, ly + 4), (lx + 0.5, ly + 14), (lx + 3, 24), gates["south"]], wd, track=True)
            if level == 2:
                p.road([(lx + 14, ly + 1), (22, -6), gates["east"]], 1.4, track=True)

    # ---- standing things
    for x, y, sc, lo, hi, i in trees:
        if lo <= level <= hi:
            p.tree(x, y, sc, "fruit", i)
    if wall:
        towers = {3: (), 4: (0.2, 0.8), 5: (0.12, 0.32, 0.68, 0.88)}[level]
        back = {3: (), 4: (), 5: (0.3, 0.7)}[level]
        hh = 3.4 if wall == "palisade" else 4.0
        if variant == 0:
            p.wall(cx, cy + 1, rx, ry, wall, towers=towers, gate=0.5, back_towers=back, height=hh)
            gx, gy = cx, cy + 1 + ry
        else:
            _, (gx, gy), _ = rot_wall(p, cx, cy, rx, ry, ROT1, wall, towers, back, hh)
        if level >= 4:                                # the gate tower: taller at the city (banners belong to castles)
            gt = p.tower(gx, gy + 0.7, 5.0, 8.5 if level == 4 else 10.0, kit.STONE, "battlement")
            p.stand(gy + 0.8, lambda pen: pen.rect(gx - 1.5, gy - 2.6, 3.0, 3.0, kit.DOOR, None), on=gt)
    for i, (x, y) in enumerate(sites[:n]):
        thatch = level == 1 or (level == 2 and i % 2 == 1)
        tall = level >= 4 and i % 4 == 0              # a few taller houses in the walled places
        big = level == 5 and i % 3 == 1
        p.house(x, y, 7.0 + (i * 37 % 5) * 0.4, 4.4 + (1.8 if tall else 0) + (0.8 if big else 0), 3.2 + (i * 53 % 4) * 0.3, wall=i,
                kind="ridge" if (i * 29 % 7) < 4 else "gable", roof="thatch" if thatch else "tile", smoke=(i % 3 == 0))
    if level == 5:
        for i, (x, y) in enumerate(suburb):
            p.house(x, y, 6.6, 4.2, 3.2, wall=i + 2, kind="ridge" if i % 2 else "gable", smoke=(i == 1))
    # the landmark of the level, always at the same place
    if level == 1:
        well(p, lx + 1, ly + 5)
    elif level == 2:
        p.church(lx - 1, ly + 5, "chapel")
    elif level in (3, 4):
        p.church(lx - 1, ly + 6, "church")
    else:
        p.church(lx - 1.5, ly + 8, "cathedral", 1.3)
    # ---- season activity
    if season == "summer" and level <= 2:
        p.person(lx + 7, ly + 8)
    if season in ("spring", "summer") and level >= 3:                           # market day on the green
        p.person(lx - 8, ly + 9, (70, 96, 150))
        p.person(lx + 9, ly + 9.5)
    return p.finish(label="settlement L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "settlements.png")
    kit.sheet(draw, LEVELS, "Settlements: levels 1-5 by season", out, NAMES, wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "settlements_variants.png")
    kit.variant_sheet(draw, LEVELS, "Settlements: layouts and mirror", vout, NAMES)
    print("wrote", os.path.normpath(vout))
