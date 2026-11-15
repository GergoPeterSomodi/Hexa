## The ground cover of the map prototype region (step 4): one cover per land hex, chosen by wave function collapse
## (docs/design/map/04-wfc-model.md sections 2, 5 and 9; 01-terrain-and-relief.md sections 2.1, 2.2 and 8).
##
## The skeleton is fixed before this step: the relief levels, the crests and passes, the water and the coast. The solver
## only chooses the cover: farmland, grassland, woods, marsh, rock, snow and ice, tundra and sand.
##
## Cell rules (hard, checked before any choice; see cell_allowed): snow only on level 6 (the highest ground), woods
## not on level 6, marsh only on levels 1 and 2, farmland not above level 4, rock from level 4 (and on a cliff coast at
## level 3), tundra only north of 58 degrees, sand only on coastal lowland.
##
## Adjacency (hard, see pair_allowed): snow touches only snow, rock and grassland; rock never touches marsh or sand;
## sand never touches woods or snow; tundra never touches farmland, marsh or sand; and so on (FORBIDDEN).
##
## Weights (soft, the prior of each cover on each hex): the level and the height (rock and snow grow with height);
## the water (floodplains and river valleys favour farmland, grass and marsh; lake shores and river mouths favour
## marsh; a cliff favours rock); the latitude (a little more woods in the north, more farmland in the south); the coast
## (sand). Neighbour affinity (AFFINITY) makes covers cluster into patches: woods the most, so forests come in blocks.
##
## Search: propagation narrows the neighbours of each choice (arc consistency). A dead end undoes the last choice and
## everything it narrowed, and strikes that option out (backtracking). A search that uses up its backtrack budget
## restarts with the next draw of luck. After RETRIES restarts a greedy fill places the least-bad covers and lists them
## (none expected on the region; the test says so).
##
## Determinism: one Rng (core/rng.gd) seeded from the region's cover seed; ties are broken by hex position, never by
## the order of a dictionary. Pure: no files, no engine calls.
class_name WorldCover
extends RefCounted

const FARMLAND := 0
const GRASSLAND := 1
const WOODS := 2
const MARSH := 3
const ROCK := 4
const SNOW := 5
const TUNDRA := 6
const SAND := 7
const COUNT := 8
const NAMES: Array[String] = ["Farmland", "Grassland", "Woods", "Marsh", "Rock", "Snow and ice", "Tundra", "Sand"]
## Relief levels 0 (sea, unused here) to 6: the rows of the weight table have this many columns.
const LEVELS := 7
## Woods stop at the tree line: level 5 hexes below this height may carry woods (the Alps); above it, rock.
const TREE_LINE_M := 2000.0
## Tundra is only drawn north of this latitude (Lapland and the far north coast).
const TUNDRA_LAT := 58.0
## Slope (metres per kilometre, along the light) that gives the full shading of 0.2.
const SHADE_M_PER_KM := 220.0
## Restarts of the search before the greedy fill, and backtracks allowed in one run.
const RETRIES := 8
const BACKTRACK_LIMIT := 20000
## How strongly a hex copies the covers already round it: a weight grows by this much per neighbour of that cover.
const AFFINITY: Array[float] = [1.6, 1.2, 2.2, 1.2, 1.4, 1.6, 0.6, 0.6]
## The base weight of each cover (rows, in the order of the constants above) on each relief level (columns 0 to 6).
## Zero means not in the table; the cell rules decide what may stand where, the weights decide what is likely.
const BASE: Array[float] = [
	0.0, 1.0, 1.0, 0.5, 0.12, 0.0, 0.0,  # farmland
	0.0, 0.6, 0.7, 0.8, 0.9, 0.5, 0.0,  # grassland
	0.0, 0.6, 0.8, 1.0, 0.9, 0.5, 0.0,  # woods
	0.0, 0.25, 0.2, 0.0, 0.0, 0.0, 0.0,  # marsh
	0.0, 0.0, 0.0, 0.1, 0.6, 1.0, 0.0,  # rock
	0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5,  # snow and ice
	0.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.0,  # tundra
	0.0, 1.0, 0.6, 0.0, 0.0, 0.0, 0.0,  # sand
]
## Pairs of covers that may not touch (symmetric). Every other pair may.
const FORBIDDEN: Array[Vector2i] = [
	Vector2i(SNOW, FARMLAND), Vector2i(SNOW, WOODS), Vector2i(SNOW, MARSH), Vector2i(SNOW, SAND),
	Vector2i(SNOW, TUNDRA), Vector2i(ROCK, MARSH), Vector2i(ROCK, SAND), Vector2i(SAND, WOODS),
	Vector2i(TUNDRA, FARMLAND), Vector2i(TUNDRA, MARSH), Vector2i(TUNDRA, SAND),
]

