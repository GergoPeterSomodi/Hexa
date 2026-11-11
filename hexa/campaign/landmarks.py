"""Landmark city tiles: ten famous cities, each drawn at three growth stages (1 town, 2 city, 3 great capital).

Same look as the goods tiles in hexa.campaign.goodsart: 120 x 140 pointy-top hex, flat two-tone shading (lit
left, darker right), dark ink outlines on the objects, drawn at 2x on a 240 x 280 canvas and smooth-scaled.
Every city has its own ground and its own silhouette, so it reads at a glance even at map size:

    venice         lagoon + island, campanile, three basilica domes, gondolas
    constantinople Golden Horn bay, Hagia Sophia dome with four minarets, Theodosian walls with towers
    paris          the Seine round the Ile de la Cite, Notre-Dame's twin towers and spire
    london         the Thames, London Bridge with houses, the White Tower, old St Paul's spire
    lisbon         the Tagus, tiered hillside houses, Belem tower, caravels
    rome           the Tiber, Castel Sant'Angelo drum, St Peter's dome and colonnade, obelisk
    seville        the Guadalquivir, the Giralda belfry, Torre del Oro, Indies ships
    cairo          Nile green strip on sand, citadel minarets on the hill, pyramids
    moscow         snow, red Kremlin walls with towers and onion domes
    granada        the Alhambra's red towers on its hill, cypresses, Sierra snowcaps

Public API:  draw_city(name, stage, variant=0) -> pygame.Surface (120 x 140, per-pixel alpha)
             CITY_NAMES, STAGE_NAMES
"""
import math
import random
import zlib

import pygame

from .art import hex_pts, shade
from .goodsart import Pen, building, tower, dome, boat, flag, palm, pine, lerp, INK, WHITE, DARK, DWOOD

W, H = 120, 140
CX, CY = W / 2, H / 2
R = 69.3
K = 2                                       # supersampling factor
CITY_NAMES = ["venice", "constantinople", "paris", "london", "lisbon",
              "rome", "seville", "cairo", "moscow", "granada"]
STAGE_NAMES = ["town", "city", "capital"]

# palette shared by the cities
STONE = (206, 200, 186)
CREAM = (240, 230, 205)
LIME = (236, 228, 204)
BRICK = (196, 104, 76)
ROOF_RED = (200, 92, 62)
SLATE = (96, 106, 124)
GOLD = (236, 190, 70)
WATER = (80, 156, 208)
WATER_D = (58, 120, 178)
WATER_L = (140, 206, 234)
SAND = (232, 210, 160)
GREEN = (116, 172, 92)
GREEN_D = (74, 130, 66)


class Canvas:
    """A 120 x 140 tile: ground pen `g`, object-layer pen `o` (outlined by `stamp`), `finish` clips to the hex."""

    def __init__(self):
        self.surf = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        self.layer = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        self.g = Pen(self.surf)
        self.o = Pen(self.layer)

    def fill(self, color):
        self.surf.fill(color)

    def shadow(self, x, y, w, h=None, a=45):
        h = h or w * 0.35
        sh = pygame.Surface((max(1, int(w * K)), max(1, int(h * K))), pygame.SRCALPHA)
        pygame.draw.ellipse(sh, (0, 0, 0, a), sh.get_rect())
        self.surf.blit(sh, (round((x - w / 2) * K), round((y - h / 2) * K)))

    def stamp(self, ink=2):
        """Commit the object layer with a dark outline around its silhouette (the Kenney ink look)."""
        r = self.layer.get_bounding_rect(1)
        if not r.w:
            return
        r = r.inflate(8, 8).clip(self.layer.get_rect())
        sub = self.layer.subsurface(r)
        if ink:
            sil = pygame.mask.from_surface(sub, 40).to_surface(setcolor=INK + (255,), unsetcolor=(0, 0, 0, 0))
            offs = [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)]
            for dx, dy in offs:
                self.surf.blit(sil, (r.x + dx, r.y + dy))
        self.surf.blit(sub, r.topleft)
        self.layer.fill((0, 0, 0, 0), r)

    def finish(self):
        mask = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        pygame.draw.polygon(mask, (255, 255, 255, 255), [(x * K, y * K) for x, y in hex_pts(R - 0.3, CX, CY)])
        self.surf.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        out = pygame.transform.smoothscale(self.surf, (W, H))
        return out.convert_alpha() if pygame.display.get_surface() else out


def _rng(city, stage, variant, tag=""):
    return random.Random(zlib.crc32(f"{city}|{stage}|{variant}|{tag}".encode()))


def _scatter_tufts(c, rng, col, n, keep=lambda x, y: True):
    for _ in range(n):
        x, y = rng.uniform(8, 112), rng.uniform(12, 128)
        if math.hypot(x - CX, y - CY) < R - 14 and keep(x, y):
            c.g.lines(col, [(x - 1.5, y), (x, y - 2.5), (x + 1.5, y)], 1)


