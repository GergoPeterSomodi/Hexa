"""Relief round 2: ranges from crests, long spurs, one massif per high hex, hills; trees in clumps; fields in blocks."""
import math, random
from frame import *
from relief import crest_chains, in_window


def hp(m):
    """Peak height in px at the close zoom (hex radius 60) for a height in metres."""
    t = max(0.0, min(1.0, (m - 450.0) / 2650.0))
    return 8.0 + 40.0 * t ** 0.85


def local_max(x, y):
    best = 0.0
    for n in [hex_of_km(x + dx, y + dy) for dx, dy in ((0, 0), (6, 0), (-6, 0), (0, 6), (0, -6))]:
        best = max(best, hex_height(*n))
    return best


def build_relief(world, F):
    rnd = random.Random(1480)
    ridges = []
    rgrid = Grid(4.0)
    passes = list(world["passes"].values())

    def water_d(x, y):
        return world["wgrid"].near(x, y, 9)[0]

    def road_d(x, y):
        return world["rdgrid"].near(x, y, 6)[0]

    def town_d(x, y):
        best = 1e9
        for t in world["towns"].values():
            d = math.hypot(t["x"] - x, t["y"] - y) - (3 if t["rank"] == 3 else 0)
            # nothing tall stands just in front of (south of) a place, where it would hide it in the 3/4 view
            if 0 < y - t["y"] < 9 and abs(x - t["x"]) < 8:
                d = min(d, 0.0)
            best = min(best, d)
        return best

    # 1. the main ranges: one ridge along each crest line, peaks sized by the hexes on either side,
    #    dipping to a saddle at a pass and to a gorge where a river cuts through
    for ch in crest_chains(world):
        pts = resample(chaikin(ch, 2), 4.3)
        if len(pts) < 2:
            continue
        samples = []
        off = rnd.randint(0, 1)
        for i, p in enumerate(pts):
            x, y = p
            a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
            nx, ny = (b[1] - a[1]), -(b[0] - a[0])
            nn = math.hypot(nx, ny) or 1
            jit = rnd.uniform(-0.9, 0.9)
            x, y = x + nx / nn * jit, y + ny / nn * jit
            if not F.is_land(x, y, 0.05):
                continue
            m = 0.6 * local_max(x, y) + 0.4 * max(M(x, y), 0) * 1.1
            pf = 1.0
            is_pass = None
            for ps in passes:
                d = math.hypot(ps["x"] - x, ps["y"] - y)
                if d < 8:
                    pf = min(pf, lerp(0.16, 1.0, smoothstep(1.0, 8, d)))
                    if d < 3.6:
                        is_pass = ps["name"]
            wd = water_d(x, y)
            if wd < 3.5:
                pf = min(pf, lerp(0.1, 1.0, smoothstep(1.0, 3.5, wd)))
            if town_d(x, y) < 5 or (road_d(x, y) < 1.5 and not is_pass):
                pf = min(pf, 0.3)
            m *= rnd.uniform(0.76, 1.1)
            apex = ((i + off) % 2 == 0) and not is_pass and pf > 0.6
            if apex and rnd.random() < 0.3:
                m *= 1.16
            samples.append(dict(x=x, y=y, m=m, pf=pf, apex=apex, kind="crest", nrm=(nx / nn, ny / nn), pass_=is_pass))
            rgrid.add(x, y)
        if samples:
            ridges.append(samples)
    # 2. shoulders: spurs run down from every other crest peak to the lower side while the ground stays high,
    #    each peak sized by the ground under it, so a spur falls away into the plain; valleys stay open between
    spurs = []
    for rg in ridges:
        apexes = [s for s in rg if s["apex"]]
        for n_, s in enumerate(apexes):
            if n_ % 2:
                continue
            for side in (1, -1):
                nx, ny = s["nrm"][0] * side, s["nrm"][1] * side
                tx, ty = s["x"] + nx * 10, s["y"] + ny * 10
                if M(tx, ty) > M(s["x"], s["y"]) * 0.97:
                    continue
                ang = math.atan2(ny, nx) + rnd.uniform(-0.3, 0.3)
                chain = []
                d = 6.8
                x, y = s["x"], s["y"]
                while d < 48:
                    ang += rnd.uniform(-0.14, 0.14)
                    x, y = x + math.cos(ang) * 6.8, y + math.sin(ang) * 6.8
                    mm = M(x, y)
                    if mm < 640 or not F.is_land(x, y, 0.08) or water_d(x, y) < 3.6 or road_d(x, y) < 2.6 or town_d(x, y) < 6:
                        break
                    if rgrid.near(x, y, 4)[0] < 3.0 and d > 5:
                        break
                    hm = min(s["m"] * (0.8 - d / 90.0), mm * 0.95) * rnd.uniform(0.74, 1.0)
                    chain.append(dict(x=x, y=y, m=hm, pf=1.0, apex=True, kind="spur"))
                    d += 6.8
                if chain:
                    spurs.append(chain)
                    for c in chain:
                        rgrid.add(c["x"], c["y"])
    ridges += spurs
    # 3. massifs: high ground far from the ranges gets one short ridge of two or three peaks per hex, along the contour
    units = []
    for (c, r), hx in sorted(HEX.items()):
        if not hx.get("land"):
            continue
        cx, cy = centre(c, r)
        if not in_window(cx, cy, 20):
            continue
        cx += rnd.uniform(-4, 4)
        cy += rnd.uniform(-3, 3)
        m = M(cx, cy)
        if m < 1100 or rgrid.near(cx, cy, 10)[0] < 6.5 or water_d(cx, cy) < 4 or town_d(cx, cy) < 7:
            continue
        gx = M(cx + 3, cy) - M(cx - 3, cy)
        gy = M(cx, cy + 3) - M(cx, cy - 3)
        ang = math.atan2(gx, -gy) if abs(gx) + abs(gy) > 1 else rnd.uniform(-0.4, 0.4)
        n = 3 if m > 1700 else 2
        chain = []
        for q in range(n):
            t = (q - (n - 1) / 2) * 4.6
            x, y = cx + math.cos(ang) * t, cy + math.sin(ang) * t
            if water_d(x, y) < 3.4 or not F.is_land(x, y, 0.1):
                continue
            f = 1.0 if q == n // 2 else rnd.uniform(0.7, 0.85)
            chain.append(dict(x=x, y=y, m=max(M(x, y), 700) * f * 0.95, pf=1.0, apex=True, kind="massif"))
        if chain:
            units.append(chain)
            for cc in chain:
                rgrid.add(cc["x"], cc["y"])
    # 4. rolling hills on the middle ground, thinned near valleys
    hills = []
    step = 6.0
    j = 0
    y = Y0 - 18
    while y < Y0 + 245:
        x = X0 - 15 + (step / 2 if j % 2 else 0)
        while x < X0 + 360:
            px, py = x + rnd.uniform(-2, 2), y + rnd.uniform(-1.8, 1.8)
            x += step
            if not F.is_land(px, py, 0.1):
                continue
            m = F.at(F.height, px, py)
            wd = water_d(px, py)
            if town_d(px, py) < 5 or road_d(px, py) < 2.0 or wd < 2.4 or rgrid.near(px, py, 6)[0] < 4.8:
                continue
            if 380 <= m < 1500 and rnd.random() < 0.7 * smoothstep(2.4, 6, wd):
                hills.append(dict(x=px, y=py, m=min(m, 1100)))
        y += step * 0.866
        j += 1
    return ridges + units, hills, rgrid


