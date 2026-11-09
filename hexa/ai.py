"""The computer opponent.

take_turn() is a generator: it performs one unit action and then yields that
unit, so the game can pause between moves and the player can watch.
The AI can see the whole map (it ignores fog of war).

Strategy:
- Economy: keep a few workers building farms, lumber camps and mines, and send
  settlers to found up to MAX_TOWNS towns on its own half of the map.
- Army: one soldier guards the castle. The other soldiers gather at a rally
  point until there are WAVE_SIZE of them, then march on the enemy together.
- Scouts roam and only pick fights they can win.
"""
from collections import Counter

from .hexgrid import distance, within
from .rules import (AI, IMPROVEMENT_FOR_TERRAIN, MIN_TOWN_SPACING, SCOUT, SETTLER, SOLDIER,
                    TERRITORY_RADIUS, WORKER, other)

THREAT_RANGE = 5     # enemy soldiers this close to one of our towns bring the army home
WAVE_SIZE = 3        # soldiers needed before an attack starts
CHASE_RANGE = 3      # attacking soldiers detour for enemies this close
RALLY_DISTANCE = 3   # how far in front of the castle the army gathers
MAX_TOWNS = 4        # the AI stops settling after this many towns
SETTLE_UNTIL = 25    # ... or after this turn
WORKERS_PER_TOWN = 1


def take_turn(world, side=AI):
    memory = world.ai_memory.setdefault(side, {"attacking": False})
    _buy_units(world, side)

    guard, home = _pick_guard(world, side)
    army = [u for u in world.units_of(side) if u.type is SOLDIER and u is not guard]
    if len(army) >= WAVE_SIZE:
        memory["attacking"] = True
    elif len(army) <= 1:
        memory["attacking"] = False

    # Soldiers first so they clear the way, then scouts, then civilians.
    order = {SOLDIER.key: 0, SCOUT.key: 1, WORKER.key: 2, SETTLER.key: 3}
    for unit in sorted(world.units_of(side), key=lambda u: order[u.type.key]):
        if world.winner:
            return
        if not unit.alive or unit not in world.units or unit.moves_left <= 0:
            continue
        action = _choose_action(world, unit, home if unit is guard else None, memory["attacking"])
        if action is None:
            continue
        kind, arg = action
        if kind == "attack":
            world.attack(unit, arg)
        elif kind == "build":
            world.build(unit)
        elif kind == "found":
            world.found_town(unit)
        elif arg != unit.pos:
            world.move(unit, arg)
            _work_on_arrival(world, unit)
        else:
            continue
        yield unit


# ----- economy -----------------------------------------------------------------
def _buy_units(world, side):
    towns = world.towns_of(side)
    count = Counter(u.type.key for u in world.units_of(side))
    threatened = bool(_raiders(world, side, THREAT_RANGE))
    for town in sorted(towns, key=lambda t: not t.capital):
        if threatened:
            wants = [SOLDIER]
        else:
            wants = []
            if count[SCOUT.key] == 0 and world.turn < 8:
                wants.append(SCOUT)
            if count[WORKER.key] < WORKERS_PER_TOWN * len(towns) + 1 and _build_sites(world, side):
                wants.append(WORKER)
            if count[SETTLER.key] == 0 and len(towns) < MAX_TOWNS and world.turn <= SETTLE_UNTIL \
                    and _town_site(world, side):
                wants.append(SETTLER)
            wants.append(SOLDIER)
        for unit_type in wants:
            if world.train_check(town, unit_type)[0]:
                world.train(town, unit_type)
                count[unit_type.key] += 1
                break
            if unit_type is SETTLER:
                break    # save up for the settler instead of spending on soldiers


def _build_sites(world, side):
    return [p for p, key in world.terrain.items()
            if key in IMPROVEMENT_FOR_TERRAIN and p not in world.improvements
            and not world.town_at(p) and world.territory_owner(p) == side]


def _worker_goal(world, unit):
    sites = [p for p in _build_sites(world, unit.owner)
             if world.unit_at(p) is None or world.unit_at(p) is unit]
    if not sites:
        return None
    stock = world.stock[unit.owner]
    scarce = min(stock, key=stock.get)
    def value(p):
        yields = IMPROVEMENT_FOR_TERRAIN[world.terrain[p]].yields
        return distance(unit.pos, p) - (2 if scarce in yields else 0)
    return min(sites, key=value)


def _town_site(world, side):
    capital = world.capital_of(side)
    enemy = world.capital_of(other(side))
    if capital is None:
        return None
    best, best_value = None, 0
    for pos, key in world.terrain.items():
        if not world.terrain_at(pos).passable:
            continue
        if any(distance(t.pos, pos) < MIN_TOWN_SPACING for t in world.towns):
            continue
        d_home = distance(pos, capital.pos)
        if not 3 <= d_home <= 6 or (enemy and distance(pos, enemy.pos) <= d_home):
            continue
        land = [p for p in within(pos, TERRITORY_RADIUS)
                if p in world.terrain and world.terrain[p] in IMPROVEMENT_FOR_TERRAIN
                and world.territory_owner(p) is None]
        value = len(land) - 0.5 * d_home
        if value > best_value:
            best, best_value = pos, value
    return best


