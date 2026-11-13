"""Goods objects: one code-drawn object per trade good, for the map's Goods view (deposits).

Every good shows the good itself (or how it is made), never a generic crate, and each has its own silhouette
and colour so no two read alike, even at map size.

Style: the Kenney hexagon pack's objects. Flat colours, lit from the top-left (top faces lightest, left faces
mid, right faces darker), a thin darker edge on each part and a soft dark outline round the whole object.

All drawing is in the 120 x 140 tile space (the object sits on the hex, ground line near y = 100) at K x
supersampling, and is scaled down at the end. `draw_good(key, size)` returns a transparent tile-frame surface
`size` px tall (width size * 6 / 7): blit it centred on the hex, with size = the hex tile height (2 * r).
"""
import math

import pygame

from .art import shade
from .render import draw
from .render.cache import BoundedCache
from .render.draw import ell

W, H = 120, 140
CX, GY = 60, 100                 # object centre line and ground line
K = 4                            # supersampling factor
EDGE = 0.9                       # part edge width (tile px)
OUTLINE = 2.6                    # silhouette outline width (tile px)

WOOD = (165, 112, 66)
DWOOD = (120, 80, 48)
LWOOD = (205, 160, 105)
IRON = (88, 86, 92)
STEEL = (178, 186, 198)
DARK = (44, 38, 40)
WHITE = (250, 250, 246)
BURLAP = (205, 172, 118)
LEAF = (78, 150, 70)


# ----- pen ------------------------------------------------------------------------------------------------
def _w(w):
    return max(1, round(w * K))


class Pen(draw.Pen):
    """The shared pen on the K x canvas. `shape`, `disc` and `egg` add the darker part edge."""

    def __init__(self, surf):
        super().__init__(surf, K)

    def stroke(self, c, pts, w=EDGE, closed=True):
        """A thick polyline with round joints (pygame leaves gaps at the joints of wide lines)."""
        if len(pts) < 2:
            return
        q = [(x * K, y * K) for x, y in pts]
        pygame.draw.lines(self.s, c, closed, q, _w(w))
        for x, y in q:
            pygame.draw.circle(self.s, c, (x, y), w * K / 2)

    def shape(self, c, pts, edge=None, w=EDGE):
        self.poly(c, pts)
        if edge is not False:
            self.stroke(edge or shade(c, -0.38), pts, w)

    def line(self, c, a, b, w=1.0):
        self.stroke(c, [a, b], w, closed=False)

    def lines(self, c, pts, w=1.0):
        self.stroke(c, pts, w, closed=False)

    def disc(self, c, xy, r, edge=None, w=EDGE):
        self.circle(edge or shade(c, -0.38), xy, r + w / 2)
        self.circle(c, xy, r - w / 2)

    def egg(self, c, cx, cy, rx, ry, edge=None, w=EDGE):
        self.oval(edge or shade(c, -0.38), cx, cy, rx + w / 2, ry + w / 2)
        self.oval(c, cx, cy, rx - w / 2, ry - w / 2)


# ----- geometry helpers -------------------------------------------------------------------------------------
def rot(pts, x, y, ang):
    """Local points rotated by ang degrees (clockwise on screen) and moved to (x, y)."""
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return [(x + px * c - py * s, y + px * s + py * c) for px, py in pts]


def rell(cx, cy, rx, ry, ang, n=20):
    return rot(ell(0, 0, rx, ry, 0, 360, n), cx, cy, ang)


# ----- shared parts -----------------------------------------------------------------------------------------
def leaf(p, base, tip, width, col, rib=True):
    """A pointed leaf from base to tip; the right half a little darker."""
    bx, by = base
    L = math.hypot(tip[0] - bx, tip[1] - by)
    ang = math.degrees(math.atan2(tip[1] - by, tip[0] - bx))
    top = [(L * t, -width * math.sin(math.pi * t) ** 0.85) for t in (i / 10 for i in range(11))]
    bot = [(L * t, width * math.sin(math.pi * t) ** 0.85) for t in (i / 10 for i in range(11))]
    p.shape(col, rot(top + bot[::-1], bx, by, ang))
    p.poly(shade(col, -0.18), rot([(0, 0)] + bot[1:-1] + [(L, 0)], bx, by, ang))
    if rib:
        p.line(shade(col, 0.25), base, (bx + (tip[0] - bx) * 0.85, by + (tip[1] - by) * 0.85), 0.7)


def cylinder(p, x, y, rx, ry, h, col, top=None, edge=None, dark=0.24):
    """An upright cylinder: (x, y) the bottom centre. Right part shaded; top ellipse `top` (None: lighter)."""
    body = ell(x, y, rx, ry, 0, 180, 18) + [(x - rx, y - h), (x + rx, y - h)]
    p.shape(col, body, edge)
    a = 62
    p.poly(shade(col, -dark), [(x + rx, y - h)] + ell(x, y, rx, ry, 0, a, 8) +
           [(x + rx * math.cos(math.radians(a)), y - h)])
    p.stroke(edge or shade(col, -0.38), body, EDGE)
    p.egg(top or shade(col, 0.18), x, y - h, rx, ry, edge)


def log_end(p, x, y, r, L, bark, end, rings=2):
    """A lying log (or bolt) whose round end faces front-left: (x, y) the centre of that end."""
    rx = r * 0.55
    body = [(x, y - r), (x + L, y - r)] + ell(x + L, y, rx, r, -90, 90, 10) + [(x, y + r)]
    p.shape(bark, body)
    p.poly(shade(bark, -0.22), [(x, y + r * 0.35), (x + L, y + r * 0.35)] + ell(x + L, y, rx, r, 20, 90, 6) +
           [(x, y + r)])
    p.line(shade(bark, 0.22), (x + 2, y - r * 0.6), (x + L - 1, y - r * 0.6), 0.9)
    p.stroke(shade(bark, -0.4), body)
    p.egg(end, x, y, rx, r, shade(bark, -0.3))
    for k in range(1, rings + 1):
        f = k / (rings + 1)
        p.oval(shade(end, -0.16), x, y, rx * f, r * f, 0.6)


def box(p, x, y, w, h, d, col, top=None, side=None, edge=None):
    """A block seen from the front-left: (x, y) the front bottom-left corner; depth goes up and right."""
    dx, dy = d * 0.6, -d * 0.55
    side = side or shade(col, -0.26)
    top = top or shade(col, 0.2)
    p.shape(side, [(x + w, y), (x + w + dx, y + dy), (x + w + dx, y - h + dy), (x + w, y - h)], edge)
    p.shape(col, [(x, y), (x + w, y), (x + w, y - h), (x, y - h)], edge)
    p.shape(top, [(x, y - h), (x + w, y - h), (x + w + dx, y - h + dy), (x + dx, y - h + dy)], edge)


def fish(p, x, y, L, ang=0, back=(84, 140, 196), belly=(222, 234, 240), flip=False):
    """A fish lying side-on, head to the left (flip: to the right); (x, y) its middle."""
    f = -1 if flip else 1
    h = L * 0.21
    n = 14
    top = [(-L / 2 + L * 0.82 * t, -h * math.sin(math.pi * t) ** 0.75) for t in (i / n for i in range(n + 1))]
    bot = [(-L / 2 + L * 0.82 * t, h * 0.9 * math.sin(math.pi * t) ** 0.75) for t in (i / n for i in range(n + 1))]
    tail = [(L * 0.28, 0), (L * 0.52, -h * 1.15), (L * 0.43, 0), (L * 0.52, h * 1.15)]
    fin = [(-L * 0.06, -h * 0.9), (L * 0.08, -h * 1.45), (L * 0.2, -h * 0.75)]

    def T(pts):
        return rot([(f * px, py) for px, py in pts], x, y, ang)
    dk = shade(back, -0.3)
    p.shape(dk, T(fin))
    p.shape(dk, T(tail))
    p.shape(back, T(top + bot[::-1]))
    p.poly(belly, T([(px, max(py, h * 0.12)) for px, py in bot[1:-1]] +
                    [(px, h * 0.12) for px, _ in bot[-2:0:-1]]))
    p.poly(shade(back, 0.3), T([(-L * 0.28, -h * 0.45), (L * 0.15, -h * 0.55), (L * 0.15, -h * 0.35),
                                (-L * 0.28, -h * 0.25)]))
    p.stroke(shade(back, -0.45), T(top + bot[::-1]))
    p.lines(shade(back, -0.35), T(ell(-L * 0.18, 0, h * 0.35, h * 0.6, -70, 70, 6)), 0.8)
    ex, ey = T([(-L * 0.36, -h * 0.22)])[0]
    p.circle(WHITE, (ex, ey), h * 0.26)
    p.circle(DARK, (ex - f * 0.2, ey), h * 0.14)


def grapes(p, x, y, s=1.0, col=(126, 46, 112)):
    """A bunch hanging from (x, y): rows of berries narrowing downwards, with a leaf on top."""
    leaf(p, (x, y - 1 * s), (x - 11 * s, y - 7 * s), 4.5 * s, (96, 160, 70))
    leaf(p, (x, y - 1 * s), (x + 10 * s, y - 8 * s), 4.2 * s, (82, 145, 62))
    rows = ((-6, 0), (0, 0), (6, 0), (-3, 5), (3, 5), (-6, 10), (0, 10), (6, 10), (-3, 15), (3, 15), (0, 20))
    for dx, dy in sorted(rows, key=lambda r: r[1]):
        bx, by = x + dx * s * 0.95, y + 4 * s + dy * s * 0.85
        p.disc(col, (bx, by), 3.6 * s, shade(col, -0.45))
        p.circle(shade(col, 0.35), (bx - 1.2 * s, by - 1.2 * s), 1.0 * s)


