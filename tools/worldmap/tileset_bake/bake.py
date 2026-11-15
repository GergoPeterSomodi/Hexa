"""The full tile bake (spec: docs/architecture/m1-build-spec.md section 3): every tile of every set, on any map.

    python tools/worldmap/tileset_bake/bake.py [--out godot/assets/tiles] [--sets summer,winter_snow] [--jobs N]

Writes <out>/<set>/index.json and the atlases for the six sets spring, summer, autumn, winter_snow, winter_frost and
winter_mild: ground, shade, coast_<n>, trees, relief, pieces_<n> (three picture sizes) and marks. All six sets have the
same tiles at the same places; `shade.png` and `marks.png` are the same picture in every set (drawn once, copied).
The bake reads no map and no layers file: the art is code (flat_tiles, coast_tiles, decor_tiles with art.py, and the
pieces kit through tools/worldmap/godot_bake/pieces_bake.render). Needs pygame only. No `.import` files are written.

The work is cut into tasks (one coast tile, one cover, one tree kind, a chunk of pieces...) and spread over a pool of
processes; the parent builds the atlases from what comes back.
"""
import argparse
import json
import multiprocessing
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GODOT_BAKE = os.path.join(REPO, "tools", "worldmap", "godot_bake")
sys.path.insert(0, HERE)
sys.path.append(GODOT_BAKE)             # after HERE: godot_bake has a bake.py too
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

# set name -> (season, climate)
SETS = {"spring": ("spring", "snow"), "summer": ("summer", "snow"), "autumn": ("autumn", "snow"),
        "winter_snow": ("winter", "snow"), "winter_frost": ("winter", "frost"), "winter_mild": ("winter", "mild")}
CHUNK = 24
QUICK_COAST = [(3, 0, "beach", False), (48, 2, "beach", True), (9, 4, "cliff", False), (6, 1, "beach", False)]
QUICK_MODULES = ("wheat", "harbour")
# Landmarks a place of the map can carry that the kit draws no monument for (it knows the ten famous cities, at levels 4 and
# 5). The settlement stands as usual, under the landmark's own tile name, at every settlement level: MapCells names
# piece/settlements/<level>/<variant>/<mirror>/<landmark>/<part> for any level of such a place.
PLAIN_LANDMARKS = ("hospice", "monastery")


# ---------------------------------------------------------------- the names (no drawing: the tests count with these)
def ground_names():
    import flat_tiles as F
    out = []
    for cover in F.COVERS:
        for band in range(F.BANDS if cover in F.GREEN else 1):
            for v in range(F.GROUND_VARIANTS):
                out.append(("ground/%s/%d/%d" % (cover, band, v), F.RANK[cover]))
    for depth in ("shelf", "sea", "deep"):
        for v in range(F.SEA_VARIANTS):
            out.append(("sea/%s/%d" % (depth, v), F.SEA_RANK[depth]))
    return out


def coast_names():
    import coast_tiles as C
    return [C.tile_name(*t) for t in C.all_tiles()]


def tree_names():
    import decor_tiles as D
    return ["trees/%s/%s/%d/%d" % (k, o, d, v) for k in D.TREE_KINDS for o in D.TREE_OPTS for d in range(6)
            for v in range(D.TREE_VARIANTS)]


def relief_names():
    import decor_tiles as D
    return ["relief/%s/%s/%d" % (k, f, v) for k in D.RELIEF_KINDS for f in D.RELIEF_FORMS for v in range(D.RELIEF_VARIANTS)]


# ---------------------------------------------------------------- the workers
def _init_worker():
    sys.stdout = open(os.devnull, "w")
    _setup()


def _setup():
    import pygame
    pygame.init()
    pygame.display.set_mode((5, 5))
    if GODOT_BAKE not in sys.path:
        sys.path.append(GODOT_BAKE)


_PALS = {}


def _pal(set_name):
    import flat_tiles
    if set_name not in _PALS:
        _PALS[set_name] = flat_tiles.palette(*SETS[set_name])
    return _PALS[set_name]


def _raw(surf):
    import pygame
    return pygame.image.tobytes(surf, "RGBA")


