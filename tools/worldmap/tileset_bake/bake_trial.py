"""The M1 trial tileset: a small set of hex tiles baked from the Python map art, for the side-by-side with today's
whole-map bake (docs/design/map/m1_trial/notes.md).

    python tools/worldmap/tileset_bake/bake_trial.py --layers <layers.json> --needs <names.json> [--out DIR] [--jobs N]

--layers: not needed any more (the decor stage draws with tileset_bake/art.py and reads no map); kept so old calls work.
--needs:  the tile names the trial view asks for, written by godot/tools/mapview/dump_trial_tiles.gd; only the coast
          and piece tiles named there are baked (the other kinds are baked whole). Without it: no coast, no pieces.
Writes <out>/<source>.png and <out>/index.json (default out: godot/assets/tiles/trial). Summer only. Needs pygame.
"""
import argparse
import json
import multiprocessing
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--layers", default=os.environ.get("STYLE_FRAME_LAYERS"))
    ap.add_argument("--needs", default="")
    ap.add_argument("--out", default=os.path.join(REPO, "godot", "assets", "tiles", "trial"))
    ap.add_argument("--pieces", default=os.path.join(REPO, "godot", "assets", "worldmap", "north_italy", "pieces"))
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--only", default="", help="comma list of stages: flat,coast,decor,pieces (default: all)")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    stages = set(a.only.split(",")) if a.only else {"flat", "coast", "decor", "pieces"}
    needs = json.load(open(a.needs, encoding="utf-8"))["names"] if a.needs else []
    import pygame
    pygame.init()
    import coast_tiles
    import flat_tiles
    import lattice as LT
    import piece_tiles
    from tile_atlas import GridAtlas, from_rgba

    index_path = os.path.join(a.out, "index.json")
    sources = {}
    if os.path.exists(index_path):
        sources = {s["name"]: s for s in json.load(open(index_path, encoding="utf-8"))["sources"]}
    t0 = time.time()
    atlases = []
    if "flat" in stages:
        atlases += flat_tiles.bake()
    if "coast" in stages:
        jobs = []
        for name in sorted(n for n in needs if n.startswith("coast/")):
            p = name.split("/")
            jobs.append((int(p[2]), int(p[3]), p[1], len(p) > 4 and p[4] == "bay"))
        coast = GridAtlas("coast", (coast_tiles.C_W, coast_tiles.C_H))
        if jobs:
            with multiprocessing.get_context("spawn").Pool(min(a.jobs, len(jobs))) as pool:
                for name, raw in pool.map(coast_tiles.bake_one, jobs, chunksize=1):
                    coast.add(name, from_rgba(raw, coast.region))
        print("coast: %d tiles" % len(coast.tiles))
        atlases.append(coast)
    if "decor" in stages:
        import decor_tiles
        trees = GridAtlas("trees", (decor_tiles.T_W, decor_tiles.T_H))
        relief = GridAtlas("relief", (decor_tiles.R_W, decor_tiles.R_H))
        decor_tiles.bake(trees, relief)
        atlases += [trees, relief]
    if "pieces" in stages:
        baked = piece_tiles.BakedPieces(a.pieces)
        pieces = GridAtlas("pieces", (piece_tiles.P_W, piece_tiles.P_H), piece_tiles.P_ANCHOR)
        done = set()
        missing = []
        for name in sorted(n for n in needs if n.startswith("piece/")):
            _, family, level, variant, mirror, extra, _part = name.split("/")
            ident = (family, int(level), int(variant), int(mirror), extra)
            if ident in done:
                continue
            done.add(ident)
            key = baked.find(family, int(level), "summer", "-", int(variant), int(mirror), extra)
            if key is None:
                missing.append(name)
                continue
            shift = piece_tiles.addon_shift(extra) if family == "harbour_addon" else (0, 0)
            for part, surf in baked.parts(key, shift, family == "harbour_addon").items():
                sort = {"back": piece_tiles.BACK_SORT, "front": piece_tiles.FRONT_SORT}.get(part, 0)
                if family == "harbour_addon":
                    sort = 34 if shift[1] >= 0 else -34       # a harbour stands seaward of everything on its hex
                pieces.add(piece_tiles.piece_name(family, int(level), int(variant), int(mirror), extra, part), surf, y_sort=sort)
        print("pieces: %d tiles for %d pieces; %d without a picture %s" % (len(pieces.tiles), len(done), len(missing), missing[:4]))
        atlases.append(pieces)
    for atlas in atlases:
        sources[atlas.name] = atlas.save(a.out)
    order = ["ground", "shade", "coast", "trees", "relief", "pieces", "marks"]
    index = {"version": 1, "cell": [LT.CELL_W, LT.CELL_H], "season": "summer",
             "sources": [sources[n] for n in order if n in sources]}
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, separators=(",", ":"))
    total = sum(os.path.getsize(os.path.join(a.out, s["file"])) for s in index["sources"])
    tiles = sum(len(s["tiles"]) for s in index["sources"])
    print("wrote %s: %d sources, %d tiles, %.1f MB of PNG, %.0f s" % (index_path, len(index["sources"]), tiles, total / 1e6,
                                                                     time.time() - t0))
    return 0


if __name__ == "__main__":
    multiprocessing.freeze_support()
    sys.exit(main())
