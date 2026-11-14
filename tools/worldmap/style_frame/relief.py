"""Relief, trees and field parcels for the style frame (km space)."""
import math, random
from frame import *


def in_window(x, y, m=30):
    return X0 - m < x < X0 + 345 + m and Y0 - m < y < Y0 + 230 + m


def crest_chains(world):
    key = lambda p: (round(p[0], 2), round(p[1], 2))
    edges = []
    for e in L["crests"]:
        a, b = (e[0], e[1]), (e[2], e[3])
        pts = edge_pts(a, b)
        if len(pts) != 2 or not in_window(*pts[0], m=40):
            continue
        edges.append((key(pts[0]), key(pts[1])))
    # a pass leaves a gap in the data's crest: close it with the edge nearest the pass, so the ridge dips to a saddle
    for p in world["passes"].values():
        c, r = hex_of_km(p["x"], p["y"])
        best = None
        for hx in [(c, r)] + nbrs(c, r):
            for n in nbrs(*hx):
                if n not in HEX or hx not in HEX:
                    continue
                pts = edge_pts(hx, n)
                if len(pts) != 2:
                    continue
                mid = ((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2)
                d = math.dist(mid, (p["x"], p["y"]))
                if best is None or d < best[0]:
                    best = (d, key(pts[0]), key(pts[1]))
        if best and best[0] < 12:
            edges.append((best[1], best[2]))
    adj = {}
    for a, b in edges:
        adj.setdefault(a, set()).add(b)
        adj.setdefault(b, set()).add(a)
    # join ends that are one short step apart over high ground (the data's crest has single-edge gaps)
    ends = [n for n in adj if len(adj[n]) == 1]
    for i, a in enumerate(ends):
        for b in ends[i + 1:]:
            d = math.dist(a, b)
            if d < 17.5 and b not in adj[a]:
                mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                if M(*mid) > 700:
                    adj[a].add(b)
                    adj[b].add(a)
    seen = set()
    chains = []
    nodes = sorted(adj, key=lambda n: (len(adj[n]) == 2, n))
    for s in nodes:
        for nb in sorted(adj[s]):
            if (s, nb) in seen:
                continue
            line = [s, nb]
            seen.add((s, nb)); seen.add((nb, s))
            prev, cur = s, nb
            while len(adj[cur]) == 2:
                nxt = [q for q in adj[cur] if q != prev][0]
                if (cur, nxt) in seen:
                    break
                seen.add((cur, nxt)); seen.add((nxt, cur))
                line.append(nxt)
                prev, cur = cur, nxt
            chains.append(line)
    return chains


def hp(m):
    """Peak height in px at the close zoom (hex radius 60) for a height in metres."""
    t = max(0.0, min(1.0, (m - 450.0) / 2650.0))
    return 9.0 + 50.0 * t ** 0.85


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
            best = min(best, math.hypot(t["x"] - x, t["y"] - y) - (3 if t["rank"] == 3 else 0))
        return best

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
            m = 0.55 * local_max(x, y) + 0.45 * max(M(x, y), 0) * 1.1
            pf = 1.0
            is_pass = None
            for ps in passes:
                d = math.hypot(ps["x"] - x, ps["y"] - y)
                if d < 8:
                    pf = min(pf, lerp(0.16, 1.0, smoothstep(1.0, 8, d)))
                    if d < 3.6:
                        is_pass = ps["name"]
            m *= rnd.uniform(0.9, 1.06)
            apex = ((i + off) % 2 == 0) and not is_pass and pf > 0.6
            samples.append(dict(x=x, y=y, m=m, pf=pf, apex=apex, kind="crest", nrm=(nx / nn, ny / nn), pass_=is_pass))
            rgrid.add(x, y)
        if samples:
            ridges.append(samples)
    # shoulders: spurs run down from the crest peaks towards the lower side, getting lower, stopping at valleys
    spurs = []
    for rg in ridges:
        for s in rg:
            if not s["apex"]:
                continue
            for side in (1, -1):
                nx, ny = s["nrm"][0] * side, s["nrm"][1] * side
                tx, ty = s["x"] + nx * 10, s["y"] + ny * 10
                if M(tx, ty) > M(s["x"], s["y"]) * 0.97:
                    continue
                ang = math.atan2(ny, nx) + rnd.uniform(-0.35, 0.35)
                chain = []
                for step, f in ((4.2, 0.76), (8.2, 0.6), (12.0, 0.46)):
                    x = s["x"] + math.cos(ang) * step + rnd.uniform(-0.6, 0.6)
                    y = s["y"] + math.sin(ang) * step + rnd.uniform(-0.6, 0.6)
                    mm = M(x, y)
                    if mm < 520 or not F.is_land(x, y, 0.08) or water_d(x, y) < 3.2 or road_d(x, y) < 2.4 or town_d(x, y) < 5:
                        break
                    chain.append(dict(x=x, y=y, m=min(s["m"] * f, mm * 1.05) * rnd.uniform(0.92, 1.05),
                                      pf=1.0, apex=True, kind="spur"))
                if chain:
                    spurs.append(chain)
                    for c in chain:
                        rgrid.add(c["x"], c["y"])
    ridges += spurs
    # the rest of the high ground: lower massif peaks and rolling hills, thinned out near valleys
    units = []
    hills = []
    step = 5.4
    j = 0
    y = Y0 - 18
    while y < Y0 + 245:
        x = X0 - 15 + (step / 2 if j % 2 else 0)
        while x < X0 + 360:
            px, py = x + rnd.uniform(-1.8, 1.8), y + rnd.uniform(-1.6, 1.6)
            x += step
            if not F.is_land(px, py, 0.1):
                continue
            m = F.at(F.height, px, py)
            wd = water_d(px, py)
            rd = road_d(px, py)
            td = town_d(px, py)
            if td < 5.5 or rd < 2.0:
                continue
            att = smoothstep(1.8, 7.5, wd)
            if m >= 820:
                if rgrid.near(px, py, 6)[0] < 4.6:
                    continue
                mm = m * lerp(0.55, 1.0, att) * rnd.uniform(0.78, 0.98)
                if mm < 700:
                    hills.append(dict(x=px, y=py, m=mm))
                else:
                    units.append([dict(x=px, y=py, m=mm, pf=1.0, apex=True, kind="fill")])
            elif m >= 360 and wd > 2.2:
                if rnd.random() < 0.72 * att:
                    hills.append(dict(x=px, y=py, m=m))
        y += step * 0.866
        j += 1
    return ridges + units, hills, rgrid


def build_trees(world, F, rgrid):
    rnd = random.Random(7)
    trees = []
    step = 1.75
    y = Y0 - 6
    j = 0
    towns = list(world["towns"].values())
    while y < Y0 + 236:
        x = X0 - 6 + (step / 2 if j % 2 else 0)
        while x < X0 + 352:
            px, py = x + rnd.uniform(-0.7, 0.7), y + rnd.uniform(-0.6, 0.6)
            x += step
            if not F.is_land(px, py, 0.06):
                continue
            m = F.at(F.height, px, py)
            if m > 1900:
                continue
            wv = F.at(F.woods, px, py)
            n = vnoise(px, py, 6.0, 31) * 0.6 + vnoise(px, py, 2.2, 32) * 0.4
            dens = wv * 0.9 + (n - 0.5) * 1.1
            rock = F.at(F.rock, px, py)
            sparse = (rock > 0.4 and rnd.random() < 0.05) or (F.at(F.farm, px, py) > 0.4 and rnd.random() < 0.012)
            if dens < 0.52 and not sparse:
                continue
            if world["wgrid"].near(px, py, 3)[0] < 1.3 or world["rdgrid"].near(px, py, 3)[0] < 1.1:
                continue
            if any(math.hypot(t["x"] - px, t["y"] - py) < (5.5 if t["rank"] == 3 else 3.8 if t["rank"] == 2 else 2.4) for t in towns):
                continue
            if rgrid.near(px, py, 4)[0] < 2.4:
                continue
            conifer = m > 750 or rock > 0.4 or vnoise(px, py, 5.0, 33) > 0.68
            trees.append(dict(x=px, y=py, con=conifer, s=rnd.uniform(0.85, 1.12), seed=rnd.random(), m=m))
        y += step * 0.866
        j += 1
    return trees


def build_parcels(world, F):
    rnd = random.Random(99)
    out = []
    step = 3.0
    towns = list(world["towns"].values())
    y = Y0 - 4
    while y < Y0 + 234:
        x = X0 - 4
        while x < X0 + 350:
            px, py = x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1)
            x += step
            if F.at(F.farm, px, py) < 0.5 or F.at(F.height, px, py) > 500 or not F.is_land(px, py, 0.12):
                continue
            if rnd.random() > 0.5:
                continue
            if world["wgrid"].near(px, py, 3)[0] < 1.6 or world["rdgrid"].near(px, py, 3)[0] < 1.0:
                continue
            if any(math.hypot(t["x"] - px, t["y"] - py) < (4.5 if t["rank"] == 3 else 3.0) for t in towns):
                continue
            ang = vnoise(px, py, 22, 41) * math.pi + rnd.uniform(-0.15, 0.15)
            out.append(dict(x=px, y=py, a=ang, w=rnd.uniform(1.8, 2.8), h=rnd.uniform(0.9, 1.4), c=rnd.randrange(5)))
        y += step
    return out
