"""The look-alike review on two pages: every family, ore, site and landmark city at 50%.

crowding.png        Every family at 50%: the three levels in summer, then the top level in spring, autumn and the
                    three winters. Beside it the five ores, the six sites and the ten landmark cities.
crowding_pairs.png  The pairs that crowd each other (guide section 4), side by side at 50% and at 100%, in the
                    seasons where they come closest.

    python tools/worldmap/pieces/crowding.py             # writes both into docs/design/map/pieces/
    python tools/worldmap/pieces/crowding.py OUT_DIR
"""
import os
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
import families as F

pygame = kit.pygame
pygame.init()

PAD = 4
HW = (kit.SIZE + PAD * 2) // 2 + 3          # a 50% cell and its gap
ROW = HW + 2
# the columns of a family row: (heading, which of the three levels, season, climate); None is a gap
COLUMNS = [("low", 0, "summer", None), ("middle", 1, "summer", None), ("top", 2, "summer", None), None,
           ("spring", 2, "spring", None), ("autumn", 2, "autumn", None), None,
           ("snow", 2, "winter", "snow"), ("frost", 2, "winter", "frost"), ("mild", 2, "winter", "mild")]


def half(img, season, ground, climate=None, scale=0.5):
    return kit._cell(img, season, scale, PAD, ground, climate)


def piece(name, lv, season, climate=None, **kw):
    return kit.with_wild(F.mod(name).draw, lv, season, climate=climate, **kw)


def col_x(x0, k):
    return x0 + sum((10 if c is None else HW) for c in COLUMNS[:k])


def family_row(out, x0, y, title, name, ground, levels, kw):
    out.blit(kit._font(19).render(title, True, kit.SHEET_TEXT), (x0 - 104, y + 22))
    for k, c in enumerate(COLUMNS):
        if c is None:
            continue
        _, li, season, climate = c
        out.blit(half(piece(name, levels[li], season, climate, **kw), season, ground, climate), (col_x(x0, k), y))


def heads(out, x0, y):
    f = kit._font(16)
    for k, c in enumerate(COLUMNS):
        if c is not None:
            out.blit(f.render(c[0], True, kit.SHEET_DIM), (col_x(x0, k) + 2, y))


def crowding(path):
    f_t, f_h, f_s = kit._font(30, True), kit._font(21), kit._font(16)
    x_a = 120
    w_a = col_x(0, len(COLUMNS))
    x_b = x_a + w_a + 150
    cities = ("plain",) + tuple(F.landmark_names())
    W = x_b - 104 + max(w_a + 104, len(cities) * HW) + 16
    top = 84
    H = top + len(F.FAMILIES) * ROW + 16
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    out.blit(f_t.render("The look-alike review: everything at 50%", True, kit.SHEET_TEXT), (16, 10))
    out.blit(f_s.render("Each piece in its terrain's wild land, half size. Left: the families (three levels in summer; the top level in "
                        "spring, autumn and the three winters). Right: ores, sites, landmark cities.", True, kit.SHEET_DIM), (16, 42))
    heads(out, x_a, top - 16)
    for i, (title, name, ground, levels, kw) in enumerate(F.FAMILIES):
        family_row(out, x_a, top + i * ROW, title, name, ground, levels, kw)
    # the ores
    y = top
    heads(out, x_b, y - 16)
    for ore in F.ORES:
        family_row(out, x_b, y, "Mines: %s" % (ore or "plain"), "mines", "rock", (1, 2, 3), {"ore": ore})
        y += ROW
    # the sites
    y += 22
    for j, s in enumerate(F.site_names()):
        out.blit(f_s.render(s.replace("_", " ")[:10], True, kit.SHEET_DIM), (x_b + j * HW + 2, y - 16))
    for r, (season, climate) in enumerate((("summer", None), ("autumn", None), ("winter", "snow"), ("winter", "mild"))):
        if r == 0:
            out.blit(f_h.render("Sites", True, kit.SHEET_TEXT), (x_b - 104, y + 8))
        out.blit(f_s.render(climate or season, True, kit.SHEET_DIM), (x_b - 104, y + 30))
        for j in range(len(F.site_names())):
            out.blit(half(piece("sites", 1, season, climate, variant=j), season, "grass", climate), (x_b + j * HW, y))
        y += ROW
    # the landmark cities
    y += 8
    out.blit(f_h.render("Landmark cities (the first column: a plain city)", True, kit.SHEET_TEXT), (x_b - 104, y))
    y += 20
    for j, c in enumerate(cities):
        out.blit(f_s.render(c[:10], True, kit.SHEET_DIM), (x_b - 104 + j * HW + 2, y))
    y += 14
    for lv, season, climate in ((4, "summer", None), (5, "summer", None), (5, "winter", "snow"), (5, "winter", "mild")):
        for j, c in enumerate(cities):
            kw = {} if c == "plain" else {"landmark": c}
            out.blit(half(piece("settlements", lv, season, climate, **kw), season, "grass", climate), (x_b - 104 + j * HW, y))
        y += ROW
    out.blit(f_s.render("rows: level 4 summer, level 5 summer, level 5 snow winter, level 5 mild winter", True, kit.SHEET_DIM), (x_b - 104, y + 2))
    pygame.image.save(out, path)
    print("wrote", os.path.normpath(path), out.get_size())


