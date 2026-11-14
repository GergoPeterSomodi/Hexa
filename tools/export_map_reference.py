"""Measure the Python Europe 1480 at eight seeds and write the reference the Godot map is checked against.

Run from anywhere:  python tools/export_map_reference.py [--out FILE]

Builds the Python world (`CampaignWorld(seed, map="europe")`) for seed 1480 and seeds 1 to 7, and writes
godot/data/map_reference.json with:
- "equal": facts no seed changes in Python (the grid, the hex classes, cities, rivers, ridges and passes, countries,
  castles 2 and 3, towns 2 and 3, names), with the value at seed 1480 and whether all seeds agree;
- "close": counts that luck moves (terrain mix, towers, small towns, roads, provinces and population, goods, starting
  units) as the value at 1480 and the min, median and max over the eight seeds;
- "hexes_1480": the per-hex facts of seed 1480 (hex class, owner) that the per-hex equal rules compare, one string per row.

The rules that use these numbers are in the brief's "The new Europe is checked" section and in godot/data/README.md.
"""
import argparse
import statistics
import sys
from collections import Counter
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.godot_export_common import DATA_DIR, dump, plain  # noqa: E402

from hexa.campaign import geo  # noqa: E402
from hexa.campaign.world import CampaignWorld  # noqa: E402

SCHEMA = "hexa-godot/map-reference/1"
SEEDS = [1480, 1, 2, 3, 4, 5, 6, 7]
REFERENCE_SEED = 1480
OWNER_CODES = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"


def hexes(positions):
    return sorted([list(p) for p in positions])


def measure(seed):
    """Every count of one seed, as plain numbers and lists."""
    world = CampaignWorld(seed=seed, map="europe")
    provinces = list(world.provinces.values())
    land = provinces
    classes = Counter("lake" if t == "lake" else "ocean" if t == "ocean" else "land" for t in world.terrain.values())
    names = [p.name for p in land]
    goods = Counter(p.good for p in land if p.good)
    owned = Counter(p.owner for p in land if p.owner)
    pop = {tag: sum(p.pop for p in world.provinces_of(tag)) for tag in world.countries}
    units = world.units
    kinds = Counter(u.kind.key for u in units)
    per_country_units = {tag: Counter(u.kind.key for u in units if u.owner == tag) for tag in world.countries}
    return {
        "classes": dict(classes),
        "grid": [geo.COLS, geo.ROWS],
        "coastal": sum(1 for p in land if p.coastal),
        "cities": hexes(world.cities),
        "city_names": sorted(v[0] for v in world.cities.values()),
        "rivers": len(world.rivers),
        "river_hexes": len(world.river_at),
        "ridge_edges": len(world.ridge_edges()),
        "pass_edges": len(world.pass_edges()),
        "pass_hexes": len(world.passes()),
        "countries": len(world.countries),
        "capitals": {tag: list(c.capital) for tag, c in sorted(world.countries.items())},
        "castle2": hexes(p.pos for p in land if p.castle == 2),
        "castle3": hexes(p.pos for p in land if p.castle == 3),
        "towers": sum(1 for p in land if p.castle == 1),
        "towns2": hexes(p.pos for p in land if p.settlement == 2),
        "towns3": hexes(p.pos for p in land if p.settlement == 3),
        "small_towns": sum(1 for p in land if p.settlement == 1),
        "names": len(names),
        "names_distinct": len(set(names)),
        "names_empty": sum(1 for n in names if not n),
        "terrain_mix": dict(Counter(p.terrain for p in land)),
        "roads": len(world.roads),
        "road_paths": len(world.road_paths),
        "owned": sum(owned.values()),
        "owned_by": dict(owned),
        "population": sum(pop.values()),
        "population_by": pop,
        "goods": dict(goods),
        "goods_present": len(goods),
        "no_good": sum(1 for p in land if not p.good),
        "units": sum(kinds.values()),
        "unit_kinds": dict(kinds),
        "unit_kinds_by": {tag: dict(c) for tag, c in per_country_units.items()},
        "units_on_land": sum(1 for u in units if world.is_land(u.pos)),
        "owner_rows": [[world.provinces[(c, r)].owner if (c, r) in world.provinces else None
                        for c in range(geo.COLS)] for r in range(geo.ROWS)],
        "class_rows": [[("K" if world.terrain[(c, r)] == "lake" else "O" if world.terrain[(c, r)] == "ocean" else "L")
                        for c in range(geo.COLS)] for r in range(geo.ROWS)],
    }


