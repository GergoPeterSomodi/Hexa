"""The growing map mockup: the 2D close-up of Genoa drawn at several moments in time.

    python tools/worldmap/closeup_2d/closeup.py OUT_DIR --stage 1|2|3|4a|4b|all
    python tools/worldmap/closeup_2d/growth.py OUT_DIR            (all five panels, the contact sheet and the zoom strips)

What stands in each stage is data (stages.py): every hex of the normal map is one district with a stage per panel,
and a district's seat, farms, fields, terraces and woods are drawn from the stage of the hex they stand in, inside
that hex (check_layout tests every site). The land is the same in every stage: the coast, the ground tones, the
torrent, the hills and ranges (their places and silhouettes), the town sites and the road lines. To keep it so:
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
GENOA_ZONE = (884, 868, 330.0, 240.0)       # the hill and town of Genoa: no data hills, no rule-placed fields
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
        if SF.SLOPES:
            T.TONES = SF.SLOPES.level(1.0)
        loops = build_coast([ell_km(kind, e) for kind, e in C.COAST_MODS])
        drift, at = coast_drift(loops)
        print("coast: at most %.1f km from the normal map's line (limit %.1f)" % (drift, COAST_REACH_KM))
        assert drift <= COAST_REACH_KM, at
        _ready.append([[P(*p) for p in lp] for lp in loops])
        bad = check_layout()
        for line in bad:
            print("LAYOUT:", line)
    return _ready[0]


def check_layout(margin=0.7):
    """Every authored site against its hex: returns the list of those that touch or cross a border (km margin)."""
    bad = []

    def test(what, hx, pts, m=margin):
        worst = min(hex_margin(x, y, hx) for x, y in pts)
        if worst < m:
            bad.append("%s leaves hex %s (%.1f km inside, wanted %.1f)" % (what, hx, worst, m))

    def ell(x, y, rx, ry):
        return [(x + math.cos(math.radians(a)) * rx, y + math.sin(math.radians(a)) * ry) for a in range(0, 360, 20)]

    gh = C.GENOA_HEX
    test("Genoa wall", gh, C.WALL)
    test("Genoa lighthouse rock", gh, ell(C.CAPE[0], C.CAPE[1], C.CAPE[2], C.CAPE[3]), 0.4)
    test("Genoa junction", gh, [C.JUNCTION])
    for key in ST.ORDER:
        g = ST.STAGES[key]["genoa"]
        for pts, w in g["moles"]:
            test("Genoa mole (%s)" % key, gh, [(x, y + w / 2.0) for x, y in pts], 0.4)
        test("Genoa suburbs (%s)" % key, gh, [(x + d, y) for x, y in g["suburbs"] for d in (-24, 24)] or [C.JUNCTION])
        test("Genoa slips (%s)" % key, gh, [(x - 30, y + 18) for x, y in g["slips"]] or [C.JUNCTION], 0.4)
    sx, sy, srx, sry = ST.SAVONA_AT
    test("Savona", (7, 13), [q for q in ell(sx, sy, srx + 16, sry + 12) if q[0] > 0])
    cx, cy, crx, cry = ST.CHIAVARI_AT
    test("Chiavari", (9, 13), ell(cx, cy, crx + 6, cry + 8))
    test("pass post", (9, 12), [(ST.PASS_AT[0] - 110, ST.PASS_AT[1]), (ST.PASS_AT[0] + 150, ST.PASS_AT[1])])
    for i, (x, y, sd, side) in enumerate(ST.HAMLETS):
        test("hamlet %d" % i, hex_at(x, y), ell(x, y, 96, 42))
    for i, (x, y, lv) in enumerate(ST.FARMS):
        test("farm %d" % i, hex_at(x, y), [(x - 34, y), (x + 60, y + 6), (x, y - 44), (x + 40, y - 40)])
    for i, b in enumerate(ST.BLOCKS):
        if hex_margin(b[0], b[1]) < 2.0:
            bad.append("block %d stands too near a border" % i)
    for i, (x, y, lv) in enumerate(ST.TOWERS):
        test("watchtower %d" % i, hex_at(x, y), [(x - 12, y), (x + 12, y)], 0.5)
    return bad


def stage_at(key, x, y):
    """The stage of the district a point (drawing px) lies in, in panel key."""
    return ST.stage_of(hex_at(x, y), key)


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


def auto_blocks(cv, st, key, hills, streams):
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
            hx = hex_at(x, y)
            if ST.stage_of(hx, key) < 4 or not all(in_hex(x + dx, y + dy, hx, 0.8) for dx in (-95, 95) for dy in (-48, 48)):
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
            cands.append((score, x, y, gx, gy, hx))
    cands.sort(reverse=True)
    for i, (score, x, y, gx, gy, hx) in enumerate(cands[:spec["n"]]):
        ang = (hsh(gx, gy, 4) - 0.5) * 26
        cols, rows = (3, 2) if hsh(gx, gy, 5) < 0.6 else (2, 3)
        C.field_block(cv, x, y, ang, cols, rows, 58 * 1.4, 40 * 1.35, seed=500 + gx * 7 + gy, mix=getattr(ST, spec["mix"]),
                      hedge=spec["hedge"], hx=hx)


def stream_side(cv, line, frac, off=34):
    """A site beside a stream, frac of the way down it; returns (x, y, side) or None when the ground is taken."""
    i = int((len(line) - 1) * frac)
    for j in list(range(i, min(len(line), i + 60), 6)) + list(range(i, max(0, i - 60), -6)):
        for side in (1, -1):
            x, y = line[j][0] + side * off, line[j][1]
            if cv.keep.clear(x, y - 6, -6) and cv.sites.clear(x, y, 20) and is_land(*K(x, y), 0.05) and hex_margin(x - side * 16, y) > 0.5 \
                    and hex_margin(x + side * 22, y) > 0.5:
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
        lx, ly = C.CAPE[0] - 4, C.CAPE[1] + 2

        def old_light():
            rr = random.Random(9)
            A.rock(s, lx - 16, ly + 8, 30, rr, col=(160, 148, 130))
            A.rock(s, lx + 14, ly + 9, 26, rr, col=(150, 140, 126))
            A.rock(s, lx, ly + 12, 40, rr, col=(170, 158, 138))
            A.beacon(s, lx, ly + 2, 1.15)
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
        fx, fy = C.CASTLE[0] + 40, C.CASTLE[1] - 30
        cv.add(fy + 30, lambda: A.bastion_fort(s, fx, fy, 96, 38, h=20, n=5))
        cv.add(fy + 31, lambda: A.castle(s, fx, fy + 10, sc=0.66))
        cv.sh_poly([(fx - 92, fy + 26), (fx + 98, fy + 26), (fx + 146, fy + 52), (fx - 46, fy + 52)])
        for ang in (-90, -18, 198):                   # flags on the three bastions that show behind the keep
            tx, ty = fx + math.cos(math.radians(ang)) * 96 * 0.9, fy + math.sin(math.radians(ang)) * 38 * 0.9 - 20
            cv.add(fy + 32, (lambda a=tx, b=ty: A.flag(cv.s, a, b, 22)))
        cv.keep.add(fx, fy, 104)
    if g.get("flags"):
        for i, (x, y) in enumerate(C.WALL):
            if (x, y) not in (C.WEST_GATE, C.NORTH_GATE, C.EAST_GATE, C.CASTLE) and i % 2 == 0:
                cv.add(y - 5.5, (lambda x=x, y=y: A.flag(cv.s, x, y - 62, 22)))


# ---------------------------------------------------------------- one stage
def compose(key, ref=None, upto_relief=False):
    """Paints one panel and returns the canvas. ref is the canvas of the reference layout: its routes decide where
    hills stand, its hills tell the rule-placed fields where not to go. Without ref this is the reference pass: every
    site of every stage is laid out, so that no hill is put where a later stage will build."""
    st = ST.STAGES[key]
    full = ref is None
    loops_px = setup()
    g = st["genoa"]

    def stage(x, y):
        return 5 if full else stage_at(key, x, y)

    T.FARM_GAIN, T.WOOD_GAIN, T.SUN_COL = st["farm_gain"], st["wood_gain"], st["sun"]
    cv = T.Canvas()
    if ref is not None:
        cv.routes = FrozenGrid(ref.routes)
    sx, sy, srx, sry = ST.SAVONA_AT
    cx, cy, crx, cry = ST.CHIAVARI_AT
    sv = dict(ST.SAVONA[min(4, max(1, ST.stage_of((7, 13), key)))], **st.get("savona_extra", {}))
    ch = dict(ST.CHIAVARI[min(4, max(1, ST.stage_of((9, 13), key)))], **st.get("chiavari_extra", {}))
    T.paint_sea(cv, loops_px)
    T.paint_land(cv, loops_px)
    T.FARM_GAIN, T.WOOD_GAIN, T.SUN_COL = 1.0, 1.0, (176, 198, 100)
    runs = T.shore_points(loops_px)
    q0, q1 = g["quay"]
    T.paint_shore(cv, runs, [(lambda x, y: in_basin(x, y) and not (q0 - 3 <= bay_angle(x, y) <= q1 + 3), "sand"),
                             (in_basin, "quay"),
                             (lambda x, y: math.hypot(x - C.BAY[0], (y - C.BAY[1]) * 1.5) < 330, "sand"),
                             (lambda x, y: math.hypot(x - sx, y - sy - 110) < 180, "sand"),
                             (lambda x, y: math.hypot(x - cx, y - cy - 80) < 150, "sand")])
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

    # ---- the hill behind Genoa (inside Genoa's hex)
    wallpoly = C.WALL + C.WALL_FOOT
    B = C.DOME_BASE
    dome = [dict(x=626, y=B, h=84, apex=False, m=300), dict(x=748, y=B, h=150, apex=False, m=420), dict(x=892, y=B, h=186, apex=True, m=480),
            dict(x=1022, y=B, h=150, apex=False, m=420), dict(x=1142, y=B, h=88, apex=False, m=300)]
    dome_st = dict(st["dome"], clear=0.0,
                   where=lambda x, y: not in_poly(x, y, wallpoly) or y < arc(270, 200)[1] + abs(x - C.BAY[0]) * 0.2)
    dome_top = T.ridge(cv, dome, 0.37, main=False, wood=0.34, pre=True, st=dome_st)
    cv.hills = []
    # ---- the ground plane: the torrent and the roads of the normal map, fields, the harbour works
    bis = C.paint_stream(cv, C.BISAGNO, 4, 13, 4)

    def road(pts, spec, keep_w, **kw):
        style, w = spec
        return C.paint_road(cv, pts, w, style=style, keep_w=keep_w, **kw) if style else C.paint_road(cv, pts, w, **kw)

    giovi = road(C.ROAD_GIOVI, st["road_giovi"], 11)
    west = road(C.ROAD_WEST, st["road_coast"], 10)
    east = road(C.ROAD_EAST, st["road_coast"], 10)
    spur = road(C.ROAD_SPUR, st["road_spur"], 8)
    road(C.ROAD_GATE, st["road_coast"], 10, wig=0)
    roads = dict(giovi=giovi, west=west, east=east, spur=spur)
    for x in range(660, 1140, 40):
        for y in range(770, 1090, 40):
            if in_poly(x, y, wallpoly):
                cv.keep.add(x, y, 44)
    cv.keep.add(C.CAPE[0], C.CAPE[1], 50)
    cv.keep.add(C.JUNCTION[0], C.JUNCTION[1], 26)
    cv.routes.add(884, 880, 290)
    cv.routes.add(700, 905, 150)
    cv.routes.add(1070, 905, 150)
    # Savona and Chiavari, each inside its hex
    C.town(cv, sx, sy, srx, sry, sv["n"], 21, sc=1.25, walled=sv["walled"], big=sv["big"],
           church=(sx + 12, sy - 6, dict(sc=1.2, side="right")), church_built=sv["church"], wall_frac=sv.get("wall_frac", 1.0),
           scaffold=sv.get("scaffold", False), flags=sv.get("flags", False), paved=sv["paved"], pave_k=sv.get("pave_k", 1.0), hx=(7, 13))
    C.town(cv, cx, cy, crx, cry, ch["n"], 22, sc=1.2, big=ch["big"], paved=ch["paved"],
           church=(cx + 10, cy - 8, dict(sc=1.05, side="left", cap="dome")), church_built=ch["church"], hx=(9, 13))
    # the seats of the small districts: the site is fixed, the level follows the stage of the hex
    built = []
    for i, h in enumerate(ST.HAMLETS):
        lv = ST.HAMLET_LEVEL[stage(h[0], h[1])]
        if lv:
            built.append((h, lv))
        else:
            cv.sites.add(h[0], h[1], 72)
    farms = []
    for i, (fx, fy, need) in enumerate(ST.FARMS):
        if stage(fx, fy) >= need:
            farms.append((i, fx, fy))
        else:
            cv.sites.add(fx + 10, fy - 10, 30)
    # a cart track from every hamlet and farm to the nearest road of its own hex
    main_roads = giovi[::4] + west[::4] + east[::4] + spur[::4]
    for (hx_, hy_), wide in [((h[0], h[1] + 20), lv > 1) for h, lv in built] + [((fx, fy + 4), False) for i, fx, fy in farms]:
        own = hex_at(hx_, hy_)
        near = [q for q in main_roads if in_hex(q[0], q[1], own, 0.3)]
        if not near:
            continue
        q = min(near, key=lambda p: (p[0] - hx_) ** 2 + (p[1] - hy_) ** 2)
        d = math.dist(q, (hx_, hy_))
        if 50 < d < 460:
            mid = ((hx_ + q[0]) / 2 + (q[1] - hy_) * 0.1, (hy_ + q[1]) / 2 - (q[0] - hx_) * 0.1)
            track = wiggle(smooth([(hx_, hy_), mid, q], 3, 2.0), 4, 80.0, int(hx_) % 40 + 3)
            if not all(in_hex(t[0], t[1], own, 0.2) for t in track[::8]):
                track = smooth([(hx_, hy_), q], 1, 2.0)
            stroke(cv.s, track, 7 if wide else 5.5, (156, 134, 88))
            stroke(cv.s, track, 4.5 if wide else 3, (224, 206, 158))
            cv.keep.add_line(track, 9)
    for (hx_, hy_, sd, side), lv in built:
        own = hex_at(hx_, hy_)
        church = (hx_ + (10 if side == "right" else -6), hy_ - 8, dict(sc=0.95, side=side))
        if lv == 1:
            C.town(cv, hx_, hy_, 74, 30, 3, sd, sc=1.2, church=church, church_built=False, paved=False, hx=own)
        elif lv == 2:
            C.town(cv, hx_, hy_, 74, 30, 5, sd, sc=1.2, church=church, hx=own)
        else:
            C.town(cv, hx_, hy_, 88, 35, 9, sd, sc=1.2, church=church, big=1, hx=own)
    # the field blocks of every district, as far as its stage has brought them
    for i, b in enumerate(ST.BLOCKS):
        own = hex_at(b[0], b[1])
        sg = stage(b[0], b[1])
        if sg < b[7]:
            continue
        use = ST.DISTRICTS[own]["use"] if own in ST.DISTRICTS else "woodland"
        mix, hedge = (ST.MIXED, True) if full else ST.block_mix(use, sg, st["outcome"], i)
        if mix is ST.STRIPS and not hedge:            # open strip fields: narrow parcels, no hedges
            C.field_block(cv, b[0], b[1], b[2], b[3] * 2, b[4], b[5] * 0.7, b[6] * 1.35, seed=100 + i, mix=mix, hedge=False, hx=own)
        else:
            C.field_block(cv, b[0], b[1], b[2], b[3], b[4], b[5] * 1.4, b[6] * 1.35, seed=100 + i, mix=mix, hedge=hedge, hx=own)
    if ref is not None:
        auto_blocks(cv, st, key, ref.hills, (bis,))
    for i, x, y in farms:
        if cv.keep.clear(x, y, 20):
            C.farmstead(cv, x, y, 300 + i)
    C.genoa_ground(cv, g)
    C.genoa_gardens(cv, wallpoly, g["gardens"])
    # the crossing of the coast road and the torrent, on the border of Genoa's and Chiavari's hexes
    hit = None
    for i in range(0, len(east) - 2, 2):
        for j in range(0, len(bis) - 2, 2):
            hit = hit or seg_x(east[i], east[i + 2], bis[j], bis[j + 2])
    if hit and st["crossing"] == "ford":
        A.ford(cv.s, hit[0], hit[1], 30)
    # ---- standing things
    near_pts = [(h[0], h[1]) for h, lv in built] + [(sx, sy), (cx, cy), (C.BAY[0], 880)] + [(fx, fy) for i, fx, fy in farms]

    def ridge_st(grp):
        m = sum(q["m"] for q in grp) / len(grp)
        sg = stage(sum(q["x"] for q in grp) / len(grp), max(q["y"] for q in grp))
        d = dict(st["ridge_low"] if grp[0]["kind"] == "spur" and m < 900 else st["ridge"])
        if sg < 4:                 # only a rich district terraces its ranges
            d["terr"] = 0.0
        if sg < 2:
            d["clear"] = 0.0
        if sg < 3:
            d["wood"] = max(d["wood"], ST.LOOK[sg]["ridge_wood"])
        if d.get("terr"):
            d["where"] = lambda x, y: y > 230        # the far crest keeps its woods
        return d

    def hill_st(bx, by, h, coastal, sd):
        sg = stage(bx, by)
        farmed = coastal and sd < 0.75
        if sg == 2:               # early growth: only the hills by a settlement are worked
            farmed = farmed and min(math.hypot(bx - q[0], by - q[1]) for q in near_pts) < 420
        lines = ST.LOOK[sg]["hill_lines"] if farmed else 0
        crop = "olive"
        if sg >= 4:
            crop = st["hill_crop"]
            if st["outcome"] == "grain":
                lines = min(lines, 3)
            elif st["outcome"] == "wine" and not lines and (coastal or by > 520):
                lines = 5
        return dict(lines=lines, crop=crop, scrub=sg <= 2 and coastal and not lines)

    T.data_relief(cv, skip=lambda x, y: in_genoa(x, y), drop=0.3, st=dict(ridge=ridge_st, hill=hill_st))
    if upto_relief:
        return cv
    C.genoa(cv, g)
    genoa_extras(cv, g, east)
    C.ships(cv, [(SHIP[k], x, y, kw) for k, x, y, kw in st["fleet"]])
    if hit and st["crossing"] != "ford":
        if st["crossing"] == "timber":
            cv.add(hit[1] + 14, (lambda q=hit: A.timber_bridge(cv.s, (q[0] - 36, q[1] + 1), (q[0] + 36, q[1] - 1), 8)))
        else:
            cv.add(hit[1] + 14, (lambda q=hit: A.bridge(cv.s, (q[0] - 36, q[1] + 1), (q[0] + 36, q[1] - 1), 3, 9)))
        cv.keep.add(hit[0], hit[1], 50)
    # the pass post: the seat of the Giovi hex
    px, py = ST.PASS_AT
    kind = st.get("pass_") or ST.PASS[min(4, ST.stage_of((9, 12), key))]

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
    # coast watchtowers: one to a coastal district, on its own ground
    for i, (tx, ty, need) in enumerate(ST.TOWERS):
        if stage(tx, ty) >= need and is_land(*K(tx, ty + 6), 0.02):
            cv.add(ty, (lambda a=tx, b=ty: A.tower(cv.s, a, b, 20, 46, col=(214, 196, 164))))
            cv.sh_box(tx, ty, 20, 46)
            cv.keep.add(tx, ty, 40)
            if st["tower_flags"]:
                cv.add(ty + 0.5, (lambda a=tx, b=ty: A.flag(cv.s, a, b - 56, 22)))
    if ch.get("tower"):
        cv.add(cy - 50, lambda: A.tower(cv.s, cx - 112, cy - 30, 22, 54, col=(214, 196, 164)))
        cv.add(cy - 49.5, lambda: A.flag(cv.s, cx - 112, cy - 30 - 66, 22))
    # harbours of the small towns: nothing, a jetty, or a quay with a mole and warehouses; all inside the town's hex
    # Savona's cove is shallow inside its hex: a quay along the strand instead of a jetty out to sea
    if sv["port"] or sv["jetty"]:
        if sv["port"]:
            port_works(cv, sx - 72, sx + 20, sy + sry + 10, sy + sry + 110, 61, n_wh=2)
        else:
            quay_strip(cv, shore_run(cv, sx - 46, sx + 18, sy + sry + 10, sy + sry + 110, 8), 13)
        cv.add(sy + sry + 70, lambda: A.boat(cv.s, sx - 14, sy + sry + 64, 1.0, 1))
    if ch["port"] or ch["jetty"]:
        tx, ty = cx + 26, cy + cry + 30
        if ch["port"]:
            end = port_works(cv, cx - 78, cx + 78, cy + cry, cy + cry + 80, 62, n_wh=2, mole=(tx, ty, 52))
        else:
            end = C.jetty(cv, tx, ty, 40)
        if hex_margin(end[0], end[1] + 8, (9, 13)) < 0.3:
            print("LAYOUT: Chiavari's harbour reaches %.1f km from its border" % hex_margin(end[0], end[1] + 8, (9, 13)))
        cv.add(end[1] + 16, (lambda e=end: A.boat(cv.s, e[0] - 30, e[1] + 4, 1.0, 1)))
    for (tx, ty) in ST.STRAND[:st["strand_boats"]]:
        qx, qy, nx, ny = C.nearest_shore(cv, tx, ty)
        cv.add(qy, (lambda a=qx - nx * 6, b=qy - ny * 6 + 4, k=int(tx): A.boat(cv.s, a, b, 0.9, 1 if k % 2 else -1, sail=False,
                                                                           col=((60, 96, 140), (176, 60, 50), (236, 226, 200))[k % 3])))
    # mills on the torrent, press houses and barns by the farms
    for frac in st["mills"]:
        site = stream_side(cv, bis, frac)
        if site:
            x, y, d = site
            cv.add(y, (lambda x=x, y=y, d=d: A.mill(cv.s, x, y, random.Random(int(x)), 1.0, d)))
            cv.sh_box(x, y, 40, 44)
            cv.keep.add(x, y - 12, 34)
    standing = dict((i, (fx, fy)) for i, fx, fy in farms)
    for what, idx, offs in (("press", st["press"], ((104, 14), (-84, 12), (98, -26), (-78, -24))),
                            ("barn", st["barns"], ((-88, 16), (108, 16), (-82, -20), (102, -22)))):
        for i in idx:
            if i not in standing:
                continue
            fx, fy = standing[i]
            own = hex_at(fx, fy)
            for dx, dy in offs:
                x, y = fx + dx, fy + dy
                if cv.keep.clear(x, y - 8, -4) and cv.keep.clear(x - 30, y - 4, -8) and is_land(*K(x, y), 0.05) \
                        and in_hex(x - 34, y, own, 0.7) and in_hex(x + 34, y, own, 0.7):
                    if what == "press":
                        cv.add(y, (lambda x=x, y=y: A.press_house(cv.s, x, y, random.Random(int(x)), 1.15)))
                        cv.add(y - 6, (lambda x=x, y=y: A.cypress(cv.s, x - 38, y - 6, 1.4, random.Random(int(y)))))
                        cv.sh_box(x, y, 54, 40)
                        cv.keep.add(x, y - 10, 42)
                    else:
                        cv.add(y, (lambda x=x, y=y: A.barn(cv.s, x, y, random.Random(int(x)), 1.0)))
                        cv.sh_box(x, y, 46, 40)
                        cv.keep.add(x - 14, y - 8, 50)
                    break

    def on_dome(x, y):
        ty = T.sil_y(dome_top, x)
        if ty is None or y > C.DOME_BASE + 6:
            return False
        if y > ty + 24:
            return (int(x * 7 + y * 3) % 10) < 7           # a few trees stand on the slope
        return y > ty - 90                                    # none close behind the crest

    def look(x, y):
        return ST.LOOK[stage(x, y)]

    def marks(x, y, dice):
        if not look(x, y)["clearings"]:
            return None
        if dice < 0.3:
            return A.stump
        return A.charcoal_pile if dice > 0.93 else None

    T.grow_trees_staged(cv, coast_y, veto=on_dome,
                        bias=lambda x, y, cd: look(x, y)["tree_bias"],
                        scrub=lambda x, y, cd: look(x, y)["scrub"][0 if cd < 430 else 1],
                        marks=marks)
    for i in st["flocks"]:
        fx, fy = ST.FLOCKS[i]
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
        _ref.append(compose("3", None, upto_relief=True))
    cv = compose(key, _ref[0])
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
