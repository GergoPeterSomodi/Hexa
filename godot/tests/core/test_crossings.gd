## The crossing tiles (core/views/crossings.gd, baked by tools/worldmap/tileset_bake/mark_tiles.py): the name of the tile on
## every edge with a crossing, and the bake holding every name a map can ask for in all six sets (crossings and the
## landmark variants of the settlements, which MapCells names for any level of a place that carries one).
extends GutTest

const ROOT := "res://assets/tiles/"
const MAP_PATH := "res://data/maps/north_italy.tres"


func _tile_names(set_name: String) -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + set_name + "/index.json"))
	var index: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var sources: Array = index.get("sources", [])
	for entry: Variant in sources:
		var source: Dictionary = entry
		var tiles: Array = source["tiles"]
		for row: Variant in tiles:
			var tile: Dictionary = row
			out[str(tile["name"])] = true
	return out


func test_names() -> void:
	assert_eq(Crossings.tile_name(1, 0), "mark/ford/0")
	assert_eq(Crossings.tile_name(2, 1), "mark/bridge_wood/1")
	assert_eq(Crossings.tile_name(3, 2), "mark/bridge_stone/2")
	assert_eq(Crossings.tile_name(4, 5), "mark/ferry/5")
	assert_eq(Crossings.tile_name(5, 3), "mark/pass/3")
	assert_eq(Crossings.tile_name(0, 0), "")
	assert_eq(Crossings.tile_name(6, 0), "")
	assert_eq(Crossings.tile_name(1, 6), "")
	assert_eq(Crossings.all_names().size(), 30)


func test_a_hex_names_the_crossings_on_its_three_owned_edges() -> void:
	var map := MapData.new()
	map.allocate(4, 3)
	var hex := Vector2i(1, 1)
	map.crossing[map.edge_index(hex, 0)] = 3  # a stone bridge on its east edge
	map.crossing[map.edge_index(hex, 2)] = 1  # a ford on its north-west edge
	var out := Crossings.of_hex(map, hex)
	assert_eq(out, {"crossing0": "mark/bridge_stone/0", "crossing1": "", "crossing2": "mark/ford/2"})
	# the edge in direction 3 is the east edge of the west neighbour: that hex holds the tile
	map.crossing[map.edge_index(hex, 3)] = 2
	assert_eq(Crossings.of_hex(map, hex)["crossing0"], "mark/bridge_stone/0", "the neighbour's edge is not this hex's")
	assert_eq(Crossings.of_hex(map, Vector2i(0, 1))["crossing0"], "mark/bridge_wood/0")
	assert_eq(Crossings.of_hex(map, Vector2i(3, 2)), {"crossing0": "", "crossing1": "", "crossing2": ""})


func test_every_crossing_is_named_once() -> void:
	var map := MapData.new()
	map.allocate(5, 4)
	for hex: Vector2i in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(4, 3)]:
		for d: int in 3:
			map.crossing[map.edge_index(hex, d)] = 1 + d
	var all := Crossings.all_of(map)
	assert_eq(all.size(), 9)
	for entry: Dictionary in all:
		var of_hex := Crossings.of_hex(map, entry["hex"] as Vector2i)
		assert_eq(of_hex[Crossings.LAYERS[int(entry["d"])]], entry["tile"])


func test_north_italy_crossings_are_in_the_bake_of_every_set() -> void:
	var map := load(MAP_PATH) as MapData
	assert_not_null(map)
	assert_gt(Crossings.all_of(map).size(), 0, "the map has crossings")
	for set_name: String in TilesetBuilder.ALL_SETS:
		var names := _tile_names(set_name)
		for tile_name: String in Crossings.all_names():
			assert_true(names.has(tile_name), "%s has %s" % [set_name, tile_name])


func test_landmark_settlements_have_tiles_at_every_level() -> void:
	var map := load(MAP_PATH) as MapData
	var landmarks: Dictionary[String, bool] = {}
	for place: Dictionary in map.places:
		var landmark := str(place.get("landmark", ""))
		if landmark != "":
			landmarks[landmark] = true
	assert_gt(landmarks.size(), 0)
	for set_name: String in TilesetBuilder.ALL_SETS:
		var names := _tile_names(set_name)
		for landmark: String in landmarks:
			for level: int in range(1, 6):
				for variant: int in 2:
					for mirror: bool in [false, true]:
						for part: String in ["ground", "front"]:
							var tile_name := MapTiles.piece("settlements", level, variant, mirror, landmark, part)
							assert_true(names.has(tile_name), "%s has %s" % [set_name, tile_name])
