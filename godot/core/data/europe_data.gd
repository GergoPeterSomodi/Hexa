## The inputs of the Europe 1480 map builder, read once from the exported JSON in godot/data (never from Python).
## Plain values: polygons, polylines, the named points and the wave function rules. core/data/ holds loaders only.
## Geometry is float64: a polygon or polyline is a PackedFloat64Array of interleaved x, y (lon, lat) pairs.
class_name EuropeData
extends RefCounted

const GEO_DIR := "res://data/geography/"
const DATA_DIR := "res://data/"

var projection: Dictionary = {}
var land_polygons: Array[PackedFloat64Array] = []  # the 7 landmasses, then the 17 islands (Python's order)
var lakes: Array[PackedFloat64Array] = []
var seas: Array[PackedFloat64Array] = []
var force_sea: PackedFloat64Array = PackedFloat64Array()
var force_land: PackedFloat64Array = PackedFloat64Array()
var mountains: Array[PackedFloat64Array] = []  # the 18 mountain lines (heights are not used by the land builder)
var hills: Array[PackedFloat64Array] = []
var deserts: Array[PackedFloat64Array] = []
var steppes: Array[PackedFloat64Array] = []
var maghreb: Array[PackedFloat64Array] = []
var marshes: Array[PackedFloat64Array] = []  # [lon0, lat0, lon1, lat1, k]
var river_names: PackedStringArray = PackedStringArray()
var rivers: Array[PackedFloat64Array] = []
var pass_names: PackedStringArray = PackedStringArray()
var pass_points: PackedFloat64Array = PackedFloat64Array()  # (lon, lat) of each named pass, in order
var city_names: PackedStringArray = PackedStringArray()
var city_points: PackedFloat64Array = PackedFloat64Array()  # (lon, lat) of each city, in order
var city_sizes: PackedInt32Array = PackedInt32Array()
var land_kinds: PackedStringArray = PackedStringArray()  # terrain kinds with a movement cost (not lake, not ocean)
var forbidden: Array[PackedStringArray] = []  # pairs of terrain kinds that may not touch
var affinity: float = 1.6
var map_seed: int = 1480


static func load_europe() -> EuropeData:
	var data := EuropeData.new()
	data._read_projection()
	data._read_land()
	data._read_shapes()
	data._read_rivers_passes_cities()
	data._read_rules()
	return data


func _read_projection() -> void:
	projection = _read_json(GEO_DIR + "projection.json")


func _read_land() -> void:
	var land := _read_json(GEO_DIR + "land.json")
	for item: Dictionary in _dicts(land["landmasses"]):
		land_polygons.append(_points(item["points"]))
	for item: Dictionary in _dicts(land["islands"]):
		land_polygons.append(_points(item["points"]))
	for item: Dictionary in _dicts(land["lakes"]):
		lakes.append(_points(item["points"]))
	for item: Dictionary in _dicts(land["seas"]):
		seas.append(_points(item["points"]))
	force_sea = _points(land["force_sea"])
	force_land = _points(land["force_land"])


func _read_shapes() -> void:
	var shapes := _read_json(GEO_DIR + "terrain_shapes.json")
	for item: Dictionary in _dicts(shapes["mountains"]):
		mountains.append(_points(item["line"]))
	for line: Array in _arrays(shapes["hills"]):
		hills.append(_points(line))
	for poly: Array in _arrays(shapes["deserts"]):
		deserts.append(_points(poly))
	for poly: Array in _arrays(shapes["steppes"]):
		steppes.append(_points(poly))
	for poly: Array in _arrays(shapes["maghreb"]):
		maghreb.append(_points(poly))
	for item: Dictionary in _dicts(shapes["marshes"]):
		marshes.append(PackedFloat64Array([float(item["lon0"]), float(item["lat0"]), float(item["lon1"]),
				float(item["lat1"]), float(item["k"])]))


func _read_rivers_passes_cities() -> void:
	var river_file := _read_json(GEO_DIR + "rivers.json")
	for item: Dictionary in _dicts(river_file["rivers"]):
		river_names.append(str(item["name"]))
		rivers.append(_points(item["points"]))
	var pass_file := _read_json(GEO_DIR + "passes.json")
	for item: Dictionary in _dicts(pass_file["passes"]):
		pass_names.append(str(item["name"]))
		pass_points.append(float(item["lon"]))
		pass_points.append(float(item["lat"]))
	var city_file := _read_json(GEO_DIR + "cities.json")
	for item: Dictionary in _dicts(city_file["cities"]):
		city_names.append(str(item["name"]))
		city_points.append(float(item["lon"]))
		city_points.append(float(item["lat"]))
		city_sizes.append(int(item["size"]))


func _read_rules() -> void:
	var terrain := _read_json(DATA_DIR + "terrain.json")
	for item: Dictionary in _dicts(terrain["terrain"]):
		if item["move"] != null:
			land_kinds.append(str(item["key"]))
	var wfc := _read_json(DATA_DIR + "wfc.json")
	for pair: Array in _arrays(wfc["forbidden"]):
		forbidden.append(PackedStringArray([str(pair[0]), str(pair[1])]))
	affinity = float(wfc["affinity_in_build_map"])
	var constants := _read_json(DATA_DIR + "constants.json")
	map_seed = int(constants["map_seed"])


static func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "godot/data: cannot read " + path)
	return parsed


static func _dicts(raw: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Variant in raw:
		out.append(item)
	return out


static func _arrays(raw: Array) -> Array[Array]:
	var out: Array[Array] = []
	for item: Variant in raw:
		out.append(item)
	return out


## Interleaved (lon, lat) pairs of a JSON list of [lon, lat] points.
static func _points(raw: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for pair: Array in _arrays(raw):
		out.append(float(pair[0]))
		out.append(float(pair[1]))
	return out