## Cover of each land hex (sea and lake hexes have none).
var cover: Dictionary[Vector2i, int] = {}
## Hexes that touch the sea (not a lake), and hexes with a cliff coast (a sea shore of level 3 or higher).
var coastal: Dictionary[Vector2i, bool] = {}
var cliff: Dictionary[Vector2i, bool] = {}
## Hexes with a river on one of their edges, and hexes beside a lake (a lake edge or a whole lake hex).
var river_side: Dictionary[Vector2i, bool] = {}
var lake_side: Dictionary[Vector2i, bool] = {}
## Relief shading of each land hex, from the slope of the heights round it (about -0.2 to 0.2): positive when the ground
## faces the light from the upper left. The viewer multiplies the colour by 1 + shade.
var shade: Dictionary[Vector2i, float] = {}

var by_cover: PackedInt32Array = PackedInt32Array()  # index: cover; the count of land hexes
var by_level: PackedInt32Array = PackedInt32Array()  # index: level * COUNT + cover
var backtracks: int = 0  # dead ends undone (all attempts)
var restarts: int = 0  # searches given up after the backtrack budget
var contradictions: int = 0  # propagation wipe-outs (dead ends found; each one is undone or restarted)
var input_dead_ends: int = 0  # wipe-outs found before any choice (a rule or relief error; none expected)
var last_resort: Array[Vector2i] = []  # hexes placed by the greedy fill (none expected)
var last_resort_violations: int = 0  # forbidden pairs the greedy fill had to allow (none expected)

var _grid: HexGrid
var _cells: Array[Vector2i] = []
var _index: Dictionary[Vector2i, int] = {}
var _level: PackedInt32Array = PackedInt32Array()
var _metres: PackedFloat32Array = PackedFloat32Array()
var _lat: PackedFloat32Array = PackedFloat32Array()
var _nbr: PackedInt32Array = PackedInt32Array()  # six per cell: the neighbouring land cell or -1
var _prior: PackedFloat32Array = PackedFloat32Array()  # COUNT per cell: the weight, zero when not allowed
var _initial: PackedInt32Array = PackedInt32Array()  # the domain bits of each cell before any choice
var _dom: PackedInt32Array = PackedInt32Array()  # the domain bits of each cell now
var _compat: PackedInt32Array = PackedInt32Array()  # per cover: the bits of the covers it may touch
var _trail_cell: PackedInt32Array = PackedInt32Array()
var _trail_old: PackedInt32Array = PackedInt32Array()
var _frame_cell: PackedInt32Array = PackedInt32Array()
var _frame_opt: PackedInt32Array = PackedInt32Array()
var _frame_tried: PackedInt32Array = PackedInt32Array()
var _frame_before: PackedInt32Array = PackedInt32Array()
var _frame_start: PackedInt32Array = PackedInt32Array()
var _rng: Rng = null
var _attempt_backtracks: int = 0
var _hollows: Dictionary[Vector2i, bool] = {}  # land hexes with three or more higher neighbours (a basin or valley)
var _marsh_zone: Dictionary[Vector2i, bool] = {}  # hexes in a region marsh zone (Po delta, Venetian lagoon edges)


## The cover of every land hex of the relief, from the grid, the relief, the heights, the water and one seed.
static func build(grid: HexGrid, relief: WorldRelief, heights: WorldHeights, water: WorldWater,
		seed_value: int) -> WorldCover:
	var out := WorldCover.new()
	out._grid = grid
	out._compat = _compat_table()
	out._collect(relief, heights, water)
	out._build_priors()
	out._search(seed_value)
	out._finish()
	return out


