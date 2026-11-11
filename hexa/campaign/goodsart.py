"""Province investment tiles: one hand-drawn landmark per trade good, growing over five levels.

Every good has its own ground (colour and pattern) and its own landmark silhouette, so a tile reads at a glance
even at map size. The five levels of one good are the same place growing: the ground layout is seeded by
good + variant only, and each level adds to it (more terraces, a bigger building, more boats, flags ...).

Drawing happens at 2x on a 240 x 280 canvas (all coordinates below are in the 120 x 140 tile space and scaled
by the Pen) and is smooth-scaled down at the end. Objects are drawn on a scratch layer and "stamped" with a dark
ink outline, in the flat two-tone style of the Kenney hexagon pack (lit left faces, darker right faces).
"""
import math
import os
import random
import zlib

import pygame

from hexa.campaign.art import hex_pts, shade

W, H = 120, 140
CX, CY = W / 2, H / 2
R = 69.3
K = 2                                     # supersampling factor
INK = (45, 45, 50)

# shared palette
CREAM = (240, 230, 205)
STONE = (205, 200, 188)
WOOD = (150, 104, 64)
DWOOD = (110, 76, 46)
ROOF_RED = (214, 96, 66)
ROOF_SLATE = (96, 106, 124)
THATCH = (218, 178, 96)
WHITE = (250, 250, 246)
DARK = (40, 34, 36)
WATER = (78, 160, 212)
WATER_L = (130, 200, 232)
SKIN = (238, 200, 165)

GOODS_ART = {
    "grain": ["Wheat strips", "Open fields", "Grange barn", "Windmill farm", "Manor estate"],
    "wine": ["Hillside vines", "Terraced vineyard", "Press house", "Wine cellars", "Chateau"],
    "wool": ["Upland grazing", "Walled pastures", "Shepherd's hut", "Sheepfolds", "Wool barn"],
    "cotton": ["Cotton patch", "Cotton fields", "Drying sheds", "Cotton farm", "Gin house"],
    "sugar": ["Cane patch", "Cane fields", "Boiling house", "Sugar works", "Sugar mill"],
    "tobacco": ["Tobacco patch", "Tobacco fields", "Curing barn", "Tobacco farm", "Tobacco warehouse"],
    "timber": ["Woodcutters' clearing", "Logging camp", "Sawpit", "Sawmill", "Timber yard"],
    "iron": ["Iron diggings", "Iron mine", "Ore tramway", "Bloomery", "Ironworks"],
    "silver": ["Silver vein", "Silver mine", "Deep workings", "Stamp mill", "Royal mint"],
    "gold": ["Gold panning", "Placer claim", "Sluice works", "Gold diggings", "Fortified gold mine"],
    "salt": ["Salt pans", "Salt marsh works", "Salt mounds", "Saltern", "Salt house"],
    "fish": ["Fishing beach", "Fishing jetty", "Fishing village", "Fishing pier", "Fishing harbour"],
    "furs": ["Trapline", "Trapper's lodge", "Trapping camp", "Fur post", "Fur trading fort"],
    "ivory": ["Elephant grounds", "Hunting camp", "Trading hut", "Ivory market", "Ivory fort"],
    "spices": ["Spice garden", "Spice grove", "Drying yard", "Spice plantation", "Spice warehouse"],
    "horses": ["Horse corral", "Round paddock", "Stables", "Stud farm", "Royal stud"],
    "cattle": ["Grazing meadow", "Cattle pasture", "Cattle barn", "Cattle ranch", "Cattle estate"],
    "stone": ["Stone cutting", "Quarry", "Crane quarry", "Deep quarry", "Marble works"],
    "copper": ["Copper outcrop", "Copper diggings", "Copper mine", "Roasting yard", "Copper smelter"],
    "hemp": ["Hemp & flax plot", "Hemp fields", "Retting ponds", "Rope yard", "Ropewalk"],
    "olives": ["Olive trees", "Olive terraces", "Olive farm", "Oil jars", "Olive press"],
    "silk": ["Mulberry hedges", "Mulberry orchard", "Silkworm sheds", "Silk farm", "Silk caravanserai"],
    "dyes": ["Dye vats", "Dye yard", "Dye works", "Cloth dyers", "Dye house"],
    "cocoa": ["Cocoa grove", "Cocoa clearing", "Drying mats", "Cocoa plantation", "Cocoa hacienda"],
    "coffee": ["Coffee shrubs", "Coffee terraces", "Drying patios", "Coffee estate", "Coffee tower house"],
}


# ----- pen: draws in tile coordinates on the 2x canvas ------------------------------------------------
def _w(w):
    return 0 if not w else max(1, round(w * K))


class Pen:
    def __init__(self, surf):
        self.s = surf

    def poly(self, c, pts, w=0):
        if len(pts) > 2:
            pygame.draw.polygon(self.s, c, [(x * K, y * K) for x, y in pts], _w(w))

    def circle(self, c, xy, r, w=0):
        pygame.draw.circle(self.s, c, (xy[0] * K, xy[1] * K), max(0.5, r * K), _w(w))

    def ellipse(self, c, x, y, w, h, wd=0):
        pygame.draw.ellipse(self.s, c, pygame.Rect(round(x * K), round(y * K), max(1, round(w * K)),
                                                   max(1, round(h * K))), _w(wd))

    def oval(self, c, cx, cy, rx, ry, wd=0):
        self.ellipse(c, cx - rx, cy - ry, rx * 2, ry * 2, wd)

    def line(self, c, a, b, w=1):
        pygame.draw.line(self.s, c, (a[0] * K, a[1] * K), (b[0] * K, b[1] * K), max(1, round(w * K)))

    def lines(self, c, pts, w=1, closed=False):
        if len(pts) > 1:
            pygame.draw.lines(self.s, c, closed, [(x * K, y * K) for x, y in pts], max(1, round(w * K)))

    def band(self, c, pts, w):
        """A thick polyline with round joints (rivers, tracks, walls)."""
        self.lines(c, pts, w)
        for x, y in pts:
            self.circle(c, (x, y), w / 2 - 0.25)

    def rect(self, c, x, y, w, h, wd=0, br=0):
        pygame.draw.rect(self.s, c, pygame.Rect(round(x * K), round(y * K), max(1, round(w * K)),
                                                max(1, round(h * K))), _w(wd), round(br * K))


def ell(cx, cy, rx, ry, a0=0, a1=360, n=36):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def mix(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


# ----- sprites from the pack -----------------------------------------------------------------------------
_SPR = {}


def _spr(tiles_dir, name, scale=1.0):
    key = (tiles_dir, name, scale)
    if key not in _SPR:
        img = pygame.image.load(os.path.join(os.path.dirname(tiles_dir), "Objects", name + ".png"))
        if pygame.display.get_surface():
            img = img.convert_alpha()
        _SPR[key] = pygame.transform.smoothscale(img, (max(1, int(img.get_width() * scale * K)),
                                                       max(1, int(img.get_height() * scale * K))))
    return _SPR[key]


_MASK = {}


def _hex_mask():
    if "m" not in _MASK:
        m = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        pygame.draw.polygon(m, (255, 255, 255, 255), [(x * K, y * K) for x, y in hex_pts(R - 0.3)])
        _MASK["m"] = m
    return _MASK["m"]


_OFFS = [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)]
_OFFS_THIN = [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)]


class Tile:
    """Builder for one tile: ground pen `g`, object-layer pen `o`, `stamp()` commits the layer with an outline."""

    def __init__(self, good, level, variant, tiles_dir):
        self.good, self.lv, self.v, self.td = good, level, variant % 3, tiles_dir
        self.flip = self.v == 1
        self.surf = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        self.layer = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
        self.g = Pen(self.surf)
        self.o = Pen(self.layer)

    def r(self, tag=""):
        """A random source that depends on good, variant and tag only, so every level shares one layout."""
        return random.Random(zlib.crc32(f"{self.good}|{self.v}|{tag}".encode()))

    def X(self, dx):
        return CX - dx if self.flip else CX + dx

    def at(self, dx, dy):
        return (self.X(dx), CY + dy)

    def pts(self, rel):
        return [self.at(dx, dy) for dx, dy in rel]

    def ground(self, color, rim=True):
        self.surf.fill(color)
        if rim:
            self.g.poly(shade(color, -0.1), hex_pts(R - 1), 3)

    def shadow(self, x, y, w, h=None, a=45):
        h = h or w * 0.35
        sh = pygame.Surface((max(1, int(w * K)), max(1, int(h * K))), pygame.SRCALPHA)
        pygame.draw.ellipse(sh, (0, 0, 0, a), sh.get_rect())
        self.surf.blit(sh, (round((x - w / 2) * K), round((y - h / 2) * K)))

    def stamp(self, ink=2):
        r = self.layer.get_bounding_rect(1)
        if not r.w:
            return
        r = r.inflate(8, 8).clip(self.layer.get_rect())
        sub = self.layer.subsurface(r)
        if ink:
            sil = pygame.mask.from_surface(sub, 40).to_surface(setcolor=INK + (255,), unsetcolor=(0, 0, 0, 0))
            for dx, dy in (_OFFS if ink >= 2 else _OFFS_THIN):
                self.surf.blit(sil, (r.x + dx, r.y + dy))
        self.surf.blit(sub, r.topleft)
        self.layer.fill((0, 0, 0, 0), r)

    def sprite(self, name, x, y, scale=1.0, flip=False):
        img = _spr(self.td, name, scale)
        if flip:
            img = pygame.transform.flip(img, True, False)
        self.surf.blit(img, (round(x * K - img.get_width() / 2), round(y * K - img.get_height())))

    def finish(self):
        self.surf.blit(_hex_mask(), (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        out = pygame.transform.smoothscale(self.surf, (W, H))
        return out.convert_alpha() if pygame.display.get_surface() else out


# ----- shared object drawings (all on a pen, in tile coordinates) ---------------------------------------
def building(p, x, y, w, h, d, wall, roof, kind="front", rh=None, door=True, wins=0, side_wall=None):
    """A box house seen from the front-left: front face lit, right side darker. (x, y) is the front-bottom centre.
    kind: 'front' (gable facing us), 'side' (ridge parallel to the front), 'flat', 'hip'. Returns the roof top."""
    dx, dy = d * 0.55, -d * 0.42
    x0, x1 = x - w / 2, x + w / 2
    side = side_wall or shade(wall, -0.28)
    rl, rd = roof, shade(roof, -0.3)
    A, B, Bt, At = (x0, y), (x1, y), (x1, y - h), (x0, y - h)
    BD, BtD, AtD = (x1 + dx, y + dy), (x1 + dx, y - h + dy), (x0 + dx, y - h + dy)
    top = (x, y - h)
    if kind == "flat":
        p.poly(side, [B, BD, BtD, Bt])
        p.poly(wall, [A, B, Bt, At])
        p.poly(shade(roof, 0.1), [At, Bt, BtD, AtD])
    elif kind in ("side", "hip"):
        rh = h * 0.8 if rh is None else rh
        inset = w * 0.18 if kind == "hip" else 0
        rL, rR = (x0 + dx / 2 + inset, y - h - rh + dy / 2), (x1 + dx / 2 - inset, y - h - rh + dy / 2)
        p.poly(rd, [AtD, BtD, rR, rL])
        p.poly(side, [B, BD, BtD, Bt] if kind == "hip" else [B, BD, BtD, rR, Bt])
        if kind == "hip":
            p.poly(shade(roof, -0.15), [Bt, BtD, rR])
        p.poly(wall, [A, B, Bt, At])
        p.poly(rl, [At, Bt, rR, rL])
        top = rL
    else:
        rh = w * 0.5 if rh is None else rh
        ap, apD = (x, y - h - rh), (x + dx, y - h - rh + dy)
        p.poly(rl, [At, ap, apD, AtD])
        p.poly(side, [B, BD, BtD, Bt])
        p.poly(rd, [Bt, BtD, apD, ap])
        p.poly(wall, [A, B, Bt, ap, At])
        top = ap
    if door:
        dw = max(3, w * 0.2)
        p.rect(DARK, x - dw / 2, y - min(h * 0.6, 8), dw, min(h * 0.6, 8))
    for i in range(wins):
        wx = x0 + w * (i + 0.5) / wins
        if door and abs(wx - x) < w * 0.15:
            continue
        p.rect(DARK, wx - 1.5, y - h * 0.72, 3, 3)
    return top


def tower(p, x, y, r, h, wall, roof=None, cone=None, crenel=False, dome_col=None):
    dark = shade(wall, -0.3)
    p.oval(wall, x, y, r, r * 0.35)
    p.rect(wall, x - r, y - h, 2 * r, h)
    p.poly(dark, [(x + r * 0.2, y - h), (x + r, y - h), (x + r, y)] + ell(x, y, r, r * 0.35, 0, 80, 8)[::-1][:-1] +
           [(x + r * 0.2, y + r * 0.34)])
    p.oval(shade(wall, 0.12), x, y - h, r, r * 0.35)
    if crenel:
        for i in range(4):
            cx = x - r + r * 0.25 + i * r * 0.5
            p.rect(wall if i < 2 else dark, cx - r * 0.13, y - h - r * 0.45, r * 0.26, r * 0.45)
    if roof:
        cone = cone or r * 2
        p.poly(roof, [(x - r * 1.15, y - h), (x + r * 1.15, y - h), (x, y - h - cone)])
        p.poly(shade(roof, -0.3), [(x, y - h + r * 0.38), (x + r * 1.15, y - h), (x, y - h - cone)])
    if dome_col:
        dome(p, x, y - h, r * 1.05, dome_col)


def dome(p, x, y, r, col):
    p.poly(col, ell(x, y, r, r, 180, 360, 18))
    p.poly(shade(col, -0.25), ell(x, y, r, r, 270, 360, 10) + [(x, y)])
    p.oval(shade(col, -0.15), x, y, r, r * 0.25)
    p.line(shade(col, 0.4), (x - r * 0.5, y - r * 0.6), (x - r * 0.2, y - r * 0.85), 1)


def chimney(p, x, y, w=4, h=9, col=(170, 95, 70)):
    p.rect(col, x - w / 2, y - h, w, h)
    p.rect(shade(col, -0.3), x, y - h, w / 2, h)
    p.rect(shade(col, -0.45), x - w / 2 - 0.5, y - h - 1.5, w + 1, 1.8)


def smoke(p, x, y, n=4, col=(215, 215, 222), drift=1.0, s=1.0):
    for i in range(n):
        r = (3 + i * 1.6) * s
        a = max(70, 210 - i * 38)
        p.circle(col + (a,), (x + i * 3 * drift * s + (i % 2) * 2, y - i * 7 * s - r), r)
        p.circle(shade(col, 0.5) + (a,), (x + i * 3 * drift * s + (i % 2) * 2 - r * 0.3, y - i * 7 * s - r * 1.3),
                 r * 0.5)


def glow(p, x, y, r, col=(255, 150, 40)):
    for k, a in ((1.0, 50), (0.7, 90), (0.4, 160)):
        p.circle(col + (a,), (x, y), r * k)


def mound(p, x, y, w, h, col, light=None):
    pts = []
    for i in range(17):
        t = i / 16
        pts.append((x - w / 2 + w * t, y - h * (1 - (2 * t - 1) ** 2) ** 0.7))
    p.poly(col, pts)
    p.poly(shade(col, -0.25), pts[8:] + [(x, y)])
    if light:
        p.line(light, (x - w * 0.22, y - h * 0.55), (x - w * 0.08, y - h * 0.85), 1.2)


def person(p, x, y, coat=(70, 90, 150), s=1.0, hat=(80, 60, 40)):
    p.line(DARK, (x - 1.2 * s, y), (x - 1.2 * s, y - 3 * s), 1.2 * s)
    p.line(DARK, (x + 1.2 * s, y), (x + 1.2 * s, y - 3 * s), 1.2 * s)
    p.rect(coat, x - 2.5 * s, y - 8 * s, 5 * s, 5.5 * s, br=1)
    p.circle(SKIN, (x, y - 9.5 * s), 2 * s)
    p.rect(hat, x - 2.5 * s, y - 12 * s, 5 * s, 1.6 * s)


def barrel(p, x, y, s=1.0):
    p.rect((160, 105, 60), x - 3 * s, y - 7 * s, 6 * s, 7 * s, br=1)
    p.rect((120, 78, 45), x, y - 7 * s, 3 * s, 7 * s)
    p.line((80, 70, 70), (x - 3 * s, y - 2 * s), (x + 3 * s, y - 2 * s), 0.8)
    p.line((80, 70, 70), (x - 3 * s, y - 5 * s), (x + 3 * s, y - 5 * s), 0.8)


def cube(p, x, y, s, col, top=None, side=None):
    """A small block: front face s wide, top and right side faces."""
    d = s * 0.55
    p.poly(side or shade(col, -0.25), [(x + s / 2, y), (x + s / 2 + d * 0.6, y - d * 0.5),
                                        (x + s / 2 + d * 0.6, y - s - d * 0.5), (x + s / 2, y - s)])
    p.rect(col, x - s / 2, y - s, s, s)
    p.poly(top or shade(col, 0.2), [(x - s / 2, y - s), (x + s / 2, y - s), (x + s / 2 + d * 0.6, y - s - d * 0.5),
                                     (x - s / 2 + d * 0.6, y - s - d * 0.5)])


def flag(p, x, y, h, col, w=None):
    w = w or h * 0.45
    p.line(DWOOD, (x, y), (x, y - h), 1.3)
    p.poly(col, [(x, y - h), (x + w, y - h + w * 0.3), (x, y - h + w * 0.62)])
    p.poly(shade(col, -0.3), [(x, y - h + w * 0.31), (x + w, y - h + w * 0.3), (x, y - h + w * 0.62)])


def wheel(p, cx, cy, r, col=WOOD, spokes=8, paddles=True):
    p.circle(shade(col, -0.25), (cx, cy), r, 2)
    p.circle(col, (cx, cy), r - 0.5, 1.4)
    for i in range(spokes):
        a = math.radians(i * 360 / spokes + 10)
        p.line(col, (cx, cy), (cx + r * math.cos(a), cy + r * math.sin(a)), 1.1)
        if paddles:
            ox, oy = cx + r * math.cos(a), cy + r * math.sin(a)
            p.line(shade(col, -0.2), (ox, oy), (ox + 3 * math.cos(a), oy + 3 * math.sin(a)), 2.2)
    p.circle(shade(col, -0.4), (cx, cy), 2)


def pine(p, x, y, h=22, col=(40, 120, 70), snow=False, trunk=True):
    w = h * 0.42
    if trunk:
        p.rect(DWOOD, x - 1.2, y - 4, 2.4, 4)
    for k in range(3):
        by = y - 3 - k * h * 0.24
        tw = w * (1 - k * 0.22)
        th = h * 0.42
        c = col if not snow else (WHITE if k == 2 else mix(col, WHITE, 0.15))
        p.poly(c, [(x - tw, by), (x + tw, by), (x, by - th)])
        p.poly(shade(c, -0.28), [(x, by), (x + tw, by), (x, by - th)])
        if snow and k < 2:
            p.poly(WHITE, [(x - tw * 0.5, by - th * 0.5), (x + tw * 0.5, by - th * 0.5), (x, by - th)])


def round_tree(p, x, y, r=7, col=(60, 150, 70), trunk=DWOOD, th=4):
    p.rect(trunk, x - 1.2, y - th, 2.4, th)
    cy = y - th - r * 0.85
    p.circle(shade(col, -0.25), (x, cy), r)
    p.circle(col, (x - r * 0.18, cy - r * 0.12), r * 0.86)
    p.circle(shade(col, 0.22), (x - r * 0.4, cy - r * 0.35), r * 0.35)


def palm(p, x, y, h=26, lean=4, col=(60, 160, 70)):
    top = (x + lean, y - h)
    pts = [lerp((x, y), top, t / 4) for t in range(5)]
    pts = [(px + math.sin(t * 0.9) * lean * 0.25, py) for t, (px, py) in enumerate(pts)]
    for a, b in zip(pts, pts[1:]):
        p.line((150, 110, 70), a, b, 2.6)
        p.line((120, 85, 55), (a[0] - 1.5, a[1]), (a[0] + 1.5, a[1] - 1), 0.8)
    tx, ty = top
    for ang, ln in ((200, 13), (160, 12), (235, 10), (305, 10), (340, 13), (20, 12), (270, 7)):
        a = math.radians(ang)
        tip = (tx + math.cos(a) * ln, ty + math.sin(a) * ln * 0.75 + 3)
        mid = (tx + math.cos(a) * ln * 0.5, ty + math.sin(a) * ln * 0.5 - 2)
        nx, ny = -math.sin(a) * 2.2, math.cos(a) * 2.2
        c = col if 90 < ang < 270 else shade(col, -0.25)
        p.poly(c, [(tx, ty), (mid[0] + nx, mid[1] + ny), tip, (mid[0] - nx, mid[1] - ny)])
    p.circle((110, 80, 50), (tx, ty + 1), 2)


def acacia(p, x, y, s=1.0):
    p.line((110, 76, 46), (x, y), (x, y - 13 * s), 2.4)
    p.line((110, 76, 46), (x, y - 8 * s), (x + 6 * s, y - 14 * s), 1.6)
    p.line((110, 76, 46), (x, y - 9 * s), (x - 5 * s, y - 14 * s), 1.4)
    p.oval((72, 118, 52), x, y - 17 * s, 16 * s, 5 * s)
    p.oval((100, 152, 66), x - 1 * s, y - 18 * s, 14 * s, 4 * s)
    p.oval((128, 176, 82), x - 5 * s, y - 19.5 * s, 6 * s, 2 * s)


def sheep(p, x, y, s=1.0, flip=False):
    f = -1 if flip else 1
    p.line(DARK, (x - 3 * s, y - 2 * s), (x - 3 * s, y + 1 * s), 1.4)
    p.line(DARK, (x + 2.5 * s, y - 2 * s), (x + 2.5 * s, y + 1 * s), 1.4)
    p.oval(WHITE, x, y - 4.5 * s, 6.5 * s, 4.2 * s)
    p.oval((222, 224, 222), x + 1 * s, y - 3 * s, 5 * s, 2.4 * s)
    p.circle((60, 60, 66), (x + f * 6 * s, y - 5.5 * s), 2.3 * s)


def cow(p, x, y, s=1.0, flip=False, col=WHITE, spots=(40, 40, 46)):
    f = -1 if flip else 1
    for lx in (-5, -2, 3, 5.5):
        p.line(shade(col, -0.35), (x + lx * s * f, y - 3 * s), (x + lx * s * f, y + 1 * s), 1.6)
    p.rect(col, x - 7 * s, y - 9 * s, 14 * s, 7 * s, br=3)
    p.oval(spots, x - 2 * f * s, y - 6.5 * s, 2.6 * s, 2 * s)
    p.oval(spots, x + 3 * f * s, y - 7.5 * s, 2 * s, 1.5 * s)
    p.rect(shade(col, -0.15), x - 7 * s, y - 4 * s, 14 * s, 2 * s, br=1)
    hx = x + f * 8.5 * s
    p.oval(spots, hx, y - 8 * s, 3 * s, 2.6 * s)
    p.oval((235, 190, 180), hx + f * 1.2 * s, y - 6.8 * s, 1.8 * s, 1.2 * s)
    p.line(WHITE, (hx - 2 * s, y - 10.5 * s), (hx - 3 * s, y - 12 * s), 1)
    p.line(WHITE, (hx + 2 * s, y - 10.5 * s), (hx + 3 * s, y - 12 * s), 1)


def horse(p, x, y, col=(130, 82, 50), s=1.0, flip=False, gallop=True, mane=None):
    f = -1 if flip else 1
    mane = mane or shade(col, -0.45)
    dk = shade(col, -0.25)
    if gallop:
        legs = [((-5, -5), (-10, -1)), ((-3, -5), (-7, 0)), ((4, -5), (9, -2)), ((6, -5), (11, -3))]
    else:
        legs = [((-5, -5), (-5, 0)), ((-2.5, -5), (-2.5, 0)), ((4, -5), (4, 0)), ((6, -5), (6, 0))]
    for (ax, ay), (bx, by) in legs:
        p.line(dk, (x + ax * f * s, y + ay * s), (x + bx * f * s, y + by * s), 1.6)
    p.oval(col, x, y - 8 * s, 8 * s, 3.6 * s)
    p.poly(col, [(x + f * 4 * s, y - 10 * s), (x + f * 9 * s, y - 16 * s), (x + f * 12 * s, y - 15 * s),
                 (x + f * 11 * s, y - 13 * s), (x + f * 7 * s, y - 7 * s)])
    p.line(mane, (x + f * 4 * s, y - 11 * s), (x + f * 9 * s, y - 16.5 * s), 1.6)
    p.line(mane, (x - f * 7.5 * s, y - 9.5 * s), (x - f * 12 * s, y - 5 * s), 2)


def elephant(p, x, y, s=1.0, flip=False):
    f = -1 if flip else 1
    g, dk = (150, 148, 158), (115, 112, 125)
    for lx in (-8, -4, 4, 8):
        p.rect(dk if lx in (-4, 8) else g, x + lx * f * s - 2.2 * s, y - 8 * s, 4.4 * s, 8 * s)
    p.oval(g, x, y - 12 * s, 12 * s, 7.5 * s)
    p.oval(dk, x + 2 * f * s, y - 8 * s, 9 * s, 3 * s)
    hx = x + f * 11 * s
    p.circle(g, (hx, y - 14 * s), 5.5 * s)
    p.oval(dk, hx - f * 2.5 * s, y - 14 * s, 3.8 * s, 5 * s)
    p.lines(g, [(hx + f * 4 * s, y - 13 * s), (hx + f * 6 * s, y - 8 * s), (hx + f * 6.5 * s, y - 3 * s),
                (hx + f * 8 * s, y - 2 * s)], 3 * s)
    p.lines(WHITE, [(hx + f * 2.5 * s, y - 10.5 * s), (hx + f * 6 * s, y - 9 * s), (hx + f * 8 * s, y - 11 * s)],
            1.5 * s)
    p.line(dk, (x - f * 12 * s, y - 13 * s), (x - f * 14 * s, y - 7 * s), 1.2)


def boat(p, x, y, s=1.0, sail=WHITE, flip=False):
    f = -1 if flip else 1
    hull = [(x - 12 * s, y - 5 * s), (x + 12 * s, y - 5 * s), (x + 8 * s, y + 1 * s), (x - 8 * s, y + 1 * s)]
    p.poly((150, 104, 64), hull)
    p.poly((112, 74, 44), [(x - 10 * s, y - 2 * s), (x + 10 * s, y - 2 * s), (x + 8 * s, y + 1 * s),
                           (x - 8 * s, y + 1 * s)])
    if sail:
        p.line(DWOOD, (x, y - 5 * s), (x, y - 22 * s), 1.4)
        p.poly(sail, [(x + f * 1, y - 21 * s), (x + f * 10 * s, y - 7 * s), (x + f * 1, y - 7 * s)])
        p.poly(shade(sail, -0.12), [(x + f * 1, y - 13 * s), (x + f * 10 * s, y - 7 * s), (x + f * 1, y - 7 * s)])


def ripple(p, x, y, w=6, col=WATER_L):
    p.lines(col, [(x - w, y), (x - w / 2, y - 1.5), (x, y), (x + w / 2, y - 1.5), (x + w, y)], 1)


def stone_wall(p, pts, col=(170, 166, 156), w=3.2):
    p.band(shade(col, -0.35), [(x, y + 1.2) for x, y in pts], w)
    p.band(col, pts, w)
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 4))
        for i in range(n):
            q = lerp(a, b, (i + 0.5) / n)
            p.circle(shade(col, 0.3), (q[0] - 0.6, q[1] - 0.6), 0.9)


