"""Throw-away prototype for docs/design/map/04-wfc-model.md. Not game code.

Runs the proposed pipeline on the prototype region (western Alps, Po plain, Ligurian coast):
  0 fixed geography -> 1 relief and crests -> 2 water on the edges -> 3 ground cover (WFC) -> 4 settlements -> 5 roads
  -> 6 edge sockets, checked.
Usage:  python proto.py [SUB] [SEED] [--nodraw]     SUB = hexes per game hex along one axis (1 = today's grid).
Writes 04_prototype_steps[_fine].png next to the design doc and prints the numbers the doc quotes.
"""
import heapq
import json
import math
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
GEO = os.path.join(ROOT, "godot", "data", "geography")
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
SUB = int(ARGS[0]) if ARGS else 1
SEED = int(ARGS[1]) if len(ARGS) > 1 else 1480
DRAW = "--nodraw" not in sys.argv

# ---------------------------------------------------------------------------------------------------------------
# grid and projection (the game's own: odd rows shifted half a hex, pointy-top)
# ---------------------------------------------------------------------------------------------------------------
proj = json.load(open(os.path.join(GEO, "projection.json")))
COL_DEG = proj["col_deg"] / SUB
ROW_DEG = COL_DEG * 0.8660254
LON_A, LON_B, LAT_A, LAT_B = 5.7, 11.3, 43.25, 47.15


def merc(lat):
    return math.degrees(math.log(math.tan(math.pi / 4 + math.radians(lat) / 2)))


def inv_merc(y):
    return math.degrees(2 * math.atan(math.exp(math.radians(y))) - math.pi / 2)


Y_TOP = merc(LAT_B)
COLS = int(math.ceil((LON_B - LON_A) / COL_DEG))
ROWS = int(math.ceil((Y_TOP - merc(LAT_A)) / ROW_DEG))
CELLS = [(c, r) for r in range(ROWS) for c in range(COLS)]
CELLSET = set(CELLS)
EVEN = [(1, 0), (0, -1), (-1, -1), (-1, 0), (-1, 1), (0, 1)]      # E NE NW W SW SE
ODD = [(1, 0), (1, -1), (0, -1), (-1, 0), (0, 1), (1, 1)]


def nbr(p, e):
    d = (ODD if p[1] & 1 else EVEN)[e]
    return (p[0] + d[0], p[1] + d[1])


def nbrs(p):
    return [nbr(p, e) for e in range(6)]


def centre(p):                                   # hex-grid units: 1 between columns, 0.866 between rows
    return (p[0] + 0.5 * (p[1] & 1) + 0.5, (p[1] + 0.5) * 0.8660254)


def unit(lon, lat):
    return ((lon - LON_A) / COL_DEG, (Y_TOP - merc(lat)) / COL_DEG)


def lonlat(p):
    x, y = centre(p)
    return (LON_A + x * COL_DEG, inv_merc(Y_TOP - y * COL_DEG))


def hex_at(x, y):                                # nearest centre (exact for a hex grid)
    r0 = int(math.floor(y / 0.8660254))
    best, bd = None, 1e9
    for r in (r0 - 1, r0, r0 + 1):
        c0 = int(math.floor(x - 0.5 * (r & 1)))
        for c in (c0 - 1, c0, c0 + 1):
            cx, cy = centre((c, r))
            d = (cx - x) ** 2 + (cy - y) ** 2
            if d < bd:
                best, bd = (c, r), d
    return best


def ekey(a, b):
    return (a, b) if a < b else (b, a)


def edge_of(a, b):
    return nbrs(a).index(b)


def hashf(*k):                                   # deterministic 0..1 from integers, no global state
    h = 2166136261
    for v in k:
        h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
        h ^= h >> 13
        h = (h * 0x5bd1e995) & 0xFFFFFFFF
        h ^= h >> 15
    return h / 4294967296.0


def noise(x, y, seed):                           # smooth value noise from the integer hash
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hashf(xi, yi, seed), hashf(xi + 1, yi, seed)
    c, d = hashf(xi, yi + 1, seed), hashf(xi + 1, yi + 1, seed)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy


# ---------------------------------------------------------------------------------------------------------------
# step 1: fixed geography. The repo data, plus prototype-only additions the real data set would need.
# ---------------------------------------------------------------------------------------------------------------
land_json = json.load(open(os.path.join(GEO, "land.json")))
shapes = json.load(open(os.path.join(GEO, "terrain_shapes.json")))
MOUNT = [(m["line"], m["height"]) for m in shapes["mountains"]]
MOUNT += [([[7.0, 44.15], [8.0, 44.3], [9.0, 44.5]], 0.5),          # added: Ligurian Alps and Apennines
          ([[7.1, 46.35], [8.4, 46.62]], 0.9)]                      # added: Bernese Alps (north wall of the Valais)