# The pairs of guide section 4: (heading, [(label, module, ground, level, keywords)], [(season, climate)])
PAIRS = [
    ("Rows and blocks on worked land: hemp, wheat, cotton, vineyard, silk, olives",
     [("hemp 3", "hemp", "farm", 3, {}), ("wheat 3", "wheat", "farm", 3, {}), ("cotton 3", "cotton", "farm", 3, {}),
      ("vineyard 3", "vineyard", "grass", 3, {}), ("silk 3", "silk", "grass", 3, {}), ("olives 3", "olives", "grass", 3, {})],
     [("spring", None), ("summer", None), ("autumn", None), ("winter", "mild")]),
    ("In the wood and on the rock: furs, timber, castle 1; gold, castle 2",
     [("furs 3", "furs", "wood", 3, {}), ("timber 3", "timber", "wood", 3, {}), ("furs 2", "furs", "wood", 2, {}),
      ("castle 1", "castles", "grass", 1, {}), ("gold 3", "mines", "rock", 3, {"ore": "gold"}), ("castle 2", "castles", "grass", 2, {})],
     [("summer", None), ("winter", "snow")]),
    ("Quarry and mines; dye works and salt",
     [("quarry 3", "quarry", "rock", 3, {}), ("mines 3", "mines", "rock", 3, {}), ("quarry 1", "quarry", "rock", 1, {}),
      ("mines 1", "mines", "rock", 1, {}), ("dyes 3", "dyes", "grass", 3, {}), ("salt 3", "salt", "sand", 3, {})],
     [("summer", None), ("winter", "snow")]),
    ("Sites against what they could be taken for; the three domes",
     [("ruined castle", "sites", "grass", 1, {"variant": 4}), ("castle 1", "castles", "grass", 1, {}),
      ("monastery", "sites", "grass", 1, {"variant": 0}), ("village", "settlements", "grass", 2, {}),
      ("silk 3", "silk", "grass", 3, {}), ("Constantinople", "settlements", "grass", 5, {"landmark": "constantinople"})],
     [("summer", None), ("winter", "snow")]),
]


def pairs(path):
    f_t, f_h, f_s = kit._font(30, True), kit._font(21), kit._font(16)
    cw = kit.SIZE + PAD * 2 + 3
    n = max(len(p[1]) for p in PAIRS)
    x0 = 72
    x1 = x0 + n * HW + 26
    W = x1 + n * cw + 16
    H = 70 + sum(34 + len(p[2]) * (cw + 2) for p in PAIRS) + 10
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    out.blit(f_t.render("The pairs that crowd each other", True, kit.SHEET_TEXT), (16, 10))
    out.blit(f_s.render("Left at 50% (the test), right the same at 100%. Guide section 4 has the rule that keeps each pair apart.",
                        True, kit.SHEET_DIM), (16, 42))
    y = 70
    for title, items, seasons in PAIRS:
        out.blit(f_h.render(title, True, kit.SHEET_TEXT), (16, y))
        for j, it in enumerate(items):
            out.blit(f_s.render(it[0], True, kit.SHEET_DIM), (x1 + j * cw + 2, y + 19))
            out.blit(f_s.render(it[0][:9], True, kit.SHEET_DIM), (x0 + j * HW + 2, y + 19))
        y += 34
        for season, climate in seasons:
            out.blit(f_s.render(climate or season, True, kit.SHEET_DIM), (16, y + 50))
            for j, (label, name, ground, lv, kw) in enumerate(items):
                img = piece(name, lv, season, climate, **kw)
                out.blit(half(img, season, ground, climate), (x0 + j * HW, y + (cw - HW) // 2))
                out.blit(half(img, season, ground, climate, 1.0), (x1 + j * cw, y))
            y += cw + 2
    pygame.image.save(out, path)
    print("wrote", os.path.normpath(path), out.get_size())


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    crowding(os.path.join(folder, "crowding.png"))
    pairs(os.path.join(folder, "crowding_pairs.png"))
