"""Grazing, levels 0-3, for sheep, cattle or horses (see docs/design/map/pieces/GUIDE.md, section 8).

0 the map's wild land (no piece) - 1 loose animals on a trodden patch, a shepherd, a hut - 2 a fenced meadow, the byre -
3 three meadows, the market hall. Three layouts (LAYOUT) and the mirror; layout 2 is the upland pens (stone-walled
pastures and a round stone fold for sheep and cattle, three round paddocks for horses). One layout table for all three animals:
draw(level, season, variant=0, mirror=False, animal="sheep"|"cattle"|"horses"). Only the animal, the byre's openings
and the market hall's goods differ. The piece draws no wild land: the map's trees and scrub stand round the work.

python grazing.py          writes grazing_sheep.png, grazing_cattle.png, grazing_horses.png, grazing_sheep_variants.png
                           and grazing_horses_variants.png
python grazing.py DIR      the same, into DIR
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "loose herd, hut", 2: "meadow, byre", 3: "3 meadows, hall"}
VARIANTS = 3
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
    dict(  # layout 2: the upland pens. The hut at the back right, the byre at the back left of the middle, the hall at the back left.
        # Its meadows have two forms, by the animal (FORM): "walled" (sheep, cattle) = odd pastures inside dry-stone walls and
        # a round stone fold; "round" (horses) = three round paddocks. hut, byre, hall, hay, haymaking, shepherd and track are shared;
        # the herd's places differ by form. Herd entries: x, y, from level, the animals that stay out in winter; young: as above.
        hut=(16, -24), byre=(-10, -3, 13.0), hall=(-26, -16, 16.0),
        hay=[(6, -20, 1.0, 2), (38, -18, 0.9, 3)], haymaking=(22, -22), shepherd=(-17, 4),
        track=[(-10, 0), (-14, 8), (-14, 20), (-12, 28), GATES["south"]],
        walled=dict(
            # the pastures: from level, corners. P1 and P3 share the side (12, 4)-(28, 12): the walls are drawn once.
            pastures=[
                (2, [(-6, 9), (12, 4), (28, 12), (23, 28), (-3, 24)]),
                (3, [(-22, 9), (-35, 3), (-40, 16), (-30, 25), (-20, 24)]),
                (3, [(12, 4), (28, 12), (40, 4), (34, -12), (17, -10)]),
            ],
            patch=(8, 17, 36, 16),
            fold=(-28, -4, 6.0),                         # the round stone fold by the byre, from level 2
            herd=[
                (2, 11, 1, ("sheep", "cattle")), (7, 21, 1, ()), (13, 14, 1, ("cattle",)), (19, 22, 1, ()), (23, 16, 1, ()),
                (-31.5, -4.5, 2, ("sheep",)), (-24.5, -3, 2, ("sheep",)), (12, 9, 2, ("cattle",)),
                (20, -2, 3, ()), (30, 1, 3, ()), (24, -8, 3, ()), (-30, 14, 3, ()), (-26, 22, 3, ()),
            ],
            young=[(3.2, 11.8, 1), (14.2, 14.8, 1), (13.2, 9.8, 2)],
        ),
        round=dict(
            rings=[(8, 16, 16, 2), (-26, 14, 11, 3), (27, -3, 11, 3)],      # cx, cy, radius, from level
            patch=(8, 16, 32, 18),
            herd=[
                (5, 10, 1, ("horses",)), (0, 14, 1, ("horses",)), (8, 20, 1, ()), (14, 12, 1, ("horses",)), (18, 19, 1, ()),
                (-3, 19, 2, ()), (12, 24, 2, ()), (21, 15, 2, ()),
                (-31, 16, 3, ()), (-25, 19, 3, ()), (-28, 12, 3, ()), (24, -3, 3, ()), (31, 0, 3, ()),
            ],
            young=[(6.2, 10.8, 1), (1.2, 14.8, 1), (13.2, 24.8, 2)],
        ),
    ),
]
FORM = {"sheep": "walled", "cattle": "walled", "horses": "round"}


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


def meadow_poly(p, pts, season):
    """A pasture of one pale colour inside dry-stone walls (the walls are drawn once for all pastures: upland_walls).
    In winter snow with two hoof-trodden patches, as meadow()."""
    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
    cx, cy, w, h = sum(xs) / len(xs), sum(ys) / len(ys), max(xs) - min(xs), max(ys) - min(ys)
    if p.winter:
        p.patch(pts, kit.SNOW)
        p.blob(cx - w * 0.14, cy + h * 0.10, w * 0.26, h * 0.24, kit.SNOW_D, alpha=0.85)
        p.blob(cx + w * 0.14, cy - h * 0.10, w * 0.20, h * 0.22, kit.SNOW_D, alpha=0.85)
    else:
        col = MEADOW[season]
        p.patch(pts, col, kit.shade(col, 0.78))


def meadow_ring(p, cx, cy, r, season):
    """The inside of a round pen: the meadow colour (snow in winter), drawn before the ring."""
    pts = kit.ring_points(cx, cy, r, r * kit.TILT, 0, 2 * math.pi, max(16, int(r * 2.2)))
    if p.winter:
        p.patch(pts, kit.SNOW)
        p.blob(cx - r * 0.2, cy + r * 0.12, r * 0.7, r * 0.5, kit.SNOW_D, alpha=0.85)
    else:
        col = MEADOW[season]
        p.patch(pts, col, kit.shade(col, 0.78))


def upland_walls(p, pastures):
    """The dry-stone walls of the pastures: every side once, so two pastures that share a side get one wall."""
    seen, runs = set(), []
    for pts in pastures:
        for a, b in zip(pts, pts[1:] + pts[:1]):
            key = frozenset((a, b))
            if key not in seen:
                seen.add(key)
                runs.append((a, b))
    for a, b in runs:
        p.drystone([a, b])


def draw_upland(level, season, animal, mirror):
    """Layout 2, the upland pens: the same hut, byre, hall, haystacks, track, herd counts and seasons as layouts 0 and 1."""
    kind = KIND[animal]
    p = kit.Piece(season, ground="grass", seed=2, mirror=mirror)
    L = LAYOUT[2]
    F = L[FORM[animal]]
    sp, su, wi = season == "spring", season == "summer", season == "winter"
    hut, byre, hall = L["hut"], L["byre"], L["hall"]
    px, py, pw, ph = F["patch"]
    p.blob(px, py, pw, ph, p.pal["soil"], alpha=0.3)                                 # where the herd gathers (the level 1 footprint)
    p.blob(hut[0] + 1, hut[1] + 3.5, 14, 7, p.pal["soil"], alpha=0.3)
    if level >= 2:
        p.blob(byre[0], byre[1] + 3, byre[2] + 6, 7, p.pal["soil"], alpha=0.3)
    if level >= 3:
        p.road(L["track"], 1.6, track=True)
    if FORM[animal] == "walled":
        pastures = [pts for frm, pts in F["pastures"] if level >= frm]
        for pts in pastures:
            meadow_poly(p, pts, season)
        upland_walls(p, pastures)
        if level >= 2:
            fx, fy, fr = F["fold"]
            meadow_ring(p, fx, fy, fr, season)
            p.ring(fx, fy, fr, kind="stone", gate=90)
    else:
        for cx, cy, r, frm in F["rings"]:
            if level >= frm:
                p.blob(cx, cy + 1, r * 2 + (9 if frm == 2 else 5), r * 1.7 + (7 if frm == 2 else 4), p.pal["soil"], alpha=0.3)    # the trodden apron round the paddock
                meadow_ring(p, cx, cy, r, season)
                if frm == 2:
                    p.blob(cx, cy + 1, r * 1.0, r * 0.7, p.pal["soil"], alpha=0.3)   # the trodden middle
                p.ring(cx, cy, r, kind="fence")

    p.house(hut[0], hut[1], 5.5, 3.5, 3.0, wall=4, kind="ridge", roof="thatch", smoke=True)
    if level >= 2:
        longhouse(p, byre[0], byre[1], byre[2], kind)
    for x, y, sc, frm in L["hay"]:
        if level >= frm and not sp:
            p.haystack(x, y, sc)
    if level >= 3:
        market_hall(p, hall[0], hall[1], hall[2], animal)

    for x, y, frm, stays in F["herd"]:
        if level >= frm and (not wi or animal in stays):
            p.animal(x, y, kind, flip=x > 4)
    if sp:
        for x, y, frm in F["young"]:
            if level >= frm:
                p.animal(x, y, kind, flip=x > 4, sc=0.7)
    if not wi:
        p.person(L["shepherd"][0], L["shepherd"][1], (110, 80, 60))
    if su and level >= 2:
        p.haystack(L["haymaking"][0], L["haymaking"][1])
    return p.finish(label="grazing %s L%d v2%s" % (animal, level, "m" if mirror else ""))


def draw(level, season, variant=0, mirror=False, animal="sheep"):
    assert animal in ANIMALS, animal
    if level == 0:                                    # no piece on the map: the sheet shows the wild land
        return kit.wild(season, "grass", seed=2)
    if variant == 2:
        return draw_upland(level, season, animal, mirror)
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
    out = os.path.join(outdir, "grazing_horses_variants.png")
    kit.variant_sheet(_draw_for("horses"), LEVELS, "Grazing (horses): layouts and mirror", out, {**NAMES, 3: HALL_NAME["horses"]}, ground="grass")
    print("wrote", os.path.normpath(out))