def _onion(p, x, y, r, col):
    """Russian onion dome: a bulb, a little neck and a gold spike."""
    p.oval(shade(col, -0.25), x, y - r * 0.2, r * 0.82, r * 1.02)
    p.oval(col, x - r * 0.08, y - r * 0.2, r * 0.7, r * 0.95)
    p.rect(shade(col, -0.3), x - r * 0.25, y - r * 0.05, r * 0.5, r * 0.25)
    p.line(GOLD, (x, y - r * 1.25), (x, y - r * 1.9), 1.1)
    p.circle(GOLD, (x, y - r * 2.0), r * 0.18)


def _cross_cap(p, x, y, s=1.0, col=GOLD):
    p.line(col, (x, y), (x, y - 5 * s), 1.1)
    p.line(col, (x - 1.8 * s, y - 3.4 * s), (x + 1.8 * s, y - 3.4 * s), 1.0)


def _gondola(p, x, y, s=1.0, flip=False):
    f = -1 if flip else 1
    p.poly((34, 34, 44), [(x - 9 * s, y - 3 * s), (x + 9 * s, y - 3 * s), (x + 6 * s, y + 0.8 * s),
                          (x - 6 * s, y + 0.8 * s)])
    p.poly((64, 64, 78), [(x - 9 * s, y - 3 * s), (x + 9 * s, y - 3 * s), (x + 9 * s, y - 2 * s),
                          (x - 9 * s, y - 2 * s)])
    p.line(DWOOD, (x + f * 6 * s, y - 3 * s), (x + f * 9 * s, y - 11 * s), 1.2)
    p.poly((34, 34, 44), [(x + f * 7 * s, y - 11 * s), (x + f * 11 * s, y - 11 * s), (x + f * 9 * s, y - 13 * s)])


def _windows(p, x0, y0, w, h, rows, cols, col=DARK):
    for r in range(rows):
        for c in range(cols):
            p.rect(col, x0 + c * w / cols + w / cols * 0.35, y0 + r * h / rows + h / rows * 0.3,
                   max(1, w / cols * 0.3), max(1, h / rows * 0.35))


def _cube_row(p, x0, x1, y, h, n, cols, roofs, rng, d=4):
    """A row of small houses standing on baseline y between x0 and x1."""
    for i in range(n):
        x = lerp((x0, 0), (x1, 0), (i + 0.5) / n)[0] + rng.uniform(-1.5, 1.5)
        hh = h * rng.uniform(0.7, 1.1)
        w = (x1 - x0) / n * 0.7
        building(p, x, y, w, hh, d, rng.choice(cols), rng.choice(roofs), "front", door=False)


# ======================================================================================================
# 1. VENICE: a lagoon, the brick island, the campanile, the basilica domes and gondolas
# ======================================================================================================
def venice(c, s, v):
    rng = _rng("venice", s, v)
    c.fill(WATER)
    c.g.band((120, 186, 222), [(0, 118), (30, 112), (60, 116), (90, 110), (120, 114)], 6)
    k = (0.66, 0.84, 1.0)[s - 1]
    isl = [(16, 98), (30, 78), (52, 68), (72, 66), (92, 72), (104, 90), (100, 112), (78, 124), (42, 124), (20, 114)]
    isl = [(60 + (x - 60) * k, 96 + (y - 96) * k) for x, y in isl]
    c.g.poly(SAND, isl)
    c.g.lines(shade(SAND, -0.2), isl + [isl[0]], 1.2)
    for sx in (34, 56, 80):
        c.g.line(WATER_D, (sx + (s - 2) * 3, 58 + 40 * k), (sx + 6 * k, 124), 2.0)
    c.g.line(WATER_D, (60, 82 + 10 * k), (60, 126), 1.6)
    wall, roof = (236, 214, 180), (176, 96, 70)
    o = c.o
    # the blocks of houses along the island
    _cube_row(o, 24 * k + 36 * (1 - k), 96 - 36 * (1 - k), 116 - 2 * (1 - k), 14, 5 if s == 1 else 9,
              [wall, (232, 200, 166)], [roof, (168, 84, 64)], rng, d=5)
    if s == 1:
        tower(o, 60, 98, 4.5, 36, BRICK, roof=(160, 84, 62), cone=10)
        _gondola(o, 88, 110, 1.0)
    else:
        # campanile: the tall brick bell tower with a pyramid cap
        tower(o, 32, 88, 5.0, 46 if s == 3 else 36, BRICK, roof=(160, 84, 62), cone=14 if s == 3 else 10)
        o.rect((236, 228, 210), 28.5, 62 if s == 3 else 70, 7, 6)
        # basilica: domes over a cross-shaped body
        bx, by = 62, 96
        building(o, bx, by, 36, 14, 18, (232, 208, 170), roof, "flat", door=True)
        dome(o, bx - 8, by - 14, 6, (222, 176, 96))
        dome(o, bx + 6, by - 14, 6, (222, 176, 96))
        dome(o, bx - 1, by - 22, 8.5, (232, 188, 104))
        _cross_cap(o, bx - 1, by - 30.5, 1.0)
        if s == 3:
            # Doge's palace: a pink arcade with a little pinnacle row
            pal = 90 - 18 * (1 - k) + 2
            building(o, pal, 110, 24, 16, 10, (246, 196, 170), (150, 110, 100), "flat", door=False, wins=4)
            for i in range(4):
                o.rect((250, 226, 210), pal - 9 + i * 6, 102, 3, 6)
            _gondola(o, 26, 116, 1.0, flip=True)
            _gondola(o, 76, 84, 0.9)
    c.stamp()
    if s >= 2:
        _gondola(c.o, 20, 124, 0.85)
        _gondola(c.o, 94, 118, 0.85, flip=True)
        c.stamp()


