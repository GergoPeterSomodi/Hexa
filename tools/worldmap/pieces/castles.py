"""Castles, levels 1-3 (see docs/design/map/pieces/GUIDE.md, section 8).

1 watchtower (a palisade ring, one stone tower with a slate cone) - 2 castle (a grey stone ring wall with corner towers
and a gatehouse, the keep) - 3 bastion fortress (a low, thick, angular wall with four pointed bastions lying round the
castle, a moat, a gate tower; the castle of level 2 stands inside it unchanged).

All three stand on the same low mound. The banner colour is a parameter: draw(level, season, flag=kit.FLAG).
The tower of level 1 and the keep of level 2 share one foot (KEEP): the keep is the tower grown in place.

Two layouts (LAYOUT) and the mirror. Layout 0: a round castle in the middle of the hex, a four-bastion fortress.
Layout 1: a spur castle: a long mound and an elongated ring lying from the lower left to the upper right, the keep at
its upper end and the gate at the lower end; the fortress is a pentagon with five bastions round it.

python castles.py          writes docs/design/map/pieces/castles.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

LEVELS = range(1, 4)
VARIANTS = 2
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
GATES = [{"south": (-5, 36)}, {"south": (-12, 33)}]   # where the map's road layer joins the lane (10+ px inside the border)
# The layouts side by side. Layout 1 (the spur): rot turns the mound and the rings in the plan; ring1: the small palisade
# round the tower (cx, cy, a, b: half axes in the plan); ring2: the stone ring; fort: the pentagon's middle and radius.
ROT1 = -22.0
LAYOUT = [
    dict(keep=KEEP, mound=MOUND, rot=0.0, ring1=RING1, ring2=RING2, fort=None, person=(CX + 5, CY + RING2[1] + 7)),
    dict(keep=(15, -4), mound=(1, 1, 24, 10.5), rot=ROT1, ring1=(15, 0, 11, 6.5), ring2=(1, 1, 22, 10), fort=(3, 3, 29.0),
         person=(-4, 19)),
]


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
    return p.stand(y, lambda pen: _tower(pen, p.winter, x, y, w, h, top, flag, door, roof_h, slit), x=x)


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


def ell_pts(cx, cy, a, b, rot, n=48):
    """An ellipse of half axes a, b turned by rot degrees in the plan, then tilted. Unmirrored."""
    th = math.radians(rot)
    c, s = math.cos(th), math.sin(th)
    return [(cx + a * math.cos(t) * c - b * math.sin(t) * s, cy + (a * math.cos(t) * s + b * math.sin(t) * c) * kit.TILT)
            for t in (2 * math.pi * q / n for q in range(n))]


def mound_rot(p, cx, cy, a, b, rot):
    """The mound of layout 1: the same three tones as mound(), on a long ellipse turned in the plan."""
    g = p.pal["grass"]
    if p.winter:
        rim, top = kit.mix(kit.SNOW_D, (160, 172, 192), 0.35), kit.SNOW
    else:
        rim, top = kit.shade(g, 0.72), kit.shade(g, 1.06)
    mid = kit.mix(rim, top, 0.55)
    for (dx, dy, f, col) in ((1.6, 2.0, 1.0, rim), (0.0, 0.6, 0.92, mid), (-0.6, -0.4, 0.78, top)):
        pts = ell_pts(cx + dx, cy + dy, a * f + (0.5 if f == 1.0 else 0), b * f + (0.5 if f == 1.0 else 0), rot)
        p.over(lambda pen, pts=pts, col=col: pen.poly(pts, col, None), 1.0)


def ring_arcs(cx, cy, a, b, rot, n=96):
    """A ring's outline turned in the plan, as two arcs from the right end to the left end: front (through the
    bottom) and back (through the top). Unmirrored."""
    pts = ell_pts(cx, cy, a, b, rot, n)
    i = max(range(n), key=lambda q: pts[q][0])
    pts = pts[i:] + pts[:i]
    return pts[:n // 2 + 1], pts[n // 2:] + [pts[0]]


def rot_ring(p, cx, cy, a, b, rot, stone):
    """The ring wall of layout 1, turned in the plan. stone=False: a timber palisade (level 1); stone=True: the grey
    ring with two corner towers and a gatehouse (level 2). The kit moves a standing thing but cannot turn a lopsided
    ring round, so the outline is worked out unmirrored, every point is turned round for a mirrored piece and the
    whole ring is queued with x=0. Returns the gate point (unmirrored)."""
    front, back = ring_arcs(cx, cy, a, b, rot)
    m, winter = p.m, p.winter
    hw = RING_H if stone else 3.4
    lit, dk = (kit.STONE_GREY, kit.STONE_GREY_D) if stone else (kit.TIMBER, kit.TIMBER_D)
    gate = front[max(range(len(front)), key=lambda q: front[q][1])]
    X = lambda q: (q[0] * m, q[1])
    fr, bk = [X(q) for q in front], [X(q) for q in back]
    if m < 0:
        fr = fr[::-1]                                   # index 0 stays the drawn right end (its shaded side)
    full = ring_arcs(cx, cy, a + 2, b + 2, rot)
    p.shadow(cx + m * a * 0.15, cy + b * kit.TILT * 0.4, a * 2.0, b * 2.0 * kit.TILT * 1.1)
    p.claim([q for arc in full for q in arc])           # the court: no wild tree inside the ring

    def fb(pen):
        top = [(q[0], q[1] - hw) for q in bk]
        pen.poly(bk + top[::-1], kit.shade(lit, 0.8), None)
        if not stone:
            for q in bk:
                pen.line((q[0], q[1] - hw + 0.4), (q[0], q[1] - hw - 0.9), kit.shade(lit, 0.7), 0.5)
        pen.lines(top, kit.INK if stone else dk, 0.5)
        if winter and stone:
            pen.lines([(q[0], q[1] - hw - 0.7) for q in top], kit.SNOW, 0.8)

    def ff(pen):
        top = [(q[0], q[1] - hw) for q in fr]
        pen.poly(fr + top[::-1], lit, None)
        if stone:
            k = len(fr) // 5
            pen.poly(fr[:k + 1] + top[:k + 1][::-1], dk, None)      # the right end: in shade
            for q in range(0, len(fr), 3):
                t = top[q]
                pen.rect(t[0] - 0.8, t[1] - 1.5, 1.6, 1.6, lit if not winter else kit.SNOW, kit.INK, 0.5)
            if winter:
                pen.lines([(q[0], q[1] - 0.4) for q in top], kit.SNOW, 1.0)
        else:
            for q in fr:
                pen.line((q[0], q[1] - hw + 0.4), (q[0], q[1] - hw - 0.9), dk, 0.5)
            for q in range(2, len(fr), 4):
                t = fr[q]
                pen.line((t[0], t[1] - hw + 0.8), (t[0], t[1] - 0.4), dk, 0.5)
        pen.lines(top, kit.INK, 0.5)
        pen.lines(fr, kit.INK, 0.5)
        g = X(gate)
        if stone:
            for t in (0.16, 0.98):                                    # the two corner towers
                q = X(front[int((len(front) - 1) * t)])
                _tower(pen, winter, q[0], q[1] + 0.5, 4.8, hw + 4.5, "battlement", None, False)
            _tower(pen, winter, g[0], g[1] + 0.8, 7.0, 8.2, "battlement", None, False)     # the gatehouse
            pen.rect(g[0] - 1.5, g[1] + 0.8 - 3.4, 3.0, 3.4, kit.DOOR, None)
        else:
            pen.rect(g[0] - 1.6, g[1] - 3.0, 3.2, 3.0, kit.DOOR, None)
            pen.rect(g[0] - 2.4, g[1] - hw - 1.6, 4.8, 1.2, dk, None)
    p.stand(min(q[1] for q in back) - 0.5, fb, x=0)
    p.stand(max(q[1] for q in front) + 0.5, ff, x=0)
    if stone:
        for t in (0.16, 0.98):
            q = front[int((len(front) - 1) * t)]
            p.cast(q[0], q[1], 4.8)
    return gate


# ------------------------------------------------------------------ level 2: the grey ring wall
def ring_wall(p, cx, cy, rx, ry, height=RING_H):
    """A stone ring wall in castle grey, with two corner towers and a gatehouse at the front. Like kit.wall, but
    STONE_GREY (the kit's stone wall is town stone)."""
    lit, dk = kit.STONE_GREY, kit.STONE_GREY_D
    winter = p.winter
    back = kit.ring_points(cx, cy, rx, ry, math.pi, 2 * math.pi)
    front = kit.ring_points(cx, cy, rx, ry, 0, math.pi)
    hw = height
    p.shadow(cx + p.m * rx * 0.2, cy + ry * 0.35, rx * 2.3, ry * 2.0)
    p.claim(kit.ring_points(cx, cy, rx + 2, ry + 2, 0, 2 * math.pi))        # the court: no wild tree inside the ring

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
    p.stand(cy - ry - 0.5, fb, x=cx)                          # the ring is symmetric about x = cx: it stays where it is
    handle = p.stand(cy + ry + 0.5, ff, x=cx)
    for t in (0.02, 0.98):
        q = front[int((len(front) - 1) * t)]
        p.cast(q[0], q[1], 4.8)
    return handle


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


def penta_plan(R, da=8.5, dt=7.5):
    """Layout 1's outline in plan (u, v) before the tilt, clockwise: a pentagon of radius R with its point to the
    north, and a pointed bastion on each corner (da along each wall, dt out past the corner)."""
    vs = [(R * math.cos(math.radians(-90 + 72 * k)), R * math.sin(math.radians(-90 + 72 * k))) for k in range(5)]
    pts = []
    for k in range(5):
        V, Pv, Nv = vs[k], vs[k - 1], vs[(k + 1) % 5]
        du = lambda Q: ((Q[0] - V[0]) / math.dist(Q, V), (Q[1] - V[1]) / math.dist(Q, V))
        ap, an = du(Pv), du(Nv)
        ou = (V[0] / R, V[1] / R)
        pts += [(V[0] + ap[0] * da, V[1] + ap[1] * da), (V[0] + ou[0] * dt, V[1] + ou[1] * dt), (V[0] + an[0] * da, V[1] + an[1] * da)]
    return pts


def fort_wall(p, outer, inner, h, ax=CX):
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
        p.stand(depth, fn, x=ax)                           # the plan is symmetric about x = ax: edges stay joined


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


def draw(level, season, variant=0, mirror=False, flag=kit.FLAG):
    p = kit.Piece(season, ground="grass", seed=3, mirror=mirror)
    L = LAYOUT[variant]
    gates = GATES[variant]
    keep_at = L["keep"]
    winter, spring, summer = p.winter, season == "spring", season == "summer"
    if variant == 0:
        fcx, fcy = CX, CY
        plan = fort_plan(FORT_A, FORT_B)
        base_v = FORT_B                                    # the front wall of the fortress (plan v)
    else:
        fcx, fcy, fr_ = L["fort"]
        plan = penta_plan(fr_)
        base_v = fr_ * math.cos(math.radians(36))
    outer = tilt(plan, fcx, fcy)
    inner = tilt(offset_poly(plan, FORT_T), fcx, fcy)
    gy = fcy + base_v * kit.TILT                           # the fortress gate: on the middle of the front wall

    # ---- ground plane
    if level >= 3:
        moat(p, outer)
        yard = kit.ROAD if not winter else (172, 160, 140)      # the trodden yard: an overlay on whatever ground there is
        p.over(lambda pen: pen.poly(outer, yard, None), 0.45)
    if variant == 0:
        mound(p)
    else:
        mound_rot(p, *L["mound"], L["rot"])
    if variant == 0:
        gate_y = CY + (RING2[1] if level >= 2 else RING1[1])
        if level == 1:
            p.road([(CX, gate_y - 1), (CX - 1, gate_y + 8), gates["south"]], 1.4, track=True)
        elif level == 2:
            p.road([(CX, gate_y - 1), (CX - 1, gate_y + 8), gates["south"]], 2.0)
        else:
            p.road([(CX, gate_y - 1), (CX, 22), gates["south"]], 2.0)
    else:
        r1, r2 = L["ring1"], L["ring2"]
        if level == 1:
            g1 = ring_arcs(*r1, L["rot"])[0]
            g1 = max(g1, key=lambda q: q[1])
            p.road([(g1[0], g1[1] - 1), (g1[0] - 3, g1[1] + 8), (4, 20), (-4, 27), gates["south"]], 1.4, track=True)
        else:
            g2 = max(ring_arcs(*r2, L["rot"])[0], key=lambda q: q[1])
            if level == 2:
                p.road([(g2[0], g2[1] - 1), (g2[0] - 1, g2[1] + 8), (-9, 24), gates["south"]], 2.0)
            else:
                p.road([(g2[0], g2[1] - 1), (g2[0] + 3, g2[1] + 8), (fcx, gy - 1)], 2.0)
                p.road([(fcx, gy - 1), (fcx - 4, gy + 5), gates["south"]], 2.0)
    if level >= 3:                                         # the bridge over the moat, from the gate tower
        p.patch([(fcx - 2.6, gy - 1), (fcx + 2.6, gy - 1), (fcx + 2.6, gy + MOAT_W + 1.8), (fcx - 2.6, gy + MOAT_W + 1.8)], kit.TIMBER, kit.INK, 0.5)
        for k in range(5):
            y = gy + 0.5 + k * 1.7
            p.over(lambda pen, y=y: pen.line((fcx - 2.6, y), (fcx + 2.6, y), kit.TIMBER_D, 0.5), 1.0)

    # ---- standing things
    if level == 1:
        if variant == 0:
            p.wall(CX, CY, RING1[0], RING1[1], "palisade", towers=(), gate=0.5, height=3.4)
        else:
            rot_ring(p, *L["ring1"], L["rot"], False)
        add_tower(p, keep_at[0], keep_at[1], 6.4, 8.8, "cone", flag, door=False, roof_h=5.6)
    else:
        if variant == 0:
            ring_wall(p, CX, CY, RING2[0], RING2[1])
        else:
            rot_ring(p, *L["ring2"], L["rot"], True)
        keep_h = 14.5
        p.cast(keep_at[0], keep_at[1], 11)
        keep = p.stand(keep_at[1], lambda pen: _tower(pen, winter, keep_at[0], keep_at[1], 10.0, keep_h, "battlement", flag, True, slit=True, banner_h=3.2), x=keep_at[0])
        if winter:                                         # the keep smokes in winter only (the kit's smoke is grey on snow)
            p.smoke(keep_at[0] + 3.6, keep_at[1] - keep_h - 3.4, always=False, foot=keep_at[1], on=keep)
    if level >= 3:
        fort_wall(p, outer, inner, FORT_H, ax=fcx)
        p.cast(fcx, gy, 8)
        p.stand(gy + 0.9, lambda pen: _tower(pen, winter, fcx, gy + 0.9, 8.4, 8.0, "battlement", flag, True), x=fcx)
    # ---- season activity (never changes the layout)
    if (spring or summer) and level >= 2:
        p.person(L["person"][0], L["person"][1], (70, 96, 150))
    return p.finish(label="castle L%d v%d%s" % (level, variant, "m" if mirror else ""))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "design", "map", "pieces", "castles.png")
    kit.sheet(draw, LEVELS, "Castles: levels 1-3 by season", out, NAMES, wild=True)
    print("wrote", os.path.normpath(out))
    vout = os.path.join(os.path.dirname(out), "castles_variants.png")
    kit.variant_sheet(draw, LEVELS, "Castles: layout and mirror", vout, NAMES)
    print("wrote", os.path.normpath(vout))
