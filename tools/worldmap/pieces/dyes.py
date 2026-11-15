"""Dye works, levels 1-3 (see docs/design/map/pieces/GUIDE.md, sections 4, 6 and 8: "Dye works").

1 three round vats (blue, red, yellow) on a trodden yard, a thatched hut, a rinsing channel between two ponds, a cloth line
- 2 six vats in two rows (purple added), a second cloth line, the hut re-roofed in tile, the drying loft - 3 nine vats in a
3 x 3 grid (layout 1: a double row along the channel), a third cloth line, a second house, the dye house with its chimney.
Level 0 is no piece: the sheets show kit.wild(). Two layouts (LAYOUT) and the mirror.

The vats lie on the ground and keep their colour in every season (they are heated): in winter only their rims carry snow.
The cloth lines hang from spring to autumn and stand bare in winter; the loft is hung in every season; the dye house
chimney smokes in every season. The channel and its ponds freeze where water freezes (p.frozen).

python dyes.py            writes docs/design/map/pieces/dyes.png and dyes_variants.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "3 vats, hut, cloth line", 2: "6 vats, loft", 3: "9 vats, dye house"}
VARIANTS = 2
SEED = 12
# Where the map's road layer joins the yard's track (unmirrored, 10+ px inside the border).
GATES = [{"south": (-4, 33)}, {"south": (-16, 33)}]

B, R, Y, P = "blue", "red", "yellow", "purple"
VAT_W, VAT_H = 8.2, 5.4                               # the rim; the liquor is 1.3 px smaller all round

# The layouts are fixed tables: a level adds to the level below and never moves anything.
#   yards: trodden ground (cx, cy, w, h, from level), the footprint;  vats: x, y, colour, from level;
#   channel: the rinsing channel, a pond (9 x 6) at each end;  lines: the cloth lines (x, y, width, from level, cloth colours);
#   hut: the home building, its foot (a thatched hut, tile from level 2);  house2: from level 3;
#   front: how far in front of the vats the map's wild trees are kept out (px; a crown is 10 tall);
#   loft: level 2's landmark (foot);  dye: level 3's landmark (foot);  track: to the gate;  dyers: summer, by level.
LAYOUT = [
    dict(  # layout 0: the vats in a 3 x 3 block left of the middle, the channel down the east side, the hut at the back left
        yards=[(-8, 1, 34, 14, 1), (-8, 12, 40, 22, 2), (0, 13, 66, 38, 3)],
        vats=[(-20, 0, B, 1), (-8, 0, R, 1), (4, 0, Y, 1),
              (-20, 9, P, 2), (-8, 9, B, 2), (4, 9, R, 2),
              (-20, 18, Y, 3), (-8, 18, P, 3), (4, 18, B, 3)],
        channel=[(25, -24), (26, -13), (28, -1), (26, 10), (25, 17)],
        lines=[(-20, 30, 16, 1, (B, R, Y)), (4, 32, 16, 2, (P, B, R)), (23, 30, 12, 3, (Y, P, R))],
        hut=(-33, -10), house2=(-34, 12), loft=(15, -9), dye=(-1, -20),
        track=[(-33, -5), (-30, 6), (-14, 24), (-4, 33)],
        dyers=[(-14, 5), (-2, 14)], front=13,
    ),
    dict(  # layout 1: the channel along the back, the vats in one long double row below it, the dye house at the east end
        yards=[(-19, -6, 28, 9, 1), (-12, -4, 50, 24, 2), (-1, 6, 68, 40, 3)],
        vats=[(-30, -9, B, 1), (-19, -9, R, 1), (-8, -9, Y, 1),
              (-25, 0, P, 2), (-14, 0, B, 2), (-3, 0, R, 2),
              (3, -9, Y, 3), (14, -9, P, 3), (8, 0, B, 3)],
        channel=[(-35, -20), (-20, -22), (0, -21), (20, -22), (35, -19)],
        lines=[(-14, 13, 16, 1, (B, R, Y)), (8, 17, 16, 2, (P, B, R)), (-30, 27, 12, 3, (Y, P, R))],
        hut=(-32, 11), house2=(-7, 31), loft=(24, 25), dye=(29, 2),
        track=[(-31, 17), (-26, 24), (-18, 30), (-16, 33)],
        dyers=[(-14, 4), (2, -4)], front=9,
    ),
]


def _ellipse(cx, cy, w, h, n=14):
    return [(cx + math.cos(i * 2 * math.pi / n) * w / 2, cy + math.sin(i * 2 * math.pi / n) * h / 2) for i in range(n)]


def vat(p, x, y, name):
    """A round vat lying on the ground: a stone rim and the liquor. The liquor keeps its colour in every season; only
    the rim takes snow, and only where snow lies."""
    rim = kit.SNOW if p.winter else kit.STONE_D
    p.blob(x, y, VAT_W, VAT_H, rim, edge=kit.shade(rim, 0.82) if p.winter else None)
    p.blob(x - 0.2, y + 0.1, VAT_W - 2.6, VAT_H - 2.0, kit.DYE[name])


def cloth_line(p, x, y, w, cols):
    """A cloth line: two posts and a line, 7 px tall, three cloths (2.5 x 4 px) in the vats' colours. Bare in winter."""
    cloths = p.season != "winter"
    xs = [x - w / 2 + w * (k + 0.5) / len(cols) for k in range(len(cols))]
    p.cast(x, y, w * 0.5, 2.0)

    def fn(pen):
        for px in (x - w / 2, x + w / 2):
            pen.rect(px - 0.5, y - 7.0, 1.0, 7.0, kit.TIMBER, None)
        pen.line((x - w / 2, y - 6.4), (x + w / 2, y - 6.4), kit.TIMBER_D, 0.7)
        if cloths:
            for cx, name in zip(xs, cols):
                c = kit.DYE[name]
                pen.rect(cx - 1.25, y - 6.2, 2.5, 4.0, c, None)
                pen.rect(cx + 0.3, y - 6.2, 0.95, 4.0, kit.shade(c, 0.84), None)
        if p.winter:                                   # a snow line on the rope
            pen.line((x - w / 2, y - 6.9), (x + w / 2, y - 6.9), kit.SNOW, 0.5)
    return p.stand(y, fn, x=x)


