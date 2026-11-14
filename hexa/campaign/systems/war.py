"""War: declaring and ending wars, peace offers, attacks, battles and sieges.

Functions taking ``world``; ``CampaignWorld`` binds them as plain class attributes (``at_war = war.at_war``), so the hot
ones (``at_war``, ``enemies``, called from every supply and path search) cost no extra call. The battle system builds on
this module: ``attack_options_group`` says where a stack may strike (the checks are battle.engage_check's), ``attack_group``
walks to the hex it attacks from and calls ``engage`` (battle.py: a battle, a join or an overrun), ``sieges`` is the
season's step that gives a province to the army standing in it (never on a battle hex), ``peace`` ends a war (its battles
end first) and moves the provinces, ``lose`` takes units off the map with a ``unit_lost`` event each and ``kill`` is ``lose``
for one unit and what it carries; ``lose`` also tells the battles (battle.units_left) so a battle never keeps a unit that
has left the map. The bus events (``war_declared``, ``peace_made``, ``province_captured``,
``siege_progress``, ``unit_lost``) are emitted here; the battle events come from battle.py. Imports point down: never
world.py, ui, render or pygame.
"""
import math

from ...hexgrid import neighbors, within
from ..data import (CASTLE_SIEGE, CROWD_BANDS, ELEVATION, GARRISON_HP, GARRISON_MEN, GARRISON_ODDS, GARRISON_ODDS_ALONE,
                    GARRISON_REGEN, MILITIA_MEN,
                    SIEGE_BASE_NEED, SIEGE_HUNGER, SIEGE_MIN_SEASONS, SIEGE_RATE_MAX, SIEGE_STORM_CUT, START_YEAR,
                    WAR_LENGTH_AI)
from . import battle as battlesys, combat, movement
from ..state import War

# What this module changes on the world: the wars, the provinces (owner, controller, siege, garrison), the units (hit
# points, experience, positions; the dead are removed), the countries (alive, capital), the log, and what changed()
# and refresh_markets() mark when a province changes hands.
OWNS = ("wars", "provinces", "units", "countries", "log", "version", "_owned", "_castle_list", "_markets_dirty",
        "siege_names")
SIEGE_FORECAST_MAX = 60         # seasons the forecast counts before it gives up (a place falls well before this)

# The combat values (general, attack_value, defense_value) live in combat.py. The names stay here, so the old
# import paths (war.general and the world's facades) keep working.
general = combat.general
attack_value = combat.attack_value
defense_value = combat.defense_value


def at_war(world, a, b):
    return any({w.a, w.b} == {a, b} for w in world.wars)


def enemies(world, tag):
    return {w.b if w.a == tag else w.a for w in world.wars if tag in (w.a, w.b)}


def war_check(world, a, b):
    if a == b or not world.countries[b].alive:
        return False, "Not possible"
    if world.at_war(a, b):
        return False, "Already at war"
    if b not in world.neighbours_of(a):
        return False, "Only neighbours can go to war"
    return True, ""


def declare_war(world, a, b):
    if not world.war_check(a, b)[0]:
        return False
    world.wars.append(War(a, b, world.turn))
    world.bus.emit("war_declared", a, target=b)
    world.message(f"{world.countries[a].name} declared war on {world.countries[b].name}!",
                 None if world.player in (a, b) else "nobody")
    if world.player in (a, b):
        world.message(f"War: {world.countries[a].name} against {world.countries[b].name}.")
    return True


def war_score(world, tag, enemy):
    taken = sum(1 for p in world.provinces_of(enemy) if p.controller == tag)
    lost = sum(1 for p in world.provinces_of(tag) if p.controller == enemy)
    capital = world.provinces[world.countries[enemy].capital].controller == tag
    return taken - lost + (3 if capital else 0)


def _shared_hexes(world, a, b):
    """The hexes where a unit of a and a unit of b stand together (carried units aside)."""
    here = {}
    for unit in world.units:
        if unit.carrier is None and not unit.naval and unit.owner in (a, b):
            here.setdefault(unit.pos, set()).add(unit.owner)
    return {pos for pos, tags in here.items() if len(tags) == 2}


