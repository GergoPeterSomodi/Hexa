"""The map art's drawing, without a world: trees, conifers, hills and mountain ranges (with their snow and styles),
as functions of a surface, in the style frame's own look and the seasons' palettes.

    p = art.Painter("summer")                      # or "spring", "autumn", "winter" (with climate "snow"/"frost"/"mild")
    p.on(surf).draw_tree(x, y, 1.0)                # (x, y) is the foot of the tree, on surf

This is the drawing code that used to live in style_frame/render.py (Frame.draw_tree, draw_conifer, draw_hill,
draw_range, snow, style) and frame_bake.py (the spring and autumn palettes); both use it from here. Nothing in this
module reads a map: the style frame hands in its ground tone (the slope shading of the land at a point) as
`ground_tone`; the tile bake has none, so a hill takes its plain colour.

Summer is the style frame's colours exactly. Spring and autumn take the kit's season tokens (kit.PAL, kit.LEAF_AUTUMN);
winter takes kit.WINTER[climate] and draws bare twigs, snowy conifers and snow-toned hills and ranges, for one
climate of the three per painter (the frame picks the climate per point; a tile set has one).
"""
import contextlib
import math
import os
import random
import sys

import pygame

HERE = os.path.dirname(os.path.abspath(__file__))

C_SNOW = (242, 245, 250)
SEASONS = ("summer", "spring", "autumn", "winter")
CLIMATES = ("snow", "frost", "mild")


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))))


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


_KIT = []


def kit():
    """The pieces kit (season palettes), imported when a season other than summer is drawn."""
    if not _KIT:
        sys.path.insert(0, os.path.join(HERE, "..", "pieces"))
        try:
            import kit as k
        finally:
            sys.path.pop(0)
        _KIT.append(k)
    return _KIT[0]


# ---------------------------------------------------------------- season tones (the greens of hills and ranges)
def is_green(col):
    return col[1] > col[0] + 10 and col[1] > col[2] + 25


def snowy(col):
    """A green of the frame's hills and ranges as snow of the same lightness."""
    if not is_green(col):
        return col
    r, g, b = col[0], col[1], col[2]
    t = max(0.0, min(1.0, ((r + g + b) / 3.0 - 45) / 95.0))
    return kit().mix((96, 104, 124), (240, 243, 248), t) + tuple(col[3:])


def frosty(col):
    """The same green in a frost winter: half way to snow, the frosted ground's own tone showing."""
    if not is_green(col):
        return col
    k = kit()
    t = max(0.0, min(1.0, ((col[0] + col[1] + col[2]) / 3.0 - 45) / 95.0))
    return k.mix(k.mix((92, 104, 96), k.WINTER["frost"]["grass"], t), snowy(col), 0.45) + tuple(col[3:])


def mildy(col):
    """The same green in a mild winter: duller and greyer, no snow."""
    if not is_green(col):
        return col
    k = kit()
    return k.mix(col, k.shade(k.WINTER["mild"]["grass"], (col[0] + col[1] + col[2]) / 400.0), 0.8) + tuple(col[3:])


WINTER_TONE = {"snow": snowy, "frost": frosty, "mild": mildy}


def season_tone(season):
    """The frame's greens in spring or autumn: the green scaled by the kit's grass of that season (None for others)."""
    if season not in ("spring", "autumn"):
        return None
    k = kit()
    pal, base = k.PAL[season]["grass"], k.PAL["summer"]["grass"]
    f = [pal[i] / base[i] for i in range(3)]

    def tone(col):
        if not is_green(col):
            return col
        return tuple(max(0, min(255, int(col[i] * f[i]))) for i in range(3)) + tuple(col[3:])
    return tone


@contextlib.contextmanager
def tone_draw(tone):
    """While open, the green drawing comes out in the given tone (for hills and wooded ranges)."""
    d = pygame.draw
    old = {n: getattr(d, n) for n in ("polygon", "circle", "lines", "line", "ellipse")}

    def wrap(fn):
        return lambda surf, col, *a, **k: fn(surf, tone(col), *a, **k)
    for n, fn in old.items():
        setattr(d, n, wrap(fn))
    try:
        yield
    finally:
        for n, fn in old.items():
            setattr(d, n, fn)


