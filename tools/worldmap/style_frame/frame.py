"""Hexa map style frame: the Gulf of Genoa, the Ligurian Apennines and the Maritime Alps, in one slight 3/4 view.

python frame.py OUT_DIR
"""
import os, sys, math, random
os.environ["SDL_VIDEODRIVER"] = "dummy"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pygame
from geo import *
import sites

pygame.init()

TILT = float(os.environ.get("SF_TILT", "0.85"))            # the ground plane is seen a little from above: north-south distances shrink to 85 per cent
X0, Y0 = 70.0, 214.0   # the north-west corner of the frame, in km from the region's corner
LIGHT = (-0.75, -0.66)  # light from the upper left

# ---------------------------------------------------------------- palette (direction A)
INK = (52, 44, 46)
C_FARM = (178, 198, 98)
C_GRASS = (146, 186, 86)
C_WOOD = (112, 164, 78)
C_ROCK = (170, 156, 130)
C_SNOW = (242, 245, 250)
C_SAND = (234, 216, 162)
C_SEA = (71, 143, 192)
C_SHELF = (96, 168, 210)
C_DEEP = (52, 112, 170)
C_FOAM = (226, 242, 248)
C_RIVER = (74, 146, 206)
C_RIVER_EDGE = (44, 92, 140)
C_ROAD = (226, 206, 152)
C_ROAD_EDGE = (128, 100, 66)

TOWNS = [  # name, rank (3 city, 2 town, 1 village), lon, lat, port
    ("Genoa", 3, 8.93, 44.41, True), ("Turin", 3, 7.69, 45.07, False), ("Pavia", 3, 9.16, 45.19, False),
    ("Pisa", 3, 10.40, 43.72, False), ("Asti", 2, 8.21, 44.90, False), ("Alessandria", 2, 8.61, 44.91, False),
    ("Piacenza", 2, 9.69, 45.05, False), ("Parma", 2, 10.33, 44.80, False), ("Savona", 2, 8.48, 44.31, True),
    ("Cuneo", 2, 7.55, 44.39, False), ("Nice", 2, 7.27, 43.70, True), ("Susa", 2, 7.05, 45.14, False),
    ("Serravalle", 1, 8.86, 44.72, False), ("Chiavari", 1, 9.32, 44.32, True),
]
PASSES = [("Giovi", 8.93, 44.56, 472), ("Col di Tenda", 7.57, 44.15, 1871), ("Mont Cenis", 6.90, 45.26, 2083)]


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return (int(c1[0] + (c2[0] - c1[0]) * t), int(c1[1] + (c2[1] - c1[1]) * t), int(c1[2] + (c2[2] - c1[2]) * t))


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))))


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def chaikin(pts, n=2, closed=False):
    for _ in range(n):
        out = [pts[0]] if not closed else []
        rng = range(len(pts)) if closed else range(len(pts) - 1)
        for i in rng:
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append((a[0] * .75 + b[0] * .25, a[1] * .75 + b[1] * .25))
            out.append((a[0] * .25 + b[0] * .75, a[1] * .25 + b[1] * .75))
        if not closed:
            out.append(pts[-1])
        pts = out
    return pts


def resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        d = math.dist(a, b)
        t = step - acc
        while t <= d:
            out.append((a[0] + (b[0] - a[0]) * t / d, a[1] + (b[1] - a[1]) * t / d))
            t += step
        acc = (acc + d) % step
    if math.dist(out[-1], pts[-1]) > step * 0.3:
        out.append(pts[-1])
    return out