# ======================================================================================================
# 2. CONSTANTINOPLE: the Golden Horn, Theodosian walls, the Hagia Sophia dome and minarets
# ======================================================================================================
def constantinople(c, s, v):
    rng = _rng("constantinople", s, v)
    c.fill((166, 168, 118))
    c.g.poly(WATER, [(68, 140), (72, 118), (92, 106), (120, 98), (120, 140)])
    c.g.lines(WATER_L, [(72, 124), (92, 114), (120, 106)], 1.5)
    for _ in range(4):
        c.g.line((240, 206, 110), (rng.uniform(80, 110), rng.uniform(118, 130)),
                 (rng.uniform(84, 112), rng.uniform(118, 130)), 1.0)
    _scatter_tufts(c, rng, (134, 146, 90), 40, keep=lambda x, y: not (x > 66 and y > 100))
    o = c.o
    stone, lead = (216, 210, 196), (190, 196, 204)
    # Theodosian walls: a long battlemented line with towers, thicker at the later stages
    wall_pts = [(4, 104), (30, 98), (56, 100), (84, 96), (112, 92)]
    if s >= 2:
        wall_pts = [(2, 110), (24, 104), (46, 104), (66, 100), (92, 98), (112, 96)]
    c.g.band(shade(stone, -0.3), [(x, y + 2) for x, y in wall_pts], 6.5 if s < 3 else 8)
    c.g.band(stone, wall_pts, 5.5 if s < 3 else 7)
    towers_at = [0.12, 0.42, 0.72, 0.98] if s == 1 else [0.08, 0.26, 0.45, 0.62, 0.8, 0.98]
    for t in towers_at:
        x, y = wall_pts[0][0] + (wall_pts[-1][0] - wall_pts[0][0]) * t, 0
        seg = min(range(len(wall_pts) - 1), key=lambda i: abs(wall_pts[i][0] - x))
        a, b = wall_pts[seg], wall_pts[seg + 1]
        y = lerp(a, b, (x - a[0]) / max(1, b[0] - a[0]))[1]
        tower(o, x, y + 2, 3.8, 16, stone, roof=(120, 110, 98), cone=5, crenel=True)
    # Hagia Sophia: the great dome on a wide body, with four minarets
    bx, by = 58, 80
    if s == 1:
        building(o, bx, by, 34, 9, 14, (240, 234, 220), lead, "flat")
        dome(o, bx, by - 9, 11, lead)
        tower(o, bx + 22, by + 4, 2.4, 26, (240, 236, 226), roof=(96, 106, 124), cone=8)
    else:
        building(o, bx, by, 46, 10, 18, (240, 234, 220), lead, "flat")
        dome(o, bx, by - 10, 15, lead)
        for dx in (-7, 7):
            dome(o, bx + dx * 1.4, by - 10 - 4, 5, lead)
        _cross_cap(o, bx, by - 25, 1.0, col=(236, 200, 90))
        mins = [(bx - 28, by + 8), (bx + 28, by + 8)]
        if s == 3:
            mins += [(bx - 36, by - 6), (bx + 36, by - 6)]
        for mx, my in mins:
            tower(o, mx, my, 2.8, 34 if s == 3 else 30, (240, 236, 226), roof=(96, 106, 124), cone=9)
            o.rect(shade((240, 236, 226), -0.2), mx - 3.2, my - 26, 6.4, 1.4)
    if s == 3:
        # a few carracks in the Horn and a gold crescent on the dome
        boat(o, 84, 118, 1.0, sail=(246, 240, 226), flip=True)
        boat(o, 102, 110, 0.8, sail=(204, 80, 60))
        o.poly(GOLD, [(58, 40), (62, 40), (62, 46)])
    c.stamp()
    if s >= 2:
        for _ in range(6 if s == 2 else 10):
            x, y = rng.uniform(16, 100), rng.uniform(116, 128)
            if x < 64 and y > 108:
                continue
            building(c.o, x, y, rng.uniform(7, 9), rng.uniform(5, 8), 5, (222, 186, 150),
                     ROOF_RED, "front", door=False)
        c.stamp()


