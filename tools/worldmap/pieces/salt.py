"""Salt pans, levels 1-3, at the map's shore (see docs/design/map/pieces/GUIDE.md, sections 8 and 10).

1 four pans in a row along the shore, a heap, a hut and a trodden path - 2 eight pans in two rows, a feeder channel
from the pans to the shore, a sluice, three heaps - 3 fourteen pans in three rows, five heaps, a short jetty with a
boat and the salt store.   Level 0 is no piece: the sheets show kit.wild().

Everything is laid out in SHORE COORDINATES: u px along the shore from the middle, v px out to sea (v < 0 is
inland); shore.pt(u, v) turns that into piece px for whichever side the sea is on. The piece draws no sea of its own.

Two layouts (VARIANTS = 2). Layout 0: one block of pans in three rows, the hut and the sluice at the west, the heaps in
front, the jetty at the east. Layout 1: two blocks of pans either side of a straight feeder channel (3 and 4 pans wide, two
rows), the heaps in a row along the inland side, the store and the jetty at the west, the hut at the east.
On a lagoon (bay=) the pans lie at the lagoon's shore as at any other; the jetty and the boat keep inside it.
Winter: pans frozen only where the water freezes (p.frozen); in a mild winter they are filled as in spring.

python salt.py             writes docs/design/map/pieces/salt.png, salt_variants.png and salt_sides.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "4 pans, hut, path", 2: "8 pans, sluice", 3: "14 pans, store"}
VARIANTS = 2
SEED = 2
COAST = dict(y0=15.0, amp=2.0, sand=4.0, seed=3)      # the keywords of p.coast(); level 0 uses the same
# the land depth behind the shore each level uses (px): a hex with less land takes a lower level
NEED = {1: 26, 2: 34, 3: 46}

PAN_W, PAN_H = 10.4, 7.3                              # the pan, inside its dyke (dykes of neighbours share a rim)
PITCH = 11.2                                          # u between neighbouring pan columns

# ---- layout 0: one block of 5 x 3 pans in the middle
COLS = (-22.4, -11.2, 0.0, 11.2, 22.4)                # u of the five pan columns
ROWS = (-18.0, -26.6, -35.2)                          # v of the three pan rows: A (by the shore), B, C
HUT = (COLS[0], ROWS[0] - 1.0)                        # u, v: the hut stands at the left end of row A
PANS = [                                              # u, v, from level
    (COLS[1], ROWS[0], 1), (COLS[2], ROWS[0], 1), (COLS[3], ROWS[0], 1), (COLS[4], ROWS[0], 1),
    (COLS[1], ROWS[1], 2), (COLS[2], ROWS[1], 2), (COLS[3], ROWS[1], 2), (COLS[4], ROWS[1], 2),
    (COLS[0], ROWS[1], 3),
    (COLS[0], ROWS[2], 3), (COLS[1], ROWS[2], 3), (COLS[2], ROWS[2], 3), (COLS[3], ROWS[2], 3), (COLS[4], ROWS[2], 3),
]
HEAPS = [(3, 1), (-9, 2), (15, 2), (-21, 3), (27, 3)]  # u, from level; all stand at v = HEAP_V
HEAP_V = -8.0
PATH = [(-21.0, -14.0), (-14.0, -13.0), (-4.0, -12.5), (6.0, -12.5), (16.0, -12.5)]   # trodden: hut to the pans, along their front
CHANNEL = [(-33.0, 0.0), (-33.0, -9.0), (-32.0, -20.0), (-33.0, -31.0)]   # u, v: from the pans down to the shore
SLUICE = (-33.0, -17.0)
STORE = (0.0, -43.0)
JETTY_U = 18.0                                        # the jetty runs straight out from pt(u, -1) to pt(u, 14)
BOAT = (10.0, 9.0)                                    # moored beside the jetty
DRIFT = (-26.0, -4.0, 8, 3)                           # winter only: one low drift on the beach
RAKERS = [(9.0, -13.0), (21.0, -13.0, (70, 96, 150))]   # summer: one from level 1, the second from level 2

# ---- layout 1: two blocks of pans either side of the feeder channel, which runs inland from the shore
# The channel lies at CH_U, a little west of the middle: 7 pans and the channel are 84 px wide, the whole margin hex,
# so the east block (4 wide) is brought in by this much to keep its dykes inside the 10 px margin.
CH_U = -5.0
G1 = 7.6                                              # the first pan column's distance from the channel (a 3.2 px water gap)
WCOLS = tuple(CH_U - G1 - PITCH * k for k in range(3))     # the west block, 3 pans wide
ECOLS = tuple(CH_U + G1 + PITCH * k for k in range(4))     # the east block, 4 pans wide
ROWS1 = (-18.0, -26.6)
PANS1 = [                                             # u, v, from level
    (WCOLS[0], ROWS1[0], 1), (WCOLS[1], ROWS1[0], 2), (WCOLS[2], ROWS1[0], 2),
    (ECOLS[0], ROWS1[0], 1), (ECOLS[1], ROWS1[0], 1), (ECOLS[2], ROWS1[0], 2), (ECOLS[3], ROWS1[0], 2),
    (ECOLS[0], ROWS1[1], 2),
    (WCOLS[0], ROWS1[1], 3), (WCOLS[1], ROWS1[1], 3), (WCOLS[2], ROWS1[1], 3),
    (ECOLS[1], ROWS1[1], 3), (ECOLS[2], ROWS1[1], 3), (ECOLS[3], ROWS1[1], 3),
]
LAYOUT = [
    dict(pans=PANS, heaps=HEAPS, heap_v=HEAP_V, hut=HUT, paths=[PATH], channel=CHANNEL, sluice=SLUICE, store=STORE,
         jetty_u=JETTY_U, boat=BOAT, drift=DRIFT, rakers=RAKERS),
    dict(pans=PANS1, heaps=[(-26, 1), (6, 2), (30, 2), (-14, 3), (18, 3)], heap_v=-34.0, hut=(24.0, -8.0),
         paths=[[(21.0, -11.0), (16.0, -12.5), (12.0, -12.5), (1.0, -12.5)], [(-11.0, -12.5), (-22.0, -12.5), (-36.0, -12.5)]],
         channel=[(CH_U, 0.0), (CH_U, -10.0), (CH_U, -22.0), (CH_U, -31.0)], sluice=(CH_U, -17.0), store=(-27.0, -5.0),
         jetty_u=-22.0, boat=(-14.0, 9.0), drift=(22.0, -4.0, 8, 3),
         rakers=[(-17.0, -12.5), (17.0, -12.5, (70, 96, 150))],
         yard=(-2.0, -35.0, 78, 9)),     # trodden ground behind the pans where the heaps stand (level 3)
]


def pan_col(p, i):
    pal = p.pal
    if p.season == "spring":
        return kit.mix(pal["shallow"], pal["sand"], 0.45)
    if p.season == "summer":
        return kit.mix(kit.SALT, kit.PLASTER[2], 0.55) if i % 3 == 1 else kit.SALT
    if p.season == "autumn":
        return kit.mix(kit.STONE_GREY, pal["sand"], 0.3)
    return kit.ICE if p.frozen else kit.mix(pal["shallow"], pal["sand"], 0.45)     # a mild winter: filled, as in spring


def at(s, u, v, du=0.0, dv=0.0):
    """The piece-px point du along and dv across the shore from the shore point (u, v): the kit's shore.at."""
    return s.at(u, v, du, dv)


