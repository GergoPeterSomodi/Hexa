"""Grazing, levels 0-3, for sheep, cattle or horses (see docs/design/map/pieces/GUIDE.md, section 8).

0 rough grazing - 1 loose animals, a shepherd, a hut - 2 a fenced meadow, the byre - 3 three meadows, the market hall.
One layout for all three animals: draw(level, season, animal="sheep"|"cattle"|"horses").
Only the animal, the byre's openings and the market hall's goods differ.

python grazing.py          writes grazing_sheep.png, grazing_cattle.png, grazing_horses.png in docs/design/map/pieces
python grazing.py DIR      the same, into DIR
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "rough grazing", 1: "loose herd, hut", 2: "meadow, byre", 3: "3 meadows, hall"}
ANIMALS = ("sheep", "cattle", "horses")
KIND = {"sheep": "sheep", "cattle": "cow", "horses": "horse"}
HALL_NAME = {"sheep": "wool hall", "cattle": "dairy", "horses": "stud house"}

# Young animals (spring). Named tokens, not in the kit.
LAMB = (244, 240, 230)
CALF = (176, 118, 80)
FOAL = (120, 86, 64)

HUT = (-31, -4)
BYRE = (-4, 0, 13.0)                                  # x, foot y, width
HALL = (16, -12, 16.0)
MEADOWS = [                                           # cx, cy, w, h (before the tilt), from level
    (6, 17, 30, 18, 2),
    (-29, 24, 22, 15, 3),
    (35, 3, 16, 22, 3),
]
YARD = [(-11.5, 2.5), (3.5, 2.5), (3.5, 6.5), (-11.5, 6.5)]            # the stable's small fenced yard (horses), level 2
# x, y, from level, stays out in winter
HERD = [
    (-4, 15, 1, True), (3, 20, 1, False), (9, 14, 1, True), (14, 21, 1, False), (18, 16, 1, False),
    (-5, 22, 2, False), (5, 15, 2, True), (10, 22, 2, False),
    (-33, 23, 3, False), (-27, 27, 3, False), (-22, 22, 3, False), (32, 0, 3, False), (38, 8, 3, False),
]
YOUNG = [(-1.8, 15.8, 1), (11.6, 21.6, 1), (7.6, 15.8, 2)]             # spring only: beside a grown animal; x, y, from level
SCRUB = [(6, 17, 34, 16), (-28, 24, 24, 12), (35, 3, 20, 20), (-4, -2, 24, 10), (-30, -5, 16, 8), (16, -12, 22, 8)]   # level 0 darker patches
WILD = [                                              # x, y, kind, size, gone from level
    (-32, -18, "round", 1.0, 9), (30, -23, "round", 0.9, 9),
    (-3, 14, "bush", 1.0, 1), (-28, 25, "bush", 1.0, 3), (34, 5, "bush", 1.0, 3),
    (-24, -20, "bush", 1.0, 9), (44, 26, "bush", 1.0, 9), (6, -28, "bush", 1.0, 9),
]
STONES = [(-12, 24, 1.8, 1), (28, 30, 2.0, 9), (-40, 6, 1.6, 9), (40, -14, 1.7, 9), (-16, 12, 1.4, 3)]   # x, y, r, gone from level
HAY = [(-17, -6, 2), (32, -15, 3)]                    # haystacks (not in spring)
HAY_EXTRA = (-22, -9)                                 # the haymaking stack, summer only, level 2 and up
TRACK = [(-27, -1), (-18, 4), (-13, 12), (-13, 30), (-15, 48)]


def longhouse(p, x, y, w, kind):
    """The byre / stable: a long low timber building with a thatched roof, 13 px wide, wall 4.2, roof 3.8."""
    h, roof_h = 4.2, 3.8
    r1, r2 = (kit.THATCH, kit.THATCH_D) if not p.winter else (kit.SNOW, kit.SNOW_D)
    p.cast(x, y, w)
    smoky = p.winter

    def fn(pen):
        x0, top = x - w / 2, y - h
        pen.rect(x0, top, w, h, kit.TIMBER, None)
        pen.rect(x0 + w * 0.78, top, w * 0.22, h, kit.shade(kit.TIMBER, 0.84), None)
        if kind == "cow":                                  # three wide doors
            for fx in (0.14, 0.42, 0.68):
                pen.rect(x0 + w * fx, y - 2.6, 2.2, 2.6, kit.DOOR, None)
        elif kind == "horse":                              # two stable doors, half-doors with a lit top
            for fx in (0.2, 0.56):
                pen.rect(x0 + w * fx, y - 3.0, 1.8, 3.0, kit.DOOR, None)
                pen.rect(x0 + w * fx, y - 1.5, 1.8, 0.5, kit.TIMBER_D, None)
        else:                                              # sheep: a hatch and a door
            pen.rect(x0 + w * 0.2, y - 2.6, 2.0, 2.6, kit.DOOR, None)
            pen.rect(x0 + w * 0.58, y - 3.2, 1.8, 1.2, kit.DOOR, None)
        rf = [(x0 - 1.2, top + 0.3), (x0 + w + 1.2, top + 0.3), (x0 + w - 0.8, top - roof_h), (x0 + 0.8, top - roof_h)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.72, top - roof_h), (x0 + w * 0.78, top + 0.3)], r2, None)
        if p.winter:
            pen.line(rf[0], rf[1], kit.THATCH_D, 0.5)
        pen.poly(rf, None, kit.INK, 0.5)
        pen.rect(x0, top, w, h, None, kit.INK, 0.5)
        if smoky:
            kit._smoke(pen, x + w * 0.3, top - roof_h - 0.5)
    p.stand(y, fn)


def market_hall(p, x, y, w, animal):
    """The level 3 landmark: a wide tiled roof on timber posts, goods under it. 16 px wide, 8.8 tall."""
    post_h, roof_h = 4.4, 4.4
    p.cast(x, y, w)
    winter = p.winter
    r1, r2 = (kit.SNOW, kit.SNOW_D) if winter else (kit.ROOF, kit.ROOF_D)
    x0 = x - w / 2

    def fn(pen):
        pen.rect(x0 + 0.6, y - post_h, w - 1.2, post_h, kit.DOOR, None)           # the dark open hall
        if animal == "sheep":                                                      # bales of wool
            for bx in (x0 + 3.5, x0 + 7.0):
                pen.rect(bx, y - 2.2, 2.4, 2.2, kit.SAIL, kit.INK, 0.5)
        elif animal == "cattle":                                                   # milk churns
            for bx in (x0 + 3.5, x0 + 6.4, x0 + 9.3):
                pen.rect(bx, y - 2.4, 1.4, 2.4, kit.SAIL, None)
                pen.rect(bx + 0.9, y - 2.4, 0.5, 2.4, kit.SAIL_D, None)
                pen.rect(bx - 0.2, y - 2.9, 1.8, 0.6, kit.SAIL_D, None)
        else:                                                                      # a stud rail and a trough
            pen.rect(x0 + 3.0, y - 1.6, 5.5, 0.8, kit.TIMBER, None)
            pen.rect(x0 + 9.5, y - 2.0, 3.0, 2.0, kit.THATCH, None)
        n = 5
        for i in range(n):                                                         # the posts: lit, with a shaded edge
            px = x0 + 0.6 + (w - 2.4) * i / (n - 1)
            pen.rect(px, y - post_h, 1.2, post_h, kit.TIMBER, None)
            pen.rect(px + 0.7, y - post_h, 0.5, post_h, kit.TIMBER_D, None)
        top = y - post_h
        rf = [(x0 - 1.4, top + 0.4), (x0 + w + 1.4, top + 0.4), (x0 + w - 1.0, top - roof_h), (x0 + 1.0, top - roof_h)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.7, top - roof_h), (x0 + w * 0.76, top + 0.4)], r2, None)
        if winter:
            pen.line(rf[0], rf[1], kit.ROOF_D, 0.5)
        if animal == "horses":                                                     # the stud house has a little cupola
            cx = x
            pen.rect(cx - 1.5, top - roof_h - 2.2, 3.0, 2.2, kit.PLASTER[0], kit.INK, 0.5)
            pen.poly([(cx - 2.0, top - roof_h - 2.2), (cx, top - roof_h - 4.0), (cx + 2.0, top - roof_h - 2.2)], r1, kit.INK, 0.5)
        pen.poly(rf, None, kit.INK, 0.5)
    p.stand(y, fn)


def young_animal(p, x, y, kind):
    def fn(pen):
        if kind == "sheep":
            pen.ellipse(x, y - 0.8, 2.0, 1.5, LAMB, (120, 110, 100), 0.5)
        elif kind == "cow":
            pen.ellipse(x, y - 1.1, 2.8, 1.8, CALF, kit.INK, 0.5)
        else:
            pen.line((x - 0.7, y), (x - 0.7, y - 1.3), FOAL, 0.5)
            pen.line((x + 0.7, y), (x + 0.7, y - 1.3), FOAL, 0.5)
            pen.ellipse(x, y - 1.8, 2.6, 1.4, FOAL, kit.INK, 0.5)
            pen.line((x + 1.2, y - 2.0), (x + 1.7, y - 3.0), FOAL, 0.8)
    p.stand(y, fn)


def draw(level, season, animal="sheep"):
    assert animal in ANIMALS, animal
    kind = KIND[animal]
    p = kit.Piece(season, ground="grass", seed=2)
    sp, su, wi = season == "spring", season == "summer", season == "winter"

    # ---- ground plane
    if level == 0:                                    # wild grazing: darker scrub patches where the work will come
        for x, y, w, h in SCRUB:
            p.blob(x, y, w, h, kit.mix(p.pal["grass"], p.pal["wood"], 0.5))
    if level == 1:                                    # worn ground where the herd gathers and round the hut
        p.blob(6, 17, 32, 14, kit.mix(p.pal["grass"], p.pal["soil"], 0.22))
        p.blob(HUT[0] + 1, HUT[1] + 3, 14, 7, kit.mix(p.pal["grass"], p.pal["soil"], 0.22))
    if level >= 3:
        p.road(TRACK, 1.6, track=True)
    for cx, cy, w, h, frm in MEADOWS:
        if level >= frm:
            pts = p.field(cx, cy, w, h, 0, kit.crop("meadow", season), 1, edge=kit.mix(p.pal["grass"], kit.TIMBER_D, 0.5))
            p.fence(pts + [pts[0]])
    if level >= 2 and kind == "horse":
        p.fence(YARD + [YARD[0]])
    avoid = [(HUT[0], HUT[1], 8), (BYRE[0], BYRE[1], 11), (HALL[0], HALL[1], 12)] + [(m[0], m[1], max(m[2], m[3]) * 0.62) for m in MEADOWS if level >= m[4]]
    p.tufts(24 if level == 0 else 14 if level == 1 else 9 if level == 2 else 5, avoid=avoid if level else ())
    p.stones([(x, y, r) for x, y, r, gone in STONES if level < gone])

    # ---- standing things
    for i, (x, y, k, sc, gone) in enumerate(WILD):
        if level < gone:
            p.tree(x, y, sc, k, i)
    if level >= 1:
        p.house(HUT[0], HUT[1], 5.5, 3.5, 3.0, wall=4, kind="ridge", roof="thatch", smoke=True)
    if level >= 2:
        longhouse(p, BYRE[0], BYRE[1], BYRE[2], kind)
        if not sp:
            p.haystack(HAY[0][0], HAY[0][1])
    if level >= 3:
        market_hall(p, HALL[0], HALL[1], HALL[2], animal)
        if not sp:
            p.haystack(HAY[1][0], HAY[1][1], 0.9)

    # ---- the herd: fixed table; winter keeps only the three nearest the byre; young ones in spring
    for x, y, frm, stays in HERD:
        if level >= frm and (not wi or stays):
            p.animal(x, y, kind, flip=x > 8)
    if sp:
        for x, y, frm in YOUNG:
            if level >= frm:
                young_animal(p, x, y, kind)
    # ---- season activity
    if not wi and level >= 1:
        p.person(-12, 9, (110, 80, 60))                                   # the shepherd
    if su and level >= 2:
        p.haystack(HAY_EXTRA[0], HAY_EXTRA[1])                            # haymaking
    return p.finish(label="grazing %s L%d" % (animal, level))


def _draw_for(animal):
    return lambda level, season: draw(level, season, animal=animal)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    for a in ANIMALS:
        out = os.path.join(outdir, "grazing_%s.png" % a)
        names = dict(NAMES)
        names[3] = HALL_NAME[a]
        kit.sheet(_draw_for(a), LEVELS, "Grazing (%s): levels 0-3 by season" % a, out, names, ground="grass")
        print("wrote", os.path.normpath(out))
