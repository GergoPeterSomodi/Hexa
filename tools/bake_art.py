"""Bake the code-drawn map art of the Python game into texture atlases for the Godot port (release 0.3.0, item 5).

    python -m tools.bake_art                         bake everything into godot/assets/baked/
    python -m tools.bake_art --out DIR               somewhere else (the tests bake into a temp dir)
    python -m tools.bake_art --only ground,coast     some groups (a partial bake writes a partial index)
    python -m tools.bake_art --list                  the groups and how many sprites each holds

The art modules of the Python game (art, goodsart, wfctiles, landmarks) stay the source of the pictures: this tool
calls them, exactly as the map view does, and writes what they draw. It changes nothing under hexa/, so the sprite
hashes (tests/test_sprite_hashes.py) keep guarding the art code. The Python game is frozen at v0.2.2.

SIZES (pinned by docs/roadmap/godot-port-plan.md B7)
    Hex radius 60 px. The grid tile (Godot TileSet tile_size) is 104 x 120, pointy-top.
    Every sprite is a hex picture of 106 x 122 px (REGION): one pixel larger than the tile on every side, the same
    overlap the Python map view gives its sprites at every zoom (MapView._seamless, scale_tile to r*sqrt(3)+1), so
    neighbours join without a hairline. Its anchor is its centre (53, 61), which sits on the hex centre.
    In the atlas each sprite has a 2 px extruded border (its edge pixels copied outwards), so a cell is 110 x 126.
    Atlas pages are at most 2048 x 2048 (safe on old GPUs and the Compatibility renderer). Import them in Godot
    with mipmaps on and filter linear.

EDGE MASKS
    Coast, river, road, mouth, bridge, town-gate and harbour pieces are named by edge masks: bit e is edge e in the
    order of hexa/hexgrid.py neighbors(pos) for the odd-r offset grid: 0 = E, 1 = NE, 2 = NW, 3 = W, 4 = SW,
    5 = SE (screen y down). Godot's TileMap neighbour order is different: the builder converts.

LAYERS (back to front, what the Python map view draws at its tile zoom, MapView._draw_tiles and overlay_desc)
    ground   terrain, sea, lake, native village, or the goods tile of a province with works (goods group)
    coast    coast/<sea mask>/<v>; a river mouth replaces it with mouth/<river edge>/<sea mask> (coast included),
             a coastal town with harbour/<level>/<sea mask> (coast and town included, drawn last, see town)
    river    river/<mask>/<v>
    road     road/dirt/<mask> or road/paved/<mask> (paved: the roads of a town of level 3 or more); where a road of
             two edges crosses a river of two edges, bridge/<road mask>/<river mask> (road and bridges, no river)
             replaces the road piece. Roads never cross a sea edge or a ridge crest (the builder drops those edges).
    deco     deco/<kind>/<seed> on open land without anything else (trees, rocks, fields, hamlet)
    town     town/<level>/<v> (no roads), town/<level>/gates/<road mask> (streets and wall gates drawn in; replaces
             the road piece), harbour/<level>/<sea mask>; castle/<level>/<v> for a castle without a town
    Town levels are wfctiles' (mapview.overlay_desc): settlement 1 -> 2 (village), 2 -> 3 (market town) or 4 (walled,
    when it has a castle), 3 -> 5 (city) or 6 (great city, population 60 or more). The variant v is 0..2.

The index (index.json) lists every sprite: atlas page, rect (the 106 x 122 region, without the extrusion), anchor,
sort offset, layer and where the picture came from; and every page's size and sha256. The hashes depend on the
pygame build like the sprite hashes do (the platform key is in the index): CI bakes on Linux and that bake is the one
committed. Kenney Hexagon Pack PNGs that the Python game shows as they are, are also copied unchanged into kenney/
with the pack's licence (CC0).
"""
import argparse
import hashlib
import json
import math
import os
import shutil
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES_DIR = os.path.join(ROOT, "hexagon-pack", "PNG", "Tiles")
OUT_DIR = os.path.join(ROOT, "godot", "assets", "baked")

