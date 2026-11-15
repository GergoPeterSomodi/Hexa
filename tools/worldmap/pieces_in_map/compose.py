"""Pieces in the map: the style frame (close zoom, hex radius 60) with chosen hexes drawn by normal-map pieces.

A test, not game code. It answers one question: do the pieces of tools/worldmap/pieces (one hex, one level, one
season) sit in the real map, or do they look like stickers?

Round 2 (after the owner's answers of 2026-11-15; see docs/design/map/pieces/GUIDE.md):
  - NO NAME PLATES. The normal map shows no town name plates for now. Towns stay where the guide puts them.
  - THE MAP DRAWS THE WILD LAND. The frame's own trees stay in a piece hex and are thinned only under the piece's
    footprint (kit.take_apart(...)["footprint"]), instead of the whole hex being cleared.
  - THE MAP OWNS THE SHORE. Every piece is told where the map has the sea in its hex (sea=, shore=); a piece
    never draws a sea, and nothing of a piece stands in the water. A port keeps the frame's own quay, moles,
    lighthouse and ships at its own shore: the stand-in for the harbour add-on until harbour.py can draw it.
  - MIRROR AND LAYOUT come from the hex: kit.pick(col, row).

Round 3 (the second review of the pieces): every family is in the map, not only settlements and wheat (GOODS):
vineyards and olives on the hills, grazing and timber in the foothills, mines in the Alps, castles at the passes,
salt on a flat shore, fishing villages, and the PORTS as a town piece plus the harbour add-on.
  - A coast family's piece is left whole at the shore (its jetties, moles and boats lie on the water); a hex with
    less land than the module's NEED takes a lower level, a hex without a shore takes no coast piece.
  - The harbour add-on's canvas is anchored at the shore, not at the hex centre, so the basin may reach into the
    sea hex next door; add-on things inside the town's footprint are left out.
  - Relief rule K: range samples that stand in or in front of a footprint are dropped (the range is cut there).

Round 4 (the owner's answers on ports and winters; GUIDE sections 7 and 10):
  - TWO PORT MODES. A CARVED port (port_mode(): a great port, here Genoa) gets a bay cut into its own hex
    (carve_ports(), with the kit's bay shape kit.carve); the town piece is clipped at the new shore and the harbour
    add-on sits in the bay, inside the port's own hex. A SEASIDE port (Savona, Nice, Chiavari, Pisa's outport)
    keeps the shore as it is: the add-on is anchored at the shore and may reach into the sea hex next door.
  - WINTER BY CLIMATE. Every hex has one of three winters, kit.winter_of(latitude, height, km to the sea): snow
    (the Alps and the high Apennines), frost (the Po plain and the hills) and mild (the Ligurian coast). Each piece
    is drawn for its hex's winter (take_apart(climate=)); the stand-in winter ground, trees, hills, parcels and
    rivers follow the same index point by point, so the snow line follows the mountains.

What the compositor does (the frame and the pieces are used read only; no file of either is changed):
  - A hex that takes a piece loses the frame's own town, field parcels and rounded hills, and the trees that stand
    in the piece's footprint. Ranges, rivers, roads, coasts and the other trees stay.
  - The piece comes from kit.take_apart(): no ground base (the frame paints the ground), the ground detail (fields,
    plots, yards) feathered at the hex border, clipped to the land, and laid on the frame's ground before the
    rivers and roads.
  - The piece's soft shadows go into the frame's one shadow pass.
  - Every standing thing of a piece is put into the frame's own back-to-front list by the y of its foot, so a
    piece's houses and the map's trees and hills cover each other correctly.
  - A town's site moves to the middle of its piece and the roads are led there.
  - Winter: the frame has no winter of its own, so a stand-in is made here (the ground from the pieces' three
    winter palettes, bare broadleaves, snow on conifers and hills where snow lies). It is a stand-in, not a design.

Run (the frame's environment: STYLE_FRAME_LAYERS must name the exported layers file):
    python tools/worldmap/pieces_in_map/compose.py [OUT_DIR] [summer|winter|both]
Writes summer.png, winter.png, plain_crop.png, hills_coast_crop.png, winter_crop.png and prints the measurements. (base_kept_crop.png in the docs folder is
from round 1 and is no longer written.)
"""
import contextlib
import os
os.environ.setdefault("STYLE_FRAME_SLOPES", "0")     # as the checked-in style_frame_close.png was drawn
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "style_frame"))
sys.path.insert(0, os.path.join(HERE, "..", "pieces"))

import render as R          # the style frame (builds the world at import)
import kit                  # the pieces kit
import castles
import grazing
import harbour
import mines
import olives
import salt
import settlements
import timber
import vineyard
import wheat

pygame = R.pygame
WORLD, FIELDS = R.WORLD, R.FIELDS

