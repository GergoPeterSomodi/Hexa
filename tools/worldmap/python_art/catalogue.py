"""The Python-art catalogue: the frozen Python game's own code-drawn map art, for the owner to pick from.

Every picture is drawn by the Python game's art code (hexa/campaign/goodsart.py, wfctiles.py, landmarks.py,
nature.py, life.py, landscape.py) and scaled to the normal map's hex radius 60, as tools/bake_art.py does. Kenney
pack art is left out. Next to each group stands the matching current normal-map piece (tools/worldmap/pieces) where
one exists. Nothing is converted here; this only shows what there is. Run from the repository root:

    python tools/worldmap/python_art/catalogue.py           # writes docs/design/map/python_art/*.png
    python tools/worldmap/python_art/catalogue.py out_dir   # or into any other folder
"""
import os
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(HERE, "..", "pieces"))

import pygame

pygame.init()
pygame.display.set_mode((1, 1))

import kit                                                     # noqa: E402  the new style's kit (read only)
import castles, grazing, harbour, mines, olives, salt, settlements, timber, vineyard, wheat   # noqa: E402,E401
from tools import bake_art                                     # noqa: E402
from hexa.campaign import goodsart, landmarks, landscape, life, nature, wfctiles   # noqa: E402

TD = bake_art.TILES_DIR            # goodsart wants the folder; none of the 25 goods loads a pack sprite
RW, RH = bake_art.REGION           # 106 x 122: a Python tile at hex radius 60
BG, TEXT, DIM = (27, 30, 46), (236, 236, 228), (150, 156, 176)
HEAD = (236, 190, 90)
CW, CH = 112, 138                  # one cell: the picture and its id under it
GAP = 4
K60 = RW / 120.0                   # object scale from the 120 px tile to radius 60
GRASS = (140, 186, 92)
SEA = (78, 160, 212)


def font(size, bold=False):
    return pygame.font.SysFont("arial", size, bold)


def text(out, s, x, y, size=13, col=TEXT, bold=False):
    out.blit(font(size, bold).render(s, True, col), (x, y))


