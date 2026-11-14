"""The battle read model (battle slice 1, PR 6a): one plain, read-only view of a battle, for the map badge, the battle
panel, the log and the odds card. None of them reads state.Battle or the combat rules itself. Pygame-free; it changes
nothing in the world, and nothing it makes is saved.

``battle_view(world, battle_or_pos, viewer)`` returns a dict, or None when no battle is on that hex. ``battle_or_pos``
is a state.Battle or the hex it is fought on. ``viewer`` is a country tag, or None for the whole picture (tools, tests).
``odds_view(world, group, target_pos, viewer)`` returns the inputs of the odds card, their ratio and the card's one word
(``odds_word``, the bands of data.ODDS_WORDS).

Both are cached per world on ``world.version``: a view is made again only after a ``world.changed()`` (or when the
viewer, its access, the turn or the timing changes), so a frame that asks for one again gets the same object. The dicts
are read-only by convention: the cache shares them. Keys are always present; sequences are tuples.

battle_view keys: ``access`` ("exact", "seen" or "hidden", see the fog rule below), ``exact``, ``viewer``,
``viewer_role`` ("attacker", "defender" or None), ``pos``, ``name``, ``year`` (the year it began), ``start`` and
``seasons`` (the turns so far, the first counts as one), ``days`` (battle.days),
``assault``, ``crossing``, ``uphill``, ``ground`` ({terrain, lanes, castle}), ``sides`` ({"attacker": [tags],
"defender": [tags]}: lists, ready for alliances), ``side`` ({tag: side dict} for each tag in sides), ``dice`` (the
last day's {day, rolls, mult} or None), ``log`` (battlelog.describe of each record, oldest first), and ``can_order``.
A side dict has ``access``, ``men`` (now), ``start`` (men that went in, joiners included), ``killed``, ``wounded``,
``front_morale`` (combat.army_morale: the break-test measure, the men-weighted morale of the lanes, not a bar of men),
``strength`` (combat.battle_strength: men times strength morale, what the bar shows), ``lanes`` (three dicts, left,
centre, right: lane, open, broken, id, kind, rank, men, morale, shaken), ``reserve``, ``back_line`` (artillery),
``routed``, ``general`` (trait or None), ``stance``, ``standing``, ``can_order`` and ``orders`` (for the viewer's own
side: {"attack"|"hold"|"withdraw": {ok, reason}}, else None). Each lane's ``shaken`` is True for the regiment that moved up
into it on the battle's last day (combat records the ids in the day's log record), False for another regiment, None for an
empty lane or the garrison.

Fog (decided in PR 6a; the panel and the log may say so):
- exact: viewer None, or a side of the battle. Every number is exact; stances and standing orders are shown.
- seen: the hex is in the player's vision (world.player is None, or the viewer is the player and the hex is in
  world.visible), and the viewer is no side. Men, killed, wounded and strength are rounded to 100 men, morale to 5 %.
  Lanes, reserves, the dice and the log's kinds show; stances and standing orders do not; old text lines do not (their
  numbers cannot be rounded).
- hidden: anything else. The view keeps every key, with pos, name, year, sides, side, log, dice and numbers empty or None.
The odds card uses the same rule for each side: the attacker's own stack is exact to its owner; an enemy is exact to
itself, rounded when its hex is seen, and None when hidden (then no ratio). When the defence is hidden the garrison
(``defence["garrison"]``) and the Besiege entry (``besiege``) are None too; a seen garrison's men are rounded, and the
Besiege reason's men with them.

odds_view keys: ``ok`` and ``reason`` (systems/battle.engage_check), ``attacker``, ``defender`` (tags or None), ``battle``
(a battle is on the target), ``name``, ``attack`` and ``defence`` ({access, men, morale, strength}; defence also has
``terrain``, ``castle``, ``assault``, ``general``), and ``ratio`` (attack strength over defence strength, or None). The
``attack`` also has ``general``. ``factor`` is the defender's ground factor (odds_factor: GROUND_ODDS, or 1.0 in an assault, where
the garrison's weight is in its men). ``word`` is the card's one word: "Unknown" when the enemy is hidden or there is no ratio, else
odds_word(attack / defence / factor) (unrounded), so ``ratio`` itself is the plains reading. ``crossing`` and ``uphill`` say whether the attack crosses a pass or comes up from
lower ground (the battle's own, or the ones an attack would have). ``place`` is the hex's place name, ``attacker_name``
and ``defender_name`` the countries' names (``defender_name`` None when the enemy is hidden). The strength is
the same measure as battle_strength: morale times men. With a battle on the hex it is battle_strength itself; before the
battle, the same sum over the regiments on the hex (and the garrison of an assault) is worked out here, since
battle_strength needs a battle to count on.
"""
import weakref

