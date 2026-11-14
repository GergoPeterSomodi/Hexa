## The map the builder makes: one kind per grid hex (a land kind, "ocean" or "lake"), the rivers, the crest (ridge)
## edges and the passes. Plain data. Step 2 (provinces, countries, towns, castles, roads) adds its own fields here,
## filled by functions in map_builder.gd after the ridges and passes.
class_name MapData
extends RefCounted

const OCEAN := "ocean"
const LAKE := "lake"

var cols: int = 0
var rows: int = 0
var map_seed: int = 0
var terrain: Dictionary[Vector2i, String] = {}  # every grid hex, in row-major insertion order
var rivers: Dictionary = {}  # river name -> Array[Vector2i]; only rivers of 3 hexes or more
var river_at: Dictionary[Vector2i, String] = {}  # hex -> the first river through it
var sea_body: Dictionary[Vector2i, int] = {}  # ocean hex -> number of its connected sea
var city_names: Dictionary[Vector2i, String] = {}  # land hex -> city name
var city_sizes: Dictionary[Vector2i, int] = {}
var ridge_edges: Dictionary[Vector4i, bool] = {}  # crest edges no army crosses (HexGrid.edge_key)
var pass_names: Dictionary[Vector4i, String] = {}  # open crest edges (passes) -> name
var pass_ids: Dictionary[Vector4i, int] = {}
var pass_hexes: Dictionary[Vector2i, String] = {}  # hexes at the ends of a pass edge -> pass name


func has_hex(pos: Vector2i) -> bool:
	return terrain.has(pos)


func is_land(pos: Vector2i) -> bool:
	if not terrain.has(pos):
		return false
	var kind: String = terrain[pos]
	return kind != OCEAN and kind != LAKE


## Land hexes in row-major order.
func land_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos: Vector2i in terrain.keys():
		if is_land(pos):
			out.append(pos)
	return out


## Land hexes with an ocean hex next to them (a coastal province in Python: Province.coastal).
func coastal_land() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos: Vector2i in land_hexes():
		for n: Vector2i in HexGrid.neighbours(pos):
			if terrain.has(n) and terrain[n] == OCEAN:
				out.append(pos)
				break
	return out


## {"land": n, "ocean": n, "lake": n}
func class_counts() -> Dictionary:
	var counts := {"land": 0, "ocean": 0, "lake": 0}
	for pos: Vector2i in terrain.keys():
		var kind: String = terrain[pos]
		if kind == OCEAN:
			counts["ocean"] = int(counts["ocean"]) + 1
		elif kind == LAKE:
			counts["lake"] = int(counts["lake"]) + 1
		else:
			counts["land"] = int(counts["land"]) + 1
	return counts


## Land hexes per land kind.
func terrain_counts() -> Dictionary:
	var counts: Dictionary = {}
	for pos: Vector2i in land_hexes():
		var kind: String = terrain[pos]
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts
