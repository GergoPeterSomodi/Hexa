"""Every generated sprite of the art modules, hashed: {name: sha256 of its RGBA bytes and size}.

The art modules (goodsart, goodsobjects, wfctiles, nature, life, landmarks, art) draw the tiles, objects and figures
in code. A refactor of them (render/draw.py, the cache sizes) must not change a pixel, and this is the proof:
tests/test_sprite_hashes.py compares collect() with tests/fixtures/sprite_hashes.json. Everything has a fixed seed or
variant, so the hashes are the same on every run on one machine (pygame, SDL and the smoothscale backend decide what
a build of pygame draws, see environment()).

    python -m tests.support.sprites                 print the number of sprites and the time
    UPDATE_SPRITES=1 python -m unittest tests.test_sprite_hashes      write the fixture
"""
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TILES = os.path.join(ROOT, "hexagon-pack", "PNG", "Tiles")
FIXTURE = os.path.join(ROOT, "tests", "fixtures", "sprite_hashes.json")
FIGURES = ("pikemen", "arquebusiers", "musketeers", "knights", "lancers", "cuirassiers", "bombards", "culverins",
           "field_guns", "wagon", "general", "scout", "pioneer", "colonist", "caravel", "carrack")
DECORATIONS = ("trees", "rocks", "hamlet", "fields", "smoke", "port", "town", "city")
RED = (196, 52, 48)


def environment():
    """What the pixels depend on (pygame draws and scales a little differently in another build)."""
    import platform
    import pygame
    return {"system": platform.system(), "python": f"{sys.version_info.major}.{sys.version_info.minor}",
            "pygame": pygame.version.ver, "sdl": ".".join(map(str, pygame.get_sdl_version(linked=True))),
            "smoothscale": pygame.transform.get_smoothscale_backend()}


def digest(surface):
    import pygame
    return hashlib.sha256(pygame.image.tobytes(surface, "RGBA") + repr(surface.get_size()).encode()).hexdigest()


def _goods(out):
    from hexa.campaign import goodsart, goodsobjects
    for good in sorted(goodsart._GOODS):
        for level in range(1, 6):
            for variant in range(3):
                out[f"goodsart:{good}:{level}:{variant}"] = goodsart.good_tile(good, level, TILES, variant)
    for key in sorted(goodsobjects.OBJECTS):
        out[f"goodsobjects:master:{key}"] = goodsobjects.master(key)
        out[f"goodsobjects:34:{key}"] = goodsobjects.draw_good(key, 68)


def _wfc(out):
    from hexa.campaign import wfctiles as w
    tile = w.tile
    for kind in w.SEA_BASES:
        for v in range(3):
            out[f"wfc:sea:{kind}:{v}"] = w.sea_tile(kind, v)
    for mask in range(64):
        edges = [e for e in range(6) if mask >> e & 1]
        out[f"wfc:coast:{mask}"] = w.coast_overlay(edges, mask % 3)
    for edges in ((0,), (0, 3), (1, 4), (0, 2), (0, 2, 4), (0, 1, 3), (1, 2, 4, 5)):
        for v in range(2):
            out[f"wfc:river:{edges}:{v}"] = w.river_overlay(edges, v)
        out[f"wfc:river_mouth:{edges}"] = w.river_overlay(edges, 0, mouth=True, sea_edges=(5,) if 5 not in edges else (3,))
        out[f"wfc:river_lake:{edges}"] = w.river_overlay(edges, 1, lake=True)
        out[f"wfc:road:{edges}"] = w.road_overlay(edges, 0, "dirt")
        out[f"wfc:paved:{edges}"] = w.road_overlay(edges, 1, "paved")
        out[f"wfc:wall:{edges}"] = w.wall_overlay((), 2, edges, 0)
    for crossing in ("bridge", "ford", "ferry"):
        out[f"wfc:cross:{crossing}"] = w.road_overlay((0, 3), 0, "dirt", river_edges=(1, 4), crossing=crossing)
    for level in (1, 2, 3):
        for v in range(3):
            out[f"wfc:town:{level}:{v}"] = w.settlement_tile(level, v, road_edges=(0, 3))
            out[f"wfc:town_sea:{level}:{v}"] = w.settlement_tile(level, v, sea_edges=(1, 2), river_edges=(4,))
            out[f"wfc:castle:{level}:{v}"] = w.castle_tile(level, v, road_edges=(2,))
            out[f"wfc:harbour:{level}:{v}"] = w.harbour_tile((0, 1), level, (3,), v)
        out[f"wfc:wallinside:{level}"] = w.wall_overlay((1, 4), level, (0,), 0)
    for v in range(3):
        out[f"wfc:lake:{v}"] = w.lake_overlay((2,), v)
        out[f"wfc:marsh:{v}"] = w.marsh_overlay((0, 3), v)
        out[f"wfc:mountain:{v}"] = w.mountain_overlay((1, 4), v, (0,))
    for base in ("plains", "forest", "hills", "mountains", "steppe", "desert", "tundra", "marsh"):
        out[f"wfc:full:{base}"] = w.render_tile(tile(base, road=(0, 3), variant=1), TILES)
        out[f"wfc:flat:{base}"] = w.render_tile(tile(base, river=(1, 4)), None)
    out["wfc:full:good"] = w.render_tile(tile("plains", good=("wine", 3)), TILES)
    for seed in (1, 2):
        out[f"wfc:patch:{seed}"] = w.render_patch(w.generate_patch(14, 10, seed), TILES)


