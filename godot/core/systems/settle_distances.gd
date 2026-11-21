## The distances every land hex reads from the settlements round it (WorldImprove's facts place_distance, town_distance
## and city_distance), kept up to date one settlement change at a time instead of by a full recompute (issue #413: the
## full recompute is every land hex against every settlement, about 128 million distances on the made-up Europe).
##
## Three tables, by the level a settlement needs to count as a source: any level (place), 3 (town), 4 (city). A hex's
## value is the distance in hexes to the nearest source other than the hex itself, 99 when there is none within 99. A
## level change moves a table only when it crosses that table's level; a settlement that appears or goes moves every
## table it counts in. Adding a source lowers the values within its reach (`min(old, distance)`); removing one raises the
## values it alone held, found by a scan of the hexes whose value equals their distance to it and recomputed by a search
## over the sources kept by row. The results are exactly those of a full recompute (tests/core/test_settle_distances.gd).
##
## Pure: no files, no engine calls. `evals` counts the hex distances worked out, for the tests.
class_name SettleDistances
extends RefCounted

## The level a settlement needs to be a source of each table, and the fact each table writes.
const LEVELS: Array[int] = [1, 3, 4]
const KEYS: Array[String] = ["place_distance", "town_distance", "city_distance"]
const FAR := 99

## Hex distances worked out since the object was made (a count, not a time).
var evals: int = 0

var _cols: int = 0
var _rows: int = 0
var _cell_of: PackedInt32Array = PackedInt32Array()  # per hex index of the map: the land cell, or -1
var _facts: Array[Dictionary] = []  # per land cell: the dictionary that gets the three values
var _dist: Array[PackedInt32Array] = []  # per table, per hex index of the map
var _row_max: Array[PackedInt32Array] = []  # per table, per row: an upper bound of the values in that row
var _src: Array = []  # per table: Array[PackedInt32Array], per row the columns of its sources


## `cells` are the land cells in the order of `facts` (one dictionary each).
func _init(map: MapData, cells: Array[Vector2i], facts: Array[Dictionary]) -> void:
	_cols = map.cols
	_rows = map.rows
	_facts = facts
	_cell_of.resize(map.hex_count())
	_cell_of.fill(-1)
	for i: int in cells.size():
		_cell_of[map.index_of(cells[i])] = i
	for t: int in LEVELS.size():
		var values := PackedInt32Array()
		values.resize(map.hex_count())
		values.fill(FAR)
		_dist.append(values)
		var maxima := PackedInt32Array()
		maxima.resize(_rows)
		maxima.fill(FAR)
		_row_max.append(maxima)
		var rows: Array[PackedInt32Array] = []
		rows.resize(_rows)
		_src.append(rows)


## Everything again from the settlements as (column, row, level) in full: the start, and the reference the tests keep.
func rebuild(settled: Array[Vector3i]) -> void:
	for t: int in LEVELS.size():
		var rows: Array[PackedInt32Array] = []
		rows.resize(_rows)
		_src[t] = rows
		for s: Vector3i in settled:
			if s.z >= LEVELS[t]:
				(_src[t] as Array[PackedInt32Array])[s.y].append(s.x)
		var maxima: PackedInt32Array = _row_max[t]
		maxima.fill(0)
		for idx: int in _cell_of.size():
			if _cell_of[idx] < 0:
				continue
			var y := _row_of(idx)
			var v := _nearest(idx - y * _cols, y, t)
			_store(t, idx, v)
			maxima[y] = maxi(maxima[y], v)


## A settlement of `hex` went from `old_level` to `new_level` (0: no settlement there).
func change(hex: Vector2i, old_level: int, new_level: int) -> void:
	if hex.x < 0 or hex.y < 0 or hex.x >= _cols or hex.y >= _rows:
		return
	for t: int in LEVELS.size():
		var was := old_level >= LEVELS[t]
		var is_now := new_level >= LEVELS[t]
		if was == is_now:
			continue
		if is_now:
			(_src[t] as Array[PackedInt32Array])[hex.y].append(hex.x)
			_add(t, hex.x, hex.y)
		else:
			var column := (_src[t] as Array[PackedInt32Array])[hex.y]
			var at := column.find(hex.x)
			if at >= 0:
				column.remove_at(at)
			_remove(t, hex.x, hex.y)


