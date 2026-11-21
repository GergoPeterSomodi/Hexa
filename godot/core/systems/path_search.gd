## The path searches of the armies and the supply line (docs/architecture/m6-build-spec.md sections 5.0 R6, R7 and 5.3): A*
## for one route, a bounded Dijkstra for the reach of a season, multi-source fields and the whole-map cost field to a goal.
## Dial's bucket queue on integer costs: circular buckets of BUCKETS lists, so no heap. Pure: it knows no country. `allowed`
## has one byte a hex (1: the searcher may stand there), made by the caller (Movement's open mask for armies, the country's
## own land for supply). Ties follow the fixed order: buckets first in, neighbours in direction order 0 to 5, a strict
## improvement only (R6 h).
class_name PathSearch
extends RefCounted

## "Not reached" in every distance field.
const UNREACHED := 1 << 30
## Circular buckets. The keys of one search differ by at most budget + 1 (a WADE step of a reach spends the whole budget,
## and a unit's move points are at most 1,000, MP_MAX), so 1,024 buckets never hold two keys at once.
const BUCKETS := 1024


## The state of one search (the dense per-hex arrays and what it touched).
class Run extends RefCounted:
	var dist := PackedInt32Array()
	var parent := PackedInt32Array()
	## Every hex that got a finite distance, in the order it was first reached (the start first).
	var touched := PackedInt32Array()
	## True when a step was refused only because it went past the budget.
	var cut := false
	var reached := false


