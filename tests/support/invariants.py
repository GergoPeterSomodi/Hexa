"""World invariants: what must be true of a game world after any finished action, whatever was played.

    check_conquest(world)     a Conquest ``World``
    check_colony(world)       a Colonisation ``ColonyWorld``
    check_campaign(world)     an Age of Discovery ``CampaignWorld``

Each returns None if every invariant holds and otherwise raises AssertionError listing every broken one, one per
line, each line starting with the invariant's name (``cargo: ...``). ``conquest_problems(world)`` and friends
return that list without raising.

Called again on the same world object, a checker also checks that time only runs forward: the turn (and the
campaign's ``version``) may never go down. It remembers the last values per world object in a weak dictionary,
so it never adds anything to the world itself.

None of this reads the AI's private memory, and none of it imports pygame.

KNOWN_OPEN lists the broken invariants that open bugs still cause. The checkers report them like any other (they
are real); ``known_open(mode, problem)`` names the bug, so a long run can tell them from new ones. Each is pinned
by an ``expectedFailure`` test in tests/test_properties.py (KnownBugsTest).
"""
import math
import weakref

_LAST = weakref.WeakKeyDictionary()       # world -> {"turn": ..., "version": ...} seen last time
_SHOWN = 12                               # problems listed in one AssertionError

# (mode, start of the problem text) -> the open bug behind it
KNOWN_OPEN = {}


def known_open(mode, problem):
    """The open bug that explains this problem text ("conquest", "colony" or "campaign"), or None."""
    return next((bug for (m, start), bug in KNOWN_OPEN.items() if m == mode and problem.startswith(start)), None)


def _raise(problems, what):
    if problems:
        more = f"\n... and {len(problems) - _SHOWN} more" if len(problems) > _SHOWN else ""
        raise AssertionError(f"{len(problems)} {what} invariant(s) broken:\n" + "\n".join(problems[:_SHOWN]) + more)


def _forward(world, problems, **now):
    """Turn (and version) never go down between two checks of the same world."""
    last = _LAST.get(world)
    if last is not None:
        for name, value in now.items():
            if value < last[name]:
                problems.append(f"{name}: went back from {last[name]} to {value}")
    _LAST[world] = now


def _whole(n):
    return type(n) is int


def _stacks(units):
    """{pos: [units]} of the units standing on the map (not aboard a ship)."""
    found = {}
    for u in units:
        if getattr(u, "carrier", None) is None:
            found.setdefault(u.pos, []).append(u)
    return found


def _unique_ids(world, problems):
    ids = [u.id for u in world.units]
    if len(ids) != len(set(ids)):
        problems.append(f"unit-id: duplicate unit ids {sorted(i for i in set(ids) if ids.count(i) > 1)}")


