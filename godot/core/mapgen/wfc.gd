## Wave function collapse on the hex grid: a port of hexa/campaign/wfc.py (collapse), with its luck from core/rng.gd.
## Every cell starts with the tiles its prior allows. The cell with the fewest options is collapsed to one tile,
## weighted by its prior and by the neighbours that already have that tile, and the choice is propagated.
## A neighbour left with no option keeps its domain (the rule relaxes), so the run always finishes.
class_name Wfc
extends RefCounted

var _rng: Rng
var _affinity: float
var _tiles: Array[String] = []
var _index: Dictionary = {}  # tile -> bit number
var _compat: PackedInt64Array = PackedInt64Array()  # per tile: the bit mask of tiles it may touch
var _support: Dictionary = {}  # domain mask -> the tiles some tile of that domain may touch
var _near: Dictionary = {}  # cell -> Array[Vector2i] of its neighbours that are cells
var _prior: Dictionary = {}  # cell -> {tile: weight}
var _domain: Dictionary = {}  # cell -> bit mask of the tiles still possible
var _result: Dictionary[Vector2i, String] = {}
var _heap := MinHeap.new()


## cells: the land hexes; prior: cell -> {tile: weight}; forbidden: pairs of tiles that may not touch;
## affinity: how strongly a cell copies its neighbours. Returns cell -> tile.
static func collapse(cells: Array[Vector2i], prior: Dictionary, forbidden: Array[PackedStringArray],
		affinity: float, rng: Rng) -> Dictionary[Vector2i, String]:
	var wfc := Wfc.new()
	wfc._rng = rng
	wfc._affinity = affinity
	wfc._run(cells, prior, forbidden)
	return wfc._result


func _run(cells: Array[Vector2i], prior: Dictionary, forbidden: Array[PackedStringArray]) -> void:
	_prior = prior
	var seen: Dictionary = {}
	for p: Vector2i in cells:
		var pr: Dictionary = prior[p]
		for t: String in pr.keys():
			seen[t] = true
	for pair: PackedStringArray in forbidden:
		seen[pair[0]] = true
		seen[pair[1]] = true
	for t: String in seen.keys():
		_tiles.append(t)
	_tiles.sort()
	for i in _tiles.size():
		_index[_tiles[i]] = i
	var full := (1 << _tiles.size()) - 1
	_compat.resize(_tiles.size())
	for i in _tiles.size():
		_compat[i] = full
	for pair: PackedStringArray in forbidden:
		var a: int = _index[pair[0]]
		var b: int = _index[pair[1]]
		_compat[a] = _compat[a] & ~(1 << b)
		_compat[b] = _compat[b] & ~(1 << a)

	var cellset: Dictionary = {}
	for p: Vector2i in cells:
		cellset[p] = true
	for p: Vector2i in cells:
		var near: Array[Vector2i] = []
		for n: Vector2i in HexGrid.neighbours(p):
			if cellset.has(n):
				near.append(n)
		_near[p] = near
		var mask := 0
		var pr: Dictionary = prior[p]
		for t: String in pr.keys():
			var w: float = pr[t]
			if w > 0.0:
				mask = mask | (1 << _index[t])
		_domain[p] = mask if mask != 0 else full

	for p: Vector2i in cells:
		_heap.push(MinHeap.Entry.new(_popcount(_domain[p]), _rng.randf(), p))
	var queue: Array[Vector2i] = []
	queue.assign(cells)
	_propagate(queue)

	while not _heap.is_empty():
		var e: MinHeap.Entry = _heap.pop()
		var p := e.pos
		if _result.has(p) or e.count != _popcount(_domain[p]):
			continue
		var mask: int = _domain[p]
		var options: Array[String] = []
		var weights: Array[float] = []
		var pr: Dictionary = _prior[p]
		var near: Array[Vector2i] = _near[p]
		for i in _tiles.size():
			if ((mask >> i) & 1) == 1:
				var t := _tiles[i]
				var same := 0
				for n: Vector2i in near:
					if _result.get(n, "") == t:
						same += 1
				var base := 0.01
				if pr.has(t):
					base = float(pr[t])
				options.append(t)
				weights.append(base * (1.0 + _affinity * float(same)))
		var pick: String = options[_choose(weights)]
		_result[p] = pick
		_domain[p] = 1 << _index[pick]
		var changed: Array[Vector2i] = [p]
		_propagate(changed)


## Narrows the domains of the unresolved neighbours of the queued cells; a changed neighbour is queued again.
func _propagate(queue: Array[Vector2i]) -> void:
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		var allow := _allowed_next(_domain[p])
		var near: Array[Vector2i] = _near[p]
		for n: Vector2i in near:
			if _result.has(n):
				continue
			var before: int = _domain[n]
			var nd := before & allow
			if nd != before and nd != 0:
				_domain[n] = nd
				queue.append(n)
				_heap.push(MinHeap.Entry.new(_popcount(nd), _rng.randf(), n))


## The tiles that some tile of the domain may touch.
func _allowed_next(mask: int) -> int:
	if _support.has(mask):
		return _support[mask]
	var got := 0
	var m := mask
	var i := 0
	while m != 0:
		if (m & 1) == 1:
			got = got | _compat[i]
		m = m >> 1
		i += 1
	_support[mask] = got
	return got


## Index of one option, drawn as Python's random.choices does with these weights (bisect on the running total).
func _choose(weights: Array[float]) -> int:
	var cum: Array[float] = []
	var total := 0.0
	for w: float in weights:
		total += w
		cum.append(total)
	var x := _rng.randf() * total
	var lo := 0
	var hi := weights.size() - 1
	while lo < hi:
		var mid := (lo + hi) >> 1
		if x < cum[mid]:
			hi = mid
		else:
			lo = mid + 1
	return lo


static func _popcount(x: int) -> int:
	var count := 0
	var v := x
	while v != 0:
		v = v & (v - 1)
		count += 1
	return count
