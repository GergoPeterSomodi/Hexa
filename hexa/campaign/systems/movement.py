"""Movement: where a stack may step, the paths and reach it has this season, and the march itself.

Functions taking ``world``; ``CampaignWorld`` binds them as plain class attributes (``plan = movement.plan``), so a
call costs no more than the old method did: this is the AI's hot path (``plan``, ``may_enter``, ``cost_field``,
``reachable_group``, ``step_toward_group``). The functions reach each other through ``world.`` as the methods did
(tests wrap ``world.plan`` and ``world.cost_field``). ``plan`` is the Dijkstra over a stack's move points,
``reachable_group``/``next_season_reach``/``path_to``/``route`` read it, ``move_group`` walks the route hex by hex and
emits ``unit_moved``, ``cost_field`` is the cost to a goal from everywhere (the AI's march, with ``step_toward_group``
choosing the next stop), and ``pass_wait``/``field_in`` decide whether a stack should wait for a pass to open instead of
taking a detour. Supply and foraging are in supply.py; step costs, walls and passes in terrain.py. Imports point down:
never world.py, ui, render or pygame.
"""
import heapq

from ...hexgrid import distance, neighbors
from ..data import GENERAL, SCOUT, TERRAIN

# What this module changes on the world: the units it moves (position, moves left, boarding), the movement record
# last_move, and, for the moment field_in runs, the turn (put back before it returns).
OWNS = ("units", "last_move", "turn")

INF = float("inf")


def may_enter(world, unit, pos, frm=None):
    """Whether the unit may step onto `pos` (ignoring other units), from `frm` (default: where it stands, when
    that is next to pos): a ridge crest or a pass shut by snow between the two hexes stops it."""
    if unit.naval:
        return world.is_sea(pos)
    if frm is None and distance(unit.pos, pos) == 1:
        frm = unit.pos
    if frm is not None and (frm, pos) in world.walls():
        return False
    prov = world.provinces.get(pos)
    if not prov:
        return False
    owner = prov.owner
    if owner in (None, unit.owner):
        return True
    return (unit.kind.war or unit.kind in (GENERAL, SCOUT)) and world.at_war(unit.owner, owner)


def zoc(world, tag):
    """Hexes next to enemy castles: armies must stop when they walk into them."""
    enemies = world.enemies(tag)
    if not enemies:
        return set()
    found, walls = set(), world.walls()
    for prov in world.castles():
        if prov.controller in enemies and prov.garrison > 0:
            found.update(n for n in neighbors(prov.pos) if (prov.pos, n) not in walls)
    return found


def stuck_reason(world, group):
    """Why a stack ordered to move cannot move this season, or "" if nothing in particular is in the way.
    A stack moves at its slowest unit's pace, so one unit with no moves left holds the whole stack back."""
    if min(u.moves_left for u in group) > 0:
        return ""
    if any(getattr(u, "foraged_turn", -1) == world.turn for u in group):
        return "They foraged this season and have no moves left."
    fresh = [u for u in group if u.moves_left <= 0 and not u.acted and u.kind.moves > 0]
    if not fresh:
        return "They have already moved this season."
    counts = {}
    for u in fresh:
        counts[u.kind.name] = counts.get(u.kind.name, 0) + 1
    names = " and ".join(f"{n} {kind}" if n > 1 else kind for kind, n in sorted(counts.items()))
    if len(fresh) == 1:
        return f"{names} raised this season and can't move yet. Untick it to move the rest."
    return f"{names} were raised this season and can't move yet. Untick them to move the rest."


def reachable(world, unit):
    return world.reachable_group([unit])


