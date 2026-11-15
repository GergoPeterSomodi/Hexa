"""Drawing pieces for the close-up: trees, houses, churches, walls, ships. All sizes are in drawing px (2x)."""
import math, random
import pygame

INK = (52, 44, 46)
ROOFS = [(204, 94, 62), (214, 108, 68), (190, 84, 58), (220, 122, 78), (198, 100, 70)]
SLATE = (126, 134, 148)
WALLS = [(240, 228, 196), (232, 200, 140), (234, 192, 166), (246, 240, 228), (226, 210, 170), (236, 178, 128), (222, 160, 132)]
STONE = (222, 210, 184)
STONE_D = (176, 162, 138)
WINDOW = (78, 62, 64)
SHUTTER = (74, 122, 92)


def sh(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))))


def mixc(a, b, t):
    return (int(a[0] + (b[0] - a[0]) * t), int(a[1] + (b[1] - a[1]) * t), int(a[2] + (b[2] - a[2]) * t))


def poly(s, col, pts, ink=INK, w=2):
    pygame.draw.polygon(s, col, pts)
    if ink:
        pygame.draw.polygon(s, ink, pts, w)


def rect(s, col, x, y, w, h, ink=INK, lw=2):
    r = pygame.Rect(round(x), round(y), max(1, round(w)), max(1, round(h)))
    pygame.draw.rect(s, col, r)
    if ink:
        pygame.draw.rect(s, ink, r, lw)


# ---------------------------------------------------------------- trees
LEAF = [((58, 104, 54), (84, 140, 64), (116, 172, 80), (150, 198, 100)),     # chestnut / oak
        ((54, 98, 60), (76, 130, 70), (104, 160, 84), (136, 186, 104)),      # darker wood
        ((70, 112, 50), (100, 148, 60), (134, 180, 74), (168, 204, 96))]     # sunny green
OLIVE = ((86, 108, 84), (122, 146, 112), (156, 176, 140), (190, 204, 172))
TREE_INK = (36, 58, 38)
TRUNK = (96, 72, 52)


def broadleaf(s, x, y, sc, r, tone=0, ink=True):
    """A round tree of three lobes: ink rim, shadow side, lit lobes, a highlight."""
    d, m, l, hl = LEAF[tone % 3] if tone < 9 else OLIVE
    R = 11.0 * sc
    th = 6.0 * sc
    pygame.draw.line(s, TRUNK, (x, y), (x, y - th - R * 0.4), max(2, int(2.6 * sc)))
    cy = y - th - R * 0.8
    lobes = [(0, 0, 1.0), (-0.55 + r.uniform(-.1, .1), 0.25, 0.72), (0.6 + r.uniform(-.1, .1), 0.3, 0.68), (0.1, -0.5, 0.7)]
    if ink:
        for dx, dy, f in lobes:
            pygame.draw.circle(s, TREE_INK, (x + dx * R, cy + dy * R), R * f + 2)
    for dx, dy, f in lobes:
        pygame.draw.circle(s, d, (x + dx * R, cy + dy * R), R * f)
    for dx, dy, f in lobes:
        pygame.draw.circle(s, m, (x + dx * R - R * 0.14, cy + dy * R - R * 0.16), R * f * 0.82)
    for dx, dy, f in lobes[:2] + lobes[3:]:
        pygame.draw.circle(s, l, (x + dx * R - R * 0.3, cy + dy * R - R * 0.32), R * f * 0.5)
    pygame.draw.circle(s, hl, (x - R * 0.42, cy - R * 0.62), R * 0.2)
    pygame.draw.circle(s, hl, (x - R * 0.8, cy + R * 0.02), R * 0.13)


def conifer(s, x, y, sc, r):
    """A fir in three tiers, shaded on the right."""
    h, w = 34 * sc, 19 * sc
    pygame.draw.line(s, TRUNK, (x, y), (x, y - 6 * sc), max(2, int(2.4 * sc)))
    lit, dk, hl = (62, 116, 70), (42, 86, 58), (92, 146, 84)
    for i in range(3):
        t0 = i / 3.0
        yb = y - 5 * sc - h * t0 * 0.8
        yt = yb - h * 0.46
        ww = w * (1 - t0 * 0.5)
        pts = [(x, yt), (x + ww / 2, yb), (x + ww * 0.2, yb - 2 * sc), (x, yb + 1.5 * sc), (x - ww * 0.2, yb - 2 * sc), (x - ww / 2, yb)]
        pygame.draw.polygon(s, lit, pts)
        pygame.draw.polygon(s, dk, [(x, yt), (x + ww / 2, yb), (x + ww * 0.2, yb - 2 * sc), (x + ww * 0.04, yb + 1.5 * sc)])
        pygame.draw.line(s, hl, (x - ww * 0.3, yb - h * 0.14), (x - ww * 0.06, yt + h * 0.12), max(1, int(1.6 * sc)))
        pygame.draw.polygon(s, (30, 52, 40), pts, 2)


def cypress(s, x, y, sc, r):
    h, w = 40 * sc * r.uniform(0.85, 1.15), 9 * sc
    pygame.draw.line(s, TRUNK, (x, y), (x, y - 4 * sc), 2)
    pts = [(x, y - h), (x + w * 0.38, y - h * 0.7), (x + w / 2, y - h * 0.3), (x + w * 0.3, y - 3 * sc), (x - w * 0.3, y - 3 * sc),
           (x - w / 2, y - h * 0.3), (x - w * 0.38, y - h * 0.7)]
    pygame.draw.polygon(s, (50, 92, 62), pts)
    pygame.draw.polygon(s, (36, 70, 52), [pts[0], pts[1], pts[2], pts[3], (x + w * 0.05, y - 3 * sc), (x + w * 0.1, y - h * 0.6)])
    pygame.draw.line(s, (82, 128, 80), (x - w * 0.2, y - h * 0.35), (x - w * 0.1, y - h * 0.75), 2)
    pygame.draw.polygon(s, (28, 48, 38), pts, 2)