def quad(s, u, v, w2, h2):
    """A rectangle lying on the shore: centre (u, v), half sizes w2 along and h2 across: the kit's shore.rect."""
    return s.rect(u, v, w2 * 2, h2 * 2)


def pan(p, s, u, v, i):
    w2, h2 = PAN_W / 2, PAN_H / 2
    dyke = kit.SNOW if p.winter else kit.mix(p.pal["sand"], kit.STONE_D, 0.55)
    p.patch(quad(s, u, v, w2 + 0.8, h2 + 0.65), dyke)
    edge = kit.ICE_D if p.frozen else kit.STONE_D
    p.patch(quad(s, u, v, w2, h2), pan_col(p, i), edge, 0.5)
    inner = kit.mix(pan_col(p, i), kit.SNOW if p.winter else (kit.SALT if p.season != "autumn" else kit.STONE_GREY_D), 0.35)
    a, b = at(s, u, v, -w2 + 1.6, -0.6), at(s, u, v, w2 - 2.2, -0.6)
    p.over(lambda pen: pen.line(a, b, inner, 0.5), 0.85)                       # a glint, a crust or a crack
    if p.season == "summer" and i % 3 != 1:
        a, b = at(s, u, v, -w2 + 2.4, 1.6), at(s, u, v, w2 - 3.0, 1.6)
        p.over(lambda pen: pen.line(a, b, kit.shade(kit.SALT, 0.93), 0.5), 0.85)