# ----- Conquest ------------------------------------------------------------------------------------------------
def conquest_problems(world):
    from hexa.rules import AI, DRAW, IMPROVEMENTS, PLAYER, RESOURCES, TURN_LIMIT
    sides = (PLAYER, AI)
    problems = []
    for u in world.units:
        where = f"{u.owner} {u.type.key} #{u.id} at {u.pos}"
        if not world.in_bounds(u.pos) or not world.terrain_at(u.pos).passable:
            problems.append(f"unit-hex: {where} is not on passable land")
        if not 0 < u.hp <= u.type.max_hp:
            problems.append(f"unit-hp: {where} has {u.hp} HP (max {u.type.max_hp})")
        if not 0 <= u.moves_left <= u.type.moves:
            problems.append(f"unit-moves: {where} has {u.moves_left} moves left (max {u.type.moves})")
        if u.owner not in sides:
            problems.append(f"unit-owner: {where} belongs to no side")
    for pos, here in _stacks(world.units).items():
        if len(here) > 1:
            problems.append(f"one-unit-per-hex: {len(here)} units at {pos}")
    _unique_ids(world, problems)
    for side in sides:
        stock = world.stock.get(side)
        if stock is None or set(stock) != set(RESOURCES):
            problems.append(f"stock: {side} has resources {sorted(stock or ())}, expected {sorted(RESOURCES)}")
            continue
        for res, n in stock.items():
            if not _whole(n) or n < 0:
                problems.append(f"stock: {side} has {n!r} {res}")
    seen = set()
    for town in world.towns:
        if not world.in_bounds(town.pos) or not world.terrain_at(town.pos).passable:
            problems.append(f"town-hex: {town.owner} {town.kind} at {town.pos} is not on passable land")
        if town.pos in seen:
            problems.append(f"town-hex: two towns at {town.pos}")
        seen.add(town.pos)
        if town.owner not in sides:
            problems.append(f"town-owner: town at {town.pos} belongs to {town.owner!r}")
    if world.winner is None:
        for side in sides:
            capitals = [t for t in world.towns if t.owner == side and t.capital]
            if len(capitals) != 1:
                problems.append(f"capital: {side} holds {len(capitals)} castles but the game is not over")
    for pos, key in world.improvements.items():
        if key not in IMPROVEMENTS:
            problems.append(f"improvement: unknown building {key!r} at {pos}")
        elif not world.in_bounds(pos) or world.terrain[pos] not in IMPROVEMENTS[key].terrains:
            problems.append(f"improvement: {key} at {pos} stands on {world.terrain.get(pos)!r}")
        if world.town_at(pos):
            problems.append(f"improvement: {key} under the town at {pos}")
    if not 1 <= world.turn <= TURN_LIMIT:
        problems.append(f"turn: turn {world.turn} is outside 1..{TURN_LIMIT}")
    if world.current not in sides:
        problems.append(f"turn: it is the turn of {world.current!r}")
    if world.winner not in (None, PLAYER, AI, DRAW):
        problems.append(f"winner: {world.winner!r} is not a side")
    elif world.winner and not world.win_reason:
        problems.append("winner: a winner without a reason")
    if not world.visible <= world.explored or not world.explored <= world.terrain.keys():
        problems.append("fog: visible hexes must be explored, and explored hexes on the map")
    _forward(world, problems, turn=world.turn)
    return problems


def check_conquest(world):
    _raise(conquest_problems(world), "Conquest")


