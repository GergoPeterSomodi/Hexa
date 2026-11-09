"""Colonisation mode game state and rules. Nothing in here uses pygame.

Turn order each round: you, the Crimson Company, the Golden Company, the native tribes,
and (after you declare independence) the royal army. One turn is one season.
"""
import heapq
import itertools
import random
from dataclasses import dataclass, field

from ..hexgrid import distance, neighbors, within
from . import mapgen
from .rules import (BRAVE, BRAVE_EVERY, BRAVES_PER_VILLAGE, BUILDING_SCORE, BURN_LOOT, COLD_DAMAGE,
                    COLONISERS, COLONIST, COLONIST_FOOD, COLONY_BASE, COLONY_DEFENSE, COLONY_HEAL,
                    COLONY_NAMES, COLONY_SCORE, COLONY_SIGHT, CROWN, DRAW, FAVOUR_FOR_COLONIST,
                    FEVER_CHANCE, FIREWOOD, FOOD_LOT, FOOD_LOT_PRICE, FUR_PRICE, GIFT_CALM, GIFT_COST,
                    GOAL_ENDLESS, GOAL_INDEPENDENCE, GOAL_SURVIVE, GROW_COST, IMPROVEMENT_FOR_TERRAIN,
                    IMPROVEMENTS, INDEPENDENCE_POP, INDEPENDENCE_SOLDIERS, INDEPENDENCE_TURNS, MAP_COLS,
                    MAP_ROWS, MAX_POP, MIN_COLONY_SPACING, MIN_VILLAGE_SPACING, NATIVES, PIONEER, PLAYER,
                    POP_FOOD, POP_SCORE, RAID_FOOD, REGULAR, RESOURCES, REST_HEAL, RIVALS,
                    ROYAL_WAVE_EVERY, ROYAL_WAVE_SIZE, ROYAL_WAVES, SCOUT, SHIP, SIDE_NAMES, SOLDIER,
                    START_LAND, START_SEA, START_STOCK, STOCKADE_COST, STOCKADE_DEFENSE, SURVIVE_TURNS,
                    TENSION_BUILD, TENSION_BURN, TENSION_COLONY, TENSION_DECAY, TENSION_PEACE,
                    TENSION_WAR, TERRAIN, TERRITORY_RADIUS, TRADE_CALM, TRADE_GET, TRADE_GIVE,
                    TRIBE_NAMES, TURN_ORDER, VILLAGE_COUNT, VILLAGE_LAND, VILLAGE_REACH, WOOD_LOT,
                    WOOD_LOT_PRICE, cost_text, season, year)

INF = float("inf")


@dataclass(eq=False)
class Unit:
    id: int
    type: object
    owner: str
    pos: tuple
    hp: int
    moves_left: int
    acted: bool = False
    attacked: bool = False
    carrier: object = None      # the ship this unit is aboard
    home: object = None         # a brave's village
    ai_goal: object = None

    @property
    def label(self):
        return f"{SIDE_NAMES[self.owner]} {self.type.name.lower()}"

    @property
    def tribe(self):
        return self.home.tribe if self.home else None


@dataclass(eq=False)
class Colony:
    pos: tuple
    owner: str
    name: str
    pop: int = 1
    capital: bool = False
    stockade: bool = False
    busy: bool = False          # already did its one job this turn

    @property
    def label(self):
        return f"{self.name} ({SIDE_NAMES[self.owner].replace('Your', 'yours')})"


@dataclass(eq=False)
class Village:
    pos: tuple
    tribe: int
    burned: bool = False
    visited: set = field(default_factory=set)   # sides whose scouts have been here
    traded: dict = field(default_factory=dict)  # side -> turn it last traded
    timer: int = 0


