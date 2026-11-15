"""The kit's map contract on one page: wild land, the coast, the footprint, the mirror and pick().

A demonstration and a test of kit.py, not a family. It shows what the owner decided on 2026-11-15 (see
docs/design/map/pieces/GUIDE.md, sections 1, 6, 10 and 12) with the families as they are today:

  1  The wild land of each terrain, as kit.wild() draws it: the level 0 column of every family sheet.
  2  The coast: one small coast piece (FISHING below: copy its use of shore.pt) with the sea on different sides
     and on a shore line given by the map.
  3  The footprint: the area a piece works (red), and the piece standing in wild land thinned by it.
  4  The mirror: positions turned round, the light still from the upper left.
  5  kit.pick(col, row): which picture each hex of a block shows.

    python tools/worldmap/pieces/contract.py            # writes docs/design/map/pieces/kit_contract.png
    python tools/worldmap/pieces/contract.py out.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
import castles
import settlements
import wheat

pygame = kit.pygame


def fishing(season="summer", sea=None, shore=None, mirror=False):
    """A coast piece written in shore coordinates: u px along the shore, v px out to sea (v < 0 is inland).
    The same table works for every sea side; the kit turns (u, v) into piece px."""
    p = kit.Piece(season, ground="grass", seed=4, sea=sea, shore=shore, mirror=mirror)
    s = p.coast(13.0, amp=1.2, sand=5.0, seed=5)
    p.jetty(s.pt(-18, -1.5), s.pt(6, -1.5), 3.0, stone=True)          # a quay along the shore
    p.jetty(s.pt(12, -1), s.pt(12, 15), 1.8)                          # a jetty out to sea
    for u, v, smoke in ((-14, -13, True), (2, -17, False)):           # two huts inland
        p.house(*s.pt(u, v), 5.5, 3.5, 3.0, roof="thatch", smoke=smoke)
    p.house(*s.pt(-6, -5), 11.5, 5.2, 4.4, wall=1, roof="tile", door=False)      # a warehouse on the quay
    p.boat(*s.pt(-12, 13), 1.0)
    p.boat(*s.pt(20, 9), 0.7)
    return p.finish(label="fishing demo")


def cell(img, season="summer", ground="grass", scale=1.0):
    return kit._cell(img, season, scale, 6, ground)


def tinted(lay, season, ground):
    """The piece's layers on plain ground with the footprint in red."""
    s = kit.backdrop(season, kit.SIZE, kit.SIZE, ground)
    g = pygame.transform.smoothscale(lay["ground"], (kit.SIZE, kit.SIZE))
    s.blit(g, (0, 0))
    o = pygame.Surface((kit.SIZE * kit.SS, kit.SIZE * kit.SS), pygame.SRCALPHA)
    for foot, order, fn in lay["standing"]:
        fn(kit.Pen(o))
    s.blit(pygame.transform.smoothscale(o, (kit.SIZE, kit.SIZE)), (0, 0))
    s.blit(lay["footprint"].to_surface(setcolor=(220, 40, 40, 90), unsetcolor=(0, 0, 0, 0)), (0, 0))
    out = pygame.Surface((kit.SIZE, kit.SIZE), pygame.SRCALPHA)
    out.blit(s, (0, 0))
    return out


def in_a_wood(draw, level, season):
    """The piece as it would stand in a wooded hex: the wood's scatter instead of its own terrain's."""
    old = dict(kit.WILD_MIX)
    for k in kit.WILD_MIX:
        kit.WILD_MIX[k] = old["wood"]
    try:
        return kit.with_wild(draw, level, season)
    finally:
        kit.WILD_MIX.update(old)


