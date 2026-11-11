"""The Age of Discovery window: map, panels, mouse and keyboard."""
import sys

import pygame


from .. import settings as options
from . import ai, geo, saves
from .gamemenu import GameMenu
from .data import (FOOD_PER_TROOP, MANPOWER, NEEDS, OUTPUT, SUPPLY_RANGE, WAGON, WAGON_SEASONS, BRANCH_NAMES, ERAS, GENERAL, GENERAL_TRAITS, RESEARCH_FUND, SCOUT, UPGRADE_MAX, BUILDINGS, CARAVEL, CARRACK, CASTLES, COLONIST, COLONY_DONE, GOODS,
                   SETTLEMENT_SLOTS, SETTLEMENTS, TAX_LEVELS, TERRAIN, UNIT_KINDS, WORKS, WORKS_BONUS, WORKS_ERA,
                   WORKS_LEVELS)
from .mapview import ZOOMS, GOODS_VIEWS, MODES, MapView
from .world import CampaignWorld

WIDTH, HEIGHT = 1280, 720
TOP = 46
PANEL_W = 390
SCROLL = 18
BG = (24, 28, 34)
PANEL_BG = (28, 32, 40)
LINE = (60, 68, 80)
TEXT = (235, 238, 242)
MUTED = (150, 160, 172)
FAINT = (105, 115, 128)
GOLD = (255, 214, 70)
GOOD_C = (120, 200, 120)
BAD_C = (230, 110, 100)


class Button:
    def __init__(self, rect, label, enabled, action, hint="", detail=""):
        self.rect, self.label, self.enabled, self.action, self.hint, self.detail = \
            rect, label, enabled, action, hint, detail


class UI:
    def __init__(self):
        self.selected = None        # the unit shown on top of the selected stack
        self.group = []             # every unit of the selected stack
        self.picked = set()         # ids of the units in it that will move (tick boxes)
        self.province = None
        self.panel = None           # province, unit, country, market, ledger
        self.country = None         # tag shown in the country panel
        self.market = None
        self.reach = {}
        self.attacks = {}
        self.hover = None
        self.mouse = (0, 0)
        self.buttons = []
        self.toast = ""
        self.toast_until = 0
        self.reach2 = {}
        self.stops = set()
        self.path = []
        self.path_key = None
        self.speed = 3
        self.first_moves = 3
        self.order_route = None     # route whose merchant orders are open in the market panel
        self.hoverables = []        # (rect, card) areas that show a hover card
        self.anim = None            # (unit ids, route, start ms) of a move being shown
        self.hover_key = None
        self.hover_since = 0


