## Relief of the map prototype region (core/mapgen/world_relief.gd): the levels of every hex, the crest edges where a
## spine runs between two high hexes, the pass saddles, and the invariants that the viewer and the next steps rely on.
## The counts are the ones the extraction report and the first viewer pictures showed; a synthetic spine checks the
## crossing test on one edge.
extends GutTest

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"

var _grid: HexGrid = null
var _heights: WorldHeights = null
var _region: WorldRegion = null
var _relief: WorldRelief = null


func before_all() -> void:
	_heights = WorldHeights.from_text(FileAccess.get_file_as_string(HEIGHTS))
	_region = WorldRegion.from_text(FileAccess.get_file_as_string(REGION))
	if _heights == null or _region == null:
		return
	_grid = HexGrid.new(_region.hex_w_km, _region.deg_km, _region.ref_lat, _region.lon_west, _region.lat_north)
	_relief = WorldRelief.build(_grid, _heights, _region)


func _ready_or_fail() -> bool:
	if _relief == null:
		fail_test("the heights and the region must read")
		return false
	return true


func _pass_index(pass_name: String) -> int:
	for i: int in _region.passes.size():
		if _region.passes[i]["name"] == pass_name:
			return i
	return -1


func test_level_histogram_is_the_extraction_histogram() -> void:
	if not _ready_or_fail():
		return
	var summary := _relief.summary(_region.passes.size())
	assert_eq(summary["hexes"], 390, "every hex of the window")
	assert_eq(summary["levels"], [55, 32, 70, 57, 60, 67, 49], "sea, then lowland to high peaks (carved valleys included)")


func test_every_level_follows_from_its_metres() -> void:
	if not _ready_or_fail():
		return
	for hex: Vector2i in _heights.height_m.keys():
		assert_eq(_relief.level_at(hex), ReliefLevels.level_of(_heights.height_m[hex]), "level of %s" % [hex])
	for hex: Vector2i in _heights.land.keys():
		if not _heights.is_land(hex):
			assert_eq(_relief.level_at(hex), ReliefLevels.SEA, "sea hex %s" % [hex])


func test_every_crest_edge_joins_two_land_hexes_at_the_range_crest_level() -> void:
	if not _ready_or_fail():
		return
	for key: Vector4i in _relief.crest_edges.keys():
		var range_index: int = _relief.crest_edges[key]
		var crest_level: int = _region.ranges[range_index]["crest_level"]
		var pair := HexGrid.edge_hexes(key)
		assert_gte(mini(_relief.crest_level_at(pair[0]), _relief.crest_level_at(pair[1])), crest_level,
			"crest %s-%s of %s" % [pair[0], pair[1], _region.ranges[range_index]["name"]])


func test_crest_and_pass_edge_counts() -> void:
	if not _ready_or_fail():
		return
	var summary := _relief.summary(_region.passes.size())
	assert_eq(summary["crest_edges"], 89, "crest edges drawn from the 12 spines")
	assert_eq(summary["pass_edges"], 45, "pass edges: the crest edges of each saddle (22 passes with a crest)")
	assert_eq(summary["passes_with_crest"], 22, "22 of the 24 passes have a crest saddle")
	assert_eq(summary["gaps"], 16, "spine crossings below the crest level (Jura, Apennines, one Cottian hex)")


func test_every_pass_edge_is_a_crest_edge_of_its_saddle_hex() -> void:
	if not _ready_or_fail():
		return
	for key: Vector4i in _relief.pass_edges.keys():
		assert_true(_relief.crest_edges.has(key), "a pass edge is a crest edge")
		var p: int = _relief.pass_edges[key]
		assert_true(HexGrid.edge_hexes(key).has(_relief.pass_hex[p]), "pass %d opens on its saddle hex" % p)


func test_saddles_of_named_passes() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_relief.pass_hex[_pass_index("Great St Bernard")], Vector2i(4, 6), "Great St Bernard is hex (4, 6)")
	assert_eq(_relief.pass_hex[_pass_index("Simplon")], Vector2i(6, 4), "Simplon is hex (6, 4)")
	assert_eq(_relief.pass_hex[_pass_index("Stelvio")], Vector2i(13, 3), "Stelvio is hex (13, 3)")
	# The three pairs of passes that shared a saddle hex at 28 km (Gotthard and Furka, Splugen and San Bernardino, Julier and
	# Bernina): the nearer pass keeps the hex, the other takes the nearest free crest hex of its range (step 5).
	assert_eq(_relief.pass_hex[_pass_index("Furka")], Vector2i(7, 3), "Furka keeps (7, 3), the nearer crest hex")
	assert_eq(_relief.pass_hex[_pass_index("Gotthard")], Vector2i(8, 2), "Gotthard takes (8, 2), its own crest hex")
	assert_eq(_relief.pass_hex[_pass_index("Julier")], Vector2i(11, 3), "Julier keeps (11, 3)")
	assert_eq(_relief.pass_hex[_pass_index("Bernina")], Vector2i(12, 3), "Bernina takes (12, 3), its own crest hex")
	assert_eq(_relief.pass_hex[_pass_index("San Bernardino")], Vector2i(9, 3), "San Bernardino keeps (9, 3)")
	assert_eq(_relief.pass_hex[_pass_index("Splugen")], Vector2i(10, 3), "Splugen takes (10, 3), its own crest hex")


