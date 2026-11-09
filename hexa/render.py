"""Drawing the map, units, borders, fog of war and the bottom info bar with pygame."""
import os
from dataclasses import dataclass

import pygame

from .hexgrid import HEX_H, HEX_W, RADIUS, hex_center, hex_corners, neighbors
from .rules import (AI, CASTLE_SPRITE, DRAW, IMPROVEMENTS, PLAYER, RESOURCES, SCOUT, SETTLER,
                    TOWN_SPRITE, TURN_LIMIT, WORKER)

WINDOW_SIZE = (960, 748)
MAP_ORIGIN = (15, 12)
HUD_TOP = 606
ROW = HUD_TOP + 8
END_TURN_RECT = pygame.Rect(812, ROW, 132, 40)
BUTTON_SIZE = (124, 36)
BUTTON_ROW = ROW + 50

TEAM_COLORS = {PLAYER: (45, 115, 235), AI: (215, 55, 50)}
RESOURCE_COLORS = {"food": (235, 195, 70), "wood": (160, 110, 60), "stone": (175, 182, 192)}
BG = (34, 40, 48)
HUD_BG = (24, 28, 34)
TEXT = (235, 238, 242)
MUTED = (150, 160, 172)
FAINT = (110, 120, 132)
GOLD = (255, 214, 70)

# Hex edge i (between corners i and i+1) faces neighbour number (6 - i) % 6 in hexgrid order.
EDGE_TO_NEIGHBOR = [(6 - i) % 6 for i in range(6)]


@dataclass
class Button:
    rect: pygame.Rect
    label: str
    detail: str          # cost, shown under the label
    enabled: bool
    action: tuple
    hint: str = ""       # shown when hovering (e.g. why it is disabled)


def button_rects(count):
    w, h = BUTTON_SIZE
    return [pygame.Rect(16 + i * (w + 6), BUTTON_ROW, w, h) for i in range(count)]


def _hex_surface(color, radius=RADIUS + 0.5):
    surf = pygame.Surface((HEX_W, HEX_H), pygame.SRCALPHA)
    pygame.draw.polygon(surf, color, hex_corners((HEX_W / 2, HEX_H / 2), radius))
    return surf


