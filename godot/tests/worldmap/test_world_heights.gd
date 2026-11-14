## The heights file of the map prototype (godot/data/worldmap/heights_alps_po.json, written by
## tools/worldmap/extract_heights.py) through WorldHeights: the committed file reads, its counts are the extraction's,
## a few hexes hold the heights the report printed, and a file of another schema is refused.
extends GutTest

const PATH := "res://data/worldmap/heights_alps_po.json"

var _heights: WorldHeights = null


func before_all() -> void:
	_heights = WorldHeights.from_text(FileAccess.get_file_as_string(PATH))


func test_committed_file_reads_with_the_window_and_the_height_statistic() -> void:
	assert_not_null(_heights, "the file reads")
	if _heights == null:
		return
	assert_eq(_heights.height_stat, "inner_max", "the height is the highest ground within 0.4 hex (thread 1)")
	assert_almost_eq(_heights.hex_w_km, 28.0, 0.0001, "28 km hexes")
	assert_almost_eq(_heights.lon_west, 5.6, 0.0001, "the window's west edge")
	assert_almost_eq(_heights.lat_north, 47.3, 0.0001, "the window's north edge")


func test_counts_are_the_extraction_report_counts() -> void:
	if _heights == null:
		fail_test("the file must read")
		return
	assert_eq(_heights.land.size(), 371, "every hex of the window (the window runs to 12.6 E)")
	var land := 0
	for hex: Vector2i in _heights.land.keys():
		if _heights.is_land(hex):
			land += 1
	assert_eq(land, 324, "324 land hexes (the coastline decides)")
	assert_eq(_heights.height_m.size(), 324, "a height for every land hex")
	assert_eq(_heights.anchors.size(), 63 + 24 + 7, "63 places, 24 passes and 7 gorges are anchored")


func test_known_hexes_hold_the_measured_heights() -> void:
	if _heights == null:
		fail_test("the file must read")
		return
	var mont_blanc := Vector2i(3, 6)
	assert_true(_heights.is_land(mont_blanc), "Mont Blanc's hex is land")
	assert_gt(_heights.height_m[mont_blanc], 4000.0, "the summit area is above 4000 m (ETOPO ice surface)")
	var sea := 0
	for hex: Vector2i in _heights.land.keys():
		if not _heights.is_land(hex):
			sea += 1
	assert_eq(sea, 47, "47 sea hexes (the Ligurian and Tyrrhenian sea, the Gulf of Lion edge, the lagoon of Venice)")
	assert_false(_heights.has_hex(Vector2i(-40, -40)), "a hex outside the window is not in the file")
	var milan := Vector2i(10, 8)
	assert_almost_eq(_heights.height_m[milan], 125.3, 0.05, "Milan's hex, 125 m (plain)")
	var aosta := Vector2i(4, 7)
	assert_gt(float(_heights.stats[aosta]["inner_max"]), 2000.0, "Aosta's hex is high ground under inner max")
	assert_lt(_heights.height_m[aosta], 1000.0, "carved: the Aosta valley floor reads low (the owner's valley decision)")


func test_each_land_hex_has_its_statistics_and_a_consistent_level() -> void:
	if _heights == null:
		fail_test("the file must read")
		return
	for hex: Vector2i in _heights.height_m.keys():
		var stats: Dictionary = _heights.stats[hex]
		assert_true(stats.has("inner_max") and stats.has("mean") and stats.has("centre_z"), "stats of %s" % [hex])
		if bool(stats.get("carved", false)):
			assert_lte(_heights.height_m[hex], float(stats["inner_max"]) + 0.01, "a carved hex is at most its inner max")
		else:
			assert_almost_eq(_heights.height_m[hex], float(stats["inner_max"]), 0.01, "height of %s is inner_max" % [hex])
		assert_gte(float(stats["inner_max"]), float(stats["inner_mean"]), "max >= mean in %s" % [hex])


func test_a_file_of_another_schema_is_refused() -> void:
	assert_null(WorldHeights.from_text("{\"schema\": \"hexa-godot/map/1\"}"), "another schema")
	assert_null(WorldHeights.from_text("[1, 2, 3]"), "not an object")


func test_a_small_file_reads_into_hexes_land_and_sea() -> void:
	var text := JSON.stringify({
		"schema": "hexa-godot/worldmap-heights/1",
		"height_stat": "inner_max",
		"grid": {"hex_w_km": 28.0, "deg_km": 111.2, "ref_lat": 45.25},
		"window": {"lon_west": 5.6, "lon_east": 11.9, "lat_south": 43.2, "lat_north": 47.3},
		"hexes": [
			{"c": 1, "r": 2, "land": true, "height_m": 2950.5, "inner_max": 2950.5, "mean": 1200.0, "centre_z": 900.0},
			{"c": 2, "r": 2, "land": false, "height_m": 0.0, "inner_max": 0.0, "mean": 0.0, "centre_z": -20.0},
		],
		"anchors": [{"kind": "pass", "name": "Test", "c": 1, "r": 2, "z": 2900.0, "metres": 2469}],
	})
	var small := WorldHeights.from_text(text)
	assert_not_null(small, "the small file reads")
	if small == null:
		return
	assert_true(small.is_land(Vector2i(1, 2)), "land hex")
	assert_false(small.is_land(Vector2i(2, 2)), "sea hex")
	assert_almost_eq(small.height_m[Vector2i(1, 2)], 2950.5, 0.001, "height of the land hex")
	assert_false(small.height_m.has(Vector2i(2, 2)), "a sea hex has no height")
	assert_eq(small.anchors[0]["name"], "Test", "the anchor is kept")
