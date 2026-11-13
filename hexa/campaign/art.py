"""Extra tiles, decorations, unit figures and tokens in the flat style of the Kenney hexagon pack.

Terrain tiles and decorations are assembled from the pack's own object sprites (trees, rocks, hay, houses ...) on
the pack's own base colours, so they sit seamlessly beside the original tiles. Units are drawn in code.
Everything is drawn at the pack's size (120 x 140, a pointy-top hex) and scaled by the map view.
"""
import math
import os
import random

import pygame

from .render.cache import BoundedCache

W, H = 120, 140
CX, CY = W / 2, H / 2
R = 69.3                                   # centre to corner of the pack's hexes
OUTLINE = (45, 45, 50)
GOLD = (255, 214, 70)
INK = (30, 30, 38)
RAW_CACHE = 256                              # the pack's sprites as loaded (sizes: python -m tools.perf)
OBJECT_CACHE = 256                           # scaled / tinted object sprites


def hex_pts(r=R, cx=CX, cy=CY):
    return [(cx + r * math.cos(math.radians(60 * i - 30)), cy + r * math.sin(math.radians(60 * i - 30)))
            for i in range(6)]


def shade(color, k):
    """k > 0 lightens, k < 0 darkens."""
    return tuple(max(0, min(255, int(c + (255 - c) * k if k > 0 else c * (1 + k)))) for c in color)


def blank():
    return pygame.Surface((W, H), pygame.SRCALPHA)


def base(color):
    surf = blank()
    pygame.draw.polygon(surf, color, hex_pts())
    return surf


def inside(x, y, r=R - 14):
    """Whether a point is comfortably inside the hex."""
    dx, dy = abs(x - CX), abs(y - CY)
    return dy <= r and dx <= r * math.sqrt(3) / 2 and dx * 0.5 + dy * math.sqrt(3) / 2 <= r * math.sqrt(3) / 2


def scatter(rng, n, r=R - 16, spacing=18):
    points = []
    tries = 0
    while len(points) < n and tries < 400:
        tries += 1
        x, y = rng.uniform(CX - r, CX + r), rng.uniform(CY - r, CY + r)
        if inside(x, y, r) and all(math.hypot(x - a, y - b) > spacing for a, b in points):
            points.append((x, y))
    return sorted(points, key=lambda p: p[1])


def smooth(points, rounds=3, wobble=0.0, seed=0):
    """Chaikin smoothing (with a little random wobble) to turn hex-centre paths into rivers."""
    rng = random.Random(seed)
    pts = [(x + rng.uniform(-wobble, wobble), y + rng.uniform(-wobble, wobble)) for x, y in points]
    for _ in range(rounds):
        out = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            out += [(ax * 0.75 + bx * 0.25, ay * 0.75 + by * 0.25), (ax * 0.25 + bx * 0.75, ay * 0.25 + by * 0.75)]
        out.append(pts[-1])
        pts = out
    return pts


# ----- loading the pack's sprites ------------------------------------------------------------------
_RAW = BoundedCache("art.raw", RAW_CACHE)
_OBJECTS = BoundedCache("art.objects", OBJECT_CACHE)


def _load(path):
    img = _RAW.get(path)
    if img is None:
        img = pygame.image.load(path)
        try:
            img = img.convert_alpha()
        except pygame.error:
            pass
        _RAW.put(path, img)
    return img


def _objects_dir(tiles_dir):
    return os.path.join(os.path.dirname(tiles_dir), "Objects")


def _snowcap(img):
    """Whiten the upper part of a tree so it looks snowed on."""
    out = img.copy()
    w, h = out.get_size()
    for y in range(h):
        k = 0.8 if y < h * 0.35 else 0.55 if y < h * 0.62 else 0.0
        if y > h * 0.62:
            break
        if int(y / max(1, h / 7)) % 2 == 1:
            k *= 0.45                       # tiers: alternate bands stay darker
        for x in range(w):
            r, g, b, a = out.get_at((x, y))
            if a:
                out.set_at((x, y), (int(r + (246 - r) * k), int(g + (249 - g) * k), int(b + (252 - b) * k), a))
    return out


def _obj(tiles_dir, name, scale=1.0, tint=None, snow=False):
    key = (tiles_dir, name, scale, tint, snow)
    img = _OBJECTS.get(key)
    if img is None:
        img = _load(os.path.join(_objects_dir(tiles_dir), name + ".png"))
        if scale != 1.0:
            img = pygame.transform.smoothscale(img, (max(1, int(img.get_width() * scale)),
                                                     max(1, int(img.get_height() * scale))))
        if tint:
            img = img.copy()
            img.fill(tuple(tint) + (255,), special_flags=pygame.BLEND_RGBA_MULT)
        if snow:
            img = _snowcap(img)
        _OBJECTS.put(key, img)
    return img


def _tile_img(tiles_dir, rel):
    return _load(os.path.join(tiles_dir, *rel.split("/"))).copy()


