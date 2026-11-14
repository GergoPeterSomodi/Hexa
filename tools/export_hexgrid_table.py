"""Write the hex-grid and projection tables that the Godot GUT tests check their maths against.

Run from anywhere:  python tools/export_hexgrid_table.py

Writes godot/tests/fixtures/hexgrid_table.json (hexa/hexgrid.py: neighbours, cube coordinates, distance, within,
hex_center, pixel_to_hex) and godot/tests/fixtures/geo_table.json (hexa/campaign/geo.py: merc, inv_merc, lonlat,
hex_of, seg_distance). Only the frozen Python game is read; its values are written with repr floats, so every
float reads back to the same double in Godot.
"""
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.godot_export_common import REPO, dump  # noqa: E402

from hexa import hexgrid  # noqa: E402
from hexa.campaign import geo  # noqa: E402

FIXTURES = REPO / "godot" / "tests" / "fixtures"


def hexgrid_table():
    positions = [(c, r) for r in range(-3, 6) for c in range(-3, 6)] + [(7, 11), (-4, 9), (202, 149), (0, 149)]
    pairs = [(a, b) for a in positions[::5] for b in positions[::7]]
    points = [(x * 13.7 - 40.25, y * 9.1 + 0.125) for x in range(-3, 6) for y in range(-2, 4)]
    return {
        "schema": "hexa-godot/hexgrid-table/1",
        "source": "hexa/hexgrid.py (tools/export_hexgrid_table.py)",
        "neighbours": [[list(p), [list(n) for n in hexgrid.neighbors(p)]] for p in positions],
        "cube": [[list(p), list(hexgrid.to_cube(p))] for p in positions],
        "distance": [[list(a), list(b), hexgrid.distance(a, b)] for a, b in pairs],
        "within": [[list(p), k, [list(q) for q in hexgrid.within(p, k)]]
                   for p in [(0, 0), (3, 4), (-2, 7)] for k in (0, 1, 2, 3)],
        "center": [[list(p), list(hexgrid.hex_center(p))] for p in positions],
        "center_origin": [[list(p), list(hexgrid.hex_center(p, (12.5, -7.0)))] for p in positions[:12]],
        "pixel": [[list(pt), list(hexgrid.pixel_to_hex(pt))] for pt in points],
        "pixel_origin": [[list(pt), list(hexgrid.pixel_to_hex(pt, (12.5, -7.0)))] for pt in points[:20]],
    }


def geo_table():
    cells = [(c, r) for r in range(0, 150, 13) for c in range(0, 203, 17)] + [(202, 149), (0, 0), (5, 1)]
    lats = [-13.0, -0.5, 0.0, 12.25, 36.2, 46.0, 51.37, 62.5, 70.0]
    coords = [(lon, lat) for lon in (-9.14, -5.4, 0.0, 8.56, 21.0, 46.5, 2.25) for lat in (36.0, 46.0, 53.37, 64.1)]
    return {
        "schema": "hexa-godot/geo-table/1",
        "source": "hexa/campaign/geo.py (tools/export_hexgrid_table.py)",
        "merc": [[lat, geo.merc(lat)] for lat in lats],
        "inv_merc": [[y, geo.inv_merc(y)] for y in [geo.merc(lat) for lat in lats]],
        "lonlat": [[list(p), list(geo.lonlat(p))] for p in cells],
        "hex_of": [[lon, lat, list(geo.hex_of(lon, lat))] for lon, lat in coords],
        "seg_distance": [[list(p), list(a), list(b), geo.seg_distance(p, a, b)]
                         for p, a, b in [((8.0, 46.0), (5.0, 44.0), (12.0, 47.5)), ((-3.0, 50.0), (-3.0, 50.0), (0.0, 52.0)),
                                         ((20.0, 60.0), (0.0, 40.0), (30.0, 70.0)), ((-30.5, 39.2), (-40.0, 30.0), (-31.0, 41.0))]],
    }


def main():
    FIXTURES.mkdir(parents=True, exist_ok=True)
    for name, table in (("hexgrid_table.json", hexgrid_table()), ("geo_table.json", geo_table())):
        path = dump(FIXTURES / name, table)
        print(f"{path.stat().st_size:>9,d}  {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