class ColonyWorld:
    mode = "colony"

    def __init__(self, seed=None, start=START_SEA, goal=GOAL_SURVIVE, cols=MAP_COLS, rows=MAP_ROWS):
        self.seed = seed if seed is not None else random.randrange(1_000_000)
        self.rng = random.Random(self.seed)
        self.start, self.goal = start, goal
        self.cols, self.rows = cols, rows
        self.terrain, self.variants, self.landings, villages = mapgen.generate(cols, rows, self.rng, VILLAGE_COUNT)
        self.villages = [Village(pos, tribe) for pos, tribe in villages]
        self.tension = {t: dict.fromkeys(COLONISERS, 0) for t in range(len(TRIBE_NAMES))}
        self.war = {t: set() for t in range(len(TRIBE_NAMES))}
        self.colonies = []
        self.improvements = {}
        self.stock = {side: dict(START_STOCK) for side in COLONISERS}
        self.favour = dict.fromkeys(COLONISERS, 0)
        self.units = []
        self._ids = itertools.count(1)
        self._names = list(COLONY_NAMES)
        self.rng.shuffle(self._names)
        self.turn = 1
        self.current = PLAYER
        self.winner = None
        self.win_reason = ""
        self.log = []
        self.explored = set()
        self.visible = set()
        self.ai_memory = {}
        self.dead = set()                 # colonisers knocked out of the game
        self.declared = None              # turn independence was declared
        self.royal_waves = 0

        for side in COLONISERS:
            land, sea = self.landings[side]
            ship = self._new_unit(SHIP, side, sea)
            if start == START_SEA:
                for unit_type in (COLONIST, COLONIST, SOLDIER, PIONEER):
                    self._new_unit(unit_type, side, sea, carrier=ship)
            else:
                colony = self._add_colony(land, side, pop=2)
                self._new_unit(SOLDIER, side, colony.pos)
                self.spawn(PIONEER, side, colony.pos)
                self.spawn(SCOUT, side, colony.pos)
        for village in self.villages:
            self._new_unit(BRAVE, NATIVES, village.pos, home=village)
        self.update_visibility()
        if start == START_SEA:
            self.message("Spring 1610. Your ship reaches the New World. Pick a good spot on the coast and land!")
        else:
            self.message("Spring 1610. Your little colony must survive its first winter. Good luck!")

    # ----- lookups -------------------------------------------------------------
    def in_bounds(self, pos):
        return pos in self.terrain

    def terrain_at(self, pos):
        return TERRAIN[self.terrain[pos]]

    def is_ocean(self, pos):
        return self.terrain.get(pos) == "ocean"

    def is_land(self, pos):
        return pos in self.terrain and self.terrain_at(pos).passable

    def coastal(self, pos):
        return any(self.is_ocean(n) for n in neighbors(pos))

    def unit_at(self, pos):
        for unit in self.units:
            if unit.pos == pos and unit.carrier is None:
                return unit
        return None

    def cargo(self, ship):
        return [u for u in self.units if u.carrier is ship]

    def colony_at(self, pos):
        return next((c for c in self.colonies if c.pos == pos), None)

    def village_at(self, pos):
        return next((v for v in self.villages if v.pos == pos and not v.burned), None)

    def ruins_at(self, pos):
        return next((v for v in self.villages if v.pos == pos and v.burned), None)

    def units_of(self, side):
        return [u for u in self.units if u.owner == side]

    def colonies_of(self, side):
        return [c for c in self.colonies if c.owner == side]

    def capital_of(self, side):
        return next((c for c in self.colonies if c.owner == side and c.capital), None)

    def population(self, side):
        return sum(c.pop for c in self.colonies_of(side))

    def season(self):
        return season(self.turn)

    def date(self):
        return f"{self.season()} {year(self.turn)}"

    def message(self, text):
        self.log.append(text)
        del self.log[:-60]

    def _new_unit(self, unit_type, owner, pos, carrier=None, home=None):
        unit = Unit(next(self._ids), unit_type, owner, pos, unit_type.max_hp, unit_type.moves,
                    carrier=carrier, home=home)
        self.units.append(unit)
        return unit

    def spawn(self, unit_type, owner, near, home=None):
        """Put a new land unit on the nearest free land hex (within 3)."""
        for radius in range(4):
            spots = [p for p in within(near, radius) if self.is_land(p) and self.unit_at(p) is None
                     and not self.village_at(p) and self._colony_ok(owner, p)]
            if spots:
                return self._new_unit(unit_type, owner, min(spots, key=lambda p: (distance(p, near), p)), home=home)
        return None

    def _colony_ok(self, side, pos):
        colony = self.colony_at(pos)
        return colony is None or colony.owner == side

    # ----- who fights whom -----------------------------------------------------
    def can_attack(self, attacker, target):
        """Whether attacker may attack target (a Unit)."""
        a, b = attacker.owner, target.owner
        if a == b or target.carrier or target.type.naval:
            return False
        if a == NATIVES:
            return b in self.war[attacker.tribe]
        if a == CROWN:
            return b == PLAYER
        if b == CROWN:
            return a == PLAYER
        return True     # colonisers may attack each other, and natives (which starts a war)

    def hostile_to(self, side, unit):
        """Whether `unit` would attack `side` (used for healing, threats and raided buildings)."""
        if unit.owner == side:
            return False
        if unit.owner == NATIVES:
            return side in self.war[unit.tribe]
        if unit.owner == CROWN:
            return side == PLAYER
        if side == CROWN:
            return unit.owner == PLAYER
        return side != NATIVES

    def hostile_adjacent(self, side, pos):
        near = set(neighbors(pos))
        return any(u.pos in near and u.carrier is None and self.hostile_to(side, u) for u in self.units)

    def defense_at(self, unit, pos):
        bonus = self.terrain_at(pos).defense if self.is_land(pos) else 0
        colony = self.colony_at(pos)
        if colony and colony.owner == unit.owner:
            bonus += COLONY_DEFENSE + (STOCKADE_DEFENSE if colony.stockade else 0)
        if unit.type is BRAVE and unit.home and unit.home.pos == pos:
            bonus += COLONY_DEFENSE
        return unit.type.defense + bonus

    # ----- land and economy ----------------------------------------------------
    def village_land(self, pos):
        return next((v for v in self.villages if not v.burned and distance(v.pos, pos) <= VILLAGE_LAND), None)

    def territory_colony(self, pos):
        best = None
        for colony in self.colonies:
            d = distance(colony.pos, pos)
            if d <= TERRITORY_RADIUS and (best is None or d < best[0]):
                best = (d, colony)
        return best[1] if best else None

    def territory_owner(self, pos):
        if self.village_land(pos):
            return NATIVES
        colony = self.territory_colony(pos)
        return colony.owner if colony else None

    def improvement_yield(self, key):
        imp = IMPROVEMENTS[key]
        if self.season() == "Winter" and imp.winter is not None:
            return imp.winter
        return imp.yields

    def worked(self, colony):
        """Buildings this colony works: one per colonist living there, best first.
        A building with a hostile unit standing on it produces nothing."""
        sites = []
        for pos, key in self.improvements.items():
            if self.territory_colony(pos) is not colony or self.village_land(pos):
                continue
            occupier = self.unit_at(pos)
            if occupier and self.hostile_to(colony.owner, occupier):
                continue
            sites.append(pos)
        sites.sort(key=lambda p: (-sum(IMPROVEMENTS[self.improvements[p]].yields.values()), p))
        return sites[:colony.pop]

    def income_of_colony(self, colony):
        total = dict.fromkeys(RESOURCES, 0)
        for res, n in COLONY_BASE.items():
            total[res] += n
        for pos in self.worked(colony):
            for res, n in self.improvement_yield(self.improvements[pos]).items():
                total[res] += n
        total["food"] -= colony.pop * POP_FOOD
        if self.season() == "Winter":
            total["wood"] -= FIREWOOD
        return total

    def income(self, side):
        total = dict.fromkeys(RESOURCES, 0)
        for colony in self.colonies_of(side):
            for res, n in self.income_of_colony(colony).items():
                total[res] += n
        total["food"] -= sum(u.type.upkeep for u in self.units_of(side))
        return total

    def can_afford(self, side, cost):
        return all(self.stock[side].get(r, 0) >= n for r, n in cost.items())

    def pay(self, side, cost):
        for res, n in cost.items():
            self.stock[side][res] -= n

    def _my_turn(self, side):
        if self.winner:
            return False, "The game is over"
        if side != self.current:
            return False, "Not your turn"
        return True, ""

    # ----- colony jobs (one per colony per turn) ------------------------------
    def _job_check(self, colony):
        ok, reason = self._my_turn(colony.owner)
        if ok and colony.busy:
            return False, f"{colony.name} already did its job this turn"
        return ok, reason

    def _room(self, pos):
        return any(self.is_land(p) and self.unit_at(p) is None and not self.village_at(p)
                   for r in range(4) for p in within(pos, r))

    def train_check(self, colony, unit_type):
        ok, reason = self._job_check(colony)
        if not ok:
            return ok, reason
        if not self.can_afford(colony.owner, unit_type.cost):
            return False, f"A {unit_type.name.lower()} costs {cost_text(unit_type.cost)}"
        if not self._room(colony.pos):
            return False, "No room around the colony"
        return True, ""

    def train(self, colony, unit_type):
        if not self.train_check(colony, unit_type)[0]:
            return None
        self.pay(colony.owner, unit_type.cost)
        return self._job_unit(colony, unit_type)

    def _job_unit(self, colony, unit_type):
        unit = self.spawn(unit_type, colony.owner, colony.pos)
        unit.moves_left, unit.acted = 0, True
        colony.busy = True
        if colony.owner == PLAYER:
            self.message(f"{colony.name} trained a {unit_type.name.lower()}.")
        self.update_visibility()
        return unit

    def colonist_check(self, colony):
        ok, reason = self._job_check(colony)
        if not ok:
            return ok, reason
        if colony.pop < 2:
            return False, "Needs at least 2 population"
        if self.stock[colony.owner]["food"] < COLONIST_FOOD:
            return False, f"Needs {COLONIST_FOOD} food for the journey"
        if not self._room(colony.pos):
            return False, "No room around the colony"
        return True, ""

    def make_colonist(self, colony):
        if not self.colonist_check(colony)[0]:
            return None
        colony.pop -= 1
        self.stock[colony.owner]["food"] -= COLONIST_FOOD
        return self._job_unit(colony, COLONIST)

    def grow_check(self, colony):
        ok, reason = self._job_check(colony)
        if not ok:
            return ok, reason
        if colony.pop >= MAX_POP:
            return False, f"{colony.name} is full ({MAX_POP} population)"
        if not self.can_afford(colony.owner, GROW_COST):
            return False, f"Growing costs {cost_text(GROW_COST)}"
        return True, ""

    def grow(self, colony):
        if not self.grow_check(colony)[0]:
            return False
        self.pay(colony.owner, GROW_COST)
        colony.pop += 1
        colony.busy = True
        if colony.owner == PLAYER:
            self.message(f"{colony.name} grew to {colony.pop} population.")
        return True

    def stockade_check(self, colony):
        ok, reason = self._job_check(colony)
        if not ok:
            return ok, reason
        if colony.stockade:
            return False, "Already has a stockade"
        if not self.can_afford(colony.owner, STOCKADE_COST):
            return False, f"A stockade costs {cost_text(STOCKADE_COST)}"
        return True, ""

    def build_stockade(self, colony):
        if not self.stockade_check(colony)[0]:
            return False
        self.pay(colony.owner, STOCKADE_COST)
        colony.stockade = colony.busy = True
        if colony.owner == PLAYER:
            self.message(f"{colony.name} built a stockade (+{STOCKADE_DEFENSE} defense).")
        return True

    # ----- pioneers and colonists ---------------------------------------------
    def build_check(self, unit):
        if unit.type is not PIONEER:
            return None, "Only pioneers can build"
        ok, reason = self._my_turn(unit.owner)
        if not ok or unit.carrier or unit.moves_left <= 0:
            return None, reason or "No moves left this turn"
        improvement = IMPROVEMENT_FOR_TERRAIN.get(self.terrain[unit.pos])
        if improvement is None:
            return None, "Pioneers build farms, fisheries (beach), trapper camps (forest) or mines (hills)"
        if self.colony_at(unit.pos):
            return None, "Cannot build on a colony"
        if unit.pos in self.improvements:
            return None, "There is already a building here"
        if self.territory_owner(unit.pos) != unit.owner:
            return None, "Pioneers can only build on your colonies' land"
        if not self.can_afford(unit.owner, improvement.cost):
            return None, f"A {improvement.name.lower()} costs {cost_text(improvement.cost)}"
        return improvement, ""

    def build(self, unit):
        improvement, _ = self.build_check(unit)
        if improvement is None:
            return False
        self.improvements[unit.pos] = improvement.key
        self.pay(unit.owner, improvement.cost)
        unit.moves_left, unit.acted = 0, True
        if unit.owner == PLAYER:
            gain = ", ".join(f"+{n} {r}" for r, n in improvement.yields.items())
            self.message(f"Your pioneer built a {improvement.name.lower()} ({gain} while worked).")
        for tribe in {v.tribe for v in self.villages if not v.burned and distance(v.pos, unit.pos) <= 2}:
            self.add_tension(tribe, unit.owner, TENSION_BUILD, "you build on their hunting grounds")
        return True

    def found_check(self, unit, pos=None):
        pos = unit.pos if pos is None else pos
        if unit.type is not COLONIST:
            return False, "Only colonists can found colonies"
        ok, reason = self._my_turn(unit.owner)
        if not ok or unit.moves_left <= 0:
            return False, reason or "No moves left this turn"
        if unit.carrier and pos == unit.pos:
            return False, "Land first"
        if not self.is_land(pos):
            return False, "Colonies must be on land"
        if any(distance(c.pos, pos) < MIN_COLONY_SPACING for c in self.colonies):
            return False, f"Too close to another colony (needs {MIN_COLONY_SPACING} hexes)"
        if any(not v.burned and distance(v.pos, pos) <= MIN_VILLAGE_SPACING for v in self.villages):
            return False, "Too close to a native village"
        owner = self.territory_owner(pos)
        if owner not in (None, unit.owner):
            return False, "That land belongs to someone else"
        return True, ""

    def found_colony(self, unit):
        if not self.found_check(unit)[0]:
            return None
        self.units.remove(unit)
        colony = self._add_colony(unit.pos, unit.owner)
        who = "You" if unit.owner == PLAYER else f"The {SIDE_NAMES[unit.owner]}"
        self.message(f"{who} founded {colony.name}.")
        for tribe in {v.tribe for v in self.villages if not v.burned and distance(v.pos, colony.pos) <= 4}:
            self.add_tension(tribe, unit.owner, TENSION_COLONY, "settlers took their land")
        self.update_visibility()
        return colony

    def _add_colony(self, pos, owner, pop=1):
        name = self._names.pop() if self._names else f"Colony {len(self.colonies) + 1}"
        colony = Colony(pos, owner, name, pop=pop, capital=self.capital_of(owner) is None)
        self.colonies.append(colony)
        self.improvements.pop(pos, None)
        return colony

    def join_check(self, unit):
        if unit.type is not COLONIST:
            return False, "Only colonists can join a colony"
        ok, reason = self._my_turn(unit.owner)
        if not ok:
            return ok, reason
        colony = self._joinable(unit)
        if not colony:
            return False, "Move into or next to one of your colonies to join it"
        if colony.pop >= MAX_POP:
            return False, f"{colony.name} is full"
        return True, ""

    def _joinable(self, unit):
        if unit.carrier:
            return None
        near = [c for c in self.colonies_of(unit.owner) if distance(c.pos, unit.pos) <= 1]
        return min(near, key=lambda c: (distance(c.pos, unit.pos), c.pop), default=None)

    def join(self, unit):
        if not self.join_check(unit)[0]:
            return False
        colony = self._joinable(unit)
        colony.pop += 1
        self.units.remove(unit)
        if unit.owner == PLAYER:
            self.message(f"A colonist joined {colony.name} ({colony.pop} population).")
        return True

    # ----- the homeland --------------------------------------------------------
    def at_homeland(self, unit):
        return unit.type.naval and unit.pos[0] >= self.cols - 1

    def market_check(self, ship, action):
        ok, reason = self._my_turn(ship.owner)
        if not ok:
            return ok, reason
        if not self.at_homeland(ship):
            return False, "Sail to the east edge of the map to reach the homeland"
        if ship.owner == PLAYER and self.declared:
            return False, "The Crown has closed its ports to rebels"
        stock = self.stock[ship.owner]
        kind = action[0]
        if kind == "sell_furs" and stock["furs"] <= 0:
            return False, "No furs to sell"
        if kind == "sell_wood" and stock["wood"] < WOOD_LOT:
            return False, f"Needs {WOOD_LOT} wood"
        if kind == "buy_food" and stock["gold"] < FOOD_LOT_PRICE:
            return False, f"Needs {FOOD_LOT_PRICE} gold"
        if kind == "buy":
            if stock["gold"] < action[1].price:
                return False, f"Needs {action[1].price} gold"
            if len(self.cargo(ship)) >= ship.type.capacity:
                return False, "The ship is full"
        return True, ""

    def market(self, ship, action):
        if not self.market_check(ship, action)[0]:
            return False
        stock, kind, side = self.stock[ship.owner], action[0], ship.owner
        if kind == "sell_furs":
            sold = stock["furs"]
            stock["furs"] = 0
            stock["gold"] += sold * FUR_PRICE
            self.favour[side] += sold
            text = f"Sold {sold} furs for {sold * FUR_PRICE} gold. The Crown is pleased."
        elif kind == "sell_wood":
            stock["wood"] -= WOOD_LOT
            stock["gold"] += WOOD_LOT_PRICE
            text = f"Sold {WOOD_LOT} timber for {WOOD_LOT_PRICE} gold."
        elif kind == "buy_food":
            stock["gold"] -= FOOD_LOT_PRICE
            stock["food"] += FOOD_LOT
            text = f"Bought {FOOD_LOT} food."
        else:
            unit_type = action[1]
            stock["gold"] -= unit_type.price
            self._new_unit(unit_type, side, ship.pos, carrier=ship).moves_left = 0
            text = f"A {unit_type.name.lower()} boarded your ship."
        if side == PLAYER:
            self.message(text)
        return True

    # ----- natives -------------------------------------------------------------
    def mood(self, tribe, side):
        if side in self.war[tribe]:
            return "at war"
        t = self.tension[tribe][side]
        return "angry" if t >= 70 else "wary" if t >= TENSION_PEACE else "friendly"

    def add_tension(self, tribe, side, amount, reason=""):
        if side not in COLONISERS:
            return
        t = self.tension[tribe]
        t[side] = max(0, min(TENSION_WAR + 50, t[side] + amount))
        name = TRIBE_NAMES[tribe]
        if t[side] >= TENSION_WAR and side not in self.war[tribe]:
            self.war[tribe].add(side)
            if side == PLAYER:
                self.message(f"The {name} declare war on you{': ' + reason if reason else ''}!")
            else:
                self.message(f"The {name} went to war with the {SIDE_NAMES[side]}.")
        elif t[side] < TENSION_PEACE and side in self.war[tribe]:
            self.war[tribe].discard(side)
            if side == PLAYER:
                self.message(f"The {name} make peace with you.")
        elif amount > 0 and side == PLAYER and reason and t[side] >= 70:
            self.message(f"The {name} are angry: {reason}.")

    def in_contact(self, side, village):
        if any(u.owner == side and u.carrier is None and distance(u.pos, village.pos) == 1 for u in self.units):
            return True
        return any(distance(c.pos, village.pos) <= VILLAGE_REACH for c in self.colonies_of(side))

    def gift_check(self, side, village):
        ok, reason = self._my_turn(side)
        if not ok:
            return ok, reason
        if not self.in_contact(side, village):
            return False, f"Needs a unit next to the village or a colony within {VILLAGE_REACH} hexes"
        if not self.can_afford(side, GIFT_COST):
            return False, f"A gift costs {cost_text(GIFT_COST)}"
        return True, ""

    def gift(self, side, village):
        if not self.gift_check(side, village)[0]:
            return False
        self.pay(side, GIFT_COST)
        if side == PLAYER:
            self.message(f"The {TRIBE_NAMES[village.tribe]} accept your gift.")
        self.add_tension(village.tribe, side, -GIFT_CALM)
        return True

    def trade_check(self, side, village):
        ok, reason = self._my_turn(side)
        if not ok:
            return ok, reason
        if side in self.war[village.tribe]:
            return False, "They will not trade while at war with you"
        if not self.in_contact(side, village):
            return False, f"Needs a unit next to the village or a colony within {VILLAGE_REACH} hexes"
        if village.traded.get(side) == self.turn:
            return False, "Already traded with this village this turn"
        if not self.can_afford(side, TRADE_GIVE):
            return False, f"They want {cost_text(TRADE_GIVE)}"
        return True, ""

    def trade(self, side, village):
        if not self.trade_check(side, village)[0]:
            return False
        self.pay(side, TRADE_GIVE)
        for res, n in TRADE_GET.items():
            self.stock[side][res] += n
        village.traded[side] = self.turn
        self.add_tension(village.tribe, side, -TRADE_CALM)
        if side == PLAYER:
            self.message(f"Traded {cost_text(TRADE_GIVE)} for {cost_text(TRADE_GET)} with the {TRIBE_NAMES[village.tribe]}.")
        return True

    def _visit(self, unit, village):
        village.visited.add(unit.owner)
        roll = self.rng.random()
        mine = unit.owner == PLAYER
        if roll < 0.35:
            gold = self.rng.randint(4, 8)
            self.stock[unit.owner]["gold"] += gold
            text = f"The village gives your scout {gold} gold as a welcome gift."
        elif roll < 0.6:
            self.stock[unit.owner]["food"] += 6
            text = "The village shares 6 food with your scout."
        elif roll < 0.88:
            if mine:
                self.explored |= {p for p in within(village.pos, 5) if self.in_bounds(p)}
            text = "The villagers tell your scout about the lands around them."
        else:
            self.spawn(COLONIST, unit.owner, unit.pos)
            text = "A villager decides to join you as a colonist!"
        self.add_tension(village.tribe, unit.owner, -5)
        if mine:
            self.message(text)

    # ----- movement ------------------------------------------------------------
    def can_enter(self, unit, pos):
        if not self.in_bounds(pos):
            return False
        if unit.type.naval:
            return self.is_ocean(pos) and self.unit_at(pos) is None
        if not self.is_land(pos) or self.unit_at(pos) is not None:
            return False
        village = self.village_at(pos)
        if village:
            return unit.owner == NATIVES and village.tribe == unit.tribe
        colony = self.colony_at(pos)
        if colony and colony.owner != unit.owner:
            return unit.type.can_capture and self.can_capture(unit.owner, colony)
        return True

    def can_capture(self, side, colony):
        if side == CROWN:
            return colony.owner == PLAYER
        if colony.owner == CROWN:
            return False
        if CROWN in (side, colony.owner):
            return False
        return side in COLONISERS

    def reachable(self, unit):
        """{pos: move cost} for every hex the unit can end its move on this turn."""
        if unit.carrier:
            if unit.moves_left <= 0:
                return {unit.pos: 0}
            reach = {unit.pos: 0}
            for n in neighbors(unit.pos):
                if self.can_enter(unit, n):
                    reach[n] = 1        # landing costs one move
            return reach
        costs = {unit.pos: 0}
        heap = [(0, unit.pos)]
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > costs.get(pos, INF):
                continue
            if pos != unit.pos and self.colony_at(pos) and self.colony_at(pos).owner != unit.owner:
                continue        # capturing a colony ends the move
            for n in neighbors(pos):
                if not self.can_enter(unit, n):
                    continue
                step = 1 if unit.type.naval else self.terrain_at(n).move_cost
                new_cost = cost + step
                if new_cost <= unit.moves_left and new_cost < costs.get(n, INF):
                    costs[n] = new_cost
                    heapq.heappush(heap, (new_cost, n))
        if not unit.type.naval:
            # Boarding one of your ships next to a hex you can reach.
            for ship in self.units_of(unit.owner):
                if ship.type.naval and len(self.cargo(ship)) < ship.type.capacity:
                    via = [costs[n] for n in neighbors(ship.pos) if n in costs]
                    if via and min(via) + 1 <= unit.moves_left:
                        costs[ship.pos] = min(via) + 1
        return costs

    def cost_field(self, goal, naval=False):
        """{pos: cost to travel from pos to goal}, ignoring units."""
        field = {goal: 0}
        heap = [(0, goal)]
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > field.get(pos, INF):
                continue
            step = 1 if naval else (self.terrain_at(pos).move_cost or 1)
            for n in neighbors(pos):
                ok = self.is_ocean(n) if naval else (self.is_land(n) and not self.village_at(n))
                if ok and cost + step < field.get(n, INF):
                    field[n] = cost + step
                    heapq.heappush(heap, (cost + step, n))
        return field

    def step_toward(self, unit, goal, field=None):
        field = field if field is not None else self.cost_field(goal, unit.type.naval)
        reach = self.reachable(unit)
        options = [p for p in reach if p == unit.pos or self.unit_at(p) is None]
        return min(options, key=lambda p: (field.get(p, distance(p, goal) * 3 + 100), reach[p]))

    def move(self, unit, dest):
        reach = self.reachable(unit)
        if self.winner or unit.owner != self.current or dest not in reach:
            return False
        if dest == unit.pos:
            return True
        occupant = self.unit_at(dest)
        if occupant and occupant.type.naval and occupant.owner == unit.owner and not unit.type.naval:
            unit.carrier, unit.pos, unit.moves_left = occupant, dest, 0        # board
        elif unit.carrier:
            unit.carrier, unit.pos = None, dest                                # land
            unit.moves_left -= 1
        else:
            unit.moves_left -= reach[dest]
            unit.pos = dest
            if unit.type.naval:
                for passenger in self.cargo(unit):
                    passenger.pos = dest
        unit.acted = True

        colony = self.colony_at(dest)
        if colony and colony.owner != unit.owner and unit.carrier is None:
            self._capture(colony, unit)
        if unit.type is SCOUT and unit.carrier is None:
            for village in self.villages:
                if not village.burned and unit.owner not in village.visited and distance(village.pos, dest) == 1:
                    self._visit(unit, village)
        self.update_visibility()
        self.check_end()
        return True

    def _capture(self, colony, unit):
        loser = colony.owner
        colony.owner = unit.owner
        colony.pop = max(1, colony.pop - 1)
        colony.busy = True
        was_capital, colony.capital = colony.capital, self.capital_of(unit.owner) is None
        if was_capital:
            self._new_capital(loser)
        self.message(f"{unit.label} captured {colony.name}!")

    def _new_capital(self, side):
        rest = self.colonies_of(side)
        if rest and not self.capital_of(side):
            max(rest, key=lambda c: c.pop).capital = True

    def _destroy_colony(self, colony):
        self.colonies.remove(colony)
        if colony.capital:
            self._new_capital(colony.owner)

    # ----- combat --------------------------------------------------------------
    def attack_options(self, unit):
        """{target position: hex to attack from}. Needs at least 1 move left after moving."""
        if (self.winner or unit.owner != self.current or unit.attacked or unit.moves_left <= 0
                or unit.type.attack <= 0 or unit.carrier):
            return {}
        reach = self.reachable(unit)
        stands = {p: c for p, c in reach.items() if c < unit.moves_left and self.unit_at(p) in (None, unit)}
        targets = [u.pos for u in self.units if u.carrier is None and self.can_attack(unit, u)]
        if unit.type.raider:
            targets += [c.pos for c in self.colonies if self.unit_at(c.pos) is None
                        and c.owner in self.war[unit.tribe]]
        if unit.owner in COLONISERS and unit.type.can_capture:
            targets += [v.pos for v in self.villages if not v.burned and self.unit_at(v.pos) is None]
        options = {}
        for target in targets:
            near = [p for p in neighbors(target) if p in stands]
            if near:
                options[target] = min(near, key=lambda p: (stands[p], -self.defense_at(unit, p)))
        return options

    def _damage(self, attacker, defender, factor):
        roll = attacker.type.attack * factor * self.rng.uniform(0.8, 1.25)
        return round(roll) - self.defense_at(defender, defender.pos)

    def _start_native_war(self, side, tribe, reason):
        self.add_tension(tribe, side, TENSION_WAR, reason)

    def attack(self, unit, target_pos):
        options = self.attack_options(unit)
        if target_pos not in options:
            return False
        if not self.move(unit, options[target_pos]) or self.winner:
            return True
        target = self.unit_at(target_pos)
        if target:
            if target.owner == NATIVES and unit.owner in COLONISERS:
                self._start_native_war(unit.owner, target.tribe, "you attacked their warriors")
            self._fight(unit, target)
        elif self.colony_at(target_pos):
            colony = self.colony_at(target_pos)
            stolen = min(RAID_FOOD, max(0, self.stock[colony.owner]["food"]))
            self.stock[colony.owner]["food"] -= stolen
            colony.pop -= 1
            if colony.pop <= 0:
                self._destroy_colony(colony)
                self.message(f"{unit.label}s burned {colony.name} to the ground!")
            else:
                self.message(f"{unit.label}s raided {colony.name}: -1 population, -{stolen} food.")
        else:
            village = self.village_at(target_pos)
            village.burned = True
            for res, n in BURN_LOOT.items():
                self.stock[unit.owner][res] += n
            self.improvements.pop(village.pos, None)
            self.message(f"{unit.label} burned a village of the {TRIBE_NAMES[village.tribe]} "
                         f"(+{cost_text(BURN_LOOT)}).")
            self._start_native_war(unit.owner, village.tribe, "you burned their village")
            for tribe in self.tension:
                if tribe != village.tribe:
                    self.add_tension(tribe, unit.owner, TENSION_BURN, "you burn villages")
        unit.moves_left = 0
        unit.acted = unit.attacked = True
        self.update_visibility()
        self.check_end()
        return True

    def _fight(self, unit, target):
        flankers = sum(1 for u in self.units if u.owner == unit.owner and u is not unit
                       and u.carrier is None and distance(u.pos, target.pos) == 1)
        damage = max(1, self._damage(unit, target, 1.0) + flankers)
        target.hp -= damage
        text = f"{unit.label} hit {target.label.lower()} for {damage}"
        if target.hp <= 0:
            self._kill(target)
            text += f". {target.label} destroyed!"
        else:
            counter = max(0, self._damage(target, unit, 0.55)) if target.type.attack > 0 else 0
            if counter:
                unit.hp -= counter
                text += f", took {counter} back"
                if unit.hp <= 0:
                    self._kill(unit)
                    text += f". {unit.label} destroyed!"
        self.message(text if text.endswith("!") else text + ".")

    def raze(self, unit):
        """A brave burns the enemy building it is standing on."""
        key = self.improvements.get(unit.pos)
        owner = self.territory_owner(unit.pos)
        if (unit.type is not BRAVE or unit.owner != self.current or not key or owner not in COLONISERS
                or owner not in self.war[unit.tribe]):
            return False
        del self.improvements[unit.pos]
        unit.moves_left, unit.acted = 0, True
        whose = "your" if owner == PLAYER else f"the {SIDE_NAMES[owner]}'s"
        self.message(f"Native braves burned {whose} {IMPROVEMENTS[key].name.lower()}!")
        return True

    def _kill(self, unit):
        for passenger in self.cargo(unit):
            self.units.remove(passenger)
        if unit in self.units:
            self.units.remove(unit)

    # ----- independence --------------------------------------------------------
    def independence_check(self):
        ok, reason = self._my_turn(PLAYER)
        if not ok:
            return ok, reason
        if self.goal != GOAL_INDEPENDENCE:
            return False, "Only in the Independence game"
        if self.declared:
            return False, "You already declared independence"
        if self.population(PLAYER) < INDEPENDENCE_POP:
            return False, f"Needs {INDEPENDENCE_POP} population in your colonies (you have {self.population(PLAYER)})"
        soldiers = sum(1 for u in self.units_of(PLAYER) if u.type is SOLDIER)
        if soldiers < INDEPENDENCE_SOLDIERS:
            return False, f"Needs {INDEPENDENCE_SOLDIERS} soldiers (you have {soldiers})"
        return True, ""

    def declare_independence(self):
        if not self.independence_check()[0]:
            return False
        self.declared = self.turn
        self.message(f"You declared independence! Hold out for {INDEPENDENCE_TURNS} turns against the royal army.")
        return True

    def _land_royal_wave(self):
        targets = self.colonies_of(PLAYER)
        if not targets:
            return
        target = min(targets, key=lambda c: (min((distance(c.pos, p) for p in self.terrain if self.is_ocean(p))), -c.pop))
        beaches = sorted((p for p in self.terrain if self.is_land(p) and self.coastal(p)
                          and self.unit_at(p) is None and not self.village_at(p) and not self.colony_at(p)),
                         key=lambda p: (distance(p, target.pos) < 2, distance(p, target.pos)))
        for pos in beaches[:ROYAL_WAVE_SIZE]:
            self._new_unit(REGULAR, CROWN, pos)
        self.royal_waves += 1
        self.message(f"The royal army lands near {target.name}! (wave {self.royal_waves}/{ROYAL_WAVES})")

    # ----- turns ---------------------------------------------------------------
    def eliminated(self, side):
        if side in COLONISERS:
            return not self.colonies_of(side) and not any(u.type is COLONIST for u in self.units_of(side))
        if side == CROWN:
            return not self.declared or (self.royal_waves >= ROYAL_WAVES and not self.units_of(CROWN))
        return False

    def active_sides(self):
        return [s for s in TURN_ORDER if s not in self.dead and not self.eliminated(s)]

    def end_turn(self):
        if self.winner:
            return
        for unit in self.units_of(self.current):
            if unit.carrier or unit.acted or unit.hp >= unit.type.max_hp:
                continue
            if self.hostile_adjacent(unit.owner, unit.pos):
                continue
            colony = self.colony_at(unit.pos)
            heal = COLONY_HEAL if colony and colony.owner == unit.owner else REST_HEAL
            unit.hp = min(unit.type.max_hp, unit.hp + heal)
        order = self.active_sides()
        if self.current not in order:
            order = [s for s in TURN_ORDER if s in order or s == self.current]
        i = order.index(self.current) + 1
        if i >= len(order):
            self.turn += 1
            if self.goal == GOAL_SURVIVE and self.turn > SURVIVE_TURNS:
                self.turn = SURVIVE_TURNS
                self._decide_on_score()
                return
            self.current = order[0]
        else:
            self.current = order[i]
        self.start_turn()

    def start_turn(self):
        side = self.current
        for unit in self.units_of(side):
            unit.moves_left = unit.type.moves
            unit.acted = unit.attacked = False
        for colony in self.colonies_of(side):
            colony.busy = False
        if side in COLONISERS:
            self._colony_turn(side)
        elif side == NATIVES:
            self._native_turn()
        elif side == CROWN and self.royal_waves < ROYAL_WAVES and \
                (self.turn - self.declared) % ROYAL_WAVE_EVERY == 1:
            self._land_royal_wave()
        self.check_end()
        self.update_visibility()

    def _colony_turn(self, side):
        mine = side == PLAYER
        gained = self.income(side)
        for res, n in gained.items():
            self.stock[side][res] += n
        stock, now = self.stock[side], self.season()
        if mine:
            gains = ", ".join(f"{n:+} {r}" for r, n in gained.items() if n)
            self.message(f"{self.date()}. Income: {gains or 'nothing'}.")
            if now == "Winter":
                self.message("Winter! Farms are frozen, colonies burn firewood, and the cold hurts units outside your land.")

        if now == "Spring" and self.favour[side] >= FAVOUR_FOR_COLONIST and not (mine and self.declared):
            home = self.capital_of(side)
            if home and self.spawn(COLONIST, side, home.pos):
                self.favour[side] -= FAVOUR_FOR_COLONIST
                if mine:
                    self.message(f"A supply ship from home brings a new colonist to {home.name}.")
        if now == "Summer":
            for colony in self.colonies_of(side):
                if colony.pop >= 3 and self.rng.random() < FEVER_CHANCE:
                    colony.pop -= 1
                    if mine:
                        self.message(f"Fever in {colony.name}: -1 population.")
        if now == "Winter":
            for unit in self.units_of(side):
                if unit.carrier or unit.type.naval or self.territory_owner(unit.pos) == side:
                    continue
                unit.hp -= COLD_DAMAGE
                if unit.hp <= 0:
                    self._kill(unit)
                    if mine:
                        self.message(f"Your {unit.type.name.lower()} froze to death.")
        for res, what in (("food", "food"), ("wood", "firewood")):
            if stock[res] >= 0:
                continue
            stock[res] = 0
            if self.colonies_of(side):
                biggest = max(self.colonies_of(side), key=lambda c: c.pop)
                if biggest.pop > 1:
                    biggest.pop -= 1
                elif res == "food":
                    for unit in [u for u in self.units_of(side) if u.type.upkeep]:
                        unit.hp -= 1
                        if unit.hp <= 0:
                            self._kill(unit)
                if mine:
                    self.message(f"Out of {what}! People in {biggest.name} are dying.")

    def _native_turn(self):
        for tribe, sides in self.tension.items():
            for side in sides:
                if sides[side] > 0:
                    self.add_tension(tribe, side, -TENSION_DECAY)
        for village in self.villages:
            if village.burned or not self.war[village.tribe]:
                village.timer = 0
                continue
            village.timer += 1
            braves = sum(1 for u in self.units if u.home is village)
            if village.timer >= BRAVE_EVERY and braves < BRAVES_PER_VILLAGE:
                if self.spawn(BRAVE, NATIVES, village.pos, home=village):
                    village.timer = 0

    def score(self, side):
        buildings = sum(1 for p in self.improvements if self.territory_owner(p) == side)
        soldiers = sum(1 for u in self.units_of(side) if u.type is SOLDIER)
        return (COLONY_SCORE * len(self.colonies_of(side)) + POP_SCORE * self.population(side)
                + BUILDING_SCORE * buildings + self.stock[side]["gold"] // 10 + soldiers)

    def _decide_on_score(self):
        scores = {s: self.score(s) for s in COLONISERS if s not in self.dead}
        best = max(scores.values())
        leaders = [s for s, v in scores.items() if v == best]
        if len(leaders) > 1 and PLAYER in leaders:
            self.winner = DRAW
        else:
            self.winner = leaders[0]
        board = ", ".join(f"{SIDE_NAMES[s].replace('Your', 'you')} {v}" for s, v in
                          sorted(scores.items(), key=lambda kv: -kv[1]))
        self.win_reason = f"Ten years have passed. Score: {board}"
        self.message(self.win_reason + ".")

    def check_end(self):
        if self.winner:
            return
        for side in COLONISERS:
            if side not in self.dead and self.eliminated(side):
                self.dead.add(side)
                if side != PLAYER:
                    self.message(f"The {SIDE_NAMES[side]} has been wiped out.")
        if PLAYER in self.dead:
            alive = [s for s in RIVALS if s not in self.dead]
            self.winner = max(alive, key=self.score) if alive else DRAW
            self.win_reason = "Your colony has been lost"
            if self.declared:
                self.win_reason = "The royal army crushed your rebellion"
            return
        if self.declared:
            held = self.turn - self.declared >= INDEPENDENCE_TURNS
            beaten = self.royal_waves >= ROYAL_WAVES and not self.units_of(CROWN)
            if held or beaten:
                self.winner = PLAYER
                self.win_reason = "You won your independence" + (" by destroying the royal army" if beaten else "")
                return
        if self.goal == GOAL_SURVIVE and all(s in self.dead for s in RIVALS):
            self.winner = PLAYER
            self.win_reason = "You are the last colonial power standing"

    # ----- fog of war ----------------------------------------------------------
    def update_visibility(self):
        seen = set()
        for unit in self.units_of(PLAYER):
            if unit.carrier is None:
                seen.update(within(unit.pos, unit.type.sight))
        for colony in self.colonies_of(PLAYER):
            seen.update(within(colony.pos, COLONY_SIGHT))
        self.visible = {p for p in seen if self.in_bounds(p)}
        self.explored |= self.visible

    def __repr__(self):
        return f"<ColonyWorld seed={self.seed} turn={self.turn} {self.current} units={len(self.units)}>"