from .battlelog import describe
from .data import DICE, ELEVATION, GARRISON_MEN, GROUND_ODDS, ODDS_WORDS, SIEGE_HUNGER, START_YEAR, TERRAIN
from .state import Battle
from .systems import battle as battlesys, combat, terrain as terrainsys, war as warsys
from ..hexgrid import distance, neighbors

ROUND_MEN = 100              # a seen (not exact) number of men is rounded to this
RELIEF_STACKS = 4            # the relief search of siege_view looks at the defender's four nearest stacks (cheap redraws)
ROUND_MORALE = 0.05          # and a morale to this share
LANES = ("left", "centre", "right")
_VIEWS = weakref.WeakKeyDictionary()    # world -> (world.version, {key: (object, view)}); never saved


def _memo(world, key, obj, make):
    """The view for ``key``, made by ``make`` once per world.version. ``obj`` (the battle, or None) must be the same object
    for a hit, so a view never outlives the object it was made from."""
    entry = _VIEWS.get(world)
    if entry is None or entry[0] != world.version:
        entry = (world.version, {})
        _VIEWS[world] = entry
    table = entry[1]
    hit = table.get(key)
    if hit is None or hit[0] is not obj:
        hit = (obj, make())
        table[key] = hit
    return hit[1]


def besieged(world):
    """The hexes a siege runs on, in province order (cached per world.version, so a frame or a task-flag rebuild does not
    scan every province: the siege badges and the task flag read this). A siege starts, lifts or ends with world.changed()."""
    return _memo(world, ("besieged",), None, lambda: tuple(pos for pos, prov in world.provinces.items() if prov.besieger))


def _access(world, pos, tags, viewer):
    """"exact", "seen" or "hidden": what the viewer may know about the stacks of ``tags`` on ``pos`` (the fog rule above)."""
    if viewer is None or viewer in tags:
        return "exact"
    if world.player is None or (viewer == world.player and pos in world.visible):
        return "seen"
    return "hidden"


def _men_out(value, access):
    """A number of men as the view gives it: exact, or rounded to ROUND_MEN when the viewer only sees the hex."""
    if access == "exact":
        return int(round(value))
    return int(round(value / ROUND_MEN) * ROUND_MEN)


def _morale_out(value, access):
    """A morale (0 to 1) as the view gives it: exact, or rounded to ROUND_MORALE."""
    if access == "exact":
        return round(value, 3)
    return round(round(value / ROUND_MORALE) * ROUND_MORALE, 2)


def _year(turn):
    """The year of a season (the rule of CampaignWorld.year)."""
    return START_YEAR + (turn - 1) // 4


def _war(world, battle, tag):
    """A side's live war units on the battle's hex, by id (routed ones included: they are still there)."""
    return sorted((u for u in world.units_at(battle.pos) if u.kind.war and u.owner == tag and u.hp > 0),
                  key=lambda u: u.id)


def _unit_men(battle, unit):
    """The men a regiment has now: its hp less the damage it has not yet taken (battle.carry), in men (the panel's men -
    carry, so the numbers move smoothly)."""
    return combat.men_per_hp(unit) * max(0.0, unit.hp - battle.carry.get(unit.id, 0.0))


def _garrison_men(world, battle):
    """The men of the castle's garrison now (the same carry rule as a regiment's)."""
    prov = world.provinces[battle.pos]
    return GARRISON_MEN * max(0.0, prov.garrison - battle.carry.get("garrison", 0.0))


def _side_men(world, battle, tag):
    """A side's men now on the hex: its war units and, for the defender in an assault, the garrison."""
    men = sum(_unit_men(battle, u) for u in _war(world, battle, tag))
    if tag == battle.defender and battle.assault and world.provinces[battle.pos].garrison > 0:
        men += _garrison_men(world, battle)
    return men


def _names(world, tags):
    return {tag: (world.countries[tag].name if tag in world.countries else tag) for tag in tags}


