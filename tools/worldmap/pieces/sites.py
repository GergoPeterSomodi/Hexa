"""Sites: one old stone thing alone in the wild land (see docs/design/map/pieces/GUIDE.md, section 8, "Sites").

One level. THE VARIANT IS THE SITE: the map data says which hex has which site, so the map passes variant= itself and
takes only the mirror from kit.pick().
0 monastery - 1 Roman ruins - 2 aqueduct - 3 standing stones - 4 ruined castle - 5 pilgrimage chapel.
A site is decoration: it marks no rule of the game. It has no fields beyond the monastery's one garden plot, no
animals, no heaps; smoke only from the monastery (autumn and winter); one or two pilgrims at the chapel in summer.
The piece draws no wild land: the wild trees and stones of the map stand close round it (footprint 8-20%).

The sites are drawn mirror-aware: a part that points at a neighbour (the broken end of the aqueduct, the ragged ends of
the ruined wall) is built in the reflected frame (sg = p.m) and stood with x=0, so the whole arrangement turns round
like the ground does; the light stays upper left because every two-tone shape is shaded after it is reflected.

python sites.py            writes docs/design/map/pieces/sites.png and sites_variants.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = (0, 1)
NAMES = {0: "wild land (the map's)", 1: "the site (variant = which)"}
VARIANTS = 6
SITES = ("monastery", "roman_ruins", "aqueduct", "standing_stones", "ruined_castle", "pilgrimage_chapel")
# Only the sites with a track have a gate point (unmirrored, 10+ px inside the border): the monastery and the chapel.
GATES = [{"south": (0, 34)}, {}, {}, {}, {}, {"south": (-4, 33)}]

# ------------------------------------------------------------------ the layout tables (one dict per site)
LAYOUT = [
    dict(  # 0 monastery: the church in the middle at the back between two wings, a low range across the front, a wall
        church=(-1.5, -5), wing_w=(-10, -5, 8.5), wing_e=(11.5, -5, 8.5), south=(0, 9.5, 13),
        wall=[(-3, 14.5), (-19.5, 14.5), (-19.5, -9.5), (19.5, -9.5), (19.5, 14.5), (3, 14.5)],
        court=[(-10, -2), (10, -2), (10, 5), (-10, 5)],
        plot=(13.5, 7, 8, 4.5), fruit=[(-12, 10), (-17, 6)], track=[(0, 9.5), (0, 14.5), (0, 24), (0, 34)]),
    dict(  # 1 Roman ruins: four columns, a lintel on the two tallest, two fallen drums, a paved patch
        paving=[(-20, 4), (-11, -2), (6, -3), (19, 0), (22, 6), (13, 11), (-8, 12), (-19, 9)],
        cols=[(-14, 3, 6.0), (-5, 0, 9.6), (5, -1, 8.6), (14, 3, 7.5)], lintel=(-5, 5),
        drums=[(-9, 8), (10, 8.5)]),
    dict(  # 2 aqueduct: 5 arches, 34 long, the last pier broken
        y=6, x0=-17, pier=2.0, span=4.4, high=9.0, spring=3.8, deck=(9.0, 6.0),
        claim=[(-20, -6), (20, -6), (20, 12), (-20, 12)]),
    dict(  # 3 standing stones: a ring of 7 (the 7th lies fallen), one taller, a faint trodden circle
        centre=(0, 2), rx=13.5, ry=7.2, first=15.0, heights=[4.6, 5.4, 4.2, 6.6, 4.8, 5.2], fallen=5, tall=3),
    dict(  # 4 ruined castle: a tower stump, a length of wall with a gap, ivy, rubble
        tower=(-10, 5, 12, 12.5), wall=(-4, 19, 5, 6.0), gap=(5, 10), rubble=(7.5, 6.5),
        ivy=[(-14.5, -1.5, 3.0, 4.6), (-1.0, 0.5, 5.0, 3.0)]),
    dict(  # 5 pilgrimage chapel: the chapel on a pale knoll, a cross, two cypresses, a track to the south gate
        chapel=(-4, 1), knoll=(0, 7, 38, 17), cross=(13, 8), cypress=[(-17, 3), (14, -3.5)],
        track=[(-2, 8), (2, 16), (-1, 25), (-4, 33)], pilgrims=[(3, 17), (-3, 27)]),
]

# ------------------------------------------------------------------ small drawing helpers
GREY = (kit.STONE_GREY, kit.STONE_GREY_D)
SAND = (kit.STONE, kit.STONE_D)
MARB = (kit.MARBLE, kit.MARBLE_D)


def _clip_right(pts, xa):
    """The part of the polygon with x >= xa (Sutherland-Hodgman against one vertical line)."""
    out = []
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        ia, ib = a[0] >= xa, b[0] >= xa
        if ia:
            out.append(a)
        if ia != ib:
            t = (xa - a[0]) / (b[0] - a[0])
            out.append((xa, a[1] + t * (b[1] - a[1])))
    return out


def _solid(pen, pts, cols, band=0.26, ink=kit.INK, lw=0.5):
    """A two-tone standing shape in the picture's frame: lit, the right `band` of its width shaded, a thin ink line."""
    lit, dark = cols
    xs = [q[0] for q in pts]
    x0, x1 = min(xs), max(xs)
    pen.poly(pts, lit, None)
    d = _clip_right(pts, x1 - (x1 - x0) * band)
    if len(d) >= 3:
        pen.poly(d, dark, None)
    if ink is not None:
        pen.poly(pts, None, ink, lw)


