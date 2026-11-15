"""Sanity check of the bake: puts the baked files back together the way compose.py (tools/worldmap/pieces_in_map) lays
them, using nothing but the files in the bake folder, and writes one picture. It is also a worked example of the contract.

    python tools/worldmap/godot_bake/reassemble.py [--bake DIR] [--season summer] [--out FILE] [--union-shadows]

Order (as compose.py): ground_<season> -> the ground detail of every piece (clipped to the land, except coast pieces) ->
overlay_<season> (rivers, roads, bridges, pass marks) -> soft shadows (wild and pieces) -> every standing thing, wild and
piece, sorted by (foot y, x). The wild trees and hills that stand in a piece's footprint or hex are left out; mountain
ranges cannot be cut and stay. Straight-alpha normal blits only (what Godot does).
"""
import argparse
import json
import math
import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
R, TILT, SIZE, C = 60.0, 0.85, 112, 56


def in_hex(x, y, margin=0.0):
    """kit.in_hex: the piece-px point lies inside the hex, margin px clear of the border."""
    ax, ay = abs(x), abs(y) / TILT
    inner = R * math.cos(math.radians(30)) - margin
    return ax <= inner and ax * 0.5 + ay * math.cos(math.radians(30)) <= inner


class Bake:
    def __init__(self, folder):
        self.dir = folder
        load = lambda p: json.load(open(os.path.join(folder, p), encoding="utf-8"))
        self.meta, self.wild, self.index = load("meta.json"), load("wild.json"), load("pieces/index.json")
        self.place = load("placements.json")["placements"]
        self.images = {}
        self.centre_of_hex = {(h["c"], h["r"]): tuple(h["centre_px"]) for h in self.meta["hexes"]}

    def image(self, name, sub=""):
        k = (sub, name)
        if k not in self.images:
            self.images[k] = pygame.image.load(os.path.join(self.dir, sub, name)).convert_alpha()
        return self.images[k]

    def sprite(self, ref, sub=""):
        r = ref["rect"]
        return self.image(ref["atlas"] + ".png", sub).subsurface(pygame.Rect(*r))


