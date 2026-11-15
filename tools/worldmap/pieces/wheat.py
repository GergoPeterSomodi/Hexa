"""Wheat fields, levels 0-3 (reference family; see docs/design/map/pieces/GUIDE.md).

0 rough grass - 1 a farm with one block of strips - 2 three hedged blocks and a barn - 3 an estate: five blocks,
a canal with poplars and a windmill.

python wheat.py            writes docs/design/map/pieces/wheat.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "rough grass", 1: "farm + 1 block", 2: "3 blocks, barn", 3: "estate, windmill"}

# The layout is fixed: a level adds to the level below and never moves anything.
YARD = (-5, 0, 15)                                   # the farmyard: x, y, radius kept clear
BLOCKS = [                                           # cx, cy, w, h, angle, strips, from level
    (26, 15, 36, 26, -10, 6, 1),
    (-23, 23, 32, 21, 8, 5, 2),
    (21, -22, 35, 20, -6, 5, 2),
    (-25, -21, 30, 19, 6, 5, 3),
    (3, 36, 28, 9, 0, 3, 3),
]
SCRUB = [(-24, -22, 26, 12), (20, -20, 30, 13), (26, 16, 30, 16), (-22, 22, 28, 13), (0, 36, 26, 8), (-2, -2, 22, 10)]   # wild patches, level 0
WILD_TREES = [                                       # x, y, kind, size, gone from level
    (-30, -18, "round", 1.0, 3), (22, -28, "round", 0.9, 2), (34, 14, "round", 1.0, 1), (-18, 26, "bush", 1.0, 2),
    (8, -8, "bush", 1.0, 1), (-36, 6, "bush", 1.0, 9), (40, -6, "round", 0.85, 3), (2, 30, "bush", 1.0, 3),
    (-8, -34, "round", 0.9, 9), (-2, 12, "round", 1.0, 1), (16, 4, "bush", 1.0, 1),
]
CANAL = [(-45, -6), (-34, -7), (-24, -8), (-10, -9), (2, -10), (14, -8), (30, -7), (45, -4)]
POPLARS = [(-41, -10), (-35, -11), (-29, -11)]


def windmill(p, x, y):
    """The level 3 landmark: a white tower mill, 17 px tall with its sails."""
    p.cast(x, y, 7)
    winter = p.winter

    def fn(pen):
        body = [(x - 3.2, y), (x + 3.2, y), (x + 2.2, y - 10), (x - 2.2, y - 10)]
        pen.poly(body, (240, 234, 220), None)
        pen.poly([(x + 0.8, y), (x + 3.2, y), (x + 2.2, y - 10), (x + 0.6, y - 10)], (204, 196, 180), None)
        pen.poly(body, None, kit.INK, 0.5)
        cap = [(x - 2.8, y - 10), (x + 2.8, y - 10), (x, y - 13.5)]
        pen.poly(cap, kit.SLATE if not winter else kit.SNOW, kit.INK, 0.5)
        pen.rect(x - 0.7, y - 2.4, 1.4, 2.4, kit.DOOR, None)
        hx, hy = x - 0.5, y - 10.5                    # the sail cross
        for a in (35, 125, 215, 305):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            tip = (hx + ca * 8.5, hy + sa * 8.5)
            pen.line((hx, hy), tip, kit.INK, 0.5)
            q0 = (hx + ca * 3, hy + sa * 3)
            pen.poly([q0, tip, (tip[0] - sa * 1.8, tip[1] + ca * 1.8), (q0[0] - sa * 1.8, q0[1] + ca * 1.8)], kit.SAIL, kit.INK, 0.5)
    p.stand(y, fn)


def stooks(p, x, y, n=3):
    """Sheaves standing on a cut strip (summer harvest): small gold cones, 5 px apart."""
    for i in range(n):
        a, b = x + i * 5.0, y + (i % 2) * 1.2
        p.stand(b, (lambda a, b: lambda pen: (pen.poly([(a - 1.4, b), (a, b - 3.0), (a + 1.4, b)], (236, 204, 104), None),
                                              pen.poly([(a + 0.2, b), (a, b - 3.0), (a + 1.4, b)], (176, 138, 64), None)))(a, b))


def draw(level, season):
    p = kit.Piece(season, ground="farm", seed=1)
    su, au, wi, sp = season == "summer", season == "autumn", season == "winter", season == "spring"
    cols = kit.crop("wheat", season)

    # ---- ground plane
    blocks = [b for b in BLOCKS if b[6] <= level]
    if level == 0:                                    # wild land: darker scrub patches where the fields will come
        for x, y, w, h in SCRUB:
            p.blob(x, y, w, h, p.pal["wood"], alpha=0.55)
    if level >= 3:
        p.water(CANAL, 1.4)
    if level >= 1:
        p.road([(-5, 3), (-4, 14), (-12, 30), (-16, 46)], 1.6, track=level < 3)
    for i, (cx, cy, w, h, ang, n, _) in enumerate(blocks):
        c = cols[i:] + cols[:i]                       # each block starts on another strip colour
        if su and i == len(blocks) - 1:               # harvest: the newest block is half cut (stubble)
            c = [c[0], (206, 184, 122), c[2], (214, 190, 126)]
        pts = p.field(cx, cy, w, h, ang, c, n, furrows=au or wi or sp)
        if level >= 2:                                # hedges on two sides of each block
            p.hedge([pts[0], pts[1], pts[2]])
    avoid = [YARD] + [(b[0], b[1], max(b[2], b[3]) * 0.62) for b in blocks]
    p.tufts(16 if level == 0 else 9 if level == 1 else 4, avoid=avoid if level else ())
    if level == 0:
        p.stones([(14, 18, 2.0), (-22, -2, 1.6), (30, -12, 1.8)])
    elif level == 1:
        p.stones([(-22, -2, 1.6)])

    # ---- standing things
    for i, (x, y, kind, sc, gone) in enumerate(WILD_TREES):
        if level < gone:
            p.tree(x, y, sc, kind, i)
    if level >= 1:
        p.house(-9, 0, 7.5, 4.8, 3.6, wall=0, kind="ridge", roof="thatch" if level == 1 else "tile", smoke=True)
        p.tree(-19, 1, 0.9, "fruit", 1)
    if level >= 2:
        p.house(1, 2, 9.5, 5.2, 4.6, wall=(214, 186, 140), kind="gable", roof="thatch", door=False)   # the barn
        p.tree(-15, 7, 0.9, "fruit", 2)
        if not sp:
            p.haystack(9, 5)
    if level >= 3:
        windmill(p, -3, -14)
        p.house(-6, 9, 6.5, 4.2, 3.2, wall=3, kind="ridge")
        for i, (x, y) in enumerate(POPLARS):
            p.tree(x, y, 0.9, "poplar", i)
        if not sp:
            p.haystack(13, 7, 0.9)
    # ---- season activity (never changes the layout)
    if su and blocks:
        cx, cy = blocks[-1][0], blocks[-1][1]
        stooks(p, cx - 8, cy + 1, 4 if level > 1 else 3)
        p.person(cx + 9, cy - 1)
        if level >= 2:
            p.person(cx - 12, cy - 4, (70, 96, 150))
    if au and level >= 1:
        p.person(blocks[0][0] - 4, blocks[0][1] + 2, (110, 80, 60))       # the ploughman
        p.animal(blocks[0][0] + 1, blocks[0][1] + 2, "cow")
    return p.finish(label="wheat L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "wheat.png")
    kit.sheet(draw, LEVELS, "Wheat fields: levels 0-3 by season", out, NAMES, ground="farm")
    print("wrote", os.path.normpath(out))
