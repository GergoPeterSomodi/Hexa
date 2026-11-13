"""A battle's life (battle slice 1, spec sections 3.1, 3.5 and 3.6): how a battle starts and takes in a stack, the orders
(Attack, Hold, Withdraw), the phase that fights its days (``battle_season``) and how it ends (``end_battle``,
``end_battles``, and the retreat hex ``retreat_spot``). A battle is one ``state.Battle`` per hex in ``world.battles``.
The day's arithmetic is in combat.py; this module starts, orders, ends and records a battle and emits its events.

Events: ``battle_started`` (a battle begins), ``battle_joined`` (a stack joins a side), ``battle_fought`` (once per
battle per season, after its days) and ``battle_ended`` (once per battle, after it has left ``world.battles``). The
``battle_ended`` fields are the contract of docs/design/war-goals-and-peace.md section 3.4 (hexa/events.py lists them).

Functions taking ``world``; World binds the public ones as facades. ``battle_season`` is not in the season's PHASES until
the switch (PR 4), so nothing fights a battle in a game yet. Nothing here uses pygame, the window or a bus handler.
"""
import math

from ...hexgrid import distance, neighbors, within
from ..data import (BATTLE_LOG, BATTLE_MAX_SEASONS, DAYS_PER_SEASON, RETREAT_MORALE, RETREAT_RANGE, WITHDRAW_PURSUIT,
                    WOUNDED_RETURN)
from ..state import Battle
from . import combat, military, movement
from .combat import army_morale

# What this module changes: the battles, the units (position, hp, morale, experience; the dead are removed), the
# provinces (controller, siege and garrison when a castle is stormed), the battle's log, and the map's version
# (changed()).
OWNS = ("battles", "units", "provinces", "log", "version", "_owned", "_castle_list", "_markets_dirty")
STANCES = ("attack", "hold", "withdraw")


def _name(world, tag):
    return world.countries[tag].name


def _shown(world, *tags):
    """The tag a message is shown under: None when the player is one of the tags, else "nobody" (as war.battle did)."""
    return None if world.player in tags else "nobody"


def _log(world, battle, text):
    battle.log.append((world.turn, battle.days, text))
    del battle.log[:-BATTLE_LOG]


def _seasons(world, battle):
    """The seasons a battle has lasted, the season it began in counting as one."""
    return world.turn - battle.start + 1


def _side_units(world, battle, tag):
    """A side's units on the battle hex that move or surrender with it: war units, generals and wagons. The garrison is
    not a unit: it stays in its castle."""
    return [u for u in world.units_at(battle.pos) if u.owner == tag and not u.naval]


def fits(world, group, pos):
    """Whether the stack's war units may share pos with its side's units there: the stack limit of military.py, counted
    per side. The enemy's units on the hex do not count, so a battle hex holds one stack of each side."""
    tag = group[0].owner
    units = [u for u in world.units_at(pos) if u.owner == tag and u not in group] + list(group)
    return sum(1 for u in units if u.kind.war) <= military.stack_limit(world, tag, units)


def engage(world, group, pos):
    """The stack ``group`` attacks the hex ``pos`` (spec 3.1). It steps in from the hex beside pos (movement.step_in)
    unless it already stands there, then one of three things happens:
    - pos holds only the enemy's civilians (no war units, no garrison): they are overrun, and no battle starts;
    - pos is a battle the stack's country is in: the stack joins its side's reserve;
    - otherwise a battle starts. The defender is the enemy with war units on pos, or the controller of a castle with a
      garrison. Both sides are deployed into their lanes at once.
    Returns False, and changes nothing, when the attack cannot happen: the stack is not beside pos, the countries are not
    at war, the stack does not fit, or pos is a battle the stack's country is not in. The caller checks the attack first
    (the attack options of the war module)."""
    group = [u for u in group if u in world.units]
    if not group or any(u.naval or u.carrier is not None for u in group):
        return False
    owner = group[0].owner
    if any(u.owner != owner for u in group):
        return False
    stand = group[0].pos
    if stand != pos and (pos not in neighbors(stand) or (stand, pos) in world.walls()):
        return False
    if not fits(world, group, pos):
        return False
    battle = world.battle_at(pos)
    if battle is not None:
        if owner not in (battle.attacker, battle.defender):
            return False
        if stand != pos:
            movement.step_in(world, group, pos)
        return join(world, battle, group)
    return _start(world, group, pos)