## The cheapest route from `from` to `goal` (A*, the heuristic is the hex distance, every step costs 1 or more). `hexes`
## gives the steps after the start, the goal last; `why` is "" when ok, else "unreachable" (no route at all) or "too_far"
## (a route exists but costs more than `max_cost`). WADE steps count `wade_cost`. `comps` (from `components`, optional)
## answers a goal in another component at once.
static func route(map: MapData, steps: StepCosts, allowed: PackedByteArray, from: Vector2i, goal: Vector2i,
		winter: bool, max_cost: int, wade_cost: int, comps: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var s := map.index_of(from)
	var g := map.index_of(goal)
	if s < 0 or g < 0:
		return _no("unreachable")
	if s == g:
		return {"ok": true, "cost": 0, "hexes": PackedInt32Array(), "why": ""}
	if allowed[g] == 0:
		return _no("unreachable")
	if not comps.is_empty() and (comps[g] < 0 or comps[g] != comps[s]):
		return _no("unreachable")
	var run := _search(steps, allowed, PackedInt32Array([s]), g, max_cost, winter, false, false, wade_cost, false, true)
	if run.reached:
		return _found(run, s, g)
	var why := "unreachable"
	if run.cut:
		var free := _search(steps, allowed, PackedInt32Array([s]), g, UNREACHED, winter, false, false, wade_cost, false, true)
		if free.reached:
			why = "too_far"
	return _no(why)


## The hexes an army reaches in one season from `from` with `budget` move points: the walk's rule, a WADE step only as the
## first step (it spends the whole budget). {hex index: cost}, the start included at 0.
static func reach(map: MapData, steps: StepCosts, allowed: PackedByteArray, from: Vector2i, budget: int,
		winter: bool) -> Dictionary:
	var out := {}
	var s := map.index_of(from)
	if s < 0:
		return out
	var run := _search(steps, allowed, PackedInt32Array([s]), -1, budget, winter, false, false, 0, true, false)
	for i: int in run.touched:
		out[i] = run.dist[i]
	return out


## Multi-source: the cost to every hex from the nearest of `starts`, up to `budget`; UNREACHED beyond. `supply` uses
## StepCosts.supply_cost (WADE is supply_wade_cost); otherwise the plan's costs (WADE is wade_plan_cost).
static func field(map: MapData, steps: StepCosts, allowed: PackedByteArray, starts: PackedInt32Array, budget: int,
		winter: bool, supply: bool) -> PackedInt32Array:
	var run := _search(steps, allowed, starts, -1, budget, winter, supply, false, steps.defs.wade_plan_cost, false, false)
	return run.dist


## The whole-map cost to `goal` from every hex (reverse steps, the plan's costs): the route cost from x to goal, the goal 0,
## UNREACHED for a hex that cannot reach it. M8's march (spec 5.3).
static func cost_field(map: MapData, steps: StepCosts, allowed: PackedByteArray, goal: Vector2i,
		winter: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(map.hex_count())
	out.fill(UNREACHED)
	var g := map.index_of(goal)
	if g < 0:
		return out
	var run := _search(steps, allowed, PackedInt32Array([g]), -1, UNREACHED, winter, false, true,
		steps.defs.wade_plan_cost, false, false)
	return run.dist


## Labels the allowed hexes by the component they belong to (steps that are not BLOCKED join hexes; WADE and CLOSED count
## as connected). -1 for a hex the mask does not allow. Used to refuse an unreachable goal at once (R7).
static func components(map: MapData, steps: StepCosts, allowed: PackedByteArray) -> PackedInt32Array:
	var n := map.hex_count()
	var cols := map.cols
	var rows := map.rows
	var label := PackedInt32Array()
	label.resize(n)
	label.fill(-1)
	var next := 0
	for s: int in n:
		if allowed[s] == 0 or label[s] >= 0:
			continue
		label[s] = next
		var queue := PackedInt32Array([s])
		var head := 0
		while head < queue.size():
			var u: int = queue[head]
			head += 1
			for d: int in 6:
				var v := StepCosts.neighbour_index(cols, rows, u, d)
				if v < 0 or allowed[v] == 0 or label[v] >= 0:
					continue
				if steps.cost(u, d, false) == StepCosts.BLOCKED:
					continue
				label[v] = next
				queue.append(v)
		next += 1
	return label


static func _found(run: Run, s: int, g: int) -> Dictionary:
	var hexes := PackedInt32Array()
	var cur := g
	while cur != s:
		hexes.append(cur)
		cur = run.parent[cur]
	hexes.reverse()
	return {"ok": true, "cost": run.dist[g], "hexes": hexes, "why": ""}


static func _no(why: String) -> Dictionary:
	return {"ok": false, "cost": UNREACHED, "hexes": PackedInt32Array(), "why": why}


## The one search of this file. Forward (from the starts) or reverse (to the starts, `reverse`); `goal` >= 0 stops at it, with
## A* when `astar`. `start_wade_only`: a WADE step is taken only from a start (cost = budget). `supply`: the supply costs.
static func _search(steps: StepCosts, allowed: PackedByteArray, starts: PackedInt32Array, goal: int, budget: int,
		winter: bool, supply: bool, reverse: bool, wade: int, start_wade_only: bool, astar: bool) -> Run:
	var map := steps.map
	var cols := map.cols
	var rows := map.rows
	var n := map.hex_count()
	var run := Run.new()
	run.dist.resize(n)
	run.dist.fill(UNREACHED)
	run.parent.resize(n)
	run.parent.fill(-1)
	var buckets: Array[Array] = []
	for k: int in BUCKETS:
		buckets.append([])
	var goal_q := 0
	var goal_r := 0
	if astar and goal >= 0:
		goal_r = floori(float(goal) / cols)
		goal_q = goal - goal_r * cols - ((goal_r - (goal_r & 1)) >> 1)
	var queued := 0
	var cur := -1
	for s: int in starts:
		if run.dist[s] == 0:
			continue
		run.dist[s] = 0
		run.touched.append(s)
		var k := _h(s, cols, astar, goal_q, goal_r)
		_push(buckets, k, s)
		queued += 1
		if cur < 0 or k < cur:
			cur = k
	if cur < 0:
		return run
	while queued > 0 and not run.reached:
		var b: Array = buckets[cur % BUCKETS]
		if b.size() > 0:
			var head := 0
			while head < b.size() and not run.reached:
				var u: int = b[head]
				head += 1
				queued -= 1
				var gu: int = run.dist[u]
				if gu + _h(u, cols, astar, goal_q, goal_r) != cur:
					continue
				if u == goal:
					run.reached = true
					break
				for d: int in 6:
					var v: int
					var c: int
					if reverse:
						v = StepCosts.neighbour_index(cols, rows, u, d)
						if v < 0 or allowed[v] == 0:
							continue
						c = _edge_cost(steps, v, (d + 3) % 6, winter, supply)
					else:
						v = StepCosts.neighbour_index(cols, rows, u, d)
						if v < 0 or allowed[v] == 0:
							continue
						c = _edge_cost(steps, u, d, winter, supply)
					if c == StepCosts.BLOCKED:
						continue
					var nc: int
					if c == StepCosts.WADE and start_wade_only:
						if gu != 0:
							continue
						nc = budget
					elif c == StepCosts.WADE:
						nc = gu + wade
					else:
						nc = gu + c
					if nc > budget:
						run.cut = true
						continue
					if nc >= run.dist[v]:
						continue
					if run.dist[v] == UNREACHED:
						run.touched.append(v)
					run.dist[v] = nc
					run.parent[v] = u
					_push(buckets, nc + _h(v, cols, astar, goal_q, goal_r), v)
					queued += 1
			b.clear()
		cur += 1
	return run


## The cost of the step from `from` in direction `dir` as the search sees it: BLOCKED for a closed pass, WADE as is.
static func _edge_cost(steps: StepCosts, from: int, dir: int, winter: bool, supply: bool) -> int:
	if supply:
		return steps.supply_cost(from, dir, winter)
	var c := steps.cost(from, dir, winter)
	if c == StepCosts.CLOSED:
		return StepCosts.BLOCKED
	return c


## The A* heuristic: the hex distance to the goal (0 without A*). Offset (odd-r) to axial coordinates.
static func _h(i: int, cols: int, astar: bool, goal_q: int, goal_r: int) -> int:
	if not astar:
		return 0
	var row := floori(float(i) / cols)
	var q := i - row * cols - ((row - (row & 1)) >> 1)
	var dq := q - goal_q
	var dr := row - goal_r
	var ds := -dq - dr
	return maxi(absi(dq), maxi(absi(dr), absi(ds)))


static func _push(buckets: Array[Array], key: int, v: int) -> void:
	buckets[key % BUCKETS].append(v)