# ======================================================================================================
# 3. PARIS: the Seine, the Ile de la Cite, Notre-Dame's west towers and spire
# ======================================================================================================
def paris(c, s, v):
    rng = _rng("paris", s, v)
    c.fill((118, 170, 96))
    for _ in range(14):
        x, y = rng.uniform(8, 112), rng.uniform(14, 126)
        c.g.rect((100 + rng.randint(0, 20), 158, 86), x, y, 10, 6)
    river = [(-4, 78), (22, 84), (42, 96), (60, 98), (78, 96), (98, 88), (124, 74)]
    c.g.band(WATER, river, 14)
    c.g.band(WATER_L, [(x, y - 2) for x, y in river], 3)
    island = [(46, 92), (56, 86), (70, 86), (80, 92), (76, 99), (58, 101), (48, 98)]
    c.g.poly((204, 194, 170), island)
    c.g.lines(shade((204, 194, 170), -0.3), island + [island[0]], 1.0)
    o = c.o
    stone = (214, 206, 190)
    if s >= 2:
        # the bridges across the Seine, and the houses on the banks
        for bx in (34, 84):
            o.rect((214, 204, 184), bx - 5, 86 + (bx - 34) * 0.0, 10, 8)
        for i in range(6 if s == 2 else 10):
            x = rng.uniform(10, 110)
            y = 72 + rng.uniform(-2, 4) if x < 60 else 92 + rng.uniform(0, 18)
            if 42 < x < 86 and 84 < y < 104:
                continue
            building(o, x, y, rng.uniform(7, 9), rng.uniform(6, 9), 5, rng.choice([(226, 206, 180), (210, 196, 176)]),
                     rng.choice([ROOF_RED, SLATE]), "front", door=False)
    c.stamp()
    o = c.o
    # Notre-Dame: west towers with pointed slate caps, a nave box, and the spire at stage 3
    nx, ny = 60, 88
    # the two west towers always show (the silhouette people know); the nave and spire come with growth
    th = {1: 30, 2: 40, 3: 46}[s]
    o.rect(shade(stone, -0.05), nx - 12, ny - 14, 24, 12)
    for tx in (nx - 12, nx + 6):
        tower(o, tx, ny - 4, 4.4, th, stone, roof=SLATE, cone=16 if s == 1 else 20)
        o.oval(shade(stone, -0.1), tx, ny - th - 3, 2.4, 2.4)
    o.circle((118, 104, 130), (nx - 0.5, ny - 20), 3.4)            # rose window
    o.circle(shade(stone, -0.4), (nx - 0.5, ny - 20), 1.4)
    if s >= 2:
        o.oval(shade(stone, -0.2), nx - 0.5, ny - 18, 4, 3)
        if s == 3:
            # the flying buttresses and the crossing spire
            o.poly(SLATE, [(nx - 2.5, ny - 20), (nx + 2.5, ny - 20), (nx + 0.5, ny - 58), (nx - 0.5, ny - 58)])
            o.poly(shade(SLATE, -0.3), [(nx + 0.5, ny - 20), (nx + 2.5, ny - 20), (nx + 0.5, ny - 58)])
            for d in (-1, 1):
                o.line(stone, (nx + d * 10, ny - 4), (nx + d * 4, ny - 12), 1.4)
    c.stamp()


