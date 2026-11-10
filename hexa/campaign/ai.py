"""Computer-run countries in the Age of Discovery campaign.

Each country, once per season: sets taxes, sends merchants, builds, keeps an army, fights its
wars, and (for Atlantic powers) explores and colonises. AI countries know only the map they
have explored.
"""
from collections import deque

from ..hexgrid import distance, neighbors
from . import geo
SCALE = geo.SCALE
from .data import (BUILDINGS, CARAVEL, CARRACK, COLONIST, GARRISON_DEFENSE, GARRISON_HP, GENERAL, GOODS,
                   MANUFACTORY_TAX, PIONEER, PRODUCTION_TAX, troop,
                   SETTLEMENT_TAX, WORKS, WORKS_BONUS, WORKS_COST)

# (tag: first turn it starts colonising; Portugal and Castile lead the way)
MAX_WARS = 3


def run(world, tag):
    country = world.countries[tag]
    if not country.alive or world.over:
        return
    memory = country.memory
    memory.setdefault("seed", sum(ord(ch) for ch in tag))
    country.tax = "high" if country.treasury < 0 else "low" if country.treasury > 600 else "normal"
    _merchants(world, tag)
    for _ in range(1 + int(country.treasury > 1500) + int(country.treasury > 4000)):
        _build(world, tag)
    _army(world, tag)
    _pioneers(world, tag)
    if _colonial(world, tag):
        _colonise(world, tag)
    _diplomacy(world, tag)


# ----- money ---------------------------------------------------------------------------
def _merchants(world, tag):
    country = world.countries[tag]
    free = world.merchants(tag) - len(country.orders)
    if free <= 0:
        return
    mine = world.merchant_markets(tag)
    options = []
    for route in world.routes:
        if route.a in mine or route.b in mine:
            for g, src, dst, margin, amount in world.merchant_options(tag, route)[:3]:
                if margin > 0.2:
                    options.append((margin * amount, route, g, src))
    options.sort(key=lambda o: -o[0])
    for _, route, g, src in options[:free]:
        world.send_merchant(tag, route, g, src)
    # Recall merchants whose trade has turned into a loss.
    for route in world.routes:
        for owner, g, amount, profit in route.results:
            if owner == tag and profit < 0:
                world.recall_merchant(tag, route, (g, next(o[2] for o in route.orders if o[0] == tag and o[1] == g)))


def _gain(world, prov, key):
    """Rough extra ducats per season a building would bring."""
    market = prov.market
    if not market:
        return 0
    if key == "settlement":
        step = SETTLEMENT_TAX[min(3, prov.settlement + 1)] - SETTLEMENT_TAX[prov.settlement]
        return 0.5 + (prov.peasants * 0.02 + prov.burghers * 0.15) * step + (1.0 if prov.settlement == 0 else 0)
    if key == "castle":
        country = world.countries[prov.owner]
        border = any(world.army_strength(t) > world.army_strength(prov.owner) for t in world.neighbours_of(prov.owner))
        if prov.pos == country.capital and prov.castle < 2:
            return 2.0
        return 0.6 if border and prov.settlement >= 2 and prov.castle < 1 else 0
    if key in ("weaver", "toolmaker", "armoury"):
        b = BUILDINGS[key]
        made = sum(n * market.price[g] for g, n in b.outputs.items())
        cost = sum(n * market.price[g] for g, n in b.inputs.items())
        staff = min(1.0, prov.burghers / (b.needs_burghers * (prov.level(key) + 1)))
        return max(0.0, made - cost) * MANUFACTORY_TAX * staff
    if key == "marketplace":
        return 1.0 + prov.burghers * 0.03
    return 0


def _build(world, tag):
    country = world.countries[tag]
    reserve = 80 + 3 * max(5.0, country.balance)
    if country.treasury < reserve:
        return
    provinces = sorted(world.provinces_of(tag), key=lambda p: -p.pop)[:14]
    best = None
    for prov in provinces:
        for key in ("settlement", "castle", "weaver", "toolmaker", "armoury", "marketplace"):
            if not world.build_check(tag, prov, key)[0]:
                continue
            value = _gain(world, prov, key) / world.build_cost(prov, key)
            if best is None or value > best[0]:
                best = (value, prov, key)
    if _colonial(world, tag):
        capital = world.provinces[country.capital]
        ports = [p for p in world.provinces_of(tag) if p.level("port")]
        if not ports and capital.coastal and world.build_check(tag, capital, "port")[0]:
            best = (1, capital, "port")
    if best and world.countries[tag].treasury - world.build_cost(best[1], best[2]) > reserve * 0.5:
        world.build(tag, best[1], best[2])


