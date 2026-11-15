"""Soft slope shading for the ground plane, from real heights (the slope rule of the style frame).

The land should rise as one body from the coast to the crest. This module builds one smoothed height field for the
frame and derives three gentle tones from it: a lit/shaded slope tone (light from the upper left), a valley tone
(floors a little darker, crests a little lighter) and a height tint. The renderers multiply them onto the ground
colour; the standing hills and ranges take their foot colour from the shaded ground.

Switches (environment):
  STYLE_FRAME_SLOPES=0     turn the slope shading off (the old renders stay reproducible). Default: on.
  STYLE_FRAME_HEIGHTS=PATH a derived height grid (JSON, as written by tools/worldmap/closeup_3d/extract_area.py from
                           NOAA ETOPO 2022; kept outside the repository). Without it the per-hex heights of the map
                           are used: the land still rises, but the valleys between the hexes are missing.

The map's coast is the hex coast, which lies up to about 20 km off the real one. The fine heights are therefore
sampled through a soft warp that moves the real shore onto the drawn shore and fades out inland, and the drawn rivers
and streams are pressed into the field, so that the shading agrees with what the map shows.

Credit for the fine heights: NOAA National Centers for Environmental Information. 2022: ETOPO 2022 15 Arc-Second
Global Relief Model. doi:10.25921/fd45-gt74
"""
import json, math, os

from frame import X0, Y0, vnoise, smoothstep
from geo import LON_W, LAT_N, DEG, COS

ON = os.environ.get("STYLE_FRAME_SLOPES", "1") != "0"
HEIGHTS = os.environ.get("STYLE_FRAME_HEIGHTS", "")

SLOPE_K = 26.0        # metres per km towards the light at which a slope is about three quarters lit
VALLEY_M = (12.0, 150.0)   # metres below (above) the wide mean at which a floor (crest) starts and is fully toned
CARVE = 0.42          # how far a drawn river or stream presses the ground down (a share of the height)
CARVE_KM = 2.3
FINE_SHARE, BROAD_SHARE = 0.8, 0.3   # the slope tone mixes the fine relief with the big shapes
# The light on the slopes: from the left and a little from above, as on the standing mountains (lit faces left).
# A light from straight above-left would put every coast that faces the viewer in the shade.
SLOPE_LIGHT = (-0.9, -0.44)
FLAT_M_KM = (7.0, 26.0)   # ground that rises less than this (metres per km) gets no slope tone, more than this the full tone
FLAT_SHADE_M_KM = (15.0, 40.0)   # the same for the shaded side and the floors: a dark tone on a gentle ramp reads as a stain


class HeightGrid:
    """A derived lon/lat height grid: rows north to south, columns west to east, whole metres."""
    def __init__(self, path):
        d = json.load(open(path, encoding="utf-8"))
        self.z = d["z"]
        self.lon0, self.lat0, self.d_lon, self.d_lat = d["lon0"], d["lat0"], d["d_lon"], d["d_lat"]
        self.cols, self.rows = d["cols"], d["rows"]

    def km_of(self, c, r):
        return ((self.lon0 + c * self.d_lon - LON_W) * DEG * COS, (LAT_N - (self.lat0 - r * self.d_lat)) * DEG)

    def at(self, x, y):
        """The height in metres at a km position (bilinear); None outside the grid."""
        fc = (LON_W + x / (DEG * COS) - self.lon0) / self.d_lon
        fr = (self.lat0 - (LAT_N - y / DEG)) / self.d_lat
        c, r = int(math.floor(fc)), int(math.floor(fr))
        if c < 0 or r < 0 or c >= self.cols - 1 or r >= self.rows - 1:
            return None
        tx, ty = fc - c, fr - r
        z = self.z
        a = z[r][c] + (z[r][c + 1] - z[r][c]) * tx
        b = z[r + 1][c] + (z[r + 1][c + 1] - z[r + 1][c]) * tx
        return a + (b - a) * ty


def _blur(a, w, h, passes=1):
    """Binomial blur (1 4 6 4 1), separable; each pass has a sigma of one cell."""
    for _ in range(passes):
        b = [0.0] * (w * h)
        for j in range(h):
            o = j * w
            for i in range(w):
                i0, i1, i3, i4 = max(i - 2, 0), max(i - 1, 0), min(i + 1, w - 1), min(i + 2, w - 1)
                b[o + i] = (a[o + i0] + 4 * a[o + i1] + 6 * a[o + i] + 4 * a[o + i3] + a[o + i4]) * 0.0625
        a = [0.0] * (w * h)
        for j in range(h):
            j0, j1, j3, j4 = max(j - 2, 0) * w, max(j - 1, 0) * w, min(j + 1, h - 1) * w, min(j + 2, h - 1) * w
            o = j * w
            for i in range(w):
                a[o + i] = (b[j0 + i] + 4 * b[j1 + i] + 6 * b[o + i] + 4 * b[j3 + i] + b[j4 + i]) * 0.0625
    return a


