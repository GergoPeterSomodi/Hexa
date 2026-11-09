"""Game state and rules: map, units, towns, economy, fog of war, movement, combat and turns.

Nothing in here uses pygame, so the rules can be tested without a window.
"""
import heapq
import itertools
import random
from dataclasses import dataclass

from . import mapgen
from .hexgrid import distance, neighbors, within
from .rules import (AI, CASTLE_INCOME, DRAW, IMPROVEMENT_FOR_TERRAIN, IMPROVEMENTS, MIN_TOWN_SPACING,
                    PLAYER, RESOURCES, REST_HEAL, SCOUT, SETTLER, SIDE_NAMES, SOLDIER, START_STOCK,
                    TERRAIN, TERRITORY_RADIUS, TOWN_DEFENSE, TOWN_HEAL, TOWN_INCOME, TOWN_SCORE,
                    TOWN_SIGHT, TURN_LIMIT, WORKER, cost_text, other)

INF = float("inf")


@dataclass(eq=False)
class Unit:
    id: int
    type: object
    owner: str
    pos: tuple
    hp: int
    moves_left: int
    acted: bool = False      # moved, fought or worked this turn, so no resting heal
    attacked: bool = False   # already attacked this turn
    ai_goal: tuple | None = None

    @property
    def alive(self):
        return self.hp > 0

    @property
    def label(self):
        return f"{'Your' if self.owner == PLAYER else 'Enemy'} {self.type.name.lower()}"


@dataclass(eq=False)
class Town:
    pos: tuple
    owner: str
    capital: bool = False    # the starting castle; losing it loses the game
    trained: bool = False    # already trained a unit this turn

    @property
    def kind(self):
        return "castle" if self.capital else "town"


