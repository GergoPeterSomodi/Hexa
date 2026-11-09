"""Hexa: a small turn-based medieval strategy game.

    python play.py            # random map
    python play.py --seed 42  # the same map every time
"""
import argparse
import os

import pygame

from hexa import ai
from hexa.hexgrid import pixel_to_hex
from hexa.render import END_TURN_RECT, MAP_ORIGIN, WINDOW_SIZE, Renderer
from hexa.rules import PLAYER
from hexa.world import World

TILES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hexagon-pack", "PNG", "Tiles")
AI_STEP_MS = 350   # pause between visible enemy moves


class UIState:
    def __init__(self):
        self.selected = None
        self.reach = {}
        self.attacks = {}
        self.hover = None
        self.end_hover = False


class App:
    def __init__(self, seed=None):
        pygame.init()
        pygame.display.set_caption("Hexa")
        self.screen = pygame.display.set_mode(WINDOW_SIZE)
        self.renderer = Renderer(self.screen, TILES_DIR)
        self.clock = pygame.time.Clock()
        self.running = True
        self.new_game(seed)

    def new_game(self, seed=None):
        self.world = World(seed)
        self.ui = UIState()
        self.ai_turn = None
        self.ai_next = 0
        pygame.display.set_caption(f"Hexa  -  map #{self.world.seed}")

    # ----- selection -----------------------------------------------------------
    def select(self, unit):
        self.ui.selected = unit
        self.refresh()

    def refresh(self):
        unit = self.ui.selected
        if unit is None or unit not in self.world.units or self.world.current != PLAYER:
            self.ui.selected, self.ui.reach, self.ui.attacks = None, {}, {}
            return
        self.ui.reach = self.world.reachable(unit)
        self.ui.attacks = {p: s for p, s in self.world.attack_options(unit).items() if p in self.world.visible}

    def select_next(self):
        ready = [u for u in self.world.units_of(PLAYER) if u.moves_left > 0]
        if not ready:
            return
        current = self.ui.selected
        index = ready.index(current) + 1 if current in ready else 0
        self.select(ready[index % len(ready)])

    # ----- input ---------------------------------------------------------------
    def players_turn(self):
        return self.world.current == PLAYER and not self.world.winner and self.ai_turn is None

    def end_turn(self):
        if not self.players_turn():
            return
        self.select(None)
        self.world.end_turn()
        self.ai_turn = ai.take_turn(self.world)
        self.ai_next = 0

    def click(self, pixel):
        if END_TURN_RECT.collidepoint(pixel):
            self.end_turn()
            return
        if not self.players_turn():
            return
        pos = pixel_to_hex(pixel, MAP_ORIGIN)
        if not self.world.in_bounds(pos):
            return
        world, selected = self.world, self.ui.selected
        unit = world.unit_at(pos)
        if selected and pos in self.ui.attacks:
            world.attack(selected, unit)
        elif selected and pos in self.ui.reach and pos != selected.pos:
            world.move(selected, pos)
        elif unit and unit.owner == PLAYER:
            self.ui.selected = unit
        else:
            self.ui.selected = None
        self.refresh()

    def handle(self, event):
        if event.type == pygame.QUIT:
            self.running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.ui.selected:
                    self.select(None)
                else:
                    self.running = False
            elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                self.end_turn()
            elif event.key == pygame.K_TAB and self.players_turn():
                self.select_next()
            elif event.key == pygame.K_r:
                self.new_game()
        elif event.type == pygame.MOUSEMOTION:
            self.ui.hover = pixel_to_hex(event.pos, MAP_ORIGIN)
            self.ui.end_hover = END_TURN_RECT.collidepoint(event.pos)
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                self.click(event.pos)
            elif event.button == 3:
                self.select(None)

    # ----- enemy turn ----------------------------------------------------------
    def update(self, now):
        if self.ai_turn is None or now < self.ai_next:
            return
        # Run enemy actions until one happens where the player can see it, then pause.
        for unit in self.ai_turn:
            if unit.pos in self.world.visible or self.world.winner:
                self.ai_next = now + AI_STEP_MS
                return
        self.ai_turn = None
        if not self.world.winner:
            self.world.end_turn()
            self.select_next()

    def run(self):
        while self.running:
            for event in pygame.event.get():
                self.handle(event)
            self.update(pygame.time.get_ticks())
            self.renderer.draw(self.world, self.ui)
            pygame.display.flip()
            self.clock.tick(60)
        pygame.quit()


def main():
    parser = argparse.ArgumentParser(description="Play Hexa.")
    parser.add_argument("--seed", type=int, help="map number, to replay the same map")
    App(parser.parse_args().seed).run()


if __name__ == "__main__":
    main()
