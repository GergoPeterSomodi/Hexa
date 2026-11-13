"""Military: what a unit costs, raising troops and ships, refitting to the newest kind, drilling, and stack limits.

Functions taking ``world``; ``CampaignWorld`` keeps a one-line facade for each one the UI, the AI and the tests call.
``recruit_check``/``recruit``, ``refit_check``/``refit`` and ``upgrade_check``/``upgrade`` stay pairs: the action calls
its check first and the facades keep that contract. ``land_spot`` (where a new land unit appears) is in terrain.py; this module calls
it as ``world.land_spot``. Imports point down: never world.py, ui, render or pygame.
"""
from ...hexgrid import neighbors
from .. import resources
from ..data import (BRANCHES, CARAVEL, CARRACK, CIVILIAN_LIMIT, COLONIST, COLONIST_PEOPLE, GALLEON, GENERAL, GENERAL_STACK,
                    GOODS, SCOUT, STACK_BASE, UPGRADE_COST, WAGON, troop)
from .building import job_check

# What this module changes: the province (peasants, busy), the units it raises or refits, the treasury (through
# resources.spend), the local market's pending purchases, and the log.
OWNS = ("provinces", "units", "countries", "markets", "log")


def unit_cost(world, prov, kind):
    """What raising this kind costs in this province: the gold plus its goods at the local prices (ducats)."""
    market = prov.market
    goods = dict(kind.goods)
    if kind.naval and prov.level("shipyard") and "timber" in goods:
        goods["timber"] *= 0.7
    price = sum(n * (market.price[g] if market else GOODS[g].price * 1.5) for g, n in goods.items())
    gold = kind.gold * (1 + world.bonus(prov.owner, "cavalry_cost")) if kind.branch == "cavalry" else kind.gold
    return round(gold + price)


def raise_options(world, tag):
    """The kinds a country can raise now: one troop per branch of its era, then the fixed non-combat kinds."""
    era = world.countries[tag].era
    return [troop(b, era) for b in BRANCHES] + [GENERAL, WAGON, SCOUT, COLONIST, CARAVEL, CARRACK, GALLEON]


def stack_limit(world, tag, units=()):
    """How many troops may share a hex: the base, plus the country's bonus, plus a general's."""
    limit = STACK_BASE + world.bonus(tag, "stack")
    if any(u.kind is GENERAL for u in units):
        limit += GENERAL_STACK + world.bonus(tag, "general_stack")
    return int(limit)


def can_stand(world, group, pos, others=None):
    """Whether these units (all of one owner) may end their move together on pos."""
    owner = group[0].owner
    if others is None:
        others = [u for u in world.units_at(pos) if u not in group]
    if any(u.owner != owner for u in others):
        return False
    if group[0].naval:
        return True
    everyone = others + list(group)
    war = sum(1 for u in everyone if u.kind.war)
    generals = sum(1 for u in everyone if u.kind is GENERAL)
    civilians = len(everyone) - war - generals
    return war <= stack_limit(world, owner, everyone) and civilians <= CIVILIAN_LIMIT and generals <= 1


def recruit_check(world, tag, prov, kind):
    """(ok, reason): can this province raise this kind now?"""
    ok, reason = job_check(world, tag, prov)
    if not ok:
        return ok, reason
    country = world.countries[tag]
    if kind.war and kind.era != country.era:
        return False, "Your armies have moved on to newer troops"
    if kind.needs == "town" and prov.settlement < 2 and not prov.level("foundry"):
        return False, "Cannons are cast in towns and cities (or anywhere with a foundry)"
    if kind is GENERAL:
        if prov.pos != country.capital:
            return False, "Generals are appointed in your capital"
        generals = sum(1 for u in world.units_of(tag) if u.kind is GENERAL)
        if generals >= 1 + len(world.provinces_of(tag)) // 20:
            return False, "Your country cannot support more generals"
    cost = unit_cost(world, prov, kind)
    if country.treasury < cost:
        return False, f"Costs {cost} ducats"
    if kind.naval:
        if kind is CARRACK and not world.has(tag, "carrack"):
            return False, "Carracks need the Carrack tech"
        if kind is GALLEON and not world.has(tag, "galleon"):
            return False, "Galleons need the Galleon tech"
        if not prov.level("port"):
            return False, "Needs a port"
        if kind in (CARRACK, GALLEON) and not prov.level("shipyard"):
            return False, f"{kind.name}s need a shipyard"
        if not any(world.is_sea(n) and all(u.owner == tag for u in world.units_at(n)) for n in neighbors(prov.pos)):
            return False, "No free sea next to the port"
    elif world.land_spot(tag, prov, kind) is None:
        return False, "No room here or next door (stacks are full)"
    if kind is COLONIST and prov.peasants < 3:
        return False, "Needs at least 3k peasants to send settlers"
    if kind.war and prov.peasants < world.men_per_troop(tag) + 2:
        return False, "Not enough men left here (each troop takes 1,000 peasants)"
    return True, ""