HILLS = [[[7.95, 44.7], [8.5, 44.95]], [[8.9, 45.85], [10.6, 45.75]]]   # added: Monferrato; the lake foothills
RIVERS = [  # name, class, points source -> mouth. Po, Rhone, Rhine are in the repo; the rest are added.
    ("Po", 3, [[7.1, 44.7], [7.69, 45.07], [8.3, 45.15], [9.0, 45.1], [9.7, 45.1], [10.0, 45.05], [11.6, 44.95]]),
    ("Rhone", 2, [[8.4, 46.5], [7.0, 46.2], [6.15, 46.2], [4.84, 45.76]]),
    ("Rhine", 2, [[9.0, 46.6], [9.4, 47.6]]),
    ("Ticino", 2, [[8.6, 46.5], [8.85, 46.15], [8.6, 45.8], [8.9, 45.4], [9.2, 45.15]]),
    ("Adda", 2, [[10.3, 46.45], [9.6, 46.15], [9.35, 46.1], [9.4, 45.85], [9.55, 45.5], [9.85, 45.13]]),
    ("Dora Baltea", 2, [[6.95, 45.8], [7.3, 45.73], [7.85, 45.5], [8.0, 45.18]]),
    ("Dora Riparia", 2, [[6.9, 45.1], [7.3, 45.1], [7.69, 45.07]]),
    ("Tanaro", 2, [[7.75, 44.2], [8.05, 44.7], [8.2, 44.9], [8.75, 45.0]]),
]
LAKES = [("Maggiore", [[8.8, 46.15], [8.6, 45.8]]), ("Como", [[9.35, 46.15], [9.3, 45.9]]),
         ("Geneva", [[6.9, 46.4], [6.2, 46.25]])]
CITIES = [(c["name"], c["lon"], c["lat"], c["size"]) for c in json.load(open(os.path.join(GEO, "cities.json")))["cities"]]
CITIES += [("Pavia", 9.16, 45.19, 20), ("Como", 9.08, 45.81, 12), ("Novara", 8.62, 45.45, 10), ("Asti", 8.2, 44.9, 12),
           ("Savona", 8.48, 44.31, 10), ("Piacenza", 9.7, 45.05, 15), ("Cremona", 10.02, 45.13, 15),
           ("Bergamo", 9.67, 45.7, 12), ("Brescia", 10.22, 45.54, 20), ("Aosta", 7.32, 45.74, 5),
           ("Alessandria", 8.61, 44.91, 10), ("Nice", 7.26, 43.7, 8), ("Geneva", 6.14, 46.2, 12),
           ("Parma", 10.33, 44.8, 15), ("Bellinzona", 9.02, 46.19, 4), ("Susa", 7.05, 45.14, 3),
           ("Cuneo", 7.55, 44.39, 6), ("Sion", 7.36, 46.23, 4), ("Chur", 9.53, 46.85, 4), ("Lucerne", 8.3, 47.05, 6)]
PASSES = [(p["name"], p["lon"], p["lat"]) for p in json.load(open(os.path.join(GEO, "passes.json")))["passes"]]
PASSES += [("Giovi", 8.93, 44.55), ("Tenda", 7.56, 44.15), ("Splugen", 9.33, 46.5), ("Cadibona", 8.38, 44.33)]


def inside(pt, poly):
    x, y = pt
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


t0 = time.perf_counter()
POLY = [m["points"] for m in land_json["landmasses"]] + [m["points"] for m in land_json["islands"]]
SEAS = [m["points"] for m in land_json["seas"]]
land = set()
for p in CELLS:
    ll = lonlat(p)
    if any(inside(ll, q) for q in POLY) and not any(inside(ll, q) for q in SEAS):
        land.add(p)
city_at = {}
for name, lon, lat, size in sorted(CITIES, key=lambda c: -c[3]):
    h = hex_at(*unit(lon, lat))
    if h in CELLSET:
        land.add(h)                              # a city point is always land (the game's rule)
        city_at.setdefault(h, []).append((name, size))
sea = CELLSET - land
coastal = {p for p in land if any(n in sea for n in nbrs(p))}
border = {p for p in land if any(n not in CELLSET for n in nbrs(p))}


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0 if L == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def line_dist(lon, lat, line):
    return min(seg_dist(lon, lat, *line[i], *line[i + 1]) for i in range(len(line) - 1))


# ---------------------------------------------------------------------------------------------------------------
# step 2: relief. Height from the mountain and hill lines plus noise; crest edges where a mountain line cuts
# between two hex centres; named passes open the nearest crest edge.
# ---------------------------------------------------------------------------------------------------------------
height = {}
for p in land:
    lon, lat = lonlat(p)
    h = 0.0
    for line, top in MOUNT:
        h = max(h, top * (1 - line_dist(lon, lat, line) / 0.9))
    for line in HILLS:
        h = max(h, 0.34 * (1 - line_dist(lon, lat, line) / 0.5))
    x, y = centre(p)
    h += 0.10 * (noise(x / (2.5 * SUB), y / (2.5 * SUB), SEED) - 0.5) + 0.05 * (noise(x / SUB * 1.7, y / SUB * 1.7, SEED + 1) - 0.5)
    height[p] = max(0.0, h)


def relief_of(h):
    return 0 if h < 0.18 else 1 if h < 0.42 else 2 if h < 0.72 else 3


relief = {p: relief_of(height[p]) for p in land}


def cross(x0, y0, x1, y1, ax, ay, bx, by):
    den = (x1 - x0) * (by - ay) - (y1 - y0) * (bx - ax)
    if abs(den) < 1e-12:
        return False
    t = ((ax - x0) * (by - ay) - (ay - y0) * (bx - ax)) / den
    u = ((ax - x0) * (y1 - y0) - (ay - y0) * (x1 - x0)) / den
    return 0 <= t <= 1 and 0 <= u <= 1


crest = set()
for line, top in MOUNT:
    if top < 0.5:
        continue
    pts = [unit(*q) for q in line]
    count = {}
    for a in land:
        ax, ay = centre(a)
        for b in nbrs(a):
            if b in land and a < b:
                bx, by = centre(b)
                n = sum(cross(pts[i][0] + 1.3e-6, pts[i][1] + 2.1e-6, pts[i + 1][0] + 1.3e-6, pts[i + 1][1] + 2.1e-6,
                              ax, ay, bx, by) for i in range(len(pts) - 1))
                if n:
                    count[(a, b)] = n
    crest |= {k for k, n in count.items() if n % 2}
passes = {}
for name, lon, lat in PASSES:
    px, py = unit(lon, lat)
    ranked = []
    for (a, b) in crest:
        if (a, b) in passes:
            continue
        (ax, ay), (bx, by) = centre(a), centre(b)
        ranked.append((math.hypot((ax + bx) / 2 - px, (ay + by) / 2 - py), (a, b)))
    ranked.sort()
    if ranked and ranked[0][0] <= 1.5 * SUB:
        passes[ranked[0][1]] = name
t_relief = time.perf_counter() - t0

# ---------------------------------------------------------------------------------------------------------------
# step 3: water. Rivers run ALONG hex edges, from corner to corner (thread 2's model). The real rivers are snapped
# to the corner graph first and own their course; every other corner drains downhill (priority flood from the
# sea, the map edge and the real rivers), never along a crest. Corners that collect enough water start streams.
# ---------------------------------------------------------------------------------------------------------------
t0 = time.perf_counter()
RC = 0.57735027
UY = 0.28867513


def ckey(x, y):
    return (int(round(x * 2)), int(round(y / UY - 0.5)))


def cxy(k):
    return (k[0] / 2.0, (k[1] + 0.5) * UY)


def hex_corner(p, i):                            # corner i at screen angle 60i - 30
    x, y = centre(p)
    a = math.radians(60 * i - 30)
    return ckey(x + RC * math.cos(a), y + RC * math.sin(a))


edge_ends = {}           # edge -> its two corners
cadj = {}                # corner -> [(corner, edge)]
chex = {}                # corner -> the grid hexes that touch it
for p in CELLS:
    for i in range(6):
        chex.setdefault(hex_corner(p, i), []).append(p)
    for e in range(6):
        k = ekey(p, nbr(p, e))
        if k not in edge_ends:
            c1, c2 = hex_corner(p, (-e) % 6), hex_corner(p, (1 - e) % 6)
            edge_ends[k] = (c1, c2)
            cadj.setdefault(c1, []).append((c2, k))
            cadj.setdefault(c2, []).append((c1, k))
sea_corner = {c for c, hs in chex.items() if any(h in sea for h in hs)}
off_corner = {c for c, hs in chex.items() if len(hs) < 3} - sea_corner
cheight = {c: (sum(height[h] for h in hs if h in land) / max(1, sum(1 for h in hs if h in land))) for c, hs in chex.items()}


def capable(k):                                  # a river may run along this edge: no sea on either side
    return k[0] not in sea and k[1] not in sea


def poly_dist(x, y, pts):
    return min(seg_dist(x, y, *pts[i], *pts[i + 1]) for i in range(len(pts) - 1))


riv = {}                 # edge -> {"from", "to", "name", "cls"}
cdown = {}               # corner -> (next corner, edge)
river_corner = set()
gorges, extended = [], []


def lay(path, name):
    for a, b in zip(path, path[1:]):
        k = [kk for n, kk in cadj[a] if n == b][0]
        if k in crest:
            crest.discard(k)
            passes.pop(k, None)
            gorges.append((name, k))
        riv[k] = {"from": a, "to": b, "name": name, "cls": 1}
        cdown[a] = (b, k)
    river_corner.update(path)


for name, _, points in RIVERS:
    pts = [unit(*q) for q in points]
    free = [c for c in cadj if c not in sea_corner and c not in river_corner]
    start = min(free, key=lambda c: (math.hypot(cxy(c)[0] - pts[0][0], cxy(c)[1] - pts[0][1]), c))
    best = {start: 0.0}
    came = {}
    hp = [(0.0, start)]
    end = None
    final = {}
    while hp:
        cost, c = heapq.heappop(hp)
        if c == "END":
            end = final["c"]
            break
        if cost > best[c]:
            continue
        stop = c != start and (c in sea_corner or c in off_corner or c in river_corner)
        if stop or c != start:                   # a river may also just end here; far from the real mouth costs a lot
            x, y = cxy(c)
            fin = cost + 6.0 * math.hypot(x - pts[-1][0], y - pts[-1][1]) + (0 if stop else 3.0)
            if fin < best.get("END", 1e18):
                best["END"] = fin
                final["c"] = c
                heapq.heappush(hp, (fin, "END"))
        if stop:
            continue
        for n, k in cadj[c]:
            if not capable(k) or k in riv:
                continue
            (x1, y1), (x2, y2) = cxy(c), cxy(n)
            step = RC * (1 + 4 * poly_dist((x1 + x2) / 2, (y1 + y2) / 2, pts)) + (6 if k in crest else 0)
            if cost + step < best.get(n, 1e18):
                best[n] = cost + step
                came[n] = c
                heapq.heappush(hp, (cost + step, n))
    path = [end]
    while path[-1] in came:
        path.append(came[path[-1]])
    path.reverse()
    last = path[-1]
    if not (last in sea_corner or last in off_corner or last in river_corner):
        # the data's river stops inland: extend it to the nearest water
        seen_, queue_, goal = {last: None}, [last], None
        while queue_ and goal is None:
            q = queue_.pop(0)
            for n, k in cadj[q]:
                if n in seen_ or n in path or not capable(k) or k in crest or k in riv:
                    continue
                seen_[n] = q
                if n in sea_corner or n in off_corner or n in river_corner:
                    goal = n
                    break
                queue_.append(n)
        tail = []
        while goal is not None and goal != last:
            tail.append(goal)
            goal = seen_[goal]
        path += tail[::-1]
        extended.append((name, len(tail)))
    lay(path, name)