def _cap(pen, top, thick=1.3, shaded=True):
    """Snow along a ragged top line (a list of points in the picture's frame): lit snow, the right part shaded."""
    pts = list(top) + [(x, y + thick) for x, y in reversed(top)]
    pen.poly(pts, kit.SNOW, None)
    if shaded:
        xs = [q[0] for q in top]
        d = _clip_right(pts, max(xs) - (max(xs) - min(xs)) * 0.26)
        if len(d) >= 3:
            pen.poly(d, kit.SNOW_D, None)


def _arch(cx, yb, r, n=10, flip=1):
    """The upper half of an arch ring, from the right springing over the top to the left one."""
    return [(cx + math.cos(math.pi * i / n) * r, yb - math.sin(math.pi * i / n) * r) for i in range(n + 1)]


# ------------------------------------------------------------------ 0 monastery
def monastery(p, season):
    L = LAYOUT[0]
    # ground: the court (claimed, nothing wild grows in it), the plot, the track, the low wall
    p.claim(L["court"])                                                          # nothing wild grows in the court
    p.claim([(0, -12), (7, -12), (7, -8), (0, -8)])                            # ... nor behind the tower
    p.over(lambda pen: pen.poly(L["court"], kit.PLASTER[4], None), 0.2)           # the trodden court, too faint to count
    cx, cy, w, h = L["plot"]
    p.field(cx, cy, w, h, 0, kit.crop("garden", season), 3, furrows=season in ("autumn", "winter", "spring"))
    p.road(L["track"], 1.6, track=True)
    p.stockade(L["wall"], kind="low", height=2.2, col=kit.STONE_GREY, claim=True)           # the low precinct wall, the gate gap in front
    # the church and the three wings, slate roofs, one joined block round the court
    p.church(*L["church"], "church", roof="slate")
    wx, wy, ww = L["wing_w"]
    p.house(wx, wy, ww, 4.4, 3.4, wall=0, kind="ridge", roof="slate", door=False)
    ex, ey, ew = L["wing_e"]
    p.house(ex, ey, ew, 4.4, 3.4, wall=0, kind="ridge", roof="slate", door=False, smoke=True)
    sx, sy, sw = L["south"]
    p.house(sx, sy, sw, 3.8, 2.8, wall=3, kind="ridge", roof="slate", door=True)
    for i, (x, y) in enumerate(L["fruit"]):
        p.tree(x, y, 0.9, "fruit", i + 1)
    p.hold(L["fruit"], side=2.5, back=3, front=4)                                 # the low fruit trees keep their ground


