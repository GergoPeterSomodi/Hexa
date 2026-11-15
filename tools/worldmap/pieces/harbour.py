"""Fishing and harbours, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 a beach with one boat drawn up - 1 two huts, two boats, a net rack and the timber jetty - 2 a stone quay, a third
boat, a ship and two warehouses - 3 two moles round a basin, a third warehouse, a second ship, a shipyard slip with a
hull and the lighthouse on the west mole.

Boats: spring and summer they are out at sea, in autumn the first and third lie at the jetty, in winter all are laid
up (bare masts). The ships stay in the basin; the beached boat stays on the sand.

python harbour.py          writes docs/design/map/pieces/harbour.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "beach, 1 boat", 1: "huts, jetty", 2: "quay, ship", 3: "moles, light"}

LAMP = (246, 206, 84)                                 # the lighthouse lamp: yellow in every season (a new token)

SHORE_Y = 13.0
BEACHED = (-44, 6)                                    # the boat drawn up on the sand (every level)
HUTS = [(-26, -4, True), (-12, -9, False)]            # x, y, smoke (level 1)
RACK = (-42, -5, -35, -5)                             # net rack: two posts and a line (level 1)
JETTY = ((12, 12), (12, 29))                          # the landmark of level 1
QUAY = ((-26, 11.5), (30, 11.5))                      # level 2
MOLES = [((-36, 11), (-36, 28)), ((40, 11), (40, 28))]   # level 3
WAREHOUSES = [(-14, 7), (3, 7), (20, 7)]              # x, y; level 2 has the first two, level 3 the third
SLIP = (33, 8)                                        # the shipyard slip and its hull, level 3
LIGHT = (-36, 26)
# boats: home berth, out berth, from level
BOATS = [((7, 19), (-8, 37), 1), ((7, 25), (6, 41), 1), ((17, 21), (14, 36), 2)]
SHIPS = [((-16, 26), 2), ((28, 26), 3)]
TREES = [(-24, -25, "round", 0.95), (16, -26, "round", 0.9), (-18, -17, "bush", 1.0), (32, -14, "bush", 1.0)]   # always
PATCHES = [(-26, -4, 16, 8), (-12, -9, 14, 7)]        # level 0: darker ground where the huts will stand


def lighthouse(p, x, y):
    """The level 3 landmark: a white tower on the west mole with a yellow lamp room, 19 px tall."""
    winter = p.winter
    p.cast(x, y, 6)

    def fn(pen):
        body = [(x - 3.0, y), (x + 3.0, y), (x + 2.0, y - 13.5), (x - 2.0, y - 13.5)]
        pen.poly(body, kit.CHURCH, None)
        pen.poly([(x + 0.9, y), (x + 3.0, y), (x + 2.0, y - 13.5), (x + 0.7, y - 13.5)], kit.shade(kit.CHURCH, 0.84), None)
        pen.poly([(x - 2.6, y - 6.0), (x + 2.6, y - 6.0), (x + 2.35, y - 8.0), (x - 2.35, y - 8.0)], kit.ROOF, None)     # a red band
        pen.poly(body, None, kit.INK, 0.5)
        pen.rect(x - 0.6, y - 2.4, 1.2, 2.4, kit.DOOR, None)
        pen.rect(x - 3.0, y - 14.4, 6.0, 1.0, kit.STONE_GREY_D, kit.INK, 0.5)                     # the gallery
        pen.rect(x - 1.8, y - 18.0, 3.6, 3.6, LAMP, kit.INK, 0.5)                                 # the lamp room
        pen.rect(x + 0.4, y - 18.0, 1.4, 3.6, kit.shade(LAMP, 0.84), None)
        cap = [(x - 2.6, y - 18.0), (x + 2.6, y - 18.0), (x, y - 20.6)]
        pen.poly(cap, kit.SNOW if winter else kit.SLATE, kit.INK, 0.5)
    p.stand(y, fn)


def hull_on_slip(p, x, y):
    """The shipyard: a ship frame (ribs, bare) on a timber slip."""
    winter = p.winter
    p.cast(x, y, 9)

    def fn(pen):
        hull = [(x - 6.5, y - 4.4), (x + 6.5, y - 4.4), (x + 4.6, y), (x - 4.6, y)]
        pen.poly(hull, kit.HULL, None)
        pen.poly([(x - 6.5, y - 4.4), (x - 5.6, y - 4.4), (x - 3.2, y), (x - 4.6, y)], kit.shade(kit.HULL, 1.15), None)
        for i in range(-2, 3):
            pen.line((x + i * 2.5, y - 4.4), (x + i * 2.0, y - 0.5), kit.TIMBER_D, 0.5)           # ribs
        pen.poly(hull, None, kit.INK, 0.5)
        pen.line((x - 6.5, y - 4.4), (x - 7.8, y - 6.6), kit.INK, 0.5)                              # the stem post
        if winter:
            pen.line((x - 6.0, y - 4.6), (x + 6.0, y - 4.6), kit.SNOW, 0.8)
    p.stand(y, fn)


def net_rack(p, x0, y0, x1, y1):
    def fn(pen):
        for x, y in ((x0, y0), (x1, y1)):
            pen.rect(x - 0.4, y - 5, 0.8, 5, kit.TIMBER_D, None)
        pen.lines([(x0, y0 - 4.6), ((x0 + x1) / 2, y0 - 3.2), (x1, y1 - 4.6)], kit.TIMBER_D, 0.5)
        pen.lines([(x0 + 1, y0 - 4.0), ((x0 + x1) / 2, y0 - 1.9), (x1 - 1, y1 - 4.0)], kit.mix(kit.THATCH, kit.INK, 0.2), 0.5)   # the net
    p.stand(max(y0, y1), fn)


def draw(level, season):
    p = kit.Piece(season, ground="grass", seed=4)
    su, au, wi, sp = season == "summer", season == "autumn", season == "winter", season == "spring"

    # ---- ground plane
    if level == 0:
        for x, y, w, h in PATCHES:
            p.blob(x, y, w, h, kit.mix(p.pal["grass"], p.pal["wood"], 0.5))
    avoid = []
    if level >= 1:
        avoid += [(-26, -4, 8), (-12, -9, 8), (-40, -5, 6)]
    if level >= 2:
        avoid += [(x, y, 9) for x, y in WAREHOUSES[:2]]
    p.tufts(14 if level == 0 else 9 if level == 1 else 6 if level == 2 else 5, area=(-46, -44, 46, 6), avoid=avoid)
    p.blob(0, 8, 86, 10, p.pal["sand"])                 # the beach: sand widened along the shore, every level
    p.coast(SHORE_Y, amp=1.2, sand=5.0, seed=5)
    if level >= 3:                                       # the slip down to the water
        p.patch([(SLIP[0] - 2.5, SLIP[1] - 6), (SLIP[0] + 2.5, SLIP[1] - 6), (SLIP[0] + 2.5, 12.5), (SLIP[0] - 2.5, 12.5)],
                kit.mix(kit.TIMBER, p.pal["grass"], 0.35), kit.TIMBER_D, 0.5)
    if level >= 1:
        p.jetty(JETTY[0], JETTY[1], 1.8)
        p.jetty((JETTY[1][0] - 3.2, JETTY[1][1]), (JETTY[1][0] + 3.2, JETTY[1][1]), 1.8)       # the T head
    if level >= 2:
        p.jetty(QUAY[0], QUAY[1], 3.2, stone=True)
        if wi:
            p.gp.line((QUAY[0][0], QUAY[0][1] - 0.4), (QUAY[1][0], QUAY[1][1] - 0.4), kit.SNOW, 1.4)
    if level >= 3:
        for a, b in MOLES:
            p.jetty(a, b, 4.2, stone=True)
            head = (b[0] + (6 if a[0] < 0 else -6), b[1])                  # the head curls into the basin
            p.jetty(b, head, 3.2, stone=True)
            if wi:
                p.gp.line((a[0], a[1]), (b[0], b[1] - 0.5), kit.SNOW, 1.6)
                p.gp.line((b[0], b[1] - 0.4), (head[0], head[1] - 0.4), kit.SNOW, 1.2)

    # ---- standing things
    for i, (x, y, kind, sc) in enumerate(TREES):
        p.tree(x, y, sc, kind, i)
    p.boat(BEACHED[0], BEACHED[1], 0.55, sail=False)
    if level >= 1:
        for x, y, sm in HUTS:
            p.house(x, y, 5.5, 3.5, 3.0, roof="thatch", smoke=sm)
        net_rack(p, *RACK)
    if level >= 2:
        for i, (x, y) in enumerate(WAREHOUSES[:2]):
            p.house(x, y, 11.5, 5.2, 4.4, wall=(1, 3)[i], kind="ridge", roof="tile", door=False)
        for (x, y), frm in SHIPS:
            if level >= frm:
                p.boat(x, y, 1.0, sail=not wi)
    if level >= 3:
        p.house(WAREHOUSES[2][0], WAREHOUSES[2][1], 11.5, 5.2, 4.4, wall=4, kind="ridge", roof="tile", door=False)
        hull_on_slip(p, SLIP[0], SLIP[1])
        lighthouse(p, LIGHT[0], LIGHT[1])
    for i, (home, out, frm) in enumerate(BOATS):
        if level < frm:
            continue
        at_sea = sp or su or (au and i % 2 == 1)
        p.boat(*(out if at_sea else home), 0.55, sail=not wi)
    # ---- season activity
    if (sp or su) and level >= 1:
        p.person(-39, -2.5)                              # a fisherman at the net rack
    if (sp or su or au) and level >= 2:
        p.person(-2, 10.5, (70, 96, 150))                # a man on the quay
    return p.finish(label="harbour L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "harbour.png")
    kit.sheet(draw, LEVELS, "Fishing and harbours: levels 0-3 by season", out, NAMES, ground="grass")
    print("wrote", os.path.normpath(out))