# ----- Colonisation --------------------------------------------------------------------------------------------
def colony_problems(world):
    from hexa.colony.rules import (BRAVE, COLONISERS, CROWN, DRAW, GOAL_INDEPENDENCE, GOAL_SURVIVE,
                                   IMPROVEMENTS, MAX_POP, NATIVES, REGULAR, RESOURCES, ROYAL_WAVES,
                                   SURVIVE_TURNS, TENSION_PEACE, TENSION_WAR, TURN_ORDER)
    problems = []
    living = set(world.units)
    for u in world.units:
        where = f"{u.owner} {u.type.key} #{u.id} at {u.pos}"
        ship = u.carrier
        if ship is None:
            on = world.is_ocean(u.pos) if u.type.naval else world.is_land(u.pos)
            if not on:
                problems.append(f"unit-hex: {where} stands on {world.terrain.get(u.pos)!r}")
        elif ship not in living or not ship.type.naval or ship.owner != u.owner or ship.pos != u.pos or u.type.naval:
            problems.append(f"cargo: {where} is aboard {ship.owner} {ship.type.key} #{ship.id} at {ship.pos}, "
                            f"which can't carry it")
        if not 0 < u.hp <= u.type.max_hp:
            problems.append(f"unit-hp: {where} has {u.hp} HP (max {u.type.max_hp})")
        if not 0 <= u.moves_left <= u.type.moves:
            problems.append(f"unit-moves: {where} has {u.moves_left} moves left (max {u.type.moves})")
        if u.owner not in TURN_ORDER:
            problems.append(f"unit-owner: {where} belongs to no side")
        elif (u.type is BRAVE) != (u.owner == NATIVES) or (u.type is REGULAR) != (u.owner == CROWN):
            problems.append(f"unit-owner: {where} is the wrong side for its kind")
        elif (u.type is BRAVE) != (u.home in world.villages):
            problems.append(f"unit-owner: {where} has home {u.home!r}")
        if u.type.naval:
            aboard = world.cargo(u)
            if len(aboard) > u.type.capacity:
                problems.append(f"cargo: {where} carries {len(aboard)} units (capacity {u.type.capacity})")
    for pos, here in _stacks(world.units).items():
        if len(here) > 1:
            problems.append(f"one-unit-per-hex: {len(here)} units at {pos}")
    _unique_ids(world, problems)
    for side in COLONISERS:
        stock = world.stock.get(side)
        if stock is None or set(stock) != set(RESOURCES):
            problems.append(f"stock: {side} has resources {sorted(stock or ())}, expected {sorted(RESOURCES)}")
        else:
            for res, n in stock.items():
                if not _whole(n) or n < 0:
                    problems.append(f"stock: {side} has {n!r} {res}")
        if not _whole(world.favour.get(side)) or world.favour[side] < 0:
            problems.append(f"favour: {side} has {world.favour.get(side)!r}")
    seen, capitals = set(), {}
    for c in world.colonies:
        where = f"{c.owner} colony {c.name} at {c.pos}"
        if not 1 <= c.pop <= MAX_POP:
            problems.append(f"colony-pop: {where} has {c.pop} people (1..{MAX_POP})")
        if not world.is_land(c.pos):
            problems.append(f"colony-hex: {where} is not on land")
        if c.pos in seen:
            problems.append(f"colony-hex: two colonies at {c.pos}")
        seen.add(c.pos)
        if c.owner not in COLONISERS + (CROWN,):
            problems.append(f"colony-owner: {where} belongs to {c.owner!r}")
        elif c.owner in world.dead:
            problems.append(f"colony-owner: {where} belongs to a side that is out of the game")
        capitals.setdefault(c.owner, []).append(c.capital)
    for side, flags in capitals.items():
        if sum(flags) != 1:
            problems.append(f"colony-capital: {side} has {sum(flags)} capitals among {len(flags)} colonies")
    for tribe, sides in world.tension.items():
        for side, t in sides.items():
            if not 0 <= t <= TENSION_WAR + 50:
                problems.append(f"tension: tribe {tribe} vs {side} is {t}")
            if side in world.war[tribe] and t < TENSION_PEACE:
                problems.append(f"tension: tribe {tribe} is at war with {side} at tension {t} (peace below "
                                f"{TENSION_PEACE})")
            if side not in world.war[tribe] and t >= TENSION_WAR:
                problems.append(f"tension: tribe {tribe} is at peace with {side} at tension {t}")
        if not world.war[tribe] <= set(COLONISERS):
            problems.append(f"tension: tribe {tribe} is at war with {sorted(world.war[tribe])}")
    for pos, key in world.improvements.items():
        if key not in IMPROVEMENTS:
            problems.append(f"improvement: unknown building {key!r} at {pos}")
        elif not world.in_bounds(pos) or world.terrain[pos] not in IMPROVEMENTS[key].terrains:
            problems.append(f"improvement: {key} at {pos} stands on {world.terrain.get(pos)!r}")
        if world.colony_at(pos) or world.village_at(pos):
            problems.append(f"improvement: {key} under a colony or village at {pos}")
    if world.turn < 1 or (world.goal == GOAL_SURVIVE and world.turn > SURVIVE_TURNS):
        problems.append(f"turn: turn {world.turn} is out of range")
    if world.current not in TURN_ORDER:
        problems.append(f"turn: it is the turn of {world.current!r}")
    if world.winner not in (None, DRAW) + COLONISERS:
        problems.append(f"winner: {world.winner!r} is not a side")
    if not world.dead <= set(COLONISERS) or any(not world.eliminated(s) for s in world.dead):
        problems.append(f"dead: {sorted(world.dead)} are out of the game but not all eliminated")
    ghosts = sorted({u.owner for u in world.units if u.owner in world.dead})
    if ghosts and world.winner is None:
        problems.append(f"dead-side-units: {ghosts} are out of the game but still have units on the map")
    if world.declared is not None and (world.goal != GOAL_INDEPENDENCE or not 1 <= world.declared <= world.turn):
        problems.append(f"independence: declared on turn {world.declared} in a {world.goal} game")
    if not 0 <= world.royal_waves <= ROYAL_WAVES or (world.royal_waves and world.declared is None):
        problems.append(f"independence: {world.royal_waves} royal waves landed")
    if world.declared is None and world.units_of(CROWN):
        problems.append("independence: royal troops before anyone declared independence")
    if not world.visible <= world.terrain.keys():
        problems.append("fog: visible hexes off the map")
    _forward(world, problems, turn=world.turn)
    return problems


def check_colony(world):
    _raise(colony_problems(world), "Colonisation")