def peace(world, a, b, winner=None):
    """End the war. Each side keeps what it occupies if `winner` is None; otherwise only the winner gains. The battles
    of the two end first (no pursuit, no retreat: battle.end_battles). Then the stacks in the other's land go home, and
    so do the stacks that still stand together on a third country's hex (the larger tag of the two goes)."""
    world.wars = [w for w in world.wars if {w.a, w.b} != {a, b}]
    world.end_battles(a, b)
    moved = 0
    changed_hands = set()
    for prov in list(world.provinces_of(a)) + list(world.provinces_of(b)):
        if prov.controller != prov.owner and prov.controller in (a, b):
            changed_hands.add(prov.pos)
            gainer = prov.controller
            if winner is None or gainer == winner:
                if world.countries[prov.owner].capital == prov.pos:
                    prov.controller = prov.owner      # capitals return
                    continue
                world.bus.emit("province_captured", gainer, prov.pos, loser=prov.owner, by="peace")
                prov.owner = gainer
                moved += 1
            prov.controller = prov.owner
            prov.siege = 0
    for prov in world.provinces.values():
        # peace ends the sieges between the two parties, its progress lost (0.2.2 defaults); a third country's siege of
        # one of their places goes on. A place this peace handed back has no siege left to report: no lift event.
        if prov.besieger and not world.at_war(prov.besieger, prov.controller):
            if prov.pos in changed_hands or prov.controller == prov.besieger:
                _forget_siege(world, prov)
            else:
                _lift(world, prov, "peace")
    shared = _shared_hexes(world, a, b)
    for unit in list(world.units):
        if unit.carrier is None and not unit.naval and unit.owner in (a, b):
            prov = world.provinces.get(unit.pos)
            foreign = bool(prov and prov.owner in (a, b) and prov.owner != unit.owner)
            third = unit.pos in shared and (prov is None or prov.owner not in (a, b))
            if foreign or (third and unit.owner == max(a, b)):
                home = world.countries[unit.owner].capital
                spot = world.free_spot_near(unit, home)
                if spot:
                    unit.pos = spot
                else:
                    world.lose([unit], "evicted")
    world.changed(ownership=True)
    world.refresh_markets()
    world.bus.emit("peace_made", a, b=b, winner=winner, moved=moved)
    names = f"{world.countries[a].name} and {world.countries[b].name}"
    world.message(f"Peace between {names}" + (f": {moved} provinces changed hands." if moved else "."),
                 None if world.player in (a, b) else "nobody")
    world.check_alive()


def free_spot_near(world, unit, pos):
    for r in range(8):
        for p in sorted(within(pos, r)):
            prov = world.provinces.get(p)
            if prov and prov.owner == unit.owner and world.can_stand([unit], p):
                return p
    return None


def peace_offer(world, tag, enemy, terms):
    """The player proposes peace. terms: 'take' (keep what you occupy), 'white' or 'yield'."""
    if not world.at_war(tag, enemy):
        return False, "Not at war"
    war = next(w for w in world.wars if {w.a, w.b} == {tag, enemy})
    score = world.war_score(tag, enemy)
    length = world.turn - war.start
    if terms == "yield":
        world.peace(tag, enemy, winner=enemy)
        return True, "They accept your surrender."
    if terms == "white":
        if score >= -1 and length >= 4:
            world.peace(tag, enemy, winner="nobody")
            return True, "White peace signed."
        return False, "They refuse: they are winning, or the war has only just started"
    if score >= 3 or (score >= 1 and world.army_strength(enemy) <= world.army_strength(tag)):
        world.peace(tag, enemy, winner=tag)
        return True, "They accept and give up the provinces you occupy."
    return False, "They refuse: occupy more of their land or beat their army first"


def attack_options(world, unit):
    return world.attack_options_group([unit])


def attack(world, unit, target_pos):
    return world.attack_group([unit], target_pos)


def targets(world, tag):
    """The hexes a country's stacks may strike at: the enemy's stacks and garrisoned castles, never a hex the country
    already stands on. A battle the country is a side of is a target too: a stack beside it joins (spec 3.1)."""
    enemies = world.enemies(tag)
    if not enemies:
        return set()
    found = {u.pos for u in world.units if u.carrier is None and not u.naval and u.owner in enemies}
    for prov in world.castles():
        if prov.controller in enemies and prov.garrison > 0:
            found.add(prov.pos)
    ours = world.owners_at()
    joins = {b.pos for b in world.battles if tag in (b.attacker, b.defender)}
    return {pos for pos in found if tag not in ours.get(pos, ())} | joins