def coin(p, x, y, r, col, edge=None):
    p.egg(shade(col, -0.25), x, y + r * 0.18, r, r * 0.55, edge)
    p.egg(col, x, y, r, r * 0.55, edge)
    p.oval(shade(col, 0.35), x - r * 0.15, y - r * 0.08, r * 0.45, r * 0.22, 0.6)


def coin_stack(p, x, y, r, n, col):
    for i in range(n):
        p.egg(shade(col, -0.2 if i % 2 else -0.1), x, y - i * r * 0.32, r, r * 0.55)
    coin(p, x, y - n * r * 0.32, r, col)


def sack(p, x, y, w, h, col, fill=None, heap=None):
    """An open sack: (x, y) bottom centre. `fill` shows the contents as a heap above the rolled rim."""
    rim_y = y - h
    body = ([(x - w * 0.42, rim_y + 2), (x - w * 0.52, y - h * 0.35), (x - w * 0.46, y - 1)] +
            ell(x, y - 1, w * 0.46, h * 0.12, 180, 0, 10) + [(x + w * 0.52, y - h * 0.35), (x + w * 0.42, rim_y + 2)])
    p.shape(col, body)
    p.poly(shade(col, -0.2), [(x + w * 0.12, rim_y + 3), (x + w * 0.42, rim_y + 2), (x + w * 0.52, y - h * 0.35),
                              (x + w * 0.46, y - 1), (x + w * 0.15, y + h * 0.1)])
    p.stroke(shade(col, -0.4), body)
    for k in (-0.2, 0.18):
        p.line(shade(col, -0.18), (x + w * k, rim_y + 6), (x + w * k * 1.2, y - 4), 0.7)
    if fill:
        heap = heap or h * 0.2
        p.shape(fill, ell(x, rim_y, w * 0.4, heap, 180, 360, 14))
        p.poly(shade(fill, -0.15), ell(x, rim_y, w * 0.4, heap, 300, 360, 6) + [(x + w * 0.1, rim_y)])
        p.oval(shade(fill, 0.3), x - w * 0.12, rim_y - heap * 0.6, w * 0.1, h * 0.05)
    p.egg(shade(col, 0.12), x, rim_y + 1, w * 0.46, h * 0.1)
    if fill:
        p.oval(fill, x, rim_y, w * 0.38, h * 0.07)


def blade(p, a, b, w, col=STEEL):
    """A straight steel blade from a to b, lit edge on the left."""
    p.line(shade(col, -0.45), a, b, w + EDGE * 2)
    p.line(col, a, b, w)
    p.line(shade(col, 0.4), a, (a[0] + (b[0] - a[0]) * 0.9, a[1] + (b[1] - a[1]) * 0.9), max(0.6, w * 0.3))


def stick(p, a, b, w, col=WOOD):
    p.line(shade(col, -0.45), a, b, w + EDGE * 2)
    p.line(col, a, b, w)


# ----- raw goods --------------------------------------------------------------------------------------------
def draw_grain(p):
    """Three wheat sheaves leaning together in a stook, tied at the waist, heavy ears fanned out on top."""
    stalk, ear, band = (214, 178, 78), (244, 212, 110), (160, 98, 42)

    def sheaf(x, y, h, lean):
        wx, wy = x + lean * 0.45, y - h * 0.45
        tx, ty = x + lean, y - h
        lower = [(x - 9, y), (x + 9, y), (wx + 5, wy), (wx - 5, wy)]
        upper = [(wx - 5, wy), (wx + 5, wy), (tx + 11, ty + 9), (tx - 11, ty + 9)]
        p.shape(stalk, lower)
        p.poly(shade(stalk, -0.18), [(x + 2, y), (x + 9, y), (wx + 5, wy), (wx + 1, wy)])
        for k in (-5, -1, 3):
            p.line(shade(stalk, -0.25), (x + k * 1.4, y - 1), (wx + k * 0.8, wy + 2), 0.6)
        p.stroke(shade(stalk, -0.4), lower)
        p.shape(stalk, upper)
        p.poly(shade(stalk, -0.18), [(wx + 1, wy), (wx + 5, wy), (tx + 11, ty + 9), (tx + 3, ty + 9)])
        p.stroke(shade(stalk, -0.4), upper)
        for i in range(9):
            a = -84 + i * 21
            s, c = math.sin(math.radians(a)), math.cos(math.radians(a))
            ex, ey = tx + s * 11, ty + 8 - c * 10
            col = ear if i < 5 else shade(ear, -0.12)
            p.shape(col, rell(ex, ey, 7, 2.7, a - 90, 12), shade(ear, -0.45))
            for k in (-3.5, 0, 3.5):
                p.line(shade(ear, -0.3), (ex + s * k - c * 1.2, ey - c * k - s * 1.2),
                       (ex + s * k + c * 1.2, ey - c * k + s * 1.2), 0.5)
        p.shape(band, [(wx - 6, wy - 2.5), (wx + 6, wy - 2.5), (wx + 6, wy + 2.5), (wx - 6, wy + 2.5)])

    sheaf(60, 94, 64, 0)
    sheaf(41, 101, 56, 10)
    sheaf(79, 101, 56, -10)


def draw_fish(p):
    """A wicker creel full of fish, tails up, and a big fish lying on the ground in front."""
    wick = (196, 150, 86)
    x, y = 50, 92
    # fish standing in the basket (drawn first, the basket front hides their heads)
    fish(p, 38, 60, 30, ang=-70, back=(70, 128, 184))
    fish(p, 56, 56, 32, ang=-100, back=(96, 152, 204))
    rim = ell(x, 70, 24, 8, 0, 360, 24)
    body = [(x + 24, 70)] + ell(x, y + 1, 17, 6, 0, 180, 10) + [(x - 24, 70)]
    p.shape(wick, body)
    p.poly(shade(wick, -0.2), [(x + 24, 70), (x + 9, 76)] + ell(x, y + 1, 17, 6, 60, 0, 6)[:-1] + [(x + 17, y + 1)])
    for i in range(1, 4):
        yy = 70 + i * 6
        rr = 24 - i * 2
        p.lines(shade(wick, -0.3), ell(x, yy, rr, 7, 10, 170, 12), 0.7)
    for i in range(-3, 4):
        p.line(shade(wick, -0.25), (x + i * 6.5, 77.5 - abs(i) * 0.6), (x + i * 4.6, y + 6 - abs(i) * 0.5), 0.6)
    p.stroke(shade(wick, -0.42), body)
    p.stroke(shade(wick, -0.42), rim)
    p.lines(shade(wick, 0.25), ell(x, 70, 24, 8, 180, 360, 16), 2.2)
    p.lines(shade(wick, -0.42), ell(x, 70, 25.2, 9.2, 180, 360, 16), 0.6)
    # the big fish in front
    fish(p, 70, 95, 50, ang=-8, back=(84, 140, 196), flip=True)


def draw_salt(p):
    """White salt cones on a pale salt pan, with a wooden rake."""
    pan = (196, 214, 226)
    p.shape(pan, ell(60, 92, 44, 13, 0, 360, 28), (120, 140, 160))
    p.oval((168, 196, 216), 60, 93, 38, 10)
    p.oval((214, 230, 240), 54, 92, 22, 5)

    def cone(x, y, r, h):
        p.shape((244, 247, 250), [(x - r, y), (x, y - h), (x + r, y)] + ell(x, y, r, r * 0.3, 0, 180, 10),
                (110, 128, 150))
        p.poly((206, 218, 232), [(x + 1, y - h + 2), (x + r, y)] + ell(x, y, r, r * 0.3, 0, 70, 6) + [(x + 2, y + r * 0.3)])
        p.stroke((110, 128, 150), [(x - r, y), (x, y - h), (x + r, y)] + ell(x, y, r, r * 0.3, 0, 180, 10))
        p.line(WHITE, (x - 3, y - h * 0.6), (x - 1.2, y - h * 0.85), 1.1)
    cone(62, 82, 17, 38)
    cone(40, 92, 14, 30)
    cone(81, 94, 13, 28)
    # rake leaning on the right
    stick(p, (99, 56), (88, 98), 2.0, LWOOD)
    p.shape(DWOOD, rot([(-8, -1.5), (8, -1.5), (8, 1.5), (-8, 1.5)], 99, 56, -25))
    for k in (-6, -2, 2, 6):
        a, b = rot([(k, 1), (k, 5)], 99, 56, -25)
        p.line(DWOOD, a, b, 1.2)