## The cell rules: whether a cover may stand on a land hex of this level, height, coast and latitude.
static func cell_allowed(cover_id: int, level: int, metres: float, is_coastal: bool, is_cliff: bool,
		lat: float) -> bool:
	match cover_id:
		FARMLAND:
			return level >= 1 and level <= 4
		GRASSLAND:
			return level >= 1 and level <= 5
		WOODS:
			return (level >= 1 and level <= 4) or (level == 5 and metres < TREE_LINE_M)
		MARSH:
			return level == 1 or level == 2
		ROCK:
			return (level >= 4 and level <= 5) or (level == 3 and is_cliff)
		SNOW:
			return level == 6
		TUNDRA:
			return lat >= TUNDRA_LAT and level >= 1 and level <= 5
		SAND:
			return is_coastal and (level == 1 or level == 2) and not is_cliff
	return false


## Whether two covers may touch (the adjacency table).
static func pair_allowed(a: int, b: int) -> bool:
	for pair: Vector2i in FORBIDDEN:
		if (pair.x == a and pair.y == b) or (pair.x == b and pair.y == a):
			return false
	return true


func cover_at(hex: Vector2i) -> int:
	return int(cover.get(hex, -1))


func name_at(hex: Vector2i) -> String:
	var c := cover_at(hex)
	return "" if c < 0 else NAMES[c]


func is_coastal(hex: Vector2i) -> bool:
	return bool(coastal.get(hex, false))


func is_cliff(hex: Vector2i) -> bool:
	return bool(cliff.get(hex, false))


## The cover edge value (04 section 3.1): "blend" when the two land hexes carry different covers, else "same".
func is_blend(a: Vector2i, b: Vector2i) -> bool:
	var ca := cover_at(a)
	var cb := cover_at(b)
	return ca >= 0 and cb >= 0 and ca != cb


func count_of(cover_id: int) -> int:
	return int(by_cover[cover_id]) if cover_id >= 0 and cover_id < COUNT else 0


func count_at_level(level: int, cover_id: int) -> int:
	return int(by_level[level * COUNT + cover_id])


## Counts for the report and the tests.
func summary() -> Dictionary:
	var names: Dictionary[String, int] = {}
	for c: int in COUNT:
		names[NAMES[c]] = count_of(c)
	var levels: Array[Dictionary] = []
	for level: int in range(1, LEVELS):
		var row: Dictionary[String, int] = {}
		for c: int in COUNT:
			if count_at_level(level, c) > 0:
				row[NAMES[c]] = count_at_level(level, c)
		levels.append(row)
	return {
		"hexes": cover.size(),
		"by_cover": names,
		"by_level": levels,
		"backtracks": backtracks,
		"restarts": restarts,
		"contradictions": contradictions,
		"input_dead_ends": input_dead_ends,
		"last_resort": last_resort.size(),
		"last_resort_violations": last_resort_violations,
	}


# ----- inputs -------------------------------------------------------------------------------------------------------


func _collect(relief: WorldRelief, heights: WorldHeights, water: WorldWater) -> void:
	for hex: Vector2i in relief.levels.keys():
		if relief.level_at(hex) != ReliefLevels.SEA:
			_cells.append(hex)
	_cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return p.y < q.y or (p.y == q.y and p.x < q.x))
	var n := _cells.size()
	for i: int in n:
		_index[_cells[i]] = i
	_nbr.resize(n * 6)
	_nbr.fill(-1)
	_level.resize(n)
	_metres.resize(n)
	_lat.resize(n)
	for i: int in n:
		var hex := _cells[i]
		var level := relief.level_at(hex)
		var higher := 0
		var sea_near := false
		var cliff_here := false
		var river_here := false
		var lake_here := false
		for d: int in 6:
			var nb := _grid.neighbour(hex, d)
			if _index.has(nb):
				_nbr[i * 6 + d] = int(_index[nb])
			if not relief.levels.has(nb):
				continue
			var edge := HexGrid.edge_key(hex, nb)
			if water.river_edge.has(edge):
				river_here = true
			if water.lake_edge.has(edge) or water.lake_hex.has(nb):
				lake_here = true
			if water.shore_edge.has(edge) and str(water.shore_edge[edge]) == "cliff":
				cliff_here = true
			if relief.level_at(nb) == ReliefLevels.SEA and not water.lake_hex.has(nb):
				sea_near = true
			if relief.level_at(nb) > level:
				higher += 1
		_level[i] = level
		_metres[i] = float(heights.height_m.get(hex, 0.0))
		_lat[i] = float(_grid.lonlat_of(_grid.centre_km(hex)).y)
		coastal[hex] = sea_near
		_marsh_zone[hex] = water.marsh_zone.has(hex)
		cliff[hex] = cliff_here
		river_side[hex] = river_here
		lake_side[hex] = lake_here
		if higher >= 3 and level >= 1 and level <= 4:
			_hollows[hex] = true
	for i: int in n:
		shade[_cells[i]] = _shade_of(relief, heights, _cells[i])