def loft(p, x, y):
    """The level 2 landmark: a tall open timber frame, 10 px wide and 11 tall, hung with long cloths in the four colours.
    The cloths hang in every season."""
    p.cast(x, y, 10, 3)

    def fn(pen):
        pen.rect(x - 5.0, y - 11.0, 1.2, 11.0, kit.TIMBER, None)                 # the posts
        pen.rect(x + 3.8, y - 11.0, 1.2, 11.0, kit.TIMBER_D, None)
        for i, name in enumerate((B, R, Y, P)):                                    # the long cloths, 1.5 px wide, 7 tall
            cx = x - 3.5 + i * 2.35
            c = kit.DYE[name]
            pen.rect(cx - 0.85, y - 9.6, 1.7, 7.4 - (i % 2) * 1.2, c, None)
            pen.rect(cx + 0.1, y - 9.6, 0.75, 7.4 - (i % 2) * 1.2, kit.shade(c, 0.84), None)
        pen.rect(x - 5.4, y - 11.8, 10.8, 1.6, kit.SNOW if p.winter else kit.TIMBER, None)    # the top beam
        pen.rect(x - 5.4, y - 11.8, 10.8, 1.6, None, kit.INK, 0.5)
        pen.rect(x - 5.0, y - 1.6, 10.0, 1.0, kit.TIMBER_D, None)                # the sill
        pen.line((x - 5.0, y - 11.0), (x - 5.0, y), kit.INK, 0.5)
        pen.line((x + 5.0, y - 11.0), (x + 5.0, y), kit.INK, 0.5)
    return p.stand(y, fn, x=x)