def _put(surf, img, x, y, flip=False):
    """Blit an object standing with its feet at (x, y)."""
    if flip:
        img = pygame.transform.flip(img, True, False)
    surf.blit(img, (round(x - img.get_width() / 2), round(y - img.get_height())))


def _ground_shadow(surf, x, y, w):
    sh = pygame.Surface((int(w) + 2, int(w * 0.4) + 2), pygame.SRCALPHA)
    pygame.draw.ellipse(sh, (0, 0, 0, 40), sh.get_rect())
    surf.blit(sh, (round(x - sh.get_width() / 2), round(y - sh.get_height() / 2)))


def _kbase(color):
    """A base hex in the pack's colours with its faint darker rim."""
    s = base(color)
    pygame.draw.polygon(s, shade(color, -0.12), hex_pts(), 3)
    return s


def _rot(pt, deg, c=(0, 0)):
    a = math.radians(deg)
    x, y = pt[0] - c[0], pt[1] - c[1]
    return c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a)


# ----- small code-drawn helpers (grass tufts, sheep, boat) ---------------------------------------------
def tuft(surf, x, y, color=(30, 130, 70), n=3):
    for dx in ((-3, 0, 3) if n == 3 else (-4, -1, 2, 5)):
        pygame.draw.line(surf, color, (x, y), (x + dx, y - 6), 2)


def reed(surf, x, y):
    pygame.draw.line(surf, (60, 105, 55), (x, y), (x - 1, y - 12), 2)
    pygame.draw.line(surf, (75, 125, 65), (x + 3, y), (x + 4, y - 9), 2)
    pygame.draw.line(surf, (120, 80, 50), (x - 1, y - 12), (x - 1, y - 16), 3)


def _acacia(surf, x, y):
    pygame.draw.line(surf, (110, 76, 46), (x, y), (x, y - 15), 3)
    pygame.draw.line(surf, (110, 76, 46), (x, y - 10), (x + 6, y - 16), 2)
    pygame.draw.ellipse(surf, (70, 118, 52), (x - 15, y - 25, 30, 12))
    pygame.draw.ellipse(surf, (98, 150, 66), (x - 15, y - 26, 30, 11))
    pygame.draw.ellipse(surf, (122, 172, 80), (x - 9, y - 26, 16, 5))


def sheep(surf, x, y):
    pygame.draw.ellipse(surf, INK, (x - 7, y - 6, 14, 10))
    pygame.draw.ellipse(surf, (250, 250, 245), (x - 6, y - 5, 12, 8))
    pygame.draw.ellipse(surf, (222, 224, 226), (x - 5, y - 1, 10, 4))
    pygame.draw.circle(surf, INK, (x + 6, y - 2), 3)
    pygame.draw.circle(surf, (70, 70, 75), (x + 6, y - 2), 2)
    pygame.draw.line(surf, INK, (x - 3, y + 3), (x - 3, y + 6), 2)
    pygame.draw.line(surf, INK, (x + 2, y + 3), (x + 2, y + 6), 2)


def boat(surf, x, y, s=1.0, sail=(250, 250, 250)):
    hull = [(x - 14 * s, y), (x + 14 * s, y), (x + 9 * s, y + 7 * s), (x - 9 * s, y + 7 * s)]
    pygame.draw.polygon(surf, INK, [(px + (1 if px > x else -1), py + (1 if py > y else -1)) for px, py in hull])
    pygame.draw.polygon(surf, (150, 105, 65), hull)
    pygame.draw.polygon(surf, (110, 74, 44), [(x - 11 * s, y + 3.5 * s), (x + 12 * s, y + 3.5 * s),
                                              (x + 9 * s, y + 7 * s), (x - 9 * s, y + 7 * s)])
    pygame.draw.line(surf, (90, 60, 35), (x, y), (x, y - 18 * s), 2)
    pygame.draw.polygon(surf, sail, [(x + 1, y - 17 * s), (x + 11 * s, y - 4 * s), (x + 1, y - 3 * s)])
    pygame.draw.polygon(surf, (215, 220, 228), [(x + 1, y - 10 * s), (x + 11 * s, y - 4 * s), (x + 1, y - 3 * s)])


# ----- new terrain tiles ---------------------------------------------------------------------------
def _spots(seed, n, spacing, r=R - 18):
    return scatter(random.Random(seed), n, r=r, spacing=spacing)


