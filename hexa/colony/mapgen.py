"""Random continent for the colonisation mode: land in the west, ocean in the east."""
from collections import deque

from ..hexgrid import distance, neighbors, within
from ..mapgen import _noise
from .rules import COLONISERS, TERRAIN, TRIBE_NAMES


def _land_connected(terrain, spots):
    start = spots[0]
    seen, queue = {start}, deque([start])
    while queue:
        pos = queue.popleft()
        for n in neighbors(pos):
            if n in terrain and n not in seen and TERRAIN[terrain[n]].passable:
                seen.add(n)
                queue.append(n)
    return all(s in seen for s in spots)


def generate(cols, rows, rng, village_count):
    """Return (terrain, variants, landings, villages).

    landings: {side: (coast hex to land on, ocean hex where its ship starts)}
    villages: [(pos, tribe index)]
    """
    while True:
        height = _noise(cols, rows, rng)
        wet = _noise(cols, rows, rng)
        soil = _noise(cols, rows, rng, passes=1)

        # A ragged north-south coastline about 7 hexes from the east edge.
        coast, drift = {}, 0
        for r in range(rows):
            drift = max(-2, min(2, drift + rng.choice((-1, 0, 0, 1))))
            coast[r] = cols - 7 + drift

        terrain = {}
        for (c, r), h in height.items():
            w = wet[(c, r)]
            if c >= coast[r]:
                terrain[(c, r)] = "ocean"
            elif h > 0.93:
                terrain[(c, r)] = "mountain"
            elif h > 0.80:
                terrain[(c, r)] = "hills"
            elif w < 0.06:
                terrain[(c, r)] = "water"
            elif w > 0.62:
                terrain[(c, r)] = "forest"
            elif soil[(c, r)] > 0.7:
                terrain[(c, r)] = "dirt"
            else:
                terrain[(c, r)] = "grass"
        for pos, t in list(terrain.items()):
            if t in ("grass", "dirt", "forest") and rng.random() < 0.6 and \
                    any(terrain.get(n) == "ocean" for n in neighbors(pos)):
                terrain[pos] = "beach"

        # Landing spots: player in the middle, the rival companies north and south.
        landings = {}
        for side, r in zip(COLONISERS, (rows // 2, 3, rows - 4)):
            land, sea = (coast[r] - 1, r), (coast[r] + 1, r)
            for pos in within(land, 1):
                if pos in terrain and terrain[pos] in ("mountain", "water"):
                    terrain[pos] = "grass"
            terrain[land] = "beach"
            terrain[sea] = "ocean"
            landings[side] = (land, sea)

        spots = [land for land, _ in landings.values()]
        if not _land_connected(terrain, spots):
            continue

        # Native villages, inland and away from the landing spots.
        candidates = [p for p, t in terrain.items() if t in ("grass", "dirt", "forest", "hills")
                      and p[0] <= coast[p[1]] - 3 and all(distance(p, s) >= 5 for s in spots)]
        rng.shuffle(candidates)
        villages = []
        for pos in candidates:
            if len(villages) >= village_count:
                break
            if all(distance(pos, v) >= 4 for v, _ in villages):
                villages.append((pos, min(len(TRIBE_NAMES) - 1, pos[1] * len(TRIBE_NAMES) // rows)))
        if len(villages) < village_count - 2:
            continue

        variants = {pos: rng.randrange(len(TERRAIN[t].sprites)) for pos, t in terrain.items()}
        return terrain, variants, landings, villages