def run_task(task):
    """Pool entry: a task tuple -> (task, result). Results are plain bytes and tuples."""
    import pygame
    pygame.init()
    kind = task[0]
    if kind == "coast":
        import coast_tiles
        order = task[2]
        spec = task[1]
        return task, (coast_tiles.tile_name(*spec), coast_tiles.bake_sets((spec, [_pal(n) for n in order]))[1])
    if kind == "ground":
        import flat_tiles as F
        _, name, cover = task
        pal = _pal(name)
        out = []
        for band in range(F.BANDS if cover in F.GREEN else 1):
            for v in range(F.GROUND_VARIANTS):
                out.append(("ground/%s/%d/%d" % (cover, band, v), _raw(F.ground_tile(cover, band, v, pal))))
        return task, out
    if kind == "sea":
        import flat_tiles as F
        _, name, depth = task
        pal = _pal(name)
        return task, [("sea/%s/%d" % (depth, v), _raw(F.sea_tile(depth, v, pal))) for v in range(F.SEA_VARIANTS)]
    if kind == "shared":
        import flat_tiles as F
        from tile_atlas import GridAtlas
        shade = GridAtlas("shade", (F.S_W, F.S_H))
        F.shade_tiles(shade)
        marks = GridAtlas("marks", (F.G_W, F.G_H))
        marks.add("mark/grid", F.grid_tile())
        marks.add("mark/select", F.select_tile())
        marks.add("mark/target", F.target_tile())
        marks.add("mark/white", F.white_tile())
        import mark_tiles as MT
        for tname, surf, sort in MT.all_tiles():            # fords, bridges, ferries and pass marks (T15)
            marks.add(tname, surf, y_sort=sort)
        return task, {a.name: (a.region, [(t["name"], _raw(s)) for t, s in zip(a.tiles, a.surfs)]) for a in (shade, marks)}
    if kind == "trees":
        import art
        import decor_tiles as D
        _, name, tkind = task
        season, climate = SETS[name]
        painter = art.Painter(season, climate)
        out = []
        for opt in D.TREE_OPTS:
            for d in range(6):
                for v in range(D.TREE_VARIANTS):
                    out.append(("trees/%s/%s/%d/%d" % (tkind, opt, d, v), _raw(D.tree_tile(painter, d, tkind, opt, v))))
        return task, out
    if kind == "relief":
        import art
        import decor_tiles as D
        _, name, rkind = task
        season, climate = SETS[name]
        painter = art.Painter(season, climate)
        return task, [("relief/%s/%s/%d" % (rkind, f, v), _raw(D.relief_tile(painter, rkind, f, v)))
                      for f in D.RELIEF_FORMS for v in range(D.RELIEF_VARIANTS)]
    if kind == "pieces":
        import pieces_bake as PB
        import piece_tiles as PT
        _, name, chunk = task
        season, climate = SETS[name]
        out = []
        for idx, sp in chunk:
            sp = dict(sp, season=season, climate=climate if season == "winter" else "-")
            try:
                r = PB.render(sp)
            except Exception as e:                      # one bad piece must not stop the bake: report it with its key
                out.append((idx, None, "%s: %s" % (type(e).__name__, e)))
                continue
            if r is None:
                out.append((idx, None, None))
                continue
            shift = PT.addon_shift(sp["extra"]) if sp["family"] == "harbour_addon" else (0, 0)
            out.append((idx, PT.layers_of(r, shift, sp["family"] == "harbour_addon"), None))
        return task, out
    raise ValueError(kind)


# ---------------------------------------------------------------- the parent
def _surf(raw, size):
    from tile_atlas import from_rgba
    return from_rgba(raw, size)


def piece_specs(quick=False):
    import pieces_bake as PB
    specs = PB.enumerate_specs()
    plain = [s for s in specs if s["family"] == "settlements" and s["extra"] == "-"]
    for name in PLAIN_LANDMARKS:
        specs += [dict(s, extra=name) for s in plain]
    if quick:
        specs = [s for s in specs if s["module"] in QUICK_MODULES and s["level"] <= 2]
    return specs


def piece_ident(sp):
    return (sp["family"], sp["level"], sp["variant"], int(sp["mirror"]), sp["extra"])


