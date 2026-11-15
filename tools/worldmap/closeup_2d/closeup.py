"""The 2D close-up mockup of Genoa (hex radius 240): the style frame's patch with the detail of the closest zoom.

Run from the repository root, with STYLE_FRAME_LAYERS pointing at the exported layers file:
    python tools/worldmap/closeup_2d/closeup.py OUT_DIR [EMPTY_CROP.png]
Writes 2d_genoa_close.png and, when the frame's plain 4x crop is given, 2d_genoa_compare.png.
With the slope rule on (the default; see tools/worldmap/style_frame/slopes.py) the picture is written as
2d_genoa_close_slopes.png instead; STYLE_FRAME_SLOPES=0 gives the first picture again.
Set CLOSEUP_KEEP_2X=1 to also save the 2x drawing (for checking details).
Authored positions are in drawing px (2x of the 1280x720 picture).
"""
import math, os, random, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scene import *
from frame import seg_x
import paint as A
import terrain as T

pygame.init()
INK = A.INK
C_ROAD, C_ROAD_EDGE = (228, 208, 156), (128, 100, 66)
C_RIVER, C_RIVER_EDGE = (84, 156, 212), (44, 92, 140)
QUAY = (224, 210, 180)

# ---------------------------------------------------------------- Genoa: the bay, the walls, the routes
BAY = (1235, 1000, 215, 100)            # the harbour basin: centre and radii
CAPE = (985, 1047, 82, 50)              # Capo di Faro, where the lighthouse stands
POINT = (1478, 1036, 96, 56)            # the old-town point, root of the old mole
WALL = [(1003, 990), (985, 930), (1002, 860), (1055, 795), (1130, 742), (1205, 712), (1262, 700), (1325, 715), (1400, 750),
        (1470, 800), (1520, 860), (1545, 915), (1554, 985), (1550, 1046)]
WEST_GATE, EAST_GATE, CASTLE = (985, 930), (1545, 915), (1262, 700)
POLCEVERA = [(1040, -30), (1028, 70), (1022, 180), (1004, 290), (1000, 400), (990, 520), (962, 660), (915, 800), (892, 925), (876, 1000), (868, 1060)]
BISAGNO = [(1850, 300), (1800, 420), (1750, 540), (1700, 680), (1660, 800), (1646, 905), (1642, 980), (1648, 1070)]
ROAD_GIOVI = [(985, 930), (958, 890), (962, 800), (1005, 670), (1046, 540), (1070, 430), (1090, 372), (1150, 350), (1236, 338), (1252, 312),
              (1160, 296), (1082, 280), (1066, 252), (1150, 236), (1236, 222), (1250, 194), (1170, 178), (1110, 160), (1104, 132),
              (1142, 100), (1150, 40), (1160, -30)]
ROAD_WEST = [(-40, 1000), (60, 978), (190, 968), (330, 905), (480, 884), (640, 902), (780, 930), (862, 927), (924, 925), (985, 930)]
ROAD_EAST = [(1545, 915), (1614, 906), (1678, 904), (1780, 928), (1900, 962), (2040, 968), (2230, 985), (2420, 1000), (2620, 1010)]


def arc(a, off=0.0):
    """A point on the harbour ellipse (a in degrees, 270 is due north), pushed off px to the land side."""
    rad = math.radians(a)
    return (BAY[0] + (BAY[2] + off) * math.cos(rad), BAY[1] + (BAY[3] + off * 0.62) * math.sin(rad))


def arc_step(a, off, dist):
    """The angle that lies dist px further along the harbour ellipse."""
    x0, y0 = arc(a, off)
    b = a
    while b < a + 60:
        b += 0.25
        x1, y1 = arc(b, off)
        if math.hypot(x1 - x0, (y1 - y0) * 1.7) >= dist:
            break
    return b


def ell_km(kind, e):
    cx, cy = K(e[0], e[1])
    return (kind, cx, cy, e[2] / S, e[3] / (S * TILT))


def smooth(pts, n=3, step=6.0):
    return resample(chaikin(pts, n), step)


def stroke(s, pts, w, col):
    for p in pts:
        pygame.draw.circle(s, col, p, w / 2.0)


def wiggle(pts, amp, period, seed):
    out = []
    for i, p in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1.0
        m = (vnoise(i * 6.0, 0.0, period, seed) - 0.5) * 2 * amp * min(1.0, i / 12.0, (len(pts) - 1 - i) / 12.0)
        out.append((p[0] - dy / n * m, p[1] + dx / n * m))
    return out


# ---------------------------------------------------------------- ground-plane pieces
def paint_stream(cv, pts, w0, w1, seed):
    s = cv.s
    pts = wiggle(smooth(pts, 3, 5.0), 9, 60.0, seed)
    n = len(pts)
    for i, p in enumerate(pts):          # the gravel bed of a torrent
        t = i / (n - 1.0)
        if t > 0.25 and cv.land_mask.get_at((int(min(max(p[0], 0), W - 1)), int(min(max(p[1], 0), H - 1))))[3]:
            pygame.draw.circle(s, (216, 208, 172), (p[0] + 3 * math.sin(i * 0.3), p[1]), (w0 + (w1 - w0) * t) * 1.15)
    for i, p in enumerate(pts):
        t = i / (n - 1.0)
        pygame.draw.circle(s, C_RIVER_EDGE, p, (w0 + (w1 - w0) * t) / 2 + 2)
    for i, p in enumerate(pts):
        t = i / (n - 1.0)
        pygame.draw.circle(s, C_RIVER, p, (w0 + (w1 - w0) * t) / 2)
    for i in range(4, n - 2, 7):
        t = i / (n - 1.0)
        w = w0 + (w1 - w0) * t
        pygame.draw.line(s, (150, 204, 236), (pts[i][0] - w * 0.2, pts[i][1]), (pts[i + 2][0] - w * 0.2, pts[i + 2][1]), 2)
    cv.keep.add_line(pts, 20)
    cv.routes.add_line(pts, 10)
    return pts


