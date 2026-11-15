"""Vineyard and winery, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 the map's wild land - 1 two young blocks and a thatched hut - 2 four blocks of full rows, a tiled house, the press
house with two vats - 3 six blocks, two of them terraced, a track, the wine estate with a tower and cypresses.
Three layouts (LAYOUT[0], LAYOUT[1], LAYOUT[2]) with the same landmarks, counts and coverage; the map also mirrors them.
Layout 2 is a different kind of plan: the six blocks are sectors of one set of contour rows round the chateau.

python vineyard.py         writes docs/design/map/pieces/vineyard.png and vineyard_variants.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
VARIANTS = 3
NAMES = {0: "wild land (the map's)", 1: "young vines", 2: "press house", 3: "estate"}

# The layouts are fixed tables: a level adds to the level below and never moves anything. Blocks: cx, cy, w, h,
# angle, rows, from level, shelves (terraces). Layout 0: hut left of the middle, press house in the middle, estate at
# the back; layout 1: hut at the back right, press house on the east side, estate on the west flank, the terraced
# blocks at the front. Layout 2 (contour rows round the chateau) has its own keys: the centre of the rings, the
# rings (first radius, step, rows per sector, flattening), six sectors as angle pairs in degrees (0 east, 90 the front,
# 180 west) with a from level and the number of terrace walls, and the same hut, press, vats, estate, tower, cypress,
# track. The opening at the back (220 to 320 degrees) holds the press house; the hut stands in the front gap.
LAYOUT = [
    dict(
        hut=(-14, 8),                                 # the hut, later the tiled house: same foot at every level
        press=(3, -2),                                # the press house (level 2)
        vats=[(13.5, -0.5), (18.5, 1.8)],
        estate=(-4, -22),                             # one broad two-storey ochre house (level 3)
        tower=(3.6, -21.4),                           # its tower stands on the right-hand end, not above the ridge
        cypress=[(9.5, -21), (13.5, -23.5)],
        blocks=[
            (26, 14, 24, 17, -8, 6, 1, 1),
            (-21, 21, 18, 12, 6, 5, 1, 1),
            (27, -7, 22, 15, 18, 6, 2, 1),
            (-27, -8, 21, 15, -14, 5, 2, 1),
            (-22, -22, 14, 10, 0, 5, 3, 2),
            (22, -22, 14, 10, 0, 5, 3, 2),
        ],
        track=[(-12, 11), (-10, 20), (-6, 32), (-5, 38)],
    ),
    dict(
        hut=(12, -18),
        press=(14, -2),
        vats=[(24.5, -0.5), (29.5, 1.8)],
        estate=(-30, -9),
        tower=(-22.4, -8.4),
        cypress=[(-17, -8), (-13, -10.5)],
        blocks=[
            (-27, 14, 24, 17, 12, 6, 1, 1),
            (31, 17, 18, 12, -12, 5, 1, 1),
            (-3, -27, 22, 15, -6, 6, 2, 1),
            (26, -18, 21, 15, 10, 5, 2, 1),
            (-12, 26, 14, 10, 0, 5, 3, 2),
            (13, 26, 14, 10, 0, 5, 3, 2),
        ],
        track=[(11, 2), (8, 12), (3, 22), (-2, 32), (-5, 38)],
    ),
    dict(
        centre=(0, -4),
        rings=dict(r0=14.5, step=4.4, n=6, flat=0.78),
        sectors=[                                     # a0, a1, from level, terrace walls on the two outermost rows
            (107, 139, 1, 0),                         # front left, then round to the west
            (147, 179, 1, 0),
            (41, 73, 2, 0),                           # front right, then round to the east
            (1, 33, 2, 0),
            (187, 219, 3, 2),                         # the back sectors stand on terrace walls
            (-39, -7, 3, 2),
        ],
        hut=(2.5, 22),
        press=(-9, -25),
        vats=[(-1.5, -23.5), (3.5, -22)],
        estate=(-3.5, -1),
        tower=(4.1, -0.4),
        cypress=[(-10.5, -1.5), (9.5, -1.5)],
        track=[(-1, 2), (-2, 12), (-4, 20), (-5, 28), (-5, 38)],
    ),
]
GATES = {"south": (-5, 38)}                           # the track ends here in both layouts; the map's road layer carries it on


def corners(b):
    cx, cy, w, h, ang = b[:5]
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return [(cx + ca * u - sa * v, cy + (sa * u + ca * v) * kit.TILT) for u, v in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]


def press_house(p, x, y):
    """The level 2 landmark: a wide tiled building, 12 px wide, with a big dark door."""
    p.cast(x, y, 12)
    winter = p.winter
    w, h, rh = 12.0, 5.2, 4.6
    wall = kit.PLASTER[1]

    def fn(pen):
        x0, top = x - w / 2, y - h
        pen.rect(x0, top, w, h, wall, None)
        pen.rect(x0 + w * 0.78, top, w * 0.22, h, kit.shade(wall, 0.84), None)
        r1, r2 = (kit.ROOF, kit.ROOF_D) if not winter else (kit.SNOW, kit.SNOW_D)
        rf = [(x0 - 1, top + 0.3), (x0 + w + 1, top + 0.3), (x0 + w - 0.8, top - rh), (x0 + 0.8, top - rh)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.72, top - rh), (x0 + w * 0.78, top + 0.3)], r2, None)
        if winter:
            pen.line(rf[0], rf[1], kit.ROOF_D, 0.5)
        pen.poly(rf, None, kit.INK, 0.5)
        pen.rect(x - 2.6, y - 3.8, 4.4, 3.8, kit.DOOR, None)          # the big door of the pressing hall
        pen.rect(x - 2.6, y - 3.8, 4.4, 3.8, None, kit.INK, 0.5)
        pen.rect(x0 + 1.0, y - 3.4, 1.2, 1.2, kit.DOOR, None)
        pen.rect(x0, top, w, h, None, kit.INK, 0.5)
    return p.stand(y, fn, x=x)


def vat(p, x, y):
    """A round wooden vat: a barrel body with two hoops and a dark top; snow cap in winter."""
    p.cast(x, y, 5)
    winter = p.winter

    def fn(pen):
        pen.rect(x - 2.5, y - 4.0, 5.0, 4.0, kit.TIMBER, None)
        pen.rect(x + 0.9, y - 4.0, 1.6, 4.0, kit.TIMBER_D, None)
        pen.line((x - 2.5, y - 1.3), (x + 2.5, y - 1.3), kit.TIMBER_D, 0.5)
        pen.line((x - 2.5, y - 2.9), (x + 2.5, y - 2.9), kit.TIMBER_D, 0.5)
        pen.rect(x - 2.5, y - 4.0, 5.0, 4.0, None, kit.INK, 0.5)
        pen.ellipse(x, y - 4.0, 5.0, 2.0, kit.SNOW if winter else (120, 50, 62), kit.INK, 0.5)
    return p.stand(y, fn, x=x)


def basket(p, x, y):
    return p.stand(y, lambda pen: (pen.rect(x - 1.1, y - 1.5, 2.2, 1.5, kit.TIMBER, kit.INK, 0.5), pen.rect(x - 1.1, y - 1.5, 2.2, 0.5, (150, 60, 66), None)), x=x)


def ring_band(L, i):
    R = L["rings"]
    rx = R["r0"] + i * R["step"]
    return rx, rx * R["flat"]


def contour_ground(p, L, level, season):
    """Layout 2: the sectors of contour rows. Each sector's soil is a patch between two ring lines; the rows are arcs."""
    cx, cy = L["centre"]
    R = L["rings"]
    flat, n = R["flat"], R["n"]
    soil = kit.crop("vine_soil", season)[0]
    vine = kit.crop("vine", season)[0]
    r_in, r_out = R["r0"] - 2.0, R["r0"] + (n - 1) * R["step"] + 2.2
    p.blob(cx, cy, r_in * 1.6, r_in * flat * 1.6, p.pal["soil"], alpha=0.28)          # the faint trodden knoll
    for a0, a1, frm, shelves in L["sectors"]:
        if frm > level:
            continue
        span = int(abs(a1 - a0) // 3) + 2
        inner = kit.ring_points(cx, cy, r_in, r_in * flat, math.radians(a0), math.radians(a1), span)
        outer = kit.ring_points(cx, cy, r_out, r_out * flat, math.radians(a0), math.radians(a1), span)
        pts = inner + outer[::-1]
        if p.winter:
            p.patch(pts, kit.SNOW)
            for i in (0, 3):                          # a band in three shows earth between the rows
                ra, rb = R["r0"] + (i + 0.5) * R["step"] - 1.1, R["r0"] + (i + 0.5) * R["step"] + 1.1
                ba = kit.ring_points(cx, cy, ra, ra * flat, math.radians(a0), math.radians(a1), span)
                bb = kit.ring_points(cx, cy, rb, rb * flat, math.radians(a0), math.radians(a1), span)
                p.patch(ba + bb[::-1], p.pal["soil"])
        else:
            p.patch(pts, soil, kit.shade(soil, 0.8))
        young = level == 1 and frm == 1
        for i in range(n):
            rx, ry = ring_band(L, i)
            p.arc(cx, cy, rx, ry, min(a0, a1) + 1.5, max(a0, a1) - 1.5, col=vine, lw=1.5, dashed=young)
        for i in range(n - shelves, n):               # terrace walls under the outermost rows
            rx, ry = ring_band(L, i)
            rx, ry = rx + 2.0, ry + 2.0 * flat
            p.terrace(kit.ring_points(cx, cy, rx, ry, math.radians(min(a0, a1) + 1.5), math.radians(max(a0, a1) - 1.5), span), face=2)


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece: the sheets show the map's wild land
        return kit.wild(season, "grass", seed=2)
    p = kit.Piece(season, ground="grass", seed=2, mirror=mirror)
    L = LAYOUT[variant]
    if "rings" in L:
        return draw_contour(p, L, level, season)
    sp, su, au, wi = season == "spring", season == "summer", season == "autumn", season == "winter"
    soil = kit.crop("vine_soil", season)[0]
    vine = kit.crop("vine", season)[0]
    if wi:
        strips = [kit.SNOW, kit.mix(kit.SNOW, kit.SNOW_D, 0.7), kit.SNOW, p.pal["soil"]]     # one strip in four shows earth
    else:
        strips = [soil]
    blocks = [b for b in L["blocks"] if b[6] <= level]

    # ---- ground plane
    if level >= 3:
        p.road(L["track"], 1.6, track=True)
    for b in blocks:
        cx, cy, w, h, ang, n, frm, shelves = b
        young = level == 1 and frm == 1
        if shelves == 1:
            p.field(cx, cy, w, h, ang, strips, n if wi else 1, along=False)
            p.rows(cx, cy, w, h, ang, n, col=vine, soil=False, dashed=young, lw=1.5)
            continue
        sh = (h - 1.0) / shelves                      # terraced: each shelf has its own rows and a stone wall below
        for k in range(shelves):
            sy = cy - h / 2 + sh * (k + 0.5) + k * 1.0
            p.field(cx, sy, w, sh, ang, strips, n if wi else 1, along=False)
            p.rows(cx, sy, w, sh, ang, n, col=vine, soil=False, lw=1.5)
            ya = sy + sh / 2 * kit.TILT
            p.terrace([(cx - w / 2 - 0.5, ya + 0.4), (cx + w / 2 + 0.5, ya + 0.4)], face=2)

    # ---- standing things
    hut = L["hut"]
    if level >= 1:
        if level == 1:
            p.house(hut[0], hut[1], 5.5, 3.5, 3.0, wall=0, roof="thatch", smoke=True)
        else:                                         # the hut grows into a house but keeps its thatch: the tile roofs are the press and the estate
            p.house(hut[0], hut[1], 7.5, 4.8, 3.6, wall=0, roof="thatch", smoke=True)
    if level >= 2:
        press_house(p, *L["press"])
        for x, y in L["vats"]:
            vat(p, x, y)
    if level >= 3:
        p.house(L["estate"][0], L["estate"][1], 12.0, 6.5, 3.4, wall=kit.PLASTER[1], roof="tile")
        p.tower(L["tower"][0], L["tower"][1], 3.6, 8.6, col=kit.PLASTER[1], top="cone", roof=kit.ROOF)
        for i, (x, y) in enumerate(L["cypress"]):
            p.tree(x, y, 1.0, "poplar", i)

    # ---- season activity (never changes the layout)
    if blocks:
        new = [b for b in blocks if b[6] == level][-1]
        cx, cy, w, h = new[:4]
        if au:
            p.person(cx - w * 0.18, cy - 1, (110, 80, 60))
            p.person(cx + w * 0.08, cy + 2, (196, 72, 60))
            for q in (-1, 0, 1):
                basket(p, cx - 4 + q * 4.2, cy + h * 0.5 * kit.TILT + 3.2)
        elif su:
            p.person(cx + w * 0.1, cy, (70, 96, 150))
        elif sp and level >= 2:
            p.person(cx - w * 0.1, cy + 1, (110, 80, 60))
    return p.finish(label="vineyard L%d" % level)


def draw_contour(p, L, level, season):
    """Layout 2: the same landmarks, counts and seasons as layouts 0 and 1 on one set of contour rows."""
    sp, su, au = season == "spring", season == "summer", season == "autumn"
    cx, cy = L["centre"]
    R = L["rings"]
    sectors = [s for s in L["sectors"] if s[2] <= level]
    if level >= 3:
        p.road(L["track"], 1.6, track=True)
    contour_ground(p, L, level, season)
    hut = L["hut"]
    if level == 1:
        p.house(hut[0], hut[1], 5.5, 3.5, 3.0, wall=0, roof="thatch", smoke=True)
    else:
        p.house(hut[0], hut[1], 7.5, 4.8, 3.6, wall=0, roof="thatch", smoke=True)
    if level >= 2:
        press_house(p, *L["press"])
        for x, y in L["vats"]:
            vat(p, x, y)
    if level >= 3:
        p.house(L["estate"][0], L["estate"][1], 12.0, 6.5, 3.4, wall=kit.PLASTER[1], roof="tile")
        p.tower(L["tower"][0], L["tower"][1], 3.6, 8.6, col=kit.PLASTER[1], top="cone", roof=kit.ROOF)
        for i, (x, y) in enumerate(L["cypress"]):
            p.tree(x, y, 1.0, "poplar", i)

    def at(r, a):                                     # a point on the rings: radius of the first row's scale, angle in degrees
        return cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r * R["flat"]
    a0, a1 = sectors[-1][:2]
    am = (a0 + a1) / 2.0
    mid = R["r0"] + 2.5 * R["step"]
    if au:
        p.person(*at(mid, am - 8), (110, 80, 60))
        p.person(*at(mid + R["step"], am + 6), (196, 72, 60))
        for q in (-1, 0, 1):
            bx, by = at(R["r0"] + 5 * R["step"] + 1.6, am + q * 6.5)
            basket(p, bx, by)
    elif su:
        p.person(*at(mid, am), (70, 96, 150))
    elif sp and level >= 2:
        p.person(*at(mid, am - 6), (110, 80, 60))
    return p.finish(label="vineyard L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "vineyard.png")
    kit.sheet(draw, LEVELS, "Vineyard and winery: levels 0-3 by season", out, NAMES, ground="grass", wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "vineyard_variants.png")
    kit.variant_sheet(draw, LEVELS, "Vineyard: layouts and mirror", vout, NAMES, ground="grass")
    print("wrote", os.path.normpath(vout))
