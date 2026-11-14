## The projection and the polygon maths against the table that tools/export_hexgrid_table.py writes from
## hexa/campaign/geo.py, with the constants of godot/data/geography/projection.json.
extends GutTest

const TABLE := "res://tests/fixtures/geo_table.json"
const PROJECTION := "res://data/geography/projection.json"

var _table: Dictionary = {}
var _geo: Geo


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROJECTION))
	_geo = Geo.new(float(p["lon0"]), float(p["col_deg"]), float(p["row_deg"]), float(p["y_top"]),
			int(p["cols"]), int(p["rows"]))


func test_projection_constants_are_the_python_ones() -> void:
	assert_eq(_geo.cols, 203, "columns")
	assert_eq(_geo.rows, 150, "rows")
	assert_eq(_geo.col_deg, 0.725, "degrees of longitude per hex (1.45 / SCALE 2)")


func test_merc_and_inverse_match_python() -> void:
	for row: Array in _table["merc"]:
		assert_almost_eq(Geo.merc(float(row[0])), float(row[1]), 1e-12, "merc(%s)" % [row[0]])
	for row: Array in _table["inv_merc"]:
		assert_almost_eq(Geo.inv_merc(float(row[0])), float(row[1]), 1e-12, "inv_merc(%s)" % [row[0]])


func test_lonlat_matches_python() -> void:
	for row: Array in _table["lonlat"]:
		var pos: Array = row[0]
		var want: Array = row[1]
		var got := _geo.lonlat(Vector2i(int(pos[0]), int(pos[1])))
		assert_almost_eq(got[0], float(want[0]), 1e-12, "lon of %s" % [pos])
		assert_almost_eq(got[1], float(want[1]), 1e-12, "lat of %s" % [pos])


func test_hex_of_matches_python_exactly() -> void:
	for row: Array in _table["hex_of"]:
		var want: Array = row[2]
		assert_eq(_geo.hex_of(float(row[0]), float(row[1])), Vector2i(int(want[0]), int(want[1])),
				"hex_of(%s, %s)" % [row[0], row[1]])


func test_hex_of_inverts_lonlat() -> void:
	for col in range(0, 203, 11):
		for row in range(0, 150, 9):
			var pos := Vector2i(col, row)
			var centre := _geo.lonlat(pos)
			assert_eq(_geo.hex_of(centre[0], centre[1]), pos, "the centre of %s is in %s" % [pos, pos])


func test_seg_distance_matches_python() -> void:
	for row: Array in _table["seg_distance"]:
		var p: Array = row[0]
		var a: Array = row[1]
		var b: Array = row[2]
		var got := Geo.seg_distance(float(p[0]), float(p[1]), float(a[0]), float(a[1]), float(b[0]), float(b[1]))
		assert_almost_eq(got, float(row[3]), 1e-12, "distance from %s to %s-%s" % [p, a, b])


func test_inside_is_even_odd() -> void:
	var square := PackedFloat64Array([0.0, 0.0, 4.0, 0.0, 4.0, 4.0, 0.0, 4.0])
	assert_true(Geo.inside(2.0, 2.0, square), "centre of a square is inside")
	assert_false(Geo.inside(5.0, 2.0, square), "outside the square")
	assert_false(Geo.inside(-0.5, 2.0, square), "left of the square")
