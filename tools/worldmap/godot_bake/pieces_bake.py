"""The pieces stage of the Godot bake: every piece of tools/worldmap/pieces as layers (ground detail, shadow, standing
things, footprint) in atlases, with an index keyed "family|level|season|climate|variant|mirror|extra".

Does not import the style frame (the pieces' sites.py and the frame's sites.py have the same name). The layers are cut
the way tools/worldmap/pieces_in_map/compose.py cuts them (take_apart there): the ground detail premultiplied, feathered
at the hex border and smoothscaled from 2x; every standing thing smoothscaled alone and cut to its box. Straight alpha
in the PNGs: a normal alpha blend gives compose's pixels.
"""
import importlib
import multiprocessing
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PIECES = os.path.normpath(os.path.join(HERE, "..", "pieces"))
sys.path.insert(0, PIECES)
sys.path.insert(0, HERE)

import pygame
import atlas as AT

SEASONS = ("spring", "summer", "autumn", "winter")
CLIMATES = ("snow", "frost", "mild")
SIDES8 = ("E", "SE", "S", "SW", "W", "NW", "N", "NE")
BAY = (0.0, 72.0, 13.0)                      # the stand-in carved bay (kit.BAY_WIDTH wide, 13 px deep): the sheets' own
ORES = ("iron", "silver", "copper", "gold")
COAST = ("salt", "harbour")
FAMILIES = ["settlements", "castles", "wheat", "vineyard", "olives", "grazing", "salt", "mines", "timber", "harbour", "quarry",
            "dyes", "hemp", "cotton", "silk", "furs", "sites"]

_K = None


def _kit():
    global _K
    if _K is None:
        pygame.init()
        pygame.display.set_mode((5, 5))
        import kit
        _K = kit
    return _K


def season_groups():
    return [(s, "-") for s in SEASONS[:2]] + [("autumn", "-")] + [("winter", c) for c in CLIMATES]


def group_name(season, climate):
    return "pieces_%s" % season if season != "winter" else "pieces_winter_%s" % climate


def key_of(sp):
    return "|".join(str(x) for x in (sp["family"], sp["level"], sp["season"], sp["climate"], sp["variant"], int(sp["mirror"]), sp["extra"]))


def enumerate_specs(landmarks=True):
    """Every picture of every family: a list of spec dicts (family, module, level, variant, mirror, extra, kw, sea, bay, addon)."""
    _kit()
    out = []
    for fam in FAMILIES:
        mod = importlib.import_module(fam)
        levels = [lv for lv in mod.LEVELS if lv > 0]
        variants = range(int(getattr(mod, "VARIANTS", 1)))
        rows = [("-", {}, None, None)]
        if fam == "grazing":
            rows = [(a, {"animal": a}, None, None) for a in mod.ANIMALS]
        elif fam == "mines":
            rows = [("-", {}, None, None)] + [(o, {"ore": o}, None, None) for o in ORES]
        elif fam in COAST:
            rows = [(s, {}, s, None) for s in SIDES8] + [("carved", {}, "S", BAY)]
        for lv in levels:
            for extra, kw, sea, bay in rows:
                for v in variants:
                    for m in (False, True):
                        out.append(dict(family=fam, module=fam, level=lv, variant=v, mirror=m, extra=extra, kw=kw, sea=sea,
                                        bay=bay, shore=None))
        if fam == "harbour":                                   # the add-on of a port: its own family
            for lv in levels:
                for extra, kw, sea, bay in rows:
                    for v in variants:
                        for m in (False, True):
                            out.append(dict(family="harbour_addon", module="harbour", level=lv, variant=v, mirror=m, extra=extra,
                                            kw=dict(kw, addon=True), sea=sea, bay=bay, shore=None))
        if fam == "settlements" and landmarks:
            import landmarks as LM
            for name in LM.NAMES:
                for lv in (4, 5):
                    for v in variants:
                        for m in (False, True):
                            out.append(dict(family=fam, module=fam, level=lv, variant=v, mirror=m, extra=name,
                                            kw={"landmark": name}, sea=None, bay=None, shore=None))
    return out


def expand(specs):
    """Each spec for every season (winter in the three climates)."""
    out = []
    for sp in specs:
        for season, climate in season_groups():
            out.append(dict(sp, season=season, climate=climate))
    return out


# ---------------------------------------------------------------- the worker
_FEATHER = None


def _feather(k):
    global _FEATHER
    if _FEATHER is None:
        size, ss = k.SIZE, k.SS
        m = pygame.Surface((size * ss, size * ss), pygame.SRCALPHA)
        n = k.FEATHER * ss
        for i in range(n + 1):
            a = int(255 * i / n)
            pygame.draw.polygon(m, (a, a, a, a), [k.Pen.T(p) for p in k.hex_points(i / ss)])
        _FEATHER = m
    return _FEATHER


def _pack(surf, off):
    """(RGBA bytes, w, h, ox, oy) of a straight-alpha surface cut to its box, or None if nothing shows."""
    c = AT.crop(surf)
    if c is None:
        return None
    s, (x, y) = c
    return (pygame.image.tobytes(s, "RGBA"), s.get_width(), s.get_height(), x + off[0], y + off[1])


