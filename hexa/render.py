"""Drawing the map, units, fog of war and the bottom info bar with pygame."""
import os

import pygame

from .hexgrid import HEX_H, HEX_W, RADIUS, hex_center, hex_corners
from .rules import AI, CASTLE_SPRITE, DRAW, PLAYER, SCOUT, SIDE_NAMES, TURN_LIMIT

WINDOW_SIZE = (960, 716)
MAP_ORIGIN = (15, 12)
HUD_TOP = 606
END_TURN_RECT = pygame.Rect(812, HUD_TOP + 18, 132, 46)

TEAM_COLORS = {PLAYER: (45, 115, 235), "ai": (215, 55, 50)}
BG = (34, 40, 48)
HUD_BG = (24, 28, 34)
TEXT = (235, 238, 242)
MUTED = (150, 160, 172)
GOLD = (255, 214, 70)


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
                terrain = world.terrain_at(pos)
                path = CASTLE_SPRITE if world.castle_at(pos) else terrain.sprites[world.variants[pos]]
                self.screen.blit(self.sprite(path), top_left)
                if pos not in world.visible:
                    self.screen.blit(self.dim, top_left)
                if pos in reach and pos != ui.selected.pos:
                    self.screen.blit(self.reach, top_left)

        for castle in world.castles:
            if castle.pos in world.explored:
                self._draw_flag(castle.pos, TEAM_COLORS[castle.owner])

        if ui.hover in world.terrain:
            self._outline(ui.hover, (255, 255, 255), 2)
        for target in ui.attacks:
            self._outline(target, (255, 70, 60), 3)
        if ui.selected:
            self._outline(ui.selected.pos, GOLD, 3)

        for unit in world.units:
            if unit.owner == PLAYER or unit.pos in world.visible:
                self._draw_unit(unit, world)

    def _outline(self, pos, color, width):
        pygame.draw.polygon(self.screen, color, hex_corners(hex_center(pos, MAP_ORIGIN), RADIUS - 1), width)

    def _draw_flag(self, pos, color):
        cx, cy = hex_center(pos, MAP_ORIGIN)
        x, y = cx + 14, cy - 30
        pygame.draw.line(self.screen, (60, 45, 35), (x, y), (x, y + 22), 2)
        pygame.draw.polygon(self.screen, color, [(x + 1, y), (x + 15, y + 5), (x + 1, y + 10)])
        pygame.draw.polygon(self.screen, (20, 20, 20), [(x + 1, y), (x + 15, y + 5), (x + 1, y + 10)], 1)

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
        if unit.type is SCOUT:   # an arrow: fast and far-seeing
            pygame.draw.polygon(self.screen, white, [(cx - 7, cy - 7), (cx + 8, cy), (cx - 7, cy + 7), (cx - 3, cy)])
        else:                    # crossed swords
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

    def _draw_hud(self, world, ui):
        pygame.draw.rect(self.screen, HUD_BG, (0, HUD_TOP, WINDOW_SIZE[0], WINDOW_SIZE[1] - HUD_TOP))
        pygame.draw.line(self.screen, (60, 68, 80), (0, HUD_TOP), (WINDOW_SIZE[0], HUD_TOP))
        x, y = 16, HUD_TOP + 10

        whose = "Your turn" if world.current == PLAYER else "Enemy is moving..."
        self._text(self.bold, f"Turn {world.turn}/{TURN_LIMIT}  ·  {whose}", (x, y),
                   TEXT if world.current == PLAYER else (255, 150, 140))

        if ui.selected:
            u = ui.selected
            line = (f"{u.type.name}   HP {u.hp}/{u.type.max_hp}   Moves {u.moves_left}/{u.type.moves}"
                    f"   Attack {u.type.attack}   Defense {u.type.defense}")
            if u.attacked:
                line += "   (attacked)"
        else:
            line = "Click one of your blue units, or press Tab."
        self._text(self.font, line, (x, y + 26))
        self._text(self.small, self._hover_text(world, ui.hover), (x, y + 50), MUTED)
        self._text(self.small, "Tab: next unit   Right-click: deselect   Space: end turn   R: new map",
                   (x, y + 68), (110, 120, 132))

        recent = world.log[-4:]
        for i, msg in enumerate(recent):
            self._text(self.small, self._fit(self.small, msg, 360), (440, y + 2 + i * 19),
                       TEXT if i == len(recent) - 1 else MUTED)

        active = world.current == PLAYER and not world.winner
        color = (60, 150, 80) if active and ui.end_hover else (50, 125, 68) if active else (60, 64, 72)
        pygame.draw.rect(self.screen, color, END_TURN_RECT, border_radius=8)
        label = self.bold.render("End turn", True, TEXT if active else MUTED)
        self.screen.blit(label, label.get_rect(center=END_TURN_RECT.center))
        score = self.small.render(f"Strength: you {world.strength(PLAYER)} · enemy {world.strength(AI)}", True, MUTED)
        self.screen.blit(score, score.get_rect(midtop=(END_TURN_RECT.centerx - 20, END_TURN_RECT.bottom + 4)))

    @staticmethod
    def _fit(font, text, width):
        if font.size(text)[0] <= width:
            return text
        while text and font.size(text + "...")[0] > width:
            text = text[:-1]
        return text.rstrip(" ,.") + "..."

    def _hover_text(self, world, pos):
        if pos not in world.terrain:
            return ""
        if pos not in world.explored:
            return "Unexplored"
        t = world.terrain_at(pos)
        text = (f"{t.name}: impassable" if not t.passable else
                f"{t.name}: move cost {t.move_cost}" + (f", defense +{t.defense}" if t.defense else ""))
        castle = world.castle_at(pos)
        if castle:
            text = f"{SIDE_NAMES[castle.owner].replace('You', 'Your')} castle: defense +1, heals units"
        unit = world.unit_at(pos)
        if unit and (unit.owner == PLAYER or pos in world.visible):
            text += f"   |   {unit.label} {unit.hp}/{unit.type.max_hp} HP"
        return text

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