# ======================================================================================================
# 4. LONDON: the Thames, London Bridge with its houses, the White Tower and old St Paul's spire
# ======================================================================================================
def london(c, s, v):
    rng = _rng("london", s, v)
    c.fill((132, 170, 98))
    river = [(-4, 110), (24, 104), (52, 110), (80, 104), (124, 98)]
    c.g.band((100, 134, 158), river, 15)
    c.g.band((150, 190, 206), [(x, y - 3) for x, y in river], 3)
    _scatter_tufts(c, rng, (98, 140, 74), 30, keep=lambda x, y: y < 96)
    o = c.o
    stone = (200, 196, 186)
    # London Bridge: a stone causeway on arches, with a row of houses
    if s >= 2:
        for ax in (42, 52, 62, 72):
            o.oval((120, 110, 100), ax, 108, 4.5, 3.5)
        o.rect((208, 202, 190), 36, 101, 48, 5)
        bn = 5 if s == 2 else 8
        for i in range(bn):
            hx = 38 + i * (44 / bn) + 2
            building(o, hx, 101, 6.5, rng.uniform(8, 13), 4, rng.choice([(236, 202, 166), (216, 184, 150)]),
                     rng.choice([ROOF_RED, (150, 90, 70)]), "front", door=False)
    # the White Tower and its wall towers on the left bank
    ww = (234, 232, 224)
    building(o, 24, 92, 22, 20, 14, ww, (190, 190, 200), "flat", door=True, wins=2)
    for i in range(4):
        o.rect(shade(ww, -0.25), 13 + i * 5, 72, 2.5, 3)
    tower(o, 10, 96, 4.0, 20 if s < 3 else 26, stone, crenel=True)
    if s == 3:
        tower(o, 40, 92, 3.6, 22, stone, roof=(120, 96, 80), cone=8)
    # old St Paul's: a grey nave with a tall spire
    px = 88
    building(o, px, 88, 22, 14, 12, (168, 168, 176), (120, 120, 132), "flat", door=False, wins=3)
    if s == 1:
        o.poly((150, 150, 160), [(px - 4, 74), (px + 4, 74), (px + 0.4, 50), (px - 0.4, 50)])
    elif s == 2:
        o.poly((150, 150, 160), [(px - 5, 74), (px + 5, 74), (px + 0.6, 36), (px - 0.6, 36)])
        o.poly(shade((150, 150, 160), -0.3), [(px + 0.2, 74), (px + 5, 74), (px + 0.6, 36)])
    else:
        o.poly((150, 150, 160), [(px - 7, 74), (px + 7, 74), (px + 1, 16), (px - 1, 16)])
        o.poly(shade((150, 150, 160), -0.3), [(px + 1, 74), (px + 7, 74), (px + 1, 16)])
        o.line((120, 120, 132), (px, 16), (px, 10), 1.2)
        o.poly((160, 160, 170), [(px - 4, 80), (px + 4, 80), (px + 4, 74), (px - 4, 74)])
    c.stamp()
    if s >= 2:
        c.o.poly(WHITE, [(20, 110), (26, 110), (26, 114), (20, 114)])
        c.stamp()
        for x in (22, 104):
            boat(c.o, x, 114, 0.7, sail=(246, 246, 240))
        c.stamp()


# ======================================================================================================
# 5. LISBON: the Tagus, the hillside houses in tiers, the Belem tower and caravels
# ======================================================================================================
def lisbon(c, s, v):
    rng = _rng("lisbon", s, v)
    c.fill((196, 160, 106))
    c.g.poly((120, 114, 112), [(0, 100), (120, 94), (120, 140), (0, 140)])
    c.g.poly(WATER, [(0, 112), (30, 106), (60, 110), (96, 104), (120, 108), (120, 140), (0, 140)])
    c.g.lines(WHITE, [(0, 112), (30, 106), (60, 110), (96, 104), (120, 108)], 1.5)
    hills = [(0, 100), (16, 84), (40, 74), (66, 72), (92, 80), (120, 92)]
    c.g.poly((176, 138, 92), hills + [(120, 110), (0, 110)])
    c.g.poly((150, 118, 74), [(40, 74), (66, 72), (92, 80), (120, 92), (120, 110), (60, 110)])
    # terraces: the steps of the hillside that the houses sit on
    for tier in ([(14, 92), (40, 84), (66, 82), (92, 90), (118, 100)],
                 [(20, 104), (44, 98), (70, 98), (100, 104)]):
        c.g.lines(shade((176, 138, 92), -0.22), tier, 1.6)
    for _ in range(12):
        x, y = rng.uniform(4, 116), rng.uniform(70, 110)
        c.g.line((130, 150, 90), (x, y), (x + 4, y), 1.5)
    o = c.o
    houses = [(56, 84), (76, 84), (46, 92), (72, 96), (90, 96), (30, 100), (96, 104), (62, 102)]
    if s == 1:
        houses = houses[:4]
    if s >= 2:
        for x, y in houses:
            if s == 2 and (x, y) in ((96, 104), (30, 100)):
                continue
            building(o, x, y, 8, rng.uniform(6, 8), 5, rng.choice([(246, 240, 226), (240, 210, 170)]),
                     rng.choice([ROOF_RED, (186, 96, 70)]), "front", door=False)
    # Belem tower, a white limestone drum with turrets, on the river edge
    bx, by = 22, 108
    tower(o, bx, by, 6.0, 30, (240, 236, 226), roof=(176, 120, 76), cone=9, crenel=True)
    o.oval((240, 236, 226), bx, by - 30, 4.4, 3.2)
    # Se cathedral: twin towers with a heavy roof
    if s >= 2:
        cx_, cy_ = 70, 78
        tower(o, cx_ - 6, cy_, 3.4, 26, (226, 206, 170), roof=(120, 96, 76), cone=8)
        tower(o, cx_ + 6, cy_, 3.4, 26, (226, 206, 170), roof=(120, 96, 76), cone=8)
        o.rect((226, 206, 170), cx_ - 8, cy_ - 8, 16, 10)
    if s == 3:
        # St George's castle on the top of the hill
        cxs = 36
        o.rect((230, 220, 196), cxs - 14, 52, 28, 12)
        for i in range(5):
            o.rect((230, 220, 196), cxs - 14 + i * 6, 49, 3, 4)
        o.rect(shade((230, 220, 196), -0.2), cxs + 14, 40, 3, 22)
        flag(o, cxs + 15, 40, 10, (220, 60, 60))
    c.stamp()
    # caravels in the Tagus
    if s == 1:
        boat(c.o, 74, 118, 1.0, sail=WHITE)
    else:
        boat(c.o, 74, 120, 1.0, sail=WHITE)
        boat(c.o, 100, 116, 0.8, sail=(220, 80, 70), flip=True)
        if s == 3:
            boat(c.o, 46, 122, 0.8, sail=WHITE)
    c.stamp()


