"""A fictional world for the Age of Discovery campaign ("Random world" map option).

`generate(seed)` returns an object that stands in for the real-world data in geo.py. It uses
the same projection (everything is (lon, lat) on geo's frame), so the latitude rules of the
world code keep working: the north is cold, the south tropical, the far west is a New World
across an ocean and the east is an Old World full of countries.

How it is made:
1. A design: random but structured continents (an Old World with a Mediterranean-like inland
   sea, a northern sea and peninsulas; a wide ocean; two or three New World landmasses).
2. Macro layout: wave function collapse on a coarse hex grid (cells of ~4.35 degrees) with
   deep / sea / coast / land / high tiles, priors from the design and adjacency rules.
3. Fine mask: the macro tiles and the design are blended onto every hex, plus smooth value
   noise for natural coastlines, then cleaned up (stray islets dropped, holes filled, a few
   lakes kept, the Old World joined into one landmass and every sea joined to the ocean).
4. Features: mountain ranges through the high cells, hills, rivers flowing down the
   distance-to-sea field, deserts and steppes by latitude band and distance from the coast.
5. People: cities, countries (weighted Voronoi groups of cities), markets, tribes and names.
Everything is deterministic for a given seed.
"""
import heapq
import math
import random
from collections import deque
from types import SimpleNamespace

from . import geo
from .wfc import collapse
from ..hexgrid import neighbors, within

MDEG = 4.35                      # macro cell width in degrees of longitude
MROW = MDEG * 0.8660254          # macro row spacing in Mercator degrees
TILE_VALUE = {"deep": 0.0, "sea": 0.18, "coast": 0.5, "land": 0.82, "high": 0.92}
FORBIDDEN = [("deep", "coast"), ("deep", "land"), ("deep", "high"), ("sea", "land"), ("sea", "high"),
             ("coast", "high")]

PALETTE = [
    (40, 130, 70), (200, 170, 40), (170, 60, 60), (40, 70, 170), (150, 60, 140), (190, 40, 40),
    (70, 90, 160), (60, 160, 90), (200, 70, 80), (40, 90, 200), (160, 110, 60), (80, 80, 110),
    (120, 150, 190), (100, 160, 100), (200, 180, 120), (90, 150, 210), (230, 230, 230), (130, 190, 160),
    (210, 210, 170), (110, 110, 160), (190, 120, 50), (130, 150, 120), (60, 140, 150), (30, 160, 140),
    (190, 60, 110), (140, 50, 160), (240, 230, 160), (100, 170, 200), (160, 200, 120), (210, 90, 100),
    (180, 200, 80), (150, 150, 150), (130, 50, 40), (170, 150, 100), (200, 150, 40), (150, 120, 70),
    (80, 150, 60), (200, 120, 120), (90, 100, 60), (220, 140, 140), (150, 130, 190), (180, 70, 40),
    (90, 90, 90), (220, 200, 90), (120, 80, 150), (70, 120, 100),
]

REAL_NAMES = set("""
france spain portugal england scotland ireland wales italy germany austria hungary poland russia prussia
bohemia bavaria saxony sweden norway denmark finland holland belgium burgundy castile aragon navarre
granada leon galicia venice genoa milan naples sicily sardinia savoy florence tuscany greece serbia bosnia
croatia albania bulgaria romania moldavia wallachia georgia armenia persia iran iraq syria egypt libya
tunisia algeria morocco mali ghana benin niger nigeria chad sudan ethiopia kenya congo angola gabon togo
guinea senegal gambia liberia somalia oman yemen qatar jordan israel lebanon turkey cyprus malta crete
india china japan korea mexico peru chile brazil bolivia cuba haiti jamaica canada panama honduras belize
colombia venezuela ecuador paraguay uruguay argentina guyana suriname latvia lithuania estonia livonia
ukraine belarus crimea hansa pomerania brandenburg hesse lorraine alsace flanders brittany normandy
aquitaine gascony provence catalonia andorra monaco luxembourg liechtenstein switzerland slovakia slovenia
macedonia montenegro kosovo thrace anatolia rus novgorod muscovy kazan astrakhan nubia kush axum sheba
assyria babylon sumer media lydia phrygia dacia illyria gaul iberia hispania britannia scythia sarmatia
thule dalmatia carinthia styria tyrol silesia moravia volhynia podolia ruthenia courland samogitia karelia
lapland iceland greenland zambia malawi rwanda burundi uganda tanzania sparta troy athens rome carthage
numidia mauretania cyrenaica tripolitania arabia hejaz nejd sind aden asia europe africa america oceania
atlantis mordor gondor rohan narnia westeros essos valyria vandalia cilicia lycia caria pontus bithynia
galatia cappadocia mysia ionia aeolia doris achaea epirus thessaly boeotia attica arcadia elis messenia
colchis iberia albion erin cambria cornwall kent wessex mercia anglia sussex essex york
""".split())

ONSETS = ["b", "c", "d", "f", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "z", "br", "dr", "gr",
          "kr", "tr", "st", "th", "sh", "ch", "vl", "sk", "fr", "gl", "pr", "sl", "w", "j", "bl", "kh"]
VOWELS = ["a", "e", "i", "o", "u", "a", "e", "o", "ae", "ia", "io", "ou", "ei", "y", "au", "ea"]
CODAS = ["n", "r", "l", "s", "th", "nd", "rk", "st", "m", "sk", "rn", "lt", "x", "sh", "nt", "rd", "ld"]
COUNTRY_ENDS = ["ia", "a", "or", "en", "and", "ar", "os", "ene", "ium", "eth", "ora", "ica", "ovia", "ant",
                "ania", "aine", "esh", "ir", "onia", "ad", "uria", "ec", "is"]
CITY_ENDS = ["burg", "heim", "ford", "ton", "grad", "ova", "ano", "ille", "ac", "ez", "is", "on", "os", "a",
             "era", "mar", "stad", "polis", "ein", "ik", "um", "by", "wick", "ena", "ari", "o", "esk", "dor"]
RIVER_ENDS = ["a", "e", "is", "ar", "en", "o", "ava", "ine", "ul", "es", "an"]
NATIVE_ONSETS = ["t", "tl", "k", "ch", "m", "n", "p", "q", "w", "y", "x", "h", "c", "s", "z", "tz", "hu", "qu",
                 "ny", "mb", "ng", "b", "d", "l"]
NATIVE_VOWELS = ["a", "o", "i", "u", "e", "a", "o", "aa", "ua"]
NATIVE_CODAS = ["n", "c", "l", "tl", "q", "m", "x", "k", "w"]
NATIVE_ENDS = ["ec", "an", "ca", "oa", "i", "ue", "aq", "o", "uk", "eca", "ani", "oto", "ba", "ngo", "we", "ya"]
NATIVE_CITY_ENDS = ["tlan", "pan", "co", "ca", "ma", "yo", "ixa", "ac", "lo", "mba"]
COLONY_PREFIX = ["New ", "Port ", "Fort ", "Cape ", "San ", "Santa ", "Saint ", "", "", ""]
VOWEL_SET = set("aeiouy")


# ----- small helpers --------------------------------------------------------------------
def _scale():
    return getattr(geo, "SCALE", 1)


def _smooth(a, b, x):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    t = (x - a) / (b - a)
    return t * t * (3 - 2 * t)