def _marsh(td, v):
    s = _kbase((70, 160, 105))
    rng = random.Random(30 + v)
    for x, y in _spots(3 + v * 11, 5, 28):
        pygame.draw.ellipse(s, (45, 125, 165), (x - 15, y - 5, 30, 13))
        pygame.draw.ellipse(s, (64, 150, 190), (x - 14, y - 6, 28, 12))
        pygame.draw.ellipse(s, (120, 190, 220), (x - 8, y - 4, 12, 4))
        if rng.random() < 0.5:
            pygame.draw.ellipse(s, (60, 150, 80), (x + 4, y - 3, 8, 5))          # lily pad
    for x, y in _spots(21 + v, 6, 18, R - 14):
        reed(s, x, y + 3)
    for i, (x, y) in enumerate(_spots(7 + v * 5, 4, 26)):
        _put(s, _obj(td, "treeRound_small", 0.9, (150, 200, 150)), x, y + 8)
    if v == 1:
        _put(s, _obj(td, "log"), CX + 14, CY + 34)
    return s


def _taiga(td, v):
    s = _kbase((228, 236, 244))
    rng = random.Random(4 + v * 9)
    for x, y in _spots(30 + v * 7, 4, 30):
        pygame.draw.ellipse(s, (205, 217, 232), (x - 12, y - 3, 24, 8))
    for x, y in _spots(5 + v * 13, 9, 19):
        big = rng.random() < 0.6
        _put(s, _obj(td, "treePine_large" if big else "treePine_small", 1.0, None, True), x, y + 8)
    return s


def _snow(td, v):
    s = _kbase((236, 242, 248))
    for x, y in _spots(9 + v * 4, 4, 30):
        pygame.draw.ellipse(s, (214, 224, 236), (x - 14, y - 4, 28, 8))
    layouts = [[("rockGrey_small1", -18, 4), ("rockGrey_small3", 22, 26)],
               [("rockGrey_medium1", 14, 6), ("rockGrey_small2", -22, 24)],
               [("rockGrey_small4", -12, -12), ("rockGrey_small1", 12, 24), ("treePine_small", 26, -4)]]
    for name, dx, dy in layouts[v % 3]:
        _put(s, _obj(td, name, 1.0, None, name.startswith("treePine")), CX + dx, CY + dy)
    return s


def _savanna(td, v):
    s = _kbase((214, 190, 110))
    for x, y in _spots(6 + v * 3, 8, 16):
        tuft(s, x, y, (170, 150, 70))
    for x, y in _spots(2 + v * 5, 3, 34):
        _acacia(s, x, y + 8)
    _put(s, _obj(td, "rockBrown_small" if v % 2 else "rockGrey_small2", 1.0, (255, 225, 190) if v % 2 else None),
         CX + (-30 if v % 2 else 28), CY + (22 if v % 2 else -18))
    return s


def _beach(td, v):
    s = _tile_img(td, "Terrain/Sand/sand_07.png")
    ang = 120 * (v % 3)
    pts = [(0, -75), (-6, -42), (12, -20), (-4, 0), (14, 22), (-2, 46), (0, 75), (70, 75), (70, -75)]
    poly = [(CX + _rot(p, ang)[0], CY + _rot(p, ang)[1]) for p in pts]
    shore = poly[:7]
    wet = pygame.Surface((W, H), pygame.SRCALPHA)
    pygame.draw.polygon(wet, (90, 175, 215), poly)
    pygame.draw.lines(wet, (130, 205, 230), False, shore, 10)
    pygame.draw.lines(wet, (90, 175, 215), False, shore, 4)
    pygame.draw.lines(wet, (250, 252, 252), False, shore, 3)
    mask = pygame.Surface((W, H), pygame.SRCALPHA)                     # keep water inside the hex
    pygame.draw.polygon(mask, (255, 255, 255, 255), hex_pts(R - 1))
    wet.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    s.blit(wet, (0, 0))
    pygame.draw.polygon(s, (70, 150, 195), [p for p in hex_pts(R - 1)], 2)
    px, py = _rot((-34, -6), ang)
    _put(s, _obj(td, "treeRound_large", 1.0, (170, 230, 170)), CX + px, CY + py + 10)
    px, py = _rot((-24, 34), ang)
    _put(s, _obj(td, "log"), CX + px, CY + py + 6, flip=bool(v))
    px, py = _rot((-30, -34), ang)
    _put(s, _obj(td, "rockGrey_small3", 0.8), CX + px, CY + py + 6)
    return s


def _vineyard(td, v):
    s = _tile_img(td, "Terrain/Dirt/dirt_06.png")
    vertical = v == 1
    for row in range(-2, 3):
        pos = row * 16 + (4 if v == 2 else 0)
        pygame.draw.line(s, (125, 92, 52), (CX - 46, CY + pos + 2), (CX + 46, CY + pos + 2), 1) if not vertical else None
        for t in range(-46, 48, 10):
            x, y = (CX + pos, CY + t) if vertical else (CX + t, CY + pos)
            if inside(x, y, R - 17) and not (v == 2 and x > CX + 12 and y < CY - 4):
                pygame.draw.line(s, (110, 80, 45), (x, y + 2), (x, y - 6), 2)
                pygame.draw.circle(s, (45, 120, 50), (x, y - 7), 5)
                pygame.draw.circle(s, (70, 150, 65), (x - 1, y - 8), 3)
                pygame.draw.circle(s, (125, 50, 110), (x + 2, y - 4), 2)
    if v == 2:
        _put(s, _obj(td, "house_small", 0.6), CX + 26, CY - 8)
    else:
        _put(s, _obj(td, "fence"), CX + (-40 if v == 0 else 38), CY + 38, flip=v == 1)
    return s


