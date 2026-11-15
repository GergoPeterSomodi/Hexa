"""Derived height grid and stream lines for the 3D close-up test (Genoa area), from NOAA ETOPO 2022 (60 arc-second).

Reads the raw ETOPO NetCDF file (outside the repository) and writes one small JSON file with only derived numbers:
the heights of the window in whole metres (land and sea bed), and stream lines found by a flow count on that grid
(pits filled by a priority flood, eight flow directions). The output is scratch data for the prototype scene
godot/prototypes/closeup3d and is kept outside the repository too.

Usage:  python tools/worldmap/closeup_3d/extract_area.py --etopo PATH --out PATH
            [--west 7.9 --east 9.9 --south 43.8 --north 45.0] [--stream-cells 40]
Stdlib only. Credit for the heights: NOAA National Centers for Environmental Information. 2022: ETOPO 2022
15 Arc-Second Global Relief Model. doi:10.25921/fd45-gt74
"""

import argparse
import heapq
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from netcdf_classic import NetCDFClassic  # noqa: E402

CREDIT = ("NOAA National Centers for Environmental Information. 2022: ETOPO 2022 15 Arc-Second Global Relief "
          "Model. doi:10.25921/fd45-gt74")
SCHEMA = "hexa-godot/closeup3d-heights/1"
NEIGHBOURS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def read_window(path: str, west: float, east: float, south: float, north: float) -> tuple:
    """Rows north to south, columns west to east. Returns (rows, lon of column 0, lat of row 0, d_lon, d_lat)."""
    nc = NetCDFClassic(path)
    lat_axis = nc.read_axis("latitude")
    lon_axis = nc.read_axis("longitude")
    d_lat = lat_axis[1] - lat_axis[0]
    d_lon = lon_axis[1] - lon_axis[0]
    i0 = max(0, int(math.floor((south - lat_axis[0]) / d_lat)))
    i1 = min(len(lat_axis), int(math.ceil((north - lat_axis[0]) / d_lat)) + 1)
    j0 = max(0, int(math.floor((west - lon_axis[0]) / d_lon)))
    j1 = min(len(lon_axis), int(math.ceil((east - lon_axis[0]) / d_lon)) + 1)
    if lon_axis[j0] > west + d_lon or lon_axis[j1 - 1] < east - d_lon:
        raise SystemExit("the ETOPO file does not cover the window in longitude")
    block = nc.read_block("z", i0, i1, j0, j1)
    nc.close()
    block.reverse()  # the file runs south to north
    return block, lon_axis[j0], lat_axis[i1 - 1], d_lon, d_lat


def flow(rows: list, cell_km: tuple) -> tuple:
    """Priority flood from the sea and the window edge, then the flow count. Returns (downstream, count)."""
    n_r = len(rows)
    n_c = len(rows[0])
    down = [[None] * n_c for _ in range(n_r)]
    done = [[False] * n_c for _ in range(n_r)]
    order = []
    heap = []
    for r in range(n_r):
        for c in range(n_c):
            sea = rows[r][c] <= 0.0
            edge = r in (0, n_r - 1) or c in (0, n_c - 1)
            if sea or edge:
                done[r][c] = True
                if not sea:
                    heapq.heappush(heap, (rows[r][c], r, c))
    # Sea cells are sinks; land cells beside the sea drain into it.
    for r in range(n_r):
        for c in range(n_c):
            if rows[r][c] <= 0.0:
                for dr, dc in NEIGHBOURS:
                    rr, cc = r + dr, c + dc
                    if 0 <= rr < n_r and 0 <= cc < n_c and not done[rr][cc]:
                        done[rr][cc] = True
                        down[rr][cc] = (r, c)
                        heapq.heappush(heap, (rows[rr][cc], rr, cc))
    while heap:
        z, r, c = heapq.heappop(heap)
        order.append((r, c))
        for dr, dc in NEIGHBOURS:
            rr, cc = r + dr, c + dc
            if 0 <= rr < n_r and 0 <= cc < n_c and not done[rr][cc]:
                done[rr][cc] = True
                down[rr][cc] = (r, c)
                # A diagonal step is longer: a tiny penalty keeps the lines from zigzagging on flat ground.
                step = math.hypot(dr * cell_km[1], dc * cell_km[0])
                heapq.heappush(heap, (max(rows[rr][cc], z) + 1e-4 * step, rr, cc))
    count = [[1] * n_c for _ in range(n_r)]
    for r, c in reversed(order):
        d = down[r][c]
        if d is not None:
            count[d[0]][d[1]] += count[r][c]
    return down, count


