"""Tile atlases on a fixed grid, and the index a Godot tool turns into a TileSet (shell/mapview/tileset_builder.gd).

One GridAtlas is one TileSetAtlasSource: every tile has the same picture size (`region`), so Godot needs no per-tile
rectangle. A tile has a name, the pixel of its picture that sits on the middle of the cell (`anchor`), where its foot
is for depth sorting (`y_sort`, px below the middle of the cell) and its rank in a blended layer (`z`).
Pictures are 32-bit surfaces with straight alpha.
"""
import os

import pygame

MAX_SIDE = 4096


def blank(size):
    return pygame.Surface(size, pygame.SRCALPHA)


def from_rgba(buf, size):
    return pygame.image.frombuffer(bytes(buf), size, "RGBA").copy()


class GridAtlas:
    def __init__(self, name, region, anchor=None, sep=2):
        self.name = name
        self.region = tuple(region)
        self.anchor = anchor or (region[0] // 2, region[1] // 2)
        self.sep = sep
        self.tiles = []
        self.surfs = []

    def add(self, name, surf, anchor=None, y_sort=0, z=0):
        assert surf.get_size() == self.region, (name, surf.get_size(), self.region)
        self.tiles.append({"name": name, "anchor": list(anchor or self.anchor), "y_sort": y_sort, "z": z})
        self.surfs.append(surf)

    def save(self, out_dir):
        """Writes <name>.png and returns the source's entry for the index."""
        w, h = self.region
        sep = self.sep
        cols = max(1, min(len(self.surfs), (MAX_SIDE + sep) // (w + sep)))
        rows = (len(self.surfs) + cols - 1) // cols
        assert rows * (h + sep) - sep <= MAX_SIDE, "%s: too many tiles for one atlas (%d)" % (self.name, len(self.surfs))
        sheet = blank((cols * (w + sep) - sep, rows * (h + sep) - sep))
        for i, s in enumerate(self.surfs):
            cx, cy = i % cols, i // cols
            # the sheet is empty, so adding copies the tile as it is (straight alpha, nothing blended)
            sheet.blit(s, (cx * (w + sep), cy * (h + sep)), special_flags=pygame.BLEND_RGBA_ADD)
            self.tiles[i]["at"] = [cx, cy]
        pygame.image.save(sheet, os.path.join(out_dir, self.name + ".png"))
        return {"name": self.name, "file": self.name + ".png", "region": [w, h], "separation": sep,
                "size": list(sheet.get_size()), "tiles": self.tiles}
