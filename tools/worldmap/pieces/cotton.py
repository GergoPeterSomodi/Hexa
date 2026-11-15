"""Cotton, levels 1-3 (see docs/design/map/pieces/GUIDE.md, sections 4, 6 and 8: "Cotton").

1 one patch of red earth (22 x 16 px) with five plant rows along its long side, a thatched hut - 2 three patches, the drying
shed (a thatched roof on posts, white under it) and two bales - 3 five patches, the gin house (two storeys, plastered, tile
roof, a hoist beam on its right), four bales, a track. Level 0 is no piece: the sheets show kit.wild(). Two layouts (LAYOUT)
and the mirror: layout 0 has the rows running east-west and the patches in loose rows, layout 1 has them running north-south
and the patches in an L round the gin house.

The red earth is a patch under the work only. Spring: young green dashed rows; summer: green rows, bolls (1 px BOLL dots) on
every second row; autumn is the harvest, the signature at its strongest: every row white with bolls, two pickers, the bales
out; winter: no white at all, the rows of dry stalks: pale dashed rows along the long side in every climate (tan on the snow
soil of a snow or frost winter, pale straw on the dark red earth of a mild one), so cotton is not a plain brown block like
hemp. Spring's red earth is redder than the map's soil (the kit's cotton_soil). The bales (and the white under the shed) stand in autumn and
winter only.

python cotton.py            writes docs/design/map/pieces/cotton.png and cotton_variants.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "1 patch, hut", 2: "3 patches, drying shed, bales", 3: "5 patches, gin house"}
VARIANTS = 2
SEED = 16
GROUND = "farm"
# Where the map's road layer joins the yard's track (unmirrored, 10+ px inside the border).
GATES = [{"south": (-8, 33)}, {"south": (-1, 33)}]

SPACE, RUN = 16.0, 22.0           # a patch: 5 rows 3.2 px apart across SPACE, each RUN long (the long side)
ROWS = 5

# The layouts are fixed tables: a level adds to the level below and never moves anything.
#   patches: cx, cy, angle (degrees; 90 = rows run east-west, 0 = rows run north-south), from level;
#   yards: trodden ground (cx, cy, w, h, from level), laid half-transparent, it clears the map's wild land round the yard;
#   hut: the home building (thatch at every level), shed: level 2's landmark, gin: level 3's landmark (foot points);
#   bales: x, y, lift (px, for a bale on another), from level;  pickers: autumn, (x, y);  track: ends at the gate.
LAYOUT = [
    dict(  # layout 0: rows east-west in loose rows, the yard bottom left, the gin house in the middle with the shed beside it
        patches=[(8, -1, 92, 1), (-16, -19, 87, 2), (14, -22, 94, 2), (-29, 1, 88, 3), (30, 13, 91, 3)],
        yards=[(-26, 18, 24, 13, 1), (-16, 24, 36, 16, 2), (-8, 17, 56, 28, 3)],
        hut=(-31, 22), shed=(-17, 25), gin=(-3, 17),
        bales=[(-8, 27, 0, 2), (-4.6, 27, 0, 2), (-6.3, 27, 2.5, 3), (1.4, 27, 0, 3)],
        pickers=[(4, -1), (13, -3)],
        track=[(-26, 25), (-20, 31), (-8, 33)],
    ),
    dict(  # layout 1: rows north-south; an L of patches (an arm along the east, an arm along the back) round the gin house
        patches=[(-29, 7, 2, 1), (-29, -13, -2, 2), (-12, 22, 3, 2), (9, 22, -2, 3), (28, 8, 1, 3)],
        yards=[(-14, 6, 24, 13, 1), (-8, 4, 40, 18, 2), (-3, 2, 56, 30, 3)],
        hut=(-16, 8), shed=(8, 6), gin=(-4, -6),
        bales=[(10, 10, 0, 2), (13.4, 10, 0, 2), (11.7, 10, 2.5, 3), (16.6, 10, 0, 3)],
        pickers=[(-31, 6), (-27, 9)],
        track=[(-14, 12), (-7, 14), (-1.5, 20), (-1.5, 27), (-1, 33)],
    ),
]


def _pt(cx, cy, ang, u, v):
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return (cx + ca * u - sa * v, cy + (sa * u + ca * v) * kit.TILT)


STALK = {"snow": (176, 146, 106), "frost": (176, 146, 106), "mild": (220, 200, 156)}     # dry stalks, by winter
DASH, GAP = 2.4, 1.6               # a dry-stalk dash and the gap after it, along the row


def _dots(p, cx, cy, ang, u, n, step, shift, col, size):
    """n dots `step` apart along the row at across-offset u (shifted along by `shift`), laid by the kit's p.dots."""
    pts = []
    for k in range(n):
        v = -(n - 1) * step / 2 + k * step + shift
        pts.append(_pt(cx, cy, ang, u, v))
    p.dots(pts, col, size)