def stone_pine(s, x, y, sc, r):
    """An umbrella pine: a bare leaning trunk under a flat crown."""
    h = 30 * sc * r.uniform(0.9, 1.15)
    lean = r.uniform(-3, 4) * sc
    pygame.draw.line(s, (112, 80, 58), (x, y), (x + lean, y - h), max(2, int(2.8 * sc)))
    pygame.draw.line(s, (112, 80, 58), (x + lean * 0.7, y - h * 0.75), (x + lean + 7 * sc, y - h - 1 * sc), 2)
    cx, cy = x + lean + 1 * sc, y - h - 3 * sc
    w, hh = 30 * sc, 12 * sc
    for dx, dy, f in ((0, 0, 1.0), (-0.34, 0.12, 0.62), (0.36, 0.14, 0.6)):
        e = pygame.Rect(0, 0, w * f + 4, hh * f + 4)
        e.center = (cx + dx * w, cy + dy * hh)
        pygame.draw.ellipse(s, (30, 56, 40), e)
    for dx, dy, f in ((0, 0, 1.0), (-0.34, 0.12, 0.62), (0.36, 0.14, 0.6)):
        e = pygame.Rect(0, 0, w * f, hh * f)
        e.center = (cx + dx * w, cy + dy * hh)
        pygame.draw.ellipse(s, (52, 104, 62), e)
    for dx, dy, f in ((-0.06, -0.1, 0.8), (-0.36, 0.04, 0.5)):
        e = pygame.Rect(0, 0, w * f, hh * f * 0.7)
        e.center = (cx + dx * w, cy + dy * hh - 1)
        pygame.draw.ellipse(s, (84, 140, 76), e)
    e = pygame.Rect(0, 0, w * 0.3, hh * 0.3)
    e.center = (cx - w * 0.22, cy - hh * 0.22)
    pygame.draw.ellipse(s, (122, 172, 96), e)


def olive(s, x, y, sc, r):
    R = 6.5 * sc
    pygame.draw.line(s, (104, 84, 66), (x, y), (x, y - 4 * sc), 2)
    cy = y - 4 * sc - R * 0.6
    pygame.draw.circle(s, (50, 70, 56), (x, cy), R + 1.5)
    pygame.draw.circle(s, OLIVE[0], (x, cy), R)
    pygame.draw.circle(s, OLIVE[1], (x - R * 0.2, cy - R * 0.2), R * 0.76)
    pygame.draw.circle(s, OLIVE[2], (x - R * 0.36, cy - R * 0.36), R * 0.4)


def bush(s, x, y, sc, r, tone=0):
    d, m, l, hl = LEAF[tone % 3]
    R = 5.5 * sc
    pygame.draw.circle(s, TREE_INK, (x, y - R * 0.7), R + 1.5)
    pygame.draw.circle(s, d, (x, y - R * 0.7), R)
    pygame.draw.circle(s, m, (x - R * 0.2, y - R * 0.9), R * 0.72)
    pygame.draw.circle(s, l, (x - R * 0.38, y - R * 1.08), R * 0.34)


# ---------------------------------------------------------------- houses
def windows(s, x0, y0, w, h, floors, r, shutters=False, f=1.0):
    """Rows of small windows on a wall rect (x0, y0, w, h); f scales the window size."""
    f = max(1.0, f)
    cols = max(1, int(w / (13 * f)))
    ww, wh = round(5 * f), round(7 * f)
    for f in range(floors):
        yy = y0 + h * (f + 0.5) / floors - wh / 2 - (2 if floors > 1 else 0)
        for c in range(cols):
            if r.random() < 0.12:
                continue
            xx = x0 + w * (c + 0.5) / cols - ww / 2
            if shutters and r.random() < 0.6:
                pygame.draw.rect(s, SHUTTER, (round(xx) - 2, round(yy), ww + 4, wh))
            pygame.draw.rect(s, WINDOW, (round(xx), round(yy), ww, wh))
            pygame.draw.line(s, (252, 246, 228), (round(xx) - 1, round(yy) + wh), (round(xx) + ww, round(yy) + wh), 1)


def tile_rows(s, quad, col, n, r):
    """Tile shading on a roof slope quad (bottom-left, bottom-right, top-right, top-left)."""
    bl, br, tr, tl = quad
    for i in range(1, n + 1):
        t = i / (n + 1.0)
        a = (bl[0] + (tl[0] - bl[0]) * t, bl[1] + (tl[1] - bl[1]) * t)
        b = (br[0] + (tr[0] - br[0]) * t, br[1] + (tr[1] - br[1]) * t)
        pygame.draw.line(s, sh(col, 0.86), a, b, 1)
        # a few lit tiles
        for q in range(int((b[0] - a[0]) / 12) + 1):
            if r.random() < 0.45:
                u = r.random()
                px, py = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
                pygame.draw.line(s, sh(col, 1.14), (px, py - 3), (px + 4, py - 3), 2)


