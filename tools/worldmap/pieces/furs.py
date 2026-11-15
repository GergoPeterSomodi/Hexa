"""Furs, levels 0-3 (see docs/design/map/pieces/GUIDE.md, sections 4 and 8: "Furs"). Ground: wood. Seed 15.

0 the map's wild wood (no piece) - 1 a small clearing at the front, two pelt frames, a fire ring, the trapper's tent
- 2 a wider clearing, five frames, the log cabin - 3 eight frames in two rows, a second cabin, a stack of fur bales and the
trading post: a long log house in a square stockade that is open to the front. Two layouts (LAYOUT) and the mirror.

The wood is left standing (the map's): the piece draws only a small clearing, the pelt frames in front of every building
and the buildings. Nothing of timber's (no stumps, log piles, mound, water, track of logs) and nothing of the castle's
(no tower, no banner, no stone, no ring): the stockade is three straight sides of stakes with corner posts, on flat ground.

Seasons: winter is the high season (every frame carries a pelt, the tent and every cabin smoke: three smokes at most);
autumn has a pelt on two frames in three and the tent's smoke; spring and summer a pelt on every second frame and one
trapper by the tent.

python furs.py            writes docs/design/map/pieces/furs.png and furs_variants.png
python furs.py DIR        the same, into DIR
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

GROUND = "wood"
SEED = 15
LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "tent, 2 frames", 2: "log cabin, 5 frames", 3: "trading post, 8 frames"}
VARIANTS = 2
# Where the map's road layer joins the clearing's track (unmirrored, 10+ px inside the border). Both layouts end there.
FRONT = 7.5          # how far in front of the front row of frames the map keeps its trees out (a crown is 10 tall)
GATES = {"south": (-4, 31)}

# Named tokens of this family (derived from the kit's, so no new colour in the palette).
FRAME = kit.mix(kit.TIMBER, kit.PLASTER[0], 0.42)        # a pelt frame: pale timber
FRAME_D = kit.shade(FRAME, 0.82)
HIDE = kit.PLASTER[4]                                    # the tent's hide
HIDE_D = kit.shade(HIDE, 0.84)

# The layouts are fixed tables: a level adds to the level below and never moves anything.
#   clearing: cx, cy, w, h, from level: all blobs of a level are laid as ONE half-transparent layer (soil at 0.5), so
#       overlaps do not darken; three or four blobs, never one ellipse;
#   tent (foot), fire (the ring), cabin (level 2), cabin2 (level 3), bales (level 3): x, foot y;
#   stockade: x centre, back y, front y, width (level 3); the post house stands inside it (house: x, foot y, 13 wide);
#   frames: x, y, from level; they all stand in front of the buildings;
#   trapper: x, foot y (spring and summer);  track: from the clearing to the gate (level 2 and up, a 1 px track).
LAYOUT = [
    dict(  # layout 0: the clearing across the front, the tent in the middle, the stockade at the back right, frames in rows
        clearing=[(-6, 16, 30, 15, 1), (8, 19, 22, 11, 1),
                  (2, 19, 48, 12, 2), (-26, 13, 20, 12, 2),
                  (20, 12, 20, 9, 3)],
        tent=(-6, 9), fire=(2, 12.5), cabin=(-27, 11), cabin2=(17, 11), bales=(31, 14),
        stockade=(21, -19, -7, 28), house=(21, -10),
        frames=[(-20, 24, 1), (-10, 24, 1), (0, 24, 2), (10, 24, 2), (20, 24, 2),
                (-15, 18, 3), (-5, 18, 3), (5, 18, 3)],
        trapper=(-12, 13),
        track=[(0, 26), (-2, 29), GATES["south"]],
    ),
    dict(  # layout 1: the clearing on the east side, the stockade at its back, the frames in an L round the cabins
        clearing=[(25, 14, 28, 15, 1), (14, 20, 22, 11, 1),
                  (26, 21, 40, 13, 2), (33, 11, 20, 14, 2), (13, 12, 18, 12, 2),
                  (4, 4, 12, 26, 3)],
        tent=(20, 8), fire=(27, 11), cabin=(34, 8), cabin2=(29, 18), bales=(11, 15),
        stockade=(22, -21, -8, 28), house=(22, -12),
        frames=[(2, 24, 1), (11, 24, 1), (20, 24, 2), (29, 24, 2), (2, 16, 2),
                (2, 8, 3), (2, 0, 3), (2, -8, 3)],
        trapper=(8, 10),
        track=[(22, 27), (8, 30), GATES["south"]],
    ),
]


def pelt_frame(p, x, y, full):
    """A drying frame: a pale timber square, 4 wide and 4.5 tall, with a diamond pelt laced in it (or empty). Winter
    snow lies on the top rail."""
    p.cast(x, y, 3.6, 1.6)

    def fn(pen):
        x0, top = x - 2.0, y - 4.5
        pen.rect(x0, top, 4.0, 0.8, FRAME, None)                                       # the top rail
        pen.rect(x0, y - 0.8, 4.0, 0.8, FRAME_D, None)                                 # the foot rail
        pen.rect(x0, top, 0.8, 4.5, FRAME, None)                                       # the posts
        pen.rect(x0 + 3.2, top, 0.8, 4.5, FRAME_D, None)
        if full:
            c = (x, y - 2.5)
            pen.poly([(c[0] - 1.6, c[1]), (c[0], c[1] - 2.0), (c[0], c[1] + 2.0)], kit.PELT, None)
            pen.poly([(c[0] + 1.6, c[1]), (c[0], c[1] - 2.0), (c[0], c[1] + 2.0)], kit.PELT_D, None)
        pen.rect(x0, top, 4.0, 4.5, None, kit.INK, 0.5)
        if p.winter:
            pen.rect(x0, top - 0.5, 4.0, 0.6, kit.SNOW, None)
    return p.stand(y, fn, x=x)


def tent(p, x, y):
    """The level 1 landmark: a pale hide cone, 6 wide and 7 tall, its poles crossing above the top. It smokes in autumn
    and winter (the fire inside)."""
    p.cast(x, y, 6)

    def fn(pen):
        pen.poly([(x - 3.0, y), (x + 3.0, y), (x, y - 7.0)], HIDE, None)
        pen.poly([(x, y - 7.0), (x + 3.0, y), (x + 1.0, y)], HIDE_D, None)
        pen.poly([(x - 0.4, y), (x + 1.2, y), (x + 0.4, y - 2.8)], kit.DOOR, None)            # the flap
        if p.winter:
            pen.poly([(x - 1.5, y - 4.3), (x, y - 7.0), (x + 1.5, y - 4.3), (x + 0.4, y - 4.9), (x - 0.5, y - 4.1)], kit.SNOW, None)
        pen.poly([(x - 3.0, y), (x + 3.0, y), (x, y - 7.0)], None, kit.INK, 0.5)
        pen.line((x - 1.3, y - 8.6), (x + 0.5, y - 6.2), kit.TIMBER_D, 0.8)                   # the poles cross
        pen.line((x + 1.3, y - 8.6), (x - 0.5, y - 6.2), kit.TIMBER_D, 0.8)
    h = p.stand(y, fn, x=x)
    p.smoke(x, y - 8.8, foot=y, on=h)                                                           # autumn and winter
    return h


def log_house(p, x, y, w, smoke=False):
    """A log house: `TIMBER` walls with two log lines, a dark plank roof (`TIMBER_D`); the cabin is 8 wide, the post's
    house 13. Wall 4.6, roof 3.6 (8 px in all)."""
    h, rh = 4.6, 3.6
    p.cast(x, y, w)

    def fn(pen):
        x0, top = x - w / 2, y - h
        pen.rect(x0, top, w, h, kit.TIMBER, None)
        pen.rect(x0 + w * 0.78, top, w * 0.22, h, kit.TIMBER_D, None)
        for fy in (1.5, 3.0):                                                                  # the log lines
            pen.line((x0, top + fy), (x0 + w, top + fy), kit.TRUNK, 0.5)
        pen.rect(x0 + w * 0.3, y - 2.4, 1.5, 2.4, kit.DOOR, None)
        r1, r2 = (kit.SNOW, kit.SNOW_D) if p.winter else (kit.TIMBER_D, kit.shade(kit.TIMBER_D, 0.8))
        rf = [(x0 - 1.0, top + 0.3), (x0 + w + 1.0, top + 0.3), (x0 + w - 0.6, top - rh), (x0 + 0.6, top - rh)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.72, top - rh), (x0 + w * 0.78, top + 0.3)], r2, None)
        if p.winter:                                                                           # the eave keeps the plank colour
            pen.poly([rf[0], rf[1], (rf[1][0] - 0.3, rf[1][1] - 1.0), (rf[0][0] + 0.3, rf[0][1] - 1.0)], kit.TIMBER_D, None)
        else:
            pen.line((x0 + 0.3, top - rh * 0.5), (x0 + w - 0.3, top - rh * 0.5), kit.TRUNK, 0.5)   # a plank seam
        pen.poly(rf, None, kit.INK, 0.5)
        pen.rect(x0, top, w, h, None, kit.INK, 0.5)
    hs = p.stand(y, fn, x=x)
    if smoke and p.winter:                                                                     # only in winter
        p.smoke(x + w * 0.2, y - h - rh - 0.5, foot=y, on=hs)
    return hs


def bales(p, x, y):
    """The level 3 stack of fur bales: three `PELT` boxes, two below and one on top."""
    p.cast(x, y, 8)

    def fn(pen):
        for bx, by in ((x - 2.3, y), (x + 2.3, y), (x, y - 3.0)):
            pen.box(bx, by, 4.2, 3.0, kit.PELT, kit.INK)
            pen.line((bx - 2.1, by - 1.5), (bx + 2.1, by - 1.5), kit.PELT_D, 0.5)
        if p.winter:
            pen.rect(x - 2.1, y - 6.4, 4.2, 0.7, kit.SNOW, None)
    return p.stand(y, fn, x=x)


def _stake(pen, sx, y, w, h, snow):
    """One stake: pointed, lit on the left, shaded on the right."""
    pen.poly([(sx, y), (sx, y - h + 1.6), (sx + w / 2, y - h), (sx + w, y - h + 1.6), (sx + w, y)], kit.TIMBER, None)
    pen.poly([(sx + w / 2, y - h), (sx + w, y - h + 1.6), (sx + w, y), (sx + w * 0.55, y)], kit.TIMBER_D, None)
    pen.line((sx, y - h + 1.6), (sx, y), kit.TRUNK, 0.4)
    if snow:
        pen.poly([(sx + w * 0.2, y - h + 1.0), (sx + w / 2, y - h), (sx + w * 0.8, y - h + 1.0)], kit.SNOW, None)


def stockade(p, cx, yb, yf, w):
    """The level 3 stockade: a square of stakes, open to the front. The back side lies across the back, two sides run
    from the back corners towards the front, and four corner posts stand a little taller. No gate, no tower, no stone,
    no banner. Its inside is claimed (held ground). Every part turns round the same axis x = cx."""
    sh, pw = 4.8, 1.9
    x0, x1 = cx - w / 2, cx + w / 2
    n = int(w // pw)
    pw_b = w / n
    p.claim([(x0, yb - 1), (x1, yb - 1), (x1, yf + 4), (cx + 9, yf + 4), (cx + 9, yf + 9), (cx - 9, yf + 9), (cx - 9, yf + 4), (x0, yf + 4)])
    p.blob(cx, (yb + yf) / 2 + 0.5, w - 3, yf - yb - 1.5, p.pal["soil"], alpha=0.4)      # the trodden yard inside
    p.cast(cx, yb, w)
    p.cast(cx, yf, w, 3)

    def back(pen):
        for i in range(n):
            _stake(pen, x0 + i * pw_b, yb, pw_b, sh, p.winter)
    p.stand(yb, back, x=cx)

    def side(sx):
        def fn(pen):
            m = 9
            for k in range(m):
                _stake(pen, sx - 1.1 + (0.5 if k % 2 else -0.5), yb + 1.0 + (yf - yb - 1.0) * k / (m - 1), 2.2, sh, p.winter)
        return fn
    p.stand(yf, side(x0 + pw / 2), x=cx)
    p.stand(yf, side(x1 - pw / 2), x=cx)

    def post(px, py):
        def fn(pen):
            pen.rect(px - 1.1, py - 5.8, 2.2, 5.8, kit.TIMBER, None)
            pen.rect(px + 0.1, py - 5.8, 1.0, 5.8, kit.TIMBER_D, None)
            pen.poly([(px - 1.1, py - 5.8), (px, py - 7.0), (px + 1.1, py - 5.8)], kit.TIMBER_D, None)
            pen.rect(px - 1.1, py - 5.8, 2.2, 5.8, None, kit.INK, 0.5)
            if p.winter:
                pen.poly([(px - 0.9, py - 5.9), (px, py - 7.0), (px + 0.9, py - 5.9)], kit.SNOW, None)
        return fn
    for px, py in ((x0, yb), (x1, yb), (x0, yf), (x1, yf)):
        p.stand(py + 0.1, post(px, py), x=cx)


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheet shows the wild wood
        return kit.wild(season, GROUND, seed=SEED)
    p = kit.Piece(season, ground=GROUND, seed=SEED, mirror=mirror)
    L = LAYOUT[variant]
    sp, su, au, wi = (season == s for s in ("spring", "summer", "autumn", "winter"))

    # ---- ground plane: the small clearing (cleared ground, one half-transparent layer), the fire ring, a faint track
    blobs = [b for b in L["clearing"] if b[4] <= level]
    p.over(lambda pen: [pen.ellipse(cx, cy, w, h, p.pal["soil"], None) for cx, cy, w, h, _ in blobs], 0.5)
    fx, fy = L["fire"]
    p.blob(fx, fy, 4.8, 2.6, kit.TRUNK)
    p.blob(fx, fy, 2.6, 1.3, kit.DOOR)
    if level >= 2:
        p.road(L["track"], 1.0, track=True)

    # ---- standing things: the buildings, then the frames in front of all of them
    tent(p, *L["tent"])
    if level >= 2:
        log_house(p, *L["cabin"], 8.0, smoke=True)
    if level >= 3:
        log_house(p, *L["cabin2"], 8.0, smoke=True)
        bales(p, *L["bales"])
        stockade(p, *L["stockade"])
        log_house(p, *L["house"], 13.0)
    for k, (x, y, frm) in enumerate(L["frames"]):
        if level >= frm:
            full = wi or (au and k % 3 != 2) or (k % 2 == 0)
            pelt_frame(p, x, y, full)
    row = [f for f in L["frames"] if f[2] <= level and f[1] == max(g[1] for g in L["frames"] if g[2] <= level)]
    p.claim([(row[0][0] - 3.5, row[0][1] - 1), (row[-1][0] + 3.5, row[0][1] - 1),         # nothing wild stands in front of the front row
             (row[-1][0] + 3.5, row[0][1] + FRONT), (row[0][0] - 3.5, row[0][1] + FRONT)])
    # ---- season activity: one trapper by the tent in spring and summer
    if sp or su:
        p.person(*L["trapper"], kit.TRUNK)
    return p.finish(label="furs L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    out = os.path.join(outdir, "furs.png")
    kit.sheet(draw, LEVELS, "Furs: levels 0-3 by season", out, NAMES, ground=GROUND, wild=True)
    print("wrote", os.path.normpath(out))
    out = os.path.join(outdir, "furs_variants.png")
    kit.variant_sheet(draw, LEVELS, "Furs: layouts and mirror", out, NAMES, ground=GROUND)
    print("wrote", os.path.normpath(out))