## The slope of the heights round a hex (least squares over its neighbours; the sea is height 0), lit from the upper left.
func _shade_of(relief: WorldRelief, heights: WorldHeights, hex: Vector2i) -> float:
	var h0 := float(heights.height_m.get(hex, 0.0))
	var gx := 0.0
	var gy := 0.0
	var spread := 0.0
	var centre := _grid.centre_km(hex)
	for d: int in 6:
		var nb := _grid.neighbour(hex, d)
		if not relief.levels.has(nb):
			continue
		var dh := float(heights.height_m.get(nb, 0.0)) - h0
		var v := _grid.centre_km(nb) - centre
		gx += dh * v.x
		gy += dh * v.y
		spread += v.length_squared()
	if spread <= 0.0:
		return 0.0
	var lit := (gx + gy) / sqrt(2.0) / spread
	return clampf(lit / SHADE_M_PER_KM, -0.2, 0.2)


# ----- weights and the cell rules -----------------------------------------------------------------------------------


func _build_priors() -> void:
	var n := _cells.size()
	_prior.resize(n * COUNT)
	_prior.fill(0.0)
	_initial.resize(n)
	_initial.fill(0)
	for i: int in n:
		var hex := _cells[i]
		var level := _level[i]
		var metres := _metres[i]
		var lat := _lat[i]
		var wet := bool(river_side.get(hex, false))
		var lake := bool(lake_side.get(hex, false))
		var sea := bool(coastal.get(hex, false))
		var cl := bool(cliff.get(hex, false))
		var flood := wet and level <= 2
		var valley := wet and (level == 3 or level == 4)
		var basin := _hollows.has(hex)
		var mask := 0
		for c: int in COUNT:
			if not cell_allowed(c, level, metres, sea, cl, lat):
				continue
			var w := BASE[c * LEVELS + level]
			match c:
				FARMLAND:
					w *= 1.0 + 1.5 * float(flood) + 0.3 * float(valley)
					w *= 1.2 if lake else 1.0
					w *= clampf(1.0 + 0.04 * (45.0 - lat), 0.6, 1.4)
				GRASSLAND:
					w *= 1.0 + 0.3 * float(flood) + 0.4 * float(valley) + 0.3 * float(lake)
				WOODS:
					w *= clampf(1.0 + 0.10 * (lat - 45.0), 0.6, 1.4)
					w *= 0.6 if flood else 1.0
					w *= 1.25 if level >= 3 and level <= 5 else 1.0
				MARSH:
					w *= 1.0 + 2.5 * float(flood) + 2.0 * float(lake) + 1.0 * float(basin)
					# A river mouth on the low coast is a delta (step 5: the Po delta is marsh): four times the weight.
					w *= (4.0 if level <= 1 else 1.5) if sea and wet else 1.0
				ROCK:
					if level == 3:
						w *= 3.0 if cl else 1.0
					elif level == 4:
						w *= clampf((metres - 1000.0) / 800.0 + 0.5, 0.5, 2.0)
					elif level == 5:
						w *= 2.0 if metres >= TREE_LINE_M else 0.5
				_:
					pass
			if w > 0.0:
				_prior[i * COUNT + c] = w
				mask = mask | (1 << c)
		if bool(_marsh_zone.get(hex, false)) and cell_allowed(MARSH, level, metres, sea, cl, lat):
			# A marsh zone (the Po delta, the lagoon edges): the low hexes are marsh and nothing else (a rule of the
			# region data, not a weight). Hexes above level 2 keep their own choice.
			for c: int in COUNT:
				if c != MARSH:
					_prior[i * COUNT + c] = 0.0
			mask = 1 << MARSH
		_initial[i] = mask
		if mask == 0:
			# No cover is allowed here: a rule error in the inputs. Reported by the search (input_dead_ends).
			input_dead_ends += 1
	_hollows.clear()


