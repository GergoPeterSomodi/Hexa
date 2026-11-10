"""Hexa: a small turn-based strategy game on a hex map.

    python play.py                                   # start menu
    python play.py --mode conquest --seed 42         # skip the menu, same map every time
    python play.py --mode colony --start sea --goal survive
    python play.py --mode campaign --nation POR             # Age of Discovery as Portugal
"""
import argparse
import os

import pygame

from hexa import ai
from hexa.campaign.app import CampaignApp
from hexa.colony.app import ColonyApp
from hexa.menu import Menu
from hexa.hexgrid import pixel_to_hex
from hexa.render import END_TURN_RECT, MAP_ORIGIN, WINDOW_SIZE, Button, Renderer, button_rects
from hexa.rules import IMPROVEMENT_FOR_TERRAIN, PLAYER, SETTLER, UNIT_TYPES, WORKER, cost_text
from hexa.world import World

TILES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hexagon-pack", "PNG", "Tiles")
AI_STEP_MS = 350   # pause between visible enemy moves


class UIState:
    def __init__(self):
        self.selected = None      # a Unit
        self.town = None          # a Town
        self.reach = {}
        self.attacks = {}
        self.buttons = []
        self.status = ""
        self.hover = None
        self.hover_button = None
        self.end_hover = False


class App:
    def __init__(self, seed=None):
        pygame.init()
        pygame.key.set_repeat()
        self.screen = pygame.display.set_mode(WINDOW_SIZE)
        self.renderer = Renderer(self.screen, TILES_DIR)
        self.clock = pygame.time.Clock()
        self.running = True
        self.result = None       # "menu" or "quit" when the loop ends
        self.new_game(seed)

    def new_game(self, seed=None):
        self.world = World(seed)
        self.ui = UIState()
        self.ai_turn = None
        self.ai_next = 0
        pygame.display.set_caption(f"Hexa conquest  -  map #{self.world.seed}")
        self.refresh()

    # ----- selection -----------------------------------------------------------
    def select(self, unit=None, town=None):
        self.ui.selected, self.ui.town = unit, town
        self.refresh()

    def refresh(self):
        """Recompute highlights, buttons and the status line after anything changes."""
        world, ui = self.world, self.ui
        if ui.selected and (ui.selected not in world.units or world.current != PLAYER):
            ui.selected = None
        if ui.town and (ui.town.owner != PLAYER or world.current != PLAYER):
            ui.town = None
        ui.reach, ui.attacks, ui.buttons = {}, {}, []

        unit, town = ui.selected, ui.town
        if unit:
            ui.reach = world.reachable(unit)
            ui.attacks = {p: s for p, s in world.attack_options(unit).items() if p in world.visible}
            t = unit.type
            ui.status = f"{t.name}   HP {unit.hp}/{t.max_hp}   Moves {unit.moves_left}/{t.moves}"
            ui.status += f"   Attack {t.attack}   Defense {t.defense}" if t.attack else "   Cannot fight"
            if t is WORKER:
                improvement, reason = world.build_check(unit)
                shown = improvement or IMPROVEMENT_FOR_TERRAIN.get(world.terrain[unit.pos])
                label = f"Build {shown.name.lower()}" if shown else "Build"
                detail = cost_text(shown.cost) if shown else "-"
                ui.buttons.append(Button(None, label, detail, improvement is not None, ("build",),
                                         reason or f"Builds a {shown.name.lower()} here (B)"))
            elif t is SETTLER:
                ok, reason = world.found_check(unit)
                ui.buttons.append(Button(None, "Found town", "uses the settler", ok, ("found",),
                                         reason or "Founds a new town here (B)"))
        elif town:
            gain = world.income_of_town(town)
            gains = ", ".join(f"+{n} {r}" for r, n in gain.items() if n) or "nothing"
            ui.status = f"Your {town.kind}: {gains} per turn. Trains one unit per turn."
            if town.trained:
                ui.status = f"Your {town.kind} already trained a unit this turn."
            for unit_type in UNIT_TYPES.values():
                ok, reason = world.train_check(town, unit_type)
                hint = reason or self._describe(unit_type)
                ui.buttons.append(Button(None, f"{unit_type.name}  [{unit_type.hotkey}]",
                                         cost_text(unit_type.cost), ok, ("train", unit_type), hint))
        elif world.current == PLAYER and not world.winner:
            ui.status = "Click a blue unit, or click one of your towns to train units."
        else:
            ui.status = ""
        for button, rect in zip(ui.buttons, button_rects(len(ui.buttons))):
            button.rect = rect
        ui.hover_button = None

    @staticmethod
    def _describe(unit_type):
        return {
            "scout": "Scout: fast explorer, sees far. Cannot capture towns.",
            "soldier": "Soldier: fights and captures towns. Eats 1 food per turn.",
            "worker": "Worker: builds farms, lumber camps and mines inside your borders.",
            "settler": "Settler: walks to a free spot and founds a new town.",
        }[unit_type.key]

    def select_next(self):
        ready = [u for u in self.world.units_of(PLAYER) if u.moves_left > 0]
        if not ready:
            return
        current = self.ui.selected
        index = ready.index(current) + 1 if current in ready else 0
        self.select(ready[index % len(ready)])

    # ----- actions ---------------------------------------------------------------
    def players_turn(self):
        return self.world.current == PLAYER and not self.world.winner and self.ai_turn is None

    def end_turn(self):
        if not self.players_turn():
            return
        self.select()
        self.world.end_turn()
        self.ai_turn = ai.take_turn(self.world)
        self.ai_next = 0

    def press(self, button):
        if not button.enabled or not self.players_turn():
            return
        kind = button.action[0]
        if kind == "train":
            self.world.train(self.ui.town, button.action[1])
        elif kind == "build":
            self.world.build(self.ui.selected)
        elif kind == "found":
            town = self.world.found_town(self.ui.selected)
            self.select(town=town)
            return
        self.refresh()

    def click(self, pixel):
        if END_TURN_RECT.collidepoint(pixel):
            self.end_turn()
            return
        for button in self.ui.buttons:
            if button.rect.collidepoint(pixel):
                self.press(button)
                return
        if not self.players_turn():
            return
        pos = pixel_to_hex(pixel, MAP_ORIGIN)
        if not self.world.in_bounds(pos):
            return
        world, selected = self.world, self.ui.selected
        unit = world.unit_at(pos)
        town = world.town_at(pos)
        own_town = town if town and town.owner == PLAYER else None
        if selected and pos in self.ui.attacks:
            world.attack(selected, unit)
        elif selected and pos in self.ui.reach and pos != selected.pos:
            world.move(selected, pos)
        elif unit and unit.owner == PLAYER and not (unit is selected and own_town):
            self.select(unit)
            return
        elif own_town:
            self.select(town=own_town)    # clicking a selected unit inside a town selects the town
            return
        else:
            self.select()
            return
        self.refresh()

    def hotkey(self, key):
        name = pygame.key.name(key)
        for button in self.ui.buttons:
            if (button.action[0] == "train" and button.action[1].hotkey == name) or                     (button.action[0] in ("build", "found") and name == "b"):
                self.press(button)
                return

    def handle(self, event):
        if event.type == pygame.QUIT:
            self.running, self.result = False, "quit"
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.ui.selected or self.ui.town:
                    self.select()
                else:
                    self.running, self.result = False, "quit"
            elif event.key == pygame.K_m:
                self.running, self.result = False, "menu"
            elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                self.end_turn()
            elif event.key == pygame.K_TAB and self.players_turn():
                self.select_next()
            elif event.key == pygame.K_r:
                self.new_game()
            else:
                self.hotkey(event.key)
        elif event.type == pygame.MOUSEMOTION:
            self.ui.hover = pixel_to_hex(event.pos, MAP_ORIGIN)
            self.ui.end_hover = END_TURN_RECT.collidepoint(event.pos)
            self.ui.hover_button = next((b for b in self.ui.buttons if b.rect.collidepoint(event.pos)), None)
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                self.click(event.pos)
            elif event.button == 3:
                self.select()

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
        self.refresh()

    def run(self):
        while self.running:
            for event in pygame.event.get():
                self.handle(event)
            self.update(pygame.time.get_ticks())
            self.renderer.draw(self.world, self.ui)
            pygame.display.flip()
            self.clock.tick(60)
        return self.result


