"""Write the projection table that the Godot GUT tests check their maths against.

Run from anywhere:  python tools/export_hexgrid_table.py

Writes godot/tests/fixtures/geo_table.json (hexa/campaign/geo.py: merc, inv_merc, lonlat, hex_of, seg_distance).
(The 0.3.0 hex grid table is gone with that grid; the map's own grid is tested against tools/worldmap/extract_heights.py.) Only the frozen Python game is read; its values are written with repr floats, so every
float reads back to the same double in Godot.
"""
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.godot_export_common import REPO, dump  # noqa: E402

from hexa.campaign import geo  # noqa: E402

FIXTURES = REPO / "godot" / "tests" / "fixtures"


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
    for name, table in (("geo_table.json", geo_table()),):
        path = dump(FIXTURES / name, table)
        print(f"{path.stat().st_size:>9,d}  {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