# ======================================================================================================
# 6. ROME: the Tiber, Castel Sant'Angelo's drum, St Peter's dome, colonnade and obelisk
# ======================================================================================================
def rome(c, s, v):
    rng = _rng("rome", s, v)
    c.fill((150, 178, 102))
    _scatter_tufts(c, rng, (120, 152, 84), 36)
    tib = [(62, -4), (68, 22), (58, 48), (70, 72), (84, 96), (92, 118), (84, 144)]
    c.g.band(WATER, tib, 12)
    c.g.band(WATER_L, [(x + 2, y) for x, y in tib], 3)
    for x, y in [(56, 24), (62, 60), (88, 112)]:
        c.g.poly((226, 206, 150), [(x - 6, y), (x, y - 2), (x + 6, y + 1), (x, y + 3)])
    o = c.o
    stone = (234, 224, 200)
    # Castel Sant'Angelo: a round drum on the right bank, with the angel's spire
    ax, ay = 94, 96
    tower(o, ax, ay, 9.0, 22, (224, 206, 170), roof=(166, 120, 90), cone=8)
    o.oval((226, 210, 178), ax, ay - 22, 9.0, 3.2)
    o.rect((226, 210, 178), ax - 1.5, ay - 36, 3, 14)
    o.oval((222, 200, 170), ax, ay - 36, 3.5, 2.6)
    if s == 1:
        c.stamp()
        return
    # St Peter's: the basilica front and the great dome, with a colonnade on the piazza
    px, py = 36, 88
    building(o, px, py, 42, 14, 16, stone, (196, 176, 150), "flat", door=True)
    dome(o, px, py - 14, 16 if s == 3 else 12, (218, 226, 230))
    o.line((190, 196, 200), (px, py - 14 - (16 if s == 3 else 12)), (px, py - 36), 1.0)
    o.oval((244, 238, 226), px, py - 14, 3, 3)
    if s == 3:
        # a colonnade on both sides of the piazza
        for side in (-1, 1):
            for i in range(5):
                cx_ = px + side * (26 + i * 2.2)
                o.rect((236, 228, 214), cx_ - 1.2, py + 2 + i * 0.4, 2.4, 9)
        o.poly(shade(stone, -0.1), [(px - 31, py + 3), (px + 31, py + 3), (px + 26, py + 10), (px - 26, py + 10)])
        # the obelisk in the piazza
        o.poly((200, 176, 150), [(px + 8, py + 14), (px + 10, py + 14), (px + 10, py - 4), (px + 8, py - 4)])
        o.poly((214, 186, 150), [(px + 8, py - 4), (px + 10, py - 4), (px + 9, py - 9)])
        # houses of the Trastevere bank
        for hx, hy in [(60, 112), (74, 118), (106, 122)]:
            building(o, hx, hy, 8, 6, 5, (238, 220, 186), ROOF_RED, "front", door=False)
    c.stamp()