def _battle_name(world, battle):
    """The battle's name; a battle made before names were kept gets its place."""
    if battle.name:
        return battle.name
    prov = world.provinces.get(battle.pos)
    return f"Battle at {world.place(prov)}" if prov is not None else "Battle"


def _regiment(battle, unit, access):
    return {"id": unit.id, "kind": unit.kind.name, "branch": unit.kind.branch, "rank": unit.rank[1],
            "men": _men_out(_unit_men(battle, unit), access), "morale": _morale_out(unit.morale, access)}


def _shaken(battle):
    """The ids of the regiments that moved up into a lane on the battle's last day (the day record's ``shaken``; empty
    before the first day and in a battle saved before the record had it)."""
    for rec in reversed(battle.log):
        if isinstance(rec, dict) and rec.get("kind") == "day":
            return frozenset(rec.get("shaken") or ())
    return frozenset()


def _lane(world, battle, tag, lane, key, by_id, access, shaken):
    """One lane of a side: the regiment in it (or the garrison), empty when nothing holds the lane."""
    prov = world.provinces[battle.pos]
    out = {"lane": LANES[lane], "open": combat.lane_open(prov, lane), "broken": lane in battle.broken.get(tag, ()),
           "id": None, "kind": None, "rank": None, "men": None, "morale": None, "shaken": None}
    if key == "garrison":
        out.update(id="garrison", kind="Garrison", men=_men_out(_garrison_men(world, battle), access),
                   morale=_morale_out(battle.garrison_morale, access))
    elif key is not None and key in by_id:
        unit = by_id[key]
        out.update(id=unit.id, kind=unit.kind.name, rank=unit.rank[1], men=_men_out(_unit_men(battle, unit), access),
                   morale=_morale_out(unit.morale, access), shaken=unit.id in shaken)
    return out


def _orders(world, battle, tag):
    """The three stances a side may take now, each with the battle's own check and its reason."""
    out = {}
    for stance in battlesys.STANCES:
        ok, reason = battlesys.battle_order_check(world, battle.pos, tag, stance)
        out[stance] = {"ok": ok, "reason": reason}
    return out


def _side(world, battle, tag, viewer, access):
    """One side of the battle (see the module docstring for the keys)."""
    units = _war(world, battle, tag)
    by_id = {u.id: u for u in units}
    lanes_of = battle.lanes.get(tag, [None, None, None])
    in_lanes = {key for key in lanes_of if key is not None}
    shaken = _shaken(battle)
    lanes = tuple(_lane(world, battle, tag, lane, lanes_of[lane], by_id, access, shaken) for lane in range(3))
    rest = [u for u in units if u.id not in in_lanes and u.id not in battle.routed]
    reserve = tuple(_regiment(battle, u, access) for u in rest if u.kind.branch != "artillery")
    back_line = tuple(_regiment(battle, u, access) for u in rest if u.kind.branch == "artillery")
    routed = tuple(_regiment(battle, u, access) for u in units if u.id in battle.routed)
    general = combat.general(world, [u for u in world.units_at(battle.pos) if u.owner == tag])
    exact = access == "exact"
    can = viewer == tag and world.player in (None, tag)
    return {
        "access": access,
        "men": _men_out(_side_men(world, battle, tag), access),
        "start": _men_out(battle.men0.get(tag, 0), access),
        "killed": _men_out(battle.killed.get(tag, 0.0), access),
        "wounded": _men_out(battle.wounded.get(tag, 0.0), access),
        "front_morale": _morale_out(combat.army_morale(world, battle, tag), access),
        "strength": _men_out(combat.battle_strength(world, battle, tag), access),
        "lanes": lanes,
        "reserve": reserve,
        "back_line": back_line,
        "routed": routed,
        "general": (general.trait or None) if general is not None else None,
        "stance": battle.stance.get(tag) if exact else None,
        "standing": (units[0].standing if units else None) if exact else None,
        "can_order": can,
        "orders": _orders(world, battle, tag) if can else None,
    }


def _rounded(entry):
    """A log record with its numbers rounded, for a viewer who only sees the hex."""
    rec = dict(entry)
    for field in ("killed", "wounded"):
        if isinstance(rec.get(field), dict):
            rec[field] = {tag: _men_out(value, "seen") for tag, value in rec[field].items()}
    if "men" in rec:
        rec["men"] = _men_out(rec["men"], "seen")
    return rec