def plan_pieces(specs, per_set):
    """per_set: {set: {idx: layers}}. Returns [(size, name, idx, part, anchor, y_sort, {set: items})] sorted by (size, name),
    and the list of problems. Every set gets every tile (a blank where a set has no such part), the size and the anchor
    come from the union of the boxes over the sets."""
    import piece_tiles as PT
    plan, problems = [], []
    for idx, sp in enumerate(specs):
        got = {n: per_set[n].get(idx) for n in per_set}
        have = [lay for lay in got.values() if lay]
        if not have:
            continue
        box = PT.union_box([PT.box_of(lay) for lay in have if PT.box_of(lay)] or [None])
        size = PT.size_for(box)
        if size is None:
            problems.append("%s is %d x %d px, bigger than %d" % (piece_ident(sp), box[2] - box[0], box[3] - box[1], PT.SIZES[-1]))
            continue
        anchor = PT.anchor_for(size, box)
        parts = sorted({p for lay in have for p in lay})
        shift = PT.addon_shift(sp["extra"]) if sp["family"] == "harbour_addon" else (0, 0)
        for part in parts:
            name = PT.piece_name(sp["family"], sp["level"], sp["variant"], sp["mirror"], sp["extra"], part)
            plan.append((size, name, idx, part, anchor, PT.sort_of(sp["family"], part, shift),
                         {n: (lay or {}).get(part, []) for n, lay in got.items()}))
    plan.sort(key=lambda p: (p[0], p[1]))
    return plan, problems


def build_set(name, out_dir, results, shared, pieces_plan, log):
    """Builds and saves one set's atlases and index from the collected results. Returns (index dict, PNG bytes)."""
    import coast_tiles as C
    import decor_tiles as D
    import flat_tiles as F
    from tile_atlas import GridAtlas, Packer
    os.makedirs(out_dir, exist_ok=True)
    atlases = []
    ground = GridAtlas("ground", (F.G_W, F.G_H))
    by = {}
    for task, res in results.get(name, []):
        if task[0] in ("ground", "sea", "trees", "relief"):
            for tname, raw in res:
                by[tname] = raw
    for tname, z in ground_names():
        ground.add(tname, _surf(by.pop(tname), ground.region), z=z)
    atlases.append(ground)
    atlases.append("shade")
    coast = Packer("coast_", (C.C_W, C.C_H))
    order = results["_order"]
    k = order.index(name)
    for tname in coast_names():
        if tname not in results["_coast"]:
            continue                                    # a quick bake draws only some of them
        coast.add(tname, _surf(results["_coast"][tname][k], coast.region))
    atlases += coast.atlases
    trees = GridAtlas("trees", (D.T_W, D.T_H))
    for tname in tree_names():
        d = int(tname.split("/")[3])
        trees.add(tname, _surf(by.pop(tname), trees.region), anchor=D.T_ANCHOR[d], y_sort=D.T_SORT[d])
    relief = GridAtlas("relief", (D.R_W, D.R_H), D.R_ANCHOR)
    for tname in relief_names():
        form = tname.split("/")[2]
        relief.add(tname, _surf(by.pop(tname), relief.region), y_sort=D.relief_sort(form))
    atlases += [trees, relief]
    import piece_tiles as PT
    packers = {}
    for size, pname, _idx, _part, anchor, sort, items in pieces_plan:
        if size not in packers:
            packers[size] = Packer("pieces_", (size, size))
        packers[size].add(pname, PT.compose(items[name], size, anchor), anchor=anchor, y_sort=sort)
    n = 0
    for size in sorted(packers):                 # number the piece sources 0, 1, 2... over all sizes
        for a in packers[size].atlases:
            a.name = "pieces_%d" % n
            n += 1
            atlases.append(a)
    atlases.append("marks")
    sources = []
    for a in atlases:
        if isinstance(a, str):
            sources.append(shared[a])
            continue
        sources.append(a.save(out_dir))
        log("   %s: %d tiles" % (a.name, len(a.tiles)))
    for a in ("shade", "marks"):
        src = os.path.join(shared["_dir"], a + ".png")
        shutil.copyfile(src, os.path.join(out_dir, a + ".png"))
    import lattice as LT
    index = {"version": 1, "cell": [LT.CELL_W, LT.CELL_H], "set": name, "sources": sources}
    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, separators=(",", ":"))
    return index