def cell(img, tag, bg=None):
    """One labelled cell. `img` is centred; `bg` is a ground colour for transparent overlays and objects."""
    s = pygame.Surface((CW, CH), pygame.SRCALPHA)
    if bg is not None:
        pygame.draw.polygon(s, bg, [(x + (CW - RW) / 2, y) for x, y in bake_art._hex(RW / 2, RH / 2, 60)])
    w, h = img.get_size()
    if w > RW or h > RH:
        k = min(RW / w, RH / h)
        img = pygame.transform.smoothscale(img, (round(w * k), round(h * k)))
        w, h = img.get_size()
    s.blit(img, ((CW - w) // 2, (RH - h) // 2))
    t = font(12, True).render(tag, True, TEXT)
    s.blit(t, ((CW - t.get_width()) // 2, RH + 1))
    return s


def now_cell(mod, level, tag, ground, **kw):
    """A current normal-map piece in its wild land, as the overview sheet shows it (gold frame)."""
    s = pygame.Surface((CW, CH), pygame.SRCALPHA)
    b = kit.backdrop("summer", kit.SIZE, kit.SIZE, ground)
    b.blit(kit.with_wild(mod.draw, level, "summer", **kw), (0, 0))
    s.blit(b, (0, (RH - kit.SIZE) // 2))
    pygame.draw.rect(s, HEAD, (0, (RH - kit.SIZE) // 2, kit.SIZE, kit.SIZE), 1)
    t = font(12).render(tag, True, HEAD)
    s.blit(t, ((CW - t.get_width()) // 2, RH + 1))
    return s


def good(g, lv, v=0):
    return bake_art.seamless(goodsart.good_tile(g, lv, TD, v))


def ov(img):
    return bake_art.overlay_size(img)


def obj(surf):
    w, h = surf.get_size()
    return pygame.transform.smoothscale(surf, (max(1, round(w * K60)), max(1, round(h * K60))))


# good -> (current family module, ground, draw keywords); goods not listed have no family in the new style
NOW = {
    "grain": (wheat, "farm", {}), "wine": (vineyard, "grass", {}), "olives": (olives, "grass", {}),
    "wool": (grazing, "grass", {}), "cattle": (grazing, "grass", {"animal": "cattle"}),
    "horses": (grazing, "grass", {"animal": "horses"}), "salt": (salt, "sand", {}),
    "fish": (harbour, "grass", {}), "timber": (timber, "wood", {}),
    "iron": (mines, "rock", {}), "silver": (mines, "rock", {}), "gold": (mines, "rock", {}),
    "copper": (mines, "rock", {}),
}
HAVE = ["grain", "wine", "olives", "wool", "cattle", "horses", "salt", "fish", "timber", "iron", "silver", "gold",
        "copper"]
NEW = ["stone", "hemp", "cotton", "silk", "dyes", "furs", "sugar", "tobacco", "spices", "cocoa", "coffee", "ivory"]


class Page:
    def __init__(self, title, sub, w, h):
        self.s = pygame.Surface((w, h))
        self.s.fill(BG)
        text(self.s, title, 14, 8, 24, TEXT, True)
        text(self.s, sub, 14, 38, 13, DIM)
        self.y = 62

    def head(self, s, x=14):
        self.y += 4
        text(self.s, s, x, self.y, 15, HEAD, True)
        self.y += 22

    def row(self, label, cells, x0=110, sub=None):
        text(self.s, label, 14, self.y + 48, 15, TEXT, True)
        if sub:
            text(self.s, sub, 14, self.y + 68, 11, DIM)
        x = x0
        for c in cells:
            if c is None:
                x += 14
                continue
            self.s.blit(c, (x, self.y))
            x += CW + GAP
        self.y += CH + 2

    def grid(self, cells, per_row, x0=14):
        for i in range(0, len(cells), per_row):
            x = x0
            for c in cells[i:i + per_row]:
                self.s.blit(c, (x, self.y))
                x += CW + GAP
            self.y += CH + 2

    def save(self, path):
        out = self.s.subsurface((0, 0, self.s.get_width(), min(self.s.get_height(), self.y + 8))).copy()
        pygame.image.save(out, path)
        print("wrote", os.path.basename(path), out.get_size(), "%d kB" % (os.path.getsize(path) // 1024))


def goods_page(path, goods, title, with_now):
    sub = "Python goods tiles (goodsart.good_tile), levels 1-5 in layout 0, then level 5 in layout 2. Hex radius 60. Id = good + level."
    if with_now:
        sub += "  Gold frame: the current normal-map family, levels 1-3."
    p = Page(title, sub, 110 + (6 + (3 if with_now else 0)) * (CW + GAP) + 30, 80 + len(goods) * (CH + 14))
    for g in goods:
        cells = [cell(good(g, lv), "%s%d" % (g, lv)) for lv in range(1, 6)]
        cells.append(cell(good(g, 5, 2), "%s5 layout 2" % g))
        if with_now and NOW.get(g):
            mod, ground, kw = NOW[g]
            cells.append(None)
            cells += [now_cell(mod, lv, "now: %s %d" % (mod.__name__, lv), ground, **kw) for lv in (1, 2, 3)]
        p.row(g, cells)
        for i, n in enumerate(goodsart.GOODS_ART[g]):
            t = font(10).render(n, True, DIM)
            p.s.blit(t, (110 + i * (CW + GAP) + (CW - t.get_width()) // 2, p.y - 4))
        p.y += 12
    p.save(path)


def towns_page(path):
    p = Page("Python art 3: settlements, harbours, castles, landmark cities",
             "wfctiles.settlement_tile / castle_tile / wall_overlay, landmarks.draw_city, on a flat grass hex. Gold frame: the current normal-map piece.",
             110 + 9 * (CW + GAP) + 30, 2400)
    w = wfctiles
    p.head("Settlements (T1-T6: hamlet, village, market town, walled town, city, great city)")
    p.row("town", [cell(ov(w.settlement_tile(lv, 0)), "T%d" % lv, GRASS) for lv in range(1, 7)]
          + [None] + [now_cell(settlements, lv, "now: settlement %d" % lv, "grass") for lv in (3, 5)])
    p.row("town", [cell(ov(w.settlement_tile(lv, 1, road_edges=(0, 3, 4))), "T%d gates" % lv, GRASS) for lv in range(1, 7)]
          + [None] + [now_cell(settlements, lv, "now: settlement %d" % lv, "grass") for lv in (1, 4)],
          sub="layout 1, roads")
    p.head("Harbour towns (TH2-TH6: the town with piers at its own shore)")
    p.row("harbour", [cell(ov(w.settlement_tile(lv, 0, sea_edges=(4, 5))), "TH%d" % lv, GRASS) for lv in range(2, 7)]
          + [None] + [now_cell(harbour, lv, "now: harbour %d" % lv, "grass") for lv in (2, 3)]
          + [now_cell(harbour, 3, "now: add-on 3", "grass", addon=True)])
    p.head("Castles (K1 motte, K2 stone castle, K3 fortress) and town walls (W1 palisade, W2 stone, W3 star fort)")
    p.row("castle", [cell(ov(w.castle_tile(lv, 0)), "K%d" % lv, GRASS) for lv in (1, 2, 3)]
          + [cell(ov(w.castle_tile(lv, 1, road_edges=(4,))), "K%d layout 1" % lv, GRASS) for lv in (2, 3)]
          + [None] + [now_cell(castles, lv, "now: castle %d" % lv, "grass") for lv in (1, 2, 3)])
    p.row("walls", [cell(ov(w.wall_overlay((), lv, (0, 3))), "W%d" % lv, GRASS) for lv in (1, 2, 3)])
    p.head("Landmark cities (id <city><stage>: 1 town, 2 city, 3 great capital)")
    names = landmarks.CITY_NAMES
    for part in (names[:3], names[3:6], names[6:9], names[9:]):
        cells = []
        for n in part:
            cells += [cell(ov(landmarks.draw_city(n, st, 0)), "%s%d" % (n, st), GRASS) for st in (1, 2, 3)]
            cells.append(None)
        p.row("", cells, x0=14)
    p.save(path)


def nature_page(path):
    p = Page("Python art 4: terrain tiles, nature objects, life and sites, water and crossings",
             "nature.draw_tile, nature objects (large), life.OBJECTS, landscape pieces, wfctiles overlays. All at the radius-60 scale.",
             14 + 12 * (CW + GAP) + 10, 3200)
    p.head("Whole terrain tiles (nature.draw_tile; id N-<name>)")
    p.grid([cell(bake_art.seamless(nature.draw_tile(n, 0)), "N-" + n) for n in nature.TILE_KINDS], 12)
    p.head("Nature objects (id O-<name>): mountains, hills, trees, clutter")
    p.grid([cell(obj(nature._pub(n, "large", 0)), "O-" + n, GRASS) for n in nature._BUILD], 12)
    p.head("Life, coast and sea, ruins and holy places (life.py; id L-<name>)")
    cells = []
    for n in life.OBJECTS:
        size = life.SIZE_MAX.get(n, "l")
        cells.append(cell(obj(life.OBJECTS[n](size, 0)), "L-" + n, SEA if n in life.WATER_OBJECTS else GRASS))
    p.grid(cells, 12)
    p.head("Farm and pass pieces of the close-up landscape (landscape._piece; id P-<name>), shown at 2x")
    cells = []
    for n in landscape.PIECES:
        surf, w, h = landscape._piece(n, 0)
        cells.append(cell(obj(surf), "P-" + n, GRASS))
    p.grid(cells, 12)
    p.head("Water, relief overlays and crossings (wfctiles; id X-<name>)")
    w = wfctiles
    cells = [cell(ov(w.sea_tile("sea", 0)), "X-sea"), cell(ov(w.sea_tile("shallow", 0)), "X-shallow"),
             cell(ov(w.sea_tile("reef", 0)), "X-reef"),
             cell(ov(w.lake_overlay((1,), 0)), "X-lake", GRASS),
             cell(ov(w.river_overlay((), 0, lake=True)), "X-pond", GRASS),
             cell(ov(w.marsh_overlay((), 0)), "X-marsh", (120, 160, 96)),
             cell(ov(w.mountain_overlay((), 0)), "X-mountains", (150, 150, 140)),
             cell(ov(w.mountain_overlay((0, 3), 1)), "X-pass", (150, 150, 140)),
             cell(ov(w.coast_overlay((0, 1, 2, 3, 4, 5), 0)), "X-islet", SEA),
             cell(ov(w.river_overlay((0, 2, 4), 0)), "X-confluence", GRASS),
             cell(ov(w.river_overlay((1,), 0, mouth=True, sea_edges=(4, 5))), "X-river-mouth", GRASS)]
    for kind in ("bridge", "ford", "ferry"):
        s = pygame.Surface((120, 140), pygame.SRCALPHA)
        s.blit(w.river_overlay((1, 4), 0), (0, 0))
        s.blit(w.road_overlay((0, 3), 0, "dirt", (1, 4), kind), (0, 0))
        cells.append(cell(ov(s), "X-" + kind, GRASS))
    p.grid(cells, 12)
    p.save(path)


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    goods_page(os.path.join(out_dir, "catalogue_1_goods_new.png"), NEW,
               "Python art 1: goods with NO family in the new style yet", False)
    goods_page(os.path.join(out_dir, "catalogue_2_goods_have.png"), HAVE,
               "Python art 2: goods whose family exists in the new style", True)
    towns_page(os.path.join(out_dir, "catalogue_3_towns.png"))
    nature_page(os.path.join(out_dir, "catalogue_4_nature_life.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "design", "map", "python_art"))
