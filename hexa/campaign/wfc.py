"""Wave function collapse on a hex grid.

Every cell starts with a set of possible tiles (weighted by a prior). Pairs of tiles that may
not touch are forbidden. Repeatedly the cell with the fewest options left is collapsed to one
tile (weighted by its prior and by how many neighbours already have that tile, so like clumps
with like), and the choice is propagated to the neighbours. When a neighbour would be left with
no options the rule is relaxed for that edge instead of restarting, so the run always finishes.
"""
import heapq


def collapse(cells, prior, forbidden, neighbours, rng, affinity=1.5, fixed=None):
    """cells: iterable of positions; prior: pos -> {tile: weight > 0};
    forbidden: iterable of (tile, tile) pairs that may not be neighbours (symmetric);
    neighbours: pos -> iterable of positions (positions outside `cells` are ignored);
    fixed: optional pos -> tile already decided. Returns {pos: tile}."""
    cells = list(cells)
    tiles = sorted({t for p in cells for t in prior[p]} | {t for pair in forbidden for t in pair}
                   | set((fixed or {}).values()))
    index = {t: i for i, t in enumerate(tiles)}
    full = (1 << len(tiles)) - 1
    compat = [full] * len(tiles)
    for a, b in forbidden:
        compat[index[a]] &= ~(1 << index[b])
        compat[index[b]] &= ~(1 << index[a])
    support = {}

    def allowed_next(mask):
        got = support.get(mask)
        if got is None:
            got = 0
            m, i = mask, 0
            while m:
                if m & 1:
                    got |= compat[i]
                m >>= 1
                i += 1
            support[mask] = got
        return got

    cellset = set(cells)
    near = {p: [n for n in neighbours(p) if n in cellset] for p in cells}
    domain = {}
    for p in cells:
        mask = 0
        for t, w in prior[p].items():
            if w > 0:
                mask |= 1 << index[t]
        domain[p] = mask or full
    result = {}
    for p, t in (fixed or {}).items():
        if p in domain:
            domain[p] = 1 << index[t]

    def propagate(queue):
        while queue:
            p = queue.pop()
            allow = allowed_next(domain[p])
            for n in near[p]:
                if n in result:
                    continue
                nd = domain[n] & allow
                if nd != domain[n] and nd:
                    domain[n] = nd
                    queue.append(n)
                    heapq.heappush(heap, (bin(nd).count("1"), rng.random(), n))

    heap = [(bin(domain[p]).count("1"), rng.random(), p) for p in cells]
    heapq.heapify(heap)
    propagate(list(cells))
    while heap:
        count, _, p = heapq.heappop(heap)
        if p in result or count != bin(domain[p]).count("1"):
            continue
        mask = domain[p]
        options = [t for t in tiles if mask >> index[t] & 1]
        weights = []
        for t in options:
            same = sum(1 for n in near[p] if result.get(n) == t)
            weights.append(prior[p].get(t, 0.01) * (1 + affinity * same))
        pick = rng.choices(options, weights)[0]
        result[p] = pick
        domain[p] = 1 << index[pick]
        propagate([p])
    return result
