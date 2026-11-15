"""Settlements, levels 1-5 (reference family; see docs/design/map/pieces/GUIDE.md).

1 hamlet - 2 village (chapel) - 3 town (palisade, church) - 4 walled town (stone wall, towers) - 5 city (cathedral,
suburbs). The lower strip of the hex (y from +26 down) is kept free for the name plate.

python settlements.py      writes docs/design/map/pieces/settlements.png
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(1, 6)
NAMES = {1: "hamlet", 2: "village", 3: "town", 4: "walled town", 5: "city"}
CX, CY = 0, -7                                        # the middle of the place: the same in every level

#        houses, ring rx, ry, wall kind
SPEC = {1: (3, 0, 0, None), 2: (7, 0, 0, None), 3: (11, 25, 14, "palisade"), 4: (16, 31, 17, "stone"), 5: (24, 38, 20.5, "stone")}


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


SITES = _sites()
SUBURB = [(-33, 19), (-25, 22), (30, 20), (37, 16)]          # level 5: houses outside the wall, by the roads
PLOTS = [                                                    # cx, cy, w, h, angle, strips, from level, to level
    (-22, 9, 14, 9, 8, 3, 1, 2), (20, -20, 14, 8, -6, 3, 1, 2), (24, 8, 15, 9, -8, 3, 2, 2), (-24, -17, 14, 8, 6, 3, 2, 2),
    (-37, 6, 12, 9, 80, 3, 3, 4), (38, 4, 12, 9, 96, 3, 3, 4), (-20, 21, 14, 7, 6, 3, 3, 4), (22, 21, 14, 7, -6, 3, 3, 4),
]
TREES = [                                                    # x, y, kind, size, from level, to level
    (-34, -8, "round", 1.0, 1, 2), (33, -3, "round", 0.9, 1, 2), (-12, -27, "round", 0.9, 1, 3), (10, 17, "fruit", 0.9, 1, 2),
    (-15, 12, "fruit", 0.9, 1, 2), (38, -14, "round", 0.9, 1, 4), (-40, -2, "bush", 1.0, 1, 5), (6, -31, "round", 0.85, 1, 4),
    (-30, 16, "fruit", 0.9, 3, 4), (32, 16, "fruit", 0.9, 3, 4), (44, 6, "bush", 1.0, 3, 5),
]


def well(p, x, y):
    def fn(pen):
        pen.ellipse(x, y - 1, 3.6, 2.4, kit.STONE_GREY, kit.INK, 0.5)
        pen.line((x - 1.8, y - 1), (x - 1.8, y - 5), kit.TIMBER_D, 0.5)
        pen.line((x + 1.8, y - 1), (x + 1.8, y - 5), kit.TIMBER_D, 0.5)
        pen.poly([(x - 2.8, y - 4.6), (x + 2.8, y - 4.6), (x, y - 6.6)], kit.THATCH_D if not p.winter else kit.SNOW, kit.INK, 0.5)
    p.stand(y, fn)


def draw(level, season):
    p = kit.Piece(season, ground="grass", seed=2)
    n, rx, ry, wall = SPEC[level]
    # ---- ground plane
    if level >= 3:                                    # trodden ground inside the ring
        p.blob(CX, CY + 1, rx * 2 - 2, ry * 2 - 1, kit.ROAD if not p.winter else (204, 198, 188), alpha=0.45 if not p.winter else 1.0)
    for cx, cy, w, h, ang, st, lo, hi in PLOTS:
        if lo <= level <= hi:
            p.field(cx, cy, w, h, ang, kit.crop("garden", season), st, furrows=True)
    gate_y = CY + (ry if level >= 3 else 6)
    p.road([(CX, gate_y - 2), (CX - 1, gate_y + 8), (CX - 5, 36), (CX - 8, 48)], 1.4 if level < 3 else 2.0 if level < 5 else 2.4, track=level < 3)
    if level >= 2:
        p.road([(CX + (rx or 14) - 2, CY + 3), (CX + (rx or 14) + 5, CY + 5), (48, 2)], 1.4 if level < 3 else 2.0, track=level < 3)
    if level >= 4:
        p.road([(CX - rx + 2, CY + 3), (CX - rx - 4, CY + 5), (-48, 3)], 2.0)
    p.tufts(8 if level < 3 else 5, avoid=[(CX, CY, (rx or 20) + 6)])

    # ---- standing things
    for i, (x, y, kind, sc, lo, hi) in enumerate(TREES):
        if lo <= level <= hi:
            p.tree(x, y, sc, kind, i)
    if wall:
        towers = {3: (), 4: (0.2, 0.8), 5: (0.12, 0.32, 0.68, 0.88)}[level]
        back = {3: (), 4: (), 5: (0.3, 0.7)}[level]
        p.wall(CX, CY + 1, rx, ry, wall, towers=towers, gate=0.5, back_towers=back, height=3.4 if wall == "palisade" else 4.0)
        if level >= 4:                                # the gate tower: taller at the city (banners belong to castles)
            p.tower(CX, CY + 1 + ry + 0.7, 5.0, 8.5 if level == 4 else 10.0, kit.STONE, "battlement")
            p.stand(CY + 1 + ry + 0.8, lambda pen: pen.rect(CX - 1.5, CY + 1 + ry - 2.6, 3.0, 3.0, kit.DOOR, None))
    for i, (x, y) in enumerate(SITES[:n]):
        thatch = level == 1 or (level == 2 and i % 2 == 1)
        tall = level >= 4 and i % 4 == 0              # a few taller houses in the walled places
        big = level == 5 and i % 3 == 1
        p.house(x, y, 7.0 + (i * 37 % 5) * 0.4, 4.4 + (1.8 if tall else 0) + (0.8 if big else 0), 3.2 + (i * 53 % 4) * 0.3, wall=i,
                kind="ridge" if (i * 29 % 7) < 4 else "gable", roof="thatch" if thatch else "tile", smoke=(i % 3 == 0))
    if level == 5:
        for i, (x, y) in enumerate(SUBURB):
            p.house(x, y, 6.6, 4.2, 3.2, wall=i + 2, kind="ridge" if i % 2 else "gable", smoke=(i == 1))
    # the landmark of the level, always at the middle
    if level == 1:
        well(p, CX + 1, CY + 5)
    elif level == 2:
        p.church(CX - 1, CY + 5, "chapel")
    elif level in (3, 4):
        p.church(CX - 1, CY + 6, "church")
    else:
        p.church(CX - 1.5, CY + 8, "cathedral", 1.3)
    # ---- season activity
    if season == "summer" and level <= 2:
        p.person(CX + 7, CY + 8)
    if season in ("spring", "summer") and level >= 3:                           # market day on the green
        p.person(CX - 8, CY + 9, (70, 96, 150))
        p.person(CX + 9, CY + 9.5)
    return p.finish(label="settlement L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "settlements.png")
    kit.sheet(draw, LEVELS, "Settlements: levels 1-5 by season", out, NAMES)
    print("wrote", os.path.normpath(out))
