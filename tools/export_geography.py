"""Export the Europe 1480 geography to godot/data/geography/ (JSON), once.

Run from anywhere:  python tools/export_geography.py [--out DIR]

Reads the frozen game (`hexa/campaign/geo.py`, `regions.py`, `placenames.py`, `naming.py`; imported, never edited) and
writes the tables the Godot map builder projects onto its hex grid. Points are [longitude, latitude] in degrees.
The schema of every file is in godot/data/README.md. Nothing is typed by hand: every number comes from the module.
"""
import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.godot_export_common import CAMPAIGN_DIR, GEO_DIR, dump, module_constants, plain  # noqa: E402

from hexa.campaign import geo, placenames, regions  # noqa: E402

SCHEMA = "hexa-godot/geography-{}/1"

LAND_NAMES = ("EUROPE_ASIA", "SCANDINAVIA", "BRITAIN", "IRELAND", "AFRICA", "NORTH_AMERICA", "SOUTH_AMERICA")


def points(poly):
    return [[lon, lat] for lon, lat in poly]


def projection():
    return {
        "schema": SCHEMA.format("projection"),
        "source": "hexa/campaign/geo.py (projection, lonlat, hex_of, merc, inv_merc, land_cells; see builder_functions.json)",
        "name": geo.name,
        "start": plain(geo.START),
        "lon0": geo.LON0,
        "lon1": geo.LON1,
        "lat_top": geo.LAT_TOP,
        "lat_bottom": geo.LAT_BOTTOM,
        "scale": geo.SCALE,
        "col_deg": geo.COL_DEG,
        "row_deg": geo.ROW_DEG,
        "y_top": geo.Y_TOP,
        "cols": geo.COLS,
        "rows": geo.ROWS,
        "note": "col_deg and row_deg are the values Python computes (1.45 / SCALE and COL_DEG * 0.8660254); use these "
                "exact doubles, do not recompute them. Odd rows are shifted half a hex (see lonlat and hex_of rules).",
    }


def land():
    polys = [{"name": n.lower(), "points": points(getattr(geo, n))} for n in LAND_NAMES]
    islands = [{"name": f"island_{i:02d}", "points": points(p)} for i, p in enumerate(geo.ISLANDS)]
    return {
        "schema": SCHEMA.format("land"),
        "source": "hexa/campaign/geo.py (EUROPE_ASIA... ISLANDS, LAKES, SEAS, FORCE_SEA, FORCE_LAND)",
        "note": "land_cells tests a hex centre against the land polygons in the order of `landmasses` then `islands`; "
                "a centre inside a lake polygon is a lake; a centre inside a sea polygon is not land; a centre inside "
                "no polygon is ocean. force_sea points are removed from land, force_land points added. The city "
                "points are also forced land (builder rule, builder_functions.json).",
        "landmasses": polys,
        "islands": islands,
        "lakes": [{"points": points(p)} for p in geo.LAKES],
        "seas": [{"points": points(p)} for p in geo.SEAS],
        "force_sea": points(geo.FORCE_SEA),
        "force_land": points(geo.FORCE_LAND),
    }


def terrain_shapes():
    heights = list(geo.MOUNTAIN_HEIGHT)
    return {
        "schema": SCHEMA.format("terrain-shapes"),
        "source": "hexa/campaign/geo.py (DESERTS, STEPPES, MAGHREB, MARSHES, HILLS, FERTILE_RIVERS, MOUNTAINS, MOUNTAIN_HEIGHT)",
        "note": "deserts, steppes and maghreb are polygons; marshes are boxes (lon0, lat0, lon1, lat1, k) with k the marsh "
                "share 0..1; hills, fertile_rivers and mountain lines are polylines. mountains[i].height is "
                "MOUNTAIN_HEIGHT[i]; a line past the list has default_height.",
        "deserts": [points(p) for p in geo.DESERTS],
        "steppes": [points(p) for p in geo.STEPPES],
        "maghreb": [points(p) for p in geo.MAGHREB],
        "marshes": [{"lon0": a, "lat0": b, "lon1": c, "lat1": d, "k": k} for a, b, c, d, k in geo.MARSHES],
        "hills": [points(p) for p in geo.HILLS],
        "fertile_rivers": [points(p) for p in geo.FERTILE_RIVERS],
        "mountains": [{"line": points(line), "height": heights[i] if i < len(heights) else None}
                      for i, line in enumerate(geo.MOUNTAINS)],
        "default_height": 0.6,
    }


def rivers():
    return {
        "schema": SCHEMA.format("rivers"),
        "source": "hexa/campaign/geo.py (RIVERS)",
        "note": "Traced by worldgen.trace onto the hexes they flow through, in this order.",
        "rivers": [{"name": name, "points": points(line)} for name, line in geo.RIVERS],
    }


def passes():
    return {
        "schema": SCHEMA.format("passes"),
        "source": "hexa/campaign/geo.py (PASSES)",
        "note": "The 24 named passes. The game has 72 pass edges and passes in all, derived from these and the mountain "
                "lines (terrain.passes, worldgen.build_edges); the map reference (godot/data/map_reference.json) counts them.",
        "passes": [{"name": name, "lon": lon, "lat": lat} for name, lon, lat in geo.PASSES],
    }