def build_trees(world, F, rgrid):
    rnd = random.Random(7)
    trees = []
    step = 2.0
    y = Y0 - 6
    j = 0
    towns = list(world["towns"].values())
    while y < Y0 + 236:
        x = X0 - 6 + (step / 2 if j % 2 else 0)
        while x < X0 + 352:
            px, py = x + rnd.uniform(-0.8, 0.8), y + rnd.uniform(-0.7, 0.7)
            x += step
            if not F.is_land(px, py, 0.06):
                continue
            m = F.at(F.height, px, py)
            if m > 1800:
                continue
            wv = F.at(F.woods, px, py)
            n = vnoise(px, py, 6.0, 31) * 0.6 + vnoise(px, py, 2.2, 32) * 0.4
            dens = wv * 0.85 + (n - 0.5) * 1.3 - smoothstep(900, 1500, m) * 0.25
            rock = F.at(F.rock, px, py)
            sparse = (rock > 0.4 and m < 1700 and rnd.random() < 0.13) or (F.at(F.farm, px, py) > 0.4 and rnd.random() < 0.012)
            if dens < 0.6 and not sparse:
                continue
            if world["wgrid"].near(px, py, 3)[0] < 1.5 or world["rdgrid"].near(px, py, 3)[0] < 2.0:
                continue
            if any(math.hypot(t["x"] - px, t["y"] - py) < ((12 if t["port"] else 6) if t["rank"] == 3 else 3.8 if t["rank"] == 2 else 2.4) for t in towns):
                continue
            if rgrid.near(px, py, 6)[0] < 4.2:
                continue
            conifer = m > 1000 or rock > 0.4 or vnoise(px, py, 5.0, 33) > 0.72
            trees.append(dict(x=px, y=py, con=conifer, s=rnd.uniform(0.85, 1.12), seed=rnd.random(), m=m))
        y += step * 0.866
        j += 1
    return trees


