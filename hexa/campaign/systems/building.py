"""Investment and building: raising a goods tile a level, and building (or upgrading) a building, a settlement or a castle.

Functions taking ``world``; ``CampaignWorld`` keeps a one-line facade for each one the UI, the AI and the tests call.
Every ``*_check`` is paired with the action that calls it first (``build_check``/``build``, ``invest_check``/
``invest``), and the facades keep that contract. ``job_check`` (a province does one job a season) is shared with the
military module. Imports point down: never world.py, ui, render or pygame.
"""
from .. import resources, tech
from ..data import (BUILD_TURNS, BUILDINGS, CASTLE_COST, CASTLE_GOODS, CASTLES, ERAS, FARM_GOODS, GOODS, PLANTATION_GOODS,
                    SETTLEMENT_COST, SETTLEMENT_GOODS, SETTLEMENT_POP, SETTLEMENT_SLOTS, SETTLEMENTS, WORKS,
                    WORKS_BONUS, WORKS_COST, WORKS_ERA, WORKS_GOODS, WORKS_LEVELS, with_article)

# What this module changes: the province's queue, works level and busy flag, the treasury (through resources.spend),
# the local market's pending purchases, and the log.
OWNS = ("provinces", "countries", "markets", "log")

BUILDING_TECH = {"ropewalk": ("ropewalk", "ropewalk"), "powder_mill": ("powder_mill", "corned_powder"),
                 "glassworks": ("glass_leather", "glass_leather"), "tannery": ("glass_leather", "glass_leather"),
                 "university": ("university", "universities")}   # building -> (flag, tech key)


def building_name(world, prov, key):
    if key == "settlement":
        return SETTLEMENTS[min(3, prov.settlement + 1)]
    if key == "castle":
        return CASTLES[min(3, prov.castle + 1)]
    return BUILDINGS[key].name


def works_name(world, prov, level=None):
    level = prov.works if level is None else level
    if not prov.good or prov.good not in WORKS or level <= 0:
        return ""
    return WORKS[prov.good][level - 1]


def slots_used(world, prov):
    built = sum(1 for v in prov.buildings.values() if v)
    return built + sum(1 for item in prov.queue if item[0] in BUILDINGS and not prov.level(item[0]))


def goods_price(world, prov, goods):
    """What these goods cost on the province's market (ducats)."""
    market = prov.market
    return sum(n * (market.price[g] if market else GOODS[g].price * 1.5) for g, n in goods.items())


def _buy(prov, goods):
    """Book the goods as a purchase on the local market (it shows up in next season's demand)."""
    if prov.market:
        for g, n in goods.items():
            prov.market.pending[g] = prov.market.pending.get(g, 0) + n


def build_goods(world, prov, key):
    if key == "settlement":
        return SETTLEMENT_GOODS[min(3, prov.settlement + 1)]
    if key == "castle":
        return CASTLE_GOODS[min(3, prov.castle + 1)]
    return {}


def build_cost(world, prov, key):
    if key == "settlement":
        base = SETTLEMENT_COST[min(3, prov.settlement + 1)]
    elif key == "castle":
        base = CASTLE_COST[min(3, prov.castle + 1)] * (1 + world.bonus(prov.owner, "castle_cost"))
    else:
        return BUILDINGS[key].cost * (prov.level(key) + 1)
    return round(base + goods_price(world, prov, build_goods(world, prov, key)))


def job_check(world, tag, prov):
    if prov.owner != tag:
        return False, "Not your province"
    if prov.controller != tag:
        return False, "The province is occupied"
    if prov.busy:
        return False, "This province already did its job this season"
    return True, ""


