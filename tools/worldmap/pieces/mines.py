"""Mines, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8). Ground: rock.

0 the map's wild rock (scree, boulders and conifers are the map's) - 1 the low outcrop at the back with the adit (a timbered mouth in the outcrop), a
hut, a spoil heap, a track - 2 the headframe with its wheel over a shaft, a second hut and heap, a stream with a water
wheel - 3 the smelter with its tall chimney (smoking in every season), an ore pile, a third heap, and the two huts
upgraded in place to a row of three miners' houses.

Ores: draw(..., ore="iron" | "silver" | "copper") keeps every layout and changes the heap and ore colours, one detail
and the level 3 landmark, which stands on the smelter's foot (iron: the blast furnace, silver: the mint, copper: the
roasting yard). ore=None is the plain mine, pixel for pixel as before.

python mines.py            writes docs/design/map/pieces/mines.png, mines_variants.png and one sheet per ore
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
VARIANTS = 2
ORES = (None, "iron", "silver", "copper")
NAMES = {0: "wild land (the map's)", 1: "adit", 2: "headframe", 3: "smelter, row"}

# Named tokens that are new to this family (rock and ore are not in the kit's list):
OUTCROP = (128, 116, 104)        # the rock outcrop, lit
OUTCROP_D = (92, 84, 78)         # shaded side
ORE = (136, 104, 88)             # the ore pile, lit (rust-brown)
ORE_D = (104, 78, 68)
# ore details (positions are fixed per layout):
# iron: the second, small ore pile by the headframe, from level 2 (x, y)
IRON_PILE = [(2.5, 9.5), (10, 3)]
# copper: 4 flat verdigris stains on the outcrop's lit faces: (block index, x, how far down the face 0-1), per layout
STAINS = [
    [(0, -30.5, 0.55), (0, -25.5, 0.35), (2, -18.0, 0.55), (2, -15.2, 0.3)],
    [(0, -25.0, 0.5), (0, -21.5, 0.3), (2, -40.0, 0.5), (1, -40.0, 0.5)],
]

# ---- the fixed layouts: positions never depend on level or season
# The outcrop is three rock blocks, drawn back to front: (foot y, top profile as (x, height above the foot), ridge x).
# The adit is cut into block 2. Layout 0: the outcrop spans the back, the headframe east of the middle with the wheel
# race on the east side, the smelter west, the row of houses along the front. Layout 1: the outcrop stands on the west
# flank, the headframe at the back of the middle, the wheel race at the back right, the smelter at the front, and the
# row of houses is a column on the east side.
LAYOUT = [
    dict(
        blocks=[
            (-21.0, [(-33, 0), (-32, 5), (-27, 8), (-21, 8.5), (-17, 6), (-16, 0)], -23),
            (-20.6, [(-2, 0), (-1, 5), (2, 6.5), (5, 4.5), (7, 0)], 1),
            (-20.0, [(-20, 0), (-19, 6), (-14, 9.5), (-8, 10.5), (-2, 8.5), (0, 4), (0.8, 0)], -11),
        ],
        shadows=[(-13, -19.2, 42, 4.5, 17)],        # x, y, w, h, shift to the lower right (times p.m)
        adit=(-9, -19.4),                           # foot of the adit's mouth, in the middle block
        track=[(-9, -18), (-7, -8), (-3, 2), (-1, 14), (-3, 30), (-4, 38)],       # ends at the gate point
        heaps=[(-18, -10, 14.0, 7.5, 1), (24, 10, 10.0, 5.6, 2), (16, 19, 9.0, 5.0, 3)],       # x, y, w, h, from level
        headframe=(11, 2),                          # foot of the headframe, from level 2
        # the wheel's race: the piece's own water (streams are the map's), ending in a small pond at each end, inside the hex
        stream=[(37, -13), (35, -7), (33, 0), (35, 7), (37, 13)],
        wheel=(34.5, -2.5),                         # foot of the water wheel, on the stream
        smelter=(-24, 6),                           # foot of the smelter, from level 3
        ore=(-9, 9),                                # the ore pile, from level 3
        # huts become houses in place; the row's third house is new at level 3: x, y, from level
        houses=[(-33, 22, 1), (-21, 22, 2), (-9, 23, 3)],
        # the worked yard grows with the level: trodden earth laid over the rock (x, y, w, h, from level)
        yards=[(-12, -8, 46, 20, 1), (-31, 20, 18, 8, 1),               # under the adit and the first heap; the hut
               (12, 4, 40, 22, 2), (-19, 20, 18, 8, 2),                  # under the headframe and its heap; the second hut
               (-22, 9, 34, 22, 3), (-12, 21, 42, 10, 3)],              # under the smelter; along the row of houses
    ),
    dict(
        blocks=[
            (-22.0, [(-28, 0), (-27, 5), (-22, 8), (-16, 8.5), (-12, 6), (-11, 0)], -19),
            (6.0, [(-42, 0), (-41, 4.5), (-37, 6.5), (-33, 4.5), (-32, 0)], -37),
            (-7.0, [(-42, 0), (-41, 6), (-36, 9.5), (-30, 10.5), (-24, 8.5), (-22, 4), (-21.2, 0)], -32),
        ],
        shadows=[(-19, -20.2, 22, 4.0, 10), (-31.5, -5.2, 22, 4.0, 10), (-37, 7.8, 14, 3.5, 8)],
        adit=(-31, -5.4),
        track=[(-31, -2), (-29, 6), (-26, 16), (-21, 26), (-16, 33)],
        heaps=[(-19, 5, 14.0, 7.5, 1), (-6, 10, 10.0, 5.6, 2), (14, 12, 9.0, 5.0, 3)],
        headframe=(3, -6),
        stream=[(13, -26), (19, -25), (25, -22), (30, -18)],
        wheel=(22, -23.5),
        smelter=(-4, 26),
        ore=(12, 28),
        houses=[(25, -6, 1), (26, 5, 2), (27, 16, 3)],
        yards=[(-26, -2, 40, 22, 1), (27, -8, 18, 8, 1),
               (4, -4, 40, 22, 2), (28, 3, 18, 8, 2),
               (-2, 24, 34, 22, 3), (27, 6, 14, 30, 3)],
    ),
]
GATES = [{"south": (-4, 38)}, {"south": (-16, 33)}]       # where the map's road layer joins the track
YARD_ALPHA = 0.35


def outcrop(p, L, stains=()):
    """The low rock outcrop: three blocks of rock. It stays at every level; the adit is cut into it at level 1.
    stains: (block, x, down) verdigris patches on the lit faces (copper)."""
    winter = p.winter
    for sx, sy, sw, sh, dx in L["shadows"]:
        p.shadow(sx + p.m * dx, sy, sw, sh)             # the outcrop's own shadow, lower right of its middle
    handles = []
    for bi, (base, prof, ridge) in enumerate(L["blocks"]):
        top = [(x, base - h) for x, h in prof]
        mine = [(sx, sd) for b, sx, sd in stains if b == bi]

        def fn(pen, top=top, base=base, ridge=ridge, mine=mine):
            body = top + [(top[-1][0], base), (top[0][0], base)]
            pen.poly(body, OUTCROP, None)
            ir = max(i for i, q in enumerate(top) if q[0] <= ridge)
            dark = [top[ir]] + top[ir + 1:] + [(top[-1][0], base), (ridge + 2.5, base)]
            pen.poly(dark, OUTCROP_D, None)
            for sx, sd in mine:                              # flat verdigris stains, the lit face only
                ty = base - 6.0
                for (xa, ya), (xb, yb) in zip(top, top[1:]):
                    if xa <= sx <= xb:
                        ty = ya + (yb - ya) * (sx - xa) / (xb - xa)
                sy = ty + 2.4 + (base - ty - 3.4) * sd
                pen.poly([(sx - 1.7, sy), (sx - 0.4, sy - 1.1), (sx + 1.5, sy - 0.8), (sx + 1.9, sy + 0.5), (sx + 0.3, sy + 1.2), (sx - 1.4, sy + 0.9)], kit.VERDIGRIS, None)
            if winter:                                       # snow on the top faces
                pen.poly(top + [(x + 0.4, y + 2.6) for x, y in reversed(top)], kit.SNOW, None)
            pen.poly(body, None, kit.INK, 0.5)
            for k in range(1, len(top) - 1, 2):              # cracks
                pen.line((top[k][0] + 0.6, top[k][1] + 2.4), (top[k][0] + 1.4, base - 0.8), OUTCROP_D, 0.5)
        handles.append(p.stand(base, fn))
    return handles


def adit(p, rock, at):
    """Level 1 landmark: a dark arched mouth in the outcrop, framed with timber."""
    x, y = at

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


SPOIL4 = {None: (kit.SPOIL, kit.SPOIL_D, ORE, ORE_D)}
for _o, _c in kit.ORES.items():
    SPOIL4[_o] = (_c["spoil"], _c["spoil_d"], _c["ore"], _c["ore_d"])


def blast_furnace(p, x, y):
    """Iron, level 3, on the smelter's foot: a tapered grey stone stack (15 px tall, 7 wide at the foot) with a timber
    charging bridge on its right and the mouth at its foot glowing (GLOW, 2 x 2 px: the only light of the family).
    The stack smokes in every season."""
    winter = p.winter
    p.cast(x, y, 12)
    top = y - 15.0

    def fn(pen):
        # the charging bridge: a ramp from the ground up to the stack's top, on two trestles (drawn first, behind)
        a, b = (x + 12.5, y - 0.4), (x + 2.6, top + 1.6)
        pen.poly([(b[0], b[1]), (a[0] - 1.6, a[1] - 1.4), (a[0], a[1] - 0.2), (b[0] + 0.4, b[1] + 1.4)], kit.TIMBER, kit.INK, 0.5)
        for tx in (x + 6.0, x + 9.4):
            ty = b[1] + (a[1] - b[1]) * (tx - b[0]) / (a[0] - b[0])
            pen.rect(tx - 0.5, ty, 1.0, y - ty - 0.2, kit.TIMBER_D, None)
        if winter:
            pen.line((b[0] + 0.6, b[1] - 0.2), (a[0] - 1.4, a[1] - 1.7), kit.SNOW, 0.8)
        # the stack: tapered, lit left, shaded right
        body = [(x - 3.5, y), (x + 3.5, y), (x + 2.2, top), (x - 2.2, top)]
        pen.poly(body, kit.STONE_GREY, None)
        pen.poly([(x + 0.4, y), (x + 3.5, y), (x + 2.2, top), (x + 0.2, top)], kit.STONE_GREY_D, None)
        pen.rect(x - 4.4, y - 2.2, 8.8, 2.2, kit.STONE_GREY, None)                   # the stone plinth
        pen.rect(x + 0.6, y - 2.2, 3.8, 2.2, kit.STONE_GREY_D, None)
        pen.line((x - 2.9, y - 7.0), (x + 2.9, y - 7.0), kit.STONE_GREY_D, 0.5)       # two iron hoops
        pen.line((x - 2.5, y - 11.0), (x + 2.5, y - 11.0), kit.STONE_GREY_D, 0.5)
        pen.rect(x - 2.9, top - 1.0, 5.8, 1.2, kit.STONE_GREY if not winter else kit.SNOW_D, kit.INK, 0.5)      # the rim
        pen.rect(x + 0.4, top - 1.0, 2.5, 1.2, kit.STONE_GREY_D, None)
        if winter:
            pen.line((x - 2.9, top - 1.2), (x + 2.9, top - 1.2), kit.SNOW, 0.9)
        pen.poly(body, None, kit.INK, 0.5)
        pen.rect(x - 4.4, y - 2.2, 8.8, 2.2, None, kit.INK, 0.5)
        # the mouth: a dark arch with one glowing spot (the same in every season)
        pen.rect(x - 1.5, y - 2.0, 3.0, 2.0, kit.DOOR, None)
        pen.rect(x - 1.0, y - 1.2, 2.0, 1.2, kit.GLOW, None)
    stack = p.stand(y, fn, x=x)
    p.smoke(x, top - 2.6, always=True, foot=y, on=stack)


def mint(p, x, y):
    """Silver, level 3, on the smelter's foot: a white house on a grey stone base, a slate roof, a barred dark door,
    and a stamp frame (two timber posts and a beam, 6 px) beside it. No smoke of its own: the usual house smoke."""
    house = p.house(x, y, 10.0, 7.0, 3.6, wall=kit.PLASTER[3], kind="ridge", roof="slate", door=False, smoke=True)

    def fn(pen):
        pen.rect(x - 5.0, y - 1.3, 10.0, 1.3, kit.STONE_GREY, kit.INK, 0.5)                # the stone base
        pen.rect(x + 2.4, y - 1.3, 2.6, 1.3, kit.STONE_GREY_D, None)
        pen.rect(x - 1.2, y - 3.6, 2.4, 2.3, kit.DOOR, None)                                # the barred door
        pen.line((x, y - 3.5), (x, y - 1.4), kit.STONE_GREY, 0.4)                          # the bars
    p.stand(y + 0.1, fn, x=x, on=house)
    sx = x + 10.0
    p.cast(sx, y, 5)

    def stamp(pen):
        pen.rect(sx - 2.6, y - 6.0, 1.1, 6.0, kit.TIMBER, kit.INK, 0.5)
        pen.rect(sx + 1.5, y - 6.0, 1.1, 6.0, kit.TIMBER_D, kit.INK, 0.5)
        pen.rect(sx - 3.2, y - 6.8, 6.4, 1.2, kit.TIMBER, kit.INK, 0.5)
        pen.rect(sx + 0.6, y - 6.8, 2.6, 1.2, kit.TIMBER_D, None)
        pen.line((sx, y - 5.6), (sx, y - 2.6), kit.STONE_GREY_D, 0.9)                        # the stamp hanging in the frame
        pen.rect(sx - 1.2, y - 2.8, 2.4, 1.4, kit.STONE_GREY_D, kit.INK, 0.5)
        if p.winter:
            pen.line((sx - 3.0, y - 7.0), (sx + 3.0, y - 7.0), kit.SNOW, 0.8)
    p.stand(y + 0.05, stamp, x=sx)


def roasting_yard(p, x, y):
    """Copper, level 3, on the smelter's foot: three low dark heaps in a row (7 x 4 px, an orange line at the foot) on a
    trodden yard, each smoking in every season (the three smokes are the activity limit)."""
    p.blob(x - 2.5, y - 1.0, 36, 10, p.pal["soil"], alpha=YARD_ALPHA)
    orange = kit.ORES["copper"]["ore"]
    for hx in (x - 11.0, x - 2.5, x + 6.0):
        p.cast(hx, y, 6)

        def fn(pen, hx=hx):
            dome = [(hx - 3.5, y), (hx - 2.8, y - 2.4), (hx - 1.2, y - 3.8), (hx + 1.2, y - 3.8), (hx + 2.8, y - 2.4), (hx + 3.5, y)]
            pen.poly(dome, kit.TRUNK, None)
            pen.poly([(hx + 0.4, y - 3.8), (hx + 1.2, y - 3.8), (hx + 2.8, y - 2.4), (hx + 3.5, y), (hx + 0.2, y)], kit.shade(kit.TRUNK, 0.8), None)
            pen.line((hx - 3.0, y - 0.5), (hx + 3.0, y - 0.5), orange, 0.7)
            pen.poly(dome, None, kit.INK, 0.5)
        h = p.stand(y, fn, x=hx)
        p.smoke(hx, y - 5.6, always=True, foot=y, on=h)


LANDMARKS = {None: smelter, "iron": blast_furnace, "silver": mint, "copper": roasting_yard}      # gold: task 17


def draw(level, season, variant=0, mirror=False, ore=None):
    assert ore in ORES, ore
    if level == 0:                                    # no piece: the sheets show the map's wild rock
        return kit.wild(season, "rock", seed=4)
    p = kit.Piece(season, ground="rock", seed=4, mirror=mirror)
    L = LAYOUT[variant]
    # ---- ground plane
    for x, y, w, h, lo in L["yards"]:                      # worked ground under each landmark, growing with the level
        if level >= lo:
            p.blob(x, y, w, h, p.pal["soil"], alpha=YARD_ALPHA)
    if level >= 2:
        p.water(L["stream"], 2.0)
        for x, y in (L["stream"][0], L["stream"][-1]):
            p.pond([(x + math.cos(i * math.pi / 6) * 4.0, y + math.sin(i * math.pi / 6) * 2.5) for i in range(12)])
    p.road(L["track"], 1.5, track=True)

    # ---- standing things
    spoil, spoil_d, pile, pile_d = SPOIL4[ore]
    rock = outcrop(p, L, STAINS[variant] if ore == "copper" else ())
    adit(p, rock[2], L["adit"])                                  # cut into the middle block: it moves with it
    for x, y, w, h, lo in L["heaps"]:
        if level >= lo:
            p.heap(x, y, w, h, spoil, spoil_d)
    if level >= 2:
        water_wheel(p, *L["wheel"])
        headframe(p, *L["headframe"])
        if ore == "iron":                                 # the second, small ore pile by the headframe
            p.heap(IRON_PILE[variant][0], IRON_PILE[variant][1], 6.0, 3.4, pile, pile_d)
    if level >= 3:
        LANDMARKS[ore](p, *L["smelter"])
        p.heap(L["ore"][0], L["ore"][1], 8.0, 4.6, pile, pile_d)
    for i, (x, y, lo) in enumerate(L["houses"]):
        if level < lo:
            continue
        if level >= 3:                                # upgraded in place: the same foot, a bigger house
            p.house(x, y, 7.6, 4.6, 3.6, wall=i + 1, kind="ridge" if i % 2 else "gable", roof="thatch", smoke=(i == 2 and ore != "copper"))
        else:
            p.house(x, y, 5.5, 3.5, 3.0, wall=i, kind="ridge", roof="thatch", smoke=(i == 0))
    return p.finish(label="mines L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "mines.png")
    kit.sheet(draw, LEVELS, "Mines: levels 0-3 by season", out, NAMES, ground="rock", wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "mines_variants.png")
    kit.variant_sheet(draw, LEVELS, "Mines: layout and mirror", vout, NAMES, ground="rock")
    print("wrote", os.path.normpath(vout))
    for o in ORES[1:]:
        def draw_o(level, season, variant=0, mirror=False, o=o, **kw):
            return draw(level, season, variant, mirror, ore=o)
        oout = os.path.join(os.path.dirname(out), "mines_%s.png" % o)
        kit.sheet(draw_o, LEVELS, "Mines, %s: levels 0-3 by season" % o, oout, NAMES, ground="rock", wild=True)
        print("wrote", os.path.normpath(oout))
