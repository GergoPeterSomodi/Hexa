"""Checks that the prototype's hex grid (style_frame/geo.py, the Python the base is drawn in) and Godot's WorldGrid
(godot/core/hexgrid.gd) agree: the same hex centres in km, the same hex of a point, the same neighbours and
corners, the same longitude/latitude to km. hexgrid.gd is ported line by line below (there is no Godot on the build
machine); STYLE_FRAME_LAYERS must be set (geo.py reads it).

    python tools/worldmap/godot_bake/grid_check.py
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "style_frame"))
import geo                                                                   # noqa: E402

SQRT3 = 1.7320508075688772
EVEN = [(1, 0), (0, -1), (-1, -1), (-1, 0), (-1, 1), (0, 1)]                 # _EVEN_DIRS
ODD = [(1, 0), (1, -1), (0, -1), (-1, 0), (0, 1), (1, 1)]                    # _ODD_DIRS


class WorldGrid:
    """hexgrid.gd: _init, km_of, centre_km, hex_of_km, neighbours, corners_km."""

    def __init__(self, hex_w_km, deg_km, ref_lat, lon_west, lat_north):
        self.w = hex_w_km
        self.r = hex_w_km / SQRT3
        self.h = 1.5 * self.r
        self.deg_km, self.lon_west, self.lat_north = deg_km, lon_west, lat_north
        self.cos_ref = math.cos(math.radians(ref_lat))

    def km_of(self, lon, lat):
        return ((lon - self.lon_west) * self.deg_km * self.cos_ref, (self.lat_north - lat) * self.deg_km)

    def centre_km(self, c, r):
        return (self.w * (c + 0.5) + (r & 1) * self.w / 2.0, self.r + self.h * r)

    def hex_of_km(self, x, y):
        px, py = x - self.w / 2.0, y - self.r
        q = (SQRT3 / 3.0 * px - py / 3.0) / self.r
        rr_ = (2.0 / 3.0 * py) / self.r
        s = -q - rr_
        rq, rr, rs = math.floor(q + 0.5), math.floor(rr_ + 0.5), math.floor(s + 0.5)
        dq, dr, ds = abs(rq - q), abs(rr - rr_), abs(rs - s)
        if dq > dr and dq > ds:
            rq = -rr - rs
        elif dr > ds:
            rr = -rq - rs
        row = int(rr)
        return (int(rq) + ((row - (row & 1)) >> 1), row)

    def neighbours(self, c, r):
        return [(c + a, r + b) for a, b in (ODD if r & 1 else EVEN)]

    def corners_km(self, c, r):
        cx, cy = self.centre_km(c, r)
        return [(cx + self.r * math.cos(math.radians(-90 + 60 * k)), cy + self.r * math.sin(math.radians(-90 + 60 * k))) for k in range(6)]


def main():
    g = json.load(open(os.environ["STYLE_FRAME_LAYERS"], encoding="utf-8"))["grid"]
    wg = WorldGrid(g["hex_w_km"], g["deg_km"], g["ref_lat"], g["lon_west"], g["lat_north"])
    worst = dict(centre=0.0, corner=0.0, hexof=0, nbr=0, kmof=0.0)
    for (c, r) in geo.HEX:
        a, b = wg.centre_km(c, r), geo.centre(c, r)
        worst["centre"] = max(worst["centre"], abs(a[0] - b[0]), abs(a[1] - b[1]))
        for p, q in zip(wg.corners_km(c, r), geo.corners(c, r)):
            worst["corner"] = max(worst["corner"], abs(p[0] - q[0]), abs(p[1] - q[1]))
        if wg.neighbours(c, r) != geo.nbrs(c, r):
            worst["nbr"] += 1
    rnd = random.Random(1)
    for _ in range(20000):
        x, y = rnd.uniform(0, 600), rnd.uniform(0, 480)
        if wg.hex_of_km(x, y) != geo.hex_of_km(x, y):
            worst["hexof"] += 1
    for _ in range(2000):
        lon, lat = rnd.uniform(5.6, 12.6), rnd.uniform(43.0, 47.3)
        a, b = wg.km_of(lon, lat), geo.km_of(lon, lat)
        worst["kmof"] = max(worst["kmof"], abs(a[0] - b[0]), abs(a[1] - b[1]))
    print("grid parameters of the layers: %s" % g)
    print("geo.py: W_KM %.6f, R_KM %.9f, H_KM %.9f, LON_W %.2f, LAT_N %.2f, DEG %.1f, cos(ref lat) %.9f" % (
        geo.W_KM, geo.R_KM, geo.H_KM, geo.LON_W, geo.LAT_N, geo.DEG, geo.COS))
    print("over %d hexes: max |centre_km difference| %.2e km, corners %.2e km, neighbour lists different: %d" % (
        len(geo.HEX), worst["centre"], worst["corner"], worst["nbr"]))
    print("20000 random points: hex_of_km differs for %d; 2000 random lon/lat: km_of differs by at most %.2e km" % (
        worst["hexof"], worst["kmof"]))
    print("e.g. hex (7, 12): geo %s, WorldGrid %s;  hex (14, 11): geo %s, WorldGrid %s" % (
        tuple(round(v, 4) for v in geo.centre(7, 12)), tuple(round(v, 4) for v in wg.centre_km(7, 12)),
        tuple(round(v, 4) for v in geo.centre(14, 11)), tuple(round(v, 4) for v in wg.centre_km(14, 11))))
    meta_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "godot", "assets", "worldmap", "north_italy", "meta.json")
    if len(sys.argv) > 1:
        meta_path = sys.argv[1]
    if os.path.exists(meta_path):                                            # the baked meta against Godot's centre_km
        m = json.load(open(meta_path, encoding="utf-8"))
        ox, oy = m["origin_km"]
        s_px = m["px_per_km"]
        worst_px = 0.0
        for h in m["hexes"]:
            kx, ky = wg.centre_km(h["c"], h["r"])
            px, py = (kx - ox) * s_px, (ky - oy) * s_px * m["tilt"]
            worst_px = max(worst_px, abs(px - h["centre_px"][0]), abs(py - h["centre_px"][1]))
        print("meta.json: %d hexes; image px = ((centre_km - origin_km) * px_per_km, ... * tilt) is within %.2f px of every centre_px "
              "(centre_px are rounded to whole pixels)" % (len(m["hexes"]), worst_px))
        worst["meta_px"] = worst_px
    ok = worst.get("meta_px", 0.0) <= 0.5 + 1e-9 and worst["centre"] < 1e-9 and worst["corner"] < 1e-9 and not worst["nbr"] and not worst["hexof"] and worst["kmof"] < 1e-9
    print("the grids %s" % ("MATCH" if ok else "DIFFER"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
