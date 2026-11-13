"""Drawing the campaign map: a cached, zoomable political / terrain / goods / market map with fog."""
import functools
import math
import os
import time

import pygame

from ..hexgrid import neighbors
from . import art, geo, goodsart, goodsobjects, landscape, wfctiles
from .render.budget import FrameBudget
from .data import (GOODS, NATIVE_VILLAGE_SPRITE,
                   TERRAIN, TERRAIN_SPRITES, WORKS)

SQRT3 = math.sqrt(3)
ZOOMS = (3, 5, 8, 13, 21, 34)     # hex radius in pixels
TILE_FROM = 3                     # from this zoom level on, the map is drawn with tile art
LAND_FROM = 21                    # from this hex radius on, the map is drawn with the landscape art (_draw_landscape)
LAND_BUILD_MS = 3.0               # time a frame may spend building composites and object lists (at least one of each);
                                  # a hex not built yet is drawn with its old sprite, or without its objects
PREFETCH_RING = 3                 # hexes beyond the view that idle frames build ahead (a pan stays on built ground)
PREFETCH_FIT = 0.3                 # share of a build that must fit in the time left before it is started
PREFETCH_LATE_MS = 17.0           # a frame already this long gets no extra slice
PREFETCH_MIN_MS = 1.0             # a frame that is panning always spends this long on the ring, however late it is
BACKDROP_MAX_K = 2.2              # no backdrop for a zoom jump bigger than this (13 to 34): it would be a smear
BACKDROP_S = 2.5                  # a zoom's stand-in picture (the old frame, scaled) is dropped after this long at the latest
LAND_IDLE_MS = 8.0                # a frame may prefetch the ring round the view until this many ms into the frame
WARM_MS = 250.0                   # the start-up warm of the view's hexes stops after this long (the rest: prefetch)
LAND_STILL_MS = 24.0              # a frame whose camera did not move (same zoom) may spend this long building in total
                                  # (overlays, composites, object lists), nearest the view centre first
ART_KEYS = {"galleon": "carrack"}   # unit kinds drawn with another kind's figure until they get their own
MINES = ("iron", "silver", "gold", "salt")
BANK, RIVER_DARK, RIVER = (205, 190, 125), (40, 100, 170), (95, 160, 220)
ROAD, ROAD_EDGE = (190, 150, 95), (120, 85, 50)
SPRITE_H = 70 / (60 / SQRT3)      # Kenney tiles are 60x70 for a hex of radius 34.6
GOODS_VIEWS = ("chips", "deposits", "prices")
TERRAIN_TINT = {"plains": (150, 205, 90), "steppe": (215, 195, 110), "forest": (25, 105, 45), "hills": (175, 140, 90),
                "mountains": (150, 150, 165), "desert": (245, 215, 130), "jungle": (15, 115, 65), "tundra": (205, 215, 220),
                "marsh": (80, 150, 130), "taiga": (60, 110, 90), "savanna": (220, 190, 90), "beach": (240, 220, 160),
                "snow": (240, 245, 250)}
ABBR = {"grain": "GRN", "fish": "FSH", "salt": "SLT", "wine": "WIN", "wool": "WOL", "cotton": "CTN", "timber": "TMB",
        "iron": "IRN", "sugar": "SUG", "tobacco": "TOB", "furs": "FUR", "ivory": "IVR", "spices": "SPC",
        "silver": "SLV", "gold": "GLD"}


def abbr(good):
    """The chip text of a good: its short form, or the first three letters of its name (not all goods have one)."""
    return ABBR.get(good) or GOODS[good].name[:3].upper()


BLACK_FOG = (14, 16, 22)
MODE_BORDERS = 150                # alpha of the owner borders in the terrain, goods and markets modes
DIM = (0, 0, 0, 105)               # the fog over hexes the player knows but cannot see now
FROST = (245, 248, 255, 70)        # the winter frost of the north
SEA = (38, 74, 128)
SHALLOW = (52, 104, 160)
SEA_DEEP = (30, 60, 108)
NATIVE_LAND = (205, 192, 160)
WASTE = (215, 200, 165)
MODES = ("political", "terrain", "goods", "markets")


_CORNERS = [(math.cos(math.radians(60 * i - 30)), math.sin(math.radians(60 * i - 30))) for i in range(6)]


def hex_points(cx, cy, r):
    return [(cx + r * c, cy + r * s) for c, s in _CORNERS]      # the corner table: same floats, no trig


@functools.lru_cache(maxsize=2048)       # colour tuples only (no surfaces), bounded: not a render cache
def tint(color, amount):
    return tuple(max(0, min(255, int(c + (255 - c) * amount))) if amount > 0 else max(0, int(c * (1 + amount)))
                 for c in color)


def market_color(index):
    hue = (index * 0.618034) % 1.0
    color = pygame.Color(0)
    color.hsva = (hue * 360, 55, 85, 100)
    return (color.r, color.g, color.b)