def streams(rows: list, down: list, count: list, threshold: int) -> list:
    n_r = len(rows)
    n_c = len(rows[0])
    is_stream = [[rows[r][c] > 0.0 and count[r][c] >= threshold for c in range(n_c)] for r in range(n_r)]
    has_up = [[False] * n_c for _ in range(n_r)]
    for r in range(n_r):
        for c in range(n_c):
            d = down[r][c]
            if is_stream[r][c] and d is not None and is_stream[d[0]][d[1]]:
                has_up[d[0]][d[1]] = True
    heads = [(count[r][c], r, c) for r in range(n_r) for c in range(n_c) if is_stream[r][c] and not has_up[r][c]]
    lines = []
    used = [[False] * n_c for _ in range(n_r)]
    # Walk every head down to the sea first, to know each stem's length; the longest stems are cut first, so the
    # shorter ones end on them as tributaries.
    walks = []
    for _n, r, c in heads:
        length = 0
        rr, cc = r, c
        while down[rr][cc] is not None and is_stream[rr][cc]:
            rr, cc = down[rr][cc]
            length += 1
        walks.append((length, r, c))
    walks.sort(reverse=True)
    for _length, r, c in walks:
        cells = []
        while True:
            cells.append((r, c))
            if used[r][c]:
                break
            used[r][c] = True
            d = down[r][c]
            if d is None:
                break
            r, c = d
            if not is_stream[r][c]:
                cells.append((r, c))  # one step into the sea, so the mouth closes
                break
        if len(cells) >= 3:
            lines.append(cells)
    return lines


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--etopo", required=True, help="the ETOPO 2022 60 arc-second NetCDF file (eastern half)")
    ap.add_argument("--out", required=True, help="the JSON file to write (outside the repository)")
    ap.add_argument("--west", type=float, default=7.9)
    ap.add_argument("--east", type=float, default=9.9)
    ap.add_argument("--south", type=float, default=43.8)
    ap.add_argument("--north", type=float, default=45.0)
    ap.add_argument("--stream-cells", type=int, default=40, help="cells that must drain through a stream cell")
    args = ap.parse_args()

    rows, lon0, lat0, d_lon, d_lat = read_window(args.etopo, args.west, args.east, args.south, args.north)
    mid = math.radians((args.south + args.north) / 2.0)
    cell_km = (d_lon * 111.2 * math.cos(mid), d_lat * 111.2)
    down, count = flow(rows, cell_km)
    lines = streams(rows, down, count, args.stream_cells)
    out = {
        "schema": SCHEMA,
        "credit": CREDIT,
        "note": "Derived data: heights in whole metres, rows north to south, columns west to east; lon0 and lat0 are "
                "the centre of the first cell. Streams: [lon, lat, cells drained] per point, from a flow count.",
        "lon0": round(lon0, 6), "lat0": round(lat0, 6), "d_lon": round(d_lon, 8), "d_lat": round(d_lat, 8),
        "cols": len(rows[0]), "rows": len(rows),
        "z": [[int(round(v)) for v in row] for row in rows],
        "streams": [[[round(lon0 + c * d_lon, 5), round(lat0 - r * d_lat, 5), count[r][c]] for r, c in cells]
                    for cells in lines],
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    flat = [v for row in rows for v in row]
    print("window %.3f..%.3f E, %.3f..%.3f N: %d x %d cells, z %d..%d m, %d streams, %d bytes" % (
        lon0, lon0 + (len(rows[0]) - 1) * d_lon, lat0 - (len(rows) - 1) * d_lat, lat0, len(rows[0]), len(rows),
        min(flat), max(flat), len(lines), os.path.getsize(args.out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