def draw_wine(p):
    """A wine barrel on its cradle with a tap, and a big bunch of grapes in front."""
    wood, end = (176, 112, 62), (210, 160, 100)
    p.shape(DWOOD, [(30, 99), (36, 82), (42, 82), (40, 99)])
    p.shape(DWOOD, [(76, 99), (80, 80), (86, 80), (86, 99)])
    # barrel, end facing front-left, bulging body
    x, y, r, L = 34, 72, 19, 50
    body = [(x, y - r)] + [(x + L * t, y - r - 4 * math.sin(math.pi * t)) for t in (i / 8 for i in range(1, 8))] + \
        [(x + L, y - r)] + ell(x + L, y, r * 0.5, r, -90, 90, 10) + \
        [(x + L * t, y + r + 4 * math.sin(math.pi * t)) for t in (i / 8 for i in range(7, 0, -1))] + [(x, y + r)]
    p.shape(wood, body)
    p.poly(shade(wood, -0.22), [(x, y + r * 0.35)] + [(x + L * t, y + r * 0.35 + 3 * math.sin(math.pi * t))
                                                       for t in (i / 8 for i in range(1, 8))] +
           [(x + L, y + r * 0.35)] + ell(x + L, y, r * 0.5, r, 20, 90, 6) +
           [(x + L * t, y + r + 4 * math.sin(math.pi * t)) for t in (i / 8 for i in range(7, 0, -1))] + [(x, y + r)])
    p.line(shade(wood, 0.25), (x + 4, y - r * 0.55 - 2), (x + L - 4, y - r * 0.55 - 2), 1.2)
    for t in (0.12, 0.88):
        hx = x + L * t
        bulge = 4 * math.sin(math.pi * t)
        p.line(IRON, (hx, y - r - bulge), (hx, y + r + bulge), 2.6)
    p.stroke(shade(wood, -0.45), body)
    p.egg(end, x, y, r * 0.5, r, shade(wood, -0.35))
    p.oval(shade(end, -0.12), x, y, r * 0.32, r * 0.66, 0.6)
    p.oval(IRON, x, y, r * 0.5 + 0.8, r + 0.8, 1.8)
    p.shape(DWOOD, [(x - 1, y + 6), (x - 6, y + 6), (x - 6, y + 10), (x - 1, y + 10)])
    p.shape(IRON, [(x - 5, y + 9), (x - 3, y + 9), (x - 3, y + 13), (x - 5, y + 13)])
    grapes(p, 72, 84, 1.05)


def draw_wool(p):
    """A woolly sheep (cream fleece, dark face and legs)."""
    fleece, face = (240, 234, 216), (62, 56, 58)
    for lx, ly in ((44, 84), (52, 86), (72, 86), (80, 84)):
        dk = lx in (52, 80)
        p.shape(shade(face, 0.15 if not dk else -0.1), [(lx - 2, ly), (lx + 2, ly), (lx + 2, ly + 13), (lx - 2, ly + 13)])
    puffs = [(40, 70, 11), (52, 62, 12), (66, 60, 12), (80, 66, 12), (86, 77, 10), (74, 80, 12), (58, 80, 12),
             (44, 80, 11), (60, 70, 14)]
    edge = (150, 140, 120)
    for x, y, r in puffs:
        p.circle(edge, (x, y), r + EDGE)
    for x, y, r in puffs:
        p.circle(fleece, (x, y), r - EDGE / 2)
    for x, y, r in puffs[3:8]:
        p.circle((222, 212, 190), (x + r * 0.2, y + r * 0.3), r * 0.7)
    for x, y, r in ((50, 60, 5), (64, 57, 5), (40, 68, 4), (78, 63, 5)):
        p.circle(WHITE, (x - 1, y - 1), r)
    # head to the left
    head = [(34, 62), (26, 66), (20, 78), (24, 84), (32, 80), (38, 70)]
    p.shape(face, head)
    p.shape(face, rell(28, 64, 6, 2.6, 25, 12))
    p.circle(WHITE, (27, 71), 1.6)
    p.circle(DARK, (26.6, 71.2), 0.8)
    for x, y, r in ((33, 60, 6), (38, 58, 5)):
        p.disc(fleece, (x, y), r, edge)


def draw_cotton(p):
    """A cotton bush with open white bolls, and a burlap sack brimming with picked cotton."""
    br = (120, 84, 54)
    for a, b in (((58, 98), (50, 62)), ((58, 98), (70, 56)), ((54, 80), (36, 66)), ((62, 76), (82, 66)),
                 ((52, 70), (44, 52)), ((66, 66), (64, 46))):
        stick(p, a, b, 2.2, br)
    for base, tip, col in (((40, 74), (28, 80), (70, 140, 64)), ((80, 72), (92, 78), (64, 132, 58)),
                           ((58, 60), (52, 48), (80, 150, 70)), ((70, 82), (82, 90), (64, 132, 58))):
        leaf(p, base, tip, 4.2, col)

    def boll(x, y, r):
        p.shape((112, 76, 50), [(x - r * 0.9, y + r * 0.4), (x, y + r * 1.15), (x + r * 0.9, y + r * 0.4)])
        for dx, dy, k in ((-0.5, 0.1, 0.62), (0.5, 0.1, 0.62), (0, -0.35, 0.66), (0, 0.25, 0.6)):
            p.disc(WHITE if dy < 0.2 else (232, 232, 226), (x + dx * r, y + dy * r), r * k, (150, 150, 145))
        p.circle((255, 255, 255), (x - r * 0.3, y - r * 0.45), r * 0.22)
    for x, y, r in ((50, 61, 7), (70, 55, 7.5), (36, 65, 6.5), (82, 64, 7), (44, 50, 6.5), (64, 44, 7)):
        boll(x, y, r)
    sack(p, 76, 100, 30, 26, BURLAP)
    for dx, dy, r in ((-8, -27, 5.5), (0, -30, 6.5), (8, -27, 5.5), (-3, -24, 5), (5, -24, 5)):
        p.disc(WHITE, (76 + dx, 100 + dy), r, (150, 150, 145))


def draw_timber(p):
    """A pyramid of felled logs, and an axe struck into a stump."""
    bark, end = (140, 92, 54), (226, 190, 130)
    # stump with axe, behind on the right
    cylinder(p, 86, 82, 9, 3.5, 12, (120, 80, 48), top=end)
    stick(p, (84, 70), (100, 52), 2.4, LWOOD)
    p.shape(STEEL, rot([(-4, -3), (5, -4), (6, 4), (-4, 2.5)], 84, 70, -40))
    for x, y in ((24, 92), (40, 92), (56, 92)):
        log_end(p, x, y, 8.5, 40, bark, end)
    for x, y in ((32, 76), (48, 76)):
        log_end(p, x, y, 8.5, 40, bark, end)
    log_end(p, 40, 60, 8.5, 40, bark, end)


def draw_iron(p):
    """A heap of dark iron ore with rust flecks and a pickaxe resting on it."""
    ore, rust = (98, 102, 116), (190, 98, 52)

    def rock(pts, col):
        p.shape(col, pts, (40, 40, 52))
        cx = sum(x for x, _ in pts) / len(pts)
        cy = sum(y for _, y in pts) / len(pts)
        p.poly(shade(col, -0.25), [pt for pt in pts if pt[0] >= cx - 1] + [(cx, cy + 2)])
        p.poly(shade(col, 0.18), [pts[0], pts[1], (cx - 1, cy - 1)])
        p.stroke((40, 40, 52), pts)
    rock([(30, 98), (26, 84), (38, 72), (52, 76), (54, 98)], ore)
    rock([(66, 98), (62, 78), (74, 70), (90, 76), (94, 98)], shade(ore, -0.08))
    rock([(40, 82), (42, 62), (58, 52), (72, 62), (74, 84), (56, 92)], ore)
    rock([(46, 102), (44, 90), (56, 86), (68, 90), (70, 102)], shade(ore, 0.05))
    for x, y, r in ((50, 64, 3), (60, 72, 2.5), (36, 86, 2.5), (80, 84, 3), (57, 95, 2.2), (70, 64, 2)):
        p.disc(rust, (x, y), r, (120, 58, 32))
    # pickaxe
    stick(p, (74, 40), (96, 100), 3.2, LWOOD)
    head = [(56, 50), (66, 38), (76, 35), (88, 38), (98, 46), (86, 43), (76, 42), (68, 45)]
    p.shape((206, 212, 222), head, (60, 64, 78))
    p.poly((236, 240, 246), [(60, 47), (66, 40), (76, 37), (76, 39), (67, 43)])
    p.shape(DWOOD, [(72, 36), (78, 35), (79, 42), (73, 43)])


def draw_horses(p):
    """A chestnut horse standing side-on, dark mane and tail, white blaze."""
    coat, mane = (176, 104, 56), (64, 40, 30)
    dk = shade(coat, -0.22)
    # far legs (darker)
    for x0, x1 in ((50, 48), (80, 82)):
        p.shape(dk, [(x0 - 2.6, 76), (x0 + 2.6, 76), (x1 + 2.2, 98), (x1 - 2.2, 98)])
        p.shape(mane, [(x1 - 2.6, 97), (x1 + 2.6, 97), (x1 + 3, 101), (x1 - 3, 101)])
    # tail
    p.shape(mane, [(86, 66), (92, 70), (94, 86), (90, 94), (88, 84), (85, 72)])
    # body
    body = ell(66, 70, 22, 11.5, 0, 360, 30)
    p.shape(coat, body)
    p.poly(dk, ell(66, 70, 22, 11.5, 15, 160, 14))
    p.stroke(shade(coat, -0.42), body)
    # neck and head
    neck = [(42, 66), (36, 48), (34, 40), (44, 38), (50, 50), (54, 64)]
    p.shape(coat, neck)
    head = [(34, 38), (38, 34), (42, 38), (32, 56), (26, 58), (24, 54)]
    p.shape(coat, head)
    p.poly(WHITE, [(36, 40), (38, 39), (29, 54), (27, 53)])
    p.shape(dk, [(24, 54), (32, 52), (32, 56), (26, 58)])
    p.shape(coat, [(38, 34), (40, 28), (42, 35)])
    p.circle(DARK, (35, 42), 1.2)
    p.shape(mane, [(40, 34), (46, 38), (54, 60), (50, 62), (43, 46), (38, 36)])
    # near legs
    for x0, x1 in ((46, 44), (84, 86)):
        p.shape(coat, [(x0 - 3, 74), (x0 + 3, 74), (x1 + 2.4, 98), (x1 - 2.4, 98)])
        p.shape(mane, [(x1 - 2.8, 97), (x1 + 2.8, 97), (x1 + 3.2, 102), (x1 - 3.2, 102)])
    p.line(shade(coat, 0.25), (52, 62), (74, 60), 1.4)