level = {}
heap = []
for c in cadj:
    if c in sea_corner or c in off_corner:
        level[c] = 0.0 if c in sea_corner else cheight[c]
        heapq.heappush(heap, (level[c], c))
    elif c in river_corner:
        level[c] = min(cheight[c], 0.05)
        heapq.heappush(heap, (level[c], c))
order = []
while heap:
    lvl, c = heapq.heappop(heap)
    order.append(c)
    for n, k in cadj[c]:
        if n in level or not capable(k) or k in crest or k in riv:
            continue
        level[n] = max(cheight[n], lvl + 1e-4)
        cdown[n] = (c, k)
        heapq.heappush(heap, (level[n], n))
undrained = [c for c in cadj if c not in level]
acc = {c: 0.0 for c in cadj}
for c, hs in chex.items():
    for h in hs:
        if h in land:
            acc[c] += (1.0 + 1.5 * relief[h]) / 6.0          # each hex shares its rain among its six corners
indeg = {c: 0 for c in cadj}
for c, (n, k) in cdown.items():
    indeg[n] += 1
todo = sorted(c for c in cadj if indeg[c] == 0)
while todo:
    c = todo.pop()
    if c in cdown:
        n = cdown[c][0]
        acc[n] += acc[c]
        indeg[n] -= 1
        if indeg[n] == 0:
            todo.append(n)
T1, T2, T3 = 4.0 * SUB * SUB, 7.0 * SUB * SUB, 30.0 * SUB * SUB
for c in sorted(cdown):
    n, k = cdown[c]
    if k not in riv and acc[c] >= T1 and c not in sea_corner:
        riv[k] = {"from": c, "to": n, "name": "", "cls": 1}
        river_corner.update((c, n))
for k, r in riv.items():
    a = acc[r["from"]]
    r["cls"] = 3 if a >= T3 else 2 if a >= T2 else 1
lake = set()
for name, pts in LAKES:
    lp = [unit(*q) for q in pts]
    for k, r in riv.items():
        (x1, y1), (x2, y2) = cxy(r["from"]), cxy(r["to"])
        if poly_dist((x1 + x2) / 2, (y1 + y2) / 2, lp) <= 0.45:
            lake.add(k)
riverside = {}
for k, r in riv.items():
    for h in k:
        if h in land:
            riverside[h] = max(riverside.get(h, 0), r["cls"])
confluence = {h for c in river_corner if sum(1 for n, k in cadj[c] if k in riv) == 3 for h in chex[c] if h in land}
lakeside = {h for k in lake for h in k if h in land}
# a mountain hex beside a real river is a valley floor: one relief class lower than its walls
valley = {p for p in riverside if riverside[p] >= 2 and relief[p] >= 2}
for p in valley:
    relief[p] -= 1
t_water = time.perf_counter() - t0

# ---------------------------------------------------------------------------------------------------------------
# step 4: ground cover by WFC (cell domains from relief, water and climate; forbidden pairs; real backtracking)
# ---------------------------------------------------------------------------------------------------------------
t0 = time.perf_counter()
COVER = ["farmland", "grass", "wood", "marsh", "downs", "woodhill", "alp", "rock", "snow", "meadow"]
CI = {c: i for i, c in enumerate(COVER)}
FORBID = [("snow", "farmland"), ("snow", "grass"), ("snow", "marsh"), ("snow", "wood"), ("snow", "downs"),
          ("rock", "farmland"), ("rock", "marsh"), ("alp", "marsh"), ("marsh", "downs"), ("marsh", "woodhill"),
          ("snow", "woodhill"), ("rock", "grass")]
compat = [(1 << len(COVER)) - 1] * len(COVER)
for a, b in FORBID:
    compat[CI[a]] &= ~(1 << CI[b])
    compat[CI[b]] &= ~(1 << CI[a])


def prior(p):
    r = relief[p]
    wet = riverside.get(p, 0)
    if p in valley:
        return {"meadow": 1.0, "wood": 0.35, "farmland": 0.25}
    if r == 0:
        w = {"farmland": 0.7 if wet else 0.45, "grass": 0.3, "wood": 0.22}
        if wet >= 2:
            w["marsh"] = 0.10
        return w
    if r == 1:
        return {"downs": 0.5, "woodhill": 0.5, "wood": 0.15, "grass": 0.1}
    if r == 2:
        return {"alp": 0.7, "rock": 0.3, "woodhill": 0.15}
    return {"rock": 0.5, "snow": 0.6 if lonlat(p)[1] > 45.3 else 0.2}


