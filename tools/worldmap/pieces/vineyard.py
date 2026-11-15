"""Vineyard and winery, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 scrub on sunny hills - 1 two young blocks and a thatched hut - 2 four blocks of full rows, a tiled house, the press
house with two vats - 3 six blocks, the upper two terraced, a track, the wine estate with a tower and cypresses.

python vineyard.py         writes docs/design/map/pieces/vineyard.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "scrub", 1: "young vines", 2: "press house", 3: "estate"}

# The layout is fixed: a level adds to the level below and never moves anything.
HUT = (-14, 8)                                        # the hut, later the tiled house: same foot at every level
PRESS = (3, -2)                                       # the press house (level 2)
VATS = [(13.5, -0.5), (18.5, 1.8)]
ESTATE = (-3, -24)                                    # the estate house (level 3)
TOWER = (-10.5, -24)
CYPRESS = [(6, -23), (10, -25.5)]
BLOCKS = [                                            # cx, cy, w, h, angle, rows, from level, shelves (terraces)
    (26, 14, 24, 17, -8, 6, 1, 1),
    (-26, 22, 22, 15, 6, 5, 1, 1),
    (28, -9, 24, 16, 18, 6, 2, 1),
    (-28, -10, 22, 16, -14, 5, 2, 1),
    (-28, -26, 18, 14, 0, 5, 3, 2),
    (28, -28, 18, 14, 0, 5, 3, 2),
]
TRACK = [(-12, 11), (-10, 20), (-6, 32), (-4, 46)]
WILD = [                                              # x, y, kind, size, gone from level (9 = never)
    (-26, -26, "bush", 1.0, 3), (28, -27, "bush", 1.0, 3), (-30, -6, "bush", 1.0, 2), (30, 18, "bush", 1.0, 1),
    (-30, 24, "bush", 1.0, 1), (3, -40, "bush", 1.0, 9), (-42, 4, "bush", 1.0, 9), (42, 2, "bush", 1.0, 9),
    (30, -8, "round", 0.9, 2), (-14, -25, "round", 1.0, 3),
]
STONES = [(-4, 22, 1.8, 9), (10, 16, 1.6, 3), (34, -30, 1.5, 3), (-38, -18, 1.6, 2), (36, 30, 1.5, 9)]


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
    p.stand(y, fn)


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
    p.stand(y, fn)


def basket(p, x, y):
    p.stand(y, lambda pen: (pen.rect(x - 1.1, y - 1.5, 2.2, 1.5, kit.TIMBER, kit.INK, 0.5), pen.rect(x - 1.1, y - 1.5, 2.2, 0.5, (150, 60, 66), None)))


def draw(level, season):
    p = kit.Piece(season, ground="grass", seed=2)
    sp, su, au, wi = season == "spring", season == "summer", season == "autumn", season == "winter"
    soil = kit.crop("vine_soil", season)[0]
    vine = kit.crop("vine", season)[0]
    if wi:
        strips = [kit.SNOW, kit.mix(kit.SNOW, kit.SNOW_D, 0.7), kit.SNOW, p.pal["soil"]]     # one strip in four shows earth
    else:
        strips = [soil]
    blocks = [b for b in BLOCKS if b[6] <= level]

    # ---- ground plane
    if level == 0:                                    # wild land, with darker patches where the vines will come
        for b in BLOCKS:
            p.blob(b[0], b[1], b[2] * 1.1, b[3] * 0.9, kit.mix(p.pal["grass"], p.pal["wood"], 0.5))
    if level >= 3:
        p.road(TRACK, 1.6, track=True)
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
            wall = [(cx - w / 2 - 0.5, ya + 0.4), (cx + w / 2 + 0.5, ya + 0.4)]
            p.patch([wall[0], wall[1], (wall[1][0], wall[1][1] + 2.2), (wall[0][0], wall[0][1] + 2.2)], kit.STONE, kit.STONE_D, 0.5)
            p.patch([wall[0], wall[1], (wall[1][0], wall[1][1] + 0.7), (wall[0][0], wall[0][1] + 0.7)], kit.SNOW if wi else (236, 228, 208), None)
    avoid = [(b[0], b[1], max(b[2], b[3]) * 0.62) for b in blocks] + [(HUT[0], HUT[1], 8)]
    if level >= 2:
        avoid += [(PRESS[0] + 6, PRESS[1], 14)]
    p.tufts(14 if level == 0 else 8 if level == 1 else 4, avoid=avoid if level else ())
    p.stones([(x, y, r) for x, y, r, g in STONES if level < g or g == 9])

    # ---- standing things
    for i, (x, y, kind, sc, gone) in enumerate(WILD):
        if level < gone:
            p.tree(x, y, sc, kind, i)
    if level >= 1:
        if level == 1:
            p.house(HUT[0], HUT[1], 5.5, 3.5, 3.0, wall=0, roof="thatch", smoke=True)
        else:
            p.house(HUT[0], HUT[1], 7.5, 4.8, 3.6, wall=0, roof="tile", smoke=True)
    if level >= 2:
        press_house(p, PRESS[0], PRESS[1])
        for x, y in VATS:
            vat(p, x, y)
    if level >= 3:
        p.tower(TOWER[0], TOWER[1], 4.4, 11.5, col=kit.PLASTER[3], top="cone", roof=kit.ROOF)
        p.house(ESTATE[0], ESTATE[1], 12.0, 6.4, 4.4, wall=kit.PLASTER[0], roof="tile")
        for i, (x, y) in enumerate(CYPRESS):
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


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "vineyard.png")
    kit.sheet(draw, LEVELS, "Vineyard and winery: levels 0-3 by season", out, NAMES, ground="grass")
    print("wrote", os.path.normpath(out))