def _work_on_arrival(world, unit):
    """Workers and settlers that still have moves left get to work right away."""
    if unit.type is WORKER and world.build_check(unit)[0]:
        world.build(unit)
    elif unit.type is SETTLER and unit.pos == unit.ai_goal and world.found_check(unit)[0]:
        world.found_town(unit)


# ----- army --------------------------------------------------------------------
def _pick_guard(world, side):
    """One soldier stays home once we have two, or whenever an enemy soldier is close."""
    capital = world.capital_of(side)
    soldiers = [u for u in world.units_of(side) if u.type is SOLDIER]
    if not capital or not soldiers:
        return None, None
    if len(soldiers) >= 2 or _raiders(world, side, THREAT_RANGE):
        return min(soldiers, key=lambda u: distance(u.pos, capital.pos)), capital.pos
    return None, None


def _raiders(world, side, radius):
    homes = [t.pos for t in world.towns_of(side)]
    return [e for e in world.units_of(other(side))
            if e.type.can_capture and any(distance(e.pos, h) <= radius for h in homes)]


def _choose_action(world, unit, guard_home, attacking):
    if unit.type is WORKER:
        if world.build_check(unit)[0]:
            return "build", None
        goal = _worker_goal(world, unit)
        return ("move", world.step_toward(unit, goal)) if goal else None

    if unit.type is SETTLER:
        site = unit.ai_goal
        if site is None or not world.found_check(unit, site)[0] or world.unit_at(site) not in (None, unit):
            site = unit.ai_goal = _town_site(world, unit.owner)
        if site is None:
            return ("found", None) if world.found_check(unit)[0] else None
        if unit.pos == site:
            return "found", None
        return "move", world.step_toward(unit, site)

    enemy_side = other(unit.owner)
    reach = world.reachable(unit)

    # 1. Grab an undefended enemy town or castle if we can reach it.
    towns = [t for t in world.towns_of(enemy_side) if t.pos in reach]
    if towns:
        return "move", min(towns, key=lambda t: not t.capital).pos

    options = world.attack_options(unit)

    # 2. The guard walks home, and once there only fights from the castle.
    if guard_home is not None:
        if unit.pos != guard_home:
            return "move", world.step_toward(unit, guard_home)
        targets = [world.unit_at(t) for t, stand in options.items() if stand == unit.pos]
        return ("attack", min(targets, key=lambda t: t.hp)) if targets else None

    # 3. Attack something worth hitting. Scouts only pick on weak targets.
    targets = [world.unit_at(t) for t in options]
    if unit.type is SCOUT:
        targets = [t for t in targets if t.type.attack == 0 or t.type is SCOUT or t.hp <= unit.type.attack]
    if targets:
        return "attack", min(targets, key=lambda t: (t.hp, distance(unit.pos, t.pos)))

    # 4. Otherwise head for a goal.
    goal = _scout_goal(world, unit) if unit.type is SCOUT else _soldier_goal(world, unit, attacking)
    if goal is None:
        return None
    return "move", world.step_toward(unit, goal)


def _soldier_goal(world, unit, attacking):
    enemy_side = other(unit.owner)
    raiders = _raiders(world, unit.owner, THREAT_RANGE - 1)
    if raiders:
        return min(raiders, key=lambda e: distance(unit.pos, e.pos)).pos
    capital = world.capital_of(enemy_side)
    if capital is None:
        return None
    if not attacking:
        return _rally_point(world, unit.owner, capital.pos)
    near = [e for e in world.units_of(enemy_side) if distance(unit.pos, e.pos) <= CHASE_RANGE]
    if near:
        return min(near, key=lambda e: (distance(unit.pos, e.pos), e.hp)).pos
    open_towns = [t for t in world.towns_of(enemy_side)
                  if not t.capital and world.unit_at(t.pos) is None and distance(unit.pos, t.pos) <= 4]
    if open_towns:
        return min(open_towns, key=lambda t: distance(unit.pos, t.pos)).pos
    return capital.pos


def _rally_point(world, side, target):
    key = ("rally", side)
    if key not in world.ai_memory:
        capital = world.capital_of(side)
        if not capital:
            return target
        to_target = world.cost_field(target)
        spots = [p for p in to_target if distance(p, capital.pos) == RALLY_DISTANCE]
        world.ai_memory[key] = min(spots, key=to_target.get) if spots else capital.pos
    return world.ai_memory[key]


def _scout_goal(world, unit):
    if unit.ai_goal is None or distance(unit.pos, unit.ai_goal) <= 1:
        far = [p for p in world.terrain
               if world.terrain_at(p).passable and distance(p, unit.pos) >= 4]
        unit.ai_goal = world.rng.choice(far) if far else None
    return unit.ai_goal
