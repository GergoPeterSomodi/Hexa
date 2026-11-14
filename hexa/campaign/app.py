"""The Age of Discovery window: map, panels, mouse and keyboard."""
import math
import sys

import pygame

from .. import settings as options
from ..ui.kit import button as draw_button, hover_card, text as draw_text, tip, wrap
from ..ui.theme import BG, GOLD, LINE, PANEL_BG, TEXT, new_font
from . import geo, saves, siegeacts
from .display import open_window
from .screens import ScreenStack, gamemenu
from .screens.gamemenu import PauseMenu
from .screens.techscreen import TechScreen
from .screens.battle import BattleScreen
from .data import COLONIST, GENERAL
from .uistate import UI, hint_text
from .mapview import ZOOMS, GOODS_VIEWS, MODES, MapView
from .game import GameManager
from .hud import Hud
from . import panels
from .panels.cards import province_card as card_of
from .panels.country import research_line as research_text, war_line

def _ordinal(n):
    suffix = "th" if 10 <= n % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    return f"{n}{suffix}"


def _dashed_line(surface, colour, points, width, dash=10, gap=7):
    """A polyline drawn as dashes."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        if length == 0:
            continue
        ux, uy = (x1 - x0) / length, (y1 - y0) / length
        t = 0.0
        while t < length:
            e = min(t + dash, length)
            pygame.draw.line(surface, colour, (x0 + ux * t, y0 + uy * t), (x0 + ux * e, y0 + uy * e), width)
            t += dash + gap


WIDTH, HEIGHT = 1280, 720
TOP = 46
PANEL_W = 390


def _screen_attr(screen, name):
    """A read-only view of one attribute of a screen of the window (app.menu, app.tech_open, ...)."""
    return property(lambda self: getattr(getattr(self, screen), name))


class CampaignApp:
    menu = _screen_attr("pause", "page")                 # None, "main", "save", "load", "options" or "question"
    menu_confirm = _screen_attr("pause", "confirm")
    menu_question = _screen_attr("pause", "question")
    menu_buttons = _screen_attr("pause", "buttons")      # (rect, action, enabled) of the pause page on screen
    menu_rect = _screen_attr("pause", "rect")
    tech_open = _screen_attr("tech", "grid_open")
    tech_selected = _screen_attr("tech", "selected")
    tech_buttons = _screen_attr("tech", "buttons")
    quickload_until = 0         # ticks until which a second F9 press loads the quicksave

    def __init__(self, tiles_dir=None, player=None, map="europe", seed=None, load=None):
        self.settings = options.load()
        self.screens = ScreenStack(self)        # what is on top of the map: the pause menu, the tech screen
        self.pause = PauseMenu()
        self.tech = TechScreen()
        self.battle = BattleScreen()           # the battle panel (battle slice 1): opened by the press table
        self.apply_display()
        self.tiles_dir = tiles_dir
        pygame.display.set_caption("Hexa: Age of Discovery")
        self.clock = pygame.time.Clock()
        self.font = new_font(14)
        self.small = new_font(12)
        self.bold = new_font(15, bold=True)
        self.title = new_font(20, bold=True)
        self.big = new_font(30, bold=True, serif=True)
        if map == "random" and seed is None:
            import random
            seed = random.randrange(1, 100000)
        loaded = GameManager.load(load) if load else None
        if load and loaded is None:          # never quietly start some other game instead
            raise saves.LoadError(f"{saves.slot_name(load)} could not be loaded.")
        self.camera = [0.0, 0.0]
        self.drag = None
        self.running = True
        self.result = None
        self._mini = None
        if loaded:                           # one map view: load_world builds it (and the caption, ui and camera)
            self.load_world(loaded)
            self.toast(f"Loaded {saves.slot_name(load)}: {loaded.world.date()}.")
            return
        game = GameManager.new(seed if seed is not None else 1480, map)
        self._set_game(game)
        pygame.display.set_caption(f"Hexa: Age of Discovery  -  {self.world.geo.name}")
        self.view = MapView(self.world, tiles_dir)
        self.ui = UI()
        self.busy = False
        self._mini_key = None
        self.view.zoom = 1
        self.look_at(geo.hex_of(*self.world.geo.START))
        if player:
            self.choose_named(player)

    @property
    def world(self):
        return self.game.world

    def apply_display(self):
        """Open the window (or go fullscreen) as the settings say; the map fills whatever size it gets."""
        global WIDTH, HEIGHT
        self.screen = open_window(self.settings)
        WIDTH, HEIGHT = self.screen.get_size()
        if hasattr(self, "camera"):
            self.clamp()

    # ----- the screens on top of the map (hexa/campaign/screens/) ---------------------------------------
    def open_menu(self, page="main"):
        self.pause.open(self, page)

    def close_menu(self):
        self.pause.close(self)

    def open_tech(self):
        self.tech.open(self)

    def _set_game(self, game):
        self.game = game                # the war alert listens to its world's event bus
        self.hud = Hud()                # the ribbons, the action log and the top bar remember things between frames
        game.bus.subscribe("war_declared", self._war_declared)
        game.bus.subscribe("unit_moved", lambda e: self.ui.replay.record(e, self.settings["movement"]))   # replay.py

    def load_world(self, game):
        """Switch to a loaded game: new map view, selection and camera."""
        self._set_game(game)
        world = game.world
        self.view = MapView(world, self.tiles_dir)
        self.ui = UI()
        self._mini_key = None
        self.busy = False
        self.tech.sync(self)        # closes the tech grid when the new game has no player
        pygame.display.set_caption(f"Hexa: Age of Discovery  -  {world.geo.name}")
        if world.player:
            self.view.zoom = 4
            self.look_at(world.countries[world.player].capital)
        else:
            self.view.zoom = 1
            self.look_at(geo.hex_of(*world.geo.START))
        self.refresh()

    # ----- camera ----------------------------------------------------------------------
    def view_rect(self):
        return pygame.Rect(0, TOP, WIDTH, HEIGHT - TOP)

    def look_at(self, pos):
        x, y = self.view.center(pos)
        rect = self.view_rect()
        self.camera = [x - rect.w / 2, y - rect.h / 2]
        self.clamp()

    def clamp(self):
        w, h = self.view.size()
        rect = self.view_rect()
        self.camera[0] = max(-200, min(w - rect.w + 200, self.camera[0]))
        self.camera[1] = max(-100, min(h - rect.h + 100, self.camera[1]))

    def zoom(self, step, at=None):
        new = max(0, min(len(ZOOMS) - 1, self.view.zoom + step))
        if new == self.view.zoom:
            return
        rect = self.view_rect()
        at = at or rect.center
        mx, my = at[0] - rect.x + self.camera[0], at[1] - rect.y + self.camera[1]
        pos = self.view.hex_at(mx, my)
        self.view.zoom = new
        x, y = self.view.center(pos)
        self.camera = [x - (at[0] - rect.x), y - (at[1] - rect.y)]
        self.clamp()

    def hex_under(self, pixel):
        rect = self.view_rect()
        if not rect.collidepoint(pixel) or self.hud.covers(self, pixel):
            return None
        return self.ui.replay.pick(self.world, self.view.hex_at(pixel[0] - rect.x + self.camera[0], pixel[1] - rect.y + self.camera[1]))

    # ----- state -----------------------------------------------------------------------
    @property
    def player(self):
        return self.world.player

    def choose(self, tag):
        world = self.world
        world.player = tag
        world.countries[tag].memory = {}
        world.update_visibility()
        world.changed()
        self.ui.panel, self.ui.country = "country", tag
        world.message(f"You lead {world.countries[tag].name}. Grow your economy, trade, and reach for the New World.",
                      notice="lead")
        self.view.zoom = 4
        self.look_at(world.countries[tag].capital)

    def choose_named(self, name):
        """--nation: play the country given by tag or name; if there is none, say so and show the chooser."""
        tag = self.world.find_country(name)
        if tag:
            self.choose(tag)
            return
        self.toast(f"There is no country '{name}' on this map: click a country to play it.")
        print(f"--nation {name}: no such country on {self.world.geo.name}. Countries: "
              + ", ".join(f"{t} ({c.name})" for t, c in sorted(self.world.countries.items())), file=sys.stderr)

    def toast(self, text):
        self.ui.toast = text
        self.ui.toast_until = pygame.time.get_ticks() + 3500

    def select_unit(self, unit, only=False):
        """Select the whole stack the unit stands in (or just the unit, for ships and passengers)."""
        ui, world = self.ui, self.world
        ui.selected = unit
        if unit is None:
            ui.group, ui.picked = [], set()
        else:
            if unit.naval:
                ui.group = [unit]
            elif unit.carrier:
                ui.group = world.cargo(unit.carrier)
            else:
                ui.group = [u for u in world.units_at(unit.pos) if u.owner == unit.owner]
            ui.picked = {unit.id} if only or unit.carrier else {u.id for u in ui.group}
            ui.panel = "unit"
        self.refresh()

    def active(self):
        """The ticked units of the selected stack: they move and fight together."""
        world = self.world
        return [u for u in self.ui.group if u.id in self.ui.picked and u in world.units]

    def _cancel_orders(self, units):
        """A manual order for the stack itself (attack, found, forage) replaces the multi-season move order of the stack."""
        for unit in units:
            unit.goal = None

    def refresh(self):
        ui, world = self.ui, self.world
        world.ensure_markets()
        self.hud.tasks.forget()                 # the task flag counts again after any action or season
        ui.group = [u for u in ui.group if u in world.units]
        if ui.selected not in ui.group:
            ui.selected = ui.group[0] if ui.group else None
        if not ui.group and ui.panel == "unit":
            ui.panel = None
        active = self.active()
        if active and active[0].owner == self.player and len({u.pos for u in active}) == 1:
            ui.reach = world.reachable_group(active)
            ui.attacks = {p: s for p, s in world.attack_options_group(active).items() if p in world.visible}
            ui.reach2 = world.next_season_reach(active)
            ui.stops = world.zoc(self.player) & set(ui.reach)
            ui.speed = min(u.kind.moves for u in active)
            ui.first_moves = min(u.moves_left for u in active)
        else:
            ui.reach, ui.attacks, ui.reach2, ui.stops = {}, {}, {}, set()
        ui.path, ui.path_key = [], None

    def next_unit(self):
        ready = [u for u in self.world.units_of(self.player)
                 if (u.moves_left > 0 and not isinstance(u.goal, tuple)) or self.is_marching(u)]
        if not ready:
            self.toast("All units have moved.")
            return
        current = self.ui.selected
        index = ready.index(current) + 1 if current in ready else 0
        for step in range(len(ready)):
            unit = ready[(index + step) % len(ready)]
            if unit not in self.ui.group or step == len(ready) - 1:
                break
        self.select_unit(unit)
        self.look_at(unit.pos)

    # ----- turns -----------------------------------------------------------------------
    def end_turn(self, key=False):
        world = self.world
        if not self.player or world.over:
            return
        if self.ui.replay.active:               # the moves are still being shown: a key skips them, a click waits
            return self.ui.replay.skip() if key else self.toast("The moves are still playing: Space skips them.")
        self.hud.tasks.close()                  # End season never asks: the task flag shows what is left (hud/tasks.py)
        self.busy = True
        world.ensure_markets()
        self.draw()
        pygame.display.flip()
        self.game.autosave_every = options.AUTOSAVE_TURNS[self.settings["autosave"]]
        season = self.game.end_season(orders=self._advance_orders)
        self.busy = False
        self.refresh()
        gamemenu.autosave_toast(self, season.saved, season.error)
        self.process_events()
        if self.player and not world.countries[self.player].researching and not self.tech.pending(self):
            self.toast("Pick new research (T)")

    MARCH_SEASONS = 12          # how far ahead a planned march route is looked up (for the dashed line)

    def is_marching(self, unit):
        """A player's unit on a multi-season march that has not arrived: it waits for the player's order."""
        return (self.player is not None and unit.owner == self.player and isinstance(unit.goal, tuple)
                and not unit.carrier and unit.pos != unit.goal and unit in self.world.units)

    def waiting_marches(self):
        """The player's stacks that are on a march, as {(pos, goal): [units]}."""
        orders = {}
        if not self.player:
            return orders
        for unit in self.world.units_of(self.player):
            if self.is_marching(unit):
                orders.setdefault((unit.pos, unit.goal), []).append(unit)
        return orders

    def _advance_orders(self):
        """End of a season. Marches do not move on their own: each stack waits for the player's order (the
        Continue march button, or R with the stack selected). Its planned route stays on the map."""
        count = len(self.waiting_marches())
        if count:
            noun = "march waits" if count == 1 else "marches wait"
            text = f"{count} {noun} for your order: select the stack and press R (Continue march)."
            self.world.message(text, self.player, "march")
            self.toast(text)

    def continue_march(self, units):
        """Walk the player's stacks among `units` on along their march orders, with this season's moves only."""
        orders = {}
        for unit in units:
            if self.is_marching(unit):
                orders.setdefault((unit.pos, unit.goal), []).append(unit)
        for (_pos, goal), group in orders.items():
            self._march_step(group, goal)
        self.refresh()

    def _march_step(self, group, goal):
        world = self.world
        pos = group[0].pos
        ids = tuple(sorted(u.id for u in group))
        logged = self.__dict__.setdefault("_pass_waits", {})     # stack ids -> season of the last log line
        if min(u.moves_left for u in group) <= 0:
            self.toast("No moves left this season: the march goes on next season.")
            return
        reach = world.reachable_group(group)
        waiting = world.pass_wait(group, goal)          # behind a pass shut by snow: no long detour, wait for spring
        dest = pos if waiting else goal if goal in reach else world.step_toward_group(group, goal)
        if dest == pos:
            pass_name = world.pass_blocks(group, goal)
            if pass_name:                   # a closed pass: every press says so; the log says it once a season
                text = f"The {pass_name} pass is closed by snow; the march waits for spring."
                self.toast(text)
                if logged.get(ids) != world.turn:
                    logged[ids] = world.turn
                    world.message(text, self.player, "march", pos)
                return
            for unit in group:
                unit.goal = None
            logged.pop(ids, None)
            return
        world.move_group(group, dest)
        logged.pop(ids, None)
        if dest == goal:
            for unit in group:
                unit.goal = None

    def march_routes(self):
        """The planned route of each waiting march as [pos, ..., goal]. Cached until the map, the season or the
        stacks' moves change (a pass closes in winter and opens in spring, so the route changes with the season)."""
        marches = self.waiting_marches()
        sig = tuple((pos, goal, tuple(sorted(u.id for u in group)), min(u.moves_left for u in group))
                    for (pos, goal), group in sorted(marches.items()))
        key = (self.world.version, self.world.turn, sig)
        cache = self.__dict__.get("_route_cache")
        if cache is None or cache[0] != key:
            routes = []
            for (pos, goal), group in marches.items():
                steps = self.world.path_to(group, goal, seasons=self.MARCH_SEASONS)
                if steps:
                    routes.append([p for p, _ in steps])
            cache = self._route_cache = (key, routes)
        return cache[1]

    def _draw_marches(self):
        """The planned route of each waiting march: a dashed gold line over the map, ringed at its goal."""
        view_rect = self.view_rect()
        ox, oy = view_rect.x - self.camera[0], view_rect.y - self.camera[1]
        self.screen.set_clip(view_rect)
        for route in self.march_routes():
            pts = [(x + ox, y + oy) for x, y in (self.view.center(p) for p in route)]
            _dashed_line(self.screen, GOLD, pts, 3)
            gx, gy = pts[-1]
            pygame.draw.circle(self.screen, GOLD, (int(gx), int(gy)), max(5, self.view.r // 2), 2)
        self.screen.set_clip(None)

    def process_events(self):
        """Once a frame and after a season: rebuild changed markets, then hand queued events to their handlers."""
        self.world.ensure_markets()
        self.game.bus.drain()
        self._show_war_news()

    def _war_declared(self, event):
        """A war declared on the player: a log line now, the alert box later (_show_war_news)."""
        world, me = self.world, self.player
        if not me or event.get("target") != me or not world.at_war(me, event.tag):
            return                      # not on us, or the war already ended this season
        world.message(f"{world.countries[event.tag].name} declared war on you! Their armies can now enter your land.", me)
        self.__dict__.setdefault("_war_news", []).append(event.tag)

    def _show_war_news(self):
        """Open the war alert for the pending declarations, once nothing else is on screen."""
        self.tech.sync(self)                            # the idea modal follows the pending cards
        pending = self.__dict__.get("_war_news")
        if not pending or not self.player or self.screens or self.busy:
            return
        world = self.world
        attackers = list(dict.fromkeys(pending))
        pending.clear()
        lines = [f"{world.countries[tag].name} has declared war on you." for tag in attackers]
        lines.append("Their armies can take your provinces. Their country panel shows the war.")
        first = attackers[0]
        self.pause.ask(self, "War on you!", lines,
                 [(f"Show {world.countries[first].name}", ("country", first), False),
                  ("Continue", ("resume",), False)])

    def _war_line(self, tag):
        return war_line(self.world, tag)

    def research_line(self):
        """'Researching Drill yards: 12 / 40 RP, 2 queued' for the player, or 'Nothing is being researched'."""
        return research_text(self.world)

    # ----- input -------------------------------------------------------------------------
    def handle(self, event):
        ui = self.ui
        self.tech.sync(self)
        if event.type == pygame.KEYDOWN and event.key == pygame.K_F11:
            gamemenu.toggle_fullscreen(self)
            return
        if event.type == pygame.KEYDOWN and event.key == pygame.K_F5 and not self.busy:
            gamemenu.save_to(self, "quick")
            return
        if event.type == pygame.KEYDOWN and event.key == pygame.K_F9 and not self.busy:
            gamemenu.quickload(self)
            return
        if self.screens.handle_event(event) or self.hud.tasks.key(event):     # a screen first; Esc closes the task list
            return
        if event.type == pygame.QUIT:
            self.running, self.result = False, "quit"
        elif event.type == pygame.KEYDOWN:
            key = event.key
            if key == pygame.K_ESCAPE:
                if ui.selected or ui.panel:
                    self.select_unit(None)              # also clears the group, which refresh() would re-select
                    ui.panel, ui.province = None, None
                    self.refresh()
                else:
                    self.open_menu()
            elif key == pygame.K_m:
                self.open_menu()
            elif key == pygame.K_t and self.player:
                self.tech.toggle(self)
            elif key in (pygame.K_SPACE, pygame.K_RETURN) and self.player:
                self.end_turn(True)
            elif key == pygame.K_TAB and self.player:
                self.next_unit()
            elif key in (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4):
                mode = MODES[key - pygame.K_1]
                if mode == "goods" and self.view.mode == "goods":
                    i = GOODS_VIEWS.index(self.view.goods_view)
                    self.view.goods_view = GOODS_VIEWS[(i + 1) % len(GOODS_VIEWS)]
                self.view.mode = mode
            elif key in (pygame.K_PLUS, pygame.K_EQUALS, pygame.K_KP_PLUS):
                self.zoom(1)
            elif key in (pygame.K_MINUS, pygame.K_KP_MINUS):
                self.zoom(-1)
            elif key == pygame.K_g:
                gamemenu.toggle_grid(self)
            elif key == pygame.K_l:
                ui.panel = "ledger" if ui.panel != "ledger" else None
            elif key == pygame.K_r and self.player and any(self.is_marching(u) for u in self.active()):
                self.continue_march(self.active())          # R: the selected stack walks on along its march
            elif key == pygame.K_c and self.player:
                self.open_country(self.player)
            elif key == pygame.K_b and ui.selected and ui.selected.owner == self.player:
                worker = next((u for u in self.active() if u.kind is COLONIST), None)
                if worker:
                    self.press(("found", worker, False))
        elif event.type == pygame.MOUSEWHEEL:
            if not self.hud.tasks.covers(ui.mouse) and not self.hud.wheel(self, event.y) and (not self.panel_rect().collidepoint(ui.mouse) or not ui.panel):
                self.zoom(1 if event.y > 0 else -1, ui.mouse)
        elif event.type == pygame.MOUSEMOTION:
            ui.mouse = event.pos
            if self.drag is not None and (event.buttons[2] or event.buttons[1]):
                self.camera[0] -= event.rel[0]
                self.camera[1] -= event.rel[1]
                self.drag += abs(event.rel[0]) + abs(event.rel[1])
                self.clamp()
            ui.hover = self.hex_under(event.pos) if not (ui.panel and self.panel_rect().collidepoint(event.pos)) else None
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                self.left_click(event.pos)
            elif event.button in (2, 3):
                self.hud.tasks.close()
                self.drag = None if self.hud.covers(self, event.pos) else 0       # no pan, no order from the HUD
        elif event.type == pygame.MOUSEBUTTONUP and event.button in (2, 3):
            if event.button == 3 and self.drag is not None and self.drag < 6:     # no press on the map: no order
                self.right_click(event.pos)
            self.drag = None

    def panel_rect(self):
        return pygame.Rect(WIDTH - PANEL_W, TOP, PANEL_W, HEIGHT - TOP)

    def left_click(self, pixel):
        ui, world = self.ui, self.world
        if self.hud.tasks.click(self, pixel):           # the task flag and its list come first: they are over the panel
            return
        panel = ui.panel and self.panel_rect()
        for button in ui.buttons:
            if button.rect.collidepoint(pixel):
                if panel and panel.collidepoint(pixel) and not panel.contains(button.rect):
                    continue                    # the panel is on top of what pokes into it
                if button.enabled:
                    self.press(button.action)
                elif button.hint:
                    self.toast(hint_text(button.hint))
                return
        if ui.panel and self.panel_rect().collidepoint(pixel):
            return
        if self.minimap_rect().collidepoint(pixel):
            mini = self.minimap_rect()
            col = int((pixel[0] - mini.x) / mini.w * world.cols)
            row = int((pixel[1] - mini.y) / mini.h * world.rows)
            self.look_at((col, row))
            return
        if self.hud.sieges.click(self, pixel):          # a siege badge opens its province
            return
        battle = None if self.hud.covers(self, pixel) else self.hud.marks.at(pixel)
        if battle is not None:                  # the badge or the bar of a battle opens its panel
            self.press(("battle", battle))
            return
        pos = self.hex_under(pixel)
        if pos is None or pos not in world.terrain:
            return
        known = pos in self.view.known()
        if not known:
            self.select_unit(None)
            ui.province, ui.panel = None, None
            return
        if self.player is None:
            prov = world.provinces.get(pos)
            if prov and prov.owner:
                ui.province = prov
                self.open_country(prov.owner)
            return
        unit = world.unit_at(pos)
        visible_unit = unit and (unit.owner == self.player or pos in world.visible)
        if visible_unit and unit not in ui.group:
            ui.province = world.provinces.get(pos)
            self.select_unit(unit)
            return
        self.select_unit(None)
        prov = world.provinces.get(pos)
        if prov:
            ui.province, ui.panel = prov, "province"
        else:
            ui.province, ui.panel = None, None
        self.refresh()

    def right_click(self, pixel):
        ui, world = self.ui, self.world
        group = self.active()
        pos = self.hex_under(pixel)
        if not group or group[0].owner != self.player or pos is None or pos not in world.terrain:
            self.select_unit(None)
            return
        here = group[0].pos
        ok, reason = world.move_check(group, pos)
        if pos in ui.attacks or siegeacts.in_range(self, group, pos):
            if siegeacts.attack(self, group, pos, bool(pygame.key.get_mods() & pygame.KMOD_SHIFT)):
                self._cancel_orders(group)
        elif not ok and pos != here:
            self.toast(reason)                       # a closed pass: say why
        elif pos in ui.reach and pos != here:
            for unit in group:
                unit.goal = None
            world.move_group(group, pos)
        elif pos != here and world.pass_wait(group, pos):
            for unit in group:
                unit.goal = pos                              # the march waits for spring behind the closed pass
            self.toast(f"The {world.pass_wait(group, pos)} pass is closed by snow; the march waits for spring.")
        elif pos != here:
            dest = world.step_toward_group(group, pos)
            if dest != here:
                for unit in group:
                    unit.goal = pos
                world.move_group(group, dest)
                self.toast("On their way: they keep moving there in the coming seasons.")
            else:
                self.toast(world.stuck_reason(group) or "They cannot get there.")
        ui.group = [u for u in group if u in world.units]
        ui.picked = {u.id for u in ui.group}
        self.refresh()

    def open_country(self, tag):
        self.ui.panel, self.ui.country = "country", tag

    # ----- player actions: press() looks the action's kind up in PRESS ---------------------------------------
    def press(self, action):
        """Run an action tuple from a button or key: ``(kind, ...)`` goes to PRESS[kind]; then refresh."""
        handler = self.PRESS.get(action[0])
        if handler:
            handler(self, action)
        self.refresh()

    def _do_game_menu(self, action):
        self.open_menu()

    def _do_close_panel(self, action):
        self.ui.panel = None

    def _do_mode(self, action):
        self.view.mode = action[1]

    def _do_panel(self, action):
        world, ui = self.world, self.ui
        if action[1] == "country":
            self.open_country(self.player)
        elif action[1] == "market":
            ui.panel = "market"
            prov = ui.province if ui.province and ui.province.market else world.provinces[world.countries[self.player].capital]
            ui.market = prov.market
        else:
            ui.panel = action[1] if ui.panel != action[1] else None

    def _do_choose(self, action):
        self.choose(action[1])

    def _do_end(self, action):
        self.end_turn()

    def _do_continue(self, action):
        self.continue_march(self.active())

    def _do_build(self, action):
        self.world.build(self.player, action[1], action[2])

    def _do_recruit(self, action):
        unit = self.world.recruit(self.player, action[1], action[2])
        if unit and not unit.kind.war and unit.kind is not GENERAL:
            self.select_unit(unit, only=True)

    def _do_invest(self, action):
        if not self.world.invest(self.player, action[1]):
            self.toast(self.world.invest_check(self.player, action[1])[1])

    def _do_found(self, action):
        founder = action[1]
        prov = self.world.found(founder, trading_post=action[2])
        if prov:
            self._cancel_orders([founder])
            self.ui.selected, self.ui.province, self.ui.panel = None, prov, "province"

    def _do_pick(self, action):
        self.select_unit(action[1], only=True)

    def _do_toggle(self, action):
        self.ui.picked ^= {action[1].id}

    def _do_all(self, action):
        ui = self.ui
        ui.picked = {u.id for u in ui.group} if len(ui.picked) < len(ui.group) else set()

    def _do_refit(self, action):
        if not self.world.refit(action[1]):
            self.toast(self.world.refit_check(action[1])[1])

    def _do_upgrade(self, action):
        if not self.world.upgrade(action[1], action[2]):
            self.toast(self.world.upgrade_check(action[1], action[2])[1])

    def _do_raise(self, action):
        self.ui.panel, self.ui.province = "raise", action[1]

    def _do_tech(self, action):
        self.tech.toggle(self)

    def _do_fund(self, action):
        if not self.world.fund_research(self.player):
            self.toast("Not enough ducats")

    def _do_tax(self, action):
        self.world.set_tax(self.player, action[1])            # preview the new tax without rerunning the season

    def _do_war(self, action):
        self.world.declare_war(self.player, action[1])

    def _do_peace(self, action):
        ok, text = self.world.peace_offer(self.player, action[1], action[2])
        self.toast(text)

    def _do_merchant(self, action):
        if len(action) > 2:
            self.world.send_merchant(self.player, action[1], action[2], action[3])
            self.ui.order_route = None
        else:
            self.ui.order_route = None if self.ui.order_route is action[1] else action[1]

    def _do_goods_view(self, action):
        self.view.mode, self.view.goods_view = "goods", action[1]

    def _do_forage(self, action):
        acting = self.active()
        if self.world.forage(acting, self.player):
            self._cancel_orders(acting)
        else:
            self.toast(self.world.forage_check(acting, self.player)[1])

    def _do_recall(self, action):
        self.world.recall_merchant(self.player, action[1], action[2] if len(action) > 2 else None)

    def _do_market(self, action):
        self.ui.panel, self.ui.market = "market", action[1]

    def _do_country(self, action):
        self.open_country(action[1])

    def _do_province(self, action):
        self.ui.province, self.ui.panel = action[1], "province"
        self.look_at(action[1].pos)

    def _do_goto(self, action):
        self.look_at(action[1])

    def _do_log(self, action):
        self.hud.press(self, action)

    def _do_battle(self, action):
        self.battle.open(self, action[1])

    PRESS = {"game_menu": _do_game_menu, "close_panel": _do_close_panel, "mode": _do_mode, "panel": _do_panel,
             "choose": _do_choose, "end": _do_end, "continue": _do_continue, "build": _do_build,
             "recruit": _do_recruit, "invest": _do_invest, "found": _do_found, "pick": _do_pick,
             "toggle": _do_toggle, "all": _do_all, "refit": _do_refit, "upgrade": _do_upgrade, "raise": _do_raise,
             "tech": _do_tech, "fund": _do_fund, "tax": _do_tax, "war": _do_war, "peace": _do_peace,
             "merchant": _do_merchant, "goods_view": _do_goods_view, "forage": _do_forage, "recall": _do_recall,
             "market": _do_market, "country": _do_country, "province": _do_province, "goto": _do_goto,
             "log": _do_log, "battle": _do_battle, "tasks": lambda self, action: self.hud.tasks.toggle(),
             "battle_log": lambda self, action: self.battle.show_ended(self, action[1]),
             "siege": lambda self, action: siegeacts.press(self, action)}

    def scroll(self):
        if self.menu:
            return
        speed = options.SCROLL[self.settings["scroll"]]
        keys = pygame.key.get_pressed()
        dx = (keys[pygame.K_RIGHT] or keys[pygame.K_d]) - (keys[pygame.K_LEFT] or keys[pygame.K_a])
        dy = (keys[pygame.K_DOWN] or keys[pygame.K_s]) - (keys[pygame.K_UP] or keys[pygame.K_w])
        if dx or dy:
            self.camera[0] += dx * speed
            self.camera[1] += dy * speed
            self.clamp()

    # ----- drawing helpers (the work is in hexa/ui/kit.py) --------------------------------------------------
    def text(self, font, text, pos, color=TEXT, width=None):
        return draw_text(self.screen, font, text, pos, color, width).width

    def button(self, rect, label, enabled, action, hint="", detail="", small=False):
        return draw_button(self, rect, label, enabled, action, hint, detail, small)

    # ----- drawing ---------------------------------------------------------------------------
    def draw(self):
        self.tech.sync(self)
        self.ui.buttons = []
        self.ui.hoverables = []
        if not self.screens.hides_map:                  # an opaque screen (the tech grid) covers all of it
            self._draw_map()
        self.screens.draw()

    def _draw_map(self):
        ui = self.ui
        self._update_path()
        self.screen.fill(BG)
        self.view.grid_on = self.settings["grid"]
        self.view.pass_names_on = self.settings["pass_names"]
        self.view.draw(self.screen, self.view_rect(), self.camera, ui)
        self._draw_marches()
        self.hud.draw_world(self)
        self.hud.draw_log(self)
        self.draw_minimap()
        self.hud.draw_top(self)
        if ui.panel:
            self.draw_panel()
        self.hud.draw_tasks(self)               # before the hint, so a hover over the flag shows its hint
        self.draw_hint()
        if self.player is None:
            self.draw_choose_banner()
        if self.busy:
            self.banner("The other countries are making their moves...")
        if self.world.over:
            self.banner(self.game_over_text())

    def _update_path(self):
        ui, world = self.ui, self.world
        active = self.active()
        if not active or not ui.reach or ui.hover is None or active[0].owner != self.player:
            ui.path = []
            return
        key = (ui.hover, tuple(u.id for u in active), active[0].pos, min(u.moves_left for u in active))
        if key == ui.path_key:
            return
        ui.path_key = key
        ui.path = world.path_to(active, ui.hover) if ui.hover != active[0].pos else []

    def game_over_text(self):
        world = self.world
        ranking = world.ranking()
        text = (f"The year {world.year()} has come. Final ranking: "
                f"{', '.join(c.name for c in ranking[:3])} lead.")
        if self.player:
            name = world.countries[self.player].name
            place = next((i for i, c in enumerate(ranking) if c.tag == self.player), None)
            if place is None:
                text += f" {name} did not survive: score {world.score(self.player)}."
            else:
                text += f" {name}: {_ordinal(place + 1)} of {len(ranking)}, score {world.score(self.player)}."
        return text + " Press L for the ledger."

    def banner(self, text):
        cx = WIDTH // 2 - (PANEL_W // 2 if self.ui.panel else 0)
        room = 2 * min(cx, WIDTH - cx) - 40                  # the widest the banner may be, centred on cx
        lines = [self.title.render(line, True, TEXT) for line in wrap(self.title, text, room - 30)]
        if not lines:
            return
        box = pygame.Rect(0, 0, max(img.get_width() for img in lines) + 30,
                          sum(img.get_height() for img in lines) + 4 * (len(lines) - 1) + 16)
        box.center = (cx, TOP + 40)
        pygame.draw.rect(self.screen, (15, 18, 24), box, border_radius=8)
        pygame.draw.rect(self.screen, GOLD, box, 1, border_radius=8)
        y = box.y + 8
        for img in lines:
            self.screen.blit(img, img.get_rect(midtop=(box.centerx, y)))
            y += img.get_height() + 4

    def draw_choose_banner(self):
        self.banner("Choose your country: click any country on the map")

    def minimap_rect(self):
        w, h = self.world.cols + 1, self.world.rows
        right = WIDTH - (PANEL_W if self.ui.panel else 0) - 10
        return pygame.Rect(right - w, HEIGHT - h - 10, w, h)

    def draw_minimap(self):
        world = self.world
        key = self.view.fog_stamp()
        if key != self._mini_key:
            self._mini_key = key
            surf = pygame.Surface((world.cols + 1, world.rows))
            surf.fill((14, 16, 22))
            known = world.countries[world.player].explored if world.player else world.terrain
            for pos, terrain in world.terrain.items():
                if pos not in known:
                    continue
                prov = world.provinces.get(pos)
                if terrain == "ocean":
                    color = (38, 74, 128)
                elif prov and prov.owner:
                    color = world.countries[prov.owner].color
                else:
                    color = (190, 178, 145)
                surf.set_at((pos[0] + (pos[1] & 1), pos[1]), color)
            self._mini = surf
        rect = self.minimap_rect()
        pygame.draw.rect(self.screen, (10, 10, 12), rect.inflate(6, 6), border_radius=3)
        self.screen.blit(self._mini, rect)
        w, h = self.view.size()
        view = self.view_rect()
        frame = pygame.Rect(rect.x + self.camera[0] / w * rect.w, rect.y + self.camera[1] / h * rect.h,
                            view.w / w * rect.w, view.h / h * rect.h)
        pygame.draw.rect(self.screen, (255, 255, 255), frame.clip(rect.inflate(2, 2)), 1)

    def hoverable(self, rect, card):
        self.ui.hoverables.append((pygame.Rect(rect), card))

    def draw_hint(self):
        ui, world = self.ui, self.world
        now = pygame.time.get_ticks()
        if now < ui.toast_until:
            tip(self, ui.toast)
            return
        hint, key = None, None
        for button in ui.buttons:
            if button.rect.collidepoint(ui.mouse) and button.hint:
                hint, key = button.hint, ("button", button.label, tuple(button.rect))
        if hint is None:
            for rect, card in ui.hoverables:
                if rect.collidepoint(ui.mouse):
                    hint, key = card, ("area", tuple(rect))
        if hint is None and ui.hover and ui.hover in world.terrain and not self.busy:
            hint, key = card_of(world, ui.hover), ("hex", ui.hover)
        if key != ui.hover_key:
            ui.hover_key, ui.hover_since = key, now
        if hint is None:
            return
        if isinstance(hint, str):
            tip(self, hint)
        elif now - ui.hover_since >= 350:
            hover_card(self, *hint)

    # ----- panels ------------------------------------------------------------------------
    def draw_panel(self):
        rect = self.panel_rect()
        pygame.draw.rect(self.screen, PANEL_BG, rect)
        pygame.draw.line(self.screen, LINE, rect.topleft, rect.bottomleft)
        self.button((rect.right - 30, rect.y + 8, 22, 22), "×", True, ("close_panel",), "Close (Esc)")
        panels.draw(self, self.world, self.ui)

    # ----- loop ---------------------------------------------------------------------------
    def run(self):
        dt = 0
        while self.running:
            for event in pygame.event.get():
                self.handle(event)
            self.scroll()
            self.process_events()
            self.screens.update(dt)
            if not self.screens:
                self.ui.replay.advance(dt)
            self.draw()
            pygame.display.flip()
            dt = self.clock.tick(60)
        return self.result