def reachable_group(world, group, best=None):
    """{pos: move cost} the stack can reach this season. `best` is a plan() over its moves, if one is at hand."""
    lead = group[0]
    moves = min(u.moves_left for u in group)
    if any(u.carrier for u in group):
        ship = lead.carrier
        if moves <= 0 or any(u.carrier is not ship for u in group):
            return {lead.pos: 0}
        reach = {lead.pos: 0}
        for n in neighbors(lead.pos):
            if all(world.may_enter(u, n) for u in group) and world.can_stand(group, n):
                reach[n] = 1
        return reach
    naval = lead.naval
    occupied = world.owners_at()
    if best is None:
        best = world.plan(group, moves)
    costs = {p: c for p, (c, _) in best.items()}
    alone = world.can_stand(group, None, others=[])
    reach = {p: c for p, c in costs.items()
             if p == lead.pos or (alone if p not in occupied else world.can_stand(group, p))}
    if not naval:
        aboard = world.aboard()
        for ship in world.units_of(lead.owner):
            if ship.naval and len(aboard.get(ship.id, ())) + len(group) <= ship.kind.capacity:
                via = [costs[n] for n in neighbors(ship.pos) if n in costs]
                if via and min(via) + 1 <= moves:
                    reach[ship.pos] = min(via) + 1
    return reach


def plan(world, group, budget):
    """{pos: (cost, previous pos)} for this stack over `budget` move points, same rules as moving."""
    lead = group[0]
    naval = lead.naval
    zoc = set() if naval else world.zoc(lead.owner)
    walls = frozenset() if naval else world.walls()
    occupied, mine = world.owners_at(), {lead.owner}
    best = {lead.pos: (0, None)}
    heap = [(0, lead.pos)]
    while heap:
        cost, pos = heapq.heappop(heap)
        if cost > best[pos][0]:
            continue
        if pos != lead.pos and pos in zoc:
            continue
        for n in neighbors(pos):
            if n not in world.terrain or (pos, n) in walls or not all(world.may_enter(u, n, pos) for u in group):
                continue
            if occupied.get(n, mine) != mine:
                continue
            new = cost + (1 if naval else world.step_cost(pos, n))
            if new <= budget and new < best.get(n, (INF,))[0]:
                best[n] = (new, pos)
                heapq.heappush(heap, (new, n))
    return best


def next_season_reach(world, group):
    """Hexes the stack could reach by the end of next season (but not this one)."""
    if any(u.carrier for u in group):
        return {}
    speed = min(world.unit_moves(u) for u in group)
    budget = min(u.moves_left for u in group) + speed
    occupied = world.owners_at()
    alone = world.can_stand(group, None, others=[])
    return {p: c for p, (c, _) in world.plan(group, budget).items()
            if (alone if p not in occupied else world.can_stand(group, p))}


def path_to(world, group, goal, seasons=4):
    """[(pos, move cost so far)] from the stack to goal, or [] if it is too far or blocked."""
    speed = min(world.unit_moves(u) for u in group)
    best = world.plan(group, min(u.moves_left for u in group) + speed * (seasons - 1))
    if goal not in best:
        return []
    path = []
    pos = goal
    while pos is not None:
        path.append((pos, best[pos][0]))
        pos = best[pos][1]
    return path[::-1]


def move(world, unit, dest):
    return world.move_group([unit], dest)


def move_toward(world, unit, goal):
    """move(unit, step_toward(unit, goal)): one step of a march, with one path search."""
    return world.move_toward_group([unit], goal)


def move_toward_group(world, group, goal):
    """move_group(group, step_toward_group(group, goal)) with one path search, not two: the plan is shared."""
    if world.pass_wait(group, goal):                  # behind a pass shut by snow: wait for spring
        return False
    best = world.group_plan(group)
    dest = world.step_toward_group(group, goal, best=best)
    return world.move_group(group, dest, best=best)


def group_plan(world, group):
    """plan() for the stack over its moves this season. None for units aboard a ship (they only step off)."""
    if group[0].carrier:
        return None
    return world.plan(group, min(u.moves_left for u in group))