def _interp(ctrl, x):
    if x <= ctrl[0][0]:
        return ctrl[0][1]
    for (x0, y0), (x1, y1) in zip(ctrl, ctrl[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return ctrl[-1][1]


def _deg(a, b):
    """Plain distance in degrees between two (lon, lat) points."""
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _pt(pos):
    lon, lat = geo.lonlat(pos)
    return round(lon, 2), round(lat, 2)


class _Noise:
    """Smooth value noise on a lattice in (lon, Mercator y) space, values in -1..1."""

    def __init__(self, rng, step):
        self.step = step
        self.x0, self.y0 = -115.0, -40.0
        self.nx = int(180 / step) + 4
        ny = int(160 / step) + 4
        self.v = [rng.random() * 2 - 1 for _ in range(self.nx * ny)]

    def __call__(self, x, y):
        fx = (x - self.x0) / self.step
        fy = (y - self.y0) / self.step
        ix, iy = int(fx), int(fy)
        tx, ty = fx - ix, fy - iy
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        v, nx = self.v, self.nx
        i = iy * nx + ix
        a = v[i] + (v[i + 1] - v[i]) * tx
        b = v[i + nx] + (v[i + nx + 1] - v[i + nx]) * tx
        return a + (b - a) * ty


class _Stroke:
    """A thick polyline in (lon, Mercator y) space: 1 inside, falling smoothly to 0 at its edge."""

    def __init__(self, points, widths, soft=0.45):
        self.pts = [(lon, geo.merc(lat)) for lon, lat in points]
        self.w = list(widths)
        self.soft = soft
        pad = max(self.w) * (1 + soft)
        xs = [p[0] for p in self.pts]
        ys = [p[1] for p in self.pts]
        self.box = (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)
        self.points = list(points)

    def __call__(self, x, y):
        b = self.box
        if not (b[0] <= x <= b[2] and b[1] <= y <= b[3]):
            return 0.0
        pts, w, soft = self.pts, self.w, self.soft
        best = 0.0
        n = len(pts)
        for i in range(max(1, n - 1)):
            j = min(i + 1, n - 1)
            ax, ay = pts[i]
            dx, dy = pts[j][0] - ax, pts[j][1] - ay
            l2 = dx * dx + dy * dy
            t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / l2))
            d = math.hypot(x - ax - t * dx, y - ay - t * dy)
            hw = w[i] + (w[j] - w[i]) * t
            v = 1 - _smooth(hw * (1 - soft), hw * (1 + soft), d)
            if v > best:
                best = v
        return best


class _Lang:
    """A tiny syllable 'language', so names from one country sound alike."""

    def __init__(self, rng, native=False):
        self.rng = rng
        self.onsets = rng.sample(NATIVE_ONSETS if native else ONSETS, 10)
        self.vowels = rng.sample(NATIVE_VOWELS if native else VOWELS, 5)
        self.codas = rng.sample(NATIVE_CODAS if native else CODAS, 4)
        self.ends = {
            "country": rng.sample(NATIVE_ENDS if native else COUNTRY_ENDS, 4),
            "city": rng.sample(NATIVE_CITY_ENDS if native else CITY_ENDS, 5),
            "river": rng.sample(NATIVE_ENDS if native else RIVER_ENDS, 4),
            "tribe": rng.sample(NATIVE_ENDS, 5),
        }

    def _syllable(self, first, last):
        rng = self.rng
        s = "" if first and rng.random() < 0.2 else rng.choice(self.onsets)
        s += rng.choice(self.vowels)
        if rng.random() < (0.45 if last else 0.2):
            s += rng.choice(self.codas)
        return s

    def _join(self, a, b):
        if not b:
            return a
        if a[-1] in VOWEL_SET and b[0] in VOWEL_SET:
            a = a[:-1]
        elif a[-1] not in VOWEL_SET and b[0] not in VOWEL_SET:
            a += self.rng.choice(self.vowels)[0]
        return a + b

    def word(self, kind, used):
        rng = self.rng
        for _ in range(80):
            n = rng.choice((1, 2, 2, 2, 3))
            root = "".join(self._syllable(i == 0, i == n - 1) for i in range(n))
            end = rng.choice(self.ends[kind]) if rng.random() < 0.85 else ""
            w = self._join(root, end)
            if not 4 <= len(w) <= 11 or any(w[i] == w[i + 1] == w[i + 2] for i in range(len(w) - 2)):
                continue
            if sum(1 for i in range(len(w) - 2) if not (set(w[i:i + 3]) & VOWEL_SET)):
                continue                                  # three consonants in a row
            w = w.capitalize()
            low = w.lower()
            if low in REAL_NAMES or low[:-1] in REAL_NAMES or w in used:
                continue
            used.add(w)
            return w
        w = f"{rng.choice(self.onsets).capitalize()}{rng.choice(self.vowels)}{len(used)}"
        used.add(w)
        return w


# ----- the design: where the continents and seas go -------------------------------------
def _coast(rng, base, jitter, step=3.5):
    """Control points every `step` degrees of latitude along a base coast, jittered."""
    lo, hi = base[0][0], base[-1][0]
    out, lat = [], lo
    while lat < hi:
        out.append((lat, _interp(base, lat) + rng.uniform(-jitter, jitter)))
        lat += step
    out.append((hi, _interp(base, hi) + rng.uniform(-jitter, jitter)))
    return out