def _pioneers(world, tag):
    """Keep a few pioneers busy improving the best tiles."""
    country = world.countries[tag]
    pioneers = [u for u in world.units_of(tag) if u.kind is PIONEER]
    wanted = 1 + len(world.provinces_of(tag)) // 25
    if len(pioneers) < wanted and country.treasury > 200 and country.balance > 3:
        capital = world.provinces[country.capital]
        unit = world.recruit(tag, capital, PIONEER)
        if unit:
            pioneers.append(unit)
    claimed = set()
    occupied = world.owners_at()
    for unit in pioneers:
        if unit not in world.units or unit.moves_left <= 0 or unit.carrier:
            continue
        if world.improve_check(unit)[0] and country.treasury > 150:
            world.improve(unit)
            continue
        mass = world.landmass.get(unit.pos)
        sites = [p for p in world.provinces_of(tag) if p.good in WORKS and p.works < 3 and p.controller == tag
                 and p.pos not in claimed and world.landmass.get(p.pos) == mass
                 and (p.pos not in occupied or p.pos == unit.pos)]
        near = [p for p in sites if distance(p.pos, unit.pos) <= 10 * SCALE]
        sites = near or sites
        if not sites:
            continue
        def value(p):
            price = p.market.price[p.good] if p.market else GOODS[p.good].price
            return p.output * WORKS_BONUS * price / WORKS_COST[p.works] - distance(p.pos, unit.pos) * 0.002
        goal = max(sites, key=value).pos
        claimed.add(goal)
        if goal != unit.pos:
            world.move(unit, world.step_toward(unit, goal))
        if unit.pos == goal and world.improve_check(unit)[0] and country.treasury > 150:
            world.improve(unit)


# ----- armies and war ---------------------------------------------------------------------
def _army(world, tag):
    country = world.countries[tag]
    enemies = world.enemies(tag)
    troops = [u for u in world.units_of(tag) if u.kind.war]
    wanted = max(2, round(world.total_pop(tag) / 300 * (1.4 if enemies else 1.0)))
    if len(troops) < wanted and country.treasury > 70 and country.balance > 0:
        _raise(world, tag, troops)
    capital = world.provinces[country.capital]
    if len(troops) >= 8 and country.treasury > 300 and not any(u.kind is GENERAL for u in world.units_of(tag)):
        world.recruit(tag, capital, GENERAL)
    stacks = {}
    for unit in world.units_of(tag):
        if unit.carrier is None and (unit.kind.war or unit.kind is GENERAL):
            stacks.setdefault(unit.pos, []).append(unit)
    for pos, stack in sorted(stacks.items()):
        if not all(u in world.units for u in stack) or min(u.moves_left for u in stack) <= 0:
            continue
        if enemies:
            _campaign(world, tag, stack, enemies)
        else:
            _gather(world, tag, stack)
    if country.treasury > 400:
        for unit in [u for u in world.units_of(tag) if u.kind.war]:
            if world.refit_check(unit)[0]:
                world.refit(unit)


def _raise(world, tag, troops):
    country = world.countries[tag]
    n = len(troops) + 1
    count = lambda b: sum(1 for u in troops if u.kind.branch == b)
    branch = "infantry"
    if count("cavalry") < 0.3 * n:
        branch = "cavalry"
    if n >= 4 and count("artillery") < 0.15 * n:
        branch = "artillery"
    places = sorted((p for p in world.provinces_of(tag) if p.settlement >= 2 and not p.busy),
                    key=lambda p: (p.pos != country.capital, -p.pop))[:4]
    for kind in (troop(branch, country.era), troop("infantry", country.era)):
        for prov in places:
            if world.recruit(tag, prov, kind):
                return


def _gather(world, tag, stack):
    capital = world.countries[tag].capital
    if distance(stack[0].pos, capital) <= SCALE:
        return
    home = world.provinces.get(stack[0].pos)
    if home and home.owner == tag and distance(stack[0].pos, capital) <= 4 * SCALE:
        return
    world.move_group(stack, world.step_toward_group(stack, capital))


