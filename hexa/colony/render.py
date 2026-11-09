"""Drawing the colonisation mode: a scrolling map, minimap, info bar and message log."""
import pygame

from ..hexgrid import HEX_H, HEX_W, RADIUS, ROW_H, hex_center, hex_corners, neighbors
from ..render import EDGE_TO_NEIGHBOR, Renderer, _hex_surface
from .rules import (BRAVE, COLONIST, COLONY_SPRITES, CROWN, DRAW, GOAL_SURVIVE, IMPROVEMENTS, NATIVES,
                    PIONEER, PLAYER, REGULAR, RESOURCES, RIVALS, RUINS_SPRITE, SCOUT, SHIP, SIDE_NAMES,
                    SURVIVE_TURNS, TRIBE_NAMES, VILLAGE_SPRITE, CRIMSON, GOLDEN)

WINDOW_SIZE = (960, 748)
VIEW_H = 606                     # the map viewport is above this line
HUD_TOP = VIEW_H
ROW = HUD_TOP + 8
BUTTON_SIZE = (106, 38)
BUTTON_ROW = ROW + 48
END_TURN_RECT = pygame.Rect(812, BUTTON_ROW, 132, 40)
MAP_MARGIN = 12
MINI_CELL = 4
MINI_POS = (WINDOW_SIZE[0] - 12, 10)     # top-right corner of the minimap

TEAM_COLORS = {PLAYER: (45, 115, 235), CRIMSON: (205, 50, 50), GOLDEN: (230, 175, 30),
               NATIVES: (165, 100, 55), CROWN: (150, 70, 200)}
RESOURCE_COLORS = {"food": (235, 195, 70), "wood": (160, 110, 60), "furs": (190, 140, 100), "gold": (255, 220, 90)}
MOOD_COLORS = {"friendly": (90, 200, 100), "wary": (240, 200, 60), "angry": (245, 130, 50), "at war": (235, 60, 50)}
BG = (16, 22, 34)
HUD_BG = (24, 28, 34)
TEXT = (235, 238, 242)
MUTED = (150, 160, 172)
FAINT = (110, 120, 132)
GOLD = (255, 214, 70)
TERRAIN_MINI = {"grass": (96, 160, 70), "dirt": (170, 140, 90), "forest": (50, 110, 55), "hills": (140, 130, 90),
                "mountain": (120, 120, 125), "water": (70, 140, 200), "beach": (225, 205, 140), "ocean": (40, 90, 160)}


def button_rects(count):
    w, h = BUTTON_SIZE
    return [pygame.Rect(16 + i * (w + 6), BUTTON_ROW, w, h) for i in range(count)]


def map_pixel_size(world):
    return (int(world.cols * HEX_W + HEX_W / 2 + 2 * MAP_MARGIN),
            int((world.rows - 1) * ROW_H + HEX_H + 2 * MAP_MARGIN))


def minimap_rect(world):
    w, h = world.cols * MINI_CELL + MINI_CELL // 2, world.rows * MINI_CELL
    return pygame.Rect(MINI_POS[0] - w, MINI_POS[1], w, h)