# ------------------------------------------------------------------ 1 Roman ruins
def _column(p, x, y, h, broken, seed=0):
    """A fluted marble column, foot at (x, y), h tall in all. broken: a jagged top; else a capital."""
    p.cast(x, y, 4)

    def fn(pen):
        top_y = y - h + (0 if broken else 1.3)           # the shaft's top
        if broken:
            j = ((0.4, -0.9, 0.5, -0.6), (-0.3, 0.5, -0.4, 0.3), (0.6, -0.4, 0.2, -0.8), (-0.5, 0.2, -0.7, 0.4))[seed % 4]
            shaft = [(x - 1.35, y), (x + 1.35, y), (x + 1.25, top_y + j[0]), (x + 0.5, top_y + j[1] - 0.6), (x - 0.2, top_y + j[2]),
                     (x - 1.3, top_y + j[3])]
        else:
            shaft = [(x - 1.35, y), (x + 1.35, y), (x + 1.25, top_y), (x - 1.25, top_y)]
        _solid(pen, shaft, MARB, 0.36)
        pen.line((x - 0.2, y - 1.4), (x - 0.2, top_y + 1.4), kit.MARBLE_D, 0.5)                                 # a flute
        _solid(pen, [(x - 2.1, y), (x + 2.1, y), (x + 2.1, y - 1.1), (x - 2.1, y - 1.1)], MARB, 0.3)           # the base
        if not broken:
            _solid(pen, [(x - 2.4, top_y), (x + 2.4, top_y), (x + 2.4, top_y - 1.3), (x - 2.4, top_y - 1.3)], MARB, 0.3)
        if p.winter:
            ty = top_y - (0 if broken else 1.3)
            _cap(pen, [(x - 1.3, ty + 0.3), (x + 1.3, ty + 0.3)], 0.9, False)
    return p.stand(y, fn, x=x)


def _lintel(p, x0, x1, y, ytop, th=2.4):
    """The beam across two columns, ytop its top edge; cracked in the middle."""
    def fn(pen):
        pts = [(x0 - 0.5, ytop + th), (x1 + 0.5, ytop + th), (x1 + 0.5, ytop), (x0 - 0.5, ytop)]
        _solid(pen, pts, MARB, 0.22)
        xm = (x0 + x1) / 2 + 1.0
        pen.line((xm, ytop), (xm - 0.7, ytop + th * 0.6), kit.MARBLE_D, 0.5)
        if p.winter:
            _cap(pen, [(x0 - 0.3, ytop + 0.2), (x1 + 0.3, ytop + 0.2)], 0.9)
    return p.stand(y, fn, x=(x0 + x1) / 2)


def _drum(p, x, y, w=5.8):
    """A fallen column drum lying on the ground: lit on top, shaded below, one pale end."""
    p.cast(x, y, w * 0.8, 1.6)

    def fn(pen):
        x0 = x - w / 2
        pale = kit.mix(kit.MARBLE, (255, 255, 255), 0.5)                          # paler than the map's grey stones
        pen.rect(x0, y - 2.7, w, 1.5, pale, None)
        pen.rect(x0, y - 1.2, w, 1.2, kit.mix(kit.MARBLE, kit.MARBLE_D, 0.45), None)
        pen.ellipse(x - w / 2, y - 1.35, 1.8, 2.7, pale, None)
        pen.rect(x0, y - 2.7, w, 2.7, None, kit.INK, 0.5)
        pen.line((x0 + w * 0.55, y - 2.7), (x0 + w * 0.55, y), kit.MARBLE_D, 0.4)
        if p.winter:
            pen.rect(x0 + 0.4, y - 3.3, w - 0.8, 0.9, kit.SNOW, None)
    return p.stand(y, fn, x=x)