FORMAT = 1
HEX_RADIUS = 60
TILE = (104, 120)                 # the grid tile: radius 60, pointy-top (60*sqrt(3) = 103.9 is rounded to 104)
REGION = (106, 122)               # every sprite: one pixel of overlap on each side of the tile
ANCHOR = (REGION[0] // 2, REGION[1] // 2)
EXTRUDE = 2
CELL = (REGION[0] + 2 * EXTRUDE, REGION[1] + 2 * EXTRUDE)
PAGE_MAX = 2048
COLS = PAGE_MAX // CELL[0]        # 18
ROWS = PAGE_MAX // CELL[1]        # 16
VARIANTS = 3                      # mapview._variant(pos) is 0..2
TOWN_LEVELS = (2, 3, 4, 5, 6)
WALLED = 4                        # town levels from here on have a wall (gates where the roads come in)


def bits(mask):
    return tuple(e for e in range(6) if mask >> e & 1)


def masks(lo, hi):
    """Every edge mask with lo..hi edges set, in numeric order."""
    return [m for m in range(64) if lo <= bin(m).count("1") <= hi]


# ----- making one sprite at bake size ---------------------------------------------------------------------------
def _hex(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i - 30)), cy + r * math.sin(math.radians(60 * i - 30)))
            for i in range(6)]


