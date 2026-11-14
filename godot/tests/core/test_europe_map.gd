## The map check of step 1 (the land layers) for Europe 1480: the facts that must equal Python's, and the terrain mix
## inside the ranges of godot/data/map_reference.json. The map is built once for the whole file.
## The ranges: each kind's Python range (min to max over the eight seeds) widened by the larger of 10 percent of its
## median and 25 hexes (the brief, "The new Europe is checked").
extends GutTest

const REFERENCE := "res://data/map_reference.json"

var _map: MapData
var _reference: Dictionary = {}
var _equal: Dictionary = {}
var _mix_ranges: Dictionary = {}


func before_all() -> void:
	_reference = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
	_equal = _reference["equal"]
	_mix_ranges = _reference["close"]["terrain_mix"]
	_map = MapBuilder.build_europe(EuropeData.load_europe())


func _ref(key: String) -> Variant:
	var fact: Dictionary = _equal[key]
	return fact["value"]


func test_grid_is_203_by_150() -> void:
	var grid: Array = _ref("grid")
	assert_eq(_map.cols, int(grid[0]), "columns")
	assert_eq(_map.rows, int(grid[1]), "rows")
	assert_eq(_map.terrain.size(), 203 * 150, "every grid hex has a kind")


func test_land_ocean_and_lake_counts_match_python() -> void:
	var want: Dictionary = _ref("hex_classes")
	var got := _map.class_counts()
	assert_eq(int(got["land"]), int(want["land"]), "land hexes")
	assert_eq(int(got["ocean"]), int(want["ocean"]), "ocean hexes")
	assert_eq(int(got["lake"]), int(want["lake"]), "lake hexes")


func test_every_hex_is_the_same_class_as_python() -> void:
	var rows: Array = _reference["hexes_1480"]["class_rows"]
	var differ := 0
	var first := ""
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			var code: String = row[c]
			var kind: String = _map.terrain[Vector2i(c, r)]
			var want := "L"
			if kind == MapData.OCEAN:
				want = "O"
			elif kind == MapData.LAKE:
				want = "K"
			if want != code:
				differ += 1
				if first == "":
					first = "%s is %s, Python %s" % [Vector2i(c, r), kind, code]
	# The brief lists land differences and treats more than 5 as a bug; with the same grid and the same coastlines
	# there should be none.
	assert_eq(differ, 0, "hexes whose class differs from Python (first: %s)" % first)


func test_coastal_land_count_matches_python() -> void:
	assert_eq(_map.coastal_land().size(), int(_ref("coastal_provinces")), "coastal land hexes")


func test_cities_are_on_the_python_hexes_with_the_python_names() -> void:
	var want_hexes: Array = _ref("cities")
	var got_hexes: Array[Vector2i] = []
	for pos: Vector2i in _map.city_names.keys():
		got_hexes.append(pos)
	got_hexes.sort_custom(HexGrid.lex_less)
	var want: Array[Vector2i] = []
	for pair: Array in want_hexes:
		want.append(Vector2i(int(pair[0]), int(pair[1])))
	assert_eq(got_hexes, want, "city hexes")
	var names: Array[String] = []
	for name: String in _map.city_names.values():
		names.append(name)
	names.sort()
	var want_names: Array = _ref("city_names")
	assert_eq(names, want_names, "city names")


func test_rivers_match_python_counts() -> void:
	assert_eq(_map.rivers.size(), int(_ref("rivers")), "rivers")
	assert_eq(_map.river_at.size(), int(_ref("river_hexes")), "river hexes")


func test_ridges_and_passes_match_python_counts() -> void:
	assert_eq(_map.ridge_edges.size(), int(_ref("ridge_edges")), "ridge edges")
	assert_eq(_map.pass_names.size(), int(_ref("pass_edges")), "pass edges")
	assert_eq(_map.pass_hexes.size(), int(_ref("passes")), "passes (hexes at the ends of pass edges)")


func test_pass_edges_join_neighbouring_land_and_are_not_ridges() -> void:
	for e: Vector4i in _map.pass_names.keys():
		assert_false(_map.ridge_edges.has(e), "a pass edge is not a ridge edge")
		var ends := HexGrid.edge_ends(e)
		assert_eq(HexGrid.distance(ends[0], ends[1]), 1, "a pass edge joins neighbours")
		assert_true(_map.is_land(ends[0]) and _map.is_land(ends[1]), "a pass edge joins land")


func test_terrain_mix_is_inside_the_python_ranges() -> void:
	var mix := _map.terrain_counts()
	for kind: String in mix.keys():
		assert_true(_mix_ranges.has(kind), "%s is a kind of the Python map" % kind)
	for kind: String in _mix_ranges.keys():
		var fact: Dictionary = _mix_ranges[kind]
		var width := maxf(0.10 * float(fact["median"]), 25.0)
		var low := float(fact["min"]) - width
		var high := float(fact["max"]) + width
		var got := float(mix.get(kind, 0))
		assert_true(got >= low and got <= high,
				"%s %d inside %.0f to %.0f (Python %d to %d)" % [kind, int(got), low, high,
				int(fact["min"]), int(fact["max"])])


func test_every_land_hex_has_a_land_kind() -> void:
	var kinds := EuropeData.load_europe().land_kinds
	for pos: Vector2i in _map.land_hexes():
		var kind: String = _map.terrain[pos]
		assert_true(kinds.has(kind), "%s has the land kind %s" % [pos, kind])


func test_the_same_seed_builds_the_same_map() -> void:
	var again := MapBuilder.build_europe(EuropeData.load_europe())
	assert_eq(again.terrain, _map.terrain, "the terrain is repeatable")
	assert_eq(again.ridge_edges.size(), _map.ridge_edges.size(), "the ridges are repeatable")
