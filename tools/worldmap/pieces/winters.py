"""Two contract sheets of round 3: the three winters, and the two port modes.

winters.png   Winter by climate (guide section 7). Every family's wild land and top level in the snow winter, the
              frost winter and the mild winter, at 100% and at 50%. The modules are called as always,
              draw(level, "winter"); the kit is told the hex's winter (kit.with_wild(..., climate=)).
ports.png     The two port modes (guide section 10): the harbour on an open shore (seaside) and in a bay the map
              carved (the kit's stand-in bay: Piece(bay=...)), with the bay's horns and mouth line marked; and the
              salt pans on an open shore and on a lagoon.

    python tools/worldmap/pieces/winters.py             # writes both into docs/design/map/pieces/
    python tools/worldmap/pieces/winters.py OUT_DIR
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

pygame = kit.pygame

# title, module, ground, the level shown, draw keywords
FAMILIES = [
    ("Settlements", "settlements", "grass", 4, {}),
    ("Wheat", "wheat", "farm", 3, {}),
    ("Vineyard", "vineyard", "grass", 3, {}),
    ("Olives", "olives", "grass", 3, {}),
    ("Grazing", "grazing", "grass", 3, {}),
    ("Timber", "timber", "wood", 3, {}),
    ("Mines", "mines", "rock", 3, {}),
    ("Salt pans", "salt", "sand", 3, {}),
    ("Harbour", "harbour", "grass", 3, {}),
]
WILD_GROUND = {"Settlements": ("grass", 3)}        # a family without a level 0: kit.wild(ground, seed)
NOTE = {"snow": "snow (hard)", "frost": "frost (light)", "mild": "mild (Mediterranean)"}


def winters(path):
    pad = 4
    cw = kit.SIZE + pad * 2
    hw = cw // 2
    left, top = 110, 104
    x_top = left + 3 * (cw + 4) + 18
    x50 = x_top + 3 * (cw + 4) + 22
    W = x50 + 3 * (hw + 3) + 16
    H = top + len(FAMILIES) * (cw + 6) + 16
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    f_t, f_h, f_s = kit._font(30, True), kit._font(22), kit._font(17)
    out.blit(f_t.render("Winter by climate: the three winters", True, kit.SHEET_TEXT), (16, 10))
    out.blit(f_s.render("The same call, draw(level, \"winter\"); the kit is told the hex's winter. Left: the wild land. "
                        "Middle: the top level. Right: the top level at 50%.", True, kit.SHEET_DIM), (16, 42))
    out.blit(f_s.render("the wild land (level 0)", True, kit.SHEET_DIM), (left + 2, top - 38))
    out.blit(f_s.render("the top level", True, kit.SHEET_DIM), (x_top + 2, top - 38))
    out.blit(f_s.render("50% test", True, kit.SHEET_DIM), (x50 + 2, top - 38))
    for j, c in enumerate(kit.CLIMATES):
        for x0 in (left, x_top):
            out.blit(f_s.render(NOTE[c], True, kit.SHEET_TEXT), (x0 + j * (cw + 4) + 2, top - 20))
        out.blit(f_s.render(c, True, kit.SHEET_DIM), (x50 + j * (hw + 3) + 2, top - 20))
    for i, (title, name, ground, lv, kw) in enumerate(FAMILIES):
        y = top + i * (cw + 6)
        out.blit(f_h.render(title, True, kit.SHEET_TEXT), (12, y + 44))
        try:
            mod = importlib.import_module(name)
        except Exception as e:                            # a module that is being edited: leave its row empty
            out.blit(f_s.render("(module not ready: %s)" % type(e).__name__, True, kit.SHEET_DIM), (left, y + 50))
            continue
        out.blit(f_s.render("level %d" % lv, True, kit.SHEET_DIM), (12, y + 64))
        for j, c in enumerate(kit.CLIMATES):
            if 0 in mod.LEVELS:
                w0 = kit.with_wild(mod.draw, 0, "winter", climate=c, **kw)
            else:
                w0 = kit.wild("winter", *WILD_GROUND[title], climate=c)
            img = kit.with_wild(mod.draw, lv, "winter", climate=c, **kw)
            out.blit(kit._cell(w0, "winter", 1.0, pad, ground, c), (left + j * (cw + 4), y))
            out.blit(kit._cell(img, "winter", 1.0, pad, ground, c), (x_top + j * (cw + 4), y))
            out.blit(kit._cell(img, "winter", 0.5, pad, ground, c), (x50 + j * (hw + 3), y + 30))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    print("wrote", os.path.normpath(path), out.get_size())


def _marked(img, sea, bay, coast):
    """The piece with the bay's horns and mouth line drawn on it (what shore.bay tells the module)."""
    p = kit.Piece("summer", sea=sea, bay=bay, base=False)
    s = p.coast(**coast)
    out = img.copy()
    if s.bay is not None:
        a, b = s.bay.pt(s.bay.west), s.bay.pt(s.bay.east)
        T = lambda q: (q[0] + kit.C, q[1] + kit.C)
        pygame.draw.line(out, (196, 52, 48), T(a), T(b), 1)
        for q in (a, b):
            pygame.draw.circle(out, (196, 52, 48), T(q), 2)
    return out


