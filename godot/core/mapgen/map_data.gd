## The map the builder makes. Step 1: one kind per grid hex (a land kind, "ocean" or "lake"), the rivers, the crest
## (ridge) edges and the passes. Step 2: the provinces (one per land hex), the countries, roads and starting units.
## Plain data, filled by the functions of map_builder.gd in order. The field names are the contract the map view
## reads; they are listed in godot/README.md ("MapData fields") and do not change without a note there.
class_name MapData
extends RefCounted

const OCEAN := "ocean"
const LAKE := "lake"

# ----- step 1: the land layers -------------------------------------------------------------------------------------
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

# ----- step 2: provinces, countries, roads, starting units ------------------------------------------------------------
var provinces: Dictionary[Vector2i, Province] = {}  # every land hex, in (column, row) order (Python world.provinces)
var landmass: Dictionary[Vector2i, int] = {}  # land hex -> its landmass number (1, 2, ... in province order)
var countries: Dictionary[String, Country] = {}  # country tag -> Country
var country_order: Array[String] = []  # the tags in geo.COUNTRIES order
var roads: Dictionary[Vector2i, bool] = {}  # every hex on a road (towns and capitals joined)
var road_paths: Array[Array] = []  # each road: an Array of Vector2i from its town to the network it joined
var units: Array[Unit] = []  # the starting units, in the order they were placed


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


## The province of a land hex, or null.
func province(pos: Vector2i) -> Province:
	return provinces.get(pos) as Province


## The provinces a country owns at the start, in province order.
func provinces_of(tag: String) -> Array[Province]:
	var out: Array[Province] = []
	for prov: Province in provinces.values():
		if prov.owner == tag:
			out.append(prov)
	return out


## The people of a country's provinces (Python world.total_pop).
func total_pop(tag: String) -> float:
	var sum := 0.0
	for prov: Province in provinces_of(tag):
		sum += prov.pop()
	return sum


## The starting units standing on a hex.
func units_at(pos: Vector2i) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit: Unit in units:
		if unit.pos == pos:
			out.append(unit)
	return out


## True when a step between two neighbouring hexes crosses a ridge no army crosses (a wall in every season).
func is_ridge_step(a: Vector2i, b: Vector2i) -> bool:
	return ridge_edges.has(HexGrid.edge_key(a, b))
