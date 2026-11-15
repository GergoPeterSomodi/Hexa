"""Timber and logging, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 the map's wild wood (no piece) - 1 a clearing at the front with stumps, a hut and the charcoal mound - 2 a wider
clearing, 2 log piles, the sawmill on its own mill race - 3 the clearing reaches the middle (the back third stays
wood), 4 log piles, a long shed and the log raft on the mill pond. Two layouts (LAYOUT) and the mirror.
The piece draws no tree: the wood is the map's. It draws the clearing and the work in it, and its own short mill race
with a pond at each end (streams are the map's).

python timber.py           writes docs/design/map/pieces/timber.png and timber_variants.png
python timber.py DIR       the same, into DIR
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

GROUND = "wood"
LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "clearing, mound", 2: "sawmill, 2 piles", 3: "4 piles, raft"}
VARIANTS = 2
# Where the map's road layer joins the track (unmirrored, 10+ px inside the border). Both layouts end there.
GATES = {"south": (-27, 25)}

CUT_WOOD = (226, 196, 140)           # the cut top of a stump (named token, the same colour as the kit's log ends)

# The layouts are fixed tables: a level adds to the level below and never moves anything.
#   clearing: cx, cy, w, h, from level. All blobs of a level are laid as ONE half-transparent layer (soil at 0.6), so
#       overlaps do not darken; it grows from the front (south) to the back, and the back third stays wood.
#   hut, mound (level 1), sawmill = x, foot y, width (level 2), shed = x, foot y, width (level 3), raft (level 3);
#   race: the mill race, about 34 px long, with a small pond (8 x 5) at its first and a large pond (14 x 8) at its
#       last point; the raft floats on the large pond;
#   stumps: x, y, from level (5 / 9 / 12); piles: x, foot y, from level; pile_winter: felling time's extra pile;
#   people: x, foot y, from level;  track: level 2 and up, ends at the gate.
LAYOUT = [
    dict(  # layout 0: the clearing across the front, the mound and the sawmill on the right, the hut and the shed on the left
        clearing=[
            (-2, 21, 34, 15, 1), (18, 14, 22, 14, 1), (-22, 10, 24, 14, 1),
            (-2, 25, 54, 16, 2), (0, 30, 44, 11, 2), (28, 21, 22, 14, 2), (0, 12, 68, 24, 2),
            (0, 1, 68, 26, 3), (-20, -6, 34, 22, 3), (22, -4, 32, 22, 3),
        ],
        hut=(-26, 6), mound=(22, 10), sawmill=(17, 23.5, 13.0), shed=(-8, 6, 15.0),
        race=[(25.5, 24.2), (14, 24.9), (2, 25.9), (-9, 27.0)],
        raft=(-9, 27.2),
        stumps=[(-14, 20, 1), (-8, 12, 1), (0, 9, 1), (9, 10, 1), (3, 18, 1),
                (-24, 17, 2), (-2, 22, 2), (-18, 10, 2), (34, 9, 2),
                (-33, 12, 3), (30, 3, 3), (14, 1, 3)],
        piles=[(-10, 19, 2), (34, 14, 2), (-30, 17, 3), (8, 4, 3)],
        pile_winter=(37, 20),
        people=[(-9, 15, 1), (7, 20, 2)],
        track=[(-26, 9), (-27, 16), GATES["south"]],
    ),
    dict(  # layout 1: a tongue from the front centre to the north-east, the mound at its head, the hut and shed on the east flank
        clearing=[
            (-6, 22, 28, 14, 1), (-2, 14, 22, 15, 1), (2, 6, 20, 14, 1), (5, -3, 20, 13, 1),
            (-4, 26, 48, 16, 2), (0, 30, 44, 11, 2), (4, 14, 44, 24, 2), (9, 2, 40, 24, 2),
            (-12, 12, 38, 26, 3), (12, -6, 52, 30, 3), (-4, 4, 58, 30, 3),
        ],
        hut=(31, 3), mound=(4, -6), sawmill=(-2, 26, 13.0), shed=(32, 14, 15.0),
        race=[(-17, 27.2), (-5, 26.8), (7, 26.0), (18, 25.0)],
        raft=(19, 25.2),
        stumps=[(-8, 13, 1), (7, 14, 1), (-3, 5, 1), (11, 6, 1), (1, -1, 1),
                (-10, 4, 2), (15, 15, 2), (-15, 13, 2), (17, 0, 2),
                (-20, 8, 3), (-12, -1, 3), (22, 1, 3)],
        piles=[(-16, 17, 2), (19, 17, 2), (-26, 12, 3), (18, 8, 3)],
        pile_winter=(26, 20),
        people=[(1, 12, 1), (10, 9, 2)],
        track=[(0, -2), (-6, 8), (-14, 16), (-22, 20), GATES["south"]],
    ),
]


def _ellipse(cx, cy, w, h, n=14):
    return [(cx + math.cos(i * 2 * math.pi / n) * w / 2, cy + math.sin(i * 2 * math.pi / n) * h / 2) for i in range(n)]


def stump(p, x, y):
    p.cast(x, y, 3)

    def fn(pen):
        pen.rect(x - 1.7, y - 2.2, 3.4, 2.2, kit.TIMBER, None)
        pen.rect(x + 0.4, y - 2.2, 1.3, 2.2, kit.TIMBER_D, None)
        pen.ellipse(x, y - 2.2, 3.4, 1.6, kit.SNOW if p.winter else CUT_WOOD, kit.INK, 0.5)
        pen.line((x - 1.7, y - 2.2), (x - 1.7, y), kit.INK, 0.5)
        pen.line((x + 1.7, y - 2.2), (x + 1.7, y), kit.INK, 0.5)
    return p.stand(y, fn, x=x)


def charcoal_mound(p, x, y):
    """The level 1 landmark: a dark domed heap that smokes in every season (the guide's one smoke exception)."""
    h = p.heap(x, y, 11, 6.5, kit.DOOR, kit.shade(kit.DOOR, 0.78))
    p.smoke(x + 0.5, y - 6.5, always=True, foot=y, on=h)
    return h


def sawmill(p, x, y, w):
    """The level 2 landmark: a timber house with an overshot water wheel on its right, the wheel's foot in the race."""
    h, roof_h = 5.6, 4.2
    r1, r2 = (kit.THATCH, kit.THATCH_D) if not p.winter else (kit.SNOW, kit.SNOW_D)
    p.cast(x, y, w)
    wx, wy, wr = x + w / 2 + 2.6, y + 1.2, 4.3

    def fn(pen):
        x0, top = x - w / 2, y - h
        pen.rect(x0, top, w, h, kit.TIMBER, None)
        pen.rect(x0 + w * 0.76, top, w * 0.24, h, kit.TIMBER_D, None)
        for fx in (0.3, 0.55):                                    # plank lines
            pen.line((x0 + w * fx, top), (x0 + w * fx, y), kit.TIMBER_D, 0.5)
        pen.rect(x0 + w * 0.12, y - 3.2, 2.4, 3.2, kit.DOOR, None)
        pen.rect(x0 + w * 0.62, y - 3.4, 2.0, 1.6, kit.DOOR, None)
        rf = [(x0 - 1.2, top + 0.3), (x0 + w + 1.2, top + 0.3), (x0 + w - 0.8, top - roof_h), (x0 + 0.8, top - roof_h)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.72, top - roof_h), (x0 + w * 0.78, top + 0.3)], r2, None)
        if p.winter:
            pen.line(rf[0], rf[1], kit.THATCH_D, 0.5)
        pen.poly(rf, None, kit.INK, 0.5)
        pen.rect(x0, top, w, h, None, kit.INK, 0.5)
        # the wheel: a ring with spokes and paddles, its foot in the race
        pen.circle(wx, wy - wr, wr + 0.5, kit.TIMBER_D)
        pen.circle(wx, wy - wr, wr - 0.8, kit.TIMBER)
        pen.circle(wx, wy - wr, wr - 1.8, kit.TIMBER_D)
        for a in (0, 45, 90, 135):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            pen.line((wx - ca * (wr - 0.4), wy - wr - sa * (wr - 0.4)), (wx + ca * (wr - 0.4), wy - wr + sa * (wr - 0.4)), kit.INK, 0.5)
        pen.circle(wx, wy - wr, 0.8, kit.INK)
    return p.stand(y + 0.2, fn)