class MapView:
    MARGIN = 6

    def __init__(self, world, tiles_dir=None):
        self.world = world
        self.tiles_dir = tiles_dir
        self._market_index_key, self._market_index = None, {}
        self._sprites = {}
        self._overlays = {}
        self.goods_view = "chips"
        self.zoom = 1
        self.mode = "political"
        self._cache = None
        self._key = None
        self.title_fonts = {}
        self.small = pygame.font.SysFont("segoeui,arial", 12, bold=True)
        self.tiny = pygame.font.SysFont("segoeui,arial", 10, bold=True)
        self.num = pygame.font.SysFont("segoeui,arial", 11, bold=True)
        self._art = {}
        self._figures = {}
        terrain = world.terrain
        self.shallow = {p for p, t in terrain.items() if t == "ocean"
                        and any(terrain.get(n) not in (None, "ocean", "lake") for n in neighbors(p))}
        self.lat = {p: geo.lonlat(p)[1] for p in terrain}
        self._rivers = []
        for i, (name, path) in enumerate(sorted(getattr(world, "rivers", {}).items())):
            pts = art.smooth([self.unit_point(q) for q in path], 3, wobble=0.22, seed=i)
            xs, ys = [x for x, _ in pts], [y for _, y in pts]
            self._rivers.append((pts, (min(xs), min(ys), max(xs), max(ys))))
        self._edges = self._edge_sockets(world)
        self._overlay_base = {}       # TileDesc -> 120x140 overlay (generated a few per frame)
        self._gen_budget = 0
        self.land = landscape.Landscape(world, tiles_dir) if tiles_dir else None
        self._pan = (0.0, 0.0)             # the last camera move, for prefetching ahead of a pan
        self._last_cam = None
        self._pf_done, self._pf_version = set(), None
        self._budget, self._frame_objs = FrameBudget(LAND_BUILD_MS), 0      # the frame's slice for builds
        self._frame_sprites, self._frame_ov = 0, 0
        self._warmed = False               # the start-up warm of the landscape zooms runs on the first draw
        self.warm_ms = 0.0
        self._last_r, self._still = None, False
        self._fill_key, self._fill_seen = None, set()
        self._filled = None                # (camera, r, season, world version) of the last still frame that built it all
        self._pm_edges, self._pm_ver = {}, None      # (pos, r) -> owner border segments, for this world version
        self._under_backdrop = set()
        self._pf_plan = None               # (key, plan, cursor) of the prefetch: rebuilt only when its inputs change
        self._pf_cost = {"g": 0.0015, "o": 0.0008}   # moving average of what one ground / object build costs (s)
        self._frame = None                 # the last frame's map (before units and fog), kept for a zoom's backdrop
        self._frame_at = None              # (r, camera) of that frame
        self._backdrop = None              # (scaled old frame, its top-left in world px at the new r, drop time)
        self._tint_sprites = {}            # (rgba, r) -> one translucent hex for _tint
        self._tint_layers = {}             # clip size -> the layer _tint draws on
        self._labels = {}                  # (town name, r) -> (shade box, name surface): drawn every frame, rendered once
        self._late_labels = []             # (shade, name, centre-top point) of the far zooms: drawn over the unit tokens
        self._label_key, self._label_plan = None, {}   # the town names placed at this zoom, fog and focus (_town_labels)
        self._label_stats = {}             # the last placement: placed, skipped, ms
        self._focus = None                 # the selected province's position: its town name is never hidden
        self._drawn_labels = []            # (pos, screen rect) of the town names drawn this frame
        self.pass_names_on = True          # pass names at the closest zoom (an option, like the grid)
        self.grid_on = True                # the faint hex grid on the landscape zooms (the G key)
        self._roads = []
        for path in getattr(world, "road_paths", []):
            pts = [self.unit_point(q) for q in path]
            xs, ys = [x for x, _ in pts], [y for _, y in pts]
            self._roads.append((pts, (min(xs), min(ys), max(xs), max(ys))))

    # ----- geometry --------------------------------------------------------------------
    @property
    def r(self):
        return ZOOMS[self.zoom]

    @staticmethod
    def unit_point(pos):
        """A hex centre in units of the hex radius (before the margin)."""
        col, row = pos
        return ((col + 0.5 * (row & 1) + 0.5) * SQRT3, row * 1.5 + 1)

    def center(self, pos):
        r = self.r
        w = r * SQRT3
        col, row = pos
        return (self.MARGIN + (col + 0.5 * (row & 1) + 0.5) * w, self.MARGIN + row * 1.5 * r + r)

    def size(self):
        r = self.r
        return (int(self.world.cols * r * SQRT3 + r * SQRT3 / 2 + 2 * self.MARGIN),
                int(self.world.rows * 1.5 * r + r / 2 + 2 * self.MARGIN))

    def hex_at(self, x, y):
        r = self.r
        w = r * SQRT3
        px, py = x - self.MARGIN - w / 2, y - self.MARGIN - r
        q = (SQRT3 / 3 * px - py / 3) / r
        rr = (2 / 3 * py) / r
        s = -q - rr
        rq, rrr, rs = round(q), round(rr), round(s)
        dq, dr, ds = abs(rq - q), abs(rrr - rr), abs(rs - s)
        if dq > dr and dq > ds:
            rq = -rrr - rs
        elif dr > ds:
            rrr = -rq - rs
        return rq + (rrr - (rrr & 1)) // 2, rrr

    # ----- cached map layer -----------------------------------------------------------
    def fog_stamp(self):
        """What the cached map layers (here and the minimap) depend on: the world version, the player and how many
        hexes the player has explored. A stack that walks several hexes adds what it sees on the way without bumping
        the version, so the count is part of the key."""
        world = self.world
        country = world.countries.get(world.player)
        return world.version, world.player, len(country.explored) if country else 0

    def surface(self):
        key = (self.zoom, self.mode, self.fog_stamp(), self.world.winter())
        if key != self._key:
            self._key = key
            self._cache = self._render()
        return self._cache

    def known(self):
        world = self.world
        player = world.countries.get(world.player)
        if player:
            return player.explored
        if not hasattr(self, "_old_world"):
            self._old_world = getattr(world, "_known_world", None) or \
                {p for p in world.terrain if world.geo.KNOWN_WORLD(*geo.lonlat(p))}
        return self._old_world

    def _colour(self, pos):
        world = self.world
        terrain = world.terrain[pos]
        if terrain == "ocean":
            return SHALLOW if pos in self.shallow else SEA
        if terrain == "lake":
            return TERRAIN["lake"].color
        prov = world.provinces[pos]
        if self.mode == "terrain":
            return TERRAIN[terrain].color
        if self.mode == "goods":
            if prov.good is None:
                return (120, 110, 95)
            return GOODS[prov.good].color
        if self.mode == "markets":
            if prov.market is None:
                return (95, 95, 95) if prov.owner else NATIVE_LAND
            number = self._market_number(prov.market)
            return market_color(number) if number is not None else (95, 95, 95)
        if prov.owner:
            color = world.countries[prov.owner].color
            return tint(color, 0.15) if not prov.colony else tint(color, 0.45)
        return WASTE if prov.terrain == "desert" else NATIVE_LAND

    def _render(self):
        world = self.world
        r = self.r
        surf = pygame.Surface(self.size())
        surf.fill(BLACK_FOG)
        known = self.known()
        visible = world.visible
        grow = 0.6 if r >= 9 else 1.1
        outline = r >= 13
        unseen = []
        for pos in world.terrain:
            if pos not in known:
                continue
            cx, cy = self.center(pos)
            pts = hex_points(cx, cy, r + grow)
            color = self._colour(pos)
            pygame.draw.polygon(surf, color, pts)
            if outline and world.is_land(pos):
                pygame.draw.polygon(surf, tint(color, -0.12), hex_points(cx, cy, r), 1)
            if pos not in visible and world.player:
                unseen.append(((0, 0, 0, 85), cx, cy))
        self._tint(surf, unseen, cache=False)           # one sheet: a shade per hex would show every shared edge
        if r >= 5 and self.mode in ("political", "terrain"):
            m = self.MARGIN
            for pts, _ in self._rivers:
                pygame.draw.lines(surf, (60, 120, 190), False, [(m + x * r, m + y * r) for x, y in pts],
                                  max(1, r // 4))
            rivers = getattr(world, "river_at", {})
            hide = {n for p in rivers for n in neighbors(p) if n not in known} | {p for p in rivers if p not in known}
            for pos in hide:
                if pos in world.terrain:
                    pygame.draw.polygon(surf, BLACK_FOG, hex_points(*self.center(pos), r + 1.2))
        self._borders(surf, known)
        if self.land is not None:                                  # the ridge crests' relief fold (per season)
            m = self.MARGIN
            landscape.draw_far_ridges(surf, r, world.winter(), lambda p: (m + p[0] * r, m + p[1] * r), self._ridge_items(known))
        self._decorations(surf, known)
        return surf

    def _borders(self, surf, known):
        world = self.world
        r = self.r
        width = 1 if r < 9 else 2
        for prov in world.provinces.values():
            if prov.pos not in known or not prov.owner:
                continue
            cx, cy = self.center(prov.pos)
            pts = hex_points(cx, cy, r)
            near = list(neighbors(prov.pos))
            for edge in range(6):
                other = world.provinces.get(near[(6 - edge) % 6])
                if other is None or other.owner != prov.owner:
                    color = (20, 20, 24) if other is not None and other.owner else (30, 30, 34)
                    pygame.draw.line(surf, color, pts[edge], pts[(edge + 1) % 6], width)
            if prov.controller != prov.owner and prov.controller:
                ctrl = world.countries[prov.controller].color
                for k in (-0.5, 0.0, 0.5):
                    pygame.draw.line(surf, ctrl, (cx - r * 0.6 + k * r, cy + r * 0.5), (cx + k * r + r * 0.1, cy - r * 0.5), 2)

    def _decorations(self, surf, known):
        world = self.world
        r = self.r
        if self.mode == "political" and r <= 13:
            self._country_names(surf, known)
        if self.mode == "markets":
            for market in world.markets:
                if market.active and market.center in known:
                    cx, cy = self.center(market.center)
                    pygame.draw.circle(surf, (20, 20, 20), (cx, cy), max(3, r // 2))
                    pygame.draw.circle(surf, (255, 230, 120), (cx, cy), max(2, r // 2 - 1))
                    self._label(surf, market.name, (cx, cy - r - 4), self.small)
        if r >= 9:
            for pos, (name, size) in world.cities.items():
                if pos not in known or (r < 13 and size < 30):
                    continue
                cx, cy = self.center(pos)
                pygame.draw.circle(surf, (20, 20, 20), (cx, cy), 3)
                pygame.draw.circle(surf, (250, 250, 250), (cx, cy), 2)
                if r >= 13 and self.mode != "markets":
                    self._label(surf, name, (cx, cy + 9), self.tiny)
        if r >= 13:
            for prov in world.provinces.values():
                if prov.pos in known and (prov.colony or prov.trading_post):
                    cx, cy = self.center(prov.pos)
                    color = (250, 250, 250)
                    if prov.trading_post:
                        pygame.draw.rect(surf, color, (cx - 4, cy - 4, 8, 8), 1)
                    else:
                        pygame.draw.polygon(surf, color, [(cx - 5, cy), (cx, cy - 5), (cx + 5, cy)], 1)
                        pygame.draw.rect(surf, color, (cx - 4, cy, 8, 5), 1)

    def _country_names(self, surf, known):
        world = self.world
        for country in world.countries.values():
            provs = [p for p in world.provinces_of(country.tag) if p.pos in known and not p.colony
                     and not p.trading_post]
            if len(provs) < 3:
                continue
            xs = [self.center(p.pos)[0] for p in provs]
            ys = [self.center(p.pos)[1] for p in provs]
            size = max(10, min(30, int(len(provs) ** 0.5 * self.r * 0.55)))
            font = self.title_fonts.get(size)
            if font is None:
                font = self.title_fonts[size] = pygame.font.SysFont("georgia,timesnewroman,serif", size, bold=True)
            cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
            text = font.render(country.name.upper(), True, (30, 26, 22))
            if text.get_width() > (max(xs) - min(xs)) * 1.6 + 30:
                continue
            surf.blit(text, text.get_rect(center=(cx, cy)))

    def _label(self, surf, text, at, font):
        img = font.render(text, True, (250, 250, 250))
        shadow = font.render(text, True, (10, 10, 10))
        rect = img.get_rect(center=at)
        surf.blit(shadow, rect.move(1, 1))
        surf.blit(img, rect)

    # ----- per frame ------------------------------------------------------------------------
    def draw(self, screen, view_rect, camera, ui):
        world = self.world
        if self.land is not None and not self._warmed and self.r >= LAND_FROM:
            self._warmed = True
            self.warm(camera, view_rect)
        screen.set_clip(view_rect)
        screen.fill(BLACK_FOG, view_rect)
        self._late_labels = []
        self._drawn_labels = []
        self._under_backdrop = set()                      # hexes this frame whose picture is the zoom backdrop's
        self._focus = ui.province.pos if ui.province else None
        self._view_rect, self._cam = view_rect, camera
        self._zoom_backdrop(screen, view_rect, camera)
        if self.r >= LAND_FROM and self.land is not None:
            self._draw_landscape(screen, view_rect, camera)
        elif self.zoom >= TILE_FROM and self.tiles_dir:
            self._draw_tiles(screen, view_rect, camera)
        else:
            screen.blit(self.surface(), (view_rect.x - camera[0], view_rect.y - camera[1]))
            self._capture(screen, view_rect, camera)
        r = self.r
        ox, oy = view_rect.x - camera[0], view_rect.y - camera[1]

        def at(pos):
            x, y = self.center(pos)
            return x + ox, y + oy
        if ui.selected and ui.reach:
            self._movement(screen, at, ui)
        if ui.province:
            pygame.draw.polygon(screen, (255, 214, 70), hex_points(*at(ui.province.pos), r), 2)
        if ui.hover in world.terrain:
            pygame.draw.polygon(screen, (255, 255, 255), hex_points(*at(ui.hover), r), 1)
        self._draw_units(screen, view_rect, at, ui)
        for shade, name, box in self._late_labels:           # the town names over the tokens
            screen.blit(shade, box)
            screen.blit(name, name.get_rect(center=box.center))
        self._late_labels = []
        screen.set_clip(None)

    # ----- ridge crests at the far zooms ------------------------------------------------------
    def _ridge_items(self, known, keep=None):
        """[((a, b), look, is_pass)] of the crest and pass edges of known hexes (a, b: the edge's corners in unit
        points); keep(point pair) may drop the ones off screen."""
        if self.land is None:
            return []
        out = []
        for ha, hb, pts, look, is_pass in self.land.ridges().far_edges():
            if ha in known and hb in known and (keep is None or keep(pts)):
                out.append((pts, look, is_pass))
        return out

    def _far_ridges(self, screen, view_rect, camera):
        """r=13 (the tile art): the relief fold along the ridge crests, over the tiles and under the fog dim."""
        r, m = self.r, self.MARGIN
        ox, oy = view_rect.x - camera[0], view_rect.y - camera[1]

        def px(p):
            return (ox + m + p[0] * r - view_rect.x, oy + m + p[1] * r - view_rect.y)

        def visible(pts):
            x, y = px(pts[0])
            return -2 * r <= x <= view_rect.w + 2 * r and -2 * r <= y <= view_rect.h + 2 * r
        items = self._ridge_items(self.known(), visible)
        if items:
            landscape.draw_far_ridges(screen.subsurface(view_rect), r, self.world.winter(), px, items)

    def _pass_names(self, screen):
        """Pass names at r=34 (political map): a small plate at each pass saddle the player knows, kept clear of the
        town names already drawn, of the other pass names and of the pass hospice."""
        if self.r != 34 or not self.pass_names_on or self.land is None:
            return
        ridges, r = self.land.ridges(), self.r
        known = self.known()
        view_rect, cam = self._view_rect, self._cam
        ox, oy = view_rect.x - cam[0] + self.MARGIN, view_rect.y - cam[1] + self.MARGIN
        taken = [box for _, box in self._drawn_labels]
        seen = set()
        for name, pos, other in ridges.pass_sites():
            if name in seen or pos not in known or other not in known:
                continue
            seen.add(name)
            (ax, ay), (bx, by) = landscape.hex_centre(pos), landscape.hex_centre(other)
            mx, my = ox + (ax + bx) / 2 * r, oy + (ay + by) / 2 * r
            if not view_rect.inflate(60, 40).collidepoint(mx, my):
                continue
            shade, text = self._label_surfaces(name)
            w, h = shade.get_size()
            avoid = list(taken)
            hosp = ridges.hospice.get(name)
            if hosp is not None:                      # the hospice stands near the hex centre: keep the plate off it
                hx, hy = landscape.hospice_spot(*hosp)
                avoid.append(pygame.Rect(round(ox + hx * r) - 24, round(oy + hy * r) - 40, 48, 44))
            for dy in (0, -h - 4, h + 4, -2 * h - 8):
                box = pygame.Rect(round(mx - w / 2), round(my - h / 2 + dy), w, h)
                if not any(box.inflate(6, 4).colliderect(o) for o in avoid):
                    screen.blit(shade, box)
                    screen.blit(text, text.get_rect(center=box.center))
                    taken.append(box)
                    self._drawn_labels.append((("pass", name), box))
                    break

    def _capture(self, screen, view_rect, camera):
        """Keep this frame's map (a plain copy, about 0.2 ms) in case the next frame is at another zoom."""
        if self._frame is None or self._frame.get_size() != view_rect.size:
            self._frame = pygame.Surface(view_rect.size)
        self._frame.blit(screen, (0, 0), view_rect)
        self._frame_at = (self.r, (camera[0], camera[1]))

    def _zoom_backdrop(self, screen, view_rect, camera):
        """After a zoom change the new zoom's hexes are built a few at a time (nearest the centre first), which shows as
        a wave of flat old-style tiles turning into landscape. So the last frame, scaled to the new zoom, is drawn
        first; the hexes built so far go over it and the unbuilt ones simply stay as the old picture shows them."""
        r = self.r
        if self._frame_at is not None and self._frame_at[0] != r and r >= LAND_FROM and self._frame is not None:
            old_r, cam = self._frame_at
            k = r / old_r
            self._frame_at = (r, cam)                    # (taken once per zoom change)
            self._backdrop = None
            if k <= BACKDROP_MAX_K:                      # a bigger jump would be a blur of a few pixels
                m = self.MARGIN
                # the part of the old frame that lands in the new view, and only that part is scaled
                want = pygame.Rect(0, 0, 0, 0)
                want.x = int(m + (camera[0] - m) / k - cam[0]) - 2
                want.y = int(m + (camera[1] - m) / k - cam[1]) - 2
                want.w, want.h = int(view_rect.w / k) + 5, int(view_rect.h / k) + 5
                src = want.clip(self._frame.get_rect())
                if src.w > 8 and src.h > 8:
                    surf = pygame.transform.smoothscale(self._frame.subsurface(src),
                                                        (max(1, round(src.w * k)), max(1, round(src.h * k))))
                    top = (m + (cam[0] + src.x - m) * k, m + (cam[1] + src.y - m) * k)
                    self._backdrop = (surf, top, time.perf_counter() + BACKDROP_S, r)
        bd = self._backdrop
        if bd is None:
            return
        surf, top, until, bd_r = bd
        if bd_r != r or time.perf_counter() > until:
            self._backdrop = None
            return
        screen.blit(surf, (view_rect.x + top[0] - camera[0], view_rect.y + top[1] - camera[1]))

    def _backdrop_covers(self, cx, cy, view_rect):
        """Does the zoom backdrop cover the hex at the screen point (cx, cy)? (Then an unbuilt hex is left to it.)"""
        bd = self._backdrop
        if bd is None:
            return False
        surf, top, _, _ = bd
        x, y = cx - view_rect.x + self._cam[0] - top[0], cy - view_rect.y + self._cam[1] - top[1]
        m = self.r + 2                                    # the whole hex, not just its centre
        return m <= x < surf.get_width() - m and m <= y < surf.get_height() - m

    def _draw_units(self, screen, view_rect, at, ui):
        """The figures on the map. While a replay runs (campaign/replay.py) the stacks it walks are drawn where it says,
        not where the world has them: waiting ones on their first hex (with the units that stay there), walking ones
        between two hexes."""
        world, player = self.world, self.world.player
        group = getattr(ui, "group", [])
        held, walking, away = {}, [], set()        # id -> hex; (ids, screen point); every id the replay draws
        for pose in (ui.replay.poses() if getattr(ui, "replay", None) else ()):
            away.update(pose.ids)
            if pose.f == 0 and pose.shown:
                held.update({uid: pose.a for uid in pose.ids})
            elif pose.f > 0:
                (x0, y0), (x1, y1) = at(pose.a), at(pose.b)
                walking.append((pose.ids, (x0 + (x1 - x0) * pose.f, y0 + (y1 - y0) * pose.f)))
        stacks = {}
        for unit in world.units:
            if unit.carrier is None and (unit.id not in away or unit.id in held):
                stacks.setdefault(held.get(unit.id, unit.pos), []).append(unit)
        for pos, stack in stacks.items():
            if player and stack[0].owner != player and pos not in world.visible and stack[0].id not in held:
                continue
            x, y = at(pos)
            if view_rect.inflate(40, 40).collidepoint(x, y):
                top = next((u for u in stack if u.kind.war), stack[0])
                self._draw_stack(screen, stack, top, (x, y), any(u in group for u in stack))
        for ids, point in walking:
            stack = [u for u in world.units if u.id in ids]
            if stack:
                self._draw_stack(screen, stack, max(stack, key=lambda u: (u.kind.war, u.kind.naval, u.id)), point, any(u in group for u in stack))

    def _draw_stack(self, screen, stack, top, point, selected):
        if self.zoom >= TILE_FROM and self.tiles_dir:
            self._diorama(screen, stack, top, point, selected)
        else:
            self._token(screen, top, point, selected, len(stack))

    # ----- tile art (zoomed in) ------------------------------------------------------------
    def sprite(self, path):
        key = (path, self.r)
        if key not in self._sprites and isinstance(path, tuple):
            _, good, level, variant = path
            img = goodsart.good_tile(good, level, self.tiles_dir, variant)
            self._sprites[key] = self._seamless(img)
        if key not in self._sprites:
            if path.startswith("art:"):
                _, name, variant = path.split(":")
                if (name, variant) not in self._art:
                    self._art[(name, variant)] = art.make_tile(name, self.tiles_dir, int(variant))
                image = self._art[(name, variant)]
            else:
                image = pygame.image.load(os.path.join(self.tiles_dir, path)).convert_alpha()
            self._sprites[key] = self._seamless(image)
        return self._sprites[key]

    def _seamless(self, image):
        """A 120 x 140 tile picture scaled to this zoom's sprite size so that neighbours join without a gap: the pack's
        tiles have antialiased, half-transparent edge pixels (and blits land on whole pixels, the hex spacing does not),
        so the picture is drawn a little large on a rim of its own colour and clipped to a hex grown to the sprite's
        full width."""
        r = self.r
        w, h = int(round(r * SQRT3)) + 1, int(round(r * SPRITE_H)) + 1
        big = wfctiles.scale_tile(image, round(w * 1.06), round(h * 1.06))
        poly = hex_points(w / 2, h / 2, (w + 2) / SQRT3)
        out = pygame.Surface((w, h), pygame.SRCALPHA)
        rim = pygame.transform.average_color(big, big.get_rect().inflate(-big.get_width() // 3, -big.get_height() // 3))
        pygame.draw.polygon(out, tuple(rim[:3]) + (255,), poly)
        out.blit(big, ((w - big.get_width()) // 2, (h - big.get_height()) // 2))
        mask = landscape.clip_mask((w, h))
        pygame.draw.polygon(mask, (255, 255, 255, 255), poly)
        out.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        return out

    def overlay(self, name):
        key = (name, self.r)
        if key not in self._overlays:
            r = self.r
            surf = pygame.Surface((int(r * SQRT3) + 2, int(2 * r) + 2), pygame.SRCALPHA)
            cx, cy = surf.get_width() / 2, surf.get_height() / 2
            if name in ("ocean", "shallow"):
                pygame.draw.polygon(surf, (38, 92, 158) if name == "ocean" else (62, 130, 190),
                                    hex_points(cx, cy, r + 0.6))
                for x, y in ((-0.45, -0.2), (0.05, 0.25), (0.2, -0.45)):
                    box = (cx + x * r, cy + y * r, r * 0.35, r * 0.2)
                    pygame.draw.arc(surf, (110, 160, 215), box, 0.3, 2.8, max(1, r // 16))
            elif name == "frost":
                for i in range(6):
                    a = math.radians(i * 67 + 20)
                    pygame.draw.circle(surf, (255, 255, 255), (cx + math.cos(a) * r * 0.5, cy + math.sin(a) * r * 0.45),
                                       max(1, r // 14))
            elif name == "black":
                pygame.draw.polygon(surf, BLACK_FOG, hex_points(cx, cy, r + 0.8))
            self._overlays[key] = surf
        return self._overlays[key]

    def tile_sprite(self, prov):
        """The base picture of a province: its developed goods tile, a native camp, or the bare land.
        Towns, castles, coasts, rivers and roads are drawn on top as one edge-matched overlay."""
        if prov.works and prov.good in WORKS and not (prov.settlement or prov.castle):
            return ("good", prov.good, min(5, prov.works), self._variant(prov.pos))
        if prov.owner is None and prov.natives >= 2.5 and (prov.pos[0] * 7 + prov.pos[1] * 3) % 5 == 0:
            return NATIVE_VILLAGE_SPRITE
        return self.land_sprite(prov)

    @staticmethod
    def _variant(pos):
        return ((pos[0] * 73856093) ^ (pos[1] * 19349663)) % 3

    @staticmethod
    def building(prov):
        return bool(prov.castle or prov.settlement or (prov.works and prov.good in WORKS))

    # ----- edge sockets: which of a hex's six edges a coast, river or road crosses ------------------
    @staticmethod
    def _edge_sockets(world):
        """{pos: (sea edges, river edges, river mouth?, road edges)}; edge e is the e-th neighbors(pos)."""
        rivers, roads = {}, {}

        def link(table, a, b):
            near_a, near_b = list(neighbors(a)), list(neighbors(b))
            if b in near_a and a in near_b:
                table.setdefault(a, set()).add(near_a.index(b))
                table.setdefault(b, set()).add(near_b.index(a))

        river_at = getattr(world, "river_at", {})
        for name, path in getattr(world, "rivers", {}).items():
            for a, b in zip(path, path[1:]):
                link(rivers, a, b)
            end = path[-1]                      # a tributary flows into the river next to it
            for n in neighbors(end):
                if river_at.get(n) not in (None, name) and n not in path:
                    link(rivers, end, n)
                    break
        for path in getattr(world, "road_paths", []):
            for a, b in zip(path, path[1:]):
                link(roads, a, b)
        out = {}
        for pos in world.provinces:
            near = list(neighbors(pos))
            sea = frozenset(e for e, n in enumerate(near) if world.terrain.get(n) == "ocean")
            river = frozenset(rivers.get(pos, ()))
            mouth = bool(river) and bool(sea) and len(river) == 1
            road = frozenset(roads.get(pos, ()))
            if sea or river or road:
                out[pos] = (sea, river, mouth, road)
        return out

    def overlay_desc(self, prov, bare=False):
        """The wfctiles description of what lies on top of this province's base picture (or None)."""
        sea, river, mouth, road = self._edges.get(prov.pos, (frozenset(), frozenset(), False, frozenset()))
        town = castle = 0
        if not bare:
            if prov.settlement:
                town = {1: 2, 2: 4 if prov.castle else 3, 3: 6 if prov.pop >= 60 else 5}[prov.settlement]
                if prov.settlement == 1 and prov.castle:
                    town, castle = 0, prov.castle
            elif prov.castle:
                castle = prov.castle
        else:
            road = frozenset()
        if road and self.land is not None:
            road = road - frozenset(self.land.ridges().crest.get(prov.pos, ()))      # none over a crest
        if not (sea or river or road or town or castle):
            return None
        return wfctiles.TileDesc(sea=sea, river=river - sea, mouth=mouth, road=road - sea,
                                 paved=(road - sea) if town >= 3 else frozenset(), town=town, castle=castle,
                                 variant=self._variant(prov.pos))

    def overlay_img(self, desc):
        key = ("wfc", desc, self.r)
        if key not in self._sprites:
            base = self._overlay_base.get(desc)
            if base is None:
                if self._gen_budget <= 0:
                    return None                 # drawn in a later frame: new overlays are made a few at a time
                self._gen_budget -= 1
                base = self._overlay_base[desc] = wfctiles.overlay(desc)
            self._sprites[key] = wfctiles.scale_tile(base, int(round(self.r * SQRT3)) + 1,
                                                     int(round(self.r * SPRITE_H)) + 1)
        return self._sprites[key]

    def sea_img(self, pos):
        key = ("sea", self._variant(pos), self.r)
        if key not in self._sprites:
            base = wfctiles.sea_tile("sea", self._variant(pos))
            self._sprites[key] = wfctiles.scale_tile(base, int(round(self.r * SQRT3)) + 1,
                                                     int(round(self.r * SPRITE_H)) + 1)
        return self._sprites[key]

    def decoration(self, kind, seed):
        key = ("deco", kind, seed % 4, self.r)
        if key not in self._sprites:
            img = art.decoration(kind, seed % 4, self.tiles_dir)
            w = int(round(self.r * SQRT3)) + 1
            self._sprites[key] = pygame.transform.smoothscale(img, (w, int(round(self.r * SPRITE_H)) + 1))
        return self._sprites[key]

    def decorations_for(self, prov):
        """Extra life on undeveloped open land: a few trees, rocks, fields or a hamlet."""
        col, row = prov.pos
        h = (col * 73856093 ^ row * 19349663) & 0xFFFF
        out = []
        if not self.building(prov) and prov.pos not in self._edges and prov.terrain in ("plains", "steppe", "savanna"):
            if h % 6 == 0:
                out.append("trees")
            elif h % 9 == 1:
                out.append("rocks")
            elif prov.owner and h % 7 == 2:
                out.append("fields")
            elif prov.owner and prov.pop > 10 and h % 11 == 3:
                out.append("hamlet")
        return out, h

    def _draw_tiles(self, screen, view_rect, camera):
        world = self.world
        r = self.r
        w = r * SQRT3
        known = self.known()
        visible = world.visible
        ox, oy = view_rect.x - camera[0], view_rect.y - camera[1]
        row0 = max(0, int((camera[1] - self.MARGIN) / (1.5 * r)) - 1)
        row1 = min(world.rows - 1, int((camera[1] + view_rect.h - self.MARGIN) / (1.5 * r)) + 1)
        col0 = max(0, int((camera[0] - self.MARGIN) / w) - 1)
        col1 = min(world.cols - 1, int((camera[0] + view_rect.w - self.MARGIN) / w) + 1)
        bare = self.mode == "terrain" or (self.mode == "goods" and self.goods_view == "deposits")
        shown, hidden, dimmed = [], [], []
        self._gen_budget = 24

        def blit(img, cx, cy):
            screen.blit(img, (cx - img.get_width() / 2, cy - img.get_height() / 2))

        for row in range(row0, row1 + 1):
            for col in range(col0, col1 + 1):
                pos = (col, row)
                cx, cy = self.center(pos)
                cx, cy = cx + ox, cy + oy
                if pos not in known:
                    hidden.append((cx, cy))
                    continue
                prov = world.provinces.get(pos)
                if prov is None:
                    img = self.sea_img(pos) if world.is_sea(pos) else self.sprite(TERRAIN_SPRITES["lake"][0])
                    blit(img, cx, cy)
                else:
                    blit(self.sprite(self.land_sprite(prov) if bare else self.tile_sprite(prov)), cx, cy)
                    desc = self.overlay_desc(prov, bare)
                    if desc is not None:
                        img = self.overlay_img(desc)
                        if img is not None:
                            blit(img, cx, cy)
                    shown.append((prov, cx, cy))
                if world.player and pos not in visible:
                    dimmed.append((cx, cy))
        if not bare:
            for prov, cx, cy in shown:
                kinds, h = self.decorations_for(prov)
                for kind in kinds:
                    blit(self.decoration(kind, h), cx, cy)

        # Winter frost in the north.
        if world.turn % 4 == 0 and not bare:
            frost = self.overlay("frost")
            north = [(cx, cy) for prov, cx, cy in shown if self.lat[prov.pos] > 42]
            self._tint(screen, [(FROST, cx, cy) for cx, cy in north])
            for cx, cy in north:
                blit(frost, cx, cy)
        if r == 13:
            self._far_ridges(screen, view_rect, camera)
        self._capture(screen, view_rect, camera)
        self._tint(screen, [(DIM, cx, cy) for cx, cy in dimmed])
        black = self.overlay("black")
        for cx, cy in hidden:
            blit(black, cx, cy)
        if self.mode != "political":
            self._mode_layer(screen, shown)
            self._owner_borders(screen, shown, MODE_BORDERS)
            return
        self._owner_washes(screen, shown)
        self._political_marks(screen, shown)

    def _owner_washes(self, screen, shown):
        """The owner's tint of each province (under the objects on the landscape zooms)."""
        world = self.world
        under = self._under_backdrop
        self._tint(screen, [(world.countries[prov.owner].color + (34,), cx, cy) for prov, cx, cy in shown
                            if prov.owner and (cx, cy) not in under])

    def _tint(self, screen, items, cache=True):
        """Translucent hexes [(rgba, cx, cy)] over the map, drawn on one layer and blitted once. A tint blitted hex by
        hex leaves a faint line (or a doubled one) along every shared edge, where the blits are rounded to whole
        pixels, which reads as a grid even when the grid is off; here each hex is a little larger than its cell and
        the polygons replace each other where they meet, so the tint is one even sheet."""
        if not items:
            return
        clip = screen.get_clip() or screen.get_rect()
        layer = self._tint_layers.get(clip.size) if cache else None
        if layer is None:
            layer = pygame.Surface(clip.size, pygame.SRCALPHA)
            if cache:
                self._tint_layers[clip.size] = layer
        else:
            layer.fill((0, 0, 0, 0))
        r = self.r
        sprites = self._tint_sprites
        blit = layer.blit
        ox, oy = clip.x + r + 2, clip.y + r + 2           # the sprite is 2 * (r + 2) square, centred on the hex
        for rgba, cx, cy in items:
            spr = sprites.get((rgba, r))
            if spr is None:
                n = int(2 * r) + 5
                spr = sprites[(rgba, r)] = pygame.Surface((n, n), pygame.SRCALPHA)
                pygame.draw.polygon(spr, rgba, hex_points(n / 2, n / 2, r + 1.0))
            # MAX, not a blend: where two hexes overlap the tint stays what one hex gives (blits off the layer clip)
            blit(spr, (cx - ox, cy - oy), special_flags=pygame.BLEND_RGBA_MAX)
        screen.blit(layer, clip.topleft)

    def _owner_borders(self, screen, shown, alpha=255):
        """The owner borders of the shown provinces. alpha < 255 draws them fainter, through a layer (the terrain, goods
        and markets modes keep the borders so the player can see where a country ends)."""
        world, r = self.world, self.r
        width = max(2, r // 8)
        if self._pm_ver != world.version:
            self._pm_edges.clear()
            self._pm_ver = world.version
        target, draw_line = screen, pygame.draw.line
        clip = screen.get_clip() or screen.get_rect()
        if alpha < 255:
            target = self._tint_layers.get(("borders", clip.size))      # (get, then create: setdefault would build a
            if target is None:                                           # full-view surface every frame)
                target = self._tint_layers[("borders", clip.size)] = pygame.Surface(clip.size, pygame.SRCALPHA)
        ox, oy = (clip.x, clip.y) if alpha < 255 else (0, 0)
        box = None
        for prov, cx, cy in shown:
            if not prov.owner:
                continue
            segs = self._pm_edges.get((prov.pos, r))
            if segs is None:                    # the outline's segments as offsets from the hex centre
                color = world.countries[prov.owner].color
                dark, light = tint(color, -0.35), tint(color, 0.35)
                outer = hex_points(0, 0, r - width / 2 - 1)
                inner = hex_points(0, 0, r - width * 1.6 - 1)
                near = list(neighbors(prov.pos))
                segs = []
                for edge in range(6):
                    other = world.provinces.get(near[(6 - edge) % 6])
                    if other is None or other.owner != prov.owner:
                        a, b = (edge + 1) % 6, edge
                        segs.append((dark, outer[b], outer[a], light, inner[b], inner[a]))
                self._pm_edges[(prov.pos, r)] = segs
            lw = max(1, width // 2)
            x, y = cx - ox, cy - oy
            for dark, ob, oa, light, ib, ia in segs:
                if alpha < 255:
                    dark, light = dark + (alpha,), light + (alpha,)
                draw_line(target, dark, (x + ob[0], y + ob[1]), (x + oa[0], y + oa[1]), width)
                draw_line(target, light, (x + ib[0], y + ib[1]), (x + ia[0], y + ia[1]), lw)
            if alpha < 255 and segs:
                if box is None:
                    box = [x - r, y - r, x + r, y + r]
                else:
                    box = [min(box[0], x - r), min(box[1], y - r), max(box[2], x + r), max(box[3], y + r)]
        if alpha < 255 and box is not None:
            area = pygame.Rect(int(box[0]) - 2, int(box[1]) - 2, int(box[2] - box[0]) + 5,
                               int(box[3] - box[1]) + 5).clip(target.get_rect())
            screen.blit(target, (clip.x + area.x, clip.y + area.y), area)
            target.fill((0, 0, 0, 0), area)               # clean for the next frame (only the part that was drawn on)

    def _political_marks(self, screen, shown):
        """Owner borders, controller stripes, goods dots, town names and capital flags (over the objects)."""
        world, r = self.world, self.r
        plan = self._town_labels()
        self._owner_borders(screen, shown)
        for prov, cx, cy in shown:
            if prov.controller and prov.controller != prov.owner:
                ctrl = world.countries[prov.controller].color
                for k in (-0.4, 0.0, 0.4):
                    pygame.draw.line(screen, ctrl, (cx - r * 0.5 + k * r, cy + r * 0.45), (cx + k * r + r * 0.1, cy - r * 0.45), 3)
            if prov.works and (prov.castle or prov.settlement >= 2):
                for i in range(prov.works):        # works hidden under a town: show their level as dots
                    dot = (cx - r * 0.5 + i * r * 0.22, cy + r * 0.62)
                    pygame.draw.circle(screen, (20, 20, 20), dot, max(3, r // 9))
                    pygame.draw.circle(screen, GOODS[prov.good].color, dot, max(2, r // 9 - 1))
            hit = plan.get(prov.pos)
            if hit is not None:                     # a town name the placement kept (see _town_labels)
                dx, dy, shade, name = hit
                box = pygame.Rect(round(cx + dx), round(cy + dy), shade.get_width(), shade.get_height())
                self._drawn_labels.append((prov.pos, box))
                if r < LAND_FROM:                   # tokens stand on the hex centre and would cover the name
                    self._late_labels.append((shade, name, box))
                else:
                    screen.blit(shade, box)
                    screen.blit(name, name.get_rect(center=box.center))
            if prov.owner and world.countries[prov.owner].capital == prov.pos:
                self._flag(screen, (cx + r * 0.35, cy - r * 0.85), world.countries[prov.owner].color)
        self._pass_names(screen)

    def _label_surfaces(self, name):
        """The shade box and the text of a town name at this zoom (rendered once)."""
        key = (name, self.r)
        lab = self._labels.get(key)
        if lab is None:
            text = self.small.render(name, True, (245, 245, 245))
            shade = pygame.Surface(text.get_rect().inflate(8, 2).size, pygame.SRCALPHA)
            shade.fill((0, 0, 0, 150))
            lab = self._labels[key] = (shade, text)
        return lab

    def _town_labels(self):
        """The town names of the political map at this zoom, placed over the whole known map:
        {pos: (dx, dy, shade, text)}, the top left of the name's box as an offset from the hex centre.
        Order: the player's capital, then the selected province (both always drawn), then capitals, cities and towns,
        bigger towns first. Each name tries the spot below the hex (where it always was), then above, right and left;
        a name that fits in none is skipped (the two always-drawn ones are placed anyway). Placement depends on the
        zoom, the fog stamp (world version, player, explored hexes) and the focus only, so it is cached on those and
        is the same whatever the window shows."""
        world, r = self.world, self.r
        key = (r, self.fog_stamp(), self._focus)
        if key == self._label_key:
            return self._label_plan
        t0 = time.perf_counter()
        known = self.known()
        capitals = {c.capital for c in world.countries.values()}
        home = world.countries.get(world.player)
        home_capital = home.capital if home else None
        cands = []
        for pos, prov in world.provinces.items():
            if pos not in known or not (prov.settlement >= 2 or prov.castle):
                continue
            if prov.name.startswith(("near ", "New ")) or "countryside" in prov.name or " lands" in prov.name:
                continue
            if r < 20 and not prov.city:
                continue
            if pos == home_capital:
                group = 0
            elif pos == self._focus:
                group = 1
            else:
                group = 2
            rank = 0 if pos in capitals else (1 if prov.city or prov.settlement >= 3 else 2)
            cands.append((group, rank, -prov.pop, pos, prov))
        cands.sort(key=lambda c: c[:4])
        cell = 64
        grid, plan, skipped = {}, {}, 0
        hw = r * SQRT3 / 2

        def cells(rect):
            probe = rect.inflate(6, 6)                     # keeps a 3 px gap between names
            for gx in range(probe.left // cell, probe.right // cell + 1):
                for gy in range(probe.top // cell, probe.bottom // cell + 1):
                    yield (gx, gy)

        for group, _, _, pos, prov in cands:
            cx, cy = self.center(pos)
            shade, text = self._label_surfaces(prov.name)
            w, h = shade.get_size()
            spots = ((cx - w / 2, cy + r * 0.72),                 # below the hex: the old spot
                     (cx - w / 2, cy - r * 0.72 - h),             # above
                     (cx + hw + 2, cy - h / 2),                   # right
                     (cx - hw - 2 - w, cy - h / 2))               # left
            spot = None
            for x, y in spots:
                rect = pygame.Rect(round(x), round(y), w, h)
                probe = rect.inflate(6, 6)
                if not any(probe.colliderect(other) for c in cells(rect) for other in grid.get(c, ())):
                    spot = (x, y, rect)
                    break
            if spot is None:
                if group == 2:
                    skipped += 1
                    continue
                x, y = spots[0]
                spot = (x, y, pygame.Rect(round(x), round(y), w, h))
            x, y, rect = spot
            for c in cells(rect):
                grid.setdefault(c, []).append(rect)
            plan[pos] = (x - cx, y - cy, shade, text)
        self._label_key, self._label_plan = key, plan
        self._label_stats = {"placed": len(plan), "skipped": skipped, "ms": (time.perf_counter() - t0) * 1000}
        return plan

    # ----- landscape art (close zooms) -------------------------------------------------------
    @staticmethod
    def _blit_centre(screen, img, cx, cy):
        screen.blit(img, (cx - img.get_width() / 2, cy - img.get_height() / 2))

    def _visible_range(self, camera, view_rect):
        """(row0, row1, col0, col1): the hexes whose centres may be on view_rect, clipped to the map."""
        return self._range_at(camera, view_rect, self.r)

    def _range_at(self, camera, view_rect, r, margin=0):
        """_visible_range at hex radius r, with `margin` more rows and columns on every side."""
        world = self.world
        w = r * SQRT3
        row0 = max(0, int((camera[1] - self.MARGIN) / (1.5 * r)) - 1 - margin)
        row1 = min(world.rows - 1, int((camera[1] + view_rect.h - self.MARGIN) / (1.5 * r)) + 1 + margin)
        col0 = max(0, int((camera[0] - self.MARGIN) / w) - 1 - margin)
        col1 = min(world.cols - 1, int((camera[0] + view_rect.w - self.MARGIN) / w) + 1 + margin)
        return row0, row1, col0, col1

    def warm(self, camera, view_rect, budget_ms=WARM_MS):
        """Start-up: builds the ground composites, object sprites and object lists of the view's own hexes at the
        current landscape zoom, nearest the view centre first, until budget_ms is spent. The rest is left to the idle
        prefetch. Runs once, on the first landscape draw. Sets warm_ms."""
        land, r = self.land, self.r
        budget = FrameBudget(budget_ms).start()
        land.warm_sources()
        known = self.known()
        season = land.season_now()
        row0, row1, col0, col1 = self._range_at(camera, view_rect, r)
        cx = camera[0] + view_rect.w / 2
        cy = camera[1] + view_rect.h / 2
        todo = []
        for row in range(row0, row1 + 1):
            for col in range(col0, col1 + 1):
                x, y = self.center((col, row))
                todo.append(((x - cx) ** 2 + (y - cy) ** 2, (col, row)))
        todo.sort()
        for _, pos in todo:
            if not budget.fits():
                break
            if pos not in known:
                continue
            land.prepare(pos, r, season)
            land.ground(pos, r, season)
            land.make_sprites(pos, r, season)
            land.objects(pos, r, season)
        self.warm_ms = (time.perf_counter() - budget.t0) * 1000

    def _draw_landscape(self, screen, view_rect, camera):
        """The close zooms, in draw order: ground composites, the faint grid, fog under the objects, the washes of
        the view, ONE object pass over the visible hexes (plus one margin row and column, sorted by base y), the fog
        dim, then the borders, labels and chips of the view."""
        world, r, land = self.world, self.r, self.land
        season = land.season_now()
        known, visible = self.known(), world.visible
        ox, oy = view_rect.x - camera[0], view_rect.y - camera[1]
        rows = self._visible_range(camera, view_rect)
        self._still = self._last_cam == tuple(camera) and self._last_r == r
        if self._last_cam is not None and tuple(camera) != self._last_cam:
            self._pan = (camera[0] - self._last_cam[0], camera[1] - self._last_cam[1])
        self._last_cam, self._last_r = tuple(camera), r
        bare = self.mode == "terrain" or (self.mode == "goods" and self.goods_view == "deposits")
        shown, hidden, dimmed, land_hexes = [], [], [], []
        self._gen_budget = 0                       # wfc overlays the fallback may build this frame (see _landscape_ground)
        self._budget.start(LAND_BUILD_MS)
        self._frame_builds, self._frame_objs = 0, 0
        self._frame_sprites, self._frame_ov = 0, 0
        if self._still:
            self._fill_centre_first(camera, view_rect, rows, known, season)
        for row in range(rows[0], rows[1] + 1):
            for col in range(rows[2], rows[3] + 1):
                pos = (col, row)
                cx, cy = self.center(pos)
                cx, cy = cx + ox, cy + oy
                if pos not in known:
                    hidden.append((cx, cy))
                    continue
                prov = world.provinces.get(pos)
                self._landscape_ground(screen, pos, cx, cy, prov, season, bare)
                if prov is not None:
                    shown.append((prov, cx, cy))
                if world.is_land(pos):
                    land_hexes.append((cx, cy))
                if world.player and pos not in visible:
                    dimmed.append((cx, cy))
        if self.grid_on:
            grid = land.grid(r)
            for cx, cy in land_hexes:
                self._blit_centre(screen, grid, cx, cy)
        black = self.overlay("black")
        for cx, cy in hidden:
            self._blit_centre(screen, black, cx, cy)
        if self.mode != "political":
            self._mode_layer(screen, shown, chips=False)
        else:
            self._owner_washes(screen, shown)
        if not bare:
            self._object_pass(screen, view_rect, (ox, oy), rows, known, season)
        self._prefetch(view_rect, camera, rows, season)
        self._capture(screen, view_rect, camera)
        if self._backdrop is not None and self._filled == (tuple(camera), r, season, world.version, self.mode):
            self._backdrop = None                        # everything of the view is built: the stand-in goes
        self._tint(screen, [(DIM, cx, cy) for cx, cy in dimmed])
        if self.mode != "political":
            self._mode_layer(screen, shown, washes=False)
            self._owner_borders(screen, shown, MODE_BORDERS)
            return
        self._political_marks(screen, shown)

    def _may_build(self, made, budget=None):
        """May the frame build one more hex of a kind? A still frame: while its builds total under LAND_STILL_MS. A
        moving frame: the first of a kind always goes, then only while in time (budget: the kind's own slice)."""
        if self._still:
            return self._budget.spent < LAND_STILL_MS / 1000
        return made == 0 or (budget or self._budget).fits()

    def _fill_centre_first(self, camera, view_rect, rows, known, season):
        """Still frame: builds the view's hexes nearest the centre first, until LAND_STILL_MS of building is spent.
        The drawing order is unchanged; this only decides which composites and object lists are ready."""
        r = self.r
        done = (tuple(camera), r, season, self.world.version, self.mode)
        if self._filled == done:                                 # everything of this view is already built
            return
        if self._fill_key != done:
            self._fill_key, self._fill_seen = done, set()
        seen = self._fill_seen
        cx, cy = camera[0] + view_rect.w / 2, camera[1] + view_rect.h / 2
        todo = []
        for row in range(rows[0], rows[1] + 1):
            for col in range(rows[2], rows[3] + 1):
                x, y = self.center((col, row))
                todo.append(((x - cx) ** 2 + (y - cy) ** 2, (col, row)))
        todo.sort()
        for _, pos in todo:
            if self._budget.spent >= LAND_STILL_MS / 1000:
                return
            if pos in known and pos not in seen:
                self._build_hex(pos, r, season)
                seen.add(pos)
        self._filled = done

    def _build_hex(self, pos, r, season):
        """One hex's composite and object list, the first-use work first; the time goes to the frame budget's `spent`."""
        land = self.land
        t = time.perf_counter()
        if land.ground(pos, r, season, build=False) is None:
            land.prepare(pos, r, season)
            land.ground(pos, r, season)
        if land.objects(pos, r, season, build=False) is None:
            land.make_sprites(pos, r, season)
            land.objects(pos, r, season)
        self._budget.spend(t)

    def _landscape_ground(self, screen, pos, cx, cy, prov, season, bare):
        """One hex's ground: its baked composite if built (new ones while the frame has LAND_BUILD_MS: first the
        hex's overlay and picture, then the composite), else the sprite."""
        world, land = self.world, self.land
        img = land.ground(pos, self.r, season, build=False)
        if img is not None:
            self._blit_centre(screen, img, cx, cy)
            return
        in_time = self._budget.fits()
        if self._may_build(self._frame_builds):
            t = time.perf_counter()
            if land.prepare(pos, self.r, season):
                self._frame_ov += 1
            n0 = land.builds
            img = land.ground(pos, self.r, season)
            self._frame_builds += land.builds - n0
            self._budget.spend(t)
        if img is not None:
            self._blit_centre(screen, img, cx, cy)
            return
        if prov is None:
            img = self.sea_img(pos) if world.is_sea(pos) else self.sprite(TERRAIN_SPRITES["lake"][0])
            self._blit_centre(screen, img, cx, cy)
            return
        if self._backdrop is not None and self._backdrop_covers(cx, cy, self._view_rect):
            self._under_backdrop.add((cx, cy))
            return                                       # the zoom's stand-in picture shows here until this hex is built
        self._blit_centre(screen, self.sprite(self.land_sprite(prov) if bare else self.tile_sprite(prov)), cx, cy)
        desc = self.overlay_desc(prov, bare)
        if desc is not None:
            self._gen_budget = 1 if in_time else 0           # a new wfc overlay costs ~10 ms: only inside the budget
            img = self.overlay_img(desc)
            if img is not None:
                self._blit_centre(screen, img, cx, cy)

    def _objects_of(self, pos, r, season, build):
        """The object list of a hex (None if not built and build is False), counting the builds of this frame: first
        its sprites that do not exist yet (make_sprites), then the list."""
        land = self.land
        objs = land.objects(pos, r, season, build=False)
        if objs is not None or not build:
            return objs
        t = time.perf_counter()
        n0 = land.sprite_builds
        land.make_sprites(pos, r, season)
        self._frame_sprites += land.sprite_builds - n0
        n0 = land.object_builds
        objs = land.objects(pos, r, season)
        self._frame_objs += land.object_builds - n0
        self._budget.spend(t)
        return objs

    def _object_pass(self, screen, view_rect, origin, rows, known, season):
        """Every object of the known hexes in the view, plus one margin row and column, back to front by base y.
        A hex whose object list is not built yet (the frame's time is used up) is left out of this frame and
        appears in a later one, or in the idle prefetch."""
        world, r = self.world, self.r
        ox, oy = origin
        row0, row1, col0, col1 = rows[0] - 1, rows[1] + 1, rows[2] - 1, rows[3] + 1
        objs_slice = FrameBudget(LAND_BUILD_MS).start()          # the object lists get their own slice of time
        items = []
        vl, vt, vr, vb = view_rect.left, view_rect.top, view_rect.right, view_rect.bottom
        for row in range(max(0, row0), min(world.rows - 1, row1) + 1):
            for col in range(max(0, col0), min(world.cols - 1, col1) + 1):
                pos = (col, row)
                if pos not in known:
                    continue
                build = self._may_build(self._frame_objs, objs_slice)
                objs = self._objects_of(pos, r, season, build)
                if objs is None:
                    continue
                cx, cy = self.center(pos)
                cx, cy = cx + ox, cy + oy
                for surf, dx, dy, sort_y in objs:
                    w, h = surf.get_size()
                    x = int(round(cx + dx - w / 2))
                    y = int(round(cy + dy - h + 1))
                    if x < vr and x + w > vl and y < vb and y + h > vt:
                        items.append((cy + sort_y, x, y, surf))
        items.sort(key=lambda item: item[0])
        for _, x, y, surf in items:
            screen.blit(surf, (x, y))

    def _prefetch(self, view_rect, camera, rows, season):
        """Idle time: build the composites and object lists of the ring of hexes just beyond the view (ahead of the
        last pan first), then of the view's middle at the neighbouring landscape zoom, so a zoom switch or a pan is
        already warm. Stops at LAND_IDLE_MS of the frame (a panning frame that is not already late gets
        PREFETCH_MIN_MS from now), and never builds what is already built. The plan is kept between frames, and a
        build is only started if at least half of it fits in the time left."""
        world, land = self.world, self.land
        now = time.perf_counter()
        idle = FrameBudget(LAND_IDLE_MS).start(t0=self._budget.t0)
        if self._pan != (0.0, 0.0) and now - self._budget.t0 < PREFETCH_LATE_MS / 1000:
            idle.extend(now, PREFETCH_MIN_MS)
        if not idle.fits(now=now):
            return
        if self._pf_version != world.version:
            self._pf_done.clear()
            self._pf_version = world.version
        known = self.known()
        ax, ay = self._pan
        norm = (ax * ax + ay * ay) ** 0.5
        heading = (round(ax / norm), round(ay / norm)) if norm else (0, 0)
        centre = self.hex_at(camera[0] + view_rect.w / 2, camera[1] + view_rect.h / 2)
        key = (tuple(rows), self.r, heading, centre, self.fog_stamp())
        if self._pf_plan is None or self._pf_plan[0] != key:
            self._pf_plan = [key, self._prefetch_plan(view_rect, camera, rows, norm), 0]
        plan, i = self._pf_plan[1], self._pf_plan[2]
        cost = self._pf_cost
        done = self._pf_done
        while i < len(plan):
            r, pos = plan[i]
            if pos not in known or (r, pos, season) in done:
                i += 1
                continue
            t = time.perf_counter()
            if land.ground(pos, r, season, build=False) is None:
                if not idle.fits(cost["g"] * PREFETCH_FIT * 1000, t):
                    break
                land.prepare(pos, r, season)
                land.ground(pos, r, season)
                cost["g"] += (time.perf_counter() - t - cost["g"]) * 0.2
            t = time.perf_counter()
            if land.objects(pos, r, season, build=False) is None:
                if not idle.fits(cost["o"] * PREFETCH_FIT * 1000, t):
                    break
                land.make_sprites(pos, r, season)
                land.objects(pos, r, season)
                cost["o"] += (time.perf_counter() - t - cost["o"]) * 0.2
            done.add((r, pos, season))
            i += 1
        self._pf_plan[2] = i

    def _prefetch_plan(self, view_rect, camera, rows, norm):
        """[(r, pos)]: the ring beyond the view, the pan's side first, then the middle at the other landscape zoom."""
        world = self.world
        mx, my = camera[0] + view_rect.w / 2, camera[1] + view_rect.h / 2
        ax, ay = self._pan
        ring = []
        for row in range(max(0, rows[0] - PREFETCH_RING), min(world.rows - 1, rows[1] + PREFETCH_RING) + 1):
            for col in range(max(0, rows[2] - PREFETCH_RING), min(world.cols - 1, rows[3] + PREFETCH_RING) + 1):
                if rows[0] <= row <= rows[1] and rows[2] <= col <= rows[3]:
                    continue
                ring.append((col, row))

        def ahead(pos):
            cx, cy = self.center(pos)
            dx, dy = cx - mx, cy - my
            score = (dx * dx + dy * dy) ** 0.5
            if norm:
                score -= 1.5 * (dx * ax + dy * ay) / norm      # cells in the pan direction first
            return score
        plan = [(self.r, pos) for pos in sorted(ring, key=ahead)]
        other = {21: 34, 34: 21}.get(self.r)
        if other is not None:
            centre = self.hex_at(mx, my)
            half_cols = int(view_rect.w / 2 / (other * SQRT3)) + 2
            half_rows = int(view_rect.h / 2 / (1.5 * other)) + 2
            near = [(c, rw) for rw in range(centre[1] - half_rows, centre[1] + half_rows + 1)
                    for c in range(centre[0] - half_cols, centre[0] + half_cols + 1)
                    if 0 <= rw < world.rows and 0 <= c < world.cols]
            near.sort(key=lambda p: abs(p[0] - centre[0]) + abs(p[1] - centre[1]))
            plan += [(other, pos) for pos in near]
        return plan

    def land_sprite(self, prov):
        options = TERRAIN_SPRITES[prov.terrain]
        return options[(prov.pos[0] * 5 + prov.pos[1] * 11) % len(options)]

    def chip(self, screen, x, y, text, fill, fg=(255, 255, 255)):
        img = self.tiny.render(text, True, fg)
        box = img.get_rect(center=(x, y)).inflate(8, 3)
        pygame.draw.rect(screen, (15, 15, 18), box.inflate(2, 2), border_radius=6)
        pygame.draw.rect(screen, fill, box, border_radius=6)
        screen.blit(img, img.get_rect(center=box.center))

    def _market_number(self, market):
        """The index of a market in world.markets, or None if it is not one of them. The table is rebuilt only when
        the world changes (its version or its number of markets)."""
        world = self.world
        key = (id(world), world.version, len(world.markets))
        if key != self._market_index_key:
            self._market_index_key = key
            self._market_index = {id(m): i for i, m in enumerate(world.markets)}
        return self._market_index.get(id(market))

    def _mode_layer(self, screen, shown, washes=True, chips=True):
        """Close-up terrain, goods and market views: the washes (under the objects on the landscape zooms) and the
        chips and labels (over them)."""
        r = self.r
        if washes:
            tints = []
            under = self._under_backdrop                 # (the backdrop already carries its tint)
            for prov, cx, cy in shown:
                if (cx, cy) in under:
                    continue
                if self.mode == "terrain":
                    tints.append((TERRAIN_TINT[prov.terrain] + (45,), cx, cy))
                elif self.mode == "goods" and self.goods_view == "deposits" and prov.good:
                    tints.append((GOODS[prov.good].color + (70,), cx, cy))
                elif self.mode == "markets" and prov.market and self._market_number(prov.market) is not None:
                    tints.append((market_color(self._market_number(prov.market)) + (95,), cx, cy))
            self._tint(screen, tints)
        for prov, cx, cy in shown:
            if self.mode == "terrain":
                t = TERRAIN[prov.terrain]
                if chips and r >= 20:
                    if t.defense:
                        self.chip(screen, cx - r * 0.3, cy + r * 0.38, str(t.move), (70, 80, 95))
                        x, y = cx + r * 0.08, cy + r * 0.15
                        s = r * 0.42
                        shield = [(x, y), (x + s, y), (x + s, y + s * 0.6), (x + s / 2, y + s), (x, y + s * 0.6)]
                        pygame.draw.polygon(screen, (40, 90, 160), shield)
                        pygame.draw.polygon(screen, (15, 15, 18), shield, 1)
                        img = self.tiny.render(str(int(t.defense * 4)), True, (255, 255, 255))
                        screen.blit(img, img.get_rect(center=(x + s / 2, y + s * 0.42)))
                    else:
                        self.chip(screen, cx, cy + r * 0.38, str(t.move), (70, 80, 95))
            elif self.mode == "goods":
                if not prov.good:
                    continue
                good = GOODS[prov.good]
                if self.goods_view == "deposits":
                    if washes:
                        obj = goodsobjects.draw_good(prov.good, round(2 * r))
                        screen.blit(obj, (cx - obj.get_width() / 2, cy - obj.get_height() / 2))
                    continue
                if self.goods_view == "prices":
                    if chips and prov.market:
                        price = prov.market.price[prov.good]
                        t = max(0.0, min(1.0, (price / good.price - 0.5) / 1.5))
                        self.chip(screen, cx, cy - r * 0.08, abbr(prov.good), (int(60 + 180 * t), int(170 - 110 * t), 70))
                        self.chip(screen, cx, cy + r * 0.38, f"{price:.1f}d", (30, 34, 42))
                    continue
                if chips:
                    dark = sum(good.color) > 520
                    self.chip(screen, cx, cy - r * 0.08, abbr(prov.good), good.color, (20, 20, 20) if dark else (255, 255, 255))
                    if prov.owner and r >= 20:
                        self.chip(screen, cx, cy + r * 0.38, f"{prov.output:.1f}", (30, 34, 42))
            elif self.mode == "markets" and prov.market:
                if chips and prov.pos == prov.market.center:
                    self.chip(screen, cx, cy, prov.market.name, (40, 45, 55))

    def _movement(self, screen, at, ui):
        """This season in green, next season in blue, attacks in red, castle zones marked 'stop', path preview."""
        r = self.r
        known = self.known()
        start = ui.selected.pos
        now = {p for p in ui.reach if p in known}
        later = {p for p in getattr(ui, "reach2", {}) if p in known and p not in now}
        for area, color, alpha in ((later, (70, 160, 230), 50), (now - {start}, (70, 220, 120), 80)):
            self._tint(screen, [(color + (alpha,), *at(pos)) for pos in area])
        self._edge(screen, at, later | now, (130, 190, 255), 2)
        self._edge(screen, at, now, (120, 255, 160), max(2, r // 9))
        if r >= 14:
            for pos in getattr(ui, "stops", ()):
                if pos in now:
                    x, y = at(pos)
                    self.chip(screen, x, y - r * 0.5, "stop", (200, 120, 30))
        self._tint(screen, [((230, 60, 50, 100), *at(pos)) for pos in ui.attacks])
        for pos in ui.attacks:
            x, y = at(pos)
            pygame.draw.polygon(screen, (255, 70, 60), hex_points(x, y, r - 1), max(2, r // 9))
            if r >= 14:
                self.chip(screen, x, y + r * 0.62, "attack", (170, 40, 35))
        path = getattr(ui, "path", [])
        if len(path) > 1:
            points = [at(p) for p, _ in path]
            pygame.draw.lines(screen, (255, 255, 255), False, points, 4)
            pygame.draw.lines(screen, (255, 214, 70), False, points, 2)
            speed = getattr(ui, "speed", 3) or 3
            first = getattr(ui, "first_moves", speed)
            for pos, cost in path[1:]:
                x, y = at(pos)
                season = 1 if cost <= first else 2 + (cost - first - 1) // speed
                pygame.draw.circle(screen, (20, 20, 20), (x, y), max(6, r // 4))
                pygame.draw.circle(screen, (120, 255, 160) if season == 1 else (130, 190, 255), (x, y), max(5, r // 4 - 1))
                img = self.tiny.render(str(cost), True, (10, 10, 10))
                screen.blit(img, img.get_rect(center=(x, y)))
            goal, cost = path[-1]
            seasons = 1 if cost <= first else 2 + (cost - first - 1) // speed
            x, y = at(goal)
            pygame.draw.polygon(screen, (255, 214, 70), hex_points(x, y, r - 1), 3)
            self.chip(screen, x, y - r * 0.75, f"{seasons} season{'s' * (seasons != 1)}", (40, 45, 55))

    def _edge(self, screen, at, area, color, width):
        r = self.r
        for pos in area:
            x, y = at(pos)
            pts = hex_points(x, y, r - 1)
            near = list(neighbors(pos))
            for e in range(6):
                if near[(6 - e) % 6] not in area:
                    pygame.draw.line(screen, color, pts[e], pts[(e + 1) % 6], width)

    def _flag(self, screen, at, color):
        x, y = at
        size = max(8, self.r // 3)
        pygame.draw.line(screen, (60, 45, 35), (x, y), (x, y + size * 1.5), 2)
        flag = [(x + 1, y), (x + size, y + size // 3), (x + 1, y + 2 * size // 3)]
        pygame.draw.polygon(screen, color, flag)
        pygame.draw.polygon(screen, (20, 20, 20), flag, 1)

    # ----- units: little dioramas close up, board-game tokens far out --------------------------
    def figure(self, key, color, size, faded):
        k = ("fig", key, color, size, faded)
        if k not in self._figures:
            self._figures[k] = art.figure(ART_KEYS.get(key, key), color, size, faded=faded)
        return self._figures[k]

    def token_img(self, key, color, size, era, faded):
        k = ("tok", key, color, size, era, faded)
        if k not in self._figures:
            self._figures[k] = art.token(ART_KEYS.get(key, key), color, size, era=era, faded=faded)
        return self._figures[k]

    def _tired(self, units):
        return units[0].owner == self.world.player and all(u.moves_left == 0 for u in units)

    def _diorama(self, screen, stack, top, at, selected):
        """Up to three figures showing what the stack is made of, with a shield for its size."""
        world = self.world
        x, y = at
        r = self.r
        color = world.countries[top.owner].color
        faded = self._tired(stack)
        if selected:
            ring = pygame.Rect(0, 0, r * 1.5, r * 0.6)
            ring.center = (x, y + r * 0.35)
            pygame.draw.ellipse(screen, (255, 214, 70), ring, max(2, r // 10))
        if top.naval:
            img = self.figure(top.kind.key, color, int(r * 1.5), faded)
            screen.blit(img, (x - img.get_width() / 2, y + r * 0.45 - img.get_height() * 0.86))
            self._shield(screen, (x + r * 0.62, y - r * 0.55), len(world.cargo(top)), color)
            return
        kinds = {}
        for u in stack:
            kinds.setdefault(u.kind.key, []).append(u)
        order = sorted(kinds, key=lambda k: (-(kinds[k][0].kind.war), -len(kinds[k]), k))[:3]
        size = int(r * (1.5 if len(order) == 1 else 1.2))
        spots = {1: [(0, 0.38)], 2: [(-0.32, 0.3), (0.32, 0.42)],
                 3: [(-0.34, 0.18), (0.34, 0.2), (0.0, 0.48)]}[len(order)]
        for key, (dx, dy) in sorted(zip(order, spots), key=lambda kv: kv[1][1]):
            img = self.figure(key, color, size, faded)
            screen.blit(img, (x + dx * r - img.get_width() / 2, y + dy * r - img.get_height() * 0.86))
        lead = next((u for u in stack if u.kind.war), None)
        if lead and r >= 14:
            ratio = sum(u.hp for u in stack if u.kind.war) / sum(u.kind.hp for u in stack if u.kind.war)
            bar = pygame.Rect(0, 0, r * 1.0, max(3, r // 8))
            bar.midtop = (x, y + r * 0.55)
            pygame.draw.rect(screen, (20, 20, 20), bar.inflate(2, 2))
            fill = (80, 200, 90) if ratio > 0.6 else (240, 200, 60) if ratio > 0.3 else (230, 70, 60)
            pygame.draw.rect(screen, fill, (bar.x, bar.y, max(2, round(bar.w * ratio)), bar.h))
        if len(stack) > 1:
            self._shield(screen, (x + r * 0.62, y - r * 0.5), len(stack), color)

    def _shield(self, screen, at, count, color):
        if count <= 1:
            return
        x, y = at
        s = max(9, self.r // 3)
        pts = [(x - s, y - s), (x + s, y - s), (x + s, y + s * 0.2), (x, y + s * 1.1), (x - s, y + s * 0.2)]
        pygame.draw.polygon(screen, (20, 20, 25), [(a + 1, b + 1) for a, b in pts])
        pygame.draw.polygon(screen, color, pts)
        pygame.draw.polygon(screen, (255, 214, 70), pts, 2)
        img = self.num.render(str(count), True, (255, 255, 255))
        screen.blit(img, img.get_rect(center=(x, y - s * 0.1)))

    def _token(self, screen, unit, at, selected, count=1):
        world = self.world
        x, y = at
        r = self.r
        if r < 5:
            color = world.countries[unit.owner].color
            pygame.draw.circle(screen, (15, 15, 18), (x, y), 3)
            pygame.draw.circle(screen, color, (x, y), 2)
            return
        stack = world.units_at(unit.pos)
        size = max(12, int(r * 1.9))
        img = self.token_img(unit.kind.key, world.countries[unit.owner].color, size, max(1, unit.kind.era),
                             self._tired(stack))
        if selected:
            pygame.draw.circle(screen, (255, 214, 70), (x, y), size * 0.56, 2)
        screen.blit(img, (x - img.get_width() / 2, y - img.get_height() * 0.62))
        if count > 1 and r >= 8:
            self._badge(screen, (x + size * 0.45, y - size * 0.45), count, world.countries[unit.owner].color)

    def _badge(self, screen, at, count, color):
        if count <= 1 or self.r < 9:
            return
        badge = pygame.Rect(0, 0, 16, 14)
        badge.center = at
        pygame.draw.rect(screen, (20, 20, 24), badge, border_radius=4)
        pygame.draw.rect(screen, color, badge, 1, border_radius=4)
        img = self.num.render(str(count), True, (255, 255, 255))
        screen.blit(img, img.get_rect(center=badge.center))
