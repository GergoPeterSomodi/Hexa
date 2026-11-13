"""Terrain rules: movement cost, winter, the ridge crests and mountain passes, and where a new land unit appears.

Functions taking ``world``. ``CampaignWorld`` binds them as methods with a plain class attribute (``edge_blocked =
terrain.edge_blocked``), so the hot ones (``edge_blocked``, ``step_walls``, ``winter``, ``step_cost``) cost no extra
call. What stays on ``CampaignWorld`` is ``pass_data``, which owns the ``_pass_cache`` the pass tables are kept in
(``pass_tables`` here builds them), and ``pass_wait``/``field_in``, which run the movement path search (step 3.11).
Imports point down: never world.py, ui, render or pygame.
"""
import hashlib

from ...hexgrid import distance, neighbors
from .. import geo
from ..data import TERRAIN
from ..state import Unit
from . import worldgen

# What this module changes: nothing on the world. The pass tables are cached by CampaignWorld.pass_data; the only
# thing written is the geography's own hash cache (geo._pass_geo_key).
OWNS = ()

INF = float("inf")


def pass_tables(world, key):
    """(key, ridge, passes, hexes, summer, winter), built from the geography (CampaignWorld.pass_data keeps it).
    ridge: frozenset of frozenset({a, b}), the crest edges that are never open; passes: {edge: (name, id)}, the
    crest edges that are open in summer and shut by snow in winter; hexes: {hex: pass name} for the hexes at the
    ends of a pass edge; summer / winter: every blocked step as an ordered (from, to) pair, for the path searches."""
    ridge, passes = worldgen.build_edges(world)
    hexes = {}
    for edge, (name, _) in sorted(passes.items(), key=lambda kv: sorted(kv[0])):
        for pos in edge:
            hexes.setdefault(pos, name)
    summer = frozenset(pair for e in ridge for a, b in (sorted(e),) for pair in ((a, b), (b, a)))
    shut = frozenset(pair for e in passes for a, b in (sorted(e),) for pair in ((a, b), (b, a)))
    return (key, ridge, passes, hexes, summer, summer | shut)


def step_cost(world, frm, to):
    """Move points to walk from one land hex into the next: roads and rivers make it cheaper. A step across a
    blocked edge (a ridge crest, or a pass shut by snow) is impossible: it costs INF."""
    if (frm, to) in step_walls(world):
        return INF
    return move_cost(world, frm, to)

def move_cost(world, frm, to):
    """step_cost without the ridge edges (trade routes ignore the crests)."""
    move = TERRAIN[world.terrain[to]].move
    if to in world.roads and frm in world.roads:
        return 1
    river = world.river_at.get(to)
    if river and world.river_at.get(frm) == river:
        return max(1, move - 1)
    return move

def is_winter(world):
    """Winter is every fourth turn (turn 4 is Winter in data.date)."""
    return world.turn % 4 == 0

def step_walls(world):
    """The ordered (from, to) steps land units cannot take this season."""
    data = world.pass_data()
    return data[5] if is_winter(world) else data[4]

def ridge_edges(world):
    """The crest edges no army can cross in any season: a frozenset of frozenset({hex, hex})."""
    return world.pass_data()[1]

def pass_edges(world):
    """[(name, id, edge, closed now)] for every pass: the crest edges that are open in summer and closed by snow
    in winter. `edge` is frozenset({hex, hex}); the list is sorted by id."""
    closed = is_winter(world)
    found = [(name, pid, edge, closed) for edge, (name, pid) in world.pass_data()[2].items()]
    return sorted(found, key=lambda t: (t[1], sorted(t[2])))

def edge_blocked(world, a, b, winter=None):
    """True if land units cannot step between the neighbouring hexes a and b: across a ridge crest, or through a
    pass in winter (winter=None means the current season)."""
    data = world.pass_data()
    if (a, b) in data[4]:
        return True
    if winter is None:
        winter = is_winter(world)
    return bool(winter) and (a, b) in data[5]

def passes(world):
    """{pos: name} of the hexes at the ends of a mountain pass edge (the hexes themselves are always open)."""
    return world.pass_data()[3]

