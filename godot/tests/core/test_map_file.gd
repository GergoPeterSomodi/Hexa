## The Europe map file (godot/data/maps/europe_1480.json, written by tools/build_map.gd) and its text format (MapFile):
## the committed file reads back to the same text, its counts are the built map's, and a small map of every field kind
## survives the round trip.
extends GutTest

var _text: String = ""


func before_all() -> void:
	_text = FileAccess.get_file_as_string(MapFile.PATH)


func test_committed_file_reads_and_writes_back_to_the_same_text() -> void:
	assert_gt(_text.length(), 1000000, "the file is there (about 5 MB)")
	var map := MapFile.from_text(_text)
	assert_not_null(map, "the file reads")
	if map == null:
		return
	assert_eq(MapFile.to_text(map), _text, "to_text(from_text(file)) is the file, byte for byte")


func test_committed_file_holds_the_europe_counts() -> void:
	var map := MapFile.from_text(_text)
	assert_not_null(map, "the file reads")
	if map == null:
		return
	assert_eq(map.cols, 203, "columns")
	assert_eq(map.rows, 150, "rows")
	assert_eq(map.map_seed, 1480, "the map seed")
	assert_eq(map.terrain.size(), 30450, "every grid hex has a kind")
	assert_eq(map.land_hexes().size(), 14411, "land hexes (Python 14,411)")
	assert_eq(map.provinces.size(), 14411, "provinces: one per land hex")
	assert_eq(map.country_order.size(), 49, "countries")
	assert_eq(map.countries.size(), 49, "countries by tag")
	assert_eq(map.units.size(), 131, "starting units as built on seed 1480")
	assert_eq(map.rivers.size(), 35, "rivers")
	assert_eq(map.city_names.size(), 102, "cities")


func test_small_map_of_every_field_kind_round_trips() -> void:
	var map := MapData.new()
	map.cols = 3
	map.rows = 2
	map.map_seed = 7
	for r: int in 2:
		for c: int in 3:
			map.terrain[Vector2i(c, r)] = "plains"
	map.terrain[Vector2i(1, 0)] = MapData.OCEAN
	map.terrain[Vector2i(2, 1)] = MapData.LAKE
	map.rivers["Test"] = [Vector2i(0, 1), Vector2i(1, 1)]
	map.river_at[Vector2i(0, 1)] = "Test"
	map.sea_body[Vector2i(1, 0)] = 1
	map.city_names[Vector2i(0, 0)] = "Oldtown"
	map.city_sizes[Vector2i(0, 0)] = 2
	map.ridge_edges[HexGrid.edge_key(Vector2i(0, 0), Vector2i(1, 1))] = true
	map.pass_names[HexGrid.edge_key(Vector2i(1, 1), Vector2i(2, 1))] = "Gap"
	map.pass_ids[HexGrid.edge_key(Vector2i(1, 1), Vector2i(2, 1))] = 4
	map.pass_hexes[Vector2i(1, 1)] = "Gap"
	map.landmass[Vector2i(0, 0)] = 1
	var prov := Province.new(Vector2i(0, 0), "plains", true, true)
	prov.name = "Oldtown"
	prov.owner = "AAA"
	prov.controller = "AAA"
	prov.peasants = 12.5
	prov.burghers = 0.25
	prov.works = 2
	prov.settlement = 2
	prov.castle = 3
	prov.port = true
	map.provinces[prov.pos] = prov
	var country := Country.new("AAA", "Alpha", Color(0.25, 0.5, 0.75), Vector2i(0, 0))
	country.colonial_start = 30
	map.countries["AAA"] = country
	map.country_order.append("AAA")
	map.roads[Vector2i(0, 0)] = true
	map.road_paths.append([Vector2i(0, 0), Vector2i(1, 0)])
	map.units.append(Unit.new(1, "knights", "AAA", Vector2i(0, 0), 6, 2.0))
	var text := MapFile.to_text(map)
	var back := MapFile.from_text(text)
	assert_not_null(back, "the text reads")
	if back == null:
		return
	assert_eq(MapFile.to_text(back), text, "the same text again")
	assert_eq(back.terrain[Vector2i(1, 0)], MapData.OCEAN, "ocean kept")
	assert_eq(back.rivers["Test"][1], Vector2i(1, 1), "river hexes kept in order")
	assert_eq(back.pass_ids[HexGrid.edge_key(Vector2i(1, 1), Vector2i(2, 1))], 4, "pass id kept")
	assert_eq(back.provinces[Vector2i(0, 0)].peasants, 12.5, "people kept")
	assert_eq(back.countries["AAA"].colour, Color(0.25, 0.5, 0.75), "colour kept")
	assert_eq(back.countries["AAA"].colonial_start, 30, "colonial start kept")
	assert_eq(back.units[0].moves, 2.0, "unit moves kept")


func test_text_of_another_schema_is_refused() -> void:
	assert_null(MapFile.from_text("{\"schema\": \"something-else\"}"), "a file of another schema")
	assert_null(MapFile.from_text("[1, 2]"), "a list, not an object")
	assert_null(MapFile.from_text("{\"cols\": 3}"), "an object without the schema")