def _pasture(td, v):
    s = _tile_img(td, "Terrain/Grass/grass_05.png")
    for i in range(5):
        _put(s, _obj(td, "fence"), CX - 44 + i * 18, CY + 44 - i * 4 * (1 if v != 1 else -1) - (0 if v != 1 else 12))
    _put(s, _obj(td, "hay"), CX + (24 if v != 1 else -30), CY - 18)
    _put(s, _obj(td, "hay", 0.8), CX + (36 if v != 1 else -42), CY - 4)
    pos = [[(-24, -6), (-6, 4), (-30, 16), (6, -22)], [(10, -4), (28, 8), (0, 16), (22, -20)],
           [(-20, 0), (0, 10), (-8, -14), (20, 4), (10, 24)]][v % 3]
    for dx, dy in pos:
        sheep(s, CX + dx, CY + dy)
    return s


def _plantation(td, v):
    s = _tile_img(td, "Terrain/Dirt/dirt_06.png")
    for row in range(-2, 3):
        y = CY + row * 16 + (3 if v == 2 else 0)
        for x in range(int(CX - 48), int(CX + 40), 13):
            if inside(x, y, R - 16):
                pygame.draw.ellipse(s, (22, 100, 48), (x - 6, y - 5, 12, 10))
                pygame.draw.ellipse(s, (35, 130, 60), (x - 6, y - 6, 12, 9))
                pygame.draw.ellipse(s, (240, 240, 235), (x - 2, y - 4, 4, 3))
    hx = (24, -26, 28)[v % 3]
    hy = (-14, 30, 30)[v % 3]
    _put(s, _obj(td, "house_small", 0.8), CX + hx, CY + hy)
    return s


_TILES = {"marsh": _marsh, "taiga": _taiga, "snow": _snow, "savanna": _savanna, "beach": _beach,
          "vineyard": _vineyard, "pasture": _pasture, "plantation": _plantation}


def make_tile(name, tiles_dir, variant=0):
    """A 120 x 140 hex tile for a terrain the pack lacks, built from the pack's own sprites."""
    return _TILES[name](tiles_dir, variant % 3).convert_alpha() if pygame.display.get_surface() else \
        _TILES[name](tiles_dir, variant % 3)


# ----- decorations laid over ordinary tiles --------------------------------------------------------
def _ring(rng, n, radius=(40, 50), min_sep=65):
    """n positions around the edge of the hex (angles at least min_sep degrees apart)."""
    out = []
    for _ in range(300):
        if len(out) >= n:
            break
        a = rng.uniform(0, 360)
        if all(min(abs(a - b), 360 - abs(a - b)) >= min_sep for b in out):
            out.append(a)
    pts = []
    for a in out:
        r = rng.uniform(*radius)
        x, y = CX + r * math.cos(math.radians(a)) * 0.95, CY + r * math.sin(math.radians(a)) * 0.9
        if inside(x, y - 10, R - 10):
            pts.append((x, y))
    return sorted(pts, key=lambda p: p[1])


