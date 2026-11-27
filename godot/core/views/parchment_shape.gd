## The parchment map's hand-drawn geometry (docs/architecture/map-overview-build-spec.md R3, R5, D3 and section 4): the
## wobbled corners and edge middles of every hex, the edges between the hexes and the mountain marks, all in map px.
## It is made once a map and knows nothing of owners or of the fog: the shell hides what the viewer has not discovered by
## the bytes of ParchmentView, which index the same hexes (row * cols + col).
## Pure core/views/ code: no nodes, no engine calls, no luck (an integer hash of a point's own position).
class_name ParchmentShape
extends RefCounted

## How far a corner moves, at most, along each axis (map px).
const CORNER_WOBBLE_PX := 10.0
## How far an edge's middle moves, at most, along the edge's normal (map px).
const MIDDLE_WOBBLE_PX := 9.0
## A land hex higher than this (m) has a mountain mark; higher than MOUNTAIN_BIG_M, a larger one.
const MOUNTAIN_M := 1400
const MOUNTAIN_BIG_M := 2400
## The points of one hex's polygon: corner 0, the middle of edge 0-1, corner 1, ... the middle of edge 5-0.
const POLYGON_POINTS := 12
## The points of one edge: a corner, the middle, the next corner.
const EDGE_POINTS := 3
## The points of one mountain mark's zig-zag.
const MOUNTAIN_POINTS := 5
## The foot of a mark's zig-zag from its cell centre (map px), and the zig-zag from that foot (the mockup's, at 104 px).
const MOUNTAIN_FOOT := Vector2(0.0, 12.5)
const MOUNTAIN_ZIGZAG: Array[Vector2] = [Vector2(-27.0, 0.0), Vector2(-11.0, -27.0), Vector2(0.0, -10.5),
	Vector2(9.0, -23.5), Vector2(27.0, 0.0)]
const MOUNTAIN_BIG_SCALE := 1.25

## COAST: a land hex against a sea hex. LAND: two land hexes, or a land hex against the edge of the map.
enum Edge { COAST, LAND }

## The corner lattice (map px a step): half a cell across and a quarter of a cell down, so every corner of every hex is a
## whole number of steps, the same from each hex that holds it.
const _STEP_X := 52.0  # MapTiles.CELL.x / 2
const _STEP_Y := 25.5  # MapTiles.CELL.y / 4
## The six corners from a cell's centre, in lattice steps, in HexGrid corner order (0 top, then clockwise on screen).
const _CORNERS: Array[Vector2i] = [Vector2i(0, -2), Vector2i(1, -1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 1),
	Vector2i(-1, -1)]
const _MASK := 0xFFFFFFFF


## A number in [0, 1) for two whole numbers, the same on every machine: 32-bit integer mixing, no product past 63 bits.
static func hash01(x: int, y: int) -> float:
	return float(_hash32(x, y)) / 4294967296.0


## Corner `k` (HexGrid order, 0 top) of a hex in map px, moved by the hash of its own lattice point: every hex that
## shares the corner gets the same point.
static func corner(hex: Vector2i, k: int) -> Vector2:
	var step := _CORNERS[posmod(k, 6)]
	return _point(2 * hex.x + 1 + (hex.y & 1) + step.x, 2 + 3 * hex.y + step.y)


## The middle of the edge between two (wobbled) corners, moved along the edge's normal by the hash of its own position:
## the same point for (a, b) and (b, a).
static func middle(a: Vector2, b: Vector2) -> Vector2:
	var p := a
	var q := b
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		p = b
		q = a
	var mid := (p + q) * 0.5
	var along := q - p
	var offset := (float(_hash32(roundi(mid.x), roundi(mid.y))) / 2147483648.0 - 1.0) * MIDDLE_WOBBLE_PX
	return mid + Vector2(-along.y, along.x).normalized() * offset


## The outline of a hex: POLYGON_POINTS points, corner 2k at index 2k and the middle of edge k to k + 1 after it,
## clockwise on screen. It is star-shaped about MapTiles.cell_centre(hex), so a fan from the centre fills it.
static func polygon(hex: Vector2i) -> PackedVector2Array:
	var ux := 2 * hex.x + 1 + (hex.y & 1)
	var uy := 2 + 3 * hex.y
	var c0 := _point(ux, uy - 2)
	var c1 := _point(ux + 1, uy - 1)
	var c2 := _point(ux + 1, uy + 1)
	var c3 := _point(ux, uy + 2)
	var c4 := _point(ux - 1, uy + 1)
	var c5 := _point(ux - 1, uy - 1)
	return PackedVector2Array([c0, middle(c0, c1), c1, middle(c1, c2), c2, middle(c2, c3), c3, middle(c3, c4), c4,
		middle(c4, c5), c5, middle(c5, c0)])