def draw_cattle(p):
    """A cream cow with brown patches, short horns and a pink muzzle, head down to graze."""
    hide, patch = (244, 238, 226), (126, 82, 56)
    edge = (130, 110, 92)
    for x in (50, 82):
        p.shape(shade(hide, -0.2), [(x - 2.6, 80), (x + 2.6, 80), (x + 2.4, 98), (x - 2.4, 98)], edge)
        p.shape(DARK, [(x - 2.8, 97), (x + 2.8, 97), (x + 3, 101), (x - 3, 101)])
    p.lines(edge, [(90, 66), (95, 76), (94, 88)], 1.8)
    p.shape(patch, rell(94, 89, 2.2, 3.6, 0, 10))
    body = [(40, 62), (62, 58), (86, 60), (92, 68), (90, 82), (80, 86), (48, 86), (40, 80)]
    p.shape(hide, body, edge)
    p.shape(patch, [(60, 60), (74, 59), (78, 70), (66, 74), (58, 68)], shade(patch, -0.3))
    p.shape(patch, [(82, 62), (90, 66), (90, 78), (84, 76)], shade(patch, -0.3))
    p.shape(patch, [(44, 70), (52, 70), (52, 80), (44, 82)], shade(patch, -0.3))
    p.poly(shade(hide, -0.12), [(48, 86), (80, 86), (90, 82), (90, 78), (48, 80)])
    p.shape((236, 176, 176), rell(68, 87, 5, 3, 0, 12))
    p.stroke(edge, body)
    # head
    head = [(42, 64), (30, 66), (24, 78), (26, 86), (34, 88), (40, 78), (46, 72)]
    p.shape(hide, head, edge)
    p.shape(patch, [(30, 66), (40, 64), (38, 74), (31, 74)], shade(patch, -0.3))
    p.shape((236, 170, 166), rell(29, 86, 6, 3.6, -10, 12))
    p.circle(DARK, (27.5, 86), 0.9)
    p.circle(DARK, (31.5, 86), 0.9)
    p.circle(DARK, (33, 74), 1.2)
    p.shape((236, 226, 200), [(28, 66), (24, 58), (22, 56), (27, 60), (32, 64)], (140, 120, 90))
    p.shape((236, 226, 200), [(40, 64), (44, 56), (46, 55), (44, 60), (43, 66)], (140, 120, 90))
    p.shape(patch, rell(23, 66, 5, 2.4, -20, 10))
    for x in (44, 76):
        p.shape(hide, [(x - 3, 82), (x + 3, 82), (x + 2.6, 98), (x - 2.6, 98)], edge)
        p.shape(DARK, [(x - 3, 97), (x + 3, 97), (x + 3.3, 102), (x - 3.3, 102)])


def draw_stone(p):
    """Dressed stone blocks and a column drum, with mallet marks: the quarry's yield."""
    stone = (212, 206, 192)
    edge = (110, 106, 100)
    box(p, 24, 98, 32, 18, 14, stone, edge=edge)
    box(p, 56, 98, 26, 16, 14, shade(stone, -0.05), edge=edge)
    box(p, 34, 80, 28, 15, 13, shade(stone, 0.03), edge=edge)
    for x, y in ((30, 90), (38, 92), (62, 90), (42, 72), (50, 74)):
        p.line(shade(stone, -0.2), (x, y), (x + 4, y - 1), 0.7)
    cylinder(p, 90, 96, 9, 4, 26, (196, 192, 182), edge=edge)
    for k in (8, 16):
        p.lines(shade((196, 192, 182), -0.18), ell(90, 96 - k, 9, 4, 10, 170, 10), 0.6)


def draw_copper(p):
    """Round copper cakes stacked crosswise, beside a lump of green malachite ore."""
    cu = (214, 122, 64)
    edge = (110, 56, 26)
    # malachite rock behind
    pts = [(66, 98), (64, 80), (76, 66), (92, 72), (96, 98)]
    p.shape((60, 160, 120), pts, (24, 80, 60))
    p.poly((44, 128, 96), [(80, 70), (92, 72), (96, 98), (80, 98)])
    p.poly((120, 210, 170), [(64, 80), (76, 66), (74, 78)])
    for x, y, r in ((72, 86, 3), (86, 82, 2.6), (80, 92, 2.2)):
        p.disc((30, 110, 80), (x, y), r, (20, 70, 50))
    for x, y, r in ((76, 78, 2.6), (90, 90, 2.4)):
        p.disc(cu, (x, y), r, edge)
    # stack of plano-convex cakes
    for i, (x, y) in enumerate(((42, 96), (46, 86), (40, 76), (45, 66), (42, 56))):
        rx, ry = 20, 7
        p.shape(shade(cu, -0.28), ell(x, y, rx, ry, 0, 180, 14) + [(x - rx, y - 4), (x + rx, y - 4)], edge)
        p.egg(cu if i % 2 == 0 else shade(cu, 0.06), x, y - 4, rx, ry, edge)
        p.oval(shade(cu, 0.38), x - 6, y - 6, 7, 2.2)


def draw_hemp(p):
    """A hemp plant with its big fingered leaves, blue flax flowers and a tied bundle of retted fibre."""
    stem, lf = (88, 130, 56), (98, 162, 72)
    stick(p, (56, 100), (56, 34), 2.4, stem)

    def palm(x, y, s):
        for a, k in ((-84, 0.5), (-54, 0.8), (-26, 1.0), (0, 1.1), (26, 1.0), (54, 0.8), (84, 0.5)):
            a2 = math.radians(a)
            leaf(p, (x, y), (x + math.sin(a2) * s * k, y - math.cos(a2) * s * k), s * 0.09 + 1.0,
                 lf if a <= 0 else shade(lf, -0.1), rib=False)
    palm(56, 66, 30)
    palm(56, 38, 15)
    # flax flowers
    for x, y in ((28, 86), (22, 76), (36, 78)):
        stick(p, (x, 100), (x, y), 1.0, stem)
    for x, y in ((28, 86), (22, 76), (36, 78)):
        for a in range(0, 360, 72):
            p.disc((110, 150, 235), (x + math.cos(math.radians(a)) * 2.8, y + math.sin(math.radians(a)) * 2.8), 2.5,
                   (50, 70, 150))
        p.circle((250, 230, 120), (x, y), 1.3)
    # bundle of fibre
    fib = (226, 206, 150)
    pts = [(74, 100), (96, 100), (90, 80), (98, 58), (84, 60), (80, 80)]
    p.shape(fib, pts, (130, 110, 70))
    p.poly(shade(fib, -0.15), [(86, 100), (96, 100), (90, 80), (98, 58), (90, 59), (85, 80)])
    for k in range(4):
        p.line(shade(fib, -0.25), (78 + k * 4, 98), (86 + k * 3, 62), 0.6)
    p.stroke((130, 110, 70), pts)
    p.shape((150, 96, 50), [(79, 76), (92, 76), (92, 81), (79, 81)])


# ----- luxuries ---------------------------------------------------------------------------------------------
def draw_sugar(p):
    """A white sugarloaf in its blue paper wrapper, with fresh-cut cane stalks behind."""
    cane = (176, 196, 96)
    for a, b in (((40, 100), (34, 34)), ((52, 100), (56, 28)), ((84, 100), (92, 40))):
        stick(p, a, b, 4.2, cane)
        for t in (0.2, 0.42, 0.64, 0.86):
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            p.line(shade(cane, -0.4), (x - 2.4, y), (x + 2.4, y), 1.0)
        leaf(p, b, (b[0] + (12 if b[0] > 50 else -12), b[1] - 4), 3, (96, 160, 70), rib=False)
        leaf(p, b, (b[0] + (-8 if b[0] > 50 else 9), b[1] - 10), 2.6, (110, 172, 80), rib=False)
    # the loaf
    x, y, r, h = 64, 98, 15, 58
    cone = [(x - r, y), (x - r * 0.45, y - h + 8)] + ell(x, y - h + 8, r * 0.45, r * 0.45, 180, 360, 10) + \
        [(x + r * 0.45, y - h + 8), (x + r, y)] + ell(x, y, r, r * 0.32, 0, 180, 10)
    p.shape((248, 248, 244), cone, (130, 140, 160))
    p.poly((214, 220, 232), [(x + 3, y - h + 6), (x + r * 0.45, y - h + 8), (x + r, y)] + ell(x, y, r, r * 0.32, 0, 60, 6) +
           [(x + 5, y + 4)])
    p.line(WHITE, (x - 7, y - 30), (x - 4, y - 48), 1.6)
    p.stroke((130, 140, 160), cone)
    paper = (54, 92, 176)
    wrap = [(x - r, y), (x - r * 0.78, y - 18), (x + r * 0.78, y - 18), (x + r, y)] + ell(x, y, r, r * 0.32, 0, 180, 10)
    p.shape(paper, wrap)
    p.poly(shade(paper, -0.25), [(x + 4, y - 18), (x + r * 0.78, y - 18), (x + r, y)] + ell(x, y, r, r * 0.32, 0, 70, 6) +
           [(x + 6, y + 4)])
    p.stroke(shade(paper, -0.45), wrap)
    p.lines((236, 220, 170), ell(x, y - 18, r * 0.8, r * 0.26, 0, 180, 10), 1.4)
    p.lines((236, 220, 170), [(x - 2, y - 14), (x - 4, y - 8), (x - 1, y - 6)], 1.0)