# ======================================================================================================
# 7. SEVILLE: the Guadalquivir, the Giralda belfry, the cathedral, Torre del Oro and Indies ships
# ======================================================================================================
def seville(c, s, v):
    rng = _rng("seville", s, v)
    c.fill((222, 178, 110))
    riv = [(-4, 118), (24, 120), (54, 126), (84, 120), (124, 110)]
    c.g.band(WATER, riv, 18)
    c.g.band(WATER_L, [(x, y - 4) for x, y in riv], 4)
    _scatter_tufts(c, rng, (172, 150, 88), 20, keep=lambda x, y: y < 110)
    o = c.o
    # the Giralda: a brick tower with white bands, a bell belfry and the weathervane
    gx, gy = 48, 98
    gh = {1: 40, 2: 58, 3: 66}[s]
    brick = (206, 120, 82)
    o.poly(shade(brick, -0.25), [(gx + 3, gy), (gx + 8, gy - 4), (gx + 8, gy - gh), (gx + 3, gy - gh)])
    o.rect(brick, gx - 6, gy - gh, 12, gh)
    for yy in range(int(gy - gh + 4), int(gy), 6):
        o.rect((240, 228, 210), gx - 6, yy, 12, 1.6)
    if s >= 2:
        o.rect(shade(brick, 0.1), gx - 7, gy - gh - 6, 14, 6)
        for k in range(-1, 2):
            o.rect(DARK, gx + k * 4 - 1.2, gy - gh - 4, 2.4, 3.6)
    o.poly(shade(brick, -0.1), [(gx - 7, gy - gh - 6), (gx + 7, gy - gh - 6), (gx, gy - gh - 14)])
    o.line(GOLD, (gx, gy - gh - 14), (gx, gy - gh - 22), 1.2)
    o.poly(GOLD, [(gx, gy - gh - 22), (gx + 4, gy - gh - 20), (gx, gy - gh - 18)])
    # cathedral nave and roof
    cxw, cyw = 74, 110
    building(o, cxw, cyw, 30, 10, 18, (240, 232, 214), (160, 96, 68), "flat", door=False)
    if s >= 2:
        for k in range(3):
            dome(o, cxw - 8 + k * 8, cyw - 10, 4, (216, 170, 100)) if k == 1 else None
    if s == 3:
        # Torre del Oro: a gold round tower at the water's edge
        tower(o, 102, 110, 4.4, 20, (240, 206, 120), crenel=True)
        palm(o, 12, 104, 26, 3)
        palm(o, 106, 96, 22, -2)
    c.stamp()
    if s >= 2:
        for x in (20, 90):
            boat(c.o, x, 124, 0.7 if x < 60 else 0.9, sail=(246, 242, 228))
        c.stamp()
    if s == 3:
        boat(c.o, 66, 128, 1.1, sail=(186, 62, 56), flip=True)
        c.stamp()


# ======================================================================================================
# 8. CAIRO: the Nile strip on sand, the citadel on its hill with minarets, pyramids in the distance
# ======================================================================================================
def cairo(c, s, v):
    rng = _rng("cairo", s, v)
    c.fill((236, 210, 150))
    c.g.poly(GREEN, [(0, 0), (48, 0), (44, 56), (30, 90), (36, 140), (0, 140)])
    c.g.band(WATER, [(54, 0), (52, 40), (44, 80), (46, 120), (42, 150)], 9)
    c.g.band(WATER_L, [(50, 0), (48, 40), (41, 80), (43, 120)], 2)
    for _ in range(18):
        x, y = rng.uniform(4, 40), rng.uniform(4, 130)
        c.g.circle(GREEN_D, (x, y), 1.8)
    if s == 3:
        c.g.poly((186, 160, 110), [(66, 42), (92, 16), (120, 42), (120, 42)])
        c.g.poly((160, 134, 92), [(92, 16), (120, 42), (96, 42)])
    o = c.o
    stone = (234, 218, 180)
    hill = [(62, 136), (66, 100), (86, 84), (106, 84), (120, 92), (120, 140)]
    c.g.poly((206, 170, 118), hill)
    c.g.poly((178, 144, 96), [(86, 84), (106, 84), (120, 92), (120, 140), (98, 140)])
    if s == 1:
        building(o, 88, 102, 14, 8, 8, stone, (170, 110, 80), "flat", door=True)
        tower(o, 84, 94, 2.8, 22, stone, roof=(64, 150, 100), cone=9)
        palm(o, 28, 104, 24, 2)
    else:
        wx0, wx1 = 68, 118
        o.rect(shade(stone, -0.15), wx0, 98, wx1 - wx0, 10)
        for i in range(6):
            o.rect(stone, wx0 + i * 9, 95, 4, 3)
        mins = [(70, 84), (94, 78), (108, 90)] if s == 2 else [(68, 80), (84, 70), (100, 74), (112, 88)]
        for mx, my in mins:
            tower(o, mx, my, 2.6, 32 if s == 2 else 36, stone, roof=(64, 150, 100), cone=10)
        dome(o, 86, 96, 9, (230, 222, 204))
        if s == 3:
            palm(o, 26, 100, 26, 3)
            palm(o, 14, 116, 22, -2)
            building(o, 46, 116, 12, 8, 8, (240, 226, 190), (170, 110, 80), "flat", door=True)
            building(o, 32, 126, 10, 6, 6, (232, 214, 176), (170, 110, 80), "flat", door=False)
    c.stamp()


