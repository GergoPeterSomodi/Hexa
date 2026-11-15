"""Coast tiles: the shore of a land hex whose neighbours are partly sea, drawn along the hex edges with a wobble.

A coast tile lies over the ground and the sea of its own hex and a margin round it. It paints the sea that the
wobble cuts into the land, the land the wobble pushes out into the sea, the strip of sand or wet rock, the foam, the
light band of shallow water and, on a steep coast seen from the front, the cliff face.

Why neighbouring tiles join: the wobble is a field that repeats on the lattice (lattice.Waves), every tile works out
the same shore from its `mask` (which of its six neighbours are sea), and a pixel is painted only by the tile whose
own hex is the nearest land. The bands are narrower than REACH, so nothing a tile cannot know (hexes two steps away)
changes what it paints.
"""
import math

import lattice as LT
from tile_atlas import from_rgba

MARGIN = 34
C_W, C_H = LT.CELL_W + 2 * MARGIN, LT.CELL_H + 2 * MARGIN
REACH = 20.0                    # px of sea a tile paints out from its shore (the light band)
FOAM = 2.6
STYLES = ("beach", "cliff")
STRIP = {"beach": 5.0, "cliff": 3.0}
FACE = {"beach": 0.0, "cliff": 11.0}
SEA_BLEED = 2.5                 # the sea tile lies this far over the land's edge (flat_tiles.sea_tile): cover it
C_SAND = (234, 216, 162)
C_FOAM = (226, 242, 248)
C_LIGHT = (122, 192, 222)
C_SHELF = (83, 155, 201)        # flat_tiles.SEA_COL["shelf"]
C_STONE = (160, 148, 124)
BAY_HALF, BAY_BACK = 36.0, 20.0     # a carved port's bay: 72 px wide, its back 20 px south of the hex's middle

_WX = LT.Waves(11, [(1, 1), (2, -1), (3, 1), (1, -2), (4, 0), (5, 2), (7, -1)], 7.5)
_WY = LT.Waves(12, [(1, -1), (2, 1), (3, -1), (2, 2), (4, 1), (6, -1), (5, -2)], 6.5)
ROUND = 12.0                    # px: the radius of the ring the shore is averaged over (rounds the hex corners)
_RING = [(ROUND * math.cos(math.radians(a)), ROUND * math.sin(math.radians(a)) * LT.TILT) for a in range(0, 360, 60)]
INSIDE = 30.0                   # px inside the hex beyond which nothing of the coast shows


def _bay(x, y):
    """<= 0 inside the bay's water."""
    return max(abs(x) - BAY_HALF, BAY_BACK - y)


def coast_tile(mask, lv, style, bay=False):
    """mask: bit d set = the neighbour in direction d is sea (1 to 63). lv: the lattice variant of the cell."""
    sea = [LT.NEIGHBOUR[d] for d in range(6) if mask >> d & 1]
    land = [LT.NEIGHBOUR[d] for d in range(6) if not mask >> d & 1]
    vx, vy = LT.variant_centre(lv)
    ox, oy = C_W / 2.0, C_H / 2.0
    hex_h = LT.hex_h
    strip, face = STRIP[style], FACE[style]
    s_grid = [[99.0] * C_W for _ in range(C_H)]         # > 0 land (px to the shore), < 0 sea
    mine = [[False] * C_W for _ in range(C_H)]

    def field(wx, wy):
        """(s, this hex, the other land): s > 0 on land, < 0 at sea, about the px to the hex-edge shore."""
        h_a = hex_h(wx, wy)
        sea_d = 1e9
        for sx, sy in sea:
            v = hex_h(wx - sx, wy - sy)
            if v < sea_d:
                sea_d = v
        if bay:
            b = _bay(wx, wy)
            h_a = max(h_a, -b)
            sea_d = min(sea_d, b)
        other = 1e9
        for lx, ly in land:
            v = hex_h(wx - lx, wy - ly)
            if v < other:
                other = v
        return (sea_d - min(h_a, other)) / 2.0, h_a, other

    for y in range(C_H):
        py = y + 0.5 - oy
        srow, mrow = s_grid[y], mine[y]
        for x in range(C_W):
            px = x + 0.5 - ox
            if hex_h(px, py) < -INSIDE and not bay:
                mrow[x] = True
                continue                                 # well inside the land
            wx = px + _WX.at(px + vx, py + vy)
            wy = py + _WY.at(px + vx, py + vy)
            s, h_a, other = field(wx, wy)
            mrow[x] = h_a <= other + 0.5
            total = 2.0 * s
            for rx, ry in _RING:                         # the mean over a small ring rounds the hex corners off
                total += field(wx + rx, wy + ry)[0]
            srow[x] = total / 8.0
    buf = bytearray(C_W * C_H * 4)
    last_land = [-999] * C_W
    for y in range(C_H):
        py = y + 0.5 - oy
        for x in range(C_W):
            s = s_grid[y][x]
            if s > 0.0:
                last_land[x] = y
            if not mine[y][x]:
                continue
            px = x + 0.5 - ox
            raw_sea = 1e9                                # how far the pixel itself is from the sea hexes
            for sx, sy in sea:
                v = hex_h(px - sx, py - sy)
                if v < raw_sea:
                    raw_sea = v
            hsh = LT.pixel_hash(int(x + vx), int(y + vy))
            col = None
            alpha = 255
            if s > 0.0:
                if s < strip:
                    if style == "beach":
                        col = C_SAND
                    else:
                        col = (150, 138, 118) if hsh > 90 else (122, 112, 98)
                elif raw_sea <= SEA_BLEED:              # land the wobble pushed out over the sea tile
                    col = C_SAND if style == "beach" else C_STONE
            else:
                dy = y - last_land[x]
                d = -s
                if face > 0.0 and dy <= face:
                    if dy <= 1:
                        col = (70, 58, 50)
                    else:
                        wxi = int(x + vx)
                        hs = ((wxi * 2654435761) >> 7) & 31
                        k = 0.78 + 0.22 * (1 - dy / face)
                        col = ((150 + hs * 0.6) * k, (128 + hs * 0.5) * k, (104 + hs * 0.4) * k)
                        if (wxi // 3) & 3 == 0:
                            col = (col[0] * 0.86, col[1] * 0.86, col[2] * 0.86)
                elif (face > 0.0 and dy <= face + FOAM) or d < FOAM:
                    col = C_FOAM
                else:
                    t = max(0.0, 1.0 - d / REACH) * 0.85
                    if raw_sea > 0.0:                    # the pixel lies in a land hex: the sea must cover the ground
                        col = tuple(C_SHELF[i] + (C_LIGHT[i] - C_SHELF[i]) * t for i in range(3))
                    elif t > 0.0:
                        col = C_LIGHT
                        alpha = int(255 * t)
            if col is None or alpha <= 0:
                continue
            i = (y * C_W + x) * 4
            buf[i] = max(0, min(255, int(col[0])))
            buf[i + 1] = max(0, min(255, int(col[1])))
            buf[i + 2] = max(0, min(255, int(col[2])))
            buf[i + 3] = alpha
    return from_rgba(buf, (C_W, C_H))


def tile_name(mask, lv, style, bay=False):
    return "coast/%s/%d/%d%s" % (style, mask, lv, "/bay" if bay else "")


def bake_one(args):
    """Pool entry: (mask, lv, style, bay) -> (name, RGBA bytes)."""
    import pygame
    mask, lv, style, bay = args
    surf = coast_tile(mask, lv, style, bay)
    return tile_name(mask, lv, style, bay), pygame.image.tobytes(surf, "RGBA")
