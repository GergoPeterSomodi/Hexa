"""Computer players for the colonisation mode: rival companies, native tribes and the royal army.

take_turn(world, side) is a generator that yields after each unit acts, so the game can
pause between moves the player can see. The computer sees the whole map.
"""
from ..hexgrid import distance, neighbors, within
from .rules import (BRAVE, COLONIST, COLONISERS, CROWN, FAVOUR_FOR_COLONIST, FOOD_LOT, GIFT_COST,
                    GROW_COST, IMPROVEMENT_FOR_TERRAIN, IMPROVEMENTS, MAX_POP, NATIVES, PIONEER, PLAYER,
                    SCOUT, SHIP, SOLDIER, TRADE_GIVE, WOOD_LOT)

MAX_COLONIES = 5
SETTLE_UNTIL = 30         # stop making colonists after this turn
ATTACK_FROM = 20          # rival companies start attacking other colonies from this turn
WAVE_SIZE = 3             # spare soldiers needed before attacking
THREAT_RANGE = 4
BRAVE_RANGE = 9           # braves stay this close to their village


def take_turn(world, side):
    if side == NATIVES:
        yield from _natives(world)
    elif side == CROWN:
        yield from _crown(world)
    else:
        yield from _company(world, side)


# ----- shared helpers ----------------------------------------------------------------
def _threats(world, side, pos, radius=THREAT_RANGE):
    return [u for u in world.units if u.carrier is None and u.type.attack >= 4
            and world.hostile_to(side, u) and distance(u.pos, pos) <= radius]


def _best_attack(world, unit, allow=lambda target_pos: True):
    """Pick the most promising attack from unit.attack_options(), or None."""
    best = None
    for pos, stand in world.attack_options(unit).items():
        if not allow(pos):
            continue
        target = world.unit_at(pos)
        if target:
            if target.owner == NATIVES and unit.owner not in world.war[target.tribe]:
                continue            # never start a war with the natives on purpose
            expected = unit.type.attack - world.defense_at(target, pos)
            value = 10 - target.hp + (8 if target.hp <= expected else 0) + target.type.attack
            value -= world.defense_at(unit, stand)
        elif world.colony_at(pos):
            value = 12
        else:
            continue                # the computer does not burn villages
        if best is None or value > best[0]:
            best = (value, pos)
    return best[1] if best else None


def _walk(world, unit, goal):
    if goal is None or unit.moves_left <= 0:
        return False
    dest = world.step_toward(unit, goal)
    return dest != unit.pos and world.move(unit, dest)


# ----- the rival companies ------------------------------------------------------------
def _company(world, side):
    memory = world.ai_memory.setdefault(side, {"claimed": {}})
    _colony_jobs(world, side)
    _natives_diplomacy(world, side)
    for ship in [u for u in world.units_of(side) if u.type is SHIP]:
        if _ship(world, ship, memory):
            yield ship

    order = {SOLDIER.key: 0, SCOUT.key: 1, PIONEER.key: 2, COLONIST.key: 3}
    if not world.colonies_of(side):
        order[COLONIST.key] = -1        # land the colonists first
    attacking = world.turn >= ATTACK_FROM and _spare_soldiers(world, side) >= WAVE_SIZE
    guards = _assign_guards(world, side)
    for unit in sorted([u for u in world.units_of(side) if not u.type.naval], key=lambda u: order[u.type.key]):
        if unit not in world.units or world.winner:
            continue
        if unit.type is not COLONIST and _clear_beach(world, unit):
            acted = True
        elif unit.type is SOLDIER:
            acted = _soldier(world, unit, guards.get(unit), attacking)
        elif unit.type is SCOUT:
            acted = _scout(world, unit)
        elif unit.type is PIONEER:
            acted = _pioneer(world, unit, memory)
        else:
            acted = _colonist(world, unit, memory)
        if acted:
            yield unit


def _clear_beach(world, unit):
    """Step away from a ship that still has passengers, so they have room to land."""
    if unit.carrier or unit.moves_left <= 0:
        return False
    ships = [s for s in world.units_of(unit.owner) if s.type.naval and world.cargo(s)
             and distance(s.pos, unit.pos) == 1]
    if not ships:
        return False
    reach = world.reachable(unit)
    away = [p for p in reach if world.is_land(p) and world.unit_at(p) is None
            and all(distance(p, s.pos) > 1 for s in ships)]
    if not away:
        return False
    home = _home(world, unit.owner)
    return world.move(unit, min(away, key=lambda p: (reach[p], distance(p, home))))


def _count(world, side, unit_type):
    return sum(1 for u in world.units_of(side) if u.type is unit_type)


def _spare_soldiers(world, side):
    return _count(world, side, SOLDIER) - len(world.colonies_of(side))


