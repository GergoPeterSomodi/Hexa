"""Pieces in the map: the style frame (close zoom, hex radius 60) with chosen hexes drawn by normal-map pieces.

A test, not game code. It answers one question: do the pieces of tools/worldmap/pieces (one hex, one level, one
season) sit in the real map, or do they look like stickers?

What the compositor does (the frame and the pieces are used read only; no file of either is changed):
  - A hex that takes a piece loses the frame's own town, field parcels, trees and rounded hills, so nothing doubles.
    Ranges, rivers, roads, coasts and names stay: they are other layers.
  - The piece's ground base is dropped: the frame paints the ground. Only the piece's ground detail (fields, plots,
    yards, tracks, tufts) is kept, feathered at the hex border, clipped to the land, and laid on the frame's ground
    before the rivers and roads.
  - The piece's soft shadows go into the frame's one shadow pass.
  - Every standing thing of a piece is taken out of the piece's queue one by one and put into the frame's own
    back-to-front list by the y of its foot, so a piece's houses and a neighbour's trees and hills cover each other
    correctly.
  - A town's site moves to the middle of its piece, the roads are led there, and the name plate goes on the strip
    the settlement pieces keep free (26 px below the hex centre).
  - Winter: the frame has no winter of its own, so a stand-in is made here (snow ground from the pieces' palette,
    bare broadleaves, snow on conifers and hills). It is a stand-in, not a design.

Run (the frame's environment: STYLE_FRAME_LAYERS must name the exported layers file):
    python tools/worldmap/pieces_in_map/compose.py [OUT_DIR] [summer|winter|both] [--ab]
Writes summer.png, winter.png, plain_crop.png (and base_ab.png with --ab) and prints the measurements.
"""
import contextlib
import os
os.environ.setdefault("STYLE_FRAME_SLOPES", "0")     # as the checked-in style_frame_close.png was drawn
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "style_frame"))
sys.path.insert(0, os.path.join(HERE, "..", "pieces"))

import render as R          # the style frame (builds the world at import)
import kit                  # the pieces kit
import settlements
import wheat

pygame = R.pygame
WORLD, FIELDS = R.WORLD, R.FIELDS

# ---------------------------------------------------------------- what goes where
TOWN_LEVEL = {
    "Genoa": 5, "Turin": 5, "Pavia": 5, "Pisa": 4, "Alessandria": 4, "Piacenza": 4, "Asti": 3, "Parma": 3,
    "Savona": 3, "Nice": 3, "Cuneo": 3, "Susa": 2, "Chiavari": 2, "Serravalle": 1,
}
# Wheat on the Po plain: (column, row) -> level. Chosen from the farmland hexes in view (see --probe).
WHEAT = {(7, 9): 2, (8, 9): 3, (10, 9): 3, (11, 9): 1, (12, 9): 2, (6, 10): 2, (6, 11): 1, (7, 11): 1, (12, 12): 2}
SITE_DY = -6.0              # the middle of a settlement piece lies 6 px above the hex centre (CY + 1 in settlements.py)
PLATE_DY = 26.0             # the settlement pieces keep the strip from here down free for the name plate
SS, SIZE, C = kit.SS, kit.SIZE, kit.C


# ---------------------------------------------------------------- taking a piece apart
BasePiece = kit.Piece


class LayeredPiece(BasePiece):
    """kit.Piece that keeps its layers: no ground base (the map paints the ground), and the queue of standing things
    is kept so each one can join the map's back-to-front order."""
    last = None
    keep_base = False

    def base(self, kind, texture=True):
        if LayeredPiece.keep_base:
            return BasePiece.base(self, kind, texture)
        if texture:
            self.rnd.random()       # the kit draws one number here: keep the sequence, so tufts stand where they did

    def finish(self, check=True, label=""):
        LayeredPiece.last = self
        return None


_MASK = None


