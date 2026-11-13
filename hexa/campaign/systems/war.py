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
from ...hexgrid import neighbors, within
from ..data import CASTLE_SIEGE, GARRISON_HP, GARRISON_REGEN, SIEGE_BASE
from . import battle as battlesys, combat
from ..state import War

# What this module changes on the world: the wars, the provinces (owner, controller, siege, garrison), the units (hit
# points, experience, positions; the dead are removed), the countries (alive, capital), the log, and what changed()
# and refresh_markets() mark when a province changes hands.
OWNS = ("wars", "provinces", "units", "countries", "log", "version", "_owned", "_castle_list", "_markets_dirty")

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
    for prov in list(world.provinces_of(a)) + list(world.provinces_of(b)):
        if prov.controller != prov.owner and prov.controller in (a, b):
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
        for stand in sorted((p for p in neighbors(pos) if p in stands), key=lambda p: (stands[p], p)):
            if world.engage_check(group, pos, stand=stand)[0]:
                options[pos] = stand
                break
    return options


def attack_group(world, group, target):
    """The stack walks to the hex it attacks from (one unit_moved), then calls engage, which makes the one step onto the
    target and starts the battle, joins it or overruns the civilians there. Nothing moves when engage refuses. Returns what
    engage returned."""
    options = world.attack_options_group(group)
    if target not in options:
        return False
    stand = options[target]
    if stand != group[0].pos:
        world.move_group(group, stand)
    done = world.engage(group, target)
    if done:
        for unit in group:
            if unit in world.units:
                unit.moves_left, unit.attacked, unit.acted = 0, True, True
    world.changed()
    return done



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


def sieges(world):
    """Troops standing in enemy (or lost) provinces take control of them; castles hold out longer."""
    battle_hexes = {b.pos for b in world.battles}
    for prov in world.provinces.values():
        if prov.owner is None or prov.pos in battle_hexes:
            continue            # a battle hex: no siege progress, no garrison regrowth, while the battle lasts (spec 3.2)
        if world.retreated.get(prov.pos) == world.turn:
            continue            # a side fled or withdrew onto this hex this season: it is running, not besieging (0.2.1 review)
        here = [u for u in world.units_at(prov.pos) if u.kind.war]
        cap = prov.castle * GARRISON_HP
        if not here:
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
            continue
        if len({u.owner for u in here}) > 1:
            continue            # two armies on one hex: the battle decides it, no siege progress either way
        tag = here[0].owner
        if tag == prov.controller:
            prov.siege = 0
            continue
        if tag == prov.owner or world.at_war(tag, prov.controller):
            general = world.general(world.units_at(prov.pos))
            cannons = sum(u.kind.siege + (world.bonus(tag, "siege") if u.kind.branch == "artillery" else 0)
                          for u in here)
            prov.siege += 1 + cannons + (1 if general and general.trait == "assault" else 0)
            defended = prov.controller == prov.owner
            need = SIEGE_BASE + (prov.castle * (CASTLE_SIEGE + world.bonus(prov.owner, "siege_points"))
                                 if defended else 0)
            world.bus.emit("siege_progress", tag, prov.pos, progress=prov.siege, need=need)
            if prov.siege >= need:
                world.bus.emit("province_captured", tag, prov.pos, loser=prov.controller, by="siege")
                prov.controller, prov.siege = tag, 0
                prov.garrison = 0 if tag != prov.owner else prov.garrison
                world.message(f"{world.countries[tag].name} took control of {world.place(prov)}.",
                             None if world.player in (tag, prov.owner) else "nobody")
                world.changed()


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
