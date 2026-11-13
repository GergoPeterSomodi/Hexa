"""A battle's life (battle slice 1, spec sections 3.1, 3.5 and 3.6): how a battle starts and takes in a stack, the orders
(Attack, Hold, Withdraw), the phase that fights its days (``battle_season``) and how it ends (``end_battle``,
``end_battles``, and the retreat hex ``retreat_spot``). A battle is one ``state.Battle`` per hex in ``world.battles``.
The day's arithmetic is in combat.py; this module starts, orders, ends and records a battle and emits its events.

Events: ``battle_started`` (a battle begins), ``battle_joined`` (a stack joins a side), ``battle_fought`` (once per
battle per season, after its days) and ``battle_ended`` (once per battle, after it has left ``world.battles``). The
``battle_ended`` fields are the contract of docs/design/war-goals-and-peace.md section 3.4 (hexa/events.py lists them).
How a battle ends: "broke", "withdrew" or "surrendered" (a loser), "destroyed" (a side with no regiment or garrison left
after a day of the fight: the other side wins, as the loser), "peace" and "gone" (a draw: peace, a country that vanished
between seasons, or both sides destroyed on one day). A draw has no winner and no loser, so it scores nothing.

Functions taking ``world``; World binds the public ones as facades. ``battle_season`` is the season's ``battles`` phase, the
first of PHASES (season.py). A battle is named when it starts (decision 5): "Battle of X, 1525", "Second Battle of X,
1525" for a repeat. Nothing here uses pygame, the window or a bus handler.
"""
import math

from ...hexgrid import distance, neighbors, within
from ..data import (ATTACK_MORALE, BATTLE_MAX_SEASONS, DAYS_PER_SEASON, ELEVATION, RETREAT_MORALE, RETREAT_RANGE,
                    START_YEAR, STANDING_ORDERS, TERRAIN, WITHDRAW_PURSUIT, WOUNDED_RETURN)
from ..naming import is_wild
from ..state import Battle
from . import combat, military, movement, terrain
from .combat import army_morale

# What this module changes: the battles, the units (position, hp, morale, experience; the dead are removed), the
# provinces (controller, siege and garrison when a castle is stormed), the battle's log, the names given so far, and
# the map's version (changed()).
OWNS = ("battles", "battle_names", "units", "provinces", "log", "version", "_owned", "_castle_list", "_markets_dirty")
STANCES = ("attack", "hold", "withdraw")
ORDINALS = ("First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth")


def _name(world, tag):
    return world.countries[tag].name


def _shown(world, *tags):
    """The tag a message is shown under: None when the player is one of the tags, else "nobody" (as war.battle did)."""
    return None if world.player in tags else "nobody"


def _seasons(world, battle):
    """The seasons a battle has lasted, the season it began in counting as one."""
    return world.turn - battle.start + 1


def _side_units(world, battle, tag):
    """A side's units on the battle hex that move or surrender with it: war units, generals and wagons. The garrison is
    not a unit: it stays in its castle."""
    return [u for u in world.units_at(battle.pos) if u.owner == tag and not u.naval]


def _present(world, battle, tag):
    """Whether a side still has a fighting presence on the hex: a live war unit (a routed one too, it is still there) or,
    in an assault, the defender's garrison. A side with neither is gone (spec 3.6, decision 2026-11-13)."""
    if any(u.kind.war and u.hp > 0 and u.owner == tag for u in world.units_at(battle.pos)):
        return True
    return tag == battle.defender and battle.assault and world.provinces[battle.pos].garrison > 0


def fits(world, group, pos):
    """Whether the stack may stand on pos with its side's units already there: military.can_stand, counted per side. It
    checks the stack limit, the general's limit (one general) and the civilians' limit. The enemy's units do not count:
    a battle hex holds one stack of each side."""
    tag = group[0].owner
    others = [u for u in world.units_at(pos) if u.owner == tag and u not in group]
    return military.can_stand(world, list(group), pos, others)