def fence(p, pts, col=WOOD, post=5):
    """Posts and two rails along a polyline (pts already ordered)."""
    for a, b in zip(pts, pts[1:]):
        p.line(shade(col, 0.15), (a[0], a[1] - post * 0.75), (b[0], b[1] - post * 0.75), 1.1)
        p.line(shade(col, 0.15), (a[0], a[1] - post * 0.35), (b[0], b[1] - post * 0.35), 1.1)
    for x, y in pts:
        p.line(shade(col, -0.2), (x, y), (x, y - post), 1.6)


def palisade(p, pts, h=10, col=(150, 100, 60)):
    out = []
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 3.2))
        out += [lerp(a, b, i / n) for i in range(n)]
    out.append(pts[-1])
    for i, (x, y) in enumerate(out):
        c = col if i % 2 == 0 else shade(col, -0.18)
        p.poly(c, [(x - 1.7, y), (x + 1.7, y), (x + 1.7, y - h), (x, y - h - 2.5), (x - 1.7, y - h)])


def shed(p, x, y, w, d, h, roof, posts=DWOOD):
    """Open-sided shed: a roof on four posts. Returns the floor rectangle area for contents."""
    dx, dy = d * 0.55, -d * 0.42
    for px, py in ((x - w / 2 + dx, y + dy), (x + w / 2 + dx, y + dy)):
        p.line(posts, (px, py), (px, py - h), 1.4)
    for px in (x - w / 2, x + w / 2):
        p.line(posts, (px, y), (px, y - h), 1.4)
    rl = [(x - w / 2 - 2, y - h), (x + w / 2 + 2, y - h), (x + w / 2 + dx + 2, y - h + dy - 3),
          (x - w / 2 + dx - 2, y - h + dy - 3)]
    p.poly(roof, rl)
    p.poly(shade(roof, -0.3), [(x - w / 2 - 2, y - h), (x + w / 2 + 2, y - h), (x + w / 2 + 2, y - h + 2),
                               (x - w / 2 - 2, y - h + 2)])


def furrows(p, quad, col, n=4, along=0):
    """Draw n lines across a quad (o, o+u, o+u+v, o+v), parallel to edge `along` (0: u, 1: v)."""
    a, b, c, d = quad
    for i in range(1, n + 1):
        t = i / (n + 1)
        if along == 0:
            p.line(col, lerp(a, d, t), lerp(b, c, t), 1)
        else:
            p.line(col, lerp(a, b, t), lerp(d, c, t), 1)


def grid_cells(t, cw, ch, ang, tag, ni=4, nj=5, off=(0, 0)):
    """A rotated grid of parallelogram cells around the centre: list of (i, j, quad, rand, rand2)."""
    a = math.radians(ang)
    ux, uy = math.cos(a) * cw, math.sin(a) * cw
    b = a + math.radians(84)
    vx, vy = math.cos(b) * ch, math.sin(b) * ch
    rng = t.r(tag)
    out = []
    for i in range(-ni, ni):
        for j in range(-nj, nj):
            ox, oy = CX + off[0] + i * ux + j * vx, CY + off[1] + i * uy + j * vy
            q = [(ox, oy), (ox + ux, oy + uy), (ox + ux + vx, oy + uy + vy), (ox + vx, oy + vy)]
            if t.flip:
                q = [(2 * CX - x, y) for x, y in q]
            out.append((i, j, q, rng.random(), rng.random()))
    return out


def centroid(q):
    return (sum(x for x, _ in q) / len(q), sum(y for _, y in q) / len(q))


def sea(t, shore_rel, far_rel, sand=(232, 214, 160)):
    """Water beyond a shoreline. shore_rel: shoreline points; far_rel: points closing the water polygon."""
    shore = t.pts(shore_rel)
    poly = shore + t.pts(far_rel)
    g = t.g
    g.band(sand, shore, 12)
    g.poly(WATER, poly)
    g.band(mix(WATER, WATER_L, 0.6), shore, 6)
    g.lines(WHITE, shore, 1.6)
    r = t.r("waves")
    for _ in range(14):
        x, y = r.uniform(5, 115), r.uniform(10, 130)
        if _in_poly((x, y), poly) and min(math.hypot(x - a, y - b) for a, b in shore) > 9:
            ripple(g, x, y, 4)
    return poly


def _in_poly(pt, poly):
    x, y = pt
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def _inside(x, y, r=R - 12):
    dx, dy = abs(x - CX), abs(y - CY)
    return dy <= r and dx <= r * math.sqrt(3) / 2 and dx * 0.5 + dy * math.sqrt(3) / 2 <= r * math.sqrt(3) / 2


def jitter_grid(t, tag, step, r=R - 6, jit=0.35):
    rng = t.r(tag)
    out = []
    y = CY - r
    row = 0
    while y < CY + r:
        x = CX - r + (step / 2 if row % 2 else 0)
        while x < CX + r:
            px, py = x + rng.uniform(-jit, jit) * step, y + rng.uniform(-jit, jit) * step
            if _inside(px, py, r):
                out.append((px, py, rng.random()))
            x += step
        y += step * 0.8
        row += 1
    return out


