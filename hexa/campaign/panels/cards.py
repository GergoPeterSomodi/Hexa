"""The hover cards: (title, [(line, colour), ...]) for a hex, a unit, a troop kind and a good.

Pure functions of the world (they draw nothing); ``kit.hover_card`` draws what they return.
"""
from ...ui.theme import BAD_C, GOOD_C, MUTED, TEXT
from ..data import (BRANCH_NAMES, BUILDINGS, CASTLES, ERAS, FOOD_PER_TROOP, GOODS, MEN, NEEDS, SETTLEMENTS, TERRAIN, WAGON)


def cost_lines(world, prov, kind):
    """What raising a unit of `kind` costs in `prov`, its upkeep and (for troops) the men it takes."""
    market = prov.market if prov else None
    parts = [f"{kind.gold} ducats"] + [f"{n:g} {GOODS[g].name.lower()}" for g, n in kind.goods.items()]
    lines = [("Raise: " + " + ".join(parts), TEXT)]
    if prov and market:
        lines.append((f"   = {world.unit_cost(prov, kind)} ducats at the {market.name} market today", MUTED))
    food = f" + {FOOD_PER_TROOP:g} grain" if kind.war else ""
    lines.append((f"Upkeep: {kind.upkeep:g} ducats{food} a season", TEXT))
    if kind.war:
        lines.append((f"Takes {world.men_per_troop(world.player) * 1000:,.0f} men from the province", TEXT))
    return lines


def troop_card(world, kind, prov=None):
    """The card of a kind of unit in the raise panel."""
    if not kind.war:
        about = {"general": ["Joins a stack: +2 stack room", "+20% in his speciality (random)"],
                 "wagon": [f"Keeps its stack fed for {world.wagon_seasons(world.player)} seasons away from depots",
                           "Refills when back in supply"],
                 "scout": ["Moves 5, sees 3 hexes", "May cross enemy land in war"],
                 "pioneer": ["Builds fields, mines and lumber camps (press B on the tile)"],
                 "colonist": ["1,000 settlers: found a colony or trading post"],
                 "caravel": ["Fast explorer, sees far, carries 4 units"],
                 "carrack": ["Big ship, carries 8 units (needs a shipyard)"],
                 "galleon": ["Big gun ship, carries 10 units (needs a shipyard and the Galleon tech)"]}.get(kind.key, [])
        return kind.name, [(a, TEXT) for a in about] + cost_lines(world, prov, kind)
    strong = {"infantry": [("Strong: defending, holding castles (+30%)", GOOD_C),
                           ("Strong: against cavalry (+25% defense)", GOOD_C)],
              "cavalry": [("Strong: open land +40%, moves 5", GOOD_C),
                          ("Weak: forests and hills -30%, castles -50%", BAD_C)],
              "artillery": [("Strong: castles x2, fires 2 hexes away, no reply", GOOD_C),
                            (f"Speeds sieges (+{kind.siege} a season)", GOOD_C),
                            ("Weak: helpless up close (half defense)", BAD_C)]}[kind.branch]
    title = f"{kind.name}  ({BRANCH_NAMES[kind.branch].lower()}, {ERAS[kind.era][0]})"
    lines = [(f"Attack {kind.attack}   Defense {kind.defense}   {MEN:,} men when full   Moves {kind.moves}", TEXT)]
    return title, lines + strong + cost_lines(world, prov, kind)


def unit_card(world, unit):
    """The card of one unit in a stack: hit points, experience, supply and moves."""
    lines = []
    if unit.kind.war:
        lines.append((f"{unit.men:,} men   Attack {unit.kind.attack}+{unit.atk_up}   "
                      f"Defense {unit.kind.defense}+{unit.def_up}", TEXT))
        rank = unit.rank
        lines.append((f"Experience {unit.xp}" + (f" ({rank[1]}, +{(rank[2] - 1) * 100:.0f}%)" if rank[1] else
                                                  " (3 = Veteran, 7 = Elite)"), MUTED))
        lines.append(("Fed last season" if unit.supplied else "Hungry: no healing, loses strength",
                      GOOD_C if unit.supplied else BAD_C))
    elif unit.kind is WAGON:
        lines.append((f"Food for {unit.supplies} more season{'s' * (unit.supplies != 1)} away from depots", TEXT))
    lines.append((f"Moves {unit.moves_left}/{unit.kind.moves}", MUTED))
    return f"{world.countries[unit.owner].name}: {unit.label}", lines


