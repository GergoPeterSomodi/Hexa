"""Hemp and the ropewalk, levels 0-3 (see docs/design/map/pieces/GUIDE.md, sections 4 and 8: "Hemp and the ropewalk").
Ground: farm. Seed 13.

0 the map's wild land (no piece) - 1 two near-square blocks, one retting pond touching a block, a thatched hut, a track -
2 five blocks, two ponds, a row of four stooks (thin tripods), the scutching barn - 3 eight blocks, three ponds, six stooks,
a second house and the ropewalk: an open thatched shed 28 px long with a rope running 10 px out of its end to a post.
Two layouts (LAYOUT) and the mirror. The piece draws no wild land.

A hemp block is near-square (14 x 12), has two strips at most and is never gold or light green (guide section 4: the
crowding table, hemp against spring wheat). Spring: bare earth with dashed rows; summer: the darkest green on the map
with a darker band along each block's front edge; autumn: pale stubble, the stooks on the newest blocks, two pale
bundles steeping on every pond, smoke; winter: two snow tones with their edges and, in the snow and frost winters, stubble (four rows of two short dark
dashes; the mild winter keeps dark earth with its dashed rows), the ponds frozen where water freezes (p.frozen), no stooks.

python hemp.py            writes docs/design/map/pieces/hemp.png and hemp_variants.png
python hemp.py DIR        the same, into DIR
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

GROUND = "farm"
SEED = 13
LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "2 blocks, pond, hut", 2: "5 blocks, stooks, barn", 3: "8 blocks, ropewalk"}
VARIANTS = 2
# Where the map's road layer joins the yard's track (unmirrored, 10+ px inside the border).
GATES = [{"south": (18, 31)}, {"south": (-4, 33)}]

BW, BH = 14.0, 12.0          # a block before the tilt: near-square
POND_W, POND_H = 9.0, 6.0    # a retting pond (kit.RET)
WALK_W, WALK_WALL, WALK_ROOF = 28.0, 4.0, 3.0   # the ropewalk
ROPE_OUT = 10.0              # the rope runs this far out of the shed's end to its post

# The layouts are fixed tables; a level adds to the level below and never moves anything.
#   blocks: cx, cy, angle, from level (14 x 12, two strips);  ponds: cx, cy, from level;
#   yards: trodden ground x, y, w, h, from level (it clears the map's wild land round the buildings);
#   hut: the home building (a thatched hut, always); barn: level 2's landmark (foot); house2: level 3 (foot);
#   walk: level 3's landmark, the ropewalk's middle and foot y (it lies level in both layouts; the rope runs east);
#   stooks: x, foot y, from level (levels 2 and 3 stand on the newest blocks); track: ends at the gate;
#   workers: x, foot y, from level (summer only).
LAYOUT = [
    dict(  # layout 0: the ropewalk across the front left, the buildings in the middle, three groups of blocks round them
        blocks=[(-11.5, -10, -6, 1), (12.5, -12, 5, 1),
                (-31, -14, 4, 2), (-29, 7, -5, 2), (30, 3, 3, 2),
                (5, -29, 0, 3), (25, -20, -3, 3), (26, 17, 4, 3)],
        ponds=[(1, -9, 1), (-30, -4, 2), (35, 10, 3)],
        yards=[(6, 5, 26, 14, 1), (14, 11, 30, 18, 2), (-6, 26, 40, 18, 3)],
        hut=(5, 6), barn=(-6, 10), house2=(17, 8), walk=(-14, 28),
        stooks=[(24.5, 5, 2), (28.1, 5, 2), (31.7, 5, 2), (35.3, 5, 2), (22.5, 19.5, 3), (26.5, 19.5, 3)],
        track=[(5, 6), (9, 17), (14, 25), (18, 31)],
        workers=[(-2, -3, 1), (23, 10, 2)],
    ),
    dict(  # layout 1: the ropewalk across the back, two groups of blocks either side of the pond in the middle, the yard in front
        blocks=[(-12, 2, -4, 1), (12, 0, 5, 1),
                (-29, -9, 5, 2), (29, -8, -3, 2), (30, 11, 4, 2),
                (-27, 11, -4, 3), (-14, -11, 0, 3), (15, 21, 3, 3)],
        ponds=[(0, -1, 1), (-28, 1, 2), (30, 1, 3)],
        yards=[(-8, 23, 26, 14, 1), (-12, 25, 38, 18, 2), (4, -22, 46, 18, 3)],
        hut=(-8, 22), barn=(-22, 26), house2=(4, 28), walk=(4, -24),
        stooks=[(24.5, 13, 2), (28.1, 13, 2), (31.7, 13, 2), (35.3, 13, 2), (11.5, 23.5, 3), (16.5, 23.5, 3)],
        track=[(-8, 22), (-7, 28), (-4, 33)],
        workers=[(-4, 8, 1), (20, 8, 2)],
    ),
]


def _ellipse(cx, cy, w, h, n=12):
    return [(cx + math.cos(i * 2 * math.pi / n) * w / 2, cy + math.sin(i * 2 * math.pi / n) * h / 2) for i in range(n)]


def block_corners(cx, cy, angle):
    """The four corners of a block on the ground (the tilt squashes y to 85%), as p.field draws it."""
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    return [(cx + ca * u - sa * v, cy + (sa * u + ca * v) * kit.TILT) for u, v in
            ((-BW / 2, -BH / 2), (BW / 2, -BH / 2), (BW / 2, BH / 2), (-BW / 2, BH / 2))]


STUBBLE = {"snow": (92, 78, 66), "frost": (104, 88, 70)}   # dark cut stalks: much darker than either snow tone


def stubble(p, cx, cy, angle):
    """Winter stubble under snow or frost: four rows across the block, each a run of two short dark dashes (2.4 px
    long, 1.1 px thick), so the near-square block shows a pattern of marks and not an empty outline at 50%."""
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))

    def P(u, v):
        return (cx + ca * u - sa * v, cy + (sa * u + ca * v) * kit.TILT)
    col = STUBBLE[p.climate]
    for i in range(4):
        u = -BW / 2 + BW * (i + 0.5) / 4
        for v0 in (-3.9, 1.5):
            p.gp.line(P(u, v0), P(u, v0 + 2.4), col, 1.1)


def hemp_block(p, cx, cy, angle, i):
    """One near-square block of two strips. Spring: bare earth with dashed young rows; summer: the darkest green with a
    darker band along the front edge (the crop stands tall); autumn: stubble; winter: two snow tones, earth-coloured
    dashed rows. The rows run across the strips, so a block reads as a square, never as a long strip."""
    cols = kit.crop("hemp", p.season)
    cols = cols[i % 2:] + cols[:i % 2]
    pts = p.field(cx, cy, BW, BH, angle, cols, 2, furrows=False)
    if p.season == "winter" and p.climate != "mild":
        stubble(p, cx, cy, angle)
    elif p.season != "summer":
        p.rows(cx, cy, BW, BH, angle, 4, col=kit.crop("hemp_row", p.season)[0], lw=0.9, soil=False, dashed=True)
    else:
        a, b = pts[3], pts[2]                                      # the front edge: a darker band 1.2 px deep
        p.patch([a, b, (b[0], b[1] - 1.3), (a[0], a[1] - 1.3)], kit.shade(cols[0], 0.74))


def stook(p, x, y):
    """A stook: a thin tripod of three lines, 2.4 wide and 4.5 tall, bound near the top. Never a round stack."""
    p.cast(x, y, 2.4, 1.1)
    col = kit.TIMBER_D

    def fn(pen):
        top = (x, y - 4.5)
        for fx in (x - 1.2, x + 0.1, x + 1.2):
            pen.line(top, (fx, y), col, 0.9)
        pen.line((x - 0.7, y - 2.7), (x + 0.7, y - 2.7), kit.TIMBER, 0.8)
    return p.stand(y, fn, x=x)


def ropewalk(p, x, y):
    """The level 3 landmark: an open thatched shed 28 px long, wall 4, roof 3, on posts (you see the dark inside and the
    rope running down its length). It always lies level, in both layouts. Returns the shed's handle; the rope and its
    post are a second thing (x= its own axis), the rope drawn toward the shed with p.m so the mirror keeps it joined."""
    x0, x1 = x - WALK_W / 2, x + WALK_W / 2
    p.cast(x, y, WALK_W, 3.0)
    winter = p.winter
    roof1, roof2 = (kit.SNOW, kit.SNOW_D) if winter else (kit.THATCH, kit.THATCH_D)

    def fn(pen):
        top = y - WALK_WALL
        pen.rect(x0, top, WALK_W, WALK_WALL, kit.DOOR, None)                                     # the open side: dark inside
        pen.rect(x0, y - 1.0, WALK_W, 1.0, kit.TIMBER_D, None)                                    # the sill
        pen.line((x0 + 0.5, y - 1.9), (x1 - 0.5, y - 1.9), kit.ROAD, 0.5)                         # the rope, seen inside
        for k in range(8):                                                                        # posts every 4 px
            px = x0 + 0.5 + k * (WALK_W - 1.0) / 7
            pen.rect(px - 0.5, top, 1.0, WALK_WALL, kit.TIMBER_D if k == 7 else kit.TIMBER, None)
        rf = [(x0 - 1.2, top + 0.4), (x1 + 1.2, top + 0.4), (x1 + 0.4, top - WALK_ROOF), (x0 - 0.4, top - WALK_ROOF)]
        pen.poly(rf, roof1, None)
        pen.poly([rf[1], rf[2], (x0 + WALK_W * 0.8, top - WALK_ROOF), (x0 + WALK_W * 0.8 + 1.0, top + 0.4)], roof2, None)
        if winter:                                                                                # a 1 px eave of thatch under the snow
            pen.poly([rf[0], rf[1], (rf[1][0] - 0.3, rf[1][1] - 1.0), (rf[0][0] + 0.3, rf[0][1] - 1.0)], kit.THATCH, None)
        pen.poly(rf, None, kit.INK, 0.5)
        pen.line((x0, y), (x1, y), kit.INK, 0.5)
    shed = p.stand(y, fn, x=x)
    px = x1 + ROPE_OUT
    d = x1 - px                                                                                  # towards the shed, unmirrored

    def rope(pen):
        pen.line((px, y - 1.9), (px + p.m * d, y - 1.9), kit.ROAD_EDGE, 0.7)                      # the rope runs back to the shed
        pen.rect(px - 0.6, y - 3.8, 1.2, 3.8, kit.TIMBER, None)                                  # the post
        pen.rect(px - 1.4, y - 3.8, 2.8, 0.7, kit.TIMBER_D, None)
        if winter:
            pen.rect(px - 1.4, y - 4.4, 2.8, 0.6, kit.SNOW, None)
    p.stand(y, rope, x=px)
    return shed


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheet shows the wild land
        return kit.wild(season, GROUND, seed=SEED)
    p = kit.Piece(season, ground=GROUND, seed=SEED, mirror=mirror)
    L = LAYOUT[variant]
    su, au = season == "summer", season == "autumn"

    # ---- ground plane: the trodden yards (overlays: they clear the wild land), the blocks, the ponds, the track
    for cx, cy, w, h, frm in L["yards"]:
        if level >= frm:
            p.blob(cx, cy, w, h, p.pal["soil"], alpha=0.3)
    p.road(L["track"], 1.5, track=True)
    for i, (cx, cy, ang, frm) in enumerate(L["blocks"]):
        if level >= frm:
            hemp_block(p, cx, cy, ang, i)
    for cx, cy, frm in L["ponds"]:
        if level >= frm:
            p.pond(_ellipse(cx, cy, POND_W, POND_H), frozen=p.frozen, col=kit.RET, edge=kit.RET_D)
            if au:                                    # bundles steeping: two pale lines on the water
                for dx in (-1.9, 1.5):
                    p.patch([(cx + dx - 1.5, cy + 0.4 + dx * 0.25), (cx + dx + 1.5, cy - 0.1 + dx * 0.25),
                             (cx + dx + 1.5, cy + 0.7 + dx * 0.25), (cx + dx - 1.5, cy + 1.2 + dx * 0.25)], kit.crop("hemp", "autumn")[0])

    # ---- standing things
    p.house(*L["hut"], 5.5, 3.5, 3.0, wall=0, kind="ridge", roof="thatch", smoke=True)
    if level >= 2:                                    # the scutching barn
        p.house(*L["barn"], 11.0, 5.0, 4.2, wall=(214, 186, 140), kind="gable", roof="thatch", door=False)
    if level >= 3:
        p.house(*L["house2"], 6.5, 4.2, 3.2, wall=1, kind="ridge", roof="thatch")
        ropewalk(p, *L["walk"])
    if level >= 2:                                    # the claim round the stooks, drawn or not (the wild land never changes)
        p.hold([(x, y) for x, y, frm in L["stooks"] if level >= frm], side=2.5, back=4.0, front=3.0)
    if au or su:                                      # stooks stand in summer (the first half) and autumn (all)
        here = [(x, y) for x, y, frm in L["stooks"] if level >= frm]
        for x, y in here if au else here[:len(here) // 2]:
            stook(p, x, y)
    # ---- season activity: one or two workers in summer
    if su:
        for x, y, frm in L["workers"]:
            if level >= frm:
                p.person(x, y, (112, 88, 70) if frm == 1 else (70, 96, 150))
    return p.finish(label="hemp L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    out = os.path.join(outdir, "hemp.png")
    kit.sheet(draw, LEVELS, "Hemp and the ropewalk: levels 0-3 by season", out, NAMES, ground=GROUND, wild=True)
    print("wrote", os.path.normpath(out))
    out = os.path.join(outdir, "hemp_variants.png")
    kit.variant_sheet(draw, LEVELS, "Hemp and the ropewalk: layouts and mirror", out, NAMES, ground=GROUND)
    print("wrote", os.path.normpath(out))