def roman_ruins(p, season):
    L = LAYOUT[1]
    pav = L["paving"]
    def paving(pen):
        pen.poly(pav, kit.MARBLE, None)
        for a, b in (((-14, 0), (-12, 11)), ((-2, -3), (0, 13)), ((10, -2), (11, 11)), ((-22, 7), (22, 4))):
            pen.line(a, b, kit.MARBLE_D, 0.6)
    p.over(paving, 0.55)
    cols = L["cols"]
    for i, (x, y, h) in enumerate(cols):
        _column(p, x, y, h, broken=h < 9, seed=i)
    a, b = L["lintel"][0], L["lintel"][1]
    ya = max(c[1] for c in cols if c[0] in (a, b))
    _lintel(p, a, b, ya + 0.5, min(c[1] - c[2] for c in cols if c[0] in (a, b)) - 2.4)
    for x, y in L["drums"]:
        _drum(p, x, y)
    p.hold(L["drums"], side=3, back=3, front=4)                                  # the fallen drums keep their ground


# ------------------------------------------------------------------ 2 aqueduct
def aqueduct(p, season):
    L = LAYOUT[2]
    sg = p.m
    y, x0, pw, sp, hh, spr = L["y"], L["x0"], L["pier"], L["span"], L["high"], L["spring"]
    step = pw + sp
    r = sp / 2.0
    p.claim(L["claim"])
    p.shadow(1.5, y + 1.0, 38, 3.2)

    def R(pts):
        return [(sg * a, b) for a, b in pts]

    def fn(pen):
        n = 5
        # ---- the body: piers 0-4, the decks over arches 0-3, the left half of arch 4's spandrel (a ragged end)
        arch_x = [x0 + pw + k * step for k in range(n)]          # left edge of each opening
        top = [(x0, y), (x0, y - hh), (arch_x[4] + 1.2, y - hh), (arch_x[4] + 1.9, y - hh + 1.0), (arch_x[4] + 1.3, y - hh + 1.9),
               (arch_x[4] + 2.0, y - hh + 2.9), (arch_x[4] + r, y - spr - r)]
        body = list(top)
        a4 = _arch(arch_x[4] + r, y - spr, r)             # right to left over the top
        body += [q for q in a4 if q[0] < arch_x[4] + r - 0.01]
        body += [(arch_x[4], y)]
        for k in range(3, -1, -1):                        # the openings of arches 3..0, right to left
            xa, xb = arch_x[k], arch_x[k] + sp
            body += [(xb, y), (xb, y - spr)] + _arch(xa + r, y - spr, r)[1:-1] + [(xa, y - spr), (xa, y)]
        body += [(x0, y)]
        pts = R(body)
        pen.poly(pts, kit.STONE, None)
        # the shaded right face of each pier, a vault band inside each opening, the coping line on the deck
        for k in range(n):
            px = x0 + k * step
            pen.rect(*(lambda a, b: (min(a, b), y - hh, abs(b - a), hh))(sg * (px + pw * 0.62), sg * (px + pw)), kit.STONE_D, None)
        for k in range(4):
            xa = arch_x[k]
            ring = _arch(xa + r, y - spr, r)
            inner = _arch(xa + r, y - spr, r - 0.9)
            pen.poly(R(ring + list(reversed(inner))), kit.shade(kit.STONE_D, 0.9), None)
        pen.line((sg * x0, y - hh + 1.2), (sg * (arch_x[4] + 1.6), y - hh + 1.2), kit.STONE_D, 0.5)
        pen.poly(pts, None, kit.INK, 0.5)
        # ---- the broken last pier: a stump with a jagged top and two fallen blocks
        px = x0 + 5 * step
        stump = [(px, y), (px, y - 5.0), (px + 0.7, y - 5.8), (px + 1.2, y - 4.4), (px + 1.7, y - 5.4), (px + 2.0, y - 4.2), (px + 2.0, y)]
        sp_pts = R(stump)
        _solid(pen, sp_pts, SAND, 0.34)
        for bx, by, bw in ((px - 2.6, y, 2.2), (px + 3.4, y, 1.8)):
            _solid(pen, R([(bx, by), (bx + bw, by), (bx + bw, by - 1.5), (bx, by - 1.5)]), SAND, 0.3)
        if p.winter:
            _cap(pen, [(sg * x0, y - hh + 0.1), (sg * (arch_x[4] + 1.2), y - hh + 0.1)], 1.2)
            _cap(pen, [(sg * (px + 0.1), y - 5.0), (sg * (px + 1.9), y - 4.5)], 0.9, False)
    p.stand(y, fn, x=0)


