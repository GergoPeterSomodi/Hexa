"""Silk, levels 0-3 (see docs/design/map/pieces/GUIDE.md, sections 4 and 8: "Silk"). Ground: grass. Seed 14.

0 the map's wild land (no piece) - 1 two single-file rows of six mulberries on pale strips, a thatched hut -
2 four rows of seven, the silkworm shed (16 px, thatch, four dark window slots) - 3 six rows (the old ones lengthened),
a second shed, the caravanserai: a small court wall with a 6 px turquoise dome over its gate.
Two layouts (LAYOUT) and the mirror. Layout 0 has straight level rows and the caravanserai at the back; layout 1 tilts
the rows by about 20 degrees and puts the caravanserai at the front.

Every tree stands in a row, at least 9 px from the next row. The sheds stand at the rows' open end, in line with a lane:
they are front-view buildings and a row in front of them would hide them. In summer the leaves are picked: every second
tree of the two newest rows stands stripped (the kit's bare pollard, `p.tree(..., "mulberry", bare=True)`), and two pickers
with baskets work there. Autumn is gold and late green by turns (the kit's own mulberry); winter is bare pollards with a
dab of snow where snow lies. The sheds smoke in autumn and winter. The dome keeps its colour in every season: snow lies
only on its upper left.

python silk.py            writes docs/design/map/pieces/silk.png and silk_variants.png
python silk.py DIR        the same, into DIR
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

GROUND = "grass"
SEED = 14
LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "2 rows, hut", 2: "4 rows, silkworm shed", 3: "6 rows, caravanserai"}
VARIANTS = 2

STEP = 5.0                         # trees stand 5 px apart along a row
RUN = {1: 6, 2: 7}                 # trees per row from level 1 and 2; the rest of a row from level 3

# The layouts are fixed tables; a level adds to the level below and never moves anything.
#   rows: (x of the first tree, foot y of the first tree, angle in degrees, row from level, trees in all). A row has
#       RUN[1] = 6 trees at once, the 7th from level 2 and the rest from level 3. Rows 0-1 are the level 1 rows, 2-3 are
#       added at level 2 and 4-5 at level 3 ("the two newest rows" of a level are those);
#   hut: the home building, its foot (a thatched hut at every level);
#   sheds: (x, foot y, from level) the 16 px silkworm sheds; caravan: (x, foot y) the level 3 landmark, 14 px wide;
#   yards: trodden ground (cx, cy, w, h, from level) round the buildings;
#   pickers: two (dx, dy) from the stripped trees of the newest rows, summer only;  track: hut to gate.
LAYOUT = [
    dict(  # layout 0: level rows, the yard column down the west side, the caravanserai at the back
        rows=[(-12, -5.5, 0, 1, 9), (-12, 5.5, 0, 1, 9),
              (-12, -16.5, 0, 2, 8), (-12, 16.5, 0, 2, 8),
              (-9, -27.5, 0, 3, 7), (-9, 27.5, 0, 3, 7)],
        hut=(-27, 12),
        sheds=[(-27, 0, 2), (-24, 24, 3)],
        caravan=(-26, -15),
        yards=[(-26, 9, 22, 13, 1), (-26, 2, 30, 14, 2), (-24, 20, 30, 12, 3), (-26, -12, 24, 12, 3)],
        pickers=[(0.0, 0.0), (0.0, 0.0)],
        track=[(-27, 15), (-26, 22), (-18, 30), (-12, 33)],
    ),
    dict(  # layout 1: rows tilted 20 degrees, the yard on the east flank, the caravanserai at the front
        rows=[(-22, -12, 20, 1, 9), (-25, -1, 20, 1, 9),
              (-19, -23, 20, 2, 8), (-28, 10, 20, 2, 8),
              (-16, -34, 20, 3, 7), (-31, 21, 20, 3, 7)],
        hut=(26, -6),
        sheds=[(24, 7, 2), (28, 19, 3)],
        caravan=(11, 31),
        yards=[(26, -4, 22, 13, 1), (25, 5, 30, 14, 2), (28, 18, 30, 12, 3), (11, 28, 26, 12, 3)],
        pickers=[(0.0, 0.0), (0.0, 0.0)],
        track=[(30, -4), (38, 4), (38, 14), (33, 22), (26, 27)],
    ),
]
GATES = [{"south": (-12, 33)}, {"south": (26, 27)}]       # where the map's road layer joins the track


def row_trees(row):
    """The trees of a row as (x, foot y, from level), in order along the row."""
    x0, y0, ang, lv, n = row
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    out = []
    for k in range(n):
        frm = max(lv, 1 if k < RUN[1] else 2 if k < RUN[2] else 3)
        out.append((x0 + k * STEP * c, y0 + k * STEP * s * kit.TILT, frm))
    return out


def basket(p, x, y):
    """A picker's basket on the ground: 2 x 1.4 px of thatch with a dark rim."""
    def fn(pen):
        pen.rect(x - 1.0, y - 1.4, 2.0, 1.4, kit.THATCH, None)
        pen.rect(x - 1.0, y - 1.4, 2.0, 0.5, kit.THATCH_D, None)
    return p.stand(y, fn, x=x)


