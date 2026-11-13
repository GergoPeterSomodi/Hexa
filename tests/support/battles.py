"""Battle helpers for tests: two stacks side by side at war, the set-up of the battle system (slice 1).

    setup(world, attacker_spec, defender_spec, terrain=None, castle=0) -> Fight
        Picks two neighbouring land provinces of two different countries (in hex order, so the choice is the same
        every time), clears those countries' war units, puts the attacker's stack on the first hex and the
        defender's on the second, and makes the two countries enemies. A spec lists regiments as (branch, era) or
        (branch, era, count): ``[("infantry", 1, 3)]`` is three era 1 infantry regiments. ``terrain`` sets the
        defender's hex; ``castle`` gives it a castle of that level with a full garrison.

    place(world, branch, era, tag, pos, n=1) -> [Unit]
        n regiments of one troop type on a hex, for a test that builds its own stacks.

Use it on a world from ``fresh()`` (it changes units, provinces and wars). No pygame here.
"""
from collections import namedtuple

from hexa.campaign.data import GARRISON_HP, troop
from hexa.campaign.state import War
from hexa.hexgrid import neighbors

Fight = namedtuple("Fight", "attacker defender attack_pos defend_pos attackers defenders")


def place(world, branch, era, tag, pos, n=1):
    """n regiments of the troop (branch, era) for country tag on pos. Returns the new units."""
    kind = troop(branch, era)
    return [world.add_unit(kind, tag, pos, moves=kind.moves) for _ in range(n)]


def _regiments(world, spec, tag, pos):
    units = []
    for entry in spec:
        branch, era = entry[0], entry[1]
        count = entry[2] if len(entry) > 2 else 1
        units += place(world, branch, era, tag, pos, count)
    return units


def _pair(world):
    """The first (attacker hex, defender hex) of two neighbouring land provinces of different countries."""
    for prov in sorted(world.provinces.values(), key=lambda p: p.pos):
        if prov.owner is None or not world.is_land(prov.pos):
            continue
        for n in sorted(neighbors(prov.pos)):
            other = world.provinces.get(n)
            if other is None or other.owner in (None, prov.owner) or not world.is_land(n):
                continue
            if not (world.countries[prov.owner].alive and world.countries[other.owner].alive):
                continue
            return prov, other
    raise AssertionError("no two neighbouring countries on this world")


def setup(world, attacker_spec, defender_spec, terrain=None, castle=0):
    prov_a, prov_d = _pair(world)
    a, d = prov_a.owner, prov_d.owner
    world.units = [u for u in world.units if not (u.kind.war and u.owner in (a, d))]
    if not world.at_war(a, d):
        world.wars.append(War(a, d, world.turn))
    if terrain is not None:
        prov_d.terrain = terrain
    if castle:
        prov_d.castle, prov_d.garrison = castle, castle * GARRISON_HP
    attackers = _regiments(world, attacker_spec, a, prov_a.pos)
    defenders = _regiments(world, defender_spec, d, prov_d.pos)
    world.changed()
    return Fight(a, d, prov_a.pos, prov_d.pos, attackers, defenders)
