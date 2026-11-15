"""The growing map mockup: the 2D close-up of Genoa drawn at several moments in time.

    python tools/worldmap/closeup_2d/closeup.py OUT_DIR --stage 1|2|3|4a|4b|all
    python tools/worldmap/closeup_2d/growth.py OUT_DIR            (all five panels, the contact sheet and the zoom strips)

What stands in each stage is data (stages.py). The land is the same in every stage: the coast, the ground tones, the
torrents, the hills and ranges (their places and silhouettes), the town sites and the road lines. To keep it so:
  - the hills are placed once, from the layout of stage 3 (they keep off its roads, fields and towns), and that set
    is used for every stage;
  - trees, slope woods and field parcels have fixed places and their own dice, so a stage only adds or removes them;
  - later sites are reserved: fields keep off a hamlet that is not built yet.
Positions are in drawing px (2x of the 1280x720 picture), as in closeup.py.
"""
import math, os, random, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import closeup as C
from closeup import *
import stages as ST

SHIP = {"carrack": A.carrack, "galley": A.galley, "boat": A.boat}
GENOA_ZONE = (1258, 800, 430.0, 300.0)       # the hill and town of Genoa: no data hills, no rule-placed fields
_ready = []


class FrozenGrid:
    """The reference routes: every stage asks the same grid where a hill may stand, and adds nothing to it."""
    def __init__(self, grid):
        self.grid = grid

    def add(self, *a, **k):
        pass

    def add_line(self, *a, **k):
        pass

    def clear(self, *a, **k):
        return self.grid.clear(*a, **k)


def setup():
    if not _ready:
        if SF.SLOPES:      # the slope rule: the two authored torrents lie in their valleys too
            SF.SLOPES.add_water([[K(*p) for p in smooth(line, 3, 12.0)] for line in (C.POLCEVERA, C.BISAGNO)])
            T.TONES = SF.SLOPES.level(1.0)
        loops = build_coast([ell_km("sea", C.BAY), ell_km("land", C.CAPE), ell_km("land", C.POINT)])
        _ready.append([[P(*p) for p in lp] for lp in loops])
    return _ready[0]


def bay_angle(x, y):
    return math.degrees(math.atan2((y - C.BAY[1]) / C.BAY[3], (x - C.BAY[0]) / C.BAY[2])) % 360.0


def in_basin(x, y):
    return math.hypot((x - C.BAY[0]) / (C.BAY[2] + 16), (y - C.BAY[1]) / (C.BAY[3] + 16)) < 1.0 and y < C.BAY[1] + 30


def in_genoa(x, y, k=1.0):
    return math.hypot((x - GENOA_ZONE[0]) / (GENOA_ZONE[2] * k), (y - GENOA_ZONE[1]) / (GENOA_ZONE[3] * k)) < 1.0


