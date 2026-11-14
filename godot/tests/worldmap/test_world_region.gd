## The hand-written region file (godot/data/worldmap/region_alps_po.json) through WorldRegion: it reads, its counts are the
## ones the extraction report checked, every point is inside the window, and a file of another schema is refused.
extends GutTest

const PATH := "res://data/worldmap/region_alps_po.json"

var _region: WorldRegion = null


func before_all() -> void:
	_region = WorldRegion.from_text(FileAccess.get_file_as_string(PATH))


func test_committed_file_reads_with_its_window_and_grid() -> void:
	assert_not_null(_region, "the file reads")
	if _region == null:
		return
	assert_eq(_region.name, "Alps and Po (prototype region, 1480)", "the name")
	assert_almost_eq(_region.hex_w_km, 28.0, 0.0001, "28 km hexes")
	assert_almost_eq(_region.deg_km, 111.2, 0.0001, "kilometres per degree")
	assert_almost_eq(_region.ref_lat, 45.25, 0.0001, "reference latitude")


func test_counts_of_every_kind() -> void:
	if _region == null:
		fail_test("the file must read")
		return
	assert_eq(_region.ranges.size(), 12, "12 ranges")
	assert_eq(_region.passes.size(), 24, "24 passes")
	assert_eq(_region.valleys.size(), 16, "16 valleys")
	assert_eq(_region.rivers.size(), 15, "15 rivers, tributaries included")
	assert_eq(_region.lakes.size(), 8, "8 lake axes (Como has a south arm)")
	assert_eq(_region.gorges.size(), 4, "4 named gorges")
	assert_eq(_region.places.size(), 56, "56 notable places in the window")
	assert_eq(_region.river_cities.size(), 4, "Verona, Florence, Pisa and Geneva")


func test_every_point_is_inside_the_window() -> void:
	if _region == null:
		fail_test("the file must read")
		return
	var lines: Array[PackedVector2Array] = []
	for r: Dictionary in _region.ranges:
		lines.append(r["line"])
	for r: Dictionary in _region.rivers:
		lines.append(r["line"])
	for v: Dictionary in _region.valleys:
		lines.append(v["floor"])
	for line: PackedVector2Array in lines:
		for p: Vector2 in line:
			assert_true(_inside(p), "a point of a line at %s" % [p])
	for ps: Dictionary in _region.passes:
		assert_true(_inside(ps["pos"]), "pass %s" % ps["name"])
	for pl: Dictionary in _region.places:
		assert_true(_inside(pl["pos"]), "place %s" % pl["name"])


func test_river_cities_are_on_a_named_river_and_a_place() -> void:
	if _region == null:
		fail_test("the file must read")
		return
	var rivers := {}
	for rv: Dictionary in _region.rivers:
		rivers[rv["name"]] = true
	for rc: Dictionary in _region.river_cities:
		assert_not_null(_region.find_place(rc["name"]).get("pos"), "%s is a place" % rc["name"])
		assert_true(rivers.has(rc["river"]), "%s is on the river %s" % [rc["name"], rc["river"]])
	assert_eq(_region.find_place("Florence").get("kind"), "city", "Florence is a city")


func test_a_file_of_another_schema_is_refused() -> void:
	assert_null(WorldRegion.from_text("{\"schema\": \"hexa-godot/worldmap-heights/1\"}"), "another schema")
	assert_null(WorldRegion.from_text("42"), "not an object")


func _inside(p: Vector2) -> bool:
	# The Rhone leaves the window to the south-west, so the window is taken 0.15 degree wider for the test.
	return _region.lon_west - 0.15 <= p.x and p.x <= _region.lon_east and _region.lat_south <= p.y and p.y <= _region.lat_north