def cities():
    return {
        "schema": SCHEMA.format("cities"),
        "source": "hexa/campaign/geo.py (CITIES)",
        "note": "size is the city's size as in the Python table (it sets the starting settlement and castle).",
        "cities": [{"name": name, "lon": lon, "lat": lat, "size": size} for name, lon, lat, size in geo.CITIES],
    }


def countries():
    return {
        "schema": SCHEMA.format("countries"),
        "source": "hexa/campaign/geo.py (COUNTRIES)",
        "note": "Territory seeds: each land hex belongs to the nearest seed (worldgen.build_countries), with the rules in "
                "builder_functions.json. The first seed is the capital. Names and colours are in data/countries.json.",
        "countries": [{"tag": tag, "seeds": points(seeds)} for tag, (_, _, seeds) in geo.COUNTRIES.items()],
    }


def markets():
    return {
        "schema": SCHEMA.format("markets"),
        "source": "hexa/campaign/geo.py (MARKETS)",
        "note": "colonial markets open once a colonial power owns land next to them.",
        "markets": [{"name": name, "lon": lon, "lat": lat, "colonial": colonial}
                    for name, lon, lat, colonial in geo.MARKETS],
    }


def tribes():
    return {
        "schema": SCHEMA.format("tribes"),
        "source": "hexa/campaign/geo.py (TRIBES)",
        "note": "Land nobody owns takes the tribe of the nearest point (worldgen.build_countries).",
        "tribes": [{"name": name, "lon": lon, "lat": lat} for name, lon, lat in geo.TRIBES],
    }


def region_tables():
    return {
        "schema": SCHEMA.format("regions"),
        "source": "hexa/campaign/regions.py (REGIONS, CITY_REGION)",
        "note": "tag is the country in 1480, or null. city_region maps a geo city to its region; each city is also an "
                "anchor of its region. Every land hex takes the region of its nearest anchor (naming.py).",
        "regions": [{"name": n, "lon": lon, "lat": lat, "tag": tag} for n, lon, lat, tag in regions.REGIONS],
        "city_region": dict(sorted(regions.CITY_REGION.items())),
    }


def naming():
    consts = module_constants(CAMPAIGN_DIR / "naming.py",
                              ["COMPASS", "OWN_WEIGHT", "SEA_PENALTY", "_CELL", "EXONYMS", "SKIP", "LAND_WORDS",
                               "COAST_WORDS", "RIVER_WORDS"])
    return {
        "schema": SCHEMA.format("naming"),
        "source": "hexa/campaign/naming.py (the constants; the functions are in builder_functions.json)",
        "compass": plain(consts["COMPASS"]),
        "own_weight": consts["OWN_WEIGHT"],
        "sea_penalty": consts["SEA_PENALTY"],
        "anchor_cell_degrees": consts["_CELL"],
        "exonyms": plain(consts["EXONYMS"]),
        "skip": plain(consts["SKIP"]),
        "land_words": plain(consts["LAND_WORDS"]),
        "coast_words": plain(consts["COAST_WORDS"]),
        "river_words": plain(consts["RIVER_WORDS"]),
    }


def place_names():
    doc = [line.strip() for line in (placenames.__doc__ or "").splitlines()]
    start = next((i for i, line in enumerate(doc) if "GeoNames" in line), None)
    if start is None:
        raise ValueError("the placenames credit is missing")
    credit = " ".join(doc[start:start + 2]).strip()
    if "GeoNames" not in credit or "CC BY 4.0" not in credit:
        raise ValueError("the placenames credit line changed; update the export")
    rows = []
    for line in placenames.PLACES.strip().splitlines():
        lon, lat, name = line.split("|")
        rows.append([float(lon), float(lat), name])
    return {
        "schema": SCHEMA.format("placenames"),
        "source": "hexa/campaign/placenames.py (PLACES)",
        "credit": {
            "text": credit,
            "source": "GeoNames",
            "url": "https://www.geonames.org",
            "licence": "CC BY 4.0",
            "licence_url": "https://creativecommons.org/licenses/by/4.0/",
            "note": "Must appear in the credits file of the Windows zip (plan B5, the release brief).",
        },
        "note": "One place per row: [longitude, latitude, name], biggest first. A hex gets the best three places in it "
                "(naming._places_by_hex). Names without diacritics for Cyrillic, Arabic and Greek.",
        "places": rows,
    }


def payload():
    """{path under godot/data/geography: JSON-ready object}."""
    return {
        "projection.json": projection(),
        "land.json": land(),
        "terrain_shapes.json": terrain_shapes(),
        "rivers.json": rivers(),
        "passes.json": passes(),
        "cities.json": cities(),
        "countries.json": countries(),
        "markets.json": markets(),
        "tribes.json": tribes(),
        "regions.json": region_tables(),
        "naming.json": naming(),
        "placenames.json": place_names(),
    }


def export(out_dir):
    out_dir = Path(out_dir)
    return {name: dump(out_dir / name, obj) for name, obj in payload().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(GEO_DIR), help="output folder (default godot/data/geography)")
    args = parser.parse_args(argv)
    for name, path in export(args.out).items():
        print(f"{path.stat().st_size:>9,d}  {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
