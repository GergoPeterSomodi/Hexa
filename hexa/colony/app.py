"""The colonisation mode window: mouse, keyboard, scrolling camera and computer turns."""
import pygame

from ..hexgrid import pixel_to_hex
from ..render import Button
from . import ai
from .render import (END_TURN_RECT, MAP_MARGIN, MINI_CELL, VIEW_H, WINDOW_SIZE, ColonyRenderer, button_rects,
                     map_pixel_size, minimap_rect)
from .rules import (BUYABLE, COLONIST, COLONIST_FOOD, FOOD_LOT, FOOD_LOT_PRICE, FUR_PRICE, GIFT_COST,
                    GOAL_INDEPENDENCE, GOAL_NAMES, GROW_COST, IMPROVEMENT_FOR_TERRAIN, INDEPENDENCE_TURNS,
                    PIONEER, PLAYER, SHIP, START_NAMES, STOCKADE_COST, TRADE_GET, TRADE_GIVE, TRAINABLE,
                    TRIBE_NAMES, WOOD_LOT, WOOD_LOT_PRICE, cost_text)
from .world import ColonyWorld

AI_STEP_MS = 300
SCROLL_SPEED = 14
DESCRIBE = {
    "scout": "Scout: fast, sees far. Visiting a native village for the first time brings gifts.",
    "pioneer": "Pioneer: builds farms, fisheries, trapper camps and silver mines on your land.",
    "soldier": "Soldier: fights and captures colonies. Eats 1 food per turn.",
    "colonist": "Colonist: founds a new colony, or joins one to add population.",
}


class UIState:
    def __init__(self):
        self.selected = None
        self.colony = None
        self.village = None
        self.reach = {}
        self.attacks = {}
        self.buttons = []
        self.status = ""
        self.hover = None
        self.hover_button = None
        self.end_hover = False


