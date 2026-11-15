"""The flat tiles: ground cover, sea, relief shade and light, and the hex marks (marks.png). Colours are the style frame's
(tools/worldmap/style_frame/frame.py); nothing here reads a map.

Ground and sea tiles are opaque inside their hex and fade out over SPILL px beyond it, so a tile of a higher rank
spills softly onto its neighbours (the rank is the tile's z). Shade and light tiles are a smooth bump round the hex
whose neighbours add up to one, so the per-hex shade of the map becomes a smooth field (see shade_tiles).
"""
import math
import random

import pygame

import lattice as LT
from tile_atlas import GridAtlas, blank, from_rgba

SPILL = 34
G_W, G_H = LT.CELL_W + 2 * SPILL, LT.CELL_H + 2 * SPILL

C_FARM = (178, 198, 98)
C_GRASS = (146, 186, 86)
C_WOOD = (112, 164, 78)
C_ROCK = (170, 156, 130)
C_SAND = (234, 216, 162)
C_ALPINE = (172, 160, 138)
C_MARSH = (128, 162, 98)
C_TUNDRA = (150, 160, 112)
C_SEA = (71, 143, 192)
C_SHELF = (96, 168, 210)
C_DEEP = (52, 112, 170)
HIGH_TINT = (190, 206, 128)

COVERS = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]
BASE = {"farmland": C_FARM, "grassland": C_GRASS, "woods": C_WOOD, "marsh": C_MARSH, "rock": C_ROCK, "snow": C_ALPINE,
        "tundra": C_TUNDRA, "sand": C_SAND}