def reassemble(folder, season="summer", union=False):
    pygame.init()
    pygame.display.set_mode((5, 5))
    B = Bake(folder)
    W, H = B.meta["size_px"]
    surf = B.image("ground_%s.png" % season).copy().convert()
    land = B.image("land_mask.png")
    placements = [p for p in B.place if p["keys"][season] in B.index["pieces"]]
    pieces = []                                         # (placement, entry)
    for p in placements:
        pieces.append((p, B.index["pieces"][p["keys"][season]]))

    # the footprints, as masks, at the piece's centre
    fps = []
    for p, e in pieces:
        fp = e["footprint"]
        if fp:
            m = pygame.mask.from_surface(B.sprite(fp, "pieces"), 127)
            fps.append((p["centre"][0] + fp["offset"][0], p["centre"][1] + fp["offset"][1], m))

    def in_footprint(x, y):
        for ox, oy, m in fps:
            i, j = int(math.floor(x - ox)), int(math.floor(y - oy))
            if 0 <= i < m.get_size()[0] and 0 <= j < m.get_size()[1] and m.get_at((i, j)):
                return True
        return False

    def is_land(x, y):
        x, y = int(x), int(y)
        return 0 <= x < W and 0 <= y < H and land.get_at((x, y))[0] > 127

    piece_hexes = {tuple(p["hex"]) for p, _ in pieces if not p["addon"]}
    # 2: the ground detail of the pieces, on the ground, clipped to the land (coast pieces: whole)
    for p, e in pieces:
        g = e["ground"]
        if not g:
            continue
        spr = B.sprite(g, "pieces").copy()
        x0, y0 = p["centre"][0] + g["offset"][0], p["centre"][1] + g["offset"][1]
        if not p["coast"]:
            clip = pygame.Surface(spr.get_size(), pygame.SRCALPHA)
            for j in range(spr.get_height()):
                for i in range(spr.get_width()):
                    v = 255 if is_land(x0 + i + 0.5, y0 + j + 0.5) else 0
                    clip.set_at((i, j), (v, v, v, v))
            spr.blit(clip, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
        surf.blit(spr, (x0, y0))
    # 3: rivers, roads, bridges
    surf.blit(B.image("overlay_%s.png" % season), (0, 0))

    # 4 and 5: shadows, then everything that stands
    shadow_layer = pygame.Surface((W, H), pygame.SRCALPHA)
    drawn = []                                          # (sort y, sort x, order, surface, topleft)
    stats = {"wild trees thinned": 0, "hills dropped": 0, "wild objects": 0, "piece things": 0, "standing left out at the sea": 0}

    def shade(spr, pos):
        if union:
            shadow_layer.blit(spr, pos, special_flags=pygame.BLEND_RGBA_MAX)
        else:
            surf_shadows.append((spr, pos))
    surf_shadows = []
    for it in B.wild["items"]:
        fx, fy = it["foot"]
        if it["kind"] == "tree" and in_footprint(fx, fy):
            stats["wild trees thinned"] += 1
            continue
        if it["kind"] == "range" and any(in_footprint(fx, fy - d) for d in (0, 10, 20, 30)):
            stats["range samples dropped"] = stats.get("range samples dropped", 0) + 1
            continue
        if it["kind"] == "hill" and tuple(it["hex"]) in piece_hexes:
            stats["hills dropped"] += 1
            continue
        stats["wild objects"] += 1
        sp, sh = it["sprite"][season], it["shadow"][season]
        if sh:
            shade(B.sprite(sh, ""), (fx + sh["offset"][0], fy + sh["offset"][1]))
        if sp:
            drawn.append((it["sort_y"], it["sort_x"], 0, B.sprite(sp, ""), (fx + sp["offset"][0], fy + sp["offset"][1])))
    town_fp = {}
    for p, e in pieces:
        if not p["addon"] and e["footprint"]:
            f = e["footprint"]
            town_fp[tuple(p["hex"])] = (p["centre"][0] + f["offset"][0], p["centre"][1] + f["offset"][1],
                                        pygame.mask.from_surface(B.sprite(f, "pieces"), 127))
    for p, e in pieces:
        cx, cy = p["centre"]
        hx = tuple(p["hex"])
        if e["shadow"]:
            sh = e["shadow"]
            shade(B.sprite(sh, "pieces"), (cx + sh["offset"][0], cy + sh["offset"][1]))
        for n, st in enumerate(e["standing"]):
            spr = B.sprite(st, "pieces")
            pos = (cx + st["offset"][0], cy + st["offset"][1])
            foot_pic = cy + st["pic_foot_y"]
            w, h = spr.get_size()
            if not p["coast"] and st["foot_y"] < 60 and any(not is_land(fx_, foot_pic) for fx_ in (pos[0] + 1, pos[0] + w // 2, pos[0] + w - 1)):
                stats["standing left out at the sea"] += 1
                continue
            if p["coast"] and not in_hex(pos[0] + w // 2 - cx, foot_pic - cy, 1):
                continue
            if p["addon"] and hx in town_fp:
                ox, oy, m = town_fp[hx]
                i, j = int(math.floor(pos[0] + w / 2 - ox)), int(math.floor(foot_pic - oy))
                if 0 <= i < m.get_size()[0] and 0 <= j < m.get_size()[1] and m.get_at((i, j)) and is_land(pos[0] + w / 2, foot_pic):
                    continue
            stats["piece things"] += 1
            drawn.append((cy + st["foot_y"] + n * 1e-5, cx, 1, spr, pos))
    if union:
        surf.blit(shadow_layer, (0, 0))
    else:
        for spr, pos in surf_shadows:
            surf.blit(spr, pos)
    for _, _, _, spr, pos in sorted(drawn, key=lambda d: (d[0], d[1])):
        surf.blit(spr, pos)
    return surf, stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bake", default=os.path.join(REPO, "godot", "assets", "worldmap", "north_italy"))
    ap.add_argument("--season", default="summer")
    ap.add_argument("--out", default=None)
    ap.add_argument("--union-shadows", action="store_true", help="lay all shadows as one flat layer (as compose.py does)")
    a = ap.parse_args()
    out = a.out or os.path.join(REPO, "docs", "design", "map", "godot_bake", "reassembled_%s.png" % a.season)
    surf, stats = reassemble(a.bake, a.season, a.union_shadows)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    pygame.image.save(surf, out)
    print("wrote", out, stats)


if __name__ == "__main__":
    main()
