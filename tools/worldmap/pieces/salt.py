"""Salt pans, levels 0-3 (see docs/design/map/pieces/GUIDE.md, section 8).

0 bare shore - 1 three pans, a heap and a hut - 2 eight pans, a feeder channel, a sluice, three heaps -
3 fourteen pans, five heaps, a jetty with a boat and the salt store.

python salt.py             writes docs/design/map/pieces/salt.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(0, 4)
NAMES = {0: "bare shore", 1: "3 pans, hut", 2: "8 pans, sluice", 3: "14 pans, store"}

SHORE_Y = 15.0                                        # the sea starts here, the same at every level
PAN_W, PAN_H = 10.4, 7.3                              # the pan, inside its dyke
PX, PY = 12.0, 9.0                                    # grid pitch
ROW_Y = (-22.0, -13.0, -4.0)
# x of each column; rows 1..3 are ROW_Y[0..2]
PANS = [                                              # cx, cy, from level
    (6, ROW_Y[2], 1), (18, ROW_Y[2], 1), (30, ROW_Y[2], 1),
    (-18, ROW_Y[1], 2), (-6, ROW_Y[1], 2), (6, ROW_Y[1], 2), (18, ROW_Y[1], 2), (30, ROW_Y[1], 2),
    (-6, ROW_Y[0], 3), (6, ROW_Y[0], 3), (18, ROW_Y[0], 3), (30, ROW_Y[0], 3), (-6, ROW_Y[2], 3), (-18, ROW_Y[2], 3),
]
HEAPS = [(8, 1), (-4, 2), (20, 2), (-16, 3), (32, 3)]  # x, from level; all stand on y = HEAP_Y
HEAP_Y = 6.5
HUT = (-37, -8)
CHANNEL = [(-29, 17), (-29, 8), (-29, -2), (-28, -11), (-26, -21)]
SLUICE = (-29, -2)
STORE = (0, -29)
JETTY = ((25, 12), (31, 28))
BOAT = (38, 27)
SCRUB = [(14, -4, 40, 12), (-4, -13, 44, 12), (0, -22, 40, 11)]       # level 0: darker ground where the pans will come
POOLS = [[(11, -7), (17, -8.5), (23, -7), (21, -3), (14, -2.5)], [(-14, -15), (-8, -16.5), (-3, -14), (-6, -10.5), (-12, -10.5)]]
STONES = [(-8, 3, 1.8, 1), (30, 9, 1.6, 9), (-42, 4, 1.8, 9), (4, -33, 1.5, 9), (40, -8, 1.6, 2)]   # x, y, r, gone from level
DRIFTS = [(-30, -30, 13, 5), (30, -31, 12, 5), (-12, 10, 8, 3)]       # winter only


def pan_col(p, i):
    pal = p.pal
    if p.season == "spring":
        return kit.mix(pal["shallow"], pal["sand"], 0.45)
    if p.season == "summer":
        return kit.mix(kit.SALT, kit.PLASTER[2], 0.55) if i % 3 == 1 else kit.SALT
    if p.season == "autumn":
        return kit.mix(kit.STONE_GREY, pal["sand"], 0.3)
    return kit.ICE


def pan(p, cx, cy, i):
    w2, h2 = PAN_W / 2, PAN_H / 2
    dyke = kit.SNOW if p.winter else kit.mix(p.pal["sand"], kit.STONE_D, 0.55)
    p.patch([(cx - w2 - 0.8, cy - h2 - 0.65), (cx + w2 + 0.8, cy - h2 - 0.65), (cx + w2 + 0.8, cy + h2 + 0.65), (cx - w2 - 0.8, cy + h2 + 0.65)], dyke)
    edge = kit.ICE_D if p.winter else kit.STONE_D
    p.patch([(cx - w2, cy - h2), (cx + w2, cy - h2), (cx + w2, cy + h2), (cx - w2, cy + h2)], pan_col(p, i), edge, 0.5)
    inner = kit.mix(pan_col(p, i), kit.SNOW if p.winter else (kit.SALT if p.season != "autumn" else kit.STONE_GREY_D), 0.35)
    p.gp.line((cx - w2 + 1.6, cy - 0.6), (cx + w2 - 2.2, cy - 0.6), inner, 0.5)         # a glint, a crust or a crack
    if p.season == "summer" and i % 3 != 1:
        p.gp.line((cx - w2 + 2.4, cy + 1.6), (cx + w2 - 3.0, cy + 1.6), kit.shade(kit.SALT, 0.93), 0.5)


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
    p.stand(y, fn)


def draw(level, season):
    p = kit.Piece(season, ground="sand", seed=2)
    su, au, wi = season == "summer", season == "autumn", season == "winter"
    pans = [q for q in PANS if q[2] <= level]
    heaps = [h for h in HEAPS if h[1] <= level]
    work = [(q[0], q[1], 9) for q in pans] + [(h[0], HEAP_Y, 6) for h in heaps]
    if level >= 1:
        work.append((HUT[0], HUT[1], 8))
    if level >= 2:
        work.append((SLUICE[0], SLUICE[1], 6))

    # ---- ground plane (the same order every time, so the scatter never moves)
    if level == 0:                                    # wild: darker wet ground where the pans will come, two pools
        for x, y, w, h in SCRUB:
            p.blob(x, y, w, h, kit.mix(p.pal["sand"], p.pal["soil"], 0.25))
    p.tufts(14 if level == 0 else 8 if level == 1 else 5 if level == 2 else 3, area=(-46, -44, 46, 6), avoid=work)
    p.stones([(x, y, r) for x, y, r, gone in STONES if level < gone])
    p.coast(SHORE_Y, amp=2.0, sand=4.0, seed=3)
    if level == 0:
        for pts in POOLS:
            p.patch(pts, kit.ICE if wi else kit.mix(p.pal["shallow"], p.pal["sand"], 0.3),
                    kit.ICE_D if wi else kit.mix(p.pal["shallow"], p.pal["sand"], 0.7), 0.5)       # shallow pools
    if level >= 2:
        p.water(CHANNEL, 2.2)
    for i, (cx, cy, _) in enumerate(PANS):
        if level >= PANS[i][2]:
            pan(p, cx, cy, i)
    if level >= 3:
        p.jetty(JETTY[0], JETTY[1], 2.2)
    for d in DRIFTS:
        p.snow_patch(*d)

    # ---- standing things
    if level >= 1:
        p.house(HUT[0], HUT[1], 5.5, 3.5, 3.0, roof="thatch", smoke=True)
    if level >= 2:
        sluice(p, SLUICE[0], SLUICE[1])
    covered = au or wi
    for hx, frm in HEAPS:
        if level >= frm:
            if covered:
                p.heap(hx, HEAP_Y, 8, 5.5, kit.THATCH, kit.THATCH_D)
            else:
                p.heap(hx, HEAP_Y, 8, 5.5, kit.SALT, kit.shade(kit.SALT, 0.86))
    if level >= 3:
        p.house(STORE[0], STORE[1], 16, 5.4, 4.6, wall=3, kind="ridge", roof="tile", door=False)
        p.boat(BOAT[0], BOAT[1], 0.55, sail=not wi)
    # ---- season activity: two rakers in summer
    if su and level >= 1:
        p.person(24, 1.8)
        if level >= 2:
            p.person(38, 1.8, (70, 96, 150))
    return p.finish(label="salt L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "salt.png")
    kit.sheet(draw, LEVELS, "Salt pans: levels 0-3 by season", out, NAMES, ground="sand")
    print("wrote", os.path.normpath(out))