def _defence_power(world, pos):
    power = world.stack_power(world.units_at(pos))
    prov = world.provinces.get(pos)
    if prov and prov.castle and prov.garrison > 0:
        power += (3 + GARRISON_DEFENSE + 2 * prov.castle) / 2 * prov.garrison / (prov.castle * GARRISON_HP) * 1.5
    return power


def _campaign(world, tag, stack, enemies):
    ours = world.stack_power(stack)
    best = None
    for pos, stand in world.attack_options_group(stack).items():
        theirs = _defence_power(world, pos)
        ratio = ours / max(1.0, theirs)
        if stand == "bombard" or ratio >= 1.3:
            value = ratio + (2 if stand == "bombard" else 0)
            if best is None or value > best[0]:
                best = (value, pos)
    if best:
        world.attack_group(stack, best[1])
        return
    here = world.provinces.get(stack[0].pos)
    if here and here.owner in enemies | {tag} and here.controller != tag:
        return                                      # keep the siege going
    lost = [p for p in world.provinces_of(tag) if p.controller != tag]
    guns = any(u.kind.branch == "artillery" for u in stack)
    targets = lost or [p for e in enemies for p in world.provinces_of(e)
                       if p.controller != tag and (guns or p.castle == 0 or len(stack) >= 5)]
    if not targets:
        return
    goal = min(targets, key=lambda p: distance(p.pos, stack[0].pos)).pos
    if distance(goal, stack[0].pos) > 30 * SCALE:
        return
    world.move_group(stack, world.step_toward_group(stack, goal))


def _diplomacy(world, tag):
    memory = world.countries[tag].memory
    if world.enemies(tag) or (world.turn + memory["seed"]) % 8 or len(world.wars) >= MAX_WARS:
        return
    if world.rng.random() > 0.12:
        return
    mine = world.army_strength(tag)
    weak = [t for t in world.neighbours_of(tag) if world.countries[t].alive and
            world.army_strength(t) * 1.8 < mine and not world.enemies(t)]
    if weak and world.countries[tag].treasury > 100 and mine >= 2:
        world.declare_war(tag, world.rng.choice(sorted(weak)))


# ----- exploration and colonies --------------------------------------------------------------
def _colonial(world, tag):
    if tag not in world.colonial or world.turn < world.colonial[tag]:
        return False
    return world.countries[tag].balance > 8 and any(p.level("port") for p in world.provinces_of(tag))