def decoration(kind, seed, tiles_dir):
    """A transparent overlay that makes plain tiles look less alike, or shows a settlement's growth."""
    surf = blank()
    rng = random.Random(seed)
    td = tiles_dir
    if kind == "trees":
        for x, y in scatter(rng, rng.randint(1, 3), spacing=30):
            name = rng.choice(("treePine_small", "treePine_large", "treeRound_small", "treeRound_large"))
            _put(surf, _obj(td, name), x, y + 12)
    elif kind == "rocks":
        for x, y in scatter(rng, rng.randint(1, 2), spacing=30):
            name = rng.choice(("rockGrey_small1", "rockGrey_small2", "rockGrey_medium1", "rockBrown_small",
                               "rockGrey_small5"))
            _put(surf, _obj(td, name), x, y + 10)
    elif kind == "hamlet":
        for x, y in scatter(rng, 3, r=34, spacing=26):
            _put(surf, _obj(td, "house_small", 0.65), x, y + 12, flip=rng.random() < 0.5)
    elif kind == "fields":
        x, y = CX + rng.uniform(-20, 8), CY + rng.uniform(-6, 18)
        _put(surf, _obj(td, "farmland", 0.8), x, y)
        for hx, hy in scatter(rng, 2, r=42, spacing=40):
            if math.hypot(hx - x, hy - y) > 28:
                _put(surf, _obj(td, "hay", 0.8), hx, hy + 8)
    elif kind == "smoke":
        cols = ((214, 214, 220), (200, 202, 210), (186, 188, 198))
        ox = rng.uniform(-3, 3)
        for i, (dx, dy, r) in enumerate(((14, -30, 7), (19, -43, 9), (14, -58, 11), (21, -75, 13))):
            puff = pygame.Surface((r * 4, r * 4), pygame.SRCALPHA)
            a = 190 - i * 40
            pygame.draw.circle(puff, cols[i % 3] + (a,), (r * 2, r * 2), r)
            pygame.draw.circle(puff, (240, 240, 245, a), (r * 2 - r // 3, r * 2 - r // 3), max(2, r * 2 // 3))
            surf.blit(puff, (CX + dx + ox - r * 2, CY + dy - r * 2))
    elif kind == "port":
        for i, px in enumerate((CX + 18, CX + 30, CX + 42)):
            pygame.draw.line(surf, INK, (px, CY + 24), (px, CY + 36), 5)
            pygame.draw.line(surf, (100, 70, 40), (px, CY + 24), (px, CY + 35), 3)
        pygame.draw.rect(surf, INK, (CX + 14, CY + 18, 42, 10), border_radius=2)
        pygame.draw.rect(surf, (165, 120, 72), (CX + 15, CY + 19, 40, 8), border_radius=2)
        pygame.draw.rect(surf, (125, 88, 52), (CX + 15, CY + 24, 40, 3))
        for px in (CX + 24, CX + 34, CX + 44):
            pygame.draw.line(surf, (125, 88, 52), (px, CY + 19), (px, CY + 26), 1)
        boat(surf, CX + 40, CY + 46, 0.9)
    elif kind in ("town", "city"):
        n = 2 if kind == "town" else 3
        for i, (x, y) in enumerate(_ring(rng, n)):
            if kind == "city" and i == n - 1 and n > 1:
                _put(surf, _obj(td, "tower", 0.42), x, y + 8)
            else:
                _put(surf, _obj(td, "house_small", 0.62), x, y + 8, flip=rng.random() < 0.5)
    return surf


# ----- unit figures --------------------------------------------------------------------------------
SKIN = (240, 205, 170)
METAL = (200, 205, 215)
WOOD = (130, 92, 55)


def _lw(s, n=2):
    return max(2, int(n * s * 1.25))


def _outlined(surf, color=INK, t=2):
    sil = pygame.mask.from_surface(surf, 20).to_surface(setcolor=color + (255,), unsetcolor=(0, 0, 0, 0))
    out = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
    for dx in range(-t, t + 1):
        for dy in range(-t, t + 1):
            if dx * dx + dy * dy <= t * t + 1:
                out.blit(sil, (dx, dy))
    out.blit(surf, (0, 0))
    return out


def _faded(surf):
    g = pygame.transform.grayscale(surf)
    g.fill((70, 70, 70, 0), special_flags=pygame.BLEND_RGB_ADD)
    g.set_alpha(215)
    out = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
    out.blit(g, (0, 0))
    return out


def _person(surf, x, y, s, coat, hat=(60, 50, 45)):
    for dx in (-2, 2):
        pygame.draw.line(surf, (60, 50, 45), (x + dx * s, y), (x + dx * s, y - 6 * s), _lw(s))
    body = pygame.Rect(0, 0, 9 * s, 11 * s)
    body.midbottom = (x, y - 5 * s)
    pygame.draw.rect(surf, coat, body, border_radius=int(2 * s))
    pygame.draw.rect(surf, shade(coat, -0.25), (body.centerx, body.y, body.w / 2, body.h), border_radius=int(2 * s))
    pygame.draw.circle(surf, SKIN, (x, body.y - 3 * s), 3.8 * s)
    pygame.draw.rect(surf, hat, (x - 4 * s, body.y - 8.5 * s, 8 * s, 3.5 * s))
    return body


def _draw_figure(surf, key, color, s, x, y):
    w = lambda n=2: _lw(s, n)  # noqa: E731
    if key in ("pikemen", "arquebusiers", "musketeers"):
        for dx in (-7, 7):
            _person(surf, x + dx * s, y, s, color, hat=METAL if key == "pikemen" else (40, 40, 45))
            if key == "pikemen":
                pygame.draw.line(surf, WOOD, (x + (dx + 5) * s, y - 2 * s), (x + (dx + 5) * s, y - 34 * s), w())
                pygame.draw.polygon(surf, METAL, [(x + (dx + 3) * s, y - 33 * s), (x + (dx + 5) * s, y - 40 * s),
                                                  (x + (dx + 7) * s, y - 33 * s)])
            else:
                pygame.draw.line(surf, (70, 55, 40), (x + (dx + 2) * s, y - 12 * s), (x + (dx + 12) * s, y - 20 * s), w())
    elif key in ("knights", "lancers", "cuirassiers"):
        horse = (125, 88, 58) if key != "cuirassiers" else (70, 52, 40)
        pygame.draw.ellipse(surf, horse, (x - 13 * s, y - 18 * s, 25 * s, 12 * s))
        for dx in (-10, -5, 4, 9):
            pygame.draw.line(surf, horse, (x + dx * s, y - 8 * s), (x + dx * s, y), w())
        pygame.draw.polygon(surf, horse, [(x + 8 * s, y - 16 * s), (x + 16 * s, y - 27 * s), (x + 20 * s, y - 22 * s),
                                          (x + 12 * s, y - 12 * s)])
        pygame.draw.polygon(surf, color, [(x - 9 * s, y - 15 * s), (x + 7 * s, y - 15 * s), (x + 4 * s, y - 8 * s),
                                          (x - 6 * s, y - 8 * s)])
        body = pygame.Rect(0, 0, 9 * s, 11 * s)
        body.midbottom = (x - 1 * s, y - 14 * s)
        pygame.draw.rect(surf, METAL if key != "lancers" else color, body, border_radius=int(2 * s))
        pygame.draw.circle(surf, METAL, (x - 1 * s, body.y - 3 * s), 4 * s)
        if key == "lancers":
            pygame.draw.line(surf, WOOD, (x - 6 * s, y - 14 * s), (x + 22 * s, y - 37 * s), w())
            pygame.draw.polygon(surf, color, [(x + 15 * s, y - 31 * s), (x + 22 * s, y - 37 * s), (x + 19 * s, y - 27 * s)])
        else:
            pygame.draw.line(surf, METAL, (x + 3 * s, y - 20 * s), (x + 12 * s, y - 33 * s), w())
    elif key in ("bombards", "culverins", "field_guns"):
        barrel = (80, 80, 88) if key != "culverins" else (170, 125, 62)
        length = {"bombards": 22, "culverins": 28, "field_guns": 24}[key]
        width = {"bombards": 10, "culverins": 7, "field_guns": 8}[key]
        start = (x - 12 * s, y - 10 * s)
        end = (x + (length - 12) * s, y - 20 * s)
        pygame.draw.line(surf, barrel, start, end, int(width * s))
        pygame.draw.circle(surf, barrel, end, width * s / 2)
        pygame.draw.rect(surf, WOOD, (x - 14 * s, y - 10 * s, 18 * s, 5 * s))
        pygame.draw.circle(surf, (100, 70, 40), (x - 6 * s, y - 5 * s), 6.5 * s, w())
        pygame.draw.circle(surf, color, (x - 6 * s, y - 5 * s), 2.5 * s)
    elif key == "wagon":
        pygame.draw.rect(surf, WOOD, (x - 14 * s, y - 14 * s, 24 * s, 8 * s))
        pygame.draw.ellipse(surf, (240, 235, 215), (x - 14 * s, y - 27 * s, 24 * s, 19 * s))
        pygame.draw.rect(surf, WOOD, (x - 14 * s, y - 16 * s, 24 * s, 3 * s))
        for dx in (-9, 5):
            pygame.draw.circle(surf, (90, 60, 35), (x + dx * s, y - 4 * s), 5.5 * s, w())
        pygame.draw.line(surf, (110, 80, 50), (x + 10 * s, y - 10 * s), (x + 20 * s, y - 8 * s), w())
        pygame.draw.rect(surf, color, (x - 4 * s, y - 23 * s, 7 * s, 7 * s))
    elif key == "general":
        body = _person(surf, x, y, s * 1.1, color, hat=(30, 30, 35))
        pygame.draw.line(surf, (90, 70, 50), (x + 8 * s, y), (x + 8 * s, y - 34 * s), w())
        pygame.draw.polygon(surf, GOLD, [(x + 8 * s, y - 34 * s), (x + 22 * s, y - 30 * s), (x + 8 * s, y - 26 * s)])
        pygame.draw.circle(surf, GOLD, (body.centerx, body.centery), 2.5 * s)
    elif key == "scout":
        _person(surf, x - 3 * s, y, s, color, hat=(90, 120, 60))
        pygame.draw.line(surf, (170, 140, 80), (x + 1 * s, y - 16 * s), (x + 11 * s, y - 21 * s), w(3))
        pygame.draw.circle(surf, METAL, (x + 12 * s, y - 21.5 * s), 2.2 * s)
    elif key == "pioneer":
        _person(surf, x - 3 * s, y, s, color, hat=(200, 160, 70))
        pygame.draw.line(surf, WOOD, (x + 2 * s, y - 6 * s), (x + 10 * s, y - 22 * s), w())
        pygame.draw.arc(surf, METAL, (x + 4 * s, y - 28 * s, 13 * s, 10 * s), 0.3, 2.9, w())
    elif key == "colonist":
        for dx, coat in ((-6, color), (6, shade(color, 0.35))):
            _person(surf, x + dx * s, y, s, coat, hat=(140, 100, 60))
        pygame.draw.rect(surf, (160, 120, 75), (x + 9 * s, y - 16 * s, 8 * s, 7 * s), border_radius=2)
    elif key in ("caravel", "carrack"):
        big = key == "carrack"
        hull = [(x - 18 * s, y - 12 * s), (x + 20 * s, y - 12 * s), (x + 13 * s, y - 2 * s), (x - 13 * s, y - 2 * s)]
        pygame.draw.polygon(surf, (135, 92, 55), hull)
        pygame.draw.polygon(surf, shade((135, 92, 55), -0.3), [(x - 13 * s, y - 6 * s), (x + 16 * s, y - 6 * s),
                                                              (x + 13 * s, y - 2 * s), (x - 13 * s, y - 2 * s)])
        masts = (-6, 6) if big else (0,)
        for mx in masts:
            pygame.draw.line(surf, (90, 60, 35), (x + mx * s, y - 12 * s), (x + mx * s, y - 40 * s), w())
            pygame.draw.rect(surf, (250, 248, 240), (x + (mx - 7) * s, y - 36 * s, 14 * s, 18 * s), border_radius=int(3 * s))
            pygame.draw.rect(surf, color, (x + (mx - 7) * s, y - 30 * s, 14 * s, 4 * s))
        pygame.draw.polygon(surf, color, [(x + masts[-1] * s, y - 41 * s), (x + (masts[-1] + 9) * s, y - 38 * s),
                                          (x + masts[-1] * s, y - 35 * s)])


def figure(key, color, size=48, faded=False):
    """A little figure for a unit, drawn on a soft base disc in the owner's colour (faded: no moves left)."""
    k = 2                                                     # drawn at 2x and scaled down for smooth edges
    big = size * k
    s = big / 40
    x, y = big / 2 - 2 * s, big * 0.86
    fig = pygame.Surface((big, big), pygame.SRCALPHA)
    _draw_figure(fig, key, color, s, x, y)
    fig = _outlined(fig, INK, 2)
    out = pygame.Surface((big, big), pygame.SRCALPHA)
    pygame.draw.ellipse(out, (0, 0, 0, 80), (x - 19 * s, y - 3 * s, 38 * s, 10 * s))
    pygame.draw.ellipse(out, INK, (x - 17 * s, y - 6 * s, 34 * s, 10 * s))
    pygame.draw.ellipse(out, shade(color, -0.1), (x - 16 * s, y - 5 * s, 32 * s, 8 * s))
    pygame.draw.ellipse(out, shade(color, 0.25), (x - 12 * s, y - 4.5 * s, 24 * s, 4 * s))
    out.blit(fig, (0, 0))
    out = pygame.transform.smoothscale(out, (size, size))
    return _faded(out) if faded else out


# ----- tokens for far zoom ---------------------------------------------------------------------------
_WAR = {"pikemen": "inf", "arquebusiers": "inf", "musketeers": "inf",
        "knights": "cav", "lancers": "cav", "cuirassiers": "cav",
        "bombards": "art", "culverins": "art", "field_guns": "art"}


def _symbol(surf, key, x, y, u, c):
    """A bold glyph centred at (x, y); u is the pixel size of a 20-unit radius disc / 20."""
    kind = _WAR.get(key, key)
    lw = max(2, int(4 * u))
    if kind == "inf":
        pygame.draw.line(surf, c, (x - 9 * u, y + 9 * u), (x + 9 * u, y - 9 * u), lw)
        pygame.draw.line(surf, c, (x + 9 * u, y + 9 * u), (x - 9 * u, y - 9 * u), lw)
        for sx in (-1, 1):
            pygame.draw.polygon(surf, c, [(x + sx * 9 * u - 3 * u, y - 7 * u), (x + sx * 9 * u + 3 * u, y - 7 * u),
                                          (x + sx * 9 * u, y - 13 * u)])
    elif kind == "cav":
        pts = [(-9, 9), (-8, 0), (-3, -6), (-1, -11), (2, -8), (9, -3), (9, 1), (3, 1), (3, 9)]
        pygame.draw.polygon(surf, c, [(x + px * u, y + py * u) for px, py in pts])
    elif kind == "art":
        pygame.draw.circle(surf, c, (x - 4 * u, y + 4 * u), 6 * u, max(2, int(3 * u)))
        pygame.draw.line(surf, c, (x - 4 * u, y + 2 * u), (x + 9 * u, y - 7 * u), max(3, int(6 * u)))
        pygame.draw.circle(surf, c, (x + 9 * u, y - 7 * u), 3.5 * u)
    elif kind == "scout":
        pygame.draw.line(surf, c, (x - 10 * u, y + 6 * u), (x + 6 * u, y - 5 * u), max(3, int(6 * u)))
        pygame.draw.circle(surf, c, (x + 8 * u, y - 7 * u), 4.5 * u)
    elif kind == "general":
        pts = []
        for i in range(10):
            rr = 11 * u if i % 2 == 0 else 4.8 * u
            a = math.radians(-90 + 36 * i)
            pts.append((x + rr * math.cos(a), y + rr * math.sin(a) + 1 * u))
        pygame.draw.polygon(surf, c, pts)
    elif kind == "wagon":
        pygame.draw.rect(surf, c, (x - 10 * u, y - 7 * u, 20 * u, 9 * u), border_radius=int(2 * u))
        pygame.draw.polygon(surf, c, [(x - 8 * u, y - 7 * u), (x - 5 * u, y - 12 * u), (x + 6 * u, y - 12 * u), (x + 9 * u, y - 7 * u)])
        for dx in (-5, 5):
            pygame.draw.circle(surf, c, (x + dx * u, y + 5 * u), 4 * u)
    elif kind == "pioneer":
        pygame.draw.line(surf, c, (x - 7 * u, y + 10 * u), (x + 5 * u, y - 7 * u), lw)
        pygame.draw.arc(surf, c, (x - 7 * u, y - 14 * u, 22 * u, 16 * u), 0.2, 2.9, max(3, int(5 * u)))
    elif kind == "colonist":
        pygame.draw.circle(surf, c, (x, y - 6 * u), 4.5 * u)
        pygame.draw.polygon(surf, c, [(x - 8 * u, y + 10 * u), (x - 5 * u, y - 1 * u), (x + 5 * u, y - 1 * u), (x + 8 * u, y + 10 * u)])
    elif kind in ("caravel", "carrack"):
        pygame.draw.polygon(surf, c, [(x - 11 * u, y + 2 * u), (x + 11 * u, y + 2 * u), (x + 6 * u, y + 9 * u), (x - 6 * u, y + 9 * u)])
        pygame.draw.line(surf, c, (x, y + 2 * u), (x, y - 11 * u), max(2, int(2.5 * u)))
        pygame.draw.polygon(surf, c, [(x + 1.5 * u, y - 10 * u), (x + 9 * u, y - 1 * u), (x + 1.5 * u, y)])
        if kind == "carrack":
            pygame.draw.polygon(surf, c, [(x - 1.5 * u, y - 8 * u), (x - 8 * u, y - 1 * u), (x - 1.5 * u, y)])


def token(key, color, size, era=1, faded=False):
    """A board-game counter for far zoom: size wide, about 1.3 x size tall (flag on a pole, ring, parchment, glyph)."""
    k = 2
    w, h = size * k, int(size * 1.3 * k)
    surf = pygame.Surface((w, h), pygame.SRCALPHA)
    r = w * 0.36
    cx, cy = w * 0.45, h - r - w * 0.09
    u = r / 20
    pygame.draw.ellipse(surf, (0, 0, 0, 90), (cx - r * 1.05, cy + r * 0.55, r * 2.1, r * 0.9))
    # flag pole and flag first, so the disc overlaps its foot
    px = cx + r * 0.62
    top = h * 0.03
    pygame.draw.line(surf, (90, 65, 40), (px, cy - r * 0.5), (px, top), max(2, int(2.2 * u)))
    flag = [(px, top), (px + r * 0.95, top + r * 0.30), (px, top + r * 0.62)]
    pygame.draw.polygon(surf, color, flag)
    pygame.draw.polygon(surf, shade(color, -0.3), [(px, top + r * 0.31), (px + r * 0.95, top + r * 0.30), (px, top + r * 0.62)])
    pygame.draw.polygon(surf, GOLD, flag, max(1, int(1.3 * u)))
    # disc: dark rim, country ring, parchment
    pygame.draw.circle(surf, INK, (cx, cy + 3 * u), r + 2 * u)
    pygame.draw.circle(surf, shade(color, -0.35), (cx, cy + 3 * u), r)
    pygame.draw.circle(surf, INK, (cx, cy), r + 2 * u)
    pygame.draw.circle(surf, color, (cx, cy), r)
    pygame.draw.circle(surf, shade(color, 0.3), (cx, cy), r, max(1, int(2 * u)))
    pygame.draw.circle(surf, INK, (cx, cy), r * 0.72 + 1.5 * u)
    pygame.draw.circle(surf, (242, 232, 205), (cx, cy), r * 0.72)
    pygame.draw.circle(surf, (226, 213, 180), (cx, cy + r * 0.3), r * 0.72, max(1, int(2 * u)), draw_bottom_left=True,
                       draw_bottom_right=True)
    gy = cy - (2 * u if key in _WAR else 0)
    _symbol(surf, key, cx, gy, u * 0.95, shade(color, -0.45))
    if key in _WAR:
        n = max(1, min(4, era))
        for i in range(n):
            ex = cx + (i - (n - 1) / 2) * 6.5 * u
            pygame.draw.circle(surf, INK, (ex, cy + r * 0.52), 3.4 * u)
            pygame.draw.circle(surf, GOLD, (ex, cy + r * 0.52), 2.3 * u)
    surf = pygame.transform.smoothscale(surf, (size, int(size * 1.3)))
    return _faded(surf) if faded else surf
