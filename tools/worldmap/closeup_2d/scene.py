"""Geography for the 2D close-up of Genoa: the style frame's world, seen at hex radius 240.

The land, coast, roads, the torrent and the ridges come from the style-frame generator (read only), so the view is
the same patch as the frame's 4x crop. The rule of this zoom is "one city, one hex, drawn inside it": every settlement
stands inside its own 28 km hex (see stages.DISTRICTS), and the helpers below say which hex a point lies in and how
far it is from the border. The coast is the frame's first line (FIELDS.land0); the only local changes are three small
harbour coves (COAST_MODS), each within COAST_REACH_KM of that line. The frame now follows the same rule and cuts the
same coves (style_frame/sites.py), so its own coast, roads and town sites (frame_land, FRAME_ROADS, FRAME_SITES)
coincide with the close-up's; agreement() measures how well.
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

# ---------------------------------------------------------------- the hexes of the normal map
APOTHEM = W_KM / 2.0            # centre to border, km


def hex_at(x, y):
    """The hex (column, row) under a point in drawing px."""
    return hex_of_km(*K(x, y))


def hex_margin(x, y, hx=None):
    """How far (km) a point in drawing px lies inside hex hx (its own hex when not given); negative when outside."""
    kx, ky = K(x, y)
    if hx is None:
        hx = hex_of_km(kx, ky)
    cx, cy = centre(*hx)
    dx, dy = abs(kx - cx), abs(ky - cy)
    return APOTHEM - max(dx, dx * 0.5 + dy * 0.8660254)


def in_hex(x, y, hx, margin=1.0):
    """True when the point (drawing px) lies in hex hx, at least margin km from its border."""
    return hex_margin(x, y, hx) >= margin


def hex_px(hx):
    return [P(*p) for p in corners(*hx)]


def frame_line(pts):
    """A line of the normal map (km) in drawing px, cut to the view."""
    out = [P(*p) for p in pts]
    return [p for p in out if -260 < p[0] < W + 260 and -260 < p[1] < H + 260]


FRAME_ROADS = [frame_line(rd["pts"]) for rd in WORLD["roads"]]
FRAME_ROADS = [ln for ln in FRAME_ROADS if len(ln) > 1]
FRAME_STREAMS = [ln for ln in (frame_line(st) for st in WORLD["streams"]) if len(ln) > 1]
# the normal map's town sites and pass in view: name -> drawing px
FRAME_SITES = {t["name"]: P(t["x"], t["y"]) for t in list(WORLD["towns"].values()) + list(WORLD["passes"].values())
               if -100 < P(t["x"], t["y"])[0] < W + 100 and -100 < P(t["x"], t["y"])[1] < H + 100}

# ---------------------------------------------------------------- the coast
COAST_REACH_KM = 3.5            # no local change moves the shore further than this from the frame's line
# Local changes to the frame's coast: ("sea" or "land", x, y, rx, ry) ellipses in km, applied in order. Set by build_coast.
MODS = []


def frame_land(x, y):
    """The normal map's own land value (the frame's coast, with its harbour coves, is its 0.5 line)."""
    return FIELDS.at(FIELDS.land, x, y)


def first_land(x, y):
    """The normal map's land value before any harbour cove: the line the coves are measured from."""
    return FIELDS.at(FIELDS.land0, x, y)


def land_value(x, y):
    v = FIELDS.at(FIELDS.land0, x, y)
    # small coves and points that only show at this zoom (they move the shore by a few hundred metres at most)
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


def coast_drift(loops, step=4, frame_land=None):
    """The largest distance (km) from the close-up's shore to the normal map's first shore, and where (km).
    With frame_land given, the distance to that land field instead (the frame's coast with its coves)."""
    frame_land = frame_land or first_land
    worst, at = 0.0, None
    for lp in loops:
        for x, y in lp[::step]:
            if not (VX < x < VX + VW_KM and VY < y < VY + VH_KM):
                continue
            inside = frame_land(x, y) > 0.5
            d = 0.0
            found = False
            while d < 8.0 and not found:
                d += 0.25
                for a in range(0, 360, 20):
                    if (frame_land(x + math.cos(math.radians(a)) * d, y + math.sin(math.radians(a)) * d) > 0.5) != inside:
                        found = True
                        break
            if d > worst:
                worst, at = d, (x, y)
    return worst, at


def line_gap(a, b, step=1.0):
    """The largest distance from a point of polyline a to polyline b (both in km)."""
    def seg_d(p, q0, q1):
        dx, dy = q1[0] - q0[0], q1[1] - q0[1]
        n = dx * dx + dy * dy
        t = 0.0 if n == 0 else max(0.0, min(1.0, ((p[0] - q0[0]) * dx + (p[1] - q0[1]) * dy) / n))
        return math.hypot(p[0] - q0[0] - dx * t, p[1] - q0[1] - dy * t)
    worst = 0.0
    for p in resample(a, step):
        worst = max(worst, min(seg_d(p, b[i], b[i + 1]) for i in range(len(b) - 1)))
    return worst


def agreement(loops, close_roads, close_sites):
    """How far the normal map (the style frame) lies from the close-up, in km, inside the close-up's view.
    close_roads: the close-up's road lines in km; close_sites: name -> (x, y) in km of its towns and pass.
    Returns lines of text."""
    out = []
    drift, at = coast_drift(loops, frame_land=frame_land)
    out.append("coast: the two shores lie at most %.1f km apart (the map draws its coast on a 1 km grid)" % drift)
    def in_view(p):
        return VX < p[0] < VX + VW_KM and VY < p[1] < VY + VH_KM
    allc = [resample(chaikin(ln, 3), 0.3) for ln in close_roads]
    worst = 0.0
    for rd in WORLD["roads"]:
        pts = [p for p in rd["pts"] if in_view(p)]
        for p in pts:
            worst = max(worst, min(math.dist(p, q) for ln in allc for q in ln))
    out.append("roads: every road of the map in view lies within %.2f km of a road of the close-up" % worst)
    for name, (x, y) in sorted(close_sites.items()):
        t = WORLD["towns"].get(name) or WORLD["passes"].get(name)
        out.append("%s: map site %.1f km from the close-up's, hex %s on both" % (name, math.hypot(t["x"] - x, t["y"] - y), hex_of_km(x, y))
                   if hex_of_km(x, y) == hex_of_km(t["x"], t["y"]) else
                   "%s: DIFFERENT HEX, map %s, close-up %s" % (name, hex_of_km(t["x"], t["y"]), hex_of_km(x, y)))
    return out


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
