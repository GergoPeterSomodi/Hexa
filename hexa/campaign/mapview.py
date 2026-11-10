"""Drawing the campaign map: a cached, zoomable political / terrain / goods / market map with fog."""
import math
import os

import pygame

from ..hexgrid import neighbors
from . import art, geo
from .data import (CASTLE_SPRITES, COLONIST, GENERAL, GOOD_SPRITES, GOODS, NATIVE_VILLAGE_SPRITE, PIONEER, SCOUT,
                   SETTLEMENT_SPRITES, TERRAIN, TERRAIN_SPRITES, WORKS)

SQRT3 = math.sqrt(3)
ZOOMS = (3, 5, 8, 13, 21, 34)     # hex radius in pixels
TILE_FROM = 3                     # from this zoom level on, the map is drawn with tile art
MINES = ("iron", "silver", "gold", "salt")
BANK, RIVER_DARK, RIVER = (205, 190, 125), (40, 100, 170), (95, 160, 220)
ROAD, ROAD_EDGE = (190, 150, 95), (120, 85, 50)
SPRITE_H = 70 / (60 / SQRT3)      # Kenney tiles are 60x70 for a hex of radius 34.6
GOODS_VIEWS = ("chips", "deposits", "prices")
TERRAIN_TINT = {"plains": (150, 205, 90), "steppe": (215, 195, 110), "forest": (25, 105, 45), "hills": (175, 140, 90),
                "mountains": (150, 150, 165), "desert": (245, 215, 130), "jungle": (15, 115, 65), "tundra": (205, 215, 220),
                "marsh": (80, 150, 130), "taiga": (60, 110, 90), "savanna": (220, 190, 90), "beach": (240, 220, 160),
                "snow": (240, 245, 250)}
DEPOSITS = {"iron": "rockGrey_large", "salt": "rockGrey_medium2", "silver": "crystals1", "gold": "crystals2",
            "timber": "logPile", "grain": "hay", "wine": "farmland", "wool": "fence", "cotton": "farmland",
            "sugar": "farmland", "tobacco": "farmland", "fish": "box1", "furs": "campingTent", "ivory": "box2",
            "spices": "box2"}
ABBR = {"grain": "GRN", "fish": "FSH", "salt": "SLT", "wine": "WIN", "wool": "WOL", "cotton": "CTN", "timber": "TMB",
        "iron": "IRN", "sugar": "SUG", "tobacco": "TOB", "furs": "FUR", "ivory": "IVR", "spices": "SPC",
        "silver": "SLV", "gold": "GLD"}
BLACK_FOG = (14, 16, 22)
SEA = (38, 74, 128)
SHALLOW = (52, 104, 160)
SEA_DEEP = (30, 60, 108)
NATIVE_LAND = (205, 192, 160)
WASTE = (215, 200, 165)
MODES = ("political", "terrain", "goods", "markets")