def _design(rng):
    d = SimpleNamespace()
    u = rng.uniform
    # Old World west coast (lon at given latitudes); the south bulges west like Africa.
    bulge = u(-3, 4)
    base = [(-16, 10), (-6, 9), (0, 4), (6, -5), (12, -13), (18, -15), (24, -13), (30, -10), (35, -8),
            (40, -9), (45, -8), (50, -4), (55, -6), (60, -5), (68, -5)]
    base = [(lat, lon + u(-2.5, 2.5) - (bulge if 6 <= lat <= 24 else 0)) for lat, lon in base]
    d.wc = _coast(rng, base, 1.6)
    d.warp = (_Noise(rng, 8.0), _Noise(rng, 8.0))
    d.south = _Noise(rng, 9.0)
    d.south_ow = u(-9, -4)
    d.seas, d.details, d.islands = [], [], []

    # The Mediterranean: a long sea from a narrow western strait into the heart of the Old World.
    lat_m = u(35, 40)
    lon_end = u(24, 33)
    coast = _interp(d.wc, lat_m)
    pts = [(coast - 5, lat_m), (coast + 1.5, lat_m + u(-0.5, 0.5))]
    widths = [2.0, 1.3]
    x = coast + u(6, 8)
    while x < lon_end:
        pts.append((x, lat_m + u(-2.5, 2.5)))
        widths.append(u(3.4, 5.0))
        x += u(6, 8)
    pts.append((lon_end, pts[-1][1] + u(-1.5, 1.5)))
    widths.append(u(2.4, 3.4))
    d.med = pts
    d.seas.append(_Stroke(pts, widths))
    for _ in range(rng.randint(1, 3)):                    # gulfs (an Adriatic, an Aegean...)
        i = rng.randrange(2, len(pts) - 1)
        x0, y0 = pts[i]
        if rng.random() < 0.65:
            end = (x0 + u(-3, 5), y0 + u(6, 10))
        else:
            end = (x0 + u(-3, 3), y0 - u(5, 7))
        d.seas.append(_Stroke([(x0, y0), end], [u(1.7, 2.4), u(0.9, 1.3)]))
    for _ in range(rng.randint(2, 4)):                    # islands in it
        i = rng.randrange(2, len(pts) - 1)
        t = rng.random()
        cx = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t
        cy = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t + u(-1.0, 1.0)
        a = u(0, math.pi)
        ln = u(0, 1.8)
        d.details.append((_Stroke([(cx - ln * math.cos(a), cy - ln * math.sin(a)),
                                   (cx + ln * math.cos(a), cy + ln * math.sin(a))], [u(0.7, 1.3)] * 2), 0.85))
        d.islands.append((cx, cy))
    for k in range(2):                                    # peninsulas reaching south into it
        if rng.random() > (0.95 if k == 0 else 0.6):
            continue
        i = rng.randrange(2, len(pts) - 1)
        px, py = pts[i]
        d.details.append((_Stroke([(px - u(0, 2.5), py + widths[i] + 3.5), (px + u(-1, 3.5), py - widths[i] * 0.25)],
                                  [u(1.4, 2.0), u(0.8, 1.2)]), 0.75))
    # An enclosed eastern sea (like the Black Sea); the clean-up cuts it a strait.
    if rng.random() < 0.7:
        cx, cy = min(lon_end + u(3, 9), 36.0), lat_m + u(6, 10)
        rx, ry = u(3, 4.5), u(2, 3)
        d.seas.append(_Stroke([(cx - rx, cy), (cx + rx, cy + u(-1.5, 1.5))], [ry, ry]))
    # A northern sea entering from the ocean (like the North Sea and the Baltic).
    if rng.random() < 0.85:
        lat_n = u(max(51, lat_m + 10), 56)
        c = _interp(d.wc, lat_n)
        npts = [(c - 4, lat_n), (c + 3, lat_n + u(-1, 1)), (c + u(8, 11), lat_n + u(-0.5, 1.5)),
                (u(13, 22), lat_n + u(0, 3))]
        nw = [3.2, u(2.6, 3.4), u(1.2, 1.6), u(2.8, 3.6)]
        if rng.random() < 0.6:
            npts.append((npts[-1][0] + u(3, 6), npts[-1][1] + u(1, 4)))
            nw.append(u(1.6, 2.4))
        d.seas.append(_Stroke(npts, nw))
        if rng.random() < 0.5:
            x0, y0 = npts[-1]
            d.seas.append(_Stroke([(x0, y0), (x0 + u(-2, 2), y0 + u(5, 8))], [u(1.4, 1.8), 1.0]))
    # Islands off the west coast (a Britain, an Ireland).
    if rng.random() < 0.85:
        lat_b = u(50, 57)
        cmin = min(_interp(d.wc, lat_b + k) for k in range(-6, 7))
        rx = u(2.0, 2.8)
        cx = cmin - rx - u(3.0, 4.5)
        d.details.append((_Stroke([(cx, lat_b - u(3, 4)), (cx + u(-1.5, 1.5), lat_b + u(3, 4.5))], [rx, rx * 0.8]), 0.9))
        d.islands.append((cx, lat_b))
        if rng.random() < 0.6:
            ix, iy = cx - rx - u(3.5, 5), lat_b + u(-1.5, 1.5)
            d.details.append((_Stroke([(ix, iy - 1), (ix, iy + 1)], [u(1.3, 1.8)] * 2), 0.9))
            d.islands.append((ix, iy))
    for _ in range(rng.randint(2, 4)):                    # lonely Atlantic islands
        ix, iy = u(-46, -24), u(14, 42)
        d.details.append((_Stroke([(ix, iy)], [u(0.7, 1.1)]), 0.9))
        d.islands.append((ix, iy))

    # The New World.
    d.continents = []
    lat_lo = u(16, 21)
    west = _coast(rng, [(14, -92), (22, -94.5), (32, -93.5), (45, -93.5), (68, -93.5)], 1.5)
    east = _coast(rng, [(lat, lon + u(-3, 3)) for lat, lon in [(14, -86), (22, -82), (28, -79), (34, -75), (41, -69),
                                                                (47, -61), (53, -58), (60, -62), (68, -66)]], 2.0)
    d.continents.append((lat_lo, 90, west, east))
    lat_hi = u(7, 12)
    west = _coast(rng, [(-16, -77), (-6, -81), (2, -80), (10, -77), (14, -75)], 1.5)
    east = _coast(rng, [(lat, lon + u(-3, 3)) for lat, lon in [(-16, -40), (-8, -37), (-3, -42), (3, -51), (8, -60),
                                                                (12, -68), (14, -72)]], 2.0)
    d.continents.append((-30, lat_hi, west, east))
    d.extra_land, d.nw_cuts = [], []
    isthmus = rng.random() < 0.5
    if isthmus:
        d.extra_land.append(_Stroke([(-91, lat_lo + 1.5), (-84, 12.5), (-79, lat_hi - 1.5)], [1.4, 1.1, 1.4]))
    if rng.random() < 0.85:                               # a gulf in the south of the north continent
        gx, gy = u(-92, -86), u(24, 28)
        d.nw_cuts.append(_Stroke([(gx - 3, gy), (gx + 3, gy + u(-1, 1))], [u(3.5, 4.5)] * 2))
    if rng.random() < 0.6:                                # a big northern bay
        bx, by = u(-88, -78), u(56, 60)
        d.nw_cuts.append(_Stroke([(bx, by), (bx + u(-3, 3), by + 8)], [u(3.5, 4.5), 5]))
    if rng.random() < 0.6:                                # a peninsula pointing south
        e30 = _interp(d.continents[0][3], 30)
        d.extra_land.append(_Stroke([(e30 - 3, 31), (e30 - 1.5, u(24, 26))], [1.5, 1.1]))
    third = rng.random()
    if third < 0.4:                                       # a big cold island
        gx, gy = u(-52, -45), u(57, 60)
        d.extra_land.append(_Stroke([(gx - 3, gy), (gx + 3, gy + u(0, 3))], [u(3.0, 4.0)] * 2))
        d.islands.append((gx, gy))
    elif third < 0.8:                                     # a big tropical island
        cy = u(19, 23)
        d.extra_land.append(_Stroke([(u(-86, -82), cy), (u(-76, -72), cy - u(0, 3))], [u(1.4, 2.0)] * 2))
        d.islands.append((-79, cy))
    if not isthmus or rng.random() < 0.6:                 # an island arc
        a, b = (u(-76, -72), u(17, 19)), (u(-63, -60), u(10, 13))
        for k in range(rng.randint(4, 6)):
            t = (k + u(0.2, 0.8)) / 6
            ix, iy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + u(-0.6, 0.6)
            d.details.append((_Stroke([(ix, iy)], [u(0.6, 1.0)]), 0.9))
            d.islands.append((ix, iy))
    d.wc_min = min(_interp(d.wc, lat) for lat in range(12, 63))
    d.known_w = max(-28.0, d.wc_min - 12)
    return d


