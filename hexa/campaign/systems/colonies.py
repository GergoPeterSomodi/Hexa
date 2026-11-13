"""Colonies: founding a colony or a trading post, and what colonies do each season (settlers, natives, growing up).

Functions taking ``world``; ``CampaignWorld.found_check`` and ``found`` are one-line facades, and ``grow`` calls
``settlers``, ``natives`` and ``graduate`` at the places the colonial part of the old loop sat, so the order of every
change (and every random draw) is the old one. Imports point down: never world.py, ui, render or pygame.
"""
from .. import geo, naming
from ..data import COLONIST, COLONIST_PEOPLE, COLONY_GROWTH, NATIVE_RAID_CHANCE

# What this module changes: province fields (owner, controller, colony, trading_post, peasants, natives, settlement,
# name) and the colonist units it removes from world.units.
OWNS = ("provinces", "units")

SCALE = geo.SCALE
SETTLERS = 0.04               # people a colony receives from home each season


def found_check(world, unit, trading_post=False):
    """(ok, reason): can this colonist found a colony (or a trading post) where it stands?"""
    if unit.kind is not COLONIST:
        return False, "Only colonists can found colonies"
    if unit.carrier:
        return False, "Land first"
    if unit.moves_left <= 0:
        return False, "No moves left this season"
    prov = world.provinces.get(unit.pos)
    if not prov or prov.owner is not None:
        return False, "Colonies need land nobody owns"
    if prov.terrain == "desert" and not prov.coastal:
        return False, "Nobody can live in the open desert"
    if not world.in_old_world(prov.pos) and not world.has(unit.owner, "atlantic"):
        return False, "Crossing the Atlantic needs the Astrolabe tech"
    if trading_post:
        if not prov.coastal:
            return False, "Trading posts must be on the coast"
        if prov.natives < 1.0:
            return False, "Trading posts need a native population to trade with"
    return True, ""


def found(world, unit, trading_post=False):
    """Found the colony or trading post: the province, or None if found_check says no."""
    if not found_check(world, unit, trading_post)[0]:
        return None
    prov = world.provinces[unit.pos]
    prov.owner = prov.controller = unit.owner
    if trading_post:
        prov.trading_post = True
        prov.peasants = 0.2
        what = "trading post"
    else:
        prov.colony = True
        prov.peasants = COLONIST_PEOPLE
        prov.settlement = 1
        what = "colony"
    if naming.is_wild(prov.name) and prov.tribe and not prov.city:
        prov.name = naming.colony_name(world, prov)
    world.units.remove(unit)
    world.changed(ownership=True)
    world.refresh_markets()
    country = world.countries[unit.owner]
    world.message(f"{country.name} founded a {what} at {world.place(prov)}.",
                  None if unit.owner == world.player or geo.lonlat(prov.pos)[0] < -20 else unit.owner)
    world.bus.emit("colony_founded", unit.owner, prov.pos, what=what)
    world.see_from(unit, radius=2 * SCALE)
    return prov


def settlers(world, prov, rate):
    """A colony's growth rate (the rate plus its bonus), and the settlers who keep arriving from home."""
    rate += COLONY_GROWTH * (1 + world.bonus(prov.owner, "colony_growth"))
    prov.peasants += SETTLERS
    return rate


def natives(world, prov):
    """Natives settle in a colony or trading post, and may raid a colony they outnumber."""
    if prov.colony or prov.trading_post:
        settled = prov.natives * 0.01
        prov.natives -= settled
        prov.peasants += settled * 0.5
    if prov.colony and prov.natives > prov.peasants * 2 and world.rng.random() < NATIVE_RAID_CHANCE:
        prov.peasants *= 0.8
        world.message(f"Natives raided the colony at {world.place(prov)}!", prov.owner)
        world.bus.emit("native_raid", prov.owner, prov.pos)


def graduate(world, prov):
    """A colony that has grown to COLONY_DONE people (the caller checks) becomes a full province."""
    prov.colony = False
    world.message(f"{world.place(prov)} has grown into a full province.", prov.owner, "growth", prov.pos)
