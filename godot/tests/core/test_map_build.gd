## The map build (tools/build_map.gd, docs/architecture/m1-build-spec.md T6): the committed data/maps/north_italy.tres is
## what the build gives today, twice over, and it says what core/mapgen says; the winter rule is the kit's.
extends GutTest

const BUILD := "res://tools/build_map.gd"
const FILE := "res://data/maps/north_italy.tres"

var _builder: GDScript = null
var _first: Dictionary = {}
var _second: Dictionary = {}


func before_all() -> void:
	_builder = load(BUILD)
	_first = _builder.call("build_files")
	_second = _builder.call("build_files")


func _map(built: Dictionary) -> MapData:
	return built["map"]


func test_the_build_reads() -> void:
	assert_false(_first.has("error"), "the data files read")
	assert_eq(_map(_first).id, "north_italy")
	assert_eq(_map(_first).cols, 21)
	assert_eq(_map(_first).rows, 19)


func test_built_map_validates() -> void:
	assert_eq(_map(_first).validate(), [] as Array[String])


func test_rebuilt_twice_gives_one_digest() -> void:
	assert_eq(_map(_first).digest(), _map(_second).digest())


func test_committed_file_is_the_build() -> void:
	var committed := load(FILE) as MapData
	assert_not_null(committed, "the committed file loads as MapData")
	assert_eq(committed.validate(), [] as Array[String], "the committed file validates")
	assert_eq(committed.digest(), _map(_first).digest(), "the committed file is current: run tools/build_map.gd")


func test_cover_relief_and_land_equal_mapgen() -> void:
	var map := _map(_first)
	var relief: WorldRelief = _first["relief"]
	var cover: WorldCover = _first["cover"]
	var checked := 0
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		if not relief.levels.has(hex):
			continue  # the odd rows' last column repeats its neighbour (build_map.gd)
		checked += 1
		var level := relief.level_at(hex)
		assert_eq(int(map.relief[i]), level, "relief of %s" % hex)
		assert_eq(int(map.land[i]), 1 if level > 0 else 0, "land of %s" % hex)
		if level > 0:
			assert_eq(int(map.cover[i]), cover.cover_at(hex), "cover of %s" % hex)
		else:
			assert_eq(int(map.cover[i]), MapData.COVER_SEA, "sea has no cover at %s" % hex)
	assert_eq(checked, 390, "every hex of the data was compared")


func test_rivers_equal_mapgen() -> void:
	var map := _map(_first)
	var water: WorldWater = _first["water"]
	var counts := [0, 0, 0, 0, 0]
	for e: int in map.river.size():
		counts[map.river[e]] += 1
	assert_eq(counts[1] + counts[2] + counts[3], water.river_edge.size(), "river edges")
	assert_eq(counts[4], water.stream_edge.size(), "stream edges")
	for key: Vector4i in water.river_edge:
		var a := Vector2i(key.x, key.y)
		var b := Vector2i(key.z, key.w)
		var want := int(water.rivers[water.river_edge[key]]["class"])
		assert_eq(map.river_on(a, map.grid().direction_of(a, b)), want, "river on %s" % [key])
		assert_eq(map.river_on(b, map.grid().direction_of(b, a)), want, "river from the other side %s" % [key])
	for key: Vector4i in water.stream_edge:
		if water.river_edge.has(key):
			continue
		var a := Vector2i(key.x, key.y)
		assert_eq(map.river_on(a, map.grid().direction_of(a, Vector2i(key.z, key.w))), 4, "stream on %s" % [key])
	assert_eq(map.rivers.size(), water.rivers.size(), "drawn courses")
	for r: Dictionary in map.rivers:
		assert_gt((r["corners"] as PackedVector2Array).size(), 1, "%s is drawn" % r["name"])