def _log(battle, names, access):
    """The battle's log through battlelog.describe. Old saves kept the text itself: those lines are shown only to the
    exact view, since their numbers cannot be rounded."""
    out = []
    for entry in battle.log:
        if isinstance(entry, dict):
            rec = entry if access == "exact" else _rounded(entry)
            out.append({"turn": rec.get("turn"), "day": rec.get("day"), "kind": rec.get("kind"),
                        "text": describe(rec, names)})
        elif access == "exact":
            out.append({"turn": entry[0], "day": entry[1], "kind": "text", "text": describe(entry, names)})
    return tuple(out)


def _dice(battle):
    """The last day's rolls and the damage multipliers they gave (data.DICE), or None before the first day."""
    for rec in reversed(battle.log):
        if isinstance(rec, dict) and rec.get("kind") == "day":
            rolls = dict(rec.get("rolls") or {})
            return {"day": rec.get("day"), "rolls": rolls,
                    "mult": {tag: DICE.get(roll, 1.0) for tag, roll in rolls.items()}}
    return None


def _hidden(viewer):
    """The view of a battle the viewer cannot see: every key is there, nothing about the stacks."""
    return {"access": "hidden", "exact": False, "viewer": viewer, "viewer_role": None, "pos": None, "name": None,
            "year": None, "start": None, "seasons": None, "days": None, "assault": None,
            "crossing": None, "uphill": None, "ground": None, "sides": {"attacker": [], "defender": []}, "side": {},
            "dice": None, "log": (), "can_order": False}


def _battle(world, battle, viewer, access):
    if access == "hidden":
        return _hidden(viewer)
    att, dfn = battle.attacker, battle.defender
    names = _names(world, (att, dfn))
    prov = world.provinces[battle.pos]
    role = "attacker" if viewer == att else ("defender" if viewer == dfn else None)
    terrain = TERRAIN.get(prov.terrain)
    return {
        "access": access, "exact": access == "exact", "viewer": viewer, "viewer_role": role,
        "pos": battle.pos, "name": _battle_name(world, battle), "year": _year(battle.start),
        "start": battle.start, "seasons": world.turn - battle.start + 1, "days": battle.days,
        "assault": battle.assault,
        "crossing": battle.crossing, "uphill": battle.uphill,
        "ground": {"terrain": terrain.name if terrain is not None else prov.terrain,
                   "lanes": sum(1 for lane in range(3) if combat.lane_open(prov, lane)),
                   "castle": prov.castle if battle.assault else 0},
        "sides": {"attacker": [att], "defender": [dfn]},
        "side": {tag: _side(world, battle, tag, viewer, access) for tag in (att, dfn)},
        "dice": _dice(battle),
        "log": _log(battle, names, access),
        "can_order": role is not None and world.player in (None, viewer),
    }


def battle_view(world, battle_or_pos, viewer=None):
    """The read model of one battle (the module docstring). ``battle_or_pos``: a state.Battle, or the hex of one. None
    when no battle is on that hex, or the battle has ended (it is no longer in world.battles: its stacks have moved on,
    so it has no live numbers; the log lines of an ended battle come from its battle_ended event). ``viewer``: the
    country tag looking, or None for the whole picture."""
    battle = battle_or_pos if isinstance(battle_or_pos, Battle) else world.battle_at(tuple(battle_or_pos))
    if battle is None or battle not in world.battles:
        return None
    access = _access(world, battle.pos, (battle.attacker, battle.defender), viewer)
    key = ("battle", battle.pos, viewer, access, world.turn)
    return _memo(world, key, battle, lambda: _battle(world, battle, viewer, access))


# ----- the odds card's inputs -----------------------------------------------------------------------------------

def odds_word(ratio):
    """The odds card's one word for a strength ratio: the highest band (data.ODDS_WORDS) the ratio reaches. "Unknown"
    when there is no ratio (no defenders). Pygame-free, and the same for every viewer."""
    if ratio is None:
        return "Unknown"
    word = ODDS_WORDS[0][0]
    for name, low, _ in ODDS_WORDS:
        if ratio >= low:
            word = name
    return word


def odds_factor(terrain, castle, assault):
    """The factor the odds card divides the attack ratio by for the defender's hex: 1.0 in an assault (the garrison fights
    and the ground does not count; the garrison's own weight is in the men, see war.storm_defence), else the ground's
    (GROUND_ODDS). 1.0 for plains and for a ground not measured. ``castle`` is kept for the callers' shape."""
    if assault:
        return 1.0
    return GROUND_ODDS.get(terrain, 1.0)