func test_no_two_passes_share_a_saddle_and_each_has_its_own_pass_edges() -> void:
	if not _ready_or_fail():
		return
	var seen: Dictionary[Vector2i, bool] = {}
	for p: int in _relief.pass_saddles.keys():
		var s: Vector2i = _relief.pass_saddles[p]
		assert_false(seen.has(s), "%s: no two passes share a saddle" % _region.passes[p]["name"])
		seen[s] = true
		var open := 0
		for d: int in 6:
			var key := HexGrid.edge_key(s, _grid.neighbour(s, d))
			if _relief.crest_edges.has(key) and _relief.pass_edges.has(key):
				open += 1
		assert_gte(open, 1, "%s: its saddle has open crest edges" % _region.passes[p]["name"])
	assert_eq(_relief.saddle_failures.size(), 0, "every pass with a crest found its saddle")
	for name: String in ["Furka", "Gotthard", "San Bernardino", "Splugen", "Julier", "Bernina"]:
		var p := _pass_index(name)
		assert_true(_relief.pass_saddles.has(p), "%s has a saddle" % name)
		assert_true(_relief.pass_has_crest[p], "%s carries a crest" % name)
		assert_lte(_relief.pass_km[p], 1.5 * _grid.hex_w_km + 0.001, "%s: its saddle within 1.5 hex widths" % name)


func test_low_passes_without_a_crest_near_them_get_no_saddle_edges() -> void:
	if not _ready_or_fail():
		return
	assert_false(_relief.pass_has_crest[_pass_index("Cadibona")], "Cadibona: no crest hex within one hex")
	assert_false(_relief.pass_has_crest[_pass_index("Arlberg")], "Arlberg: the spine is 31 km away")
	assert_true(_relief.pass_has_crest[_pass_index("Giovi")], "Giovi: the Apennine crest is 5 km away")


func test_saddles_of_passes_with_a_crest_are_within_one_hex_of_the_pass() -> void:
	if not _ready_or_fail():
		return
	for p: int in _region.passes.size():
		if _relief.pass_has_crest[p]:
			assert_lte(_relief.pass_km[p], _grid.hex_w_km + 0.001, "pass %s" % _region.passes[p]["name"])


func test_mont_blanc_is_high_and_the_po_plain_is_low() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_relief.level_at(Vector2i(3, 6)), 6, "Mont Blanc's hex is high peaks")
	assert_eq(_relief.level_at(Vector2i(10, 8)), 2, "Milan's hex is plain")
	assert_eq(_relief.level_at(Vector2i(5, 9)), 2, "Turin's hex is plain")
	assert_eq(_relief.level_at(Vector2i(9, 9)), 1, "Pavia's hex is lowland")


func test_a_spine_crossing_one_edge_makes_one_crest_edge_only_when_both_hexes_are_high() -> void:
	var grid := HexGrid.new(28.0, 111.2, 45.25, 0.0, 47.0)
	var heights := WorldHeights.new()
	heights.land[Vector2i(0, 0)] = true
	heights.land[Vector2i(1, 0)] = true
	heights.height_m[Vector2i(0, 0)] = 3000.0
	heights.height_m[Vector2i(1, 0)] = 3100.0
	var mid := Vector2(28.0, grid.hex_r_km)
	var line := PackedVector2Array()
	for y: float in [mid.y - 30.0, mid.y + 30.0]:
		line.append(grid.lonlat_of(Vector2(mid.x, y)))
	var region := WorldRegion.new()
	region.ranges.append({"name": "Test spine", "crest_level": 5, "line": line})
	var relief := WorldRelief.build(grid, heights, region)
	assert_eq(relief.crest_edges.size(), 1, "one crest edge")
	assert_true(relief.crest_edges.has(HexGrid.edge_key(Vector2i(0, 0), Vector2i(1, 0))), "on the shared edge")
	assert_eq(relief.gaps.size(), 0, "no gap")
	heights.height_m[Vector2i(1, 0)] = 300.0
	var low := WorldRelief.build(grid, heights, region)
	assert_eq(low.crest_edges.size(), 0, "a lowland hex on one side: no crest")
	assert_eq(low.gaps.size(), 1, "the crossing is reported as a gap")