class ColonyApp:
    def __init__(self, screen, tiles_dir, seed=None, start="sea", goal="survive"):
        self.screen = screen
        self.renderer = ColonyRenderer(screen, tiles_dir)
        self.clock = pygame.time.Clock()
        self.running = True
        self.result = None           # "menu" or "quit" when the loop ends
        self.settings = (start, goal)
        self.drag = None
        self.new_game(seed)

    def new_game(self, seed=None):
        start, goal = self.settings
        self.world = ColonyWorld(seed, start, goal)
        self.ui = UIState()
        self.ai_turn = None
        self.ai_next = 0
        self.camera = [0, 0]
        pygame.display.set_caption(f"Hexa colonies  -  {START_NAMES[start]}, {GOAL_NAMES[goal]}  -  map #{self.world.seed}")
        self.select_next()
        if not self.ui.selected:
            self.look_at(self.world.landings[PLAYER][0])
        self.refresh()

    # ----- camera ----------------------------------------------------------------
    def look_at(self, pos):
        x, y = self.renderer.center(pos)
        x, y = x - self.renderer.origin[0], y - self.renderer.origin[1]
        self.camera = [x - WINDOW_SIZE[0] / 2, y - VIEW_H / 2]
        self.clamp_camera()

    def clamp_camera(self):
        width, height = map_pixel_size(self.world)
        self.camera[0] = max(0, min(width - WINDOW_SIZE[0], self.camera[0]))
        self.camera[1] = max(0, min(max(0, height - VIEW_H), self.camera[1]))
        self.renderer.origin = (MAP_MARGIN - self.camera[0], MAP_MARGIN - self.camera[1])

    def on_screen(self, pos):
        x, y = self.renderer.center(pos)
        return 60 < x < WINDOW_SIZE[0] - 60 and 60 < y < VIEW_H - 60

    def hex_at(self, pixel):
        if pixel[1] >= VIEW_H:
            return None
        return pixel_to_hex(pixel, self.renderer.origin)

    # ----- selection --------------------------------------------------------------
    def select(self, unit=None, colony=None, village=None):
        self.ui.selected, self.ui.colony, self.ui.village = unit, colony, village
        self.refresh()

    def refresh(self):
        world, ui = self.world, self.ui
        mine = world.current == PLAYER and not world.winner
        if ui.selected and (ui.selected not in world.units or not mine):
            ui.selected = None
        if ui.colony and (ui.colony.owner != PLAYER or ui.colony not in world.colonies or not mine):
            ui.colony = None
        if ui.village and (ui.village.burned or not mine):
            ui.village = None
        ui.reach, ui.attacks, ui.buttons = {}, {}, []
        unit, colony, village = ui.selected, ui.colony, ui.village
        if unit:
            self._unit_panel(unit)
        elif colony:
            self._colony_panel(colony)
        elif village:
            self._village_panel(village)
        elif mine:
            ui.status = "Click one of your units or colonies. Click a native village to gift or trade."
        else:
            ui.status = ""
        for button, rect in zip(ui.buttons, button_rects(len(ui.buttons))):
            button.rect = rect
        ui.hover_button = None

    def _unit_panel(self, unit):
        world, ui = self.world, self.ui
        ui.reach = world.reachable(unit)
        ui.attacks = {p: s for p, s in world.attack_options(unit).items() if p in world.visible}
        t = unit.type
        ui.status = f"{t.name}   HP {unit.hp}/{t.max_hp}   Moves {unit.moves_left}/{t.moves}"
        ui.status += f"   Attack {t.attack}   Defense {t.defense}" if t.attack else "   Cannot fight"
        add = ui.buttons.append
        if unit.carrier:
            ui.status += "   |   Aboard ship: click a highlighted land hex to go ashore (costs 1 move)"
        if t is PIONEER:
            improvement, reason = world.build_check(unit)
            shown = improvement or IMPROVEMENT_FOR_TERRAIN.get(world.terrain[unit.pos])
            label = f"Build {shown.name.split()[-1].lower()}" if shown else "Build"
            add(Button(None, label, cost_text(shown.cost) if shown else "-", improvement is not None, ("build",),
                       reason or f"Builds a {shown.name.lower()} here (B)"))
        elif t is COLONIST:
            ok, reason = world.found_check(unit)
            add(Button(None, "Found colony", "uses the colonist", ok, ("found",), reason or "Founds a new colony here (B)"))
            ok, reason = world.join_check(unit)
            add(Button(None, "Join colony", "+1 population", ok, ("join",), reason or "Joins the colony next to it (J)"))
        elif t is SHIP:
            cargo = world.cargo(unit)
            names = ", ".join(u.type.name.lower() for u in cargo) or "empty"
            ui.status += f"   |   Cargo {len(cargo)}/{t.capacity}: {names}"
            if world.at_homeland(unit):
                stock = world.stock[PLAYER]
                market = [("Sell furs", f"+{stock['furs'] * FUR_PRICE}G", ("sell_furs",),
                           f"Sell all furs for {FUR_PRICE} gold each. Furs win the Crown's favour: free colonists each spring"),
                          ("Sell wood", f"{WOOD_LOT}W > {WOOD_LOT_PRICE}G", ("sell_wood",), "Sell timber to the homeland"),
                          ("Buy food", f"{FOOD_LOT_PRICE}G > {FOOD_LOT}F", ("buy_food",), "Buy food for the colonies")]
                market += [(f"Buy {u.name.lower()}", f"{u.price}G", ("buy", u), DESCRIBE[u.key]) for u in BUYABLE]
                for label, detail, action, hint in market:
                    ok, reason = world.market_check(unit, action)
                    add(Button(None, label, detail, ok, action, reason or hint))
            else:
                for passenger in cargo[:7]:
                    add(Button(None, passenger.type.name, "select", True, ("pick", passenger),
                               f"Select this {passenger.type.name.lower()} to take it ashore"))
                if not cargo:
                    ui.status += "   |   Sail to the glowing east edge to trade with the homeland"

    def _colony_panel(self, colony):
        world, ui = self.world, self.ui
        gain = world.income_of_colony(colony)
        gains = ", ".join(f"{n:+} {r}" for r, n in gain.items() if n) or "nothing"
        worked = len(world.worked(colony))
        ui.status = (f"{colony.name}: population {colony.pop}, works {worked} building{'s' * (worked != 1)}. "
                     f"Per turn: {gains}.  One job per turn.")
        if colony.busy:
            ui.status = f"{colony.name} already did its job this turn. Per turn: {gains}."
        add = ui.buttons.append
        for unit_type in TRAINABLE:
            ok, reason = world.train_check(colony, unit_type)
            add(Button(None, unit_type.name, cost_text(unit_type.cost), ok, ("train", unit_type),
                       reason or DESCRIBE[unit_type.key]))
        ok, reason = world.colonist_check(colony)
        add(Button(None, "Colonist", f"1 pop {COLONIST_FOOD}F", ok, ("colonist",),
                   reason or "Sends out one of the people living here as a colonist"))
        ok, reason = world.grow_check(colony)
        add(Button(None, "Grow", f"+1 pop {cost_text(GROW_COST)}", ok, ("grow",),
                   reason or "Welcomes a new family: +1 population, so one more building gets worked"))
        ok, reason = world.stockade_check(colony)
        add(Button(None, "Stockade", cost_text(STOCKADE_COST), ok, ("stockade",),
                   reason or "Wooden walls: +2 defense for units inside"))
        if world.goal == GOAL_INDEPENDENCE:
            ok, reason = world.independence_check()
            add(Button(None, "Independence", "declare", ok, ("independence",),
                       reason or f"Declare independence! Survive {INDEPENDENCE_TURNS} turns against the royal army to win"))

    def _village_panel(self, village):
        world, ui = self.world, self.ui
        tribe = village.tribe
        mood = world.mood(tribe, PLAYER)
        visited = "visited by your scout" if PLAYER in village.visited else "not visited yet (send a scout)"
        ui.status = (f"Village of the {TRIBE_NAMES[tribe]}: {mood} towards you "
                     f"(tension {world.tension[tribe][PLAYER]}/100), {visited}.")
        ok, reason = world.gift_check(PLAYER, village)
        ui.buttons.append(Button(None, "Gift", cost_text(GIFT_COST), ok, ("gift", village),
                                 reason or "Calms the whole tribe; can end a war"))
        ok, reason = world.trade_check(PLAYER, village)
        ui.buttons.append(Button(None, "Trade", f"{cost_text(TRADE_GIVE)} > {cost_text(TRADE_GET)}", ok,
                                 ("trade", village), reason or "Swap timber for furs, once per village per turn"))

    def select_next(self):
        ready = [u for u in self.world.units_of(PLAYER) if u.moves_left > 0 and
                 not (u.carrier and not any(self.world.is_land(p) for p in self.world.reachable(u)))]
        if not ready:
            return
        current = self.ui.selected
        index = ready.index(current) + 1 if current in ready else 0
        unit = ready[index % len(ready)]
        self.select(unit)
        if not self.on_screen(unit.pos):
            self.look_at(unit.pos)

    # ----- actions -----------------------------------------------------------------
    def players_turn(self):
        return self.world.current == PLAYER and not self.world.winner and self.ai_turn is None

    def end_turn(self):
        if not self.players_turn():
            return
        self.select()
        self.world.end_turn()
        self._start_ai()

    def _start_ai(self):
        if self.world.winner or self.world.current == PLAYER:
            self.ai_turn = None
            return
        self.ai_turn = ai.take_turn(self.world, self.world.current)
        self.ai_next = 0

    def press(self, button):
        if not button.enabled or not self.players_turn():
            return
        world, kind = self.world, button.action[0]
        unit, colony = self.ui.selected, self.ui.colony
        if kind == "train":
            world.train(colony, button.action[1])
        elif kind == "colonist":
            world.make_colonist(colony)
        elif kind == "grow":
            world.grow(colony)
        elif kind == "stockade":
            world.build_stockade(colony)
        elif kind == "independence":
            world.declare_independence()
        elif kind == "build":
            world.build(unit)
        elif kind == "found":
            new = world.found_colony(unit)
            self.select(colony=new)
            return
        elif kind == "join":
            world.join(unit)
            self.select()
            return
        elif kind == "pick":
            self.select(button.action[1])
            return
        elif kind == "gift":
            world.gift(PLAYER, button.action[1])
        elif kind == "trade":
            world.trade(PLAYER, button.action[1])
        else:
            world.market(unit, button.action)
        self.refresh()

    def click(self, pixel):
        if END_TURN_RECT.collidepoint(pixel):
            self.end_turn()
            return
        for button in self.ui.buttons:
            if button.rect.collidepoint(pixel):
                self.press(button)
                return
        mini = minimap_rect(self.world)
        if mini.collidepoint(pixel):
            cell = MINI_CELL
            row = min(max((pixel[1] - mini.y) // cell, 0), self.world.rows - 1)
            shift = (row & 1) * cell // 2                     # odd rows are drawn half a cell to the right
            col = min(max((pixel[0] - mini.x - shift) // cell, 0), self.world.cols - 1)
            self.look_at((col, row))
            return
        pos = self.hex_at(pixel)
        if not self.players_turn() or pos is None or not self.world.in_bounds(pos):
            return
        world, selected = self.world, self.ui.selected
        unit = world.unit_at(pos)
        colony = world.colony_at(pos)
        own_colony = colony if colony and colony.owner == PLAYER else None
        if selected and pos in self.ui.attacks:
            world.attack(selected, pos)
        elif selected and pos in self.ui.reach and pos != selected.pos:
            world.move(selected, pos)
        elif unit and unit.owner == PLAYER and not (unit is selected and own_colony):
            self.select(unit)
            return
        elif own_colony:
            self.select(colony=own_colony)
            return
        elif world.village_at(pos) and pos in world.explored:
            self.select(village=world.village_at(pos))
            return
        else:
            self.select()
            return
        self.refresh()

    def hotkey(self, key):
        name = pygame.key.name(key)
        buttons = self.ui.buttons
        if name.isdigit() and 1 <= int(name) <= len(buttons):
            self.press(buttons[int(name) - 1])
            return
        wanted = {"b": ("build", "found"), "j": ("join",)}.get(name, ())
        for button in buttons:
            if button.action[0] in wanted:
                self.press(button)
                return

    def handle(self, event):
        if event.type == pygame.QUIT:
            self.running, self.result = False, "quit"
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.ui.selected or self.ui.colony or self.ui.village:
                    self.select()
                else:
                    self.running, self.result = False, "quit"
            elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                self.end_turn()
            elif event.key == pygame.K_TAB and self.players_turn():
                self.select_next()
            elif event.key == pygame.K_r:
                self.new_game()
            elif event.key == pygame.K_m:
                self.running, self.result = False, "menu"
            elif event.key == pygame.K_c:
                thing = self.ui.selected or self.ui.colony or self.ui.village
                if thing:
                    self.look_at(thing.pos)
            else:
                self.hotkey(event.key)
        elif event.type == pygame.MOUSEMOTION:
            if self.drag and event.buttons[2]:
                self.camera[0] -= event.rel[0]
                self.camera[1] -= event.rel[1]
                self.drag[1] += abs(event.rel[0]) + abs(event.rel[1])
                self.clamp_camera()
            self.ui.hover = self.hex_at(event.pos)
            self.ui.end_hover = END_TURN_RECT.collidepoint(event.pos)
            self.ui.hover_button = next((b for b in self.ui.buttons if b.rect.collidepoint(event.pos)), None)
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                self.click(event.pos)
            elif event.button == 3:
                self.drag = [event.pos, 0]
        elif event.type == pygame.MOUSEBUTTONUP and event.button == 3:
            if self.drag and self.drag[1] < 6:
                self.select()
            self.drag = None

    def scroll(self):
        keys = pygame.key.get_pressed()
        dx = (keys[pygame.K_RIGHT] or keys[pygame.K_d]) - (keys[pygame.K_LEFT] or keys[pygame.K_a])
        dy = (keys[pygame.K_DOWN] or keys[pygame.K_s]) - (keys[pygame.K_UP] or keys[pygame.K_w])
        if dx or dy:
            self.camera[0] += dx * SCROLL_SPEED
            self.camera[1] += dy * SCROLL_SPEED
            self.clamp_camera()

    # ----- computer turns -------------------------------------------------------------
    def update(self, now):
        if self.ai_turn is None or now < self.ai_next:
            return
        world = self.world
        for unit in self.ai_turn:
            if unit.pos in world.visible or world.winner:
                self.ai_next = now + AI_STEP_MS
                return
        if world.winner:
            self.ai_turn = None
        else:
            world.end_turn()
            self._start_ai()
            if self.ai_turn is None:
                self.select_next()
        self.refresh()

    def run(self):
        while self.running:
            for event in pygame.event.get():
                self.handle(event)
            self.scroll()
            self.update(pygame.time.get_ticks())
            self.renderer.draw(self.world, self.ui, self.camera)
            pygame.display.flip()
            self.clock.tick(60)
        return self.result
