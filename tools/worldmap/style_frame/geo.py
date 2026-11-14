"""Data and geometry for the style frame (reads the map-proto worktree, read only)."""
import json, math, os

# The repository root, and the layers file written by the map prototype (outside the repo; set STYLE_FRAME_LAYERS).
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
L = json.load(open(os.environ["STYLE_FRAME_LAYERS"], encoding="utf-8"))
H = json.load(open(ROOT + "/godot/data/worldmap/heights_alps_po.json", encoding="utf-8"))
R = json.load(open(ROOT + "/godot/data/worldmap/region_alps_po.json", encoding="utf-8"))

W_KM = 28.0
R_KM = W_KM / math.sqrt(3)
H_KM = 1.5 * R_KM
COS = math.cos(math.radians(45.25))
LON_W, LAT_N, DEG = 5.6, 47.3, 111.2

HEX = {}
for h in L["hexes"]:
    c, r = h[0], h[1]
    HEX[(c, r)] = dict(level=h[2], cover=h[3], shade=h[4], water=h[6], lagoon=h[7])
for h in H["hexes"]:
    k = (h["c"], h["r"])
    if k in HEX:
        HEX[k]["m"] = h["height_m"] if h["land"] else 0.0
        HEX[k]["land"] = h["land"]
        HEX[k]["peak"] = h.get("peak")


def km_of(lon, lat):
    return ((lon - LON_W) * DEG * COS, (LAT_N - lat) * DEG)


def centre(c, r):
    return (W_KM * (c + 0.5) + (r & 1) * W_KM / 2.0, R_KM + H_KM * r)


def corner(c, r, k):
    x, y = centre(c, r)
    a = math.radians(-90 + 60 * k)
    return (x + R_KM * math.cos(a), y + R_KM * math.sin(a))


def corners(c, r):
    return [corner(c, r, k) for k in range(6)]


EVEN = [(1, 0), (0, -1), (-1, -1), (-1, 0), (-1, 1), (0, 1)]
ODD = [(1, 0), (1, -1), (0, -1), (-1, 0), (0, 1), (1, 1)]


def nbrs(c, r):
    d = ODD if r & 1 else EVEN
    return [(c + a, r + b) for a, b in d]


def edge_pts(a, b):
    """The two corner points shared by neighbouring hexes a and b."""
    ca = corners(*a)
    cb = corners(*b)
    out = []
    for p in ca:
        for q in cb:
            if abs(p[0] - q[0]) < 1e-6 and abs(p[1] - q[1]) < 1e-6:
                out.append(p)
    return out


def hex_of_km(x, y):
    px = x - W_KM / 2.0
    py = y - R_KM
    q = (math.sqrt(3) / 3.0 * px - py / 3.0) / R_KM
    r = (2.0 / 3.0 * py) / R_KM
    s = -q - r
    rq, rr, rs = math.floor(q + .5), math.floor(r + .5), math.floor(s + .5)
    dq, dr, ds = abs(rq - q), abs(rr - r), abs(rs - s)
    if dq > dr and dq > ds:
        rq = -rr - rs
    elif dr > ds:
        rr = -rq - rs
    row = int(rr)
    col = int(rq) + ((row - (row & 1)) >> 1)
    return (col, row)
