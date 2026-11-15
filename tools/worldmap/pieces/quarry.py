"""Quarry, levels 0-3 (see docs/design/map/pieces/GUIDE.md, sections 4 and 8). Ground: rock. Seed 11.

0 the map's wild rock (no piece) - 1 one pale ledge at the back (the cut face), 2 cut blocks, a hut, a track -
2 three ledges stepping back and up, a neat stack of 5 blocks, a second hut, a ramp and the treadwheel crane on the
lowest ledge - 3 four ledges, 8 blocks in two stacks, a long masons' lodge and the column yard (3 standing columns
and one lying). Two layouts (LAYOUT) and the mirror.

The pit is not drawn from above: it is a stepped rock face seen from the front, the family's own raised ground
(as the mine's outcrop is). Each ledge is a flat top (ground, lit PIT, snow where snow lies) behind a cut face
(standing: PIT, the right quarter PIT_D, bare in every season). Ledges are added in FRONT of the lower ones, so a
level never moves what the level below drew. No dark opening, no cone heap, no smoke, no water.

python quarry.py           writes docs/design/map/pieces/quarry.png and quarry_variants.png
python quarry.py DIR       the same, into DIR
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

GROUND = "rock"
SEED = 11
LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "cut face, blocks", 2: "treadwheel crane", 3: "column yard"}
VARIANTS = 2

FACE = 2.9           # the cut face of a ledge (px); with its visible top it is one step of the stair

# The layouts are fixed tables; a level adds to the level below and never moves anything.
#   ledges: x0, x1, foot y (the foot of the cut face), from the back (the level 1 ledge) to the front, one more
#       ledge per level from level 2 (ledge 1 at level 1, 1-3 at level 2, 1-4 at level 3);
#   step: the stair's y step (a ledge's face plus the visible depth of its top);
#   crane: x, foot y: on the top of the lowest ledge of level 2 (ledge 3);
#   ramp: the pale track up beside the stair (level 2 and up);
#   yards: trodden ground x, y, w, h, from level (what clears the ground; the footprint grows with it);
#   blocks: x, foot y, from level, exposed (snow on the top); a stack is a row of three with two on top;
#   huts: x, foot y, from level; lodge: x, foot y (level 3, 16 px wide);
#   columns: x, foot y (level 3); lying: x, foot y;  masons: x, foot y, from level (summer 2, spring and autumn 1).
LAYOUT = [
    dict(  # layout 0: the stair across the back-left, the yard and the blocks in front, the column yard at the east
        step=4.5,
        ledges=[(-26, -2, -27.0), (-30, 2, -22.5), (-34, 6, -18.0), (-42, 14, -13.5)],
        crane=(1.0, -21.6),
        ramp=[(22, -3), (19, -10), (13, -15), (8.5, -20.2)],
        yards=[(6, 5, 42, 17, 1), (-31, 7, 17, 9, 1),
               (-6, 9, 66, 20, 2), (33, 11, 20, 10, 2),
               (4, 15, 80, 28, 3), (-14, 19, 28, 11, 3)],
        blocks=[(10.0, 7, 1, False), (13.2, 7, 1, False),
                (16.4, 7, 2, False), (11.6, 5, 2, True), (14.8, 5, 2, True),
                (23.0, 10, 3, False), (26.2, 10, 3, False), (24.6, 8, 3, True)],
        huts=[(-32, 5, 1), (35, 12, 2)],
        lodge=(-13, 19),
        columns=[(12, 18), (19, 18), (26, 18)],
        lying=(31, 26),
        masons=[(2, 11, 1), (20, 14, 2)],
        track=[(2, 6), (1, 16), (-1, 26), (-3, 34)],
    ),
    dict(  # layout 1: the stair runs back to front down the west flank, the yard, the crane and the works to its east
        step=9.0,
        ledges=[(-28, -12, -18.0), (-34, -14, -9.0), (-42, -16, 0.0), (-42, -12, 9.0)],
        crane=(-19.5, -5.8),
        ramp=[(-2, 12), (-7, 5), (-12, -1), (-16.5, -5.0)],
        yards=[(8, 4, 40, 18, 1), (22, -12, 16, 9, 1),
               (6, 9, 62, 22, 2), (32, 3, 18, 10, 2),
               (4, 14, 78, 28, 3), (27, 19, 26, 11, 3)],
        blocks=[(5.0, 8, 1, False), (8.2, 8, 1, False),
                (11.4, 8, 2, False), (6.6, 6, 2, True), (9.8, 6, 2, True),
                (15.0, 15, 3, False), (18.2, 15, 3, False), (16.6, 13, 3, True)],
        huts=[(20, -13, 1), (34, 4, 2)],
        lodge=(28, 21),
        columns=[(-24, 22), (-17, 22), (-10, 22)],
        lying=(-4, 28),
        masons=[(2, 14, 1), (-6, 8, 2)],
        track=[(0, 8), (3, 17), (5, 26), (6, 34)],
    ),
]
GATES = [{"south": (-3, 34)}, {"south": (6, 34)}]       # where the map's road layer joins the track


def ledge(p, i, x0, x1, y, step):
    """One ledge: its top (ground, lit PIT or snow) behind its cut face (standing; bare in winter too)."""
    w = x1 - x0
    cx = (x0 + x1) / 2
    snow = p.winter
    p.patch([(x0 + 0.8, y - FACE), (x1 - 0.8, y - FACE), (x1 - 2.6, y - step), (x0 + 2.6, y - step)],
            kit.SNOW if snow else kit.PIT, kit.SNOW_D if snow else kit.PIT_D, 0.5)
    if snow:                                            # a lit left part of the snow, a shaded right quarter
        p.patch([(x1 - w * 0.25, y - FACE), (x1 - 0.8, y - FACE), (x1 - 2.6, y - step), (x1 - w * 0.25 - 1.0, y - step)],
                kit.SNOW_D, None)
    p.shadow(cx + p.m * 3, y + 1.3, w * 0.9, 2.4)       # the ledge's soft shadow on the ledge below, lower right

    def fn(pen):
        body = [(x0 + 0.8, y - FACE), (x1 - 0.8, y - FACE), (x1, y), (x0, y)]
        pen.poly(body, kit.PIT, None)
        xd = x1 - w * 0.25
        pen.poly([(xd, y - FACE), (x1 - 0.8, y - FACE), (x1, y), (xd - 0.4, y)], kit.PIT_D, None)
        for k in range(1, int(w // 10) + 1):             # cut seams: a few vertical joints of the saw cuts
            sx = x0 + k * w / (int(w // 10) + 1) + (i % 2) * 1.3
            if sx < xd - 1:
                pen.line((sx, y - FACE + 0.4), (sx - 0.3, y - 0.3), kit.PIT_D, 0.5)
        pen.poly(body, None, kit.INK, 0.5)
    p.stand(y, fn, x=cx)


def crane(p, x, y):
    """Level 2 landmark: the treadwheel crane, a timber A-frame 12 px tall with its big wheel at the foot, a boom
    with a rope and a stone on the hook."""
    p.cast(x, y, 8)
    winter = p.winter
    m = p.m

    def fn(pen):
        top = y - 12.0
        # boom and rope behind the frame; they point to the ramp's side (the neighbouring thing)
        bx, by = x + m * 6.4, y - 8.6
        pen.line((x, top + 0.8), (bx, by), kit.TIMBER_D, 0.9)
        pen.line((bx, by), (bx, y - 4.6), kit.INK, 0.4)
        pen.box(bx, y - 3.0, 2.2, 1.6, kit.MARBLE)
        # the A-frame: left leg lit, right leg shaded
        pen.poly([(x - 4.8, y), (x - 3.5, y), (x + 0.5, top + 0.6), (x - 0.5, top)], kit.TIMBER, kit.INK, 0.5)
        pen.poly([(x + 4.8, y), (x + 3.5, y), (x + 0.5, top + 0.6), (x + 0.1, top)], kit.TIMBER_D, kit.INK, 0.5)
        pen.line((x - 3.0, y - 3.4), (x + 3.0, y - 3.4), kit.TIMBER_D, 0.8)          # cross brace
        # the treadwheel at the foot: a ring of timber with spokes
        cy = y - 3.5
        pen.circle(x, cy, 3.5, kit.TIMBER_D, kit.INK, 0.5)
        pen.circle(x, cy, 2.4, kit.TIMBER, None)
        for dx, dy in ((-2.4, 0), (2.4, 0), (0, -2.4), (0, 2.4), (-1.7, -1.7), (1.7, 1.7), (1.7, -1.7), (-1.7, 1.7)):
            pen.line((x, cy), (x + dx, cy + dy), kit.TIMBER_D, 0.4)
        pen.circle(x, cy, 0.6, kit.INK, None)
        if winter:
            pen.line((x - 1.0, top - 0.4), (x + 1.2, top - 0.4), kit.SNOW, 0.9)
    return p.stand(y, fn, x=x)


def column(p, x, y):
    """One standing column, 9 px tall: a base, a pale shaft with a shaded right quarter, a capital."""
    p.cast(x, y, 4.4, 2.2)
    winter = p.winter

    def fn(pen):
        pen.rect(x - 1.5, y - 8.0, 3.0, 7.2, kit.MARBLE, None)
        pen.rect(x + 0.7, y - 8.0, 0.8, 7.2, kit.MARBLE_D, None)
        pen.rect(x - 1.5, y - 8.0, 3.0, 7.2, None, kit.INK, 0.4)
        pen.box(x, y, 4.4, 1.0, kit.MARBLE)                                           # base
        pen.box(x, y - 8.0, 4.4, 1.0, kit.MARBLE)                                     # capital
        if winter:
            pen.rect(x - 2.2, y - 9.5, 4.4, 0.9, kit.SNOW, None)
    return p.stand(y, fn, x=x)


def lying_column(p, x, y):
    """The fifth piece of the column yard: a shaft on the ground, 9 px long."""
    p.cast(x, y, 9, 2.4)
    winter = p.winter

    def fn(pen):
        pen.box(x, y, 9.0, 2.6, kit.MARBLE, side=0.26)
        pen.rect(x - 4.5, y - 2.6, 1.0, 2.6, kit.MARBLE_D, None)                      # the cut end
        pen.rect(x - 4.5, y - 2.6, 9.0, 2.6, None, kit.INK, 0.4)
        if winter:
            pen.rect(x - 4.5, y - 3.2, 9.0, 0.8, kit.SNOW, None)
    return p.stand(y, fn, x=x)


def block(p, x, y, exposed):
    """A cut block: a 3 x 2 px MARBLE box. The ones with a free top carry snow where snow lies."""
    p.cast(x, y, 3.0, 1.4)
    snow = p.winter and exposed

    def fn(pen):
        pen.box(x, y, 3.0, 2.0, kit.MARBLE)
        if snow:
            pen.rect(x - 1.5, y - 2.7, 3.0, 0.8, kit.SNOW, None)
    return p.stand(y, fn, x=x)


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheets show the map's wild rock
        return kit.wild(season, GROUND, seed=SEED)
    p = kit.Piece(season, ground=GROUND, seed=SEED, mirror=mirror)
    L = LAYOUT[variant]
    step = L["step"]
    nledge = {1: 1, 2: 3, 3: 4}[level]

    # ---- ground plane: the trodden yard (an overlay, the only thing that clears the ground), the ramp, the track
    yards = [yd for yd in L["yards"] if yd[4] <= level]
    p.over(lambda pen: [pen.ellipse(cx, cy, w, h, p.pal["soil"], None) for cx, cy, w, h, _ in yards], 0.4)
    p.road(L["track"], 1.5, track=True)
    if level >= 2:
        p.road(L["ramp"], 2.0, track=True)                # the pale ramp up beside the stair

    # ---- the stair: ledges back to front (tops are ground, faces stand)
    for i in range(nledge):
        x0, x1, y = L["ledges"][i]
        ledge(p, i, x0, x1, y, step)

    # ---- standing things
    for x, y, lo in L["huts"]:
        if level >= lo:
            p.house(x, y, 5.5, 3.5, 3.0, wall=4 if lo == 1 else 0, kind="ridge", roof="thatch")
    for x, y, lo, exposed in L["blocks"]:
        if level >= lo:
            block(p, x, y, exposed)
    if level >= 2:
        crane(p, *L["crane"])
    if level >= 3:
        lx, ly = L["lodge"]
        p.house(lx, ly, 16.0, 4.8, 3.8, wall=kit.STONE, kind="ridge", roof="thatch", door=False)
        for x, y in L["columns"]:
            column(p, x, y)
        lying_column(p, *L["lying"])

    # ---- season: masons at work (none in winter, one in spring and autumn, two in summer)
    if season != "winter":
        for x, y, lo in L["masons"]:
            if level >= lo and (season == "summer" or lo == 1):
                p.person(x, y, (112, 88, 70) if lo == 1 else (70, 96, 150))
    return p.finish(label="quarry L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    out = os.path.join(outdir, "quarry.png")
    kit.sheet(draw, LEVELS, "Quarry: levels 0-3 by season", out, NAMES, ground=GROUND, wild=True)
    print("wrote", os.path.normpath(out))
    out = os.path.join(outdir, "quarry_variants.png")
    kit.variant_sheet(draw, LEVELS, "Quarry: layout and mirror", out, NAMES, ground=GROUND)
    print("wrote", os.path.normpath(out))
