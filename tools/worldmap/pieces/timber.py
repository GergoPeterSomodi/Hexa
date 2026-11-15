"""Timber and logging, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 wild wood - 1 a clearing with stumps, a hut and the charcoal mound - 2 wider clearing, 2 log piles, the sawmill -
3 trees only in the back half, 4 log piles, a long shed and the log raft on the stream (no raft in winter).
Trees thin from the front; the back row never changes.

python timber.py           writes docs/design/map/pieces/timber.png
python timber.py out.png   or any other path
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

GROUND = "wood"
LEVELS = range(0, 4)
NAMES = {0: "wild wood", 1: "clearing, mound", 2: "sawmill, 2 piles", 3: "4 piles, raft"}

CUT_WOOD = (226, 196, 140)           # the cut top of a stump (named token, the same colour as the kit's log ends)

STREAM = [(-52, 34), (-36, 32), (-20, 33), (-4, 31), (10, 32.5), (26, 31), (40, 33), (52, 32)]
HUT = (-26, 6)
MOUND = (22, 10)                     # the charcoal mound: level 1 landmark
SAWMILL = (22, 25, 13.0)             # x, foot y, width: level 2 landmark
SHED = (-8, 6, 15.0)                 # level 3
RAFT = (-14, 32.6)                   # level 3 landmark, on the stream
STUMPS = [(-12, 18), (-3, 22), (6, 17), (-6, 13), (13, 14)]
CLEARINGS = [                        # cx, cy, w, h, from level: each is added to the one before
    (0, 16, 34, 14, 1),
    (0, 16, 76, 24, 2),
    (0, 10, 80, 30, 3),
]
PILES = [(8, 24, 2), (-18, 26, 2), (-28, 24, 3), (38, 17, 3)]          # x, foot y, from level
PILE_WINTER = (-4, 28)               # felling time: one more pile (level 2 and up)
PEOPLE = [(-9, 15, 1), (15, 21, 2)]  # x, foot y, from level
TRACK = [(0, 12), (-4, 20), (-8, 28), (-12, 36), (-14, 50)]            # level 2
TREES = [                            # x, y, kind, size, gone from level.  C = conifer, R = round
    # the back row: never removed
    (-40, -12, "conifer", 1.0, 9), (-32, -20, "round", 1.0, 9), (-22, -22, "conifer", 1.0, 9), (-12, -27, "conifer", 1.0, 9),
    (-2, -33, "conifer", 1.0, 9), (8, -30, "round", 1.0, 9), (16, -25, "conifer", 1.0, 9), (26, -20, "conifer", 1.0, 9),
    (38, -14, "round", 1.0, 9), (-18, -11, "conifer", 1.0, 9), (6, -16, "conifer", 1.0, 9),
    # the middle: gone at level 3
    (-33, -2, "conifer", 1.0, 3), (-26, -5, "conifer", 1.0, 3), (28, -6, "conifer", 1.0, 3), (40, 2, "round", 1.0, 3),
    # the wide clearing: gone at level 2
    (-36, 16, "conifer", 1.0, 2), (-36, 25, "round", 1.0, 2), (34, 16, "conifer", 1.0, 2), (42, 26, "round", 1.0, 2),
    # the first clearing (stumps stand where they were): gone at level 1
    (-12, 18, "conifer", 1.0, 1), (-3, 22, "round", 1.0, 1), (6, 17, "conifer", 1.0, 1), (-6, 13, "conifer", 1.0, 1),
    (13, 14, "round", 1.0, 1),
]
WORK_PATCHES = [(0, 16, 34, 14), (-30, 20, 20, 9), (34, 18, 22, 9), (-8, 6, 20, 8)]   # level 0: darker ground where the work will come


def stump(p, x, y):
    p.cast(x, y, 3)

    def fn(pen):
        pen.rect(x - 1.7, y - 2.2, 3.4, 2.2, kit.TIMBER, None)
        pen.rect(x + 0.4, y - 2.2, 1.3, 2.2, kit.TIMBER_D, None)
        pen.ellipse(x, y - 2.2, 3.4, 1.6, kit.SNOW if p.winter else CUT_WOOD, kit.INK, 0.5)
        pen.line((x - 1.7, y - 2.2), (x - 1.7, y), kit.INK, 0.5)
        pen.line((x + 1.7, y - 2.2), (x + 1.7, y), kit.INK, 0.5)
    p.stand(y, fn)


def charcoal_mound(p, x, y):
    """The level 1 landmark: a dark domed heap that smokes in every season (the guide's one smoke exception)."""
    p.heap(x, y, 11, 6.5, kit.DOOR, kit.shade(kit.DOOR, 0.78))
    p.stand(y + 30, lambda pen: kit._smoke(pen, x + 0.5, y - 6.5))


def sawmill(p, x, y, w):
    """The level 2 landmark: a timber house on the stream with an overshot water wheel on its right."""
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
        # the wheel: a ring with spokes and paddles, its foot in the stream
        pen.circle(wx, wy - wr, wr + 0.5, kit.TIMBER_D)
        pen.circle(wx, wy - wr, wr - 0.8, kit.TIMBER)
        pen.circle(wx, wy - wr, wr - 1.8, kit.TIMBER_D)
        for a in (0, 45, 90, 135):
            import math
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            pen.line((wx - ca * (wr - 0.4), wy - wr - sa * (wr - 0.4)), (wx + ca * (wr - 0.4), wy - wr + sa * (wr - 0.4)), kit.INK, 0.5)
        pen.circle(wx, wy - wr, 0.8, kit.INK)
    p.stand(y + 0.2, fn)


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
    p.stand(y, fn)


def raft(p, x, y):
    """The level 3 landmark: a raft of logs tied together, floating on the stream (open water only)."""
    def fn(pen):
        for i, dy in enumerate((-1.5, 0.0, 1.5)):
            xo = (0.6, -0.4, 0.2)[i]
            pen.rect(x - 6 + xo, y + dy - 0.7, 12, 1.4, kit.TIMBER if i != 1 else kit.TIMBER_D, kit.INK, 0.5)
            pen.dot(x + 5.4 + xo, y + dy, CUT_WOOD, 0.9)
        pen.line((x - 2, y - 2.2), (x - 2, y + 2.2), kit.TRUNK, 0.8)           # the lashings
        pen.line((x + 2.5, y - 2.2), (x + 2.5, y + 2.2), kit.TRUNK, 0.8)
    p.stand(y + 3, fn)


def draw(level, season):
    p = kit.Piece(season, ground="wood", seed=3)
    au, wi = season == "autumn", season == "winter"

    # ---- ground plane
    if level == 0:                                    # wild wood: darker patches where the clearing and yards will come
        for x, y, w, h in WORK_PATCHES:
            p.blob(x, y, w, h, kit.shade(p.pal["wood"], 0.93))
    clear = kit.mix(p.pal["soil"], p.pal["wood"], 0.4)
    for cx, cy, w, h, frm in CLEARINGS:
        if level >= frm:
            p.blob(cx, cy, w, h, clear)
    if level >= 2:
        p.road(TRACK, 1.6, track=True)
    p.water(STREAM, 3.0)
    p.tufts(18 if level == 0 else 11 if level == 1 else 7 if level == 2 else 4,
            avoid=[(c[0], c[1], max(c[2], c[3]) * 0.4) for c in CLEARINGS if level >= c[4]])
    p.stones([(-40, 8, 1.6), (32, 26, 1.8)] if level < 2 else [(32, 28, 1.8)])

    # ---- standing things
    for i, (x, y, kind, sc, gone) in enumerate(TREES):
        if level < gone:
            p.tree(x, y, sc, kind, i)
    if level >= 1:
        for x, y in STUMPS:
            stump(p, x, y)
        p.house(HUT[0], HUT[1], 5.5, 3.5, 3.0, wall=4, kind="ridge", roof="thatch", smoke=True)
        charcoal_mound(p, MOUND[0], MOUND[1])
    if level >= 2:
        sawmill(p, SAWMILL[0], SAWMILL[1], SAWMILL[2])
        for x, y, frm in PILES:
            if level >= frm:
                p.logs(x, y, 3, 7.0)
        if wi:
            p.logs(PILE_WINTER[0], PILE_WINTER[1], 3, 7.0)
    if level >= 3:
        shed(p, SHED[0], SHED[1], SHED[2])
        if not wi:
            raft(p, RAFT[0], RAFT[1])
    # ---- season activity: the loggers
    for x, y, frm in PEOPLE:
        if level >= frm and not (au and frm == 2):
            p.person(x, y, (110, 80, 60) if frm == 1 else (70, 96, 150))
    return p.finish(label="timber L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "timber.png")
    kit.sheet(draw, LEVELS, "Timber and logging: levels 0-3 by season", out, NAMES, ground="wood")
    print("wrote", os.path.normpath(out))
