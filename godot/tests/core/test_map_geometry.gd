## The map view's hex geometry against core/hexgrid.gd (the Python hexgrid, scaled to the baked radius 60), and the
## tile layer's scale and offset that map the 104 x 120 grid onto it.
extends GutTest


func _close(a: Vector2, b: Vector2, tolerance: float, what: String) -> void:
	assert_true(a.distance_to(b) <= tolerance, "%s: %s vs %s" % [what, a, b])


func test_centre_is_hex_centre_scaled_to_radius_60() -> void:
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(202, 149),
			Vector2i(100, 75), Vector2i(7, 3)]:
		var expected := HexGrid.hex_center(pos) * MapGeometry.SQRT3
		_close(MapGeometry.centre(pos), expected, 0.001, "centre of %s" % [pos])


func test_centre_matches_hex_centre_over_the_whole_map() -> void:
	# Every hex of the Europe grid, against the same maths in core/hexgrid.gd.
	for r in range(0, 150, 7):
		for c in range(0, 203, 5):
			var pos := Vector2i(c, r)
			_close(MapGeometry.centre(pos), HexGrid.hex_center(pos) * MapGeometry.SQRT3, 0.001, "centre %s" % [pos])


func test_hex_width_and_row_step_are_the_baked_radius() -> void:
	# A regular pointy-top hex of radius 60: width sqrt(3) x 60, row step 1.5 x 60.
	assert_almost_eq(MapGeometry.hex_width(), 103.9230484541, 0.0001, "hex width")
	assert_almost_eq(MapGeometry.ROW_STEP, 90.0, 0.0001, "row step")
	var a := MapGeometry.centre(Vector2i(4, 2))
	var b := MapGeometry.centre(Vector2i(5, 2))
	assert_almost_eq(b.x - a.x, MapGeometry.hex_width(), 0.001, "neighbour in the row")
	var c := MapGeometry.centre(Vector2i(4, 3))
	assert_almost_eq(c.y - a.y, MapGeometry.ROW_STEP, 0.001, "row below")


func test_pixel_to_hex_inverts_centre() -> void:
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(3, 4), Vector2i(202, 149), Vector2i(50, 51)]:
		assert_eq(MapGeometry.pixel_to_hex(MapGeometry.centre(pos)), pos, "centre of %s" % [pos])


func test_pixel_to_hex_inside_a_hex_is_that_hex() -> void:
	var pos := Vector2i(10, 9)
	var c := MapGeometry.centre(pos)
	for offset: Vector2 in [Vector2(20, 0), Vector2(-20, 10), Vector2(0, -25), Vector2(0, 30), Vector2(-15, -15)]:
		assert_eq(MapGeometry.pixel_to_hex(c + offset), pos, "offset %s" % [offset])


func test_tile_layer_maps_the_tile_grid_onto_the_hex_geometry() -> void:
	# Stacked tiles of 104 x 120: column step 104, odd rows 52 to the right, row step 90, tile centre at (52, 60).
	var scale := MapGeometry.tile_layer_scale()
	var offset := MapGeometry.tile_layer_offset()
	assert_almost_eq(scale.x * float(MapGeometry.TILE_W), MapGeometry.hex_width(), 0.0001, "scale makes 104 exact")
	assert_almost_eq(offset.y, 0.6218, 0.001, "offset y")
	for r in 6:
		for c in 8:
			var pos := Vector2i(c, r)
			var local := Vector2(float(c * MapGeometry.TILE_W) + float(r & 1) * 52.0 + 52.0, float(r) * 90.0 + 60.0)
			var on_screen := Vector2(local.x * scale.x, local.y + offset.y)
			_close(on_screen, MapGeometry.centre(pos), 0.01, "tile centre of %s" % [pos])