# ---------------------------------------------------------------- what goes where
TOWN_LEVEL = {
    "Genoa": 5, "Turin": 5, "Pavia": 5, "Pisa": 4, "Alessandria": 4, "Piacenza": 4, "Asti": 3, "Parma": 3,
    "Savona": 3, "Nice": 3, "Cuneo": 3, "Susa": 2, "Chiavari": 2, "Serravalle": 1,
}
# Wheat on the Po plain: (column, row) -> level. Chosen from the farmland hexes in view (see --probe).
WHEAT = {(7, 9): 2, (8, 9): 3, (10, 9): 3, (11, 9): 1, (12, 9): 2, (6, 10): 2, (13, 10): 3, (12, 12): 2}
# Round 3: the other families, each on its own kind of land: (column, row) -> (module, level, draw keywords).
GOODS = {
    (7, 12): (vineyard, 3, {}), (7, 11): (vineyard, 2, {}), (6, 11): (vineyard, 1, {}),      # the Monferrato and Langhe hills
    (6, 12): (vineyard, 2, {}),
    (7, 14): (olives, 3, {}), (6, 13): (olives, 2, {}),                                      # the Riviera di Ponente
    (5, 12): (grazing, 3, {"animal": "sheep"}), (4, 10): (grazing, 2, {"animal": "cattle"}),  # Alpine foothills
    (11, 11): (grazing, 2, {"animal": "horses"}), (13, 12): (grazing, 1, {"animal": "sheep"}),   # Apennine foothills
    (8, 12): (timber, 3, {}), (10, 11): (timber, 2, {}), (11, 13): (timber, 1, {}), (10, 10): (timber, 2, {}),
    (4, 13): (mines, 3, {}), (3, 15): (mines, 2, {}),                                        # the Maritime Alps
    (9, 12): (castles, 2, {}), (5, 14): (castles, 1, {}), (4, 9): (castles, 3, {}),          # Giovi, Col di Tenda, the Susa valley
    (13, 17): (salt, 3, {}),                                                                 # the flat shore south of Pisa
    (5, 15): (harbour, 1, {}), (10, 13): (harbour, 2, {}),                                   # fishing villages
}
COAST_FAMILIES = (salt, harbour)                     # they build at the map's shore: on the water too
# A port is a town piece plus the harbour add-on at the hex's own shore: town -> the add-on's level.
PORTS = {"Genoa": 3, "Pisa": 3, "Savona": 2, "Nice": 2, "Chiavari": 1}

# The two port modes (GUIDE section 10). CARVED: the map cuts a bay into the port's hex and the harbour sits in it,
# inside its own hex. SEASIDE: the harbour is added along the shore as it is. The mode comes from the map data and
# never changes in play: a place that is a city (rank 3) and a sea port in the data is a great port and is carved.
BAY_WIDTH = kit.BAY_WIDTH   # px, horn to horn (72): harbour.py has its carved layout (review task 9), so the bay is the
                            # guide's and its two horns stand inside the hex as headlands.
BAY_U0 = 2.0                # the harbour's works are centred 2 px off the shore's middle
BAY_BACK = {5: 18.0, 4: 16.0}      # px from the hex centre to the back of the bay: clear of a city's wall (others: kit.BAY_BACK)
BAYS = {}                   # town -> (u0, width, depth) once carve_ports() has cut it


def port_mode(t):
    return "carved" if t["rank"] == 3 and t["port"] else "seaside"


SITE_DY = -6.0              # the middle of a settlement piece lies 6 px above the hex centre (CY + 1 in settlements.py)
SS, SIZE, C = kit.SS, kit.SIZE, kit.C


# ---------------------------------------------------------------- taking a piece apart
_MASK = None


def feather_mask():
    """The kit's hex feather as a premultiplied multiplier (2x)."""
    global _MASK
    if _MASK is None:
        m = pygame.Surface((SIZE * SS, SIZE * SS), pygame.SRCALPHA)
        n = kit.FEATHER * SS
        for i in range(n + 1):
            a = int(255 * i / n)
            pygame.draw.polygon(m, (a, a, a, a), [kit.Pen.T(p) for p in kit.hex_points(i / SS)])
        _MASK = m
    return _MASK


