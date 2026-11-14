"""Export the Age of Discovery game numbers and the Python builder's rules to godot/data/ (JSON).

Run from anywhere:  python tools/export_data.py [--out DIR]

Reads the frozen game (`hexa/`, imported and never edited) and writes:
- constants.json, terrain.json, goods.json, buildings.json, units.json, countries.json, wfc.json
- rules/builder_functions.json: the Python functions of the map builder as steps (see godot_export_common.function_ir)

The schema of every file is in godot/data/README.md. tests/test_godot_export.py runs this module into a temporary
folder and compares the result with the committed files.
"""
import argparse
import ast
import inspect
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.godot_export_common import CAMPAIGN_DIR, DATA_DIR, REPO, dump, function_ir, plain  # noqa: E402

from hexa.campaign import data, geo, wfc  # noqa: E402
from hexa.campaign.systems import worldgen  # noqa: E402

SCHEMA = "hexa-godot/{}/1"

# The Python functions the Godot map builder ports, by file (None = every top-level function of the file).
BUILDER_FUNCTIONS = {
    "hexa/hexgrid.py": ["neighbors", "to_cube", "distance", "within"],
    "hexa/campaign/geo.py": None,
    "hexa/campaign/systems/worldgen.py": None,
    "hexa/campaign/systems/terrain.py": ["pass_tables", "ridge_edges", "pass_edges", "passes", "pass_name", "geo_key"],
    "hexa/campaign/naming.py": None,
    "hexa/campaign/specialgoods.py": None,
    "hexa/campaign/wfc.py": None,
}


def levels(names, **columns):
    """One object per level (0 is the empty place or castle), from parallel tables."""
    out = []
    for i, name in enumerate(names):
        row = {"level": i, "name": name}
        for key, values in columns.items():
            row[key] = plain(values[i])
        out.append(row)
    return out


