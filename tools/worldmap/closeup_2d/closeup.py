"""The 2D close-up mockup of Genoa (hex radius 240): the style frame's patch with the detail of the closest zoom.

The rule: one city, one hex, drawn inside it. Genoa stands in the middle of its own hex (8,13 of the normal map), its
harbour is the corner of sea inside that hex, and the coast, the torrent and the roads are the normal map's lines
(scene.FRAME_ROADS, scene.FRAME_STREAMS); the roads meet at the hex centre behind the town, as they do on the map.
The picture itself is stage 3 of the growing map (growth.py, stages.py).

Run from the repository root, with STYLE_FRAME_LAYERS pointing at the exported layers file:
    python tools/worldmap/closeup_2d/closeup.py OUT_DIR [EMPTY_CROP.png]
Writes 2d_genoa_close.png and, when the frame's plain 4x crop is given, 2d_genoa_compare.png.
With the slope rule on (the default; see tools/worldmap/style_frame/slopes.py) the picture is written as
2d_genoa_close_slopes.png instead; STYLE_FRAME_SLOPES=0 gives the first picture again.
Set CLOSEUP_KEEP_2X=1 to also save the 2x drawing (for checking details).

The growing map (the same view at several moments in time, see growth.py and stages.py):
    python tools/worldmap/closeup_2d/closeup.py OUT_DIR --stage 1|2|3|4a|4b|all
Without --stage the picture is stage 3.
Authored positions are in drawing px (2x of the 1280x720 picture).
"""
import math, os, random, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scene import *
from frame import seg_x
import paint as A
import terrain as T
import stages as ST

pygame.init()
INK = A.INK
C_ROAD, C_ROAD_EDGE = (228, 208, 156), (128, 100, 66)
C_RIVER, C_RIVER_EDGE = (84, 156, 212), (44, 92, 140)
QUAY = (224, 210, 180)

# ---------------------------------------------------------------- Genoa: the bay, the walls, the routes
GENOA_HEX = (8, 13)
BAY = (884, 1030, 165, 64)              # the harbour basin: centre and radii
CAPE = (704, 1002, 32, 20)              # the rock at the root of the new mole, where the lighthouse stands
POINT = (1066, 1000, 40, 20)            # the old-town point, root of the old mole
WALL = [(698, 1005), (684, 968), (694, 912), (734, 858), (784, 818), (836, 792), (912, 775), (966, 790), (1020, 820), (1070, 860),
        (1100, 908), (1112, 955), (1108, 985)]
WEST_GATE, NORTH_GATE, EAST_GATE, CASTLE = (684, 968), (836, 792), (1112, 955), (912, 775)
WALL_FOOT = [(1080, 1100), (730, 1100)]                # closes the wall polygon across the basin
DOME_BASE = 925                         # the foot of the town hill
JUNCTION = (850, 700)                   # where the roads meet: the hex centre, behind the town's north gate
# The lines of the normal map. The torrent is the map's stream on the border of Genoa's and Chiavari's hexes; the
# roads follow the map's roads and end at the junction (the map draws its Genoa on the hex border, see the notes).
BISAGNO = [(1290, 440), (1296, 484)] + [p for p in FRAME_STREAMS[0]]
ROAD_WEST = [(286, 912), (340, 862), (396, 795), (531, 684), (640, 655), (713, 651), (790, 672), (850, 700)]
ROAD_EAST = [(850, 700), (912, 694), (1000, 696), (1080, 740), (1150, 790), (1229, 832), (1310, 815), (1399, 776), (1539, 671),
             (1640, 668), (1719, 698), (1840, 700), (1990, 712), (2131, 723), (2300, 728), (2620, 725)]
ROAD_GIOVI = [(850, 700), (905, 640), (980, 590), (1080, 520), (1170, 440), (1205, 300), (1172, 160), (1148, 84), (1122, -30)]
ROAD_SPUR = [(1719, 698), (1744, 800), (1732, 900), (1716, 962)]         # from the centre of Chiavari's hex down to the village
ROAD_GATE = [(850, 700), (846, 748), (836, 792)]
COAST_MODS = (("sea", BAY), ("land", CAPE), ("land", POINT),
              ("sea", (240, 1090, 84, 78)),          # Savona's cove: the sea comes up to the town inside its hex
              ("sea", (1715, 1086, 82, 40)))          # Chiavari's cove


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