class CampaignApp(GameMenu):
    def __init__(self, tiles_dir=None, player=None, map="europe", seed=None, load=None):
        self.settings = options.load()
        self.apply_display()
        self.tiles_dir = tiles_dir
        pygame.display.set_caption("Hexa: Age of Discovery")
        self.clock = pygame.time.Clock()
        self.font = pygame.font.SysFont("segoeui,arial", 14)
        self.small = pygame.font.SysFont("segoeui,arial", 12)
        self.bold = pygame.font.SysFont("segoeui,arial", 15, bold=True)
        self.title = pygame.font.SysFont("segoeui,arial", 20, bold=True)
        self.big = pygame.font.SysFont("georgia,timesnewroman,serif", 30, bold=True)
        if map == "random" and seed is None:
            import random
            seed = random.randrange(1, 100000)
        loaded = saves.load(load) if load else None
        if load and loaded is None:          # never quietly start some other game instead
            raise saves.LoadError(f"{saves.slot_name(load)} could not be loaded.")
        self.world = loaded or CampaignWorld(seed if seed is not None else 1480, map=map)
        pygame.display.set_caption(f"Hexa: Age of Discovery  -  {self.world.geo.name}")
        self.view = MapView(self.world, tiles_dir)
        self.ui = UI()
        self.camera = [0.0, 0.0]
        self.drag = None
        self.running = True
        self.result = None
        self.busy = False
        self._mini = None
        self._mini_key = None
        self.view.zoom = 1
        self.look_at(geo.hex_of(*self.world.geo.START))
        if loaded:
            self.load_world(loaded)
            self.toast(f"Loaded {saves.slot_name(load)}: {loaded.date()}.")
        elif player:
            self.choose_named(player)

    def load_world(self, world):
        """Switch to a loaded world: fresh map view and selection, camera on the player's capital."""
        self.world = world
        self.view = MapView(world, self.tiles_dir)
        self.ui = UI()
        self._mini_key = None
        self.busy = False
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
        if not rect.collidepoint(pixel):
            return None
        return self.view.hex_at(pixel[0] - rect.x + self.camera[0], pixel[1] - rect.y + self.camera[1])

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
        world.message(f"You lead {world.countries[tag].name}. Grow your economy, trade, and reach for the New World.")
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

    def refresh(self):
        ui, world = self.ui, self.world
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
        ready = [u for u in self.world.units_of(self.player) if u.moves_left > 0 and not isinstance(u.goal, tuple)]
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
    def end_turn(self):
        world = self.world
        if not self.player or world.over:
            return
        self.busy = True
        self.draw()
        pygame.display.flip()
        for tag in world.countries:
            if tag != self.player:
                ai.run(world, tag)
        world.end_round()
        self._advance_orders()
        self.busy = False
        self.refresh()
        self.autosave()

    def _advance_orders(self):
        """Units with a far-away destination keep moving toward it each season, stacks together."""
        world = self.world
        orders = {}
        for unit in world.units_of(self.player):
            if isinstance(unit.goal, tuple) and not unit.carrier:
                orders.setdefault((unit.pos, unit.goal), []).append(unit)
        for (pos, goal), group in orders.items():
            if pos == goal:
                for unit in group:
                    unit.goal = None
                continue
            reach = world.reachable_group(group)
            dest = goal if goal in reach else world.step_toward_group(group, goal)
            if dest == pos:
                for unit in group:
                    unit.goal = None
            else:
                world.move_group(group, dest)
                if dest == goal:
                    for unit in group:
                        unit.goal = None

    # ----- input -------------------------------------------------------------------------
    def handle(self, event):
        ui = self.ui
        if event.type == pygame.KEYDOWN and event.key == pygame.K_F11:
            self.toggle_fullscreen()
            return
        if event.type == pygame.KEYDOWN and event.key == pygame.K_F5 and not self.busy:
            self.save_to("quick")
            return
        if event.type == pygame.KEYDOWN and event.key == pygame.K_F9 and not self.busy:
            self.quickload()
            return
        if self.menu:
            self.menu_handle(event)
            return
        if event.type == pygame.QUIT:
            self.running, self.result = False, "quit"
        elif event.type == pygame.KEYDOWN:
            key = event.key
            if key == pygame.K_ESCAPE:
                if ui.selected or ui.panel:
                    ui.selected, ui.panel, ui.province = None, None, None
                    self.refresh()
                else:
                    self.open_menu()
            elif key == pygame.K_m:
                self.open_menu()
            elif key in (pygame.K_SPACE, pygame.K_RETURN) and self.player:
                self.end_turn()
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
            elif key == pygame.K_l:
                ui.panel = "ledger" if ui.panel != "ledger" else None
            elif key == pygame.K_c and self.player:
                self.open_country(self.player)
            elif key == pygame.K_b and ui.selected and ui.selected.owner == self.player:
                worker = next((u for u in self.active() if u.kind is COLONIST), None)
                if worker:
                    self.press(("found", worker, False))
        elif event.type == pygame.MOUSEWHEEL:
            if not self.panel_rect().collidepoint(ui.mouse) or not ui.panel:
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
                self.drag = 0
        elif event.type == pygame.MOUSEBUTTONUP and event.button in (2, 3):
            if event.button == 3 and (self.drag or 0) < 6:
                self.right_click(event.pos)
            self.drag = None

    def panel_rect(self):
        return pygame.Rect(WIDTH - PANEL_W, TOP, PANEL_W, HEIGHT - TOP)

    def left_click(self, pixel):
        ui, world = self.ui, self.world
        for button in ui.buttons:
            if button.rect.collidepoint(pixel):
                if button.enabled:
                    self.press(button.action)
                elif button.hint:
                    self.toast(button.hint)
                return
        if ui.panel and self.panel_rect().collidepoint(pixel):
            return
        if self.minimap_rect().collidepoint(pixel):
            mini = self.minimap_rect()
            col = int((pixel[0] - mini.x) / mini.w * world.cols)
            row = int((pixel[1] - mini.y) / mini.h * world.rows)
            self.look_at((col, row))
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
        if pos in ui.attacks:
            world.attack_group(group, pos)
        elif pos in ui.reach and pos != here:
            for unit in group:
                unit.goal = None
            if world.move_group(group, pos):
                self.animate()
        elif pos != here:
            dest = world.step_toward_group(group, pos)
            if dest != here:
                for unit in group:
                    unit.goal = pos
                if world.move_group(group, dest):
                    self.animate()
                self.toast("On their way: they keep moving there in the coming seasons.")
            else:
                self.toast("They cannot get there.")
        ui.group = [u for u in group if u in world.units]
        ui.picked = {u.id for u in ui.group}
        self.refresh()

    def animate(self):
        """Slide the stack that just moved along its route on the map."""
        ids, path = getattr(self.world, "last_move", ((), []))
        self.ui.anim = (ids, path, pygame.time.get_ticks()) if len(path) > 1 else None

    def open_country(self, tag):
        self.ui.panel, self.ui.country = "country", tag

    def press(self, action):
        world, ui, tag = self.world, self.ui, self.player
        kind = action[0]
        if kind == "game_menu":
            self.open_menu()
        elif kind == "mode":
            self.view.mode = action[1]
        elif kind == "panel":
            if action[1] == "country":
                self.open_country(tag)
            elif action[1] == "market":
                ui.panel = "market"
                prov = ui.province if ui.province and ui.province.market else world.provinces[world.countries[tag].capital]
                ui.market = prov.market
            else:
                ui.panel = action[1] if ui.panel != action[1] else None
        elif kind == "choose":
            self.choose(action[1])
        elif kind == "end":
            self.end_turn()
        elif kind == "build":
            world.build(tag, action[1], action[2])
        elif kind == "recruit":
            unit = world.recruit(tag, action[1], action[2])
            if unit and not unit.kind.war and unit.kind is not GENERAL:
                self.select_unit(unit, only=True)
        elif kind == "invest":
            if not world.invest(tag, action[1]):
                self.toast(world.invest_check(tag, action[1])[1])
        elif kind == "found":
            prov = world.found(action[1], trading_post=action[2])
            if prov:
                ui.selected, ui.province, ui.panel = None, prov, "province"
        elif kind == "pick":
            self.select_unit(action[1], only=True)
        elif kind == "toggle":
            ui.picked ^= {action[1].id}
        elif kind == "all":
            ui.picked = {u.id for u in ui.group} if len(ui.picked) < len(ui.group) else set()
        elif kind == "refit":
            if not world.refit(action[1]):
                self.toast(world.refit_check(action[1])[1])
        elif kind == "upgrade":
            if not world.upgrade(action[1], action[2]):
                self.toast(world.upgrade_check(action[1], action[2])[1])
        elif kind == "raise":
            ui.panel, ui.province = "raise", action[1]
        elif kind == "fund":
            if not world.fund_research(tag):
                self.toast("Not enough ducats")
        elif kind == "tax":
            world.countries[tag].tax = action[1]
            world.economy()
        elif kind == "war":
            world.declare_war(tag, action[1])
        elif kind == "peace":
            ok, text = world.peace_offer(tag, action[1], action[2])
            self.toast(text)
        elif kind == "merchant":
            if len(action) > 2:
                world.send_merchant(tag, action[1], action[2], action[3])
                ui.order_route = None
            else:
                ui.order_route = None if ui.order_route is action[1] else action[1]
        elif kind == "goods_view":
            self.view.mode, self.view.goods_view = "goods", action[1]
        elif kind == "forage":
            if not world.forage(self.active(), tag):
                self.toast(world.forage_check(self.active(), tag)[1])
        elif kind == "recall":
            world.recall_merchant(tag, action[1], action[2] if len(action) > 2 else None)
        elif kind == "market":
            ui.panel, ui.market = "market", action[1]
        elif kind == "country":
            self.open_country(action[1])
        elif kind == "province":
            ui.province, ui.panel = action[1], "province"
            self.look_at(action[1].pos)
        elif kind == "goto":
            self.look_at(action[1])
        self.refresh()

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

    # ----- drawing helpers --------------------------------------------------------------------
    def text(self, font, text, pos, color=TEXT, width=None):
        if width:
            while text and font.size(text)[0] > width:
                text = text[:-2] + "…" if len(text) > 2 else ""
        img = font.render(text, True, color)
        self.screen.blit(img, pos)
        return img.get_width()

    def button(self, rect, label, enabled, action, hint="", detail="", small=False):
        rect = pygame.Rect(rect)
        hovered = rect.collidepoint(self.ui.mouse)
        color = ((70, 95, 140) if hovered else (52, 74, 112)) if enabled else (44, 48, 56)
        pygame.draw.rect(self.screen, color, rect, border_radius=5)
        font = self.small if small else self.bold
        fg = TEXT if enabled else FAINT
        if detail:
            img = font.render(label, True, fg)
            self.screen.blit(img, img.get_rect(midleft=(rect.x + 8, rect.centery)))
            img = self.small.render(detail, True, MUTED if enabled else FAINT)
            self.screen.blit(img, img.get_rect(midright=(rect.right - 8, rect.centery)))
        else:
            img = font.render(label, True, fg)
            self.screen.blit(img, img.get_rect(center=rect.center))
        self.ui.buttons.append(Button(rect, label, enabled, action, hint, detail))
        return rect

    # ----- drawing ---------------------------------------------------------------------------
    def draw(self):
        ui = self.ui
        ui.buttons = []
        ui.hoverables = []
        self.world.ensure_markets()
        self._update_path()
        self.screen.fill(BG)
        self.view.draw(self.screen, self.view_rect(), self.camera, ui)
        self.draw_log()
        self.draw_minimap()
        self.draw_top()
        if ui.panel:
            self.draw_panel()
        self.draw_hint()
        if self.player is None:
            self.draw_choose_banner()
        if self.busy:
            self.banner("The other countries are making their moves...")
        if self.world.over:
            self.banner(f"The year {self.world.year()} has come. Final ranking: "
                        f"{', '.join(c.name for c in self.world.ranking()[:3])} lead. Press L for the ledger.")
        if self.menu:
            self.draw_menu()

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

    def banner(self, text):
        img = self.title.render(text, True, TEXT)
        box = img.get_rect(center=(WIDTH // 2 - (PANEL_W // 2 if self.ui.panel else 0), TOP + 40)).inflate(30, 16)
        pygame.draw.rect(self.screen, (15, 18, 24), box, border_radius=8)
        pygame.draw.rect(self.screen, GOLD, box, 1, border_radius=8)
        self.screen.blit(img, img.get_rect(center=box.center))

    def draw_choose_banner(self):
        self.banner("Choose your country: click any country on the map")

    def draw_top(self):
        world, screen = self.world, self.screen
        pygame.draw.rect(screen, BG, (0, 0, WIDTH, TOP))
        pygame.draw.line(screen, LINE, (0, TOP - 1), (WIDTH, TOP - 1))
        x = 12
        if self.player:
            country = world.countries[self.player]
            pygame.draw.rect(screen, country.color, (x, 12, 22, 22), border_radius=3)
            pygame.draw.rect(screen, (10, 10, 10), (x, 12, 22, 22), 1, border_radius=3)
            self.button((x - 2, 8, 28, 30), "", True, ("panel", "country"), "Your country: income, taxes, diplomacy (C)")
            pygame.draw.rect(screen, country.color, (x, 12, 22, 22), border_radius=3)
            x += 30
            x += self.text(self.title, country.name, (x, 10)) + 16
            balance = country.balance
            x += self.text(self.bold, f"{country.treasury:,.0f} ducats", (x, 14), GOLD) + 4
            x += self.text(self.small, f"({balance:+.1f}/season)", (x, 17), GOOD_C if balance >= 0 else BAD_C) + 14
            x += self.text(self.font, f"Merchants {len(country.orders)}/{world.merchants(self.player)}", (x, 14), MUTED) + 14
        x += self.text(self.bold, world.date(), (x, 14)) + 18
        for mode in MODES:
            w = self.small.size(mode.title())[0] + 16
            r = self.button((x, 10, w, 26), mode.title(), True, ("mode", mode), f"{mode.title()} map ({MODES.index(mode) + 1})",
                            small=True)
            if self.view.mode == mode:
                pygame.draw.rect(screen, GOLD, r, 1, border_radius=5)
                if mode == "goods":
                    sx = r.x
                    for view in GOODS_VIEWS:
                        sw = self.small.size(view.title())[0] + 12
                        b = self.button((sx, TOP + 4, sw, 22), view.title(), True, ("goods_view", view),
                                        {"chips": "What each tile makes", "deposits": "The goods as little objects on the land",
                                         "prices": "Today's price: green cheap, red dear (press 3 again to switch)"}[view],
                                        small=True)
                        if self.view.goods_view == view:
                            pygame.draw.rect(screen, GOLD, b, 1, border_radius=5)
                        sx += sw + 3
            x += w + 4
        if self.player:
            x += 10
            for label, panel in (("Market", "market"), ("Ledger", "ledger")):
                w = self.small.size(label)[0] + 16
                self.button((x, 10, w, 26), label, True, ("panel", panel), small=True)
                x += w + 4
            menu_x = x + 10
            end_w = max(64, min(120, WIDTH - menu_x - 64 - 20))
            self.button((WIDTH - end_w - 10, 7, end_w, 32), "End season" if end_w >= 110 else "End",
                        not self.busy and not world.over, ("end",), "Let the season pass (Space)")
        else:
            menu_x = WIDTH - 80
        self.button((menu_x, 10, 64, 26), "Menu", True, ("game_menu",), "Save, load, options and exit (Esc)",
                    small=True)

    def draw_log(self):
        lines = self.world.log[-5:]
        if not lines:
            return
        width = 560
        box = pygame.Rect(8, HEIGHT - 12 - 18 * len(lines), width, 18 * len(lines) + 6)
        shade = pygame.Surface(box.size, pygame.SRCALPHA)
        shade.fill((10, 12, 16, 175))
        self.screen.blit(shade, box)
        for i, line in enumerate(lines):
            self.text(self.small, line, (box.x + 8, box.y + 3 + i * 18), TEXT if i == len(lines) - 1 else MUTED, width - 16)

    def minimap_rect(self):
        w, h = self.world.cols + 1, self.world.rows
        right = WIDTH - (PANEL_W if self.ui.panel else 0) - 10
        return pygame.Rect(right - w, HEIGHT - h - 10, w, h)

    def draw_minimap(self):
        world = self.world
        key = (world.version, world.player)
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
            self._one_line(ui.toast)
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
            hint, key = self.province_card(ui.hover), ("hex", ui.hover)
        if key != ui.hover_key:
            ui.hover_key, ui.hover_since = key, now
        if hint is None:
            return
        if isinstance(hint, str):
            self._one_line(hint)
        elif now - ui.hover_since >= 350:
            self._card(*hint)

    def _one_line(self, text):
        ui = self.ui
        img = self.font.render(text, True, TEXT)
        box = img.get_rect(topleft=(ui.mouse[0] + 16, ui.mouse[1] + 18)).inflate(14, 8)
        box.clamp_ip(pygame.Rect(0, TOP, WIDTH, HEIGHT - TOP))
        pygame.draw.rect(self.screen, (12, 14, 18), box, border_radius=5)
        pygame.draw.rect(self.screen, LINE, box, 1, border_radius=5)
        self.screen.blit(img, img.get_rect(center=box.center))

    def _card(self, title, lines):
        ui = self.ui
        width = max([self.bold.size(title)[0]] + [self.font.size(t)[0] for t, _ in lines]) + 22
        width = min(width, 420)
        box = pygame.Rect(ui.mouse[0] + 18, ui.mouse[1] + 18, width, 32 + 19 * len(lines))
        box.clamp_ip(pygame.Rect(0, TOP, WIDTH, HEIGHT - TOP))
        shade = pygame.Surface(box.size, pygame.SRCALPHA)
        shade.fill((12, 14, 18, 240))
        self.screen.blit(shade, box)
        pygame.draw.rect(self.screen, GOLD, box, 1, border_radius=6)
        self.text(self.bold, title, (box.x + 10, box.y + 6), GOLD, width - 20)
        for i, (line, color) in enumerate(lines):
            self.text(self.font, line, (box.x + 10, box.y + 28 + i * 19), color, width - 20)

    def cost_lines(self, prov, kind):
        world = self.world
        market = prov.market if prov else None
        parts = [f"{kind.gold} ducats"] + [f"{n:g} {GOODS[g].name.lower()}" for g, n in kind.goods.items()]
        lines = [("Raise: " + " + ".join(parts), TEXT)]
        if prov and market:
            lines.append((f"   = {world.unit_cost(prov, kind)} ducats at the {market.name} market today", MUTED))
        food = f" + {FOOD_PER_TROOP:g} grain" if kind.war else ""
        lines.append((f"Upkeep: {kind.upkeep:g} ducats{food} a season", TEXT))
        if kind.war:
            lines.append((f"Takes {MANPOWER * 1000:,.0f} men from the province", TEXT))
        return lines

    def troop_card(self, kind, prov=None):
        if not kind.war:
            about = {"general": ["Joins a stack: +2 stack room", "+20% in his speciality (random)"],
                     "wagon": [f"Keeps its stack fed for {WAGON_SEASONS} seasons away from depots",
                               "Refills when back in supply"],
                     "scout": ["Moves 5, sees 3 hexes", "May cross enemy land in war"],
                     "pioneer": ["Builds fields, mines and lumber camps (press B on the tile)"],
                     "colonist": ["1,000 settlers: found a colony or trading post"],
                     "caravel": ["Fast explorer, sees far, carries 4 units"],
                     "carrack": ["Big ship, carries 8 units (needs a shipyard)"]}[kind.key]
            return kind.name, [(a, TEXT) for a in about] + self.cost_lines(prov, kind)
        strong = {"infantry": [("Strong: defending, holding castles (+30%)", GOOD_C),
                               ("Strong: against cavalry (+25% defense)", GOOD_C)],
                  "cavalry": [("Strong: open land +40%, moves 5", GOOD_C),
                              ("Weak: forests and hills -30%, castles -50%", BAD_C)],
                  "artillery": [("Strong: castles x2, fires 2 hexes away, no reply", GOOD_C),
                                (f"Speeds sieges (+{kind.siege} a season)", GOOD_C),
                                ("Weak: helpless up close (half defense)", BAD_C)]}[kind.branch]
        title = f"{kind.name}  ({BRANCH_NAMES[kind.branch].lower()}, {ERAS[kind.era][0]})"
        lines = [(f"Attack {kind.attack}   Defense {kind.defense}   HP {kind.hp}   Moves {kind.moves}", TEXT)]
        return title, lines + strong + self.cost_lines(prov, kind)

    def unit_card(self, unit):
        world = self.world
        lines = []
        if unit.kind.war:
            lines.append((f"HP {unit.hp}/{unit.kind.hp}   Attack {unit.kind.attack}+{unit.atk_up}   "
                          f"Defense {unit.kind.defense}+{unit.def_up}", TEXT))
            rank = unit.rank
            lines.append((f"Experience {unit.xp}" + (f" ({rank[1]}, +{(rank[2] - 1) * 100:.0f}%)" if rank[1] else
                                                      " (3 = Veteran, 7 = Elite)"), MUTED))
            lines.append(("Fed last season" if unit.supplied else "Hungry: no healing, loses strength",
                          GOOD_C if unit.supplied else BAD_C))
        elif unit.kind is WAGON:
            lines.append((f"Food for {unit.supplies} more season{'s' * (unit.supplies != 1)} away from depots", TEXT))
        lines.append((f"Moves {unit.moves_left}/{unit.kind.moves}", MUTED))
        return f"{world.countries[unit.owner].name}: {unit.label}", lines

    def province_card(self, pos):
        world, tag = self.world, self.player
        if tag and pos not in world.countries[tag].explored:
            return "Unknown", [("Nobody from your country has been here yet.", MUTED)]
        prov = world.provinces.get(pos)
        if not prov:
            return ("Lake" if world.terrain[pos] == "lake" else "Sea"), [("Ships only." if world.is_sea(pos) else
                                                                          "Nobody can cross it.", MUTED)]
        t = TERRAIN[prov.terrain]
        if prov.owner:
            who = world.countries[prov.owner].name + (" (colony)" if prov.colony else " (trading post)" if prov.trading_post else "")
        else:
            who = f"{prov.tribe} natives" if prov.natives > 0.5 else "Empty land"
        lines = [(f"{who}   ·   {t.name}: move {t.move}, defense +{t.defense * 100:.0f}%", TEXT)]
        if prov.good:
            line = f"{GOODS[prov.good].name}"
            if prov.owner:
                line += f": {prov.output:.1f} a season, worth {prov.value:.1f} ducats"
            if prov.works:
                line += f"  ({world.works_name(prov).lower()})"
            lines.append((line, TEXT))
        if prov.owner:
            lines.append((f"Peasants {prov.peasants:.0f}k  Burghers {prov.burghers:.0f}k  Nobles {prov.nobles:.0f}k"
                          f"   ·   food {prov.food * 100:.0f}%", TEXT))
            town = " ".join(x for x in (SETTLEMENTS[prov.settlement], CASTLES[prov.castle]) if x)
            if town:
                lines.append((town + (f"   garrison {prov.garrison}" if prov.castle else ""), MUTED))
        if prov.natives >= 0.5:
            lines.append((f"{prov.tribe} people: {prov.natives:.0f}k", MUTED))
        if tag:
            limit = world.supply_limit(tag, pos)
            lines.append((f"Feeds {limit} of your troops" + ("" if prov.owner == tag else " (foreign land: half)"), GOOD_C))
        if prov.market:
            lines.append((f"Market: {prov.market.name}", MUTED))
        here = world.units_at(pos)
        if here and (here[0].owner == tag or pos in world.visible):
            troops = [u for u in here if u.kind.war]
            lines.append((f"{world.countries[here[0].owner].name}: {len(here)} unit{'s' * (len(here) != 1)}"
                          + (f", {len(troops)} troops, power {world.stack_power(troops):.0f}" if troops else ""),
                          BAD_C if here[0].owner != tag else TEXT))
        return prov.name, lines

    def good_card(self, market, g):
        world = self.world
        good = GOODS[g]
        price = market.price[g]
        lines = [(f"Price {price:.2f} ducats (normal {good.price:g})",
                  BAD_C if price > good.price * 1.25 else GOOD_C if price < good.price * 0.8 else TEXT),
                 (f"Supply {market.supply[g]:.1f}   Demand {market.demand[g]:.1f}", TEXT),
                 (f"Made here {market.produced[g]:.1f}   In {market.imports[g]:.1f}   Out {market.exports[g]:.1f}", MUTED)]
        makers = sorted((p for p in market.provinces if p.good == g), key=lambda p: -p.output)
        if makers:
            lines.append(("Made in: " + ", ".join(p.name for p in makers[:3]) + (" ..." if len(makers) > 3 else ""), TEXT))
        users = [cls for cls, needs in NEEDS.items() if g in needs or (g in ("grain", "fish") and "food" in needs)]
        built = [b.name.lower() for b in BUILDINGS.values() if g in b.inputs or (g == "cotton" and b.key == "weaver")]
        if users or built:
            lines.append(("Bought by: " + ", ".join(users + built), TEXT))
        if g in ("grain", "fish"):
            lines.append((f"Troops eat {FOOD_PER_TROOP:g} grain each a season", MUTED))
        return f"{good.name} at {market.name}", lines

    # ----- panels ------------------------------------------------------------------------
    def draw_panel(self):
        rect = self.panel_rect()
        pygame.draw.rect(self.screen, PANEL_BG, rect)
        pygame.draw.line(self.screen, LINE, rect.topleft, rect.bottomleft)
        self.button((rect.right - 30, rect.y + 8, 22, 22), "×", True, ("panel", self.ui.panel), "Close (Esc)")
        panel = self.ui.panel
        if panel == "province" and self.ui.province:
            self.province_panel(self.ui.province)
        elif panel == "unit" and self.ui.selected:
            self.unit_panel(self.ui.selected)
        elif panel == "raise" and self.ui.province:
            self.raise_panel(self.ui.province)
        elif panel == "country" and self.ui.country:
            self.country_panel(self.ui.country)
        elif panel == "market" and self.ui.market:
            self.market_panel(self.ui.market)
        elif panel == "ledger":
            self.ledger_panel()

    def _heading(self, text, y, x=None):
        x = x if x is not None else WIDTH - PANEL_W + 14
        self.text(self.bold, text, (x, y), GOLD)
        pygame.draw.line(self.screen, LINE, (x, y + 20), (WIDTH - 14, y + 20))
        return y + 26

    def province_panel(self, prov):
        world, tag = self.world, self.player
        x, y = WIDTH - PANEL_W + 14, TOP + 10
        w = PANEL_W - 28
        self.text(self.title, prov.name, (x, y), width=w - 30)
        y += 30
        if prov.owner:
            country = world.countries[prov.owner]
            what = "Colony of " if prov.colony else "Trading post of " if prov.trading_post else ""
            pygame.draw.rect(self.screen, country.color, (x, y + 3, 12, 12))
            self.text(self.font, f"{what}{country.name}", (x + 18, y))
        else:
            self.text(self.font, f"Unclaimed: {prov.tribe} lands" if prov.tribe else "Unclaimed land", (x, y), MUTED)
        y += 20
        market = f"   Market: {prov.market.name}" + (" (far: -30%)" if prov.remote else "") if prov.market else ""
        self.text(self.small, f"{TERRAIN[prov.terrain].name}{', coast' if prov.coastal else ''}{market}", (x, y), MUTED, w)
        y += 20
        if prov.controller and prov.controller != prov.owner:
            self.text(self.font, f"Occupied by {world.countries[prov.controller].name}", (x, y), BAD_C)
            y += 20
        if prov.good:
            line = f"Produces {GOODS[prov.good].name.lower()}"
            if prov.owner:
                line += f": {prov.output:.1f} a season, worth {prov.value:.1f} ducats"
            self.text(self.font, line, (x, y), width=w)
        else:
            self.text(self.font, "Produces nothing of value", (x, y), MUTED)
        y += 26
        y = self._heading("People", y)
        if prov.owner:
            self.text(self.font, f"Peasants {prov.peasants:.1f}k   Burghers {prov.burghers:.1f}k   Nobles {prov.nobles:.1f}k",
                      (x, y), width=w)
            y += 20
            self.text(self.small, f"Food supply {prov.food * 100:.0f}%", (x, y), GOOD_C if prov.food >= 0.95 else BAD_C)
            if tag:
                self.text(self.small, f"Feeds {world.supply_limit(tag, prov.pos)} of your troops", (x + 130, y), MUTED)
            y += 18
        if prov.natives >= 0.1:
            self.text(self.font, f"{prov.tribe or 'Native'} people {prov.natives:.1f}k", (x, y), MUTED)
            y += 20
        if prov.colony:
            done = min(1.0, prov.pop / COLONY_DONE)
            pygame.draw.rect(self.screen, (50, 55, 64), (x, y + 2, w, 10), border_radius=4)
            pygame.draw.rect(self.screen, GOOD_C, (x, y + 2, w * done, 10), border_radius=4)
            self.text(self.small, f"Colony: {prov.pop:.1f}k of {COLONY_DONE:.0f}k people to become a full province",
                      (x, y + 14), MUTED)
            y += 34
        y += 4
        if prov.owner == tag and tag:
            if prov.busy:
                self.text(self.small, "This province has done its job for this season.", (x, y), GOLD)
                y += 18
            y = self._heading("The tile", y)
            if prov.good in WORKS:
                level = prov.works
                name = world.works_name(prov) or "Untouched land"
                pips = "".join("*" if i < level else "." for i in range(WORKS_LEVELS))
                self.text(self.font, f"{name}" + (f"  +{WORKS_BONUS * level * 100:.0f}%" if level else ""),
                          (x, y + 3), TEXT if level else MUTED, 190)
                self.text(self.small, pips, (x + 192, y + 5), GOLD)
                if level < WORKS_LEVELS:
                    nxt = WORKS[prov.good][level]
                    ok, reason = world.invest_check(tag, prov)
                    goods = ", ".join(f"{n:g} {GOODS[g].name.lower()}" for g, n in world.invest_goods(prov).items())
                    hint = reason or (f"Invest: {nxt} (+{WORKS_BONUS * 100:.0f}% {GOODS[prov.good].name.lower()}). "
                                      f"Needs {goods}, bought on the local market. Era {WORKS_ERA[level]}+.")
                    self.button((x + 230, y, w - 230, 23), f"Invest: {nxt}", ok, ("invest", prov), hint,
                                f"{world.invest_cost(prov)}", small=True)
                else:
                    self.text(self.small, "fully developed", (x + 240, y + 5), FAINT)
                y += 26
            for key, names in (("settlement", SETTLEMENTS), ("castle", CASTLES)):
                level = prov.settlement if key == "settlement" else prov.castle
                current = names[level] or ("Countryside" if key == "settlement" else "No castle")
                self.text(self.font, current, (x, y + 3), TEXT if level else MUTED, 150)
                queued = next((item for item in prov.queue if item[0] == key), None)
                if queued:
                    self.text(self.small, f"building, {queued[1]} season{'s' * (queued[1] != 1)} left", (x + 170, y + 5), GOLD)
                elif level < 3:
                    ok, reason = world.build_check(tag, prov, key)
                    goods = ", ".join(f"{n:g} {GOODS[g].name.lower()}" for g, n in world.build_goods(prov, key).items())
                    hint = reason or (("More people, taxes and building slots" if key == "settlement"
                                       else "Defends the land: +defense, longer sieges") +
                                      (f". Needs {goods} from the market." if goods else ""))
                    self.button((x + 160, y, w - 160, 23), f"To {names[level + 1].lower()}", ok, ("build", prov, key),
                                hint, f"{world.build_cost(prov, key)}", small=True)
                y += 26
            slots = SETTLEMENT_SLOTS[prov.settlement]
            y = self._heading(f"Buildings ({world.slots_used(prov)}/{slots} slots)", y + 2)
            for key, b in BUILDINGS.items():
                if b.needs_coast and not prov.coastal:
                    continue
                level = prov.level(key)
                queued = next((item for item in prov.queue if item[0] == key), None)
                label = f"{b.name} {'I' * level}" if level else b.name
                self.text(self.font, label, (x, y + 3), TEXT if level else MUTED, 150)
                if queued:
                    self.text(self.small, f"building, {queued[1]} season{'s' * (queued[1] != 1)} left", (x + 170, y + 5), GOLD)
                elif level < b.max_level:
                    ok, reason = world.build_check(tag, prov, key)
                    self.button((x + 160, y, w - 160, 23), "Upgrade" if level else "Build", ok,
                                ("build", prov, key), reason or b.hint, f"{world.build_cost(prov, key)}", small=True)
                else:
                    self.text(self.small, "complete", (x + 170, y + 5), FAINT)
                y += 26
            y += 4
            self.button((x, y, w, 28), "Raise units here...", not prov.busy, ("raise", prov),
                        "Infantry, cavalry, cannons, generals, scouts, pioneers, colonists and ships" if not prov.busy
                        else "This province already did its job this season", small=True)
            y += 34
        elif prov.owner and tag:
            self.button((x, y, w, 26), f"Diplomacy with {world.countries[prov.owner].name}", True,
                        ("country", prov.owner), small=True)
            y += 32
        if prov.market:
            self.button((x, y, w, 26), f"Open the {prov.market.name} market", True, ("market", prov.market), small=True)

    def unit_panel(self, unit):
        world, ui = self.world, self.ui
        x, y = WIDTH - PANEL_W + 14, TOP + 10
        w = PANEL_W - 28
        country = world.countries[unit.owner]
        group = ui.group or [unit]
        troops = [u for u in group if u.kind.war]
        title = unit.label if len(group) == 1 else f"Stack of {len(group)}"
        self.text(self.title, title, (x, y), width=w - 30)
        y += 30
        pygame.draw.rect(self.screen, country.color, (x, y + 3, 12, 12))
        line = country.name
        if troops and not unit.naval:
            line += f"   ·   {len(troops)}/{world.stack_limit(unit.owner, group)} troops   ·   power {world.stack_power(troops):.0f}"
        self.text(self.font, line, (x + 18, y), width=w - 18)
        y += 22
        if troops and not unit.naval and not unit.carrier:
            state, count, limit = world.supply_state(group)
            colour = {"supplied": GOOD_C, "wagon": GOLD, "foraging": GOLD, "cut off": BAD_C}[state]
            text = {"supplied": f"In supply (a depot within {SUPPLY_RANGE} hexes)",
                    "wagon": "Fed by the supply wagon", "foraging": "Foraging this season",
                    "cut off": "Cut off from supply: no healing, -1 HP a season"}[state]
            self.text(self.small, text, (x, y), colour, w - 130)
            over = count > limit
            self.text(self.small, f"land feeds {count}/{limit}", (x + w - 120, y), BAD_C if over else MUTED)
            self.hoverable((x, y, w, 16), ("Supply", [
                (f"Troops here eat {FOOD_PER_TROOP:g} grain each a season, bought on the local market.", TEXT),
                ("Towns, castles and ports are depots. A stack within "
                 f"{SUPPLY_RANGE} hexes of one, through land you control, is in supply.", TEXT),
                ("Enemy armies cut supply lines. Cut-off troops lose 1 HP a season and cannot heal.", BAD_C),
                (f"This land feeds {limit} troops (people and farms; half in foreign land).", TEXT),
                ("Bigger stacks lose 1 HP a season. Wagons and foraging keep stacks fed.", MUTED)]))
            y += 20
            if unit.owner == self.player and (state == "cut off" or
                                              (state != "supplied" and world.provinces.get(unit.pos) and
                                               world.provinces[unit.pos].owner != unit.owner)):
                ok, reason = world.forage_check(group, self.player)
                self.button((x, y, w, 24), "Forage the land", ok, ("forage",),
                            reason or "Feed the stack from this province: it loses people and half its goods", small=True)
                y += 28
        if unit.owner != self.player:
            for u in group[:14]:
                self.text(self.small, f"{u.label}   {u.hp}/{u.kind.hp} HP" if u.kind.war else u.label, (x, y), MUTED)
                y += 18
            return
        if unit.naval:
            moves = unit.moves_left
            self.text(self.font, f"Moves left {moves}/{unit.kind.moves}", (x, y))
            y += 24
            cargo = world.cargo(unit)
            y = self._heading(f"Cargo {len(cargo)}/{unit.kind.capacity}", y)
            for passenger in cargo:
                self.button((x, y, w, 24), passenger.label, True, ("pick", passenger),
                            "Select it (tick more to land them together), then right-click the coast", small=True)
                y += 28
            if not cargo:
                self.text(self.small, "Empty. Units board by moving onto the ship from the coast.", (x, y), MUTED, w)
            return
        self.text(self.small, "Ticked units move and fight together. Right-click to move or attack;", (x, y), MUTED, w)
        self.text(self.small, "right-click far away to march over several seasons.", (x, y + 15), MUTED, w)
        y += 36
        self.button((x, y, 110, 22), "Tick all / none", True, ("all",), small=True)
        y += 28
        for u in group[:13]:
            ticked = u.id in ui.picked
            self.button((x, y, 22, 22), "x" if ticked else "", True, ("toggle", u),
                        "Untick to leave this unit behind (split the stack)", small=True)
            label = u.label
            if u.kind.war:
                label += f"   {u.hp}/{u.kind.hp}"
            elif u.kind is GENERAL:
                label = f"General: {GENERAL_TRAITS[u.trait]}"
            color = TEXT if u.moves_left > 0 else MUTED
            if u.kind.war and not u.supplied:
                color = BAD_C
            self.text(self.small, label, (x + 28, y + 3), color, 196 if u.kind.war else w - 30)
            self.hoverable((x + 28, y, 196 if u.kind.war else w - 30, 22), self.unit_card(u))
            if u.kind.war:
                bx = x + w - 126
                ok, reason = world.refit_check(u)
                if u.kind.era < world.countries[u.owner].era:
                    self.button((bx, y, 52, 22), "Refit", ok, ("refit", u), reason or "Re-equip as the newest troops", small=True)
                for i, stat in enumerate(("attack", "defense")):
                    ok, reason = world.upgrade_check(u, stat)
                    level = u.atk_up if stat == "attack" else u.def_up
                    if level < UPGRADE_MAX:
                        cost = world.upgrade_cost(u, stat)
                        self.button((bx + 56 + i * 36, y, 32, 22), "+A" if stat == "attack" else "+D", ok,
                                    ("upgrade", u, stat), reason or f"Drill +1 {stat} for {cost} ducats", small=True)
            y += 26
        workers = [u for u in self.active() if u.kind is COLONIST]
        if workers:
            worker = workers[0]
            y += 4
            if True:
                ok, reason = world.found_check(worker)
                bw = (w - 6) // 2
                self.button((x, y, bw, 26), "Found colony (B)", ok, ("found", worker, False),
                            reason or "Settlers take this land; it grows into a full province", small=True)
                ok, reason = world.found_check(worker, trading_post=True)
                self.button((x + bw + 6, y, bw, 26), "Trading post", ok, ("found", worker, True),
                            reason or "Trade with the natives here: they keep the land, you get their goods", small=True)

    def raise_panel(self, prov):
        world, tag = self.world, self.player
        x, y = WIDTH - PANEL_W + 14, TOP + 10
        w = PANEL_W - 28
        country = world.countries[tag]
        self.text(self.title, f"Raise in {prov.name}", (x, y), width=w - 30)
        y += 32
        self.text(self.bold, ERAS[country.era][0], (x, y), GOLD)
        y += 22
        nxt = world.next_era(tag)
        if nxt:
            era, year, need = nxt
            done = min(1.0, country.research / need)
            pygame.draw.rect(self.screen, (50, 55, 64), (x, y + 2, w, 10), border_radius=4)
            pygame.draw.rect(self.screen, GOLD, (x, y + 2, w * done, 10), border_radius=4)
            self.text(self.small, f"Research {country.research:.0f}/{need} toward the {ERAS[era][0]} (not before {year})",
                      (x, y + 14), MUTED, w)
            y += 34
            gold, points = RESEARCH_FUND
            self.button((x, y, w, 24), f"Fund research: +{points}", country.treasury >= gold, ("fund",),
                        "Burghers do research on their own; ducats speed it up", f"{gold} ducats", small=True)
            y += 30
        y = self._heading("Troops", y + 4)
        for kind in world.raise_options(tag):
            if kind.naval and not prov.coastal:
                continue
            if kind is CARAVEL:
                y = self._heading("Others", y + 4)
            ok, reason = world.recruit_check(tag, prov, kind)
            label = f"{kind.name}  {kind.attack}/{kind.defense}  mv {kind.moves}" if kind.war else kind.name
            title, lines = self.troop_card(kind, prov)
            if reason:
                lines = [(reason, BAD_C)] + lines
            self.button((x, y, w, 25), label, ok, ("recruit", prov, kind), (title, lines),
                        f"{world.unit_cost(prov, kind)} ducats", small=True)
            y += 29
        self.button((x, y + 6, w, 24), "Back to the province", True, ("province", prov), small=True)

    def country_panel(self, tag):
        world = self.world
        x, y = WIDTH - PANEL_W + 14, TOP + 10
        w = PANEL_W - 28
        country = world.countries[tag]
        pygame.draw.rect(self.screen, country.color, (x, y + 4, 18, 18), border_radius=3)
        self.text(self.title, country.name, (x + 26, y))
        y += 32
        provs = world.provinces_of(tag)
        self.text(self.font, f"{len(provs)} provinces, {world.total_pop(tag):,.0f}k people, "
                             f"army {world.army_strength(tag)} regiments", (x, y), width=w)
        y += 20
        colonies = world.colonies_of(tag)
        if colonies:
            self.text(self.font, f"{len(colonies)} colonies and trading posts", (x, y))
            y += 20
        if self.player is None:
            y += 10
            self.text(self.font, f"Treasury {country.treasury:,.0f} ducats, {country.balance:+.1f} a season", (x, y))
            y += 30
            self.button((x, y, w, 36), f"Play as {country.name}", True, ("choose", tag),
                        "Start the campaign with this country")
            y += 50
            tips = {"POR": "Best placed to sail around Africa and across the Atlantic.",
                    "CAS": "Big, rich, and close to the Atlantic.", "ENG": "An island with good harbours.",
                    "VEN": "Rich in trade but walled in by the Mediterranean.",
                    "TUR": "Huge and strong, far from the Atlantic."}
            if tag in tips:
                self.text(self.small, tips[tag], (x, y), MUTED, w)
            return
        if tag == self.player:
            y += 6
            y = self._heading("Treasury", y)
            self.text(self.font, f"{country.treasury:,.0f} ducats", (x, y), GOLD)
            y += 22
            for key, label in (("production", "Taxes on goods produced"), ("taxes", "Taxes on people"),
                               ("buildings", "Manufactories"), ("trade", "Trade (merchants and tolls)"),
                               ("upkeep", "Building upkeep"), ("military", "Armies and ships"),
                               ("colonies", "Young colonies"), ("interest", "Interest on debt")):
                if key not in country.income:
                    continue
                value = country.income[key]
                self.text(self.small, label, (x, y), MUTED)
                self.text(self.small, f"{value:+.1f}", (x + w - 60, y), GOOD_C if value >= 0 else BAD_C)
                y += 17
            self.text(self.bold, "Each season", (x, y + 2))
            self.text(self.bold, f"{country.balance:+.1f}", (x + w - 60, y + 2), GOOD_C if country.balance >= 0 else BAD_C)
            y += 28
            self.text(self.font, "Tax level", (x, y + 4))
            bx = x + 90
            for level in TAX_LEVELS:
                r = self.button((bx, y, 82, 26), level.title(), True, ("tax", level),
                                {"low": "Less money, people grow faster", "normal": "Balanced",
                                 "high": "More money, people grow slower"}[level], small=True)
                if country.tax == level:
                    pygame.draw.rect(self.screen, GOLD, r, 1, border_radius=5)
                bx += 88
            y += 36
            y = self._heading("Wars", y)
            enemies = world.enemies(tag)
            if not enemies:
                self.text(self.small, "At peace. Click a neighbour's province to declare war.", (x, y), MUTED)
                y += 20
            for enemy in sorted(enemies):
                name = world.countries[enemy].name
                score = world.war_score(tag, enemy)
                self.text(self.font, f"{name} (war score {score:+d})", (x, y))
                y += 22
                bw = (w - 8) // 3
                self.button((x, y, bw, 24), "Take land", True, ("peace", enemy, "take"),
                            "Demand the provinces you occupy", small=True)
                self.button((x + bw + 4, y, bw, 24), "White peace", True, ("peace", enemy, "white"),
                            "Everyone keeps their own land", small=True)
                self.button((x + 2 * bw + 8, y, bw, 24), "Give up", True, ("peace", enemy, "yield"),
                            "They keep what they occupy", small=True)
                y += 30
            y += 4
            y = self._heading(f"Merchants {len(country.orders)}/{world.merchants(tag)}", y)
            for rid, g, src in country.orders[:6]:
                route = next((r for r in world.routes if r.id == rid), None)
                if not route:
                    continue
                dst = route.b.name if src == route.a.name else route.a.name
                result = next((res for res in route.results if res[0] == tag and res[1] == g), None)
                profit = f"{result[3]:+.0f}" if result else "new"
                self.text(self.small, f"{GOODS[g].name}: {src} > {dst}  ({profit} last season)", (x, y + 4),
                          BAD_C if result and result[3] < 0 else TEXT, w - 70)
                self.button((x + w - 64, y, 64, 22), "Recall", True, ("recall", route, (g, src)), small=True)
                y += 26
            free = world.merchants(tag) - len(country.orders)
            if free > 0:
                self.text(self.small, f"{free} merchant{'s' * (free != 1)} free: open a market, press + on a route.",
                          (x, y), GOLD)
                y += 20
            self.button((x, y + 4, w, 26), "Open your home market", True, ("panel", "market"), small=True)
            return
        # Another country
        y += 6
        relation = "at war with you" if world.at_war(tag, self.player) else "at peace with you"
        self.text(self.font, f"Treasury about {country.treasury:,.0f} ducats; {relation}.", (x, y), width=w)
        y += 28
        if world.at_war(tag, self.player):
            score = world.war_score(self.player, tag)
            self.text(self.font, f"War score {score:+d}", (x, y))
            y += 24
            for label, terms, hint in (("Demand the land you occupy", "take", "They accept if you are clearly winning"),
                                       ("Offer white peace", "white", "Everyone keeps their own land"),
                                       ("Give up", "yield", "They keep what they occupy")):
                self.button((x, y, w, 26), label, True, ("peace", tag, terms), hint, small=True)
                y += 30
        else:
            ok, reason = world.war_check(self.player, tag)
            self.button((x, y, w, 28), f"Declare war on {country.name}", ok, ("war", tag),
                        reason or "Armies can then enter their land and occupy provinces", small=True)
            y += 34
        self.button((x, y, w, 26), "Show their capital", True, ("goto", country.capital), small=True)

    def market_panel(self, market):
        world, tag = self.world, self.player
        x, y = WIDTH - PANEL_W + 14, TOP + 10
        w = PANEL_W - 28
        owner = world.market_owner(market)
        self.text(self.title, f"{market.name} market", (x, y))
        y += 28
        self.text(self.small, f"Centre held by {world.countries[owner].name if owner else 'nobody'}, "
                              f"{len(market.provinces)} provinces trade here", (x, y), MUTED, w)
        y += 22
        cols = (x, x + 92, x + 158, x + 220, x + 282)
        for cx, label in zip(cols, ("Good", "Price", "Supply", "Demand", "Trade")):
            self.text(self.small, label, (cx, y), MUTED)
        y += 18
        for g, good in GOODS.items():
            supply, demand = market.supply.get(g, 0), market.demand.get(g, 0)
            if supply < 0.05 and demand < 0.05 and good.kind != "money":
                continue
            price = market.price[g]
            ratio = price / good.price
            color = BAD_C if ratio > 1.25 else GOOD_C if ratio < 0.8 else TEXT
            pygame.draw.rect(self.screen, good.color, (cols[0], y + 4, 8, 8))
            self.text(self.small, good.name, (cols[0] + 12, y))
            self.hoverable((x, y, w, 16), self.good_card(market, g))
            self.text(self.small, f"{price:.2f}", (cols[1], y), color)
            self.text(self.small, f"{supply:.1f}", (cols[2], y))
            self.text(self.small, f"{demand:.1f}", (cols[3], y))
            net = market.imports.get(g, 0) - market.exports.get(g, 0)
            if abs(net) >= 0.05:
                self.text(self.small, f"{'in' if net > 0 else 'out'} {abs(net):.1f}", (cols[4], y), GOOD_C if net > 0 else GOLD)
            y += 16
        y += 6
        y = self._heading("Trade routes", y)
        mine = tag and market in world.merchant_markets(tag)
        routes = sorted(world.routes_of(market), key=lambda r: -r.profit)
        if self.ui.order_route in routes:
            routes.remove(self.ui.order_route)
            routes.insert(0, self.ui.order_route)
        for route in routes[:7]:
            if y > HEIGHT - 40:
                break
            other = route.other(market)
            goods = ", ".join(sorted({GOODS[f[0]].name.lower() for f in route.flows})[:3]) or "nothing"
            self.text(self.small, f"{other.name}{' (sea)' if route.sea else ''}: trade carries {goods}",
                      (x, y + 3), TEXT, w - 40)
            self.hoverable((x, y, w - 40, 22), (f"{market.name} - {other.name}", [
                ("Background trade moves goods from cheap to dear by itself.", TEXT),
                (f"Moving a unit costs {route.cost:.2f} ducats; market owners take tolls.", MUTED),
                ("Press + to give one of your merchants an order on this route:", TEXT),
                ("export or import a good you choose. The profit (or loss) is yours.", GOOD_C)]))
            if tag:
                ok, reason = world.send_merchant_check(tag, route)
                self.button((x + w - 34, y, 32, 22), "+", ok, ("merchant", route),
                            reason or "Give a merchant an order on this route", small=True)
            y += 25
            if tag:
                for owner, g, src in route.orders:
                    if owner != tag:
                        continue
                    dst = route.b.name if src == route.a.name else route.a.name
                    result = next((res for res in route.results if res[0] == tag and res[1] == g), None)
                    note = f"{result[3]:+.0f} last season" if result else "starts next season"
                    self.text(self.small, f"  your merchant: {GOODS[g].name.lower()} {src} > {dst}, {note}", (x, y + 2),
                              BAD_C if result and result[3] < 0 else GOLD, w - 70)
                    self.button((x + w - 64, y, 64, 20), "Recall", True, ("recall", route, (g, src)), small=True)
                    y += 23
            if tag and self.ui.order_route is route:
                options = world.merchant_options(tag, route)[:5]
                if not options:
                    self.text(self.small, "  Nothing worth carrying on this route right now.", (x, y), MUTED)
                    y += 20
                for g, src, dst, margin, amount in options:
                    verb = "Export" if src in world.merchant_markets(tag) else "Import"
                    label = f"{verb} {GOODS[g].name.lower()}: {src.name} > {dst.name}"
                    detail = f"{margin:+.1f} x {amount:.0f} = {margin * amount:+.0f}"
                    self.button((x + 10, y, w - 10, 22), label, margin > 0 or True, ("merchant", route, g, src), (
                        f"{verb} {GOODS[g].name.lower()}", [
                            (f"Buy {amount:.0f} at {src.price[g]:.2f} in {src.name}, sell at {dst.price[g]:.2f} in {dst.name}", TEXT),
                            (f"Transport {route.cost:.2f} a unit: {margin:+.2f} a unit, about {margin * amount:+.0f} a season",
                             GOOD_C if margin > 0 else BAD_C),
                            ("Exporting raises the price at home; importing lowers it.", MUTED)]), detail, small=True)
                    y += 25
        if tag and not mine:
            self.text(self.small, "Your merchants can only work routes from markets where you own land.", (x, y + 4), MUTED, w)

    def ledger_panel(self):
        world = self.world
        x, y = WIDTH - PANEL_W + 14, TOP + 10
        self.text(self.title, "Ledger", (x, y))
        y += 32
        for cx, label in zip((x, x + 26, x + 190, x + 245, x + 305), ("#", "Country", "Score", "Income", "Colonies")):
            self.text(self.small, label, (cx, y), MUTED)
        y += 18
        for i, country in enumerate(world.ranking()[:28]):
            color = GOLD if country.tag == self.player else TEXT
            self.text(self.small, str(i + 1), (x, y), MUTED)
            pygame.draw.rect(self.screen, country.color, (x + 26, y + 4, 9, 9))
            self.text(self.small, country.name, (x + 40, y), color, 145)
            self.text(self.small, str(world.score(country.tag)), (x + 190, y), color)
            self.text(self.small, f"{country.balance:.0f}", (x + 245, y), color)
            self.text(self.small, str(len(world.colonies_of(country.tag))), (x + 305, y), color)
            y += 20

    # ----- loop ---------------------------------------------------------------------------
    def run(self):
        while self.running:
            for event in pygame.event.get():
                self.handle(event)
            self.scroll()
            self.draw()
            pygame.display.flip()
            self.clock.tick(60)
        return self.result
