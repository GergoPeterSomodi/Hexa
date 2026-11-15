"""Ground, sea, shore, hills, ridges and woods of the close-up. Everything is drawn at 2x and scaled down at the end."""
import math, random
import pygame
from scene import *
from scene import FIELDS as F
import paint as A
import slopes as SLP

TONES = None                   # the slope tones of this zoom (set by the close-up when the slope rule is on)

C_FARM = (178, 198, 98)
C_GRASS = (146, 186, 86)
C_WOOD = (112, 164, 78)
C_ROCK = (170, 156, 130)
C_SAND = (234, 216, 162)
C_SEA = (71, 143, 192)
C_SHELF = (108, 180, 216)
C_DEEP = (54, 116, 174)
C_FOAM = (232, 246, 250)
SHADOW = (158, 168, 188)       # multiplied onto the ground


class Canvas:
    def __init__(self):
        self.s = pygame.Surface((W, H))
        self.objs = []
        self.routes = PGrid(64)    # roads, streams, fields and towns: hills keep off them
        self.shadow = pygame.Surface((W, H))
        self.shadow.fill((255, 255, 255))
        self.keep = PGrid(64)      # where trees and fields must not stand
        self.coast = []            # shore points in px, with their seaward normals
        self.land_mask = None

    def add(self, key, fn):
        self.objs.append((key, len(self.objs), fn))

    def sh_ell(self, x, y, w, h):
        e = pygame.Rect(0, 0, max(2, w), max(2, h))
        e.center = (x, y)
        pygame.draw.ellipse(self.shadow, SHADOW, e)

    def sh_poly(self, pts):
        pygame.draw.polygon(self.shadow, SHADOW, pts)

    def sh_box(self, x, y, w, h):
        """The ground shadow of a box standing on (x, y), w wide and h tall: it falls to the lower right."""
        L = h * 0.45
        self.sh_poly([(x - w / 2, y), (x + w / 2, y), (x + w / 2 + L, y + L * 0.42), (x - w / 2 + L, y + L * 0.42)])

    def flush_shadows(self):
        small = pygame.transform.smoothscale(self.shadow, (W // 5, H // 5))
        soft = pygame.transform.smoothscale(small, (W, H))
        self.s.blit(soft, (0, 0), special_flags=pygame.BLEND_RGB_MULT)
        self.shadow.fill((255, 255, 255))

    def flush_objects(self):
        for key, _, fn in sorted(self.objs, key=lambda o: (o[0], o[1])):
            fn()
        self.objs = []


def lowres(fn, cell=8):
    """Paint fn(km x, km y) -> colour on a coarse grid and scale it up smoothly."""
    gw, gh = W // cell + 1, H // cell + 1
    buf = bytearray(gw * gh * 3)
    for j in range(gh):
        for i in range(gw):
            c = fn(*K(i * cell, j * cell))
            k = (j * gw + i) * 3
            buf[k], buf[k + 1], buf[k + 2] = c
    img = pygame.image.frombuffer(bytes(buf), (gw, gh), "RGB")
    return pygame.transform.smoothscale(img, (gw * cell, gh * cell))


def clamp8(v):
    return 0 if v < 0 else 255 if v > 255 else int(v)


def hex_lines(surf, col, width=2):
    for c in range(0, 24):
        for r in range(0, 34):
            cx, cy = P(*centre(c, r))
            if -S * 20 < cx < W + S * 20 and -S * 20 < cy < H + S * 20:
                pts = [P(*p) for p in corners(c, r)]
                pygame.draw.lines(surf, col, False, pts[:4], width)


# ---------------------------------------------------------------- sea
def sea_colour(x, y):
    v = land_value(x, y)
    d = max(0.0, min(1.0, (0.5 - v) / 0.5))
    if d < 0.32:
        c = mix(C_SHELF, C_SEA, d / 0.32)
    else:
        c = mix(C_SEA, C_DEEP, (d - 0.32) / 0.68)
    f = 1.0 + (vnoise(x, y, 5.0, 61) - 0.5) * 0.10 + (vnoise(x, y * 2.2, 1.6, 62) - 0.5) * 0.05
    return (clamp8(c[0] * f), clamp8(c[1] * f), clamp8(c[2] * f))


def paint_sea(cv, loops_px):
    cv.s.blit(lowres(sea_colour), (0, 0))
    hex_lines(cv.s, (96, 164, 208), 2)
    # shallow water: three flat bands that follow the shore, each a little lighter
    for base, col, seed in ((64, (92, 166, 208), 41), (38, (116, 188, 222), 42), (17, (150, 212, 232), 43)):
        for lp in loops_px:
            for i in range(0, len(lp), 2):
                x, y = lp[i]
                if -100 < x < W + 100 and -100 < y < H + 100:
                    rr = base * (0.62 + 0.76 * vnoise(x, y, 150.0, seed))
                    pygame.draw.circle(cv.s, col, (x, y), rr)


def paint_waves(cv):
    """Small wave strokes on the open sea, denser and longer near the shore."""
    r = random.Random(7)
    s = cv.s
    for _ in range(520):
        x, y = r.uniform(0, W), r.uniform(H * 0.55, H)
        v = land_value(*K(x, y))
        if v > 0.43:
            continue
        deep = v < 0.25
        col = (104, 170, 214) if deep else (150, 206, 232)
        w = r.uniform(16, 30)
        if r.random() < 0.55:
            pygame.draw.arc(s, col, (x - w, y - 5, w, 10), 0.3, math.pi - 0.3, 2)
            pygame.draw.arc(s, col, (x, y - 5, w, 10), 0.3, math.pi - 0.3, 2)
        else:
            pygame.draw.arc(s, col, (x - w / 2, y - 5, w, 10), 0.3, math.pi - 0.3, 2)
        if r.random() < 0.18:
            pygame.draw.line(s, (214, 238, 248), (x - 4, y - 6), (x + 5, y - 6), 2)


# ---------------------------------------------------------------- land
def land_colour(x, y):
    v = land_value(x, y)
    if v < 0.36:
        return C_GRASS
    farm, woods, rock = F.at(F.farm, x, y), F.at(F.woods, x, y), F.at(F.rock, x, y)
    grass = max(0.0, 1.0 - farm - woods - rock)
    c = [farm * C_FARM[i] + grass * C_GRASS[i] + woods * C_WOOD[i] + rock * C_ROCK[i] for i in range(3)]
    sun = smoothstep(0.72, 0.52, v) * 0.45            # the sunny coastal strip
    c = [c[i] + ((176, 198, 100)[i] - c[i]) * sun for i in range(3)]
    dh = F.at(F.height, x - 1.5, y - 1.5) - F.at(F.height, x + 1.5, y + 1.5)
    roll = vnoise(x - 0.7, y - 0.7, 4.5, 71) - vnoise(x + 0.7, y + 0.7, 4.5, 71)
    roll2 = vnoise(x - 0.35, y - 0.35, 1.7, 73) - vnoise(x + 0.35, y + 0.35, 1.7, 73)
    if TONES:      # the slope rule: the real rise of the land carries the shading, the noise is only a little texture
        f = 1.0 + roll * 0.2 + roll2 * 0.14 + (vnoise(x, y, 2.2, 72) - 0.5) * 0.07
        c = SLP.tone(c[0] * f, c[1] * f, c[2] * f, TONES.soft(TONES.shade, x, y), TONES.soft(TONES.valley, x, y),
                     TONES.soft(TONES.height, x, y))
        return (clamp8(c[0]), clamp8(c[1]), clamp8(c[2]))
    f = 1.0 + max(-0.13, min(0.13, dh * 0.0006)) + roll * 0.55 + roll2 * 0.22 + (vnoise(x, y, 2.2, 72) - 0.5) * 0.07
    return (clamp8(c[0] * f), clamp8(c[1] * f), clamp8(c[2] * f))


def paint_land(cv, loops_px):
    tex = pygame.Surface((W, H), pygame.SRCALPHA)
    tex.blit(lowres(land_colour, 6), (0, 0))
    hex_lines(tex, (110, 148, 72), 2)
    # grass marks: tufts and light dabs, a texture that only shows up close
    r = random.Random(3)
    for _ in range(15000):
        x, y = r.uniform(0, W - 6), r.uniform(4, H - 1)
        kx, ky = K(x, y)
        if vnoise(kx, ky, 2.6, 75) < 0.42:
            continue
        c = tex.get_at((int(x), int(y)))
        if r.random() < 0.6:
            col = A.sh(c, 0.88)
            pygame.draw.line(tex, col, (x, y), (x + 1, y - 5), 2)
            pygame.draw.line(tex, col, (x + 4, y), (x + 5, y - 4), 2)
        else:
            pygame.draw.line(tex, A.sh(c, 1.09), (x, y), (x + 6, y), 2)
    mask = pygame.Surface((W, H), pygame.SRCALPHA)
    for lp in loops_px:
        pygame.draw.polygon(mask, (255, 255, 255, 255), lp)
    tex.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
    cv.s.blit(tex, (0, 0))
    cv.land_mask = mask


def shore_points(loops_px):
    """Shore points inside the view, each with its seaward normal."""
    out = []
    for lp in loops_px:
        n = len(lp)
        run = []
        for i in range(n):
            x, y = lp[i]
            if not (-120 < x < W + 120 and -120 < y < H + 160):
                if run:
                    out.append(run)
                    run = []
                continue
            a, b = lp[(i - 3) % n], lp[(i + 3) % n]
            tx, ty = b[0] - a[0], b[1] - a[1]
            d = math.hypot(tx, ty) or 1.0
            nx, ny = ty / d, -tx / d
            if land_value(*K(x + nx * 14, y + ny * 14)) > land_value(*K(x - nx * 14, y - ny * 14)):
                nx, ny = -nx, -ny
            run.append((x, y, nx, ny))
        if run:
            out.append(run)
    return out


def paint_shore(cv, runs, ports):
    """Sand, rocks, cliffs and foam along the shore. ports: (test(x, y), kind) pairs that fix the shore kind
    ("sand" for a low beach, "quay" for a built harbour edge)."""
    s = cv.s
    r = random.Random(17)

    def kind(x, y, nx, ny):
        kx, ky = K(x - nx * 26, y - ny * 26)
        cl = F.at(F.cliff, kx, ky)
        m = F.at(F.height, *K(x - nx * 60, y - ny * 60))
        for test, kd in ports:
            if test(x, y):
                return kd, 0.0
        if cl > 0.3:
            return ("cliff" if ny > 0.3 else "crag"), cl
        if m < 430 or vnoise(x, y, 260.0, 19) < 0.4:
            return "sand", 0.0
        return "rocks", 0.0

    tagged = [[(p, kind(*p)) for p in run] for run in runs]
    # sand and dark rock rims first
    for run in tagged:
        for (x, y, nx, ny), (kd, cl) in run:
            if kd == "sand":
                rr = 8 + 9 * vnoise(x, y, 120.0, 23)
                pygame.draw.circle(s, C_SAND, (x - nx * 2, y - ny * 2), rr)
            elif kd in ("rocks", "crag"):
                pygame.draw.circle(s, (150, 134, 110), (x - nx * 1, y - ny * 1), 5)
    for run in tagged:
        for (x, y, nx, ny), (kd, cl) in run:
            if kd == "sand" and vnoise(x, y, 60.0, 24) > 0.5:
                pygame.draw.circle(s, (244, 230, 184), (x - nx * 5, y - ny * 5), 4)
    # cliffs that face the viewer: a standing rock face with strata, wet at the foot
    for run in tagged:
        i = 0
        while i < len(run):
            if run[i][1][0] != "cliff":
                i += 1
                continue
            j = i
            while j < len(run) and run[j][1][0] == "cliff":
                j += 1
            seg = run[i:j]
            i = j
            if len(seg) < 16:
                for q_ in range(0, len(seg), 4):
                    A.rock(s, seg[q_][0][0], seg[q_][0][1] + 4, r.uniform(14, 24), r)
                continue
            if seg[0][0][0] > seg[-1][0][0]:
                seg = seg[::-1]
            n = len(seg)
            top, bot = [], []
            for q, ((x, y, nx, ny), (kd, cl)) in enumerate(seg):
                taper = min(1.0, q / 7.0, (n - 1 - q) / 7.0)
                hc = (22 + 50 * min(1.0, cl * 1.3)) * taper * (0.8 + 0.4 * vnoise(x, y, 70.0, 25))
                top.append((x, y))
                bot.append((x + 2, y + hc))
            pygame.draw.polygon(s, (204, 176, 134), top + bot[::-1])
            q = 0
            while q < n - 1:                     # facets: alternate lit and shaded slabs
                step = r.randint(3, 7)
                e = min(n - 1, q + step)
                if r.random() < 0.5:
                    pygame.draw.polygon(s, (176, 148, 112), top[q:e + 1] + bot[q:e + 1][::-1])
                pygame.draw.line(s, (132, 106, 84), top[q], bot[q], 2)
                q = e
            for q in range(n - 1):               # the wet foot and two strata lines
                a0, a1, b0, b1 = top[q], top[q + 1], bot[q], bot[q + 1]
                f0 = (a0[0] + (b0[0] - a0[0]) * 0.74, a0[1] + (b0[1] - a0[1]) * 0.74)
                f1 = (a1[0] + (b1[0] - a1[0]) * 0.74, a1[1] + (b1[1] - a1[1]) * 0.74)
                pygame.draw.polygon(s, (128, 108, 94), [f0, f1, b1, b0])
                for t in (0.3, 0.52):
                    if (q // 5 + int(t * 10)) % 2:
                        g0 = (a0[0], a0[1] + (b0[1] - a0[1]) * t)
                        g1 = (a1[0], a1[1] + (b1[1] - a1[1]) * t)
                        pygame.draw.line(s, (156, 128, 98), g0, g1, 2)
            pygame.draw.lines(s, (92, 74, 60), False, top, 3)
            pygame.draw.lines(s, (70, 110, 150), False, bot, 2)
            for q in range(0, n, 2):             # foam at the foot
                if vnoise(bot[q][0], 0, 40.0, 26) > 0.35:
                    pygame.draw.circle(s, C_FOAM, (bot[q][0] + r.uniform(-3, 3), bot[q][1] + 4), r.uniform(3, 6))
            for q in range(3, n - 3, 3):         # grass hanging over the edge
                pygame.draw.circle(s, (124, 168, 78), (top[q][0], top[q][1] - 1), 4)
    # foam: a line at the water's edge and two broken lines further out
    for run in tagged:
        for q, ((x, y, nx, ny), (kd, cl)) in enumerate(run):
            if kd in ("cliff", "quay"):
                continue
            if vnoise(x, y, 46.0, 27) > 0.28:
                pygame.draw.circle(s, C_FOAM, (x + nx * 6, y + ny * 6), 3.2)
            if q % 2 == 0 and vnoise(x, y, 60.0, 28) > 0.52:
                pygame.draw.circle(s, (206, 234, 244), (x + nx * 19, y + ny * 19), 2.2)
            if q % 2 == 0 and vnoise(x, y, 80.0, 29) > 0.6:
                pygame.draw.circle(s, (176, 220, 238), (x + nx * 36, y + ny * 36), 2)
    # boulders on rocky shores and under crags
    for run in tagged:
        for q, ((x, y, nx, ny), (kd, cl)) in enumerate(run):
            if kd in ("rocks", "crag") and q % 9 == 0:
                d = r.uniform(-4, 16)
                bx, by = x + nx * d + r.uniform(-6, 6), y + ny * d + r.uniform(-4, 4)
                if d > 6:
                    pygame.draw.ellipse(s, C_FOAM, (bx - 14, by - 4, 28, 9))
                A.rock(s, bx, by, r.uniform(13, 28), r, col=r.choice(((150, 140, 126), (166, 150, 128), (132, 124, 114))))
            elif kd == "sand" and q % 23 == 0 and r.random() < 0.5:
                A.rock(s, x - nx * 4, y - ny * 4, r.uniform(8, 13), r)
    cv.coast = [p for run in tagged for p, _ in run]


# ---------------------------------------------------------------- hills and ridges
HILL_LIT, HILL_HI, HILL_SH, HILL_DEEP = (134, 172, 86), (152, 188, 98), (104, 144, 74), (88, 126, 68)
HILL_INK = (56, 80, 46)
CANOPY_LIT = ((82, 134, 62), (108, 160, 74), (138, 186, 92))
CANOPY_SH = ((60, 102, 56), (76, 120, 62), (92, 138, 70))


def canopy(s, x, y, rr, lit, r):
    c = CANOPY_LIT if lit else CANOPY_SH
    pygame.draw.circle(s, c[0], (x, y), rr)
    pygame.draw.circle(s, c[1], (x - rr * 0.28, y - rr * 0.3), rr * 0.62)
    if r.random() < 0.4:
        pygame.draw.circle(s, c[2], (x - rr * 0.45, y - rr * 0.5), rr * 0.24)


def sil_y(top, x):
    for i in range(len(top) - 1):
        a, b = top[i], top[i + 1]
        if a[0] <= x <= b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / ((b[0] - a[0]) or 1e-6)
    return None


def hill(cv, x, y, h, seed, terraces=False, wood=0.5, key=None):
    """A rounded hill standing on (x, y): lit left, shaded right, hachures, a few trees, terraces if farmed."""
    r = random.Random(seed)
    w = h * r.uniform(2.2, 3.3)
    skew = r.uniform(0.85, 1.2)
    n = 28
    top = []
    for i in range(n + 1):
        t = i / n
        tt = t ** skew
        yy = y - h * (0.55 * math.sin(math.pi * tt) ** 0.8 + 0.45 * math.sin(math.pi * tt) ** 2.2) * (1 + 0.05 * math.sin(t * 9 + seed * 7))
        top.append((x - w / 2 + w * t, yy))
    ia = min(range(n + 1), key=lambda i: top[i][1])
    ax, ay = top[ia]

    def draw():
        s = cv.s
        foot = [(x + w / 2 - w * i / 8.0, y + w * 0.03 * math.sin(math.pi * i / 8.0)) for i in range(9)]
        # the hill takes its tone from the ground it stands on, so it grows out of it
        gc = s.get_at((int(min(max(x - w * 0.3, 0), W - 1)), int(min(max(y + 8, 0), H - 1))))
        ok = gc[1] > gc[0] and gc[1] > gc[2] + 40
        HILL_LIT = mix(globals()['HILL_LIT'], gc[:3], 0.5) if ok else globals()['HILL_LIT']
        HILL_HI, HILL_SH, HILL_DEEP = A.sh(HILL_LIT, 1.1), A.sh(HILL_LIT, 0.8), A.sh(HILL_LIT, 0.68)
        pygame.draw.polygon(s, HILL_LIT, top + foot)
        term = [(ax + w * 0.02, ay), (ax + w * 0.1, ay + h * 0.35), (ax + w * 0.13, ay + h * 0.7), (ax + w * 0.12, y + 2)]
        shp = term[::-1] + [p for p in top if p[0] > ax + w * 0.02] + [(x + w / 2, y), (x + w * 0.3, y + w * 0.02)]
        pygame.draw.polygon(s, HILL_SH, shp)
        deep = [term[0], term[1], term[2], (ax + w * 0.2, ay + h * 0.75), (ax + w * 0.17, ay + h * 0.3)]
        pygame.draw.polygon(s, HILL_DEEP, deep)
        left = [p for p in top if p[0] <= ax]
        if len(left) > 4:
            m = len(left)
            hi = left[2:] + [(p[0] + w * 0.03, p[1] + h * 0.2 * math.sin(math.pi * q / (m - 3.0)) + 2) for q, p in list(enumerate(left[2:]))[::-1]]
            pygame.draw.polygon(s, HILL_HI, hi)
        if terraces:        # farmed slopes: dry-stone terraces following the round of the hill
            fr = [0.14, 0.27, 0.4, 0.53, 0.66]
            lines = []
            for f in fr:
                lines.append([(p[0], y - (y - p[1]) * f + w * 0.02 * math.sin(math.pi * q / n)) for q, p in enumerate(top) if 0.05 * n < q < 0.95 * n])
            for q in range(len(lines) - 1):
                if q % 2 == 0:
                    band = [p for p in lines[q] if p[0] < ax + w * 0.08] + [p for p in lines[q + 1] if p[0] < ax + w * 0.08][::-1]
                    if len(band) > 3:
                        pygame.draw.polygon(s, (178, 192, 100) if q % 4 == 0 else (160, 182, 88), band)
            for ln in lines:
                lit = [p for p in ln if p[0] < ax + w * 0.1]
                shd = [p for p in ln if p[0] >= ax + w * 0.1]
                if len(lit) > 1:
                    pygame.draw.lines(s, (98, 132, 66), False, [(p[0], p[1] + 3) for p in lit], 2)
                    pygame.draw.lines(s, (222, 212, 176), False, lit, 2)
                if len(shd) > 1:
                    pygame.draw.lines(s, (150, 158, 118), False, shd, 2)
            for q, ln in enumerate(lines[:-1]):   # olives and vines on the terraces
                for p in ln[1::2]:
                    if r.random() < 0.55:
                        lit = p[0] < ax + w * 0.1
                        pygame.draw.circle(s, (104, 132, 96) if lit else (84, 110, 84), (p[0] + r.uniform(-3, 3), p[1] - 6), 4.5)
                        if lit:
                            pygame.draw.circle(s, (150, 172, 132), (p[0] - 1.5, p[1] - 7.5), 2)
        else:
            for q in range(int(w / 9)):       # hachures down the slopes
                t = r.uniform(0.1, 0.46) if q % 3 else r.uniform(0.6, 0.9)
                px = x - w / 2 + w * t
                py = sil_y(top, px)
                if py is None:
                    continue
                y0 = py + (y - py) * r.uniform(0.25, 0.7)
                lean = -0.02 if t < 0.5 else 0.03
                pygame.draw.line(s, A.sh(HILL_LIT, 0.9) if t < 0.5 else A.sh(HILL_LIT, 0.7), (px, y0), (px + w * lean, y0 + h * 0.14), 2)
        # woods on the hill
        cnt = int(w * h / 900 * wood)
        blobs = []
        for _ in range(cnt * 3):
            px = x + r.uniform(-0.46, 0.46) * w
            py0 = sil_y(top, px)
            if py0 is None:
                continue
            py = py0 + (y - py0) * r.uniform(0.25, 1.0)
            if py - py0 < 9:
                continue
            if vnoise(px, py, 46.0, int(seed * 1000) % 97 + 100) < (0.42 if not terraces else 0.6):
                continue
            blobs.append((py, px))
            if len(blobs) >= cnt:
                break
        for py, px in sorted(blobs):
            canopy(s, px, py, r.uniform(7, 10.5), px < ax + w * 0.11, r)
        for q in range(int(w / 26)):          # tufts and bushes round the foot
            px = x + r.uniform(-0.47, 0.47) * w
            canopy(s, px, y + r.uniform(-3, 6), r.uniform(6, 9.5), px < ax + w * 0.11, r)
        if h > 60 and r.random() < 0.3:       # a rock outcrop near the top
            A.rock(s, ax - w * 0.08, ay + h * 0.2, r.uniform(16, 24), r, col=(168, 160, 138))
        pygame.draw.lines(s, HILL_INK, False, top[2:-2], 3)

    cv.add(y if key is None else key, draw)
    cv.sh_ell(x + w * 0.3, y + 4, w * 0.9, h * 0.34)
    return top


def ridge(cv, g, seed, main=True, wood=0.62, key=None, rocky_from=1700, pre=False, terraces=None):
    """A range standing on the feet of its samples g (dicts x, y, h, apex, m): one silhouette with shaded faces,
    fall lines, minor spurs and woods on the slopes."""
    r = random.Random(seed)
    g = sorted(g, key=lambda p: p["x"])
    n = len(g)
    ctrl = [(g[0]["x"] - g[0]["h"] * 1.35, g[0]["y"])]
    for i, p in enumerate(g):
        wq = p["h"] * 1.2
        if p.get("apex", True):
            ctrl.append((p["x"] - wq * 0.2, p["y"] - p["h"] * 0.86))
            ctrl.append((p["x"], p["y"] - p["h"] * 1.04))
            ctrl.append((p["x"] + wq * 0.2, p["y"] - p["h"] * 0.86))
        else:
            ctrl.append((p["x"], p["y"] - p["h"]))
        if i < n - 1:
            q = g[i + 1]
            if p.get("apex", True) and q.get("apex", True) and q["x"] - p["x"] > (p["h"] + q["h"]) * 0.5:
                t = r.uniform(0.42, 0.58)
                ctrl.append((p["x"] + (q["x"] - p["x"]) * t, (p["y"] + q["y"]) / 2 - min(p["h"], q["h"]) * r.uniform(0.5, 0.7)))
    ctrl.append((g[-1]["x"] + g[-1]["h"] * 1.35, g[-1]["y"]))
    ctrl = [c for i, c in enumerate(ctrl) if i == 0 or c[0] > ctrl[i - 1][0] + 1]
    top = resample(chaikin(ctrl, 2), 9.0)
    sd = int(seed * 997) % 89 + 200
    top = [(px, py + (vnoise(px, 0.0, 34.0, sd) - 0.5) * 9 * min(1.0, i / 3.0, (len(top) - 1 - i) / 3.0)) for i, (px, py) in enumerate(top)]

    def base_y(xq):
        if xq <= g[0]["x"]:
            return g[0]["y"]
        for a, b in zip(g, g[1:]):
            if a["x"] <= xq <= b["x"]:
                return a["y"] + (b["y"] - a["y"]) * (xq - a["x"]) / ((b["x"] - a["x"]) or 1e-6)
        return g[-1]["y"]

    x0, x1 = top[0][0], top[-1][0]
    foot = [(x1 - (x1 - x0) * i / 24.0, base_y(x1 - (x1 - x0) * i / 24.0) + 5) for i in range(25)]
    # peaks and saddles of the smoothed silhouette
    m = len(top)
    peaks = [i for i in range(2, m - 2) if top[i][1] <= top[i - 1][1] and top[i][1] < top[i + 1][1]
             and top[i][1] < base_y(top[i][0]) - 14]
    keep = []
    for i in peaks:
        if keep and i - keep[-1] < 5:
            if top[i][1] < top[keep[-1]][1]:
                keep[-1] = i
            continue
        keep.append(i)
    peaks = keep
    faces = []
    for q, ia in enumerate(peaks):
        ax, ay = top[ia]
        by = base_y(ax)
        h = by - ay
        if q + 1 < len(peaks):
            js = max(range(ia, peaks[q + 1] + 1), key=lambda i: top[i][1])
            sx, sy = top[js]
            wq = sx - ax
            bs = base_y(sx)
            valley = [(sx + (bs - sy) * 0.24 * t, sy + (bs + 5 - sy) * t) for t in (0.33, 0.66, 1.0)]
        else:
            js = m - 1
            wq = top[js][0] - ax
            valley = []
        fall = [(ax + wq * 0.34 * (t ** 0.8) + math.sin(t * 7 + q) * wq * 0.025, ay + (by + 5 - ay) * t) for t in (0, 0.2, 0.4, 0.6, 0.8, 1.0)]
        shp = fall[::-1] + top[ia + 1:js + 1] + valley
        il = peaks[q - 1] if q else 0
        jl = max(range(il, ia + 1), key=lambda i: top[i][1]) if q else 0
        faces.append(dict(ia=ia, ax=ax, ay=ay, by=by, h=h, w=wq, shp=shp, fall=fall, jl=jl, js=js))
    hmax = max((f["h"] for f in faces), default=40)
    mmax = max(p.get("m", 600) for p in g)
    rocky = mmax > rocky_from

    def draw():
        s = cv.s
        HILL_LIT, HILL_HI, HILL_SH, HILL_DEEP = (globals()[q] for q in ("HILL_LIT", "HILL_HI", "HILL_SH", "HILL_DEEP"))
        if TONES and not pre:      # the range takes part of its tone from the shaded ground at its foot
            acc, cnt = [0, 0, 0], 0
            for t in (0.2, 0.35, 0.5, 0.65, 0.8):
                qx = x0 + (x1 - x0) * t
                qy = base_y(qx) + 16
                if 0 <= qx < W and 0 <= qy < H:
                    gc = s.get_at((int(qx), int(qy)))
                    if gc[1] > gc[0] and gc[1] > gc[2] + 40:
                        acc = [acc[i] + gc[i] for i in range(3)]
                        cnt += 1
            if cnt:
                HILL_LIT = mix(HILL_LIT, tuple(v / cnt for v in acc), 0.45)
                HILL_HI, HILL_SH, HILL_DEEP = A.sh(HILL_LIT, 1.1), A.sh(HILL_LIT, 0.8), A.sh(HILL_LIT, 0.68)
        pygame.draw.polygon(s, HILL_LIT, top + foot)
        rock_polys = []
        for f in faces:
            ia, ax, ay, by, h, wq = f["ia"], f["ax"], f["ay"], f["by"], f["h"], f["w"]
            if len(f["shp"]) >= 3:
                pygame.draw.polygon(s, HILL_SH, f["shp"])
                fall = f["fall"]
                deep = fall[:5] + [(fall[4][0] + wq * 0.12, fall[4][1]), (fall[2][0] + wq * 0.16, fall[2][1]), (fall[1][0] + wq * 0.1, fall[1][1])]
                pygame.draw.polygon(s, HILL_DEEP, deep)
            left = top[f["jl"]:ia + 1]
            if len(left) > 3:      # a lighter band under the crest on the lit side
                k = len(left)
                hi = left + [(p[0] + 5, p[1] + h * 0.2 * math.sin(math.pi * i / (k - 1.0)) + 2) for i, p in list(enumerate(left))[::-1]]
                pygame.draw.polygon(s, HILL_HI, hi)
                # a minor spur on the lit face: a thin shaded wedge
                for t in ((0.5,) if k < 14 else (0.36, 0.7)):
                    qx, qy = left[int((k - 1) * t)]
                    fy = base_y(qx) + 4
                    ex = qx - (fy - qy) * 0.12
                    pygame.draw.polygon(s, (120, 158, 80), [(qx, qy + 3), (ex, fy), (ex + (fy - qy) * 0.3, fy)])
                    pygame.draw.line(s, (84, 118, 60), (qx, qy + 3), (ex, fy), 2)
            if rocky and h > hmax * 0.6:     # bare rock at the top of the high ones
                yr = ay + h * 0.3
                tp = [p for p in top[f["jl"]:f["js"] + 1] if p[1] < yr]
                if len(tp) >= 2:
                    teeth = []
                    k = max(2, int((tp[-1][0] - tp[0][0]) / 16))
                    for i in range(k + 1):
                        teeth.append((tp[-1][0] - (tp[-1][0] - tp[0][0]) * i / k, yr + (r.uniform(4, 12) if i % 2 else -3)))
                    pygame.draw.polygon(s, (182, 172, 148), tp + teeth)
                    rp = [p for p in tp if p[0] >= ax] + [q_ for q_ in teeth if q_[0] >= ax + wq * 0.1] + [(ax + wq * 0.08, yr)]
                    if len(rp) >= 3:
                        pygame.draw.polygon(s, (128, 120, 106), rp)
                    rock_polys.append(tp + teeth)
        shps = [f["shp"] for f in faces if len(f["shp"]) >= 3]
        if terraces:          # dry-stone terraces round the lower slopes (terraces(x, y) says where)
            for fq in (0.16, 0.26, 0.36, 0.46, 0.56, 0.66):
                run = []
                for pt in top[2:-2] + [None]:
                    q_ = None
                    if pt is not None:
                        ty_ = base_y(pt[0]) - (base_y(pt[0]) - pt[1]) * fq
                        if terraces(pt[0], ty_):
                            q_ = (pt[0], ty_)
                    if q_:
                        run.append(q_)
                    else:
                        if len(run) > 2:
                            mid = run[len(run) // 2]
                            lit_ = not any(in_poly(mid[0], mid[1], sp) for sp in shps)
                            pygame.draw.lines(s, (96, 130, 64) if lit_ else (78, 110, 60), False, [(a_, b_ + 3) for a_, b_ in run], 2)
                            pygame.draw.lines(s, (222, 212, 176) if lit_ else (160, 166, 124), False, run, 2)
                        run = []
        # the woods on the slopes, row by row from the crest down
        y_top = min(p[1] for p in top)
        y_bot = max(p[1] for p in foot)
        yy = y_top + 10
        while yy < y_bot:
            xx = x0 + r.uniform(0, 14)
            while xx < x1:
                px, py = xx + r.uniform(-4, 4), yy + r.uniform(-4, 4)
                xx += 12.0
                ty = sil_y(top, px)
                if ty is None or py < ty + 9 or py > base_y(px) + 3:
                    continue
                nz = vnoise(px, py, 64.0, sd + 1) * 0.65 + vnoise(px, py, 22.0, sd + 2) * 0.35
                thin = (py - ty) / max(30.0, base_y(px) - ty)          # thinner woods towards the crest
                if nz < 1 - wood - 0.12 * thin + 0.1:
                    if r.random() < 0.05:
                        pygame.draw.line(s, (116, 152, 78), (px, py), (px - 2, py + 11), 2)
                    continue
                if any(in_poly(px, py, rp) for rp in rock_polys):
                    continue
                lit = not any(in_poly(px, py, sp) for sp in shps)
                canopy(s, px, py, r.uniform(7.5, 11.5), lit, r)
            yy += 10.0
        xx = x0 + 6
        while xx < x1 - 6:                      # bushes along the foot, so the range grows out of the ground
            fy = base_y(xx) + 5 + r.uniform(-4, 3)
            if r.random() < 0.8:
                canopy(s, xx, fy, r.uniform(8, 12), not any(in_poly(xx, fy - 12, sp) for sp in shps), r)
            xx += r.uniform(9, 15)
        pygame.draw.lines(s, (48, 66, 42) if main else (62, 86, 50), False, top, 4 if main else 3)
        for f in faces:     # the fall line from each peak, a short ink stroke
            fl = f["fall"]
            pygame.draw.lines(s, (62, 88, 50), False, fl[:3], 2)

    if pre:
        draw()
    else:
        cv.add(max(p["y"] for p in g) if key is None else key, draw)
    for f in faces:
        cv.sh_ell(f["ax"] + f["h"] * 0.8, f["by"] + 6, f["h"] * 2.1, f["h"] * 0.34)
    return top


def data_relief(cv, skip=None, drop=0.0):
    """The frame's ranges and hills at this zoom: same places, same heights, new painting."""
    k = RPX / 60.0 * SS
    rnd = random.Random(5)
    for rg in RELIEF:
        pts = []
        for smp in rg:
            bx, by = P(smp["x"], smp["y"])
            h = SF.hp(smp["m"]) * k * (smp["pf"] if not smp["apex"] else 1.0)
            if not smp["apex"]:
                h *= 0.4 + 0.25 * random.Random(smp["x"] * 7.1 + smp["y"]).random()
            pts.append(dict(x=bx, y=by, h=h, apex=smp["apex"], m=smp["m"], kind=smp["kind"]))
        groups, cur = [], [pts[0]] if pts else []
        for a, b in zip(pts, pts[1:]):
            dx, dy = b["x"] - a["x"], b["y"] - a["y"]
            same = len(cur) < 2 or (dx > 0) == (cur[-1]["x"] - cur[-2]["x"] > 0)
            if abs(dy) <= 0.6 * abs(dx) and abs(dx) > 2 and same:
                cur.append(b)
            else:
                groups.append(cur)
                cur = [b]
        if cur:
            groups.append(cur)
        for g in groups:
            sd = rnd.random()
            if len(g) == 1 and not g[0]["apex"] and g[0]["h"] < 6 * k:
                continue
            for p in g:
                if len(g) == 1:
                    p["apex"] = True
            foot = max(p["y"] for p in g)
            xs = sum(p["x"] for p in g) / len(g)
            if xs < -260 or xs > W + 260 or foot < -20 or foot > H + 300:
                continue
            if skip and skip(xs, foot):
                continue
            if len(g) == 1 and not cv.routes.clear(xs, foot - 20, 70, reach=5):
                continue
            ridge(cv, g, sd, main=g[0]["kind"] == "crest")
    for hl in HILLS:
        sd = rnd.random()
        bx, by = P(hl["x"], hl["y"])
        if bx < -200 or bx > W + 200 or by < -10 or by > H + 120:
            continue
        h = (5.0 + 7.5 * smoothstep(360, 900, hl["m"])) * k * 1.2
        if sd < drop or (skip and skip(bx, by)) or not cv.routes.clear(bx, by - h * 0.2, h * 1.2, reach=5):
            continue
        if TONES and not TONES.keeps_hill(hl["x"], hl["y"]):
            continue      # the shaded ground carries the shape there
        coastal = F.at(F.land, hl["x"], hl["y"] + 9) < 0.75 or F.at(F.farm, hl["x"], hl["y"]) > 0.3
        wd = 0.3 + 0.5 * F.at(F.woods, hl["x"], hl["y"])
        if 0.42 < sd < 0.72:      # a lower shoulder behind, so the hills are not all single humps
            side = 1 if sd < 0.57 else -1
            hill(cv, bx + side * h * 1.25, by - 7, h * 0.64, sd + 0.11, wood=wd, key=by - 1)
        hill(cv, bx, by, h, sd, terraces=coastal and sd < 0.75, wood=wd)
        cv.keep.add(bx, by - h * 0.3, h * 0.9)


# ---------------------------------------------------------------- trees on the ground
def grow_trees(cv, coast_y, veto=None):
    r = random.Random(11)
    for gy in range(-10, H + 70, 27):
        for gx in range(-20, W + 40, 31):
            x, y = gx + r.uniform(-13, 13), gy + r.uniform(-11, 11)
            kx, ky = K(x, y)
            if land_value(kx, ky) < 0.56:
                continue
            woods = F.at(F.woods, kx, ky)
            clump = vnoise(kx, ky, 3.4, 81) * 0.65 + vnoise(kx, ky, 1.2, 82) * 0.35
            p = woods * 0.8 + (clump - 0.5) * 2.0 - 0.3
            cd = coast_y(x) - y
            if cd < 170:
                p -= 0.2
            if r.random() > p or not cv.keep.clear(x, y, 12) or (veto and veto(x, y)):
                continue
            m = F.at(F.height, kx, ky)
            sc = r.uniform(1.2, 2.05)
            roll = r.random()
            tf = SLP.canopy_tone(TONES.soft(TONES.shade, kx, ky), TONES.soft(TONES.valley, kx, ky)) if TONES else 1.0
            if cd < 200 and roll < 0.14:
                fn, w = (lambda a, b, c, d=random.Random(roll): A.stone_pine(cv.s, a, b, c * 1.05, d)), 26
            elif cd < 260 and roll < 0.25:
                fn, w = (lambda a, b, c, d=random.Random(roll): A.cypress(cv.s, a, b, c * 1.1, d)), 8
            elif m > 700 and roll > 0.62 - (m - 700) / 1400.0:
                fn, w = (lambda a, b, c, d=random.Random(roll), f=tf: A.conifer(cv.s, a, b, c * 1.1, d, f)), 16
            else:
                tone = int(vnoise(kx, ky, 2.0, 83) * 3.2) % 3
                fn, w = (lambda a, b, c, d=random.Random(roll), t=tone, f=tf: A.broadleaf(cv.s, a, b, c, d, t, f=f)), 22
            cv.add(y, (lambda f=fn, a=x, b=y, c=sc: f(a, b, c)))
            cv.sh_ell(x + w * sc * 0.45, y + 2, w * sc * 1.25, w * sc * 0.42)