def _in_other_battle(world, group, pos):
    """Whether a unit of the stack has fought in a battle on another hex (it is in that battle's members)."""
    ids = {u.id for u in group}
    return any(b.pos != pos and b.members & ids for b in world.battles)


def _defender(world, owner, pos):
    """The side a stack attacking pos meets: the enemy with war units there, else the controller of a castle with a
    garrison, else None (only civilians, or nothing)."""
    enemy_war = sorted({u.owner for u in world.units_at(pos) if u.owner != owner and u.kind.war})
    if enemy_war:
        return enemy_war[0]
    prov = world.provinces[pos]
    if prov.castle and prov.garrison > 0 and prov.controller not in (None, owner):
        return prov.controller
    return None


def engage_check(world, group, pos, stand=None):
    """Whether the stack ``group`` may attack the hex pos, and why not: (ok, reason). ``engage`` makes the same checks
    and changes nothing when one fails (the *_check contract). The reasons are the attack options' hover hints. A stack
    whose average morale is under ATTACK_MORALE cannot attack (spec 3.1). ``stand`` is the hex it attacks from (default:
    where it stands now); attack_options_group asks for each candidate stand."""
    group = [u for u in group if u in world.units]
    if not group:
        return False, "No units to attack with"
    owner = group[0].owner
    if any(u.owner != owner for u in group):
        return False, "One country's stack attacks at a time"
    if any(u.naval for u in group):
        return False, "Ships do not fight battles"
    if any(u.carrier is not None for u in group):
        return False, "Units aboard a ship cannot attack"
    if pos not in world.provinces or not world.is_land(pos):
        return False, "Not a land province"
    stand = group[0].pos if stand is None else stand
    if stand != pos and pos not in neighbors(stand):
        return False, "Not beside the target"
    if stand != pos and (stand, pos) in world.walls():
        return False, "A ridge or a closed pass lies between"
    wars = [u for u in group if u.kind.war and u.hp > 0]
    if not wars:
        return False, "No regiments to attack with"
    if sum(u.morale for u in wars) / len(wars) < ATTACK_MORALE:
        return False, "Too shaken to attack"
    if _in_other_battle(world, group, pos):
        return False, "Already in another battle"
    battle = world.battle_at(pos)
    if battle is not None:
        if owner not in (battle.attacker, battle.defender):
            return False, "Not your battle"
        if all(u.id in battle.members for u in wars):
            return False, "Already in this battle"
    if not fits(world, group, pos):
        return False, "Too many units for this hex"
    if battle is not None:
        return True, ""
    defender = _defender(world, owner, pos)
    if defender is None:
        others = [u for u in world.units_at(pos) if u.owner != owner]
        if not others:
            return False, "No enemy here"
        if not all(world.at_war(owner, u.owner) for u in others):
            return False, "Not at war"
        return True, ""
    if not world.at_war(owner, defender):
        return False, "Not at war"
    return True, ""


def engage(world, group, pos):
    """The stack ``group`` attacks the hex ``pos`` (spec 3.1). ``engage_check`` runs first, and nothing moves when it says
    no. Then this function makes the one step onto pos (movement.step_in, unless the stack already stands there), and one
    of three things happens:
    - pos holds only the enemy's civilians (no war units, no garrison): they are overrun, and no battle starts;
    - pos is a battle the stack's country is in: the stack joins its side's reserve (only units not yet in it count);
    - otherwise a battle starts. The defender is the enemy with war units on pos, or the controller of a castle with a
      garrison. Both sides are deployed into their lanes at once.
    The attack order does not step in itself: attack_group must call engage only (it must not call movement.step_in),
    or the stack would stand on the enemy's hex when this refuses. Returns True when the attack happened."""
    ok, _ = engage_check(world, group, pos)
    if not ok:
        return False
    group = [u for u in group if u in world.units]
    owner, stand = group[0].owner, group[0].pos
    battle = world.battle_at(pos)
    defender = None if battle is not None else _defender(world, owner, pos)
    if stand != pos:
        movement.step_in(world, group, pos)
    if battle is not None:
        return join(world, battle, group)
    if defender is None:
        _overrun(world, group, pos)
        return True
    return _start(world, group, pos, defender, stand)


