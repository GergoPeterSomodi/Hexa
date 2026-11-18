## Country border ink lines and inner tinted bands for one chunk of the map
## (docs/architecture/m2-build-spec.md sections 4.6, 5.7, and 6.3).
## Pure core/views/ code: no nodes, no engine calls, deterministic on MapData and owner bytes.
class_name BorderLines
extends RefCounted

const INK := Color("#1c140d", 0.85)
const INK_WIDTH := 2.4
const BAND_DEPTH := 7.0
const BAND_ALPHA := 0.85

## Offsets of the six hex corners from MapTiles.cell_centre(hex) in map px:
## 0 top, 1 upper right, 2 lower right, 3 bottom, 4 lower left, 5 upper left (matches HexGrid.EDGE_CORNERS).
const HEX_CORNERS: Array[Vector2] = [
	Vector2(0.0, -51.0),
	Vector2(52.0, -25.5),
	Vector2(52.0, 25.5),
	Vector2(0.0, 51.0),
	Vector2(-52.0, 25.5),
	Vector2(-52.0, -25.5),
]


## The six corners of `hex` in map px (in HexGrid corner order 0..5).
static func hex_corners(hex: Vector2i) -> PackedVector2Array:
	var centre := MapTiles.cell_centre(hex)
	var out := PackedVector2Array()
	out.resize(6)
	for k: int in 6:
		out[k] = centre + HEX_CORNERS[k]
	return out


## Border ink lines and inner country bands for one chunk (EdgeLines.CHUNK cells a side).
## Only visits each hex's three owned edges (E, NE, NW) so no edge is emitted twice across chunk seams.
static func for_chunk(map: MapData, owner: PackedByteArray, chunk: Vector2i, palette: PackedColorArray) -> Array[Dictionary]:
	if map == null or owner.size() != map.hex_count():
		return []
	var x0 := maxi(chunk.x * EdgeLines.CHUNK, 0)
	var x1 := mini((chunk.x + 1) * EdgeLines.CHUNK, map.cols)
	var y0 := maxi(chunk.y * EdgeLines.CHUNK, 0)
	var y1 := mini((chunk.y + 1) * EdgeLines.CHUNK, map.rows)
	if x0 >= x1 or y0 >= y1:
		return []
	var out: Array[Dictionary] = []
	for row: int in range(y0, y1):
		for col: int in range(x0, x1):
			var hex := Vector2i(col, row)
			var idx := row * map.cols + col
			if map.land[idx] == 0:
				continue
			var own_a := int(owner[idx])
			var centre_a := MapTiles.cell_centre(hex)
			for d: int in MapData.OWNED_EDGES:
				var other := map.neighbour(hex, d)
				var other_idx := map.index_of(other)
				if other_idx < 0 or map.land[other_idx] == 0:
					continue
				var own_b := int(owner[other_idx])
				if own_a == own_b:
					continue
				var pair := HexGrid.EDGE_CORNERS[d]
				var p0 := centre_a + HEX_CORNERS[pair.x]
				var p1 := centre_a + HEX_CORNERS[pair.y]
				out.append({
					"kind": "border",
					"points": PackedVector2Array([p0, p1]),
					"width": INK_WIDTH,
					"colour": INK,
				})
				if own_a > 0 and own_a < palette.size():
					out.append(_band(p0, p1, centre_a, palette[own_a]))
				if own_b > 0 and own_b < palette.size():
					out.append(_band(p1, p0, MapTiles.cell_centre(other), palette[own_b]))
	return out


## The chunks to rebuild when ownership changes on `hexes`: each hex's chunk and its six neighbours' chunks.
static func chunks_touched(map: MapData, hexes: Array[Vector2i]) -> Array[Vector2i]:
	if map == null:
		return []
	var seen: Dictionary[Vector2i, bool] = {}
	for hex: Vector2i in hexes:
		if not map.has(hex):
			continue
		seen[EdgeLines.chunk_of(hex)] = true
		for d: int in 6:
			var other := map.neighbour(hex, d)
			if map.has(other):
				seen[EdgeLines.chunk_of(other)] = true
	var out: Array[Vector2i] = []
	out.assign(seen.keys())
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


static func _band(p0: Vector2, p1: Vector2, centre: Vector2, base: Color) -> Dictionary:
	var inner0 := p0 + (centre - p0).normalized() * BAND_DEPTH
	var inner1 := p1 + (centre - p1).normalized() * BAND_DEPTH
	var edge_col := Color(base, BAND_ALPHA)
	var inner_col := Color(base, 0.0)
	return {
		"kind": "border_band",
		"polygon": PackedVector2Array([p0, p1, inner1, inner0]),
		"colours": PackedColorArray([edge_col, edge_col, inner_col, inner_col]),
	}
