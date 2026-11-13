"""Combat values: how strong a unit is in a fight and how well it holds one. Functions taking ``world``.

``attack_value`` and ``defense_value`` are the values today's one-shot battle (war.battle) uses, and the day rules of
the battle system build on: terrain, castles, ranks, drills, techs, ideas and the general's trait all come in
here. ``general`` finds the general among some units. The values are read through ``world.bonus`` only and
nothing here changes the world. war.py re-exports the names. Imports point down: never world.py, ui, render or
pygame.
"""
from ..data import CASTLE_DEFENSE, FIGHT_ATTACK, FIGHT_DEFENSE, GENERAL, GENERAL_BONUS, PIKES_VS_HORSE, TERRAIN

# Nothing here writes the world.
OWNS = ()


def general(world, units):
    return next((u for u in units if u.kind is GENERAL), None)


def attack_value(world, unit, fight, general):
    tag, branch = unit.owner, unit.kind.branch
    flat = unit.kind.attack + unit.atk_up + world.bonus(tag, f"{branch}_attack")
    value = flat * FIGHT_ATTACK[branch][fight] * unit.rank[2] * (1 + world.bonus(tag, branch))
    if general and (general.trait == fight or (general.trait == "cavalry" and branch == "cavalry")):
        value *= 1 + GENERAL_BONUS
    return value


def defense_value(world, unit, fight, prov, castle, versus, general):
    tag, branch = unit.owner, unit.kind.branch
    value = (unit.kind.defense + unit.def_up) * FIGHT_DEFENSE[branch][fight] * unit.rank[2]
    value *= 1 + (CASTLE_DEFENSE * castle if fight == "garrison" else TERRAIN[prov.terrain].defense)
    if branch == "infantry" and versus == "cavalry":
        value *= PIKES_VS_HORSE * (1 + world.bonus(tag, "vs_horse"))
    value *= 1 + world.bonus(tag, branch)
    if general and general.trait in ("defense", fight):
        value *= 1 + GENERAL_BONUS
    return value
