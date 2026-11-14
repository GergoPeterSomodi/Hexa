## The tile plan on a hand-made fixture: a 5 x 4 grid with a column of sea on the west, a river, a city and a mouth.
## Checks the layer counts, the edge masks (hexgrid order E, NE, NW, W, SW, SE) and that every key exists in the atlas.
extends GutTest

var _atlas: AtlasIndex
var _map: MapData
var _plan: TilePlan


func before_all() -> void:
	_atlas = AtlasIndex.load_index()


func before_each() -> void:
	_map = _fixture()
	_plan = TilePlan.build(_map, _atlas)


## Column 0 is ocean; columns 1 to 4 are plains, except the city at (3, 2), which is a forest.
## A river runs (2, 0) to (2, 1) to (3, 1); a second, short river meets the sea at (1, 1).
func _fixture() -> MapData:
	var map := MapData.new()
	map.cols = 5
	map.rows = 4
	for r in 4:
		for c in 5:
			var pos := Vector2i(c, r)
			if c == 0:
				map.terrain[pos] = MapData.OCEAN
			else:
				map.terrain[pos] = "plains"
	map.terrain[Vector2i(3, 2)] = "forest"
	map.city_names[Vector2i(3, 2)] = "Testville"
	map.city_sizes[Vector2i(3, 2)] = 2
	map.rivers["Main"] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1)]
	map.rivers["Mouth"] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	for river: String in map.rivers.keys():
		for pos: Vector2i in map.rivers[river]:
			if not map.river_at.has(pos):
				map.river_at[pos] = river
	return map


func test_fixture_geometry_is_as_described() -> void:
	# The sea mask uses hexgrid edge order: an even row's (1, 0) has west (bit 3) and south-west (bit 4) sea: 8 + 16.
	assert_eq(TilePlan.sea_mask(_map, Vector2i(1, 0)), 24, "sea mask of (1, 0)")
	assert_eq(TilePlan.edge_bit(Vector2i(2, 0), Vector2i(2, 1)), 32, "(2, 1) is south-east of (2, 0)")
	assert_eq(TilePlan.edge_bit(Vector2i(2, 1), Vector2i(2, 0)), 4, "(2, 0) is north-west of (2, 1)")
	assert_eq(TilePlan.edge_bit(Vector2i(0, 0), Vector2i(3, 3)), 0, "not neighbours")


func test_ground_has_one_cell_per_hex() -> void:
	assert_eq(_plan.count(TilePlan.GROUND), 20, "every hex of 5 x 4")
	assert_eq(_plan.missing, 0, "every key exists in the atlas")
	assert_true(_plan.key_at(TilePlan.GROUND, Vector2i(0, 0)).begins_with("sea/sea/"), "sea hex")
	assert_true(_plan.key_at(TilePlan.GROUND, Vector2i(1, 0)).begins_with("terrain/plains/"), "plains hex")
	assert_true(_plan.key_at(TilePlan.GROUND, Vector2i(3, 2)).begins_with("terrain/forest/"), "forest hex")


func test_coast_covers_land_next_to_the_sea_except_the_mouth() -> void:
	# Column 1 is coastal (4 hexes); (1, 1) is the mouth of the short river, so it has no coast cell of its own.
	assert_eq(_plan.count(TilePlan.COAST), 3, "coast cells")
	assert_eq(_plan.key_at(TilePlan.COAST, Vector2i(1, 0)).substr(0, 8), "coast/24", "coast mask of (1, 0)")
	assert_eq(_plan.key_at(TilePlan.COAST, Vector2i(1, 1)), "", "no coast under a mouth")


func test_river_cells_and_the_mouth() -> void:
	# The river hexes are (2, 0), (2, 1), (3, 1) and the mouth (1, 1), (2, 1), (2, 2): the rivers share (2, 1).
	var cells := _plan.layers[TilePlan.RIVER]
	assert_true(cells.has(Vector2i(2, 0)), "river at (2, 0)")
	assert_true(cells.has(Vector2i(1, 1)), "mouth at (1, 1)")
	assert_true(_plan.key_at(TilePlan.RIVER, Vector2i(1, 1)).begins_with("mouth/"), "mouth piece")
	assert_eq(_plan.key_at(TilePlan.RIVER, Vector2i(2, 0)).substr(0, 9), "river/32/", "river edge south-east")


func test_town_on_land_and_no_roads_or_castles_yet() -> void:
	# A size 2 city is a market town, level 3; it is not on the coast so it has no harbour.
	assert_true(_plan.key_at(TilePlan.TOWN, Vector2i(3, 2)).begins_with("town/3/"), "market town")
	assert_eq(_plan.count(TilePlan.TOWN), 1, "one town")
	assert_eq(_plan.count(TilePlan.ROAD), 0, "roads wait for the builder's step 2")


func test_decoration_only_on_open_plains() -> void:
	var deco := _plan.layers[TilePlan.DECO]
	var candidates := 0
	for r in 4:
		for c in 5:
			var pos := Vector2i(c, r)
			var open := _map.terrain[pos] == "plains" and c >= 2 and not _map.river_at.has(pos) 					and not _map.city_names.has(pos) and not (c == 2 and r == 2)
			if not open:
				assert_false(deco.has(pos), "no deco at %s" % [pos])
				continue
			candidates += 1
			# Python's decorations_for: the same hash, trees on h % 6 == 0 and rocks on h % 9 == 1.
			var h := int((c * 73856093) ^ (r * 19349663)) & 0xFFFF
			if h % 6 == 0 or h % 9 == 1:
				assert_true(deco.has(pos), "deco at %s" % [pos])
			else:
				assert_false(deco.has(pos), "no deco at %s" % [pos])
	assert_true(candidates > 0, "the fixture has open plains")
	for key: String in deco.values():
		assert_true(_atlas.has(key), "deco key %s exists" % [key])


func test_variant_and_town_level() -> void:
	assert_eq(TilePlan.town_level(15), 3, "market town")
	assert_eq(TilePlan.town_level(40), 5, "city")
	assert_eq(TilePlan.town_level(60), 6, "great city")
	var v := TilePlan.variant(Vector2i(4, 3), 3)
	assert_true(v >= 0 and v < 3, "variant range")
	assert_eq(TilePlan.variant(Vector2i(4, 3), 3), v, "variant is a pure function of the hex")