def paint_road(cv, pts, w, wig=5, clear=0):
    s = cv.s
    pts = wiggle(smooth(pts, 2 if clear else 3, 4.0), wig, 46.0, int(pts[0][0]) % 50 + 7)
    stroke(s, pts, w + 5, C_ROAD_EDGE)
    stroke(s, pts, w, C_ROAD)
    r = random.Random(int(pts[0][1]))
    for i in range(3, len(pts) - 3, 3):      # ruts and stones
        a, b = pts[i], pts[i + 1]
        if r.random() < 0.5:
            pygame.draw.line(s, (206, 184, 134), (a[0] - 2, a[1] + 1), (b[0] - 2, b[1] + 1), 2)
        if r.random() < 0.12:
            pygame.draw.circle(s, (244, 232, 196), (a[0] + r.uniform(-3, 3), a[1] + r.uniform(-2, 2)), 1.6)
    cv.keep.add_line(pts, w + 10 + clear)
    cv.routes.add_line(pts, 12 + clear)
    return pts


FIELD_COLS = [(222, 198, 104), (196, 208, 102), (210, 180, 96), (186, 196, 120), (232, 212, 128), (168, 196, 92), (204, 190, 132)]


def field_block(cv, cx, cy, ang, cols, rows, cw, ch, seed):
    """A block of strip fields on the ground: wheat, green crops, fallow, vines and olive groves, hedged."""
    r = random.Random(seed)
    s = cv.s
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))

    def G(u, v):
        return (cx + u * ca - v * sa, cy + (u * sa + v * ca) * TILT)

    v0 = -rows * ch / 2.0
    for j in range(rows):
        u0 = -cols * cw / 2.0 + r.uniform(-8, 8)
        hh = ch * r.uniform(0.85, 1.15)
        for i in range(cols):
            ww = cw * r.uniform(0.7, 1.3)
            quad = [G(u0 + 2, v0 + 2), G(u0 + ww - 2, v0 + 2), G(u0 + ww - 2, v0 + hh - 2), G(u0 + 2, v0 + hh - 2)]
            mx, my = G(u0 + ww / 2, v0 + hh / 2)
            ua, ub = u0, u0 + ww
            u0 += ww
            if r.random() < 0.1 or not all(is_land(*K(*q), 0.03) for q in quad) or not cv.keep.clear(mx, my, min(ww, hh) * 0.55):
                continue
            kind = r.choice(("wheat", "wheat", "green", "fallow", "vine", "olive", "green"))
            col = {"wheat": FIELD_COLS[r.choice((0, 4))], "green": FIELD_COLS[r.choice((1, 5, 3))], "fallow": FIELD_COLS[r.choice((2, 6))],
                   "vine": (206, 190, 128), "olive": (188, 200, 118)}[kind]
            pygame.draw.polygon(s, col, quad)
            if kind in ("wheat", "green", "fallow"):
                along = r.random() < 0.5
                k = int((hh if along else ww) / 7)
                for q in range(1, k):
                    t = q / float(k)
                    if along:
                        a, b = G(ua + 3, v0 + hh * t), G(ub - 3, v0 + hh * t)
                    else:
                        a, b = G(ua + ww * t, v0 + 3), G(ua + ww * t, v0 + hh - 3)
                    pygame.draw.line(s, A.sh(col, 0.9 if q % 2 else 1.06), a, b, 2)
                if kind == "wheat" and r.random() < 0.5:        # sheaves
                    for q in range(3):
                        px, py = G(ua + ww * r.uniform(0.2, 0.8), v0 + hh * r.uniform(0.25, 0.8))
                        pygame.draw.polygon(s, (236, 206, 110), [(px - 3, py), (px + 3, py), (px, py - 7)])
                        pygame.draw.polygon(s, (150, 120, 60), [(px - 3, py), (px + 3, py), (px, py - 7)], 1)
            elif kind == "vine":
                k = int(hh / 8)
                for q in range(1, k):
                    a, b = G(ua + 4, v0 + hh * q / k), G(ub - 4, v0 + hh * q / k)
                    m = int(math.dist(a, b) / 7)
                    for e in range(m + 1):
                        px, py = a[0] + (b[0] - a[0]) * e / max(1, m), a[1] + (b[1] - a[1]) * e / max(1, m)
                        pygame.draw.circle(s, (88, 134, 66), (px, py), 3)
                        pygame.draw.circle(s, (128, 170, 82), (px - 1, py - 1), 1.5)
            else:
                k, m = max(2, int(hh / 22)), max(2, int(ww / 22))
                for q in range(k):
                    for e in range(m):
                        px, py = G(ua + ww * (e + 0.5) / m, v0 + hh * (q + 0.6) / k)
                        cv.add(py, (lambda a=px, b=py, d=random.Random(q * 7 + e): A.olive(cv.s, a, b, 1.25, d)))
                        cv.sh_ell(px + 5, py + 1, 16, 6)
            pygame.draw.polygon(s, (98, 138, 68), quad, 3)
            if r.random() < 0.6:
                bx, by = quad[r.randrange(4)]
                cv.add(by, (lambda a=bx, b=by, d=random.Random(i * 3 + j), t=r.randrange(3): A.bush(cv.s, a, b, 1.3, d, t)))
            cv.keep.add(mx, my, max(ww, hh) * 0.62)
            cv.routes.add(mx, my, max(ww, hh) * 0.3)
        v0 += hh


def farmstead(cv, x, y, seed):
    r = random.Random(seed)
    cv.add(y, lambda: A.house(cv.s, x, y, r, sc=1.3, kind="eaves", floors=2))
    cv.sh_box(x, y, 40, 46)
    cv.add(y + 6, lambda: A.house(cv.s, x + 36, y + 6, random.Random(seed + 1), sc=0.95, kind="gable", floors=1, wall=(206, 186, 150)))
    cv.add(y - 4, lambda: A.cypress(cv.s, x - 30, y - 4, 1.4, random.Random(seed + 2)))
    cv.keep.add(x + 10, y - 10, 46)
    cv.routes.add(x + 10, y - 10, 30)