def _target(d, lon, lat, y):
    """How much the design wants land here (0..1)."""
    wx, wy = d.warp
    dx, dy = 2.4 * wx(lon, y), 2.0 * wy(lon, y)
    lon, y = lon + dx, y + dy
    lat = geo.inv_merc(max(-80.0, min(80.0, y)))
    ow = _smooth(-2.0, 2.0, lon - _interp(d.wc, lat)) * _smooth(d.south_ow - 2.5, d.south_ow + 2.5, lat)
    if ow > 0:
        s = 0.0
        for f in d.seas:
            v = f(lon, y)
            if v > s:
                s = v
        ow *= 1 - s
    v = ow
    if lon < -25:
        for lo, hi, west, east in d.continents:
            if lo - 2 <= lat <= hi + 2:
                w, e = _interp(west, lat), _interp(east, lat)
                c = (_smooth(w - 1.5, w + 1.5, lon) * (1 - _smooth(e - 1.5, e + 1.5, lon))
                     * _smooth(lo - 1.5, lo + 1.5, lat) * (1 - _smooth(hi - 1.5, hi + 1.5, lat)))
                if c > v:
                    v = c
        for f in d.extra_land:
            c = f(lon, y)
            if c > v:
                v = c
        for f in d.nw_cuts:
            v *= 1 - f(lon, y)
    cut = -9.0 + 4.0 * d.south(lon, 0.0)
    return v * _smooth(cut - 1.7, cut + 1.7, lat) * _smooth(geo.LON0 + 2.0, geo.LON0 + 5.0, lon)


def _detail(d, lon, y):
    return sum(amp * f(lon, y) for f, amp in d.details)


# ----- macro layout by wave function collapse ------------------------------------------------
def _macro(d, rng, noise_hi):
    mc_n = int((geo.LON1 - geo.LON0) / MDEG) + 4
    mr_n = int((geo.Y_TOP - geo.merc(geo.LAT_BOTTOM)) / MROW) + 4

    def centre(cell):
        c, r = cell
        lon = geo.LON0 - MDEG + (c + 0.5 * (r & 1)) * MDEG
        y = geo.Y_TOP + MROW - r * MROW
        return lon, y

    cells = [(c, r) for r in range(mr_n) for c in range(mc_n)]
    prior = {}
    for cell in cells:
        lon, y = centre(cell)
        lat = geo.inv_merc(max(-80.0, min(80.0, y)))
        t = _target(d, lon, lat, y)
        hi = max(0.0, min(1.0, noise_hi(lon, y) * 1.4 + 0.25))
        if lon < -60:                                     # western cordilleras in the New World
            for lo, top, west, east in d.continents:
                if lo <= lat <= top and lon - _interp(west, lat) < (10 if lat > 15 else 6):
                    hi = min(1.0, hi + 0.55)
        ocean = -58 < lon < d.wc_min - 3
        w = {
            "deep": math.exp(-((t - 0.0) / 0.16) ** 2) * (2.0 if ocean else 0.7),
            "sea": math.exp(-((t - 0.2) / 0.16) ** 2) * 0.8,
            "coast": math.exp(-((t - 0.5) / 0.18) ** 2) * 0.7,
            "land": math.exp(-((t - 0.95) / 0.3) ** 2) * (1 - 0.7 * hi),
            "high": math.exp(-((t - 0.95) / 0.3) ** 2) * 0.45 * hi * hi,
        }
        top = max(w.values())
        prior[cell] = {k: v for k, v in w.items() if v >= 0.04 * top}
    fixed = {}
    for (x0, y0), (x1, y1) in zip(d.med[1:], d.med[2:]):  # the Mediterranean must be sea
        steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / 2))
        for k in range(steps + 1):
            lon, lat = x0 + (x1 - x0) * k / steps, y0 + (y1 - y0) * k / steps
            y = geo.merc(lat)
            r = int(round((geo.Y_TOP + MROW - y) / MROW))
            c = int(round((lon - geo.LON0 + MDEG) / MDEG - 0.5 * (r & 1)))
            fixed[(c, r)] = "sea"
    tiles = collapse(cells, prior, FORBIDDEN, neighbors, rng, affinity=1.5, fixed=fixed)
    return tiles, centre, mc_n, mr_n


# ----- the fine land mask --------------------------------------------------------------------
def _components(cells, nb):
    comp, out = {}, []
    for p in sorted(cells):
        if p in comp:
            continue
        group = [p]
        comp[p] = len(out)
        queue = deque([p])
        while queue:
            cur = queue.popleft()
            for n in nb[cur]:
                if n in cells and n not in comp:
                    comp[n] = len(out)
                    group.append(n)
                    queue.append(n)
        out.append(group)
    return out, comp


def _path(start, passable, target, nb, cost):
    """Cheapest path from any start cell through passable cells to a target cell.
    Returns (cells strictly between, in order from the start side; the target cell reached)."""
    dist = {p: 0.0 for p in start}
    prev = {}
    heap = [(0.0, p) for p in sorted(start)]
    heapq.heapify(heap)
    while heap:
        dd, p = heapq.heappop(heap)
        if dd > dist[p]:
            continue
        if p in target:
            hit, out = p, []
            p = prev.get(p)
            while p is not None and p not in start:
                out.append(p)
                p = prev.get(p)
            return out[::-1], hit
        for n in nb[p]:
            if n in start or (n not in passable and n not in target):
                continue
            nd = dd + cost(n)
            if nd < dist.get(n, 1e18):
                dist[n] = nd
                prev[n] = p
                heapq.heappush(heap, (nd, n))
    return None, None


def _grid(cols, rows):
    nb = {}
    for r in range(rows):
        for c in range(cols):
            nb[(c, r)] = [n for n in neighbors((c, r)) if 0 <= n[0] < cols and 0 <= n[1] < rows]
    return nb