def sluice(p, x, y):
    """The level 2 landmark: a small timber frame with a gate board across the channel."""
    winter = p.winter
    p.cast(x, y, 5)

    def fn(pen):
        pen.rect(x - 2.6, y - 2.6, 5.2, 2.6, kit.TIMBER_D, None)                      # gate boards
        pen.rect(x - 2.7, y - 5.6, 0.9, 5.6, kit.TIMBER, None)                         # posts
        pen.rect(x + 1.8, y - 5.6, 0.9, 5.6, kit.TIMBER_D, None)
        pen.rect(x - 3.2, y - 6.8, 6.4, 1.3, kit.SNOW if winter else kit.TIMBER, None)  # the beam
        pen.rect(x - 3.2, y - 6.8, 6.4, 1.3, None, kit.INK, 0.5)
        pen.line((x - 2.7, y - 5.6), (x - 2.7, y), kit.INK, 0.5)
        pen.line((x + 2.7, y - 5.6), (x + 2.7, y), kit.INK, 0.5)
        pen.rect(x - 2.6, y - 2.6, 5.2, 2.6, None, kit.INK, 0.5)
    return p.stand(y, fn)


def draw(level, season, variant=0, mirror=False, sea=None, shore=None, bay=None):
    if level == 0:                                    # no piece on the map: the sheets show the wild shore
        return kit.wild(season, "sand", seed=SEED, coast=COAST, sea=sea, shore=shore, bay=bay, mirror=mirror)
    L = LAYOUT[variant]
    p = kit.Piece(season, ground="sand", seed=SEED, sea=sea, shore=shore, bay=bay, mirror=mirror)
    s = p.coast(**COAST)
    b = s.bay                                         # a lagoon: only the jetty and the boat look at it
    su, au, wi = season == "summer", season == "autumn", season == "winter"
    ju = L["jetty_u"]
    jend = 14.0 if b is None else min(14.0, b.room(ju) - 2.0)
    boat = None
    if level >= 3:
        bu, bv = L["boat"]
        if b is not None:
            bv = min(bv, b.room(bu) - 3.0)
        if bv >= 3.0:
            boat = (bu, bv)

    # ---- ground plane (the same order every time)
    soil = p.pal["soil"]
    if level >= 1:                                    # the trodden path from the hut to the pans, and ground round the hut
        hu, hv = L["hut"]
        p.blob(*s.pt(hu, hv + 1.5), 15, 7, soil, alpha=0.35)
        lines = [[s.pt(*q) for q in path] for path in L["paths"]]
        p.over(lambda pen: [pen.lines(line, soil, 2.6) for line in lines], 0.5)
    if level >= 2:                                    # the feeder channel: quiet, quieter than the sea
        col = kit.ICE if p.frozen else kit.mix(p.pal["river"], p.pal["shallow"], 0.5)
        edge = kit.ICE_D if p.frozen else p.pal["river_edge"]
        line = [s.pt(*q) for q in L["channel"]]
        p.over(lambda pen: (pen.lines(line, edge, 3.2), pen.lines(line, col, 2.2)), 0.8)
    if level >= 3 and "yard" in L:
        quadr = s.rect(*L["yard"])                    # turns with the shore, unlike a blob
        p.over(lambda pen: pen.poly(quadr, soil, None), 0.35)
    for i, (u, v, frm) in enumerate(L["pans"]):
        if level >= frm:
            pan(p, s, u, v, i)
    if level >= 3 and jend >= 4.0:
        p.jetty(s.pt(ju, -1), s.pt(ju, jend), 2.2, snow=True)
    if p.winter:
        p.snow_patch(*s.pt(L["drift"][0], L["drift"][1]), L["drift"][2], L["drift"][3])

    # ---- standing things
    if level >= 1:
        p.house(*s.pt(*L["hut"]), 5.5, 3.5, 3.0, roof="thatch", smoke=True)
    if level >= 2:
        sluice(p, *s.pt(*L["sluice"]))
    covered = au or wi
    for hu, frm in L["heaps"]:
        if level >= frm:
            x, y = s.pt(hu, L["heap_v"])
            if covered:
                p.heap(x, y, 8, 5.5, kit.THATCH, kit.THATCH_D)
            else:
                p.heap(x, y, 8, 5.5, kit.SALT, kit.shade(kit.SALT, 0.86))
    if level >= 3:
        p.house(*s.pt(*L["store"]), 16, 5.4, 4.6, wall=3, kind="ridge", roof="tile", door=False)
        if boat is not None:
            p.boat(*s.pt(*boat), 0.7, sail=not wi)
    # ---- season activity: two rakers in summer
    if su:
        for k, r in enumerate(L["rakers"]):
            if level >= k + 1:
                p.person(*s.pt(r[0], r[1]), *r[2:])
    return p.finish(label="salt L%d" % level)


