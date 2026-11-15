"""Olives, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 the map's wild land - 1 a thatched hut and seven olive trees in two loose groups - 2 a stone farmhouse, 15 trees on
three terrace walls - 3 an oil mill with a millstone, 24 trees on five terrace walls, a track.
The olive tree is evergreen: its colours never change with the season, only the ground does.

python olives.py           writes docs/design/map/pieces/olives.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
VARIANTS = 1
NAMES = {0: "wild land (the map's)", 1: "hut, 7 trees", 2: "farmhouse", 3: "oil mill"}

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
TRACK = [(28, 12), (24, 20), (16, 29), (8, 36)]
GATES = {"south": (8, 36)}                            # the track ends here; the map's road layer carries it on

def wall_pts(y, x0, x1):
    n = 8
    return [(x0 + (x1 - x0) * i / n, y + 1.4 * ((i / n - 0.5) ** 2) * -4 + 1.0) for i in range(n + 1)]


def clip(pts, shrink=10.0):
    """The polygon pts cut to the hex pulled in by `shrink` px: ground work keeps 10 px clear of the border (GUIDE C3)."""
    hx = kit.hex_points(shrink)
    sgn = 1 if sum(hx[i][0] * hx[(i + 1) % 6][1] - hx[(i + 1) % 6][0] * hx[i][1] for i in range(6)) > 0 else -1
    out = list(pts)
    for i in range(6):
        a, b = hx[i], hx[(i + 1) % 6]

        def side(q):
            return sgn * ((b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0]))
        src, out = out, []
        for j, q in enumerate(src):
            r = src[j - 1]
            sq, sr = side(q), side(r)
            if (sq >= 0) != (sr >= 0):
                t = sr / (sr - sq)
                out.append((r[0] + (q[0] - r[0]) * t, r[1] + (q[1] - r[1]) * t))
            if sq >= 0:
                out.append(q)
        if not out:
            break
    return out


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
    return p.stand(y, fn, x=x)


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece: the sheets show the map's wild land
        return kit.wild(season, "grass", seed=3)
    p = kit.Piece(season, ground="grass", seed=3, mirror=mirror)
    sp, su, au, wi = season == "spring", season == "summer", season == "autumn", season == "winter"
    soil = kit.crop("olive_soil", season)[0]
    if wi:                                            # the shelves take snow; the walls stay stone
        soil = kit.mix(soil, kit.SNOW, 0.6)
    trees = [t for t in TREES if t[2] <= level]
    walls = [w for w in WALLS if w[3] <= level]

    # ---- ground plane
    for x, y, frm in trees:                           # pale ochre soil under every tree
        p.patch(clip(ellipse_pts(x + 0.5, y + 1.5, 5.5, 3.25)), soil)
    for y, x0, x1, _ in walls:                        # the terrace strip north of each wall
        p.patch(clip([(x0, y - 11), (x1, y - 11), (x1, y), (x0, y)]), soil)
    for y, x0, x1, _ in walls:                        # the wall: a stone face under a pale top line, never under snow
        p.terrace([q for q in wall_pts(y, x0, x1) if kit.in_hex(q[0], q[1] + 3, 10)], face=3)
    if level >= 3:
        p.road(TRACK, 1.6, track=True)
        p.blob(STONE_AT[0], STONE_AT[1], 11.2, 7.2, kit.STONE, edge=kit.STONE_D)                 # the millstone, flat on the ground
        p.blob(STONE_AT[0], STONE_AT[1], 3.0, 2.0, kit.DOOR)
    if sp:                                            # blossom dots on the ground under one tree in three
        for i, (x, y, frm) in enumerate(trees):
            if i % 3 == 0:
                for dx, dy in ((-3, 1), (2, 2.5), (-0.5, 3.5), (3.5, 0.5)):
                    p.blob(x + dx, y + dy, 2.0, 1.3, (255, 250, 250))
    new = [t for t in trees if t[2] == level]
    if au:                                            # the harvest: pale cloths under three of the newest trees
        for x, y, _ in new[:3]:
            p.patch(clip([(x - 4.5, y + 0.5), (x + 4.5, y + 0.5), (x + 5.5, y + 3.8), (x - 5.5, y + 3.8)]), kit.SAIL_D, kit.STONE_D, 0.5)

    # ---- standing things
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
    return [(cx + math.cos(2 * math.pi * i / n) * rx, cy + math.sin(2 * math.pi * i / n) * ry) for i in range(n)]


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "olives.png")
    kit.sheet(draw, LEVELS, "Olives: levels 0-3 by season", out, NAMES, ground="grass", wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "olives_variants.png")
    kit.variant_sheet(draw, LEVELS, "Olives: layout and mirror", vout, NAMES, ground="grass")
    print("wrote", os.path.normpath(vout))
