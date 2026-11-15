"""The shared drawing kit for Hexa's normal-map pieces. Rule book: docs/design/map/pieces/GUIDE.md.

A piece is the picture of one hex's improvement at one level in one season, at hex radius 60.
Every family module imports this kit and exposes  draw(level, season) -> pygame.Surface  (see README.md).

Coordinates: everything a family module passes to the kit is in PIECE PIXELS at 100% size, with the origin at
the hex centre, x to the right and y down. The kit draws at 2x and scales down, so never multiply by 2 yourself.
The hex is pointy-top, 104 px wide and 102 px tall (north-south distances are already squashed to 85%).

Colours and shapes of the house, trees, walls, ship and shadows are taken from the style frame
(tools/worldmap/style_frame/frame.py and render.py), so pieces sit in the same world.
"""
import math
import os
import random

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame

pygame.init()

# ------------------------------------------------------------------ canvas
SS = 2                      # drawn at 2x, smoothscaled to 1x
R = 60                      # hex radius in px at 100%
TILT = 0.85                 # the ground plane: north-south distances at 85%
SIZE = 112                  # the piece canvas, square, at 100%
C = SIZE // 2               # the hex centre on the canvas
HEX_W = R * math.sqrt(3)    # 103.9
HEX_H = 2 * R * TILT        # 102
MARGIN = 3                  # standing things stay this far inside the hex border
FEATHER = 5                 # the ground fades out over this many px at the hex border
SEASONS = ("spring", "summer", "autumn", "winter")

INK = (52, 44, 46)
SHADOW = (30, 50, 30)
SHADOW_ALPHA = 46


NO_BASE = False               # set by take_apart(): pieces are then drawn without their ground base (for the map)
LAST = None                   # the Piece most recently finished (take_apart() reads it)


def hex_points(shrink=0.0):
    """The six corners in piece px (origin at the centre), pulled in by `shrink` px."""
    r = R - shrink / math.cos(math.radians(30))
    return [(r * math.cos(math.radians(-90 + 60 * k)), r * math.sin(math.radians(-90 + 60 * k)) * TILT) for k in range(6)]


def in_hex(x, y, margin=0.0):
    """True if the piece-px point lies inside the hex, `margin` px clear of the border."""
    ax, ay = abs(x), abs(y) / TILT
    inner = R * math.cos(math.radians(30)) - margin
    return ax <= inner and ax * 0.5 + ay * math.cos(math.radians(30)) <= inner


# ------------------------------------------------------------------ colour helpers
def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])


# ------------------------------------------------------------------ the palette (named tokens)
# Fixed tokens: the same in every season.
STONE = (214, 202, 174)         # town walls, quays, moles
STONE_D = (176, 164, 140)
STONE_GREY = (176, 172, 166)    # castles, mines
STONE_GREY_D = (132, 128, 126)
PLASTER = [(240, 228, 196), (232, 200, 140), (234, 192, 166), (246, 240, 228), (226, 210, 170)]   # house walls
CHURCH = (236, 226, 204)
ROOF = (204, 94, 62)            # tile roofs
ROOF_D = (160, 70, 50)
THATCH = (198, 168, 104)        # huts, barns
THATCH_D = (158, 128, 78)
SLATE = (112, 116, 132)         # castle and tower roofs
SLATE_D = (82, 86, 102)
TIMBER = (150, 110, 72)         # palisades, jetties, fences, frames
TIMBER_D = (112, 80, 54)
TRUNK = (92, 70, 50)
DOOR = (70, 56, 50)
DOME = (150, 160, 150)
DOME_L = (178, 188, 176)
HULL = (120, 78, 52)
SAIL = (246, 240, 226)
SAIL_D = (214, 206, 190)
ROAD = (226, 206, 152)
ROAD_EDGE = (128, 100, 66)
SNOW = (242, 245, 250)
SNOW_D = (206, 214, 228)        # the shaded side of snow
SMOKE = (236, 236, 232)
SMOKE_SNOW = (186, 190, 202)     # smoke in winter: grey, so it shows against snow
FLAG = (196, 52, 48)
SALT = (248, 246, 240)
SPOIL = (150, 140, 132)         # mine waste heaps
SPOIL_D = (112, 104, 100)

# Season tokens. PAL[season][token].
PAL = {
    "spring": dict(
        grass=(152, 196, 92), farm=(176, 202, 104), wood=(120, 172, 82), rock=(170, 156, 130), sand=(234, 216, 162),
        soil=(152, 114, 78), soil_d=(124, 92, 64), tuft=(112, 158, 72), hedge=(84, 140, 66), hedge_d=(56, 100, 52),
        leaf=((44, 76, 40), (86, 150, 66), (118, 180, 80), (156, 208, 104)),            # outline, dark, mid, light
        conifer=((34, 56, 40), (66, 120, 70), (46, 92, 58)),                            # outline, lit, shaded
        sea=(71, 143, 192), shallow=(96, 168, 210), foam=(226, 242, 248), river=(74, 146, 206), river_edge=(44, 92, 140),
        blossom=(250, 232, 236)),
    "summer": dict(
        grass=(146, 186, 86), farm=(178, 198, 98), wood=(112, 164, 78), rock=(170, 156, 130), sand=(234, 216, 162),
        soil=(162, 126, 86), soil_d=(132, 100, 70), tuft=(112, 150, 70), hedge=(70, 128, 60), hedge_d=(46, 92, 50),
        leaf=((38, 60, 38), (70, 128, 60), (96, 158, 72), (130, 186, 92)),
        conifer=((34, 56, 40), (66, 120, 70), (46, 92, 58)),
        sea=(71, 143, 192), shallow=(96, 168, 210), foam=(226, 242, 248), river=(74, 146, 206), river_edge=(44, 92, 140),
        blossom=None),
    "autumn": dict(
        grass=(172, 174, 84), farm=(188, 178, 98), wood=(152, 152, 76), rock=(166, 150, 126), sand=(230, 212, 160),
        soil=(140, 102, 70), soil_d=(112, 80, 56), tuft=(150, 140, 70), hedge=(150, 112, 52), hedge_d=(108, 78, 44),
        leaf=((78, 50, 32), (176, 96, 44), (210, 134, 52), (236, 178, 76)),             # rust; see LEAF_AUTUMN for the mix
        conifer=((34, 56, 40), (66, 116, 68), (46, 90, 56)),
        sea=(66, 134, 182), shallow=(92, 160, 202), foam=(226, 242, 248), river=(70, 138, 196), river_edge=(44, 92, 140),
        blossom=None),
    "winter": dict(
        grass=(228, 233, 238), farm=(232, 236, 240), wood=(216, 224, 230), rock=(208, 208, 208), sand=(234, 230, 214),
        soil=(176, 156, 136), soil_d=(150, 128, 110), tuft=(150, 150, 110), hedge=(108, 96, 76), hedge_d=(78, 68, 56),
        leaf=((70, 54, 44), (104, 82, 62), (104, 82, 62), (104, 82, 62)),               # bare: only twigs are drawn
        conifer=((34, 56, 40), (62, 106, 72), (44, 82, 60)),
        sea=(62, 122, 166), shallow=(104, 158, 194), foam=(232, 242, 248), river=(86, 142, 190), river_edge=(52, 96, 140),
        blossom=None),
}
# Autumn broadleaves are a fixed mix of three colourings, chosen by the tree's index (i % 3): rust, gold, late green.
LEAF_AUTUMN = [
    ((78, 50, 32), (176, 96, 44), (210, 134, 52), (236, 178, 76)),
    ((84, 62, 30), (190, 144, 44), (222, 180, 62), (242, 212, 104)),
    ((48, 62, 36), (110, 132, 58), (140, 160, 68), (176, 190, 90)),
]
ICE = (206, 226, 238)
ICE_D = (172, 200, 220)