def paint_road(cv, pts, w, wig=5, clear=0, style=None, keep_w=None):
    """style (growing map): "track" (a mule track), "cart" (a cart road), None (a road) or "highway" (paved).
    keep_w is the width that trees and fields keep clear, so that it can stay the same while the road grows."""
    s = cv.s
    pts = wiggle(smooth(pts, 2 if clear else 3, 4.0), wig, 46.0, int(pts[0][0]) % 50 + 7)
    if style is not None:
        paint_road_style(s, pts, w, style)
        kw = keep_w or w
        cv.keep.add_line(pts, kw + 10 + clear)
        cv.routes.add_line(pts, 12 + clear)
        return pts
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


def paint_road_style(s, pts, w, style):
    r = random.Random(int(pts[0][1]))
    if style == "track":            # a mule track: a thin worn line, broken where the grass has taken it back
        for i, p in enumerate(pts):
            if (i // 7) % 5 != 4:
                pygame.draw.circle(s, (150, 132, 92), p, w / 2.0 + 1.5)
        for i, p in enumerate(pts):
            if (i // 7) % 5 != 4:
                pygame.draw.circle(s, (208, 190, 144), p, w / 2.0)
        return
    if style == "cart":             # a cart road: two ruts in the earth
        stroke(s, pts, w + 4, (140, 114, 76))
        stroke(s, pts, w, (216, 196, 148))
        for i in range(2, len(pts) - 3, 2):
            a, b = pts[i], pts[i + 1]
            pygame.draw.line(s, (188, 166, 120), (a[0] - 2, a[1] + 1), (b[0] - 2, b[1] + 1), 2)
            if r.random() < 0.5:
                pygame.draw.line(s, (188, 166, 120), (a[0] + 3, a[1] - 1), (b[0] + 3, b[1] - 1), 1)
        return
    # a highway: wide, paved pale, kerb stones on both sides
    stroke(s, pts, w + 6, (112, 92, 70))
    stroke(s, pts, w, (238, 226, 190))
    for i in range(2, len(pts) - 2, 3):
        a, b = pts[i - 1], pts[i + 1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / n, dx / n
        for sd in (-1, 1):
            cx, cy = pts[i][0] + nx * sd * (w / 2.0 - 1), pts[i][1] + ny * sd * (w / 2.0 - 1)
            pygame.draw.circle(s, (250, 244, 224) if i % 2 else (206, 192, 160), (cx, cy), 2)
        if i % 2:
            pygame.draw.line(s, (214, 198, 160), (pts[i][0] - 2, pts[i][1]), (pts[i][0] + 2, pts[i][1]), 2)


FIELD_COLS = [(222, 198, 104), (196, 208, 102), (210, 180, 96), (186, 196, 120), (232, 212, 128), (168, 196, 92), (204, 190, 132)]


FIELD_MIX = ("wheat", "wheat", "green", "fallow", "vine", "olive", "green")


def field_block(cv, cx, cy, ang, cols, rows, cw, ch, seed, mix=None, hedge=True, hx=None):
    """A block of strip fields on the ground: wheat, green crops, fallow, vines and olive groves, hedged.
    mix (growing map): the crops to draw from; the parcels then keep their shape whatever grows on them.
    hedge: True (hedged), False (open strips with a thin balk) or "trees" (hedges with trees at the corners).
    hx: the hex the block belongs to; a parcel that would touch the border is left out."""
    r = random.Random(seed)
    s = cv.s
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))

    def G(u, v):
        return (cx + u * ca - v * sa, cy + (u * sa + v * ca) * TILT)

    v0 = -rows * ch / 2.0
    rgeo = r
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
            if hx is not None and not all(in_hex(q[0], q[1], hx, 0.8) for q in quad):
                continue
            if mix is not None:
                if not cv.sites.clear(mx, my, min(ww, hh) * 0.55):
                    continue
                r = random.Random(seed * 131 + j * 17 + i)      # the dice of this parcel
            kind = r.choice(FIELD_MIX if mix is None else mix)
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
            if hedge:
                pygame.draw.polygon(s, (98, 138, 68), quad, 3)
            else:
                pygame.draw.polygon(s, A.sh(col, 0.8), quad, 1)
            if r.random() < 0.6 and hedge:
                bx, by = quad[r.randrange(4)]
                cv.add(by, (lambda a=bx, b=by, d=random.Random(i * 3 + j), t=r.randrange(3): A.bush(cv.s, a, b, 1.3, d, t)))
            if hedge == "trees":
                for qi in (0, 2):
                    if r.random() < 0.55:
                        bx, by = quad[qi]
                        cv.add(by, (lambda a=bx, b=by, d=random.Random(i * 5 + j + qi), t=r.randrange(3): A.broadleaf(cv.s, a, b, 1.05, d, t)))
            cv.keep.add(mx, my, max(ww, hh) * 0.62)
            cv.routes.add(mx, my, max(ww, hh) * 0.3)
            if mix is not None:
                r = rgeo
        v0 += hh


def farmstead(cv, x, y, seed):
    r = random.Random(seed)
    cv.add(y, lambda: A.house(cv.s, x, y, r, sc=1.3, kind="eaves", floors=2))
    cv.sh_box(x, y, 40, 46)
    cv.add(y + 6, lambda: A.house(cv.s, x + 36, y + 6, random.Random(seed + 1), sc=0.95, kind="gable", floors=1, wall=(206, 186, 150)))
    cv.add(y - 4, lambda: A.cypress(cv.s, x - 30, y - 4, 1.4, random.Random(seed + 2)))
    cv.keep.add(x + 10, y - 10, 46)
    cv.routes.add(x + 10, y - 10, 30)


def town(cv, cx, cy, rx, ry, n, seed, sc=1.3, walled=False, church=None, front_open=True, big=0,
         church_built=True, wall_frac=1.0, scaffold=False, flags=False, paved=True, pave_k=1.0, hx=None):
    """A town or hamlet: houses packed in an ellipse, a church, paving, and a wall round the land side.
    Growing map: church_built=False keeps the church plot empty, wall_frac is the share of the wall that stands
    (built from the west), scaffold marks the stretch in work, flags puts garrison flags on the wall towers."""
    r = random.Random(seed)
    s = cv.s
    e = pygame.Rect(0, 0, rx * 2.1 * pave_k, ry * 2.1 * pave_k)
    e.center = (cx, cy)
    if paved:
        pygame.draw.ellipse(s, (212, 200, 160), e)
        pygame.draw.ellipse(s, (224, 212, 172), e.inflate(-rx * 0.5, -ry * 0.5))
    else:           # trodden earth round a few houses
        pygame.draw.ellipse(s, (190, 196, 124), e.inflate(-rx * 0.3, -ry * 0.3))
        pygame.draw.ellipse(s, (204, 200, 138), e.inflate(-rx * 0.9, -ry * 0.9))
    houses, tries = [], 0
    while len(houses) < n and tries < 900:
        tries += 1
        a, d = r.uniform(0, 2 * math.pi), math.sqrt(r.random()) * 0.9
        hx_, hy = cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d
        if not is_land(*K(hx_, hy + 6), 0.03) or not is_land(*K(hx_, hy - 20), 0.03):
            continue
        if hx is not None and not (in_hex(hx_ - 22 * sc, hy + 4, hx, 0.7) and in_hex(hx_ + 22 * sc, hy + 4, hx, 0.7)):
            continue
        if any(abs(hx_ - q[0]) < 30 * sc and abs(hy - q[1]) < 17 * sc for q in houses):
            continue
        if church and abs(hx_ - church[0]) < 50 * sc and abs(hy - church[1]) < 22 * sc:
            continue
        houses.append((hx_, hy))
    for i, (hx_, hy) in enumerate(houses):
        rr = random.Random(seed * 31 + i)
        if i < big:
            cv.add(hy, (lambda a=hx_, b=hy, d=rr: A.palazzo(cv.s, a, b, d, sc=sc * 0.95, floors=3, arcade=False)))
            cv.sh_box(hx_, hy, 34 * sc, 60 * sc)
        else:
            cv.add(hy, (lambda a=hx_, b=hy, d=rr: A.house(cv.s, a, b, d, sc=sc)))
            cv.sh_box(hx_, hy, 30 * sc, 44 * sc)
    if church and church_built:
        kw = dict(church[2])
        cv.add(church[1], (lambda: A.church(cv.s, church[0], church[1], random.Random(seed + 5), **kw)))
        cv.sh_box(church[0] + 20, church[1], 60 * kw.get("sc", 1), 80 * kw.get("sc", 1))
    if walled:
        m = 26
        pts = [(cx + math.cos(a) * (rx + 16), cy + math.sin(a) * (ry + 12)) for a in [math.pi * 0.96 + math.pi * 1.08 * q / m for q in range(m + 1)]]
        built = int(round(m * wall_frac))
        for q in range(m):
            a, b = pts[q], pts[q + 1]
            if q >= built:
                if scaffold and q < built + 5 and is_land(*K(a[0], a[1] + 4), 0.02) and is_land(*K(b[0], b[1] + 4), 0.02):
                    lo = 17 - (q - built + 1) * 3               # the wall going up: lower course by course
                    cv.add(max(a[1], b[1]) - 6, (lambda a=a, b=b, lo=lo: A.wall_run(cv.s, [a, b], lo, teeth=False)))
                    cv.add(max(a[1], b[1]) - 5, (lambda a=a, b=b: A.scaffold(cv.s, a, b, 32)))
                    if q == built + 4:
                        cv.add(b[1] + 6, (lambda b=b: A.stone_heap(cv.s, b[0] + 16, b[1] + 8)))
                continue
            if is_land(*K(a[0], a[1] + 4), 0.02) and is_land(*K(b[0], b[1] + 4), 0.02):
                cv.add(max(a[1], b[1]) - 6, (lambda a=a, b=b: A.wall_run(cv.s, [a, b], 18)))
                if q % 6 == 3:
                    cv.add(a[1] - 5, (lambda a=a: A.tower(cv.s, a[0], a[1] + 2, 18, 40)))
                    if flags:
                        cv.add(a[1] - 4.5, (lambda a=a: A.flag(cv.s, a[0], a[1] - 50, 20)))
        g = pts[m // 2]
        if built > m // 2:
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
# What Genoa has today (about 1600). The growing map passes other values (stages.py); the layout never changes.
GENOA_NOW = ST.GENOA_1600


def genoa_ground(cv, g=None):
    """What lies flat: the paving, the quay round the basin, the piers and the two moles."""
    s = cv.s
    g = g or GENOA_NOW
    q0, q1 = g["quay"]

    def edge(a, off):         # where there is no quay yet the paving stops short of the strand
        return arc(a, off if q0 <= a <= q1 else 17)

    # paving and lanes are laid inside the wall; a grown town also paves a strip outside it, where the suburbs stand
    lay = pygame.Surface((W, H), pygame.SRCALPHA)
    pave = [arc(a, 196) for a in range(190, 351, 4)] + [edge(a, -3) for a in range(350, 189, -4)]
    pygame.draw.polygon(lay, (214, 200, 164, 255), pave)
    pygame.draw.polygon(lay, (226, 212, 176, 255), [arc(a, 120) for a in range(196, 345, 4)] + [edge(a, 0) for a in range(344, 195, -4)])
    e = pygame.Rect(0, 0, POINT[2] * 2.2, POINT[3] * 2.0)
    e.center = (POINT[0], POINT[1] - 8)
    pygame.draw.ellipse(lay, (220, 206, 170, 255), e)
    # streets: a few darker lanes running up from the quay
    for a in (212, 232, 252, 276, 298, 318, 336):
        pygame.draw.line(lay, (196, 180, 146, 255), arc(a, 10 if q0 <= a <= q1 else 22), arc(a + 3, 186), 5)
    for off in (48, 88, 126, 163):
        pts = [arc(a, off) for a in range(198, 344, 4)]
        pygame.draw.lines(lay, (198, 182, 148, 255), False, pts, 4)
    m = pygame.Surface((W, H), pygame.SRCALPHA)
    pygame.draw.polygon(m, (255, 255, 255, 255), WALL + WALL_FOOT)
    if not g.get("pave_in_wall"):
        for gate_ in (WEST_GATE, EAST_GATE):
            pygame.draw.ellipse(m, (255, 255, 255, 255), (gate_[0] - 52, gate_[1] - 44, 104, 76))
    lay.blit(m, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
    s.blit(lay, (0, 0))
    # the quay
    outer = [arc(a, 15) for a in range(q0, q1, 3)]
    inner = [arc(a, -5) for a in range(q0, q1, 3)]
    pygame.draw.polygon(s, QUAY, outer + inner[::-1])
    pygame.draw.lines(s, (246, 238, 214), False, [arc(a, 9) for a in range(q0 + 2, q1 - 2, 3)], 3)
    pygame.draw.lines(s, INK, False, inner, 3)
    pygame.draw.lines(s, (40, 86, 130), False, [arc(a, -9) for a in range(q0 + 2, q1 - 2, 3)], 3)
    for a in range(q0 + 6, q1 - 5, 7):
        x, y = arc(a, 2)
        pygame.draw.rect(s, (88, 66, 54), (x - 2, y - 5, 4, 6))
    # piers into the basin
    for a, ln in g["piers"]:
        x0, y0 = arc(a, -2)
        dx, dy = BAY[0] - x0, (BAY[1] + 24) - y0
        d = math.hypot(dx, dy)
        x1, y1 = x0 + dx / d * ln, y0 + dy / d * ln
        pygame.draw.line(s, INK, (x0, y0), (x1, y1), 15)
        pygame.draw.line(s, QUAY, (x0, y0), (x1, y1), 10)
        pygame.draw.line(s, (246, 238, 214), (x0 - 3, y0), (x1 - 3, y1), 2)
        for t in (0.35, 0.7, 1.0):
            pygame.draw.rect(s, (88, 66, 54), (x0 + (x1 - x0) * t - 2, y0 + (y1 - y0) * t - 4, 4, 6))
    # the old mole from the town point, the new mole from the lighthouse cape
    for pts, w in g["moles"]:
        pts = smooth(pts, 2, 4.0)
        stroke(s, pts, w + 5, INK)
        stroke(s, pts, w, QUAY)
        stroke(s, [(p[0] - 2, p[1] - 4) for p in pts[2:-2]], 4, (246, 238, 214))
        for p in pts[3::9]:                    # the sea wall on the outer side, stone by stone
            pygame.draw.rect(s, (188, 174, 150), (p[0] - 4, p[1] + w * 0.22, 9, 5))
            pygame.draw.rect(s, INK, (p[0] - 4, p[1] + w * 0.22, 9, 5), 1)
    # a shipyard on the west strand: slips with two hulls in frame, and stacked timber
    for x, y in g["slips"]:
        pygame.draw.polygon(s, (196, 178, 140), [(x - 30, y + 8), (x + 26, y - 6), (x + 32, y + 4), (x - 24, y + 18)])


def genoa_gardens(cv, wallpoly, offs=(212, 236, 262, 290, 320)):
    """Terraced gardens and olive yards between the upper houses and the wall."""
    s = cv.s
    r = random.Random(77)
    for off in offs:
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


def genoa(cv, g=None):
    s = cv.s
    g = g or GENOA_NOW
    r = random.Random(1492)
    wallpoly = WALL + WALL_FOOT
    sc = 1.36
    marks = [(950, 900, 60), (790, 925, 44), (1046, 946, 44), (866, 866, 40), (CASTLE[0], CASTLE[1] + 36, 60)]
    placed = []

    def free(x, y, w):
        return all(abs(x - mx) > (mw + w) / 2 or abs(y - my) > 14 for mx, my, mw in marks)

    # the Ripa: tall arcaded houses in a row along the quay
    a = 199.0
    while a < 342:
        x, y = arc(a, 24)
        w = r.uniform(30, 40)
        a = arc_step(a, 24, w * 1.3)
        if not in_poly(x, y, wallpoly) or abs(x - BAY[0]) < 40:
            continue
        rr = random.Random(int(a * 13))
        fl = rr.choice((3, 4, 4, 5))
        cv.add(y, (lambda x=x, y=y, w=w, rr=rr, fl=fl: A.palazzo(cv.s, x, y, rr, sc=1.28, w=w, floors=fl)))
        cv.sh_box(x, y, w * 1.28, 80)
    # Palazzo San Giorgio on the quay, with its painted front
    cv.add(arc(270, 24)[1] + 1, lambda: A.palazzo(cv.s, BAY[0], arc(270, 24)[1] + 1, random.Random(5), sc=1.5, w=50, floors=4,
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
            if off > g["rows"]:        # not built yet: the plot stays garden
                continue
            if k == "p":
                cv.add(y, (lambda x=x, y=y, w=w, rr=rr: A.palazzo(cv.s, x, y, rr, sc=1.2, w=w, floors=rr.choice((3, 3, 4)), arcade=False)))
            else:
                cv.add(y, (lambda x=x, y=y, w=w, rr=rr: A.house(cv.s, x, y, rr, sc=sc, w=w, floors=rr.choice((2, 2, 3)))))
            cv.sh_box(x, y, w * sc, 56)
            placed.append((x, y))
    # the old quarter on the point, by the mole
    for yy in (972, 992):
        x = POINT[0] - 36 + (yy % 3) * 6
        while x < POINT[0] + 40:
            w = r.uniform(27, 33)
            if in_poly(x, yy, wallpoly) and is_land(*K(x, yy + 5), 0.03) and in_hex(x + 20, yy + 6, GENOA_HEX, 0.7):
                rr = random.Random(int(x * 3 + yy))
                cv.add(yy, (lambda x=x, y=yy, w=w, rr=rr: A.house(cv.s, x, y, rr, sc=1.25, w=w, floors=rr.choice((2, 3)))))
                cv.sh_box(x, yy, w * 1.25, 50)
            x += w * 1.25
    # the cathedral of San Lorenzo: striped front, dome and bell tower
    cv.add(902, lambda: A.church(cv.s, 950, 902, random.Random(1), sc=1.6, stripes=True, dome=True, cap="dome"))
    if g["churches"] > 1:
        cv.add(926, lambda: A.church(cv.s, 790, 926, random.Random(2), sc=1.15, side="left"))
    if g["churches"] > 2:
        cv.add(947, lambda: A.church(cv.s, 1046, 947, random.Random(3), sc=1.15, stripes=True))
    if g["churches"] > 3:
        cv.add(867, lambda: A.church(cv.s, 866, 867, random.Random(4), sc=1.0, cap="dome", side="left"))
    # tower houses of the old families
    for x, y, h in ((904, 898, 104), (1006, 918, 88), (832, 896, 82), (1076, 968, 72)):
        cv.add(y, (lambda x=x, y=y, h=h: A.tower(cv.s, x, y, 19, h, col=(218, 182, 144))))
        cv.sh_box(x, y, 19, h)
    # the walls: up the hill to the castle and down again, a tower at every turn
    pieces = smooth(WALL, 1, 30.0)
    for a, b in zip(pieces, pieces[1:]):
        cv.add(max(a[1], b[1]) - 8, (lambda a=a, b=b: A.wall_run(cv.s, [a, b], 22)))
    cv.sh_poly([(p[0] + 4, p[1]) for p in pieces] + [(p[0] + 16, p[1] + 8) for p in pieces[::-1]])
    for i, (x, y) in enumerate(WALL):
        if (x, y) in (WEST_GATE, NORTH_GATE, EAST_GATE, CASTLE):
            continue
        cv.add(y - 6, (lambda x=x, y=y: A.tower(cv.s, x, y + 3, 22, 52)))
        cv.sh_box(x, y + 3, 22, 52)
    cv.add(WEST_GATE[1] - 2, lambda: A.gate(cv.s, WEST_GATE[0], WEST_GATE[1] + 4, 1.15))
    cv.add(EAST_GATE[1] - 2, lambda: A.gate(cv.s, EAST_GATE[0], EAST_GATE[1] + 4, 1.15))
    cv.add(NORTH_GATE[1] - 2, lambda: A.gate(cv.s, NORTH_GATE[0], NORTH_GATE[1] + 4, 1.2))

    def castle():
        x, y = CASTLE[0] + 6, CASTLE[1] + 6
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

    if g["castle"]:
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
    for hx_, hy_, hk_ in g["hulls"]:
        cv.add(hk_, (lambda a=hx_, b=hy_: hull_frame(a, b)))

    def crane():
        x, y = arc(246, 8)
        pygame.draw.circle(s, (150, 112, 76), (x, y - 14), 11)
        pygame.draw.circle(s, INK, (x, y - 14), 11, 2)
        pygame.draw.circle(s, (104, 76, 56), (x, y - 14), 3)
        pygame.draw.line(s, (104, 76, 56), (x, y - 14), (x + 30, y - 52), 4)
        pygame.draw.line(s, INK, (x + 30, y - 52), (x + 30, y - 22), 1)
        pygame.draw.rect(s, (196, 160, 110), (x + 26, y - 22, 9, 8))
        pygame.draw.rect(s, INK, (x + 26, y - 22, 9, 8), 1)
    if g["crane"]:
        cv.add(arc(246, 8)[1] + 30, crane)
    # goods on the quay: bales and barrels
    for a in g["goods"]:
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
    lx, ly = CAPE[0] - 4, CAPE[1] + 2

    def lantern():
        rr = random.Random(9)
        A.rock(s, lx - 16, ly + 8, 30, rr, col=(160, 148, 130))
        A.rock(s, lx + 14, ly + 9, 26, rr, col=(150, 140, 126))
        A.rock(s, lx, ly + 12, 40, rr, col=(170, 158, 138))
        top = A.lanterna(s, lx, ly, 1.2)
        for dx, dy in ((-34, -6), (-30, 8), (34, -6), (30, 8)):      # the beam of the light
            pygame.draw.line(s, (255, 238, 170), (lx + dx * 0.45, top + 14 + dy * 0.45), (lx + dx, top + 14 + dy), 2)
    if g["lanterna"]:
        cv.add(ly + 20, lantern)
        cv.sh_box(lx, ly + 6, 32, 160)
    # small harbour lights at the ends of the moles
    for tx_, ty_, tw_, th_, tk_ in g["lights"]:
        cv.add(tk_, (lambda a=tx_, b=ty_, c=tw_, d=th_: A.tower(s, a, b, c, d, cap="spire")))
    # suburbs outside the gates
    for x, y in g["suburbs"]:
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
    for cx, cy in ((884, 1150), (1080, 1120), (1715, 1150), (2450, 1190), (320, 1150), (640, 1100)):
        for i in range(r.randint(2, 4)):
            x, y = cx + r.uniform(-60, 60), cy + r.uniform(-34, 34)
            w = r.uniform(6, 9)
            pygame.draw.lines(s, (252, 252, 250), False, [(x - w, y - 3), (x - w * 0.4, y - 5), (x, y), (x + w * 0.4, y - 5), (x + w, y - 3)], 2)
            pygame.draw.line(s, (90, 96, 110), (x - 1, y + 1), (x + 1, y + 1), 1)


def ships(cv, fleet=None):
    s = cv.s
    fleet = fleet or [({"carrack": A.carrack, "galley": A.galley, "boat": A.boat}[k], x, y, kw) for k, x, y, kw in ST.FLEET_1600]
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
    plate(out, "Genoa", (442, 306), 3, "midbottom")
    plate(out, "Savona", (118, 398), 2, "midbottom")
    plate(out, "Chiavari", (930, 472), 1, "midleft")
    halo_text(out, "Giovi", 21, (58, 48, 44), (244, 238, 222), (640, 44), "midleft")
    halo_text(out, "Bisagno", 15, (34, 84, 136), (206, 232, 244), (704, 442))
    halo_text(out, "G u l f   o f   G e n o a", 28, (170, 212, 236), None, (640, 688))


# ---------------------------------------------------------------- the picture
def main(out_dir, empty_crop=None):
    """Today's picture is stage 3 of the growing map; there is one layout, in stages.py."""
    import growth
    t0 = time.time()
    out, big = growth.render("3")
    os.makedirs(out_dir, exist_ok=True)
    stem = "2d_genoa_close_slopes" if SF.SLOPES else "2d_genoa_close"
    pygame.image.save(out, os.path.join(out_dir, stem + ".png"))
    if os.environ.get("CLOSEUP_KEEP_2X"):
        pygame.image.save(big, os.path.join(out_dir, stem + "_2x.png"))
    print("rendered in %.1f s" % (time.time() - t0))
    if empty_crop:
        compare(out, pygame.image.load(empty_crop), os.path.join(out_dir, "2d_genoa_compare.png"))
    return out


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
    if "--stage" in sys.argv:
        import growth
        growth.run(sys.argv[1], sys.argv[sys.argv.index("--stage") + 1])
    else:
        main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
