"""Wheat fields, levels 0-3 (reference family; see docs/design/map/pieces/GUIDE.md).

0 the map's wild land (no piece) - 1 a farm with one block of strips - 2 three hedged blocks and a barn - 3 an estate:
five blocks, a canal with poplars that ends in a pond at each end, and a windmill. Two layouts (LAYOUT) and the mirror.
The piece draws no wild land: the map's trees and scrub stand round the work.

python wheat.py            writes docs/design/map/pieces/wheat.png and wheat_variants.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "farm + 1 block", 2: "3 blocks, barn", 3: "estate, windmill"}
VARIANTS = 2
# Where the map's road layer joins the farm track (unmirrored, 10+ px inside the border). Both layouts end there.
GATES = {"south": (-10, 34)}

# The layouts are fixed tables: a level adds to the level below and never moves anything.
#   yard: the trodden farmyard (x, y, w, h), laid half-transparent: it clears the map's wild land round the house;  blocks: cx, cy, w, h, angle, strips, from level;  canal: the line, with a pond
#   (8 x 5) at each end;  farm/barn/house2: the buildings;  fruit, hay: planted and stacked things, by level;
#   mill: the level 3 landmark (8 px free in front of it);  track: ends at the gate.
LAYOUT = [
    dict(  # layout 0: the yard just left of the middle, the windmill behind it, the canal across the upper half
        yard=(-5, 3, 28, 16),
        blocks=[
            (23, 13, 34, 24, -10, 6, 1),               # every corner 10 px inside the border (the map's rivers run there)
            (-20, 19, 30, 15, 8, 5, 2),
            (17, -18, 29, 16, -6, 5, 2),
            (-22, -17, 28, 13, 6, 4, 3),
            (4, 30, 18, 7, 0, 3, 3),
        ],
        canal=[(-36, -7), (-24, -8), (-10, -9), (2, -10), (14, -8), (30, -7), (36, -5)],
        poplars=[(-41, -10), (-35, -11), (-29, -11)],
        farm=(-9, 0), barn=(1, 2), house2=(-6, 9), mill=(-3, -14),
        fruit=[(-19, 1), (-15, 7)], hay=[(9, 5), (13, 7)],
        track=[(-5, 3), (-4, 14), (-9, 28), GATES["south"]],
    ),
    dict(  # layout 1: the yard upper right, the canal with its poplars across the lower half, the windmill front left
        yard=(14, -11, 36, 20),
        blocks=[
            (6, 5, 34, 24, 6, 6, 1),
            (-25, -10, 32, 20, -6, 5, 2),
            (32, 8, 22, 17, 90, 5, 2),
            (-34, 9, 20, 15, 90, 5, 3),
            (-4, -29, 20, 9, 0, 3, 3),
        ],
        canal=[(-35, 16), (-24, 21), (-10, 23), (6, 23), (20, 21), (35, 16)],
        poplars=[(-26, 26.5), (-20, 28), (-14, 29)],
        farm=(14, -17), barn=(25, -15), house2=(6, -11), mill=(-18, 13),
        fruit=[(3, -17), (38, -11)], hay=[(33, -5), (38, -2)],
        track=[(14, -11), (19, -5), (23, 8), (21, 17), (12, 27), (2, 31), GATES["south"]],
    ),
]


def _ellipse(cx, cy, w, h, n=12):
    return [(cx + math.cos(i * 2 * math.pi / n) * w / 2, cy + math.sin(i * 2 * math.pi / n) * h / 2) for i in range(n)]


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
    return p.stand(y, fn)


def stooks(p, x, y, n=3):
    """Sheaves standing on a cut strip (summer harvest): small gold cones, 5 px apart. Returns their handles."""
    out = []
    for i in range(n):
        a, b = x + i * 5.0, y + (i % 2) * 1.2
        out.append(p.stand(b, (lambda a, b: lambda pen: (pen.poly([(a - 1.4, b), (a, b - 3.0), (a + 1.4, b)], (236, 204, 104), None),
                                                         pen.poly([(a + 0.2, b), (a, b - 3.0), (a + 1.4, b)], (176, 138, 64), None)))(a, b)))
    return out


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheet shows the wild land
        return kit.wild(season, "farm", seed=1)
    p = kit.Piece(season, ground="farm", seed=1, mirror=mirror)
    L = LAYOUT[variant]
    su, au, wi, sp = season == "summer", season == "autumn", season == "winter", season == "spring"
    cols = kit.crop("wheat", season)

    # ---- ground plane
    blocks = [b for b in L["blocks"] if b[6] <= level]
    if level >= 1:
        p.blob(*L["yard"], p.pal["soil"], alpha=0.3)
    if level >= 3:
        p.water(L["canal"], 1.4)                      # the canal ends in a pond at each end, inside the hex
        for x, y in (L["canal"][0], L["canal"][-1]):
            p.pond(_ellipse(x, y, 8, 5))
    if level >= 1:
        p.road(L["track"], 1.6, track=level < 3)
    for i, (cx, cy, w, h, ang, n, _) in enumerate(blocks):
        c = cols[i:] + cols[:i]                       # each block starts on another strip colour
        if su and i == len(blocks) - 1:               # harvest: the newest block is half cut (stubble)
            c = [c[0], (206, 184, 122), c[2], (214, 190, 126)]
        pts = p.field(cx, cy, w, h, ang, c, n, furrows=au or wi or sp)
        if level >= 2:                                # hedges on two sides of each block
            p.hedge([pts[0], pts[1], pts[2]])

    # ---- standing things
    if level >= 1:
        p.house(*L["farm"], 7.5, 4.8, 3.6, wall=0, kind="ridge", roof="thatch" if level == 1 else "tile", smoke=True)
        p.tree(*L["fruit"][0], 0.9, "fruit", 1)
    if level >= 2:
        p.house(*L["barn"], 9.5, 5.2, 4.6, wall=(214, 186, 140), kind="gable", roof="thatch", door=False)   # the barn
        p.tree(*L["fruit"][1], 0.9, "fruit", 2)
        if not sp:
            p.haystack(*L["hay"][0])
    if level >= 3:
        windmill(p, *L["mill"])
        p.house(*L["house2"], 6.5, 4.2, 3.2, wall=3, kind="ridge")
        for i, (x, y) in enumerate(L["poplars"]):
            p.tree(x, y, 0.9, "poplar", i)
        if not sp:
            p.haystack(*L["hay"][1], 0.9)
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
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces", "wheat.png")
    kit.sheet(draw, LEVELS, "Wheat fields: levels 0-3 by season", out, NAMES, ground="farm", wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "wheat_variants.png")
    kit.variant_sheet(draw, LEVELS, "Wheat fields: layouts and mirror", vout, NAMES, ground="farm")
    print("wrote", os.path.normpath(vout))