def _nature(out):
    from hexa.campaign import life, nature
    for name in sorted(nature._BUILD):
        for size in nature.SIZES:
            for seed in range(nature.VARIANTS):
                out[f"nature:{name}:{size}:{seed}"] = nature._pub(name, size, seed)
    for name in nature.TILE_KINDS:
        for v in range(2):
            out[f"nature:tile:{name}:{v}"] = nature.draw_tile(name, v)
    import pygame
    for kind in nature.KINDS:
        out[f"nature:scatter:{kind}"] = nature.scatter(pygame.Surface((120, 140), pygame.SRCALPHA), kind, 0.7, 2)
    for name in sorted(life.OBJECTS):
        for size in life.SIZES:
            for seed in range(4):
                out[f"life:{name}:{size}:{seed}"] = life.OBJECTS[name](size, seed)
    for kind in life.KINDS:
        out[f"life:scatter:{kind}"] = life.scatter(pygame.Surface((120, 140), pygame.SRCALPHA), kind, 1.0, 1)


def _art(out):
    from hexa.campaign import art, landmarks
    for name in sorted(landmarks.DRAWERS):
        for stage in (1, 2, 3):
            for v in range(2):
                out[f"landmark:{name}:{stage}:{v}"] = landmarks.draw_city(name, stage, v)
    for name in sorted(art._TILES):
        for v in range(3):
            out[f"art:tile:{name}:{v}"] = art.make_tile(name, TILES, v)
    for kind in DECORATIONS:
        for seed in range(3):
            out[f"art:deco:{kind}:{seed}"] = art.decoration(kind, seed, TILES)
    for key in FIGURES:
        out[f"art:figure:{key}"] = art.figure(key, RED, 48)
        out[f"art:figure_faded:{key}"] = art.figure(key, RED, 33, faded=True)
        for era in (1, 2):
            out[f"art:token:{key}:{era}"] = art.token(key, RED, 40, era)


def collect():
    """{name: digest} of every sprite, built from scratch (the caches emptied first)."""
    import pygame
    from hexa.campaign.render import cache
    pygame.init()
    if not pygame.display.get_surface():
        pygame.display.set_mode((5, 5))
    cache.clear_all()
    sprites = {}
    for part in (_goods, _wfc, _nature, _art):
        part(sprites)
    return {name: digest(surf) for name, surf in sorted(sprites.items())}


if __name__ == "__main__":
    import time
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    sys.path.insert(0, ROOT)
    began = time.perf_counter()
    found = collect()
    print(len(found), "sprites in", round(time.perf_counter() - began, 1), "s")