def affinity_in_build_map():
    """The affinity keyword that worldgen.build_map passes to wfc.collapse (read from its source)."""
    tree = ast.parse((CAMPAIGN_DIR / "systems" / "worldgen.py").read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and node.name == "build_map":
            for call in ast.walk(node):
                if isinstance(call, ast.Call):
                    for kw in call.keywords:
                        if kw.arg == "affinity" and isinstance(kw.value, ast.Constant):
                            return kw.value.value
    raise KeyError("worldgen.build_map passes no literal affinity")


def map_seed():
    """The seed of the Python Europe map: CampaignWorld's default for map='europe'."""
    from hexa.campaign.world import CampaignWorld
    return inspect.signature(CampaignWorld.__init__).parameters["seed"].default


def payload():
    """{path under godot/data: JSON-ready object}."""
    files = {}
    files["constants.json"] = {
        "schema": SCHEMA.format("constants"),
        "source": "hexa/campaign/data.py, hexa/campaign/geo.py, hexa/campaign/world.py",
        "area": data.AREA,
        "scale": geo.SCALE,
        "start_year": data.START_YEAR,
        "end_year": data.END_YEAR,
        "seasons": plain(data.SEASONS),
        "eras": [{"era": era, "name": v[0], "start_year": v[1], "third": v[2]} for era, v in sorted(data.ERAS.items())],
        "map_seed": map_seed(),
        "territory_radius": data.TERRITORY_RADIUS,
        "garrison_hp": data.GARRISON_HP,
        "garrison_men": data.GARRISON_MEN,
        "men": data.MEN,
    }
    files["terrain.json"] = {
        "schema": SCHEMA.format("terrain"),
        "source": "hexa/campaign/data.py (TERRAIN, ROUGH, NARROW_TERRAIN, OPEN_GROUND, ELEVATION)",
        "note": "density is people per hex in thousands, already divided by AREA. move null = not walkable.",
        "terrain": plain(list(data.TERRAIN.values())),
        "rough": plain(data.ROUGH),
        "narrow": plain(data.NARROW_TERRAIN),
        "open_ground": plain(data.OPEN_GROUND),
        "elevation": plain(data.ELEVATION),
    }
    files["goods.json"] = {
        "schema": SCHEMA.format("goods"),
        "source": "hexa/campaign/data.py (GOODS, FOODS, NEEDS, OUTPUT, PRICE_FLOOR, PRICE_CAP, ELASTICITY, FARM_GOODS)",
        "goods": plain(list(data.GOODS.values())),
        "foods": plain(data.FOODS),
        "farm_goods": plain(data.FARM_GOODS),
        "needs": plain(data.NEEDS),
        "output": plain(data.OUTPUT),
        "price_floor": data.PRICE_FLOOR,
        "price_cap": data.PRICE_CAP,
        "elasticity": data.ELASTICITY,
    }
    files["buildings.json"] = {
        "schema": SCHEMA.format("buildings"),
        "source": "hexa/campaign/data.py (BUILDINGS, WORKS*, SETTLEMENT*, CASTLE*, MANUFACTORIES...)",
        "note": "Sprite file names are art, not game numbers: they are not exported (the art baker reads them).",
        "buildings": plain(list(data.BUILDINGS.values())),
        "manufactories": plain(data.MANUFACTORIES),
        "plantation_goods": plain(data.PLANTATION_GOODS),
        "mine_goods": plain(data.MINE_GOODS),
        "build_turns": data.BUILD_TURNS,
        "works": {
            "levels": data.WORKS_LEVELS,
            "bonus": data.WORKS_BONUS,
            "cost": plain(data.WORKS_COST),
            "goods": plain(data.WORKS_GOODS),
            "era": plain(data.WORKS_ERA),
            "upkeep": data.WORKS_UPKEEP,
            "level_names": plain(data.WORKS),
        },
        "settlements": levels(data.SETTLEMENTS, cost=data.SETTLEMENT_COST, goods=data.SETTLEMENT_GOODS,
                              pop=data.SETTLEMENT_POP, slots=data.SETTLEMENT_SLOTS, tax=data.SETTLEMENT_TAX,
                              upkeep=data.SETTLEMENT_UPKEEP),
        "castles": levels(data.CASTLES, cost=data.CASTLE_COST, goods=data.CASTLE_GOODS, upkeep=data.CASTLE_UPKEEP,
                          area=data.CASTLE_AREA),
        "castle_defense": data.CASTLE_DEFENSE,
        "castle_siege": data.CASTLE_SIEGE,
    }
    files["units.json"] = {
        "schema": SCHEMA.format("units"),
        "source": "hexa/campaign/data.py (UNIT_KINDS, TROOPS, BRANCHES, STACK_*, MANPOWER)",
        "note": "troops are the war units by branch and era; troop(branch, era) in data.py is the lookup.",
        "unit_kinds": plain(list(data.UNIT_KINDS.values())),
        "troops": plain(list(data.TROOPS)),
        "branches": plain(data.BRANCHES),
        "branch_names": plain(data.BRANCH_NAMES),
        "general": plain(data.GENERAL),
        "stack": {"base": data.STACK_BASE, "limit_by_era": {str(era): n for era, n in data.STACK_LIMIT.items()},
                  "general": data.GENERAL_STACK, "civilian": data.CIVILIAN_LIMIT, "front": data.FRONT},
        "manpower": data.MANPOWER,
        "food_per_troop": data.FOOD_PER_TROOP,
        "colonist_people": data.COLONIST_PEOPLE,
    }
    countries = []
    for tag, (name, colour, points) in geo.COUNTRIES.items():
        lon, lat = points[0]
        countries.append({"tag": tag, "name": name, "colour": plain(colour), "capital": {"lon": lon, "lat": lat}})
    files["countries.json"] = {
        "schema": SCHEMA.format("countries"),
        "source": "hexa/campaign/geo.py (COUNTRIES, COLONIAL, COASTAL_KNOWLEDGE, KNOWN_WORLD)",
        "note": "Order is the dict order of geo.COUNTRIES and must be kept: the builder iterates in it. "
                "The capital is the first seed point; all seed points are in geography/countries.json. "
                "known_world_rule is the Python lambda, as text.",
        "countries": countries,
        "colonial_start": plain(geo.COLONIAL),
        "coastal_knowledge": plain(geo.COASTAL_KNOWLEDGE),
        "known_world_rule": "lon > -19.5 and lat > 11.5 and not (lat < 20 and lon > 20)",
    }
    files["wfc.json"] = {
        "schema": SCHEMA.format("wfc"),
        "source": "hexa/campaign/systems/worldgen.py (FORBIDDEN, build_map), hexa/campaign/wfc.py (collapse)",
        "note": "FORBIDDEN pairs may not touch (symmetric). The tile list is sorted by name. The weight of a tile in a "
                "cell is its prior times (1 + affinity * number of neighbours already with that tile). The random "
                "stream is Python's random.Random(seed): a GDScript port cannot reproduce it, so the same seed gives "
                "another map, judged by the counts (godot/data/README.md).",
        "forbidden": plain(worldgen.FORBIDDEN),
        "affinity_in_build_map": affinity_in_build_map(),
        "affinity_default": inspect.signature(wfc.collapse).parameters["affinity"].default,
        "rng_seed_for_terrain": "world.seed (the map seed, see constants.json map_seed)",
    }
    rules = {}
    for path, names in BUILDER_FUNCTIONS.items():
        for name, entry in function_ir(REPO / path, names).items():
            rules[f"{path}::{name}"] = {"file": path, "name": name, **entry}
    files["rules/builder_functions.json"] = {
        "schema": SCHEMA.format("builder-functions"),
        "note": "The Python map builder's functions as steps, read from the source by the AST (not run). Each step: "
                "when = the if-tests that hold (source text; an else is 'not (test)'); op = assign | set | return | "
                "loop | stmt. Values: literals, {name}, {dict: [[k, v]...]}, {list}, {expr: source}. Port them in order: a return ends the function, so a later step is reached only when the earlier returns did not fire.",
        "functions": rules,
    }
    return files


def export(out_dir):
    out_dir = Path(out_dir)
    return {name: dump(out_dir / name, obj) for name, obj in payload().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(DATA_DIR), help="output folder (default godot/data)")
    args = parser.parse_args(argv)
    for name, path in export(args.out).items():
        print(f"{path.stat().st_size:>9,d}  {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