static func _compat_table() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(COUNT)
	for a: int in COUNT:
		var bits := 0
		for b: int in COUNT:
			if pair_allowed(a, b):
				bits = bits | (1 << b)
		out[a] = bits
	return out


# ----- the search ---------------------------------------------------------------------------------------------------


func _search(seed_value: int) -> void:
	_rng = Rng.new()
	_rng.seed_with(seed_value)
	var n := _cells.size()
	for _attempt: int in RETRIES + 1:
		_dom = _initial.duplicate()
		_trail_cell.clear()
		_trail_old.clear()
		_clear_frames()
		_attempt_backtracks = 0
		var queue: Array[int] = []
		for i: int in n:
			queue.append(i)
		if not _propagate(queue):
			input_dead_ends += 1
			_dom = _initial.duplicate()
		if _run():
			return
		restarts += 1
	# Last resort: a greedy fill from the cell rules, listing every hex and every forbidden pair it allows.
	_greedy_fill()


## The backtracking loop. Returns true when every cell has one cover, false when the budget is used up or no option is
## left at the first choice. A frame is one decision: the cell, the option tried, the options already struck out, the
## domain before the decision and where the trail starts. A dead end restores the newest frame and strikes its option;
## when a frame has no option left it is popped, and the frame below it is restored in turn.
func _run() -> bool:
	var contradiction := false
	var result := false
	var running := true
	while running:
		if not contradiction:
			var cell := _pick_cell()
			if cell < 0:
				result = true
				running = false
			else:
				var opt := _pick_option(cell, _dom[cell])
				_frame_cell.append(cell)
				_frame_opt.append(opt)
				_frame_tried.append(0)
				_frame_before.append(_dom[cell])
				_frame_start.append(_trail_cell.size())
				contradiction = not _assign(cell, opt)
		else:
			if _frame_cell.is_empty() or _attempt_backtracks >= BACKTRACK_LIMIT:
				running = false
			else:
				_attempt_backtracks += 1
				backtracks += 1
				var top := _frame_cell.size() - 1
				_restore(int(_frame_start[top]))
				var tried := int(_frame_tried[top]) | (1 << int(_frame_opt[top]))
				_frame_tried[top] = tried
				var rem := int(_frame_before[top]) & ~tried
				if rem == 0:
					_pop_frame()
				else:
					var cell := int(_frame_cell[top])
					var opt := _pick_option(cell, rem)
					_frame_opt[top] = opt
					contradiction = not _assign(cell, opt)
	return result


func _clear_frames() -> void:
	_frame_cell.clear()
	_frame_opt.clear()
	_frame_tried.clear()
	_frame_before.clear()
	_frame_start.clear()


func _pop_frame() -> void:
	var top := _frame_cell.size() - 1
	_frame_cell.resize(top)
	_frame_opt.resize(top)
	_frame_tried.resize(top)
	_frame_before.resize(top)
	_frame_start.resize(top)


## The undecided cell with the fewest options (the first one by position on a tie); -1 when all are decided. A linear
## scan: fine for the region (292 hexes); Europe (about 58,000 land hexes) needs a heap keyed by the option count.
func _pick_cell() -> int:
	var best := -1
	var best_count := 99
	for i: int in _dom.size():
		var count := _popcount(_dom[i])
		if count > 1 and count < best_count:
			best_count = count
			best = i
	return best