# Crop colours per season: strip colours cycle through the list. Each family owns its crop (see the guide).
CROPS = {
    "wheat": dict(
        spring=[(150, 192, 88), (168, 202, 98), (136, 178, 84), (160, 122, 84)],          # green shoots, one bare strip
        summer=[(222, 198, 104), (232, 212, 128), (210, 180, 96), (226, 204, 112)],       # ripe gold
        autumn=[(142, 104, 72), (204, 182, 122), (156, 118, 80), (128, 94, 66)],          # ploughed earth and stubble
        winter=[(238, 241, 245), (214, 224, 236), (238, 241, 245), (190, 170, 148)]),     # snow, one strip of bare earth
    "garden": dict(                                                                       # small plots by houses
        spring=[(128, 176, 84), (160, 124, 86), (146, 190, 96)],
        summer=[(110, 164, 80), (150, 186, 92), (170, 134, 90)],
        autumn=[(150, 112, 76), (166, 160, 84), (134, 98, 68)],
        winter=[(230, 234, 240), (222, 228, 236), (204, 190, 172)]),
    "meadow": dict(                                                                       # fenced pasture, hay
        spring=[(166, 206, 104)], summer=[(170, 200, 100)], autumn=[(186, 182, 98)], winter=[(234, 238, 242)]),
    "vine_soil": dict(
        spring=[(176, 140, 104)], summer=[(180, 146, 106)], autumn=[(168, 130, 96)], winter=[(226, 228, 232)]),
    "vine": dict(                                                                         # the row colour
        spring=[(120, 170, 76)], summer=[(72, 128, 62)], autumn=[(170, 70, 60)], winter=[(96, 76, 60)]),
    "olive_soil": dict(
        spring=[(206, 196, 140)], summer=[(212, 198, 142)], autumn=[(204, 188, 136)], winter=[(226, 226, 222)]),
}
CROP_EDGE = dict(spring=(104, 130, 62), summer=(128, 124, 60), autumn=(100, 78, 54), winter=(140, 152, 176))


def crop(name, season):
    return CROPS[name][season]


# ------------------------------------------------------------------ the pen (2x drawing with ink)
class Pen:
    """Draws on a 2x surface in piece px. Every family uses this for its own landmarks, so ink and scale agree."""

    def __init__(self, surf):
        self.s = surf

    @staticmethod
    def T(p):
        return ((p[0] + C) * SS, (p[1] + C) * SS)

    @staticmethod
    def W(w):
        return max(1, int(round(w * SS)))

    def poly(self, pts, fill=None, ink=INK, w=1):
        q = [self.T(p) for p in pts]
        if fill is not None:
            pygame.draw.polygon(self.s, fill, q)
        if ink is not None:
            pygame.draw.polygon(self.s, ink, q, self.W(w))

    def rect(self, x, y, w, h, fill=None, ink=INK, lw=1):
        """x, y is the top left corner."""
        self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], fill, ink, lw)

    def box(self, x, y, w, h, col, ink=INK, side=0.24):
        """An upright wall face standing on (x, y) = middle of its foot: lit, with a shaded strip on the right."""
        x0 = x - w / 2
        self.rect(x0, y - h, w, h, col, None)
        self.rect(x0 + w * (1 - side), y - h, w * side, h, shade(col, 0.84), None)
        if ink is not None:
            self.rect(x0, y - h, w, h, None, ink)

    def line(self, a, b, col=INK, w=1):
        pygame.draw.line(self.s, col, self.T(a), self.T(b), self.W(w))

    def lines(self, pts, col=INK, w=1, closed=False):
        if len(pts) > 1:
            pygame.draw.lines(self.s, col, closed, [self.T(p) for p in pts], self.W(w))

    def circle(self, x, y, r, fill=None, ink=None, w=1):
        if fill is not None:
            pygame.draw.circle(self.s, fill, self.T((x, y)), r * SS)
        if ink is not None:
            pygame.draw.circle(self.s, ink, self.T((x, y)), r * SS, self.W(w))

    def ellipse(self, x, y, w, h, fill=None, ink=None, lw=1):
        """x, y is the centre."""
        r = pygame.Rect(0, 0, max(1, int(w * SS)), max(1, int(h * SS)))
        r.center = self.T((x, y))
        if fill is not None:
            pygame.draw.ellipse(self.s, fill, r)
        if ink is not None:
            pygame.draw.ellipse(self.s, ink, r, self.W(lw))

    def dot(self, x, y, col, size=1.0):
        self.rect(x - size / 2, y - size / 2, size, size, col, None)


def ring_points(cx, cy, rx, ry, a0, a1, n=40):
    return [(cx + math.cos(a0 + (a1 - a0) * q / n) * rx, cy + math.sin(a0 + (a1 - a0) * q / n) * ry) for q in range(n + 1)]


