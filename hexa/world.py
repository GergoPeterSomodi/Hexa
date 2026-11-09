"""Game state and rules: map, units, castles, fog of war, movement, combat and turns.

Nothing in here uses pygame, so the rules can be tested without a window.
"""
import heapq
import itertools
import random
from dataclasses import dataclass

from . import mapgen
from .hexgrid import distance, neighbors, within
from .rules import (AI, CASTLE_DEFENSE, CASTLE_HEAL, CASTLE_SIGHT, PLAYER, REST_HEAL,
                    DRAW, SCOUT, SIDE_NAMES, SOLDIER, SPAWN_EVERY, TERRAIN, TURN_LIMIT, other)

INF = float("inf")


@dataclass(eq=False)
class Unit:
    id: int
    type: object
    owner: str
    pos: tuple
    hp: int
    moves_left: int
    acted: bool = False      # moved or fought this turn, so no resting heal
    attacked: bool = False   # already attacked this turn
    ai_goal: tuple | None = None

    @property
    def alive(self):
        return self.hp > 0

    @property
    def label(self):
        return f"{'Your' if self.owner == PLAYER else 'Enemy'} {self.type.name.lower()}"


@dataclass(eq=False)
class Castle:
    pos: tuple
    owner: str


class World:
    def __init__(self, seed=None, cols=15, rows=11):
        self.seed = seed if seed is not None else random.randrange(1_000_000)
        self.rng = random.Random(self.seed)
        self.cols, self.rows = cols, rows
        self.terrain, self.variants, (player_home, ai_home) = mapgen.generate(cols, rows, self.rng)
        self.castles = [Castle(player_home, PLAYER), Castle(ai_home, AI)]
        self.units = []
        self._ids = itertools.count(1)
        self.turn = 1
        self.current = PLAYER
        self.winner = None
        self.win_reason = ""
        self.log = []
        self.explored = set()
        self.visible = set()
        self.ai_memory = {}     # scratch space for the computer opponent

        centre = (cols // 2, rows // 2)
        for castle in self.castles:
            self.spawn(SOLDIER, castle.owner, castle.pos)
            scout_pos = min((p for p in neighbors(castle.pos) if self.is_free(p)),
                            key=lambda p: distance(p, centre))
            self.spawn(SCOUT, castle.owner, scout_pos)
        self.update_visibility()
        self.message("Turn 1. Capture the enemy castle to win!")

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

    def castle_at(self, pos):
        for castle in self.castles:
            if castle.pos == pos:
                return castle
        return None

    def units_of(self, side):
        return [u for u in self.units if u.owner == side]

    def castles_of(self, side):
        return [c for c in self.castles if c.owner == side]

    def is_free(self, pos):
        return self.in_bounds(pos) and self.terrain_at(pos).passable and self.unit_at(pos) is None

    def enemy_adjacent(self, side, pos):
        return any(u.owner != side and u.pos in set(neighbors(pos)) for u in self.units)

    def defense_at(self, unit, pos):
        bonus = self.terrain_at(pos).defense
        castle = self.castle_at(pos)
        if castle and castle.owner == unit.owner:
            bonus += CASTLE_DEFENSE
        return unit.type.defense + bonus

    def message(self, text):
        self.log.append(text)
        del self.log[:-50]

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
                castle = self.castle_at(n)
                if castle and castle.owner != unit.owner and not unit.type.can_capture:
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
        castle = self.castle_at(dest)
        if castle and castle.owner != unit.owner:
            castle.owner = unit.owner
            self.message(f"{unit.label} captured a castle!")
            self.check_winner()
        self.update_visibility()
        return True

    # ----- combat --------------------------------------------------------------
    def attack_options(self, unit):
        """{enemy position: hex to attack from}. Attacking needs at least 1 move left after moving."""
        if self.winner or unit.owner != self.current or unit.attacked or unit.moves_left <= 0:
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
            counter = max(0, self._damage(target, unit, 0.55))
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
                castle = self.castle_at(unit.pos)
                heal = CASTLE_HEAL if castle and castle.owner == unit.owner else REST_HEAL
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
        if self.turn % SPAWN_EVERY == 0:
            for castle in self.castles_of(side):
                who = "Your castle" if side == PLAYER else "The enemy castle"
                if self.enemy_adjacent(side, castle.pos):
                    self.message(f"{who} is under siege and could not train a soldier.")
                elif self.spawn(SOLDIER, side, castle.pos):
                    self.message(f"{who} trained a new soldier.")
        if side == PLAYER:
            self.message(f"Turn {self.turn}. Your move.")
        self.update_visibility()

    def strength(self, side):
        """Army strength = total HP of a side's units. Decides the game at the turn limit."""
        return sum(u.hp for u in self.units_of(side))

    def _decide_on_score(self):
        mine, theirs = self.strength(PLAYER), self.strength(AI)
        if mine == theirs:
            self.winner, self.win_reason = DRAW, f"Time's up: both armies have strength {mine}"
        else:
            self.winner = PLAYER if mine > theirs else AI
            self.win_reason = f"Time's up: army strength {mine} vs {theirs}"
        self.message(self.win_reason + ".")

    def check_winner(self):
        for side in (PLAYER, AI):
            if not self.castles_of(side):
                self.winner = other(side)
                self.win_reason = ("You captured the enemy castle" if self.winner == PLAYER
                                   else "The enemy captured your castle")
                return

    # ----- fog of war (for the human player) -----------------------------------
    def update_visibility(self):
        seen = set()
        for unit in self.units_of(PLAYER):
            seen.update(within(unit.pos, unit.type.sight))
        for castle in self.castles_of(PLAYER):
            seen.update(within(castle.pos, CASTLE_SIGHT))
        self.visible = {p for p in seen if self.in_bounds(p)}
        self.explored |= self.visible

    def __repr__(self):
        return f"<World seed={self.seed} turn={self.turn} {SIDE_NAMES[self.current]} units={len(self.units)}>"