def render(sp):
    """One spec -> {"key", "ground", "shadow", "footprint", "standing": [...]} with raw bytes (see _pack), or None for no piece."""
    k = _kit()
    mod = importlib.import_module(sp["module"])
    size, ss, c = k.SIZE, k.SS, k.C
    lay = k.take_apart(mod.draw, sp["level"], sp["season"], variant=sp["variant"], mirror=sp["mirror"], sea=sp["sea"],
                       shore=sp["shore"], bay=sp["bay"], climate=sp["climate"] if sp["season"] == "winter" else None, **sp["kw"])
    if lay is None:
        return None
    g = lay["ground"].premul_alpha()
    g.blit(_feather(k), (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
    ground = _pack(AT.unpremultiply(pygame.transform.smoothscale(g, (size, size))), (-c, -c))
    sh = pygame.transform.smoothscale(lay["shadow"], (size, size))
    sh.set_colorkey((255, 255, 255))
    sh = sh.convert_alpha()
    sh.fill((255, 255, 255, k.SHADOW_ALPHA), special_flags=pygame.BLEND_RGBA_MIN)
    shadow = _pack(sh, (-c, -c))
    fp = lay["footprint"].to_surface(setcolor=(255, 255, 255, 255), unsetcolor=(0, 0, 0, 0))
    footprint = _pack(fp, (-c, -c))
    standing = []
    for foot, order, fn in lay["standing"]:
        one = pygame.Surface((size * ss, size * ss), pygame.SRCALPHA)
        fn(k.Pen(one))
        small = pygame.transform.smoothscale(one, (size, size))
        box = small.get_bounding_rect()
        if not box.width:
            continue
        s = AT.unpremultiply(small.subsurface(box).copy())
        standing.append((pygame.image.tobytes(s, "RGBA"), box.width, box.height, box.x - c, box.y - c, order, min(order, box.bottom - c)))
    return {"key": key_of(sp), "ground": ground, "shadow": shadow, "footprint": footprint, "standing": standing}


def _init_worker():
    sys.stdout = open(os.devnull, "w")
    _kit()


def _render_many(chunk):
    out = []
    for sp in chunk:
        try:
            out.append(render(sp))
        except Exception as e:                      # one bad piece must not stop the bake: report it with its key
            out.append({"key": key_of(sp), "error": "%s: %s" % (type(e).__name__, e)})
    return out


# ---------------------------------------------------------------- the parent
def _surf(t):
    return pygame.image.frombytes(t[0], (t[1], t[2]), "RGBA")


def bake_pieces(out_dir, specs, jobs=None, log=print):
    """Renders every spec in a pool, packs the atlases into out_dir and returns (index dict, errors, stats)."""
    pygame.init()
    jobs = jobs or max(1, (os.cpu_count() or 2) - 1)
    atlases = {}

    def at(name):
        if name not in atlases:
            atlases[name] = AT.Atlas(name)
        return atlases[name]
    entries = {}
    errors = []
    chunks = [specs[i:i + 24] for i in range(0, len(specs), 24)]
    t0 = time.time()
    done = 0
    ctx = multiprocessing.get_context("spawn")
    with ctx.Pool(jobs, initializer=_init_worker) as pool:
        for res in pool.imap_unordered(_render_many, chunks):
            for r in res:
                done += 1
                if r is None:
                    continue
                if "error" in r:
                    errors.append((r["key"], r["error"]))
                    continue
                parts = r["key"].split("|")
                grp = group_name(parts[2], parts[3])
                e = {"ground": None, "shadow": None, "standing": [], "footprint": None}
                if r["ground"]:
                    e["ground"] = (at(grp).add(_surf(r["ground"])), r["ground"][3], r["ground"][4], "g")
                if r["shadow"]:
                    e["shadow"] = (at("pieces_shadow").add(_surf(r["shadow"])), r["shadow"][3], r["shadow"][4], "s")
                if r["footprint"]:
                    e["footprint"] = (at("pieces_footprint").add(_surf(r["footprint"])), r["footprint"][3], r["footprint"][4], "f")
                for t in r["standing"]:
                    e["standing"].append((at(grp).add(_surf(t)), t[3], t[4], t[5], t[6]))
                entries[r["key"]] = (e, grp)
            if (done // 24) % 40 == 0:
                log("   pieces %d / %d (%.0f s)" % (done, len(specs), time.time() - t0))
    log("   rendered %d pieces in %.0f s; %d errors" % (len(entries), time.time() - t0, len(errors)))
    files = {}
    for name in sorted(atlases):
        files[name] = atlases[name].pack(out_dir)
        log("   atlas %s: %d unique sprites, %s" % (name, len(atlases[name].sprites), files[name]))

    def ref(name, handle, ox, oy, **extra):
        stem, rect = atlases[name].rect(handle)
        d = {"atlas": stem, "rect": rect, "offset": [ox, oy]}
        d.update(extra)
        return d
    index = {}
    for key, (e, grp) in entries.items():
        item = {"ground": None if e["ground"] is None else ref(grp, e["ground"][0], e["ground"][1], e["ground"][2]),
                "shadow": None if e["shadow"] is None else ref("pieces_shadow", e["shadow"][0], e["shadow"][1], e["shadow"][2]),
                "standing": [ref(grp, h, ox, oy, foot_y=fy, pic_foot_y=pfy) for h, ox, oy, fy, pfy in e["standing"]],
                "footprint": None if e["footprint"] is None else ref("pieces_footprint", e["footprint"][0], e["footprint"][1], e["footprint"][2])}
        index[key] = item
    return index, errors, files
