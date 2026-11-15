"""The frame stage of the Godot bake: the style frame's ground, relief shading, rivers, roads, coast and sea as base
images, and every standing wild object (trees, hills, mountain ranges) as sprites, per season.

It reads the style frame (tools/worldmap/style_frame) and the compositor (tools/worldmap/pieces_in_map/compose.py)
as they are and changes nothing in them; the compositor's own steps (carve_ports, move_sites, the winter by climate)
are called, so the base is the compositor's frame without its towns, fields and pieces.

Importing this module imports the style frame, which builds the world (about 15 s). Call init() once, then
bake_season(). STYLE_FRAME_LAYERS must be set before the import.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pieces_in_map"))
sys.path.insert(0, HERE)

import compose as CP                    # imports the style frame (render) and the kit
import atlas as AT
sys.path.insert(0, os.path.join(HERE, "..", "tileset_bake"))
import art as ART                   # the wild things' drawing (trees, hills, ranges) in every season, without a world

R = CP.R
kit = CP.kit
pygame = CP.pygame
WORLD, FIELDS = CP.WORLD, CP.FIELDS
MARGIN = 100                            # px of canvas round the frame for the wild sprites that hang over its edge

COVER_NAMES = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]      # godot/core/mapgen/world_cover.gd
_INIT = False


def init():
    """The compositor's two map changes, once: Genoa's carved bay and the towns' sites at the middle of their hexes."""
    global _INIT
    if not _INIT:
        CP.carve_ports()
        CP.move_sites()
        R.check_water()                 # rivers and streams must end on water: prints the problems (none expected)
        _INIT = True


# ---------------------------------------------------------------- spring and autumn: a stand-in from the kit's palettes
def season_colours(season):
    """Sets the frame's colours for a season. Summer and winter are the compositor's own; spring and autumn have no
    frame palette, so the kit's season tokens (kit.PAL) replace the summer ones (a stand-in, like the winter)."""
    if season in ("spring", "autumn"):
        pal, base = kit.PAL[season], kit.PAL["summer"]
        cols = dict(CP.SUMMER_COLS)
        deep = CP.SUMMER_COLS["C_DEEP"]
        cols.update(C_FARM=pal["farm"], C_GRASS=pal["grass"], C_WOOD=pal["wood"], C_ROCK=pal["rock"], C_SAND=pal["sand"],
                    C_SEA=pal["sea"], C_SHELF=pal["shallow"], C_RIVER=pal["river"], C_RIVER_EDGE=pal["river_edge"],
                    C_DEEP=tuple(int(deep[i] * pal["sea"][i] / base["sea"][i]) for i in range(3)))
        for n, c in cols.items():
            setattr(R, n, c)
    else:
        CP.season_cols(season)


def season_tone(season):
    """The frame's greens (hills, wooded ranges) in spring or autumn: the green scaled by the kit's grass of that season."""
    if season not in ("spring", "autumn"):
        return None
    pal, base = kit.PAL[season]["grass"], kit.PAL["summer"]["grass"]
    k = [pal[i] / base[i] for i in range(3)]

    def tone(col):
        if not CP.is_green(col):
            return col
        return tuple(max(0, min(255, int(col[i] * k[i]))) for i in range(3)) + tuple(col[3:])
    return tone


