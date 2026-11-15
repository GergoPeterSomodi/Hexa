"""Wild decor tiles: trees by wedge, hills and mountain ridges by hex. The drawing is the style frame's own
(art.Painter: draw_tree, draw_conifer, draw_hill, draw_range), called on a blank picture; no map is read.

TREES BY WEDGE. A hex is six wedges (the triangle from its middle to each edge). Each wedge is its own tile on its
own layer, so the view can pick per wedge: full wood, a bank kept clear along a river edge, a corridor kept clear
for a road, only the outer ring (the hex is built on), a loose fringe (the neighbour is a wood) or a few trees.
The trees' shadows are baked under them (flat, the frame's alpha).

RELIEF BY HEX. One tile: a few rounded hills, or a ridge of two or three peaks, wider than the hex so the ridges of
neighbouring hexes join. `back` ridges stand in the upper half of the hex (the hex is built on); `pass` ridges leave
a saddle in the middle (a road crosses).
"""
import math
import random

import pygame

import art
import lattice as LT
from tile_atlas import blank

SHADOW = (30, 50, 30)
SHADOW_ALPHA = 46

T_W, T_H = 76, 84
# Where the middle of the cell lies in a wedge tile, per direction (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE).
T_ANCHOR = [(10, 50), (10, 76), (66, 76), (66, 50), (66, 24), (10, 24)]
T_SORT = [0, -30, -30, 0, 30, 30]
TREE_KINDS = ("broad", "mixed", "conifer")
TREE_OPTS = ("full", "thin", "bank", "road", "bankroad", "outer", "outerroad", "fringe", "sparse")
TREE_VARIANTS = 2
OVER = 3.0                      # px a wood may stand beyond its hex edge, so two wooded hexes knit
BANK = 9.0                      # px kept clear inside an edge with a river
ROAD = 8.0                      # px kept clear either side of a road's line
RING = 17.0                     # a built hex keeps its trees this near its edge only

R_W, R_H = 236, 150
R_ANCHOR = (118, 112)
RELIEF_KINDS = ("hills_low", "hills_high", "ridge_green", "ridge_rock", "ridge_snow")
RELIEF_FORMS = ("full", "pass", "back")
RELIEF_VARIANTS = 3
RIDGE_M = {"ridge_green": 1380.0, "ridge_rock": 2020.0, "ridge_snow": 2750.0}

_NORMALS = []
for _nx, _ny in LT.NEIGHBOUR:
    _l = math.hypot(_nx, _ny)
    _NORMALS.append((_nx / _l, _ny / _l, _l / 2.0))


def wedge_of(x, y):
    best, bd = -1e9, 0
    for d, (nx, ny, dist) in enumerate(_NORMALS):
        v = (nx * x + ny * y) / dist
        if v > best:
            best, bd = v, d
    return bd


def _spoke_distance(x, y, d):
    """px from a point to the road's line: the middle of the hex to the middle of edge d (and on to the neighbour)."""
    nx, ny, _ = _NORMALS[d]
    along = x * nx + y * ny
    if along < 0:
        return math.hypot(x, y)
    return abs(-x * ny + y * nx)


def _hp(m):
    t = max(0.0, min(1.0, (m - 450.0) / 2650.0))
    return 8.0 + 40.0 * t ** 0.85


def _lay_shadows(surf, ellipses):
    if not ellipses:
        return
    lay = blank(surf.get_size())
    for x, y, w, h in ellipses:
        r = pygame.Rect(0, 0, max(2, int(w)), max(2, int(h)))
        r.center = (int(x), int(y))
        pygame.draw.ellipse(lay, SHADOW + (255,), r)
    lay.set_alpha(SHADOW_ALPHA)
    surf.blit(lay, (0, 0))


def tree_tile(painter, d, kind, opt, variant):
    rnd = random.Random("%s/%s/%d/%d" % (kind, opt, d, variant))
    nz = LT.ValueNoise(rnd.randrange(1 << 20))
    ax, ay = T_ANCHOR[d]
    nx, ny, dist = _NORMALS[d]
    trees = []
    sx, sy = 7.42, 5.46
    y = -LT.HALF_H - 8
    j = 0
    while y < LT.HALF_H + 8:
        x = -LT.HALF_W - 8 + (sx / 2 if j % 2 else 0)
        while x < LT.HALF_W + 8:
            px, py = x + rnd.uniform(-3.0, 3.0), y + rnd.uniform(-2.2, 2.2)
            x += sx
            roll, scale, pick = rnd.random(), rnd.uniform(0.85, 1.12), rnd.random()
            if wedge_of(px, py) != d:
                continue
            h = LT.hex_h(px, py)
            edge = nx * px + ny * py - dist            # <= 0 inside this wedge's edge
            if h > OVER:
                continue
            n = nz.at(px + 300, py + 300, 22.0) * 0.6 + nz.at(px + 700, py + 700, 8.2) * 0.4
            if opt == "sparse":
                if roll > (0.13 if kind == "conifer" else 0.035) or h > -4:
                    continue
            elif opt == "fringe":
                reach = 26.0 * (0.4 + n)                # a loose fringe: thick at the edge, gone towards the middle
                if edge < -reach or roll > 0.75 * (1.0 + edge / reach) + 0.1 or h > 0:
                    continue
            else:
                if n < (0.5 if opt == "thin" else 0.36):
                    continue                            # clearings; "thin" keeps only the clumps (hills show between)
                if opt in ("bank", "bankroad") and edge > -BANK:
                    continue
                if opt in ("road", "bankroad", "outerroad") and _spoke_distance(px, py, d) < ROAD:
                    continue
                if opt in ("outer", "outerroad") and h < -RING:
                    continue
            conifer = kind == "conifer" or nz.at(px + 100, py + 100, 18.6) > (0.74 if kind == "broad" else 0.5)
            trees.append((py, px, scale, conifer, pick))
        y += sy
        j += 1
    surf = blank((T_W, T_H))
    _lay_shadows(surf, [(px + ax + 3.2 * sc, py + ay + 0.5, 7 * sc, 2.4 * sc) for py, px, sc, _, _ in trees])
    f = painter.on(surf)
    for py, px, sc, conifer, _ in sorted(trees):
        if conifer:
            f.draw_conifer(round(px + ax), round(py + ay), sc, 1.0)
        else:
            f.draw_tree(round(px + ax), round(py + ay), sc, 1.0)
    return surf


