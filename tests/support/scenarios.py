"""Scenario fights for the battle bands (battle slice 1, spec sections 4 and 7.3.1): one stack of regiments against
another on one hex, fought day by day with a seeded rng until a side breaks or the safety stop. tests/test_battle.py
asserts the bands and tools/battle_stats.py prints the table, so both read the same scenarios.

    stage(world, spec_a, spec_d, terrain="plains", castle=0) -> (battle, attackers, defenders)
        Both stacks on one hex, the attacker on Attack and the defender on Hold. The attacker stands on plains beside it:
        on a hill or mountain hex the battle is uphill (ELEVATION), as engage sets it.
    play(world, seed, spec_a, spec_d, terrain="plains") -> dict
        One fight to its end: days, seasons, winner, loss (share of its men lost per side, killed and wounded), the
        battle, and stopped (no side broke within the safety stop).

A spec lists regiments as (branch, era, count). Pygame-free.
"""
import math
import random

from hexa.campaign.data import BATTLE_MAX_SEASONS, DAYS_PER_SEASON, ELEVATION, GARRISON_HP
from hexa.campaign.state import Battle
from hexa.campaign.systems import combat
from tests.support.battles import place

SCENARIOS = {
    "3 pikes v 3 pikes": ([("infantry", 1, 3)], [("infantry", 1, 3)]),
    "4 pikes v 3 pikes": ([("infantry", 1, 4)], [("infantry", 1, 3)]),
    "6 pikes v 4 pikes": ([("infantry", 1, 6)], [("infantry", 1, 4)]),
    "6 pikes v 6 pikes": ([("infantry", 1, 6)], [("infantry", 1, 6)]),
    "4 pikes, 2 knights, 1 gun, both sides": ([("infantry", 1, 4), ("cavalry", 1, 2), ("artillery", 1, 1)],
                                              [("infantry", 1, 4), ("cavalry", 1, 2), ("artillery", 1, 1)]),
    "8 mixed v 5 pikes": ([("infantry", 1, 4), ("cavalry", 1, 2), ("artillery", 1, 2)], [("infantry", 1, 5)]),
}
TERRAINS = ("plains", "hills")
SEEDS = range(30)


def site(world):
    """A land hex with an owner (the attacker's country) and another live country (the defender's)."""
    pos = next(p.pos for p in sorted(world.provinces.values(), key=lambda p: p.pos)
               if p.owner is not None and world.is_land(p.pos))
    attacker = world.provinces[pos].owner
    defender = next(t for t in sorted(world.countries) if t != attacker and world.countries[t].alive)
    return pos, attacker, defender


def stage(world, spec_a, spec_d, terrain="plains", castle=0):
    """Both stacks on one hex, the attacker on Attack and the defender on Hold. ``castle`` gives the hex a castle of that
    level with a full garrison, held by the defender: an assault."""
    pos, a, d = site(world)
    world.units = [u for u in world.units if not (u.pos == pos and u.kind.war)]
    prov = world.provinces[pos]
    prov.terrain = terrain
    prov.owner = a
    prov.controller = d if castle else a
    prov.castle, prov.garrison = (castle, castle * GARRISON_HP) if castle else (0, 0)
    attackers = [u for branch, era, n in spec_a for u in place(world, branch, era, a, pos, n)]
    defenders = [u for branch, era, n in spec_d for u in place(world, branch, era, d, pos, n)]
    world.changed()
    uphill = ELEVATION.get(terrain, 0) > ELEVATION.get("plains", 0)
    battle = Battle(pos=pos, attacker=a, defender=d, start=world.turn, assault=bool(castle), uphill=uphill,
                    stance={a: "attack", d: "hold"})
    return battle, attackers, defenders


def play(world, seed, spec_a, spec_d, terrain="plains"):
    """One scenario fight to its end. At the safety stop the side with the lower army morale withdraws, as in the game
    (spec 3.5; the attacker on a tie), so the other side wins. Returns a dict: days, seasons, winner (tag), loss (share
    of its men lost per side, killed and wounded), the battle, and stopped (no side broke within the safety stop)."""
    world.rng = random.Random(seed)
    battle, _, _ = stage(world, spec_a, spec_d, terrain=terrain)
    combat.deploy(world, battle)
    men0 = dict(battle.men0)
    broke, days = None, 0
    for days in range(1, 3 * BATTLE_MAX_SEASONS + 1):
        report = combat.fight_day(world, battle)
        if report["broke"] is not None:
            broke = report["broke"]
            break
    stopped = broke is None
    if stopped:
        att = combat.army_morale(world, battle, battle.attacker)
        dfn = combat.army_morale(world, battle, battle.defender)
        broke = battle.attacker if att <= dfn else battle.defender
    winner = battle.defender if broke == battle.attacker else battle.attacker
    loss = {tag: (battle.killed.get(tag, 0.0) + battle.wounded.get(tag, 0.0)) / men0[tag]
            for tag in (battle.attacker, battle.defender)}
    return {"days": days, "seasons": math.ceil(days / DAYS_PER_SEASON), "winner": winner, "loss": loss,
            "battle": battle, "stopped": stopped}