def take_apart(draw, level, season, hx, sea=None, shore=None, bay=None, climate=None, **kw):
    """The piece of one hex from the kit, ready for the frame. Returns a dict:
    ground (112x112, premultiplied alpha), shadow (2x, white = none), things [(foot_y, order, image, rect)] with
    premultiplied images cut to their boxes, footprint (the kit's mask), mirror, variant."""
    lay = kit.take_apart(draw, level, season, hex=hx, sea=sea, shore=shore, bay=bay, climate=climate, **kw)
    g = lay["ground"].premul_alpha()                 # overlays are half-transparent: premultiply before scaling
    g.blit(feather_mask(), (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
    ground = pygame.transform.smoothscale(g, (SIZE, SIZE))
    things = []
    for n, (foot, order, fn) in enumerate(lay["standing"]):
        one = pygame.Surface((SIZE * SS, SIZE * SS), pygame.SRCALPHA)
        fn(kit.Pen(one))
        small = pygame.transform.smoothscale(one, (SIZE, SIZE))
        box = small.get_bounding_rect()
        if box.width:
            things.append((order, n, small.subsurface(box).copy(), box))
    return {"ground": ground, "shadow": lay["shadow"], "things": things, "footprint": lay["footprint"],
            "mirror": lay["mirror"], "variant": lay["variant"], "shore": lay["shore"]}


# ---------------------------------------------------------------- winter by climate
class Climate:
    """The winter of every point of the frame: the kit's cold index (kit.cold_index: latitude, height, km to the
    sea) on the frame's km grid. of_hex() is THE RULE for a hex (its centre's latitude, the hex's mean height from
    the height data, the km from its centre to the sea); at() and of() give the same index point by point, for the
    stand-in ground, so the snow line follows the mountains instead of the hex borders."""

    def __init__(self):
        F = FIELDS
        w, h = F.w, F.h
        INF = 1e12

        def edt(f):                                      # the exact squared distance along one line (Felzenszwalb)
            n = len(f)
            out, v, z, k = [0.0] * n, [0] * n, [0.0] * (n + 1), 0
            z[0], z[1] = -INF, INF
            for q in range(1, n):
                while True:
                    p_ = v[k]
                    x = ((f[q] + q * q) - (f[p_] + p_ * p_)) / (2.0 * q - 2.0 * p_)
                    if x <= z[k] and k > 0:
                        k -= 1
                    else:
                        break
                k += 1
                v[k], z[k], z[k + 1] = q, x, INF
            k = 0
            for q in range(n):
                while z[k + 1] < q:
                    k += 1
                out[q] = (q - v[k]) ** 2 + f[v[k]]
            return out
        d = [0.0 if F.land[k] <= 0.5 else 1e8 for k in range(w * h)]     # the distance to the sea in km
        for i in range(w):
            d[i::w] = edt(d[i::w])
        for j in range(h):
            d[j * w:(j + 1) * w] = edt(d[j * w:(j + 1) * w])
        d = [math.sqrt(v) for v in d]
        self.sea = d
        self.cold = [kit.cold_index(R.LAT_N - (F.y0 + k // w) / R.DEG, F.height[k], d[k]) for k in range(w * h)]

    def at(self, x_km, y_km):
        return FIELDS.at(self.cold, x_km, y_km)

    def of(self, x_km, y_km):
        c = self.at(x_km, y_km)
        return "mild" if c < kit.MILD_BELOW else "frost" if c < kit.SNOW_FROM else "snow"

    def hex_values(self, hx):
        x, y = R.centre(*hx)
        return R.LAT_N - y / R.DEG, float(R.HEX[hx].get("m", 0.0)), FIELDS.at(self.sea, x, y)

    def of_hex(self, hx):
        return kit.winter_of(*self.hex_values(hx))


_CLIMATE = None


def climate_field():
    global _CLIMATE
    if _CLIMATE is None:
        _CLIMATE = Climate()
    return _CLIMATE


def is_green(col):
    return col[1] > col[0] + 10 and col[1] > col[2] + 25


def snowy(col):
    """A green of the frame's hills and ranges as snow of the same lightness."""
    if not is_green(col):
        return col
    r, g, b = col[0], col[1], col[2]
    t = max(0.0, min(1.0, ((r + g + b) / 3.0 - 45) / 95.0))
    return kit.mix((96, 104, 124), (240, 243, 248), t) + tuple(col[3:])


def frosty(col):
    """The same green in a frost winter: half way to snow, the frosted ground's own tone showing."""
    if not is_green(col):
        return col
    t = max(0.0, min(1.0, ((col[0] + col[1] + col[2]) / 3.0 - 45) / 95.0))
    return kit.mix(kit.mix((92, 104, 96), kit.WINTER["frost"]["grass"], t), snowy(col), 0.45) + tuple(col[3:])


def mildy(col):
    """The same green in a mild winter: duller and greyer, no snow."""
    if not is_green(col):
        return col
    return kit.mix(col, kit.shade(kit.WINTER["mild"]["grass"], (col[0] + col[1] + col[2]) / 400.0), 0.8) + tuple(col[3:])


WINTER_TONE = {"snow": snowy, "frost": frosty, "mild": mildy}


@contextlib.contextmanager
def tone_draw(tone):
    """While open, the frame's green drawing comes out in the winter tone (for its hills and wooded ranges)."""
    d = pygame.draw
    old = {n: getattr(d, n) for n in ("polygon", "circle", "lines", "line", "ellipse")}

    def wrap(fn):
        return lambda surf, col, *a, **k: fn(surf, tone(col), *a, **k)
    for n, fn in old.items():
        setattr(d, n, wrap(fn))
    try:
        yield
    finally:
        for n, fn in old.items():
            setattr(d, n, fn)


SUMMER_COLS = {n: getattr(R, n) for n in ("C_FARM", "C_GRASS", "C_WOOD", "C_ROCK", "C_SAND", "C_SEA", "C_SHELF", "C_DEEP",
                                          "C_RIVER", "C_RIVER_EDGE")}


def season_cols(season, climate="snow"):
    cols = dict(SUMMER_COLS)
    if season == "winter":
        pal = kit.WINTER[climate]
        cols.update(C_FARM=pal["farm"], C_GRASS=pal["grass"], C_WOOD=pal["wood"], C_ROCK=pal["rock"], C_SAND=pal["sand"],
                    C_SEA=pal["sea"], C_SHELF=pal["shallow"], C_DEEP=kit.shade(pal["sea"], 0.8),
                    C_RIVER=pal["river"], C_RIVER_EDGE=pal["river_edge"])
    for n, c in cols.items():
        setattr(R, n, c)


PARCEL_WINTER = {
    "snow": ([(238, 241, 245), (214, 224, 236), (232, 236, 242), (190, 170, 148), (226, 232, 240)], (140, 152, 176, 150)),
    "frost": ([(228, 233, 232), (198, 208, 184), (234, 238, 240), (176, 156, 134), (214, 222, 204)], (136, 144, 150, 150)),
    "mild": ([(128, 160, 84), (138, 108, 78), (120, 150, 80), (150, 118, 84), (158, 176, 104)], (96, 96, 60, 150)),
}


# ---------------------------------------------------------------- the frame with pieces
class PieceFrame(R.Frame):
    def __init__(self, season="summer", towns=TOWN_LEVEL, fields=WHEAT, with_pieces=True, goods=GOODS):
        R.Frame.__init__(self, 60)
        self.season = season
        self.winter = season == "winter"
        self.assign = {}                                     # hex -> (family module, level, town or None)
        self.kw = {}                                         # hex -> the draw keywords of its piece
        self.pieces, self.addons = {}, {}
        if with_pieces:
            for name, lv in towns.items():
                t = WORLD["towns"][name]
                self.assign[t["hex"]] = (settlements, lv, t)
            for hx, lv in fields.items():
                assert hx not in self.assign, hx
                self.assign[hx] = (wheat, lv, None)
            for hx, (mod, lv, kw) in goods.items():
                assert hx not in self.assign, hx
                self.assign[hx] = (mod, lv, None)
                self.kw[hx] = kw
        self.stats = {}

    # ---- geometry
    def hex_px(self, hx):
        x, y = self.P(*R.centre(*hx))
        return int(round(x)), int(round(y))

    def in_piece(self, x_km, y_km):
        return R.hex_of_km(x_km, y_km) in self.assign

    def in_footprint(self, x_km, y_km):
        """True if the map point lies in the footprint of a piece (the area the piece works)."""
        return self.footprint_px(*self.P(x_km, y_km))

    def all_pieces(self):
        """Every piece with its hex: the hex's own piece first, then a port's harbour add-on."""
        return list(self.pieces.items()) + list(self.addons.items())

    def centre_of(self, hx, pc):
        """The map px of the middle of a piece's canvas: the hex centre, or an add-on's anchor at the shore."""
        return pc.get("centre") or self.hex_px(hx)

    def footprint_px(self, x, y):
        for hx, pc in self.all_pieces():
            cx, cy = self.centre_of(hx, pc)
            if abs(x - cx) < C and abs(y - cy) < C and kit.in_footprint(pc["footprint"], x - cx, y - cy):
                return True
        return False

    def winter_at(self, x, y):
        """The winter at a map px."""
        return climate_field().of(*self.km(x, y))

    def sea_of(self, hx):
        """Where the map has the sea in this hex, for the kit: (sea, shore) = the direction to the sea as an angle
        on screen and the shore line as piece-px points; (None, None) for a hex without sea."""
        return self.sea_at(*self.hex_px(hx))

    def sea_at(self, cx, cy):
        """sea_of() for a piece canvas centred on any map px (a harbour add-on is anchored at the shore)."""
        wet = []
        for j in range(-50, 51, 4):
            for i in range(-52, 53, 4):
                if kit.in_hex(i, j) and not FIELDS.is_land(*self.km(cx + i, cy + j)):
                    wet.append((i, j))
        if len(wet) < 3:
            return None, None
        sx, sy = sum(p[0] for p in wet) / len(wet), sum(p[1] for p in wet) / len(wet)
        if math.hypot(sx, sy) < 1e-6:
            return None, None
        ang = math.degrees(math.atan2(sy, sx))
        out = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
        along = (out[1], -out[0])
        line = []
        for u in range(-54, 55, 6):
            for v in range(-60, 61):
                x, y = along[0] * u + out[0] * v, along[1] * u + out[1] * v
                if not FIELDS.is_land(*self.km(cx + x, cy + y)):
                    line.append((x, y))
                    break
        return (ang, line) if len(line) >= 2 else (None, None)

    # ---- the frame's own drawing, without what the pieces replace
    def parcels(self):
        keep = [p for p in R.PARCELS if not self.in_piece(p["x"], p["y"])]
        self.stats["parcels dropped"] = len(R.PARCELS) - len(keep)
        cols, edge = R.PARCEL_COLS, (104, 120, 60, 150)
        lay = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        for p in keep:
            if self.winter:
                cols, edge = PARCEL_WINTER[climate_field().of(p["x"], p["y"])]
            ca, sa = math.cos(p["a"]), math.sin(p["a"])
            pts = []
            for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                pts.append(self.P(p["x"] + ca * u * p["w"] / 2 - sa * v * p["h"] / 2, p["y"] + sa * u * p["w"] / 2 + ca * v * p["h"] / 2))
            pygame.draw.polygon(lay, cols[p["c"]] + (215,), pts)
            pygame.draw.lines(lay, edge, True, pts, 1)
        self.surf.blit(lay, (0, 0))

    def water(self):
        self.piece_ground()            # the pieces' fields and yards lie under the rivers and roads (other layers)
        if not self.winter:
            return R.Frame.water(self)
        k = self.k                      # winter: the same lines without the green valley band
        cold, mild = kit.WINTER["snow"], kit.WINTER["mild"]     # streams freeze where snow lies; in a mild winter all water runs
        for st in WORLD["streams"]:
            self.stroke2(st, 1.6 * k + 1.6, 2.6 * k + 1.6, kit.ICE_D, mild["river_edge"])
        for rv in WORLD["rivers"]:
            w = {3: 6.5, 2: 4.6, 1: 3.4}[rv["cls"]] * k
            self.stroke2(rv["pts"], w * 0.75 + 2, w + 2, cold["river_edge"], mild["river_edge"], clip_land=False)
        for st in WORLD["streams"]:
            self.stroke2(st, 1.2 * k, 2.4 * k, kit.ICE, mild["river"])
        for rv in WORLD["rivers"]:
            w = {3: 6.5, 2: 4.6, 1: 3.4}[rv["cls"]] * k
            self.stroke2(rv["pts"], w * 0.75, w, cold["river"], mild["river"], clip_land=False)

    def stroke2(self, pts_km, w0, w1, col, col_mild, clip_land=True, step=0.35):
        """The frame's stroke(), with the colour chosen point by point: col_mild where the winter is mild."""
        pts = R.resample(pts_km, step)
        n = len(pts)
        cf = climate_field()
        for i, q in enumerate(pts):
            if clip_land and not FIELDS.is_land(q[0], q[1], -0.035):
                continue
            w = w0 + (w1 - w0) * i / max(1, n - 1)
            pygame.draw.circle(self.surf, col_mild if cf.at(*q) < kit.MILD_BELOW else col, self.P(*q), max(0.6, w / 2))

    def relief(self):
        # Relief rule K (review section 3): no range, spur or hill stands inside or in front of a piece's footprint.
        hills, relief = R.HILLS, R.RELIEF
        R.HILLS = [h for h in hills if not self.in_piece(h["x"], h["y"])]
        self.stats["hills dropped"] = len(hills) - len(R.HILLS)

        def covers(s):                 # a peak drawn at this foot hides what lies up to 30 px behind (north of) it
            x, y = self.P(s["x"], s["y"])
            return any(self.footprint_px(x, y - d) for d in (0, 10, 20, 30))
        kept, dropped = [], 0
        for rg in relief:              # a range is cut where it is dropped: the two ends are not joined over the gap
            run = []
            for q in rg:
                if covers(q):
                    dropped += 1
                    if run:
                        kept.append(run)
                    run = []
                else:
                    run.append(q)
            if run:
                kept.append(run)
        self.stats["range samples dropped at footprints"] = dropped
        R.RELIEF = kept
        try:
            R.Frame.relief(self)
        finally:
            R.HILLS, R.RELIEF = hills, relief

    def trees(self):
        # the map's wild land stays; it is thinned only where a piece works (the piece's footprint)
        trees = R.TREES
        inside = [t for t in trees if self.in_piece(t["x"], t["y"])]
        R.TREES = [t for t in trees if not self.in_footprint(t["x"], t["y"])]
        self.stats["trees of the map in piece hexes"] = len(inside)
        self.stats["trees thinned by the footprints"] = len(trees) - len(R.TREES)
        try:
            R.Frame.trees(self)
        finally:
            R.TREES = trees

    def towns(self):
        towns = WORLD["towns"]
        mine = {a[2]["name"] for a in self.assign.values() if a[2]}
        WORLD["towns"] = {n: t for n, t in towns.items() if n not in mine}
        try:
            R.Frame.towns(self)
        finally:
            WORLD["towns"] = towns
        for t in towns.values():        # no name plates on the normal map for now
            t.pop("_label", None)
            t.pop("_label_at", None)
        self.place_pieces()

    # ---- winter stand-in, by climate
    def ground(self):
        if not self.winter:
            return R.Frame.ground(self)
        # The frame's ground three times, in the three winter palettes, laid over each other through the cold index.
        layers = {}
        for c in ("mild", "frost", "snow"):
            season_cols("winter", c)
            R.Frame.ground(self)
            if c == "snow":
                self.high_snow()
            if c == "frost":
                self.frost_patches()
            layers[c] = self.surf.copy()
        season_cols("winter", "snow")
        self.surf.blit(layers["mild"], (0, 0))
        for c, edge, band in (("frost", kit.MILD_BELOW, 0.3), ("snow", kit.SNOW_FROM, 0.4)):
            lay = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
            lay.blit(layers[c], (0, 0))
            lay.blit(self.cold_mask(edge, band), (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
            self.surf.blit(lay, (0, 0))
        self.ground_img = self.surf.copy()

    def cold_mask(self, edge, band):
        """White with alpha: opaque where the cold index lies above edge, fading over +/- band."""
        F, cf = FIELDS, climate_field()
        small = pygame.Surface((F.w, F.h), pygame.SRCALPHA)
        for k, c in enumerate(cf.cold):
            a = int(255 * R.smoothstep(edge - band, edge + band, c))
            small.set_at((k % F.w, k // F.w), (255, 255, 255, a))
        big = pygame.transform.smoothscale(small, (int(F.w * self.S), int(F.h * self.S * R.TILT)))
        out = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        out.fill((255, 255, 255, 0))
        out.blit(big, (-2 * self.S, -2 * self.S * R.TILT), special_flags=pygame.BLEND_RGBA_MAX)
        return out

    def high_snow(self):
        # The frame turns high ground to bare stone with a fixed colour; under snow it is snow with some stone showing.
        s = self.surf
        for y in range(self.H):
            for x in range(self.W):
                r, g, b, _ = s.get_at((x, y))
                if r > g > b and r - b > 18 and r < 215 and FIELDS.at(FIELDS.land, *self.km(x, y)) > 0.56:
                    t = max(0.0, min(1.0, ((r + g + b) / 3.0 - 120) / 60.0))
                    s.set_at((x, y), kit.mix((r, g, b), kit.mix((186, 194, 212), kit.SNOW, t), 0.8))

    def frost_patches(self):
        """A frost winter's ground: patches of thin snow on the frosted ground, as the kit's sheets show it."""
        rnd = random.Random(77)
        cf = climate_field()
        lay = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        for _ in range(5200):
            x, y = rnd.uniform(0, self.W), rnd.uniform(0, self.H)
            w, h = rnd.uniform(10, 30), rnd.uniform(5, 12)
            kx, ky = self.km(x, y)
            if R.vnoise(kx, ky, 9.0, 61) < 0.52:         # in drifts, not as a pattern
                continue
            if not (kit.MILD_BELOW - 0.4 < cf.at(kx, ky) < kit.SNOW_FROM + 0.5):
                continue
            if not all(FIELDS.is_land(*self.km(x + dx, y + dy), 0.04) for dx, dy in ((-w / 2, 0), (w / 2, 0), (0, -h / 2), (0, h / 2))):
                continue
            pygame.draw.ellipse(lay, kit.SNOW + (185,), (x - w / 2, y - h / 2, w, h))
        self.surf.blit(lay, (0, 0))

    def draw_range(self, g):
        if not self.winter:
            return R.Frame.draw_range(self, g)
        q = g[len(g) // 2]
        with tone_draw(WINTER_TONE[self.winter_at(q["x"], q["y"])]):
            R.Frame.draw_range(self, g)

    def draw_hill(self, x, y, h, seed):
        if not self.winter:
            return R.Frame.draw_hill(self, x, y, h, seed)
        with tone_draw(WINTER_TONE[self.winter_at(x, y)]):
            R.Frame.draw_hill(self, x, y, h, seed)

    def ground_tone(self, x, y, base, share):
        if self.winter:
            base = WINTER_TONE[self.winter_at(x, y)](base)
        return R.Frame.ground_tone(self, x, y, base, share)

    def draw_tree(self, x, y, sc, f=1.0):
        if not self.winter:
            return R.Frame.draw_tree(self, x, y, sc, f)
        s = self.surf                   # bare twigs, with a dab of snow where snow lies, as kit.Piece.tree draws them
        r, th = 4.4 * sc, 3.0 * sc
        pygame.draw.line(s, kit.TRUNK, (x, y), (x, y - th), max(1, int(1.4 * sc)))
        for dx, dy in ((-0.9, -0.5), (-0.45, -1.0), (0.1, -1.15), (0.6, -0.95), (0.95, -0.45)):
            pygame.draw.line(s, (70, 54, 44), (x, y - th), (x + dx * r, y - th + dy * r * 1.25), 1)
        if self.winter_at(x, y) != "mild":
            pygame.draw.line(s, kit.SNOW, (x - r * 0.7, y - th - r * 0.75), (x - r * 0.1, y - th - r * 1.3), 1)

    def draw_conifer(self, x, y, sc, f=1.0):
        if not self.winter:
            return R.Frame.draw_conifer(self, x, y, sc, f)
        clim = self.winter_at(x, y)
        s = self.surf
        h, w = 12.5 * sc, 7.2 * sc
        oc, lit, dk = kit.WINTER[clim]["conifer"]
        pygame.draw.line(s, kit.TRUNK, (x, y), (x, y - 2.5 * sc), max(1, int(1.3 * sc)))
        pts = [(x, y - h), (x + w / 2, y - 2 * sc), (x - w / 2, y - 2 * sc)]
        pygame.draw.polygon(s, R.shade(lit, f), pts)
        pygame.draw.polygon(s, R.shade(dk, f), [(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)])
        if clim != "mild":
            pygame.draw.polygon(s, kit.SNOW, [(x, y - h), (x - w * 0.5, y - 2 * sc), (x - w * 0.16, y - 2 * sc), (x - w * 0.02, y - h * 0.5)])
        pygame.draw.polygon(s, oc, pts, 1)

    # ---- the pieces
    def build_pieces(self):
        self.pieces = {}
        self.stats["sea side"] = {}
        self.stats["picture (layout, mirrored)"] = {}
        self.addons = {}
        self.stats["coast pieces (family, level asked, level given, land depth px)"] = {}
        self.stats["coast pieces left out (no shore in the hex)"] = []
        self.stats["winter of the piece hexes"] = {}
        self.stats["port modes"] = {}
        for hx, (mod, lv, t) in sorted(self.assign.items()):
            sea, shore = self.sea_of(hx)
            clim = None
            if self.winter:                              # the rule: the hex's latitude, mean height and km to the sea
                clim = climate_field().of_hex(hx)
                self.stats["winter of the piece hexes"][hx] = clim
            if mod in COAST_FAMILIES:
                pc = self.coast_piece(mod, lv, hx, sea, shore, climate=clim, **self.kw.get(hx, {}))
                if pc is None:
                    continue
            else:
                pc = take_apart(mod.draw, lv, self.season, hx, sea, shore, climate=clim, **self.kw.get(hx, {}))
            pc["coast"] = mod in COAST_FAMILIES
            self.pieces[hx] = pc
            if sea is not None:
                self.stats["sea side"][hx] = "%d deg" % round(sea)
            self.stats["picture (layout, mirrored)"][hx] = (pc["variant"], pc["mirror"])
            if t and t["name"] in PORTS and sea is not None:
                # A port: the harbour add-on at the hex's own shore. Its canvas is ANCHORED AT THE SHORE, not at
                # the hex centre: moved along the sea direction until the shore lies where the harbour expects
                # it (COAST y0 px out from the middle), so the basin may reach into the sea hex next door.
                out = kit.sea_vector(sea)
                d0 = min(shore, key=lambda q: abs(q[0] * out[1] - q[1] * out[0]))
                shift = d0[0] * out[0] + d0[1] * out[1] - harbour.COAST["y0"]
                cx, cy = self.hex_px(hx)
                ax, ay = int(round(cx + out[0] * shift)), int(round(cy + out[1] * shift))
                sea2, shore2 = self.sea_at(ax, ay)
                if sea2 is not None:
                    bay = BAYS.get(t["name"])            # a carved port: the harbour is told its bay (shore.bay)
                    ad = self.coast_piece(harbour, PORTS[t["name"]], hx, sea2, shore2, addon=True, bay=bay, climate=clim)
                    ad["coast"] = True
                    ad["centre"] = (ax, ay)
                    ad["home"] = bay is not None         # a carved harbour stays inside the port's own hex
                    self.stats["port modes"][t["name"]] = "carved, bay (u0, width, depth) = (%d, %d, %d) px" % bay if bay else "seaside"
                    ad["under"] = pc["footprint"]        # add-on things inside the town's footprint are left out
                    self.addons[hx] = ad
                    self.stats.setdefault("harbour add-on anchor (px from the hex centre)", {})[t["name"]] = int(round(shift))
        for hx in [h for h in self.assign if h not in self.pieces]:
            del self.assign[hx]                          # no shore, no coast piece: the hex stays the map's

    def coast_piece(self, mod, level, hx, sea, shore, **kw):
        """A coast family's piece at the map's shore. The module lists the land depth each level needs (NEED): a
        hex with less land behind its shore takes a lower level; a hex without a shore takes no coast piece."""
        if sea is None:
            self.stats["coast pieces left out (no shore in the hex)"].append((mod.__name__, hx))
            return None
        lv = level
        while True:
            pc = take_apart(mod.draw, lv, self.season, hx, sea, shore, **kw)
            if lv == 1 or pc["shore"] is None or pc["shore"].depth >= mod.NEED[lv] or kw.get("addon"):
                break
            lv -= 1
        self.stats["coast pieces (family, level asked, level given, land depth px)"][hx if not kw.get("addon") else hx + ("add-on",)] = (
            mod.__name__, level, lv, int(pc["shore"].depth) if pc["shore"] else None)
        return pc

    def piece_ground(self):
        """The ground detail of every piece, on the frame's ground, clipped to the land."""
        self.build_pieces()
        lost = {}
        for hx, pc in self.all_pieces():
            ground = pc["ground"]
            cx, cy = self.centre_of(hx, pc)
            land = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)
            n = 0
            for j in range(SIZE):
                for i in range(SIZE):
                    if not pc["coast"] and ground.get_at((i, j))[3] and not FIELDS.is_land(*self.km(cx - C + i + 0.5, cy - C + j + 0.5)):
                        n += 1                           # (a coast piece's jetties and moles lie on the water)
                    else:
                        land.set_at((i, j), (255, 255, 255, 255))
            if n:
                lost[hx] = n
                ground = ground.copy()
                ground.blit(land, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
            self.surf.blit(ground, (cx - C, cy - C), special_flags=pygame.BLEND_PREMULTIPLIED)
        self.stats["ground px clipped at the sea"] = lost

    def place_pieces(self):
        """Every standing thing of every piece joins the frame's back-to-front list by the y of its foot. The map
        owns the shore: a thing whose foot would stand in the water is left out."""
        wet = {}
        hidden = {}
        outside = {}
        count = 0
        for hx, pc in self.all_pieces():
            cx, cy = self.centre_of(hx, pc)
            tx, ty = self.hex_px(hx)
            for y, n, img, box in pc["things"]:
                pos = (cx - C + box.x, cy - C + box.y)
                foot_y = min(cy + y, pos[1] + box.height)               # smoke is queued 30 px low: use the picture's foot
                if pc.get("home") and not kit.in_hex(pos[0] + box.width / 2 - tx, foot_y - ty, 0):
                    outside["standing"] = outside.get("standing", 0) + 1      # counted, still drawn
                if not pc["coast"] and y < 60 and any(not FIELDS.is_land(*self.km(fx, foot_y)) for fx in (pos[0] + 1, pos[0] + box.width // 2, pos[0] + box.width - 1)):
                    wet[hx] = wet.get(hx, 0) + 1
                    continue
                if pc["coast"] and not kit.in_hex(box.centerx - C, foot_y - cy, 1):
                    hidden[hx] = hidden.get(hx, 0) + 1                  # the map's shore pushed it out of its canvas hex
                    continue
                if (pc.get("under") is not None and kit.in_footprint(pc["under"], pos[0] + box.width / 2 - tx, foot_y - ty)
                        and FIELDS.is_land(*self.km(pos[0] + box.width / 2, foot_y))):       # (what stands on the water is the harbour's)
                    hidden[hx] = hidden.get(hx, 0) + 1                  # an add-on thing inside the town: left out
                    continue
                self.add(cy + y + n * 1e-5, cx, (lambda im, p: lambda: self.surf.blit(im, p, special_flags=pygame.BLEND_PREMULTIPLIED))(img, pos))
                count += 1
        self.stats["standing things placed"] = count
        self.stats["carved harbours: things with their foot outside the port's own hex"] = outside
        self.stats["standing things left out at the sea"] = wet
        self.stats["coast things left out (inside the town, or pushed out of the hex by the shore)"] = hidden

    def draw_shadows(self):
        lay = pygame.Surface((self.W, self.H))
        lay.fill((255, 255, 255))
        lay.set_colorkey((255, 255, 255))
        for _, x, y, w, h in self.shadows:
            r = pygame.Rect(0, 0, w, h)
            r.center = (x, y)
            pygame.draw.ellipse(lay, (30, 50, 30), r)
        for hx, pc in self.all_pieces():
            cx, cy = self.centre_of(hx, pc)
            small = pygame.transform.smoothscale(pc["shadow"].convert(24), (SIZE, SIZE))
            small.set_colorkey((255, 255, 255))
            lay.blit(small, (cx - C, cy - C))
        lay.set_alpha(46)
        self.surf.blit(lay, (0, 0))

    def render(self, path):
        season_cols(self.season)
        try:
            R.Frame.render(self, path)
        finally:
            season_cols("summer")
        return self.measure()

    # ---- the measurements
    def measure(self):
        out = []
        for k in sorted(self.stats):
            out.append("%s: %s" % (k, self.stats[k]))
        # what of the frame is left inside the piece hexes
        left = {}
        for rv in WORLD["rivers"]:
            for p in rv["pts"]:
                hx = R.hex_of_km(*p)
                if hx in self.assign:
                    left.setdefault(hx, set()).add("river " + rv["name"])
        for st in WORLD["streams"]:
            for p in st:
                hx = R.hex_of_km(*p)
                if hx in self.assign:
                    left.setdefault(hx, set()).add("stream")
        for rd in WORLD["roads"]:
            for p in rd["pts"]:
                hx = R.hex_of_km(*p)
                if hx in self.assign:
                    left.setdefault(hx, set()).add("road")
        for rg in R.RELIEF:
            for s in rg:
                hx = R.hex_of_km(s["x"], s["y"])
                if hx in self.assign:
                    left.setdefault(hx, set()).add("range (%s)" % s["kind"])
        for hx in sorted(left):
            mod, lv, t = self.assign[hx]
            out.append("hex %d,%d (%s L%d): the frame still draws %s" % (hx[0], hx[1], t["name"] if t else mod.__name__, lv, ", ".join(sorted(left[hx]))))
        for line in out:
            print("  ", line)
        return out


def move_sites(towns=TOWN_LEVEL):
    """A town with a piece stands at the middle of its piece; the roads are led there and the frame's own trees,
    hills and fields are built again round the new sites (the frame's own functions, nothing changed)."""
    S = 60.0 / R.R_KM
    for name in towns:
        t = WORLD["towns"][name]
        t["site0"] = (t["x"], t["y"])
        if name in R.sites.SHARED_SITES:
            continue                    # Genoa, Savona, Chiavari: their roads are fixed lines shared with the close-up
        cx, cy = R.centre(*t["hex"])
        t["x"], t["y"] = cx, cy + SITE_DY / (S * R.TILT)
    R.build_roads(WORLD)
    R.RELIEF, R.HILLS, R.RGRID = R.build_relief(WORLD, FIELDS)
    R.TREES = R.build_trees(WORLD, FIELDS, R.RGRID)
    R.PARCELS = R.build_parcels(WORLD, FIELDS)


def carve_ports(towns=TOWN_LEVEL):
    """The carved ports: cuts the kit's bay (kit.carve) into the frame's land field, in the port's own hex. The
    back of the bay is put where the harbour wants its shore (BAY_BACK px from the hex centre: clear of a city's
    wall); the shore moves at most kit.BAY_REACH px. Run once, before the frame's trees and fields are built."""
    f = PieceFrame("summer", with_pieces=False)
    F = FIELDS
    report = {}
    for name in PORTS:
        t = WORLD["towns"][name]
        if port_mode(t) != "carved":
            continue
        cx, cy = f.hex_px(t["hex"])
        sea, shore = f.sea_at(cx, cy)
        if sea is None:
            continue
        out = kit.sea_vector(sea)
        along = (out[1], -out[0])
        d0 = kit._shore_h(shore, out)(BAY_U0)
        back = max(kit.BAY_BACK, BAY_BACK.get(towns.get(name, 0), kit.BAY_BACK))
        depth = min(kit.BAY_REACH, d0 - back)
        if depth < 3:
            report[name] = "not carved: the shore already lies %d px from the centre" % d0
            continue
        bay = (BAY_U0, BAY_WIDTH, depth)
        new = kit.carve(sea, shore, (BAY_U0, BAY_WIDTH + 6, depth))      # 6 px wider: the land field is a 1 km grid and rounds the cut
        cells = 0
        for j in range(F.h):
            for i in range(F.w):
                x, y = f.P(F.x0 + i, F.y0 + j)
                x, y = x - cx, y - cy
                if abs(x) > 60 or abs(y) > 60 or not kit.in_hex(x, y, 1.5):
                    continue                             # the bay never leaves the port's own hex
                u, d = x * along[0] + y * along[1], x * out[0] + y * out[1]
                if abs(u - BAY_U0) > BAY_WIDTH / 2 + 3:
                    continue
                wet = d - new.h(u)                       # px beyond the bay's shore (below 0: land)
                if wet > -8:
                    k = j * F.w + i
                    v = 0.5 - max(-0.3, min(0.3, wet / 6.0))
                    if v < F.land[k]:
                        cells += F.land[k] > 0.5 >= v
                        F.land[k] = v
        BAYS[name] = bay
        report[name] = "bay %d px wide, shore moved %d px (%.1f km) inland to %d px from the hex centre; %d km2 of land turned to sea" % (
            BAY_WIDTH, depth, depth / (f.S * (abs(out[0]) + abs(out[1]) * R.TILT)), back, cells)
    for name, line in report.items():
        print("   carved port %s: %s" % (name, line))
    print("   coast drift after carving: %.1f km from the frame's first line (the frame's cove rule: %.1f km)" % (
        R.sites.coast_shift(F), R.sites.COAST_REACH_KM))
    return report


def probe():
    """Lists the farmland hexes in view: where wheat pieces can go."""
    f = R.Frame(60)
    for (c, r), h in sorted(R.HEX.items()):
        if not h.get("land"):
            continue
        x, y = f.P(*R.centre(c, r))
        if not (30 < x < 1250 and 30 < y < 690):
            continue
        town = [t["name"] for t in WORLD["towns"].values() if t["hex"] == (c, r)]
        riv = sum(1 for rv in WORLD["rivers"] for p in rv["pts"] if R.hex_of_km(*p) == (c, r))
        st = sum(1 for s in WORLD["streams"] for p in s if R.hex_of_km(*p) == (c, r))
        rd = sum(1 for d in WORLD["roads"] for p in d["pts"] if R.hex_of_km(*p) == (c, r))
        print("%2d,%2d px %4d,%3d cover %d level %d %4d m  river %3d stream %3d road %3d  %s" % (
            c, r, x, y, h["cover"], h["level"], h.get("m", 0), riv, st, rd, " ".join(town)))


CROP = (460, 0, 640, 360)      # the Po plain: Asti to Piacenza
CROP2 = (130, 230, 640, 360)   # the Alps to Genoa: mines, the castle at the pass, grazing, vineyards, olives, two ports
CROP3 = (300, 60, 640, 420)    # winter: the Po plain (frost), the Apennines (snow) and the Ligurian coast (mild)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--probe" in sys.argv:
        return probe()
    out = args[0] if args else os.path.join(HERE, "..", "..", "..", "docs", "design", "map", "pieces_in_map")
    which = args[1] if len(args) > 1 else "both"
    os.makedirs(out, exist_ok=True)
    carve_ports()
    move_sites()
    if which in ("both", "summer"):
        f = PieceFrame("summer")
        f.render(os.path.join(out, "summer.png"))
        crop = f.surf.subsurface(pygame.Rect(CROP)).copy()
        pygame.image.save(pygame.transform.scale(crop, (CROP[2] * 2, CROP[3] * 2)), os.path.join(out, "plain_crop.png"))
        crop = f.surf.subsurface(pygame.Rect(CROP2)).copy()
        pygame.image.save(pygame.transform.scale(crop, (CROP2[2] * 2, CROP2[3] * 2)), os.path.join(out, "hills_coast_crop.png"))
    if which in ("both", "winter"):
        f = PieceFrame("winter")
        f.render(os.path.join(out, "winter.png"))
        crop = f.surf.subsurface(pygame.Rect(CROP3)).copy()
        pygame.image.save(pygame.transform.scale(crop, (CROP3[2] * 2, CROP3[3] * 2)), os.path.join(out, "winter_crop.png"))
        cf = climate_field()
        for name in ("Genoa", "Savona", "Pisa", "Pavia", "Asti", "Turin", "Serravalle", "Cuneo", "Susa"):
            hx = WORLD["towns"][name]["hex"]
            lat, m, sea = cf.hex_values(hx)
            print("   winter rule %-11s lat %.2f, %4d m, %3d km to the sea: cold %.1f = %s" % (name, lat, m, sea, kit.cold_index(lat, m, sea), cf.of_hex(hx)))


if __name__ == "__main__":
    main()