def _year(turn):
    """The year of a season (the same rule as CampaignWorld.year)."""
    return START_YEAR + (turn - 1) // 4


def _ordinal(count):
    return ORDINALS[count - 1] if count <= len(ORDINALS) else f"{count}th"


def _place_name(world, pos):
    """The name of the place a battle is fought at (decision 5): the hex's province name; in wild land, the nearest named
    province within 3 hexes; else the terrain's name."""
    prov = world.provinces.get(pos)
    if prov is not None and not is_wild(prov.name):
        return prov.name
    for p in sorted(within(pos, 3), key=lambda p: (distance(pos, p), p)):
        near = world.provinces.get(p)
        if near is not None and not is_wild(near.name):
            return near.name
    return TERRAIN[prov.terrain].name if prov is not None and prov.terrain in TERRAIN else "open country"


def _battle_name(world, pos):
    """A new battle's name: "Battle of X, 1525", and "Second Battle of X, 1525" for each repeat on the same place. The
    count is kept in world.battle_names, so a repeat stays a repeat after a save."""
    base = _place_name(world, pos)
    count = world.battle_names.get(base, 0) + 1
    world.battle_names[base] = count
    title = "Battle" if count == 1 else f"{_ordinal(count)} Battle"
    return f"{title} of {base}, {_year(world.turn)}"


def _crosses_pass(world, a, b):
    """Whether the step from a to b goes through a mountain pass (an open pass edge of the geography, not a ridge)."""
    edge = frozenset((a, b))
    return any(e == edge for _, _, e, _ in terrain.pass_edges(world))


def _uphill(world, stand, pos):
    """Whether the stand hex is lower ground than the battle hex (ELEVATION of the two terrains, spec 3.4)."""
    if stand == pos:
        return False
    low, high = world.provinces[stand].terrain, world.provinces[pos].terrain
    return ELEVATION.get(low, 0) < ELEVATION.get(high, 0)


def _start(world, group, pos, defender, stand):
    """A new battle on pos for a stack that now stands there (see engage). Both sides are deployed. The attack's ground
    (crossing a pass, coming up from lower ground) is kept on the battle for the day rules."""
    owner = group[0].owner
    prov = world.provinces[pos]
    assault = prov.controller == defender and prov.castle > 0 and prov.garrison > 0
    name = _battle_name(world, pos)
    crossing = stand != pos and _crosses_pass(world, stand, pos)
    battle = Battle(pos=pos, attacker=owner, defender=defender, start=world.turn, assault=assault, name=name,
                    stance={owner: "attack", defender: standing_of(world, pos, defender)}, crossing=crossing,
                    uphill=_uphill(world, stand, pos))
    battle.members = {u.id for u in world.units_at(pos) if u.owner in (owner, defender)} | {u.id for u in group}
    world.battles.append(battle)
    combat.deploy(world, battle)
    combat.record(world, battle, "attacked", attacker=owner, defender=defender, assault=assault)
    world.bus.emit("battle_started", owner, pos, defender=defender, assault=assault, name=name,
                   year=_year(world.turn))
    world.changed()
    return True


def _overrun(world, group, pos):
    """The stack overruns the enemy's civilians on pos: they are lost, and no battle starts."""
    owner = group[0].owner
    others = [u for u in world.units_at(pos) if u.owner != owner]
    world.lose(others, "overrun")
    world.message(f"{_name(world, owner)} overran {len(others)} unarmed unit{'s' * (len(others) != 1)} at "
                  f"{world.place(world.provinces[pos])}.", _shown(world, owner, others[0].owner))
    world.changed()