def _colonise(world, tag):
    country = world.countries[tag]
    memory = country.memory
    ships = [u for u in world.units_of(tag) if u.naval]
    colonists = [u for u in world.units_of(tag) if u.kind is COLONIST]
    home_ports = [p for p in world.provinces_of(tag) if p.level("port")]
    if not home_ports:
        return
    home = min(home_ports, key=lambda p: (geo.lonlat(p.pos)[0], -p.pop))

    if not ships and country.treasury > 140:
        world.recruit(tag, home, CARRACK if home.level("shipyard") else CARAVEL)
        return
    colonies = len(world.colonies_of(tag))
    limit = 1 + int(country.balance // 20) + world.turn // 40
    target = memory.get("target")
    if target and (world.provinces[target].owner is not None):
        target = memory["target"] = None
    if target is None and colonies < limit and ships:
        target = memory["target"] = _pick_site(world, tag, ships[0])

    if not memory.get("west") and any(_new_world(world, p) for p in country.explored if p in world.provinces):
        memory["west"] = True
    explore = colonies >= 2 and not memory.get("west")
    for ship in ships:
        if ship not in world.units:
            continue
        aboard = world.cargo(ship)
        if aboard and target:
            _sail_and_land(world, ship, aboard, target)
        elif target and not colonists and country.treasury > 120 and not explore:
            port = _port_next_to(world, tag, ship)
            if port:
                unit = world.recruit(tag, port, COLONIST)
                if unit:
                    world.move(unit, ship.pos)
            else:
                world.move(ship, world.step_toward(ship, _sea_by(world, home.pos)))
        elif target is None or not colonists or (explore and not aboard):
            frontier = _frontier(world, tag, ship)
            if frontier:
                world.move(ship, world.step_toward(ship, frontier))
            else:
                world.move(ship, world.step_toward(ship, _sea_by(world, home.pos)))
    for colonist in colonists:
        if colonist not in world.units or colonist.carrier:
            continue
        prov = world.provinces.get(colonist.pos)
        if prov and prov.owner is None:
            africa = geo.lonlat(prov.pos)[1] < 17 and geo.lonlat(prov.pos)[0] > -20
            if world.found(colonist, trading_post=africa and world.found_check(colonist, True)[0]):
                memory["target"] = None
                continue
        free = [s for s in ships if len(world.cargo(s)) < s.kind.capacity and distance(s.pos, colonist.pos) == 1]
        if free:
            world.move(colonist, free[0].pos)


def _sail_and_land(world, ship, aboard, target):
    if distance(ship.pos, target) > 1:
        dest = _sea_by(world, target)
        if dest:
            world.move(ship, world.step_toward(ship, dest))
    if distance(ship.pos, target) <= 1:
        for unit in aboard:
            if world.unit_at(target) is None and world.provinces[target].owner is None:
                if world.move(unit, target) and unit.kind is COLONIST:
                    africa = geo.lonlat(target)[1] < 17 and geo.lonlat(target)[0] > -20
                    if not world.found(unit, trading_post=africa and world.found_check(unit, True)[0]):
                        world.found(unit)
                    world.countries[unit.owner].memory["target"] = None
                    break


def _port_next_to(world, tag, ship):
    for n in neighbors(ship.pos):
        prov = world.provinces.get(n)
        if prov and prov.owner == tag and prov.peasants >= 3:
            return prov
    return None


def _sea_by(world, pos):
    seas = [n for n in neighbors(pos) if world.is_sea(n)]
    if seas:
        return min(seas)
    for r in range(2, 5 * SCALE):
        found = [p for p in _ring(pos, r) if world.is_sea(p)]
        if found:
            return min(found)
    return None


def _ring(pos, r):
    from ..hexgrid import within
    return [p for p in within(pos, r) if distance(p, pos) == r]


def _pick_site(world, tag, ship):
    country = world.countries[tag]
    capital = country.capital
    body = world.sea_body.get(ship.pos)
    best = None
    for pos in country.explored:
        prov = world.provinces.get(pos)
        if not prov or prov.owner is not None or not prov.coastal or not prov.good:
            continue
        lon, lat = geo.lonlat(pos)
        if (world.in_old_world(pos) if world.map == "random" else lon > -12 and lat > 20):
            continue                              # the Old World is not for colonising
        if prov.terrain == "desert" or lon > 20:
            continue
        if not any(world.sea_body.get(n) == body for n in neighbors(pos)):
            continue
        price = GOODS[prov.good].price
        value = price * 2 + (2 if prov.terrain in ("plains", "jungle") else 0) - distance(pos, capital) / (12 * SCALE)
        value -= prov.natives / 8 * SCALE * SCALE
        if _new_world(world, pos):
            value += 3                            # the New World is the prize
        if any(p.owner == tag for p in (world.provinces.get(n) for n in neighbors(pos)) if p):
            value += 3
        if best is None or value > best[0]:
            best = (value, pos)
    return best[1] if best else None


def _new_world(world, pos):
    """Land across the ocean: the Americas, or a random world's unknown continents."""
    if world.map == "random":
        return not world.in_old_world(pos) and geo.lonlat(pos)[0] < world.geo.START[0] - 30
    return geo.lonlat(pos)[0] < -30


def _frontier(world, tag, ship):
    """The nearest known sea hex next to the unknown (searched by sailing distance)."""
    explored = world.countries[tag].explored
    lon0 = geo.lonlat(ship.pos)[0]
    seen = {ship.pos}
    queue = deque([ship.pos])
    found = []
    while queue and len(seen) < 4000 * SCALE * SCALE:
        pos = queue.popleft()
        if any(n in world.terrain and n not in explored for n in neighbors(pos)):
            found.append(pos)
            if len(found) >= 12:
                break
        for n in neighbors(pos):
            if n not in seen and world.is_sea(n) and n in explored:
                seen.add(n)
                queue.append(n)
    if not found:
        return None
    return min(found, key=lambda p: (geo.lonlat(p)[0] - lon0) * 0.3 + distance(p, ship.pos))