def draw_tobacco(p):
    """A tobacco plant (huge leaves, pink flower head) beside a tied hand of cured brown leaves."""
    stem, green = (110, 140, 60), (112, 168, 64)
    stick(p, (46, 100), (46, 30), 2.4, stem)
    for y, side, L, w in ((90, -1, 26, 8), (82, 1, 28, 8.5), (68, -1, 24, 7.5), (56, 1, 22, 7), (44, -1, 16, 5.5)):
        leaf(p, (46, y), (46 + side * L, y - 14 + (6 if side < 0 else 0)), w,
             green if side < 0 else shade(green, -0.1))
    for x, y in ((40, 28), (46, 24), (52, 28), (46, 32)):
        p.shape((236, 140, 170), [(x - 1.6, y + 4), (x - 3, y - 2), (x + 3, y - 2), (x + 1.6, y + 4)], (150, 70, 100))
    # the cured hand, leaning on the right
    cured = (156, 104, 48)
    for i, (dx, ang, L) in enumerate(((-6, -12, 36), (0, -4, 40), (6, 6, 36), (2, 14, 30))):
        x0, y0 = 80 + dx * 0.3, 54
        tip = (x0 + math.sin(math.radians(ang)) * L, y0 + math.cos(math.radians(ang)) * L)
        leaf(p, (x0, y0), tip, 7.5, shade(cured, (-0.12, 0, 0.08, -0.2)[i]))
    p.shape((120, 82, 40), [(75, 50), (85, 50), (86, 58), (74, 58)])
    p.shape((206, 180, 120), [(74, 53), (86, 53), (86, 56), (74, 56)])


def draw_furs(p):
    """A beaver pelt laced into a pole frame, and a fox pelt with a white-tipped tail laid in front."""
    pole, pelt = (186, 138, 84), (126, 84, 54)
    lace = (236, 218, 176)
    stick(p, (30, 100), (33, 24), 2.6, pole)
    stick(p, (90, 100), (87, 24), 2.6, pole)
    stick(p, (25, 30), (95, 30), 2.4, pole)
    stick(p, (27, 92), (93, 92), 2.4, pole)
    right = [(60, 37), (65, 39), (67, 45), (78, 40), (83, 46), (75, 53), (77, 62), (76, 71), (84, 77), (80, 84),
             (68, 80), (63, 84), (62, 88)]
    hide = right + [(120 - x, y) for x, y in right[::-1]][1:-1]
    for a, b in (((60, 37), (60, 31)), ((83, 46), (88, 42)), ((84, 77), (88, 84)), ((37, 46), (32, 42)),
                 ((36, 77), (32, 84)), ((62, 88), (62, 92)), ((77, 62), (88, 62)), ((43, 62), (32, 62))):
        p.line(lace, a, b, 1.0)
    p.shape(pelt, hide, (66, 40, 24))
    p.poly(shade(pelt, -0.18), right[2:-1] + [(60, 70), (60, 46)])
    p.shape(shade(pelt, 0.22), ell(58, 62, 10, 15, 0, 360, 20), False)
    p.oval(shade(pelt, 0.38), 55, 56, 4, 6)
    for x, y in ((50, 70), (66, 54), (54, 78), (70, 70), (48, 52)):
        p.line(shade(pelt, -0.3), (x, y), (x + 2, y + 3), 0.7)
    p.stroke((66, 40, 24), hide)
    # fox pelt
    fox = (214, 110, 48)
    body = [(24, 94), (34, 86), (52, 84), (70, 88), (78, 94), (66, 100), (40, 101)]
    p.shape(fox, body)
    p.poly(WHITE, [(36, 96), (52, 92), (66, 96), (52, 99)])
    p.shape(fox, [(24, 94), (16, 89), (18, 96)])
    p.shape(fox, [(24, 94), (16, 99), (22, 101)])
    tail = [(76, 92), (88, 86), (100, 88), (104, 94), (96, 98), (82, 98)]
    p.shape(fox, tail)
    p.shape(WHITE, [(98, 88), (104, 94), (96, 98), (95, 92)], (150, 140, 130))
    p.circle(DARK, (28, 92), 1)


def draw_ivory(p):
    """A pair of great tusks crossed on a low wooden block, tips curving outwards."""
    tusk = (244, 234, 206)
    edge = (130, 112, 80)
    box(p, 28, 102, 62, 7, 10, DWOOD)

    def curve(x0, y0, x1, y1, bend, w0):
        pts_l, pts_r = [], []
        n = 18
        for i in range(n + 1):
            t = i / n
            bx = x0 + (x1 - x0) * t + bend * math.sin(math.pi * t)
            by = y0 + (y1 - y0) * t
            dx = (x1 - x0) + bend * math.pi * math.cos(math.pi * t)
            dy = (y1 - y0)
            L = math.hypot(dx, dy) or 1
            nx, ny = -dy / L, dx / L
            w = w0 * (1 - t) ** 0.75 + 0.4
            pts_l.append((bx + nx * w, by + ny * w))
            pts_r.append((bx - nx * w, by - ny * w))
        return pts_l, pts_r
    for x0, x1, bend, col in ((46, 96, -14, shade(tusk, -0.07)), (74, 24, 14, tusk)):
        a, b = curve(x0, 96, x1, 26, bend, 7.5)
        poly = a + b[::-1]
        p.shape(col, poly, edge)
        p.stroke(edge, poly)
        p.shape((214, 190, 150), [a[0], b[0], b[1], a[1]], edge)
        mid = [((ax + bx) / 2, (ay + by) / 2) for (ax, ay), (bx, by) in zip(a, b)]
        p.lines(WHITE, mid[4:12], 1.2)


def draw_spices(p):
    """Three open sacks heaped with turmeric, paprika and cinnamon, with a spill of colour in front."""
    sack(p, 38, 92, 30, 28, BURLAP, (238, 186, 36), 8)
    sack(p, 82, 92, 30, 28, shade(BURLAP, -0.06), (206, 66, 40), 8)
    sack(p, 60, 102, 32, 30, shade(BURLAP, 0.04), (214, 124, 46), 9)
    p.shape((206, 66, 40), ell(92, 103, 9, 3.2, 180, 360, 10), (120, 36, 20))
    p.shape((238, 186, 36), ell(28, 104, 8, 3, 180, 360, 10), (140, 100, 20))
    # cinnamon sticks across the front sack's heap
    for dx in (-3, 2):
        stick(p, (52 + dx, 66 + dx * 0.4), (70 + dx, 60 + dx * 0.4), 2.2, (150, 82, 40))


def draw_olives(p):
    """A two-handled terracotta oil jar and an olive sprig heavy with fruit."""
    clay = (204, 112, 70)
    edge = (110, 54, 30)
    x = 54
    jar = [(x - 7, 30), (x + 7, 30), (x + 6, 36)] + ell(x, 64, 20, 30, -70, 70, 16) + [(x + 6, 98), (x - 6, 98)] + \
        ell(x, 64, 20, 30, 110, 250, 16) + [(x - 6, 36)]
    p.shape(clay, jar, edge)
    p.poly(shade(clay, -0.2), [(x + 4, 38)] + ell(x, 64, 20, 30, -60, 70, 12) + [(x + 6, 98), (x + 2, 98)])
    p.line(shade(clay, 0.3), (x - 13, 56), (x - 11, 76), 2)
    p.stroke(edge, jar)
    p.egg(shade(clay, 0.1), x, 30, 8, 2.6, edge)
    p.oval((70, 50, 30), x, 30, 5.4, 1.6)
    for f in (-1, 1):
        p.lines(edge, [(x + f * 6, 38), (x + f * 16, 36), (x + f * 17, 46)], 3.6)
        p.lines(clay, [(x + f * 6, 38), (x + f * 16, 36), (x + f * 17, 46)], 1.8)
    p.lines(shade(clay, -0.3), ell(x, 52, 17, 4, 10, 170, 12), 1.0)
    # olive sprig in front
    br = (120, 96, 60)
    stick(p, (66, 100), (98, 74), 1.6, br)
    for t, side in ((0.15, 1), (0.35, -1), (0.55, 1), (0.75, -1), (0.92, 1)):
        bx, by = 66 + 32 * t, 100 - 26 * t
        leaf(p, (bx, by), (bx + 10 * (0.6 if side > 0 else -0.3), by + (6 if side > 0 else -9)), 2.4,
             (140, 164, 104) if side > 0 else (120, 146, 88), rib=False)
    for x0, y0, c in ((74, 98, (80, 100, 50)), (82, 90, (64, 52, 70)), (90, 86, (96, 116, 56)), (96, 80, (64, 52, 70))):
        p.disc(c, (x0, y0), 3.4, shade(c, -0.45))
        p.circle(shade(c, 0.4), (x0 - 1, y0 - 1), 0.9)