def main():
    parser = argparse.ArgumentParser(description="Play Hexa.")
    parser.add_argument("--mode", choices=("campaign", "conquest", "colony"), help="skip the menu and start this mode")
    parser.add_argument("--nation", help="campaign: play this country straight away (e.g. POR, ENG, VEN)")
    parser.add_argument("--start", choices=("sea", "land"), default="sea", help="colonisation: how to start")
    parser.add_argument("--goal", choices=("survive", "independence", "endless"), default="survive",
                        help="colonisation: how to win")
    parser.add_argument("--seed", type=int, help="map number, to replay the same map")
    args = parser.parse_args()
    settings = {"mode": args.mode or "campaign", "start": args.start, "goal": args.goal}
    skip_menu = args.mode is not None
    pygame.init()
    while True:
        screen = pygame.display.set_mode(WINDOW_SIZE)
        if not skip_menu:
            settings = Menu(screen, settings).run()
            if settings is None:
                break
        skip_menu_once, skip_menu = skip_menu, False
        if settings["mode"] == "campaign":
            result = CampaignApp(TILES_DIR, args.nation if skip_menu_once else None).run()
        elif settings["mode"] == "conquest":
            result = App(args.seed).run()
        else:
            result = ColonyApp(screen, TILES_DIR, args.seed, settings["start"], settings["goal"]).run()
        if result != "menu":
            break
    pygame.quit()


if __name__ == "__main__":
    main()