def wfc_cover(seed, relax):
    rng = random.Random(seed)
    cells = sorted(land)
    pri = {p: prior(p) for p in cells}
    dom = {p: sum(1 << CI[t] for t in pri[p]) for p in cells}
    near = {p: [n for n in nbrs(p) if n in land] for p in cells}
    trail = []                                   # (cell, old mask): undo log
    done = {}
    stats = {"wipeouts": 0, "backtracks": 0, "relaxed": 0}

    def support(mask):
        got = 0
        i = 0
        while mask:
            if mask & 1:
                got |= compat[i]
            mask >>= 1
            i += 1
        return got

    def propagate(start):
        queue = list(start)
        while queue:
            p = queue.pop()
            allow = support(dom[p])
            for n in near[p]:
                nd = dom[n] & allow
                if nd != dom[n]:
                    if nd == 0:
                        stats["wipeouts"] += 1
                        if relax:
                            stats["relaxed"] += 1
                            continue
                        return False
                    trail.append((n, dom[n]))
                    dom[n] = nd
                    queue.append(n)
        return True

    if not propagate(cells):                     # the inputs themselves contradict: report, then relax
        relax = True
        propagate(cells)
    order_ = sorted(cells, key=lambda p: hashf(p[0], p[1], seed))   # a fixed tie-break, independent of dict order
    stack = []                                   # decisions: (cell, tried mask, trail length)
    while len(done) < len(cells):
        p = min((q for q in order_ if q not in done), key=lambda q: bin(dom[q]).count("1"))
        tried = 0
        while True:
            opts = [i for i in range(len(COVER)) if dom[p] >> i & 1 and not tried >> i & 1]
            if not opts:                         # nothing left here: undo the previous decision
                stats["backtracks"] += 1
                if not stack or stats["backtracks"] > 200:
                    relax = True
                    opts = [i for i in range(len(COVER)) if pri[p].get(COVER[i])] or [0]
                else:
                    q, qtried, mark = stack.pop()
                    while len(trail) > mark:
                        c, old = trail.pop()
                        dom[c] = old
                    del done[q]
                    p, tried = q, qtried
                    continue
            weights = []
            for i in opts:
                same = sum(1 for n in near[p] if done.get(n) == i)
                weights.append(pri[p].get(COVER[i], 0.01) * (1 + 1.6 * same))
            pick = rng.choices(opts, weights)[0]
            mark = len(trail)
            trail.append((p, dom[p]))
            dom[p] = 1 << pick
            done[p] = pick
            if propagate([p]):
                stack.append((p, tried | 1 << pick, mark))
                break
            while len(trail) > mark:
                c, old = trail.pop()
                dom[c] = old
            del done[p]
            tried |= 1 << pick
    bad = sum(1 for p in cells for n in near[p] if p < n and not compat[done[p]] >> done[n] & 1)
    return {p: COVER[i] for p, i in done.items()}, stats, bad


cover, wstats, wbad = wfc_cover(SEED, relax=False)
_, rstats, rbad = wfc_cover(SEED, relax=True)
t_cover = time.perf_counter() - t0

# ---------------------------------------------------------------------------------------------------------------
# step 5: settlements. Real cities first (one per hex, the biggest wins); then villages by score with spacing.
# ---------------------------------------------------------------------------------------------------------------
t0 = time.perf_counter()
settle = {}                                      # hex -> (name, size)
merged = 0
for h, lst in city_at.items():
    settle[h] = lst[0]
    merged += len(lst) - 1


def hexdist(a, b):
    def cube(p):
        x = p[0] - (p[1] - (p[1] & 1)) // 2
        return x, p[1], -x - p[1]
    ca, cb = cube(a), cube(b)
    return max(abs(ca[i] - cb[i]) for i in range(3))


def score(p):
    s = 3 - 1.5 * relief[p] + (2 if p in riverside else 0) + (1 if p in coastal else 0) + (1 if p in lakeside else 0)
    s += 1.5 if p in confluence else 0
    return s + 0.5 * hashf(p[0], p[1], SEED + 7)


GAP = 2 if SUB == 1 else 3
want = len(land) // (9 * SUB)
for p in sorted(land, key=lambda q: (-score(q), q)):
    if len(settle) >= len(city_at) + want:
        break
    if relief[p] < 2 and all(hexdist(p, q) >= GAP for q in settle):
        settle[p] = ("", 1)

# ---------------------------------------------------------------------------------------------------------------
# step 6: roads. Roads run from hex centre to hex centre and cross edges. Cheapest paths on a cost field: crests
# block, passes cost extra, crossing a river edge costs a ford, a bridge or a ferry. Every pass pulls a road.
# ---------------------------------------------------------------------------------------------------------------
road = {}                                        # edge -> times used
STEP = {0: 2, 1: 3, 2: 7, 3: 12}
EXTRA = {"wood": 1, "woodhill": 1, "marsh": 3, "snow": 4}
WET = {1: 1, 2: 3, 3: 6}
FORCE = [False]


def step_cost(a, b):
    k = ekey(a, b)
    if k in road:
        return 1
    c = STEP[relief[b]] + EXTRA.get(cover[b], 0)
    if k in crest and k not in passes:
        if not FORCE[0]:
            return None
        c += 40
    if k in passes:
        c += 4
    if k in riv:
        w = 8 if k in lake else WET[riv[k]["cls"]]
        c += w // 2 if (a in settle or b in settle) else w
    return c


def connect(start, goals, limit=10 ** 9):
    best = {start: 0}
    came = {}
    hp = [(0, start)]
    while hp:
        c, p = heapq.heappop(hp)
        if c > best[p]:
            continue
        if p in goals and p != start:
            path = [p]
            while path[-1] in came:
                path.append(came[path[-1]])
            return path[::-1], c
        for n in nbrs(p):
            if n in land:
                s = step_cost(p, n)
                if s is not None and c + s < best.get(n, limit):
                    best[n] = c + s
                    came[n] = p
                    heapq.heappush(hp, (c + s, n))
    return None, None


def add(path):
    for a, b in zip(path, path[1:]):
        road[ekey(a, b)] = road.get(ekey(a, b), 0) + 1


capital = max(settle, key=lambda p: (settle[p][1], p))
network = {capital}
unreached = 0
new_passes = 0
for p in sorted(settle, key=lambda q: (hexdist(q, capital), q)):
    if p in network:
        continue
    path, _ = connect(p, network)
    if not path:
        FORCE[0] = True                          # shut in by crests: open one more pass on the cheapest crossing
        path, _ = connect(p, network)
        FORCE[0] = False
        for a, b in zip(path or [], (path or [])[1:]):
            if ekey(a, b) in crest and ekey(a, b) not in passes:
                passes[ekey(a, b)] = "(new pass)"
                new_passes += 1
    if path:
        add(path)
        network |= set(path)
    else:
        unreached += 1