def build_parcels(world, F):
    rnd = random.Random(99)
    out = []
    towns = list(world["towns"].values())
    seeds = []
    for t in towns:
        for q in range({3: 6, 2: 4, 1: 2}[t["rank"]]):
            a = rnd.uniform(0, 2 * math.pi)
            d = rnd.uniform(4.5, 9.5) if t["rank"] == 3 else rnd.uniform(3.4, 7.5)
            seeds.append((t["x"] + math.cos(a) * d, t["y"] + math.sin(a) * d))
    for (c, r), hx in sorted(HEX.items()):
        if hx.get("land") and hx["cover"] == 0 and rnd.random() < 0.45:
            x, y = centre(c, r)
            seeds.append((x + rnd.uniform(-8, 8), y + rnd.uniform(-7, 7)))
    for sx, sy in seeds:
        if not in_window(sx, sy, 5) or F.at(F.height, sx, sy) > 650 or not F.is_land(sx, sy, 0.15):
            continue
        if F.at(F.woods, sx, sy) > 0.6:
            continue
        ang = rnd.uniform(-0.5, 0.5) + (math.pi / 2 if rnd.random() < 0.4 else 0)
        ca, sa = math.cos(ang), math.sin(ang)
        cols, rows = rnd.randint(2, 4), rnd.randint(1, 3)
        pw, ph = rnd.uniform(2.2, 2.9), rnd.uniform(0.95, 1.25)
        for i in range(cols):
            for j in range(rows):
                if rnd.random() < 0.15:
                    continue
                u = (i - (cols - 1) / 2) * pw * 1.04
                v = (j - (rows - 1) / 2) * ph * 1.08
                x, y = sx + ca * u - sa * v, sy + sa * u + ca * v
                if world["wgrid"].near(x, y, 3)[0] < 1.4 or world["rdgrid"].near(x, y, 3)[0] < 0.9:
                    continue
                if any(math.hypot(t["x"] - x, t["y"] - y) < (3.6 if t["rank"] == 3 else 2.4) for t in towns):
                    continue
                if not F.is_land(x, y, 0.12):
                    continue
                out.append(dict(x=x, y=y, a=ang, w=pw, h=ph, c=rnd.randrange(5)))
    return out