## The value of a hex in a table (-1 for sea).
func value(t: int, hex: Vector2i) -> int:
	var idx := hex.y * _cols + hex.x
	return -1 if hex.x < 0 or hex.y < 0 or hex.x >= _cols or hex.y >= _rows or _cell_of[idx] < 0 else int(_dist[t][idx])


func _store(t: int, idx: int, v: int) -> void:
	_dist[t][idx] = v
	_facts[_cell_of[idx]][KEYS[t]] = v


## The distance to the nearest source of table t other than the hex itself, by rows outward from the hex's own.
func _nearest(x: int, y: int, t: int) -> int:
	var best := FAR
	var rows: Array[PackedInt32Array] = _src[t]
	var q := x - ((y - (y & 1)) >> 1)
	var k := 0
	while k < best:
		var below := y - k
		var above := y + k
		if below < 0 and above >= _rows:
			break
		for side: int in 2 if k > 0 else 1:
			var yy := below if side == 0 else above
			if yy < 0 or yy >= _rows:
				continue
			var off := (yy - (yy & 1)) >> 1
			for sx: int in rows[yy]:
				var dq := q - (sx - off)
				var dr := y - yy
				var d := maxi(maxi(absi(dq), absi(dr)), absi(dq + dr))
				evals += 1
				if d > 0 and d < best:
					best = d
		k += 1
	return best


## A source appeared at (x, y): every hex nearer to it than to what it had gets the new, smaller value.
func _add(t: int, x: int, y: int) -> void:
	var sq := x - ((y - (y & 1)) >> 1)
	var dist: PackedInt32Array = _dist[t]
	var maxima: PackedInt32Array = _row_max[t]
	for yy: int in range(maxi(0, y - FAR), mini(_rows - 1, y + FAR) + 1):
		var dr := yy - y
		var reach := maxima[yy] - 1  # a hex there is changed only if it is nearer than its value, at most the bound
		if reach < 0 or absi(dr) > reach:
			continue
		var off := (yy - (yy & 1)) >> 1
		var lo := maxi(maxi(-reach, -reach - dr), -(sq + off))
		var hi := mini(mini(reach, reach - dr), _cols - 1 - (sq + off))
		var row_at := yy * _cols
		for dq: int in range(lo, hi + 1):
			var idx := row_at + sq + dq + off
			evals += 1
			if _cell_of[idx] < 0:
				continue
			var d := maxi(maxi(absi(dq), absi(dr)), absi(dq + dr))
			if d > 0 and d < dist[idx]:
				_store(t, idx, d)


## A source went from (x, y): the hexes whose value was their distance to it are searched again.
func _remove(t: int, x: int, y: int) -> void:
	var sq := x - ((y - (y & 1)) >> 1)
	var dist: PackedInt32Array = _dist[t]
	var maxima: PackedInt32Array = _row_max[t]
	var held: Array[int] = []
	for yy: int in range(maxi(0, y - FAR), mini(_rows - 1, y + FAR) + 1):
		var dr := yy - y
		var reach := maxima[yy]
		if absi(dr) > reach:
			continue
		var off := (yy - (yy & 1)) >> 1
		var lo := maxi(maxi(-reach, -reach - dr), -(sq + off))
		var hi := mini(mini(reach, reach - dr), _cols - 1 - (sq + off))
		var row_at := yy * _cols
		for dq: int in range(lo, hi + 1):
			var idx := row_at + sq + dq + off
			evals += 1
			if _cell_of[idx] < 0:
				continue
			var d := maxi(maxi(absi(dq), absi(dr)), absi(dq + dr))
			if d > 0 and d == dist[idx]:
				held.append(idx)
	for idx: int in held:
		var yy := _row_of(idx)
		var v := _nearest(idx - yy * _cols, yy, t)
		if v != dist[idx]:
			_store(t, idx, v)
			maxima[yy] = maxi(maxima[yy], v)


func _row_of(idx: int) -> int:
	return floori(float(idx) / float(_cols))