class ColonyRenderer(Renderer):
    def __init__(self, screen, tiles_dir):
        super().__init__(screen, tiles_dir)
        self.snow = _hex_surface((235, 242, 255, 85))
        self.lane = _hex_surface((255, 220, 120, 45))
        self.ocean = [self._ocean_tile(i) for i in range(3)]
        self.origin = (MAP_MARGIN, MAP_MARGIN)
        self.tiny = pygame.font.SysFont("segoeui,arial", 11, bold=True)
        self.label_font = pygame.font.SysFont("segoeui,arial", 12, bold=True)

    @staticmethod
    def _ocean_tile(variant):
        """The tile pack has no open-sea tile, so draw one: deep blue with a few wave marks."""
        surf = _hex_surface((38, 92, 158, 255))
        pygame.draw.polygon(surf, (30, 76, 136), hex_corners((HEX_W / 2, HEX_H / 2), RADIUS - 1), 2)
        waves = [((14, 22), (30, 46)), ((32, 40), (12, 52)), ((20, 30), (36, 18))][variant]
        for x, y in waves:
            pygame.draw.arc(surf, (110, 160, 215), (x, y, 12, 7), 0.3, 2.8, 2)
            pygame.draw.arc(surf, (110, 160, 215), (x + 10, y, 12, 7), 0.3, 2.8, 2)
        return surf

    def center(self, pos):
        return hex_center(pos, self.origin)

    # ----- frame -------------------------------------------------------------------
    def draw(self, world, ui, camera):
        self.origin = (MAP_MARGIN - camera[0], MAP_MARGIN - camera[1])
        self.screen.fill(BG)
        self.screen.set_clip(pygame.Rect(0, 0, WINDOW_SIZE[0], VIEW_H))
        self._draw_map(world, ui)
        self._draw_log(world)
        self._draw_minimap(world, camera)
        self.screen.set_clip(None)
        self._draw_hud(world, ui)
        if world.winner:
            self._draw_game_over(world)

    def _on_screen(self, pos):
        x, y = self.center(pos)
        return -HEX_W < x < WINDOW_SIZE[0] + HEX_W and -HEX_H < y < VIEW_H + HEX_H

    def _tile_sprite(self, world, pos):
        colony = world.colony_at(pos)
        if colony:
            return next(sprite for limit, sprite in COLONY_SPRITES if colony.pop < limit)
        if world.village_at(pos):
            return VILLAGE_SPRITE
        if world.ruins_at(pos):
            return RUINS_SPRITE
        if pos in world.improvements:
            return IMPROVEMENTS[world.improvements[pos]].sprite
        return world.terrain_at(pos).sprites[world.variants[pos]]

    def _draw_map(self, world, ui):
        reach = ui.reach if ui.selected else {}
        winter = world.season() == "Winter"
        shown = [p for p in world.terrain if self._on_screen(p)]
        for pos in sorted(shown, key=lambda p: (p[1], p[0])):
            cx, cy = self.center(pos)
            top_left = (cx - HEX_W / 2, cy - HEX_H / 2)
            if pos not in world.explored:
                self.screen.blit(self.unseen, top_left)
                continue
            if world.terrain[pos] == "ocean":
                self.screen.blit(self.ocean[(pos[0] * 7 + pos[1] * 3) % 3], top_left)
            else:
                self.screen.blit(self.sprite(self._tile_sprite(world, pos)), top_left)
            if winter and world.is_land(pos):
                self.screen.blit(self.snow, top_left)
            if pos[0] == world.cols - 1:
                self.screen.blit(self.lane, top_left)
            if pos not in world.visible:
                self.screen.blit(self.dim, top_left)
            if pos in reach and pos != ui.selected.pos:
                self.screen.blit(self.reach, top_left)

        self._draw_borders(world, shown)
        self._draw_homeland_arrow(world)
        for village in world.villages:
            if village.pos in world.explored and not village.burned and self._on_screen(village.pos):
                self._draw_village_badge(world, village)
        for colony in world.colonies:
            if colony.pos in world.explored and self._on_screen(colony.pos):
                self._draw_colony_badge(colony)

        if ui.hover in world.terrain:
            self._outline(ui.hover, (255, 255, 255), 2)
        for target in ui.attacks:
            unit = world.unit_at(target)
            peaceful = unit and unit.owner == NATIVES and PLAYER not in world.war[unit.tribe]
            peaceful = peaceful or (world.village_at(target) and PLAYER not in world.war[world.village_at(target).tribe])
            self._outline(target, (255, 160, 40) if peaceful else (255, 70, 60), 3)
        if ui.selected:
            self._outline(ui.selected.pos, GOLD, 3)
        for thing in (ui.colony, ui.village):
            if thing:
                self._outline(thing.pos, GOLD, 3)

        for unit in world.units:
            if unit.carrier is None and (unit.owner == PLAYER or unit.pos in world.visible) \
                    and self._on_screen(unit.pos):
                self._draw_unit(unit, world)

    def _draw_borders(self, world, shown):
        owners = {}

        def owner(pos):
            if pos not in owners:
                owners[pos] = world.territory_owner(pos) if world.is_land(pos) else None
            return owners[pos]
        for pos in shown:
            mine = owner(pos)
            if mine is None or pos not in world.explored:
                continue
            corners = hex_corners(self.center(pos), RADIUS - 2)
            near = list(neighbors(pos))
            for edge in range(6):
                if owner(near[EDGE_TO_NEIGHBOR[edge]]) != mine:
                    pygame.draw.line(self.screen, TEAM_COLORS[mine], corners[edge], corners[(edge + 1) % 6], 3)

    def _outline(self, pos, color, width):
        pygame.draw.polygon(self.screen, color, hex_corners(self.center(pos), RADIUS - 1), width)

    def _draw_homeland_arrow(self, world):
        x, _ = self.center((world.cols - 1, 0))
        x += HEX_W / 2 + 6
        if x > WINDOW_SIZE[0] + 40:
            return
        label = self.small.render("Homeland", True, GOLD)
        for y in range(130, VIEW_H, 200):
            pygame.draw.polygon(self.screen, GOLD, [(x, y), (x + 14, y + 10), (x, y + 20)])
            self.screen.blit(label, (x - label.get_width() - 4, y + 22))

    def _draw_colony_badge(self, colony):
        cx, cy = self.center(colony.pos)
        color = TEAM_COLORS[colony.owner]
        if colony.stockade:
            pygame.draw.polygon(self.screen, (120, 80, 40), hex_corners((cx, cy), RADIUS - 5), 4)
        self._draw_flag_at((cx + 14, cy - 30), color, colony.capital)
        badge = pygame.Rect(0, 0, 18, 16)
        badge.center = (cx - 18, cy - 20)
        pygame.draw.rect(self.screen, (20, 20, 24), badge, border_radius=4)
        pygame.draw.rect(self.screen, color, badge, 2, border_radius=4)
        num = self.tiny.render(str(colony.pop), True, TEXT)
        self.screen.blit(num, num.get_rect(center=badge.center))
        name = self.label_font.render(colony.name, True, TEXT)
        box = name.get_rect(midtop=(cx, cy + 24)).inflate(8, 2)
        shade = pygame.Surface(box.size, pygame.SRCALPHA)
        shade.fill((0, 0, 0, 150))
        self.screen.blit(shade, box)
        self.screen.blit(name, name.get_rect(center=box.center))

    def _draw_flag_at(self, at, color, big):
        x, y = at
        size = 15 if big else 11
        pygame.draw.line(self.screen, (60, 45, 35), (x, y), (x, y + 22), 2)
        flag = [(x + 1, y), (x + size, y + size // 3), (x + 1, y + 2 * size // 3)]
        pygame.draw.polygon(self.screen, color, flag)
        pygame.draw.polygon(self.screen, (20, 20, 20), flag, 1)

    def _draw_village_badge(self, world, village):
        cx, cy = self.center(village.pos)
        mood = world.mood(village.tribe, PLAYER)
        pygame.draw.circle(self.screen, (20, 20, 20), (cx + 18, cy - 20), 7)
        pygame.draw.circle(self.screen, MOOD_COLORS[mood], (cx + 18, cy - 20), 6)

    def _draw_unit(self, unit, world):
        cx, cy = self.center(unit.pos)
        cy += 3
        color = TEAM_COLORS[unit.owner]
        if unit.owner == PLAYER and world.current == PLAYER and unit.moves_left == 0:
            color = tuple((c + 140) // 2 for c in color)
        white = (255, 255, 255)
        screen = self.screen
        if unit.type is SHIP:
            hull = [(cx - 20, cy + 2), (cx + 20, cy + 2), (cx + 13, cy + 13), (cx - 13, cy + 13)]
            pygame.draw.polygon(screen, (90, 60, 35), hull)
            pygame.draw.polygon(screen, (20, 20, 20), hull, 2)
            pygame.draw.line(screen, (60, 40, 25), (cx, cy + 2), (cx, cy - 22), 3)
            sail = [(cx + 2, cy - 20), (cx + 17, cy - 4), (cx + 2, cy - 2)]
            pygame.draw.polygon(screen, color, sail)
            pygame.draw.polygon(screen, white, sail, 1)
            cargo = len(world.cargo(unit))
            if cargo and (unit.owner == PLAYER or unit.pos in world.visible):
                badge = pygame.Rect(cx - 21, cy - 22, 16, 15)
                pygame.draw.rect(screen, (20, 20, 24), badge, border_radius=4)
                num = self.tiny.render(str(cargo), True, TEXT)
                screen.blit(num, num.get_rect(center=badge.center))
        else:
            pygame.draw.circle(screen, (15, 18, 24), (cx, cy + 2), 16)
            pygame.draw.circle(screen, color, (cx, cy), 15)
            pygame.draw.circle(screen, (250, 250, 250), (cx, cy), 15, 2)
            t = unit.type
            if t is SCOUT:
                pygame.draw.polygon(screen, white, [(cx - 7, cy - 7), (cx + 8, cy), (cx - 7, cy + 7), (cx - 3, cy)])
            elif t is PIONEER:
                pygame.draw.line(screen, white, (cx - 6, cy + 7), (cx + 4, cy - 3), 3)
                pygame.draw.polygon(screen, white, [(cx, cy - 9), (cx + 9, cy), (cx + 6, cy + 3), (cx - 3, cy - 6)])
            elif t is COLONIST:
                pygame.draw.circle(screen, white, (cx, cy - 5), 4)
                pygame.draw.polygon(screen, white, [(cx - 7, cy + 8), (cx, cy - 1), (cx + 7, cy + 8)])
            elif t is BRAVE:
                pygame.draw.polygon(screen, white, [(cx - 2, cy + 9), (cx + 2, cy + 9), (cx + 5, cy - 10)])
                pygame.draw.line(screen, white, (cx - 7, cy + 4), (cx + 7, cy - 4), 2)
            else:       # soldier or royal regular: crossed swords
                pygame.draw.line(screen, white, (cx - 7, cy - 7), (cx + 7, cy + 7), 3)
                pygame.draw.line(screen, white, (cx + 7, cy - 7), (cx - 7, cy + 7), 3)
                pygame.draw.line(screen, white, (cx - 8, cy + 3), (cx - 3, cy + 8), 2)
                pygame.draw.line(screen, white, (cx + 8, cy + 3), (cx + 3, cy + 8), 2)
                if t is REGULAR:
                    pygame.draw.polygon(screen, GOLD, [(cx - 6, cy - 12), (cx - 6, cy - 17), (cx - 3, cy - 14),
                                                       (cx, cy - 18), (cx + 3, cy - 14), (cx + 6, cy - 17), (cx + 6, cy - 12)])
        ratio = unit.hp / unit.type.max_hp
        bar = pygame.Rect(cx - 15, cy + 19, 30, 5)
        pygame.draw.rect(screen, (20, 20, 20), bar.inflate(2, 2))
        fill = (80, 200, 90) if ratio > 0.6 else (240, 200, 60) if ratio > 0.3 else (230, 70, 60)
        pygame.draw.rect(screen, fill, (bar.x, bar.y, max(2, round(bar.w * ratio)), bar.h))

    # ----- overlays ---------------------------------------------------------------
    def _draw_log(self, world):
        recent = world.log[-4:]
        if not recent:
            return
        width = 470
        lines = [self._fit(self.small, msg, width - 16) for msg in recent]
        panel = pygame.Surface((width, 10 + 18 * len(lines)), pygame.SRCALPHA)
        panel.fill((10, 14, 20, 170))
        self.screen.blit(panel, (8, 8))
        for i, line in enumerate(lines):
            self._text(self.small, line, (16, 12 + i * 18), TEXT if i == len(lines) - 1 else MUTED)

    def _draw_minimap(self, world, camera):
        rect = minimap_rect(world)
        pygame.draw.rect(self.screen, (10, 12, 16), rect.inflate(6, 6), border_radius=3)
        for pos, terrain in world.terrain.items():
            if pos not in world.explored:
                continue
            x = rect.x + pos[0] * MINI_CELL + (pos[1] & 1) * MINI_CELL // 2
            y = rect.y + pos[1] * MINI_CELL
            owner = world.territory_owner(pos)
            color = TEAM_COLORS[owner] if owner in TEAM_COLORS and owner != NATIVES else TERRAIN_MINI[terrain]
            pygame.draw.rect(self.screen, color, (x, y, MINI_CELL, MINI_CELL))
        for unit in world.units:
            if unit.carrier is None and (unit.owner == PLAYER or unit.pos in world.visible):
                x = rect.x + unit.pos[0] * MINI_CELL + (unit.pos[1] & 1) * MINI_CELL // 2
                y = rect.y + unit.pos[1] * MINI_CELL
                pygame.draw.rect(self.screen, (255, 255, 255) if unit.owner == PLAYER else TEAM_COLORS[unit.owner],
                                 (x, y, MINI_CELL, MINI_CELL))
        width, height = map_pixel_size(world)
        view = pygame.Rect(rect.x + camera[0] * rect.w / width, rect.y + camera[1] * rect.h / height,
                           WINDOW_SIZE[0] * rect.w / width, VIEW_H * rect.h / height)
        pygame.draw.rect(self.screen, (255, 255, 255), view.clip(rect.inflate(2, 2)), 1)

    # ----- info bar -----------------------------------------------------------------
    def _draw_hud(self, world, ui):
        pygame.draw.rect(self.screen, HUD_BG, (0, HUD_TOP, WINDOW_SIZE[0], WINDOW_SIZE[1] - HUD_TOP))
        pygame.draw.line(self.screen, (60, 68, 80), (0, HUD_TOP), (WINDOW_SIZE[0], HUD_TOP))
        x = 16
        turns = f"/{SURVIVE_TURNS}" if world.goal == GOAL_SURVIVE else ""
        if world.current == PLAYER:
            whose, color = "Your turn", TEXT
        else:
            whose, color = f"{SIDE_NAMES[world.current].replace('Native', 'Natives')} moving...", (255, 170, 140)
        season_color = {"Winter": (200, 225, 255), "Summer": (255, 220, 120)}.get(world.season(), TEXT)
        self._text(self.bold, world.date(), (x, ROW), season_color)
        dx = x + self.bold.size(world.date())[0] + 10
        self._text(self.font, f"Turn {world.turn}{turns}  ·  {whose}", (dx, ROW + 2), color)
        self._draw_resources(world, 360, ROW + 2)

        self._text(self.font, self._fit(self.font, ui.status, 780), (x, ROW + 24))
        for i, button in enumerate(ui.buttons):
            self._draw_button(button, button is ui.hover_button, i + 1)

        hint = ui.hover_button.hint if ui.hover_button else self._hover_text(world, ui.hover)
        self._text(self.small, self._fit(self.small, hint, 780), (x, ROW + 92), MUTED)
        self._text(self.small, "Arrows/WASD or right-drag: scroll   Tab: next unit   1-7: buttons   "
                               "B: build/found   J: join   Space: end turn   M: menu", (x, ROW + 112), FAINT)

        active = world.current == PLAYER and not world.winner
        color = (60, 150, 80) if active and ui.end_hover else (50, 125, 68) if active else (60, 64, 72)
        pygame.draw.rect(self.screen, color, END_TURN_RECT, border_radius=8)
        label = self.bold.render("End turn", True, TEXT if active else MUTED)
        self.screen.blit(label, label.get_rect(center=END_TURN_RECT.center))
        scores = " · ".join(f"{name} {world.score(s)}" for s, name in
                            ((PLAYER, "you"), (CRIMSON, "crimson"), (GOLDEN, "golden")) if s not in world.dead)
        text = self.small.render(f"Score: {scores}", True, MUTED)
        self.screen.blit(text, text.get_rect(topright=(END_TURN_RECT.right, END_TURN_RECT.bottom + 6)))

    def _draw_resources(self, world, x, y):
        income = world.income(PLAYER)
        for res in RESOURCES:
            pygame.draw.circle(self.screen, RESOURCE_COLORS[res], (x + 6, y + 9), 6)
            text = f"{res.title()} {world.stock[PLAYER][res]}"
            self._text(self.font, text, (x + 16, y))
            x += 16 + self.font.size(text)[0] + 4
            delta = income[res]
            color = (120, 200, 120) if delta > 0 else (230, 110, 100) if delta < 0 else FAINT
            text = f"({delta:+})"
            self._text(self.small, text, (x, y + 2), color)
            x += self.small.size(text)[0] + 12

    def _draw_button(self, button, hovered, number):
        super()._draw_button(button, hovered)
        if number <= 9:
            self._text(self.tiny, str(number), (button.rect.x + 4, button.rect.y + 1),
                       MUTED if button.enabled else FAINT)

    def _hover_text(self, world, pos):
        if pos not in world.terrain:
            return ""
        if pos not in world.explored:
            return "Unexplored"
        t = world.terrain_at(pos)
        if t.key == "ocean":
            parts = ["Ocean: ships only" + (". Sail here to trade with the homeland" if pos[0] == world.cols - 1 else "")]
        else:
            parts = [f"{t.name}: impassable" if not t.passable else
                     f"{t.name}: move cost {t.move_cost}" + (f", defense +{t.defense}" if t.defense else "")]
        colony = world.colony_at(pos)
        village = world.village_at(pos)
        if colony:
            parts = [f"{colony.name}: {SIDE_NAMES[colony.owner].replace('Your', 'your')} colony, "
                     f"population {colony.pop}" + (", stockade" if colony.stockade else "")]
        elif village:
            parts = [f"Village of the {TRIBE_NAMES[village.tribe]}: {world.mood(village.tribe, PLAYER)} "
                     f"towards you. Click it to gift or trade"]
        elif world.ruins_at(pos):
            parts.append("burned village")
        elif pos in world.improvements:
            imp = IMPROVEMENTS[world.improvements[pos]]
            gain = ", ".join(f"+{n} {r}" for r, n in world.improvement_yield(imp.key).items()) or "nothing in winter"
            parts.append(f"{imp.name} ({gain})")
        owner = world.territory_owner(pos)
        if owner and not colony and not village:
            parts.append("your land" if owner == PLAYER else f"{SIDE_NAMES[owner].replace('Native', 'native')} land")
        unit = world.unit_at(pos)
        if unit and (unit.owner == PLAYER or pos in world.visible):
            text = f"{unit.label} {unit.hp}/{unit.type.max_hp} HP"
            if unit.type is SHIP and unit.owner == PLAYER:
                text += f", carrying {len(world.cargo(unit))}/{unit.type.capacity}"
            if unit.owner == NATIVES:
                text += f" ({TRIBE_NAMES[unit.tribe]}, {world.mood(unit.tribe, PLAYER)})"
            parts.append(text)
        return "   |   ".join(parts)

    def _draw_game_over(self, world):
        shade = pygame.Surface((WINDOW_SIZE[0], VIEW_H), pygame.SRCALPHA)
        shade.fill((0, 0, 0, 150))
        self.screen.blit(shade, (0, 0))
        won = world.winner == PLAYER
        if world.winner == DRAW:
            title = self.big.render("Draw", True, TEXT)
        else:
            title = self.big.render("Victory!" if won else "Defeat", True, GOLD if won else (240, 90, 80))
        cx = WINDOW_SIZE[0] // 2
        self.screen.blit(title, title.get_rect(center=(cx, 240)))
        lines = [self._fit(self.font, f"{world.win_reason} ({world.date()}).", 900)]
        if not won and world.winner in RIVALS:
            lines.append(f"The {SIDE_NAMES[world.winner]} comes out on top.")
        lines.append("Press R for a new map, M for the menu, or Esc to quit.")
        for i, line in enumerate(lines):
            text = self.font.render(line, True, TEXT)
            self.screen.blit(text, text.get_rect(center=(cx, 295 + i * 26)))