# ------------------------------------------------------------------ the piece
class Piece:
    """One hex picture. Ground-plane calls draw at once, in call order. Standing calls are queued and drawn back to
    front (by the y of their foot) in finish()."""

    def __init__(self, season, ground="grass", seed=0, texture=True, base=None):
        assert season in SEASONS, season
        self.season = season
        self.pal = PAL[season]
        self.winter = season == "winter"
        big = (SIZE * SS, SIZE * SS)
        self.g = pygame.Surface(big, pygame.SRCALPHA)      # the ground plane
        self.sh = pygame.Surface(big)                      # soft shadows
        self.sh.fill((255, 255, 255))
        self.sh.set_colorkey((255, 255, 255))
        self.o = pygame.Surface(big, pygame.SRCALPHA)      # standing things
        self.gp = Pen(self.g)
        self.op = Pen(self.o)
        self.queue = []                 # (order y, n, fn); the true foot y of entry n is self.foot[n]
        self.foot = {}
        self.n = 0
        self.rnd = random.Random(seed * 7919 + 13)          # never seeded by the season: the same ground in all seasons
        self.ground_kind = ground
        self.has_base = (not NO_BASE) if base is None else base     # False: only the ground detail, for the map
        self.base(ground, texture)

    # -------------------------------------------------------------- ground plane
    def base(self, kind, texture=True):
        """The season ground: a flat fill with soft mottling. The same mottling in every season and level."""
        col = self.pal[kind]
        rnd = random.Random(self.rnd.random())          # drawn from in every case, so the scatter never shifts
        if not self.has_base:
            self.g.fill((0, 0, 0, 0))
            return
        self.g.fill(col + (255,))
        if not texture:
            return
        for i in range(26):
            x, y = rnd.uniform(-52, 52), rnd.uniform(-50, 50)
            w, h = rnd.uniform(10, 26), rnd.uniform(5, 11)
            f = 1.035 if i % 2 else 0.965
            if self.winter:
                f = 1.0 if i % 2 else 0.972          # snow never goes brighter than its base, only bluer
                c2 = mix(shade(col, f), SNOW_D, 0.0 if i % 2 else 0.25)
            else:
                c2 = shade(col, f)
            self.gp.ellipse(x, y, w, h, c2)

    def tufts(self, n=14, area=None, avoid=()):
        """Grass tufts (in winter: dry stalks through the snow). `avoid` is a list of (x, y, r) to keep clear."""
        rnd = random.Random(self.rnd.random())
        col = self.pal["tuft"]
        done = 0
        for _ in range(n * 6):
            if done >= n:
                break
            x, y = rnd.uniform(-46, 46), rnd.uniform(-44, 44)
            if not in_hex(x, y, 6) or any(math.hypot(x - a[0], (y - a[1]) / TILT) < a[2] for a in avoid):
                continue
            if area and not (area[0] <= x <= area[2] and area[1] <= y <= area[3]):
                continue
            for q in (-1, 0, 1):
                self.gp.line((x + q, y), (x + q * 1.6, y - 2.2), col, 0.5)
            done += 1

    def stones(self, spots):
        """Small boulders lying on the ground. spots: [(x, y, r)]."""
        for x, y, r in spots:
            pts = [(x + math.cos(a) * r, y + math.sin(a) * r * 0.7) for a in [q * math.pi / 3 for q in range(6)]]
            self.gp.poly(pts, (196, 186, 166) if not self.winter else SNOW, (84, 74, 68), 0.5)
            self.gp.poly([pts[0], pts[1], pts[2], (x, y)], (140, 130, 118), None)

    def patch(self, pts, col, ink=None, w=0.5):
        """A flat shape on the ground (a yard, a pan, a clearing)."""
        self.gp.poly(pts, col, ink, w)

    def over(self, fn, alpha=0.5):
        """Draw fn(pen) on the ground half-transparent (alpha 0..1), so it tints whatever ground lies under it.
        Use it for everything that is a change of the ground itself: trodden earth, scrub, tracks, yards."""
        if alpha >= 0.999:
            fn(self.gp)
            return
        lay = pygame.Surface(self.g.get_size(), pygame.SRCALPHA)
        fn(Pen(lay))
        a = pygame.Surface(self.g.get_size(), pygame.SRCALPHA)
        a.fill((255, 255, 255, int(round(255 * alpha))))
        lay.blit(a, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
        self.g.blit(lay, (0, 0))

    def blob(self, x, y, w, h, col, alpha=1.0, edge=None, lw=0.5):
        """A soft ellipse on the ground, centre (x, y). alpha < 1 lays it half-transparent over the ground (use this
        for trodden or cleared ground). edge: a darker rim colour (a mound, a millstone, a clearing)."""
        self.over(lambda pen: pen.ellipse(x, y, w, h, col, edge, lw), alpha)

    def scrub(self, x, y, w, h, dark=0.07):
        """A darker patch of the ground itself (scrub, rough grass, the place where work will come): a
        half-transparent shade, so it works on any ground colour. dark 0.07 = the ground colour x 0.93."""
        self.over(lambda pen: pen.ellipse(x, y, w, h, (0, 0, 0)), dark)

    def field(self, cx, cy, w, h, angle=0.0, cols=None, strips=5, along=True, edge=None, furrows=False):
        """A block of field strips on the ground. cx, cy: centre; w, h: size before the tilt; angle in degrees.
        cols: strip colours, cycled (use kit.crop(name, season)). along=True: strips run along w.
        furrows: thin darker lines inside each strip (ploughed earth, winter furrows). Returns the corner points."""
        cols = cols or crop("wheat", self.season)
        edge = edge or CROP_EDGE[self.season]
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))

        def P(u, v):
            return (cx + ca * u - sa * v, cy + (sa * u + ca * v) * TILT)
        for i in range(strips):
            if along:
                v0, v1 = -h / 2 + h * i / strips, -h / 2 + h * (i + 1) / strips
                pts = [P(-w / 2, v0), P(w / 2, v0), P(w / 2, v1), P(-w / 2, v1)]
            else:
                u0, u1 = -w / 2 + w * i / strips, -w / 2 + w * (i + 1) / strips
                pts = [P(u0, -h / 2), P(u1, -h / 2), P(u1, h / 2), P(u0, h / 2)]
            c = cols[i % len(cols)]
            self.gp.poly(pts, c, None)
            if furrows:
                a = ((pts[0][0] + pts[3][0]) / 2, (pts[0][1] + pts[3][1]) / 2)
                b = ((pts[1][0] + pts[2][0]) / 2, (pts[1][1] + pts[2][1]) / 2)
                if not along:
                    a = ((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2)
                    b = ((pts[3][0] + pts[2][0]) / 2, (pts[3][1] + pts[2][1]) / 2)
                self.gp.line(a, b, shade(c, 0.86), 0.5)
            self.gp.poly(pts, None, mix(edge, c, 0.45), 0.5)
        corners = [P(-w / 2, -h / 2), P(w / 2, -h / 2), P(w / 2, h / 2), P(-w / 2, h / 2)]
        self.gp.poly(corners, None, edge, 0.5)
        return corners

    def rows(self, cx, cy, w, h, angle=0.0, n=6, col=None, lw=1.2, soil=None, dashed=False):
        """Plant rows (vines, vegetables) over a soil block: n lines across the block's short side, on a soil patch.
        col: the row colour (default the season's vine colour); soil: the patch colour, or False for no patch.
        dashed=True breaks each row into plants 3 px apart (young vines, level 1)."""
        col = col or crop("vine", self.season)[0]
        if soil is not False:
            self.field(cx, cy, w, h, angle, [soil or crop("vine_soil", self.season)[0]], 1)
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))

        def P(u, v):
            return (cx + ca * u - sa * v, cy + (sa * u + ca * v) * TILT)
        for i in range(n):
            u = -w / 2 + w * (i + 0.5) / n
            a, b = P(u, -h / 2 + 1), P(u, h / 2 - 1)
            if not dashed:
                self.gp.line(a, b, col, lw)
            else:
                m = max(2, int(h // 3))
                for q in range(m):
                    t = (q + 0.5) / m
                    self.gp.dot(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, col, lw)

    def terrace(self, pts, face=0.0):
        """A dry-stone terrace wall along a line on the ground: a pale stone line with a dark foot below it.
        face > 0: the wall shows a front face that many px tall under the top line (a retaining wall seen from the
        front: olives, vineyards, any walled shelf)."""
        if face > 0:
            low = [(p[0], p[1] + face) for p in pts]
            self.gp.poly(list(pts) + low[::-1], STONE_D, None)
            self.gp.lines(low, shade(STONE_D, 0.72), 0.5)
            self.gp.lines(pts, (222, 212, 190) if not self.winter else SNOW, 1.0)
            return
        self.gp.lines([(p[0], p[1] + 0.8) for p in pts], shade(self.pal[self.ground_kind], 0.72), 1.0)
        self.gp.lines(pts, (222, 212, 190) if not self.winter else SNOW, 1.0)

    def scree(self, n=18, avoid=()):
        """Scree streaks and small stones for rock ground, which must never be flat grey."""
        rnd = random.Random(self.rnd.random())
        done = 0
        for _ in range(n * 6):
            if done >= n:
                break
            x, y = rnd.uniform(-46, 46), rnd.uniform(-44, 44)
            if not in_hex(x, y, 6) or any(math.hypot(x - a[0], (y - a[1]) / TILT) < a[2] for a in avoid):
                continue
            col = (198, 188, 168) if done % 2 else (128, 118, 104)
            if self.winter:
                col = SNOW if done % 2 else (150, 144, 138)
            ln = rnd.uniform(2.5, 4.5)
            self.gp.line((x, y), (x + ln * 0.35, y + ln * 0.8), col, 0.5)
            self.gp.line((x + 2, y), (x + 2 + ln * 0.3, y + ln * 0.65), col, 0.5)
            done += 1

    def jetty(self, a, b=None, w=2.2, stone=False, snow=False):
        """A timber jetty (or a stone quay or mole with stone=True) lying on the ground or water. Either from a to b,
        or along a list of points given as a (a bent mole). snow=True: a snow line on its top in winter."""
        if b is not None and not snow:
            self.gp.line(a, b, INK, w + 1.6)
            self.gp.line(a, b, STONE if stone else TIMBER, w)
            return
        pts = [a, b] if b is not None else list(a)
        col = STONE if stone else TIMBER
        for c, ww in ((INK, w + 1.6), (col, w)):
            self.gp.lines(pts, c, ww)
            for q in pts[1:-1]:                     # round the bends
                self.gp.ellipse(q[0], q[1], ww, ww, c)
        if snow and self.winter:
            self.gp.lines([(q[0], q[1] - w * 0.2) for q in pts], SNOW, max(0.5, w * 0.55))

    def hedge(self, pts, w=1.6):
        """A hedge along a line on the ground: a dark base line with a lighter top line."""
        self.gp.lines(pts, self.pal["hedge_d"], w)
        self.gp.lines([(p[0] - 0.3, p[1] - 0.6) for p in pts], self.pal["hedge"], w * 0.55)
        if self.winter:
            self.gp.lines([(p[0] - 0.3, p[1] - 0.9) for p in pts], SNOW, 0.5)

    def fence(self, pts, col=TIMBER_D):
        """A post-and-rail fence along a line: a thin rail with a post every 4 px."""
        self.gp.lines(pts, col, 0.5)
        for a, b in zip(pts, pts[1:]):
            d = math.dist(a, b)
            for i in range(int(d // 4) + 1):
                t = min(1.0, i * 4 / d) if d else 0
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                self.gp.line((x, y), (x, y - 1.6), col, 0.5)

    def road(self, pts, w=2.0, track=False):
        """A road on the ground. track=True: a thin farm track without an edge line. Snow-covered tracks stay visible."""
        col = ROAD if not self.winter else (214, 206, 190)
        if not track:
            self.gp.lines(pts, ROAD_EDGE, w + 1)
            self.gp.lines(pts, col, w)
        else:                                       # a track is worn ground: laid 75% over whatever is there
            self.over(lambda pen: pen.lines(pts, col, max(1.0, w * 0.6)), 0.75)

    def water(self, pts, w=3.0, frozen=None):
        """A stream or canal along a line. Freezes in winter unless frozen=False."""
        frozen = self.winter if frozen is None else frozen
        self.gp.lines(pts, self.pal["river_edge"] if not frozen else ICE_D, w + 1)
        self.gp.lines(pts, self.pal["river"] if not frozen else ICE, w)

    def pond(self, pts, frozen=None, ink=True, col=None, edge=None):
        """Still water as a shape (a pond, a salt pan uses patch() instead). Freezes in winter.
        col, edge: the open-water colours (default the river's); the frozen colours are always ICE."""
        frozen = self.winter if frozen is None else frozen
        col, edge = col or self.pal["river"], edge or self.pal["river_edge"]
        self.gp.poly(pts, col if not frozen else ICE, (edge if not frozen else ICE_D) if ink else None, 0.5)
        if frozen:
            a, b = pts[0], pts[len(pts) // 2]
            self.gp.line(((a[0] * 2 + b[0]) / 3, (a[1] * 2 + b[1]) / 3), ((a[0] + b[0] * 2) / 3, (a[1] + b[1] * 2) / 3), SNOW, 0.5)

    def coast(self, y0=10.0, amp=3.0, sand=4.0, seed=3):
        """The sea on the south side of the hex (the side facing the viewer), below a wavy shore line at about y0.
        Draws a sand strip, the sea, a light shallow band and a foam line. Returns shore(x) -> y of the water's edge.
        The sea never freezes."""
        rnd = random.Random(seed)
        ph = [rnd.uniform(0, 6.28) for _ in range(3)]

        def shore(x):
            return y0 + amp * (math.sin(x * 0.07 + ph[0]) * 0.6 + math.sin(x * 0.17 + ph[1]) * 0.3 + math.sin(x * 0.4 + ph[2]) * 0.1)
        xs = [x for x in range(-58, 60, 2)]
        line = [(x, shore(x)) for x in xs]
        if sand:
            self.gp.poly([(x, y - sand) for x, y in line] + [(58, 60), (-58, 60)], self.pal["sand"], None)
        self.gp.poly(line + [(58, 60), (-58, 60)], self.pal["shallow"], None)
        self.gp.poly([(x, y + 5) for x, y in line] + [(58, 60), (-58, 60)], self.pal["sea"], None)
        self.gp.lines(line, self.pal["foam"], 1)
        for wx, wy in ((-30, 12), (8, 20), (30, 9), (-8, 30)):       # little wave marks, as in the style frame
            y = shore(wx) + 8 + wy
            if in_hex(wx, y, 8):
                self.gp.lines([(wx - 3, y), (wx - 1.5, y - 0.8), (wx, y), (wx + 1.5, y - 0.8), (wx + 3, y)], mix(self.pal["sea"], self.pal["foam"], 0.45), 0.5)
        return shore

    def snow_patch(self, x, y, w, h):
        """A drift of snow on the ground (winter only; does nothing in other seasons)."""
        if self.winter:
            self.gp.ellipse(x, y, w, h, SNOW)

    # -------------------------------------------------------------- shadows
    def shadow(self, x, y, w, h):
        """A soft ground shadow: an ellipse centred on (x, y). Standing primitives add their own."""
        r = pygame.Rect(0, 0, max(1, int(w * SS)), max(1, int(h * SS)))
        r.center = Pen.T((x, y))
        pygame.draw.ellipse(self.sh, SHADOW, r)

    def cast(self, x, y, w, h=None):
        """The usual shadow of a standing thing whose foot is w wide: lower right of the foot."""
        self.shadow(x + w * 0.35, y + 0.6, w * 1.5, h or max(2.0, w * 0.5))

    # -------------------------------------------------------------- standing things
    def stand(self, y, fn, lift=0.0):
        """Queue fn(pen) to be drawn at depth y (the y of the thing's foot). Use for a family's own landmarks.
        lift: draw it that many px later in the order than its foot says (smoke: it must lie over its chimney)."""
        self.queue.append((y + lift, self.n, fn))
        self.foot[self.n] = y
        self.n += 1

    def layers(self):
        """The piece taken apart for the map (see take_apart()):
        'ground'   the ground-plane layer at 2x (with base=False: only the detail, transparent elsewhere), not yet
                   feathered at the hex border;
        'shadow'   the 2x shadow layer (white = none; blend it with SHADOW_ALPHA);
        'standing' the standing things, back to front: (foot_y, order_y, fn), fn(pen) draws one of them."""
        st = [(self.foot[q[1]], q[0], q[2]) for q in sorted(self.queue, key=lambda q: (q[0], q[1]))]
        return {"ground": self.g, "shadow": self.sh, "standing": st}

    def tree(self, x, y, sc=1.0, kind="round", i=0):
        """A tree with its foot at (x, y). kind: 'round' (broadleaf), 'conifer', 'poplar' (tall, thin), 'bush',
        'olive' (silver green, evergreen), 'fruit' (small, blossom in spring). i: the tree's index (autumn colour mix)."""
        season, pal, winter = self.season, self.pal, self.winter
        self.cast(x, y, {"conifer": 4.5, "poplar": 3.5, "bush": 4.0}.get(kind, 5.5) * sc)

        def fn(p):
            if kind == "conifer":
                oc, lit, dk = pal["conifer"]
                h, w = 12.5 * sc, 7.2 * sc
                p.line((x, y), (x, y - 2.5 * sc), TRUNK, 1.3 * sc)
                pts = [(x, y - h), (x + w / 2, y - 2 * sc), (x - w / 2, y - 2 * sc)]
                p.poly(pts, lit, None)
                p.poly([(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)], dk, None)
                if winter:      # snow lies on the lit (left) side
                    p.poly([(x, y - h), (x - w * 0.5, y - 2 * sc), (x - w * 0.16, y - 2 * sc), (x - w * 0.02, y - h * 0.5)], SNOW, None)
                p.poly(pts, None, oc, 0.5)
                return
            if kind == "poplar":
                oc, dk, mid, lt = pal["leaf"] if season != "autumn" else LEAF_AUTUMN[1]
                h, w = 15 * sc, 4.2 * sc
                p.line((x, y), (x, y - 3 * sc), TRUNK, 1.0 * sc)
                if winter:
                    for q in (-1, 0, 1):
                        p.line((x, y - 3 * sc), (x + q * 1.4 * sc, y - h), TRUNK, 0.5)
                    return
                p.ellipse(x, y - 2 * sc - h * 0.45, w + 1, h * 0.9 + 1, oc)
                p.ellipse(x, y - 2 * sc - h * 0.45, w, h * 0.9, dk)
                p.ellipse(x - w * 0.16, y - 2 * sc - h * 0.5, w * 0.56, h * 0.7, mid)
                return
            if kind == "olive":
                r = 3.4 * sc
                cy = y - 2.2 * sc - r * 0.6
                p.line((x, y), (x + 0.5, y - 2.4 * sc), (104, 88, 70), 1.2 * sc)
                p.ellipse(x, cy, r * 2 + 1, r * 1.5 + 1, (62, 78, 62))
                p.ellipse(x, cy, r * 2, r * 1.5, (122, 142, 104))
                p.ellipse(x - r * 0.3, cy - r * 0.22, r * 1.2, r * 0.8, (168, 182, 142) if not winter else SNOW)
                return
            r = {"round": 4.4, "bush": 2.6, "fruit": 3.2}[kind] * sc
            th = {"round": 3.0, "bush": 0.6, "fruit": 2.4}[kind] * sc
            cy = y - th - r * 0.75
            if kind != "bush":
                p.line((x, y), (x, y - th - (r * 0.4 if not winter else 0)), TRUNK, 1.4 * sc)
            if winter:          # bare twigs with a dab of snow; a bush is a snow mound with twigs
                if kind == "bush":
                    p.ellipse(x, y - r * 0.6, r * 2, r * 1.3, SNOW_D)
                    p.ellipse(x - r * 0.2, y - r * 0.75, r * 1.5, r * 0.9, SNOW)
                    return
                for dx, dy in ((-0.9, -0.5), (-0.45, -1.0), (0.1, -1.15), (0.6, -0.95), (0.95, -0.45)):
                    p.line((x, y - th), (x + dx * r, y - th + dy * r * 1.25), pal["leaf"][0], 0.8)
                p.line((x - r * 0.7, y - th - r * 0.75), (x - r * 0.1, y - th - r * 1.3), SNOW, 0.5)
                return
            oc, dk, mid, lt = pal["leaf"] if season != "autumn" else LEAF_AUTUMN[i % 3]
            p.circle(x, cy, r + 0.5, oc)
            p.circle(x, cy, r, dk)
            p.circle(x - r * 0.28, cy - r * 0.28, r * 0.66, mid)
            p.circle(x - r * 0.45, cy - r * 0.45, r * 0.26, lt)
            if kind == "fruit" and pal["blossom"]:
                for dx, dy in ((-0.5, -0.3), (0.3, -0.5), (0.1, 0.3), (-0.2, 0.5), (0.55, 0.15)):
                    p.dot(x + dx * r, cy + dy * r, pal["blossom"], 1.0)
        self.stand(y, fn)

    def house(self, x, y, w=7.0, h=4.6, roof_h=3.6, wall=0, kind="ridge", roof="tile", door=True, smoke=False):
        """A house with the middle of its foot at (x, y). kind: 'ridge' (roof slope faces the viewer) or 'gable'
        (gable to the front). roof: 'tile', 'thatch' or 'slate'. wall: an index into PLASTER, or a colour.
        Winter puts snow on the roof. smoke=True adds chimney smoke in autumn and winter only."""
        wallc = PLASTER[wall % len(PLASTER)] if isinstance(wall, int) else wall
        r1, r2 = {"tile": (ROOF, ROOF_D), "thatch": (THATCH, THATCH_D), "slate": (SLATE, SLATE_D)}[roof]
        eave_l = r1
        if self.winter:
            r1, r2 = SNOW, SNOW_D
        self.cast(x, y, w)
        smoky = smoke and self.season in ("autumn", "winter")

        def fn(p):
            x0, top = x - w / 2, y - h
            if kind == "ridge":
                p.rect(x0, top, w, h, wallc, None)
                p.rect(x0 + w * 0.78, top, w * 0.22, h, shade(wallc, 0.84), None)
                rf = [(x0 - 1, top + 0.3), (x0 + w + 1, top + 0.3), (x0 + w - 0.6, top - roof_h), (x0 + 0.6, top - roof_h)]
                p.poly(rf, r1, None)
                p.poly([rf[1], rf[2], (x0 + w * 0.72, top - roof_h), (x0 + w * 0.78, top + 0.3)], r2, None)
                if self.winter:                 # the eave keeps the roof colour: a 1 px band, so roofs stay roofs
                    p.poly([rf[0], rf[1], (rf[1][0] - 0.3, rf[1][1] - 1.1), (rf[0][0] + 0.3, rf[0][1] - 1.1)], eave_l, None)
                p.poly(rf, None, INK, 0.5)
            else:
                p.rect(x0, top, w, h, wallc, None)
                p.poly([(x0, top), (x0 + w / 2, top - roof_h), (x0 + w, top)], wallc, None)
                slope = [(x0 + w / 2, top - roof_h), (x0 + w / 2 + 2.6, top - roof_h - 2.2), (x0 + w + 2.8, top - 2.2), (x0 + w + 0.6, top + 0.4)]
                p.poly(slope, r2, INK, 0.5)
                if self.winter:
                    p.line((slope[3][0] + 0.2, slope[3][1] - 0.5), (slope[2][0] - 0.2, slope[2][1] - 0.5), eave_l, 1.0)
                p.line((x0 - 0.6, top + 0.4), (x0 + w / 2, top - roof_h), r1, 1.4)
                p.line((x0, top), (x0 + w / 2, top - roof_h), INK, 0.5)
            if door:
                p.rect(x0 + w * 0.4, y - 2.2, 1.4, 2.2, DOOR, None)
            p.rect(x0, top, w, h, None, INK, 0.5)
            if smoky:
                _smoke(p, x + w * 0.2, top - roof_h - 0.5, self.winter)
        self.stand(y, fn)

    def smoke(self, x, y, always=False, foot=None):
        """Chimney smoke rising from (x, y). Autumn and winter only, unless always=True (the listed chimneys: the
        smelter, the charcoal mound). Grey in winter so it shows on snow. foot: the foot y of the thing that smokes."""
        if always or self.season in ("autumn", "winter"):
            fy = y if foot is None else foot
            self.stand(fy, lambda p: _smoke(p, x, y, self.winter), lift=y + 30 - fy)

    def church(self, x, y, size="church", sc=1.0):
        """size: 'chapel' (village), 'church' (town), 'cathedral' (city: a dome and a tall bell tower).
        (x, y) is the middle of the nave's foot; the tower stands to the right. sc scales the whole building."""
        big = size != "chapel"
        w, hw = ((9, 6) if big else (6, 4.5))
        w, hw = w * sc, hw * sc
        th = {"chapel": 8, "church": 13, "cathedral": 17}[size] * sc
        r1, r2 = (ROOF, ROOF_D) if not self.winter else (SNOW, SNOW_D)
        self.cast(x + 2, y, w + 5 * sc)

        def fn(p):
            rh = 3.5 * sc
            p.rect(x - w / 2, y - hw, w, hw, CHURCH, None)
            p.rect(x + w * 0.28, y - hw, w * 0.22, hw, shade(CHURCH, 0.86), None)
            rf = [(x - w / 2 - 0.5, y - hw), (x + w / 2 + 0.5, y - hw), (x + w / 2 - 0.5, y - hw - rh), (x - w / 2 + 0.5, y - hw - rh)]
            p.poly(rf, r1, INK, 0.5)
            if self.winter:
                p.poly([rf[0], rf[1], (rf[1][0] - 0.3, rf[1][1] - 1.1), (rf[0][0] + 0.3, rf[0][1] - 1.1)], ROOF, None)
                p.poly(rf, None, INK, 0.5)
            p.rect(x - w / 2, y - hw, w, hw, None, INK, 0.5)
            p.rect(x - 0.8 * sc, y - 2.6 * sc, 1.6 * sc, 2.6 * sc, DOOR, None)
            if size == "cathedral":
                cx, cy = x, y - hw - rh
                dr = 4.2 * sc                                   # the dome on its drum
                p.ellipse(cx, cy - 3 * sc, dr * 2 + 1, dr * 2 + 1, INK)
                p.ellipse(cx, cy - 3 * sc, dr * 2, dr * 2, DOME if not self.winter else SNOW_D)
                p.ellipse(cx - dr * 0.25, cy - 3 * sc - dr * 0.25, dr * 1.2, dr * 1.2, DOME_L if not self.winter else SNOW)
                p.rect(cx - 3.6 * sc, cy - 3 * sc, 7.2 * sc, 3 * sc, CHURCH, INK, 0.5)
                p.line((cx, cy - 3 * sc - dr), (cx, cy - 3 * sc - dr - 2.2 * sc), INK, 0.5)
            tx = x + w / 2 + 1.5 * sc
            tw = 4 * sc
            p.rect(tx - tw / 2, y - th, tw, th, CHURCH, None)
            p.rect(tx + tw * 0.15, y - th, tw * 0.35, th, shade(CHURCH, 0.85), None)
            cap = [(tx - tw / 2 - 0.6, y - th), (tx + tw / 2 + 0.6, y - th), (tx, y - th - 4 * sc)]
            p.poly(cap, ROOF_D if not self.winter else SNOW_D, INK, 0.5)
            p.rect(tx - tw / 2, y - th, tw, th, None, INK, 0.5)
            p.rect(tx - 0.5 * sc, y - th + 1.5 * sc, 1 * sc, 1.8 * sc, DOOR, None)
        self.stand(y, fn)

    def tower(self, x, y, w=4.2, h=9.0, col=STONE, top="battlement", flag=None, roof=SLATE):
        """A tower with the middle of its foot at (x, y). top: 'battlement', 'cone' (a pointed roof) or 'flat'.
        flag: a colour for a small banner, or None."""
        self.cast(x, y, w + 1)

        def fn(p):
            p.box(x, y, w, h, col, None)
            if top == "battlement":
                p.rect(x - w / 2 - 0.5, y - h - 1.4, w + 1, 1.6, col, INK, 0.5)
                for q in (-1, 0, 1):
                    p.rect(x + q * (w / 2) - 0.5, y - h - 2.4, 1.0, 1.0, col if not self.winter else SNOW, None)
            elif top == "cone":
                rc = roof if not self.winter else SNOW_D
                p.poly([(x - w / 2 - 0.6, y - h), (x + w / 2 + 0.6, y - h), (x, y - h - w * 0.95)], rc, INK, 0.5)
                if self.winter:
                    p.poly([(x - w / 2 - 0.6, y - h), (x, y - h), (x, y - h - w * 0.95)], SNOW, None)
            p.rect(x - w / 2, y - h, w, h, None, INK, 0.5)
            if h >= 8:
                p.rect(x - 0.4, y - h * 0.62, 0.8, 1.6, DOOR, None)
            if flag:
                ty = y - h - (2.4 if top == "battlement" else w * 0.95 if top == "cone" else 0)
                p.line((x, ty), (x, ty - 4.5), INK, 0.5)
                p.poly([(x, ty - 4.5), (x + 3.2, ty - 3.6), (x, ty - 2.6)], flag, None)
        self.stand(y, fn)

    def wall(self, cx, cy, rx, ry, kind="stone", towers=(0.25, 0.5, 0.75), gate=0.5, back_towers=(), height=4.0, col=None):
        """A ring wall round (cx, cy). kind: 'palisade' (timber stakes, no towers unless asked) or 'stone'
        (battlements). towers and gate are positions along the front half, 0 = right end, 1 = left end
        (0.5 = the middle of the front). The back half is queued behind everything inside, the front half before it."""
        col = col or (STONE if kind == "stone" else TIMBER)       # col=STONE_GREY for castles
        back = ring_points(cx, cy, rx, ry, math.pi, 2 * math.pi)
        front = ring_points(cx, cy, rx, ry, 0, math.pi)
        hw = height
        self.shadow(cx + rx * 0.2, cy + ry * 0.35, rx * 2.3, ry * 2.0)

        def stakes(p, pts, c):
            for q in range(0, len(pts), 1):
                a = pts[q]
                p.line((a[0], a[1] - hw + 0.4), (a[0], a[1] - hw - 0.9), c, 0.5)

        def fb(p):
            top = [(a[0], a[1] - hw) for a in back]
            p.poly(back + top[::-1], shade(col, 0.82), None)
            if kind == "palisade":
                stakes(p, back, shade(col, 0.7))
            p.lines(top, INK if kind == "stone" else TIMBER_D, 0.5)
            for a in back_towers:
                q = back[int(len(back) * a)]
                p.box(q[0], q[1], 3.6, hw + 3, shade(col, 0.9), INK)

        def ff(p):
            top = [(a[0], a[1] - hw) for a in front]
            p.poly(front + top[::-1], col, None)
            if kind == "stone":
                for q in range(0, len(front), 3):
                    a = top[q]
                    p.rect(a[0] - 0.8, a[1] - 1.4, 1.6, 1.5, col if not self.winter else SNOW, None)
            else:
                stakes(p, front, TIMBER_D)
                for q in range(2, len(front), 4):
                    a = front[q]
                    p.line((a[0], a[1] - hw + 0.8), (a[0], a[1] - 0.4), TIMBER_D, 0.5)
            p.lines(top, INK, 0.5)
            p.lines(front, INK, 0.5)
            for a in towers:
                q = front[int((len(front) - 1) * a)]
                tw, th = 4.2, hw + 3.5
                p.box(q[0], q[1], tw, th, col, INK)
                if self.winter:
                    p.rect(q[0] - tw / 2, q[1] - th - 0.6, tw, 1.0, SNOW, None)
            if gate is not None:
                q = front[int((len(front) - 1) * gate)]
                p.rect(q[0] - 1.6, q[1] - 3.0, 3.2, 3.0, DOOR, None)
                if kind == "palisade":
                    p.rect(q[0] - 2.4, q[1] - hw - 1.6, 4.8, 1.2, TIMBER_D, None)
        self.stand(cy - ry - 0.5, fb)
        self.stand(cy + ry + 0.5, ff)

    def boat(self, x, y, sc=1.0, sail=True):
        """A ship or fishing boat with its keel at (x, y). sc 1.0 = a trading ship (12 px long); 0.55 = a fishing
        boat. sail=False: a bare mast (boats laid up in winter)."""
        def fn(p):
            k = sc
            hull = [(x - 6 * k, y - 3 * k), (x + 6 * k, y - 3 * k), (x + 4 * k, y), (x - 4 * k, y)]
            p.poly(hull, HULL, INK, 0.5)
            p.line((x, y - 3 * k), (x, y - 13 * k), INK, 0.5)
            if sail:
                sl = [(x - 4.2 * k, y - 11.5 * k), (x + 4.2 * k, y - 11.5 * k), (x + 3.6 * k, y - 5 * k), (x - 3.6 * k, y - 5 * k)]
                p.poly(sl, SAIL, None)
                p.poly([(x + 0.5 * k, y - 11.5 * k), sl[1], sl[2], (x + 0.5 * k, y - 5 * k)], SAIL_D, None)
                p.poly(sl, None, INK, 0.5)
            p.line((x - 7 * k, y + 0.5), (x - 3 * k, y + 0.5), (240, 244, 248), 0.5)
        self.stand(y, fn)

    def person(self, x, y, col=(196, 72, 60)):
        """A person as a dot: 1 px wide, 3 px tall (a dark head on a coloured body)."""
        def fn(p):
            p.rect(x - 0.6, y - 2.4, 1.2, 2.4, col, None)
            p.rect(x - 0.6, y - 3.4, 1.2, 1.1, INK, None)
        self.stand(y, fn)

    def animal(self, x, y, kind="sheep", flip=False, sc=1.0, col=None):
        """An animal as a blob: 'sheep' (white, 3x2), 'cow' (brown and white, 4x2.5), 'horse' (dark, 4x3 on legs).
        sc: 0.7 for a young one. col: another coat colour."""
        d = -1 if flip else 1
        if sc != 1.0 or col is not None:
            def fy(p):
                body = col or {"sheep": (244, 240, 230), "cow": (150, 92, 60), "horse": (96, 66, 50)}[kind]
                if kind == "horse":
                    p.line((x - 1.2 * sc, y), (x - 1.2 * sc, y - 1.6 * sc), INK, 0.5)
                    p.line((x + 1.2 * sc, y), (x + 1.2 * sc, y - 1.6 * sc), INK, 0.5)
                    p.ellipse(x, y - 2.4 * sc, 4.4 * sc, 2.2 * sc, body, INK, 0.5)
                    p.line((x + 1.8 * d * sc, y - 2.8 * sc), (x + 2.6 * d * sc, y - 4.4 * sc), body, 1.0)
                else:
                    w, h = ((3.2, 2.2) if kind == "sheep" else (4.4, 2.6))
                    p.ellipse(x, y - h * sc * 0.58, w * sc, h * sc, body, (120, 110, 100) if kind == "sheep" else INK, 0.5)
                    p.dot(x + w * 0.48 * d * sc, y - h * sc * 0.75, INK if kind == "sheep" else shade(body, 0.72), 1.0)
            self.stand(y, fy)
            return

        def fn(p):
            if kind == "sheep":
                p.ellipse(x, y - 1.2, 3.2, 2.2, (244, 240, 230) if not self.winter else (226, 218, 200), (120, 110, 100), 0.5)
                p.dot(x + 1.5 * d, y - 1.5, INK, 1.0)
            elif kind == "cow":
                p.ellipse(x, y - 1.6, 4.4, 2.6, (150, 92, 60), INK, 0.5)
                p.dot(x - 0.6 * d, y - 1.8, (240, 232, 220), 1.2)
                p.dot(x + 2.2 * d, y - 2.2, (110, 66, 44), 1.4)
            else:
                p.line((x - 1.2, y), (x - 1.2, y - 1.6), INK, 0.5)
                p.line((x + 1.2, y), (x + 1.2, y - 1.6), INK, 0.5)
                p.ellipse(x, y - 2.4, 4.4, 2.2, (96, 66, 50), INK, 0.5)
                p.line((x + 1.8 * d, y - 2.8), (x + 2.6 * d, y - 4.4), (96, 66, 50), 1.0)
        self.stand(y, fn)

    def haystack(self, x, y, sc=1.0):
        """A round haystack (a snow-capped mound in winter)."""
        self.cast(x, y, 4 * sc)

        def fn(p):
            w, h = 4.6 * sc, 4.6 * sc
            pts = [(x - w / 2, y), (x - w / 2, y - h * 0.45), (x, y - h), (x + w / 2, y - h * 0.45), (x + w / 2, y)]
            p.poly(pts, (226, 196, 110), None)
            p.poly([(x + w * 0.12, y), (x + w * 0.08, y - h * 0.9), (x + w / 2, y - h * 0.45), (x + w / 2, y)], (190, 158, 86), None)
            if self.winter:
                p.poly([(x - w / 2, y - h * 0.45), (x, y - h), (x + w / 2, y - h * 0.45), (x, y - h * 0.62)], SNOW, None)
            p.poly(pts, None, (110, 84, 50), 0.5)
        self.stand(y, fn)

    def heap(self, x, y, w, h, col, col_d=None, ink=INK):
        """A cone-shaped heap (salt, spoil, grain, charcoal): two-tone, lit from the left. Snow-capped in winter."""
        col_d = col_d or shade(col, 0.8)
        self.cast(x, y, w * 0.8)

        def fn(p):
            pts = [(x - w / 2, y), (x - w * 0.12, y - h), (x + w * 0.12, y - h), (x + w / 2, y)]
            p.poly(pts, col, None)
            p.poly([(x + w * 0.02, y - h), (x + w * 0.12, y - h), (x + w / 2, y), (x + w * 0.1, y)], col_d, None)
            if self.winter:
                p.poly([(x - w * 0.3, y - h * 0.55), (x - w * 0.12, y - h), (x + w * 0.12, y - h), (x + w * 0.28, y - h * 0.6), (x, y - h * 0.72)], SNOW, None)
            p.poly(pts, None, ink, 0.5)
        self.stand(y, fn)

    def logs(self, x, y, n=3, w=7.0):
        """A pile of n logs lying across, seen from the side with their cut ends to the right."""
        self.cast(x, y, w)

        def fn(p):
            for i in range(n):
                yy = y - i * 1.5
                ww = w - i * 1.2
                p.rect(x - ww / 2, yy - 1.6, ww, 1.6, TIMBER if not (self.winter and i == n - 1) else SNOW, INK, 0.5)
                p.dot(x + ww / 2 - 0.6, yy - 0.8, (226, 196, 140), 1.0)
        self.stand(y, fn)

    # -------------------------------------------------------------- output
    def finish(self, check=True, label=""):
        """Compose the piece: ground (faded at the hex border), shadows, then standing things back to front.
        Returns a SIZE x SIZE surface with alpha. With check=True, prints a line if a standing thing leaves the hex."""
        global LAST
        LAST = self
        for q in sorted(self.queue, key=lambda q: (q[0], q[1])):
            q[2](self.op)
        mask = _hex_mask()
        ground = self.g.copy()
        sh = pygame.Surface(self.g.get_size(), pygame.SRCALPHA)
        self.sh.set_alpha(SHADOW_ALPHA)
        sh.blit(self.sh, (0, 0))
        ground.blit(sh, (0, 0))
        ground.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
        ground.blit(self.o, (0, 0))
        out = pygame.transform.smoothscale(ground, (SIZE, SIZE))
        if check:
            bad = overhang(self.o)
            if bad:
                print("PIECE PROBLEM %s %s: %d px of standing art outside the hex margin" % (label, self.season, bad))
        return out


def _smoke(p, x, y, winter=False):
    for i, (dx, dy, r) in enumerate(((0.0, -1.5, 1.0), (0.8, -3.6, 1.3), (2.0, -5.8, 1.6))):
        p.circle(x + dx, y + dy, r, SMOKE_SNOW if winter else SMOKE)


def take_apart(draw, level, season, **kw):
    """Draw one piece for the map: without its ground base, and returned as layers (see Piece.layers()), so the map
    can lay the ground detail on its own ground and sort every standing thing into its own back-to-front list.
    Works with every family module as it is: take_apart(wheat.draw, 2, "summer")."""
    global NO_BASE
    NO_BASE = True
    try:
        draw(level, season, **kw)
    finally:
        NO_BASE = False
    return LAST.layers()


_MASK = None


def _hex_mask():
    """White inside the hex, alpha fading to 0 over FEATHER px at the border (2x surface)."""
    global _MASK
    if _MASK is None:
        m = pygame.Surface((SIZE * SS, SIZE * SS), pygame.SRCALPHA)
        m.fill((255, 255, 255, 0))
        n = FEATHER * SS
        for i in range(n + 1):
            pts = [Pen.T(p) for p in hex_points(i / SS)]
            pygame.draw.polygon(m, (255, 255, 255, int(255 * i / n)), pts)
        _MASK = m
    return _MASK


def overhang(obj_layer):
    """The number of 1x pixels of standing art that lie outside the hex pulled in by MARGIN. 0 = the piece fits."""
    small = pygame.transform.scale(obj_layer, (SIZE, SIZE))
    allowed = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)
    pygame.draw.polygon(allowed, (255, 255, 255, 255), [(p[0] + C, p[1] + C) for p in hex_points(MARGIN)])
    am = pygame.mask.from_surface(allowed, 127)
    om = pygame.mask.from_surface(small, 60)
    am.invert()
    return om.overlap_area(am, (0, 0))


# ------------------------------------------------------------------ sheets
SHEET_BG = (26, 30, 44)
SHEET_TEXT = (226, 226, 220)
SHEET_DIM = (150, 156, 170)


def _font(size, bold=False):
    f = pygame.font.Font(None, size)
    f.set_bold(bold)
    return f


def backdrop(season, w, h, ground="grass"):
    """A patch of plain season ground to show pieces on, so the blend at the hex border can be judged."""
    s = pygame.Surface((w, h))
    s.fill(PAL[season][ground])
    return s


def _cell(piece, season, scale=1.0, pad=6, ground="grass"):
    w = int((SIZE + pad * 2) * scale)
    s = backdrop(season, w, w, ground)
    img = piece if scale == 1.0 else pygame.transform.smoothscale(piece, (int(SIZE * scale), int(SIZE * scale)))
    s.blit(img, (int(pad * scale), int(pad * scale)))
    lay = pygame.Surface((w, w), pygame.SRCALPHA)
    pts = [((p[0] + C + pad) * scale, (p[1] + C + pad) * scale) for p in hex_points()]
    pygame.draw.lines(lay, (30, 40, 30, 40), True, pts, 1)
    s.blit(lay, (0, 0))
    return s


def sheet(draw, levels, title, path, level_names=None, ground="grass", row_season="summer"):
    """Lay a family out as a labelled grid and save it as a PNG.

    draw(level, season) -> Surface (SIZE x SIZE);  levels: e.g. range(0, 4);  level_names: {level: "name"}.
    Left: rows = levels, columns = seasons, at 100%. Right: the same grid at 50% (the small-size test).
    Bottom: every level of `row_season` side by side as touching hexes (the seam and progression test).
    Returns the dict {(level, season): Surface}."""
    levels = list(levels)
    level_names = level_names or {}
    pieces = {(lv, se): draw(lv, se) for lv in levels for se in SEASONS}
    for k, s in pieces.items():
        assert s.get_size() == (SIZE, SIZE), "draw%r must return a %dx%d surface" % (k, SIZE, SIZE)
    pad, gap, left, top = 6, 6, 118, 64
    cw = SIZE + pad * 2
    hw = cw // 2
    gw = len(SEASONS) * (cw + gap)
    gh = len(levels) * (cw + gap)
    x50 = left + gw + 30
    row_w = int(len(levels) * HEX_W + 40)
    W = max(x50 + len(SEASONS) * (hw + 4) + 20, left + row_w + 20)
    H = top + gh + 40 + 150
    out = pygame.Surface((W, H))
    out.fill(SHEET_BG)
    f_t, f_h, f_s = _font(30, True), _font(22), _font(18)
    out.blit(f_t.render(title, True, SHEET_TEXT), (16, 12))
    out.blit(f_s.render("100%  (hex radius 60)", True, SHEET_DIM), (left, 44))
    out.blit(f_s.render("50% test", True, SHEET_DIM), (x50, 44))
    for j, se in enumerate(SEASONS):
        out.blit(f_h.render(se, True, SHEET_TEXT), (left + j * (cw + gap) + 4, top - 2 + gh))
        out.blit(f_s.render(se, True, SHEET_DIM), (x50 + j * (hw + 4), top - 2 + len(levels) * (hw + 4)))
    for i, lv in enumerate(levels):
        y = top + i * (cw + gap)
        out.blit(f_h.render("Level %d" % lv, True, SHEET_TEXT), (14, y + 40))
        if lv in level_names:
            out.blit(f_s.render(level_names[lv], True, SHEET_DIM), (14, y + 62))
        for j, se in enumerate(SEASONS):
            out.blit(_cell(pieces[(lv, se)], se, 1.0, pad, ground), (left + j * (cw + gap), y))
            out.blit(_cell(pieces[(lv, se)], se, 0.5, pad, ground), (x50 + j * (hw + 4), top + i * (hw + 4)))
    # the row of touching hexes
    ry = top + gh + 34
    out.blit(f_s.render("Side by side, %s (touching hexes: seams and progression)" % row_season, True, SHEET_DIM), (left, ry - 6))
    strip = backdrop(row_season, row_w, 124, ground)
    for i, lv in enumerate(levels):
        strip.blit(pieces[(lv, row_season)], (int(20 + i * HEX_W - (SIZE - HEX_W) / 2), 6))
    out.blit(strip, (left, ry + 14))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    pygame.image.save(out, path)
    return pieces