def ports(path):
    import harbour
    import salt
    pad = 4
    cw = kit.SIZE + pad * 2
    left, top = 150, 70
    sides = ("S", "E", "NW")
    rows = [
        ("Harbour 3", "seaside: an open shore", harbour, "grass", 3, None, {}),
        ("Harbour 3", "carved: the map's bay", harbour, "grass", 3, (0.0, kit.BAY_WIDTH, 13.0), {}),
        ("Harbour add-on 3", "carved: the map's bay", harbour, "grass", 3, (0.0, kit.BAY_WIDTH, 13.0), {"addon": True}),
        ("Harbour 1", "carved: the map's bay", harbour, "grass", 1, (0.0, kit.BAY_WIDTH, 13.0), {}),
        ("Salt 3", "an open shore", salt, "sand", 3, None, {}),
        ("Salt 3", "a lagoon (a bay)", salt, "sand", 3, (0.0, kit.BAY_WIDTH, 10.0), {}),
    ]
    W = left + 2 * len(sides) * (cw + 4) + 30
    H = top + len(rows) * (cw + 6) + 34
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    f_t, f_h, f_s = kit._font(30, True), kit._font(21), kit._font(17)
    out.blit(f_t.render("Ports: seaside and carved", True, kit.SHEET_TEXT), (16, 10))
    out.blit(f_s.render("Left: summer on three sea sides. Right: the same, winter. Red: the bay's horns and mouth line "
                        "(shore.bay). The modules do not use the bay yet (review task 9).", True, kit.SHEET_DIM), (16, 42))
    for r, (title, sub, mod, ground, lv, bay, kw) in enumerate(rows):
        y = top + r * (cw + 6)
        out.blit(f_h.render(title, True, kit.SHEET_TEXT), (12, y + 40))
        out.blit(f_s.render(sub, True, kit.SHEET_DIM), (12, y + 60))
        for k, se in enumerate(("summer", "winter")):
            for j, side in enumerate(sides):
                img = kit.with_wild(mod.draw, lv, se, sea=side, bay=bay, **kw)
                if bay and se == "summer":
                    img = _marked(img, side, bay, mod.COAST)
                out.blit(kit._cell(img, se, 1.0, pad, ground), (left + (k * len(sides) + j) * (cw + 4) + k * 14, y))
    for k, se in enumerate(("summer", "winter")):
        for j, side in enumerate(sides):
            out.blit(f_s.render("%s, sea %s" % (se, side), True, kit.SHEET_DIM),
                     (left + (k * len(sides) + j) * (cw + 4) + k * 14 + 4, top + len(rows) * (cw + 6)))
    pygame.image.save(out, path)
    print("wrote", os.path.normpath(path), out.get_size())


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    winters(os.path.join(folder, "winters.png"))
    ports(os.path.join(folder, "ports.png"))
