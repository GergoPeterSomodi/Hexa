"""Exports a fine height raster of the north Italy map from NOAA ETOPO 2022 (60 arc-second).

The per-hex heights of godot/data/worldmap/heights_alps_po.json are one number per 28 km hex; the later map look
(docs/architecture/m1-build-spec.md section 14) wants the ground itself. This writes the metres on a raster with
HEIGHT_GRID_STEP = 4 samples per hex width (7 km), over the whole region, to godot/data/worldmap/height_grid_alps_po.json.
Each sample is the mean of the ETOPO cells whose centres lie within half a step of it (signed: the sea is negative metres).
Derived numbers only; the ETOPO file stays outside the repository.

Data credit: NOAA National Centers for Environmental Information. 2022: ETOPO 2022 15 Arc-Second Global Relief Model.
doi:10.25921/fd45-gt74

    python tools/worldmap/export_height_grid.py [--etopo PATH] [--out PATH]

Stdlib only. Run from anywhere; the grid is the one of godot/core/hexgrid.gd (x east, y south, km from the region corner).
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from netcdf_classic import NetCDFClassic  # noqa: E402

DEFAULT_ETOPO = "C:/hxr/data/etopo2022/etopo2022_60s_east.nc"
DEFAULT_OUT = os.path.join(REPO, "godot", "data", "worldmap", "height_grid_alps_po.json")
REGION = os.path.join(REPO, "godot", "data", "worldmap", "region_alps_po.json")
STEP_PER_HEX = 4
COLS, ROWS = 21, 19
SOURCE = ("NOAA ETOPO 2022, 60 arc-second, surface elevation. Credit: NOAA National Centers for Environmental Information. "
          "2022: ETOPO 2022 15 Arc-Second Global Relief Model. doi:10.25921/fd45-gt74")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--etopo", default=DEFAULT_ETOPO)
    ap.add_argument("--out", default=DEFAULT_OUT)
    a = ap.parse_args(argv)
    region = json.load(open(REGION, encoding="utf-8"))
    win, g = region["window"], region["grid"]
    w_km, deg_km = float(g["hex_w_km"]), float(g["deg_km"])
    cos_ref = math.cos(math.radians(float(g["ref_lat"])))
    lon_w, lat_n = float(win["lon_west"]), float(win["lat_north"])
    r_km = w_km / math.sqrt(3.0)
    far_x = w_km * (COLS + 0.5)
    far_y = 2.0 * r_km + 1.5 * r_km * (ROWS - 1)
    step = w_km / STEP_PER_HEX
    nx, ny = int(math.ceil(far_x / step)) + 1, int(math.ceil(far_y / step)) + 1
    half = step / 2.0

    nc = NetCDFClassic(a.etopo)
    lat_axis, lon_axis = nc.read_axis("latitude"), nc.read_axis("longitude")
    d_lat, d_lon = lat_axis[1] - lat_axis[0], lon_axis[1] - lon_axis[0]
    lat_s = lat_n - (ny - 1) * step / deg_km - 0.1
    lon_e = lon_w + (nx - 1) * step / (deg_km * cos_ref) + 0.1
    i0 = max(0, int(math.floor((lat_s - lat_axis[0]) / d_lat)))
    i1 = min(len(lat_axis), int(math.ceil((lat_n + 0.1 - lat_axis[0]) / d_lat)) + 1)
    j0 = max(0, int(math.floor((lon_w - 0.1 - lon_axis[0]) / d_lon)))
    j1 = min(len(lon_axis), int(math.ceil((lon_e - lon_axis[0]) / d_lon)) + 1)
    block = nc.read_block("z", i0, i1, j0, j1)
    nc.close()
    sums = [[0.0] * nx for _ in range(ny)]
    counts = [[0] * nx for _ in range(ny)]
    for ii, row in enumerate(block):
        y = (lat_n - lat_axis[i0 + ii]) * deg_km
        sj = int(round(y / step))
        for jj, z in enumerate(row):
            x = (lon_axis[j0 + jj] - lon_w) * deg_km * cos_ref
            si = int(round(x / step))
            if 0 <= si < nx and 0 <= sj < ny and abs(x - si * step) <= half and abs(y - sj * step) <= half:
                sums[sj][si] += z
                counts[sj][si] += 1
    values = []
    for sj in range(ny):
        for si in range(nx):
            if counts[sj][si] == 0:
                raise SystemExit("no ETOPO cell near sample %d, %d" % (si, sj))
            values.append(int(round(sums[sj][si] / counts[sj][si])))
    doc = {"schema": "hexa-godot/worldmap-height-grid/1", "source": SOURCE,
           "grid": {"hex_w_km": w_km, "step_per_hex": STEP_PER_HEX, "step_km": step, "origin_km": [0.0, 0.0],
                    "width": nx, "height": ny},
           "note": "metres, row by row from the north-west corner; sea is negative", "values": values}
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, separators=(",", ":"))
        f.write("\n")
    print("wrote %s: %d x %d samples, %d bytes, min %d max %d m" % (a.out, nx, ny, os.path.getsize(a.out), min(values), max(values)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
