"""Mines, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8). Ground: rock.

0 the map's wild rock (scree, boulders and conifers are the map's) - 1 the low outcrop at the back with the adit (a timbered mouth in the outcrop), a
hut, a spoil heap, a track - 2 the headframe with its wheel over a shaft, a second hut and heap, a stream with a water
wheel - 3 the smelter with its tall chimney (smoking in every season), an ore pile, a third heap, and the two huts
upgraded in place to a row of three miners' houses.

python mines.py            writes docs/design/map/pieces/mines.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
VARIANTS = 1
NAMES = {0: "wild land (the map's)", 1: "adit", 2: "headframe", 3: "smelter, row"}

# Named tokens that are new to this family (rock and ore are not in the kit's list):
OUTCROP = (128, 116, 104)        # the rock outcrop, lit
OUTCROP_D = (92, 84, 78)         # shaded side
ORE = (136, 104, 88)             # the ore pile, lit (rust-brown)
ORE_D = (104, 78, 68)

# ---- the fixed layout: positions never depend on level or season
OUTCROP_BASE = -21               # y of the outcrop's foot
# the outcrop is three rock blocks, drawn back to front: (foot y offset, top profile as (x, height above the foot), ridge x)
OUTCROP_BLOCKS = [
    (0.0, [(-33, 0), (-32, 5), (-27, 8), (-21, 8.5), (-17, 6), (-16, 0)], -23),
    (0.4, [(-2, 0), (-1, 5), (2, 6.5), (5, 4.5), (7, 0)], 1),
    (1.0, [(-20, 0), (-19, 6), (-14, 9.5), (-8, 10.5), (-2, 8.5), (0, 4), (0.8, 0)], -11),
]
ADIT = (-9, OUTCROP_BASE + 1.6)             # foot of the adit's mouth, in the middle block
TRACK = [(-9, -18), (-7, -8), (-3, 2), (-1, 14), (-3, 30), (-4, 38)]       # ends at the gate point, 13 px inside the border
GATES = {"south": (-4, 38)}                 # where the map's road layer joins the track
HEAPS = [(-18, -10, 14.0, 7.5, 1), (24, 10, 10.0, 5.6, 2), (16, 19, 9.0, 5.0, 3)]       # x, y, w, h, from level
HEADFRAME = (11, 2)                         # foot of the headframe, from level 2
STREAM = [(52, -14), (44, -11), (36, -6), (33, 0), (36, 7), (43, 12), (52, 18)]
WHEEL = (34.5, -2.5)                        # foot of the water wheel, on the stream
SMELTER = (-24, 6)                          # foot of the smelter, from level 3
ORE_PILE = (-9, 9)                          # from level 3
# huts become houses in place; the row's third house is new at level 3: x, y, from level
HOUSES = [(-33, 22, 1), (-21, 22, 2), (-9, 23, 3)]
# the worked yard grows with the level: trodden earth laid over the rock (x, y, w, h, from level)
YARDS = [(-12, -8, 46, 20, 1), (-31, 20, 18, 8, 1),               # under the adit and the first heap; the hut
         (12, 4, 40, 22, 2), (-19, 20, 18, 8, 2),                  # under the headframe and its heap; the second hut
         (-22, 9, 34, 22, 3), (-12, 21, 42, 10, 3)]               # under the smelter; along the row of houses
YARD_ALPHA = 0.35


def outcrop(p):
    """The low rock outcrop at the back: three blocks of rock. It stays at every level; the adit is cut into it at level 1."""
    winter = p.winter
    y0 = OUTCROP_BASE
    p.shadow(-13 + p.m * 17, y0 + 1.8, 42, 4.5)         # the outcrop's own shadow, lower right of its middle (x = -13)
    handles = []
    for dy, prof, ridge in OUTCROP_BLOCKS:
        base = y0 + dy
        top = [(x, base - h) for x, h in prof]

        def fn(pen, top=top, base=base, ridge=ridge):
            body = top + [(top[-1][0], base), (top[0][0], base)]
            pen.poly(body, OUTCROP, None)
            ir = max(i for i, q in enumerate(top) if q[0] <= ridge)
            dark = [top[ir]] + top[ir + 1:] + [(top[-1][0], base), (ridge + 2.5, base)]
            pen.poly(dark, OUTCROP_D, None)
            if winter:                                       # snow on the top faces
                pen.poly(top + [(x + 0.4, y + 2.6) for x, y in reversed(top)], kit.SNOW, None)
            pen.poly(body, None, kit.INK, 0.5)
            for k in range(1, len(top) - 1, 2):              # cracks
                pen.line((top[k][0] + 0.6, top[k][1] + 2.4), (top[k][0] + 1.4, base - 0.8), OUTCROP_D, 0.5)
        handles.append(p.stand(base, fn))
    return handles


def adit(p, rock):
    """Level 1 landmark: a dark arched mouth in the outcrop, framed with timber."""
    x, y = ADIT

    def fn(pen):
        pen.poly([(x - 3.2, y), (x - 3.2, y - 4.2), (x - 1.8, y - 5.6), (x + 1.8, y - 5.6), (x + 3.2, y - 4.2), (x + 3.2, y)], kit.DOOR, None)
        pen.rect(x - 4.2, y - 6.0, 1.3, 6.0, kit.TIMBER, kit.INK, 0.5)            # posts
        pen.rect(x + 2.9, y - 6.0, 1.3, 6.0, kit.TIMBER_D, kit.INK, 0.5)
        pen.rect(x - 4.8, y - 6.9, 9.6, 1.4, kit.TIMBER, kit.INK, 0.5)           # lintel
        pen.rect(x + 2.0, y - 6.9, 2.8, 1.4, kit.TIMBER_D, None)
        if p.winter:
            pen.rect(x - 4.8, y - 7.7, 9.6, 1.0, kit.SNOW, None)
        pen.line((x - 1.6, y), (x - 2.6, y + 3.4), kit.TIMBER_D, 0.5)              # two rails run out
        pen.line((x + 1.6, y), (x + 2.2, y + 3.4), kit.TIMBER_D, 0.5)
    return p.stand(y + 0.3, fn, on=rock)


def headframe(p, x, y):
    """Level 2 landmark: a timber A-frame over the shaft with the winding wheel at the top, 19 px tall."""
    p.cast(x, y, 9)
    winter = p.winter
    top = (x, y - 15.5)

    def fn(pen):
        # the shaft head: a low stone collar and a small shaft house
        pen.ellipse(x, y - 0.6, 11, 4.4, kit.STONE_GREY_D, kit.INK, 0.5)
        pen.ellipse(x, y - 0.9, 9, 3.2, kit.DOOR, None)
        # back stay from the wheel to the shaft house (it lies on the house's side in a mirrored piece), behind the legs
        pen.line((top[0], top[1] + 1), (x + p.m * 8.5, y - 4.5), kit.INK, 0.5)
        # two legs: the left lit, the right shaded
        pen.poly([(x - 5.2, y), (x - 3.9, y), (x + 0.3, top[1] + 1.4), (x - 0.9, top[1] + 1.4)], kit.TIMBER, kit.INK, 0.5)
        pen.poly([(x + 5.2, y), (x + 3.9, y), (x + 0.3, top[1] + 1.4), (x + 0.9, top[1] + 1.4)], kit.TIMBER_D, kit.INK, 0.5)
        pen.line((x - 3.4, y - 3.6), (x + 3.4, y - 3.6), kit.TIMBER_D, 0.9)          # cross braces
        pen.line((x - 2.2, y - 7.2), (x + 2.2, y - 7.2), kit.TIMBER_D, 0.9)
        pen.line((x - 3.4, y - 3.6), (x + 2.2, y - 7.2), kit.TIMBER_D, 0.5)
        # the winding wheel at the top: a ring with spokes
        pen.circle(top[0], top[1], 3.5, kit.TIMBER_D, kit.INK, 0.5)
        pen.circle(top[0], top[1], 2.3, kit.STONE_GREY, None)
        for dx, dy in ((-2.3, 0), (2.3, 0), (0, -2.3), (0, 2.3)):
            pen.line((top[0], top[1]), (top[0] + dx, top[1] + dy), kit.TIMBER_D, 0.5)
        pen.circle(top[0], top[1], 0.6, kit.INK, None)
        if winter:
            pen.line((x - 1.8, top[1] - 3.2), (x + 1.8, top[1] - 3.2), kit.SNOW, 1.0)
        # the cable down to the shaft
        pen.line((x - 2.9, top[1] + 0.6), (x - 2.9, y - 1.0), kit.INK, 0.5)
    p.stand(y, fn, x=x)
    # the shaft house beside it (a thatched shed, the engine house)
    p.house(x + 8.5, y + 0.8, 6.8, 4.0, 3.0, wall=kit.shade(kit.TIMBER, 1.25), kind="ridge", roof="thatch", door=True)


def water_wheel(p, x, y):
    """The water wheel on the stream: an upright wheel with paddles, its foot in the water."""
    p.cast(x, y, 5)
    winter = p.winter

    def fn(pen):
        cy = y - 3.6
        pen.circle(x, cy, 3.9, kit.TIMBER_D, kit.INK, 0.5)
        pen.circle(x, cy, 2.7, kit.TIMBER, None)
        for dx, dy in ((-2.6, 0), (2.6, 0), (0, -2.6), (0, 2.6), (-1.8, -1.8), (1.8, 1.8), (1.8, -1.8), (-1.8, 1.8)):
            pen.line((x, cy), (x + dx, cy + dy), kit.TIMBER_D, 0.5)
        pen.circle(x, cy, 0.7, kit.INK, None)
        if winter:
            pen.line((x - 2.4, cy - 3.2), (x + 0.6, cy - 3.9), kit.SNOW, 0.9)
        pen.line((x - 4.6, y + 0.4), (x + 4.6, y + 0.4), kit.TIMBER_D, 1.0)                    # the trough it sits in
    p.stand(y, fn, x=x)


def smelter(p, x, y):
    """Level 3 landmark: a wide stone furnace house with a tall square chimney, 19 px tall. Smokes in every season."""
    winter = p.winter
    p.cast(x, y, 13)
    cxm, chy = x - 4.2, y - 0.6                      # the chimney's foot: hidden behind the house, drawn first

    def chimney(pen):
        h = 19.5
        pen.poly([(cxm - 2.0, chy), (cxm + 2.0, chy), (cxm + 1.5, chy - h), (cxm - 1.5, chy - h)], kit.STONE_GREY, None)
        pen.poly([(cxm + 0.5, chy), (cxm + 2.0, chy), (cxm + 1.5, chy - h), (cxm + 0.3, chy - h)], kit.STONE_GREY_D, None)
        pen.rect(cxm - 2.1, chy - h - 1.2, 4.2, 1.4, kit.STONE_GREY if not winter else kit.SNOW_D, kit.INK, 0.5)
        pen.rect(cxm + 0.7, chy - h - 1.2, 1.4, 1.4, kit.STONE_GREY_D, None)
        pen.poly([(cxm - 2.0, chy), (cxm + 2.0, chy), (cxm + 1.5, chy - h), (cxm - 1.5, chy - h)], None, kit.INK, 0.5)
        if winter:
            pen.line((cxm - 2.0, chy - h - 1.4), (cxm + 2.0, chy - h - 1.4), kit.SNOW, 0.9)
    stack = p.stand(y - 0.5, chimney, x=cxm)
    p.smoke(cxm, chy - 19.5 - 1.6, always=True, foot=y - 0.5, on=stack)       # smokes in every season, on its chimney
    house = p.house(x, y, 12.5, 6.2, 3.8, wall=kit.STONE_GREY, kind="ridge", roof="slate", door=False)
    # the furnace mouth: a dark arch with a red glow, the one warm spot
    p.stand(y + 0.1, lambda pen: (pen.rect(x - 2.0, y - 3.4, 4.0, 3.4, kit.DOOR, None), pen.rect(x - 1.0, y - 1.6, 2.0, 1.4, kit.ROOF, None)), x=x, on=house)


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece: the sheets show the map's wild rock
        return kit.wild(season, "rock", seed=4)
    p = kit.Piece(season, ground="rock", seed=4, mirror=mirror)
    # ---- ground plane
    for x, y, w, h, lo in YARDS:                      # worked ground under each landmark, growing with the level
        if level >= lo:
            p.blob(x, y, w, h, p.pal["soil"], alpha=YARD_ALPHA)
    if level >= 2:
        p.water(STREAM, 3.0)
    p.road(TRACK, 1.5, track=True)

    # ---- standing things
    rock = outcrop(p)
    adit(p, rock[2])                                  # cut into the middle block: it moves with it
    for x, y, w, h, lo in HEAPS:
        if level >= lo:
            p.heap(x, y, w, h, kit.SPOIL, kit.SPOIL_D)
    if level >= 2:
        water_wheel(p, *WHEEL)
        headframe(p, *HEADFRAME)
    if level >= 3:
        smelter(p, *SMELTER)
        p.heap(ORE_PILE[0], ORE_PILE[1], 8.0, 4.6, ORE, ORE_D)
    for i, (x, y, lo) in enumerate(HOUSES):
        if level < lo:
            continue
        if level >= 3:                                # upgraded in place: the same foot, a bigger house
            p.house(x, y, 7.6, 4.6, 3.6, wall=i + 1, kind="ridge" if i % 2 else "gable", roof="thatch", smoke=(i == 2))
        else:
            p.house(x, y, 5.5, 3.5, 3.0, wall=i, kind="ridge", roof="thatch", smoke=(i == 0))
    return p.finish(label="mines L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "mines.png")
    kit.sheet(draw, LEVELS, "Mines: levels 0-3 by season", out, NAMES, ground="rock", wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "mines_variants.png")
    kit.variant_sheet(draw, LEVELS, "Mines: layout and mirror", vout, NAMES, ground="rock")
    print("wrote", os.path.normpath(vout))
