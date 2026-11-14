"""Castle areas (0.2.2, docs/design/castle-areas.md, sections 2.2 and 2.3): a castle holds the land of its own country around it.

A castle of level L holds the provinces of its owner's own land within CASTLE_AREA[L] hexes, counted along that land (the
hexes its walk may pass are the owner's own provinces). Each province belongs to the nearest castle that reaches it (ties:
the higher level, then the lower position). A castle is a member of its own area at distance 0.

The state of a province, read by ``area_state``:
- "held": its owner controls it and the castle of its area stands (the castle's owner controls the castle). An enemy army
  may enter, stand and forage there, but cannot take it while the castle stands.
- "fallen": its owner controls it and the castle of its area has fallen (the castle is controlled by someone else).
- "open": no castle holds it, or its owner has lost control of it (own land: retaken by walking in, one season).
- "castle": the castle hex itself (the target of a siege, not land held by anything).

The membership (who belongs to which castle) depends only on owners and castle levels; the control that makes a state
"held" or "fallen" is read when asked, so a castle's fall needs no rebuild. The table is the world's cache
(``world.area_table()``, ``_areas`` in WORLD_CACHES): cleared when owners or castles change (``changed(ownership=True)``,
``forget_castles()``). Pygame-free. Nothing here changes the world: the siege step (war.sieges) and the AI read it.
"""
from collections import deque

from ...hexgrid import neighbors
from ..data import CASTLE_AREA

OWNS = ("castle_fell",)     # the season each castle fell (fell()); the table is the world's cache (CampaignWorld.area_table)


def reach(castle_level):
    """The hexes of its own land a castle of this level holds (data.CASTLE_AREA; a level past the table takes the last)."""
    return CASTLE_AREA[min(max(castle_level, 0), len(CASTLE_AREA) - 1)]


def build(world):
    """The membership table: {"of": {pos: castle}, "dist": {pos: hexes}, "paths": {castle: {pos: parent}},
    "members": {castle: [pos, ...]}}, the members of each area nearest first (the castle first). The reach is walked
    along land an army can walk: a ridge crest (pass_data()[4], the static ridge, never a pass) is not a step."""
    provinces = world.provinces
    crest = world.pass_data()[4]                # the ordered (from, to) steps across a ridge crest, in every season
    best = {}                                   # pos -> (sort key, castle): nearest, then higher level, then position
    paths = {}
    for castle in sorted(world.castles(), key=lambda p: p.pos):
        tree, depth = {castle.pos: None}, {castle.pos: 0}
        queue, limit = deque([castle.pos]), reach(castle.castle)
        while queue:
            pos = queue.popleft()
            if depth[pos] >= limit:
                continue
            for n in neighbors(pos):
                if n in tree or (pos, n) in crest:
                    continue
                prov = provinces.get(n)
                if prov is None or prov.owner != castle.owner:
                    continue
                tree[n], depth[n] = pos, depth[pos] + 1
                queue.append(n)
        paths[castle.pos] = tree
        for pos, hexes in depth.items():
            key = (hexes, -castle.castle, castle.pos)
            if pos not in best or key < best[pos][0]:
                best[pos] = (key, castle.pos)
    dist = {pos: key[0] for pos, (key, _) in best.items()}
    members = {}
    for pos in sorted(best, key=lambda p: (dist[p], p)):
        members.setdefault(best[pos][1], []).append(pos)
    return {"of": {pos: holder for pos, (_, holder) in best.items()}, "dist": dist, "paths": paths, "members": members}


def fell(world, prov):
    """Stamp the season a castle changed hands (a storm in the battles phase or a siege in the sieges step): its land
    opens from the next season, so the step of this season still reads the castle as standing (standing())."""
    world.castle_fell[prov.pos] = world.turn


def standing(world):
    """The castles that stand now: the castle hexes their owner still controls, and the castles that fell this season
    (fell()): the snapshot the siege step takes at its start counts them, so their land opens from the next season."""
    fell_now = world.castle_fell
    return {p.pos for p in world.castles() if p.controller == p.owner or fell_now.get(p.pos) == world.turn}


def is_held(world, prov, up=None):
    """Whether this province is held by a castle that stands: not a castle, its owner controls it, and the castle of its
    area stands. ``up`` is the set of standing castles as the caller fixed it (the siege step reads them at the start of its
    step, so a castle that falls mid-step opens its land from the next season); None reads the castles now."""
    if prov.castle or prov.controller != prov.owner:
        return False
    holder = world.area_table()["of"].get(prov.pos)
    if holder is None:
        return False
    if up is not None:
        return holder in up
    castle = world.provinces[holder]
    return castle.controller == castle.owner


def castle_of(world, pos):
    """The castle that holds the province at pos (its area's castle, standing), or None: open, fallen, a castle's own hex,
    or land no castle reaches."""
    prov = world.provinces.get(pos)
    if prov is None or not is_held(world, prov):
        return None
    return world.area_table()["of"][pos]


def area(world, castle_pos):
    """The provinces of a castle's area, the castle first, then nearest first. [] when castle_pos is no castle."""
    return list(world.area_table()["members"].get(castle_pos, ()))


def opens(world, castle_pos, taker=None):
    """The provinces a castle's fall opens to its taker: the area's provinces its owner still controls (the castle aside).
    0 when the owner takes its own castle back (``taker`` is the owner: its land is held again, nothing opens)."""
    castle = world.provinces.get(castle_pos)
    if castle is None or not castle.castle or castle.owner is None or taker == castle.owner:
        return 0
    return sum(1 for pos in area(world, castle_pos)
               if pos != castle_pos and world.provinces[pos].controller == castle.owner)


def _path(table, holder, pos):
    tree, path, cur = table["paths"][holder], [], pos
    while cur is not None:
        path.append(cur)
        cur = tree[cur]
    return path[::-1]


def area_state(world, pos, viewer=None):
    """The area read model of the hex pos: {"state": "held" | "fallen" | "open" | "castle", "castle": the castle of its
    area (its own hex for "castle"; None for land no castle reaches), "owner": the land's owner, "distance": hexes from the
    castle along its own land (0 for a castle; None for land no castle reaches), "path": the hexes from the castle to pos
    (both ends), "own": whether ``viewer`` is the land's owner}. None for a hex with no province or no owner. ``viewer``
    changes only "own"; a state is the land's and the castle's, for every viewer (see the module docstring)."""
    prov = world.provinces.get(pos)
    if prov is None or prov.owner is None:
        return None
    own = viewer is not None and viewer == prov.owner
    if prov.castle:
        return {"state": "castle", "castle": pos, "owner": prov.owner, "distance": 0, "path": [pos], "own": own}
    table = world.area_table()
    holder = table["of"].get(pos)
    if holder is None:
        return {"state": "open", "castle": None, "owner": prov.owner, "distance": None, "path": [], "own": own}
    path = _path(table, holder, pos)
    if prov.controller != prov.owner:
        state = "open"
    elif is_held(world, prov):
        state = "held"
    else:
        state = "fallen"
    return {"state": state, "castle": holder, "owner": prov.owner, "distance": len(path) - 1, "path": path, "own": own}