class Renderer:
    def __init__(self, screen, tiles_dir):
        self.screen = screen
        self.tiles_dir = tiles_dir
        self._sprites = {}
        self.font = pygame.font.SysFont("segoeui,arial", 15)
        self.small = pygame.font.SysFont("segoeui,arial", 13)
        self.bold = pygame.font.SysFont("segoeui,arial", 17, bold=True)
        self.button_font = pygame.font.SysFont("segoeui,arial", 14, bold=True)
        self.big = pygame.font.SysFont("segoeui,arial", 46, bold=True)
        self.unseen = _hex_surface((20, 24, 30, 255))
        self.dim = _hex_surface((0, 0, 0, 125))
        self.reach = _hex_surface((255, 255, 255, 60), RADIUS - 2)

    def sprite(self, path):
        if path not in self._sprites:
            image = pygame.image.load(os.path.join(self.tiles_dir, path)).convert_alpha()
            self._sprites[path] = pygame.transform.smoothscale(image, (HEX_W, HEX_H))
        return self._sprites[path]

    # ----- whole frame -----------------------------------------------------------
    def draw(self, world, ui):
        self.screen.fill(BG)
        self._draw_map(world, ui)
        self._draw_hud(world, ui)
        if world.winner:
            self._draw_game_over(world)

    def _tile_sprite(self, world, pos):
        town = world.town_at(pos)
        if town:
            return CASTLE_SPRITE if town.capital else TOWN_SPRITE
        if pos in world.improvements:
            return IMPROVEMENTS[world.improvements[pos]].sprite
        return world.terrain_at(pos).sprites[world.variants[pos]]

    def _draw_map(self, world, ui):
        reach = ui.reach if ui.selected else {}
        for row in range(world.rows):
            for col in range(world.cols):
                pos = (col, row)
                cx, cy = hex_center(pos, MAP_ORIGIN)
                top_left = (cx - HEX_W / 2, cy - HEX_H / 2)
                if pos not in world.explored:
                    self.screen.blit(self.unseen, top_left)
                    continue
                self.screen.blit(self.sprite(self._tile_sprite(world, pos)), top_left)
                if pos not in world.visible:
                    self.screen.blit(self.dim, top_left)
                if pos in reach and pos != ui.selected.pos:
                    self.screen.blit(self.reach, top_left)

        self._draw_borders(world)
        for town in world.towns:
            if town.pos in world.explored:
                self._draw_flag(town.pos, TEAM_COLORS[town.owner], big=town.capital)

        if ui.hover in world.terrain:
            self._outline(ui.hover, (255, 255, 255), 2)
        for target in ui.attacks:
            self._outline(target, (255, 70, 60), 3)
        if ui.selected:
            self._outline(ui.selected.pos, GOLD, 3)
        if ui.town:
            self._outline(ui.town.pos, GOLD, 3)

        for unit in world.units:
            if unit.owner == PLAYER or unit.pos in world.visible:
                self._draw_unit(unit, world)

    def _draw_borders(self, world):
        owners = {pos: world.territory_owner(pos) for pos in world.explored}
        for pos, owner in owners.items():
            if owner is None:
                continue
            corners = hex_corners(hex_center(pos, MAP_ORIGIN), RADIUS - 2)
            near = list(neighbors(pos))
            for edge in range(6):
                n = near[EDGE_TO_NEIGHBOR[edge]]
                if owners.get(n, world.territory_owner(n) if n in world.terrain else None) != owner:
                    pygame.draw.line(self.screen, TEAM_COLORS[owner], corners[edge], corners[(edge + 1) % 6], 3)

    def _outline(self, pos, color, width):
        pygame.draw.polygon(self.screen, color, hex_corners(hex_center(pos, MAP_ORIGIN), RADIUS - 1), width)

    def _draw_flag(self, pos, color, big):
        cx, cy = hex_center(pos, MAP_ORIGIN)
        x, y = cx + 14, cy - 30
        size = 15 if big else 11
        pygame.draw.line(self.screen, (60, 45, 35), (x, y), (x, y + 22), 2)
        flag = [(x + 1, y), (x + size, y + size // 3), (x + 1, y + 2 * size // 3)]
        pygame.draw.polygon(self.screen, color, flag)
        pygame.draw.polygon(self.screen, (20, 20, 20), flag, 1)

    def _draw_unit(self, unit, world):
        cx, cy = hex_center(unit.pos, MAP_ORIGIN)
        cy += 3
        color = TEAM_COLORS[unit.owner]
        spent = unit.owner == PLAYER and world.current == PLAYER and unit.moves_left == 0
        if spent:
            color = tuple((c + 140) // 2 for c in color)
        pygame.draw.circle(self.screen, (15, 18, 24), (cx, cy + 2), 16)
        pygame.draw.circle(self.screen, color, (cx, cy), 15)
        pygame.draw.circle(self.screen, (250, 250, 250), (cx, cy), 15, 2)
        white = (255, 255, 255)
        if unit.type is SCOUT:      # an arrow: fast and far-seeing
            pygame.draw.polygon(self.screen, white, [(cx - 7, cy - 7), (cx + 8, cy), (cx - 7, cy + 7), (cx - 3, cy)])
        elif unit.type is WORKER:   # a hammer
            pygame.draw.line(self.screen, white, (cx - 6, cy + 7), (cx + 4, cy - 3), 3)
            pygame.draw.polygon(self.screen, white, [(cx, cy - 9), (cx + 9, cy), (cx + 6, cy + 3), (cx - 3, cy - 6)])
        elif unit.type is SETTLER:  # a little house
            pygame.draw.polygon(self.screen, white, [(cx - 8, cy - 1), (cx, cy - 9), (cx + 8, cy - 1)])
            pygame.draw.rect(self.screen, white, (cx - 6, cy - 1, 12, 9))
            pygame.draw.rect(self.screen, color, (cx - 2, cy + 3, 4, 5))
        else:                       # crossed swords
            pygame.draw.line(self.screen, white, (cx - 7, cy - 7), (cx + 7, cy + 7), 3)
            pygame.draw.line(self.screen, white, (cx + 7, cy - 7), (cx - 7, cy + 7), 3)
            pygame.draw.line(self.screen, white, (cx - 8, cy + 3), (cx - 3, cy + 8), 2)
            pygame.draw.line(self.screen, white, (cx + 8, cy + 3), (cx + 3, cy + 8), 2)
        ratio = unit.hp / unit.type.max_hp
        bar = pygame.Rect(cx - 15, cy + 19, 30, 5)
        pygame.draw.rect(self.screen, (20, 20, 20), bar.inflate(2, 2))
        fill = (80, 200, 90) if ratio > 0.6 else (240, 200, 60) if ratio > 0.3 else (230, 70, 60)
        pygame.draw.rect(self.screen, fill, (bar.x, bar.y, max(2, round(bar.w * ratio)), bar.h))

    # ----- info bar --------------------------------------------------------------
    def _text(self, font, text, pos, color=TEXT):
        self.screen.blit(font.render(text, True, color), pos)

    @staticmethod
    def _fit(font, text, width):
        if font.size(text)[0] <= width:
            return text
        while text and font.size(text + "...")[0] > width:
            text = text[:-1]
        return text.rstrip(" ,.") + "..."

    def _draw_hud(self, world, ui):
        pygame.draw.rect(self.screen, HUD_BG, (0, HUD_TOP, WINDOW_SIZE[0], WINDOW_SIZE[1] - HUD_TOP))
        pygame.draw.line(self.screen, (60, 68, 80), (0, HUD_TOP), (WINDOW_SIZE[0], HUD_TOP))
        x = 16

        whose = "Your turn" if world.current == PLAYER else "Enemy is moving..."
        self._text(self.bold, f"Turn {world.turn}/{TURN_LIMIT}  ·  {whose}", (x, ROW),
                   TEXT if world.current == PLAYER else (255, 150, 140))
        self._draw_resources(world, 262, ROW + 2)

        self._text(self.font, self._fit(self.font, ui.status, 515), (x, ROW + 25))
        for button in ui.buttons:
            self._draw_button(button, button is ui.hover_button)

        hint = ui.hover_button.hint if ui.hover_button else self._hover_text(world, ui.hover)
        self._text(self.small, self._fit(self.small, hint, 515), (x, ROW + 91), MUTED)
        self._text(self.small, "Tab: next unit   B: build/found   1-4: train   Space: end turn   R: new map   M: menu",
                   (x, ROW + 111), FAINT)

        active = world.current == PLAYER and not world.winner
        color = (60, 150, 80) if active and ui.end_hover else (50, 125, 68) if active else (60, 64, 72)
        pygame.draw.rect(self.screen, color, END_TURN_RECT, border_radius=8)
        label = self.bold.render("End turn", True, TEXT if active else MUTED)
        self.screen.blit(label, label.get_rect(center=END_TURN_RECT.center))
        score = self.small.render(f"Score: you {world.score(PLAYER)} · enemy {world.score(AI)}", True, MUTED)
        self.screen.blit(score, score.get_rect(topright=(END_TURN_RECT.right, END_TURN_RECT.bottom + 4)))

        recent = world.log[-3:]
        for i, msg in enumerate(recent):
            self._text(self.small, self._fit(self.small, msg, 395), (548, ROW + 64 + i * 19),
                       TEXT if i == len(recent) - 1 else MUTED)

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
            x += self.small.size(text)[0] + 14

    def _draw_button(self, button, hovered):
        if button.enabled:
            color = (70, 95, 140) if hovered else (52, 74, 112)
        else:
            color = (44, 48, 56)
        pygame.draw.rect(self.screen, color, button.rect, border_radius=6)
        if hovered:
            pygame.draw.rect(self.screen, (120, 140, 180), button.rect, 1, border_radius=6)
        fg = TEXT if button.enabled else FAINT
        label = self.button_font.render(button.label, True, fg)
        self.screen.blit(label, label.get_rect(midtop=(button.rect.centerx, button.rect.y + 2)))
        detail = self.small.render(button.detail, True, MUTED if button.enabled else FAINT)
        self.screen.blit(detail, detail.get_rect(midbottom=(button.rect.centerx, button.rect.bottom - 2)))

    def _hover_text(self, world, pos):
        if pos not in world.terrain:
            return ""
        if pos not in world.explored:
            return "Unexplored"
        t = world.terrain_at(pos)
        parts = [f"{t.name}: impassable" if not t.passable else
                 f"{t.name}: move cost {t.move_cost}" + (f", defense +{t.defense}" if t.defense else "")]
        town = world.town_at(pos)
        if town:
            whose = "Your" if town.owner == PLAYER else "Enemy"
            parts = [f"{whose} {town.kind}: defense +1, heals units, trains one unit per turn"]
        elif pos in world.improvements:
            imp = IMPROVEMENTS[world.improvements[pos]]
            gain = ", ".join(f"+{n} {r}" for r, n in imp.yields.items())
            parts.append(f"{imp.name} ({gain})")
        owner = world.territory_owner(pos)
        if owner and not town:
            parts.append("your land" if owner == PLAYER else "enemy land")
        unit = world.unit_at(pos)
        if unit and (unit.owner == PLAYER or pos in world.visible):
            parts.append(f"{unit.label} {unit.hp}/{unit.type.max_hp} HP")
        return "   |   ".join(parts)

    def _draw_game_over(self, world):
        shade = pygame.Surface((WINDOW_SIZE[0], HUD_TOP), pygame.SRCALPHA)
        shade.fill((0, 0, 0, 150))
        self.screen.blit(shade, (0, 0))
        won = world.winner == PLAYER
        if world.winner == DRAW:
            title = self.big.render("Draw", True, TEXT)
        else:
            title = self.big.render("Victory!" if won else "Defeat", True, GOLD if won else (240, 90, 80))
        cx = WINDOW_SIZE[0] // 2
        self.screen.blit(title, title.get_rect(center=(cx, 250)))
        for i, line in enumerate((f"{world.win_reason} on turn {world.turn}.",
                                  "Press R for a new map, or Esc to quit.")):
            text = self.font.render(line, True, TEXT)
            self.screen.blit(text, text.get_rect(center=(cx, 305 + i * 26)))