def draw_silk(p):
    """Twisted pink silk skeins hung over a lacquered rod, with a heap of white cocoons below."""
    silk = (238, 150, 196)
    edge = (150, 70, 110)
    lac = (170, 54, 46)
    stick(p, (30, 100), (30, 34), 2.6, lac)
    stick(p, (90, 100), (90, 34), 2.6, lac)
    p.shape(lac, [(24, 30), (96, 30), (98, 35), (22, 35)])
    for i, x in enumerate((44, 60, 76)):
        col = shade(silk, (0.08, -0.04, 0.14)[i])
        loop = ([(x - 4, 34), (x + 4, 34), (x + 8, 50), (x + 8, 66)] + ell(x, 70, 8, 8, 0, 180, 10) +
                [(x - 8, 66), (x - 8, 50)])
        p.shape(col, loop, edge)
        p.poly(shade(col, -0.16), [(x + 1, 34), (x + 4, 34), (x + 8, 50), (x + 8, 66)] +
               ell(x, 70, 8, 8, 0, 90, 5) + [(x + 1, 78)])
        for k in range(5):
            y = 44 + k * 7
            p.line(shade(col, -0.3), (x - 7, y), (x + 7, y + 6), 0.9)
        p.line(WHITE, (x - 5, 46), (x - 5.5, 64), 1.0)
        p.stroke(edge, loop)
        p.shape(shade(col, -0.25), [(x - 5.5, 38), (x + 5.5, 38), (x + 6, 42), (x - 6, 42)], edge)
    for x, y, a in ((40, 96, -10), (50, 94, 15), (60, 98, -5), (70, 94, 20), (80, 97, -15), (55, 90, 0),
                    (66, 89, 10), (46, 89, -20)):
        p.shape((250, 246, 230), rell(x, y, 5.2, 3.2, a, 14), (150, 140, 110))
        p.circle(WHITE, (x - 1.5, y - 1), 1.1)


def draw_dyes(p):
    """Two dye tubs, deep indigo and crimson, a dyed cloth hung over the rim and a stirring paddle."""
    tub = (172, 120, 70)
    cylinder(p, 76, 92, 17, 6, 20, tub, top=shade(tub, 0.1))
    p.oval((190, 40, 60), 76, 72, 14, 4.6)
    p.oval((230, 90, 100), 72, 71, 5, 1.4)
    stick(p, (74, 72), (92, 40), 2.2, LWOOD)
    p.shape(LWOOD, rot([(-3, 0), (3, 0), (3, 10), (-3, 10)], 92, 40, 150))
    cylinder(p, 44, 100, 20, 7, 24, tub, top=shade(tub, 0.1))
    for k in (8, 16):
        p.lines(IRON, ell(44, 100 - k, 20, 7, 10, 170, 12), 1.4)
    indigo = (64, 52, 190)
    p.oval(indigo, 44, 76, 16.5, 5.4)
    p.oval((120, 110, 230), 38, 75, 6, 1.6)
    cloth = [(26, 73), (36, 72), (34, 94), (31, 100), (27, 97), (25, 86)]
    p.shape((90, 76, 214), cloth, (36, 28, 110))
    p.poly((70, 58, 180), [(31, 72), (36, 72), (34, 94), (31, 100)])
    p.disc((90, 76, 214), (29, 104), 1.3, (36, 28, 110))


def draw_cocoa(p):
    """Two ridged cocoa pods, one split open on its cream beans, and a heap of brown cocoa beans."""
    pod, pod2 = (196, 106, 48), (150, 60, 50)

    def ridged(x, y, L, r, ang, col):
        pts = rot([(L / 2 * math.cos(math.radians(a)), r * math.sin(math.radians(a)) *
                    (1 - 0.25 * math.cos(math.radians(a)) ** 2)) for a in range(0, 361, 12)], x, y, ang)
        p.shape(col, pts)
        p.poly(shade(col, -0.2), rot([(L / 2 * math.cos(math.radians(a)), r * math.sin(math.radians(a)) * 0.95)
                                      for a in range(0, 181, 12)] + [(-L / 2, 0)], x, y, ang))
        for k in (-0.55, 0, 0.55):
            p.lines(shade(col, -0.3), rot([(L * 0.44 * t, k * r * math.sqrt(max(0, 1 - (t * 0.95) ** 2)))
                                           for t in (i / 8 - 1 for i in range(17))], x, y, ang), 0.8)
        p.line(shade(col, 0.35), *rot([(-L * 0.2, -r * 0.6), (L * 0.15, -r * 0.65)], x, y, ang), 1.2)
        p.stroke(shade(col, -0.45), pts)
    ridged(52, 58, 48, 15, -30, pod)
    # split pod: an open half with beans
    x, y = 70, 86
    half = rot([(24 * math.cos(math.radians(a)), 11 * math.sin(math.radians(a))) for a in range(0, 181, 12)], x, y, 8)
    p.shape(pod2, half + rot([(-24, 0), (24, 0)], x, y, 8)[:1])
    p.shape((236, 222, 190), rell(x, y, 21, 5.6, 8, 20), (130, 90, 60))
    for i in range(6):
        p.shape((244, 236, 214), rell(x - 14 + i * 5.6, y - 1 + i * 0.75, 3.2, 2.2, 8, 10), (150, 120, 90))
    # bean heap
    bean = (110, 64, 40)
    for bx, by, a in ((26, 98, 20), (32, 101, -10), (38, 98, 30), (30, 94, -30), (36, 94, 10), (44, 101, 0),
                      (22, 102, 0), (40, 103, 40)):
        p.shape(bean, rell(bx, by, 3.8, 2.4, a, 12), (60, 30, 18))
        p.line(shade(bean, 0.3), *rot([(-2, -0.6), (1.2, -0.8)], bx, by, a), 0.6)


def draw_coffee(p):
    """A coffee branch with glossy leaves and red cherries, over a wooden scoop of roasted beans."""
    br = (120, 90, 60)
    green = (40, 120, 70)
    stick(p, (60, 98), (60, 28), 2.4, br)
    for y, side, L in ((86, -1, 22), (86, 1, 22), (66, -1, 24), (66, 1, 24), (46, -1, 20), (46, 1, 20),
                       (30, -1, 12), (30, 1, 12)):
        leaf(p, (60, y), (60 + side * L, y - 8), 6 if L > 14 else 4,
             green if side < 0 else shade(green, -0.12))
    for cy in (82, 62, 42):
        for dx, dy in ((-4, 2), (4, 2), (0, 5), (-2, -1), (3, -2)):
            c = (204, 40, 40) if (dx + dy) % 3 else (232, 120, 50)
            p.disc(c, (60 + dx, cy + dy), 3.1, (110, 20, 20))
            p.circle(shade(c, 0.45), (60 + dx - 1, cy + dy - 1), 0.8)
    # scoop of beans in front
    sc = (176, 128, 80)
    p.shape(sc, ell(46, 98, 18, 6, 0, 180, 14) + [(28, 94), (64, 94)])
    p.egg(shade(sc, 0.1), 46, 94, 18, 5)
    p.shape(sc, [(64, 92), (80, 88), (82, 92), (64, 97)])
    bean = (92, 54, 32)
    for bx, by in ((34, 92), (40, 90), (46, 91), (52, 90), (58, 92), (38, 95), (44, 95), (50, 95), (56, 95),
                   (42, 87), (48, 87), (54, 88)):
        p.shape(bean, rell(bx, by, 3.2, 2.2, -15, 10), (44, 24, 14))
        p.line((50, 28, 16), (bx - 1.6, by - 0.4), (bx + 1.6, by + 0.4), 0.5)


# ----- money ------------------------------------------------------------------------------------------------
def draw_silver(p):
    """A cross-stacked pile of silver bars, with stacks of pieces of eight."""
    ag = (214, 220, 232)
    edge = (84, 92, 118)

    def bar(x, y, w, d):
        h = 6
        dx, dy = d * 0.6, -d * 0.55
        p.shape(shade(ag, -0.3), [(x + w, y), (x + w + dx, y + dy), (x + w + dx - 1.5, y + dy - h),
                                  (x + w - 1.5, y - h)], edge)
        p.shape(shade(ag, -0.08), [(x, y), (x + w, y), (x + w - 1.5, y - h), (x + 1.5, y - h)], edge)
        p.shape(shade(ag, 0.2), [(x + 1.5, y - h), (x + w - 1.5, y - h), (x + w + dx - 1.5, y + dy - h),
                                 (x + dx + 1.5, y + dy - h)], edge)
        p.line(WHITE, (x + 4, y - h + dy * 0.3), (x + w * 0.5, y - h + dy * 0.3), 1.0)
    for i, x in enumerate((24, 47, 70)):
        bar(x, 96, 20, 14)
    for x in (34, 57):
        bar(x, 86, 20, 14)
    bar(45, 76, 20, 14)
    coin_stack(p, 30, 104, 7.5, 3, ag)
    coin_stack(p, 92, 104, 7.5, 5, shade(ag, -0.04))