class Painter:
    """Draws the wild things on a surface: Painter(season, climate).on(surf).draw_tree(...).
    k: the frame's scale (1.0 at the close zoom, 60 px per hex radius); mid: the middle zoom (no strata, no foot trees);
    slopes: the slope rule is on (hills and green ranges take shade() of their lit colour);
    ground_tone(x, y, base, share): the colour of a hill at its foot (the style frame's slope shading); None: plain."""

    def __init__(self, season="summer", climate="snow", k=1.0, mid=False, slopes=True, ground_tone=None):
        assert season in SEASONS and climate in CLIMATES, (season, climate)
        self.season, self.climate = season, climate
        self.winter = season == "winter"
        self.k, self.mid, self.slopes = k, mid, slopes
        self._ground_tone = ground_tone
        self.surf = None
        self.tone = WINTER_TONE[climate] if self.winter else season_tone(season)

    def on(self, surf):
        self.surf = surf
        return self

    def ground_tone(self, x, y, base, share):
        if self.winter:
            base = self.tone(base)
        if self._ground_tone is not None:
            return self._ground_tone(x, y, base, share)
        return base

    # ---- the drawing proper (the style frame's, as it was)
    def style(self, m, seed):
        m = m + (seed - 0.5) * 220
        if m < 1700:
            return dict(lit=(132, 166, 86), sh=(92, 128, 70), ink=(48, 66, 42), green=True)
        if m < 2250:
            return dict(lit=(172, 162, 138), sh=(122, 114, 100), ink=(56, 50, 46), green=False, skirt=True)
        return dict(lit=(184, 175, 162), sh=(126, 118, 116), ink=(56, 50, 52), green=False)

    def _range(self, g):
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
        if st.get("green") and self.slopes:
            mid_p = g[len(g) // 2]
            st["lit"] = self.ground_tone(mid_p["x"], mid_p["y"] + mid_p["h"] * 0.1 + 3 * k, st["lit"], 0.3)
            st["sh"] = shade(st["lit"], 0.74)
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

    def _hill(self, x, y, h, seed):
        s = self.surf
        k = self.k
        w = h * 2.5
        pts = [(x - w / 2 + w * t, y - h * math.sin(math.pi * t) ** 0.8) for t in [i / 14 for i in range(15)]]
        lit = self.ground_tone(x, y + 2 * k, (134, 172, 86), 0.35)
        pygame.draw.polygon(s, lit, pts + [(x + w / 2, y + 1), (x - w / 2, y + 1)])
        shp = [(x + w * 0.04, y - h * 0.98)] + [p for p in pts if p[0] > x + w * 0.04] + [(x + w / 2, y + 1), (x + w * 0.16, y + 1), (x + w * 0.12, y - h * 0.4)]
        pygame.draw.polygon(s, shade(lit, 0.79) if self.slopes else (106, 146, 74), shp)
        pygame.draw.lines(s, (66, 94, 52), False, pts, 1)

    # ---- seasons
    def draw_range(self, g):
        if self.tone is None:
            return self._range(g)
        with tone_draw(self.tone):
            self._range(g)

    def draw_hill(self, x, y, h, seed):
        if self.tone is None:
            return self._hill(x, y, h, seed)
        with tone_draw(self.tone):
            self._hill(x, y, h, seed)

    def draw_tree(self, x, y, sc, f=1.0, i=0):
        s = self.surf
        if self.winter:                 # bare twigs, with a dab of snow where snow lies, as kit.Piece.tree draws them
            k = kit()
            r, th = 4.4 * sc, 3.0 * sc
            pygame.draw.line(s, k.TRUNK, (x, y), (x, y - th), max(1, int(1.4 * sc)))
            for dx, dy in ((-0.9, -0.5), (-0.45, -1.0), (0.1, -1.15), (0.6, -0.95), (0.95, -0.45)):
                pygame.draw.line(s, (70, 54, 44), (x, y - th), (x + dx * r, y - th + dy * r * 1.25), 1)
            if self.climate != "mild":
                pygame.draw.line(s, k.SNOW, (x - r * 0.7, y - th - r * 0.75), (x - r * 0.1, y - th - r * 1.3), 1)
            return
        if self.season != "summer":     # spring or autumn: the kit's leaf colours (autumn: its three-colour mix by index)
            k = kit()
            oc, dk, mid, lit = k.LEAF_AUTUMN[i % 3] if self.season == "autumn" else k.PAL[self.season]["leaf"]
            pygame.draw.line(s, (92, 70, 50), (x, y), (x, y - 3 * sc), max(1, int(1.4 * sc)))
            r = 4.4 * sc
            cy = y - 3 * sc - r * 0.75
            pygame.draw.circle(s, oc, (x, cy), r + 1)
            pygame.draw.circle(s, dk, (x, cy), r)
            pygame.draw.circle(s, mid, (x - r * 0.28, cy - r * 0.28), r * 0.66)
            pygame.draw.circle(s, lit, (x - r * 0.45, cy - r * 0.45), r * 0.26)
            return
        pygame.draw.line(s, (92, 70, 50), (x, y), (x, y - 3 * sc), max(1, int(1.4 * sc)))
        r = 4.4 * sc
        cy = y - 3 * sc - r * 0.75
        pygame.draw.circle(s, (38, 60, 38), (x, cy), r + 1)
        pygame.draw.circle(s, shade((70, 128, 60), f), (x, cy), r)
        pygame.draw.circle(s, shade((96, 158, 72), f), (x - r * 0.28, cy - r * 0.28), r * 0.66)
        pygame.draw.circle(s, shade((130, 186, 92), f), (x - r * 0.45, cy - r * 0.45), r * 0.26)

    def draw_conifer(self, x, y, sc, f=1.0, i=0):
        s = self.surf
        h, w = 12.5 * sc, 7.2 * sc
        pts = [(x, y - h), (x + w / 2, y - 2 * sc), (x - w / 2, y - 2 * sc)]
        if self.winter:
            k = kit()
            oc, lit, dk = k.WINTER[self.climate]["conifer"]
            pygame.draw.line(s, k.TRUNK, (x, y), (x, y - 2.5 * sc), max(1, int(1.3 * sc)))
            pygame.draw.polygon(s, shade(lit, f), pts)
            pygame.draw.polygon(s, shade(dk, f), [(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)])
            if self.climate != "mild":
                pygame.draw.polygon(s, k.SNOW, [(x, y - h), (x - w * 0.5, y - 2 * sc), (x - w * 0.16, y - 2 * sc),
                                                (x - w * 0.02, y - h * 0.5)])
            pygame.draw.polygon(s, oc, pts, 1)
            return
        pygame.draw.line(s, (92, 70, 50), (x, y), (x, y - 2.5 * sc), max(1, int(1.3 * sc)))
        if self.season != "summer":
            k = kit()
            oc, lit, dk = k.PAL[self.season]["conifer"]
            pygame.draw.polygon(s, lit, pts)
            pygame.draw.polygon(s, dk, [(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)])
            pygame.draw.line(s, k.mix(lit, dk, 0.4), (x - w * 0.3, y - h * 0.45), (x + w * 0.05, y - h * 0.38), 1)
            pygame.draw.polygon(s, oc, pts, 1)
            return
        pygame.draw.polygon(s, shade((66, 120, 70), f), pts)
        pygame.draw.polygon(s, shade((46, 92, 58), f), [(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)])
        pygame.draw.line(s, shade((60, 108, 64), f), (x - w * 0.3, y - h * 0.45), (x + w * 0.05, y - h * 0.38), 1)
        pygame.draw.polygon(s, (34, 56, 40), pts, 1)
