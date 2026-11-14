"""Per-hex height statistics for the map prototype region, from NOAA ETOPO 2022 (60 arc-second).

Reads the hand-written region (godot/data/worldmap/region_alps_po.json), the coastline (godot/data/geography/land.json)
and the raw ETOPO NetCDF file (outside the repo). Writes only derived numbers, one record per 28 km hex, to
godot/data/worldmap/heights_alps_po.json, and prints a report: every named feature and the hex it landed in.

Land or sea is decided by the coastline polygons (majority of 13 sample points in the hex), never by height below 0.
The statistics use the ETOPO cells of the hex that are at or above sea level (z >= 0), so a coastal hex is not pulled
down by the sea cells beside its land. Lakes are land (the coastline has none in this window).

Usage:  python tools/worldmap/extract_heights.py [--region PATH] [--out PATH] [--etopo PATH] [--quiet]
Run from the repository root (the folder that holds godot/). Stdlib only (the project venv has no numpy or scipy).

Grid (shared with godot/core/worldmap/world_grid.gd; the GUT test checks a few points against this script):
  x_km = (lon - lon_west) * deg_km * cos(ref_lat);  y_km = (lat_north - lat) * deg_km          (y grows south)
  pointy-top hexes, circumradius R = W / sqrt(3), W = hex_w_km; odd rows shifted half a hex right
  centre of hex (c, r):  x = W * (c + 0.5) + (r & 1) * W / 2,  y = R + 1.5 * R * r
  hex of a point: axial rounding of q = (sqrt3/3 X - Y/3) / R, r = (2/3 Y) / R, X = x - W/2, Y = y - R
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from netcdf_classic import NetCDFClassic  # noqa: E402

SQRT3 = math.sqrt(3.0)
# Lower bounds, metres, of relief levels 2 to 6 (01-terrain-and-relief.md section 2.1). Level 0 is sea (the coastline),
# level 1 is 0 to 100 m, level 2 is 100 to 400 m, ... level 6 is 2800 m and up.
LEVEL_LOWER_BOUNDS = [100, 400, 900, 1700, 2800]
INNER_RADIUS_HEX = 0.4  # thread 1: the height of a hex is the highest ground within about 0.4 of a hex of its centre
# (inner_max, the default). The other statistics are written too, for comparison and for the valley question.
STATS = ("inner_mean", "inner_median", "inner_p75", "inner_max", "mean", "median", "max")
# "centre" (one ETOPO cell at the hex centre) is not in the file's statistics; it is only a comparison choice
# (--stat=centre), so the owner can see the valley question with and without the inner maximum.
SCHEMA_HEIGHTS = "hexa-godot/worldmap-heights/1"
DEFAULT_REGION = os.path.join("godot", "data", "worldmap", "region_alps_po.json")
DEFAULT_OUT = os.path.join("godot", "data", "worldmap", "heights_alps_po.json")
DEFAULT_ETOPO = "C:/hxr/data/etopo2022/etopo2022_60s_east.nc"
COAST = os.path.join("godot", "data", "geography", "land.json")


class Grid:
    def __init__(self, region: dict) -> None:
        win = region["window"]
        g = region["grid"]
        self.lon_w = float(win["lon_west"])
        self.lon_e = float(win["lon_east"])
        self.lat_s = float(win["lat_south"])
        self.lat_n = float(win["lat_north"])
        self.w = float(g["hex_w_km"])
        self.deg_km = float(g["deg_km"])
        self.ref_lat = float(g["ref_lat"])
        self.cos_ref = math.cos(math.radians(self.ref_lat))
        self.r = self.w / SQRT3
        self.h = 1.5 * self.r

    def km_of(self, lon: float, lat: float) -> tuple:
        return ((lon - self.lon_w) * self.deg_km * self.cos_ref, (self.lat_n - lat) * self.deg_km)

    def lonlat_of(self, x: float, y: float) -> tuple:
        return (self.lon_w + x / (self.deg_km * self.cos_ref), self.lat_n - y / self.deg_km)

    def centre_km(self, c: int, r: int) -> tuple:
        return (self.w * (c + 0.5) + (r & 1) * self.w / 2.0, self.r + self.h * r)

    def hex_of_km(self, x: float, y: float) -> tuple:
        X = x - self.w / 2.0
        Y = y - self.r
        q = (SQRT3 / 3.0 * X - Y / 3.0) / self.r
        rr = (2.0 / 3.0 * Y) / self.r
        s = -q - rr
        rq = math.floor(q + 0.5)
        rrr = math.floor(rr + 0.5)
        rs = math.floor(s + 0.5)
        dq = abs(rq - q)
        dr = abs(rrr - rr)
        ds = abs(rs - s)
        if dq > dr and dq > ds:
            rq = -rrr - rs
        elif dr > ds:
            rrr = -rq - rs
        col = int(rq + (rrr - (rrr & 1)) // 2)
        return (col, int(rrr))

    def hex_of(self, lon: float, lat: float) -> tuple:
        return self.hex_of_km(*self.km_of(lon, lat))

    def hex_centre_lonlat(self, c: int, r: int) -> tuple:
        return self.lonlat_of(*self.centre_km(c, r))

    def in_window(self, lon: float, lat: float) -> bool:
        return self.lon_w <= lon <= self.lon_e and self.lat_s <= lat <= self.lat_n


def point_in_polygon(x: float, y: float, poly: list) -> bool:
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def bbox(poly: list) -> tuple:
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    return (min(xs), min(ys), max(xs), max(ys))


class Coast:
    """Land and sea from godot/data/geography/land.json (the game's own rules: land polygons minus sea polygons)."""

    def __init__(self, path: str) -> None:
        data = json.load(open(path, encoding="utf-8"))
        self.land = [m["points"] for m in data["landmasses"]] + [m["points"] for m in data["islands"]]
        self.sea = [m["points"] for m in data["seas"]]
        self.land_box = [bbox(p) for p in self.land]
        self.sea_box = [bbox(p) for p in self.sea]
        self.force_sea = [tuple(p) for p in data.get("force_sea", [])]
        self.force_land = [tuple(p) for p in data.get("force_land", [])]

    def is_land(self, lon: float, lat: float) -> bool:
        if any(lon0 <= lon <= lon1 and lat0 <= lat <= lat1 and point_in_polygon(lon, lat, p)
               for p, (lon0, lat0, lon1, lat1) in zip(self.sea, self.sea_box)):
            return False
        return any(lon0 <= lon <= lon1 and lat0 <= lat <= lat1 and point_in_polygon(lon, lat, p)
                   for p, (lon0, lat0, lon1, lat1) in zip(self.land, self.land_box))


def sample_offsets(grid: Grid) -> list:
    """The centre and two rings of six points (at 0.55 and 0.9 of the circumradius), in km offsets."""
    out = [(0.0, 0.0)]
    for ring in (0.55, 0.9):
        for k in range(6):
            a = math.radians(60.0 * k)
            out.append((ring * grid.r * math.cos(a), ring * grid.r * math.sin(a)))
    return out


def decide_land(grid: Grid, coast: Coast, c: int, r: int, offsets: list) -> tuple:
    cx, cy = grid.centre_km(c, r)
    votes = 0
    for dx, dy in offsets:
        lon, lat = grid.lonlat_of(cx + dx, cy + dy)
        if coast.is_land(lon, lat):
            votes += 1
    return votes * 2 > len(offsets), votes


def percentile(sorted_vals: list, p: float) -> float:
    if not sorted_vals:
        return 0.0
    k = (len(sorted_vals) - 1) * p
    lo = math.floor(k)
    hi = math.ceil(k)
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (k - lo)


def level_of(metres: float) -> int:
    """Relief level of a land hex (1 to 6) from its height in metres."""
    level = 1
    for i, lower in enumerate(LEVEL_LOWER_BOUNDS, start=2):
        if metres >= lower:
            level = i
    return level


def line_points(line: list, step_deg: float = 0.01) -> list:
    pts = []
    for (x0, y0), (x1, y1) in zip(line[:-1], line[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step_deg))
        for i in range(n):
            t = i / n
            pts.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    pts.append(tuple(line[-1]))
    return pts


def main(argv: list) -> int:
    args = {}
    quiet = "--quiet" in argv
    rest = [a for a in argv[1:] if a != "--quiet"]
    for a in rest:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            args[k] = v
    stat_name = args.get("stat", "inner_max")
    if stat_name not in STATS + ("centre",):
        raise SystemExit("--stat must be one of %s, centre" % ", ".join(STATS))
    region_path = args.get("region", DEFAULT_REGION)
    out_path = args.get("out", DEFAULT_OUT)
    etopo_path = args.get("etopo", DEFAULT_ETOPO)

    region = json.load(open(region_path, encoding="utf-8"))
    grid = Grid(region)
    coast = Coast(COAST)
    offsets = sample_offsets(grid)

    # The grid: every hex whose centre lies inside the window.
    cols_max = int(math.ceil((grid.lon_e - grid.lon_w) * grid.deg_km * grid.cos_ref / grid.w)) + 2
    rows_max = int(math.ceil((grid.lat_n - grid.lat_s) * grid.deg_km / grid.h)) + 2
    hexes = {}
    for r in range(rows_max):
        for c in range(cols_max):
            lon, lat = grid.hex_centre_lonlat(c, r)
            if grid.in_window(lon, lat):
                hexes[(c, r)] = {"lon": lon, "lat": lat}

    # Land or sea from the coastline, then the game's forced points (land.json force_land, force_sea, places).
    for (c, r), rec in hexes.items():
        land, votes = decide_land(grid, coast, c, r, offsets)
        rec["land"] = land
        rec["votes"] = votes
        rec["forced"] = ""
    for lon, lat in coast.force_sea:
        h = grid.hex_of(lon, lat)
        if h in hexes:
            hexes[h]["land"] = False
            hexes[h]["forced"] = "force_sea"
    for lon, lat in coast.force_land:
        h = grid.hex_of(lon, lat)
        if h in hexes:
            hexes[h]["land"] = True
            hexes[h]["forced"] = "force_land"
    places = region["places"]
    for p in places:
        h = grid.hex_of(p["lon"], p["lat"])
        if h in hexes and not hexes[h]["land"]:
            hexes[h]["land"] = True
            hexes[h]["forced"] = "city point (builder rule: cities are land)" if p["kind"] != "hospice" else "place"

    # ETOPO cells inside the window: which hex each cell belongs to, and its height if at or above sea level.
    nc = NetCDFClassic(etopo_path)
    lat_axis = nc.read_axis("latitude")
    lon_axis = nc.read_axis("longitude")
    d_lat = lat_axis[1] - lat_axis[0]
    d_lon = lon_axis[1] - lon_axis[0]
    i0 = max(0, int(math.floor((grid.lat_s - lat_axis[0]) / d_lat)))
    i1 = min(len(lat_axis), int(math.ceil((grid.lat_n - lat_axis[0]) / d_lat)) + 1)
    j0 = max(0, int(math.floor((grid.lon_w - lon_axis[0]) / d_lon)))
    j1 = min(len(lon_axis), int(math.ceil((grid.lon_e - lon_axis[0]) / d_lon)) + 1)
    if lon_axis[j0] > grid.lon_w + d_lon or lon_axis[j1 - 1] < grid.lon_e - d_lon:
        raise SystemExit("the ETOPO file does not cover the window in longitude")
    block = nc.read_block("z", i0, i1, j0, j1)
    nc.close()

    cell_vals = {h: [] for h in hexes}  # (z, lon, lat, distance from the hex centre in km) for cells with z >= 0
    cell_all = {h: 0 for h in hexes}
    for ii, row in enumerate(block):
        lat = lat_axis[i0 + ii]
        if not (grid.lat_s <= lat <= grid.lat_n):
            continue
        for jj, z in enumerate(row):
            lon = lon_axis[j0 + jj]
            if not grid.in_window(lon, lat) or math.isnan(z):
                continue
            h = grid.hex_of(lon, lat)
            if h not in hexes:
                continue
            cell_all[h] += 1
            if z >= 0.0:
                x, y = grid.km_of(lon, lat)
                cx, cy = grid.centre_km(h[0], h[1])
                cell_vals[h].append((z, lon, lat, math.hypot(x - cx, y - cy)))

    def _z_at(i: int, j: int) -> float:
        # Height of one ETOPO cell from the window block (the block covers every cell the report looks at).
        ii = i - i0
        jj = j - j0
        if 0 <= ii < len(block) and 0 <= jj < len(block[0]):
            return block[ii][jj]
        return math.nan

    out_hexes = []
    stat_level = {s: 0 for s in STATS}
    for (c, r) in sorted(hexes.keys(), key=lambda k: (k[1], k[0])):
        rec = hexes[(c, r)]
        vals = cell_vals[(c, r)]
        entry = {"c": c, "r": r, "land": rec["land"], "cells": cell_all[(c, r)], "votes": rec["votes"]}
        if rec["forced"]:
            entry["forced"] = rec["forced"]
        if rec["land"]:
            zs = sorted(v[0] for v in vals)
            inner = sorted(v[0] for v in vals if v[3] <= INNER_RADIUS_HEX * grid.w)
            if zs:
                top = max(vals, key=lambda v: v[0])
                entry.update({
                    "inner_mean": round(sum(inner) / len(inner), 1) if inner else round(sum(zs) / len(zs), 1),
                    "inner_median": round(percentile(inner, 0.5), 1) if inner else round(percentile(zs, 0.5), 1),
                    "inner_p75": round(percentile(inner, 0.75), 1) if inner else round(percentile(zs, 0.75), 1),
                    "inner_max": round(inner[-1], 1) if inner else round(zs[-1], 1),
                    "mean": round(sum(zs) / len(zs), 1),
                    "median": round(percentile(zs, 0.5), 1),
                    "min": round(zs[0], 1),
                    "max": round(zs[-1], 1),
                    "p90": round(percentile(zs, 0.9), 1),
                    "peak": [round(top[1], 4), round(top[2], 4), round(top[0], 1)],
                })
            else:
                entry.update({"inner_mean": 0.0, "inner_median": 0.0, "inner_p75": 0.0, "inner_max": 0.0,
                              "mean": 0.0, "median": 0.0, "min": 0.0, "max": 0.0, "p90": 0.0,
                              "peak": None, "no_data": True})
            clon, clat = grid.hex_centre_lonlat(c, r)
            ci = int(round((clat - lat_axis[0]) / d_lat))
            cj = int(round((clon - lon_axis[0]) / d_lon))
            entry["centre_z"] = _json_z(_z_at(ci, cj))
            use_centre = stat_name == "centre" and entry["centre_z"] is not None
            if use_centre:
                entry["height_m"] = entry["centre_z"]
            else:
                entry["height_m"] = entry["inner_mean" if stat_name == "centre" else stat_name]
            entry["level"] = level_of(entry["height_m"])
            for key in stat_level:
                stat_level[key] += level_of(entry[key]) >= 2
        else:
            entry["height_m"] = 0.0
            entry["level"] = 0
        out_hexes.append(entry)

    # Named features: the hex each lands in, and the ETOPO height at the point itself.
    anchors = []
    report_lines = []
    for p in places:
        h = grid.hex_of(p["lon"], p["lat"])
        z = _z_at(*_cell_index(lat_axis, lon_axis, p["lat"], p["lon"], d_lat, d_lon))
        anchors.append({"kind": p["kind"], "name": p["name"], "c": h[0], "r": h[1], "z": _json_z(z)})
        in_h = h in hexes
        land = hexes[h]["land"] if in_h else None
        height = hexes_value(out_hexes, h, "height_m") if in_h else None
        report_lines.append(("place", p["name"], p["kind"], h, land, _json_z(z), height))
    for ps in region["passes"]:
        h = grid.hex_of(ps["lon"], ps["lat"])
        z = _z_at(*_cell_index(lat_axis, lon_axis, ps["lat"], ps["lon"], d_lat, d_lon))
        anchors.append({"kind": "pass", "name": ps["name"], "c": h[0], "r": h[1], "z": _json_z(z),
                        "metres": ps["metres"]})
        in_h = h in hexes
        land = hexes[h]["land"] if in_h else None
        height = hexes_value(out_hexes, h, "height_m") if in_h else None
        report_lines.append(("pass", ps["name"], ps["metres"], h, land, _json_z(z), height))
    for gorge in region["gorges"]:
        h = grid.hex_of(gorge["lon"], gorge["lat"])
        anchors.append({"kind": "gorge", "name": gorge["name"], "c": h[0], "r": h[1]})
        report_lines.append(("gorge", gorge["name"], "", h, hexes[h]["land"] if h in hexes else None, None, None))
    for rc in region["river_cities"]:
        place = next(p for p in places if p["name"] == rc["name"])
        h = grid.hex_of(place["lon"], place["lat"])
        report_lines.append(("river city", rc["name"], rc["river"] + " " + rc["form"], h,
                             hexes[h]["land"] if h in hexes else None, None, None))

    line_rows = []
    for group in ("ranges", "valleys", "rivers"):
        for item in region[group]:
            line = item.get("line") or item.get("floor")
            touched = []
            seen = set()
            for lon, lat in line_points(line):
                h = grid.hex_of(lon, lat)
                if h not in seen:
                    seen.add(h)
                    touched.append(h)
            in_grid = [h for h in touched if h in hexes]
            sea_hexes = [h for h in in_grid if not hexes[h]["land"]]
            line_rows.append((group, item["name"], len(in_grid), len(sea_hexes), len(touched) - len(in_grid)))
            if group == "ranges":
                crest = item["crest_level"]
                levels = [level_of(hexes_value(out_hexes, h, "height_m")) for h in in_grid]
                line_rows[-1] = line_rows[-1] + (crest, sum(1 for lv in levels if lv >= crest))
    for lake in region["lakes"]:
        touched = []
        for lon, lat in line_points(lake["axis"]):
            h = grid.hex_of(lon, lat)
            if h not in touched:
                touched.append(h)
        line_rows.append(("lakes", lake["name"], len([h for h in touched if h in hexes]), 0, 0))

    result = {
        "schema": SCHEMA_HEIGHTS,
        "source": "NOAA ETOPO 2022, 60 arc-second, surface elevation. Credit: NOAA National Centers for Environmental "
                  "Information. 2022: ETOPO 2022 15 Arc-Second Global Relief Model. doi:10.25921/fd45-gt74",
        "region": region["name"],
        "window": region["window"],
        "grid": {"hex_w_km": grid.w, "deg_km": grid.deg_km, "ref_lat": grid.ref_lat},
        "height_stat": stat_name,
        "level_lower_bounds": LEVEL_LOWER_BOUNDS,
        "hexes": out_hexes,
        "anchors": anchors,
    }
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(result, f, indent=1, sort_keys=False)
        f.write("\n")

    if not quiet:
        land_n = sum(1 for e in out_hexes if e["land"])
        print("grid: %d hexes in the window (%d land, %d sea); hex %.0f km" % (len(out_hexes), land_n, len(out_hexes) - land_n, grid.w))
        print("land hexes at level >= 2 by statistic (of %d land): %s" % (land_n, ", ".join(
            "%s %d" % (s, stat_level[s]) for s in STATS)))
        print("")
        print("NAMED POINTS (kind, name, hex (c,r), land?, ETOPO z at the point, hex height m):")
        for row in report_lines:
            print("  " + "  |  ".join(str(x) for x in row))
        print("")
        print("LINES (name, hexes in window, sea hexes, hexes outside, [crest level, crest hexes at that level]):")
        for row in line_rows:
            print("  " + "  |  ".join(str(x) for x in row))
        print("")
        hist = [0] * 7
        for e in out_hexes:
            hist[e.get("level", 0)] += 1
        print("levels with %s (0 sea, 1 lowland ... 6 high peaks): %s" % (stat_name, " ".join(str(n) for n in hist)))
        print("wrote %s" % out_path)
    return 0


def hexes_value(out_hexes: list, h: tuple, key: str) -> float:
    for e in out_hexes:
        if (e["c"], e["r"]) == h:
            return float(e.get(key, 0.0))
    return 0.0


def _json_z(z: float):
    return None if math.isnan(z) else round(z, 1)


def _cell_index(lat_axis: list, lon_axis: list, lat: float, lon: float, d_lat: float, d_lon: float) -> tuple:
    i = int(round((lat - lat_axis[0]) / d_lat))
    j = int(round((lon - lon_axis[0]) / d_lon))
    return (min(max(i, 0), len(lat_axis) - 1), min(max(j, 0), len(lon_axis) - 1))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
