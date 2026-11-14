"""Render the style frame at the close zoom (r=60) and the middle zoom (r=30)."""
import math, random, sys, os, time
from frame import *
from relief import *
from relief2 import *

FIELDS = Fields(WORLD)
build_roads(WORLD)
RELIEF, HILLS, RGRID = build_relief(WORLD, FIELDS)
TREES = build_trees(WORLD, FIELDS, RGRID)
PARCELS = build_parcels(WORLD, FIELDS)

PARCEL_COLS = [(222, 198, 104), (196, 208, 102), (210, 180, 96), (186, 196, 120), (232, 212, 128)]
WALLS = [(240, 228, 196), (232, 200, 140), (234, 192, 166), (246, 240, 228), (226, 210, 170)]
ROOF = (204, 94, 62)
ROOF_D = (160, 70, 50)


class Frame:
    def __init__(self, rpx, mid=False):
        self.rpx = rpx
        self.k = rpx / 60.0
        self.S = rpx / R_KM
        self.mid = mid
        self.W, self.H = int(1280 * self.k), int(720 * self.k)
        self.surf = pygame.Surface((self.W, self.H))
        self.objs = []
        self.shadows = []
        self.labels = []

    def P(self, x, y):
        return ((x - X0) * self.S, (y - Y0) * self.S * TILT)

    # ------------------------------------------------------------ ground, coast and sea, pixel by pixel
    def ground(self):
        F = FIELDS
        fw, fh = F.w, F.h

        def pack(a, b, c, sa, sb, sc):
            buf = bytearray(fw * fh * 3)
            for i in range(fw * fh):
                buf[3 * i] = max(0, min(255, int(a[i] * sa)))
                buf[3 * i + 1] = max(0, min(255, int(b[i] * sb)))
                buf[3 * i + 2] = max(0, min(255, int(c[i] * sc)))
            s = pygame.image.frombuffer(bytes(buf), (fw, fh), "RGB")
            big = pygame.transform.smoothscale(s, (int(fw * self.S), int(fh * self.S * TILT)))
            out = pygame.Surface((self.W, self.H))
            out.blit(big, (-2 * self.S, -2 * self.S * TILT))
            return pygame.image.tobytes(out, "RGB")

        nz1 = [vnoise(X0 + (i % fw) - 2, Y0 + (i // fw) - 2, 4.0, 51) for i in range(fw * fh)]
        nz2 = [vnoise(X0 + (i % fw) - 2, Y0 + (i // fw) - 2, 1.6, 52) for i in range(fw * fh)]
        A = pack(F.land, F.height, F.cliff, 255, 255 / 3300.0, 255)
        B = pack(F.farm, F.woods, F.rock, 255, 255, 255)
        C = pack(F.depth, nz1, nz2, 255, 255, 255)
        W, H = self.W, self.H
        out = bytearray(W * H * 3)
        k = self.k
        last_land = [-999] * W
        last_cliff = [0.0] * W
        off = 3 * (3 * W + 3)
        for y in range(H):
            row = y * W
            for x in range(W):
                i = (row + x) * 3
                lv = A[i] / 255.0
                if lv >= 0.5:
                    m = A[i + 1] * 12.94
                    farm, woods, rock = B[i] / 255.0, B[i + 1] / 255.0, B[i + 2] / 255.0
                    grass = max(0.0, 1.0 - farm - woods - rock)
                    r = farm * C_FARM[0] + grass * C_GRASS[0] + woods * C_WOOD[0] + rock * C_ROCK[0]
                    g = farm * C_FARM[1] + grass * C_GRASS[1] + woods * C_WOOD[1] + rock * C_ROCK[1]
                    b = farm * C_FARM[2] + grass * C_GRASS[2] + woods * C_WOOD[2] + rock * C_ROCK[2]
                    # higher ground: meadow goes to alpine stone, then snow
                    ta = smoothstep(1250, 2300, m) * (0.55 + 0.45 * smoothstep(-30, 40, C[i + 1] - 128))
                    if ta > 0:
                        r, g, b = r + (172 - r) * ta, g + (160 - g) * ta, b + (138 - b) * ta
                    n1 = C[i + 1] - 128
                    n2 = C[i + 2] - 128
                    hsh = ((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 255
                    if False:
                        r, g, b = 236, 240, 246
                        if n2 > 40:
                            r, g, b = 214, 222, 234
                    else:
                        sc = rock + ta * 0.8
                        if sc > 0.25:   # scree and boulders: light and dark dabs on stony ground
                            if n2 > 52 and hsh > 120:
                                r, g, b = r + 26, g + 24, b + 20
                            elif n2 < -46 and hsh > 150:
                                r, g, b = r - 30, g - 30, b - 26
                    i0 = i - off
                    i1 = i + off
                    if 0 <= i0 and i1 < len(A):
                        dh = A[i0 + 1] - A[i1 + 1]
                    else:
                        dh = 0
                    f = 1.0 + max(-0.16, min(0.16, dh * 0.016)) + n1 * 0.00045 + (hsh - 128) * 0.0002
                    r, g, b = r * f, g * f, b * f
                    cl = A[i + 2] / 255.0
                    # the shore: a sand strip on low coasts, wet rocks on steeper ones
                    if lv < 0.535 and cl < 0.35:
                        if m < 380:
                            r, g, b = C_SAND
                        else:
                            r, g, b = (150, 138, 118) if hsh > 90 else (122, 112, 98)
                    last_land[x] = y
                    last_cliff[x] = cl
                    out[i] = max(0, min(255, int(r)))
                    out[i + 1] = max(0, min(255, int(g)))
                    out[i + 2] = max(0, min(255, int(b)))
                else:
                    d = C[i] / 255.0
                    if d < 0.62:
                        t = (d - 0.3) / 0.32
                        r, g, b = C_SHELF[0] + (C_SEA[0] - C_SHELF[0]) * t, C_SHELF[1] + (C_SEA[1] - C_SHELF[1]) * t, C_SHELF[2] + (C_SEA[2] - C_SHELF[2]) * t
                    else:
                        t = (d - 0.62) / 0.38
                        r, g, b = C_SEA[0] + (C_DEEP[0] - C_SEA[0]) * t, C_SEA[1] + (C_DEEP[1] - C_SEA[1]) * t, C_SEA[2] + (C_DEEP[2] - C_SEA[2]) * t
                    n1 = C[i + 1] - 128
                    r, g, b = r + n1 * 0.05, g + n1 * 0.06, b + n1 * 0.05
                    if lv > 0.3:   # the light band of shallow water along the shore
                        t = (lv - 0.3) / 0.2
                        r, g, b = r + (122 - r) * t * 0.7, g + (192 - g) * t * 0.7, b + (222 - b) * t * 0.7
                    dy = y - last_land[x]
                    face = (2 + last_cliff[x] * 15) * k
                    if last_cliff[x] > 0.2 and dy <= face:
                        # a cliff face seen from the front: the land breaks off into the sea
                        hs = ((x * 2654435761) >> 7) & 31
                        base = 0.78 + 0.22 * (1 - dy / face)
                        if dy <= 1:
                            r, g, b = 70, 58, 50
                        else:
                            r, g, b = (150 + hs * 0.6) * base, (128 + hs * 0.5) * base, (104 + hs * 0.4) * base
                            if ((x // max(1, int(3 * k))) & 3) == 0:
                                r, g, b = r * 0.86, g * 0.86, b * 0.86
                    elif dy <= face + 2.2 * k and last_cliff[x] > 0.2:
                        r, g, b = C_FOAM
                    elif lv > 0.465:
                        r, g, b = C_FOAM
                    out[i] = max(0, min(255, int(r)))
                    out[i + 1] = max(0, min(255, int(g)))
                    out[i + 2] = max(0, min(255, int(b)))
        self.surf.blit(pygame.image.frombuffer(bytes(out), (W, H), "RGB"), (0, 0))

    # ------------------------------------------------------------ flat things on the ground plane
    def hexgrid(self):
        lay = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        for (c, r) in HEX:
            pts = [self.P(*p) for p in corners(c, r)]
            if all(p[0] < -60 or p[0] > self.W + 60 for p in pts) or all(p[1] < -60 or p[1] > self.H + 60 for p in pts):
                continue
            pygame.draw.lines(lay, (30, 40, 30, 26 if not self.mid else 20), True, pts, 1)
        self.surf.blit(lay, (0, 0))

    def parcels(self):
        if self.mid:
            return
        lay = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        for p in PARCELS:
            ca, sa = math.cos(p["a"]), math.sin(p["a"])
            pts = []
            for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                x = p["x"] + ca * u * p["w"] / 2 - sa * v * p["h"] / 2
                y = p["y"] + sa * u * p["w"] / 2 + ca * v * p["h"] / 2
                pts.append(self.P(x, y))
            col = PARCEL_COLS[p["c"]]
            pygame.draw.polygon(lay, col + (215,), pts)
            pygame.draw.lines(lay, (104, 120, 60, 150), True, pts, 1)
        self.surf.blit(lay, (0, 0))

    def rocks(self):
        """Stony ground is never flat: boulders, scree streaks and tufts of alpine grass, lying on the ground."""
        rnd = random.Random(17)
        k = self.k
        step = 1.5 if not self.mid else 2.6
        y = Y0 - 2
        while y < Y0 + 232:
            x = X0 - 2
            while x < X0 + 348:
                px, py = x + rnd.uniform(-0.7, 0.7), y + rnd.uniform(-0.6, 0.6)
                x += step
                m = FIELDS.at(FIELDS.height, px, py)
                stony = FIELDS.at(FIELDS.rock, px, py) * 0.9 + smoothstep(1300, 2300, m)
                if stony < 0.45 or not FIELDS.is_land(px, py, 0.05) or rnd.random() > stony * 0.27:
                    continue
                if WORLD["wgrid"].near(px, py, 2)[0] < 1.0 or WORLD["rdgrid"].near(px, py, 2)[0] < 0.8:
                    continue
                sx, sy = self.P(px, py)
                kind = rnd.random()
                if kind < 0.45:
                    rr = rnd.uniform(1.4, 2.6) * k
                    pts = [(sx + math.cos(a) * rr * rnd.uniform(0.8, 1.15), sy + math.sin(a) * rr * 0.7)
                           for a in [q * math.pi / 3 for q in range(6)]]
                    pygame.draw.polygon(self.surf, (196, 186, 166), pts)
                    pygame.draw.polygon(self.surf, (140, 130, 118), [pts[0], pts[1], pts[2], (sx, sy)])
                    pygame.draw.polygon(self.surf, (84, 74, 68), pts, 1)
                elif kind < 0.75:
                    L_ = rnd.uniform(2.5, 4.5) * k
                    col = (198, 188, 168) if rnd.random() < 0.5 else (128, 118, 104)
                    pygame.draw.line(self.surf, col, (sx, sy), (sx + L_ * 0.35, sy + L_), 1)
                    pygame.draw.line(self.surf, col, (sx + 2 * k, sy), (sx + 2 * k + L_ * 0.3, sy + L_ * 0.8), 1)
                else:
                    for q in range(3):
                        tx = sx + rnd.uniform(-2, 2) * k
                        pygame.draw.line(self.surf, (112, 140, 76), (tx, sy), (tx + rnd.uniform(-1, 1) * k, sy - 2.2 * k), 1)
            y += step * 0.9

    def stroke(self, pts_km, w0, w1, col, clip_land=True, step=0.35):
        pts = resample(pts_km, step)
        n = len(pts)
        for i, p in enumerate(pts):
            if clip_land and not FIELDS.is_land(p[0], p[1], -0.035):
                continue
            w = w0 + (w1 - w0) * i / max(1, n - 1)
            x, y = self.P(*p)
            pygame.draw.circle(self.surf, col, (x, y), max(0.6, w / 2))

    def water(self):
        k = self.k
        lay = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        for line in [rv["pts"] for rv in WORLD["rivers"]] + WORLD["streams"]:
            for q in resample(line, 0.8):
                m = FIELDS.at(FIELDS.height, *q)
                if m < 650 or not FIELDS.is_land(q[0], q[1], 0.0):
                    continue
                x, y = self.P(*q)
                rr = (6 + 6 * smoothstep(650, 1800, m)) * k
                pygame.draw.ellipse(lay, (132, 170, 84, 255), (x - rr, y - rr * 0.6, rr * 2, rr * 1.2))
        lay.set_alpha(150)
        self.surf.blit(lay, (0, 0))
        for st in WORLD["streams"]:
            if self.mid:
                continue
            self.stroke(st, 1.6 * k + 1.6, 2.6 * k + 1.6, C_RIVER_EDGE)
        for rv in WORLD["rivers"]:
            w = {3: 6.5, 2: 4.6, 1: 3.4}[rv["cls"]] * k
            self.stroke(rv["pts"], w * 0.75 + 2, w + 2, C_RIVER_EDGE, clip_land=False)
        for st in WORLD["streams"]:
            if self.mid:
                continue
            self.stroke(st, 1.2 * k, 2.4 * k, C_RIVER)
        for rv in WORLD["rivers"]:
            w = {3: 6.5, 2: 4.6, 1: 3.4}[rv["cls"]] * k
            self.stroke(rv["pts"], w * 0.75, w, C_RIVER, clip_land=False)
            # a highlight on the lit bank
            pts = resample(rv["pts"], 0.5)
            for i in range(0, len(pts), 3):
                x, y = self.P(*pts[i])
                if w > 3:
                    pygame.draw.circle(self.surf, (128, 190, 232), (x - w * 0.18, y - w * 0.12), max(0.6, w * 0.16))

    def roads(self):
        k = self.k
        for rd in WORLD["roads"]:
            if self.mid and rd["cls"] < 3:
                ww = 2.2 * k + 0.8
            else:
                ww = (3.4 if rd["cls"] == 3 else 2.5) * k
            pts = self.wiggle(rd["pts"])
            self.stroke(pts, ww + 2, ww + 2, C_ROAD_EDGE, step=0.3)
        for rd in WORLD["roads"]:
            if self.mid and rd["cls"] < 3:
                ww = 2.2 * k + 0.8
            else:
                ww = (3.4 if rd["cls"] == 3 else 2.5) * k
            pts = self.wiggle(rd["pts"])
            self.stroke(pts, ww, ww, C_ROAD, step=0.3)

    def wiggle(self, pts):
        """Roads climbing to a pass take hairpins: a sideways swing where the ground is high."""
        out = []
        dist = 0
        for i, p in enumerate(pts):
            if i:
                dist += math.dist(pts[i - 1], p)
            m = FIELDS.at(FIELDS.height, *p)
            near = min(math.hypot(ps["x"] - p[0], ps["y"] - p[1]) for ps in WORLD["passes"].values())
            amp = smoothstep(700, 1300, m) * smoothstep(0.8, 3.5, near) * 0.9 * smoothstep(0, 4, dist)
            if amp > 0 and 0 < i < len(pts) - 1:
                a, b = pts[i - 1], pts[i + 1]
                dx, dy = b[0] - a[0], b[1] - a[1]
                n = math.hypot(dx, dy) or 1
                s = math.sin(dist * 1.6) * amp
                out.append((p[0] - dy / n * s, p[1] + dx / n * s))
            else:
                out.append(p)
        return out

    # ------------------------------------------------------------ standing things (sorted by their foot)
    def add(self, y, x, fn):
        self.objs.append((y, x, fn))

    def relief(self):
        k = self.k
        rnd = random.Random(5)
        for rg in RELIEF:
            samples = rg
            if self.mid:
                samples = [s for i, s in enumerate(rg) if s["apex"] or s.get("pass_") or s["pf"] < 0.6]
                if rg[0]["kind"] == "spur":
                    samples = rg[0:len(rg):2]
                if rg[0]["kind"] == "massif":
                    samples = [max(rg, key=lambda q: q["m"])]
            pts = []
            for s in samples:
                bx, by = self.P(s["x"], s["y"])
                h = hp(s["m"]) * k * (s["pf"] if not s["apex"] else 1.0)
                if not s["apex"]:
                    h *= 0.4 + 0.25 * random.Random(s["x"] * 7.1 + s["y"]).random()
                pts.append(dict(x=bx, y=by, h=h, apex=s["apex"], m=s["m"], seed=rnd.random(), pass_=s.get("pass_"), kind=s["kind"]))
            # split into groups that run left to right without steep steps
            groups = []
            cur = [pts[0]] if pts else []
            for a, b in zip(pts, pts[1:]):
                dx, dy = b["x"] - a["x"], b["y"] - a["y"]
                same_dir = len(cur) < 2 or (dx > 0) == (cur[-1]["x"] - cur[-2]["x"] > 0)
                if abs(dy) <= 0.6 * abs(dx) and abs(dx) > 2 and same_dir:
                    cur.append(b)
                else:
                    groups.append(cur)
                    cur = [b]
            if cur:
                groups.append(cur)
            for g in groups:
                if g[0]["x"] > g[-1]["x"]:
                    g.reverse()
                if len(g) == 1 and not g[0]["apex"] and g[0]["h"] < 6 * k:
                    continue
                if len(g) == 1:
                    g[0]["apex"] = True
                foot = max(p["y"] for p in g)
                xs = sum(p["x"] for p in g) / len(g)
                if xs < -80 or xs > self.W + 80 or foot < -10 or foot > self.H + 90:
                    continue
                self.add(foot, xs, (lambda gg: lambda: self.draw_range(gg))(g))
                for p in g:
                    if p["apex"]:
                        w = p["h"] * 1.15
                        self.shadows.append(("ell", p["x"] + w * 0.35, p["y"] + p["h"] * 0.05, w * 1.3, max(3, p["h"] * 0.28)))
        for hl in HILLS:
            if self.mid and rnd.random() < 0.4:
                continue
            bx, by = self.P(hl["x"], hl["y"])
            h = (5.0 + 7.5 * smoothstep(360, 900, hl["m"])) * k
            self.add(by, bx, (lambda a, b, c, s: lambda: self.draw_hill(a, b, c, s))(bx, by, h, rnd.random()))
            self.shadows.append(("ell", bx + h * 0.9, by + 1, h * 2.6, h * 0.5))

    def style(self, m, seed):
        m = m + (seed - 0.5) * 220
        if m < 1700:
            return dict(lit=(132, 166, 86), sh=(92, 128, 70), ink=(48, 66, 42), green=True)
        if m < 2250:
            return dict(lit=(172, 162, 138), sh=(122, 114, 100), ink=(56, 50, 46), green=False, skirt=True)
        return dict(lit=(184, 175, 162), sh=(126, 118, 116), ink=(56, 50, 52), green=False)

    def draw_range(self, g):
        k = self.k
        s = self.surf
        # the silhouette along the top: peak, shoulder, saddle, shoulder, peak...
        top = []
        info = []
        n = len(g)
        geo = []
        st = self.style(max(p["m"] for p in g), g[0]["seed"])
        green = st.get("green")
        for p in g:
            r = random.Random(p["seed"])
            w = p["h"] * r.uniform(1.0, 1.2) * (1.3 if green else 1.0)
            geo.append((p["x"] + r.uniform(-0.06, 0.06) * w, p["y"] - p["h"], w, r))
        for idx, p in enumerate(g):
            ax, ay, w, r = geo[idx]
            by, h = p["y"], p["h"]
            if not p["apex"]:
                if idx == 0:
                    top.append((p["x"] - h * 1.2, by + h * 0.1))
                top.append((p["x"], ay))
                if idx == n - 1:
                    top.append((p["x"] + h * 1.2, by + h * 0.1))
                continue
            if idx == 0:
                top.append((ax - w, by + h * 0.08))
            lx, ly = top[-1]
            kx, ky = lx + (ax - lx) * 0.55, ly + (ay - ly) * 0.55 - h * 0.07 * r.uniform(-0.8, 1.6)
            if lx + 2 < kx < ax - 2:
                top.append((kx, ky))
            if green:   # wooded mountains have rounded tops, never a spike
                top.append((ax - w * 0.16, ay + h * 0.1))
                ia = len(top)
                top.append((ax + w * 0.02, ay + h * 0.005))
                top.append((ax + w * 0.17, ay + h * 0.11))
            else:
                ia = len(top)
                top.append((ax, ay))
            if idx < n - 1 and g[idx + 1]["apex"]:
                ax2, ay2, w2, _ = geo[idx + 1]
                q = g[idx + 1]
                sx = ax + (ax2 - ax) * r.uniform(0.42, 0.58)
                sy = (by + q["y"]) / 2 - min(h, q["h"]) * r.uniform(0.52, 0.76)
            elif idx < n - 1:
                q = g[idx + 1]
                sx, sy = q["x"], q["y"] - q["h"]
            else:
                sx, sy = ax + w, by + h * 0.08
            kx, ky = ax + (sx - ax) * 0.45, ay + (sy - ay) * 0.5 - h * 0.07 * r.uniform(-0.8, 1.6)
            if ax + 2 < kx < sx - 2:
                top.append((kx, ky))
            if idx < n - 1 and g[idx + 1]["apex"] or idx == n - 1:
                top.append((sx, sy))
            info.append((ia, ax, by, h, w, p))
        base = [(p["x"], p["y"] + p["h"] * 0.1 + 1.5 * k) for p in reversed(g)]
        poly = top + [(top[-1][0], base[0][1])] + base + [(top[0][0], base[-1][1])]
        st = self.style(max(p["m"] for p in g), g[0]["seed"])
        pygame.draw.polygon(s, st["lit"], poly)
        # shadow faces: right of a fall line from each peak
        for ia, ax, by, h, w, p in info:
            r = random.Random(p["seed"] + 1)
            right = []
            j = ia + 1
            while j < len(top):
                right.append(top[j])
                if j > ia + 1 and top[j][1] > top[ia][1] + h * 0.15 and (j + 1 >= len(top) or top[j + 1][1] < top[j][1]):
                    break
                j += 1
            if not right:
                continue
            ex, ey = right[-1]
            # the valley line runs from the saddle down to the foot at a slant; the fall line from the peak likewise
            vx = ex + (by - ey) * 0.22 if j < len(top) - 1 else ex
            fx = ax + w * r.uniform(0.22, 0.38)
            shp = [top[ia]] + right + [(vx, by + h * 0.1), (fx, by + h * 0.1),
                                       (ax + w * r.uniform(0.08, 0.16), by - h * 0.45)]
            pygame.draw.polygon(s, st["sh"], shp)
            # snow by height
            if p["m"] > 2250:
                sf = 0.2 + 0.26 * smoothstep(2250, 3300, p["m"])
                ys = by - h * (1 - sf)
                self.snow(top, ia, ax, by, h, ys, r)
            elif st.get("green"):
                pass
            # strata on rock
            if not st.get("green") and not self.mid:
                for q in range(2):
                    t = r.uniform(0.35, 0.7)
                    x0 = ax - w * t * 0.5
                    y0 = by - h * (1 - t)
                    pygame.draw.line(s, shade(st["lit"], 0.84), (x0, y0), (x0 + w * 0.18, y0 + h * 0.12), 1)
        if st.get("skirt"):
            xs = [q[0] for q in top]
            def sil(xq):
                for q in range(len(top) - 1):
                    a, b = top[q], top[q + 1]
                    if a[0] <= xq <= b[0] and b[0] > a[0]:
                        return a[1] + (b[1] - a[1]) * (xq - a[0]) / (b[0] - a[0])
                return None
            def base_y(xq):
                best = None
                for p in g:
                    d = abs(p["x"] - xq)
                    if best is None or d < best[0]:
                        best = (d, p["y"], p["h"])
                return best[1], best[2]
            r = random.Random(g[0]["seed"] + 9)
            x = xs[0]
            band = []
            while x <= xs[-1]:
                sy = sil(x)
                if sy is not None:
                    byq, hq = base_y(x)
                    yt = byq - hq * (0.36 + 0.1 * math.sin(x * 0.21 + r.random() * 6))
                    band.append((x, max(yt, sy + 1.2 * k), byq + hq * 0.1 + 1.5 * k))
                x += 2.0 * k
            for q in range(len(band) - 1):
                (x0, t0, b0), (x1, t1, b1) = band[q], band[q + 1]
                shadowed = any(ax + w * 0.14 < x0 < ax + w * 1.0 for _, ax, _, _, w, _ in info)
                col = (90, 130, 68) if shadowed else (122, 162, 82)
                pygame.draw.polygon(s, col, [(x0, t0), (x1 + 0.6, t1), (x1 + 0.6, b1), (x0, b0)])
            pts = [(q[0], q[1]) for q in band]
            if len(pts) > 1:
                pygame.draw.lines(s, (70, 104, 56), False, pts, 1)
        # a skirt of trees along the foot of green and middle mountains
        if (st.get("green") or st.get("skirt")) and not self.mid:
            for ia, ax, by, h, w, p in info:
                r = random.Random(p["seed"] + 2)
                n = int(w / (3.2 * k)) if st.get("green") else int(w / (5 * k))
                for q in range(n):
                    tx = ax + r.uniform(-0.85, 0.85) * w
                    ty = by + h * 0.05 - r.uniform(0, 0.32) * h * (1 - abs(tx - ax) / w)
                    rr = r.uniform(1.6, 2.3) * k
                    lit = tx < ax + w * 0.12
                    pygame.draw.circle(s, (70, 122, 58) if lit else (56, 100, 50), (tx, ty), rr)
                    pygame.draw.circle(s, (98, 150, 72) if lit else (74, 118, 60), (tx - rr * 0.3, ty - rr * 0.3), rr * 0.5)
        main = g[0].get("kind") == "crest"
        pygame.draw.lines(s, st["ink"] if main else shade(st["ink"], 1.25), False, top, max(1, int(round((2 if main else 1.3) * k))))

    def snow(self, top, ia, ax, by, h, ys, r):
        s = self.surf

        def walk(dirn):
            j = ia
            while 0 <= j + dirn < len(top):
                a, b = top[j], top[j + dirn]
                if b[1] >= ys:
                    t = (ys - a[1]) / ((b[1] - a[1]) or 1e-6)
                    return [(a[0] + (b[0] - a[0]) * t, ys)], j
                j += dirn
            return [top[j]], j
        lp, jl = walk(-1)
        rp, jr = walk(1)
        lefts = [top[q] for q in range(jl + 1, ia)] if jl < ia else []
        rights = [top[q] for q in range(ia + 1, jr + 1)] if jr > ia else []
        rights = [q for q in rights if q[1] < ys]
        x0, x1 = lp[0][0], rp[0][0]
        teeth = []
        n = max(2, int((x1 - x0) / (3 * self.k)))
        for q in range(n + 1):
            tx = x1 - (x1 - x0) * q / n
            teeth.append((tx, ys + (r.uniform(1.0, 3.2) * self.k if q % 2 else -0.5)))
        poly = lp + lefts + [top[ia]] + rights + rp + teeth
        if len(poly) >= 3:
            pygame.draw.polygon(s, C_SNOW, poly)
            fx = ax + (x1 - ax) * 0.25
            shp = [top[ia]] + rights + rp + [q for q in teeth if q[0] > fx] + [(fx, ys + 1)]
            if len(shp) >= 3:
                pygame.draw.polygon(s, (204, 212, 230), shp)

    def draw_hill(self, x, y, h, seed):
        s = self.surf
        k = self.k
        w = h * 2.5
        pts = [(x - w / 2 + w * t, y - h * math.sin(math.pi * t) ** 0.8) for t in [i / 14 for i in range(15)]]
        pygame.draw.polygon(s, (134, 172, 86), pts + [(x + w / 2, y + 1), (x - w / 2, y + 1)])
        shp = [(x + w * 0.04, y - h * 0.98)] + [p for p in pts if p[0] > x + w * 0.04] + [(x + w / 2, y + 1), (x + w * 0.16, y + 1), (x + w * 0.12, y - h * 0.4)]
        pygame.draw.polygon(s, (106, 146, 74), shp)
        pygame.draw.lines(s, (66, 94, 52), False, pts, 1)

    def trees(self):
        k = self.k
        for i, t in enumerate(TREES):
            if self.mid and i % 3:
                continue
            bx, by = self.P(t["x"], t["y"])
            if bx < -10 or bx > self.W + 10 or by < -5 or by > self.H + 20:
                continue
            sc = t["s"] * k * (1.4 if self.mid else 1.0)
            if t["con"]:
                self.add(by, bx, (lambda a, b, c: lambda: self.draw_conifer(a, b, c))(bx, by, sc))
            else:
                self.add(by, bx, (lambda a, b, c: lambda: self.draw_tree(a, b, c))(bx, by, sc))
            self.shadows.append(("ell", bx + 3.2 * sc, by + 0.5, 7 * sc, 2.4 * sc))

    def draw_tree(self, x, y, sc):
        s = self.surf
        pygame.draw.line(s, (92, 70, 50), (x, y), (x, y - 3 * sc), max(1, int(1.4 * sc)))
        r = 4.4 * sc
        cy = y - 3 * sc - r * 0.75
        pygame.draw.circle(s, (38, 60, 38), (x, cy), r + 1)
        pygame.draw.circle(s, (70, 128, 60), (x, cy), r)
        pygame.draw.circle(s, (96, 158, 72), (x - r * 0.28, cy - r * 0.28), r * 0.66)
        pygame.draw.circle(s, (130, 186, 92), (x - r * 0.45, cy - r * 0.45), r * 0.26)

    def draw_conifer(self, x, y, sc):
        s = self.surf
        h, w = 12.5 * sc, 7.2 * sc
        pygame.draw.line(s, (92, 70, 50), (x, y), (x, y - 2.5 * sc), max(1, int(1.3 * sc)))
        pts = [(x, y - h), (x + w / 2, y - 2 * sc), (x - w / 2, y - 2 * sc)]
        pygame.draw.polygon(s, (66, 120, 70), pts)
        pygame.draw.polygon(s, (46, 92, 58), [(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)])
        pygame.draw.line(s, (60, 108, 64), (x - w * 0.3, y - h * 0.45), (x + w * 0.05, y - h * 0.38), 1)
        pygame.draw.polygon(s, (34, 56, 40), pts, 1)

    # ------------------------------------------------------------ towns, bridges, harbours
    def towns(self):
        for t in WORLD["towns"].values():
            if self.mid and t["rank"] == 1:
                continue
            bx, by = self.P(t["x"], t["y"])
            if bx < -40 or bx > self.W + 40 or by < -10 or by > self.H + 40:
                continue
            rnd = random.Random(t["name"])
            k = self.k * (1.6 if self.mid else 1.0)
            rank = t["rank"]
            n = {3: 19, 2: 9, 1: 3}[rank] + (14 if t["port"] and rank == 3 else 0)
            if self.mid:
                n = {3: 6, 2: 3, 1: 0}[rank]
            rx = {3: 26, 2: 15.5, 1: 8}[rank] * k
            if self.mid:
                rx *= 0.5
            ry = rx * TILT * 0.62
            houses = []
            tries = 0
            while len(houses) < n and tries < 400:
                tries += 1
                if t["port"] and rank == 3:
                    hx = bx + rnd.uniform(-1.45, 1.45) * rx
                    hy = by - rnd.uniform(-0.3, 1.7) * ry * (1 - 0.4 * abs(hx - bx) / (1.45 * rx))
                else:
                    a = rnd.uniform(0, 2 * math.pi)
                    d = math.sqrt(rnd.random()) * 0.92
                    hx, hy = bx + math.cos(a) * rx * d, by + math.sin(a) * ry * d
                if t["port"] and not FIELDS.is_land(X0 + hx / self.S, Y0 + hy / (self.S * TILT), 0.02):
                    continue
                if not self.mid and any(abs(hx - q[0]) < 5.6 * k and abs(hy - q[1]) < 3.4 * k for q in houses):
                    continue
                houses.append((hx, hy, rnd.random()))
            walled = rank >= 2 and not self.mid
            front_wall = walled and not t["port"]
            self.add(by - ry - 0.5, bx, (lambda a, b, c, d, e: lambda: self.draw_wall(a, b, c, d, e, back=True))(bx, by, rx + 3 * k, ry + 2.5 * k, walled))
            for hx, hy, sd in houses:
                self.add(hy, hx, (lambda a, b, c, d: lambda: self.draw_house(a, b, c, d))(hx, hy, sd, k))
            # the landmark of the place
            lm = {"Genoa": "dome", "Turin": "dome", "Pavia": "towers", "Pisa": "leaning", "Asti": "towers"}.get(t["name"],
                                                                                                           "church" if rank >= 2 else "chapel")
            if self.mid:
                lm = "dome" if rank == 3 else "church"
            self.add(by + 0.5, bx + 2, (lambda a, b, c, d: lambda: self.draw_landmark(a, b, c, d))(bx + rnd.uniform(-3, 3) * k, by - 1 * k, lm, k))
            if front_wall:
                self.add(by + ry + 2.5 * k, bx, (lambda a, b, c, d, e: lambda: self.draw_wall(a, b, c, d, e, back=False))(bx, by, rx + 3 * k, ry + 2.5 * k, walled))
            self.shadows.append(("ell", bx + rx * 0.25, by + 2, rx * 2.3, ry * 1.6))
            t["_label"] = (bx, by + ry + (6 if front_wall else 4) * k)
            if t["port"] and rank == 3:
                t["_label_above"] = (bx + rx * 0.2, by - ry * 1.7 - 16 * k)
            if t["port"]:
                self.harbour(t, bx, by, rx, ry, k)

    def draw_house(self, x, y, sd, k):
        s = self.surf
        r = random.Random(sd)
        w = r.uniform(6, 8.5) * k
        hw = r.uniform(3.8, 5.4) * k
        rh = r.uniform(3.2, 4.2) * k
        wall = WALLS[r.randrange(len(WALLS))]
        x0 = x - w / 2
        top = y - hw
        if r.random() < 0.5:
            # ridge across: the front roof slope seen from above
            pygame.draw.rect(s, wall, (x0, top, w, hw))
            pygame.draw.rect(s, shade(wall, 0.84), (x0 + w * 0.78, top, w * 0.22, hw))
            roof = [(x0 - 1 * k, top + 0.5), (x0 + w + 1 * k, top + 0.5), (x0 + w - 0.6 * k, top - rh), (x0 + 0.6 * k, top - rh)]
            pygame.draw.polygon(s, ROOF, roof)
            pygame.draw.polygon(s, ROOF_D, [roof[1], roof[2], (x0 + w * 0.72, top - rh), (x0 + w * 0.78, top + 0.5)])
            pygame.draw.polygon(s, INK, roof, 1)
        else:
            # gable to the front, the right roof slope going back
            pygame.draw.rect(s, wall, (x0, top, w, hw))
            gable = [(x0, top), (x0 + w / 2, top - rh), (x0 + w, top)]
            pygame.draw.polygon(s, wall, gable)
            slope = [(x0 + w / 2, top - rh), (x0 + w / 2 + 2.6 * k, top - rh - 2.2 * k), (x0 + w + 2.8 * k, top - 2.2 * k), (x0 + w + 0.6 * k, top + 0.4)]
            pygame.draw.polygon(s, ROOF_D, slope)
            pygame.draw.line(s, ROOF, (x0 - 0.6 * k, top + 0.4), (x0 + w / 2, top - rh), max(1, int(1.6 * k)))
            pygame.draw.polygon(s, INK, slope, 1)
            pygame.draw.line(s, INK, (x0, top), (x0 + w / 2, top - rh), 1)
        if k >= 0.9:
            pygame.draw.rect(s, (70, 56, 50), (x0 + w * 0.4, y - 2.2 * k, max(1, 1.4 * k), 2.2 * k))
        pygame.draw.rect(s, INK, (x0, top, w, hw), 1)

    def draw_landmark(self, x, y, kind, k):
        s = self.surf
        stone = (236, 226, 204)
        if kind in ("church", "chapel", "dome"):
            w, hw = (9 if kind != "chapel" else 6) * k, (6 if kind != "chapel" else 4.5) * k
            pygame.draw.rect(s, stone, (x - w / 2, y - hw, w, hw))
            roof = [(x - w / 2 - 1, y - hw), (x + w / 2 + 1, y - hw), (x + w / 2 - 1, y - hw - 3.5 * k), (x - w / 2 + 1, y - hw - 3.5 * k)]
            pygame.draw.polygon(s, ROOF, roof)
            pygame.draw.polygon(s, INK, roof, 1)
            pygame.draw.rect(s, INK, (x - w / 2, y - hw, w, hw), 1)
            if kind == "dome":
                cx, cy = x, y - hw - 3.5 * k
                pygame.draw.rect(s, stone, (cx - 3.5 * k, cy - 3 * k, 7 * k, 3 * k))
                pygame.draw.rect(s, INK, (cx - 3.5 * k, cy - 3 * k, 7 * k, 3 * k), 1)
                rect = pygame.Rect(0, 0, 8 * k, 8 * k)
                rect.center = (cx, cy - 3 * k)
                pygame.draw.ellipse(s, (150, 160, 150), rect)
                pygame.draw.ellipse(s, (178, 188, 176), rect.inflate(-3 * k, -3 * k).move(-1 * k, -1 * k))
                pygame.draw.rect(s, stone, (cx - 3.5 * k, cy - 3 * k, 7 * k, 3 * k))
                pygame.draw.arc(s, INK, rect, 0, math.pi, 1)
                pygame.draw.line(s, INK, (cx, cy - 7 * k), (cx, cy - 9 * k), 1)
            tx = x + w / 2 + 1.5 * k
            th = (13 if kind != "chapel" else 8) * k
            pygame.draw.rect(s, stone, (tx - 2 * k, y - th, 4 * k, th))
            pygame.draw.rect(s, shade(stone, 0.85), (tx + 0.6 * k, y - th, 1.4 * k, th))
            pygame.draw.polygon(s, ROOF_D, [(tx - 2.6 * k, y - th), (tx + 2.6 * k, y - th), (tx, y - th - 4 * k)])
            pygame.draw.polygon(s, INK, [(tx - 2.6 * k, y - th), (tx + 2.6 * k, y - th), (tx, y - th - 4 * k)], 1)
            pygame.draw.rect(s, INK, (tx - 2 * k, y - th, 4 * k, th), 1)
        elif kind == "towers":
            for dx, th in ((-5, 17), (2, 21), (7, 14)):
                tx = x + dx * k
                pygame.draw.rect(s, (214, 178, 140), (tx - 1.8 * k, y - th * k, 3.6 * k, th * k))
                pygame.draw.rect(s, (176, 140, 110), (tx + 0.5 * k, y - th * k, 1.3 * k, th * k))
                pygame.draw.rect(s, INK, (tx - 1.8 * k, y - th * k, 3.6 * k, th * k), 1)
                pygame.draw.rect(s, INK, (tx - 1.8 * k, y - th * k - 1.4 * k, 3.6 * k, 1.4 * k), 1)
        elif kind == "leaning":
            self.draw_landmark(x - 5 * k, y, "church", k)
            tx, ty = x + 9 * k, y + 1 * k
            lean = 0.12
            th = 15 * k
            pts = [(tx - 2.6 * k, ty), (tx + 2.6 * k, ty), (tx + 2.6 * k + th * lean, ty - th), (tx - 2.6 * k + th * lean, ty - th)]
            pygame.draw.polygon(s, (246, 242, 232), pts)
            for q in range(1, 5):
                yy = ty - th * q / 5
                xx = tx + th * lean * q / 5
                pygame.draw.line(s, (196, 188, 172), (xx - 2.6 * k, yy), (xx + 2.6 * k, yy), 1)
            pygame.draw.polygon(s, INK, pts, 1)

    def draw_wall(self, x, y, rx, ry, walled, back):
        if not walled:
            return
        s = self.surf
        k = self.k
        rect = pygame.Rect(0, 0, rx * 2, ry * 2)
        rect.center = (x, y)
        hw = 4 * k
        col = (214, 202, 174)
        n = 40
        if back:
            pts = [(x + math.cos(a) * rx, y + math.sin(a) * ry) for a in [math.pi + math.pi * q / n for q in range(n + 1)]]
            top = [(p[0], p[1] - hw) for p in pts]
            pygame.draw.polygon(s, shade(col, 0.82), pts + top[::-1])
            pygame.draw.lines(s, INK, False, top, 1)
        else:
            pts = [(x + math.cos(a) * rx, y + math.sin(a) * ry) for a in [math.pi * q / n for q in range(n + 1)]]
            top = [(p[0], p[1] - hw) for p in pts]
            pygame.draw.polygon(s, col, pts + top[::-1])
            for q in range(0, n, 3):
                p = top[q]
                pygame.draw.rect(s, col, (p[0] - 0.8 * k, p[1] - 1.5 * k, 1.6 * k, 1.5 * k))
            pygame.draw.lines(s, INK, False, top, 1)
            pygame.draw.lines(s, INK, False, pts, 1)
            for a in (0.25, 0.5, 0.75):
                q = int(n * a)
                p = pts[q]
                tw, th = 4.2 * k, hw + 3.5 * k
                pygame.draw.rect(s, col, (p[0] - tw / 2, p[1] - th, tw, th))
                pygame.draw.rect(s, shade(col, 0.84), (p[0] + tw * 0.15, p[1] - th, tw * 0.35, th))
                pygame.draw.rect(s, INK, (p[0] - tw / 2, p[1] - th, tw, th), 1)
            # the gate
            p = pts[n // 2]
            pygame.draw.rect(s, (70, 56, 50), (p[0] - 1.4 * k, p[1] - 2.6 * k, 2.8 * k, 2.6 * k))

    def harbour(self, t, bx, by, rx, ry, k):
        s = self.surf
        # find the sea side: the direction from the town to the nearest sea
        best = None
        for a in range(0, 360, 10):
            for d in (1, 2, 3, 4, 5, 7, 9):
                x = t["x"] + math.cos(math.radians(a)) * d
                y = t["y"] + math.sin(math.radians(a)) * d
                if not FIELDS.is_land(x, y, -0.05):
                    if best is None or d < best[0]:
                        best = (d, a)
                    break
        if best is None:
            return
        d, a = best
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        px_, py_ = -sa, ca   # along the shore
        if t["name"] == "Genoa":
            # the old mole and the new: two arms round a basin; the Lanterna on its rock to the west; ships at anchor
            sx, sy = t["x"] + ca * (d - 0.6), t["y"] + sa * (d - 0.6)
            west = [(sx + px_ * 4.2, sy + py_ * 4.2), (sx + px_ * 4.0 + ca * 2.4, sy + py_ * 4.0 + sa * 2.4),
                    (sx + px_ * 2.2 + ca * 3.6, sy + py_ * 2.2 + sa * 3.6)]
            east = [(sx - px_ * 3.0, sy - py_ * 3.0), (sx - px_ * 2.6 + ca * 2.0, sy - py_ * 2.6 + sa * 2.0),
                    (sx - px_ * 1.2 + ca * 2.6, sy - py_ * 1.2 + sa * 2.6)]
            for mole in (west, east):
                pts = [self.P(*q) for q in mole]
                pygame.draw.lines(s, INK, False, pts, max(3, int(5.2 * k)))
                pygame.draw.lines(s, (214, 202, 176), False, pts, max(2, int(3.2 * k)))
            lx, ly = self.P(sx + px_ * 5.4 + ca * 0.4, sy + py_ * 5.4 + sa * 0.4)
            pygame.draw.ellipse(s, (128, 118, 106), (lx - 4 * k, ly - 2 * k, 8 * k, 4 * k))
            self.add(ly, lx, lambda: self.draw_lighthouse(lx, ly, k))
            for u, v in ((0.6, 1.6), (-1.2, 1.2), (1.8, 6.0)):
                qx, qy = self.P(sx + px_ * u + ca * v, sy + py_ * u + sa * v)
                self.add(qy, qx, (lambda a_, b_: lambda: self.draw_ship(a_, b_, k))(qx, qy))
        else:
            mx, my = t["x"] + ca * (d - 0.4), t["y"] + sa * (d - 0.4)
            pts = [self.P(mx, my), self.P(mx + ca * 1.8 + px_ * 0.8, my + sa * 1.8 + py_ * 0.8)]
            pygame.draw.line(s, INK, pts[0], pts[1], max(3, int(4 * k)))
            pygame.draw.line(s, (210, 198, 172), pts[0], pts[1], max(1, int(2.2 * k)))
            if not self.mid:
                qx, qy = self.P(mx + ca * 1.7 - px_ * 1.0, my + sa * 1.7 - py_ * 1.0)
                self.add(qy, qx, (lambda a_, b_: lambda: self.draw_ship(a_, b_, k * 0.85))(qx, qy))

    def draw_lighthouse(self, x, y, k):
        s = self.surf
        h = 17 * k
        pts = [(x - 2.4 * k, y), (x + 2.4 * k, y), (x + 1.7 * k, y - h), (x - 1.7 * k, y - h)]
        pygame.draw.polygon(s, (240, 234, 220), pts)
        pygame.draw.polygon(s, (200, 192, 176), [(x + 0.5 * k, y), (x + 2.4 * k, y), (x + 1.7 * k, y - h), (x + 0.4 * k, y - h)])
        pygame.draw.polygon(s, INK, pts, 1)
        pygame.draw.rect(s, (250, 214, 96), (x - 1.5 * k, y - h - 3 * k, 3 * k, 3 * k))
        pygame.draw.rect(s, INK, (x - 1.5 * k, y - h - 3 * k, 3 * k, 3 * k), 1)
        pygame.draw.polygon(s, ROOF_D, [(x - 2 * k, y - h - 3 * k), (x + 2 * k, y - h - 3 * k), (x, y - h - 5.5 * k)])

    def draw_ship(self, x, y, k):
        s = self.surf
        hull = [(x - 6 * k, y - 3 * k), (x + 6 * k, y - 3 * k), (x + 4 * k, y), (x - 4 * k, y)]
        pygame.draw.polygon(s, (120, 78, 52), hull)
        pygame.draw.polygon(s, INK, hull, 1)
        pygame.draw.line(s, INK, (x, y - 3 * k), (x, y - 13 * k), 1)
        sail = [(x - 4.2 * k, y - 11.5 * k), (x + 4.2 * k, y - 11.5 * k), (x + 3.6 * k, y - 5 * k), (x - 3.6 * k, y - 5 * k)]
        pygame.draw.polygon(s, (246, 240, 226), sail)
        pygame.draw.polygon(s, (214, 206, 190), [(x + 0.5 * k, y - 11.5 * k), (x + 4.2 * k, y - 11.5 * k), (x + 3.6 * k, y - 5 * k), (x + 0.5 * k, y - 5 * k)])
        pygame.draw.polygon(s, INK, sail, 1)
        pygame.draw.line(s, (240, 244, 248), (x - 7 * k, y + 1), (x - 3 * k, y + 1), 1)

    def bridges(self):
        k = self.k * (1.2 if self.mid else 1.0)
        for b in WORLD["bridges"]:
            if self.mid and b["cls"] == 0:
                continue
            x, y = self.P(b["x"], b["y"])
            rx, ry = b["road_dir"]
            ang = math.atan2(ry * TILT, rx)
            span = {3: 9, 2: 7.5, 1: 6.5, 0: 5}[b["cls"]] * k
            self.add(y + 1, x, (lambda a, c, d, e: lambda: self.draw_bridge(a, c, d, e))(x, y, ang, span))

    def draw_bridge(self, x, y, ang, span):
        s = self.surf
        k = self.k
        ca, sa = math.cos(ang), math.sin(ang)
        a = (x - ca * span, y - sa * span)
        b = (x + ca * span, y + sa * span)
        w = 2.6 * k
        deck = [(a[0], a[1] - w), (b[0], b[1] - w), (b[0], b[1] + w * 0.4), (a[0], a[1] + w * 0.4)]
        # the arched face towards the viewer
        face = [(a[0], a[1] + w * 0.4), (b[0], b[1] + w * 0.4), (b[0], b[1] + w * 0.4 + 3 * k), (a[0], a[1] + w * 0.4 + 3 * k)]
        pygame.draw.polygon(s, (176, 164, 140), face)
        n = 3 if span > 7 * k else 2
        for q in range(n):
            t = (q + 0.5) / n
            cx, cy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + w * 0.4 + 3 * k
            rr = pygame.Rect(0, 0, span * 2 / n * 0.62, 4 * k)
            rr.center = (cx, cy)
            pygame.draw.ellipse(s, (48, 92, 136), rr)
        pygame.draw.polygon(s, INK, face, 1)
        pygame.draw.polygon(s, (214, 200, 168), deck)
        pygame.draw.polygon(s, INK, deck, 1)

    def passes(self):
        k = self.k
        for p in WORLD["passes"].values():
            x, y = self.P(p["x"], p["y"])
            if not (0 < x < self.W and 0 < y < self.H):
                continue
            high = p["m"] > 1500
            self.add(y + 0.5, x, (lambda a, b, c: lambda: self.draw_pass(a, b, c))(x, y, high))
            p["_label"] = (x, y)

    def draw_pass(self, x, y, high):
        s = self.surf
        k = self.k
        if high:   # a hospice: a low stone house with a small bell gable
            x0 = x + 4 * k
            pygame.draw.rect(s, (220, 212, 196), (x0, y - 5 * k, 8 * k, 5 * k))
            roof = [(x0 - 1, y - 5 * k), (x0 + 8 * k + 1, y - 5 * k), (x0 + 7 * k, y - 8 * k), (x0 + 1 * k, y - 8 * k)]
            pygame.draw.polygon(s, (116, 104, 98), roof)
            pygame.draw.polygon(s, INK, roof, 1)
            pygame.draw.rect(s, INK, (x0, y - 5 * k, 8 * k, 5 * k), 1)
        # a cairn with a pole on the saddle
        for q, (dx, dy, r) in enumerate(((0, 0, 2.2), (0.3, -2.4, 1.7), (0, -4.2, 1.2))):
            pygame.draw.circle(s, (150, 140, 128), (x + dx * k, y + dy * k), r * k)
            pygame.draw.circle(s, INK, (x + dx * k, y + dy * k), r * k, 1)
        pygame.draw.line(s, INK, (x, y - 5 * k), (x, y - 11 * k), 1)
        pygame.draw.polygon(s, (196, 60, 50), [(x, y - 11 * k), (x + 4 * k, y - 10 * k), (x, y - 9 * k)])

    def waves(self):
        rnd = random.Random(3)
        k = self.k
        if self.mid:
            return
        for q in range(70):
            x, y = rnd.uniform(X0, X0 + 345), rnd.uniform(Y0, Y0 + 230)
            if FIELDS.at(FIELDS.land, x, y) > 0.2:
                continue
            px, py = self.P(x, y)
            col = (112, 176, 218)
            pygame.draw.arc(self.surf, col, (px - 6 * k, py - 2 * k, 6 * k, 4 * k), 0.2, math.pi - 0.2, 1)
            pygame.draw.arc(self.surf, col, (px, py - 2 * k, 6 * k, 4 * k), 0.2, math.pi - 0.2, 1)

    # ------------------------------------------------------------ drawing it all
    def draw_shadows(self):
        lay = pygame.Surface((self.W, self.H))
        lay.fill((255, 255, 255))
        lay.set_colorkey((255, 255, 255))
        for sh in self.shadows:
            _, x, y, w, h = sh
            r = pygame.Rect(0, 0, w, h)
            r.center = (x, y)
            pygame.draw.ellipse(lay, (30, 50, 30), r)
        lay.set_alpha(46)
        self.surf.blit(lay, (0, 0))

    def labels_draw(self):
        k = self.k
        placed = []
        bold = lambda px: pygame.font.SysFont("segoeui", int(px), bold=True)
        ital = lambda px: pygame.font.SysFont("georgia", int(px), italic=True)
        for t in sorted(WORLD["towns"].values(), key=lambda t: -t["rank"]):
            if "_label" not in t:
                continue
            if self.mid and t["rank"] < 2:
                continue
            x, y = t["_label"]
            size = {3: 16, 2: 13.5, 1: 11.5}[t["rank"]] * (k if not self.mid else 0.72)
            f = bold(max(9, size))
            txt = f.render(t["name"], True, (250, 246, 234))
            pad_x, pad_y = (7 if t["rank"] == 3 else 5) * max(k, 0.6), 1.5 * max(k, 0.6)
            r = pygame.Rect(0, 0, txt.get_width() + pad_x * 2, txt.get_height() + pad_y * 2 - 2)
            r.midtop = (x, y)
            if "_label_above" in t:
                r.midbottom = t["_label_above"]
            r.clamp_ip(self.surf.get_rect().inflate(-4, -4))
            plate = pygame.Surface(r.size, pygame.SRCALPHA)
            col = (30, 36, 56, 232) if t["rank"] >= 2 else (52, 58, 74, 214)
            pygame.draw.rect(plate, col, plate.get_rect(), border_radius=int(r.height / 2.4))
            if t["rank"] == 3:
                pygame.draw.rect(plate, (214, 186, 110, 255), plate.get_rect(), 1, border_radius=int(r.height / 2.4))
            self.surf.blit(plate, r)
            self.surf.blit(txt, (r.centerx - txt.get_width() / 2, r.centery - txt.get_height() / 2))
            placed.append(r)
        for p in WORLD["passes"].values():
            if "_label" not in p:
                continue
            x, y = p["_label"]
            f = ital(max(9, 12.5 * k))
            self.halo_text(p["name"], f, (58, 48, 44), (244, 238, 222), (x + 7 * k, y + 1 * k), anchor="midleft")
        if not self.mid:
            for name, lx, ly in (("Po", 252, 245.5), ("Tanaro", 200, 270.5), ("Arno", 404, 392.2)):
                x, y = self.P(lx, ly)
                f = ital(11 * k)
                self.halo_text(name, f, (34, 84, 136), (196, 226, 242), (x, y), anchor="center")
        f = ital(22 * k)
        txt = "L i g u r i a n   S e a"
        x, y = self.P(282, 382)
        self.halo_text(txt, f, (38, 96, 150), None, (x, y), anchor="center")

    def halo_text(self, text, font, col, halo, pos, anchor="center"):
        img = font.render(text, True, col)
        r = img.get_rect(**{anchor: pos})
        if halo:
            h = font.render(text, True, halo)
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)):
                self.surf.blit(h, r.move(dx, dy))
        self.surf.blit(img, r)

    def render(self, path):
        t0 = time.time()
        for d in list(WORLD["towns"].values()) + list(WORLD["passes"].values()):
            for key in ("_label", "_label_above"):
                d.pop(key, None)
        self.ground()
        t1 = time.time()
        self.hexgrid()
        self.parcels()
        self.rocks()
        self.water()
        self.roads()
        self.waves()
        self.relief()
        self.trees()
        self.towns()
        self.bridges()
        self.passes()
        self.draw_shadows()
        for y, x, fn in sorted(self.objs, key=lambda o: (o[0], o[1])):
            fn()
        self.labels_draw()
        pygame.draw.rect(self.surf, (40, 36, 40), self.surf.get_rect(), 1)
        pygame.image.save(self.surf, path)
        print(path, "ground %.1fs total %.1fs, %d objects" % (t1 - t0, time.time() - t0, len(self.objs)))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    which = sys.argv[2] if len(sys.argv) > 2 else "both"
    if which in ("both", "close"):
        Frame(60).render(os.path.join(out, "style_frame_close.png"))
    if which in ("both", "middle"):
        Frame(30, mid=True).render(os.path.join(out, "style_frame_middle.png"))