# ---------------------------------------------------------------- the frame, as the compositor draws it, without pieces
class BakeFrame(CP.PieceFrame):
    """The compositor's frame (winter by climate included) without towns, parcels and pieces. With margin > 0 the
    canvas is bigger and everything is shifted by it (for the wild sprites); km() undoes the shift."""

    def __init__(self, season, margin=0, with_pieces=False):
        CP.PieceFrame.__init__(self, season, with_pieces=with_pieces)
        self.margin = margin
        self.tone = season_tone(season)
        if margin:
            self.W += 2 * margin
            self.H += 2 * margin
        self.rec = None                      # a list: the draw_* calls are only noted in it, nothing is drawn
        self.shadow_at = []

    def P(self, x, y):
        px, py = R.Frame.P(self, x, y)
        return px + self.margin, py + self.margin

    def km(self, px, py):
        return R.Frame.km(self, px - self.margin, py - self.margin)

    def add(self, y, x, fn):
        self.shadow_at.append(len(self.shadows))
        R.Frame.add(self, y, x, fn)

    def parcels(self):
        pass

    # ---- standing things: noted or drawn
    def trees(self):
        for i, t in enumerate(R.TREES):
            bx, by = self.P(t["x"], t["y"])
            sc = t["s"] * self.k
            if t["con"]:
                self.add(by, bx, (lambda a, b, c, d: lambda: self.draw_conifer(a, b, c, 1.0, d))(bx, by, sc, i))
            else:
                self.add(by, bx, (lambda a, b, c, d: lambda: self.draw_tree(a, b, c, 1.0, d))(bx, by, sc, i))
            self.shadows.append(("ell", bx + 3.2 * sc, by + 0.5, 7 * sc, 2.4 * sc))

    def draw_tree(self, x, y, sc, f=1.0, i=0):
        if self.rec is not None:
            self.rec.append(("tree", x, y, sc, i))
            return
        if self.winter:
            return CP.PieceFrame.draw_tree(self, x, y, sc, f)
        if self.season == "summer":
            return R.Frame.draw_tree(self, x, y, sc, f)
        return ART.Painter(self.season).on(self.surf).draw_tree(x, y, sc, f, i)     # spring or autumn: the kit's leaf colours

    def draw_conifer(self, x, y, sc, f=1.0, i=0):
        if self.rec is not None:
            self.rec.append(("conifer", x, y, sc, i))
            return
        if self.winter:
            return CP.PieceFrame.draw_conifer(self, x, y, sc, f)
        if self.season == "summer":
            return R.Frame.draw_conifer(self, x, y, sc, f)
        return ART.Painter(self.season).on(self.surf).draw_conifer(x, y, sc, f, i)

    def draw_range(self, g):
        if self.rec is not None:
            self.rec.append(("range", g))
            return
        if self.tone is not None:
            with CP.tone_draw(self.tone):
                return R.Frame.draw_range(self, g)
        return CP.PieceFrame.draw_range(self, g)

    def draw_hill(self, x, y, h, seed):
        if self.rec is not None:
            self.rec.append(("hill", x, y, h, seed))
            return
        if self.tone is not None:
            with CP.tone_draw(self.tone):
                return R.Frame.draw_hill(self, x, y, h, seed)
        return CP.PieceFrame.draw_hill(self, x, y, h, seed)


def _note(frame, fn):
    frame.rec = []
    try:
        fn()
        return frame.rec[0]
    finally:
        frame.rec = None


# ---------------------------------------------------------------- the base
def render_base(season):
    """(ground, overlay, base, frame): the frame's ground with rocks and waves; its rivers, roads, bridges and pass marks
    on a transparent layer; and the two together."""
    f = BakeFrame(season)
    season_colours(season)
    try:
        f.ground()
        f.rocks()
        f.waves()
        ground = f.surf.copy()
        f.surf = pygame.Surface((f.W, f.H), pygame.SRCALPHA)
        f.water()
        f.roads()
        f.bridges()
        f.passes()
        for y, x, fn in sorted(f.objs, key=lambda o: (o[0], o[1])):
            fn()
        overlay = f.surf
    finally:
        season_colours("summer")
    base = ground.copy()
    base.blit(overlay, (0, 0))
    return ground, overlay, base, f


# ---------------------------------------------------------------- the wild sprites
def _region(rec, k=1.0):
    kind = rec[0]
    if kind in ("tree", "conifer"):
        x, y = rec[1], rec[2]
        return pygame.Rect(int(x - 30 * k), int(y - 46 * k), int(60 * k), int(58 * k))
    if kind == "hill":
        x, y, h = rec[1], rec[2], rec[3]
        return pygame.Rect(int(x - (h * 1.4 + 8) * k), int(y - (h + 8) * k), int((h * 2.8 + 16) * k), int((h + 16) * k))
    g = rec[1]
    hm = max(p["h"] for p in g)
    x0, x1 = min(p["x"] for p in g), max(p["x"] for p in g)
    y0, y1 = min(p["y"] for p in g), max(p["y"] for p in g)
    return pygame.Rect(int(x0 - (2.6 * hm + 12) * k), int(y0 - (1.8 * hm + 20) * k),
                       int(x1 - x0 + (5.2 * hm + 24) * k), int(y1 - y0 + (2.1 * hm + 36) * k))