def house(s, x, y, r, sc=1.0, kind=None, wall=None, roof=None, floors=None, w=None):
    """A house on its foot (x, y): the front wall, a shaded right end, a tiled roof, windows and a door."""
    w = (w or r.uniform(26, 36)) * sc
    floors = floors or r.choice((1, 2, 2, 2, 3))
    hw = (9 + 9.5 * floors) * sc
    rh = r.uniform(11, 15) * sc
    wall = wall or r.choice(WALLS)
    roof = roof or r.choice(ROOFS)
    kind = kind or r.choice(("eaves", "eaves", "gable"))
    x0, top = x - w / 2, y - hw
    if kind == "eaves":
        rect(s, wall, x0, top, w, hw, None)
        pygame.draw.rect(s, sh(wall, 0.82), (round(x0 + w * 0.8), round(top), round(w * 0.2) + 1, round(hw)))
        pygame.draw.rect(s, sh(wall, 0.86), (round(x0), round(top), round(w), 4))          # the shadow of the eaves
        windows(s, x0 + 2, top + 4, w * 0.78, hw - 6, floors, r, shutters=floors > 1, f=sc * 0.8)
        if r.random() < 0.8:
            dx = x0 + w * r.choice((0.25, 0.45, 0.6))
            pygame.draw.rect(s, (86, 62, 50), (round(dx), round(y - 10 * sc), round(6 * sc), round(10 * sc)))
        pygame.draw.rect(s, INK, (round(x0), round(top), round(w), round(hw)), 2)
        e = 3 * sc
        q = [(x0 - e, top + 1), (x0 + w + e, top + 1), (x0 + w - 2 * sc, top - rh), (x0 + 2 * sc, top - rh)]
        pygame.draw.polygon(s, roof, q)
        tile_rows(s, q, roof, 2, r)
        pygame.draw.polygon(s, sh(roof, 0.78), [q[1], q[2], (x0 + w * 0.76, top - rh), (x0 + w * 0.8, top + 1)])
        pygame.draw.line(s, sh(roof, 1.18), (q[3][0] + 2, q[3][1] + 2), (x0 + w * 0.74, top - rh + 2), 2)
        pygame.draw.polygon(s, INK, q, 2)
        if r.random() < 0.5:   # a chimney
            cx = x0 + w * r.uniform(0.2, 0.6)
            rect(s, sh(wall, 0.95), cx, top - rh - 5 * sc, 5 * sc, 8 * sc, INK, 1)
    else:
        rect(s, wall, x0, top, w, hw, None)
        gable = [(x0, top), (x0 + w / 2, top - rh), (x0 + w, top)]
        pygame.draw.polygon(s, wall, gable)
        pygame.draw.polygon(s, sh(wall, 0.9), [(x0 + w / 2, top - rh), (x0 + w, top), (x0 + w / 2 + 3, top)])
        windows(s, x0 + 2, top + 2, w - 4, hw - 4, floors, r, shutters=floors > 1, f=sc * 0.8)
        pygame.draw.rect(s, WINDOW, (round(x0 + w / 2 - 2), round(top - rh * 0.5), 5, 6))
        if r.random() < 0.8:
            pygame.draw.rect(s, (86, 62, 50), (round(x0 + w * 0.42), round(y - 10 * sc), round(6 * sc), round(10 * sc)))
        bx, by = 10 * sc, -8 * sc
        slope = [(x0 + w + 2 * sc, top + 1), (x0 + w + 2 * sc + bx, top + 1 + by), (x0 + w / 2 + bx, top - rh + by), (x0 + w / 2, top - rh)]
        pygame.draw.polygon(s, sh(roof, 0.8), slope)
        tile_rows(s, [slope[0], slope[1], slope[2], slope[3]], sh(roof, 0.8), 1, r)
        pygame.draw.polygon(s, INK, slope, 2)
        pygame.draw.line(s, roof, (x0 - 2 * sc, top + 1), (x0 + w / 2, top - rh), max(3, int(4 * sc)))
        pygame.draw.line(s, INK, (x0 - 3 * sc, top + 2), (x0 + w / 2, top - rh - 2), 1)
        pygame.draw.lines(s, INK, False, [(x0, top), (x0, y), (x0 + w, y), (x0 + w, top)], 2)
    return w, hw + rh