class Grid:
    """Spatial hash of points (km) for nearest-distance queries."""
    def __init__(self, cell=4.0):
        self.cell = cell
        self.d = {}

    def add(self, x, y, tag=None):
        self.d.setdefault((int(x // self.cell), int(y // self.cell)), []).append((x, y, tag))

    def near(self, x, y, r):
        cx, cy, n = int(x // self.cell), int(y // self.cell), int(r // self.cell) + 1
        best, bt = 1e9, None
        for i in range(cx - n, cx + n + 1):
            for j in range(cy - n, cy + n + 1):
                for p in self.d.get((i, j), ()):
                    dd = (p[0] - x) ** 2 + (p[1] - y) ** 2
                    if dd < best:
                        best, bt = dd, p[2]
        return math.sqrt(best), bt


# ---------------------------------------------------------------- the land model (km space)
def hex_height(c, r):
    h = HEX.get((c, r))
    if not h or not h.get("land"):
        return 0.0
    return float(h.get("m", 0.0))


def blend_field(x, y, fn, reach=1.25):
    """Kernel blend of a per-hex value over the hexes round a point."""
    c, r = hex_of_km(x, y)
    tot = wsum = 0.0
    for cc in range(c - 2, c + 3):
        for rr in range(r - 2, r + 3):
            if (cc, rr) not in HEX:
                continue
            hx, hy = centre(cc, rr)
            d = math.hypot(hx - x, hy - y) / (reach * W_KM)
            if d >= 1:
                continue
            w = (1 - d) ** 2
            tot += w * fn(cc, rr)
            wsum += w
    return tot / wsum if wsum else 0.0


def M(x, y):
    return blend_field(x, y, hex_height)


def is_land_hex(c, r):
    h = HEX.get((c, r))
    return bool(h and h.get("land"))


def cover_w(kind):
    return lambda c, r: 1.0 if is_land_hex(c, r) and HEX[(c, r)]["cover"] == kind else 0.0


def build_world():
    w = {}
    # rivers: the edge lines of the data, smoothed, with a little meander
    rivers = []
    for rv in L["rivers"]:
        pts = chaikin(rv["pts"], 3)
        pts = resample(pts, 1.2)
        rnd = random.Random(rv["name"])
        ph = rnd.random() * 6
        out = []
        for i, p in enumerate(pts):
            if 0 < i < len(pts) - 1:
                a, b = pts[i - 1], pts[i + 1]
                dx, dy = b[0] - a[0], b[1] - a[1]
                n = math.hypot(dx, dy) or 1
                m = math.sin(i * 0.55 + ph) * 0.7 + math.sin(i * 0.21 + ph * 2) * 0.6
                out.append((p[0] - dy / n * m, p[1] + dx / n * m))
            else:
                out.append(p)
        rivers.append(dict(name=rv["name"], cls=rv["class"], pts=out))
    # streams: one edge each; keep those whose lower end reaches a river or the sea within a short step
    rgrid = Grid(3.0)
    for rv in rivers:
        for p in rv["pts"]:
            rgrid.add(p[0], p[1], rv["name"])
    streams = []
    for e in L["streams"]:
        pts = edge_pts((e[0], e[1]), (e[2], e[3]))
        if len(pts) != 2:
            continue
        best = None
        for end in (0, 1):
            p = pts[end]
            d, _ = rgrid.near(p[0], p[1], 10)
            sea = any(not is_land_hex(*n) and n in HEX for n in [hex_of_km(p[0] + dx, p[1] + dy) for dx, dy in ((5, 0), (-5, 0), (0, 5), (0, -5))])
            if d < 9 or sea:
                if best is None or d < best[0]:
                    best = (d if not sea else 0, end, sea)
        if best is None:
            continue
        lo = pts[best[1]]
        hi = pts[1 - best[1]]
        line = [hi, ((hi[0] + lo[0]) / 2 + 1.2, (hi[1] + lo[1]) / 2), lo]
        if not best[2]:
            # carry it on to the river
            d, _ = rgrid.near(lo[0], lo[1], 10)
            bx = by = None
            bd = 1e9
            for rv in rivers:
                for p in rv["pts"]:
                    dd = math.dist(p, lo)
                    if dd < bd:
                        bd, bx, by = dd, p[0], p[1]
            line.append((bx, by))
        else:
            # run on into the sea
            dx, dy = lo[0] - hi[0], lo[1] - hi[1]
            n = math.hypot(dx, dy)
            line.append((lo[0] + dx / n * 5, lo[1] + dy / n * 5))
        pts2 = resample(chaikin(line, 3), 1.0)
        streams.append(pts2)
    w["rivers"], w["streams"] = rivers, streams
    wgrid = Grid(3.0)
    for rv in rivers:
        for p in rv["pts"]:
            wgrid.add(p[0], p[1], "river%d" % rv["cls"])
    for st in streams:
        for p in st:
            wgrid.add(p[0], p[1], "stream")
    w["wgrid"] = wgrid
    # towns
    towns = []
    for name, rank, lon, lat, port in TOWNS:
        x, y = km_of(lon, lat)
        towns.append(dict(name=name, rank=rank, x=x, y=y, real=(x, y), port=port))
    # one town, one hex: the hex comes from the map data; the site inside it is set by sites.place_sites
    sites.resolve_hexes(towns)
    for t in towns:                   # a port stands between its hex centre and its quay, so it is drawn a little smaller
        t["scale"] = {"Genoa": 0.82, "Savona": 0.8, "Nice": 0.8}.get(t["name"], 1.0)
    w["towns"] = {t["name"]: t for t in towns}
    passes = []
    for name, lon, lat, m in PASSES:
        x, y = km_of(lon, lat)
        if name == "Giovi":
            x, y = sites.GIOVI_AT     # where the close-up's road crosses the saddle
        passes.append(dict(name=name, x=x, y=y, m=m, real=km_of(lon, lat)))
    w["passes"] = {p["name"]: p for p in passes}
    build_roads(w)
    return w


def build_roads(w):
    T_ = w["towns"]
    P_ = w["passes"]

    def C(c, r):
        return centre(c, r)

    def at(name):
        return (T_[name]["x"], T_[name]["y"])

    # Every road ends at a town's site inside its hex. Round Genoa the lines are the close-up's (sites.ROAD_*): the
    # roads meet at the centre of Genoa's hex, behind the town, and a short gate road leads down into it.
    roads = [
        dict(cls=3, pts=sites.ROAD_GIOVI + [at("Serravalle"), (258, 272), C(9, 10), (275, 248), at("Pavia")]),
        dict(cls=3, pts=[at("Turin"), (190, 244), at("Asti"), at("Alessandria"), C(9, 10), (294, 256), at("Piacenza"),
                         (344, 266), at("Parma"), (400, 288), (430, 296)]),
        dict(cls=2, pts=sites.ROAD_WEST),                     # from Savona's east side
        dict(cls=2, pts=sites.ROAD_EAST, cut=sites.EAST_END),
        dict(cls=2, pts=sites.ROAD_SPUR),                     # down to Chiavari
        dict(cls=2, pts=sites.ROAD_GATE),                     # to Genoa's north gate
        dict(cls=2, pts=[at("Turin"), (152, 240.5), (134, 242.6), (122, 241), at("Susa"), (P_["Mont Cenis"]["x"], P_["Mont Cenis"]["y"]), (90, 221), (60, 216)]),
        dict(cls=2, pts=[at("Cuneo"), (157, 341), (P_["Col di Tenda"]["x"], P_["Col di Tenda"]["y"]),
                         (148, 368), (140, 384), at("Nice")]),
        dict(cls=2, pts=[at("Pisa"), (398, 396), (430, 394)]),
    ]
    for rd in roads:
        pts = chaikin(rd["pts"], 3)
        if "cut" in rd:               # the line goes on in the close-up; the map's road stops here
            pts = pts[:min(range(len(pts)), key=lambda i: math.dist(pts[i], rd["cut"])) + 1]
        rd["pts"] = resample(pts, 0.8)
    w["roads"] = roads
    rdg = Grid(3.0)
    for rd in roads:
        for p in rd["pts"]:
            rdg.add(p[0], p[1], rd["cls"])
    w["rdgrid"] = rdg
    # bridges: where a road crosses a river or stream
    bridges = []
    waters = [(rv["pts"], rv["cls"]) for rv in w["rivers"]] + [(st, 0) for st in w["streams"]]
    for rd in roads:
        rp = rd["pts"]
        for wp, wc in waters:
            for i in range(len(rp) - 1):
                for j in range(len(wp) - 1):
                    q = seg_x(rp[i], rp[i + 1], wp[j], wp[j + 1])
                    if q:
                        dx, dy = wp[j + 1][0] - wp[j][0], wp[j + 1][1] - wp[j][1]
                        if all(math.dist(q, (b["x"], b["y"])) > 3 for b in bridges):
                            bridges.append(dict(x=q[0], y=q[1], cls=wc, river_dir=(dx, dy),
                                                road_dir=(rp[i + 1][0] - rp[i][0], rp[i + 1][1] - rp[i][1])))
    w["bridges"] = bridges


def seg_x(p1, p2, p3, p4):
    d = (p2[0] - p1[0]) * (p4[1] - p3[1]) - (p2[1] - p1[1]) * (p4[0] - p3[0])
    if abs(d) < 1e-9:
        return None
    t = ((p3[0] - p1[0]) * (p4[1] - p3[1]) - (p3[1] - p1[1]) * (p4[0] - p3[0])) / d
    u = ((p3[0] - p1[0]) * (p2[1] - p1[1]) - (p3[1] - p1[1]) * (p2[0] - p1[0])) / d
    if 0 <= t <= 1 and 0 <= u <= 1:
        return (p1[0] + t * (p2[0] - p1[0]), p1[1] + t * (p2[1] - p1[1]))
    return None


WORLD = build_world()


# ---------------------------------------------------------------- noise and fields on a 1 km grid
def _lattice(seed):
    rnd = random.Random(seed)
    return [rnd.random() for _ in range(4096)]


_LAT = {}


def vnoise(x, y, scale, seed):
    lat = _LAT.get(seed)
    if lat is None:
        lat = _LAT[seed] = _lattice(seed)
    x /= scale
    y /= scale
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)

    def g(i, j):
        return lat[((i * 73856093) ^ (j * 19349663)) & 4095]
    a = g(xi, yi) + (g(xi + 1, yi) - g(xi, yi)) * fx
    b = g(xi, yi + 1) + (g(xi + 1, yi + 1) - g(xi, yi + 1)) * fx
    return a + (b - a) * fy


FW_KM, FH_KM = 345 + 4, int(720 / (60 / R_KM * TILT)) + 4


class Fields:
    def __init__(self, world):
        self.w, self.h = FW_KM, FH_KM
        self.x0, self.y0 = X0 - 2, Y0 - 2
        n = self.w * self.h
        self.land = [0.0] * n
        self.height = [0.0] * n
        self.farm = [0.0] * n
        self.grass = [0.0] * n
        self.woods = [0.0] * n
        self.rock = [0.0] * n
        self.depth = [0.0] * n
        self.cliff = [0.0] * n
        ports = [t for t in world["towns"].values() if t["port"]]
        for j in range(self.h):
            y = Y0 + j - 2
            for i in range(self.w):
                x = X0 + i - 2
                c, r = hex_of_km(x, y)
                acc = dict(l=0., m=0., ml=0., f=0., g=0., wd=0., rk=0., dp=0., ws=0., wl=0., wsea=0.)
                for cc in range(c - 2, c + 3):
                    for rr in range(r - 2, r + 3):
                        hx = HEX.get((cc, rr))
                        if hx is None:
                            continue
                        px, py = centre(cc, rr)
                        d = math.hypot(px - x, py - y) / W_KM
                        if d >= 1.25:
                            continue
                        wk = (1 - d / 1.25) ** 2
                        wl = max(0.0, 1 - d / 0.85) ** 2
                        acc["ws"] += wk
                        acc["wl"] += wl
                        if hx.get("land"):
                            acc["l"] += wl
                            m = float(hx.get("m", 0))
                            acc["m"] += wk * m
                            acc["ml"] += wk
                            cv = hx["cover"]
                            if cv == 0:
                                acc["f"] += wk
                            elif cv == 1:
                                acc["g"] += wk
                            elif cv == 2:
                                acc["wd"] += wk
                            else:
                                acc["rk"] += wk
                        else:
                            acc["wsea"] += wk
                            acc["dp"] += wk * {"shelf": 0.3, "sea": 0.62, "deep": 1.0}.get(hx["water"], 0.6)
                k = j * self.w + i
                lv = acc["l"] / acc["wl"] if acc["wl"] else 0.0
                # the coast: hex land blended, then pushed in and out by two octaves of noise (coves and headlands)
                nz = (vnoise(x, y, 15.0, 10) - 0.5) * 0.7 + (vnoise(x, y, 7.0, 11) - 0.5) * 0.6 + (vnoise(x, y, 2.8, 12) - 0.5) * 0.3
                self.land[k] = lv + nz * max(0.0, 1 - abs(lv - 0.5) * 1.3)
                self.height[k] = acc["m"] / acc["ws"] if acc["ws"] else 0.0
                ml = acc["ml"] or 1e-9
                self.farm[k] = acc["f"] / ml
                self.grass[k] = acc["g"] / ml
                self.woods[k] = acc["wd"] / ml
                self.rock[k] = acc["rk"] / ml
                self.depth[k] = acc["dp"] / acc["wsea"] if acc["wsea"] else 0.3
                mland = acc["m"] / ml
                stretch = vnoise(x, y, 6.5, 21)
                self.cliff[k] = smoothstep(300, 750, mland) * smoothstep(0.47, 0.6, stretch)
        # The first coast line. Each port's real position, carried to the nearest coast, gets a low bulge of land.
        # (The towns themselves are sited later, inside their hexes: sites.place_sites; t is a copy here.)
        ports = [dict(x=t["real"][0], y=t["real"][1], town=t) for t in ports]
        for t in ports:
            best = None
            for a in range(0, 360, 6):
                ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
                d = 0.0
                while d < 26:
                    if self.at(self.land, t["x"] + ca * d, t["y"] + sa * d) < 0.5:
                        if best is None or d < best[0]:
                            best = (d, ca, sa)
                        break
                    d += 0.4
            if best and best[0] > 1.5:
                d, ca, sa = best
                t["x"] += ca * (d - 1.6)
                t["y"] += sa * (d - 1.6)
            t["town"]["coast_point"] = (t["x"], t["y"])     # where the frame drew the port before the one-hex rule
        for j in range(self.h):
            for i in range(self.w):
                x, y = X0 + i - 2, Y0 + j - 2
                k = j * self.w + i
                for t in ports:
                    dd = math.hypot(t["x"] - x, t["y"] - y)
                    if dd < 8:
                        self.land[k] += 0.35 * math.exp(-(dd / 2.4) ** 2)
        for t in ports:  # harbours and port towns: low shore, no cliff
            for j in range(self.h):
                for i in range(self.w):
                    x, y = X0 + i - 2, Y0 + j - 2
                    dd = math.hypot(t["x"] - x, t["y"] - y)
                    if dd < 9:
                        k = j * self.w + i
                        self.cliff[k] *= smoothstep(4, 9, dd)
        self.land0 = list(self.land)      # the coast before the harbour coves (sites.apply_coves)

    def low_shore(self, towns):
        """Harbours and port towns stand on a low shore: no cliff near a port's site."""
        for t in towns:
            if not t["port"]:
                continue
            for j in range(self.h):
                for i in range(self.w):
                    dd = math.hypot(t["x"] - (X0 + i - 2), t["y"] - (Y0 + j - 2))
                    if dd < 9:
                        self.cliff[j * self.w + i] *= smoothstep(4, 9, dd)

    def at(self, arr, x, y):
        fx, fy = x - X0 + 2, y - Y0 + 2
        i, j = int(math.floor(fx)), int(math.floor(fy))
        if i < 0 or j < 0 or i >= self.w - 1 or j >= self.h - 1:
            i = min(max(i, 0), self.w - 2)
            j = min(max(j, 0), self.h - 2)
        tx, ty = fx - i, fy - j
        tx, ty = min(max(tx, 0), 1), min(max(ty, 0), 1)
        k = j * self.w + i
        a = arr[k] + (arr[k + 1] - arr[k]) * tx
        b = arr[k + self.w] + (arr[k + self.w + 1] - arr[k + self.w]) * tx
        return a + (b - a) * ty

    def is_land(self, x, y, margin=0.0):
        return self.at(self.land, x, y) > 0.5 + margin