class World:
    def __init__(self, seed=None, cols=15, rows=11):
        self.seed = seed if seed is not None else random.randrange(1_000_000)
        self.rng = random.Random(self.seed)
        self.cols, self.rows = cols, rows
        self.terrain, self.variants, (player_home, ai_home) = mapgen.generate(cols, rows, self.rng)
        self.towns = [Town(player_home, PLAYER, capital=True), Town(ai_home, AI, capital=True)]
        self.improvements = {}            # pos -> improvement key
        self.stock = {side: dict(START_STOCK) for side in (PLAYER, AI)}
        self.units = []
        self._ids = itertools.count(1)
        self.turn = 1
        self.current = PLAYER
        self.winner = None
        self.win_reason = ""
        self.log = []
        self.explored = set()
        self.visible = set()
        self.ai_memory = {}               # scratch space for the computer opponent

        centre = (cols // 2, rows // 2)
        for town in self.towns:
            self.spawn(SOLDIER, town.owner, town.pos)
            free = sorted((p for p in neighbors(town.pos) if self.is_free(p)), key=lambda p: distance(p, centre))
            self.spawn(SCOUT, town.owner, free[0])
            self.spawn(WORKER, town.owner, free[-1])
        self.update_visibility()
        self.message("Turn 1. Build up your kingdom and capture the enemy castle!")

    # ----- lookups -------------------------------------------------------------
    def in_bounds(self, pos):
        return pos in self.terrain

    def terrain_at(self, pos):
        return TERRAIN[self.terrain[pos]]

    def unit_at(self, pos):
        for unit in self.units:
            if unit.pos == pos:
                return unit
        return None

    def town_at(self, pos):
        for town in self.towns:
            if town.pos == pos:
                return town
        return None

    def units_of(self, side):
        return [u for u in self.units if u.owner == side]

    def towns_of(self, side):
        return [t for t in self.towns if t.owner == side]

    def capital_of(self, side):
        return next((t for t in self.towns if t.owner == side and t.capital), None)

    def is_free(self, pos):
        return self.in_bounds(pos) and self.terrain_at(pos).passable and self.unit_at(pos) is None

    def enemy_adjacent(self, side, pos):
        near = set(neighbors(pos))
        return any(u.owner != side and u.pos in near for u in self.units)

    def defense_at(self, unit, pos):
        bonus = self.terrain_at(pos).defense
        town = self.town_at(pos)
        if town and town.owner == unit.owner:
            bonus += TOWN_DEFENSE
        return unit.type.defense + bonus

    def message(self, text):
        self.log.append(text)
        del self.log[:-50]

    # ----- territory and economy ----------------------------------------------
    def territory_town(self, pos):
        """The town whose land this hex is (the nearest town within reach), or None."""
        best = None
        for town in self.towns:
            d = distance(town.pos, pos)
            if d <= TERRITORY_RADIUS and (best is None or d < best[0]):
                best = (d, town)
        return best[1] if best else None

    def territory_owner(self, pos):
        town = self.territory_town(pos)
        return town.owner if town else None

    def income_of_town(self, town):
        """What one town and the buildings on its land produce per turn.
        A building with an enemy unit standing on it produces nothing."""
        total = dict.fromkeys(RESOURCES, 0)
        for res, n in (CASTLE_INCOME if town.capital else TOWN_INCOME).items():
            total[res] += n
        for pos, key in self.improvements.items():
            occupier = self.unit_at(pos)
            if self.territory_town(pos) is town and not (occupier and occupier.owner != town.owner):
                for res, n in IMPROVEMENTS[key].yields.items():
                    total[res] += n
        return total

    def income(self, side):
        """Net resources per turn for a side, after soldiers eat their food."""
        total = dict.fromkeys(RESOURCES, 0)
        for town in self.towns_of(side):
            for res, n in self.income_of_town(town).items():
                total[res] += n
        total["food"] -= self.upkeep(side)
        return total

    def upkeep(self, side):
        return sum(u.type.upkeep for u in self.units_of(side))

    def can_afford(self, side, cost):
        return all(self.stock[side].get(r, 0) >= n for r, n in cost.items())

    def train_check(self, town, unit_type):
        """(True, "") if the town can train this unit now, else (False, reason)."""
        if self.winner or town.owner != self.current:
            return False, "Not your turn"
        if town.trained:
            return False, "This town already trained a unit this turn"
        if not self.can_afford(town.owner, unit_type.cost):
            return False, "Not enough resources"
        if not any(self.is_free(p) for r in range(3) for p in within(town.pos, r)):
            return False, "No room around the town"
        return True, ""

    def train(self, town, unit_type):
        ok, _ = self.train_check(town, unit_type)
        if not ok:
            return None
        unit = self.spawn(unit_type, town.owner, town.pos)
        for res, n in unit_type.cost.items():
            self.stock[town.owner][res] -= n
        unit.moves_left = 0          # ready to act next turn
        unit.acted = True
        town.trained = True
        if town.owner == PLAYER:
            self.message(f"Your {town.kind} trained a {unit_type.name.lower()}.")
        self.update_visibility()
        return unit

    def build_check(self, unit):
        """(improvement, "") if the worker can build here now, else (None, reason)."""
        if unit.type is not WORKER:
            return None, "Only workers can build"
        if self.winner or unit.owner != self.current or unit.moves_left <= 0:
            return None, "No moves left this turn"
        improvement = IMPROVEMENT_FOR_TERRAIN.get(self.terrain[unit.pos])
        if improvement is None:
            return None, "Workers build on grassland or dirt (farm), forest (lumber) or hills (mine)"
        if self.town_at(unit.pos):
            return None, "Cannot build on a town"
        if unit.pos in self.improvements:
            return None, "There is already a building here"
        if self.territory_owner(unit.pos) != unit.owner:
            return None, "Workers can only build inside your borders"
        if not self.can_afford(unit.owner, improvement.cost):
            return None, f"A {improvement.name.lower()} costs {cost_text(improvement.cost)}"
        return improvement, ""

    def build(self, unit):
        improvement, _ = self.build_check(unit)
        if improvement is None:
            return False
        self.improvements[unit.pos] = improvement.key
        for res, n in improvement.cost.items():
            self.stock[unit.owner][res] -= n
        unit.moves_left = 0
        unit.acted = True
        if unit.owner == PLAYER:
            gain = ", ".join(f"+{n} {r}" for r, n in improvement.yields.items())
            self.message(f"Your worker built a {improvement.name.lower()} ({gain} per turn).")
        return True

    def found_check(self, unit, pos=None):
        """(True, "") if the settler can found a town here (or at pos), else (False, reason)."""
        pos = unit.pos if pos is None else pos
        if unit.type is not SETTLER:
            return False, "Only settlers can found towns"
        if self.winner or unit.owner != self.current or unit.moves_left <= 0:
            return False, "No moves left this turn"
        if any(distance(t.pos, pos) < MIN_TOWN_SPACING for t in self.towns):
            return False, f"Too close to another town (needs {MIN_TOWN_SPACING} hexes)"
        return True, ""

    def found_town(self, unit):
        ok, _ = self.found_check(unit)
        if not ok:
            return None
        town = Town(unit.pos, unit.owner)
        self.towns.append(town)
        self.improvements.pop(unit.pos, None)
        self.units.remove(unit)
        self.message(f"{'You' if unit.owner == PLAYER else 'The enemy'} founded a new town.")
        self.update_visibility()
        return town

    # ----- creating units ------------------------------------------------------
    def spawn(self, unit_type, owner, near):
        for radius in range(3):
            spots = [p for p in within(near, radius) if self.is_free(p)]
            if spots:
                pos = min(spots, key=lambda p: distance(p, near))
                unit = Unit(next(self._ids), unit_type, owner, pos, unit_type.max_hp, unit_type.moves)
                self.units.append(unit)
                return unit
        return None

    # ----- movement ------------------------------------------------------------
    def reachable(self, unit):
        """{pos: move cost} for every hex the unit can end its move on this turn."""
        costs = {unit.pos: 0}
        heap = [(0, unit.pos)]
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > costs.get(pos, INF):
                continue
            for n in neighbors(pos):
                if not self.is_free(n):
                    continue
                town = self.town_at(n)
                if town and town.owner != unit.owner and not unit.type.can_capture:
                    continue
                new_cost = cost + self.terrain_at(n).move_cost
                if new_cost <= unit.moves_left and new_cost < costs.get(n, INF):
                    costs[n] = new_cost
                    heapq.heappush(heap, (new_cost, n))
        return costs

    def cost_field(self, goal):
        """{pos: cost to walk from pos to goal}, ignoring units. Used for long-range pathing."""
        field = {goal: 0}
        heap = [(0, goal)]
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > field.get(pos, INF):
                continue
            step = self.terrain_at(pos).move_cost
            for n in neighbors(pos):
                if self.in_bounds(n) and self.terrain_at(n).passable and cost + step < field.get(n, INF):
                    field[n] = cost + step
                    heapq.heappush(heap, (cost + step, n))
        return field

    def step_toward(self, unit, goal):
        """The reachable hex that gets the unit closest to goal this turn."""
        field = self.cost_field(goal)
        reach = self.reachable(unit)
        return min(reach, key=lambda p: (field.get(p, INF), reach[p]))

    def move(self, unit, dest):
        reach = self.reachable(unit)
        if self.winner or unit.owner != self.current or dest not in reach:
            return False
        if dest == unit.pos:
            return True
        unit.moves_left -= reach[dest]
        unit.pos = dest
        unit.acted = True
        town = self.town_at(dest)
        if town and town.owner != unit.owner:
            town.owner = unit.owner
            self.message(f"{unit.label} captured {'the' if town.capital else 'a'} {town.kind}!")
            self.check_winner()
        self.update_visibility()
        return True

    # ----- combat --------------------------------------------------------------
    def attack_options(self, unit):
        """{enemy position: hex to attack from}. Attacking needs at least 1 move left after moving."""
        if (self.winner or unit.owner != self.current or unit.attacked or unit.moves_left <= 0
                or unit.type.attack <= 0):
            return {}
        reach = self.reachable(unit)
        options = {}
        for enemy in self.units_of(other(unit.owner)):
            stands = [p for p in neighbors(enemy.pos) if p in reach and reach[p] < unit.moves_left]
            if stands:
                options[enemy.pos] = min(stands, key=lambda p: (reach[p], -self.defense_at(unit, p)))
        return options

    def _damage(self, attacker, defender, factor):
        roll = attacker.type.attack * factor * self.rng.uniform(0.8, 1.25)
        return round(roll) - self.defense_at(defender, defender.pos)

    def attack(self, unit, target):
        options = self.attack_options(unit)
        if target.pos not in options:
            return False
        if not self.move(unit, options[target.pos]) or self.winner:
            return True

        # Flanking: +1 damage for every other friendly unit next to the target.
        flankers = sum(1 for u in self.units_of(unit.owner)
                       if u is not unit and distance(u.pos, target.pos) == 1)
        damage = max(1, self._damage(unit, target, 1.0) + flankers)
        target.hp -= damage
        text = f"{unit.label} hit {target.label.lower()} for {damage}"
        if target.hp <= 0:
            self.units.remove(target)
            text += f". {target.label} destroyed!"
        else:
            counter = max(0, self._damage(target, unit, 0.55)) if target.type.attack > 0 else 0
            if counter:
                unit.hp -= counter
                text += f", took {counter} back"
                if unit.hp <= 0:
                    self.units.remove(unit)
                    text += f". {unit.label} destroyed!"
        self.message(text if text.endswith("!") else text + ".")
        unit.moves_left = 0
        unit.acted = unit.attacked = True
        self.update_visibility()
        return True

    # ----- turns ---------------------------------------------------------------
    def end_turn(self):
        if self.winner:
            return
        for unit in self.units_of(self.current):
            if not unit.acted and unit.hp < unit.type.max_hp and not self.enemy_adjacent(unit.owner, unit.pos):
                town = self.town_at(unit.pos)
                heal = TOWN_HEAL if town and town.owner == unit.owner else REST_HEAL
                unit.hp = min(unit.type.max_hp, unit.hp + heal)
        self.current = other(self.current)
        if self.current == PLAYER:
            if self.turn >= TURN_LIMIT:
                self._decide_on_score()
                return
            self.turn += 1
        self.start_turn()

    def start_turn(self):
        side = self.current
        for unit in self.units_of(side):
            unit.moves_left = unit.type.moves
            unit.acted = unit.attacked = False
        for town in self.towns_of(side):
            town.trained = False
        gained = self.income(side)
        for res, n in gained.items():
            self.stock[side][res] += n
        if side == PLAYER:
            gains = ", ".join(f"{n:+} {r}" for r, n in gained.items() if n)
            self.message(f"Turn {self.turn}. Income: {gains or 'nothing'}.")
        if self.stock[side]["food"] < 0:
            # Starvation: soldiers lose HP until there is food again.
            self.stock[side]["food"] = 0
            for unit in [u for u in self.units_of(side) if u.type.upkeep]:
                unit.hp -= 1
                if unit.hp <= 0:
                    self.units.remove(unit)
            if side == PLAYER:
                self.message("Out of food! Your soldiers are starving (-1 HP each).")
        self.update_visibility()

    def score(self, side):
        """Total HP of a side's units plus TOWN_SCORE per town. Decides the game at the turn limit."""
        return sum(u.hp for u in self.units_of(side)) + TOWN_SCORE * len(self.towns_of(side))

    def _decide_on_score(self):
        mine, theirs = self.score(PLAYER), self.score(AI)
        if mine == theirs:
            self.winner, self.win_reason = DRAW, f"Time's up: both sides scored {mine}"
        else:
            self.winner = PLAYER if mine > theirs else AI
            self.win_reason = f"Time's up: score {mine} vs {theirs}"
        self.message(self.win_reason + ".")

    def check_winner(self):
        for side in (PLAYER, AI):
            if self.capital_of(side) is None:
                self.winner = other(side)
                self.win_reason = ("You captured the enemy castle" if self.winner == PLAYER
                                   else "The enemy captured your castle")
                return

    # ----- fog of war (for the human player) -----------------------------------
    def update_visibility(self):
        seen = set()
        for unit in self.units_of(PLAYER):
            seen.update(within(unit.pos, unit.type.sight))
        for town in self.towns_of(PLAYER):
            seen.update(within(town.pos, TOWN_SIGHT))
        self.visible = {p for p in seen if self.in_bounds(p)}
        self.explored |= self.visible

    def __repr__(self):
        return f"<World seed={self.seed} turn={self.turn} {SIDE_NAMES[self.current]} units={len(self.units)}>"
