## The map prototype's hex grid (core/hexgrid.gd): the neighbour order and the edge numbers of 04 section 3,
## the round trip from a hex to its centre and back, the edge segments, and agreement with the numbers the extraction
## script (tools/worldmap/extract_heights.py) wrote for every named place and pass of the region.
extends GutTest

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"

var _grid: HexGrid


func before_all() -> void:
	# The window and grid of the region file, with the same numbers as the extraction script.
	_grid = HexGrid.new(28.0, 111.2, 45.25, 5.6, 47.3)


func test_neighbours_follow_the_odd_row_layout_in_edge_order() -> void:
	# Even row: east, north-east, north-west, west, south-west, south-east.
	assert_eq(_grid.neighbours(Vector2i(2, 2)), [
		Vector2i(3, 2), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)],
		"neighbours of an even row")
	# Odd row, shifted half a hex to the right.
	assert_eq(_grid.neighbours(Vector2i(2, 3)), [
		Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 4)],
		"neighbours of an odd row")


func test_the_opposite_edge_of_a_neighbour_is_three_steps_round() -> void:
	for r in range(-2, 4):
		for c in range(-2, 4):
			var hex := Vector2i(c, r)
			for d: int in 6:
				var nb := _grid.neighbour(hex, d)
				assert_eq(_grid.neighbour(nb, (d + 3) % 6), hex, "edge %d of %s" % [d, hex])
				assert_eq(_grid.direction_of(hex, nb), d, "direction of %s to %s" % [hex, nb])
	assert_eq(_grid.direction_of(Vector2i(0, 0), Vector2i(5, 5)), -1, "a far hex is not a neighbour")


func test_hex_centres_map_back_to_their_hex() -> void:
	for r in range(-2, 22):
		for c in range(-2, 20):
			var hex := Vector2i(c, r)
			assert_eq(_grid.hex_of_km(_grid.centre_km(hex)), hex, "centre of %s" % [hex])


func test_points_near_a_corner_inside_a_hex_stay_in_it() -> void:
	var hex := Vector2i(7, 9)
	var centre := _grid.centre_km(hex)
	for corner: Vector2 in _grid.corners_km(hex):
		var inside := centre.lerp(corner, 0.9)
		assert_eq(_grid.hex_of_km(inside), hex, "a point 0.9 of the way to a corner")


func test_hex_width_and_row_height_of_a_28_km_grid() -> void:
	var a := _grid.centre_km(Vector2i(4, 4))
	var b := _grid.centre_km(Vector2i(5, 4))
	assert_almost_eq(b.x - a.x, 28.0, 0.001, "centres across a row are one hex width apart")
	var c := _grid.centre_km(Vector2i(4, 5))
	assert_almost_eq(c.y - a.y, 28.0 * sqrt(3.0) / 2.0, 0.001, "rows are sqrt(3)/2 widths apart")
	assert_almost_eq(_grid.hex_r_km, 28.0 / sqrt(3.0), 0.001, "circumradius")


func test_edge_segment_runs_between_two_corners_at_the_edge_middle() -> void:
	var hex := Vector2i(4, 4)
	var east := _grid.neighbour(hex, 0)
	var seg := _grid.edge_segment_km(hex, east)
	assert_eq(seg.size(), 2, "an edge has two ends")
	var middle := (seg[0] + seg[1]) / 2.0
	var centre := _grid.centre_km(hex)
	assert_almost_eq(middle.x - centre.x, 14.0, 0.001, "the east edge sits half a hex width east of the centre")
	assert_almost_eq(middle.y - centre.y, 0.0, 0.001, "and is level with the centre")
	assert_almost_eq(seg[0].distance_to(seg[1]), _grid.hex_r_km, 0.001, "a hex side is as long as the circumradius")
	var north := _grid.edge_segment_km(hex, _grid.neighbour(hex, 1))
	assert_true(north[0].y < centre.y and north[1].y < centre.y, "the north-east edge is above the centre")


func test_edge_key_does_not_depend_on_the_order_of_the_hexes() -> void:
	var a := Vector2i(3, 7)
	var b := _grid.neighbour(a, 2)
	assert_eq(HexGrid.edge_key(a, b), HexGrid.edge_key(b, a), "both orders give one key")
	assert_eq(HexGrid.edge_hexes(HexGrid.edge_key(a, b)).size(), 2, "the key names two hexes")


func test_named_places_and_passes_land_in_the_hexes_the_extraction_script_chose() -> void:
	var heights := WorldHeights.from_text(FileAccess.get_file_as_string(HEIGHTS))
	var region := WorldRegion.from_text(FileAccess.get_file_as_string(REGION))
	assert_not_null(heights, "the heights file reads")
	assert_not_null(region, "the region file reads")
	if heights == null or region == null:
		return
	var grid := HexGrid.new(region.hex_w_km, region.deg_km, region.ref_lat, region.lon_west, region.lat_north)
	var expected := {}
	for anchor: Dictionary in heights.anchors:
		if anchor["kind"] == "pass":
			expected["pass:" + str(anchor["name"])] = Vector2i(int(anchor["c"]), int(anchor["r"]))
		elif anchor["kind"] != "gorge":
			expected["place:" + str(anchor["name"])] = Vector2i(int(anchor["c"]), int(anchor["r"]))
	var checked := 0
	for pl: Dictionary in region.places:
		var pos: Vector2 = pl["pos"]
		assert_eq(grid.hex_of(pos.x, pos.y), expected["place:" + str(pl["name"])], "place %s" % pl["name"])
		checked += 1
	for ps: Dictionary in region.passes:
		var pos: Vector2 = ps["pos"]
		assert_eq(grid.hex_of(pos.x, pos.y), expected["pass:" + str(ps["name"])], "pass %s" % ps["name"])
		checked += 1
	assert_eq(checked, region.places.size() + region.passes.size(), "every place and every pass is checked")
	assert_eq(checked, 87, "63 places and 24 passes")
	assert_eq(grid.hex_of(7.07, 46.10), Vector2i(3, 5), "a point from the region's gorge list (Martigny)")