## The edges with land on a side that belong to the hexes of rows rows.x up to, not with, rows.y. Rows that cover the
## map once give every such edge once (an edge belongs to the hex that has it as E, NE or NW; an edge of the map's rim
## to its only hex). {points: PackedVector2Array, EDGE_POINTS an edge; a, b: PackedInt32Array, hex indexes;
## kind: PackedByteArray, an Edge}. A COAST edge has the land hex as `a` and the sea hex as `b`; a LAND edge has two
## land hexes, or b -1 on the rim of the map. The points run clockwise round hex `a`: `a` lies right of their course
## on screen, and they are three points of polygon(a).
static func edges(map: MapData, rows: Vector2i) -> Dictionary:
	var points := PackedVector2Array()
	var a := PackedInt32Array()
	var b := PackedInt32Array()
	var kind := PackedByteArray()
	if map != null:
		var cols := map.cols
		var land := map.land
		for row: int in range(maxi(rows.x, 0), mini(rows.y, map.rows)):
			for col: int in cols:
				var i := row * cols + col
				var ring := Economy.ring_of(map, i)
				var here := land[i] == 1
				var ux := 2 * col + 1 + (row & 1)
				var uy := 2 + 3 * row
				for d: int in 6:
					var j := ring[d]
					if j >= 0 and d >= MapData.OWNED_EDGES:
						continue  # the neighbour's own edge
					var there := j >= 0 and land[j] == 1
					if not here and not there:
						continue
					# Only this edge's two corners and middle, as polygon() makes them (a whole outline a hex is too slow
					# on a large map).
					var ends := HexGrid.EDGE_CORNERS[d]
					var from := _point(ux + _CORNERS[ends.x].x, uy + _CORNERS[ends.x].y)
					var to := _point(ux + _CORNERS[ends.y].x, uy + _CORNERS[ends.y].y)
					var mid := middle(from, to)
					if here:
						points.append(from)
						points.append(mid)
						points.append(to)
						a.append(i)
						b.append(j)
						kind.append(Edge.LAND if there or j < 0 else Edge.COAST)
					else:  # the land is the neighbour: its course round it is ours backwards
						points.append(to)
						points.append(mid)
						points.append(from)
						a.append(j)
						b.append(i)
						kind.append(Edge.COAST)
	return {"points": points, "a": a, "b": b, "kind": kind}


## The mountain marks of the land hexes of rows rows.x up to, not with, rows.y, in hex index order: {points:
## PackedVector2Array, MOUNTAIN_POINTS a mark (a polyline); hex: PackedInt32Array; big: PackedByteArray, 1 above
## MOUNTAIN_BIG_M}.
static func mountains(map: MapData, rows: Vector2i) -> Dictionary:
	var points := PackedVector2Array()
	var hexes := PackedInt32Array()
	var big := PackedByteArray()
	if map != null:
		var cols := map.cols
		var land := map.land
		var heights := map.height_m
		for i: int in range(maxi(rows.x, 0) * cols, mini(rows.y, map.rows) * cols):
			if land[i] == 0 or heights[i] <= MOUNTAIN_M:
				continue
			var large := heights[i] > MOUNTAIN_BIG_M
			var foot := MapTiles.cell_centre(map.hex_of(i)) + MOUNTAIN_FOOT
			var scale := MOUNTAIN_BIG_SCALE if large else 1.0
			for step: Vector2 in MOUNTAIN_ZIGZAG:
				points.append(foot + step * scale)
			hexes.append(i)
			big.append(1 if large else 0)
	return {"points": points, "hex": hexes, "big": big}


## The corner at lattice point (ux, uy), moved along each axis by its own half of the point's hash.
static func _point(ux: int, uy: int) -> Vector2:
	var h := _hash32(ux, uy)
	return Vector2(float(ux) * _STEP_X + (float(h & 0xFFFF) / 32768.0 - 1.0) * CORNER_WOBBLE_PX,
		float(uy) * _STEP_Y + (float(h >> 16) / 32768.0 - 1.0) * CORNER_WOBBLE_PX)


static func _hash32(x: int, y: int) -> int:
	var h := ((x & _MASK) * 0x27D4EB2D + (y & _MASK) * 0x165667B1 + 0x61C88647) & _MASK
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & _MASK
	h = ((h ^ (h >> 12)) * 0x297A2D39) & _MASK
	return h ^ (h >> 15)