# ----- Age of Discovery ----------------------------------------------------------------------------------------
def _no_retreat(world, battle, tag):
    """True when a side of the battle has no hex to retreat to (its units, or nothing, standing on the battle's hex)."""
    units = [u for u in world.units if u.pos == battle.pos and u.owner == tag]
    return world.retreat_spot(units, battle.pos) is None


def _battle_problems(world, battle, claimed):
    """Battle slice 1: the two sides are at war and stand on the battle's hex (the defender may hold its garrison
    there instead), every regiment in a lane is a living unit of its side on that hex, no unit is in two battles
    (`claimed` collects the ids of the regiments that fight on the hex), the damage carried is a fraction of a hit point,
    the battle has a name, and it is not older than the safety stop allows (decision 7: a battle goes on past it only
    while neither side can retreat)."""
    from hexa.campaign.data import BATTLE_MAX_SEASONS
    where = f"battle at {battle.pos}"
    problems = []
    if not world.at_war(battle.attacker, battle.defender):
        problems.append(f"battle: {where} is not between two countries at war")
    if not battle.name:
        problems.append(f"battle: {where} has no name")
    if world.turn - battle.start + 1 > BATTLE_MAX_SEASONS + 1 and not (
            _no_retreat(world, battle, battle.attacker) and _no_retreat(world, battle, battle.defender)):
        problems.append(f"battle: {where} is older than the safety stop and a side could still retreat")
    here = {u.owner for u in world.units if u.pos == battle.pos and u.kind.war}
    prov = world.provinces.get(battle.pos)
    garrison = prov is not None and prov.controller == battle.defender and prov.garrison > 0
    if battle.attacker not in here or (battle.defender not in here and not garrison):
        problems.append(f"battle: {where} lacks one of its sides ({battle.attacker} v {battle.defender})")
    living = {u.id: u for u in world.units}
    for tag, lanes in battle.lanes.items():
        for uid in lanes:
            if uid is None or uid == "garrison":
                continue
            unit = living.get(uid)
            if unit is None or unit.owner != tag or unit.pos != battle.pos:
                problems.append(f"battle: {where} has unit #{uid} in a {tag} lane, which is not a living {tag} unit there")
    for uid in sorted(battle.members):
        unit = living.get(uid)
        if unit is None or unit.pos != battle.pos:
            continue
        if uid in claimed:
            problems.append(f"battle: unit #{uid} is in two battles")
        claimed.add(uid)
    for key, value in battle.carry.items():
        if not 0 <= value < 1:
            problems.append(f"battle: {where} carries {value!r} damage for {key}")
    return problems