def _draw_rec(f, rec):
    kind = rec[0]
    if kind == "tree":
        f.draw_tree(round(rec[1]), round(rec[2]), rec[3], 1.0, rec[4])
    elif kind == "conifer":
        f.draw_conifer(round(rec[1]), round(rec[2]), rec[3], 1.0, rec[4])
    elif kind == "hill":
        f.draw_hill(round(rec[1]), round(rec[2]), rec[3], rec[4])
    else:
        f.draw_range(rec[1])


def sprite_of(f, scratch, rec):
    """(surface, (x, y)) of one wild object drawn alone on the transparent scratch canvas: the sprite cut to its box and
    where its top-left lay on the canvas."""
    k = 1.0
    for _ in range(5):
        region = _region(rec, k).clip(scratch.get_rect())
        scratch.set_clip(region)
        f.surf = scratch
        try:
            _draw_rec(f, rec)
        finally:
            scratch.set_clip(None)
        box = scratch.subsurface(region).get_bounding_rect()
        out = None
        if box.width:
            out = (scratch.subsurface(box.move(region.topleft)).copy(), (box.x + region.x, box.y + region.y))
        scratch.fill((0, 0, 0, 0), region)
        if out is None:
            return None
        touching = box.left == 0 or box.top == 0 or box.right == region.width or box.bottom == region.height
        inside = region.left > 0 and region.top > 0 and region.right < scratch.get_width() and region.bottom < scratch.get_height()
        if not (touching and inside):
            return out
        k *= 1.5
    raise RuntimeError("wild sprite does not fit its region: %r" % (rec[:1],))


def shadow_sprite(shs):
    """The soft shadow of one wild object: its ellipses laid as one flat shape at the frame's shadow alpha (46/255)."""
    rects = []
    for _, x, y, w, h in shs:
        r = pygame.Rect(0, 0, w, h)
        r.center = (x, y)
        rects.append(r)
    box = rects[0].unionall(rects[1:]).inflate(2, 2)
    s = pygame.Surface(box.size, pygame.SRCALPHA)
    for r in rects:
        pygame.draw.ellipse(s, kit.SHADOW + (kit.SHADOW_ALPHA,), r.move(-box.x, -box.y))
    return s, box.topleft


KINDS = {"tree": "tree", "conifer": "tree", "hill": "hill", "range": "range"}


def range_slices(f, scratch, rec, shs):
    """A mountain range group as one object per sample (peak or saddle point): the group is drawn whole and cut into vertical
    strips halfway between neighbouring samples, so the strips together are exactly the whole range, and a strip can be dropped
    (as compose.py drops range samples at a piece's footprint) without redrawing. Returns [(sample, sprite, shadow)]."""
    g = rec[1]
    res = sprite_of(f, scratch, rec)
    if res is None:
        return []
    surf, (ox, oy) = res
    xs = [p["x"] for p in g]
    cuts = [-1e9] + [(a + b) / 2.0 for a, b in zip(xs, xs[1:])] + [1e9]
    apex_shadows = iter(shs)
    out = []
    for i, p in enumerate(g):
        shadow = next(apex_shadows) if p["apex"] else None
        x0, x1 = max(int(math.floor(cuts[i])), ox), min(int(math.floor(cuts[i + 1])), ox + surf.get_width())
        spr = None
        if x1 > x0:
            strip = surf.subsurface(pygame.Rect(x0 - ox, 0, x1 - x0, surf.get_height()))
            box = strip.get_bounding_rect()
            if box.width:
                spr = (strip.subsurface(box).copy(), (x0 + box.x, oy + box.y))
        out.append((p, spr, shadow))
    return out