def hex_points(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i - 30)), cy + r * math.sin(math.radians(60 * i - 30)))
            for i in range(6)]


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
        self._sprites = {}
        self._overlays = {}
        self._objects = {}
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
    def surface(self):
        world = self.world
        key = (self.zoom, self.mode, world.version, world.player)
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
            return market_color(world.markets.index(prov.market))
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
        shade = pygame.Surface((int(r * SQRT3) + 2, int(2 * r) + 2), pygame.SRCALPHA)
        grow = 0.6 if r >= 9 else 1.1
        pygame.draw.polygon(shade, (0, 0, 0, 85), hex_points(shade.get_width() / 2, shade.get_height() / 2, r + grow - 0.5))
        outline = r >= 13
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
                surf.blit(shade, (cx - shade.get_width() / 2, cy - shade.get_height() / 2))
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
        screen.set_clip(view_rect)
        screen.fill(BLACK_FOG, view_rect)
        if self.zoom >= TILE_FROM and self.tiles_dir:
            self._draw_tiles(screen, view_rect, camera)
        else:
            screen.blit(self.surface(), (view_rect.x - camera[0], view_rect.y - camera[1]))
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
        player = world.player
        group = getattr(ui, "group", [])
        done = set()
        for unit in world.units:
            if unit.carrier is not None or unit.pos in done:
                continue
            if player and unit.owner != player and unit.pos not in world.visible:
                continue
            done.add(unit.pos)
            x, y = at(unit.pos)
            if not view_rect.inflate(40, 40).collidepoint(x, y):
                continue
            stack = world.units_at(unit.pos)
            top = world.unit_at(unit.pos)
            if self.zoom >= TILE_FROM and self.tiles_dir:
                self._diorama(screen, stack, top, (x, y), any(u in group for u in stack))
            else:
                self._token(screen, top, (x, y), any(u in group for u in stack), len(stack))
        screen.set_clip(None)

    # ----- tile art (zoomed in) ------------------------------------------------------------
    def sprite(self, path):
        key = (path, self.r)
        if key not in self._sprites:
            if path.startswith("art:"):
                _, name, variant = path.split(":")
                if (name, variant) not in self._art:
                    self._art[(name, variant)] = art.make_tile(name, self.tiles_dir, int(variant))
                image = self._art[(name, variant)]
            else:
                image = pygame.image.load(os.path.join(self.tiles_dir, path)).convert_alpha()
            w = int(round(self.r * SQRT3)) + 1
            self._sprites[key] = pygame.transform.smoothscale(image, (w, int(round(self.r * SPRITE_H)) + 1))
        return self._sprites[key]

    def overlay(self, name):
        key = (name, self.r)
        if key not in self._overlays:
            r = self.r
            surf = pygame.Surface((int(r * SQRT3) + 2, int(2 * r) + 2), pygame.SRCALPHA)
            cx, cy = surf.get_width() / 2, surf.get_height() / 2
            if name in ("ocean", "shallow"):
                pygame.draw.polygon(surf, (38, 92, 158) if name == "ocean" else (62, 130, 190),
                                    hex_points(cx, cy, r + 0.6))
                pygame.draw.polygon(surf, (30, 76, 136), hex_points(cx, cy, r - 0.5), 1)
                for x, y in ((-0.45, -0.2), (0.05, 0.25), (0.2, -0.45)):
                    box = (cx + x * r, cy + y * r, r * 0.35, r * 0.2)
                    pygame.draw.arc(surf, (110, 160, 215), box, 0.3, 2.8, max(1, r // 16))
            elif name == "dim":
                pygame.draw.polygon(surf, (0, 0, 0, 105), hex_points(cx, cy, r - 0.2))
            elif name == "frost":
                pygame.draw.polygon(surf, (245, 248, 255, 70), hex_points(cx, cy, r - 0.8))
                for i in range(6):
                    a = math.radians(i * 67 + 20)
                    pygame.draw.circle(surf, (255, 255, 255), (cx + math.cos(a) * r * 0.5, cy + math.sin(a) * r * 0.45),
                                       max(1, r // 14))
            elif name == "black":
                pygame.draw.polygon(surf, BLACK_FOG, hex_points(cx, cy, r + 0.8))
            self._overlays[key] = surf
        return self._overlays[key]

    def tile_sprite(self, prov):
        """The tile art for a province: castle > town or city > works > village > native camp > land."""
        if prov.castle:
            return CASTLE_SPRITES[prov.castle]
        if prov.settlement >= 2:
            return SETTLEMENT_SPRITES[prov.settlement]
        if prov.works and prov.good in WORKS:
            return WORKS[prov.good][1][prov.works - 1]
        if prov.settlement == 1:
            return SETTLEMENT_SPRITES[1]
        if prov.owner is None and prov.natives >= 2.5 and (prov.pos[0] * 7 + prov.pos[1] * 3) % 5 == 0:
            return NATIVE_VILLAGE_SPRITE
        if prov.terrain == "plains" and prov.good in GOOD_SPRITES and prov.owner:
            options = GOOD_SPRITES[prov.good]
            return options[(prov.pos[0] * 5 + prov.pos[1] * 11) % len(options)]
        return self.land_sprite(prov)

    @staticmethod
    def building(prov):
        return bool(prov.castle or prov.settlement or (prov.works and prov.good in WORKS))

    def decoration(self, kind, seed):
        key = ("deco", kind, seed % 4, self.r)
        if key not in self._sprites:
            img = art.decoration(kind, seed % 4, self.tiles_dir)
            w = int(round(self.r * SQRT3)) + 1
            self._sprites[key] = pygame.transform.smoothscale(img, (w, int(round(self.r * SPRITE_H)) + 1))
        return self._sprites[key]

    def decorations_for(self, prov):
        """Extra life on a tile: trees, rocks, hamlets and fields on open land, smoke over mines,
        a dock at ports, more houses around growing towns."""
        col, row = prov.pos
        h = (col * 73856093 ^ row * 19349663) & 0xFFFF
        out = []
        if prov.settlement >= 2 and not prov.castle:
            out.append("town" if prov.settlement == 2 else "city")
        elif prov.castle and prov.settlement >= 3:
            out.append("city")
        if prov.level("port") and (prov.settlement or prov.castle):
            out.append("port")
        if prov.works and prov.good in MINES:
            out.append("smoke")
        if not self.building(prov) and prov.terrain in ("plains", "steppe", "savanna") and \
                not (prov.owner and prov.good in GOOD_SPRITES and prov.terrain == "plains"):
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
        shown, hidden, dimmed, coast, redraw = [], [], [], [], []
        roads, rivers = getattr(world, "roads", set()), getattr(world, "river_at", {})

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
                    if world.is_sea(pos):
                        img = self.overlay("shallow" if pos in self.shallow else "ocean")
                    else:
                        img = self.sprite(TERRAIN_SPRITES["lake"][0])
                else:
                    path = self.land_sprite(prov) if bare else self.tile_sprite(prov)
                    img = self.sprite(path)
                    shown.append((prov, cx, cy))
                    if prov.coastal:
                        coast.append((prov, cx, cy))
                    if not bare and (pos in roads or pos in rivers) and self.building(prov):
                        redraw.append((img, cx, cy))
                blit(img, cx, cy)
                if world.player and pos not in visible:
                    dimmed.append((cx, cy))

        # Surf where land meets the sea.
        surf_w = max(2, r // 9)
        for prov, cx, cy in coast:
            pts = hex_points(cx, cy, r)
            near = list(neighbors(prov.pos))
            for edge in range(6):
                if world.terrain.get(near[(6 - edge) % 6]) == "ocean":
                    pygame.draw.line(screen, (240, 248, 252), pts[edge], pts[(edge + 1) % 6], surf_w)

        # Rivers and roads, then the buildings they pass through on top again.
        view = (camera[0] - self.MARGIN - 2 * r, camera[1] - self.MARGIN - 2 * r,
                camera[0] + view_rect.w + 2 * r, camera[1] + view_rect.h + 2 * r)
        m = self.MARGIN

        def on_screen(box):
            return box[2] * r >= view[0] and box[0] * r <= view[2] and box[3] * r >= view[1] and box[1] * r <= view[3]
        for pts, box in self._rivers:
            if on_screen(box):
                line = [(ox + m + x * r, oy + m + y * r) for x, y in pts]
                for color, k in ((BANK, 0.36), (RIVER_DARK, 0.25), (RIVER, 0.15)):
                    width = max(2, int(r * k))
                    pygame.draw.lines(screen, color, False, line, width)
                    for x, y in line[::3]:
                        pygame.draw.circle(screen, color, (x, y), width / 2)
        dash = max(3, r * 0.28)
        for pts, box in self._roads:
            if not on_screen(box):
                continue
            line = [(ox + m + x * r, oy + m + y * r) for x, y in pts]
            for (x0, y0), (x1, y1) in zip(line, line[1:]):
                length = math.hypot(x1 - x0, y1 - y0)
                n = max(1, int(length / dash))
                for i in range(0, n, 2):
                    a, b = i / n, min(1.0, (i + 1) / n)
                    seg = ((x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b))
                    pygame.draw.line(screen, ROAD_EDGE, *seg, max(3, r // 6))
                    pygame.draw.line(screen, ROAD, *seg, max(1, r // 6 - 2))
        for prov, cx, cy in shown:
            if prov.pos in roads and prov.pos in rivers and not self.building(prov):
                bridge = pygame.Rect(0, 0, r * 0.62, r * 0.3)
                bridge.center = (cx, cy)
                pygame.draw.rect(screen, ROAD_EDGE, bridge.inflate(2, 2), border_radius=3)
                pygame.draw.rect(screen, (175, 135, 85), bridge, border_radius=2)
                for k in (-0.2, 0.0, 0.2):
                    pygame.draw.line(screen, ROAD_EDGE, (cx + k * r, bridge.top), (cx + k * r, bridge.bottom), 1)
        for img, cx, cy in redraw:
            blit(img, cx, cy)
        if not bare:
            for prov, cx, cy in shown:
                kinds, h = self.decorations_for(prov)
                for kind in kinds:
                    blit(self.decoration(kind, h), cx, cy)

        # Winter frost in the north.
        if world.turn % 4 == 0 and not bare:
            frost = self.overlay("frost")
            for prov, cx, cy in shown:
                if self.lat[prov.pos] > 42:
                    blit(frost, cx, cy)
        dim, black = self.overlay("dim"), self.overlay("black")
        for cx, cy in dimmed:
            blit(dim, cx, cy)
        for cx, cy in hidden:
            blit(black, cx, cy)
        if self.mode != "political":
            self._mode_layer(screen, shown)
            return
        width = max(2, r // 8)
        for prov, cx, cy in shown:
            if prov.owner:
                color = world.countries[prov.owner].color
                blit(self.wash(color, 34), cx, cy)
                outer = hex_points(cx, cy, r - width / 2 - 1)
                inner = hex_points(cx, cy, r - width * 1.6 - 1)
                near = list(neighbors(prov.pos))
                for edge in range(6):
                    other = world.provinces.get(near[(6 - edge) % 6])
                    if other is None or other.owner != prov.owner:
                        a, b = (edge + 1) % 6, edge
                        pygame.draw.line(screen, tint(color, -0.35), outer[b], outer[a], width)
                        pygame.draw.line(screen, tint(color, 0.35), inner[b], inner[a], max(1, width // 2))
            if prov.controller and prov.controller != prov.owner:
                ctrl = world.countries[prov.controller].color
                for k in (-0.4, 0.0, 0.4):
                    pygame.draw.line(screen, ctrl, (cx - r * 0.5 + k * r, cy + r * 0.45), (cx + k * r + r * 0.1, cy - r * 0.45), 3)
            if prov.works and (prov.castle or prov.settlement >= 2):
                for i in range(prov.works):        # works hidden under a town: show their level as dots
                    dot = (cx - r * 0.5 + i * r * 0.22, cy + r * 0.62)
                    pygame.draw.circle(screen, (20, 20, 20), dot, max(3, r // 9))
                    pygame.draw.circle(screen, GOODS[prov.good].color, dot, max(2, r // 9 - 1))
            named = not prov.name.startswith(("near ", "New ")) and "countryside" not in prov.name
            if (prov.settlement >= 2 or prov.castle) and named and (r >= 20 or prov.city):
                name = self.small.render(prov.name, True, (245, 245, 245))
                box = name.get_rect(midtop=(cx, cy + r * 0.72)).inflate(8, 2)
                shade = pygame.Surface(box.size, pygame.SRCALPHA)
                shade.fill((0, 0, 0, 150))
                screen.blit(shade, box)
                screen.blit(name, name.get_rect(center=box.center))
            if prov.owner and world.countries[prov.owner].capital == prov.pos:
                self._flag(screen, (cx + r * 0.35, cy - r * 0.85), world.countries[prov.owner].color)

    def land_sprite(self, prov):
        options = TERRAIN_SPRITES[prov.terrain]
        return options[(prov.pos[0] * 5 + prov.pos[1] * 11) % len(options)]

    def wash(self, color, alpha):
        key = ("wash", color, alpha, self.r)
        if key not in self._overlays:
            r = self.r
            surf = pygame.Surface((int(r * SQRT3) + 2, int(2 * r) + 2), pygame.SRCALPHA)
            pygame.draw.polygon(surf, color + (alpha,), hex_points(surf.get_width() / 2, surf.get_height() / 2, r - 0.8))
            self._overlays[key] = surf
        return self._overlays[key]

    def object_sprite(self, name):
        key = (name, self.r)
        if key not in self._objects:
            path = os.path.join(os.path.dirname(self.tiles_dir), "Objects", name + ".png")
            img = pygame.image.load(path).convert_alpha()
            h = int(self.r * 0.95)
            self._objects[key] = pygame.transform.smoothscale(img, (round(img.get_width() * h / img.get_height()), h))
        return self._objects[key]

    def chip(self, screen, x, y, text, fill, fg=(255, 255, 255)):
        img = self.tiny.render(text, True, fg)
        box = img.get_rect(center=(x, y)).inflate(8, 3)
        pygame.draw.rect(screen, (15, 15, 18), box.inflate(2, 2), border_radius=6)
        pygame.draw.rect(screen, fill, box, border_radius=6)
        screen.blit(img, img.get_rect(center=box.center))

    def _mode_layer(self, screen, shown):
        """Close-up terrain, goods and market views drawn over the tiles."""
        world, r = self.world, self.r
        for prov, cx, cy in shown:
            if self.mode == "terrain":
                t = TERRAIN[prov.terrain]
                img = self.wash(TERRAIN_TINT[prov.terrain], 45)
                screen.blit(img, (cx - img.get_width() / 2, cy - img.get_height() / 2))
                if r >= 20:
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
                    img = self.wash(good.color, 70)
                    screen.blit(img, (cx - img.get_width() / 2, cy - img.get_height() / 2))
                    img = self.object_sprite(DEPOSITS[prov.good])
                    screen.blit(img, (cx - img.get_width() / 2, cy - img.get_height() / 2 + 2))
                    continue
                if self.goods_view == "prices":
                    if not prov.market:
                        continue
                    price = prov.market.price[prov.good]
                    t = max(0.0, min(1.0, (price / good.price - 0.5) / 1.5))
                    self.chip(screen, cx, cy - r * 0.08, ABBR[prov.good], (int(60 + 180 * t), int(170 - 110 * t), 70))
                    self.chip(screen, cx, cy + r * 0.38, f"{price:.1f}d", (30, 34, 42))
                    continue
                dark = sum(good.color) > 520
                self.chip(screen, cx, cy - r * 0.08, ABBR[prov.good], good.color, (20, 20, 20) if dark else (255, 255, 255))
                if prov.owner and r >= 20:
                    self.chip(screen, cx, cy + r * 0.38, f"{prov.output:.1f}", (30, 34, 42))
            elif self.mode == "markets" and prov.market:
                img = self.wash(market_color(world.markets.index(prov.market)), 95)
                screen.blit(img, (cx - img.get_width() / 2, cy - img.get_height() / 2))
                if prov.pos == prov.market.center:
                    self.chip(screen, cx, cy, prov.market.name, (40, 45, 55))

    def _movement(self, screen, at, ui):
        """This season in green, next season in blue, attacks in red, castle zones marked 'stop', path preview."""
        r = self.r
        known = self.known()
        start = ui.selected.pos
        now = {p for p in ui.reach if p in known}
        later = {p for p in getattr(ui, "reach2", {}) if p in known and p not in now}
        for area, color, alpha in ((later, (70, 160, 230), 50), (now - {start}, (70, 220, 120), 80)):
            img = self.wash(color, alpha)
            for pos in area:
                x, y = at(pos)
                screen.blit(img, (x - img.get_width() / 2, y - img.get_height() / 2))
        self._edge(screen, at, later | now, (130, 190, 255), 2)
        self._edge(screen, at, now, (120, 255, 160), max(2, r // 9))
        if r >= 14:
            for pos in getattr(ui, "stops", ()):
                if pos in now:
                    x, y = at(pos)
                    self.chip(screen, x, y - r * 0.5, "stop", (200, 120, 30))
        red = self.wash((230, 60, 50), 100)
        for pos, how in ui.attacks.items():
            x, y = at(pos)
            screen.blit(red, (x - red.get_width() / 2, y - red.get_height() / 2))
            pygame.draw.polygon(screen, (255, 70, 60), hex_points(x, y, r - 1), max(2, r // 9))
            if r >= 14:
                self.chip(screen, x, y + r * 0.62, "fire" if how == "bombard" else "attack", (170, 40, 35))
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
            self._figures[k] = art.figure(key, color, size, faded=faded)
        return self._figures[k]

    def token_img(self, key, color, size, era, faded):
        k = ("tok", key, color, size, era, faded)
        if k not in self._figures:
            self._figures[k] = art.token(key, color, size, era=era, faded=faded)
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

    # ----- the old round unit icons ------------------------------------------
    def _unit(self, screen, unit, at, selected, count=1):
        world = self.world
        x, y = at
        r = self.r
        color = world.countries[unit.owner].color
        if unit.owner == world.player and unit.moves_left == 0:
            color = tuple((c + 140) // 2 for c in color)
        white = (255, 255, 255)
        size = max(5, int(r * 0.45))
        k = size / 15                       # icons are designed for a 15 px circle
        if selected:
            pygame.draw.circle(screen, (255, 214, 70), (x, y), size + 4, 2)
        if unit.naval:
            hull = [(x - 20 * k, y + 2 * k), (x + 20 * k, y + 2 * k), (x + 13 * k, y + 13 * k), (x - 13 * k, y + 13 * k)]
            pygame.draw.polygon(screen, (90, 60, 35), hull)
            pygame.draw.polygon(screen, (20, 20, 20), hull, 2 if r >= 14 else 1)
            pygame.draw.line(screen, (60, 40, 25), (x, y + 2 * k), (x, y - 22 * k), max(1, int(3 * k)))
            sail = [(x + 2 * k, y - 20 * k), (x + 17 * k, y - 4 * k), (x + 2 * k, y - 2 * k)]
            pygame.draw.polygon(screen, color, sail)
            pygame.draw.polygon(screen, white, sail, 1)
            self._badge(screen, (x - 15 * k, y - 15 * k), len(world.cargo(unit)), color)
            return
        pygame.draw.circle(screen, (15, 18, 24), (x, y + max(1, int(2 * k))), size + 1)
        pygame.draw.circle(screen, color, (x, y), size)
        pygame.draw.circle(screen, (250, 250, 250), (x, y), size, max(1, int(2 * k)))
        line = max(1, int(3 * k))
        branch = unit.kind.branch
        if unit.kind is PIONEER:
            pygame.draw.line(screen, white, (x - 6 * k, y + 7 * k), (x + 4 * k, y - 3 * k), line)
            pygame.draw.polygon(screen, white, [(x, y - 9 * k), (x + 9 * k, y), (x + 6 * k, y + 3 * k), (x - 3 * k, y - 6 * k)])
        elif unit.kind is COLONIST:
            pygame.draw.circle(screen, white, (x, y - 5 * k), max(1, 4 * k))
            pygame.draw.polygon(screen, white, [(x - 7 * k, y + 8 * k), (x, y - k), (x + 7 * k, y + 8 * k)])
        elif unit.kind is SCOUT:
            pygame.draw.polygon(screen, white, [(x - 7 * k, y - 7 * k), (x + 8 * k, y), (x - 7 * k, y + 7 * k), (x - 3 * k, y)])
        elif unit.kind is GENERAL:
            pts = [(x + 9 * k * math.cos(math.radians(a - 90)) * (1 if i % 2 == 0 else 0.45),
                    y + 9 * k * math.sin(math.radians(a - 90)) * (1 if i % 2 == 0 else 0.45))
                   for i, a in enumerate(range(0, 360, 36))]
            pygame.draw.polygon(screen, (255, 214, 70), pts)
        elif branch == "cavalry":           # a horseshoe
            pygame.draw.arc(screen, white, (x - 8 * k, y - 8 * k, 16 * k, 17 * k), math.radians(-40), math.radians(220), line)
            pygame.draw.line(screen, white, (x - 6 * k, y + 5 * k), (x - 7 * k, y + 8 * k), line)
            pygame.draw.line(screen, white, (x + 6 * k, y + 5 * k), (x + 7 * k, y + 8 * k), line)
        elif branch == "artillery":         # a cannon on its wheel
            pygame.draw.line(screen, white, (x - 8 * k, y + 3 * k), (x + 9 * k, y - 5 * k), max(2, int(4 * k)))
            pygame.draw.circle(screen, white, (x - 2 * k, y + 5 * k), max(2, 4 * k), max(1, int(2 * k)))
        else:                               # infantry: crossed swords
            pygame.draw.line(screen, white, (x - 7 * k, y - 7 * k), (x + 7 * k, y + 7 * k), line)
            pygame.draw.line(screen, white, (x + 7 * k, y - 7 * k), (x - 7 * k, y + 7 * k), line)
        if unit.kind.war and r >= 14:
            ratio = unit.hp / unit.kind.hp
            bar = pygame.Rect(x - size, y + size + 3, size * 2, max(3, size // 4))
            pygame.draw.rect(screen, (20, 20, 20), bar.inflate(2, 2))
            fill = (80, 200, 90) if ratio > 0.6 else (240, 200, 60) if ratio > 0.3 else (230, 70, 60)
            pygame.draw.rect(screen, fill, (bar.x, bar.y, max(2, round(bar.w * ratio)), bar.h))
        self._badge(screen, (x + size, y - size), count, color)

    def _badge(self, screen, at, count, color):
        if count <= 1 or self.r < 9:
            return
        badge = pygame.Rect(0, 0, 16, 14)
        badge.center = at
        pygame.draw.rect(screen, (20, 20, 24), badge, border_radius=4)
        pygame.draw.rect(screen, color, badge, 1, border_radius=4)
        img = self.num.render(str(count), True, (255, 255, 255))
        screen.blit(img, img.get_rect(center=badge.center))