def town(cv, cx, cy, rx, ry, n, seed, sc=1.3, walled=False, church=None, front_open=True, big=0):
    """A town or hamlet: houses packed in an ellipse, a church, paving, and a wall round the land side."""
    r = random.Random(seed)
    s = cv.s
    e = pygame.Rect(0, 0, rx * 2.1, ry * 2.1)
    e.center = (cx, cy)
    pygame.draw.ellipse(s, (212, 200, 160), e)
    pygame.draw.ellipse(s, (224, 212, 172), e.inflate(-rx * 0.5, -ry * 0.5))
    houses, tries = [], 0
    while len(houses) < n and tries < 900:
        tries += 1
        a, d = r.uniform(0, 2 * math.pi), math.sqrt(r.random()) * 0.9
        hx, hy = cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d
        if not is_land(*K(hx, hy + 6), 0.03) or not is_land(*K(hx, hy - 20), 0.03):
            continue
        if any(abs(hx - q[0]) < 30 * sc and abs(hy - q[1]) < 17 * sc for q in houses):
            continue
        if church and abs(hx - church[0]) < 50 * sc and abs(hy - church[1]) < 22 * sc:
            continue
        houses.append((hx, hy))
    for i, (hx, hy) in enumerate(houses):
        rr = random.Random(seed * 31 + i)
        if i < big:
            cv.add(hy, (lambda a=hx, b=hy, d=rr: A.palazzo(cv.s, a, b, d, sc=sc * 0.95, floors=3, arcade=False)))
            cv.sh_box(hx, hy, 34 * sc, 60 * sc)
        else:
            cv.add(hy, (lambda a=hx, b=hy, d=rr: A.house(cv.s, a, b, d, sc=sc)))
            cv.sh_box(hx, hy, 30 * sc, 44 * sc)
    if church:
        kw = dict(church[2])
        cv.add(church[1], (lambda: A.church(cv.s, church[0], church[1], random.Random(seed + 5), **kw)))
        cv.sh_box(church[0] + 20, church[1], 60 * kw.get("sc", 1), 80 * kw.get("sc", 1))
    if walled:
        m = 26
        pts = [(cx + math.cos(a) * (rx + 16), cy + math.sin(a) * (ry + 12)) for a in [math.pi * 0.96 + math.pi * 1.08 * q / m for q in range(m + 1)]]
        for q in range(m):
            a, b = pts[q], pts[q + 1]
            if is_land(*K(a[0], a[1] + 4), 0.02) and is_land(*K(b[0], b[1] + 4), 0.02):
                cv.add(max(a[1], b[1]) - 6, (lambda a=a, b=b: A.wall_run(cv.s, [a, b], 18)))
                if q % 6 == 3:
                    cv.add(a[1] - 5, (lambda a=a: A.tower(cv.s, a[0], a[1] + 2, 18, 40)))
        g = pts[m // 2]
        cv.add(g[1] - 4, lambda: A.gate(cv.s, g[0], g[1] + 3, 0.9))
    cv.sh_ell(cx + rx * 0.2, cy + 6, rx * 1.7, ry * 1.2)
    for a in range(0, 360, 30):
        cv.keep.add(cx + math.cos(math.radians(a)) * rx * 0.7, cy + math.sin(math.radians(a)) * ry * 0.7, rx * 0.55)
    cv.keep.add(cx, cy, rx * 0.7)
    cv.routes.add(cx, cy, rx * 1.7)


def nearest_shore(cv, x, y):
    return min(cv.coast, key=lambda p: (p[0] - x) ** 2 + (p[1] - y) ** 2)


def jetty(cv, x, y, length=70, w=15, along=0.0):
    """A small stone mole from the shore point nearest (x, y), straight out to sea."""
    px, py, nx, ny = nearest_shore(cv, x, y)
    nx, ny = nx + along, ny
    d = math.hypot(nx, ny)
    nx, ny = nx / d, ny / d
    a, b = (px - nx * 8, py - ny * 8), (px + nx * length, py + ny * length * TILT)
    pts = [(a[0] + (b[0] - a[0]) * t / 12.0, a[1] + (b[1] - a[1]) * t / 12.0) for t in range(13)]
    stroke(cv.s, pts, w + 5, INK)
    stroke(cv.s, pts, w, QUAY)
    stroke(cv.s, [(p[0] - 2, p[1] - 3) for p in pts[1:-1]], 3, (246, 238, 214))
    for p in pts[3::4]:
        pygame.draw.rect(cv.s, (88, 66, 54), (p[0] + 2, p[1] - 3, 4, 6))
    return b


# ---------------------------------------------------------------- Genoa
def genoa_ground(cv):
    """What lies flat: the paving, the quay round the basin, the piers and the two moles."""
    s = cv.s
    pave = [arc(a, 196) for a in range(190, 351, 4)] + [arc(a, -3) for a in range(350, 189, -4)]
    pygame.draw.polygon(s, (214, 200, 164), pave)
    pygame.draw.polygon(s, (226, 212, 176), [arc(a, 120) for a in range(196, 345, 4)] + [arc(a, 0) for a in range(344, 195, -4)])
    e = pygame.Rect(0, 0, POINT[2] * 1.75, POINT[3] * 1.7)
    e.center = (POINT[0] - 6, POINT[1] - 6)
    pygame.draw.ellipse(s, (220, 206, 170), e)
    # streets: a few darker lanes running up from the quay
    for a in (212, 232, 252, 276, 298, 318, 336):
        pygame.draw.line(s, (196, 180, 146), arc(a, 10), arc(a + 3, 186), 5)
    for off in (48, 88, 126, 163):
        pts = [arc(a, off) for a in range(198, 344, 4)]
        pygame.draw.lines(s, (198, 182, 148), False, pts, 4)
    # the quay
    outer = [arc(a, 15) for a in range(184, 357, 3)]
    inner = [arc(a, -5) for a in range(184, 357, 3)]
    pygame.draw.polygon(s, QUAY, outer + inner[::-1])
    pygame.draw.lines(s, (246, 238, 214), False, [arc(a, 9) for a in range(186, 355, 3)], 3)
    pygame.draw.lines(s, INK, False, inner, 3)
    pygame.draw.lines(s, (40, 86, 130), False, [arc(a, -9) for a in range(186, 355, 3)], 3)
    for a in range(190, 352, 7):
        x, y = arc(a, 2)
        pygame.draw.rect(s, (88, 66, 54), (x - 2, y - 5, 4, 6))
    # piers into the basin
    for a, ln in ((226, 52), (258, 62), (288, 60), (318, 50)):
        x0, y0 = arc(a, -2)
        dx, dy = BAY[0] - x0, (BAY[1] + 40) - y0
        d = math.hypot(dx, dy)
        x1, y1 = x0 + dx / d * ln, y0 + dy / d * ln
        pygame.draw.line(s, INK, (x0, y0), (x1, y1), 17)
        pygame.draw.line(s, QUAY, (x0, y0), (x1, y1), 12)
        pygame.draw.line(s, (246, 238, 214), (x0 - 3, y0), (x1 - 3, y1), 2)
        for t in (0.35, 0.7, 1.0):
            pygame.draw.rect(s, (88, 66, 54), (x0 + (x1 - x0) * t - 2, y0 + (y1 - y0) * t - 4, 4, 6))
    # the old mole from the town point, the new mole from the lighthouse cape
    for pts, w in (([(1420, 1058), (1372, 1074), (1310, 1080), (1262, 1076)], 22), ([(1052, 1070), (1090, 1084), (1136, 1086)], 20)):
        pts = smooth(pts, 2, 4.0)
        stroke(s, pts, w + 5, INK)
        stroke(s, pts, w, QUAY)
        stroke(s, [(p[0] - 2, p[1] - 4) for p in pts[2:-2]], 4, (246, 238, 214))
        for p in pts[3::9]:                    # the sea wall on the outer side, stone by stone
            pygame.draw.rect(s, (188, 174, 150), (p[0] - 4, p[1] + w * 0.22, 9, 5))
            pygame.draw.rect(s, INK, (p[0] - 4, p[1] + w * 0.22, 9, 5), 1)
    # a shipyard on the west strand: slips with two hulls in frame, and stacked timber
    for x, y in ((1052, 968), (1084, 954)):
        pygame.draw.polygon(s, (196, 178, 140), [(x - 30, y + 8), (x + 26, y - 6), (x + 32, y + 4), (x - 24, y + 18)])


def genoa_gardens(cv, wallpoly):
    """Terraced gardens and olive yards between the upper houses and the wall."""
    s = cv.s
    r = random.Random(77)
    for off in (212, 236, 262, 290, 320):
        pts = [arc(a, off) for a in range(186, 356, 2)]
        run = []
        for p in pts + [None]:
            if p and in_poly(p[0], p[1] + 10, wallpoly) and in_poly(p[0], p[1] - 14, wallpoly):
                run.append(p)
            else:
                if len(run) > 3:
                    pygame.draw.lines(s, (98, 132, 66), False, [(q[0], q[1] + 3) for q in run], 2)
                    pygame.draw.lines(s, (224, 214, 178), False, run, 2)
                    for q in run[2::3]:
                        if r.random() < 0.5:
                            cv.add(q[1] - 3, (lambda a=q[0], b=q[1] - 3, d=random.Random(int(q[0])): A.olive(cv.s, a, b, 1.1, d)))
                        elif r.random() < 0.16:
                            cv.add(q[1] - 3, (lambda a=q[0], b=q[1] - 3, d=random.Random(int(q[0])): A.cypress(cv.s, a, b, 1.15, d)))
                run = []


def genoa(cv):
    s = cv.s
    r = random.Random(1492)
    wallpoly = WALL + [(1480, 1100), (1000, 1100)]
    sc = 1.42
    marks = [(1318, 846, 60), (1118, 876, 44), (1440, 902, 44), (1212, 808, 40), (1262, 742, 60)]
    placed = []

    def free(x, y, w):
        return all(abs(x - mx) > (mw + w) / 2 or abs(y - my) > 14 for mx, my, mw in marks)

    # the Ripa: tall arcaded houses in a row along the quay
    a = 199.0
    while a < 342:
        x, y = arc(a, 24)
        w = r.uniform(30, 40)
        a = arc_step(a, 24, w * 1.3)
        if not in_poly(x, y, wallpoly) or abs(x - 1236) < 40:
            continue
        rr = random.Random(int(a * 13))
        fl = rr.choice((3, 4, 4, 5))
        cv.add(y, (lambda x=x, y=y, w=w, rr=rr, fl=fl: A.palazzo(cv.s, x, y, rr, sc=1.28, w=w, floors=fl)))
        cv.sh_box(x, y, w * 1.28, 80)
    # Palazzo San Giorgio on the quay, with its painted front
    cv.add(arc(270, 24)[1] + 1, lambda: A.palazzo(cv.s, 1236, arc(270, 24)[1] + 1, random.Random(5), sc=1.5, w=50, floors=4,
                                                 wall=(226, 150, 118), roof=A.SLATE))
    # rows of houses climbing behind
    for off, kinds in ((62, "pph"), (98, "phh"), (134, "hhp"), (168, "hhh"), (200, "hhh"), (232, "hh-")):
        a = 194.0 + (off % 5)
        while a < 348:
            x, y = arc(a, off)
            x += r.uniform(-5, 5)
            y += r.uniform(-5, 5)
            w = r.uniform(27, 36)
            a = arc_step(a, off, w * sc * 0.96)
            if not in_poly(x, y, wallpoly) or not in_poly(x, y - 34, wallpoly) or not is_land(*K(x, y + 4), 0.02) or not free(x, y, w * sc):
                continue
            k = r.choice(kinds)
            if k == "-":
                continue
            rr = random.Random(int(x * 7 + y))
            if k == "p":
                cv.add(y, (lambda x=x, y=y, w=w, rr=rr: A.palazzo(cv.s, x, y, rr, sc=1.2, w=w, floors=rr.choice((3, 3, 4)), arcade=False)))
            else:
                cv.add(y, (lambda x=x, y=y, w=w, rr=rr: A.house(cv.s, x, y, rr, sc=sc, w=w, floors=rr.choice((2, 2, 3)))))
            cv.sh_box(x, y, w * sc, 56)
            placed.append((x, y))
    # the old quarter on the point, by the mole
    for yy in (992, 1014, 1038, 1060):
        x = POINT[0] - 84 + (yy % 3) * 6
        while x < POINT[0] + 70:
            w = r.uniform(27, 35)
            d = math.hypot((x - POINT[0]) / (POINT[2] - 12), (yy - POINT[1]) / (POINT[3] - 6))
            if d < 0.93 and in_poly(x, yy, wallpoly) and is_land(*K(x, yy + 5), 0.03):
                rr = random.Random(int(x * 3 + yy))
                cv.add(yy, (lambda x=x, y=yy, w=w, rr=rr: A.house(cv.s, x, y, rr, sc=1.3, w=w, floors=rr.choice((2, 3)))))
                cv.sh_box(x, yy, w * 1.3, 50)
            x += w * 1.3
    # the cathedral of San Lorenzo: striped front, dome and bell tower
    cv.add(848, lambda: A.church(cv.s, 1318, 848, random.Random(1), sc=1.72, stripes=True, dome=True, cap="dome"))
    cv.add(877, lambda: A.church(cv.s, 1118, 877, random.Random(2), sc=1.2, side="left"))
    cv.add(903, lambda: A.church(cv.s, 1440, 903, random.Random(3), sc=1.2, stripes=True))
    cv.add(809, lambda: A.church(cv.s, 1212, 809, random.Random(4), sc=1.05, cap="dome", side="left"))
    # tower houses of the old families
    for x, y, h in ((1262, 846, 118), (1392, 872, 100), (1172, 842, 92), (1466, 962, 84)):
        cv.add(y, (lambda x=x, y=y, h=h: A.tower(cv.s, x, y, 19, h, col=(218, 182, 144))))
        cv.sh_box(x, y, 19, h)
    # the walls: up the hill to the castle and down again, a tower at every turn
    pieces = smooth(WALL, 1, 30.0)
    for a, b in zip(pieces, pieces[1:]):
        cv.add(max(a[1], b[1]) - 8, (lambda a=a, b=b: A.wall_run(cv.s, [a, b], 22)))
    cv.sh_poly([(p[0] + 4, p[1]) for p in pieces] + [(p[0] + 16, p[1] + 8) for p in pieces[::-1]])
    for i, (x, y) in enumerate(WALL):
        if (x, y) in (WEST_GATE, EAST_GATE, CASTLE):
            continue
        cv.add(y - 6, (lambda x=x, y=y: A.tower(cv.s, x, y + 3, 22, 52)))
        cv.sh_box(x, y + 3, 22, 52)
    cv.add(WEST_GATE[1] - 2, lambda: A.gate(cv.s, WEST_GATE[0], WEST_GATE[1] + 4, 1.15))
    cv.add(EAST_GATE[1] - 2, lambda: A.gate(cv.s, EAST_GATE[0], EAST_GATE[1] + 4, 1.3))

    def castle():
        x, y = CASTLE[0], CASTLE[1] + 6
        A.tower(s, x - 38, y - 2, 24, 58)
        A.tower(s, x + 38, y - 2, 24, 58)
        A.rect(s, (224, 212, 184), x - 36, y - 40, 72, 42, INK, 2)
        pygame.draw.rect(s, (182, 170, 146), (x + 10, y - 40, 26, 42))
        pygame.draw.rect(s, INK, (x - 36, y - 40, 72, 42), 2)
        for i in range(7):
            A.rect(s, (224, 212, 184), x - 36 + i * 11.2, y - 47, 6, 8, INK, 1)
        A.tower(s, x, y + 2, 34, 92)
        d = pygame.Rect(0, 0, 13, 20)
        d.midbottom = (x, y + 2)
        pygame.draw.rect(s, (62, 48, 48), d, border_top_left_radius=6, border_top_right_radius=6)
        pygame.draw.line(s, INK, (x, y - 103), (x, y - 138), 2)
        A.pennant(s, x, y - 138, d=1, n=30)

    cv.add(CASTLE[1] + 8, castle)
    cv.sh_box(CASTLE[0], CASTLE[1] + 8, 100, 90)
    # the shipyard: two hulls in frame on the slips, timber, and a treadwheel crane on the quay
    def hull_frame(x, y):
        hull = [(x - 34, y - 12), (x + 34, y - 16), (x + 24, y + 1), (x - 22, y + 4)]
        for px in (x - 20, x, x + 18):                     # the props of the slip
            pygame.draw.line(s, (96, 70, 50), (px, y + 2), (px - 5, y + 11), 2)
        pygame.draw.polygon(s, (206, 164, 108), hull)
        for t in range(1, 8):                              # the ribs, still open to the sky
            px = x - 34 + 68 * t / 8.0
            pygame.draw.line(s, (128, 90, 58), (px, y - 12 - 4 * t / 8.0), (px + 2, y + 3 - 3 * t / 8.0), 2)
        pygame.draw.line(s, (236, 204, 150), hull[0], hull[1], 2)
        pygame.draw.polygon(s, INK, hull, 2)
    cv.add(975, lambda: hull_frame(1052, 962))
    cv.add(962, lambda: hull_frame(1086, 948))

    def crane():
        x, y = arc(246, 8)
        pygame.draw.circle(s, (150, 112, 76), (x, y - 14), 11)
        pygame.draw.circle(s, INK, (x, y - 14), 11, 2)
        pygame.draw.circle(s, (104, 76, 56), (x, y - 14), 3)
        pygame.draw.line(s, (104, 76, 56), (x, y - 14), (x + 30, y - 52), 4)
        pygame.draw.line(s, INK, (x + 30, y - 52), (x + 30, y - 22), 1)
        pygame.draw.rect(s, (196, 160, 110), (x + 26, y - 22, 9, 8))
        pygame.draw.rect(s, INK, (x + 26, y - 22, 9, 8), 1)
    cv.add(arc(246, 8)[1] + 30, crane)
    # goods on the quay: bales and barrels
    for a in (214, 236, 262, 284, 300, 326):
        x, y = arc(a, 6)
        def goods(x=x, y=y, k=int(a)):
            for i in range(3):
                px = x + i * 8 - 8
                if (k + i) % 2:
                    pygame.draw.rect(s, (196, 160, 110), (px - 3, y - 7, 7, 7))
                    pygame.draw.rect(s, INK, (px - 3, y - 7, 7, 7), 1)
                else:
                    pygame.draw.ellipse(s, (150, 104, 66), (px - 3, y - 8, 7, 9))
                    pygame.draw.ellipse(s, INK, (px - 3, y - 8, 7, 9), 1)
        cv.add(y + 26, goods)
    # the Lanterna on its rock
    lx, ly = CAPE[0] - 10, CAPE[1] + 6

    def lantern():
        rr = random.Random(9)
        A.rock(s, lx - 26, ly + 12, 46, rr, col=(160, 148, 130))
        A.rock(s, lx + 24, ly + 14, 40, rr, col=(150, 140, 126))
        A.rock(s, lx, ly + 18, 60, rr, col=(170, 158, 138))
        top = A.lanterna(s, lx, ly, 1.42)
        for dx, dy in ((-34, -6), (-30, 8), (34, -6), (30, 8)):      # the beam of the light
            pygame.draw.line(s, (255, 238, 170), (lx + dx * 0.45, top + 14 + dy * 0.45), (lx + dx, top + 14 + dy), 2)
    cv.add(ly + 20, lantern)
    cv.sh_box(lx, ly + 6, 36, 190)
    # small harbour lights at the ends of the moles
    cv.add(1082, lambda: A.tower(s, 1262, 1080, 14, 34, cap="spire"))
    cv.add(1092, lambda: A.tower(s, 1136, 1090, 12, 26, cap="spire"))
    # suburbs outside the gates
    for x, y in ((930, 905), (902, 960), (1600, 935), (1596, 880), (940, 968)):
        if cv.keep.clear(x, y, 0) or True:
            rr = random.Random(int(x + y))
            cv.add(y, (lambda x=x, y=y, rr=rr: A.house(cv.s, x, y, rr, sc=1.25)))
            cv.sh_box(x, y, 40, 44)
    return wallpoly


def flock(s, x, y, seed):
    r = random.Random(seed)
    for i in range(7):
        px, py = x + r.uniform(-34, 34), y + r.uniform(-12, 12)
        pygame.draw.ellipse(s, (60, 70, 50), (px - 5, py - 1, 12, 5))
        pygame.draw.ellipse(s, (246, 242, 230), (px - 5, py - 7, 10, 7))
        pygame.draw.circle(s, (70, 60, 56), (px + (5 if i % 2 else -5), py - 5), 2)


def gulls(s):
    """Gulls over the harbour and the cliffs: two short strokes each."""
    r = random.Random(12)
    for cx, cy in ((1210, 1128), (1420, 1150), (1905, 1140), (2450, 1190), (320, 1080), (930, 1120)):
        for i in range(r.randint(2, 4)):
            x, y = cx + r.uniform(-60, 60), cy + r.uniform(-34, 34)
            w = r.uniform(6, 9)
            pygame.draw.lines(s, (252, 252, 250), False, [(x - w, y - 3), (x - w * 0.4, y - 5), (x, y), (x + w * 0.4, y - 5), (x + w, y - 3)], 2)
            pygame.draw.line(s, (90, 96, 110), (x - 1, y + 1), (x + 1, y + 1), 1)


def ships(cv):
    s = cv.s
    fleet = [
        (A.carrack, 1168, 1012, dict(sc=1.0, d=1, furled=True)),
        (A.galley, 1322, 1030, dict(sc=0.86, d=-1, sail=False)),
        (A.boat, 1126, 966, dict(sc=1.0, d=1, sail=False)),
        (A.boat, 1262, 946, dict(sc=1.0, d=-1, sail=False)),
        (A.boat, 1372, 982, dict(sc=1.05, d=-1)),
        (A.carrack, 1560, 1262, dict(sc=1.75, d=-1)),
        (A.galley, 760, 1216, dict(sc=1.3, d=1)),
        (A.carrack, 330, 1352, dict(sc=1.15, d=1, cross=False)),
        (A.carrack, 2330, 1336, dict(sc=1.3, d=-1)),
        (A.boat, 2010, 1152, dict(sc=1.3, d=1)),
        (A.boat, 2140, 1206, dict(sc=1.15, d=-1)),
        (A.boat, 1880, 1300, dict(sc=1.2, d=1)),
        (A.boat, 380, 1136, dict(sc=1.25, d=1)),
        (A.boat, 470, 1190, dict(sc=1.1, d=-1)),
        (A.boat, 1030, 1180, dict(sc=1.15, d=1)),
    ]
    for fn, x, y, kw in fleet:
        cv.add(y, (lambda fn=fn, x=x, y=y, kw=kw: fn(s, x, y, **kw)))


# ---------------------------------------------------------------- names
def plate(surf, text, pos, rank, anchor="midtop"):
    """A place name on the frame's dark rounded plate (the size stays that of the interface, it does not grow with the zoom)."""
    size = {3: 27, 2: 21, 1: 17}[rank]
    f = pygame.font.SysFont("segoeui", size, bold=True)
    txt = f.render(text, True, (250, 246, 234))
    pad_x, pad_y = (15 if rank == 3 else 11), 3
    r = pygame.Rect(0, 0, txt.get_width() + pad_x * 2, txt.get_height() + pad_y * 2 - 4)
    setattr(r, anchor, pos)
    r.clamp_ip(surf.get_rect().inflate(-8, -8))
    p = pygame.Surface(r.size, pygame.SRCALPHA)
    col = (30, 36, 56, 236) if rank >= 2 else (52, 58, 74, 220)
    pygame.draw.rect(p, col, p.get_rect(), border_radius=int(r.height / 2.4))
    if rank == 3:
        pygame.draw.rect(p, (214, 186, 110, 255), p.get_rect(), 2, border_radius=int(r.height / 2.4))
    surf.blit(p, r)
    surf.blit(txt, (r.centerx - txt.get_width() / 2, r.centery - txt.get_height() / 2 - 1))


def halo_text(surf, text, size, col, halo, pos, anchor="center", font="georgia"):
    f = pygame.font.SysFont(font, size, italic=True)
    img = f.render(text, True, col)
    r = img.get_rect(**{anchor: pos})
    if halo:
        h = f.render(text, True, halo)
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1), (-2, 0), (2, 0), (0, 2), (0, -2)):
            surf.blit(h, r.move(dx, dy))
    surf.blit(img, r)