def shed(p, x, y, smoke=True):
    """The silkworm shed: a long low thatched shed, 16 px wide, wall 3.5, with four dark window slots. It smokes in autumn
    and winter (a heated rearing room); only the oldest shed does (smoke=): three smokes in a column beside the pale
    rows read as a row of exclamation marks (round 4 review)."""
    w, h, rh = 16.0, 3.5, 3.0
    hs = p.house(x, y, w, h, rh, wall=3, kind="ridge", roof="thatch", door=False, smoke=smoke)

    def fn(pen):
        for q in range(4):
            sx = x - w / 2 + w * (q + 0.5) / 4
            pen.rect(sx - 0.6, y - 3.0, 1.2, 1.5, kit.DOOR, None)
    p.stand(y, fn, on=hs)
    return hs


def caravanserai(p, x, y):
    """The level 3 landmark: a court wall (STONE, 14 wide, 5 tall) with an arched gate in a gate block, and over the gate a
    small turquoise dome 6 px wide. 13 px tall in all. The dome keeps its colour in every season; snow lies only on its
    upper left, on the lit side."""
    p.cast(x, y, 14, 3.0)
    snow = p.winter

    def fn(pen):
        wl, wt = x - 7.0, y - 5.0
        pen.rect(wl, wt - 1.6, 14.0, 1.6, kit.STONE_D, None)                         # the far wall, seen over the near one
        pen.rect(wl, wt, 14.0, 5.0, kit.STONE, None)                                  # the near wall
        pen.rect(x + 3.2, wt, 3.8, 5.0, kit.STONE_D, None)                            # its shaded right part
        pen.rect(wl, wt - 1.6, 14.0, 6.6, None, kit.INK, 0.5)
        for q in range(3):                                                            # the merlons of the far wall
            pen.rect(wl + 1.2 + q * 4.6, wt - 2.6, 2.0, 1.0, kit.STONE_D, kit.INK, 0.4)
        if snow:
            pen.rect(wl + 0.2, wt - 0.6, 14.0 * 0.5, 0.9, kit.SNOW, None)
        # the gate block, 6 px wide and 8 tall, over the wall, with the arch and the dome
        gl, gt = x - 3.0, y - 8.0
        pen.rect(gl, gt, 6.0, 8.0, kit.STONE, None)
        pen.rect(x + 1.2, gt, 1.8, 8.0, kit.STONE_D, None)
        pen.rect(gl, gt, 6.0, 8.0, None, kit.INK, 0.5)
        pen.rect(x - 1.3, y - 3.2, 2.6, 3.2, kit.DOOR, None)                          # the arched gate
        pen.ellipse(x, y - 3.2, 2.6, 2.4, kit.DOOR, None)
        # the dome: the kit's, 6 wide and 3.4 tall on the block (snow on the upper left only), a finial on top
        dy = gt
        pen.dome(x, dy, 6.0, 3.4, kit.DOME_TILE, kit.DOME_TILE_D, snow=snow)
        pen.line((x, dy - 3.4), (x, dy - 5.0), kit.INK, 0.5)
        pen.rect(gl - 0.2, dy, 6.4, 1.2, kit.STONE, kit.INK, 0.4)                     # the drum under the dome
    h = p.stand(y, fn, x=x)
    p.claim([(x - 11, y - 12), (x + 11, y - 12), (x + 11, y + 5), (x - 11, y + 5)])
    return h


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheets show the map's wild land
        return kit.wild(season, GROUND, seed=SEED)
    p = kit.Piece(season, ground=GROUND, seed=SEED, mirror=mirror)
    L = LAYOUT[variant]
    su = season == "summer"
    soil = kit.crop("mulberry_soil", season)[0]
    rows = [(r, row_trees(r)) for r in L["rows"]]

    # ---- ground plane: trodden yards, the pale strips under the rows, the track
    yards = [yd for yd in L["yards"] if yd[4] <= level]
    p.over(lambda pen: [pen.ellipse(cx, cy, w, h, p.pal["soil"], None) for cx, cy, w, h, _ in yards], 0.32)
    p.road(L["track"], 1.5, track=True)
    for ri, ((x0, y0, ang, lv, n), trees) in enumerate(rows):
        mine = [t for t in trees if t[2] <= level]
        if lv > level or not mine:
            continue
        xa, ya = mine[0][0], mine[0][1]
        xb, yb = mine[-1][0], mine[-1][1]
        ln = math.hypot(xb - xa, (yb - ya) / kit.TILT) + 6.0
        p.field((xa + xb) / 2, (ya + yb) / 2 + 0.5, ln, 3.0, ang, [soil], 1)

    # ---- standing things: the trees row by row (index shifts by row so the autumn colours do not line up)
    newest = [ri for ri, (r, _) in enumerate(rows) if r[3] == level]
    for ri, (r, trees) in enumerate(rows):
        for k, (x, y, frm) in enumerate(trees):
            if frm > level:
                continue
            if su and ri in newest and k % 2 == 1:
                p.tree(x, y, 1.0, "mulberry", k + ri, bare=True)       # stripped: the kit's bare pollard
            else:
                p.tree(x, y, 1.0, "mulberry", k + ri)
    p.house(*L["hut"], 5.5, 3.5, 3.0, wall=0, kind="ridge", roof="thatch", smoke=level < 2)
    oldest = min(frm for _, _, frm in L["sheds"])
    for x, y, frm in L["sheds"]:
        if level >= frm:
            shed(p, x, y, smoke=(frm == oldest))
    if level >= 3:
        caravanserai(p, *L["caravan"])

    # ---- season: two pickers with baskets by the stripped trees of the newest rows, in summer only
    if su:
        for q, ri in enumerate(newest[:2]):
            trees = [t for t in rows[ri][1] if t[2] <= level]
            x, y, _ = trees[min(len(trees) - 1, 3)]
            p.person(x + 2.6, y + 2.6, (112, 88, 70) if q == 0 else (70, 96, 150))
            basket(p, x + 4.8, y + 2.8)
    return p.finish(label="silk L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    out = os.path.join(outdir, "silk.png")
    kit.sheet(draw, LEVELS, "Silk: levels 0-3 by season", out, NAMES, ground=GROUND, wild=True)
    print("wrote", os.path.normpath(out))
    out = os.path.join(outdir, "silk_variants.png")
    kit.variant_sheet(draw, LEVELS, "Silk: layouts and mirror", out, NAMES, ground=GROUND)
    print("wrote", os.path.normpath(out))