def _country_name(world, tag):
    return world.countries[tag].name if tag in world.countries else tag


def _crosses_pass(world, a, b):
    """Whether the step from a to b goes through a mountain pass (the rule of systems/battle.py engage)."""
    edge = frozenset((a, b))
    return any(e == edge for _, _, e, _ in terrainsys.pass_edges(world))


def _general(world, pos, tag, access):
    """The trait of ``tag``'s general on ``pos`` (its trait key, None for none or when the view does not show it)."""
    if tag is None or access == "hidden":
        return None
    general = combat.general(world, [u for u in world.units_at(pos) if u.owner == tag])
    return (general.trait or None) if general is not None else None

def _enemy(world, owner, pos, battle):
    """The side a stack attacking ``pos`` meets: the other side of the battle there, else the enemy with war units on the
    hex, else the controller of a castle with a garrison (the rule of battle._defender). None when there is none."""
    if owner is None:
        return None
    if battle is not None:
        if owner == battle.attacker:
            return battle.defender
        return battle.attacker if owner == battle.defender else None
    enemies = sorted({u.owner for u in world.units_at(pos) if u.owner != owner and u.kind.war})
    if enemies:
        return enemies[0]
    prov = world.provinces.get(pos)
    if prov is not None and prov.castle and prov.garrison > 0 and prov.controller not in (None, owner):
        return prov.controller
    return None


def _attack_raw(world, group, battle, owner):
    """The attacking side's men and strength: the group's regiments, joined to the side already in the battle."""
    men, strength = combat.group_strength(world, group)
    if battle is not None and owner in (battle.attacker, battle.defender):
        joiners = [u for u in group if u.kind.war and u.hp > 0 and u.id not in battle.members]
        joined_men, joined_strength = combat.group_strength(world, joiners)
        men = _side_men(world, battle, owner) + joined_men
        strength = combat.battle_strength(world, battle, owner) + joined_strength
    return men, strength


def _defence_raw(world, pos, battle, enemy):
    """The defending side's men and strength on the target hex (the battle's, or the hex's before one)."""
    if battle is not None:
        return _side_men(world, battle, enemy), combat.battle_strength(world, battle, enemy)
    prov = world.provinces[pos]
    garrison = prov.castle and prov.garrison > 0 and prov.controller == enemy       # full morale before the battle
    return combat.group_strength(world, [u for u in world.units_at(pos) if u.owner == enemy],
                                 pos if garrison else None)


def _figures(raw, access):
    """A side's numbers as the viewer may have them: None when hidden, rounded when seen."""
    if raw is None or access == "hidden":
        return {"access": "hidden", "men": None, "morale": None, "strength": None}
    men, strength = raw
    morale = strength / men if men > 0 else 0.0
    return {"access": access, "men": _men_out(men, access), "morale": _morale_out(morale, access),
            "strength": _men_out(strength, access)}


def _besiege(world, group, target_pos, owner, stand, defence_access):
    """The Besiege entry of the odds card (0.2.2, design 4.6): None when the place is not a garrisoned castle with no field
    army on it. Else: ``ok`` and ``reason`` (the men rule included), ``seasons`` (falls in about N seasons, the arrival
    season counted; None when the stack is too small), ``need``, ``rate``, ``stores`` (the garrison's seasons of stores),
    ``war_left`` (the seasons the war has left, the arrival season counted, None when there is no war) and
    ``war_ends_first`` (the place would fall after the war ends), and ``opens`` (the provinces its fall opens to the
    taker: the castle's area land its owner still holds, castle areas 2.3)."""
    prov = world.provinces.get(target_pos)
    if not group or prov is None or not prov.castle or prov.garrison <= 0:
        return None
    if not warsys.besiege_target(world, group, target_pos):
        return None
    ok, reason = warsys.besiege_check(world, group, target_pos, stand=stand)
    units = list(group) + [u for u in world.units_at(target_pos) if u.owner == owner and u not in group]
    held = prov.besieger == owner
    progress, turns = (prov.siege, prov.siege_turns) if held else (0, 0)
    terms = warsys.siege_terms(world, prov, owner, units)
    if not ok and not terms["ok"] and reason.startswith("Too few men"):      # the garrison's men as the viewer has them
        reason = (f"Too few men to hold a siege (need {_men_out(terms['garrison_men'], defence_access):,}, "
                  f"you have {terms['men']:,})")
    seasons = warsys.siege_forecast(world, prov, owner, units, progress, turns)
    war = next((w for w in world.wars if {w.a, w.b} == {owner, prov.controller}), None)
    left = None if war is None else warsys.war_limit(world, war.a, war.b) - (world.turn - war.start) + 1
    return {"ok": ok, "reason": reason, "seasons": seasons, "need": terms["need"], "rate": terms["rate"],
            "stores": terms["stores"], "war_left": left, "opens": world.area_opens(target_pos),
            "war_ends_first": bool(seasons is not None and left is not None and seasons > left)}