# ------------------------------------------------------------------ 3 standing stones
def _stone(p, x, y, h, w=3.4, lean=0.0, fallen=False):
    p.cast(x, y, 4.0 if not fallen else 5.5, 1.6 if fallen else None)

    def fn(pen):
        if fallen:                                          # lying: a long low boulder, pale on top
            pts = [(x - 3.4, y), (x - 3.6, y - 1.3), (x - 2.0, y - 2.4), (x + 1.2, y - 2.6), (x + 3.2, y - 1.8), (x + 3.7, y - 0.6), (x + 3.0, y)]
            _solid(pen, pts, GREY, 0.4)
            if p.winter:
                _cap(pen, [(x - 2.2, y - 2.3), (x + 1.2, y - 2.5), (x + 3.0, y - 1.7)], 0.9)
            return
        hw = w / 2
        pts = [(x - hw, y), (x - hw * 0.85 + lean, y - h * 0.62), (x - hw * 0.45 + lean, y - h * 0.94), (x + 0.2 + lean, y - h),
               (x + hw * 0.7 + lean, y - h * 0.88), (x + hw * 0.92 + lean * 0.6, y - h * 0.55), (x + hw, y)]
        _solid(pen, pts, GREY, 0.36)
        if p.winter:
            _cap(pen, [pts[2], pts[3], pts[4]], 1.1)
    return p.stand(y, fn, x=x)


def standing_stones(p, season):
    L = LAYOUT[3]
    cx, cy, rx, ry = L["centre"][0], L["centre"][1], L["rx"], L["ry"]
    p.blob(cx, cy, 2 * rx + 9, 2 * ry + 8, p.pal["soil"], alpha=0.25)              # the trodden circle
    n = 7
    k = 0
    p.hold([(cx + math.cos(math.radians(L["first"] + i * 360.0 / n)) * rx, cy + math.sin(math.radians(L["first"] + i * 360.0 / n)) * ry)
            for i in range(n)], side=2.5, back=3, front=4)                       # the ring's low stones keep their ground
    for i in range(n):
        a = math.radians(L["first"] + i * 360.0 / n)
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        if i == L["fallen"]:
            _stone(p, x, y + 0.5, 2.4, fallen=True)
            continue
        h = L["heights"][k]
        _stone(p, x, y, h, w=3.0 + 0.5 * (h > 6), lean=(-0.35, 0.3, 0.0, 0.2, -0.25, 0.35)[k])
        k += 1