def draw_gold(p):
    """An open treasure chest heaped with gold coins, a few spilled on the ground."""
    au = (250, 204, 52)
    edge = (130, 80, 20)
    wood = (150, 84, 50)
    # lid, open behind
    lid = [(28, 62), (30, 40), (78, 34), (84, 52)]
    p.shape(shade(wood, -0.1), lid)
    p.poly(shade(wood, -0.35), [(32, 58), (33, 44), (76, 39), (80, 52)])
    p.line(au, (40, 60), (42, 39), 2.6)
    p.line(au, (72, 54), (72, 36), 2.6)
    # coins heap above the chest front
    for x, y in ((34, 62), (44, 58), (54, 56), (64, 58), (74, 62), (40, 66), (52, 64), (64, 66), (82, 64),
                 (46, 54), (58, 51), (70, 55)):
        coin(p, x, y, 6.5, au, edge)
    # chest body
    box(p, 24, 98, 56, 30, 18, wood, top=shade(wood, 0.1))
    p.shape(au, [(24, 74), (80, 74), (80, 78), (24, 78)], edge)
    for x in (34, 70):
        p.shape(au, [(x - 2.5, 68), (x + 2.5, 68), (x + 2.5, 98), (x - 2.5, 98)], edge)
    p.shape(au, [(49, 76), (55, 76), (55, 86), (49, 86)], edge)
    p.circle(DARK, (52, 80), 1.2)
    for x, y in ((88, 102), (96, 98), (92, 94)):
        coin(p, x, y, 5.5, au, edge)


# ----- made goods -------------------------------------------------------------------------------------------
def draw_cloth(p):
    """A stack of folded cloth in plum and lilac, the top length draped down the front, shears on top."""
    plum, lilac, deep, pale = (176, 104, 196), (206, 160, 220), (126, 68, 156), (232, 210, 240)
    x, w, d, t = 28, 52, 16, 7.5

    def layer(y, col, dx=0):
        dxx, dyy = d * 0.6, -d * 0.55
        x0 = x + dx
        p.shape(shade(col, -0.25), [(x0 + w, y), (x0 + w + dxx, y + dyy), (x0 + w + dxx, y - t + dyy),
                                    (x0 + w, y - t)])
        front = [(x0 + 2, y), (x0 + w, y), (x0 + w, y - t), (x0 + 2, y - t)] + ell(x0 + 2, y - t / 2, 3, t / 2,
                                                                                    270, 90, 8)[::-1]
        p.shape(col, front)
        p.shape(shade(col, 0.2), [(x0, y - t), (x0 + w, y - t), (x0 + w + dxx, y - t + dyy), (x0 + dxx, y - t + dyy)])
        p.line(shade(col, 0.35), (x0 + 2, y - t + 1.6), (x0 + w - 2, y - t + 1.6), 0.8)
    for i, (col, dx) in enumerate(((deep, 0), (lilac, -2), (plum, 1), (pale, -1))):
        layer(100 - i * t, col, dx)
    top = 100 - 4 * t
    # draped length from the top layer down over the front
    drape = [(54, top), (74, top), (78, top + 4), (80, 104), (66, 106), (60, 98), (56, top + 6)]
    p.shape(plum, drape)
    p.poly(shade(plum, -0.18), [(70, top), (74, top), (78, top + 4), (80, 104), (72, 105)])
    for k in (0, 6):
        p.line(shade(plum, -0.3), (60 + k, top + 6), (64 + k, 100), 0.8)
    p.stroke(shade(plum, -0.42), drape)
    # shears
    for a in (-18, 12):
        bl = rot([(0, -1.2), (20, -0.4), (20, 0.4), (0, 1.2)], 36, top - 6, a)
        p.shape(STEEL, bl, (70, 76, 96))
    p.egg(DARK, 34, top - 6, 3, 2)


def draw_tools(p):
    """A hammer and a hand saw crossed over a small blue-grey tool chest, tongs on the lid."""
    chest = (86, 100, 128)
    # saw (behind)
    saw = rot([(-24, -6), (14, -3), (14, 3), (-24, 2)], 58, 54, 52)
    p.shape(STEEL, saw, (70, 76, 96))
    a, b = rot([(-23, 2), (13, 3)], 58, 54, 52)
    for i in range(10):
        t = i / 9
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        p.shape(STEEL, rot([(-1.4, 0), (1.4, 0), (0, 2.6)], x, y, 52), (70, 76, 96))
    p.shape(LWOOD, rot([(14, -6), (24, -6), (24, 6), (14, 6)], 58, 54, 52))
    p.oval(DWOOD, *rot([(19, 0)], 58, 54, 52)[0], 2.4, 2)
    # hammer
    stick(p, (82, 34), (44, 86), 3.2, LWOOD)
    head = rot([(-12, -4.5), (10, -4.5), (12, -2), (12, 2), (10, 4.5), (-6, 4.5), (-12, 1)], 82, 34, -36 + 90)
    p.shape((120, 126, 140), head, (50, 54, 66))
    p.poly((150, 156, 170), rot([(-11, -3.6), (9, -3.6), (9, -1), (-11, -0.5)], 82, 34, 54))
    # chest
    box(p, 26, 102, 56, 20, 14, chest)
    p.shape(IRON, [(48, 86), (60, 86), (60, 90), (48, 90)])
    p.line(shade(chest, 0.3), (30, 88), (78, 88), 1.0)
    for x in (32, 76):
        p.shape(IRON, [(x - 2, 82), (x + 2, 82), (x + 2, 102), (x - 2, 102)])


def draw_weapons(p):
    """A rack of pikes and a halberd, a sword and a red shield propped in front."""
    red = (186, 56, 52)
    stick(p, (24, 74), (96, 74), 3, DWOOD)
    stick(p, (24, 100), (96, 100), 3, DWOOD)
    for x in (26, 94):
        stick(p, (x, 102), (x, 68), 3, WOOD)
    for x, top in ((36, 22), (50, 16), (64, 20), (78, 24)):
        stick(p, (x, 100), (x, top + 10), 2.0, LWOOD)
        p.shape(STEEL, [(x, top), (x + 3, top + 6), (x + 1.8, top + 11), (x - 1.8, top + 11), (x - 3, top + 6)],
                (70, 76, 96))
    # halberd axe on the 50 pike
    p.shape(STEEL, [(51, 28), (60, 25), (62, 33), (60, 39), (51, 34)], (70, 76, 96))
    # sword leaning
    blade(p, (88, 46), (72, 98), 3.0)
    p.line((150, 110, 50), (82, 50), (95, 55), 2.4)
    p.line(DWOOD, (88, 46), (91, 38), 2.4)
    p.circle((214, 170, 60), (92, 36), 2.2)
    # heater shield
    shield = [(28, 64), (58, 64), (58, 80), (54, 92), (43, 100), (32, 92), (28, 80)]
    p.shape(red, shield, (90, 24, 24))
    p.poly(shade(red, -0.2), [(43, 64), (58, 64), (58, 80), (54, 92), (43, 100)])
    p.shape((236, 206, 96), [(41, 64), (45, 64), (45, 99), (41, 98)], (120, 90, 30))
    p.shape((236, 206, 96), [(28, 74), (58, 74), (58, 78), (28, 78)], (120, 90, 30))
    p.stroke((90, 24, 24), shield, 1.2)


def draw_rope(p):
    """A heavy coil of hemp rope beside a folded, tied bundle of sailcloth."""
    rope = (214, 184, 120)
    edge = (120, 90, 50)
    canvas = (244, 238, 220)
    # folded sail behind
    box(p, 52, 84, 38, 22, 20, canvas, top=WHITE, side=(214, 206, 186), edge=(140, 130, 110))
    for y in (68, 76):
        p.line((200, 190, 168), (52, y), (90, y), 0.8)
    p.lines(edge, [(70, 84), (70, 62), (82, 51)], 1.6)
    # coil: stacked flat rings
    x, y = 44, 98
    for i in range(5):
        cy = y - i * 4.4
        p.egg(shade(rope, -0.08 if i % 2 else 0), x, cy, 22, 9, edge)
    p.egg(rope, x, y - 22, 22, 9, edge)
    for rr in (17, 12, 7):
        p.oval(shade(rope, -0.3), x, y - 22, rr, rr * 0.4, 1.2)
    for a in range(0, 360, 24):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.line(shade(rope, -0.22), (x + c * 18, y - 22 + s * 7.4), (x + c * 21, y - 22 + s * 8.6), 0.6)
    p.oval((70, 50, 30), x, y - 22, 3.5, 1.4)
    p.lines(edge, [(x + 20, y - 18), (x + 30, y - 8), (x + 40, y + 2)], 3.2)
    p.lines(rope, [(x + 20, y - 18), (x + 30, y - 8), (x + 40, y + 2)], 1.8)