def _odds(world, group, target_pos, viewer, owner, stand):
    battle = world.battle_at(target_pos)
    if group:
        ok, reason = battlesys.engage_check(world, group, target_pos)
    else:
        ok, reason = False, "No units to attack with"
    enemy = _enemy(world, owner, target_pos, battle)
    attack_access = _access(world, stand, (owner,), viewer) if owner is not None else "hidden"
    defence_access = _access(world, target_pos, (enemy,), viewer) if enemy is not None else "hidden"
    prov = world.provinces.get(target_pos)
    raw_attack = _attack_raw(world, group, battle, owner) if group else None
    raw_defence = _defence_raw(world, target_pos, battle, enemy) if enemy is not None else None
    assault = battle.assault if battle is not None else bool(
        enemy is not None and prov is not None and prov.controller == enemy and prov.castle and prov.garrison > 0)
    garrison = None
    if battle is None and assault and enemy is not None:
        defence_men, garrison = warsys.storm_defence(world, target_pos, enemy, owner)   # a storm: men against men (0.2.2)
        raw_defence = (defence_men, defence_men)
        if defence_access == "hidden":
            garrison = None                                              # the garrison is the defender's secret
        if raw_attack is not None:
            raw_attack = (raw_attack[0], raw_attack[0])
    attack = _figures(raw_attack, attack_access)
    defence = _figures(raw_defence, defence_access)
    if garrison is not None and defence_access != "hidden":       # men as they are; the weight is in the strength
        field = sum(u.men for u in world.units_at(target_pos) if u.owner == enemy and u.kind.war)
        defence["men"] = _men_out(field + garrison["men"], defence_access)
    defence["terrain"] = TERRAIN[prov.terrain].name if prov is not None and prov.terrain in TERRAIN else None
    defence["castle"] = prov.castle if prov is not None and enemy is not None and prov.controller == enemy else 0
    defence["assault"] = assault
    defence["garrison"] = garrison
    attack["general"] = _general(world, stand, owner, attack_access)
    defence["general"] = _general(world, target_pos, enemy, defence_access)
    ratio, raw = None, None
    if attack["strength"] is not None and defence["strength"]:
        raw = attack["strength"] / defence["strength"]
        ratio = round(raw, 2)
    factor = odds_factor(prov.terrain if prov is not None else None, defence["castle"], defence["assault"])
    if battle is not None:
        crossing, uphill = battle.crossing, battle.uphill
    elif stand != target_pos:
        crossing = _crosses_pass(world, stand, target_pos)
        uphill = ELEVATION.get(world.provinces[stand].terrain, 0) < ELEVATION.get(world.provinces[target_pos].terrain, 0)
    else:
        crossing = uphill = False
    word = "Unknown" if enemy is None or defence_access == "hidden" else odds_word(None if raw is None else raw / factor)
    return {"target": target_pos, "attacker": owner, "defender": enemy, "battle": battle is not None,
            "name": _battle_name(world, battle) if battle is not None else None,
            "place": world.place(prov) if prov is not None else None,
            "attacker_name": _country_name(world, owner) if owner is not None else None,
            "defender_name": _country_name(world, enemy) if enemy is not None and defence_access != "hidden" else None,
            "ok": ok, "reason": reason, "attack": attack, "defence": defence, "ratio": ratio, "factor": factor,
            "word": word,
            "besiege": None if battle is not None or defence_access == "hidden"
            else _besiege(world, group, target_pos, owner, stand, defence_access),
            "crossing": bool(crossing), "uphill": bool(uphill)}


