"""TRIAL ONLY: the map facts the M1 trial view draws, as one JSON file.

The trial has no MapData yet (the build writes it with godot/tools/build_map.gd, see docs/architecture/m1-build-spec.md),
so this script copies the same facts out of the map prototype's exported layers file (the output of core/mapgen: relief
levels, cover, sea depth, rivers, streams, road edges, crests) and the heights file. Nothing is drawn or decided here.

    python tools/worldmap/tileset_bake/trial_map.py --layers <layers.json> [--out godot/assets/tiles/trial/trial_map.json]
"""
import argparse
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
COVERS = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--layers", default=os.environ.get("STYLE_FRAME_LAYERS"))
    ap.add_argument("--out", default=os.path.join(REPO, "godot", "assets", "tiles", "trial", "trial_map.json"))
    a = ap.parse_args(argv)
    layers = json.load(open(a.layers, encoding="utf-8"))
    heights = json.load(open(os.path.join(REPO, "godot", "data", "worldmap", "heights_alps_po.json"), encoding="utf-8"))
    meta = json.load(open(os.path.join(REPO, "godot", "assets", "worldmap", "north_italy", "meta.json"), encoding="utf-8"))
    window = {(h["c"], h["r"]) for h in meta["hexes"]}
    metres = {(h["c"], h["r"]): (h["height_m"] if h["land"] else 0.0) for h in heights["hexes"]}
    hexes = []
    for c, r, level, cover, _shade, _x, water, _lagoon in layers["hexes"]:
        land = level > 0
        hexes.append({"c": c, "r": r, "land": land, "level": level, "cover": COVERS[cover] if land else "",
                      "height_m": round(float(metres.get((c, r), 0.0)), 1), "depth": water if not land else "",
                      "window": (c, r) in window})
    grid = layers["grid"]
    out = {
        "note": "TRIAL ONLY: facts copied from the map prototype's layers file; the build reads MapData instead",
        "hex_w_km": grid["hex_w_km"], "hex_h_km": grid["hex_h_km"],
        "hexes": hexes,
        "rivers": [{"name": rv["name"], "class": rv["class"], "pts_km": [[round(p[0], 3), round(p[1], 3)] for p in rv["pts"]]}
                   for rv in layers["rivers"]],
        "streams": layers["streams"],
        "road_edges": layers["road_edges"],
        "crests": [e[:4] for e in layers["crests"]],
    }
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    print("wrote %s: %d hexes (%d in the window), %d rivers, %d road edges" % (a.out, len(hexes), len(window), len(out["rivers"]),
                                                                              len(out["road_edges"])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