# ===================================================================================================
# the goods
# ===================================================================================================
def _grain(t):
    lv, g, o = t.lv, t.g, t.o
    meadow = (120, 176, 74)
    t.ground(meadow)
    cols = [(236, 196, 66), (220, 158, 52), (242, 218, 124), (164, 190, 76), (232, 182, 60)]
    for i, j, q, k, c in grid_cells(t, 30, 21, (-16, 18, -30)[t.v], "cells"):
        if k < 0.3 + 0.16 * lv:
            col = cols[int(c * len(cols))]
            g.poly(col, q)
            furrows(g, q, shade(col, -0.13), 3)
        else:
            g.poly(meadow, q)
            cx, cy = centroid(q)
            g.circle(shade(meadow, -0.12), (cx, cy), 2)
        g.poly((96, 140, 58), q, 1.2)
    track = t.pts([(-70, 6), (-30, 14), (0, 24), (30, 20), (70, 30)])
    g.band((214, 188, 130), track, 4)
    # haystacks
    hs = [(-36, 32), (-24, 38), (42, 40), (-46, 18), (48, 28), (-8, -34), (4, -40)][:[2, 4, 5, 6, 7][lv - 1]]
    for dx, dy in sorted(hs, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        mound(o, x, y, 11, 10, (236, 190, 70), (255, 236, 150))
        o.line((190, 140, 50), (x - 4, y - 3), (x + 4, y - 3), 0.8)
    t.stamp()
    if lv >= 3:                                  # grange barn
        x, y = t.at(-24, -4)
        t.shadow(x + 4, y, 36)
        building(o, x, y, 28, 13, 18, (184, 66, 50), (112, 82, 64), "side", rh=10, wins=0)
        o.rect((240, 230, 210), x - 4, y - 10, 8, 10)
        o.line((184, 66, 50), (x - 4, y - 10), (x + 4, y), 1)
        o.line((184, 66, 50), (x + 4, y - 10), (x - 4, y), 1)
        t.stamp()
    if lv >= 5:                                  # manor + walled garden
        gx, gy = t.at(-30, 44)
        garden = [(gx - 14, gy), (gx + 14, gy), (gx + 20, gy - 10), (gx - 8, gy - 10)]
        g.poly((88, 160, 80), garden)
        for i in range(3):
            g.circle((230, 120, 140) if i % 2 else (250, 220, 90), lerp(garden[0], garden[2], 0.25 + i * 0.25), 1.6)
        stone_wall(o, [garden[3], garden[2], garden[1]], (215, 205, 185), 2.4)
        for q in (lerp(garden[3], garden[2], 0.3), lerp(garden[3], garden[2], 0.75)):
            round_tree(o, q[0], q[1] + 4, 4, (70, 150, 70), th=2)
        stone_wall(o, [garden[3], garden[0], garden[1]], (215, 205, 185), 2.4)
        t.stamp()
        x, y = t.at(4, 46)
        t.shadow(x + 6, y, 36)
        top = building(o, x, y, 24, 15, 16, CREAM, ROOF_RED, "front", wins=2)
        chimney(o, top[0] + 9, top[1] + 11, 3.5, 8)
        x2, y2 = t.at(16 if not t.flip else -8, 40)
        building(o, x2 + (6 if not t.flip else -6), y2, 14, 12, 12, CREAM, ROOF_RED, "side", door=False, wins=2)
        t.stamp()
    if lv >= 4:                                  # windmill (the silhouette)
        x, y = t.at(28, 10)
        t.shadow(x + 2, y, 26)
        windmill(o, x, y, 1.0, (18, 30, 8)[t.v])
        if lv >= 5:
            flag(o, x - 1, y - 45, 8, (60, 90, 190))
        t.stamp()


def windmill(p, x, y, s=1.0, ang=20):
    h, bw, tw = 34 * s, 9 * s, 5.5 * s
    p.poly(CREAM, [(x - bw, y), (x + bw, y), (x + tw, y - h), (x - tw, y - h)])
    p.poly(shade(CREAM, -0.25), [(x + bw * 0.15, y), (x + bw, y), (x + tw, y - h), (x + tw * 0.15, y - h)])
    p.rect(DARK, x - 2.5 * s, y - 7 * s, 5 * s, 7 * s, br=2)
    p.rect(DARK, x - 1.5 * s, y - 20 * s, 3 * s, 3.5 * s)
    cap = [(x - tw - 2.5 * s, y - h + 1), (x + tw + 2.5 * s, y - h + 1), (x, y - h - 9 * s)]
    p.poly((122, 84, 56), cap)
    p.poly((92, 62, 42), [(x, y - h + 1), cap[1], cap[2]])
    hub = (x - 1 * s, y - h - 2 * s)
    L, sw = 25 * s, 6.5 * s
    for k in range(4):
        a = math.radians(ang + k * 90)
        ux, uy = math.cos(a), math.sin(a)
        nx, ny = -uy, ux
        p0 = (hub[0] + ux * L * 0.22, hub[1] + uy * L * 0.22)
        p1 = (hub[0] + ux * L, hub[1] + uy * L)
        frame = [p0, p1, (p1[0] + nx * sw, p1[1] + ny * sw), (p0[0] + nx * sw, p0[1] + ny * sw)]
        p.poly((238, 228, 206), frame)
        for i in range(1, 4):
            q0, q1 = lerp(frame[0], frame[1], i / 4), lerp(frame[3], frame[2], i / 4)
            p.line((150, 110, 70), q0, q1, 0.8)
        p.line((150, 110, 70), lerp(frame[0], frame[3], 0.5), lerp(frame[1], frame[2], 0.5), 0.8)
        p.line((112, 78, 50), hub, p1, 1.6)
    p.circle((90, 62, 42), hub, 2.4 * s)


def _wine(t):
    lv, g, o = t.lv, t.g, t.o
    scrub = (164, 158, 92)
    t.ground(scrub)
    r = t.r("scrub")
    for _ in range(26):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((128, 132, 70), (x, y), r.uniform(1.5, 3))
    sx = t.X((4, 4, -8)[t.v])
    n = 3 + lv                                   # terraces climb the hill as the level rises
    rxs = [80 - k * 9.6 for k in range(9)]
    cys = [CY + 26 - k * 7.4 for k in range(9)]
    soil_l, soil_d = (198, 146, 90), (166, 116, 74)
    hill_l, hill_d = (150, 152, 84), (126, 130, 70)
    rr = t.r("hilltop")
    for k in range(8):
        rx, cy = rxs[k], cys[k]
        ry = rx * 0.5
        terraced = k < n
        if terraced or k == n:
            g.poly(soil_l if terraced else hill_l, ell(sx, cy, rx, ry, 0, 360, 48))
            g.poly(soil_d if terraced else hill_d, ell(sx, cy, rx, ry, -75, 75, 24) + [(sx + rx * 0.25, cy)])
        if terraced:
            wall = ell(sx, cy, rx, ry, 4, 176, 34)
            g.band((112, 88, 64), [(x, y + 2.2) for x, y in wall], 2.2)
            g.band((222, 210, 182), wall, 2.4)
            for tt in (0.3, 0.72):
                vrx = rx + (rxs[k + 1] - rx) * tt
                vcy = cy + (cys[k + 1] - cy) * tt
                m = max(8, int(vrx / 2.2))
                for i in range(m):
                    ang = math.radians(i * 360 / m + k * 9)
                    if math.sin(ang) < -0.25:
                        continue
                    vx, vy = sx + vrx * math.cos(ang), vcy + vrx * 0.5 * math.sin(ang)
                    dk = math.cos(ang) > 0.25
                    g.circle((34, 96, 42) if dk else (48, 122, 50), (vx, vy - 1), 2.8)
                    g.circle((76, 150, 66) if not dk else (54, 120, 52), (vx - 0.8, vy - 2), 1.4)
                    g.circle((116, 42, 108), (vx + 1.2, vy + 0.6), 1.2)
        else:
            for _ in range(3):
                a_, d_ = rr.uniform(0.3, 2.8), rr.uniform(0.75, 0.95)
                bx, by = sx + math.cos(a_) * rx * d_, cy + math.sin(a_) * ry * d_
                g.circle((96, 118, 60), (bx, by - 1), 2.6)
                g.circle((120, 142, 70), (bx - 0.8, by - 1.8), 1.2)
    sy = cys[7]
    o_ = o
    if lv >= 3:                                  # stone press house
        x, y = t.at(-32, 40)
        t.shadow(x + 4, y, 30)
        building(o_, x, y, 20, 12, 14, STONE, ROOF_RED, "front", wins=0)
        barrel(o_, x + 15, y + 2)
        t.stamp()
    if lv >= 4:                                  # cellar arch dug into a terrace wall + barrels
        x, y = t.at(26, 34)
        o_.poly((185, 175, 150), [(x - 11, y), (x + 11, y), (x + 11, y - 11), (x - 11, y - 11)])
        o_.poly(shade((185, 175, 150), -0.25), [(x + 7, y), (x + 11, y), (x + 11, y - 11), (x + 7, y - 11)])
        o_.poly(DARK, ell(x - 1, y - 5, 6, 7, 180, 360, 12) + [(x + 5, y), (x - 7, y)])
        for i, (bx, by) in enumerate(((-15, 4), (-9, 5), (13, 5), (-12, -1))):
            barrel(o_, x + bx, y + by, 0.95)
        t.stamp()
    if lv >= 5:                                  # chateau with a round tower crowning the hill
        x, y = t.X(-2), sy + 10
        t.shadow(x + 6, y, 40)
        building(o_, x, y, 26, 15, 14, CREAM, ROOF_SLATE, "hip", rh=10, wins=3)
        tx = x + (18 if not t.flip else -18)
        tower(o_, tx - (0 if not t.flip else 0), y + 2, 6, 24, CREAM, ROOF_SLATE, 13)
        o_.rect(DARK, tx - 1.5, y - 14, 3, 4)
        flag(o_, tx, y - 34, 7, (150, 40, 90))
        t.stamp()


def _wool(t):
    lv, g, o = t.lv, t.g, t.o
    base = (156, 200, 108)
    t.ground(base)
    for dx, dy, rx, ry in ((-30, -30, 40, 22), (34, -6, 44, 24), (-20, 30, 46, 24), (30, 46, 34, 18)):
        x, y = t.at(dx, dy)
        g.oval(shade(base, -0.1), x + 4, y + 4, rx, ry)
        g.oval((176, 214, 124), x, y, rx, ry)
        g.oval((190, 224, 140), x - rx * 0.3, y - ry * 0.35, rx * 0.45, ry * 0.35)
    walls = [[(-70, -6), (-36, -10), (-6, -2), (24, -12), (70, -4)],
             [(-4, -70), (-8, -36), (-2, -2), (-12, 30), (-6, 70)],
             [(-2, -2), (22, 18), (34, 44), (40, 70)],
             [(-70, 50), (-40, 46), (-12, 30)]]
    for wpts in walls[:min(4, lv + 1)]:
        stone_wall(g, t.pts(wpts))
    r = t.r("sheep")
    spots = [(-40, -24), (-26, -34), (-46, -14), (30, -28), (42, -20), (20, -34), (-34, 20), (-24, 30),
             (-40, 34), (20, 30), (10, 44), (46, 10), (-20, 46), (52, 26)]
    r.shuffle(spots)
    n = [4, 6, 8, 10, 12][lv - 1]
    taken = []
    if lv >= 3:
        taken.append((-30, 6))
    if lv >= 4:
        taken.append((26, 30))
    if lv >= 5:
        taken.append((24, -24))
    flock = [s for s in spots if all(math.hypot(s[0] - a, s[1] - b) > 18 for a, b in taken)][:n]
    for dx, dy in sorted(flock, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        sheep(o, x, y, 1.0, flip=(dx * 7 + dy) % 2 == 0)
    t.stamp()
    if lv >= 3:                                  # shepherd hut: round stone hut with thatch
        x, y = t.at(-30, 12)
        t.shadow(x + 2, y, 22)
        tower(o, x, y, 8, 8, STONE, THATCH, 10)
        o.rect(DARK, x - 2.5, y - 6, 5, 6)
        t.stamp()
        smoke(o, x + 2, y - 20, 3)
        t.stamp(0)
    if lv >= 4:                                  # round sheepfold with sheep inside
        x, y = t.at(26, 32)
        o.oval((150, 146, 136), x, y + 1, 16, 8.5, 3.5)
        o.oval((190, 186, 176), x, y, 16, 8.5, 3)
        t.stamp(1)
        for dx, dy in ((-6, 2), (3, -1), (7, 4)):
            sheep(o, x + dx, y + dy, 0.85)
        t.stamp()
    if lv >= 5:                                  # big wool barn with fleece bales
        x, y = t.at(18, -18)
        t.shadow(x + 6, y, 44)
        building(o, x, y, 34, 14, 18, STONE, ROOF_SLATE, "side", rh=11, wins=3)
        t.stamp()
        bx, by = x + (-24 if not t.flip else 24), y + 6
        for i, (dx, dy) in enumerate(((0, 0), (7, 0), (3.5, -6), (14, 1))):
            cube(o, bx + dx, by + dy, 6, (244, 236, 210))
        t.stamp()


def _cotton(t):
    lv, g, o = t.lv, t.g, t.o
    soil = (192, 98, 66)
    t.ground(soil)
    a = math.radians((-12, 14, 4)[t.v])
    rf = 22 + 9 * lv
    fc = t.at(-4, 4)
    for row in range(-8, 9):
        oy = row * 9
        rowpts = []
        for col in range(-9, 10):
            ox = col * 8.5 + (row % 2) * 4
            x = fc[0] + ox * math.cos(a) - oy * math.sin(a)
            y = fc[1] + ox * math.sin(a) + oy * math.cos(a)
            rowpts.append((x, y))
        g.lines(shade(soil, -0.14), [(x, y + 2) for x, y in rowpts], 1.2)
        for x, y in rowpts:
            if math.hypot((x - fc[0]) * 0.9, y - fc[1]) < rf:
                g.oval((40, 110, 50), x, y, 3.6, 2.6)
    r = t.r("puffs")
    for row in range(-8, 9):
        oy = row * 9
        for col in range(-9, 10):
            ox = col * 8.5 + (row % 2) * 4
            x = fc[0] + ox * math.cos(a) - oy * math.sin(a)
            y = fc[1] + ox * math.sin(a) + oy * math.cos(a)
            if math.hypot((x - fc[0]) * 0.9, y - fc[1]) < rf:
                o.circle(WHITE, (x - 1.5, y - 2), 2.1)
                o.circle(WHITE, (x + 1.5, y - 1.5 - r.random()), 1.9)
                o.circle((226, 226, 222), (x + 0.5, y - 0.2), 1.4)
    t.stamp(1)
    if lv >= 3:                                  # open drying sheds with cotton heaps
        sheds = [(-26, -22)] + ([(6, -34)] if lv >= 4 else [])
        for dx, dy in sheds:
            x, y = t.at(dx, dy)
            t.shadow(x + 4, y, 30)
            mound(o, x + 2, y - 1, 16, 7, WHITE)
            shed(o, x, y, 18, 12, 11, (170, 120, 70))
            t.stamp()
    if lv >= 4:
        x, y = t.at(-36, 26)
        for i in range(3):
            o.oval((190, 150, 90), x + i * 6 - 3, y - 4, 2.6, 3.2)
            o.circle(WHITE, (x + i * 6 - 3, y - 7), 2.4)
        person(o, x + 14, y + 2, (240, 230, 200), 1.0, (210, 190, 130))
        t.stamp()
    if lv >= 5:                                  # gin house with banded bales
        x, y = t.at(24, -10)
        t.shadow(x + 6, y, 40)
        top = building(o, x, y, 24, 22, 16, (172, 126, 82), (120, 84, 60), "front", wins=2)
        o.rect(DARK, x - 2, top[1] + 8, 4, 4)
        o.line(DWOOD, (top[0], top[1] + 2), (top[0] + 0, top[1] - 4), 1.3)
        o.line(DWOOD, (top[0], top[1] - 4), (top[0] - 7, top[1] - 4), 1.3)
        t.stamp()
        bx = x + (-22 if not t.flip else 22)
        for dx, dy in ((0, 14), (7, 14), (3.5, 8), (14, 15), (-6, 20), (1, 20)):
            cube(o, bx + dx, y + dy, 6, (246, 244, 236), side=(210, 208, 200))
            o.line((150, 110, 70), (bx + dx - 3, y + dy - 3), (bx + dx + 3, y + dy - 3), 0.8)
        t.stamp()


def cane_block(p, x, y, w, d, h, seed=0):
    """A stand of tall sugar cane: jointed yellow-green stalks under a spiky crown of leaf blades."""
    rng = random.Random(seed)
    dx, dy = d * 0.55, -d * 0.42
    stalk_l, stalk_d, node = (214, 210, 96), (166, 172, 66), (120, 120, 56)
    p.poly((120, 140, 50), [(x + w, y), (x + w + dx, y + dy), (x + w + dx, y + dy - h), (x + w, y - h)])
    p.rect((150, 162, 60), x, y - h, w, h)
    sx, i = x + 1.2, 0
    while sx < x + w - 0.8:
        p.line(stalk_l if i % 2 == 0 else stalk_d, (sx, y), (sx, y - h), 1.5)
        for ny in range(3):
            p.line(node, (sx - 0.8, y - 3 - ny * 4.5 - (i % 3)), (sx + 0.8, y - 3 - ny * 4.5 - (i % 3)), 0.6)
        sx += 2.4
        i += 1
    for k in range(int(w / 3) + 1):
        q = (x + w * k / int(w / 3), y - h * 0.55)
        p.line((96, 160, 50), q, (q[0] + rng.uniform(-2, 2), q[1] - h * 0.3), 1)
    leaf_l, leaf_m, leaf_d = (134, 200, 66), (96, 168, 54), (66, 132, 46)
    top = [(x, y - h), (x + w, y - h), (x + w + dx, y - h + dy), (x + dx, y - h + dy)]
    p.poly(leaf_m, top)
    blades = []
    for k in range(int(w / 2.2) + 2):
        tt = k / (int(w / 2.2) + 1)
        for depth in (0.9, 0.5, 0.05):
            q = lerp(lerp(top[0], top[3], depth), lerp(top[1], top[2], depth), tt)
            blades.append((q[1], q, depth))
    for _, q, depth in sorted(blades):
        ang = math.radians(rng.uniform(-160, -20))
        ln = rng.uniform(3.5, 6.5)
        tip = (q[0] + math.cos(ang) * ln, q[1] + math.sin(ang) * ln)
        col = leaf_l if math.cos(ang) < 0 else (leaf_d if depth > 0.4 else leaf_m)
        p.poly(col, [(q[0] - 1.1, q[1] + 0.5), (q[0] + 1.1, q[1] + 0.5), tip])
    for k in range(int(w / 4) + 1):
        q = (x + 1 + k * 4, y - h)
        p.lines(leaf_m, [q, (q[0] - 1.5, q[1] + 2.5), (q[0] - 2.5, q[1] + 5)], 1.2)


def _sugar(t):
    lv, g, o = t.lv, t.g, t.o
    t.ground((196, 168, 108))
    r = t.r("dirt")
    for _ in range(20):
        g.circle((176, 148, 92), (r.uniform(5, 115), r.uniform(5, 135)), r.uniform(1.5, 3))
    blocks = [(-40, -2), (-10, -2), (20, 4), (-36, 24), (-6, 26), (24, 30), (-22, 50), (8, 52)]
    nb = [3, 5, 6, 8, 8][lv - 1]
    free = blocks[:nb]
    if lv >= 5:
        free = [b for b in free if b not in ((20, 4), (24, 30))]
    if lv >= 3:                                  # boiling house with a tall chimney
        x, y = t.at(-30, -25)
        t.shadow(x + 4, y, 30)
        top = building(o, x, y, 22, 10, 14, (176, 92, 66), (100, 74, 62), "side", rh=7, wins=2)
        chimney(o, x + 8, top[1] + 4, 5, 18, (160, 80, 60))
        t.stamp()
        smoke(o, x + 9, top[1] - 14, 4, (200, 200, 206))
        t.stamp(0)
    if lv >= 4:                                  # second boiling house + cane cart
        x, y = t.at(10, -27)
        top = building(o, x, y, 18, 10, 12, (176, 92, 66), (100, 74, 62), "side", rh=7)
        chimney(o, x + 6, top[1] + 4, 4.5, 15, (160, 80, 60))
        t.stamp()
        smoke(o, x + 7, top[1] - 11, 3, (200, 200, 206))
        t.stamp(0)
    for dx, dy in sorted(free, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        cane_block(o, x - 13, y, 24, 10, 16, int(dx * 31 + dy))
        t.stamp()
    if lv >= 5:                                  # sugar mill: aqueduct feeding a big wheel
        x, y = t.at(26, 22)
        t.shadow(x, y, 40)
        building(o, x + (4 if not t.flip else -4), y, 20, 14, 14, CREAM, ROOF_RED, "side", rh=8, wins=2)
        t.stamp()
        wx = x + (-14 if not t.flip else 14)
        wheel(o, wx, y - 12, 13, (150, 104, 64))
        t.stamp()
        sgn = 1 if not t.flip else -1
        ax0, ax1 = wx - sgn * 2, wx + sgn * 34
        o.rect((170, 160, 150), min(ax0, ax1), y - 29, abs(ax1 - ax0), 4)
        o.line(WATER, (ax0, y - 28.5), (ax1, y - 28.5), 1.4)
        for i in range(3):
            px = wx + sgn * (12 + i * 9)
            o.rect((190, 180, 168), px - 2, y - 26, 4, 26 - 6 + i * 2)
        t.stamp()


def leaf(p, base, ang, ln, wd, col):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    tip = (base[0] + ux * ln, base[1] + uy * ln)
    m1 = (base[0] + ux * ln * 0.45 + nx * wd, base[1] + uy * ln * 0.45 + ny * wd)
    m2 = (base[0] + ux * ln * 0.45 - nx * wd, base[1] + uy * ln * 0.45 - ny * wd)
    p.poly(col, [base, m1, tip, m2])
    p.line(shade(col, 0.3), base, lerp(base, tip, 0.8), 0.7)


def tobacco_plant(p, x, y, s=1.0):
    dk, md, lt = (34, 96, 46), (50, 124, 56), (80, 156, 72)
    for ang in (200, 340):
        leaf(p, (x, y - 2 * s), ang, 9 * s, 3.4 * s, dk)
    for ang in (235, 305):
        leaf(p, (x, y - 3 * s), ang, 9 * s, 3.2 * s, md)
    leaf(p, (x, y - 4 * s), 270, 8 * s, 2.6 * s, lt)
    p.circle((240, 180, 200), (x, y - 12 * s), 1.1 * s)


def tobacco_barn(p, x, y, w=16, h=26, d=12):
    wall = (126, 88, 60)
    top = building(p, x, y, w, h, d, wall, (84, 64, 52), "front", rh=8, door=False)
    for i in range(1, int(w / 3)):
        sx = x - w / 2 + i * 3
        p.line(shade(wall, -0.2), (sx, y), (sx, y - h), 0.8)
    for gy in (y - h * 0.8, y - h * 0.5):
        p.rect((60, 44, 36), x - w / 2 + 2, gy, w - 4, 3.6)
        for k in range(int((w - 4) / 2.5)):
            p.line((214, 172, 76), (x - w / 2 + 3 + k * 2.5, gy), (x - w / 2 + 3 + k * 2.5, gy + 3.4), 1.2)
    p.rect(DARK, x - 2.5, y - 7, 5, 7)
    return top


def _tobacco(t):
    lv, g, o = t.lv, t.g, t.o
    soil = (122, 84, 54)
    t.ground(soil)
    for k in range(-9, 10):
        y = CY + k * 8
        g.line(shade(soil, -0.18), (0, y + 2), (W, y + 2 - 6), 1.2)
        g.line(shade(soil, 0.12), (0, y), (W, y - 6), 1)
    rf = 26 + 8 * lv
    fc = t.at(-6, 10)
    pts = []
    for k in range(-9, 10):
        for i in range(-8, 9):
            x = CX + i * 12 + (k % 2) * 6
            y = CY + k * 10 - (x - CX) * 0.05
            if math.hypot(x - fc[0], (y - fc[1]) * 1.15) < rf and _inside(x, y, R - 8):
                pts.append((x, y))
    blocked = []
    if lv >= 3:
        blocked.append(t.at(26, -26))
    if lv >= 4:
        blocked.append(t.at(-28, -30))
    if lv >= 5:
        blocked += [t.at(2, -40), t.at(30, 30)]
    pts = [q for q in pts if all(math.hypot(q[0] - a, q[1] - b) > 18 for a, b in blocked)]
    for x, y in sorted(pts, key=lambda q: q[1]):
        tobacco_plant(o, x, y)
    t.stamp(1)
    barns = []
    if lv >= 3:
        barns.append((26, -24, 22, 34))
    if lv >= 4:
        barns.append((-28, -28, 18, 28))
    if lv >= 5:
        barns.append((2, -42, 16, 24))
    for dx, dy, w, h in sorted(barns, key=lambda b: b[1]):
        x, y = t.at(dx, dy)
        t.shadow(x + 4, y, w * 1.6)
        tobacco_barn(o, x, y, w, h)
        t.stamp()
    if lv >= 4:                                  # drying rack with hanging leaves
        x, y = t.at(-36, 12)
        o.line(DWOOD, (x - 8, y), (x - 8, y - 10), 1.4)
        o.line(DWOOD, (x + 8, y), (x + 8, y - 10), 1.4)
        o.line(DWOOD, (x - 9, y - 10), (x + 9, y - 10), 1.4)
        for k in range(6):
            o.poly((206, 160, 70) if k % 2 else (176, 130, 56), [(x - 7 + k * 2.8, y - 10), (x - 5.4 + k * 2.8, y - 10),
                                                                  (x - 6.2 + k * 2.8, y - 4)])
        t.stamp()
    if lv >= 5:                                  # warehouse + hogsheads
        x, y = t.at(30, 36)
        t.shadow(x + 6, y, 40)
        building(o, x, y, 28, 12, 14, (200, 170, 120), (130, 70, 56), "side", rh=8, wins=2)
        t.stamp()
        for dx, dy in ((-20, 6), (-14, 8), (-26, 3)):
            hx = x + (dx if not t.flip else -dx)
            barrel(o, hx, y + dy, 1.2)
        t.stamp()


def _timber(t):
    lv, g, o = t.lv, t.g, t.o
    floor = (52, 122, 66)
    t.ground(floor)
    cc = t.at(-6, 8)
    crx = 14 + 7 * lv
    cry = crx * 0.72
    clearing = ell(cc[0], cc[1], crx, cry, 0, 360, 30)
    g.poly((146, 176, 88), clearing)
    g.poly((128, 160, 78), ell(cc[0], cc[1], crx, cry, -60, 120, 16))
    r = t.r("dirt")
    for _ in range(4 + lv * 2):
        a, d = r.uniform(0, 6.28), r.uniform(0.2, 0.85)
        g.oval((178, 150, 100), cc[0] + math.cos(a) * crx * d, cc[1] + math.sin(a) * cry * d, 3, 1.6)
    # stream (always there; it widens into a log river at L5)
    srel = [(70, -40), (40, -22), (16, -4), (-6, 22), (-24, 44), (-44, 80)]
    stream = t.pts(srel)
    sw = [5, 5, 5, 7, 11][lv - 1]
    g.band((60, 110, 120), [(x + 1, y + 1.5) for x, y in stream], sw + 2)
    g.band(WATER, stream, sw)
    g.lines(WATER_L, [(x - 1, y) for x, y in stream], 1)

    def near_stream(x, y, m):
        for a, b in zip(stream, stream[1:]):
            vx, vy = b[0] - a[0], b[1] - a[1]
            tt = max(0, min(1, ((x - a[0]) * vx + (y - a[1]) * vy) / (vx * vx + vy * vy)))
            if math.hypot(x - a[0] - vx * tt, y - a[1] - vy * tt) < m:
                return True
        return False

    trees = []
    for x, y, k in jitter_grid(t, "trees", 12.5, R - 2, 0.3):
        if ((x - cc[0]) / (crx + 4)) ** 2 + ((y - cc[1]) / (cry + 4)) ** 2 < 1 or near_stream(x, y + 4, sw / 2 + 4):
            continue
        trees.append((x, y + 6, k))
    for x, y, k in sorted(trees, key=lambda q: q[1]):
        pine(o, x, y, 20 + k * 6, (36, 112, 62) if k < 0.6 else (46, 128, 70))
    t.stamp(1)
    # stumps & logs in the clearing
    rs = t.r("stumps")
    for i in range(3 + lv * 2):
        a, d = rs.uniform(0, 6.28), rs.uniform(0.25, 0.9)
        x, y = cc[0] + math.cos(a) * crx * d, cc[1] + math.sin(a) * cry * d
        if near_stream(x, y, sw / 2 + 3):
            continue
        o.rect((140, 96, 60), x - 2, y - 3, 4, 3)
        o.oval((222, 190, 130), x, y - 3, 2, 1)
    t.stamp(1)

    def logpile(x, y, n=3):
        for row in range(n):
            for k in range(n - row):
                lx = x - (n - row - 1) * 2.6 + k * 5.2
                ly = y - row * 4.4
                o.poly((150, 100, 62), [(lx - 2, ly - 4.6), (lx + 9, ly - 8), (lx + 9, ly - 3.4), (lx - 2, ly)])
                o.circle((222, 186, 128), (lx - 0.2, ly - 2.3), 2.3)
                o.circle((180, 140, 90), (lx - 0.2, ly - 2.3), 1)
    lp = [(-18, 10, 3), (6, 16, 2), (-26, -4, 2), (10, -2, 3)][:[1, 2, 2, 3, 2][lv - 1]]
    for dx, dy, n in lp:
        x, y = cc[0] + (dx if not t.flip else -dx), cc[1] + dy
        logpile(x, y, n)
    t.stamp()
    x, y = cc[0] + (8 if not t.flip else -8), cc[1] + 4
    person(o, x, y, (150, 50, 40))
    o.line(DWOOD, (x + 2, y - 7), (x + 6, y - 12), 1.2)
    o.poly((200, 205, 215), [(x + 5, y - 13), (x + 8, y - 12), (x + 6.5, y - 10)])
    t.stamp(1)
    if lv >= 3:                                  # sawpit trestle with two sawyers
        x, y = cc[0] + (-6 if not t.flip else 6), cc[1] - 6
        o.rect((80, 60, 40), x - 9, y - 1, 18, 4)
        for px in (x - 8, x + 8):
            o.line(DWOOD, (px - 2, y + 2), (px, y - 7), 1.4)
            o.line(DWOOD, (px + 2, y + 2), (px, y - 7), 1.4)
        o.poly((176, 124, 76), [(x - 12, y - 7), (x + 12, y - 7), (x + 12, y - 10), (x - 12, y - 10)])
        o.circle((222, 186, 128), (x - 12, y - 8.5), 1.8)
        o.line((200, 205, 215), (x - 2, y - 18), (x - 2, y + 3), 1)
        person(o, x - 2, y - 9, (90, 110, 160))
        t.stamp()
    if lv >= 4:                                  # water-powered sawmill on the stream
        px, py = lerp(stream[1], stream[2], 0.55)
        bx = px + (12 if not t.flip else -12)
        t.shadow(bx + 4, py + 6, 32)
        building(o, bx + (4 if not t.flip else -4), py + 6, 20, 12, 14, (170, 120, 76), (110, 80, 60), "side",
                 rh=8, wins=1)
        t.stamp()
        wheel(o, px + (2 if not t.flip else -2), py + 1, 9)
        t.stamp()
    if lv >= 5:                                  # floating logs + timber yard
        for k, tt in enumerate((0.25, 0.55, 0.85)):
            a, b = stream[3 + (k % 2)], stream[4 + (k % 2)]
            q = lerp(a, b, tt)
            o.poly((160, 112, 70), [(q[0] - 5, q[1] - 2), (q[0] + 5, q[1] - 4), (q[0] + 6, q[1] - 1),
                                    (q[0] - 4, q[1] + 1)])
            o.circle((222, 186, 128), (q[0] - 4.5, q[1] - 0.5), 1.4)
        t.stamp(1)
        yx, yy = cc[0] + (20 if not t.flip else -26), cc[1] + 22
        for dx, dy in ((0, 0), (11, 2), (5.5, -5)):
            for k in range(3):
                cube(o, yx + dx, yy + dy - k * 2.2, 9, (226, 190, 130), side=(176, 136, 88))
        t.stamp()


def _mountain(t, base, lit, dark, peaks, snow=None, base_y=14):
    """Two-tone faceted peaks (lit left face, dark right face); peaks: (dx, top dy, half width), back first."""
    g = t.g
    t.ground(base)
    for dx, py, hw in sorted(peaks, key=lambda q: q[1]):
        px = t.X(dx)
        top, foot = (px, CY + py), CY + base_y + (py + 60) * 0.12
        left, mid, right = (px - hw * 1.5, foot), (px + hw * 0.3, foot), (px + hw * 1.35, foot)
        g.poly(lit, [left, top, mid])
        g.poly(dark, [top, right, mid])
        g.lines(shade(dark, -0.25), [left, top, right], 1)
        if snow:
            k = 0.32
            a, b, c = lerp(top, left, k), lerp(top, mid, k * 1.1), lerp(top, right, k)
            g.poly(snow, [top, a, lerp(a, b, 0.4), (b[0], b[1] - 2), b])
            g.poly(mix(snow, dark, 0.35), [top, b, lerp(b, c, 0.5), c])


def adit(p, x, y, w=12, h=12):
    """Mine tunnel entrance with a timber frame."""
    p.poly(DARK, ell(x, y - h + w / 2, w / 2, w / 2, 180, 360, 10) + [(x + w / 2, y), (x - w / 2, y)])
    p.rect((130, 90, 55), x - w / 2 - 2, y - h, 3, h)
    p.rect((130, 90, 55), x + w / 2 - 1, y - h, 3, h)
    p.rect((150, 106, 64), x - w / 2 - 3.5, y - h - 2.5, w + 7, 3.5)


def rails(p, pts, col=(110, 100, 96)):
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 3.5))
        for i in range(n):
            q = lerp(a, b, i / n)
            p.line((120, 84, 50), (q[0] - 3, q[1] + 0.5), (q[0] + 3, q[1] - 0.5), 1.2)
    p.lines(col, [(x - 2, y) for x, y in pts], 0.9)
    p.lines(col, [(x + 2, y) for x, y in pts], 0.9)


def cart(p, x, y, load=(150, 70, 50), body=(110, 80, 60)):
    p.poly(body, [(x - 5, y - 7), (x + 5, y - 7), (x + 4, y - 2), (x - 4, y - 2)])
    p.poly(shade(body, -0.3), [(x + 1, y - 7), (x + 5, y - 7), (x + 4, y - 2), (x + 1, y - 2)])
    p.poly(load, [(x - 4.5, y - 7), (x - 1, y - 10), (x + 2, y - 9.5), (x + 4.5, y - 7)])
    p.circle(DARK, (x - 2.5, y - 1.5), 1.7)
    p.circle(DARK, (x + 2.5, y - 1.5), 1.7)


def _iron(t):
    lv, g, o = t.lv, t.g, t.o
    base = (118, 84, 72)
    _mountain(t, base, (116, 108, 112), (68, 62, 70), [(-40, -30, 30), (16, -44, 36), (54, -22, 22), (-10, -14, 22)],
              None, 14)
    # rust-red ore seams across the rock faces
    for seam in ([(-58, -4), (-44, -12), (-30, -10), (-18, -20)], [(0, -14), (14, -26), (30, -24), (42, -34)],
                 [(-30, 4), (-14, 0), (4, 4)], [(30, 0), (44, -8), (58, -6)]):
        pts = t.pts(seam)
        g.lines((70, 40, 34), [(x, y + 1) for x, y in pts], 2.6)
        g.lines((196, 92, 50), pts, 2)
    r = t.r("rust")
    for _ in range(22):
        x, y = r.uniform(5, 115), r.uniform(CY + 16, 135)
        g.circle((176, 86, 54) if r.random() < 0.55 else (84, 62, 58), (x, y), r.uniform(1, 2.6))
    ax, ay = t.at(-6, 16)
    # spoil heaps grow
    heaps = [(-34, 34, 14, 7), (30, 44, 18, 9), (-44, 50, 12, 6)][:max(0, lv - 1)]
    track = t.pts([(-6, 16), (-2, 34), (8, 52), (14, 80)])
    if lv >= 2:
        rails(g, track)
    for dx, dy, w, h in heaps:
        x, y = t.at(dx, dy)
        mound(o, x, y, w, h, (150, 74, 50), (200, 120, 80))
    t.stamp(1)
    adit(o, ax, ay, 13, 13)
    t.stamp()
    if lv >= 3:
        for tt in ((0.45,), (0.45, 1.3))[lv >= 4]:
            q = lerp(track[1], track[2], tt) if tt <= 1 else lerp(track[2], track[3], tt - 1)
            cart(o, q[0], q[1], (160, 76, 52))
        person(o, ax + (8 if not t.flip else -8), ay + 2, (120, 90, 60))
        t.stamp()
    if lv >= 4:                                  # bloomery furnace + charcoal stack
        x, y = t.at(30, 22)
        t.shadow(x + 3, y, 24)
        o.poly((150, 140, 128), [(x - 10, y), (x + 10, y), (x + 5, y - 16), (x - 5, y - 16)])
        o.poly((118, 108, 100), [(x + 2, y), (x + 10, y), (x + 5, y - 16), (x + 2, y - 16)])
        o.poly((255, 150, 40), ell(x - 2, y - 2, 4, 5, 180, 360, 8))
        t.stamp()
        glow(o, x - 2, y - 4, 10)
        smoke(o, x, y - 18, 3, (150, 146, 150))
        t.stamp(0)
        cx, cy = t.at(-32, 26)
        mound(o, cx, cy, 14, 8, (50, 46, 46))
        t.stamp()
    if lv >= 5:                                  # headframe wheel + blast furnace
        x, y = t.at(-30, -2)
        for sx in (-8, 8):
            o.line(DWOOD, (x + sx, y), (x, y - 30), 2)
        o.line(DWOOD, (x - 5, y - 12), (x + 5, y - 12), 1.4)
        wheel(o, x, y - 30, 8, (120, 84, 54), 6, False)
        o.line(DARK, (x + 7, y - 30), (x + 7, y - 6), 0.8)
        t.stamp()
        bx, by = t.at(26, 0)
        t.shadow(bx + 4, by, 26)
        o.poly((140, 128, 118), [(bx - 10, by), (bx + 10, by), (bx + 6, by - 34), (bx - 6, by - 34)])
        o.poly((108, 98, 92), [(bx + 2, by), (bx + 10, by), (bx + 6, by - 34), (bx + 2, by - 34)])
        o.rect((255, 160, 50), bx - 3, by - 8, 6, 6)
        o.rect((255, 210, 120), bx - 6, by - 36, 12, 3)
        t.stamp()
        glow(o, bx, by - 36, 9, (255, 130, 40))
        smoke(o, bx, by - 38, 4, (90, 86, 92))
        t.stamp(0)


def sparkle(p, x, y, r=3, col=WHITE):
    p.poly(col, [(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3), (x, y + r),
                 (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)])


def _silver(t):
    lv, g, o = t.lv, t.g, t.o
    _mountain(t, (182, 194, 208), (214, 224, 236), (150, 166, 190),
              [(-34, -40, 20), (6, -64, 24), (42, -48, 20), (-12, -20, 16), (30, -18, 14)], WHITE, 16)
    # glittering veins
    veins = [[(-46, 8), (-36, -2), (-40, -12), (-30, -22)], [(4, 10), (12, -4), (4, -16), (10, -30)],
             [(30, 10), (38, -2), (32, -14), (42, -24)]]
    for vp in veins:
        pts = t.pts(vp)
        g.lines((84, 100, 140), [(x + 0.8, y + 0.8) for x, y in pts], 3)
        g.lines((236, 244, 255), pts, 1.6)
    r = t.r("spark")
    for vp in veins:
        for q in vp[1::2]:
            x, y = t.at(*q)
            sparkle(o, x + r.uniform(-2, 2), y, 3.6 + r.random() * 1.2, (250, 252, 255))
            o.circle((170, 200, 240), (x, y), 1)
    t.stamp(1)
    ax, ay = t.at(-10, 20)
    track = t.pts([(-10, 20), (-14, 40), (-6, 60), (-10, 80)])
    if lv >= 2:
        rails(g, track, (150, 150, 160))
        for dx, dy, w in ((22, 40, 18), (-38, 44, 14))[:lv - 1]:
            x, y = t.at(dx, dy)
            mound(o, x, y, w, w * 0.5, (196, 204, 214), WHITE)
        t.stamp(1)
    adit(o, ax, ay, 12, 12)
    t.stamp()
    if lv >= 2:
        q = lerp(track[0], track[1], 0.6)
        cart(o, q[0], q[1], (226, 232, 242))
        t.stamp()
    if lv >= 3:                                  # second adit higher up with a zigzag path
        bx, by = t.at(24, -6)
        path = t.pts([(24, -6), (30, 2), (16, 8), (22, 18), (10, 24)])
        g.lines((150, 140, 130), path, 2.4)
        adit(o, bx, by, 9, 9)
        t.stamp()
    if lv >= 4:                                  # stamp mill
        x, y = t.at(34, 30)
        t.shadow(x + 4, y, 26)
        building(o, x, y, 16, 12, 12, (160, 120, 80), (110, 80, 60), "side", rh=6, door=False)
        for k in range(3):
            o.line((90, 90, 96), (x - 5 + k * 5, y - 18), (x - 5 + k * 5, y - 4), 1.4)
        o.line(DWOOD, (x - 8, y - 18), (x + 8, y - 18), 1.4)
        t.stamp()
    if lv >= 5:                                  # mint / assay house with silver bars
        x, y = t.at(10, 50)
        t.shadow(x + 6, y, 42)
        building(o, x, y, 30, 12, 12, (236, 232, 222), (190, 90, 70), "front", rh=7, door=False)
        for k in range(5):
            px = x - 12 + k * 6
            o.rect(WHITE, px - 1.2, y - 12, 2.4, 12)
            o.rect((200, 196, 186), px + 0.6, y - 12, 0.8, 12)
        o.rect(DARK, x - 2.5, y - 7, 5, 7)
        t.stamp()
        bx = x + (-24 if not t.flip else 24)
        for k, (dx, dy) in enumerate(((0, 0), (6, 0), (3, -3), (-4, 5), (2, 5))):
            o.poly((226, 232, 244), [(bx + dx - 3, y + dy), (bx + dx + 3, y + dy), (bx + dx + 2, y + dy - 3),
                                     (bx + dx - 2, y + dy - 3)])
            o.line(WHITE, (bx + dx - 2, y + dy - 2.6), (bx + dx + 1, y + dy - 2.6), 0.7)
        flag(o, x - 14, y - 26, 8, (200, 40, 50))
        t.stamp()
        sparkle(o, bx + 4, y - 6, 3)
        t.stamp(0)


def _gold(t):
    lv, g, o = t.lv, t.g, t.o
    sand = (228, 198, 118)
    t.ground(sand)
    r = t.r("pebbles")
    for _ in range(26):
        g.circle((206, 176, 100), (r.uniform(5, 115), r.uniform(5, 135)), r.uniform(1, 2.4))
    # rocky outcrop at the back
    rocks = t.pts([(-70, -30), (-50, -44), (-30, -40), (-14, -56), (6, -46), (30, -58), (50, -42), (70, -40),
                   (70, -70), (-70, -70)])
    g.poly((176, 140, 92), rocks)
    g.lines((140, 104, 70), rocks[:8], 1.4)
    stream = t.pts([(-30, -60), (-20, -36), (8, -20), (18, 2), (-4, 22), (-14, 44), (6, 64), (10, 80)])
    sm = [(x, y) for x, y in stream]
    g.band((240, 222, 160), sm, 18)
    g.band((60, 120, 160), [(x + 1, y + 1.5) for x, y in sm], 10)
    g.band(WATER, sm, 9)
    g.lines(WATER_L, [(x - 1.5, y) for x, y in sm], 1.2)
    rs = t.r("glint")
    for i in range(6 + lv * 2):
        q = lerp(sm[i % (len(sm) - 1)], sm[i % (len(sm) - 1) + 1], rs.random())
        sparkle(o, q[0] + rs.uniform(-3, 3), q[1] + rs.uniform(-2, 2), 2.2, (255, 214, 50))
    t.stamp(0)
    # tents
    tents = [(-36, 6), (40, -14), (-40, 30), (34, 30)][:[1, 2, 3, 3, 2][lv - 1]]
    for dx, dy in sorted(tents, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        o.poly((244, 236, 214), [(x - 7, y), (x + 3, y), (x - 2, y - 9)])
        o.poly((206, 196, 172), [(x + 3, y), (x + 8, y - 4), (x + 3, y - 12), (x - 2, y - 9)])
        o.poly(DARK, [(x - 3, y), (x, y), (x - 2, y - 5)])
    t.stamp()
    # panners on the banks
    pans = [(0.4, 1), (0.6, 3), (0.3, 4), (0.7, 5)][:[2, 3, 3, 4, 4][lv - 1]]
    for tt, seg in pans:
        q = lerp(sm[seg], sm[seg + 1], tt)
        x, y = q[0] + 8, q[1] + 3
        person(o, x, y, (110, 70, 140) if seg % 2 else (60, 110, 160), 1.0)
        o.oval((70, 66, 70), x - 5, y - 4, 3.6, 1.6)
        o.circle((255, 214, 50), (x - 5, y - 4.2), 0.9)
    t.stamp()
    if lv >= 2:                                  # sluice boxes on trestles
        sl = [(14, 10), (-22, 34)][:1 if lv < 3 else 2]
        for dx, dy in sl:
            x, y = t.at(dx, dy)
            sgn = 1 if not t.flip else -1
            a, b = (x - sgn * 4, y - 12), (x + sgn * 20, y - 4)
            for q in (lerp(a, b, 0.15), lerp(a, b, 0.85)):
                o.line(DWOOD, (q[0], q[1] + 2), (q[0], q[1] + 8 + (q[1] - a[1]) * -0.5 + 0), 1.4)
            o.line((150, 104, 64), a, b, 4.4)
            o.line(WATER, (a[0], a[1] - 1), (b[0], b[1] - 1), 1.6)
            t.stamp()
    if lv >= 3:
        for dx, dy, w in ((40, 26, 14), (-24, 52, 12)):
            x, y = t.at(dx, dy)
            mound(o, x, y, w, w * 0.5, (196, 160, 100))
        x, y = t.at(-34, -18)
        building(o, x, y, 14, 8, 10, (170, 124, 80), (120, 90, 64), "side", rh=5)
        t.stamp()
    if lv >= 4:                                  # mine head in the rocks
        x, y = t.at(26, -36)
        adit(o, x, y, 11, 11)
        t.stamp()
    if lv >= 5:                                  # palisade + watchtower + gold heap
        pal = t.pts([(2, -36), (38, -36), (46, -8), (38, 6)])
        palisade(o, pal, 9)
        t.stamp()
        tower(o, pal[1][0], pal[1][1] + 10, 5, 18, (160, 112, 70), (120, 84, 56), 7)
        flag(o, pal[1][0], pal[1][1] - 16, 7, (200, 40, 50))
        t.stamp()
        gx, gy = t.at(28, 44)
        mound(o, gx, gy, 14, 7, (250, 200, 50), (255, 245, 170))
        t.stamp()
        sparkle(o, gx - 2, gy - 9, 3.2, WHITE)
        sparkle(o, gx + 5, gy - 4, 2.2, WHITE)
        t.stamp(0)


def _salt(t):
    lv, g, o = t.lv, t.g, t.o
    t.ground((226, 216, 184))
    sea(t, [(-80, 44), (-40, 50), (-6, 42), (30, 52), (80, 46)], [(80, 90), (-80, 90)])
    cols = [(248, 248, 244), (192, 226, 236), (240, 206, 212), (250, 250, 248), (214, 236, 240)]
    reach = 18 + 9 * lv
    for i, j, q, k, c in grid_cells(t, 19, 13, (-6, 6, 0)[t.v], "pans", 4, 6, (0, -6)):
        cx, cy = centroid(q)
        if cy > CY + 38 or math.hypot(cx - CX, (cy - CY + 8) * 1.3) > reach:
            continue
        col = cols[int(c * len(cols))]
        g.poly((170, 136, 98), q)
        inner = [lerp(pt, (cx, cy), 0.2) for pt in q]
        g.poly(col, inner)
        g.line(shade(col, -0.1), inner[2], inner[3], 1)
        if k < 0.4:
            g.circle(WHITE, (cx - 2, cy - 1), 1.6)
    if lv >= 3:
        mounds = [(-30, -26), (-18, -32), (-40, -14), (-26, -14), (-6, -40), (-48, -2)][:[0, 0, 3, 5, 6][lv - 1]]
        for dx, dy in sorted(mounds, key=lambda q: q[1]):
            x, y = t.at(dx, dy)
            mound(o, x, y, 13, 10, WHITE, (255, 255, 255))
            o.poly((206, 222, 236), [(x, y), (x + 6.5, y), (x + 4, y - 6), (x, y - 10)])
        t.stamp()
    if lv >= 4:
        for dx, dy in ((10, 10), (-20, 20)):
            x, y = t.at(dx, dy)
            person(o, x, y, (90, 90, 150))
            o.line(DWOOD, (x + 2, y - 6), (x + 7, y), 1)
        t.stamp()
    if lv >= 5:                                  # salt house / boiling house
        x, y = t.at(24, -24)
        t.shadow(x + 6, y, 44)
        top = building(o, x, y, 30, 12, 16, (220, 200, 170), (150, 150, 160), "side", rh=9, wins=3)
        chimney(o, x + 10, top[1] + 4, 4, 10)
        t.stamp()
        smoke(o, x + 11, top[1] - 6, 3)
        t.stamp(0)
        flag(o, x - 15, y - 20, 7, (40, 90, 190))
        t.stamp()
    # a little boat in the sea at every level
    bx, by = t.at(30 if lv < 5 else -34, 62)
    boat(o, bx, by, 0.7)
    t.stamp()


def _fish(t):
    lv, g, o = t.lv, t.g, t.o
    t.ground((112, 176, 84))
    shore = [(44, -75), (30, -40), (38, -14), (22, 10), (6, 36), (-16, 80)]
    sea(t, shore, [(80, 80), (80, -80)])
    if lv >= 5:                                  # stone quay along the shore + a breakwater
        q = t.pts([(28, -48), (34, -14), (18, 10), (2, 38)])
        g.band((110, 120, 130), [(x + 2, y + 3) for x, y in q], 9)
        g.band((206, 202, 190), q, 9)
        for a, b in zip(q, q[1:]):
            for i in range(1, 5):
                m = lerp(a, b, i / 5)
                g.line((170, 166, 156), (m[0] - 2, m[1] - 3), (m[0] + 2, m[1] + 3), 0.8)
        bw = t.pts([(30, -36), (40, -38), (46, -42)])
        g.band((110, 120, 130), [(x + 2, y + 3) for x, y in bw], 7)
        g.band((196, 192, 180), bw, 7)
    r = t.r("grass")
    for _ in range(10):
        x, y = r.uniform(-60, 0), r.uniform(-60, 60)
        if _inside(t.X(x), CY + y):
            g.circle((92, 150, 70), t.at(x, y), 2.5)
    # piers: (shore dx, dy) and length grows
    piers = [((32, -18), 18), ((20, 18), 24)]
    np_ = [1, 1, 2, 2, 2][lv - 1]
    for k in range(np_):
        (dx, dy), ln = piers[k]
        ln = ln + (8 if lv >= 4 else 0)
        x, y = t.at(dx, dy)
        sgn = 1 if not t.flip else -1
        x2 = x + sgn * ln
        for px in [x + sgn * (i * 5 + 3) for i in range(int(ln / 5))]:
            o.line(DWOOD, (px, y + 1), (px, y + 5), 1.4)
        o.poly((176, 128, 78), [(x, y - 2), (x2, y - 2 - sgn * 0), (x2, y + 2), (x, y + 2)])
        o.line((130, 92, 56), (x, y + 2), (x2, y + 2), 1)
        t.stamp()
    # boats
    bpos = [(46, -2), (40, 30), (52, 14), (20, 52), (36, 48), (50, -20)]
    nb = [1, 2, 3, 4, 6][lv - 1]
    for dx, dy in sorted(bpos[:nb], key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        boat(o, x, y, 0.8 if dy % 3 else 0.9, WHITE if dx % 4 else (240, 220, 170), t.flip)
    t.stamp()

    def rack(x, y):
        o.line(DWOOD, (x - 7, y), (x - 7, y - 10), 1.3)
        o.line(DWOOD, (x + 7, y), (x + 7, y - 10), 1.3)
        o.line(DWOOD, (x - 8, y - 10), (x + 8, y - 10), 1.3)
        for k in range(5):
            fx = x - 5.5 + k * 2.75
            o.poly((176, 196, 210), [(fx - 1, y - 10), (fx + 1, y - 10), (fx + 1.2, y - 5), (fx, y - 3.5),
                                     (fx - 1.2, y - 5)])
    racks = [(-12, -14), (-24, 8), (-6, -40)][:[1, 2, 2, 3, 3][lv - 1]]
    for dx, dy in racks:
        rack(*t.at(dx, dy))
    t.stamp()
    if lv >= 3:                                  # fisher huts + nets on poles
        for dx, dy in ((-34, -20), (-40, 22))[:1 if lv < 4 else 2]:
            x, y = t.at(dx, dy)
            t.shadow(x + 4, y, 22)
            building(o, x, y, 13, 8, 10, (166, 120, 80), THATCH, "front", rh=7)
            t.stamp()
        x, y = t.at(-18, 34)
        o.line(DWOOD, (x - 6, y), (x - 6, y - 11), 1.2)
        o.line(DWOOD, (x + 6, y), (x + 6, y - 11), 1.2)
        for k in range(4):
            o.line((90, 90, 110), (x - 6, y - 10 + k * 2.5), (x + 6, y - 10 + k * 2.5), 0.6)
        for k in range(5):
            o.line((90, 90, 110), (x - 6 + k * 3, y - 10), (x - 6 + k * 3, y - 2), 0.6)
        t.stamp(1)
    if lv >= 5:                                  # stone quay, warehouse and a lighthouse
        x, y = t.at(-14, -10)
        t.shadow(x + 6, y, 34)
        building(o, x, y, 22, 12, 14, STONE, ROOF_RED, "side", rh=8, wins=2)
        t.stamp()
        lx, ly = t.at(46, -40)
        tower(o, lx, ly, 4.5, 20, WHITE, (200, 60, 50), 6)
        o.rect((255, 220, 100), lx - 2, ly - 18, 4, 3)
        t.stamp()
        flag(o, x - 10, y - 22, 7, (40, 90, 190))
        t.stamp()


def log_cabin(p, x, y, w, h, d, snow=True):
    wall = (138, 92, 58)
    top = building(p, x, y, w, h, d, wall, WHITE if snow else (110, 80, 60), "front", rh=w * 0.42, door=False)
    for k in range(1, int(h / 2.5) + 1):
        p.line(shade(wall, -0.3), (x - w / 2, y - k * 2.5), (x + w / 2, y - k * 2.5), 0.7)
    p.rect(DARK, x - 2, y - 6, 4, 6)
    return top


def pelt_frame(p, x, y, s=1.0):
    pts = [(x, y - 14 * s), (x + 6 * s, y - 7 * s), (x, y), (x - 6 * s, y - 7 * s)]
    p.poly((150, 100, 60), [(x, y - 12.5 * s), (x + 4.4 * s, y - 7 * s), (x, y - 1.5 * s), (x - 4.4 * s, y - 7 * s)])
    p.poly((120, 78, 46), [(x, y - 12.5 * s), (x + 4.4 * s, y - 7 * s), (x, y - 1.5 * s)])
    p.lines(DWOOD, pts, 1.2, True)
    p.line(DWOOD, (x, y), (x, y + 2), 1.4)


def _furs(t):
    lv, g, o = t.lv, t.g, t.o
    snow = (236, 242, 248)
    t.ground(snow)
    r = t.r("drifts")
    for _ in range(7):
        x, y = r.uniform(10, 110), r.uniform(15, 130)
        g.oval((212, 224, 238), x, y, r.uniform(8, 16), 3)
    river = t.pts([(70, 30), (40, 40), (20, 56), (10, 80)])
    g.band((176, 200, 222), river, 10)
    g.band((120, 160, 200), river, 6)
    clear = (16 + 4 * lv)
    trees = []
    for x, y, k in jitter_grid(t, "pines", 13, R - 2, 0.32):
        if math.hypot(x - t.X(-6), (y - CY) * 1.2) < clear + 10:
            continue
        if min(math.hypot(x - a, y - b) for a, b in river) < 10:
            continue
        trees.append((x, y + 6, k))
    for x, y, k in sorted(trees, key=lambda q: q[1]):
        pine(o, x, y, 18 + k * 7, (40, 96, 74), snow=True)
    t.stamp(1)
    frames = [(-14, 14), (6, 18), (-22, -4), (12, -10), (0, 26), (-28, 22)][:[1, 2, 4, 5, 6][lv - 1]]
    fc = t.at(-4, 2)
    if lv >= 5:
        palisade(o, ell(fc[0], fc[1], 40, 25, 180, 360, 14), 10)
        t.stamp()
    items = []
    if lv == 1:
        items.append(("tent", -8, 0))
    if lv >= 2:
        items.append(("cabin", -10 if lv < 5 else -14, -2))
    if lv >= 3:
        items.append(("cabin2", 14, -14))
        items.append(("canoe", 22, 34))
    if lv >= 4:
        items.append(("store", -26, 4))
    if lv >= 5:
        items.append(("block", 22, -22))
    for dx, dy in frames:
        items.append(("frame", dx, dy))
    items.append(("fire", 6, 6))
    for kind, dx, dy in sorted(items, key=lambda q: q[2]):
        x, y = t.at(dx, dy)
        if kind == "tent":
            o.poly((196, 160, 116), [(x - 9, y), (x + 9, y), (x, y - 18)])
            o.poly((160, 124, 86), [(x, y), (x + 9, y), (x, y - 18)])
            o.poly(DARK, [(x - 3, y), (x + 1, y), (x - 1, y - 7)])
            o.line(DWOOD, (x - 2, y - 17), (x - 4, y - 21), 1)
            o.line(DWOOD, (x + 2, y - 17), (x + 4, y - 21), 1)
        elif kind == "cabin":
            t.shadow(x + 4, y, 26)
            top = log_cabin(o, x, y, 18, 10, 14)
            chimney(o, top[0] + 6, top[1] + 9, 3.5, 7, (150, 140, 130))
        elif kind == "cabin2":
            t.shadow(x + 4, y, 22)
            log_cabin(o, x, y, 14, 9, 12)
        elif kind == "store":
            for px in (x - 5, x + 5):
                o.line(DWOOD, (px, y), (px, y - 6), 1.6)
            log_cabin(o, x, y - 6, 12, 7, 9)
        elif kind == "block":
            o.rect((138, 92, 58), x - 6, y - 12, 12, 12)
            o.rect((110, 72, 46), x - 1, y - 12, 7, 12)
            o.rect((150, 100, 62), x - 8, y - 20, 16, 8)
            o.rect((118, 78, 50), x, y - 20, 8, 8)
            o.poly(WHITE, [(x - 9, y - 20), (x + 9, y - 20), (x, y - 26)])
            flag(o, x, y - 25, 8, (200, 40, 50))
        elif kind == "canoe":
            o.poly((176, 120, 70), [(x - 10, y - 3), (x + 10, y - 3), (x + 7, y), (x - 7, y)])
            o.line((120, 80, 46), (x - 8, y - 1.5), (x + 8, y - 1.5), 1)
        elif kind == "frame":
            pelt_frame(o, x, y)
        elif kind == "fire":
            o.line(DWOOD, (x - 3, y), (x + 3, y - 2), 1.4)
            o.line(DWOOD, (x + 3, y), (x - 3, y - 2), 1.4)
            o.poly((255, 160, 40), [(x - 2, y - 1.5), (x + 2, y - 1.5), (x, y - 6)])
        t.stamp()
    if lv >= 5:
        palisade(o, ell(fc[0], fc[1], 40, 25, 0, 78, 6), 9)
        palisade(o, ell(fc[0], fc[1], 40, 25, 102, 180, 6), 9)
        t.stamp()
    smoke(o, t.X(6), CY - 2, 3)
    t.stamp(0)


def round_hut(p, x, y, r=7, wall=(196, 150, 100)):
    p.oval(wall, x, y - 1, r, r * 0.35)
    p.rect(wall, x - r, y - r * 0.9 - 1, 2 * r, r * 0.9)
    p.rect(shade(wall, -0.25), x + r * 0.2, y - r * 0.9 - 1, r * 0.8, r * 0.9)
    p.rect(DARK, x - 1.8, y - 5, 3.6, 4.5)
    roof = [(x - r * 1.3, y - r * 0.9), (x + r * 1.3, y - r * 0.9), (x, y - r * 2.6)]
    p.poly(THATCH, roof)
    p.poly(shade(THATCH, -0.25), [(x, y - r * 0.9), roof[1], roof[2]])


def tusk(p, x, y, s=1.0, flip=False):
    f = -1 if flip else 1
    pts = [(x, y), (x + f * 4 * s, y - 2 * s), (x + f * 8 * s, y - 7 * s), (x + f * 9 * s, y - 12 * s)]
    p.lines((250, 244, 220), pts, 2.4 * s)
    p.lines((214, 200, 170), [(px + 0.6, py + 0.6) for px, py in pts[:3]], 0.8)


def _ivory(t):
    lv, g, o = t.lv, t.g, t.o
    base = (214, 188, 108)
    t.ground(base)
    r = t.r("grass")
    for _ in range(34):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.lines((178, 156, 76), [(x - 2, y), (x, y - 4), (x + 2, y)], 1)
    for _ in range(5):
        g.oval((200, 172, 96), r.uniform(10, 110), r.uniform(15, 125), r.uniform(10, 18), 4)
    if lv >= 2:
        wx, wy = t.at(26, 34)
        g.oval((170, 150, 100), wx, wy + 1, 18, 7)
        g.oval(WATER, wx, wy, 16, 6)
        g.oval(WATER_L, wx - 4, wy - 1.5, 6, 1.5)
    trees = [(-36, -34), (34, -38), (44, 4)]
    for dx, dy in trees:
        acacia(o, *t.at(dx, dy), 1.15)
    t.stamp()
    els = [(-12, -14, 1.0, False), (14, 18, 0.9, True), (-34, 16, 0.75, False)]
    if lv >= 3:
        els = [(-30, -14, 0.9, False), (20, 46, 0.8, True), (-34, 16, 0.7, False)]
    if lv >= 5:
        els = [(-36, -18, 0.85, False), (-6, 54, 0.75, True)]
    n = [2, 3, 3, 3, 2][lv - 1]
    for dx, dy, s, fl in sorted(els[:n], key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        t.shadow(x, y, 26 * s)
        elephant(o, x, y, s, fl != t.flip)
        t.stamp()
    if lv >= 3:
        huts = [(6, -18)] + ([(-14, 30)] if lv >= 4 else [])
        if lv >= 5:
            huts = [(4, -14), (22, 4)]
        for dx, dy in huts:
            x, y = t.at(dx, dy)
            t.shadow(x + 2, y, 20)
            round_hut(o, x, y)
            t.stamp()
        x, y = t.at(18 if lv < 5 else -8, -4 if lv < 5 else 16)
        for k in range(2 + (lv - 3) * 2):
            tusk(o, x - 6 + k * 3, y + (k % 2), 1.0, k % 2 == 1)
        t.stamp()
    if lv >= 5:                                  # stockade fort
        pal = t.pts([(-24, -24), (30, -24), (40, 18)])
        palisade(o, pal, 10, (168, 116, 66))
        t.stamp()
        x, y = t.at(-24, -26)
        tower(o, x, y + 4, 5, 18, (168, 116, 66), THATCH, 8)
        flag(o, x, y - 22, 8, (200, 40, 50))
        t.stamp()
        pal2 = t.pts([(-24, -24), (-30, 20), (40, 18)])
        palisade(o, pal2, 10, (168, 116, 66))
        t.stamp()


SPICE_COLS = [(232, 120, 40), (196, 52, 40), (240, 200, 50), (130, 78, 44), (220, 90, 60)]


def spice_mat(p, x, y, cols, w=25):
    d = w * 0.6
    mat = [(x - w / 2, y), (x + w / 2, y), (x + w / 2 + d * 0.55, y - d * 0.42), (x - w / 2 + d * 0.55, y - d * 0.42)]
    p.poly((226, 196, 132), mat)
    for k in range(1, 4):
        p.line((196, 160, 100), lerp(mat[0], mat[1], k / 4), lerp(mat[3], mat[2], k / 4), 0.7)
    for k, c in enumerate(cols):
        q = lerp(lerp(mat[0], mat[3], 0.5), lerp(mat[1], mat[2], 0.5), (k + 0.5) / len(cols))
        mound(p, q[0], q[1] + 2.5, w / len(cols) * 1.15 + 1, 9, c, shade(c, 0.4))


def _spices(t):
    lv, g, o = t.lv, t.g, t.o
    base = (204, 136, 84)
    t.ground(base)
    r = t.r("under")
    for _ in range(12):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((96, 150, 64), (x, y), r.uniform(3, 6))
        g.circle((120, 172, 78), (x - 1, y - 1), r.uniform(1.5, 3))
    path = t.pts([(-70, 20), (-20, 22), (10, 10), (70, 0)])
    g.band((226, 180, 120), path, 6)
    bushes = []
    for x, y, k in jitter_grid(t, "bush", 15, R - 4, 0.3):
        if k < 0.25 + lv * 0.08:
            bushes.append((x, y))
    palms = [(-38, -10, 30, 5), (40, -30, 28, -4), (-14, -42, 26, 3), (44, 34, 24, -4), (-40, 40, 24, 4)]
    np_ = [2, 3, 4, 4, 5][lv - 1]
    for dx, dy, h, lean in sorted(palms[:np_], key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        palm(o, x, y, h, lean if not t.flip else -lean)
        t.stamp()
    mats = [(-10, 0, [0, 1, 2]), (16, 26, [2, 3, 0]), (-26, 30, [1, 4]), (20, -6, [3, 0, 1])]
    nm = [1, 2, 3, 3, 3][lv - 1]
    for dx, dy, ci in sorted(mats[:nm], key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        spice_mat(o, x, y, [SPICE_COLS[c] for c in ci])
        t.stamp()
    if lv >= 3:                                  # drying rack + baskets
        x, y = t.at(-4, 46)
        for k, c in enumerate((SPICE_COLS[0], SPICE_COLS[2], SPICE_COLS[3])):
            o.rect((170, 120, 70), x - 9 + k * 7, y - 5, 6, 5, br=1)
            o.oval(c, x - 6 + k * 7, y - 5, 3, 1.4)
        t.stamp()
    if lv >= 4:                                  # shed with striped awning
        x, y = t.at(26, -22)
        t.shadow(x + 4, y, 26)
        building(o, x, y, 16, 10, 12, (236, 222, 190), (200, 90, 60), "side", rh=7)
        for k in range(4):
            c = (230, 60, 50) if k % 2 == 0 else WHITE
            o.poly(c, [(x - 8 + k * 4, y - 10), (x - 4 + k * 4, y - 10), (x - 4 + k * 4 - 1, y - 5),
                       (x - 8 + k * 4 - 1, y - 5)])
        t.stamp()
    if lv >= 5:                                  # spice warehouse with coloured awnings and flags
        x, y = t.at(-14, -18)
        t.shadow(x + 6, y, 44)
        building(o, x, y, 32, 14, 16, (240, 226, 196), (196, 84, 56), "side", rh=10, wins=4, door=False)
        for k in range(8):
            c = [SPICE_COLS[0], SPICE_COLS[2], SPICE_COLS[1], WHITE][k % 4]
            o.poly(c, [(x - 16 + k * 4, y - 8), (x - 12 + k * 4, y - 8), (x - 12 + k * 4 - 1.5, y - 3),
                       (x - 16 + k * 4 - 1.5, y - 3)])
        flag(o, x - 14, y - 26, 8, SPICE_COLS[0])
        flag(o, x + 4, y - 30, 8, SPICE_COLS[1])
        t.stamp()


def _horses(t):
    lv, g, o = t.lv, t.g, t.o
    base = (150, 196, 88)
    t.ground(base)
    r = t.r("tufts")
    for _ in range(30):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.lines((120, 170, 70), [(x - 2, y), (x, y - 3), (x + 2, y)], 1)
    cx, cy = t.at(-2, 14)
    if lv == 1:
        rx, ry = 22, 14
    elif lv < 5:
        rx, ry = 38, 22
    else:
        rx, ry = 44, 24
    sandc = (222, 200, 140)
    if lv >= 5:
        g.oval(sandc, cx, cy, rx, ry)
        g.oval(shade(sandc, -0.08), cx, cy + 2, rx - 6, ry - 5, 1)
    else:
        g.oval(sandc, cx, cy, rx - 2, ry - 2)
        g.oval(base if lv > 1 else (166, 206, 100), cx, cy, rx - 9, ry - 7)
    posts = ell(cx, cy, rx, ry, 0, 360, 20 if lv > 1 else 12)[:-1]
    if lv == 1:
        for x, y in posts:
            g.line(DWOOD, (x, y), (x, y - 5), 1.6)
        g.lines((200, 180, 130), [(x, y - 4) for x, y in posts], 0.7, True)
    else:
        ring = [(x, y) for x, y in ell(cx, cy, rx, ry, 180, 360, 12)]
        fence(o, ring, (176, 130, 80))
        t.stamp(1)
    if lv >= 5:                                  # tilt barrier through the lists
        o.line((240, 230, 210), (cx - rx * 0.6, cy), (cx + rx * 0.6, cy), 2.4)
        o.line((200, 50, 50), (cx - rx * 0.6, cy - 1), (cx + rx * 0.6, cy - 1), 0.8)
        t.stamp(1)
    hs = [(-14, -8, (130, 82, 50)), (14, 6, (60, 48, 44)), (-20, 10, (232, 226, 214)), (20, -10, (170, 110, 60)),
          (0, 14, (100, 66, 44))]
    nh = [2, 3, 4, 5, 5][lv - 1]
    sc = 0.75 if lv == 1 else 1.0
    for dx, dy, col in sorted(hs[:nh], key=lambda q: q[1]):
        if lv == 1:
            dx, dy = dx * 0.55, dy * 0.6
        x, y = cx + (dx if not t.flip else -dx), cy + dy
        horse(o, x, y, col, sc, (dx < 0) != t.flip, True, (240, 230, 210) if col[0] < 80 else None)
    t.stamp()
    if lv >= 2:
        ring = ell(cx, cy, rx, ry, 0, 180, 12)
        fence(o, ring, (176, 130, 80))
        t.stamp(1)
    if lv >= 3:                                  # stables
        x, y = t.at(-14, -36)
        t.shadow(x + 6, y, 44)
        building(o, x, y, 34, 10, 14, (186, 132, 84), (150, 70, 52), "side", rh=8, door=False)
        for k in range(4):
            sx = x - 13 + k * 8.5
            o.rect(DARK, sx - 2, y - 7, 4, 7)
            o.rect((120, 84, 54), sx - 2, y - 3.5, 4, 3.5)
        t.stamp()
    if lv >= 4:                                  # trough + small paddock
        pen = t.pts([(24, -34), (48, -34), (52, -16), (28, -16)])
        fence(o, [pen[0], pen[1], pen[2]], (176, 130, 80), 4)
        t.stamp(1)
        x, y = t.at(38, -22)
        horse(o, x - 4, y + 2, (190, 140, 90), 0.7, t.flip, False)
        o.rect((150, 104, 64), x + 2, y - 3, 10, 3)
        o.rect(WATER, x + 3, y - 3, 8, 1.2)
        t.stamp()
        fence(o, [pen[2], pen[3], pen[0]], (176, 130, 80), 4)
        t.stamp(1)
    if lv >= 5:                                  # pavilions and banners
        for k, (dx, dy, c) in enumerate(((-44, -16, (200, 40, 50)), (34, 48, (40, 80, 190)))):
            x, y = t.at(dx, dy)
            o.poly(WHITE, [(x - 7, y), (x + 7, y), (x + 5, y - 9), (x - 5, y - 9)])
            for s in range(3):
                o.poly(c, [(x - 6 + s * 5, y), (x - 4 + s * 5, y), (x - 3.5 + s * 4, y - 9), (x - 5 + s * 4, y - 9)])
            o.poly(c, [(x - 6, y - 9), (x + 6, y - 9), (x, y - 16)])
            o.poly(shade(c, -0.3), [(x, y - 9), (x + 6, y - 9), (x, y - 16)])
            o.line(DWOOD, (x, y - 16), (x, y - 20), 1)
        for q in (ell(cx, cy, rx, ry, 0, 180, 4)[1:4]):
            flag(o, q[0], q[1], 14, (200, 40, 50) if q[0] < cx else (40, 80, 190))
        t.stamp()


def _cattle(t):
    lv, g, o = t.lv, t.g, t.o
    base = (78, 166, 82)
    t.ground(base)
    r = t.r("lush")
    for _ in range(22):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((96, 186, 96), (x, y), r.uniform(2, 4))
    for _ in range(10):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((240, 240, 200) if r.random() < 0.5 else (250, 220, 80), (x, y), 0.9)
    px, py = t.at(-24, -16)
    g.oval((60, 130, 70), px + 1, py + 2, 22, 11)
    g.oval(WATER, px, py, 20, 9)
    g.oval(WATER_L, px - 6, py - 3, 8, 2)
    for k in range(5):
        a = math.radians(200 + k * 30)
        rx_, ry_ = px + math.cos(a) * 20, py + math.sin(a) * 9
        o.line((60, 105, 55), (rx_, ry_), (rx_ - 1, ry_ - 7), 1.2)
        o.line((120, 80, 50), (rx_ - 1, ry_ - 7), (rx_ - 1, ry_ - 9), 1.8)
    t.stamp(1)
    if lv >= 2:
        fence(o, t.pts([(-60, 40), (-40, 36), (-20, 40), (0, 44), (20, 46)]), (176, 130, 80))
        t.stamp(1)
    if lv >= 4:                                  # pens
        for k in range(2):
            a = t.at(4 + k * 24, 26)
            b = t.at(26 + k * 24, 26)
            fence(o, [a, b], (176, 130, 80), 4)
        t.stamp(1)
    cows = [(-6, 4), (14, -6), (-36, 14), (20, 14), (-18, 24), (36, 4), (6, 34), (34, 40), (14, 44)]
    nc = [3, 5, 6, 7, 8][lv - 1]
    taken = [(20, -30)] if lv >= 3 else []
    if lv >= 5:
        taken += [(-20, 48), (38, -20)]
    cs = [c for c in cows if all(math.hypot(c[0] - a, c[1] - b) > 14 for a, b in taken)][:nc]
    for dx, dy in sorted(cs, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        cow(o, x, y, 0.9, ((dx + dy) % 3 == 0) != t.flip, WHITE if dx % 2 == 0 else (150, 96, 60),
            (40, 40, 46) if dx % 2 == 0 else (240, 236, 226))
    t.stamp()
    if lv >= 4:
        for k in range(2):
            a = t.at(4 + k * 24, 34)
            b = t.at(26 + k * 24, 34)
            fence(o, [a, b], (176, 130, 80), 4)
        t.stamp(1)
    if lv >= 3:                                  # red barn
        x, y = t.at(18, -26)
        t.shadow(x + 6, y, 40)
        building(o, x, y, 28, 14, 18, (196, 56, 46), (90, 86, 92), "side", rh=11, door=False)
        o.rect(WHITE, x - 5, y - 11, 10, 11)
        o.rect((196, 56, 46), x - 4, y - 10, 8, 10)
        o.line(WHITE, (x - 4, y - 10), (x + 4, y), 1)
        o.line(WHITE, (x + 4, y - 10), (x - 4, y), 1)
        t.stamp()
    if lv >= 5:                                  # silo + farmhouse
        x, y = t.at(40, -18)
        tower(o, x, y, 6, 26, (220, 214, 200), None, None, False, (150, 60, 50))
        t.stamp()
        x, y = t.at(-22, 50)
        t.shadow(x + 6, y, 34)
        top = building(o, x, y, 22, 13, 14, CREAM, ROOF_RED, "front", wins=2)
        chimney(o, top[0] + 7, top[1] + 9, 3.5, 7)
        t.stamp()


def _stone(t):
    lv, g, o = t.lv, t.g, t.o
    base = (178, 178, 172)
    t.ground(base)
    r = t.r("rubble")
    for _ in range(10):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((130, 176, 90), (x, y), r.uniform(3, 6))
    for _ in range(26):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((150, 150, 146), (x, y), r.uniform(0.8, 2))
    steps = [1, 2, 3, 4, 4][lv - 1]
    px, py = t.at(-2, 2)
    x0, y0, x1, y1 = px - 42, py - 30, px + 42, py + 34
    g.poly((150, 148, 140), [(x0 - 3, y0 - 2), (x1 + 3, y0 - 2), (x1 + 4, y1 + 4), (x0 - 2, y1 + 4)])
    g.poly((214, 212, 204), [(x0 - 3, y0 - 3), (x1 + 3, y0 - 3), (x1 + 3, y1 + 2), (x0 - 3, y1 + 2)])
    back, right, left = (234, 224, 200), (212, 202, 180), (150, 144, 132)
    for k in range(steps):
        rise = 8
        g.poly(left, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
        g.poly(right, [(x1, y0), (x1, y1), (x1 - 3, y1), (x1 - 3, y0 + rise)])
        g.poly(back, [(x0, y0), (x1, y0), (x1 - 3, y0 + rise), (x0 + 3, y0 + rise)])
        for c in range(1, 9):
            lx = x0 + (x1 - x0) * c / 9
            g.line(shade(back, -0.14), (lx + (c % 2) * 2.5, y0 + 1), (lx + (c % 2) * 2.5, y0 + rise / 2), 0.8)
            g.line(shade(back, -0.14), (lx + 1.2, y0 + rise / 2), (lx + 1.2, y0 + rise - 1), 0.8)
        g.line(shade(back, -0.14), (x0 + 2, y0 + rise / 2), (x1 - 2, y0 + rise / 2), 0.7)
        g.line(shade(back, 0.4), (x0 + 1, y0 + 0.5), (x1 - 1, y0 + 0.5), 0.8)
        floor = tuple(max(0, c - 22 * (k + 1)) for c in (196, 190, 176))
        fl = [(x0 + 3, y0 + rise), (x1 - 3, y0 + rise), (x1 - 3, y1), (x0 + 3, y1)]
        g.poly(floor, fl)
        g.line(shade(floor, -0.25), fl[0], fl[1], 1)
        x0, y0, x1, y1 = x0 + 8, y0 + rise + 2, x1 - 8, y1 - 2.5
    cur = [(x0 - 5, y0 - 2), (x1 + 5, y0 - 2), (x1 + 5, y1 + 2.5), (x0 - 5, y1 + 2.5)]
    # cut blocks at the bottom of the pit and on the rim
    bot = centroid(cur)
    blocks = [(bot[0] - 6, bot[1] + 3), (bot[0] + 4, bot[1] + 4)]
    rim = [(-46, 40), (-36, 42), (-41, 36), (-50, 30), (40, 40), (50, 36), (45, 30), (30, 44)]
    nb = [2, 3, 4, 6, 8][lv - 1]
    for x, y in blocks:
        cube(o, x, y, 5.5, (244, 242, 236), side=(200, 198, 192))
    t.stamp()
    for dx, dy in sorted(rim[:nb], key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        cube(o, x, y, 7, (244, 242, 236), side=(200, 198, 192))
    t.stamp()
    person(o, bot[0] + 10, bot[1] + 3, (150, 60, 50))
    t.stamp(1)
    if lv >= 2:                                  # sledge with a block
        x, y = t.at(18, -36)
        o.rect(DWOOD, x - 7, y - 2, 14, 2)
        cube(o, x - 1, y - 2, 7, (244, 242, 236), side=(200, 198, 192))
        t.stamp()

    def crane(x, y, s=1.0, fl=False):
        f = -1 if fl else 1
        wheel(o, x, y - 9 * s, 8 * s, (150, 104, 64), 8, False)
        o.line(DWOOD, (x - 6 * s, y), (x, y - 9 * s), 1.4)
        o.line(DWOOD, (x + 6 * s, y), (x, y - 9 * s), 1.4)
        o.line(DWOOD, (x + f * 3 * s, y - 2 * s), (x + f * 16 * s, y - 26 * s), 2)
        o.line(DARK, (x + f * 16 * s, y - 26 * s), (x + f * 16 * s, y - 10 * s), 0.8)
        cube(o, x + f * 16 * s, y - 4 * s, 5 * s, (244, 242, 236), side=(200, 198, 192))
    if lv >= 3:
        x, y = t.at(-30, -33)
        crane(x, y, 1.0, t.flip)
        t.stamp()
    if lv >= 4:
        x, y = t.at(46, -8)
        crane(x, y, 0.9, not t.flip)
        t.stamp()
    if lv >= 5:                                  # marble works: columns + statue
        x, y = t.at(-30, 48)
        for k in range(3):
            cx = x + k * 8
            o.rect(WHITE, cx - 2, y - 16 + k * 0, 4, 16)
            o.rect((214, 212, 206), cx + 0.5, y - 16, 1.5, 16)
            o.rect(WHITE, cx - 3, y - 18, 6, 2.2)
        o.rect(WHITE, x - 4, y - 20, 22, 2.5)
        t.stamp()
        sx, sy = t.at(34, 50)
        cube(o, sx, sy, 8, (230, 228, 220), side=(196, 194, 188))
        o.rect(WHITE, sx - 2, sy - 18, 4, 9)
        o.circle(WHITE, (sx, sy - 20), 2.2)
        o.line(WHITE, (sx + 2, sy - 16), (sx + 5, sy - 21), 1.4)
        t.stamp()


def teal_rock(p, x, y, w, h, seed=0):
    """A crag of verdigris-green rock with a lit left face, a dark right face and a coppery streak."""
    rng = random.Random(seed)
    lit, dk, hi = (66, 170, 150), (34, 116, 112), (132, 214, 190)
    pk = (x + rng.uniform(-0.18, 0.08) * w, y - h)
    ls = (x - w * 0.44, y - h * rng.uniform(0.4, 0.62))
    rs = (x + w * 0.46, y - h * rng.uniform(0.3, 0.5))
    bl, br, mid = (x - w / 2, y), (x + w / 2, y), (x + w * 0.1, y)
    ridge = (pk[0] + w * 0.06, y - h * 0.42)
    p.poly(lit, [bl, ls, pk, ridge, mid])
    p.poly(dk, [pk, rs, br, mid, ridge])
    p.poly(hi, [ls, pk, ridge, lerp(ls, ridge, 0.5)])
    p.lines((214, 120, 60), [lerp(bl, ridge, 0.35), lerp(ls, ridge, 0.6), lerp(pk, ridge, 0.7)], 1.2)
    p.circle((236, 150, 80), lerp(rs, mid, 0.5), 1)


def _copper(t):
    lv, g, o = t.lv, t.g, t.o
    base = (158, 112, 80)
    t.ground(base)
    r = t.r("grit")
    for _ in range(26):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((90, 160, 140) if r.random() < 0.3 else (138, 96, 68), (x, y), r.uniform(1, 2.5))
    g.poly((118, 146, 120), t.pts([(-80, -10), (-44, -24), (-10, -18), (20, -30), (80, -18), (80, -80), (-80, -80)]))
    rocks = [(24, -22, 42, 40), (-30, -22, 30, 26), (-50, -2, 16, 12), (50, 2, 14, 10), (2, -44, 20, 16),
             (-14, -36, 14, 10)]
    for dx, dy, w, h in sorted(rocks, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        teal_rock(o, x, y, w, h, dx * 7 + dy)
    t.stamp()
    ax, ay = t.at(-4, -4)
    adit(o, ax, ay, 11, 11)
    t.stamp()
    heaps = [(-30, 26, 18), (24, 22, 22), (-12, 44, 16), (40, 44, 18)][:[1, 2, 3, 4, 4][lv - 1]]
    track = t.pts([(-4, -4), (2, 14), (12, 34), (10, 60)])
    if lv >= 3:
        rails(g, track)
    for dx, dy, w in sorted(heaps, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        mound(o, x, y, w, w * 0.5, (214, 116, 54), (246, 170, 100))
    t.stamp()
    if lv >= 3:
        for tt in (0.4, 0.9)[:1 if lv < 4 else 2]:
            q = lerp(track[1], track[2], tt)
            cart(o, q[0], q[1], (226, 128, 60))
        t.stamp()
    if lv >= 4:                                  # roasting heap with greenish smoke
        x, y = t.at(-38, 46)
        mound(o, x, y, 14, 6, (90, 70, 60))
        t.stamp()
        glow(o, x, y - 3, 6, (255, 140, 40))
        smoke(o, x, y - 6, 3, (170, 200, 150))
        t.stamp(0)
    if lv >= 5:                                  # smelter with a tall chimney
        x, y = t.at(28, 54)
        t.shadow(x + 4, y, 34)
        building(o, x, y, 22, 10, 12, (176, 110, 80), (90, 84, 90), "side", rh=6, wins=2)
        cx = x + (12 if not t.flip else -12)
        chimney(o, cx, y - 6, 6, 34, (170, 90, 64))
        o.rect((255, 160, 60), x - 9, y - 5, 4, 3)
        t.stamp()
        smoke(o, cx + 1, y - 42, 4, (160, 206, 160))
        t.stamp(0)


def _hemp(t):
    lv, g, o = t.lv, t.g, t.o
    base = (128, 160, 80)
    t.ground(base)
    # beds: alternating hemp (tall dark) and flax (blue) strips
    beds = []
    for i, j, q, k, c in grid_cells(t, 24, 18, (-8, 10, 2)[t.v], "beds", 4, 5, (0, 4)):
        cx, cy = centroid(q)
        if math.hypot(cx - CX, (cy - CY) * 1.2) > 18 + lv * 10:
            continue
        beds.append((q, (i + j) % 2 == 0, (cx, cy)))
    for q, hemp, _ in beds:
        if not hemp:
            g.poly((150, 190, 100), q)
            rr = t.r(f"flax{q[0]}")
            for _ in range(16):
                a, b = rr.random(), rr.random()
                pt = lerp(lerp(q[0], q[1], a), lerp(q[3], q[2], a), b)
                g.circle((80, 120, 230), pt, 1.9)
                g.circle((170, 196, 252), (pt[0] - 0.5, pt[1] - 0.5), 0.7)
        else:
            g.poly((70, 120, 56), q)
        g.poly((110, 140, 70), q, 1)
    hemp_pts = []
    for q, hemp, c in beds:
        if hemp:
            for a in (0.2, 0.5, 0.8):
                for b in (0.25, 0.6, 0.95):
                    hemp_pts.append(lerp(lerp(q[0], q[1], a), lerp(q[3], q[2], a), b))
    for x, y in sorted(hemp_pts, key=lambda q: q[1]):
        o.line((60, 110, 50), (x, y), (x, y - 9), 1.2)
        for k in range(5):
            a = math.radians(-90 + (k - 2) * 38)
            o.line((40, 110, 48) if k % 2 else (66, 140, 60), (x, y - 9),
                   (x + math.cos(a) * 4.5, y - 9 + math.sin(a) * 4.5), 1.4)
    t.stamp(1)
    if lv >= 3:                                  # retting pond with bundles
        x, y = t.at(-30, 36)
        g.poly((96, 120, 90), [(x - 14, y + 6), (x + 10, y + 6), (x + 16, y - 4), (x - 8, y - 4)])
        g.poly((96, 140, 150), [(x - 12, y + 5), (x + 9, y + 5), (x + 14, y - 3), (x - 7, y - 3)])
        for k in range(3):
            o.poly((206, 180, 110), [(x - 8 + k * 7, y + 2), (x - 3 + k * 7, y + 2), (x - 1 + k * 7, y - 1),
                                     (x - 6 + k * 7, y - 1)])
        t.stamp(1)
        for k in range(3):
            sx, sy = t.at(-48 + k * 7, 12 - k * 2)
            o.poly((214, 190, 110), [(sx - 3, sy), (sx + 3, sy), (sx, sy - 10)])
            o.poly((180, 156, 86), [(sx, sy), (sx + 3, sy), (sx, sy - 10)])
        t.stamp()
    if lv == 4:                                  # rope yard: posts and taut ropes
        a, b = t.at(-40, -34), t.at(36, -40)
        for k in range(4):
            q = lerp(a, b, k / 3)
            o.line(DWOOD, q, (q[0], q[1] - 8), 1.6)
        o.line((210, 180, 110), (a[0], a[1] - 6), (b[0], b[1] - 6), 1.2)
        o.line((210, 180, 110), (a[0], a[1] - 4), (b[0], b[1] - 4), 1.2)
        person(o, a[0] + 6, a[1] + 2, (150, 60, 50))
        t.stamp()
    if lv >= 5:                                  # the long ropewalk
        x, y = t.X(-2), CY - 28
        t.shadow(x + 6, y, 96, 10)
        building(o, x, y, 86, 8, 9, (226, 206, 170), (150, 80, 60), "side", rh=5, door=False, wins=8)
        t.stamp()
        for k, (dx, dy) in enumerate(((30, 46), (40, 40), (24, 40))):
            cx, cy = t.at(dx, dy)
            o.oval((190, 150, 90), cx, cy - 2, 5, 3)
            o.oval((150, 110, 60), cx, cy - 2, 2.2, 1.2)
        t.stamp()


def olive_tree(p, x, y, s=1.0):
    p.lines((96, 76, 60), [(x, y), (x - 1.5 * s, y - 3 * s), (x + 1 * s, y - 6 * s)], 2.2 * s)
    c1, c2, c3 = (138, 154, 128), (164, 178, 150), (200, 210, 186)
    for dx, dy, r in ((-4, -9, 4.4), (4, -9, 4.2), (0, -12, 4.6)):
        p.circle(shade(c1, -0.1), (x + dx * s, y + dy * s), r * s)
    for dx, dy, r in ((-4.5, -10, 3.4), (3, -10.5, 3.2), (-0.5, -13, 3.6)):
        p.circle(c2, (x + dx * s, y + dy * s), r * s)
    p.circle(c3, (x - 2 * s, y - 14 * s), 1.6 * s)
    p.circle((60, 70, 50), (x + 2 * s, y - 8 * s), 0.8 * s)


def amphora(p, x, y, s=1.0):
    c = (200, 110, 64)
    p.poly(c, [(x - 1 * s, y), (x + 1 * s, y), (x + 3.4 * s, y - 5 * s), (x + 2.6 * s, y - 9 * s),
               (x + 1.2 * s, y - 10 * s), (x - 1.2 * s, y - 10 * s), (x - 2.6 * s, y - 9 * s), (x - 3.4 * s, y - 5 * s)])
    p.poly(shade(c, -0.25), [(x + 0.5 * s, y), (x + 1 * s, y), (x + 3.4 * s, y - 5 * s), (x + 2.6 * s, y - 9 * s),
                             (x + 0.5 * s, y - 10 * s)])
    p.rect(shade(c, 0.1), x - 1.6 * s, y - 12 * s, 3.2 * s, 2 * s)


def _olives(t):
    lv, g, o = t.lv, t.g, t.o
    base = (210, 176, 104)
    t.ground(base)
    r = t.r("dry")
    for _ in range(24):
        x, y = r.uniform(5, 115), r.uniform(5, 135)
        g.circle((190, 156, 86), (x, y), r.uniform(1, 2.6))
    nw = [3, 3, 4, 4, 4][lv - 1]
    walls_y = [-34, -8, 18, 44][:nw]
    for wy in walls_y:
        pts = t.pts([(-70, wy + 4), (-30, wy), (0, wy + 3), (34, wy - 2), (70, wy + 2)])
        g.poly((196, 160, 90), [(x, y) for x, y in pts] + [(pts[-1][0], pts[-1][1] - 9), (pts[0][0], pts[0][1] - 9)])
        stone_wall(g, pts, (214, 206, 186), 3.4)
    trees = [(-28, -44), (16, -46), (-14, -18), (28, -20), (-34, 8), (6, 8), (-14, 34), (22, 32), (38, 6),
             (-42, -16), (-4, -46), (2, 34)]
    nt = [6, 8, 10, 11, 12][lv - 1]
    taken = []
    if lv >= 5:
        taken = [(20, 40), (36, 26)]
    sel = [q for q in trees if all(math.hypot(q[0] - a, q[1] - b) > 16 for a, b in taken)][:nt]
    for dx, dy in sorted(sel, key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        olive_tree(o, x, y, 1.45)
    t.stamp()
    if lv >= 3:
        jars = [(-34, 50), (-28, 52), (-22, 50), (-31, 46), (-16, 53), (-25, 45), (-10, 50)][:[0, 0, 3, 5, 7][lv - 1]]
        for dx, dy in sorted(jars, key=lambda q: q[1]):
            amphora(o, *t.at(dx, dy))
        t.stamp()
    if lv >= 4:                                  # a donkey with panniers
        x, y = t.at(-4, 54)
        horse(o, x, y, (150, 140, 130), 0.8, t.flip, False, (90, 84, 80))
        o.rect((170, 120, 70), x - 4, y - 10, 6, 4)
        t.stamp()
    if lv >= 5:                                  # olive press house with millstone
        x, y = t.at(24, 46)
        t.shadow(x + 6, y, 34)
        building(o, x, y, 22, 12, 14, STONE, ROOF_RED, "side", rh=8, wins=2)
        t.stamp()
        mx = x + (-20 if not t.flip else 20)
        o.oval((170, 164, 150), mx, y + 6, 9, 4)
        o.oval((140, 134, 122), mx, y + 6, 6, 2.5)
        o.rect((190, 186, 176), mx - 2, y - 6, 4, 11)
        o.oval((220, 216, 204), mx, y - 0.5, 2, 5.5)
        o.line(DWOOD, (mx, y + 2), (mx + 9, y - 2), 1.4)
        t.stamp()


def _silk(t):
    lv, g, o = t.lv, t.g, t.o
    base = (196, 206, 140)
    t.ground(base)
    rows = [-44, -26, -8, 10, 28, 46]
    nr = [3, 5, 6, 6, 6][lv - 1]
    for k, ry in enumerate(rows):
        g.line((176, 186, 120), (0, CY + ry + 4), (W, CY + ry + 2), 2)
    hedges = []
    for k, ry in enumerate(rows[:nr] if lv < 3 else rows):
        if lv < 3 and k >= nr:
            continue
        for seg in range(-2, 3):
            x0 = seg * 30 + (k % 2) * 12 - 10
            hedges.append((x0, ry, 22))
    blocked = []
    if lv >= 3:
        blocked.append((-24, -14, 24))
    if lv >= 4:
        blocked.append((-30, 32, 22))
    if lv >= 5:
        blocked.append((18, 4, 34))
    for x0, ry, ln in sorted(hedges, key=lambda q: q[1]):
        if any(abs(x0 + ln / 2 - bx) < br and abs(ry - by) < 14 for bx, by, br in blocked):
            continue
        a, b = t.at(x0, ry), t.at(x0 + ln, ry - 2)
        o.band((54, 120, 60), [(a[0], a[1] - 3), (b[0], b[1] - 3)], 8)
        o.band((84, 152, 72), [(a[0], a[1] - 5), (b[0], b[1] - 5)], 4)
        for k in range(3):
            q = lerp(a, b, 0.2 + k * 0.3)
            o.circle((150, 60, 110), (q[0], q[1] - 1.5), 0.9)
    t.stamp(1)

    def worm_shed(x, y):
        t.shadow(x + 4, y, 28)
        for row in range(3):
            o.rect((150, 110, 70), x - 9, y - 3 - row * 3.5, 18, 1)
            for k in range(7):
                o.circle(WHITE, (x - 7.5 + k * 2.5, y - 4.4 - row * 3.5), 1.2)
        shed(o, x, y, 20, 12, 13, (176, 120, 72))
        t.stamp()
    if lv == 1:
        x, y = t.at(-6, 6)
        person(o, x, y, (190, 60, 80), 1.0, (240, 230, 200))
        o.rect((180, 140, 80), x + 3, y - 6, 4, 3)
        t.stamp()
    if lv >= 3:
        worm_shed(*t.at(-24, -12))
    if lv >= 4:
        worm_shed(*t.at(-30, 32))
        x, y = t.at(4, 48)
        for k in range(3):
            o.rect((180, 140, 80), x - 7 + k * 6, y - 4, 5, 4, br=1)
            o.circle(WHITE, (x - 4.5 + k * 6, y - 4.5), 1.6)
        t.stamp()
    if lv >= 2:
        x, y = t.at(30, -6) if lv < 5 else t.at(-4, 30)
        person(o, x, y, (190, 60, 80), 1.0, (240, 230, 200))
        t.stamp()
    if lv >= 5:                                  # domed caravanserai
        x, y = t.at(10, 10)
        t.shadow(x + 10, y, 64)
        wall = (234, 222, 198)
        building(o, x, y, 50, 12, 26, wall, shade(wall, 0.1), "flat", door=False)
        for k in range(6):
            ax = x - 20 + k * 8
            o.poly(DARK, ell(ax, y - 3, 2.4, 3, 180, 360, 6) + [(ax + 2.4, y), (ax - 2.4, y)])
        o.rect((200, 60, 60), x - 3, y - 12, 6, 2)
        dx_, dy_ = 26 * 0.55 / 2, -26 * 0.42 / 2
        dome(o, x + dx_, y - 12 + dy_, 16, (128, 148, 176))
        o.line((230, 200, 90), (x + dx_, y - 28 + dy_), (x + dx_, y - 34 + dy_), 1.4)
        o.circle((230, 200, 90), (x + dx_, y - 34 + dy_), 1.4)
        for sx in (-18, 30):
            dome(o, x + sx, y - 12 + dy_ * 0.6, 5, (128, 148, 176))
        mx = x + (30 if not t.flip else -30)
        tower(o, mx, y + 4, 2.8, 30, wall, (128, 148, 176), 7)
        o.rect(shade(wall, -0.2), mx - 3.6, y - 20, 7.2, 1.6)
        t.stamp()


DYE_COLS = [(44, 70, 172), (196, 40, 52), (242, 200, 40), (60, 150, 70), (120, 50, 140), (230, 120, 40)]


def vat(p, x, y, col, r=7):
    p.oval((110, 76, 50), x, y, r + 1.5, (r + 1.5) * 0.5)
    p.rect((130, 90, 56), x - r - 1.5, y - 4, 2 * r + 3, 4)
    p.rect((100, 68, 42), x + r * 0.2, y - 4, r * 0.8 + 1.5, 4)
    p.oval((150, 106, 66), x, y - 4, r + 1.5, (r + 1.5) * 0.5)
    p.oval(col, x, y - 4, r, r * 0.5)
    p.oval(shade(col, 0.35), x - r * 0.4, y - 4 - r * 0.15, r * 0.35, r * 0.15)


def cloth_line(p, a, b, cols, drop=10):
    p.line(DWOOD, a, (a[0], a[1] - 16), 1.5)
    p.line(DWOOD, b, (b[0], b[1] - 16), 1.5)
    p.line((90, 80, 70), (a[0], a[1] - 15), (b[0], b[1] - 15), 0.7)
    n = len(cols)
    for k, c in enumerate(cols):
        q0 = lerp((a[0], a[1] - 15), (b[0], b[1] - 15), (k + 0.15) / n)
        q1 = lerp((a[0], a[1] - 15), (b[0], b[1] - 15), (k + 0.85) / n)
        p.poly(c, [q0, q1, (q1[0], q1[1] + drop), (q0[0], q0[1] + drop)])
        p.poly(shade(c, -0.25), [lerp(q0, q1, 0.6), q1, (q1[0], q1[1] + drop), (lerp(q0, q1, 0.6)[0],
                                                                                  lerp(q0, q1, 0.6)[1] + drop)])


def _dyes(t):
    lv, g, o = t.lv, t.g, t.o
    base = (164, 150, 116)
    t.ground(base)
    r = t.r("mud")
    for _ in range(16):
        g.circle((146, 132, 100), (r.uniform(5, 115), r.uniform(5, 135)), r.uniform(1.5, 3))
    # coloured runoff stream (rainbow bands)
    strm = t.pts([(-10, -10), (-4, 14), (8, 36), (4, 60), (12, 80)])
    for k, c in enumerate((DYE_COLS[0], DYE_COLS[4], DYE_COLS[1])):
        g.band(mix(c, base, 0.25), [(x - 3 + k * 3, y) for x, y in strm], 4)
    vats = [(-22, -8, 0), (-6, -14, 1), (10, -8, 2), (-30, 8, 4), (24, 2, 3), (-14, 4, 5), (26, -18, 1)]
    nv = [3, 5, 6, 7, 7][lv - 1]
    for dx, dy, ci in sorted(vats[:nv], key=lambda q: q[1]):
        x, y = t.at(dx, dy)
        vat(o, x, y, DYE_COLS[ci])
        t.stamp()
    lines = [((-46, 36), (-16, 40), [0, 1, 2]), ((14, 34), (44, 30), [3, 4, 5]),
             ((-30, 58), (0, 60), [1, 2, 0]), ((-40, -36), (-12, -40), [2, 0, 4])]
    nl = [1, 2, 3, 4, 3][lv - 1]
    for a, b, ci in sorted(lines[:nl], key=lambda q: q[0][1]):
        pa, pb = t.at(*a), t.at(*b)
        if t.flip:
            pa, pb = pb, pa
        cloth_line(o, pa, pb, [DYE_COLS[c] for c in ci])
        t.stamp()
    if lv >= 3:                                  # small dye shed
        x, y = t.at(-36, -18)
        t.shadow(x + 4, y, 24)
        building(o, x, y, 14, 9, 11, (180, 140, 100), (120, 90, 70), "side", rh=6, wins=1)
        t.stamp()
    if lv >= 5:                                  # dye house with a tall drying loft
        x, y = t.at(22, -22)
        t.shadow(x + 6, y, 36)
        dx, dy = 14 * 0.55, -14 * 0.42
        building(o, x, y, 22, 14, 14, (226, 208, 176), (150, 84, 62), "flat", wins=2)
        ly = y - 14
        for px in (x - 11, x + 11, x + 11 + dx):
            o.line(DWOOD, (px, ly + (dy if px > x + 12 else 0)), (px, ly - 14 + (dy if px > x + 12 else 0)), 1.6)
        for k, c in enumerate((DYE_COLS[0], DYE_COLS[1], DYE_COLS[2], DYE_COLS[4], DYE_COLS[3])):
            cx = x - 9 + k * 4.4
            o.rect(c, cx, ly - 13, 3.6, 11)
        o.poly((150, 84, 62), [(x - 13, ly - 14), (x + 13, ly - 14), (x + 13 + dx, ly - 14 + dy), (x - 13 + dx, ly - 14 + dy),
                               ])
        o.poly((176, 100, 74), [(x - 13, ly - 14), (x + 13, ly - 14), (x + 13 + dx / 2, ly - 22 + dy / 2),
                                (x - 13 + dx / 2, ly - 22 + dy / 2)])
        o.poly((120, 66, 50), [(x + 13, ly - 14), (x + 13 + dx, ly - 14 + dy), (x + 13 + dx / 2, ly - 22 + dy / 2)])
        t.stamp()


def cocoa_tree(p, x, y, s=1.0):
    p.rect((100, 70, 46), x - 1.4 * s, y - 8 * s, 2.8 * s, 8 * s)
    p.circle((24, 82, 48), (x + 1 * s, y - 13 * s), 7 * s)
    p.circle((40, 110, 58), (x - 1 * s, y - 14 * s), 5.8 * s)
    p.circle((70, 140, 70), (x - 3 * s, y - 16 * s), 2.2 * s)
    for dx, dy, c in ((-2.6, -5, (240, 150, 40)), (2.6, -6, (220, 100, 40)), (-2.2, -9.5, (250, 196, 60))):
        p.oval(c, x + dx * s - 1.3 * s, y + dy * s - 2 * s, 2.6 * s, 4 * s)


def _cocoa(t):
    lv, g, o = t.lv, t.g, t.o
    t.ground((32, 92, 56))
    cc = t.at(-2, 10)
    crx = 22 + 6 * lv
    cry = crx * 0.72
    g.poly((104, 146, 74), ell(cc[0], cc[1], crx, cry, 0, 360, 30))
    g.poly((90, 130, 64), ell(cc[0], cc[1], crx, cry, -60, 100, 14))
    canopy = []
    for x, y, k in jitter_grid(t, "canopy", 13, R + 4, 0.35):
        if ((x - cc[0]) / (crx + 2)) ** 2 + ((y - cc[1]) / (cry + 2)) ** 2 < 1:
            continue
        canopy.append((x, y, k))
    for x, y, k in sorted(canopy, key=lambda q: q[1]):
        rr = 9 + k * 4
        o.circle((22, 70, 44), (x + 1.5, y + 1), rr)
        o.circle((34, 100, 58) if k < 0.5 else (46, 118, 62), (x - 1, y - 1.5), rr * 0.85)
        o.circle((70, 146, 72), (x - rr * 0.35, y - rr * 0.45), rr * 0.3)
        if k > 0.8:
            o.circle((230, 80, 120), (x + 2, y - 2), 1.4)
    t.stamp(1)
    trees = [(-14, -6), (8, -10), (-22, 12), (16, 8), (-4, 22), (24, -4), (-30, -4), (2, 2), (-12, 34), (18, 28)]
    nt = [4, 6, 7, 8, 7][lv - 1]
    taken = []
    if lv >= 3:
        taken.append((16, 22))
    if lv >= 5:
        taken = [(4, -6), (16, 22)]
    sel = [q for q in trees if all(math.hypot(q[0] - a, q[1] - b) > 13 for a, b in taken)][:nt]
    for dx, dy in sorted(sel, key=lambda q: q[1]):
        x, y = cc[0] + (dx if not t.flip else -dx), cc[1] + dy
        cocoa_tree(o, x, y, 1.0)
    t.stamp()
    if lv >= 3:                                  # drying mats with beans + hut
        for k, (dx, dy) in enumerate(((16, 22), (2, 30))[:1 if lv < 4 else 2]):
            x, y = cc[0] + (dx if not t.flip else -dx), cc[1] + dy
            mat = [(x - 9, y), (x + 9, y), (x + 13, y - 5), (x - 5, y - 5)]
            g.poly((214, 190, 136), mat)
            rr = t.r(f"beans{k}")
            for _ in range(14):
                q = lerp(lerp(mat[0], mat[1], rr.random()), lerp(mat[3], mat[2], rr.random()), rr.random())
                g.circle((110, 60, 40), q, 1)
        x, y = cc[0] + (-20 if not t.flip else 20), cc[1] - 12
        if lv < 5:
            t.shadow(x + 3, y, 20)
            building(o, x, y, 12, 8, 10, (190, 150, 100), THATCH, "front", rh=7)
            t.stamp()
    if lv >= 5:                                  # hacienda around a courtyard
        x, y = cc[0] + (4 if not t.flip else -4), cc[1] - 2
        wall, roof = (246, 240, 228), (206, 92, 62)
        t.shadow(x + 8, y + 4, 56)
        building(o, x + 2, y - 10, 36, 10, 10, wall, roof, "side", rh=6, wins=4, door=False)
        t.stamp()
        building(o, x - 18, y + 2, 8, 9, 18, wall, roof, "side", rh=5, door=False)
        g.poly((200, 180, 140), [(x - 12, y + 2), (x + 18, y + 2), (x + 22, y - 6), (x - 8, y - 6)])
        t.stamp()
        o.poly((206, 160, 100), [(x - 10, y + 1), (x + 16, y + 1), (x + 19, y - 4), (x - 7, y - 4)])
        t.stamp(0)
        round_tree(o, x + 4, y + 1, 4, (60, 150, 70), th=3)
        t.stamp()
        building(o, x + 24, y + 4, 8, 9, 18, wall, roof, "side", rh=5, door=False)
        t.stamp()
        o.rect(wall, x - 14, y + 4, 34, 5)
        o.rect(shade(wall, -0.1), x - 14, y + 7.5, 34, 1.5)
        o.poly(DARK, ell(x + 3, y + 9, 3, 4, 180, 360, 6))
        flag(o, x + 3, y - 2, 7, (200, 160, 40))
        t.stamp()


def coffee_shrub(p, x, y):
    p.circle((38, 98, 46), (x, y - 3), 3.6)
    p.circle((58, 128, 58), (x - 0.8, y - 3.8), 2.6)
    p.circle((214, 40, 40), (x + 1.6, y - 2), 0.95)
    p.circle((230, 60, 50), (x - 1.4, y - 1.6), 0.95)


def _coffee(t):
    lv, g, o = t.lv, t.g, t.o
    hill = (82, 128, 66)
    t.ground(hill)
    # mountain backdrop
    g.poly((96, 112, 84), t.pts([(-80, -30), (-40, -56), (-16, -48), (12, -70), (40, -48), (80, -60), (80, -80),
                                 (-80, -80)]))
    g.poly((78, 92, 70), t.pts([(12, -70), (40, -48), (80, -60), (80, -80), (12, -80)]))
    nt = [3, 5, 6, 7, 7][lv - 1]
    ys = [56, 42, 28, 14, 0, -14, -28][:nt]
    for k, ty in enumerate(ys):
        sl = (k % 2) * 4 - 2
        top = t.pts([(-80, ty - 6 + sl), (80, ty - 6 - sl)])
        bot = t.pts([(-80, ty + sl), (80, ty - sl)])
        g.poly((90, 140, 66), [top[0], top[1], (top[1][0], top[1][1] + 8), (top[0][0], top[0][1] + 8)])
        g.poly((150, 82, 56), [bot[0], bot[1], (bot[1][0], bot[1][1] + 6), (bot[0][0], bot[0][1] + 6)])
        g.line((112, 60, 42), (bot[0][0], bot[0][1] + 6), (bot[1][0], bot[1][1] + 6), 1)
    wild = []
    for x, y, k in jitter_grid(t, "wild", 14, R - 4, 0.35):
        if CY - 52 < y < CY + ys[-1] - 12:
            wild.append((x, y, k))
    for x, y, k in sorted(wild, key=lambda q: q[1]):
        if k < 0.55:
            round_tree(o, x, y + 6, 5 + k * 3, (52, 110, 56), th=3)
        elif k < 0.8:
            o.circle((60, 104, 58), (x, y), 3)
    t.stamp(1)
    shrubs = []
    for k, ty in enumerate(ys):
        sl = (k % 2) * 4 - 2
        for i in range(12):
            dx = -62 + i * 11 + (k % 2) * 5
            yy = ty - 1 + sl - (dx + 80) / 160 * 2 * sl
            shrubs.append((dx, yy))
    blocked = []
    if lv >= 3:
        blocked.append((-30, 30, 16))
    if lv >= 4:
        blocked += [(26, 16, 14)]
    if lv >= 5:
        blocked.append((20, 2, 18))
    for dx, dy in sorted(shrubs, key=lambda q: q[1]):
        if any(abs(dx - bx) < br and abs(dy - by) < 10 for bx, by, br in blocked):
            continue
        x, y = t.at(dx, dy)
        coffee_shrub(o, x, y)
    t.stamp(1)
    if lv >= 3:                                  # drying patios
        pats = [(-30, 30)] + ([(26, 16)] if lv >= 4 else [])
        for k, (dx, dy) in enumerate(pats):
            x, y = t.at(dx, dy)
            pat = [(x - 13, y + 3), (x + 13, y + 3), (x + 15, y - 5), (x - 11, y - 5)]
            o.poly((226, 214, 192), pat)
            rr = t.r(f"beans{k}")
            for _ in range(22):
                q = lerp(lerp(pat[0], pat[1], rr.random()), lerp(pat[3], pat[2], rr.random()), rr.random())
                o.circle((120, 66, 40), q, 1)
            t.stamp(1)
            person(o, x + 8, y + 1, (220, 220, 210), 1.0, (240, 240, 230))
            t.stamp()
    if lv == 4:
        x, y = t.at(-10, -18)
        t.shadow(x + 4, y, 22)
        building(o, x, y, 14, 14, 10, (176, 130, 92), (176, 130, 92), "flat", wins=2)
        o.rect(WHITE, x - 7, y - 15, 14, 1.5)
        t.stamp()
    if lv >= 5:                                  # Yemeni tower house
        x, y = t.at(20, 4)
        t.shadow(x + 6, y, 26)
        wall = (170, 120, 84)
        building(o, x, y, 18, 44, 12, wall, (176, 130, 92), "flat", door=False)
        o.rect(WHITE, x - 9, y - 30, 18, 1.4)
        o.rect(WHITE, x - 9, y - 18, 18, 1.4)
        o.rect((240, 236, 226), x - 9, y - 44, 18, 4)
        for row, wy in enumerate((y - 40, y - 28, y - 16)):
            for wx in (x - 5, x + 2):
                o.rect(WHITE, wx - 0.8, wy - 0.8, 4.6, 6.6)
                o.rect(DARK, wx, wy, 3, 5)
                if row == 0:
                    o.circle(WHITE, (wx + 1.5, wy - 1.6), 1.6)
        o.rect(DARK, x - 2, y - 7, 4, 7)
        for k in range(4):
            o.poly(WHITE, [(x - 9 + k * 5, y - 44), (x - 6 + k * 5, y - 44), (x - 7.5 + k * 5, y - 48)])
        building(o, x - (16 if not t.flip else -16), y + 6, 14, 18, 10, wall, (176, 130, 92), "flat", wins=2)
        o.rect(WHITE, x - (23 if not t.flip else -9), y - 13, 14, 1.4)
        t.stamp()


_GOODS = {"grain": _grain, "wine": _wine, "wool": _wool, "cotton": _cotton, "sugar": _sugar,
          "tobacco": _tobacco, "timber": _timber, "iron": _iron, "silver": _silver, "gold": _gold,
          "salt": _salt, "fish": _fish, "furs": _furs, "ivory": _ivory, "spices": _spices, "horses": _horses,
          "cattle": _cattle, "stone": _stone, "copper": _copper, "hemp": _hemp, "olives": _olives,
          "silk": _silk, "dyes": _dyes, "cocoa": _cocoa, "coffee": _coffee}


def good_tile(good, level, tiles_dir, variant=0):
    """A 120 x 140 tile for a province investing in `good` at `level` (1..5); variant 0..2 varies the layout.

    None for goods without art (cloth, tools, weapons...): the caller keeps its plain tile."""
    if good not in _GOODS:
        return None
    t = Tile(good, max(1, min(5, int(level))), variant, tiles_dir)
    _GOODS[good](t)
    return t.finish()
