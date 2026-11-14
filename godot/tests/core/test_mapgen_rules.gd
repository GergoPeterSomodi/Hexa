## Small hand-made maps for the step 2 rules of the Europe builder: the road search (costs, limits, ridges, owners), the
## stacking of starting troops, the compass words and the wild-name test. No Europe here: each map is a few hexes.
extends GutTest


func _line_map(count: int, owner: String) -> MapData:
	var map := MapData.new()
	for c in count:
		var pos := Vector2i(c, 0)
		map.terrain[pos] = "plains"
		var prov := Province.new(pos, "plains", false, false)
		prov.owner = owner
		map.provinces[pos] = prov
	return map


func _data() -> EuropeData:
	var data := EuropeData.new()
	data.terrain_move = {"plains": 1.0, "forest": 2.0}
	data.stack_base = 6
	data.stack_general = 2
	data.stack_civilian = 3
	data.war_kinds = PackedStringArray(["pikemen", "knights", "bombards"])
	data.compass = PackedStringArray(["east", "north-east", "north", "north-west", "west", "south-west", "south",
			"south-east"])
	return data


func _goal(pos: Vector2i) -> Dictionary:
	return {pos: true}


func test_a_road_follows_the_line_of_plains() -> void:
	var map := _line_map(5, "A")
	var path := RoadBuilder._connect(map, _data(), Vector2i(0, 0), _goal(Vector2i(4, 0)), 100, "A")
	assert_eq(path.size(), 5, "five hexes from the first to the last")
	assert_eq(path[0], Vector2i(0, 0), "starts at the town")
	assert_eq(path[4], Vector2i(4, 0), "ends at the goal")


func test_a_road_stops_at_the_cost_limit() -> void:
	var map := _line_map(5, "A")
	# Four plains steps cost 8 half steps; a limit of 6 (three steps) cannot reach the goal.
	var path := RoadBuilder._connect(map, _data(), Vector2i(0, 0), _goal(Vector2i(4, 0)), 6, "A")
	assert_true(path.is_empty(), "no road beyond the limit")


func test_a_road_does_not_cross_a_ridge() -> void:
	var map := _line_map(5, "A")
	map.ridge_edges[HexGrid.edge_key(Vector2i(2, 0), Vector2i(3, 0))] = true
	var path := RoadBuilder._connect(map, _data(), Vector2i(0, 0), _goal(Vector2i(4, 0)), 100, "A")
	assert_true(path.is_empty(), "a ridge with no pass stops the road")


func test_a_road_stays_in_its_owners_land() -> void:
	var map := _line_map(5, "A")
	(map.provinces[Vector2i(2, 0)] as Province).owner = "B"
	var path := RoadBuilder._connect(map, _data(), Vector2i(0, 0), _goal(Vector2i(4, 0)), 100, "A")
	assert_true(path.is_empty(), "a country's road does not cross another country")
	var open := RoadBuilder._connect(map, _data(), Vector2i(0, 0), _goal(Vector2i(4, 0)), 100, "")
	assert_eq(open.size(), 5, "a capital road (no owner) may cross any land")


func test_a_road_hex_is_cheaper_to_reuse() -> void:
	var map := _line_map(5, "A")
	var forest_data := _data()
	(map.provinces[Vector2i(1, 0)] as Province).terrain = "forest"
	map.terrain[Vector2i(1, 0)] = "forest"
	map.roads[Vector2i(1, 0)] = true
	# The road hex costs half a step, so a limit of 4 (two steps) reaches the goal two hexes away on a road.
	var path := RoadBuilder._connect(map, forest_data, Vector2i(0, 0), _goal(Vector2i(2, 0)), 4, "A")
	assert_eq(path.size(), 3, "the road hex is crossed at half cost")


func test_a_troop_stack_holds_the_base_limit_and_a_general_adds_two() -> void:
	var map := _line_map(1, "A")
	var data := _data()
	var pos := Vector2i(0, 0)
	for i in 6:
		map.units.append(Unit.new(i + 1, "pikemen", "A", pos, 10, 1.0))
	assert_false(StartingUnits._can_stand(map, data, "A", "pikemen", pos), "seventh troop does not fit")
	map.units.append(Unit.new(7, "general", "A", pos, 1, 8.0))
	assert_true(StartingUnits._can_stand(map, data, "A", "pikemen", pos), "a general lets two more fit")


func test_a_foreign_unit_keeps_a_country_out_of_the_hex() -> void:
	var map := _line_map(1, "A")
	var pos := Vector2i(0, 0)
	map.units.append(Unit.new(1, "pikemen", "B", pos, 10, 1.0))
	assert_false(StartingUnits._can_stand(map, _data(), "A", "pikemen", pos), "another country's troop is there")


func test_the_compass_words_follow_the_direction() -> void:
	var data := _data()
	assert_eq(Naming.compass(1.0, 0.0, data), "east", "east")
	assert_eq(Naming.compass(0.0, 1.0, data), "north", "north")
	assert_eq(Naming.compass(-1.0, 0.0, data), "west", "west")
	assert_eq(Naming.compass(0.0, -1.0, data), "south", "south")
	assert_eq(Naming.compass(-1.0, -1.0, data), "south-west", "south-west")


func test_placeholder_names_are_wild_and_real_names_are_not() -> void:
	assert_true(Naming.is_wild(""), "empty")
	assert_true(Naming.is_wild("near Lisbon"), "near")
	assert_true(Naming.is_wild("Mercia lands"), "lands")
	assert_true(Naming.is_wild("Bavaria countryside"), "countryside")
	assert_false(Naming.is_wild("Lisbon"), "a real name")
	assert_false(Naming.is_wild("Minho (forest)"), "a labelled name is kept")