## One option of a domain, drawn by weight: prior times the affinity of the neighbours that already have it.
func _pick_option(cell: int, mask: int) -> int:
	var options: Array[int] = []
	var weights: Array[float] = []
	var total := 0.0
	for c: int in COUNT:
		if ((mask >> c) & 1) == 0:
			continue
		var same := 0
		for d: int in 6:
			var nb := int(_nbr[cell * 6 + d])
			if nb >= 0 and int(_dom[nb]) == (1 << c):
				same += 1
		var w := maxf(float(_prior[cell * COUNT + c]), 0.01) * (1.0 + AFFINITY[c] * float(same))
		options.append(c)
		weights.append(w)
		total += w
	var x := _rng.randf() * total
	var acc := 0.0
	for k: int in options.size():
		acc += weights[k]
		if x < acc:
			return options[k]
	return options[options.size() - 1]


func _assign(cell: int, opt: int) -> bool:
	_push_trail(cell, int(_dom[cell]))
	_dom[cell] = 1 << opt
	var queue: Array[int] = [cell]
	return _propagate(queue)


## Narrows the neighbours of each queued cell to the covers its domain allows; false on a wipe-out.
func _propagate(queue: Array[int]) -> bool:
	while not queue.is_empty():
		var j: int = queue.pop_back()
		var allow := _support(int(_dom[j]))
		for d: int in 6:
			var k := int(_nbr[j * 6 + d])
			if k < 0:
				continue
			var before := int(_dom[k])
			var nd := before & allow
			if nd == before:
				continue
			_push_trail(k, before)
			_dom[k] = nd
			if nd == 0:
				contradictions += 1
				return false
			queue.append(k)
	return true


func _support(mask: int) -> int:
	var got := 0
	for c: int in COUNT:
		if ((mask >> c) & 1) == 1:
			got = got | int(_compat[c])
	return got


func _push_trail(cell: int, old: int) -> void:
	_trail_cell.append(cell)
	_trail_old.append(old)


func _restore(start: int) -> void:
	while _trail_cell.size() > start:
		var last := _trail_cell.size() - 1
		_dom[_trail_cell[last]] = _trail_old[last]
		_trail_cell.resize(last)
		_trail_old.resize(last)


func _greedy_fill() -> void:
	var n := _cells.size()
	var assigned := PackedInt32Array()
	assigned.resize(n)
	assigned.fill(-1)
	_dom = _initial.duplicate()
	for i: int in n:
		var best := -1
		var best_score := INF
		for c: int in COUNT:
			if ((int(_initial[i]) >> c) & 1) == 0:
				continue
			var viol := 0
			for d: int in 6:
				var nb := int(_nbr[i * 6 + d])
				if nb >= 0 and assigned[nb] >= 0 and not _may_touch(c, assigned[nb]):
					viol += 1
			var score := float(viol) * 1000.0 - float(_prior[i * COUNT + c])
			if score < best_score:
				best_score = score
				best = c
		if best < 0:
			best = FARMLAND  # cannot happen: every land hex has a cover allowed by the cell rules
		assigned[i] = best
		_dom[i] = 1 << best
		last_resort.append(_cells[i])
		for d: int in 6:
			var nb := int(_nbr[i * 6 + d])
			if nb >= 0 and assigned[nb] >= 0 and not _may_touch(best, assigned[nb]):
				last_resort_violations += 1


## Whether two covers may touch under the table the search uses (_compat).
func _may_touch(a: int, b: int) -> bool:
	return ((int(_compat[a]) >> b) & 1) == 1


func _finish() -> void:
	by_cover.resize(COUNT)
	by_cover.fill(0)
	by_level.resize(LEVELS * COUNT)
	by_level.fill(0)
	for i: int in _cells.size():
		var c := _lowest_bit(int(_dom[i]))
		cover[_cells[i]] = c
		by_cover[c] += 1
		by_level[_level[i] * COUNT + c] += 1
	_trail_cell.clear()
	_trail_old.clear()
	_clear_frames()
	_prior.clear()
	_initial.clear()
	_dom.clear()
	_nbr.clear()
	_cells.clear()
	_index.clear()


static func _popcount(mask: int) -> int:
	var count := 0
	var m := mask
	while m != 0:
		count += m & 1
		m = m >> 1
	return count


static func _lowest_bit(mask: int) -> int:
	for c: int in COUNT:
		if ((mask >> c) & 1) == 1:
			return c
	return FARMLAND