def bake_wild(season, out_dir):
    """Every wild object of the frame as sprites for one season: wild_<season>*.png and the table of the objects. Trees and
    hills are one object each; a mountain range is one object per sample (see range_slices)."""
    f = BakeFrame(season, MARGIN)
    season_colours(season)
    try:
        f.relief()
        f.trees()
        scratch = pygame.Surface((f.W, f.H), pygame.SRCALPHA)
        atlas = AT.Atlas("wild_" + season)
        rows = []
        n = len(f.objs)

        def row(kind, species, foot, sy, sx, res, sh, group=None):
            kx, ky = f.km(foot[0] + MARGIN, foot[1] + MARGIN)
            rows.append(dict(kind=kind, species=species, foot=foot, sort_y=sy - MARGIN, x=sx - MARGIN, hex=R.hex_of_km(kx, ky), group=group,
                             spr=None if res is None else (atlas.add(res[0]), res[1]),
                             shd=None if sh is None else (atlas.add(sh[0]), sh[1])))
        for i, (sy, sx, fn) in enumerate(f.objs):
            rec = _note(f, fn)
            s0, s1 = f.shadow_at[i], (f.shadow_at[i + 1] if i + 1 < n else len(f.shadows))
            shs = f.shadows[s0:s1]
            if rec[0] == "range":
                for p, spr, shd in range_slices(f, scratch, rec, shs):
                    foot = (round(p["x"]) - MARGIN, round(p["y"]) - MARGIN)
                    row("range", "range", foot, p["y"], p["x"], spr, None if shd is None else shadow_sprite([shd]), group=i)
                continue
            foot = (round(rec[1]) - MARGIN, round(rec[2]) - MARGIN)
            row(KINDS[rec[0]], rec[0], foot, sy, sx, sprite_of(f, scratch, rec), shadow_sprite(shs) if shs else None)
    finally:
        season_colours("summer")
    files = atlas.pack(out_dir)
    out = []
    for r in rows:
        e = dict(kind=r["kind"], species=r["species"], foot=list(r["foot"]), sort_y=r["sort_y"], x=r["x"], hex=list(r["hex"]), group=r["group"])
        for key in ("spr", "shd"):
            v = r[key]
            if v is None:
                e[key] = None
                continue
            stem, rect = atlas.rect(v[0])
            e[key] = {"atlas": stem, "rect": rect, "offset": [v[1][0] - MARGIN - r["foot"][0], v[1][1] - MARGIN - r["foot"][1]]}
        out.append(e)
    return out, files