def _stalks(p, cx, cy, ang, col):
    """Winter: the dry stalks, five pale dashed rows along the long side (2.4 px dashes, 1.6 px gaps)."""
    dashes = []
    for i in range(ROWS):
        u = -SPACE / 2 + SPACE * (i + 0.5) / ROWS
        v = -RUN / 2 + 1.2 + (i % 2) * 1.8
        while v + DASH < RUN / 2 - 0.8:
            dashes.append((_pt(cx, cy, ang, u, v), _pt(cx, cy, ang, u, v + DASH)))
            v += DASH + GAP
    p.over(lambda pen: [pen.line(a, b, col, 1.0) for a, b in dashes], 1.0)


def _young_rows(p, cx, cy, ang, col):
    """Spring: the soil and five rows of young plants, 1.2 px dots 3.4 px apart, every other row shifted by half a step
    (so the dots do not form a grid)."""
    p.field(cx, cy, SPACE, RUN, ang, [kit.crop("cotton_soil", "spring")[0]], 1)
    for i in range(ROWS):
        u = -SPACE / 2 + SPACE * (i + 0.5) / ROWS
        n = int((RUN - 3.0) // 3.4)
        _dots(p, cx, cy, ang, u, n, 3.4, (i % 2) * 1.7 - 0.85, col, 1.3)


def patch(p, cx, cy, ang, season):
    """One patch of red earth with five rows along its long side. Bolls: every second row in summer, every row in autumn."""
    cot = kit.crop("cotton", season)[0]
    if season == "spring":
        _young_rows(p, cx, cy, ang, cot)
    elif season == "winter":                              # the red earth under dry, pale stalks (dashed rows along the long side)
        p.field(cx, cy, SPACE, RUN, ang, [kit.crop("cotton_soil", "winter")[0]], 1)
        _stalks(p, cx, cy, ang, STALK[kit.CLIMATE])
    else:
        p.rows(cx, cy, SPACE, RUN, ang, ROWS, col=cot, soil=kit.crop("cotton_soil", season)[0])
    if season in ("summer", "autumn"):
        step, rows = (2.0, range(ROWS)) if season == "autumn" else (2.8, (1, 3))
        for i in rows:
            u = -SPACE / 2 + SPACE * (i + 0.5) / ROWS
            _dots(p, cx, cy, ang, u, int((RUN - 3.0) // step) + 1, step, 0.0, kit.BOLL, 1.0)


def _bale_box(pen, x, b, w, h):
    """A bale seen from the front: a BOLL box with a shaded right quarter, a soft dark outline and two bands of rope."""
    pen.rect(x - w / 2, b - h, w, h, kit.BOLL, None)
    pen.rect(x + w / 2 - 0.7, b - h, 0.7, h, kit.shade(kit.BOLL, 0.9), None)
    pen.rect(x - w / 2, b - h, w, h, None, kit.INK, 0.35)
    for dx in (-w * 0.22, w * 0.22):
        pen.line((x + dx, b - h), (x + dx, b), kit.TIMBER_D, 0.3)


def drying_shed(p, x, y):
    """The level 2 landmark: a thatched roof on posts, 12 px wide, open sides, white under it (autumn and winter)."""
    w = 12.0
    p.cast(x, y, w, 3.0)
    white = p.season in ("autumn", "winter")
    snow = p.winter
    r1, r2 = (kit.SNOW, kit.SNOW_D) if snow else (kit.THATCH, kit.THATCH_D)

    def fn(pen):
        x0 = x - w / 2
        pen.rect(x0 + 0.6, y - 5.4, w - 1.2, 5.2, kit.DOOR, None)                        # the dark open space under the roof
        if white:                                                                         # the heap of lint
            heap = [(x - 4.6, y - 0.2), (x - 3.4, y - 2.6), (x - 1.2, y - 3.8), (x + 1.6, y - 3.2), (x + 3.8, y - 2.0), (x + 4.8, y - 0.2)]
            pen.poly(heap, kit.BOLL, None)
            pen.poly([(x + 1.6, y - 3.2), (x + 3.8, y - 2.0), (x + 4.8, y - 0.2), (x + 1.8, y - 0.2)], kit.SNOW_D if snow else (222, 220, 212), None)
        pen.rect(x0 + 0.1, y - 5.6, 1.0, 5.6, kit.TIMBER, None)                          # the posts
        pen.rect(x0 + w - 1.1, y - 5.6, 1.0, 5.6, kit.TIMBER_D, None)
        rf = [(x0 - 1.0, y - 5.0), (x0 + w + 1.0, y - 5.0), (x0 + w - 0.8, y - 9.0), (x0 + 0.8, y - 9.0)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.74, y - 9.0), (x0 + w * 0.78, y - 5.0)], r2, None)
        if snow:                                                                          # the eave keeps the thatch colour
            pen.poly([rf[0], rf[1], (rf[1][0] - 0.3, rf[1][1] - 1.1), (rf[0][0] + 0.3, rf[0][1] - 1.1)], kit.THATCH, None)
        pen.poly(rf, None, kit.INK, 0.5)
    return p.stand(y, fn, x=x)


def gin_house(p, x, y):
    """The level 3 landmark: a two-storey plastered house (PLASTER[1], 9 wide, 6.4 of wall) with a tile roof, a hatch on
    the upper floor and a hoist beam on its right (with a bale on the rope in autumn). The house is the kit's; the floor
    line, the hatch and the beam are parts of it (on=)."""
    w, h, rh = 9.0, 6.4, 3.6
    hs = p.house(x, y, w, h, rh, wall=1, kind="ridge", roof="tile")
    x1, top = x + w / 2, y - h
    pick = p.season == "autumn"

    def fn(pen):
        pen.line((x - w / 2, y - 3.2), (x1, y - 3.2), kit.shade(kit.PLASTER[1], 0.8), 0.5)             # the floor between the storeys
        pen.rect(x - 2.6, y - 6.0, 1.8, 2.0, kit.DOOR, None)                                           # the loading hatch above the door
        pen.rect(x + 0.9, y - 5.6, 1.2, 1.4, kit.DOOR, None)                                           # a small window
        by = top - 0.2                                                                                  # the hoist beam under the eave
        pen.rect(x1 - 0.4, by, 6.2, 0.9, kit.TIMBER, None)
        pen.line((x1 + 3.6, by + 0.5), (x1 + 3.6, by + 0.5 + 3.4 if pick else by + 0.5 + 2.4), kit.INK, 0.4)    # the rope
        pen.line((x1 + 0.3, by + 0.9), (x1 + 2.8, by - 0.1), kit.TIMBER_D, 0.5)                          # a brace
        if pick:
            _bale_box(pen, x1 + 3.6, by + 0.9 + 4.6 + 2.0, 2.6, 2.0)
    p.stand(y, fn, on=hs)
    return hs


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheets show the wild land
        return kit.wild(season, GROUND, seed=SEED)
    p = kit.Piece(season, ground=GROUND, seed=SEED, mirror=mirror)
    L = LAYOUT[variant]
    au = season == "autumn"
    soil = p.pal["soil"]

    # ---- ground plane (the same order every time)
    for cx, cy, w, h, frm in L["yards"]:
        if level >= frm:
            p.blob(cx, cy, w, h, soil, alpha=0.3)
    if level >= 1:
        p.road(L["track"], 1.5, track=True)
    for cx, cy, ang, frm in L["patches"]:
        if level >= frm:
            patch(p, cx, cy, ang, season)

    # ---- standing things
    p.house(*L["hut"], 5.5, 3.5, 3.0, wall=0, kind="ridge", roof="thatch", smoke=True)
    if level >= 2:
        drying_shed(p, *L["shed"])
    if level >= 3:
        gin_house(p, *L["gin"])
    feet = [(x, y) for x, y, lift, frm in L["bales"] if level >= frm]
    if feet:
        p.hold(feet)                                  # the bales' ground, held in every season so the wild land never changes
    for x, y, lift, frm in L["bales"]:
        if level >= frm and season in ("autumn", "winter"):
            p.bale(x, y, lift=lift)
    # ---- season activity: two pickers on the first patches in autumn
    for x, y in L["pickers"]:
        p.claim([(x - 2.5, y - 3), (x + 2.5, y - 3), (x + 2.5, y + 10), (x - 2.5, y + 10)])     # held in every season
        if au:
            p.person(x, y, (112, 88, 70) if x < 10 else (70, 96, 150))
    return p.finish(label="cotton L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces", "cotton.png")
    kit.sheet(draw, LEVELS, "Cotton: levels 0-3 by season", out, NAMES, ground=GROUND, wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.splitext(out)[0] + "_variants.png"
    kit.variant_sheet(draw, LEVELS, "Cotton: layouts and mirror", vout, NAMES, ground=GROUND)
    print("wrote", os.path.normpath(vout))