def names(out):
    plate(out, "Genoa", (631, 286), 3, "midbottom")
    plate(out, "Savona", (92, 552), 2)
    plate(out, "Chiavari", (1128, 500), 1)
    halo_text(out, "Giovi", 21, (58, 48, 44), (244, 238, 222), (626, 52), "midleft")
    halo_text(out, "Polcevera", 15, (34, 84, 136), (206, 232, 244), (452, 372))
    halo_text(out, "Bisagno", 15, (34, 84, 136), (206, 232, 244), (892, 330))
    halo_text(out, "G u l f   o f   G e n o a", 28, (170, 212, 236), None, (640, 688))


# ---------------------------------------------------------------- the picture
def main(out_dir, empty_crop=None):
    t0 = time.time()
    if SF.SLOPES:      # the slope rule: the two authored torrents lie in their valleys too
        SF.SLOPES.add_water([[K(*p) for p in smooth(line, 3, 12.0)] for line in (POLCEVERA, BISAGNO)])
        T.TONES = SF.SLOPES.level(1.0)
    loops = build_coast([ell_km("sea", BAY), ell_km("land", CAPE), ell_km("land", POINT)])
    loops_px = [[P(*p) for p in lp] for lp in loops]
    cv = T.Canvas()
    sx, sy = P(SAVONA["x"], SAVONA["y"])
    cx, cy = P(CHIAVARI["x"], CHIAVARI["y"])
    T.paint_sea(cv, loops_px)
    T.paint_land(cv, loops_px)
    runs = T.shore_points(loops_px)

    def in_basin(x, y):
        return math.hypot((x - BAY[0]) / (BAY[2] + 16), (y - BAY[1]) / (BAY[3] + 16)) < 1.0 and y < BAY[1] + 30

    T.paint_shore(cv, runs, [(in_basin, "quay"),
                             (lambda x, y: math.hypot(x - BAY[0], (y - BAY[1]) * 1.5) < 420, "sand"),
                             (lambda x, y: math.hypot(x - sx, y - sy) < 230, "sand"),
                             (lambda x, y: math.hypot(x - cx, y - cy) < 170, "sand")])
    T.paint_waves(cv)
    ctab = {}

    def coast_y(x):
        k = int(x // 16)
        if k not in ctab:
            y = 500.0
            while y < H + 200 and land_value(*K(k * 16 + 8, y)) > 0.5:
                y += 6
            ctab[k] = y
        return ctab[k]

    # ---- the hill behind Genoa, painted flat first so that the town, its walls and the road can climb it
    wallpoly = WALL + [(1480, 1100), (1000, 1100)]
    dome = [dict(x=930, y=884, h=118, apex=False, m=300), dict(x=1085, y=884, h=214, apex=False, m=420), dict(x=1262, y=884, h=262, apex=True, m=480),
            dict(x=1425, y=884, h=214, apex=False, m=420), dict(x=1580, y=884, h=124, apex=False, m=300)]
    dome_top = T.ridge(cv, dome, 0.37, main=False, wood=0.34, pre=True,
                       terraces=lambda x, y: not in_poly(x, y, wallpoly) or y < arc(270, 200)[1] + abs(x - BAY[0]) * 0.2)
    # ---- the ground plane: streams, roads, fields, the harbour works
    pol = paint_stream(cv, POLCEVERA, 7, 15, 3)
    bis = paint_stream(cv, BISAGNO, 6, 13, 4)
    giovi = paint_road(cv, ROAD_GIOVI, 11, wig=0, clear=16)
    west = paint_road(cv, ROAD_WEST, 10)
    east = paint_road(cv, ROAD_EAST, 10)
    # towns and hamlets claim their ground before the fields do
    for x in range(960, 1600, 40):
        for y in range(700, 1090, 40):
            if in_poly(x, y, wallpoly):
                cv.keep.add(x, y, 44)
    cv.keep.add(CAPE[0], CAPE[1], 90)
    cv.routes.add(1262, 830, 330)
    cv.routes.add(1040, 860, 200)
    cv.routes.add(1480, 860, 200)
    town(cv, sx + 40, sy - 62, 150, 62, 15, 21, sc=1.3, walled=True, big=3,
         church=(sx + 50, sy - 70, dict(sc=1.3, side="right")))
    town(cv, cx - 10, cy - 34, 104, 40, 8, 22, sc=1.25, church=(cx + 6, cy - 44, dict(sc=1.1, side="left", cap="dome")))
    farms = ((330, 800), (900, 596), (1730, 880), (2440, 962), (500, 930), (1960, 742), (1325, 560), (150, 842))
    hamlets = [(1330, 410, 23, "right"), (566, 640, 24, "left"), (1808, 640, 25, "right"), (2300, 892, 26, "left"), (676, 968, 27, "right"),
               (1420, 420, 28, "left"), (2050, 600, 29, "right")]
    # cart tracks from every hamlet and farm to the nearest road
    main_roads = giovi[::4] + west[::4] + east[::4]
    for hx, hy in [(h[0], h[1] + 20) for h in hamlets] + [(f[0], f[1] + 4) for f in farms]:
        q = min(main_roads, key=lambda p: (p[0] - hx) ** 2 + (p[1] - hy) ** 2)
        d = math.dist(q, (hx, hy))
        if 50 < d < 460:
            mid = ((hx + q[0]) / 2 + (q[1] - hy) * 0.16, (hy + q[1]) / 2 - (q[0] - hx) * 0.16)
            track = wiggle(smooth([(hx, hy), mid, q], 3, 2.0), 4, 80.0, int(hx) % 40 + 3)
            stroke(cv.s, track, 7, (156, 134, 88))
            stroke(cv.s, track, 4.5, (224, 206, 158))
            cv.keep.add_line(track, 9)
    for hx, hy, sd, side in hamlets:
        town(cv, hx, hy, 74, 30, 5, sd, sc=1.2, church=(hx + (10 if side == "right" else -6), hy - 8, dict(sc=0.95, side=side)))
    blocks = [(420, 968, -8, 4, 2, 62, 40), (560, 716, 6, 4, 2, 60, 40), (700, 620, -10, 2, 2, 60, 42), (836, 700, 14, 2, 4, 54, 42),
              (880, 520, 16, 2, 3, 56, 44), (1130, 470, 14, 2, 2, 56, 40), (1380, 490, -6, 2, 2, 60, 42), (1740, 760, 12, 2, 4, 56, 42),
              (1900, 660, -8, 3, 2, 58, 40), (1790, 990, 6, 3, 2, 60, 38), (1960, 1040, 4, 3, 1, 62, 42), (2210, 940, -6, 3, 2, 60, 40),
              (2400, 900, 8, 3, 2, 60, 40), (300, 860, -14, 3, 2, 60, 42), (90, 900, 8, 3, 2, 60, 40), (2060, 690, 8, 3, 2, 56, 40),
              (1420, 500, 6, 3, 2, 56, 38), (760, 880, -4, 3, 1, 60, 38), (640, 1010, -3, 3, 1, 56, 34), (2160, 1060, 3, 2, 1, 60, 36)]
    for i, b in enumerate(blocks):
        field_block(cv, b[0], b[1], b[2], b[3], b[4], b[5] * 1.4, b[6] * 1.35, seed=100 + i)
    for i, (x, y) in enumerate(farms):
        if cv.keep.clear(x, y, 20):
            farmstead(cv, x, y, 300 + i)
    genoa_ground(cv)
    genoa_gardens(cv, wallpoly)
    # ---- standing things
    T.data_relief(cv, skip=lambda x, y: math.hypot((x - 1258) / 430.0, (y - 800) / 300.0) < 1.0, drop=0.3)
    genoa(cv)
    ships(cv)
    # two stone bridges on the coast road, and the pass
    for road, water in ((west, pol), (east, bis)):
        hit = None
        for i in range(0, len(road) - 2, 2):
            for j in range(0, len(water) - 2, 2):
                hit = hit or seg_x(road[i], road[i + 2], water[j], water[j + 2])
        if hit:
            cv.add(hit[1] + 14, (lambda q=hit: A.bridge(cv.s, (q[0] - 36, q[1] + 1), (q[0] + 36, q[1] - 1), 3, 9)))
            cv.keep.add(hit[0], hit[1], 50)
    px, py = 1142, 100

    def the_pass():
        A.cairn(cv.s, px - 34, py + 8, 1.15)
        A.house(cv.s, px + 44, py + 4, random.Random(8), sc=1.35, kind="eaves", floors=2, wall=(222, 214, 198), roof=(128, 116, 110), w=40)
        A.tower(cv.s, px + 84, py + 2, 15, 50, cap="spire", roof=(128, 116, 110))
    cv.add(py + 10, the_pass)
    cv.keep.add(px + 30, py, 80)
    # travellers on the roads
    for i, d in ((int(len(giovi) * 0.33), -1), (int(len(giovi) * 0.62), 1)):
        mx, my = giovi[i]
        cv.add(my + 2, (lambda a=mx, b=my, d=d: A.mule_train(cv.s, a, b + 2, d)))
    # a watchtower on the eastern headland, a monastery hill above the Bisagno
    for wx, wy in ((1876, 1070), (2470, 1090), (560, 990)):
        px_, py_, nx, ny = nearest_shore(cv, wx, wy)
        tx, ty = px_ - nx * 26, py_ - ny * 26 - 4
        cv.add(ty, (lambda a=tx, b=ty: A.tower(cv.s, a, b, 20, 46, col=(214, 196, 164))))
        cv.sh_box(tx, ty, 20, 46)
        cv.keep.add(tx, ty, 40)
    # fishing strands: jetties and boats pulled up on the sand
    for (tx, ty, ln) in ((sx + 190, sy - 10, 84), (cx + 20, cy + 30, 70)):
        end = jetty(cv, tx, ty, ln)
        cv.add(end[1] + 16, (lambda e=end: A.boat(cv.s, e[0] - 34, e[1] + 14, 1.15, 1)))
    for (tx, ty) in ((cx - 70, cy + 20), (cx - 30, cy + 26), (sx + 20, sy + 40), (700, 1010), (1700, 1040)):
        qx, qy, nx, ny = nearest_shore(cv, tx, ty)
        cv.add(qy, (lambda a=qx - nx * 6, b=qy - ny * 6 + 4, k=int(tx): A.boat(cv.s, a, b, 0.9, 1 if k % 2 else -1, sail=False,
                                                                           col=((60, 96, 140), (176, 60, 50), (236, 226, 200))[k % 3])))
    def on_dome(x, y):
        ty = T.sil_y(dome_top, x)
        if ty is None or y > 890:
            return False
        if y > ty + 24:
            return (int(x * 7 + y * 3) % 10) < 7           # a few trees stand on the slope
        return y > ty - 110                                   # none close behind the crest

    T.grow_trees(cv, coast_y, veto=on_dome)
    for i, (fx, fy) in enumerate(((1290, 150), (700, 760), (2150, 800), (240, 720))):     # sheep on the pastures
        if cv.keep.clear(fx, fy, 10):
            cv.add(fy + 12, (lambda a=fx, b=fy, k=i: flock(cv.s, a, b, k)))
    cv.flush_shadows()
    cv.flush_objects()
    gulls(cv.s)
    out = pygame.transform.smoothscale(cv.s, (OUT_W, OUT_H))
    names(out)
    pygame.draw.rect(out, (40, 36, 40), out.get_rect(), 1)
    os.makedirs(out_dir, exist_ok=True)
    stem = "2d_genoa_close_slopes" if SF.SLOPES else "2d_genoa_close"
    path = os.path.join(out_dir, stem + ".png")
    pygame.image.save(out, path)
    if os.environ.get("CLOSEUP_KEEP_2X"):
        pygame.image.save(cv.s, os.path.join(out_dir, stem + "_2x.png"))
    print("rendered in %.1f s" % (time.time() - t0))
    if empty_crop:
        compare(out, pygame.image.load(empty_crop), os.path.join(out_dir, "2d_genoa_compare.png"))
    return cv, out


def compare(new, old, path):
    pw, ph, head, gap = 960, 540, 54, 12
    img = pygame.Surface((pw * 2 + gap * 3, ph + head + gap))
    img.fill((30, 34, 48))
    f = pygame.font.SysFont("segoeui", 22, bold=True)
    for i, (pic, title) in enumerate(((old, "Before: the style frame enlarged 4x (hex radius 240), sharp but empty"),
                                      (new, "After: 2D close-up, with detail that only appears at this zoom"))):
        x = gap + i * (pw + gap)
        img.blit(pygame.transform.smoothscale(pic.convert(24) if pic.get_bitsize() != 24 else pic, (pw, ph)), (x, head))
        img.blit(f.render(title, True, (244, 238, 222)), (x + 4, 12))
    pygame.image.save(img, path)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
