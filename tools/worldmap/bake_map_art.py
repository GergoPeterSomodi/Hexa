"""Bake the art of the new world map (map prototype, step 6 part A) into godot/assets/worldmap/.

    python -m tools.worldmap.bake_map_art                      bake everything into godot/assets/worldmap/
    python -m tools.worldmap.bake_map_art --out DIR            somewhere else
    python -m tools.worldmap.bake_map_art --sheets DIR         also write one contact sheet per group into DIR

Everything is drawn in code with pygame, in direction A (docs/design/godot-look/README.md): flat two-tone shading lit
from the upper left, 1-2 px ink outlines. The trees, peaks, hills, rocks, reeds and a few landmarks are the Python
game's own objects (hexa/campaign/nature.py and life.py), drawn here at the new map's sizes; hexa/ is read only. The
crests, passes, cliffs, coasts, towns, castles, bridges, ports, fields, arms and the ground textures are new.

The output is reproducible: the same pygame build writes the same bytes on every run (all randomness is seeded from
names, every list is sorted). godot/assets/worldmap/README.md documents the index.json contract.
"""
import argparse
import hashlib
import json
import math
import os
import random
import sys
import zlib

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

import pygame  # noqa: E402

pygame.init()

from hexa.campaign import life, nature  # noqa: E402

OUT_DIR = os.path.join(ROOT, "godot", "assets", "worldmap")
FORMAT = "hexa-worldmap-art/1"
BASE_R = 60.0                  # every piece is drawn for a hex radius of 60 px (the closest zoom)
SQ3 = math.sqrt(3.0)
K = 3                          # supersampling of the new pieces
PAGE_W = 2048
PAD = 2                        # transparent gap round every sprite in an atlas page
TEX = 256                      # ground textures: 256 x 256, tileable

INK = (38, 36, 42)
SNOW = (240, 244, 250)


def rng_for(*key):
    return random.Random(zlib.crc32("|".join(str(k) for k in key).encode()))


def shade(c, k):
    """k > 0 lightens towards white, k < 0 darkens."""
    return tuple(max(0, min(255, int(round(v + (255 - v) * k if k > 0 else v * (1 + k))))) for v in c[:3])


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# ================================================================================================ the pen
class Pen:
    """A supersampled canvas in final pixels with its origin on the anchor. poly/oval draw filled shapes with an ink
    edge (ink=width in final px, 0 for none). finish() scales down and trims; the anchor follows the trim."""

    def __init__(self, w, h, ax, ay, k=K):
        self.w, self.h, self.ax, self.ay, self.k = w, h, ax, ay, k
        self.surf = pygame.Surface((w * k, h * k), pygame.SRCALPHA)

    def P(self, x, y):
        return ((x + self.ax) * self.k, (y + self.ay) * self.k)

    def poly(self, col, pts, ink=1.0, ink_col=INK):
        if len(pts) < 3:
            return
        q = [self.P(x, y) for x, y in pts]
        pygame.draw.polygon(self.surf, col, q)
        if ink:
            pygame.draw.polygon(self.surf, ink_col, q, max(1, round(ink * self.k)))

    def oval(self, col, x, y, rx, ry, ink=1.0, ink_col=INK):
        cx, cy = self.P(x, y)
        rect = pygame.Rect(round(cx - rx * self.k), round(cy - ry * self.k), max(1, round(2 * rx * self.k)),
                           max(1, round(2 * ry * self.k)))
        pygame.draw.ellipse(self.surf, col, rect)
        if ink:
            pygame.draw.ellipse(self.surf, ink_col, rect, max(1, round(ink * self.k)))

    def line(self, col, a, b, w=1.0):
        pygame.draw.line(self.surf, col, self.P(*a), self.P(*b), max(1, round(w * self.k)))

    def lines(self, col, pts, w=1.0, closed=False):
        if len(pts) > 1:
            pygame.draw.lines(self.surf, col, closed, [self.P(x, y) for x, y in pts], max(1, round(w * self.k)))

    def dot(self, col, x, y, r):
        pygame.draw.circle(self.surf, col, self.P(x, y), max(1, round(r * self.k)))

    def soft(self, rgba, x, y, rx, ry):
        """A soft translucent ellipse (shadows, calm patches): not outlined."""
        tmp = pygame.Surface(self.surf.get_size(), pygame.SRCALPHA)
        cx, cy = self.P(x, y)
        pygame.draw.ellipse(tmp, rgba, pygame.Rect(round(cx - rx * self.k), round(cy - ry * self.k),
                                                   round(2 * rx * self.k), round(2 * ry * self.k)))
        self.surf.blit(tmp, (0, 0))

    def tt(self, base, pts, split_x=0.0, lit=0.14, dark=-0.28, ink=1.0):
        """Two-tone polygon: lit left of split_x, shaded right of it, one ink edge round the whole."""
        left = clip_poly(pts, lambda x, y: split_x - x)
        right = clip_poly(pts, lambda x, y: x - split_x)
        if len(left) > 2:
            self.poly(shade(base, lit), left, 0)
        if len(right) > 2:
            self.poly(shade(base, dark), right, 0)
        if ink:
            q = [self.P(x, y) for x, y in pts]
            pygame.draw.polygon(self.surf, INK, q, max(1, round(ink * self.k)))

    def finish(self, outline=0.0):
        surf = self.surf
        if outline:
            out = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
            sil = pygame.mask.from_surface(surf, 60).to_surface(setcolor=INK + (255,), unsetcolor=(0, 0, 0, 0))
            r = outline * self.k
            for a in range(8):
                ang = a * math.pi / 4
                out.blit(sil, (round(r * math.cos(ang)), round(r * math.sin(ang))))
            out.blit(surf, (0, 0))
            surf = out
        small = pygame.transform.smoothscale(surf, (self.w, self.h))
        return trim(small, (self.ax, self.ay))


def trim(surf, anchor):
    r = surf.get_bounding_rect(1)
    if r.w == 0:
        r = pygame.Rect(0, 0, 1, 1)
    out = pygame.Surface(r.size, pygame.SRCALPHA)
    out.blit(surf, (0, 0), r)
    return out, (round(anchor[0] - r.x, 2), round(anchor[1] - r.y, 2))


def clip_poly(pts, f):
    """Keep the part of a polygon where f(x, y) >= 0 (Sutherland-Hodgman against one half plane)."""
    out = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        fa, fb = f(*a), f(*b)
        if fa >= 0:
            out.append(a)
        if (fa >= 0) != (fb >= 0):
            t = fa / (fa - fb)
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


# ================================================================================================ registry
class Bake:
    def __init__(self):
        self.pieces = {}        # name -> dict(surf, anchor, group, layer, rotate, meta)
        self.textures = {}      # name -> dict(surf, file, meta)

    def add(self, name, surf_anchor, group, layer, rotate=False, **meta):
        assert name not in self.pieces, name
        surf, anchor = surf_anchor
        self.pieces[name] = dict(surf=surf, anchor=anchor, group=group, layer=layer, rotate=rotate, meta=meta)

    def tex(self, name, surf, file, **meta):
        self.textures[name] = dict(surf=surf, file=file, meta=meta)


# ================================================================================================ ground
COVERS = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]   # WorldCover order
COVER_BASE = {
    "farmland": (190, 196, 112),
    "grassland": (150, 192, 92),
    "woods": (104, 150, 80),
    "marsh": (132, 160, 118),
    "rock": (166, 158, 144),
    "snow": (238, 243, 249),
    "tundra": (178, 180, 150),
    "sand": (232, 214, 162),
}
# multiply tints by relief level (index = level 0..6; 0 is the sea and unused): hills a shade darker and warmer
LEVEL_TINT = [
    [1.0, 1.0, 1.0], [1.03, 1.03, 1.0], [1.0, 1.0, 1.0], [0.95, 0.93, 0.87], [0.90, 0.89, 0.84],
    [0.88, 0.88, 0.88], [0.95, 0.97, 1.0],
]


def tile_values(size, cells, seed, lo=0, hi=255):
    """Tileable value noise as a list of rows: a random cells x cells lattice that wraps, smoothstep-interpolated."""
    rng = rng_for("noise", size, cells, seed)
    grid = [[rng.uniform(lo, hi) for _ in range(cells)] for _ in range(cells)]
    step = size / cells
    fade = [0.0] * size
    idx = [0] * size
    for p in range(size):
        f = p / step
        i = int(f)
        t = f - i
        fade[p] = t * t * (3 - 2 * t)
        idx[p] = i % cells
    rows = []
    for y in range(size):
        j0 = idx[y]
        j1 = (j0 + 1) % cells
        ty = fade[y]
        g0, g1 = grid[j0], grid[j1]
        row = []
        for x in range(size):
            i0 = idx[x]
            i1 = (i0 + 1) % cells
            tx = fade[x]
            a = g0[i0] + (g0[i1] - g0[i0]) * tx
            b = g1[i0] + (g1[i1] - g1[i0]) * tx
            row.append(a + (b - a) * ty)
        rows.append(row)
    return rows


def wrap_draw(surf, fn, x, y, margin=24):
    """Draw at (x, y) and at its wrapped copies near the borders, so the texture tiles."""
    s = surf.get_width()
    for dx in (-s, 0, s):
        for dy in (-s, 0, s):
            if -margin <= x + dx <= s + margin and -margin <= y + dy <= s + margin:
                fn(x + dx, y + dy)


def tinted_base(cover, amp):
    base = COVER_BASE[cover]
    surf = pygame.Surface((TEX, TEX))
    surf.fill(base)
    # low-frequency light and dark patches, two octaves, applied as a soft overlay
    for cells, a in ((4, amp), (9, amp * 0.6)):
        n = tile_values(TEX, cells, cover + str(cells))
        light = pygame.Surface((TEX, TEX), pygame.SRCALPHA)
        dark = pygame.Surface((TEX, TEX), pygame.SRCALPHA)
        for y in range(0, TEX):
            for x in range(0, TEX):
                v = n[y][x] - 128
                if v > 0:
                    light.set_at((x, y), (255, 255, 230, min(255, int(v * a))))
                else:
                    dark.set_at((x, y), (30, 40, 20, min(255, int(-v * a))))
        surf.blit(light, (0, 0))
        surf.blit(dark, (0, 0))
    return surf