# ------------------------------------------------------------------ 4 ruined castle
def ruined_castle(p, season):
    L = LAYOUT[4]
    sg = p.m
    tx, ty, tw, th = L["tower"]
    wa, wb, wy, wh = L["wall"]
    g0, g1 = L["gap"]
    rx_, ry_ = L["rubble"]
    p.claim([(-16, -10), (-4, -10), (-4, 9), (-16, 9)])
    p.claim([(-4, -3), (19, -3), (19, 9), (-4, 9)])

    def R(pts):
        return [(sg * a, b) for a, b in pts]

    def prof(x0, x1, y, tops):
        """A polygon on the foot line y between x0 and x1 with a ragged top: tops = [(x, height)] from left to right."""
        return [(x0, y)] + [(a, y - h) for a, h in tops] + [(x1, y)]

    t0, t1 = tx - tw / 2, tx + tw / 2
    tower_tops = [(t0, th - 2.0), (t0 + 1.8, th), (t0 + 3.3, th - 1.6), (t0 + 4.6, th - 3.2), (t0 + 6.0, th - 1.0), (t0 + 7.6, th - 2.6),
                  (t0 + 9.0, th - 4.4), (t1 - 0.6, th - 3.4), (t1, th - 5.2)]
    wallA_tops = [(wa, wh), (wa + 3.0, wh), (g0 - 3.6, wh - 0.6), (g0 - 2.4, wh - 2.2), (g0 - 1.4, wh - 1.4), (g0 - 0.6, wh - 3.4), (g0, wh - 4.2)]
    wallB_tops = [(g1, 1.8), (g1 + 0.9, 3.2), (g1 + 2.2, 2.4), (g1 + 3.4, 4.6), (g1 + 4.6, wh - 0.4), (wb - 2.4, wh), (wb - 0.8, wh - 1.4), (wb, wh - 3.0)]
    p.shadow(-3.5, ty + 1.0, 38, 3.4)

    def fn(pen):
        # wall pieces first (behind the tower's right edge), tower last
        pa = R(prof(wa, g0, wy, wallA_tops))
        pb = R(prof(g1, wb, wy, wallB_tops))
        for pts, top in ((pa, wallA_tops), (pb, wallB_tops)):
            _solid(pen, pts, GREY, 0.2)
        for pts in (pa, pb):                                           # two stone courses and a loophole
            xs = [q[0] for q in pts]
            for c in (2.3, 4.2):
                pen.line((min(xs) + 0.3, wy - c), (max(xs) - 0.3, wy - c), kit.shade(kit.STONE_GREY_D, 0.95), 0.4)
        pen.rect(sg * (wa + 4.3) - 0.45, wy - 3.7, 0.9, 2.0, kit.DOOR, None)
        pen.rect(sg * (g1 + 5.2) - 0.45, wy - 3.7, 0.9, 2.0, kit.DOOR, None)
        # the tower stump: a square front, a ragged top, a door, a slit, courses
        pt = R(prof(t0, t1, ty, tower_tops))
        _solid(pen, pt, GREY, 0.26)
        xa, xb = min(sg * t0, sg * t1), max(sg * t0, sg * t1)
        for c in (3.6, 7.0):
            pen.line((xa + 0.3, ty - c), (xb - 0.3, ty - c), kit.shade(kit.STONE_GREY_D, 0.95), 0.4)
        pen.rect(sg * tx - 0.5, ty - 8.6, 1.0, 2.4, kit.DOOR, None)
        pen.rect(sg * tx - 1.0, ty - 3.1, 2.0, 3.1, kit.DOOR, None)
        if p.winter:
            _cap(pen, R([(a, ty - h + 0.1) for a, h in tower_tops]), 1.4)
            _cap(pen, R([(a, wy - h + 0.1) for a, h in wallA_tops]), 1.1)
            _cap(pen, R([(a, wy - h + 0.1) for a, h in wallB_tops]), 1.1)
    p.stand(ty, fn, x=0)
    for ix, iy, iw, ih in L["ivy"]:                                        # ivy: patches on the faces
        def ivy(pen, ix=ix, iy=iy, iw=iw, ih=ih):
            pen.ellipse(sg * ix, iy, iw + 0.8, ih + 0.8, p.pal["hedge_d"], None)
            pen.ellipse(sg * ix - 0.3, iy - 0.3, iw, ih, p.pal["hedge"], None)
            if p.winter:
                pen.ellipse(sg * ix - 0.6, iy - ih * 0.3, iw * 0.7, ih * 0.35, kit.SNOW, None)
        p.stand(ty + 0.05, ivy, x=0)
    p.heap(rx_, ry_, 6.0, 2.8, kit.STONE_GREY, kit.STONE_GREY_D)


# ------------------------------------------------------------------ 5 pilgrimage chapel
def _cross(p, x, y):
    p.cast(x, y, 3.4)

    def fn(pen):
        _solid(pen, [(x - 1.7, y), (x + 1.7, y), (x + 1.3, y - 1.8), (x - 1.3, y - 1.8)], GREY, 0.34)        # the steps
        _solid(pen, [(x - 0.6, y - 1.8), (x + 0.6, y - 1.8), (x + 0.6, y - 7.0), (x - 0.6, y - 7.0)], GREY, 0.4)
        _solid(pen, [(x - 2.2, y - 5.3), (x + 2.2, y - 5.3), (x + 2.2, y - 6.5), (x - 2.2, y - 6.5)], GREY, 0.3)
        if p.winter:
            _cap(pen, [(x - 2.1, y - 6.5), (x + 2.1, y - 6.5)], 0.8, False)
    return p.stand(y, fn, x=x)