def _mask(spec, cols, rows):
    """(land, lakes, highness, ok) for a cols x rows grid."""
    d, tiles, centre = spec.design, spec.tiles, spec.centre
    s = _scale()
    rng = random.Random(f"{spec.seed}:mask:{cols}x{rows}")
    n1, n2, n3 = spec.noise
    sigma2 = 2 * (0.5 * MDEG) ** 2
    land, high = set(), {}
    lonlats = {}
    y_top = geo.Y_TOP + MROW
    for r in range(rows):
        lat = geo.lonlat((0, r))[1]
        y = geo.merc(lat)
        fr = (y_top - y) / MROW
        r0 = int(math.floor(fr))
        mrows = [mr for mr in (r0 - 1, r0, r0 + 1, r0 + 2)]
        for c in range(cols):
            lon = geo.lonlat((c, r))[0]
            lonlats[(c, r)] = (lon, lat)
            tw = tv = th = 0.0
            for mr in mrows:
                fc = (lon - geo.LON0 + MDEG) / MDEG - 0.5 * (mr & 1)
                c0 = int(math.floor(fc))
                for mc in (c0, c0 + 1, c0 + 2, c0 - 1):
                    t = tiles.get((mc, mr))
                    if t is None:
                        continue
                    mx, my = centre((mc, mr))
                    dd = (lon - mx) ** 2 + (y - my) ** 2
                    if dd > 2.6 * MDEG * MDEG:
                        continue
                    k = math.exp(-dd / sigma2)
                    tw += k
                    tv += k * TILE_VALUE[t]
                    if t == "high":
                        th += k
            m = tv / tw if tw else 0.0
            value = (0.6 * m + 0.4 * _target(d, lon, lat, y) + _detail(d, lon, y)
                     + 0.15 * n1(lon, y) + 0.10 * n2(lon, y) + 0.06 * n3(lon, y))
            if value > 0.5:
                land.add((c, r))
            high[(c, r)] = th / tw if tw else 0.0

    nb = _grid(cols, rows)
    cells = set(nb)
    island_hexes = set()
    for lon, lat in d.islands:
        p = geo.hex_of(lon, lat)
        for q in within(p, max(2, 2 * s)):
            island_hexes.add(q)

    def known(p):
        lon, lat = lonlats[p]
        return lon > d.known_w and lat > 11.5

    # Stray islets go, unless the design put an island there.
    comps, _ = _components(land, nb)
    for group in comps:
        if len(group) <= 2 * s and not any(p in island_hexes for p in group):
            land.difference_update(group)

    ok = True
    for _ in range(5):
        changed = False
        comps, comp = _components(land, nb)
        old = [g for g in comps if len(g) >= 25 * s * s and sum(1 for p in g if known(p)) * 2 > len(g)
               and not any(p in island_hexes for p in g)]
        old.sort(key=len, reverse=True)
        if len(old) > 1:
            main = set(old[0])
            for group in old[1:]:
                water = cells - land
                bridge, _ = _path(set(group), water, main, nb,
                               lambda p: 1.0 + (2.5 if lonlats[p][0] < 20 else 0.0))
                if bridge:
                    land.update(bridge)
                    main.update(group)
                    main.update(bridge)
                    changed = True
        water = cells - land
        wcomps, _ = _components(water, nb)
        wcomps.sort(key=len, reverse=True)
        ocean = set(wcomps[0]) if wcomps else set()
        for group in wcomps[1:]:
            if len(group) <= 3 * s * s:
                continue
            channel, _ = _path(set(group), land, ocean, nb, lambda p: 1.0)
            if channel:
                land.difference_update(channel)
                ocean.update(group)
                ocean.update(channel)
                changed = True
        if not changed:
            break
    else:
        ok = False

    # Small enclosed waters: a few stay lakes, the rest become land.
    water = cells - land
    wcomps, _ = _components(water, nb)
    wcomps.sort(key=len, reverse=True)
    lakes = set()
    small = [g for g in wcomps[1:]]
    rng.shuffle(small)
    for group in small:
        border = any(p[0] in (0, cols - 1) or p[1] in (0, rows - 1) for p in group)
        if len(lakes) < 4 and len(group) <= 3 * s * s and not border:
            lakes.update(group)
        else:
            land.update(group)
    lake_count = len(_components(lakes, nb)[0]) if lakes else 0
    if lake_count < 2:
        dist = _distance_field(land, cells - land, nb)
        spots = sorted(p for p in land if dist.get(p, 0) >= 4 * s)
        rng.shuffle(spots)
        made = []
        for p in spots:
            if lake_count >= 2 + (1 if rng.random() < 0.5 else 0):
                break
            if any(_deg(lonlats[p], lonlats[q]) < 15 for q in made):
                continue
            lake = {p}
            if s > 1:
                lake.update(rng.sample(nb[p], 2))
            lakes.update(lake)
            land.difference_update(lake)
            made.append(p)
            lake_count += 1
    land -= lakes
    return land, lakes, high, ok, nb, lonlats


def _distance_field(land, sources, nb):
    """Steps from the nearest source cell, for land cells."""
    dist = {}
    queue = deque()
    for p in sources:
        for n in nb[p]:
            if n in land and n not in dist:
                dist[n] = 1
                queue.append(n)
    while queue:
        p = queue.popleft()
        for n in nb[p]:
            if n in land and n not in dist:
                dist[n] = dist[p] + 1
                queue.append(n)
    return dist


# ----- features ------------------------------------------------------------------------------
def _on_land_pieces(line, land, min_points=2):
    """Split a polyline where it leaves the land; return the pieces on land."""
    pieces, cur = [], []
    line = [(round(p[0], 2), round(p[1], 2)) for p in line]
    for i, p in enumerate(line):
        ok = geo.hex_of(*p) in land
        if ok and cur and i > 0:
            mid = ((p[0] + line[i - 1][0]) / 2, (p[1] + line[i - 1][1]) / 2)
            ok = geo.hex_of(*mid) in land
            if not ok:
                if len(cur) >= min_points:
                    pieces.append(cur)
                cur = []
                ok = True
        if ok:
            cur.append(p)
        else:
            if len(cur) >= min_points:
                pieces.append(cur)
            cur = []
    if len(cur) >= min_points:
        pieces.append(cur)
    return pieces


def _mountains(tiles, centre, land, rng):
    high = {p for p, t in tiles.items() if t == "high"}
    lines = []
    seen = set()

    def ll(cell):
        lon, y = centre(cell)
        return lon, geo.inv_merc(y)

    def jitter_path(pts):
        out = []
        for i, p in enumerate(pts):
            out.append((p[0] + rng.uniform(-0.6, 0.6), p[1] + rng.uniform(-0.5, 0.5)))
            if i + 1 < len(pts):
                q = pts[i + 1]
                dx, dy = q[0] - p[0], q[1] - p[1]
                ln = math.hypot(dx, dy) or 1
                o = rng.uniform(-0.9, 0.9)
                out.append(((p[0] + q[0]) / 2 - dy / ln * o, (p[1] + q[1]) / 2 + dx / ln * o))
        if len(out) >= 2:                                 # reach a little past the end cells
            for a, b, idx in ((out[1], out[0], 0), (out[-2], out[-1], len(out))):
                dx, dy = b[0] - a[0], b[1] - a[1]
                ln = math.hypot(dx, dy) or 1
                e = (b[0] + dx / ln * 1.2, b[1] + dy / ln * 1.2)
                out.insert(idx, e)
        return out

    for start in sorted(high):
        if start in seen:
            continue
        cluster = [start]
        seen.add(start)
        queue = deque([start])
        while queue:
            cur = queue.popleft()
            for n in neighbors(cur):
                if n in high and n not in seen:
                    seen.add(n)
                    cluster.append(n)
                    queue.append(n)
        if len(cluster) == 1:
            lon, lat = ll(cluster[0])
            a = rng.uniform(0, math.pi)
            h = rng.uniform(1.8, 3.0)
            raw = [(lon - h * math.cos(a), lat - h * math.sin(a)), (lon, lat), (lon + h * math.cos(a), lat + h * math.sin(a))]
            lines.extend(_on_land_pieces(jitter_path(raw)[1:-1], land))
            continue
        # A random spanning tree of the cluster, cut into paths between its forks and ends.
        cset = set(cluster)
        edges = sorted((rng.random(), a, b) for a in cluster for b in neighbors(a) if b in cset and a < b)
        parent = {c: c for c in cluster}

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x
        adj = {c: [] for c in cluster}
        for _, a, b in edges:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb
                adj[a].append(b)
                adj[b].append(a)
        nodes = [c for c in cluster if len(adj[c]) != 2] or cluster[:1]
        used = set()
        for n0 in sorted(nodes):
            for n1 in adj[n0]:
                if (n0, n1) in used:
                    continue
                path = [n0, n1]
                used.add((n0, n1))
                used.add((n1, n0))
                while len(adj[path[-1]]) == 2:
                    nxt = [x for x in adj[path[-1]] if x != path[-2]][0]
                    used.add((path[-1], nxt))
                    used.add((nxt, path[-1]))
                    path.append(nxt)
                    if nxt == n0:
                        break
                lines.extend(_on_land_pieces(jitter_path([ll(c) for c in path]), land))
    return lines


def _mountain_heights(mountains):
    """The height (0.5 to 1.0) of each ridge line: the longest range is the highest, short spurs are low."""
    lengths = [sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(line, line[1:])) for line in mountains]
    top = max(lengths, default=0) or 1
    return [round(0.5 + 0.5 * n / top, 2) for n in lengths]