def _owner_text(world, prov):
    if prov.owner:
        return world.countries[prov.owner].name + (" (colony)" if prov.colony else " (trading post)" if prov.trading_post else "")
    return f"{prov.tribe} natives" if prov.natives > 0.5 else "Empty land"


def _pass_lines(world, pos):
    lines, seen = [], set()
    for name, _, way in world.pass_edges_at(pos):
        if (name, way) not in seen:
            seen.add((name, way))
            lines.append((f"The {name} pass (to the {way}) is closed by snow until spring", BAD_C))
    return lines


def province_card(world, pos):
    """The card of the hex under the mouse: terrain, owner, good, people, supply and who stands there."""
    tag = world.player
    if tag and pos not in world.countries[tag].explored:
        return "Unknown", [("Nobody from your country has been here yet.", MUTED)]
    prov = world.provinces.get(pos)
    if not prov:
        return ("Lake" if world.terrain[pos] == "lake" else "Sea"), [("Ships only." if world.is_sea(pos) else
                                                                      "Nobody can cross it.", MUTED)]
    t = TERRAIN[prov.terrain]
    lines = [(f"{_owner_text(world, prov)}   ·   {t.name}: move {t.move}, defense +{t.defense * 100:.0f}%", TEXT)]
    if world.pass_closed(pos):
        lines += _pass_lines(world, pos)
    if prov.good:
        line = f"{GOODS[prov.good].name}"
        if prov.owner:
            line += f": {prov.output:.1f} a season, worth {prov.value:.1f} ducats"
        if prov.works:
            line += f"  ({world.works_name(prov).lower()})"
        lines.append((line, TEXT))
    if prov.owner:
        lines.append((f"Peasants {prov.peasants:.0f}k  Burghers {prov.burghers:.0f}k  Nobles {prov.nobles:.0f}k"
                      f"   ·   food {prov.food * 100:.0f}%", TEXT))
        town = " ".join(x for x in (SETTLEMENTS[prov.settlement], CASTLES[prov.castle]) if x)
        if town:
            lines.append((town + (f"   garrison {prov.garrison}" if prov.castle else ""), MUTED))
    if prov.natives >= 0.5:
        lines.append((f"{prov.tribe} people: {prov.natives:.0f}k", MUTED))
    if tag:
        limit = world.supply_limit(tag, pos)
        lines.append((f"Feeds {limit} of your troops" + ("" if prov.owner == tag else " (foreign land: half)"), GOOD_C))
    if prov.market:
        lines.append((f"Market: {prov.market.name}", MUTED))
    here = world.units_at(pos)
    if here and (here[0].owner == tag or pos in world.visible):
        troops = [u for u in here if u.kind.war]
        lines.append((f"{world.countries[here[0].owner].name}: {len(here)} unit{'s' * (len(here) != 1)}"
                      + (f", {len(troops)} troops, {sum(u.men for u in troops):,} men" if troops else ""),
                      BAD_C if here[0].owner != tag else TEXT))
    return world.place(prov), lines


def good_card(world, market, g):
    """The card of a good in a market's table: price, supply and demand, where it is made and who buys it."""
    good = GOODS[g]
    price = market.price[g]
    lines = [(f"Price {price:.2f} ducats (normal {good.price:g})",
              BAD_C if price > good.price * 1.25 else GOOD_C if price < good.price * 0.8 else TEXT),
             (f"Supply {market.supply[g]:.1f}   Demand {market.demand[g]:.1f}", TEXT),
             (f"Made here {market.produced[g]:.1f}   In {market.imports[g]:.1f}   Out {market.exports[g]:.1f}", MUTED)]
    makers = sorted((p for p in market.provinces if p.good == g), key=lambda p: -p.output)
    if makers:
        lines.append(("Made in: " + ", ".join(p.name for p in makers[:3]) + (" ..." if len(makers) > 3 else ""), TEXT))
    users = [cls for cls, needs in NEEDS.items() if g in needs or (g in ("grain", "fish") and "food" in needs)]
    built = [b.name.lower() for b in BUILDINGS.values() if g in b.inputs or (g == "cotton" and b.key == "weaver")]
    if users or built:
        lines.append(("Bought by: " + ", ".join(users + built), TEXT))
    if g in ("grain", "fish"):
        lines.append((f"Troops eat {FOOD_PER_TROOP:g} grain each a season", MUTED))
    return f"{good.name} at {market.name}", lines