def join(world, battle, group):
    """A stack already on the battle's hex joins its side's reserve (spec 3.1). Only its war units that are not yet in the
    battle count in ``men0``; every unit of the stack becomes a member. The joiners fight from the first day a gap opens
    in their side's lanes. Returns True."""
    tag = group[0].owner
    men = sum(u.men for u in group if u.kind.war and u.hp > 0 and u.id not in battle.members)
    battle.members.update(u.id for u in group)
    battle.men0[tag] = battle.men0.get(tag, 0) + men
    side = "attacker" if tag == battle.attacker else "defender"
    combat.record(world, battle, "joined", tag=tag, side=side, men=men)
    world.bus.emit("battle_joined", tag, battle.pos, side=side, men=men)
    world.changed()
    return True


# ----- standing orders (what an army does when attacked and given no order; Unit.standing) ----------------------

def standing_check(world, pos, tag, order):
    """Whether side ``tag``'s regiments on pos may take the standing order (Hold or Withdraw): (ok, reason)."""
    if order not in STANDING_ORDERS:
        return False, "Unknown order"
    if not any(u.owner == tag and u.kind.war for u in world.units_at(pos)):
        return False, "No regiments here"
    return True, ""


def standing_order(world, pos, tag, order):
    """Set the standing order of every unit of side ``tag`` on pos (the stack shares one). It is used when the stack is
    attacked and no battle order was given. Returns False, and changes nothing, when the check says no."""
    if not standing_check(world, pos, tag, order)[0]:
        return False
    for unit in world.units_at(pos):
        if unit.owner == tag:
            unit.standing = order
    world.changed()
    return True


def standing_of(world, pos, tag):
    """The stance a side takes into a battle on pos with no order of its own: its lowest-id war unit's standing order.
    "withdraw" only when a retreat hex exists (else "hold"), so the stance is always one the battle can carry out."""
    units = sorted((u for u in world.units_at(pos) if u.owner == tag and u.kind.war), key=lambda u: u.id)
    if not units or units[0].standing != "withdraw":
        return "hold"
    group = [u for u in world.units_at(pos) if u.owner == tag and not u.naval]
    return "withdraw" if retreat_spot(world, group, pos) is not None else "hold"


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
    world.changed()
    return True


# ----- the retreat -------------------------------------------------------------------------------------------------

def retreat_spot(world, group, pos):
    """The hex a beaten side retreats to (spec 3.6). Walking from pos over land, the nearest hex within RETREAT_RANGE
    steps that the side's country controls, with no enemy unit, no battle and room for the whole side (military.can_stand).
    The walk never crosses a wall (world.walls(): the ridge crests, and the mountain passes in winter), the sea or a hex
    with an enemy unit. Ties go to the hex farthest from the enemy's nearest unit, then the lowest pos. None when there is
    no such hex. It runs when an order is set or a side breaks, never per frame."""
    if not group:
        return None
    tag = group[0].owner
    enemies = world.enemies(tag)
    enemy_at = [u.pos for u in world.units if u.owner in enemies and u.carrier is None]
    blocked = set(enemy_at)
    walls = world.walls()
    steps_to = {pos: 0}
    frontier = [pos]
    for step in range(1, RETREAT_RANGE + 1):
        nxt = []
        for here in frontier:
            for n in neighbors(here):
                if n in steps_to or n in blocked or not world.is_land(n) or (here, n) in walls:
                    continue
                steps_to[n] = step
                nxt.append(n)
        frontier = nxt
    best = None
    for p, steps in steps_to.items():
        if p == pos or world.battle_at(p) is not None:
            continue
        prov = world.provinces.get(p)
        if prov is None or prov.controller != tag or not military.can_stand(world, group, p):
            continue
        away = min((distance(p, f) for f in enemy_at), default=0)
        key = (steps, -away, p)
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
    """A withdrawal's pursuit: each regiment of the side loses ``share`` of the men it has (its hp), all of it killed, none
    wounded (spec 3.4, 3.5). Never more than the men it has left. The garrison is not in ``units``: it stays in its castle."""
    for unit in units:
        if unit not in world.units or not unit.kind.war:
            continue
        carry = battle.carry.get(unit.id, 0.0)
        hp = min(share * unit.hp, max(0.0, unit.hp - carry))
        if hp <= 0:
            continue
        total = round(carry + hp, 9)
        whole = int(total)
        battle.carry[unit.id] = total - whole
        battle.killed[tag] = battle.killed.get(tag, 0.0) + hp * combat.men_per_hp(unit)
        unit.hp = max(0, unit.hp - whole)
        if unit.hp <= 0:
            world.kill(unit, "battle")


