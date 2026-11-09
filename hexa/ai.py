"""The computer opponent.

take_turn() is a generator: it performs one unit action and then yields that
unit, so the game can pause between moves and the player can watch.
The AI can see the whole map (it ignores fog of war).

Strategy: one soldier guards the castle. The other soldiers gather at a rally
point until there are WAVE_SIZE of them, then march on the enemy castle
together. Scouts roam and only pick fights they can win.
"""
from .hexgrid import distance
from .rules import AI, SCOUT, SOLDIER, other

THREAT_RANGE = 5     # enemy soldiers this close to our castle bring the army home
WAVE_SIZE = 3        # soldiers needed before an attack starts
CHASE_RANGE = 3      # attacking soldiers detour for enemies this close
RALLY_DISTANCE = 3   # how far in front of the castle the army gathers


def take_turn(world, side=AI):
    memory = world.ai_memory.setdefault(side, {"attacking": False})
    guard, home = _pick_guard(world, side)
    army = [u for u in world.units_of(side) if u.type is SOLDIER and u is not guard]
    if len(army) >= WAVE_SIZE:
        memory["attacking"] = True
    elif len(army) <= 1:
        memory["attacking"] = False

    # Soldiers first so they clear the way, scouts last.
    for unit in sorted(world.units_of(side), key=lambda u: u.type is SCOUT):
        if world.winner:
            return
        if not unit.alive or unit not in world.units:
            continue
        action = _choose_action(world, unit, home if unit is guard else None, memory["attacking"])
        if action is None:
            continue
        kind, arg = action
        if kind == "attack":
            world.attack(unit, arg)
        elif arg != unit.pos:
            world.move(unit, arg)
        else:
            continue
        yield unit


def _pick_guard(world, side):
    """One soldier stays home once we have two, or whenever an enemy soldier is close."""
    castles = world.castles_of(side)
    soldiers = [u for u in world.units_of(side) if u.type is SOLDIER]
    if not castles or not soldiers:
        return None, None
    home = castles[0].pos
    if len(soldiers) >= 2 or _raiders(world, side, THREAT_RANGE):
        return min(soldiers, key=lambda u: distance(u.pos, home)), home
    return None, None


def _raiders(world, side, radius):
    homes = [c.pos for c in world.castles_of(side)]
    return [e for e in world.units_of(other(side))
            if e.type.can_capture and any(distance(e.pos, h) <= radius for h in homes)]


def _choose_action(world, unit, guard_home, attacking):
    enemy_side = other(unit.owner)
    reach = world.reachable(unit)

    # 1. Grab an undefended enemy castle if we can reach it: that wins the game.
    for castle in world.castles_of(enemy_side):
        if castle.pos in reach:
            return "move", castle.pos

    options = world.attack_options(unit)

    # 2. The guard walks home, and once there only fights from the castle.
    if guard_home is not None:
        if unit.pos != guard_home:
            return "move", world.step_toward(unit, guard_home)
        targets = [world.unit_at(t) for t, stand in options.items() if stand == unit.pos]
        return ("attack", min(targets, key=lambda t: t.hp)) if targets else None

    # 3. Attack something worth hitting. Scouts only pick on weak targets.
    targets = [world.unit_at(t) for t in options]
    if unit.type is SCOUT:
        targets = [t for t in targets if t.type is SCOUT or t.hp <= unit.type.attack]
    if targets:
        return "attack", min(targets, key=lambda t: (t.hp, distance(unit.pos, t.pos)))

    # 4. Otherwise head for a goal.
    if unit.type is SCOUT:
        goal = _scout_goal(world, unit)
    else:
        goal = _soldier_goal(world, unit, attacking)
    if goal is None:
        return None
    return "move", world.step_toward(unit, goal)


def _soldier_goal(world, unit, attacking):
    raiders = _raiders(world, unit.owner, THREAT_RANGE - 1)
    if raiders:
        return min(raiders, key=lambda e: distance(unit.pos, e.pos)).pos
    targets = world.castles_of(other(unit.owner))
    if not targets:
        return None
    target = min(targets, key=lambda c: distance(unit.pos, c.pos)).pos
    if not attacking:
        return _rally_point(world, unit.owner, target)
    near = [e for e in world.units_of(other(unit.owner)) if distance(unit.pos, e.pos) <= CHASE_RANGE]
    if near:
        return min(near, key=lambda e: (distance(unit.pos, e.pos), e.hp)).pos
    return target


def _rally_point(world, side, target):
    key = ("rally", side)
    if key not in world.ai_memory:
        castles = world.castles_of(side)
        if not castles:
            return target
        home = castles[0].pos
        to_target = world.cost_field(target)
        spots = [p for p in to_target if distance(p, home) == RALLY_DISTANCE]
        world.ai_memory[key] = min(spots, key=to_target.get) if spots else home
    return world.ai_memory[key]


def _scout_goal(world, unit):
    if unit.ai_goal is None or distance(unit.pos, unit.ai_goal) <= 1:
        far = [p for p in world.terrain
               if world.terrain_at(p).passable and distance(p, unit.pos) >= 4]
        unit.ai_goal = world.rng.choice(far) if far else None
    return unit.ai_goal
