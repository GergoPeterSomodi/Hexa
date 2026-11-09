"""Random map generation: smoothed noise -> terrain, then a castle on each side."""
from collections import deque

from .hexgrid import neighbors, within
from .rules import TERRAIN


def _noise(cols, rows, rng, passes=2):
    grid = {(c, r): rng.random() for r in range(rows) for c in range(cols)}
    for _ in range(passes):
        smoothed = {}
        for pos, value in grid.items():
            near = [grid[n] for n in neighbors(pos) if n in grid]
            smoothed[pos] = (value + sum(near)) / (1 + len(near))
        grid = smoothed
    # Convert to ranks in 0..1 so thresholds mean "this share of the map".
    order = sorted(grid, key=grid.get)
    return {pos: i / (len(order) - 1) for i, pos in enumerate(order)}


def _connected(terrain, start, goal):
    seen, queue = {start}, deque([start])
    while queue:
        pos = queue.popleft()
        if pos == goal:
            return True
        for n in neighbors(pos):
            if n in terrain and n not in seen and TERRAIN[terrain[n]].passable:
                seen.add(n)
                queue.append(n)
    return False


def generate(cols, rows, rng):
    """Return (terrain, variants, castle_positions) where castle_positions = (player, ai)."""
    while True:
        height = _noise(cols, rows, rng)
        wet = _noise(cols, rows, rng)
        soil = _noise(cols, rows, rng, passes=1)
        terrain = {}
        for pos in height:
            h, w = height[pos], wet[pos]
            if h > 0.95:
                terrain[pos] = "mountain"
            elif h > 0.83:
                terrain[pos] = "hills"
            elif w < 0.09:
                terrain[pos] = "water"
            elif w > 0.74:
                terrain[pos] = "forest"
            elif soil[pos] > 0.7:
                terrain[pos] = "dirt"
            else:
                terrain[pos] = "grass"

        mid = rows // 2
        player = (1, mid + rng.randint(-2, 2))
        ai = (cols - 2, mid + rng.randint(-2, 2))
        for castle in (player, ai):
            for pos in within(castle, 1):
                if pos in terrain:
                    terrain[pos] = "grass"

        if _connected(terrain, player, ai):
            variants = {pos: rng.randrange(len(TERRAIN[t].sprites)) for pos, t in terrain.items()}
            return terrain, variants, (player, ai)