def _start(world, group, pos):
    """A new battle on pos for a stack that is beside it (see engage)."""
    owner = group[0].owner
    stand = group[0].pos
    others = [u for u in world.units_at(pos) if u.owner != owner]
    prov = world.provinces[pos]
    enemy_war = sorted({u.owner for u in others if u.kind.war})
    if enemy_war:
        defender = enemy_war[0]
    elif prov.castle and prov.garrison > 0 and prov.controller not in (None, owner):
        defender = prov.controller
    else:
        defender = None
    if defender is None:
        if not others or not all(world.at_war(owner, u.owner) for u in others):
            return False
        if stand != pos:
            movement.step_in(world, group, pos)
        world.lose(others, "overrun")
        world.message(f"{_name(world, owner)} overran {len(others)} unarmed unit{'s' * (len(others) != 1)} at "
                      f"{world.place(prov)}.", _shown(world, owner, others[0].owner))
        world.changed()
        return True
    if not world.at_war(owner, defender):
        return False
    if stand != pos:
        movement.step_in(world, group, pos)
    assault = prov.controller == defender and prov.castle > 0 and prov.garrison > 0
    battle = Battle(pos=pos, attacker=owner, defender=defender, start=world.turn, assault=assault,
                    stance={owner: "attack", defender: "hold"})
    world.battles.append(battle)
    combat.deploy(world, battle)
    _log(world, battle, f"{_name(world, owner)} attacked {_name(world, defender)}"
                        + (" in its castle" if assault else ""))
    world.bus.emit("battle_started", owner, pos, defender=defender, assault=assault)
    world.changed()
    return True


def join(world, battle, group):
    """A stack already on the battle's hex joins its side's reserve (spec 3.1). Its men count in ``men0`` from now on,
    and it fights from the first day a gap opens in its side's lanes. Returns True."""
    tag = group[0].owner
    men = sum(u.men for u in group if u.kind.war)
    battle.men0[tag] = battle.men0.get(tag, 0) + men
    side = "attacker" if tag == battle.attacker else "defender"
    _log(world, battle, f"{_name(world, tag)} joined the {side} side with {men:,} men")
    world.bus.emit("battle_joined", tag, battle.pos, side=side, men=men)
    world.changed()
    return True


# ----- orders ------------------------------------------------------------------------------------------------------

def battle_order_check(world, pos, tag, stance):
    """Whether side ``tag`` may take the stance (Attack, Hold or Withdraw) in the battle on pos: (ok, reason)."""
    battle = world.battle_at(pos)
    if battle is None:
        return False, "No battle here"
    if tag not in (battle.attacker, battle.defender):
        return False, "Not your battle"
    if stance not in STANCES:
        return False, "Unknown order"
    if stance == "withdraw" and retreat_spot(world, _side_units(world, battle, tag), pos) is None:
        return False, "Nowhere to withdraw to"
    return True, ""


def battle_order(world, pos, tag, stance):
    """Set a side's stance in the battle on pos. It stays until changed. Returns False, and changes nothing, when the
    check says no."""
    if not battle_order_check(world, pos, tag, stance)[0]:
        return False
    world.battle_at(pos).stance[tag] = stance
    return True


# ----- the retreat -------------------------------------------------------------------------------------------------

def retreat_spot(world, group, pos):
    """The hex a beaten side retreats to (spec 3.6): the nearest land hex within RETREAT_RANGE that the side's country
    controls, with no enemy unit, no battle, and room for the whole side (military.can_stand). Ties go to the hex
    farthest from the enemy's nearest unit, then the lowest pos. None when there is no such hex."""
    if not group:
        return None
    tag = group[0].owner
    enemies = world.enemies(tag)
    enemy_at = [u.pos for u in world.units if u.owner in enemies and u.carrier is None]
    best = None
    for p in within(pos, RETREAT_RANGE):
        if p == pos or not world.is_land(p) or p in enemy_at or world.battle_at(p) is not None:
            continue
        prov = world.provinces.get(p)
        if prov is None or prov.controller != tag or not military.can_stand(world, group, p):
            continue
        away = min((distance(p, f) for f in enemy_at), default=0)
        key = (distance(pos, p), -away, p)
        if best is None or key < best:
            best = key
    return None if best is None else best[2]