def _men_now(battle, unit):
    """The men a regiment still has: its hp less the damage it has not yet taken (battle.carry), in men. Only war units
    have men; generals, wagons and the other civilians have none (spec 6.5)."""
    if not unit.kind.war or not unit.kind.hp:
        return 0.0
    return combat.men_per_hp(unit) * (unit.hp - battle.carry.get(unit.id, 0.0))


def _surrender(world, battle, tag, group):
    """No retreat hex: the side is lost. Its war units' men count as killed (spec 6.1)."""
    battle.killed[tag] = battle.killed.get(tag, 0.0) + sum(_men_now(battle, u) for u in group if u.kind.war)
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


def _storm(world, battle, loser, how, had_field):
    """A castle falls to the attacker when the defender's army breaks or surrenders and the castle has no defence left.
    With no field units the garrison is the whole army (spec 3.6.5, decision 2026-11-13): its break stores the castle.
    With field units, the castle holds while its garrison has men and morale. True if stormed."""
    prov = world.provinces[battle.pos]
    if loser != battle.defender or not battle.assault or how not in ("broke", "surrendered", "destroyed"):
        return False
    if had_field and prov.garrison > 0 and battle.garrison_morale > 0:
        return False
    world.bus.emit("province_captured", battle.attacker, battle.pos, loser=prov.controller, by="storm")
    prov.controller, prov.siege, prov.garrison = battle.attacker, 0, 0
    return True


