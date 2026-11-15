"""Fishing and harbours, levels 1-3, at the map's shore (see docs/design/map/pieces/GUIDE.md, sections 8 and 10).

1 two huts, two boats, a net rack, a small boat drawn up and the timber jetty - 2 a stone quay, a third boat, a ship and
two warehouses - 3 two bent moles closing a basin, a third warehouse, a second ship, a shipyard slip with a hull and
the lighthouse on the west mole's bend.   Level 0 is no piece: the sheets show kit.wild().

Everything is laid out in SHORE COORDINATES: u px along the shore from its middle, v px out to sea (v < 0 is inland);
shore.pt(u, v) turns that into piece px for whichever side the sea is on. The piece draws no sea of its own.

Two port modes (guide section 10):
  SEASIDE, the open shore (shore.bay is None): two layouts (VARIANTS = 2), LAYOUT[0] and LAYOUT[1].
    Layout 0: huts at the west, the jetty right of the middle, the quay west of the jetty, two bent moles of equal size
    with the lighthouse on the west mole's bend, the slip at the east.
    Layout 1: one long mole from the west end that sweeps round the basin, and a short spur from the east shore; the
    lighthouse on the long mole's head; the quay east of the jetty; the huts in the middle, the net rack at the east.
  CARVED, in the map's bay (shore.bay is a kit.Bay): ONE layout, CARVED, written in u relative to the bay's middle
    (bay.u0): the jetty and the quay on the back of the bay, two short moles from the horns across its mouth, the
    lighthouse on a horn, the ships and boats inside. `variant` is ignored in a bay (the mirror still applies).
    Nothing is laid out by the bay's depth except through bay.room(u): a berth that does not fit is left out.
BAY says what the harbour asks of the map's bay, REACH how far out from an open shore each level reaches.

draw(..., addon=True) draws only the works at the water's edge (jetty, quay, moles, lighthouse, the hull on its slip,
the ships and boats): the harbour of a port town, to be laid over the town piece (GUIDE section 8).

Boats: spring and summer they are out at sea, in autumn the first and third lie at the jetty, in winter all are laid
up (bare masts). The ships stay in the basin; the beached boat stays on the sand. In every winter the boats are laid
up; snow (moles, roofs, the lighthouse cap, the hull) lies only where snow lies (p.winter): a mild winter is white nowhere.

python harbour.py          writes docs/design/map/pieces/harbour.png, harbour_variants.png, harbour_sides.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "wild land (the map's)", 1: "huts, jetty", 2: "quay, ship", 3: "moles, light"}
VARIANTS = 2
SEED = 4
COAST = dict(y0=13.0, amp=1.2, sand=5.0, seed=5)      # the keywords of p.coast(); level 0 uses the same
NEED = {1: 28, 2: 28, 3: 28}                          # the land depth behind the shore each level uses (px)
BAY = dict(width=kit.BAY_WIDTH, back=COAST["y0"])     # what the harbour asks of the map's bay: its width, and its back
                                                      # at COAST["y0"] px from the hex centre (where it expects its shore)
# px out from an open shore that each level's works AND berths reach (measured over both layouts, every season, the
# outermost foot or ground detail on a south shore: the boats' "out at sea" berths of spring and summer are the
# farthest, at 22.5 (layout 0) and 24 (layout 1). The works alone reach 14 px at levels 1 and 2 (the jetty's T head)
# and 21 / 24 px at level 3 (layout 0 / 1: the moles).
REACH = {1: 24, 2: 24, 3: 24}

LAMP = (246, 206, 84)                                 # the lighthouse lamp: yellow in every season (a new token)
LIGHT_SIZE = (21.5, 7.0)                              # tall, wide (px), with its cap
SHIP_SIZE = (13.5, 12.5)                              # a ship at size 1.0; a boat is BOAT_SC of it
BOAT_SC = 0.7                                         # fishing boats (ships are 1.0)

# ---- the open shore: one dict per layout. u: px along the shore from its middle; v: px out to sea (v < 0: inland)
#   beached     the small boat drawn up on the sand (level 1)      huts   u, v, smoke (level 1)
#   rack        net rack: two posts and a line (level 1): u0, v0, u1, v1
#   jetty       the landmark of level 1: u, from v, to v; T head across its end
#   quay        level 2: from u to u at v                          moles  level 3: bent moles, a list of points each
#   warehouses  u, v; level 2 has the first two, level 3 the third  slip  the shipyard slip and its hull, level 3
#   lights      the lighthouse spots: the first that fits (a tall thing leaves the hex at the top where the sea is behind the land)
#   boats       home berth, out berth, from level                  ships  berth, from level
#   yards       trodden ground round the huts (an overlay)         fisher, quayman: the two people (spring, summer, autumn)
LAYOUT = [
    dict(beached=(-36, -7), huts=[(-28, -17, True), (-14, -23, False)], rack=(-39, -15, -33, -15),
         jetty=(8, -1, 13), quay=(-30, 12, -1.5),
         moles=[[(-30, -1), (-30, 14), (-18, 18)], [(34, -1), (34, 14), (22, 18)]],       # a 40 px mouth
         warehouses=[(-22, -6), (-8, -6), (6, -6)], slip=(21, -5),
         # The first mole's bend; where the hex is too short above that spot (the sea behind the land, or the mole at
         # the upper end of an east or west shore) the next spot that has room: the other mole's bend, then the moles'
         # roots, then the land by the second mole (the last: on the head of land, sea in the north).
         lights=[(-30, 14), (34, 14), (-30, -1), (34, -1), (34, -7)],
         boats=[((-1.5, 6), (-12, 21.5), 1), ((-3.5, 14), (4, 22.5), 1), ((-22.5, 7), (12, 20.5), 2)],
         ships=[((-14, 11), 2), ((20, 11), 3)],
         yards=[(-28, -15.5, 16, 8), (-14, -21.5, 14, 7)], fisher=(-35, -12.5), quayman=(-1, -2.5)),
    # Layout 1: one long mole from the west end (out 15 px, then two bends to end at (8, 21)) and a short spur from the
    # east shore: the mouth is at the east, 24 px wide. The lighthouse stands on the long mole's head.
    dict(beached=(36, -8), huts=[(-3, -23, True), (7, -19, False)], rack=(33, -16, 39, -16),
         jetty=(-14, -1, 13), quay=(-4, 28, -1.5),
         moles=[[(-32, -1), (-32, 15), (-24, 21), (8, 21)], [(32, -1), (32, 9)]],
         warehouses=[(0, -6), (14, -6), (28, -6)], slip=(-24, -5),
         lights=[(8, 21), (-24, 21), (-32, 15), (-32, -1), (32, 9), (32, -1), (32, -7)],
         boats=[((-24, 7), (-14, 26), 1), ((-6, 17), (18, 24), 1), ((-1, 6), (-30, 26), 2)],
         ships=[((16, 9), 2), ((2, 12), 3)],
         yards=[(-3, -21.5, 16, 8), (7, -17.5, 14, 7)], fisher=(36, -12.5), quayman=(14, -2.5)),
]

# ---- the carved port: ONE layout, in u relative to the bay's middle (bay.u0). v: px out from the bay's own shore,
# unless said so. Berths are cut to the water the bay has (bay.room); the moles are laid along the mouth line.
CARVED = dict(
    beached=(-27, -6), huts=[(-17, -18, True), (-3, -23, False)], rack=(21, -16, 27, -16),
    jetty=(6, -1, 13),                                # from the back of the bay, out to at most room - 3
    quay=(-24, 24, -1.5), quay3=(-24, 14),            # level 2; level 3 stops short of the slip
    warehouses=[(-22, -6), (-8, -6), (6, -6)], slip=(22, -5),
    mole=[(1, 0), (16, 1.5), (21, -2.5)],             # from the west horn along the mouth line (px from the horn, v from the mouth line); the east one the same from its horn
    light=[(3, 0), (16, 1.5), (1, 0)],                # the lighthouse spots from the west horn, then the same from the east horn
    boats=[((-2, 6), (-10, 4), 1), ((14, 12), (1, 4), 1), ((-24, 7), (11, 4), 2)],  # home (v from the shore), out (v beyond the mouth line)
    ships=[((-14, 9), 2), ((24, 9), 3)],
    yards=[(-17, -16.5, 16, 8), (-3, -21.5, 14, 7)], fisher=(18, -12.5), quayman=(-2, -2.5),
)


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


def afloat(p, s, u, v, sc, sail):
    """A ship or boat at (u, v) out on the water. Sails stand upright on every sea side, so where the hex is too
    short above the berth the boat lies closer in (shore.fit), and where it fits nowhere it is left out."""
    at = s.fit(u, v, SHIP_SIZE[0] * sc, SHIP_SIZE[1] * sc, v_min=min(v, 4.0))
    if at is not None:
        p.boat(*at, sc, sail=sail)


def line_at(s, u0, u1, v, step=12):
    """Points along the shore from u0 to u1 at v out from it, so a quay follows the shore's waves."""
    n = max(1, int(abs(u1 - u0) // step))
    return [s.pt(u0 + (u1 - u0) * i / n, v) for i in range(n + 1)]


def draw(level, season, variant=0, mirror=False, sea=None, shore=None, bay=None, addon=False):
    if level == 0:                                    # no piece on the map: the sheets show the wild shore
        return kit.wild(season, "grass", seed=SEED, coast=COAST, sea=sea, shore=shore, bay=bay, mirror=mirror)
    p = kit.Piece(season, ground="grass", seed=SEED, sea=sea, shore=shore, bay=bay, mirror=mirror)
    s = p.coast(**COAST)
    if s.bay is not None:                             # the map has cut a bay: the carved layout
        return carved(p, s, level, season, addon)
    L = LAYOUT[variant]
    su, au, wi, sp = season == "summer", season == "autumn", season == "winter", season == "spring"
    land = not addon                                  # the add-on keeps to the water's edge: no huts, warehouses, rack, people

    # ---- ground plane
    if land and level >= 1:                           # trodden ground round the huts (overlays)
        for u, v, w, h in L["yards"]:
            p.blob(*s.pt(u, v), w, h, p.pal["soil"], alpha=0.35)
    if level >= 3:                                    # the slip down to the water
        u, v = L["slip"]
        p.patch([s.pt(u - 2.5, v - 6), s.pt(u + 2.5, v - 6), s.pt(u + 2.5, 0.5), s.pt(u - 2.5, 0.5)],
                kit.mix(kit.TIMBER, p.pal["grass"], 0.35), kit.TIMBER_D, 0.5)
    if level >= 1:
        u, v0, v1 = L["jetty"]
        p.jetty(s.pt(u, v0), s.pt(u, v1), 1.8, snow=True)
        p.jetty(s.pt(u - 3.2, v1), s.pt(u + 3.2, v1), 1.8, snow=True)                        # the T head
    if level >= 2:
        p.jetty(line_at(s, L["quay"][0], L["quay"][1], L["quay"][2]), None, 3.2, stone=True, snow=True)
    if level >= 3:
        for pts in L["moles"]:                                                               # the moles close a basin
            p.jetty([s.pt(*q) for q in pts], None, 3.6, stone=True, snow=True)

    # ---- standing things
    if land and level >= 1:
        for u, v, sm in L["huts"]:
            p.house(*s.pt(u, v), 5.5, 3.5, 3.0, roof="thatch", smoke=sm)
        net_rack(p, *s.pt(L["rack"][0], L["rack"][1]), *s.pt(L["rack"][2], L["rack"][3]))
    if level >= 1:
        p.boat(*s.pt(*L["beached"]), 0.55, sail=False)
    if land and level >= 2:
        for i, (u, v) in enumerate(L["warehouses"][:2]):
            p.house(*s.pt(u, v), 11.5, 5.2, 4.4, wall=(1, 3)[i], kind="ridge", roof="tile", door=False)
    if level >= 2:
        for (u, v), frm in L["ships"]:
            if level >= frm:
                afloat(p, s, u, v, 1.0, not wi)
    if level >= 3:
        if land:
            u, v = L["warehouses"][2]
            p.house(*s.pt(u, v), 11.5, 5.2, 4.4, wall=4, kind="ridge", roof="tile", door=False)
        hull_on_slip(p, *s.pt(*L["slip"]))
        light = s.first(L["lights"], *LIGHT_SIZE)
        if light is not None:
            lighthouse(p, *s.pt(*light))
    for i, (home, out, frm) in enumerate(L["boats"]):
        if level < frm:
            continue
        at_sea = sp or su or (au and i % 2 == 1)
        afloat(p, s, *(out if at_sea else home), BOAT_SC, not wi)
    # ---- season activity
    if land and (sp or su) and level >= 1:
        p.person(*s.pt(*L["fisher"]))                    # a fisherman at the net rack
    if land and (sp or su or au) and level >= 2:
        p.person(*s.pt(*L["quayman"]), (70, 96, 150))    # a man on the quay
    return p.finish(label="harbour L%d%s" % (level, " addon" if addon else ""))


def carved(p, s, level, season, addon):
    """The harbour in the map's bay (one layout). u is relative to the bay's middle; the quay and the slip lie on the
    bay's own shore (s.pt), the moles along the mouth line (b.pt), the berths are cut to the water (b.room)."""
    b, C = s.bay, CARVED
    u0 = b.u0
    su, au, wi, sp = season == "summer", season == "autumn", season == "winter", season == "spring"
    land = not addon

    def room(u):                                      # the water at u (u relative), from the back of the bay to the mouth line
        return b.room(u0 + u)

    def inside(u, v):                                 # a berth in the bay: v from the shore, 3 px short of the mouth line; None if no room
        v = min(v, room(u) - 3.0)
        return (u, v) if v >= 3.0 else None

    # ---- ground plane
    if land and level >= 1:                           # trodden ground round the huts (overlays)
        for u, v, w, h in C["yards"]:
            p.blob(*s.pt(u0 + u, v), w, h, p.pal["soil"], alpha=0.35)
    if level >= 3:                                    # the slip down to the water
        u, v = C["slip"]
        p.patch([s.pt(u0 + u - 2.5, v - 6), s.pt(u0 + u + 2.5, v - 6), s.pt(u0 + u + 2.5, 0.5), s.pt(u0 + u - 2.5, 0.5)],
                kit.mix(kit.TIMBER, p.pal["grass"], 0.35), kit.TIMBER_D, 0.5)
    if level >= 1:                                    # the jetty from the back of the bay, with its T head
        u, v0, v1 = C["jetty"]
        v1 = min(v1, room(u) - 3.0)
        p.jetty(s.pt(u0 + u, v0), s.pt(u0 + u, v1), 1.8, snow=True)
        p.jetty(s.pt(u0 + u - 3.2, v1), s.pt(u0 + u + 3.2, v1), 1.8, snow=True)
    if level >= 2:                                    # the quay along the straight back
        x0, x1 = C["quay"][:2] if level < 3 else C["quay3"]
        p.jetty(line_at(s, u0 + x0, u0 + x1, C["quay"][2]), None, 3.2, stone=True, snow=True)
    if level >= 3:                                    # two short moles from the horns close the mouth to about 28 px
        for horn, sign in ((b.west, 1), (b.east, -1)):
            p.jetty([b.pt(horn + sign * d, v) for d, v in C["mole"]], None, 3.6, stone=True, snow=True)

    # ---- standing things
    if land and level >= 1:
        for u, v, sm in C["huts"]:
            p.house(*s.pt(u0 + u, v), 5.5, 3.5, 3.0, roof="thatch", smoke=sm)
        r = C["rack"]
        net_rack(p, *s.pt(u0 + r[0], r[1]), *s.pt(u0 + r[2], r[3]))
    if level >= 1:
        p.boat(*s.pt(u0 + C["beached"][0], C["beached"][1]), 0.55, sail=False)
    if land and level >= 2:
        for i, (u, v) in enumerate(C["warehouses"][:2]):
            p.house(*s.pt(u0 + u, v), 11.5, 5.2, 4.4, wall=(1, 3)[i], kind="ridge", roof="tile", door=False)
    if level >= 2:
        for (u, v), frm in C["ships"]:
            if level >= frm:
                at = inside(u0 + u, v)
                if at is not None:
                    afloat(p, s, *at, 1.0, not wi)
    if level >= 3:
        if land:
            u, v = C["warehouses"][2]
            p.house(*s.pt(u0 + u, v), 11.5, 5.2, 4.4, wall=4, kind="ridge", roof="tile", door=False)
        hull_on_slip(p, *s.pt(u0 + C["slip"][0], C["slip"][1]))
        spots = [b.uv(b.west + d, v) for d, v in C["light"]] + [b.uv(b.east - d, v) for d, v in C["light"]]
        light = s.first(spots, *LIGHT_SIZE)
        if light is not None:
            lighthouse(p, *s.pt(*light))
    for i, (home, out, frm) in enumerate(C["boats"]):
        if level < frm:
            continue
        at_sea = sp or su or (au and i % 2 == 1)
        if at_sea:                                    # out at sea: a few px beyond the mouth line
            at = (u0 + out[0], room(out[0]) + out[1])
        else:
            at = inside(u0 + home[0], home[1])
        if at is not None:
            afloat(p, s, *at, BOAT_SC, not wi)
    # ---- season activity
    if land and (sp or su) and level >= 1:
        p.person(*s.pt(u0 + C["fisher"][0], C["fisher"][1]))
    if land and (sp or su or au) and level >= 2:
        p.person(*s.pt(u0 + C["quayman"][0], C["quayman"][1]), (70, 96, 150))
    return p.finish(label="harbour L%d%s" % (level, " addon" if addon else ""))


def sides_sheet(path, season="summer"):
    """The coast check: levels 1-3, in summer and winter, sea on S, E and NW and the same mirrored; below it the
    add-on (summer), layout 1 (level 3, summer and winter) and the carved port in a bay of depth 13 (levels 1-3 in
    summer, level 3 in winter and as an add-on), all on S, E and NW."""
    pg = kit.pygame
    cases = [(side, m) for m in (False, True) for side in ("S", "E", "NW")]
    cw = kit.SIZE + 8
    bay = (0, kit.BAY_WIDTH, 13)
    rows = [(se, lv, False, 0, None) for se in ("summer", "winter") for lv in (1, 2, 3)]
    rows += [("summer", lv, True, 0, None) for lv in (1, 2, 3)]
    rows += [("summer", 3, False, 1, None), ("winter", 3, False, 1, None)]
    rows += [("summer", lv, False, 0, bay) for lv in (1, 2, 3)]
    rows += [("winter", 3, False, 0, bay), ("summer", 3, True, 0, bay)]
    LAB = 150
    W, H = LAB + len(cases) * cw, 40 + len(rows) * cw + 30
    out = pg.Surface((W, H))
    out.fill(kit.SHEET_BG)
    f = kit._font(17)
    for j, (side, m) in enumerate(cases):
        out.blit(f.render("sea %s%s" % (side, " mirrored" if m else ""), True, kit.SHEET_TEXT), (LAB + j * cw + 4, 8))
    for r, (se, lv, ad, var, bay_) in enumerate(rows):
        label = "%s L%d%s%s%s" % (se, lv, " add-on" if ad else "", " lay.1" if var else "", " carved" if bay_ else "")
        out.blit(f.render(label, True, kit.SHEET_TEXT), (6, 40 + r * cw + 50))
        for j, (side, m) in enumerate(cases):
            img = kit.with_wild(draw, lv, se, variant=var, mirror=m, sea=side, bay=bay_, addon=ad)
            out.blit(kit._cell(img, se, 1.0, 4, "grass"), (LAB + j * cw, 34 + r * cw))
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