def attack_options_group(world, group):
    """{target hex: the hex to attack from}. A target is an enemy's hex or a battle the stack's country is a side of (the
    stack joins it). An option is offered only when the attack would be allowed from that hex: battle.engage_check says
    so for each stand, the cheapest first. There is no bombardment: guns fight from the same hex (spec 3.7)."""
    fighters = [u for u in group if u.kind.war and u.moves_left > 0 and not u.attacked]
    if not fighters or any(u.carrier for u in group):
        return {}
    lead = group[0]
    targets = world.targets(lead.owner)
    if not targets:
        return {}
    moves = min(u.moves_left for u in group)
    reach = world.reachable_group(group)
    stands = {p: c for p, c in reach.items() if c < moves and not any(u.naval for u in world.units_at(p))}
    options = {}
    for pos in sorted(targets):
        if pos == lead.pos:
            continue
        siege = world.besiege_target(group, pos)
        for stand in sorted((p for p in neighbors(pos) if p in stands), key=lambda p: (stands[p], p)):
            if not world.engage_check(group, pos, stand=stand)[0]:
                continue
            # a garrisoned castle is offered only as a siege Besiege allows (attack_group would refuse the rest); Storm
            # stays open through storm_check and storm_group
            if siege and not world.besiege_check(group, pos, stand=stand)[0]:
                continue
            options[pos] = stand
            break
    return options


def attack_group(world, group, target):
    """The stack walks to the hex it attacks from (one unit_moved), then calls engage, which makes the one step onto the
    target and starts the battle, joins it or overruns the civilians there. A move onto a garrisoned castle is a siege
    instead (0.2.2, the default: besiege, no battle; the meter starts in the season's siege step); Storm is storm_group.
    Nothing moves when the attack is refused. Returns what it returned."""
    options = world.attack_options_group(group)
    if target not in options:
        return False
    stand = options[target]
    siege = world.besiege_target(group, target)
    if siege and not world.besiege_check(group, target, stand=stand)[0]:
        return False
    if stand != group[0].pos:
        world.move_group(group, stand)
    done = world.besiege(group, target) if siege else world.engage(group, target)
    if done:
        for unit in group:
            if unit in world.units:
                unit.moves_left, unit.attacked, unit.acted = 0, True, True
    world.changed()
    return done



def _storm_stand(world, group, target):
    """The hex beside target a stack storms from: the cheapest one storm_check allows (attack_options_group's order), or
    None. A stack already on the hex needs no stand (storm_group checks it itself)."""
    if not group or any(u.carrier for u in group) or not any(u.kind.war and u.moves_left > 0 and not u.attacked
                                                             for u in group):
        return None
    moves = min(u.moves_left for u in group)
    reach = world.reachable_group(group)
    stands = {p: c for p, c in reach.items() if c < moves and not any(u.naval for u in world.units_at(p))}
    for stand in sorted((p for p in neighbors(target) if p in stands), key=lambda p: (stands[p], p)):
        if world.storm_check(group, target, stand=stand)[0]:
            return stand
    return None


def lose(world, units, why):         # off the map, with a unit_lost event each (why: see hexa/events.py)
    units = list(units)
    for unit in units:
        world.units.remove(unit)
        world.bus.emit("unit_lost", unit.owner, unit.pos, what=unit.kind.name, why=why)
    battlesys.units_left(world, units)      # the battles they were in let go of them now (battle.units_left)


def kill(world, unit, why="battle"):
    world.lose(world.cargo(unit), "sunk")
    if unit in world.units:
        world.lose([unit], why)


def garrison_men(prov, hp=None):
    """The men a place's defence counts for the crowd (4.2): the militia of a place with no castle, else the castle's
    garrison in men (GARRISON_MEN a hit point). ``hp`` replaces the garrison's hit points (a storm's cut)."""
    if not prov.castle:
        return MILITIA_MEN
    return (prov.garrison if hp is None else hp) * GARRISON_MEN