def move_group(world, group, dest, best=None):
    """Walk a stack to dest this season. `best` is the stack's plan() if the caller already has one."""
    group = [u for u in group if u in world.units]
    if world.over or not group:
        return False
    lead = group[0]
    if dest == lead.pos:
        return True
    if not world.move_check(group, dest)[0]:
        return False
    if best is None:
        best = world.group_plan(group)
    reach = world.reachable_group(group, best)
    if dest not in reach:
        return False
    aboard = world.aboard()                  # looked up once: nobody gets on or off during the walk
    ship = None
    if not lead.naval:
        ship = next((u for u in world.units_at(dest) if u.naval and u.owner == lead.owner
                     and len(aboard.get(u.id, ())) + len(group) <= u.kind.capacity), None)
    # Walk the route hex by hex, looking around on the way (so fog clears along it, not just at the end).
    path = world.route(group, dest, best)
    world.last_move = ([u.id for u in group], path)
    explored_before = len(world.countries[lead.owner].explored)  # counted before the walk reveals anything (#26)
    scout = max(group, key=lambda u: world.unit_sight(u))      # the stack sees as far as its best eyes
    for step in path[1:-1]:
        for unit in group:
            unit.pos = step
            for passenger in aboard.get(unit.id, ()):
                passenger.pos = step
        world.see_from(scout, refresh=False)
    for unit in group:
        unit.pos = path[0]
        for passenger in aboard.get(unit.id, ()):
            passenger.pos = path[0]
    for unit in group:
        if ship:
            unit.carrier, unit.pos, unit.moves_left = ship, dest, 0
        elif unit.carrier:
            unit.carrier, unit.pos = None, dest
            unit.moves_left -= 1
        else:
            unit.moves_left -= reach[dest]
            unit.pos = dest
            for passenger in aboard.get(unit.id, ()):
                passenger.pos = dest
        unit.acted = True
    if not lead.naval and not ship and dest in world.zoc(lead.owner):
        for unit in group:
            unit.moves_left = 0
    country = world.countries[lead.owner]
    for unit in group:
        world.see_from(unit, refresh=False)
    if lead.owner == world.player:
        if len(country.explored) != explored_before:
            world.changed()
        world.update_visibility()
    seen = [lead.owner == world.player or p in world.visible for p in path]
    world.bus.emit("unit_moved", lead.owner, dest, ids=[u.id for u in group], path=tuple(path), naval=lead.naval,
                  seen=tuple(seen))
    return True


def step_in(world, group, pos):
    """The last step of an attack (spec 3.1): the stack moves from the hex beside pos onto pos, the enemy's hex. Its units
    have no moves left and have attacked. One unit_moved, with the walk (its hex, pos), as move_group emits. The caller
    checks the attack first (battle.engage does)."""
    group = [u for u in group if u in world.units]
    if not group:
        return False
    lead = group[0]
    path = (lead.pos, pos)
    ids = [u.id for u in group]
    for unit in group:
        unit.pos, unit.moves_left, unit.acted, unit.attacked = pos, 0, True, True
    world.last_move = (ids, list(path))
    for unit in group:
        world.see_from(unit, refresh=False)
    if lead.owner == world.player:
        world.update_visibility()
    seen = tuple(lead.owner == world.player or p in world.visible for p in path)
    world.bus.emit("unit_moved", lead.owner, pos, ids=ids, path=path, naval=lead.naval, seen=seen)
    return True


def route(world, group, dest, best=None):
    """The hexes the stack walks through to reach dest this season, start and end included."""
    lead = group[0]
    if lead.carrier or distance(lead.pos, dest) <= 1:
        return [lead.pos, dest]
    if best is None:
        best = world.plan(group, min(u.moves_left for u in group))
    if dest not in best:                     # boarding a ship: walk to the shore next to it
        shore = [n for n in neighbors(dest) if n in best]
        if not shore:
            return [lead.pos, dest]
        last = min(shore, key=lambda n: best[n][0])
        return world.route(group, last, best) + [dest] if last != lead.pos else [lead.pos, dest]
    path, pos = [], dest
    while pos is not None:
        path.append(pos)
        pos = best[pos][1]
    return path[::-1]