# ======================================================================================================
# 9. MOSCOW: snow, the red brick Kremlin walls with towers and the onion domes
# ======================================================================================================
def moscow(c, s, v):
    rng = _rng("moscow", s, v)
    c.fill((234, 242, 246))
    c.g.band((156, 196, 226), [(0, 118), (30, 110), (56, 120), (84, 112), (120, 120)], 6)
    _scatter_tufts(c, rng, (176, 200, 212), 30)
    o = c.o
    brick = (182, 74, 62)
    wall = [(26, 96), (34, 84), (50, 78), (74, 78), (92, 84), (96, 96), (92, 108), (74, 116), (50, 116), (32, 108)]
    if s == 1:
        wall = wall[:6] + [(34, 108), (32, 96)]
    c.g.poly(shade(brick, -0.3), [(x, y + 3) for x, y in wall])
    c.g.poly(brick, wall)
    # Kremlin towers: red bodies with green pointed roofs
    tpos = [(26, 96), (62, 78), (96, 96), (50, 116)] if s >= 2 else [(62, 78), (34, 96)]
    for tx, ty in tpos:
        tower(o, tx, ty + 4, 3.8, 18 if s == 1 else 24, brick, roof=(56, 130, 96), cone=9, crenel=True)
    if s == 1:
        _onion(o, 62, 66, 5.5, (56, 130, 180))
    if s >= 2:
        _onion(o, 62, 62, 6.5, (232, 176, 60))
        _onion(o, 38, 84, 4.5, (60, 150, 110))
        _onion(o, 84, 84, 4.5, (60, 110, 190))
    if s == 3:
        # the St Basil cluster: stripy onion domes in many colours
        for (x, y, r, col) in [(56, 96, 3.2, (224, 60, 60)), (68, 96, 3.6, (56, 130, 180)),
                               (74, 110, 3.2, (226, 186, 70)), (50, 110, 3.0, (240, 250, 255)),
                               (62, 110, 4.0, (126, 60, 180))]:
            _onion(o, x, y, r, col)
        _onion(o, 96, 66, 3.5, (220, 110, 60))
        building(o, 72, 100, 16, 8, 8, (240, 226, 216), (196, 96, 66), "flat", door=True)
    c.stamp()
    if s >= 2:
        for x, y in [(104, 116), (14, 120)]:
            building(c.o, x, y, 9, 7, 6, (236, 220, 196), (150, 110, 80), "front", door=False)
        for x, y in [(20, 80), (110, 92)]:
            pine(c.o, x, y, 16, col=(40, 110, 70), snow=True)
        c.stamp()


# ======================================================================================================
# 10. GRANADA: the Alhambra's red palace towers on the hill, cypresses, Sierra Nevada snow
# ======================================================================================================
def granada(c, s, v):
    rng = _rng("granada", s, v)
    c.fill((150, 178, 110))
    _scatter_tufts(c, rng, (116, 150, 88), 26)
    if s >= 2:
        c.g.poly((244, 246, 248), [(0, 46), (26, 14), (54, 40), (62, 36), (96, 2), (120, 24), (120, 46), (0, 46)])
        c.g.poly((200, 214, 226), [(26, 14), (30, 26), (22, 38), (0, 46), (0, 26)])
        c.g.poly((200, 214, 226), [(96, 2), (100, 14), (92, 26), (120, 24), (120, 14)])
    hill = [(-4, 140), (-2, 96), (20, 80), (44, 70), (70, 74), (96, 88), (124, 98), (124, 140)]
    c.g.poly((190, 150, 104), hill)
    c.g.poly((164, 128, 90), [(44, 70), (70, 74), (96, 88), (124, 98), (124, 140), (72, 140), (60, 110)])
    o = c.o
    red = (196, 110, 80)
    cyp = (38, 96, 66)
    if s == 1:
        tower(o, 50, 84, 4.2, 26, red, roof=None, crenel=True)
        flag(o, 50, 58, 10, (236, 210, 90))
        pine(o, 84, 100, 16, col=cyp)
        pine(o, 28, 110, 14, col=cyp)
    else:
        # the palace block with the Torre de la Vela on its corner and the high towers
        building(o, 58, 96, 40, 14, 16, (206, 122, 88), (176, 92, 64), "flat", door=True, wins=3)
        tower(o, 36, 86, 5.0, 40 if s == 2 else 46, red, roof=None, crenel=True)
        flag(o, 36, 46 if s == 3 else 50, 12, (236, 210, 90))
        tower(o, 82, 84, 3.6, 22, red, roof=(170, 90, 64), cone=8, crenel=True)
        for i in range(6):
            o.rect((236, 218, 196), 42 + i * 6, 102, 2.4, 6)
        pine(o, 104, 104, 18, col=cyp)
        pine(o, 16, 116, 16, col=cyp)
        if s == 3:
            for x, y in [(104, 124), (82, 124), (22, 130)]:
                pine(o, x, y, 16, col=cyp)
            building(o, 98, 120, 10, 6, 6, (240, 232, 214), (176, 96, 66), "front", door=False)
            building(o, 20, 96, 8, 6, 6, (244, 236, 220), (176, 96, 66), "front", door=False)
    c.stamp()


DRAWERS = {"venice": venice, "constantinople": constantinople, "paris": paris, "london": london,
           "lisbon": lisbon, "rome": rome, "seville": seville, "cairo": cairo, "moscow": moscow,
           "granada": granada}


def draw_city(name, stage, variant=0):
    """A 120 x 140 landmark tile for `name` at growth `stage` (1 town, 2 city, 3 great capital)."""
    c = Canvas()
    DRAWERS[name](c, max(1, min(3, int(stage))), variant)
    return c.finish()