def make_tasks(sets, quick):
    import flat_tiles as F
    import decor_tiles as D
    import coast_tiles as C
    tasks = []
    coast = QUICK_COAST if quick else C.all_tiles()
    tasks += [("coast", t, tuple(sets)) for t in coast]
    specs = piece_specs(quick)
    indexed = list(enumerate(specs))
    for n in sets:
        for i in range(0, len(indexed), CHUNK):
            tasks.append(("pieces", n, indexed[i:i + CHUNK]))
    tasks.append(("shared",))
    for n in sets:
        tasks += [("ground", n, c) for c in F.COVERS]
        tasks += [("sea", n, d) for d in ("shelf", "sea", "deep")]
        tasks += [("trees", n, k) for k in D.TREE_KINDS]
        tasks += [("relief", n, k) for k in D.RELIEF_KINDS]
    return tasks, specs


def run(out_root, sets=None, jobs=None, quick=False, log=print):
    """Bakes the sets into out_root/<set>/. quick: a few coast tiles and pieces only (for the test). Returns {set: index}."""
    import pygame
    pygame.init()
    sets = list(sets or SETS)
    jobs = jobs or max(1, (os.cpu_count() or 2) - 1)
    t0 = time.time()
    tasks, specs = make_tasks(sets, quick)
    log("%d tasks, %d pieces, %d sets, %d processes" % (len(tasks), len(specs), len(sets), jobs))
    results = {n: [] for n in sets}
    results["_coast"] = {}
    results["_order"] = sets
    piece_res = {n: {} for n in sets}
    errors = []
    shared_res = None
    done = 0
    ctx = multiprocessing.get_context("spawn")
    if sys.path[0] != HERE:                     # importing pieces_bake put godot_bake first; the workers must find this bake.py
        sys.path.insert(0, HERE)
    with ctx.Pool(jobs, initializer=_init_worker) as pool:
        for task, res in pool.imap_unordered(run_task, tasks, chunksize=1):
            done += 1
            kind = task[0]
            if kind == "coast":
                results["_coast"][res[0]] = res[1]
            elif kind == "shared":
                shared_res = res
            elif kind == "pieces":
                for idx, lay, err in res:
                    if err:
                        errors.append((piece_ident(specs[idx]), err))
                    elif lay:
                        piece_res[task[1]][idx] = lay
            else:
                results[task[1]].append((task, res))
            if done % 100 == 0 or done == len(tasks):
                log("  %d / %d tasks, %.0f s" % (done, len(tasks), time.time() - t0))
    log("drawn in %.0f s; %d piece errors" % (time.time() - t0, len(errors)))
    for e in errors[:10]:
        log("   piece error %s" % (e,))
    # the files shared by every set
    from tile_atlas import GridAtlas
    import mark_tiles as MT
    shared_dir = os.path.join(out_root, "_shared")
    os.makedirs(shared_dir, exist_ok=True)
    shared = {"_dir": shared_dir}
    for aname, (region, tiles) in shared_res.items():
        atlas = GridAtlas(aname, region)
        for tname, raw in tiles:
            atlas.add(tname, _surf(raw, region), y_sort=MT.y_sort(tname))
        shared[aname] = atlas.save(shared_dir)
    plan, problems = plan_pieces(specs, piece_res)
    for p in problems:
        log("   PIECE TOO BIG: %s" % p)
    log("pieces: %d tiles per set" % len(plan))
    indexes = {}
    for n in sets:
        log("set %s" % n)
        indexes[n] = build_set(n, os.path.join(out_root, n), results, shared, plan, log)
        for tname in [t for t in results["_coast"]]:
            results["_coast"][tname][results["_order"].index(n)] = None      # free the memory
    shutil.rmtree(shared_dir)
    for n, ix in indexes.items():
        total = sum(os.path.getsize(os.path.join(out_root, n, s["file"])) for s in ix["sources"])
        log("%s: %d sources, %d tiles, %.1f MB of PNG" % (n, len(ix["sources"]), sum(len(s["tiles"]) for s in ix["sources"]),
                                                           total / 1e6))
    log("done in %.0f s" % (time.time() - t0))
    return indexes


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(REPO, "godot", "assets", "tiles"))
    ap.add_argument("--sets", default="", help="comma list of %s (default: all six)" % ", ".join(SETS))
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--quick", action="store_true", help="a few coast tiles and pieces only")
    a = ap.parse_args(argv)
    sets = [s for s in a.sets.split(",") if s] or list(SETS)
    for s in sets:
        if s not in SETS:
            ap.error("unknown set %s" % s)
    run(a.out, sets, a.jobs, a.quick)
    return 0


if __name__ == "__main__":
    multiprocessing.freeze_support()
    sys.exit(main())
