"""Olives, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 scrub and pine - 1 a thatched hut and seven olive trees in two loose groups - 2 a stone farmhouse, 15 trees on
three terrace walls - 3 an oil mill with a millstone, 24 trees on five terrace walls, a track.
The olive tree is evergreen: its colours never change with the season, only the ground does.

python olives.py           writes docs/design/map/pieces/olives.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "scrub and pine", 1: "hut, 7 trees", 2: "farmhouse", 3: "oil mill"}

# The layout is fixed: a level adds to the level below and never moves anything.
FARM = (30, 9)                                        # the hut, later the stone farmhouse: same foot at every level
MILL = (13, -2)                                       # the oil mill (level 3)
STONE_AT = (13, 6.5)                                  # its millstone lies on the ground in front
#         wall y, x from, x to, from level      (the strip of ground and trees lies north of its wall)
WALLS = [(-27, -30, 6, 3), (-16, -42, 6, 3), (-6, -42, 3, 2), (8, -46, 1, 2), (22, -40, 11, 2)]
TREES = [                                             # x, y, from level; foot y = wall y - 3.5
    (-37, -9.5, 2), (-28, -9.5, 1), (-19, -9.5, 1), (-10, -9.5, 2), (-1, -9.5, 2),                    # wall -6
    (-39, 4.5, 2), (-30, 4.5, 1), (-21, 4.5, 1), (-12, 4.5, 2), (-3, 4.5, 2),                         # wall 8
    (-33, 18.5, 2), (-24, 18.5, 1), (-15, 18.5, 1), (-6, 18.5, 1), (3, 18.5, 2),                      # wall 22
    (-33, -19.5, 3), (-24, -19.5, 3), (-15, -19.5, 3), (-6, -19.5, 3), (3, -19.5, 3),                 # wall -16
    (-22, -30.5, 3), (-14, -30.5, 3), (-6, -30.5, 3), (2, -30.5, 3),                                  # wall -27
]
WILD = [                                                      # x, y, kind, gone from level (9 = never)
    (-35, -14, "conifer", 2), (-6, -28, "conifer", 3), (25, -20, "conifer", 9), (38, -4, "conifer", 9),
    (14, 30, "bush", 2), (-40, 26, "bush", 2), (24, -16, "bush", 2), (-20, 32, "bush", 3), (40, 22, "bush", 9),
    (18, -30, "bush", 9),
]
STONES = [(22, 18, 1.8, 3), (-38, -2, 1.6, 2), (35, -18, 1.6, 9), (8, 34, 1.6, 9)]
TRACK = [(28, 12), (24, 22), (22, 34), (24, 48)]


def wall_pts(y, x0, x1):
    n = 8
    return [(x0 + (x1 - x0) * i / n, y + 1.4 * ((i / n - 0.5) ** 2) * -4 + 1.0) for i in range(n + 1)]


def oil_mill(p, x, y):
    """The level 3 landmark: a long stone building, 15 px wide, with a tile roof and a chimney."""
    p.cast(x, y, 15)
    winter = p.winter
    w, h, rh = 15.0, 6.0, 4.8

    def fn(pen):
        x0, top = x - w / 2, y - h
        wall = kit.STONE
        pen.rect(x0 + w * 0.8 - 2.4, top - rh - 2.6, 2.0, 3.6, kit.STONE_D, kit.INK, 0.5)     # chimney, behind the roof
        pen.rect(x0, top, w, h, wall, None)
        pen.rect(x0 + w * 0.78, top, w * 0.22, h, kit.shade(wall, 0.84), None)
        for q in range(1, 4):                                                          # masonry courses
            pen.line((x0, top + q * 1.5), (x0 + w * 0.78, top + q * 1.5), kit.STONE_D, 0.5)
        r1, r2 = (kit.SLATE, kit.SLATE_D) if not winter else (kit.SNOW, kit.SNOW_D)
        rf = [(x0 - 1, top + 0.3), (x0 + w + 1, top + 0.3), (x0 + w - 0.8, top - rh), (x0 + 0.8, top - rh)]
        pen.poly(rf, r1, None)
        pen.poly([rf[1], rf[2], (x0 + w * 0.72, top - rh), (x0 + w * 0.78, top + 0.3)], r2, None)
        if winter:
            pen.line(rf[0], rf[1], kit.SLATE_D, 0.5)
        pen.poly(rf, None, kit.INK, 0.5)
        pen.rect(x - 3.4, y - 4.0, 3.2, 4.0, kit.DOOR, None)                 # the wide press door
        pen.rect(x + 1.4, y - 3.8, 1.2, 1.4, kit.DOOR, None)
        pen.rect(x0, top, w, h, None, kit.INK, 0.5)
    p.stand(y, fn)


def draw(level, season):
    p = kit.Piece(season, ground="grass", seed=3)
    sp, su, au, wi = season == "spring", season == "summer", season == "autumn", season == "winter"
    soil = kit.crop("olive_soil", season)[0]
    trees = [t for t in TREES if t[2] <= level]
    walls = [w for w in WALLS if w[3] <= level]

    # ---- ground plane
    if level == 0:                                    # wild land, with darker patches where the groves will come
        for y, x0, x1, _ in WALLS:
            p.blob((x0 + x1) / 2, y - 5, (x1 - x0) * 0.9, 9, kit.mix(p.pal["grass"], p.pal["wood"], 0.5))
    for x, y, frm in trees:                           # pale ochre soil under every tree
        p.blob(x + 0.5, y + 1.5, 11, 6.5, soil)
    for y, x0, x1, _ in walls:                        # the terrace strip north of each wall
        p.patch([(x0, y - 11), (x1, y - 11), (x1, y), (x0, y)], soil)
    for y, x0, x1, _ in walls:
        pts = wall_pts(y, x0, x1)
        p.patch(pts + [(x1, y + 3.6), (x0, y + 3.6)], kit.STONE, kit.STONE_D, 0.5)          # the wall face: never under snow
        p.patch(pts + [(x1, pts[-1][1] + 0.8), (x0, pts[0][1] + 0.8)], kit.SNOW if wi else (238, 230, 210), None)
    if level >= 3:
        p.road(TRACK, 1.6, track=True)
        p.patch(ellipse_pts(*STONE_AT, 5.6, 3.6), kit.STONE, kit.STONE_D, 0.5)                  # the millstone, flat on the ground
        p.patch(ellipse_pts(STONE_AT[0], STONE_AT[1], 1.5, 1.0), kit.DOOR, None)
    avoid = [(MILL[0], MILL[1], 16), (FARM[0], FARM[1], 8)] + [(x, y, 6) for x, y, _ in trees]
    p.tufts(14 if level == 0 else 8 if level == 1 else 4, avoid=avoid if level else ())
    p.stones([(x, y, r) for x, y, r, g in STONES if level < g or g == 9])
    if sp:                                            # blossom dots on the ground under one tree in three
        for i, (x, y, frm) in enumerate(trees):
            if i % 3 == 0:
                for dx, dy in ((-3, 1), (2, 2.5), (-0.5, 3.5), (3.5, 0.5)):
                    p.blob(x + dx, y + dy, 2.0, 1.3, (255, 250, 250))
    new = [t for t in trees if t[2] == level]
    if au:                                            # the harvest: pale cloths under three of the newest trees
        for x, y, _ in new[:3]:
            p.patch([(x - 4.5, y + 0.5), (x + 4.5, y + 0.5), (x + 5.5, y + 3.8), (x - 5.5, y + 3.8)], kit.SAIL_D, kit.STONE_D, 0.5)

    # ---- standing things
    for i, (x, y, kind, gone) in enumerate(WILD):
        if level < gone:
            p.tree(x, y, 1.0 if kind == "conifer" else 1.0, kind, i)
    for i, (x, y, frm) in enumerate(TREES):
        if frm <= level:
            p.tree(x, y, 1.0, "olive", i)
    if level >= 1:
        if level == 1:
            p.house(FARM[0], FARM[1], 5.5, 3.5, 3.0, wall=0, roof="thatch", smoke=True)
        else:
            p.house(FARM[0], FARM[1], 9.5, 5.2, 4.0, wall=kit.STONE, roof="tile", smoke=True)
    if level >= 3:
        oil_mill(p, MILL[0], MILL[1])

    # ---- season activity (never changes the layout)
    if au and new:
        p.person(new[0][0] + 5, new[0][1] + 3.5, (110, 80, 60))
        p.person(new[2][0] - 5, new[2][1] + 3.5, (196, 72, 60))
    elif su and level >= 2:
        p.person(FARM[0] - 8, FARM[1] + 3, (70, 96, 150))
    return p.finish(label="olives L%d" % level)


def ellipse_pts(cx, cy, rx, ry, n=16):
    import math
    return [(cx + math.cos(2 * math.pi * i / n) * rx, cy + math.sin(2 * math.pi * i / n) * ry) for i in range(n)]


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "olives.png")
    kit.sheet(draw, LEVELS, "Olives: levels 0-3 by season", out, NAMES, ground="grass")
    print("wrote", os.path.normpath(out))