def crowd(men, defenders):
    """The crowd rule (4.2): the besieger's men over the defenders' men. Under 1x too few to hold a siege (0); 1x to 2x
    1; 2x to 4x 2; 4x and more 3 (data.CROWD_BANDS)."""
    if men < defenders:
        return 0
    if defenders <= 0:
        return 3
    ratio = men / defenders
    for limit, value in CROWD_BANDS:
        if ratio < limit:
            return value
    return 3


def siege_need(world, prov, hp=None):
    """The points a place takes (4.2): SIEGE_BASE_NEED, the ground's elevation, and each castle level's CASTLE_SIEGE (plus
    the defender's siege_points tech) times the garrison's share of its full hit points, rounded up. ``hp`` replaces the
    garrison's hit points (a storm's cut)."""
    extra = 0
    if prov.castle:
        full = prov.castle * GARRISON_HP
        share = min(1.0, (prov.garrison if hp is None else hp) / full)
        extra = prov.castle * (CASTLE_SIEGE + world.bonus(prov.controller, "siege_points")) * share
    return math.ceil(SIEGE_BASE_NEED + ELEVATION.get(prov.terrain, 0) + extra)


def siege_terms(world, prov, tag, units, hp=None):
    """The besieger's numbers against a place (4.1 and 4.2), the same for the meter, the forecast and the odds card: its
    men, the defenders' men, the crowd, guns (the units' siege points, the artillery tech as today), the general, the
    rate (points a season, at most SIEGE_RATE_MAX; 0 when the crowd is too small), the need, and the garrison's stores in
    seasons (1 + castle level). ``ok`` is False when the stack is too small to hold the place."""
    wars = [u for u in units if u.kind.war]
    men = sum(u.men for u in wars)
    defenders = garrison_men(prov, hp)
    level = crowd(men, defenders)
    guns = sum(u.kind.siege + (world.bonus(tag, "siege") if u.kind.branch == "artillery" else 0) for u in wars)
    general = combat.general(world, units)
    assault = 1 if general is not None and general.trait == "assault" else 0
    rate = min(SIEGE_RATE_MAX, level + guns + assault) if level else 0
    return {"men": men, "garrison_men": defenders, "crowd": level, "guns": guns, "general": bool(assault), "rate": rate,
            "need": siege_need(world, prov, hp), "stores": 1 + prov.castle, "ok": level > 0}


def siege_forecast(world, prov, tag, units, progress=0, turns=0):
    """Seasons until a place falls at the rate the stack has now, counting the season it arrives in as the first (the odds
    card's "falls in about N seasons"). A running siege counts on from its meter (``progress``, ``turns`` seasons held).
    None when the stack is too small to hold it."""
    terms = siege_terms(world, prov, tag, units)
    if not terms["ok"]:
        return None
    points, count = progress, turns
    for _ in range(SIEGE_FORECAST_MAX):
        count += 1
        points += terms["rate"] + (SIEGE_HUNGER if count > terms["stores"] else 0)
        if count >= SIEGE_MIN_SEASONS and points >= terms["need"]:
            return count - turns
    return None


def siege_name(world, pos):
    """A siege's name (like a battle's): "Siege of Lisbon, 1532", "Second Siege of Lisbon, 1532" for each repeat on the
    same place. The count is kept in world.siege_names, so a repeat stays a repeat after a save."""
    base = battlesys.place_name(world, pos)
    count = world.siege_names.get(base, 0) + 1
    world.siege_names[base] = count
    ordinal = battlesys.ORDINALS[count - 1] if count <= len(battlesys.ORDINALS) else f"{count}th"
    title = "Siege" if count == 1 else f"{ordinal} Siege"
    return f"{title} of {base}, {START_YEAR + (world.turn - 1) // 4}"


def besieged(prov):
    """Whether a place is under siege: a besieger holds its meter (its output stops, the stack forages free)."""
    return bool(prov.besieger)


def war_limit(world, a, b):
    """The seasons a war between a and b may last: WAR_LENGTH_AI, twice as long when the player is in it (season.py)."""
    return WAR_LENGTH_AI * (2 if world.player in (a, b) else 1)


