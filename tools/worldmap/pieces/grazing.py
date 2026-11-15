"""Grazing, levels 0-3, for sheep, cattle or horses (see docs/design/map/pieces/GUIDE.md, section 8).

0 the map's wild land (no piece) - 1 loose animals on a trodden patch, a shepherd, a hut - 2 a fenced meadow, the byre -
3 three meadows, the market hall. Two layouts (LAYOUT) and the mirror. One layout table for all three animals:
draw(level, season, variant=0, mirror=False, animal="sheep"|"cattle"|"horses"). Only the animal, the byre's openings
and the market hall's goods differ. The piece draws no wild land: the map's trees and scrub stand round the work.

python grazing.py          writes grazing_sheep.png, grazing_cattle.png, grazing_horses.png and grazing_sheep_variants.png
python grazing.py DIR      the same, into DIR
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "loose herd, hut", 2: "meadow, byre", 3: "3 meadows, hall"}
VARIANTS = 2
ANIMALS = ("sheep", "cattle", "horses")
KIND = {"sheep": "sheep", "cattle": "cow", "horses": "horse"}
HALL_NAME = {"sheep": "wool hall", "cattle": "dairy", "horses": "stud house"}
# Where the map's road layer joins the track (unmirrored, 10+ px inside the border). Both layouts end there.
GATES = {"south": (-8, 34)}

# The meadow: the season's grass mixed half way to this tint, so it is clearly paler than the ground in every season
# (named token, not in the kit). The colours are fixed per season, so they do not depend on the map's ground.
MEADOW_TINT = (232, 228, 150)
MEADOW = {s: kit.mix(kit.PAL[s]["grass"], MEADOW_TINT, 0.5) for s in ("spring", "summer", "autumn")}
MEADOW["winter"] = kit.mix(kit.WINTER["mild"]["grass"], MEADOW_TINT, 0.4)     # a mild winter: no snow lies (p.winter is False)

# The layouts are fixed tables: a level adds to the level below and never moves anything.
#   hut, byre (x, foot y, width), hall (x, foot y, width): the buildings;
#   meadows: cx, cy, w, h (before the tilt), from level; the first is the level 2 meadow, the trodden patch lies in it;
#   patch: the level 1 trodden patch (36 x 16, an overlay) where the herd gathers;
#   herd: x, y, from level, stays out in winter; young: spring only, beside a grown animal: x, y, from level;
#   hay: haystacks (x, y, size, from level; not in spring); haymaking: the extra summer stack; shepherd: the person;
#   track: level 3, ends at the gate.
LAYOUT = [
    dict(  # layout 0: the hut far left at the back, the byre at the middle, the hall at the back right, meadows in front and to the sides
        hut=(-32, -17), byre=(-2, -2, 13.0), hall=(8, -18, 16.0),
        meadows=[(8, 17, 40, 24, 2), (-26.5, -6, 30, 20, 3), (30.5, -7, 22, 26, 3)],
        patch=(8, 17),
        herd=[
            (-3, 15, 1, True), (5, 21, 1, False), (13, 14, 1, True), (19, 21, 1, False), (24, 15, 1, False),
            (-7, 22, 2, False), (10, 10, 2, True), (18, 25, 2, False),
            (-35, -5, 3, False), (-27, 0, 3, False), (-20, -9, 3, False), (27, -11, 3, False), (36, 0, 3, False),
        ],
        young=[(-0.8, 15.8, 1), (15.2, 14.8, 1), (12.2, 10.8, 2)],
        hay=[(-18, -18, 1.0, 2), (37, -23, 0.9, 3)], haymaking=(-13, -12), shepherd=(-15, 9),
        track=[(-3, 3), (-13, 5), (-17, 12), (-16, 22), (-13, 29), GATES["south"]],
    ),
    dict(  # layout 1: the byre and hut at the back right, the big meadow across the middle, two meadows on the west, the hall front left
        hut=(34, -12), byre=(18, -16, 13.0), hall=(-22, 31, 16.0),
        meadows=[(15, 8, 40, 24, 2), (-21, -15, 30, 20, 3), (-22, 9, 22, 26, 3)],
        patch=(15, 8),
        herd=[
            (4, 8, 1, False), (11, 12, 1, False), (18, 5, 1, True), (25, 10, 1, True), (31, 7, 1, False),
            (7, 15, 2, False), (21, 15, 2, False), (28, 1, 2, True),
            (-29, -17, 3, False), (-21, -11, 3, False), (-13, -18, 3, False), (-26, 2, 3, False), (-18, 13, 3, False),
        ],
        young=[(5.8, 8.8, 1), (19.8, 5.8, 1), (8.8, 15.8, 2)],
        hay=[(4, -19, 1.0, 2), (-35, 22, 0.9, 3)], haymaking=(38, -6), shepherd=(-6, 4),
        track=[(16, -11), (6, -8), (-3, -6), (-6, -3.5), (-8, 0), (-8, 12), (-9, 24), GATES["south"]],
    ),
]


def longhouse(p, x, y, w, kind):
    """The byre / stable: a long low timber building with a thatched roof, 13 px wide, wall 4.2, roof 3.8."""
    h, roof_h = 4.2, 3.8
    r1, r2 = (kit.THATCH, kit.THATCH_D) if not p.winter else (kit.SNOW, kit.SNOW_D)
    p.cast(x, y, w)

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
    handle = p.stand(y, fn)
    p.smoke(x + w * 0.3, y - h - roof_h - 0.5, foot=y, on=handle)          # the chimney is off the middle: smoke is tied to it
    return handle


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
    return p.stand(y, fn)


def meadow(p, cx, cy, w, h, season):
    """A fenced meadow of one pale colour. In winter it is snow with two hoof-trodden patches, so the fence never
    encloses plain background."""
    if p.winter:
        pts = p.field(cx, cy, w, h, 0, [kit.SNOW], 1, edge=kit.SNOW_D)
        p.blob(cx - w * 0.18, cy + h * 0.12, w * 0.34, h * 0.30, kit.SNOW_D, alpha=0.85)
        p.blob(cx + w * 0.20, cy - h * 0.14, w * 0.26, h * 0.26, kit.SNOW_D, alpha=0.85)
    else:
        col = MEADOW[season]
        pts = p.field(cx, cy, w, h, 0, [col], 1, edge=kit.shade(col, 0.78))
    p.fence(pts + [pts[0]])


def draw(level, season, variant=0, mirror=False, animal="sheep"):
    assert animal in ANIMALS, animal
    if level == 0:                                    # no piece on the map: the sheet shows the wild land
        return kit.wild(season, "grass", seed=2)
    kind = KIND[animal]
    p = kit.Piece(season, ground="grass", seed=2, mirror=mirror)
    L = LAYOUT[variant]
    sp, su, wi = season == "spring", season == "summer", season == "winter"
    hut, byre, hall = L["hut"], L["byre"], L["hall"]

    # ---- ground plane: trodden ground is an overlay on whatever ground the map has
    p.blob(L["patch"][0], L["patch"][1], 36, 16, p.pal["soil"], alpha=0.3)          # where the herd gathers (the level 1 footprint)
    p.blob(hut[0] + 1, hut[1] + 3.5, 14, 7, p.pal["soil"], alpha=0.3)               # the hut's yard
    if level >= 2:
        p.blob(byre[0], byre[1] + 3, byre[2] + 6, 7, p.pal["soil"], alpha=0.3)      # the byre's yard
    if level >= 3:
        p.road(L["track"], 1.6, track=True)
    for cx, cy, w, h, frm in L["meadows"]:
        if level >= frm:
            meadow(p, cx, cy, w, h, season)
    if level >= 2 and kind == "horse":                # the stable's small fenced yard
        bx, by = byre[0], byre[1]
        yard = [(bx - 7.5, by + 2.5), (bx + 7.5, by + 2.5), (bx + 7.5, by + 6.5), (bx - 7.5, by + 6.5)]
        p.fence(yard + [yard[0]])

    # ---- standing things
    p.house(hut[0], hut[1], 5.5, 3.5, 3.0, wall=4, kind="ridge", roof="thatch", smoke=True)
    if level >= 2:
        longhouse(p, byre[0], byre[1], byre[2], kind)
    for x, y, sc, frm in L["hay"]:
        if level >= frm and not sp:
            p.haystack(x, y, sc)
    if level >= 3:
        market_hall(p, hall[0], hall[1], hall[2], animal)

    # ---- the herd: fixed table; winter keeps only the three nearest the byre; young ones in spring
    for x, y, frm, stays in L["herd"]:
        if level >= frm and (not wi or stays):
            p.animal(x, y, kind, flip=x > 4)
    if sp:
        for x, y, frm in L["young"]:
            if level >= frm:
                p.animal(x, y, kind, flip=x > 4, sc=0.7)
    # ---- season activity
    if not wi:
        p.person(L["shepherd"][0], L["shepherd"][1], (110, 80, 60))                 # the shepherd
    if su and level >= 2:
        p.haystack(L["haymaking"][0], L["haymaking"][1])                            # haymaking
    return p.finish(label="grazing %s L%d v%d%s" % (animal, level, variant, "m" if mirror else ""))


def _draw_for(animal):
    def draw_animal(level, season, variant=0, mirror=False):
        return draw(level, season, variant=variant, mirror=mirror, animal=animal)
    return draw_animal


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    for a in ANIMALS:
        out = os.path.join(outdir, "grazing_%s.png" % a)
        names = dict(NAMES)
        names[3] = HALL_NAME[a]
        kit.sheet(_draw_for(a), LEVELS, "Grazing (%s): levels 0-3 by season" % a, out, names, ground="grass", wild=True)
        print("wrote", os.path.normpath(out))
    out = os.path.join(outdir, "grazing_sheep_variants.png")
    kit.variant_sheet(_draw_for("sheep"), LEVELS, "Grazing (sheep): layouts and mirror", out, NAMES, ground="grass")
    print("wrote", os.path.normpath(out))