def seamless(image):
    """A 120 x 140 opaque tile picture at REGION size, as MapView._seamless makes it at every zoom: drawn a little
    large on a rim of its own colour and clipped to a hex grown to the sprite's full width (no gaps between tiles)."""
    import pygame
    from hexa.campaign import landscape, wfctiles
    w, h = REGION
    big = wfctiles.scale_tile(image, round(w * 1.06), round(h * 1.06))
    poly = _hex(w / 2, h / 2, (w + 2) / math.sqrt(3))
    out = pygame.Surface((w, h), pygame.SRCALPHA)
    rim = pygame.transform.average_color(big, big.get_rect().inflate(-big.get_width() // 3, -big.get_height() // 3))
    pygame.draw.polygon(out, tuple(rim[:3]) + (255,), poly)
    out.blit(big, ((w - big.get_width()) // 2, (h - big.get_height()) // 2))
    mask = landscape.clip_mask((w, h))
    pygame.draw.polygon(mask, (255, 255, 255, 255), poly)
    out.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    return out


def overlay_size(image):
    """A transparent 120 x 140 overlay at REGION size (scale_tile: edge colours bled first, no dark rims)."""
    from hexa.campaign import wfctiles
    return wfctiles.scale_tile(image, *REGION)


def plain_size(image):
    """A decoration at REGION size, smooth-scaled as MapView.decoration does."""
    import pygame
    return pygame.transform.smoothscale(image, REGION)


def _kenney(rel):
    import pygame
    img = pygame.image.load(os.path.join(TILES_DIR, *rel.split("/")))
    return img.convert_alpha() if pygame.display.get_surface() else img


# ----- the groups: (name, layer, sort, source, make) ---------------------------------------------------------------
def _ground():
    from hexa.campaign import art, wfctiles
    from hexa.campaign.data import NATIVE_VILLAGE_SPRITE, TERRAIN_SPRITES
    out = []
    for kind, options in TERRAIN_SPRITES.items():
        for i, path in enumerate(options):
            if path.startswith("art:"):
                _, name, v = path.split(":")
                make = (lambda n=name, v=int(v): seamless(art.make_tile(n, TILES_DIR, v)))
                source = f"art.make_tile({name!r}, {v})"
            else:
                make = (lambda p=path: seamless(_kenney(p)))
                source = f"kenney:{path}"
            out.append((f"terrain/{kind}/{i}", "ground", 0, source, make))
    for kind in wfctiles.SEA_BASES:
        for v in range(VARIANTS):
            out.append((f"sea/{kind}/{v}", "ground", 0, f"wfctiles.sea_tile({kind!r}, {v})",
                        lambda k=kind, v=v: seamless(wfctiles.sea_tile(k, v))))      # opaque, like the land
    out.append(("native_village", "ground", 0, f"kenney:{NATIVE_VILLAGE_SPRITE}",
                lambda: seamless(_kenney(NATIVE_VILLAGE_SPRITE))))
    return out


def _goods():
    from hexa.campaign import goodsart
    from hexa.campaign.data import GOODS
    drawn = [g for g in sorted(GOODS) if goodsart.good_tile(g, 1, TILES_DIR) is not None]    # made goods have none
    return [(f"goods/{good}/{level}/{v}", "ground", 0, f"goodsart.good_tile({good!r}, {level}, {v})",
             lambda g=good, lv=level, v=v: seamless(goodsart.good_tile(g, lv, TILES_DIR, v)))
            for good in drawn for level in range(1, 6) for v in range(VARIANTS)]


def _deco():
    from hexa.campaign import art
    return [(f"deco/{kind}/{seed}", "deco", 0, f"art.decoration({kind!r}, {seed})",
             lambda k=kind, s=seed: plain_size(art.decoration(k, s, TILES_DIR)))
            for kind in ("trees", "rocks", "fields", "hamlet") for seed in range(4)]


def _coast():
    from hexa.campaign import wfctiles as w
    out = [(f"coast/{m}/{v}", "coast", 0, f"wfctiles.coast_overlay({bits(m)}, {v})",
            lambda m=m, v=v: overlay_size(w.coast_overlay(bits(m), v))) for m in masks(1, 6) for v in range(VARIANTS)]
    for e in range(6):                               # a river ending in the sea: the mouth flares into the coast
        for m in masks(1, 5):
            if not m >> e & 1:
                out.append((f"mouth/{e}/{m}", "coast", 0, f"wfctiles.river_overlay(({e},), mouth=True, sea_edges={bits(m)})",
                            lambda e=e, m=m: overlay_size(w.river_overlay((e,), 0, mouth=True, sea_edges=bits(m)))))
    return out


def _river():
    from hexa.campaign import wfctiles as w
    return [(f"river/{m}/{v}", "river", 0, f"wfctiles.river_overlay({bits(m)}, {v})",
             lambda m=m, v=v: overlay_size(w.river_overlay(bits(m), v))) for m in masks(1, 4) for v in range(VARIANTS)]


def _road():
    from hexa.campaign import wfctiles as w
    out = [(f"road/{kind}/{m}", "road", 0, f"wfctiles.road_overlay({bits(m)}, kind={kind!r})",
            lambda m=m, k=kind: overlay_size(w.road_overlay(bits(m), 0, k)))
           for kind in ("dirt", "paved") for m in masks(1, 6)]
    for rm in masks(2, 2):
        for vm in masks(2, 2):
            if not rm & vm:
                out.append((f"bridge/{rm}/{vm}", "road", 0, f"wfctiles.road_overlay({bits(rm)}, river_edges={bits(vm)})",
                            lambda rm=rm, vm=vm: overlay_size(w.road_overlay(bits(rm), 0, "dirt", river_edges=bits(vm)))))
    return out


def _town():
    from hexa.campaign import wfctiles as w
    out = [(f"town/{lv}/{v}", "town", 0, f"wfctiles.settlement_tile({lv}, {v})",
            lambda lv=lv, v=v: overlay_size(w.settlement_tile(lv, v))) for lv in TOWN_LEVELS for v in range(VARIANTS)]
    out += [(f"town/{lv}/gates/{m}", "town", 0, f"wfctiles.settlement_tile({lv}, road_edges={bits(m)})",
             lambda lv=lv, m=m: overlay_size(w.settlement_tile(lv, 0, road_edges=bits(m))))
            for lv in TOWN_LEVELS for m in masks(1, 4)]
    out += [(f"harbour/{lv}/{m}", "town", 0, f"wfctiles.settlement_tile({lv}, sea_edges={bits(m)})",
             lambda lv=lv, m=m: overlay_size(w.settlement_tile(lv, 0, sea_edges=bits(m))))
            for lv in TOWN_LEVELS for m in masks(1, 5)]
    out += [(f"castle/{lv}/{v}", "town", 0, f"wfctiles.castle_tile({lv}, {v})",
             lambda lv=lv, v=v: overlay_size(w.castle_tile(lv, v))) for lv in (1, 2, 3) for v in range(VARIANTS)]
    return out


def _landmark():
    from hexa.campaign import landmarks
    return [(f"landmark/{name}/{stage}/{v}", "town", 0, f"landmarks.draw_city({name!r}, {stage}, {v})",
             lambda n=name, s=stage, v=v: overlay_size(landmarks.draw_city(n, s, v)))
            for name in landmarks.CITY_NAMES for stage in (1, 2, 3) for v in range(2)]


GROUPS = {"ground": _ground, "goods": _goods, "deco": _deco, "coast": _coast, "river": _river, "road": _road,
          "town": _town, "landmark": _landmark}


def kenney_files():
    """The pack's tile PNGs the Python map shows as they are (copied unchanged next to the atlases)."""
    from hexa.campaign.data import NATIVE_VILLAGE_SPRITE, TERRAIN_SPRITES
    paths = {p for opts in TERRAIN_SPRITES.values() for p in opts if not p.startswith("art:")}
    return sorted(paths | {NATIVE_VILLAGE_SPRITE})


# ----- atlas pages ----------------------------------------------------------------------------------------------
def extrude(page, x, y, w, h, n=EXTRUDE):
    """Copy the edge pixels of the region (x, y, w, h) n pixels outwards (no bleeding of neighbours when filtered)."""
    import pygame
    COPY = pygame.BLEND_RGBA_MAX                   # onto the page's empty pixels: an exact copy, alpha included
    for i in range(1, n + 1):
        page.blit(page, (x - i, y), (x, y, 1, h), COPY)
        page.blit(page, (x + w - 1 + i, y), (x + w - 1, y, 1, h), COPY)
    for i in range(1, n + 1):
        page.blit(page, (x - n, y - i), (x - n, y, w + 2 * n, 1), COPY)
        page.blit(page, (x - n, y + h - 1 + i), (x - n, y + h - 1, w + 2 * n, 1), COPY)


def _sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def bake(out_dir=OUT_DIR, only=None, log=print):
    """Bake the groups (all, or `only`) into out_dir; returns the index (also written to out_dir/index.json)."""
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
    if ROOT not in sys.path:
        sys.path.insert(0, ROOT)
    import pygame
    from hexa.campaign.render import cache
    from tests.support import sprites
    pygame.init()
    if not pygame.display.get_surface():
        pygame.display.set_mode((5, 5))
    cache.clear_all()
    os.makedirs(out_dir, exist_ok=True)
    index = {"format": FORMAT, "hex_radius": HEX_RADIUS, "tile_size": list(TILE), "region_size": list(REGION),
             "anchor": list(ANCHOR), "extrude": EXTRUDE, "cell": list(CELL), "page_max": PAGE_MAX,
             "edge_order": ["E", "NE", "NW", "W", "SW", "SE"], "platform": sprites.platform_key(),
             "atlases": {}, "sprites": {}}
    for group, items in GROUPS.items():
        if only and group not in only:
            continue
        began = time.perf_counter()
        items = items()
        per = COLS * ROWS
        for page_no in range((len(items) + per - 1) // per):
            chunk = items[page_no * per:(page_no + 1) * per]
            rows = (len(chunk) + COLS - 1) // COLS
            cols = min(COLS, len(chunk))
            page = pygame.Surface((cols * CELL[0], rows * CELL[1]), pygame.SRCALPHA)
            page.fill((0, 0, 0, 0))
            fname = f"{group}_{page_no}.png"
            for i, (name, layer, sort, source, make) in enumerate(chunk):
                img = make()
                assert img.get_size() == REGION, (name, img.get_size())
                x = (i % COLS) * CELL[0] + EXTRUDE
                y = (i // COLS) * CELL[1] + EXTRUDE
                page.blit(img, (x, y), special_flags=pygame.BLEND_RGBA_MAX)     # an exact copy (empty page)
                extrude(page, x, y, *REGION)
                index["sprites"][name] = {"atlas": fname, "rect": [x, y, REGION[0], REGION[1]],
                                          "anchor": list(ANCHOR), "sort": sort, "layer": layer, "source": source}
            path = os.path.join(out_dir, fname)
            pygame.image.save(page, path)
            index["atlases"][fname] = {"group": group, "size": list(page.get_size()), "sprites": len(chunk),
                                       "sha256": _sha(path)}
        log(f"{group:9s} {len(items):5d} sprites  {time.perf_counter() - began:5.1f} s")
    if not only:
        kdir = os.path.join(out_dir, "kenney")
        for rel in kenney_files():
            dest = os.path.join(kdir, *rel.split("/"))
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copyfile(os.path.join(TILES_DIR, *rel.split("/")), dest)
        shutil.copyfile(os.path.join(ROOT, "hexagon-pack", "License.txt"), os.path.join(kdir, "License.txt"))
        index["kenney"] = {"licence": "CC0 1.0 (Kenney Hexagon Pack, www.kenney.nl), see kenney/License.txt",
                           "files": kenney_files()}
    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(index, f, indent=1, sort_keys=True)
        f.write("\n")
    return index


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=OUT_DIR)
    ap.add_argument("--only", default="", help="comma-separated groups: " + ",".join(GROUPS))
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args(argv)
    if ROOT not in sys.path:
        sys.path.insert(0, ROOT)
    if args.list:
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        for group, items in GROUPS.items():
            print(f"{group:9s} {len(items()):5d}")
        return 0
    only = {g for g in args.only.split(",") if g}
    unknown = only - set(GROUPS)
    if unknown:
        ap.error(f"unknown groups: {sorted(unknown)}")
    began = time.perf_counter()
    index = bake(args.out, only or None)
    print(f"{len(index['sprites'])} sprites on {len(index['atlases'])} pages in {time.perf_counter() - began:.1f} s"
          f" -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