def storm_defence(world, pos, enemy, attacker=None):
    """The defence of a garrisoned castle in a storm (design 4.6), in men: the field men of ``enemy`` on the hex plus the
    garrison's men after the siege's cut (storm_garrison), weighted GARRISON_ODDS with a field army and by castle level
    alone otherwise (GARRISON_ODDS_ALONE). Returns (men, the garrison's numbers for the odds card)."""
    prov = world.provinces[pos]
    hp = storm_garrison(world, prov, attacker)
    field = sum(u.men for u in world.units_at(pos) if u.owner == enemy and u.kind.war)
    weight = GARRISON_ODDS if field else GARRISON_ODDS_ALONE[min(prov.castle, len(GARRISON_ODDS_ALONE)) - 1]
    men = garrison_men(prov, hp)
    return field + men * weight, {"hp": hp, "full": prov.castle * GARRISON_HP, "men": men, "weight": weight,
                                 "cut": hp < prov.garrison}


def storm_garrison(world, prov, attacker=None):
    """The garrison's hit points a storm faces (design 4.5): the garrison cut by the siege's progress,
    hp x (1 - SIEGE_STORM_CUT x progress / need), rounded up. No siege progress, no cut. ``attacker``: the storming
    country; only its own siege's progress cuts the garrison (None: whoever besieges)."""
    if not prov.besieger or prov.siege <= 0 or (attacker is not None and prov.besieger != attacker):
        return prov.garrison
    return math.ceil(prov.garrison * (1 - SIEGE_STORM_CUT * min(1.0, prov.siege / siege_need(world, prov))))


def _lift(world, prov, why):
    """The siege of a place is lifted: progress, hunger, seasons and name go to zero (a lifted siege starts from zero the
    next time, 0.2.2 defaults). ``why``: "left", "relief", "outnumbered" or "peace"."""
    tag, name, progress, turns = prov.besieger, prov.siege_name, prov.siege, prov.siege_turns
    need = siege_need(world, prov)
    prov.besieger, prov.siege, prov.siege_turns, prov.siege_name = "", 0, 0, ""
    world.bus.emit("siege_lifted", tag, prov.pos, why=why, name=name, progress=progress, need=need, seasons=turns)
    world.changed()


def _forget_siege(world, prov):
    """A siege that has nothing left to hold (its place was handed back by a peace): cleared, with no event."""
    prov.besieger, prov.siege, prov.siege_turns, prov.siege_name = "", 0, 0, ""
    world.changed()


def _fall(world, prov, tag):
    """The place falls to the besieger (province_captured, by "siege")."""
    name, turns, loser = prov.siege_name, prov.siege_turns, prov.controller
    world.bus.emit("province_captured", tag, prov.pos, loser=loser, by="siege", name=name, seasons=turns)
    prov.controller = tag
    prov.besieger, prov.siege, prov.siege_turns, prov.siege_name = "", 0, 0, ""
    prov.garrison = 0 if tag != prov.owner else prov.garrison
    world.message(f"{world.countries[tag].name} took control of {world.place(prov)}.",
                  None if world.player in (tag, prov.owner) else "nobody")
    world.changed()


def _siege_season(world, prov):
    """One season of a running siege (4.2): the besieger's stack must still stand on the place with men enough, and the
    meter gains its rate, plus SIEGE_HUNGER once the stores are out. A place falls at the end of a season in which the
    meter reaches the need and the siege has lasted SIEGE_MIN_SEASONS. A battle on the hex never reaches here."""
    tag = prov.besieger
    units = [u for u in world.units_at(prov.pos) if u.owner == tag]
    if prov.controller == tag:
        prov.besieger, prov.siege, prov.siege_turns, prov.siege_name = "", 0, 0, ""
        return
    if not any(u.kind.war for u in units) or not world.at_war(tag, prov.controller):
        relieved = any(u.owner == prov.controller and u.kind.war for u in world.units_at(prov.pos))
        _lift(world, prov, "relief" if relieved else "left")
        return
    terms = siege_terms(world, prov, tag, units)
    if not terms["ok"]:
        _lift(world, prov, "outnumbered")
        return
    prov.siege_turns += 1
    hunger = SIEGE_HUNGER if prov.siege_turns > terms["stores"] else 0
    prov.siege += terms["rate"] + hunger
    world.bus.emit("siege_progress", tag, prov.pos, progress=prov.siege, need=terms["need"], rate=terms["rate"],
                   hunger=hunger, seasons=prov.siege_turns, name=prov.siege_name)
    if prov.siege_turns >= SIEGE_MIN_SEASONS and prov.siege >= terms["need"]:
        _fall(world, prov, tag)