pass_roads = 0
for (a, b), name in sorted(passes.items()):
    if (a, b) in road:
        continue
    pa, ca = connect(a, network - {a}, 60) if a not in network else ([a], 0)
    pb, cb = connect(b, network - {b}, 60) if b not in network else ([b], 0)
    if pa and pb:
        add(pa[::-1] + pb)
        network |= set(pa) | set(pb)
        pass_roads += 1
road_hex = {p for k in road for p in k}
rlevel = {k: 1 if n == 1 else 2 if n <= 3 else 3 for k, n in road.items()}
crossing = {}
for k in road:
    town = max(settle.get(k[0], ("", 0))[1], settle.get(k[1], ("", 0))[1])
    if k in passes:
        crossing[k] = "pass road"
    elif k in lake:
        crossing[k] = "ferry"
    elif k in riv:
        c = riv[k]["cls"]
        if c == 1:
            crossing[k] = "ford" if rlevel[k] == 1 else "bridge wood"
        elif c == 2:
            crossing[k] = "bridge stone" if (rlevel[k] == 3 or town >= 40) else "bridge wood"
        else:
            crossing[k] = ("bridge stone" if town >= 40 else "bridge wood") if town else "ferry"
ports = {}
for p in settle:
    seas_ = [n for n in nbrs(p) if n in sea]
    if seas_:
        ports[p] = max(seas_, key=lambda n: (sum(1 for m in nbrs(n) if m in sea or m not in CELLSET), n))
t_roads = time.perf_counter() - t0

# ---------------------------------------------------------------------------------------------------------------
# step 7: sockets. One record per edge (so two hexes can never disagree), then every hex reads its six.
#   line  (runs along the edge):   "", sea, shore, crest, pass, river1..3, lake
#   step  (relief across the edge): level, slope, scarp;  floor = a valley floor continues across
#   road  (crosses the edge):       0 none, 1 track, 2 road, 3 highway;  cross = how it gets over the line
# ---------------------------------------------------------------------------------------------------------------
t0 = time.perf_counter()
sock = {}
for k in edge_ends:
    a, b = k
    if a not in CELLSET or b not in CELLSET:
        continue
    s = {"line": "", "step": "", "floor": False, "road": 0, "cross": "", "cover": ""}
    la, lb = a in land, b in land
    if not la and not lb:
        s["line"] = "sea"
    elif la != lb:
        s["line"] = "shore"
        l_, s_ = (a, b) if la else (b, a)
        if ports.get(l_) == s_:
            s["cross"] = "quay"
    else:
        if k in passes:
            s["line"] = "pass"
        elif k in crest:
            s["line"] = "crest"
        elif k in lake:
            s["line"] = "lake"
        elif k in riv:
            s["line"] = "river%d" % riv[k]["cls"]
        d = abs(relief[b] - relief[a])
        s["step"] = "level" if d == 0 else "slope" if d == 1 else "scarp"
        s["floor"] = a in valley and b in valley and k not in crest
        s["road"] = rlevel.get(k, 0)
        s["cross"] = crossing.get(k, "")
        s["cover"] = "same" if cover[a] == cover[b] else "blend"
    sock[k] = s

errors = []
for k, r in riv.items():                         # the checks the real build would run as tests
    if k in crest or not capable(k):
        errors.append(("river on a crest or shore edge", k))
    c, hops = r["to"], 0
    while c not in sea_corner and c not in off_corner and hops < 10000:
        outs = [(n, kk) for n, kk in cadj[c] if kk in riv and riv[kk]["from"] == c]
        if len(outs) != 1:
            errors.append(("river corner with %d ways out" % len(outs), c))
            break
        c = outs[0][0]
        hops += 1
for p in road_hex:
    if p not in settle:
        deg = sum(1 for n in nbrs(p) if ekey(p, n) in road)
        if deg < 2 and not any(ekey(p, n) in passes for n in nbrs(p)):
            errors.append(("road dead end", p))
for k, s in sock.items():
    if s["road"] and s["line"] == "crest":
        errors.append(("road over a crest", k))
    if s["road"] and s["line"] in ("pass", "lake", "river1", "river2", "river3") and not s["cross"]:
        errors.append(("road over a line with no crossing", k))
mouths = sum(1 for r in riv.values() if r["to"] in sea_corner)


def canon(mask):                                 # the smallest of the six rotations
    return min(((mask << r) | (mask >> (6 - r))) & 63 for r in range(6))


LAYERS = ("water", "road", "crest", "coast")
layers = {k: set() for k in LAYERS}
combined, combined_rot = set(), set()
for p in land:
    m = dict.fromkeys(LAYERS, 0)
    for e in range(6):
        n = nbr(p, e)
        if n not in CELLSET:
            continue
        s = sock[ekey(p, n)]
        if s["line"].startswith(("river", "lake")):
            m["water"] |= 1 << e
        if s["line"] == "shore":
            m["coast"] |= 1 << e
        if s["road"]:
            m["road"] |= 1 << e
        if s["line"] in ("crest", "pass"):
            m["crest"] |= 1 << e
    for k in LAYERS:
        layers[k].add(m[k])
    combined.add((relief[p], cover[p]) + tuple(m[k] for k in LAYERS))
    best = min(range(6), key=lambda r: tuple(((m[k] << r) | (m[k] >> (6 - r))) & 63 for k in LAYERS))
    combined_rot.add((relief[p], cover[p]) + tuple(((m[k] << best) | (m[k] >> (6 - best))) & 63 for k in LAYERS))
