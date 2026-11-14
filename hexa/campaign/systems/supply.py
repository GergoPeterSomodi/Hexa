"""Supply and foraging: who is fed, who starves, and what an army eats off foreign land.

Functions taking ``world``; ``CampaignWorld`` binds them as plain class attributes (``in_supply = supply.in_supply``), so
a call costs no more than the old method did. ``supply_limit`` is how many troops a hex feeds, ``is_depot`` and
``in_supply`` say where the army's own supply reaches, ``supply_state`` is what the panel shows, ``forage_check``/
``forage`` is the player's (and the AI's) way to eat a foreign province, and ``logistics`` is the season's step: feed
every stack or make it suffer attrition (it runs first in ``end_round``). Imports point down: never world.py, ui,
render or pygame.
"""
from ...hexgrid import neighbors
from ..data import (ATTRITION, FARM_GOODS, FORAGE_LOSS, FOREIGN_SUPPLY, SUPPLY_BASE, SUPPLY_PER_FARM,
                    SUPPLY_PER_PEOPLE, WAGON)

# What this module changes on the world: foraged provinces, hit points and wagon supplies of units (and the units it
# starves to death through world.kill), and the log.
OWNS = ("provinces", "units", "log")


def supply_limit(world, tag, pos):
    prov = world.provinces.get(pos)
    if not prov:
        return 0
    limit = SUPPLY_BASE + prov.pop / SUPPLY_PER_PEOPLE + \
        (prov.works * SUPPLY_PER_FARM if prov.good in FARM_GOODS else 0) + (prov.natives / 20)
    if world.is_depot(tag, pos):
        limit += world.bonus(tag, "depot_supply")
    if prov.owner != tag:
        limit *= FOREIGN_SUPPLY
    return max(1, int(limit))


def is_depot(world, tag, pos):
    prov = world.provinces.get(pos)
    return bool(prov and prov.owner == tag and prov.controller == tag and
                (prov.settlement >= 2 or prov.castle or prov.level("port")))


def in_supply(world, tag, pos):
    """Within SUPPLY_RANGE hexes of a depot, through land we control and no enemy armies."""
    enemies = world.enemies(tag)
    blocked = {u.pos for u in world.units if u.owner in enemies and u.kind.war and u.carrier is None}
    walls = world.walls()
    seen, frontier = {pos}, [pos]
    for _ in range(world.supply_reach(tag) + 1):
        nxt = []
        for p in frontier:
            if world.is_depot(tag, p):
                return True
            for n in neighbors(p):
                prov = world.provinces.get(n)
                if n in seen or not prov or prov.controller != tag or n in blocked or (p, n) in walls:
                    continue
                seen.add(n)
                nxt.append(n)
        frontier = nxt
    return False


def supply_state(world, group):
    """('supplied' | 'wagon' | 'foraging' | 'cut off', troops, limit) for a stack."""
    lead = group[0]
    troops = [u for u in group if u.kind.war]
    limit = world.supply_limit(lead.owner, lead.pos)
    prov = world.provinces.get(lead.pos)
    if world.in_supply(lead.owner, lead.pos):
        state = "supplied"
    elif any(u.kind is WAGON and u.supplies > 0 for u in group):
        state = "wagon"
    elif prov and prov.foraged == (lead.owner, world.turn):
        state = "foraging"
    else:
        state = "cut off"
    return state, len(troops), limit


def forage_check(world, group, tag=None, end_of_round=False):
    troops = [u for u in group if u.kind.war]
    if tag is not None and any(u.owner != tag for u in troops):
        return False, "Only your own troops can forage"
    if not troops:
        return False, "Only troops forage"
    lead = troops[0]
    if world.battle_at(lead.pos) is not None:
        return False, "Can't forage during a battle"     # owner decision: a battle's stacks eat from their own stores
    prov = world.provinces.get(lead.pos)
    if not prov or prov.owner == lead.owner:
        return False, "Armies only forage in foreign land"
    if prov.foraged == (lead.owner, world.turn):
        return False, "Already foraged here this season"
    if not end_of_round and min(u.moves_left for u in troops) <= 0:
        return False, "No time left this season"
    return True, ""


def forage(world, group, tag=None, end_of_round=False):
    if not world.forage_check(group, tag, end_of_round)[0]:
        return False
    troops = [u for u in group if u.kind.war]
    prov = world.provinces[troops[0].pos]
    prov.foraged = (troops[0].owner, world.turn)
    prov.peasants *= 1 - FORAGE_LOSS
    prov.natives *= 1 - FORAGE_LOSS
    for unit in troops:
        unit.foraged_turn = world.turn
        if not end_of_round:
            unit.moves_left = 0
    world.message(f"Troops foraged around {world.place(prov)}: they eat, the province suffers.", troops[0].owner)
    world.bus.emit("forage", troops[0].owner, prov.pos)
    return True


def _besieging(world, prov, tag, group):
    """Whether a stack besieges the place it stands on, the arrival season counted (0.2.2): the holder of its meter, or a
    stack alone on an enemy place with men enough, which war.sieges starts this season. A stack that arrived on the place
    is fed from its arrival, not from the season after."""
    if prov is None:
        return False
    if prov.besieger:
        return prov.besieger == tag
    if not prov.castle or prov.garrison <= 0:          # the arrival rule is for a garrisoned castle (an open place: as before)
        return False
    if prov.owner is None or prov.controller in (None, tag) or not world.at_war(tag, prov.controller):
        return False
    if world.battle_at(prov.pos) is not None or world.retreated.get(prov.pos) == world.turn:
        return False
    if any(u.owner != tag and u.kind.war for u in world.units_at(prov.pos)):
        return False
    return bool(world.siege_terms(prov, tag, group)["ok"])


def logistics(world):
    """Once per season: feed every stack, or make it suffer attrition."""
    stacks = {}
    for unit in world.units:
        if unit.carrier is None and not unit.naval:
            stacks.setdefault((unit.pos, unit.owner), []).append(unit)
    reported = set()
    for (pos, tag), group in stacks.items():
        troops = [u for u in group if u.kind.war]
        if not troops:
            continue
        prov = world.provinces.get(pos)
        besieging = _besieging(world, prov, tag, group)     # a besieger forages the place it holds for free (0.2.2)
        if tag != world.player and prov and prov.owner != tag and not besieging and not world.in_supply(tag, pos) and \
                not any(u.kind is WAGON and u.supplies > 0 for u in group):
            world.forage(group, end_of_round=True)   # computer armies forage when they must, moves or not
        state, count, limit = world.supply_state(group)
        for wagon in [u for u in group if u.kind is WAGON]:
            if state == "supplied":
                wagon.supplies = world.wagon_seasons(tag)
            elif state == "wagon" and wagon.supplies > 0:
                wagon.supplies -= 1
                break
        fed = state != "cut off" or besieging
        hurt = 0
        for unit in troops:
            unit.supplied = fed
            loss = (0 if fed else ATTRITION) + (ATTRITION if count > limit and not besieging else 0)
            if loss:
                unit.hp -= loss
                hurt += 1
                if unit.hp <= 0:
                    world.kill(unit, "starved")
        if hurt and tag == world.player and pos not in reported:
            reported.add(pos)
            why = "cut off from supply" if not fed else f"too many troops for the land ({count}/{limit})"
            where = world.place(prov) if prov else "the field"
            world.message(f"Your troops at {where} are {why}: they lose strength.", None, "supply", pos)