def draw_glass(p):
    """Blown glass: a tall green bottle, a round blue flask and a goblet, with bright highlights."""
    def glass_shape(pts, col, hl):
        p.shape(col, pts, shade(col, -0.5))
        p.lines(WHITE, hl, 1.6)
    green, blue, clear = (86, 176, 150), (110, 180, 230), (186, 228, 240)
    # tall bottle
    x = 40
    bottle = [(x - 3, 26), (x + 3, 26), (x + 3, 44), (x + 10, 54), (x + 10, 98), (x - 10, 98), (x - 10, 54),
              (x - 3, 44)]
    glass_shape(bottle, green, [(x - 6, 58), (x - 6, 90)])
    p.poly(shade(green, -0.18), [(x + 3, 44), (x + 10, 54), (x + 10, 98), (x + 4, 98), (x + 4, 54)])
    p.shape((150, 100, 60), [(x - 3.6, 22), (x + 3.6, 22), (x + 3.6, 28), (x - 3.6, 28)])
    # round flask
    fx = 70
    p.shape(blue, [(fx - 3, 46), (fx + 3, 46), (fx + 3, 62), (fx - 3, 62)], shade(blue, -0.5))
    p.shape(blue, ell(fx, 80, 17, 18, 0, 360, 28), shade(blue, -0.5))
    p.poly(shade(blue, -0.15), ell(fx, 80, 17, 18, -50, 110, 12) + [(fx + 2, 80)])
    p.lines(WHITE, ell(fx, 80, 12, 13, 190, 250, 6), 1.8)
    p.egg(shade(blue, 0.3), fx, 46, 4.2, 1.6)
    # goblet in front
    gx = 90
    glass_shape([(gx + 9, 76)] + ell(gx, 76, 9, 12, 0, 180, 12), clear, [(gx - 5, 79), (gx - 3, 84)])
    p.shape(clear, [(gx - 1.4, 87), (gx + 1.4, 87), (gx + 1.4, 98), (gx - 1.4, 98)], shade(clear, -0.5))
    p.egg(clear, gx, 99, 7, 2.4, shade(clear, -0.5))
    p.egg(shade(clear, -0.1), gx, 76, 9, 2.8, shade(clear, -0.5))


def draw_leather(p):
    """A pair of tall riding boots, and a rolled, strapped tanned hide behind them."""
    hide = (196, 138, 80)
    edge = (80, 48, 24)
    log_end(p, 62, 86, 10, 34, hide, shade(hide, 0.2), rings=0)
    p.lines(shade(hide, -0.3), [(62 + 4 * math.cos(math.radians(a)) * a / 720,
                                 86 + 8 * math.sin(math.radians(a)) * a / 720) for a in range(0, 721, 30)], 0.8)
    for x in (76, 90):
        p.shape((92, 58, 34), [(x - 2, 75.5), (x + 2, 75.5), (x + 2, 96.5), (x - 2, 96.5)])
    boot = (112, 64, 36)

    def one(x, y, col):
        b = [(x - 6, y - 46), (x + 6, y - 46), (x + 6, y - 7), (x + 8, y - 3), (x + 8, y + 1), (x - 20, y + 1),
             (x - 20, y - 3), (x - 15, y - 8), (x - 6, y - 11)]
        p.shape(col, b, edge)
        p.poly(shade(col, -0.2), [(x + 1, y - 46), (x + 6, y - 46), (x + 6, y - 7), (x + 8, y - 3), (x + 8, y - 1),
                                  (x + 1, y - 1)])
        p.stroke(edge, b)
        p.shape(shade(col, 0.25), [(x - 7.5, y - 49), (x + 7.5, y - 49), (x + 7.5, y - 41), (x - 7.5, y - 41)], edge)
        p.shape(DARK, [(x - 20, y - 1), (x + 8, y - 1), (x + 8, y + 2.5), (x - 20, y + 2.5)])
        p.line(shade(col, 0.35), (x - 3.5, y - 38), (x - 3.5, y - 14), 1.1)
        p.line(shade(col, 0.35), (x - 16, y - 5), (x - 10, y - 7), 1.0)
    one(56, 96, shade(boot, -0.12))
    one(42, 101, boot)


def draw_gunpowder(p):
    """A black powder keg with a lit fuse, a spill of powder and a pyramid of cannonballs."""
    keg = (78, 74, 76)
    edge = (24, 22, 26)
    x, y = 50, 98
    cylinder(p, x, y, 20, 7, 40, keg, top=(110, 104, 100), edge=edge)
    for k, w in ((6, 2.4), (20, 2.0), (34, 2.4)):
        p.lines((150, 120, 70), ell(x, y - k, 20, 7, 5, 175, 14), w)
    for dx in (-12, -4, 4, 12):
        p.line(shade(keg, -0.25), (x + dx, y - 40 + 6.5 - abs(dx) * 0.2), (x + dx, y + 6 - abs(dx) * 0.2), 0.6)
    p.shape((236, 230, 214), [(x - 7, y - 26), (x + 5, y - 26), (x + 5, y - 16), (x - 7, y - 16)], (120, 110, 90))
    p.lines(DARK, [(x - 4, y - 24), (x + 2, y - 18)], 1.2)
    p.lines(DARK, [(x + 2, y - 24), (x - 4, y - 18)], 1.2)
    # fuse with spark
    p.lines((60, 50, 40), [(x + 4, y - 42), (x + 10, y - 52), (x + 18, y - 56)], 1.6)
    for a in range(0, 360, 45):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.line((255, 200, 60), (x + 18, y - 56), (x + 18 + c * 5, y - 56 + s * 5), 1.0)
    p.circle((255, 240, 160), (x + 18, y - 56), 2.2)
    # spilled powder
    p.shape((40, 38, 42), ell(26, 102, 10, 3.4, 180, 360, 10), edge)
    # cannonballs
    for bx, by in ((80, 100), (94, 100), (87, 89)):
        p.disc((60, 62, 70), (bx, by), 7, edge)
        p.circle((130, 134, 146), (bx - 2.4, by - 2.4), 2)


# ----- registry ---------------------------------------------------------------------------------------------
# key: (draw function, silhouette outline colour)
OBJECTS = {
    "grain": (draw_grain, (110, 76, 24)),
    "fish": (draw_fish, (34, 58, 92)),
    "salt": (draw_salt, (78, 94, 120)),
    "wine": (draw_wine, (66, 32, 34)),
    "wool": (draw_wool, (82, 72, 64)),
    "cotton": (draw_cotton, (64, 60, 52)),
    "timber": (draw_timber, (66, 42, 24)),
    "iron": (draw_iron, (34, 34, 44)),
    "cloth": (draw_cloth, (70, 38, 88)),
    "tools": (draw_tools, (36, 40, 54)),
    "weapons": (draw_weapons, (56, 26, 26)),
    "sugar": (draw_sugar, (44, 64, 100)),
    "tobacco": (draw_tobacco, (54, 50, 24)),
    "furs": (draw_furs, (66, 40, 26)),
    "ivory": (draw_ivory, (100, 82, 54)),
    "spices": (draw_spices, (90, 52, 24)),
    "silver": (draw_silver, (64, 70, 96)),
    "gold": (draw_gold, (100, 60, 18)),
    "horses": (draw_horses, (56, 32, 20)),
    "cattle": (draw_cattle, (74, 56, 44)),
    "stone": (draw_stone, (82, 80, 76)),
    "copper": (draw_copper, (90, 44, 20)),
    "hemp": (draw_hemp, (40, 62, 30)),
    "olives": (draw_olives, (86, 46, 26)),
    "silk": (draw_silk, (110, 46, 80)),
    "dyes": (draw_dyes, (40, 30, 70)),
    "cocoa": (draw_cocoa, (60, 30, 18)),
    "coffee": (draw_coffee, (34, 30, 22)),
    "rope": (draw_rope, (96, 74, 40)),
    "glass": (draw_glass, (30, 76, 94)),
    "leather": (draw_leather, (62, 38, 20)),
    "gunpowder": (draw_gunpowder, (20, 20, 24)),
}


def _dilate(layer, ink, width):
    """The layer with a solid `ink` outline `width` tile px wide round its silhouette."""
    sil = pygame.mask.from_surface(layer, 60).to_surface(setcolor=ink + (255,), unsetcolor=(0, 0, 0, 0))
    out = pygame.Surface(layer.get_size(), pygame.SRCALPHA)
    rr = width * K
    for rad in (rr, rr * 0.66, rr * 0.33):
        for a in range(0, 360, 20):
            out.blit(sil, (round(math.cos(math.radians(a)) * rad), round(math.sin(math.radians(a)) * rad)))
    out.blit(layer, (0, 0))
    return out


def master(key):
    """The object for `key` on a transparent 120 x 140 tile frame at K x scale, with shadow and outline.

    Not cached: a master is about 1 MB, so draw_good builds one, scales it to the size asked for and lets it go."""
    fn, ink = OBJECTS[key]
    layer = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
    fn(Pen(layer))
    out = pygame.Surface((W * K, H * K), pygame.SRCALPHA)
    r = layer.get_bounding_rect(1)
    sh = pygame.Surface((max(1, int(r.w * 0.9)), int(13 * K)), pygame.SRCALPHA)
    pygame.draw.ellipse(sh, (0, 0, 0, 46), sh.get_rect())
    out.blit(sh, (r.centerx - sh.get_width() / 2, r.bottom - sh.get_height() * 0.62))
    out.blit(_dilate(layer, ink, OUTLINE), (0, 0))
    return out


def _shrink(surf, w, h):
    """Smooth downscale in halving steps, so thin parts stay crisp at small sizes."""
    while surf.get_width() > w * 2:
        surf = pygame.transform.smoothscale(surf, (surf.get_width() // 2, surf.get_height() // 2))
    return pygame.transform.smoothscale(surf, (w, h))


@BoundedCache("goodsobjects.goods", 512).memo
def draw_good(key, size):
    """The object for good `key` on a transparent tile frame `size` px tall (and size * 6 / 7 wide).

    Cached per (key, size): the only memory kept is the surfaces of the sizes drawn."""
    size = max(4, int(size))
    return _shrink(master(key), max(3, round(size * W / H)), size)