def _hills(mountains, land, dcoast, lonlats, rng):
    s = _scale()
    hills = []
    for line in mountains:
        if rng.random() < 0.5 or len(line) < 3:
            continue
        side = rng.choice((-1, 1))
        a, b = line[0], line[-1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        off = rng.uniform(2.0, 2.6)
        mid = line[len(line) // 4: len(line) - len(line) // 4 + 1]
        shifted = [(p[0] - dy / ln * off * side, p[1] + dx / ln * off * side) for p in mid]
        hills.extend(_on_land_pieces(shifted, land))
    spots = sorted(p for p in land if dcoast.get(p, 0) >= 2 * s)
    for _ in range(rng.randint(6, 10)):
        if not spots:
            break
        lon, lat = lonlats[rng.choice(spots)]
        a = rng.uniform(0, 2 * math.pi)
        pts = [(lon, lat)]
        for _ in range(rng.randint(2, 4)):
            a += rng.uniform(-0.5, 0.5)
            lon, lat = lon + 2.4 * math.cos(a), lat + 2.0 * math.sin(a)
            pts.append((lon, lat))
        hills.extend(_on_land_pieces(pts, land))
    return hills


MAX_PASSES = 8            # about as many as the Europe map has


def _passes(mountains, land, nb, rng):
    """Mountain passes: one on each of the MAX_PASSES longest ridges (a second one on a long ridge), on a
    ridge hex with lowland on both sides (two lowland neighbours that are not next to each other), at least
    5 hexes apart. Returns hex positions."""
    ridge = _raster_lines(mountains, 0.0) & land
    lines = sorted(((len(_raster_lines([line], 0.0) & land), i) for i, line in enumerate(mountains)), reverse=True)
    out = []
    for length, i in lines:
        if len(out) >= MAX_PASSES:
            break
        cands = []
        for p in sorted(_raster_lines([mountains[i]], 0.0) & land):
            low = [n for n in nb[p] if n in land and n not in ridge]
            if any(b not in nb[a] for i, a in enumerate(low) for b in low[i + 1:]):
                cands.append(p)
        if not cands:
            continue
        want = min(2 if length >= 20 else 1, MAX_PASSES - len(out))
        picked = []
        for p in rng.sample(cands, len(cands)):
            if len(picked) >= want:
                break
            if all(q not in within(p, 4) for q in picked + out):
                picked.append(p)
        out.extend(picked)
    return out


def _raster_lines(lines, radius_deg):
    """Hexes within about radius_deg of any of the polylines."""
    out = set()
    step = geo.COL_DEG * 0.5
    reach = max(0, int(round(radius_deg / geo.COL_DEG)))
    for line in lines:
        for a, b in zip(line, line[1:]):
            n = max(1, int(_deg(a, b) / step))
            for k in range(n + 1):
                p = geo.hex_of(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
                out.update(within(p, reach) if reach else (p,))
    return out


# ----- the generator -------------------------------------------------------------------------
def generate(seed):
    best = None
    for attempt in range(5):
        world = _attempt(seed, attempt)
        if world._ok:
            return world
        if best is None:
            best = world
    return best


def _attempt(seed, attempt):
    s = _scale()
    rng = random.Random(f"hexa-random-world:{seed}:{attempt}")
    spec = SimpleNamespace(seed=f"{seed}:{attempt}")
    spec.design = d = _design(rng)
    noise_hi = _Noise(rng, 9.0)
    spec.noise = (_Noise(rng, 6.5), _Noise(rng, 3.0), _Noise(rng, 1.4))
    spec.tiles, spec.centre, _, _ = _macro(d, rng, noise_hi)
    cols, rows = geo.COLS, geo.ROWS
    land, lakes, highness, ok, nb, lonlats = _mask(spec, cols, rows)
    cells = set(nb)
    water = cells - land
    ocean = water - lakes
    dcoast = _distance_field(land, water, nb)
    docean = _distance_field(land, ocean, nb)

    def known(lon, lat):
        return lon > d.known_w and lat > 11.5

    # Relief.
    mountains = _mountains(spec.tiles, spec.centre, land, rng)
    hills = _hills(mountains, land, dcoast, lonlats, rng)
    mount_hex = _raster_lines(mountains, 0.8) & land
    prng = random.Random(f"hexa-random-passes:{seed}:{attempt}")
    pass_hexes = _passes(mountains, land, nb, prng)
    pass_lang = _Lang(prng)
    pass_names = set()
    passes = [(pass_lang.word("city", pass_names), *_pt(p)) for p in pass_hexes]

    # Climate bands.
    band = _Noise(rng, 4.5)

    def desert_at(point):
        lon, lat = point
        p = geo.hex_of(lon, lat)
        dc = dcoast.get(p)
        if dc is None:
            return False
        y = geo.merc(lat)
        n = band(lon, y)
        if lon < -30:
            return 21 + 2 * n <= lat <= 31 + 2 * n and dc >= 3 * s
        return 16 + 3 * n <= lat <= 30 + 3 * band(lon + 50, y) and dc >= 2 * s

    def steppe_at(point):
        lon, lat = point
        p = geo.hex_of(lon, lat)
        dc = dcoast.get(p)
        if dc is None or not (lon > 5 or lon < -60):
            return False
        y = geo.merc(lat)
        return 43 + 2 * band(lon, y + 40) <= lat <= 52 + 2 * band(lon + 30, y) and dc >= 5 * s

    desert_hex = {p for p in land if desert_at(lonlats[p])}

    # Rivers: a drainage network by priority flood from the sea over a noisy elevation (inland and
    # high ground is higher), so every land hex drains to the ocean. Rivers are the main stems of
    # the largest basins, traced from the mouth upstream along the biggest tributary.
    meander = _Noise(rng, 3.5)
    elev = {p: 0.25 * docean[p] / s + 1.6 * (meander(lonlats[p][0], geo.merc(lonlats[p][1])) + 1)
            + 4.0 * highness.get(p, 0.0) for p in docean}
    down, order = {}, []
    heap = []
    for p in sorted(docean):
        sea = [n for n in nb[p] if n in ocean]
        if sea:
            down[p] = min(sea)
            heap.append((elev[p], p))
    heapq.heapify(heap)
    filled = {p: e for e, p in heap}
    while heap:
        e, p = heapq.heappop(heap)
        order.append(p)
        for n in nb[p]:
            if n in elev and n not in down:
                down[n] = p
                filled[n] = max(elev[n], e + 0.01)
                heapq.heappush(heap, (filled[n], n))
    acc = {p: 1 for p in order}
    ups = {}
    for p in reversed(order):
        q = down[p]
        if q in acc:
            acc[q] += acc[p]
            ups.setdefault(q, []).append(p)
    rivers, river_hex, zone = [], set(), set()
    lang_used = set()
    min_len = max(7, 5 * s)

    def add_river(path, mouth, name_lang):
        pts = [_pt(p) for i, p in enumerate(path) if i % s == 0 or i == len(path) - 1]
        pts.append(_pt(mouth))
        rivers.append((name_lang.word("river", lang_used), pts))
        river_hex.update(path)
        for p in path:
            zone.update(within(p, s))
        return pts

    old_lang = _Lang(rng)
    new_lang = _Lang(rng, native=True)
    fertile = []
    # A great river through the desert (like the Nile), if the dry band has room for one.
    src = [p for p in land if 4 <= lonlats[p][1] <= 13 and d.known_w + 6 < lonlats[p][0] < 42
           and dcoast.get(p, 0) >= 3 * s and p not in mount_hex]
    targets = {p for p in land if lonlats[p][1] >= 27 and lonlats[p][0] > d.known_w and any(n in ocean for n in nb[p])}
    if src and targets and len(desert_hex) > 40 * s * s:
        start = max(sorted(src), key=lambda p: docean.get(p, 0) + rng.random() * 3 * s)
        mid, end = _path({start}, land - mount_hex, targets, nb,
                         lambda p: 1.0 + 0.8 * (meander(lonlats[p][0], geo.merc(lonlats[p][1])) + 1)
                         + (0.0 if p in desert_hex else 0.6))
        if end is not None:
            nile = [start] + mid + [end]
            sea = [n for n in nb[end] if n in ocean]
            if sea and len(nile) >= 8 * s and sum(1 for p in nile if p in desert_hex) >= 0.35 * len(nile):
                fertile.append(add_river(nile, min(sea), old_lang))
    quota = {"old": rng.randint(9, 13), "new": rng.randint(5, 7)}
    count = {"old": len(rivers), "new": 0}
    mouths = sorted((p for p in order if down[p] in ocean), key=lambda p: (-acc[p], p))
    stop = max(2, s * s)
    for m in mouths:
        if all(count[k] >= quota[k] for k in quota):
            break
        region = "old" if lonlats[m][0] > d.known_w - 2 else "new"
        if count[region] >= quota[region] or acc[m] < min_len * 2:
            continue
        stem = [m]
        while True:
            up = [u for u in ups.get(stem[-1], ()) if acc[u] >= stop]
            if not up:
                break
            stem.append(max(up, key=lambda u: (acc[u], u)))
        path = stem[::-1]
        if len(path) < min_len or any(q in zone for q in path):
            continue
        add_river(path, down[m], old_lang if region == "old" else new_lang)
        count[region] += 1

    # Marshes: river deltas and a few low northern coasts.
    marshes = [(pts[-2][0], pts[-2][1], 1.2, 0.45) for _, pts in rivers]
    coastal_north = sorted(p for p in land if dcoast.get(p) == 1 and 45 < lonlats[p][1] < 58
                           and known(*lonlats[p]))
    for _ in range(rng.randint(2, 4)):
        if coastal_north:
            lon, lat = lonlats[rng.choice(coastal_north)]
            marshes.append((lon, lat, rng.uniform(1.5, 2.5), rng.uniform(0.3, 0.45)))

    def marsh_at(point):
        lon, lat = point
        best = 0.0
        for x, y, r, k in marshes:
            if abs(lon - x) <= r and abs(lat - y) <= r and _deg(point, (x, y)) <= r:
                best = max(best, k)
        return best

    # ----- cities ----------------------------------------------------------------------
    coastal = {p for p in land if any(n in ocean for n in nb[p])}
    by_river = {p for p in land if p in river_hex or any(n in river_hex for n in nb[p])}
    names = set()
    cand = []
    for p in sorted(land):
        lon, lat = lonlats[p]
        if not known(lon, lat) or p in mount_hex:
            continue
        if p in desert_hex and p not in coastal and p not in by_river:
            continue
        score = (rng.random() + 0.8 * (p in coastal) + 0.8 * (p in by_river) + 0.3 * (30 < lat < 50)
                 - 0.35 * (lat > 57) - 0.3 * (lat > 60) - 0.4 * (p in desert_hex))
        cand.append((-score, p))
    cand.sort()
    target_n = rng.randint(92, 108)
    chosen = []
    for spacing in (3.0, 2.7, 2.4):
        bucket = {}
        for q in chosen:
            ll = lonlats[q]
            bucket.setdefault((int(ll[0] // 3), int(ll[1] // 3)), []).append(ll)
        for _, p in cand:
            if len(chosen) >= target_n:
                break
            ll = lonlats[p]
            bx, by = int(ll[0] // 3), int(ll[1] // 3)
            if any(_deg(ll, o) < spacing for i in (-1, 0, 1) for j in (-1, 0, 1) for o in bucket.get((bx + i, by + j), ())):
                continue
            chosen.append(p)
            bucket.setdefault((bx, by), []).append(ll)
        if len(chosen) >= 90:
            break
    size = {}
    for p in chosen:
        v = 4 + int(46 * rng.random() ** 2.6)
        if p in coastal:
            v += rng.randint(4, 14)
        if p in by_river:
            v += rng.randint(3, 12)
        size[p] = min(150, v)

    # ----- countries -------------------------------------------------------------------
    comps, comp = _components(land, nb)
    n_countries = rng.randint(31, 38)
    order = sorted(chosen, key=lambda p: -(size[p] + rng.random() * 30))
    capitals = []
    gap = 7.5
    while len(capitals) < n_countries and gap > 2:
        for p in order:
            if len(capitals) >= n_countries:
                break
            if p not in capitals and all(_deg(lonlats[p], lonlats[q]) >= gap for q in capitals):
                capitals.append(p)
        gap -= 0.5
    # Every sizeable island gets a kingdom of its own.
    for group in comps:
        gset = set(group)
        here = [p for p in chosen if p in gset]
        if len(here) >= 2 and not any(p in gset for p in capitals) and len(capitals) < 40:
            capitals.append(max(here, key=lambda p: size[p]))
    weight = {}
    inland = sorted(capitals, key=lambda p: -(lonlats[p][0] * 0.05 + dcoast.get(p, 0) * 0.15 / s + rng.random()))
    n_emp = rng.randint(4, 6)
    for i, p in enumerate(inland):
        weight[p] = rng.uniform(2.0, 2.7) if i < n_emp else 1.0
    for p in rng.sample(inland[n_emp:], min(6, len(inland) - n_emp)):
        weight[p] = rng.uniform(1.3, 1.6)
    members = {p: [] for p in capitals}
    for p in chosen:
        if p in members:
            members[p].append(p)
            continue
        best = min(capitals, key=lambda q: (_deg(lonlats[p], lonlats[q]) + (6 if comp[p] != comp[q] else 0)) / weight[q])
        members[best].append(p)
    for p in capitals:
        if weight[p] >= 2:
            size[p] = max(size[p], rng.randint(90, 150))
        elif weight[p] > 1:
            size[p] = max(size[p], rng.randint(35, 80))
        else:
            size[p] = max(size[p], rng.randint(12, 40))

    country_used = set()
    tags_used = set()
    langs, info = {}, []
    for cap in capitals:
        lang = _Lang(rng)
        name = lang.word("country", country_used)
        tag = _tag(name, tags_used)
        langs[cap] = lang
        city_list = members[cap]
        k = 5 if weight[cap] >= 2 else 3 if weight[cap] > 1 else 2
        seeds = [cap]
        rest = [p for p in city_list if p != cap]
        while rest and len(seeds) < k:
            far = max(rest, key=lambda p: min(_deg(lonlats[p], lonlats[q]) for q in seeds))
            seeds.append(far)
            rest.remove(far)
        info.append((tag, name, cap, seeds, city_list))
    city_names = {}
    for tag, name, cap, seeds, city_list in info:
        for p in sorted(city_list, key=lambda p: -size[p]):
            city_names[p] = langs[cap].word("city", names)
    # Colours: each country takes the unused colour that differs most from its neighbours'.
    colours = {}
    palette = list(PALETTE)
    for tag, name, cap, seeds, city_list in sorted(info, key=lambda x: -len(x[4])):
        near = [colours[t] for t, _, c2, _, _ in info if t in colours and _deg(lonlats[cap], lonlats[c2]) < 14]
        free = [c for c in palette if c not in colours.values()] or palette

        def score(c):
            return min([sum((a - b) ** 2 for a, b in zip(c, o)) for o in near] or [1e9]) + rng.random()
        colours[tag] = max(free, key=score)
    countries = {}
    for tag, name, cap, seeds, city_list in info:
        countries[tag] = (name, colours[tag], [_pt(p) for p in seeds])

    cities = [(city_names[p], *_pt(p), size[p]) for p in sorted(chosen, key=lambda p: lonlats[p])]

    # Native cities in the New World and the tropical south.
    native_lang = new_lang
    nat_spots = sorted(p for p in land if not known(*lonlats[p]) and p not in mount_hex and p not in desert_hex
                       and (lonlats[p][0] < -50 or lonlats[p][1] < 12))
    rng.shuffle(nat_spots)
    natives = []
    n_native = rng.choice((3, 4))
    for p in nat_spots:
        if len(natives) >= n_native:
            break
        if all(_deg(lonlats[p], lonlats[q]) >= 14 for q in natives):
            natives.append(p)
    for i, p in enumerate(natives):
        lang = _Lang(rng, native=True) if lonlats[p][0] > -40 else native_lang
        cities.append((lang.word("city", names), *_pt(p), 150 if i == 0 else rng.randint(20, 90)))

    # ----- markets -----------------------------------------------------------------------
    markets = []
    picked = []
    for p in sorted(chosen, key=lambda p: (-size[p], p)):
        if len(picked) >= rng.randint(19, 22):
            break
        if all(_deg(lonlats[p], lonlats[q]) >= 7 for q in picked):
            picked.append(p)
    for p in picked:
        markets.append((city_names[p], *_pt(p), False))
    shores = sorted(p for p in coastal if not known(*lonlats[p]) and (lonlats[p][0] < -50 or lonlats[p][1] < 12))
    rng.shuffle(shores)
    want = rng.randint(10, 14)
    col = []
    for spacing in (9, 7, 5, 3):
        for p in shores:
            if len(col) >= want:
                break
            if all(_deg(lonlats[p], lonlats[q]) >= spacing for q in col):
                col.append(p)
        if len(col) >= want:
            break
    colonial_langs = [langs[cap] for _, _, cap, _, _ in info]
    for p in col:
        word = rng.choice(colonial_langs).word("city", names)
        name = rng.choice(COLONY_PREFIX) + word
        names.add(name)
        markets.append((name, *_pt(p), True))

    # ----- tribes ------------------------------------------------------------------------
    tribal = sorted(p for p in land if not known(*lonlats[p]))
    rng.shuffle(tribal)
    tribes = []
    tribe_used = set()
    for spacing in (7.0, 6.0, 5.0, 4.0, 3.0):
        for p in tribal:
            if len(tribes) >= 46:
                break
            if all(_deg(lonlats[p], (t[1], t[2])) >= spacing for t in tribes):
                lang = native_lang if lonlats[p][0] < -40 else old_lang if rng.random() < 0.3 else _Lang(rng, True)
                tribes.append((lang.word("tribe", tribe_used), *_pt(p)))
        if len(tribes) >= 30:
            break
    # Nomads of the Old World's deserts and far north, for land no country holds.
    wild = sorted(p for p in land if known(*lonlats[p]) and (p in desert_hex or lonlats[p][1] > 59))
    rng.shuffle(wild)
    nomads = []
    for p in wild:
        if len(nomads) >= 4:
            break
        if all(_deg(lonlats[p], lonlats[q]) >= 12 for q in nomads):
            nomads.append(p)
            tribes.append((old_lang.word("tribe", tribe_used), *_pt(p)))

    # ----- colonial powers -----------------------------------------------------------------
    coastal_west = []
    for tag, name, cap, seeds, city_list in info:
        shore = [lonlats[p][0] for p in city_list if p in coastal]
        if shore:
            coastal_west.append((min(shore), tag))
    coastal_west.sort()
    colonial = {}
    for i, (_, tag) in enumerate(coastal_west[:8]):
        colonial[tag] = 0 if i < 2 else 30 if i < 5 else 60

    old_cities = [lonlats[p] for p in chosen]
    cx = sum(p[0] for p in old_cities) / max(1, len(old_cities))
    cy = sum(p[1] for p in old_cities) / max(1, len(old_cities))
    start = min(old_cities, key=lambda p: _deg(p, (cx, cy))) if old_cities else (10.0, 45.0)

    masks = {(cols, rows): (frozenset(land), frozenset(lakes))}

    def land_cells(c, r):
        if (c, r) not in masks:
            got = _mask(spec, c, r)
            masks[(c, r)] = (frozenset(got[0]), frozenset(got[1]))
        lnd, lks = masks[(c, r)]
        return set(lnd), set(lks)

    known_w = d.known_w

    def region_at(lon, lat):
        if lon > d.known_w and lat > 11.5:
            return "old"
        return "new" if lon < round(start[0], 2) - 30 else "colonial"

    world = SimpleNamespace(
        name=f"Random world #{seed}", seed=seed,
        START=(round(start[0], 2), round(start[1], 2)),
        land_cells=land_cells, FORCE_LAND=[],
        CITIES=cities, COUNTRIES=countries, MARKETS=markets, TRIBES=tribes, RIVERS=rivers,
        MOUNTAINS=mountains, MOUNTAIN_HEIGHT=_mountain_heights(mountains), HILLS=hills, FERTILE_RIVERS=fertile, PASSES=passes,
        desert_at=desert_at, steppe_at=steppe_at, marsh_at=marsh_at,
        KNOWN_WORLD=lambda lon, lat: lon > known_w and lat > 11.5,
        REGION=region_at, COLONISABLE=lambda lon, lat: region_at(lon, lat) != "old",
        TROPICAL=lambda lon, lat: lat < 17 and region_at(lon, lat) != "new",
        COASTAL_KNOWLEDGE={}, COLONIAL=colonial,
        # the projection stays geo's; these forward to it so the object can stand in for the module
        lonlat=lambda pos: geo.lonlat(pos), hex_of=lambda lon, lat: geo.hex_of(lon, lat),
        line_distance=lambda p, line: geo.line_distance(p, line),
    )
    counts_ok = (len(chosen) >= 85 and 28 <= len(countries) <= 40 and count["old"] >= 7 and count["new"] >= 4
                 and len(tribes) >= 28)
    world._ok = ok and counts_ok and _old_world_joined(land, nb, lonlats, known_w, spec.design)
    return world


def _old_world_joined(land, nb, lonlats, known_w, d):
    comps, _ = _components(land, nb)
    known = [len([p for p in g if lonlats[p][0] > known_w and lonlats[p][1] > 11.5]) for g in comps]
    total = sum(known)
    return bool(total) and max(known) >= 0.8 * total


def _tag(name, used):
    letters = [ch for ch in name.upper() if "A" <= ch <= "Z"]
    options = ["".join(letters[:3])]
    options += [letters[0] + a + b for i, a in enumerate(letters[1:], 1) for b in letters[i + 1:]]
    options += [letters[0] + a + b for a in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" for b in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    for t in options:
        if len(t) == 3 and t not in used:
            used.add(t)
            return t
    raise ValueError("out of tags")
