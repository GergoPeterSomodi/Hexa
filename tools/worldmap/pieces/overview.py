"""The overview sheet: every family of normal-map pieces on one page.

Top: one summer row per family, every level side by side (grazing shows sheep, with the cattle and horse top levels
beside it). Bottom: a winter row for six families. Run from the repository root:

    python tools/worldmap/pieces/overview.py            # writes docs/design/map/pieces/overview.png
    python tools/worldmap/pieces/overview.py out.png    # or any other path
"""
import os
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pygame

import kit
import castles
import grazing
import harbour
import mines
import olives
import salt
import settlements
import timber
import vineyard
import wheat

pygame.init()

# title, module, ground, extra cells: (label, level, draw keywords)
FAMILIES = [
    ("Settlements", settlements, "grass", []),
    ("Castles", castles, "grass", []),
    ("Wheat", wheat, "farm", []),
    ("Vineyard", vineyard, "grass", []),
    ("Olives", olives, "grass", []),
    ("Grazing", grazing, "grass", [("cattle 3", 3, {"animal": "cattle"}), ("horses 3", 3, {"animal": "horses"})]),
    ("Salt pans", salt, "sand", []),
    ("Mines", mines, "rock", []),
    ("Timber", timber, "wood", []),
    ("Harbour", harbour, "grass", []),
]
WINTER = ["Settlements", "Castles", "Wheat", "Vineyard", "Salt pans", "Timber"]

PAD = 4
CELL = kit.SIZE + PAD * 2          # 120
GAP = 3
LABEL_W = 96
COLS = 6                           # the widest row: grazing (4 levels + 2 animals)
BLOCK_W = LABEL_W + COLS * (CELL + GAP) + 14
ROW_H = CELL + 8


def cell(piece, season, ground, tag):
    s = kit.backdrop(season, CELL, CELL, ground)
    s.blit(piece, (PAD, PAD))
    f = kit._font(16)
    t = f.render(tag, True, (40, 44, 40) if season != "winter" else (90, 96, 110))
    s.blit(t, (4, 3))
    return s


def row(out, x, y, title, mod, ground, extras, season):
    f_h, f_s = kit._font(22), kit._font(16)
    out.blit(f_h.render(title, True, kit.SHEET_TEXT), (x, y + 44))
    out.blit(f_s.render(season, True, kit.SHEET_DIM), (x, y + 64))
    cx = x + LABEL_W
    for lv in mod.LEVELS:
        out.blit(cell(mod.draw(lv, season), season, ground, "%d %s" % (lv, mod.NAMES.get(lv, ""))), (cx, y))
        cx += CELL + GAP
    for tag, lv, kw in extras:
        out.blit(cell(mod.draw(lv, season, **kw), season, ground, tag), (cx, y))
        cx += CELL + GAP


def main(path):
    n_top = (len(FAMILIES) + 1) // 2
    n_bot = (len(WINTER) + 1) // 2
    top = 50
    mid = top + n_top * ROW_H + 34
    W = 16 + BLOCK_W * 2
    H = mid + n_bot * ROW_H + 12
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    out.blit(kit._font(30, True).render("Normal-map pieces: every family, every level", True, kit.SHEET_TEXT), (16, 10))
    out.blit(kit._font(18).render("Summer, 100% (hex radius 60). Each piece on its own terrain.", True, kit.SHEET_DIM), (470, 18))
    for i, (title, mod, ground, extras) in enumerate(FAMILIES):
        row(out, 16 + (i // n_top) * BLOCK_W, top + (i % n_top) * ROW_H, title, mod, ground, extras, "summer")
    out.blit(kit._font(18).render("Winter (snow roofs keep a roof-colour eave; still water frozen, the sea open)", True, kit.SHEET_DIM), (16, mid - 22))
    by = {f[0]: f for f in FAMILIES}
    for i, name in enumerate(WINTER):
        title, mod, ground, extras = by[name]
        row(out, 16 + (i // n_bot) * BLOCK_W, mid + (i % n_bot) * ROW_H, title, mod, ground, [], "winter")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    print("wrote", os.path.normpath(path), out.get_size(), "%d kB" % (os.path.getsize(path) // 1024))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces", "overview.png"))
