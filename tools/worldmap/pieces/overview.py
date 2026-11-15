"""The overview: every family of normal-map pieces, on two pages.

overview.png     Summer. One row per family (sixteen), every level side by side, each piece standing in its terrain's
                 wild land as on the map (grazing shows sheep, with the cattle and horse top levels beside it). Below:
                 the mines by ore, the six sites, and the ten landmark cities beside a plain city.
overview_2.png   The same in the snow winter (the frost and mild winters: winters.png). Below: what the map makes of
                 one piece: the layouts (three for vineyard, grazing and castles) and the mirror, the sea on four
                 sides, a port's harbour add-on and the carved harbour.

Run from the repository root:

    python tools/worldmap/pieces/overview.py            # writes both into docs/design/map/pieces/
    python tools/worldmap/pieces/overview.py OUT_DIR    # or into any other folder
"""
import os
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pygame

import kit
import families as F

pygame.init()

# extra cells at the end of a family's row: (label, level, draw keywords)
EXTRAS = {"Grazing": [("cattle 3", 3, {"animal": "cattle"}), ("horses 3", 3, {"animal": "horses"})]}

PAD = 4
CELL = kit.SIZE + PAD * 2          # 120
GAP = 3
LABEL_W = 96
COLS = 6                           # the widest row: grazing (4 levels + 2 animals)
BLOCK_W = LABEL_W + COLS * (CELL + GAP) + 14
ROW_H = CELL + 8
W = 16 + BLOCK_W * 2
STRIP = 13                         # cells in a full-width strip


def cell(piece, season, ground, tag):
    s = kit.backdrop(season, CELL, CELL, ground)
    s.blit(piece, (PAD, PAD))
    f = kit._font(16)
    t = f.render(tag, True, (40, 44, 40) if season != "winter" else (90, 96, 110))
    s.blit(t, (4, 3))
    return s


def row(out, x, y, title, name, ground, season):
    mod = F.mod(name)
    f_h, f_s = kit._font(22), kit._font(16)
    out.blit(f_h.render(title, True, kit.SHEET_TEXT), (x, y + 44))
    out.blit(f_s.render(season, True, kit.SHEET_DIM), (x, y + 64))
    cx = x + LABEL_W
    for lv in mod.LEVELS:
        out.blit(cell(kit.with_wild(mod.draw, lv, season), season, ground, "%d %s" % (lv, mod.NAMES.get(lv, ""))), (cx, y))
        cx += CELL + GAP
    for tag, lv, kw in EXTRAS.get(title, []):
        out.blit(cell(kit.with_wild(mod.draw, lv, season, **kw), season, ground, tag), (cx, y))
        cx += CELL + GAP


def strip(out, y, cells, season):
    """A full-width strip of cells: (tag, module name, ground, level, keywords)."""
    for j, (tag, name, ground, lv, kw) in enumerate(cells):
        img = kit.with_wild(F.mod(name).draw, lv, season, **kw)
        out.blit(cell(img, season, ground, tag), (16 + j * (CELL + GAP), y))


def ores_and_sites():
    cells = [("mine 3", "mines", "rock", 3, {})]
    cells += [("%s 3" % o, "mines", "rock", 3, {"ore": o}) for o in F.ORES[1:]]
    cells += [("gold 1", "mines", "rock", 1, {"ore": "gold"}), ("gold 2", "mines", "rock", 2, {"ore": "gold"})]
    cells += [(s.replace("_", " "), "sites", "grass", 1, {"variant": i}) for i, s in enumerate(F.site_names())]
    return cells


def cities():
    cells = [("a plain city", "settlements", "grass", 5, {})]
    cells += [(n.capitalize(), "settlements", "grass", 5, {"landmark": n}) for n in F.landmark_names()]
    cells += [("Venice, level 4", "settlements", "grass", 4, {"landmark": "venice"}), ("Moscow, level 4", "settlements", "grass", 4, {"landmark": "moscow"})]
    return cells[:STRIP]


