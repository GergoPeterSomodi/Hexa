"""Sprite atlases for the Godot bake: dedupe, shelf packing, straight-alpha PNGs. Needs pygame only.

Everything here works on pygame Surfaces with straight (not premultiplied) alpha, which is what Godot loads from a
PNG. `unpremultiply` turns the kit's premultiplied pictures (smoothscaled from 2x, as compose.py blits them with
BLEND_PREMULTIPLIED) into straight alpha, so a normal alpha blend in Godot gives the same pixels.
"""
import hashlib
import json
import os
import re

import pygame

MAX_SIZE = 4096
PAD = 2                      # transparent pixels round every sprite: no bleeding when Godot filters or scales

_UNP = None
_SEMI = bytes(0 if a in (0, 255) else 1 for a in range(256))
_FIND = re.compile(b"\x01")


def _unp_table():
    global _UNP
    if _UNP is None:
        _UNP = [None] + [bytes(min(255, (c * 255 + a // 2) // a) for c in range(256)) for a in range(1, 256)]
    return _UNP


def unpremultiply(surf):
    """A new SRCALPHA surface: the premultiplied picture `surf` as straight alpha (colour / alpha, clamped)."""
    w, h = surf.get_size()
    data = bytearray(pygame.image.tobytes(surf, "RGBA"))
    alpha = bytes(data[3::4])
    tbl = _unp_table()
    for m in _FIND.finditer(alpha.translate(_SEMI)):
        i = m.start()
        t = tbl[alpha[i]]
        j = 4 * i
        data[j] = t[data[j]]
        data[j + 1] = t[data[j + 1]]
        data[j + 2] = t[data[j + 2]]
    return pygame.image.frombytes(bytes(data), (w, h), "RGBA")


def crop(surf):
    """(cropped copy, (x, y)): the surface cut to its non-transparent box, and where the box's top-left lay in it.
    None when nothing is visible."""
    r = surf.get_bounding_rect()
    if not r.width or not r.height:
        return None
    return surf.subsurface(r).copy(), (r.x, r.y)


def digest(surf):
    return hashlib.blake2b(pygame.image.tobytes(surf, "RGBA") + repr(surf.get_size()).encode(), digest_size=12).hexdigest()


class Atlas:
    """A group of sprites packed into one or more PNG atlases of at most MAX_SIZE square. Identical pictures are stored
    once. add() returns a handle; after pack(), rect(handle) gives (file stem, [x, y, w, h])."""

    def __init__(self, stem):
        self.stem = stem
        self.sprites = {}            # digest -> Surface
        self.where = {}              # digest -> (stem, rect)
        self.files = []              # [(stem, w, h)]

    def add(self, surf):
        d = digest(surf)
        if d not in self.sprites:
            self.sprites[d] = surf
        return d

    def pack(self, out_dir, save=True):
        items = sorted(self.sprites.items(), key=lambda kv: (-kv[1].get_height(), -kv[1].get_width(), kv[0]))
        n = 0
        cur = None
        x = y = shelf = 0
        placed = []

        def flush():
            nonlocal cur, placed, n
            if cur is None:
                return
            used_w = max(r[2] + r[0] for _, r in placed) + PAD
            used_h = max(r[3] + r[1] for _, r in placed) + PAD
            stem = "%s_%d" % (self.stem, n) if n else self.stem
            sheet = pygame.Surface((used_w, used_h), pygame.SRCALPHA)
            for d, r in placed:
                sheet.blit(self.sprites[d], (r[0], r[1]))
                self.where[d] = (stem, [r[0], r[1], r[2], r[3]])
            if save:
                os.makedirs(out_dir, exist_ok=True)
                pygame.image.save(sheet, os.path.join(out_dir, stem + ".png"))
            self.files.append((stem, used_w, used_h))
            n += 1
            cur = None
            placed = []
        for d, s in items:
            w, h = s.get_size()
            if w + 2 * PAD > MAX_SIZE or h + 2 * PAD > MAX_SIZE:
                raise ValueError("sprite %dx%d does not fit an atlas" % (w, h))
            if cur is None:
                cur = True
                x, y, shelf = PAD, PAD, 0
            if x + w + PAD > MAX_SIZE:                  # next shelf
                x, y = PAD, y + shelf + PAD
                shelf = 0
            if y + h + PAD > MAX_SIZE:                  # next atlas
                flush()
                cur = True
                x, y, shelf = PAD, PAD, 0
            placed.append((d, (x, y, w, h)))
            x += w + PAD
            shelf = max(shelf, h)
        flush()
        return self.files

    def rect(self, handle):
        return self.where[handle]


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, separators=(",", ":"), ensure_ascii=False)
