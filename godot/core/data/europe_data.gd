## The inputs of the Europe 1480 map builder, read once from the exported JSON in godot/data (never from Python).
## Plain values: polygons, polylines, the named points, the wave function rules, and (step 2) the people, country,
## place-name and unit tables. core/data/ holds loaders only.
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
var fertile_river: PackedFloat64Array = PackedFloat64Array()  # the first fertile river (Python FERTILE_RIVERS[0])
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
var scale: int = 2
var territory_radius: int = 8  # hexes: a starting country owns land this close to one of its seeds
var settlement_pop: int = 6  # thousand people a village needs (buildings.json settlements, level 1)
var terrain_move: Dictionary = {}  # land kind -> movement cost
var terrain_density: Dictionary = {}  # every kind -> people per hex, in thousands (already divided by area)
var works_goods: PackedStringArray = PackedStringArray()  # the goods that can have works (buildings.json works)
var unit_hp: Dictionary = {}  # unit kind -> hit points
var unit_moves: Dictionary = {}  # unit kind -> moves a turn
var troop_keys: Dictionary = {}  # "branch/era" -> the troop's kind key (troop(branch, era) in data.py)
var war_kinds: PackedStringArray = PackedStringArray()  # the nine war units
var stack_base: int = 6
var stack_general: int = 2
var stack_civilian: int = 3
# Countries, in geo.COUNTRIES order (countries.json and geography/countries.json agree on the order).
var country_tags: PackedStringArray = PackedStringArray()
var country_names: PackedStringArray = PackedStringArray()
var country_colours: Array[Color] = []
var country_capitals: PackedFloat64Array = PackedFloat64Array()  # (lon, lat) of each capital
var country_seeds: Array[PackedFloat64Array] = []  # the territory seed points of each country, capital first
var colonial_start: Dictionary = {}  # tag -> turn the country starts colonising (missing: none)
var tribe_names: PackedStringArray = PackedStringArray()  # the 56 native peoples
var tribe_points: PackedFloat64Array = PackedFloat64Array()
var region_names: PackedStringArray = PackedStringArray()  # the 684 historical regions
var region_points: PackedFloat64Array = PackedFloat64Array()
var region_tags: PackedStringArray = PackedStringArray()  # the country that held it ("" when none)
var city_region: Dictionary = {}  # city name -> region name
var place_names: PackedStringArray = PackedStringArray()  # the 6,940 real places, biggest first
var place_points: PackedFloat64Array = PackedFloat64Array()
var exonyms: Dictionary = {}  # modern name -> the name of 1480
var name_skip: PackedStringArray = PackedStringArray()  # places that are districts of a bigger town
var compass: PackedStringArray = PackedStringArray()
var own_weight: float = 0.7
var sea_penalty: float = 10.0
var anchor_cell: float = 4.0  # degrees per bucket of the anchor grid
var land_words: Dictionary = {}  # land kind -> PackedStringArray of descriptions
var coast_words: PackedStringArray = PackedStringArray()
var river_words: PackedStringArray = PackedStringArray()


static func load_europe() -> EuropeData:
	var data := EuropeData.new()
	data._read_projection()
	data._read_land()
	data._read_shapes()
	data._read_rivers_passes_cities()
	data._read_rules()
	data._read_people()
	data._read_countries()
	data._read_names()
	data._read_units()
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
	var fertile: Array = shapes["fertile_rivers"]
	fertile_river = _points(fertile[0])


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
			terrain_move[str(item["key"])] = float(item["move"])
		terrain_density[str(item["key"])] = float(item["density"])
	var wfc := _read_json(DATA_DIR + "wfc.json")
	for pair: Array in _arrays(wfc["forbidden"]):
		forbidden.append(PackedStringArray([str(pair[0]), str(pair[1])]))
	affinity = float(wfc["affinity_in_build_map"])
	var constants := _read_json(DATA_DIR + "constants.json")
	map_seed = int(constants["map_seed"])
	scale = int(constants["scale"])
	territory_radius = int(constants["territory_radius"])
	var buildings := _read_json(DATA_DIR + "buildings.json")
	var settlements: Array = buildings["settlements"]
	settlement_pop = int((settlements[1] as Dictionary)["pop"])
	var works: Dictionary = buildings["works"]
	for good: String in (works["level_names"] as Dictionary).keys():
		works_goods.append(good)


