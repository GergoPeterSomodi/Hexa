"""Bakes the north Italy normal map's art into files the Godot project loads (see README.md in this folder).

    python tools/worldmap/godot_bake/bake.py [--out DIR] [--layers FILE] [--stages frame,pieces] [--jobs N] [--no-landmarks]

Defaults: --out godot/assets/worldmap/north_italy (from the repository root), --layers $STYLE_FRAME_LAYERS (the layers
file the style frame reads). Needs pygame only. Writes meta.json, base_/ground_/overlay_<season>.png, land_mask.png,
wild.json with wild_<season>*.png, placements.json and pieces/ (atlases and index.json).
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

SEASONS = ["spring", "summer", "autumn", "winter"]


def write_json(path, obj, indent=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, separators=(",", ":") if indent is None else None, indent=indent, ensure_ascii=False)


def frame_stage(out, jobs):
    """Base images, wild sprites and the hex data: one process per season (each builds the style frame's world)."""
    ctx = multiprocessing.get_context("spawn")
    tasks = [(s, out, s == "summer") for s in SEASONS]
    t0 = time.time()
    with ctx.Pool(min(jobs, 4)) as pool:
        res = {r["season"]: r for r in pool.map(_frame_task, tasks, chunksize=1)}
    print("frame stage: %.0f s" % (time.time() - t0))
    return res


def _frame_task(args):
    import frame_bake
    return frame_bake.run_task(args)


def merge_wild(res):
    """wild.json: one item per wild object, with a sprite and a shadow per season."""
    base = res["summer"]["wild"]
    items = []
    for i, o in enumerate(base):
        sprite, shadow = {}, {}
        for s in SEASONS:
            w = res[s]["wild"][i]
            assert w["foot"] == o["foot"] and w["kind"] == o["kind"] and w["sort_y"] == o["sort_y"], (s, i)
            sprite[s], shadow[s] = w["spr"], w["shd"]
        kind = o["kind"]
        items.append({"id": "%s%d" % ({"tree": "t", "hill": "h", "range": "r"}[kind], i), "hex": o["hex"], "foot": o["foot"],
                      "sort_y": o["sort_y"], "sort_x": o["x"], "kind": kind, "species": o["species"],
                      "removable": True, "group": o["group"], "sprite": sprite, "shadow": shadow})
    atlases = {s: [{"file": "%s.png" % st, "size": [w, h]} for st, w, h in res[s]["wild_files"]] for s in SEASONS}
    return {"version": 1, "note": "sprite and shadow are per season: sprite[season] = {atlas, rect, offset} (offset from foot to the "
                                  "sprite's top-left, image px); sort by (sort_y, sort_x)", "atlases": atlases, "items": items}


def key_for(p, season):
    """The index key of a placement of the compositor, for a season."""
    from pieces_bake import key_of
    extra = "-"
    kw = p["kw"]
    if "animal" in kw:
        extra = kw["animal"]
    elif "ore" in kw:
        extra = kw["ore"]
    fam = "harbour_addon" if p["addon"] else p["family"]
    clim = p["climate"] if season == "winter" else "-"
    if p["sea"] is not None:
        extra = "hex:%d,%d%s" % (p["hex"][0], p["hex"][1], "+addon" if p["addon"] else "")
    variant = kw.get("variant", p["variant"])
    return key_of(dict(family=fam, level=p["level"], season=season, climate=clim, variant=variant, mirror=p["mirror"], extra=extra))


def exact_specs(placements):
    """The coastal placements of the compositor as pieces of their own shore (extra "hex:c,r"): a piece that stands on the
    map's own shore line, with its bay if the port is carved."""
    from pieces_bake import season_groups
    out = []
    for p in placements:
        if p["sea"] is None:
            continue
        kw = dict(p["kw"])
        variant = kw.pop("variant", p["variant"])
        mod = p["family"]
        fam = "harbour_addon" if p["addon"] else mod
        if p["addon"]:
            kw["addon"] = True
        for season, climate in season_groups():
            if season == "winter" and climate != p["climate"]:
                continue
            out.append(dict(family=fam, module=mod, level=p["level"], variant=variant, mirror=p["mirror"], season=season,
                            climate=climate, extra="hex:%d,%d%s" % (p["hex"][0], p["hex"][1], "+addon" if p["addon"] else ""),
                            kw=kw, sea=p["sea"], shore=[tuple(q) for q in p["shore"]], bay=tuple(p["bay"]) if p["bay"] else None))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(REPO, "godot", "assets", "worldmap", "north_italy"))
    ap.add_argument("--layers", default=os.environ.get("STYLE_FRAME_LAYERS"))
    ap.add_argument("--stages", default="frame,pieces")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--no-landmarks", action="store_true", help="leave out the landmark cities' settlements (not on this map)")
    a = ap.parse_args(argv)
    out = os.path.abspath(a.out)
    stages = a.stages.split(",")
    os.makedirs(out, exist_ok=True)
    if a.layers:
        os.environ["STYLE_FRAME_LAYERS"] = os.path.abspath(a.layers)
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    pdir = os.path.join(out, "pieces")
    placements = None
    if "frame" in stages:
        if not os.environ.get("STYLE_FRAME_LAYERS"):
            sys.exit("the frame stage needs --layers (or STYLE_FRAME_LAYERS): the layers file the style frame reads")
        res = frame_stage(out, a.jobs)
        s = res["summer"]
        wild = merge_wild(res)
        write_json(os.path.join(out, "wild.json"), wild)
        meta = {"version": 1, "radius_px": 60, "tilt": s["tilt"], "px_per_km": s["px_per_km"], "origin_km": s["origin_km"],
                "size_px": s["size"], "seasons": SEASONS, "hex_w_km": s["hex_w_km"], "hexes": s["hexes"]}
        write_json(os.path.join(out, "meta.json"), meta)
        placements = s["placements"]
        for p in placements:                                    # which key each placement of the compositor uses, per season
            p["keys"] = {sn: key_for(p, sn) for sn in SEASONS}
        write_json(os.path.join(out, "placements.json"), {"version": 1, "placements": placements})
        print("wrote meta.json (%d hexes), wild.json (%d objects), placements.json (%d)" % (len(meta["hexes"]), len(wild["items"]), len(placements)))
    if "pieces" in stages:
        import pieces_bake as PB
        if placements is None:
            placements = json.load(open(os.path.join(out, "placements.json"), encoding="utf-8"))["placements"]
        specs = PB.expand(PB.enumerate_specs(landmarks=not a.no_landmarks)) + exact_specs(placements)
        print("pieces: %d pictures" % len(specs))
        index, errors, files = PB.bake_pieces(pdir, specs, a.jobs)
        for k, e in errors:
            print("PIECE ERROR", k, e)
        atl = {name: [{"file": "%s.png" % st, "size": [w, h]} for st, w, h in fl] for name, fl in files.items()}
        write_json(os.path.join(pdir, "index.json"), {"version": 1, "key": "family|level|season|climate|variant|mirror|extra",
                                                      "atlases": atl, "pieces": index})
        for p in placements:
            p["keys"] = {sn: key_for(p, sn) for sn in SEASONS}
            for k in p["keys"].values():
                if k not in index:
                    print("MISSING KEY", k)
        total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(out) for f in fs)
        print("pieces: %d keys, %d errors; everything under %s: %.1f MB" % (len(index), len(errors), out, total / 1e6))
    return 0


if __name__ == "__main__":
    multiprocessing.freeze_support()
    sys.exit(main())
