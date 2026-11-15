"""Piece tiles: an improvement piece (a family at a level, one layout) as four tiles: its flat ground, its shadow,
and its standing things in a back band (their foot above the middle of the hex) and a front band.

TRIAL: the pictures are put together from the pieces the whole-map bake already wrote
(godot/assets/worldmap/north_italy/pieces: index.json and its atlases). The M1 build renders them straight from the
families instead (tools/worldmap/godot_bake/pieces_bake.py render()), with the same cut into four tiles.
"""
import json
import math
import os

import pygame

from tile_atlas import blank

P_W, P_H = 184, 184
P_ANCHOR = (92, 104)
BACK_SORT, FRONT_SORT = -12, 12
COAST_Y0 = 13.0                 # a harbour add-on's own shore lies this far out from the middle of its picture
BAY_BACK = 20.0                 # coast_tiles.BAY_BACK
SIDE_ANGLE = {"E": 0, "SE": 45, "S": 90, "SW": 135, "W": 180, "NW": 225, "N": 270, "NE": 315}
SIDE_REACH = {"E": 52.0, "W": 52.0, "N": 40.0, "S": 40.0}       # px from the middle of the hex to its shore; others 46


def addon_shift(side):
    """Where a harbour add-on's picture goes, from the middle of the hex: so its shore lies on the hex's own."""
    if side == "carved":
        return (0.0, BAY_BACK - COAST_Y0)
    a = math.radians(SIDE_ANGLE[side])
    reach = SIDE_REACH.get(side, 46.0) - COAST_Y0
    return (round(math.cos(a) * reach), round(math.sin(a) * reach))


class BakedPieces:
    def __init__(self, folder):
        self.folder = folder
        self.index = json.load(open(os.path.join(folder, "index.json"), encoding="utf-8"))["pieces"]
        self.sheets = {}

    def sheet(self, stem):
        if stem not in self.sheets:
            self.sheets[stem] = pygame.image.load(os.path.join(self.folder, stem + ".png"))
        return self.sheets[stem]

    def find(self, family, level, season, climate, variant, mirror, extra):
        """The index key, with the fallbacks of the map scene (north_italy_map.gd _find_key)."""
        winter = climate if season == "winter" else "-"
        for v, m, e in ((variant, mirror, extra), (0, mirror, extra), (variant, mirror, "-"), (0, mirror, "-"), (0, 0, extra),
                        (0, 0, "-")):
            key = "%s|%d|%s|%s|%d|%d|%s" % (family, level, season, winter, v, m, e)
            if key in self.index:
                return key
        return None

    def parts(self, key, shift=(0, 0), one_band=False):
        """{part: surface} for ground, shadow, back and front (a part with nothing in it is left out)."""
        e = self.index[key]
        ax, ay = P_ANCHOR[0] + shift[0], P_ANCHOR[1] + shift[1]
        out = {}
        for part in ("ground", "shadow"):
            g = e.get(part)
            if g:
                s = blank((P_W, P_H))
                _put(s, self.sheet(g["atlas"]), g, ax, ay)
                out[part] = s
        bands = {"back": [], "front": []}
        for t in e.get("standing") or []:
            bands["back" if t["foot_y"] + shift[1] < 0 and not one_band else "front"].append(t)
        for part, things in bands.items():
            if things:
                s = blank((P_W, P_H))
                for t in things:                        # the list is back to front already
                    _put(s, self.sheet(t["atlas"]), t, ax, ay)
                out[part] = s
        return out


def _put(dst, sheet, sprite, ax, ay):
    x, y = ax + sprite["offset"][0], ay + sprite["offset"][1]
    w, h = sprite["rect"][2], sprite["rect"][3]
    assert x >= 0 and y >= 0 and x + w <= P_W and y + h <= P_H, ("a piece does not fit its tile", sprite, (x, y))
    dst.blit(sheet, (x, y), sprite["rect"])


# ---------------------------------------------------------------- the full bake: pieces straight from the kit
SIZES = (120, 152, 184)         # the three picture sizes of the piece sources (px square)
PREFERRED = (0.5, 104.0 / 184.0)    # where the middle of the hex sits in a picture, as a share of its size


def layers_of(r, shift=(0, 0), one_band=False):
    """{part: [(rgba bytes, w, h, x, y)]} from a pieces_bake.render() result: x, y are px from the middle of the hex, the
    picture moved by `shift`. ground and shadow have one picture each; back and front list the standing things
    back to front. A harbour add-on has one band (all front)."""
    out = {}
    for part in ("ground", "shadow"):
        g = r[part]
        if g:
            out[part] = [(g[0], g[1], g[2], g[3] + shift[0], g[4] + shift[1])]
    for t in r["standing"]:
        band = "back" if t[5] + shift[1] < 0 and not one_band else "front"
        out.setdefault(band, []).append((t[0], t[1], t[2], t[3] + shift[0], t[4] + shift[1]))
    return out


def box_of(layers):
    """(x0, y0, x1, y1) of everything in a layers dict, px from the middle of the hex; None when it is empty."""
    rects = [(x, y, x + w, y + h) for items in layers.values() for _, w, h, x, y in items]
    if not rects:
        return None
    return (min(q[0] for q in rects), min(q[1] for q in rects), max(q[2] for q in rects), max(q[3] for q in rects))


def union_box(boxes):
    boxes = [b for b in boxes if b]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def size_for(box):
    """The smallest picture size that holds the box, or None."""
    for s in SIZES:
        if box[2] - box[0] <= s and box[3] - box[1] <= s:
            return s
    return None


def anchor_for(size, box):
    """The pixel of a size x size picture that sits on the middle of the hex: the usual place, moved only as far as the box needs."""
    ax = max(-box[0], min(size - box[2], int(round(size * PREFERRED[0]))))
    ay = max(-box[1], min(size - box[3], int(round(size * PREFERRED[1]))))
    return ax, ay


def compose(items, size, anchor):
    """One picture from a part's items (straight alpha, laid over each other in order)."""
    s = blank((size, size))
    for raw, w, h, x, y in items:
        s.blit(pygame.image.frombuffer(bytes(raw), (w, h), "RGBA"), (anchor[0] + x, anchor[1] + y))
    return s


def sort_of(family, part, shift):
    if family == "harbour_addon":
        return 34 if shift[1] >= 0 else -34       # a harbour stands seaward of everything on its hex
    return {"back": BACK_SORT, "front": FRONT_SORT}.get(part, 0)


def piece_name(family, level, variant, mirror, extra, part):
    return "piece/%s/%d/%d/%d/%s/%s" % (family, level, variant, int(bool(mirror)), extra or "-", part)