# A higher rank spills over a lower one.
RANK = {"sand": 0, "farmland": 1, "grassland": 2, "marsh": 3, "tundra": 4, "woods": 5, "rock": 6, "snow": 7}
GREEN = ("farmland", "grassland", "woods", "marsh")
STONY = ("rock", "snow")
BANDS = 5               # green covers: 0 to 3 = paler and drier with height, 4 = alpine (half stone)
GROUND_VARIANTS = 3
SEA_RANK = {"shelf": 0, "sea": 1, "deep": 2}
SEA_COL = {"shelf": tuple((a + b) // 2 for a, b in zip(C_SHELF, C_SEA)), "sea": C_SEA,
           "deep": tuple(int(a + (b - a) * 0.6) for a, b in zip(C_SEA, C_DEEP))}
SEA_VARIANTS = 3
SHADE_LEVELS = 10       # tile shade/<n>: the ground times 1 - 0.03 n, a little cooler
LIGHT_LEVELS = 6        # tile light/<n>: a warm light of n sixths added
K_RADIUS = 1.2 * LT.CELL_W
S_W, S_H = 2 * int(K_RADIUS) + 4, 2 * int(K_RADIUS * LT.TILT) + 4


def _scaled(col, ref, to):
    return tuple(max(0, min(255, int(round(col[i] * to[i] / float(ref[i]))))) for i in range(3))


def palette(season="summer", climate="snow"):
    """The colours of one tile set: ground covers, the three seas and the coast's sand, foam and light band.
    Summer is the constants of this module; the other seasons take the pieces kit's tokens (kit.PAL, kit.WINTER[climate]),
    and what the kit has no token for (marsh, tundra, the high tint, alpine stone, the deep sea) is scaled the same way."""
    if season == "summer":
        sea, shelf, deep = C_SEA, SEA_COL["shelf"], SEA_COL["deep"]
        return {"base": dict(BASE), "high": HIGH_TINT, "alpine": C_ALPINE,
                "sea": {"shelf": shelf, "sea": sea, "deep": deep},
                "sand": C_SAND, "foam": (226, 242, 248), "shelf": (83, 155, 201), "light": (122, 192, 222)}
    import art
    k = art.kit()
    p = k.WINTER[climate] if season == "winter" else k.PAL[season]
    grass = _scaled
    base = dict(BASE)
    base.update(farmland=p["farm"], grassland=p["grass"], woods=p["wood"], rock=p["rock"], sand=p["sand"],
                marsh=grass(C_MARSH, C_GRASS, p["grass"]), tundra=grass(C_TUNDRA, C_GRASS, p["grass"]),
                snow=grass(C_ALPINE, C_ROCK, p["rock"]))
    sea = p["sea"]
    shallow = p["shallow"]
    shelf = tuple((a + b) // 2 for a, b in zip(shallow, sea))
    seas = {"shelf": shelf, "sea": sea, "deep": grass(SEA_COL["deep"], C_SEA, sea)}
    light = tuple(max(0, min(255, c + shelf[i] - s)) for i, (c, s) in enumerate(zip((122, 192, 222), (83, 155, 201))))
    return {"base": base, "high": grass(HIGH_TINT, C_GRASS, p["grass"]), "alpine": grass(C_ALPINE, C_ROCK, p["rock"]),
            "sea": seas, "sand": p["sand"], "foam": p["foam"], "shelf": shelf, "light": light}


SUMMER = None           # palette("summer"), made on first use


def _pal(pal):
    global SUMMER
    if pal is not None:
        return pal
    if SUMMER is None:
        SUMMER = palette("summer")
    return SUMMER


def band_colour(cover, band, pal=None):
    pal = _pal(pal)
    c = pal["base"][cover]
    if cover not in GREEN:
        return c
    t = 0.1 * min(band, 3)
    c = tuple(c[i] + (pal["high"][i] - c[i]) * t for i in range(3))
    if band == 4:
        c = tuple(c[i] + (pal["alpine"][i] - c[i]) * 0.55 for i in range(3))
    return c


def _edge_alpha(h, n):
    if h <= 0.5:
        return 255
    return int(255 * (1.0 - LT.smoothstep(0.0, SPILL * (0.3 + 0.7 * n), h)))


def ground_tile(cover, band, variant, pal=None):
    seed = 1000 + COVERS.index(cover) * 31 + band * 7 + variant
    nz = LT.ValueNoise(seed)
    base = band_colour(cover, band, pal)
    stony = cover in STONY or band == 4
    buf = bytearray(G_W * G_H * 4)
    ox, oy = G_W / 2.0, G_H / 2.0
    for y in range(G_H):
        py = y + 0.5 - oy
        for x in range(G_W):
            px = x + 0.5 - ox
            h = LT.hex_h(px, py)
            if h >= SPILL:
                continue
            a = _edge_alpha(h, nz.at(px + 400, py + 400, 16.0))
            if a <= 0:
                continue
            hsh = LT.pixel_hash(x + 7 * variant, y + 13 * band)
            f = 1.0 + (nz.at(px + 200, py + 200, 14.8) - 0.5) * 0.115 + (hsh - 128) * 0.0002
            r, g, b = base[0] * f, base[1] * f, base[2] * f
            if stony:                       # scree: light and dark dabs
                n2 = nz.at(px + 900, py + 900, 5.9)
                if n2 > 0.704 and hsh > 120:
                    r, g, b = r + 26, g + 24, b + 20
                elif n2 < 0.32 and hsh > 150:
                    r, g, b = r - 30, g - 30, b - 26
            i = (y * G_W + x) * 4
            buf[i] = max(0, min(255, int(r)))
            buf[i + 1] = max(0, min(255, int(g)))
            buf[i + 2] = max(0, min(255, int(b)))
            buf[i + 3] = a
    surf = from_rgba(buf, (G_W, G_H))
    if stony:
        _rocks(surf, random.Random(seed), 0.24 if cover in STONY else 0.14)
    if cover == "marsh":
        _reeds(surf, random.Random(seed))
    return surf


def _rocks(surf, rnd, chance):
    """The style frame's boulders, scree streaks and tufts (render.Frame.rocks), inside the hex."""
    ox, oy = G_W / 2.0, G_H / 2.0
    y = -LT.HALF_H
    while y < LT.HALF_H:
        x = -LT.HALF_W
        while x < LT.HALF_W:
            sx, sy = x + rnd.uniform(-2.6, 2.6), y + rnd.uniform(-1.9, 1.9)
            x += 5.57
            if LT.hex_h(sx, sy) > -2.0 or rnd.random() > chance:
                continue
            sx, sy = sx + ox, sy + oy
            kind = rnd.random()
            if kind < 0.45:
                rr = rnd.uniform(1.4, 2.6)
                pts = [(sx + math.cos(a) * rr * rnd.uniform(0.8, 1.15), sy + math.sin(a) * rr * 0.7)
                       for a in [q * math.pi / 3 for q in range(6)]]
                pygame.draw.polygon(surf, (196, 186, 166), pts)
                pygame.draw.polygon(surf, (140, 130, 118), [pts[0], pts[1], pts[2], (sx, sy)])
                pygame.draw.polygon(surf, (84, 74, 68), pts, 1)
            elif kind < 0.75:
                ln = rnd.uniform(2.5, 4.5)
                col = (198, 188, 168) if rnd.random() < 0.5 else (128, 118, 104)
                pygame.draw.line(surf, col, (sx, sy), (sx + ln * 0.35, sy + ln), 1)
                pygame.draw.line(surf, col, (sx + 2, sy), (sx + 2 + ln * 0.3, sy + ln * 0.8), 1)
            else:
                for _ in range(3):
                    tx = sx + rnd.uniform(-2, 2)
                    pygame.draw.line(surf, (112, 140, 76), (tx, sy), (tx + rnd.uniform(-1, 1), sy - 2.2), 1)
        y += 4.26


def _reeds(surf, rnd):
    ox, oy = G_W / 2.0, G_H / 2.0
    for _ in range(26):
        x, y = rnd.uniform(-LT.HALF_W, LT.HALF_W), rnd.uniform(-LT.HALF_H, LT.HALF_H)
        if LT.hex_h(x, y) > -6:
            continue
        if rnd.random() < 0.35:
            pygame.draw.ellipse(surf, (96, 150, 170), (x + ox - 5, y + oy - 2, 10, 4))
            pygame.draw.ellipse(surf, (70, 110, 130), (x + ox - 5, y + oy - 2, 10, 4), 1)
        else:
            for q in range(3):
                pygame.draw.line(surf, (88, 124, 70), (x + ox + q * 2, y + oy), (x + ox + q * 2 - 1, y + oy - 4), 1)


def sea_tile(depth, variant, pal=None):
    nz = LT.ValueNoise(77 + variant + 10 * SEA_RANK[depth])
    col = _pal(pal)["sea"][depth]
    hard = depth == "shelf"
    buf = bytearray(G_W * G_H * 4)
    ox, oy = G_W / 2.0, G_H / 2.0
    for y in range(G_H):
        py = y + 0.5 - oy
        for x in range(G_W):
            px = x + 0.5 - ox
            h = LT.hex_h(px, py)
            if hard:
                a = 255 if h <= 2.0 else 0
            else:
                a = _edge_alpha(h, nz.at(px + 400, py + 400, 12.0))
            if a <= 0:
                continue
            n1 = (nz.at(px + 200, py + 200, 14.8) - 0.5) * 255
            i = (y * G_W + x) * 4
            buf[i] = max(0, min(255, int(col[0] + n1 * 0.05)))
            buf[i + 1] = max(0, min(255, int(col[1] + n1 * 0.06)))
            buf[i + 2] = max(0, min(255, int(col[2] + n1 * 0.05)))
            buf[i + 3] = a
    surf = from_rgba(buf, (G_W, G_H))
    rnd = random.Random(500 + variant)
    for _ in range(variant):                # the frame's wave marks: variant 0 has none
        x, y = rnd.uniform(-28, 28) + ox, rnd.uniform(-26, 26) + oy
        for dx in (-6, 0):
            pygame.draw.arc(surf, (112, 176, 218), (x + dx, y - 2, 6, 4), 0.2, math.pi - 0.2, 1)
    return surf


def _kernel(x, y):
    d = math.hypot(x, y / LT.TILT) / K_RADIUS
    return (1.0 - d * d) ** 2 if d < 1.0 else 0.0


def _weights():
    """w[y][x]: the share of this hex at each pixel of a shade tile. The shares of all hexes add up to 1 everywhere."""
    out = []
    ox, oy = S_W / 2.0, S_H / 2.0
    for y in range(S_H):
        row = []
        py = y + 0.5 - oy
        for x in range(S_W):
            px = x + 0.5 - ox
            k = _kernel(px, py)
            if k <= 0.0:
                row.append(0.0)
                continue
            total = 0.0
            for j in range(-3, 4):
                for i in range(-3, 4):
                    cx = LT.CELL_W * (i + 0.5 * (j & 1))
                    total += _kernel(px - cx, py - LT.ROW * j)
            row.append(k / total)
        out.append(row)
    return out


def shade_colour(level):
    """What the ground is multiplied by at full weight: darker, and a little cooler (the frame's shaded slopes)."""
    t = level / float(SHADE_LEVELS)
    f = 1.0 - 0.30 * t
    return (f - 0.03 * t, f, f + 0.03 * t)


LIGHT_HUE = (255, 250, 150)
LIGHT_ALPHA = 0.125             # the alpha of light/<LIGHT_LEVELS> at full weight: adds about (32, 31, 19)


def shade_tiles(atlas):
    w = _weights()
    for level in range(1, SHADE_LEVELS + 1):
        c = shade_colour(level)
        buf = bytearray(S_W * S_H * 4)
        for y in range(S_H):
            for x in range(S_W):
                k = w[y][x]
                i = (y * S_W + x) * 4
                buf[i] = int(round(255 * c[0] ** k))
                buf[i + 1] = int(round(255 * c[1] ** k))
                buf[i + 2] = min(255, int(round(255 * c[2] ** k)))
                buf[i + 3] = 255
        atlas.add("shade/%d" % level, from_rgba(buf, (S_W, S_H)))
    for level in range(1, LIGHT_LEVELS + 1):
        buf = bytearray(S_W * S_H * 4)
        for y in range(S_H):
            for x in range(S_W):
                i = (y * S_W + x) * 4
                buf[i], buf[i + 1], buf[i + 2] = LIGHT_HUE
                buf[i + 3] = int(round(255 * LIGHT_ALPHA * level / LIGHT_LEVELS * w[y][x]))
        atlas.add("light/%d" % level, from_rgba(buf, (S_W, S_H)))


def grid_tile():
    """The hex outline of one cell (the frame's grid line); neighbours draw the shared edges twice."""
    s = blank((G_W, G_H))
    pts = [(x + G_W / 2.0, y + G_H / 2.0) for x, y in LT.hex_points()]
    pygame.draw.aalines(s, (30, 40, 30, 44), True, pts)
    return s


MARK_SS = 4                     # the marks are drawn at 4 x and shrunk to the tile, so their edges are smooth
GOLD = (255, 214, 70)           # the selection's gold (hexa/campaign/art.py GOLD)
INK = (40, 30, 18)              # the dark edge under a mark's line
CREAM = (246, 244, 226)         # the build target's dashes


def _mark(draw):
    """One mark: draw(surface, corners) paints it at MARK_SS times the tile's size, then the picture shrinks to the tile."""
    big = blank((G_W * MARK_SS, G_H * MARK_SS))
    pts = [((x + G_W / 2.0) * MARK_SS, (y + G_H / 2.0) * MARK_SS) for x, y in LT.hex_points()]
    draw(big, pts)
    return pygame.transform.smoothscale(big, (G_W, G_H))


def _ring(surf, pts, colour, width):
    """A closed line of width px (before the shrink) on the hex's edges."""
    pygame.draw.polygon(surf, colour, pts, width * MARK_SS)


def select_tile():
    """The selected hex: a light fill, a gold edge over a dark one."""
    def draw(s, pts):
        pygame.draw.polygon(s, (255, 255, 255, 60), pts)
        _ring(s, pts, INK + (255,), 4)
        _ring(s, pts, GOLD + (255,), 2)
    return _mark(draw)


def target_tile():
    """A build target: a light fill and a dashed cream edge over a dark one."""
    def draw(s, pts):
        pygame.draw.polygon(s, (255, 255, 255, 40), pts)
        _ring(s, pts, INK + (255,), 4)
        for i in range(6):
            a, b = pts[i], pts[(i + 1) % 6]
            for k in (0, 2):                    # every second quarter of each side is a dash
                p = (a[0] + (b[0] - a[0]) * k / 4.0, a[1] + (b[1] - a[1]) * k / 4.0)
                q = (a[0] + (b[0] - a[0]) * (k + 1) / 4.0, a[1] + (b[1] - a[1]) * (k + 1) / 4.0)
                pygame.draw.line(s, CREAM + (255,), p, q, 2 * MARK_SS)
    return _mark(draw)


def white_tile():
    """A white hex for tinting (M2): opaque inside the hex, smooth at the edge."""
    return _mark(lambda s, pts: pygame.draw.polygon(s, (255, 255, 255, 255), pts))


def bake(covers=COVERS, log=print):
    """The trial's flat stage (summer; the grid line also stays in ground for the trial scene)."""
    ground = GridAtlas("ground", (G_W, G_H))
    for cover in covers:
        for band in range(BANDS if cover in GREEN else 1):
            for v in range(GROUND_VARIANTS):
                ground.add("ground/%s/%d/%d" % (cover, band, v), ground_tile(cover, band, v), z=RANK[cover])
        log("ground: %s" % cover)
    for depth in ("shelf", "sea", "deep"):
        for v in range(SEA_VARIANTS):
            ground.add("sea/%s/%d" % (depth, v), sea_tile(depth, v), z=SEA_RANK[depth])
    ground.add("grid/line", grid_tile())    # the old place of the grid: tile_trial.gd still draws its grid from here
    shade = GridAtlas("shade", (S_W, S_H))
    shade_tiles(shade)
    log("shade: %d tiles of %d x %d" % (len(shade.tiles), S_W, S_H))
    marks = GridAtlas("marks", (G_W, G_H))
    marks.add("mark/grid", grid_tile())
    marks.add("mark/select", select_tile())
    marks.add("mark/target", target_tile())
    marks.add("mark/white", white_tile())
    log("marks: %d tiles of %d x %d" % (len(marks.tiles), G_W, G_H))
    return [ground, shade, marks]