def shed(p, x, y, w):
    """The level 3 long shed: low, open-fronted, timber and thatch."""
    h, roof_h = 3.8, 3.4
    r1, r2 = (kit.THATCH, kit.THATCH_D) if not p.winter else (kit.SNOW, kit.SNOW_D)
    p.cast(x, y, w)

    def fn(pen):
        x0, top = x - w / 2, y - h
        pen.rect(x0, top, w, h, kit.DOOR, None)
        for i in range(5):
            px = x0 + 0.4 + (w - 1.6) * i / 4
            pen.rect(px, top, 1.0, h, kit.TIMBER, None)
        rf = [(x0 - 1.0, top + 0.3), (x0 + w + 1.0, top + 0.3), (x0 + w - 0.8, top - roof_h), (x0 + 0.8, top - roof_h)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.72, top - roof_h), (x0 + w * 0.78, top + 0.3)], r2, None)
        if p.winter:
            pen.line(rf[0], rf[1], kit.THATCH_D, 0.5)
        pen.poly(rf, None, kit.INK, 0.5)
    return p.stand(y, fn)


def raft(p, x, y):
    """The level 3 landmark: a raft of logs tied together, floating on the mill pond (open water only)."""
    def fn(pen):
        for i, dy in enumerate((-1.5, 0.0, 1.5)):
            xo = (0.6, -0.4, 0.2)[i]
            pen.rect(x - 6 + xo, y + dy - 0.7, 12, 1.4, kit.TIMBER if i != 1 else kit.TIMBER_D, kit.INK, 0.5)
            pen.dot(x + 5.4 + xo, y + dy, CUT_WOOD, 0.9)
        pen.line((x - 2, y - 2.2), (x - 2, y + 2.2), kit.TRUNK, 0.8)           # the lashings
        pen.line((x + 2.5, y - 2.2), (x + 2.5, y + 2.2), kit.TRUNK, 0.8)
    return p.stand(y + 3, fn, x=x)


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheet shows the wild wood
        return kit.wild(season, GROUND, seed=3)
    p = kit.Piece(season, ground=GROUND, seed=3, mirror=mirror)
    L = LAYOUT[variant]
    au, wi = season == "autumn", season == "winter"

    # ---- ground plane: the clearing is cleared ground, an overlay (one layer, so overlaps do not darken)
    blobs = [b for b in L["clearing"] if b[4] <= level]
    p.over(lambda pen: [pen.ellipse(cx, cy, w, h, p.pal["soil"], None) for cx, cy, w, h, _ in blobs], 0.6)
    if level >= 2:
        p.road(L["track"], 1.6, track=True)
        p.water(L["race"], 1.4)                       # the mill race, with a pond at each end, all inside the hex
        x0, y0 = L["race"][0]
        x1, y1 = L["race"][-1]
        p.pond(_ellipse(x0, y0, 8, 5))
        p.pond(_ellipse(x1, y1, 14, 8))

    # ---- standing things
    for x, y, frm in L["stumps"]:
        if level >= frm:
            stump(p, x, y)
    hx, hy = L["hut"]
    p.house(hx, hy, 5.5, 3.5, 3.0, wall=4, kind="ridge", roof="thatch", smoke=True)
    charcoal_mound(p, *L["mound"])
    if level >= 2:
        sawmill(p, *L["sawmill"])
        for x, y, frm in L["piles"]:
            if level >= frm:
                p.logs(x, y, 3, 7.0)
        if wi:
            p.logs(L["pile_winter"][0], L["pile_winter"][1], 3, 7.0)
    if level >= 3:
        shed(p, *L["shed"])
        if not wi:
            raft(p, *L["raft"])
    # ---- season activity: the loggers
    for x, y, frm in L["people"]:
        if level >= frm and not (au and frm == 2):
            p.person(x, y, (110, 80, 60) if frm == 1 else (70, 96, 150))
    return p.finish(label="timber L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    out = os.path.join(outdir, "timber.png")
    kit.sheet(draw, LEVELS, "Timber and logging: levels 0-3 by season", out, NAMES, ground=GROUND, wild=True)
    print("wrote", os.path.normpath(out))
    out = os.path.join(outdir, "timber_variants.png")
    kit.variant_sheet(draw, LEVELS, "Timber and logging: layouts and mirror", out, NAMES, ground=GROUND)
    print("wrote", os.path.normpath(out))