def recruit(world, tag, prov, kind):
    """Raise the unit (paying, booking the goods and taking the men): the unit, or None if recruit_check says no."""
    if not recruit_check(world, tag, prov, kind)[0]:
        return None
    cost = unit_cost(world, prov, kind)
    resources.spend(world, tag, cost, "raise", prov.pos)
    prov.busy = True
    if prov.market:
        for g, n in kind.goods.items():
            prov.market.pending[g] = prov.market.pending.get(g, 0) + n
    if kind is COLONIST:
        prov.peasants -= COLONIST_PEOPLE
    if kind.war:
        prov.peasants -= world.men_per_troop(tag)
    if kind.naval:
        pos = next(n for n in neighbors(prov.pos) if world.is_sea(n) and all(u.owner == tag for u in world.units_at(n)))
    else:
        pos = world.land_spot(tag, prov, kind)
    unit = world.add_unit(kind, tag, pos)
    if kind is WAGON:
        unit.supplies = world.wagon_seasons(tag)
    world.message(f"{world.place(prov)}: raised {kind.name.lower()} for {cost} ducats.", tag)
    world.bus.emit("unit_raised", tag, unit.pos, what=kind.name, id=unit.id)
    world.see_from(unit)
    return unit


def refit_check(world, unit):
    """(ok, reason): can this troop be refitted to its branch's newest kind where it stands?"""
    country = world.countries[unit.owner]
    if not unit.kind.war or unit.kind.era >= country.era:
        return False, "Already the newest kind"
    prov = world.provinces.get(unit.pos)
    if unit.carrier or not prov or prov.owner != unit.owner or (prov.settlement < 2 and not prov.level("barracks")
                                                                  and not prov.level("foundry")):
        return False, "Refit in one of your towns or cities"
    if unit.moves_left <= 0 or unit.upgraded:
        return False, "No time left this season"
    new = troop(unit.kind.branch, country.era)
    cost = unit_cost(world, prov, new) // 2
    if country.treasury < cost:
        return False, f"Costs {cost} ducats"
    return True, ""


def refit(world, unit):
    """Refit the troop to its country's newest kind for half that kind's cost: True, or False if refit_check says no."""
    if not refit_check(world, unit)[0]:
        return False
    country = world.countries[unit.owner]
    prov = world.provinces[unit.pos]
    new = troop(unit.kind.branch, country.era)
    resources.spend(world, unit.owner, unit_cost(world, prov, new) // 2, "refit", prov.pos)
    unit.kind, unit.hp = new, new.hp
    unit.moves_left, unit.upgraded = 0, True
    world.message(f"{world.place(prov)}: refitted as {new.name.lower()}.", unit.owner)
    return True


def upgrade_cost(world, unit, stat):
    """Ducats for one more level of drill in `stat` (attack or defense), at the local prices."""
    gold, goods = UPGRADE_COST[stat]
    prov = world.provinces.get(unit.pos)
    market = prov.market if prov else None
    if unit.kind.branch == "artillery":
        goods = {"tools": 1.0} if stat == "attack" else {"iron": 2.5}
    return round(gold * (1 + (unit.atk_up if stat == "attack" else unit.def_up)) +
                 sum(n * (market.price[g] if market else GOODS[g].price) for g, n in goods.items()))


def upgrade_check(world, unit, stat):
    """(ok, reason): can this troop be drilled one level in `stat` where it stands?"""
    if not unit.kind.war:
        return False, "Only troops can be drilled"
    prov = world.provinces.get(unit.pos)
    need = "foundry" if unit.kind.branch == "artillery" else "barracks"
    if unit.carrier or not prov or prov.owner != unit.owner or not prov.level(need):
        return False, f"Needs to stand in your province with a {need}"
    if (unit.atk_up if stat == "attack" else unit.def_up) >= world.drill_max(unit.owner):
        return False, f"{stat.title()} is fully drilled"
    if unit.moves_left <= 0 or unit.upgraded:
        return False, "No time left this season"
    cost = upgrade_cost(world, unit, stat)
    if world.countries[unit.owner].treasury < cost:
        return False, f"Costs {cost} ducats"
    return True, ""


def upgrade(world, unit, stat):
    """Drill the troop one level in `stat`: True, or False if upgrade_check says no."""
    if not upgrade_check(world, unit, stat)[0]:
        return False
    resources.spend(world, unit.owner, upgrade_cost(world, unit, stat), "upgrade", unit.pos)
    if stat == "attack":
        unit.atk_up += 1
    else:
        unit.def_up += 1
    unit.moves_left, unit.upgraded = 0, True
    return True