def build_check(world, tag, prov, key):
    ok, reason = job_check(world, tag, prov)
    if not ok:
        return ok, reason
    if prov.queue:
        return False, "Something is already under construction here"
    if key == "settlement":
        nxt = prov.settlement + 1
        if nxt > 3:
            return False, "Already a city"
        if prov.pop < SETTLEMENT_POP[nxt]:
            return False, f"A {SETTLEMENTS[nxt].lower()} needs {SETTLEMENT_POP[nxt]}k people (has {prov.pop:.0f}k)"
    elif key == "castle":
        if prov.castle >= 3:
            return False, "Already a large castle"
        if prov.castle >= world.castle_top(tag):
            return False, "A large castle needs the Trace italienne tech"
        if prov.colony and prov.castle >= 1:
            return False, "Young colonies can only build a tower"
    else:
        b = BUILDINGS[key]
        level = prov.level(key)
        if level >= world.building_max(tag, key):
            return False, "Already at the highest level"
        if key in BUILDING_TECH and not world.has(tag, BUILDING_TECH[key][0]):
            return False, f"Needs the {tech.tech(BUILDING_TECH[key][1]).name} tech"
        if key == "university" and prov.settlement < 3:
            return False, "Universities need a city"
        if b.needs_coast and not prov.coastal:
            return False, "Needs a coastal province"
        if key == "shipyard" and not prov.level("port"):
            return False, "Build a port first"
        if not level and slots_used(world, prov) >= SETTLEMENT_SLOTS[prov.settlement]:
            if not prov.settlement:
                return False, "Needs a village (or bigger) first"
            return False, (f"No free building slots ({SETTLEMENT_SLOTS[prov.settlement]} in a "
                           f"{SETTLEMENTS[prov.settlement].lower()})")
        if b.needs_burghers and prov.burghers < b.needs_burghers * (level + 1) * 0.5:
            return False, f"Needs about {b.needs_burghers * (level + 1):.0f}k burghers to staff it"
        if prov.colony and key not in ("port", "marketplace"):
            return False, "Colonies can only build ports and marketplaces"
    cost = build_cost(world, prov, key)
    if world.countries[tag].treasury < cost:
        return False, f"Costs {cost} ducats"
    return True, ""


def build(world, tag, prov, key):
    if not build_check(world, tag, prov, key)[0]:
        return False
    resources.spend(world, tag, build_cost(world, prov, key), "build", prov.pos)
    _buy(prov, build_goods(world, prov, key))
    prov.queue.append([key, BUILD_TURNS])
    prov.busy = True
    world.message(f"{world.place(prov)}: started {with_article(building_name(world, prov, key))} "
                 f"(ready in {BUILD_TURNS} seasons).", tag)
    return True


def invest_goods(world, prov):
    return dict(WORKS_GOODS[prov.works]) if prov.works < WORKS_LEVELS else {}


def invest_cost(world, prov):
    """Ducats for the next level: a fee plus the goods it needs, at local prices."""
    if prov.works >= WORKS_LEVELS:
        return 0
    cost = WORKS_COST[prov.works] + goods_price(world, prov, invest_goods(world, prov))
    if prov.good in FARM_GOODS:
        cost *= 1 + world.bonus(prov.owner, "farm_invest")
    return round(cost)


def invest_check(world, tag, prov):
    ok, reason = job_check(world, tag, prov)
    if not ok:
        return ok, reason
    if not prov.good or prov.good not in WORKS:
        return False, "Nothing to develop here"
    if prov.works >= WORKS_LEVELS:
        return False, f"Fully developed ({works_name(world, prov)})"
    era = WORKS_ERA[prov.works]
    if world.countries[tag].era < era:
        return False, f"The next level needs the {ERAS[era][0]}"
    if prov.good in PLANTATION_GOODS and prov.works >= 2 and not world.has(tag, "plantations"):
        return False, "Plantation levels 3 and up need the Plantations tech"
    if prov.colony and prov.works >= 2:
        return False, "Young colonies can only reach level 2"
    cost = invest_cost(world, prov)
    if world.countries[tag].treasury < cost:
        return False, f"Costs {cost} ducats"
    return True, ""


def invest(world, tag, prov):
    if not invest_check(world, tag, prov)[0]:
        return False
    resources.spend(world, tag, invest_cost(world, prov), "invest", prov.pos)
    _buy(prov, invest_goods(world, prov))
    prov.works += 1
    prov.busy = True
    world.message(f"{world.place(prov)}: upgraded to {works_name(world, prov).lower()} "
                 f"(+{WORKS_BONUS * prov.works * 100:.0f}% {GOODS[prov.good].name.lower()}).", tag)
    world.bus.emit("investment_done", tag, prov.pos, level=prov.works)
    world.changed()
    return True