def feather_mask():
    """The kit's hex feather as a premultiplied multiplier (2x)."""
    global _MASK
    if _MASK is None:
        m = pygame.Surface((SIZE * SS, SIZE * SS), pygame.SRCALPHA)
        n = kit.FEATHER * SS
        for i in range(n + 1):
            a = int(255 * i / n)
            pygame.draw.polygon(m, (a, a, a, a), [kit.Pen.T(p) for p in kit.hex_points(i / SS)])
        _MASK = m
    return _MASK


def take_apart(draw, level, season, keep_base=False):
    """Returns (ground, shadow, things): the ground detail (112x112, premultiplied alpha), the shadow layer (2x, white
    = none) and the standing things as (foot_y, order, image, rect) with premultiplied images cut to their boxes."""
    kit.Piece = LayeredPiece
    LayeredPiece.keep_base = keep_base
    try:
        draw(level, season)
    finally:
        kit.Piece = BasePiece
    p = LayeredPiece.last
    g = p.g.copy()                                   # drawn pixels are opaque, the rest is (0, 0, 0, 0): premultiplied
    g.blit(feather_mask(), (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
    ground = pygame.transform.smoothscale(g, (SIZE, SIZE))
    things = []
    for y, n, fn in sorted(p.queue, key=lambda q: (q[0], q[1])):
        lay = pygame.Surface((SIZE * SS, SIZE * SS), pygame.SRCALPHA)
        fn(kit.Pen(lay))
        small = pygame.transform.smoothscale(lay, (SIZE, SIZE))
        box = small.get_bounding_rect()
        if box.width:
            things.append((y, n, small.subsurface(box).copy(), box))
    return ground, p.sh, things


# ---------------------------------------------------------------- winter stand-in for the frame
def snowy(col):
    """A green of the frame's hills and ranges as snow of the same lightness."""
    r, g, b = col[0], col[1], col[2]
    if not (g > r + 10 and g > b + 25):
        return col
    t = max(0.0, min(1.0, ((r + g + b) / 3.0 - 45) / 95.0))
    return kit.mix((96, 104, 124), (240, 243, 248), t) + tuple(col[3:])


@contextlib.contextmanager
def snow_draw():
    """While open, the frame's green drawing comes out as snow (for its hills and wooded ranges)."""
    d = pygame.draw
    old = {n: getattr(d, n) for n in ("polygon", "circle", "lines", "line", "ellipse")}

    def wrap(fn):
        return lambda surf, col, *a, **k: fn(surf, snowy(col), *a, **k)
    for n, fn in old.items():
        setattr(d, n, wrap(fn))
    try:
        yield
    finally:
        for n, fn in old.items():
            setattr(d, n, fn)


SUMMER_COLS = {n: getattr(R, n) for n in ("C_FARM", "C_GRASS", "C_WOOD", "C_ROCK", "C_SAND", "C_SEA", "C_SHELF", "C_DEEP",
                                          "C_RIVER", "C_RIVER_EDGE")}


def season_cols(season):
    pal = kit.PAL[season]
    cols = dict(SUMMER_COLS)
    if season == "winter":
        cols.update(C_FARM=pal["farm"], C_GRASS=pal["grass"], C_WOOD=pal["wood"], C_ROCK=pal["rock"], C_SAND=pal["sand"],
                    C_SEA=pal["sea"], C_SHELF=pal["shallow"], C_DEEP=kit.shade(pal["sea"], 0.8),
                    C_RIVER=pal["river"], C_RIVER_EDGE=pal["river_edge"])
    for n, c in cols.items():
        setattr(R, n, c)


# ---------------------------------------------------------------- the frame with pieces
class PieceFrame(R.Frame):
    def __init__(self, season="summer", towns=TOWN_LEVEL, fields=WHEAT, keep_base=False, with_pieces=True):
        R.Frame.__init__(self, 60)
        self.season = season
        self.winter = season == "winter"
        self.keep_base = keep_base
        self.assign = {}                                     # hex -> (family module, level, town or None)
        if with_pieces:
            for name, lv in towns.items():
                t = WORLD["towns"][name]
                self.assign[t["hex"]] = (settlements, lv, t)
            for hx, lv in fields.items():
                assert hx not in self.assign, hx
                self.assign[hx] = (wheat, lv, None)
        self.stats = {}

    # ---- geometry
    def hex_px(self, hx):
        x, y = self.P(*R.centre(*hx))
        return int(round(x)), int(round(y))

    def in_piece(self, x_km, y_km):
        return R.hex_of_km(x_km, y_km) in self.assign

    # ---- the frame's own drawing, without what the pieces replace
    def parcels(self):
        keep = [p for p in R.PARCELS if not self.in_piece(p["x"], p["y"])]
        self.stats["parcels dropped"] = len(R.PARCELS) - len(keep)
        cols = R.PARCEL_COLS if not self.winter else [(238, 241, 245), (214, 224, 236), (232, 236, 242), (190, 170, 148), (226, 232, 240)]
        edge = (104, 120, 60, 150) if not self.winter else (140, 152, 176, 150)
        lay = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        for p in keep:
            ca, sa = math.cos(p["a"]), math.sin(p["a"])
            pts = []
            for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                pts.append(self.P(p["x"] + ca * u * p["w"] / 2 - sa * v * p["h"] / 2, p["y"] + sa * u * p["w"] / 2 + ca * v * p["h"] / 2))
            pygame.draw.polygon(lay, cols[p["c"]] + (215,), pts)
            pygame.draw.lines(lay, edge, True, pts, 1)
        self.surf.blit(lay, (0, 0))

    def water(self):
        self.piece_ground()            # the pieces' fields and yards lie under the rivers and roads (other layers)
        if not self.winter:
            return R.Frame.water(self)
        k = self.k                      # winter: the same lines without the green valley band
        for st in WORLD["streams"]:
            self.stroke(st, 1.6 * k + 1.6, 2.6 * k + 1.6, kit.ICE_D)
        for rv in WORLD["rivers"]:
            w = {3: 6.5, 2: 4.6, 1: 3.4}[rv["cls"]] * k
            self.stroke(rv["pts"], w * 0.75 + 2, w + 2, R.C_RIVER_EDGE, clip_land=False)
        for st in WORLD["streams"]:
            self.stroke(st, 1.2 * k, 2.4 * k, kit.ICE)
        for rv in WORLD["rivers"]:
            w = {3: 6.5, 2: 4.6, 1: 3.4}[rv["cls"]] * k
            self.stroke(rv["pts"], w * 0.75, w, R.C_RIVER, clip_land=False)

    def relief(self):
        hills = R.HILLS
        R.HILLS = [h for h in hills if not self.in_piece(h["x"], h["y"])]
        self.stats["hills dropped"] = len(hills) - len(R.HILLS)
        try:
            R.Frame.relief(self)
        finally:
            R.HILLS = hills

    def trees(self):
        trees = R.TREES
        R.TREES = [t for t in trees if not self.in_piece(t["x"], t["y"])]
        self.stats["trees dropped"] = len(trees) - len(R.TREES)
        try:
            R.Frame.trees(self)
        finally:
            R.TREES = trees

    def towns(self):
        towns = WORLD["towns"]
        mine = {a[2]["name"] for a in self.assign.values() if a[2]}
        WORLD["towns"] = {n: t for n, t in towns.items() if n not in mine}
        try:
            R.Frame.towns(self)
        finally:
            WORLD["towns"] = towns
        for hx, (mod, lv, t) in self.assign.items():
            if not t:
                continue
            cx, cy = self.hex_px(hx)
            t["_label"] = (cx, cy + PLATE_DY)
            if t["port"]:               # the quay, moles and ships are the frame's coast layer: kept, at the old site
                x, y = t["x"], t["y"]
                t["x"], t["y"] = t["site0"]
                try:
                    bx, by = self.P(*t["site0"])
                    rx = {3: 26, 2: 15.5, 1: 8}[t["rank"]] * self.k * t.get("scale", 1.0)
                    t["_pieces"] = []
                    self.harbour(t, bx, by, rx, rx * R.TILT * 0.62, self.k, lambda y_, x_, fn: self.add(y_, x_, fn))
                    del t["_pieces"]
                finally:
                    t["x"], t["y"] = x, y
        self.place_pieces()

    # ---- winter stand-in
    def ground(self):
        R.Frame.ground(self)
        if not self.winter:
            return
        # The frame turns high ground to bare stone with a fixed colour; under snow it is snow with some stone showing.
        s = self.surf
        for y in range(self.H):
            for x in range(self.W):
                r, g, b, _ = s.get_at((x, y))
                if r > g > b and r - b > 18 and r < 215 and FIELDS.at(FIELDS.land, *self.km(x, y)) > 0.56:
                    t = max(0.0, min(1.0, ((r + g + b) / 3.0 - 120) / 60.0))
                    s.set_at((x, y), kit.mix((r, g, b), kit.mix((186, 194, 212), kit.SNOW, t), 0.8))
        self.ground_img = s.copy()

    def draw_range(self, g):
        if not self.winter:
            return R.Frame.draw_range(self, g)
        with snow_draw():
            R.Frame.draw_range(self, g)

    def draw_hill(self, x, y, h, seed):
        if not self.winter:
            return R.Frame.draw_hill(self, x, y, h, seed)
        with snow_draw():
            R.Frame.draw_hill(self, x, y, h, seed)

    def ground_tone(self, x, y, base, share):
        if self.winter:
            base = snowy(base)
        return R.Frame.ground_tone(self, x, y, base, share)

    def draw_tree(self, x, y, sc, f=1.0):
        if not self.winter:
            return R.Frame.draw_tree(self, x, y, sc, f)
        s = self.surf                   # bare twigs with a dab of snow, as kit.Piece.tree draws them
        r, th = 4.4 * sc, 3.0 * sc
        pygame.draw.line(s, kit.TRUNK, (x, y), (x, y - th), max(1, int(1.4 * sc)))
        for dx, dy in ((-0.9, -0.5), (-0.45, -1.0), (0.1, -1.15), (0.6, -0.95), (0.95, -0.45)):
            pygame.draw.line(s, (70, 54, 44), (x, y - th), (x + dx * r, y - th + dy * r * 1.25), 1)
        pygame.draw.line(s, kit.SNOW, (x - r * 0.7, y - th - r * 0.75), (x - r * 0.1, y - th - r * 1.3), 1)

    def draw_conifer(self, x, y, sc, f=1.0):
        if not self.winter:
            return R.Frame.draw_conifer(self, x, y, sc, f)
        s = self.surf
        h, w = 12.5 * sc, 7.2 * sc
        oc, lit, dk = kit.PAL["winter"]["conifer"]
        pygame.draw.line(s, kit.TRUNK, (x, y), (x, y - 2.5 * sc), max(1, int(1.3 * sc)))
        pts = [(x, y - h), (x + w / 2, y - 2 * sc), (x - w / 2, y - 2 * sc)]
        pygame.draw.polygon(s, R.shade(lit, f), pts)
        pygame.draw.polygon(s, R.shade(dk, f), [(x, y - h), (x + w / 2, y - 2 * sc), (x + w * 0.06, y - 2 * sc)])
        pygame.draw.polygon(s, kit.SNOW, [(x, y - h), (x - w * 0.5, y - 2 * sc), (x - w * 0.16, y - 2 * sc), (x - w * 0.02, y - h * 0.5)])
        pygame.draw.polygon(s, oc, pts, 1)

    # ---- the pieces
    def build_pieces(self):
        self.pieces = {}
        for hx, (mod, lv, t) in sorted(self.assign.items()):
            self.pieces[hx] = take_apart(mod.draw, lv, self.season, self.keep_base)

    def piece_ground(self):
        """The ground detail of every piece, on the frame's ground, clipped to the land."""
        self.build_pieces()
        lost = {}
        for hx, (ground, sh, things) in self.pieces.items():
            cx, cy = self.hex_px(hx)
            land = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)
            n = 0
            for j in range(SIZE):
                for i in range(SIZE):
                    if ground.get_at((i, j))[3] and not FIELDS.is_land(*self.km(cx - C + i + 0.5, cy - C + j + 0.5)):
                        n += 1
                    else:
                        land.set_at((i, j), (255, 255, 255, 255))
            if n:
                lost[hx] = n
                ground = ground.copy()
                ground.blit(land, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
            self.surf.blit(ground, (cx - C, cy - C), special_flags=pygame.BLEND_PREMULTIPLIED)
        self.stats["ground px clipped at the sea"] = lost

    def place_pieces(self):
        """Every standing thing of every piece joins the frame's back-to-front list by the y of its foot."""
        wet = {}
        count = 0
        for hx, (ground, sh, things) in self.pieces.items():
            cx, cy = self.hex_px(hx)
            for y, n, img, box in things:
                pos = (cx - C + box.x, cy - C + box.y)
                self.add(cy + y + n * 1e-5, cx, (lambda im, p: lambda: self.surf.blit(im, p, special_flags=pygame.BLEND_PREMULTIPLIED))(img, pos))
                count += 1
                foot_y = min(cy + y, pos[1] + box.height)               # smoke is queued 30 px low: use the picture's foot
                for fx in (pos[0] + 1, pos[0] + box.width // 2, pos[0] + box.width - 1):
                    if y < 60 and not FIELDS.is_land(*self.km(fx, foot_y)):
                        wet[hx] = wet.get(hx, 0) + 1
                        break
        self.stats["standing things placed"] = count
        self.stats["standing things with a foot in the sea"] = wet

    def draw_shadows(self):
        lay = pygame.Surface((self.W, self.H))
        lay.fill((255, 255, 255))
        lay.set_colorkey((255, 255, 255))
        for _, x, y, w, h in self.shadows:
            r = pygame.Rect(0, 0, w, h)
            r.center = (x, y)
            pygame.draw.ellipse(lay, (30, 50, 30), r)
        for hx, (ground, sh, things) in self.pieces.items():
            cx, cy = self.hex_px(hx)
            small = pygame.transform.smoothscale(sh.convert(24), (SIZE, SIZE))
            small.set_colorkey((255, 255, 255))
            lay.blit(small, (cx - C, cy - C))
        lay.set_alpha(46)
        self.surf.blit(lay, (0, 0))

    def render(self, path):
        season_cols(self.season)
        try:
            R.Frame.render(self, path)
        finally:
            season_cols("summer")
        return self.measure()

    # ---- the measurements
    def measure(self):
        out = []
        for k in sorted(self.stats):
            out.append("%s: %s" % (k, self.stats[k]))
        rows = []
        for hx, (mod, lv, t) in sorted(self.assign.items()):
            if not t or "_plate" not in t:
                continue
            r = t["_plate"]
            m = min(R.sites.hex_margin_km(*self.km(x, y), hx) for x in (r.left, r.right) for y in (r.top, r.bottom))
            cx, cy = self.hex_px(hx)
            rows.append("%s L%d plate %dx%d, top %+d px from the hex centre: %s%.1f px %s the hex border" % (
                t["name"], lv, r.width, r.height, r.top - cy, "" if m >= 0 else "", abs(m) * self.S, "inside" if m >= 0 else "OUTSIDE"))
        out += rows
        # what of the frame is left inside the piece hexes
        left = {}
        for rv in WORLD["rivers"]:
            for p in rv["pts"]:
                hx = R.hex_of_km(*p)
                if hx in self.assign:
                    left.setdefault(hx, set()).add("river " + rv["name"])
        for st in WORLD["streams"]:
            for p in st:
                hx = R.hex_of_km(*p)
                if hx in self.assign:
                    left.setdefault(hx, set()).add("stream")
        for rd in WORLD["roads"]:
            for p in rd["pts"]:
                hx = R.hex_of_km(*p)
                if hx in self.assign:
                    left.setdefault(hx, set()).add("road")
        for rg in R.RELIEF:
            for s in rg:
                hx = R.hex_of_km(s["x"], s["y"])
                if hx in self.assign:
                    left.setdefault(hx, set()).add("range (%s)" % s["kind"])
        for hx in sorted(left):
            mod, lv, t = self.assign[hx]
            out.append("hex %d,%d (%s L%d): the frame still draws %s" % (hx[0], hx[1], t["name"] if t else "wheat", lv, ", ".join(sorted(left[hx]))))
        for line in out:
            print("  ", line)
        return out


def move_sites(towns=TOWN_LEVEL):
    """A town with a piece stands at the middle of its piece; the roads are led there and the frame's own trees,
    hills and fields are built again round the new sites (the frame's own functions, nothing changed)."""
    S = 60.0 / R.R_KM
    for name in towns:
        t = WORLD["towns"][name]
        t["site0"] = (t["x"], t["y"])
        if name in R.sites.SHARED_SITES:
            continue                    # Genoa, Savona, Chiavari: their roads are fixed lines shared with the close-up
        cx, cy = R.centre(*t["hex"])
        t["x"], t["y"] = cx, cy + SITE_DY / (S * R.TILT)
    R.build_roads(WORLD)
    R.RELIEF, R.HILLS, R.RGRID = R.build_relief(WORLD, FIELDS)
    R.TREES = R.build_trees(WORLD, FIELDS, R.RGRID)
    R.PARCELS = R.build_parcels(WORLD, FIELDS)


def probe():
    """Lists the farmland hexes in view: where wheat pieces can go."""
    f = R.Frame(60)
    for (c, r), h in sorted(R.HEX.items()):
        if not h.get("land"):
            continue
        x, y = f.P(*R.centre(c, r))
        if not (30 < x < 1250 and 30 < y < 690):
            continue
        town = [t["name"] for t in WORLD["towns"].values() if t["hex"] == (c, r)]
        riv = sum(1 for rv in WORLD["rivers"] for p in rv["pts"] if R.hex_of_km(*p) == (c, r))
        st = sum(1 for s in WORLD["streams"] for p in s if R.hex_of_km(*p) == (c, r))
        rd = sum(1 for d in WORLD["roads"] for p in d["pts"] if R.hex_of_km(*p) == (c, r))
        print("%2d,%2d px %4d,%3d cover %d level %d %4d m  river %3d stream %3d road %3d  %s" % (
            c, r, x, y, h["cover"], h["level"], h.get("m", 0), riv, st, rd, " ".join(town)))


CROP = (460, 0, 640, 360)      # the Po plain: Asti to Piacenza


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--probe" in sys.argv:
        return probe()
    out = args[0] if args else os.path.join(HERE, "..", "..", "..", "docs", "design", "map", "pieces_in_map")
    which = args[1] if len(args) > 1 else "both"
    os.makedirs(out, exist_ok=True)
    move_sites()
    if which in ("both", "summer"):
        f = PieceFrame("summer")
        f.render(os.path.join(out, "summer.png"))
        crop = f.surf.subsurface(pygame.Rect(CROP)).copy()
        pygame.image.save(pygame.transform.scale(crop, (CROP[2] * 2, CROP[3] * 2)), os.path.join(out, "plain_crop.png"))
    if which in ("both", "winter"):
        PieceFrame("winter").render(os.path.join(out, "winter.png"))
    if "--ab" in sys.argv:              # the same crop with the kit's own ground base kept: what dropping it buys
        f = PieceFrame("summer", keep_base=True)
        f.render(os.path.join(out, "_base_kept.png"))
        crop = f.surf.subsurface(pygame.Rect(CROP)).copy()
        pygame.image.save(pygame.transform.scale(crop, (CROP[2] * 2, CROP[3] * 2)), os.path.join(out, "base_kept_crop.png"))
        os.remove(os.path.join(out, "_base_kept.png"))


if __name__ == "__main__":
    main()
