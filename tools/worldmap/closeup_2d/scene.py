"""Geography for the 2D close-up of Genoa: the style frame's world, seen at hex radius 240.

The land, coast, towns, roads and ridges come from the style-frame generator (read only), so the view is the
same patch as the frame's 4x crop. Only the Genoa harbour bay is carved by hand.
"""
import math, os, sys, random

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "style_frame"))
import pygame
import render as SF            # builds WORLD, FIELDS, RELIEF, HILLS on import (no drawing)
from frame import (WORLD, TILT, X0, Y0, vnoise, smoothstep, chaikin, resample, mix, shade, lerp)
from geo import R_KM, W_KM, centre, corners, hex_of_km

FIELDS = SF.FIELDS
RELIEF = SF.RELIEF
HILLS = SF.HILLS

RPX = 240                       # hex radius of the close-up, in output pixels
SS = 2                          # supersampling: drawn at 2x, scaled down at the end
OUT_W, OUT_H = 1280, 720
W, H = OUT_W * SS, OUT_H * SS
S1 = RPX / R_KM                 # output px per km
S = S1 * SS                     # drawing px per km
# the same window as the frame's 4x crop (centre at 725,370 of the radius-60 frame)
VX = X0 + (725 * 4 - OUT_W / 2) / S1
VY = Y0 + (370 * 4 - OUT_H / 2) / (S1 * TILT)
VW_KM, VH_KM = OUT_W / S1, OUT_H / (S1 * TILT)


def P(x, y):
    """km -> drawing px on the ground plane."""
    return ((x - VX) * S, (y - VY) * S * TILT)


def K(px, py):
    """drawing px -> km."""
    return (VX + px / S, VY + py / (S * TILT))


GENOA = WORLD["towns"]["Genoa"]
SAVONA = WORLD["towns"]["Savona"]
CHIAVARI = WORLD["towns"]["Chiavari"]
GIOVI = WORLD["passes"]["Giovi"]

# ---------------------------------------------------------------- the coast
# Local changes to the frame's coast: ("sea" or "land", x, y, rx, ry) ellipses in km, applied in order. Set by build_coast.
MODS = []


def land_value(x, y):
    v = FIELDS.at(FIELDS.land, x, y)
    # small coves and points that only show at this zoom
    edge = max(0.0, 1 - abs(v - 0.5) * 5.0)
    v += ((vnoise(x, y, 1.3, 31) - 0.5) * 0.10 + (vnoise(x, y, 0.55, 32) - 0.5) * 0.05) * edge
    for (kind, hx, hy, rx, ry) in MODS:
        d = math.hypot((x - hx) / rx, (y - hy) / ry)
        if d < 2.5:
            if kind == "sea":
                v = min(v, 0.5 + (d - 1) * 0.6)
            else:
                v = max(v, 0.5 + (1 - d) * 0.6)
    return v


def is_land(x, y, margin=0.0):
    return land_value(x, y) > 0.5 + margin


def contours(fn, x0, y0, x1, y1, step, level=0.5):
    """Marching squares; returns closed loops."""
    nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
    g = [[-1.0] * (nx + 2) for _ in range(ny + 2)]
    for j in range(ny):
        for i in range(nx):
            g[j + 1][i + 1] = fn(x0 + i * step, y0 + j * step) - level
    segs = {}

    def ip(i, j, i2, j2):
        a, b = g[j][i], g[j2][i2]
        t = a / (a - b) if a != b else 0.5
        return (round(x0 + (i - 1 + (i2 - i) * t) * step, 4), round(y0 + (j - 1 + (j2 - j) * t) * step, 4))

    for j in range(ny + 1):
        for i in range(nx + 1):
            a, b, c, d = g[j][i] > 0, g[j][i + 1] > 0, g[j + 1][i + 1] > 0, g[j + 1][i] > 0
            code = a | (b << 1) | (c << 2) | (d << 3)
            if code in (0, 15):
                continue
            T, R, B, Lf = ip(i, j, i + 1, j), ip(i + 1, j, i + 1, j + 1), ip(i, j + 1, i + 1, j + 1), ip(i, j, i, j + 1)
            table = {1: [(Lf, T)], 2: [(T, R)], 3: [(Lf, R)], 4: [(R, B)], 5: [(Lf, T), (R, B)], 6: [(T, B)], 7: [(Lf, B)],
                     8: [(B, Lf)], 9: [(B, T)], 10: [(T, R), (B, Lf)], 11: [(B, R)], 12: [(R, Lf)], 13: [(R, T)], 14: [(T, Lf)]}
            for p, q in table[code]:
                segs[p] = q
    loops = []
    while segs:
        start, nxt = segs.popitem()
        loop = [start]
        while nxt != start and nxt in segs:
            loop.append(nxt)
            nxt = segs.pop(nxt)
        if len(loop) > 8:
            loops.append(loop)
    return loops


def build_coast(mods):
    """Returns the land loops in km (closed, smoothed)."""
    MODS[:] = mods
    m = 6
    loops = contours(land_value, VX - m, VY - m, VX + VW_KM + m, VY + VH_KM + m, 0.4)
    return [chaikin(lp, 2, closed=True) for lp in loops]


def poly_area(pts):
    a = 0.0
    for i in range(len(pts)):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % len(pts)]
        a += x0 * y1 - x1 * y0
    return a / 2


def in_poly(x, y, poly):
    c = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
        j = i
    return c


class PGrid:
    """Spatial hash in drawing px, for keep-clear tests."""
    def __init__(self, cell=64):
        self.cell, self.d = cell, {}

    def add(self, x, y, r=0.0):
        self.d.setdefault((int(x // self.cell), int(y // self.cell)), []).append((x, y, r))

    def add_line(self, pts, r, step=12):
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            n = max(1, int(math.dist(a, b) / step))
            for q in range(n + 1):
                self.add(a[0] + (b[0] - a[0]) * q / n, a[1] + (b[1] - a[1]) * q / n, r)

    def clear(self, x, y, r=0.0, reach=3):
        """True when no stored point lies within its radius + r."""
        cx, cy = int(x // self.cell), int(y // self.cell)
        for i in range(cx - reach, cx + reach + 1):
            for j in range(cy - reach, cy + reach + 1):
                for px, py, pr in self.d.get((i, j), ()):
                    if (px - x) ** 2 + (py - y) ** 2 < (pr + r) ** 2:
                        return False
        return True