t_sock = time.perf_counter() - t0

kinds = {}
for v in crossing.values():
    kinds[v] = kinds.get(v, 0) + 1
print("grid: SUB=%d  %d x %d = %d hexes, %d land, %d sea" % (SUB, COLS, ROWS, len(CELLS), len(land), len(sea)))
print("relief classes:", [sum(1 for p in land if relief[p] == i) for i in range(4)], "valley floor hexes:", len(valley))
print("crest edges: %d, passes: %d %s" % (len(crest) - len(passes), len(passes), sorted(set(passes.values()))))
print("gorges (river beats crest):", gorges, "| rivers extended to water:", extended, "| passes added to join pockets:", new_passes)
print("rivers: %d river edges (%d real, %d generated stream edges), by size %s, lake edges %d, mouths %d, undrained corners %d" % (
    len(riv), sum(1 for r in riv.values() if r["name"]), sum(1 for r in riv.values() if not r["name"]),
    [sum(1 for r in riv.values() if r["cls"] == i) for i in (1, 2, 3)], len(lake), mouths, len(undrained)))
print("cover WFC with backtracking:", wstats, "forbidden pairs left:", wbad)
print("cover WFC with today's relax rule:", rstats, "forbidden pairs left:", rbad)
print("cover counts:", {c: sum(1 for p in land if cover[p] == c) for c in COVER})
print("settlements: %d (%d real cities kept, %d merged into a bigger neighbour's hex, %d generated), ports %d" % (
    len(settle), len(city_at), merged, len(settle) - len(city_at), len(ports)))
print("roads: %d edges by level %s, %d unreached, %d extra pass roads, passes with a road %d of %d, crossings %s" % (
    len(road), [sum(1 for v in rlevel.values() if v == i) for i in (1, 2, 3)], unreached, pass_roads,
    sum(1 for k in passes if k in road), len(passes), kinds))
print("socket checks failed:", len(errors), errors[:8])
print("distinct edge-masks per layer (raw / up to rotation):",
      {k: (len(v), len({canon(x) for x in v})) for k, v in layers.items()})
print("distinct whole-hex combinations: %d raw, %d up to rotation, on %d land hexes" % (
    len(combined), len(combined_rot), len(land)))
print("seconds (Python): relief %.3f water %.3f cover x2 %.3f settle+roads %.3f sockets %.3f" % (
    t_relief, t_water, t_cover, t_roads, t_sock))