def _move_side(world, group, pos, spot):
    """A beaten side walks from pos to spot: one unit_moved for the whole side, so the replay shows the walk."""
    lead = group[0]
    for unit in group:
        unit.pos = spot
        world.see_from(unit, refresh=False)
    if lead.owner == world.player:
        world.update_visibility()
    path = (pos, spot)
    seen = tuple(lead.owner == world.player or p in world.visible for p in path)
    world.changed()
    world.bus.emit("unit_moved", lead.owner, spot, ids=[u.id for u in group], path=path, naval=False, seen=seen)


def _pursue(world, battle, tag, share, units):
    """A withdrawal's pursuit: each regiment of the side loses ``share`` of its hp, all of it killed, none wounded
    (spec 3.4, 3.5). The garrison is not in ``units``: it stays in its castle."""
    for unit in units:
        if unit not in world.units or not unit.kind.war:
            continue
        hp = share * unit.kind.hp
        total = battle.carry.get(unit.id, 0.0) + hp
        whole = int(total)
        battle.carry[unit.id] = total - whole
        battle.killed[tag] = battle.killed.get(tag, 0.0) + hp * combat.men_per_hp(unit)
        unit.hp = max(0, unit.hp - whole)
        if unit.hp <= 0:
            world.kill(unit, "battle")


def _men_now(battle, unit):
    """The men a regiment still has: its hp less the damage it has not yet taken (battle.carry), in men."""
    if not unit.kind.hp:
        return 0.0
    return combat.men_per_hp(unit) * (unit.hp - battle.carry.get(unit.id, 0.0))


def _surrender(world, battle, tag, group):
    """No retreat hex: the side is lost. Its men count as killed (spec 6.1)."""
    battle.killed[tag] = battle.killed.get(tag, 0.0) + sum(_men_now(battle, u) for u in group)
    world.lose(group, "surrendered")


def _retreat_or_surrender(world, battle, tag, units, how):
    """The beaten side retreats to retreat_spot, or surrenders when there is none. Returns (spot or None, how)."""
    group = [u for u in units if u in world.units]
    if not group:
        return None, how
    spot = retreat_spot(world, group, battle.pos)
    if spot is None:
        _surrender(world, battle, tag, group)
        return None, "surrendered"
    _move_side(world, group, battle.pos, spot)
    if how == "broke":                       # a withdrawing side keeps its morale; a broken one is at most this low
        for unit in group:
            if unit.kind.war:
                unit.morale = min(unit.morale, RETREAT_MORALE)
    return spot, how


# ----- the end of a battle -----------------------------------------------------------------------------------------

def _experience(world, fighters, winner, loser):
    for units, gain in ((fighters[winner], 2), (fighters[loser], 1)):
        for unit in units:
            if unit in world.units and unit.kind.war:
                unit.xp += gain


def _settle_wounded(world, battle, fighters):
    """Half the wounded of each unit come back if the unit ends in supply (spec 3.6.3). The garrison's wounds are not
    units' and are not returned."""
    for units in fighters.values():
        for unit in units:
            if unit in world.units and unit.id in battle.wounded_hp:
                back = 0
                if world.in_supply(unit.owner, unit.pos):
                    back = math.floor(battle.wounded_hp[unit.id] * WOUNDED_RETURN)
                unit.hp = min(unit.kind.hp, unit.hp + back)


def _storm(world, battle, loser, how):
    """A castle falls to the attacker when the defender's army breaks or surrenders and its garrison is gone (no hp or
    no morale). A garrison still standing holds the castle: the attacker stays and the siege goes on. True if stormed."""
    prov = world.provinces[battle.pos]
    if loser != battle.defender or not battle.assault or how not in ("broke", "surrendered"):
        return False
    if prov.garrison > 0 and battle.garrison_morale > 0:
        return False
    world.bus.emit("province_captured", battle.attacker, battle.pos, loser=prov.controller, by="storm")
    prov.controller, prov.siege, prov.garrison = battle.attacker, 0, 0
    return True


