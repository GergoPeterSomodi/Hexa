"""War: declaring and ending wars, peace offers, attacks, battles and sieges.

Functions taking ``world``; ``CampaignWorld`` binds them as plain class attributes (``at_war = war.at_war``), so the hot
ones (``at_war``, ``enemies``, called from every supply and path search) cost no extra call. The battle system builds on
this module: ``attack_options_group`` says where a stack may strike, ``attack_group`` moves and fights, ``battle`` is one
fight (front line plus support, the general's trait, castle garrison; ``ranged`` for guns firing from where they stand),
``sieges`` is the season's step that gives a province to the army standing in it, ``peace`` ends a war and moves the
provinces, ``lose`` takes units off the map with a ``unit_lost`` event each and ``kill`` is ``lose`` for one unit and what it
carries. The bus events (``war_declared``, ``peace_made``, ``province_captured``, ``battle``, ``siege_progress``,
``unit_lost``) and their order are the same as before the move. Imports point down: never world.py, ui, render or pygame.
"""
from ...hexgrid import distance, neighbors, within
from ..data import (CASTLE_DEFENSE, CASTLE_SIEGE, COUNTER, FIGHT_ATTACK, FIGHT_DEFENSE, FRONT, GARRISON_HP,
                    GARRISON_REGEN, GENERAL, GENERAL_BONUS, OPEN_GROUND, PIKES_VS_HORSE, SIEGE_BASE, SUPPORT_BONUS,
                    SUPPORT_MAX, TERRAIN)
from ..state import Garrison, War

# What this module changes on the world: the wars, the provinces (owner, controller, siege, garrison), the units (hit
# points, experience, positions; the dead are removed), the countries (alive, capital), the log, and what changed()
# and refresh_markets() mark when a province changes hands.
OWNS = ("wars", "provinces", "units", "countries", "log", "version", "_owned", "_castle_list", "_markets_dirty")


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


def peace(world, a, b, winner=None):
    """End the war. Each side keeps what it occupies if `winner` is None; otherwise only the winner gains."""
    world.wars = [w for w in world.wars if {w.a, w.b} != {a, b}]
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
    for unit in list(world.units):
        if unit.carrier is None and not unit.naval and unit.owner in (a, b):
            prov = world.provinces.get(unit.pos)
            if prov and prov.owner in (a, b) and prov.owner != unit.owner:
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
    enemies = world.enemies(tag)
    if not enemies:
        return set()
    found = {u.pos for u in world.units if u.carrier is None and not u.naval and u.owner in enemies}
    for prov in world.castles():
        if prov.controller in enemies and prov.garrison > 0:
            found.add(prov.pos)
    ours = world.owners_at()
    return {pos for pos in found if tag not in ours.get(pos, ())}      # never attack the hex we stand on


def attack_options_group(world, group):
    """{target hex: hex to attack from, or "bombard" for cannons firing from where they stand}."""
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
    walls = world.walls()
    for pos in targets:
        near = [p for p in neighbors(pos) if p in stands and (p, pos) not in walls]
        if near:
            options[pos] = min(near, key=lambda p: stands[p])
    if any(u.kind.branch == "artillery" for u in fighters):
        for pos in targets:
            if distance(pos, lead.pos) <= 2 and (pos not in options or
                                                 all(u.kind.branch == "artillery" for u in fighters)):
                options[pos] = "bombard"
    return options


def attack_group(world, group, target):
    options = world.attack_options_group(group)
    if target not in options:
        return False
    stand = options[target]
    if stand == "bombard":
        shooters = [u for u in group if u.kind.branch == "artillery" and u.moves_left > 0 and not u.attacked]
        world.battle(shooters, target, ranged=True)
        for unit in shooters:
            unit.moves_left, unit.attacked, unit.acted = 0, True, True
    else:
        if stand != group[0].pos:
            world.move_group(group, stand)
        attackers = [u for u in group if u in world.units and u.kind.war]
        if attackers:
            world.battle(attackers, target)
        for unit in group:
            if unit in world.units:
                unit.moves_left, unit.attacked, unit.acted = 0, True, True
    world.changed()
    return True


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