func test_road_edges_and_crossings_equal_mapgen() -> void:
	var map := _map(_first)
	var roads: WorldRoads = _first["roads"]
	var counted := 0
	for e: int in map.road.size():
		if map.road[e] > 0:
			counted += 1
	assert_eq(counted, roads.quality.size(), "road edges")
	for key: Vector4i in roads.quality:
		var a := Vector2i(key.x, key.y)
		var b := Vector2i(key.z, key.w)
		var d := map.grid().direction_of(a, b)
		assert_eq(map.road_on(a, d), roads.quality[key], "road on %s" % [key])
		assert_eq(map.road_on(b, (d + 3) % 6), roads.quality[key], "road from the other side %s" % [key])
		assert_eq(int(map.crossing[map.edge_index(a, d)]), WorldRoads.CROSSING_KINDS.find(roads.crossing_of(key)),
			"crossing on %s" % [key])


func test_crests_passes_and_places_equal_mapgen() -> void:
	var map := _map(_first)
	var relief: WorldRelief = _first["relief"]
	var places: WorldPlaces = _first["places"]
	var crests := 0
	for e: int in map.crest.size():
		crests += map.crest[e]
	assert_eq(crests, relief.crest_edges.size(), "crest edges")
	var settled := 0
	for pl: Dictionary in map.places:
		if int(pl["level"]) >= 1 or int(pl["castle"]) >= 1:
			settled += 1
	assert_eq(settled, places.places.size(), "every place of the generator is on the map")
	for pl: Dictionary in places.places:
		var i := map.index_of(pl["hex"])
		assert_eq(str(map.places[map.place_id[i]]["name"]), str(pl["name"]), "place at %s" % [pl["hex"]])
	assert_gt(map.passes.size(), 10, "the passes are listed")


func test_climate_follows_the_kit() -> void:
	assert_almost_eq(MapClimate.cold_index(44.4, 20.0, 0.5), 0.4302916666666647, 1e-9)
	assert_almost_eq(MapClimate.cold_index(45.1, 120.0, 80.0), 5.216666666666668, 1e-9)
	assert_almost_eq(MapClimate.cold_index(46.3, 2500.0, 200.0), 14.15, 1e-9)
	assert_almost_eq(MapClimate.cold_index(45.5, 400.0, MapClimate.FAR_INLAND_KM), 7.416666666666666, 1e-9)
	assert_eq(MapClimate.winter_of(44.4, 20.0, 0.5), MapClimate.MILD)
	assert_eq(MapClimate.winter_of(45.1, 120.0, 80.0), MapClimate.FROST)
	assert_eq(MapClimate.winter_of(46.3, 2500.0, 200.0), MapClimate.SNOW)
	assert_eq(MapClimate.winter_of(46.0, 900.0, 60.0), MapClimate.SNOW)
	assert_eq(MapClimate.winter_of(43.8, 300.0, 10.0), MapClimate.MILD)
	assert_eq(MapClimate.km_to_lines(Vector2(0.0, 3.0), [PackedVector2Array([Vector2(-5, 0), Vector2(5, 0)])] as Array[PackedVector2Array]), 3.0)
	assert_eq(MapClimate.km_to_lines(Vector2.ZERO, [] as Array[PackedVector2Array]), MapClimate.FAR_INLAND_KM)


func test_climate_of_the_map_has_all_three_winters() -> void:
	var map := _map(_first)
	var counts := [0, 0, 0]
	for i: int in map.hex_count():
		if map.land[i] == 1:
			counts[map.climate[i]] += 1
	assert_gt(counts[MapClimate.SNOW], 10, "the Alps are snow")
	assert_gt(counts[MapClimate.FROST], 10, "the plain is frost")
	assert_gt(counts[MapClimate.MILD], 3, "the Ligurian coast is mild")
	var genoa := map.index_of(_hex_of_place(map, "Genoa"))
	assert_eq(int(map.climate[genoa]), MapClimate.MILD, "Genoa")


func test_shoreline_and_height_grid_are_stored() -> void:
	var map := _map(_first)
	assert_gt(map.shoreline.size(), 0, "a shoreline")
	assert_eq(map.height_grid_size, Vector2i(87, 68))
	assert_eq(map.height_grid.size(), 87 * 68)
	var points := 0
	for line: PackedVector2Array in map.shoreline:
		points += line.size()
	assert_gt(points, 100, "the coast has detail")


static func _hex_of_place(map: MapData, place_name: String) -> Vector2i:
	for pl: Dictionary in map.places:
		if str(pl["name"]) == place_name:
			return pl["hex"]
	return Vector2i(-1, -1)