def end_battle(world, battle, how, loser=None):
    """End a battle (spec 3.6). ``how``: "broke" (the loser's army broke on a day; the pursuit was on that day),
    "withdrew" (the loser withdrew, or the safety stop picked it), "peace" or "gone" (no loser: no pursuit, no retreat).
    The loser retreats to retreat_spot or surrenders; the winner's survivors gain experience, the loser's survivors less;
    the wounded come back in supply; a stormed castle goes to the attacker; the battle leaves world.battles, and then
    battle_ended is emitted once."""
    att, dfn, pos = battle.attacker, battle.defender, battle.pos
    winner = None if loser is None else (dfn if loser == att else att)
    fighters = {tag: _side_units(world, battle, tag) for tag in (att, dfn)}
    retreat = None
    if loser is not None and how in ("broke", "withdrew"):
        if how == "withdrew":
            _pursue(world, battle, loser, WITHDRAW_PURSUIT, fighters[loser])
        retreat, how = _retreat_or_surrender(world, battle, loser, fighters[loser], how)
    if loser is not None:
        _experience(world, fighters, winner, loser)
    _settle_wounded(world, battle, fighters)
    storm = _storm(world, battle, loser, how)
    if battle in world.battles:
        world.battles.remove(battle)
    world.changed(ownership=storm)
    world.bus.emit("battle_ended", att, pos, attacker=att, defender=dfn, winner=winner, loser=loser,
                   assault=battle.assault, how=how, seasons=_seasons(world, battle),
                   killed={tag: round(battle.killed.get(tag, 0.0)) for tag in (att, dfn)},
                   wounded={tag: round(battle.wounded.get(tag, 0.0)) for tag in (att, dfn)}, retreat=retreat)


def end_battles(world, a, b=None):
    """Peace between a and b (``b`` given) ends their battles, with no pursuit and no retreat (how "peace"). With only
    ``a`` (its country has disappeared) the battles it is in end (how "gone"). Both are draws: no winner, no loser."""
    for battle in sorted(world.battles, key=lambda x: x.pos):
        sides = {battle.attacker, battle.defender}
        if b is None and a in sides:
            end_battle(world, battle, "gone")
        elif b is not None and sides == {a, b}:
            end_battle(world, battle, "peace")


def _shakier(world, battle):
    """The side with the lower army morale; the attacker on a tie (the rule of combat.breaker)."""
    if army_morale(world, battle, battle.attacker) <= army_morale(world, battle, battle.defender):
        return battle.attacker
    return battle.defender


def _fight_season(world, battle):
    """One battle's season: withdrawals take effect first, then up to DAYS_PER_SEASON days, then the safety stop."""
    att, dfn = battle.attacker, battle.defender
    withdrawing = [tag for tag in (att, dfn) if battle.stance.get(tag) == "withdraw"]
    if withdrawing:
        end_battle(world, battle, "withdrew", withdrawing[0] if len(withdrawing) == 1 else _shakier(world, battle))
        return
    before = {tag: (battle.killed.get(tag, 0.0), battle.wounded.get(tag, 0.0)) for tag in (att, dfn)}
    broke, days = None, 0
    while days < DAYS_PER_SEASON and broke is None:
        broke = combat.fight_day(world, battle)["broke"]
        days += 1
    world.bus.emit("battle_fought", att, battle.pos, defender=dfn, days=days,
                   morale={tag: army_morale(world, battle, tag) for tag in (att, dfn)},
                   killed={tag: round(battle.killed.get(tag, 0.0) - before[tag][0]) for tag in (att, dfn)},
                   wounded={tag: round(battle.wounded.get(tag, 0.0) - before[tag][1]) for tag in (att, dfn)})
    if broke is not None:
        end_battle(world, battle, "broke", broke)
    elif _seasons(world, battle) >= BATTLE_MAX_SEASONS:
        end_battle(world, battle, "withdrew", _shakier(world, battle))


def battle_season(world):
    """The ``battles`` phase (spec 3.4): every battle fights its days, in pos order. A battle that ends stops there, so it
    never fights a day after it ended. The winner may start a siege in the same season (the phases that follow)."""
    if not world.battles:
        return
    for battle in sorted(world.battles, key=lambda b: b.pos):
        _fight_season(world, battle)
    world.changed()