def odds_view(world, group, target_pos, viewer=None):
    """The inputs of the odds card for the stack ``group`` attacking ``target_pos`` (the module docstring), cached on
    world.version. ``viewer``: the country looking (None for the whole picture)."""
    group = [u for u in group if u in world.units]
    owner = group[0].owner if group else None
    stand = group[0].pos if group else target_pos
    key = ("odds", tuple(u.id for u in group), target_pos, stand, viewer, world.turn)
    return _memo(world, key, None, lambda: _odds(world, group, target_pos, viewer, owner, stand))


# ----- the siege read model (0.2.2, design 4.7) ----------------------------------------------------------------------

SIEGE_KEYS = ("access", "pos", "name", "besieger", "besieger_name", "defender", "defender_name", "place", "progress",
              "need", "rate", "hunger", "seasons", "stores_left", "starving", "falls_in", "relief")


def siege_view(world, pos, viewer=None, relief=True):
    """The one read-only view of a running siege (the badge, the province panel, the log and the task flag read it): the
    meter (``progress`` of ``need``), ``rate`` a season, ``hunger`` the points the next season adds past the stores, ``seasons``
    held, ``stores_left`` (seasons of food the garrison has, 0 when it starves), ``starving``, ``falls_in`` (seasons, from
    now, the place falls at this rate; None when the besieger is too small), and ``relief``: for the defender (or the whole
    picture), its armies that can reach the hex, each {pos, men, seasons} nearest first. None when no siege runs there.
    The fog rule of the battle view (_access): exact to a side or to no player; seen keeps the meter exact and rounds the
    men (the garrison's); hidden gives None for the names, the place and every number. ``relief=False`` skips the relief
    search (the badge and the task flag need only falls_in): ``relief`` is then ()."""
    prov = world.provinces.get(tuple(pos))
    if prov is None or not prov.besieger:
        return None
    access = _access(world, prov.pos, (prov.besieger, prov.controller), viewer)
    key = ("siege", prov.pos, viewer, access, world.turn, relief)
    return _memo(world, key, prov, lambda: _siege(world, prov, viewer, access, relief))


def _siege(world, prov, viewer, access, relief=True):
    tag, defender = prov.besieger, prov.controller
    hidden = access == "hidden"
    base = {"access": access, "pos": prov.pos, "name": None if hidden else prov.siege_name,
            "besieger": None if hidden else tag, "besieger_name": None if hidden else _country_name(world, tag),
            "defender": None if hidden else defender,
            "defender_name": None if hidden else _country_name(world, defender),
            "place": None if hidden else world.place(prov), "progress": None,
            "need": None, "rate": None, "hunger": None, "seasons": None, "stores_left": None, "starving": None,
            "falls_in": None, "relief": ()}
    if hidden:
        return base
    units = [u for u in world.units_at(prov.pos) if u.owner == tag]
    terms = warsys.siege_terms(world, prov, tag, units)
    stores = terms["stores"]
    base.update(progress=prov.siege, need=terms["need"], rate=terms["rate"],
                hunger=SIEGE_HUNGER if prov.siege_turns >= stores else 0, seasons=prov.siege_turns,
                stores_left=max(0, stores - prov.siege_turns), starving=prov.siege_turns >= stores,
                falls_in=warsys.siege_forecast(world, prov, tag, units, prov.siege, prov.siege_turns))
    if relief and (viewer is None or viewer == defender):
        base["relief"] = _relief(world, prov, defender)
    return base


def _relief(world, prov, defender):
    """The defender's armies that can reach the besieged hex: each {pos, men, seasons} with seasons the first season in which
    it can stand beside the hex (1 is this season's moves), nearest first, at most four seasons away. Only the
    RELIEF_STACKS nearest stacks (by hex distance) are looked at."""
    stands = [p for p in neighbors(prov.pos) if p in world.provinces and world.is_land(p)]
    stacks = {}
    for unit in world.units:
        if unit.owner == defender and unit.kind.war and unit.carrier is None and unit.pos != prov.pos:
            stacks.setdefault(unit.pos, []).append(unit)
    nearest = sorted(stacks.items(), key=lambda item: (distance(item[0], prov.pos), item[0]))[:RELIEF_STACKS]
    found = []
    for pos, group in sorted(nearest):
        men = sum(u.men for u in group)
        for seasons in range(1, 5):
            if any(world.path_to(group, stand, seasons=seasons) for stand in stands):
                found.append({"pos": pos, "men": men, "seasons": seasons})
                break
    return tuple(sorted(found, key=lambda r: (r["seasons"], -r["men"], r["pos"]))[:3])