def campaign_problems(world):
    from hexa.campaign import tech
    from hexa.campaign.data import END_YEAR, GARRISON_HP, GOODS, PRICE_CAP, PRICE_FLOOR
    problems = []
    countries = world.countries
    alive = {tag for tag, c in countries.items() if c.alive}
    living = set(world.units)
    for u in world.units:
        where = f"{u.owner} {u.kind.key} #{u.id} at {u.pos}"
        ship = u.carrier
        if ship is None:
            on = world.is_sea(u.pos) if u.naval else u.pos in world.provinces
            if not on:
                problems.append(f"unit-hex: {where} stands on {world.terrain.get(u.pos)!r}")
        elif ship not in living or not ship.naval or ship.owner != u.owner or ship.pos != u.pos or u.naval:
            problems.append(f"cargo: {where} is aboard {ship.owner} {ship.kind.key} #{ship.id} at {ship.pos}, "
                            f"which can't carry it")
        if not 0 <= u.morale <= 1:
            problems.append(f"unit-morale: {where} has morale {u.morale!r}")
        if not 0 < u.hp <= u.kind.hp:
            problems.append(f"unit-hp: {where} has {u.hp} HP (max {u.kind.hp})")
        if not 0 <= u.moves_left <= u.kind.moves:
            problems.append(f"unit-moves: {where} has {u.moves_left} moves left (max {u.kind.moves})")
        if u.owner not in alive:
            problems.append(f"unit-owner: {where} belongs to a country that is gone")
        if u.naval:
            aboard = world.cargo(u)
            if len(aboard) > u.kind.capacity:
                problems.append(f"cargo: {where} carries {len(aboard)} units (capacity {u.kind.capacity})")
    for pos, stack in _stacks(world.units).items():
        owners = {u.owner for u in stack}
        if len(owners) > 1:
            battle = world.battle_at(pos)      # a battle hex holds its two sides and no one else
            if battle is None or owners != {battle.attacker, battle.defender}:
                problems.append(f"one-country-per-hex: {sorted(owners)} at {pos}")
            else:                             # each side of a battle hex keeps to the stack limit of its own country
                for tag in sorted(owners):
                    side = [u for u in stack if u.owner == tag]
                    if not world.can_stand(side, pos, others=[]):
                        problems.append(f"stack-limit: {tag}'s side of the battle at {pos} is too big")
        elif not stack[0].naval and stack[0].owner in countries and not world.can_stand(stack, pos, others=[]):
            kinds = ", ".join(sorted(u.kind.key for u in stack))
            problems.append(f"stack-limit: {stack[0].owner} stack at {pos} is too big ({kinds})")
    _unique_ids(world, problems)
    claimed = set()
    for battle in world.battles:
        problems.extend(_battle_problems(world, battle, claimed))
    owned = {}
    for prov in world.provinces.values():
        where = f"{prov.name} at {prov.pos}"
        if prov.owner is None:
            if prov.controller is not None:
                problems.append(f"province-owner: nobody's {where} is held by {prov.controller}")
        else:
            owned.setdefault(prov.owner, []).append(prov)
            if prov.owner not in alive:
                problems.append(f"province-owner: {where} belongs to {prov.owner!r}, not a living country")
            if prov.controller not in countries:
                problems.append(f"province-owner: {where} is held by {prov.controller!r}, not a country")
        for cls in ("peasants", "burghers", "nobles", "natives"):
            n = getattr(prov, cls)
            if not math.isfinite(n) or n < 0:
                problems.append(f"population: {where} has {n!r} {cls}")
        if not 0 <= prov.garrison <= prov.castle * GARRISON_HP:
            problems.append(f"garrison: {where} has garrison {prov.garrison} with castle level {prov.castle}")
    cache = world._owned
    if cache is not None:
        for tag in set(cache) | set(owned):
            if [id(p) for p in cache.get(tag, ())] != [id(p) for p in owned.get(tag, ())]:
                problems.append(f"ownership-cache: provinces_of({tag!r}) is out of date (call changed(ownership=True))")
    for tag, country in countries.items():
        if not math.isfinite(country.treasury):
            problems.append(f"treasury: {tag} has {country.treasury!r} ducats")
        capital = world.provinces.get(country.capital)
        if country.alive and (capital is None or capital.owner != tag):
            problems.append(f"capital: {tag}'s capital {country.capital} belongs to "
                            f"{capital.owner if capital else 'no province'!r}")
        if not country.explored <= world.terrain.keys():
            problems.append(f"fog: {tag} explored hexes off the map")
        named = country.techs | set(country.queue) | ({country.researching} - {""})
        unknown = sorted(key for key in named if tech.tech(key) is None)
        if unknown:
            problems.append(f"tech: {tag} knows, researches or queues techs that don't exist: {unknown}")
    pairs = set()
    for war in world.wars:
        pair = frozenset((war.a, war.b))
        if war.a == war.b or not pair <= alive:
            problems.append(f"war: {war.a} against {war.b}, but both must be different living countries")
        if pair in pairs:
            problems.append(f"war: {war.a} and {war.b} are at war twice")
        pairs.add(pair)
    for market in world.markets:
        for g, good in GOODS.items():
            price, base = market.price[g], good.price
            low, high = (base, base) if good.kind == "money" else (base * PRICE_FLOOR, base * PRICE_CAP)
            if not low - 1e-9 <= price <= high + 1e-9:
                problems.append(f"prices: {g} costs {price!r} in {market.name} ({low:g}..{high:g})")
    if not world.visible <= world.terrain.keys():
        problems.append("fog: visible hexes off the map")
    if world.player is None and world.visible != world.terrain.keys():
        problems.append("fog: with no player every hex is visible")
    if world.over != (world.year() > END_YEAR):
        problems.append(f"over: over is {world.over} in {world.year()}")
    _forward(world, problems, turn=world.turn, version=world.version)
    return problems


def check_campaign(world):
    _raise(campaign_problems(world), "Age of Discovery")