def relief_tile(painter, kind, form, variant):
    rnd = random.Random("%s/%s/%d" % (kind, form, variant))
    surf = blank((R_W, R_H))
    ax, ay = R_ANCHOR
    f = painter.on(surf)
    if kind.startswith("hills"):
        hills = []
        tries = 0
        want = 4 if form == "full" else 3
        while len(hills) < want and tries < 200:
            tries += 1
            x, y = rnd.uniform(-34, 34), rnd.uniform(-26, 30)
            if form == "pass" and abs(x) < 14:
                continue
            if form == "back" and y > -8:
                continue
            if LT.hex_h(x, y) > -14 or any(abs(x - q[0]) < 26 and abs(y - q[1]) < 12 for q in hills):
                continue
            h = (6.5 if kind == "hills_low" else 11.5) * rnd.uniform(0.85, 1.15)
            hills.append((x, y, h, rnd.random()))
        _lay_shadows(surf, [(x + ax + h * 0.9, y + ay + 1, h * 2.6, h * 0.5) for x, y, h, _ in hills])
        for x, y, h, seed in sorted(hills, key=lambda q: q[1]):
            f.draw_hill(round(x + ax), round(y + ay), h, seed)
        return surf
    m = RIDGE_M[kind]
    foot = -14.0 if form == "back" else 14.0 + 6.0 * variant
    size = 0.72 if form == "back" else (1.0 if kind == "ridge_green" else 1.22)
    xs = [[-36, 0, 36], [-40, -6, 32], [-30, 8, 42]][variant]
    groups = []
    if form == "full":                      # a second, lower ridge behind and to one side: no row of stamps
        side = -1 if variant % 2 else 1
        groups.append(([side * 22 - 20, side * 22 + 18], foot - 19.0, size * 0.8))
    groups.append((xs, foot, size))
    for xs, foot, size in groups:
        _ridge(surf, f, rnd, xs, foot, size, m, form, ax, ay)
    return surf


def _ridge(surf, f, rnd, xs, foot, size, m, form, ax, ay):
    g = []
    for i, x in enumerate(xs):
        apex = not (form == "pass" and i == 1 and len(xs) == 3)
        mm = m * rnd.uniform(0.84, 1.1) * (1.12 if i == 1 and apex else 1.0)
        h = _hp(mm) * size
        if not apex:
            h *= 0.3
        g.append(dict(x=x + ax + rnd.uniform(-3, 3), y=foot + ay + rnd.uniform(-3, 3), h=h, apex=apex, m=mm, seed=rnd.random(),
                      pass_=None, kind="crest"))
    _lay_shadows(surf, [(p["x"] + p["h"] * 1.15 * 0.35, p["y"] + p["h"] * 0.05, p["h"] * 1.15 * 1.3, max(3, p["h"] * 0.28))
                        for p in g if p["apex"]])
    f.draw_range(g)


def relief_sort(form):
    return -14 if form == "back" else 20


def bake(tree_atlas, relief_atlas, season="summer", climate="snow", log=print):
    painter = art.Painter(season, climate)
    for kind in TREE_KINDS:
        for opt in TREE_OPTS:
            for d in range(6):
                for v in range(TREE_VARIANTS):
                    tree_atlas.add("trees/%s/%s/%d/%d" % (kind, opt, d, v), tree_tile(painter, d, kind, opt, v),
                                   anchor=T_ANCHOR[d], y_sort=T_SORT[d])
    log("trees: %d wedge tiles" % len(tree_atlas.tiles))
    for kind in RELIEF_KINDS:
        for form in RELIEF_FORMS:
            for v in range(RELIEF_VARIANTS):
                relief_atlas.add("relief/%s/%s/%d" % (kind, form, v), relief_tile(painter, kind, form, v),
                                 anchor=R_ANCHOR, y_sort=relief_sort(form))
    log("relief: %d tiles" % len(relief_atlas.tiles))
