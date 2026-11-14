## Terrain names and colours from godot/data/terrain.json, the far-map colours, and the hover text on a fixture.
extends GutTest

var _style: TerrainStyle
var _map: MapData


func before_all() -> void:
	_style = TerrainStyle.load_default()


func before_each() -> void:
	_map = MapData.new()
	_map.cols = 3
	_map.rows = 2
	for r in 2:
		for c in 3:
			_map.terrain[Vector2i(c, r)] = "plains"
	_map.terrain[Vector2i(0, 0)] = MapData.OCEAN
	_map.terrain[Vector2i(2, 1)] = MapData.LAKE


func test_names_and_colours_load() -> void:
	assert_eq(_style.terrain_name("plains"), "Farmland", "name from terrain.json")
	assert_true(_style.colours.has("ocean"), "ocean colour")
	assert_true(_style.colours.has("lake"), "lake colour")
	assert_eq(_style.colours.size(), 15, "fifteen kinds, lake and ocean included")


func test_far_colours_are_one_per_hex_in_row_order() -> void:
	var colours := _style.far_colours(_map, false)
	assert_eq(colours.size(), 6, "one per hex")
	assert_eq(colours[0], _style.colours["ocean"], "ocean at (0, 0)")
	assert_eq(colours[1], _style.colours["plains"], "plains at (1, 0)")
	assert_eq(colours[5], _style.colours["lake"], "lake at (2, 1)")


func test_countries_fall_back_to_terrain_without_owners() -> void:
	assert_eq(_style.far_colours(_map, true), _style.far_colours(_map, false),
			"no owners in MapData yet: the countries map shows terrain")


func test_overlay_is_transparent_without_owners() -> void:
	for colour: Color in _style.overlay_colours(_map):
		assert_eq(colour.a, 0.0, "no owner, no overlay")


func test_hex_info_names_the_city_and_the_terrain() -> void:
	_map.city_names[Vector2i(1, 0)] = "Lisbon"
	_map.city_sizes[Vector2i(1, 0)] = 3
	var text := HexInfo.describe(_map, Vector2i(1, 0), _style)
	assert_true(text.begins_with("Lisbon\n"), "the city is the name: %s" % [text])
	assert_true(text.contains("Terrain: Farmland"), "the terrain: %s" % [text])
	assert_eq(HexInfo.describe(_map, Vector2i(0, 0), _style).split("\n")[0], "Sea", "ocean")
	assert_eq(HexInfo.describe(_map, Vector2i(9, 9), _style), "", "off the map")