def battle(world, attackers, pos, ranged=False):
    """Front line + support: the best 3 of each side fight, the rest support them."""
    prov = world.provinces[pos]
    here = world.units_at(pos)
    att_tag = attackers[0].owner
    def_tag = here[0].owner if here else prov.controller
    if def_tag == att_tag:
        return                                  # a country never fights itself
    castle = prov.castle if prov.controller == def_tag and prov.garrison > 0 else 0
    fight = "assault" if castle else ("open" if prov.terrain in OPEN_GROUND else "rough")
    dfight = "garrison" if castle else ("open" if fight == "open" else "rough")
    gen_a = world.general(world.units_at(attackers[0].pos))
    gen_d = world.general(here)
    defenders = [u for u in here if u.kind.war]
    if castle:
        defenders.append(Garrison(prov, world.bonus(def_tag, "garrison_defense")))
    names = (world.countries[att_tag].name, world.countries[def_tag].name if def_tag else "the natives")
    shown = None if world.player in (att_tag, def_tag) else "nobody"
    if not defenders:
        world.lose(here, "overrun")
        world.message(f"{names[0]} overran {len(here)} unarmed unit{'s' * (len(here) != 1)} at {world.place(prov)}.", shown)
        return
    att_front = sorted(attackers, key=lambda u: -world.attack_value(u, fight, gen_a))[:FRONT]
    att_back = [u for u in attackers if u not in att_front]
    def_front = sorted(defenders, key=lambda u: -world.defense_value(u, dfight, prov, castle, None, gen_d))[:FRONT]
    def_back = [u for u in defenders if u not in def_front]
    att_support = min(SUPPORT_MAX, SUPPORT_BONUS * len(att_back))
    def_support = min(SUPPORT_MAX, SUPPORT_BONUS * len(def_back))
    before = {id(u): u.hp for u in attackers + defenders}      # HP going in, to report what this fight cost
    rng = world.rng

    def strike(attacker, target, factor, support, gen_att, gen_def, att_fight, def_fight):
        hit = world.attack_value(attacker, att_fight, gen_att) * rng.uniform(0.8, 1.25) * (1 + support) * factor
        block = world.defense_value(target, def_fight, prov, castle, attacker.kind.branch, gen_def) * 0.5
        target.hp -= max(1, round(hit - block))

    alive = lambda units: [u for u in units if u.hp > 0]
    if ranged:
        for gun in attackers:
            if alive(def_front):
                strike(gun, rng.choice(alive(def_front)), 1.0, 0, gen_a, gen_d, fight, dfight)
    else:
        for gun in [u for u in att_back if u.kind.branch == "artillery"]:
            if alive(def_front):
                strike(gun, rng.choice(alive(def_front)), 0.6, 0, gen_a, gen_d, fight, dfight)
        for unit in att_front:
            if alive(def_front):
                strike(unit, rng.choice(alive(def_front)), 1.0, att_support, gen_a, gen_d, fight, dfight)
        counter_fight = "open" if fight == "assault" else fight
        for unit in alive(def_front):
            if alive(att_front):
                factor = COUNTER * (0.5 if unit.kind.branch == "artillery" else 1.0)
                strike(unit, rng.choice(alive(att_front)), factor, def_support, gen_d, gen_a, counter_fight,
                       "open" if fight == "open" else "rough")
    hp_a = sum(before[id(u)] - max(0, u.hp) for u in attackers)
    hp_d = sum(before[id(u)] - max(0, u.hp) for u in defenders)
    lost_a = [u for u in attackers if u.hp <= 0]
    lost_d = [u for u in defenders if u.hp <= 0 and not isinstance(u, Garrison)]
    for unit in lost_a + lost_d:
        if unit in world.units:
            world.kill(unit)
    for unit in defenders:
        if isinstance(unit, Garrison):
            prov.garrison = max(0, unit.hp)
    survivors_d = [u for u in defenders if u.hp > 0]
    for unit in attackers + defenders:
        if unit.hp > 0 and not isinstance(unit, Garrison):
            unit.xp += 1 + (0 if survivors_d or unit not in attackers else 1)
    dead = lambda n: f" ({n} unit{'s' * (n != 1)} destroyed)" if n else ""
    text = (f"{'Bombardment' if ranged else 'Battle'} at {world.place(prov)}: {names[0]} lost {hp_a} strength"
            f"{dead(len(lost_a))}, {names[1]} lost {hp_d}{dead(len(lost_d))}")
    if castle and prov.garrison <= 0 and not [u for u in world.units_at(pos) if u.kind.war]:
        if ranged:
            text += "; the castle walls are breached"
        else:
            world.bus.emit("province_captured", att_tag, pos, loser=prov.controller, by="storm")
            prov.controller, prov.siege = att_tag, 0
            world.lose(world.units_at(pos), "storm")
            text += f"; {names[0]} stormed the castle"
    elif not survivors_d and not ranged:
        world.lose([u for u in world.units_at(pos) if u.owner == def_tag], "storm")
    world.bus.emit("battle", att_tag, pos, defender=def_tag, ranged=ranged, lost=(len(lost_a), len(lost_d)),
                  hurt=(hp_a, hp_d))
    world.message(text + ".", shown)


def lose(world, units, why):         # off the map, with a unit_lost event each (why: see hexa/events.py)
    for unit in list(units):
        world.units.remove(unit)
        world.bus.emit("unit_lost", unit.owner, unit.pos, what=unit.kind.name, why=why)


def kill(world, unit, why="battle"):
    world.lose(world.cargo(unit), "sunk")
    if unit in world.units:
        world.lose([unit], why)


def sieges(world):
    """Troops standing in enemy (or lost) provinces take control of them; castles hold out longer."""
    for prov in world.provinces.values():
        if prov.owner is None:
            continue
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
            world.units = [u for u in world.units if u.owner != tag]
            world.wars = [w for w in world.wars if tag not in (w.a, w.b)]
            world.message(f"{country.name} has disappeared from the map.", None, "extinct")
        elif country.alive and world.provinces[country.capital].owner != tag:
            country.capital = max(world.provinces_of(tag), key=lambda p: p.pop).pos