def cost_field(world, goal, naval=False, tag=None, until=None, unit=None):
    """Move costs to `goal` from everywhere (or until every hex in `until` is settled).
    With `unit` (a land unit), routes only run through hexes it may enter (may_enter): land it may not
    cross, such as a neighbour's, is no shortcut. Such hexes still get a cost as places to start from."""
    field = {goal: 0}
    heap = [(0, goal)]
    walls = frozenset() if naval else world.walls()
    left = set(until) if until else None
    while heap:
        cost, pos = heapq.heappop(heap)
        if cost > field.get(pos, INF):
            continue
        if left is not None:
            left.discard(pos)
            if not left:
                break
        if unit is not None and pos != goal and not world.may_enter(unit, pos):
            continue                       # a unit can start here but not walk on through it
        for n in neighbors(pos):
            if naval:
                ok, step = world.is_sea(n), 1
            else:
                ok = world.is_land(n) and (n, pos) not in walls
                step = world.move_cost(n, pos) if ok and world.is_land(pos) else \
                    TERRAIN[world.terrain[n]].move if ok else 0
            if ok and cost + step < field.get(n, INF):
                field[n] = cost + step
                heapq.heappush(heap, (cost + step, n))
    return field


def step_toward(world, unit, goal, field=None):
    return world.step_toward_group([unit], goal, field)


def step_toward_group(world, group, goal, field=None, best=None):
    """The hex of the next stop on the way to goal. `best` is the stack's plan() if the caller has one at hand."""
    lead = group[0]
    if best is None:
        best = world.group_plan(group)
    reach = world.reachable_group(group, best)
    if field is None:
        # Only wait for hexes this field can settle: a land field never reaches the sea hex of a
        # friendly ship in `reach`, and waiting for it would search the whole map.
        settles = world.is_sea if lead.naval else world.is_land
        until = [p for p in reach if settles(p)] or [goal]
        field = world.cost_field(goal, lead.naval, until=until, unit=None if lead.naval else lead)
    options = [p for p in reach if p == lead.pos or not any(u.naval for u in world.units_at(p)) or lead.naval]
    return min(options, key=lambda p: (field.get(p, distance(p, goal) * 4 + 1000), reach[p]))


def field_in(world, goal, winter, until):
    """cost_field(goal) as it would be in winter (or not), whatever season it is now."""
    turn = world.turn
    world.turn = 4 if winter else 2
    try:
        return world.cost_field(goal, until=until)
    finally:
        world.turn = turn


def pass_wait(world, group, goal):
    """The name of the closed pass a land stack should wait for spring at, or "". In winter, if the way to goal that
    the summer route takes through a pass has become much longer (more than twice as far, or 2+ seasons of moves
    more) or gone, the stack waits for the pass to open instead of walking off on a long detour and back."""
    if not group or group[0].naval or goal is None or not world.winter() or group[0].pos == goal:
        return ""
    here = group[0].pos
    summer = world.field_in(goal, False, [here])
    near = summer.get(here)
    if near is None:
        return ""
    far = world.field_in(goal, True, [here]).get(here)
    speed = max(1, min(world.unit_moves(u) for u in group))
    if far is not None and far <= 2 * near and far - near < 2 * speed:
        return ""
    passes, pos = world.pass_data()[2], here
    while pos != goal:                              # follow the summer route to the pass it goes through
        nxt = min((n for n in neighbors(pos) if summer.get(n, INF) < summer[pos]), key=lambda n: (summer[n], n),
                  default=None)
        if nxt is None:
            break
        edge = passes.get(frozenset((pos, nxt)))
        if edge:
            return edge[0]
        pos = nxt
    return ""