def ground_texture(cover):
    rng = rng_for("ground", cover)
    amp = {"snow": 0.10, "sand": 0.16, "rock": 0.26, "woods": 0.22}.get(cover, 0.2)
    surf = tinted_base(cover, amp)
    base = COVER_BASE[cover]
    marks = pygame.Surface((TEX, TEX), pygame.SRCALPHA)

    def blob(col, rx, ry):
        def f(x, y):
            pygame.draw.ellipse(marks, col, pygame.Rect(round(x - rx), round(y - ry), round(2 * rx), round(2 * ry)))
        return f

    def stroke(col, pts, w):
        def f(x, y):
            pygame.draw.lines(marks, col, False, [(x + px, y + py) for px, py in pts], w)
        return f

    def place(n, fn_factory):
        for _ in range(n):
            x, y = rng.uniform(0, TEX), rng.uniform(0, TEX)
            wrap_draw(marks, fn_factory(), x, y)

    d1 = shade(base, -0.22) + (150,)
    d2 = shade(base, -0.35) + (110,)
    l1 = shade(base, 0.25) + (130,)
    if cover in ("grassland", "farmland"):
        place(170, lambda: stroke(d1, [(-2, 0), (0, -3), (2, 0)], 1))
        place(90, lambda: blob(l1, rng.uniform(1, 2), rng.uniform(0.8, 1.5)))
        if cover == "farmland":
            place(40, lambda: stroke(shade((176, 150, 90), -0.1) + (90,), [(-5, 0), (5, 0)], 1))
    elif cover == "woods":
        place(70, lambda: blob(d2, rng.uniform(3, 7), rng.uniform(2, 4)))
        place(200, lambda: blob(d1, rng.uniform(0.8, 1.6), rng.uniform(0.8, 1.4)))
        place(80, lambda: blob(l1, 1.2, 1.0))
    elif cover == "marsh":
        water = (112, 152, 166)
        for _ in range(16):
            x, y = rng.uniform(0, TEX), rng.uniform(0, TEX)
            rx, ry = rng.uniform(5, 11), rng.uniform(2.5, 4.5)
            wrap_draw(marks, blob(shade(water, -0.15) + (200,), rx + 1, ry + 1), x, y)
            wrap_draw(marks, blob(water + (220,), rx, ry), x, y)
            wrap_draw(marks, blob(shade(water, 0.3) + (150,), rx * 0.4, ry * 0.3), x - rx * 0.3, y - ry * 0.3)
        place(160, lambda: stroke(shade((98, 132, 70), 0) + (170,), [(0, 0), (rng.uniform(-1, 1), -4)], 1))
    elif cover == "rock":
        place(60, lambda: stroke(d2, [(0, 0), (rng.uniform(-4, 4), rng.uniform(2, 5)),
                                      (rng.uniform(-6, 6), rng.uniform(5, 9))], 1))
        place(140, lambda: blob(d1, rng.uniform(0.8, 2), rng.uniform(0.6, 1.4)))
        place(60, lambda: blob(l1, rng.uniform(1.5, 3), rng.uniform(1, 2)))
    elif cover == "snow":
        place(40, lambda: blob((200, 214, 236, 70), rng.uniform(6, 14), rng.uniform(2, 4)))
        place(90, lambda: blob((255, 255, 255, 160), 1, 1))
    elif cover == "tundra":
        place(120, lambda: blob((150, 150, 100, 120), rng.uniform(1, 2.5), rng.uniform(1, 2)))
        place(50, lambda: blob((196, 160, 96, 110), rng.uniform(1, 2), rng.uniform(1, 1.6)))
        place(50, lambda: blob((140, 136, 128, 140), 1.2, 0.9))
    elif cover == "sand":
        place(70, lambda: stroke(shade(base, -0.12) + (110,), [(-5, 0), (-2, -1), (2, -1), (5, 0)], 1))
        place(160, lambda: blob(d1, 0.8, 0.8))
    surf.blit(marks, (0, 0))
    return surf


def noise_texture():
    """R: broad noise (4 cells), G: middle (12), B: fine (32); tileable. The blend shader wobbles edges with it."""
    out = pygame.Surface((TEX, TEX))
    chans = [tile_values(TEX, c, "blend" + str(c), 10, 245) for c in (4, 12, 32)]
    for y in range(TEX):
        for x in range(TEX):
            out.set_at((x, y), (int(chans[0][y][x]), int(chans[1][y][x]), int(chans[2][y][x])))
    return out


def strip_textures(b):
    """Line textures (tile along x; y is across the line), white so the renderer tints them."""
    # border band: opaque at the border (y = 0), fading inwards
    band = pygame.Surface((64, 32), pygame.SRCALPHA)
    for y in range(32):
        t = y / 31
        a = int(255 * (1 - t) ** 1.6)
        pygame.draw.line(band, (255, 255, 255, a), (0, y), (63, y))
    b.tex("strip.border_band", band, "strip_border_band.png", tile="x", note="alpha 1 at the border edge, 0 inside")
    dash = pygame.Surface((32, 4), pygame.SRCALPHA)
    pygame.draw.rect(dash, (255, 255, 255, 255), pygame.Rect(0, 0, 18, 4))
    b.tex("strip.border_dash", dash, "strip_border_dash.png", tile="x", note="neutral border of other countries")
    foam = pygame.Surface((64, 8), pygame.SRCALPHA)
    pts = [(x, 3.5 + 1.6 * math.sin(x / 64 * 4 * math.pi)) for x in range(0, 65)]
    pygame.draw.lines(foam, (255, 255, 255, 235), False, pts, 2)
    for x in range(0, 64, 8):
        pygame.draw.circle(foam, (255, 255, 255, 140), (x + 4, round(6.5 + math.sin(x) * 0.5)), 1)
    b.tex("strip.foam", foam, "strip_foam.png", tile="x", note="the foam line just off the shore")
    track = pygame.Surface((32, 8), pygame.SRCALPHA)
    pygame.draw.rect(track, (255, 255, 255, 255), pygame.Rect(0, 2, 20, 4))
    b.tex("strip.track", track, "strip_track.png", tile="x", note="road quality 1 (track): a dashed line")


# ================================================================================================ reused objects
NATURE_GROUPS = {
    # family: [(object, [(size key, target width in px at r 60), ...])]
    "broadleaf": [("oak", [("s", 20), ("m", 26), ("l", 32)]), ("beech", [("s", 20), ("m", 26), ("l", 32)]),
                  ("linden", [("m", 26)]), ("birch", [("s", 16), ("m", 20)])],
    "conifer": [("pine_short", [("m", 18), ("l", 22)]),
                ("fir_tall", [("s", 13), ("m", 17), ("l", 21)]), ("fir_short", [("m", 17)])],
    "conifer_snow": [("snowy_tall", [("m", 17), ("l", 21)]), ("snowy_short", [("m", 17)])],
    "southern": [("cypress", [("m", 10), ("l", 13)]), ("umbrella", [("m", 26)]), ("olive", [("m", 22)])],
    "shrub": [("shrub", [("s", 12), ("m", 16)])],
    "peak_high": [("snow_peak", [("m", 56), ("l", 70)])],
    "peak_rocky": [],
    "peak_low": [("foothills", [("m", 50), ("l", 62)]), ("old_mountain", [("m", 50), ("l", 60)])],
    "hill": [("hill_green", [("m", 42), ("l", 52)]), ("hill_dry", [("m", 42)]), ("hill_terraced", [("m", 44)]),
             ("outcrop", [("m", 28)])],
    "rock": [("stone", [("m", 9)]), ("boulder", [("m", 13)])],
}
NATURE_SEEDS = 4


def nature_object(name, target_w, seed, ink2x):
    """A nature.py object drawn at the width wanted (not one of its three fixed sizes). The shapes are the same as the
    game's 'medium' object of that seed; the outline is ink2x half-pixels."""
    build, w, h, shadow = nature._BUILD[name]
    nature.SIZE_SCALE["bake"] = target_w / w
    c = nature.Canvas(w, h, "bake")
    c.ink = ink2x
    rng = random.Random(zlib.crc32(f"{name}|medium|{seed}".encode()))
    build(c, rng)
    surf = c.finish(shadow)
    small = pygame.transform.smoothscale(surf, (c.fw, c.fh))
    return trim(small, (c.fw / 2, c.fh))


def life_object(name, target_w, seed, base_w):
    life.SIZES["bake"] = target_w / base_w
    surf = getattr(life, name)("bake", seed)
    w, h = surf.get_size()
    return trim(surf, (w / 2, h - 1))


def bake_nature(b):
    for family, items in NATURE_GROUPS.items():
        for name, sizes in items:
            for skey, tw in sizes:
                seeds = NATURE_SEEDS if family in ("broadleaf", "conifer", "conifer_snow", "southern", "shrub") else 2
                for seed in range(seeds):
                    ink = 3 if tw >= 40 else 2
                    b.add(f"scatter.{family}.{name}.{skey}.v{seed}", nature_object(name, tw, seed, ink), "scatter",
                          "upright", width_px=tw)
    for skey, scale in (("m", 1.0), ("l", 1.25)):
        for v in range(3):
            b.add(f"scatter.peak_rocky.range.{skey}.v{v}", rock_range(scale, v), "scatter", "upright")
            b.add(f"scatter.peak_high.range.{skey}.v{v}", rock_range(scale * 1.15, v, snow=True), "scatter",
                  "upright")
    for name, tw, base_w, seeds in (("reeds", 18, 26, 4), ("cattails", 16, 24, 3), ("lily_pond", 22, 40, 2)):
        for seed in range(seeds):
            b.add(f"scatter.marsh.{name}.m.v{seed}", life_object(name, tw, seed, base_w), "scatter", "upright")
    for name, tw, base_w in (("monastery", 54, 72), ("lighthouse", 34, 64), ("windmill_post", 24, 46),
                             ("wayside_cross", 10, 22), ("fishing_boat", 20, 34), ("sea_rocks", 22, 40)):
        b.add(f"site.reuse.{name}.v0", life_object(name, tw, 0, base_w), "sites", "upright")


RANGE_ROCK = [(150, 140, 128), (140, 134, 130), (158, 146, 126)]


def rock_range(scale, v, snow=False):
    """A rocky range group (the 'rocky ranges' of the close-up 07): two or three bare grey-brown peaks, paler than the
    crest chain so the crest still reads as the line on top."""
    rng = rng_for("range", scale, v)
    pen = Pen(110, 90, 55, 80)
    base = RANGE_ROCK[v % 3]
    layout = [[(-10, -3, 30, 34), (9, 0, 26, 26)], [(-12, 0, 26, 27), (4, -4, 30, 38), (16, 1, 20, 20)],
              [(-6, -2, 32, 32), (12, 1, 22, 22)]][v % 3]
    for x, y, w, h in sorted(layout, key=lambda p: p[1]):
        peak(pen, x * scale, y * scale, w * scale, h * scale, base, rng, snow, snow_frac=0.4)
    return pen.finish()


# ================================================================================================ fields and decals
FIELD_STYLES = {
    "grain": (226, 196, 92), "barley": (232, 216, 132), "green": (126, 172, 78), "ploughed": (164, 122, 80),
    "meadow": (160, 198, 104), "vines": (198, 184, 128), "orchard": (150, 186, 96), "terrace": (176, 182, 104),
}


def field_parcel(style, v):
    rng = rng_for("parcel", style, v)
    w = rng.choice((24, 26, 28)) if style != "terrace" else 28
    h = rng.choice((14, 15, 17)) if style != "terrace" else 18
    pen = Pen(w + 4, h + 4, (w + 4) / 2, (h + 4) / 2)
    base = FIELD_STYLES[style]
    base = shade(base, rng.uniform(-0.06, 0.06))
    x0, y0, x1, y1 = -w / 2, -h / 2, w / 2, h / 2
    # slightly irregular corners, so parcels do not look stamped
    j = lambda: rng.uniform(-0.8, 0.8)  # noqa: E731
    quad = [(x0 + j(), y0 + j()), (x1 + j(), y0 + j()), (x1 + j(), y1 + j()), (x0 + j(), y1 + j())]
    pen.poly(base, quad, ink=0.6, ink_col=shade(base, -0.38))
    dk = shade(base, -0.18)
    if style in ("grain", "barley", "green"):
        for i in range(1, 5):
            y = y0 + h * i / 5
            pen.line(dk, (x0 + 1.5, y), (x1 - 1.5, y), 0.5)
    elif style == "ploughed":
        for i in range(1, 7):
            x = x0 + w * i / 7
            pen.line(shade(base, -0.25), (x, y0 + 1.5), (x, y1 - 1.5), 0.6)
    elif style == "vines":
        for i in range(1, 4):
            y = y0 + h * i / 4
            for k in range(6):
                pen.dot((92, 128, 58), x0 + 2.5 + k * (w - 5) / 5, y, 0.9)
    elif style == "orchard":
        for i in range(2):
            for k in range(4):
                x, y = x0 + 3.5 + k * (w - 7) / 3, y0 + 4 + i * (h - 8)
                pen.oval((78, 128, 58), x, y, 2.0, 1.8, ink=0.4)
                pen.dot((120, 170, 84), x - 0.6, y - 0.6, 0.8)
    elif style == "terrace":
        for i in range(1, 4):
            y = y0 + h * i / 4
            pen.line(shade(base, -0.35), (x0 + 1, y), (x1 - 1, y), 0.7)
            pen.line(shade(base, 0.25), (x0 + 1, y + 0.8), (x1 - 1, y + 0.8), 0.5)
    elif style == "meadow":
        for _ in range(6):
            x, y = rng.uniform(x0 + 2, x1 - 2), rng.uniform(y0 + 2, y1 - 2)
            pen.line(dk, (x - 1, y), (x, y - 1.5), 0.5)
    return pen.finish()


