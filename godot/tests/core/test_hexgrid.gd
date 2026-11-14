## The hex grid maths against the table that tools/export_hexgrid_table.py writes from hexa/hexgrid.py.
extends GutTest

const TABLE := "res://tests/fixtures/hexgrid_table.json"

var _table: Dictionary = {}


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE))


static func _v2i(raw: Array) -> Vector2i:
	return Vector2i(int(raw[0]), int(raw[1]))


static func _v2i_list(raw: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Array in raw:
		out.append(_v2i(item))
	return out


func test_neighbours_match_python_in_order() -> void:
	for row: Array in _table["neighbours"]:
		var pos := _v2i(row[0])
		assert_eq(HexGrid.neighbours(pos), _v2i_list(row[1]), "neighbours of %s" % [pos])


func test_cube_coordinates_match_python() -> void:
	for row: Array in _table["cube"]:
		var pos := _v2i(row[0])
		var c: Array = row[1]
		assert_eq(HexGrid.to_cube(pos), Vector3i(int(c[0]), int(c[1]), int(c[2])), "cube of %s" % [pos])


func test_distance_matches_python() -> void:
	for row: Array in _table["distance"]:
		assert_eq(HexGrid.distance(_v2i(row[0]), _v2i(row[1])), int(row[2]), "distance %s to %s" % [row[0], row[1]])


func test_within_matches_python_in_order() -> void:
	for row: Array in _table["within"]:
		var got := HexGrid.within(_v2i(row[0]), int(row[1]))
		assert_eq(got, _v2i_list(row[2]), "within %d of %s" % [int(row[1]), row[0]])


func test_hex_centre_matches_python() -> void:
	for row: Array in _table["center"]:
		var c: Array = row[1]
		_assert_close(HexGrid.hex_center(_v2i(row[0])), Vector2(float(c[0]), float(c[1])), "centre %s" % [row[0]])


func test_hex_centre_with_origin_matches_python() -> void:
	for row: Array in _table["center_origin"]:
		var c: Array = row[1]
		var got := HexGrid.hex_center(_v2i(row[0]), Vector2(12.5, -7.0))
		_assert_close(got, Vector2(float(c[0]), float(c[1])), "centre with origin %s" % [row[0]])


func test_pixel_to_hex_matches_python() -> void:
	for row: Array in _table["pixel"]:
		var pt: Array = row[0]
		assert_eq(HexGrid.pixel_to_hex(Vector2(float(pt[0]), float(pt[1]))), _v2i(row[1]), "pixel %s" % [pt])


func test_pixel_to_hex_with_origin_matches_python() -> void:
	for row: Array in _table["pixel_origin"]:
		var pt: Array = row[0]
		var got := HexGrid.pixel_to_hex(Vector2(float(pt[0]), float(pt[1])), Vector2(12.5, -7.0))
		assert_eq(got, _v2i(row[1]), "pixel with origin %s" % [pt])


func test_round_half_even_is_python_round() -> void:
	var cases := {0.5: 0, 1.5: 2, 2.5: 2, 3.5: 4, -0.5: 0, -1.5: -2, -2.5: -2, 2.4: 2, 2.6: 3, -2.6: -3, 7.0: 7}
	for x: float in cases.keys():
		assert_eq(HexGrid.round_half_even(x), int(cases[x]), "round(%s)" % [x])


func test_edge_key_ignores_direction() -> void:
	var a := Vector2i(4, 7)
	var b := Vector2i(5, 7)
	assert_eq(HexGrid.edge_key(a, b), HexGrid.edge_key(b, a), "both orders give one key")
	assert_eq(HexGrid.edge_ends(HexGrid.edge_key(b, a)), [a, b], "the ends come back sorted")


func _assert_close(got: Vector2, want: Vector2, label: String) -> void:
	assert_almost_eq(got.x, want.x, 1e-9, label + " x")
	assert_almost_eq(got.y, want.y, 1e-9, label + " y")
