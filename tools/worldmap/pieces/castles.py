"""Castles, levels 1-3 (see docs/design/map/pieces/GUIDE.md, section 8).

1 watchtower (a palisade ring, one stone tower with a slate cone) - 2 castle (a grey stone ring wall with corner towers
and a gatehouse, the keep) - 3 bastion fortress (a low, thick, angular wall with four pointed bastions lying round the
castle, a moat, a gate tower; the castle of level 2 stands inside it unchanged).

All three stand on the same low mound. The banner colour is a parameter: draw(level, season, flag=kit.FLAG).
The tower of level 1 and the keep of level 2 share one foot (KEEP): the keep is the tower grown in place.

python castles.py          writes docs/design/map/pieces/castles.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(1, 4)
NAMES = {1: "watchtower", 2: "castle, keep", 3: "bastion fortress"}

# ---- the fixed layout: nothing here depends on the level except where a "from level" is given
CX, CY = 0, 1                                        # the middle of the place (ring wall, mound): the same in every level
KEEP = (0, -3)                                       # foot of the tower / keep
MOUND = (0, 1, 41, 21)                               # x, y, w, h of the low mound
RING1 = (10, 5.5)                                    # level 1 palisade ring: rx, ry
RING2 = (17, 9.35)                                   # level 2 stone ring: rx, ry (ry = 0.55 rx)
RING_H = 4.0                                         # ring wall height
FORT_A, FORT_B = 26.0, 16.5                          # level 3: half sizes of the curtain walls, in plan (before the tilt)
FORT_H = 4.6                                         # fortress wall height
FORT_T = 3.4                                         # fortress wall thickness (plan)
MOAT_W = 3.0                                         # visible width of the moat
TREES = [                                            # x, y, kind, size, gone from level
    (-36, -12, "round", 1.0, 3), (35, -14, "round", 0.95, 3), (29, -20, "round", 0.9, 2),
    (-38, 12, "round", 1.0, 2), (40, 10, "round", 0.9, 3), (-13, -29, "round", 0.85, 9), (12, -29, "round", 0.85, 9),
    (-24, 27, "bush", 1.0, 2), (26, 29, "bush", 1.0, 2), (-31, -6, "bush", 1.0, 2), (5, 32, "bush", 1.0, 3),
    (36, 24, "conifer", 0.9, 2),
]
GATES = {"south": (-5, 36)}                          # where the map's road layer joins the lane (10+ px inside the border)
STONES = [(-16, 20, 1.8, 2), (20, 18, 1.6, 2), (-32, 6, 1.6, 3)]     # x, y, r, gone from level


# ------------------------------------------------------------------ small drawing helpers
def _banner(pen, x, y, flag, h=4.6):
    """A pole with a pennant, from the foot (x, y) upward."""
    pen.line((x, y), (x, y - h), kit.INK, 0.5)
    pen.poly([(x, y - h), (x + 3.4, y - h + 0.9), (x, y - h + 1.9)], flag, None)


def _tower(pen, winter, x, y, w, h, top="battlement", flag=None, door=True, roof_h=None, slit=False, banner_h=4.6):
    """A stone tower, foot middle at (x, y): lit left, shaded right strip, and a battlement or a slate cone."""
    lit, dk = kit.STONE_GREY, kit.STONE_GREY_D
    x0 = x - w / 2
    pen.rect(x0, y - h, w, h, lit, None)
    pen.rect(x0 + w * 0.76, y - h, w * 0.24, h, dk, None)
    top_y = y - h
    if top == "battlement":
        cw = w + 1.4
        pen.rect(x - cw / 2, top_y - 1.8, cw, 1.8, lit if not winter else kit.SNOW_D, None)
        pen.rect(x - cw / 2 + cw * 0.76, top_y - 1.8, cw * 0.24, 1.8, dk, None)
        pen.rect(x - cw / 2, top_y - 1.8, cw, 1.8, None, kit.INK, 0.5)
        n = 3 if w < 8 else 4
        for q in range(n):
            mx = x - cw / 2 + 0.3 + (cw - 1.6) * q / (n - 1)
            c = (lit if q < n - 1 else dk) if not winter else kit.SNOW
            pen.rect(mx, top_y - 3.0, 1.3, 1.3, c, kit.INK, 0.5)
        if winter:
            pen.rect(x - cw / 2, top_y - 2.0, cw, 0.8, kit.SNOW, None)
        apex = top_y - 3.0
    else:
        rh = roof_h or w * 0.95
        cone = [(x - w / 2 - 0.8, top_y), (x + w / 2 + 0.8, top_y), (x, top_y - rh)]
        pen.poly(cone, kit.SLATE if not winter else kit.SNOW, None)
        pen.poly([(x, top_y - rh), (x + w / 2 + 0.8, top_y), (x + w * 0.1, top_y)], kit.SLATE_D if not winter else kit.SNOW_D, None)
        pen.poly(cone, None, kit.INK, 0.5)
        apex = top_y - rh
    pen.rect(x0, y - h, w, h, None, kit.INK, 0.5)
    if door and h >= 8:
        pen.rect(x - 0.9, y - 2.4, 1.8, 2.4, kit.DOOR, None)
    if slit:
        pen.rect(x - 0.5, y - h * 0.62, 1.0, 2.0, kit.DOOR, None)
        pen.rect(x + w * 0.18, y - h * 0.82, 0.8, 1.6, kit.DOOR, None)
    if flag:
        _banner(pen, x, apex, flag, banner_h)


def add_tower(p, x, y, w, h, top="battlement", flag=None, door=True, roof_h=None, slit=False):
    p.cast(x, y, w + 1)
    p.stand(y, lambda pen: _tower(pen, p.winter, x, y, w, h, top, flag, door, roof_h, slit))


def mound(p):
    """The low mound all three levels stand on: a darker rim below and to the right, a lit top."""
    x, y, w, h = MOUND
    g = p.pal["grass"]
    if p.winter:
        rim, top = kit.mix(kit.SNOW_D, (160, 172, 192), 0.35), kit.SNOW
    else:
        rim, top = kit.shade(g, 0.72), kit.shade(g, 1.06)
    p.blob(x + 1.6, y + 2.0, w + 1, h + 1, rim)
    p.blob(x, y + 0.6, w - 1.5, h - 2.5, kit.mix(rim, top, 0.55))
    p.blob(x - 0.6, y - 0.4, w - 4.5, h - 5.5, top)


# ------------------------------------------------------------------ level 2: the grey ring wall
def ring_wall(p, cx, cy, rx, ry, height=RING_H):
    """A stone ring wall in castle grey, with two corner towers and a gatehouse at the front. Like kit.wall, but
    STONE_GREY (the kit's stone wall is town stone)."""
    lit, dk = kit.STONE_GREY, kit.STONE_GREY_D
    winter = p.winter
    back = kit.ring_points(cx, cy, rx, ry, math.pi, 2 * math.pi)
    front = kit.ring_points(cx, cy, rx, ry, 0, math.pi)
    hw = height
    p.shadow(cx + rx * 0.2, cy + ry * 0.35, rx * 2.3, ry * 2.0)

    def fb(pen):
        top = [(a[0], a[1] - hw) for a in back]
        pen.poly(back + top[::-1], kit.shade(lit, 0.8), None)
        pen.lines(top, kit.INK, 0.5)
        if winter:
            pen.lines([(a[0], a[1] - hw - 0.7) for a in top], kit.SNOW, 0.8)

    def ff(pen):
        top = [(a[0], a[1] - hw) for a in front]
        pen.poly(front + top[::-1], lit, None)
        pen.poly([front[i] for i in range(0, 9)] + [top[i] for i in range(8, -1, -1)], dk, None)    # right end: in shade
        for q in range(0, len(front), 3):                      # merlons
            a = top[q]
            pen.rect(a[0] - 0.8, a[1] - 1.5, 1.6, 1.6, lit if not winter else kit.SNOW, kit.INK, 0.5)
        if winter:
            pen.lines([(a[0], a[1] - 0.4) for a in top], kit.SNOW, 1.0)
        pen.lines(top, kit.INK, 0.5)
        pen.lines(front, kit.INK, 0.5)
        for t in (0.02, 0.98):                                 # the two corner towers
            q = front[int((len(front) - 1) * t)]
            _tower(pen, winter, q[0], q[1] + 0.5, 4.8, hw + 4.5, "battlement", None, False)
        g = front[len(front) // 2]                             # the gatehouse
        _tower(pen, winter, g[0], g[1] + 0.8, 7.0, 8.2, "battlement", None, False)
        pen.rect(g[0] - 1.5, g[1] + 0.8 - 3.4, 3.0, 3.4, kit.DOOR, None)
    p.stand(cy - ry - 0.5, fb)
    p.stand(cy + ry + 0.5, ff)
    for t in (0.02, 0.98):
        q = front[int((len(front) - 1) * t)]
        p.cast(q[0], q[1], 4.8)


# ------------------------------------------------------------------ level 3: the bastion fortress
def fort_plan(a, b, da=9.0, db=7.0, dt=7.5):
    """The outline in plan (u, v) before the tilt, clockwise: four curtain walls, a pointed bastion on each corner."""
    pts = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        A = (sx * (a - da), sy * b)
        B = (sx * a, sy * (b - db))
        T = (sx * (a + dt), sy * (b + dt))
        pts += [B, T, A] if sx * sy > 0 else [A, T, B]
    return pts


def offset_poly(pts, d):
    """The polygon pulled inward by d (clockwise outline in y-down coordinates): the shifted edge lines, intersected."""
    n = len(pts)
    lines = []
    for i in range(n):
        p0, p1 = pts[i], pts[(i + 1) % n]
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln, dx / ln                         # inward normal
        lines.append(((p0[0] + nx * d, p0[1] + ny * d), (dx / ln, dy / ln)))
    out = []
    for i in range(n):
        (pa, da), (pb, db) = lines[i - 1], lines[i]
        den = da[0] * db[1] - da[1] * db[0]
        if abs(den) < 1e-6:
            out.append(pb)
            continue
        t = ((pb[0] - pa[0]) * db[1] - (pb[1] - pa[1]) * db[0]) / den
        out.append((pa[0] + da[0] * t, pa[1] + da[1] * t))
    return out


def tilt(pts, cx=CX, cy=CY):
    return [(cx + u, cy + v * kit.TILT) for u, v in pts]


def fort_wall(p, outer, inner, h):
    """Queue the fortress wall as one standing item per edge, each at the depth of its own foot: the outer face of an
    edge that looks south, the inner face of one that looks north, and always the flat top. The wall's base lies on
    the (tilted) ground, so its faces rise straight up from the outline."""
    winter = p.winter
    lit, dk = kit.STONE_GREY, kit.STONE_GREY_D
    topc = kit.shade(lit, 1.1) if not winter else kit.SNOW
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        P, Q, Pi, Qi = outer[i], outer[j], inner[i], inner[j]
        dx, dy = Q[0] - P[0], Q[1] - P[1]
        ln = math.hypot(dx, dy)
        nx, ny = dy / ln, -dx / ln                         # outward normal on screen
        up = lambda pt: (pt[0], pt[1] - h)
        if ny > 0.05:                                      # an outer face we see
            depth = (P[1] + Q[1]) / 2
            side = dk if nx > 0.3 else lit
        elif ny < -0.05:                                   # the inner face of a back wall
            depth = (Pi[1] + Qi[1]) / 2
            side = dk if -nx > 0.3 else kit.shade(lit, 0.94)
        else:
            depth = (P[1] + Q[1]) / 2
            side = None

        def fn(pen, P=P, Q=Q, Pi=Pi, Qi=Qi, ny=ny, side=side, up=up):
            if side is not None:
                if ny > 0:
                    pen.poly([P, Q, up(Q), up(P)], side, kit.INK, 0.5)
                else:
                    pen.poly([Pi, Qi, up(Qi), up(Pi)], side, kit.INK, 0.5)
            band = [up(P), up(Q), up(Qi), up(Pi)]
            pen.poly(band, topc, kit.INK, 0.5)
            if ny > -0.05:                                 # crenel marks along the outer edge of the top
                dd = math.dist(P, Q)
                for k in range(1, int(dd // 3.2)):
                    t = k * 3.2 / dd
                    a = (P[0] + (Q[0] - P[0]) * t, P[1] - h + (Q[1] - P[1]) * t)
                    b = (a[0] + (Pi[0] - P[0]) * 0.28, a[1] + (Pi[1] - P[1]) * 0.28)
                    pen.line(a, b, kit.STONE_GREY_D if not winter else kit.SNOW_D, 0.5)
            pen.line(up(P), up(Q), kit.INK, 1.0)
        p.stand(depth, fn)


def moat(p, outer):
    """Water on the ground all round the wall: a thick closed line, half of it hidden by the courtyard fill later.
    A quiet water (river mixed with the shallow sea), so it reads as water round a wall, not as a blue outline."""
    pts = outer + [outer[0]]
    w = MOAT_W * 2 + 1
    if p.winter:
        edge, fill = kit.ICE_D, kit.ICE
    else:
        fill = kit.mix(p.pal["river"], p.pal["shallow"], 0.5)
        edge = kit.mix(p.pal["river_edge"], fill, 0.5)

    def fn(pen):
        pen.lines(pts, edge, w + 1.4)
        for q in outer:
            pen.ellipse(q[0], q[1], w + 1.4, (w + 1.4) * kit.TILT, edge)
        pen.lines(pts, fill, w)
        for q in outer:
            pen.ellipse(q[0], q[1], w, w * kit.TILT, fill)
    p.over(fn, 1.0)


def draw(level, season, flag=kit.FLAG):
    p = kit.Piece(season, ground="grass", seed=3)
    winter, spring, summer = p.winter, season == "spring", season == "summer"
    plan = fort_plan(FORT_A, FORT_B)
    outer = tilt(plan)
    inner = tilt(offset_poly(plan, FORT_T))

    # ---- ground plane
    p.tufts(10 if level == 1 else 6 if level == 2 else 4, avoid=[(CX, CY, 20)])     # first: later levels cover some of them
    if level >= 3:
        moat(p, outer)
        yard = kit.ROAD if not winter else (172, 160, 140)      # the trodden yard: an overlay on whatever ground there is
        p.over(lambda pen: pen.poly(outer, yard, None), 0.45)
    mound(p)
    gate_y = CY + (RING2[1] if level >= 2 else RING1[1])
    if level == 1:
        p.road([(CX, gate_y - 1), (CX - 1, gate_y + 8), GATES["south"]], 1.4, track=True)
    elif level == 2:
        p.road([(CX, gate_y - 1), (CX - 1, gate_y + 8), GATES["south"]], 2.0)
    else:
        p.road([(CX, gate_y - 1), (CX, 22), GATES["south"]], 2.0)
        gy = CY + FORT_B * kit.TILT                        # the bridge over the moat, from the gate tower
        p.patch([(CX - 2.6, gy - 1), (CX + 2.6, gy - 1), (CX + 2.6, gy + MOAT_W + 1.8), (CX - 2.6, gy + MOAT_W + 1.8)], kit.TIMBER, kit.INK, 0.5)
        for k in range(5):
            y = gy + 0.5 + k * 1.7
            p.over(lambda pen, y=y: pen.line((CX - 2.6, y), (CX + 2.6, y), kit.TIMBER_D, 0.5), 1.0)
    p.stones([(x, y, r) for x, y, r, gone in STONES if level < gone])

    # ---- standing things
    for i, (x, y, kind, sc, gone) in enumerate(TREES):
        if level < gone:
            p.tree(x, y, sc, kind, i)

    if level == 1:
        p.wall(CX, CY, RING1[0], RING1[1], "palisade", towers=(), gate=0.5, height=3.4)
        add_tower(p, KEEP[0], KEEP[1], 6.4, 8.8, "cone", flag, door=False, roof_h=5.6)
    else:
        ring_wall(p, CX, CY, RING2[0], RING2[1])
        keep_h = 14.5
        p.cast(KEEP[0], KEEP[1], 11)
        p.stand(KEEP[1], lambda pen: _tower(pen, winter, KEEP[0], KEEP[1], 10.0, keep_h, "battlement", flag, True, slit=True, banner_h=3.2))
        if winter:                                         # the keep smokes in winter only (the kit's smoke is grey on snow)
            p.smoke(KEEP[0] + 3.6, KEEP[1] - keep_h - 3.4, always=False, foot=KEEP[1])
    if level >= 3:
        fort_wall(p, outer, inner, FORT_H)
        gy = CY + FORT_B * kit.TILT
        p.cast(CX, gy, 8)
        p.stand(gy + 0.9, lambda pen: _tower(pen, winter, CX, gy + 0.9, 8.4, 8.0, "battlement", flag, True))
    # ---- season activity (never changes the layout)
    if (spring or summer) and level >= 2:
        p.person(CX + 5, CY + RING2[1] + 7, (70, 96, 150))
    return p.finish(label="castle L%d" % level)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "castles.png")
    kit.sheet(draw, LEVELS, "Castles: levels 1-3 by season", out, NAMES)
    print("wrote", os.path.normpath(out))