def equal_fact(per_seed):
    """A fact that must not move: its value at seed 1480, and whether every seed agrees."""
    base = per_seed[REFERENCE_SEED]
    agree = all(per_seed[s] == base for s in SEEDS)
    out = {"value": base, "same_in_all_seeds": agree}
    if not agree:
        out["per_seed"] = {str(s): per_seed[s] for s in SEEDS}
    return out


def close_fact(per_seed):
    """A count that luck moves: its value at seed 1480 and the range over the seeds."""
    values = [per_seed[s] for s in SEEDS]
    if isinstance(values[0], dict):
        keys = sorted({k for v in values for k in v})
        return {k: close_fact({s: per_seed[s].get(k, 0) for s in SEEDS}) for k in keys}
    return {"value": per_seed[REFERENCE_SEED], "min": min(values), "median": statistics.median(values),
            "max": max(values)}


def build():
    runs = {seed: measure(seed) for seed in SEEDS}
    ref = runs[REFERENCE_SEED]

    def across(key):
        return {s: runs[s][key] for s in SEEDS}

    equal = {
        "grid": equal_fact(across("grid")),
        "hex_classes": equal_fact({s: runs[s]["classes"] for s in SEEDS}),
        "coastal_provinces": equal_fact(across("coastal")),
        "cities": equal_fact(across("cities")),
        "city_names": equal_fact(across("city_names")),
        "rivers": equal_fact(across("rivers")),
        "river_hexes": equal_fact(across("river_hexes")),
        "ridge_edges": equal_fact(across("ridge_edges")),
        "pass_edges": equal_fact(across("pass_edges")),
        "passes": equal_fact(across("pass_hexes")),
        "countries": equal_fact(across("countries")),
        "capitals": equal_fact(across("capitals")),
        "castle2": equal_fact(across("castle2")),
        "castle3": equal_fact(across("castle3")),
        "towns2": equal_fact(across("towns2")),
        "towns3": equal_fact(across("towns3")),
        "names_all_distinct": equal_fact({s: runs[s]["names"] == runs[s]["names_distinct"] for s in SEEDS}),
        "names_none_empty": equal_fact({s: runs[s]["names_empty"] == 0 for s in SEEDS}),
    }
    close = {
        "terrain_mix": close_fact(across("terrain_mix")),
        "towers": close_fact(across("towers")),
        "small_towns": close_fact(across("small_towns")),
        "roads_hexes": close_fact(across("roads")),
        "road_paths": close_fact(across("road_paths")),
        "owned_provinces": close_fact(across("owned")),
        "owned_by_country": close_fact(across("owned_by")),
        "population": close_fact(across("population")),
        "population_by_country": close_fact(across("population_by")),
        "goods_per_kind": close_fact(across("goods")),
        "goods_present": close_fact(across("goods_present")),
        "provinces_without_good": close_fact(across("no_good")),
        "starting_units": close_fact(across("units")),
        "starting_unit_kinds": close_fact(across("unit_kinds")),
        "starting_units_by_country": close_fact(across("unit_kinds_by")),
        "starting_units_on_land": close_fact(across("units_on_land")),
    }
    owner_codes = [""] + sorted({v for row in ref["owner_rows"] for v in row if v})
    code_of = {tag: OWNER_CODES[i] for i, tag in enumerate(owner_codes) if tag}
    code_of[None] = "_"
    class_codes = {"L": "land", "O": "ocean", "K": "lake"}
    hexes_1480 = {
        "cols": geo.COLS,
        "rows": geo.ROWS,
        "class_codes": class_codes,
        "class_rows": ["".join(row) for row in ref["class_rows"]],
        "owner_codes": {code: tag for tag, code in code_of.items() if tag},
        "owner_rows": ["".join(code_of[v] if v else "_" for v in row) for row in ref["owner_rows"]],
        "note": "one character per hex, column by column; owner '_' = no owner (ocean or lake, or unowned land).",
    }
    # ref["owner_rows"] holds the owner of a province; ocean and lake hexes have none.
    return {
        "schema": SCHEMA,
        "source": "tools/export_map_reference.py: CampaignWorld(seed, map='europe') for each seed",
        "seeds": SEEDS,
        "reference_seed": REFERENCE_SEED,
        "note": "Measured on the Python game at v0.2.2 (the frozen model). 'equal' facts must match in Godot; 'close' "
                "facts must fall in their rule's range (the brief, The new Europe is checked). Rows are sorted by "
                "row, then column.",
        "equal": equal,
        "close": close,
        "hexes_1480": hexes_1480,
    }


def export(out_file):
    return dump(out_file, plain(build()))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(DATA_DIR / "map_reference.json"), help="output file")
    args = parser.parse_args(argv)
    path = export(args.out)
    print(f"{path.stat().st_size:>9,d}  {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