# ---------------------------------------------------------------- the data of the hexes
def hex_grid_data():
    """The facts of the compositor's piece frame (summer): per-hex coast, climate, rivers, roads, passes, places, and the
    placements of the compositor (what stands where)."""
    f = CP.PieceFrame("summer")
    season_colours("summer")
    f.build_pieces()
    cf = CP.climate_field()
    W, H = f.W, f.H
    river_edges, stream_edges = {}, {}                  # hex -> {direction}: 0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE
    lay = R.L
    apothem = R.W_KM / 2.0
    for rv in lay["rivers"]:                            # the river's points run through the middles of hex edges (and end at corners)
        for p in rv["pts"]:
            h0 = R.hex_of_km(p[0], p[1])
            near = [h for h in [h0] + R.nbrs(*h0) if h in R.HEX and abs(math.dist(R.centre(*h), p) - apothem) < 0.3]
            for a in near:
                for d, b in enumerate(R.nbrs(*a)):
                    if b in near and b != a:
                        river_edges.setdefault(a, set()).add(d)
    for e in lay["streams"]:
        a, b = (e[0], e[1]), (e[2], e[3])
        if a in R.HEX and b in R.HEX and b in R.nbrs(*a):
            d = R.nbrs(*a).index(b)
            stream_edges.setdefault(a, set()).add(d)
            stream_edges.setdefault(b, set()).add((d + 3) % 6)
    road_hexes = {R.hex_of_km(*p) for rd in WORLD["roads"] for p in rd["pts"]}
    frame_passes = {p["name"] for p in WORLD["passes"].values()}
    passes = {(p[0], p[1]): p[3] for p in lay["passes"] if p[3] not in frame_passes}
    for p in WORLD["passes"].values():
        passes[R.hex_of_km(p["x"], p["y"])] = p["name"]
    places = {}
    for p in lay["places"]:
        places[(p["x"], p["y"])] = dict(name=p["name"], level=p["level"], port=bool(p["port"]), rank=None, proto=False)
    for t in WORLD["towns"].values():
        for hx in [h for h, v in places.items() if v["name"] == t["name"]]:
            del places[hx]
        places[t["hex"]] = dict(name=t["name"], level=CP.TOWN_LEVEL.get(t["name"], t["rank"]), port=bool(t["port"]) or t["name"] in CP.PORTS,
                                rank=t["rank"], proto=True, mode=CP.port_mode(t) if t["port"] else "seaside")
    hexes = []
    for hx in sorted(R.HEX, key=lambda q: (q[1], q[0])):
        c, r = hx
        h = R.HEX[hx]
        cx, cy = f.hex_px(hx)
        if cx < -52 or cx > W + 52 or cy < -51 or cy > H + 51:
            continue
        land = bool(h.get("land"))
        sea, shore = f.sea_of(hx) if land else (None, None)
        place = None
        pl = places.get(hx)
        if pl:
            mode = None
            if pl["port"]:
                mode = pl.get("mode") or ("carved" if pl["level"] >= 4 else "seaside")
            place = {"name": pl["name"], "level": pl["level"], "port": pl["port"], "port_mode": mode, "landmark": None,
                     "in_prototype": pl["proto"]}
        cover = h.get("cover", -1)
        hexes.append({
            "c": c, "r": r, "land": land, "cover": COVER_NAMES[cover] if land and 0 <= cover < len(COVER_NAMES) else None,
            "height_m": float(h.get("m", 0.0)), "coast": sea is not None, "sea_angle": None if sea is None else round(sea, 2),
            "shore": None if shore is None else [[round(x, 1), round(y, 1)] for x, y in shore],
            "climate": cf.of_hex(hx), "river_edges": sorted(river_edges.get(hx, ())), "stream_edges": sorted(stream_edges.get(hx, ())),
            "road": hx in road_hexes, "pass": passes.get(hx), "place": place, "centre_px": [cx, cy]})
    place_rows = []                                     # the compositor's placements: what stands where
    given = f.stats["coast pieces (family, level asked, level given, land depth px)"]
    for hx, (mod, lv, t) in sorted(f.assign.items()):
        pc = f.pieces[hx]
        sea, shore = f.sea_of(hx)
        place_rows.append(dict(hex=list(hx), family=mod.__name__.replace("piece_", ""), level_asked=lv, level=given[hx][2] if hx in given else lv,
                               kw=f.kw.get(hx, {}), variant=pc["variant"], mirror=bool(pc["mirror"]), town=t["name"] if t else None,
                               coast=bool(pc["coast"]), addon=False, centre=list(f.hex_px(hx)), sea=sea,
                               shore=None if shore is None else [list(p) for p in shore], bay=None, climate=cf.of_hex(hx)))
        ad = f.addons.get(hx)
        if ad is not None:
            ax, ay = ad["centre"]
            sea2, shore2 = f.sea_at(ax, ay)
            name = t["name"]
            place_rows.append(dict(hex=list(hx), family="harbour", level_asked=CP.PORTS[name], level=CP.PORTS[name], kw={},
                                   variant=ad["variant"], mirror=bool(ad["mirror"]), town=name, coast=True, addon=True,
                                   centre=[ax, ay], sea=sea2, shore=[list(p) for p in shore2], bay=CP.BAYS.get(name),
                                   climate=cf.of_hex(hx)))
    return hexes, place_rows


def land_mask(path):
    """land_mask.png: white where the frame's coast field says land (after Genoa's bay is cut), black at sea."""
    w, h = 1280, 720
    img = pygame.Surface((w, h))
    S = 60.0 / R.R_KM
    for y in range(h):
        ky = R.Y0 + (y + 0.5) / (S * R.TILT)
        for x in range(w):
            if FIELDS.is_land(R.X0 + (x + 0.5) / S, ky):
                img.set_at((x, y), (255, 255, 255))
    pygame.image.save(img, path)


def bake_season(season, out_dir, extra=False):
    """Everything of one season; with extra=True also the season-independent files (hex data, land mask)."""
    init()
    result = {"season": season}
    ground, overlay, base, f = render_base(season)
    pygame.image.save(base, os.path.join(out_dir, "base_%s.png" % season))
    pygame.image.save(ground, os.path.join(out_dir, "ground_%s.png" % season))
    pygame.image.save(overlay, os.path.join(out_dir, "overlay_%s.png" % season))
    result["wild"], result["wild_files"] = bake_wild(season, out_dir)
    if extra:
        result["hexes"], result["placements"] = hex_grid_data()
        land_mask(os.path.join(out_dir, "land_mask.png"))
        result["size"] = [f.W, f.H]
        result["px_per_km"] = f.S
        result["tilt"] = R.TILT
        result["origin_km"] = [R.X0, R.Y0]
        result["hex_w_km"] = R.W_KM
    return result


def run_task(args):
    """Pool entry: (season, out_dir, extra) -> bake_season()."""
    season, out_dir, extra = args
    return bake_season(season, out_dir, extra)