def sides_sheet(path, season="summer"):
    """The coast check: levels 1-3, in summer and winter, with the sea on S, E and NW and the same mirrored; below it
    layout 1 (levels 2 and 3, summer, level 3 in winter) and both layouts on a lagoon (bay depth 10, summer)."""
    pg = kit.pygame
    cases = [(side, m) for m in (False, True) for side in ("S", "E", "NW")]
    cw = kit.SIZE + 8
    lagoon = (0, kit.BAY_WIDTH, 10)
    rows = [(se, lv, 0, None) for se in ("summer", "winter") for lv in (1, 2, 3)]
    rows += [("summer", 2, 1, None), ("summer", 3, 1, None), ("winter", 3, 1, None),
             ("summer", 3, 0, lagoon), ("summer", 3, 1, lagoon), ("winter", 3, 1, lagoon)]
    LAB = 150                                         # the width of the label column
    W, H = LAB + len(cases) * cw, 40 + len(rows) * cw + 30
    out = pg.Surface((W, H))
    out.fill(kit.SHEET_BG)
    f = kit._font(17)
    for j, (side, m) in enumerate(cases):
        out.blit(f.render("sea %s%s" % (side, " mirrored" if m else ""), True, kit.SHEET_TEXT), (LAB + j * cw + 4, 8))
    for r, (se, lv, var, bay) in enumerate(rows):
        label = "%s L%d%s%s" % (se, lv, " lay.1" if var else "", " lagoon" if bay else "")
        out.blit(f.render(label, True, kit.SHEET_TEXT), (6, 40 + r * cw + 50))
        for j, (side, m) in enumerate(cases):
            img = kit.with_wild(draw, lv, se, variant=var, mirror=m, sea=side, bay=bay)
            out.blit(kit._cell(img, se, 1.0, 4, "sand"), (LAB + j * cw, 34 + r * cw))
    pg.image.save(out, path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces")
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(folder, "salt.png")
    base = os.path.splitext(out)[0]
    kit.sheet(draw, LEVELS, "Salt pans: levels 0-3 by season", out, NAMES, ground="sand", wild=True)
    print("wrote", os.path.normpath(out))
    kit.variant_sheet(draw, LEVELS, "Salt pans: layouts and mirror", base + "_variants.png", NAMES, ground="sand")
    sides_sheet(base + "_sides.png")
    print("wrote", os.path.normpath(base + "_variants.png"), os.path.normpath(base + "_sides.png"))