def families_block(out, top, season):
    n = (len(F.FAMILIES) + 1) // 2
    for i, (title, name, ground, levels, kw) in enumerate(F.FAMILIES):
        row(out, 16 + (i // n) * BLOCK_W, top + (i % n) * ROW_H, title, name, ground, season)
    return top + n * ROW_H


def page(path, season, title, sub, lower):
    f_n = kit._font(18)
    top = 50
    n = (len(F.FAMILIES) + 1) // 2
    y1 = top + n * ROW_H + 34
    y2 = y1 + ROW_H + 26
    H = y2 + ROW_H + 8 + (lower[0] if lower else 0)
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    out.blit(kit._font(30, True).render(title, True, kit.SHEET_TEXT), (16, 10))
    out.blit(f_n.render(sub, True, kit.SHEET_DIM), (16 + kit._font(30, True).size(title)[0] + 24, 18))
    families_block(out, top, season)
    out.blit(f_n.render("The mines by ore (levels 1 and 2 differ by colour only; gold has its own layout), and the six sites "
                        "(one level: an old stone thing alone in the wild land)", True, kit.SHEET_DIM), (16, y1 - 22))
    strip(out, y1, ores_and_sites(), season)
    out.blit(f_n.render("Landmark cities: a settlement of level 4 or 5 whose monument takes the church's place "
                        "(all ten, both layouts, 50%: landmarks.png)", True, kit.SHEET_DIM), (16, y2 - 22))
    strip(out, y2, cities(), season)
    if lower:
        lower[1](out, y2 + ROW_H + 30)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    print("wrote", os.path.normpath(path), out.get_size(), "%d kB" % (os.path.getsize(path) // 1024))


def by_the_hex(out, y):
    """What the map makes of one piece: the layouts and the mirror, the sea side, the port."""
    f_n = kit._font(18)
    out.blit(f_n.render("The same level, chosen by the hex (kit.pick): wheat's two layouts and their mirrors; the three layouts of "
                        "vineyard, castles and grazing (sheep, and the horses' round paddocks)", True, kit.SHEET_DIM), (16, y - 22))
    cells = [("wheat: layout %d%s" % (v, ", mirror" if m else ""), "wheat", "farm", 3, {"variant": v, "mirror": m})
             for v, m in ((0, False), (0, True), (1, False), (1, True))]
    cells += [("vineyard: layout %d" % v, "vineyard", "grass", 3, {"variant": v}) for v in range(3)]
    cells += [("castle: layout %d" % v, "castles", "grass", 3, {"variant": v}) for v in range(3)]
    cells += [("sheep: layout 1", "grazing", "grass", 3, {"variant": 1}), ("sheep: layout 2", "grazing", "grass", 3, {"variant": 2}),
              ("horses: layout 2", "grazing", "grass", 3, {"variant": 2, "animal": "horses"})]
    strip(out, y, cells, "summer")
    y += ROW_H + 26
    out.blit(f_n.render("The sea where the map has it (harbour 3 and salt 3 on four sides); a port = town + harbour add-on (levels 2 and 3); "
                        "the carved harbour in the map's bay (ports.png)", True, kit.SHEET_DIM), (16, y - 22))
    import harbour
    import salt
    j = 0
    for mod, ground, name in ((harbour, "grass", "harbour"), (salt, "sand", "salt")):
        for side in ("E", "NW", "N", "SW"):
            out.blit(cell(kit.with_wild(mod.draw, 3, "summer", sea=side), "summer", ground, "%s: sea %s" % (name, side)), (16 + j * (CELL + GAP), y))
            j += 1
    for lv in (2, 3):
        out.blit(cell(kit.with_wild(harbour.draw, lv, "summer", addon=True), "summer", "grass", "add-on %d" % lv), (16 + j * (CELL + GAP), y))
        j += 1
    for lv in (1, 3):
        img = kit.with_wild(harbour.draw, lv, "summer", bay=(0.0, kit.BAY_WIDTH, 13.0))
        out.blit(cell(img, "summer", "grass", "carved %d" % lv), (16 + j * (CELL + GAP), y))
        j += 1


def main(folder):
    page(os.path.join(folder, "overview.png"), "summer", "Normal-map pieces: every family, every level",
         "Summer, 100% (hex radius 60). Each piece on its own terrain, in the wild land the map draws. Winter and the layouts: overview_2.png",
         None)
    page(os.path.join(folder, "overview_2.png"), "winter", "Normal-map pieces: winter, layouts, coasts",
         "The snow winter (snow roofs keep a roof-colour eave; still water frozen, the sea open). The frost and mild winters: winters.png",
         (2 * ROW_H + 60, by_the_hex))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    arg = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    if arg.lower().endswith(".png"):            # the old call with a file name: its folder
        arg = os.path.dirname(os.path.abspath(arg))
    main(arg)