def pass_name(world, pos):
    return passes(world).get(pos, "")

def pass_closed(world, pos, winter=None):
    """True if pos is at a mountain pass that snow has closed (winter=None means the current season). Only the
    step across the pass edge is closed (see edge_blocked); the hex itself can always be entered."""
    if winter is None:
        winter = is_winter(world)
    return bool(winter) and pos in passes(world)

def move_check(world, group, dest):
    """(ok, reason) for a stack stepping onto the next hex, dest. Ridge crests stop land units all year, and snow
    closes the mountain passes to them in winter."""
    if not group or dest is None:
        return False, ""
    lead = group[0]
    if lead.naval or distance(lead.pos, dest) != 1:
        return True, ""
    if (lead.pos, dest) in world.pass_data()[4]:
        return False, "Nobody can cross the ridge here; armies need a pass."
    if edge_blocked(world, lead.pos, dest):
        return False, f"The {world.pass_data()[2][frozenset((lead.pos, dest))][0]} pass is closed by snow until spring."
    return True, ""

def pass_blocks(world, group, goal):
    """The name of a mountain pass that snow has closed right in front of this land stack on its way to goal,
    or "" if no pass holds it up. A march stopped this way waits for spring instead of being dropped."""
    if not group or group[0].naval or goal is None or not is_winter(world):
        return ""
    passes, here = world.pass_data()[2], distance(group[0].pos, goal)
    for n in neighbors(group[0].pos):
        edge = passes.get(frozenset((group[0].pos, n)))
        if edge and distance(n, goal) < here:
            return edge[0]
    return world.pass_wait(group, goal)

def pass_edges_at(world, pos):
    """[(pass name, hex across the pass edge, compass direction to it)] for the pass edges that start at pos."""
    found = []
    lon, lat = geo.lonlat(pos)
    for edge, (name, _) in sorted(world.pass_data()[2].items(), key=lambda kv: sorted(kv[0])):
        if pos in edge:
            other = next(p for p in edge if p != pos)
            olon, olat = geo.lonlat(other)
            dx, dy = olon - lon, geo.merc(olat) - geo.merc(lat)
            way = ("north" if dy > abs(dx) * 0.5 else "south" if -dy > abs(dx) * 0.5 else "") + \
                ("east" if dx > abs(dy) * 0.5 else "west" if -dx > abs(dy) * 0.5 else "")
            found.append((name, other, way.replace("northeast", "north-east").replace("northwest", "north-west")
                          .replace("southeast", "south-east").replace("southwest", "south-west") or "next door"))
    return found

def within_reach(world, a, b):
    """Whether a hex at distance 2 or less from b can lend it support: no ridge crest or shut pass in the way."""
    d = distance(a, b)
    if d == 0:
        return True
    walls = step_walls(world)
    if d == 1:
        return (a, b) not in walls
    if d == 2:
        return any((a, m) not in walls and (m, b) not in walls for m in set(neighbors(a)) & set(neighbors(b)))
    return False

def land_spot(world, tag, prov, kind):
    """Where a new land unit appears: the province itself, or a province of ours next to it with room."""
    probe = Unit(0, kind, tag, prov.pos, hp=kind.hp)
    walls = step_walls(world)
    for pos in [prov.pos] + sorted(neighbors(prov.pos)):
        other = world.provinces.get(pos)
        if other and other.owner == tag and (prov.pos, pos) not in walls and world.can_stand([probe], pos):
            return pos
    return None

def geo_key(world):
    """A short hash of the ridges and passes of the geography: a save or snapshot built from other ones (or an
    older version of them) rebuilds its edges."""
    key = getattr(world.geo, "_pass_geo_key", None)
    if key is None:
        text = repr((getattr(world.geo, "MOUNTAINS", ()), getattr(world.geo, "PASSES", ())))
        key = hashlib.md5(text.encode("utf-8")).hexdigest()[:16]
        try:
            world.geo._pass_geo_key = key
        except AttributeError:
            pass
    return key