def _begin_siege(world, prov, tag):
    """A stack that stands on an enemy place with no battle starts its siege (the arrival season counts). Too few men
    start none: no meter, no hunger, and the place keeps its output."""
    units = [u for u in world.units_at(prov.pos) if u.owner == tag]
    if not siege_terms(world, prov, tag, units)["ok"]:
        return
    prov.besieger, prov.siege, prov.siege_turns = tag, 0, 0
    prov.siege_name = siege_name(world, prov.pos)
    terms = siege_terms(world, prov, tag, units)
    world.bus.emit("siege_started", tag, prov.pos, name=prov.siege_name, need=terms["need"], castle=prov.castle,
                   garrison=terms["garrison_men"], men=terms["men"])
    world.changed()
    _siege_season(world, prov)


def _regrow_or_rebel(world, prov):
    """A place with no army on it: a castle regrows its garrison (GARRISON_REGEN) while its owner holds it; a place held by
    an enemy with no army of its around is driven out after six seasons (the old rule, its counter in prov.siege)."""
    cap = prov.castle * GARRISON_HP
    if prov.castle and prov.controller == prov.owner and prov.garrison < cap:
        prov.garrison = min(cap, prov.garrison + GARRISON_REGEN)
    if prov.controller != prov.owner and not any(
            u.kind.war and u.owner == prov.controller and world.within_reach(u.pos, prov.pos)
            for u in world.units if u.carrier is None):
        prov.siege += 1
        if prov.siege >= 6:           # the people drive out a garrison nobody supports
            prov.controller, prov.siege = prov.owner, 0
            world.changed()
    elif prov.controller == prov.owner:
        prov.siege = 0


def sieges(world):
    """The season's siege step (0.2.2, design 4.1 to 4.2): a running siege advances (or is lifted); a stack alone on an
    enemy place with men enough starts one; a place with no army regrows its garrison or is driven out. A battle hex and
    a hex a side fled or withdrew onto this season make no progress (0.2.1)."""
    battle_hexes = {b.pos for b in world.battles}
    for prov in list(world.provinces.values()):
        if prov.owner is None or prov.pos in battle_hexes:
            continue            # a battle hex: no progress, no garrison regrowth, while the battle lasts (spec 3.2)
        if world.retreated.get(prov.pos) == world.turn:
            continue            # a side fled or withdrew onto this hex this season: it is running, not besieging (0.2.1 review)
        if prov.besieger:
            _siege_season(world, prov)
            continue
        here = [u for u in world.units_at(prov.pos) if u.kind.war]
        if not here:
            _regrow_or_rebel(world, prov)
            continue
        if len({u.owner for u in here}) > 1:
            continue            # two armies on one hex: the battle decides it, no siege progress either way
        tag = here[0].owner
        if tag == prov.controller:
            prov.siege = 0
            continue
        if world.at_war(tag, prov.controller):
            _begin_siege(world, prov, tag)


def besiege_target(world, group, pos):
    """Whether a stack's attack on pos is a siege, not a battle: a castle of an enemy with a garrison, no enemy war unit on
    the hex and no battle there (the move-in of design 4.5, the default)."""
    prov = world.provinces.get(pos)
    owner = group[0].owner if group else None
    if prov is None or not prov.castle or prov.garrison <= 0 or owner is None:
        return False
    if prov.controller in (None, owner) or not world.at_war(owner, prov.controller) or world.battle_at(pos) is not None:
        return False
    others = [u for u in world.units_at(pos) if u.owner != owner]
    if any(u.kind.war for u in others):
        return False
    return all(world.at_war(owner, u.owner) for u in others)     # civilians of an enemy are overrun, others refuse