def _box(a, w, h, rad, passes=2):
    """Box blur by running sums; two passes give a tent."""
    n = 2 * rad + 1
    for _ in range(passes):
        b = [0.0] * (w * h)
        for j in range(h):
            o = j * w
            s = sum(a[o + min(max(i, 0), w - 1)] for i in range(-rad, rad + 1))
            for i in range(w):
                b[o + i] = s / n
                s += a[o + min(i + rad + 1, w - 1)] - a[o + max(i - rad, 0)]
        a = [0.0] * (w * h)
        for i in range(w):
            s = sum(b[min(max(j, 0), h - 1) * w + i] for j in range(-rad, rad + 1))
            for j in range(h):
                a[j * w + i] = s / n
                s += b[min(j + rad + 1, h - 1) * w + i] - b[max(j - rad, 0) * w + i]
    return a


class Slopes:
    """The smoothed height field on the frame's 1 km grid, and the tones derived from it."""
    def __init__(self, world, F, extra_water=(), heights=None):
        self.w, self.h = F.w, F.h
        w, h = self.w, self.h
        n = w * h
        path = HEIGHTS if heights is None else heights
        self.fine = bool(path) and os.path.exists(path)
        land = [1.0 if v >= 0.5 else 0.0 for v in F.land]
        if self.fine:
            src = HeightGrid(path)
            dx, dy = self._warp(F, src, land)
            H = [0.0] * n
            for j in range(h):
                y = Y0 + j - 2
                for i in range(w):
                    k = j * w + i
                    if land[k]:
                        z = src.at(X0 + i - 2 + dx[k], y + dy[k])
                        H[k] = max(0.0, z) if z is not None else F.height[k]
        else:
            H = [F.height[k] * land[k] for k in range(n)]
        # the drawn water lies in a valley: press the field down along rivers and streams
        self._base, self._press = H, [0.0] * n
        self.add_water([rv["pts"] for rv in world["rivers"]] + list(world["streams"]) + list(extra_water))

    def add_water(self, lines):
        """Press drawn water (lines of km points, at most about 1 km apart) into the field."""
        w, h = self.w, self.h
        press = self._press
        rad = int(CARVE_KM * 2) + 1
        for line in lines:
            for (x, y) in line:
                ci, cj = int(round(x - X0 + 2)), int(round(y - Y0 + 2))
                for j in range(max(cj - rad, 0), min(cj + rad + 1, h)):
                    for i in range(max(ci - rad, 0), min(ci + rad + 1, w)):
                        d2 = (X0 + i - 2 - x) ** 2 + (Y0 + j - 2 - y) ** 2
                        v = math.exp(-d2 / (CARVE_KM * CARVE_KM))
                        if v > press[j * w + i]:
                            press[j * w + i] = v
        self.raw = [self._base[k] * (1.0 - CARVE * press[k]) for k in range(w * h)]
        self._levels = {}

    def level(self, km):
        """The tones for one zoom: km is how far the heights are smoothed (about 11 px on screen reads well)."""
        key = round(km, 2)
        if key not in self._levels:
            self._levels[key] = Tones(self.raw, self.w, self.h, km)
        return self._levels[key]

    def _warp(self, F, src, land):
        """A displacement (km) per cell that carries the real shore onto the drawn shore and fades out inland."""
        w, h = self.w, self.h
        n = w * h
        # the real shore: land cells of the source grid that touch the sea
        cell = 8.0
        real = {}
        for r in range(1, src.rows - 1):
            row = src.z[r]
            for c in range(1, src.cols - 1):
                if row[c] > 0 and (row[c - 1] <= 0 or row[c + 1] <= 0 or src.z[r - 1][c] <= 0 or src.z[r + 1][c] <= 0):
                    x, y = src.km_of(c, r)
                    real.setdefault((int(x // cell), int(y // cell)), []).append((x, y))

        def nearest_real(x, y, reach=5):
            cx, cy = int(x // cell), int(y // cell)
            best = None
            for i in range(cx - reach, cx + reach + 1):
                for j in range(cy - reach, cy + reach + 1):
                    for p in real.get((i, j), ()):
                        d = (p[0] - x) ** 2 + (p[1] - y) ** 2
                        if best is None or d < best[0]:
                            best = (d, p)
            return best

        # the drawn shore: land cells of the frame that touch the sea (not at the rim of the grid)
        shore = []
        for j in range(3, h - 3):
            for i in range(3, w - 3):
                k = j * w + i
                if land[k] and not (land[k - 1] and land[k + 1] and land[k - w] and land[k + w]):
                    x, y = X0 + i - 2, Y0 + j - 2
                    b = nearest_real(x, y)
                    v = (b[1][0] - x, b[1][1] - y) if b and b[0] < 38.0 ** 2 else (0.0, 0.0)
                    shore.append([k, x, y, v[0], v[1]])
        # even the shifts out along the shore
        bucket = {}
        for s in shore:
            bucket.setdefault((int(s[1] // 10), int(s[2] // 10)), []).append(s)
        smooth = []
        for s in shore:
            cx, cy = int(s[1] // 10), int(s[2] // 10)
            ax = ay = an = 0.0
            for i in range(cx - 1, cx + 2):
                for j in range(cy - 1, cy + 2):
                    for q in bucket.get((i, j), ()):
                        if (q[1] - s[1]) ** 2 + (q[2] - s[2]) ** 2 < 144.0:
                            ax += q[3]
                            ay += q[4]
                            an += 1
            smooth.append((ax / an, ay / an))
        # the nearest shore point of every cell: a two-pass distance sweep that carries the source along
        INF = 1e9
        dist = [INF] * n
        srcx = [0.0] * n
        srcy = [0.0] * n
        idx = [-1] * n
        for q, s in enumerate(shore):
            k = s[0]
            dist[k], srcx[k], srcy[k], idx[k] = 0.0, s[1], s[2], q

        def relax(k, k2, x, y):
            if idx[k2] < 0:
                return
            d = math.hypot(srcx[k2] - x, srcy[k2] - y)
            if d < dist[k]:
                dist[k], srcx[k], srcy[k], idx[k] = d, srcx[k2], srcy[k2], idx[k2]

        for sweep in (0, 1):
            js = range(h) if sweep == 0 else range(h - 1, -1, -1)
            for j in js:
                iis = range(w) if sweep == 0 else range(w - 1, -1, -1)
                y = Y0 + j - 2
                for i in iis:
                    k = j * w + i
                    x = X0 + i - 2
                    for di, dj in ((-1, 0), (0, -1), (-1, -1), (1, -1)) if sweep == 0 else ((1, 0), (0, 1), (1, 1), (-1, 1)):
                        i2, j2 = i + di, j + dj
                        if 0 <= i2 < w and 0 <= j2 < h:
                            relax(k, j2 * w + i2, x, y)
        dx = [0.0] * n
        dy = [0.0] * n
        for k in range(n):
            q = idx[k]
            if q < 0:
                continue
            vx, vy = smooth[q]
            reach = max(30.0, 1.9 * math.hypot(vx, vy))
            f = max(0.0, 1.0 - dist[k] / reach)
            dx[k], dy[k] = vx * f, vy * f
        return _box(dx, w, h, 3, 2), _box(dy, w, h, 3, 2)

class Tones:
    """Slope, valley and height tones of the height field smoothed to one scale."""
    def __init__(self, raw, w, h, km):
        self.w, self.h, self.km = w, h, km
        n = w * h
        H = _blur(raw, w, h, max(1, int(round(km * km))))
        broad = _box(H, w, h, max(2, int(round(km * 1.5))), 2)          # the big shapes: a whole flank lit or shaded
        wide = _box(H, w, h, max(3, int(round(km * 1.3)) + 2), 2)
        self.height = H
        lx, ly = SLOPE_LIGHT
        ln = math.hypot(lx, ly)
        lx, ly = lx / ln, ly / ln
        kf = SLOPE_K * (1.7 / km) ** 0.4
        kb = kf * 0.7
        self.shade = [0.0] * n       # -1 (turned away from the light) .. +1 (facing it)
        self.valley = [0.0] * n      # -1 (crest) .. +1 (valley floor)
        self.steep = [0.0] * n       # 0 (flat) .. 1 (steep): where the shading carries the shape by itself
        grad = [0.0] * n
        for j in range(h):
            ja, jb = max(j - 1, 0), min(j + 1, h - 1)
            for i in range(w):
                ia, ib = max(i - 1, 0), min(i + 1, w - 1)
                k = j * w + i
                gx = (H[j * w + ib] - H[j * w + ia]) / (ib - ia)
                gy = (H[jb * w + i] - H[ja * w + i]) / (jb - ja)
                bx = (broad[j * w + ib] - broad[j * w + ia]) / (ib - ia)
                by = (broad[jb * w + i] - broad[ja * w + i]) / (jb - ja)
                v = FINE_SHARE * math.tanh(-(gx * lx + gy * ly) / kf) + BROAD_SHARE * math.tanh(-(bx * lx + by * ly) / kb)
                self.shade[k] = max(-1.0, min(1.0, v))
                grad[k] = math.hypot(gx, gy)
                self.steep[k] = math.tanh(grad[k] / (kf * 1.4))
                d = wide[k] - H[k]
                if d >= 0:
                    self.valley[k] = smoothstep(VALLEY_M[0], VALLEY_M[1], d)
                else:
                    self.valley[k] = -smoothstep(VALLEY_M[0], VALLEY_M[1], -d)
        # flat land stays plain: the big shapes must not spill their shade onto the plain at a range's foot
        near = _blur(grad, w, h, 2)
        for k in range(n):
            g = smoothstep(FLAT_M_KM[0], FLAT_M_KM[1], near[k])
            gs = smoothstep(FLAT_SHADE_M_KM[0], FLAT_SHADE_M_KM[1], near[k])
            self.shade[k] *= g if self.shade[k] > 0 else gs
            if self.valley[k] > 0:
                self.valley[k] *= gs

    def keeps_hill(self, x, y):
        """Whether a rounded hill may stand at a km position: not on a valley floor, not on flat ground, and only
        some of them where the slope is steep enough to show the rise by itself."""
        va, st = self.at(self.valley, x, y), self.at(self.steep, x, y)
        if va > 0.2 or (st < 0.12 and va > -0.1):
            return False
        hsh = ((int(x * 7.3) * 73856093) ^ (int(y * 7.3) * 19349663)) & 1023
        return hsh / 1023.0 < (0.5 if st > 0.45 else 0.75)

    # ------------------------------------------------------------ sampling
    def at(self, arr, x, y):
        """Bilinear sample at a km position."""
        fx, fy = x - X0 + 2, y - Y0 + 2
        i = min(max(int(math.floor(fx)), 0), self.w - 2)
        j = min(max(int(math.floor(fy)), 0), self.h - 2)
        tx, ty = min(max(fx - i, 0.0), 1.0), min(max(fy - j, 0.0), 1.0)
        k = j * self.w + i
        a = arr[k] + (arr[k + 1] - arr[k]) * tx
        b = arr[k + self.w] + (arr[k + self.w + 1] - arr[k + self.w]) * tx
        return a + (b - a) * ty

    def soft(self, arr, x, y):
        """Smooth sample (cubic B-spline) at a km position: no creases when the field is seen much enlarged."""
        fx, fy = x - X0 + 2, y - Y0 + 2
        i, j = int(math.floor(fx)), int(math.floor(fy))
        tx, ty = fx - i, fy - j

        def wts(t):
            return ((1 - t) ** 3 / 6.0, (3 * t ** 3 - 6 * t ** 2 + 4) / 6.0, (-3 * t ** 3 + 3 * t ** 2 + 3 * t + 1) / 6.0, t ** 3 / 6.0)
        wx, wy = wts(tx), wts(ty)
        tot = 0.0
        for b in range(4):
            jj = min(max(j - 1 + b, 0), self.h - 1) * self.w
            row = 0.0
            for a in range(4):
                row += arr[jj + min(max(i - 1 + a, 0), self.w - 1)] * wx[a]
            tot += row * wy[b]
        return tot


# ---------------------------------------------------------------- the tones
LIT_GAIN, SHADE_GAIN = 0.16, 0.16      # how much a fully lit / fully shaded slope lightens / darkens the ground
FLOOR_GAIN, CREST_GAIN = 0.10, 0.05    # valley floors darker, crests lighter
HIGH_TINT = (190, 206, 128)            # high ground goes a little paler and drier
HIGH_GAIN = 0.30


def tone(r, g, b, sh, va, m):
    """The ground colour (r, g, b) on a slope: sh -1..1 (shaded..lit), va -1..1 (crest..floor), m metres."""
    green = smoothstep(-5.0, 20.0, g - r)       # stone takes less of every tone, so it stays light and clean
    t = smoothstep(100.0, 850.0, m) * HIGH_GAIN * green
    sh *= 0.55 + 0.45 * green
    r, g, b = r + (HIGH_TINT[0] - r) * t, g + (HIGH_TINT[1] - g) * t, b + (HIGH_TINT[2] - b) * t
    if sh >= 0:
        f = 1.0 + LIT_GAIN * sh
        r, g, b = r * f + 6.0 * sh, g * f + 4.0 * sh, b * f - 4.0 * sh       # lit slopes turn warm
    else:
        f = 1.0 + SHADE_GAIN * sh
        r, g, b = r * f + 9.0 * sh, g * f + 1.0 * sh, b * f - 7.0 * sh       # shaded slopes turn cool
    f = 1.0 - (FLOOR_GAIN * va if va > 0 else CREST_GAIN * va)
    return r * f, g * f, b * f


def canopy_tone(sh, va):
    """A brightness factor for a tree or a wood standing on a slope, so the woods follow the land."""
    return 1.0 + (0.14 * sh if sh >= 0 else 0.2 * sh) - (0.07 * va if va > 0 else 0.0)