def main(path):
    f_t, f_h, f_s = kit._font(30, True), kit._font(22), kit._font(17)
    cw = kit.SIZE + 12
    rows = []

    # 1 wild land
    r = [("farm", cell(kit.wild("summer", "farm", 1), "summer", "farm")), ("grass", cell(kit.wild("summer", "grass", 3))),
         ("wood", cell(kit.wild("summer", "wood", 7), "summer", "wood")), ("rock", cell(kit.wild("summer", "rock", 6), "summer", "rock")),
         ("sand + coast", cell(kit.wild("summer", "sand", 5, coast={}), "summer", "sand")),
         ("wood, autumn", cell(kit.wild("autumn", "wood", 7), "autumn", "wood")), ("wood, winter", cell(kit.wild("winter", "wood", 7), "winter", "wood")),
         ("grass, winter", cell(kit.wild("winter", "grass", 3), "winter"))]
    rows.append(("1  Wild land as the map draws it: kit.wild(season, ground, seed). Level 0 = no piece on the map", r))

    # 2 the coast
    line = [(-52, 20), (-30, 6), (-8, 2), (10, -10), (30, -14), (52, -30)]
    r = [("no sea given (sheets)", cell(fishing())), ('sea="SE"', cell(fishing(sea="SE"))), ('sea="E"', cell(fishing(sea="E"))),
         ('sea="NE"', cell(fishing(sea="NE"))), ('sea="W"', cell(fishing(sea="W"))), ('sea=("SW", "W")', cell(fishing(sea=("SW", "W")))),
         ('sea="SE" + shore line', cell(fishing(sea="SE", shore=line))), ("the same, mirrored", cell(fishing(sea="SE", shore=line, mirror=True)))]
    rows.append(("2  The coast: the map says where the sea is; the piece builds at that shore with shore.pt(u, v). "
                 "(On the map the kit draws no sea.)", r))

    # 3 the footprint
    r = []
    for name, mod, lv, ground in (("wheat 2", wheat, 2, "farm"), ("town (3)", settlements, 3, "grass"), ("castle 2", castles, 2, "grass")):
        lay = kit.take_apart(mod.draw, lv, "summer")
        r.append((name + ": footprint", cell(tinted(lay, "summer", ground), "summer", ground)))
        r.append((name + " in a wood", cell(in_a_wood(mod.draw, lv, "summer"), "summer", ground)))
    lay = kit.take_apart(settlements.draw, 1, "summer")
    r.append(("hamlet: footprint", cell(tinted(lay, "summer", "grass"))))
    r.append(("hamlet in a wood", cell(in_a_wood(settlements.draw, 1, "summer"))))
    rows.append(("3  The footprint (red): take_apart(...)[\"footprint\"]. The map draws no wild tree or bush with its foot in it", r))

    # 4 the mirror
    r = []
    for name, mod, lv, ground in (("wheat 3", wheat, 3, "farm"), ("city (5)", settlements, 5, "grass"), ("castle 3", castles, 3, "grass")):
        for m in (False, True):
            old, kit.SITE = kit.SITE, {"mirror": m}
            try:
                img = mod.draw(lv, "winter" if name == "city (5)" else "summer")
            finally:
                kit.SITE = old
            se = "winter" if name == "city (5)" else "summer"
            r.append((name + (", mirrored" if m else ""), cell(img, se, ground)))
    rows.append(("4  The mirror: every position turned round; shaded sides and shadows stay on the right", r))

    W = 24 + 8 * (cw + 8) + 16
    field = kit.hex_field(lambda c, q: _picked(c, q), 7, 3, "summer", "farm")
    H = 60 + len(rows) * (cw + 56) + field.get_height() + 60
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    out.blit(f_t.render("The kit's map contract: wild land, coast, footprint, mirror, pick", True, kit.SHEET_TEXT), (16, 12))
    y = 56
    for title, cells in rows:
        out.blit(f_h.render(title, True, kit.SHEET_TEXT), (24, y))
        for i, (name, img) in enumerate(cells):
            out.blit(img, (24 + i * (cw + 8), y + 24))
            out.blit(f_s.render(name, True, kit.SHEET_DIM), (24 + i * (cw + 8) + 2, y + 26 + cw))
        y += cw + 56
    out.blit(f_h.render("5  kit.pick(col, row) on 7 x 3 hexes of wheat level 3 (one layout so far: plain or mirrored; "
                        "with the second layout no two neighbours repeat)", True, kit.SHEET_TEXT), (24, y))
    out.blit(field, (24, y + 26))
    for c in range(7):
        for q in range(3):
            v, m = kit.pick(c, q, kit.variants_of(wheat.draw))
            cx = 24 + 8 + kit.HEX_W / 2 + c * kit.HEX_W + (q & 1) * kit.HEX_W / 2
            cy = y + 26 + 8 + kit.HEX_H / 2 + q * 0.75 * kit.HEX_H
            out.blit(f_s.render("%d%s" % (v, "m" if m else ""), True, (40, 50, 30)), (cx - 6, cy + 30))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    print("wrote", os.path.normpath(path))


_CACHE = {}


def _picked(c, q):
    v, m = kit.pick(c, q, kit.variants_of(wheat.draw))
    if (v, m) not in _CACHE:
        _CACHE[(v, m)] = kit.with_wild(wheat.draw, 3, "summer", variant=v, mirror=m)
    return _CACHE[(v, m)]


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces", "kit_contract.png"))