## The province tables of step 2: the native peoples, the historical regions and the real places.
func _read_people() -> void:
	var tribe_file := _read_json(GEO_DIR + "tribes.json")
	for item: Dictionary in _dicts(tribe_file["tribes"]):
		tribe_names.append(str(item["name"]))
		tribe_points.append(float(item["lon"]))
		tribe_points.append(float(item["lat"]))
	var region_file := _read_json(GEO_DIR + "regions.json")
	for item: Dictionary in _dicts(region_file["regions"]):
		region_names.append(str(item["name"]))
		region_points.append(float(item["lon"]))
		region_points.append(float(item["lat"]))
		region_tags.append("" if item["tag"] == null else str(item["tag"]))
	city_region = region_file["city_region"]
	var place_file := _read_json(GEO_DIR + "placenames.json")
	for row: Array in _arrays(place_file["places"]):
		place_points.append(float(row[0]))
		place_points.append(float(row[1]))
		place_names.append(str(row[2]))


func _read_countries() -> void:
	var listed := _read_json(DATA_DIR + "countries.json")
	var seeds_file := _read_json(GEO_DIR + "countries.json")
	var seeds_by_tag: Dictionary = {}
	for item: Dictionary in _dicts(seeds_file["countries"]):
		seeds_by_tag[str(item["tag"])] = _points(item["seeds"])
	for item: Dictionary in _dicts(listed["countries"]):
		var tag := str(item["tag"])
		country_tags.append(tag)
		country_names.append(str(item["name"]))
		var colour: Array = item["colour"]
		country_colours.append(Color8(int(colour[0]), int(colour[1]), int(colour[2])))
		var capital: Dictionary = item["capital"]
		country_capitals.append(float(capital["lon"]))
		country_capitals.append(float(capital["lat"]))
		country_seeds.append(seeds_by_tag[tag])
	var starts: Dictionary = listed["colonial_start"]
	for tag: String in starts.keys():
		colonial_start[tag] = int(starts[tag])


func _read_names() -> void:
	var naming := _read_json(GEO_DIR + "naming.json")
	compass = _strings(naming["compass"])
	own_weight = float(naming["own_weight"])
	sea_penalty = float(naming["sea_penalty"])
	anchor_cell = float(naming["anchor_cell_degrees"])
	var names: Dictionary = naming["exonyms"]
	for modern: String in names.keys():
		exonyms[modern] = str(names[modern])
	name_skip = _strings(naming["skip"])
	var words: Dictionary = naming["land_words"]
	for kind: String in words.keys():
		land_words[kind] = _strings(words[kind])
	coast_words = _strings(naming["coast_words"])
	river_words = _strings(naming["river_words"])


func _read_units() -> void:
	var units := _read_json(DATA_DIR + "units.json")
	for item: Dictionary in _dicts(units["unit_kinds"]):
		unit_hp[str(item["key"])] = int(item["hp"])
		unit_moves[str(item["key"])] = float(item["moves"])
	for item: Dictionary in _dicts(units["troops"]):
		var key := str(item["key"])
		troop_keys["%s/%d" % [str(item["branch"]), int(item["era"])]] = key
		war_kinds.append(key)
	var stack: Dictionary = units["stack"]
	stack_base = int(stack["base"])
	stack_general = int(stack["general"])
	stack_civilian = int(stack["civilian"])


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


static func _strings(raw: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for item: Variant in raw:
		out.append(str(item))
	return out


## Interleaved (lon, lat) pairs of a JSON list of [lon, lat] points.
static func _points(raw: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for pair: Array in _arrays(raw):
		out.append(float(pair[0]))
		out.append(float(pair[1]))
	return out
