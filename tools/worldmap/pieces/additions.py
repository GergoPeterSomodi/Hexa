"""The kit's additions for the families brought over from the Python tiles (GUIDE sections 4, 6 and 8), on one page.

Row 1: the new ground calls and the mulberry tree in the four seasons and the two other winters:
       p.drystone() pastures with a p.ring(kind="stone") fold, a p.ring() paddock, p.arc() contour rows, the hemp and
       cotton crop colours, a mulberry row.   These are demonstrations of the CALLS, not family designs.
Row 2: the new colour tokens, and kit.pick() with three layouts on a block of hexes.

python additions.py        writes docs/design/map/pieces/kit_additions.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
import pygame

COLS = [("spring", None), ("summer", None), ("autumn", None), ("winter", "snow"), ("winter", "frost"), ("winter", "mild")]


def pasture(season):
    p = kit.Piece(season, ground="grass", seed=21)
    walls = [[(-34, -20), (-8, -26), (-2, -4), (-30, 2)], [(-2, -4), (26, -12), (34, 8), (4, 16)], [(-30, 2), (-2, -4), (4, 16), (-22, 24)]]
    for w in walls:
        p.patch(w, kit.crop("meadow", season)[0])
        p.drystone(w, closed=True)
    p.ring(18, 26, 6.5, kind="stone", gate=200)
    for x, y in ((-22, -12), (-14, -8), (10, 0), (20, 4), (-12, 12), (17, 27), (20, 25)):
        p.animal(x, y, "sheep")
    return p.finish(label="demo pasture")


def paddock(season):
    p = kit.Piece(season, ground="grass", seed=21)
    p.patch(kit.ring_points(0, 2, 22, 22 * kit.TILT, 0, 2 * math.pi), kit.crop("meadow", season)[0])
    p.blob(0, 2, 30, 20, p.pal["soil"], alpha=0.3)
    p.ring(0, 2, 22, gate=90)
    for x, y, f in ((-8, 0, False), (6, -6, True), (9, 8, False)):
        p.animal(x, y, "horse", f)
    return p.finish(label="demo paddock")


def contour(season):
    p = kit.Piece(season, ground="grass", seed=21)
    cx, cy = 0, -8
    for a0, a1, dashed in ((20, 75, False), (80, 135, False), (140, 190, True)):
        inner = kit.ring_points(cx, cy, 13, 9, math.radians(a0), math.radians(a1), 12)
        outer = kit.ring_points(cx, cy, 39, 30, math.radians(a0), math.radians(a1), 12)
        p.patch(inner + outer[::-1], kit.crop("vine_soil", season)[0], kit.shade(kit.crop("vine_soil", season)[0], 0.8))
        for i in range(6):
            p.arc(cx, cy, 15.5 + i * 4.3, 11 + i * 3.5, a0 + 2, a1 - 2, dashed=dashed)
    p.house(cx, cy, 8, 5, 3.8)
    return p.finish(label="demo contour")


def crops(season):
    p = kit.Piece(season, ground="farm", seed=21)
    for cx, cy in ((-24, -14), (-8, -18)):
        p.field(cx, cy, 14, 12, 8, kit.crop("hemp", season), 2)
        if season == "spring":
            p.rows(cx, cy, 14, 12, 8, 4, col=kit.crop("hemp_row", season)[0], soil=False, dashed=True)
    p.pond([(-30, -2), (-20, -3), (-19, 3), (-29, 4)], col=kit.RET, edge=kit.RET_D)
    p.rows(16, 4, 30, 22, -6, 7, col=kit.crop("cotton", season)[0], soil=kit.crop("cotton_soil", season)[0])
    if season in ("summer", "autumn"):
        for i in range(7):
            for j in range(5 if season == "summer" else 3):
                p.patch([(4.5 + i * 4.2 + j * 0.4, -3 + j * 3.6), (5.6 + i * 4.2 + j * 0.4, -3 + j * 3.6), (5.6 + i * 4.2 + j * 0.4, -2 + j * 3.6),
                         (4.5 + i * 4.2 + j * 0.4, -2 + j * 3.6)], kit.BOLL)
    for i in range(8):
        p.tree(-34 + i * 5.2, 28 - i * 0.5, 1.0, "mulberry", i)
    return p.finish(label="demo crops")


def main(path):
    pygame.init()
    font, small = kit._font(22, True), kit._font(16)
    demos = [("drystone + stone ring", pasture), ("ring (paddock)", paddock), ("arc (contour rows)", contour), ("hemp, cotton, mulberry", crops)]
    cw = kit.SIZE + 8
    W, H = 150 + len(COLS) * cw + 420, 60 + len(demos) * cw + 150
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    out.blit(kit._font(28, True).render("Kit additions: calls, crops, tokens, pick with three layouts", True, kit.SHEET_TEXT), (14, 10))
    for j, (se, cl) in enumerate(COLS):
        out.blit(small.render(se if cl in (None, "snow") else "winter: " + cl, True, kit.SHEET_DIM), (150 + j * cw + 8, 40))
    for i, (name, fn) in enumerate(demos):
        out.blit(small.render(name, True, kit.SHEET_TEXT), (10, 60 + i * cw + 50))
        for j, (se, cl) in enumerate(COLS):
            with kit.climate(cl):
                img = fn(se)
                out.blit(kit._cell(img, se, 1.0, 4, "farm" if fn is crops else "grass", cl), (150 + j * cw, 60 + i * cw))
    x0, y = 150 + len(COLS) * cw + 20, 60
    toks = [("MARBLE", kit.MARBLE), ("MARBLE_D", kit.MARBLE_D), ("PIT", kit.PIT), ("PIT_D", kit.PIT_D), ("RET", kit.RET), ("RET_D", kit.RET_D),
            ("BOLL", kit.BOLL), ("DOME_TILE", kit.DOME_TILE), ("DOME_TILE_D", kit.DOME_TILE_D), ("PELT", kit.PELT), ("PELT_D", kit.PELT_D),
            ("GLOW", kit.GLOW), ("VERDIGRIS", kit.VERDIGRIS), ("VERDIGRIS_D", kit.VERDIGRIS_D), ("BRICK", kit.BRICK), ("BRICK_D", kit.BRICK_D),
            ("LEAD", kit.LEAD), ("LEAD_D", kit.LEAD_D), ("GILT", kit.GILT)]
    toks += [("DYE " + k, v) for k, v in kit.DYE.items()] + [("ONION %d" % i, c) for i, c in enumerate(kit.ONION)]
    for o, d in kit.ORES.items():
        toks += [("ORES %s %s" % (o, k), d[k]) for k in ("spoil", "spoil_d", "ore", "ore_d")]
    for i, (n, c) in enumerate(toks):
        xx, yy = x0 + (i % 2) * 200, y + (i // 2) * 15
        pygame.draw.rect(out, c, (xx, yy, 26, 12))
        out.blit(small.render(n, True, kit.SHEET_DIM), (xx + 32, yy - 1))
    y += (len(toks) + 1) // 2 * 15 + 14
    out.blit(small.render("kit.pick(col, row, 3): layout 0 / 1 / 2, m = mirrored", True, kit.SHEET_TEXT), (x0, y))
    cols3 = [(196, 170, 96), (110, 150, 190), (170, 110, 150)]
    for r in range(6):
        for c in range(9):
            v, m = kit.pick(c, r, 3)
            cx, cy = x0 + 22 + c * 40 + (r & 1) * 20, y + 40 + r * 30
            pts = [(cx + 20 * math.cos(math.radians(60 * k - 90)), cy + 17 * math.sin(math.radians(60 * k - 90))) for k in range(6)]
            pygame.draw.polygon(out, cols3[v], pts)
            pygame.draw.polygon(out, kit.SHEET_BG, pts, 1)
            out.blit(small.render("%d%s" % (v, "m" if m else ""), True, (30, 30, 40)), (cx - 8, cy - 9))
    pygame.image.save(out, path)
    print("wrote", path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces", "kit_additions.png"))