def end_battle(world, battle, how, loser=None, pursuit=True, cause=None):
    """End a battle (spec 3.6). ``how``: "broke" (the loser's army broke on a day; the pursuit was on that day), "withdrew"
    (the loser withdrew: on its order, or at the safety stop, which passes pursuit=False: half pursuit, or none, then the
    retreat), "destroyed" (the loser has no regiment or garrison left after a day: no retreat, the kills are already
    booked), "peace" or "gone" (a draw: no loser, no pursuit, no retreat). A side with no retreat hex surrenders after
    "broke" or "withdrew". The winner's survivors gain experience when the battle had days (the loser's survivors less);
    the wounded come back in supply; a stormed castle goes to the attacker; the battle leaves world.battles, and then
    battle_ended is emitted once. ("stalemate" is no longer an end: decision 7 makes the stop a withdrawal.)"""
    att, dfn, pos = battle.attacker, battle.defender, battle.pos
    winner = None if loser is None else (dfn if loser == att else att)
    fighters = {tag: _side_units(world, battle, tag) for tag in (att, dfn)}
    had_field = any(u.kind.war for u in fighters[dfn])     # decided before the retreat moves the units
    retreat = None
    if loser is not None and how in ("broke", "withdrew"):
        if how == "withdrew" and pursuit:
            _pursue(world, battle, loser, WITHDRAW_PURSUIT, fighters[loser])
        retreat, how = _retreat_or_surrender(world, battle, loser, fighters[loser], how)
    if loser is not None and battle.days > 0:
        _experience(world, fighters, winner, loser)
    _settle_wounded(world, battle, fighters)
    storm = _storm(world, battle, loser, how, had_field)
    if battle in world.battles:
        world.battles.remove(battle)
    world.changed(ownership=storm)
    world.bus.emit("battle_ended", att, pos, attacker=att, defender=dfn, winner=winner, loser=loser,
                   assault=battle.assault, how=how, cause=cause, seasons=_seasons(world, battle), name=battle.name,
                   year=_year(battle.start),
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


def day_cap(world, battle):
    """The most days this battle fights in this season's battles phase. "full" fights DAYS_PER_SEASON at once. "clash"
    fights only one day in the season the attack happens (the defender then has a season to answer, and allies and
    reserves can join); the days after it are fought in the later seasons' phases."""
    if getattr(world, "battle_timing", "clash") == "clash" and battle.start == world.turn:
        return 1
    return DAYS_PER_SEASON


def _fight_season(world, battle):
    """One battle's season. A side with nothing left at its start has vanished between seasons: a draw ("gone"). A
    withdrawal takes effect next. Then up to DAYS_PER_SEASON days: a side left with nothing after a day was destroyed in
    the fight, so the other side wins ("destroyed"; both at once is "gone"). Then the safety stop."""
    att, dfn = battle.attacker, battle.defender
    if not (_present(world, battle, att) and _present(world, battle, dfn)):
        end_battle(world, battle, "gone")
        return
    withdrawing = [tag for tag in (att, dfn) if battle.stance.get(tag) == "withdraw"]
    if withdrawing:
        end_battle(world, battle, "withdrew", withdrawing[0] if len(withdrawing) == 1 else _shakier(world, battle))
        return
    before = {tag: (battle.killed.get(tag, 0.0), battle.wounded.get(tag, 0.0)) for tag in (att, dfn)}
    broke, cause, days = None, None, 0
    while days < day_cap(world, battle) and broke is None:
        report = combat.fight_day(world, battle)
        broke, cause = report["broke"], report["cause"]
        days += 1
        if not (_present(world, battle, att) and _present(world, battle, dfn)):
            break
    absent = [tag for tag in (att, dfn) if not _present(world, battle, tag)]
    world.bus.emit("battle_fought", att, battle.pos, defender=dfn, days=days,
                   morale={tag: army_morale(world, battle, tag) for tag in (att, dfn)},
                   killed={tag: round(battle.killed.get(tag, 0.0) - before[tag][0]) for tag in (att, dfn)},
                   wounded={tag: round(battle.wounded.get(tag, 0.0) - before[tag][1]) for tag in (att, dfn)})
    if len(absent) == 2:
        end_battle(world, battle, "gone")
    elif absent:
        end_battle(world, battle, "destroyed", absent[0])
    elif broke is not None:
        end_battle(world, battle, "broke", broke, cause=cause)
    elif _seasons(world, battle) >= BATTLE_MAX_SEASONS:
        _safety_stop(world, battle)


def _safety_stop(world, battle):
    """The safety stop (spec 3.5, decision 7): a battle that has lasted BATTLE_MAX_SEASONS seasons ends with its lower army
    withdrawing, with no pursuit. When that side has no retreat hex the other side withdraws instead. When neither can
    retreat the battle goes on, and the stop is checked again next season. Two armies never sit on one hex unfought."""
    low = _shakier(world, battle)
    high = battle.defender if low == battle.attacker else battle.attacker
    for tag in (low, high):
        if retreat_spot(world, _side_units(world, battle, tag), battle.pos) is not None:
            end_battle(world, battle, "withdrew", tag, pursuit=False)
            return


def battle_season(world):
    """The ``battles`` phase (spec 3.4): every battle fights its days, in pos order. A battle that ends stops there, so it
    never fights a day after it ended. The winner may start a siege in the same season (the phases that follow)."""
    if not world.battles:
        return
    for battle in sorted(world.battles, key=lambda b: b.pos):
        _fight_season(world, battle)
    world.changed()
