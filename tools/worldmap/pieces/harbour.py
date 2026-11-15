"""Fishing and harbours, levels 1-3, at the map's shore (see docs/design/map/pieces/GUIDE.md, sections 8 and 10).

1 two huts, two boats, a net rack, a small boat drawn up and the timber jetty - 2 a stone quay, a third boat, a ship and
two warehouses - 3 two bent moles closing a basin, a third warehouse, a second ship, a shipyard slip with a hull and
the lighthouse on the west mole's bend.   Level 0 is no piece: the sheets show kit.wild().

Everything is laid out in SHORE COORDINATES: u px along the shore from the middle, v px out to sea (v < 0 is inland);
shore.pt(u, v) turns that into piece px for whichever side the sea is on. The piece draws no sea of its own.

draw(..., addon=True) draws only the works at the water's edge (jetty, quay, moles, lighthouse, the hull on its slip,
the ships and boats): the harbour of a port town, to be laid over the town piece (GUIDE section 8).

Boats: spring and summer they are out at sea, in autumn the first and third lie at the jetty, in winter all are laid
up (bare masts). The ships stay in the basin; the beached boat stays on the sand.

python harbour.py          writes docs/design/map/pieces/harbour.png, harbour_variants.png, harbour_sides.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "huts, jetty", 2: "quay, ship", 3: "moles, light"}
VARIANTS = 1
SEED = 4
COAST = dict(y0=13.0, amp=1.2, sand=5.0, seed=5)      # the keywords of p.coast(); level 0 uses the same
NEED = {1: 28, 2: 28, 3: 28}                          # the land depth behind the shore each level uses (px)

LAMP = (246, 206, 84)                                 # the lighthouse lamp: yellow in every season (a new token)

# u: px along the shore from its middle; v: px out to sea (v < 0: inland)
BEACHED = (-36, -7)                                   # the small boat drawn up on the sand (level 1)
HUTS = [(-28, -17, True), (-14, -23, False)]          # u, v, smoke (level 1)
RACK = (-39, -15, -33, -15)                           # net rack: two posts and a line (level 1): u0, v0, u1, v1
JETTY = (8, -1, 13)                                  # the landmark of level 1: u, from v, to v; T head across its end
QUAY = (-30, 12, -1.5)                                # level 2: from u to u at v
MOLES = [[(-30, -1), (-30, 14), (-18, 18)], [(34, -1), (34, 14), (22, 18)]]   # level 3: two bent moles, a 40 px mouth
WAREHOUSES = [(-22, -6), (-8, -6), (6, -6)]           # u, v; level 2 has the first two, level 3 the third
SLIP = (21, -5)                                       # the shipyard slip and its hull, level 3
LIGHT = MOLES[0][1]                                   # the lighthouse stands on the first mole's bend
# boats: home berth, out berth, from level
BOATS = [((-1.5, 6), (-12, 21.5), 1), ((-3.5, 14), (4, 22.5), 1), ((-22.5, 7), (12, 20.5), 2)]
SHIPS = [((-14, 11), 2), ((20, 11), 3)]
BOAT_SC = 0.7                                         # fishing boats (ships are 1.0)
HUT_YARDS = [(-28, -15.5, 16, 8), (-14, -21.5, 14, 7)]    # trodden ground round the huts (an overlay)


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
    return p.stand(y, fn)


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
    return p.stand(y, fn)


def net_rack(p, x0, y0, x1, y1):
    def fn(pen):
        for x, y in ((x0, y0), (x1, y1)):
            pen.rect(x - 0.4, y - 5, 0.8, 5, kit.TIMBER_D, None)
        pen.lines([(x0, y0 - 4.6), ((x0 + x1) / 2, y0 - 3.2), (x1, y1 - 4.6)], kit.TIMBER_D, 0.5)
        pen.lines([(x0 + 1, y0 - 4.0), ((x0 + x1) / 2, y0 - 1.9), (x1 - 1, y1 - 4.0)], kit.mix(kit.THATCH, kit.INK, 0.2), 0.5)   # the net
    return p.stand(max(y0, y1), fn)


LIGHT_TOP = -8.0                                      # the lighthouse is 20 px tall: its foot must not stand higher than this


class Along:
    """The shore with u turned round when g = -1 (the whole layout then runs the other way along the shore)."""

    def __init__(self, shore, g):
        self.shore, self.g = shore, g

    def pt(self, u, v=0.0):
        return self.shore.pt(u * self.g, v)


def line_at(s, u0, u1, v, step=12):
    """Points along the shore from u0 to u1 at v out from it, so a quay follows the shore's waves."""
    n = max(1, int(abs(u1 - u0) // step))
    return [s.pt(u0 + (u1 - u0) * i / n, v) for i in range(n + 1)]


def draw(level, season, variant=0, mirror=False, sea=None, shore=None, addon=False):
    if level == 0:                                    # no piece on the map: the sheets show the wild shore
        return kit.wild(season, "grass", seed=SEED, coast=COAST, sea=sea, shore=shore, mirror=mirror)
    p = kit.Piece(season, ground="grass", seed=SEED, sea=sea, shore=shore, mirror=mirror)
    shore = p.coast(**COAST)
    g = -1 if shore.pt(*LIGHT)[1] < LIGHT_TOP else 1  # the lighthouse stands on the lower end of the hex: the layout runs the other way along the shore
    s = Along(shore, g)
    su, au, wi, sp = season == "summer", season == "autumn", season == "winter", season == "spring"
    land = not addon                                  # the add-on keeps to the water's edge: no huts, warehouses, rack, people

    # ---- ground plane
    if land and level >= 1:                           # trodden ground round the huts (overlays)
        for u, v, w, h in HUT_YARDS:
            p.blob(*s.pt(u, v), w, h, p.pal["soil"], alpha=0.35)
    if level >= 3:                                    # the slip down to the water
        u, v = SLIP
        p.patch([s.pt(u - 2.5, v - 6), s.pt(u + 2.5, v - 6), s.pt(u + 2.5, 0.5), s.pt(u - 2.5, 0.5)],
                kit.mix(kit.TIMBER, p.pal["grass"], 0.35), kit.TIMBER_D, 0.5)
    if level >= 1:
        u, v0, v1 = JETTY
        p.jetty(s.pt(u, v0), s.pt(u, v1), 1.8, snow=True)
        p.jetty(s.pt(u - 3.2, v1), s.pt(u + 3.2, v1), 1.8, snow=True)                        # the T head
    if level >= 2:
        p.jetty(line_at(s, QUAY[0], QUAY[1], QUAY[2]), None, 3.2, stone=True, snow=True)
    if level >= 3:
        for pts in MOLES:                                                                    # two bent moles close a basin
            p.jetty([s.pt(*q) for q in pts], None, 3.6, stone=True, snow=True)

    # ---- standing things
    if land and level >= 1:
        for u, v, sm in HUTS:
            p.house(*s.pt(u, v), 5.5, 3.5, 3.0, roof="thatch", smoke=sm)
        net_rack(p, *s.pt(RACK[0], RACK[1]), *s.pt(RACK[2], RACK[3]))
    if level >= 1:
        p.boat(*s.pt(*BEACHED), 0.55, sail=False)
    if land and level >= 2:
        for i, (u, v) in enumerate(WAREHOUSES[:2]):
            p.house(*s.pt(u, v), 11.5, 5.2, 4.4, wall=(1, 3)[i], kind="ridge", roof="tile", door=False)
    if level >= 2:
        for (u, v), frm in SHIPS:
            if level >= frm:
                p.boat(*s.pt(u, v), 1.0, sail=not wi)
    if level >= 3:
        if land:
            u, v = WAREHOUSES[2]
            p.house(*s.pt(u, v), 11.5, 5.2, 4.4, wall=4, kind="ridge", roof="tile", door=False)
        hull_on_slip(p, *s.pt(*SLIP))
        lighthouse(p, *s.pt(*LIGHT))
    for i, (home, out, frm) in enumerate(BOATS):
        if level < frm:
            continue
        at_sea = sp or su or (au and i % 2 == 1)
        p.boat(*s.pt(*(out if at_sea else home)), BOAT_SC, sail=not wi)
    # ---- season activity
    if land and (sp or su) and level >= 1:
        p.person(*s.pt(-35, -12.5))                      # a fisherman at the net rack
    if land and (sp or su or au) and level >= 2:
        p.person(*s.pt(-1, -2.5), (70, 96, 150))         # a man on the quay
    return p.finish(label="harbour L%d%s" % (level, " addon" if addon else ""))


def sides_sheet(path, season="summer"):
    """The coast check: levels 1-3, in summer and winter, sea on S, E and NW and the same mirrored; below it the
    add-on (summer) on S, E and NW."""
    pg = kit.pygame
    cases = [(side, m) for m in (False, True) for side in ("S", "E", "NW")]
    cw = kit.SIZE + 8
    W, H = 90 + len(cases) * cw, 40 + 9 * cw + 30
    out = pg.Surface((W, H))
    out.fill(kit.SHEET_BG)
    f = kit._font(17)
    for j, (side, m) in enumerate(cases):
        out.blit(f.render("sea %s%s" % (side, " mirrored" if m else ""), True, kit.SHEET_TEXT), (90 + j * cw + 4, 8))
    rows = [(se, lv, False) for se in ("summer", "winter") for lv in (1, 2, 3)] + [("summer", lv, True) for lv in (1, 2, 3)]
    for r, (se, lv, ad) in enumerate(rows):
        out.blit(f.render("%s L%d%s" % (se, lv, " add-on" if ad else ""), True, kit.SHEET_TEXT), (6, 40 + r * cw + 50))
        for j, (side, m) in enumerate(cases):
            img = kit.with_wild(draw, lv, se, mirror=m, sea=side, addon=ad)
            out.blit(kit._cell(img, se, 1.0, 4, "grass"), (90 + j * cw, 34 + r * cw))
    pg.image.save(out, path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(folder, "harbour.png")
    base = os.path.splitext(out)[0]
    kit.sheet(draw, LEVELS, "Fishing and harbours: levels 0-3 by season", out, NAMES, ground="grass", wild=True)
    print("wrote", os.path.normpath(out))
    kit.variant_sheet(draw, LEVELS, "Fishing and harbours: layouts and mirror", base + "_variants.png", NAMES, ground="grass")
    sides_sheet(base + "_sides.png")
    print("wrote", os.path.normpath(base + "_variants.png"), os.path.normpath(base + "_sides.png"))
