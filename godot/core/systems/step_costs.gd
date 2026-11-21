## The step costs of the armies' walk and of the supply line (docs/architecture/m6-build-spec.md sections 4.3, 5.0 A12 and
## 5.3): the cost of stepping from a hex across one of its six edges, in the summer rules and in the winter rules. The table
## is filled a hex at a time on first use (12 costs: six directions, then six for winter) and kept for the map: one table
## per (map, defs) pair, made by `of`. Pure: no engine calls and no luck. `compute` reads the defs live; a test that edits a
## number after a table was filled calls `clear_all`.
class_name StepCosts
extends RefCounted

## The three sentinels; every other cost is 1 to 252 (a byte).
const CLOSED := 253
const WADE := 254
const BLOCKED := 255
## Table slots per hex: six directions in summer, then six in winter.
const SLOTS := 12
## Neighbour offsets by direction (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE) for an even row and an odd row; the same as
## HexGrid's, which the tests compare with.
const EVEN_DX: Array[int] = [1, 0, -1, -1, -1, 0]
const EVEN_DY: Array[int] = [0, -1, -1, 0, 1, 1]
const ODD_DX: Array[int] = [1, 1, 0, -1, 0, 1]
const ODD_DY: Array[int] = [0, -1, -1, 0, 1, 1]

## The memo of `of`: "map id/defs id" -> StepCosts. The entry keeps its map and defs, so an id is never reused under it.
static var _memo: Dictionary = {}

## The map and the defs this table is made for (read-only by convention).
var map: MapData
var defs: GameDefs
var _table := PackedByteArray()
var _filled_flags := PackedByteArray()
var _filled := 0


func _init(p_map: MapData, p_defs: GameDefs) -> void:
	map = p_map
	defs = p_defs
	var n := map.hex_count()
	_table.resize(n * SLOTS)
	_table.fill(0)
	_filled_flags.resize(n)
	_filled_flags.fill(0)


## The table of this map and these defs, made on the first ask.
static func of(p_map: MapData, p_defs: GameDefs) -> StepCosts:
	var key := "%d/%d" % [p_map.get_instance_id(), p_defs.get_instance_id()]
	var found: Variant = _memo.get(key, null)
	if found is StepCosts and (found as StepCosts).map == p_map and (found as StepCosts).defs == p_defs:
		return found as StepCosts
	var steps := StepCosts.new(p_map, p_defs)
	_memo[key] = steps
	return steps


## Forgets every table (tests, and a defs edit).
static func clear_all() -> void:
	_memo.clear()


## The index of the hex next to hex `i` in direction `d`, or -1 off the map.
static func neighbour_index(cols: int, rows: int, i: int, d: int) -> int:
	var row := floori(float(i) / cols)
	var col := i - row * cols
	var odd := (row & 1) == 1
	var c := col + (ODD_DX[d] if odd else EVEN_DX[d])
	var r := row + (ODD_DY[d] if odd else EVEN_DY[d])
	if c < 0 or c >= cols or r < 0 or r >= rows:
		return -1
	return r * cols + c


## The slot of the edge between hex `i` and its neighbour `j` in direction `d` (MapData's per-edge numbering: a hex owns
## its edges 0 to 2, and its edges 3 to 5 are its neighbours' 0 to 2).
static func edge_slot(i: int, d: int, j: int) -> int:
	if d < 3:
		return 3 * i + d
	return 3 * j + (d - 3)


## The rule of 4.3 for stepping from hex `i` across direction `d`, with no table: the first rule that applies ends it.
## The summer and winter rules differ only in the closed passes and the snow.
static func compute(p_map: MapData, p_defs: GameDefs, i: int, d: int, winter: bool) -> int:
	var j := neighbour_index(p_map.cols, p_map.rows, i, d)
	if j < 0 or p_map.land[j] != 1:
		return BLOCKED
	var e := edge_slot(i, d, j)
	if p_map.crest[e] == 1 and p_map.pass_edge[e] == 0:
		return BLOCKED
	if winter and p_map.pass_edge[e] == 1 and (
			p_map.climate[i] == p_defs.pass_closing_climate or p_map.climate[j] == p_defs.pass_closing_climate):
		return CLOSED
	var g: int = p_defs.terrains[p_map.cover[j]].move + p_defs.relief_move_add[p_map.relief[j]]
	var road := p_map.road[e]
	if road == 3:
		g = mini(g, p_defs.highway_cap)
	elif road == 2:
		g = mini(g, p_defs.road_cap)
	elif road == 1:
		g = ceili(float(g) / p_defs.track_divisor)
	if winter and p_map.climate[j] == 0:
		g = floori(float(g * p_defs.winter_snow_percent) / 100.0)
	var river := p_map.river[e]
	var crossing := p_map.crossing[e]
	var bridged := crossing == 2 or crossing == 3
	if river == 4:
		if not bridged:
			g += p_defs.stream_cost
	elif river >= 1 and not bridged:
		if crossing == 1:
			g += p_defs.ford_cost
		elif crossing == 4:
			g += p_defs.ferry_cost
		elif river >= p_defs.river_wall_class:
			return BLOCKED
		elif river >= p_defs.river_wade_class:
			return WADE
		else:
			g += p_defs.river_cost
	return g


## The cost of the step from hex `i` in direction `d` (filled on first use): a sentinel or 1 to 252.
func cost(i: int, direction: int, winter: bool) -> int:
	if _filled_flags[i] == 0:
		_fill(i)
	return _table[_slot(i, direction, winter)]


## The supply line's cost: WADE is `supply_wade_cost`, CLOSED is BLOCKED (4.8).
func supply_cost(i: int, direction: int, winter: bool) -> int:
	var c := cost(i, direction, winter)
	if c == WADE:
		return defs.supply_wade_cost
	if c == CLOSED:
		return BLOCKED
	return c


## How many hexes are filled (the perf rows read it).
func filled() -> int:
	return _filled


func _slot(i: int, direction: int, winter: bool) -> int:
	var base: int = SLOTS * i
	return base + (6 if winter else 0) + direction


func _fill(i: int) -> void:
	for wi: int in 2:
		var winter := wi == 1
		for d: int in 6:
			_table[_slot(i, d, winter)] = compute(map, defs, i, d, winter)
	_filled_flags[i] = 1
	_filled += 1
