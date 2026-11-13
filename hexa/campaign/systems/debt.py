"""Debt: how much a country may owe, and what happens when it cannot pay (troops desert, creditors seize buildings).

Functions taking ``world``; ``CampaignWorld`` keeps one-line facades for ``debt_limit``, ``disband`` and ``_unpaid``
(the economy's end-of-season step calls ``unpaid``; the tests call ``w._unpaid()``). The steps of ``unpaid`` stay as
separate functions so a bankruptcy rule can change one of them: ``debt_limit`` (what the creditors tolerate),
``troop_order`` (who deserts first), ``disband`` (remove troops until enough upkeep is saved) and ``seize_one``
(the creditors take one level of the costliest holding). Imports point down: never world.py, ui, render or pygame.
"""
from ...hexgrid import distance
from ..data import (BUILDINGS, CASTLE_UPKEEP, CASTLES, DEBT_FLOOR, DEBT_SEASONS, FOOD_PER_TROOP, GARRISON_HP, SETTLEMENT_UPKEEP,
                    SETTLEMENTS, WORKS_UPKEEP)

TROOP_FOOD = FOOD_PER_TROOP * 1.5       # grain a troop eats a season, at the 1.5 ducat price used without a market

# What this module changes: the country's income lines (and its treasury, when the creditors cap the debt), the
# troops it removes from world.units (through world.kill), the province's buildings, works, castle, settlement and
# garrison it takes away, and the log.
OWNS = ("countries", "units", "provinces", "log")


def debt_limit(world, tag):
    """Ducats a country may owe before its creditors act: DEBT_FLOOR, or DEBT_SEASONS seasons of its
    running costs (upkeep, army and colonies) if that is more. Interest stops at the limit too."""
    income = world.countries[tag].income
    costs = -(income.get("upkeep", 0.0) + income.get("military", 0.0) + income.get("colonies", 0.0))
    return max(DEBT_FLOOR, DEBT_SEASONS * costs)


def troop_order(world, tag):
    """The land troops of tag in the order they desert or are disbanded: oldest era first, then the
    weakest, then those furthest from the capital. The general is never among them."""
    capital = world.countries[tag].capital
    troops = [u for u in world.units_of(tag) if u.kind.war and not u.naval]
    return sorted(troops, key=lambda u: (u.kind.era, u.hp, -distance(u.pos, capital)))


def disband(world, tag, need, why="disbanded"):
    """Remove troops of tag (see troop_order) until about `need` ducats a season are saved.
    Returns (ducats saved, the units removed)."""
    country = world.countries[tag]
    saved, gone = 0.0, []
    for unit in troop_order(world, tag):
        if saved >= need:
            break
        saved += unit.kind.upkeep + TROOP_FOOD
        world.kill(unit, why)
        gone.append(unit)
    country.income["military"] = country.income.get("military", 0.0) + saved
    return saved, gone


def seize_one(world, tag):
    """Creditors take one level of the costliest thing tag's provinces run (castle, settlement, works or
    building). Returns (ducats a season saved, label) or None if there is nothing left to take."""
    best = None
    for prov in world.provinces_of(tag):
        if prov.controller != tag:
            continue
        options = [(BUILDINGS[k].upkeep, "building", k) for k, lvl in prov.buildings.items() if lvl > 0]
        if prov.works > 0:
            options.append((WORKS_UPKEEP, "works", None))
        if prov.castle > 0:
            options.append((CASTLE_UPKEEP[prov.castle] - CASTLE_UPKEEP[prov.castle - 1], "castle", None))
        if prov.settlement > 0:
            options.append((SETTLEMENT_UPKEEP[prov.settlement] - SETTLEMENT_UPKEEP[prov.settlement - 1],
                            "settlement", None))
        for saving, kind, key in options:
            rank = (-saving, prov.pos, kind, key or "")
            if best is None or rank < best[0]:
                best = (rank, prov, saving, kind, key)
    if best is None:
        return None
    _, prov, saving, kind, key = best
    if kind == "building":
        prov.buildings[key] -= 1
        label = BUILDINGS[key].name
        if key == "marketplace":
            world.refresh_markets()
    elif kind == "works":
        label = world.works_name(prov)
        prov.works -= 1
    elif kind == "castle":
        label = CASTLES[prov.castle].lower()
        prov.castle -= 1
        prov.garrison = min(prov.garrison, prov.castle * GARRISON_HP)
        world.forget_castles()
    else:
        label = SETTLEMENTS[prov.settlement].lower()
        prov.settlement -= 1
    world.changed()
    return saving, f"{label} at {world.place(prov)}"


def unpaid(world):
    """A country over its debt limit that is running a deficit cannot pay: its unpaid troops desert first,
    then its creditors seize castles, settlements, works and buildings, costliest first, until the season
    balances. If nothing is left to take, the creditors stop lending at the limit. Each step is logged."""
    for tag, country in world.countries.items():
        if not country.alive or country.balance >= 0 or country.treasury >= -debt_limit(world, tag):
            continue
        limit = debt_limit(world, tag)
        need = -country.balance
        saved, deserted = disband(world, tag, need, "deserted")
        need -= saved
        seized = []
        while need > 0:
            taken = seize_one(world, tag)
            if taken is None:
                break
            country.income["upkeep"] = country.income.get("upkeep", 0.0) + taken[0]
            need -= taken[0]
            seized.append(taken)
        if country.balance < 0 and country.treasury < -limit:
            # Nothing is left to take and the running costs still outrun the income: the creditors refuse
            # more credit, so the debt is held at the limit instead of growing without bound.
            country.treasury = -limit
            world.message(f"The creditors of {country.name} refuse more credit: its debt is held at "
                         f"{limit:,.0f} ducats.", tag, "credit")
        if deserted:
            counts = {}
            for unit in deserted:
                counts[unit.kind.name] = counts.get(unit.kind.name, 0) + 1
            names = ", ".join(f"{n} {k}" for k, n in sorted(counts.items()))
            world.bus.emit("unit_deserted", tag, count=len(deserted), kinds=counts)
            world.message(f"Unpaid troops desert {country.name}: {names}. The debt of {-country.treasury:,.0f} "
                         f"ducats is over the limit of {limit:,.0f}.", tag)
        for saving, label in seized:
            world.bus.emit("debt_seized", tag, what=label, saving=saving)
            world.message(f"Creditors seize the {label}, unpaid while {country.name} is in debt.", tag)