def palazzo(s, x, y, r, sc=1.0, w=None, floors=4, wall=None, roof=None, arcade=True, stripes=False):
    """A tall Genoese house: a narrow front, rows of shuttered windows, an arcade at the foot, a low roof."""
    w = (w or r.uniform(26, 38)) * sc
    hw = (10 + 10.5 * floors) * sc
    wall = wall or r.choice(WALLS)
    roof = roof or r.choice(ROOFS + [SLATE])
    x0, top = x - w / 2, y - hw
    rect(s, wall, x0, top, w, hw, None)
    if stripes:
        for i in range(0, int(hw), 8):
            if (i // 8) % 2:
                pygame.draw.rect(s, (84, 80, 86), (round(x0), round(top + i), round(w), 4))
    pygame.draw.rect(s, sh(wall, 0.8), (round(x0 + w * 0.82), round(top), round(w * 0.18) + 1, round(hw)))
    pygame.draw.rect(s, sh(wall, 0.86), (round(x0), round(top), round(w), 4))
    ah = 12 * sc if arcade else 0
    windows(s, x0 + 2, top + 5, w * 0.8, hw - ah - 6, floors - (1 if arcade else 0), r, shutters=True, f=sc * 0.8)
    if arcade:
        n = max(2, int(w / 13))
        for i in range(n):
            ax = x0 + w * (i + 0.5) / n
            aw = w / n * 0.62
            pygame.draw.rect(s, (70, 54, 54), (round(ax - aw / 2), round(y - ah), round(aw), round(ah)),
                             border_top_left_radius=int(aw / 2), border_top_right_radius=int(aw / 2))
    pygame.draw.rect(s, INK, (round(x0), round(top), round(w), round(hw)), 2)
    rh = 8 * sc
    q = [(x0 - 3 * sc, top + 1), (x0 + w + 3 * sc, top + 1), (x0 + w - 3 * sc, top - rh), (x0 + 3 * sc, top - rh)]
    pygame.draw.polygon(s, roof, q)
    tile_rows(s, q, roof, 1, r)
    pygame.draw.polygon(s, sh(roof, 0.78), [q[1], q[2], (x0 + w * 0.78, top - rh), (x0 + w * 0.82, top + 1)])
    pygame.draw.polygon(s, INK, q, 2)
    return w, hw + rh


def tower(s, x, y, w, h, col=STONE, cap="battle", r=None, roof=(160, 70, 50)):
    """A square tower: lit front, shaded right, battlements or a pointed cap."""
    x0 = x - w / 2
    rect(s, col, x0, y - h, w, h, None)
    pygame.draw.rect(s, sh(col, 0.8), (round(x0 + w * 0.62), round(y - h), round(w * 0.38) + 1, round(h)))
    for i in range(1, int(h / 26) + 1):
        pygame.draw.line(s, sh(col, 0.88), (x0 + 2, y - h + i * 26), (x0 + w * 0.6, y - h + i * 26), 1)
    pygame.draw.rect(s, WINDOW, (round(x - 2), round(y - h * 0.62), 4, 8))
    pygame.draw.rect(s, INK, (round(x0), round(y - h), round(w), round(h)), 2)
    if cap == "battle":
        rect(s, col, x0 - 3, y - h - 7, w + 6, 9, None)
        pygame.draw.rect(s, sh(col, 0.8), (round(x0 + w * 0.62), round(y - h - 7), round(w * 0.38) + 4, 9))
        pygame.draw.rect(s, INK, (round(x0 - 3), round(y - h - 7), round(w + 6), 9), 2)
        n = max(2, int(w / 9))
        for i in range(n + 1):
            tx = x0 - 3 + (w + 6 - 5) * i / n
            rect(s, col if i < n * 0.6 else sh(col, 0.8), tx, y - h - 13, 5, 6, INK, 1)
    elif cap == "spire":
        pts = [(x0 - 3, y - h), (x0 + w + 3, y - h), (x, y - h - w * 1.3)]
        pygame.draw.polygon(s, roof, pts)
        pygame.draw.polygon(s, sh(roof, 0.76), [(x + w * 0.12, y - h), (x0 + w + 3, y - h), (x, y - h - w * 1.3)])
        pygame.draw.polygon(s, INK, pts, 2)
    elif cap == "dome":
        e = pygame.Rect(0, 0, w + 4, w + 4)
        e.center = (x, y - h)
        pygame.draw.circle(s, (150, 160, 150), (x, y - h), w / 2 + 2, draw_top_left=True, draw_top_right=True)
        pygame.draw.circle(s, (186, 194, 182), (x - 2, y - h), w / 2 - 3, draw_top_left=True)
        pygame.draw.arc(s, INK, e, 0, math.pi, 2)
        pygame.draw.line(s, INK, (x0 - 2, y - h), (x0 + w + 2, y - h), 2)
        pygame.draw.line(s, INK, (x, y - h - w / 2 - 2), (x, y - h - w / 2 - 9), 2)


def belfry(s, x, y, w, h, col=STONE):
    """Arched openings near the top of a bell tower."""
    for dx in (-w * 0.2, w * 0.12):
        a = pygame.Rect(0, 0, w * 0.22, 12)
        a.midtop = (x + dx, y - h + 6)
        pygame.draw.rect(s, WINDOW, a, border_top_left_radius=4, border_top_right_radius=4)


def church(s, x, y, r, sc=1.0, stripes=False, side="right", dome=False, cap="spire", col=None, roof=None):
    """A church: gabled front with a door and a round window, the nave roof running back, a bell tower beside it."""
    col = col or (238, 228, 206)
    roof = roof or ROOFS[0]
    w, hw, rh = 34 * sc, 26 * sc, 15 * sc
    x0, top = x - w / 2, y - hw
    # the nave roof and the bell tower stand behind the front
    bx, by = 26 * sc, -17 * sc
    slope = [(x0 + w + 2, top + 1), (x0 + w + 2 + bx, top + 1 + by), (x + bx, top - rh + by), (x, top - rh)]
    side_wall = [(x0 + w, y), (x0 + w + bx, y + by), (x0 + w + bx, top + by), (x0 + w, top)]
    tw, th = 15 * sc, 66 * sc
    tx = x0 + w + bx - 2 * sc if side == "right" else x0 - tw * 0.6
    ty = y + by * 0.8 if side == "right" else y - 4 * sc
    if side == "left":
        tower(s, tx, ty, tw, th, col, cap=cap, roof=sh(roof, 0.9))
        belfry(s, tx, ty, tw, th)
    pygame.draw.polygon(s, sh(col, 0.8), side_wall)
    for i in range(3):
        pygame.draw.rect(s, WINDOW, (round(x0 + w + bx * (i + 0.6) / 3.4), round(top + by * (i + 0.6) / 3.4 + 6 * sc), 3, 8))
    pygame.draw.polygon(s, INK, side_wall, 2)
    pygame.draw.polygon(s, sh(roof, 0.8), slope)
    tile_rows(s, slope, sh(roof, 0.8), 2, r)
    pygame.draw.polygon(s, INK, slope, 2)
    if dome:
        dx, dy = x + bx * 0.75, top - rh + by * 0.75
        rect(s, col, dx - 10 * sc, dy - 8 * sc, 20 * sc, 12 * sc, INK, 2)
        pygame.draw.circle(s, (140, 152, 146), (dx, dy - 8 * sc), 12 * sc, draw_top_left=True, draw_top_right=True)
        pygame.draw.circle(s, (182, 192, 180), (dx - 3 * sc, dy - 8 * sc), 8 * sc, draw_top_left=True)
        e = pygame.Rect(0, 0, 24 * sc, 24 * sc)
        e.center = (dx, dy - 8 * sc)
        pygame.draw.arc(s, INK, e, 0, math.pi, 2)
        pygame.draw.line(s, INK, (dx, dy - 20 * sc), (dx, dy - 27 * sc), 2)
        pygame.draw.line(s, INK, (dx - 3 * sc, dy - 24 * sc), (dx + 3 * sc, dy - 24 * sc), 2)
    if side == "right":
        tower(s, tx, ty, tw, th, col, cap=cap, roof=sh(roof, 0.9))
        belfry(s, tx, ty, tw, th)
    front = [(x0, y), (x0, top), (x, top - rh), (x0 + w, top), (x0 + w, y)]
    pygame.draw.polygon(s, col, front)
    if stripes:   # the black and white bands of the Genoese churches
        for i in range(0, int(hw + rh), 7):
            if (i // 7) % 2 == 0:
                continue
            yy = y - i
            half = w / 2 if yy > top else w / 2 * max(0.0, (yy - (top - rh)) / rh)
            if half > 1:
                pygame.draw.rect(s, (80, 78, 86), (round(x - half), round(yy - 3), round(half * 2), 3))
    pygame.draw.circle(s, WINDOW, (x, top - 1 * sc), 5 * sc)
    pygame.draw.circle(s, (250, 232, 170), (x, top - 1 * sc), 5 * sc, 2)
    d = pygame.Rect(0, 0, 10 * sc, 15 * sc)
    d.midbottom = (x, y)
    pygame.draw.rect(s, (92, 64, 50), d, border_top_left_radius=int(5 * sc), border_top_right_radius=int(5 * sc))
    pygame.draw.polygon(s, INK, front, 2)
    pygame.draw.line(s, roof, (x0 - 2, top + 1), (x, top - rh - 1), 3)
    pygame.draw.line(s, roof, (x, top - rh - 1), (x0 + w + 2, top + 1), 3)
    pygame.draw.line(s, INK, (x, top - rh - 2), (x, top - rh - 11 * sc), 2)
    pygame.draw.line(s, INK, (x - 3 * sc, top - rh - 8 * sc), (x + 3 * sc, top - rh - 8 * sc), 2)


def wall_run(s, pts, h=20, col=(220, 208, 180), teeth=True):
    """A town wall along a ground polyline, standing upright, with battlements."""
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        if a[0] > b[0]:
            a, b = b, a
        dx, dy = b[0] - a[0], b[1] - a[1]
        steep = abs(dy) > abs(dx) * 1.2
        c = sh(col, 0.84) if (steep and dy < 0) or (dy < -abs(dx) * 0.5) else col
        if steep:
            c = sh(col, 0.9)
        q = [a, b, (b[0], b[1] - h), (a[0], a[1] - h)]
        pygame.draw.polygon(s, c, q)
        n = int(math.dist(a, b) / 9)
        if teeth:
            for t in range(n + 1):
                if t % 2 == 0:
                    px, py = a[0] + dx * t / max(1, n), a[1] + dy * t / max(1, n)
                    pygame.draw.rect(s, c, (round(px - 2), round(py - h - 5), 5, 6))
                    pygame.draw.rect(s, INK, (round(px - 2), round(py - h - 5), 5, 6), 1)
        pygame.draw.line(s, sh(col, 0.74), (a[0], a[1] - h * 0.45), (b[0], b[1] - h * 0.45), 1)
        pygame.draw.line(s, INK, q[3], q[2], 2)
        pygame.draw.line(s, INK, a, b, 2)


def gate(s, x, y, sc=1.0, col=(220, 208, 180)):
    """A town gate between two round-topped towers."""
    w = 24 * sc
    rect(s, col, x - w / 2, y - 30 * sc, w, 30 * sc, INK, 2)
    a = pygame.Rect(0, 0, 12 * sc, 20 * sc)
    a.midbottom = (x, y)
    pygame.draw.rect(s, (62, 48, 48), a, border_top_left_radius=int(6 * sc), border_top_right_radius=int(6 * sc))
    for dx in (-1, 1):
        tower(s, x + dx * (w / 2 + 5 * sc), y + 2, 13 * sc, 44 * sc, col)


# ---------------------------------------------------------------- ships
HULL = (124, 82, 54)
HULL_D = (88, 58, 44)
SAIL = (248, 242, 228)
SAIL_D = (216, 208, 190)
RED = (196, 52, 46)


def water_under(s, x, y, w, col=(46, 104, 150)):
    e = pygame.Rect(0, 0, w, max(6, w * 0.14))
    e.center = (x + w * 0.05, y + 2)
    pygame.draw.ellipse(s, col, e)


def sail_square(s, cx, top, w, h, belly, cross=False, d=1):
    """A square sail filled by the wind, bellying towards d."""
    b = belly * d
    pts = [(cx - w / 2, top), (cx + w / 2, top), (cx + w / 2 + b * 0.5, top + h * 0.5), (cx + w * 0.46, top + h),
           (cx + b * 0.6, top + h * 1.06), (cx - w * 0.46, top + h), (cx - w / 2 + b * 0.5, top + h * 0.5)]
    pygame.draw.polygon(s, SAIL, pts)
    pygame.draw.polygon(s, SAIL_D, [(cx + w * 0.18, top), (cx + w / 2, top), (cx + w / 2 + b * 0.5, top + h * 0.5), (cx + w * 0.46, top + h),
                                    (cx + w * 0.2 + b * 0.5, top + h * 1.03)])
    for q in (-0.2, 0.18):
        pygame.draw.line(s, (228, 220, 200), (cx + w * q, top + 2), (cx + w * q + b * 0.5, top + h), 1)
    if cross:
        t = max(3, int(w * 0.11))
        pygame.draw.line(s, RED, (cx + b * 0.3, top + h * 0.14), (cx + b * 0.5, top + h * 0.9), t)
        pygame.draw.line(s, RED, (cx - w * 0.36 + b * 0.4, top + h * 0.48), (cx + w * 0.38 + b * 0.4, top + h * 0.48), t)
    pygame.draw.polygon(s, INK, pts, 2)
    pygame.draw.line(s, (96, 70, 50), (cx - w / 2 - 3, top), (cx + w / 2 + 3, top), 3)


def pennant(s, x, y, d=1, n=22, col=RED):
    pts = [(x, y), (x + d * n, y + 2), (x + d * n * 0.7, y + 5), (x + d * n, y + 8), (x, y + 8)]
    pygame.draw.polygon(s, (250, 246, 236), pts)
    pygame.draw.line(s, col, (x, y + 4), (x + d * n * 0.8, y + 4), 2)
    pygame.draw.line(s, col, (x + d * 6, y), (x + d * 6, y + 8), 2)
    pygame.draw.polygon(s, INK, pts, 1)


def wake(s, x, y, length, d=1, col=(214, 236, 246)):
    """Foam trailing behind a hull that sails towards d."""
    for i in range(5):
        t = i / 4.0
        x0 = x - d * (length * t)
        pygame.draw.line(s, col, (x0, y + 1 + t * 5), (x0 - d * length * 0.16, y + 2 + t * 7), 2)
        pygame.draw.line(s, col, (x0, y - 3 - t * 3), (x0 - d * length * 0.14, y - 4 - t * 4), 1)


def carrack(s, x, y, sc=1.0, d=1, cross=True, furled=False):
    """A three-masted round ship seen from the side, sailing towards d (+1 right, -1 left)."""
    L = 62 * sc

    def X(u):
        return x + d * u * sc

    water_under(s, x, y, L * 2.3)
    if not furled:
        wake(s, X(-52), y, 60 * sc, d)
        for i in range(2):   # the bow wave
            pygame.draw.arc(s, (226, 242, 248), (min(X(50 + i * 7), X(64 + i * 7)), y - 5 + i * 2, 14 * sc, 9), 0.3, 2.8, 2)
    hull = [(X(-56), y - 30 * sc), (X(-34), y - 28 * sc), (X(-30), y - 17 * sc), (X(28), y - 15 * sc), (X(34), y - 25 * sc), (X(58), y - 28 * sc),
            (X(64), y - 30 * sc), (X(50), y - 6 * sc), (X(38), y), (X(-40), y), (X(-52), y - 8 * sc)]
    pygame.draw.polygon(s, HULL, hull)
    pygame.draw.polygon(s, HULL_D, [(X(-52), y - 8 * sc), (X(50), y - 6 * sc), (X(38), y), (X(-40), y)])
    pygame.draw.line(s, (186, 140, 90), (X(-54), y - 15 * sc), (X(55), y - 13 * sc), 2)
    pygame.draw.line(s, (186, 140, 90), (X(-55), y - 24 * sc), (X(-33), y - 22 * sc), 2)
    for u in (-20, -8, 4, 16):
        pygame.draw.rect(s, (60, 44, 40), (round(X(u)) - 2, round(y - 12 * sc), 4, 4))
    pygame.draw.polygon(s, INK, hull, 2)
    pygame.draw.line(s, INK, (X(58), y - 28 * sc), (X(86), y - 40 * sc), 2)            # the bowsprit
    masts = [(-40, 62, 0), (-4, 104, 1), (36, 78, 2)]
    for u, h, i in masts:
        pygame.draw.line(s, (84, 62, 48), (X(u), y - 16 * sc), (X(u), y - h * sc), max(2, int(3 * sc)))
    top = y - 104 * sc
    # the rigging: stays and shrouds
    for a, b in (((X(-4), top), (X(86), y - 40 * sc)), ((X(-4), top), (X(-56), y - 30 * sc)), ((X(36), y - 78 * sc), (X(86), y - 40 * sc)),
                 ((X(-4), top + 8 * sc), (X(-18), y - 17 * sc)), ((X(-4), top + 8 * sc), (X(10), y - 16 * sc)),
                 ((X(36), y - 70 * sc), (X(26), y - 16 * sc)), ((X(36), y - 70 * sc), (X(46), y - 22 * sc))):
        pygame.draw.line(s, (70, 58, 56), a, b, 1)
    if furled:
        for u, h, w in ((-4, 86, 50), (36, 64, 36)):
            pygame.draw.line(s, (96, 70, 50), (X(u) - w * sc / 2, y - h * sc), (X(u) + w * sc / 2, y - h * sc), 3)
            pygame.draw.line(s, SAIL_D, (X(u) - w * sc / 2 + 3, y - h * sc + 3), (X(u) + w * sc / 2 - 3, y - h * sc + 3), 4)
        pygame.draw.line(s, (96, 70, 50), (X(-52), y - 40 * sc), (X(-28), y - 62 * sc), 3)
    else:
        sail_square(s, X(-4), y - 86 * sc, 52 * sc, 50 * sc, 9 * sc, cross=cross, d=d)
        sail_square(s, X(-4), y - 102 * sc, 26 * sc, 14 * sc, 4 * sc, d=d)
        sail_square(s, X(36), y - 68 * sc, 36 * sc, 36 * sc, 7 * sc, d=d)
        lat = [(X(-58), y - 34 * sc), (X(-26), y - 68 * sc), (X(-34), y - 30 * sc)]
        pygame.draw.polygon(s, SAIL, lat)
        pygame.draw.polygon(s, SAIL_D, [lat[1], lat[2], (X(-44), y - 40 * sc)])
        pygame.draw.polygon(s, INK, lat, 2)
        pygame.draw.line(s, (96, 70, 50), (X(-60), y - 32 * sc), (X(-24), y - 70 * sc), 3)
    pennant(s, X(-4), top - 9 * sc, d=-d, n=24 * sc)
    pygame.draw.line(s, (84, 62, 48), (X(-4), top), (X(-4), top - 9 * sc), 2)


def galley(s, x, y, sc=1.0, d=1, sail=True):
    """A Genoese galley: a long low hull, a bank of oars, one lateen sail, a striped awning aft."""
    def X(u):
        return x + d * u * sc

    water_under(s, x, y, 190 * sc)
    wake(s, X(-78), y, 46 * sc, d)
    for i in range(11):     # the oars
        u = -50 + i * 10
        pygame.draw.line(s, (236, 226, 200), (X(u), y - 8 * sc), (X(u - 9), y + 7 * sc), 2)
        pygame.draw.line(s, (220, 240, 248), (X(u - 11), y + 7 * sc), (X(u - 6), y + 7 * sc), 2)
    hull = [(X(-78), y - 20 * sc), (X(-58), y - 12 * sc), (X(66), y - 11 * sc), (X(96), y - 13 * sc), (X(70), y - 3 * sc), (X(-64), y - 2 * sc), (X(-76), y - 8 * sc)]
    pygame.draw.polygon(s, HULL, hull)
    pygame.draw.line(s, RED, (X(-60), y - 9 * sc), (X(72), y - 8 * sc), max(2, int(2.5 * sc)))
    pygame.draw.polygon(s, INK, hull, 2)
    aw = [(X(-78), y - 21 * sc), (X(-52), y - 14 * sc), (X(-52), y - 26 * sc), (X(-74), y - 32 * sc)]
    pygame.draw.polygon(s, (250, 244, 230), aw)
    for i in range(3):
        t0, t1 = (i * 2 + 0.5) / 6, (i * 2 + 1.5) / 6
        q = [(aw[0][0] + (aw[1][0] - aw[0][0]) * t0, aw[0][1] + (aw[1][1] - aw[0][1]) * t0), (aw[0][0] + (aw[1][0] - aw[0][0]) * t1, aw[0][1] + (aw[1][1] - aw[0][1]) * t1),
             (aw[3][0] + (aw[2][0] - aw[3][0]) * t1, aw[3][1] + (aw[2][1] - aw[3][1]) * t1), (aw[3][0] + (aw[2][0] - aw[3][0]) * t0, aw[3][1] + (aw[2][1] - aw[3][1]) * t0)]
        pygame.draw.polygon(s, RED, q)
    pygame.draw.polygon(s, INK, aw, 2)
    pygame.draw.line(s, (84, 62, 48), (X(6), y - 11 * sc), (X(6), y - 62 * sc), max(2, int(3 * sc)))
    if sail:
        lat = [(X(-34), y - 30 * sc), (X(36), y - 82 * sc), (X(30), y - 22 * sc)]
        pygame.draw.polygon(s, SAIL, lat)
        pygame.draw.polygon(s, SAIL_D, [lat[1], lat[2], (X(14), y - 30 * sc), (X(22), y - 60 * sc)])
        pygame.draw.polygon(s, INK, lat, 2)
    pygame.draw.line(s, (96, 70, 50), (X(-38), y - 27 * sc), (X(40), y - 85 * sc), 3)
    pennant(s, X(6), y - 70 * sc, d=-d, n=18 * sc)


def boat(s, x, y, sc=1.0, d=1, sail=True, col=None):
    """A fishing boat with a small lateen sail, or a bare rowing boat."""
    def X(u):
        return x + d * u * sc

    col = col or HULL
    water_under(s, x, y, 46 * sc)
    hull = [(X(-17), y - 9 * sc), (X(19), y - 10 * sc), (X(12), y), (X(-12), y)]
    pygame.draw.polygon(s, col, hull)
    pygame.draw.line(s, (240, 232, 210), (X(-16), y - 7 * sc), (X(17), y - 8 * sc), 2)
    pygame.draw.polygon(s, INK, hull, 2)
    if sail:
        pygame.draw.line(s, (84, 62, 48), (X(0), y - 9 * sc), (X(0), y - 34 * sc), 2)
        lat = [(X(-16), y - 16 * sc), (X(12), y - 42 * sc), (X(10), y - 13 * sc)]
        pygame.draw.polygon(s, SAIL, lat)
        pygame.draw.polygon(s, SAIL_D, [lat[1], lat[2], (X(3), y - 20 * sc)])
        pygame.draw.polygon(s, INK, lat, 2)
        pygame.draw.line(s, (220, 238, 246), (X(-20), y + 2), (X(-34), y + 4), 2)
    else:
        pygame.draw.line(s, (236, 226, 200), (X(-2), y - 6 * sc), (X(-12), y + 5 * sc), 2)
        pygame.draw.line(s, (236, 226, 200), (X(4), y - 6 * sc), (X(14), y + 5 * sc), 2)


def lanterna(s, x, y, sc=1.0):
    """Genoa's lighthouse: two square shafts with bracketed galleries, the city's arms, a lantern on top."""
    c, cd = (242, 236, 222), (198, 190, 174)

    def shaft(yb, w, h):
        rect(s, c, x - w / 2, yb - h, w, h, None)
        pygame.draw.rect(s, cd, (round(x + w * 0.12), round(yb - h), round(w * 0.38) + 1, round(h)))
        for i in range(1, int(h / 18)):
            pygame.draw.line(s, sh(c, 0.9), (x - w / 2 + 2, yb - i * 18), (x + w * 0.1, yb - i * 18), 1)
        pygame.draw.rect(s, INK, (round(x - w / 2), round(yb - h), round(w), round(h)), 2)

    def gallery(yb, w):
        rect(s, c, x - w / 2, yb - 7 * sc, w, 7 * sc, None)
        pygame.draw.rect(s, cd, (round(x + w * 0.12), round(yb - 7 * sc), round(w * 0.38) + 1, round(7 * sc)))
        pygame.draw.rect(s, INK, (round(x - w / 2), round(yb - 7 * sc), round(w), round(7 * sc)), 2)
        for i in range(5):
            bx = x - w / 2 + 2 + (w - 4) * i / 4.0
            pygame.draw.line(s, INK, (bx, yb), (bx, yb + 4 * sc), 2)

    w1, h1, w2, h2 = 26 * sc, 66 * sc, 19 * sc, 50 * sc
    shaft(y, w1, h1)
    # the arms of Genoa: a red cross on white
    pygame.draw.rect(s, (250, 248, 240), (round(x - 7 * sc), round(y - 30 * sc), round(11 * sc), round(13 * sc)))
    pygame.draw.line(s, RED, (x - 1.5 * sc, y - 30 * sc), (x - 1.5 * sc, y - 18 * sc), max(2, int(2.6 * sc)))
    pygame.draw.line(s, RED, (x - 7 * sc, y - 24 * sc), (x + 4 * sc, y - 24 * sc), max(2, int(2.6 * sc)))
    pygame.draw.rect(s, INK, (round(x - 7 * sc), round(y - 30 * sc), round(11 * sc), round(13 * sc)), 1)
    pygame.draw.rect(s, WINDOW, (round(x - 2 * sc), round(y - 54 * sc), round(4 * sc), round(8 * sc)))
    gallery(y - h1, w1 + 10 * sc)
    shaft(y - h1 - 7 * sc, w2, h2)
    pygame.draw.rect(s, WINDOW, (round(x - 2 * sc), round(y - h1 - 36 * sc), round(4 * sc), round(8 * sc)))
    yt = y - h1 - 7 * sc - h2
    gallery(yt, w2 + 9 * sc)
    yl = yt - 7 * sc
    rect(s, (252, 220, 110), x - 6 * sc, yl - 13 * sc, 12 * sc, 13 * sc, INK, 2)
    pygame.draw.line(s, INK, (x, yl - 13 * sc), (x, yl), 1)
    pygame.draw.circle(s, (150, 160, 156), (x, yl - 13 * sc), 8 * sc, draw_top_left=True, draw_top_right=True)
    e = pygame.Rect(0, 0, 16 * sc, 16 * sc)
    e.center = (x, yl - 13 * sc)
    pygame.draw.arc(s, INK, e, 0, math.pi, 2)
    pygame.draw.line(s, INK, (x - 8 * sc, yl - 13 * sc), (x + 8 * sc, yl - 13 * sc), 2)
    pygame.draw.line(s, INK, (x, yl - 21 * sc), (x, yl - 30 * sc), 2)
    return yl - 7 * sc


def bridge(s, a, b, arches=3, w=9):
    """A stone bridge from a to b (ground points): the deck and the arched face towards the viewer."""
    face_h = 15
    face = [(a[0], a[1] + w * 0.5), (b[0], b[1] + w * 0.5), (b[0], b[1] + w * 0.5 + face_h), (a[0], a[1] + w * 0.5 + face_h)]
    pygame.draw.polygon(s, (176, 164, 140), face)
    for q in range(arches):
        t = (q + 0.5) / arches
        cx, cy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + w * 0.5 + face_h
        rr = pygame.Rect(0, 0, abs(b[0] - a[0]) / arches * 0.66, face_h * 1.5)
        rr.center = (cx, cy)
        pygame.draw.ellipse(s, (48, 92, 136), rr)
        pygame.draw.arc(s, INK, rr, 0, math.pi, 2)
    pygame.draw.polygon(s, INK, face, 2)
    deck = [(a[0], a[1] - w), (b[0], b[1] - w), (b[0], b[1] + w * 0.5), (a[0], a[1] + w * 0.5)]
    pygame.draw.polygon(s, (222, 208, 176), deck)
    pygame.draw.polygon(s, INK, deck, 2)
    pygame.draw.line(s, (244, 234, 208), (a[0] + 2, a[1] - w + 3), (b[0] - 2, b[1] - w + 3), 2)


def cairn(s, x, y, sc=1.0):
    for dx, dy, r in ((0, 0, 9), (1, -9, 7), (0, -17, 5)):
        pygame.draw.circle(s, (156, 146, 132), (x + dx * sc, y + dy * sc), r * sc)
        pygame.draw.circle(s, (190, 180, 164), (x + dx * sc - 2, y + dy * sc - 2), r * sc * 0.5)
        pygame.draw.circle(s, INK, (x + dx * sc, y + dy * sc), r * sc, 2)
    pygame.draw.line(s, INK, (x, y - 20 * sc), (x, y - 46 * sc), 2)
    pygame.draw.polygon(s, RED, [(x, y - 46 * sc), (x + 17 * sc, y - 42 * sc), (x, y - 37 * sc)])
    pygame.draw.polygon(s, INK, [(x, y - 46 * sc), (x + 17 * sc, y - 42 * sc), (x, y - 37 * sc)], 1)


def rock(s, x, y, w, r, col=(150, 140, 126)):
    h = w * r.uniform(0.5, 0.8)
    pts = [(x - w / 2, y), (x - w * 0.3, y - h * 0.8), (x + w * 0.05, y - h), (x + w * 0.4, y - h * 0.6), (x + w / 2, y)]
    pygame.draw.polygon(s, col, pts)
    pygame.draw.polygon(s, sh(col, 0.76), [(x + w * 0.05, y - h), (x + w * 0.4, y - h * 0.6), (x + w / 2, y), (x + w * 0.1, y)])
    pygame.draw.polygon(s, INK, pts, 2)


def mule_train(s, x, y, d=1, n=3):
    """A drover and pack mules on the road: a few px each, only seen up close."""
    for i in range(n):
        mx = x - d * i * 20
        pygame.draw.ellipse(s, (112, 86, 66), (mx - 7, y - 11, 14, 7))
        pygame.draw.rect(s, (232, 222, 196), (mx - 4, y - 15, 8, 5))
        pygame.draw.rect(s, INK, (mx - 4, y - 15, 8, 5), 1)
        pygame.draw.line(s, (72, 54, 46), (mx - 5, y - 5), (mx - 5, y), 2)
        pygame.draw.line(s, (72, 54, 46), (mx + 5, y - 5), (mx + 5, y), 2)
        pygame.draw.circle(s, (112, 86, 66), (mx + d * 8, y - 11), 3)
    px = x + d * 18
    pygame.draw.line(s, (60, 70, 110), (px, y), (px, y - 9), 3)
    pygame.draw.circle(s, (232, 196, 160), (px, y - 12), 3)
    pygame.draw.line(s, INK, (px + d * 3, y), (px + d * 5, y - 15), 1)