def _food_reserve(world, side):
    pop = world.population(side) + _count(world, side, SOLDIER)
    return 4 + (pop * 2 if world.season() in ("Autumn", "Winter") else pop // 2)


def _colony_jobs(world, side):
    stock = world.stock[side]
    colonies = sorted(world.colonies_of(side), key=lambda c: -c.pop)
    for colony in colonies:
        threatened = _threats(world, side, colony.pos)
        garrison = world.unit_at(colony.pos)
        defenders = sum(1 for u in world.units_of(side) if u.type is SOLDIER and distance(u.pos, colony.pos) <= 2)
        if threatened and defenders < len(threatened) + 1:
            if world.train_check(colony, SOLDIER)[0] and (garrison is None or len(threatened) > 1):
                world.train(colony, SOLDIER)
                continue
            if world.build_stockade(colony):
                continue
        reserve = _food_reserve(world, side)
        n_colonies = len(world.colonies_of(side))
        pioneers = _count(world, side, PIONEER)
        if pioneers < n_colonies and _build_sites(world, side) and \
                stock["food"] - PIONEER.cost["food"] >= reserve // 2 and world.train(colony, PIONEER):
            continue
        if _count(world, side, SCOUT) == 0 and world.turn < 12 and world.train(colony, SCOUT):
            continue
        if (n_colonies + _count(world, side, COLONIST) < MAX_COLONIES and world.turn <= SETTLE_UNTIL
                and colony.pop >= 3 and _count(world, side, COLONIST) == 0 and world.make_colonist(colony)):
            continue
        if colony.pop < MAX_POP - 2 and stock["food"] - GROW_COST["food"] >= reserve and world.grow(colony):
            continue
        soldiers_wanted = max(1, n_colonies // 2) + (WAVE_SIZE if world.turn >= ATTACK_FROM - 2 else 0)
        if _count(world, side, SOLDIER) < soldiers_wanted and stock["food"] >= reserve and \
                world.train(colony, SOLDIER):
            continue
        if colony.capital and stock["wood"] >= 10:
            world.build_stockade(colony)


def _natives_diplomacy(world, side):
    stock = world.stock[side]
    for village in world.villages:
        if village.burned:
            continue
        tension = world.tension[village.tribe][side]
        if (tension >= 60 or side in world.war[village.tribe]) and stock["gold"] >= GIFT_COST["gold"] + 2:
            world.gift(side, village)
        elif stock["wood"] >= 8 + TRADE_GIVE["wood"]:
            world.trade(side, village)


def _build_sites(world, side):
    sites = []
    for pos, terrain in world.terrain.items():
        if terrain in IMPROVEMENT_FOR_TERRAIN and pos not in world.improvements and not world.colony_at(pos) \
                and world.territory_owner(pos) == side:
            colony = world.territory_colony(pos)
            used = sum(1 for p in world.improvements if world.territory_colony(p) is colony)
            if used <= colony.pop:
                sites.append(pos)
    return sites


def _site_value(world, side, pos):
    imp = IMPROVEMENT_FOR_TERRAIN[world.terrain[pos]]
    income = world.income(side)
    value = 0
    for res, n in imp.yields.items():
        need = {"food": 3 - income["food"], "wood": 2 - income["wood"], "furs": 1, "gold": 0.5}[res]
        value += n * (1 + max(0, need) * 0.5)
    if imp.key == "fishery" and world.season() in ("Autumn", "Winter"):
        value += 2
    return value


def _pioneer(world, unit, memory):
    if unit.carrier:
        return _disembark(world, unit, _home(world, unit.owner))
    if world.build(unit):
        return True
    sites = _build_sites(world, unit.owner)
    if not sites:
        return _walk(world, unit, _home(world, unit.owner)) if distance(unit.pos, _home(world, unit.owner)) > 2 else False
    goal = max(sites, key=lambda p: _site_value(world, unit.owner, p) - 0.6 * distance(p, unit.pos))
    moved = _walk(world, unit, goal)
    if unit.pos == goal:
        world.build(unit)
    return moved


def _home(world, side):
    capital = world.capital_of(side)
    return capital.pos if capital else world.landings[side][0]


def _colony_site(world, unit, memory):
    side = unit.owner
    centre = _home(world, side)
    claimed = {p for uid, p in memory["claimed"].items() if uid != unit.id}
    best = None
    for pos in within(centre, 7):
        if not world.is_land(pos) or pos in claimed or world.colony_at(pos) or world.village_at(pos):
            continue
        if any(distance(c.pos, pos) < 3 for c in world.colonies) or \
                any(not v.burned and distance(v.pos, pos) <= 2 for v in world.villages) or \
                world.territory_owner(pos) not in (None, side):
            continue
        land = sum(1 for p in within(pos, 2) if world.terrain.get(p) in IMPROVEMENT_FOR_TERRAIN
                   and world.territory_owner(p) in (None, side))
        nervous = sum(1 for v in world.villages if not v.burned and distance(v.pos, pos) <= 4)
        value = land + (3 if world.coastal(pos) else 0) - 0.7 * distance(pos, centre) - 2 * nervous
        if not world.colonies_of(side):
            value -= 2 * distance(pos, centre)      # land the first colony quickly
        if best is None or value > best[0]:
            best = (value, pos)
    return best[1] if best else None


def _colonist(world, unit, memory):
    side = unit.owner
    goal = memory["claimed"].get(unit.id)
    if goal is None or not _still_free(world, goal):
        goal = _colony_site(world, unit, memory)
        if goal is not None:
            memory["claimed"][unit.id] = goal
    if unit.carrier:
        return _disembark(world, unit, goal or _home(world, side))
    if goal is None or len(world.colonies_of(side)) >= MAX_COLONIES:
        if world.join(unit):
            return True
        open_ = [c for c in world.colonies_of(side) if c.pop < MAX_POP]
        colony = min(open_, key=lambda c: (c.pop, distance(c.pos, unit.pos)), default=None)
        moved = _walk(world, unit, colony.pos if colony else None)
        return world.join(unit) or moved
    moved = False
    if unit.pos != goal:
        moved = _walk(world, unit, goal)
    first = not world.colonies_of(side)
    blocked = world.unit_at(goal) not in (None, unit) and distance(unit.pos, goal) <= 1
    if (unit.pos == goal or first or blocked) and world.found_check(unit)[0] and world.found_colony(unit):
        memory["claimed"].pop(unit.id, None)
        return True
    return moved


def _still_free(world, pos):
    return (not world.colony_at(pos) and all(distance(c.pos, pos) >= 3 for c in world.colonies))


def _disembark(world, unit, goal):
    options = [p for p in world.reachable(unit) if p != unit.pos]
    if not options:
        return False
    return world.move(unit, min(options, key=lambda p: distance(p, goal)))


def _scout(world, unit):
    if unit.carrier:
        return _disembark(world, unit, _home(world, unit.owner))
    target = _best_attack(world, unit, lambda p: world.unit_at(p) and world.unit_at(p).hp <= 3)
    if target:
        return world.attack(unit, target)
    unvisited = [v for v in world.villages if not v.burned and unit.owner not in v.visited
                 and unit.owner not in world.war[v.tribe]]
    if unvisited:
        village = min(unvisited, key=lambda v: distance(v.pos, unit.pos))
        stands = [p for p in neighbors(village.pos) if world.is_land(p) and not world.village_at(p)]
        if stands:
            return _walk(world, unit, min(stands, key=lambda p: distance(p, unit.pos)))
    home = _home(world, unit.owner)
    return _walk(world, unit, home) if distance(unit.pos, home) > 1 else False


def _assign_guards(world, side):
    """One soldier per colony, the nearest one."""
    guards, free = {}, [u for u in world.units_of(side) if u.type is SOLDIER and u.carrier is None]
    for colony in sorted(world.colonies_of(side), key=lambda c: (not c.capital, -c.pop)):
        if not free:
            break
        soldier = min(free, key=lambda u: distance(u.pos, colony.pos))
        free.remove(soldier)
        guards[soldier] = colony
    return guards


def _soldier(world, unit, guarding, attacking):
    side = unit.owner
    if unit.carrier:
        return _disembark(world, unit, _home(world, side))
    if guarding:
        target = _best_attack(world, unit, lambda p: distance(p, guarding.pos) <= 1)
        if target and unit.hp > 4:
            return world.attack(unit, target)
        if unit.pos != guarding.pos:
            return _walk(world, unit, guarding.pos)
        return False
    # Free soldiers: defend against raiders near home first.
    for colony in world.colonies_of(side):
        threats = _threats(world, side, colony.pos, 5)
        if threats:
            target = _best_attack(world, unit)
            if target:
                return world.attack(unit, target)
            return _walk(world, unit, min(threats, key=lambda u: distance(u.pos, unit.pos)).pos)
    if attacking:
        goal = _war_target(world, unit)
        if goal:
            reach = world.reachable(unit)
            if goal.pos in reach and world.unit_at(goal.pos) is None:
                return world.move(unit, goal.pos)
            target = _best_attack(world, unit, lambda p: distance(p, goal.pos) <= 2)
            if target:
                return world.attack(unit, target)
            return _walk(world, unit, goal.pos)
    home = _home(world, side)
    if distance(unit.pos, home) > 2:
        return _walk(world, unit, home)
    target = _best_attack(world, unit)
    return world.attack(unit, target) if target else False


def _war_target(world, unit):
    enemies = [c for c in world.colonies if c.owner in COLONISERS and c.owner != unit.owner]
    if not enemies:
        return None

    def weakness(colony):
        guard = world.unit_at(colony.pos)
        return distance(colony.pos, unit.pos) + (6 if guard else 0) + (4 if colony.stockade else 0)
    return min(enemies, key=weakness)


def _ship(world, ship, memory):
    side = ship.owner
    stock = world.stock[side]
    cargo = world.cargo(ship)
    if world.at_homeland(ship) and not cargo:
        world.market(ship, ("sell_furs",))
        while stock["wood"] >= 14 and world.market(ship, ("sell_wood",)):
            pass
        n_colonies = len(world.colonies_of(side))
        threatened = any(_threats(world, side, c.pos) for c in world.colonies_of(side))
        for _ in range(3):
            if stock["food"] < _food_reserve(world, side) + 8 and stock["gold"] >= 9:
                world.market(ship, ("buy_food",))
        small = sum(1 for c in world.colonies_of(side) if c.pop < MAX_POP - 2)
        for _ in range(ship.type.capacity):
            soldiers = _count(world, side, SOLDIER)
            if soldiers < max(1, n_colonies // 2) or (threatened and soldiers < n_colonies + WAVE_SIZE):
                bought = world.market(ship, ("buy", SOLDIER))
            elif (n_colonies + _count(world, side, COLONIST) < MAX_COLONIES and world.turn <= SETTLE_UNTIL)                     or _count(world, side, COLONIST) < small:
                bought = world.market(ship, ("buy", COLONIST))
            elif _count(world, side, PIONEER) < n_colonies:
                bought = world.market(ship, ("buy", PIONEER))
            else:
                bought = False
            if not bought:
                break
        cargo = world.cargo(ship)
    if cargo:
        goal = _landing_water(world, _home(world, side))
    elif stock["furs"] >= 4 or stock["gold"] >= 10 or stock["wood"] >= 16 or \
            world.favour[side] + stock["furs"] >= FAVOUR_FOR_COLONIST:
        goal = (world.cols - 1, ship.pos[1])
    else:
        goal = _landing_water(world, _home(world, side))
    if ship.pos == goal or goal is None:
        return False
    return _walk(world, ship, goal)


def _landing_water(world, target):
    water = [p for p in within(target, 4) if world.is_ocean(p)
             and any(world.is_land(n) and not world.village_at(n) for n in neighbors(p))]
    if not water:
        water = [p for p in world.terrain if world.is_ocean(p)
                 and any(world.is_land(n) for n in neighbors(p))]
    return min(water, key=lambda p: (distance(p, target), p)) if water else None


# ----- native tribes --------------------------------------------------------------------
def _natives(world):
    for unit in list(world.units_of(NATIVES)):
        if unit not in world.units or world.winner:
            continue
        if _brave(world, unit):
            yield unit


def _brave(world, unit):
    enemies = world.war[unit.tribe]
    home = unit.home.pos
    if not enemies:
        if distance(unit.pos, home) > 1:
            return _walk(world, unit, home)
        return False
    target = _best_attack(world, unit, lambda p: distance(p, home) <= BRAVE_RANGE)
    if target:
        return world.attack(unit, target)
    if world.raze(unit):
        return True
    goals = [c.pos for c in world.colonies if c.owner in enemies]
    goals += [p for p in world.improvements if world.territory_owner(p) in enemies and world.unit_at(p) is None]
    goals += [u.pos for u in world.units if u.carrier is None and u.owner in enemies and not u.type.naval]
    goals = [g for g in goals if distance(g, home) <= BRAVE_RANGE]
    if not goals:
        return _walk(world, unit, home) if distance(unit.pos, home) > 1 else False
    goal = min(goals, key=lambda g: (distance(g, unit.pos), g))
    moved = _walk(world, unit, goal)
    target = _best_attack(world, unit)
    if target:
        world.attack(unit, target)
    else:
        world.raze(unit)
    return moved


# ----- the royal army -------------------------------------------------------------------
def _crown(world):
    for unit in list(world.units_of(CROWN)):
        if unit not in world.units or world.winner:
            continue
        targets = world.colonies_of(PLAYER)
        reach = world.reachable(unit)
        empty = [c for c in targets if c.pos in reach and world.unit_at(c.pos) is None]
        if empty:
            world.move(unit, empty[0].pos)
            yield unit
            continue
        target = _best_attack(world, unit)
        if target:
            world.attack(unit, target)
            yield unit
            continue
        if targets:
            goal = min(targets, key=lambda c: distance(c.pos, unit.pos)).pos
            if _walk(world, unit, goal):
                target = _best_attack(world, unit)
                if target:
                    world.attack(unit, target)
                yield unit