def besiege_check(world, group, pos, stand=None):
    """(ok, reason) for a stack's move onto a garrisoned castle to besiege it (design 4.5, the default). The reasons are the
    attack's: engage_check, then the men (too few men hold no siege: the card says so)."""
    group = [u for u in group if u in world.units]
    if not group:
        return False, "No units to attack with"
    if not besiege_target(world, group, pos):
        return False, "Nothing to besiege here"
    ok, reason = battlesys.engage_check(world, group, pos, stand=stand)
    if not ok:
        return ok, reason
    prov = world.provinces[pos]
    owner = group[0].owner
    stack = list(group) + [u for u in world.units_at(pos) if u.owner == owner and u not in group]
    terms = siege_terms(world, prov, owner, stack)
    if not terms["ok"]:
        return False, (f"Too few men to hold a siege (need {terms['garrison_men']:,}, "
                       f"you have {terms['men']:,})")
    return True, ""


def besiege(world, group, pos):
    """The stack moves onto the garrisoned castle pos and besieges it: one step, no battle; the meter starts in the season's
    siege step. Returns True when the stack moved in."""
    ok, _ = besiege_check(world, group, pos)
    if not ok:
        return False
    group = [u for u in group if u in world.units]
    if group[0].pos != pos:
        movement.step_in(world, group, pos)
    if any(u.owner != group[0].owner for u in world.units_at(pos)):
        battlesys.overrun(world, group, pos)     # the enemy's wagons and generals on the castle hex are lost (no battle)
    world.changed()
    return True


def storm_check(world, group, pos, stand=None):
    """(ok, reason) for a storm of the garrisoned castle pos now: the assault battle of today, the garrison cut by the
    siege's progress (SIEGE_STORM_CUT). Any time during a siege (a place with no siege is stormed on arrival)."""
    group = [u for u in group if u in world.units]
    if not group:
        return False, "No units to attack with"
    prov = world.provinces.get(pos)
    owner = group[0].owner
    if prov is None or not prov.castle or prov.garrison <= 0 or prov.controller in (None, owner):
        return False, "Nothing to storm here"
    if not world.at_war(owner, prov.controller):
        return False, "Not at war"
    if any(u.kind.war and u.owner not in (owner, prov.controller) for u in world.units_at(pos)):
        return False, "Another army holds the hex"
    battle = world.battle_at(pos)
    if battle is not None and not battle.assault:
        return False, "A battle is fought here"
    return battlesys.engage_check(world, group, pos, stand=stand)


def storm(world, group, pos):
    """Storm the castle pos: the garrison is cut by the siege's progress first, then the assault battle starts (engage).
    Returns what engage returned (False, and nothing changes, when it refuses)."""
    ok, _ = storm_check(world, group, pos)
    if not ok:
        return False
    group = [u for u in group if u in world.units]
    owner, prov = group[0].owner, world.provinces[pos]
    joining = world.battle_at(pos) is not None      # an assault already on the hex: its garrison is already in the fight
    uncut = prov.garrison
    cut = uncut if joining else storm_garrison(world, prov, owner)
    prov.garrison = cut                      # the cut lasts for this storm's battle only (battle._end_battle restores it)
    done = world.engage(group, pos)
    battle = world.battle_at(pos)
    if done and not joining and battle is not None and battle.assault and battle.storm_from == 0 and cut < uncut:
        battle.storm_from, battle.storm_cut = uncut, cut
    else:                                    # no assault, or no cut to keep: the garrison is what it was
        prov.garrison = uncut
    if done:
        for unit in group:
            if unit in world.units:
                unit.moves_left, unit.attacked, unit.acted = 0, True, True
    world.changed()
    return done


def storm_group(world, group, target):
    """The stack walks to the hex it storms from (a running siege's stack is already there) and storms the castle."""
    if group and group[0].pos == target:
        stand = target
    else:
        stand = _storm_stand(world, group, target)
        if stand is None:
            return False
    if not storm_check(world, group, target, stand=stand)[0]:
        return False
    if stand != group[0].pos:
        world.move_group(group, stand)
    return storm(world, group, target)


def check_alive(world):
    for tag, country in world.countries.items():
        if country.alive and not world.provinces_of(tag):
            country.alive = False
            world.end_battles(tag)           # its battles end first, while its units still stand (spec 3.6)
            world.units = [u for u in world.units if u.owner != tag]
            world.wars = [w for w in world.wars if tag not in (w.a, w.b)]
            world.message(f"{country.name} has disappeared from the map.", None, "extinct")
        elif country.alive and world.provinces[country.capital].owner != tag:
            country.capital = max(world.provinces_of(tag), key=lambda p: p.pop).pos