def haystack(v):
    pen = Pen(12, 12, 6, 10)
    col = (226, 190, 96)
    pen.tt(col, [(-4, 0), (-3.4, -3), (-1.5, -5.6), (0, -6), (1.5, -5.6), (3.4, -3), (4, 0)])
    return pen.finish()


def marsh_pool(v):
    rng = rng_for("pool", v)
    rx, ry = rng.uniform(8, 12), rng.uniform(3.5, 5)
    pen = Pen(30, 14, 15, 7)
    pen.oval((150, 176, 128), 0, 0, rx + 1.5, ry + 1.2, ink=0)
    pen.oval((96, 140, 160), 0, 0, rx, ry, ink=0.6, ink_col=(70, 100, 110))
    pen.oval((150, 190, 204), -rx * 0.3, -ry * 0.3, rx * 0.35, ry * 0.25, ink=0)
    return pen.finish()


def calm_patch():
    """A soft pale patch the renderer lays under towns, castles and armies (the owner's 'calmer ground')."""
    w, h = 128, 76
    surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(24, 0, -1):
        t = i / 24
        a = int(70 * (1 - t) ** 1.2)
        rect = pygame.Rect(0, 0, round(w * t), round(h * t))
        rect.center = (w // 2, h // 2)
        pygame.draw.ellipse(surf, (255, 255, 255, a), rect)
    return surf, (w / 2, h / 2)


def bake_fields(b):
    for style in FIELD_STYLES:
        for v in range(3):
            b.add(f"field.parcel.{style}.v{v}", field_parcel(style, v), "scatter", "flat", rotate=True)
    b.add("field.haystack.v0", haystack(0), "scatter", "upright")
    for v in range(3):
        b.add(f"scatter.marsh.pool.v{v}", marsh_pool(v), "scatter", "flat", rotate=True)
    b.add("site.calm", calm_patch(), "scatter", "flat", tint=True)


# ================================================================================================ relief edge pieces
def edge_geometry(d, r=BASE_R):
    """Corners of edge direction d (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE) relative to the edge midpoint, and the outward
    normal. Corner k sits at angle -90 + 60k degrees (WorldGrid.EDGE_CORNERS)."""
    pairs = [(1, 2), (0, 1), (5, 0), (4, 5), (3, 4), (2, 3)]
    a, c = pairs[d]
    ca = (r * math.cos(math.radians(-90 + 60 * a)), r * math.sin(math.radians(-90 + 60 * a)))
    cb = (r * math.cos(math.radians(-90 + 60 * c)), r * math.sin(math.radians(-90 + 60 * c)))
    mid = ((ca[0] + cb[0]) / 2, (ca[1] + cb[1]) / 2)
    ang = math.radians(-60 * d)
    n = (math.cos(ang), math.sin(ang))
    return (ca[0] - mid[0], ca[1] - mid[1]), (cb[0] - mid[0], cb[1] - mid[1]), n


ORIENT = {"e": 0, "ne": 1, "nw": 2}        # the three edge orientations a hex owns; W, SW, SE use the same pieces
CREST_ROCK = (112, 104, 108)
CREST_ROCK_B = (128, 116, 104)


def peak(pen, x, y, w, h, base, rng, snow, snow_frac=0.42, sharp=True):
    """One crest peak with its feet at (x, y): a sharp profile, two-tone along its summit, a ragged snow tip."""
    top = (x + rng.uniform(-w * 0.08, w * 0.08), y - h)
    sh1 = (x - w * 0.28, y - h * rng.uniform(0.45, 0.6))
    sh2 = (x + w * 0.3, y - h * rng.uniform(0.4, 0.55))
    prof = [(x - w / 2, y), sh1, (x - w * 0.12, y - h * 0.8), top, (x + w * 0.1, y - h * 0.82), sh2, (x + w / 2, y)]
    pen.tt(base, prof, split_x=top[0], lit=0.18, dark=-0.32, ink=1.2)
    # a dark gully from the summit
    pen.line(shade(base, -0.45), (top[0] + 1, top[1] + h * 0.2), (top[0] + w * 0.12, y - h * 0.25), 0.8)
    if snow:
        sy = y - h * (1 - snow_frac)
        cap = clip_poly(prof, lambda px, py: sy - py)
        if len(cap) > 2:
            # ragged lower edge: replace the straight cut with a zigzag
            pen.poly(SNOW, cap, 0)
            right = clip_poly(cap, lambda px, py: px - top[0])
            if len(right) > 2:
                pen.poly(shade(SNOW, -0.16), right, 0)
            xs = sorted(p[0] for p in cap if abs(p[1] - sy) < 0.01)
            if len(xs) >= 2:
                zig = []
                for k in range(7):
                    t = k / 6
                    zig.append((xs[0] + (xs[-1] - xs[0]) * t, sy + (2.2 if k % 2 else 0.0)))
                pen.poly(SNOW, zig + [(xs[-1], sy - 0.5), (xs[0], sy - 0.5)], 0)
            pen.lines(INK, [p for p in prof], 1.2)
    else:
        # a lighter rock tip
        cap = clip_poly(prof, lambda px, py: (y - h * 0.72) - py)
        if len(cap) > 2:
            pen.poly(shade(base, 0.32), clip_poly(cap, lambda px, py: top[0] - px) or cap, 0)
            pen.lines(INK, prof, 1.2)


def crest_piece(orient, snow, v):
    d = ORIENT[orient]
    a, c, n = edge_geometry(d)
    rng = rng_for("crest", orient, snow, v)
    pen = Pen(120, 130, 60, 80)
    base = CREST_ROCK if v == 0 else CREST_ROCK_B
    if v == 0 and orient != "e":
        ts, sizes = [0.22, 0.5, 0.8], [(26, 30), (30, 38), (26, 31)]
    elif v == 0:
        ts, sizes = [0.28, 0.74], [(32, 34), (30, 38)]
    else:
        ts, sizes = [0.3, 0.72], [(30, 36), (28, 32)]
    feet = []
    for t, (w, h) in zip(ts, sizes):
        x = a[0] + (c[0] - a[0]) * t
        y = a[1] + (c[1] - a[1]) * t
        feet.append((y, x, w, h))
    for y, x, w, h in sorted(feet):
        peak(pen, x, y + 3, w, h * rng.uniform(0.92, 1.08), base, rng, snow)
    return pen.finish()


def cap_piece(snow, v):
    rng = rng_for("cap", snow, v)
    pen = Pen(70, 70, 35, 60)
    base = CREST_ROCK if v == 0 else CREST_ROCK_B
    peak(pen, 0, 4, 36, 46, base, rng, snow, snow_frac=0.45)
    return pen.finish()


def saddle_piece(orient, snow, v):
    """A pass edge: two low shoulders at the corners and a pale rounded saddle between them (the road crosses here)."""
    d = ORIENT[orient]
    a, c, n = edge_geometry(d)
    rng = rng_for("saddle", orient, snow, v)
    pen = Pen(120, 110, 60, 70)
    base = CREST_ROCK if v == 0 else CREST_ROCK_B
    col = (232, 236, 242) if snow else (170, 164, 140)
    feet = []
    for t, (w, h) in ((0.1, (22, 25)), (0.9, (22, 22))):
        feet.append((a[1] + (c[1] - a[1]) * t, a[0] + (c[0] - a[0]) * t, w, h))
    feet.sort()
    # the back shoulder, the saddle dome, the front shoulder
    y, x, w, h = feet[0]
    peak(pen, x, y + 3, w, h, base, rng, snow)
    dome = []
    for k in range(17):
        t = k / 16
        dome.append((-13 + 26 * t, 4 - 8 * (1 - (2 * t - 1) ** 2) ** 0.8))
    pen.tt(col, dome, split_x=-1.0, lit=0.12, dark=-0.16, ink=1.0)
    pen.line(shade(col, -0.3), (-3, -2.5), (2, -2.5), 0.8)
    y, x, w, h = feet[1]
    peak(pen, x, y + 3, w, h, base, rng, snow)
    return pen.finish()


def cliff_piece(d, v):
    """A cliff on edge d of the high (land) hex, facing out over the lower side. Anchor: the edge midpoint."""
    a, c, n = edge_geometry(d)
    rng = rng_for("cliff", d, v)
    pen = Pen(110, 90, 55, 40)
    h = 12
    drop = h * max(0.18, min(1.0, n[1] * 0.9 + 0.5))
    off = (n[0] * 4, n[1] * 3 + drop)
    face = [a, c, (c[0] + off[0], c[1] + off[1]), (a[0] + off[0], a[1] + off[1])]
    rockc = (176, 150, 116) if v == 0 else (158, 146, 132)
    lit = n[0] < -0.1
    col = shade(rockc, 0.12 if lit else -0.22)
    pen.poly(col, face, ink=1.0)
    # strata and cracks
    for k in range(1, 6):
        t = k / 6 + rng.uniform(-0.04, 0.04)
        p = (a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t)
        pen.line(shade(col, -0.3), p, (p[0] + off[0] * 0.9, p[1] + off[1] * 0.9), 0.7)
    # the grass lip on top
    pen.line((96, 132, 70), a, c, 2.0)
    if v == 1 and n[1] > -0.1:
        for k in range(3):
            t = 0.25 + 0.25 * k
            x = a[0] + (c[0] - a[0]) * t + off[0] + rng.uniform(-2, 2)
            y = a[1] + (c[1] - a[1]) * t + off[1] + 3
            pen.oval(shade(rockc, -0.1), x, y, 2.6, 1.8, ink=0.8)
            pen.line((250, 252, 255), (x - 3.5, y + 2), (x + 3.5, y + 2), 0.8)
    return pen.finish()


def beach_piece(d):
    """Flat sand rim inside the shore edge with foam just outside it. Anchor: the edge midpoint."""
    a, c, n = edge_geometry(d)
    pen = Pen(110, 110, 55, 55)
    inward = (-n[0], -n[1])
    sand = (236, 218, 160)
    rim = [(a[0] + inward[0] * 7, a[1] + inward[1] * 7), (c[0] + inward[0] * 7, c[1] + inward[1] * 7), c, a]
    pen.poly(sand, rim, ink=0)
    pen.line(shade(sand, -0.15), a, c, 1.0)
    pts = []
    for k in range(17):
        t = k / 16
        x = a[0] + (c[0] - a[0]) * t + n[0] * (3 + 0.9 * math.sin(t * 9))
        y = a[1] + (c[1] - a[1]) * t + n[1] * (3 + 0.9 * math.sin(t * 9))
        pts.append((x, y))
    pen.lines((252, 253, 255), pts, 1.4)
    return pen.finish()


def hospice(v):
    pen = Pen(50, 46, 25, 40)
    stone = (204, 196, 180)
    roof = (86, 90, 104)
    pen.soft((0, 0, 0, 45), 2, 0, 18, 3)
    house(pen, -2, 0, 22, 9, 8, stone, roof, "ridge", snow=True)
    if v == 0:
        tower_sq(pen, 12, 1, 6, 17, stone, roof)
    else:
        house(pen, 12, 2, 9, 7, 6, stone, roof, "gable", snow=True)
        pen.line(INK, (5, -18), (5, -22), 0.8)
        pen.line(INK, (3.6, -20.6), (6.4, -20.6), 0.8)
    return pen.finish()


def cairn(v):
    pen = Pen(20, 26, 10, 22)
    st = (160, 154, 146)
    for i, (x, y, rx) in enumerate(((0, 0, 5.5), (0.5, -3.6, 4.2), (-0.3, -6.6, 3.2), (0.2, -9.0, 2.2))):
        pen.oval(shade(st, 0.08 * (i % 2)), x, y - 1, rx, 1.9, ink=0.8)
    pen.line(INK, (0.2, -10), (0.2, -17), 0.9)
    pen.poly((196, 60, 50), [(0.2, -17), (5, -15.6), (0.2, -14)], ink=0.6)
    return pen.finish()


def bake_relief(b):
    for orient in ORIENT:
        for snow in (True, False):
            for v in (0, 1):
                b.add(f"relief.crest.{orient}.{'snow' if snow else 'rock'}.v{v}", crest_piece(orient, snow, v),
                      "relief", "edge")
            b.add(f"relief.saddle.{orient}.{'snow' if snow else 'rock'}.v0", saddle_piece(orient, snow, 0),
                  "relief", "edge")
    for snow, v in ((True, 0), (False, 0), (False, 1)):
        b.add(f"relief.cap.{'snow' if snow else 'rock'}.v{v}", cap_piece(snow, v), "relief", "corner")
    for d in range(6):
        for v in (0, 1):
            b.add(f"coast.cliff.d{d}.v{v}", cliff_piece(d, v), "relief", "edge")
        b.add(f"coast.beach.d{d}", beach_piece(d), "relief", "edge_flat")
    for v in (0, 1):
        b.add(f"site.hospice.v{v}", hospice(v), "sites", "upright")
    b.add("site.cairn.v0", cairn(0), "sites", "upright")


# ================================================================================================ buildings
WALL = (238, 228, 204)
WALL_B = (226, 210, 178)
ROOF_RED = (198, 74, 52)
ROOF_ORANGE = (214, 116, 62)
ROOF_SLATE = (84, 94, 124)
STONE = (204, 198, 186)
WOOD = (140, 100, 62)


def house(pen, x, y, w, h, d, wall, roof, kind="gable", snow=False, door=True):
    """A small house seen from the front left, its front-bottom centre at (x, y). The front is lit, the side shaded."""
    dx, dy = d * 0.55, -d * 0.4
    x0, x1 = x - w / 2, x + w / 2
    side = shade(wall, -0.3)
    if kind == "gable":
        rh = w * 0.55
        apex = (x, y - h - rh)
        pen.poly(side, [(x1, y), (x1 + dx, y + dy), (x1 + dx, y - h + dy), (x1, y - h)], 0.8)
        pen.poly(roof, [apex, (x1, y - h), (x1 + dx, y - h + dy), (apex[0] + dx, apex[1] + dy)], 0.8)
        pen.poly(wall, [(x0, y), (x1, y), (x1, y - h), apex, (x0, y - h)], 0.8)
        pen.line(shade(roof, -0.25), (x0 - 0.6, y - h + 0.4), apex, 1.2)
        if snow:
            pen.poly(SNOW, [apex, (x1, y - h), (x1 + dx * 0.6, y - h + dy * 0.6),
                            (apex[0] + dx * 0.6, apex[1] + dy * 0.6)], 0.5)
    else:
        rh = h * 0.75 + d * 0.15
        r1 = (x0 + dx * 0.5, y - h - rh + dy * 0.5)
        r2 = (x1 + dx * 0.5, y - h - rh + dy * 0.5)
        pen.poly(side, [(x1, y), (x1 + dx, y + dy), (x1 + dx, y - h + dy), r2, (x1, y - h)], 0.8)
        pen.poly(wall, [(x0, y), (x1, y), (x1, y - h), (x0, y - h)], 0.8)
        pen.poly(roof, [(x0 - 0.5, y - h), (x1 + 0.5, y - h), r2, r1], 0.8)
        pen.line(shade(roof, 0.22), (r1[0] + 0.5, r1[1] + 0.6), (r2[0] - 0.5, r2[1] + 0.6), 0.6)
        if snow:
            pen.poly(SNOW, [(r1[0], r1[1]), (r2[0], r2[1]), (r2[0] - dx * 0.3, r2[1] + 2.2),
                            (r1[0] - dx * 0.3, r1[1] + 2.2)], 0.5)
    if door and w >= 6:
        pen.poly(shade(wall, -0.55), [(x - 0.9, y), (x + 0.9, y), (x + 0.9, y - min(3.2, h * 0.55)),
                                      (x - 0.9, y - min(3.2, h * 0.55))], 0)


def tower_sq(pen, x, y, w, h, wall, roof, spire=True, crenel=False):
    """A square tower, front-bottom centre (x, y); a pyramid or spire roof, or crenels."""
    d = w * 0.8
    dx, dy = d * 0.55, -d * 0.4
    x0, x1 = x - w / 2, x + w / 2
    pen.poly(shade(wall, -0.3), [(x1, y), (x1 + dx, y + dy), (x1 + dx, y - h + dy), (x1, y - h)], 0.8)
    pen.poly(wall, [(x0, y), (x1, y), (x1, y - h), (x0, y - h)], 0.8)
    top = [(x0, y - h), (x1, y - h), (x1 + dx, y - h + dy), (x0 + dx, y - h + dy)]
    if crenel:
        pen.poly(shade(wall, 0.15), top, 0.8)
        for k in range(3):
            cx = x0 + 0.6 + k * (w - 1.2) / 2
            pen.poly(wall, [(cx - 0.8, y - h), (cx + 0.8, y - h), (cx + 0.8, y - h - 2), (cx - 0.8, y - h - 2)], 0.6)
    else:
        sh = h * (0.75 if spire else 0.35)
        apex = (x + dx / 2, y - h - sh + dy / 2)
        pen.poly(roof, [(x0, y - h), (x1, y - h), apex], 0.8)
        pen.poly(shade(roof, -0.3), [(x1, y - h), (x1 + dx, y - h + dy), apex], 0.8)
    pen.poly(INK, [(x - 0.6, y - h * 0.62), (x + 0.6, y - h * 0.62), (x + 0.6, y - h * 0.5),
                   (x - 0.6, y - h * 0.5)], 0)


def round_tower(pen, x, y, r, h, wall, roof=None, crenel=False):
    dark = shade(wall, -0.3)
    pen.oval(dark, x, y, r, r * 0.38, 0.8)
    body = [(x - r, y), (x - r, y - h), (x + r, y - h), (x + r, y)]
    pen.poly(wall, body, 0)
    pen.poly(dark, [(x + r * 0.25, y + r * 0.36), (x + r * 0.25, y - h), (x + r, y - h), (x + r, y)], 0)
    pen.line(INK, (x - r, y), (x - r, y - h), 0.8)
    pen.line(INK, (x + r, y), (x + r, y - h), 0.8)
    pen.oval(shade(wall, 0.15), x, y - h, r, r * 0.38, 0.8)
    if crenel:
        for k in range(4):
            cx = x - r + 0.7 + k * (2 * r - 1.4) / 3
            pen.poly(wall if k < 2 else dark, [(cx - 0.7, y - h + 0.6), (cx + 0.7, y - h + 0.6),
                                               (cx + 0.7, y - h - 1.8), (cx - 0.7, y - h - 1.8)], 0.5)
    if roof:
        apex = (x, y - h - r * 2.3)
        pen.poly(roof, [(x - r - 0.8, y - h), apex, (x + r + 0.8, y - h)], 0.8)
        pen.poly(shade(roof, -0.3), [(x + 0.2, y - h + r * 0.3), apex, (x + r + 0.8, y - h)], 0.8)


def flag(pen, x, y, h, col):
    pen.line(INK, (x, y), (x, y - h), 0.9)
    pen.poly(col, [(x, y - h), (x + h * 0.5, y - h + h * 0.16), (x, y - h + h * 0.34)], 0.6)


def church(pen, x, y, scale, wall, roof, spire_roof):
    s = scale
    house(pen, x - 2 * s, y, 13 * s, 7 * s, 7 * s, wall, roof, "ridge")
    tower_sq(pen, x + 6.5 * s, y + 0.5, 4.6 * s, 15 * s, wall, spire_roof, spire=True)


def cathedral(pen, x, y, scale):
    s = scale
    house(pen, x - 1 * s, y, 18 * s, 9 * s, 9 * s, (236, 226, 208), ROOF_SLATE, "ridge")
    house(pen, x - 10 * s, y + 1, 7 * s, 10 * s, 7 * s, (236, 226, 208), ROOF_SLATE, "gable")
    tower_sq(pen, x + 9 * s, y + 1, 5.5 * s, 22 * s, (236, 226, 208), ROOF_SLATE, spire=True)


def wall_ring(pen, cx, cy, rx, ry, hw, stone, towers, front, gate=True):
    """A town wall ellipse. front=False draws the back half (inner face, behind the houses), True the front half
    (outer face, lit left) with its towers."""
    def pt(t):
        return (cx + rx * math.cos(t), cy + ry * math.sin(t))
    n = 36
    if not front:
        ts = [math.pi + math.pi * k / n for k in range(n + 1)]
        band = [pt(t) for t in ts] + [(p[0], p[1] - hw) for p in reversed([pt(t) for t in ts])]
        pen.poly(shade(stone, -0.12), band, 0.8)
        pen.lines(shade(stone, 0.2), [(p[0], p[1] - hw) for p in (pt(t) for t in ts)], 1.2)
        for t in towers:
            if math.sin(t) < 0:
                x, y = pt(t)
                round_tower(pen, x, y, hw * 0.55, hw * 1.6, stone, ROOF_RED)
        return
    ts = [math.pi * k / n for k in range(n + 1)]
    pts = [pt(t) for t in ts]
    for i in range(n):
        a, c = pts[i], pts[i + 1]
        col = shade(stone, 0.1) if (a[0] + c[0]) / 2 < cx - rx * 0.15 else shade(stone, -0.22)
        pen.poly(col, [a, c, (c[0], c[1] - hw), (a[0], a[1] - hw)], 0)
    pen.lines(INK, pts, 0.8)
    pen.lines(INK, [(p[0], p[1] - hw) for p in pts], 0.8)
    pen.lines(shade(stone, 0.3), [(p[0], p[1] - hw - 0.6) for p in pts], 0.9)
    for t in towers:
        if math.sin(t) >= 0:
            x, y = pt(t)
            round_tower(pen, x, y, hw * 0.6, hw * 1.7, stone, ROOF_RED)
    if gate:
        x, y = pt(math.pi / 2 + 0.25)
        tower_sq(pen, x - 2.5, y, hw * 0.9, hw * 1.8, stone, ROOF_RED, spire=False)
        tower_sq(pen, x + 2.5, y, hw * 0.9, hw * 1.8, stone, ROOF_RED, spire=False)
        pen.poly((60, 46, 36), [(x - 1.3, y), (x + 1.3, y), (x + 1.3, y - hw * 0.9), (x, y - hw * 1.1),
                                (x - 1.3, y - hw * 0.9)], 0.6)


def palisade(pen, cx, cy, rx, ry, front, gap=0.5):
    n = 26
    ts = [(math.pi * k / n) if front else (math.pi + math.pi * k / n) for k in range(n + 1)]
    for t in ts:
        if front and abs(t - math.pi / 2) < gap:
            continue
        x, y = cx + rx * math.cos(t), cy + ry * math.sin(t)
        col = shade(WOOD, 0.1) if x < cx else shade(WOOD, -0.2)
        pen.poly(col, [(x - 0.9, y), (x + 0.9, y), (x + 0.9, y - 4.2), (x, y - 5.4), (x - 0.9, y - 4.2)], 0.5)


def cluster(rng, n, rx, ry, cx=0.0, cy=0.0, minsep=6.5, avoid=()):
    """House feet in an ellipse, spaced, sorted back to front."""
    pts = []
    tries = 0
    while len(pts) < n and tries < 4000:
        tries += 1
        a = rng.uniform(0, 2 * math.pi)
        rr = math.sqrt(rng.uniform(0, 1))
        x, y = cx + rx * rr * math.cos(a), cy + ry * rr * math.sin(a)
        if any(abs(x - px) < minsep and abs(y - py) < minsep * 0.62 for px, py in pts):
            continue
        if any(abs(x - ax) < aw and abs(y - ay) < ah for ax, ay, aw, ah in avoid):
            continue
        pts.append((x, y))
    return sorted(pts, key=lambda p: (p[1], p[0]))


def houses_at(pen, rng, pts, size=1.0, roofs=(ROOF_RED, ROOF_RED, ROOF_ORANGE, ROOF_SLATE)):
    for x, y in pts:
        w = rng.uniform(6.5, 8.5) * size
        h = rng.uniform(4.5, 6.0) * size
        d = rng.uniform(5, 7) * size
        wall = WALL if rng.random() < 0.65 else WALL_B
        house(pen, x, y, w, h, d, wall, rng.choice(roofs), rng.choice(("gable", "ridge")))


def ground_plate(pen, rx, ry, cy=0.0):
    pen.soft((214, 196, 150, 150), 0, cy, rx, ry)
    pen.soft((232, 218, 178, 120), -rx * 0.08, cy - ry * 0.08, rx * 0.8, ry * 0.75)


def town_piece(level, v):
    rng = rng_for("town", level, v)
    if level == 1:
        pen = Pen(60, 50, 30, 36)
        ground_plate(pen, 16, 7, -1)
        pts = cluster(rng, 2 + v % 2, 9, 3.5, minsep=8)
        houses_at(pen, rng, pts, 1.0)
        return pen.finish()
    if level == 2:
        pen = Pen(76, 64, 38, 46)
        ground_plate(pen, 22, 9, -1)
        ch = (-4 + 6 * v, -4)
        pts = cluster(rng, 5, 15, 6.5, avoid=[(ch[0], ch[1], 10, 5)])
        front = [p for p in pts if p[1] >= ch[1]]
        houses_at(pen, rng, [p for p in pts if p[1] < ch[1]])
        church(pen, ch[0], ch[1], 0.85, WALL, ROOF_RED, ROOF_SLATE)
        houses_at(pen, rng, front)
        return pen.finish()
    if level == 3:
        pen = Pen(92, 76, 46, 54)
        ground_plate(pen, 30, 12, -2)
        cx, cy, rx, ry = 0, -3, 25, 10.5
        palisade(pen, cx, cy, rx, ry, False)
        ch = (3 - 8 * v, -6)
        pts = cluster(rng, 9, 19, 7.5, cy=-3, avoid=[(ch[0], ch[1], 11, 5)])
        houses_at(pen, rng, [p for p in pts if p[1] < ch[1]])
        church(pen, ch[0], ch[1], 1.0, WALL, ROOF_RED, ROOF_SLATE)
        houses_at(pen, rng, [p for p in pts if p[1] >= ch[1]])
        palisade(pen, cx, cy, rx, ry, True)
        return pen.finish()
    if level == 4:
        pen = Pen(110, 90, 55, 62)
        ground_plate(pen, 36, 14, -2)
        cx, cy, rx, ry, hw = 0, -4, 30, 12.5, 5.5
        towers = [math.pi * k / 3 + 0.5 for k in range(6)]
        wall_ring(pen, cx, cy, rx, ry, hw, STONE, towers, False)
        cat = (-2 + 6 * v, -7)
        pts = cluster(rng, 13, 24, 9, cy=-4, minsep=6, avoid=[(cat[0], cat[1], 13, 6)])
        houses_at(pen, rng, [p for p in pts if p[1] < cat[1]])
        cathedral(pen, cat[0], cat[1], 0.9)
        houses_at(pen, rng, [p for p in pts if p[1] >= cat[1]])
        wall_ring(pen, cx, cy, rx, ry, hw, STONE, towers, True)
        return pen.finish()
    # level 5: a walled city with suburbs outside the wall
    pen = Pen(130, 104, 65, 70)
    ground_plate(pen, 50, 18, -2)
    cx, cy, rx, ry, hw = 0, -6, 33, 14, 6.5
    towers = [math.pi * k / 4 + 0.35 for k in range(8)]
    sub_back = cluster(rng, 5, 44, 6, cy=-20, minsep=7, avoid=[(0, -20, 30, 6)])
    houses_at(pen, rng, sub_back, 0.9)
    wall_ring(pen, cx, cy, rx, ry, hw, STONE, towers, False)
    cat = (-4 + 8 * v, -9)
    pts = cluster(rng, 17, 27, 10, cy=-6, minsep=5.6, avoid=[(cat[0], cat[1], 15, 7)])
    houses_at(pen, rng, [p for p in pts if p[1] < cat[1]])
    cathedral(pen, cat[0], cat[1], 1.1)
    houses_at(pen, rng, [p for p in pts if p[1] >= cat[1]])
    wall_ring(pen, cx, cy, rx, ry, hw, STONE, towers, True)
    side = [(x, y) for x, y in cluster(rng, 10, 50, 8, cy=8, minsep=7) if abs(x) > 34 or y > 9]
    houses_at(pen, rng, side, 0.9)
    return pen.finish()


def palace_piece(v):
    """The capital's palace, set beside the city (a square castle-palace with a central tower)."""
    pen = Pen(60, 60, 30, 46)
    pen.soft((0, 0, 0, 40), 2, 0, 22, 4)
    brick = (196, 112, 82)
    house(pen, -4, 0, 26, 9, 12, brick, ROOF_RED, "ridge", door=False)
    round_tower(pen, -17, 1, 3.2, 12, brick, None, crenel=True)
    round_tower(pen, 10, 1, 3.2, 12, brick, None, crenel=True)
    tower_sq(pen, -4, -9, 6, 14, brick, ROOF_RED, spire=False)
    pen.poly((60, 40, 30), [(-5.4, 0), (-2.6, 0), (-2.6, -4), (-4, -5), (-5.4, -4)], 0.6)
    flag(pen, -1.6, -27, 7, (40, 120, 140))
    return pen.finish()


def crown_icon(size):
    pen = Pen(size + 4, size + 4, (size + 4) / 2, (size + 4) / 2)
    s = size / 16
    gold = (232, 182, 64)
    pts = [(-7 * s, 4 * s), (-7.5 * s, -4 * s), (-3.5 * s, -0.5 * s), (0, -6 * s), (3.5 * s, -0.5 * s),
           (7.5 * s, -4 * s), (7 * s, 4 * s)]
    pen.tt(gold, pts, lit=0.15, dark=-0.15, ink=max(0.8, s * 0.9))
    for x, y in ((-7.5 * s, -4 * s), (0, -6 * s), (7.5 * s, -4 * s)):
        pen.dot(gold, x, y - 0.6 * s, 1.3 * s)
    pen.line((176, 40, 40), (-6 * s, 2.2 * s), (6 * s, 2.2 * s), 1.1 * s)
    return pen.finish()


def castle_piece(level, v):
    roof = ROOF_RED if v == 0 else ROOF_SLATE
    if level == 1:
        pen = Pen(50, 56, 25, 44)
        pen.soft((0, 0, 0, 45), 1, 0, 16, 3)
        # the mound
        mound = [(-15 + 30 * k / 16, -6 * (1 - (2 * k / 16 - 1) ** 2) ** 0.7) for k in range(17)]
        pen.tt((120, 156, 82), mound, lit=0.1, dark=-0.22, ink=0.9)
        round_tower(pen, 0, -3, 5, 16, STONE, None, crenel=True)
        pen.poly(INK, [(-0.7, -11), (0.7, -11), (0.7, -13.5), (-0.7, -13.5)], 0)
        flag(pen, 2, -21, 7, (196, 60, 50) if v == 0 else (60, 90, 170))
        return pen.finish()
    if level == 2:
        pen = Pen(70, 64, 35, 46)
        pen.soft((0, 0, 0, 45), 1, 0, 24, 4)
        hw = 6
        # curtain wall: a lozenge court seen from the front left
        back = [(-18, -6), (0, -14), (18, -6)]
        frontp = [(-18, -6), (0, 2), (18, -6)]
        pen.poly(shade(STONE, -0.15), back + [(18, -6 - hw), (0, -14 - hw), (-18, -6 - hw)], 0.8)
        for (x, y) in back:
            round_tower(pen, x, y, 3, hw + 4, STONE, roof)
        tower_sq(pen, -1 + 3 * v, -6, 9, 19, STONE, roof, spire=False, crenel=True)
        pen.poly(shade(STONE, 0.08), [(-18, -6), (0, 2), (0, 2 - hw), (-18, -6 - hw)], 0.8)
        pen.poly(shade(STONE, -0.24), [(0, 2), (18, -6), (18, -6 - hw), (0, 2 - hw)], 0.8)
        pen.poly((60, 46, 36), [(-7.5, -1.5), (-4.5, -0.1), (-4.5, -4), (-6, -5.4), (-7.5, -5.2)], 0.6)
        for (x, y) in frontp:
            round_tower(pen, x, y, 3.2, hw + 4, STONE, roof)
        flag(pen, 3 + 3 * v, -32, 7, (196, 60, 50) if v == 0 else (60, 90, 170))
        return pen.finish()
    # level 3: a star fort (trace italienne), low walls with an earth top, barracks and a flag inside
    pen = Pen(90, 66, 45, 40)
    pen.soft((0, 0, 0, 45), 1, 2, 34, 6)
    n = 5
    pts = []
    for k in range(2 * n):
        ang = -math.pi / 2 + math.pi * k / n + 0.12 * v
        rr = 30 if k % 2 == 0 else 17
        pts.append((rr * math.cos(ang), rr * math.sin(ang) * 0.5 - 6))
    hw = 4.5
    earth = (122, 150, 92)
    # the outer faces (only those facing the viewer are seen)
    for i in range(len(pts)):
        a, c = pts[i], pts[(i + 1) % len(pts)]
        if c[0] < a[0]:            # the edge runs right to left at the front: its face is seen
            mx = (a[0] + c[0]) / 2
            col = shade(STONE, 0.08) if mx < 0 else shade(STONE, -0.24)
            pen.poly(col, [a, c, (c[0], c[1] + hw), (a[0], a[1] + hw)], 0.8)
    pen.poly(earth, pts, 0.9)
    inner = [(x * 0.72, (y + 6) * 0.72 - 6) for x, y in pts]
    pen.poly(shade(earth, 0.18), inner, 0.6)
    house(pen, -5, -3, 14, 5.5, 7, (220, 206, 176), roof, "ridge")
    house(pen, 8, -9, 8, 5, 6, (220, 206, 176), roof, "gable")
    flag(pen, 1, -16, 9, (196, 60, 50) if v == 0 else (60, 90, 170))
    return pen.finish()


# bridges: axis 0 = the road runs E-W (crossing an E or W edge), 1 = NE-SW, 2 = NW-SE
AXES = {0: (1.0, 0.0), 1: (0.5, -SQ3 / 2), 2: (-0.5, -SQ3 / 2)}


def bridge_piece(kind, axis):
    ux, uy = AXES[axis]
    if uy > 0 or (uy == 0 and ux < 0):
        ux, uy = -ux, -uy
    px, py = -uy, ux                     # across the deck
    if py < 0:
        px, py = -px, -py               # px, py points to the front (down the screen)
    L = 30 if kind != "ford" else 26
    W = 7.5 if kind == "stone" else 6.5
    pen = Pen(70, 64, 35, 32)
    a = (-ux * L / 2, -uy * L / 2)
    c = (ux * L / 2, uy * L / 2)
    if kind == "ford":
        band = [(a[0] - px * W / 2, a[1] - py * W / 2), (c[0] - px * W / 2, c[1] - py * W / 2),
                (c[0] + px * W / 2, c[1] + py * W / 2), (a[0] + px * W / 2, a[1] + py * W / 2)]
        pen.poly((206, 226, 232), band, ink=0)
        pen.lines((246, 250, 252), [band[0], band[1]], 0.8)
        pen.lines((246, 250, 252), [band[3], band[2]], 0.8)
        for k in range(6):
            t = (k + 0.5) / 6 - 0.5
            pen.oval((176, 168, 154), ux * L * t + px * (1 if k % 2 else -1), uy * L * t + py * (1 if k % 2 else -1),
                     1.6, 1.1, ink=0.5)
        return pen.finish()
    if kind == "ferry":
        pen.lines(INK, [a, c], 0.7)
        hull = [(-7, -1.5), (7, -1.5), (5.5, 2), (-5.5, 2)]
        pen.poly((150, 108, 66), [(x, y) for x, y in hull], 0.9)
        pen.poly((176, 132, 84), [(-6.5, -1.5), (6.5, -1.5), (6, -2.6), (-6, -2.6)], 0.6)
        pen.line(INK, (2, -2.6), (2, -9), 0.8)
        pen.dot((70, 80, 140), -2, -4.2, 1.6)
        pen.line((70, 80, 140), (-2, -4), (-2, -2.6), 1.2)
        return pen.finish()
    deck = (196, 188, 172) if kind == "stone" else (156, 112, 70)
    drop = 6.0 if kind == "stone" else 3.5
    e1 = (a[0] + px * W / 2, a[1] + py * W / 2)
    e2 = (c[0] + px * W / 2, c[1] + py * W / 2)
    face = [e1, e2, (e2[0], e2[1] + drop), (e1[0], e1[1] + drop)]
    if kind == "wood":
        for k in range(4):
            t = (k + 0.5) / 4
            x, y = e1[0] + (e2[0] - e1[0]) * t, e1[1] + (e2[1] - e1[1]) * t
            pen.line((90, 64, 40), (x, y), (x, y + drop + 3), 1.4)
    pen.poly(shade(deck, -0.25), face, 0.9)
    if kind == "stone":
        for k in range(3):
            t = (k + 0.5) / 3
            x, y = e1[0] + (e2[0] - e1[0]) * t, e1[1] + (e2[1] - e1[1]) * t
            span = abs(e2[0] - e1[0]) / 3 * 0.36
            if span < 1.4:
                continue
            arch = [(x + span * math.cos(a_), y + drop + 0.2 + drop * 0.62 * math.sin(a_))
                    for a_ in [math.pi + math.pi * q / 8 for q in range(9)]]
            pen.poly((52, 84, 110), arch, 0.7)
    top = [(a[0] - px * W / 2, a[1] - py * W / 2), (c[0] - px * W / 2, c[1] - py * W / 2), e2, e1]
    pen.poly(deck, top, 0.9)
    if kind == "wood":
        for k in range(1, 8):
            t = k / 8
            x, y = a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t
            pen.line(shade(deck, -0.25), (x - px * W / 2, y - py * W / 2), (x + px * W / 2, y + py * W / 2), 0.5)
    else:
        pen.line(shade(deck, 0.25), top[0], top[1], 1.4)
        pen.line(shade(deck, 0.1), e1, e2, 1.2)
    return pen.finish()


def quay_piece(kind, d):
    """A port on edge d of the town hex: a stone quay along the shore with a moored cog, or a wooden jetty."""
    a, c, n = edge_geometry(d)
    pen = Pen(110, 110, 55, 55)
    inward = (-n[0], -n[1])
    if kind == "stone":
        q = 0.42
        ia = (a[0] * q + inward[0] * 4, a[1] * q + inward[1] * 4)
        ic = (c[0] * q + inward[0] * 4, c[1] * q + inward[1] * 4)
        oa, oc = (a[0] * q + n[0] * 3, a[1] * q + n[1] * 3), (c[0] * q + n[0] * 3, c[1] * q + n[1] * 3)
        top = [ia, ic, oc, oa]
        drop = 4 * max(0.2, min(1.0, n[1] + 0.6))
        pen.poly(shade(STONE, -0.25), [oa, oc, (oc[0], oc[1] + drop), (oa[0], oa[1] + drop)], 0.8)
        pen.poly(STONE, top, 0.8)
        for k in range(1, 4):
            t = k / 4
            x, y = oa[0] + (oc[0] - oa[0]) * t, oa[1] + (oc[1] - oa[1]) * t
            pen.dot(INK, x, y - 0.5, 0.8)
        bx, by = n[0] * 17 + (c[0] - a[0]) * 0.18, n[1] * 17 + (c[1] - a[1]) * 0.18 + 4
        cog(pen, bx, by, 0.8, (236, 228, 208))
    else:
        L = 16
        e = (n[0] * L, n[1] * L)
        px, py = -n[1], n[0]
        W = 3.5
        for k in range(1, 4):
            t = k / 4
            x, y = e[0] * t, e[1] * t
            pen.line((80, 58, 38), (x + px * W / 2, y + py * W / 2), (x + px * W / 2, y + py * W / 2 + 3.5), 1.0)
        plank = [(-px * W / 2, -py * W / 2), (e[0] - px * W / 2, e[1] - py * W / 2),
                 (e[0] + px * W / 2, e[1] + py * W / 2), (px * W / 2, py * W / 2)]
        pen.poly((160, 116, 72), plank, 0.8)
        bx, by = n[0] * 10 + px * 7, n[1] * 10 + py * 7 + 2
        rowboat(pen, bx, by)
    return pen.finish()


def cog(pen, x, y, s, sail):
    hull = [(x - 9 * s, y - 4 * s), (x + 9 * s, y - 4 * s), (x + 6.5 * s, y + 1.5 * s), (x - 6.5 * s, y + 1.5 * s)]
    pen.tt((150, 104, 64), hull, split_x=x + 2, ink=0.8)
    pen.line(INK, (x, y - 4 * s), (x, y - 19 * s), 0.9)
    sailp = [(x - 5.5 * s, y - 17.5 * s), (x + 5.5 * s, y - 17.5 * s), (x + 5 * s, y - 7 * s), (x - 5 * s, y - 7 * s)]
    pen.tt(sail, sailp, split_x=x + 1, lit=0.0, dark=-0.12, ink=0.8)
    pen.line((196, 60, 50), (x, y - 16 * s), (x, y - 8.5 * s), 1.0 * s)
    pen.line((196, 60, 50), (x - 3.5 * s, y - 12.5 * s), (x + 3.5 * s, y - 12.5 * s), 1.0 * s)


def rowboat(pen, x, y):
    pen.poly((150, 104, 64), [(x - 5, y - 1.6), (x + 5, y - 1.6), (x + 3.6, y + 1.2), (x - 3.6, y + 1.2)], 0.7)


def boat_piece(v):
    pen = Pen(40, 40, 20, 30)
    pen.soft((20, 60, 90, 60), 0, 2, 11, 2)
    cog(pen, 0, 0, 1.0 if v == 0 else 0.85, (236, 228, 208) if v == 0 else (220, 206, 170))
    return pen.finish()


def bake_sites(b):
    for level in range(1, 6):
        for v in (0, 1, 2):
            b.add(f"town.{level}.v{v}", town_piece(level, v), "sites", "upright", level=level)
    b.add("town.palace.v0", palace_piece(0), "sites", "upright")
    for level in (1, 2, 3):
        for v in (0, 1):
            b.add(f"castle.{level}.v{v}", castle_piece(level, v), "sites", "upright", level=level)
    for kind in ("stone", "wood", "ford", "ferry"):
        for axis in (0, 1, 2):
            b.add(f"road.bridge.{kind}.axis{axis}", bridge_piece(kind, axis), "sites",
                  "flat" if kind == "ford" else "upright")
    for kind in ("stone", "wood"):
        for d in range(6):
            b.add(f"port.quay.{kind}.d{d}", quay_piece(kind, d), "sites", "edge")
    for v in (0, 1):
        b.add(f"port.boat.cog.v{v}", boat_piece(v), "sites", "upright")


# ================================================================================================ heraldry
def shield_outline(w, h, top=0.0):
    pts = []
    pts.append((-w / 2, top))
    pts.append((w / 2, top))
    for k in range(13):
        t = k / 12
        # right side down to the point
        x = w / 2 * (1 - t ** 2.2)
        y = top + h * 0.45 + (h * 0.55) * t
        pts.append((x, y))
    for k in range(12, -1, -1):
        t = k / 12
        x = -w / 2 * (1 - t ** 2.2)
        y = top + h * 0.45 + (h * 0.55) * t
        pts.append((x, y))
    return pts


def biscione(size):
    """The Visconti viper of Milan, simplified: a white shield, a blue crowned serpent in an S, a red figure in its
    jaws. A sketch to be checked against a heraldry source before it ships."""
    W = size * 0.8
    H = size
    pen = Pen(int(size + 6), int(size + 6), (size + 6) / 2, 3)
    ink = max(0.8, size / 48)
    sh = shield_outline(W, H)
    pen.poly((246, 246, 240), sh, ink=0)
    right = clip_poly(sh, lambda x, y: x - W * 0.05)
    pen.poly((226, 226, 220), right, ink=0)
    blue = (36, 78, 168)
    # the body: an S from the tail at the bottom to the head at the top left
    path = []
    for k in range(41):
        t = k / 40
        y = H * (0.92 - 0.72 * t)
        x = W * 0.2 * math.sin(t * 2.6 * math.pi + 0.4) * (0.6 + 0.4 * t)
        path.append((x, y))
    thick = size * 0.085
    for i, (x, y) in enumerate(path):
        r = thick * (0.45 + 0.55 * (i / 40))
        pen.dot(shade(blue, -0.35), x + r * 0.25, y + r * 0.2, r)
    for i, (x, y) in enumerate(path):
        r = thick * (0.45 + 0.55 * (i / 40))
        pen.dot(blue, x, y, r * 0.86)
    hx, hy = path[-1]
    # head and open jaws facing right
    pen.oval(blue, hx + thick * 0.4, hy - thick * 0.3, thick * 1.25, thick * 0.95, ink=0)
    if size >= 40:
        # the red figure in the jaws
        fx, fy = hx + thick * 2.0, hy - thick * 0.7
        pen.dot((206, 40, 40), fx + thick * 0.3, fy - thick * 0.9, thick * 0.42)
        pen.line((206, 40, 40), (fx, fy), (fx + thick * 0.6, fy - thick * 0.7), thick * 0.5)
        pen.line((206, 40, 40), (fx - thick * 0.3, fy + thick * 0.2), (fx + thick * 0.9, fy + thick * 0.3),
                 thick * 0.32)
        pen.line((206, 40, 40), (fx + thick * 0.4, fy - thick * 0.5), (fx + thick * 1.1, fy - thick * 1.1),
                 thick * 0.3)
    else:
        pen.dot((206, 40, 40), hx + thick * 1.8, hy - thick * 0.6, thick * 0.6)
    # crown
    gold = (232, 182, 64)
    cx, cy = hx - thick * 0.3, hy - thick * 1.3
    cw = thick * 1.3
    crown = [(cx - cw, cy + cw * 0.4), (cx - cw * 1.1, cy - cw * 0.6), (cx - cw * 0.4, cy - cw * 0.1),
             (cx, cy - cw * 0.9), (cx + cw * 0.4, cy - cw * 0.1), (cx + cw * 1.1, cy - cw * 0.6),
             (cx + cw, cy + cw * 0.4)]
    pen.poly(gold, crown, ink=ink * 0.6)
    pen.lines(INK, sh + [sh[0]], ink)
    return pen.finish()


def arms_frame(size):
    """A blank shield (white, the renderer tints or fills it) with an ink edge and an inner rim."""
    W, H = size * 0.8, size
    pen = Pen(int(size + 6), int(size + 6), (size + 6) / 2, 3)
    ink = max(0.8, size / 48)
    sh = shield_outline(W, H)
    pen.poly((255, 255, 255), sh, ink=ink)
    if size >= 40:
        inner = shield_outline(W * 0.86, H * 0.86, top=H * 0.06)
        pen.lines((200, 200, 200), inner + [inner[0]], max(0.6, size / 96))
    return pen.finish()


def pennant():
    """A swallow-tailed pennant on a pole; the cloth is white for the renderer to tint in the country colour."""
    pen = Pen(70, 64, 6, 62)
    pen.line((96, 70, 44), (0, 0), (0, -58), 2.0)
    cloth = [(1, -57), (56, -54), (44, -45), (58, -36), (1, -34)]
    pen.poly((255, 255, 255), cloth, ink=1.0)
    pen.poly((226, 226, 226), [(30, -55.5), (56, -54), (44, -45), (58, -36), (30, -35)], ink=0)
    pen.lines(INK, cloth + [cloth[0]], 1.0)
    pen.dot((232, 182, 64), 0, -59, 1.8)
    return pen.finish()


def plate():
    """The town plate: a navy pill (nine-patch: margins 10 px left and right)."""
    w, h = 40, 18
    pen = Pen(w, h, 0, 0)
    pen.poly((28, 34, 56), [(9, 1), (w - 9, 1), (w - 1, 9), (w - 9, h - 1), (9, h - 1), (1, 9)], ink=0)
    pen.oval((28, 34, 56), 9, 9, 8, 8, ink=0)
    pen.oval((28, 34, 56), w - 9, 9, 8, 8, ink=0)
    pen.poly((28, 34, 56), [(9, 1), (w - 9, 1), (w - 9, h - 1), (9, h - 1)], ink=0)
    pen.lines((232, 182, 64, 255), [(9, 1.6), (w - 9, 1.6)], 0.6)
    return pen.finish()


def level_dot():
    pen = Pen(8, 8, 4, 4)
    pen.dot((232, 182, 64), 0, 0, 2.2)
    return pen.finish()


def bake_heraldry(b):
    for size in (96, 48, 22):
        b.add(f"arms.milan.{size}", biscione(size), "heraldry", "ui", country="Milan")
        b.add(f"arms.frame.{size}", arms_frame(size), "heraldry", "ui", tint=True)
    b.add("arms.pennant", pennant(), "heraldry", "ui", tint=True)
    b.add("label.plate", plate(), "heraldry", "ui", nine_patch=[10, 0, 10, 0])
    b.add("label.dot", level_dot(), "heraldry", "ui")
    for size in (16, 24):
        b.add(f"label.crown.{size}", crown_icon(size), "heraldry", "ui")


# ================================================================================================ rules (the index)
def rules():
    """The data the Godot renderer codes against, besides the sprite rects: zoom bands, scatter, mountains, fields,
    sites, edges, borders and the line palette. All lengths are in hex radii (r) unless the name says px."""
    return {
        "zoom": {
            "base_radius_px": BASE_R,
            "note": "A piece is drawn at scale = (r / base_radius_px) * band.scale_mul[family]. Bands are picked by "
                    "the hex radius r in screen px: the first band with r >= r_min.",
            "bands": [
                {"name": "close", "r_min": 40,
                 "scale_mul": {"scatter": 1.0, "relief": 1.0, "sites": 1.0, "field": 1.0},
                 "step_mul": {"trees": 1.0, "mountains": 1.0, "fields": 1.0, "marsh": 1.0, "rocks": 1.0}},
                {"name": "middle", "r_min": 18,
                 "scale_mul": {"scatter": 1.35, "relief": 1.15, "sites": 1.3, "field": 1.25},
                 "step_mul": {"trees": 1.5, "mountains": 1.25, "fields": 1.3, "marsh": 1.6, "rocks": 99.0}},
                {"name": "far", "r_min": 0,
                 "scale_mul": {"scatter": 1.8, "relief": 1.4, "sites": 1.8, "field": 1.0},
                 "step_mul": {"trees": 2.6, "mountains": 1.7, "fields": 99.0, "marsh": 99.0, "rocks": 99.0},
                 "sites": "plates only below r 10"},
            ],
        },
        "ground": {
            "covers": COVERS,
            "texture_world_px": TEX,
            "note": "Sample every cover texture in world space: uv = world_px_at_base_radius / texture_world_px, so "
                    "neighbouring hexes share the pattern and no seam shows. Multiply by level_tint[level], then the "
                    "relief shade (WorldCover.shade). Blend (the owner's narrow v2 blend: hexes still read as "
                    "hexes): at a pixel, e = its distance in r units to the nearest edge of its hex, signed + inside; "
                    "the hex and the neighbour across that edge mix with t = smoothstep(-band, band, e + n), n = "
                    "noise_amp * (noise.r * 2 - 1); near a corner the third hex joins the same way. The noise is "
                    "sampled in world space (noise_world_px per texture repeat) so both sides of an edge agree.",
            "level_tint": LEVEL_TINT,
            "blend": {"band": 0.11, "noise_amp": 0.07, "noise_world_px": 512, "hard_edges": ["sea", "lake_hex"]},
            "valley_floor": {"tint": [1.06, 1.08, 1.0], "note": "the valley flag is a paler meadow ribbon"},
        },
        "scatter": {
            "grid": "A square world grid over the whole map, not per hex. Point (i, j) sits at (i, j) * step + "
                    "jitter * step * (h1 - 0.5, h2 - 0.5), odd rows j shifted by half a step in x (so rows do not "
                    "line up), with h1, h2 two hashes of (layer, i, j) in 0..1. The cover and level at the "
                    "jittered point come from the hex under it. A third hash below density keeps the point; a "
                    "fourth picks the species by weight; a fifth picks size and variant. So the result is stable "
                    "between runs and saves, and a forest runs on across hex edges.",
            "calm": {"site_radius": 0.55, "line_clear": 0.12, "crest_clear": 0.22,
                     "note": "no tree, rock or mountain within site_radius of a settlement, castle or hospice site; "
                             "none within line_clear of a river or road line; no mountain within crest_clear of a "
                             "crest or pass edge (the crest pieces stand there). The site.calm decal goes under every "
                             "site (scale 1.0 at a town of level 3)."},
            "layers": {
                "trees": {"step": 0.36, "jitter": 1.0, "family_sizes": {"s": 0.3, "m": 0.45, "l": 0.25}},
                "marsh": {"step": 0.42, "jitter": 1.0},
                "rocks": {"step": 0.6, "jitter": 0.9},
                "mountains": {"step": 0.62, "jitter": 1.0},
                "fields": {"step": 0.42, "jitter": 0.25},
            },
            "covers": {
                "farmland": {"trees": {"density": 0.05, "species": {"broadleaf": 1}},
                             "note": "fields come from the farm rule below"},
                "grassland": {"trees": {"density": 0.12, "species": {"broadleaf": 3, "shrub": 2}},
                              "rocks": {"density": 0.08}},
                "woods": {"trees": {"density": 0.86, "species_by_level": {
                    "1": {"broadleaf": 8, "conifer": 1, "shrub": 1}, "2": {"broadleaf": 8, "conifer": 1, "shrub": 1},
                    "3": {"broadleaf": 5, "conifer": 4, "shrub": 1}, "4": {"conifer": 8, "broadleaf": 2},
                    "5": {"conifer": 9, "shrub": 1}, "6": {"conifer": 1}}}},
                "marsh": {"marsh": {"density": 0.55, "species": {"reeds": 5, "cattails": 3, "pool": 3,
                                                                 "lily_pond": 1}},
                          "trees": {"density": 0.06, "species": {"broadleaf": 1}}},
                "rock": {"rocks": {"density": 0.3}, "trees": {"density": 0.08, "species": {"conifer": 1}}},
                "snow": {"rocks": {"density": 0.08}},
                "tundra": {"rocks": {"density": 0.2}, "trees": {"density": 0.1, "species": {"shrub": 2, "conifer": 1}}},
                "sand": {"rocks": {"density": 0.06}, "trees": {"density": 0.04, "species": {"shrub": 1}}},
            },
            "southern": {"rule": "hexes south of lat_max (Liguria, Tuscany) at level <= 3 swap broadleaf for the "
                                 "southern family with this share", "lat_max": 44.6, "share": 0.6},
            "snowline": {"rule": "conifers at level >= 5 use the conifer_snow family", "level": 5},
        },
        "mountains": {
            "rule": "On the mountains grid the kind comes from the height interpolated between the three nearest hex "
                    "centres (relief levels, inverse-distance weights), so a range fades from snowy peaks to rocky "
                    "ranges to wooded hills across hex edges.",
            "kinds": [
                {"kind": "peak_high", "min_level": 5.6, "density": 0.95, "sizes": {"m": 0.45, "l": 0.55}},
                {"kind": "peak_rocky", "min_level": 4.7, "density": 0.85, "sizes": {"m": 0.6, "l": 0.4},
                 "species": {"range": 1}, "snow_cover_swap": "peak_high"},
                {"kind": "peak_low", "min_level": 3.9, "density": 0.55, "sizes": {"m": 0.7, "l": 0.3},
                 "with_trees": 0.6},
                {"kind": "hill", "min_level": 2.9, "density": 0.4, "sizes": {"m": 0.8, "l": 0.2},
                 "species": {"hill_green": 5, "hill_dry": 1, "hill_terraced": 2, "outcrop": 1},
                 "farmland_species": {"hill_terraced": 3, "hill_green": 2}},
            ],
        },
        "fields": {
            "rule": "Parcels stand on the fields grid. Each farm (a farmland hex, or a settlement) spreads parcels "
                    "round "
                    "its site out to radius[level] (r units); a point takes the nearest farm in reach. The parcel's "
                    "angle is the same for all parcels of one farm (a hash of the farm hex, in 0..180 degrees, "
                    "snapped to 15). Style by weight; terraces replace grain on level >= 3 ground.",
            "farm_level": "farmland hex: 1; a settlement of level L also farms its own hex at L and ring 1 at L - 2",
            "radius": [0.0, 0.45, 0.7, 0.95, 1.25, 1.6],
            "density": [0.0, 0.7, 0.8, 0.85, 0.9, 0.92],
            "styles": {"grain": 4, "barley": 2, "green": 3, "ploughed": 2, "meadow": 2, "orchard": 1, "vines": 1},
            "southern_styles": {"vines": 3, "orchard": 2, "grain": 2, "green": 1},
            "hill_styles": {"terrace": 4, "vines": 2, "meadow": 1},
            "haystacks": 0.08,
        },
        "sites": {
            "site_point": "The hex centre, moved a third of a hex away from the hex's river edges (to the dry side), "
                          "or "
                          "towards the quay edge for a port; a river city's site is the hex centre.",
            "town": "town.<level>.v<hash % 3>, anchor on the site point",
            "capital": "town.palace.v0 at site + (0.62, 0.12) r, and label.crown.* on the plate",
            "castle": "with a town: castle.<level>.v<hash % 2> at site + (-0.6, 0.2) r; alone: on the site",
            "port": "port.quay.<stone for sea and lake | wood for rivers>.d<edge direction of the quay edge>, anchored "
                    "on that edge's midpoint; port.boat.cog.* on the water off big ports",
            "hospice": "site.hospice.v<hash % 2> on the saddle hex centre, site.cairn.v0 at + (0.3, -0.15) r",
            "monastery": "site.reuse.monastery.v0",
            "plate_hidden_below_r": 10,
        },
        "edges": {
            "direction_order": "0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE (WorldGrid.neighbour); corner k at -90 + 60k degrees",
            "orientation_of_direction": {"0": "e", "3": "e", "1": "ne", "4": "ne", "2": "nw", "5": "nw"},
            "crest": "relief.crest.<orientation>.<snow if both hexes are level 6 or either is snow cover, else "
                     "rock>.v<hash % 2>, "
                     "anchor on the edge midpoint. Lit pieces are never rotated or mirrored.",
            "cap": "relief.cap.<snow|rock>.v<hash>, on every corner where two or more crest edges meet",
            "pass": "relief.saddle.<orientation>.<snow|rock>.v0 on a pass edge (line = pass)",
            "cliff": "coast.cliff.d<direction from the land hex to the sea>.v<hash % 2>, on the edge midpoint "
                     "(also step = scarp, facing the lower hex)",
            "beach": "coast.beach.d<direction>: optional; the coastline recipe draws the rim (D7)",
            "bridge": "road.bridge.<stone|wood|ford|ferry>.axis<a>: a = 0 for a road crossing an E/W edge, 1 for "
                      "NE/SW, "
                      "2 for NW/SE; on the river edge's midpoint. crossing bridge_stone -> stone, bridge_wood -> wood",
        },
        "border": {
            "style": "A (D6): a band of the country colour inside the border, a dark line on it, a faint wash",
            "band_width": 0.3, "band_alpha": 0.6, "band_texture": "strip.border_band",
            "line_px_at_base": 3.0, "line_colour": "country colour * 0.5", "wash_alpha": 0.15,
            "other_countries": {"texture": "strip.border_dash", "colour": [60, 60, 70], "alpha": 0.7,
                                "px_at_base": 2.0},
            "draw_order": "band and wash under the upright objects; the line above them (reads through forests)",
            "colours": {"Milan": [60, 140, 150]},
        },
        "lines": {
            "note": "Rivers and roads are drawn as strips (geometry). Widths in r units, with a floor in px.",
            "river": {"widths": [0.0, 0.07, 0.1, 0.14], "min_px": [0, 1.5, 2.0, 3.0], "bank": [68, 112, 120],
                      "water": [74, 140, 196], "highlight": [150, 200, 230], "bank_extra": 0.04},
            "stream": {"width": 0.035, "min_px": 1.0, "water": [96, 156, 204]},
            "lake": {"water": [88, 156, 206], "shore": [226, 214, 162], "shore_extra": 0.05},
            "sea": {"shelf": [126, 186, 222], "deep": [74, 136, 196], "lagoon": [170, 214, 222],
                    "sand_rim": 0.07, "foam": "strip.foam", "shallow": 0.22},
            "road": {"widths": [0.0, 0.03, 0.05, 0.065], "casing": [70, 56, 44], "surface": [[0, 0, 0], [150, 118, 82],
                                                                                           [224, 196, 140],
                                                                                           [242, 232, 208]],
                     "track_texture": "strip.track"},
        },
    }


# ================================================================================================ packing and output
def pack(pieces, group):
    names = sorted((n for n, p in pieces.items() if p["group"] == group),
                   key=lambda n: (-pieces[n]["surf"].get_height(), n))
    pages, rects = [], {}
    x = y = shelf = 0
    cur = []
    for n in names:
        w, h = pieces[n]["surf"].get_size()
        cw, ch = w + 2 * PAD, h + 2 * PAD
        if x + cw > PAGE_W:
            x, y, shelf = 0, y + shelf, 0
        if y + ch > PAGE_W:
            pages.append((cur, y + shelf))
            cur, x, y, shelf = [], 0, 0, 0
        cur.append(n)
        rects[n] = (len(pages), x + PAD, y + PAD, w, h)
        x += cw
        shelf = max(shelf, ch)
    pages.append((cur, y + shelf))
    return pages, rects


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def build():
    b = Bake()
    bake_nature(b)
    bake_fields(b)
    bake_relief(b)
    bake_sites(b)
    bake_heraldry(b)
    for cover in COVERS:
        b.tex(f"ground.{cover}", ground_texture(cover), f"ground_{cover}.png", tile="xy", cover=cover,
              mean_colour=list(COVER_BASE[cover]))
    b.tex("noise", noise_texture(), "noise_blend.png", tile="xy",
          note="R broad (4 cells), G middle (12), B fine (32); 0..1 values, mean 0.5")
    strip_textures(b)
    return b


def write(b, out_dir, log=print):
    os.makedirs(out_dir, exist_ok=True)
    index = {"format": FORMAT, "base_radius_px": BASE_R, "pages": {}, "textures": {}, "pieces": {}}
    groups = sorted({p["group"] for p in b.pieces.values()})
    for group in groups:
        pages, rects = pack(b.pieces, group)
        for i, (names, height) in enumerate(pages):
            pid = f"{group}_{i}"
            h = max(4, (height + 3) // 4 * 4)
            page = pygame.Surface((PAGE_W, h), pygame.SRCALPHA)
            for n in names:
                _, x, y, w, hh = rects[n]
                page.blit(b.pieces[n]["surf"], (x, y))
            path = os.path.join(out_dir, pid + ".png")
            pygame.image.save(page, path)
            index["pages"][pid] = {"file": pid + ".png", "size": [PAGE_W, h], "sha256": sha(path),
                                   "filter": "linear", "mipmaps": True}
        for n, (pi, x, y, w, h) in rects.items():
            p = b.pieces[n]
            entry = {"page": f"{group}_{pi}", "rect": [x, y, w, h], "anchor": [p["anchor"][0], p["anchor"][1]],
                     "layer": p["layer"], "rotate": p["rotate"]}
            entry.update(p["meta"])
            index["pieces"][n] = entry
    for n in sorted(b.textures):
        t = b.textures[n]
        path = os.path.join(out_dir, t["file"])
        pygame.image.save(t["surf"], path)
        entry = {"file": t["file"], "size": list(t["surf"].get_size()), "sha256": sha(path)}
        entry.update(t["meta"])
        index["textures"][n] = entry
    index["pieces"] = dict(sorted(index["pieces"].items()))
    index["rules"] = rules()
    index["counts"] = {"pieces": len(b.pieces), "textures": len(b.textures), "pages": len(index["pages"])}
    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(index, f, indent=1, sort_keys=False)
        f.write("\n")
    log(f"bake_map_art: {len(b.pieces)} pieces on {len(index['pages'])} pages, {len(b.textures)} textures -> {out_dir}")
    return index


# ================================================================================================ contact sheets
def contact_sheets(b, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    font = pygame.font.SysFont("segoeui", 13)
    head = pygame.font.SysFont("segoeui", 20, bold=True)
    families = {}
    for n in sorted(b.pieces):
        parts = n.split(".")
        key = parts[0] if parts[0] in ("town", "castle", "port", "arms", "label", "field") else ".".join(parts[:2])
        families.setdefault(key, []).append(n)
    sheets = {
        "sheet_scatter_trees": ["scatter.broadleaf", "scatter.conifer", "scatter.southern", "scatter.shrub"],
        "sheet_scatter_relief": ["scatter.peak_high", "scatter.peak_rocky", "scatter.peak_low", "scatter.hill",
                                 "scatter.rock", "scatter.marsh", "scatter.herd"],
        "sheet_fields": ["field", "site.calm"],
        "sheet_relief_edges": ["relief.crest", "relief.saddle", "relief.cap", "coast.cliff", "coast.beach"],
        "sheet_sites": ["town", "castle", "site.hospice", "site.cairn", "site.reuse", "road.bridge", "port"],
        "sheet_heraldry": ["arms", "label"],
    }
    bg = (124, 168, 96)
    for sheet, fams in sheets.items():
        rows = []
        for fam in fams:
            names = families.get(fam, [])
            if names:
                rows.append((fam, names))
        scale = 2
        width = 1800
        y = 50
        layout = []
        for fam, names in rows:
            x = 170
            rowh = 0
            line = []
            for n in names:
                s = b.pieces[n]["surf"]
                w, h = s.get_width() * scale, s.get_height() * scale
                if x + w + 16 > width:
                    layout.append((fam, line, y, rowh))
                    y += rowh + 34
                    x, rowh, line = 170, 0, []
                    fam = ""
                line.append((n, x))
                x += max(w, 60) + 16
                rowh = max(rowh, h)
            layout.append((fam, line, y, rowh))
            y += rowh + 40
        sheet_s = pygame.Surface((width, y + 20))
        sheet_s.fill((236, 234, 228))
        sheet_s.blit(head.render(sheet.replace("_", " ") + "  (2x, on a grass swatch; anchor = red cross)", True,
                                 (30, 30, 30)), (16, 12))
        for fam, line, ly, rowh in layout:
            sheet_s.blit(font.render(fam, True, (40, 40, 40)), (16, ly + rowh // 2 - 8))
            for n, x in line:
                p = b.pieces[n]
                s = p["surf"]
                big = pygame.transform.scale(s, (s.get_width() * scale, s.get_height() * scale))
                sw = pygame.Rect(x - 4, ly - 4, big.get_width() + 8, big.get_height() + 8)
                pygame.draw.rect(sheet_s, bg if not n.startswith(("arms", "label")) else (200, 200, 196), sw)
                sheet_s.blit(big, (x, ly))
                ax, ay = p["anchor"]
                cx, cy = x + ax * scale, ly + ay * scale
                pygame.draw.line(sheet_s, (220, 30, 30), (cx - 3, cy), (cx + 3, cy))
                pygame.draw.line(sheet_s, (220, 30, 30), (cx, cy - 3), (cx, cy + 3))
                label = n.split(".", 2)[-1] if len(n) > 22 else n
                sheet_s.blit(font.render(label[-26:], True, (70, 70, 70)), (x, ly + big.get_height() + 4))
        pygame.image.save(sheet_s, os.path.join(out_dir, sheet + ".png"))
    # ground textures, 2 x 2 tiles each to show they tile, and the noise and strips
    covers = [n for n in sorted(b.textures) if n.startswith("ground.")] + ["noise"]
    s = pygame.Surface((len(covers) * 270 // 2 * 2 + 40, 640))
    s.fill((236, 234, 228))
    s.blit(head.render("ground textures (2 x 2 repeats each: they must tile), the blend noise, the strips", True,
                       (30, 30, 30)), (16, 12))
    for i, n in enumerate(covers):
        t = b.textures[n]["surf"]
        x = 16 + (i % 5) * 300
        yy = 50 + (i // 5) * 300
        half = pygame.transform.smoothscale(t, (128, 128))
        for dx in (0, 128):
            for dy in (0, 128):
                s.blit(half, (x + dx, yy + dy))
        s.blit(font.render(n, True, (40, 40, 40)), (x, yy + 260))
    sx = 16 + 4 * 300 + 300
    for j, n in enumerate([n for n in sorted(b.textures) if n.startswith("strip.")]):
        t = b.textures[n]["surf"]
        row = pygame.Surface((256, t.get_height()), pygame.SRCALPHA)
        for k in range(0, 256, t.get_width()):
            row.blit(t, (k, 0))
        pygame.draw.rect(s, (60, 110, 160), pygame.Rect(sx - 4, 360 + j * 50 - 4, 264, t.get_height() * 2 + 8))
        s.blit(pygame.transform.scale(row, (256, t.get_height() * 2)), (sx, 360 + j * 50))
        s.blit(font.render(n, True, (40, 40, 40)), (sx + 270, 360 + j * 50))
    pygame.image.save(s, os.path.join(out_dir, "sheet_ground.png"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=OUT_DIR)
    ap.add_argument("--sheets", default=None, help="write contact sheets into this folder")
    args = ap.parse_args(argv)
    b = build()
    write(b, args.out)
    if args.sheets:
        contact_sheets(b, args.sheets)
    return 0


if __name__ == "__main__":
    sys.exit(main())
