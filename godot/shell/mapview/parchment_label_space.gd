## What is taken on the screen for ParchmentLabels: the boxes placed so far, looked up in a grid, and the geometry of a
## turned box against a screen box and against the hex cells (the unexplored ones, or another country's:
## docs/architecture/map-overview-build-spec.md R10, R12, D7). A turned box is its middle, its long axis (a unit vector) and its half size.
class_name ParchmentLabelSpace
extends RefCounted

## The side of a grid cell (screen px), and how far outside the screen a box is still entered in the grid.
const GRID_PX := 96.0
const REACH_PX := 360.0
## A hex cell's corners from its middle (map px; MapModes.hex_at_px's cells), the three of one half, and the normals of
## its three pairs of sides.
const HEX_CORNERS: Array[Vector2] = [Vector2(52.0, -25.5), Vector2(52.0, 25.5), Vector2(0.0, 51.0)]
const HEX_NORMALS: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.4402, -0.8979), Vector2(0.4402, 0.8979)]
## Two boxes that only touch do not overlap (map px).
const TOUCH_PX := 0.01
## Where a lifted box lies: far from every screen.
const NOWHERE := Rect2(-1.0e7, -1.0e7, 0.0, 0.0)

var _blocks: Array[Rect2] = []  # the bounds of what is placed
var _turns: Array[PackedVector2Array] = []  # beside _blocks: [middle, axis, half] of a turned box, else empty
var _grid: Dictionary[Vector2i, Array] = {}  # grid cell -> indices into _blocks
var _viewport := Vector2.ZERO


## Forgets every box; `viewport` is the screen's size.
func clear(viewport: Vector2) -> void:
	_viewport = viewport
	_blocks.clear()
	_turns.clear()
	_grid.clear()


## How many boxes were added: the number the next one gets.
func size() -> int:
	return _blocks.size()


## Adds a box by its bounds; `turn` ([middle, axis, half]) for a turned box.
func add(bounds: Rect2, turn: PackedVector2Array = PackedVector2Array()) -> void:
	var n := _blocks.size()
	_blocks.append(bounds)
	_turns.append(turn)
	var low := Vector2i((bounds.position / GRID_PX).floor())
	var high := Vector2i((bounds.end / GRID_PX).floor())
	# A box far larger than the screen is entered only where it can be asked for.
	var shown_low := Vector2i((Vector2(-REACH_PX, -REACH_PX) / GRID_PX).floor())
	var shown_high := Vector2i(((_viewport + Vector2(REACH_PX, REACH_PX)) / GRID_PX).floor())
	low = low.clamp(shown_low, shown_high)
	high = high.clamp(shown_low, shown_high)
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if not _grid.has(cell):
				_grid[cell] = []
			_grid[cell].append(n)


## Takes box `n` away for the while.
func lift(n: int) -> void:
	_blocks[n] = NOWHERE


## Puts a lifted box `n` back with the bounds it was added with.
func put_back(n: int, bounds: Rect2) -> void:
	_blocks[n] = bounds


## Whether `box` meets a box added; with `unturned_only`, the turned boxes do not count.
func meets(box: Rect2, unturned_only: bool) -> bool:
	var low := Vector2i((box.position / GRID_PX).floor())
	var high := Vector2i((box.end / GRID_PX).floor())
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			for n: int in _grid.get(Vector2i(x, y), []):
				if not _blocks[n].intersects(box):
					continue
				var turn := _turns[n]
				if turn.is_empty() or (not unturned_only and turned_hits(box, turn[0], turn[1], turn[2])):
					return true
	return false


## Whether the turned box of middle `centre`, long axis `axis` and half size `half` overlaps `box`.
static func turned_hits(box: Rect2, centre: Vector2, axis: Vector2, half: Vector2) -> bool:
	var box_half := box.size * 0.5
	var d := centre - (box.position + box_half)
	var c := absf(axis.x)
	var s := absf(axis.y)
	if absf(d.x) >= box_half.x + half.x * c + half.y * s or absf(d.y) >= box_half.y + half.x * s + half.y * c:
		return false
	var across := Vector2(-axis.y, axis.x)
	return absf(d.dot(axis)) < half.x + box_half.x * c + box_half.y * s \
		and absf(d.dot(across)) < half.y + box_half.x * s + box_half.y * c


## Whether a turned box in map px, its middle at `at`, overlaps the cell of a hex of the map whose byte in `owners`
## (ParchmentView.owner_bytes) is `value` (`equal` true) or is not (`equal` false). A box of no height is a line.
static func over_hexes(owners: PackedByteArray, map: MapData, at: Vector2, axis: Vector2, half: Vector2, value: int,
		equal: bool) -> bool:
	var reach_x := absf(axis.x) * half.x + absf(axis.y) * half.y + 52.0
	var reach_y := absf(axis.y) * half.x + absf(axis.x) * half.y + 51.0
	var first := maxi(0, ceili((at.y - reach_y - 51.0) / MapTiles.ROW))
	var last := mini(map.rows - 1, floori((at.y + reach_y - 51.0) / MapTiles.ROW))
	for row: int in range(first, last + 1):
		var shift := 0.5 + 0.5 * float(row & 1)
		var left := maxi(0, ceili((at.x - reach_x) / MapTiles.CELL.x - shift))
		var right := mini(map.cols - 1, floori((at.x + reach_x) / MapTiles.CELL.x - shift))
		for col: int in range(left, right + 1):
			if (owners[row * map.cols + col] == value) != equal:
				continue
			if _hex_hit(MapTiles.cell_centre(Vector2i(col, row)) - at, axis, half):
				return true
	return false


## Whether a hex cell whose middle is `off` from a turned box's middle overlaps the box (map px): no separating axis
## among the box's two and the cell's three.
static func _hex_hit(off: Vector2, axis: Vector2, half: Vector2) -> bool:
	var across := Vector2(-axis.y, axis.x)
	for line: Vector2 in [axis, across, HEX_NORMALS[0], HEX_NORMALS[1], HEX_NORMALS[2]]:
		var cell := 0.0
		for corner: Vector2 in HEX_CORNERS:
			cell = maxf(cell, absf(corner.dot(line)))
		var box := half.x * absf(axis.dot(line)) + half.y * absf(across.dot(line))
		if absf(off.dot(line)) >= cell + box - TOUCH_PX:
			return false
	return true