def dye_house(p, x, y):
    """The level 3 landmark: a wide stone building (13 px, `STONE` walls, tile roof) with a chimney that smokes in every
    season. The house is the kit's; the chimney is a part of it (`on=`) and the smoke sits on the chimney."""
    w, h, rh = 13.0, 5.6, 4.4
    hs = p.house(x, y, w, h, rh, wall=kit.STONE, kind="ridge", roof="tile")
    cx, top = x + 3.6, y - h - rh                                                  # the chimney stands on the roof's right half

    def fn(pen):
        pen.rect(cx - 1.0, top - 2.8, 2.0, 4.0, kit.STONE_GREY, None)
        pen.rect(cx + 0.2, top - 2.8, 0.8, 4.0, kit.STONE_GREY_D, None)
        pen.rect(cx - 1.0, top - 2.8, 2.0, 4.0, None, kit.INK, 0.5)
        pen.rect(cx - 1.4, top - 3.4, 2.8, 1.0, kit.SNOW if p.winter else kit.STONE_GREY_D, kit.INK, 0.5)
    p.stand(y, fn, on=hs)
    p.smoke(cx, top - 3.6, always=True, foot=y, on=hs)
    return hs


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheet shows the wild land
        return kit.wild(season, "grass", seed=SEED)
    p = kit.Piece(season, ground="grass", seed=SEED, mirror=mirror)
    L = LAYOUT[variant]
    su = season == "summer"
    soil = p.pal["soil"]

    # ---- ground plane (the same order every time)
    for cx, cy, w, h, frm in L["yards"]:
        if level >= frm:
            p.blob(cx, cy, w, h, soil, alpha=0.32)
    if level >= 1:
        p.road(L["track"], 1.6, track=True)
        ch = L["channel"]                              # the rinsing channel: plain water between two ponds, inside the hex
        p.water(ch, 1.0)
        for x, y in (ch[0], ch[-1]):
            p.pond(_ellipse(x, y, 8, 5.2))
    here = [v for v in L["vats"] if level >= v[3]]
    for x, y, name, frm in here:
        vat(p, x, y, name)
    # the vats are held ground: the map's wild trees keep their crowns off them (a tree's foot in front would hide a vat)
    p.claim([(min(v[0] for v in here) - 5, min(v[1] for v in here) - 4), (max(v[0] for v in here) + 5, min(v[1] for v in here) - 4),
             (max(v[0] for v in here) + 5, max(v[1] for v in here) + L["front"]), (min(v[0] for v in here) - 5, max(v[1] for v in here) + L["front"])])

    # ---- standing things
    if level >= 1:
        p.house(*L["hut"], 5.5, 3.5, 3.0, wall=0, kind="ridge", roof="thatch" if level == 1 else "tile", smoke=True)
    for x, y, w, frm, cols in L["lines"]:
        if level >= frm:
            cloth_line(p, x, y, w, cols)
    if level >= 2:
        loft(p, *L["loft"])
    if level >= 3:
        p.house(*L["house2"], 6.5, 4.2, 3.2, wall=1, kind="ridge", roof="tile")
        dye_house(p, *L["dye"])
    # ---- season activity: two dyers at the vats in summer
    if su:
        for k, (x, y) in enumerate(L["dyers"]):
            if level >= k + 1:
                p.person(x, y, kit.TRUNK)
    return p.finish(label="dyes L%d" % level)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces", "dyes.png")
    kit.sheet(draw, LEVELS, "Dye works: levels 0-3 by season", out, NAMES, ground="grass", wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.splitext(out)[0] + "_variants.png"
    kit.variant_sheet(draw, LEVELS, "Dye works: layouts and mirror", vout, NAMES, ground="grass")
    print("wrote", os.path.normpath(vout))