def hsh(*v):
    """A fixed number in [0, 1) for a site: the same in every stage and every run."""
    n = 2166136261
    for q in v:
        n = ((n ^ (int(q) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    n ^= n >> 15
    n = (n * 2246822519) & 0xFFFFFFFF
    n ^= n >> 13
    return (n % 100003) / 100003.0


# ---------------------------------------------------------------- pieces placed by rule
def shore_run(cv, x0, x1, y0, y1, step=10):
    """The shore between x0 and x1 as a left-to-right line of points (drawing px)."""
    pts = sorted((p[0], p[1]) for p in cv.coast if x0 <= p[0] <= x1 and y0 <= p[1] <= y1)
    out = []
    for p in pts:
        if not out or p[0] - out[-1][0] >= step:
            out.append(p)
    return [(p[0], (out[max(0, i - 1)][1] + p[1] + out[min(len(out) - 1, i + 1)][1]) / 3.0) for i, p in enumerate(out)]


def quay_strip(cv, run, w=15):
    """A stone quay along a stretch of shore."""
    if len(run) < 3:
        return
    s = cv.s
    pts = smooth([(x, y - 3) for x, y in run], 2, 4.0)
    stroke(s, pts, w + 5, INK)
    stroke(s, pts, w, C.QUAY)
    stroke(s, [(p[0], p[1] - 4) for p in pts[2:-2]], 3, (246, 238, 214))
    for p in pts[4::9]:
        pygame.draw.rect(s, (88, 66, 54), (p[0] - 2, p[1] + 1, 4, 6))
    cv.keep.add_line(pts, w + 8)


def port_works(cv, x0, x1, y0, y1, seed, n_wh=3, mole=None, light=True):
    """A town harbour: a quay along the strand, warehouses behind it and a mole with a harbour light."""
    run = shore_run(cv, x0, x1, y0, y1)
    quay_strip(cv, run)
    r = random.Random(seed)
    for i in range(n_wh):
        if len(run) < 4:
            break
        px, py = run[int((len(run) - 1) * (i + 0.6) / (n_wh + 0.2))]
        wx, wy, ww = px, py - 22, r.choice((40, 46, 52))
        if cv.keep.clear(wx, wy - 4, -24):
            cv.add(wy, (lambda a=wx, b=wy, c=ww, d=random.Random(seed * 7 + i): A.warehouse(cv.s, a, b, d, w=c, sc=1.0)))
            cv.sh_box(wx, wy, ww, 34)
            cv.keep.add(wx, wy - 8, ww * 0.6)
    if mole:
        end = C.jetty(cv, mole[0], mole[1], mole[2], 19)
        if light:
            cv.add(end[1] + 4, (lambda e=end: A.tower(cv.s, e[0], e[1] + 3, 12, 26, cap="spire")))
        return end
    return None


def auto_blocks(cv, st, hills, streams):
    """Field blocks placed by rule: grain goes to the valley floors and the low ground, vines to the low sunny hills.
    A block needs free land clear of towns, roads, hills and reserved sites; the best sites are taken first."""
    spec = st["auto_blocks"]
    if not spec:
        return
    cands = []
    for gy in range(360, 1090, 104):
        for gx in range(70, W - 40, 150):
            x = gx + (hsh(gx, gy, 1) - 0.5) * 70
            y = gy + (hsh(gx, gy, 2) - 0.5) * 44
            if in_genoa(x, y, 1.05):
                continue
            if not all(is_land(*K(x + dx, y + dy), 0.06) for dx in (-95, 0, 95) for dy in (-48, 48)):
                continue
            if any(abs(x - hx) < hh * 1.5 + 80 and hy - hh * 1.05 - 40 < y < hy + 50 for hx, hy, hh in hills):
                continue
            if not cv.keep.clear(x, y, 40) or not cv.sites.clear(x, y, 60):
                continue
            kx, ky = K(x, y)
            m = FIELDS.at(FIELDS.height, kx, ky)
            ds = min(math.hypot(x - p[0], y - p[1]) for line in streams for p in line[::6])
            if spec["kind"] == "grain":
                score = -m / 900.0 + FIELDS.at(FIELDS.farm, kx, ky) * 0.6 + max(0.0, 1.0 - ds / 260.0) * 0.9 + hsh(gx, gy, 3) * 0.15
            else:
                score = -abs(m - 430.0) / 700.0 + (y / H) * 0.9 - max(0.0, 1.0 - ds / 120.0) * 0.4 + hsh(gx, gy, 3) * 0.15
            cands.append((score, x, y, gx, gy))
    cands.sort(reverse=True)
    for i, (score, x, y, gx, gy) in enumerate(cands[:spec["n"]]):
        ang = (hsh(gx, gy, 4) - 0.5) * 26
        cols, rows = (3, 2) if hsh(gx, gy, 5) < 0.6 else (2, 3)
        C.field_block(cv, x, y, ang, cols, rows, 58 * 1.4, 40 * 1.35, seed=500 + gx * 7 + gy, mix=spec["mix"], hedge=spec["hedge"])


def stream_side(cv, line, frac, off=34):
    """A site beside a stream, frac of the way down it; returns (x, y, side) or None when the ground is taken."""
    i = int((len(line) - 1) * frac)
    for j in list(range(i, min(len(line), i + 60), 6)) + list(range(i, max(0, i - 60), -6)):
        for side in (1, -1):
            x, y = line[j][0] + side * off, line[j][1]
            if cv.keep.clear(x, y - 6, -6) and cv.sites.clear(x, y, 20) and is_land(*K(x, y), 0.05):
                return x, y, -side
    return None


# ---------------------------------------------------------------- Genoa's extra works
def genoa_extras(cv, g, east_road):
    s = cv.s
    for a in g.get("strand_boats", ()):               # no quay yet: boats pulled up on the strand
        x, y = arc(a, 7)
        cv.add(y + 2, (lambda x=x, y=y, k=int(a): A.boat(cv.s, x, y + 3, 0.9, 1 if k % 2 else -1, sail=False,
                                                         col=((60, 96, 140), (176, 60, 50), (236, 226, 200))[k % 3])))
    if g.get("beacon"):                               # the old light tower on the cape
        lx, ly = C.CAPE[0] - 10, C.CAPE[1] + 6

        def old_light():
            rr = random.Random(9)
            A.rock(s, lx - 26, ly + 12, 46, rr, col=(160, 148, 130))
            A.rock(s, lx + 24, ly + 14, 40, rr, col=(150, 140, 126))
            A.rock(s, lx, ly + 18, 60, rr, col=(170, 158, 138))
            A.beacon(s, lx, ly + 2, 1.3)
        cv.add(ly + 20, old_light)
        cv.sh_box(lx, ly + 6, 26, 90)
    for x, y, w in g.get("mole_warehouses", ()):
        cv.add(y, (lambda x=x, y=y, w=w: A.warehouse(cv.s, x, y, random.Random(x), w=w, sc=0.9)))
    for x, y in g.get("yard_timber", ()):
        cv.add(y, (lambda x=x, y=y: A.timber_stack(cv.s, x, y, 1.1)))
    if g.get("crane2"):
        def crane():
            x, y = arc(304, 8)
            pygame.draw.circle(s, (150, 112, 76), (x, y - 14), 11)
            pygame.draw.circle(s, INK, (x, y - 14), 11, 2)
            pygame.draw.circle(s, (104, 76, 56), (x, y - 14), 3)
            pygame.draw.line(s, (104, 76, 56), (x, y - 14), (x - 30, y - 52), 4)
            pygame.draw.line(s, INK, (x - 30, y - 52), (x - 30, y - 22), 1)
            pygame.draw.rect(s, (196, 160, 110), (x - 35, y - 22, 9, 8))
            pygame.draw.rect(s, INK, (x - 35, y - 22, 9, 8), 1)
        cv.add(arc(304, 8)[1] + 30, crane)
    if g.get("fort"):                                 # the bastion fortress on the crest above the town
        fx, fy = C.CASTLE[0], C.CASTLE[1] - 22
        fy -= 10
        cv.add(fy + 30, lambda: A.bastion_fort(s, fx, fy, 156, 60, h=22, n=5))
        cv.add(fy + 31, lambda: A.castle(s, fx, fy + 14, sc=0.8))
        cv.sh_poly([(fx - 150, fy + 34), (fx + 160, fy + 34), (fx + 230, fy + 74), (fx - 80, fy + 74)])
        for ang in (-90, -18, 198):                   # flags on the three bastions that show behind the keep
            tx, ty = fx + math.cos(math.radians(ang)) * 156 * 0.9, fy + math.sin(math.radians(ang)) * 60 * 0.9 - 22
            cv.add(fy + 32, (lambda a=tx, b=ty: A.flag(cv.s, a, b, 24)))
        cv.keep.add(fx, fy, 170)
    if g.get("flags"):
        for i, (x, y) in enumerate(C.WALL):
            if (x, y) not in (C.WEST_GATE, C.EAST_GATE, C.CASTLE) and i % 2 == 1:
                cv.add(y - 5.5, (lambda x=x, y=y: A.flag(cv.s, x, y - 62, 22)))


def east_quay(cv):
    """The long quay of the great port: the strand east of the old town, built up to the Bisagno, with warehouses."""
    run = shore_run(cv, 1548, 1632, 1000, 1110, 8)
    quay_strip(cv, run, 17)
    for i, t in enumerate((0.18, 0.62)):
        if len(run) > 3:
            px, py = run[int((len(run) - 1) * t)]
            cv.add(py - 20, (lambda a=px + 6, b=py - 20, k=i: A.warehouse(cv.s, a, b, random.Random(40 + k), w=42, sc=1.0)))
            cv.sh_box(px + 6, py - 20, 42, 34)
            cv.keep.add(px + 6, py - 30, 34)
    if run:
        end = C.jetty(cv, run[len(run) // 2][0], run[len(run) // 2][1] + 6, 46, 15)
        cv.add(end[1] + 16, (lambda e=end: A.boat(cv.s, e[0] + 30, e[1] + 8, 1.0, -1)))


# ---------------------------------------------------------------- one stage
def compose(st, ref=None, upto_relief=False):
    """Paints one stage and returns the canvas. ref is the canvas of the reference layout (stage 3): its routes decide
    where hills stand, its hills tell the rule-placed fields where not to go."""
    loops_px = setup()
    g = st["genoa"]
    T.FARM_GAIN, T.WOOD_GAIN, T.SUN_COL = st["farm_gain"], st["wood_gain"], st["sun"]
    cv = T.Canvas()
    if ref is not None:
        cv.routes = FrozenGrid(ref.routes)
    sx, sy = P(SAVONA["x"], SAVONA["y"])
    cx, cy = P(CHIAVARI["x"], CHIAVARI["y"])
    T.paint_sea(cv, loops_px)
    T.paint_land(cv, loops_px)
    T.FARM_GAIN, T.WOOD_GAIN, T.SUN_COL = 1.0, 1.0, (176, 198, 100)
    runs = T.shore_points(loops_px)
    q0, q1 = g["quay"]
    T.paint_shore(cv, runs, [(lambda x, y: in_basin(x, y) and not (q0 - 3 <= bay_angle(x, y) <= q1 + 3), "sand"),
                             (in_basin, "quay"),
                             (lambda x, y: math.hypot(x - C.BAY[0], (y - C.BAY[1]) * 1.5) < 420, "sand"),
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

    # ---- the hill behind Genoa
    wallpoly = C.WALL + [(1480, 1100), (1000, 1100)]
    dome = [dict(x=930, y=884, h=118, apex=False, m=300), dict(x=1085, y=884, h=214, apex=False, m=420), dict(x=1262, y=884, h=262, apex=True, m=480),
            dict(x=1425, y=884, h=214, apex=False, m=420), dict(x=1580, y=884, h=124, apex=False, m=300)]
    dome_st = dict(st["dome"], clear=0.0,
                   where=lambda x, y: not in_poly(x, y, wallpoly) or y < arc(270, 200)[1] + abs(x - C.BAY[0]) * 0.2)
    dome_top = T.ridge(cv, dome, 0.37, main=False, wood=0.34, pre=True, st=dome_st)
    cv.hills = []
    # ---- the ground plane: streams, roads, fields, the harbour works
    pol = C.paint_stream(cv, C.POLCEVERA, 7, 15, 3)
    bis = C.paint_stream(cv, C.BISAGNO, 6, 13, 4)
    gs, gw = st["road_giovi"]
    cs, cw = st["road_coast"]
    giovi = C.paint_road(cv, C.ROAD_GIOVI, gw, wig=0, clear=16, style=gs, keep_w=11) if gs else C.paint_road(cv, C.ROAD_GIOVI, gw, wig=0, clear=16)
    west = C.paint_road(cv, C.ROAD_WEST, cw, style=cs, keep_w=10) if cs else C.paint_road(cv, C.ROAD_WEST, cw)
    east = C.paint_road(cv, C.ROAD_EAST, cw, style=cs, keep_w=10) if cs else C.paint_road(cv, C.ROAD_EAST, cw)
    roads = dict(giovi=giovi, west=west, east=east)
    for x in range(960, 1600, 40):
        for y in range(700, 1090, 40):
            if in_poly(x, y, wallpoly):
                cv.keep.add(x, y, 44)
    cv.keep.add(C.CAPE[0], C.CAPE[1], 90)
    cv.routes.add(1262, 830, 330)
    cv.routes.add(1040, 860, 200)
    cv.routes.add(1480, 860, 200)
    # Savona and Chiavari
    sv, ch = st["savona"], st["chiavari"]
    C.town(cv, sx + 40, sy - 62, 150, 62, sv["n"], 21, sc=1.3, walled=sv["walled"], big=sv["big"],
           church=(sx + 50, sy - 70, dict(sc=1.3, side="right")), church_built=sv["church"], wall_frac=sv.get("wall_frac", 1.0),
           scaffold=sv.get("scaffold", False), flags=sv.get("flags", False), paved=sv["paved"], pave_k=sv.get("pave_k", 1.0))
    C.town(cv, cx - 10, cy - 34, 104, 40, ch["n"], 22, sc=1.25, big=ch["big"], paved=ch["paved"],
           church=(cx + 6, cy - 44, dict(sc=1.1, side="left", cap="dome")), church_built=ch["church"])
    # hamlets: the site is fixed, the level grows (1 a few houses, 2 a village with its church, 3 a big village)
    levels = st["hamlets"]
    built = [(h, levels[i]) for i, h in enumerate(ST.HAMLETS) if levels.get(i)]
    for i, (hx, hy, sd, side) in enumerate(ST.HAMLETS):
        if not levels.get(i):
            cv.sites.add(hx, hy, 72)
    farms = [f for i, f in enumerate(ST.FARMS) if i in st["farms"]]
    for i, f in enumerate(ST.FARMS):
        if i not in st["farms"]:
            cv.sites.add(f[0] + 10, f[1] - 10, 30)
    main_roads = giovi[::4] + west[::4] + east[::4]
    for (hx, hy), wide in [((h[0], h[1] + 20), lv > 1) for h, lv in built] + [((f[0], f[1] + 4), False) for f in farms]:
        q = min(main_roads, key=lambda p: (p[0] - hx) ** 2 + (p[1] - hy) ** 2)
        d = math.dist(q, (hx, hy))
        if 50 < d < 460:
            mid = ((hx + q[0]) / 2 + (q[1] - hy) * 0.16, (hy + q[1]) / 2 - (q[0] - hx) * 0.16)
            track = wiggle(smooth([(hx, hy), mid, q], 3, 2.0), 4, 80.0, int(hx) % 40 + 3)
            stroke(cv.s, track, 7 if wide else 5.5, (156, 134, 88))
            stroke(cv.s, track, 4.5 if wide else 3, (224, 206, 158))
            cv.keep.add_line(track, 9)
    for (hx, hy, sd, side), lv in built:
        church = (hx + (10 if side == "right" else -6), hy - 8, dict(sc=0.95, side=side))
        if lv == 1:
            C.town(cv, hx, hy, 74, 30, 3, sd, sc=1.2, church=church, church_built=False, paved=False)
        elif lv == 2:
            C.town(cv, hx, hy, 74, 30, 5, sd, sc=1.2, church=church)
        else:
            C.town(cv, hx, hy, 88, 35, 9, sd, sc=1.2, church=church, big=1)
    for i, b in enumerate(ST.BLOCKS):
        mix = st["blocks"].get(i)
        if mix is None:
            continue
        if mix is ST.STRIPS and not st["hedge"]:      # open strip fields: narrow parcels, no hedges
            C.field_block(cv, b[0], b[1], b[2], b[3] * 2, b[4], b[5] * 0.7, b[6] * 1.35, seed=100 + i, mix=mix, hedge=False)
        else:
            C.field_block(cv, b[0], b[1], b[2], b[3], b[4], b[5] * 1.4, b[6] * 1.35, seed=100 + i, mix=mix,
                          hedge=st["hedge"] if mix is not ST.STRIPS else True)
    if ref is not None:
        auto_blocks(cv, st, ref.hills, (pol, bis))
    for i, (x, y) in enumerate(ST.FARMS):
        if i in st["farms"] and cv.keep.clear(x, y, 20):
            C.farmstead(cv, x, y, 300 + i)
    C.genoa_ground(cv, g)
    if g.get("east_quay"):
        east_quay(cv)
    C.genoa_gardens(cv, wallpoly, g["gardens"])
    # crossings on the coast road: a ford, a timber bridge or a stone bridge
    hits = {}
    for name, road, water in (("pol", west, pol), ("bis", east, bis)):
        hit = None
        for i in range(0, len(road) - 2, 2):
            for j in range(0, len(water) - 2, 2):
                hit = hit or seg_x(road[i], road[i + 2], water[j], water[j + 2])
        hits[name] = hit
        if hit and st["crossings"][name] == "ford":
            A.ford(cv.s, hit[0], hit[1], 30)
    # ---- standing things
    low = dict(st["ridge_low"])
    high = dict(st["ridge"])
    near_pts = [(h[0], h[1]) for h, lv in built] + [(sx + 40, sy - 62), (cx - 10, cy - 34), (1262, 860)] + list(farms)

    if high.get("terr"):
        high["where"] = lambda x, y: y > 230        # the far crest keeps its woods

    def ridge_st(grp):
        m = sum(p["m"] for p in grp) / len(grp)
        return low if grp[0]["kind"] == "spur" and m < 900 else high

    def hill_st(bx, by, h, coastal, sd):
        farmed = coastal and sd < 0.75
        if st["hill_near_only"]:
            farmed = farmed and min(math.hypot(bx - p[0], by - p[1]) for p in near_pts) < 420
        lines = st["hill_lines"] if farmed else 0
        if not lines and st["hill_lines_inland"] and (coastal or by > 520):
            lines = st["hill_lines_inland"]
        return dict(lines=lines, crop=st["hill_crop"], scrub=st["hill_scrub"] and coastal and not lines)

    T.data_relief(cv, skip=lambda x, y: in_genoa(x, y), drop=0.3, st=dict(ridge=ridge_st, hill=hill_st))
    if upto_relief:
        return cv
    C.genoa(cv, g)
    genoa_extras(cv, g, east)
    C.ships(cv, [(SHIP[k], x, y, kw) for k, x, y, kw in st["fleet"]])
    for name, hit in hits.items():
        kind = st["crossings"][name]
        if not hit or kind == "ford":
            continue
        if kind == "timber":
            cv.add(hit[1] + 14, (lambda q=hit: A.timber_bridge(cv.s, (q[0] - 36, q[1] + 1), (q[0] + 36, q[1] - 1), 8)))
        else:
            cv.add(hit[1] + 14, (lambda q=hit: A.bridge(cv.s, (q[0] - 36, q[1] + 1), (q[0] + 36, q[1] - 1), 3, 9)))
        cv.keep.add(hit[0], hit[1], 50)
    # the pass
    px, py = 1142, 100
    kind = st["pass_"]

    def the_pass():
        A.cairn(cv.s, px - 34, py + 8, 1.15)
        if kind == "hut":
            A.house(cv.s, px + 40, py + 4, random.Random(8), sc=1.05, kind="gable", floors=1, wall=(206, 196, 176), roof=(128, 116, 110), w=30)
        elif kind in ("hospice", "inn"):
            A.house(cv.s, px + 44, py + 4, random.Random(8), sc=1.35, kind="eaves", floors=2, wall=(222, 214, 198), roof=(128, 116, 110), w=40)
            A.tower(cv.s, px + 84, py + 2, 15, 50, cap="spire", roof=(128, 116, 110))
            if kind == "inn":      # the highway brings an inn, a stable and a toll house
                A.house(cv.s, px + 126, py + 8, random.Random(18), sc=1.25, kind="eaves", floors=2, wall=(234, 200, 150), w=38)
                A.house(cv.s, px - 84, py + 2, random.Random(19), sc=1.05, kind="gable", floors=1, wall=(214, 200, 170), roof=(150, 110, 84), w=34)
                A.cart(cv.s, px + 86, py + 22, 1)
        elif kind == "castle":
            A.castle(cv.s, px + 70, py + 8, sc=0.7)
    cv.add(py + 10, the_pass)
    cv.keep.add(px + 30, py, 80)
    if kind == "inn":
        cv.keep.add(px + 126, py, 40)
        cv.keep.add(px - 84, py, 36)
    if kind == "castle":
        cv.keep.add(px + 70, py - 10, 70)
        cv.sh_box(px + 70, py + 8, 80, 70)
    # travellers on the roads
    for name, frac, what, d in st["travellers"]:
        mx, my = roads[name][int(len(roads[name]) * frac)]
        if what == "cart":
            cv.add(my + 2, (lambda a=mx, b=my, d=d: A.cart(cv.s, a, b + 3, d)))
        else:
            cv.add(my + 2, (lambda a=mx, b=my, d=d, n=2 if what == "mule2" else 3: A.mule_train(cv.s, a, b + 2, d, n)))
    if st["road_giovi"][0] == "highway":
        for frac in (0.12, 0.42, 0.7, 0.9):
            mx, my = giovi[int(len(giovi) * frac)]
            cv.add(my, (lambda a=mx + 13, b=my + 2: A.milestone(cv.s, a, b)))
    # coast watchtowers
    for i, (wx, wy) in enumerate(ST.TOWERS):
        px_, py_, nx, ny = C.nearest_shore(cv, wx, wy)
        tx, ty = px_ - nx * 26, py_ - ny * 26 - 4
        if i in st["towers"]:
            cv.add(ty, (lambda a=tx, b=ty: A.tower(cv.s, a, b, 20, 46, col=(214, 196, 164))))
            cv.sh_box(tx, ty, 20, 46)
            cv.keep.add(tx, ty, 40)
            if st["tower_flags"]:
                cv.add(ty + 0.5, (lambda a=tx, b=ty: A.flag(cv.s, a, b - 56, 22)))
    if ch.get("tower"):
        cv.add(cy - 80, lambda: A.tower(cv.s, cx - 120, cy - 60, 22, 54, col=(214, 196, 164)))
        cv.add(cy - 79.5, lambda: A.flag(cv.s, cx - 120, cy - 60 - 66, 22))
    # harbours of the small towns: nothing, a jetty, or a quay with a mole and warehouses
    for town_, (tx, ty, ln), box, seed in ((sv, (sx + 190, sy - 10, 84), (sx - 70, sx + 230, sy - 80, sy + 110), 61),
                                           (ch, (cx + 20, cy + 30, 70), (cx - 110, cx + 110, cy - 40, cy + 110), 62)):
        if town_["port"]:
            end = port_works(cv, box[0], box[1], box[2], box[3], seed, n_wh=3, mole=(tx, ty, ln + 34))
            cv.add(end[1] + 16, (lambda e=end: A.boat(cv.s, e[0] - 34, e[1] + 14, 1.15, 1)))
        elif town_["jetty"]:
            end = C.jetty(cv, tx, ty, ln)
            cv.add(end[1] + 16, (lambda e=end: A.boat(cv.s, e[0] - 34, e[1] + 14, 1.15, 1)))
    for (tx, ty) in ((cx - 70, cy + 20), (cx - 30, cy + 26), (sx + 20, sy + 40), (700, 1010), (1700, 1040))[:st["strand_boats"]]:
        qx, qy, nx, ny = C.nearest_shore(cv, tx, ty)
        cv.add(qy, (lambda a=qx - nx * 6, b=qy - ny * 6 + 4, k=int(tx): A.boat(cv.s, a, b, 0.9, 1 if k % 2 else -1, sail=False,
                                                                           col=((60, 96, 140), (176, 60, 50), (236, 226, 200))[k % 3])))
    # mills on the torrents, press houses and barns by the villages
    for name, frac in st["mills"]:
        site = stream_side(cv, pol if name == "pol" else bis, frac)
        if site:
            x, y, d = site
            cv.add(y, (lambda x=x, y=y, d=d: A.mill(cv.s, x, y, random.Random(int(x)), 1.0, d)))
            cv.sh_box(x, y, 40, 44)
            cv.keep.add(x, y - 12, 34)
    for i in st["press"]:
        hx, hy, sd, side = ST.HAMLETS[i]
        for dx, dy in ((112, 16), (-112, 14), (104, -22), (-104, -20)):
            x, y = hx + dx, hy + dy
            if cv.keep.clear(x, y - 8, -4) and is_land(*K(x, y), 0.05):
                cv.add(y, (lambda x=x, y=y: A.press_house(cv.s, x, y, random.Random(int(x)), 1.15)))
                cv.add(y - 6, (lambda x=x, y=y: A.cypress(cv.s, x - 38, y - 6, 1.4, random.Random(int(y)))))
                cv.sh_box(x, y, 54, 40)
                cv.keep.add(x, y - 10, 42)
                break
    for i in st["barns"]:
        hx, hy, sd, side = ST.HAMLETS[i]
        for dx, dy in ((-118, 18), (118, 18), (-110, -18), (110, -20)):
            x, y = hx + dx, hy + dy
            if cv.keep.clear(x, y - 8, -4) and cv.keep.clear(x - 40, y - 4, -8) and is_land(*K(x, y), 0.05):
                cv.add(y, (lambda x=x, y=y: A.barn(cv.s, x, y, random.Random(int(x)), 1.0)))
                cv.sh_box(x, y, 46, 40)
                cv.keep.add(x - 14, y - 8, 50)
                break

    def on_dome(x, y):
        ty = T.sil_y(dome_top, x)
        if ty is None or y > 890:
            return False
        if y > ty + 24:
            return (int(x * 7 + y * 3) % 10) < 7           # a few trees stand on the slope
        return y > ty - 110                                   # none close behind the crest

    bias, (scrub_coast, scrub_in) = st["tree_bias"], st["scrub"]

    def marks(x, y, dice):
        if dice < 0.3:
            return A.stump
        return A.charcoal_pile if dice > 0.93 else None

    T.grow_trees_staged(cv, coast_y, veto=on_dome,
                        bias=lambda x, y, cd: bias,
                        scrub=(lambda x, y, cd: scrub_coast if cd < 430 else scrub_in) if scrub_coast else None,
                        marks=marks if st["clearings"] else None)
    for i, (fx, fy) in enumerate(st["flocks"]):
        if cv.keep.clear(fx, fy, 10):
            cv.add(fy + 12, (lambda a=fx, b=fy, k=i: C.flock(cv.s, a, b, k)))
    cv.flush_shadows()
    cv.flush_objects()
    C.gulls(cv.s)
    return cv


_ref = []


def render(key, keep_2x=False):
    """Returns (the 1280x720 picture with names, the 2x drawing without names) of one stage."""
    if not _ref:
        _ref.append(compose(ST.STAGES["3"], None, upto_relief=True))
    cv = compose(ST.STAGES[key], _ref[0])
    out = pygame.transform.smoothscale(cv.s, (OUT_W, OUT_H))
    C.names(out)
    pygame.draw.rect(out, (40, 36, 40), out.get_rect(), 1)
    return out, cv.s


def run(out_dir, which="all"):
    os.makedirs(out_dir, exist_ok=True)
    keys = ST.ORDER if which == "all" else (which,)
    pics = {}
    for key in keys:
        t0 = time.time()
        out, big = render(key)
        st = ST.STAGES[key]
        pygame.image.save(out, os.path.join(out_dir, st["file"] + ".png"))
        if os.environ.get("CLOSEUP_KEEP_2X"):
            pygame.image.save(big, os.path.join(out_dir, st["file"] + "_2x.png"))
        pics[key] = (out, big)
        print("stage %s rendered in %.1f s" % (key, time.time() - t0))
    return pics


if __name__ == "__main__":
    import sheets
    pics = run(sys.argv[1], "all")
    sheets.contact_sheet(pics, os.path.join(sys.argv[1], "growth_sheet.png"))
    sheets.zoom_strips(pics, os.path.join(sys.argv[1], "growth_zoom_strips.png"))