# ---------------------------------------------------------------------------------------------------------------
# pictures
# ---------------------------------------------------------------------------------------------------------------
if DRAW:
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    import pygame
    pygame.init()
    R = 30 if SUB == 1 else max(8, 34 // SUB)
    K = R * 1.732
    PW, PH = int((COLS + 1) * K) + 20, int((ROWS + 0.5) * R * 1.5) + 50
    surf = pygame.Surface((PW * 3, PH * 2))
    surf.fill((246, 241, 229))
    font = pygame.font.SysFont("arial", 15, bold=True)
    small = pygame.font.SysFont("arial", 11)
    INK = (40, 36, 32)
    SEA_C, LAND_C = (126, 176, 214), (226, 219, 190)
    REL_C = [(178, 208, 140), (196, 186, 120), (160, 142, 112), (236, 236, 240)]
    COV_C = {"farmland": (214, 204, 110), "grass": (150, 200, 110), "wood": (60, 140, 80), "marsh": (110, 160, 140),
             "downs": (186, 190, 110), "woodhill": (96, 140, 84), "alp": (150, 150, 128), "rock": (150, 140, 134),
             "snow": (240, 240, 246), "meadow": (170, 214, 130)}
    RIV_C, LAKE_C, CREST_C, PASS_C, ROAD_C = (40, 100, 170), (90, 160, 225), (70, 50, 40), (236, 150, 40), (120, 70, 40)

    def P(xy, ox, oy):
        return ox + 10 + xy[0] * K, oy + 36 + xy[1] * K

    def px(p, ox, oy):
        return P(centre(p), ox, oy)

    def corners(p, ox, oy):
        return [P(cxy(hex_corner(p, i)), ox, oy) for i in range(6)]

    def eline(k, ox, oy):
        c1, c2 = edge_ends[k]
        return P(cxy(c1), ox, oy), P(cxy(c2), ox, oy)

    def emid(k, ox, oy):
        p0, p1 = eline(k, ox, oy)
        return (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2

    def base(ox, oy, colour):
        for p in CELLS:
            pygame.draw.polygon(surf, colour(p), corners(p, ox, oy))
            pygame.draw.polygon(surf, (120, 120, 110), corners(p, ox, oy), 1)

    def title(ox, oy, text):
        surf.blit(font.render(text, True, INK), (ox + 10, oy + 8))

    def draw_crests(ox, oy):
        for k in crest:
            p0, p1 = eline(k, ox, oy)
            pygame.draw.line(surf, PASS_C if k in passes else CREST_C, p0, p1, max(2, R // 5))

    def draw_rivers(ox, oy):
        for k, r in sorted(riv.items()):
            p0, p1 = eline(k, ox, oy)
            if k in lake:
                pygame.draw.line(surf, LAKE_C, p0, p1, max(4, R // 2))
                pygame.draw.circle(surf, LAKE_C, p0, max(2, R // 4))
                pygame.draw.circle(surf, LAKE_C, p1, max(2, R // 4))
            else:
                w = max(1, int(R * (0.04 + 0.07 * r["cls"])))
                pygame.draw.line(surf, RIV_C, p0, p1, w)
                pygame.draw.circle(surf, RIV_C, p1, max(1, w // 2))

    def draw_roads(ox, oy):
        for k in sorted(road):
            pygame.draw.line(surf, ROAD_C, px(k[0], ox, oy), px(k[1], ox, oy), min(4, rlevel[k] + (1 if SUB == 1 else 0)))
        for k, kind in crossing.items():
            if kind == "pass road":
                continue
            m = emid(k, ox, oy)
            q = max(3, R // 6)
            if kind == "ferry":
                pygame.draw.circle(surf, (250, 250, 250), m, q)
                pygame.draw.circle(surf, INK, m, q, 1)
            else:
                col = (250, 250, 250) if kind.startswith("bridge") else (200, 190, 150)
                pygame.draw.rect(surf, col, (m[0] - q, m[1] - q, 2 * q, 2 * q))
                pygame.draw.rect(surf, INK, (m[0] - q, m[1] - q, 2 * q, 2 * q), 1)

    def draw_towns(ox, oy):
        for p, (name, size) in settle.items():
            c = px(p, ox, oy)
            r = max(2, int(R * (0.12 + 0.05 * min(4, size ** 0.5 / 2.5))))
            pygame.draw.circle(surf, (200, 50, 40) if name else (250, 250, 250), c, r)
            pygame.draw.circle(surf, INK, c, r, 1)
            if name and (SUB == 1 or size >= 10):
                surf.blit(small.render(name, True, INK), (c[0] + r + 1, c[1] - 7))

    # panel 1: what is fixed
    ox, oy = 0, 0
    surf.set_clip((0, 0, PW, PH))
    base(ox, oy, lambda p: SEA_C if p in sea else LAND_C)
    title(ox, oy, "0 Fixed from geography: coast, lines, points")
    for line, top in MOUNT:
        pygame.draw.lines(surf, (110, 70, 50), False, [P(unit(*q), ox, oy) for q in line], 3)
    for name, cls, points in RIVERS:
        pygame.draw.lines(surf, RIV_C, False, [P(unit(*q), ox, oy) for q in points], 2)
    for name, pts in LAKES:
        pygame.draw.lines(surf, LAKE_C, False, [P(unit(*q), ox, oy) for q in pts], 6)
    for name, lon, lat in PASSES:
        pygame.draw.circle(surf, PASS_C, P(unit(lon, lat), ox, oy), 4)
    for name, lon, lat, size in CITIES:
        pygame.draw.circle(surf, (200, 50, 40), P(unit(lon, lat), ox, oy), 3)
    surf.set_clip(None)
    # panel 2: relief
    ox = PW
    base(ox, oy, lambda p: SEA_C if p in sea else REL_C[relief_of(height[p])])
    title(ox, oy, "1 Relief classes, crest edges (dark), passes (orange)")
    draw_crests(ox, oy)
    # panel 3: water
    ox = 2 * PW
    base(ox, oy, lambda p: SEA_C if p in sea else REL_C[relief[p]])
    title(ox, oy, "2 Water on the edges: real rivers snapped, streams by flow")
    draw_crests(ox, oy)
    draw_rivers(ox, oy)
    # panel 4: cover
    ox, oy = 0, PH
    base(ox, oy, lambda p: SEA_C if p in sea else COV_C[cover[p]])
    title(ox, oy, "3 Ground cover solved by WFC inside each relief class")
    draw_rivers(ox, oy)
    # panel 5: settlements and roads
    ox = PW
    base(ox, oy, lambda p: SEA_C if p in sea else COV_C[cover[p]])
    title(ox, oy, "4-5 Settlements by score, roads by cheapest path")
    draw_crests(ox, oy)
    draw_rivers(ox, oy)
    draw_roads(ox, oy)
    draw_towns(ox, oy)
    # panel 6: sockets
    ox = 2 * PW
    base(ox, oy, lambda p: (214, 228, 240) if p in sea else (240, 236, 222))
    title(ox, oy, "6 Edge sockets: one record per edge")
    LINE_C = {"shore": (232, 200, 120), "crest": CREST_C, "pass": PASS_C, "lake": LAKE_C,
              "river1": RIV_C, "river2": RIV_C, "river3": RIV_C}
    for k, s in sock.items():
        p0, p1 = eline(k, ox, oy)
        if s["line"] in LINE_C:
            w = {"river1": 2, "river2": 3, "river3": 5}.get(s["line"], max(2, R // 5))
            pygame.draw.line(surf, LINE_C[s["line"]], p0, p1, w if SUB == 1 else max(2, w - 1))
        elif s["step"] == "scarp":
            pygame.draw.line(surf, (190, 150, 130), p0, p1, 2)
        m = emid(k, ox, oy)
        q = max(2, R // 8)
        if s["floor"]:
            pygame.draw.circle(surf, (90, 180, 90), m, q + 2)
        if s["road"]:
            pygame.draw.rect(surf, ROAD_C, (m[0] - q, m[1] - q, 2 * q, 2 * q))
        if s["cross"] and s["cross"] != "pass road":
            pygame.draw.rect(surf, (250, 250, 250), (m[0] - q, m[1] - q, 2 * q, 2 * q))
            pygame.draw.rect(surf, INK, (m[0] - q, m[1] - q, 2 * q, 2 * q), 1)
    out = os.path.join(HERE, "..", "04_prototype_steps%s.png" % ("" if SUB == 1 else "_fine"))
    pygame.image.save(surf, os.path.normpath(out))
    print("wrote", os.path.basename(out))
