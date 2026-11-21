## Helpers of the step-cost and path-search tests (docs/architecture/m6-build-spec.md section 9, task L3): a small open map built
## fresh in each test (never a shared map), a copy of the committed defs that a planted fault may edit (a duplicate, never the
## cached resource), and the hex lists the asserts read.
class_name PathFixture
extends RefCounted

const COLS := 9
const ROWS := 7


## A 9 x 7 map of land: every hex farmland, relief 0, climate temperate (2), no edge marks.
static func open_map() -> MapData:
	var map := MapData.new()
	map.allocate(COLS, ROWS)
	map.land.fill(1)
	map.cover.fill(0)
	map.climate.fill(2)
	return map


## A mask with every hex allowed.
static func allowed_all(map: MapData) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(map.hex_count())
	mask.fill(1)
	return mask


## A mask of the land hexes of `map`.
static func allowed_land(map: MapData) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(map.hex_count())
	for i: int in map.hex_count():
		mask[i] = map.land[i]
	return mask


## A duplicate of the committed defs (sub-resources included): a planted fault edits this copy only.
static func defs_copy() -> GameDefs:
	return EconomyFixture.committed().duplicate(true) as GameDefs


## The hex coordinates of a list of hex indices, in the same order.
static func hexes(map: MapData, indices: PackedInt32Array) -> Array:
	var out: Array = []
	for i: int in indices:
		out.append(map.hex_of(i))
	return out


## The edges that cross from column `col` to column `col + 1`: direction 0 from every row, and directions 1 and 5 from the
## odd rows (an odd row is shifted right). A wall between two columns must mark all of them, or a route goes round it.
static func boundary(map: MapData, col: int) -> Array:
	var out: Array = []
	for r: int in map.rows:
		var hex := Vector2i(col, r)
		out.append([hex, 0])
		if (r & 1) == 1:
			out.append([hex, 1])
			out.append([hex, 5])
	return out


## Sets one per-edge mark of the edge of `hex` in direction `d`: `field` is &"river", &"crest", &"pass_edge", &"road" or
## &"crossing". (The arrays are written through the map: a PackedByteArray passed as an argument would be a copy.)
static func set_edge(map: MapData, hex: Vector2i, d: int, field: StringName, value: int) -> void:
	var e := map.edge_index(hex, d)
	match field:
		&"river":
			map.river[e] = value
		&"crest":
			map.crest[e] = value
		&"pass_edge":
			map.pass_edge[e] = value
		&"road":
			map.road[e] = value
		&"crossing":
			map.crossing[e] = value
		_:
			assert(false, "PathFixture.set_edge: unknown field %s" % String(field))