def pilgrimage_chapel(p, season):
    L = LAYOUT[5]
    kx, ky, kw, kh = L["knoll"]
    p.blob(kx, ky, kw, kh, kit.PLASTER[3], alpha=0.55)                          # the pale trodden knoll
    p.blob(kx - 1, ky - 1, kw * 0.6, kh * 0.55, kit.PLASTER[3], alpha=0.4)
    p.road(L["track"], 1.6, track=True)
    p.claim([(-9, -11), (1, -11), (1, -4), (-9, -4)])                            # nothing wild behind the chapel
    p.church(*L["chapel"], "chapel")
    _cross(p, *L["cross"])
    for i, (x, y) in enumerate(L["cypress"]):
        p.tree(x, y, 0.82, "cypress", i)
    if season == "summer":                                                      # one or two pilgrims
        p.person(*L["pilgrims"][0], (96, 84, 120))
        p.person(*L["pilgrims"][1], (150, 100, 64))


SITE_FN = (monastery, roman_ruins, aqueduct, standing_stones, ruined_castle, pilgrimage_chapel)


def draw(level, season, variant=0, mirror=False):
    if level == 0:                                    # no piece on the map: the sheet shows the wild land
        return kit.wild(season, "grass", seed=17)
    p = kit.Piece(season, ground="grass", seed=17, mirror=mirror)
    SITE_FN[variant](p, season)
    return p.finish(label="sites %s" % SITES[variant])


# ------------------------------------------------------------------ the sheets
def sites_sheet(path):
    """One row per site: the wild land, the site in spring, summer, autumn and the snow winter, then the frost and the
    mild winter; and all seven at 50% on the right."""
    pygame = kit.pygame
    cols = [("wild land", 0, "summer", None), ("spring", 1, "spring", None), ("summer", 1, "summer", None),
            ("autumn", 1, "autumn", None), ("winter: snow", 1, "winter", "snow"), ("winter: frost", 1, "winter", "frost"),
            ("winter: mild", 1, "winter", "mild")]
    pad, gap, left, top = 6, 6, 150, 84
    cw = kit.SIZE + pad * 2
    hw = cw // 2
    x50 = left + len(cols) * (cw + gap) + 24
    W = x50 + len(cols) * (hw + 4) + 16
    H = top + len(SITES) * (cw + gap) + 16
    out = pygame.Surface((W, H))
    out.fill(kit.SHEET_BG)
    f_t, f_h, f_s = kit._font(30, True), kit._font(22), kit._font(18)
    out.blit(f_t.render("Sites: six old stone things in the wild land (one level; the variant is the site)", True, kit.SHEET_TEXT), (16, 12))
    out.blit(f_s.render("100%  (hex radius 60); each site stands in the map's wild land, thinned by its footprint", True, kit.SHEET_DIM), (left, 44))
    out.blit(f_s.render("50% test", True, kit.SHEET_DIM), (x50, 44))
    for j, (name, lv, se, cl) in enumerate(cols):
        out.blit(f_s.render(name, True, kit.SHEET_TEXT), (left + j * (cw + gap) + 4, top - 18))
    for i, name in enumerate(SITES):
        y = top + i * (cw + gap)
        out.blit(f_h.render(name.replace("_", " "), True, kit.SHEET_TEXT), (14, y + 44))
        out.blit(f_s.render("variant %d" % i, True, kit.SHEET_DIM), (14, y + 66))
        for j, (cn, lv, se, cl) in enumerate(cols):
            img = kit.with_wild(draw, lv, se, variant=i, climate=cl)
            gr = "grass"
            out.blit(kit._cell(img, se, 1.0, pad, gr, cl), (left + j * (cw + gap), y))
            out.blit(kit._cell(img, se, 0.5, pad, gr, cl), (x50 + j * (hw + 4), y + hw // 2))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "..", "docs", "design", "map", "pieces", "sites.png")
    sites_sheet(out)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "sites_variants.png")
    kit.variant_sheet(draw, LEVELS, "Sites: the six sites, their mirrors, and how they sit side by side", vout, NAMES, ground="grass")
    print("wrote", os.path.normpath(vout))
